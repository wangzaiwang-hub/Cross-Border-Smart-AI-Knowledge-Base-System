# Windows WSL2 与 Docker Desktop 手工安装配置操作文档

## 第一部分：检查 Windows、处理器虚拟化和现有安装

### 第一步：确认操作系统版本

**在哪里操作**：客户 Windows 本机键盘和系统窗口，不是在 Rocky Linux 虚拟机、SSH、Docker 容器或 Ubuntu WSL 中操作。

1. 同时按 `Win + R`。
2. 输入：

```text
winver
```

3. 点击“确定”。

**执行后的结果**：打开“关于 Windows”窗口，记录 Windows 版本和操作系统内部版本。

本项目建议使用 Windows 11 64 位 23H2 或更高版本。Docker 官方当前要求 WSL2 后端至少满足 Windows 11 23H2（内部版本 22631）或受支持的 Windows 10 22H2（内部版本 19045）。Windows Server 不能按本文安装 Docker Desktop。

### 第二步：确认 Windows 是 64 位 x64

**在哪里操作**：Windows 本机“设置”。

1. 右键“此电脑”。
2. 点击“属性”。
3. 在“系统类型”处确认内容。

**执行后的结果**：应显示“64 位操作系统，基于 x64 的处理器”。

如果是 ARM64，本文中的 `x86_64` 镜像摘要和 Windows x64 安装包不适用；如果是 32 位 Windows，不能继续安装本项目环境。

### 第三步：确认物理内存和磁盘空间

**在哪里操作**：Windows 本机 PowerShell。

1. 按 `Win + X`。
2. 点击“终端”或“Windows PowerShell”。
3. 输入：

```powershell
Get-CimInstance Win32_ComputerSystem | Select-Object TotalPhysicalMemory
Get-PSDrive -PSProvider FileSystem | Select-Object Name,Used,Free
```

**执行后的结果**：显示内存字节数和各磁盘剩余空间。

本项目客户电脑建议至少 16 GB 物理内存。Docker Desktop 数据盘至少保留 30 GB；如果只有 8 GB 内存，不适合同时运行 IDEA Java 服务、Docker Desktop 和 VMware 虚拟机，不能声称可以全量常驻。

### 第四步：确认 BIOS/UEFI 虚拟化已启用

**在哪里操作**：Windows 本机任务管理器。

1. 按 `Ctrl + Shift + Esc` 打开任务管理器。
2. 点击“性能”。
3. 点击“CPU”。
4. 查看右下角“虚拟化”。

**执行后的结果**：必须显示“已启用”。

如果显示“已禁用”：

1. 记录电脑品牌和型号。
2. 重启电脑进入 BIOS/UEFI。
3. 找到 Intel `VT-x/Intel Virtualization Technology` 或 AMD `SVM Mode/AMD-V`。
4. 设置为 `Enabled`。
5. 保存并退出 BIOS。
6. 回到 Windows 重新检查。

不同品牌进入 BIOS 的按键不同，常见为 `F2`、`Delete`、`F10` 或 `Esc`。不要在不知道选项用途时修改磁盘模式、安全启动或 TPM。

### 第五步：检查是否已有 Docker Desktop

**在哪里操作**：Windows 本机“设置”和 PowerShell。

1. 打开“设置”→“应用”→“已安装的应用”。
2. 搜索 `Docker Desktop`。
3. 回到 PowerShell输入：

```powershell
Get-Command docker -ErrorAction SilentlyContinue
docker version
```

**执行后的结果**：

1. 全新电脑通常找不到 Docker Desktop，`docker` 命令不存在。
2. 已安装且正在运行时，`docker version` 同时显示 Client 和 Server。
3. 只显示 Client 或报 `dockerDesktopLinuxEngine`/`docker_engine` 管道错误，说明程序存在但 Engine 未运行。

**需要修改的内容**：已有 Docker Desktop 时不要直接覆盖或卸载。先执行下面命令记录现有容器、镜像和卷：

```powershell
docker ps -a
docker images
docker volume ls
docker info --format 'Version={{.ServerVersion}} OSType={{.OSType}} RootDir={{.DockerRootDir}} Mirrors={{json .RegistryConfig.Mirrors}}'
```

已有客户业务容器时必须先备份，不能执行“恢复出厂设置”。

## 第二部分：安装和验证 WSL2

### 第一步：检查 WSL 当前版本

**在哪里操作**：Windows 本机管理员 PowerShell。

1. 点击开始菜单。
2. 输入 `PowerShell`。
3. 右键“Windows PowerShell”或“终端”。
4. 点击“以管理员身份运行”。
5. 输入：

```powershell
wsl --version
```

**执行后的结果**：现代 WSL 会显示 WSL、内核、WSLg 和 Windows 版本。Docker Desktop 当前要求 WSL 2.1.5 或更高版本。

如果只显示帮助文本、提示参数无效或没有版本信息，说明是旧的系统内置 WSL，需要按第三步更新。

### 第二步：检查两个 Windows 可选功能

**在哪里操作**：Windows 本机管理员 PowerShell。

输入：

```powershell
Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux |
  Select-Object FeatureName,State
Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform |
  Select-Object FeatureName,State
```

**执行后的结果**：下面两个功能都应为 `Enabled`：

```text
Microsoft-Windows-Subsystem-Linux
VirtualMachinePlatform
```

### 第三步：安装或更新 WSL

**在哪里操作**：Windows 本机管理员 PowerShell。

全新电脑输入：

```powershell
wsl --install --no-distribution
```

已有 WSL 时输入：

```powershell
wsl --update
```

**执行后的结果**：系统启用 WSL 和虚拟机平台，安装或更新 WSL 内核，并可能提示需要重启。

如果 `--no-distribution` 不被当前 Windows 识别，输入：

```powershell
wsl --install
```

这可能同时安装 Ubuntu。Ubuntu 可以保留，但本项目源码、Java 服务和前端仍在 Windows 本机运行，不放到 Ubuntu 中。

### 第四步：重启 Windows

**在哪里操作**：Windows 本机开始菜单。

1. 关闭正在编辑的文件。
2. 点击“开始”→“电源”→“重启”。
3. 等待重新登录 Windows。

**执行后的结果**：Windows 可选功能和 WSL2 内核正式生效。

### 第五步：设置新发行版默认使用 WSL2

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
wsl --set-default-version 2
wsl --status
wsl -l -v
```

**执行后的结果**：默认版本显示 `2`。如果安装了 Ubuntu，其 `VERSION` 应为 `2`。

Ubuntu 是客户可选的命令行环境，不是 Rocky Linux 虚拟机，也不是 Docker Desktop 自己的 `docker-desktop` 发行版。这三个环境不能混为一处。

### 第六步：Microsoft Store 被禁用时安装 WSL

**在哪里操作**：Windows 本机浏览器和管理员 PowerShell，仅在 `wsl --update` 因企业策略失败时执行。

1. 打开微软官方 WSL 发布页：`https://github.com/microsoft/WSL/releases`。
2. 展开最新稳定版本的 `Assets`。
3. x64 电脑下载 `.x64.msi` 安装包，不下载 ARM64 包。
4. 双击 MSI。
5. 按安装向导完成安装。
6. 回到管理员 PowerShell输入：

```powershell
wsl --version
wsl --status
```

**执行后的结果**：显示完整 WSL 版本，并且版本不低于 2.1.5。

## 第三部分：下载并安装 Docker Desktop

### 第一步：从 Docker 官方网站下载安装包

**在哪里操作**：Windows 本机浏览器。

1. 打开 Docker 官方安装文档：`https://docs.docker.com/desktop/setup/install/windows-install/`。
2. 点击页面中的 `Docker Desktop for Windows - x86_64` 下载按钮。
3. 也可以打开产品页：`https://www.docker.com/products/docker-desktop/`，点击 `Download for Windows`。
4. 浏览器下载文件名应为：

```text
Docker Desktop Installer.exe
```

5. 把文件保存到：

```text
D:\ygh-installers\docker-desktop
```

目录不存在时，在资源管理器中依次创建 `D:\ygh-installers` 和 `docker-desktop`。

**执行后的结果**：Windows 本机得到 Docker 官方 EXE 安装包。不要从网盘、软件下载站或不明镜像下载修改版安装器。

### 第二步：检查安装包数字签名

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
Get-AuthenticodeSignature 'D:\ygh-installers\docker-desktop\Docker Desktop Installer.exe' |
  Select-Object Status,StatusMessage,@{Name='Signer';Expression={$_.SignerCertificate.Subject}}
```

**执行后的结果**：`Status` 必须是 `Valid`，签名者应包含 Docker。

如果是 `NotSigned`、`HashMismatch` 或签名无效，删除安装包，重新从 Docker 官方页面下载，不能继续安装。

### 第三步：选择安装模式和安装目录

**在哪里操作**：Windows 本机安装向导。

本项目交付电脑统一采用“所有用户”安装模式，默认安装到：

```text
C:\Program Files\Docker\Docker
```

1. 右键 `Docker Desktop Installer.exe`。
2. 点击“以管理员身份运行”。
3. Windows 用户账户控制弹窗点击“是”。
4. 如果安装器询问 `Install for me only` 或 `Install for all users`，选择所有用户。
5. 在配置页保持 `Use WSL 2 instead of Hyper-V` 选中。
6. 不需要 Windows 容器时，不启用 Windows containers。
7. 点击 `OK` 或 `Install`。

**执行后的结果**：安装器把 Docker Desktop 程序安装到 `C:\Program Files\Docker\Docker`，并配置 WSL2 后端所需组件。

**注意事项**：Docker 新版也支持每用户安装到 `%LOCALAPPDATA%\Programs\DockerDesktop`。客户若已由单位管理员采用每用户模式，不要混装第二套；本文后续命令在两种模式下相同。

### 第四步：完成安装并重新登录

**在哪里操作**：Windows 本机安装向导和开始菜单。

1. 等待安装进度完成。
2. 出现 `Installation succeeded` 时点击 `Close`。
3. 安装器要求注销时点击 `Log out`，然后重新登录。
4. 没有要求注销时也建议重启一次 Windows。

**执行后的结果**：开始菜单中出现 `Docker Desktop`。

### 第五步：第一次启动 Docker Desktop

**在哪里操作**：Windows 本机开始菜单和 Docker Desktop 窗口。

1. 点击开始菜单。
2. 搜索并打开 `Docker Desktop`。
3. 阅读 Docker Subscription Service Agreement。
4. 客户确认许可符合自身使用场景后，勾选接受并点击 `Accept`。
5. 要求登录时，按客户单位策略登录；界面允许跳过时可以先跳过。
6. 等待主界面显示 Docker Engine 正在运行。

**执行后的结果**：任务栏右下角出现 Docker 图标，Docker Desktop 主界面可打开。

### 第六步：确认使用 WSL2 和 Linux 容器

**在哪里操作**：Windows 本机 Docker Desktop。

1. 点击 Docker Desktop 右上角齿轮 `Settings`。
2. 点击 `General`。
3. 确认 `Use the WSL 2 based engine` 已启用。
4. 点击 `Apply & restart`（只有修改后才需要点击）。
5. 在任务栏右下角右键 Docker 图标。
6. 如果菜单显示 `Switch to Linux containers`，点击它；如果显示 `Switch to Windows containers`，说明当前已经是 Linux 容器，不要点击。

**执行后的结果**：本项目 Docker 容器运行在 Docker Desktop 的 Linux/WSL2 后端。

### 第七步：确认 docker-desktop 发行版

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
wsl -l -v
```

**执行后的结果**：列表中出现 `docker-desktop`，版本为 `2`，Docker 运行时状态通常是 `Running`。

**安装位置说明**：

1. Docker Desktop 程序在 Windows `C:\Program Files\Docker\Docker`。
2. Linux Docker Engine 在 Docker Desktop 管理的 `docker-desktop` WSL2 环境中。
3. 镜像、容器和命名卷保存在 Docker Desktop 的虚拟磁盘中。
4. 本项目源码仍在 Windows 普通目录，由 IDEA 打开。
5. Rocky Linux 虚拟机有另一套独立 Docker Engine，两边镜像、容器和卷互不共享。

## 第四部分：配置 Docker Desktop 内存、CPU、磁盘和启动行为

### 第一步：设置 Docker Desktop 开机启动

**在哪里操作**：Windows 本机 Docker Desktop。

1. 打开 `Settings` → `General`。
2. 启用 `Start Docker Desktop when you sign in to your computer`。
3. 点击 `Apply & restart`。

**执行后的结果**：客户登录 Windows 后 Docker Desktop 自动启动。Java 服务仍由 IDEA 人工启动，不会被 Docker Desktop批量启动。

### 第二步：检查 Docker 可用 CPU 和内存

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
docker info --format 'CPUs={{.NCPU}} MemoryBytes={{.MemTotal}} OSType={{.OSType}} Architecture={{.Architecture}}'
```

**执行后的结果**：本项目 16 GB Windows 电脑建议 Docker 显示至少 4 CPU、约 4 GB 内存、`OSType=linux`、`Architecture=x86_64`。

### 第三步：手工创建 .wslconfig

**在哪里操作**：Windows 本机 PowerShell和记事本。该文件控制所有 WSL2 虚拟机上限，包括 Docker Desktop；它不控制 VMware 中的 Rocky Linux。

输入：

```powershell
notepad "$HOME\.wslconfig"
```

文件不存在时点击“是”，粘贴：

```ini
[wsl2]
memory=4GB
processors=4
swap=1GB
```

1. 点击“文件”→“另存为”。
2. 文件名保持 `.wslconfig`，不能变成 `.wslconfig.txt`。
3. “保存类型”选择“所有文件”。
4. 编码选择 `UTF-8`。
5. 保存到当前 Windows 用户目录，例如 `C:\Users\客户用户名\.wslconfig`。

**需要修改的内容**：

1. 物理内存为 16 GB 时使用 `memory=4GB`。
2. 物理内存大于 32 GB 且要同时运行多个场景组件时，可由实施人员评估改为 6 GB 或 8 GB。
3. `processors` 不能超过电脑逻辑处理器数量；只有 2 核时写 2，但低配置电脑不适合全量场景。
4. 不要把 `memory` 写成没有单位的数字。

### 第四步：让 .wslconfig 生效

**在哪里操作**：Windows 本机任务栏、Docker Desktop 和 PowerShell。

1. 在任务栏右下角右键 Docker 图标。
2. 点击 `Quit Docker Desktop`，等待图标消失。
3. 打开 PowerShell输入：

```powershell
wsl --shutdown
```

4. 从开始菜单重新打开 Docker Desktop。
5. 等待 Engine 运行后输入：

```powershell
docker info --format 'CPUs={{.NCPU}} MemoryBytes={{.MemTotal}}'
```

**执行后的结果**：CPU 和内存上限与 `.wslconfig` 接近。4 GB 的字节数约为 `4294967296`，实际显示可能略少。

**注意事项**：不能在 Docker 正在写数据时直接结束 `vmmemWSL` 进程。

### 第五步：设置 Docker 虚拟磁盘位置

**在哪里操作**：Windows 本机 Docker Desktop。仅在系统盘空间不足或交付前规划数据盘时操作。

1. 先停止所有 Docker 容器。
2. 打开 `Settings` → `Resources` → `Advanced`。
3. 找到 `Disk image location`。
4. 点击 `Browse`。
5. 选择数据盘目录，例如：

```text
D:\DockerDesktopData
```

6. 点击 `Apply & restart`。
7. 等待 Docker Desktop 完成迁移。

**执行后的结果**：Docker Desktop 使用 D 盘保存虚拟磁盘。界面没有该选项时保持默认位置，不手工移动、复制或替换 `ext4.vhdx`。

### 第六步：检查磁盘使用情况

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
docker system df
docker info --format 'DockerRootDir={{.DockerRootDir}}'
```

**执行后的结果**：显示镜像、容器、卷占用。`DockerRootDir=/var/lib/docker` 是 Docker Linux 环境内部路径，不是 Windows 项目源码目录。

## 第五部分：验证 Docker Engine 和基础网络

### 第一步：验证 Client 和 Server

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
docker version
```

**执行后的结果**：必须同时显示 Client 和 Server，Server 的 OS/Arch 为 `linux/amd64` 或等价内容。

### 第二步：查看 Docker Desktop 状态

**在哪里操作**：Windows 本机 PowerShell。

新版 Docker Desktop 输入：

```powershell
docker desktop status
docker desktop version
```

**执行后的结果**：状态为 `running`，并显示 Docker Desktop CLI 插件版本。

如果当前版本没有 `docker desktop` 子命令，以 Docker Desktop 界面和 `docker version` 的 Server 输出为准。

### 第三步：测试 DNS 和 Docker Hub Registry

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
Resolve-DnsName registry-1.docker.io
curl.exe -I --connect-timeout 10 --max-time 20 https://registry-1.docker.io/v2/
```

**执行后的结果**：DNS 返回地址；Registry 返回 HTTP `401 Unauthorized` 是正常的未登录响应，表示网络和 TLS 已经到达 Docker Hub。

如果 DNS 解析失败，先修复 Windows 网络和 DNS。配置镜像源不能解决 Windows 本身无法联网的问题。

### 第四步：拉取 Alpine 测试镜像

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
docker pull alpine:latest
```

**执行后的结果**：正常情况最后显示：

```text
Status: Downloaded newer image for alpine:latest
docker.io/library/alpine:latest
```

或显示 `Image is up to date`。`alpine:latest` 只用于网络测试；MySQL、Redis、Nacos、PGVector、RocketMQ、Seata 和 Elasticsearch 必须使用各自文档中的固定版本，不能使用 `latest`。

### 第五步：运行并自动删除测试容器

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
docker run --rm alpine:latest sh -c 'cat /etc/alpine-release && echo docker-network-ok'
```

**执行后的结果**：显示 Alpine 版本和 `docker-network-ok`，命令结束后测试容器自动删除。

检查：

```powershell
docker ps -a --filter ancestor=alpine:latest
```

应没有本次测试的停止容器。

## 第六部分：手工判断并配置 Docker Hub 镜像源

### 第一步：先判断是否真的需要镜像源

**在哪里操作**：Windows 本机 PowerShell。

如果第五部分 `docker pull alpine:latest` 已成功，说明官方 Docker Hub 当前可用，可以保持官方源，不必为了“配置过”而添加失效代理。

输入下面命令记录当前配置：

```powershell
docker info --format 'Mirrors={{json .RegistryConfig.Mirrors}}'
```

**执行后的结果**：未配置时通常为 `Mirrors=[]`；已配置时显示一个或多个地址。

### 第二步：测试候选镜像站入口

**在哪里操作**：Windows 本机 PowerShell。

逐条输入：

```powershell
curl.exe -I --connect-timeout 10 --max-time 20 https://docker.1ms.run/v2/
curl.exe -I --connect-timeout 10 --max-time 20 https://docker.m.daocloud.io/v2/
```

**执行后的结果**：HTTP `200` 或 `401` 表示 Registry 入口可达；`403`、`429`、`5xx`、解析失败或超时表示本次部署不可用。

**注意事项**：入口可达不代表所有项目镜像都存在。每个组件仍要按对应文档执行实际 `docker pull` 并核对镜像版本和摘要。

### 第三步：打开 Docker Engine JSON 配置

**在哪里操作**：Windows 本机 Docker Desktop。

1. 打开 Docker Desktop。
2. 点击右上角齿轮 `Settings`。
3. 点击左侧 `Docker Engine`。
4. 先把当前 JSON 内容截图或复制到客户变更记录中。

**执行后的结果**：右侧编辑框显示 Docker Engine JSON。不能删除原有未知配置。

### 第四步：手工加入一个已检测可达的镜像源

**在哪里操作**：Windows 本机 Docker Desktop 的 `Docker Engine` 编辑框。

如果当前内容只有：

```json
{
  "builder": {
    "gc": {
      "defaultKeepStorage": "20GB",
      "enabled": true
    }
  }
}
```

并且第二步确认 `docker.1ms.run` 可达，则修改为：

```json
{
  "builder": {
    "gc": {
      "defaultKeepStorage": "20GB",
      "enabled": true
    }
  },
  "registry-mirrors": [
    "https://docker.1ms.run"
  ]
}
```

如果客户原 JSON 还有其他键，只在最外层对象中增加 `registry-mirrors`，并正确添加逗号。不要整段覆盖客户已有代理、DNS或构建配置。

1. 检查所有键和值使用英文双引号。
2. 检查最后一个属性后面没有多余逗号。
3. 点击 `Apply & restart`。
4. 等待 Docker Engine 重启。

**执行后的结果**：Docker Desktop 接受 JSON 并重新运行。JSON 错误时界面会提示解析失败，此时恢复修改前内容，不要继续点击。

### 第五步：验证镜像源生效

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
docker info --format 'Mirrors={{json .RegistryConfig.Mirrors}}'
docker pull alpine:latest
```

**执行后的结果**：Mirrors 中显示刚配置的地址，Alpine 拉取成功。

### 第六步：明确 registry-mirrors 的适用范围

**在哪里操作**：Windows 本机 PowerShell和本文核对。

`registry-mirrors` 主要处理默认 Docker Hub（`docker.io`）镜像。例如：

```text
mysql:8.4.10
redis:8.4.4
nacos/nacos-server:v3.1.1
apache/rocketmq:5.3.1
apache/seata-server:2.5.0
```

下面这种独立上游仓库不会因为配置 Docker Hub mirror 自动改道：

```text
docker.elastic.co/elasticsearch/elasticsearch:8.19.17
```

Elasticsearch 网络失败时必须按 Elasticsearch 文档使用 `elastic.m.daocloud.io` 显式拉取并重新打标签。

### 第七步：不要长期堆放多个未知镜像源

**在哪里操作**：Windows 本机 Docker Desktop。

参考资料中的社区地址会随时间失效。不要一次填入五六个未检测地址，因为这会延长失败等待时间，也难以判断实际用了哪个源。

本项目规则是：

1. 官方源能拉取就使用官方源。
2. 官方源失败时，检测一个候选代理。
3. 实际拉取固定项目镜像并核对摘要。
4. 代理失效后从 `registry-mirrors` 删除。
5. 无稳定公网时使用离线 `docker save`/`docker load`。

## 第七部分：配置单位网络代理

### 第一步：判断 Windows 是否使用代理

**在哪里操作**：Windows 本机“设置”和 PowerShell。

1. 打开“设置”→“网络和 Internet”→“代理”。
2. 记录是否启用“使用设置脚本”或“使用代理服务器”。
3. PowerShell输入：

```powershell
netsh winhttp show proxy
```

**执行后的结果**：确认客户网络是直连、PAC 还是固定代理。

### 第二步：在 Docker Desktop 配置代理

**在哪里操作**：Windows 本机 Docker Desktop。

1. 打开 `Settings` → `Resources` → `Proxies`，部分版本位于 `Settings` → `Proxies`。
2. Windows 系统代理可用时选择 `System proxy`。
3. 单位提供固定代理时选择 `Manual configuration`。
4. HTTP 和 HTTPS 地址按单位网络管理员提供值填写，格式例如：

```text
http://代理服务器地址:端口
```

5. `No proxy` 中至少按单位要求填写内网地址和本机地址，例如：

```text
localhost,127.0.0.1,192.168.154.0/24
```

6. 点击 `Apply & restart`。

**执行后的结果**：Docker Desktop 和镜像拉取按设置使用代理。

**注意事项**：本文不能替客户虚构代理地址、用户名和密码。只填写单位网络管理员正式提供的值，不把代理密码写入项目文档或源码。

### 第三步：验证代理后的镜像拉取

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
docker pull alpine:latest
docker run --rm alpine:latest wget -qO- https://example.com
```

**执行后的结果**：镜像可以拉取，容器可以访问外部 HTTPS 页面。单位明确禁止容器访问公网时，只验证镜像拉取，并按安全策略关闭容器出网测试。

## 第八部分：手工导出和载入离线镜像

### 第一步：在有网电脑创建镜像交付目录

**在哪里操作**：能够拉取镜像的 Windows 本机 PowerShell。

输入：

```powershell
New-Item -ItemType Directory -Force 'D:\ygh-delivery\docker-images'
```

**执行后的结果**：生成统一镜像交付目录。

### 第二步：逐个拉取项目固定镜像

**在哪里操作**：有网 Windows 本机 PowerShell。

每个镜像必须按对应组件文档逐个拉取和验证。示例：

```powershell
docker pull redis:8.4.4
docker image inspect redis:8.4.4 --format 'ID={{.Id}} ARCH={{.Architecture}} OS={{.Os}} DIGESTS={{json .RepoDigests}}'
```

**执行后的结果**：固定版本镜像存在且摘要符合项目锁定记录。不要一次执行未核对的批量拉取脚本。

### 第三步：逐个导出镜像

**在哪里操作**：有网 Windows 本机 PowerShell。

以 Redis 为例输入：

```powershell
docker save -o 'D:\ygh-delivery\docker-images\redis-8.4.4-amd64.tar' redis:8.4.4
Get-FileHash 'D:\ygh-delivery\docker-images\redis-8.4.4-amd64.tar' -Algorithm SHA256
```

**执行后的结果**：得到单组件 TAR 和交付文件哈希。其他组件在各自文档中使用各自镜像名和文件名，不能把所有镜像做成不透明的一键包。

### 第四步：把镜像文件交给客户电脑

**在哪里操作**：Windows 本机资源管理器和移动硬盘。

1. 把 TAR 文件复制到客户电脑：

```text
D:\ygh-delivery\docker-images
```

2. 按交付清单逐个核对文件名和大小。
3. 使用 `Get-FileHash` 核对 SHA256。

**执行后的结果**：交付文件与有网电脑导出文件完全一致。

### 第五步：在客户电脑逐个载入镜像

**在哪里操作**：客户 Windows 本机 PowerShell。

以 Redis 为例输入：

```powershell
docker load -i 'D:\ygh-delivery\docker-images\redis-8.4.4-amd64.tar'
docker image inspect redis:8.4.4 --format 'ID={{.Id}} ARCH={{.Architecture}} OS={{.Os}} DIGESTS={{json .RepoDigests}}'
```

**执行后的结果**：显示 `Loaded image`，镜像可被查到。载入镜像不等于创建容器，必须继续执行该组件文档中的配置、数据卷和 `docker run` 步骤。

## 第九部分：明确项目源码、虚拟机和 Docker 的边界

### 第一步：确认项目源码不由 Docker 拉取

**在哪里操作**：Windows 本机资源管理器和 IntelliJ IDEA。

客户收到项目源码 ZIP 后解压到 Windows普通目录，例如：

```text
D:\ygh-ai-system
```

IDEA 打开这个目录。Docker `pull` 只拉取镜像，不会拉取客户电脑里的项目源码，也不会读取源码 ZIP。

### 第二步：确认 Windows Docker Desktop 运行哪些组件

**在哪里操作**：Windows 本机 PowerShell和对应组件文档。

当前低配置交付方案中，Windows Docker Desktop 负责按场景运行：

```text
PGVector 0.8.5 / PostgreSQL 17
RocketMQ 5.3.1
Seata 2.5.0
Elasticsearch 8.19.17
```

这些组件不是 Java 项目源码，不由 IDEA 启动。

### 第三步：确认 Rocky Linux 虚拟机有独立 Docker

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

虚拟机中的 Docker Engine 负责：

```text
MySQL 8.4.10
Redis 8.4.4
Nacos 3.1.1
```

在 Windows 执行 `docker ps` 看不到虚拟机容器；在 SSH 中执行 `docker ps` 也看不到 Windows Docker Desktop 容器。两边必须分别安装、配置和验证。

### 第四步：确认 Ubuntu WSL 不承载本项目

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
wsl -l -v
```

如果存在 Ubuntu，它只是可选用户发行版。本文不在 Ubuntu 中安装 MySQL、Redis、Nacos、JDK、IDEA 或 Node.js，不把项目复制到 `/home`，也不从 Ubuntu 启动前后端。

## 第十部分：停止、再次启动和安全清理

### 第一步：正常退出 Docker Desktop

**在哪里操作**：Windows 本机任务栏。

1. 先停止正在写数据的业务服务。
2. 按各组件文档执行 `docker stop`。
3. 右键任务栏 Docker 图标。
4. 点击 `Quit Docker Desktop`。

**执行后的结果**：Docker Desktop 和其 WSL2 后端停止。命名卷和镜像不会删除。

### 第二步：再次启动 Docker Desktop

**在哪里操作**：Windows 本机开始菜单和 PowerShell。

1. 从开始菜单打开 `Docker Desktop`。
2. 等待 Engine 运行。
3. 输入：

```powershell
docker version
docker ps -a
```

**执行后的结果**：Client/Server 正常，原有容器仍在。设置为 `unless-stopped` 的容器会按各自状态恢复。

### 第三步：只删除 Alpine 测试镜像

**在哪里操作**：Windows 本机 PowerShell。

确认没有项目使用 Alpine 后输入：

```powershell
docker image rm alpine:latest
```

**执行后的结果**：只删除测试镜像。不要使用 `docker system prune --volumes`，该命令可能删除项目数据卷。

### 第四步：不要执行的危险操作

**在哪里操作**：Windows 本机 Docker Desktop和 PowerShell。

没有完整备份和客户书面确认时，不执行：

```text
Docker Desktop → Troubleshoot → Reset to factory defaults
docker system prune --volumes
docker volume prune
wsl --unregister docker-desktop
手工删除 Docker Desktop 的 ext4.vhdx
```

这些操作可能删除 MySQL、Redis、Nacos、PGVector、RocketMQ、Seata 或 Elasticsearch 的持久化数据。

## 第十一部分：常见故障处理

### 第一步：处理 Hardware assisted virtualization must be enabled

**在哪里操作**：Windows 本机任务管理器和 BIOS/UEFI。

**原因**：处理器虚拟化未启用，或 Windows 虚拟机平台未生效。

1. 按第一部分第四步确认任务管理器显示“虚拟化：已启用”。
2. 管理员 PowerShell输入：

```powershell
Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform
```

3. 状态不是 `Enabled` 时输入：

```powershell
Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -All
```

4. 重启 Windows。

### 第二步：处理 WSL 版本过低

**在哪里操作**：Windows 本机管理员 PowerShell。

输入：

```powershell
wsl --update
wsl --shutdown
wsl --version
```

**执行后的结果**：WSL 不低于 2.1.5。单位禁用 Store 时使用第二部分第六步 MSI 方式。

### 第三步：处理 dockerDesktopLinuxEngine 管道错误

**在哪里操作**：Windows 本机 Docker Desktop和 PowerShell。

故障通常类似：

```text
open //./pipe/dockerDesktopLinuxEngine: The system cannot find the file specified
```

处理顺序：

1. 打开 Docker Desktop，等待 Engine 完成启动。
2. 右键任务栏 Docker 图标，确认当前是 Linux containers。
3. 输入：

```powershell
wsl -l -v
docker desktop status
```

4. Docker Desktop 界面无响应时正常退出 Docker Desktop。
5. 输入：

```powershell
wsl --shutdown
```

6. 重新打开 Docker Desktop。

不能直接恢复出厂设置。

### 第四步：处理 Docker Engine JSON 无法应用

**在哪里操作**：Windows 本机 Docker Desktop。

**原因**：漏逗号、多逗号、中文引号、重复键或括号不匹配。

1. 回到 `Settings` → `Docker Engine`。
2. 恢复第六部分第三步保存的原始 JSON。
3. 点击 `Apply & restart`。
4. Engine 正常后重新只增加一个 `registry-mirrors` 键。

不要把 Linux `/etc/docker/daemon.json` 教程直接套到 Windows Docker Desktop；Windows 应在 Docker Desktop 的 Docker Engine 页面配置。

### 第五步：处理镜像拉取超时

**在哪里操作**：Windows 本机 PowerShell和 Docker Desktop。

依次检查：

```powershell
Resolve-DnsName registry-1.docker.io
curl.exe -I --connect-timeout 10 --max-time 20 https://registry-1.docker.io/v2/
docker info --format 'Mirrors={{json .RegistryConfig.Mirrors}}'
docker pull alpine:latest
```

判断方法：

1. DNS 失败：修复 Windows DNS、网关或单位网络。
2. Registry 可达但 pull 超时：检查 Docker Desktop代理和镜像源。
3. 返回 `429 Too Many Requests`：等待限流解除或按客户账号策略登录 Docker Hub。
4. 某个社区代理失败：删除该地址，检测其他来源或使用离线 TAR。
5. 只有某个项目镜像失败：按该组件文档使用专用代理，不改全局配置碰运气。

### 第六步：处理端口已被占用

**在哪里操作**：Windows 本机 PowerShell。

先把第一行的 `19200` 修改为需要检查的实际端口，再完整输入：

```powershell
$port = 19200
Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
  Where-Object { $_.LocalPort -eq $port } |
  Select-Object LocalAddress,LocalPort,OwningProcess
```

查进程：

```powershell
Get-Process -Id 这里替换为实际进程号
```

先确认进程用途。不要直接结束客户程序，也不要擅自改变项目固定端口。

### 第七步：处理 C 盘空间持续减少

**在哪里操作**：Windows 本机 Docker Desktop和 PowerShell。

输入：

```powershell
docker system df -v
```

1. 识别占用最大的镜像和停止容器。
2. 只删除明确不用且已备份的对象。
3. 需要迁移虚拟磁盘时按第四部分第五步通过 Docker Desktop 界面完成。
4. 不手工删除 AppData 下的 Docker 文件。

## 第十二部分：最终验收

### 第一步：执行完整检查

**在哪里操作**：Windows 本机 PowerShell。

依次输入：

```powershell
wsl --version
wsl --status
wsl -l -v
docker desktop status
docker version
docker info --format 'OSType={{.OSType}} Architecture={{.Architecture}} CPUs={{.NCPU}} Memory={{.MemTotal}} Mirrors={{json .RegistryConfig.Mirrors}}'
docker pull alpine:latest
docker run --rm alpine:latest sh -c 'cat /etc/alpine-release && echo docker-ok'
docker system df
```

### 第二步：核对合格结果

**在哪里操作**：Windows 本机检查记录。

全部满足才进入组件安装：

1. WSL 版本不低于 2.1.5，默认版本为 2。
2. `docker-desktop` 是 WSL2 发行版且可运行。
3. Docker Desktop 同时显示 Client 和 Server。
4. `OSType=linux`，架构为 `x86_64/amd64`。
5. 16 GB 客户电脑给 Docker Desktop 约 4 GB 内存和不超过物理上限的 CPU。
6. Docker Hub 官方源或一个经过检测的镜像源可以拉取 Alpine。
7. 测试容器输出 `docker-ok` 并自动删除。
8. Docker Desktop 程序、镜像数据、项目源码、Ubuntu WSL 和 Rocky Linux 虚拟机的边界已经分清。
9. 没有执行 Compose、`.env`、批处理或一键脚本。
10. 后续每个项目组件继续按各自文档逐个拉取、配置、启动和验证。
