# 跨境智汇 AI 知识库系统：Docker 安装、Redis 配置与数据迁移步骤

> 本文适用于当前项目的资源受限开发环境：Windows 11 宿主机、VMware NAT 网络、Rocky Linux 10 虚拟机。
>
> 本文不使用批处理脚本、Shell 安装脚本、Docker Compose 或 `.env` 文件。所有组件均按步骤手动安装和配置。
>
> 当前项目固定使用 `redis:8.4.4`，禁止改成 `redis:latest`。项目中的 Redis 运行在 Rocky Linux 虚拟机的 Docker 中，不安装在 Windows、WSL 或 Windows Docker Desktop 中。

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

## 第三步：清理可能冲突的旧 Docker 软件包

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

## 第四步：安装 Docker 仓库管理工具

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

## 第五步：添加 Docker 软件仓库

### 在哪里操作

在 Rocky Linux 虚拟机中执行。

### 5.1 优先添加 Docker 官方 CentOS 仓库

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

### 5.2 官方仓库无法访问时使用阿里云仓库地址

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

## 第六步：安装并启动 Docker Engine

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

## 第七步：手动配置 Docker 镜像源和运行参数

### 在哪里配置

配置文件位于 Rocky Linux 虚拟机：

```text
/etc/docker/daemon.json
```

该文件配置的是虚拟机中的 Docker Engine，不影响 Windows Docker Desktop。

### 7.1 备份已有配置

先查看文件是否存在：

```bash
ls -l /etc/docker/daemon.json
```

如果文件存在，输入：

```bash
cp -a /etc/docker/daemon.json /etc/docker/daemon.json.bak
```

如果提示文件不存在，直接继续。

### 7.2 打开配置文件

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

### 7.3 验证 JSON 配置

```bash
dockerd --validate --config-file=/etc/docker/daemon.json
```

预期输出：

```text
configuration OK
```

如果不是 `configuration OK`，不要重启 Docker。重新执行 `vi /etc/docker/daemon.json`，检查英文双引号、逗号和大括号。

### 7.4 重启 Docker

```bash
systemctl daemon-reload
systemctl restart docker
systemctl status docker --no-pager
```

状态必须仍然是 `active (running)`。

如果 Docker 重启失败，并且第 7.1 步已经生成备份，执行以下命令回滚：

```bash
cp -a /etc/docker/daemon.json.bak /etc/docker/daemon.json
dockerd --validate --config-file=/etc/docker/daemon.json
systemctl restart docker
systemctl status docker --no-pager
```

只有验证输出 `configuration OK` 后才能重启。

### 7.5 验证镜像源和 Docker 参数

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

## 第八步：拉取项目固定版本的 Redis 镜像

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

## 第九步：创建 Redis 的项目目录、网络和数据卷

### 安装位置说明

本步骤全部在 Rocky Linux 虚拟机中执行：

- Redis 配置文件：`/opt/ygh/redis/conf/redis.conf`
- Redis 容器：虚拟机 Docker 中的 `ygh-redis`
- Redis 数据卷：`ygh-redis-data`
- 数据卷实际位置：`/var/lib/docker/volumes/ygh-redis-data/_data`
- Docker 网络：`ygh-core`

不要直接修改 `/var/lib/docker/volumes` 下面的文件，数据读写由 Docker 和 Redis 管理。

### 9.1 创建配置目录

```bash
mkdir -p /opt/ygh/redis/conf
```

### 9.2 创建 Docker 网络

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

### 9.3 创建数据卷

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

## 第十步：生成 Redis 密码并手动编写配置文件

### 在哪里配置

在 Rocky Linux 虚拟机中配置 `/opt/ygh/redis/conf/redis.conf`。

本文不使用 `.env`，密码由管理员手动生成后写入服务器上的 Redis 配置文件。真实密码不得写进项目代码、Git、Markdown、聊天记录或截图。

### 10.1 生成强密码

```bash
openssl rand -base64 24
```

命令会输出一行随机内容。立即将该值保存到客户自己的密码管理器，后面 IDEA 配置也要使用同一个值。

不要使用 `123456`、公司名称、手机号或文档中的示例文字作为密码。

### 10.2 打开 Redis 配置文件

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

### 10.3 确认没有遗留占位符

```bash
grep -n 'REPLACE_WITH' /opt/ygh/redis/conf/redis.conf
```

正确结果是不输出任何内容。如果仍然输出最后一行，说明密码没有替换，必须重新编辑。

### 10.4 设置配置文件权限

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

## 第十一步：手动启动项目 Redis 容器

### Redis 安装到哪里

Redis 不作为 Rocky Linux 系统软件安装。Redis 8.4.4 运行在虚拟机 Docker 的 `ygh-redis` 容器中，配置文件和数据分别挂载到容器内部：

- `/opt/ygh/redis/conf/redis.conf` → `/usr/local/etc/redis/redis.conf`
- `ygh-redis-data` → `/data`

### 11.1 确认端口没有被占用

```bash
ss -lntp | grep ':6379'
```

正确结果是不输出任何内容。如果已经有源码版 Redis 或其他容器占用 6379，先按本文“第十七步”完成迁移和停机，不要直接启动第二个 Redis。

### 11.2 确认没有同名容器

```bash
docker ps -a --filter name=^/ygh-redis$
```

如果没有输出容器记录，继续执行启动命令。

如果已经存在 `ygh-redis`，先执行：

```bash
docker inspect ygh-redis --format '状态={{.State.Status}} 镜像={{.Config.Image}}'
```

确认它是不是本项目已有容器。不要直接删除来源不明的容器。

### 11.3 启动容器

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

## 第十二步：在虚拟机内验证 Redis

### 12.1 验证未认证访问会被拒绝

```bash
docker exec ygh-redis redis-cli PING
```

预期结果：

```text
NOAUTH Authentication required.
```

这说明密码认证已经生效。

### 12.2 不在命令历史中明文输入密码

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

### 12.3 检查项目关键参数

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

## 第十三步：配置 Rocky Linux 防火墙

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

## 第十四步：从 Windows 验证 Redis 端口

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

## 第十五步：在 IDEA 中配置项目连接 Redis

### Redis 和 Java 项目分别运行在哪里

- Redis：Rocky Linux 虚拟机里的 Docker 容器，地址 `192.168.154.10:6379`。
- Java 服务：Windows 本机的 IntelliJ IDEA。
- WSL：本步骤不使用。
- Windows Docker Desktop：本步骤不使用。

项目代码不需要“拉取到 Redis”或“上传到 Redis”。IDEA 启动 Java 服务后，Java 服务通过 IP、端口和密码连接虚拟机中的 Redis。

### 15.1 打开 IDEA 运行配置

1. 打开 IntelliJ IDEA 和客户解压后的项目目录。
2. 点击右上角当前运行配置名称。
3. 点击 `Edit Configurations...`。
4. 在左侧选择要启动的 Spring Boot 服务，例如 `ygh-gateway`、`ygh-auth-service` 或 `ygh-product-service`。
5. 找到 `Environment variables`。
6. 点击输入框右侧的编辑按钮。

### 15.2 添加 Redis 环境变量

逐项添加：

```text
YGH_REDIS_HOST=192.168.154.10
YGH_REDIS_PORT=6379
YGH_REDIS_PASSWORD=这里填写第十步生成的真实Redis密码
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

### 15.3 项目代码对应关系

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

## 第十六步：验证 IDEA 启动后的项目连接

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

## 第十七步：已有源码版 Redis 时的数据迁移

新客户首次部署没有旧 Redis 数据时，跳过本步骤。项目代码压缩包不包含 Redis 运行数据，Redis 数据也不会随着代码自动导入。

只有旧机器已经运行 Redis、并且明确需要保留旧缓存或短期状态时，才进行迁移。

### 17.1 先检查源 Redis 和目标 Redis 版本

在旧 Redis 所在的 Linux 机器执行：

```bash
/usr/local/redis/bin/redis-server --version
```

目标版本固定为：

```text
Redis 8.4.4
```

如果旧 Redis 是原稿中的 `8.6.1`，不要把它的 RDB 文件直接导入项目的 `8.4.4` 容器。`8.6.1 → 8.4.4` 属于降级迁移，RDB/AOF 向旧版本兼容不能默认保证。

出现这种情况时有两个选择：

1. 新客户环境本来就不需要旧缓存：不迁移数据，直接使用空的 `redis:8.4.4`。
2. 必须保留旧数据：先单独制定兼容性验证方案，确认项目能否整体升级到 `redis:8.6.1`，通过测试后再修改部署基线。未经验证不要改项目镜像版本。

只有源 Redis 版本不高于 `8.4.4`，并完成备份后，才继续下面的 RDB 迁移。

### 17.2 在旧 Redis 上生成 RDB

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

### 17.3 停止旧 Redis，避免迁移过程中继续写入

如果旧 Redis 由 systemd 管理：

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

### 17.4 将 RDB 文件上传到新虚拟机

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

### 17.5 将 RDB 导入尚未使用的项目数据卷

本操作要求 `ygh-redis-data` 是新建空卷。如果目标 Redis 已经产生业务数据，先备份，不能直接覆盖。

停止并删除目标容器，但保留数据卷：

```bash
docker stop ygh-redis
docker rm ygh-redis
```

检查数据卷内容：

```bash
docker run --rm -v ygh-redis-data:/data redis:8.4.4 find /data -maxdepth 2 -type f -printf '%p\n'
```

如果已经存在 `appendonlydir`、`dump.rdb` 或其他业务数据，先停止操作并备份，不要覆盖。

确认是空卷后，导入 RDB：

```bash
docker run --rm \
  -v ygh-redis-data:/data \
  -v /opt/ygh/redis-migration:/backup:ro,Z \
  redis:8.4.4 \
  sh -c 'cp /backup/dump.rdb /data/dump.rdb && chown redis:redis /data/dump.rdb'
```

然后重新执行“第十一步”的完整 `docker run` 命令启动 `ygh-redis`。

### 17.6 验证迁移结果

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

## 第十八步：日常启动、停止和查看状态

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

## 第十九步：常见故障排查

### 19.1 DNF 提示无法解析 mirrors.rockylinux.org

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

### 19.2 Docker 拉取镜像超时

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

### 19.3 容器启动后立即退出

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

### 19.4 Windows 端口测试失败

```bash
ss -lntp | grep ':6379'
firewall-cmd --list-rich-rules
docker port ygh-redis
```

`docker port ygh-redis` 应显示：

```text
6379/tcp -> 192.168.154.10:6379
```

### 19.5 IDEA 提示 WRONGPASS

重新在虚拟机中读取配置，但不要截图或复制到聊天中：

```bash
vi /opt/ygh/redis/conf/redis.conf
```

确认 `requirepass` 的值与 IDEA 运行配置中的 `YGH_REDIS_PASSWORD` 完全一致。修改配置后执行：

```bash
docker restart ygh-redis
```

### 19.6 Redis 提示 OOM command not allowed

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

## 第二十步：最终验收

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
- Docker 官方 CentOS 安装文档：<https://docs.docker.com/engine/install/centos/>
- Docker 官方镜像加速配置说明：<https://docs.docker.com/docker-hub/image-library/mirror/>
- Redis Docker 官方镜像：<https://hub.docker.com/_/redis>
