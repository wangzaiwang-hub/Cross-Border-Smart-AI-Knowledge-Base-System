# 2026-07-12 后端开发进度

## 1. BE-0306 Sentinel Gateway 限流与可识别降级

- Test-Author 先建立四条路由规则、非法配置、真实 Sentinel 阻断以及 429/503 响应契约测试；生产类缺失时测试编译按预期失败。
- Gateway 接入 Sentinel Gateway WebFlux Adapter，认证路由默认 20 QPS + 5 burst，业务路由默认 100 QPS + 10 burst，全部可由环境变量覆盖。
- QPS 必须为正数且有限，burst 必须非负，二者最大值均为 10,000；非法启动参数 fail-fast，不以无界规则继续运行。
- Sentinel 流控异常返回统一 429 `RATE_LIMITED` 和 `Retry-After: 1`；Nacos/LoadBalancer 无服务实例返回统一 503 `DEPENDENCY_UNAVAILABLE`，两者均携带 canonical traceId。
- 未识别异常不伪装成降级响应，继续交给 WebFlux 异常处理链。
- 采用直接 Gateway Adapter，测试 JVM 可正常退出；动态 Nacos 规则和 Sentinel 治理留待 `BE-1003`。
- Reviewer 指出的缺少 `Retry-After` P1 已修复；限流测试改用合法 1 QPS 规则，证明首次请求通过、第二次被拒绝且下游操作不执行。测试保存并恢复 Sentinel JVM 全局规则，避免污染后续用例。
- `mvnw.cmd -pl ygh-platform/ygh-gateway -am verify` 通过：受影响 Reactor 6 个模块、Gateway 33 项测试，Gateway 分支覆盖率门禁 90% 通过。

## 2. BE-0307 CORS、请求大小、上传路径与安全 Header

- Test-Author 先建立 exact-origin CORS、配置拒绝、Content-Length/chunked 超限、精确上传路径和安全响应头测试；生产类缺失时测试编译按预期失败。
- CORS Origin 改为部署环境必填，基础配置没有 localhost 默认；独立 CORS Filter 位于请求 Guard 之前，真实浏览器可读取 411/413/403 的统一 Envelope。
- 普通请求默认 2 MiB，未知长度请求在路由前有界缓存；multipart 默认 50 MiB、必须提供 Content-Length，避免低配置机器缓存大文件。
- multipart 仅允许三个精确 POST 端点；尾斜杠、子路径、矩阵参数、错误方法和非白名单路径均拒绝。
- Reviewer 发现原流式实现会让超限异常先穿过 Reactor Netty HttpClient 并形成可放大 WARN 堆栈；现改为路由前准入。真实 Netty 断言 2 MiB+ chunked 请求返回 413、业务下游调用为 0、HttpClientConnect 无 WARN。
- 安全头在 beforeCommit 规范化，移除 Server；默认 no-store 但保留下游明确缓存策略，直接 HTTPS 增加 HSTS。
- Reviewer 随后识别 `Mono<Void>` 空完成可能触发 `switchIfEmpty` 二次下游调用；现使用 `singleOptional` 物化空/非空状态，单元与真实 Netty 均证明合法 chunked 请求下游恰好执行一次。
- `mvnw.cmd -pl ygh-platform/ygh-gateway -am clean verify` 通过：Gateway 43 项测试、0 失败，分支覆盖率 95.78%；最终复审 P0/P1 清零。

## 3. BE-0308 Actuator 与 Nacos 注册验证

- 新增 `/actuator/health/liveness`、`/actuator/health/readiness`、`/livez` 和 `/readyz`，四个真实 Netty 探针均返回 `UP` 且不泄露 components。
- 匿名开放面收敛到四个健康路径、health 根和 info；`env` 与任意组件级 health 路径仍受保护。
- 配置优雅停机与 20 秒阶段超时；readiness 仅代表应用可接流量，Nacos 注册使用独立验证脚本确认。
- `verify-gateway-registration.ps1` 使用环境变量凭据和 Nacos v3 Admin API，具备注册异步轮询且不输出 Token。
- 真实烟测结果：本机 live/ready `UP`；虚拟机反向访问 `192.168.154.1:18080` 为 `UP`；Nacos 精确命中 `YGH_GROUP@@ygh-gateway 192.168.154.1:18080 healthy=true`。
- 正常结束烟测后本机 18080 listener 为 0，Nacos 不再保留目标实例；虚拟机核心组件未停止。
- Reviewer 审查 P0/P1 为 0；在途请求 drain 留待 `BE-1225`，Nacos 纳入 readiness 的治理决策留待 `BE-1101`。

## 4. BE-0309 Gateway 真实契约集成测试

- 新增真实随机端口测试链：Netty Gateway、Spring Security、Nimbus 远程 JWKS、四条 LB 服务发现记录和 embedded backend。
- RSA 2048/RS256 Token 包含 kid/use=sig、issuer、audience、nbf、exp 和角色权限；显式证明 JWKS 远程请求一次。
- 真实 HTTP 验证 401、403、auth/user/system/admin 四类路由、可信内部用户头，以及 429/Retry-After/traceId。
- 429 故障注入请求未进入 backend；合法 count=1 阈值仍由 Sentinel 单元集成测试覆盖。
- 集成测试最初暴露 JWKS 测试服务使用 `request.path()` 时缺少前导斜杠，导致返回空 JWKS 选择结果；修正为 URI path 后，真实 Resource Server 链路通过。这也证明 `mockJwt` 不能替代最终 HTTP 认证证据。
- Reviewer 复审 P0/P1 为 0；Gateway P03.1 全部任务完成。
- Gateway 阶段执行根 Reactor `mvnw.cmd clean verify`：220 项测试、0 失败/错误/跳过；Gateway 分支覆盖率 95.78%。
