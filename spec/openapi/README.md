# OpenAPI 冻结文件

本目录保存经过真实运行实例导出并由自动化测试验证的接口契约。`auth-service-v1.json` 对应 `/api/v1/auth/**` 与 `/.well-known/jwks.json`，更新时必须先通过 Auth 模块测试和全 Reactor `clean verify`。

所有可运行服务通过 `/v3/api-docs` 和 `/swagger-ui.html` 暴露契约。集中测试阶段启动服务后执行 `./export-openapi.ps1`，导出 14 个服务的 JSON 快照。`spec/bruno` 是可版本化的前端联调请求集；密码和 Token 仅在运行时环境中填写。
