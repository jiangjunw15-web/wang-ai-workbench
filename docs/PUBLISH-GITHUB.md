# 发布到 GitHub（GitHub Desktop）

仓库已在本地完成初始化与提交（分支 `main`），无需命令行推送。

## 步骤

1. 打开 **GitHub Desktop**。
2. `File → Add Local Repository…`，选择本仓库根目录（含 `.git` 的文件夹）。
3. 若提示 "publish this repository to GitHub"，点击 **Publish repository**。
4. 填写：
   - **Name**：`wang-ai-workbench`（或你喜欢的名字）
   - **Description**：`AutoGPT 私人工作台：桌面客户端 + LLM 网关接入 + 自有控制台`
   - **Visibility**：Public（开源）
   - 不要勾选 "setup CI" 之类可选项（除非你想要）。
5. 点 **Publish Repository**。GitHub Desktop 会把本地 `main` 推上去。

## 发布 Release（可选）

构建产物（安装器/便携 EXE）**不放进 git**（见 .gitignore）。要发 Release：

1. 本地构建：`cd desktop && bash build-installer.sh`
2. GitHub 网页 → 仓库 → Releases → New release → tag `v1.0.0`
3. 把 `desktop/setup/王将军AI工作台安装程序.exe` 作为 release asset 上传。

## 检查清单（发布前）

- [ ] `git status` 干净
- [ ] 无凭据：`git grep -niE "password|api_key|secret" -- '*.md' '*.json'` 只应命中示例/占位
- [ ] README 的安装步骤在一台**干净机器**上可走通（至少 bootstrap + 桌面端）
