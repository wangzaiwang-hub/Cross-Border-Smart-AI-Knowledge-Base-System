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
