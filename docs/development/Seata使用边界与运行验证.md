# Seata 使用边界与运行验证

商城主链路默认采用本地事务、Outbox、RocketMQ 幂等消费和对账补偿，不把模型调用、文件解析、Elasticsearch、PGVector 或长时间人工流程放入全局事务。Seata 只保留给确实需要同步强一致、可在数秒内结束且所有参与方均为关系数据库的短链路。

JDK 25 运行探针直接使用 Apache Seata 2.5.0 官方 `GlobalTransaction` API，与真实 TC 完成 `begin → status → commit`，不以端口探活代替客户端协议验证。API 依据：[Apache Seata 2.5 API Guide](https://seata.apache.org/docs/v2.5/user/api/)。

```powershell
docker compose --env-file .\ygh-deploy\constrained-dev\.env `
  -f .\ygh-deploy\constrained-dev\local-compose.yml `
  --profile mall-deps up -d seata
$env:YGH_SEATA_RUNTIME_TEST = "true"
$env:YGH_SEATA_SERVER = "127.0.0.1:8091"
.\mvnw.cmd -pl ygh-tests/ygh-compatibility-tests test `
  -Dtest=SeataRuntimeCompatibilityTest
```

该探针只创建无业务分支的短全局事务，用于验证 JDK、客户端与 TC 协议兼容性；业务服务仍不得因为“已有 Seata”而绕过 Outbox 或把跨服务长流程改造成同步全局事务。

## 2026-07-13 实测证据

- Seata Server：`apache/seata-server:2.5.0`，TC `127.0.0.1:8091` 健康。
- Java：Temurin JDK `25.0.3`，Spring Boot `4.0.7`，Seata Client `2.5.0`。
- TM 注册成功，服务端与客户端版本均为 `2.5.0`。
- 实际 XID：运行时动态生成；日志确认 `Begin new global transaction` 和 `commit status: Committed`。
- Maven：`SeataRuntimeCompatibilityTest` 1 test，0 failure，0 error，0 skipped。
