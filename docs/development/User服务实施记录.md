# User 服务实施记录

## 1. BE-0340 Maven 双模块

User 域按企业 Maven Reactor 建立为：

```text
ygh-applications/                 # packaging=pom
└─ ygh-user/                      # packaging=pom
   ├─ ygh-user-api/               # DTO/服务契约，packaging=jar
   │  └─ src/main/java + src/test/java
   └─ ygh-user-service/           # 可运行服务，packaging=jar
      └─ src/main/java + src/main/resources + src/test/java
```

- 根 Reactor 已加入 `ygh-applications`；两个聚合 POM 不创建空 `src`。
- API 模块只发布 DTO/接口，不依赖 Spring Web、数据库或服务实现；首个 `UserProfileView` 已验证 ID 对外保持字符串。
- Service 模块依赖 API、公共 Web/MyBatis 能力、Spring Boot Web/Actuator、Springdoc、Nacos、Flyway 与 MySQL 驱动，禁止向 API 模块反向依赖。
- `application.yml` 对 `user_db` 应用账号、迁移账号、Nacos 地址与凭据全部失败快速，不提供 localhost 或明文密码默认值。
- `UserApplication` 是唯一启动入口；实际 JAR 和 API 模块均严格采用 `src/main/java`、`src/main/resources`（仅服务）、`src/test/java` 的 Maven 标准目录。

验证命令：

```powershell
.\mvnw.cmd -pl ygh-applications/ygh-user/ygh-user-service -am verify
```

10 个相关 Reactor 模块构建成功，API 与 Service 测试、Enforcer、JaCoCo 和 Spring Boot 可执行 JAR 重打包均通过。

## 2. BE-0341 user_db V1

V1 在 User 私有 MySQL Schema 建立六张业务表：

| 表 | 所有权 | 关键门禁 |
|---|---|---|
| `user_profile` | 用户公开资料 | `user_id` 主键；显示名检查；乐观版本 |
| `user_department` | 部门树 | code 唯一；父级外键；禁止直接自引用 |
| `user_position` | 岗位定义 | code 唯一；启用状态与名称索引 |
| `user_employee` | 员工身份 | user/employee_no 唯一；部门外键；状态及日期检查 |
| `user_employee_position` | 员工多岗位关系 | 复合主键；员工删除级联关系；岗位删除受限 |
| `user_address` | 用户收货地址 | 所有权外键；每用户唯一默认地址；owner 更新时间索引 |

地址接收人、联系电话和详细门牌地址不以明文列保存，V1 只定义 `recipient_name_ciphertext`、`recipient_phone_ciphertext`、`address_detail_ciphertext` 和 `pii_key_version`；后续地址用例必须通过统一 AES-GCM 适配器读写。省市区用于路由与统计，仍按最小披露原则处理。默认地址使用生成列 `default_user_id` 与唯一索引在数据库层防止并发产生两个默认地址；Profile 删除采用 RESTRICT，敏感数据清理必须走显式审计用例，不依赖隐式级联。

真实 `mysql:8.4.10` Testcontainer 验证空库迁移一次、重复迁移为零、六张表和 Flyway 历史表、列/索引/外键、无原始 PII 列以及第二个默认地址被唯一约束拒绝。

开发虚拟机部署证据（2026-07-12）：

- 修改前备份 `/opt/ygh/constrained-dev/.env.bak-be0341-20260712` 与 `vm-compose.yml.bak-be0341-20260712`；
- `user_db` 使用独立 `ygh_user_migration` 和 `ygh_user_app`，迁移账号持有 DDL，应用账号仅获六张业务表 DML；
- Flyway 成功迁移到 V1，`verify-user-db.sh` 验证七张含历史表、应用账号 DDL 被拒绝；
- User 服务使用独立 runtime JAR 启动，readiness 为 `UP`；
- Nacos 中唯一健康实例为 `YGH_GROUP@@ygh-user-service 192.168.154.1:18082`，已排除 Link-local 地址误注册。

## 3. BE-0342 本人资料查询与修改

- 提供 `GET /api/v1/users/me` 与 `PUT /api/v1/users/me`，路径不接受外部 userId，所有权只能来自 Gateway 验证过的 JWT。
- Gateway 对 `userId/roles/permissions/traceId/requestId/method/path/timestamp` 生成独立 HMAC-SHA256 身份签名；User 校验 30 秒时窗和整组请求绑定信息。客户端伪造或篡改任一内部头均返回 401。
- 首次 PUT 以 `version=0` 创建 Profile；后续更新必须携带当前版本，通过 `SELECT ... FOR UPDATE` 与条件更新实现乐观并发控制，陈旧版本返回 409。
- displayName 入库前去除首尾空白；timezone 必须是 JDK ZoneId；avatarUrl 只接受带 host 的 HTTP/HTTPS URL；数据库 Entity/ResultSet 不进入 API 模块。
- 单元测试覆盖创建、读取、更新、陈旧版本、404、非法时区和 URL；真实 MySQL 测试覆盖 JDBC 创建、版本递增与陈旧写拒绝；可信身份测试覆盖有效、篡改、过期和缺失签名。
- 真实开发链路已完成 `Gateway → Auth 注册/JWT → User PUT → User GET`：注册用户通过 Gateway 更新并读回本人资料，响应 userId 与 JWT 主体一致、version 为 0、traceId 完整。

## 4. BE-0343 本人地址全生命周期

- 提供 `GET/POST /api/v1/users/me/addresses`、`PUT/DELETE /api/v1/users/me/addresses/{id}` 与 `PUT /api/v1/users/me/addresses/{id}/default`；接口不接受 owner 参数，所有 SQL 同时约束 `id + user_id`。
- 接收人、手机和详细地址使用 AES-256-GCM 字段级加密，随机 96-bit IV 随密文存储；AAD 绑定 owner、字段名和密钥版本，密文被篡改、跨用户复制或使用错误版本均无法解密。
- PII 密钥、版本和 ID worker 分别由 `YGH_USER_PII_KEY_BASE64`、`YGH_USER_PII_KEY_VERSION`、`YGH_USER_ID_WORKER` 注入；本地 `.env` 自动生成且被 Git 忽略，示例文件不含真实值。
- 第一条地址自动成为默认地址；切换默认地址和删除默认地址均在数据库事务内完成，数据库唯一生成列继续作为并发下的最后一道单默认约束。
- 修改、设默认和删除均携带 `version` 并使用 owner + version 乐观锁；资源不存在、越权访问和陈旧版本统一隐藏为业务冲突，不泄露他人资源是否存在。
- 自动化验证包括 API DTO 脱敏、AES 随机 IV/AAD/篡改、真实 MySQL 加密落库、单默认、所有权隔离、陈旧版本、删除后默认晋升和应用服务冲突分支；User API 与 Service JaCoCo 门禁通过。
- 真实链路证据（2026-07-12）：`Gateway → Auth 注册/登录 → User Profile → Address 创建/查询/修改/删除` 成功，结果为 `ADDRESS_E2E_OK`，创建地址为默认、更新版本由 0 增至 1、删除后列表为空。
