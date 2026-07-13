# 资源受限 DEV 部署

本目录用于 15.2GB Windows 开发机与 3.5GB Rocky Linux 虚拟机的场景化开发环境。它保留企业级组件边界，但不要求所有组件同时常驻。

## 运行位置

- 虚拟机 `192.168.154.10`：`core`（MySQL、Redis、Nacos）常驻；`ai-data`（PGVector）按需。
- Windows Docker Desktop：`mall-deps`（RocketMQ、Seata）或 `ai-deps`（Elasticsearch），二者互斥运行。
- Docker Desktop/WSL2 上限：3GB 内存、4 CPU、1GB Swap，且不随 Windows 自动启动。

## 虚拟机命令

```bash
cd /opt/ygh/constrained-dev
./scripts/status.sh
./scripts/health-check.sh
./scripts/deploy-ai-data.sh
./scripts/stop-ai-data.sh
./scripts/backup-data.sh
./scripts/cleanup-images.sh          # 只预览
./scripts/cleanup-images.sh --apply  # 仅清理 dangling images
```

所有停止脚本均保留数据卷。禁止使用 `docker compose down -v`。

## Windows 命令

使用场景脚本启动。它会阻止两个 profile 同时运行，也会在检测到其他项目容器或内存不足时拒绝启动：

```powershell
Set-Location F:\跨境智汇AI知识库系统\ygh-deploy\constrained-dev
.\scripts\local-profile.ps1 -Mode mall-deps
.\scripts\local-profile.ps1 -Mode ai-deps
.\scripts\local-profile.ps1 -Mode status
.\scripts\local-profile.ps1 -Mode stop
```

在 Docker Desktop 3GB 内存上限下联调 AI 时，Elasticsearch 与全部 Java 服务无法同时常驻。保留
`gateway/auth/user/system/product/order/knowledge/search/ai`，并停止
`inventory/wallet/training/notification/admin` 后再启动 `ai-deps`；切换模块时重新启动对应服务。

`.env` 是本机密钥文件，不得提交、复制到文档或粘贴到日志。

## WSL 与 Docker Desktop

Docker Desktop 运行且已启用 Ubuntu 集成时，禁止执行 `wsl --terminate Ubuntu`。该操作会直接杀掉 Docker 的发行版代理并触发 `DockerDesktop/Wsl/ExecError`。

需要冷重启 WSL 时必须按以下顺序：

```powershell
docker desktop stop
wsl --shutdown
wsl -d Ubuntu --exec true
docker desktop start
```

不得使用 `wsl --unregister`，也不得删除 Ubuntu 或 `docker-desktop` 发行版。
