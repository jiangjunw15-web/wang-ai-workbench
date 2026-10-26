#!/usr/bin/env python3
"""王将军AI工作台 — 本地管理服务.

Serves two owner-facing consoles that the platform's own frontend does not
ship:

  /wang/ai-order   AI 排序管理 — reads the Magpie gateway's model list,
                    lets the owner define the priority order used when the
                    AI team picks a model per role, and stores it.
  /wang/magpie     Magpie 连接 — shows the gateway's live status, model
                    inventory and a live probe of each model.

Network safety: the service talks to EXACTLY ONE fixed upstream — the
local Magpie relay — which is validated by an explicit host allowlist and
loopback/private-range check before any request is made. No user-supplied
URL is ever fetched; the only user-controlled value that reaches the
network is a model id, which is passed as a JSON field, never as a URL.

State is kept in a small JSON file on the Windows host.
"""
from __future__ import annotations

import html
import ipaddress
import json
import os
import re
import socket
import tempfile
import threading
import time
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, quote, urlparse

# --- configuration (all overridable via environment) ------------------------
# Upstream is any OpenAI-compatible gateway (Magpie is one example). Default
# points at the local Magpie relay; override with MAGPIE_BASE_URL.
GATEWAY = os.environ.get("MAGPIE_BASE_URL", "http://127.0.0.1:13425/v1")
ALLOWED_HOSTS = set(
    os.environ.get("WANG_ALLOWED_HOSTS", "127.0.0.1,localhost,172.17.0.1").split(",")
)
# State file lives under the user's local app data by default so the tool is
# portable; override with WANG_STATE.
_default_state = Path(
    os.environ.get("LOCALAPPDATA", str(Path.home())), "wang-workbench", "ai-order.json"
)
STATE_FILE = Path(os.environ.get("WANG_STATE", str(_default_state)))
PORT = int(os.environ.get("WANG_PORT", "8790"))
# Bind loopback by default (a local console should not be LAN-reachable);
# the WSL->Windows relay connects over loopback, so this is sufficient.
BIND = os.environ.get("WANG_BIND", "127.0.0.1")

DEFAULT_ORDER = [
    m
    for m in os.environ.get("WANG_DEFAULT_MODELS", "").split(",")
    if m
] or [
    "group/free",
    "group/deepseek",
    "group/kimi",
]

ROLE_DEFAULTS = {
    "项目经理": "group/free",
    "策划师": "group/kimi",
    "撰稿人": "group/micu",
    "主编": "group/deepseek",
}

_lock = threading.Lock()


def _assert_allowed(url: str) -> None:
    """Allow only the fixed Magpie relay (http + private/loopback host)."""
    p = urlparse(url)
    if p.scheme != "http":
        raise ValueError(f"blocked scheme: {p.scheme}")
    host = p.hostname or ""
    if host not in ALLOWED_HOSTS:
        raise ValueError(f"blocked host: {host}")
    for info in socket.getaddrinfo(host, p.port or 80):
        ip = ipaddress.ip_address(info[4][0])
        if not (ip.is_private or ip.is_loopback or ip.is_link_local):
            raise ValueError(f"host resolved outside private space: {ip}")


def load_state() -> dict:
    try:
        with _lock:
            if STATE_FILE.exists():
                return json.loads(STATE_FILE.read_text(encoding="utf-8"))
    except Exception:
        pass
    return {"order": list(DEFAULT_ORDER), "roles": dict(ROLE_DEFAULTS)}


def save_state(state: dict) -> None:
    """Persist state atomically; callers need a real failure signal."""
    with _lock:
        STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
        fd, temp_name = tempfile.mkstemp(prefix=".ai-order-", suffix=".tmp", dir=str(STATE_FILE.parent))
        try:
            with os.fdopen(fd, "w", encoding="utf-8") as f:
                json.dump(state, f, ensure_ascii=False, indent=2)
                f.flush()
                os.fsync(f.fileno())
            os.replace(temp_name, STATE_FILE)
        except Exception:
            try:
                os.unlink(temp_name)
            except OSError:
                pass
            raise


def _gateway_url(path: str) -> str:
    url = GATEWAY.rstrip("/") + path
    _assert_allowed(url)
    return url


def gw_get(path: str, timeout: float = 12.0):
    url = _gateway_url(path)
    req = urllib.request.Request(url, headers={"Accept": "application/json"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode())


def gateway_models() -> list[dict]:
    try:
        data = gw_get("/models")
    except Exception:
        return []
    out = []
    for m in data.get("data", []):
        out.append(
            {
                "id": m.get("id"),
                "display_name": m.get("display_name") or m.get("id"),
                "context_length": m.get("context_length"),
                "max_output_tokens": m.get("max_output_tokens"),
                "reasoning": bool(m.get("reasoning")),
                "owned_by": m.get("owned_by"),
            }
        )
    return out


def probe_model(model_id: str) -> dict:
    """One cheap chat call to confirm the model really answers.

    The model id is a JSON field value, never part of the URL.
    """
    url = _gateway_url("/chat/completions")
    payload = json.dumps(
        {
            "model": model_id,
            "messages": [{"role": "user", "content": "ping"}],
            "max_tokens": 8,
        }
    ).encode()
    req = urllib.request.Request(url, data=payload, headers={"Content-Type": "application/json"})
    t0 = time.time()
    try:
        with urllib.request.urlopen(req, timeout=45) as r:
            body = json.loads(r.read().decode())
        text = ""
        try:
            text = (body["choices"][0]["message"].get("content") or "")[:60]
        except Exception:
            pass
        return {
            "ok": True,
            "ms": int((time.time() - t0) * 1000),
            "served_as": body.get("model"),
            "sample": text.strip(),
        }
    except urllib.error.HTTPError as e:
        return {"ok": False, "ms": int((time.time() - t0) * 1000), "error": f"HTTP {e.code}"}
    except Exception as e:
        return {"ok": False, "ms": int((time.time() - t0) * 1000), "error": str(e)[:120]}


PAGE_CSS = """
:root{--bg:#f8fafc;--fg:#0f172a;--card:#fff;--line:#e2e8f0;--ice:#38bdf8;--deep:#1e3a5f;
--muted:#64748b;--ok:#059669;--bad:#dc2626}
@media (prefers-color-scheme:dark){:root{--bg:#020617;--fg:#e2e8f0;--card:#0f172a;--line:#1e293b;--muted:#94a3b8}}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--fg);
font-family:"Segoe UI","Microsoft YaHei",system-ui,-apple-system,sans-serif;padding:32px}
.wrap{max-width:1080px;margin:0 auto}
h1{font-size:24px;margin:0 0 4px;letter-spacing:-.02em}
.sub{color:var(--muted);font-size:13px;margin-bottom:24px}
.card{background:var(--card);border:1px solid var(--line);border-radius:14px;padding:20px;margin-bottom:18px;
box-shadow:0 1px 3px rgba(15,23,42,.06)}
.card h2{font-size:15px;margin:0 0 14px;display:flex;align-items:center;gap:8px}
.dot{width:8px;height:8px;border-radius:50%;background:var(--ice);display:inline-block}
table{width:100%;border-collapse:collapse;font-size:13px}
th,td{text-align:left;padding:9px 8px;border-bottom:1px solid var(--line)}
th{color:var(--muted);font-weight:600;font-size:12px;text-transform:uppercase;letter-spacing:.04em}
tr:last-child td{border-bottom:none}
code{font-family:"Cascadia Code",Consolas,monospace;font-size:12px;background:rgba(56,189,248,.12);
padding:2px 6px;border-radius:5px}
.pill{display:inline-block;padding:2px 9px;border-radius:999px;font-size:11px;font-weight:600}
.pill.ok{background:rgba(5,150,105,.14);color:var(--ok)}
.pill.bad{background:rgba(220,38,38,.14);color:var(--bad)}
.pill.idle{background:rgba(100,116,139,.16);color:var(--muted)}
select{background:var(--card);color:var(--fg);border:1px solid var(--line);border-radius:8px;padding:6px 10px;font-size:13px}
button{background:var(--deep);color:#fff;border:0;border-radius:9px;padding:9px 18px;font-size:13px;cursor:pointer;
font-weight:600}
button:hover{background:#2c5280}
button.ghost{background:transparent;color:var(--muted);border:1px solid var(--line)}
.row{display:flex;gap:10px;align-items:center;flex-wrap:wrap}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(280px,1fr));gap:12px}
.mi{background:var(--card);border:1px solid var(--line);border-radius:12px;padding:14px}
.mi h3{margin:0 0 6px;font-size:14px}
.mi p{margin:0 0 10px;color:var(--muted);font-size:12px}
.hint{background:rgba(56,189,248,.1);border-left:3px solid var(--ice);padding:10px 14px;border-radius:0 8px 8px 0;
font-size:13px;margin-bottom:16px}
#toast{position:fixed;bottom:24px;right:24px;background:var(--deep);color:#fff;padding:11px 20px;border-radius:10px;
font-size:13px;opacity:0;transition:.25s;pointer-events:none}
#toast.on{opacity:1}
"""


MODEL_ID_RE = re.compile(r"^[A-Za-z0-9._:/-]{1,160}$")


def safe_model_id(value: object) -> str:
    value = str(value)
    return value if MODEL_ID_RE.fullmatch(value) else ""


def esc(value: object) -> str:
    return html.escape(str(value), quote=True)


def page_ai_order(models: list[dict], state: dict) -> str:
    rows = []
    seen = set()
    for i, mid in enumerate(state["order"], 1):
        if mid in seen:
            continue
        seen.add(mid)
        m = next((x for x in models if x["id"] == mid), None)
        label = m["display_name"] if m else mid
        ctx_raw = m["context_length"] if m else None
        ctx = f"{ctx_raw:,}" if isinstance(ctx_raw, int) else "-"
        role = next((r for r, v in state["roles"].items() if v == mid), "")
        rows.append(
            f"<tr><td><b>{i}</b></td><td><code>{esc(mid)}</code></td><td>{esc(label)}</td>"
            f"<td>{esc(ctx)}</td><td>{esc(role or '—')}</td>"
            f"<td><button class='ghost' data-move='{i-1}' data-delta='-1'>↑</button> "
            f"<button class='ghost' data-move='{i-1}' data-delta='1'>↓</button></td></tr>"
        )
    for m in [x for x in state["order"] if x not in seen and not any(y["id"] == x for y in models)]:
        seen.add(m)
        rows.append(
            f"<tr><td><b>-</b></td><td><code>{esc(m)}</code></td><td>网关未提供（已保留）</td>"
            f"<td>-</td><td>-</td><td></td></tr>"
        )
    role_rows = "".join(
        f"<tr><td>{esc(r)}</td><td><select data-role='{esc(r)}'>"
        + "".join(
            f"<option value='{esc(m['id'])}'{' selected' if m['id'] == v else ''}>{esc(m['id'])}</option>"
            for m in models
        )
        + "</select></td></tr>"
        for r, v in state["roles"].items()
    )
    return f"""<!doctype html><html lang="zh-CN"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>AI 排序管理 · 王将军AI工作台</title><style>{PAGE_CSS}</style></head><body>
<div class="wrap">
<nav class="row" style="margin-bottom:18px"><a href="/library" style="color:var(--deep);font-weight:600;text-decoration:none">← 返回工作台</a><span class="sub" style="margin:0">/</span><a href="/wang/ai-order" style="color:var(--deep);font-weight:600">AI 排序管理</a><a href="/wang/magpie" style="color:var(--muted)">Magpie 连接</a></nav>
<h1>AI 排序管理</h1>
<div class="sub">王将军AI工作台 · 决定 AI 团队各角色优先调用哪个模型</div>
<div class="hint">顺序即优先级。AI 团队按此列表从上往下为角色挑选模型；你也可以为每个角色直接指定模型。</div>
<div class="card"><h2><span class="dot"></span>模型优先级</h2>
<table><thead><tr><th>#</th><th>模型 ID</th><th>显示名</th><th>上下文</th><th>当前角色</th><th>调整</th></tr></thead>
<tbody>{''.join(rows)}</tbody></table>
<div class="row" style="margin-top:14px"><button onclick="save()">保存配置</button>
<button class="ghost" onclick="location.reload()">重载</button>
<button class="ghost" onclick="history.length > 1 ? history.back() : location.href='/library'">← 上一级</button>
<span id="stat" class="sub"></span></div></div>
<div class="card"><h2><span class="dot"></span>角色 → 模型 指派</h2>
<table><thead><tr><th>角色</th><th>使用模型</th></tr></thead><tbody>{role_rows}</tbody></table></div>
</div><div id="toast"></div>
<script>
let order = {json.dumps(state["order"], ensure_ascii=False)};
document.querySelectorAll('[data-move]').forEach(b => b.addEventListener('click', () => move(Number(b.dataset.move), Number(b.dataset.delta))));
function move(i, d){{ const j=i+d; if(j<0||j>=order.length) return;
  [order[i],order[j]]=[order[j],order[i]]; save(false); }}
async function save(reload=true){{
  const roles = {{}}; document.querySelectorAll('select[data-role]').forEach(s=>roles[s.dataset.role]=s.value);
  const r = await fetch('/wang/api/order', {{method:'POST',headers:{{'Content-Type':'application/json'}},
    body:JSON.stringify({{order, roles}})}});
  if(r.ok){{ toast('已保存'); if(reload) setTimeout(()=>location.reload(),400); }} else toast('保存失败');
}}
function toast(m){{ const t=document.getElementById('toast'); t.textContent=m; t.classList.add('on');
  setTimeout(()=>t.classList.remove('on'),1800); }}
</script></body></html>"""


def page_magpie(models: list[dict], state: dict) -> str:
    def _num(v):
        return f"{v:,}" if isinstance(v, int) else "-"

    cards = "".join(
        f"<div class='mi'><h3><code>{esc(m['id'])}</code></h3>"
        f"<p>{esc(m['display_name'])} · 上下文 {_num(m['context_length'])} · "
        f"最大输出 {_num(m['max_output_tokens'])}</p>"
        f"<span class='pill idle'>待测</span> "
        f"<button class='ghost' data-probe-model='{esc(m['id'])}'>测试</button>"
        f"<div class='probe'></div></div>"
        for m in models
    )
    offline = "" if models else (
        "<div class='hint' style='border-color:#dc2626;background:rgba(220,38,38,.08)'>"
        "无法连接 Magpie 网关。请确认 Windows 侧 Magpie 正在运行（127.0.0.1:3425），"
        "且中继 relay.js 存活。</div>"
    )
    role_rows = "".join(
        f"<tr><td>{esc(r)}</td><td><code>{esc(v)}</code></td></tr>" for r, v in state["roles"].items()
    )
    return f"""<!doctype html><html lang="zh-CN"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Magpie 连接 · 王将军AI工作台</title><style>{PAGE_CSS}</style></head><body>
<div class="wrap">
<nav class="row" style="margin-bottom:18px"><a href="/library" style="color:var(--deep);font-weight:600;text-decoration:none">← 返回工作台</a><span class="sub" style="margin:0">/</span><a href="/wang/ai-order" style="color:var(--muted)">AI 排序管理</a><a href="/wang/magpie" style="color:var(--deep);font-weight:600">Magpie 连接</a></nav>
<h1>Magpie 连接</h1>
<div class="sub">王将军AI工作台 · 本机模型网关状态与模型清单</div>
<div class="card"><h2><span class="dot"></span>连接状态</h2>
<div class="row"><span class="pill {'ok' if models else 'bad'}">{'已连接' if models else '未连接'}</span>
<code>{GATEWAY}</code><span class="sub">可用模型 {len(models)} 个</span></div>{offline}</div>
<div class="card"><h2><span class="dot"></span>模型清单</h2>
<div class="grid">{cards or '<p class="sub">网关未返回模型。</p>'}</div></div>
<div class="card"><h2><span class="dot"></span>当前角色分配</h2>
<button class="ghost" onclick="history.length > 1 ? history.back() : location.href='/library'">← 上一级</button>
<table><thead><tr><th>角色</th><th>模型</th></tr></thead><tbody>{role_rows}</tbody></table></div>
</div><div id="toast"></div>
<script>
document.querySelectorAll('[data-probe-model]').forEach(btn => btn.addEventListener('click', () => probe(btn.dataset.probeModel, btn)));
async function probe(id, btn){{
  const card = btn.parentElement; const out = card.querySelector('.probe');
  const pill = card.querySelector('.pill'); pill.className='pill idle'; pill.textContent='测试中…';
  const r = await fetch('/wang/api/probe?model='+encodeURIComponent(id));
  const j = await r.json();
  pill.className='pill '+(j.ok?'ok':'bad'); pill.textContent=j.ok?('正常 '+j.ms+'ms'):('失败 '+j.error);
  out.textContent = j.ok ? ('实际由 '+(j.served_as||id)+' 应答') : '';
}}
</script></body></html>"""


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):
        pass

    def _send(self, code: int, body: bytes, ctype: str) -> None:
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        path = self.path.split("?")[0]
        state = load_state()
        if path == "/":
            self.send_response(302)
            self.send_header("Location", "/wang/ai-order")
            self.send_header("Content-Length", "0")
            self.end_headers()
            return
        if path == "/wang/ai-order":
            self._send(200, page_ai_order(gateway_models(), state).encode("utf-8"), "text/html; charset=utf-8")
            return
        if path == "/wang/magpie":
            self._send(200, page_magpie(gateway_models(), state).encode("utf-8"), "text/html; charset=utf-8")
            return
        if path == "/wang/api/state":
            self._send(200, json.dumps(state, ensure_ascii=False).encode(), "application/json; charset=utf-8")
            return
        if path == "/wang/api/models":
            self._send(200, json.dumps(gateway_models(), ensure_ascii=False).encode(), "application/json; charset=utf-8")
            return
        if path == "/wang/api/probe":
            from urllib.parse import parse_qs, urlparse
            q = parse_qs(urlparse(self.path).query)
            mid = (q.get("model") or [""])[0]
            self._send(200, json.dumps(probe_model(mid), ensure_ascii=False).encode(), "application/json; charset=utf-8")
            return
        self._send(404, b"not found", "text/plain")

    def do_POST(self):
        if self.path.split("?")[0] == "/wang/api/order":
            n = int(self.headers.get("Content-Length", "0"))
            raw = self.rfile.read(n) if n else b"{}"
            try:
                data = json.loads(raw.decode("utf-8"))
            except Exception:
                self._send(400, b'{"error":"bad json"}', "application/json")
                return
            state = load_state()
            if isinstance(data.get("order"), list) and data["order"]:
                state["order"] = [str(x) for x in data["order"]]
            if isinstance(data.get("roles"), dict) and data["roles"]:
                state["roles"] = {str(k): str(v) for k, v in data["roles"].items()}
            try:
                save_state(state)
            except OSError as exc:
                self._send(500, json.dumps({"ok": False, "error": str(exc)}, ensure_ascii=False).encode(), "application/json; charset=utf-8")
                return
            self._send(200, json.dumps({"ok": True}, ensure_ascii=False).encode(), "application/json; charset=utf-8")
            return
        self._send(404, b"not found", "text/plain")


def main() -> None:
    srv = ThreadingHTTPServer((BIND, PORT), Handler)
    print(f"[wang] serving on http://{BIND}:{PORT}  gateway={GATEWAY}", flush=True)
    srv.serve_forever()


if __name__ == "__main__":
    main()
