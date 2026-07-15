# Rocky Linux 虚拟机从零配置指南

## 第一部分：配置 VMware NAT 网络

### 第一步：打开虚拟网络编辑器

操作位置：

```text
在 Windows 本机电脑操作。
软件：VMware Workstation Pro。
默认安装路径示例：C:\Program Files (x86)\VMware\VMware Workstation
这一步不是在 Rocky Linux、Docker 或 WSL2 里操作。
```

在 Windows 桌面打开 VMware Workstation Pro。

点击：

```text
Edit
Virtual Network Editor
Change Settings
```

执行后的结果：

能看到 `VMnet8`，并且可以修改网络配置。

需要修改的内容：

选中 `VMnet8`，确认勾选：

```text
NAT: Used to share the host's IP address
Connect a host virtual adapter to this network
Use local DHCP service to distribute IP address to VMs
```

### 第二步：设置 VMnet8 网段

**在哪里操作**：Windows 本机 VMware“虚拟网络编辑器”，不是 Rocky Linux 终端。

在 `VMnet8` 页面填写：

```text
Subnet IP:   192.168.154.0
Subnet mask: 255.255.255.0
```

点击：

```text
NAT Settings
```

填写：

```text
Gateway IP: 192.168.154.2
```

点击：

```text
OK
Apply
OK
```

执行后的结果：

VMware NAT 网关固定为：

```text
192.168.154.2
```

需要修改的内容：

如果客户电脑已有其他软件占用 `192.168.154.0/24`，换一个网段。例如：

```text
Subnet IP:   192.168.80.0
Gateway IP: 192.168.80.2
虚拟机 IP:   192.168.80.10
Windows IP:  192.168.80.1
```

后面所有 `192.168.154.10` 都要改成 `192.168.80.10`。

### 第三步：设置 DHCP 地址池

**在哪里操作**：Windows 本机 VMware“虚拟网络编辑器”的 VMnet8 DHCP 设置窗口。

点击：

```text
DHCP Settings
```

填写：

```text
Start IP address: 192.168.154.128
End IP address:   192.168.154.254
```

点击：

```text
OK
Apply
OK
```

执行后的结果：

DHCP 不会把 `192.168.154.10` 分配给其他虚拟机。

需要修改的内容：

如果换成 `192.168.80.0/24`，这里改成：

```text
Start IP address: 192.168.80.128
End IP address:   192.168.80.254
```

### 第四步：确认 Windows VMnet8 地址

**在哪里操作**：Windows 本机 PowerShell。

打开 Windows PowerShell，输入：

```powershell
ipconfig
```

执行后的结果：

找到：

```text
Ethernet adapter VMware Network Adapter VMnet8:
   IPv4 Address. . . . . . . . . . . : 192.168.154.1
   Subnet Mask . . . . . . . . . . . : 255.255.255.0
```

需要修改的内容：

如果这里不是 `192.168.154.1`，后面防火墙规则里的源地址要改成这里显示的 Windows VMnet8 地址。

---

## 第二部分：创建 Rocky Linux 虚拟机

### 第一步：下载 VMware Workstation Pro

**在哪里操作**：Windows 本机浏览器和文件资源管理器。

下载和安装位置：

```text
下载安装到 Windows 本机电脑。
默认安装路径示例：C:\Program Files (x86)\VMware\VMware Workstation
不要安装到虚拟机里，不要安装到 WSL2 里。
```

浏览器打开：

```text
https://www.vmware.com/products/desktop-hypervisor/workstation-and-fusion
```

如果页面跳转到 Broadcom，按页面提示登录或注册 Broadcom 账号。

点击下载：

```text
VMware Workstation Pro for Windows
```

执行后的结果：

Windows 下载到安装包，例如：

```text
VMware-workstation-full-xx.x.x.exe
```

需要修改的内容：

文件名以客户实际下载版本为准。

### 第二步：安装 VMware Workstation Pro

**在哪里操作**：Windows 本机 VMware 安装向导，需要使用有安装权限的 Windows 账号。

安装位置：

```text
安装到 Windows 本机电脑。
安装完成后，Windows 上出现 VMware Workstation Pro。
后续 Rocky Linux 会作为 VMware 里的虚拟机运行。
```

双击安装包。

安装界面按顺序点击：

```text
Next
勾选 I accept the terms in the License Agreement
Next
Next
Next
Install
Finish
```

执行后的结果：

桌面或开始菜单出现：

```text
VMware Workstation Pro
```

需要修改的内容：

安装过程中如果提示重启 Windows，先重启，再继续后面的步骤。

### 第三步：下载 Rocky Linux Minimal ISO

**在哪里操作**：Windows 本机浏览器下载，随后在 Windows PowerShell 校验文件。

下载位置：

```text
ISO 文件下载到 Windows 本机电脑。
建议保存路径：D:\ISO\Rocky-10.2-x86_64-minimal.iso
ISO 只是安装镜像，不是项目运行目录。
```

浏览器打开：

```text
https://download.rockylinux.org/pub/rocky/10/isos/x86_64/
```

点击：

```text
Rocky-10.2-x86_64-minimal.iso
Rocky-10.2-x86_64-minimal.iso.CHECKSUM
```

执行后的结果：

下载到 ISO 文件，例如：

```text
D:\ISO\Rocky-10.2-x86_64-minimal.iso
D:\ISO\Rocky-10.2-x86_64-minimal.iso.CHECKSUM
```

需要修改的内容：

本文固定使用 Rocky Linux 10.2 x86_64 Minimal。不要下载 `latest`、Live、Boot、DVD 或 aarch64 镜像。

下载完成后打开 Windows PowerShell，输入：

```powershell
Get-FileHash 'D:\ISO\Rocky-10.2-x86_64-minimal.iso' -Algorithm SHA256
Select-String -Path 'D:\ISO\Rocky-10.2-x86_64-minimal.iso.CHECKSUM' -Pattern 'Rocky-10\.2-x86_64-minimal\.iso$'
```

执行后的结果：第一条命令的 `Hash` 与第二条命令中该 ISO 对应的 SHA256 必须逐字完全相同，不区分字母大小写。手工从第一个字符核对到最后一个字符；任何字符不同都要删除 ISO 并从 Rocky 官方仓库重新下载，不能继续安装。这里不使用 PowerShell 变量或校验脚本。

### 第四步：创建虚拟机

创建位置：

```text
虚拟机创建在 Windows 本机 VMware 里。
虚拟机文件建议保存路径：D:\VMs\ygh-rocky-dev
Rocky Linux 系统会安装到这个虚拟机的 40GB 虚拟硬盘中。
```

在 VMware Workstation Pro 点击：

```text
Create a New Virtual Machine
Typical
Next
Installer disc image file (iso)
Browse
```

选择 Rocky Linux Minimal ISO。

继续填写：

```text
Guest operating system: Linux
Version: Rocky Linux 64-bit
Virtual machine name: ygh-rocky-dev
Location: D:\VMs\ygh-rocky-dev
Maximum disk size: 40 GB
Store virtual disk as a single file
```

点击：

```text
Customize Hardware
```

设置：

```text
Memory: 3584 MB
Processors: 2
Network Adapter: NAT
```

点击：

```text
Close
Finish
```

执行后的结果：

VMware 左侧出现虚拟机：

```text
ygh-rocky-dev
```

需要修改的内容：

如果客户电脑内存大于 32GB，可以把 Memory 改成 `4096 MB`。

### 第五步：安装 Rocky Linux

**在哪里操作**：Windows 本机 VMware 虚拟机控制台中的 Rocky Linux 安装界面。

安装位置：

```text
安装到 VMware 虚拟机内部。
不是安装到 Windows 本机程序目录。
安装完成后，Rocky Linux 的系统目录在虚拟机内部，例如 /、/home、/opt。
后续组件配置和镜像目录统一放在：/opt/ygh
```

启动虚拟机。

选择：

```text
Install Rocky Linux 10.2
```

进入安装界面后配置：

```text
Installation Destination: 选择 40GB 磁盘，使用 Automatic
Root Password: 设置强密码
User Creation:
  Full name: wang
  User name: wang
  勾选 Make this user administrator
```

点击：

```text
Begin Installation
Reboot System
```

执行后的结果：

系统重启后可以用 `wang` 登录。

需要修改的内容：

如果客户不用 `wang`，后面所有命令里的 `wang` 都替换成客户实际 Linux 用户名。

---

## 第三部分：配置 Rocky Linux 固定 IP

### 第一步：查看网卡名称

**在哪里操作**：Rocky Linux 虚拟机控制台。此时固定 IP 可能尚未完成，不依赖 SSH。

登录 Rocky Linux，输入：

```bash
whoami
ip addr
nmcli connection show
```

执行后的结果：

通常能看到：

```text
whoami 输出 wang
连接名 ens160
设备名 ens160
```

需要修改的内容：

如果连接名不是 `ens160`，后面命令中的 `ens160` 要替换成实际连接名。

例如连接名是：

```text
Wired connection 1
```

后面命令就写：

```bash
"Wired connection 1"
```

### 第二步：设置固定 IP

**在哪里操作**：Rocky Linux 虚拟机控制台中的终端。

输入：

```bash
sudo nmcli connection modify ens160 ipv4.method manual \
  ipv4.addresses 192.168.154.10/24 \
  ipv4.gateway 192.168.154.2 \
  ipv4.dns "223.5.5.5 8.8.8.8"
```

继续输入：

```bash
sudo nmcli connection up ens160
```

继续输入：

```bash
ip addr show ens160
```

继续输入：

```bash
ip route
```

执行后的结果：

`ip addr` 里应该看到：

```text
inet 192.168.154.10/24
```

`ip route` 里应该看到：

```text
default via 192.168.154.2
```

需要修改的内容：

如果 VMware NAT 网段是 `192.168.80.0/24`，命令改成：

```bash
sudo nmcli connection modify ens160 ipv4.method manual \
  ipv4.addresses 192.168.80.10/24 \
  ipv4.gateway 192.168.80.2 \
  ipv4.dns "223.5.5.5 8.8.8.8"
sudo nmcli connection up ens160
```

### 第三步：测试虚拟机联网

**在哪里操作**：Rocky Linux 虚拟机终端。

输入：

```bash
ping -c 4 223.5.5.5
```

继续输入：

```bash
ping -c 4 mirrors.rockylinux.org
```

继续输入：

```bash
curl -I https://download.docker.com/linux/centos/docker-ce.repo
```

执行后的结果：

`ping 223.5.5.5` 应该看到：

```text
0% packet loss
```

`ping mirrors.rockylinux.org` 应该能解析域名。

`curl` 应该返回 HTTP 响应头。

需要修改的内容：

如果 IP 能通、域名不通，重新设置 DNS：

```bash
sudo nmcli connection modify ens160 ipv4.dns "223.5.5.5 8.8.8.8"
sudo nmcli connection up ens160
```

---

## 第四部分：配置 SSH

### 第一步：安装并启动 SSH

**在哪里操作**：Rocky Linux 虚拟机控制台终端。

安装位置：

```text
安装到 Rocky Linux 虚拟机里。
服务名：sshd
用途：Windows PowerShell 通过 ssh 连接虚拟机。
不安装到 Windows Docker Desktop 或 WSL2。
```

输入：

```bash
sudo dnf install -y openssh-server
```

继续输入：

```bash
sudo systemctl enable --now sshd
```

继续输入：

```bash
sudo systemctl status sshd --no-pager
```

执行后的结果：

看到：

```text
Active: active (running)
```

需要修改的内容：

如果服务没有启动，先看错误：

```bash
journalctl -u sshd -n 50 --no-pager
```

### 第二步：Windows 测试 SSH

**在哪里操作**：Windows 本机 PowerShell，不在虚拟机控制台输入。

打开 Windows PowerShell，输入：

```powershell
Test-NetConnection 192.168.154.10 -Port 22
```

继续输入：

```powershell
ssh wang@192.168.154.10
```

第一次连接时输入：

```text
yes
```

然后输入 `wang` 的密码。

执行后的结果：

`Test-NetConnection` 显示：

```text
TcpTestSucceeded : True
```

SSH 能登录到 Rocky Linux。

需要修改的内容：

如果 IP 或用户名不同，替换 `wang@192.168.154.10`。

### 第三步：配置 SSH 免密

**在哪里操作**：密钥生成和公钥上传命令在 Windows 本机 PowerShell 输入；失败后的权限检查在 Rocky Linux 终端输入。

先在 Windows PowerShell 输入：

```powershell
Test-Path "$HOME\.ssh\id_ed25519"
```

如果输出 `True`，说明当前 Windows 用户已经有密钥，不能覆盖，直接执行下一条公钥上传命令。

如果输出 `False`，再单独输入：

```powershell
ssh-keygen -t ed25519
```

命令询问保存位置和口令时按客户安全要求填写；测试环境可以一路回车使用默认路径。命令结束后再次执行 `Test-Path "$HOME\.ssh\id_ed25519"`，必须变为 `True`。

继续输入：

```powershell
Get-Content "$HOME\.ssh\id_ed25519.pub" | ssh wang@192.168.154.10 'umask 077; mkdir -p ~/.ssh; cat >> ~/.ssh/authorized_keys; chmod 700 ~/.ssh; chmod 600 ~/.ssh/authorized_keys'
```

继续输入：

```powershell
ssh -o BatchMode=yes wang@192.168.154.10 'echo SSH_OK'
```

执行后的结果：

最后输出：

```text
SSH_OK
```

需要修改的内容：

如果没有输出 `SSH_OK`，登录虚拟机输入：

```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
restorecon -RFv ~/.ssh
sudo systemctl restart sshd
```

---

## 第五部分：手动安装和验证 Docker Engine

### 第一步：卸载冲突组件

操作位置：

```text
在 Rocky Linux 虚拟机里操作。
目的：清理虚拟机里可能自带或冲突的容器组件。
不影响 Windows 本机 Docker Desktop。
```

登录 Rocky Linux，输入：

```bash
sudo dnf remove -y podman buildah runc docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine
```

执行后的结果：

可能显示已删除，也可能显示没有安装。

需要修改的内容：

如果提示 `No match for argument`，可以继续下一步。

### 第二步：安装基础工具

**在哪里操作**：通过 SSH 登录后的 Rocky Linux 虚拟机终端。

输入：

```bash
sudo dnf install -y dnf-plugins-core curl ca-certificates yum-utils
```

执行后的结果：

最后看到：

```text
Complete!
```

需要修改的内容：

如果下载失败，先回到网络配置部分检查 DNS 和 NAT。

### 第三步：添加 Docker 官方软件源

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

输入：

```bash
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
```

继续输入：

```bash
sudo dnf makecache
```

执行后的结果：

能看到 Docker 软件源缓存完成。

需要修改的内容：

如果无法访问 `download.docker.com`，先测试：

```bash
curl -I https://download.docker.com/linux/centos/docker-ce.repo
```

如果公司网络拦截，需要让客户网络放通 Docker 官方下载站，或使用客户公司允许的软件源。

### 第四步：安装 Docker Engine

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。这里安装的是虚拟机 Docker Engine，不是 Windows Docker Desktop。

安装位置：

```text
安装到 Rocky Linux 虚拟机里。
Docker 命令路径：/usr/bin/docker
Docker 配置文件：/etc/docker/daemon.json
Docker 数据目录：/var/lib/docker
不安装到 Windows Docker Desktop，也不安装到 WSL2。
```

输入：

```bash
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin
```

执行后的结果：

最后看到：

```text
Complete!
```

需要修改的内容：本文每个组件都使用独立的 `docker pull`、`docker run`、`docker stop` 和 `docker start`，不需要安装或调用 Compose 插件。

### 第五步：手动写入 Docker 配置

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端，配置文件位于虚拟机 `/etc/docker/daemon.json`。

配置位置：

```text
写入 Rocky Linux 虚拟机：/etc/docker/daemon.json
该配置只影响虚拟机里的 Docker Engine。
不影响 Windows 本机 Docker Desktop。
```

输入：

```bash
sudo mkdir -p /etc/docker
```

继续输入：

```bash
sudo tee /etc/docker/daemon.json >/dev/null <<'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "live-restore": true,
  "storage-driver": "overlay2",
  "default-address-pools": [
    { "base": "172.30.0.0/16", "size": 24 }
  ]
}
EOF
```

继续输入：

```bash
sudo dockerd --validate --config-file=/etc/docker/daemon.json
```

执行后的结果：

没有报错，说明 JSON 格式正确。

需要修改的内容：

此时先不写镜像代理。Docker 启动后在第十步逐个测试，只有现场可用且符合客户安全要求的地址才写入 `registry-mirrors`。

### 第六步：启动 Docker

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

输入：

```bash
sudo systemctl enable --now docker
```

继续输入：

```bash
sudo systemctl status docker --no-pager
```

执行后的结果：

看到：

```text
Active: active (running)
```

需要修改的内容：

如果启动失败，输入：

```bash
journalctl -u docker -n 100 --no-pager
```

根据报错修正 `/etc/docker/daemon.json`。

### 第七步：把当前用户加入 docker 组

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端；重新登录动作回到 Windows PowerShell 完成。

输入：

```bash
sudo usermod -aG docker wang
```

继续输入：

```bash
exit
```

回到 Windows PowerShell，重新登录：

```powershell
ssh wang@192.168.154.10
```

执行后的结果：

重新进入虚拟机。

需要修改的内容：

如果 Linux 用户不是 `wang`，把命令里的 `wang` 改成实际用户名。

### 第八步：验证 Docker 安装

**在哪里操作**：重新登录后的 Rocky Linux 虚拟机 SSH 终端。

在 Rocky Linux 输入：

```bash
groups
```

继续输入：

```bash
docker version
```

继续输入：

```bash
docker info --format 'Docker={{.ServerVersion}} Cgroup={{.CgroupVersion}} Driver={{.Driver}}'
```

执行后的结果：

`groups` 里包含：

```text
docker
```

`docker version` 正常输出客户端和服务端版本。

需要修改的内容：

如果提示：

```text
permission denied
```

说明没有重新登录，执行：

```bash
exit
```

再重新 SSH 登录。

### 第九步：测试 Docker 镜像拉取

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端，不使用 Windows Docker Desktop 的 Docker 命令。

输入：

```bash
docker pull alpine
```

执行后的结果：

成功时看到：

```text
Status: Downloaded newer image for alpine:latest
```

需要修改的内容：

如果失败，继续下一步处理 Docker 镜像封锁。

### 第十步：逐个测试镜像地址并配置可用镜像源

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

先测试 Docker Hub 官方 Registry：

```bash
curl -I --connect-timeout 10 https://registry-1.docker.io/v2/
```

**执行后的结果**：

1. 返回 `HTTP/1.1 401 Unauthorized` 说明网络已经到达 Docker Registry；401 是未登录探测的正常结果。
2. `Could not resolve host` 说明 DNS 仍未修好，回到第三部分第三步。
3. `Connection timed out` 或 TLS 失败说明当前网络无法直连 Docker Hub。

官方地址不可用时，逐个测试候选地址，每次只输入一条：

```bash
curl -I --connect-timeout 10 https://docker.m.daocloud.io/v2/
```

```bash
curl -I --connect-timeout 10 https://docker.1ms.run/v2/
```

**执行后的结果**：只有能返回 HTTP 响应且 TLS 证书校验正常的地址才可使用。公共代理可用性会变化；客户有自建 Harbor 或合规代理时优先使用单位地址。

先备份当前 Docker 配置：

```bash
date '+%Y%m%d-%H%M%S'
sudo cp -a /etc/docker/daemon.json /etc/docker/daemon.json.bak.20260715-143000
```

第二条命令中的 `20260715-143000` 是示例。必须改成第一条命令刚显示的实际时间，再输入第二条命令；不要原样照抄示例时间。如果提示 `/etc/docker/daemon.json` 不存在，说明这是第一次配置，可以直接进入编辑步骤。

输入：

```bash
sudo vi /etc/docker/daemon.json
```

按 `i` 编辑。保留原来的日志、存储驱动和地址池，只在 `registry-mirrors` 中填写刚实测可用的一个地址：

```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "live-restore": true,
  "storage-driver": "overlay2",
  "registry-mirrors": [
    "https://docker.1ms.run"
  ],
  "default-address-pools": [
    { "base": "172.30.0.0/16", "size": 24 }
  ]
}
```

按 `Esc`，输入 `:wq` 并回车。逐条输入：

```bash
sudo dockerd --validate --config-file=/etc/docker/daemon.json
```

```bash
sudo systemctl restart docker
```

```bash
docker info | sed -n '/Registry Mirrors/,+4p'
```

```bash
docker pull alpine:latest
```

**执行后的结果**：配置校验无错误，Docker 为 active，`docker info` 显示实际镜像地址，Alpine 拉取成功。

**需要修改的内容**：示例 `https://docker.1ms.run` 必须替换为客户现场实测可用且符合安全要求的地址。失败时从实际备份文件恢复后重启 Docker，不要继续叠加未知代理。

### 第十一步：网络受限时逐个离线导入组件镜像

**在哪里操作**：可联网 Windows 电脑 PowerShell、WinSCP、Rocky Linux SSH 终端。

进入后续组件文档时，只为当前组件执行 `docker pull`、`docker save`、SHA256、WinSCP 上传和 `docker load`。不要把全部组件打成一个不透明大包。

以 MySQL 为例，在可联网电脑输入：

```powershell
docker pull mysql:8.4.10
docker save -o 'D:\ygh-images\mysql-8.4.10.tar' mysql:8.4.10
Get-FileHash 'D:\ygh-images\mysql-8.4.10.tar' -Algorithm SHA256
```

用 WinSCP 上传到 `/opt/ygh/images/mysql-8.4.10.tar`。在虚拟机输入：

```bash
sha256sum /opt/ygh/images/mysql-8.4.10.tar
docker load -i /opt/ygh/images/mysql-8.4.10.tar
docker image inspect mysql:8.4.10 --format '{{.RepoTags}} {{.Architecture}} {{.Os}}'
```

**执行后的结果**：Windows 与虚拟机 SHA256 一致，当前镜像标签和架构正确。然后进入当前组件文档创建目录、配置、密码、容器和数据卷；不要执行 Compose。

**下一步做什么**：完成下面的防火墙基础配置，再按总教程依次安装 MySQL、Redis、Nacos 和 PGVector。

## 第六部分：手动配置虚拟机防火墙

### 第一步：启动 firewalld

**在哪里操作**：通过 SSH 登录后的 Rocky Linux 虚拟机终端。

安装和运行位置：

```text
firewalld 运行在 Rocky Linux 虚拟机里。
它控制虚拟机端口访问。
不控制 Windows Docker Desktop，也不控制 WSL2。
```

在 Rocky Linux 输入：

```bash
sudo systemctl enable --now firewalld
```

继续输入：

```bash
sudo firewall-cmd --state
```

执行后的结果：

看到：

```text
running
```

需要修改的内容：

如果没有 `firewall-cmd`，输入：

```bash
sudo dnf install -y firewalld
sudo systemctl enable --now firewalld
```

### 第二步：确认 Windows VMnet8 地址

**在哪里操作**：Windows 本机 PowerShell，不是在虚拟机终端中。

在 Windows PowerShell 输入：

```powershell
ipconfig
```

执行后的结果：

确认 `VMware Network Adapter VMnet8` 的 IPv4，例如：

```text
192.168.154.1
```

需要修改的内容：

下面所有 `source address=192.168.154.1/32` 都必须改成客户 Windows VMnet8 地址。

### 第三步：开放 MySQL 端口

**在哪里操作**：通过 SSH 登录后的 Rocky Linux 虚拟机终端。

端口位置：

```text
MySQL 容器运行在 Rocky Linux 虚拟机 Docker 里。
容器端口：3306
虚拟机对 Windows 暴露：192.168.154.10:3306
只允许 Windows VMnet8 地址访问，不对所有网段开放。
```

在 Rocky Linux 输入：

```bash
sudo firewall-cmd --permanent --add-rich-rule='rule family=ipv4 source address=192.168.154.1/32 port protocol=tcp port=3306 accept'
```

执行后的结果：

看到：

```text
success
```

需要修改的内容：

不要使用 `--add-port=3306/tcp`，那会对整个网络开放数据库端口。

### 第四步：开放 Redis 端口

**在哪里操作**：通过 SSH 登录后的 Rocky Linux 虚拟机终端。

端口位置：

```text
Redis 容器运行在 Rocky Linux 虚拟机 Docker 里。
容器端口：6379
虚拟机对 Windows 暴露：192.168.154.10:6379
```

输入：

```bash
sudo firewall-cmd --permanent --add-rich-rule='rule family=ipv4 source address=192.168.154.1/32 port protocol=tcp port=6379 accept'
```

执行后的结果：

看到：

```text
success
```

### 第五步：开放 Nacos 端口

**在哪里操作**：通过 SSH 登录后的 Rocky Linux 虚拟机终端。

端口位置：

```text
Nacos 容器运行在 Rocky Linux 虚拟机 Docker 里。
控制台端口：8080
服务端口：8848
客户端 gRPC 端口：9848
虚拟机对 Windows 暴露：192.168.154.10:8080、8848、9848
```

输入：

```bash
sudo firewall-cmd --permanent --add-rich-rule='rule family=ipv4 source address=192.168.154.1/32 port protocol=tcp port=8080 accept'
```

继续输入：

```bash
sudo firewall-cmd --permanent --add-rich-rule='rule family=ipv4 source address=192.168.154.1/32 port protocol=tcp port=8848 accept'
```

继续输入：

```bash
sudo firewall-cmd --permanent --add-rich-rule='rule family=ipv4 source address=192.168.154.1/32 port protocol=tcp port=9848 accept'
```

执行后的结果：

每条命令都看到：

```text
success
```

### 第六步：开放 PGVector 端口

**在哪里操作**：通过 SSH 登录后的 Rocky Linux 虚拟机终端。

端口位置：

```text
PGVector 容器运行在 Rocky Linux 虚拟机 Docker 里。
容器端口：5432
虚拟机对 Windows 暴露：192.168.154.10:5432
```

输入：

```bash
sudo firewall-cmd --permanent --add-rich-rule='rule family=ipv4 source address=192.168.154.1/32 port protocol=tcp port=5432 accept'
```

执行后的结果：

看到：

```text
success
```

### 第七步：重新加载防火墙

**在哪里操作**：通过 SSH 登录后的 Rocky Linux 虚拟机终端。

输入：

```bash
sudo firewall-cmd --reload
```

继续输入：

```bash
sudo firewall-cmd --list-rich-rules
```

执行后的结果：

能看到端口：

```text
3306
5432
6379
8080
8848
9848
```

需要修改的内容：

如果客户 Windows VMnet8 地址不是 `192.168.154.1`，重新删除错误规则后添加正确规则。

删除示例：

```bash
sudo firewall-cmd --permanent --remove-rich-rule='rule family=ipv4 source address=192.168.154.1/32 port protocol=tcp port=3306 accept'
sudo firewall-cmd --reload
```

---
