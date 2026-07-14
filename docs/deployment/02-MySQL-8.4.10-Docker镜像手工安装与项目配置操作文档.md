# MySQL 8.4.10 Docker 镜像手工安装与项目配置操作文档

## 第一部分：确认 Docker 和虚拟机网络

### 第一步：从 Windows 登录 Rocky Linux 虚拟机

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
ssh root@192.168.154.10
```

如果客户使用的 SSH 用户不是 `root`，只替换用户名。登录成功后，提示符会变成类似 `[root@localhost ~]#`。从下一步开始，除非明确写着 Windows 或 IDEA，命令都在这个 Rocky Linux 虚拟机终端输入。

### 第二步：检查 Docker 是否安装在虚拟机中

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

输入：

```bash
docker version
docker info | sed -n '/Registry Mirrors/,+5p'
```

**执行后的结果**：

- `docker version` 必须同时显示 Client 和 Server。
- Registry Mirrors 应显示已经配置的 DaoCloud 和 1ms 镜像代理，或者客户自己的企业镜像仓库。

**失败时怎么处理**：如果提示 `docker: command not found`，先停止本教程，按照 Redis 操作文档“在 Rocky Linux 虚拟机中手动安装 Docker”部分完成 Docker Engine 安装和镜像代理配置，再回来继续。MySQL 最终运行在 Rocky Linux 虚拟机内部的 Docker 容器中，不安装到 Windows、WSL 或 Windows Docker Desktop。

### 第三步：检查虚拟机 IP 和 3306 端口

输入：

```bash
ip -br address
sudo ss -lntp | grep ':3306' || echo '3306 端口空闲'
docker ps -a --filter name=ygh-mysql
```

**执行后的结果**：虚拟机网卡应具有 `192.168.154.10/24`，3306 应显示空闲，不应存在名为 `ygh-mysql` 的旧容器。

**需要修改的内容**：如果客户使用其他固定 IP，记录实际地址，后面 `docker run`、防火墙和 IDEA 数据库 URL 必须同时替换。如果 3306 已被占用，执行 `sudo ss -lntp | grep ':3306'` 查看进程，确认旧数据库数据已经备份后再处理，不能直接结束未知进程。

## 第二部分：手动拉取或上传 MySQL 8.4.10 镜像

### 第一步：从项目固定镜像名拉取

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

输入：

```bash
docker pull mysql:8.4.10
```

**正常输出**：最后应出现 `Status: Downloaded newer image for mysql:8.4.10` 或 `Image is up to date for mysql:8.4.10`，并显示镜像摘要。

**为什么使用这个版本**：项目固定使用 MySQL 8.4.10。不能改成 `mysql:latest`、`mysql:8` 或 MariaDB，否则客户不同时间部署会得到不同版本，数据库行为和 Flyway 迁移结果无法保证一致。

### 第二步：官方名称拉取失败时逐个检测镜像代理

先检测代理：

```bash
curl -L -sS --connect-timeout 10 -o /dev/null -w 'DaoCloud: %{http_code}\n' https://docker.m.daocloud.io/v2/
curl -L -sS --connect-timeout 10 -o /dev/null -w '1ms: %{http_code}\n' https://docker.1ms.run/v2/
```

返回 `200` 或 `401` 表示 Registry 可达。`403` 表示当前访问被拒绝，`429` 表示限流，`5xx` 表示代理故障，`000` 或连接超时表示当前网络不可用。

DaoCloud 可达时输入：

```bash
docker pull docker.m.daocloud.io/library/mysql:8.4.10
docker tag docker.m.daocloud.io/library/mysql:8.4.10 mysql:8.4.10
```

1ms 可达时输入：

```bash
docker pull docker.1ms.run/library/mysql:8.4.10
docker tag docker.1ms.run/library/mysql:8.4.10 mysql:8.4.10
```

两种方式只选择一种。第二条 `docker tag` 把代理镜像添加为项目统一使用的 `mysql:8.4.10` 标签。

### 第三步：核对镜像版本、架构和摘要

输入：

```bash
docker image inspect mysql:8.4.10 --format 'ARCH={{.Architecture}} OS={{.Os}} TAGS={{json .RepoTags}} DIGESTS={{json .RepoDigests}}'
docker run --rm mysql:8.4.10 mysqld --version
```

**执行后的结果**：

- 架构为 `amd64`，操作系统为 `linux`。
- 标签包含 `mysql:8.4.10`。
- `mysqld --version` 显示 MySQL 8.4.10。
- 项目锁定的多架构标签摘要为 `sha256:c831a0f11348d402b43d77453e17d770be2eef356615a2823fe0f5a0d6c8b9af`，Linux amd64 平台摘要为 `sha256:ef9038553b7ea407704f16770e407ffd32f5566f125d0d94f63ff736af1d43f8`。

如果摘要或版本不一致，不启动容器，先删除错误标签并重新拉取。

### 第四步：虚拟机不能联网时上传镜像包

**在哪里操作**：先在可以联网且已安装 Docker Desktop 的 Windows PowerShell 操作。

```powershell
docker pull --platform linux/amd64 mysql:8.4.10
New-Item -ItemType Directory -Force 'D:\delivery-images'
docker save -o 'D:\delivery-images\mysql-8.4.10.tar' mysql:8.4.10
Get-FileHash 'D:\delivery-images\mysql-8.4.10.tar' -Algorithm SHA256
```

**执行后的结果**：`docker save` 完成后，Windows 的 `D:\delivery-images` 中应出现 `mysql-8.4.10.tar`；`Get-FileHash` 会输出一行 SHA256。先把这串 SHA256 记录下来，后面用来判断上传过程中有没有损坏。

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

先给当前 SSH 用户创建可上传目录：

```bash
whoami
sudo mkdir -p /opt/images
sudo chown "$USER":"$USER" /opt/images
sudo chmod 750 /opt/images
ls -ld /opt/images
```

`whoami` 显示谁，`ls -ld` 的所有者就应是谁。例如使用 `root` 登录时应显示 `root root`，使用 `ygh` 登录时应显示 `ygh ygh`。如果所有者仍是其他账号，WinSCP 会在上传时提示 `Permission denied`，此时不要改成 `chmod 777`，重新执行上面的 `chown`。

**在哪里操作**：Windows 本机 WinSCP。

1. 打开 WinSCP，点击左下角 `新建站点`。
2. `文件协议` 选择 `SFTP`。
3. `主机名` 填写 `192.168.154.10`，`端口号` 填写 `22`。
4. `用户名` 和 `密码` 填写刚才 `whoami` 对应的 SSH 账号及其密码。
5. 点击 `登录`；首次连接出现主机密钥提示时，核对地址确实是 `192.168.154.10` 后点击 `接受`。
6. 左侧进入 `D:\delivery-images`，右侧进入 `/opt/images`。
7. 把左侧 `mysql-8.4.10.tar` 拖到右侧，等待传输进度达到 100%。

上传完成后，右侧必须看到 `/opt/images/mysql-8.4.10.tar`，文件大小应与 Windows 中的源文件一致。

回到虚拟机 SSH 终端输入：

```bash
sha256sum /opt/images/mysql-8.4.10.tar
docker load -i /opt/images/mysql-8.4.10.tar
docker image inspect mysql:8.4.10 --format '{{json .RepoTags}}'
docker run --rm mysql:8.4.10 mysqld --version
```

Linux 和 Windows 的 SHA256 必须一致；`docker load` 应显示 `Loaded image: mysql:8.4.10`；版本必须是 8.4.10。这个 tar 是 MySQL 镜像包，不是 Java 项目压缩包，不要解压后上传。

## 第三部分：手动创建 MySQL 配置、密码和数据目录

### 第一步：创建宿主机目录

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

输入：

```bash
sudo mkdir -p /opt/docker_mysql/conf
sudo mkdir -p /opt/docker_mysql/data
sudo mkdir -p /opt/docker_mysql/secrets
sudo mkdir -p /opt/docker_mysql/import
sudo mkdir -p /opt/mysql-backups
sudo chown "$USER":"$USER" /opt/docker_mysql/import /opt/mysql-backups
sudo chmod 750 /opt/docker_mysql/import /opt/mysql-backups
sudo ls -ld /opt/docker_mysql/{conf,data,secrets,import} /opt/mysql-backups
sudo find /opt/docker_mysql/data -mindepth 1 -maxdepth 1 -print
```

**目录用途**：

- `/opt/docker_mysql/conf`：MySQL 配置文件。
- `/opt/docker_mysql/data`：MySQL 数据文件，挂载到容器 `/var/lib/mysql`。
- `/opt/docker_mysql/secrets`：root 密码文件。
- `/opt/docker_mysql/import`：Nacos SQL 等单个导入文件。
- `/opt/mysql-backups`：数据库备份。

这些目录全部位于 Rocky Linux 虚拟机，不放在 Windows、WSL 或项目源码目录。`import` 和 `mysql-backups` 的所有者应是当前 SSH 用户，权限应为 750，这样 WinSCP 可以上传 SQL、当前用户可以写入备份；不要给密码目录做相同授权。最后一条 `find` 在全新安装时不应输出任何文件；如果有输出，说明这里存在旧 MySQL 数据，必须先确认数据来源并完成备份，不能继续执行首次启动，更不能直接删除。

### 第二步：逐项编写低内存配置文件

先确认虚拟机中有文本编辑器：

```bash
command -v vi
```

正常应输出 `/usr/bin/vi`。如果没有任何输出并回到命令提示符，输入 `sudo dnf install -y vim-minimal`，安装完成后再次执行 `command -v vi`。然后输入：

```bash
sudo vi /opt/docker_mysql/conf/ygh-low-memory.cnf
```

按 `i` 进入编辑模式，逐行输入：

```ini
[mysqld]
character-set-server=utf8mb4
collation-server=utf8mb4_0900_ai_ci
default-time-zone=+08:00
innodb_buffer_pool_size=256M
innodb_log_buffer_size=16M
max_connections=80
table_open_cache=400
thread_cache_size=16
tmp_table_size=16M
max_heap_table_size=16M
performance_schema=OFF
skip_name_resolve=ON
binlog_expire_logs_seconds=86400
slow_query_log=OFF

[client]
default-character-set=utf8mb4
```

按 `Esc`，输入 `:wq` 并回车保存。检查：

```bash
sudo cat /opt/docker_mysql/conf/ygh-low-memory.cnf
```

**配置原因**：字符集和排序规则与项目数据库一致；256MB InnoDB 缓冲池、80 个连接和关闭 Performance Schema 用于当前 3.5GB 虚拟机；binlog 只保留一天，避免磁盘持续增长。

### 第三步：生成并保存 root 密码文件

先确认 OpenSSL 可用：

```bash
openssl version
```

正常会显示 OpenSSL 版本。如果提示 `openssl: command not found`，输入 `sudo dnf install -y openssl`，安装完成后重新执行 `openssl version`。然后生成一个 32 位字母数字密码：

```bash
openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | head -c 32; echo
```

把输出保存到客户密码管理器。然后输入：

```bash
sudo vi /opt/docker_mysql/secrets/mysql-root-password
```

按 `i`，只输入刚才生成的密码，不加引号、不加空格；按 `Esc`，输入 `:wq` 保存。设置权限：

```bash
sudo chown root:root /opt/docker_mysql/secrets/mysql-root-password
sudo chmod 600 /opt/docker_mysql/secrets/mysql-root-password
sudo stat -c '%U %G %a %n' /opt/docker_mysql/secrets/mysql-root-password
```

应输出 `root root 600`。不要用 `cat` 打印密码，不要把密码直接放进 `docker run`，后面通过 `MYSQL_ROOT_PASSWORD_FILE` 读取该文件。

### 第四步：确认 MySQL 镜像中的用户 UID

输入：

```bash
docker run --rm mysql:8.4.10 id mysql
```

正常应看到类似 `uid=999(mysql) gid=999(mysql)`。按实际输出设置数据目录：

```bash
sudo chown -R 999:999 /opt/docker_mysql/data
sudo chmod 750 /opt/docker_mysql/data
sudo chown root:999 /opt/docker_mysql/conf/ygh-low-memory.cnf
sudo chmod 640 /opt/docker_mysql/conf/ygh-low-memory.cnf
```

如果 `id mysql` 显示的 UID/GID 不是 `999:999`，把命令中的 999 替换为实际值。禁止对配置、密码和数据目录执行 `chmod 777`。

### 第五步：创建后续组件共用的 Docker 网络

输入：

```bash
docker network inspect ygh-core
```

如果显示 `network ygh-core not found`，输入：

```bash
docker network create ygh-core
```

再次执行 `docker network inspect ygh-core`，应显示网络名称 `ygh-core`。MySQL 容器先加入该网络，后续 Nacos 容器才能使用容器名 `ygh-mysql` 连接 MySQL。

## 第四部分：手动启动 MySQL 容器

### 第一步：执行首次启动命令

输入完整命令：

```bash
docker run -d \
  --name ygh-mysql \
  --network ygh-core \
  --cpus="0.60" \
  --memory="640m" \
  -p 192.168.154.10:3306:3306 \
  -e TZ=Asia/Shanghai \
  -e MYSQL_ROOT_PASSWORD_FILE=/run/secrets/mysql-root-password \
  -v /opt/docker_mysql/secrets/mysql-root-password:/run/secrets/mysql-root-password:ro,Z \
  -v /opt/docker_mysql/conf/ygh-low-memory.cnf:/etc/mysql/conf.d/ygh-low-memory.cnf:ro,Z \
  -v /opt/docker_mysql/data:/var/lib/mysql:Z \
  --health-cmd='MYSQL_PWD="$(cat /run/secrets/mysql-root-password)" mysqladmin ping -h 127.0.0.1 -uroot --silent' \
  --health-interval=10s \
  --health-timeout=5s \
  --health-retries=20 \
  --health-start-period=40s \
  --log-driver json-file \
  --log-opt max-size=10m \
  --log-opt max-file=3 \
  --restart unless-stopped \
  mysql:8.4.10
```

**执行后的结果**：Docker 输出一个容器 ID。首次启动会初始化 `/opt/docker_mysql/data`，通常需要几十秒，期间 MySQL 暂时不接受连接。

**需要修改的内容**：客户虚拟机固定 IP 不同时，只替换 `-p` 前面的 `192.168.154.10`，并同步修改后面的防火墙和 IDEA URL。不要修改容器名、镜像版本、资源限制和容器内路径。三条日志参数把单个日志文件限制为 10MB、最多保留 3 个，必须保留，防止容器日志长期占满虚拟机磁盘。

### 第二步：等待 MySQL 健康

输入：

```bash
docker ps --filter name=ygh-mysql
docker inspect ygh-mysql --format 'Status={{.State.Status}} Health={{.State.Health.Status}}'
docker logs --tail 200 ygh-mysql
```

**执行后的结果**：状态先显示 `starting`，最终必须变成 `Status=running Health=healthy`。日志中应出现 `ready for connections`。

**失败时怎么处理**：

- `Permission denied`：检查数据目录 UID、配置文件权限和 `:Z`。
- `unknown variable`：检查 `ygh-low-memory.cnf` 拼写。
- 容器反复重启：执行 `docker logs ygh-mysql`，不要重复创建第二个容器。
- root 密码文件错误：确认文件非空、权限为 600，并且挂载路径完全一致。

### 第三步：验证版本和项目参数

进入 MySQL：

```bash
docker exec -e MYSQL_HISTFILE=/dev/null -it ygh-mysql mysql -uroot -p
```

出现 `Enter password:` 时输入 root 密码，终端不会显示字符，输入完成按回车。在 `mysql>` 中逐条输入：

```sql
SELECT VERSION();
SHOW VARIABLES WHERE Variable_name IN (
  'character_set_server','collation_server','time_zone',
  'innodb_buffer_pool_size','max_connections','performance_schema'
);
EXIT;
```

版本必须为 8.4.10；字符集为 `utf8mb4`；排序规则为 `utf8mb4_0900_ai_ci`；时区为 `+08:00`；缓冲池为 268435456 字节；最大连接数为 80；Performance Schema 为 OFF。

## 第五部分：逐个创建项目数据库和账号

### 第一步：准备密码清单

**在哪里操作**：客户自己的密码管理器，不写进项目文件。

下面每个账号使用不同的 32 位字母数字密码。每需要一个密码，就在虚拟机执行一次：

```bash
openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | head -c 32; echo
```

需要保存的账号包括：`nacos`，以及 auth、user、system、product、inventory、order、wallet、knowledge、ai、training、notification 各自的 `_app` 和 `_migration` 账号。不能让多个账号共用同一个密码。

### 第二步：进入不会保存 SQL 历史的 MySQL 客户端

输入：

```bash
docker exec -e MYSQL_HISTFILE=/dev/null -it ygh-mysql mysql -uroot -p
```

输入 root 密码。后续 SQL 中所有 `CHANGE_TO_..._PASSWORD` 都必须在粘贴前替换为密码管理器中的实际密码。不要把占位符原样执行。

### 第三步：创建 Nacos 配置库和账号

在 `mysql>` 中逐条输入：

```sql
CREATE DATABASE nacos_config CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
CREATE USER 'nacos'@'%' IDENTIFIED BY 'CHANGE_TO_NACOS_DB_PASSWORD';
GRANT ALL PRIVILEGES ON nacos_config.* TO 'nacos'@'%';
SHOW GRANTS FOR 'nacos'@'%';
```

每条成功后显示 `Query OK`。`SHOW GRANTS` 必须显示账号只对 `nacos_config` 有权限。Nacos 容器的安装和启动不在本文执行。

### 第四步：创建 auth、user、system 三组最小权限账号

逐组执行，上一组成功后再执行下一组：

```sql
CREATE DATABASE auth_db CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
CREATE USER 'ygh_auth_app'@'%' IDENTIFIED BY 'CHANGE_TO_AUTH_APP_PASSWORD';
CREATE USER 'ygh_auth_migration'@'%' IDENTIFIED BY 'CHANGE_TO_AUTH_MIGRATION_PASSWORD';
GRANT SELECT,INSERT,UPDATE,DELETE,CREATE,DROP,REFERENCES,INDEX,ALTER ON auth_db.* TO 'ygh_auth_migration'@'%';
SHOW GRANTS FOR 'ygh_auth_app'@'%';
SHOW GRANTS FOR 'ygh_auth_migration'@'%';
```

```sql
CREATE DATABASE user_db CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
CREATE USER 'ygh_user_app'@'%' IDENTIFIED BY 'CHANGE_TO_USER_APP_PASSWORD';
CREATE USER 'ygh_user_migration'@'%' IDENTIFIED BY 'CHANGE_TO_USER_MIGRATION_PASSWORD';
GRANT SELECT,INSERT,UPDATE,DELETE,CREATE,DROP,REFERENCES,INDEX,ALTER ON user_db.* TO 'ygh_user_migration'@'%';
SHOW GRANTS FOR 'ygh_user_app'@'%';
SHOW GRANTS FOR 'ygh_user_migration'@'%';
```

```sql
CREATE DATABASE system_db CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
CREATE USER 'ygh_system_app'@'%' IDENTIFIED BY 'CHANGE_TO_SYSTEM_APP_PASSWORD';
CREATE USER 'ygh_system_migration'@'%' IDENTIFIED BY 'CHANGE_TO_SYSTEM_MIGRATION_PASSWORD';
GRANT SELECT,INSERT,UPDATE,DELETE,CREATE,DROP,REFERENCES,INDEX,ALTER ON system_db.* TO 'ygh_system_migration'@'%';
SHOW GRANTS FOR 'ygh_system_app'@'%';
SHOW GRANTS FOR 'ygh_system_migration'@'%';
```

这三个 `_app` 账号此时只有登录权限，属于预期结果。它们的表级权限必须等 IDEA 首次启动相应服务、Flyway 建表完成后再授予，具体见第八部分。

### 第五步：逐个创建八个业务数据库和账号

每个代码块单独执行并检查 `Query OK`：

```sql
CREATE DATABASE product_db CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
CREATE USER 'ygh_product_app'@'%' IDENTIFIED BY 'CHANGE_TO_PRODUCT_APP_PASSWORD';
CREATE USER 'ygh_product_migration'@'%' IDENTIFIED BY 'CHANGE_TO_PRODUCT_MIGRATION_PASSWORD';
GRANT SELECT,INSERT,UPDATE,DELETE ON product_db.* TO 'ygh_product_app'@'%';
GRANT SELECT,INSERT,UPDATE,DELETE,CREATE,DROP,REFERENCES,INDEX,ALTER ON product_db.* TO 'ygh_product_migration'@'%';
```

```sql
CREATE DATABASE inventory_db CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
CREATE USER 'ygh_inventory_app'@'%' IDENTIFIED BY 'CHANGE_TO_INVENTORY_APP_PASSWORD';
CREATE USER 'ygh_inventory_migration'@'%' IDENTIFIED BY 'CHANGE_TO_INVENTORY_MIGRATION_PASSWORD';
GRANT SELECT,INSERT,UPDATE,DELETE ON inventory_db.* TO 'ygh_inventory_app'@'%';
GRANT SELECT,INSERT,UPDATE,DELETE,CREATE,DROP,REFERENCES,INDEX,ALTER ON inventory_db.* TO 'ygh_inventory_migration'@'%';
```

```sql
CREATE DATABASE order_db CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
CREATE USER 'ygh_order_app'@'%' IDENTIFIED BY 'CHANGE_TO_ORDER_APP_PASSWORD';
CREATE USER 'ygh_order_migration'@'%' IDENTIFIED BY 'CHANGE_TO_ORDER_MIGRATION_PASSWORD';
GRANT SELECT,INSERT,UPDATE,DELETE ON order_db.* TO 'ygh_order_app'@'%';
GRANT SELECT,INSERT,UPDATE,DELETE,CREATE,DROP,REFERENCES,INDEX,ALTER ON order_db.* TO 'ygh_order_migration'@'%';
```

```sql
CREATE DATABASE wallet_db CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
CREATE USER 'ygh_wallet_app'@'%' IDENTIFIED BY 'CHANGE_TO_WALLET_APP_PASSWORD';
CREATE USER 'ygh_wallet_migration'@'%' IDENTIFIED BY 'CHANGE_TO_WALLET_MIGRATION_PASSWORD';
GRANT SELECT,INSERT,UPDATE,DELETE ON wallet_db.* TO 'ygh_wallet_app'@'%';
GRANT SELECT,INSERT,UPDATE,DELETE,CREATE,DROP,REFERENCES,INDEX,ALTER ON wallet_db.* TO 'ygh_wallet_migration'@'%';
```

```sql
CREATE DATABASE knowledge_db CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
CREATE USER 'ygh_knowledge_app'@'%' IDENTIFIED BY 'CHANGE_TO_KNOWLEDGE_APP_PASSWORD';
CREATE USER 'ygh_knowledge_migration'@'%' IDENTIFIED BY 'CHANGE_TO_KNOWLEDGE_MIGRATION_PASSWORD';
GRANT SELECT,INSERT,UPDATE,DELETE ON knowledge_db.* TO 'ygh_knowledge_app'@'%';
GRANT SELECT,INSERT,UPDATE,DELETE,CREATE,DROP,REFERENCES,INDEX,ALTER ON knowledge_db.* TO 'ygh_knowledge_migration'@'%';
```

```sql
CREATE DATABASE ai_db CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
CREATE USER 'ygh_ai_app'@'%' IDENTIFIED BY 'CHANGE_TO_AI_APP_PASSWORD';
CREATE USER 'ygh_ai_migration'@'%' IDENTIFIED BY 'CHANGE_TO_AI_MIGRATION_PASSWORD';
GRANT SELECT,INSERT,UPDATE,DELETE ON ai_db.* TO 'ygh_ai_app'@'%';
GRANT SELECT,INSERT,UPDATE,DELETE,CREATE,DROP,REFERENCES,INDEX,ALTER ON ai_db.* TO 'ygh_ai_migration'@'%';
```

```sql
CREATE DATABASE training_db CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
CREATE USER 'ygh_training_app'@'%' IDENTIFIED BY 'CHANGE_TO_TRAINING_APP_PASSWORD';
CREATE USER 'ygh_training_migration'@'%' IDENTIFIED BY 'CHANGE_TO_TRAINING_MIGRATION_PASSWORD';
GRANT SELECT,INSERT,UPDATE,DELETE ON training_db.* TO 'ygh_training_app'@'%';
GRANT SELECT,INSERT,UPDATE,DELETE,CREATE,DROP,REFERENCES,INDEX,ALTER ON training_db.* TO 'ygh_training_migration'@'%';
```

```sql
CREATE DATABASE notification_db CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
CREATE USER 'ygh_notification_app'@'%' IDENTIFIED BY 'CHANGE_TO_NOTIFICATION_APP_PASSWORD';
CREATE USER 'ygh_notification_migration'@'%' IDENTIFIED BY 'CHANGE_TO_NOTIFICATION_MIGRATION_PASSWORD';
GRANT SELECT,INSERT,UPDATE,DELETE ON notification_db.* TO 'ygh_notification_app'@'%';
GRANT SELECT,INSERT,UPDATE,DELETE,CREATE,DROP,REFERENCES,INDEX,ALTER ON notification_db.* TO 'ygh_notification_migration'@'%';
```

最后输入：

```sql
FLUSH PRIVILEGES;
SHOW DATABASES;
SELECT user,host FROM mysql.user WHERE user LIKE 'ygh\_%' OR user='nacos' ORDER BY user;
EXIT;
```

`SHOW DATABASES` 必须包含 `nacos_config`、`auth_db`、`user_db`、`system_db` 和八个业务库。账号列表应包含 23 个项目账号：1 个 nacos 账号和 11 组 app/migration 账号。

## 第六部分：手动导入 Nacos 数据库表结构

### 第一步：在 Windows 找到项目提供的 SQL 文件

**在哪里操作**：Windows 文件资源管理器。

进入客户解压后的项目目录：

```text
项目根目录\ygh-deploy\constrained-dev\mysql\init\01-nacos-schema.sql
```

这个文件只包含 Nacos 数据表结构，不包含 MySQL root 密码和项目账号密码。

### 第二步：使用 WinSCP 单独上传 SQL 文件

打开 WinSCP，协议选择 `SFTP`，主机填写 `192.168.154.10`，端口填写 `22`，输入 SSH 用户和密码。左侧选中 `01-nacos-schema.sql`，右侧进入 `/opt/docker_mysql/import`，上传为：

```text
/opt/docker_mysql/import/01-nacos-schema.sql
```

这里是单独上传一个数据库结构文件，不是复制整个部署目录，也不是执行批量初始化脚本。

### 第三步：复制进容器并手动导入

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

```bash
ls -lh /opt/docker_mysql/import/01-nacos-schema.sql
docker cp /opt/docker_mysql/import/01-nacos-schema.sql ygh-mysql:/tmp/01-nacos-schema.sql
docker exec -e MYSQL_HISTFILE=/dev/null -it ygh-mysql mysql -uroot -p
```

输入 root 密码后，在 `mysql>` 中输入：

```sql
USE nacos_config;
SOURCE /tmp/01-nacos-schema.sql;
SHOW TABLES;
SELECT COUNT(*) AS table_count FROM information_schema.tables WHERE table_schema='nacos_config';
EXIT;
```

每条建表语句应显示 `Query OK`，`SHOW TABLES` 应看到 `config_info`、`config_info_gray`、`users`、`roles`、`permissions` 等 Nacos 表。出现 `Table already exists` 说明重复导入，停止操作并检查当前库，不要删除已有表后重来。

## 第七部分：配置防火墙和 Windows 连通性

### 第一步：只允许 Windows 宿主机访问 3306

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

```bash
sudo firewall-cmd --permanent --add-rich-rule='rule family=ipv4 source address=192.168.154.1/32 port port=3306 protocol=tcp accept'
sudo firewall-cmd --reload
sudo firewall-cmd --list-rich-rules
```

规则列表必须显示来源 `192.168.154.1/32` 和端口 3306。客户 VMnet8 地址不同时，在 Windows 执行 `ipconfig` 查看实际 IPv4，并替换规则中的来源地址。不要把 MySQL 3306 开放给 `0.0.0.0/0`。

### 第二步：从 Windows 检查端口

退出 SSH 或新开 Windows PowerShell：

```powershell
Test-NetConnection 192.168.154.10 -Port 3306
```

应显示 `TcpTestSucceeded : True`。如果为 False，依次检查虚拟机 IP、`docker ps`、容器健康状态、端口映射和 firewalld 规则。

## 第八部分：在 IDEA 中逐个配置数据库并执行 Flyway

### 第一步：理解每个服务为什么有两套账号

每个 Java 服务使用 `_migration` 账号执行 Flyway 建表和升级，使用 `_app` 账号处理业务请求。迁移账号有 DDL 权限，应用账号只有 DML 权限。不能为了省事让 Java 服务使用 root，也不能把迁移账号当作应用账号。

### 第二步：打开 IDEA 运行配置

**在哪里操作**：Windows 本机 IntelliJ IDEA。

1. 使用 IDEA 打开项目根目录，等待右下角 Maven 导入和索引完成。
2. 点击 `Run` → `Edit Configurations...`。
3. 点击左上角 `+`，选择 `Application`。
4. auth 数据库迁移配置的名称填写 `DB-Migrate-auth`，Main class 选择 `com.yuegang.zhihui.auth.AuthMigrationApplication`，`Use classpath of module` 选择 `ygh-auth-service`。
5. 找到 `Environment variables`，点击右侧编辑按钮。
6. 按下面表格为当前迁移入口填写五个变量。

项目还提供 `com.yuegang.zhihui.user.UserMigrationApplication` 和 `com.yuegang.zhihui.system.SystemMigrationApplication`。这三个类是项目源码中专门用于数据库迁移的入口：不启动 HTTP 端口，关闭 Nacos 注册，Flyway 完成后自动退出。此处不要选择普通的 `AuthApplication`、`UserApplication` 或 `SystemApplication`。

### 第三步：逐服务填写数据库变量

URL 公共格式为：

```text
jdbc:mysql://192.168.154.10:3306/数据库名?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=Asia/Shanghai
```

| IDEA 服务 | URL 变量与数据库 | 应用用户名变量 | 应用密码变量 | 迁移用户名变量 | 迁移密码变量 |
|---|---|---|---|---|---|
| `ygh-auth-service` | `YGH_AUTH_DB_URL` → `auth_db` | `YGH_AUTH_DB_APP_USERNAME=ygh_auth_app` | `YGH_AUTH_DB_APP_PASSWORD` | `YGH_AUTH_DB_MIGRATION_USERNAME=ygh_auth_migration` | `YGH_AUTH_DB_MIGRATION_PASSWORD` |
| `ygh-user-service` | `YGH_USER_DB_URL` → `user_db` | `YGH_USER_DB_APP_USERNAME=ygh_user_app` | `YGH_USER_DB_APP_PASSWORD` | `YGH_USER_DB_MIGRATION_USERNAME=ygh_user_migration` | `YGH_USER_DB_MIGRATION_PASSWORD` |
| `ygh-system-service` | `YGH_SYSTEM_DB_URL` → `system_db` | `YGH_SYSTEM_DB_APP_USERNAME=ygh_system_app` | `YGH_SYSTEM_DB_APP_PASSWORD` | `YGH_SYSTEM_DB_MIGRATION_USERNAME=ygh_system_migration` | `YGH_SYSTEM_DB_MIGRATION_PASSWORD` |
| `ygh-product-service` | `YGH_PRODUCT_DB_URL` → `product_db` | `YGH_PRODUCT_DB_APP_USERNAME=ygh_product_app` | `YGH_PRODUCT_DB_APP_PASSWORD` | `YGH_PRODUCT_DB_MIGRATION_USERNAME=ygh_product_migration` | `YGH_PRODUCT_DB_MIGRATION_PASSWORD` |
| `ygh-inventory-service` | `YGH_INVENTORY_DB_URL` → `inventory_db` | `YGH_INVENTORY_DB_APP_USERNAME=ygh_inventory_app` | `YGH_INVENTORY_DB_APP_PASSWORD` | `YGH_INVENTORY_DB_MIGRATION_USERNAME=ygh_inventory_migration` | `YGH_INVENTORY_DB_MIGRATION_PASSWORD` |
| `ygh-order-service` | `YGH_ORDER_DB_URL` → `order_db` | `YGH_ORDER_DB_APP_USERNAME=ygh_order_app` | `YGH_ORDER_DB_APP_PASSWORD` | `YGH_ORDER_DB_MIGRATION_USERNAME=ygh_order_migration` | `YGH_ORDER_DB_MIGRATION_PASSWORD` |
| `ygh-wallet-service` | `YGH_WALLET_DB_URL` → `wallet_db` | `YGH_WALLET_DB_APP_USERNAME=ygh_wallet_app` | `YGH_WALLET_DB_APP_PASSWORD` | `YGH_WALLET_DB_MIGRATION_USERNAME=ygh_wallet_migration` | `YGH_WALLET_DB_MIGRATION_PASSWORD` |
| `ygh-knowledge-service` | `YGH_KNOWLEDGE_DB_URL` → `knowledge_db` | `YGH_KNOWLEDGE_DB_APP_USERNAME=ygh_knowledge_app` | `YGH_KNOWLEDGE_DB_APP_PASSWORD` | `YGH_KNOWLEDGE_DB_MIGRATION_USERNAME=ygh_knowledge_migration` | `YGH_KNOWLEDGE_DB_MIGRATION_PASSWORD` |
| `ygh-ai-service` | `YGH_AI_DB_URL` → `ai_db` | `YGH_AI_DB_APP_USERNAME=ygh_ai_app` | `YGH_AI_DB_APP_PASSWORD` | `YGH_AI_DB_MIGRATION_USERNAME=ygh_ai_migration` | `YGH_AI_DB_MIGRATION_PASSWORD` |
| `ygh-training-service` | `YGH_TRAINING_DB_URL` → `training_db` | `YGH_TRAINING_DB_APP_USERNAME=ygh_training_app` | `YGH_TRAINING_DB_APP_PASSWORD` | `YGH_TRAINING_DB_MIGRATION_USERNAME=ygh_training_migration` | `YGH_TRAINING_DB_MIGRATION_PASSWORD` |
| `ygh-notification-service` | `YGH_NOTIFICATION_DB_URL` → `notification_db` | `YGH_NOTIFICATION_DB_APP_USERNAME=ygh_notification_app` | `YGH_NOTIFICATION_DB_APP_PASSWORD` | `YGH_NOTIFICATION_DB_MIGRATION_USERNAME=ygh_notification_migration` | `YGH_NOTIFICATION_DB_MIGRATION_PASSWORD` |

以认证服务为例，Environment variables 中填写：

```text
YGH_AUTH_DB_URL=jdbc:mysql://192.168.154.10:3306/auth_db?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=Asia/Shanghai
YGH_AUTH_DB_APP_USERNAME=ygh_auth_app
YGH_AUTH_DB_APP_PASSWORD=填写认证应用账号真实密码
YGH_AUTH_DB_MIGRATION_USERNAME=ygh_auth_migration
YGH_AUTH_DB_MIGRATION_PASSWORD=填写认证迁移账号真实密码
```

其他服务按表格替换前缀、数据库名、账号和密码。不要把真实密码写入 `application.yml`。

### 第四步：确认迁移执行时机并准备额外变量

MySQL 容器、数据库和账号在第七部分完成后已经可以交付给 Nacos 使用。下面的 Java Flyway 操作不要立刻执行，必须先完成 Redis 和 Nacos 的安装配置，再返回本文继续。原因是三个迁移入口虽然不会向 Nacos 注册，但 Spring 仍会读取项目配置中的必填变量；使用临时假值容易在后续正式启动时遗留错误配置。

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端，以及客户自己的密码管理器。

下列项目密钥每项单独执行一次命令，每得到一行结果就立即按对应名称保存到密码管理器：

```bash
openssl rand -base64 32
```

依次生成并保存：

1. `YGH_INTERNAL_REQUEST_HMAC_BASE64`：auth、user、system 使用同一个值。
2. `YGH_AUTH_AUDIT_PEPPER_BASE64`：只给 auth 使用。
3. `YGH_USER_PII_KEY_BASE64`：只给 user 使用。
4. `YGH_SYSTEM_CONFIG_MASTER_KEY_BASE64`：只给 system 使用。

**执行后的结果**：每次输出应是一行 Base64 字符串。四项必须分别保存，不能混用，不能写进 Markdown、`application.yml` 或聊天记录。

**在哪里操作**：Windows 本机 IntelliJ IDEA 的 `Run` → `Edit Configurations...` → 对应迁移配置 → `Environment variables`。

除上一节的五个数据库变量外，还要逐项添加：

| 迁移配置 | 额外变量 | 填写内容 |
|---|---|---|
| 三个配置都填写 | `YGH_NACOS_SERVER_ADDR` | `192.168.154.10:8848`，IP 不同时替换 |
| 三个配置都填写 | `YGH_NACOS_USERNAME` | Nacos 配置文档中实际创建的用户名 |
| 三个配置都填写 | `YGH_NACOS_PASSWORD` | Nacos 配置文档中该用户的真实密码 |
| 三个配置都填写 | `YGH_INTERNAL_REQUEST_HMAC_BASE64` | 密码管理器中刚生成的同一个 HMAC 值 |
| `DB-Migrate-auth` | `YGH_REDIS_HOST` | `192.168.154.10`，IP 不同时替换 |
| `DB-Migrate-auth` | `YGH_REDIS_PORT` | `6379` |
| `DB-Migrate-auth` | `YGH_REDIS_PASSWORD` | Redis 配置文档中保存的真实密码 |
| `DB-Migrate-auth` | `YGH_REDIS_ENVIRONMENT` | `dev` |
| `DB-Migrate-auth` | `YGH_AUTH_ID_WORKER` | `1` |
| `DB-Migrate-auth` | `YGH_AUTH_AUDIT_PEPPER_BASE64` | 对应的真实 Base64 值 |
| `DB-Migrate-auth` | `YGH_SYSTEM_INTERNAL_BASE_URL` | `http://127.0.0.1:8083`；迁移期间不会调用，只用于满足必填配置 |
| `DB-Migrate-user` | `YGH_USER_PII_KEY_BASE64` | 对应的真实 Base64 值 |
| `DB-Migrate-user` | `YGH_USER_PII_KEY_VERSION` | `1` |
| `DB-Migrate-system` | `YGH_SYSTEM_CONFIG_MASTER_KEY_BASE64` | 对应的真实 Base64 值 |

填写后点击环境变量窗口的 `OK`，再点击运行配置窗口的 `Apply`。不要在 Nacos 尚未安装、真实 Nacos 用户名和密码还不存在时执行下面的迁移入口。

### 第五步：运行 auth 专用迁移入口并确认 Flyway

**在哪里操作**：Windows 本机 IntelliJ IDEA。

一次只处理一个迁移入口。先从 auth 开始：

1. 在 IDEA 顶部运行配置下拉框中选择刚创建的 `DB-Migrate-auth`。
2. 再次打开 `Run` → `Edit Configurations...`，核对五个数据库变量都已填写，尤其不能把 app 密码与 migration 密码填反。
3. 点击 `OK` 返回主界面。
4. 点击运行配置右侧的绿色三角形。
5. 打开下方 `Run` 窗口，不要看到 Java 进程出现后就马上进行下一项；继续观察 Flyway 日志。
6. 必须看到 Flyway 对 `auth_db` 完成迁移，且 `flyway_schema_history` 已建立。
7. 迁移入口会自动关闭 Spring 上下文并结束进程。看到 `Process finished with exit code 0` 后才进入下一步；不需要点击红色方块强制停止。

auth、user、system 三个应用账号在建表前故意没有表权限，所以先运行专用迁移入口，让 `_migration` 账号完成 Flyway，再手动授予 app 账号表级权限。如果 Flyway 出现 `Access denied`，说明 migration 用户名、密码或授权有误，不能继续授权步骤。

**执行后的结果**：Flyway 日志应显示迁移成功，最终退出码为 0，不能出现 `Unknown database`、`Communications link failure` 或 migration checksum 错误。此时不要运行普通 auth 服务，先到下一步检查数据库记录并授予应用账号权限。

**需要修改的内容**：创建 user 和 system 迁移配置时，分别更换配置名称、Main class、classpath 模块、环境变量前缀和数据库名。一次只运行一个，确认当前迁移完成后再处理下一个。

每个服务完成后，在 MySQL 中检查：

```bash
docker exec -e MYSQL_HISTFILE=/dev/null -it ygh-mysql mysql -uroot -p
```

```sql
SELECT installed_rank,version,description,success FROM auth_db.flyway_schema_history ORDER BY installed_rank;
```

检查其他服务时把 `auth_db` 改为对应数据库。所有记录的 `success` 必须为 1。

### 第六步：Flyway 建表后授予 auth 应用账号表级权限

进入 root MySQL 客户端，输入：

```sql
GRANT SELECT,INSERT,UPDATE,DELETE ON auth_db.auth_account TO 'ygh_auth_app'@'%';
GRANT SELECT,INSERT,UPDATE,DELETE ON auth_db.auth_credential TO 'ygh_auth_app'@'%';
GRANT SELECT,INSERT,UPDATE,DELETE ON auth_db.auth_refresh_token TO 'ygh_auth_app'@'%';
GRANT SELECT,INSERT,UPDATE,DELETE ON auth_db.auth_login_attempt TO 'ygh_auth_app'@'%';
GRANT SELECT,INSERT,UPDATE,DELETE ON auth_db.auth_account_admin_audit TO 'ygh_auth_app'@'%';
GRANT SELECT,INSERT,UPDATE,DELETE ON auth_db.auth_password_reset TO 'ygh_auth_app'@'%';
SHOW GRANTS FOR 'ygh_auth_app'@'%';
EXIT;
```

**执行后的结果**：六条 `GRANT` 均应显示 `Query OK`；`SHOW GRANTS` 应列出六张 auth 表的 `SELECT, INSERT, UPDATE, DELETE` 权限。auth 的数据库迁移与授权到这里完成，普通 auth 服务留到 Redis、Nacos 及其余项目依赖全部配置后再启动。

### 第七步：Flyway 建表后授予 user 应用账号表级权限

**在哪里操作**：Windows 本机 IntelliJ IDEA。

auth 授权完成后，再处理 user 数据库迁移：

1. 打开 `Run` → `Edit Configurations...`，点击左上角 `+`，选择 `Application`。
2. Name 填写 `DB-Migrate-user`。
3. Main class 选择 `com.yuegang.zhihui.user.UserMigrationApplication`，classpath 模块选择 `ygh-user-service`。
4. 填写 `YGH_USER_DB_URL`、app 用户名与密码、migration 用户名与密码共五项。
5. 点击 `OK`，选择 `DB-Migrate-user`，再点击绿色三角形。
6. 观察日志，确认 Flyway 已对 `user_db` 完成迁移，并以 `Process finished with exit code 0` 自动结束。

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。先输入：

```bash
docker exec -e MYSQL_HISTFILE=/dev/null -it ygh-mysql mysql -uroot -p
```

看到 `Enter password:` 后输入 root 密码，再在 `mysql>` 中先检查 Flyway，然后逐条授权：

```sql
SELECT installed_rank,version,description,success FROM user_db.flyway_schema_history ORDER BY installed_rank;
GRANT SELECT,INSERT,UPDATE,DELETE ON user_db.user_profile TO 'ygh_user_app'@'%';
GRANT SELECT,INSERT,UPDATE,DELETE ON user_db.user_department TO 'ygh_user_app'@'%';
GRANT SELECT,INSERT,UPDATE,DELETE ON user_db.user_position TO 'ygh_user_app'@'%';
GRANT SELECT,INSERT,UPDATE,DELETE ON user_db.user_employee TO 'ygh_user_app'@'%';
GRANT SELECT,INSERT,UPDATE,DELETE ON user_db.user_employee_position TO 'ygh_user_app'@'%';
GRANT SELECT,INSERT,UPDATE,DELETE ON user_db.user_address TO 'ygh_user_app'@'%';
SHOW GRANTS FOR 'ygh_user_app'@'%';
EXIT;
```

**执行后的结果**：Flyway 历史全部成功，六张 user 表授权成功。普通 user 服务此时不启动，继续处理 system 数据库迁移。

### 第八步：Flyway 建表后授予 system 应用账号表级权限

**在哪里操作**：Windows 本机 IntelliJ IDEA。

user 授权完成后，再处理 system 数据库迁移：

1. 打开 `Run` → `Edit Configurations...`，点击左上角 `+`，选择 `Application`。
2. Name 填写 `DB-Migrate-system`。
3. Main class 选择 `com.yuegang.zhihui.system.SystemMigrationApplication`，classpath 模块选择 `ygh-system-service`。
4. 填写 `YGH_SYSTEM_DB_URL`、app 用户名与密码、migration 用户名与密码共五项。
5. 点击 `OK`，选择 `DB-Migrate-system`，再点击绿色三角形。
6. 观察日志，确认 Flyway 已对 `system_db` 完成迁移，并以 `Process finished with exit code 0` 自动结束。

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。先重新进入 root MySQL 客户端：

```bash
docker exec -e MYSQL_HISTFILE=/dev/null -it ygh-mysql mysql -uroot -p
```

输入 root 密码后，在 `mysql>` 中逐条输入：

```sql
SELECT installed_rank,version,description,success FROM system_db.flyway_schema_history ORDER BY installed_rank;
GRANT SELECT,INSERT,UPDATE,DELETE ON system_db.system_role TO 'ygh_system_app'@'%';
GRANT SELECT,INSERT,UPDATE,DELETE ON system_db.system_permission TO 'ygh_system_app'@'%';
GRANT SELECT,INSERT,UPDATE,DELETE ON system_db.system_role_permission TO 'ygh_system_app'@'%';
GRANT SELECT,INSERT,UPDATE,DELETE ON system_db.system_user_authorization TO 'ygh_system_app'@'%';
GRANT SELECT,INSERT,UPDATE,DELETE ON system_db.system_user_role TO 'ygh_system_app'@'%';
GRANT SELECT,INSERT,UPDATE,DELETE ON system_db.system_authorization_audit TO 'ygh_system_app'@'%';
GRANT SELECT,INSERT,UPDATE,DELETE ON system_db.system_dictionary_type TO 'ygh_system_app'@'%';
GRANT SELECT,INSERT,UPDATE,DELETE ON system_db.system_dictionary_item TO 'ygh_system_app'@'%';
GRANT SELECT,INSERT,UPDATE,DELETE ON system_db.system_setting TO 'ygh_system_app'@'%';
GRANT SELECT,INSERT,UPDATE,DELETE ON system_db.system_feature_flag TO 'ygh_system_app'@'%';
GRANT SELECT,INSERT,UPDATE,DELETE ON system_db.system_configuration_audit TO 'ygh_system_app'@'%';
GRANT SELECT,INSERT,UPDATE,DELETE ON system_db.system_ai_provider_config TO 'ygh_system_app'@'%';
SHOW GRANTS FOR 'ygh_system_app'@'%';
EXIT;
```

**执行后的结果**：Flyway 历史全部成功，十二张 system 表授权成功。普通 system 服务留到项目全部依赖配置完成后启动。

### 第九步：记录其余八个服务的后续迁移检查项

product、inventory、order、wallet、knowledge、ai、training、notification 的 `_app` 账号已经在第五部分获得各自数据库的 DML 权限，不需要再执行表级授权。这些普通服务还依赖 Nacos，部分服务还依赖 Redis、RocketMQ、PGVector 或项目密钥，因此在 MySQL 配置阶段不要为了建表提前启动。

等全部组件配置完成，执行项目启动操作文档时，必须按下面顺序一次只启动一个，并核对对应数据库：

1. `ygh-product-service`：URL 使用 `product_db`，确认 Flyway 成功后检查 `product_db.flyway_schema_history`。
2. `ygh-inventory-service`：URL 使用 `inventory_db`，确认 Flyway 成功后检查 `inventory_db.flyway_schema_history`。
3. `ygh-order-service`：URL 使用 `order_db`，确认 Flyway 成功后检查 `order_db.flyway_schema_history`。
4. `ygh-wallet-service`：URL 使用 `wallet_db`，确认 Flyway 成功后检查 `wallet_db.flyway_schema_history`。
5. `ygh-knowledge-service`：URL 使用 `knowledge_db`，确认 Flyway 成功后检查 `knowledge_db.flyway_schema_history`。
6. `ygh-ai-service`：URL 使用 `ai_db`，确认 Flyway 成功后检查 `ai_db.flyway_schema_history`。
7. `ygh-training-service`：URL 使用 `training_db`，确认 Flyway 成功后检查 `training_db.flyway_schema_history`。
8. `ygh-notification-service`：URL 使用 `notification_db`，确认 Flyway 成功后检查 `notification_db.flyway_schema_history`。

届时每次都在 IDEA 顶部选择对应运行配置，打开 `Run` → `Edit Configurations...` 核对表格中的五个变量和该服务的其他依赖变量，点击 `OK`，再点击绿色三角形。当前服务 Flyway 未成功前不要启动下一服务。检查历史时，在虚拟机进入 root MySQL 客户端，把下面的 `数据库名` 替换成当前行写明的数据库：

```sql
SELECT installed_rank,version,description,success FROM 数据库名.flyway_schema_history ORDER BY installed_rank;
```

**执行后的结果**：最终启动项目后，八个数据库都应存在 `flyway_schema_history`，每条记录的 `success` 都为 1。当前 MySQL 安装步骤不要求这八个数据库已经建出业务表；此时数据库和账号存在、账号授权正确即为正常状态。

## 第九部分：日常启停、备份和恢复

### 第一步：停止、启动和重启

**在哪里操作**：Rocky Linux 虚拟机 SSH 终端。

```bash
docker stop ygh-mysql
docker start ygh-mysql
docker restart ygh-mysql
docker logs --tail 200 ygh-mysql
```

停止容器不会删除 `/opt/docker_mysql/data`。Java 服务依赖 MySQL，停止 MySQL 前先在 IDEA 停止正在使用数据库的 Java 服务。

### 第二步：手动备份全部数据库

```bash
backup_file="/opt/mysql-backups/mysql-all-$(date +%Y%m%d-%H%M%S).sql"
docker exec ygh-mysql sh -c 'MYSQL_PWD="$(cat /run/secrets/mysql-root-password)" mysqldump -uroot --all-databases --single-transaction --routines --events' > "$backup_file"
sha256sum "$backup_file" > "$backup_file.sha256"
ls -lh "$backup_file" "$backup_file.sha256"
```

备份文件必须大于 0 字节。把 SQL 和 `.sha256` 一起复制到客户备份存储，不只保存在虚拟机系统盘。

### 第三步：恢复前先保护现有数据

恢复会修改数据库，必须先停止 IDEA 中全部 Java 服务并再做一次当前备份。确认恢复文件的 SHA256 后才执行：

```bash
sha256sum -c /opt/mysql-backups/要恢复的文件.sql.sha256
docker exec -i ygh-mysql sh -c 'MYSQL_PWD="$(cat /run/secrets/mysql-root-password)" mysql -uroot' < /opt/mysql-backups/要恢复的文件.sql
```

校验必须显示 `OK`。恢复完成后重新检查数据库、账号、Flyway 历史和应用健康。不要在不知道备份来源和版本时直接恢复。

## 第十部分：常见错误逐项排查

### 1. `Access denied for user`

检查 IDEA 中的用户名和密码是否对应同一账号；检查账号 Host 是否为 `%`；执行 `SHOW GRANTS FOR '账号'@'%';`。不要改用 root 绕过权限错误。

### 2. `Unknown database`

进入 root MySQL 执行 `SHOW DATABASES;`，确认 URL 中的数据库名与实际名称完全一致，例如 `auth_db`，不是 `auth-db`。

### 3. `Communications link failure`

依次检查 `docker ps`、容器 Health、`Test-NetConnection`、3306 端口映射和 firewalld。连接失败不是 Flyway 问题。

### 4. 容器启动后立即退出

执行：

```bash
docker ps -a --filter name=ygh-mysql
docker logs --tail 200 ygh-mysql
```

重点检查配置项拼写、数据目录权限、SELinux 标签和 root 密码文件挂载。

### 5. 修改 root 密码文件后密码没有变化

官方 MySQL 镜像只在空数据目录首次初始化时读取 `MYSQL_ROOT_PASSWORD_FILE`。数据目录已经存在时，修改宿主机密码文件不会自动修改数据库中的 root 密码。必须登录 MySQL 后使用 `ALTER USER` 正式修改，并同步更新密码文件；不能删除数据目录重新初始化。
