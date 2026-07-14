# 跨境智汇 AI 知识库系统 Redis 8.4.4 部署、配置与旧数据迁移操作文档

## 第一部分：按照本项目实际结构部署 Redis

### 第一步：在 Windows 本机确认项目部署文件

**在哪里操作**：Windows 本机 PowerShell。

Redis 不需要读取 Windows 上的 Java 源码，也不会“拉取项目”。客户收到完整项目压缩包并解压后，只需要把项目已经提供的部署目录复制到 Rocky Linux 虚拟机。先执行：

```powershell
Test-Path 'F:\跨境智汇AI知识库系统\ygh-deploy\constrained-dev\vm-compose.yml'
Test-Path 'F:\跨境智汇AI知识库系统\ygh-deploy\constrained-dev\.env.example'
```

**执行后的结果**：两条命令都应输出 `True`。

**需要修改的内容**：如果客户把项目解压到了其他盘符，只修改命令中的项目根路径。例如项目位于 `D:\跨境智汇AI知识库系统`，就把前面的 `F:` 改为 `D:`。不要修改 `vm-compose.yml` 里的 Redis 版本、端口、内存和数据卷名称。

### 第二步：把部署目录复制到 Rocky Linux 虚拟机

**在哪里操作**：Windows 本机 WinSCP。

1. 打开 WinSCP。
2. 文件协议选择 `SFTP`。
3. 主机名输入 `192.168.154.10`。
4. 端口输入 `22`。
5. 输入虚拟机实际 SSH 用户名和密码，点击“登录”。
6. WinSCP 左侧进入 Windows 项目目录 `F:\跨境智汇AI知识库系统\ygh-deploy\constrained-dev`。
7. WinSCP 右侧进入虚拟机目录 `/opt/ygh`。如果目录不存在，右键空白处选择“新建”→“目录”，依次创建 `ygh` 和 `constrained-dev`。
8. 把左侧 `constrained-dev` 目录中的全部文件复制到右侧 `/opt/ygh/constrained-dev`。

**执行后的结果**：虚拟机中必须存在 `/opt/ygh/constrained-dev/vm-compose.yml`、`/opt/ygh/constrained-dev/.env.example` 和 `/opt/ygh/constrained-dev/mysql` 目录。

**需要修改的内容**：只修改客户自己的 Windows 项目路径、SSH 用户名和密码。虚拟机部署目标目录固定使用 `/opt/ygh/constrained-dev`，后面的命令全部基于该目录。

### 第三步：通过 SSH 检查复制结果

**在哪里操作**：先在 Windows PowerShell 连接 SSH，随后命令运行在 Rocky Linux 虚拟机。

```powershell
ssh root@192.168.154.10
```

如果实际用户不是 `root`，把 `root` 改为实际用户名。登录成功后，提示符会变成类似 `[root@localhost ~]#`。继续输入：

```bash
cd /opt/ygh/constrained-dev
pwd
ls -la
ls -l vm-compose.yml .env.example
```

**执行后的结果**：

- `pwd` 输出 `/opt/ygh/constrained-dev`。
- `ls` 能看到 `vm-compose.yml`、`.env.example`、`mysql`、`postgres` 等项目部署文件。

**需要修改的内容**：如果提示目录不存在，说明第二步复制位置不正确。回到 WinSCP，把文件重新复制到 `/opt/ygh/constrained-dev`，不要继续执行后面的 Docker 命令。

### 第四步：确认 Docker 安装在虚拟机而不是 Windows Docker Desktop

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

```bash
docker version
docker compose version
sudo systemctl is-enabled docker
sudo systemctl is-active docker
```

**执行后的结果**：

- `docker version` 同时显示 Client 和 Server。
- `docker compose version` 显示 Docker Compose 版本。
- 后两条命令分别输出 `enabled` 和 `active`。

**需要修改的内容**：如果提示 `docker: command not found`，说明虚拟机还没有安装 Docker，先执行本文“第三部分：虚拟机没有 Docker 时的安装与镜像源配置”，安装完成后再回到本步骤。Windows Docker Desktop 只运行 RocketMQ、Seata 或 Elasticsearch，不承载本项目的 Redis。

检查镜像源配置：

```bash
sudo cat /etc/docker/daemon.json
docker info | sed -n '/Registry Mirrors/,+5p'
```

应能看到项目使用的镜像代理地址。修改 `/etc/docker/daemon.json` 后，必须依次执行：

```bash
sudo dockerd --validate --config-file=/etc/docker/daemon.json
sudo systemctl daemon-reload
sudo systemctl restart docker
```

### 第五步：手动配置项目环境文件中的 Redis 密码

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

本项目的 `vm-compose.yml` 使用 `${REDIS_PASSWORD}` 把密码传给 Redis 容器。`.env` 是 Docker Compose 的本地配置文件，不是启动脚本；项目当前的 Compose 文件要求使用它提供 MySQL、Redis、Nacos 等组件的密码。不能把真实密码直接写入 `vm-compose.yml`。

如果 `/opt/ygh/constrained-dev/.env` 已经由项目完整部署步骤创建，直接编辑它：

```bash
cd /opt/ygh/constrained-dev
sudo vi .env
```

找到下面这一行：

```text
REDIS_PASSWORD=change-me
```

把 `change-me` 修改为客户自己的强密码，例如先在终端生成候选密码：

```bash
openssl rand -base64 24
```

将输出内容保存到客户自己的密码管理器，然后手动填到 `.env` 的 `REDIS_PASSWORD=` 后面。不要把真实密码写入本文、Git、截图或聊天记录。

保存后执行下面的检查。该命令只检查配置项是否存在，不打印真实密码：

```bash
grep -q '^REDIS_PASSWORD=.' .env && echo 'REDIS_PASSWORD 已配置'
```

**执行后的结果**：输出 `REDIS_PASSWORD 已配置`。

**需要修改的内容**：如果 `.env` 不存在，先执行 `cp .env.example .env`，然后用 `vi .env` 把文件中的所有 `change-me` 和示例密钥按完整部署教程逐项替换。因为 `mysql`、`redis`、`nacos` 同属于 `core`，不能只配置 Redis 一项后就声称整个项目可以启动。

### 第六步：核对项目中 Redis 的真实配置

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

```bash
cd /opt/ygh/constrained-dev
sed -n '55,78p' vm-compose.yml
```

本项目的 Redis 配置以 `vm-compose.yml` 为准，关键内容如下：

- 镜像：`redis:8.4.4`，不使用 `latest`。
- 容器启动参数：`appendonly yes`、`appendfsync everysec`、`maxmemory 96mb`、`maxmemory-policy noeviction`。
- 密码：读取 `.env` 中的 `REDIS_PASSWORD`，通过 `--requirepass` 生效。
- 对外地址：`192.168.154.10:6379`。
- 持久化目录：容器内 `/data`。
- 持久化方式：Docker named volume `ygh-redis-data`。
- 资源限制：`0.20` CPU、`128m` 内存。
- 重启策略：`unless-stopped`。

**执行后的结果**：看到 `redis:` 服务以及上面的镜像、端口、数据卷和启动参数。

**需要修改的内容**：客户首次部署本项目时，不需要创建 `/usr/local/redis`、`/opt/docker_redis` 或单独的 `redis.conf`，也不需要安装 `gcc` 后源码编译 Redis。只有从已有源码版 Redis 迁移旧数据时，才执行本文第四部分。

### 第七步：检查 Compose 配置是否完整

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

```bash
cd /opt/ygh/constrained-dev
docker compose --env-file .env -f vm-compose.yml --profile core config >/dev/null
echo $?
```

**执行后的结果**：输出 `0`。

**需要修改的内容**：如果提示 `required variable ... is missing`，打开 `.env`，补齐报错中指出的变量。不要删掉 `vm-compose.yml` 中的 `:?required`，这些检查用于阻止空密码启动。

### 第八步：拉取本项目固定版本的 Redis 镜像

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

```bash
cd /opt/ygh/constrained-dev
docker compose --env-file .env -f vm-compose.yml --profile core pull redis
docker image inspect redis:8.4.4 --format '{{.RepoTags}}'
```

**执行后的结果**：拉取过程最后显示 Redis 镜像已下载，第二条命令输出中包含 `redis:8.4.4`。

**需要修改的内容**：如果出现超时或无法访问 Docker Hub，先检查 `ping -c 4 223.5.5.5` 和 `getent hosts registry-1.docker.io`，然后回到第四步检查 `/etc/docker/daemon.json`。不要临时把镜像改成 `redis:latest`。

### 第九步：按照项目依赖顺序启动 MySQL、Redis 和 Nacos

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

本项目的基础组件顺序是：先启动 MySQL 和 Redis，确认二者健康后，再启动依赖 MySQL 的 Nacos。手动输入：

```bash
cd /opt/ygh/constrained-dev
docker compose --env-file .env -f vm-compose.yml --profile core up -d mysql redis
docker compose --env-file .env -f vm-compose.yml --profile core ps mysql redis
```

**执行后的结果**：第一次启动 MySQL 需要执行项目的数据库初始化文件。等待状态从 `health: starting` 变成 `healthy`，Redis 也应显示 `healthy`。可以每隔 10 秒重新执行一次 `ps` 命令查看，不要重复执行 `up`。

MySQL 和 Redis 都为 `healthy` 后，再输入：

```bash
docker compose --env-file .env -f vm-compose.yml --profile core up -d nacos
docker compose --env-file .env -f vm-compose.yml --profile core ps
```

**执行后的结果**：最终 `mysql`、`redis`、`nacos` 都显示 `healthy`。Nacos 第一次启动通常比 Redis 慢，因为它必须等待 MySQL 的 `nacos_config` 数据库可用。

**需要修改的内容**：

- Redis 启动失败：执行 `docker compose --env-file .env -f vm-compose.yml logs --tail=200 redis`。
- MySQL 启动失败：先解决 MySQL，不能跳过后直接判断 Nacos 故障。
- 端口被占用：执行 `sudo ss -lntp | grep ':6379'`。如果已有源码版 Redis 占用 6379，按第四部分完成迁移或停止旧进程。

### 第十步：验证 Redis 容器、密码、参数和数据卷

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

```bash
cd /opt/ygh/constrained-dev
docker compose --env-file .env -f vm-compose.yml --profile core exec -T redis sh -c 'REDISCLI_AUTH="$REDIS_PASSWORD" redis-cli ping'
docker compose --env-file .env -f vm-compose.yml --profile core exec -T redis sh -c 'REDISCLI_AUTH="$REDIS_PASSWORD" redis-cli INFO server | grep redis_version'
docker compose --env-file .env -f vm-compose.yml --profile core exec -T redis sh -c 'REDISCLI_AUTH="$REDIS_PASSWORD" redis-cli CONFIG GET maxmemory maxmemory-policy appendonly appendfsync'
docker volume inspect ygh-redis-data
```

**执行后的结果**：

- 第一条输出 `PONG`。
- 第二条输出 `redis_version:8.4.4`。
- 配置检查能看到 `maxmemory` 为 96MB 对应的字节数、`maxmemory-policy` 为 `noeviction`、`appendonly` 为 `yes`、`appendfsync` 为 `everysec`。
- 数据卷检查能看到名称 `ygh-redis-data` 和 Docker 管理的挂载位置。

**需要修改的内容**：如果返回 `NOAUTH Authentication required` 或 `WRONGPASS`，检查 `.env` 的 `REDIS_PASSWORD`，然后执行下面的命令重建 Redis 容器使新密码生效：

```bash
docker compose --env-file .env -f vm-compose.yml --profile core up -d --force-recreate redis
```

该命令不会删除 `ygh-redis-data`。禁止执行 `docker compose down -v`，因为 `-v` 会删除数据卷。

### 第十一步：只允许 Windows 宿主机访问 Redis 端口

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

```bash
sudo firewall-cmd --permanent --add-rich-rule='rule family=ipv4 source address=192.168.154.1/32 port port=6379 protocol=tcp accept'
sudo firewall-cmd --reload
sudo firewall-cmd --list-rich-rules
```

**执行后的结果**：规则列表中出现只允许 `192.168.154.1/32` 访问 TCP 6379 的规则。

**需要修改的内容**：`192.168.154.1` 是当前 VMware NAT 环境中的 Windows 宿主机地址。如果客户电脑的 VMnet8 地址不同，在 Windows PowerShell 执行 `ipconfig` 查看 VMware Network Adapter VMnet8 的 IPv4 地址，并只替换规则里的来源地址。Redis 端口不要对 `0.0.0.0/0` 开放。

### 第十二步：在 Windows 检查 Redis 端口

**在哪里操作**：退出 SSH，回到 Windows 本机 PowerShell。

```powershell
Test-NetConnection 192.168.154.10 -Port 6379
```

**执行后的结果**：`TcpTestSucceeded : True`。

**需要修改的内容**：如果为 `False`，依次检查虚拟机 IP、Redis 容器状态、Compose 端口绑定和 firewalld 规则。不要把 Redis 改装到 Windows Docker Desktop 来绕过网络问题。

### 第十三步：在 IDEA 中配置使用 Redis 的 Java 服务

**在哪里操作**：Windows 本机 IntelliJ IDEA。

1. 打开项目根目录 `F:\跨境智汇AI知识库系统`。
2. 点击 `Run` → `Edit Configurations...`。
3. 选择需要启动的 Spring Boot 服务。
4. 找到 `Environment variables`，点击右侧编辑按钮。
5. 添加以下变量，把密码占位文字替换成 `.env` 中的实际 Redis 密码：

```text
YGH_REDIS_HOST=192.168.154.10
YGH_REDIS_PORT=6379
YGH_REDIS_PASSWORD=这里填写Redis真实密码
YGH_REDIS_ENVIRONMENT=dev
```

至少需要为 `ygh-gateway`、`ygh-auth-service` 和 `ygh-product-service` 配置 Redis 连接变量。`ygh-product-service` 默认使用 Redis database 2；如需显式配置，再添加：

```text
YGH_PRODUCT_REDIS_DATABASE=2
```

**执行后的结果**：IDEA 启动日志中不再出现 Redis 连接拒绝、认证失败或缺少 `YGH_REDIS_*` 变量的错误。

**需要修改的内容**：只修改 IP、端口和真实密码。Java 服务运行在 Windows IDEA，Redis 运行在 Rocky Linux 虚拟机 Docker；不要把项目源码上传到 Redis 容器，也不要在 Redis 容器中安装 JDK。

### 第十四步：日常启动、停止和查看日志

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

启动 Redis：

```bash
cd /opt/ygh/constrained-dev
docker compose --env-file .env -f vm-compose.yml --profile core up -d redis
```

停止 Redis但保留数据：

```bash
docker compose --env-file .env -f vm-compose.yml --profile core stop redis
```

再次启动已经创建的 Redis 容器：

```bash
docker compose --env-file .env -f vm-compose.yml --profile core start redis
```

查看状态和最近 200 行日志：

```bash
docker compose --env-file .env -f vm-compose.yml --profile core ps redis
docker compose --env-file .env -f vm-compose.yml logs --tail=200 redis
```

**执行后的结果**：启动后 Redis 回到 `healthy`；停止命令不会删除 `ygh-redis-data`。

**需要修改的内容**：无需修改命令。不要使用单独的 `docker run --name ygh-redis ...` 再创建第二套 Redis，也不要执行带 `-v` 的 `down`。

## 第二部分：仅在已有源码版 Redis 时执行源码安装与检查

下面保留原有源码安装、配置文件和 TLS 内容，供已有旧环境复现或迁移时使用。客户第一次部署本项目时跳过第二部分，直接执行第一部分；本项目标准运行形态始终是 Rocky Linux 虚拟机中的 Docker Compose Redis。

**源码版操作环境**：Rocky Linux 10 虚拟机；源码包 `/opt/redis-8.4.4.tar.gz`；程序 `/usr/local/redis`；配置 `/usr/local/redis/conf/redis.conf`；数据 `/usr/local/redis/dbcache`。

### 1. 源码包准备与解压

先在 Windows 浏览器打开 `https://download.redis.io/releases/redis-8.4.4.tar.gz`，下载 `redis-8.4.4.tar.gz`。文件通常位于 `C:\Users\当前用户名\Downloads`。

在 Windows PowerShell 执行：

```powershell
Get-FileHash "$HOME\Downloads\redis-8.4.4.tar.gz" -Algorithm SHA256
```

官方文件 SHA256 应为：

```text
C41CE78682346C1CAAB0EA917826EB408D666746755A0772B55754227D72EBE9
```

打开 WinSCP，协议选 `SFTP`，主机填 `192.168.154.10`，端口填 `22`，输入实际 SSH 用户和密码。左侧找到下载文件，右侧进入 `/opt`，把文件上传为 `/opt/redis-8.4.4.tar.gz`。

回到虚拟机终端执行：

```bash
ls -lh /opt/redis-8.4.4.tar.gz
sha256sum /opt/redis-8.4.4.tar.gz
```

Linux 与 Windows 的 SHA256 必须一致。然后安装源码编译依赖：

```bash
sudo dnf install -y gcc gcc-c++ make openssl-devel systemd-devel tcl tar net-tools psmisc
```

首先进入存放安装包的目录，将源码解压到标准的系统软件目录 `/usr/local/`。

```bash
cd /opt/
# 解压到指定目录
tar -zxvf /opt/redis-8.4.4.tar.gz -C /usr/local/
# 进入安装目录并重命名，方便管理
cd /usr/local/
mv redis-8.4.4 redis
cd redis/
```

### 2. 编译前的清理工作

为了防止旧的编译缓存干扰，执行清理命令。这一步会清除之前可能存在的 `.o` 文件和依赖关系。

```bash
sudo make distclean
```

*注：即使报错 `tests: No such file or directory` 通常也可忽略，只要主清理流程完成即可。*

### 3. 编译与安装 (核心步骤：开启 `TLS`)

执行编译时，必须指定 `BUILD_TLS=yes` 参数。`Redis` 会自动下载或编译内置的依赖库（如 `jemalloc`, `lua`, `hiredis`）。

```bash
# 开启 TLS 支持进行编译
sudo make BUILD_TLS=yes

# 将编译好的二进制文件安装到指定目录
make PREFIX=/usr/local/redis install
```

### 4. 环境变量配置

为了能在任何位置直接调用 `redis-cli` 等命令，需要修改系统环境变量。

```bash
vim /etc/profile
# 在文件末尾添加：
# export PATH=$PATH:/usr/local/redis/bin

# 使配置立即生效
source /etc/profile
```

### 5. 安装验证

验证安装的版本以及是否成功集成了 TLS 功能。

```bash
# 查看版本号
redis-server --version
# 预期输出：Redis server v=8.4.4 ... malloc=jemalloc-5.3.0

# 检查客户端是否支持 TLS 参数
redis-cli --help | grep tls
# 预期输出：应能看到 --tls, --tls-ciphers 等相关参数
```

### 6. 初始化生产运行目录

规范化管理 Redis 的配置文件、日志、进程文件和数据持久化文件。

```bash
mkdir -p /usr/local/redis/{conf,run,logs,dbcache}

# 拷贝并备份默认配置文件
cp /usr/local/redis/redis.conf /usr/local/redis/conf/
chown root:root /usr/local/redis/conf/redis.conf
chmod 600 /usr/local/redis/conf/redis.conf
```

### 7. 配置文件修改

使用 `vim` 修改 `/usr/local/redis/conf/redis.conf`。按照本项目配置要求修改以下项目：

*   `daemonize yes`（源码版后台运行；迁移到 Docker 时必须改为 `no`）
*   `protected-mode yes`（保持保护模式，不要关闭）
*   `appendonly yes`（开启 AOF 持久化）
*   `appendfsync everysec`（每秒刷盘）
*   `maxmemory 96mb`（匹配项目低配置环境）
*   `maxmemory-policy noeviction`（容量满时明确失败，不静默删除安全状态）

```bash
# 配置映射
vim /etc/hosts

# 在hosts中配置
192.168.154.10    redis-server
```

*   本项目直接配置 `bind 127.0.0.1 192.168.154.10`，允许虚拟机本机和 Windows 宿主机访问。
*   如果保留主机名映射，也可以配置 `bind 127.0.0.1 redis-server`。
*   配置 `dir /usr/local/redis/dbcache`、`logfile "/usr/local/redis/logs/redis.log"` 和 `pidfile /usr/local/redis/run/redis_6379.pid`。
*   源码编译保留 TLS 能力，但当前项目 Java 配置没有启用 Redis TLS；不要只开启 Redis TLS 端口后直接启动项目。

### 8. 启动服务与网络检查

指定配置文件启动 `Redis` 服务，并检查端口监听状态。

```bash
# 启动服务
/usr/local/redis/bin/redis-server /usr/local/redis/conf/redis.conf

# 检查 6379 端口是否在监听
netstat -nptl | grep 6379

# 启动Redis
/usr/local/redis/bin/redis-cli
# 会出现
redis-server:6379>
# 此时就表示redis成功登录
```

### 9. `Redis` 安全认证

现在虽然已经成功启动 `Redis` 进程，但还不能直接用于项目联调。Redis 默认只绑定本机；如果要让 Windows 宿主机上的 IDEA 访问虚拟机 Redis，就必须正确配置网络绑定、保护模式和密码认证。

1、【`redis-server`】错误的访问，在之前已经使用过了`redis-cli` 命令进行了本机的`Redis` 的连接，但是对于本机而言，当前的IP 地址为：“`192.168.154.10`”（主机名称`redis-server`）

那么如果说现在直接指派主机名称和端口号就无法进行连接了

```bash
/usr/local/redis/bin/redis-cli -h redis-server -p 6379
# 程序执行结果：Could not connect to redis at redis-server:6379: Connection refused
```

- 绑定本机

```bash
# 修改配置文件
vim /usr/local/redis/conf/redis.conf

bind redis-server
```

2、【`redis-server`】虽然`Redis` 是一个缓存组件，但是由于其使用的非常广泛，所以会将一些重要的信息放在`Redis` 里面，因为这样可以提高数据库的访问性能，所以一旦`Redis`打开了网络的绑定配置，那么所带来的问题就必须为其设置认证信息，这样才能保证服务器安全

- 认证信息的修改需要打开`redis` 配置文件

```bash
vim /usr/local/redis/conf/redis.conf
```

- 先在虚拟机执行 `openssl rand -base64 24` 生成强密码，并保存到客户自己的密码管理器。
- 修改配置文件，把占位符替换为刚生成的真实密码：

```conf
requirepass CHANGE_TO_STRONG_PASSWORD
```

不要把真实密码写入本文、Git、截图或聊天记录。

- 登录`redis`

```bash
/usr/local/redis/bin/redis-cli -h redis-server -p 6379

redis-server:6379> auth CHANGE_TO_STRONG_PASSWORD
```

 

### 源码版操作结果确认

1. **编译参数的重要性**：在源码安装阶段，`BUILD_TLS=yes` 是决定 Redis 是否支持加密连接的关键。
2. **目录规范化**：通过建立 `conf`, `logs`, `dbcache` 等目录，可以使运维工作更加井然有序。
3. **权限管理**：配置文件包含密码，使用 `chmod 600` 或按实际运行用户配置最小读取权限，不使用 `chmod 777`。

---

### 源码版操作注意事项

1. 重新编译前执行 `make distclean`，清除旧的目标文件和依赖缓存。
2. 如果执行 `redis-cli` 提示 `command not found`，先执行 `source /etc/profile`，也可以直接使用 `/usr/local/redis/bin/redis-cli`。
3. 如果 Redis 只开放 TLS 端口，`redis-cli` 必须增加 `--tls` 和对应证书参数，不能继续使用普通明文连接。



## 第三部分：虚拟机没有 Docker 时的安装与镜像源配置

开始安装前，先在 Rocky Linux 虚拟机确认网络。以下三条都成功后再继续：

```bash
ping -c 4 192.168.154.2
ping -c 4 223.5.5.5
getent hosts mirrors.rockylinux.org
```

如果公网 IP 不通，先修复 VMware NAT；如果公网 IP 能通但域名无法解析，先修复 DNS。

### 第一步：清理旧版本

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

先检查系统中是否存在 Podman 容器：

```bash
sudo podman ps -a
```

如果输出中存在客户正在使用的容器，停止本步骤，先备份或迁移这些容器，不能直接删除 Podman。如果提示 `podman: command not found`，说明没有安装 Podman，可以继续。

确认没有需要保留的 Podman 容器后，清理可能冲突的软件包：

```bash
sudo dnf remove -y podman buildah runc docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine
```

**执行后的结果**：命令完成且没有事务失败。软件包原本不存在时出现 `No packages marked for removal` 属于正常情况。

### 第二步：安装基础依赖并配置 Docker CE 软件源

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

1. **安装工具包**：

   ```bash
   sudo dnf install -y dnf-plugins-core curl ca-certificates yum-utils
   ```

2. **添加项目当前使用的 Docker 官方 CentOS 兼容软件源**：

   ```bash
   sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
   sudo dnf makecache
   ```

如果客户网络无法访问 `download.docker.com`，删除未完成的仓库文件后改用阿里云兼容地址：

```bash
sudo rm -f /etc/yum.repos.d/docker-ce.repo
sudo dnf config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
sudo dnf makecache
```

**执行后的结果**：`dnf makecache` 完成，且 Docker CE 仓库没有 metadata 下载错误。

### 第三步：安装 Docker 引擎

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

```bash
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

**执行后的结果**：安装事务最后显示 `Complete!`，且没有依赖冲突。

**需要修改的内容**：不修改软件包名称，不单独下载 Windows 版 Docker Desktop 安装包到虚拟机。

### 第四步：配置镜像加速器（解决“无法下载镜像”核心问题）

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。配置文件固定写入 `/etc/docker/daemon.json`，Docker 镜像和数据仍由 `/var/lib/docker` 管理。

项目当前配置 DaoCloud 和 1ms 两个镜像代理作为 Docker Hub 拉取加速入口。代理是否可用还取决于客户网络和代理服务状态，因此写入配置后必须执行后面的实际拉取验证。

1. **创建配置目录**：

   ```bash
   sudo mkdir -p /etc/docker
   if [ -f /etc/docker/daemon.json ]; then sudo cp -a /etc/docker/daemon.json "/etc/docker/daemon.json.bak-$(date +%Y%m%d-%H%M%S)"; fi
   ```

   **执行后的结果**：如果原来存在配置文件，会生成带日期时间的备份。后续配置失败时，可以把备份文件复制回 `/etc/docker/daemon.json` 后重启 Docker 回滚。

2. **编写配置文件**：

   ```bash
   sudo tee /etc/docker/daemon.json <<EOF
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

   不要随意把网上搜索到的未知镜像站写入客户服务器。上述地址失效时，优先使用客户自己的企业镜像仓库、合规网络代理或本文后面的离线导入方式，并保留配置变更记录。

### 第五步：启动并设置开机自启

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

```bash
sudo dockerd --validate --config-file=/etc/docker/daemon.json
sudo systemctl daemon-reload
sudo systemctl enable --now docker
```

**执行后的结果**：第一条显示配置有效或不输出错误，Docker 服务状态为启动并设置开机自启。

**需要修改的内容**：如果校验提示 JSON 语法错误，先执行 `sudo cp /etc/docker/daemon.json.bak-日期时间 /etc/docker/daemon.json` 恢复刚才的备份，再检查逗号、引号和括号。

### 第六步：验证安装

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

执行以下命令检查 Docker 状态：

```bash
sudo docker version
```

尝试拉取一个轻量级镜像测试网络：

```bash
sudo docker pull alpine
```

如果能看到 `Status: Downloaded newer image for alpine:latest` 或 `Image is up to date`，说明该次拉取成功。

**需要修改的内容**：该 Alpine 镜像只用于验证 Docker 拉取能力，不是本项目 Redis。验证完成后仍需回到第一部分第八步，拉取项目固定的 `redis:8.4.4`。

---

### 补充操作：镜像加速器仍然缓慢时如何处理

如果上述加速器仍然无法使用，按下面三种备用方式处理：

1. **使用代理（推荐）**：
   如果你有科学上网环境，给 Docker 配置系统代理：

   ```bash
   sudo mkdir -p /etc/systemd/system/docker.service.d
   sudo vi /etc/systemd/system/docker.service.d/http-proxy.conf
   ```

   内容如下：

   ```ini
   [Service]
   Environment="HTTP_PROXY=http://你的代理IP:端口"
   Environment="HTTPS_PROXY=http://你的代理IP:端口"
   ```

   然后重启：`systemctl daemon-reload && systemctl restart docker`

2. **使用国内源拉取特定镜像**：
   国内某些大厂（如华为、南京大学）对部分常用镜像有缓存，可以尝试：
   `docker pull swr.cn-north-4.myhuaweicloud.com/ddn-k8s/docker.io/library/alpine:latest`

3. **离线导出导入**：
   在能联网的机器上执行 `docker save -o image.tar 镜像名`，然后拷贝到 Rocky 机器上执行 `docker load -i image.tar`。

### 第七步：管理非 root 用户（可选）

如果你不想每次都输入 `sudo`，将当前用户加入 docker 组：

```bash
sudo usermod -aG docker $USER
# 执行完后需重新登录终端生效
```



## 第四部分：把已有源码版 Redis 数据迁入本项目 Docker Compose

将源码编译安装的 Redis 8.4.4 迁移到 Docker 中，核心逻辑是：**“导出原始数据（RDB文件）+ 提取核心配置 + 启动版本匹配的容器”**。

本项目源码版和 Docker 版都固定为 Redis 8.4.4，Docker Hub 官方镜像标签为 `redis:8.4.4`。迁移前分别执行 `redis-server --version` 和 `docker run --rm redis:8.4.4 redis-server --version`，确认两端版本一致。

### 本项目必须采用的迁移落点

迁移完成后，Redis 必须由 `/opt/ygh/constrained-dev/vm-compose.yml` 管理，数据必须进入 named volume `ygh-redis-data`。不能把下面通用示例中的独立 `ygh-redis` 容器作为本项目最终运行方式，否则会与 Compose 的端口、密码、健康检查和运维命令分离。

先在源码版 Redis 中执行保存并停止旧进程：

```bash
/usr/local/redis/bin/redis-cli -a CHANGE_TO_STRONG_PASSWORD SAVE
sudo mkdir -p /opt/ygh/redis-migration
sudo cp /usr/local/redis/dbcache/dump.rdb /opt/ygh/redis-migration/dump.rdb
sudo cp /usr/local/redis/conf/redis.conf /opt/ygh/redis-migration/redis.conf.source-backup
sudo killall redis-server
sudo ss -lntp | grep ':6379' || echo '6379 端口已释放'
```

**执行后的结果**：`/opt/ygh/redis-migration` 中存在 `dump.rdb` 和旧配置备份，6379 端口不再由源码版 Redis 监听。

把 RDB 文件复制到本项目 Redis 数据卷：

```bash
cd /opt/ygh/constrained-dev
docker compose --env-file .env -f vm-compose.yml --profile core stop redis
docker volume create ygh-redis-data
docker run --rm -v ygh-redis-data:/data alpine sh -c 'find /data -mindepth 1 -maxdepth 1 -print'
```

上面最后一条检查命令在新数据卷中不应输出任何文件。如果已经输出 `appendonlydir`、`dump.rdb` 或其他数据，立即停止迁移，先确认这些数据是否需要备份，不能直接覆盖。确认数据卷为空后继续输入：

```bash
docker run --rm \
  -v ygh-redis-data:/data \
  -v /opt/ygh/redis-migration:/migration:ro,Z \
  alpine sh -c 'cp /migration/dump.rdb /data/dump.rdb && chown 999:999 /data/dump.rdb'
docker compose --env-file .env -f vm-compose.yml --profile core up -d redis
```

这里的 `docker run` 只临时启动 Alpine 复制一次文件，命令结束后临时容器会自动删除；最终 Redis 仍由项目 Compose 启动。

验证迁移结果：

```bash
docker compose --env-file .env -f vm-compose.yml --profile core exec -T redis sh -c 'REDISCLI_AUTH="$REDIS_PASSWORD" redis-cli ping'
docker compose --env-file .env -f vm-compose.yml --profile core exec -T redis sh -c 'REDISCLI_AUTH="$REDIS_PASSWORD" redis-cli DBSIZE'
docker compose --env-file .env -f vm-compose.yml --profile core exec -T redis sh -c 'REDISCLI_AUTH="$REDIS_PASSWORD" redis-cli INFO persistence | grep -E "aof_enabled|rdb_last_load_keys_expired|rdb_last_load_keys_loaded"'
```

**执行后的结果**：第一条输出 `PONG`；`DBSIZE` 应与迁移前记录的键数量一致；持久化信息中 `aof_enabled:1`。

**需要修改的内容**：`CHANGE_TO_STRONG_PASSWORD` 替换为旧源码版 Redis 的密码；`.env` 中的 `REDIS_PASSWORD` 是迁移后项目 Redis 的密码，两者可以不同。不要把旧 `redis.conf` 直接挂载到项目容器，本项目所需参数已经由 `vm-compose.yml` 的 `command` 固定。

### 原有独立容器迁移资料

以下内容保留用于理解宿主机目录挂载和旧版独立容器迁移。它不是本项目的新部署方式，也不能与第一部分的 Compose Redis 同时执行。真正交付本项目时，以本部分前面的 named volume 迁移命令为准。

**核心预警：**

- 不使用 `redis:latest`，避免不同交付时间拉到不同版本。
- 源 Redis 版本不高于目标版本时才能直接迁移 RDB；高版本向低版本迁移必须单独验证。
- 源码版和 Docker 版都占用 `192.168.154.10:6379`，启动 Docker 前必须停止源码版。

#### 1. 准备持久化数据（Rocky Linux 虚拟机宿主系统操作）

```bash
# 确保数据写回磁盘
/usr/local/redis/bin/redis-cli -a CHANGE_TO_STRONG_PASSWORD SAVE

# 创建 Docker 专用的目录结构
mkdir -p /opt/docker_redis/{data,conf,logs}
cp /usr/local/redis/dbcache/dump.rdb /opt/docker_redis/data/
cp /usr/local/redis/conf/redis.conf /opt/docker_redis/conf/

# 关键：修正权限
# Docker 内部 redis 用户 UID 通常是 999
chown -R 999:999 /opt/docker_redis/data
```

#### 2. 针对容器环境的配置修正（重点检查项）

```
vim /opt/docker_redis/conf/redis.conf
```

确认以下配置：

- daemonize no (容器环境下必须为 no，否则容器启动即退出)
- bind 0.0.0.0 (允许外部连接)
- dir /data (指向容器内挂载点)
- logfile "/data/redis.log"（将日志也存放在持久化目录）
- appendonly yes
- appendfsync everysec
- maxmemory 96mb
- maxmemory-policy noeviction
- requirepass 使用前面生成的同一个强密码



在 Docker 中，“挂载点”是通过启动命令中的 `-v`（或 `--volume`）参数来实现的。它像一座桥梁，把**宿主机（你的 Rocky Linux）**的文件夹和**容器（Docker 内部）**的文件夹连接起来。

既然你之前已经准备好了 `/opt/docker_redis` 目录，以下是详细的设置与启动步骤：

### 第一步：在宿主机上创建物理目录
确保宿主机上有存放配置和数据的“实体”：
```bash
# 创建配置目录和数据目录
sudo mkdir -p /opt/docker_redis/conf
sudo mkdir -p /opt/docker_redis/data

# 将你之前编译好的配置文件拷贝到挂载点
sudo cp /usr/local/redis/conf/redis.conf /opt/docker_redis/conf/
```

### 第二步：修正宿主机目录权限（最重要）
Docker 镜像内的 Redis 进程通常是以 `redis` 用户（UID 999）运行的。如果宿主机的文件夹权限不对，容器会因为“Permission denied”而无法启动。
```bash
# 将目录所有权交给容器内的 redis 用户 (UID 999)
sudo chown -R 999:999 /opt/docker_redis/data
sudo chown -R 999:999 /opt/docker_redis/conf

# 不使用 777；配置含密码，数据目录只交给容器内 Redis 用户
chown -R 999:999 /opt/docker_redis/data /opt/docker_redis/conf
chmod 750 /opt/docker_redis /opt/docker_redis/data /opt/docker_redis/conf
chmod 640 /opt/docker_redis/conf/redis.conf
```

### 第三步：检查配置文件里的内部路径
打开宿主机的 `/opt/docker_redis/conf/redis.conf`，确保 Redis 知道数据该往哪存（**注意：这里填的是容器内部的路径**）：
```bash
sudo vim /opt/docker_redis/conf/redis.conf
```
找到并修改以下行：
```conf
# 数据持久化文件的存放目录（容器内路径）
dir /data

# 如果开启了日志，也建议指向 /data 或容器内的固定路径
logfile "/data/redis.log"

# 确保是非后台运行模式
daemonize no
```

### 第四步：执行挂载并启动容器
使用 `-v` 参数建立对应关系。格式为：`-v 宿主机绝对路径:容器内部路径`。

```bash
docker run -d \
  --name ygh-redis \
  --cpus="0.20" \
  --memory="128m" \
  -p 192.168.154.10:6379:6379 \
  -v /opt/docker_redis/conf/redis.conf:/etc/redis/redis.conf:ro,Z \
  -v /opt/docker_redis/data:/data:Z \
  --restart unless-stopped \
  redis:8.4.4 \
  redis-server /etc/redis/redis.conf
```

**挂载点解释：**
1.  **`-v /opt/docker_redis/conf/redis.conf:/etc/redis/redis.conf`**: 
    将宿主机的配置文件挂载到容器的 `/etc/redis/` 下。Redis 启动命令最后指定了读取这个位置。
2.  **`-v /opt/docker_redis/data:/data`**: 
    将宿主机的 `data` 目录挂载到容器的 `/data`。你在配置文件里写的 `dir /data` 产生的所有 RDB/AOF 文件都会实时出现在宿主机的 `/opt/docker_redis/data` 文件夹里。

---

### 第五步：验证挂载是否成功

#### 1. 检查容器内是否能看到配置文件
```bash
docker exec -it ygh-redis ls /etc/redis/
# 预期看到：redis.conf
```

#### 2. 测试持久化联动
在容器里写入一条数据，然后去宿主机查看文件：
```bash
# 容器内操作
docker exec -it ygh-redis redis-cli -a CHANGE_TO_STRONG_PASSWORD SET mytest "hello_docker"
docker exec -it ygh-redis redis-cli -a CHANGE_TO_STRONG_PASSWORD SAVE

# 宿主机操作
ls -l /opt/docker_redis/data/dump.rdb
# 如果 dump.rdb 的更新时间变为了刚才的时间，说明挂载点完全正常！
```

### 独立容器操作提示
*   **查看启动失败原因**：如果执行 `docker run` 后容器没起来，立刻输入 `docker logs ygh-redis`。
*   **配置文件只读**：如果你不希望容器修改你的配置文件，可以写成 `-v /opt/docker_redis/conf/redis.conf:/etc/redis/redis.conf:ro`（末尾加 `:ro` 表示 Read-Only）。对于 `data` 目录，必须是读写权限。



#### 3. 启动命令（性能调优版）

本项目虚拟机只有 2 个 vCPU、3.5GB 内存，因此使用下面的资源限制启动，避免 Redis 挤占 MySQL 和 Nacos 的资源。

```bash
docker run -d \
  --name ygh-redis \
  --cpus="0.20" \
  --memory="128m" \
  -p 192.168.154.10:6379:6379 \
  -v /opt/docker_redis/conf/redis.conf:/etc/redis/redis.conf:ro,Z \
  -v /opt/docker_redis/data:/data:Z \
  --restart unless-stopped \
  redis:8.4.4 \
  redis-server /etc/redis/redis.conf
```

------



### 独立容器迁移故障排查

**1. 为什么 redis-cli 连不上容器？**

- **检查1**：防火墙。Rocky 10 默认开启 firewalld，只允许 Windows VMnet8 地址访问：

  ```bash
  firewall-cmd --permanent --add-rich-rule='rule family=ipv4 source address=192.168.154.1/32 port port=6379 protocol=tcp accept'
  firewall-cmd --reload
  ```

- **检查2**：`protected-mode` 保持 `yes`，并确认 `requirepass` 已配置且 IDEA 中的密码一致。

**2. 迁移后运行参数是否生效？**
在容器外执行：

```bash
docker exec -it ygh-redis redis-cli -a CHANGE_TO_STRONG_PASSWORD INFO
docker exec -it ygh-redis redis-cli -a CHANGE_TO_STRONG_PASSWORD CONFIG GET io-threads
```

当前项目没有启用 3 个 IO 线程；`CONFIG GET io-threads` 保持默认值即可。重点确认 `maxmemory=96mb`、`maxmemory-policy=noeviction`、`appendonly=yes` 和 `appendfsync=everysec`。

以下保留原有的独立容器详细迁移步骤：

---

### 第一阶段：在 Rocky Linux 虚拟机宿主系统准备数据和配置

迁移前，我们需要把正在运行的 Redis 数据落盘并提取出来。

#### 1. 强制保存数据
在 Rocky Linux 虚拟机终端执行，确保内存中的数据完整写入磁盘：
```bash
/usr/local/redis/bin/redis-cli -a CHANGE_TO_STRONG_PASSWORD
redis-server:6379> SAVE
redis-server:6379> EXIT
```

#### 2. 定位并备份关键文件
你需要拷贝出两个核心文件：
- **数据文件**：`/usr/local/redis/dbcache/dump.rdb`
- **配置文件**：`/usr/local/redis/conf/redis.conf`

#### 3. 停止源码版 Redis
为了释放 6379 端口给 Docker 使用：
```bash
killall redis-server
```

---

### 第二阶段：准备 Docker 运行环境

在 Rocky Linux 虚拟机宿主系统创建专门存放 Docker 持久化数据的目录。

```bash
mkdir -p /opt/docker_redis/{data,conf}

# 将虚拟机宿主系统中的文件复制到 Docker 挂载目录
cp /usr/local/redis/dbcache/dump.rdb /opt/docker_redis/data/
cp /usr/local/redis/conf/redis.conf /opt/docker_redis/conf/

# 赋予权限，防止 Docker 容器无法读取
# 不使用 777；配置含密码，数据目录只交给容器内 Redis 用户
chown -R 999:999 /opt/docker_redis/data /opt/docker_redis/conf
chmod 750 /opt/docker_redis /opt/docker_redis/data /opt/docker_redis/conf
chmod 640 /opt/docker_redis/conf/redis.conf
```

---

### 第三阶段：针对 Docker 环境修改配置文件

**这一步极其关键！** 源码版的配置文件在 Docker 里直接用会报错，必须修改以下几项：

```bash
vim /opt/docker_redis/conf/redis.conf
```

**修改以下四项内容：**
1.  **`daemonize`**: 改为 **`no`**。（Docker 容器必须前台运行，设为 `yes` 容器启动后会立即退出）。
2.  **`bind`**: 改为 **`0.0.0.0`**。（允许容器外连接）。
3.  **`dir`**: 改为 **`/data`**。（这是容器内部的路径）。
4.  **`protected-mode`**: 保持为 **`yes`**，并确认 `requirepass` 已配置。

---

### 第四阶段：启动 Redis 容器

当前项目按低配置虚拟机运行，使用下面的 CPU 和内存限制启动。

```bash
docker run -d \
  --name ygh-redis \
  --cpus="0.20" \
  --memory="128m" \
  -p 192.168.154.10:6379:6379 \
  -v /opt/docker_redis/conf/redis.conf:/etc/redis/redis.conf:ro,Z \
  -v /opt/docker_redis/data:/data:Z \
  --restart unless-stopped \
  redis:8.4.4 \
  redis-server /etc/redis/redis.conf
```

**指令解释：**
- `-v .../redis.conf:/etc/redis/redis.conf`: 把虚拟机宿主系统中修改好的配置挂载进去。
- `-v .../data:/data`: 把存有 `dump.rdb` 的目录挂载到容器数据目录。Redis 启动时会自动加载这个文件还原数据。
- `redis:8.4.4`：项目固定使用的 Docker Hub 官方 Redis 镜像，不使用 `latest`。

---

### 第五阶段：验证迁移结果

#### 1. 检查数据是否找回
进入容器查看之前压测产生的数据：
```bash
docker exec -it ygh-redis redis-cli -a CHANGE_TO_STRONG_PASSWORD
127.0.0.1:6379> DBSIZE
# 如果输出的数字大于 0，说明数据（dump.rdb）迁移成功！
127.0.0.1:6379> INFO server
# 查看版本号是否符合预期
```

#### 2. 修改 Spring Boot 配置

本项目 Java 服务在 Windows 本机 IDEA 中运行，Redis 在 Rocky Linux 虚拟机 Docker 中运行。代码不需要上传到 Redis，Java 服务通过虚拟机 IP 连接 Redis。

在 IDEA 右上角点击运行配置 → `Edit Configurations...` → 选择服务 → `Environment variables`，添加：

```text
YGH_REDIS_HOST=192.168.154.10
YGH_REDIS_PORT=6379
YGH_REDIS_PASSWORD=这里填写Redis真实密码
YGH_REDIS_ENVIRONMENT=dev
```

至少为 `ygh-gateway`、`ygh-auth-service` 和 `ygh-product-service` 配置这些变量。不要把真实密码写入 `application.yml`。

---

### 补充操作：多线程 IO 与本项目资源限制

原版示例使用了 `io-threads 3` 和 `io-threads-do-reads yes`。当前项目的 Redis 容器只分配 `0.20` CPU，不启用这两个参数，避免线程数量超过可用 CPU。可以通过以下命令确认当前值：
```bash
docker exec -it ygh-redis redis-cli -a CHANGE_TO_STRONG_PASSWORD CONFIG GET io-threads
```

### 常见报错排除：
- **容器秒退**：检查 `redis.conf` 里的 `daemonize` 是否已经改为 `no`。
- **无法连接**：检查 `redis.conf` 里的 `bind` 是否为 `0.0.0.0`，并确认防火墙已放行 6379 端口。
- **数据没出来**：检查 `redis.conf` 里的 `dir` 是否指向了 `/data`，且容器启动命令中正确挂载了数据卷。
