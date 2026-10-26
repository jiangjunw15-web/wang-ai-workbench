# 王将军AI工作台（AutoGPT Platform × Magpie 网关）

一台 Windows 机器上的**私人专属**工作台：**AutoGPT Platform（官方单容器镜像）+ 本机 Magpie 网关全量模型接入 + 「AI 创作团队」工作流 + 自有品牌/主题/控制台**。

## 交付了什么

| 组件 | 位置 | 说明 |
| --- | --- | --- |
| 平台本体 | WSL 发行版 `AutoGPT`（数据在 `D:\automate\wsl\distro`） | 官方镜像 `significantgravitas/autogpt:latest`，单容器全家桶（前端/API/执行器/PG/RabbitMQ/Valkey/FalkorDB） |
| Magpie 接入补丁 | WSL `/root/agpt-patch/`（源文件在 `wsl/` 目录的脚本） | 新增 `magpie` LLM 供应商：OpenAI 兼容、免密钥、指向本机网关 `127.0.0.1:3425` |
| AI 创作团队工作流 | 平台内「AI创作团队」 | 输入指令 → 项目经理(GLM) → 策划师(Kimi) → 撰稿人(米醋) → 主编(DeepSeek) → 成品 |
| **AI 排序管理** | `http://localhost:3000/wang/ai-order` | 自有页面：读取 Magpie 实时模型清单，拖动调序 + 为每个角色指派模型，配置存 `D:\automate\ai-order.json` |
| **Magpie 连接** | `http://localhost:3000/wang/magpie` | 自有页面：网关连通状态、模型清单、逐模型探活（实测能看出实际路由到哪个后端） |
| **Windows 桌面客户端** | `D:\automate\desktop\setup\王将军AI工作台安装程序.exe` | 原生 WPF + WebView2 桌面壳；无地址栏、托盘常驻、返回/前进/刷新、自绘标题栏、自动拉起本机服务 |
| **便携版** | `D:\automate\desktop\publish\WangDesktop.exe` | 自包含 win-x64 单文件，目标机不需要 .NET Runtime（仍需 Microsoft Edge WebView2 Runtime） |
| 成品输出目录 | `D:\automate\outputs\` | 每次 AI 团队运行落盘一个 `team-<时间戳>.md` |

**Magpie 里的全部模型都可用**（出现在所有 AI 块的模型下拉框，运行时走本机网关）：
`group/free`、`group/deepseek`、`group/kimi`、`group/micu`、`auto/deepseek-v4-flash`、`auto/minimax-m3.1-flash`、`deepseek/deepseek-v4-flash`（网关侧另有 `auto/kimi-k3.1-pro-highspeed`、`auto/kimi-k2.7-code-highspeed` 自动出现在「AI 排序管理」的下拉里）

## 私人化定制（相对官方版）

| 项目 | 官方默认 | 本机定制 |
| --- | --- | --- |
| 平台名称 | AutoGPT Platform | **王将军AI工作台** |
| Logo / favicon | AutoGPT | 自制（冰蓝底 + 金冠 + 「王」字，脚本 `brand/make_logos.py` 可重生成） |
| 主色调 | 紫 / 靛蓝渐变 | **冰蓝**：主色 `#1E3A5F`、强调 `#38BDF8`、侧栏 `#0F172A`、背景 `#F8FAFC`（亮/暗双主题，`brand/theme_tokens.py`） |
| 侧边栏 | 首页 / 市场 / 搭建 / 团队 / 文件 | 首页 / **搭建** / 团队 / 文件 / **AI 排序管理** / **Magpie 连接**（已移除「市场」） |
| 付费 | 升级 Pro、买积分、订阅横幅 | **全部免费**：18 处付费文案改为「本平台免费」，34 处遥测端点重定向到本机 |
| 注册 | 开放注册 | `AUTH_ALLOW_NEW_ACCOUNTS=false`（仅本机管理员账户） |
| 外发数据 | PostHog / Sentry / Langfuse / Stripe / MailerLite / Postmark | **全部关闭**（Key 清空 + 端点重定向） |

定制实现方式：官方镜像没有 i18n 与主题配置接口，所以采用**构建产物级改写**——在 `.next` 产物里原地替换文案 / 令牌 / 品牌串，再对改过的 chunk 追加 `.wang1` 后缀强制浏览器重新拉取。整套流程在 `brand/apply.sh`（幂等，可重复执行），所有被改文件都备份在容器 `/root/zh_backup/`。

品牌化的前端已持久化在 Docker 卷 `wang-frontend`，**重建容器不会丢失**。

## Windows 桌面端怎么用

1. 双击 `desktop\setup\王将军AI工作台安装程序.exe`，安装器会创建桌面快捷方式、开始菜单快捷方式和当前用户开机自启。
2. 安装后双击桌面的 **王将军AI工作台**。桌面端会自动检查并拉起本机 WSL/Docker 服务。
3. 桌面窗口顶部有：`←` 返回、`→` 前进、`刷新`、最小化、最大化、关闭（关闭默认收进系统托盘；托盘菜单“退出”才真正退出）。
4. 返回键也支持 `Alt+←`，前进支持 `Alt+→`，刷新支持 `F5`。
5. 安装器要求目标机已安装 Microsoft Edge WebView2 Runtime；Windows 11 通常已自带。
6. 从“应用和功能”卸载时，使用独立卸载程序；它会关闭桌面进程、清理快捷方式、自启项、卸载登记和安装目录。

便携版 `desktop\publish\WangDesktop.exe` 可直接运行，但不会创建快捷方式/卸载登记；它仍依赖本机的 AutoGPT WSL 环境和 WebView2 Runtime。

## 怎么用

1. 打开 **http://localhost:3000**，账号见 `platform-info.txt`。
2. 左侧 **Workflows** → 「AI创作团队」→ Run → 填「创作需求」→ 运行。
3. **AI 排序管理**（侧边栏）：调模型优先级、给项目经理/策划师/撰稿人/主编分别指定模型，保存后生效。
4. **Magpie 连接**（侧边栏）：看网关是否在线、逐个模型点「测试」探活。
5. 命令行跑团队：`wsl -d AutoGPT -u root -- bash /mnt/d/automate/wsl/run_team.sh "你的创作指令"`

平台的 Copilot 对话也已切到 Magpie（`CHAT_*` 环境变量，模型 `group/free`）。

## 启停

- 开机自启：登录时自动执行（启动文件夹里的 `autogpt-platform-autostart.vbs`）——拉起端口中继 + 王将军控制台服务 + 保活 WSL + 容器自启。
- 手动：`start-platform.bat` / `stop-platform.bat`（本目录）。桌面端服务脚本会先检查端口，避免重复启动 relay。
- Wang 控制台：Windows 8790；容器通过 WSL 18790 中继访问，管理页在 `/wang/ai-order` / `/wang/magpie`。
- 发布/升级：运行 `desktop\build-installer.sh`，它会先发布桌面 EXE、再嵌入安装器，最终唯一安装器为 `desktop\setup\王将军AI工作台安装程序.exe`。
- 账号与 API Key：见 `platform-info.txt`（本目录），WSL 内同样存于 `/root/autogpt_account.env`。
- 自有控制台服务：`wang/wang_service.py`（Windows 侧 8790 端口），改完重启：`bash D:\automate\wang\start.sh`。


## 架构与网络通路（重要）

```
浏览器 → http://localhost:3000 (WSL 端口转发) → 容器 nginx → 前端/后端
后端容器 → 172.17.0.1:13425 (WSL 内 socat) → Windows 网关 IP:13425 (relay.js) → 127.0.0.1:3425 Magpie 网关
docker 拉镜像 → 127.0.0.1:17897 (socat) → relay.js → 127.0.0.1:7897 mihomo 代理
```

- `D:\automate\relay.js`：Windows 侧 TCP 中继（Magpie 3425→13425、代理 7897→17897），因为这两个服务只监听 127.0.0.1。
- WSL 内 systemd 服务：`magpie-relay.service`、`proxy-relay.service`（socat，桥接容器↔Windows）。
- WSL 镜像网络模式不可用（与 VMware 网卡冲突，自动回退 NAT），所以用中继方案。

## 中文界面（zh-CN）

平台官方**没有**多语言框架（`dictionaries/` 只是无引用的示例文件），界面文字硬编码在构建产物里。本地部署采用「**产物级汉化**」：把高频 UI 文案在 `.next` 构建产物里原地替换，不碰运行逻辑。

- 词表：`i18n/zh-cn.json`（约 200 条，按导航/动作/状态/标签/消息/登录分组）
- 替换脚本：`i18n/patch_bundle.py`（匹配 `"en"`/`'en'`/`` `en` `` 三种引号形式，含 `\uXXXX` 转义目标；短单词白名单防误伤代码标识符；每文件替换前备份到容器 `/root/zh_backup/`）
- 一键应用：`i18n/apply.sh`（打补丁 → 506 个 chunk 语法校验 → 重启 `runtime:next`）
- nginx 已对 `/_next/static/` 强制 `no-cache, must-revalidate`，浏览器每次都会校验，汉化更新即时生效
- 验证：`i18n/verify.sh`（服务端中英文计数，直接证明服务端输出）

**重要**：汉化是**服务端**行为，服务端输出的 HTML 已 100% 中文。若你自己的浏览器仍显示英文，那是浏览器自身的 HTTP 磁盘缓存——用 `Ctrl+Shift+R` 硬刷新，或开一个新窗口/新标签访问 `http://localhost:3000` 即可。换 `http://127.0.0.1:3000` 也能拿到全新页面（但该源登录会被 CSRF 拒绝 403，平台只放行 `localhost` 源，**日常请用 localhost**）。

升级官方镜像后重打补丁：重跑 `i18n/apply.sh`（词表和脚本都在本机，不需要重新克隆）。


## 补丁内容（叠加在官方镜像之上，文件挂载方式）

1. `integrations/providers.py`：新增 `ProviderName.MAGPIE`。
2. `util/llm/providers.py`：新增 `magpie` 分支 → `_call_openai_compat(base_url=$MAGPIE_BASE_URL)`。
3. `blocks/llm.py`：LLMProviderName 加入 magpie；magpie 模型免密钥（同 Ollama 机制）。
4. `data/llm_registry/catalog.py`：注册 magpie 供应商 + 7 个模型（目录即代码）。
5. `data/llm_registry/llm_models.py`：LLMModel 枚举加入 7 个模型。
6. `data/block_cost_config.py`：magpie 模型运行免费（本地网关）。

升级官方镜像后重打补丁：重跑 `wsl/extract_patch.sh`（或按 `wsl/patch_magpie.py` 的锚点更新），再重建容器（`wsl/run_platform.sh`）。

## 故障排查

- 平台打不开：先跑 `start-platform.bat`；检查 `wsl -d AutoGPT -u root -- docker ps`。
- 模型调用失败（连不上网关）：确认 Windows 上 Magpie 在跑（127.0.0.1:3425）、relay.js 在跑（`tasklist | findstr node`）、WSL 内 `systemctl status magpie-relay`。
- WSL 被自动回收导致平台"自己停了"：keepalive 已处理（`sleep infinity` 常驻 + `vmIdleTimeout=86400000`）。
- 首次启动的「skills catalog 发布」已用 `AUTOGPT_PUBLISH_SKILLS=false` 关闭（该步骤在本机网络下不稳定，不影响功能）。
