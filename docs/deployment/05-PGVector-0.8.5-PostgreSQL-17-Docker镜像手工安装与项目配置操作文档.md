# PGVector 0.8.5 / PostgreSQL 17 Docker 镜像手工安装与项目配置操作文档

## 第一部分：检查虚拟机 Docker、网络和资源

### 第一步：从 Windows 登录 Rocky Linux 虚拟机

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
ssh root@192.168.154.10
```

如果 SSH 用户不是 `root`，只替换用户名。登录成功后提示符会变成类似 `[root@localhost ~]#`。

**执行后的结果**：后续命令默认在 Rocky Linux 虚拟机 SSH 终端输入；只有明确写着 Windows、WinSCP、浏览器或 IDEA 时才回到本机操作。

**需要修改的内容**：客户使用其他固定 IP 时，记录实际地址，并同步替换本文端口映射、防火墙、PowerShell 和 IDEA JDBC URL 中的 `192.168.154.10`。

### 第二步：确认 Docker 已安装在虚拟机中

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

输入：

```bash
docker version
docker info | sed -n '/Registry Mirrors/,+5p'
```

**执行后的结果**：Docker 必须同时显示 Client 和 Server；镜像代理应已配置。

**失败时怎么处理**：提示 `docker: command not found` 或无法连接 daemon 时，停止本文，回到 `01-Rocky Linux虚拟机从零配置指南.md` 安装并验证虚拟机 Docker Engine。PGVector 最终运行在 Rocky Linux 虚拟机内部的 Docker 中，不安装到 Windows、WSL2 或 Windows Docker Desktop。

### 第三步：确认 ygh-core 网络存在

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

输入：

```bash
docker network inspect ygh-core --format 'Network={{.Name}} Driver={{.Driver}}'
```

**执行后的结果**：应显示 `Network=ygh-core Driver=bridge`。该网络由 MySQL 安装步骤创建，PGVector 加入同一项目网络。

如果显示 `network ygh-core not found`，输入：

```bash
docker network create ygh-core
```

再次执行检查，确认网络存在后再继续。

### 第四步：检查虚拟机剩余内存和磁盘

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

输入：

```bash
free -h
df -h /
docker stats --no-stream
```

**执行后的结果**：启动 PGVector 前，虚拟机可用内存建议不少于 600MB，根分区可用空间建议不少于 3GB。PGVector 容器上限为 384MB，实测空载约 40MB，但导入向量和建立 HNSW 索引时内存、磁盘都会增加。

**失败时怎么处理**：内存不足时先在 IDEA 停止无关 Java 服务；不要停止 MySQL、Redis、Nacos后仍继续启动依赖它们的服务。磁盘不足时先清理确认无用的日志或旧镜像，不能删除未知 Docker 卷和 `/opt/docker_pgvector/data`。

### 第五步：检查 5432 端口和旧容器

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

输入：

```bash
ip -br address
sudo ss -lntp | grep ':5432'
docker ps -a --filter name=ygh-pgvector
```

**执行后的结果**：虚拟机应具有 `192.168.154.10/24`；第二条命令没有输出表示 5432 空闲；第三条命令没有输出表示不存在同名旧容器。

发现旧容器或旧 PostgreSQL 进程时先确认数据归属并完成备份，不能直接结束进程或执行 `docker rm -f`。

## 第二部分：手动拉取或上传固定 PGVector 镜像

### 第一步：从官方页面确认镜像标签

**在哪里操作**：Windows 本机浏览器。

1. 打开 PGVector 官方 Docker Hub 标签页：`https://hub.docker.com/r/pgvector/pgvector/tags`。
2. 在标签搜索框输入 `0.8.5-pg17-bookworm`。
3. 确认完整标签为 `pgvector/pgvector:0.8.5-pg17-bookworm`。
4. 打开 PGVector 官方 GitHub：`https://github.com/pgvector/pgvector`。
5. 在页面中查找 `Docker`，确认 PGVector 镜像基于对应 PostgreSQL 主版本运行。

**执行后的结果**：确认本项目组合是 PGVector 0.8.5、PostgreSQL 17、Debian Bookworm。浏览器只用于核对标签，不下载源码 ZIP，也不在虚拟机源码编译扩展。

### 第二步：拉取项目固定镜像

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

输入：

```bash
docker pull pgvector/pgvector:0.8.5-pg17-bookworm
```

**执行后的结果**：最后应显示 `Downloaded newer image` 或 `Image is up to date`，镜像名称必须完整包含版本和 PostgreSQL 17 后缀。

不能改成 `pgvector/pgvector:latest`、`pg17`、PostgreSQL 18 或普通 `postgres:17`。普通 PostgreSQL 镜像不包含项目需要的 PGVector 扩展文件。

### 第三步：Docker Hub 拉取失败时检测代理

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

输入：

```bash
curl -L -sS --connect-timeout 10 -o /dev/null -w 'DaoCloud: %{http_code}\n' https://docker.m.daocloud.io/v2/
curl -L -sS --connect-timeout 10 -o /dev/null -w '1ms: %{http_code}\n' https://docker.1ms.run/v2/
```

**执行后的结果**：`200` 或 `401` 表示 Registry 可达；`403`、`429`、`5xx`、`000` 或超时表示当前方式不可用。

DaoCloud 可达时输入：

```bash
docker pull docker.m.daocloud.io/pgvector/pgvector:0.8.5-pg17-bookworm
docker tag docker.m.daocloud.io/pgvector/pgvector:0.8.5-pg17-bookworm pgvector/pgvector:0.8.5-pg17-bookworm
```

1ms 可达时输入：

```bash
docker pull docker.1ms.run/pgvector/pgvector:0.8.5-pg17-bookworm
docker tag docker.1ms.run/pgvector/pgvector:0.8.5-pg17-bookworm pgvector/pgvector:0.8.5-pg17-bookworm
```

两个代理只选择检测可达的一种。都不可达时进入离线镜像步骤，不反复执行失败的拉取命令。

### 第四步：核对镜像架构和摘要

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

输入：

```bash
docker image inspect pgvector/pgvector:0.8.5-pg17-bookworm --format 'ARCH={{.Architecture}} OS={{.Os}} TAGS={{json .RepoTags}} DIGESTS={{json .RepoDigests}}'
```

**执行后的结果**：架构应为 `amd64`，操作系统应为 `linux`，标签应正确。

项目锁定摘要为：

```text
多架构标签摘要：sha256:d2ef61f42ef767baa5a1475393303cc235bcd92febd9d7014eddb48b41f3bad0
Linux amd64 平台摘要：sha256:815bf5378222044da3b34d98e6a5fdac37b15c428b67d09c7c2d90a038e597bf
```

摘要或平台不一致时不启动容器。先确认镜像没有被旧容器使用，再删除错误标签并重新拉取。

### 第五步：在联网 Windows 制作离线镜像包

**在哪里操作**：可以联网且已安装 Docker Desktop 的 Windows PowerShell。

输入：

```powershell
docker pull --platform linux/amd64 pgvector/pgvector:0.8.5-pg17-bookworm
New-Item -ItemType Directory -Force 'D:\delivery-images'
docker save -o 'D:\delivery-images\pgvector-0.8.5-pg17-bookworm.tar' pgvector/pgvector:0.8.5-pg17-bookworm
Get-FileHash 'D:\delivery-images\pgvector-0.8.5-pg17-bookworm.tar' -Algorithm SHA256
```

**执行后的结果**：目录中出现 tar 文件，并输出文件 SHA256。记录校验值，不能把镜像 tar 当作源码压缩包解压。

### 第六步：用 WinSCP 上传镜像包

**在哪里操作**：先在 Rocky Linux 虚拟机 SSH 终端。

输入：

```bash
whoami
sudo mkdir -p /opt/images
sudo chown "$USER":"$USER" /opt/images
sudo chmod 750 /opt/images
ls -ld /opt/images
```

**执行后的结果**：目录所有者与当前 SSH 用户一致。

**在哪里操作**：Windows 本机 WinSCP。

1. 新建 SFTP 站点，主机填写 `192.168.154.10`，端口填写 `22`。
2. 输入当前 SSH 用户名和密码并登录。
3. 左侧进入 `D:\delivery-images`。
4. 右侧进入 `/opt/images`。
5. 把 `pgvector-0.8.5-pg17-bookworm.tar` 拖到右侧。
6. 等待传输进度达到 100%。

**执行后的结果**：虚拟机中存在 `/opt/images/pgvector-0.8.5-pg17-bookworm.tar`，文件大小与 Windows 一致。

### 第七步：校验并载入离线镜像

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

输入：

```bash
sha256sum /opt/images/pgvector-0.8.5-pg17-bookworm.tar
docker load -i /opt/images/pgvector-0.8.5-pg17-bookworm.tar
docker image inspect pgvector/pgvector:0.8.5-pg17-bookworm --format '{{json .RepoTags}} {{.Architecture}}'
```

**执行后的结果**：Linux 与 Windows 文件 SHA256 一致，`docker load` 显示正确镜像名，架构为 amd64。

## 第三部分：创建数据、密钥、初始化和备份目录

### 第一步：创建五个宿主机目录

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

输入：

```bash
sudo mkdir -p /opt/docker_pgvector/data
sudo mkdir -p /opt/docker_pgvector/secrets
sudo mkdir -p /opt/docker_pgvector/init
sudo mkdir -p /opt/docker_pgvector/import
sudo mkdir -p /opt/pgvector-backups
sudo chown "$USER":"$USER" /opt/docker_pgvector/import /opt/pgvector-backups
sudo chmod 750 /opt/docker_pgvector/import /opt/pgvector-backups
sudo chmod 700 /opt/docker_pgvector/secrets
sudo find /opt/docker_pgvector/data -mindepth 1 -maxdepth 1 -print
sudo ls -ld /opt/docker_pgvector/{data,secrets,init,import} /opt/pgvector-backups
```

**执行后的结果**：全新安装时 `find` 不输出任何文件。`import` 和备份目录属于当前 SSH 用户；密钥目录权限为 700。

**目录用途**：

- `/opt/docker_pgvector/data`：PostgreSQL 数据文件，挂载到容器 `/var/lib/postgresql/data`。
- `/opt/docker_pgvector/secrets`：数据库密码文件。
- `/opt/docker_pgvector/init`：首次初始化扩展 SQL。
- `/opt/docker_pgvector/import`：客户后续手工导入的数据文件。
- `/opt/pgvector-backups`：数据库备份。

数据目录有旧文件时停止操作，确认来源并备份，不能直接清空。

### 第二步：生成并保存 PostgreSQL 密码

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

输入：

```bash
openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | head -c 32; echo
```

把输出保存到客户密码管理器，名称写成 `ygh_vector 数据库密码`。然后输入：

```bash
sudo vi /opt/docker_pgvector/secrets/postgres-password
```

按 `i`，只粘贴刚生成的密码；按 `Esc`，输入 `:wq` 保存。继续输入：

```bash
sudo chown root:root /opt/docker_pgvector/secrets/postgres-password
sudo chmod 600 /opt/docker_pgvector/secrets/postgres-password
sudo stat -c '%U %G %a %n' /opt/docker_pgvector/secrets/postgres-password
```

**执行后的结果**：显示 `root root 600`。后面使用官方 PostgreSQL 镜像支持的 `POSTGRES_PASSWORD_FILE` 读取密码，不把真实值写进启动命令。

继续创建只供容器内备份和恢复使用的 PostgreSQL 密码文件：

```bash
sudo vi /opt/docker_pgvector/secrets/pgpass
```

按 `i` 输入下面一行，把最后的占位内容改成刚才保存到密码管理器的同一个数据库密码：

```text
*:*:*:ygh_vector:这里填写同一个ygh_vector真实密码
```

按 `Esc`，输入 `:wq` 保存。接着逐条输入：

```bash
sudo chown root:999 /opt/docker_pgvector/secrets/pgpass
sudo chmod 640 /opt/docker_pgvector/secrets/pgpass
sudo stat -c '%U %G %a %n' /opt/docker_pgvector/secrets/pgpass
```

**需要修改的内容**：这里暂按镜像检查得到的 PostgreSQL 组 ID `999` 设置。如果后面“确认镜像内 PostgreSQL 用户 UID/GID”显示的 GID 不是 `999`，必须把 `root:999` 中的 999 改成实际 GID 后重新执行。这个文件不是 `.env` 或脚本，它是 PostgreSQL 官方客户端识别的密码文件。

### 第三步：手工创建项目扩展初始化文件

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

输入：

```bash
sudo vi /opt/docker_pgvector/init/01-enable-vector.sql
```

按 `i`，输入项目固定内容：

```sql
CREATE EXTENSION IF NOT EXISTS vector;
```

按 `Esc`，输入 `:wq` 并回车。设置只读权限并核对：

```bash
sudo chown root:root /opt/docker_pgvector/init/01-enable-vector.sql
sudo chmod 644 /opt/docker_pgvector/init/01-enable-vector.sql
sudo cat /opt/docker_pgvector/init/01-enable-vector.sql
```

**执行后的结果**：文件只包含一条创建 `vector` 扩展的 SQL，与项目文件 `ygh-deploy/constrained-dev/postgres/init/01-enable-vector.sql` 完全一致。

该文件只在数据目录为空的第一次初始化时自动执行。旧数据目录不会重新执行初始化 SQL。

### 第四步：确认镜像中的 postgres 用户 UID

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

输入：

```bash
docker run --rm --entrypoint id pgvector/pgvector:0.8.5-pg17-bookworm postgres
```

**执行后的结果**：记录输出中的 UID 和 GID，通常类似 `uid=999(postgres) gid=999(postgres)`。

按实际 UID/GID 设置数据目录。输出为 999:999 时输入：

```bash
sudo chown -R 999:999 /opt/docker_pgvector/data
sudo chmod 700 /opt/docker_pgvector/data
```

如果实际值不是 999，把命令中的两个 999 替换成实际数字。禁止对数据库目录执行 `chmod 777`。

## 第四部分：手工启动 PGVector 容器

### 第一步：执行首次启动命令

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

输入完整命令：

```bash
docker run -d \
  --name ygh-pgvector \
  --network ygh-core \
  --cpus="0.35" \
  --memory="384m" \
  -p 192.168.154.10:5432:5432 \
  -e TZ=Asia/Shanghai \
  -e POSTGRES_DB=ygh_vector \
  -e POSTGRES_USER=ygh_vector \
  -e POSTGRES_PASSWORD_FILE=/run/secrets/postgres-password \
  -v /opt/docker_pgvector/secrets/postgres-password:/run/secrets/postgres-password:ro,Z \
  -v /opt/docker_pgvector/secrets/pgpass:/run/secrets/pgpass:ro,Z \
  -v /opt/docker_pgvector/init/01-enable-vector.sql:/docker-entrypoint-initdb.d/01-enable-vector.sql:ro,Z \
  -v /opt/docker_pgvector/data:/var/lib/postgresql/data:Z \
  --health-cmd='pg_isready -U ygh_vector -d ygh_vector' \
  --health-interval=10s \
  --health-timeout=5s \
  --health-retries=15 \
  --health-start-period=20s \
  --log-driver json-file \
  --log-opt max-size=10m \
  --log-opt max-file=3 \
  --restart unless-stopped \
  pgvector/pgvector:0.8.5-pg17-bookworm \
  postgres \
  -c shared_buffers=64MB \
  -c max_connections=30 \
  -c work_mem=2MB
```

**执行后的结果**：Docker 输出容器 ID。首次启动会初始化 PostgreSQL 17、创建 `ygh_vector` 数据库和同名超级用户、读取初始化 SQL 并启用 vector 扩展。

**需要修改的内容**：虚拟机 IP 不同时只替换 `-p` 前面的地址。数据库名、用户名、端口、资源限制、三个 PostgreSQL 参数和容器路径保持不变。

### 第二步：等待容器健康

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

输入：

```bash
docker ps --filter name=ygh-pgvector
docker inspect ygh-pgvector --format 'Status={{.State.Status}} Health={{.State.Health.Status}} Restarts={{.RestartCount}}'
docker logs --tail 200 ygh-pgvector
```

**执行后的结果**：最终显示 `Status=running Health=healthy Restarts=0`，日志出现 `database system is ready to accept connections`。

**失败时怎么处理**：

- `Permission denied`：检查 data 目录 UID、权限和 `:Z`。
- 密码文件错误：检查文件非空、权限 600 和挂载路径。
- 初始化 SQL 报错：查看第一条 SQL 错误，不能只重启；数据目录可能已经部分初始化。
- 容器反复重启：执行 `docker logs ygh-pgvector`，检查内存和参数拼写。

### 第三步：核对 PostgreSQL 和 PGVector 版本

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

输入：

```bash
docker exec -it ygh-pgvector psql -U ygh_vector -d ygh_vector
```

进入 `ygh_vector=#` 后逐条输入：

```sql
SELECT version();
SELECT extname,extversion FROM pg_extension ORDER BY extname;
SHOW shared_buffers;
SHOW max_connections;
SHOW work_mem;
\q
```

**执行后的结果**：

- PostgreSQL 主版本为 17。
- `vector` 扩展版本为 0.8.5。
- `shared_buffers` 为 64MB。
- `max_connections` 为 30。
- `work_mem` 为 2MB。

容器内本地 Unix Socket 可能不要求密码，这只能验证数据库状态，不能代替远程密码验证。

### 第四步：从 Docker 网络验证密码认证

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

输入：

```bash
docker run --rm -it --network ygh-core pgvector/pgvector:0.8.5-pg17-bookworm \
  psql -h ygh-pgvector -U ygh_vector -d ygh_vector -W
```

出现 `Password:` 后输入密码管理器中的 `ygh_vector` 密码。进入提示符后输入：

```sql
SELECT current_user,current_database(),inet_server_addr(),inet_server_port();
\q
```

**执行后的结果**：用户和数据库都为 `ygh_vector`，端口为 5432。这证明容器网络和密码认证都正常。

### 第五步：核对资源、端口和重启策略

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

输入：

```bash
docker port ygh-pgvector
docker stats --no-stream ygh-pgvector
docker inspect ygh-pgvector --format 'Memory={{.HostConfig.Memory}} NanoCpus={{.HostConfig.NanoCpus}} Restart={{.HostConfig.RestartPolicy.Name}} Log={{.HostConfig.LogConfig.Type}} {{json .HostConfig.LogConfig.Config}}'
```

**执行后的结果**：5432 绑定到 `192.168.154.10`；Memory 为 402653184；NanoCpus 为 350000000；Restart 为 `unless-stopped`；日志为 10MB × 3。

## 第五部分：配置防火墙和 Windows 连通性

### 第一步：确认 Windows VMnet8 IPv4

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
ipconfig
```

**执行后的结果**：记录 `VMware Network Adapter VMnet8` 的 IPv4，当前环境通常是 `192.168.154.1`。不要使用无线网卡或 VPN 地址。

### 第二步：允许 Windows 宿主机访问 5432

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

当前 VMnet8 地址为 `192.168.154.1` 时输入：

```bash
sudo firewall-cmd --permanent --add-rich-rule='rule family=ipv4 source address=192.168.154.1/32 port port=5432 protocol=tcp accept'
sudo firewall-cmd --reload
sudo firewall-cmd --list-rich-rules
```

**执行后的结果**：规则包含来源 `192.168.154.1/32` 和 5432。客户地址不同时替换来源地址。

PostgreSQL 不能开放给公网或 `0.0.0.0/0`。本项目 Search 服务在 Windows IDEA 运行，因此只需要 Windows VMnet8 地址访问。

### 第三步：从 Windows 测试端口

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
Test-NetConnection 192.168.154.10 -Port 5432
```

**执行后的结果**：必须显示 `TcpTestSucceeded : True`。失败时依次检查固定 IP、容器健康、端口映射和 firewalld 规则。

## 第六部分：在 IDEA 中配置 Search 服务并执行 Flyway

**执行时机**：首次按总教程部署时，完成第五部分 Windows 5432 连通性检查后，先继续安装 Windows Docker Desktop 和 Elasticsearch。只有 Elasticsearch 索引准备完成并进入 `11` 号 IDEA 后端启动文档的 Search 步骤时，才返回执行本部分。PGVector 健康不代表 Search 的全部依赖已经就绪。

### 第一步：确认只有 Search 服务直接连接 PGVector

**在哪里操作**：Windows 本机 IntelliJ IDEA 和项目源码。

项目当前直接读取 PGVector 连接变量的是：

```text
ygh-search-service
```

Knowledge 服务把已发布文档发送给 Search，AI 服务通过 Search 的内部检索接口获取结果；它们不直接填写 `YGH_VECTOR_DB_*`。不要把 PostgreSQL 密码复制到所有 Java 服务。

**执行后的结果**：只为 `ygh-search-service` 创建 PGVector 连接配置。

### 第二步：打开 Search 运行配置

**在哪里操作**：Windows 本机 IntelliJ IDEA。

1. 点击 `Run` → `Edit Configurations...`。
2. 选择 `ygh-search-service`。
3. 没有配置时点击左上角 `+`，选择 `Spring Boot`。
4. `Name` 填写 `ygh-search-service`。
5. `Module` 选择 `ygh-search-service` 所在模块。
6. `Main class` 填写或选择 `com.yuegang.zhihui.search.SearchApplication`。
7. `JRE` 选择本机已经配置好的 Oracle JDK 25。
8. `Working directory` 保持 IDEA 自动识别的项目目录，不要指向虚拟机或 PGVector 数据目录。
9. 找到 `Environment variables` 并点击右侧编辑按钮。

**执行后的结果**：打开 Search 服务环境变量窗口，尚未启动服务。

### 第三步：填写三个 PGVector 变量

**在哪里操作**：Windows 本机 IDEA 的 Search 运行配置。

逐项填写：

```text
YGH_VECTOR_DB_URL=jdbc:postgresql://192.168.154.10:5432/ygh_vector
YGH_VECTOR_DB_USERNAME=ygh_vector
YGH_VECTOR_DB_PASSWORD=填写密码管理器中的真实密码
```

**需要修改的内容**：只在虚拟机 IP 不同时修改 JDBC URL 的主机部分。数据库名和用户名保持 `ygh_vector`。

当前开发配置使用同一个 `ygh_vector` 用户执行 Flyway 和运行时查询，这是项目源码的实际契约。不要自行改成未在项目中配置的另一套账号。

**执行后的结果**：三个变量都存在，真实密码没有写入 `application.yml` 或提交到 Git。

### 第四步：先完成 Search 的其他组件变量

**在哪里操作**：Windows 本机 IDEA 的 Search 运行配置。

Search 还需要 Nacos、Elasticsearch、System 内部地址和内部 HMAC。必须先完成后续 Elasticsearch 文档和最终项目启动文档，再启动 Search。至少还应存在：

```text
YGH_NACOS_SERVER_ADDR
YGH_NACOS_USERNAME
YGH_NACOS_PASSWORD
YGH_NACOS_NAMESPACE
YGH_NACOS_DISCOVERY_GROUP
YGH_ELASTICSEARCH_BASE_URL
YGH_SYSTEM_INTERNAL_BASE_URL
YGH_INTERNAL_REQUEST_HMAC_BASE64
```

**执行后的结果**：当前 PGVector 阶段只保存连接变量，不为了建表提前使用假 Elasticsearch 地址启动 Search。

### 第五步：全部依赖完成后首次启动 Search

**在哪里操作**：Windows 本机 IntelliJ IDEA。

1. 确认 `ygh-pgvector` 为 healthy。
2. 确认 Nacos 和 Elasticsearch 已启动。
3. 选择 `ygh-search-service` 运行配置。
4. 点击绿色三角形。
5. 在 `Run` 窗口观察 Flyway 日志。

**执行后的结果**：Flyway 应依次应用 V1 至 V5，Search 服务完成启动。不能出现密码认证失败、`extension vector is not available`、连接拒绝或 Flyway checksum 错误。

### 第六步：验证 Search 建出的扩展、表和索引

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

输入：

```bash
docker exec -it ygh-pgvector psql -U ygh_vector -d ygh_vector
```

进入 psql 后逐条输入：

```sql
SELECT extname,extversion FROM pg_extension WHERE extname IN ('vector','pgcrypto') ORDER BY extname;
\dt
\d search_embedding
SELECT indexname,indexdef FROM pg_indexes WHERE tablename='search_embedding' ORDER BY indexname;
SELECT installed_rank,version,description,success FROM flyway_schema_history ORDER BY installed_rank;
SELECT alias_name,active_version,previous_version FROM search_index_version;
\q
```

**执行后的结果**：

- `vector` 为 0.8.5，并存在 `pgcrypto`。
- 存在 `search_embedding`、`search_index_version` 和 `flyway_schema_history`。
- `embedding` 字段类型为 `vector(1024)`。
- 存在使用 `hnsw` 和 `vector_cosine_ops` 的向量索引。
- Flyway V1 至 V5 的 `success` 都为 true。
- 默认别名 `knowledge-active` 指向 `knowledge-v1`。

### 第七步：检查 Search 在 Nacos 中的注册

**在哪里操作**：Windows 本机浏览器 Nacos 控制台。

1. 登录 Nacos 控制台。
2. 切换到 `ygh-dev`。
3. 打开 `服务管理` → `服务列表`。
4. Group 选择 `YGH_GROUP`。
5. 找到 `ygh-search-service` 并打开详情。

**执行后的结果**：实例健康，端口为 8089，注册 IP 是 Windows VMnet8 地址或客户确认可从其他服务访问的 Windows 地址。

## 第七部分：按需停止、再次启动和备份恢复

### 第一步：停止 PGVector

**在哪里操作**：先在 Windows IDEA 停止 Search 服务，再到 Rocky Linux SSH 终端。

输入：

```bash
docker stop ygh-pgvector
docker ps -a --filter name=ygh-pgvector
```

**执行后的结果**：容器为 Exited，`/opt/docker_pgvector/data` 仍保留。PGVector 是 AI 场景按需组件，停止时不删除数据目录。

### 第二步：再次启动 PGVector

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

输入：

```bash
docker start ygh-pgvector
docker inspect ygh-pgvector --format 'Status={{.State.Status}} Health={{.State.Health.Status}}'
```

**执行后的结果**：等待 Health 变成 healthy 后，才能在 IDEA 启动 Search。

### 第三步：重启 PGVector

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

输入：

```bash
docker restart ygh-pgvector
docker logs --tail 200 ygh-pgvector
docker inspect ygh-pgvector --format 'Health={{.State.Health.Status}} Restarts={{.RestartCount}}'
```

**执行后的结果**：日志显示数据库重新接受连接，Health 回到 healthy。不要用反复重启掩盖数据或权限错误。

### 第四步：手工备份 ygh_vector

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

先输入下面三条命令创建备份目录并查看当前时间：

```bash
sudo mkdir -p /opt/pgvector-backups
sudo chmod 700 /opt/pgvector-backups
date '+%Y%m%d-%H%M%S'
```

假设时间显示为 `20260715-143000`，把下面三条命令中的示例时间手工改成实际值，然后逐条执行：

```bash
docker exec -e PGPASSFILE=/run/secrets/pgpass ygh-pgvector pg_dump -U ygh_vector -d ygh_vector --no-owner --no-privileges > /opt/pgvector-backups/ygh-vector-20260715-143000.sql
sha256sum /opt/pgvector-backups/ygh-vector-20260715-143000.sql > /opt/pgvector-backups/ygh-vector-20260715-143000.sql.sha256
ls -lh /opt/pgvector-backups/ygh-vector-20260715-143000.sql /opt/pgvector-backups/ygh-vector-20260715-143000.sql.sha256
```

**执行后的结果**：SQL 文件大于 0 字节并生成 SHA256。把两份文件复制到客户备份存储，不只保存在虚拟机系统盘。不要照抄示例时间，以免覆盖同名文件。

向量数据可能包含客户文档内容的派生信息，备份文件不得提交到 Git 或通过公共聊天工具发送。

### 第五步：把备份恢复到独立验证数据库

**在哪里操作**：先在 Windows IDEA 停止 Search、Knowledge 和 AI 服务，再到 Rocky Linux SSH 终端。

先重新备份当前数据库。不要把备份直接导入仍包含业务表的 `ygh_vector`，否则会遇到对象已存在，并可能形成部分恢复。

先确认待恢复文件的文件名。下面以 `ygh-vector-20260714-120000.sql` 为例，实际操作时把命令中的文件名替换成真实文件名：

```bash
sha256sum -c /opt/pgvector-backups/ygh-vector-20260714-120000.sql.sha256
docker exec ygh-pgvector psql -v ON_ERROR_STOP=1 -U ygh_vector -d postgres -c "CREATE DATABASE ygh_vector_restore OWNER ygh_vector TEMPLATE template0;"
docker exec -e PGPASSFILE=/run/secrets/pgpass -i ygh-pgvector psql -v ON_ERROR_STOP=1 -U ygh_vector -d ygh_vector_restore < /opt/pgvector-backups/ygh-vector-20260714-120000.sql
docker exec ygh-pgvector psql -U ygh_vector -d ygh_vector_restore -c "SELECT extname,extversion FROM pg_extension WHERE extname IN ('vector','pgcrypto') ORDER BY extname;"
docker exec ygh-pgvector psql -U ygh_vector -d ygh_vector_restore -c "SELECT installed_rank,version,description,success FROM flyway_schema_history ORDER BY installed_rank;"
docker exec ygh-pgvector psql -U ygh_vector -d ygh_vector_restore -c "SELECT COUNT(*) AS embedding_count FROM search_embedding;"
```

如果提示 `database "ygh_vector_restore" already exists`，说明上一次恢复验证库仍存在。先确认其中没有需要保留的数据，再输入：

```bash
docker exec ygh-pgvector psql -U ygh_vector -d postgres -c "DROP DATABASE ygh_vector_restore WITH (FORCE);"
```

然后重新执行创建和导入命令。该删除命令只能删除名称完全为 `ygh_vector_restore` 的验证库，不能改成 `ygh_vector`。

**执行后的结果**：校验显示 `OK`；导入过程没有 SQL 错误；验证库包含 vector、pgcrypto、Flyway 历史和 `search_embedding` 数据。到这里仅完成恢复演练，正式数据库没有被覆盖。

### 第六步：确认后切换到已验证的恢复数据库

**在哪里操作**：Windows IDEA 与 Rocky Linux 虚拟机 SSH 终端。该操作会替换正式数据库，必须在客户确认恢复时间点和备份内容后执行。

1. 在 IDEA 依次停止 AI、Knowledge 和 Search 服务。
2. 在 SSH 终端确认当前正式库已经完成第五部分的新备份。
3. 确认没有名为 `ygh_vector_before_restore` 的旧保留库：

```bash
docker exec ygh-pgvector psql -U ygh_vector -d postgres -c "SELECT datname FROM pg_database WHERE datname IN ('ygh_vector','ygh_vector_restore','ygh_vector_before_restore') ORDER BY datname;"
```

正常应只有 `ygh_vector` 和 `ygh_vector_restore`。如果已经存在 `ygh_vector_before_restore`，先查明来源并另外备份，不能直接覆盖。

4. 终止这两个数据库的残留连接，再逐条改名：

```bash
docker exec ygh-pgvector psql -v ON_ERROR_STOP=1 -U ygh_vector -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname IN ('ygh_vector','ygh_vector_restore') AND pid <> pg_backend_pid();"
docker exec ygh-pgvector psql -v ON_ERROR_STOP=1 -U ygh_vector -d postgres -c "ALTER DATABASE ygh_vector RENAME TO ygh_vector_before_restore;"
docker exec ygh-pgvector psql -v ON_ERROR_STOP=1 -U ygh_vector -d postgres -c "ALTER DATABASE ygh_vector_restore RENAME TO ygh_vector;"
```

5. 重新执行第六部分第六步的扩展、表、索引和 Flyway 检查，再在 IDEA 启动 Search。

**执行后的结果**：Search 仍连接数据库名 `ygh_vector`，但其中数据来自已验证备份；原数据库暂时保留为 `ygh_vector_before_restore`，便于出现问题时回退。确认恢复结果稳定前不要删除该保留库。

### 第七步：修改数据库密码

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

先使用第三部分第二步的命令生成新密码，并保存到客户密码管理器。然后进入 psql：

```bash
docker exec -it ygh-pgvector psql -U ygh_vector -d ygh_vector
```

在 psql 中输入：

```sql
\password ygh_vector
```

出现 `Enter new password for user "ygh_vector":` 时粘贴新密码并回车；出现 `Enter it again:` 时再次粘贴同一密码。成功后输入 `\q` 退出。交互输入不会把密码明文保存在 SQL 历史中。

然后输入：

```bash
sudo vi /opt/docker_pgvector/secrets/postgres-password
```

按 `i`，删除旧内容，只粘贴同一个新密码；按 `Esc`，输入 `:wq` 保存。继续输入：

```bash
sudo chown root:root /opt/docker_pgvector/secrets/postgres-password
sudo chmod 600 /opt/docker_pgvector/secrets/postgres-password
sudo stat -c '%U %G %a %n' /opt/docker_pgvector/secrets/postgres-password
```

再更新客户端密码文件：

```bash
sudo vi /opt/docker_pgvector/secrets/pgpass
```

按 `i`，把这一行冒号后的旧密码改成同一个新密码，其他字段不改；按 `Esc`，输入 `:wq` 保存。然后输入：

```bash
sudo chown root:999 /opt/docker_pgvector/secrets/pgpass
sudo chmod 640 /opt/docker_pgvector/secrets/pgpass
sudo stat -c '%U %G %a %n' /opt/docker_pgvector/secrets/pgpass
```

如果镜像内 PostgreSQL 组 ID 不是 999，仍使用前面实测的 GID。

最后在 IDEA 的 `ygh-search-service` 运行配置中，把 `YGH_VECTOR_DB_PASSWORD` 改成同一个新密码。

**执行后的结果**：第四部分远程密码认证重新通过，备份命令可以读取 `pgpass`，Search 重启成功。只修改密码文件不会自动修改数据库角色密码；数据库角色、两个密码文件和 IDEA 四处必须保持一致。

## 第八部分：常见错误逐项排查

### 1. `password authentication failed for user ygh_vector`

**在哪里排查**：Rocky Linux SSH 和 Windows IDEA。

使用第四部分的临时客户端命令验证密码；检查 IDEA `YGH_VECTOR_DB_PASSWORD`。不要把密码直接写到 JDBC URL。

### 2. `extension vector is not available`

**在哪里排查**：Rocky Linux SSH 终端。

确认使用的是 `pgvector/pgvector:0.8.5-pg17-bookworm`，不是普通 postgres 镜像。执行 `SELECT * FROM pg_available_extensions WHERE name='vector';`。镜像错误时备份数据后按正确版本重新评估，不能在运行中的容器临时源码编译。

### 3. vector 扩展未创建

**在哪里排查**：Rocky Linux SSH 和 psql。

执行 `SELECT extname FROM pg_extension WHERE extname='vector';`。全新数据目录应由初始化 SQL创建；已有数据库可由有权限的 `ygh_vector` 用户手工执行 `CREATE EXTENSION IF NOT EXISTS vector;`，执行后再次检查版本。

### 4. `relation search_embedding does not exist`

**在哪里排查**：Windows IDEA Search 日志和 PostgreSQL Flyway 表。

说明 Search 的 Flyway 没有完成。检查 `flyway_schema_history`、JDBC URL 和启动日志，不能手工创建一张简化表绕过迁移。

### 5. HNSW 索引创建失败或内存不足

**在哪里排查**：Rocky Linux SSH 终端。

输入：

```bash
free -h
docker stats --no-stream ygh-pgvector
docker logs --tail 300 ygh-pgvector
```

停止无关场景服务后再重试 Flyway。不要取消容器限制或删除索引定义来掩盖资源不足。

### 6. Windows 5432 端口不通

**在哪里排查**：Windows PowerShell和 Rocky Linux SSH。

检查 `Test-NetConnection`、`docker port ygh-pgvector`、容器 Health、固定 IP 和 firewalld 来源地址。

### 7. 修改 POSTGRES_PASSWORD_FILE 后旧密码仍有效

**在哪里排查**：Rocky Linux SSH 终端。

官方 PostgreSQL 镜像只在空数据目录首次初始化时使用 `POSTGRES_PASSWORD_FILE` 设置角色密码。已有数据必须按第七部分第七步执行 `\password`，再同步密码文件和 IDEA。

### 8. 初始化 SQL 修改后没有自动执行

**在哪里排查**：Rocky Linux SSH 终端。

`/docker-entrypoint-initdb.d` 只处理空数据目录的首次初始化。不能通过删除 `/opt/docker_pgvector/data` 强制重跑。对已有库使用经过审核的 SQL 手工迁移，并先备份。

### 9. 容器启动后立即退出

**在哪里排查**：Rocky Linux SSH 终端。

输入：

```bash
docker ps -a --filter name=ygh-pgvector
docker logs --tail 300 ygh-pgvector
```

重点检查数据目录 UID、SELinux 标签、密码文件、旧数据主版本和启动参数拼写。

### 10. 磁盘持续增长

**在哪里排查**：Rocky Linux SSH 和 psql。

输入：

```bash
du -sh /opt/docker_pgvector/data
df -h /
docker exec -it ygh-pgvector psql -U ygh_vector -d ygh_vector -c "SELECT pg_size_pretty(pg_database_size('ygh_vector'));"
```

检查向量条目、旧索引版本和备份保留情况。删除历史向量必须通过 Search 的索引生命周期功能和业务审核，不能直接删除数据目录或未知表。
