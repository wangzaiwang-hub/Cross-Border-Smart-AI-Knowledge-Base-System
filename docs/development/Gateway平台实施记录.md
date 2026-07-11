# Gateway 平台实施记录

> 模块：`ygh-platform/ygh-gateway`  
> 技术基线：JDK 25、Spring Boot 4.0.7、Spring Cloud Gateway 5.0.2  
> 当前完成：`BE-0301`—`BE-0306`

## 1. Maven 边界

```text
ygh-platform/                       # packaging=pom，平台副项目
├─ pom.xml
└─ ygh-gateway/                     # 可运行 jar
   ├─ pom.xml
   └─ src/
      ├─ main/
      │  ├─ java/
      │  └─ resources/application.yml
      └─ test/java/
```

`ygh-platform` 只聚合平台入口服务并导入企业 BOM，不创建无意义源码。`ygh-gateway` 由 Spring Boot Maven Plugin `4.0.7` 重新打包为可执行 JAR。

## 2. 响应式边界

- 网关只使用 `spring-cloud-starter-gateway-server-webflux`，Web Application Type 固定为 `reactive`。
- 网关不依赖 servlet 版 `ygh-common-web`；该模块当前含 Spring MVC 和 Servlet API，不允许进入 Gateway 依赖图。
- 单元测试同时断言 `DispatcherHandler` 存在、`DispatcherServlet` 和 `jakarta.servlet.Servlet` 不存在。
- 启动测试使用随机端口创建真实 Reactive ApplicationContext，验证 Gateway WebHandler 和 Netty 启停。
- Nacos Discovery、JWT 与 Sentinel Gateway Adapter 已接入；动态限流规则持久化仍归 `BE-1003`。

## 3. 路由与服务发现

| Route ID | Path | 目标服务 |
|---|---|---|
| `auth-service` | `/api/v1/auth/**` | `lb://ygh-auth-service` |
| `user-service` | users/employees/departments/jobs/addresses | `lb://ygh-user-service` |
| `system-service` | system/roles/permissions | `lb://ygh-system-service` |

- 只声明显式业务路径，不配置可吞掉未知接口的 `/api/v1/**` catch-all。
- `spring-cloud-starter-loadbalancer` 解析 `lb://` URI；Caffeine 替换仅适合测试的默认 LoadBalancer Cache。
- Nacos 地址、用户名和密码必须由 `YGH_NACOS_SERVER_ADDR/USERNAME/PASSWORD` 注入，仓库没有开发密码或 Token。
- Namespace 默认为 `ygh-dev`，Group 默认为 `YGH_GROUP`；生产环境必须覆盖 Namespace。
- `YGH_SERVICE_IP` 可在多网卡环境显式指定可达注册地址，避免自动选择 Link-local 地址。

## 4. 基础配置

| 配置 | 默认值 | 说明 |
|---|---:|---|
| `spring.application.name` | `ygh-gateway` | Nacos 服务名基线 |
| `spring.main.web-application-type` | `reactive` | 禁止回退 MVC |
| `server.port` | `8080` | 可由 `YGH_GATEWAY_PORT` 覆盖 |
| Actuator exposure | `health,info` | 当前最小暴露面 |
| Health probes | `true` | 为后续容器探针预留 |
| Health details | `never` | 未认证端点不泄露依赖细节 |

## 5. 验证

```powershell
.\mvnw.cmd -pl ygh-platform/ygh-gateway -am verify
```

结果：6 个 Reactor 模块、36 项测试全部通过；Gateway 真实响应式上下文解析三条路由、启动并完成优雅关闭；可执行 JAR 重打包成功。

真实组件烟测使用本机 JDK 25 启动可执行 JAR，连接虚拟机 Nacos 3.1.1：

- 注册结果：`YGH_GROUP/ygh-gateway -> 192.168.154.1:18080`。
- 本机 Actuator health 返回 `UP`。
- 虚拟机通过注册地址访问 Gateway health 返回 `UP`，证明 Nacos 中发布的 IP/Port 对服务侧可达。
- 烟测进程随后停止；凭据只从未跟踪环境文件临时注入，未写入命令输出、源码或文档。

## 6. 请求关联与可信用户上下文

| 名称 | 来源 | 行为 |
|---|---|---|
| `X-Trace-Id` | 可接受格式合法的调用方值，否则生成 | 写入下游请求、响应、Exchange Attribute 和 Reactor Context |
| `X-Request-Id` | 可接受格式合法的调用方值，否则生成 | 写入下游请求、响应、Exchange Attribute 和 Reactor Context |
| `X-YGH-User-Id` | 只允许认证过滤器产生的 `CurrentUserPrincipal` | 客户端同名头先删除，认证后重新注入 |
| `X-YGH-Roles` | 同上 | 排序后逗号分隔，限制字符、数量和总长 |
| `X-YGH-Permissions` | 同上 | 排序后逗号分隔，限制字符、数量和总长 |

- Correlation Filter 顺序固定为 `HIGHEST_PRECEDENCE + 10`，最早移除客户端可控的内部身份头。
- JWT Authentication Filter 预留顺序 `+20`；只在验证签名、时间、受众、撤销和账号状态后写入可信 Principal Attribute。
- Trusted User Context Filter 顺序固定为 `+30`；没有可信 Principal 时不会向下游发送任何身份头。
- Correlation ID 限制为 8—64 位安全字符；用户 ID、角色和权限拒绝 CR/LF、逗号注入、超量和超长数据。
- 响应提交前通过 `beforeCommit` 再次用 canonical ID 覆盖同名头，保证下游不能追加或改写成冲突、多值响应。
- Gateway 关键权限/信任边界将模块分支覆盖率门禁提高到 90%；当前两个过滤器共 22 个分支全部覆盖。

## 7. JWT 与路径鉴权边界

- Gateway 是 Spring Security Reactive Resource Server，只接受 Auth JWKS 中可验证的 `RS256` Access Token。
- `issuer`、`jwk-set-uri` 和 `audience` 由 `YGH_JWT_ISSUER/JWK_SET_URI/AUDIENCE` 注入；私钥永远不进入 Gateway。
- 校验链强制签名算法、签名、`exp/nbf`、Issuer 和 Audience；错误 Token 统一返回 401，不返回解析细节。
- 公开端点只包含：POST register/login/refresh/两段密码重置、GET captcha、Actuator health/info；HTTP Method 不匹配仍需认证。
- employee/department/job 路径要求 `EMPLOYEE` 或 `ADMIN` 角色；admin/system/role/permission 路径要求 `ADMIN`；其他 `/api/v1/**` 至少认证，未知非 API 路径 deny-all。
- JWT `roles` 映射到 Spring Authority `ROLE_*`，`permissions` 映射到隔离的 `PERM_*`；Permission Claim 即使写成 `ROLE_ADMIN` 也只能得到 `PERM_ROLE_ADMIN`，不能提升角色。
- JWT Claim 只允许安全字符串数组，角色/权限最多 128 项、编码后最多 4096 字符；用户 ID、Claim 类型和内容异常均 fail-closed。
- JWT Bridge 只执行一次下游链；认证 JWT 被映射为 `CurrentUserPrincipal` Exchange Attribute，再由 Trusted Context Filter 生成内部头。
- 401/403 使用公共 `ApiResponse`，并复用 Correlation WebFilter 提前建立的 canonical traceId。

## 8. Sentinel Gateway 限流与降级

| Route ID | 默认 QPS | 突发额度 | 环境变量 |
|---|---:|---:|---|
| `auth-service` | 20 | 5 | `YGH_GATEWAY_AUTH_QPS/BURST` |
| `user-service` | 100 | 10 | `YGH_GATEWAY_SERVICE_QPS/BURST` |
| `system-service` | 100 | 10 | 同上 |
| `admin-service` | 100 | 10 | 同上 |

- 使用 Sentinel `sentinel-spring-cloud-gateway-v6x-adapter`，按已解析的 Route ID 执行一秒窗口 QPS 与突发流控。
- 启动时对 QPS 的正数、有限值和 burst 的非负值做 fail-fast 校验；QPS 与 burst 上限均为 10,000，禁止无界、NaN 或非法规则进入运行态。
- Sentinel `BlockException` 统一转换为 HTTP 429、业务码 `RATE_LIMITED`，并返回 `Retry-After: 1`；LoadBalancer 无可用实例的 `NotFoundException` 转换为 HTTP 503、业务码 `DEPENDENCY_UNAVAILABLE`。
- 429/503 均使用公共 `ApiResponse` 且包含 canonical traceId；未知异常保持原样交给后续异常链，避免误报依赖故障。
- 当前只加载可重复验证的本地静态基线，不启动 Sentinel Dashboard/Transport 全局线程；Nacos 动态规则、接口级熔断和持久化归 `BE-1003`，不在本任务虚报完成。
- 每个 Gateway 进程只运行一个 Spring ApplicationContext；Sentinel 静态 RuleManager 是 JVM 全局状态，测试保存并恢复原规则且串行锁定该资源。多上下文和动态规则生命周期统一在 `BE-1003` 收口。
- 自动化验证覆盖四条路由规则、非法配置、正 QPS 首次放行/第二次真实阻断、阻断后不执行下游操作、429/503 Envelope 和未知异常透传；Gateway 33 项测试通过，模块分支覆盖率继续高于 90%。
