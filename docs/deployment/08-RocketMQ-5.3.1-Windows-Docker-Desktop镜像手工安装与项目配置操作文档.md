# RocketMQ 5.3.1 Windows Docker Desktop 镜像手工安装与项目配置操作文档

## 第一部分：检查 Windows Docker Desktop、地址和端口

### 第一步：确认 Docker Desktop 已启动

**在哪里操作**：Windows 本机桌面和 PowerShell。

1. 双击桌面的 `Docker Desktop`。
2. 等待左下角显示 Engine 正在运行。
3. 打开新的 PowerShell，输入：

```powershell
docker version
docker info --format 'OSType={{.OSType}} Architecture={{.Architecture}} CPUs={{.NCPU}} Memory={{.MemTotal}}'
```

**执行后的结果**：`docker version` 同时显示 Client 和 Server；`OSType=linux`，架构为 `x86_64` 或 `amd64`。

**安装和运行位置**：RocketMQ 不安装到 Rocky Linux 虚拟机、WSL2 或 Windows 程序目录。它最终分成 NameServer 和 Broker 两个 Linux 容器，运行在 Windows 本机 Docker Desktop 中。

如果提示无法连接 Docker Engine，先在 Docker Desktop 的 `Settings` → `General` 中确认使用 WSL 2 engine，点击 `Apply & restart`，等待 Engine 恢复后再继续。

### 第二步：确认 Docker Desktop 可用资源

**在哪里操作**：Windows 本机 Docker Desktop 和 PowerShell。

1. 打开 Docker Desktop `Settings` → `Resources`。
2. 如果页面允许直接调整资源，内存建议至少 3GB、CPU 至少 2 核。
3. 如果页面提示资源由 WSL 统一管理，不需要在此修改，回到 PowerShell 输入：

```powershell
docker system df
docker stats --no-stream
```

**执行后的结果**：Docker Desktop 有足够空间保存约 200MB 的 RocketMQ 镜像和持续增长的消息数据；启动前至少预留 1.5GB 可用内存。NameServer 限制为 256MB，Broker 限制为 768MB。

**注意事项**：本项目是低配置交付环境，RocketMQ、Seata 与 Elasticsearch 按业务场景启动。不要在内存不足时把全部组件和全部 Java 服务同时常驻。

### 第三步：记录 Windows 的 VMnet8 IPv4

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
Get-NetIPAddress -InterfaceAlias 'VMware Network Adapter VMnet8' -AddressFamily IPv4 | Select-Object InterfaceAlias,IPAddress,PrefixLength
```

如果没有输出，再输入：

```powershell
ipconfig
```

在 `VMware Network Adapter VMnet8` 段落记录 IPv4。当前项目实测地址为：

```text
192.168.154.1
```

**执行后的结果**：得到一个 Windows 本机地址，后面写入 Broker 的 `brokerIP1`。这个地址不是虚拟机地址 `192.168.154.10`。

**需要修改的内容**：客户 VMnet8 地址不同时，后文所有 `brokerIP1=192.168.154.1` 和 Broker 端口测试地址都替换为客户实际 VMnet8 IPv4。IDEA 的 NameServer 地址仍使用 `127.0.0.1:19876`。

### 第四步：检查项目端口是否被程序占用

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
Get-NetTCPConnection -State Listen -LocalPort 19876 -ErrorAction SilentlyContinue | Select-Object LocalAddress,LocalPort,OwningProcess
Get-NetTCPConnection -State Listen -LocalPort 10909 -ErrorAction SilentlyContinue | Select-Object LocalAddress,LocalPort,OwningProcess
Get-NetTCPConnection -State Listen -LocalPort 10911 -ErrorAction SilentlyContinue | Select-Object LocalAddress,LocalPort,OwningProcess
Get-NetTCPConnection -State Listen -LocalPort 10912 -ErrorAction SilentlyContinue | Select-Object LocalAddress,LocalPort,OwningProcess
Get-NetTCPConnection -State Listen -LocalPort 20909 -ErrorAction SilentlyContinue | Select-Object LocalAddress,LocalPort,OwningProcess
Get-NetTCPConnection -State Listen -LocalPort 20911 -ErrorAction SilentlyContinue | Select-Object LocalAddress,LocalPort,OwningProcess
Get-NetTCPConnection -State Listen -LocalPort 20912 -ErrorAction SilentlyContinue | Select-Object LocalAddress,LocalPort,OwningProcess
docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
```

**执行后的结果**：全新部署时这些端口没有监听；不存在 `ygh-rocketmq-namesrv` 和 `ygh-rocketmq-broker` 同名容器。

如果有端口占用，输入下面命令查询进程，其中 `进程号` 替换为 `OwningProcess`：

```powershell
Get-Process -Id 进程号
```

先确认占用者用途。不能为了继续安装而随意结束数据库、IDEA、Docker 或客户业务进程。

### 第五步：检查 Windows 系统保留端口并选择 Broker 端口组

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
netsh interface ipv4 show excludedportrange protocol=tcp
```

查看每一行的 `Start Port` 和 `End Port`：

- 如果 `10909`、`10911`、`10912` 都不在任何范围内，选择项目默认端口组 A：`10909/10911/10912`。
- 如果其中任意端口落在保留范围内，再确认 `20909`、`20911`、`20912` 不在保留范围，选择端口组 B：`20909/20911/20912`。

**执行后的结果**：在纸面或交付记录中明确写下 `选择 A` 或 `选择 B`，后面只能执行对应的一组配置和命令，不能混用。

**原因**：Docker 映射 Windows 保留端口时会报 `ports are not available` 或 `An attempt was made to access a socket in a way forbidden by its access permissions`。本项目 Java 客户端从 NameServer 获取 Broker 的真实地址，因此备用方案必须同时修改 Broker 监听端口和 Docker 映射，不能只改冒号左边的 Windows 端口。

## 第二部分：手动拉取或载入 RocketMQ 5.3.1 镜像

### 第一步：从官方页面确认版本和运行命令

**在哪里操作**：Windows 本机浏览器。

1. 打开 Apache RocketMQ 官方 Docker 教程：`https://rocketmq.apache.org/zh/docs/quickStart/02quickstartWithDocker/`。
2. 确认官方部署由 NameServer 和 Broker 组成，容器中使用 `sh mqnamesrv` 与 `sh mqbroker` 启动。
3. 打开 Docker Hub：`https://hub.docker.com/r/apache/rocketmq/tags`。
4. 搜索标签 `5.3.1`，确认镜像全名是 `apache/rocketmq:5.3.1`。

**执行后的结果**：确认下载对象是 Docker 镜像，不下载 RocketMQ 源码 ZIP，不在 Windows 或虚拟机中另装 JDK 来运行 RocketMQ。

### 第二步：拉取固定版本镜像

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
docker pull apache/rocketmq:5.3.1
```

**执行后的结果**：最后显示 `Downloaded newer image` 或 `Image is up to date`，镜像名为 `apache/rocketmq:5.3.1`。

不能改成 `latest`、5.3.2 或其他版本。本项目服务端镜像和 Java 客户端依赖都固定为 5.3.1。

### 第三步：Docker Hub 拉取失败时检测可用代理

**在哪里操作**：Windows 本机 PowerShell。

先逐个检测：

```powershell
curl.exe -I --connect-timeout 10 https://docker.m.daocloud.io/v2/
curl.exe -I --connect-timeout 10 https://docker.1ms.run/v2/
```

**执行后的结果**：返回 HTTP `200` 或 `401` 代表 Registry 可达；`403`、`429`、`5xx`、无法解析或超时代表当前不可用。

DaoCloud 可达时输入：

```powershell
docker pull docker.m.daocloud.io/apache/rocketmq:5.3.1
docker tag docker.m.daocloud.io/apache/rocketmq:5.3.1 apache/rocketmq:5.3.1
```

1ms 可达时输入：

```powershell
docker pull docker.1ms.run/apache/rocketmq:5.3.1
docker tag docker.1ms.run/apache/rocketmq:5.3.1 apache/rocketmq:5.3.1
```

只选择检测可达的一种。镜像代理只是传输入口，最终必须打回项目固定标签。

### 第四步：核对镜像架构、版本和摘要

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
docker image inspect apache/rocketmq:5.3.1 --format 'ARCH={{.Architecture}} OS={{.Os}} USER={{.Config.User}} WORKDIR={{.Config.WorkingDir}} DIGESTS={{json .RepoDigests}}'
```

**执行后的结果**：架构为 `amd64`，系统为 `linux`，用户为 `rocketmq`，工作目录为 `/home/rocketmq/rocketmq-5.3.1/bin`。

项目锁定摘要：

```text
多架构标签摘要：sha256:d2b231c1b9204129e4f4dd65ec1521c81b8d6826e5f1fe8daa521dab0db5bf16
Linux amd64 平台摘要：sha256:6ad88a43aece60f4974238fa6ac7be50e6a7347d6ac223f4182534ff12b67a91
```

摘要或架构不一致时不要启动，先检查标签和镜像来源。

### 第五步：在联网电脑制作离线镜像包

**在哪里操作**：可联网且已安装 Docker Desktop 的 Windows PowerShell。

输入：

```powershell
docker pull --platform linux/amd64 apache/rocketmq:5.3.1
New-Item -ItemType Directory -Force 'D:\delivery-images'
docker save -o 'D:\delivery-images\apache-rocketmq-5.3.1.tar' apache/rocketmq:5.3.1
Get-FileHash 'D:\delivery-images\apache-rocketmq-5.3.1.tar' -Algorithm SHA256
```

**执行后的结果**：出现镜像 tar 文件和文件 SHA256。记录校验值，将 tar 随项目交付介质提供，不要解压 tar。

### 第六步：在客户 Windows 载入离线镜像

**在哪里操作**：客户 Windows 本机 PowerShell。

将交付介质中的 tar 放到 `D:\delivery-images`，输入：

```powershell
Get-FileHash 'D:\delivery-images\apache-rocketmq-5.3.1.tar' -Algorithm SHA256
docker load -i 'D:\delivery-images\apache-rocketmq-5.3.1.tar'
docker image inspect apache/rocketmq:5.3.1 --format '{{json .RepoTags}} {{.Architecture}}'
```

**执行后的结果**：文件 SHA256 与制作端记录一致；`docker load` 显示正确标签；架构为 amd64。在线拉取已成功时跳过第五、六步。

## 第三部分：手工创建 Windows 配置目录、Docker 网络和数据卷

### 第一步：创建 RocketMQ 配置和备份目录

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
New-Item -ItemType Directory -Force 'D:\ygh-deploy\rocketmq\conf'
New-Item -ItemType Directory -Force 'D:\ygh-backups\rocketmq'
Get-Item 'D:\ygh-deploy\rocketmq\conf','D:\ygh-backups\rocketmq'
```

**执行后的结果**：

- `D:\ygh-deploy\rocketmq\conf` 保存手工编辑的 Broker 配置。
- `D:\ygh-backups\rocketmq` 保存数据卷备份。

客户没有 D 盘时，可以改成有足够空间的盘符，但后文配置文件挂载和备份命令必须同步替换盘符。

### 第二步：打开空白 broker.conf

**在哪里操作**：Windows 本机 PowerShell 和记事本。

输入：

```powershell
notepad 'D:\ygh-deploy\rocketmq\conf\broker.conf'
```

记事本询问是否创建新文件时点击 `是`。暂时不要保存，先根据第一部分第五步选择下面唯一一套内容。

### 第三步-A：端口组 A 未被保留时填写默认配置

**在哪里操作**：Windows 本机记事本。只有明确选择端口组 A 时执行。

输入以下全部内容：

```properties
brokerClusterName=YghDevCluster
brokerName=broker-a
brokerId=0
brokerIP1=192.168.154.1
listenPort=10911
deleteWhen=04
fileReservedTime=24
brokerRole=ASYNC_MASTER
flushDiskType=ASYNC_FLUSH
autoCreateTopicEnable=true
autoCreateSubscriptionGroup=true
storePathRootDir=/home/rocketmq/store
```

**需要修改的内容**：只把 `brokerIP1` 改为第一部分第三步查到的客户 VMnet8 IPv4。其他名称、端口和参数保持不变。

### 第三步-B：109xx 被保留时填写备用配置

**在哪里操作**：Windows 本机记事本。只有明确选择端口组 B 时执行。

输入以下全部内容：

```properties
brokerClusterName=YghDevCluster
brokerName=broker-a
brokerId=0
brokerIP1=192.168.154.1
listenPort=20911
deleteWhen=04
fileReservedTime=24
brokerRole=ASYNC_MASTER
flushDiskType=ASYNC_FLUSH
autoCreateTopicEnable=true
autoCreateSubscriptionGroup=true
storePathRootDir=/home/rocketmq/store
```

**需要修改的内容**：只把 `brokerIP1` 改为客户 VMnet8 IPv4。备用监听端口固定为 20911，对应客户端 VIP 端口 20909 和主从同步端口 20912。

### 第四步：保存并核对 broker.conf

**在哪里操作**：Windows 本机记事本和 PowerShell。

1. 在记事本点击 `文件` → `另存为`。
2. 文件名确认是 `broker.conf`，不是 `broker.conf.txt`。
3. `保存类型` 选择 `所有文件`。
4. 编码选择 `UTF-8`，点击 `保存`。
5. 回到 PowerShell 输入：

```powershell
Get-Item 'D:\ygh-deploy\rocketmq\conf\broker.conf' | Select-Object FullName,Length
Get-Content 'D:\ygh-deploy\rocketmq\conf\broker.conf'
```

**执行后的结果**：文件名、路径正确，显示 12 行配置。`brokerIP1` 是客户 Windows VMnet8 地址，`listenPort` 与所选端口组一致。

### 第五步：创建 ygh-local Docker 网络

**在哪里操作**：Windows 本机 PowerShell。

先检查：

```powershell
docker network inspect ygh-local --format 'Name={{.Name}} Driver={{.Driver}}'
```

如果提示 `network ygh-local not found`，输入：

```powershell
docker network create ygh-local
```

再次检查。

**执行后的结果**：显示 `Name=ygh-local Driver=bridge`。NameServer 与 Broker 通过这个 Docker 内部网络按容器名通信。

### 第六步：创建消息数据卷

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
docker volume create ygh-rocketmq-store
docker volume inspect ygh-rocketmq-store
```

**执行后的结果**：Docker 返回 `ygh-rocketmq-store`。该卷由 Docker Desktop 管理，容器内挂载路径为 `/home/rocketmq/store`。

**安装位置说明**：不要在 Windows 资源管理器中进入 Docker Desktop 的内部 WSL 数据目录，也不要直接修改其中的文件。数据迁移统一使用本文备份和恢复命令。

### 第七步：把数据卷所有者设置为镜像用户 3000

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
docker run --rm --user 0:0 --entrypoint chown -v ygh-rocketmq-store:/home/rocketmq/store apache/rocketmq:5.3.1 -R 3000:3000 /home/rocketmq/store
docker run --rm --entrypoint id -v ygh-rocketmq-store:/home/rocketmq/store apache/rocketmq:5.3.1
docker run --rm --entrypoint ls -v ygh-rocketmq-store:/home/rocketmq/store apache/rocketmq:5.3.1 -ld /home/rocketmq/store
```

**执行后的结果**：第一条命令无错误；第二条显示容器用户 UID/GID 为 3000，store 目录可访问。该步骤只初始化一个数据卷，不是安装或启动脚本。

## 第四部分：手工启动 NameServer 和 Broker

### 第一步：启动 NameServer 容器

**在哪里操作**：Windows 本机 PowerShell。

输入完整命令：

```powershell
docker run -d `
  --name ygh-rocketmq-namesrv `
  --network ygh-local `
  --cpus="0.50" `
  --memory="256m" `
  -p 19876:9876 `
  -e "JAVA_OPT_EXT=-server -Xms128m -Xmx128m -Xmn64m" `
  --health-cmd="grep -q 'The Name Server boot success' /home/rocketmq/logs/rocketmqlogs/namesrv.log" `
  --health-interval=10s `
  --health-timeout=5s `
  --health-retries=20 `
  --health-start-period=30s `
  --stop-timeout=45 `
  --log-driver=json-file `
  --log-opt=max-size=10m `
  --log-opt=max-file=3 `
  --restart=unless-stopped `
  apache/rocketmq:5.3.1 sh mqnamesrv
```

**执行后的结果**：Docker 输出容器 ID。Windows 的 `19876` 映射到容器 NameServer 的 `9876`。

### 第二步：等待 NameServer 健康

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
docker logs --tail 100 ygh-rocketmq-namesrv
docker inspect ygh-rocketmq-namesrv --format 'Status={{.State.Status}} Health={{.State.Health.Status}} Restarts={{.RestartCount}}'
```

**执行后的结果**：日志包含 `The Name Server boot success`，最终显示 `Status=running Health=healthy Restarts=0`。未 healthy 前不要启动 Broker。

### 第三步-A：使用端口组 A 启动 Broker

**在哪里操作**：Windows 本机 PowerShell。只在 `broker.conf` 为 `listenPort=10911` 时执行。

输入：

```powershell
docker run -d `
  --name ygh-rocketmq-broker `
  --network ygh-local `
  --cpus="1.00" `
  --memory="768m" `
  -p 10909:10909 `
  -p 10911:10911 `
  -p 10912:10912 `
  -e "NAMESRV_ADDR=ygh-rocketmq-namesrv:9876" `
  -e "JAVA_OPT_EXT=-server -Xms384m -Xmx384m -Xmn128m" `
  -v "D:\ygh-deploy\rocketmq\conf\broker.conf:/home/rocketmq/rocketmq-5.3.1/conf/broker.conf:ro" `
  -v ygh-rocketmq-store:/home/rocketmq/store `
  --health-cmd="grep -q 'boot success' /home/rocketmq/logs/rocketmqlogs/broker.log" `
  --health-interval=15s `
  --health-timeout=5s `
  --health-retries=20 `
  --health-start-period=60s `
  --stop-timeout=45 `
  --log-driver=json-file `
  --log-opt=max-size=10m `
  --log-opt=max-file=3 `
  --restart=unless-stopped `
  apache/rocketmq:5.3.1 sh mqbroker -n ygh-rocketmq-namesrv:9876 -c /home/rocketmq/rocketmq-5.3.1/conf/broker.conf
```

**执行后的结果**：Docker 输出 Broker 容器 ID。不要再执行第三步-B。

### 第三步-B：使用端口组 B 启动 Broker

**在哪里操作**：Windows 本机 PowerShell。只在 `broker.conf` 为 `listenPort=20911` 时执行。

输入：

```powershell
docker run -d `
  --name ygh-rocketmq-broker `
  --network ygh-local `
  --cpus="1.00" `
  --memory="768m" `
  -p 20909:20909 `
  -p 20911:20911 `
  -p 20912:20912 `
  -e "NAMESRV_ADDR=ygh-rocketmq-namesrv:9876" `
  -e "JAVA_OPT_EXT=-server -Xms384m -Xmx384m -Xmn128m" `
  -v "D:\ygh-deploy\rocketmq\conf\broker.conf:/home/rocketmq/rocketmq-5.3.1/conf/broker.conf:ro" `
  -v ygh-rocketmq-store:/home/rocketmq/store `
  --health-cmd="grep -q 'boot success' /home/rocketmq/logs/rocketmqlogs/broker.log" `
  --health-interval=15s `
  --health-timeout=5s `
  --health-retries=20 `
  --health-start-period=60s `
  --stop-timeout=45 `
  --log-driver=json-file `
  --log-opt=max-size=10m `
  --log-opt=max-file=3 `
  --restart=unless-stopped `
  apache/rocketmq:5.3.1 sh mqbroker -n ygh-rocketmq-namesrv:9876 -c /home/rocketmq/rocketmq-5.3.1/conf/broker.conf
```

**执行后的结果**：Docker 输出 Broker 容器 ID。不要再执行第三步-A。

### 第四步：等待 Broker 健康并核对公布地址

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
docker logs --tail 150 ygh-rocketmq-broker
docker inspect ygh-rocketmq-broker --format 'Status={{.State.Status}} Health={{.State.Health.Status}} Restarts={{.RestartCount}}'
```

**执行后的结果**：日志应包含以下一种形式：

```text
The broker[broker-a, 192.168.154.1:10911] boot success
The broker[broker-a, 192.168.154.1:20911] boot success
```

地址必须是客户 VMnet8 IPv4，端口必须与所选端口组一致。若日志公布 `172.x.x.x`、虚拟机 IP 或错误 Windows IP，先停止 Broker 并修正 `broker.conf`。

### 第五步：核对资源、挂载、端口和重启策略

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
docker ps --filter name=ygh-rocketmq --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
docker stats --no-stream ygh-rocketmq-namesrv ygh-rocketmq-broker
docker inspect ygh-rocketmq-broker --format 'Memory={{.HostConfig.Memory}} NanoCpus={{.HostConfig.NanoCpus}} Restart={{.HostConfig.RestartPolicy.Name}} Mounts={{json .Mounts}}'
```

**执行后的结果**：NameServer 和 Broker 都 healthy；Broker Memory 为 805306368、NanoCpus 为 1000000000、Restart 为 `unless-stopped`；配置文件为只读挂载，数据卷名称为 `ygh-rocketmq-store`。

## 第五部分：手工创建并验证项目 Topic

### 第一步-A：端口组 A 创建 YGH_DOMAIN_EVENTS

**在哪里操作**：Windows 本机 PowerShell。只执行与端口组匹配的一步。

输入：

```powershell
docker exec ygh-rocketmq-broker sh mqadmin updateTopic -n ygh-rocketmq-namesrv:9876 -b 127.0.0.1:10911 -t YGH_DOMAIN_EVENTS -r 4 -w 4
```

**执行后的结果**：显示 `create topic to 127.0.0.1:10911 success`，Topic 有 4 个读队列和 4 个写队列。

### 第一步-B：端口组 B 创建 YGH_DOMAIN_EVENTS

**在哪里操作**：Windows 本机 PowerShell。只执行与端口组匹配的一步。

输入：

```powershell
docker exec ygh-rocketmq-broker sh mqadmin updateTopic -n ygh-rocketmq-namesrv:9876 -b 127.0.0.1:20911 -t YGH_DOMAIN_EVENTS -r 4 -w 4
```

**执行后的结果**：显示 `create topic to 127.0.0.1:20911 success`，Topic 有 4 个读队列和 4 个写队列。

**原因**：在 Broker 容器内使用 `127.0.0.1` 定点创建，避免管理命令先读取 `brokerIP1` 后绕到 Windows 地址。Java 客户端仍使用 Broker 对外公布的 VMnet8 地址。

### 第二步：查询 Topic 路由

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
docker exec ygh-rocketmq-broker sh mqadmin topicRoute -n ygh-rocketmq-namesrv:9876 -t YGH_DOMAIN_EVENTS
```

**执行后的结果**：输出包含：

- `brokerName` 为 `broker-a`。
- `cluster` 为 `YghDevCluster`。
- `readQueueNums` 和 `writeQueueNums` 都为 4。
- `brokerAddrs` 为客户 VMnet8 IPv4 加所选 Broker 监听端口。

### 第三步：查询 Broker 集群

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
docker exec ygh-rocketmq-broker sh mqadmin clusterList -n ygh-rocketmq-namesrv:9876
```

**执行后的结果**：存在 `YghDevCluster`、`broker-a`、Broker ID 0，地址与 `broker.conf` 一致。

### 第四步：从 Windows 验证 NameServer 和 Broker 端口

**在哪里操作**：Windows 本机 PowerShell。

NameServer 固定输入：

```powershell
Test-NetConnection 127.0.0.1 -Port 19876
```

端口组 A 再输入：

```powershell
Test-NetConnection 192.168.154.1 -Port 10911
```

端口组 B 再输入：

```powershell
Test-NetConnection 192.168.154.1 -Port 20911
```

**需要修改的内容**：把 `192.168.154.1` 替换为客户实际 VMnet8 IPv4，只执行所选端口组。

**执行后的结果**：两次都显示 `TcpTestSucceeded : True`。NameServer 能连通但 Broker 不通时，Java 服务仍会发送失败，不能跳过 Broker 检查。

## 第六部分：在 IDEA 中逐个配置使用 RocketMQ 的 Java 服务

### 第一步：确认需要配置的六个服务

**在哪里操作**：Windows 本机 IntelliJ IDEA 和项目源码。

本项目当前直接使用 RocketMQ 的服务是：

| IDEA 服务 | 启动类 | 角色 |
|---|---|---|
| `ygh-product-service` | `com.yuegang.zhihui.product.ProductApplication` | 生产领域事件 |
| `ygh-order-service` | `com.yuegang.zhihui.order.OrderApplication` | 生产事件并消费钱包事件 |
| `ygh-wallet-service` | `com.yuegang.zhihui.wallet.WalletApplication` | 生产支付和退款事件 |
| `ygh-notification-service` | `com.yuegang.zhihui.notification.NotificationApplication` | 消费通知相关事件 |
| `ygh-knowledge-service` | `com.yuegang.zhihui.knowledge.KnowledgeApplication` | 生产知识审核事件 |
| `ygh-training-service` | `com.yuegang.zhihui.training.TrainingApplication` | 生产培训分配事件 |

Inventory、Search、AI 等服务不直接填写 RocketMQ 变量。所有事件使用同一个 Topic：`YGH_DOMAIN_EVENTS`。

### 第二步：打开第一个服务的运行配置

**在哪里操作**：Windows 本机 IntelliJ IDEA。

1. 点击 `Run` → `Edit Configurations...`。
2. 选择 `ygh-product-service`。
3. 没有配置时点击 `+` → `Spring Boot`。
4. `Name` 填写 `ygh-product-service`。
5. `Module` 选择 Product service 模块。
6. `Main class` 选择 `com.yuegang.zhihui.product.ProductApplication`。
7. `JRE` 选择 Oracle JDK 25。
8. 找到 `Environment variables`，点击右侧编辑按钮。

**执行后的结果**：打开 Product 的环境变量编辑窗口。不要把变量填到 IDEA 全局模板或其他服务中。

### 第三步：配置 Product、Notification、Knowledge 和 Training

**在哪里操作**：Windows 本机 IDEA 对应服务的 `Environment variables` 窗口。

这四个服务分别加入：

```text
YGH_MQ_ENABLED=true
YGH_ROCKETMQ_NAMESERVER=127.0.0.1:19876
YGH_ROCKETMQ_TOPIC=YGH_DOMAIN_EVENTS
```

按第二步相同方法分别打开并保存四个运行配置。Main class 使用第一步表格中的准确值。

**执行后的结果**：四个服务启用 MQ，连接 Windows Docker Desktop 暴露的 NameServer，并统一使用项目 Topic。

### 第四步：配置 Order 和 Wallet

**在哪里操作**：Windows 本机 IDEA 的 Order、Wallet 运行配置。

这两个服务逐项加入：

```text
YGH_MQ_ENABLED=true
YGH_ROCKETMQ_NAMESERVER=127.0.0.1:19876
YGH_ROCKETMQ_DOMAIN_TOPIC=YGH_DOMAIN_EVENTS
```

**注意事项**：Order 和 Wallet 源码读取的是 `YGH_ROCKETMQ_DOMAIN_TOPIC`，不是另外四个服务使用的 `YGH_ROCKETMQ_TOPIC`。名称写错时会回退默认值，但交付配置仍必须按源码写准确。

### 第五步：先保存配置，不单独提前启动服务

**在哪里操作**：Windows 本机 IntelliJ IDEA。

这六个服务还依赖 MySQL、Redis、Nacos、内部 HMAC 和其他服务地址；Order 场景还依赖 Seata 及 Product、Inventory、Wallet。完成后续 Seata 文档和最终 IDEA 启动文档后，再按业务顺序启动。

**执行后的结果**：本步骤只保存 RocketMQ 变量，不使用伪造数据库密码或假地址强行启动 Java 服务。

### 第六步：全部依赖完成后检查客户端连接

**在哪里操作**：Windows 本机 IntelliJ IDEA 和 PowerShell。

按最终启动文档启动对应服务后，观察 IDEA Run 日志，不应出现：

```text
RocketMQ producer startup failed
notification RocketMQ consumer startup failed
order RocketMQ consumer startup failed
No route info of this topic
connect to ... failed
```

同时在 PowerShell 输入：

```powershell
docker exec ygh-rocketmq-broker sh mqadmin topicRoute -n ygh-rocketmq-namesrv:9876 -t YGH_DOMAIN_EVENTS
docker logs --since 10m ygh-rocketmq-broker | Select-String -Pattern 'register|consumer|producer|WARN|ERROR'
```

**执行后的结果**：Topic 路由仍指向正确 Broker；Broker 日志没有持续连接异常。消费者是否真正消费成功必须结合 IDEA 日志和最终业务联调确认，不能只凭容器为 healthy 判断。业务事件测试应在最终联调步骤执行，避免在客户正式库中随意制造订单或钱包数据。

## 第七部分：停止、再次启动、备份和恢复

### 第一步：按正确顺序停止 RocketMQ

**在哪里操作**：先在 Windows IDEA 停止启用了 MQ 的六个 Java 服务，再到 PowerShell。

输入：

```powershell
docker stop -t 45 ygh-rocketmq-broker
docker stop -t 45 ygh-rocketmq-namesrv
docker ps -a --filter name=ygh-rocketmq --format 'table {{.Names}}\t{{.Status}}'
```

**执行后的结果**：先停止 Broker，再停止 NameServer，两个容器状态为 Exited。数据卷没有删除。

### 第二步：再次启动 RocketMQ

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
docker start ygh-rocketmq-namesrv
docker inspect ygh-rocketmq-namesrv --format 'Health={{.State.Health.Status}}'
```

等待 NameServer 为 healthy，再输入：

```powershell
docker start ygh-rocketmq-broker
docker inspect ygh-rocketmq-broker --format 'Health={{.State.Health.Status}}'
docker exec ygh-rocketmq-broker sh mqadmin topicRoute -n ygh-rocketmq-namesrv:9876 -t YGH_DOMAIN_EVENTS
```

**执行后的结果**：两个容器恢复 healthy，Topic 路由仍存在。此后才能在 IDEA 启动 Java 服务。

### 第三步：备份 Broker 配置文件

**在哪里操作**：Windows 本机 PowerShell。

先查看当前时间：

```powershell
Get-Date -Format 'yyyyMMdd-HHmmss'
```

假设显示 `20260715-143000`，把下面两条命令中的示例时间手工改成实际值，然后逐条输入：

```powershell
Copy-Item 'D:\ygh-deploy\rocketmq\conf\broker.conf' 'D:\ygh-backups\rocketmq\broker-20260715-143000.conf'
Get-FileHash 'D:\ygh-backups\rocketmq\broker-20260715-143000.conf' -Algorithm SHA256
```

**执行后的结果**：备份目录出现带时间的配置文件并输出 SHA256。不要照抄示例时间，以免覆盖同名备份。

### 第四步：停止 Broker 后备份消息数据卷

**在哪里操作**：Windows 本机 PowerShell。

先按第一步停止 Java 服务、Broker 和 NameServer，再输入当前时间：

```powershell
Get-Date -Format 'yyyyMMdd-HHmmss'
```

假设显示 `20260715-143000`，把下面命令中的示例时间手工改成实际值。然后输入这一条完整的 `docker run` 命令：

```powershell
docker run --rm `
  --user 0:0 `
  --entrypoint tar `
  -v ygh-rocketmq-store:/source:ro `
  -v "D:\ygh-backups\rocketmq:/backup" `
  apache/rocketmq:5.3.1 `
  czf /backup/rocketmq-store-20260715-143000.tar.gz -C /source .
```

看到命令返回 PowerShell 提示符后，再逐条输入：

```powershell
Get-FileHash 'D:\ygh-backups\rocketmq\rocketmq-store-20260715-143000.tar.gz' -Algorithm SHA256
Get-Item 'D:\ygh-backups\rocketmq\rocketmq-store-20260715-143000.tar.gz' | Select-Object FullName,Length
```

**执行后的结果**：生成大于 0 字节的压缩包和 SHA256。该备份可能包含客户消息内容，不得提交 Git 或通过公共聊天工具发送。

### 第五步：恢复到新的验证数据卷

**在哪里操作**：Windows 本机 PowerShell。下面以 `rocketmq-store-20260714-120000.tar.gz` 为例，替换成实际文件名。

输入：

```powershell
Get-FileHash 'D:\ygh-backups\rocketmq\rocketmq-store-20260714-120000.tar.gz' -Algorithm SHA256
docker volume create ygh-rocketmq-store-restore
docker run --rm --user 0:0 `
  --entrypoint tar `
  -v ygh-rocketmq-store-restore:/restore `
  -v "D:\ygh-backups\rocketmq:/backup:ro" `
  apache/rocketmq:5.3.1 `
  xzf /backup/rocketmq-store-20260714-120000.tar.gz -C /restore
docker run --rm --user 0:0 --entrypoint chown -v ygh-rocketmq-store-restore:/restore apache/rocketmq:5.3.1 -R 3000:3000 /restore
docker run --rm --entrypoint du -v ygh-rocketmq-store-restore:/restore apache/rocketmq:5.3.1 -sh /restore
docker run --rm --entrypoint find -v ygh-rocketmq-store-restore:/restore apache/rocketmq:5.3.1 /restore -maxdepth 2 -type f
```

**执行后的结果**：新卷中出现 RocketMQ store 文件，原 `ygh-rocketmq-store` 未被覆盖。正式替换前必须在维护窗口用新容器名和不冲突端口验证，不得直接向正在运行的卷解压。

### 第六步：确认无误后替换数据卷

**在哪里操作**：Windows 本机 PowerShell。该操作只在客户确认恢复点、已备份当前卷且所有相关服务停止后执行。

Docker 容器的数据卷挂载在创建时固定，不能通过 `docker start` 更换。正式恢复需要：

1. 保留原卷，不执行 `docker volume rm ygh-rocketmq-store`。
2. 删除已经停止的 Broker 容器：

```powershell
docker rm ygh-rocketmq-broker
```

3. 重新执行第四部分第三步对应的 Broker 命令，但把这一段：

```text
-v ygh-rocketmq-store:/home/rocketmq/store
```

改为：

```text
-v ygh-rocketmq-store-restore:/home/rocketmq/store
```

4. 验证 Broker healthy、Topic 路由、消费组和业务消息后，再决定是否长期保留原卷。

**执行后的结果**：新 Broker 使用验证过的恢复卷；原卷仍可回退。删除容器不会删除命名卷，但必须确认命令中没有 `-v` 参数。

## 第八部分：常见错误逐项排查

### 1. Docker 提示端口被禁止访问

**在哪里排查**：Windows 本机 PowerShell。

重新执行第一部分第四、五步。如果 109xx 落在系统保留范围，停止并删除未成功创建的 Broker 容器，按端口组 B 修改 `listenPort=20911`，再使用 20909/20911/20912 的完整启动命令。不能只改 Docker 映射左侧端口。

### 2. NameServer 可连接，但 Java 报 Broker connect failed

**在哪里排查**：Windows PowerShell、`broker.conf` 和 Broker 日志。

执行 Topic 路由查询，检查 `brokerAddrs`。如果返回容器 `172.x`、虚拟机 `192.168.154.10` 或旧 VMnet8 地址，修改 `brokerIP1` 为 Windows 当前 VMnet8 IPv4，停止并重新启动 Broker，再次查询路由。

### 3. `No route info of this topic: YGH_DOMAIN_EVENTS`

**在哪里排查**：Windows 本机 PowerShell。

确认 Broker healthy，然后重新执行第五部分中与端口组匹配的 `updateTopic`，再执行 `topicRoute`。不能把 Topic 拼写成小写或自行增加前缀。

### 4. Broker 日志出现 store 权限错误

**在哪里排查**：Windows 本机 PowerShell。

停止 Broker，重新执行第三部分第七步。镜像运行用户 UID/GID 是 3000，不能把数据卷设置为其他用户，也不要在 Docker Desktop 内部目录手工改权限。

### 5. Broker 因内存不足退出

**在哪里排查**：Windows Docker Desktop 和 PowerShell。

输入：

```powershell
docker inspect ygh-rocketmq-broker --format 'OOMKilled={{.State.OOMKilled}} Exit={{.State.ExitCode}} Error={{.State.Error}}'
docker logs --tail 200 ygh-rocketmq-broker
docker stats --no-stream
```

如果 `OOMKilled=true`，先停止 Elasticsearch 和无关 Java 服务，确认 Docker Desktop 有足够内存。不要把 Broker JVM 堆随意提高到超过 384MB，也不要移除 768MB 容器上限。

### 6. 修改 broker.conf 后没有生效

**在哪里排查**：Windows PowerShell。

普通参数修改后执行 `docker restart ygh-rocketmq-broker` 并查看日志。`listenPort` 或 Docker 端口映射变化时，必须停止并删除 Broker 容器，再用匹配的新端口命令重新创建；数据卷保持不删。

### 7. 容器名已存在

**在哪里排查**：Windows PowerShell。

输入：

```powershell
docker ps -a --filter name=ygh-rocketmq
```

如果是本文创建且配置正确的 Exited 容器，使用 `docker start`，不要重复 `docker run`。只有确认需要重建并已停止 Java 服务、完成备份时，才删除对应容器；不能删除数据卷。

### 8. IDEA 服务启动后没有消费组

**在哪里排查**：IDEA 对应 Run 配置与日志。

确认 `YGH_MQ_ENABLED=true`，NameServer 为 `127.0.0.1:19876`。Order 和 Wallet 使用 `YGH_ROCKETMQ_DOMAIN_TOPIC`，其余四个服务使用 `YGH_ROCKETMQ_TOPIC`。Notification 和 Order 是当前直接创建消费者的服务，只有它们成功启动后才应看到对应消费组。

### 9. Windows 重启后 RocketMQ 没有恢复

**在哪里排查**：Docker Desktop 和 PowerShell。

确认 Docker Desktop 设置中启用了登录时启动，再输入：

```powershell
docker inspect ygh-rocketmq-namesrv ygh-rocketmq-broker --format '{{.Name}} Restart={{.HostConfig.RestartPolicy.Name}} Status={{.State.Status}}'
```

重启策略应为 `unless-stopped`。如果此前人工执行过 `docker stop`，Docker 不会把它当作异常退出；登录后按第七部分第二步手工启动。

### 10. 安全和生产使用限制

**在哪里确认**：项目交付评审。

当前低配置交付配置是单 NameServer、单异步 Master Broker，并开启自动创建 Topic 和订阅组，没有配置 RocketMQ ACL。它适用于本机开发、验收和受控内网交付，不等同于生产高可用集群。公网环境不能直接开放 19876、109xx 或 209xx；正式生产必须另行设计多节点、副本、ACL、监控、备份和防火墙策略。
