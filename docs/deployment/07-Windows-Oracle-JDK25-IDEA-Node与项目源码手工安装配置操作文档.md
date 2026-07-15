# Windows Oracle JDK 25、IntelliJ IDEA、Node.js 与项目源码手工安装配置操作文档

## 第一部分：下载和安装 Oracle JDK 25.0.3

### 第一步：确认 JDK 安装在 Windows 本机

**在哪里操作**：客户 Windows 本机，不是在 Rocky Linux 虚拟机、SSH 终端、Docker、Ubuntu WSL 或任何中间件容器中操作。

本项目规定：

```text
软件：Oracle JDK 25.0.3 LTS
安装位置：C:\Program Files\Java\jdk-25
用途：IDEA 运行 14 个 Java 服务，Maven Wrapper 编译和测试项目
源码目标级别：Java 24，由根 pom.xml 的 maven.compiler.release=24 固定
Maven 自身运行 JDK：Oracle JDK 25
```

**执行后的结果**：先明确 JDK 的宿主位置。Elasticsearch、Seata 等 Docker 镜像内部自带自己的 Java，不使用 Windows `JAVA_HOME`；Rocky Linux 虚拟机也不为本项目 IDEA 服务安装 JDK。

### 第二步：检查 Windows 是否已有 Java

**在哪里操作**：Windows 本机 PowerShell。

按 `Win + X`，点击“终端”或“Windows PowerShell”，输入：

```powershell
java -version
javac -version
where.exe java
echo $env:JAVA_HOME
```

**执行后的结果**：

1. 全新电脑可能提示找不到 `java`，可以继续安装。
2. 旧电脑可能显示 Java 8、17、21 或 OpenJDK 25，需要安装 Oracle JDK 25 并调整环境变量优先级。
3. 已是 Oracle JDK 25.0.3 时，不重复安装，进入第十二步核对供应商。

**注意事项**：PowerShell 中必须输入 `where.exe java`，不要只输入 `where java`；`where` 在 PowerShell 中可能被解释为 `Where-Object` 别名。

### 第三步：从 Oracle 官方页面找到 JDK 25 Windows 下载项

**在哪里操作**：Windows 本机浏览器。

1. 打开 Oracle 官方下载页：`https://www.oracle.com/java/technologies/downloads/#jdk25-windows`。
2. 页面上方可能先显示 JDK 26，不要下载 JDK 26。
3. 向下找到 `Java SE Development Kit 25.0.3 downloads`。
4. 点击 `Windows` 标签。
5. 在表格中找到 `x64 Installer`。

**执行后的结果**：看到文件名或链接：

```text
jdk-25_windows-x64_bin.exe
https://download.oracle.com/java/25/latest/jdk-25_windows-x64_bin.exe
```

2026-07-14 页面显示版本为 25.0.3、文件大小约 184.51 MB。不要选择 ARM64，不要选择 JRE 8，也不要进入 OpenJDK 下载页。

### 第四步：下载 Oracle JDK 安装包和 SHA256

**在哪里操作**：Windows 本机浏览器。

1. 在 `x64 Installer` 行点击 EXE 下载链接。
2. 将文件保存到：

```text
D:\ygh-installers\oracle-jdk-25
```

3. 回到 Oracle 下载表格。
4. 点击同一行后面的 `sha256` 链接。
5. 将显示的 64 位十六进制哈希保存在交付校验记录中。

**执行后的结果**：目录中有 `jdk-25_windows-x64_bin.exe`，并且校验记录中有 Oracle 官方 SHA256。

### 第五步：核对 JDK 安装包哈希和数字签名

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
Get-FileHash 'D:\ygh-installers\oracle-jdk-25\jdk-25_windows-x64_bin.exe' -Algorithm SHA256
Get-AuthenticodeSignature 'D:\ygh-installers\oracle-jdk-25\jdk-25_windows-x64_bin.exe' |
  Select-Object Status,@{Name='Signer';Expression={$_.SignerCertificate.Subject}}
```

**执行后的结果**：

1. `Get-FileHash` 的值与 Oracle 页面 `sha256` 完全一致，不区分字母大小写。
2. `Status` 为 `Valid`。
3. 签名者包含 Oracle。

哈希或签名不正确时删除文件，从 Oracle 官方页重新下载，不能继续安装。

### 第六步：启动 Oracle JDK 安装向导

**在哪里操作**：Windows 本机资源管理器。

1. 打开 `D:\ygh-installers\oracle-jdk-25`。
2. 右键 `jdk-25_windows-x64_bin.exe`。
3. 点击“以管理员身份运行”。
4. 用户账户控制弹窗点击“是”。
5. 安装向导打开后点击 `Next`。

**执行后的结果**：进入 Oracle JDK 安装位置页面。

### 第七步：确认 Oracle JDK 安装路径

**在哪里操作**：Oracle JDK 安装向导。

安装路径保持：

```text
C:\Program Files\Java\jdk-25
```

1. 如果页面显示上述路径，直接点击 `Next`。
2. 如果客户单位要求装到其他盘，必须记录实际根目录，后文所有 `C:\Program Files\Java\jdk-25` 都替换为该目录。
3. 不要在路径末尾加 `\bin`。

**执行后的结果**：安装器开始复制 `java.exe`、`javac.exe`、标准库和开发工具。

### 第八步：完成安装

**在哪里操作**：Oracle JDK 安装向导。

1. 等待进度完成。
2. 出现安装成功页面后点击 `Close`。
3. 打开资源管理器进入：

```text
C:\Program Files\Java\jdk-25
```

**执行后的结果**：目录中能看到 `bin`、`conf`、`include`、`jmods`、`legal` 和 `lib`。

### 第九步：打开 Windows 环境变量页面

**在哪里操作**：Windows 本机系统界面。

1. 右键“此电脑”。
2. 点击“属性”。
3. 点击“高级系统设置”。
4. 在“高级”标签点击“环境变量”。

**执行后的结果**：窗口分为上方“用户变量”和下方“系统变量”。本项目统一在下方“系统变量”配置，确保 IDEA 和管理员/普通 PowerShell 使用同一 JDK。

### 第十步：新建或修改 JAVA_HOME

**在哪里操作**：Windows“环境变量”窗口的“系统变量”区域。

1. 在“系统变量”中查找 `JAVA_HOME`。
2. 不存在时点击“新建”；存在时选中后点击“编辑”。
3. 变量名填写：

```text
JAVA_HOME
```

4. 变量值填写：

```text
C:\Program Files\Java\jdk-25
```

5. 点击“确定”。

**执行后的结果**：系统变量 `JAVA_HOME` 指向 Oracle JDK 根目录。

下面写法错误：

```text
C:\Program Files\Java\jdk-25\bin
C:\Program Files\Java
java.exe
```

### 第十一步：把 %JAVA_HOME%\bin 放到 Path 前部

**在哪里操作**：Windows“环境变量”窗口的“系统变量”区域。

1. 选中系统变量 `Path`。
2. 点击“编辑”。
3. 点击“新建”。
4. 输入：

```text
%JAVA_HOME%\bin
```

5. 选中新条目，点击“上移”，把它移到旧 Java 路径前面。
6. 查找并记录下列旧路径：

```text
C:\Program Files\Java\jdk-17\bin
C:\Program Files\Eclipse Adoptium\...\bin
C:\Program Files\Common Files\Oracle\Java\javapath
```

7. 旧项目仍需使用的路径可以保留，但必须放在 `%JAVA_HOME%\bin` 后面。
8. 连续点击“确定”，关闭所有环境变量和系统属性窗口。

**执行后的结果**：新打开的程序优先找到 Oracle JDK 25。

### 第十二步：重新打开 PowerShell并验证 Oracle JDK

**在哪里操作**：新打开的 Windows PowerShell。旧 PowerShell 不会自动读取刚修改的环境变量，必须关闭后重开。

输入：

```powershell
echo $env:JAVA_HOME
where.exe java
where.exe javac
java -version
javac -version
java -XshowSettings:properties -version 2>&1 |
  Select-String -Pattern 'java.home =|java.vendor =|java.version ='
```

**执行后的结果**必须包含：

```text
JAVA_HOME = C:\Program Files\Java\jdk-25
java.vendor = Oracle Corporation
java.version = 25.0.3
java version "25.0.3"
javac 25.0.3
```

`where.exe java` 第一行必须是 `C:\Program Files\Java\jdk-25\bin\java.exe`。

**实测说明**：项目已使用 Oracle Corporation JDK 25.0.3 和 Maven Wrapper 3.9.16 完成 Search 依赖链编译，不是只用 OpenJDK 推测兼容。

### 第十三步：处理 java 仍指向旧版本

**在哪里操作**：Windows 环境变量窗口和新 PowerShell。

输入：

```powershell
where.exe java
$env:Path -split ';' | Select-String -Pattern 'Java|Adoptium|jdk|javapath'
```

**处理方法**：

1. 找到排在 Oracle JDK 前面的旧 Java 路径。
2. 回到系统变量 `Path`，把 `%JAVA_HOME%\bin` 上移到最前。
3. 不确定旧 Java 是否被其他系统使用时不要卸载，只调整顺序。
4. 关闭所有 IDEA、终端和 PowerShell后重新打开。
5. 再次执行第十二步。

## 第二部分：下载和安装 IntelliJ IDEA

### 第一步：从 JetBrains 官方页面下载安装包

**在哪里操作**：Windows 本机浏览器。

1. 打开：`https://www.jetbrains.com/idea/download/?section=windows`。
2. 确认页面选择 `Windows`。
3. 选择 `Windows x64`，不要下载 ARM64。
4. JetBrains 当前采用统一版 IntelliJ IDEA，一个安装包提供基础功能；需要订阅的高级功能由许可证解锁。
5. 点击 `.exe` 下载按钮。
6. 保存到：

```text
D:\ygh-installers\intellij-idea
```

**执行后的结果**：得到名称类似 `ideaIU-2026.x.exe` 的 JetBrains 官方安装包。实际小版本以交付当天官方稳定版为准，不使用 EAP 预览版。

### 第二步：检查 IDEA 安装包数字签名

**在哪里操作**：Windows 本机 PowerShell。

先查看实际文件名：

```powershell
Get-ChildItem 'D:\ygh-installers\intellij-idea' -Filter '*.exe' |
  Select-Object Name,Length,LastWriteTime
```

把下面文件名替换为实际名称：

```powershell
Get-AuthenticodeSignature 'D:\ygh-installers\intellij-idea\ideaIU-实际版本.exe' |
  Select-Object Status,@{Name='Signer';Expression={$_.SignerCertificate.Subject}}
```

**执行后的结果**：`Status=Valid`，签名者包含 JetBrains。

### 第三步：启动 IDEA 安装向导

**在哪里操作**：Windows 本机资源管理器。

1. 双击 JetBrains 官方 EXE。
2. 用户账户控制弹窗点击“是”。
3. 欢迎页面点击 `Next`。

**执行后的结果**：进入安装位置页面。

### 第四步：确认 IDEA 安装路径

**在哪里操作**：IntelliJ IDEA 安装向导。

保持默认目录，例如：

```text
C:\Program Files\JetBrains\IntelliJ IDEA 2026.1
```

点击 `Next`。

**需要修改的内容**：实际版本目录可能不是 2026.1，以安装向导显示为准。不要把 IDEA 安装到项目源码目录 `D:\ygh-ai-system`。

### 第五步：选择安装选项

**在哪里操作**：IntelliJ IDEA 安装向导的 Installation Options 页面。

建议选择：

1. `Create Desktop Shortcut` → `IntelliJ IDEA`。
2. `Update PATH Variable` → `Add "bin" folder to the PATH`。
3. `Update Context Menu` → `Add "Open Folder as Project"`。
4. 文件关联中的 `.java` 可按客户习惯勾选。

点击 `Next`。

**执行后的结果**：桌面、右键菜单和 PATH 按选项配置。IDEA 是否在 PATH 中不影响通过桌面启动项目。

### 第六步：完成 IDEA 安装

**在哪里操作**：IntelliJ IDEA 安装向导。

1. 开始菜单文件夹保持 `JetBrains`。
2. 点击 `Install`。
3. 等待完成。
4. 勾选 `Run IntelliJ IDEA`。
5. 点击 `Finish`。

**执行后的结果**：IntelliJ IDEA 第一次启动。

### 第七步：完成 IDEA 第一次启动

**在哪里操作**：Windows 本机 IntelliJ IDEA。

1. 询问是否导入旧设置时，新电脑选择 `Do not import settings`。
2. 阅读并按客户策略接受 JetBrains 协议。
3. 登录 JetBrains 账号或选择免费基础使用方式。
4. 不要导入来源不明的 IDEA 设置 ZIP。
5. 到达欢迎页。

**执行后的结果**：看到 `New Project`、`Open` 等按钮。

### 第八步：在 IDEA 注册 Oracle JDK 25

**在哪里操作**：Windows 本机 IntelliJ IDEA 欢迎页。

1. 点击 `Customize` → `All settings`，或打开项目后进入 `File` → `Project Structure`。
2. 进入 `Platform Settings` → `SDKs`。
3. 点击 `+` → `Add JDK`。
4. 选择：

```text
C:\Program Files\Java\jdk-25
```

5. SDK 名称填写：

```text
Oracle JDK 25.0.3
```

6. 点击 `OK` 或 `Apply`。

**执行后的结果**：IDEA 的 SDK 列表显示 Oracle JDK 25.0.3，不使用 IDEA 自动下载的其他 JDK。

## 第三部分：下载和安装 Node.js 24.18.0 LTS 与 pnpm 10.13.1

### 第一步：确认 Node.js 安装在 Windows 本机

**在哪里操作**：Windows 本机。

本项目规定：

```text
Node.js：24.18.0 LTS x64
安装位置：C:\Program Files\nodejs
pnpm：10.13.1，由 ygh-web/package.json 的 packageManager 固定
前端目录：D:\ygh-ai-system\ygh-web
```

Node.js 和 pnpm 不安装到 Rocky Linux 虚拟机、Docker 或 Ubuntu WSL。前端开发服务器运行在 Windows 本机。

### 第二步：检查已有 Node.js 和 pnpm

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
node --version
npm --version
corepack --version
pnpm --version
where.exe node
where.exe pnpm
```

**执行后的结果**：没有命令时继续安装；已有其他 Node 大版本时先记录安装来源，不要把 MSI、nvm-windows 和便携版混在同一个 PATH 中。

### 第三步：下载 Node.js 24.18.0 x64 MSI

**在哪里操作**：Windows 本机浏览器。

1. 打开 Node.js 24 发布目录：`https://nodejs.org/download/release/v24.18.0/`。
2. 点击：

```text
node-v24.18.0-x64.msi
```

3. 同一页面下载：

```text
SHASUMS256.txt
```

4. 两个文件保存到：

```text
D:\ygh-installers\nodejs-24.18.0
```

**执行后的结果**：获得固定 Node.js 24.18.0 Windows x64 安装包和官方哈希清单。

### 第四步：核对 Node.js 安装包哈希

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
$actual = (Get-FileHash 'D:\ygh-installers\nodejs-24.18.0\node-v24.18.0-x64.msi' -Algorithm SHA256).Hash.ToLowerInvariant()
$expectedLine = Get-Content 'D:\ygh-installers\nodejs-24.18.0\SHASUMS256.txt' |
  Where-Object { $_ -match 'node-v24\.18\.0-x64\.msi$' }
$expected = ($expectedLine -split '\s+')[0].ToLowerInvariant()
"EXPECTED=$expected"
"ACTUAL=$actual"
$actual -eq $expected
```

**执行后的结果**：最后一行必须是 `True`。不是 `True` 时删除 MSI并重新从 Node.js 官方目录下载。

### 第五步：安装 Node.js

**在哪里操作**：Windows 本机 Node.js 安装向导。

1. 双击 `node-v24.18.0-x64.msi`。
2. 点击 `Next`。
3. 阅读许可并勾选接受，点击 `Next`。
4. 安装目录保持：

```text
C:\Program Files\nodejs
```

5. 功能保持默认，确保 `Node.js runtime`、`npm package manager`、`Corepack manager` 和 `Add to PATH` 被安装。
6. 出现“Automatically install the necessary tools”时不要勾选；本项会额外安装 Chocolatey/Python/Visual Studio Build Tools，当前前端依赖不需要。
7. 点击 `Install`。
8. 用户账户控制弹窗点击“是”。
9. 安装完成点击 `Finish`。

**执行后的结果**：Node.js 安装到 Windows，PATH 中加入 `C:\Program Files\nodejs`。

### 第六步：验证 Node.js 24.18.0

**在哪里操作**：关闭旧 PowerShell后重新打开一个 Windows PowerShell。

输入：

```powershell
node --version
npm --version
corepack --version
where.exe node
```

**执行后的结果**：

```text
node --version = v24.18.0
where.exe node 第一行 = C:\Program Files\nodejs\node.exe
```

### 第七步：用 Corepack 启用 pnpm 10.13.1

**在哪里操作**：Windows 本机管理员 PowerShell。

输入：

```powershell
corepack enable
corepack prepare pnpm@10.13.1 --activate
```

**执行后的结果**：Corepack 在 Node.js 目录启用 pnpm shim，并准备 10.13.1。

如果提示没有权限写入 `C:\Program Files\nodejs`，确认当前 PowerShell 标题包含“管理员”，再重新执行。

### 第八步：验证项目锁定的 pnpm

**在哪里操作**：Windows 本机 PowerShell。项目尚未解压时先只执行第一条，解压后再执行完整检查。

输入：

```powershell
pnpm --version
```

**执行后的结果**：显示 `10.13.1`。项目解压后，在 `ygh-web` 目录执行 pnpm 时，Corepack还会读取 `package.json` 中的：

```text
"packageManager": "pnpm@10.13.1"
```

不能擅自使用 npm 或 yarn 重建锁文件。

## 第四部分：接收和解压项目源码 ZIP

### 第一步：确认不需要 Git

**在哪里操作**：Windows 本机和交付清单。

客户收到完整项目源码 ZIP，因此：

```text
不安装 Git
不执行 git clone
不配置 GitHub 账号
不从 Docker 拉项目源码
```

Docker 拉取的是 MySQL、Redis、Nacos 等组件镜像；项目源码由交付 ZIP 提供，二者不是同一个对象。

### 第二步：检查项目 ZIP 文件名和哈希

**在哪里操作**：Windows 本机资源管理器和 PowerShell。

把交付 ZIP 放到：

```text
D:\ygh-delivery\source
```

假设文件名是：

```text
ygh-ai-system-source.zip
```

输入：

```powershell
Get-Item 'D:\ygh-delivery\source\ygh-ai-system-source.zip' |
  Select-Object FullName,Length,LastWriteTime
Get-FileHash 'D:\ygh-delivery\source\ygh-ai-system-source.zip' -Algorithm SHA256
```

**执行后的结果**：文件大小合理，SHA256 与项目交付清单完全一致。哈希不一致时停止解压并要求重新传输。

### 第三步：解除 Windows 下载阻止

**在哪里操作**：Windows 本机资源管理器。

1. 右键 `ygh-ai-system-source.zip`。
2. 点击“属性”。
3. 如果窗口底部有“解除锁定”或 `Unblock`，勾选它。
4. 点击“应用”。
5. 点击“确定”。

**执行后的结果**：ZIP 内的 Maven Wrapper `.cmd` 和其他文件不会继承互联网下载阻止标记。没有“解除锁定”选项时说明文件未被阻止，直接进入下一步。

### 第四步：确认目标目录为空

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
Test-Path 'D:\ygh-ai-system'
```

**执行后的结果**：全新部署返回 `False`。

如果返回 `True`：

1. 在资源管理器打开 `D:\ygh-ai-system`。
2. 确认是否为客户已有项目或旧版本。
3. 不覆盖旧项目；将旧目录重命名为带日期的备份，例如 `ygh-ai-system-old-20260714`。
4. 确认备份可打开后再解压新版本。

### 第五步：把源码解压到短英文路径

**在哪里操作**：Windows 本机资源管理器。

1. 右键 `ygh-ai-system-source.zip`。
2. 点击“全部解压缩”。
3. 目标路径填写：

```text
D:\ygh-ai-system
```

4. 点击“提取”。
5. 等待进度完成。

**执行后的结果**：源码位于 Windows D 盘短英文路径。不要解压到桌面、OneDrive、中文超长目录、WSL `/home`、Docker 卷或 Rocky Linux 虚拟机。

### 第六步：检查是否多套了一层目录

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
Get-ChildItem 'D:\ygh-ai-system' -Force | Select-Object Name,Mode
Test-Path 'D:\ygh-ai-system\pom.xml'
Test-Path 'D:\ygh-ai-system\mvnw.cmd'
Test-Path 'D:\ygh-ai-system\ygh-web\package.json'
```

**执行后的结果**：三个 `Test-Path` 都返回 `True`。

如果只有 `D:\ygh-ai-system\ygh-ai-system-source\pom.xml` 存在，说明 ZIP 多套一层。将内层目录整体移动为 `D:\ygh-ai-system`，确保根 `pom.xml` 直接位于目标目录下。

### 第七步：核对项目结构并理解每个目录的用途

**在哪里操作**：Windows 本机资源管理器或 PowerShell。

输入：

```powershell
Get-ChildItem 'D:\ygh-ai-system' -Directory | Select-Object Name
```

**执行后的结果**至少包含下面这些目录。客户拿到的不是一个只有若干 JAR 包的运行目录，而是一个 Maven 多模块源码项目：

```text
D:\ygh-ai-system
├─ pom.xml                    Maven 根工程，IDEA 必须从这里导入
├─ mvnw.cmd                   Maven Wrapper 的 Windows 标准入口，不是项目部署脚本
├─ .mvn\                      Maven Wrapper 固定版本配置
├─ ygh-dependencies\          Java 依赖版本管理模块
├─ ygh-common\                公共 Java 基础模块，不单独启动
├─ ygh-platform\              平台服务
│  ├─ ygh-gateway\            网关服务，启动类 GatewayApplication
│  └─ ygh-auth-service\       认证服务，启动类 AuthApplication
├─ ygh-applications\          业务服务总目录
│  ├─ ygh-admin\              管理服务
│  ├─ ygh-user\               用户服务
│  ├─ ygh-system\             系统服务
│  ├─ ygh-product\            商品服务
│  ├─ ygh-inventory\          库存服务
│  ├─ ygh-order\              订单服务
│  ├─ ygh-wallet\             钱包服务
│  ├─ ygh-search\             向量检索服务
│  ├─ ygh-knowledge\          知识库服务
│  ├─ ygh-ai\                 AI 服务
│  ├─ ygh-notification\       通知服务
│  └─ ygh-training\           培训服务
├─ ygh-web\                   商城前端和管理前端
├─ ygh-tests\                 Java 契约、集成、安全和兼容性测试模块
├─ spec\                      OpenAPI 等接口规格
├─ docs\                      项目文档
└─ ygh-deploy\                Docker 配置及历史部署材料，不是 Java 启动模块
```

每个业务目录通常继续分为 `*-api` 和 `*-service`：`*-api` 保存接口契约，不能作为 Java 应用启动；`*-service` 才包含 `src\main\java`、`src\main\resources`、数据库迁移文件和真正的 `*Application` 启动类。

`target` 是 Maven 编译产生的临时目录，不是源码模块，也不应出现在正式交付压缩包中。IDEA 中看到橙色 `target` 不代表多了一个项目；交付前应由交付方制作不包含 `target` 的干净压缩包。

`ygh-deploy\scripts` 以及其他 `.ps1`、`.sh` 文件属于现有仓库中的自动化部署或检查脚本。当前客户交付要求是逐项手工安装、配置并在 IDEA 中启动，因此客户不要进入这些目录执行脚本。交付方必须在最终源码包制作前完成脚本清理及其引用调整，不能把脚本写成客户部署入口。

缺少任何业务根目录时，源码交付包不完整，不能继续导入 IDEA；但 `ygh-deploy` 不会显示在 IDEA 的 Maven 模块列表中，因为它没有 `pom.xml`，这属于正常现象。

### 第八步：确认交付包没有真实秘密和运行垃圾

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
Get-ChildItem 'D:\ygh-ai-system' -Recurse -Force -File -ErrorAction SilentlyContinue |
  Where-Object {
    $_.Name -eq '.env' -or
    $_.Extension -in '.pem','.key','.p12','.pfx','.jks' -or
    $_.FullName -match '\\node_modules\\|\\target\\|\\\.git\\'
  } |
  Select-Object FullName
```

**执行后的结果**：正式源码交付包不应包含真实 `.env`、私钥、证书私钥库、`.git`、`target` 或 `node_modules`。

出现这些文件时不要直接使用。由交付方确认是否误带凭据，必要时立即轮换泄露凭据并重新制作干净压缩包。

### 第九步：确认 Maven Wrapper 文件完整

**在哪里操作**：Windows 本机 PowerShell。

输入：

```powershell
Get-Item 'D:\ygh-ai-system\mvnw','D:\ygh-ai-system\mvnw.cmd','D:\ygh-ai-system\.mvn\wrapper\maven-wrapper.properties' |
  Select-Object FullName,Length
Get-Content 'D:\ygh-ai-system\.mvn\wrapper\maven-wrapper.properties'
```

**执行后的结果**：配置中必须包含：

```text
distributionUrl=https://repo.maven.apache.org/maven2/org/apache/maven/apache-maven/3.9.16/apache-maven-3.9.16-bin.zip
distributionSha256Sum=5af3b743dd8b876b5c45da33b676251e5f1687712644abb4ee519ca56e1d89ce
```

客户不需要另外下载或安装 Maven，项目 Wrapper 会下载并校验 Maven 3.9.16。

## 第五部分：在 IDEA 导入 Maven 多模块项目

### 第一步：用 IDEA 打开根项目

**在哪里操作**：Windows 本机 IntelliJ IDEA。

1. 打开 IntelliJ IDEA。
2. 欢迎页点击 `Open`。
3. 选择目录：

```text
D:\ygh-ai-system
```

4. 点击 `OK`。
5. 出现 `Trust and Open Project` 时，确认 ZIP 哈希已验证后点击信任并打开。

**执行后的结果**：IDEA 打开整个根工程，不是只打开 `ygh-applications` 或某个 service 子目录。

### 第二步：等待 Maven 识别根 pom.xml

**在哪里操作**：Windows 本机 IntelliJ IDEA。

1. 右下角出现 Maven 导入提示时点击 `Load Maven Project`。
2. 没有提示时，右键根 `pom.xml`。
3. 点击 `Add as Maven Project`。
4. 打开右侧 Maven 工具窗口。

**执行后的结果**：Maven 窗口显示根项目及 `ygh-dependencies`、`ygh-common`、`ygh-platform`、`ygh-applications`、`ygh-tests` 等模块。

### 第三步：设置 Project SDK 为 Oracle JDK 25

**在哪里操作**：Windows本机 IntelliJ IDEA。

1. 点击 `File` → `Project Structure`。
2. 点击左侧 `Project`。
3. `SDK` 选择 `Oracle JDK 25.0.3`。
4. `Language level` 选择 `24 - ...` 或 `SDK default` 后确认实际为 24。
5. 点击 `Apply`。

**执行后的结果**：IDEA 本身使用 Oracle JDK 25 作为项目 SDK，但源码语法和字节码按根 `pom.xml` 的 `maven.compiler.release=24` 编译。

**注意事项**：不要把 Language level 强制改为 25 后修改 `pom.xml`。当前项目故意以 JDK 25 运行、Java 24 为源码/字节码目标，以兼容完整 Reactor 导入。

### 第四步：设置 Maven 使用项目 Wrapper

**在哪里操作**：Windows 本机 IntelliJ IDEA。

1. 点击 `File` → `Settings`。
2. 展开 `Build, Execution, Deployment`。
3. 展开 `Build Tools`。
4. 点击 `Maven`。
5. `Maven home path` 选择 `Use Maven wrapper`。
6. `User settings file` 保持客户实际 `%USERPROFILE%\.m2\settings.xml`；没有自定义设置时使用默认。
7. `Local repository` 保持 `%USERPROFILE%\.m2\repository`。
8. 不勾选 `Work offline`。

**执行后的结果**：IDEA 使用项目锁定的 Maven 3.9.16，不使用电脑中不明版本的全局 Maven。

### 第五步：设置 Maven Importer 和 Runner JDK

**在哪里操作**：Windows 本机 IntelliJ IDEA 设置窗口。

1. 在 `Build Tools` → `Maven` → `Importing` 中，把 `JDK for importer` 选为 `Oracle JDK 25.0.3`。
2. 在 `Build Tools` → `Maven` → `Runner` 中，把 `JRE` 选为 `Oracle JDK 25.0.3`。
3. 点击 `Apply`。
4. 点击 `OK`。

**执行后的结果**：IDEA 导入和运行 Maven 目标时都使用 Oracle Corporation JDK 25.0.3。

### 第六步：设置项目文件编码

**在哪里操作**：Windows 本机 IntelliJ IDEA。

1. 点击 `File` → `Settings`。
2. 进入 `Editor` → `File Encodings`。
3. `Global Encoding` 选择 `UTF-8`。
4. `Project Encoding` 选择 `UTF-8`。
5. `Default encoding for properties files` 选择 `UTF-8`。
6. 点击 `Apply` → `OK`。

**执行后的结果**：中文文档、YAML 和 Java 源码不会因 Windows 本地编码产生乱码。

### 第七步：重新加载 Maven 项目

**在哪里操作**：Windows 本机 IntelliJ IDEA Maven 工具窗口。

1. 点击 Maven 工具窗口顶部 `Reload All Maven Projects` 图标。
2. 等待右下角下载和索引完成。
3. 打开 `Build` 工具窗口查看是否有红色错误。

**执行后的结果**：所有 Maven 模块导入完成。首次导入需要从 Maven Central 下载依赖，时间取决于客户网络。

### 第八步：在 IDEA Terminal 验证 Maven 和 Oracle JDK

**在哪里操作**：Windows 本机 IntelliJ IDEA 底部 `Terminal`，终端类型选择 PowerShell。

输入：

```powershell
cd 'D:\ygh-ai-system'
.\mvnw.cmd --version
```

**执行后的结果**必须包含：

```text
Apache Maven 3.9.16
Java version: 25.0.3
vendor: Oracle Corporation
```

如果显示 Eclipse Adoptium、Microsoft、Amazon 或其他供应商，说明 IDEA Terminal 继承的是旧环境。完全退出 IDEA后重新打开，再检查系统 `JAVA_HOME` 和 Maven Runner JRE。

### 第九步：编译后端 Reactor

**在哪里操作**：Windows 本机 IntelliJ IDEA Terminal。

输入：

```powershell
cd 'D:\ygh-ai-system'
.\mvnw.cmd -DskipTests compile
```

**执行后的结果**：所有模块完成后显示：

```text
BUILD SUCCESS
```

**说明**：这是人工执行的一次 Maven 编译命令，不是批量启动脚本。它只编译，不启动 14 个 Java 服务。Java 服务将在独立 IDEA 启动文档中逐个配置和运行。

### 第十步：处理 Maven Central 无法访问

**在哪里操作**：Windows 本机浏览器、PowerShell和 IDEA。

先输入：

```powershell
curl.exe -I --connect-timeout 10 --max-time 20 https://repo.maven.apache.org/maven2/
```

返回 HTTP 200 表示 Maven Central 可达。超时时：

1. 先按单位网络要求配置 Windows/IDEA 代理。
2. 不要从不明网站手工下载零散 JAR 放进项目。
3. 客户确认使用国内 Maven 镜像时，在 `%USERPROFILE%\.m2\settings.xml` 手工配置单位批准的镜像。
4. 修改后在 IDEA Maven 页面明确选择该 `settings.xml`。
5. 点击 `Reload All Maven Projects`。

镜像地址、账号和密码由客户单位提供，本文不虚构私服凭据。

## 第六部分：安装前端依赖并验证 Node/pnpm

### 第一步：在项目目录核对 pnpm 锁定版本

**在哪里操作**：Windows 本机 IntelliJ IDEA Terminal 或 PowerShell。

输入：

```powershell
cd 'D:\ygh-ai-system\ygh-web'
Get-Content package.json | Select-String 'packageManager'
node --version
pnpm --version
```

**执行后的结果**：

```text
packageManager = pnpm@10.13.1
node = v24.18.0
pnpm = 10.13.1
```

### 第二步：按锁文件安装前端依赖

**在哪里操作**：Windows 本机 `D:\ygh-ai-system\ygh-web` 目录中的 PowerShell。

输入：

```powershell
pnpm install --frozen-lockfile
```

**执行后的结果**：pnpm 识别 4 个 workspace 项目，锁文件不被修改，最后显示 `Done`。依赖安装在 `ygh-web\node_modules` 和 pnpm 内容寻址存储中，不安装到 Docker 或虚拟机。

如果提示 lockfile 不一致，不要去掉 `--frozen-lockfile` 强行重写；说明源码包中的 `package.json` 和 `pnpm-lock.yaml` 版本不匹配，应要求交付方修正。

### 第三步：运行前端类型检查

**在哪里操作**：Windows 本机 `D:\ygh-ai-system\ygh-web` PowerShell。

输入：

```powershell
pnpm run type-check
```

**执行后的结果**：共享包、商城前端和管理端前端均显示 `Done`，命令退出码为 0。

**实测说明**：Node.js 24.18.0 + pnpm 10.13.1 已对当前三个前端工作区执行类型检查并通过。

### 第四步：运行前端生产构建检查

**在哪里操作**：Windows 本机 `D:\ygh-ai-system\ygh-web` PowerShell。

输入：

```powershell
pnpm run build
```

**执行后的结果**：各前端包构建完成，生成各自 `dist`。构建成功不等于后端已启动，前端实际启动和访问地址按独立前端文档操作。

## 第七部分：常见故障处理

### 第一步：处理 JAVA_HOME is not defined correctly

**在哪里操作**：Windows 本机 PowerShell和环境变量窗口。

输入：

```powershell
echo $env:JAVA_HOME
Test-Path "$env:JAVA_HOME\bin\java.exe"
Test-Path "$env:JAVA_HOME\bin\javac.exe"
```

两个 `Test-Path` 必须返回 `True`。否则把 `JAVA_HOME` 改为实际 JDK 根目录，不要写 `\bin`。

### 第二步：处理 Maven 显示非 Oracle JDK

**在哪里操作**：Windows 本机环境变量窗口和 IntelliJ IDEA。

依次确认：

1. 系统 `JAVA_HOME=C:\Program Files\Java\jdk-25`。
2. 系统 `Path` 中 `%JAVA_HOME%\bin` 排在旧 Java 前面。
3. IDEA Project SDK 为 Oracle JDK 25.0.3。
4. Maven Importer JDK 为 Oracle JDK 25.0.3。
5. Maven Runner JRE 为 Oracle JDK 25.0.3。
6. 完全退出并重新打开 IDEA。

重新执行：

```powershell
.\mvnw.cmd --version
```

### 第三步：处理 Unsupported class file major version

**在哪里操作**：Windows 本机 IntelliJ IDEA和 PowerShell。

**原因**：某个构建工具或运行配置仍使用旧 JDK。

输入：

```powershell
java -version
.\mvnw.cmd --version
```

两者都必须是 Java 25。IDEA 对应运行配置中的 `JRE` 也必须选择 Oracle JDK 25.0.3。

### 第四步：处理 IDEA 只识别一个模块

**在哪里操作**：Windows 本机 IntelliJ IDEA。

1. 确认打开的是 `D:\ygh-ai-system` 根目录。
2. 确认根目录直接有 `pom.xml`。
3. 右键根 `pom.xml` → `Add as Maven Project`。
4. Maven 工具窗口点击 `Reload All Maven Projects`。
5. 不要单独打开 `ygh-search-service` 等子目录。

### 第五步：处理 pnpm 版本不是 10.13.1

**在哪里操作**：Windows 本机管理员 PowerShell。

输入：

```powershell
corepack enable
corepack prepare pnpm@10.13.1 --activate
cd 'D:\ygh-ai-system\ygh-web'
pnpm --version
```

**执行后的结果**：显示 `10.13.1`。不要用 `npm install -g pnpm@latest` 覆盖项目锁定版本。

### 第六步：处理 PowerShell 禁止运行 pnpm.ps1

**在哪里操作**：Windows 本机普通 PowerShell。

如果错误包含 `pnpm.ps1 cannot be loaded because running scripts is disabled`，先使用 CMD shim：

```powershell
pnpm.cmd --version
pnpm.cmd install --frozen-lockfile
```

**执行后的结果**：不修改客户全局执行策略也可以运行 pnpm。不要为了这一问题直接把执行策略改成 `Unrestricted`。

### 第七步：处理源码目录过深或文件名过长

**在哪里操作**：Windows 本机资源管理器。

1. 确认项目路径是短路径 `D:\ygh-ai-system`。
2. 不要放到 `C:\Users\姓名\OneDrive\Desktop\很多层目录`。
3. 删除失败的半成品 `node_modules` 前先关闭 IDEA 和前端进程。
4. 回到短路径重新解压干净源码包并执行 `pnpm install --frozen-lockfile`。

### 第八步：处理交付 ZIP 缺文件

**在哪里操作**：Windows 本机 PowerShell和交付清单。

至少检查：

```powershell
Test-Path 'D:\ygh-ai-system\pom.xml'
Test-Path 'D:\ygh-ai-system\mvnw.cmd'
Test-Path 'D:\ygh-ai-system\.mvn\wrapper\maven-wrapper.properties'
Test-Path 'D:\ygh-ai-system\ygh-web\package.json'
Test-Path 'D:\ygh-ai-system\ygh-web\pnpm-lock.yaml'
```

任何一项为 `False` 都不要自己从网上拼文件，应由交付方重新提供同一版本的完整源码 ZIP。

## 第八部分：最终验收

### 第一步：执行 Windows 开发环境检查

**在哪里操作**：Windows 本机 IntelliJ IDEA Terminal。

输入：

```powershell
echo $env:JAVA_HOME
where.exe java
java -XshowSettings:properties -version 2>&1 |
  Select-String -Pattern 'java.home =|java.vendor =|java.version ='
javac -version
node --version
pnpm --version
cd 'D:\ygh-ai-system'
.\mvnw.cmd --version
Test-Path '.\pom.xml'
Test-Path '.\ygh-web\package.json'
```

### 第二步：核对合格结果

**在哪里操作**：Windows 本机检查记录。

全部满足后才能进入 14 个 Java 服务的 IDEA 配置：

1. `JAVA_HOME` 指向 `C:\Program Files\Java\jdk-25`。
2. Java 和 Javac 都是 25.0.3。
3. `java.vendor` 为 `Oracle Corporation`，不是 OpenJDK 发行商。
4. Maven Wrapper 是 3.9.16，运行时是 Oracle JDK 25.0.3。
5. IDEA Project SDK、Maven Importer 和 Maven Runner 都是 Oracle JDK 25.0.3。
6. IDEA Language level 按当前根 POM 使用 24，不擅自修改项目编译级别。
7. Node.js 是 24.18.0 LTS，pnpm 是 10.13.1。
8. 源码位于 `D:\ygh-ai-system`，根 `pom.xml`、Wrapper 和前端锁文件完整。
9. Maven `-DskipTests compile` 显示 `BUILD SUCCESS`。
10. `pnpm install --frozen-lockfile`、`pnpm run type-check` 和 `pnpm run build`通过。
11. 客户没有安装 Git，也没有执行 `git clone`。
12. 源码没有放进 Docker、WSL2 或 Rocky Linux 虚拟机。
13. 源码包不包含真实 `.env`、密钥、`.git`、`target` 或 `node_modules`。
14. Java 服务尚未用批处理启动，下一份文档将在 IDEA 中逐个创建运行配置。
