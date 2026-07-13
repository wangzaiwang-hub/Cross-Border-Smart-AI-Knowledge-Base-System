# API 安全测试规范

发布候选环境必须同时经过静态依赖/Secret 扫描、后端权限测试和 OWASP ZAP OpenAPI 动态扫描。动态扫描只允许对隔离的 SIT/验收环境执行，不得扫描未授权外部系统或生产数据。

扫描命令遵循 [OWASP ZAP 官方 API Scan 文档](https://www.zaproxy.org/docs/docker/api-scan/)。脚本在临时副本中覆盖 OpenAPI `servers`，不会修改冻结契约。

```powershell
.\ygh-deploy\scripts\run-api-security-scan.ps1 `
  -TargetUrl http://host.docker.internal:8081 `
  -OpenApiFile .\spec\openapi\auth-service-v1.json
```

默认任何 ZAP 告警导致命令失败；首次基线调查可使用 `-AlertLevel WARN` 生成报告，但不能据此关闭 `BE-1207`。误报必须记录 URL、规则 ID、请求证据和复核人，禁止通过全局忽略规则消除真实风险。

安全验收至少覆盖：认证绕过、JWT 篡改与过期、水平/垂直越权、暴力登录、SQL 注入、XSS、CSRF、安全上传、敏感信息泄露、错误响应泄露和缺失安全 Header。P0/P1 缺陷必须清零后才能签署发布候选版本。
