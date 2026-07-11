# Redis 公共能力规范

> 适用模块：`ygh-common-redis` 及所有使用 Redis 的业务 Service  
> 运行基线：Spring Boot 4.0.7、Spring Data Redis、Redis 8.4.4  
> 状态：`BE-0232` 已实现并通过真实 Redis 验证

## 1. 使用边界

Redis 只承载可过期、可重建或短期协调数据：会话撤销、验证码、限流、幂等结果、热点缓存和必要的短租锁。订单、余额、库存、权限和学习完成状态的最终事实必须保存在所属数据库。

公共模块提供：

- `RedisKeyBuilder`：统一命名空间与输入校验。
- `RedisKeyIdentifier`：SHA-256 与带 Secret pepper 的 HMAC-SHA-256 标识符。
- `TtlJitterPolicy`：缓存 TTL 和最短保留期 TTL 的不同抖动策略。
- `RedisDistributedLock`：带租约、随机 owner、原子续租和原子释放的短租锁。
- `YghRedisAutoConfiguration`：在 Boot 的 `DataRedisAutoConfiguration` 之后装配公共 Bean。

## 2. Key 规范

唯一标准格式：

```text
ygh:{env}:{service}:{business}:{identifier}
```

规则：

1. `env/service/business` 只允许小写字母、数字和连字符，单段 1—32 字符。
2. `identifier` 只允许字母、数字、点、下划线和连字符，1—128 字符。
3. 禁止空白、冒号、花括号、通配符、控制字符和路径片段，避免碰撞、扫描和 Redis Cluster hash-tag 误用。
4. 邮箱、手机号、证件号等低熵敏感值必须使用 `hmacSha256(value, pepper)`；pepper 至少 32 字节并由环境变量或 Secret 注入。
5. 普通高熵、不可逆业务标识可使用 `sha256`，但不得将密码、Token、地址或原始个人信息直接写入 Key。

示例：

```text
ygh:dev:product:detail:10001
ygh:prod:auth:blacklist:01JZ8K8M6R4QZP2W
ygh:prod:order:idempotency:7e570c...
```

## 3. TTL 规则

所有临时 Key 必须显式设置 TTL，禁止无界常驻。公共策略最大接受 10 年基础 TTL，超界、零值、负值和计算溢出直接失败。

- `cacheTtl(base)`：对可重建缓存做对称抖动，默认范围为基础值的 ±10%，降低集中失效雪崩。
- `minimumRetentionTtl(minimum)`：只增加、不缩短，用于 Token 黑名单、会话撤销、幂等记录和其他安全最短保留期。

不得把 `cacheTtl` 用于有法定、审计、安全或幂等最短保留要求的数据。

## 4. 短租分布式锁

获取使用 Redis 原子 `SET key owner NX PX lease`；续租和释放均以单 Key Lua 脚本先比较 owner，再执行 `PEXPIRE` 或 `DEL`。

强制约束：

1. owner 每次获取使用 192 bit 安全随机数，不包含用户、主机或进程信息。
2. 租约范围为 1 秒至 5 分钟，不提供无 TTL 锁。
3. 获取失败不返回其他持有者信息。
4. `RedisLockHandle.toString()` 永久脱敏 owner，Jackson JSON 忽略 owner。
5. 过期旧 owner 不得释放或续租后来持有者的锁。
6. 锁调用必须处理获取失败、业务超时和释放返回 false，不允许无限自旋。

该实现没有 Fencing Token。库存、钱包和订单正确性必须继续依赖数据库条件更新、版本号、唯一键和本地事务；Redis 锁只能降低并发冲突，不能作为唯一一致性屏障。

## 5. 自动配置与连接

业务 Service 引入 `ygh-common-redis` 后，仍需通过环境配置提供 Redis 连接：

```yaml
spring:
  data:
    redis:
      host: ${REDIS_HOST}
      port: ${REDIS_PORT:6379}
      password: ${REDIS_PASSWORD}
      database: ${REDIS_DATABASE:0}
      connect-timeout: 2s
      timeout: 2s
```

密码不得写入仓库。开发环境 Redis 常驻虚拟机 `192.168.154.10:6379`；本机 Docker 只为 Testcontainers 自动化测试临时启动 Redis，测试结束后容器自动清理，不改变部署归属。

## 6. 验证范围

自动化测试覆盖：

- Key 合法/非法输入与 HMAC pepper。
- 缓存对称抖动、最短保留期只增抖动和超大 TTL 边界。
- owner 脱敏与 Jackson 3 JSON 防泄漏。
- Boot 4 Redis 自动配置排序及真实 Bean 链。
- Redis 8.4.4 Testcontainers 的 NX/PX、错误 owner、续租、释放、过期重入和 16 并发唯一成功。
- 虚拟机 Redis 8.4.4 的错误/正确 owner 续租与释放实测。

模块验证：

```powershell
.\mvnw.cmd -pl ygh-common/ygh-common-redis -am test
```

