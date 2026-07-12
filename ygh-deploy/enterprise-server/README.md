# 企业服务器部署

本目录是全量服务器编排基线。复制 `.env.example` 为不入库的 `.env`，从 Secret 管理系统注入所有数据库、JWT、内部签名、Nacos、模型和组件凭据，然后执行：

```bash
docker compose --env-file .env config
docker compose --env-file .env pull
docker compose --env-file .env up -d
```

生产环境应将 MySQL、Redis、Elasticsearch、RocketMQ、Nacos 和对象存储替换为高可用集群或云托管服务。应用镜像不可使用 `latest` 发布，必须指定不可变版本或 digest。
