# Seata 2.5.0 Windows Docker Desktop 镜像手工安装与项目配置操作文档

## 第一部分：检查 Docker Desktop、Windows 地址和 8091 端口

### 第一步：确认 Docker Desktop 正在运行

**在哪里操作**：Windows 本机桌面和 PowerShell。

1. 双击桌面的 `Docker Desktop`。
2. 等待 Docker Engine 显示正在运行。
3. 打开新的 PowerShell，输入：

```powershell
docker version
docker info --format 'OSType={{.OSType}} Architecture={{.Architecture}} CPUs={{.NCPU}} Memory={{.MemTotal}}'
```

**执行后的结果**：Docker 同时显示 Client 和 Server，`OSType=linux`，架构为 `x86_64` 或 `amd64`。

**安装和运行位置**：Seata 不安装到 Rocky Linux 虚拟机、WSL2 或 Windows 软件目录。它最终以一个 Linux 容器运行在 Windows 本机 Docker Desktop 中。

### 第二步：确认 Docker Desktop 有足够资源

**在哪里操作**：Windows 本机 Docker Desktop 和 PowerShell。

1. 打开 Docker Desktop `Settings` → `Resources`。
2. Docker Desktop 总内存建议至少 3GB，CPU 至少 2 核。
3. 回到 PowerShell 输入：

```powershell
docker stats --no-stream
docker system df
```

**执行后的结果**：启动 Seata 前建议至少保留 700MB 可用内存和 2GB 可用磁盘。本项目给 Seata 容器分配 512MB 上限、0.50 CPU，JVM 堆固定为 256MB。

**注意事项**：RocketMQ、Seata 和 Elasticsearch 是 Windows Docker Desktop 的按需组件。低配置电脑不要同时常驻全部组件。

### 第三步：记录 Windows VMnet8 IPv4

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
Get-NetIPAddress -InterfaceAlias 'VMware Network Adapter VMnet8' -AddressFamily IPv4 | Select-Object InterfaceAlias,IPAddress,PrefixLength
```

没有输出时输入：

```powershell
ipconfig
```

在 `VMware Network Adapter VMnet8` 段落记录 IPv4。当前项目实测地址为：

```text
192.168.154.1
```

**执行后的结果**：得到 Windows 本机的 VMnet8 地址。Seata 生成的 XID 会包含这个地址；它不是 Rocky Linux 虚拟机地址 `192.168.154.10`。

**需要修改的内容**：客户 VMnet8 地址不同时，后文 `SEATA_IP=192.168.154.1` 和 VMnet8 端口测试地址替换为客户实际值。

### 第四步：检查 8091 是否空闲

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
Get-NetTCPConnection -State Listen -LocalPort 8091 -ErrorAction SilentlyContinue | Select-Object LocalAddress,LocalPort,OwningProcess
docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' | Select-String -Pattern 'seata|NAMES'
```

**执行后的结果**：全新部署时 8091 没有监听，不存在 `ygh-seata` 同名容器。

如果出现 `OwningProcess`，输入下面命令，把占位符替换为实际进程号：

```powershell
Get-Process -Id 进程号
```

查明进程用途后再处理，不能随意结束客户程序。

### 第五步：处理 Training 与 Seata 的 8091 冲突

**在哪里操作**：Windows 本机 IDEA 和 PowerShell。

本项目 `ygh-training-service` 默认也使用 Windows 8091。当前业务服务没有接入 Seata，因此本交付环境采用下面顺序：

1. 在 IDEA 停止 `ygh-training-service`。
2. 启动 Seata，完成本文兼容性测试。
3. 测试通过后停止 Seata。
4. 再在 IDEA 启动 Training。

**执行后的结果**：Seata 与 Training 不会争用同一个 Windows 端口。

**注意事项**：不要为了同时运行而随意改变 Seata TC 端口。项目兼容性测试固定使用 `127.0.0.1:8091`。将来业务服务真正接入 Seata 时，必须统一评审 Training 端口、Gateway 路由和所有客户端配置。

### 第六步：确认 8091 不在 Windows 保留端口范围

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
netsh interface ipv4 show excludedportrange protocol=tcp
```

**执行后的结果**：8091 不应落在任何 `Start Port` 到 `End Port` 范围内。如果被保留，先重启 Docker Desktop 和 Windows 后重新检查；不要直接改成其他端口并继续执行固定兼容性测试。

## 第二部分：手动拉取或载入 Seata 2.5.0 镜像

### 第一步：从官方页面确认镜像和 file 模式

**在哪里操作**：Windows 本机浏览器。

1. 打开 Apache Seata 官方 Docker 文档：`https://seata.apache.org/zh-cn/docs/ops/deploy-by-docker/`。
2. 确认 2.5.0 镜像为 `apache/seata-server:2.5.0`。
3. 确认 `SEATA_IP` 用于对外公布服务地址，`SEATA_PORT` 默认 8091，`STORE_MODE=file` 表示单机文件存储。
4. 确认 file 模式应持久化容器目录 `/seata-server/sessionStore`。
5. 打开 Docker Hub：`https://hub.docker.com/r/apache/seata-server/tags`，搜索 `2.5.0`。

**执行后的结果**：本项目下载对象是 Seata Docker 镜像，不下载源码包，不在 Windows 或虚拟机中单独安装 Seata Server 和 JDK。

### 第二步：拉取项目固定镜像

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
docker pull apache/seata-server:2.5.0
```

**执行后的结果**：最后显示 `Downloaded newer image` 或 `Image is up to date`，镜像名必须为 `apache/seata-server:2.5.0`。

不能改成 `latest` 或其他版本。项目兼容性测试依赖的客户端版本和服务端都固定为 2.5.0。

### 第三步：Docker Hub 拉取失败时检测代理

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
curl.exe -I --connect-timeout 10 https://docker.m.daocloud.io/v2/
curl.exe -I --connect-timeout 10 https://docker.1ms.run/v2/
```

**执行后的结果**：HTTP `200` 或 `401` 表示 Registry 可达；`403`、`429`、`5xx`、无法解析或超时表示当前方式不可用。

DaoCloud 可达时输入：

```powershell
docker pull docker.m.daocloud.io/apache/seata-server:2.5.0
docker tag docker.m.daocloud.io/apache/seata-server:2.5.0 apache/seata-server:2.5.0
```

1ms 可达时输入：

```powershell
docker pull docker.1ms.run/apache/seata-server:2.5.0
docker tag docker.1ms.run/apache/seata-server:2.5.0 apache/seata-server:2.5.0
```

两个代理只选择检测可达的一种，最终标签必须改回项目固定名称。

### 第四步：核对镜像架构和摘要

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
docker image inspect apache/seata-server:2.5.0 --format 'ARCH={{.Architecture}} OS={{.Os}} WORKDIR={{.Config.WorkingDir}} ENTRY={{json .Config.Entrypoint}} DIGESTS={{json .RepoDigests}}'
```

**执行后的结果**：架构为 `amd64`，系统为 `linux`，工作目录为 `/seata-server`，入口为 `/seata-server-entrypoint.sh`。

项目锁定摘要：

```text
多架构标签摘要：sha256:e66df08010eccd2b4b5e033b4a075a4e184dcb969efa003f2d0082a1c586d684
Linux amd64 平台摘要：sha256:9e5fa6c2b6e6c5a70a1d478a568def7e42d941d253e46f27e6601b37581d61c0
```

摘要或架构不一致时不要启动，先检查标签和镜像来源。

### 第五步：在联网电脑制作离线镜像包

**在哪里操作**：可以联网且已安装 Docker Desktop 的 Windows PowerShell。

输入：

```powershell
docker pull --platform linux/amd64 apache/seata-server:2.5.0
New-Item -ItemType Directory -Force 'D:\delivery-images'
docker save -o 'D:\delivery-images\apache-seata-server-2.5.0.tar' apache/seata-server:2.5.0
Get-FileHash 'D:\delivery-images\apache-seata-server-2.5.0.tar' -Algorithm SHA256
```

**执行后的结果**：出现镜像 tar 和文件 SHA256。记录校验值，不要解压 tar。

### 第六步：在客户 Windows 载入离线镜像

**在哪里操作**：客户 Windows 本机 PowerShell。

把交付介质中的 tar 放到 `D:\delivery-images`，输入：

```powershell
Get-FileHash 'D:\delivery-images\apache-seata-server-2.5.0.tar' -Algorithm SHA256
docker load -i 'D:\delivery-images\apache-seata-server-2.5.0.tar'
docker image inspect apache/seata-server:2.5.0 --format '{{json .RepoTags}} {{.Architecture}}'
```

**执行后的结果**：文件 SHA256 与制作端一致，镜像标签正确，架构为 amd64。在线拉取成功时跳过第五、六步。

## 第三部分：创建 Docker 网络、持久化卷和备份目录

### 第一步：确认 ygh-local 网络存在

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
docker network inspect ygh-local --format 'Name={{.Name}} Driver={{.Driver}}'
```

如果提示网络不存在，输入：

```powershell
docker network create ygh-local
```

再次执行检查。

**执行后的结果**：显示 `Name=ygh-local Driver=bridge`。这是 Windows Docker Desktop 中 RocketMQ、Seata 和 Elasticsearch 共用的项目网络。

### 第二步：创建 Seata 会话和日志卷

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
docker volume create ygh-seata-session
docker volume create ygh-seata-logs
docker volume inspect ygh-seata-session ygh-seata-logs
```

**执行后的结果**：创建两个 Docker 命名卷：

- `ygh-seata-session` 挂载到 `/seata-server/sessionStore`，保存 file 模式事务会话数据。
- `ygh-seata-logs` 挂载到 `/root/logs/seata`，保存服务日志、GC 日志和可能的堆转储。

**安装位置说明**：命名卷由 Docker Desktop 管理，不要在 Windows 资源管理器或 WSL 中直接修改 `/var/lib/docker/volumes`。迁移统一使用本文备份、恢复命令。

### 第三步：创建 Windows 备份目录

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
New-Item -ItemType Directory -Force 'D:\ygh-backups\seata'
Get-Item 'D:\ygh-backups\seata'
```

**执行后的结果**：备份目录存在。客户没有 D 盘时可以更换盘符，但后面的挂载和校验命令必须同步替换。

### 第四步：确认卷当前为空

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
docker run --rm --entrypoint bash -v ygh-seata-session:/data:ro apache/seata-server:2.5.0 -lc "find /data -mindepth 1 -maxdepth 2 -print"
docker run --rm --entrypoint bash -v ygh-seata-logs:/data:ro apache/seata-server:2.5.0 -lc "find /data -mindepth 1 -maxdepth 2 -print"
```

**执行后的结果**：全新卷不输出文件。

**注意事项**：这里必须写 `--entrypoint bash`。Seata 镜像有固定入口；不覆盖入口时，原本用于查看文件的辅助容器会误启动成另一个 Seata Server 并持续运行。

## 第四部分：逐项确认 Seata 的项目配置

### 第一步：确认存储模式使用 file

**在哪里操作**：Windows 本机项目文档和 PowerShell，不编辑项目源码。

本项目低配置环境固定使用：

```text
STORE_MODE=file
```

**执行后的结果**：Seata 不连接 MySQL、Redis 或 Nacos 来保存事务会话，数据写入 `ygh-seata-session` 对应的 `/seata-server/sessionStore`。

**需要修改的内容**：不要自行改成 `db`、`redis` 或 `raft`。这些模式需要额外表结构、连接配置或集群设计，当前项目没有提供对应交付契约。

### 第二步：确认服务地址和端口

**在哪里操作**：Windows 本机 PowerShell 和交付记录。

本项目参数为：

```text
SEATA_IP=192.168.154.1
SEATA_PORT=8091
```

**需要修改的内容**：只把 `SEATA_IP` 改成客户实际 VMnet8 IPv4；端口保持 8091。

**执行后的结果**：运行探针从 Windows 连接 `127.0.0.1:8091`，Seata 生成的 XID 中公布客户 VMnet8 IPv4 和 8091。

### 第三步：确认 JVM 和容器资源参数

**在哪里操作**：Windows 本机交付记录。

本项目固定参数：

```text
JVM_XMS=256m
JVM_XMX=256m
JVM_MetaspaceSize=96m
JVM_MaxMetaspaceSize=160m
JVM_MaxDirectMemorySize=128m
容器内存上限=512m
容器 CPU 上限=0.50
```

**执行后的结果**：JVM 堆不会自动使用镜像默认的 2GB，适合当前低配置 Docker Desktop。

**注意事项**：镜像内部自带自己的 Java 运行时；这里不使用 Windows 的 Oracle JDK。Windows Oracle JDK 25 只用于运行项目兼容性测试和后续 Java 服务。

### 第四步：确认不连接 Nacos

**在哪里操作**：Windows 本机项目源码和交付记录。

当前服务端配置使用：

```text
seata.config.type=file
seata.registry.type=file
```

**执行后的结果**：Seata Server 不注册到虚拟机 Nacos，也不需要 Nacos 用户名、密码、namespace 或 group。不要把 Nacos 配置照搬到 Seata。

### 第五步：确认 2.5.0 不使用旧 7091 控制台端口

**在哪里操作**：Windows 本机交付记录。

Seata 2.x 已移除旧的独立 Spring Boot Web 组件，HTTP 能力与事务服务端口合并。当前 `apache/seata-server:2.5.0` 实测监听 8091，项目运行测试也只访问 8091。

**执行后的结果**：手工启动命令只映射 8091，不把 `http://127.0.0.1:7091` 当成健康检查，也不要求客户登录旧控制台。

### 第六步：确认当前没有业务服务接入 Seata

**在哪里操作**：Windows 本机 IntelliJ IDEA 和项目源码。

当前项目实际情况：

- 14 个业务服务没有引入 `spring-cloud-starter-alibaba-seata`。
- 业务源码没有 `@GlobalTransactional`。
- `YGH_SEATA_HOST`、`YGH_SEATA_PORT` 和 `SEATA_PASSWORD` 不被业务服务读取。
- 商城交易链路使用本地事务、Outbox、RocketMQ 幂等消费和对账补偿。
- Seata 2.5.0 当前只由 `ygh-compatibility-tests` 中的运行探针验证。

**执行后的结果**：不要给 Order、Wallet、Inventory 等 IDEA 运行配置添加无效 Seata 变量，也不要声称业务订单已经使用 Seata 全局事务。

## 第五部分：手工启动并验证 Seata 容器

### 第一步：执行首次启动命令

**在哪里操作**：Windows 本机 PowerShell。确认 IDEA 中 Training 已停止。

输入完整命令，其中 VMnet8 地址不同时只修改 `SEATA_IP`：

```powershell
docker run -d `
  --name ygh-seata `
  --network ygh-local `
  --cpus="0.50" `
  --memory="512m" `
  -p 8091:8091 `
  -e "TZ=Asia/Shanghai" `
  -e "STORE_MODE=file" `
  -e "SEATA_IP=192.168.154.1" `
  -e "SEATA_PORT=8091" `
  -e "JVM_XMS=256m" `
  -e "JVM_XMX=256m" `
  -e "JVM_MetaspaceSize=96m" `
  -e "JVM_MaxMetaspaceSize=160m" `
  -e "JVM_MaxDirectMemorySize=128m" `
  -v ygh-seata-session:/seata-server/sessionStore `
  -v ygh-seata-logs:/root/logs/seata `
  --health-cmd="pgrep -f org.apache.seata.server.ServerApplication" `
  --health-interval=15s `
  --health-timeout=5s `
  --health-retries=20 `
  --health-start-period=60s `
  --stop-timeout=45 `
  --log-driver=json-file `
  --log-opt=max-size=10m `
  --log-opt=max-file=3 `
  --restart=unless-stopped `
  apache/seata-server:2.5.0
```

**执行后的结果**：Docker 输出容器 ID。所有参数都在当前命令中逐项填写，没有读取外部批量配置或启动文件。健康检查直接确认 Seata Java 主进程存在，不调用 Bash 脚本；后续仍必须通过日志和 8091 端口共同确认服务真正可用。

### 第二步：等待容器健康

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
docker logs --tail 200 ygh-seata
docker inspect ygh-seata --format 'Status={{.State.Status}} Health={{.State.Health.Status}} Restarts={{.RestartCount}}'
```

**执行后的结果**：日志依次出现：

```text
use lock store mode: file
use session store mode: file
Server started, service listen port: 8091
seata server started
```

最终显示 `Status=running Health=healthy Restarts=0`。

### 第三步：核对 JVM 参数和资源限制

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
docker logs ygh-seata 2>&1 | Select-String -Pattern 'Affected JVM parameters'
docker stats --no-stream ygh-seata
docker inspect ygh-seata --format 'Memory={{.HostConfig.Memory}} NanoCpus={{.HostConfig.NanoCpus}} Restart={{.HostConfig.RestartPolicy.Name}} Env={{json .Config.Env}}'
```

**执行后的结果**：日志包含 `-Xms256m`、`-Xmx256m`、Metaspace 96/160MB、DirectMemory 128MB；Memory 为 536870912；NanoCpus 为 500000000；Restart 为 `unless-stopped`。

### 第四步：核对持久化挂载

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
docker inspect ygh-seata --format '{{range .Mounts}}{{println .Name "->" .Destination "RW=" .RW}}{{end}}'
docker exec ygh-seata bash -lc "ls -ld /seata-server/sessionStore /root/logs/seata; find /root/logs/seata -maxdepth 2 -type f | head"
```

**执行后的结果**：`ygh-seata-session` 指向 `/seata-server/sessionStore`，`ygh-seata-logs` 指向 `/root/logs/seata`，均为可写；日志卷中出现 Seata 和 GC 日志。

### 第五步：从 Windows 验证 8091

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
Test-NetConnection 127.0.0.1 -Port 8091
Test-NetConnection 192.168.154.1 -Port 8091
```

**需要修改的内容**：第二条命令的地址替换为客户 VMnet8 IPv4。

**执行后的结果**：两次都显示 `TcpTestSucceeded : True`。第一条供本机兼容性测试使用，第二条证明对外公布的 VMnet8 地址可达。

### 第六步：只允许 Rocky Linux 虚拟机访问宿主机 TC

**在哪里操作**：管理员身份运行的 Windows PowerShell。只有将来需要从虚拟机连接 Seata 时执行。

当前虚拟机地址为 `192.168.154.10` 时输入：

```powershell
New-NetFirewallRule `
  -DisplayName 'YGH Seata TC 8091 from Rocky VM' `
  -Direction Inbound `
  -Action Allow `
  -Protocol TCP `
  -LocalPort 8091 `
  -RemoteAddress 192.168.154.10 `
  -Profile Any
Get-NetFirewallRule -DisplayName 'YGH Seata TC 8091 from Rocky VM' | Get-NetFirewallPortFilter
```

**需要修改的内容**：虚拟机 IP 不同时，只替换 `RemoteAddress`。不能填写 `Any` 或公网网段。

**执行后的结果**：Windows 防火墙只允许指定 Rocky Linux 虚拟机访问 8091。当前兼容性测试只在 Windows 本机运行时，可以不添加该规则。

## 第六部分：用 IDEA 运行项目真实 Seata 兼容性测试

### 第一步：确认 Windows 项目使用 Oracle JDK 25

**在哪里操作**：Windows 本机 IntelliJ IDEA。

1. 点击 `File` → `Project Structure...`。
2. 打开 `Project`。
3. `SDK` 选择已经安装的 Oracle JDK 25。
4. `Language level` 选择项目默认或 Java 25。
5. 点击 `Apply` → `OK`。

**执行后的结果**：IDEA 项目和后面的 JUnit 配置使用 Oracle JDK 25。Seata 容器仍使用镜像内部 Java，两者不要混淆。

### 第二步：打开兼容性测试源码

**在哪里操作**：Windows 本机 IntelliJ IDEA。

在 Project 面板依次展开：

```text
ygh-tests
  ygh-compatibility-tests
    src/test/java
      com.yuegang.zhihui.compatibility
        SeataRuntimeCompatibilityTest
```

**执行后的结果**：看到测试方法 `beginsAndCommitsARealGlobalTransactionOnJdk25`。该测试使用 `ygh_runtime_tx_group`，直接调用真实 TC 完成 begin、status、commit。

### 第三步：创建 JUnit 运行配置

**在哪里操作**：Windows 本机 IntelliJ IDEA。

1. 点击 `Run` → `Edit Configurations...`。
2. 点击左上角 `+` → `JUnit`。
3. `Name` 填写 `Seata 2.5 Runtime Compatibility`。
4. `Test kind` 选择 `Class`。
5. `Class` 选择 `com.yuegang.zhihui.compatibility.SeataRuntimeCompatibilityTest`。
6. `Use classpath of module` 选择 `ygh-compatibility-tests`。
7. `JRE` 选择 Oracle JDK 25。
8. 打开 `Environment variables`。

**执行后的结果**：JUnit 配置指向唯一的 Seata 运行测试，还没有执行。

### 第四步：填写测试的两个环境变量

**在哪里操作**：Windows 本机 IDEA 的 JUnit 运行配置。

逐项填写：

```text
YGH_SEATA_RUNTIME_TEST=true
YGH_SEATA_SERVER=127.0.0.1:8091
```

点击 `OK` 保存。

**执行后的结果**：第一个变量使测试不再被跳过，第二个变量指向 Windows Docker Desktop 的 Seata TC。

**注意事项**：不要填写 `YGH_SEATA_HOST`、`YGH_SEATA_PORT` 或 `SEATA_PASSWORD`；当前测试源码不读取这些变量。

### 第五步：运行兼容性测试

**在哪里操作**：Windows 本机 IntelliJ IDEA。

1. 确认 `docker inspect ygh-seata` 显示 healthy。
2. 在 IDEA 顶部选择 `Seata 2.5 Runtime Compatibility`。
3. 点击绿色三角形。
4. 等待 JUnit 完成，不要中途停止 Seata。

**执行后的结果**：IDEA 显示：

```text
Tests run: 1
Failures: 0
Errors: 0
Skipped: 0
```

失败或 Skipped 都不能算通过。

### 第六步：从 Seata 日志验证真实事务

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
docker logs --since 10m ygh-seata 2>&1 |
  Select-String -Pattern 'TM register success|Begin new global transaction|GlobalCommitResponse|Committing global transaction'
```

**执行后的结果**：必须同时看到：

- 客户端版本 2.5.0 的 `TM register success`。
- 应用名 `ygh-seata-runtime-probe`。
- 事务组 `ygh_runtime_tx_group`。
- `Begin new global transaction`。
- `GlobalCommitResponse` 的状态为 `Committed`。

这才证明 JDK 25 客户端与真实 Seata 2.5.0 协议可用，单纯 `TcpTestSucceeded=True` 不能代替该测试。

### 第七步：测试完成后停止 Seata 并释放 8091

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
docker stop -t 45 ygh-seata
docker ps -a --filter name=ygh-seata --format 'table {{.Names}}\t{{.Status}}'
Get-NetTCPConnection -State Listen -LocalPort 8091 -ErrorAction SilentlyContinue
```

**执行后的结果**：容器为 Exited，8091 不再监听。此后可以在 IDEA 启动 `ygh-training-service`。

## 第七部分：再次启动、备份和恢复

### 第一步：再次启动 Seata

**在哪里操作**：Windows 本机 PowerShell。先停止占用 8091 的 Training。

输入：

```powershell
docker start ygh-seata
docker inspect ygh-seata --format 'Status={{.State.Status}} Health={{.State.Health.Status}}'
```

等待 Health 变成 healthy，再运行兼容性测试。

**执行后的结果**：Seata 使用原命名卷再次启动，日志和 file 会话目录仍保留。

### 第二步：停止后备份会话和日志卷

**在哪里操作**：Windows 本机 PowerShell。

先停止 JUnit 测试并执行 `docker stop -t 45 ygh-seata`。然后查看当前时间：

```powershell
Get-Date -Format 'yyyyMMdd-HHmmss'
```

假设显示 `20260715-143000`，把下面命令中的示例时间手工改成实际值，再输入完整命令：

```powershell
docker run --rm --entrypoint tar `
  -v ygh-seata-session:/source/session:ro `
  -v ygh-seata-logs:/source/logs:ro `
  -v "D:\ygh-backups\seata:/backup" `
  apache/seata-server:2.5.0 `
  czf /backup/seata-20260715-143000.tar.gz -C /source session logs
```

返回 PowerShell 提示符后逐条输入：

```powershell
Get-FileHash 'D:\ygh-backups\seata\seata-20260715-143000.tar.gz' -Algorithm SHA256
Get-Item 'D:\ygh-backups\seata\seata-20260715-143000.tar.gz' | Select-Object FullName,Length
```

**执行后的结果**：生成大于 0 字节的压缩包并输出 SHA256。

**注意事项**：必须有 `--entrypoint tar`。没有它时辅助容器会执行 Seata 固定入口并持续运行，而不是执行备份命令。不要照抄示例时间，以免覆盖同名文件。

### 第三步：恢复到新的验证卷

**在哪里操作**：Windows 本机 PowerShell。下面以 `seata-20260714-120000.tar.gz` 为例，替换为实际文件名。

输入：

```powershell
Get-FileHash 'D:\ygh-backups\seata\seata-20260714-120000.tar.gz' -Algorithm SHA256
docker volume create ygh-seata-session-restore
docker volume create ygh-seata-logs-restore
docker run --rm --entrypoint tar `
  -v ygh-seata-session-restore:/restore/session `
  -v ygh-seata-logs-restore:/restore/logs `
  -v "D:\ygh-backups\seata:/backup:ro" `
  apache/seata-server:2.5.0 `
  xzf /backup/seata-20260714-120000.tar.gz -C /restore
docker run --rm --entrypoint find -v ygh-seata-session-restore:/data:ro apache/seata-server:2.5.0 /data -maxdepth 2 -type f -printf '%p %s bytes\n'
```

**执行后的结果**：新验证卷中出现会话文件；原 `ygh-seata-session` 和 `ygh-seata-logs` 没有被覆盖。

### 第四步：确认后使用恢复卷重建容器

**在哪里操作**：Windows 本机 PowerShell。该步骤只在确认恢复点、当前 Seata 已停止并保留原卷后执行。

1. 删除已停止的容器，不删除卷：

```powershell
docker rm ygh-seata
```

2. 重新执行第五部分第一步完整命令，但把两个挂载改为：

```text
-v ygh-seata-session-restore:/seata-server/sessionStore
-v ygh-seata-logs-restore:/root/logs/seata
```

3. 等待 healthy，重新运行 IDEA 兼容性测试。

**执行后的结果**：新容器使用恢复卷；原卷仍可回退。`docker rm` 命令不能增加 `-v`，否则可能删除容器关联的匿名卷。

## 第八部分：常见错误逐项排查

### 1. `port is already allocated` 或 8091 被占用

**在哪里排查**：Windows PowerShell 和 IDEA。

执行第一部分第四步。如果是 `ygh-training-service`，先在 IDEA 停止 Training；如果是旧 Seata 容器，检查后使用 `docker start`，不要重复创建。不能同时让 Training 与 Seata 占用 Windows 8091。

### 2. 容器一直 starting 或 unhealthy

**在哪里排查**：Windows 本机 PowerShell。

输入：

```powershell
docker logs --tail 300 ygh-seata
docker inspect ygh-seata --format 'Status={{.State.Status}} Health={{json .State.Health}} OOM={{.State.OOMKilled}} Exit={{.State.ExitCode}}'
```

先找第一条启动错误。端口健康检查只在日志出现 `Server started, service listen port: 8091` 后才会成功。

### 3. JUnit 显示 Skipped

**在哪里排查**：IDEA JUnit 运行配置。

确认环境变量名称完全是 `YGH_SEATA_RUNTIME_TEST`，值完全是小写 `true`。未设置时源码会主动跳过测试，Skipped 不是成功验证。

### 4. `can not connect to services-server`

**在哪里排查**：Windows PowerShell 和 IDEA。

确认 Seata healthy、`Test-NetConnection 127.0.0.1 -Port 8091` 成功、IDEA 中 `YGH_SEATA_SERVER=127.0.0.1:8091`。不要把测试地址填成容器名、虚拟机 IP 或 7091。

### 5. XID 中出现错误 IP

**在哪里排查**：Seata 日志和容器环境变量。

输入：

```powershell
docker inspect ygh-seata --format '{{range .Config.Env}}{{println .}}{{end}}' | Select-String 'SEATA_IP|SEATA_PORT'
```

如果 `SEATA_IP` 不是当前 Windows VMnet8 IPv4，需要停止并删除容器，使用正确地址重新执行完整 `docker run`。Docker 容器环境变量不能通过 `docker start` 修改。

### 6. 访问 7091 没有控制台

**在哪里排查**：本文第四部分第五步。

当前固定版本是 Seata 2.5.0，独立 Web 端口已合并，不把 7091 当作当前服务入口。健康、协议和事务验证全部使用 8091。

### 7. sessionStore 重启后丢失

**在哪里排查**：Windows PowerShell。

输入：

```powershell
docker inspect ygh-seata --format '{{json .Mounts}}'
```

必须看到 `ygh-seata-session` 挂载到 `/seata-server/sessionStore`。没有挂载时先停止兼容性测试，备份现有容器目录，再重建容器；不能直接删除旧容器后声称数据已保存。

### 8. 辅助检查容器一直不退出

**在哪里排查**：Windows PowerShell。

输入：

```powershell
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Command}}'
```

如果本来只想查看卷，却出现新的 Seata 进程，说明命令漏了 `--entrypoint bash`。确认该容器不是正式 `ygh-seata` 后停止并删除它，再使用本文完整检查命令。

### 9. 误以为业务服务已经接入 Seata

**在哪里排查**：项目 `pom.xml`、业务源码和 `docs/development/Seata使用边界与运行验证.md`。

当前只完成服务端部署和真实客户端兼容性探针。商城主链路仍使用本地事务、Outbox、RocketMQ 幂等和补偿。没有 starter、事务组配置、undo_log 表、数据源代理及 `@GlobalTransactional` 时，不能对客户宣称业务已使用 Seata。

### 10. file 模式是否可用于生产

**在哪里确认**：项目交付评审。

当前 file 模式是单节点开发和验收配置，适合短兼容性测试，不是生产高可用方案。正式生产若确需 Seata，必须另行设计注册中心、共享 DB 或 Raft 存储、多个 TC 节点、认证、监控、备份恢复和容量测试，不能把本文单机配置直接描述为生产集群。
