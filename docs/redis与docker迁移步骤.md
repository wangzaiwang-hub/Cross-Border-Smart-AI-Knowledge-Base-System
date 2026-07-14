# Redis 8.4.4 手工安装、配置与 Docker 迁移操作文档

## 第一部分：在 Rocky Linux 虚拟机中准备临时源码版 Redis

这一部分的源码版 Redis 只用于准备 `redis.conf`、验证参数和生成迁移数据，不是本项目最终长期运行的 Redis。完成后必须停止源码版 Redis，再把配置和数据迁移到同一台 Rocky Linux 虚拟机里的 Docker 容器。

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
```

打开文件后按下面顺序操作：

1. 按键盘上的 `i`，进入编辑模式。
2. 移动到文件最后一行。
3. 输入 `export PATH=$PATH:/usr/local/redis/bin`。
4. 按 `Esc` 退出编辑模式。
5. 输入 `:wq` 后按回车，保存并退出。

让环境变量立即生效并检查：

```bash
source /etc/profile
echo $PATH | tr ':' '\n' | grep '/usr/local/redis/bin'
```

执行后应输出 `/usr/local/redis/bin`。如果没有输出，重新打开 `/etc/profile`，检查这一行是否拼写正确。

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

配置文件位于 Rocky Linux 虚拟机的 `/usr/local/redis/conf/redis.conf`。输入：

```bash
vim /usr/local/redis/conf/redis.conf
```

打开文件后按 `i` 进入编辑模式，逐项搜索并修改。Vim 中输入 `/配置项` 后按回车可以搜索，按 `n` 可以查找下一处。

1. 搜索 `daemonize`，修改为 `daemonize yes`。源码版需要后台运行；迁移到 Docker 时再改为 `no`。
2. 搜索 `protected-mode`，修改为 `protected-mode yes`，不要关闭保护模式。
3. 搜索 `bind`，修改为 `bind 127.0.0.1 192.168.154.10`。
4. 搜索 `appendonly`，修改为 `appendonly yes`。
5. 搜索 `appendfsync`，修改为 `appendfsync everysec`。
6. 搜索 `maxmemory`，修改为 `maxmemory 96mb`。如果原文件中这一项以 `#` 开头，需要删除行首的 `#`。
7. 搜索 `maxmemory-policy`，修改为 `maxmemory-policy noeviction`。
8. 搜索 `dir`，修改为 `dir /usr/local/redis/dbcache`。
9. 搜索 `logfile`，修改为 `logfile "/usr/local/redis/logs/redis.log"`。
10. 搜索 `pidfile`，修改为 `pidfile /usr/local/redis/run/redis_6379.pid`。

全部修改完成后按 `Esc`，输入 `:wq` 并按回车保存。执行下面的命令核对，输出必须包含刚才填写的值：

```bash
grep -E '^(daemonize|protected-mode|bind|appendonly|appendfsync|maxmemory|maxmemory-policy|dir|logfile|pidfile)' /usr/local/redis/conf/redis.conf
```

```bash
# 配置映射
vim /etc/hosts

# 在hosts中配置
192.168.154.10    redis-server
```

本项目直接使用 `bind 127.0.0.1 192.168.154.10`。如果客户虚拟机的固定服务地址不是 `192.168.154.10`，这里只替换为客户实际固定 IP。源码编译保留 TLS 能力，但当前项目 Java 配置没有启用 Redis TLS，不要只开启 Redis TLS 端口后直接启动项目。

### 8. 临时启动源码版 Redis 并检查网络

以下命令在 Rocky Linux 虚拟机系统中临时启动源码版 Redis，并检查端口监听状态。这个进程只运行到 Docker 迁移前，不能和后面的 Docker Redis 同时运行。

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

现在 Redis 已经监听 `127.0.0.1` 和 `192.168.154.10`，还需要手动设置密码。先在 Rocky Linux 虚拟机终端生成强密码：

```bash
openssl rand -base64 24
```

终端会输出一串随机字符。把它保存到客户自己的密码管理器，然后输入：

```bash
vim /usr/local/redis/conf/redis.conf
```

打开文件后执行：

1. 输入 `/requirepass` 并按回车搜索。
2. 按 `i` 进入编辑模式。
3. 删除行首的 `#`，把这一行改为 `requirepass 客户刚生成的真实密码`。
4. 按 `Esc`，输入 `:wq` 并按回车保存。

不要把真实密码写入本文、Git、截图或聊天记录。重启源码版 Redis 使密码生效：

```bash
/usr/local/redis/bin/redis-cli -h 127.0.0.1 -p 6379 shutdown
/usr/local/redis/bin/redis-server /usr/local/redis/conf/redis.conf
```

使用刚才的真实密码验证：

```bash
/usr/local/redis/bin/redis-cli -h 192.168.154.10 -p 6379

192.168.154.10:6379> auth CHANGE_TO_STRONG_PASSWORD
192.168.154.10:6379> ping
```

输入命令时，把 `CHANGE_TO_STRONG_PASSWORD` 替换成真实密码。`auth` 应返回 `OK`，`ping` 应返回 `PONG`。输入 `exit` 退出 Redis 客户端，然后进入 Docker 安装步骤。

 

## 四、 操作结果确认

1. **编译参数的重要性**：在源码安装阶段，`BUILD_TLS=yes` 是决定 Redis 是否支持加密连接的关键。
2. **目录规范化**：通过建立 `conf`, `logs`, `dbcache` 等目录，可以使运维工作更加井然有序。
3. **权限管理**：配置文件包含密码，使用 `chmod 600` 或按实际运行用户配置最小读取权限，不使用 `chmod 777`。

---

## 五、 操作注意事项

1. 重新编译前执行 `make distclean`，清除旧的目标文件和依赖缓存。
2. 如果执行 `redis-cli` 提示 `command not found`，先执行 `source /etc/profile`，也可以直接使用 `/usr/local/redis/bin/redis-cli`。
3. 如果 Redis 只开放 TLS 端口，`redis-cli` 必须增加 `--tls` 和对应证书参数，不能继续使用普通明文连接。



# 第二部分：在 Rocky Linux 虚拟机内部手动安装 Docker

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

2. **手动编写配置文件**：

   ```bash
   sudo vim /etc/docker/daemon.json
   ```

   打开文件后按 `i` 进入编辑模式，输入以下全部内容：

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

   输入完成后按 `Esc`，输入 `:wq` 并按回车保存。然后执行：

   ```bash
   sudo cat /etc/docker/daemon.json
   sudo dockerd --validate --config-file=/etc/docker/daemon.json
   ```

   第一条命令应完整显示刚才输入的 JSON；第二条命令不能出现 JSON 格式错误。如果提示某一行语法错误，重新执行 `sudo vim /etc/docker/daemon.json`，检查逗号、双引号和括号。

   镜像代理状态可能变化。如果失效，使用客户自己的企业镜像仓库、网络代理或后面的离线导入方式，不要随意配置来源不明的镜像站。

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



# 第三部分：停止源码版并把 Redis 最终迁移到虚拟机 Docker 容器

这里的 Docker Engine 安装在 Rocky Linux 虚拟机内部。迁移完成后的唯一 Redis 服务是该虚拟机 Docker 中名为 `ygh-redis` 的容器；Windows IDEA 通过 `192.168.154.10:6379` 访问它。源码版 Redis 必须停止，不再作为项目服务运行。

迁移的核心操作是：**导出源码版数据（RDB 文件）→ 复制并修改配置 → 停止源码版进程 → 启动虚拟机内的 Redis Docker 容器**。

### 第一步：手动拉取项目固定版本的 Redis 镜像

在 Rocky Linux 虚拟机 SSH 终端输入：

```bash
docker pull redis:8.4.4
docker image inspect redis:8.4.4 --format '{{.RepoTags}}'
docker run --rm redis:8.4.4 redis-server --version
```

第一条命令从 Docker Hub 或已经配置的镜像代理下载 Redis。第二条命令输出中必须包含 `redis:8.4.4`。第三条命令应显示 Redis 8.4.4 版本，验证完成后临时容器自动删除。

如果拉取失败，不要把版本改成 `latest`，返回“Docker 安装步骤”的镜像源配置和网络检查部分。镜像下载到 Rocky Linux 虚拟机的 Docker 数据目录 `/var/lib/docker`，不下载到 Windows、WSL 或 Windows Docker Desktop。

### 第二步：确认源码版和 Docker 版版本一致

本项目源码版和 Docker 版都固定为 Redis 8.4.4。输入：

```bash
redis-server --version
docker run --rm redis:8.4.4 redis-server --version
```

两条命令都必须显示 8.4.4，才能继续迁移。

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

#### 2. 停止虚拟机系统中的源码版 Redis

数据和配置复制完成后，立即停止源码版 Redis，释放 6379 端口：

```bash
/usr/local/redis/bin/redis-cli -a CHANGE_TO_STRONG_PASSWORD shutdown
ss -lntp | grep ':6379' || echo '源码版 Redis 已停止，6379 端口已释放'
```

把 `CHANGE_TO_STRONG_PASSWORD` 替换为源码版 Redis 的真实密码。必须看到端口已经释放，才能继续。此后不要再启动 `/usr/local/redis/bin/redis-server`。

#### 3. 针对容器环境的配置修正（重点检查项）

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

执行后输入：

```bash
docker ps --filter name=ygh-redis
docker logs --tail 100 ygh-redis
```

`docker ps` 中应看到 `ygh-redis`，状态应为 `Up`。日志中不能出现配置文件读取失败、权限不足或端口占用错误。

以后手动停止、再次启动和重启 Redis 分别使用：

```bash
docker stop ygh-redis
docker start ygh-redis
docker restart ygh-redis
```

`--restart unless-stopped` 表示虚拟机重启后 Docker 会自动恢复该容器；如果客户手动执行了 `docker stop`，需要手动执行 `docker start ygh-redis`。

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

### 容器操作提示
*   **查看启动失败原因**：如果执行 `docker run` 后容器没起来，立刻输入 `docker logs ygh-redis`。
*   **配置文件只读**：如果你不希望容器修改你的配置文件，可以写成 `-v /opt/docker_redis/conf/redis.conf:/etc/redis/redis.conf:ro`（末尾加 `:ro` 表示 Read-Only）。对于 `data` 目录，必须是读写权限。



#### 3. 启动命令（性能调优版）

本项目虚拟机只有 2 个 vCPU、3.5GB 内存，因此使用下面的资源限制启动，避免 Redis 挤占 MySQL 和 Nacos 的资源。

下面的命令与“第四步：执行挂载并启动容器”相同，只用于再次核对最终参数。如果前面已经成功创建 `ygh-redis`，不要重复执行，否则会提示容器名称冲突。

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

以下保留原文件中的详细迁移复核步骤：

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
ss -lntp | grep ':6379' || echo '源码版 Redis 已停止，6379 端口已释放'
```

执行后必须看到“源码版 Redis 已停止，6379 端口已释放”，才能启动 Docker Redis。迁移完成后不要再执行 `/usr/local/redis/bin/redis-server`。

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

如果已经在前面的“第四步：执行挂载并启动容器”中成功创建 `ygh-redis`，本阶段只核对命令参数，不要再次执行。只有前面尚未创建容器时才执行：

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

这条命令执行在 Rocky Linux 虚拟机 SSH 终端，但 Redis 进程实际运行在该虚拟机的 Docker 容器 `ygh-redis` 中，不是直接运行在虚拟机系统中。

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

本项目 Java 服务在 Windows 本机 IDEA 中运行，Redis 最终且唯一运行在 Rocky Linux 虚拟机内的 Docker 容器 `ygh-redis` 中。代码不需要上传到 Redis，Java 服务通过虚拟机 IP 连接 Redis。

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
