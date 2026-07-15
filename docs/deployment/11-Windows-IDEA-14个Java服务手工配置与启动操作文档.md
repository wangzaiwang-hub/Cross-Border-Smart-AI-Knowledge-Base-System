# Windows IDEA 14 个 Java 服务手工配置与启动操作文档

本文从已经安装好 Oracle JDK 25、IntelliJ IDEA，并已将项目压缩包解压到 `D:\ygh-ai-system` 的状态开始。本文不使用 Git、不使用 `.env`、不使用 Docker Compose、不使用批处理或启动脚本。每个 Java 服务都在客户 Windows 本机的 IDEA 中单独配置、单独启动。

## 第一部分：确认组件已经处于可连接状态

### 第一步：确认本次操作所在位置

**在哪里操作**：客户 Windows 本机。

本项目各部分的实际运行位置如下：

| 内容 | 运行位置 |
|---|---|
| 14 个 Java 服务 | Windows 本机 IntelliJ IDEA |
| MySQL、Redis、Nacos、PostgreSQL/PGVector | Rocky Linux 虚拟机内的 Docker |
| RocketMQ、Elasticsearch | Windows 本机 Docker Desktop |
| Seata | Windows 本机 Docker Desktop；启动 Training 前必须停止 |
| 商城前端、管理前端 | Windows 本机 IDEA 终端 |

**执行后的结果**：后文标为“IDEA”的变量只能填入 IDEA 运行配置，不要输入 Rocky Linux SSH 终端，也不要写入 Docker 容器。

### 第二步：检查虚拟机网络地址

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
Test-NetConnection 192.168.154.10 -Port 3306
Test-NetConnection 192.168.154.10 -Port 6379
Test-NetConnection 192.168.154.10 -Port 8848
Test-NetConnection 192.168.154.10 -Port 5432
```

**执行后的结果**：四次检查的 `TcpTestSucceeded` 都必须为 `True`。

**需要修改的内容**：如果客户虚拟机不是 `192.168.154.10`，后文所有 `192.168.154.10` 都替换为该虚拟机的固定 IPv4。不要只修改数据库 URL 而漏改 Redis、Nacos 或 PGVector。

### 第三步：确认 Windows Docker 组件

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
Test-NetConnection 127.0.0.1 -Port 19876
Test-NetConnection 127.0.0.1 -Port 19200
```

**执行后的结果**：

1. RocketMQ NameServer 和 Broker 容器为 `Up`，`19876` 检查为 `True`。
2. Elasticsearch 容器为 `Up (healthy)`，`19200` 检查为 `True`。
3. Seata 可以暂时运行，但启动 Training 前必须停止，因为两者都使用 Windows 端口 `8091`。

**注意事项**：`19876` 是 Windows 映射后的 NameServer 端口。IDEA 服务不能填写容器内部的 `9876`。

### 第四步：确认 Windows 可被虚拟机访问的地址

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
Get-NetIPAddress -AddressFamily IPv4 |
  Where-Object {$_.IPAddress -like '192.168.154.*'} |
  Select-Object InterfaceAlias,IPAddress,PrefixLength
```

**执行后的结果**：VMware 的 VMnet8 网卡通常显示 `192.168.154.1/24`。

**需要修改的内容**：后文用 `192.168.154.1` 作为 Windows Java 服务向 Nacos 注册的 IP。如果此处显示其他地址，将后文的 `192.168.154.1` 全部替换为实际 VMnet8 IPv4。

**配置原因**：项目使用的 Nacos Discovery 2025.1.0.0 确实支持 `spring.cloud.nacos.discovery.ip`。环境变量 `SPRING_CLOUD_NACOS_DISCOVERY_IP` 会绑定到该属性。若不指定，多网卡电脑可能错误注册 Wi-Fi、VPN、WSL 或 Docker 地址，网关将无法调用服务。

## 第二部分：在 Windows 手工准备密钥和数据目录

### 第五步：建立本机密钥与业务文件目录

**在哪里操作**：Windows 本机 PowerShell。

逐条输入：

```powershell
New-Item -ItemType Directory -Force 'D:\ygh-secrets\jwt'
New-Item -ItemType Directory -Force 'D:\ygh-data\knowledge'
New-Item -ItemType Directory -Force 'D:\ygh-data\training'
```

**执行后的结果**：三条命令的 `Mode` 中显示目录标记 `d`，路径分别存在。

### 第六步：生成四个用途不同的 32 字节密钥

**在哪里操作**：Windows 本机 PowerShell。

每次单独输入下面命令，共执行四次：

```powershell
[Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
```

**执行后的结果**：每次得到一条通常为 44 个字符、末尾可能带 `=` 的 Base64 文本。

按执行顺序分别记录到客户密码管理器：

| 次数 | 密码管理器记录名称 | 后文变量 |
|---|---|---|
| 第 1 次 | YGH-内部请求签名密钥 | `YGH_INTERNAL_REQUEST_HMAC_BASE64` |
| 第 2 次 | YGH-认证审计Pepper | `YGH_AUTH_AUDIT_PEPPER_BASE64` |
| 第 3 次 | YGH-用户隐私加密密钥 | `YGH_USER_PII_KEY_BASE64` |
| 第 4 次 | YGH-系统配置主密钥 | `YGH_SYSTEM_CONFIG_MASTER_KEY_BASE64` |

**注意事项**：四个值不能相同。第 1 个值必须在全部 14 个服务中保持一致；其余三个只填入各自服务。不要把密钥写进 Markdown、源码、截图或聊天记录。

### 第七步：生成认证服务 RSA 密钥对

**在哪里操作**：Windows 本机 PowerShell。以下命令逐行执行，不创建 `.ps1` 文件。

```powershell
$rsa = [Security.Cryptography.RSA]::Create(3072)
```

```powershell
[IO.File]::WriteAllText('D:\ygh-secrets\jwt\auth-dev-2026.private.pem',$rsa.ExportPkcs8PrivateKeyPem())
```

```powershell
[IO.File]::WriteAllText('D:\ygh-secrets\jwt\auth-dev-2026.public.pem',$rsa.ExportSubjectPublicKeyInfoPem())
```

```powershell
$rsa.Dispose()
```

**执行后的结果**：前四条命令正常时不输出密钥正文。继续输入：

```powershell
Get-ChildItem 'D:\ygh-secrets\jwt' | Select-Object Name,Length
Get-Content 'D:\ygh-secrets\jwt\auth-dev-2026.private.pem' -TotalCount 1
Get-Content 'D:\ygh-secrets\jwt\auth-dev-2026.public.pem' -TotalCount 1
```

应看到两个文件，首行分别为 `-----BEGIN PRIVATE KEY-----` 和 `-----BEGIN PUBLIC KEY-----`。

**注意事项**：只能检查首行，禁止执行不带 `-TotalCount 1` 的私钥读取命令。`auth-dev-2026` 是 Key ID，后文 `YGH_JWT_ACTIVE_KID` 必须与文件名前缀完全一致。

## 第三部分：在 IDEA 建立运行配置的方法

### 第八步：打开项目并确认 Oracle JDK

**在哪里操作**：Windows 本机 IntelliJ IDEA。

1. 启动 IDEA，点击 `Open`。
2. 选择 `D:\ygh-ai-system\pom.xml` 所在的项目根目录，点击 `OK`。
3. 如果询问是否信任项目，点击 `Trust Project`。
4. 等待右下角 Maven 导入结束。
5. 点击 `File` → `Project Structure` → `Project`。
6. `SDK` 选择 Oracle JDK 25，`Language level` 选择 `24`。
7. 点击 `Apply` → `OK`。

**执行后的结果**：IDEA 使用 Oracle JDK 25 运行 Maven 和 Java 服务；源码目标级别仍按根 `pom.xml` 固定为 Java 24。

### 第九步：掌握单个服务运行配置的创建方式

**在哪里操作**：IDEA。

1. 点击顶部菜单 `Run` → `Edit Configurations...`。
2. 点击左上角 `+`，选择 `Application`。
3. 在 `Name` 填本文指定的运行配置名称。
4. 在 `Main class` 填本文指定的完整类名。
5. 在 `Use classpath of module` 选择本文指定模块。
6. `JRE` 选择 `Project SDK (Oracle JDK 25)`。
7. 点击 `Environment variables` 右侧编辑按钮。
8. 在弹窗中点击 `+`，一行一个变量地填写 `Name` 和 `Value`。
9. 填完点击环境变量弹窗的 `OK`，再点击 `Apply`。

**执行后的结果**：左侧出现一个可独立启动的 IDEA Application 配置。

**注意事项**：不要勾选“在系统环境中共享秘密”，不要把变量写到项目文件。后文表格里标为“密码管理器”的值必须从客户自己的密码管理器填写。

### 第十步：所有普通服务都要添加的六个 Nacos 变量

**在哪里操作**：每一个普通服务的 IDEA `Environment variables` 窗口。

每个服务都逐行添加：

| Name | Value |
|---|---|
| `YGH_NACOS_SERVER_ADDR` | `192.168.154.10:8848` |
| `YGH_NACOS_USERNAME` | `nacos` |
| `YGH_NACOS_PASSWORD` | 填 Nacos 文档中设置的真实密码 |
| `YGH_NACOS_NAMESPACE` | `ygh-dev` |
| `YGH_NACOS_DISCOVERY_GROUP` | `YGH_GROUP` |
| `SPRING_CLOUD_NACOS_DISCOVERY_IP` | `192.168.154.1` |

**执行后的结果**：普通服务启动后在 Nacos 的 `ygh-dev` 命名空间、`YGH_GROUP` 分组中注册为 `192.168.154.1:服务端口`。

**注意事项**：auth、user、system、gateway 还有源码中专用的 IP 变量，后文仍会明确填写。迁移入口不向 Nacos 注册，但其配置文件仍含必填 Nacos账号，因此按迁移章节填写。

## 第四部分：首次执行 auth、user、system 数据库迁移

Flyway 是项目的 Maven 依赖，不是 IDEA 中单独安装的软件或必须出现的运行配置类型。下面创建的三个配置全部选择 `Application`。开始前必须先完成《02-MySQL-8.4.10-Docker镜像手工安装与项目配置操作文档》第八部分第二步至第七步，确认 Maven 已导入、Oracle JDK 25 已生效、三个 `*MigrationApplication.java` 文件真实存在且可以编译。Main class 搜索不到时不要继续填写变量，也不要改用普通服务启动类。

### 第十一步：创建 auth 数据库迁移配置

**在哪里操作**：IDEA `Run` → `Edit Configurations...`。

填写：

```text
Name: DB-Migrate-auth
Main class: com.yuegang.zhihui.auth.AuthMigrationApplication
Use classpath of module: ygh-auth-service
JRE: Project SDK (Oracle JDK 25)
```

在 `Environment variables` 中逐行填写：

| Name | Value |
|---|---|
| `YGH_AUTH_DB_URL` | `jdbc:mysql://192.168.154.10:3306/auth_db?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=Asia/Shanghai` |
| `YGH_AUTH_DB_APP_USERNAME` | `ygh_auth_app` |
| `YGH_AUTH_DB_APP_PASSWORD` | auth app 真实密码 |
| `YGH_AUTH_DB_MIGRATION_USERNAME` | `ygh_auth_migration` |
| `YGH_AUTH_DB_MIGRATION_PASSWORD` | auth migration 真实密码 |
| `YGH_NACOS_SERVER_ADDR` | `192.168.154.10:8848` |
| `YGH_NACOS_USERNAME` | `nacos` |
| `YGH_NACOS_PASSWORD` | Nacos 真实密码 |
| `YGH_SYSTEM_INTERNAL_BASE_URL` | `http://127.0.0.1:8083` |
| `YGH_NOTIFICATION_INTERNAL_BASE_URL` | `http://127.0.0.1:8092` |
| `YGH_REDIS_HOST` | `192.168.154.10` |
| `YGH_REDIS_PASSWORD` | Redis 真实密码 |
| `YGH_REDIS_ENVIRONMENT` | `dev` |
| `YGH_INTERNAL_REQUEST_HMAC_BASE64` | 第六步第 1 个值 |
| `YGH_AUTH_ID_WORKER` | `1` |
| `YGH_AUTH_AUDIT_PEPPER_BASE64` | 第六步第 2 个值 |

没有列出的带默认值端口、Redis 端口、命名空间和分组可使用源码默认值。

### 第十二步：运行 auth 迁移并完成表授权

**在哪里操作**：IDEA。

1. 顶部运行配置选择 `DB-Migrate-auth`。
2. 点击绿色运行三角。
3. 等待 Flyway 日志完成。
4. 必须看到 `Process finished with exit code 0`；该入口会自动退出，不要手动停止。
5. 回到《02-MySQL-8.4.10-Docker镜像手工安装与项目配置操作文档》第八部分第十二步，逐条执行六张 auth 表的 `GRANT`。

**执行后的结果**：`auth_db.flyway_schema_history` 建立且记录成功，`ygh_auth_app` 获得六张 auth 表的 DML 权限。

**故障判断**：出现 `Access denied` 时核对 migration 账号与密码；出现 `Communications link failure` 时回到第二步检查 `3306`；不能改成 root 用户绕过错误。

### 第十三步：创建并运行 user 数据库迁移配置

**在哪里操作**：IDEA `Run` → `Edit Configurations...`。

填写：

```text
Name: DB-Migrate-user
Main class: com.yuegang.zhihui.user.UserMigrationApplication
Use classpath of module: ygh-user-service
```

逐行添加变量：

| Name | Value |
|---|---|
| `YGH_USER_PORT` | `8082` |
| `YGH_USER_DB_URL` | `jdbc:mysql://192.168.154.10:3306/user_db?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=Asia/Shanghai` |
| `YGH_USER_DB_APP_USERNAME` | `ygh_user_app` |
| `YGH_USER_DB_APP_PASSWORD` | user app 真实密码 |
| `YGH_USER_DB_MIGRATION_USERNAME` | `ygh_user_migration` |
| `YGH_USER_DB_MIGRATION_PASSWORD` | user migration 真实密码 |
| `YGH_NACOS_SERVER_ADDR` | `192.168.154.10:8848` |
| `YGH_NACOS_USERNAME` | `nacos` |
| `YGH_NACOS_PASSWORD` | Nacos 真实密码 |
| `YGH_USER_PII_KEY_BASE64` | 第六步第 3 个值 |
| `YGH_INTERNAL_REQUEST_HMAC_BASE64` | 第六步第 1 个值 |

点击 `Apply`，运行 `DB-Migrate-user`。看到退出码 0 后，按 MySQL 文档第八部分第十三步逐条授予六张 user 表权限。

**执行后的结果**：user 迁移入口自动结束，`flyway_schema_history` 成功，user app 表权限完成。

### 第十四步：创建并运行 system 数据库迁移配置

**在哪里操作**：IDEA `Run` → `Edit Configurations...`。

填写：

```text
Name: DB-Migrate-system
Main class: com.yuegang.zhihui.system.SystemMigrationApplication
Use classpath of module: ygh-system-service
```

逐行添加变量：

| Name | Value |
|---|---|
| `YGH_SYSTEM_DB_URL` | `jdbc:mysql://192.168.154.10:3306/system_db?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=Asia/Shanghai` |
| `YGH_SYSTEM_DB_APP_USERNAME` | `ygh_system_app` |
| `YGH_SYSTEM_DB_APP_PASSWORD` | system app 真实密码 |
| `YGH_SYSTEM_DB_MIGRATION_USERNAME` | `ygh_system_migration` |
| `YGH_SYSTEM_DB_MIGRATION_PASSWORD` | system migration 真实密码 |
| `YGH_NACOS_SERVER_ADDR` | `192.168.154.10:8848` |
| `YGH_NACOS_USERNAME` | `nacos` |
| `YGH_NACOS_PASSWORD` | Nacos 真实密码 |
| `YGH_INTERNAL_REQUEST_HMAC_BASE64` | 第六步第 1 个值 |
| `YGH_SYSTEM_CONFIG_MASTER_KEY_BASE64` | 第六步第 4 个值 |

点击 `Apply`，运行 `DB-Migrate-system`。看到退出码 0 后，按 MySQL 文档第八部分第十四步逐条授予十二张 system 表权限。

**执行后的结果**：三个特殊数据库迁移全部完成。以后升级源码时仍先运行这三个迁移入口，再启动三个普通服务。

## 第五部分：按依赖顺序启动 14 个普通服务

每次只启动当前小节的一个服务。看到健康检查成功后再进入下一小节。低配置电脑不要同时常驻全部服务，本文第六部分给出按场景启停方式。

### 第十五步：配置并启动 User 服务

**在哪里操作**：IDEA `Run` → `Edit Configurations...`。

创建配置：

```text
Name: YGH-01-User-8082
Main class: com.yuegang.zhihui.user.UserApplication
Use classpath of module: ygh-user-service
```

在 `Environment variables` 中逐行填写：

| Name | Value |
|---|---|
| `YGH_USER_DB_URL` | `jdbc:mysql://192.168.154.10:3306/user_db?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=Asia/Shanghai` |
| `YGH_USER_DB_APP_USERNAME` | `ygh_user_app` |
| `YGH_USER_DB_APP_PASSWORD` | user app 真实密码 |
| `YGH_USER_DB_MIGRATION_USERNAME` | `ygh_user_migration` |
| `YGH_USER_DB_MIGRATION_PASSWORD` | user migration 真实密码 |
| `SPRING_FLYWAY_ENABLED` | `false` |
| `YGH_NACOS_SERVER_ADDR` | `192.168.154.10:8848` |
| `YGH_NACOS_USERNAME` | `nacos` |
| `YGH_NACOS_PASSWORD` | Nacos 真实密码 |
| `YGH_NACOS_NAMESPACE` | `ygh-dev` |
| `YGH_NACOS_DISCOVERY_GROUP` | `YGH_GROUP` |
| `YGH_USER_ADVERTISE_IP` | `192.168.154.1` |
| `SPRING_CLOUD_NACOS_DISCOVERY_IP` | `192.168.154.1` |
| `YGH_USER_PII_KEY_BASE64` | 第六步第 3 个值 |
| `YGH_USER_PII_KEY_VERSION` | `1` |
| `YGH_USER_ID_WORKER` | `2` |
| `YGH_INTERNAL_REQUEST_HMAC_BASE64` | 第六步第 1 个值 |

连接池保持本项目低配置默认值：`YGH_USER_DB_POOL_MAX_SIZE=5`、`YGH_USER_DB_POOL_MIN_IDLE=1`。只有经过并发和数据库连接数评估后才修改，不要为了“性能”直接调大。

点击 `Apply` → `Run`。日志出现 `Started UserApplication` 后，在 PowerShell 输入：

```powershell
Invoke-RestMethod 'http://127.0.0.1:8082/actuator/health'
```

**执行后的结果**：返回内容中 `status` 为 `UP`；Nacos 服务列表出现 `ygh-user-service`，实例为 `192.168.154.1:8082`。

**故障判断**：若提示表不存在，说明第十三步迁移或授权未完成；不要删除数据库重试。

### 第十六步：配置并启动 System 服务

**在哪里操作**：IDEA。

创建配置：

```text
Name: YGH-02-System-8083
Main class: com.yuegang.zhihui.system.SystemApplication
Use classpath of module: ygh-system-service
```

逐行填写：

| Name | Value |
|---|---|
| `YGH_SYSTEM_PORT` | `8083` |
| `YGH_SYSTEM_DB_URL` | `jdbc:mysql://192.168.154.10:3306/system_db?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=Asia/Shanghai` |
| `YGH_SYSTEM_DB_APP_USERNAME` | `ygh_system_app` |
| `YGH_SYSTEM_DB_APP_PASSWORD` | system app 真实密码 |
| `YGH_SYSTEM_DB_MIGRATION_USERNAME` | `ygh_system_migration` |
| `YGH_SYSTEM_DB_MIGRATION_PASSWORD` | system migration 真实密码 |
| `SPRING_FLYWAY_ENABLED` | `false` |
| `YGH_NACOS_SERVER_ADDR` | `192.168.154.10:8848` |
| `YGH_NACOS_USERNAME` | `nacos` |
| `YGH_NACOS_PASSWORD` | Nacos 真实密码 |
| `YGH_NACOS_NAMESPACE` | `ygh-dev` |
| `YGH_NACOS_DISCOVERY_GROUP` | `YGH_GROUP` |
| `YGH_SYSTEM_ADVERTISE_IP` | `192.168.154.1` |
| `SPRING_CLOUD_NACOS_DISCOVERY_IP` | `192.168.154.1` |
| `YGH_INTERNAL_REQUEST_HMAC_BASE64` | 第六步第 1 个值 |
| `YGH_SYSTEM_CONFIG_MASTER_KEY_BASE64` | 第六步第 4 个值 |

连接池保持 `YGH_SYSTEM_DB_POOL_MAX_SIZE=5`、`YGH_SYSTEM_DB_POOL_MIN_IDLE=1`。

运行后输入：

```powershell
Invoke-RestMethod 'http://127.0.0.1:8083/actuator/health'
```

**执行后的结果**：`status` 为 `UP`；Nacos 中 `ygh-system-service` 实例是 `192.168.154.1:8083`。

### 第十七步：配置并启动 Notification 服务

**在哪里操作**：IDEA。

创建配置：

```text
Name: YGH-03-Notification-8092
Main class: com.yuegang.zhihui.notification.NotificationApplication
Use classpath of module: ygh-notification-service
```

逐行填写：

| Name | Value |
|---|---|
| `YGH_NOTIFICATION_PORT` | `8092` |
| `YGH_NOTIFICATION_DB_URL` | `jdbc:mysql://192.168.154.10:3306/notification_db?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=Asia/Shanghai` |
| `YGH_NOTIFICATION_DB_APP_USERNAME` | `ygh_notification_app` |
| `YGH_NOTIFICATION_DB_APP_PASSWORD` | notification app 真实密码 |
| `YGH_NOTIFICATION_DB_MIGRATION_USERNAME` | `ygh_notification_migration` |
| `YGH_NOTIFICATION_DB_MIGRATION_PASSWORD` | notification migration 真实密码 |
| `YGH_NACOS_SERVER_ADDR` | `192.168.154.10:8848` |
| `YGH_NACOS_USERNAME` | `nacos` |
| `YGH_NACOS_PASSWORD` | Nacos 真实密码 |
| `YGH_NACOS_NAMESPACE` | `ygh-dev` |
| `YGH_NACOS_DISCOVERY_GROUP` | `YGH_GROUP` |
| `SPRING_CLOUD_NACOS_DISCOVERY_IP` | `192.168.154.1` |
| `YGH_INTERNAL_REQUEST_HMAC_BASE64` | 第六步第 1 个值 |
| `YGH_MQ_ENABLED` | `false` |

**配置说明**：第一次基础启动先填 `false`，不连接 RocketMQ。需要商城异步消息时再按 RocketMQ 文档确认容器和 Topic 后改成 `true`，并新增 `YGH_ROCKETMQ_NAMESERVER=127.0.0.1:19876`、`YGH_ROCKETMQ_TOPIC=YGH_DOMAIN_EVENTS`。

运行后输入：

```powershell
Invoke-RestMethod 'http://127.0.0.1:8092/actuator/health'
```

**执行后的结果**：首次启动由 `ygh_notification_migration` 创建表，随后服务监听 `8092`，健康状态为 `UP`。

### 第十八步：配置并启动 Auth 服务

**在哪里操作**：IDEA。

创建配置：

```text
Name: YGH-04-Auth-8081
Main class: com.yuegang.zhihui.auth.AuthApplication
Use classpath of module: ygh-auth-service
```

逐行填写：

| Name | Value |
|---|---|
| `YGH_AUTH_PORT` | `8081` |
| `YGH_AUTH_DB_URL` | `jdbc:mysql://192.168.154.10:3306/auth_db?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=Asia/Shanghai` |
| `YGH_AUTH_DB_APP_USERNAME` | `ygh_auth_app` |
| `YGH_AUTH_DB_APP_PASSWORD` | auth app 真实密码 |
| `YGH_AUTH_DB_MIGRATION_USERNAME` | `ygh_auth_migration` |
| `YGH_AUTH_DB_MIGRATION_PASSWORD` | auth migration 真实密码 |
| `SPRING_FLYWAY_ENABLED` | `false` |
| `YGH_REDIS_HOST` | `192.168.154.10` |
| `YGH_REDIS_PORT` | `6379` |
| `YGH_REDIS_PASSWORD` | Redis 真实密码 |
| `YGH_REDIS_ENVIRONMENT` | `dev` |
| `YGH_NACOS_SERVER_ADDR` | `192.168.154.10:8848` |
| `YGH_NACOS_USERNAME` | `nacos` |
| `YGH_NACOS_PASSWORD` | Nacos 真实密码 |
| `YGH_NACOS_NAMESPACE` | `ygh-dev` |
| `YGH_NACOS_DISCOVERY_GROUP` | `YGH_GROUP` |
| `YGH_AUTH_ADVERTISE_IP` | `192.168.154.1` |
| `SPRING_CLOUD_NACOS_DISCOVERY_IP` | `192.168.154.1` |
| `YGH_SYSTEM_INTERNAL_BASE_URL` | `http://127.0.0.1:8083` |
| `YGH_NOTIFICATION_INTERNAL_BASE_URL` | `http://127.0.0.1:8092` |
| `YGH_INTERNAL_REQUEST_HMAC_BASE64` | 第六步第 1 个值 |
| `YGH_AUTH_ID_WORKER` | `1` |
| `YGH_AUTH_AUDIT_PEPPER_BASE64` | 第六步第 2 个值 |
| `YGH_JWT_ENABLED` | `true` |
| `YGH_JWT_KEY_DIRECTORY` | `D:\ygh-secrets\jwt` |
| `YGH_JWT_ACTIVE_KID` | `auth-dev-2026` |
| `YGH_JWT_ISSUER` | `https://auth.dev.ygh.internal` |
| `YGH_JWT_AUDIENCE` | `ygh-api` |
| `YGH_JWT_ACCESS_TOKEN_MINUTES` | `15` |
| `YGH_JWT_REFRESH_TOKEN_DAYS` | `14` |

连接池和登录限流保持源码默认值：`YGH_AUTH_DB_POOL_MAX_SIZE=5`、`YGH_AUTH_DB_POOL_MIN_IDLE=1`、`YGH_AUTH_PRINCIPAL_LOGIN_LIMIT=10`、`YGH_AUTH_PRINCIPAL_LOGIN_WINDOW=15m`、`YGH_AUTH_IP_LOGIN_LIMIT=30`、`YGH_AUTH_IP_LOGIN_WINDOW=15m`。修改这些值属于容量或安全策略变更，必须记录原因。

运行后输入：

```powershell
Invoke-RestMethod 'http://127.0.0.1:8081/actuator/health'
Invoke-RestMethod 'http://127.0.0.1:8081/.well-known/jwks.json'
```

**执行后的结果**：健康状态为 `UP`；JWKS 返回 `keys` 数组且包含 `kid` 为 `auth-dev-2026` 的公钥。响应不会返回私钥。

### 第十九步：配置并启动 Gateway 服务

**在哪里操作**：IDEA。

创建配置：

```text
Name: YGH-05-Gateway-8080
Main class: com.yuegang.zhihui.gateway.GatewayApplication
Use classpath of module: ygh-gateway
```

逐行填写：

| Name | Value |
|---|---|
| `YGH_GATEWAY_PORT` | `8080` |
| `YGH_REDIS_HOST` | `192.168.154.10` |
| `YGH_REDIS_PORT` | `6379` |
| `YGH_REDIS_PASSWORD` | Redis 真实密码 |
| `YGH_REDIS_ENVIRONMENT` | `dev` |
| `YGH_NACOS_SERVER_ADDR` | `192.168.154.10:8848` |
| `YGH_NACOS_USERNAME` | `nacos` |
| `YGH_NACOS_PASSWORD` | Nacos 真实密码 |
| `YGH_NACOS_NAMESPACE` | `ygh-dev` |
| `YGH_NACOS_DISCOVERY_GROUP` | `YGH_GROUP` |
| `YGH_NACOS_DISCOVERY_ENABLED` | `true` |
| `YGH_SERVICE_IP` | `192.168.154.1` |
| `SPRING_CLOUD_NACOS_DISCOVERY_IP` | `192.168.154.1` |
| `YGH_GATEWAY_CORS_ALLOWED_ORIGINS` | `http://localhost:5173,http://127.0.0.1:5173,http://localhost:5174,http://127.0.0.1:5174` |
| `YGH_INTERNAL_REQUEST_SIGNATURE_ENABLED` | `true` |
| `YGH_INTERNAL_REQUEST_HMAC_BASE64` | 第六步第 1 个值 |
| `YGH_GATEWAY_SESSION_VALIDATION_ENABLED` | `true` |
| `YGH_JWT_ISSUER` | `https://auth.dev.ygh.internal` |
| `YGH_JWT_JWK_SET_URI` | `http://127.0.0.1:8081/.well-known/jwks.json` |
| `YGH_JWT_AUDIENCE` | `ygh-api` |

网关请求限制保持源码默认值：`YGH_GATEWAY_REQUEST_MAX_SIZE=2MB`、`YGH_GATEWAY_UPLOAD_MAX_SIZE=50MB`、`YGH_GATEWAY_UPLOAD_PATHS=/api/v1/knowledge/documents,/api/v1/training/documents,/api/v1/products/images`、`YGH_GATEWAY_AUTH_QPS=20`、`YGH_GATEWAY_AUTH_BURST=5`、`YGH_GATEWAY_SERVICE_QPS=100`、`YGH_GATEWAY_SERVICE_BURST=10`。客户修改上传大小时还要同步检查反向代理限制。

运行后输入：

```powershell
Invoke-RestMethod 'http://127.0.0.1:8080/actuator/health'
```

**执行后的结果**：返回 `UP`，Nacos 中出现 `ygh-gateway`。网关必须在 Auth JWKS 已可访问后启动，否则 JWT 初始化或请求校验可能失败。

### 第二十步：配置并启动 Inventory 服务

**在哪里操作**：IDEA。

创建配置：

```text
Name: YGH-06-Inventory-8085
Main class: com.yuegang.zhihui.inventory.InventoryApplication
Use classpath of module: ygh-inventory-service
```

逐行填写：

| Name | Value |
|---|---|
| `YGH_INVENTORY_PORT` | `8085` |
| `YGH_INVENTORY_DB_URL` | `jdbc:mysql://192.168.154.10:3306/inventory_db?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=Asia/Shanghai` |
| `YGH_INVENTORY_DB_APP_USERNAME` | `ygh_inventory_app` |
| `YGH_INVENTORY_DB_APP_PASSWORD` | inventory app 真实密码 |
| `YGH_INVENTORY_DB_MIGRATION_USERNAME` | `ygh_inventory_migration` |
| `YGH_INVENTORY_DB_MIGRATION_PASSWORD` | inventory migration 真实密码 |
| `YGH_NACOS_SERVER_ADDR` | `192.168.154.10:8848` |
| `YGH_NACOS_USERNAME` | `nacos` |
| `YGH_NACOS_PASSWORD` | Nacos 真实密码 |
| `YGH_NACOS_NAMESPACE` | `ygh-dev` |
| `YGH_NACOS_DISCOVERY_GROUP` | `YGH_GROUP` |
| `SPRING_CLOUD_NACOS_DISCOVERY_IP` | `192.168.154.1` |
| `YGH_INTERNAL_REQUEST_HMAC_BASE64` | 第六步第 1 个值 |

运行后输入：

```powershell
Invoke-RestMethod 'http://127.0.0.1:8085/actuator/health'
```

**执行后的结果**：Flyway 首次创建 inventory 表，随后健康状态为 `UP`。以后正常启动仍会先校验迁移记录，不会重复创建已有表。

### 第二十一步：配置并启动 Wallet 服务

**在哪里操作**：IDEA。

创建配置：

```text
Name: YGH-07-Wallet-8087
Main class: com.yuegang.zhihui.wallet.WalletApplication
Use classpath of module: ygh-wallet-service
```

逐行填写：

| Name | Value |
|---|---|
| `YGH_WALLET_PORT` | `8087` |
| `YGH_WALLET_DB_URL` | `jdbc:mysql://192.168.154.10:3306/wallet_db?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=Asia/Shanghai` |
| `YGH_WALLET_DB_APP_USERNAME` | `ygh_wallet_app` |
| `YGH_WALLET_DB_APP_PASSWORD` | wallet app 真实密码 |
| `YGH_WALLET_DB_MIGRATION_USERNAME` | `ygh_wallet_migration` |
| `YGH_WALLET_DB_MIGRATION_PASSWORD` | wallet migration 真实密码 |
| `YGH_NACOS_SERVER_ADDR` | `192.168.154.10:8848` |
| `YGH_NACOS_USERNAME` | `nacos` |
| `YGH_NACOS_PASSWORD` | Nacos 真实密码 |
| `YGH_NACOS_NAMESPACE` | `ygh-dev` |
| `YGH_NACOS_DISCOVERY_GROUP` | `YGH_GROUP` |
| `SPRING_CLOUD_NACOS_DISCOVERY_IP` | `192.168.154.1` |
| `YGH_INTERNAL_REQUEST_HMAC_BASE64` | 第六步第 1 个值 |
| `YGH_MQ_ENABLED` | `false` |

基础验证先关闭 MQ。商城异步场景改为：

```text
YGH_MQ_ENABLED=true
YGH_ROCKETMQ_NAMESERVER=127.0.0.1:19876
YGH_ROCKETMQ_DOMAIN_TOPIC=YGH_DOMAIN_EVENTS
```

运行后输入：

```powershell
Invoke-RestMethod 'http://127.0.0.1:8087/actuator/health'
```

**执行后的结果**：Flyway 完成 wallet 表迁移，健康状态为 `UP`。

### 第二十二步：配置并启动 Search 服务

**在哪里操作**：IDEA。启动前确认 System、PGVector 和 Elasticsearch 都已正常。

创建配置：

```text
Name: YGH-08-Search-8089
Main class: com.yuegang.zhihui.search.SearchApplication
Use classpath of module: ygh-search-service
```

逐行填写：

| Name | Value |
|---|---|
| `YGH_SEARCH_PORT` | `8089` |
| `YGH_VECTOR_DB_URL` | `jdbc:postgresql://192.168.154.10:5432/ygh_vector` |
| `YGH_VECTOR_DB_USERNAME` | `ygh_vector` |
| `YGH_VECTOR_DB_PASSWORD` | PGVector 文档设置的真实密码 |
| `YGH_ELASTICSEARCH_BASE_URL` | `http://127.0.0.1:19200` |
| `YGH_ELASTICSEARCH_USERNAME` | `elastic` |
| `YGH_ELASTICSEARCH_PASSWORD` | Elasticsearch 真实密码 |
| `YGH_SYSTEM_INTERNAL_BASE_URL` | `http://127.0.0.1:8083` |
| `YGH_SEARCH_INDEX_ALIAS` | `knowledge-active` |
| `YGH_PRODUCT_SEARCH_INDEX` | `product-active` |
| `YGH_NACOS_SERVER_ADDR` | `192.168.154.10:8848` |
| `YGH_NACOS_USERNAME` | `nacos` |
| `YGH_NACOS_PASSWORD` | Nacos 真实密码 |
| `YGH_NACOS_NAMESPACE` | `ygh-dev` |
| `YGH_NACOS_DISCOVERY_GROUP` | `YGH_GROUP` |
| `SPRING_CLOUD_NACOS_DISCOVERY_IP` | `192.168.154.1` |
| `YGH_INTERNAL_REQUEST_HMAC_BASE64` | 第六步第 1 个值 |

**配置原因**：Search 的 PostgreSQL 在虚拟机 Docker，Elasticsearch 在 Windows Docker Desktop，因此两个地址不同。`YGH_ELASTICSEARCH_USERNAME` 和 `YGH_ELASTICSEARCH_PASSWORD` 是 Java 代码直接读取的系统环境变量，缺少时会得到 Elasticsearch `401`。

运行后输入：

```powershell
Invoke-RestMethod 'http://127.0.0.1:8089/actuator/health'
```

**执行后的结果**：Search 对 `ygh_vector` 执行 Flyway，服务监听 `8089`，健康状态为 `UP`。

### 第二十三步：配置并启动 Product 服务

**在哪里操作**：IDEA。Search 与 Redis 必须先正常。

创建配置：

```text
Name: YGH-09-Product-8084
Main class: com.yuegang.zhihui.product.ProductApplication
Use classpath of module: ygh-product-service
```

逐行填写：

| Name | Value |
|---|---|
| `YGH_PRODUCT_PORT` | `8084` |
| `YGH_PRODUCT_DB_URL` | `jdbc:mysql://192.168.154.10:3306/product_db?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=Asia/Shanghai` |
| `YGH_PRODUCT_DB_APP_USERNAME` | `ygh_product_app` |
| `YGH_PRODUCT_DB_APP_PASSWORD` | product app 真实密码 |
| `YGH_PRODUCT_DB_MIGRATION_USERNAME` | `ygh_product_migration` |
| `YGH_PRODUCT_DB_MIGRATION_PASSWORD` | product migration 真实密码 |
| `YGH_REDIS_HOST` | `192.168.154.10` |
| `YGH_REDIS_PORT` | `6379` |
| `YGH_REDIS_PASSWORD` | Redis 真实密码 |
| `YGH_PRODUCT_REDIS_DATABASE` | `2` |
| `YGH_SEARCH_BASE_URL` | `http://127.0.0.1:8089` |
| `YGH_NACOS_SERVER_ADDR` | `192.168.154.10:8848` |
| `YGH_NACOS_USERNAME` | `nacos` |
| `YGH_NACOS_PASSWORD` | Nacos 真实密码 |
| `YGH_NACOS_NAMESPACE` | `ygh-dev` |
| `YGH_NACOS_DISCOVERY_GROUP` | `YGH_GROUP` |
| `SPRING_CLOUD_NACOS_DISCOVERY_IP` | `192.168.154.1` |
| `YGH_INTERNAL_REQUEST_HMAC_BASE64` | 第六步第 1 个值 |
| `YGH_MQ_ENABLED` | `false` |

**必须修改的默认值**：源码默认 Search 地址是 `127.0.0.1:18089`，但 IDEA 实际端口为 `8089`，所以必须显式填写 `YGH_SEARCH_BASE_URL=http://127.0.0.1:8089`。

商城异步场景再新增：

```text
YGH_MQ_ENABLED=true
YGH_ROCKETMQ_NAMESERVER=127.0.0.1:19876
YGH_ROCKETMQ_TOPIC=YGH_DOMAIN_EVENTS
```

运行后输入：

```powershell
Invoke-RestMethod 'http://127.0.0.1:8084/actuator/health'
```

**执行后的结果**：Flyway 完成 product 表迁移，Redis 使用逻辑库 2，健康状态为 `UP`。

### 第二十四步：配置并启动 Order 服务

**在哪里操作**：IDEA。Product、Inventory、Wallet 均须先为 `UP`。

创建配置：

```text
Name: YGH-10-Order-8086
Main class: com.yuegang.zhihui.order.OrderApplication
Use classpath of module: ygh-order-service
```

逐行填写：

| Name | Value |
|---|---|
| `YGH_ORDER_PORT` | `8086` |
| `YGH_ORDER_DB_URL` | `jdbc:mysql://192.168.154.10:3306/order_db?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=Asia/Shanghai` |
| `YGH_ORDER_DB_APP_USERNAME` | `ygh_order_app` |
| `YGH_ORDER_DB_APP_PASSWORD` | order app 真实密码 |
| `YGH_ORDER_DB_MIGRATION_USERNAME` | `ygh_order_migration` |
| `YGH_ORDER_DB_MIGRATION_PASSWORD` | order migration 真实密码 |
| `YGH_PRODUCT_INTERNAL_BASE_URL` | `http://127.0.0.1:8084` |
| `YGH_INVENTORY_INTERNAL_BASE_URL` | `http://127.0.0.1:8085` |
| `YGH_WALLET_INTERNAL_BASE_URL` | `http://127.0.0.1:8087` |
| `YGH_NACOS_SERVER_ADDR` | `192.168.154.10:8848` |
| `YGH_NACOS_USERNAME` | `nacos` |
| `YGH_NACOS_PASSWORD` | Nacos 真实密码 |
| `YGH_NACOS_NAMESPACE` | `ygh-dev` |
| `YGH_NACOS_DISCOVERY_GROUP` | `YGH_GROUP` |
| `SPRING_CLOUD_NACOS_DISCOVERY_IP` | `192.168.154.1` |
| `YGH_INTERNAL_REQUEST_HMAC_BASE64` | 第六步第 1 个值 |
| `YGH_MQ_ENABLED` | `false` |

商城异步场景改为：

```text
YGH_MQ_ENABLED=true
YGH_ROCKETMQ_NAMESERVER=127.0.0.1:19876
YGH_ROCKETMQ_DOMAIN_TOPIC=YGH_DOMAIN_EVENTS
```

运行后输入：

```powershell
Invoke-RestMethod 'http://127.0.0.1:8086/actuator/health'
```

**执行后的结果**：Flyway 完成 order 表迁移，健康状态为 `UP`。内部地址全部是 Windows IDEA 服务，因此使用 `127.0.0.1`，不能填写 Docker 服务名。

### 第二十五步：配置并启动 Knowledge 服务

**在哪里操作**：IDEA。Search 必须先为 `UP`，`D:\ygh-data\knowledge` 必须已存在。

创建配置：

```text
Name: YGH-11-Knowledge-8088
Main class: com.yuegang.zhihui.knowledge.KnowledgeApplication
Use classpath of module: ygh-knowledge-service
```

逐行填写：

| Name | Value |
|---|---|
| `YGH_KNOWLEDGE_PORT` | `8088` |
| `YGH_KNOWLEDGE_DB_URL` | `jdbc:mysql://192.168.154.10:3306/knowledge_db?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=Asia/Shanghai` |
| `YGH_KNOWLEDGE_DB_APP_USERNAME` | `ygh_knowledge_app` |
| `YGH_KNOWLEDGE_DB_APP_PASSWORD` | knowledge app 真实密码 |
| `YGH_KNOWLEDGE_DB_MIGRATION_USERNAME` | `ygh_knowledge_migration` |
| `YGH_KNOWLEDGE_DB_MIGRATION_PASSWORD` | knowledge migration 真实密码 |
| `YGH_KNOWLEDGE_STORAGE_ROOT` | `D:\ygh-data\knowledge` |
| `YGH_SEARCH_INTERNAL_BASE_URL` | `http://127.0.0.1:8089` |
| `YGH_NACOS_SERVER_ADDR` | `192.168.154.10:8848` |
| `YGH_NACOS_USERNAME` | `nacos` |
| `YGH_NACOS_PASSWORD` | Nacos 真实密码 |
| `YGH_NACOS_NAMESPACE` | `ygh-dev` |
| `YGH_NACOS_DISCOVERY_GROUP` | `YGH_GROUP` |
| `SPRING_CLOUD_NACOS_DISCOVERY_IP` | `192.168.154.1` |
| `YGH_INTERNAL_REQUEST_HMAC_BASE64` | 第六步第 1 个值 |
| `YGH_MQ_ENABLED` | `false` |

知识库异步索引场景需要 RocketMQ 时改为：

```text
YGH_MQ_ENABLED=true
YGH_ROCKETMQ_NAMESERVER=127.0.0.1:19876
YGH_ROCKETMQ_TOPIC=YGH_DOMAIN_EVENTS
```

运行后输入：

```powershell
Invoke-RestMethod 'http://127.0.0.1:8088/actuator/health'
```

**执行后的结果**：Flyway 完成 knowledge 表迁移，文件写入 Windows 的 `D:\ygh-data\knowledge`，健康状态为 `UP`。不要把存储目录改到虚拟机路径或容器路径。

### 第二十六步：配置并启动 AI 服务

**在哪里操作**：IDEA。System、Search、Product、Inventory、Order 必须先启动。

创建配置：

```text
Name: YGH-12-AI-8090
Main class: com.yuegang.zhihui.ai.AiApplication
Use classpath of module: ygh-ai-service
```

逐行填写：

| Name | Value |
|---|---|
| `YGH_AI_PORT` | `8090` |
| `YGH_AI_DB_URL` | `jdbc:mysql://192.168.154.10:3306/ai_db?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=Asia/Shanghai` |
| `YGH_AI_DB_APP_USERNAME` | `ygh_ai_app` |
| `YGH_AI_DB_APP_PASSWORD` | ai app 真实密码 |
| `YGH_AI_DB_MIGRATION_USERNAME` | `ygh_ai_migration` |
| `YGH_AI_DB_MIGRATION_PASSWORD` | ai migration 真实密码 |
| `YGH_SYSTEM_INTERNAL_BASE_URL` | `http://127.0.0.1:8083` |
| `YGH_SEARCH_INTERNAL_BASE_URL` | `http://127.0.0.1:8089` |
| `YGH_PRODUCT_INTERNAL_BASE_URL` | `http://127.0.0.1:8084` |
| `YGH_INVENTORY_INTERNAL_BASE_URL` | `http://127.0.0.1:8085` |
| `YGH_ORDER_INTERNAL_BASE_URL` | `http://127.0.0.1:8086` |
| `YGH_NACOS_SERVER_ADDR` | `192.168.154.10:8848` |
| `YGH_NACOS_USERNAME` | `nacos` |
| `YGH_NACOS_PASSWORD` | Nacos 真实密码 |
| `YGH_NACOS_NAMESPACE` | `ygh-dev` |
| `YGH_NACOS_DISCOVERY_GROUP` | `YGH_GROUP` |
| `SPRING_CLOUD_NACOS_DISCOVERY_IP` | `192.168.154.1` |
| `YGH_INTERNAL_REQUEST_HMAC_BASE64` | 第六步第 1 个值 |

**配置说明**：AI 供应商的 API Key 不写进 IDEA，也不写入源码或 `.env`。项目通过 System 服务维护加密后的 AI 供应商配置；System 的配置主密钥必须与第十六步一致。

运行后输入：

```powershell
Invoke-RestMethod 'http://127.0.0.1:8090/actuator/health'
```

**执行后的结果**：Flyway 完成 ai 表迁移，健康状态为 `UP`。健康为 `UP` 只表示服务和基础依赖可用，不代表尚未录入的外部 AI Key 已可调用。

### 第二十七步：停止 Seata，释放 Training 所需端口

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
docker ps --filter "name=ygh-seata" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

如果显示 Seata 正在占用 `8091`，输入：

```powershell
docker stop ygh-seata
```

再输入：

```powershell
Get-NetTCPConnection -LocalPort 8091 -State Listen -ErrorAction SilentlyContinue
```

**执行后的结果**：最后一条命令没有输出，表示 `8091` 已释放。

**注意事项**：这是当前低配置开发交付方案的已知端口冲突。Training 和 Seata 不能同时占用 Windows `8091`；当前 Java 服务尚未依赖 Seata，因此运行培训场景时停止 Seata。

### 第二十八步：配置并启动 Training 服务

**在哪里操作**：IDEA。User 必须为 `UP`，Seata 必须已停止。

创建配置：

```text
Name: YGH-13-Training-8091
Main class: com.yuegang.zhihui.training.TrainingApplication
Use classpath of module: ygh-training-service
```

逐行填写：

| Name | Value |
|---|---|
| `YGH_TRAINING_PORT` | `8091` |
| `YGH_TRAINING_DB_URL` | `jdbc:mysql://192.168.154.10:3306/training_db?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=Asia/Shanghai` |
| `YGH_TRAINING_DB_APP_USERNAME` | `ygh_training_app` |
| `YGH_TRAINING_DB_APP_PASSWORD` | training app 真实密码 |
| `YGH_TRAINING_DB_MIGRATION_USERNAME` | `ygh_training_migration` |
| `YGH_TRAINING_DB_MIGRATION_PASSWORD` | training migration 真实密码 |
| `YGH_TRAINING_STORAGE_ROOT` | `D:\ygh-data\training` |
| `YGH_USER_INTERNAL_BASE_URL` | `http://127.0.0.1:8082` |
| `YGH_NACOS_SERVER_ADDR` | `192.168.154.10:8848` |
| `YGH_NACOS_USERNAME` | `nacos` |
| `YGH_NACOS_PASSWORD` | Nacos 真实密码 |
| `YGH_NACOS_NAMESPACE` | `ygh-dev` |
| `YGH_NACOS_DISCOVERY_GROUP` | `YGH_GROUP` |
| `SPRING_CLOUD_NACOS_DISCOVERY_IP` | `192.168.154.1` |
| `YGH_INTERNAL_REQUEST_HMAC_BASE64` | 第六步第 1 个值 |
| `YGH_MQ_ENABLED` | `false` |

**必须修改的默认值**：源码默认 User 地址是 Docker 名称 `http://ygh-user-service:8082`，IDEA 无法解析该名称，所以必须显式填 `http://127.0.0.1:8082`。

需要培训异步消息时新增：

```text
YGH_MQ_ENABLED=true
YGH_ROCKETMQ_NAMESERVER=127.0.0.1:19876
YGH_ROCKETMQ_TOPIC=YGH_DOMAIN_EVENTS
```

运行后输入：

```powershell
Invoke-RestMethod 'http://127.0.0.1:8091/actuator/health'
```

**执行后的结果**：Flyway 完成 training 表迁移，健康状态为 `UP`，培训文件保存在 Windows `D:\ygh-data\training`。

### 第二十九步：配置并启动 Admin 服务

**在哪里操作**：IDEA。Admin 放在最后启动，因为它会主动检查其他服务健康状态。

创建配置：

```text
Name: YGH-14-Admin-8093
Main class: com.yuegang.zhihui.admin.AdminApplication
Use classpath of module: ygh-admin-service
```

逐行填写：

| Name | Value |
|---|---|
| `YGH_ADMIN_PORT` | `8093` |
| `YGH_ADMIN_SERVICE_HEALTH_URLS` | `gateway=http://127.0.0.1:8080/actuator/health,auth=http://127.0.0.1:8081/actuator/health,user=http://127.0.0.1:8082/actuator/health,system=http://127.0.0.1:8083/actuator/health,product=http://127.0.0.1:8084/actuator/health,inventory=http://127.0.0.1:8085/actuator/health,order=http://127.0.0.1:8086/actuator/health,wallet=http://127.0.0.1:8087/actuator/health,knowledge=http://127.0.0.1:8088/actuator/health,search=http://127.0.0.1:8089/actuator/health,ai=http://127.0.0.1:8090/actuator/health,training=http://127.0.0.1:8091/actuator/health,notification=http://127.0.0.1:8092/actuator/health` |
| `YGH_LOKI_BASE_URL` | `http://127.0.0.1:3100` |
| `YGH_NACOS_SERVER_ADDR` | `192.168.154.10:8848` |
| `YGH_NACOS_USERNAME` | `nacos` |
| `YGH_NACOS_PASSWORD` | Nacos 真实密码 |
| `YGH_NACOS_NAMESPACE` | `ygh-dev` |
| `YGH_NACOS_DISCOVERY_GROUP` | `YGH_GROUP` |
| `SPRING_CLOUD_NACOS_DISCOVERY_IP` | `192.168.154.1` |
| `YGH_INTERNAL_REQUEST_HMAC_BASE64` | 第六步第 1 个值 |

**配置说明**：`YGH_ADMIN_SERVICE_HEALTH_URLS` 使用英文逗号分隔，每项是 `服务名=完整健康地址`。当前未安装 Loki 时 Admin 仍可启动，但审计日志查询功能不可用，不要把这一点误报为完整可观测性已交付。

运行后输入：

```powershell
Invoke-RestMethod 'http://127.0.0.1:8093/actuator/health'
```

**执行后的结果**：Admin 健康状态为 `UP`，Nacos 出现 `ygh-admin-service`。

## 第六部分：按业务场景启动和停止

### 第三十步：基础认证场景启动顺序

**在哪里操作**：IDEA 顶部运行配置下拉框。

按顺序逐个选择并点击绿色三角：

```text
YGH-01-User-8082
YGH-02-System-8083
YGH-03-Notification-8092
YGH-04-Auth-8081
YGH-05-Gateway-8080
```

每启动一个，都在 PowerShell 检查对应 `/actuator/health`，确认 `UP` 再启动下一个。

### 第三十一步：商城场景启动顺序

**在哪里操作**：Windows Docker Desktop、IDEA。

1. 先按 RocketMQ 文档启动 NameServer 与 Broker，并确认 `YGH_DOMAIN_EVENTS` Topic。
2. 将 Product、Wallet、Order、Notification 的 `YGH_MQ_ENABLED` 改为 `true`，并填写各自小节列出的 MQ 变量。
3. 保持基础认证场景运行。
4. 依次启动 Inventory、Wallet、Search、Product、Order。
5. 最后重启 Notification，使其按 `true` 创建消费者。

**执行后的结果**：商城依赖服务均为 `UP`，RocketMQ `consumerProgress` 能看到当前代码实际创建的消费组。

### 第三十二步：知识库与 AI 场景启动顺序

**在哪里操作**：IDEA 和 Docker Desktop。

1. 保持 User、System、Auth、Gateway 运行。
2. 确认 PGVector 和 Elasticsearch 正常。
3. 启动 Search。
4. 启动 Knowledge。
5. AI 需要商城内部服务时，再启动 Product、Inventory、Order。
6. 最后启动 AI。

**执行后的结果**：Knowledge 对 Search 的地址是 `8089`；AI 的五个内部依赖均可访问。

### 第三十三步：培训场景启动顺序

**在哪里操作**：Windows PowerShell 和 IDEA。

1. 执行 `docker stop ygh-seata`。
2. 启动 User、System、Auth、Gateway。
3. 启动 Training。
4. 需要管理看板时最后启动 Admin。

**执行后的结果**：Training 独占 Windows `8091`，不会出现 `Port 8091 was already in use`。

### 第三十四步：在 IDEA 正确停止服务

**在哪里操作**：IDEA 底部 `Services` 或 `Run` 工具窗口。

1. 选中要停止的 Java 进程。
2. 点击红色方块 `Stop`。
3. 等待日志出现 Spring 上下文关闭信息和进程结束。
4. 不要直接结束 IDEA，不要在任务管理器批量结束全部 Java。
5. 停止顺序按启动顺序反向执行：先 Admin/AI/Training，再业务服务，最后 Gateway/Auth/System/User。

**执行后的结果**：端口释放，Nacos 临时实例在超时后下线。需要恢复 Seata 时，确认 Training 已停止，再输入 `docker start ygh-seata`。

## 第七部分：完整验收和故障定位

### 第三十五步：检查 14 个 Windows 端口

**在哪里操作**：Windows 本机 PowerShell。

全部服务运行时输入：

```powershell
Get-NetTCPConnection -State Listen |
  Where-Object {$_.LocalPort -in 8080,8081,8082,8083,8084,8085,8086,8087,8088,8089,8090,8091,8092,8093} |
  Sort-Object LocalPort |
  Select-Object LocalAddress,LocalPort,OwningProcess
```

**执行后的结果**：显示 14 个端口且各有进程。若缺少某个端口，回到对应 IDEA Run 窗口查看第一条 `Caused by`，不要只看最后一行。

### 第三十六步：逐个检查健康端点

**在哪里操作**：Windows 本机 PowerShell。以下命令逐条执行。

```powershell
0..13 | ForEach-Object {
  $port = 8080 + $_
  try { "$port $((Invoke-RestMethod "http://127.0.0.1:$port/actuator/health").status)" }
  catch { "$port FAILED $($_.Exception.Message)" }
}
```

**执行后的结果**：`8080` 至 `8093` 每行均为 `UP`。本命令只用于检查，不会启动、停止或修改任何服务。

### 第三十七步：检查 Nacos 注册地址

**在哪里操作**：Windows 浏览器。

1. 打开 `http://192.168.154.10:8848/nacos/`。
2. 使用 Nacos 账号登录。
3. 切换命名空间 `ygh-dev`。
4. 点击“服务管理”→“服务列表”。
5. 逐个点击服务详情。

**执行后的结果**：已启动服务位于 `YGH_GROUP`，实例 IP 为 `192.168.154.1`，端口与本文一致，健康状态为绿色。

**故障判断**：若实例 IP 是 `172.*`、WSL 地址、VPN 地址或 Wi-Fi 地址，停止该服务，在 IDEA 中补充或修正 `SPRING_CLOUD_NACOS_DISCOVERY_IP=192.168.154.1` 后重新启动。

### 第三十八步：处理最常见的启动错误

| 日志或现象 | 原因 | 处理方法 |
|---|---|---|
| `Could not resolve placeholder` | IDEA 漏填必填变量 | 对照当前服务表格逐行补齐，不要创建 `.env` |
| `Access denied for user` | MySQL 用户名、密码或授权错误 | 核对 app/migration 账号，执行 MySQL 文档中的 `SHOW GRANTS` |
| `Communications link failure` | 虚拟机 IP、3306 或网络错误 | 执行第二步 `Test-NetConnection` |
| Redis `NOAUTH` | Redis 密码错误或漏填 | 从密码管理器重填 `YGH_REDIS_PASSWORD` |
| Nacos `403` 或注册失败 | Nacos账号、命名空间或密码错误 | 登录 Nacos 控制台核对，不能改成匿名模式 |
| Elasticsearch `401` | Search 漏填 ES 用户名或密码 | 补齐 `YGH_ELASTICSEARCH_USERNAME/PASSWORD` |
| RocketMQ 连接 `9876` 失败 | 使用了容器内部默认端口 | IDEA 改为 `127.0.0.1:19876` |
| `Port 8091 was already in use` | Seata 与 Training 冲突 | 停止当前占用者；培训场景执行 `docker stop ygh-seata` |
| Gateway 返回 401 | Auth JWKS、issuer、audience 或 HMAC 不一致 | 先检查 JWKS，再逐字核对三个 JWT 值和公共 HMAC |
| 服务在 Nacos 但网关调用失败 | 注册了错误网卡 IP | 修正 Nacos discovery IP 并重启服务 |

### 第三十九步：保存交付验收记录

**在哪里操作**：客户交付记录，不是在源码仓库保存密码。

记录以下非敏感内容：

```text
虚拟机 IPv4：
Windows VMnet8 IPv4：
Oracle JDK 版本和供应商：
14 个服务的健康检查时间：
Nacos 命名空间和分组：
RocketMQ、Elasticsearch 是否启用：
Training 运行时 Seata 是否已停止：
```

密码、Base64 密钥、JWT 私钥和外部 API Key 只记录其密码管理器条目名称，不记录真实值。

**执行后的结果**：客户拿到的是可以复现的配置记录，同时不会在交付文档中泄露秘密。
