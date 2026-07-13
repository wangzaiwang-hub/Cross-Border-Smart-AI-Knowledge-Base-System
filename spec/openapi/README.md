# OpenAPI 冻结文件

本目录保存经过真实运行实例导出并由自动化测试验证的接口契约。`auth-service-v1.json` 对应 `/api/v1/auth/**` 与 `/.well-known/jwks.json`，更新时必须先通过 Auth 模块测试和全 Reactor `clean verify`。

所有可运行服务通过 `/v3/api-docs` 和 `/swagger-ui.html` 暴露契约。受限开发环境不向宿主机暴露业务服务端口，默认使用 `docker exec` 从容器内导出；例如平台场景执行：

```powershell
./export-openapi.ps1 -Services gateway,auth,user,system,admin
```

商城、AI、培训场景切换后分别传入对应服务列表。脚本先在临时目录下载并校验 `openapi/info/paths`，同一批全部成功后才替换该批冻结快照，避免半批契约污染仓库。仅在服务端口明确映射到宿主机时使用 `-Transport host -ServiceHost <host>`。前端仍只能访问 Gateway；`spec/bruno` 中的密码和 Token 仅在运行时环境填写。
