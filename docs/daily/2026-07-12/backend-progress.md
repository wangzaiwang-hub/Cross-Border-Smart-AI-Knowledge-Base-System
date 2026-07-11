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
