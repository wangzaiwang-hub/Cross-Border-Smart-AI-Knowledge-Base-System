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
