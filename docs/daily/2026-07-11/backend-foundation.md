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
