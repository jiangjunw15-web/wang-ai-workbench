#!/usr/bin/env python3
"""Create the AI-Team workflow graph in AutoGPT Platform via the external API.

Prints GRAPH_ID / GRAPH_VERSION lines on success. No file I/O here.
Only fixed-host loopback HTTP requests are allowed (no redirects followed).
"""
import ipaddress
import json
import os
import socket
import sys
import urllib.error
import urllib.request
from urllib.parse import urlparse

KEY = os.environ.get("TEAM_TOKEN", "").strip()
HEADERS = {"X-API-Key": KEY, "Content-Type": "application/json"}
ALLOWED_HOST = "127.0.0.1"


def _assert_loopback(url: str) -> None:
    p = urlparse(url)
    if p.scheme != "http" or p.hostname != ALLOWED_HOST:
        raise ValueError(f"blocked non-loopback request target: {p.hostname}")
    for info in socket.getaddrinfo(p.hostname, p.port or 80):
        ip = ipaddress.ip_address(info[4][0])
        if not ip.is_loopback:
            raise ValueError(f"host resolved to non-loopback address: {ip}")


AI_TEXT_BLOCK = "1f292d4a-41a4-4977-9684-7c8d560b9f91"

SYS_PM = (
    "你是「AI团队」的项目经理。用户会给你一个创作需求。"
    "你的输出必须包含三部分，用中文写：\n"
    "1.【需求要点】完整复述并澄清用户需求的关键点（不得省略任何原始要求）；\n"
    "2.【成品规格】成品的体裁、篇幅、结构、风格与验收标准；\n"
    "3.【分工指令】分别写给策划师、撰稿人、主编的三段任务说明，明确各自输入与期望产出。"
)
SYS_PLANNER = (
    "你是「AI团队」的策划师。用户消息里是项目经理的需求要点、成品规格与写给你的分工指令。"
    "请产出详细创作策划（中文）：整体思路、大纲（分节/分段）、每节要点、素材与亮点、风格基调。"
    "结尾附【给撰稿人的移交说明】。"
)
SYS_WRITER = (
    "你是「AI团队」的撰稿人。用户消息里是策划案。请按策划案撰写完整初稿（中文），"
    "内容完整、直接可交付，不要输出计划性文字，直接输出作品本体。"
)
SYS_EDITOR = (
    "你是「AI团队」的主编。用户消息里是撰稿人的初稿。请进行润色、查漏补缺、结构优化，"
    "并对照项目经理的成品规格验收。输出格式：先输出【最终成品】开头的成品全文，"
    "随后附简短【质检说明】（列明修改点与验收结论）。"
)

NODE_INPUT = "a1000000-0000-4000-8000-000000000000"
NODE_PM = "a1000000-0000-4000-8000-000000000001"
NODE_PLANNER = "a1000000-0000-4000-8000-000000000002"
NODE_WRITER = "a1000000-0000-4000-8000-000000000003"
NODE_EDITOR = "a1000000-0000-4000-8000-000000000004"

INPUT_BLOCK = "90a56ffb-7024-4b2b-ab50-e26c5e5ab8ba"  # AgentLongTextInputBlock


def node(nid, x, model, sys_prompt):
    return {
        "id": nid,
        "block_id": AI_TEXT_BLOCK,
        "input_default": {"model": model, "sys_prompt": sys_prompt, "retry": 2},
        "metadata": {"position": {"x": x * 340.0, "y": 0.0}},
    }


def link(lid, src, dst, source_name="response"):
    return {
        "id": lid,
        "source_id": src,
        "sink_id": dst,
        "source_name": source_name,
        "sink_name": "prompt",
        "is_static": False,
    }


GRAPH = {
    "name": "AI创作团队",
    "description": "一条指令触发 AI 团队分工协作：项目经理拆解需求 → 策划师出方案 → 撰稿人成初稿 → 主编出成品。全部模型经由本机 Magpie 网关。",
    "nodes": [
        {
            "id": NODE_INPUT,
            "block_id": INPUT_BLOCK,
            "input_default": {
                "name": "instruction",
                "value": "",
                "title": "创作需求",
                "description": "输入你的指令，AI 团队将分工完成并产出成品",
            },
            "metadata": {"position": {"x": -340.0, "y": 0.0}},
        },
        node(NODE_PM, 0, "group/free", SYS_PM),
        node(NODE_PLANNER, 1, "group/kimi", SYS_PLANNER),
        node(NODE_WRITER, 2, "group/micu", SYS_WRITER),
        node(NODE_EDITOR, 3, "group/deepseek", SYS_EDITOR),
    ],
    "links": [
        link("b1000000-0000-4000-8000-000000000000", NODE_INPUT, NODE_PM, "result"),
        link("b1000000-0000-4000-8000-000000000001", NODE_PM, NODE_PLANNER, "response"),
        link("b1000000-0000-4000-8000-000000000002", NODE_PLANNER, NODE_WRITER, "response"),
        link("b1000000-0000-4000-8000-000000000003", NODE_WRITER, NODE_EDITOR, "response"),
    ],
}


def main():
    url = "http://127.0.0.1:3000/_agpt/external-api/v1/graphs"
    _assert_loopback(url)
    req = urllib.request.Request(
        url, method="POST", headers=HEADERS, data=json.dumps(GRAPH).encode()
    )
    opener = urllib.request.build_opener()
    opener.redirect_handler = urllib.request.HTTPRedirectHandler()
    try:
        with opener.open(req, timeout=60) as r:
            created = json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        print("HTTP", e.code, e.read().decode()[:2000], file=sys.stderr)
        sys.exit(1)
    print("GRAPH_ID:", created["id"])
    print("GRAPH_VERSION:", created.get("version", 1))
    editor_id = ""
    for n in created.get("nodes", []):
        sp = (n.get("input_default") or {}).get("sys_prompt") or ""
        if "最终成品" in sp:
            editor_id = n["id"]
            break
    print("EDITOR_NODE:", editor_id)


if __name__ == "__main__":
    main()
