# 王将军AI工作台 · Wang AI Workbench

一个把 **AutoGPT Platform** 变成「私人/团队专属 AI 工作台」的开源套件：
原生 Windows 桌面客户端 + 本机 LLM 网关接入 + 自有管理控制台 + 一键部署脚本。

它不是 AutoGPT 的 fork，而是**围绕官方 AutoGPT 单容器镜像的一层定制与封装**：
官方镜像保持不动，所有定制都以「构建产物补丁 + 独立服务 + 桌面外壳」的方式叠加，
因此可以随时跟随官方升级。

## 它能做什么

- **桌面客户端**：无地址栏的原生窗口（WPF + WebView2），自绘标题栏、系统托盘常驻、
  返回/前进/刷新、开机自启、一键拉起本机服务。
- **LLM 网关接入**：把任意 OpenAI 兼容网关（如 Magpie、one-api、new-api 等）注册为
  AutoGPT 的一个模型供应商，网关里的模型会出现在平台所有 AI 积木的下拉框中。
- **自有控制台**：两个平台没有的页面——
  - `AI 排序管理`：调整模型优先级、为团队各角色指派模型；
  - `Magpie 连接`：网关连通状态、模型清单、逐模型探活。
- **界面定制**：中文 UI、自有品牌 Logo/字标、自定义主题色、移除付费/遥测入口。
- **AI 团队工作流**：一条指令触发多角色分工（项目经理→策划→撰稿→主编）产出成品。

## 目录结构

```
desktop/          桌面客户端 (WPF) + 安装器 (Win32) + 端口中继 relay.js
console/          自有管理控制台 (Python, 无第三方依赖)
platform/         AutoGPT 部署与补丁脚本 (bootstrap + LLM 网关补丁 + nginx)
brand/            品牌资产与前端定制补丁 (Logo/主题/中文/侧边栏/免费化)
docs/             安装、架构、定制、安全说明
```

## 快速开始

要求：Windows 10/11 x64、已启用 WSL2、Docker、Microsoft Edge WebView2 Runtime、Node.js（仅中继需要）。

1. **部署平台**（在 WSL 里跑 AutoGPT 单容器并接入你的网关）：
   ```bash
   bash platform/bootstrap.sh
   ```
   可用环境变量自定义：`WSL_DISTRO`、`CONTAINER`、`IMAGE`、`GATEWAY_HOST`、`GATEWAY_PORT`、`MODELS_JSON`。
2. **应用前端定制**（中文/品牌/主题/免费化，可选）：见 `docs/CUSTOMIZE.md`。
3. **安装桌面端**：构建或直接运行安装器，见 `docs/INSTALL.md`。
4. 打开桌面端或浏览器访问 `http://localhost:3000`。

## 配置

所有 site-specific 值都通过**环境变量或旁边的配置文件**提供，没有硬编码机器路径：

| 变量 | 作用 | 默认 |
| --- | --- | --- |
| `MAGPIE_BASE_URL` | OpenAI 兼容网关地址 | `http://127.0.0.1:3425/v1` |
| `WANG_PORT` / `WANG_BIND` | 控制台端口 / 监听地址 | `8790` / `127.0.0.1` |
| `WANG_STATE` | 模型排序状态文件 | `%LOCALAPPDATA%\wang-workbench\ai-order.json` |
| `WANG_RELAYS` | 中继映射 `name:listen:host:port,...` | magpie/proxy/wang 三条 |
| `WANG_RELAY_BIND` | 中继监听地址 | `0.0.0.0` |
| `WSL_DISTRO` / `CONTAINER` | WSL 发行版 / 容器名 | `wang-workbench` |

桌面端可通过 `WANG_SERVICE_BAT` 指定自定义服务启动脚本。

## 许可

MIT，见 [LICENSE](LICENSE)。AutoGPT 本体以其自身许可证为准，本项目不修改其源码分发。
