# Windows IDEA 商城与管理前端手工配置启动操作文档

本文从项目源码已经解压到 `D:\ygh-ai-system`、Node.js 24.18.0 和 pnpm 10.13.1 已安装的状态开始。两个前端都运行在客户 Windows 本机，不在 Rocky Linux 虚拟机、Docker、WSL 中运行。本文不创建 `.env`，不使用 Git，不使用批处理或启动脚本。

## 第一部分：检查前端运行条件

### 第一步：确认 Node.js 和 pnpm 所在位置

**在哪里操作**：Windows 本机 IDEA 底部 `Terminal`。

1. 打开 `D:\ygh-ai-system` 项目。
2. 点击 IDEA 底部 `Terminal`。
3. 确认终端标签是 `PowerShell`。
4. 逐条输入：

```powershell
node --version
pnpm.cmd --version
where.exe node
where.exe pnpm.cmd
```

**执行后的结果**：版本分别为 `v24.18.0` 和 `10.13.1`；路径位于 Windows 的 Node.js 安装目录，通常为 `C:\Program Files\nodejs`。

**故障处理**：若 pnpm 找不到，关闭 IDEA 后重新打开，使新的 PATH 生效；仍找不到时按 Oracle JDK/IDEA/Node 安装文档执行 `corepack enable` 和 `corepack prepare pnpm@10.13.1 --activate`。

### 第二步：确认当前拿到的是完整源码压缩包

**在哪里操作**：IDEA Terminal。

输入：

```powershell
Test-Path 'D:\ygh-ai-system\ygh-web\package.json'
Test-Path 'D:\ygh-ai-system\ygh-web\pnpm-lock.yaml'
Test-Path 'D:\ygh-ai-system\ygh-web\apps\ygh-web-mall\package.json'
Test-Path 'D:\ygh-ai-system\ygh-web\apps\ygh-web-admin\package.json'
```

**执行后的结果**：四行都为 `True`。任何一行为 `False` 都说明解压目录层级不对或交付压缩包不完整，不能继续安装依赖。

### 第三步：确认本项目固定的前端版本和端口

**在哪里操作**：IDEA Terminal。

输入：

```powershell
Get-Content 'D:\ygh-ai-system\ygh-web\package.json'
Get-Content 'D:\ygh-ai-system\ygh-web\apps\ygh-web-mall\package.json'
Get-Content 'D:\ygh-ai-system\ygh-web\apps\ygh-web-admin\package.json'
```

**执行后的结果**：根 `packageManager` 为 `pnpm@10.13.1`；商城脚本使用 Vite `5173`；管理端使用 `5174`。

**注意事项**：不要执行 `npm install`，不要删除 `pnpm-lock.yaml`，不要把依赖升级为 `latest`。

### 第四步：检查网关已经启动

**在哪里操作**：Windows 本机 IDEA Terminal。

输入：

```powershell
Test-NetConnection 127.0.0.1 -Port 8080
Invoke-RestMethod 'http://127.0.0.1:8080/actuator/health'
```

**执行后的结果**：`TcpTestSucceeded=True`，健康状态为 `UP`。

**配置原因**：商城和管理端都通过 Gateway 访问后端。后端网关运行在 Windows IDEA 的 `8080`，不是 Docker 的 `18080`。

### 第五步：检查 5173 和 5174 没有被其他程序占用

**在哪里操作**：IDEA Terminal。

输入：

```powershell
Get-NetTCPConnection -State Listen -LocalPort 5173,5174 -ErrorAction SilentlyContinue |
  Select-Object LocalAddress,LocalPort,OwningProcess
```

**执行后的结果**：第一次启动前应无输出。项目设置了 `strictPort: true`，端口被占用时 Vite 会直接失败，不会偷偷换到其他端口。

## 第二部分：手工安装锁定的前端依赖

### 第六步：进入唯一正确的安装目录

**在哪里操作**：IDEA Terminal。

输入：

```powershell
Set-Location 'D:\ygh-ai-system\ygh-web'
Get-Location
```

**执行后的结果**：路径为 `D:\ygh-ai-system\ygh-web`。

**注意事项**：依赖必须在前端工作区根目录安装一次。不要分别进入 mall 和 admin 执行安装，否则会破坏 pnpm workspace 的统一锁定关系。

### 第七步：查看当前 pnpm 下载源

**在哪里操作**：IDEA Terminal，当前位置仍为 `ygh-web`。

输入：

```powershell
pnpm.cmd config get registry
```

**执行后的结果**：通常显示 `https://registry.npmjs.org/`。该地址可访问时保持不变。

### 第八步：测试 npm 官方源

**在哪里操作**：IDEA Terminal。

输入：

```powershell
pnpm.cmd view vue@3.5.18 version --registry=https://registry.npmjs.org/
```

**执行后的结果**：返回 `3.5.18`，说明官方源可用。

**故障处理**：如果客户网络访问官方源超时，可以临时对本次安装命令指定客户单位认可的 npm 镜像；不能在未测试的情况下永久修改全局 registry，也不能使用来源不明的代理站。

### 第九步：按锁文件安装依赖

**在哪里操作**：IDEA Terminal，目录 `D:\ygh-ai-system\ygh-web`。

输入：

```powershell
pnpm.cmd install --frozen-lockfile
```

**执行后的结果**：最终显示完成信息且退出码为 0；根目录出现或更新 `node_modules`，三个 workspace 被正确链接。

**故障处理**：

1. `ERR_PNPM_OUTDATED_LOCKFILE` 表示压缩包中的 `package.json` 与锁文件不一致，应重新取得完整交付包，不能去掉 `--frozen-lockfile` 强行改锁文件。
2. 网络超时先重试官方源或使用客户认可镜像，不要删除 lockfile。
3. 权限错误时确认源码不在系统保护目录或只读压缩目录。

### 第十步：执行类型检查

**在哪里操作**：IDEA Terminal。

输入：

```powershell
pnpm.cmd run type-check
```

**执行后的结果**：共享包、商城端、管理端均完成 `vue-tsc --noEmit`，命令退出码为 0。

### 第十一步：执行生产构建检查

**在哪里操作**：IDEA Terminal。

输入：

```powershell
pnpm.cmd run build
```

**执行后的结果**：商城和管理端均显示 `built in ...`，各自生成 `dist`。出现 chunk size warning 是体积提示，不等于构建失败；出现红色 error 或非 0 退出码才是失败。

## 第三部分：在 IDEA 配置商城前端

### 第十二步：打开 npm 运行配置窗口

**在哪里操作**：IDEA。

1. 点击 `Run` → `Edit Configurations...`。
2. 点击左上角 `+`。
3. 选择 `npm`。
4. 如果列表中没有 npm，点击 `File` → `Settings` → `Plugins`，确认 JavaScript and TypeScript 插件已启用，然后重启 IDEA。

**执行后的结果**：右侧出现 npm 运行配置表单。

### 第十三步：填写商城 npm 配置

**在哪里操作**：IDEA npm 运行配置表单。

逐项填写：

```text
Name: WEB-01-Mall-5173
package.json: D:\ygh-ai-system\ygh-web\package.json
Command: run
Scripts: dev:mall
Node interpreter: C:\Program Files\nodejs\node.exe
Package manager: pnpm
```

**需要修改的内容**：如果 `where.exe node` 显示的不是 `C:\Program Files\nodejs\node.exe`，`Node interpreter` 改为实际路径。

### 第十四步：在商城运行配置中填写网关变量

**在哪里操作**：同一个 `WEB-01-Mall-5173` 配置。

1. 找到 `Environment variables`。
2. 点击右侧编辑按钮。
3. 点击 `+`。
4. Name 输入 `VITE_GATEWAY_URL`。
5. Value 输入 `http://127.0.0.1:8080`。
6. 点击 `OK` → `Apply`。

**执行后的结果**：商城所有 Axios 请求和 Vite `/api` 代理都指向 Windows IDEA 网关 `8080`。

**注意事项**：不要复制 `apps\ygh-web-mall\.env.example`。其中历史示例端口 `18080` 是容器映射场景，不适用于本文的 IDEA 网关；本教程明确不创建 `.env`。

### 第十五步：启动商城前端

**在哪里操作**：IDEA 顶部运行配置。

1. 选择 `WEB-01-Mall-5173`。
2. 点击绿色运行三角。
3. 查看底部 Run 窗口。

**执行后的结果**：看到类似：

```text
Local:   http://localhost:5173/
```

不能出现 `Port 5173 is already in use`、依赖缺失或 TypeScript 编译错误。

### 第十六步：在浏览器验收商城前端

**在哪里操作**：Windows 浏览器。

1. 打开 `http://127.0.0.1:5173/`。
2. 按 `F12` 打开开发者工具。
3. 切换 `Network`。
4. 刷新页面。

**执行后的结果**：页面能显示，JS/CSS 文件状态为 200；发往后端的请求目标为 `127.0.0.1:8080` 或通过 5173 的 `/api` 代理转发，不应请求 `18080`。

## 第四部分：在 IDEA 配置管理前端

### 第十七步：创建管理端 npm 运行配置

**在哪里操作**：IDEA `Run` → `Edit Configurations...` → `+` → `npm`。

逐项填写：

```text
Name: WEB-02-Admin-5174
package.json: D:\ygh-ai-system\ygh-web\package.json
Command: run
Scripts: dev:admin
Node interpreter: C:\Program Files\nodejs\node.exe
Package manager: pnpm
```

**执行后的结果**：该配置调用根工作区的 `dev:admin`，实际只启动 `@ygh/web-admin`，不会重复启动商城。

### 第十八步：在管理端配置中填写网关变量

**在哪里操作**：`WEB-02-Admin-5174` 的 `Environment variables`。

添加：

```text
Name: VITE_GATEWAY_URL
Value: http://127.0.0.1:8080
```

点击 `OK` → `Apply`。

**注意事项**：不要复制 admin 的 `.env.example`，也不要填写 `18080`。管理端和商城端都访问同一个 Gateway `8080`。

### 第十九步：启动管理前端

**在哪里操作**：IDEA 顶部运行配置。

1. 保持商城运行。
2. 选择 `WEB-02-Admin-5174`。
3. 点击绿色运行三角。
4. 查看独立的 Run 标签。

**执行后的结果**：看到：

```text
Local:   http://localhost:5174/
```

商城 `5173` 和管理端 `5174` 同时监听，互不覆盖。

### 第二十步：在浏览器验收管理前端

**在哪里操作**：Windows 浏览器。

1. 打开 `http://127.0.0.1:5174/`。
2. 打开开发者工具 `Network`。
3. 刷新页面。
4. 检查静态资源和 API 请求。

**执行后的结果**：页面正常显示，静态文件为 200，API 走 Gateway `8080`。未创建管理员账号或未分配权限时登录/业务接口可能返回 401 或 403，这与前端没有启动是两类问题。

## 第五部分：启停、验收和故障处理

### 第二十一步：检查两个前端端口

**在哪里操作**：IDEA Terminal。

输入：

```powershell
Get-NetTCPConnection -State Listen -LocalPort 5173,5174 |
  Sort-Object LocalPort |
  Select-Object LocalAddress,LocalPort,OwningProcess
```

**执行后的结果**：显示 5173 和 5174 两行监听记录。

### 第二十二步：检查页面 HTTP 状态

**在哪里操作**：IDEA Terminal。

输入：

```powershell
(Invoke-WebRequest 'http://127.0.0.1:5173/' -UseBasicParsing).StatusCode
(Invoke-WebRequest 'http://127.0.0.1:5174/' -UseBasicParsing).StatusCode
```

**执行后的结果**：两行均为 `200`。

### 第二十三步：正确停止两个前端

**在哪里操作**：IDEA 底部 `Services` 或 `Run` 窗口。

1. 选中 `WEB-02-Admin-5174`，点击红色方块。
2. 等待管理端进程结束。
3. 选中 `WEB-01-Mall-5173`，点击红色方块。
4. 再执行第五步端口检查，应无输出。

**注意事项**：不要关闭整个 IDEA 来代替停止进程，不要在任务管理器批量结束 Node.js，以免结束其他项目。

### 第二十四步：处理浏览器能打开但接口失败

| 现象 | 原因 | 操作 |
|---|---|---|
| 页面打开，接口 `ERR_CONNECTION_REFUSED` | Gateway 8080 未启动 | 回到后端文档启动 Auth、System、Gateway并检查健康 |
| 请求发往 `18080` | 复制了旧示例或 IDEA 变量错误 | 删除错误 `.env`，IDEA 中设 `VITE_GATEWAY_URL=http://127.0.0.1:8080` 后重启 Vite |
| 浏览器出现 CORS 错误 | Gateway 允许来源缺少 5173/5174 | 核对 Gateway 的 `YGH_GATEWAY_CORS_ALLOWED_ORIGINS` |
| 返回 401 | 未登录、Token 无效或 Auth/JWKS 不可用 | 先检查 Auth 和 Gateway，不要修改前端绕过认证 |
| 返回 403 | 当前账号无管理权限 | 在 System 权限体系中正确授权，不要关闭权限校验 |
| Vite 报端口占用 | 上次进程未停止或其他程序占用 | 用 `Get-NetTCPConnection` 找 PID，先确认进程归属再停止 |
| 安装后类型错误 | 压缩包版本不一致或用户改动未完成 | 核对交付包哈希和 `pnpm-lock.yaml`，不能用 `--force` 跳过 |

### 第二十五步：记录前端验收结果

**在哪里操作**：客户交付记录。

记录：

```text
Node.js：24.18.0
pnpm：10.13.1
Gateway：http://127.0.0.1:8080
商城：http://127.0.0.1:5173
管理端：http://127.0.0.1:5174
type-check：通过/未通过
build：通过/未通过
商城 HTTP：
管理端 HTTP：
验收时间：
```

**执行后的结果**：客户可以从源码、锁文件、IDEA 配置到浏览器请求逐层定位问题，不依赖 `.env` 或任何启动脚本。
