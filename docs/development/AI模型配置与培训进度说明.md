# AI 模型配置、知识检索与培训进度说明

## 1. 管理员前端配置模型

管理员进入 `http://localhost:5174/ai`，点击“模型 API 配置”，填写：

- 服务商：豆包 Ark；
- API 地址：默认 `https://ark.cn-beijing.volces.com/api/v3`；
- API Key：首次必填，后续留空表示沿用原密钥；
- 对话模型：可选官方预设，也可输入账号控制台分配的 Model ID 或 Endpoint ID；
- 向量模型：可选官方预设，也可输入账号控制台分配的 Model ID 或 Endpoint ID。

保存请求发往 `PUT /api/v1/system/ai-provider-config`。System 服务使用 AES-256-GCM 加密 API Key，数据库仅保存密文和随机 nonce；查询接口只返回“已配置”状态，不返回明文。AES 主密钥由 `YGH_SYSTEM_CONFIG_MASTER_KEY_BASE64` 注入，必须是 32 字节 Base64，且不得提交 Git。

AI 与 Search 服务在每次真实模型调用前，通过 HMAC 签名的 `GET /internal/v1/system/ai-provider-config` 读取当前版本。配置版本变化时重新创建模型客户端，因此无需修改后端配置文件或重启容器。System 临时不可用时，只允许使用进程内最后一次成功读取的配置，不把 API Key 写日志、缓存文件或 Redis。

## 2. 知识库如何供 AI 使用

知识文档必须依次经过：上传、安全校验、解析切片、审核通过、发布、索引。只有已发布且当前用户有权访问的知识切片，才能进入 Elasticsearch 与 PGVector 的有效索引。

AI 问答使用现有受控 RAG 链路：

1. AI 服务把问题和用户可见范围发送给 Search；
2. Search 执行 Elasticsearch 全文检索与 PGVector 向量检索；
3. 混合结果重排后返回文档 ID、切片 ID、标题、版本和更新时间；
4. AI 只根据这些证据生成答案并返回引用；
5. 没有合格证据时拒答，不允许模型自行编造政策或通关结论。

后台上传后仍处于“待审核”的文档不会出现在前台，也不会被 AI 使用。管理员必须在知识库治理页面审核通过，等待解析和索引任务成功；失败任务可重试或执行全量重建。

## 3. 文档任务点与员工进度

每个培训章节中的有效文档都是一个独立任务点，状态为：

- `NOT_STARTED`：未开始；
- `IN_PROGRESS`：已打开但未标记完成，前端显示“未完成”；
- `COMPLETED`：已标记完成。

员工必须在自己的学习任务中打开文档。下载接口会校验任务归属、课程关系和文档状态，并在服务端记录首次打开时间。只有已经打开的文档才能通过完成接口，前端不能直接伪造“已完成”。

课程完成需要同时满足：

- 所有有效文档任务点已完成；
- 所有章节达到管理员设置的有效学习时长；
- 所有关卡测验通过。

员工可在“我的学习任务”和“学习档案”查看本人课程进度；管理员可在“培训运营 → 员工进度”查看每个员工的课程、文档完成数、总进度、状态和最好成绩。

## 4. 新增接口

| 方法与路径 | 权限 | 用途 |
|---|---|---|
| `GET /api/v1/system/ai-provider-config` | `ADMIN` / `ai:config:read` | 查询脱敏模型配置 |
| `PUT /api/v1/system/ai-provider-config` | `ADMIN` / `ai:config:write` | 加密保存并发布新配置版本 |
| `GET /internal/v1/system/ai-provider-config` | HMAC：AI/Search | 获取运行时完整配置 |
| `GET /api/v1/training/learning/assignments/{id}/documents?chapterId=...` | 本人任务 | 查询文档任务点状态 |
| `POST /api/v1/training/learning/assignments/{id}/documents/{documentId}/complete` | 本人任务 | 完成已打开的文档任务点 |
| `GET /api/v1/training/learning/admin/employee-progress` | `training:statistics:read` | 管理员查看员工级进度 |

## 5. 数据表

- `system_ai_provider_config`：单例模型配置；API Key 使用 AES-GCM 密文存储，配置用乐观锁更新。
- `system_configuration_audit`：只记录配置变更前后 SHA-256 摘要和操作人，不记录密钥。
- `training_document_progress`：以 `(assignment_id, document_id)` 为主键记录任务点状态、首次打开时间、完成时间和版本。

## 6. 验证命令

```powershell
.\mvnw.cmd -pl ygh-applications/ygh-system/ygh-system-service,ygh-applications/ygh-ai/ygh-ai-service,ygh-applications/ygh-search/ygh-search-service,ygh-applications/ygh-training/ygh-training-service -am test

Set-Location ygh-web
pnpm type-check
pnpm build
```
