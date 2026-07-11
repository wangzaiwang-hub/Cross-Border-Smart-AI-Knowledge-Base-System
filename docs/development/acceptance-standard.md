# 环境部署验收标准

## 1. 本机资源

- WSL2/Docker Desktop 内存上限不高于 3GB，处理器不高于 4，Swap 不高于 1GB。
- 未运行 Docker Desktop 时不应有 Docker Linux Engine 后台占用。
- 启动单一依赖 profile 后，Windows 可用内存不得低于 2GB。

## 2. 虚拟机 Docker

- `docker version` 客户端和服务端均成功返回。
- `docker compose version` 成功返回。
- Docker 服务开机自启且当前为 `active`。
- `/etc/docker/daemon.json` 为合法 JSON，日志轮转已启用。
- `docker info` 显示 cgroup v2 可用，SELinux 保持启用状态。

## 3. Core Profile

- `docker compose config` 返回 0。
- MySQL、Redis、Nacos 均为 `healthy`。
- MySQL 能执行 `SELECT 1`。
- Redis `PING` 返回 `PONG`。
- Nacos Server `/nacos/v3/admin/core/state/readiness` 与 Console `/v3/console/health/readiness` 返回成功。
- 三个组件总运行内存不突破规格上限的 120%。
- VM 可用内存保持不低于 500MB，根分区使用率不高于 80%。

## 4. 按需依赖 Profiles

- `mall-deps` 和 `ai-deps` 的 Compose 文件均通过语法验证。
- 虚拟机 `ai-data` 中的 PGVector 能启动，`vector` 扩展存在；停止后数据卷保留。
- 只允许绑定 VMware 网卡地址 `192.168.154.1`。
- 虚拟机能够访问已启动组件端口，其他不相关网络接口不得暴露这些端口。
- Elasticsearch、RocketMQ、Seata、PGVector 分别具有健康检查或可重复执行的探针命令。

## 5. 安全与证据

- 初始化 Git 后，真实 `.env`、私钥、密码或 API Key 必须保持在忽略范围外，不得被暂存。
- Secret 文件权限受限，输出日志中不打印 Secret 值。
- 修改前配置存在备份或变更记录。
- 验证证据写入 `docs/development/environment-acceptance-*.md`，仅保存命令、版本、状态和资源指标。

## 6. 验证命令

```bash
docker version
docker compose version
docker info
docker compose config
docker compose ps
docker stats --no-stream
free -h
df -h /
```
