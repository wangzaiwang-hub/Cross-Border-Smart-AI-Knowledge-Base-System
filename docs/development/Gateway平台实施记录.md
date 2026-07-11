# Gateway 平台实施记录

> 模块：`ygh-platform/ygh-gateway`  
> 技术基线：JDK 25、Spring Boot 4.0.7、Spring Cloud Gateway 5.0.2  
> 当前完成：`BE-0301`、`BE-0302`、`BE-0303`

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
- Nacos Discovery 通过环境变量接入；JWT、限流和 Sentinel 分别在后续任务中接入。

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
