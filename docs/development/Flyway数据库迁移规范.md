# Flyway 数据库迁移规范

> 适用范围：所有持有 MySQL 或 PostgreSQL 业务事实数据的可运行 Service  
> 技术基线：JDK 25、Spring Boot 4.0.7、Flyway 11.14.1  
> 状态：`BE-0231` 已实现并通过自动化门禁

## 1. 模块与依赖边界

每个业务 Service 只维护自己数据库的迁移，不允许跨服务修改其他数据库。迁移文件必须直接放在该 Service 的标准 Maven 资源目录：

```text
service-module/
├─ pom.xml
└─ src/
   └─ main/
      └─ resources/
         └─ db/
            └─ migration/
               ├─ V1__create_initial_schema.sql
               ├─ V2__add_business_index.sql
               └─ V3__add_audit_columns.sql
```

- 公共模块提供 `spring-boot-starter-flyway` 和启动期安全门禁。
- MySQL Service 在自身 `pom.xml` 增加运行时 `org.flywaydb:flyway-mysql`。
- PostgreSQL/PGVector Service 在自身 `pom.xml` 增加 Flyway 对应 PostgreSQL 数据库模块。
- 公共模块不得绑定具体数据库驱动，避免所有 Service 被错误引入 MySQL 或 PostgreSQL 实现。

## 2. 文件命名和版本规则

唯一允许的格式为：

```text
db/migration/V<正整数>__<lower_snake_case>.sql
```

合法示例：

```text
V1__create_initial_schema.sql
V2__add_order_status_index.sql
V15__add_trace_columns.sql
```

强制规则：

1. 版本从 `1` 开始，只允许十进制正整数；禁止 `V0` 和前导零。
2. 描述必须为小写英文、数字和下划线，首字符必须为小写英文字母。
3. 同一 Service 内版本号和完整资源路径均不得重复。
4. 迁移必须直接位于 `db/migration`，禁止嵌套目录、自定义 Location 和路径穿越。
5. 只允许版本化 SQL；禁止 Repeatable `R__`、Undo `U__` 和 Java Migration。
6. 已存在更高已应用版本时，不得补插更低版本；必须创建新的最大版本。

## 3. 启动期强制门禁

`ygh-common-mybatis` 的主迁移策略在执行 SQL 前后形成 fail-closed 链路：

1. 校验最终 Flyway Location 精确等于 `classpath:db/migration`。
2. 校验最终配置没有被业务模块覆盖为危险值。
3. 扫描 Flyway 实际解析结果，拒绝不合法路径、版本、类型、重复项和历史插入。
4. 执行 `migrate`。
5. 执行官方 `validate`，校验已应用迁移的名称、类型和 checksum。

必须保持以下配置：

```yaml
spring:
  flyway:
    locations: classpath:db/migration
    validate-migration-naming: true
    validate-on-migrate: true
    clean-disabled: true
    out-of-order: false
    baseline-on-migrate: false
```

业务模块不得通过 `ignore-migration-patterns`、`repair` 或修改 Location 绕过校验。

## 4. 校验和与历史不可变规则

1. 迁移一旦应用到共享环境，文件名、版本、描述和内容永久不可修改或删除。
2. Flyway schema history 是迁移事实记录；应用启动时必须通过 checksum 校验。
3. 发现 checksum 不一致时立即停止发布，先确认仓库、构建产物和目标数据库版本，禁止直接执行自动 `repair`。
4. 需要修正历史 SQL 的业务效果时，新增下一版本的前向修复迁移。
5. 合并冲突导致版本重复时，尚未进入共享环境的一方重编号为当前最大版本之后。

## 5. 变更与回滚策略

项目采用 forward-only 迁移，不使用 Undo Migration。失败发布按以下顺序处置：

1. 停止继续扩大发布，保留应用、Flyway history 和数据库日志证据。
2. 若数据库变更向后兼容，回滚应用镜像，数据库保持新版本。
3. 若可在线修复，评审并发布新的更高版本前向修复 SQL。
4. 只有数据破坏、无法前向恢复时，才按已演练方案恢复备份，并同步回滚应用和发布记录。

禁止在生产环境执行 `flyway clean`；禁止删除 history 行伪造未执行状态；禁止将 `repair` 当作 checksum 冲突的常规修复手段。

破坏性结构变更必须采用 Expand → Migrate → Contract：

1. Expand：先增加可空列、新表或新索引，保持旧应用兼容。
2. Migrate：双写或后台迁移数据，完成核对并切换读取。
3. Contract：至少跨一个稳定发布窗口后，单独迁移删除旧结构。

涉及删表、删列、大表类型变更、全表更新和唯一约束重建时，必须有备份、容量评估、锁等待评估、灰度与恢复演练记录。

## 6. 开发与发布验证

单模块验证：

```powershell
.\mvnw.cmd -pl ygh-common/ygh-common-mybatis -am test
```

阶段验证：

```powershell
.\mvnw.cmd clean verify
```

每个业务 Service 后续还必须使用 Testcontainers 验证：

1. 空库可以完整迁移。
2. 同一构建重复启动不重复执行。
3. 修改已应用 SQL 后启动失败。
4. 删除已应用 SQL 后验证失败。
5. 新版本迁移成功并更新 schema history。
6. 迁移失败时事务或补偿行为符合目标数据库能力。

## 7. 迁移评审清单

- [ ] 文件位于 Service 自己的 `src/main/resources/db/migration`。
- [ ] 名称符合 `V<正整数>__<lower_snake_case>.sql`。
- [ ] 版本大于所有已发布版本且不重复。
- [ ] 没有修改或删除任何已应用迁移。
- [ ] DDL/DML 只访问本 Service 数据库。
- [ ] 主键、唯一约束、索引和审计字段经过评审。
- [ ] 大表操作评估锁、耗时、磁盘和回滚方案。
- [ ] 空库、升级、幂等和 checksum 失败测试通过。
- [ ] Secret、真实个人数据和环境专属地址未写入 SQL。
- [ ] 发布与恢复步骤已记录并可执行。

