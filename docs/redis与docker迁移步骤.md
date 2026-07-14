# 实验教案：`Redis` 8.4.4 源码编译、`TLS` 增强安装与配置实战

**实验背景**：本实验按照跨境智汇 AI 知识库系统的 Rocky Linux 虚拟机环境，通过源码安装 `Redis` 8.4.4，保留 `TLS` 编译能力，再把配置和数据迁移到项目固定版本的 Docker 容器。

---

## 一、 实验目标

1. 掌握 `Redis` 源码包的解压与目录规范化管理。
2. 学习使用 `make` 命令进行条件编译（开启 `TLS` 支持）。
3. 掌握 `Redis` 运行环境的目录结构初始化。
4. 学习 `Redis` 服务的启动与端口连通性验证。

---

## 二、 实验环境

*   **操作系统**：Rocky Linux 10 虚拟机（SSH 地址 `192.168.154.10`）
*   **软件版本**：项目固定使用 `Redis` 8.4.4，源码版和 Docker 版保持一致
*   **核心依赖**：`gcc, gcc-c++, make, openssl-devel, tcl, tar, net-tools, psmisc`（编译、测试、端口和进程检查必需）
*   **安装位置**：源码包 `/opt/redis-8.4.4.tar.gz`；源码和程序 `/usr/local/redis`；配置 `/usr/local/redis/conf/redis.conf`；数据 `/usr/local/redis/dbcache`
*   **运行位置**：源码版和 Docker 版都在 Rocky Linux 虚拟机；Windows 运行 IDEA 和项目代码；WSL 与 Windows Docker Desktop 不安装此 Redis

---

## 三、 实验步骤

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

使用 `vim` 修改 `/usr/local/redis/conf/redis.conf`。根据生产需求，通常需要修改以下项（实验记录中已执行修改）：

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

 

## 四、 实验总结

1. **编译参数的重要性**：在源码安装阶段，`BUILD_TLS=yes` 是决定 Redis 是否支持加密连接的关键。
2. **目录规范化**：通过建立 `conf`, `logs`, `dbcache` 等目录，可以使运维工作更加井然有序。
3. **权限管理**：配置文件包含密码，使用 `chmod 600` 或按实际运行用户配置最小读取权限，不使用 `chmod 777`。

---

## 五、 思考题

1. 为什么在编译前建议执行 `make distclean`？
2. 如果在执行 `redis-cli` 时报错“`command not found`”，除了 `source /etc/profile` 外，还有哪种方式可以解决？
3. 在开启了 `TLS` 的 `Redis` 环境中，使用 `redis-cli` 直接连接（不加参数）还能操作数据吗？



# Docker 安装步骤

开始安装前，先在 Rocky Linux 虚拟机确认网络。以下三条都成功后再继续：

```bash
ping -c 4 192.168.154.2
ping -c 4 223.5.5.5
getent hosts mirrors.rockylinux.org
```

如果公网 IP 不通，先修复 VMware NAT；如果公网 IP 能通但域名无法解析，先修复 DNS。

### 第一步：清理旧版本

如果系统里有旧的 Docker 冲突包，先执行卸载：

```bash
sudo dnf remove docker \
                  docker-client \
                  docker-client-latest \
                  docker-common \
                  docker-latest \
                  docker-latest-logrotate \
                  docker-logrotate \
                  docker-engine
```

### 第二步：安装基础依赖并配置阿里软件源

官方源 `download.docker.com` 在国内访问极慢，我们直接使用阿里云提供的镜像仓库。

1. **安装工具包**：

   ```bash
   sudo dnf install -y dnf-plugins-core curl ca-certificates
   ```

2. **添加阿里云 Docker 软件源**：
   由于 Rocky 10 非常新，如果阿里云的 `rocky/10` 路径尚未完全就绪，我们可以手动指向 `centos` 的兼容路径：

   ```bash
   sudo dnf config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
   ```

### 第三步：安装 Docker 引擎

```bash
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

### 第四步：配置镜像加速器（解决“无法下载镜像”核心问题）

这是最关键的一步。由于目前国内大量公共镜像站（如中科大、网易、阿里等）已失效或仅限内部使用，建议配置多个**当前依然存活的社区代理**或使用**自建中转**。

1. **创建配置目录**：

   ```bash
   sudo mkdir -p /etc/docker
   ```

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

   *注意：镜像站状态变化很快，如果失效，请搜索最新的“Docker 镜像站地址”。*

### 第五步：启动并设置开机自启

```bash
sudo dockerd --validate --config-file=/etc/docker/daemon.json
sudo systemctl daemon-reload
sudo systemctl enable --now docker
```

### 第六步：验证安装

执行以下命令检查 Docker 状态：

```bash
sudo docker version
```

尝试拉取一个轻量级镜像测试网络：

```bash
sudo docker pull alpine
```

如果能看到 `Status: Downloaded newer image for alpine:latest`，说明配置成功。

---

### 💡 进阶方案：如果镜像加速器依然缓慢

如果上述加速器都无法解决你的问题，目前的“终极方案”有三种：

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



# 迁移Redis

将源码编译安装的 Redis 8.4.4 迁移到 Docker 中，核心逻辑是：**“导出原始数据（RDB文件）+ 提取核心配置 + 启动版本匹配的容器”**。

本项目源码版和 Docker 版都固定为 Redis 8.4.4，Docker Hub 官方镜像标签为 `redis:8.4.4`。迁移前分别执行 `redis-server --version` 和 `docker run --rm redis:8.4.4 redis-server --version`，确认两端版本一致。

**核心预警：**

- 不使用 `redis:latest`，避免不同交付时间拉到不同版本。
- 源 Redis 版本不高于目标版本时才能直接迁移 RDB；高版本向低版本迁移必须单独验证。
- 源码版和 Docker 版都占用 `192.168.154.10:6379`，启动 Docker 前必须停止源码版。

#### 1. 准备持久化数据（物理机操作）

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

### 💡 小贴士：
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



### 第四部分：文档补充与故障排查（QA）

**1. 为什么 redis-cli 连不上容器？**

- **检查1**：防火墙。Rocky 10 默认开启 firewalld，只允许 Windows VMnet8 地址访问：

  ```bash
  firewall-cmd --permanent --add-rich-rule='rule family=ipv4 source address=192.168.154.1/32 port protocol=tcp port=6379 accept'
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

以下是保姆级迁移步骤：

---

### 第一阶段：在物理机上准备数据和配置

迁移前，我们需要把正在运行的 Redis 数据落盘并提取出来。

#### 1. 强制保存数据
在物理机终端执行，确保内存中的数据完整写入磁盘：
```bash
/usr/local/redis/bin/redis-cli -a CHANGE_TO_STRONG_PASSWORD
redis-server:6379> SAVE
redis-server:6379> EXIT
```

#### 2. 定位并备份关键文件
你需要拷贝出两个核心文件：
- **数据文件**：`/usr/local/redis/dbcache/dump.rdb`
- **配置文件**：`/usr/local/redis/conf/redis.conf`

#### 3. 停止物理机 Redis
为了释放 6379 端口给 Docker 使用：
```bash
killall redis-server
```

---

### 第二阶段：准备 Docker 运行环境

在物理机上创建专门存放 Docker 持久化数据的目录。

```bash
mkdir -p /opt/docker_redis/{data,conf}

# 将物理机的文件拷贝到 Docker 挂载目录
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
- `-v .../redis.conf:/etc/redis/redis.conf`: 把物理机改好的配置挂载进去。
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

### 💡 进阶：多线程 IO 与本项目资源限制

原版示例使用了 `io-threads 3` 和 `io-threads-do-reads yes`。当前项目的 Redis 容器只分配 `0.20` CPU，不启用这两个参数，避免线程数量超过可用 CPU。可以通过以下命令确认当前值：
```bash
docker exec -it ygh-redis redis-cli -a CHANGE_TO_STRONG_PASSWORD CONFIG GET io-threads
```

### 常见报错排除：
- **容器秒退**：检查 `redis.conf` 里的 `daemonize` 是否已经改为 `no`。
- **无法连接**：检查 `redis.conf` 里的 `bind` 是否为 `0.0.0.0`，并确认防火墙已放行 6379 端口。
- **数据没出来**：检查 `redis.conf` 里的 `dir` 是否指向了 `/data`，且容器启动命令中正确挂载了数据卷。

