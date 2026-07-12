# 企业服务器部署

本目录是全量服务器编排基线。复制 `.env.example` 为不入库的 `.env`，从 Secret 管理系统注入所有数据库、JWT、内部签名、Nacos、模型和组件凭据，然后执行：

```bash
docker compose --env-file .env config
docker compose --env-file .env pull
docker compose --env-file .env up -d
```

推荐使用不可变镜像版本进行发布：

```powershell
.\deploy.ps1 -Version 1.0.0
.\health-check.ps1
# 出现不可接受故障时回退到上一个已验证版本
.\rollback.ps1 -Version 0.9.0
```

编排包含 14 个 Java 服务以及 MySQL、Redis、Nacos、RocketMQ、Seata、PGVector 和 Elasticsearch。生产 Secret 必须由部署平台注入；`.env` 不得提交。首次初始化会由 MySQL init 脚本创建 Nacos 和各业务数据库。

生产环境应将 MySQL、Redis、Elasticsearch、RocketMQ、Nacos 和对象存储替换为高可用集群或云托管服务。应用镜像不可使用 `latest` 发布，必须指定不可变版本或 digest。
