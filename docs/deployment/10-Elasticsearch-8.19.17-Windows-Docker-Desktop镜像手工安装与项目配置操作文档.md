# Elasticsearch 8.19.17 Windows Docker Desktop 镜像手工安装与项目配置操作文档

## 第一部分：检查 Docker Desktop、WSL2 内核参数和端口

### 第一步：确认 Docker Desktop 正在 Windows 本机运行

**在哪里操作**：客户的 Windows 本机桌面和 PowerShell，不是在 Rocky Linux 虚拟机、SSH 终端或 Ubuntu WSL 中操作。

1. 双击桌面的 `Docker Desktop`。
2. 等待左下角或主界面显示 Docker Engine 已运行。
3. 按 `Win + X`，点击“终端（管理员）”或“Windows PowerShell（管理员）”。
4. 输入：

```powershell
docker version
```

**执行后的结果**：同时显示 `Client` 和 `Server` 两部分。只有 Client、出现 `pipe/docker_engine` 错误或提示无法连接时，说明 Docker Desktop 尚未启动完成。

**安装和运行位置**：本项目 Elasticsearch 不安装到 Rocky Linux 虚拟机，也不直接安装到 Windows 软件目录。它以 Linux 容器运行在 Windows 本机 Docker Desktop 中。Docker Desktop 内部使用 WSL2，但客户不在 Ubuntu WSL 中安装 Elasticsearch。

### 第二步：确认 Docker Desktop 使用 Linux 容器

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
docker info --format 'OSType={{.OSType}} Architecture={{.Architecture}} CPUs={{.NCPU}} Memory={{.MemTotal}}'
```

**执行后的结果**：必须看到 `OSType=linux`，架构通常是 `x86_64` 或 `amd64`。

如果显示 `windows`：

1. 在任务栏右下角找到 Docker 图标。
2. 右键 Docker 图标。
3. 点击 `Switch to Linux containers`。
4. 等待 Docker Desktop 重启，然后重新执行本步骤命令。

### 第三步：给 Docker Desktop 保留足够资源

**在哪里操作**：Windows 本机 Docker Desktop。

1. 打开 Docker Desktop。
2. 点击右上角齿轮 `Settings`。
3. 点击 `Resources`。
4. 如果界面允许直接配置资源，将 Memory 设置为至少 `4 GB`，CPU 设置为至少 `2` 核。
5. 点击 `Apply & restart`。

Docker Desktop 使用 WSL2 动态资源且页面没有滑块时，不需要另建 Elasticsearch 虚拟机。回到 PowerShell输入：

```powershell
docker system df
docker stats --no-stream
```

**执行后的结果**：磁盘至少保留 5 GB 可用空间。本文给 Elasticsearch 容器设置 `1280 MB` 内存上限、`1` 个 CPU，JVM 堆固定为 `512 MB`。

**注意事项**：本项目关闭 Elasticsearch 机器学习功能。不要把容器内存降回 1 GB；项目实测 1 GB 上限曾因持续垃圾回收而以退出码 `137` 停止。

### 第四步：确认 Docker Desktop 的 WSL2 后端存在

**在哪里操作**：Windows 本机管理员 PowerShell。

输入：

```powershell
wsl -l -v
```

**执行后的结果**：列表中应有 `docker-desktop`，`VERSION` 为 `2`，Docker Desktop 运行时其状态通常是 `Running`。

如果提示没有 `wsl` 命令或没有 `docker-desktop`，先返回 Docker Desktop 安装文档完成 WSL2 后端安装，不能继续启动 Elasticsearch。

### 第五步：检查并设置 vm.max_map_count

**在哪里操作**：Windows 本机管理员 PowerShell。命令会进入 Docker Desktop 自己的 WSL2 发行版，不进入客户的 Ubuntu WSL，也不进入 Rocky Linux 虚拟机。

先输入：

```powershell
wsl -d docker-desktop -u root sysctl vm.max_map_count
```

**执行后的结果**：正确值为：

```text
vm.max_map_count = 1048576
```

如果不是 `1048576`，输入：

```powershell
wsl -d docker-desktop -u root sysctl -w vm.max_map_count=1048576
wsl -d docker-desktop -u root sysctl vm.max_map_count
```

**执行后的结果**：第一条命令返回 `vm.max_map_count = 1048576`，第二条再次确认该值。

**注意事项**：部分 Windows/WSL 版本在 Docker Desktop 或电脑重启后会恢复该值。每次 Elasticsearch 报 `max virtual memory areas vm.max_map_count` 时都重新执行本步骤。不要在 Rocky Linux 虚拟机中修改这个参数，因为 Elasticsearch 不运行在那里。

### 第六步：检查 Windows 19200 端口

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
  Where-Object { $_.LocalPort -eq 19200 } |
  Select-Object LocalAddress,LocalPort,OwningProcess
docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' | Select-String -Pattern 'elasticsearch|NAMES'
```

**执行后的结果**：全新部署时没有进程监听 19200，也不存在 `ygh-elasticsearch` 同名容器。

如果出现进程号，输入：

```powershell
Get-Process -Id 这里替换为实际进程号
```

查明占用程序后再处理。不能随意结束客户已有程序，也不能自行把项目端口改成 9200。

## 第二部分：手动拉取、核对或离线载入 Elasticsearch 镜像

### 第一步：从官方页面确认项目固定镜像

**在哪里操作**：Windows 本机浏览器。

1. 打开 Elastic 8.19 Docker 官方文档：`https://www.elastic.co/guide/en/elasticsearch/reference/8.19/docker.html`。
2. 在页面中搜索 `8.19.17`。
3. 打开官方镜像目录：`https://www.docker.elastic.co/r/elasticsearch/elasticsearch:8.19.17`。
4. 确认镜像完整名称为：

```text
docker.elastic.co/elasticsearch/elasticsearch:8.19.17
```

**执行后的结果**：本项目下载对象是 Elasticsearch Docker 镜像，不是 Elasticsearch ZIP、RPM 或源码包。镜像内部已经包含运行 Elasticsearch 所需的 JDK，不需要在 Windows、WSL2或 Rocky Linux 虚拟机中为 Elasticsearch 再安装 JDK。

### 第二步：先检测官方镜像仓库是否可达

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
curl.exe -I --connect-timeout 10 --max-time 20 https://docker.elastic.co/v2/
```

**执行后的结果**：返回 HTTP `200` 或 `401 Unauthorized` 都表示仓库可达。Registry 未登录时返回 `401` 是正常结果，不代表拉取失败。

出现“无法解析主机”“连接超时”“connection reset”或连续 `5xx` 时，官方线路当前不可用，进入第四步测试 DaoCloud 代理。

### 第三步：从 Elastic 官方仓库拉取固定版本

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
docker pull docker.elastic.co/elasticsearch/elasticsearch:8.19.17
```

**执行后的结果**：最后显示 `Downloaded newer image` 或 `Image is up to date`，并显示镜像摘要。项目实测 `amd64/linux` 镜像摘要为：

```text
sha256:aa6ee0ea2d708cea22a24ed44a420c5bbde9853d58a872e1e870f2086d04f652
```

**注意事项**：不能拉取 `latest`，不能改为 `elasticsearch:8`，也不能用 Docker Hub 上名称相似的第三方镜像替代。

### 第四步：官方仓库失败时测试 DaoCloud Elastic 专用代理

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
curl.exe -I --connect-timeout 10 --max-time 20 https://elastic.m.daocloud.io/v2/
```

返回 HTTP `200` 或 `401` 后输入：

```powershell
docker pull elastic.m.daocloud.io/elasticsearch/elasticsearch:8.19.17
docker tag elastic.m.daocloud.io/elasticsearch/elasticsearch:8.19.17 docker.elastic.co/elasticsearch/elasticsearch:8.19.17
```

**执行后的结果**：代理镜像被拉到 Windows Docker Desktop，并被重新标记为项目固定名称。2026-07-14 项目环境实测该代理可拉取同一镜像和同一摘要。

**哪些源可用、哪些源不可直接使用**：

1. `docker.elastic.co` 是首选官方源，检测可达时直接使用。
2. `elastic.m.daocloud.io` 是 DaoCloud 为 `docker.elastic.co` 提供的专用代理，必须检测通过后使用。
3. Docker Desktop `registry-mirrors` 中常见的 Docker Hub 镜像源主要加速 `docker.io`，不会自动把 `docker.elastic.co` 改走代理。
4. `docker.m.daocloud.io/elasticsearch/...` 少了上游仓库类型，不是本文确认的 Elastic 专用地址。
5. `docker.1ms.run` 即使 `/v2/` 返回 `401`，也只说明 Registry 入口存在；未确认目标镜像和摘要前，不作为本项目默认源。
6. 任何代理如果返回 `403`、`429`、超时、目标标签不存在或摘要不一致，本次部署就视为不可用，改用官方源或离线镜像。

### 第五步：核对镜像版本、架构、用户和摘要

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
docker image inspect docker.elastic.co/elasticsearch/elasticsearch:8.19.17 --format 'ID={{.Id}} ARCH={{.Architecture}} OS={{.Os}} USER={{.Config.User}} WORKDIR={{.Config.WorkingDir}} DIGESTS={{json .RepoDigests}}'
```

**执行后的结果**：应包含：

```text
ARCH=amd64
OS=linux
USER=1000:0
WORKDIR=/usr/share/elasticsearch
```

摘要应包含 `sha256:aa6ee0...d04f652`。`USER=1000:0` 是后面设置密码卷和快照卷权限的依据，不能省略。

### 第六步：有网电脑导出离线镜像

**在哪里操作**：能够成功拉取镜像的 Windows 本机 PowerShell。

先创建交付目录：

```powershell
New-Item -ItemType Directory -Force 'D:\ygh-delivery\docker-images'
```

再输入：

```powershell
docker save -o 'D:\ygh-delivery\docker-images\elasticsearch-8.19.17-amd64.tar' docker.elastic.co/elasticsearch/elasticsearch:8.19.17
Get-Item 'D:\ygh-delivery\docker-images\elasticsearch-8.19.17-amd64.tar' | Select-Object FullName,Length,LastWriteTime
Get-FileHash 'D:\ygh-delivery\docker-images\elasticsearch-8.19.17-amd64.tar' -Algorithm SHA256
```

**执行后的结果**：目录中生成 TAR 文件，并显示文件大小和文件 SHA256。把这个文件 SHA256 记录到交付清单。TAR 文件哈希是交付文件校验值，不等同于镜像 RepoDigest。

### 第七步：客户电脑离线载入镜像

**在哪里操作**：客户 Windows 本机资源管理器和 PowerShell。

1. 用移动硬盘或交付压缩包把 TAR 放到：

```text
D:\ygh-delivery\docker-images\elasticsearch-8.19.17-amd64.tar
```

2. 在客户电脑计算哈希，并与交付清单比较：

```powershell
Get-FileHash 'D:\ygh-delivery\docker-images\elasticsearch-8.19.17-amd64.tar' -Algorithm SHA256
```

3. 哈希一致后输入：

```powershell
docker load -i 'D:\ygh-delivery\docker-images\elasticsearch-8.19.17-amd64.tar'
docker image inspect docker.elastic.co/elasticsearch/elasticsearch:8.19.17 --format 'ID={{.Id}} ARCH={{.Architecture}} OS={{.Os}} DIGESTS={{json .RepoDigests}}'
```

**执行后的结果**：显示 `Loaded image`，随后可以查到固定版本。离线载入后不需要再次 `docker pull`。

## 第三部分：手工创建网络、数据卷、密码卷和快照卷

### 第一步：创建项目 Docker 网络

**在哪里操作**：Windows 本机 PowerShell。

先检查：

```powershell
docker network inspect ygh-local
```

如果返回 `network ygh-local not found`，输入：

```powershell
docker network create ygh-local
```

再验证：

```powershell
docker network inspect ygh-local --format 'NAME={{.Name}} DRIVER={{.Driver}} SCOPE={{.Scope}}'
```

**执行后的结果**：显示 `NAME=ygh-local DRIVER=bridge SCOPE=local`。

### 第二步：创建 Elasticsearch 数据卷

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
docker volume create ygh-elasticsearch-data
docker volume inspect ygh-elasticsearch-data
```

**执行后的结果**：创建名为 `ygh-elasticsearch-data` 的 Docker 命名卷。该卷挂载到容器 `/usr/share/elasticsearch/data`，容器删除后索引数据仍保留。

**注意事项**：不要把该卷当作可靠备份，不要执行 `docker volume rm ygh-elasticsearch-data`，也不要执行 `docker system prune --volumes`。

### 第三步：创建密码卷

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
docker volume create ygh-elasticsearch-secret
docker volume inspect ygh-elasticsearch-secret
```

**执行后的结果**：创建密码专用命名卷。本文不使用 `.env`，也不把明文密码写进 `docker run` 命令历史。

### 第四步：生成并妥善记录 elastic 密码

**在哪里操作**：Windows 本机 PowerShell和客户批准的密码管理器。

输入下面命令生成随机密码：

```powershell
[Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(24))
```

**执行后的结果**：PowerShell 显示一串随机字符。

1. 把该值立即保存到客户密码管理器，名称填写 `跨境智汇-Elasticsearch-elastic`。
2. 不要写进项目源码、Markdown、截图、聊天记录或 `.env`。
3. 后续出现“输入 elastic 密码”时，粘贴这个值。

### 第五步：进入临时容器写入密码文件

**在哪里操作**：Windows 本机 PowerShell。启动的是一次性配置容器，不是正式 Elasticsearch 容器。

输入：

```powershell
docker run --rm -it --user 0 --entrypoint bash -v ygh-elasticsearch-secret:/secret docker.elastic.co/elasticsearch/elasticsearch:8.19.17
```

**执行后的结果**：提示符变成类似：

```text
bash-5.1#
```

此时已经进入容器内部。逐条输入：

```bash
read -s -p "请输入 elastic 密码: " ELASTIC_PASSWORD
```

粘贴第四步保存的密码并按 Enter。输入过程不回显字符，这是正常现象。继续逐条输入：

```bash
echo
printf %s "$ELASTIC_PASSWORD" > /secret/elastic-password
chown 1000:0 /secret/elastic-password
chmod 400 /secret/elastic-password
stat -c '%u:%g %a %n' /secret/elastic-password
unset ELASTIC_PASSWORD
exit
```

**执行后的结果**：`stat` 必须显示：

```text
1000:0 400 /secret/elastic-password
```

执行 `exit` 后回到 `PS C:\...>`，临时容器自动删除，密码文件保留在命名卷中。

**注意事项**：权限必须是 `400` 或 `600`。项目实测 `440` 会报 `must have file permissions 400 or 600` 并拒绝启动；所有者错误会报 `ELASTIC_PASSWORD_FILE is not readable`。

### 第六步：创建并授权快照卷

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
docker volume create ygh-elasticsearch-snapshots
docker run --rm --user 0 --entrypoint bash -v ygh-elasticsearch-snapshots:/mnt/snapshots docker.elastic.co/elasticsearch/elasticsearch:8.19.17 -lc 'chown 1000:0 /mnt/snapshots && chmod 750 /mnt/snapshots && stat -c "%u:%g %a %n" /mnt/snapshots'
```

**执行后的结果**：最后显示：

```text
1000:0 750 /mnt/snapshots
```

该卷用于 Elasticsearch 官方快照，不直接复制正在使用的数据卷。

## 第四部分：手工启动 Elasticsearch 容器

### 第一步：首次创建并启动正式容器

**在哪里操作**：Windows 本机 PowerShell。

完整复制下面命令。PowerShell 中反引号必须是每行最后一个字符，后面不能有空格：

```powershell
docker run -d `
  --name ygh-elasticsearch `
  --network ygh-local `
  -p 19200:9200 `
  --restart unless-stopped `
  --memory 1280m `
  --cpus 1 `
  --ulimit nofile=65535:65535 `
  --stop-timeout 60 `
  --log-opt max-size=10m `
  --log-opt max-file=3 `
  -e 'discovery.type=single-node' `
  -e 'xpack.security.enabled=true' `
  -e 'xpack.ml.enabled=false' `
  -e 'ingest.geoip.downloader.enabled=false' `
  -e 'ES_JAVA_OPTS=-Xms512m -Xmx512m' `
  -e 'ELASTIC_PASSWORD_FILE=/run/secrets/elastic-password' `
  -e 'path.repo=/mnt/snapshots' `
  -v 'ygh-elasticsearch-secret:/run/secrets:ro' `
  -v 'ygh-elasticsearch-data:/usr/share/elasticsearch/data' `
  -v 'ygh-elasticsearch-snapshots:/mnt/snapshots' `
  --health-cmd='curl -fsS -u elastic:$(cat /run/secrets/elastic-password) http://127.0.0.1:9200/_cluster/health >/dev/null' `
  --health-interval=10s `
  --health-timeout=5s `
  --health-retries=18 `
  --health-start-period=60s `
  docker.elastic.co/elasticsearch/elasticsearch:8.19.17
```

**执行后的结果**：PowerShell 返回一串容器 ID。Elasticsearch 首次初始化通常需要 1 到 2 分钟。

**参数说明**：

1. `19200:9200`：Windows 本机使用 19200，容器内部使用 9200。
2. `1280m`：容器内存上限；不能改回已出现退出码 137 的 1 GB。
3. `-Xms512m -Xmx512m`：JVM 初始堆和最大堆均为 512 MB。
4. `xpack.security.enabled=true`：启用账号密码认证。
5. `xpack.ml.enabled=false`：低配置交付环境关闭机器学习模块。
6. `path.repo`：允许后续把官方快照写入快照卷。
7. `unless-stopped`：Docker Desktop 启动后自动恢复容器，人工执行 `docker stop` 后不会立即自行启动。

### 第二步：等待容器健康

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
docker ps --filter 'name=^ygh-elasticsearch$' --format 'NAME={{.Names}} STATUS={{.Status}} PORTS={{.Ports}}'
```

启动初期可能显示 `health: starting`。每隔 10 秒重新执行，直到显示 `healthy`。

如果容器变成 `Exited`，输入：

```powershell
docker logs --tail 200 ygh-elasticsearch
docker inspect ygh-elasticsearch --format 'STATUS={{.State.Status}} EXIT={{.State.ExitCode}} ERROR={{.State.Error}} OOM={{.State.OOMKilled}}'
```

不能反复删除数据卷。根据日志进入故障处理部分。

### 第三步：验证版本和账号密码

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
curl.exe -u elastic http://127.0.0.1:19200/
```

看到下面提示时，从密码管理器粘贴密码并按 Enter：

```text
Enter host password for user 'elastic':
```

**执行后的结果**：返回 JSON，`version.number` 必须是 `8.19.17`，`tagline` 为 `You Know, for Search`。

密码错误时返回 `401 Unauthorized`。不要关闭安全认证来绕过密码问题。

### 第四步：检查集群健康和资源限制

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
curl.exe -u elastic http://127.0.0.1:19200/_cluster/health?pretty
docker inspect ygh-elasticsearch --format 'MEMORY={{.HostConfig.Memory}} CPU_NANO={{.HostConfig.NanoCpus}} RESTART={{.HostConfig.RestartPolicy.Name}}'
```

**执行后的结果**：创建项目索引前，集群可能是 `yellow`；完成下一部分并把副本数设为 0 后应为 `green`。内存字节值应为 `1342177280`，重启策略为 `unless-stopped`。

### 第五步：检查 Windows 端口

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
Test-NetConnection 127.0.0.1 -Port 19200
```

**执行后的结果**：`TcpTestSucceeded : True`。

**注意事项**：Java 服务在 Windows IDEA 中运行，所以使用 `127.0.0.1:19200`。Rocky Linux 虚拟机中的 MySQL、Redis 和 Nacos 不需要连接 Elasticsearch；不要把 Elasticsearch 地址写成 `192.168.154.10:19200`。

## 第五部分：手工创建项目需要的两个索引和知识库别名

### 第一步：创建索引配置目录

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
New-Item -ItemType Directory -Force 'D:\ygh-deploy\elasticsearch\index'
```

**执行后的结果**：生成目录：

```text
D:\ygh-deploy\elasticsearch\index
```

该目录只存放不含密码的索引 JSON 配置。

### 第二步：手工创建 knowledge-v1.json

**在哪里操作**：Windows 本机 PowerShell和记事本。

输入：

```powershell
notepad 'D:\ygh-deploy\elasticsearch\index\knowledge-v1.json'
```

记事本询问是否创建新文件时点击“是”，粘贴下面全部内容：

```json
{
  "settings": {
    "number_of_shards": 1,
    "number_of_replicas": 0
  },
  "mappings": {
    "properties": {
      "documentId": { "type": "keyword" },
      "chunkId": { "type": "keyword" },
      "title": { "type": "text" },
      "content": { "type": "text" },
      "category": { "type": "keyword" },
      "visibility": { "type": "keyword" },
      "documentVersion": { "type": "long" },
      "sourceUpdatedAt": { "type": "date" }
    }
  },
  "aliases": {
    "knowledge-active": {
      "is_write_index": true
    }
  }
}
```

1. 点击“文件”→“另存为”。
2. 文件名保持 `knowledge-v1.json`。
3. “保存类型”选择“所有文件”。
4. 编码选择 `UTF-8`。
5. 保存到 `D:\ygh-deploy\elasticsearch\index`。

**执行后的结果**：创建真实索引 `knowledge-v1` 的配置，并让项目固定别名 `knowledge-active` 指向该索引。

### 第三步：创建 knowledge-v1 和 knowledge-active

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
curl.exe -u elastic -X PUT "http://127.0.0.1:19200/knowledge-v1" -H "Content-Type: application/json" --data-binary "@D:\ygh-deploy\elasticsearch\index\knowledge-v1.json"
```

按提示输入 elastic 密码。

**执行后的结果**：返回：

```json
{"acknowledged":true,"shards_acknowledged":true,"index":"knowledge-v1"}
```

如果返回 `resource_already_exists_exception`，先执行后面的核对命令，不要删除已有索引。

### 第四步：手工创建 product-active.json

**在哪里操作**：Windows 本机 PowerShell和记事本。

输入：

```powershell
notepad 'D:\ygh-deploy\elasticsearch\index\product-active.json'
```

粘贴：

```json
{
  "settings": {
    "number_of_shards": 1,
    "number_of_replicas": 0
  },
  "mappings": {
    "properties": {
      "documentId": { "type": "keyword" },
      "chunkId": { "type": "keyword" },
      "title": { "type": "text" },
      "content": { "type": "text" },
      "category": { "type": "keyword" },
      "visibility": { "type": "keyword" },
      "documentVersion": { "type": "long" },
      "sourceUpdatedAt": { "type": "date" }
    }
  }
}
```

按上一小节相同方式，以 UTF-8 和“所有文件”保存。

**执行后的结果**：生成商城商品全文检索索引配置。`product-active` 在当前项目中是实际索引名，不是知识库版本别名。

### 第五步：创建 product-active

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
curl.exe -u elastic -X PUT "http://127.0.0.1:19200/product-active" -H "Content-Type: application/json" --data-binary "@D:\ygh-deploy\elasticsearch\index\product-active.json"
```

按提示输入 elastic 密码。

**执行后的结果**：返回 `acknowledged:true` 和 `index:"product-active"`。

### 第六步：核对两个索引和别名

**在哪里操作**：Windows 本机 PowerShell。

依次输入：

```powershell
curl.exe -u elastic "http://127.0.0.1:19200/_cat/indices/knowledge-v1,product-active?v&h=health,status,index,docs.count,store.size"
curl.exe -u elastic "http://127.0.0.1:19200/_cat/aliases/knowledge-active?v"
curl.exe -u elastic "http://127.0.0.1:19200/knowledge-v1/_mapping?pretty"
curl.exe -u elastic "http://127.0.0.1:19200/_cluster/health?pretty"
```

每条命令按提示输入 elastic 密码。

**执行后的结果**：

1. `knowledge-v1` 和 `product-active` 均为 `green open`。
2. `knowledge-active` 指向 `knowledge-v1`，`is_write_index` 为 `true`。
3. 映射中八个字段类型与 JSON 一致。
4. 集群状态为 `green`。

**项目对应关系**：Search 服务的数据库迁移记录也是 `knowledge-active -> knowledge-v1`；Product 服务向 Search 服务发送商品索引任务时固定使用 `product-active`。

## 第六部分：解压项目并在 IDEA 配置 Elasticsearch 连接

### 第一步：把项目源码压缩包解压到 Windows 本机

**在哪里操作**：Windows 本机资源管理器。不是把项目上传到 Elasticsearch 容器、Rocky Linux 虚拟机、Docker 卷或 WSL2。

1. 把交付的项目源码 ZIP 放到 `D:\ygh-delivery`。
2. 右键 ZIP，点击“全部解压缩”。
3. 解压目标填写：

```text
D:\ygh-ai-system
```

4. 点击“提取”。

**执行后的结果**：`D:\ygh-ai-system` 下能看到根 `pom.xml`、`ygh-applications`、`ygh-deploy`、`ygh-platform` 和 `ygh-web`。

**说明**：这里所谓“导入项目”是让 IDEA 打开 Windows 本机源码目录。Docker 只拉取 Elasticsearch 镜像；项目源码绝不能复制进 Elasticsearch 容器。

### 第二步：在 IDEA 打开项目

**在哪里操作**：Windows 本机 IntelliJ IDEA。

1. 打开 IDEA。
2. 点击 `File` → `Open`。
3. 选择 `D:\ygh-ai-system\pom.xml`，或选择项目根目录。
4. 点击 `Open as Project`。
5. 等待 Maven 导入完成。

**执行后的结果**：IDEA Maven 工具窗口能识别项目各模块。Oracle JDK 25 和 `JAVA_HOME` 的安装配置按 Windows 基础环境文档完成；Elasticsearch 容器本身不使用 Windows 的 `JAVA_HOME`。

### 第三步：找到 Search 服务启动类

**在哪里操作**：Windows 本机 IntelliJ IDEA。

按目录展开：

```text
ygh-applications
  ygh-search
    ygh-search-service
      src/main/java
        com.yuegang.zhihui.search
          SearchApplication.java
```

**执行后的结果**：找到 `com.yuegang.zhihui.search.SearchApplication`。只有 Search 服务直接连接 Elasticsearch，Product 服务通过 Search 内部接口建立商品索引，不配置 Elasticsearch 用户名和密码。

### 第四步：给 SearchApplication 添加 Elasticsearch 环境变量

**在哪里操作**：Windows 本机 IntelliJ IDEA。

1. 点击 `Run` → `Edit Configurations`。
2. 选中 `SearchApplication`；不存在时点击 `+` → `Application`，主类填写 `com.yuegang.zhihui.search.SearchApplication`。
3. 找到 `Environment variables`，点击右侧编辑按钮。
4. 逐项新增：

```text
YGH_ELASTICSEARCH_BASE_URL=http://127.0.0.1:19200
YGH_ELASTICSEARCH_USERNAME=elastic
YGH_ELASTICSEARCH_PASSWORD=这里填写客户密码管理器中的真实密码
YGH_SEARCH_INDEX_ALIAS=knowledge-active
YGH_PRODUCT_SEARCH_INDEX=product-active
```

5. 点击 `OK` 保存变量列表。
6. 点击 `Apply`，再点击 `OK`。

**执行后的结果**：Search 运行配置获得 Elasticsearch 地址、认证和两个项目索引名。

**注意事项**：

1. 不要把真实密码写入 `application.yml`、源码或本文。
2. IDEA 运行配置可能把变量保存在本机 `.idea` 文件中，不要把含密码的运行配置提交或发给他人。
3. Search 还需要 Nacos、PGVector、System 内部地址和内部 HMAC 等变量；必须完成对应组件文档后再启动，不要因为 Elasticsearch 已就绪就省略其他变量。

### 第五步：确认启动顺序

**在哪里操作**：Windows 本机 IDEA、PowerShell和虚拟机 SSH 终端。

按下面顺序确认：

1. Rocky Linux 虚拟机中的 MySQL、Redis、Nacos 已健康。
2. Windows Docker Desktop 中的 PGVector 已健康。
3. Windows Docker Desktop 中的 Elasticsearch 已健康，两个索引已创建。
4. IDEA 先启动 System 等 Search 依赖的后端服务。
5. IDEA 再启动 `SearchApplication`。
6. 最后启动会调用 Search 的 Product、Knowledge 和 AI 相关服务。

**执行后的结果**：Search 启动时可以连接 PGVector、Nacos、System 和 Elasticsearch，不会因缺少依赖反复报错。

## 第七部分：手工注册快照仓库并备份索引

### 第一步：创建快照仓库配置文件

**在哪里操作**：Windows 本机 PowerShell和记事本。

输入：

```powershell
notepad 'D:\ygh-deploy\elasticsearch\index\snapshot-repository.json'
```

粘贴：

```json
{
  "type": "fs",
  "settings": {
    "location": "/mnt/snapshots",
    "compress": true
  }
}
```

使用 UTF-8、“所有文件”保存。

### 第二步：注册并验证快照仓库

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
curl.exe -u elastic -X PUT "http://127.0.0.1:19200/_snapshot/ygh_fs_backup" -H "Content-Type: application/json" --data-binary "@D:\ygh-deploy\elasticsearch\index\snapshot-repository.json"
curl.exe -u elastic -X POST "http://127.0.0.1:19200/_snapshot/ygh_fs_backup/_verify?pretty"
```

分别输入 elastic 密码。

**执行后的结果**：注册返回 `acknowledged:true`，验证结果显示当前 Elasticsearch 节点。出现 `repository_verification_exception` 时，返回第三部分第六步重新设置快照卷所有者和权限。

### 第三步：创建一次完整业务索引快照

**在哪里操作**：Windows 本机 PowerShell。

先生成只包含日期时间的快照名：

```powershell
$snapshotName = 'ygh-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
$snapshotName
```

记录输出，然后输入：

```powershell
curl.exe -u elastic -X PUT "http://127.0.0.1:19200/_snapshot/ygh_fs_backup/${snapshotName}?wait_for_completion=true" -H "Content-Type: application/json" -d '{"indices":"knowledge-v1,product-active","include_global_state":false}'
```

**执行后的结果**：JSON 中 `state` 为 `SUCCESS`，`failed` 分片数为 `0`。如果是 `PARTIAL` 或 `FAILED`，本次备份不合格，必须查看响应中的失败原因。

### 第四步：查询快照

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
curl.exe -u elastic "http://127.0.0.1:19200/_snapshot/ygh_fs_backup/_all?pretty"
```

**执行后的结果**：能看到刚创建的快照名、两个索引和 `SUCCESS` 状态。

### 第五步：把快照仓库导出到 Windows 备份目录

**在哪里操作**：Windows 本机 PowerShell。导出前必须停止写入并停止 Elasticsearch，不能在快照仓库仍被修改时复制。

1. 在 IDEA 停止 Search、Product、Knowledge 和 AI 等可能写入检索数据的服务。
2. 停止 Elasticsearch：

```powershell
docker stop -t 60 ygh-elasticsearch
```

3. 创建备份目录：

```powershell
New-Item -ItemType Directory -Force 'D:\ygh-backups\elasticsearch'
```

4. 导出快照卷：

```powershell
$archive = 'elasticsearch-snapshots-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.tar.gz'
docker run --rm --user 0 --entrypoint tar -v ygh-elasticsearch-snapshots:/source:ro -v 'D:\ygh-backups\elasticsearch:/backup' docker.elastic.co/elasticsearch/elasticsearch:8.19.17 -czf "/backup/$archive" -C /source .
Get-FileHash "D:\ygh-backups\elasticsearch\$archive" -Algorithm SHA256
```

5. 重新启动：

```powershell
docker start ygh-elasticsearch
```

**执行后的结果**：Windows 备份目录生成压缩包和可记录的 SHA256；容器重新变为 `healthy`。

**注意事项**：不能用复制 `ygh-elasticsearch-data` 数据卷代替官方快照。Elasticsearch 官方支持的备份方式是 Snapshot/Restore。

## 第八部分：停止、再次启动、重启和日志查看

### 第一步：正常停止

**在哪里操作**：Windows 本机 PowerShell。

先在 IDEA 停止会写入索引的服务，再输入：

```powershell
docker stop -t 60 ygh-elasticsearch
```

**执行后的结果**：返回 `ygh-elasticsearch`，容器状态变为 `Exited (0)`。数据卷、密码卷和快照卷不会删除。

### 第二步：再次启动

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
docker start ygh-elasticsearch
docker ps --filter 'name=^ygh-elasticsearch$' --format 'NAME={{.Names}} STATUS={{.Status}} PORTS={{.Ports}}'
```

**执行后的结果**：先显示 `health: starting`，随后变成 `healthy`。再次启动不需要重新创建索引或密码卷。

### 第三步：需要时重启

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
docker restart -t 60 ygh-elasticsearch
```

**执行后的结果**：容器完成正常停止后重新启动。

### 第四步：查看实时日志

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
docker logs --tail 200 -f ygh-elasticsearch
```

按 `Ctrl + C` 只退出日志查看，不会停止容器。

### 第五步：确认 Docker Desktop 重启策略

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
docker inspect ygh-elasticsearch --format 'RESTART={{.HostConfig.RestartPolicy.Name}}'
```

**执行后的结果**：显示 `RESTART=unless-stopped`。

## 第九部分：密码修改、恢复和常见故障处理

### 第一步：忘记或需要更换 elastic 密码

**在哪里操作**：Windows 本机 PowerShell和容器交互终端。

先确保容器正在运行，然后输入：

```powershell
docker exec -it ygh-elasticsearch /usr/share/elasticsearch/bin/elasticsearch-reset-password -u elastic -i
```

根据提示输入并确认新密码。

**执行后的结果**：工具提示密码重置成功。

随后必须：

1. 在客户密码管理器更新密码。
2. 按第三部分第五步重新写入 `ygh-elasticsearch-secret` 中的密码文件。
3. 在 IDEA `SearchApplication` 中更新 `YGH_ELASTICSEARCH_PASSWORD`。
4. 重启 Search 服务。

**重要说明**：`ELASTIC_PASSWORD_FILE` 是新数据卷第一次初始化时的引导密码。已有数据卷上仅修改密码文件不会自动修改 Elasticsearch 内部账号密码，必须执行重置工具。

### 第二步：处理密码文件不可读

**在哪里操作**：Windows 本机 PowerShell。

**故障输出**：

```text
File /run/secrets/elastic-password from ELASTIC_PASSWORD_FILE is not readable
```

**原因**：文件所有者不是容器用户 `1000`，或密码卷中没有该文件。

**处理位置**：Windows 本机 PowerShell。

先删除失败的容器但不删除卷：

```powershell
docker rm ygh-elasticsearch
```

然后重新执行第三部分第五步，确认输出 `1000:0 400`，再重新执行第四部分第一步创建容器。

### 第三步：处理密码文件权限错误

**在哪里操作**：Windows 本机 PowerShell，随后进入一次性配置容器。

**故障输出**：

```text
must have file permissions 400 or 600
```

**原因**：文件是 `440`、`644` 或其他权限。即使文件可以读取，Elasticsearch 也会拒绝不符合要求的权限。

按第三部分第五步进入临时容器并执行：

```bash
chown 1000:0 /secret/elastic-password
chmod 400 /secret/elastic-password
stat -c '%u:%g %a %n' /secret/elastic-password
```

确认后退出并重新创建正式容器。

### 第四步：处理 vm.max_map_count 错误

**在哪里操作**：Windows 本机管理员 PowerShell。

**故障输出**包含：

```text
max virtual memory areas vm.max_map_count
```

**处理位置**：Windows 本机管理员 PowerShell。

输入：

```powershell
wsl -d docker-desktop -u root sysctl -w vm.max_map_count=1048576
wsl -d docker-desktop -u root sysctl vm.max_map_count
docker start ygh-elasticsearch
```

### 第五步：处理退出码 137 或 OOM

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
docker inspect ygh-elasticsearch --format 'EXIT={{.State.ExitCode}} OOM={{.State.OOMKilled}} MEMORY={{.HostConfig.Memory}}'
docker stats --no-stream ygh-elasticsearch
```

**原因**：`EXIT=137` 或 `OOM=true` 通常表示容器或 Docker Desktop 内存不足。

**处理方法**：

1. 在 IDEA 停止暂时不使用的 Java 服务。
2. 停止 RocketMQ 或 Seata 等按需容器。
3. Docker Desktop 总内存至少调整为 4 GB。
4. 确认 Elasticsearch 容器内存是 `1280m`，JVM 堆仍为 `512m`。
5. 不要只把 JVM 堆调大；容器还需要堆外、文件缓存和线程内存。

### 第六步：处理 401 Unauthorized

**在哪里操作**：Windows 本机 PowerShell和 IntelliJ IDEA。

**原因**：密码输入错误、IDEA 中密码未同步，或已有数据卷使用的是旧密码。

先用交互方式验证：

```powershell
curl.exe -u elastic http://127.0.0.1:19200/
```

如果密码管理器中的密码仍返回 401，按本部分第一步重置密码。不能设置 `xpack.security.enabled=false` 来规避认证。

### 第七步：处理索引黄色或红色

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
curl.exe -u elastic "http://127.0.0.1:19200/_cluster/health?pretty"
curl.exe -u elastic "http://127.0.0.1:19200/_cat/shards?v"
```

1. 单节点环境索引副本数为 1 时通常是 `yellow`。本文两个项目索引已明确设置 `number_of_replicas=0`。
2. `red` 表示主分片不可用，不能继续启动业务服务。查看日志和磁盘空间，不要直接删除索引。

### 第八步：处理 Search 日志中的 index_not_found_exception

**在哪里操作**：Windows 本机 PowerShell和 IntelliJ IDEA。

**原因**：漏建 `knowledge-v1`、`knowledge-active` 或 `product-active`，或 IDEA 中索引变量拼写错误。

输入：

```powershell
curl.exe -u elastic "http://127.0.0.1:19200/_cat/indices?v"
curl.exe -u elastic "http://127.0.0.1:19200/_cat/aliases?v"
```

确认：

```text
knowledge-v1
knowledge-active -> knowledge-v1
product-active
```

缺失时回到第五部分逐项创建，不要把知识库别名改成 `knowledge-v1` 后绕过版本管理。

### 第九步：安全地验证快照恢复

**在哪里操作**：Windows 本机 PowerShell。恢复前在 IDEA 停止所有会访问 Search 的服务，并先创建当前快照。

不要直接覆盖现有索引。先把备份恢复为带 `restore-` 前缀的检查索引：

```powershell
curl.exe -u elastic -X POST "http://127.0.0.1:19200/_snapshot/ygh_fs_backup/这里替换为实际快照名/_restore?wait_for_completion=true" -H "Content-Type: application/json" -d '{"indices":"knowledge-v1,product-active","include_aliases":false,"include_global_state":false,"rename_pattern":"(.+)","rename_replacement":"restore-$1"}'
curl.exe -u elastic "http://127.0.0.1:19200/_cat/indices/restore-*?v"
```

**执行后的结果**：出现 `restore-knowledge-v1` 和 `restore-product-active`，文档数可与原索引比较。只有确认快照内容正确后，才能制定正式切换方案。

删除检查索引前再次确认名称只能是 `restore-` 开头：

```powershell
curl.exe -u elastic -X DELETE "http://127.0.0.1:19200/restore-knowledge-v1,restore-product-active"
```

**注意事项**：正式覆盖恢复涉及删除现有索引和切换别名，必须先获得客户确认并保留当前快照，不能把上面的检查恢复当作正式覆盖恢复。

### 第十步：最终交付检查

**在哪里操作**：Windows 本机 PowerShell和 IntelliJ IDEA。

依次确认：

```powershell
wsl -d docker-desktop -u root sysctl vm.max_map_count
docker image inspect docker.elastic.co/elasticsearch/elasticsearch:8.19.17 --format 'ID={{.Id}} ARCH={{.Architecture}} OS={{.Os}}'
docker ps --filter 'name=^ygh-elasticsearch$' --format 'NAME={{.Names}} STATUS={{.Status}} PORTS={{.Ports}}'
curl.exe -u elastic "http://127.0.0.1:19200/_cluster/health?pretty"
curl.exe -u elastic "http://127.0.0.1:19200/_cat/indices/knowledge-v1,product-active?v"
curl.exe -u elastic "http://127.0.0.1:19200/_cat/aliases/knowledge-active?v"
curl.exe -u elastic "http://127.0.0.1:19200/_snapshot/ygh_fs_backup/_all?pretty"
```

**合格结果**：

1. `vm.max_map_count=1048576`。
2. 镜像版本为 8.19.17、架构为 amd64/linux。
3. `ygh-elasticsearch` 为 `healthy`，Windows 19200 映射到容器 9200。
4. 集群为 `green`。
5. `knowledge-v1`、`product-active` 均存在。
6. `knowledge-active` 指向 `knowledge-v1`。
7. 至少一份业务索引快照状态为 `SUCCESS`。
8. IDEA `SearchApplication` 使用 `http://127.0.0.1:19200`、`elastic`、现场真实密码和项目固定索引名。
9. Product 等其他服务没有直接保存 Elasticsearch 密码。
10. 项目源码位于 Windows 本机 IDEA 工程目录，不在 Docker 容器、Docker 卷、WSL2 或 Rocky Linux 虚拟机中。
