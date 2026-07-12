# Auth 服务实施记录

## 2026-07-12 密码重置闭环

- 密码重置申请先消费一次性验证码，外部始终返回相同的 202 结构，避免泄露账号是否存在。
- 重置令牌使用 256 位随机数，数据库仅保存 SHA-256 摘要和 15 分钟有效期。
- 原始令牌通过带 HMAC 签名的 Notification 内部接口投递到本人站内信，不写日志、不进入 API 响应。
- 确认接口在本地事务中锁定并一次性消费令牌，执行密码策略和 Argon2id 重散列，同时撤销该账号全部 Refresh Token。
- 新增 Flyway `V2__create_password_reset.sql`，Notification 新增 `AUTH_PASSWORD_RESET` 模板；集中测试按当前“先开发后测试”策略后置。

> 模块：`ygh-platform/ygh-auth-service`  
> 技术基线：JDK 25、Spring Boot 4.0.7、MySQL 8.4.10、Flyway 11  
> 当前完成：`BE-0320`—`BE-0321`

## 1. Maven 与服务边界

`ygh-auth-service` 是 `ygh-platform` 下的可运行 JAR，采用标准 Maven 目录，依赖公共 Core、Web、Security、MyBatis 能力。服务拥有私有 `auth_db`，其他服务不得跨库查询；服务间只通过 API 或事件契约协作。

运行配置全部通过环境变量注入。数据库 URL、应用密码、迁移密码、Nacos 地址和凭据没有默认秘密值，缺失时启动失败。应用连接池默认最多 5 条连接，适配当前低配置开发环境；生产环境通过部署参数单独扩容。

## 2. 数据库账号隔离

| 账号 | 用途 | 权限 |
|---|---|---|
| `ygh_auth_app` | Auth 运行时事务 | 仅四张 Auth 业务表的 `SELECT, INSERT, UPDATE, DELETE` |
| `ygh_auth_migration` | Flyway 发布迁移 | DML 与 `CREATE, ALTER, INDEX, REFERENCES, DROP` |

初始化脚本每次先撤销原权限，再按白名单重新授权，从而纠正权限漂移。运行账号不能读取或修改 `flyway_schema_history`，迁移台账只属于迁移账号。全新库在 V1 执行前，运行账号仅有 `USAGE`；迁移完成后再次执行幂等 provision，才授予四张已存在业务表的权限。密码限定为 24—128 位 ASCII 字母或数字，避免 Shell/SQL 插值歧义；仓库生成器与该约束一致。MySQL 端口只绑定虚拟机专用地址，账号允许来自容器网络及开发机，外围访问继续由虚拟机网络边界限制。

现有 `ygh-mysql-data` 数据卷不会重新执行 `/docker-entrypoint-initdb.d`。因此提供 `scripts/provision-auth-db.sh` 作为显式、幂等的存量环境升级入口；不需要删除或重建数据卷。执行前已在虚拟机保留 `vm-compose.yml.bak-be0320`、`.env.bak-be0320` 和旧初始化脚本备份（如存在）。

开发环境的标准部署入口为 `scripts/deploy-auth-dev.ps1`，顺序固定为：构建可执行 JAR → 初始化数据库及迁移账号 → 运行无 HTTP 端口的 Flyway Job → 重跑表级授权 → 权限/版本验证 → 清除迁移凭据并关闭运行时 Flyway → 启动 Auth → 校验新进程 PID、端口归属和 readiness。任一步失败都会阻断后续启动。`deploy-core.sh` 负责核心组件和迁移前账号准备；Auth 部署脚本负责迁移后的授权闭环。

部署脚本可安全重复执行：只停止 PID 文件指向且命令行属于当前 Auth JAR 的旧 Java 进程；未知进程占用端口时拒绝部署；新进程提前退出立即失败；只有新 PID 实际拥有监听端口且 readiness 为 `UP` 后才原子替换 PID 文件。连续两次真实部署已验证旧 PID 退出、新 PID 接管端口，未使用旧实例健康状态误报成功。

## 3. V1 表结构

| 表 | 事实边界 | 关键约束/索引 |
|---|---|---|
| `auth_account` | 登录主体、状态、失败次数和锁定 | principal 唯一；user/type 唯一；状态索引；乐观版本 |
| `auth_credential` | 单向密码摘要及算法参数 | account 唯一；外键限制删除 |
| `auth_refresh_token` | 只保存 Token SHA-256 摘要、令牌族和轮换链 | hash 唯一；账号/族/过期复合索引；全局过期清理索引 |
| `auth_login_attempt` | 登录成功/失败审计 | principal/IP/account 时间索引；全局留存清理索引 |

所有业务 ID 使用 `BIGINT`，时间使用微秒精度 `DATETIME(6)`，字符集为 `utf8mb4`。表中不存明文密码或原始 Refresh Token。Refresh Token 的父子关系可用于 `BE-0323` 检测重放并撤销整个令牌族。

## 4. Flyway 安全策略

- 唯一位置为 `classpath:db/migration`，当前版本为 V2；V1 创建认证事实表，V2 将登录审计原始 IP 前向迁移为不可逆摘要。
- `clean`、baseline、out-of-order 均关闭，启动时强制 validate。
- 修复公共 Flyway 门禁对 Flyway 11 绝对 classpath 资源路径的误判；仍先验证资源属于批准位置，再规范化为策略路径。
- 数据库迁移使用独立账号，应用 Hikari 数据源始终使用无 DDL 权限账号。

## 5. 自动化与真实环境证据

模块测试使用受限内存的 `mysql:8.4.10` Testcontainer，验证：

1. 空库只执行一次 V1，重复迁移执行数为 0；
2. 四张业务表、Flyway 历史表、列、索引与外键完整；
3. 独立迁移账号能建表和迁移，运行账号能读写但不能执行 DDL；
4. Spring Boot 4.0.7 使用分离账号启动真实 ApplicationContext；
5. Testcontainer 管理员凭据运行时随机生成，日志字符串同时隐藏普通与管理员凭据。

Testcontainer 从全新 MySQL 数据目录开始，测试顺序与正式部署一致：先创建只有迁移权限的身份，执行 Flyway，再按业务表授予运行身份，最后启动 Spring 上下文；并反向证明运行身份不能修改迁移历史。

虚拟机验证（2026-07-12）：

- `provision-auth-db.sh` 在不重建现有 MySQL 数据卷的情况下成功创建并校准账号；
- `verify-auth-db.sh` 验证应用账号 DDL 被拒绝、迁移账号 DDL 成功、授权无漂移；
- 本机启动 Auth 可执行 JAR，连接虚拟机 MySQL 完成 V1，readiness 为 `UP`；
- Nacos 中出现唯一健康实例 `YGH_GROUP@@ygh-auth-service`，烟测结束后进程已停止；
- `auth_db` 当前包含四张业务表及 `flyway_schema_history`；该条初始部署证据当时成功版本为 1，后续 V2 实际迁移证据见第 10 节。

## 6. BE-0321 HTTP 契约

认证服务已冻结七个 `/api/v1/auth/**` 端点：注册、登录、刷新、退出、验证码、申请密码重置、确认密码重置。Controller 只依赖 `AuthCommandService` 应用端口，不暴露 Mapper、Entity 或数据库对象；后续认证实现可替换用例实现而不改变 HTTP 契约。

- 注册成功为 201；密码重置申请采用防枚举语义并返回 202；其他成功请求为 200。
- 所有响应统一为 `code/message/data/traceId/timestamp`。
- Gateway 匿名白名单与接口矩阵一致；退出接口必须认证。
- 参数错误和畸形 JSON 均返回 400/`VALIDATION_ERROR`，不回显 rejected secret 或 JSON 解析异常。
- 所有 credential-bearing DTO 将秘密字段声明为 JSON write-only，并覆盖诊断字符串。
- 密码重置申请响应只公开固定 `expiresIn`，不包含账号是否存在的布尔值；已知与未知主体必须保持相同外部响应和公开时序策略。
- 在 `BE-0322`—`BE-0325` 完成前，条件回退用例仅在没有真实 `AuthCommandService` 时注册，并统一 fail-closed 为 503，不提供假 Token、固定验证码或伪注册结果。

MockMvc 契约测试覆盖七条成功协议、校验失败、Envelope 与 traceId；DTO 测试覆盖反序列化、只写序列化、密码确认和诊断脱敏；占位应用服务测试覆盖所有方法的 fail-closed 行为。Auth 模块 `verify` 已通过 70% 行覆盖率门禁。

## 7. BE-0322 密码安全与失败锁定

- 密码摘要采用 Argon2id v19，参数为 19 MiB 内存、2 次迭代、1 路并行、16 字节随机盐和 32 字节摘要；实现将 `char[]` 显式编码为受控 UTF-8 缓冲区后调用 Bouncy Castle `byte[]` API，临时明文、盐、摘要及编码缓冲区在使用后清零。
- PHC 字符串先执行长度、语法、盐/摘要长度和资源参数上限校验，再进入 Argon2。当前允许验证的兼容窗口上限为 32 MiB、4 次迭代、2 路并行，避免攻击者提交畸形摘要造成内存或 CPU 耗尽；并发散列通过公平信号量限制为 2 个，容量耗尽失败关闭。
- 密码长度按 Unicode code point 计算，无 MFA 默认最少 15、最多 128；允许空格和 Unicode，不强制大小写、数字或特殊字符组合，拒绝控制字符。
- 离线弱密码检查使用 SecLists `2026.1` 的 xato 前十万数据集。仓库仅保存 96,518 个去重、排序后的 SHA-256 摘要及来源/许可证说明，不保存弱密码明文；资源在启动时校验固定条目数、SHA-256 和严格排序，缺失或损坏时启动失败。
- 账号连续 5 次失败锁定 15 分钟。`auth_account.version` 乐观锁保证并发更新不丢失；成功登录只可清理未锁定的失败状态，不能在 CAS 重试期间清除并发产生的有效锁。
- MySQL 集成测试验证摘要不含明文、连续失败/过期/成功状态机以及 10 个虚拟线程并发失败不绕过锁定；单元测试覆盖畸形 Argon2 参数、弱密码资源完整性和成功清锁竞态。

Auth 模块 Reactor `verify` 已通过 22 项测试及 JaCoCo 门禁；在令牌与会话链路完成前仍不宣称认证业务可联调。

## 8. BE-0323 Token 与签名密钥轮换

- Access Token 使用 RS256，默认有效期 15 分钟且配置被限制在 5—20 分钟；包含 `iss/aud/sub/jti/iat/nbf/exp/account_id/roles/permissions`，角色和权限集合与 Gateway 的数量、字符及 4096 字符上限保持一致。
- Auth 从外部密钥目录读取活动私钥和最多 8 把当前/历史公钥，`kid` 选定活动签名密钥；`/.well-known/jwks.json` 只发布公钥。滚动轮换时先加入新公钥并切换活动 `kid`，旧公钥至少保留一个 Access Token 最大寿命后再删除。
- POSIX 环境要求密钥目录不可被 group/others 写、私钥为 owner-only，并使用 `SecureDirectoryStream + NOFOLLOW_LINKS` 相对读取；非 POSIX 同样禁止跟随链接。PEM、DER、签名自检缓冲区均清零，启动时校验 RSA 至少 2048 位、CRT 指数、模数及真实 sign/verify 配对。
- Refresh Token 为 256 bit 随机不透明值，默认有效期 14 天且配置范围为 1—30 天；数据库只保存 SHA-256，不保存原 Token。每次刷新在单个 MySQL 事务内 `SELECT ... FOR UPDATE`、插入子 Token 并撤销父 Token。
- 已轮换 Token 再次出现即视为重放，以 `account_id + token_family` 命中复合索引并撤销整个 Token family；时间读写统一使用 UTC Calendar。真实 MySQL 测试验证两代 Token 均被撤销，并用 `EXPLAIN` 证明整族操作使用 `idx_auth_refresh_account_family_expiry`。
- `generate-jwt-keypair.sh` 使用 OpenSSL 生成 3072-bit RSA 密钥，默认目录 0700、私钥 0600，并拒绝覆盖。密钥文件、私钥内容与真实路径不进入仓库。

JWT 功能通过 `YGH_JWT_ENABLED=true` 显式启用，并要求注入 `YGH_JWT_KEY_DIRECTORY`、`YGH_JWT_ACTIVE_KID` 与 `YGH_JWT_ISSUER`；缺失或不安全配置启动失败。Auth 模块已通过 25 项测试和 Reviewer P0/P1 门禁。下一项 `BE-0324` 实现 Redis 会话、Access Token 撤销标记与账号禁用即时失效；完整登录/刷新 HTTP 联调仍在后续认证用例聚合后宣告。

## 9. BE-0324 Redis 会话与即时失效

- 每个 Access Token 签发时将 `accountId + jti` 会话写入 Redis，TTL 与 Token 剩余寿命一致；注销时用 Lua 原子删除会话并写入撤销标记。
- Gateway 在 RS256、issuer、audience 和时间窗验签之后，强制使用 `account_id + jti` 查询 Redis。会话不存在、已撤销、所有者不匹配或账号不是显式 `ACTIVE` 均返回 401；Redis 不可用时失败关闭为 503。
- Redis Cluster 键统一使用账号 hash tag：`ygh:<env>:auth:{<accountId>}:...`，确保 Lua 涉及的会话、撤销和账号状态键处于同一 slot。
- 账号状态为显式 `ACTIVE/DISABLED`；缺失时不默认激活。禁用状态不设 TTL，重新启用必须显式写回 `ACTIVE`。
- Auth 和 Gateway 的 Redis host、password、environment 均为必填环境配置，不提供 localhost 或弱密码回退；部署脚本只从 `.env`/环境变量注入。
- 真实 Redis Testcontainers 覆盖注册、撤销、账号禁用/启用、TTL 和 Cluster hash slot；Gateway 集成测试覆盖正常、撤销、Redis 故障及下游异常边界。

阶段模块 Reactor `verify` 已通过 11 个模块，所有 JaCoCo 门禁通过。完整登录用例仍由 `BE-0325` 继续聚合。

## 10. BE-0325 登录审计、双维限流与可信客户端 IP

- 登录前以 Redis Lua 对账号主体和客户端 IP 分别执行固定窗口原子计数，默认阈值为账号 `10 次/15 分钟`、IP `30 次/15 分钟`；两个维度始终都计数，任一超限即返回 429，Redis 故障失败关闭。
- 主体和 IP 在进入 Redis key 或 MySQL 审计表前均使用独立环境 Pepper 的 HMAC-SHA256；数据库只保存 64 位摘要。V2 前向迁移使用逐行随机 256-bit 值替换历史原始 IP 后删除 `client_ip` 列，避免低熵 IP 被字典还原。
- Gateway 删除客户端提交的内部 IP、时间戳和签名头，以 TCP 对端地址重建。HMAC 签名绑定 IP、traceId、requestId、HTTP 方法、路径和毫秒时间戳；Auth 只接受 30 秒窗口内的有效签名。
- `YGH_AUTH_AUDIT_PEPPER_BASE64` 与 `YGH_INTERNAL_REQUEST_HMAC_BASE64` 均要求至少 32 字节随机值，只通过 Secret/环境变量注入；生成脚本可幂等补齐既有 `.env`，不输出实际值。
- 登录状态机按限流、账户读取、Dummy/真实 Argon2 校验、禁用/锁定判断、失败次数 CAS、Token 签发和审计顺序执行。未知账户同样执行 Dummy Argon2，外部统一返回 `UNAUTHENTICATED`。
- Access/Refresh Token 签发后若成功审计失败，系统失败关闭并补偿撤销 Redis Access Session 与 Refresh Token family；清理失败作为 suppressed exception 保留，不覆盖原始错误。
- 请求日志只记录方法、无 Query 的路径、状态、耗时、相关 ID 和经过敏感词检查的 User-Agent；不读取请求体，不记录密码、验证码、Authorization、Cookie 或 Token。

真实 MySQL 8.4.10 + Redis 8.4.4 + 临时 RSA 密钥 + Auth 随机端口 HTTP 测试已验证：登录 200、JWT `sub/account_id/roles`、Refresh Token 行、Redis Session/账号状态和 HMAC 登录审计五处事实一致。Reviewer 复核无 P0/P1。

虚拟机 MySQL 于 2026-07-12 从 V1 前向迁移至 V2，Flyway 校验并成功应用 1 个迁移；更新后的 `verify-auth-db.sh` 已确认版本为 2、`client_ip` 已删除、仅保留 `client_ip_hash`，同时应用账号 DDL 拒绝、迁移账号 DDL 成功及五张含 Flyway 历史表的表数量门禁均通过。随后开发 Auth 实例重新部署成功。

## 11. BE-0326 注册、轮换、重放、锁定与退出闭环

- 注册使用一次性 Redis 验证码。验证码答案使用带域分离的 HMAC-SHA256 存储，Lua 在校验时无论成功失败都删除挑战；对外仅返回带干扰线、随机颜色和旋转字符的 PNG，不把答案作为 SVG 文本或响应字段暴露。
- 注册主体统一规范化，密码先经过长度、控制字符与泄露密码库检查，再执行 Argon2id；账号与凭据在一个 MySQL 事务写入，唯一键竞态稳定转换为 `BUSINESS_CONFLICT`。
- 业务 ID 使用 64 位 Snowflake 生成器，固定纪元、10 bit worker 和 12 bit 毫秒序列；`YGH_AUTH_ID_WORKER` 为部署必填项，同一集群实例不得重复，时钟回拨与序列容量耗尽均失败关闭。
- Refresh Token 每次使用即轮换；旧 Token 重放会撤销整个 token family。账号缺失或禁用时，新生成的轮换 Token 被补偿撤销，不签发 Access Token。
- 退出必须同时携带有效 RS256 Bearer Token 与 Refresh Token。Auth 独立校验签名、`kid`、issuer、audience、有效期和 `account_id/jti`，随后撤销 Refresh family，并原子删除 Redis Access Session、写入撤销标记；缺少或伪造 Authorization 返回 401。
- 真实 HTTP 集成测试使用 MySQL 8.4.10、Redis 8.4.4、临时 RSA 密钥和随机端口，覆盖验证码、注册 201、登录 200、刷新轮换、旧 Token 重放 401、无 Authorization 退出 401、有效退出、Redis Session 撤销、连续五次失败锁定及锁定后正确密码仍为 401。

Auth Reactor 共执行 45 项测试，JaCoCo 门禁通过；真实链路未使用 Mock Controller、内存数据库或伪造 Token。

开发 Auth 部署脚本已改为强制加载忽略目录中的 3072-bit RSA 密钥、收紧 Windows ACL、开启 JWT 真实模式并注入唯一 worker ID。实测部署后 readiness 为 `UP`、验证码接口返回 `SUCCESS/image/png`，证明当前运行实例不是 503 契约回退实现；虚拟机 `auth_db` V2 与最小权限复验同时通过。

## 12. BE-0327 OpenAPI、错误码与前端联调冻结

- Auth 显式接入 Springdoc WebMVC API，运行实例 `/v3/api-docs` 输出 OpenAPI 3.1；服务地址固定为 Gateway 相对根 `/`，冻结文件不包含 localhost、开发端口或机器 IP。
- OpenAPI 固定八条路径，注册成功码为 201、密码重置申请为 202、退出声明 Bearer 安全要求；统一挂载 `X-Request-Id` 与 400/401/409/429/503/500 响应组件。
- 冻结文件位于 `spec/openapi/auth-service-v1.json`，兼容性测试校验路径集合、环境中立性、成功状态码、退出安全方案、错误响应和秘密输入 `writeOnly`，防止文档静默漂移。
- 前端接入清单已同步 Token 保存/轮换、字符串 ID、验证码、退出失败处理以及九个稳定错误码。核心注册、登录、刷新、退出和验证码标记为“可联调”；密码重置因通知域尚未建设，明确标记为契约冻结且当前返回 503，没有伪称完成。
- 开发 Gateway 与 Auth 均通过独立 runtime JAR 目录部署，构建产物不再被 Windows 运行进程锁定；Gateway issuer 与 Auth 逻辑 issuer 已统一。真实 Gateway 调用 `/api/v1/auth/captcha` 返回 `SUCCESS/image/png` 和规范 traceId。

## 13. BE-0344 账号启停子能力（角色分配完成前不关闭任务）

- 新增管理员接口 `PUT /api/v1/auth/admin/users/{userId}/status`，Gateway 与 Auth 双层校验 `ADMIN` 角色；Auth 重新验证 Gateway 绑定 userId、角色、权限、traceId、requestId、方法、路径和时间戳的身份签名。
- 管理写入按 userId 查找 Auth 自有账号，以版本号乐观更新 `ACTIVE/DISABLED`，同时清理登录失败和临时锁定；管理员不能禁用自身，越权、资源探测和陈旧版本均不会泄露账号事实。
- `auth_account_admin_audit` 记录目标账号、业务用户 ID、操作人、动作、原因和服务端时间。应用账号仅获该表 DML，迁移账号继续持有 Schema DDL。
- 状态变更提交后同步更新 Redis 账号状态；禁用立即使现有 Access Token 失效，重新启用不恢复已撤销 Token，用户必须重新登录。
- 真实链路 `Gateway → ADMIN JWT → Auth V3 → Redis → Gateway Session 校验` 已验证：目标账号由 ACTIVE 切为 DISABLED 后旧 Token 立即返回 401，再恢复 ACTIVE，证据为 `ACCOUNT_ADMIN_E2E_OK`。
- 本节只完成 BE-0344 的账号启停部分；角色事实必须落在独立 `system_db`，不得为了提前勾选任务写入 `auth_db`。完成 System RBAC 和授权快照联动后再将 BE-0344 标记完成。
