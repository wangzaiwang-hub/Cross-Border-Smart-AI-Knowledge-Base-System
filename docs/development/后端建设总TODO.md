# 全项目模块开发顺序与建设总 TODO

> 版本：V1.1  
> 基线日期：2026-07-15  
> 后端技术基线：JDK 25、Spring Boot 4.0.7、Spring Cloud 2025.1.2、Spring Cloud Alibaba 2025.1.0.0  
> 使用方式：本文件是全项目代码建设的唯一总进度表。先按“模块开发严格顺序”确定下一模块，再执行后文对应 BE/FE 任务。完成任务时必须同时附测试、构建、接口或部署证据；仅创建目录不得勾选业务完成。

## 0. 状态标记

- `[x]`：实现与验证均完成。
- `[ ]` 且阶段标记“实现冻结”：代码与交付物已完成，但按 2026-07-12 决策尚未执行集中验证；不得视为验收完成。
- `[ ]`：未完成或缺少验证证据。
- 阻塞项在任务后标记 `BLOCKED:`，并写明外部输入或失败证据。
- 每个阶段只有满足“退出门禁”后才能进入下一业务阶段；允许提前准备不依赖的脚手架，但不得提前宣称阶段完成。

## 1. 模块开发严格顺序

### 1.1 顺序使用规则

1. `M00` 到 `M32` 是全项目唯一模块队列，原则上从小到大推进。
2. 当前模块的“完成门禁”没有通过时，下一个依赖模块只能准备规格和失败测试，不能开始写业务实现，更不能标记完成。
3. 每个业务服务必须先完成 API 契约模块，再完成 Service 实现模块。其他服务只能依赖对方 API 模块，禁止依赖对方 Service 模块。
4. 数据库迁移属于服务实现的一部分，必须先于 Repository、业务用例和接口联调。
5. Gateway、Admin、前端和 E2E 都是消费者，必须在被依赖服务的 OpenAPI、错误码、权限和测试证据稳定后开发。
6. `[x]` 只表示该模块当前代码和模块级证据已完成；全项目是否交付仍以 P12、P13 的未完成门禁为准。

### 1.2 第一阶段：工程骨架与公共代码

| 顺序 | 状态 | 模块/路径 | 前置依赖 | 本模块必须完成的代码 | 完成门禁 |
|---|---|---|---|---|---|
| `M00` | `[x]` | 根工程 `pom.xml`、`.mvn/`、`mvnw.cmd` | 无 | Maven Reactor、Wrapper、Enforcer、模块聚合、基础插件 | Oracle JDK 25 下根工程可构建 |
| `M01` | `[x]` | `ygh-dependencies` | M00 | Spring、数据库、MQ、测试依赖版本集中治理 | dependencyManagement 无漂移和 Snapshot |
| `M02` | `[x]` | `ygh-common-core` | M00-M01 | 统一响应、错误码、异常、分页、金额/时间、领域事件、幂等模型 | 单元测试和序列化契约通过 |
| `M03` | `[x]` | `ygh-common-test` | M02 | 测试数据工厂、Mock 时钟、Testcontainers 公共支持 | 后续模块可直接复用测试基座 |
| `M04` | `[x]` | `ygh-common-web` | M02-M03 | 异常响应、校验错误、traceId、日志脱敏、OpenAPI 公共配置 | MVC/WebFlux 代表测试通过 |
| `M05` | `[x]` | `ygh-common-security` | M02-M04 | 当前用户、角色权限、资源所有权、内部签名、安全异常 | 伪造、过期、越权测试通过 |
| `M06` | `[x]` | `ygh-common-mybatis` | M02-M03 | 审计字段、分页、事务与 Flyway 约束 | MySQL 迁移和数据访问测试通过 |
| `M07` | `[x]` | `ygh-common-redis` | M02-M03 | Key 规范、TTL 抖动、缓存和分布式锁 owner 校验 | Redis/Testcontainers 测试通过 |
| `M08` | `[x]` | `ygh-common-mq` | M02-M03 | Event Envelope、生产消费契约、幂等、重试、死信 | RocketMQ 契约和重复消费测试通过 |

第一阶段退出门禁：业务模块不需要复制响应、安全、数据库、Redis、MQ 或测试工具代码；公共模块禁止反向依赖任何业务服务。

### 1.3 第二阶段：系统事实、用户、通知、认证和入口

| 顺序 | 状态 | 模块/路径 | 前置依赖 | 本模块必须完成的代码 | 完成门禁 |
|---|---|---|---|---|---|
| `M09` | `[x]` | `ygh-system-api` | M02、M05 | RBAC、字典、参数、功能开关、AI 配置 DTO 和接口契约 | API JAR 无数据库和 Service 实现依赖 |
| `M10` | `[x]` | `ygh-system-service` | M06、M09 | `system_db` 迁移、RBAC 事实、配置加密、权限和审计接口 | Flyway、权限、OpenAPI、集成测试通过 |
| `M11` | `[x]` | `ygh-user-api` → `ygh-user-service` | M05-M06、M09 | 用户、员工、组织、岗位、地址与数据隔离 | 用户和地址所有权测试通过 |
| `M12` | `[x]` | `ygh-notification-api` → `ygh-notification-service` | M06、M08、M11 | 模板、站内信、任务、已读、重试和死信 | 重复消息不重复创建通知 |
| `M13` | `[x]` | `ygh-auth-service` | M05-M07、M10-M12 | 注册登录、密码、JWT、刷新轮换、Redis 会话、审计 | 登录/刷新/退出/锁定/重放测试通过 |
| `M14` | `[x]` | `ygh-platform/ygh-gateway` | M04-M05、M10-M13 | 路由、JWT、内部签名、限流、CORS、上传限制 | Gateway→Auth→User 真实链路通过 |

第二阶段退出门禁：System 是权限和配置事实源，User 是用户资料事实源，Auth 只保存认证凭据；Gateway 不承载业务数据。

### 1.4 第三阶段：商城与交易闭环

| 顺序 | 状态 | 模块/路径 | 前置依赖 | 本模块必须完成的代码 | 完成门禁 |
|---|---|---|---|---|---|
| `M15` | `[x]` | `ygh-product-api` → `ygh-product-service` | M06-M08、M10 | 类目、品牌、SPU/SKU、价格、批次、溯源、缓存、索引事件 | 商品前后台接口和缓存一致性测试通过 |
| `M16` | `[x]` | `ygh-inventory-api` → `ygh-inventory-service` | M06、M08、M15 | 可用/锁定/已售库存、流水、锁定确认释放、超时对账 | 并发不超卖且重复请求幂等 |
| `M17` | `[x]` | `ygh-wallet-api` → `ygh-wallet-service` | M06、M08、M11 | 虚拟账户、充值、支付、退款、流水与幂等 | 并发扣款余额不为负 |
| `M18` | `[x]` | `ygh-order-api` → `ygh-order-service` | M11、M15-M17 | 购物车、订单快照、状态机、库存锁定、支付与 Outbox | 注册→充值→下单→支付→履约 E2E 通过 |

第三阶段退出门禁：订单只能通过公开 API 调用商品、库存和钱包；禁止跨库查询；金额、库存、幂等和状态机证据齐全。

### 1.5 第四阶段：搜索、知识、AI、培训和管理聚合

| 顺序 | 状态 | 模块/路径 | 前置依赖 | 本模块必须完成的代码 | 完成门禁 |
|---|---|---|---|---|---|
| `M19` | `[x]` | `ygh-search-api` → `ygh-search-service` | M06、M10、M15 | Elasticsearch 索引/别名、PGVector、关键词/向量融合和权限过滤 | 索引切换、过滤和混合检索测试通过 |
| `M20` | `[x]` | `ygh-knowledge-api` → `ygh-knowledge-service` | M06、M08、M19 | 文档安全上传、版本、审核、解析切片、发布/下线事件 | 未审核、失效或无权内容不可检索 |
| `M21` | `[x]` | `ygh-ai-api` → `ygh-ai-service` | M10、M15-M20 | 模型适配、RAG、引用、拒答、受控业务工具、SSE 和治理 | 模块测试完成；引用/拒答总 E2E 见 BE-0714 |
| `M22` | `[x]` | `ygh-training-api` → `ygh-training-service` | M11-M12、M20 | 课程、章节、任务、进度、测验、解锁、统计 | 岗位课程→阅读→测验→解锁 E2E 通过 |
| `M23` | `[x]` | `ygh-admin-api` → `ygh-admin-service` | M10-M22 | 运营总览、AI 治理、索引/MQ/服务状态与审计聚合 | 只调用公开只读 API，不跨库读取 |

第四阶段退出门禁：知识生命周期、搜索权限和 AI 引用形成闭环；Training 进度由服务端计算；Admin 只做聚合，不成为新的业务事实源。

### 1.6 第五阶段：测试工程、部署代码和前端

| 顺序 | 状态 | 模块/路径 | 前置依赖 | 本模块必须完成的代码 | 完成门禁 |
|---|---|---|---|---|---|
| `M24` | `[x]` | `ygh-api-compatibility-tests`、`ygh-compatibility-tests` | M00-M23 | 依赖类加载、API 二进制/OpenAPI 兼容门禁 | 代表类和契约快照无非预期变化 |
| `M25` | `[x]` | `ygh-contract-tests` | M08-M23 | Feign DTO、错误码、权限码、MQ Schema 契约 | 提供方与消费方契约一致 |
| `M26` | `[x]` | `ygh-integration-tests`、`ygh-security-tests` | M10-M23 | 数据库、缓存、消息、鉴权、上传和攻击面集成测试 | P0/P1 安全与一致性缺陷清零 |
| `M27` | `[x]` | `ygh-performance-tests` | M14-M23 | 网关查询、写入、搜索和 AI 性能场景 | P95 和错误率达到验收标准 |
| `M28` | `[x]` | `ygh-deploy`、各服务 Dockerfile | M10-M27 | 镜像、健康检查、资源、部署、回滚、备份和 SBOM | 各场景部署与恢复证据通过 |
| `M29` | `[x]` | `ygh-web/packages/ygh-web-shared` | M14、稳定 OpenAPI | HTTP Client、Token 刷新、共享类型、权限和错误处理 | mall/admin 不复制客户端基础代码 |
| `M30` | `[x]` | `ygh-web/apps/ygh-web-mall` | M15-M22、M29 | 商城、知识/AI、培训、个人中心真实接口页面 | type-check、build 和主要路由联调通过 |
| `M31` | `[x]` | `ygh-web/apps/ygh-web-admin` | M10、M12、M15-M23、M29 | 组织/RBAC、商品、知识、培训、AI、通知、审计页面 | 权限按钮、401/403 和管理接口联调通过 |
| `M32` | `[ ]` | `ygh-e2e-tests`、前后端最终验收 | M24-M31 | 登录、商城、知识 AI、培训、后台、视觉与部署 E2E | BE-0714、BE-1247、BE-1262/1263、FE-1307 全部完成 |

第五阶段退出门禁：全 Reactor、集成、安全、性能、E2E、前端视觉、部署恢复、Secret 和许可证门禁全部通过，才允许创建 Release。

### 1.7 每个业务模块内部固定 TODO 顺序

以下顺序适用于 System、User、Notification、Product、Inventory、Wallet、Order、Search、Knowledge、AI、Training 和 Admin；Auth/Gateway 没有独立 API 子模块时，从适用步骤开始：

1. `[ ]` 明确模块职责、数据所有权、调用方和禁止事项。
2. `[ ]` 先写 `*-api`：请求/响应 DTO、枚举、错误码、权限码、事件 Schema 和 Feign 契约。
3. `[ ]` 更新 OpenAPI 与《后端接口与前端接入清单》，状态先标“设计中”。
4. `[ ]` 在 `*-service` 增加 Flyway 迁移、唯一键、索引、约束和最小权限账号要求。
5. `[ ]` 编写 domain：实体、值对象、状态机、领域规则和领域事件，不依赖 Controller 或数据库实现。
6. `[ ]` 编写 application：用例编排、事务边界、幂等、权限和审计。
7. `[ ]` 编写 infrastructure：Repository、Redis、MQ、搜索、文件或外部模型适配器。
8. `[ ]` 编写 web：Controller、Validation、鉴权注解、错误映射和限流策略。
9. `[ ]` 先跑模块单元测试，再跑数据库/Redis/MQ/外部依赖集成测试。
10. `[ ]` 验证越权、重复请求、非法状态、依赖超时、日志脱敏和 Secret 边界。
11. `[ ]` 同步 OpenAPI、接口清单、Mock、前端类型和部署变量。
12. `[ ]` 运行 `mvnw.cmd -pl 模块 -am verify`，附证据后才把模块节点标为 `[x]`。

## 2. 当前总体进度

| 阶段 | 状态 | 主要结果 |
|---|---|---|
| P00 环境与工程马具 | 已完成 | 环境、规格、验收、接口台账已建立 |
| P01 Maven 与版本治理 | 已完成 | JDK 25、Maven Wrapper、企业 BOM、兼容性类加载测试通过 |
| P02 公共能力 | 已完成 | 公共实现、覆盖率/API 兼容门禁及 Token 攻击测试全部通过 |
| P03 Gateway/Auth/User | 实现冻结 | Gateway、认证、密码重置、User/RBAC 已实现；集中回归待执行 |
| P04 商城基础 | 实现冻结 | 商品、溯源、缓存、库存状态机与对账已实现；集中回归待执行 |
| P05 交易闭环 | 实现冻结 | 购物车、订单、钱包、模拟支付、Outbox 与对账已实现；集中回归待执行 |
| P06 知识与搜索 | 实现冻结 | 文档安全处理、审核生命周期、ES/PGVector 混合检索与索引切换已实现；集中回归待执行 |
| P07 AI 客服 | 实现冻结 | LangChain4j 1.17.2、豆包、RAG、受控工具、SSE、治理与评测已实现；集中回归待执行 |
| P08 培训系统 | 实现冻结 | 路径、课程、文档、任务、服务端进度、关卡测验和统计已实现；集中回归待执行 |
| P09 通知与后台 | 实现冻结 | 站内信、重试/死信、System 和 Admin 聚合已实现；集中回归待执行 |
| P10 治理与安全 | 实现冻结 | Sentinel、Feign 策略、审计、Secret/SBOM 交付物已实现；故障注入待集中验证 |
| P11 可观测性与运维 | 实现冻结 | 指标、日志、告警、备份恢复和资源治理已实现；恢复演练待集中验证 |
| P12 全量测试与交付 | 进行中 | Docker/Compose/OpenAPI/Bruno/Mock 已实现；全量门禁、E2E、PR 和 Release 待执行 |
| P13 前端 | 实现冻结 | 商城与运营后台真实接口接入完成；集中 E2E/视觉验收待执行 |

## P00 环境、需求与工程马具

- [x] `BE-0001` 固化需求规格、项目范围和非范围。
- [x] `BE-0002` 固化 Maven 主项目→副项目→功能聚合→API/Service 子项目规则。
- [x] `BE-0003` 建立 `AGENTS.md` 项目地图和架构红线。
- [x] `BE-0004` 建立后端交付技术规格。
- [x] `BE-0005` 建立后端量化验收标准。
- [x] `BE-0006` 建立 Windows、WSL2、Docker Desktop、VM 和中间件环境台账。
- [x] `BE-0007` 建立接口、DTO、错误码、权限码、事件和前端接入清单。
- [x] `BE-0008` 验证虚拟机 MySQL、Redis、Nacos 健康。
- [x] `BE-0009` 验证 PGVector、RocketMQ、Seata、Elasticsearch 可按场景运行。
- [x] `BE-0010` 初始化 Git 仓库、`main` 主分支和提交规范。
- [x] `BE-0011` 增加 Secret 扫描和 Git 暂存区检查。

退出门禁：规格、验收、环境、Secret 边界和记录路径明确。当前除 Git 初始化外已满足开发条件。

## P01 Maven、JDK 与依赖治理

- [x] `BE-0101` 根 Maven 聚合工程建立。
- [x] `BE-0102` Maven Wrapper 固定 3.9.16并校验下载摘要。
- [x] `BE-0103` Maven Enforcer 强制 JDK 25和 Maven 3.9.16。
- [x] `BE-0104` `ygh-dependencies` 企业 BOM 建立。
- [x] `BE-0105` Spring Boot 调整为 4.0.7。
- [x] `BE-0106` Spring Cloud 固定 2025.1.2。
- [x] `BE-0107` Spring Cloud Alibaba 固定 2025.1.0.0。
- [x] `BE-0108` 建立 `ygh-compatibility-tests` 依赖门禁模块。
- [x] `BE-0109` 验证 Boot、Feign、Nacos、Sentinel、RocketMQ、Seata 代表类在 JDK 25 下可链接。
- [x] `BE-0110` 验证最终依赖未被覆盖回 Boot 4.0.0/Cloud 2025.1.0。
- [x] `BE-0111` 对旧 Javassist 传递依赖完成风险处理或接受记录。
- [x] `BE-0112` 建立依赖漏洞扫描和许可证清单。

退出门禁：`mvnw.cmd clean verify` 成功；依赖版本可追踪；不使用 Snapshot；当前构建门禁已通过，运行门禁在 P03/P10继续。

## P02 公共能力副项目

### P02.1 common-core

- [x] `BE-0201` 统一 `ApiResponse<T>`。
- [x] `BE-0202` 统一错误码枚举和业务异常。
- [x] `BE-0203` 一基分页请求、最大 100 条限制。
- [x] `BE-0204` 分页响应对象。
- [x] `BE-0205` ID、金额、日期时间、枚举序列化规范与测试。
- [x] `BE-0206` 领域事件基础接口、事件头和版本字段。
- [x] `BE-0207` 幂等请求上下文和幂等结果模型。

### P02.2 common-web

- [x] `BE-0210` 统一业务异常和未知异常响应。
- [x] `BE-0211` traceId 提取且未知异常不向客户端泄露细节。
- [x] `BE-0212` Bean Validation 字段错误明细。
- [x] `BE-0213` 401、403、429和依赖降级统一响应。
- [x] `BE-0214` 请求日志、耗时和脱敏过滤器。
- [x] `BE-0215` OpenAPI 公共配置、鉴权头和统一错误 Schema。

### P02.3 common-security

- [x] `BE-0220` 创建 `ygh-common-security` 模块。
- [x] `BE-0221` 当前用户、角色和权限不可变模型（JWT Claim 映射在 Auth 阶段接入）。
- [x] `BE-0222` 方法级权限注解和资源所有权接口。
- [x] `BE-0223` Token 黑名单、账号禁用和会话撤销契约。
- [x] `BE-0224` 安全异常与审计事件。
- [x] `BE-0225` 越权、过期、伪造 Token 单元测试。

### P02.4 common-data/redis/mq/test

- [x] `BE-0230` 创建 `ygh-common-mybatis`，统一审计字段和分页。
- [x] `BE-0231` Flyway 迁移命名、校验和回滚规范。
- [x] `BE-0232` 创建 `ygh-common-redis`，Key 规范、TTL 抖动、锁 owner 校验。
- [x] `BE-0233` 创建 `ygh-common-mq`，事件 Envelope、幂等消费和死信记录。
- [x] `BE-0234` 创建 `ygh-common-test`，Testcontainers、Mock 时钟和测试数据工厂。
- [x] `BE-0235` 公共模块覆盖率与 API 兼容测试达标。

退出门禁：业务服务无需复制响应、安全、数据库、Redis、MQ 和测试基础代码；公共能力均有单元测试。

## P03 平台入口、认证与用户

### P03.1 Gateway

- [x] `BE-0301` 创建 `ygh-platform/ygh-gateway` 标准 Maven 模块。
- [x] `BE-0302` Gateway 使用 WebFlux，禁止引入 MVC Starter。
- [x] `BE-0303` 配置 `/api/v1/**` 路由和 Nacos 服务发现。
- [x] `BE-0304` 生成/透传 traceId、请求 ID和用户上下文。
- [x] `BE-0305` 公共路径、登录路径、员工路径和后台路径鉴权边界。
- [x] `BE-0306` Sentinel Gateway 限流和可识别降级响应。
- [x] `BE-0307` CORS、请求体大小、上传路径和安全 Header。
- [x] `BE-0308` Actuator 健康检查和 Nacos 注册验证。
- [x] `BE-0309` Gateway 路由、401/403/429集成测试。

### P03.2 Auth

- [x] `BE-0320` 创建 `ygh-auth-service` 和私有 `auth_db` 迁移。
- [x] `BE-0321` 定义注册、登录、刷新、退出、验证码和密码重置接口。
- [x] `BE-0322` 强密码散列、密码策略和失败锁定。
- [x] `BE-0323` 短期 Access Token、可撤销 Refresh Token和密钥轮换。
- [x] `BE-0324` Redis 会话、Token 黑名单和账号禁用失效。
- [x] `BE-0325` 登录审计、IP/账号限流和敏感日志保护。
- [x] `BE-0326` 注册登录、刷新轮换、重放、锁定和退出测试。
- [x] `BE-0327` 接口清单/OpenAPI/错误码同步为“可联调”。

### P03.3 User

- [x] `BE-0340` 创建 `ygh-applications/ygh-user` API/Service 双模块。
- [x] `BE-0341` 用户资料、员工、部门、岗位和地址表迁移。
- [x] `BE-0342` 个人资料查询修改接口。
- [x] `BE-0343` 地址新增、修改、删除、默认地址和所有权校验。
- [x] `BE-0344` 管理员用户启用、禁用、角色分配接口。
- [x] `BE-0345` 员工部门岗位关联接口。
- [x] `BE-0346` 地址快照 DTO，禁止订单引用可变地址实体。
- [x] `BE-0347` 普通用户访问他人资源的隔离测试。
- [x] `BE-0348` Gateway→Auth→User 端到端登录测试。

退出门禁：用户能注册登录、刷新/退出、维护本人资料和地址；管理员可禁用账号；真实 Nacos 注册发现通过。

## P04 商品、类目与库存

### P04.1 Product

实现状态（2026-07-12）：功能代码已冻结候选，包括完整商品筛选和可重试 Elasticsearch 增量同步；按“先开发后集中测试”决策保持任务未勾选，待集中验证后统一更新证据。

- [x] `BE-0401` 创建 Product API/Service 双模块和 `product_db`。
- [x] `BE-0402` 类目树、品牌、SPU、SKU、规格、图片、价格表迁移。
- [x] `BE-0403` 供港生鲜、岭南特产、跨境零食初始类目数据。
- [x] `BE-0404` 商品批次、来源证明、溯源码和溯源说明。
- [x] `BE-0405` 前台商品列表、筛选、详情和溯源查询接口。
- [x] `BE-0406` 后台商品 CRUD、上下架、价格和批次接口。
- [x] `BE-0407` 商品缓存、缓存失效和防穿透测试。
- [x] `BE-0408` 商品变更事件和 Elasticsearch 增量同步契约。
- [x] `BE-0409` 商品接口清单与 Mock 数据。

### P04.2 Inventory

- [x] `BE-0420` 创建 Inventory API/Service 双模块和 `inventory_db`。
- [x] `BE-0421` 可用、锁定、已售库存和库存流水表。
- [x] `BE-0422` 查询、锁定、确认、释放 API。
- [x] `BE-0423` 业务唯一键与重复消息幂等。
- [x] `BE-0424` 乐观锁/条件更新防止超卖。
- [x] `BE-0425` 库存超时释放任务和对账接口。
- [x] `BE-0426` 并发锁定、重复确认、释放和超卖测试。

退出门禁：商品可浏览和运营；库存状态机、流水、幂等与并发测试通过。

## P05 购物车、订单、钱包与模拟支付

### P05.1 Order

- [x] `BE-0501` 创建 Order API/Service 双模块和 `order_db`。
- [x] `BE-0502` 购物车增加、删除、修改、勾选接口。
- [x] `BE-0503` 订单预览重新校验商品、价格和库存。
- [x] `BE-0504` 订单、订单项、商品快照、价格快照、地址快照迁移。
- [x] `BE-0505` 创建订单和库存锁定流程。
- [x] `BE-0506` 待支付、已支付、模拟处理中、模拟完成、已取消、已关闭状态机。
- [x] `BE-0507` 用户订单列表/详情和管理员查询接口。
- [x] `BE-0508` 取消、超时关闭和模拟履约接口。
- [x] `BE-0509` 非法状态跳转与重复消息测试。

### P05.2 Wallet

- [x] `BE-0520` 创建 Wallet API/Service 双模块和 `wallet_db`。
- [x] `BE-0521` 虚拟账户、充值/支付/退款/调整流水迁移。
- [x] `BE-0522` 查询余额、虚拟充值和流水分页接口。
- [x] `BE-0523` 模拟支付和退款接口。
- [x] `BE-0524` 余额与流水同一本地事务。
- [x] `BE-0525` `Idempotency-Key` 防止重复扣款。
- [x] `BE-0526` 并发扣款、余额非负和十次重复请求测试。
- [x] `BE-0527` 页面和接口明确标记“模拟资金，不产生真实交易”。

### P05.3 交易事件与一致性

- [x] `BE-0540` 定义 ORDER_CREATED、WALLET_PAYMENT_SUCCEEDED、ORDER_CANCELLED 事件。
- [x] `BE-0541` Outbox/本地消息表或等价可靠事件方案。
- [x] `BE-0542` RocketMQ 生产/消费适配器、deliveryAttempt、ACK/RECONSUME、重试延迟、Broker DLQ 和幂等集成验证。
- [x] `BE-0543` 评审 Seata 使用边界，只用于必要短链路。
- [x] `BE-0544` 订单、钱包、库存三方对账任务。
- [x] `BE-0545` 注册→充值→下单→支付→模拟履约 E2E。

退出门禁：虚拟交易全链路可重复演示；重复请求/消息不重复扣款或扣库存；不接真实支付和物流。

## P06 知识库、文档处理与搜索

### P06.1 Knowledge

- [x] `BE-0601` 创建 Knowledge API/Service 双模块和 `knowledge_db`。
- [x] `BE-0602` 文档、版本、审核、标签、来源、地区、密级表。
- [x] `BE-0603` 政策生效/失效日期和发布机构字段。
- [x] `BE-0604` 草稿→待审核→已发布/已驳回→下线/失效状态机。
- [x] `BE-0605` PDF、DOCX、TXT、Markdown 上传安全校验。
- [x] `BE-0606` 本地附件卷、访问权限、校验和和重复检测。
- [x] `BE-0607` 文档解析、切片、任务进度、失败原因和重试。
- [x] `BE-0608` 版本历史和审核操作审计。
- [x] `BE-0609` KNOWLEDGE_PUBLISHED/UNPUBLISHED 事件。

### P06.2 Search/PGVector

- [x] `BE-0620` 创建 Search API/Service 双模块。
- [x] `BE-0621` 商品、知识 Elasticsearch 索引 Mapping 和别名。
- [x] `BE-0622` 增量索引、失败重试、全量重建和别名切换。
- [x] `BE-0623` PGVector chunk 表、Embedding 维度配置和元数据过滤。
- [x] `BE-0624` 关键词检索、向量检索和融合排序接口。
- [x] `BE-0625` 发布、下线、失效和权限过滤。
- [x] `BE-0626` 检索来源、版本、更新时间可追溯。
- [x] `BE-0627` 文档发布→ES/PGVector→检索 E2E。

退出门禁：已审核知识可检索；未审核、下线、失效或无权知识绝不进入召回结果。

## P07 AI 客服与 RAG

- [x] `BE-0701` 创建 AI API/Service 双模块和 `ai_db`。
- [x] `BE-0702` 锁定经 JDK 25/Boot 4.0.7 验证的 LangChain4j 版本。
- [x] `BE-0703` 豆包 Chat/Embedding 配置适配层，Secret 不入库。
- [x] `BE-0704` 会话、消息、RAG trace、Prompt 版本、反馈、评测表。
- [x] `BE-0705` 多轮会话和 SSE 流式回答接口。
- [x] `BE-0706` 查询改写、ES+PGVector 混合检索和重排。
- [x] `BE-0707` 商品价格、库存、订单受控 Java 工具调用。
- [x] `BE-0708` 回答引用文档、版本和更新时间。
- [x] `BE-0709` 证据不足、冲突、失效政策拒答。
- [x] `BE-0710` Prompt、模型参数、知识范围和敏感词后台配置。
- [x] `BE-0711` Token 用量、首字耗时、完整耗时和错误记录。
- [x] `BE-0712` Prompt 注入、越权知识、隐私最小化安全测试。
- [x] `BE-0713` 政策、通关、溯源、推荐四类离线评测集。
- [ ] `BE-0714` AI 回答带引用 E2E 和拒答准确率报告。

退出门禁：AI 只基于有效知识和实时业务工具回答；引用可核验；无证据不臆测；模型不能修改核心数据。

## P08 培训与闯关学习

- [x] `BE-0801` 创建 Training API/Service 双模块和 `training_db`。
- [x] `BE-0802` 岗位、课程、章节、文档、学习路径和前置课程表。
- [x] `BE-0803` 关卡、题库、试卷、合格分数、重试次数表。
- [x] `BE-0804` 岗位/部门/员工课程分配和截止时间。
- [x] `BE-0805` 阅读位置、有效学习时长和章节状态接口。
- [x] `BE-0806` 服务端计算阅读完成度，禁止前端直接提交“已完成”。
- [x] `BE-0807` 测验提交、评分、答题记录和重试。
- [x] `BE-0808` 达标后解锁下一关，失败按配置重学/重试。
- [x] `BE-0809` 本人学习任务、进度、成绩接口。
- [x] `BE-0810` 管理员完成率、逾期率、平均分、薄弱知识点统计。
- [x] `BE-0811` 课程分配事件和通知。
- [x] `BE-0812` 岗位课程→阅读→测验→解锁 E2E。

退出门禁：服务端进度和后台统计一致；员工只能访问本人被分配的内部课程。

## P09 通知、管理后台与系统能力

### P09.1 Notification

- [x] `BE-0901` 创建 Notification API/Service 和 `notification_db`。
- [x] `BE-0902` 站内信、模板、发送任务、已读状态表。
- [x] `BE-0903` 订单、知识审核、课程任务异步通知。
- [x] `BE-0904` 失败重试、死信、人工补偿和审计。
- [x] `BE-0905` 用户消息列表、未读数和已读接口。

### P09.2 System

- [x] `BE-0920` 创建 System API/Service 和 `system_db`。
- [x] `BE-0921` 角色、权限、用户授权关系和数据权限接口。
- [x] `BE-0922` 字典、参数和功能开关接口。
- [x] `BE-0923` System 服务只保存用户 ID 引用，不复制用户资料或认证凭据。
- [x] `BE-0924` 不同运营角色的菜单、按钮和后端权限测试。

### P09.3 Admin

实现状态（2026-07-12）：已补充 Loki 集中审计查询，支持用户、模块、动作、结果和时间过滤；部署编排已加入 Loki/Promtail，待集中 Compose 与接口回归。

- [x] `BE-0940` 创建 Admin API/Service 聚合模块。
- [x] `BE-0941` 运营总览、待办和异常摘要接口。
- [x] `BE-0942` AI 评测、Prompt、反馈和会话审计聚合接口。
- [x] `BE-0943` 索引任务、消息积压和系统状态接口。
- [x] `BE-0944` 聚合服务只调用公开只读 API 或查询模型，不跨库查询、不承载 RBAC 事实数据。

退出门禁：运营后台所需后端接口完整；无跨库读取；重要操作均审计并要求二次确认语义。

## P10 服务治理、安全与审计

- [x] `BE-1001` Nacos `ygh-dev/sit/uat/prod` namespace 和配置命名规范。
- [x] `BE-1002` OpenFeign 超时、错误解码、仅幂等查询有限重试。
- [x] `BE-1003` Sentinel 服务与接口限流、熔断、降级规则。
- [x] `BE-1004` Seata 真实客户端兼容测试和使用边界证明。
- [x] `BE-1005` RocketMQ 至少一次投递和消费幂等验证。
- [x] `BE-1006` 登录、权限、商品、知识、订单、钱包、配置审计日志。
- [x] `BE-1007` SQL 注入、XSS、CSRF、上传、暴力登录和越权测试。
- [x] `BE-1008` 日志脱敏测试：密码、Token、完整地址、API Key 不出现。
- [x] `BE-1009` Secret 扫描和镜像环境变量检查。
- [x] `BE-1010` 依赖漏洞处置和 SBOM。

退出门禁：权限由后端强制；故障和降级可识别；关键操作可审计；无明文 Secret。

## P11 可观测性、备份与运维

- [x] `BE-1101` 所有服务 Actuator health/readiness/liveness。
- [x] `BE-1102` JVM、HTTP、数据库、Redis、MQ、ES、PGVector 指标。
- [x] `BE-1103` traceId 跨 HTTP、Feign 和 RocketMQ 传播。
- [x] `BE-1104` 结构化日志字段和滚动策略。
- [x] `BE-1105` AI 首字、完整响应、检索、重排和 Token 指标。
- [x] `BE-1106` 错误率、慢接口、消息积压、连接池、磁盘告警规则。
- [x] `BE-1107` MySQL、PGVector、Nacos 配置和附件备份。
- [x] `BE-1108` 恢复演练和 RPO/RTO 证据（真实虚拟机只读备份→本机隔离恢复，实测 RPO < 1 分钟，核心数据 RTO < 1 分钟）。
- [x] `BE-1109` 镜像清理、日志上限和磁盘水位脚本。
- [x] `BE-1110` 运维手册、场景启停和故障排查清单。

退出门禁：服务状态可观察、问题可定位、数据可恢复、资源受限环境不会无界增长。

## P12 全量验证、部署与后端交付

### P12.1 自动化测试

- [x] `BE-1201` 全量单元测试与覆盖率门禁。
- [x] `BE-1202` MySQL、Redis、RocketMQ、PGVector、ES 组件测试。
- [x] `BE-1203` Feign API 和 MQ Schema 契约测试。
- [x] `BE-1204` 数据库迁移、缓存一致性、消息幂等集成测试。
- [x] `BE-1205` 登录、商城、知识 AI、培训四条 E2E。
- [x] `BE-1206` 性能测试达到 P95 指标（真实网关链路：查询 93.84ms、写入 43.34ms、搜索 103.85ms，错误率均为 0）。
- [x] `BE-1207` 安全测试与 P0/P1 缺陷清零（Auth OpenAPI 真实网关链路 ZAP 扫描 118 项通过，FAIL=0）。
- [x] `BE-1208` 备份恢复、容器重启、消息重放和索引重建测试（MySQL/PGVector/附件隔离恢复与重启实测，死信重放和索引版本测试通过）。

### P12.2 容器与部署

- [x] `BE-1220` 每个服务 JDK 25 Dockerfile、非 root 用户和固定基础镜像。
- [x] `BE-1221` 每个服务内存、CPU、堆、健康检查和日志上限。
- [x] `BE-1222` constrained-dev 的 core/mall/ai-apps/training 场景编排。
- [x] `BE-1223` enterprise-server 全量服务器 Compose。
- [x] `BE-1224` 镜像版本、Git SHA、构建时间和 SBOM 标签。
- [x] `BE-1225` 部署、回滚、健康检查和场景切换脚本。
- [x] `BE-1226` 虚拟机逐场景资源实测，磁盘<80%、可用内存≥500MiB。

### P12.3 前端接入交付

- [x] `BE-1240` OpenAPI JSON/YAML 和 Swagger UI。
- [x] `BE-1241` 完整接口、DTO、枚举、错误码、权限码和事件清单。
- [x] `BE-1242` 可版本化 Bruno/Postman 请求集。
- [x] `BE-1243` 脱敏 Mock JSON 和前端状态机矩阵。
- [x] `BE-1244` 登录刷新、401/403、权限按钮和 SSE 协议说明。
- [x] `BE-1245` 上传、下载、预览和 AI 流中断/重连说明。
- [x] `BE-1246` 所有“可联调”接口具备最近一次自动化证据。
- [ ] `BE-1247` 后端发布候选版本验收签字。

### P12.4 GitHub 远程交付

- [x] `BE-1260` 固定 GitHub `origin` 并推送已验收阶段基线到 `main`。
- [x] `BE-1261` 发布前执行全 Reactor、E2E、Compose、Secret 和许可证最终门禁（58 模块、364 测试、四套 Compose、498 组件 SBOM）。
- [ ] `BE-1262` 推送 release/feature 分支并通过 Pull Request 完成最终代码审查。
- [ ] `BE-1263` 合并到 `main`，创建版本标签和发布说明，记录远程 Commit SHA。
- [x] `BE-1264` 核验 GitHub 仓库不含 Secret、原始需求文件、运行数据、日志和构建产物（1,043 个跟踪文件审计通过）。

退出门禁：后端独立完成全部核心业务闭环、测试、容器部署和前端接入材料，不依赖尚未开发的前端证明业务正确。

## P13 前端与产品原型（后端完成后）

- [x] `FE-1301` Figma React ZIP 已完成 Vue 企业前端重构，原始原型仅保留为本地视觉参考。
- [x] `FE-1302` 完成商城、知识/AI、培训、个人中心、运营后台原型。
- [x] `FE-1303` 创建 `ygh-web-mall`：Vue 3 + TypeScript + Vite + Element Plus。
- [x] `FE-1304` 创建 `ygh-web-admin`：Vue 3 + TypeScript + Vite + Element Plus。
- [x] `FE-1305` 从 OpenAPI 生成或维护类型安全 API Client（共享类型客户端与 14 个运行时 OpenAPI 快照已冻结）。
- [x] `FE-1306` 接入全部后端接口、权限、错误状态和流式 AI。
- [ ] `FE-1307` 前后端 E2E、视觉验收和最终交付。

说明：2026-07-13 根据后续决策已提前完成正式 Vue 商城和运营后台，以便在集中测试中验证真实端到端链路；Figma ZIP 只作为视觉参考，不直接覆盖现有工程。P13 在 Gateway、OpenAPI、E2E 与视觉检查通过前仍不得标记验收完成。

## 3. 每次开发循环

后续每一个 TODO 都必须走以下循环：

1. 更新对应 `spec/` 和接口清单。
2. 测试作者先写失败测试或可判定验证脚本。
3. 开发只实现满足当前任务的最小业务闭环。
4. 运行模块测试和受影响模块构建。
5. 审查权限、数据所有权、Secret、日志和架构边界。
6. 更新本 TODO、接口清单和 `docs/daily/YYYY-MM-DD/` 证据。
7. 阶段结束运行 `mvnw.cmd clean verify` 和对应部署冒烟。

## 4. 固定验证命令

```powershell
.\mvnw.cmd clean verify
.\mvnw.cmd -Pintegration verify
docker compose config
docker compose ps
ssh vm-ygh "cd /opt/ygh/constrained-dev && ./scripts/health-check.sh"
```
