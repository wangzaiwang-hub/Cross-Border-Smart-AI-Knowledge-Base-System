# Nacos 3.1.1 Docker 镜像手工安装与项目配置操作文档

## 第一部分：检查 MySQL、Docker 和虚拟机网络

### 第一步：从 Windows 登录 Rocky Linux 虚拟机

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
ssh root@192.168.154.10
```

如果客户使用的 SSH 用户不是 `root`，只替换 `root`，不要修改 IP 和端口。登录成功后提示符会变成类似 `[root@localhost ~]#`。

**执行后的结果**：后续命令默认在 Rocky Linux 虚拟机 SSH 终端执行；只有明确写着 Windows、浏览器、WinSCP 或 IDEA 的步骤才回到本机操作。

**需要修改的内容**：客户虚拟机不是 `192.168.154.10` 时，记录实际固定 IP。本文后续端口映射、防火墙、浏览器地址和 IDEA 变量中的 IP 必须一起替换。

### 第二步：确认 Docker 已安装在虚拟机中

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

输入：

```bash
docker version
docker info | sed -n '/Registry Mirrors/,+5p'
```

**执行后的结果**：`docker version` 必须同时显示 Client 和 Server；Registry Mirrors 应显示已经配置的镜像代理或客户企业仓库。

**失败时怎么处理**：提示 `docker: command not found` 或无法连接 daemon 时，不继续安装 Nacos，先按照 Redis 操作文档完成 Rocky Linux Docker Engine 和镜像代理配置。Nacos 最终安装在 Rocky Linux 虚拟机内部的 Docker 中，不安装到 Windows、WSL2 或 Windows Docker Desktop。

### 第三步：确认 MySQL 容器健康

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

输入：

```bash
docker ps --filter name=ygh-mysql
docker inspect ygh-mysql --format 'Status={{.State.Status}} Health={{.State.Health.Status}}'
docker network inspect ygh-core --format '{{range .Containers}}{{println .Name .IPv4Address}}{{end}}'
```

**执行后的结果**：

- `ygh-mysql` 必须是 `running` 和 `healthy`。
- Docker 网络必须叫 `ygh-core`。
- 网络列表中必须出现 `ygh-mysql` 和一个 Docker 内部地址。

Nacos 通过 Docker 网络中的容器名 `ygh-mysql` 连接数据库，不使用 Windows 地址，也不使用 `localhost`。

**失败时怎么处理**：MySQL 不健康时先回到 MySQL 操作文档排查；`network ygh-core not found` 时说明 MySQL 没有按项目要求启动，不能临时创建另一个网络继续。

### 第四步：检查 Nacos 数据库、账号和十张表

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

输入：

```bash
docker exec -e MYSQL_HISTFILE=/dev/null -it ygh-mysql mysql -unacos -p nacos_config
```

出现 `Enter password:` 后，输入 MySQL 文档中为数据库账号 `nacos` 保存的密码。这里输入的是 **Nacos 数据库账号密码**，不是 Nacos 控制台管理员密码。

进入 `mysql>` 后逐条输入：

```sql
SELECT CURRENT_USER(), DATABASE();
SHOW TABLES;
SELECT COUNT(*) AS table_count
FROM information_schema.tables
WHERE table_schema='nacos_config';
EXIT;
```

**执行后的结果**：当前用户应为 `nacos@%`，数据库应为 `nacos_config`，表数量应为 10。十张表应完整包含：

```text
config_info
config_info_gray
config_tags_relation
group_capacity
his_config_info
tenant_capacity
tenant_info
users
roles
permissions
```

**失败时怎么处理**：

- `Access denied`：数据库账号密码错误，回到 MySQL 文档检查 `nacos@%`。
- `Unknown database`：没有创建 `nacos_config`。
- 表数量为 0：没有导入项目文件 `01-nacos-schema.sql`。
- 表数量不是 10：停止操作，检查导入是否中断，不要直接删除数据库重建。

### 第五步：检查 8080、8848 和 9848 是否空闲

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

输入：

```bash
ip -br address
sudo ss -lntp | grep -E ':(8080|8848|9848)\b' || echo 'Nacos 三个端口均空闲'
docker ps -a --filter name=ygh-nacos
```

**执行后的结果**：虚拟机应具有 `192.168.154.10/24`；三个端口应为空闲；不应存在名为 `ygh-nacos` 的旧容器。

**需要修改的内容**：如果发现旧容器，不要直接执行 `docker rm -f`。先运行 `docker inspect ygh-nacos` 和 `docker logs --tail 200 ygh-nacos`，确认它是否属于现有系统。端口被其他程序占用时先查清进程归属。

## 第二部分：手动拉取或上传 Nacos 3.1.1 镜像

### 第一步：从官方页面确认版本并拉取项目固定镜像

**在哪里操作**：Windows 本机浏览器。

1. 打开 Nacos 官方 Docker 镜像仓库：`https://hub.docker.com/r/nacos/nacos-server`。
2. 点击页面中的 `Tags`。
3. 在标签搜索框输入 `v3.1.1`。
4. 确认列表中存在完整标签 `nacos/nacos-server:v3.1.1`。
5. 另开标签页打开 Nacos 官方 Docker 快速开始：`https://nacos.io/docs/latest/quickstart/quick-start-docker/`，确认 Nacos 3 使用 8080、8848 和 9848 三个端口。

浏览器页面用于核对官方仓库、版本和用法，不点击下载 ZIP。Docker 镜像由虚拟机中的 Docker Engine 分层拉取。

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

输入：

```bash
docker pull nacos/nacos-server:v3.1.1
```

**执行后的结果**：最后应显示 `Downloaded newer image` 或 `Image is up to date`，镜像名称必须为 `nacos/nacos-server:v3.1.1`。

**为什么不能使用 latest**：项目固定使用 Nacos 3.1.1，不能改成 `latest`、`v2.x` 或其他补丁版本。Nacos 3 的控制台端口、管理接口和管理员初始化方式与旧版本不同。

### 第二步：官方拉取失败时逐个检测代理

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

先检测代理端点：

```bash
curl -L -sS --connect-timeout 10 -o /dev/null -w 'DaoCloud: %{http_code}\n' https://docker.m.daocloud.io/v2/
curl -L -sS --connect-timeout 10 -o /dev/null -w '1ms: %{http_code}\n' https://docker.1ms.run/v2/
```

返回 `200` 或 `401` 表示 Registry 可达；`403` 表示拒绝；`429` 表示限流；`5xx` 表示代理异常；`000` 或超时表示网络不可用。

**执行后的结果**：只使用返回 `200` 或 `401` 的代理。两个代理都不可达时，不继续反复拉取，改用本部分离线镜像上传流程。

DaoCloud 可达时输入：

```bash
docker pull docker.m.daocloud.io/nacos/nacos-server:v3.1.1
docker tag docker.m.daocloud.io/nacos/nacos-server:v3.1.1 nacos/nacos-server:v3.1.1
```

1ms 可达时输入：

```bash
docker pull docker.1ms.run/nacos/nacos-server:v3.1.1
docker tag docker.1ms.run/nacos/nacos-server:v3.1.1 nacos/nacos-server:v3.1.1
```

两种代理只选择当前检测可达的一种。第二条命令把代理镜像统一标记成项目固定名称，后面的启动命令不需要随代理变化。

### 第三步：核对镜像架构、标签和摘要

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

输入：

```bash
docker image inspect nacos/nacos-server:v3.1.1 --format 'ARCH={{.Architecture}} OS={{.Os}} TAGS={{json .RepoTags}} DIGESTS={{json .RepoDigests}}'
```

**执行后的结果**：架构应为 `amd64`，操作系统应为 `linux`，标签应包含 `nacos/nacos-server:v3.1.1`。

项目锁定摘要：

```text
多架构标签摘要：sha256:13e74786507abbacebe080fae2fc9c05aa2591eb99c97a0a78ff0e72beb21b13
Linux amd64 平台摘要：sha256:9e4d25248c4a60212829e6ee49350af3d2a2e2c2849c789e80bffd25870a7e79
```

镜像版本或平台不一致时不要启动。先执行 `docker image rm nacos/nacos-server:v3.1.1` 删除错误标签，再重新拉取正确镜像；如果镜像正在被旧容器使用，先查清旧容器，不能强制删除。

### 第四步：虚拟机不能联网时制作镜像包

**在哪里操作**：可以联网且已安装 Docker Desktop 的 Windows PowerShell。

输入：

```powershell
docker pull --platform linux/amd64 nacos/nacos-server:v3.1.1
New-Item -ItemType Directory -Force 'D:\delivery-images'
docker save -o 'D:\delivery-images\nacos-server-v3.1.1.tar' nacos/nacos-server:v3.1.1
Get-FileHash 'D:\delivery-images\nacos-server-v3.1.1.tar' -Algorithm SHA256
```

**执行后的结果**：`D:\delivery-images` 中出现 `nacos-server-v3.1.1.tar`，PowerShell 输出该 tar 文件的 SHA256。保存这串校验值。

### 第五步：使用 WinSCP 上传镜像包

**在哪里操作**：先回到 Rocky Linux 虚拟机 SSH 终端。

输入：

```bash
whoami
sudo mkdir -p /opt/images
sudo chown "$USER":"$USER" /opt/images
sudo chmod 750 /opt/images
ls -ld /opt/images
```

**执行后的结果**：`/opt/images` 的所有者应与 `whoami` 输出一致。不要使用 `chmod 777`。

**在哪里操作**：Windows 本机 WinSCP。

1. 打开 WinSCP，点击 `新建站点`。
2. 文件协议选择 `SFTP`。
3. 主机名填写 `192.168.154.10`，端口填写 `22`。
4. 用户名和密码填写刚才 `whoami` 对应的 SSH 账号。
5. 点击 `登录`，首次连接时核对主机 IP 后接受主机密钥。
6. 左侧进入 `D:\delivery-images`。
7. 右侧进入 `/opt/images`。
8. 把 `nacos-server-v3.1.1.tar` 拖到右侧，等待进度达到 100%。

上传完成后，右侧应出现：

```text
/opt/images/nacos-server-v3.1.1.tar
```

### 第六步：校验并导入离线镜像

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

输入：

```bash
sha256sum /opt/images/nacos-server-v3.1.1.tar
docker load -i /opt/images/nacos-server-v3.1.1.tar
docker image inspect nacos/nacos-server:v3.1.1 --format '{{json .RepoTags}} {{.Architecture}}'
```

**执行后的结果**：Linux 的 SHA256 必须与 Windows 一致；`docker load` 应显示 `Loaded image: nacos/nacos-server:v3.1.1`；最终架构应为 `amd64`。

这个 tar 是 Docker 镜像包，不是 Nacos 源码包，也不是 Java 项目压缩包。不要解压后把内部文件逐个上传。

## 第三部分：手工创建 Nacos 密钥目录和四项启动密钥

### 第一步：创建 Nacos 目录

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

输入：

```bash
sudo mkdir -p /opt/docker_nacos/secrets
sudo mkdir -p /opt/nacos-backups
sudo chown "$USER":"$USER" /opt/nacos-backups
sudo chmod 750 /opt/nacos-backups
sudo chmod 700 /opt/docker_nacos/secrets
sudo ls -ld /opt/docker_nacos/secrets /opt/nacos-backups
```

**目录用途**：

- `/opt/docker_nacos/secrets`：保存 Nacos 连接 MySQL 及服务端认证所需的四项密钥，只允许 root 读取。
- `/opt/nacos-backups`：保存手工导出的 Nacos 配置数据库备份，允许当前 SSH 用户写入。

Nacos 的配置数据最终保存在 MySQL 的 `nacos_config` 中，不在 Windows、WSL 或 Nacos 容器内另建业务数据目录。

**执行后的结果**：`secrets` 目录应为 root 所有且权限 700；`nacos-backups` 应为当前 SSH 用户所有且权限 750。

### 第二步：保存 Nacos 数据库账号密码

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

输入：

```bash
sudo vi /opt/docker_nacos/secrets/mysql-password
```

按 `i` 进入编辑模式，只输入 MySQL 文档中 `nacos@%` 的真实密码，不加引号、不加空格。按 `Esc`，输入 `:wq` 并回车保存。

设置权限：

```bash
sudo chown root:root /opt/docker_nacos/secrets/mysql-password
sudo chmod 600 /opt/docker_nacos/secrets/mysql-password
sudo stat -c '%U %G %a %n' /opt/docker_nacos/secrets/mysql-password
```

**执行后的结果**：应显示 `root root 600`。不要用 `cat` 把密码打印到屏幕。

### 第三步：生成并保存 NACOS_AUTH_TOKEN

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

先生成 48 字节随机值并进行 Base64 编码：

```bash
openssl rand -base64 48
```

复制输出，立即保存到客户密码管理器，名称写成 `NACOS_AUTH_TOKEN`。然后输入：

```bash
sudo vi /opt/docker_nacos/secrets/auth-token
```

按 `i`，粘贴刚生成的一行 Base64 字符串；按 `Esc`，输入 `:wq` 保存。继续输入：

```bash
sudo chown root:root /opt/docker_nacos/secrets/auth-token
sudo chmod 600 /opt/docker_nacos/secrets/auth-token
sudo wc -c /opt/docker_nacos/secrets/auth-token
```

**执行后的结果**：字符数应大于 32。这个 Token 用于 Nacos JWT 签名，不是控制台登录密码，不能写成 `nacos` 或 `123456`。

### 第四步：生成 NACOS_AUTH_IDENTITY_KEY

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

输入：

```bash
openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | head -c 32; echo
```

把输出保存到密码管理器，名称写成 `NACOS_AUTH_IDENTITY_KEY`。然后打开文件：

```bash
sudo vi /opt/docker_nacos/secrets/identity-key
```

按 `i`，粘贴 32 位值；按 `Esc`，输入 `:wq` 保存。设置权限：

```bash
sudo chown root:root /opt/docker_nacos/secrets/identity-key
sudo chmod 600 /opt/docker_nacos/secrets/identity-key
```

**执行后的结果**：`identity-key` 文件存在且权限为 600；密码管理器中已保存同名值。不要在终端执行 `cat` 验证内容。

### 第五步：生成 NACOS_AUTH_IDENTITY_VALUE

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

再次执行一次随机生成命令：

```bash
openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | head -c 32; echo
```

这次输出必须与 Identity Key 不同。保存到密码管理器，名称写成 `NACOS_AUTH_IDENTITY_VALUE`。然后输入：

```bash
sudo vi /opt/docker_nacos/secrets/identity-value
```

按 `i` 粘贴本次输出，按 `Esc`，输入 `:wq` 保存。设置权限：

```bash
sudo chown root:root /opt/docker_nacos/secrets/identity-value
sudo chmod 600 /opt/docker_nacos/secrets/identity-value
sudo stat -c '%U %G %a %n' /opt/docker_nacos/secrets/*
```

**执行后的结果**：四个文件都应显示 `root root 600`。Identity Key 和 Identity Value 是 Nacos 服务端内部接口身份，不是用户名和密码，不能使用相同值。

### 第六步：检查密钥文件非空但不显示内容

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

输入：

```bash
sudo test -s /opt/docker_nacos/secrets/mysql-password && echo 'OK mysql-password' || echo 'EMPTY mysql-password'
sudo test -s /opt/docker_nacos/secrets/auth-token && echo 'OK auth-token' || echo 'EMPTY auth-token'
sudo test -s /opt/docker_nacos/secrets/identity-key && echo 'OK identity-key' || echo 'EMPTY identity-key'
sudo test -s /opt/docker_nacos/secrets/identity-value && echo 'OK identity-value' || echo 'EMPTY identity-value'
```

**执行后的结果**：四行都以 `OK` 开头，不应出现 `EMPTY`。这条命令只检查文件大小，不打印密钥。

## 第四部分：手工启动 Nacos 3.1.1 容器

### 第一步：再次确认 MySQL 和 Docker 网络

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

输入：

```bash
docker inspect ygh-mysql --format 'MySQL={{.State.Health.Status}}'
docker network inspect ygh-core --format '{{range .Containers}}{{println .Name}}{{end}}'
```

必须看到 `MySQL=healthy` 和 `ygh-mysql`。只有这两项正确，才执行下一步。

### 第二步：执行首次启动命令

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

完整输入：

```bash
docker run -d \
  --name ygh-nacos \
  --network ygh-core \
  --cpus="0.70" \
  --memory="768m" \
  -p 192.168.154.10:8080:8080 \
  -p 192.168.154.10:8848:8848 \
  -p 192.168.154.10:9848:9848 \
  -e TZ=Asia/Shanghai \
  -e MODE=standalone \
  -e PREFER_HOST_MODE=hostname \
  -e SPRING_DATASOURCE_PLATFORM=mysql \
  -e MYSQL_SERVICE_HOST=ygh-mysql \
  -e MYSQL_SERVICE_PORT=3306 \
  -e MYSQL_SERVICE_DB_NAME=nacos_config \
  -e MYSQL_SERVICE_USER=nacos \
  -e MYSQL_SERVICE_PASSWORD="$(sudo cat /opt/docker_nacos/secrets/mysql-password | tr -d '\r\n')" \
  -e MYSQL_DATABASE_NUM=1 \
  -e 'MYSQL_SERVICE_DB_PARAM=characterEncoding=utf8&connectTimeout=3000&socketTimeout=5000&autoReconnect=true&useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=Asia/Shanghai' \
  -e NACOS_AUTH_ENABLE=true \
  -e NACOS_AUTH_ADMIN_ENABLE=true \
  -e NACOS_AUTH_CONSOLE_ENABLE=true \
  -e NACOS_AUTH_SYSTEM_TYPE=nacos \
  -e NACOS_AUTH_TOKEN="$(sudo cat /opt/docker_nacos/secrets/auth-token | tr -d '\r\n')" \
  -e NACOS_AUTH_IDENTITY_KEY="$(sudo cat /opt/docker_nacos/secrets/identity-key | tr -d '\r\n')" \
  -e NACOS_AUTH_IDENTITY_VALUE="$(sudo cat /opt/docker_nacos/secrets/identity-value | tr -d '\r\n')" \
  -e JVM_XMS=384m \
  -e JVM_XMX=384m \
  -e JVM_XMN=128m \
  --health-cmd='curl -fsS http://127.0.0.1:8848/nacos/v3/admin/core/state/readiness >/dev/null' \
  --health-interval=15s \
  --health-timeout=5s \
  --health-retries=30 \
  --health-start-period=90s \
  --log-driver json-file \
  --log-opt max-size=10m \
  --log-opt max-file=3 \
  --restart unless-stopped \
  nacos/nacos-server:v3.1.1
```

**执行后的结果**：Docker 输出一串容器 ID。Nacos 首次启动会连接 MySQL、初始化多个应用上下文，当前虚拟机上可能需要 1 至 3 分钟。

**需要修改的内容**：

- 虚拟机固定 IP 不同时，只替换三行 `-p` 前面的 `192.168.154.10`。
- MySQL 容器按本文配套文档安装时，主机名保持 `ygh-mysql`，不要改成 `localhost` 或虚拟机 IP。
- 不要修改三个端口、镜像版本、384MB JVM 堆、768MB 容器上限和容器名。

命令中的四个 `sudo cat` 只把 root 密钥文件读取到容器环境变量，没有要求客户建立 `.env` 文件，也没有把真实密码直接写进命令历史。Nacos 镜像只能通过环境变量接收这些值，因此具有 Docker daemon 管理权限的用户仍可通过容器详情读取环境变量；只允许受信任管理员加入 `docker` 用户组，普通业务用户不得拥有 Docker 权限。

### 第三步：等待容器变为 healthy

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

输入：

```bash
docker ps --filter name=ygh-nacos
docker inspect ygh-nacos --format 'Status={{.State.Status}} Health={{.State.Health.Status}} Restarts={{.RestartCount}}'
docker logs --tail 200 ygh-nacos
```

每隔 15 秒重新执行一次 `docker inspect`，直到显示：

```text
Status=running Health=healthy Restarts=0
```

日志中应出现类似 `Nacos started successfully in stand alone mode` 的成功信息。

**失败时怎么处理**：

- 一直是 `starting`：继续等待，不要重复执行 `docker run`。
- `unhealthy`：执行 `docker inspect ygh-nacos --format '{{json .State.Health}}'` 查看探测错误。
- 反复重启：检查 MySQL 密码、`ygh-mysql` 网络名称和内存限制。
- 日志出现 `Access denied for user 'nacos'`：Nacos 数据库密码文件与 MySQL 账号密码不一致。
- 日志出现 `Unknown database 'nacos_config'`：MySQL 数据库未创建。
- 日志出现表不存在：Nacos 十张表未完整导入。

### 第四步：验证两个健康端点

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

输入：

```bash
curl -i http://192.168.154.10:8848/nacos/v3/admin/core/state/readiness
curl -i http://192.168.154.10:8080/v3/console/health/readiness
```

**执行后的结果**：两个请求都应返回 HTTP `200`。8848 是 Nacos 服务端和客户端接口，8080 是 Nacos 3 控制台接口；不能只验证控制台页面就认为服务注册接口正常。

### 第五步：核对端口映射、资源和日志限制

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

输入：

```bash
docker port ygh-nacos
docker stats --no-stream ygh-nacos
docker inspect ygh-nacos --format 'Memory={{.HostConfig.Memory}} NanoCpus={{.HostConfig.NanoCpus}} Restart={{.HostConfig.RestartPolicy.Name}} Log={{.HostConfig.LogConfig.Type}} {{json .HostConfig.LogConfig.Config}}'
```

**执行后的结果**：

- 8080、8848、9848 都绑定到 `192.168.154.10`。
- Memory 为 805306368 字节，即 768MB。
- NanoCpus 为 700000000，即 0.70 CPU。
- Restart 为 `unless-stopped`。
- 日志驱动为 `json-file`，单文件 10MB，最多 3 个。

Nacos 在当前实测环境中接近 700MB，属于本项目低配置场景的主要内存占用。不能随意把容器上限降低到 512MB。

## 第五部分：手动初始化 Nacos 管理员

### 第一步：从 Windows 打开 Nacos 3 控制台

**在哪里操作**：Windows 本机浏览器。

地址栏输入：

```text
http://192.168.154.10:8080/index.html
```

按回车。Nacos 3 的控制台使用 8080，不是旧教程常写的 `8848/nacos`。

**执行后的结果**：第一次打开时应出现管理员初始化页面，要求为管理员用户 `nacos` 设置密码。

**失败时怎么处理**：页面打不开时先不要修改 Nacos 配置，回到虚拟机执行 `docker inspect ygh-nacos` 和两个健康端点检查；如果虚拟机内正常而 Windows 不通，继续完成第七部分防火墙。

### 第二步：生成管理员密码

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

输入：

```bash
openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | head -c 32; echo
```

把输出立即保存到客户密码管理器，名称写成：

```text
Nacos 控制台管理员 nacos 密码
```

这个密码与 MySQL 的 `nacos` 数据库账号密码不是同一个密码，也不能与 `NACOS_AUTH_TOKEN`、Identity Key 或 Identity Value 共用。

**执行后的结果**：密码管理器新增一条 32 位管理员密码记录。只有确认记录已经保存，才回浏览器填写初始化页面。

### 第三步：在初始化页面设置密码

**在哪里操作**：Windows 本机浏览器的 Nacos 初始化页面。

1. 用户名保持页面固定的 `nacos`。
2. 在“密码”输入框粘贴刚生成的管理员密码。
3. 在“确认密码”输入框再次粘贴相同密码。
4. 检查两次输入完全一致。
5. 点击页面上的 `提交`、`初始化` 或当前版本对应的确认按钮。

**执行后的结果**：页面提示初始化成功，并进入登录页或直接进入 Nacos 控制台。

**注意事项**：如果页面显示管理员已经初始化，不要反复初始化。直接使用密码管理器中已有的管理员密码登录；如果密码来源不明，按故障恢复流程处理，不能删除 `users` 表。

### 第四步：登录控制台

**在哪里操作**：Windows 本机浏览器。

在登录页面填写：

```text
用户名：nacos
密码：密码管理器中刚保存的管理员密码
```

点击 `登录`。

**执行后的结果**：进入 Nacos 控制台，左侧应看到“服务管理”“配置管理”“命名空间”等菜单。

### 第五步：用登录接口再次验证认证

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

先安全读取密码，不把密码写进命令历史：

```bash
read -s -p '请输入 Nacos 管理员密码: ' NACOS_ADMIN_PASSWORD; echo
```

再输入：

```bash
curl -sS -X POST 'http://192.168.154.10:8848/nacos/v3/auth/user/login' \
  --data-urlencode 'username=nacos' \
  --data-urlencode "password=${NACOS_ADMIN_PASSWORD}"
unset NACOS_ADMIN_PASSWORD
```

**执行后的结果**：响应中应包含 `accessToken`。不要把完整响应截图或发送给他人，因为其中的 access token 是临时登录凭据。

如果返回用户名或密码错误，先回浏览器确认能否登录，不要重复初始化数据库。

## 第六部分：手动创建项目命名空间 ygh-dev

### 第一步：打开命名空间页面

**在哪里操作**：Windows 本机浏览器，保持 Nacos 管理员登录状态。

1. 点击左侧 `命名空间`。
2. 检查列表中是否已经存在 ID 为 `ygh-dev` 的命名空间。
3. 如果已经存在，点击该行查看名称和描述，确认属于本项目，然后跳到第四步验证。
4. 如果不存在，点击页面右上角 `新建命名空间`。

**执行后的结果**：已存在时确认 ID 正确；不存在时应打开“新建命名空间”窗口。没有管理员权限时按钮可能不可用，需要重新使用 `nacos` 管理员登录。

### 第二步：填写命名空间

**在哪里操作**：Windows 本机浏览器的“新建命名空间”窗口。

在弹出的窗口中填写：

```text
命名空间 ID：ygh-dev
命名空间名：ygh-dev
描述：跨境智汇 AI 知识库系统开发环境
```

字段名称可能显示为“自定义命名空间 ID”“Namespace ID”或“命名空间ID”，必须填写固定值 `ygh-dev`，不能让系统自动生成 UUID。

**执行后的结果**：保存前，三个输入框分别显示固定 ID、显示名称和项目描述；ID 输入框必须确实包含 `ygh-dev`。

### 第三步：保存命名空间

**在哪里操作**：Windows 本机浏览器的“新建命名空间”窗口。

1. 再次检查 ID 是 `ygh-dev`，中间使用短横线，不是下划线。
2. 点击 `确定` 或 `创建`。
3. 等待页面提示创建成功。

**执行后的结果**：命名空间列表出现 `ygh-dev`，类型为自定义命名空间。项目 Java 服务默认读取这个 ID。

### 第四步：验证 MySQL 中的命名空间记录

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

输入：

```bash
docker exec -e MYSQL_HISTFILE=/dev/null -it ygh-mysql mysql -unacos -p nacos_config
```

输入 Nacos **数据库账号密码**，进入 `mysql>` 后输入：

```sql
SELECT tenant_id,tenant_name,tenant_desc
FROM tenant_info
WHERE tenant_id='ygh-dev';
EXIT;
```

**执行后的结果**：必须返回一行，`tenant_id` 和 `tenant_name` 都是 `ygh-dev`。没有结果时回到浏览器检查是否只是填写了名称但让 ID 自动生成了 UUID；发现 ID 错误时，先确认命名空间中没有配置和服务实例，再通过控制台删除错误项并重新创建。

### 第五步：确认项目使用的服务分组

**在哪里操作**：Windows 本机浏览器 Nacos 控制台；本步骤只核对固定值，不需要新建分组。

项目服务发现分组固定为：

```text
YGH_GROUP
```

Nacos 不需要提前创建空分组。Java 服务第一次注册时会在 `ygh-dev` 命名空间中出现 `YGH_GROUP`。不要在控制台手工创建一个名为 `DEFAULT_GROUP` 的替代分组。

**执行后的结果**：本步骤不产生新记录，只确认后续 IDEA 变量统一使用 `YGH_GROUP`。

## 第七部分：配置防火墙并验证 Windows 连通性

### 第一步：查明 Windows 的 VMnet8 地址

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
ipconfig
```

找到 `VMware Network Adapter VMnet8`，记录 IPv4 地址。当前项目环境通常是：

```text
192.168.154.1
```

如果客户显示不同地址，后面的防火墙来源地址必须使用客户实际 VMnet8 IPv4。

**执行后的结果**：记录一个与虚拟机同属 VMware 私有网段的 Windows IPv4，例如 `192.168.154.1`。不要误记无线网卡、以太网或 VPN 地址。

### 第二步：只允许 Windows 宿主机访问 Nacos 端口

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

当前 VMnet8 地址为 `192.168.154.1` 时输入：

```bash
sudo firewall-cmd --permanent --add-rich-rule='rule family=ipv4 source address=192.168.154.1/32 port port=8080 protocol=tcp accept'
sudo firewall-cmd --permanent --add-rich-rule='rule family=ipv4 source address=192.168.154.1/32 port port=8848 protocol=tcp accept'
sudo firewall-cmd --permanent --add-rich-rule='rule family=ipv4 source address=192.168.154.1/32 port port=9848 protocol=tcp accept'
sudo firewall-cmd --reload
sudo firewall-cmd --list-rich-rules
```

**执行后的结果**：规则列表应分别显示来源 `192.168.154.1/32` 和 8080、8848、9848 三个端口。

Nacos 是内部基础组件，不能把这些端口开放给公网或 `0.0.0.0/0`。9848 是 Nacos 客户端 gRPC 通信端口，即使浏览器不访问，也必须允许 IDEA 中的 Java 客户端访问。

### 第三步：从 Windows 检查三个端口

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
Test-NetConnection 192.168.154.10 -Port 8080
Test-NetConnection 192.168.154.10 -Port 8848
Test-NetConnection 192.168.154.10 -Port 9848
```

**执行后的结果**：三个结果都必须显示 `TcpTestSucceeded : True`。

如果只有 8080 成功，浏览器虽然能打开，但 Java 服务仍无法正常注册；继续检查 8848 和 9848 的端口映射与防火墙。

### 第四步：从 Windows 浏览器再次验证控制台

**在哪里操作**：Windows 本机浏览器。

打开：

```text
http://192.168.154.10:8080/index.html
```

使用 `nacos` 和真实管理员密码登录，确认能看到 `ygh-dev` 命名空间。验证结束后退出公共电脑上的登录状态，不让浏览器保存管理员密码。

**执行后的结果**：控制台可以登录，命名空间列表存在 `ygh-dev`。

## 第八部分：在 IDEA 中逐个配置 Nacos 服务发现

### 第一步：打开一个 Java 服务运行配置

**在哪里操作**：Windows 本机 IntelliJ IDEA。

1. 使用 IDEA 打开客户解压后的项目根目录。
2. 等待 Maven 导入和索引完成。
3. 点击 `Run` → `Edit Configurations...`。
4. 选择当前要启动的 Spring Boot 服务运行配置。
5. 找到 `Environment variables`，点击右侧编辑按钮。

Java 服务由 Windows 本机 IDEA 启动，Nacos 在虚拟机 Docker 中。不要把 Java 源码复制到 Nacos 容器，也不要在 Nacos 容器中安装 JDK。

**执行后的结果**：屏幕停留在当前 Java 服务的环境变量编辑窗口，尚未启动服务。

### 第二步：填写五个公共 Nacos 变量

**在哪里操作**：Windows 本机 IntelliJ IDEA 当前服务的 `Environment variables` 窗口。

每一个需要注册 Nacos 的 Java 服务都填写：

```text
YGH_NACOS_SERVER_ADDR=192.168.154.10:8848
YGH_NACOS_USERNAME=nacos
YGH_NACOS_PASSWORD=填写 Nacos 控制台管理员真实密码
YGH_NACOS_NAMESPACE=ygh-dev
YGH_NACOS_DISCOVERY_GROUP=YGH_GROUP
```

**需要修改的内容**：

- 虚拟机 IP 不同时修改 `YGH_NACOS_SERVER_ADDR`。
- `YGH_NACOS_PASSWORD` 填控制台管理员密码，不填 MySQL `nacos` 账号密码。
- namespace 和 group 保持固定，不改成 `public` 或 `DEFAULT_GROUP`。

这些变量填写在 IDEA 当前运行配置中，不写入 `application.yml`，不建立 `.env` 文件。

**执行后的结果**：当前运行配置中能逐行看到五个变量名；密码值只保存在本机 IDEA 私有运行配置中，不出现在项目源码差异里。

### 第三步：填写 Windows 服务注册地址

**在哪里操作**：Windows 本机 IntelliJ IDEA 当前服务的 `Environment variables` 窗口。

IDEA 中启动的服务必须向 Nacos 注册 Windows VMnet8 地址，不能注册 `127.0.0.1`、Docker 内部地址或错误网卡。

| IDEA 运行配置 | 额外变量 | 当前值 |
|---|---|---|
| `ygh-gateway` | `YGH_SERVICE_IP` | `192.168.154.1` |
| `ygh-auth-service` | `YGH_AUTH_ADVERTISE_IP` | `192.168.154.1` |
| `ygh-user-service` | `YGH_USER_ADVERTISE_IP` | `192.168.154.1` |
| `ygh-system-service` | `YGH_SYSTEM_ADVERTISE_IP` | `192.168.154.1` |

客户 VMnet8 地址不同时，把表中的 `192.168.154.1` 全部替换成实际地址。其余服务当前配置由 Nacos 客户端自动选择网卡；在最终逐服务启动时必须到控制台检查实际注册 IP。

**执行后的结果**：当前要启动的服务如果在表中，应存在对应注册地址变量，并填写 Windows VMnet8 IPv4。

### 第四步：先运行数据库迁移入口

**在哪里操作**：Windows 本机 IntelliJ IDEA。

完成 Nacos 后，返回 MySQL 操作文档第八部分，按顺序运行：

```text
DB-Migrate-auth
DB-Migrate-user
DB-Migrate-system
```

三个迁移入口不会注册 Nacos，但会读取 Nacos 必填变量。必须看到 `Process finished with exit code 0`，再完成 MySQL 文档中的表级授权。

### 第五步：启动第一个普通服务并检查注册

**在哪里操作**：Windows 本机 IntelliJ IDEA。

项目完整启动顺序在最终项目启动文档中执行。检查 Nacos 时一次只启动一个服务，在 IDEA 点击绿色三角形后观察日志：

```text
不能出现 NacosException
不能出现 user not found 或 invalid token
不能出现 connection refused 192.168.154.10:8848
不能出现 gRPC 9848 连接失败
```

**执行后的结果**：IDEA 控制台显示服务完成启动且没有上述错误，然后才能到 Nacos 控制台检查实例。

### 第六步：在控制台验证服务实例

**在哪里操作**：Windows 浏览器 Nacos 控制台。

1. 登录 `http://192.168.154.10:8080/index.html`。
2. 切换命名空间为 `ygh-dev`。
3. 点击 `服务管理` → `服务列表`。
4. Group 选择或确认 `YGH_GROUP`。
5. 找到刚启动的服务名。
6. 点击服务详情，查看实例 IP、端口和健康状态。

**执行后的结果**：实例应为健康状态，IP 应是 Windows VMnet8 地址 `192.168.154.1`，端口应与 IDEA 中该服务的 `server.port` 一致。

如果 IP 是 `127.0.0.1` 或其他网卡地址，先停止 IDEA 服务，修正对应 Advertise IP 变量，再重新启动。不能在 Nacos 控制台手工修改临时实例 IP。

### 第七步：停止服务并确认自动下线

**在哪里操作**：Windows 本机 IDEA。

点击当前服务 `Run` 窗口左侧红色方块，等待 Java 进程结束。回到 Nacos 服务列表刷新。

**执行后的结果**：临时实例应自动消失或很快变为不健康。停止的服务如果长期保持健康，说明存在另一个同名进程，必须检查 IDEA 和任务管理器，避免请求随机进入旧实例。

## 第九部分：日常停止、启动、重启和备份

### 第一步：停止 Nacos

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

先在 IDEA 停止所有正在注册 Nacos 的 Java 服务，再输入：

```bash
docker stop ygh-nacos
docker ps -a --filter name=ygh-nacos
```

**执行后的结果**：容器状态为 `Exited`。停止容器不会删除 MySQL 中的 `nacos_config` 数据。

### 第二步：再次启动 Nacos

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

输入：

```bash
docker start ygh-nacos
docker inspect ygh-nacos --format 'Status={{.State.Status}} Health={{.State.Health.Status}}'
```

等待 Health 重新变为 `healthy` 后，才能启动 IDEA Java 服务。

**执行后的结果**：容器为 `running`，Health 为 `healthy`。

### 第三步：重启 Nacos

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

输入：

```bash
docker restart ygh-nacos
docker logs --tail 200 ygh-nacos
docker inspect ygh-nacos --format 'Health={{.State.Health.Status}} Restarts={{.RestartCount}}'
```

重启用于应用容器级变更或排障，不用于解决未知错误。重启后仍不健康时检查日志和 MySQL，不能反复重启掩盖问题。

**执行后的结果**：日志重新出现启动成功信息，Health 最终回到 `healthy`。

### 第四步：验证 Docker 自动重启策略

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

输入：

```bash
docker inspect ygh-nacos --format '{{.HostConfig.RestartPolicy.Name}}'
```

应输出 `unless-stopped`。虚拟机重启后 Docker 会恢复 Nacos；如果管理员手工执行过 `docker stop`，需要手工 `docker start ygh-nacos`。

### 第五步：单独备份 Nacos 配置数据库

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

输入：

```bash
backup_file="/opt/nacos-backups/nacos-config-$(date +%Y%m%d-%H%M%S).sql"
docker exec ygh-mysql sh -c 'MYSQL_PWD="$(cat /run/secrets/mysql-root-password)" mysqldump -uroot --single-transaction --routines --events nacos_config' > "$backup_file"
sha256sum "$backup_file" > "$backup_file.sha256"
ls -lh "$backup_file" "$backup_file.sha256"
```

**执行后的结果**：SQL 文件必须大于 0 字节，并生成对应 `.sha256`。把两者一起复制到客户备份存储，不只保存在虚拟机系统盘。

这个备份包含命名空间、配置、Nacos 用户和权限。不要把 SQL 文件发到聊天工具或提交到项目仓库。

### 第六步：恢复前保护当前数据

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端；执行前先在 IDEA 停止全部 Java 服务。

恢复会覆盖或合并 Nacos 数据。必须先停止全部 Java 服务和 `ygh-nacos`，再备份当前 `nacos_config`。确认恢复文件来源和 SHA256 后才能执行：

```bash
sha256sum -c /opt/nacos-backups/要恢复的文件.sql.sha256
docker exec -i ygh-mysql sh -c 'MYSQL_PWD="$(cat /run/secrets/mysql-root-password)" mysql -uroot nacos_config' < /opt/nacos-backups/要恢复的文件.sql
docker start ygh-nacos
```

校验必须显示 `OK`。启动后重新验证健康端点、管理员登录和 `ygh-dev` 命名空间。恢复属于高风险操作，不知道备份版本时不要执行。

## 第十部分：常见错误逐项排查

### 1. `Access denied for user 'nacos'`

**在哪里排查**：Rocky Linux 虚拟机 SSH 终端。

Nacos 连接 MySQL 的密码错误。先用 `docker exec ... mysql -unacos -p nacos_config` 手工验证密码，再检查 `/opt/docker_nacos/secrets/mysql-password`。修改密钥文件不会自动更新已创建容器中的环境变量，必须按“安全重建容器”步骤重建。

### 2. `Unknown database 'nacos_config'`

**在哪里排查**：Rocky Linux 虚拟机 SSH 终端和 MySQL 客户端。

MySQL 中没有配置库。执行 `SHOW DATABASES;` 检查，回到 MySQL 文档创建数据库和账号，不要让 Nacos 改用内置 Derby 临时绕过。

### 3. 日志提示表不存在

**在哪里排查**：Rocky Linux 虚拟机 SSH 终端和 MySQL 客户端。

执行 `SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='nacos_config';`，结果必须是 10。使用项目固定文件 `ygh-deploy/constrained-dev/mysql/init/01-nacos-schema.sql` 手工导入，不从其他版本网页复制 SQL。

### 4. 容器一直 unhealthy

**在哪里排查**：Rocky Linux 虚拟机 SSH 终端。

输入：

```bash
docker inspect ygh-nacos --format '{{json .State.Health}}'
docker logs --tail 300 ygh-nacos
docker stats --no-stream ygh-nacos
```

重点检查 MySQL 连接、JVM 是否被 OOM、8848 readiness 返回值以及容器重启次数。

### 5. 控制台 8080 能打开，但 Java 服务注册失败

**在哪里排查**：Windows 本机 PowerShell。

分别检查 8848 和 9848：

```powershell
Test-NetConnection 192.168.154.10 -Port 8848
Test-NetConnection 192.168.154.10 -Port 9848
```

8848 是客户端请求端口，9848 是 gRPC 端口。只开放控制台端口不能完成服务注册。

### 6. Java 日志提示用户名或密码错误

**在哪里排查**：Windows 本机 IntelliJ IDEA。

IDEA 中 `YGH_NACOS_PASSWORD` 必须是 Nacos 控制台管理员密码，不是 MySQL 数据库账号 `nacos` 的密码。修改后点击 `Apply`、`OK`，停止旧 Java 进程并重新启动。

### 7. 控制台看不到服务

**在哪里排查**：Windows 本机浏览器 Nacos 控制台和 IntelliJ IDEA。

依次检查：

1. 当前命名空间是否为 `ygh-dev`。
2. Group 是否为 `YGH_GROUP`。
3. IDEA 日志是否完成注册。
4. 服务是否已经被停止。
5. 是否误看了 `public` 命名空间。

### 8. 服务注册 IP 错误

**在哪里排查**：Windows 本机 IntelliJ IDEA 运行配置。

Gateway 使用 `YGH_SERVICE_IP`，auth、user、system 分别使用自己的 `YGH_*_ADVERTISE_IP`。IDEA 在 Windows 运行时填写 VMnet8 地址 `192.168.154.1`。修改后必须重启服务，不能在控制台直接编辑临时实例。

### 9. 修改 Token 或 Identity 文件后没有生效

**在哪里排查**：Rocky Linux 虚拟机 SSH 终端。

Docker 容器在创建时保存环境变量。只修改宿主机文件不会改变现有容器。先完成 Nacos 数据库备份，再执行安全重建：

```bash
docker stop ygh-nacos
docker rename ygh-nacos ygh-nacos-backup
```

重新执行第四部分完整 `docker run`，等待新 `ygh-nacos` 健康并验证管理员登录。确认新容器稳定后才能删除旧容器：

```bash
docker rm ygh-nacos-backup
```

新容器失败时先删除失败的新容器，再把旧容器改回原名并启动：

```bash
docker rm -f ygh-nacos
docker rename ygh-nacos-backup ygh-nacos
docker start ygh-nacos
```

这组命令不会删除 MySQL 数据，但执行前仍必须备份 `nacos_config`。不要同时运行新旧两个 Nacos 容器占用同一端口。

### 10. Nacos 内存接近 768MB

**在哪里排查**：Rocky Linux 虚拟机 SSH 终端。

当前项目台账实测 Nacos 约使用 690MB，接近容器上限属于已知低配置环境现象。执行：

```bash
free -h
docker stats --no-stream ygh-mysql ygh-nacos
```

如果虚拟机可用内存不足，不要同时启动 PGVector 和全部 Java 服务。按项目场景逐组启动；不能通过取消 Nacos 内存限制把压力转移给虚拟机操作系统。
