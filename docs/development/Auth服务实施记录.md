# Auth 服务实施记录

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

- 唯一位置为 `classpath:db/migration`，当前版本为 `V1__create_auth_schema.sql`。
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
- `auth_db` 当前包含四张业务表及 `flyway_schema_history`，成功版本为 1。

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

下一项 `BE-0322` 实现强密码散列、密码策略和失败锁定；本阶段仍不宣称认证业务可联调。
