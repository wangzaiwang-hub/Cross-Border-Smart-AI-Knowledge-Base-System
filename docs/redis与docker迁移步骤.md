# 跨境智汇 AI 知识库系统：Docker 安装、Redis 配置与数据迁移步骤

> 本文适用于当前项目的资源受限开发环境：Windows 11 宿主机、VMware NAT 网络、Rocky Linux 10 虚拟机。
>
> 本文不使用批处理脚本、Shell 安装脚本、Docker Compose 或 `.env` 文件。所有组件均按步骤手动安装和配置。
>
> 当前项目固定使用 Redis 8.4.4，禁止改成 `latest`。本文保留“源码安装 Redis → 配置并验证 → 迁移到 Docker”的完整过程；项目最终运行形态仍是 Rocky Linux 虚拟机中的 `redis:8.4.4` 容器。

## 第一步：进入 Rocky Linux 虚拟机

### 在哪里操作

本步骤在 Windows 本机操作，使用 Windows Terminal 或 PowerShell 连接虚拟机。

### 输入命令

```powershell
ssh root@192.168.154.10
```

### 执行后的结果

连接成功后，命令提示符类似：

```text
root@ygh-vm:~#
```

后续标有“在 Rocky Linux 虚拟机中执行”的命令，都在这个 SSH 窗口中输入。

### 哪些内容需要修改

- 如果客户虚拟机不是 `192.168.154.10`，把命令中的 IP 改成客户实际虚拟机 IP。
- 如果不允许 root 直接登录，把 `root` 改成实际 Linux 用户名，后续系统命令前加 `sudo`。

## 第二步：检查虚拟机网络，不通过时不要安装 Docker

### 在哪里操作

在 Rocky Linux 虚拟机中执行。

### 2.1 查看网卡地址

```bash
ip -4 addr show ens160
```

预期结果中必须包含：

```text
inet 192.168.154.10/24
```

如果网卡名称不是 `ens160`，先输入：

```bash
ip -br link
```

记住实际网卡名称，后续把文档中的 `ens160` 全部替换为实际名称。

### 2.2 查看默认网关

```bash
ip route
```

预期至少包含：

```text
default via 192.168.154.2 dev ens160
192.168.154.0/24 dev ens160
```

本项目当前 VMware NAT 网络参数为：

- Windows VMnet8 地址：`192.168.154.1`
- VMware NAT 网关：`192.168.154.2`
- Rocky Linux 固定服务地址：`192.168.154.10`
- 子网掩码：`255.255.255.0`，即 `/24`

如果没有 `default via 192.168.154.2`，先查看当前连接名称：

```bash
nmcli -t -f NAME,DEVICE connection show --active
```

如果输出为：

```text
ens160:ens160
```

说明连接名称也是 `ens160`。输入以下命令修正固定地址、网关和 DNS：

```bash
nmcli connection modify ens160 ipv4.method manual
nmcli connection modify ens160 ipv4.addresses 192.168.154.10/24
nmcli connection modify ens160 ipv4.gateway 192.168.154.2
nmcli connection modify ens160 ipv4.dns "223.5.5.5 119.29.29.29 8.8.8.8"
nmcli connection modify ens160 ipv4.ignore-auto-dns yes
nmcli connection up ens160
```

如果第一条 `nmcli` 命令显示的连接名称不是 `ens160`，只替换上述命令中 `connection modify` 和 `connection up` 后面的连接名称，不要修改网卡地址。

重新执行：

```bash
ip route
```

### 2.3 按顺序测试网络

先测试 VMware NAT 网关：

```bash
ping -c 4 192.168.154.2
```

成功时会看到 `0% packet loss`。如果这里失败，需要在 Windows 中打开 VMware 的“编辑”→“虚拟网络编辑器”，确认 `VMnet8` 使用 NAT 模式、子网为 `192.168.154.0`、网关为 `192.168.154.2`，并确认虚拟机“网络适配器”选择的是 NAT。

再测试公网 IP：

```bash
ping -c 4 223.5.5.5
```

成功时会看到来自 `223.5.5.5` 的回复。如果网关能通而公网 IP 不通，检查 Windows 上的 `VMware NAT Service` 是否正在运行。

最后测试 DNS：

```bash
getent hosts mirrors.rockylinux.org
```

成功时会返回一个或多个 IP。如果公网 IP 能通但这里没有结果，输入：

```bash
cat /etc/resolv.conf
```

确认其中存在 DNS 服务器；然后重新执行前面的 `nmcli connection modify ... ipv4.dns` 和 `nmcli connection up ...` 命令。

只有网关、公网 IP 和域名解析全部正常，才能继续下一步。

## 第三步：在 Windows 下载并上传 Redis 8.4.4 源码包

### 在哪里操作

源码包先下载到 Windows，再使用 WinSCP 上传到 Rocky Linux 虚拟机。Windows 只负责下载和上传，不在 Windows、WSL 或 Windows Docker Desktop 中安装源码版 Redis。

### 3.1 下载源码包

1. 在 Windows 打开 Edge 或 Chrome。
2. 在地址栏输入：

~~~text
https://download.redis.io/releases/redis-8.4.4.tar.gz
~~~

3. 按回车开始下载。
4. 点击浏览器右上角“下载”，再点击文件右侧的文件夹图标。
5. 确认下载文件名是 `redis-8.4.4.tar.gz`。

默认位置通常是：

~~~text
C:\Users\当前Windows用户名\Downloads\redis-8.4.4.tar.gz
~~~

不要下载 `redis-stable.tar.gz`，也不要使用 `latest`。源码版和 Docker 版必须统一为项目固定版本 8.4.4。

### 3.2 在 Windows 计算文件哈希

在 Windows PowerShell 执行：

~~~powershell
Get-FileHash "$HOME\Downloads\redis-8.4.4.tar.gz" -Algorithm SHA256
~~~

当前从 Redis 官方版本地址下载的 `redis-8.4.4.tar.gz` 实测 SHA256 为：

```text
C41CE78682346C1CAAB0EA917826EB408D666746755A0772B55754227D72EBE9
```

Windows 输出必须与该值一致。记住输出，上传后还要与虚拟机中的文件再次核对。如果文件不在 Downloads 目录，将命令中的路径改成实际路径。

### 3.3 在虚拟机创建安装包目录

在 Rocky Linux SSH 窗口执行：

~~~bash
mkdir -p /opt/software
mkdir -p /opt/backup/redis
ls -ld /opt/software /opt/backup/redis
~~~

目录用途：

- `/opt/software`：保存原始源码压缩包。
- `/opt/backup/redis`：保存迁移前的配置和数据备份。

### 3.4 使用 WinSCP 上传

1. 打开 WinSCP，文件协议选择 `SFTP`。
2. 主机名填写 `192.168.154.10`，端口填写 `22`。
3. 用户名填写 `root`；如果客户使用普通管理员用户，则填写实际用户名。
4. 登录后，左侧进入 Windows 的 Downloads 目录。
5. 右侧地址栏输入 `/opt/software` 并回车。
6. 将左侧 `redis-8.4.4.tar.gz` 拖到右侧。
7. 确认远程文件是 `/opt/software/redis-8.4.4.tar.gz`。

### 3.5 在虚拟机核对上传结果

~~~bash
ls -lh /opt/software/redis-8.4.4.tar.gz
sha256sum /opt/software/redis-8.4.4.tar.gz
~~~

Linux 输出必须与第 3.2 步 Windows 输出完全一致。不一致时删除这个损坏的上传文件并重新上传：

~~~bash
rm -f /opt/software/redis-8.4.4.tar.gz
~~~

这里只能删除刚上传且哈希不一致的安装包，不能删除 `/opt/software` 中其他文件。

## 第四步：安装 Redis 源码编译依赖

### 在哪里安装

以下编译组件安装在 Rocky Linux 虚拟机操作系统中，不安装到 Docker 容器。

### 输入命令

~~~bash
dnf install -y gcc gcc-c++ make openssl-devel systemd-devel tcl tar
~~~

组件用途：

- `gcc`、`gcc-c++`：编译 Redis 源码。
- `make`：执行 Redis Makefile。
- `openssl-devel`：编译 TLS 能力。
- `systemd-devel`：提供 systemd 开发文件。
- `tcl`：运行 Redis 自带测试。
- `tar`：解压源码包。

验证安装：

~~~bash
gcc --version
make --version
openssl version
tclsh <<< 'puts $tcl_version'
~~~

如果 DNF 提示无法解析 Rocky Linux 仓库域名，返回第二步修复网络，不要继续编译。

## 第五步：解压、编译并安装 Redis 8.4.4

### 安装位置

- 原始压缩包：`/opt/software/redis-8.4.4.tar.gz`
- 解压后的源码：`/usr/local/src/redis-8.4.4`
- 最终程序目录：`/usr/local/redis`
- Redis 命令目录：`/usr/local/redis/bin`

源码、程序、配置和运行数据必须分开保存。

### 5.1 解压源码

~~~bash
mkdir -p /usr/local/src
tar -xzf /opt/software/redis-8.4.4.tar.gz -C /usr/local/src
cd /usr/local/src/redis-8.4.4
pwd
ls -l redis.conf Makefile
~~~

`pwd` 必须输出 `/usr/local/src/redis-8.4.4`。

如果该目录以前已经存在，解压前先改名备份，不能直接覆盖：

~~~bash
mv /usr/local/src/redis-8.4.4 /usr/local/src/redis-8.4.4.bak
~~~

### 5.2 清理编译缓存

~~~bash
cd /usr/local/src/redis-8.4.4
make distclean
~~~

首次编译时可能提示部分旧目标不存在；重新编译时必须执行该命令，避免旧对象文件干扰。

### 5.3 编译并保留 TLS 能力

虚拟机为 2 个 vCPU，因此使用 `-j2`：

~~~bash
make -j2 BUILD_TLS=yes
~~~

完成后验证：

~~~bash
./src/redis-server --version
./src/redis-cli --help | grep -E -- '--tls|--cacert|--cert'
~~~

版本必须是 8.4.4，帮助中应出现 TLS 参数。当前项目开发环境没有启用 Redis TLS，所以这里只保留编译能力，配置中仍使用普通 6379 端口。

### 5.4 执行源码测试

~~~bash
make test
~~~

测试必须完成且没有 `failed`。测试失败时停止安装并保留输出，不能交付未通过测试的二进制文件。

### 5.5 安装到固定目录

如果 `/usr/local/redis` 已存在，先备份：

~~~bash
mv /usr/local/redis /usr/local/redis.bak
~~~

执行安装：

~~~bash
make PREFIX=/usr/local/redis install
ls -lh /usr/local/redis/bin
/usr/local/redis/bin/redis-server --version
~~~

`bin` 目录至少应包含 `redis-server`、`redis-cli`、`redis-benchmark`、`redis-check-rdb` 和 `redis-check-aof`。

## 第六步：创建 Redis 用户、配置目录和运行目录

### 目录规划

- 配置文件：`/usr/local/redis/conf/redis.conf`
- 官方原始配置备份：`/usr/local/redis/conf/redis.conf.original`
- 数据目录：`/usr/local/redis/data`
- 日志目录：`/usr/local/redis/logs`
- PID 目录：`/usr/local/redis/run`
- 备份目录：`/opt/backup/redis`

### 6.1 创建 Redis 系统用户

~~~bash
id redis
~~~

如果提示用户不存在，执行：

~~~bash
useradd --system --home-dir /usr/local/redis --shell /sbin/nologin redis
id redis
~~~

源码版 Redis 后续以 `redis` 用户运行，不以 root 身份运行。

### 6.2 创建目录并复制配置

~~~bash
mkdir -p /usr/local/redis/conf
mkdir -p /usr/local/redis/data
mkdir -p /usr/local/redis/logs
mkdir -p /usr/local/redis/run
cp /usr/local/src/redis-8.4.4/redis.conf /usr/local/redis/conf/redis.conf
cp /usr/local/redis/conf/redis.conf /usr/local/redis/conf/redis.conf.original
~~~

`redis.conf.original` 是官方默认配置备份，不能修改。

### 6.3 配置权限

~~~bash
chown -R root:redis /usr/local/redis/conf
chown -R redis:redis /usr/local/redis/data
chown -R redis:redis /usr/local/redis/logs
chown -R redis:redis /usr/local/redis/run
chmod 750 /usr/local/redis/conf
chmod 640 /usr/local/redis/conf/redis.conf
chmod 440 /usr/local/redis/conf/redis.conf.original
chmod 750 /usr/local/redis/data /usr/local/redis/logs /usr/local/redis/run
~~~

不要使用 `chmod 777`。配置文件中包含密码，数据目录中包含业务缓存和会话状态。

### 6.4 配置 PATH 环境变量

先备份：

~~~bash
cp -a /etc/profile /etc/profile.bak-redis
vi /etc/profile
~~~

按 `i` 进入编辑模式，在文件末尾添加：

~~~bash
export PATH=$PATH:/usr/local/redis/bin
~~~

按 `Esc`，输入 `:wq` 并回车，然后执行：

~~~bash
source /etc/profile
redis-server --version
redis-cli --version
~~~

如果配置错误，执行以下命令回滚：

~~~bash
cp -a /etc/profile.bak-redis /etc/profile
source /etc/profile
~~~

## 第七步：手动修改源码版 Redis 配置文件

### 7.1 生成密码

~~~bash
openssl rand -base64 24
~~~

把输出保存到客户自己的密码管理器。不要使用 `123456`，不要把真实密码写进文档、Git、截图或聊天记录。

### 7.2 修改配置文件

~~~bash
vi /usr/local/redis/conf/redis.conf
~~~

在 `vi` 中按 `/`，输入配置项名称并回车即可定位。把原有配置项修改为下面的值。Redis 官方配置中的 `tls-port`、`maxmemory-policy` 和 `requirepass` 默认可能以 `#` 开头被注释，遇到这种情况要删除行首的 `#` 再修改；不要保留两个同时生效的同名配置：

~~~conf
bind 127.0.0.1 192.168.154.10
protected-mode yes
port 6379
tls-port 0

daemonize no
supervised no
pidfile /usr/local/redis/run/redis_6379.pid
loglevel notice
logfile "/usr/local/redis/logs/redis.log"

databases 16

save 3600 1
save 300 100
save 60 10000
dir /usr/local/redis/data
dbfilename dump.rdb

appendonly yes
appendfilename "appendonly.aof"
appenddirname "appendonlydir"
appendfsync everysec

maxmemory 96mb
maxmemory-policy noeviction

requirepass REPLACE_WITH_THE_SOURCE_REDIS_PASSWORD
~~~

必须把最后一行占位符替换成第 7.1 步生成的真实密码。

这里已经适配当前项目：固定地址 `192.168.154.10`、端口 6379、AOF `everysec`、96MiB 最大内存、`noeviction` 策略。源码虽然以 `BUILD_TLS=yes` 编译，但当前项目 Java 配置没有开启 TLS，因此 `tls-port` 保持为 0。

检查是否遗留占位符并恢复权限：

~~~bash
grep -n 'REPLACE_WITH' /usr/local/redis/conf/redis.conf
chown root:redis /usr/local/redis/conf/redis.conf
chmod 640 /usr/local/redis/conf/redis.conf
~~~

`grep` 正确结果是不输出任何内容。

### 7.3 前台检查配置

先确认 6379 没有被占用：

~~~bash
ss -lntp | grep ':6379'
~~~

没有输出时执行：

~~~bash
runuser -u redis -- /usr/local/redis/bin/redis-server /usr/local/redis/conf/redis.conf --daemonize no
~~~

看到 `Ready to accept connections` 后按 `Ctrl+C` 停止。若立即报错，按错误行修改配置，不能继续创建服务。

## 第八步：创建源码版 Redis systemd 服务

### 服务文件位置

服务文件固定为 `/etc/systemd/system/ygh-redis-source.service`。使用 `ygh-redis-source` 名称，是为了与后面的 Docker 容器 `ygh-redis` 区分。

### 8.1 创建服务文件

~~~bash
vi /etc/systemd/system/ygh-redis-source.service
~~~

输入：

~~~ini
[Unit]
Description=YGH Redis 8.4.4 Source Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=redis
Group=redis
ExecStart=/usr/local/redis/bin/redis-server /usr/local/redis/conf/redis.conf
ExecStop=/bin/kill -s TERM $MAINPID
Restart=on-failure
RestartSec=5
LimitNOFILE=65535
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ReadWritePaths=/usr/local/redis/data /usr/local/redis/logs /usr/local/redis/run

[Install]
WantedBy=multi-user.target
~~~

保存后执行：

~~~bash
chown root:root /etc/systemd/system/ygh-redis-source.service
chmod 644 /etc/systemd/system/ygh-redis-source.service
systemd-analyze verify /etc/systemd/system/ygh-redis-source.service
systemctl daemon-reload
systemctl enable --now ygh-redis-source
systemctl status ygh-redis-source --no-pager
~~~

必须看到 `Active: active (running)`。失败时查看：

~~~bash
journalctl -u ygh-redis-source -n 100 --no-pager
tail -n 100 /usr/local/redis/logs/redis.log
~~~

## 第九步：验证源码版 Redis

### 9.1 验证监听和认证

~~~bash
ss -lntp | grep ':6379'
/usr/local/redis/bin/redis-cli -h 127.0.0.1 -p 6379 PING
~~~

未提供密码时必须返回 `NOAUTH Authentication required.`。

输入密码进行验证：

~~~bash
read -s -p "请输入源码版 Redis 密码: " SOURCE_REDIS_PASSWORD
echo
REDISCLI_AUTH="$SOURCE_REDIS_PASSWORD" /usr/local/redis/bin/redis-cli -h 127.0.0.1 -p 6379 PING
~~~

必须返回 `PONG`。

### 9.2 检查项目参数和数据位置

~~~bash
REDISCLI_AUTH="$SOURCE_REDIS_PASSWORD" redis-cli INFO server
REDISCLI_AUTH="$SOURCE_REDIS_PASSWORD" redis-cli CONFIG GET appendonly
REDISCLI_AUTH="$SOURCE_REDIS_PASSWORD" redis-cli CONFIG GET appendfsync
REDISCLI_AUTH="$SOURCE_REDIS_PASSWORD" redis-cli CONFIG GET maxmemory
REDISCLI_AUTH="$SOURCE_REDIS_PASSWORD" redis-cli CONFIG GET maxmemory-policy
REDISCLI_AUTH="$SOURCE_REDIS_PASSWORD" redis-cli SET ygh:migration:test source-ok
REDISCLI_AUTH="$SOURCE_REDIS_PASSWORD" redis-cli SAVE
ls -lh /usr/local/redis/data/dump.rdb
find /usr/local/redis/data/appendonlydir -maxdepth 2 -type f -ls
REDISCLI_AUTH="$SOURCE_REDIS_PASSWORD" redis-cli DEL ygh:migration:test
unset SOURCE_REDIS_PASSWORD
~~~

必须确认版本为 8.4.4、`appendonly=yes`、`appendfsync=everysec`、`maxmemory=100663296`、`maxmemory-policy=noeviction`。RDB 和 AOF 必须位于 `/usr/local/redis/data`。

## 第十步：备份并停止源码版 Redis，准备迁移

源码版与 Docker Redis 都使用 `192.168.154.10:6379`，不能同时启动。

### 10.1 保存并备份

~~~bash
read -s -p "请输入源码版 Redis 密码: " SOURCE_REDIS_PASSWORD
echo
REDISCLI_AUTH="$SOURCE_REDIS_PASSWORD" redis-cli SAVE
unset SOURCE_REDIS_PASSWORD
mkdir -p /opt/backup/redis/source-8.4.4
cp -a /usr/local/redis/conf/redis.conf /opt/backup/redis/source-8.4.4/redis.conf
cp -a /usr/local/redis/data/dump.rdb /opt/backup/redis/source-8.4.4/dump.rdb
cp -a /usr/local/redis/data/appendonlydir /opt/backup/redis/source-8.4.4/
sha256sum /opt/backup/redis/source-8.4.4/dump.rdb
~~~

备份目录包含数据和密码配置，只能保存在客户虚拟机本地，不能提交到 Git。

### 10.2 停止源码服务

~~~bash
systemctl disable --now ygh-redis-source
systemctl status ygh-redis-source --no-pager
ss -lntp | grep ':6379'
~~~

服务应为 `inactive (dead)`，6379 不应再有监听。

Docker 迁移失败时的回滚顺序：

~~~bash
docker stop ygh-redis
systemctl enable --now ygh-redis-source
systemctl status ygh-redis-source --no-pager
~~~

## 第十一步：清理可能冲突的旧 Docker 软件包

### 在哪里安装

Docker Engine 安装在 Rocky Linux 虚拟机操作系统中，由 systemd 管理。Docker 默认数据目录是虚拟机内的 `/var/lib/docker`。

本步骤不在 Windows、不在 WSL，也不在 IDEA 中执行。

### 输入命令

```bash
dnf remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine podman-docker
```

### 执行后的结果

- 新虚拟机通常显示没有匹配的软件包，这是正常结果。
- 如果发现旧包，DNF 会将冲突包卸载。
- 该命令不会主动删除 `/var/lib/docker` 中已有的镜像、容器和数据卷。

不要执行 `rm -rf /var/lib/docker`，否则会删除已有 Docker 数据。

## 第十二步：安装 Docker 仓库管理工具

### 在哪里操作

在 Rocky Linux 虚拟机中执行。

### 输入命令

```bash
dnf clean all
dnf makecache
dnf install -y dnf-plugins-core curl ca-certificates openssl
```

### 执行后的结果

最后应看到类似：

```text
Complete!
```

### 如果执行失败

如果出现：

```text
Could not resolve host: mirrors.rockylinux.org
```

说明第二步的网络或 DNS 还没有修好，不是 Docker 软件包本身的问题。返回第二步重新检查，不要反复执行 `dnf install`。

## 第十三步：添加 Docker 软件仓库

### 在哪里操作

在 Rocky Linux 虚拟机中执行。

### 13.1 优先添加 Docker 官方 CentOS 仓库

Rocky Linux 是 RHEL 兼容发行版，当前项目按照 Docker 官方 CentOS Stream 10 RPM 仓库方式安装。

```bash
dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
```

查看仓库是否添加成功：

```bash
dnf repolist | grep docker-ce-stable
```

预期结果包含：

```text
docker-ce-stable
```

### 13.2 官方仓库无法访问时使用阿里云仓库地址

只有官方地址持续连接失败时，才执行下面的替代操作。

先删除失败的仓库文件：

```bash
rm -f /etc/yum.repos.d/docker-ce.repo
```

再添加阿里云镜像地址：

```bash
dnf config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
```

重新生成缓存：

```bash
dnf clean all
dnf makecache
```

执行后的结果必须包含 `docker-ce-stable` 仓库，才能继续。

## 第十四步：安装并启动 Docker Engine

### 在哪里安装

以下组件全部安装到 Rocky Linux 虚拟机：

- `docker-ce`：Docker 服务端引擎。
- `docker-ce-cli`：`docker` 命令行工具。
- `containerd.io`：容器运行时。
- `docker-buildx-plugin`：镜像构建插件。
- `docker-compose-plugin`：Compose 插件。本文不使用 Compose，但项目仓库保留了 Compose 配置，安装后便于后续维护。

### 输入命令

```bash
dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

启动 Docker 并设置开机自动启动：

```bash
systemctl enable --now docker
```

查看服务状态：

```bash
systemctl status docker --no-pager
```

### 执行后的结果

状态中必须包含：

```text
Active: active (running)
```

再查看版本：

```bash
docker version
docker compose version
```

当前项目实测版本是 Docker Engine `29.6.1`、Docker Compose `5.3.1`。客户安装时补丁版本可以更新，但必须保证 `docker version` 同时显示 Client 和 Server 信息。

## 第十五步：手动配置 Docker 镜像源和运行参数

### 在哪里配置

配置文件位于 Rocky Linux 虚拟机：

```text
/etc/docker/daemon.json
```

该文件配置的是虚拟机中的 Docker Engine，不影响 Windows Docker Desktop。

### 15.1 备份已有配置

先查看文件是否存在：

```bash
ls -l /etc/docker/daemon.json
```

如果文件存在，输入：

```bash
cp -a /etc/docker/daemon.json /etc/docker/daemon.json.bak
```

如果提示文件不存在，直接继续。

### 15.2 打开配置文件

```bash
mkdir -p /etc/docker
vi /etc/docker/daemon.json
```

进入 `vi` 后按键盘 `i` 进入编辑模式，输入以下完整内容：

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
    {
      "base": "172.30.0.0/16",
      "size": 24
    }
  ]
}
```

输入完成后按 `Esc`，输入 `:wq`，按回车保存退出。

两个镜像地址是当前项目实测使用的 Docker Hub 代理。第三方镜像代理可用性会变化；代理失效时可以删除失效地址，保留可用地址，或直接使用 Docker Hub。镜像版本仍由 `docker pull` 后面的标签决定，镜像源不会把固定的 `8.4.4` 自动改成其他版本。

### 15.3 验证 JSON 配置

```bash
dockerd --validate --config-file=/etc/docker/daemon.json
```

预期输出：

```text
configuration OK
```

如果不是 `configuration OK`，不要重启 Docker。重新执行 `vi /etc/docker/daemon.json`，检查英文双引号、逗号和大括号。

### 15.4 重启 Docker

```bash
systemctl daemon-reload
systemctl restart docker
systemctl status docker --no-pager
```

状态必须仍然是 `active (running)`。

如果 Docker 重启失败，并且第 15.1 步已经生成备份，执行以下命令回滚：

```bash
cp -a /etc/docker/daemon.json.bak /etc/docker/daemon.json
dockerd --validate --config-file=/etc/docker/daemon.json
systemctl restart docker
systemctl status docker --no-pager
```

只有验证输出 `configuration OK` 后才能重启。

### 15.5 验证镜像源和 Docker 参数

```bash
docker info
```

在输出中检查：

- `Storage Driver: overlay2`
- `Live Restore Enabled: true`
- `Registry Mirrors` 下存在 DaoCloud 和 1ms 地址
- `Docker Root Dir: /var/lib/docker`

先拉取轻量镜像测试：

```bash
docker pull alpine
```

成功时会看到：

```text
Status: Downloaded newer image for alpine:latest
```

这里的 Alpine 只用于测试 Docker 网络，不是项目运行组件。

## 第十六步：拉取项目固定版本的 Redis 镜像

### 在哪里下载

在 Rocky Linux 虚拟机中通过 Docker 拉取。镜像存放在 Docker 数据目录 `/var/lib/docker`，不要手动解压或移动镜像文件。

### 输入命令

```bash
docker pull redis:8.4.4
```

### 执行后的结果

成功时会看到：

```text
Status: Downloaded newer image for redis:8.4.4
docker.io/library/redis:8.4.4
```

检查镜像：

```bash
docker image inspect redis:8.4.4 --format '镜像={{.RepoTags}} 架构={{.Architecture}}'
```

预期结果中包含 `redis:8.4.4` 和 `amd64`。

不要使用：

```bash
docker pull redis:latest
```

本项目部署规格明确禁止 `latest`，否则同一份交付文档在不同时间可能拉到不同版本。

## 第十七步：创建 Redis 的项目目录、网络和数据卷

### 安装位置说明

本步骤全部在 Rocky Linux 虚拟机中执行：

- Redis 配置文件：`/opt/ygh/redis/conf/redis.conf`
- Redis 容器：虚拟机 Docker 中的 `ygh-redis`
- Redis 数据卷：`ygh-redis-data`
- 数据卷实际位置：`/var/lib/docker/volumes/ygh-redis-data/_data`
- Docker 网络：`ygh-core`

不要直接修改 `/var/lib/docker/volumes` 下面的文件，数据读写由 Docker 和 Redis 管理。

### 17.1 创建配置目录

```bash
mkdir -p /opt/ygh/redis/conf
```

### 17.2 创建 Docker 网络

```bash
docker network create ygh-core
```

预期返回一串网络 ID。如果提示网络已经存在，说明之前创建过，可以继续。

检查网络：

```bash
docker network inspect ygh-core --format '网络={{.Name}} 驱动={{.Driver}}'
```

预期结果：

```text
网络=ygh-core 驱动=bridge
```

### 17.3 创建数据卷

```bash
docker volume create ygh-redis-data
```

预期输出：

```text
ygh-redis-data
```

检查数据卷：

```bash
docker volume inspect ygh-redis-data --format '数据卷={{.Name}} 路径={{.Mountpoint}}'
```

预期路径为：

```text
/var/lib/docker/volumes/ygh-redis-data/_data
```

### 17.4 将第十步备份的源码数据导入空数据卷

如果第三步至第十步已经生成源码版 Redis 数据，必须在第一次启动 Docker Redis 之前导入。先检查备份：

```bash
ls -lh /opt/backup/redis/source-8.4.4/dump.rdb
sha256sum /opt/backup/redis/source-8.4.4/dump.rdb
```

确认文件存在后执行：

```bash
docker run --rm \
  -v ygh-redis-data:/data \
  -v /opt/backup/redis/source-8.4.4:/backup:ro,Z \
  redis:8.4.4 \
  sh -c 'test ! -e /data/dump.rdb && cp /backup/dump.rdb /data/dump.rdb && chown redis:redis /data/dump.rdb'
```

检查数据卷：

```bash
docker run --rm -v ygh-redis-data:/data redis:8.4.4 ls -lh /data/dump.rdb
```

必须看到 `/data/dump.rdb`。Docker Redis 第一次启动时会读取该文件，并在运行后按照项目配置继续生成 AOF。

如果客户明确不需要源码版中的任何数据，可以跳过导入，但必须先由业务负责人确认，不要擅自丢弃已有数据。

## 第十八步：生成 Docker Redis 密码并手动编写配置文件

### 在哪里配置

在 Rocky Linux 虚拟机中配置 `/opt/ygh/redis/conf/redis.conf`。

本文不使用 `.env`，密码由管理员手动生成后写入服务器上的 Redis 配置文件。真实密码不得写进项目代码、Git、Markdown、聊天记录或截图。

### 18.1 生成强密码

```bash
openssl rand -base64 24
```

命令会输出一行随机内容。立即将该值保存到客户自己的密码管理器，后面 IDEA 配置也要使用同一个值。

不要使用 `123456`、公司名称、手机号或文档中的示例文字作为密码。

### 18.2 打开 Redis 配置文件

如果该文件以前已经存在，先备份：

```bash
cp -a /opt/ygh/redis/conf/redis.conf /opt/ygh/redis/conf/redis.conf.bak
```

如果提示文件不存在，说明是首次安装，直接继续。

```bash
vi /opt/ygh/redis/conf/redis.conf
```

按 `i` 进入编辑模式，输入以下完整配置：

```conf
bind 0.0.0.0
protected-mode yes
port 6379
tcp-backlog 511
timeout 0
tcp-keepalive 300

daemonize no
supervised no
loglevel notice
logfile ""

databases 16

save 3600 1
save 300 100
save 60 10000
dir /data
dbfilename dump.rdb

appendonly yes
appendfilename "appendonly.aof"
appenddirname "appendonlydir"
appendfsync everysec

maxmemory 96mb
maxmemory-policy noeviction

requirepass REPLACE_WITH_THE_PASSWORD_GENERATED_IN_THE_PREVIOUS_STEP
```

必须把最后一行的：

```text
REPLACE_WITH_THE_PASSWORD_GENERATED_IN_THE_PREVIOUS_STEP
```

替换为刚才 `openssl rand -base64 24` 生成的真实密码。`requirepass` 与密码之间保留一个空格。

按 `Esc`，输入 `:wq`，按回车保存退出。

### 18.3 确认没有遗留占位符

```bash
grep -n 'REPLACE_WITH' /opt/ygh/redis/conf/redis.conf
```

正确结果是不输出任何内容。如果仍然输出最后一行，说明密码没有替换，必须重新编辑。

### 18.4 设置配置文件权限

先确认官方镜像中的 Redis 用户 ID：

```bash
docker run --rm redis:8.4.4 id redis
```

通常会看到 `uid=999(redis)` 和 `gid=999(redis)`。如果实际数字不是 `999`，将下一条命令中的 `999` 替换为实际 GID。

```bash
chown root:999 /opt/ygh/redis/conf/redis.conf
chmod 640 /opt/ygh/redis/conf/redis.conf
ls -l /opt/ygh/redis/conf/redis.conf
```

预期权限类似：

```text
-rw-r----- 1 root 999 ... /opt/ygh/redis/conf/redis.conf
```

不要使用 `chmod 777`。该文件包含 Redis 密码，只允许 root 写入和 Redis 容器用户读取。

如果配置修改错误并且存在备份，执行下面的命令回滚，然后重启容器：

```bash
cp -a /opt/ygh/redis/conf/redis.conf.bak /opt/ygh/redis/conf/redis.conf
docker restart ygh-redis
```

## 第十九步：手动启动项目 Redis 容器

### Redis 安装到哪里

Redis 不作为 Rocky Linux 系统软件安装。Redis 8.4.4 运行在虚拟机 Docker 的 `ygh-redis` 容器中，配置文件和数据分别挂载到容器内部：

- `/opt/ygh/redis/conf/redis.conf` → `/usr/local/etc/redis/redis.conf`
- `ygh-redis-data` → `/data`

### 19.1 确认端口没有被占用

```bash
ss -lntp | grep ':6379'
```

正确结果是不输出任何内容。如果源码版 Redis 或其他容器仍占用 6379，返回第十步完成备份和停机，不要直接启动第二个 Redis。

### 19.2 确认没有同名容器

```bash
docker ps -a --filter name=^/ygh-redis$
```

如果没有输出容器记录，继续执行启动命令。

如果已经存在 `ygh-redis`，先执行：

```bash
docker inspect ygh-redis --format '状态={{.State.Status}} 镜像={{.Config.Image}}'
```

确认它是不是本项目已有容器。不要直接删除来源不明的容器。

### 19.3 启动容器

```bash
docker run -d \
  --name ygh-redis \
  --restart unless-stopped \
  --network ygh-core \
  --cpus 0.20 \
  --memory 128m \
  -p 192.168.154.10:6379:6379 \
  -v ygh-redis-data:/data \
  -v /opt/ygh/redis/conf/redis.conf:/usr/local/etc/redis/redis.conf:ro,Z \
  --log-driver json-file \
  --log-opt max-size=5m \
  --log-opt max-file=3 \
  --health-cmd='REDISCLI_AUTH=$(sed -n "s/^requirepass //p" /usr/local/etc/redis/redis.conf) redis-cli ping | grep -q PONG' \
  --health-interval 10s \
  --health-timeout 3s \
  --health-retries 10 \
  redis:8.4.4 \
  redis-server /usr/local/etc/redis/redis.conf
```

这是一个手动执行的 Docker 命令，不是启动脚本。各参数与项目 `vm-compose.yml` 的 Redis 配置保持一致：

- 固定镜像 `redis:8.4.4`。
- 容器内存上限 `128m`。
- CPU 上限 `0.20`。
- Redis 最大数据内存 `96mb`。
- 内存满时使用 `noeviction`，不静默淘汰会话撤销和安全状态。
- AOF 持久化开启，刷盘策略为 `everysec`。
- 端口只绑定虚拟机固定服务地址 `192.168.154.10`，不绑定 `0.0.0.0`。
- 容器重启策略为 `unless-stopped`。
- 每 10 秒执行一次需要密码认证的 `PING` 健康检查。

### 执行后的结果

成功后返回一串容器 ID。查看容器：

```bash
docker ps --filter name=^/ygh-redis$
```

预期包含：

```text
redis:8.4.4
192.168.154.10:6379->6379/tcp
Up ... (healthy)
```

如果容器没有出现在 `docker ps` 中，立即输入：

```bash
docker ps -a --filter name=^/ygh-redis$
docker logs --tail 100 ygh-redis
```

根据日志处理配置格式、权限或端口占用问题。

## 第二十步：在虚拟机内验证 Docker Redis

### 20.1 验证未认证访问会被拒绝

```bash
docker exec ygh-redis redis-cli PING
```

预期结果：

```text
NOAUTH Authentication required.
```

这说明密码认证已经生效。

### 20.2 不在命令历史中明文输入密码

输入：

```bash
read -s -p "请输入 Redis 密码: " REDIS_PASSWORD
```

输入密码时屏幕不会显示字符。输入完成后按回车，再输入：

```bash
echo
docker exec -e REDISCLI_AUTH="$REDIS_PASSWORD" ygh-redis redis-cli PING
```

预期结果：

```text
PONG
```

### 20.3 检查项目关键参数

```bash
docker exec -e REDISCLI_AUTH="$REDIS_PASSWORD" ygh-redis redis-cli INFO server
docker exec -e REDISCLI_AUTH="$REDIS_PASSWORD" ygh-redis redis-cli CONFIG GET appendonly
docker exec -e REDISCLI_AUTH="$REDIS_PASSWORD" ygh-redis redis-cli CONFIG GET appendfsync
docker exec -e REDISCLI_AUTH="$REDIS_PASSWORD" ygh-redis redis-cli CONFIG GET maxmemory
docker exec -e REDISCLI_AUTH="$REDIS_PASSWORD" ygh-redis redis-cli CONFIG GET maxmemory-policy
```

需要确认：

- Redis 版本为 `8.4.4`。
- `appendonly` 为 `yes`。
- `appendfsync` 为 `everysec`。
- `maxmemory` 为 `100663296`，即 96MiB。
- `maxmemory-policy` 为 `noeviction`。

验证完成后清除当前 Shell 中的临时变量：

```bash
unset REDIS_PASSWORD
```

## 第二十一步：配置 Rocky Linux 防火墙

### 在哪里操作

在 Rocky Linux 虚拟机中执行。

本项目开发环境只允许 Windows 宿主机的 VMware 网卡 `192.168.154.1` 访问 Redis，不向整个局域网开放 6379。

### 输入命令

```bash
firewall-cmd --state
```

预期输出 `running`。然后输入：

```bash
firewall-cmd --permanent --add-rich-rule='rule family=ipv4 source address=192.168.154.1/32 port protocol=tcp port=6379 accept'
firewall-cmd --reload
firewall-cmd --list-rich-rules
```

预期规则中包含：

```text
source address="192.168.154.1/32" port port="6379" protocol="tcp" accept
```

如果客户 Windows 的 VMnet8 地址不是 `192.168.154.1`，在 Windows PowerShell 输入 `ipconfig`，找到“VMware Network Adapter VMnet8”的 IPv4 地址，然后只替换防火墙命令中的来源地址。

不要执行下面这种对所有来源开放的命令：

```bash
firewall-cmd --permanent --add-port=6379/tcp
```

## 第二十二步：从 Windows 验证 Redis 端口

### 在哪里操作

保持 Redis 容器运行，另外打开 Windows PowerShell。

### 输入命令

```powershell
Test-NetConnection 192.168.154.10 -Port 6379
```

### 执行后的结果

必须看到：

```text
TcpTestSucceeded : True
```

如果是 `False`，按顺序检查：

```bash
docker ps --filter name=^/ygh-redis$
ss -lntp | grep ':6379'
firewall-cmd --list-rich-rules
```

同时确认 VMware VMnet8 与虚拟机仍处于同一 `192.168.154.0/24` 网段。

## 第二十三步：在 IDEA 中配置项目连接 Redis

### Redis 和 Java 项目分别运行在哪里

- Redis：Rocky Linux 虚拟机里的 Docker 容器，地址 `192.168.154.10:6379`。
- Java 服务：Windows 本机的 IntelliJ IDEA。
- WSL：本步骤不使用。
- Windows Docker Desktop：本步骤不使用。

项目代码不需要“拉取到 Redis”或“上传到 Redis”。IDEA 启动 Java 服务后，Java 服务通过 IP、端口和密码连接虚拟机中的 Redis。

### 23.1 打开 IDEA 运行配置

1. 打开 IntelliJ IDEA 和客户解压后的项目目录。
2. 点击右上角当前运行配置名称。
3. 点击 `Edit Configurations...`。
4. 在左侧选择要启动的 Spring Boot 服务，例如 `ygh-gateway`、`ygh-auth-service` 或 `ygh-product-service`。
5. 找到 `Environment variables`。
6. 点击输入框右侧的编辑按钮。

### 23.2 添加 Redis 环境变量

逐项添加：

```text
YGH_REDIS_HOST=192.168.154.10
YGH_REDIS_PORT=6379
YGH_REDIS_PASSWORD=这里填写第十八步生成的Docker Redis真实密码
YGH_REDIS_ENVIRONMENT=dev
```

必须修改的内容只有 `YGH_REDIS_PASSWORD` 的值。如果客户虚拟机 IP 不同，同时修改 `YGH_REDIS_HOST`。

点击 `OK` 保存环境变量，再点击运行配置窗口中的 `Apply` 和 `OK`。

这些变量需要添加到所有实际使用 Redis 的 IDEA 启动配置中。当前项目至少包括：

- `ygh-gateway`
- `ygh-auth-service`
- `ygh-product-service`

其他服务的 `application.yml` 中如果出现 `YGH_REDIS_HOST` 或 `YGH_REDIS_PASSWORD`，也按相同方式配置。

IDEA 通常将个人运行配置保存在本机工作区文件中。不要提交包含真实密码的 `.idea/workspace.xml` 或共享运行配置。

### 23.3 项目代码对应关系

当前项目实际读取的配置是：

```yaml
spring:
  data:
    redis:
      host: ${YGH_REDIS_HOST}
      port: ${YGH_REDIS_PORT:6379}
      password: ${YGH_REDIS_PASSWORD}
```

因此变量名必须完全一致，不能改成 `REDIS_HOST`、`SPRING_REDIS_HOST` 或其他名称。

`ygh-product-service` 默认使用 Redis 数据库 `2`；Gateway 和 Auth 使用各自代码中配置的默认数据库。不要为了“看起来统一”擅自修改数据库编号。

## 第二十四步：验证 IDEA 启动后的项目连接

先保证 Redis 容器正在运行：

```bash
docker ps --filter name=^/ygh-redis$
```

在 IDEA 中启动目标 Java 服务。如果环境变量正确，启动日志中不应出现以下错误：

```text
RedisConnectionFailureException
Unable to connect to Redis
NOAUTH Authentication required
WRONGPASS invalid username-password pair
```

错误含义：

- `Unable to connect to Redis`：检查 IP、6379 端口、虚拟机网络和防火墙。
- `NOAUTH`：IDEA 没有传入 `YGH_REDIS_PASSWORD`。
- `WRONGPASS`：IDEA 中的密码与 `/opt/ygh/redis/conf/redis.conf` 的 `requirepass` 不一致。
- `Connection refused`：Redis 容器未运行，或者端口没有绑定到虚拟机固定地址。

## 第二十五步：将源码版 Redis 数据迁移到 Docker

如果客户只需要一套全新的空 Redis，可以跳过本步骤。项目代码压缩包不包含 Redis 运行数据，Redis 数据不会随着代码自动导入。

如果已经按第三步至第十步安装源码版 Redis，并在第 17.4 步完成导入，就不需要重复执行本步骤。

本步骤只处理两种额外情况：旧 Redis 位于另一台机器，或者 Docker Redis 已经启动后才收到旧数据迁移要求。迁移必须安排在 IDEA 业务服务写入 Redis 之前。

### 25.1 先检查源 Redis 和目标 Redis 版本

在旧 Redis 所在的 Linux 机器执行：

```bash
/usr/local/redis/bin/redis-server --version
```

目标版本固定为：

```text
Redis 8.4.4
```

如果其他旧环境的 Redis 版本高于 `8.4.4`，不要把它的 RDB 文件直接导入项目的 `8.4.4` 容器。高版本到 `8.4.4` 属于降级迁移，RDB/AOF 向旧版本兼容不能默认保证。

出现这种情况时有两个选择：

1. 新客户环境本来就不需要旧缓存：不迁移数据，直接使用空的 `redis:8.4.4`。
2. 必须保留旧数据：先单独制定兼容性验证方案，确认项目能否整体升级到与旧环境相同或更高的 Redis 版本，通过测试后再修改部署基线。未经验证不要改项目镜像版本。

只有源 Redis 版本不高于 `8.4.4`，并完成备份后，才继续下面的 RDB 迁移。

### 25.2 在旧 Redis 上生成 RDB

如果已经完成第十步，并且存在下面的文件，说明 RDB 已经生成，可以跳到 25.4 的“情况一”：

```bash
ls -lh /opt/backup/redis/source-8.4.4/dump.rdb
```

只有源 Redis 仍在其他机器运行时，才继续执行本小节。

不要把密码直接写在命令参数中。输入：

```bash
read -s -p "请输入旧 Redis 密码: " OLD_REDIS_PASSWORD
echo
REDISCLI_AUTH="$OLD_REDIS_PASSWORD" /usr/local/redis/bin/redis-cli PING
```

预期输出 `PONG`。然后输入：

```bash
REDISCLI_AUTH="$OLD_REDIS_PASSWORD" /usr/local/redis/bin/redis-cli SAVE
REDISCLI_AUTH="$OLD_REDIS_PASSWORD" /usr/local/redis/bin/redis-cli CONFIG GET dir
REDISCLI_AUTH="$OLD_REDIS_PASSWORD" /usr/local/redis/bin/redis-cli CONFIG GET dbfilename
unset OLD_REDIS_PASSWORD
```

`SAVE` 预期返回 `OK`。后两条命令会告诉你真实的 RDB 目录和文件名，不要直接猜测一定是 `/usr/local/redis/dbcache/dump.rdb`。

### 25.3 停止旧 Redis，避免迁移过程中继续写入

如果旧 Redis 是本文安装的源码服务，执行：

```bash
systemctl disable --now ygh-redis-source
```

如果旧 Redis 由其他 systemd 服务管理，将下面的 `redis` 替换为真实服务名称：

```bash
systemctl stop redis
```

如果是手动启动，先查进程：

```bash
ps -ef | grep '[r]edis-server'
```

使用 Redis 正常关闭命令，不要直接 `kill -9`：

```bash
read -s -p "请输入旧 Redis 密码: " OLD_REDIS_PASSWORD
echo
REDISCLI_AUTH="$OLD_REDIS_PASSWORD" /usr/local/redis/bin/redis-cli SHUTDOWN SAVE
unset OLD_REDIS_PASSWORD
```

执行 `SHUTDOWN SAVE` 后连接会关闭，这是正常结果。

### 25.4 将 RDB 文件放到新虚拟机

#### 情况一：源码版 Redis 和 Docker 在同一台虚拟机

如果已经完成第十步，在 Rocky Linux 虚拟机执行：

```bash
mkdir -p /opt/ygh/redis-migration
cp -a /opt/backup/redis/source-8.4.4/dump.rdb /opt/ygh/redis-migration/dump.rdb
ls -lh /opt/ygh/redis-migration/dump.rdb
sha256sum /opt/backup/redis/source-8.4.4/dump.rdb
sha256sum /opt/ygh/redis-migration/dump.rdb
```

两个 SHA256 必须完全一致。完成后直接进入 25.5。

#### 情况二：旧 Redis 在其他机器

在 Windows PowerShell 中执行。先在新虚拟机创建迁移目录：

```powershell
ssh root@192.168.154.10 "mkdir -p /opt/ygh/redis-migration"
```

再上传旧环境导出的 `dump.rdb`。下面的 `D:\redis-backup\dump.rdb` 必须替换为 Windows 上真实文件路径：

```powershell
scp "D:\redis-backup\dump.rdb" root@192.168.154.10:/opt/ygh/redis-migration/dump.rdb
```

上传完成后返回虚拟机 SSH 窗口，检查文件：

```bash
ls -lh /opt/ygh/redis-migration/dump.rdb
sha256sum /opt/ygh/redis-migration/dump.rdb
```

记录哈希值，用于确认文件没有在传输中损坏。

### 25.5 将 RDB 导入尚未使用的项目数据卷

本操作要求目标 Redis 尚未承载业务数据。先检查当前 Key 数量：

```bash
read -s -p "请输入 Docker Redis 密码: " REDIS_PASSWORD
echo
docker exec -e REDISCLI_AUTH="$REDIS_PASSWORD" ygh-redis redis-cli DBSIZE
unset REDIS_PASSWORD
```

只有输出为 `0`，并且业务服务还没有开始使用该 Redis，才能继续。只要输出大于 `0`，立即停止迁移，先制定合并、备份和回滚方案，不能覆盖。

Redis 即使没有业务 Key，第一次启动后也会创建空 AOF 文件。因此确认 `DBSIZE` 为 `0` 后，停止并删除空容器，再重建空数据卷：

```bash
docker stop ygh-redis
docker rm ygh-redis
docker volume rm ygh-redis-data
docker volume create ygh-redis-data
```

上面的 `docker volume rm` 会删除目标卷中的空 AOF，只允许在 `DBSIZE` 已确认是 `0` 时执行。然后导入 RDB：

```bash
docker run --rm \
  -v ygh-redis-data:/data \
  -v /opt/ygh/redis-migration:/backup:ro,Z \
  redis:8.4.4 \
  sh -c 'cp /backup/dump.rdb /data/dump.rdb && chown redis:redis /data/dump.rdb'
```

然后重新执行“第十九步”的完整 `docker run` 命令启动 `ygh-redis`。

### 25.6 验证迁移结果

```bash
read -s -p "请输入新 Redis 密码: " REDIS_PASSWORD
echo
docker exec -e REDISCLI_AUTH="$REDIS_PASSWORD" ygh-redis redis-cli DBSIZE
docker exec -e REDISCLI_AUTH="$REDIS_PASSWORD" ygh-redis redis-cli INFO persistence
unset REDIS_PASSWORD
```

检查：

- `DBSIZE` 与旧 Redis 的 Key 数量是否符合预期。
- `loading:0`。
- `rdb_last_bgsave_status:ok`。
- `aof_enabled:1`。

迁移后不要只看 Key 数量，还要让业务方验证登录会话、验证码、限流、缓存和幂等场景。Redis 不是订单、余额、库存或权限的最终事实库，这些事实数据应由 MySQL 保存。

## 第二十六步：日常启动、停止和查看状态

### 启动 Redis

```bash
docker start ygh-redis
```

### 停止 Redis

```bash
docker stop ygh-redis
```

### 重启 Redis

```bash
docker restart ygh-redis
```

### 查看状态

```bash
docker ps -a --filter name=^/ygh-redis$
docker stats --no-stream ygh-redis
docker logs --tail 100 ygh-redis
```

不要执行：

```bash
docker volume rm ygh-redis-data
```

删除数据卷会删除 Redis 持久化数据。

## 第二十七步：常见故障排查

### 27.1 DNF 提示无法解析 mirrors.rockylinux.org

依次执行：

```bash
ip route
ping -c 4 192.168.154.2
ping -c 4 223.5.5.5
getent hosts mirrors.rockylinux.org
```

- 网关不通：修复 VMware VMnet8 NAT 和虚拟机网卡。
- 网关能通、公网 IP 不通：检查 Windows `VMware NAT Service`。
- 公网 IP 能通、域名不通：修复 NetworkManager DNS。

### 27.2 Docker 拉取镜像超时

```bash
docker info
curl -I https://registry-1.docker.io/v2/
curl -I https://docker.m.daocloud.io/v2/
curl -I https://docker.1ms.run/v2/
```

Docker Hub 返回 `401 Unauthorized` 通常表示网络已经到达 Registry，只是未登录，不等于连接失败。

重新拉取项目固定镜像：

```bash
docker pull redis:8.4.4
```

不要因为某个镜像源失效就改成来源不明的 Redis 镜像。

### 27.3 容器启动后立即退出

```bash
docker ps -a --filter name=^/ygh-redis$
docker logs --tail 100 ygh-redis
```

重点检查：

- 配置文件是否挂载到 `/usr/local/etc/redis/redis.conf`。
- `daemonize` 是否为 `no`。
- 配置文件是否对容器中的 Redis 用户可读。
- `requirepass` 后面是否已经替换为真实密码。
- 6379 是否被其他程序占用。

### 27.4 Windows 端口测试失败

```bash
ss -lntp | grep ':6379'
firewall-cmd --list-rich-rules
docker port ygh-redis
```

`docker port ygh-redis` 应显示：

```text
6379/tcp -> 192.168.154.10:6379
```

### 27.5 IDEA 提示 WRONGPASS

重新在虚拟机中读取配置，但不要截图或复制到聊天中：

```bash
vi /opt/ygh/redis/conf/redis.conf
```

确认 `requirepass` 的值与 IDEA 运行配置中的 `YGH_REDIS_PASSWORD` 完全一致。修改配置后执行：

```bash
docker restart ygh-redis
```

### 27.6 Redis 提示 OOM command not allowed

这表示 Redis 已达到项目设置的 `96mb` 最大内存，`noeviction` 按预期拒绝新写入，没有静默删除安全 Key。

先检查：

```bash
read -s -p "请输入 Redis 密码: " REDIS_PASSWORD
echo
docker exec -e REDISCLI_AUTH="$REDIS_PASSWORD" ygh-redis redis-cli INFO memory
docker exec -e REDISCLI_AUTH="$REDIS_PASSWORD" ygh-redis redis-cli INFO keyspace
unset REDIS_PASSWORD
```

不要直接改成 `allkeys-lru`。先排查无 TTL Key、异常大 Key 和业务写入量，再根据虚拟机剩余内存评估是否调整容量。

## 第二十八步：最终验收

在 Rocky Linux 虚拟机中依次执行：

```bash
systemctl is-active docker
docker image inspect redis:8.4.4 --format '{{.RepoTags}}'
docker inspect ygh-redis --format '状态={{.State.Status}} 重启策略={{.HostConfig.RestartPolicy.Name}} 内存={{.HostConfig.Memory}}'
docker port ygh-redis
docker stats --no-stream ygh-redis
```

预期结果：

- Docker 为 `active`。
- 镜像为 `redis:8.4.4`。
- 容器状态为 `running`。
- 重启策略为 `unless-stopped`。
- 内存上限为 `134217728` 字节，即 128MiB。
- 端口为 `192.168.154.10:6379`。

再执行认证验证：

```bash
read -s -p "请输入 Redis 密码: " REDIS_PASSWORD
echo
docker exec -e REDISCLI_AUTH="$REDIS_PASSWORD" ygh-redis redis-cli PING
docker exec -e REDISCLI_AUTH="$REDIS_PASSWORD" ygh-redis redis-cli CONFIG GET maxmemory-policy
unset REDIS_PASSWORD
```

必须得到 `PONG` 和 `noeviction`。

最后在 Windows PowerShell 执行：

```powershell
Test-NetConnection 192.168.154.10 -Port 6379
```

必须得到 `TcpTestSucceeded : True`。完成这三层验证后，才可以在 IDEA 中启动依赖 Redis 的 Java 服务。

## 参考依据

- 项目部署配置：`ygh-deploy/constrained-dev/vm-compose.yml`
- 项目环境台账：`docs/development/环境配置台账.md`
- 项目 Redis 规范：`docs/development/Redis公共能力规范.md`
- Redis 8.4.4 官方源码包：<https://download.redis.io/releases/redis-8.4.4.tar.gz>
- Redis 官方源码编译文档：<https://redis.io/docs/latest/operate/oss_and_stack/install/archive/install-redis/install-redis-from-source/>
- Redis 官方配置说明：<https://redis.io/docs/latest/operate/oss_and_stack/management/config/>
- Docker 官方 CentOS 安装文档：<https://docs.docker.com/engine/install/centos/>
- Docker 官方镜像加速配置说明：<https://docs.docker.com/docker-hub/image-library/mirror/>
- Redis Docker 官方镜像：<https://hub.docker.com/_/redis>
