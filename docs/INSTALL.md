# 安装指南 INSTALL

## 前置条件

- Windows 10/11 x64
- WSL2 已启用（`wsl --install`）
- Docker（在 WSL 发行版内安装 docker-ce）
- Microsoft Edge WebView2 Runtime（Win11 通常自带）
- Node.js（仅端口中继 relay.js 需要）
- 一个 OpenAI 兼容的 LLM 网关（可选；没有也能用平台自带供应商）

## 1. 部署平台

```bash
# 在任意 shell（Git Bash / WSL）中
export WSL_DISTRO=wang-workbench      # 你的 WSL 发行版名
export CONTAINER=wang-workbench       # 容器名
export MAGPIE_BASE_URL=http://127.0.0.1:3425/v1   # 你的网关（经中继）
bash platform/bootstrap.sh
```

bootstrap 会：确认发行版与 docker → 运行官方单容器镜像 → 应用 LLM 网关补丁。
若你的发行版尚未导入，先：

```bash
wsl --import wang-workbench <安装目录> <ubuntu-rootfs.tar.gz> --version 2
```

## 2. （可选）前端定制

中文 / 品牌 / 主题 / 免费化都是对构建产物的补丁，见 [CUSTOMIZE.md](CUSTOMIZE.md)。
全部为幂等脚本，可重复执行；改过的文件自动备份。

## 3. 安装桌面端

方式 A — 用安装器（推荐）：

```bash
cd desktop
bash build-installer.sh        # 发布桌面端 + 打包单文件安装器
./setup/王将军AI工作台安装程序.exe
```

安装器会创建桌面/开始菜单快捷方式、当前用户开机自启、独立卸载程序。

方式 B — 便携运行：

```bash
cd desktop/WangDesktop
dotnet publish -c Release -r win-x64 --self-contained true -o ../publish
../publish/WangDesktop.exe
```

## 4. 启动自有控制台

```bash
bash console/start.sh
```

控制台默认监听 `127.0.0.1:8790`（仅回环，安全）。平台通过
`/wang/...` 路径反代到它（bootstrap 已配置 nginx 路由）。

## 卸载

- 桌面端：控制面板 → 应用 → 王将军AI工作台 → 卸载（或运行安装目录下的
  `卸载王将军AI工作台.exe`）。
- 平台：`wsl -d $WSL_DISTRO -u root -- docker rm -f $CONTAINER`。
