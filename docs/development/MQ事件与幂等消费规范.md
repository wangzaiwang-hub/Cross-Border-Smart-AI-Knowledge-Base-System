# MQ 事件与幂等消费规范

> 公共模块：`ygh-common-core`、`ygh-common-mq`  
> 投递语义：至少一次  
> 状态：`BE-0233` 公共内核完成；RocketMQ 适配与真实 Broker 链路在 `BE-0542`

## 1. Event Envelope

所有跨服务事件复用 `DomainEvent<T>` / `VersionedDomainEvent<T>`，固定元数据：

| 字段 | 规则 |
|---|---|
| `eventId` | 全局唯一，1—128 位安全标识 |
| `eventType` | 大写稳定代码，最长 64 位 |
| `eventVersion` | 从 1 开始，只增不改 |
| `occurredAt` | 带时区 ISO 8601，固定输出秒，保留纳秒和原始偏移 |
| `traceId` | 1—128 位安全追踪标识 |
| `producer` | 小写服务代码，最长 64 位 |
| `businessKey` | 业务唯一键，1—128 位 |
| `payload` | 不可变、类型化 DTO；禁止 Entity 和可变集合 |

`MqEnvelopePolicy` 在进入消息基础设施前再次校验自定义 `DomainEvent`，拒绝控制字符、超长字段和不完整 Envelope，避免毒消息进入 Broker 后无法落死信。

`MqMessageHeaders` 只复制上述路由/追踪元数据，不放 Token、Cookie、密码、地址、异常文本或完整 Payload。

## 2. 消费状态机

`IdempotentMessageConsumer` 的结果只有：

| 结果 | 含义 | RocketMQ 适配目标 |
|---|---|---|
| `ACKNOWLEDGED` | 本地业务效果与 SUCCEEDED 同事务提交 | ACK |
| `DUPLICATE` | 已成功或已进入受管死信终态 | ACK |
| `RETRY` | 活跃 Claim、暂时失败、基础设施失败或状态不确定 | RECONSUME_LATER |
| `DEAD_LETTERED` | 受管死信记录与终态同事务提交 | ACK，并触发告警/人工处理 |

业务失败分类：

- `RetryableMessageException`：在最大尝试次数内重试。
- `NonRetryableMessageException`：立即写受管死信。
- 未分类业务异常：达到最大尝试次数后以 `UNEXPECTED_CONSUMER_FAILURE` 写死信。
- `MessageInfrastructureException`：无论第几次投递都返回 `RETRY`，不得误写业务死信。
- `InterruptedException`：恢复线程中断标志并返回 `RETRY`。

死信只保存稳定失败码和安全元数据，不保存异常 message、堆栈、Payload 或凭据。

## 3. Claim 与事务要求

每次 Claim 由 Consumer 生成新的 192 bit 安全随机 owner。Store 的获取、完成、释放和死信操作都必须比较 owner；旧 Claim 不能完成、释放或死信后来持有者。

租约范围为 1 秒至 15 分钟，由持久化 Store 自己的 `Clock` 或数据库时间计算，不接受调用方注入当前时间。

`JdbcMessageConsumptionStore` 提供可复用参考实现：

1. `(consumer_group, event_id)` 唯一约束保证并发唯一 Claim。
2. 活跃 Claim 返回 `IN_PROGRESS`；过期 Claim 用条件更新重领。
3. 业务处理与 `SUCCEEDED` 在同一本地数据库事务提交。
4. Handler 抛异常时业务写入与成功状态一起回滚。
5. 死信记录与 `DEAD_LETTERED` 在同一事务提交。
6. 唯一键冲突后记录被并发释放时返回重试，绝不误判 Duplicate ACK。
7. 事务、提交和 JDBC 运行时故障统一包装为 `MessageInfrastructureException`。

## 4. 数据表契约

每个实际消费者 Service 必须通过自己的 Flyway 迁移创建表，公共模块不向所有数据库自动注入 DDL。

```sql
CREATE TABLE mq_consumption (
    consumer_group VARCHAR(64) NOT NULL,
    event_id VARCHAR(128) NOT NULL,
    status VARCHAR(32) NOT NULL,
    owner VARCHAR(128),
    lease_until TIMESTAMP(6),
    created_at TIMESTAMP(6) NOT NULL,
    updated_at TIMESTAMP(6) NOT NULL,
    PRIMARY KEY (consumer_group, event_id)
);

CREATE TABLE mq_dead_letter (
    consumer_group VARCHAR(64) NOT NULL,
    event_id VARCHAR(128) NOT NULL,
    event_type VARCHAR(64) NOT NULL,
    event_version INT NOT NULL,
    business_key VARCHAR(128) NOT NULL,
    trace_id VARCHAR(128) NOT NULL,
    delivery_attempt INT NOT NULL,
    failure_code VARCHAR(64) NOT NULL,
    failed_at TIMESTAMP(6) NOT NULL,
    PRIMARY KEY (consumer_group, event_id)
);
```

正式迁移还要增加状态 CHECK/字典约束、运维查询索引和审计字段，并使用 MySQL Testcontainers 验证；不能直接复制测试 H2 schema 作为生产迁移。

## 5. 已验证边界

H2 MySQL 模式真实 JDBC 事务测试覆盖：

- 10 个并发 Claim 只有一个成功。
- 10 个并发完整投递只有一次业务效果。
- Handler 写库后抛异常，业务效果回滚。
- 成功效果与 `SUCCEEDED` 同事务提交。
- 租约过期重领后 stale owner 无法完成、释放或写死信。
- 死信与终态原子提交；死信插入失败时终态回滚。
- 提交故障归类为基础设施失败，业务效果回滚。
- 唯一键冲突与并发释放窗口不产生错误 ACK。

## 6. 后续 RocketMQ 门禁

`BE-0233` 不宣称 RocketMQ Broker 生产消费已经完成。`BE-0542` 必须继续实现并验证：

1. Spring Cloud Stream RocketMQ 生产/消费适配器。
2. Broker deliveryAttempt 到公共 Consumer 的准确映射。
3. `ACKNOWLEDGED/DUPLICATE/DEAD_LETTERED` 到 ACK 的映射。
4. `RETRY` 到 RECONSUME_LATER、重试延迟和最大次数的映射。
5. Broker DLQ 与系统受管死信的边界、告警和人工补偿。
6. RocketMQ 5.3.1 真实 Broker 的重复投递、重启恢复和消息重放。
7. 生产侧 Outbox 或事务消息与数据库事实的一致性。

