# 每日开发记录

- 日期：2026-07-11
- 作者：Codex / 项目协作
- 岗位：后端基础设施与架构
- 模块：环境台账、Maven 根工程、公共契约
- 分支：仓库尚未初始化 Git
- Commit ID：无

## 1. 今日目标与完成度

- 完成 Windows、WSL2、Docker Desktop、Rocky Linux VM 和中间件的脱敏实测台账。
- 建立后端接口、DTO、错误码、权限码、消息事件和前端联调清单。
- 建立后端交付技术规格与量化验收标准。
- 创建 JDK 25 / Maven 3.9.16 根工程、企业 BOM 和公共模块骨架。
- 以测试先行方式完成统一响应、错误码和分页请求基础实现。

## 2. 设计与关键决策

1. Maven Wrapper 固定 3.9.16，并记录发行包 SHA-256。
2. 根 POM 不导入以自身为父的子 BOM；各副项目聚合 POM 导入 `ygh-dependencies`，避免 Maven 模型解析环。
3. 初始 Boot 4.1.0 与 Alibaba 官方矩阵存在偏差；经项目负责人确认，调整为 Boot 4.0.7，仍保留独立兼容性门禁且不关闭兼容性检查。
4. 虚拟机不安装全局 Maven；本机构建、容器运行，服务继续按场景 profile 切换。

## 3. 代码变更

- 新增根 `pom.xml`、Maven Wrapper、`.mvn` 配置和 `.editorconfig`。
- 新增 `ygh-dependencies` 企业 BOM。
- 新增 `ygh-common-core`、`ygh-common-web` 聚合结构。
- 实现 `ApiResponse`、`ErrorCode`、`PageRequest`、`PageResponse`、`BusinessException`。

## 4. 接口、数据库、事件或配置变更

- 统一响应字段固定为 `code/message/data/traceId/timestamp`。
- 分页固定为一基页码，默认 20，最大 100。
- ID 使用字符串、金额使用十进制字符串、时间使用带时区 ISO 8601。
- 本日未创建数据库表和消息 Topic。

## 5. 验证命令、用例和结果

### 5.1 环境健康

```powershell
ssh vm-ygh "cd /opt/ygh/constrained-dev && ./scripts/status.sh && ./scripts/health-check.sh"
```

结果：MySQL、Redis、Nacos healthy，输出 `CORE_HEALTH_OK`。

### 5.2 Maven Wrapper

```powershell
.\mvnw.cmd -version
```

结果：Maven 3.9.16，Temurin Java 25.0.3，UTF-8。

### 5.3 TDD 红灯

```powershell
.\mvnw.cmd -pl ygh-common/ygh-common-core -am test
```

第一次按预期失败：测试引用的 `ApiResponse`、`ErrorCode`、`PageRequest` 尚未实现，共 8 个编译错误。

### 5.4 TDD 绿灯

同一命令在最小实现后返回 0：5 tests，0 failures，0 errors，0 skipped。

### 5.5 Web 异常契约

```powershell
.\mvnw.cmd -pl ygh-common/ygh-common-web -am test
```

先得到缺少 `GlobalExceptionHandler` 和 `TraceIdResolver` 的预期红灯；最小实现后返回 0。公共核心 5 个测试、公共 Web 2 个测试全部通过。

### 5.6 当前全量构建

```powershell
.\mvnw.cmd clean verify
```

结果：5 个 Reactor 模块全部 `SUCCESS`；7 tests，0 failures，0 errors，0 skipped；生成两个公共模块 JAR 和 JaCoCo 报告。

## 6. 问题、风险和处理计划

- Nacos 使用约 690.9MiB/768MiB，后续 Java 服务必须场景化启动。
- Spring Cloud Alibaba 与 Boot 4.1 的官方矩阵存在缺口，需建立兼容性测试模块。
- 根目录尚未初始化 Git，暂时无法提供 Commit ID 和 Secret 暂存检查证据。

## 7. 下一步

- 完成 `ygh-common-web` 的统一异常与 traceId 处理。
- 创建 Gateway、Auth、User 的最小可运行骨架。
- 建立认证接口明细、DTO、错误码和 OpenAPI。

## 8. Spring Boot 4.0.7 调整与回归

项目负责人批准将 Spring Boot 从 4.1.0 调整为 4.0.7。Spring Cloud 2025.1.2、Spring Cloud Alibaba 2025.1.0.0 和 JDK 25 保持不变。

新增 `ygh-tests/ygh-compatibility-tests`，固定解析 Gateway、OpenFeign、Nacos Discovery/Config、Sentinel、RocketMQ Stream 和 Seata Starter，并对 8 个代表性自动配置类执行 JDK 25 链接测试。

最终验证：

```powershell
.\mvnw.cmd clean verify
```

结果：7 个 Reactor 模块全部成功；15 tests，0 failures，0 errors，0 skipped。最终依赖解析为 Boot 4.0.7、Spring Framework 7.0.8、Spring Cloud 5.0.2、Alibaba 2025.1.0.0、RocketMQ 5.3.1、Seata 2.5.0。

保留风险：RocketMQ 传递依赖的旧 Javassist POM产生警告；Seata 的旧 Spring 版本声明已被企业 BOM覆盖，需要在真实运行时继续验证。

## 9. common-security 第一批能力

- 新增 `ygh-common-security` Maven 子模块并纳入 Reactor。
- 新增不可变 `CurrentUserPrincipal`：用户 ID 使用字符串，角色和权限采用防御性复制及精确匹配。
- 新增 `ResourceAccessGuard`：资源本人或持有显式跨用户权限的主体可以访问；仅有 `ADMIN` 角色不能绕过所有权校验。
- 测试先行：先确认缺少实现时编译失败，再补最小实现。
- `mvnw.cmd -pl ygh-common/ygh-common-security -am test` 通过：common-core 5 项、common-security 6 项，共 11 项测试零失败。
- 随后执行全工程 `mvnw.cmd clean verify`：8 个 Reactor 模块全部成功，21 项测试零失败。
- 增加运行时 `@RequiresPermission`、领域 `ResourceOwnershipChecker` 扩展点，以及 Token 黑名单、用户级会话撤销和账号启用状态的存储无关契约。
- 两批契约均先执行预期失败测试再实现；common-security 当前 9 项测试通过。
- 新增稳定 `PermissionDeniedException`、无凭据字段的 `SecurityAuditEvent`、决策枚举和发布接口；common-security 当前 11 项测试通过。
- 最终全工程 `mvnw.cmd clean verify` 再次通过：8 个 Reactor 模块、26 项测试、0 失败、0 错误、0 跳过。

## 10. Git 门禁与 common-core 契约补齐

- 初始化本地 Git 仓库，主分支为 `main`；新增 Git 协作规范。
- 新增暂存区/工作区 Secret 扫描器；中文路径扫描通过，并用临时假密钥验证扫描器能够返回失败，随后删除测试夹具。
- 原始根目录 `.doc/.docx`、真实 `.env`、私钥和运行数据已纳入忽略规则。
- 测试先行补齐 `ExternalId`、`Money`、`StableCodeEnum`、领域事件 Envelope、幂等请求上下文与结果状态模型；独立审查指出 JSON 往返和类型化事件头仍需补齐，因此 `BE-0205/0206` 暂不标记完成。
- common-core 18 项测试通过；串行执行全 Reactor `clean verify` 后 8 个模块全部成功，共 39 项测试、0 失败、0 错误、0 跳过。
- 曾因两个代理并发执行 `clean verify` 互相删除共享 `target/classes` 出现一次伪失败；已串行复测通过，并将“禁止共享工作区并发 clean”加入项目约束。
- 根据 Reviewer 意见补充 Jackson 3 生产配置与往返测试：外部 ID 为 JSON 字符串，金额两位小数字符串，币种使用稳定 code，`OffsetDateTime` 保留原始偏移。
- 领域事件重构为 `DomainEvent<T>`、独立 `EventMetadata` 和受控 `VersionedDomainEvent<T>`；业务 DTO 走不可变 marker 工厂，动态 Map 走类型安全工厂并递归冻结 Map/List/Set，禁止数组载荷。
- Reviewer 发现并阻断了初版泛型深复制可能导致的 `ClassCastException`；补充 LinkedHashMap 回归与构造入口测试后复核通过。
- 最终串行 `mvnw.cmd clean verify` 通过：8 个 Reactor 模块、46 项测试、0 失败、0 错误、0 跳过。

## 11. common-web 校验与安全错误闭环

- 请求体、方法参数/路径参数和 `ConstraintViolationException` 三类 Bean Validation 错误统一返回 400/`VALIDATION_ERROR`。
- 字段错误包含字段定位和消息，但 `rejectedValue` 永久清空，避免密码、Token、金额原值和个人数据泄漏。
- 401、403、429、503 强制使用公共默认消息；429 返回 `Retry-After: 1`。
- 新增 Servlet `ApiAuthenticationEntryPoint` 与 `ApiAccessDeniedHandler`，过滤器链错误同样写入标准 `ApiResponse` JSON。
- Test-Author 增加 Spring 7 真实验证对象和 Servlet 安全入口测试；common-core 21 项、common-web 15 项测试通过，Reviewer 复核允许完成 `BE-0212/0213`。
- 全 Reactor `mvnw.cmd clean verify` 通过：8 个模块、55 项测试、0 失败、0 错误、0 跳过。

## 12. common-web 安全请求日志

- 新增结构化 `RequestLogEvent`/`RequestLogSink` 与不读取 query/body 的 Servlet 请求日志过滤器。
- 仅记录 traceId、requestId、method、纯 path、status、duration 和脱敏 User-Agent；Authorization、Cookie、密码、Token、Secret、完整地址和请求体均不进入事件。
- 关联 ID 限制为 `[A-Za-z0-9._-]` 且不超过 128 字符；User-Agent 清除控制字符、限制 256 字符，含敏感词时整值替换。
- 默认结构化日志 Sink 失败不会破坏正常响应，也不会覆盖原始业务异常。
- 使用 Boot AutoConfiguration 和 `FilterRegistrationBean` 自动注册，顺序固定为 `HIGHEST_PRECEDENCE + 10`，确保早于 Spring Security 短路响应。
- common-web 27 项日志与自动配置测试通过且无 unchecked 编译警告；Reviewer 复核允许完成 `BE-0214`。
- 全 Reactor `mvnw.cmd clean verify` 通过：8 个模块、67 项测试、0 失败、0 错误、0 跳过。

## 13. GitHub 阶段灾备

- GitHub `origin` 固定为 `wangzaiwang-hub/Cross-Border-Smart-AI-Knowledge-Base-System`。
- 远程仓库推送前为空；本地已通过全量构建、67 项测试、Secret 扫描和差异检查。
- 已将阶段基线提交 `91e0a0b` 推送到远程 `main`，并设置本地 `main` 跟踪 `origin/main`。
- 后续开发转入 `feature/backend-p02-foundation`，完成阶段门禁后通过 Pull Request 合并，不再直接在远程主分支持续开发。

## 14. common-web OpenAPI 公共契约

- 按 Spring Boot 4.0.x 官方兼容矩阵引入 springdoc-openapi 3.0.3；企业 BOM 同时约束 common、WebMVC API/UI 与 WebFlux API/UI，各服务后续按运行模型选择 Starter。
- `ygh-common-web` 仅依赖 `springdoc-openapi-starter-common`，通过 Boot AutoConfiguration 提供公共 `OpenApiCustomizer`，不强制服务暴露 Swagger UI。
- 注册 `bearerAuth` HTTP Bearer/JWT 安全方案，但不设置全局安全要求，避免注册、登录、健康检查等公开接口被错误标记为必须认证。
- 注册统一 `ApiResponse`、`ValidationErrorResponse` 和 `FieldValidationError` Schema，以及 400、401、403、404、409、429、503、500 可复用响应。
- 429 契约声明 `Retry-After`，`X-Request-Id` 声明实际 allowlist `[A-Za-z0-9._-]{1,128}`；所有公共 Schema 显式标记必填字段。
- Test-Author 先补契约门禁，Reviewer 在补齐响应、Header、必填字段和正则后静态复核通过，允许完成 `BE-0215`。
- 模块验证 `mvnw.cmd -pl ygh-common/ygh-common-web -am test` 通过：common-core 21 项、common-web 30 项，共 51 项测试，0 失败、0 错误、0 跳过且无编译告警。
- 最终串行执行 `mvnw.cmd clean verify`：8 个 Reactor 模块全部成功，共 70 项测试，0 失败、0 错误、0 跳过。

## 15. common-mybatis 审计与分页基础

- 新增标准 Maven 子模块 `ygh-common-mybatis`，纳入 `ygh-common` 聚合与企业 BOM。
- 官方 Boot 4 专用依赖固定为 MyBatis-Plus 3.5.16，并显式引入拆分后的 JSqlParser 分页模块。
- Test-Author 先建立审计字段、MetaObjectHandler、分页适配和 Boot 自动配置测试；缺少生产类时测试编译按预期失败，再进入实现。
- `AuditableEntity` 统一 `createdBy/createdAt/updatedBy/updatedAt`；审计人使用字符串稳定 ID，时间使用 UTC `Instant`。
- 普通插入强制覆盖调用方提供的四个审计字段；`createdBy/createdAt` 使用 `updateStrategy=NEVER`，防止更新操作篡改创建审计。
- 在线服务必须显式提供 `AuditorProvider`，公共模块不静默回退为 `SYSTEM`；定时任务需要显式使用系统审计人。
- `MybatisPageAdapter` 复用 common-core 一基分页协议，将 Entity 页映射为 DTO `PageResponse`，不暴露数据库 Entity。
- 分页 Guard 要求一个且仅一个 `PaginationInnerInterceptor`、`maxLimit` 为 1 至 100 且 `overflow=false`；缺失、零值、重复和越界配置均阻止启动。
- 新增 H2 MySQL 模式真实 DataSource、SqlSession、BaseMapper 插入/更新/分页测试，证明 Boot 4.0.7 与 MyBatis-Plus 3.5.16 运行链可用。
- Reviewer 首轮阻断了可伪造创建审计和默认 SYSTEM 掩盖身份接入的问题；修复并补充真实 SQL、分页冲突测试后最终复核无阻断。
- 模块验证 `mvnw.cmd -pl ygh-common/ygh-common-mybatis -am test`：common-core 21 项、common-mybatis 23 项，共 44 项测试通过。
- 全 Reactor `mvnw.cmd clean verify`：9 个模块、93 项测试，0 失败、0 错误、0 跳过。
- 本机 `mall-deps`、`ai-deps` 及虚拟机 `core/ai-data` Compose 配置均通过 `docker compose config --quiet`，未启动或停止容器。

## 16. Flyway 前向数据库迁移门禁

- Spring Boot 4.0.7 的 `spring-boot-starter-flyway` 解析 Flyway Core 11.14.1；具体 MySQL/PostgreSQL 扩展留给持库 Service 引入。
- Test-Author 建立命名、版本、重复、路径穿越、嵌套目录、自定义 Location、Repeatable、Undo、Java Migration、checksum 变化、历史缺失、历史插入和危险配置测试。
- 公共主迁移策略在实际 `migrate` 前检查最终配置与 Flyway 真实解析结果，迁移后执行官方 `validate`，形成 fail-closed 链路。
- 只允许 `classpath:db/migration/V<正整数>__<lower_snake_case>.sql`，禁止 out-of-order、生产 clean、自动 repair 和修改已应用迁移。
- 回滚采用应用回滚、前向修复或已演练备份恢复；破坏性 DDL 采用 Expand → Migrate → Contract。
- 模块 Reactor 验证通过：common-core 21 项、common-mybatis 51 项，0 失败、0 错误、0 跳过。
- Reviewer 最终复核未发现 P0/P1 阻断，允许完成 `BE-0231`。
- 全 Reactor `clean verify` 通过：9 个模块、121 项测试，0 失败、0 错误、0 跳过。
- 本机 `mall-deps`、`ai-deps` 与虚拟机 `core`、`ai-data` 四组 Compose 配置均通过 `config --quiet`，本次验证未改变容器运行状态。

## 17. common-redis Key、TTL 与 owner 安全锁

- 新增标准 Maven 子模块 `ygh-common-redis`，纳入 `ygh-common` 聚合和企业 BOM。
- Test-Author 先建立 Key、敏感标识散列、TTL、锁 owner、Lua、Boot 自动配置和真实 Redis 并发测试；生产类缺失时编译按预期失败。
- Key 固定为 `ygh:{env}:{service}:{business}:{identifier}`，严格限制字符和长度；低熵敏感标识支持带至少 32 字节 Secret pepper 的 HMAC-SHA-256。
- `cacheTtl` 只用于可重建缓存的对称抖动；`minimumRetentionTtl` 用于黑名单、撤销和幂等最短保留期，只增不减；显式拒绝超过 10 年和溢出输入。
- 短租锁以 `SET NX PX` 获取，以 owner 比较 Lua 原子续租/释放；租约限定 1 秒至 5 分钟，owner 使用 192 bit 安全随机数。
- `RedisLockHandle` 的日志输出和 Jackson JSON 均不暴露 owner capability。
- Boot 自动配置显式排在 `DataRedisAutoConfiguration` 之后，真实 Bean 链测试证明不会因条件评估过早而静默缺失。
- Testcontainers Redis 8.4.4 验证 NX/PX、错误 owner、正确续租释放、过期重入旧 owner 不删新锁及 16 并发仅一个成功。
- 虚拟机 Redis 8.4.4 额外实测输出 `REDIS_OWNER_RENEW_RELEASE_OK`，测试 Key 已删除；本机 Testcontainers 容器测试后均已清理。
- 模块验证 19 项测试通过，0 失败、0 错误、0 跳过且无编译警告。
- Reviewer 四项 P1 修复后复审通过，未发现剩余 P0/P1，允许完成 `BE-0232`。
- Redis 短租锁没有 Fencing Token；库存与资金仍必须使用数据库条件更新或乐观锁，禁止把 Redis 锁作为唯一正确性屏障。
- 全 Reactor `clean verify` 通过：10 个模块、140 项测试，0 失败、0 错误、0 跳过。
- 本机 `mall-deps`、`ai-deps` 与虚拟机 `core`、`ai-data` 四组 Compose 配置再次通过 `config --quiet`。

## 19. common-test 公共测试基础设施

- 新增标准 Maven 子模块 `ygh-common-test`，企业 BOM 固定 test scope，避免进入生产依赖图。
- `MutableTestClock` 使用共享 AtomicReference，支持时区 View、正向推进和显式重置；8 线程各 250 次推进结果精确。
- `TestDataFactory` 生成确定性 `test-*` ID、`test_user_*` 用户名、`example.test` 邮箱和“测试用户”显示名；类型构造器拒绝生产样式身份。
- `YghTestContainerFactory` 固定 Redis 8.4.4、MySQL 8.4.10、PGVector 0.8.5-pg17-bookworm，与部署镜像一致并设置内存上限和启动超时。
- 数据库凭据每个 Fixture 动态生成且诊断输出脱敏；`JdbcContainerFixture` 支持 start/AutoCloseable，启动前禁止读取 JDBC URL。
- `ygh-common-redis` 改为 test scope 依赖 common-test，并通过公共工厂完成真实 Redis 容器锁集成测试和自动清理。
- Reviewer 修复 BOM scope 泄漏风险并补 Clock 并发证据后，最终未发现 P0/P1，允许完成 `BE-0234`。
- common-test 8 项测试与 common-redis 19 项真实容器测试通过；依赖树确认 common-test 在 Redis 中为 test scope。
- MySQL、PGVector 的真实 JDBC/扩展连通测试明确保留到 `BE-1202`，不在本阶段伪称完成。
- 全 Reactor `clean verify`：12 个模块、174 项测试，0 失败、0 错误、0 跳过。
- 本机 `mall-deps`、`ai-deps` 与虚拟机 `core`、`ai-data` 四组 Compose 配置再次通过 `config --quiet`。

## 18. common-mq Envelope、幂等消费与死信内核

- 新增标准 Maven 子模块 `ygh-common-mq`，纳入 `ygh-common` 聚合和企业 BOM；直接声明 common-core、Jackson Annotation 与 Spring JDBC 依赖。
- 收紧 `EventMetadata` 并增加 `MqEnvelopePolicy`，统一 eventId/type/traceId/producer/businessKey 长度和安全字符，毒元数据在 Broker 前失败。
- `MqMessageHeaders` 输出固定 8 个稳定头，时间保留原始偏移并固定秒级格式，不包含 Payload 或凭据。
- `IdempotentMessageConsumer` 实现 CLAIMED/DUPLICATE/IN_PROGRESS、有限重试、非重试失败、受管死信和基础设施故障状态机。
- 每次 Claim 使用 192 bit 唯一 owner；Owner 日志与 Jackson JSON 脱敏；InterruptedException 恢复中断。
- 新增 `JdbcMessageConsumptionStore`：业务操作与 SUCCEEDED 同本地事务，死信记录与 DEAD_LETTERED 同事务，所有更新比较 owner。
- H2 MySQL 模式真实验证 10 并发 Claim、10 并发投递单一业务效果、异常回滚、成功提交、租约过期重领、stale owner 拒绝、死信原子性和提交失败回滚。
- Reviewer 发现并阻断唯一键冲突/并发释放误 ACK、事务异常误分类、双时钟租约和 claim/release/DLQ 基础设施异常逸出；逐项修复并补回归。
- RocketMQ ACK/RECONSUME、deliveryAttempt、重试延迟和 Broker DLQ 明确归入 `BE-0542`，本阶段不伪称真实 Broker 链路已完成。
- Reviewer 最终复审未发现剩余 P0/P1，允许完成 `BE-0233`。
- 模块 Reactor：common-core 22 项、common-mq 25 项，共 47 项测试通过。
- 全 Reactor `clean verify`：11 个模块、166 项测试，0 失败、0 错误、0 跳过。
- 本机 `mall-deps`、`ai-deps` 与虚拟机 `core`、`ai-data` 四组 Compose 配置再次通过 `config --quiet`。

## 20. 覆盖率与公共 API 兼容门禁

- 根构建引入 JaCoCo `0.8.15` 的报告与阈值检查，公共模块最低行覆盖率为 70%、分支覆盖率为 60%。
- 增加执行数据 fail-closed 检查：模块存在生产 class 但 `jacoco.exec` 缺失或为空时，在 JaCoCo 检查前终止构建。
- 反向执行 `mvnw.cmd -pl ygh-common/ygh-common-core clean verify -DskipTests`，构建按预期失败并输出缺少 JaCoCo 执行数据，证明不能通过跳过测试绕过门禁。
- 新增 `ygh-api-compatibility-tests`，固化七个公共 JAR 共 490 条公开/受保护签名，同时支持类目录和 JAR 扫描。
- API 差异会精确输出 `REMOVED/ADDED`；测试另覆盖受保护嵌套类型和成员，防止扫描盲区。
- Reviewer 首轮提出执行数据绕过、hash-only 无差异明细和遗漏 protected API 三项 P1，均已修复并补充验证。
- 全 Reactor `clean verify`：13 个模块、176 项测试，0 失败、0 错误、0 跳过。
- 本机 `mall-deps`、`ai-deps` 与虚拟机 `core`、`ai-data` 四组 Compose 配置均通过 `config --quiet`，未改变容器运行状态。

## 21. Gateway 标准模块与 WebFlux 边界

- 根 Reactor 新增 `ygh-platform` 平台副项目，并建立标准 Maven 可运行模块 `ygh-gateway`。
- Gateway 使用 Spring Cloud Gateway Server WebFlux 5.0.2、Actuator 和 Boot Maven Plugin 4.0.7 可执行 JAR，不依赖含 MVC/Servlet 的 `ygh-common-web`。
- Test-Author 先建立 bootstrap、配置、响应式 classpath 和真实上下文测试；生产类缺失时测试编译按预期失败。
- 自动化断言 `DispatcherHandler` 存在，`DispatcherServlet` 与 `jakarta.servlet.Servlet` 不存在，防止依赖漂移把网关切回阻塞栈。
- 实际 Reactive ApplicationContext 在随机端口启动，Gateway WebHandler 存在，并完成 Netty 优雅关闭。
- 首轮将 Nacos/Sentinel 提前放入脚手架时发现第三方全局线程导致测试 JVM 无法及时退出；依照任务边界移至 `BE-0303/BE-0308` 接入，脚手架验证恢复可重复退出。
- 模块 Reactor `verify`：6 个模块、36 项测试通过；Gateway 可执行 JAR 重打包成功。

## 22. Gateway 路由与 Nacos 服务发现

- Test-Author 在真实 Reactive ApplicationContext 中先要求 auth/user/system 三条路由；未配置时测试按预期以空 RouteDefinition 集失败。
- Gateway 增加 Spring Cloud LoadBalancer、Nacos Discovery 和 Caffeine；没有引入 MVC、Servlet 或 servlet 版公共 Web 模块。
- 三条显式 `/api/v1/**` 路由分别指向 `lb://ygh-auth-service`、`lb://ygh-user-service`、`lb://ygh-system-service`，不设置未知路径 catch-all。
- Nacos 地址、用户名、密码和多网卡注册地址由环境变量注入；Namespace/Group 采用 `ygh-dev/YGH_GROUP` 开发基线，仓库不保存凭据。
- Caffeine 替换 Spring Cloud LoadBalancer 的开发默认缓存，启动日志不再出现生产缓存警告。
- 自动化测试解析并核对 Route ID、目标 URI、Path predicate，同时验证 Nacos Registry、Reactive LoadBalancer 与 Caffeine 位于 classpath。
- Reviewer 阻断了只检查 `/api/v1/` 前缀、无法发现 catch-all 或服务间路径错配的测试；现已按 Route ID 精确比较全部 Path 集合，并显式拒绝 `/api/v1/**`。
- 模块 Reactor `verify` 通过；Gateway 3 项测试、受影响公共模块 33 项测试全部通过。
- 真实组件烟测：可执行 JAR 注册到虚拟机 Nacos 3.1.1，实例为 `YGH_GROUP/ygh-gateway 192.168.154.1:18080`；本机 health 为 `UP`，虚拟机通过注册地址访问 health 也为 `UP`；进程随后停止。
