# Figma React 原型转 Vue 企业前端重构记录

## 1. 输入与结论

输入文件为仓库根目录的 `Design_System_SaaS_Landing_Page.zip`。审计确认其运行技术为 React 18、TypeScript、Vite、React Router、MUI/Radix 与 Recharts，核心实现集中在约 1552 行的单个 `App.tsx` 中。

原型已经覆盖商城、个人中心、培训和部分后台页面，但不满足项目冻结的 `Vue 3 + TypeScript + Vite + Element Plus` 技术要求，也不符合企业项目的应用拆分、共享鉴权、权限路由和类型安全 API 边界。因此没有直接把 React 代码作为正式源码提交，而是保留 ZIP 作为用户原始设计资产，重新实现 Vue 工程。

## 2. 正式工程结构

```text
ygh-web/
├─ apps/
│  ├─ ygh-web-mall/       # 公共商城、知识、AI、个人中心、培训
│  └─ ygh-web-admin/      # 企业运营后台
├─ packages/
│  └─ ygh-web-shared/     # 响应、会话、HTTP、SSE 和共享业务类型
├─ scripts/
│  └─ ui_smoke.py         # Playwright 双应用浏览器巡检
├─ package.json
├─ pnpm-workspace.yaml
└─ tsconfig.base.json
```

正式源码不依赖原始 ZIP。商城和后台分别构建、分别部署，但共享统一会话、Axios Client、Refresh Token 轮换、401/403 处理与 SSE Client。

## 3. 页面覆盖

### 商城公共区

- 首页、商品列表、商品详情；
- 知识中心、知识详情；
- AI 专业客服；
- 登录、注册、403、404。

### 用户工作台

- 购物车、结算、订单列表、订单详情；
- 模拟钱包、收货地址、通知、个人资料；
- 学习任务、课程中心、课程详情、章节阅读、闯关测验、学习档案。

### 企业运营后台

- 运营总览；
- 用户员工、角色权限；
- 商品、库存、订单、钱包；
- 知识治理、AI 治理、培训运营；
- 通知补偿、系统配置、审计安全。

## 4. 视觉决策

视觉方向为“南粤商贸档案馆 + 企业运营台”：象牙白纸张底、海关蓝绿、朱砂红与低饱和金色。商城强调商品、产地和可信来路；知识与 AI 强调版本、审核与引用；培训强调路径、规则与服务端进度；后台使用高密度表格、筛选、待办和状态视图。

该方向替换了通用 SaaS 营销模板，避免紫色渐变、悬浮大卡片和无业务含义的 AI 风格装饰。

## 5. 验证证据

2026-07-13 已执行：

```powershell
cd ygh-web
pnpm install
pnpm type-check
pnpm build
python <webapp-testing>/scripts/with_server.py `
  --server "pnpm --filter @ygh/web-mall dev" --port 5173 `
  --server "pnpm --filter @ygh/web-admin dev" --port 5174 `
  -- python scripts/ui_smoke.py
```

结果：

- 三个工作区包严格 TypeScript 检查通过；
- Mall 与 Admin 生产构建通过；
- Playwright 巡检商城公共区 6 条、用户工作台 6 条、后台 8 条路由；
- 20 条路由无空白页、无意外 404、无浏览器 Console/Page Error；
- 已人工检查商城首页与后台总览截图。

## 6. 当前边界

本阶段完成 `FE-1302`—`FE-1304`。页面中的业务展示数据仍属于脱敏原型数据；`FE-1305` 类型安全 API Client 的公共基础已经建立，但 OpenAPI 生成、全部真实接口接入、SSE 真联调和前后端 E2E 仍由 `FE-1305`—`FE-1307` 完成，不能把当前原型构建通过等同于全系统联调完成。
