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

下载位置：

```text
ISO 文件下载到 Windows 本机电脑。
建议保存路径：D:\ISO\Rocky-9.6-x86_64-minimal.iso
ISO 只是安装镜像，不是项目运行目录。
```

浏览器打开：

```text
https://rockylinux.org/download
```

点击：

```text
Rocky Linux 9
x86_64
Minimal ISO
```

执行后的结果：

下载到 ISO 文件，例如：

```text
D:\ISO\Rocky-9.6-x86_64-minimal.iso
```

需要修改的内容：

ISO 文件名以客户实际下载为准。不要下载 Live 镜像，建议下载 Minimal ISO。

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

安装位置：

```text
安装到 VMware 虚拟机内部。
不是安装到 Windows 本机程序目录。
安装完成后，Rocky Linux 的系统目录在虚拟机内部，例如 /、/home、/opt。
后续项目部署目录使用：/opt/ygh/constrained-dev
```

启动虚拟机。

选择：

```text
Install Rocky Linux 9
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

在 Windows PowerShell 输入：

```powershell
if (-not (Test-Path "$HOME\.ssh\id_ed25519")) { ssh-keygen -t ed25519 }
```

一路回车即可。

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

## 第五部分：手动准备项目配置

### 第一步：确认虚拟机里到底安装什么

本项目 Java 服务由客户在 Windows IDEA 里启动，虚拟机里不安装 JDK。

安装位置：

```text
虚拟机里只安装：Rocky Linux、OpenSSH Server、Docker Engine、Docker Compose Plugin、firewalld。
Windows 本机安装：JDK 25、IDEA、Node.js、pnpm、Docker Desktop、WSL2。
虚拟机 Docker 容器运行：MySQL、Redis、Nacos、PGVector。
Windows Docker Desktop 运行：RocketMQ、Seata、Elasticsearch。
```

虚拟机只安装：

```text
Rocky Linux 9
OpenSSH Server
Docker Engine
Docker Compose Plugin
firewalld
```

Docker 里运行：

```text
MySQL 8.4.10
Redis 8.4.4
Nacos 3.1.1
PostgreSQL 17 + PGVector 0.8.5
```

执行后的结果：

Windows IDEA 启动 Java 服务，Java 服务连接虚拟机里的 MySQL、Redis、Nacos、PGVector。

需要修改的内容：

不要在虚拟机里手工安装 JDK，不要把 JDK 上传到 `/opt/software/jdk`。

### 第二步：打开部署目录

操作位置：

```text
在 Windows 本机 PowerShell 操作。
Windows 项目目录：F:\跨境智汇AI知识库系统\ygh-deploy\constrained-dev
后面会复制到虚拟机目录：/opt/ygh/constrained-dev
```

在 Windows PowerShell 输入：

```powershell
Set-Location 'F:\跨境智汇AI知识库系统\ygh-deploy\constrained-dev'
```

继续输入：

```powershell
Get-ChildItem
```

执行后的结果：

能看到：

```text
vm-compose.yml
.env.example
mysql
postgres
scripts
```

需要修改的内容：

如果客户项目解压路径不是 `F:\跨境智汇AI知识库系统`，把命令里的路径换成客户实际项目路径。

### 第三步：手动创建 .env

文件位置：

```text
先在 Windows 本机创建：F:\跨境智汇AI知识库系统\ygh-deploy\constrained-dev\.env
再复制到 Rocky Linux 虚拟机：/opt/ygh/constrained-dev/.env
这个文件不是 Docker 镜像，不放到 WSL2，不放进交付压缩包，不截图发给别人。
```

输入：

```powershell
Copy-Item .\.env.example .\.env
```

继续输入：

```powershell
notepad .\.env
```

执行后的结果：

记事本打开 `.env`。

需要修改的内容：

把 `.env` 里的所有：

```text
change-me
base64-at-least-32-bytes
base64-exactly-32-bytes
```

全部替换成客户自己的随机值。

### 第四步：生成普通密码并填入 .env

在 Windows PowerShell 输入：

```powershell
$b=New-Object byte[] 24; [System.Security.Cryptography.RandomNumberGenerator]::Fill($b); [Convert]::ToBase64String($b).TrimEnd('=').Replace('+','A').Replace('/','B')
```

执行后的结果：

输出一串随机密码，例如：

```text
Vh2x9...省略
```

需要修改的内容：

每执行一次，复制输出值，填入 `.env` 中一个密码项。以下字段都要分别生成，不要全部用同一个密码：

```text
MYSQL_ROOT_PASSWORD
NACOS_DB_PASSWORD
AUTH_DB_APP_PASSWORD
AUTH_DB_MIGRATION_PASSWORD
USER_DB_APP_PASSWORD
USER_DB_MIGRATION_PASSWORD
SYSTEM_DB_APP_PASSWORD
SYSTEM_DB_MIGRATION_PASSWORD
YGH_PRODUCT_DB_APP_PASSWORD
YGH_PRODUCT_DB_MIGRATION_PASSWORD
YGH_INVENTORY_DB_APP_PASSWORD
YGH_INVENTORY_DB_MIGRATION_PASSWORD
YGH_ORDER_DB_APP_PASSWORD
YGH_ORDER_DB_MIGRATION_PASSWORD
YGH_WALLET_DB_APP_PASSWORD
YGH_WALLET_DB_MIGRATION_PASSWORD
YGH_KNOWLEDGE_DB_APP_PASSWORD
YGH_KNOWLEDGE_DB_MIGRATION_PASSWORD
YGH_AI_DB_APP_PASSWORD
YGH_AI_DB_MIGRATION_PASSWORD
YGH_TRAINING_DB_APP_PASSWORD
YGH_TRAINING_DB_MIGRATION_PASSWORD
YGH_NOTIFICATION_DB_APP_PASSWORD
YGH_NOTIFICATION_DB_MIGRATION_PASSWORD
REDIS_PASSWORD
NACOS_AUTH_IDENTITY_KEY
NACOS_AUTH_IDENTITY_VALUE
NACOS_ADMIN_PASSWORD
POSTGRES_PASSWORD
ELASTIC_PASSWORD
SEATA_PASSWORD
```

### 第五步：生成 Base64 密钥并填入 .env

在 Windows PowerShell 输入：

```powershell
$b=New-Object byte[] 32; [System.Security.Cryptography.RandomNumberGenerator]::Fill($b); [Convert]::ToBase64String($b)
```

执行后的结果：

输出一个 32 字节 Base64 密钥。

需要修改的内容：

分别生成并填入：

```text
USER_PII_KEY_BASE64
AUTH_AUDIT_PEPPER_BASE64
INTERNAL_REQUEST_HMAC_BASE64
```

继续输入：

```powershell
$b=New-Object byte[] 48; [System.Security.Cryptography.RandomNumberGenerator]::Fill($b); [Convert]::ToBase64String($b)
```

执行后的结果：

输出一个更长的 Base64 Token。

需要修改的内容：

填入：

```text
NACOS_AUTH_TOKEN
```

### 第六步：检查 .env 是否还有占位符

保存并关闭记事本。

在 Windows PowerShell 输入：

```powershell
Select-String -Path .\.env -Pattern 'change-me|base64-at-least-32-bytes|base64-exactly-32-bytes'
```

执行后的结果：

没有任何输出。

需要修改的内容：

如果还有输出，说明 `.env` 还没改完，重新打开：

```powershell
notepad .\.env
```

继续修改。

### 第七步：如果虚拟机 IP 不是默认值，修改 vm-compose.yml

默认虚拟机 IP 是：

```text
192.168.154.10
```

如果客户实际 IP 不是这个，在 Windows PowerShell 输入：

```powershell
notepad .\vm-compose.yml
```

把所有：

```text
192.168.154.10
```

替换成客户实际虚拟机 IP，例如：

```text
192.168.80.10
```

保存后输入：

```powershell
Select-String -Path .\vm-compose.yml -Pattern '192.168'
```

执行后的结果：

输出中的 IP 必须全部是客户实际虚拟机 IP。

需要修改的内容：

只改端口绑定 IP，不要改镜像版本、服务名、volume 名。

### 第八步：复制部署目录到虚拟机

在 Windows PowerShell 输入：

```powershell
ssh wang@192.168.154.10 'sudo mkdir -p /opt/ygh; sudo chown -R wang:wang /opt/ygh'
```

继续输入：

```powershell
ssh wang@192.168.154.10 'if [ -d /opt/ygh/constrained-dev ]; then mv /opt/ygh/constrained-dev /opt/ygh/constrained-dev.bak-$(date +%Y%m%d-%H%M%S); fi; mkdir -p /opt/ygh/constrained-dev'
```

继续输入：

```powershell
scp -r .\* wang@192.168.154.10:/opt/ygh/constrained-dev/
```

继续输入：

```powershell
scp .\.env wang@192.168.154.10:/opt/ygh/constrained-dev/.env
```

继续输入：

```powershell
ssh wang@192.168.154.10 'ls -la /opt/ygh/constrained-dev | head'
```

执行后的结果：

能看到：

```text
.env
vm-compose.yml
mysql
postgres
```

需要修改的内容：

如果用户名或 IP 不同，替换所有 `wang@192.168.154.10`。

---

## 第六部分：手动安装 Docker

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

### 第四步：安装 Docker Engine 和 Compose 插件

安装位置：

```text
安装到 Rocky Linux 虚拟机里。
Docker 命令路径：/usr/bin/docker
Docker Compose 插件路径通常为：/usr/libexec/docker/cli-plugins/docker-compose
Docker 配置文件：/etc/docker/daemon.json
Docker 数据目录：/var/lib/docker
不安装到 Windows Docker Desktop，也不安装到 WSL2。
```

输入：

```bash
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

执行后的结果：

最后看到：

```text
Complete!
```

需要修改的内容：

不要只安装 `docker` 命令，必须同时安装 `docker-compose-plugin`，因为项目使用的是：

```bash
docker compose
```

不是：

```bash
docker-compose
```

### 第五步：手动写入 Docker 配置

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
  "registry-mirrors": [
    "https://docker.m.daocloud.io",
    "https://docker.1ms.run"
  ],
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

如果客户现场有指定 Docker 镜像代理，把 `registry-mirrors` 改成客户自己的代理地址。

### 第六步：启动 Docker

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
docker compose version
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

`docker compose version` 正常输出 Compose 插件版本。

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

### 第十步：处理 Docker Hub 被封或超时

先输入：

```bash
ping -c 4 223.5.5.5
```

继续输入：

```bash
ping -c 4 registry-1.docker.io
```

继续输入：

```bash
curl -I https://registry-1.docker.io/v2/
```

执行后的结果：

如果 `223.5.5.5` 都不通，说明 VMware NAT 没配好。

如果 IP 能通但域名不通，说明 DNS 没配好。

如果能访问网络但 `docker pull` 超时，通常是 Docker Hub 被封或镜像代理不可用。

需要修改的内容：

手动改 Docker 镜像代理。输入：

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
  "registry-mirrors": [
    "https://docker.m.daocloud.io",
    "https://dockerproxy.com",
    "https://dockerpull.com",
    "https://docker.1panel.live",
    "https://docker.1ms.run"
  ],
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

继续输入：

```bash
sudo systemctl restart docker
```

继续输入：

```bash
docker pull alpine
```

执行后的结果：

能拉取 `alpine`。

如果仍然失败，使用离线导入镜像。

### 第十一步：离线导入项目镜像

在一台能访问 Docker Hub 的机器输入：

```bash
docker pull mysql:8.4.10
```

继续输入：

```bash
docker pull redis:8.4.4
```

继续输入：

```bash
docker pull nacos/nacos-server:v3.1.1
```

继续输入：

```bash
docker pull pgvector/pgvector:0.8.5-pg17-bookworm
```

继续输入：

```bash
docker save -o ygh-vm-images.tar mysql:8.4.10 redis:8.4.4 nacos/nacos-server:v3.1.1 pgvector/pgvector:0.8.5-pg17-bookworm
```

把 `ygh-vm-images.tar` 拷贝到客户虚拟机，例如放到：

```text
/opt/ygh/ygh-vm-images.tar
```

在客户虚拟机输入：

```bash
cd /opt/ygh
```

继续输入：

```bash
docker load -i ygh-vm-images.tar
```

继续输入：

```bash
docker images | grep -E 'mysql|redis|nacos|pgvector'
```

执行后的结果：

能看到：

```text
mysql                         8.4.10
redis                         8.4.4
nacos/nacos-server            v3.1.1
pgvector/pgvector             0.8.5-pg17-bookworm
```

需要修改的内容：

离线导入成功后，后面启动项目可以不执行 `pull`，直接执行 `up -d`。

---

## 第七部分：手动配置虚拟机防火墙

### 第一步：启动 firewalld

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

## 第八部分：手动启动 MySQL、Redis、Nacos

运行位置：

```text
MySQL、Redis、Nacos 不安装到 Linux 系统目录。
它们运行在 Rocky Linux 虚拟机的 Docker 容器里。
Compose 文件：/opt/ygh/constrained-dev/vm-compose.yml
环境变量文件：/opt/ygh/constrained-dev/.env
Docker 数据卷目录由 Docker 管理，底层在：/var/lib/docker/volumes
MySQL 数据卷：ygh-mysql-data
Redis 数据卷：ygh-redis-data
Nacos 数据存在 MySQL 的 nacos_config 库里。
```

### 第一步：进入部署目录

在 Rocky Linux 输入：

```bash
cd /opt/ygh/constrained-dev
```

继续输入：

```bash
pwd
```

继续输入：

```bash
ls -la
```

执行后的结果：

`pwd` 输出：

```text
/opt/ygh/constrained-dev
```

`ls` 能看到：

```text
.env
vm-compose.yml
mysql
postgres
```

需要修改的内容：

如果没有 `.env`，回到 Windows 复制 `.env`。

### 第二步：检查 Compose 配置

输入：

```bash
docker compose --env-file .env -f vm-compose.yml --profile core config >/dev/null
```

继续输入：

```bash
echo $?
```

执行后的结果：

看到：

```text
0
```

需要修改的内容：

如果报：

```text
required variable ... is missing
```

说明 `.env` 缺字段，回 Windows 打开 `.env` 补全。

### 第三步：拉取核心镜像

输入：

```bash
docker compose --env-file .env -f vm-compose.yml --profile core pull
```

执行后的结果：

会拉取：

```text
mysql:8.4.10
redis:8.4.4
nacos/nacos-server:v3.1.1
```

需要修改的内容：

如果已经离线导入镜像，这一步可以跳过。

如果拉取失败，回到 Docker 镜像封锁处理步骤。

### 第四步：启动核心组件

输入：

```bash
docker compose --env-file .env -f vm-compose.yml --profile core up -d
```

执行后的结果：

看到类似：

```text
Container ygh-vm-mysql-1  Started
Container ygh-vm-redis-1  Started
Container ygh-vm-nacos-1  Started
```

需要修改的内容：

第一次启动 MySQL 会自动读取 `mysql/init` 目录里的项目初始化文件，创建 Nacos 库、认证库、用户库、系统库和业务库。

这些初始化文件由 MySQL 容器入口自动读取，不需要客户手工执行，也不需要客户手工建库。

### 第五步：查看容器状态

输入：

```bash
docker compose --env-file .env -f vm-compose.yml --profile core ps
```

执行后的结果：

最终应该看到：

```text
mysql   healthy
redis   healthy
nacos   healthy
```

需要修改的内容：

如果 Nacos 暂时是 `starting`，等待 1 到 3 分钟后再次执行同一条命令。

### 第六步：查看启动日志

输入：

```bash
docker compose --env-file .env -f vm-compose.yml --profile core logs --tail=80 mysql
```

继续输入：

```bash
docker compose --env-file .env -f vm-compose.yml --profile core logs --tail=80 redis
```

继续输入：

```bash
docker compose --env-file .env -f vm-compose.yml --profile core logs --tail=120 nacos
```

执行后的结果：

没有反复重启、密码错误、端口占用、数据库连接失败。

需要修改的内容：

如果日志提示端口绑定失败，检查 `vm-compose.yml` 里的 IP 是否就是虚拟机 IP。

### 第七步：验证 MySQL

输入：

```bash
docker compose --env-file .env -f vm-compose.yml --profile core exec -T mysql sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysqladmin ping -h 127.0.0.1 -uroot --silent'
```

继续输入：

```bash
docker compose --env-file .env -f vm-compose.yml --profile core exec -T mysql sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -uroot -Nse "SELECT 1"'
```

执行后的结果：

第一条没有报错。

第二条输出：

```text
1
```

需要修改的内容：

如果提示认证失败，检查 `.env` 里的 `MYSQL_ROOT_PASSWORD`。如果这是第一次启动后才发现密码写错，需要先确认是否允许删除测试数据卷；不要直接删除客户数据卷。

### 第八步：验证 Redis

输入：

```bash
docker compose --env-file .env -f vm-compose.yml --profile core exec -T redis sh -c 'REDISCLI_AUTH="$REDIS_PASSWORD" redis-cli ping'
```

执行后的结果：

看到：

```text
PONG
```

需要修改的内容：

如果提示认证失败，检查 `.env` 里的 `REDIS_PASSWORD`。

### 第九步：验证 Nacos

输入：

```bash
docker compose --env-file .env -f vm-compose.yml --profile core exec -T nacos curl -fsS http://127.0.0.1:8848/nacos/v3/admin/core/state/readiness
```

继续输入：

```bash
docker compose --env-file .env -f vm-compose.yml --profile core exec -T nacos curl -fsS http://127.0.0.1:8080/v3/console/health/readiness
```

执行后的结果：

命令正常返回，不报错。

需要修改的内容：

如果失败，先看 Nacos 日志：

```bash
docker compose --env-file .env -f vm-compose.yml --profile core logs --tail=200 nacos
```

### 第十步：手动初始化 Nacos 管理员密码

输入：

```bash
set -a
```

继续输入：

```bash
. ./.env
```

继续输入：

```bash
set +a
```

继续输入：

```bash
curl -sS -X POST "http://192.168.154.10:8848/nacos/v3/auth/user/admin" --data-urlencode "password=${NACOS_ADMIN_PASSWORD}"
```

继续输入：

```bash
curl -sS -X POST "http://192.168.154.10:8848/nacos/v3/auth/user/login" --data-urlencode "username=nacos" --data-urlencode "password=${NACOS_ADMIN_PASSWORD}"
```

执行后的结果：

登录接口返回内容中包含：

```text
accessToken
```

需要修改的内容：

如果虚拟机 IP 不是 `192.168.154.10`，把 URL 里的 IP 改成客户实际虚拟机 IP。

如果提示用户已存在，可以直接执行登录命令验证。

### 第十一步：Windows 验证端口

在 Windows PowerShell 输入：

```powershell
Test-NetConnection 192.168.154.10 -Port 3306
```

继续输入：

```powershell
Test-NetConnection 192.168.154.10 -Port 6379
```

继续输入：

```powershell
Test-NetConnection 192.168.154.10 -Port 8848
```

继续输入：

```powershell
Test-NetConnection 192.168.154.10 -Port 9848
```

执行后的结果：

每条都应该看到：

```text
TcpTestSucceeded : True
```

需要修改的内容：

如果端口不通，按顺序检查：

```text
1. 虚拟机 IP 是否正确
2. vm-compose.yml 端口绑定 IP 是否正确
3. firewalld rich rule 源地址是否是 Windows VMnet8 IP
4. 容器是否 healthy
```

---

## 第九部分：手动启动 PGVector

运行位置：

```text
PGVector 不安装到 Linux 系统目录。
它运行在 Rocky Linux 虚拟机的 Docker 容器里。
Compose 文件：/opt/ygh/constrained-dev/vm-compose.yml
数据卷：ygh-pgvector-data
底层数据卷目录由 Docker 管理，位于：/var/lib/docker/volumes
不运行在 Windows Docker Desktop、WSL2 或 IDEA。
```

### 第一步：确认是否需要启动 PGVector

PGVector 用于 AI 向量数据场景。

如果当前只跑商城、用户、系统、认证等基础服务，可以先不启动 PGVector。

执行后的结果：

低配置电脑可以少占用内存。

需要修改的内容：

需要 AI 知识库向量检索时再启动。

### 第二步：拉取 PGVector 镜像

在 Rocky Linux 输入：

```bash
cd /opt/ygh/constrained-dev
```

继续输入：

```bash
docker compose --env-file .env -f vm-compose.yml --profile ai-data pull pgvector
```

执行后的结果：

拉取：

```text
pgvector/pgvector:0.8.5-pg17-bookworm
```

需要修改的内容：

如果已经离线导入镜像，这一步可以跳过。

### 第三步：启动 PGVector

输入：

```bash
docker compose --env-file .env -f vm-compose.yml --profile ai-data up -d pgvector
```

执行后的结果：

看到：

```text
Container ygh-vm-pgvector-1  Started
```

需要修改的内容：

PGVector 端口是 `5432`，密码来自 `.env` 的 `POSTGRES_PASSWORD`。

### 第四步：验证 PGVector

输入：

```bash
docker compose --env-file .env -f vm-compose.yml --profile ai-data exec -T pgvector pg_isready -U ygh_vector -d ygh_vector
```

继续输入：

```bash
docker compose --env-file .env -f vm-compose.yml --profile ai-data exec -T pgvector psql -U ygh_vector -d ygh_vector -c "SELECT extversion FROM pg_extension WHERE extname = 'vector';"
```

执行后的结果：

第一条看到：

```text
accepting connections
```

第二条能看到 vector 扩展版本。

需要修改的内容：

如果没有 vector 扩展，检查这个文件是否已经复制到虚拟机：

```text
/opt/ygh/constrained-dev/postgres/init/01-enable-vector.sql
```

### 第五步：Windows 验证 PGVector 端口

在 Windows PowerShell 输入：

```powershell
Test-NetConnection 192.168.154.10 -Port 5432
```

执行后的结果：

看到：

```text
TcpTestSucceeded : True
```

### 第六步：不用时停止 PGVector

在 Rocky Linux 输入：

```bash
cd /opt/ygh/constrained-dev
```

继续输入：

```bash
docker compose --env-file .env -f vm-compose.yml --profile ai-data stop pgvector
```

执行后的结果：

PGVector 容器停止，数据卷保留。

需要修改的内容：

不要执行：

```bash
docker compose down -v
```

`-v` 会删除数据卷。

---

## 第十部分：组件配置位置

### 第一步：查看 MySQL 配置

在 Rocky Linux 输入：

```bash
cd /opt/ygh/constrained-dev
```

继续输入：

```bash
cat mysql/conf.d/ygh-low-memory.cnf
```

执行后的结果：

能看到：

```text
character-set-server=utf8mb4
collation-server=utf8mb4_0900_ai_ci
default-time-zone=+08:00
innodb_buffer_pool_size=256M
max_connections=80
performance_schema=OFF
```

需要修改的内容：

低配置客户电脑不要随意调大 `innodb_buffer_pool_size`。

### 第二步：确认 MySQL 初始化文件

输入：

```bash
ls -la mysql/init
```

执行后的结果：

能看到项目提供的 Nacos、Auth、User、System、业务库初始化文件。

需要修改的内容：

这些文件只在 MySQL 数据卷第一次创建时自动执行。容器已经有数据后，改这些文件不会自动重跑。

### 第三步：查看 Redis 配置

输入：

```bash
grep -A 20 'redis:' vm-compose.yml
```

执行后的结果：

能看到：

```text
--appendonly yes
--appendfsync everysec
--maxmemory 96mb
--maxmemory-policy noeviction
--requirepass "$${REDIS_PASSWORD}"
```

需要修改的内容：

Redis 密码只改 `.env` 的 `REDIS_PASSWORD`。不要把密码直接写死在 `vm-compose.yml`。

### 第四步：查看 Nacos 配置

输入：

```bash
grep -A 45 'nacos:' vm-compose.yml
```

执行后的结果：

能看到：

```text
MODE: standalone
SPRING_DATASOURCE_PLATFORM: mysql
MYSQL_SERVICE_DB_NAME: nacos_config
NACOS_AUTH_ENABLE: "true"
NACOS_AUTH_ADMIN_ENABLE: "true"
JVM_XMS: 384m
JVM_XMX: 384m
```

需要修改的内容：

Nacos 管理员密码来自 `.env`：

```text
NACOS_ADMIN_PASSWORD
```

### 第五步：查看 PGVector 配置

输入：

```bash
grep -A 35 'pgvector:' vm-compose.yml
```

执行后的结果：

能看到：

```text
POSTGRES_DB: ygh_vector
POSTGRES_USER: ygh_vector
shared_buffers=64MB
max_connections=30
work_mem=2MB
```

需要修改的内容：

PGVector 密码来自 `.env`：

```text
POSTGRES_PASSWORD
```

---

## 第十一部分：Windows IDEA 连接虚拟机配置

### 第一步：确认 JDK 安装位置

JDK 25 安装在 Windows，不安装在虚拟机。

安装位置：

```text
Windows 本机：C:\Program Files\Eclipse Adoptium\jdk-25.0.3.7-hotspot
IDEA 使用这个 JDK 启动后端服务。
Rocky Linux 虚拟机里不安装 JDK。
Docker 容器里也不安装项目开发用 JDK。
```

在 Windows PowerShell 输入：

```powershell
java -version
where java
echo $env:JAVA_HOME
```

执行后的结果：

应该看到：

```text
java -version 第一行包含 openjdk version "25
where java 第一行来自 C:\Program Files\Eclipse Adoptium\jdk-25...\bin\java.exe
echo $env:JAVA_HOME 输出 C:\Program Files\Eclipse Adoptium\jdk-25...
```

需要修改的内容：

如果没有 Java 25，在 Windows 安装 JDK 25，然后配置系统环境变量。

图形界面配置方法：

1. 右键“此电脑”。
2. 点击“属性”。
3. 点击“高级系统设置”。
4. 点击“环境变量”。
5. 在下面的“系统变量”里新建或编辑 `JAVA_HOME`。
6. 变量名填写：

```text
JAVA_HOME
```

7. 变量值填写 JDK 25 安装目录，示例：

```text
C:\Program Files\Eclipse Adoptium\jdk-25.0.3.7-hotspot
```

8. 注意 `JAVA_HOME` 不要带 `\bin`：

```text
正确：C:\Program Files\Eclipse Adoptium\jdk-25.0.3.7-hotspot
错误：C:\Program Files\Eclipse Adoptium\jdk-25.0.3.7-hotspot\bin
```

9. 在“系统变量”里编辑 `Path`。
10. 新增：

```text
%JAVA_HOME%\bin
```

11. 把 `%JAVA_HOME%\bin` 放到旧版 Java 路径前面。
12. 点击“确定”保存。
13. 关闭 PowerShell，重新打开，再执行验证命令。

管理员 PowerShell 配置方法：

```powershell
[Environment]::SetEnvironmentVariable('JAVA_HOME','C:\Program Files\Eclipse Adoptium\jdk-25.0.3.7-hotspot','Machine')
```

继续输入：

```powershell
$machinePath = [Environment]::GetEnvironmentVariable('Path','Machine')
if ($machinePath -notlike '*%JAVA_HOME%\bin*') {
  [Environment]::SetEnvironmentVariable('Path', "%JAVA_HOME%\bin;$machinePath", 'Machine')
}
```

执行后的结果：

重新打开 PowerShell 后，`echo $env:JAVA_HOME` 输出 JDK 25 根目录，`where java` 第一行指向 `%JAVA_HOME%\bin\java.exe`。

### 第二步：确认后端连接地址

后端服务在 Windows IDEA 启动时，连接虚拟机地址：

```text
MySQL:    192.168.154.10:3306
Redis:    192.168.154.10:6379
Nacos:    192.168.154.10:8848
PGVector: 192.168.154.10:5432
```

执行后的结果：

Windows Java 服务可以访问虚拟机组件。

需要修改的内容：

如果虚拟机 IP 改了，IDEA 运行配置、Spring 配置、Nacos 配置里也要同步改成客户实际 IP。

---

## 第十二部分：手动备份数据

### 第一步：创建备份目录

在 Rocky Linux 输入：

```bash
backup_dir="/opt/ygh/backups/$(date +%Y%m%d-%H%M%S)"
```

继续输入：

```bash
mkdir -p "$backup_dir"
```

继续输入：

```bash
echo "$backup_dir"
```

执行后的结果：

输出本次备份目录，例如：

```text
/opt/ygh/backups/20260713-153000
```

### 第二步：备份 MySQL

输入：

```bash
cd /opt/ygh/constrained-dev
```

继续输入：

```bash
docker compose --env-file .env -f vm-compose.yml --profile core exec -T mysql sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysqldump -uroot --all-databases --single-transaction --routines --events' | gzip > "$backup_dir/mysql-all.sql.gz"
```

执行后的结果：

生成：

```text
mysql-all.sql.gz
```

需要修改的内容：

如果 MySQL 容器没有启动，先启动核心组件。

### 第三步：备份 PGVector

如果 PGVector 已启动，输入：

```bash
docker compose --env-file .env -f vm-compose.yml --profile ai-data exec -T pgvector pg_dump -U ygh_vector -d ygh_vector | gzip > "$backup_dir/pgvector-ygh-vector.sql.gz"
```

执行后的结果：

生成：

```text
pgvector-ygh-vector.sql.gz
```

需要修改的内容：

如果没有启动 PGVector，可以跳过这一步。

### 第四步：保存备份校验值

输入：

```bash
cd "$backup_dir"
```

继续输入：

```bash
sha256sum * > SHA256SUMS.txt
```

继续输入：

```bash
ls -lh
```

执行后的结果：

能看到备份文件和：

```text
SHA256SUMS.txt
```

需要修改的内容：

把备份目录复制到客户指定备份盘，不要只放在虚拟机里。

---

## 第十三部分：常见问题处理

### 问题一：Windows 端口不通

在 Windows PowerShell 输入：

```powershell
Test-NetConnection 192.168.154.10 -Port 3306
```

如果失败，在 Rocky Linux 输入：

```bash
ip addr
```

继续输入：

```bash
sudo firewall-cmd --list-rich-rules
```

继续输入：

```bash
docker compose --env-file /opt/ygh/constrained-dev/.env -f /opt/ygh/constrained-dev/vm-compose.yml --profile core ps
```

执行后的结果：

定位失败位置：

```text
IP 不对：改 nmcli 固定 IP
防火墙不对：重新添加 rich rule
容器没启动：重新 docker compose up -d
```

### 问题二：Docker 镜像拉不下来

输入：

```bash
docker pull alpine
```

如果失败，输入：

```bash
curl -I https://registry-1.docker.io/v2/
```

执行后的结果：

如果网络通但拉镜像失败，改 `/etc/docker/daemon.json` 的 `registry-mirrors`，然后：

```bash
sudo dockerd --validate --config-file=/etc/docker/daemon.json
sudo systemctl restart docker
docker pull alpine
```

如果仍失败，走离线导入 `ygh-vm-images.tar`。

### 问题三：Nacos 登录失败

输入：

```bash
cd /opt/ygh/constrained-dev
set -a
. ./.env
set +a
curl -sS -X POST "http://192.168.154.10:8848/nacos/v3/auth/user/login" --data-urlencode "username=nacos" --data-urlencode "password=${NACOS_ADMIN_PASSWORD}"
```

执行后的结果：

成功时返回 `accessToken`。

需要修改的内容：

如果没有初始化管理员，重新执行：

```bash
curl -sS -X POST "http://192.168.154.10:8848/nacos/v3/auth/user/admin" --data-urlencode "password=${NACOS_ADMIN_PASSWORD}"
```

### 问题四：MySQL 初始化库没有创建

输入：

```bash
cd /opt/ygh/constrained-dev
docker compose --env-file .env -f vm-compose.yml --profile core exec -T mysql sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -uroot -Nse "SHOW DATABASES;"'
```

执行后的结果：

应看到：

```text
nacos_config
auth_db
user_db
system_db
```

需要修改的内容：

MySQL 初始化文件只在第一次创建数据卷时运行。如果是测试环境且确认可以清空数据，才可以删除数据卷重新初始化；客户正式数据不能这样做。

---

## 第十四部分：最终检查

### 第一步：检查 Docker 组件状态

在 Rocky Linux 输入：

```bash
cd /opt/ygh/constrained-dev
```

继续输入：

```bash
docker compose --env-file .env -f vm-compose.yml --profile core ps
```

执行后的结果：

应看到：

```text
mysql healthy
redis healthy
nacos healthy
```

### 第二步：检查核心服务健康

输入：

```bash
docker compose --env-file .env -f vm-compose.yml --profile core exec -T mysql sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -uroot -Nse "SELECT 1"'
```

继续输入：

```bash
docker compose --env-file .env -f vm-compose.yml --profile core exec -T redis sh -c 'REDISCLI_AUTH="$REDIS_PASSWORD" redis-cli ping'
```

继续输入：

```bash
docker compose --env-file .env -f vm-compose.yml --profile core exec -T nacos curl -fsS http://127.0.0.1:8848/nacos/v3/admin/core/state/readiness
```

执行后的结果：

MySQL 输出 `1`，Redis 输出 `PONG`，Nacos 命令不报错。

### 第三步：检查 Windows 端口

在 Windows PowerShell 输入：

```powershell
Test-NetConnection 192.168.154.10 -Port 3306
Test-NetConnection 192.168.154.10 -Port 6379
Test-NetConnection 192.168.154.10 -Port 8848
Test-NetConnection 192.168.154.10 -Port 9848
```

执行后的结果：

全部显示：

```text
TcpTestSucceeded : True
```

完成标准：

```text
1. Rocky Linux 固定 IP 正确
2. SSH 可以登录
3. Docker 和 docker compose 可用
4. 防火墙只允许 Windows VMnet8 IP 访问组件端口
5. MySQL、Redis、Nacos healthy
6. Nacos 管理员可以登录
7. Windows 能访问 3306、6379、8848、9848
8. 需要 AI 向量场景时，PGVector 5432 可以访问
```
