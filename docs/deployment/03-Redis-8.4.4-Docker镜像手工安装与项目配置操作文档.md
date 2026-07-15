# Redis 8.4.4 Docker 镜像手工安装与项目配置操作文档

按 `00` 总教程执行时，Docker Engine 已由 `01` 号虚拟机指南安装并验证，因此先执行第一部分第一步确认位置，然后直接从第二部分开始；第一部分其余 Docker 安装步骤只用于单独拿到本文、且虚拟机确实没有 Docker 的情况，不能重复卸载已经正常运行的 Docker。

## 第一部分：在 Rocky Linux 虚拟机中手动安装 Docker

### 第一步：确认命令运行位置和虚拟机网络

**在哪里运行**：通过 SSH 登录 `192.168.154.10` 后，在 Rocky Linux 虚拟机终端运行。不要在 Windows PowerShell、WSL 或 Windows Docker Desktop 中执行本部分命令。

在 Windows PowerShell 输入：

```powershell
ssh root@192.168.154.10
```

如果实际 SSH 用户不是 `root`，把 `root` 修改为实际用户名。登录成功后，终端提示符会变成类似 `[root@localhost ~]#`。

在虚拟机终端依次输入：

```bash
ip -br address
ip route
ping -c 4 192.168.154.2
ping -c 4 223.5.5.5
getent hosts download.docker.com
getent hosts registry-1.docker.io
```

**执行结果及原因**：

- `ip -br address` 应显示虚拟机网卡具有 `192.168.154.10/24`。
- `ip route` 应显示默认网关，例如 `default via 192.168.154.2`。
- 能 ping 通 `192.168.154.2`，说明虚拟机能够到达 VMware NAT 网关。
- 能 ping 通 `223.5.5.5`，说明虚拟机能够访问公网 IP。
- `getent hosts` 能返回 IP，说明 DNS 可以解析域名。

**注意事项**：如果公网 IP 不通，先修复 VMware NAT、虚拟机网关或宿主机防火墙；如果公网 IP 能通但域名无法解析，先修复虚拟机 DNS。网络没有恢复前不要继续安装 Docker，因为 `dnf` 和 `docker pull` 都需要网络。

### 第二步：检查并清理冲突软件

**在哪里运行**：Rocky Linux 虚拟机 SSH 终端。

先检查是否存在 Podman 容器：

```bash
sudo podman ps -a
```

如果提示 `podman: command not found`，说明没有安装 Podman，可以继续。如果列表中存在客户正在使用的容器，先停止操作并备份这些容器，不能直接卸载 Podman。

确认没有需要保留的 Podman 容器后输入：

```bash
sudo dnf remove -y podman buildah runc docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine
```

**执行结果及原因**：命令最后应显示事务完成。出现 `No packages marked for removal` 表示这些冲突包原本不存在，不是错误。

**注意事项**：本命令只清理可能与 Docker CE 冲突的软件包，不要手动删除 `/var/lib/docker`、`/var/lib/containerd` 或客户已有数据目录。

### 第三步：添加 Docker CE 下载源

**在哪里运行**：Rocky Linux 虚拟机 SSH 终端。

Docker 官方安装说明位于：`https://docs.docker.com/engine/install/centos/`。Rocky Linux 10 使用 Docker 的 CentOS 兼容 RPM 仓库安装 Docker Engine。

先安装仓库管理工具：

```bash
sudo dnf install -y dnf-plugins-core curl ca-certificates yum-utils
```

优先添加 Docker 官方软件源：

```bash
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf makecache
```

**执行结果及原因**：`dnf makecache` 应成功下载仓库元数据，不能出现 `Could not resolve host`、`Connection timed out` 或 metadata 下载失败。

如果客户网络无法访问 `download.docker.com`，删除刚才未完成的仓库文件，再改用阿里云 Docker CE 兼容软件源：

```bash
sudo rm -f /etc/yum.repos.d/docker-ce.repo
sudo dnf config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
sudo dnf makecache
```

**哪些内容需要修改**：官方源和阿里云源二选一，不要同时创建两份名称相同的 `docker-ce.repo`。如果公司有内部 RPM 仓库，应填写公司提供的仓库地址。

**手动浏览器下载方式**：如果虚拟机完全不能访问软件仓库，在一台可以联网的电脑上打开 `https://download.docker.com/linux/centos/`，依次进入对应系统版本、`x86_64`、`stable`、`Packages`，下载 Docker CE、Docker CLI、containerd 和 Buildx 的 RPM 文件，再通过 WinSCP 上传到虚拟机 `/opt/docker-rpms`，最后在该目录执行 `sudo dnf install ./*.rpm`。RPM 之间存在依赖，缺少任何依赖时 `dnf` 会明确报出包名，必须补齐后再安装，不使用一键安装脚本。

### 第四步：安装 Docker Engine

**在哪里运行**：Rocky Linux 虚拟机 SSH 终端。

输入：

```bash
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin
```

**安装位置**：

- Docker 命令：`/usr/bin/docker`。
- Docker 服务：`docker.service`，由 systemd 管理。
- Docker 配置文件：`/etc/docker/daemon.json`。
- Docker 镜像和容器数据：通常位于 `/var/lib/docker`；Docker Engine 29 新安装使用 containerd image store 时，部分镜像内容位于 `/var/lib/containerd`。

**执行结果及原因**：安装事务最后应显示 `Complete!`，不能出现依赖冲突或 GPG 校验失败。Docker 官方仓库首次安装时如果要求确认 GPG Key，应核对官方文档公布的指纹后接受。

**注意事项**：这里安装的是 Rocky Linux 虚拟机内部的 Docker Engine，不是 Windows Docker Desktop。Redis 最终运行在这个 Docker Engine 创建的容器中。

### 第五步：现场检测 Docker Hub 和镜像代理

**在哪里运行**：Rocky Linux 虚拟机 SSH 终端。

先确认虚拟机和 Docker 服务没有配置代理：

```bash
env | grep -Ei '^(http|https|all|no)_proxy='
systemctl show docker --property=Environment --no-pager
docker info --format 'HTTP={{.HTTPProxy}} HTTPS={{.HTTPSProxy}} NOPROXY={{.NoProxy}}'
```

三条命令均不得出现 HTTP、HTTPS 或 SOCKS 代理地址。然后逐个执行下面六条 `/v2/` 检查命令；`--noproxy '*'` 用于强制 curl 不读取任何代理设置。每执行一条就记录 HTTP 状态，再执行下一条，禁止写循环批量检测：

```bash
curl --noproxy '*' --connect-timeout 5 --max-time 10 -sS -o /dev/null -w 'docker.1ms.run HTTP=%{http_code} CONNECT=%{time_connect}s TLS=%{time_appconnect}s TOTAL=%{time_total}s IP=%{remote_ip}\n' 'https://docker.1ms.run/v2/'
curl --noproxy '*' --connect-timeout 5 --max-time 10 -sS -o /dev/null -w 'docker.m.daocloud.io HTTP=%{http_code} CONNECT=%{time_connect}s TLS=%{time_appconnect}s TOTAL=%{time_total}s IP=%{remote_ip}\n' 'https://docker.m.daocloud.io/v2/'
curl --noproxy '*' --connect-timeout 5 --max-time 10 -sS -o /dev/null -w 'docker.1panel.live HTTP=%{http_code} CONNECT=%{time_connect}s TLS=%{time_appconnect}s TOTAL=%{time_total}s IP=%{remote_ip}\n' 'https://docker.1panel.live/v2/'
curl --noproxy '*' --connect-timeout 5 --max-time 10 -sS -o /dev/null -w 'docker.xuanyuan.me HTTP=%{http_code} CONNECT=%{time_connect}s TLS=%{time_appconnect}s TOTAL=%{time_total}s IP=%{remote_ip}\n' 'https://docker.xuanyuan.me/v2/'
curl --noproxy '*' --connect-timeout 5 --max-time 10 -sS -o /dev/null -w 'dockerproxy.com HTTP=%{http_code} CONNECT=%{time_connect}s TLS=%{time_appconnect}s TOTAL=%{time_total}s IP=%{remote_ip}\n' 'https://dockerproxy.com/v2/'
curl --noproxy '*' --connect-timeout 5 --max-time 10 -sS -o /dev/null -w 'dockerpull.com HTTP=%{http_code} CONNECT=%{time_connect}s TLS=%{time_appconnect}s TOTAL=%{time_total}s IP=%{remote_ip}\n' 'https://dockerpull.com/v2/'
```

`/v2/` 可达不代表镜像一定能拉取。对状态为 `200` 或 `401` 的地址，分别执行 Alpine 和 Nginx 的真实拉取。下面每一行都是独立命令；某个地址两条都成功后即可记录为当前可用源，不需要继续拉取其他地址：

```bash
timeout 45s docker pull --platform linux/amd64 docker.1ms.run/library/alpine:3.20
timeout 45s docker pull --platform linux/amd64 docker.1ms.run/library/nginx:alpine
timeout 45s docker pull --platform linux/amd64 docker.m.daocloud.io/library/alpine:3.20
timeout 45s docker pull --platform linux/amd64 docker.m.daocloud.io/library/nginx:alpine
timeout 45s docker pull --platform linux/amd64 docker.1panel.live/library/alpine:3.20
timeout 45s docker pull --platform linux/amd64 docker.1panel.live/library/nginx:alpine
timeout 45s docker pull --platform linux/amd64 docker.xuanyuan.me/library/alpine:3.20
timeout 45s docker pull --platform linux/amd64 docker.xuanyuan.me/library/nginx:alpine
timeout 45s docker pull --platform linux/amd64 dockerproxy.com/library/alpine:3.20
timeout 45s docker pull --platform linux/amd64 dockerproxy.com/library/nginx:alpine
timeout 45s docker pull --platform linux/amd64 dockerpull.com/library/alpine:3.20
timeout 45s docker pull --platform linux/amd64 dockerpull.com/library/nginx:alpine
```

**如何判断结果**：

- `200`：Registry 可以直接访问。
- `401`：Registry 可以访问，只是 `/v2/` 接口要求继续按镜像仓库协议鉴权；这是正常的可用结果。
- `403`：服务可达，但当前 IP、区域或访问方式被拒绝，不能作为当前客户的可用源。
- `429`：服务可达，但当前被限流，等待后重试或换源。
- `404`：该地址不是可用的 Registry `/v2/` 接口。
- `500`、`502`、`503`、`504`：代理服务端故障，暂时不可用。
- 显示 `000`、`Could not resolve host` 或连接超时：当前客户网络无法使用该源。

**2026-07-14 无 VPN、无代理真实检查结果**：

下表是早期隔离验证环境的实测记录，只用于说明判断方法，不是客户现场的配置结论。客户必须以上面六组逐条命令的当前输出为准；不能因为表中某个地址曾经成功，就跳过现场检测或直接写入 Docker 配置。Windows Docker Desktop 自带的内部转发结果不计入虚拟机 Docker Engine 的可用性判断。

| 排名 | 地址 | `/v2/` 直连 | Alpine 3.20 | Nginx Alpine | Redis 8.4.4 | 本次结论 |
|---:|---|---|---|---|---|---|
| 1 | `https://docker.m.daocloud.io` | `401`，2.31 秒 | 成功，9.40 秒（层已缓存） | 成功，9.69 秒（层已缓存） | 成功，9.44 秒（层已缓存） | 默认首选；标准名称 `redis:8.4.4` 已通过该配置拉取 |
| 2 | `https://docker.1panel.live` | `200`，4.67 秒 | 成功，11.78 秒（层已缓存） | 成功，10.05 秒（层已缓存） | 成功，15.17 秒（层已缓存） | 虚拟机可用；不同出口曾出现 403，必须现场复测 |
| 3 | `https://docker.1ms.run` | `401`，2.41 秒 | 成功，22.59 秒 | 成功，26.04 秒 | 最终成功，103.19 秒；此前两次 60 秒门限超时 | 可用但大镜像偏慢，只作为后备 |
| 4 | `https://docker.xuanyuan.me` | `401`，3.29 秒 | 成功，12.44 秒（层已缓存） | 成功，12.57 秒（层已缓存） | 成功，13.12 秒（层已缓存） | 虚拟机可用；其他出口曾出现 429，暂不放入默认配置 |
| 5 | `https://dockerproxy.com` | 5 秒连接超时 | 约 15 秒后失败 | 约 15 秒后失败 | 未继续测试 | 当前无代理网络不可用，不配置 |
| 6 | `https://dockerpull.com` | 5 秒连接超时 | 约 15 秒后失败 | 约 15 秒后失败 | 未继续测试 | 当前无代理网络不可用，不配置 |

测试顺序为 1ms、DaoCloud、1Panel、轩辕。1ms 是本轮第一个下载实际镜像层的站点，后续站点可能复用 Docker 内容存储中的相同层，因此表中后续拉取耗时只能证明请求在门限内完成，不能用于比较完整下载带宽。

Redis 复核并不只检查“拉取成功”：四个可用站的镜像均为 `linux/amd64`，实际执行 `redis-server --version` 均返回 `Redis server v=8.4.4`。标准命令 `docker pull redis:8.4.4` 也在 12.98 秒内成功，并由当前首选代理返回有效镜像。但 DaoCloud 返回的镜像创建于 2026-06-24，摘要为 `sha256:ac5c39529eb8b3e41318154581dad015b1f414e63d532f9318d25409a47f8451`；另外三个站返回的镜像创建于 2026-07-14，摘要为 `sha256:ed6718f2e830bb226f85e7323ede7d6e79bc4ece58c0024784b2ffef8fcc8a84`。这说明同一版本标签可能被上游重建或镜像站同步时间不同。正式交付必须记录并锁定验收通过的摘要，不能只依赖可变标签。

**注意事项**：镜像站可用性取决于客户出口 IP、时间、CDN 节点和服务方策略。客户部署当天必须重新执行 `/v2/` 与真实 `docker pull` 两组检查。不要把来源不明、没有 HTTPS、要求关闭证书校验或本次真实拉取失败的地址加入 Docker。

### 第六步：手动配置 Docker 镜像代理

**在哪里运行**：Rocky Linux 虚拟机 SSH 终端。

创建配置目录并备份原配置：

```bash
sudo mkdir -p /etc/docker
date '+%Y%m%d-%H%M%S'
sudo cp -a /etc/docker/daemon.json /etc/docker/daemon.json.bak-20260715-143000
```

第三条命令中的 `20260715-143000` 是示例，必须改成第二条命令实际显示的时间。如果第三条提示文件不存在，说明这是第一次配置，可以忽略该提示。输入：

```bash
sudo vim /etc/docker/daemon.json
```

打开文件后按 `i` 进入编辑模式，输入：

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
    "https://docker.1panel.live",
    "https://docker.1ms.run"
  ],
  "default-address-pools": [
    { "base": "172.30.0.0/16", "size": 24 }
  ]
}
```

输入完成后按 `Esc`，输入 `:wq` 并按回车保存。继续输入：

```bash
sudo cat /etc/docker/daemon.json
sudo dockerd --validate --config-file=/etc/docker/daemon.json
```

**执行结果及原因**：第一条命令应完整显示刚才填写的 JSON；第二条命令应输出 `configuration OK` 或不显示错误。如果提示 JSON 语法错误，重新打开文件检查双引号、逗号和括号，不能带着错误配置启动 Docker。

**哪些内容需要修改**：如果客户有企业内部镜像仓库，用企业提供的 HTTPS 地址替换 `registry-mirrors`。不修改日志轮转、`live-restore`、存储驱动和地址池，除非客户网络管理员确认 `172.30.0.0/16` 与内部网段冲突。

### 第七步：启动 Docker 并设置开机启动

**在哪里运行**：Rocky Linux 虚拟机 SSH 终端。

输入：

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now docker
sudo systemctl is-enabled docker
sudo systemctl is-active docker
```

**执行结果及原因**：后两条命令应分别输出 `enabled` 和 `active`。`enabled` 表示虚拟机开机时自动启动 Docker，`active` 表示 Docker 当前正在运行。

验证版本和镜像代理：

```bash
sudo docker version
sudo docker info | sed -n '/Registry Mirrors/,+5p'
```

`docker version` 必须同时显示 Client 和 Server；镜像代理列表必须显示 DaoCloud、1Panel 和 1ms 地址。如果只有 Client 没有 Server，执行 `sudo journalctl -u docker -n 200 --no-pager` 查看 Docker 启动错误。

## 第二部分：手动拉取 Redis 8.4.4 镜像

### 第一步：从项目固定镜像名拉取 Redis

**在哪里运行**：Rocky Linux 虚拟机 SSH 终端。

输入：

```bash
sudo docker pull redis:8.4.4
```

**正常输出示例**：

```text
8.4.4: Pulling from library/redis
...
Digest: sha256:...
Status: Downloaded newer image for redis:8.4.4
docker.io/library/redis:8.4.4
```

如果本机已有完全相同的镜像，状态可能是 `Image is up to date for redis:8.4.4`，也属于正常结果。Docker 会先尝试 Docker Hub，并按 `/etc/docker/daemon.json` 中的顺序使用镜像代理。

**为什么必须使用这个命令**：项目固定版本是 Redis 8.4.4。`redis:latest` 会随时间变化，客户重新部署时可能得到不同版本，不能用于交付。

### 第二步：官方名称拉取失败时直接从代理拉取

**在哪里运行**：Rocky Linux 虚拟机 SSH 终端。

先查看失败原因：

```bash
sudo journalctl -u docker -n 100 --no-pager
```

如果 `docker pull redis:8.4.4` 因 Docker Hub 网络超时失败，可以从下面两种方式中选择一种，不需要两种都执行。

方式一，DaoCloud：

```bash
sudo docker pull docker.m.daocloud.io/library/redis:8.4.4
sudo docker tag docker.m.daocloud.io/library/redis:8.4.4 redis:8.4.4
```

方式二，1ms：

```bash
sudo docker pull docker.1ms.run/library/redis:8.4.4
sudo docker tag docker.1ms.run/library/redis:8.4.4 redis:8.4.4
```

**执行结果及原因**：第一条命令下载代理中的 Redis 8.4.4；第二条命令在本机增加标准标签 `redis:8.4.4`，确保后面的启动命令不依赖具体代理域名。

**注意事项**：只有第五步现场检测为 `200` 或 `401` 的代理才能使用。出现 `403`、`429`、`5xx` 或连接失败时，不要连续高频重试，改用另一个已验证代理或第四部分的离线镜像方式。

### 第三步：检查镜像版本、架构和标签

**在哪里运行**：Rocky Linux 虚拟机 SSH 终端。

输入：

```bash
sudo docker image inspect redis:8.4.4 --format 'ID={{.Id}} ARCH={{.Architecture}} OS={{.Os}} TAGS={{json .RepoTags}}'
sudo docker image inspect redis:8.4.4 --format 'DIGESTS={{json .RepoDigests}}'
sudo docker run --rm redis:8.4.4 redis-server --version
```

**执行结果及原因**：

- 架构应为 `amd64`，操作系统应为 `linux`。
- 标签中必须有 `redis:8.4.4`。
- 项目在 2026-07-11 锁定的多架构标签摘要是 `sha256:ac5c39529eb8b3e41318154581dad015b1f414e63d532f9318d25409a47f8451`，Linux amd64 平台摘要是 `sha256:c17daa76f4f44878637398c9d1b0a1f3c1d30d45a804c5bcdefa4f89e48b6f3b`。`RepoDigests` 通常显示前一个标签摘要；通过代理拉取时仓库名前缀可能不同，但摘要部分应与项目锁定记录一致。
- Redis 版本命令必须显示 `v=8.4.4`。
- `--rm` 表示版本检查完成后自动删除临时容器，不会删除 Redis 镜像。

如果版本不是 8.4.4，执行 `sudo docker image rm 错误镜像标签` 删除错误标签，然后重新拉取正确版本。不要删除客户已有的其他镜像。

## 第三部分：手动创建 Redis 配置并启动项目所需容器

### 第一步：理解“拉取完成后如何导入项目”

**在哪里操作**：本步骤是操作说明，后续命令仍在 Rocky Linux 虚拟机 SSH 终端执行。

Redis 镜像拉取完成后，**不需要把 Java 项目源码导入 Redis 镜像或 Redis 容器**。本项目的正确连接关系是：

```text
Windows 本机 IntelliJ IDEA 中的 Java 服务
        ↓ 连接 192.168.154.10:6379
Rocky Linux 虚拟机
        ↓
Docker 容器 ygh-redis（redis:8.4.4）
```

所谓“让 Redis 适配项目”，实际需要完成三件事：手工创建项目要求的 `redis.conf`、用该配置启动 `ygh-redis` 容器、在 IDEA 中填写 Redis 连接变量。

### 第二步：创建 Redis 配置和数据目录

**在哪里运行**：Rocky Linux 虚拟机 SSH 终端。

输入：

```bash
sudo mkdir -p /opt/docker_redis/conf
sudo mkdir -p /opt/docker_redis/data
sudo ls -ld /opt/docker_redis /opt/docker_redis/conf /opt/docker_redis/data
```

**执行结果及原因**：应显示三个目录。配置文件放在 `/opt/docker_redis/conf`，RDB 和 AOF 数据保存在 `/opt/docker_redis/data`。这些目录位于虚拟机宿主系统，通过 Docker 挂载进入容器。

**注意事项**：不要把配置和数据放到 Windows、WSL 或 Java 项目源码目录。后续备份 Redis 时备份 `/opt/docker_redis`。

### 第三步：生成 Redis 密码

**在哪里运行**：Rocky Linux 虚拟机 SSH 终端。

输入：

```bash
openssl rand -base64 24
```

**执行结果及原因**：命令输出一串随机字符。把它保存到客户自己的密码管理器，后面编辑 `redis.conf` 和 IDEA 配置时使用同一个密码。

**注意事项**：不要使用 `123456`、公司名称或项目名称；不要把真实密码写入本文、Git、截图或聊天记录。

### 第四步：逐项编写 Redis 配置文件

**在哪里运行**：Rocky Linux 虚拟机 SSH 终端。

输入：

```bash
sudo vim /opt/docker_redis/conf/redis.conf
```

打开文件后按 `i` 进入编辑模式，逐行输入下面内容。最后一行必须把占位符替换成第三步生成的真实密码：

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
dir /data
dbfilename dump.rdb
appendonly yes
appendfilename "appendonly.aof"
appenddirname "appendonlydir"
appendfsync everysec
maxmemory 96mb
maxmemory-policy noeviction
requirepass CHANGE_TO_STRONG_PASSWORD
```

输入完成后按 `Esc`，输入 `:wq` 并按回车保存。检查时不要输出含密码的完整文件，输入：

```bash
sudo grep -E '^(bind|protected-mode|port|daemonize|logfile|dir|appendonly|appendfsync|maxmemory|maxmemory-policy)' /opt/docker_redis/conf/redis.conf
sudo grep '^requirepass .' /opt/docker_redis/conf/redis.conf
```

**执行结果及原因**：最后一条命令应输出一行以 `requirepass` 开头的配置。不要把这一行截图或发给他人，因为其中包含 Redis 真实密码。

**执行结果及原因**：第一条命令显示项目要求的配置值；第二条只显示 `Redis 密码已配置`，不会把真实密码打印到终端。

**配置原因**：

- `bind 0.0.0.0`：允许容器通过发布端口接收连接。
- `protected-mode yes` 和 `requirepass`：保持保护模式并启用认证。
- `daemonize no`：Docker 容器要求 Redis 在前台运行，否则容器会立即退出。
- `dir /data`：把持久化文件写入挂载的数据目录。
- `appendonly yes`、`appendfsync everysec`：启用 AOF 并每秒刷盘。
- `maxmemory 96mb`：匹配项目低内存虚拟机方案。
- `maxmemory-policy noeviction`：内存用满时明确写入失败，不静默删除会话和安全状态。

### 第五步：设置目录权限

**在哪里运行**：Rocky Linux 虚拟机 SSH 终端。

先确认官方镜像中的 Redis 用户 UID：

```bash
sudo docker run --rm redis:8.4.4 id redis
```

正常应显示类似 `uid=999(redis) gid=999(redis)`。然后输入：

```bash
sudo chown root:999 /opt/docker_redis/conf/redis.conf
sudo chmod 640 /opt/docker_redis/conf/redis.conf
sudo chown -R 999:999 /opt/docker_redis/data
sudo chmod 750 /opt/docker_redis /opt/docker_redis/conf /opt/docker_redis/data
sudo ls -l /opt/docker_redis/conf/redis.conf
```

**执行结果及原因**：配置文件应由 `root` 管理、Redis 组可读；数据目录由容器内 Redis 用户读写。不能使用 `chmod 777`，因为配置文件包含密码。

**哪些内容需要修改**：如果 `id redis` 显示的 UID/GID 不是 `999:999`，把 `chown` 命令中的 `999` 替换为实际值。

### 第六步：确认 6379 没有被其他 Redis 占用

**在哪里运行**：Rocky Linux 虚拟机 SSH 终端。

输入：

```bash
sudo ss -lntp | grep ':6379'
sudo docker ps -a --filter name=ygh-redis
```

**执行结果及原因**：第一条没有输出表示 6379 端口空闲；第二条没有输出表示不存在同名容器。任何一条出现内容都必须先确认旧进程或旧容器的数据归属。

如果源码版 Redis 占用端口，先用其真实密码停止：

```bash
/usr/local/redis/bin/redis-cli -a CHANGE_TO_STRONG_PASSWORD shutdown
```

如果存在以前创建但不再需要的 `ygh-redis` 容器，先确认数据已经备份，再输入 `sudo docker rm ygh-redis`。不要使用 `docker rm -f` 跳过数据确认。

### 第七步：手动启动项目 Redis 容器

**在哪里运行**：Rocky Linux 虚拟机 SSH 终端。

输入以下完整命令：

```bash
sudo docker run -d \
  --name ygh-redis \
  --network ygh-core \
  --cpus="0.20" \
  --memory="128m" \
  -p 192.168.154.10:6379:6379 \
  -e TZ=Asia/Shanghai \
  -v /opt/docker_redis/conf/redis.conf:/etc/redis/redis.conf:ro,Z \
  -v /opt/docker_redis/data:/data:Z \
  --health-cmd='redis-cli -a "$(sed -n "s/^requirepass //p" /etc/redis/redis.conf)" ping | grep -q PONG' \
  --health-interval=10s \
  --health-timeout=3s \
  --health-retries=10 \
  --log-driver=json-file \
  --log-opt=max-size=5m \
  --log-opt=max-file=3 \
  --restart unless-stopped \
  redis:8.4.4 \
  redis-server /etc/redis/redis.conf
```

**执行结果及原因**：Docker 输出一串容器 ID。`--network ygh-core` 与项目虚拟机组件网络一致；`-p` 把虚拟机固定 IP 的 6379 映射到容器；两个 `-v` 分别挂载配置和数据；`:Z` 让 SELinux 为挂载目录设置容器可访问标签；健康检查从只读配置中读取密码并执行 `PING`，不会把密码写入命令；日志限制为 5MB × 3；`unless-stopped` 让虚拟机重启后恢复容器。

**哪些内容需要修改**：如果客户虚拟机固定 IP 不是 `192.168.154.10`，只修改 `-p` 前面的宿主机 IP，并同步修改 IDEA 中的 `YGH_REDIS_HOST`。容器名、`ygh-core` 网络、镜像版本、CPU、内存、健康检查和容器内路径保持不变。

### 第八步：检查容器状态和 Redis 参数

**在哪里运行**：Rocky Linux 虚拟机 SSH 终端。

输入：

```bash
sudo docker ps --filter name=ygh-redis
sudo docker logs --tail 100 ygh-redis
sudo docker inspect ygh-redis --format 'Status={{.State.Status}} Restart={{.HostConfig.RestartPolicy.Name}} Memory={{.HostConfig.Memory}} NanoCPUs={{.HostConfig.NanoCpus}}'
```

**执行结果及原因**：容器状态必须是 `Up` 或 `running`，重启策略是 `unless-stopped`，内存字节数对应 128MB，CPU 对应 0.20 核。日志不能出现配置文件读取失败、权限不足或端口占用错误。

进入 Redis 客户端：

```bash
sudo docker exec -it ygh-redis redis-cli
```

在 `127.0.0.1:6379>` 提示符中逐条输入：

```text
AUTH CHANGE_TO_STRONG_PASSWORD
PING
INFO server
CONFIG GET maxmemory
CONFIG GET maxmemory-policy
CONFIG GET appendonly
CONFIG GET appendfsync
EXIT
```

把密码占位符替换成真实密码。`AUTH` 应返回 `OK`，`PING` 应返回 `PONG`，版本应为 8.4.4，策略应为 `noeviction`，AOF 应为 `yes`，刷盘方式应为 `everysec`。

### 第九步：配置虚拟机防火墙

**在哪里运行**：Rocky Linux 虚拟机 SSH 终端。

当前 VMware NAT 环境中，Windows 宿主机 VMnet8 地址为 `192.168.154.1`。只允许该地址访问 Redis：

```bash
sudo firewall-cmd --permanent --add-rich-rule='rule family=ipv4 source address=192.168.154.1/32 port port=6379 protocol=tcp accept'
sudo firewall-cmd --reload
sudo firewall-cmd --list-rich-rules
```

**执行结果及原因**：规则列表中应出现来源 `192.168.154.1/32` 和端口 6379。这样 Redis 不会向所有网络开放。

**哪些内容需要修改**：客户在 Windows PowerShell 执行 `ipconfig`，查看 VMware Network Adapter VMnet8 的 IPv4 地址。如果不是 `192.168.154.1`，替换防火墙规则中的来源地址。不要设置为 `0.0.0.0/0`。

### 第十步：从 Windows 检查 Redis 端口

**在哪里运行**：Windows 本机 PowerShell，不在 SSH 终端运行。

输入：

```powershell
Test-NetConnection 192.168.154.10 -Port 6379
```

**执行结果及原因**：应显示 `TcpTestSucceeded : True`，表示 Windows 可以访问虚拟机 Docker 发布的 Redis 端口。

如果为 `False`，依次检查虚拟机 IP、`docker ps`、`docker logs ygh-redis`、6379 端口映射和 firewalld 规则。不要把 Redis 改装到 Windows Docker Desktop 来绕过问题。

### 第十一步：在 IDEA 中把 Java 项目连接到 Redis

**执行时机**：首次按总教程部署时，完成第十步端口检查后先跳过本步骤。进入 `11-Windows-IDEA-14个Java服务手工配置与启动操作文档.md`，逐个创建 Gateway、Auth 和 Product 运行配置时，再按本步骤填写对应 Redis 变量。此处不能提前启动 Java 服务。

**在哪里操作**：Windows 本机 IntelliJ IDEA。

1. 使用 IDEA 打开客户解压后的项目根目录。
2. 点击 `Run` → `Edit Configurations...`。
3. 选择需要使用 Redis 的 Spring Boot 服务。
4. 找到 `Environment variables`，点击右侧编辑按钮。
5. 逐项添加：

```text
YGH_REDIS_HOST=192.168.154.10
YGH_REDIS_PORT=6379
YGH_REDIS_PASSWORD=这里填写Redis真实密码
YGH_REDIS_ENVIRONMENT=dev
```

`ygh-product-service` 另外添加：

```text
YGH_PRODUCT_REDIS_DATABASE=2
```

至少为 `ygh-gateway`、`ygh-auth-service` 和 `ygh-product-service` 配置 Redis 连接。密码必须和 `/opt/docker_redis/conf/redis.conf` 中的 `requirepass` 完全一致。

**执行结果及原因**：IDEA 启动日志中不能出现 `Connection refused`、`NOAUTH Authentication required`、`WRONGPASS` 或缺少 `YGH_REDIS_*` 变量。

### 第十二步：日常停止、启动、重启和查看日志

**在哪里运行**：Rocky Linux 虚拟机 SSH 终端。

```bash
sudo docker stop ygh-redis
sudo docker start ygh-redis
sudo docker restart ygh-redis
sudo docker logs --tail 200 ygh-redis
```

这些命令只管理容器，不删除 `/opt/docker_redis/data`。不要执行 `docker rm`、`docker system prune --volumes` 或删除 `/opt/docker_redis/data`，除非已经确认不需要数据并完成备份。

## 第四部分：虚拟机无法联网时手动上传 Redis 镜像

### 第一步：在可联网电脑下载并导出镜像

**在哪里运行**：已安装并启动 Docker Desktop 的 Windows 本机 PowerShell，或者其他能访问 Docker Hub 的电脑。

```powershell
docker pull redis:8.4.4
New-Item -ItemType Directory -Force 'D:\delivery-images'
docker save -o 'D:\delivery-images\redis-8.4.4.tar' redis:8.4.4
Get-FileHash 'D:\delivery-images\redis-8.4.4.tar' -Algorithm SHA256
```

**执行结果及原因**：生成 `D:\delivery-images\redis-8.4.4.tar` 和一串 SHA256。`docker save` 保存的是镜像全部层和标签，不是 Java 项目压缩包。

**哪些内容需要修改**：如果客户没有 D 盘，把路径改到空间充足的盘符。不要对 tar 文件再次解压。

### 第二步：使用 WinSCP 上传镜像包

**在哪里操作**：Windows 本机 WinSCP。

1. 打开 WinSCP，协议选择 `SFTP`。
2. 主机填写 `192.168.154.10`，端口填写 `22`。
3. 输入虚拟机实际 SSH 用户和密码并登录。
4. 左侧找到 `D:\delivery-images\redis-8.4.4.tar`。
5. 右侧进入 `/opt/images`；目录不存在时先新建。
6. 把 tar 文件上传到 `/opt/images/redis-8.4.4.tar`。

### 第三步：在虚拟机导入镜像

**在哪里运行**：Rocky Linux 虚拟机 SSH 终端。

```bash
sha256sum /opt/images/redis-8.4.4.tar
sudo docker load -i /opt/images/redis-8.4.4.tar
sudo docker image inspect redis:8.4.4 --format '{{json .RepoTags}}'
sudo docker run --rm redis:8.4.4 redis-server --version
```

**执行结果及原因**：Linux 的 SHA256 必须与 Windows 一致；`docker load` 应显示 `Loaded image: redis:8.4.4`；版本必须是 8.4.4。

**注意事项**：镜像导入完成后回到第三部分创建配置和启动容器。仍然不需要把 Java 项目源码复制进 Redis 容器。

## 第五部分：已有旧 Redis 数据时迁移 RDB

没有旧 Redis 数据的客户跳过本部分。只有虚拟机中已经运行过源码版或旧容器 Redis 时才执行。

### 第一步：记录旧 Redis 版本和键数量

**在哪里运行**：旧 Redis 所在的 Rocky Linux 虚拟机终端。

```bash
/usr/local/redis/bin/redis-server --version
/usr/local/redis/bin/redis-cli -a CHANGE_TO_STRONG_PASSWORD DBSIZE
```

记录版本和键数量。高版本 Redis 的 RDB 不能未经验证直接迁移到低版本；本项目目标版本是 8.4.4。

### 第二步：保存并复制 RDB

**在哪里运行**：旧 Redis 所在的 Rocky Linux 虚拟机终端。下面路径适用于本项目原有源码版 Redis；如果旧 Redis 的 `dir` 配置不是 `/usr/local/redis/dbcache`，先执行 `CONFIG GET dir`，再把复制命令中的源路径改成实际目录。

```bash
/usr/local/redis/bin/redis-cli -a CHANGE_TO_STRONG_PASSWORD SAVE
sudo mkdir -p /opt/redis-backup
sudo cp /usr/local/redis/dbcache/dump.rdb /opt/redis-backup/dump.rdb
sudo ls -lh /opt/redis-backup/dump.rdb
```

把密码占位符替换为旧 Redis 密码。必须看到非空的 `dump.rdb`。

### 第三步：停止旧 Redis并释放端口

**在哪里运行**：旧 Redis 所在的 Rocky Linux 虚拟机终端。

```bash
/usr/local/redis/bin/redis-cli -a CHANGE_TO_STRONG_PASSWORD shutdown
sudo ss -lntp | grep ':6379'
```

这条命令没有输出才表示 6379 端口已经释放，此时才能继续。旧 Redis 停止后不要再次启动。

### 第四步：把 RDB 放入项目数据目录

**在哪里运行**：准备运行 `ygh-redis` Docker 容器的 Rocky Linux 虚拟机终端。

```bash
sudo mkdir -p /opt/docker_redis/data
sudo cp /opt/redis-backup/dump.rdb /opt/docker_redis/data/dump.rdb
sudo chown -R 999:999 /opt/docker_redis/data
sudo chmod 750 /opt/docker_redis/data
```

然后按照第三部分创建 `redis.conf` 并启动 `ygh-redis`。Redis 容器首次启动时会从 `/data/dump.rdb` 加载旧数据，并继续使用 AOF 持久化。

### 第五步：核对迁移结果

**在哪里运行**：已经启动 `ygh-redis` 容器的 Rocky Linux 虚拟机终端。

```bash
sudo docker exec -it ygh-redis redis-cli
```

进入 Redis 后输入：

```text
AUTH CHANGE_TO_STRONG_PASSWORD
DBSIZE
INFO persistence
EXIT
```

迁移后的 `DBSIZE` 应与迁移前记录一致。若不一致，先停止 `ygh-redis` 并保留所有备份，不要反复覆盖数据文件。
