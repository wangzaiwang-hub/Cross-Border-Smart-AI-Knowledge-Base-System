# 开发环境部署验收记录（2026-07-11）

## 1. 验收结论

Rocky Linux 10 虚拟机的 Docker 基础设施与核心数据组件已部署成功。MySQL、Redis、Nacos 均为 `healthy`，Nacos 管理员初始化与登录验证通过；PGVector 已完成启动、扩展版本、宿主机连通性验证后按场景停止，数据卷保留。

Windows 重启后，WSL2 与 Docker Desktop 已完成运行验收：Docker Engine 实际识别 4 CPU、约 3GB 内存和 1GB Swap，Docker Desktop 保持禁止自启动。`mall-deps` 与 `ai-deps` 已分别实机验证，未同时运行。

## 2. 已验证环境

| 项目 | 验收结果 |
|---|---|
| 虚拟机服务地址 | `192.168.154.10/24` 可从 Windows 访问 |
| Windows Java | Temurin JDK 25.0.3 LTS 已安装，用户 `JAVA_HOME` 已切换；原 Java 21 保留但不再作为默认开发基线 |
| Docker Engine | 29.6.1，systemd 已启用 |
| Docker Compose | 5.3.1 |
| SELinux | `Enforcing`，未为规避容器问题而关闭 |
| MySQL | `mysql:8.4.10`，端口 3306，健康检查通过 |
| Redis | `redis:8.4.4`，端口 6379，认证与 PING 通过 |
| Nacos | `nacos/nacos-server:v3.1.1`，端口 8080/8848/9848，Server 与 Console readiness 通过 |
| Nacos 管理员 | 初始化成功，登录 API 验证通过；密码未写入本记录 |
| PGVector | `pgvector/pgvector:0.8.5-pg17-bookworm`，端口 5432，扩展版本 `0.8.5` |
| RocketMQ | 5.3.1，NameServer 与 Broker healthy；`mqadmin clusterList` 可识别 `YghDevCluster` |
| Seata | 2.5.0，TC 端口 8091 healthy；JVM 堆已限制为 256MB、直接内存 128MB |
| Elasticsearch | 8.19.17，单节点集群 green；虚拟机到 9200 可达 |
| Windows 场景保护 | `local-profile.ps1` 强制 profile 互斥，并在其他项目容器运行或内存不足时拒绝启动 |
| 优雅停止 | RocketMQ wrapper 转发 TERM 到完整进程组；RocketMQ 退出码 0，Seata/Elasticsearch 为正常 TERM 退出码 143，全部 `OOMKilled=false` |
| WSL 集成恢复 | 验收中直接终止 Ubuntu 曾中断 Docker 代理；已按“先停 Docker、再 shutdown WSL、先启动 Ubuntu、再启动 Docker”恢复并验证 Ubuntu 内 Docker Client/Server 均为 29.1.3 |
| 防火墙 | 虚拟机仅允许宿主机 `192.168.154.1/32` 访问已声明端口 |
| Secret | 本机与虚拟机 `.env` 权限收紧，Git 忽略；验收输出未记录密钥 |

## 3. 资源快照

核心组件运行、PGVector 停止时：虚拟机总内存约 3.5GiB，可用内存约 1.0GiB，2GiB Swap 仅使用约 8MiB；根分区使用率约 49%。

PGVector 运行时容器约占 39MiB；Nacos 约占 641MiB，JVM 堆固定为 384MiB、容器上限为 768MiB；MySQL 约 195MiB；Redis 约 11MiB。该结果支持把 PGVector 放在虚拟机按需运行，但不支持把 RocketMQ、Seata、Elasticsearch 和全部 Java 服务同时塞入该虚拟机。

Windows 单独运行商城依赖时，RocketMQ Broker、NameServer 与 Seata 合计约 1GB，Windows 可用内存约 2.2GB。单独运行 Elasticsearch 时容器约占 1.25GiB，Windows 可用内存约 2.0GB。两组都符合本机 3GB WSL2 上限，但没有足够余量同时运行。

Docker Desktop 中原有 CheersAI/Dify 容器已在验收后恢复。这些容器单独运行时已使用约 2.2GiB WSL 内存和约 360MiB Swap，因此本项目脚本会拒绝在它们运行时启动 YGH profile；需先停止原项目容器。

## 4. 场景运行规则

- 常驻：`core`（MySQL、Redis、Nacos）。
- AI 数据：运行 `scripts/deploy-ai-data.sh` 启动 PGVector；结束后运行 `scripts/stop-ai-data.sh`，数据卷不会删除。
- 商城重型依赖：Windows Docker Desktop 的 `mall-deps`（RocketMQ、Seata），只在商城场景启动。
- AI 重型依赖：Windows Docker Desktop 的 `ai-deps`（Elasticsearch），只在 AI 场景启动。
- `mall-deps` 与 `ai-deps` 不同时运行；Docker Desktop 不用时退出。
- 本机场景统一通过 `scripts/local-profile.ps1` 启停，禁止绕开资源和外部容器检查。

## 5. 待完成项

1. Java 服务模块生成后，再按 `mall`、`ai-apps`、`training` 场景补充服务级资源实测。
2. 创建根 Maven 工程时一并生成并锁定 Maven Wrapper；当前不依赖未安装的系统级 `mvn`。
3. Java 服务镜像形成后补齐企业服务器应用部署清单和生产容量参数。
