# OpenAPI 冻结文件

本目录保存经过真实运行实例导出并由自动化测试验证的接口契约。`auth-service-v1.json` 对应 `/api/v1/auth/**` 与 `/.well-known/jwks.json`，更新时必须先通过 Auth 模块测试和全 Reactor `clean verify`。
