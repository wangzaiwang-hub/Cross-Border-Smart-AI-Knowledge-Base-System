# Rocky Linux 虚拟机从零配置指南

> 适用场景：客户不使用我们提供的虚拟机，需要自己在 Windows + VMware Workstation Pro 中从零创建 Rocky Linux 虚拟机，并在虚拟机内运行 MySQL、Redis、Nacos 和按需 PGVector。  
> 默认目标：虚拟机 IP 为 `192.168.154.10`，Windows VMware NAT 主机地址为 `192.168.154.1`，VMware NAT 网关为 `192.168.154.2`，Linux 用户为 `wang`。  
> 重要提醒：如果客户本机 NAT 网段不是 `192.168.154.0/24`，必须按本文第 2、6、12、17 步修改，否则 Windows 后端服务和虚拟机中间件无法互通。

## 0. 最终要得到什么

配置完成后，虚拟机中长期运行：

| 组件 | 版本 | 端口 | 访问来源 |
|---|---|---:|---|
| MySQL | 8.4.10 | `3306` | 仅允许 Windows VMware NAT 主机 |
| Redis | 8.4.4 | `6379` | 仅允许 Windows VMware NAT 主机 |
| Nacos | 3.1.1 | `8848`、`9848`、`8080` | 仅允许 Windows VMware NAT 主机 |
| PGVector | 0.8.5 + PostgreSQL 17 | `5432` | 按需启动，仅允许 Windows VMware NAT 主机 |

本文所有命令分两类：

- 标注 `Windows PowerShell` 的命令，在 Windows Terminal 的 PowerShell 页签执行。
- 标注 `Rocky Linux` 的命令，在虚拟机终端或 SSH 登录后的终端执行。

不要执行：

```bash
docker compose down -v
```

`-v` 会删除 MySQL、Redis、PGVector 数据卷。

## 1. 下载 VMware Workstation Pro 和 Rocky Linux ISO

这一步没有命令，使用浏览器下载。

输入内容：

```text
https://www.vmware.com/products/desktop-hypervisor/workstation-and-fusion
https://support.broadcom.com/
https://rockylinux.org/download
```

执行后的结果：

- Windows 上安装好 VMware Workstation Pro。
- 本地保存 Rocky Linux 9 Minimal ISO，例如：

```text
D:\ISO\Rocky-9.6-x86_64-minimal.iso
```

需要修改的内容：

- ISO 文件名不一定和示例完全一致，以客户实际下载文件为准。
- 如果 VMware 官网跳转到 Broadcom 登录页，按 Broadcom 页面注册/登录后下载 Workstation Pro。

具体配置方法：

1. 打开 VMware 下载页面，下载 Windows 版 VMware Workstation Pro。
2. 双击安装包，按默认选项安装。
3. 打开 Rocky Linux 下载页。
4. 选择 Rocky Linux 9、`x86_64`、`Minimal ISO`。
5. 下载完成后不要删除 ISO，创建虚拟机时会用到。

## 2. 确认 Windows 的 VMware NAT 网段

必须先确认客户电脑的 VMware NAT 网段。本文默认：

- Windows VMware NAT 主机地址：`192.168.154.1`
- 虚拟机固定 IP：`192.168.154.10`
- VMware NAT 网关：`192.168.154.2`
- 子网掩码：`255.255.255.0`

输入命令 `Windows PowerShell`：

```powershell
ipconfig
```

执行后的结果：

在输出中找到类似下面的适配器：

```text
Ethernet adapter VMware Network Adapter VMnet8:

   IPv4 Address. . . . . . . . . . . : 192.168.154.1
   Subnet Mask . . . . . . . . . . . : 255.255.255.0
```

需要修改的内容：

- 如果客户看到的是 `192.168.154.1`，后文可以直接照抄命令。
- 如果客户看到的是 `192.168.80.1`，则后文所有 `192.168.154` 都要改成 `192.168.80`。
- 如果客户看到的是 `192.168.137.1`，则后文所有 `192.168.154` 都要改成 `192.168.137`。

具体配置方法：

1. 记下 `VMware Network Adapter VMnet8` 的 IPv4 地址，本文称为 `WINDOWS_NAT_IP`。
2. 将最后一段改成 `10`，作为虚拟机固定 IP。  
   示例：`WINDOWS_NAT_IP=192.168.80.1`，则虚拟机 IP 使用 `192.168.80.10`。
3. 将最后一段改成 `2`，作为 NAT 网关。  
   示例：`WINDOWS_NAT_IP=192.168.80.1`，则网关通常是 `192.168.80.2`。
4. 如果不确定网关，打开 VMware：`Edit → Virtual Network Editor → VMnet8 → NAT Settings`，查看 `Gateway IP`。

后文默认继续使用：

```text
WINDOWS_NAT_IP=192.168.154.1
VM_IP=192.168.154.10
VM_GATEWAY=192.168.154.2
```

## 3. 创建 VMware 虚拟机

这一步主要在 VMware 图形界面操作。

输入内容：

```text
Create a New Virtual Machine
```

执行后的结果：

得到一台空的 Rocky Linux 虚拟机，硬件建议如下：

| 配置项 | 推荐值 |
|---|---|
| CPU | 2 核 |
| 内存 | 3584 MB，内存充足可设为 4096 MB |
| 硬盘 | 40 GB 或以上 |
| 网络 | NAT，使用 VMnet8 |
| 光驱 | Rocky Linux 9 Minimal ISO |

需要修改的内容：

- 如果客户电脑内存小于 16GB，虚拟机内存建议 `3584MB`。
- 如果客户电脑内存大于 32GB，虚拟机内存可设为 `4096MB` 或更高。
- 网络必须选择 NAT，不要选择 Bridged。本文防火墙规则按 NAT 主机访问设计。

具体配置方法：

1. 打开 VMware Workstation Pro。
2. 点击 `Create a New Virtual Machine`。
3. 选择 `Typical`。
4. 选择第 1 步下载的 Rocky Linux Minimal ISO。
5. Guest OS 选择 `Linux`。
6. Version 选择 `Rocky Linux 64-bit`；如果没有该选项，选 `Other Linux 5.x kernel 64-bit`。
7. 虚拟机名称填写：

```text
ygh-rocky-dev
```

8. 虚拟机存放目录建议：

```text
D:\VMs\ygh-rocky-dev
```

9. 磁盘大小填写：

```text
40 GB
```

10. 选择 `Store virtual disk as a single file` 或 `Split virtual disk into multiple files` 均可。
11. 点击 `Customize Hardware`。
12. Memory 设置为 `3584MB`。
13. Processors 设置为 `2`。
14. Network Adapter 选择 `NAT`。
15. CD/DVD 确认挂载 Rocky Linux Minimal ISO。
16. 点击 `Finish`。

## 4. 安装 Rocky Linux 9 Minimal

这一步在虚拟机控制台操作。

输入内容：

```text
Start up this guest operating system
```

执行后的结果：

Rocky Linux 安装完成，可以登录普通用户 `wang`。

需要修改的内容：

- 用户名默认写 `wang`，后续脚本也默认给 `wang` 加 Docker 权限。
- 如果客户必须使用其他用户名，例如 `admin`，后文所有 `wang` 都必须替换成实际用户名，并且 Docker 安装脚本中也要确认 `usermod -aG docker wang` 是否需要改。

具体配置方法：

1. 启动虚拟机。
2. 进入 Rocky Linux 安装界面后选择 `Install Rocky Linux 9`。
3. 语言建议选择 `English`，也可以选择中文。
4. 点击 `Installation Destination`，选择默认磁盘，使用自动分区。
5. 点击 `Root Password`，设置 root 密码。
6. 点击 `User Creation`，创建用户：

```text
Full name: wang
User name: wang
勾选 Make this user administrator
设置一个强密码
```

7. 点击 `Begin Installation`。
8. 安装完成后点击 `Reboot System`。
9. 如果重启后再次进入安装界面，关闭虚拟机，在 VMware 的 CD/DVD 设置里取消 ISO 挂载，然后再启动。
10. 登录用户 `wang`。

## 5. 第一次登录后检查系统

输入命令 `Rocky Linux`：

```bash
whoami
cat /etc/os-release
free -h
df -h /
ip addr
nmcli connection show
```

执行后的结果：

应该看到：

- `whoami` 输出 `wang`。
- `/etc/os-release` 包含 `Rocky Linux` 和 `VERSION_ID="9.x"`。
- `free -h` 能看到约 3.5GB 或 4GB 内存。
- `df -h /` 能看到根分区可用空间。
- `ip addr` 能看到网卡名，例如 `ens160`。
- `nmcli connection show` 能看到连接名，例如 `ens160` 或 `Wired connection 1`。

需要修改的内容：

- 后文命令默认网卡连接名是 `ens160`。
- 如果 `nmcli connection show` 里连接名不是 `ens160`，后文所有 `ens160` 都要替换为实际连接名。

具体配置方法：

找到连接名：

```bash
nmcli connection show
```

示例输出：

```text
NAME    UUID                                  TYPE      DEVICE
ens160  xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx  ethernet  ens160
```

这里连接名就是 `ens160`。

如果输出是：

```text
NAME                UUID                                  TYPE      DEVICE
Wired connection 1  xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx  ethernet  ens160
```

后文命令中的 `ens160` 要替换成：

```text
Wired connection 1
```

带空格的连接名必须用英文引号包起来。

## 6. 配置虚拟机固定 IP

默认命令适用于：

```text
连接名：ens160
虚拟机 IP：192.168.154.10
网关：192.168.154.2
DNS：223.5.5.5 和 8.8.8.8
```

输入命令 `Rocky Linux`：

```bash
sudo nmcli connection modify ens160 ipv4.method manual \
  ipv4.addresses 192.168.154.10/24 \
  ipv4.gateway 192.168.154.2 \
  ipv4.dns "223.5.5.5 8.8.8.8"
sudo nmcli connection up ens160
ip addr show ens160
ip route
```

执行后的结果：

`ip addr show ens160` 应看到：

```text
inet 192.168.154.10/24
```

`ip route` 应看到：

```text
default via 192.168.154.2
```

需要修改的内容：

- 如果第 2 步确认的 VMware NAT 网段不是 `192.168.154.0/24`，必须修改 IP 和网关。
- 如果连接名不是 `ens160`，必须修改连接名。

具体配置方法：

示例 1：客户 NAT 网段是 `192.168.80.0/24`，连接名仍是 `ens160`：

```bash
sudo nmcli connection modify ens160 ipv4.method manual \
  ipv4.addresses 192.168.80.10/24 \
  ipv4.gateway 192.168.80.2 \
  ipv4.dns "223.5.5.5 8.8.8.8"
sudo nmcli connection up ens160
ip addr show ens160
ip route
```

示例 2：连接名是 `Wired connection 1`，网段仍是 `192.168.154.0/24`：

```bash
sudo nmcli connection modify "Wired connection 1" ipv4.method manual \
  ipv4.addresses 192.168.154.10/24 \
  ipv4.gateway 192.168.154.2 \
  ipv4.dns "223.5.5.5 8.8.8.8"
sudo nmcli connection up "Wired connection 1"
ip addr
ip route
```

如果配置错了，可以重新执行正确命令覆盖配置。

## 7. 检查虚拟机能访问互联网

输入命令 `Rocky Linux`：

```bash
ping -c 4 223.5.5.5
ping -c 4 mirrors.rockylinux.org
curl -I https://download.docker.com/linux/centos/docker-ce.repo
```

执行后的结果：

- 第一个 `ping` 应看到 `0% packet loss`。
- 第二个 `ping` 应能解析域名并收到响应。
- `curl -I` 应看到 `HTTP/2 200`、`HTTP/1.1 200` 或 `HTTP/1.1 302` 等 HTTP 响应。

需要修改的内容：

- 如果 IP 能 ping 通但域名不通，说明 DNS 配置有问题，回到第 6 步修改 `ipv4.dns`。
- 如果 IP 也 ping 不通，说明 NAT 网关或 VMware 网络配置有问题，回到第 2 步确认 VMnet8。

具体配置方法：

重新设置 DNS：

```bash
sudo nmcli connection modify ens160 ipv4.dns "223.5.5.5 8.8.8.8"
sudo nmcli connection up ens160
```

如果连接名不是 `ens160`，替换为实际连接名。

## 8. 启用 SSH 服务

输入命令 `Rocky Linux`：

```bash
sudo systemctl enable --now sshd
sudo systemctl status sshd --no-pager
```

执行后的结果：

应该看到：

```text
Active: active (running)
```

需要修改的内容：

- 无需修改。
- 如果 `sshd` 不存在，说明系统不是常规 Rocky Minimal 或安装不完整。

具体配置方法：

如果提示找不到 `sshd`，执行：

```bash
sudo dnf install -y openssh-server
sudo systemctl enable --now sshd
sudo systemctl status sshd --no-pager
```

## 9. 从 Windows 测试 SSH 登录

输入命令 `Windows PowerShell`：

```powershell
Test-NetConnection 192.168.154.10 -Port 22
ssh wang@192.168.154.10
```

执行后的结果：

`Test-NetConnection` 应看到：

```text
TcpTestSucceeded : True
```

第一次 SSH 会提示：

```text
Are you sure you want to continue connecting (yes/no/[fingerprint])?
```

输入：

```text
yes
```

然后输入用户 `wang` 的密码，成功后进入 Linux 命令行。

需要修改的内容：

- 如果虚拟机 IP 不是 `192.168.154.10`，替换成实际 IP。
- 如果用户名不是 `wang`，替换成实际用户名。

具体配置方法：

如果 `TcpTestSucceeded : False`：

1. 确认虚拟机已启动。
2. 在虚拟机执行 `ip addr`，确认 IP。
3. 在虚拟机执行 `sudo systemctl status sshd --no-pager`，确认 SSH 正在运行。
4. 检查 VMware 网络是否是 NAT。

## 10. 配置 SSH 免密登录

输入命令 `Windows PowerShell`：

```powershell
if (-not (Test-Path "$HOME\.ssh\id_ed25519")) { ssh-keygen -t ed25519 }
Get-Content "$HOME\.ssh\id_ed25519.pub" | ssh wang@192.168.154.10 `
  'umask 077; mkdir -p ~/.ssh; cat >> ~/.ssh/authorized_keys; chmod 600 ~/.ssh/authorized_keys'
ssh -o BatchMode=yes wang@192.168.154.10 'echo SSH_OK'
```

执行后的结果：

- 如果本机没有 SSH key，`ssh-keygen` 会询问保存路径，直接按回车即可。
- 最后一条命令应输出：

```text
SSH_OK
```

需要修改的内容：

- 如果虚拟机 IP 不是 `192.168.154.10`，替换成实际 IP。
- 如果用户名不是 `wang`，替换成实际用户名。

具体配置方法：

如果最后不是 `SSH_OK`，仍要求输入密码，说明免密没有生效。登录虚拟机后执行：

```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
restorecon -RFv ~/.ssh
sudo systemctl restart sshd
```

然后回到 Windows 再执行：

```powershell
ssh -o BatchMode=yes wang@192.168.154.10 'echo SSH_OK'
```

## 11. 在 Windows 生成项目 .env

虚拟机中间件需要 `.env` 中的随机密码。该文件必须在 Windows 项目目录生成，再复制到虚拟机。

输入命令 `Windows PowerShell`：

```powershell
Set-Location 'F:\跨境智汇AI知识库系统\ygh-deploy\constrained-dev'
.\generate-env.ps1
Test-Path .env
git status --short --ignored .env
```

执行后的结果：

首次执行应输出：

```text
ENV_CREATED_VALUES_HIDDEN
```

重复执行应输出：

```text
ENV_EXISTS_NO_CHANGE
```

`Test-Path .env` 应输出：

```text
True
```

`git status --short --ignored .env` 应显示 `.env` 被忽略，通常以 `!!` 开头。

需要修改的内容：

- 如果项目不在 `F:\跨境智汇AI知识库系统`，把路径替换成客户实际解压路径。
- 不要打开 `.env` 截图，不要把 `.env` 复制到文档或聊天中。

具体配置方法：

如果 PowerShell 禁止执行脚本，先执行：

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

然后重新执行：

```powershell
Set-Location 'F:\跨境智汇AI知识库系统\ygh-deploy\constrained-dev'
.\generate-env.ps1
```

## 12. 如果客户虚拟机 IP 不是 192.168.154.10，修改 vm-compose.yml

如果客户沿用默认 `192.168.154.10`，跳过本步。

输入命令 `Windows PowerShell`：

```powershell
Set-Location 'F:\跨境智汇AI知识库系统\ygh-deploy\constrained-dev'
Select-String -Path .\vm-compose.yml -Pattern '192.168.154.10'
```

执行后的结果：

会看到 `vm-compose.yml` 中端口绑定使用了：

```text
192.168.154.10
```

需要修改的内容：

- 如果第 6 步配置的虚拟机 IP 是 `192.168.80.10`，则必须把 `vm-compose.yml` 里的 `192.168.154.10` 全部改成 `192.168.80.10`。
- 如果仍是 `192.168.154.10`，不要改。

具体配置方法：

用 IDEA、VS Code 或记事本打开：

```text
F:\跨境智汇AI知识库系统\ygh-deploy\constrained-dev\vm-compose.yml
```

将所有：

```text
192.168.154.10
```

替换为客户实际虚拟机 IP，例如：

```text
192.168.80.10
```

保存后执行：

```powershell
Select-String -Path .\vm-compose.yml -Pattern '192.168.80.10'
```

确认已经替换成功。

## 13. 复制虚拟机部署目录到 Rocky Linux

输入命令 `Windows PowerShell`：

```powershell
Set-Location 'F:\跨境智汇AI知识库系统\ygh-deploy\constrained-dev'
ssh wang@192.168.154.10 'sudo mkdir -p /opt/ygh; sudo chown -R wang:wang /opt/ygh'
ssh wang@192.168.154.10 'if [ -d /opt/ygh/constrained-dev ]; then mv /opt/ygh/constrained-dev /opt/ygh/constrained-dev.bak-$(date +%Y%m%d-%H%M%S); fi; mkdir -p /opt/ygh/constrained-dev'
scp -r .\* wang@192.168.154.10:/opt/ygh/constrained-dev/
scp .\.env wang@192.168.154.10:/opt/ygh/constrained-dev/.env
ssh wang@192.168.154.10 'ls -la /opt/ygh/constrained-dev | head'
```

执行后的结果：

最后一条命令应看到：

```text
.env
vm-compose.yml
local-compose.yml
scripts
mysql
postgres
```

需要修改的内容：

- 如果项目路径不是 `F:\跨境智汇AI知识库系统`，替换 `Set-Location` 路径。
- 如果虚拟机 IP 或用户名不同，替换所有 `wang@192.168.154.10`。
- 第二条 SSH 命令不会删除旧目录，而是把旧目录改名为 `constrained-dev.bak-时间戳`。确认新环境正常后，实施人员再手工清理旧备份目录。

具体配置方法：

如果 `scp` 提示 `Permission denied`：

1. 先确认 SSH 能登录：

```powershell
ssh wang@192.168.154.10
```

2. 再确认 `/opt/ygh` 归属：

```powershell
ssh wang@192.168.154.10 'ls -ld /opt/ygh'
```

3. 如果不是 `wang wang`，执行：

```powershell
ssh wang@192.168.154.10 'sudo chown -R wang:wang /opt/ygh'
```

## 14. 在虚拟机安装 Docker Engine 和 Compose 插件

输入命令 `Rocky Linux`：

```bash
cd /opt/ygh/constrained-dev
chmod +x scripts/*.sh rocketmq/*.sh mysql/init/*.sh
sudo ./scripts/install-docker-rocky.sh
```

执行后的结果：

脚本最后应输出 Docker 版本信息，类似：

```text
Docker=28.x.x Cgroup=2 Driver=overlay2
Docker Compose version v2.x.x
```

需要修改的内容：

- 安装脚本默认执行 `usermod -aG docker wang`。
- 如果客户用户名不是 `wang`，安装后还要执行 `sudo usermod -aG docker 实际用户名`。

具体配置方法：

如果用户名不是 `wang`，例如是 `admin`，执行：

```bash
sudo usermod -aG docker admin
```

然后退出 SSH 或虚拟机终端，重新登录，让用户组生效：

```bash
exit
```

回到 Windows 后重新登录：

```powershell
ssh wang@192.168.154.10
```

如果客户用户名不是 `wang`，替换为实际用户名。

## 15. 验证 Docker 权限

输入命令 `Rocky Linux`：

```bash
groups
docker version
docker compose version
docker info --format 'Docker={{.ServerVersion}} Cgroup={{.CgroupVersion}} Driver={{.Driver}}'
```

执行后的结果：

- `groups` 应包含 `docker`。
- `docker version` 不应出现 `permission denied`。
- `docker compose version` 应显示版本号。
- `docker info` 应显示 `Cgroup=2` 和 `Driver=overlay2`。

需要修改的内容：

- 如果 `groups` 不包含 `docker`，说明第 14 步后没有重新登录。

具体配置方法：

重新添加并重新登录：

```bash
sudo usermod -aG docker wang
exit
```

然后从 Windows 重新 SSH：

```powershell
ssh wang@192.168.154.10
```

## 16. 检查 Docker daemon 配置

输入命令 `Rocky Linux`：

```bash
sudo cat /etc/docker/daemon.json
sudo systemctl status docker --no-pager
```

执行后的结果：

`daemon.json` 应包含：

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
    "https://docker.m.daocloud.io",
    "https://docker.1ms.run"
  ],
  "default-address-pools": [
    { "base": "172.30.0.0/16", "size": 24 }
  ]
}
```

`systemctl status docker` 应看到：

```text
Active: active (running)
```

需要修改的内容：

- 一般无需修改。
- 如果客户公司网络禁止镜像站，可以删除 `registry-mirrors` 或换成公司允许的 Docker 镜像代理。

具体配置方法：

修改后重启 Docker：

```bash
sudo systemctl daemon-reload
sudo systemctl restart docker
docker info
```

## 17. 配置虚拟机防火墙

默认脚本只允许 Windows VMware NAT 主机 `192.168.154.1` 访问虚拟机中间件端口。

输入命令 `Rocky Linux`：

```bash
cd /opt/ygh/constrained-dev
sudo ./scripts/configure-vm-firewall.sh
sudo firewall-cmd --list-rich-rules
sudo firewall-cmd --list-ports
```

执行后的结果：

应看到脚本输出：

```text
VM_FIREWALL_OK
```

`--list-rich-rules` 应包含类似：

```text
rule family="ipv4" source address="192.168.154.1/32" port port="3306" protocol="tcp" accept
rule family="ipv4" source address="192.168.154.1/32" port port="5432" protocol="tcp" accept
rule family="ipv4" source address="192.168.154.1/32" port port="6379" protocol="tcp" accept
rule family="ipv4" source address="192.168.154.1/32" port port="8080" protocol="tcp" accept
rule family="ipv4" source address="192.168.154.1/32" port port="8848" protocol="tcp" accept
rule family="ipv4" source address="192.168.154.1/32" port port="9848" protocol="tcp" accept
```

需要修改的内容：

- 如果第 2 步看到 Windows VMware NAT 主机不是 `192.168.154.1`，必须修改脚本里的源地址。
- 例如 Windows NAT 主机是 `192.168.80.1`，防火墙规则必须允许 `192.168.80.1/32`。

具体配置方法：

在 Windows 或 Linux 中打开：

```text
ygh-deploy/constrained-dev/scripts/configure-vm-firewall.sh
```

将脚本中的：

```text
source address=192.168.154.1/32
```

替换为客户实际 Windows NAT 主机地址，例如：

```text
source address=192.168.80.1/32
```

重新复制脚本到虚拟机，或直接在虚拟机内编辑后执行：

```bash
cd /opt/ygh/constrained-dev
sudo ./scripts/configure-vm-firewall.sh
sudo firewall-cmd --list-rich-rules
```

如果需要手工添加规则，示例命令如下。把 `192.168.80.1` 替换成客户实际 Windows NAT 主机地址：

```bash
for port in 3306 5432 6379 8080 8848 9848; do
  sudo firewall-cmd --permanent --add-rich-rule="rule family=ipv4 source address=192.168.80.1/32 port port=${port} protocol=tcp accept"
done
sudo firewall-cmd --reload
sudo firewall-cmd --list-rich-rules
```

## 18. 校验 vm-compose.yml 和 .env

输入命令 `Rocky Linux`：

```bash
cd /opt/ygh/constrained-dev
test -f .env && echo ENV_OK
test -f vm-compose.yml && echo COMPOSE_OK
docker compose --env-file .env -f vm-compose.yml --profile core config >/dev/null
echo $?
```

执行后的结果：

应该看到：

```text
ENV_OK
COMPOSE_OK
0
```

需要修改的内容：

- 如果没有 `ENV_OK`，说明 `.env` 没复制到虚拟机。
- 如果 `docker compose ... config` 报 `required variable ... is missing`，说明 `.env` 缺变量，需要回 Windows 重新运行 `generate-env.ps1` 并复制。
- 如果报端口绑定 IP 不存在，说明 `vm-compose.yml` 里的 IP 与虚拟机实际 IP 不一致，回第 12 步修改。

具体配置方法：

重新复制 `.env`：

```powershell
Set-Location 'F:\跨境智汇AI知识库系统\ygh-deploy\constrained-dev'
scp .\.env wang@192.168.154.10:/opt/ygh/constrained-dev/.env
```

重新复制整个目录：

```powershell
Set-Location 'F:\跨境智汇AI知识库系统\ygh-deploy\constrained-dev'
scp -r .\* wang@192.168.154.10:/opt/ygh/constrained-dev/
scp .\.env wang@192.168.154.10:/opt/ygh/constrained-dev/.env
```

## 19. 拉取虚拟机核心组件镜像

输入命令 `Rocky Linux`：

```bash
cd /opt/ygh/constrained-dev
docker compose --env-file .env -f vm-compose.yml --profile core pull
```

执行后的结果：

应拉取这些镜像：

```text
mysql:8.4.10
redis:8.4.4
nacos/nacos-server:v3.1.1
```

最终应看到每个服务 `Pulled` 或 `Downloaded newer image`。

需要修改的内容：

- 一般无需修改。
- 如果客户网络无法访问 Docker Hub，需要配置公司镜像代理或允许访问 Docker 镜像仓库。

具体配置方法：

如果下载失败，先检查网络：

```bash
curl -I https://registry-1.docker.io/v2/
docker pull redis:8.4.4
```

如果公司要求使用代理，在 `/etc/docker/daemon.json` 配置允许的 `registry-mirrors`，然后执行：

```bash
sudo systemctl restart docker
docker compose --env-file .env -f vm-compose.yml --profile core pull
```

## 20. 启动 MySQL、Redis、Nacos

输入命令 `Rocky Linux`：

```bash
cd /opt/ygh/constrained-dev
./scripts/deploy-core.sh
```

执行后的结果：

脚本会依次：

1. 校验 `.env` 是否存在。
2. 校验 `vm-compose.yml`。
3. 拉取核心镜像。
4. 启动 MySQL、Redis、Nacos。
5. 执行健康检查。
6. 初始化 Auth 数据库。
7. 验证 Auth 数据库。
8. 初始化 Nacos 管理密码。

成功时最后应看到类似：

```text
CORE_HEALTH_OK
```

以及数据库验证和 Nacos 初始化成功信息。

需要修改的内容：

- 首次启动 MySQL 会创建 Nacos 库和业务库，可能需要几分钟。
- Nacos 依赖 MySQL，首次启动慢是正常现象。
- 不要中途执行 `docker compose down -v`。

具体配置方法：

如果脚本失败，先查看状态：

```bash
cd /opt/ygh/constrained-dev
./scripts/status.sh
docker compose --env-file .env -f vm-compose.yml --profile core logs --tail 120 mysql
docker compose --env-file .env -f vm-compose.yml --profile core logs --tail 120 nacos
docker compose --env-file .env -f vm-compose.yml --profile core logs --tail 120 redis
```

常见处理：

- `.env missing`：回第 11、13 步生成并复制 `.env`。
- `port is already allocated`：说明虚拟机已有进程占用端口，执行 `sudo ss -lntp` 查看。
- `Cannot assign requested address`：说明 `vm-compose.yml` 绑定的 IP 不是虚拟机当前 IP，回第 12 步修改。
- `NACOS_READINESS_TIMEOUT`：Nacos 启动超时，先看 `nacos` 日志；低配机器可再执行一次 `./scripts/health-check.sh`。

## 21. 查看核心组件状态

输入命令 `Rocky Linux`：

```bash
cd /opt/ygh/constrained-dev
./scripts/status.sh
./scripts/health-check.sh
```

执行后的结果：

`status.sh` 应显示 `mysql`、`redis`、`nacos` 容器运行中，状态为 `healthy` 或正在变为 `healthy`。

`health-check.sh` 成功时应输出：

```text
CORE_HEALTH_OK
```

需要修改的内容：

- 无需修改。
- 如果内存不足，`docker stats` 会显示容器占用过高，需要先停止不需要的容器。

具体配置方法：

查看容器名称：

```bash
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
```

查看资源占用：

```bash
free -h
df -h
docker stats --no-stream
```

## 22. 从 Windows 验证虚拟机端口

输入命令 `Windows PowerShell`：

```powershell
Test-NetConnection 192.168.154.10 -Port 3306
Test-NetConnection 192.168.154.10 -Port 6379
Test-NetConnection 192.168.154.10 -Port 8848
Test-NetConnection 192.168.154.10 -Port 9848
```

执行后的结果：

每条命令都应看到：

```text
TcpTestSucceeded : True
```

需要修改的内容：

- 如果虚拟机 IP 不是 `192.168.154.10`，替换为实际 IP。

具体配置方法：

如果 SSH 能连，但这些端口不通：

1. 在虚拟机确认容器已启动：

```bash
cd /opt/ygh/constrained-dev
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
```

2. 确认防火墙源地址允许的是 Windows NAT 主机 IP：

```bash
sudo firewall-cmd --list-rich-rules
```

3. 回第 17 步修正防火墙。

## 23. 打开 Nacos 控制台验证

输入内容，在 Windows 浏览器打开：

```text
http://192.168.154.10:8080
```

或者：

```text
http://192.168.154.10:8848/nacos
```

执行后的结果：

应能看到 Nacos 控制台页面。

需要修改的内容：

- 如果虚拟机 IP 不是 `192.168.154.10`，替换为实际 IP。
- Nacos 用户名通常为 `nacos`。
- 密码来自 Windows 项目目录的 `.env` 中 `NACOS_ADMIN_PASSWORD`，不要把密码写入文档。

具体配置方法：

在 Windows PowerShell 中只查看变量名是否存在，不打印密码：

```powershell
Set-Location 'F:\跨境智汇AI知识库系统\ygh-deploy\constrained-dev'
Select-String -Path .\.env -Pattern '^NACOS_ADMIN_PASSWORD='
```

如果需要登录，实施人员从 `.env` 复制 `NACOS_ADMIN_PASSWORD` 的值到浏览器登录框。不要截图传播。

## 24. 按需启动 PGVector

只有知识检索、向量索引、AI 问答场景需要 PGVector。

输入命令 `Rocky Linux`：

```bash
cd /opt/ygh/constrained-dev
./scripts/deploy-ai-data.sh
docker compose --env-file .env -f vm-compose.yml --profile ai-data ps
```

执行后的结果：

成功时应看到：

```text
AI_DATA_HEALTH_OK
```

并且 `pgvector` 容器状态为 `healthy`。

需要修改的内容：

- 启动脚本要求虚拟机可用内存至少约 700MB。
- 如果低内存机器已经运行太多服务，PGVector 会拒绝启动。

具体配置方法：

内存不足时先查看：

```bash
free -h
docker stats --no-stream
```

如果确认暂时不需要 PGVector，保持停止即可。需要停止 PGVector：

```bash
cd /opt/ygh/constrained-dev
./scripts/stop-ai-data.sh
```

预期输出：

```text
AI_DATA_STOPPED_VOLUME_PRESERVED
```

## 25. 从 Windows 验证 PGVector 端口

输入命令 `Windows PowerShell`：

```powershell
Test-NetConnection 192.168.154.10 -Port 5432
```

执行后的结果：

如果 PGVector 已启动，应看到：

```text
TcpTestSucceeded : True
```

如果 PGVector 已停止，看到 `False` 是正常的。

需要修改的内容：

- 如果虚拟机 IP 不是 `192.168.154.10`，替换为实际 IP。

具体配置方法：

如果 PGVector 已启动但端口不通，回第 17 步确认防火墙是否允许 `5432/tcp`。

## 26. 备份虚拟机数据

输入命令 `Rocky Linux`：

```bash
cd /opt/ygh/constrained-dev
./scripts/backup-data.sh
```

执行后的结果：

成功时应看到：

```text
BACKUP_OK path=/opt/ygh/backups/20260713-153000
```

实际时间目录会不同。

需要修改的内容：

- 默认备份目录为 `/opt/ygh/backups`。
- 如需改目录，可设置环境变量 `YGH_BACKUP_ROOT`。

具体配置方法：

示例：备份到 `/data/ygh-backups`：

```bash
export YGH_BACKUP_ROOT=/data/ygh-backups
cd /opt/ygh/constrained-dev
./scripts/backup-data.sh
```

查看备份文件：

```bash
ls -lah /opt/ygh/backups
find /opt/ygh/backups -maxdepth 2 -type f -name 'SHA256SUMS' -print
```

## 27. 虚拟机重启后的启动检查

输入命令 `Rocky Linux`：

```bash
sudo reboot
```

虚拟机重启后，从 Windows 登录：

```powershell
ssh wang@192.168.154.10
```

再执行 `Rocky Linux`：

```bash
cd /opt/ygh/constrained-dev
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
./scripts/health-check.sh
```

执行后的结果：

- MySQL、Redis、Nacos 配置了 `restart: unless-stopped`，重启后应自动恢复。
- 健康检查应输出 `CORE_HEALTH_OK`。

需要修改的内容：

- 如果虚拟机 IP 变化，说明固定 IP 没配置成功，回第 6 步。
- 如果 Docker 未启动，回第 14、15 步检查 Docker 服务。

具体配置方法：

手工启动 Docker：

```bash
sudo systemctl enable --now docker
sudo systemctl status docker --no-pager
```

手工启动核心组件：

```bash
cd /opt/ygh/constrained-dev
docker compose --env-file .env -f vm-compose.yml --profile core up -d
./scripts/health-check.sh
```

## 28. 交付给后端 IDEA 使用的虚拟机连接信息

虚拟机配置完成后，把以下信息交给后端启动配置人员：

```text
YGH_MYSQL_HOST=192.168.154.10
YGH_MYSQL_PORT=3306
YGH_REDIS_HOST=192.168.154.10
YGH_REDIS_PORT=6379
YGH_NACOS_SERVER_ADDR=192.168.154.10:8848
YGH_VECTOR_DB_URL=jdbc:postgresql://192.168.154.10:5432/ygh_vector
```

执行后的结果：

- IDEA 中 Java 服务能连接 MySQL、Redis、Nacos。
- 启动 AI/Search 时能连接 PGVector。

需要修改的内容：

- 如果虚拟机 IP 不是 `192.168.154.10`，全部替换为实际虚拟机 IP。
- 密码仍来自 `.env`，不要写进这份连接信息。

具体配置方法：

Windows PowerShell 验证连接前置条件：

```powershell
Test-NetConnection 192.168.154.10 -Port 3306
Test-NetConnection 192.168.154.10 -Port 6379
Test-NetConnection 192.168.154.10 -Port 8848
```

AI 场景再验证：

```powershell
Test-NetConnection 192.168.154.10 -Port 5432
```

## 29. 常见问题

### 29.1 Windows 能 SSH，但连不上 MySQL/Redis/Nacos

输入命令 `Rocky Linux`：

```bash
sudo firewall-cmd --list-rich-rules
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
```

结果判断：

- 容器没启动：回第 20 步启动。
- rich rule 源地址不是 Windows VMnet8 IP：回第 17 步修改防火墙。
- `vm-compose.yml` 端口绑定 IP 不等于虚拟机 IP：回第 12 步修改。

### 29.2 Docker pull 很慢或失败

输入命令 `Rocky Linux`：

```bash
curl -I https://registry-1.docker.io/v2/
docker pull redis:8.4.4
```

结果判断：

- 如果网络完全不通，先解决虚拟机 DNS 或公司网络代理。
- 如果只有 Docker Hub 慢，配置公司允许的 registry mirror。

### 29.3 `Cannot assign requested address`

原因：

`vm-compose.yml` 中绑定了不存在的 IP，例如文件写 `192.168.154.10`，但虚拟机实际 IP 是 `192.168.80.10`。

修复命令 `Rocky Linux`：

```bash
ip addr
cd /opt/ygh/constrained-dev
grep -n '192.168' vm-compose.yml
```

具体修复：

回第 12 步，把 `vm-compose.yml` 中的 IP 改成虚拟机实际 IP，再重新复制或保存到虚拟机。

### 29.4 Nacos 长时间不健康

输入命令 `Rocky Linux`：

```bash
cd /opt/ygh/constrained-dev
docker compose --env-file .env -f vm-compose.yml --profile core ps
docker compose --env-file .env -f vm-compose.yml --profile core logs --tail 200 nacos
docker compose --env-file .env -f vm-compose.yml --profile core logs --tail 200 mysql
```

结果判断：

- MySQL 不健康：先修 MySQL。
- Nacos 报数据库连接失败：检查 `.env` 是否完整，检查 MySQL 是否初始化成功。
- 低配机器首次启动慢：等待 2 到 5 分钟后再执行 `./scripts/health-check.sh`。

### 29.5 忘记虚拟机 IP 或网卡名

输入命令 `Rocky Linux`：

```bash
ip addr
nmcli connection show
ip route
```

结果判断：

- `ip addr` 查看当前 IP。
- `nmcli connection show` 查看连接名。
- `ip route` 查看默认网关。

## 30. 最终验收清单

全部通过后，虚拟机才算配置完成：

- [ ] VMware NAT 主机 IP 已确认。
- [ ] Rocky Linux 9 Minimal 已安装。
- [ ] 用户 `wang` 或客户实际用户可登录。
- [ ] 虚拟机固定 IP 已设置，Windows 能 SSH。
- [ ] SSH 免密登录输出 `SSH_OK`。
- [ ] `.env` 已在 Windows 生成并复制到 `/opt/ygh/constrained-dev/.env`。
- [ ] 如虚拟机 IP 不是 `192.168.154.10`，已修改 `vm-compose.yml`。
- [ ] Docker Engine 和 Docker Compose 插件安装成功。
- [ ] 当前 Linux 用户属于 `docker` 组。
- [ ] 防火墙只允许 Windows NAT 主机访问 `3306`、`5432`、`6379`、`8080`、`8848`、`9848`。
- [ ] `docker compose --env-file .env -f vm-compose.yml --profile core config >/dev/null` 返回 `0`。
- [ ] `./scripts/deploy-core.sh` 成功。
- [ ] `./scripts/health-check.sh` 输出 `CORE_HEALTH_OK`。
- [ ] Windows 对 `3306`、`6379`、`8848`、`9848` 的 `Test-NetConnection` 全部成功。
- [ ] 需要 AI 场景时，`./scripts/deploy-ai-data.sh` 输出 `AI_DATA_HEALTH_OK`。
- [ ] 已执行一次 `./scripts/backup-data.sh` 并看到 `BACKUP_OK`。
