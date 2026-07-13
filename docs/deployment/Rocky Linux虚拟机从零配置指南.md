# Rocky Linux 虚拟机从零配置指南

## 第一部分：配置 VMware NAT 网络

### 第一步：打开 VMware 虚拟网络编辑器

在 Windows 上打开：

```text
VMware Workstation Pro → Edit → Virtual Network Editor
```

执行后的结果：

能看到 `VMnet8`。

需要修改的内容：

`VMnet8` 必须是 NAT 模式。

具体配置方法：

1. 点击 `Change Settings`，允许管理员权限。
2. 选择 `VMnet8`。
3. 勾选：

```text
NAT: Used to share the host's IP address
Connect a host virtual adapter to this network
Use local DHCP service to distribute IP address to VMs
```

### 第二步：设置 VMnet8 网段

在 VMware 图形界面中设置：

```text
Subnet IP:   192.168.154.0
Subnet mask: 255.255.255.0
```

点击 `NAT Settings`，设置：

```text
Gateway IP: 192.168.154.2
```

执行后的结果：

VMware NAT 网关固定为 `192.168.154.2`。

需要修改的内容：

如果客户公司电脑已有别的软件占用 `192.168.154.0/24`，可以换成其他网段，例如：

```text
Subnet IP:   192.168.80.0
Gateway IP: 192.168.80.2
虚拟机 IP:   192.168.80.10
Windows IP:  192.168.80.1
```

### 第三步：设置 DHCP 地址池避开虚拟机固定 IP

点击 `DHCP Settings`，建议设置：

```text
Start IP address: 192.168.154.128
End IP address:   192.168.154.254
```

执行后的结果：

DHCP 不会把 `192.168.154.10` 分给其他虚拟机。

需要修改的内容：

如果客户使用 `192.168.80.0/24`，则改成：

```text
Start IP address: 192.168.80.128
End IP address:   192.168.80.254
```

### 第四步：在 Windows 确认 VMnet8 IP

输入命令 `Windows PowerShell`：

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

如果这里不是 `192.168.154.1`，后面所有 `192.168.154.10`、`192.168.154.2`、`192.168.154.1` 都要按实际网段替换。

---

## 第二部分：创建 Rocky Linux 虚拟机

### 第一步：下载软件和系统镜像

浏览器打开：

```text
https://www.vmware.com/products/desktop-hypervisor/workstation-and-fusion
https://support.broadcom.com/
https://rockylinux.org/download
```

执行后的结果：

1. Windows 已安装 VMware Workstation Pro。
2. 已下载 Rocky Linux 9 Minimal ISO，例如：

```text
D:\ISO\Rocky-9.6-x86_64-minimal.iso
```

需要修改的内容：

ISO 文件名以实际下载文件为准。

### 第二步：创建虚拟机

在 VMware 中选择：

```text
Create a New Virtual Machine
```

配置如下：

```text
Type: Typical
ISO: 选择 Rocky Linux 9 Minimal ISO
Guest OS: Linux
Version: Rocky Linux 64-bit；没有就选 Other Linux 5.x kernel 64-bit
Virtual machine name: ygh-rocky-dev
Location: D:\VMs\ygh-rocky-dev
Disk: 40 GB
Network Adapter: NAT
Memory: 3584 MB
Processors: 2
```

执行后的结果：

VMware 中出现名为 `ygh-rocky-dev` 的虚拟机。

需要修改的内容：

如果客户电脑内存大于 32GB，可以把 Memory 改成 `4096 MB`。

### 第三步：安装 Rocky Linux

启动虚拟机，选择：

```text
Install Rocky Linux 9
```

安装界面配置：

```text
Installation Destination: 默认自动分区
Root Password: 设置强密码
User Creation:
  Full name: wang
  User name: wang
  勾选 Make this user administrator
```

执行后的结果：

Rocky Linux 安装完成，重启后可以登录 `wang`。

需要修改的内容：

如果客户不用 `wang`，后面所有命令里的 `wang` 都要替换成客户实际用户名。

---

## 第三部分：配置 Rocky Linux 网络

### 第一步：查看网卡名称

输入命令 `Rocky Linux`：

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

例如看到：

```text
Wired connection 1
```

则命令里要写：

```bash
"Wired connection 1"
```

### 第二步：设置固定 IP

默认输入命令 `Rocky Linux`：

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

应该看到：

```text
inet 192.168.154.10/24
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
ip addr show ens160
ip route
```

如果连接名不是 `ens160`，也要同步替换。

### 第三步：测试虚拟机联网

输入命令 `Rocky Linux`：

```bash
ping -c 4 223.5.5.5
ping -c 4 mirrors.rockylinux.org
curl -I https://download.docker.com/linux/centos/docker-ce.repo
```

执行后的结果：

1. `ping 223.5.5.5` 应该是 `0% packet loss`。
2. `ping mirrors.rockylinux.org` 应该能解析域名。
3. `curl` 应该返回 HTTP 响应。

需要修改的内容：

如果 IP 能通但域名不通，重新配置 DNS：

```bash
sudo nmcli connection modify ens160 ipv4.dns "223.5.5.5 8.8.8.8"
sudo nmcli connection up ens160
```

---

## 第四部分：配置 SSH

### 第一步：启动 SSH 服务

输入命令 `Rocky Linux`：

```bash
sudo systemctl enable --now sshd
sudo systemctl status sshd --no-pager
```

执行后的结果：

看到：

```text
Active: active (running)
```

如果提示没有 `sshd`，执行：

```bash
sudo dnf install -y openssh-server
sudo systemctl enable --now sshd
```

### 第二步：Windows 测试 SSH

输入命令 `Windows PowerShell`：

```powershell
Test-NetConnection 192.168.154.10 -Port 22
ssh wang@192.168.154.10
```

执行后的结果：

`Test-NetConnection` 应显示：

```text
TcpTestSucceeded : True
```

第一次 SSH 输入：

```text
yes
```

然后输入 `wang` 的密码。

需要修改的内容：

如果虚拟机 IP 或用户名不同，替换命令里的 `wang@192.168.154.10`。

### 第三步：配置 SSH 免密

输入命令 `Windows PowerShell`：

```powershell
if (-not (Test-Path "$HOME\.ssh\id_ed25519")) { ssh-keygen -t ed25519 }
Get-Content "$HOME\.ssh\id_ed25519.pub" | ssh wang@192.168.154.10 `
  'umask 077; mkdir -p ~/.ssh; cat >> ~/.ssh/authorized_keys; chmod 600 ~/.ssh/authorized_keys'
ssh -o BatchMode=yes wang@192.168.154.10 'echo SSH_OK'
```

执行后的结果：

最后输出：

```text
SSH_OK
```

如果没有输出 `SSH_OK`，登录虚拟机执行：

```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
restorecon -RFv ~/.ssh
sudo systemctl restart sshd
```

---

## 第五部分：生成并复制项目配置

### 第一步：在 Windows 生成 .env

输入命令 `Windows PowerShell`：

```powershell
Set-Location 'F:\跨境智汇AI知识库系统\ygh-deploy\constrained-dev'
.\generate-env.ps1
Test-Path .env
git status --short --ignored .env
```

执行后的结果：

第一次执行看到：

```text
ENV_CREATED_VALUES_HIDDEN
```

重复执行看到：

```text
ENV_EXISTS_NO_CHANGE
```

`Test-Path .env` 输出：

```text
True
```

需要修改的内容：

如果项目解压路径不是 `F:\跨境智汇AI知识库系统`，把 `Set-Location` 换成客户实际路径。

### 第二步：如果虚拟机 IP 不是默认值，修改 vm-compose.yml

默认虚拟机 IP 是 `192.168.154.10`。如果客户实际 IP 不是这个，必须修改：

```text
F:\跨境智汇AI知识库系统\ygh-deploy\constrained-dev\vm-compose.yml
```

把所有：

```text
192.168.154.10
```

替换成客户实际虚拟机 IP，例如：

```text
192.168.80.10
```

验证命令 `Windows PowerShell`：

```powershell
Set-Location 'F:\跨境智汇AI知识库系统\ygh-deploy\constrained-dev'
Select-String -Path .\vm-compose.yml -Pattern '192.168'
```

执行后的结果：

输出中的 IP 必须是客户实际虚拟机 IP。

### 第三步：复制部署目录到虚拟机

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

能看到：

```text
.env
vm-compose.yml
scripts
mysql
postgres
```

需要修改的内容：

如果用户名或 IP 不同，替换所有 `wang@192.168.154.10`。

---

## 第六部分：安装 Docker

### 第一步：清理旧版本

如果系统里有旧的 Docker 或 Podman 冲突包，先执行卸载。

输入命令 `Rocky Linux`：

```bash
sudo dnf remove -y docker \
                    docker-client \
                    docker-client-latest \
                    docker-common \
                    docker-latest \
                    docker-latest-logrotate \
                    docker-logrotate \
                    docker-engine \
                    podman \
                    buildah
```

执行后的结果：

旧版本 Docker、Podman、Buildah 被卸载。没有安装过也没关系。

### 第二步：安装基础依赖并配置 Docker 软件源

输入命令 `Rocky Linux`：

```bash
sudo dnf install -y dnf-plugins-core yum-utils curl ca-certificates
sudo yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
```

执行后的结果：

系统添加 Docker CE 软件源。

需要修改的内容：

如果阿里源不可用，换成 Docker 官方源：

```bash
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
```

### 第三步：安装 Docker 引擎和 Compose 插件

输入命令 `Rocky Linux`：

```bash
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

执行后的结果：

Docker Engine 和 Docker Compose Plugin 安装完成。

### 第四步：配置 Docker 镜像加速器和日志参数

输入命令 `Rocky Linux`：

```bash
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json <<'EOF'
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

执行后的结果：

生成 Docker 配置文件：

```text
/etc/docker/daemon.json
```

需要修改的内容：

镜像站状态变化很快。如果拉取镜像失败，搜索最新可用的 Docker 镜像站，替换 `registry-mirrors`。

### 第五步：启动 Docker 并设置开机自启

输入命令 `Rocky Linux`：

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now docker
sudo systemctl status docker --no-pager
```

执行后的结果：

看到：

```text
Active: active (running)
```

### 第六步：验证 Docker 安装

输入命令 `Rocky Linux`：

```bash
sudo docker version
sudo docker compose version
sudo docker pull alpine
```

执行后的结果：

如果看到：

```text
Status: Downloaded newer image for alpine:latest
```

说明 Docker 和镜像网络正常。

### 第七步：把当前用户加入 docker 组

输入命令 `Rocky Linux`：

```bash
sudo usermod -aG docker $USER
exit
```

重新从 Windows 登录：

```powershell
ssh wang@192.168.154.10
```

验证命令 `Rocky Linux`：

```bash
groups
docker version
docker compose version
```

执行后的结果：

`groups` 里包含 `docker`，并且执行 `docker version` 不再需要 `sudo`。

---

## 第七部分：配置虚拟机防火墙

### 第一步：查看 Windows NAT 主机 IP

输入命令 `Windows PowerShell`：

```powershell
ipconfig
```

执行后的结果：

确认 `VMware Network Adapter VMnet8` 的 IPv4，例如：

```text
192.168.154.1
```

### 第二步：修改防火墙脚本里的源地址

如果 Windows NAT 主机 IP 是 `192.168.154.1`，不用修改。

如果不是，打开：

```text
F:\跨境智汇AI知识库系统\ygh-deploy\constrained-dev\scripts\configure-vm-firewall.sh
```

把：

```text
source address=192.168.154.1/32
```

替换为客户真实 Windows NAT 主机 IP，例如：

```text
source address=192.168.80.1/32
```

然后重新复制脚本到虚拟机：

```powershell
Set-Location 'F:\跨境智汇AI知识库系统\ygh-deploy\constrained-dev'
scp .\scripts\configure-vm-firewall.sh wang@192.168.154.10:/opt/ygh/constrained-dev/scripts/configure-vm-firewall.sh
```

### 第三步：执行防火墙配置

输入命令 `Rocky Linux`：

```bash
cd /opt/ygh/constrained-dev
chmod +x scripts/*.sh mysql/init/*.sh
sudo ./scripts/configure-vm-firewall.sh
sudo firewall-cmd --list-rich-rules
```

执行后的结果：

看到：

```text
VM_FIREWALL_OK
```

并且规则里包含：

```text
3306
5432
6379
8080
8848
9848
```

需要修改的内容：

不要把数据库端口开放给所有人。只能允许 Windows NAT 主机 IP。

---

## 第八部分：启动虚拟机组件

### 第一步：校验配置文件

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

如果报 `required variable ... is missing`，说明 `.env` 不完整，回 Windows 重新执行 `generate-env.ps1`。

### 第二步：拉取 MySQL、Redis、Nacos 镜像

输入命令 `Rocky Linux`：

```bash
cd /opt/ygh/constrained-dev
docker compose --env-file .env -f vm-compose.yml --profile core pull
```

执行后的结果：

会拉取：

```text
mysql:8.4.10
redis:8.4.4
nacos/nacos-server:v3.1.1
```

如果很慢，优先检查 Docker 镜像加速器。

### 第三步：启动 MySQL、Redis、Nacos

输入命令 `Rocky Linux`：

```bash
cd /opt/ygh/constrained-dev
./scripts/deploy-core.sh
```

执行后的结果：

成功时看到：

```text
CORE_HEALTH_OK
```

说明 MySQL、Redis、Nacos 已启动并通过健康检查。

### 第四步：查看容器状态

输入命令 `Rocky Linux`：

```bash
cd /opt/ygh/constrained-dev
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
./scripts/status.sh
```

执行后的结果：

应看到：

```text
ygh-vm-mysql-1   healthy
ygh-vm-redis-1   healthy
ygh-vm-nacos-1   healthy
```

### 第五步：Windows 验证端口

输入命令 `Windows PowerShell`：

```powershell
Test-NetConnection 192.168.154.10 -Port 3306
Test-NetConnection 192.168.154.10 -Port 6379
Test-NetConnection 192.168.154.10 -Port 8848
Test-NetConnection 192.168.154.10 -Port 9848
```

执行后的结果：

每一条都应该看到：

```text
TcpTestSucceeded : True
```

需要修改的内容：

如果虚拟机 IP 不是 `192.168.154.10`，替换成实际 IP。

---

## 第九部分：启动 PGVector

### 第一步：启动 PGVector

输入命令 `Rocky Linux`：

```bash
cd /opt/ygh/constrained-dev
./scripts/deploy-ai-data.sh
```

执行后的结果：

成功时看到：

```text
AI_DATA_HEALTH_OK
```

PGVector 使用：

```text
PostgreSQL 17
PGVector 0.8.5
数据库名 ygh_vector
用户名 ygh_vector
端口 5432
```

### 第二步：Windows 验证 PGVector 端口

输入命令 `Windows PowerShell`：

```powershell
Test-NetConnection 192.168.154.10 -Port 5432
```

执行后的结果：

看到：

```text
TcpTestSucceeded : True
```

### 第三步：不用时停止 PGVector

输入命令 `Rocky Linux`：

```bash
cd /opt/ygh/constrained-dev
./scripts/stop-ai-data.sh
```

执行后的结果：

看到：

```text
AI_DATA_STOPPED_VOLUME_PRESERVED
```

说明只停止容器，不删除数据。

---

## 第十部分：组件配置说明

### MySQL 配置

配置文件：

```text
ygh-deploy/constrained-dev/mysql/conf.d/ygh-low-memory.cnf
```

关键配置：

```text
character-set-server=utf8mb4
collation-server=utf8mb4_0900_ai_ci
default-time-zone=+08:00
innodb_buffer_pool_size=256M
max_connections=80
performance_schema=OFF
```

初始化脚本：

```text
mysql/init/01-nacos-schema.sql
mysql/init/02-auth-database.sh
mysql/init/03-user-database.sh
mysql/init/04-system-database.sh
mysql/init/05-business-databases.sh
```

这些脚本会创建 Nacos 库、Auth 库、User 库、System 库和业务库。

### Redis 配置

Redis 配置写在 `vm-compose.yml` 的 `redis` 服务里：

```text
--appendonly yes
--appendfsync everysec
--maxmemory 96mb
--maxmemory-policy noeviction
--requirepass "$${REDIS_PASSWORD}"
```

密码来自 `.env`：

```text
REDIS_PASSWORD
```

### Nacos 配置

Nacos 配置写在 `vm-compose.yml` 的 `nacos` 服务里：

```text
MODE: standalone
SPRING_DATASOURCE_PLATFORM: mysql
MYSQL_SERVICE_DB_NAME: nacos_config
NACOS_AUTH_ENABLE: "true"
NACOS_AUTH_ADMIN_ENABLE: "true"
JVM_XMS: 384m
JVM_XMX: 384m
```

Nacos 管理员密码来自 `.env`：

```text
NACOS_ADMIN_PASSWORD
```

### PGVector 配置

PGVector 配置写在 `vm-compose.yml` 的 `pgvector` 服务里：

```text
POSTGRES_DB: ygh_vector
POSTGRES_USER: ygh_vector
shared_buffers=64MB
max_connections=30
work_mem=2MB
```

扩展初始化文件：

```text
postgres/init/01-enable-vector.sql
```

内容是：

```sql
CREATE EXTENSION IF NOT EXISTS vector;
```

---

## 第十一部分：备份数据

### 第一步：执行备份

输入命令 `Rocky Linux`：

```bash
cd /opt/ygh/constrained-dev
./scripts/backup-data.sh
```

执行后的结果：

看到：

```text
BACKUP_OK path=/opt/ygh/backups/具体时间目录
```

### 第二步：查看备份文件

输入命令 `Rocky Linux`：

```bash
ls -lah /opt/ygh/backups
find /opt/ygh/backups -maxdepth 2 -type f -name 'SHA256SUMS' -print
```

执行后的结果：

能看到备份目录和校验文件。

---

## 第十二部分：常见问题处理

### 问题一：Docker 镜像拉不下来

先测试：

```bash
docker pull alpine
```

如果失败，修改：

```bash
sudo vi /etc/docker/daemon.json
```

替换最新可用的 `registry-mirrors`，然后执行：

```bash
sudo systemctl daemon-reload
sudo systemctl restart docker
docker pull alpine
```

### 问题二：容器启动时报 Cannot assign requested address

原因：

`vm-compose.yml` 绑定的 IP 不是虚拟机当前 IP。

检查：

```bash
ip addr
cd /opt/ygh/constrained-dev
grep -n '192.168' vm-compose.yml
```

解决：

把 `vm-compose.yml` 里的 IP 改成虚拟机实际 IP，然后重新复制到虚拟机。

### 问题三：Windows 能 SSH，但连不上 3306、6379、8848

检查虚拟机防火墙：

```bash
sudo firewall-cmd --list-rich-rules
```

检查容器端口：

```bash
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
```

解决：

1. 如果防火墙源地址不是 Windows VMnet8 IP，回到第八部分修改防火墙脚本。
2. 如果容器没有启动，回到第九部分启动组件。

### 问题四：Nacos 一直不健康

查看日志：

```bash
cd /opt/ygh/constrained-dev
docker compose --env-file .env -f vm-compose.yml --profile core logs --tail 200 nacos
docker compose --env-file .env -f vm-compose.yml --profile core logs --tail 200 mysql
```

处理：

1. MySQL 不健康，先修 MySQL。
2. Nacos 报数据库连接失败，检查 `.env` 是否完整。
3. 低配机器首次启动慢，等 2 到 5 分钟后再执行：

```bash
./scripts/health-check.sh
```

---

## 第十三部分：最终验收

全部通过才算虚拟机配置完成：

```bash
cd /opt/ygh/constrained-dev
docker version
docker compose version
docker compose --env-file .env -f vm-compose.yml --profile core config >/dev/null
./scripts/health-check.sh
```

Windows 验证：

```powershell
Test-NetConnection 192.168.154.10 -Port 22
Test-NetConnection 192.168.154.10 -Port 3306
Test-NetConnection 192.168.154.10 -Port 6379
Test-NetConnection 192.168.154.10 -Port 8848
Test-NetConnection 192.168.154.10 -Port 9848
```

预期结果：

```text
SSH_OK
CORE_HEALTH_OK
TcpTestSucceeded : True
```

如果需要 AI 场景，再执行：

```bash
cd /opt/ygh/constrained-dev
./scripts/deploy-ai-data.sh
```

Windows 验证：

```powershell
Test-NetConnection 192.168.154.10 -Port 5432
```

预期结果：

```text
AI_DATA_HEALTH_OK
TcpTestSucceeded : True
```
