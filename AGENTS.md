# Project Agent Map

## Goal

使用 Java 25、Spring Boot 4.0.7 和 Spring Cloud Alibaba 构建可分模块开发、可容器化部署的跨境电商知识库、AI 客服、商城与培训系统。

## Repository Structure

- `docs/`：需求、架构和开发记录。
- `spec/`：可执行技术规格。
- `ygh-deploy/`：本机与虚拟机 Docker Compose、配置模板和运维脚本。
- `docs/development/`：量化验收标准与验证证据。
- `docs/development/环境配置台账.md`：Windows、WSL2、Docker Desktop、虚拟机与组件的脱敏实测台账。
- `docs/development/后端接口与前端接入清单.md`：接口、DTO、错误码、权限、事件和前端联调状态的唯一人工可读清单。
- `docs/development/后端建设总TODO.md`：后端从工程基础到部署交付的唯一总进度表，前端阶段排在最后。
- `spec/backend-delivery.md`：后端交付闭环、契约、安全、测试和完成定义。
- 后续 Java 根工程和业务副项目结构以 `docs/项目设计架构文档.md` 为准。

## Constraints

- 使用 Maven 主项目、业务副项目、功能子项目和独立 `pom.xml`。
- JDK 25、Spring Boot 4.0.7、Spring Cloud 2025.1.2 和 Spring Cloud Alibaba 2025.1.0.0 组合必须经过兼容性验证。
- 不提交密码、Token、豆包 API Key、真实 `.env` 或原始业务文件。
- 当前低配置环境按场景 profile 启停，不伪称具备全量常驻或生产容量。
- 服务器配置和个人开发配置分离；生产配置不得依赖开发机地址。
- 修改虚拟机或本机系统配置前保留备份，并提供回滚方式。
- 不跳过健康检查、资源检查和验证证据。
- 多代理共享同一工作区时禁止并发执行 Maven `clean`，避免相互删除 `target` 导致伪失败。
- 后端开发必须同步维护 OpenAPI 与前端接入清单；接口没有权限、错误码和测试证据时不得标记为可联调。
