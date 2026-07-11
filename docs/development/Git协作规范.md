# Git 协作规范

## 1. 分支

- 稳定主分支：`main`。
- 功能分支：`feat/<scope>-<description>`。
- 修复分支：`fix/<scope>-<description>`。
- 禁止直接提交密码、Token、API Key、私钥、真实 `.env` 和原始需求文件。

## 2. 提交

提交格式为：

```text
<type>(<scope>): <subject>
```

允许的 `type`：`feat`、`fix`、`docs`、`test`、`refactor`、`chore`、`build`。

每个提交只包含一个可说明、可验证、可回滚的逻辑变更。提交前必须执行：

```powershell
powershell -ExecutionPolicy Bypass -File ygh-deploy/scripts/check-staged-secrets.ps1
.\mvnw.cmd clean verify
```

## 3. 阶段提交门禁

1. 测试先行时可以保留红灯证据，但不得把无法构建的中间状态合并到 `main`。
2. TODO 只有在实现、测试和证据齐全后才能勾选。
3. 数据库迁移、事件 Schema、外部 API 和权限码的破坏性变更必须单独说明兼容策略。
4. 部署记录必须关联 Git SHA；本地未提交改动不得作为正式部署基线。

## 4. GitHub 交付目标

- 唯一远程仓库：`https://github.com/wangzaiwang-hub/Cross-Border-Smart-AI-Knowledge-Base-System.git`。
- 当前已验收基线允许推送到 `main` 作为远程灾备；后续功能使用 `feature/*` 分支开发并通过 Pull Request 合并。
- 项目完成不等于本地构建成功；必须完成最终 Secret 扫描、推送、远程 SHA 核对、版本标签和发布说明才算交付。
