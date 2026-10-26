# v0.1.0 — 王将军AI工作台（AutoGPT Platform × Magpie 网关）

首个版本：把官方 AutoGPT Platform 单容器镜像改造成一台**私人专属**的中文 AI 工作台，全部模型经本机 Magpie 网关免费接入，并跑通「AI 创作团队」四角色流水线。

## 本次实测

一次完整的「AI 创作团队」运行（2026-10-26 15:18，北京时间）：

| 环节 | 角色 | 模型 | 结果 |
| --- | --- | --- | --- |
| 1 | 项目经理 | `group/free` | 通过 |
| 2 | 策划师 | `group/kimi` | 通过 |
| 3 | 撰稿人 | `group/micu` | 通过 |
| 4 | 主编 | `group/deepseek` | 通过 |

- 指令：`写一篇约300字的短视频口播脚本，主题：秋天的第一杯热奶茶，风格温暖治愈，结尾带一句自然的行动号召。`
- 耗时：约 120 秒（建图已完成，仅执行阶段）
- 产物：`outputs/team-20261026-151839.md`（2663 字节），含【最终成品】43 秒竖屏分镜口播稿 + 【质检说明】5 条修改点与验收结论

## 组件

| 组件 | 位置 | 说明 |
| --- | --- | --- |
| 平台本体 | WSL 发行版 `AutoGPT` | 官方镜像 `significantgravitas/autogpt:latest`，单容器全家桶 |
| Magpie 供应商补丁 | `wsl/patch_magpie.py` | 新增 `magpie` LLM 供应商（OpenAI 兼容、免密钥、指向 `127.0.0.1:3425`） |
| 团队工作流 | `wsl/team_graph.py`、`wsl/run_team.sh` | 建图一次，之后一条命令执行并落盘 |
| 自有控制台 | `wang/wang_service.py`（Windows 8790） | AI 排序管理 / Magpie 连接探活 |
| 品牌与汉化 | `brand/`、`i18n/` | 构建产物级改写：冰蓝主题、Logo、约 200 条中文词表 |
| 桌面端 | `desktop/WangDesktop`、`desktop/WangInstaller` | WPF + WebView2 外壳与安装器（编译产物不入库） |

## 已知限制

1. **`group/free` 上游频控**：实测出现 `429 — 您的使用量已超出频率限制`，重置时间由上游给出。同一时段其余三个分组模型正常。
2. 团队图第一个节点（项目经理）默认 `group/free`，被限流时整条流水线中断；**图状态仍显示 COMPLETED，但成品文件为空（0～1 字节）**，请按文件大小判断成败。
3. 偶发 `Connection aborted / RemoteDisconnected`（上游或代理瞬断），重跑即恢复。

## 安装与使用

```powershell
# 平台启停
D:\automate\start-platform.bat
D:\automate\stop-platform.bat

# 命令行跑一次 AI 创作团队
wsl -d AutoGPT -u root -- bash /mnt/d/automate/wsl/run_team.sh "你的创作指令"
```

桌面端安装包与便携版为本地构建产物（体积数百 MB），不入库也不随本 Release 分发；可用 `desktop/build-installer.sh` 重新生成。

## 产物校验和（SHA-256）

```
8a16b971d925b74529f560327fe9b24522b5c1caaab47bca0860f07d15ddb8f7  team-20261026-010312.md
6e58e173ee38807cf4d85a80b7c897a7c914f95930d20102a5e138ad6900edcd  team-20261026-010832.md
5864c60a83d56be8a51be73f22f69547714ca3ad3ee75c8f691d1775678af5aa  team-20261026-151839.md
```

## 备注

- 本仓库只含源码与脚本：WSL 发行版磁盘（约 10 GB）、桌面端二进制（约 900 MB）、账号密钥文件均在 `.gitignore` 中排除。
- 平台界面的汉化与品牌化是**构建产物级改写**，升级官方镜像后需重跑 `i18n/apply.sh` 与 `brand/apply.sh`。
