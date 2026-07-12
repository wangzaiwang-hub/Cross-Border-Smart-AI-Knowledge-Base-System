# 覆盖率与公共 API 兼容门禁

> 对应任务：`BE-0235`  
> 生效日期：2026-07-11  
> 适用范围：根 Maven Reactor 中所有具有生产字节码的模块，以及七个 `ygh-common-*` 公共 JAR。

## 1. 覆盖率阻断

- 根 POM 固定 JaCoCo Maven Plugin `0.8.15`，在测试前挂载 Agent，在 `verify` 阶段生成报告并执行检查。
- 每个存在 `target/classes/**/*.class` 的模块必须产生非空 `target/jacoco.exec`。若测试被跳过、Agent 未生效或执行数据丢失，`maven-antrun-plugin` 在 JaCoCo 报告与检查之前直接终止构建。
- 当前公共基线按模块 `BUNDLE` 阻断：行覆盖率不低于 `70%`，分支覆盖率不低于 `60%`。
- 纯聚合 POM 和仅含测试源码的契约测试模块没有生产字节码，不伪造覆盖率数据，也不受执行数据存在性检查影响。
- 金额、库存、订单、权限、幂等和培训规则的关键分支 `90%` 门禁在对应业务模块落地时单独提高，不能用当前公共基线替代。

反向验证命令：

```powershell
.\mvnw.cmd -pl ygh-common/ygh-common-core clean verify -DskipTests
```

该命令必须失败，并包含 `Production classes exist but JaCoCo execution data is missing or empty`。如果成功，表示覆盖率门禁可被绕过，禁止合并。

## 2. 公共 API 兼容门禁

`ygh-tests/ygh-api-compatibility-tests` 在每次 Reactor 测试中扫描下列模块：

- `ygh-common-core`
- `ygh-common-web`
- `ygh-common-security`
- `ygh-common-mybatis`
- `ygh-common-redis`
- `ygh-common-mq`
- `ygh-common-test`

扫描器同时支持 Reactor 类目录和打包 JAR，记录公开或受保护的类型、构造器、方法和字段，排除 synthetic 与 bridge 成员。当前已审查基线为 `577` 条签名，规范化 SHA-256 为 `147ef7fade1c5acbe77b4442beaf879adf0eb32bece5f5d77b4315949e200d67`。

2026-07-13 集中测试审查新增 29 条、删除 0 条签名。新增内容属于跨服务复用的稳定公共能力：`DomainEventPublisher`、`JdbcOutboxDispatcher`、`RocketMqDomainEventPublisher`、`InternalServiceSignature`、`AuditLoggingFilter` 和 `YghFeignAutoConfiguration`。这些类型分别承担业务事件一致性、内部服务 HMAC、统一审计和 Feign 上下文传播，必须保持 public 才能由业务模块或 Spring 容器使用，因此纳入兼容基线；未通过缩小扫描范围绕过门禁。

基线文件位于：

```text
ygh-tests/ygh-api-compatibility-tests/src/test/resources/public-api-baseline.txt
```

每次测试还会生成 `target/public-api-current.txt`。发生差异时测试必须分别列出 `REMOVED` 和 `ADDED`，禁止只凭总数或散列值判断。

## 3. 基线变更流程

1. 先确认变更是否确有业务需求，优先保持二进制和源码兼容。
2. 运行测试取得 `public-api-current.txt`，逐条审查新增、删除和签名变化。
3. 删除或修改既有签名必须提供迁移方案、版本策略和调用方影响说明；不能把更新基线当成修复。
4. 经 Reviewer 同意后才允许替换基线文件，并同步更新签名数量与 SHA-256 常量。
5. 重新执行模块测试和全 Reactor `clean verify`，保留失败与成功证据。

## 4. 2026-07-11 验证证据

- API 兼容模块测试：2 项通过，包含受保护嵌套类型与成员回归测试。
- 反向门禁：跳过 `ygh-common-core` 测试时，构建在 `require-coverage-execution-data` 按预期失败。
- 全 Reactor：13 个模块、176 项测试，0 失败、0 错误、0 跳过，`clean verify` 成功。
- 本机 `mall-deps`、`ai-deps` 和虚拟机 `core`、`ai-data` 四组 Compose 均通过 `config --quiet`，验证未改变容器运行状态。
