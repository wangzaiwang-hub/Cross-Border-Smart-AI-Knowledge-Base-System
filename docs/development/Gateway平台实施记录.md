# Gateway 平台实施记录

> 模块：`ygh-platform/ygh-gateway`  
> 技术基线：JDK 25、Spring Boot 4.0.7、Spring Cloud Gateway 5.0.2  
> 当前完成：`BE-0301`—`BE-0308`

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

## 9. CORS、请求准入与安全响应头

### 9.1 CORS

- `YGH_GATEWAY_CORS_ALLOWED_ORIGINS` 是无默认值必填项；基础配置不包含 localhost 或任何开发机 Origin，漏配时启动 fail-fast。
- 只接受无路径、查询、Fragment、UserInfo 的合法 HTTP(S) Origin，拒绝 `*`、空列表、非法端口和畸形 URI。
- 允许方法固定为 GET/POST/PUT/PATCH/DELETE/OPTIONS；允许 Header 和暴露 Header 采用最小白名单，credentials 开启，预检缓存 3600 秒。
- 独立 CORS WebFilter 顺序为 `HIGHEST_PRECEDENCE + 12`，早于请求 Guard 的 `+15`；因此 Guard 直接返回的 411/413/403 仍带可信 Origin 的 CORS Header，浏览器可以读取统一错误体。

### 9.2 请求体与上传路径

| 类型 | 默认上限 | 行为 |
|---|---:|---|
| 普通请求 | 2 MiB | Content-Length 早期拒绝；chunked 在路由前最多有界缓存 2 MiB，超限不连接下游 |
| multipart 上传 | 50 MiB | 必须提供 Content-Length；超限返回 413，无长度返回 411 |

- 两类上限均不得超过 100 MiB，且上传上限不得小于普通请求上限；非法配置启动失败。
- multipart 只允许 POST 到三个精确端点：`/api/v1/knowledge/documents`、`/api/v1/training/documents`、`/api/v1/products/images`；其他方法、尾斜杠、子路径、矩阵参数和近似路径返回 403。
- 普通 chunked 请求在连接业务服务前使用 Spring DataBuffer 的有界 join；缓冲体支持安全重放并在链结束释放。空/非空请求均物化为单一 Optional 后只调用一次下游链。真实 Netty 测试证明 2 MiB+ 请求返回 413、下游调用数为 0 且 `HttpClientConnect` 不产生 WARN；合法 chunked 请求只调用一次下游。
- 文件扩展名、MIME 白名单、恶意内容扫描和业务权限仍由 Knowledge/Product/Training 服务在对应阶段完成；Gateway 只承担边缘总量和路径准入，不替代业务校验。

### 9.3 安全响应头

- 在响应提交前规范化 `nosniff`、`DENY` Frame、`no-referrer`、Permissions Policy 和 API CSP，并删除 `Server` 版本泄露。
- 下游未声明缓存策略时使用 `Cache-Control: no-store`；下游明确声明的可缓存商品资源策略予以保留。
- Gateway 直接收到 HTTPS 请求时写入一年 HSTS；企业部署若在受信反向代理终止 TLS，由代理负责外层 HSTS 和 Forwarded Header 信任边界，最终在 `BE-1223` 验证。
- 真实 Netty 与单元测试共 43 项全部通过，Gateway 分支覆盖率 95.78%，高于 90% 阻断阈值。

## 10. Actuator 探针与 Nacos 注册验证

- Actuator 只暴露 `health,info`；匿名路径精确限制为 health 根、liveness/readiness 两个分组以及 `/livez`、`/readyz`，不使用 `/actuator/health/**` 通配。`env` 和任意组件级 health 路径不能匿名访问。
- 所有公开 health 响应保持 `show-details: never`，真实 Netty 断言只返回 `status=UP`，不出现 `components`。
- `/livez` 只说明进程存活；`/readyz` 只表示 Spring ApplicationAvailability 已准备接流量，不等价于 Nacos 已注册、JWKS 可用或所有共享下游健康。Nacos 注册状态必须由独立注册验证完成，不能把共享依赖错误加入 liveness 造成重启风暴。
- 开启 `server.shutdown=graceful`，单阶段停机超时为 20 秒；在途请求 drain 的故障注入验证归 `BE-1225`。
- 新增 `verify-gateway-registration.ps1`：凭据只接受环境变量注入，登录 Nacos 后轮询 v3 Admin API，精确核对 Namespace/Group/Service/IP/Port/healthy/enabled。临时 Token 不输出且异常被收敛为无 Token 的错误；当前 Nacos v3 Admin GET 接口使用 accessToken 查询参数，部署侧不得记录完整 Query String。

真实环境验证（2026-07-12）：

| 检查 | 结果 |
|---|---|
| 本机 `/livez`、`/readyz` | `UP` |
| 虚拟机访问 `192.168.154.1:18080/livez` | `UP` |
| Nacos 实例 | `YGH_GROUP@@ygh-gateway -> 192.168.154.1:18080` |
| Nacos 状态 | `healthy=true`、唯一精确匹配 |
| 正常停止 | 本机监听端口为 0；Nacos 目标实例消失 |

烟测结束后 Gateway 进程已停止；虚拟机 MySQL、Redis、Nacos 保持原有健康运行状态，没有把 Java 服务常驻在低配环境。
