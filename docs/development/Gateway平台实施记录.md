# Gateway 平台实施记录

> 模块：`ygh-platform/ygh-gateway`  
> 技术基线：JDK 25、Spring Boot 4.0.7、Spring Cloud Gateway 5.0.2  
> 当前完成：`BE-0301`、`BE-0302`

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
- Nacos 路由与配置、JWT、限流和 Sentinel 分别在后续任务中接入；脚手架阶段不提前初始化外部客户端。

## 3. 基础配置

| 配置 | 默认值 | 说明 |
|---|---:|---|
| `spring.application.name` | `ygh-gateway` | Nacos 服务名基线 |
| `spring.main.web-application-type` | `reactive` | 禁止回退 MVC |
| `server.port` | `8080` | 可由 `YGH_GATEWAY_PORT` 覆盖 |
| Actuator exposure | `health,info` | 当前最小暴露面 |
| Health probes | `true` | 为后续容器探针预留 |
| Health details | `never` | 未认证端点不泄露依赖细节 |

## 4. 验证

```powershell
.\mvnw.cmd -pl ygh-platform/ygh-gateway -am verify
```

结果：6 个 Reactor 模块、36 项测试全部通过；Gateway 真实响应式上下文启动并完成优雅关闭；可执行 JAR 重打包成功。
