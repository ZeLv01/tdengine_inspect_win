# TDengine 巡检工具（Windows 版）

一款专业、全面的 TDengine 数据库巡检工具，适用于 Windows 操作系统。专为数据库管理员和运维团队设计，用于快速评估 TDengine 集群健康状态、识别潜在问题，并生成专业的巡检报告。

[English Documentation](README.md)

## 项目亮点与优势

### 为什么选择本工具？

| 特性 | 说明 |
|------|------|
| **26 项全面巡检** | 业界领先覆盖范围：操作系统、CPU、内存、网络、数据库配置、服务状态、安全性 |
| **双连接模式** | 支持 WebSocket (REST API) 和原生协议，远程巡检无需安装 TDengine 客户端 |
| **零依赖（EXE 模式）** | 独立可执行文件，无需安装 PowerShell 模块或运行时环境 |
| **专业 HTML 报告** | 交互式侧边栏导航、彩色状态标识、告警摘要汇总 |
| **一键打包** | 单条命令即可打包 EXE，所有模块内嵌 |
| **模块化架构** | 每个检查项独立模块，便于扩展和维护 |

### 技术优势

1. **WebSocket 优先设计**
   - 默认使用 6041 端口（REST API）
   - 巡检机无需安装 TDengine 客户端
   - 支持跨网络远程巡检
   - 自动回退到原生协议（6030 端口）

2. **智能报告生成**
   - 左侧目录导航，快速定位任意章节
   - 顶部告警摘要，一目了然查看所有失败和警告项
   - 彩色状态徽章：通过（绿色）、警告（黄色）、失败（红色）
   - 等宽字体表格，技术数据完美对齐
   - 响应式设计，适配各种屏幕尺寸

3. **企业级功能**
   - 授权监控（过期时间、使用量限制）
   - 慢查询分析（可配置回溯周期）
   - 用户权限审计（root 密码、监控用户）
   - 服务版本一致性检查（taos、taosd、taosAdapter 等所有组件）
   - 错误日志按服务聚合（taosd、taosAdapter、taosKeeper、taosx、taos-explorer）

4. **灵活部署方式**
   - **脚本模式**：直接使用 PowerShell 运行，便于开发调试
   - **EXE 模式**：打包为独立可执行文件，便于分发
   - **定时模式**：集成 Windows 任务计划程序，实现自动化巡检

5. **可配置阈值**
   - 磁盘使用率告警/临界阈值
   - CPU 使用率阈值
   - 授权过期告警天数
   - 慢查询回溯周期和阈值
   - 所有阈值通过 `config.json` 配置

### 适用场景

- **生产环境健康检查**：定期自动巡检，提前发现问题
- **部署前验证**：升级 TDengine 前验证环境状态
- **安全合规审计**：检查安全设置、用户权限、防火墙状态
- **性能监控**：跟踪慢查询、资源使用率、副本状态
- **问题排查**：生成全面报告供 TDengine 技术支持分析

## 环境要求

- Windows PowerShell 5.1 或更高版本
- 网络访问 TDengine 服务器（WebSocket 连接使用 6041 端口）
- TDengine 已安装（仅原生连接模式需要）

## 快速开始

### 1. 配置连接

编辑 `config.json` 设置 TDengine 连接参数：

```json
{
    "connection": {
        "method": "websocket",
        "server": "localhost",
        "port": 6041,
        "user": "root",
        "password": "taosdata",
        "useSSL": false,
        "timeout": 30
    }
}
```

### 2. 执行巡检

**方式一：快速启动（推荐）**

双击 `Run-Inspection.bat`，选择菜单：
- 选项 1：运行巡检（默认设置）
- 选项 2：运行巡检并自动打开报告
- 选项 3：静默模式运行巡检

**方式二：PowerShell**

```powershell
.\TDengine-Inspect.ps1
```

> **提示**：如果遇到"禁止运行脚本"的错误，先执行 `Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process`，或直接使用 `Run-Inspection.bat`（自动绕过执行策略限制）。

### 3. 查看报告

HTML 报告将生成在 `output` 文件夹中，使用任意浏览器打开即可。

## 打包 EXE

可将工具打包为独立可执行文件，便于分发部署。

### 前置条件

- Windows PowerShell 5.1 或更高版本
- PS2EXE 模块（缺失时自动安装）

### 打包步骤

```powershell
# 运行打包脚本
.\build.ps1

# 或清理后重新打包（删除之前的构建产物）
.\build.ps1 -Clean
```

### 打包输出

打包完成后会在 `dist/` 目录生成：

```
dist/
├── TDengine-Inspect.exe    # 独立可执行文件
├── config.json              # 配置文件
└── README.md                # 说明文档
```

### 使用 EXE

```cmd
REM 基本用法
TDengine-Inspect.exe

REM 指定配置文件
TDengine-Inspect.exe -ConfigPath "C:\config\my-config.json"

REM 静默模式
TDengine-Inspect.exe -Quiet

REM 生成后自动打开报告
TDengine-Inspect.exe -OpenReport
```

### 分发部署

分发工具步骤：

1. 运行 `.\build.ps1` 生成 EXE
2. 将整个 `dist/` 文件夹复制到目标机器
3. 编辑 `config.json` 匹配目标环境
4. 运行 `TDengine-Inspect.exe`

**说明**：EXE 不需要 PowerShell 模块或脚本文件，所有内容已内嵌。

## 使用示例

### 基本用法

```powershell
# 使用默认设置运行巡检
.\TDengine-Inspect.ps1

# 运行并自动打开报告
.\TDengine-Inspect.ps1 -OpenReport

# 静默模式（减少控制台输出）
.\TDengine-Inspect.ps1 -Quiet

# 指定配置文件
.\TDengine-Inspect.ps1 -ConfigPath "C:\config\my-config.json"

# 指定输出路径
.\TDengine-Inspect.ps1 -OutputPath "C:\reports\inspection.html"
```

### 定时任务

```powershell
# 交互式设置
.\TaskScheduler.ps1

# 列出定时任务
.\TaskScheduler.ps1 -List

# 删除任务
.\TaskScheduler.ps1 -Remove -TaskName "TDengine Inspection"

# 立即执行任务
.\TaskScheduler.ps1 -Run -TaskName "TDengine Inspection"
```

> **提示**：如果遇到执行策略错误，先执行 `Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process`。

## 配置说明

### 连接方式

| 方式 | 端口 | 说明 |
|------|------|------|
| websocket | 6041 | REST API（推荐远程巡检使用） |
| native | 6030 | TDengine 原生协议（需要安装客户端） |

### 阈值配置

```json
{
    "thresholds": {
        "diskUsageWarning": 85,
        "diskUsageCritical": 95,
        "cpuUsageWarning": 80,
        "licenseExpiryDays": 90,
        "licenseUsagePercent": 80,
        "slowQueryLookbackDays": 30,
        "slowQueryThresholdMs": 10000
    }
}
```

### 集群节点

```json
{
    "cluster": {
        "nodes": ["node1.example.com", "node2.example.com", "node3.example.com"],
        "replica": 3
    }
}
```

## 巡检项目

| 序号 | 检查项 | 说明 |
|------|--------|------|
| 1 | 操作系统信息 | 系统名称、版本、内核、启动时间 |
| 2 | CPU 信息 | 型号、架构、核心数 |
| 3 | 内存信息 | 总量、已用、空闲内存 |
| 4 | 网络信息 | FQDN、网卡、带宽 |
| 5 | 数据目录 | 挂载路径、文件系统、空间使用率 |
| 6 | Hosts 配置 | FQDN 到 IP 的映射关系 |
| 7 | Dnode 信息 | Vnode 数量、状态、重启时间 |
| 8 | Mnode 信息 | 角色、状态、角色变更时间 |
| 9 | 数据库列表 | 所有数据库（含 log/audit） |
| 10 | 建库语句 | 数据库创建语句 |
| 11 | 超级表统计 | 按数据库统计超级表数量 |
| 12 | 超级表详情 | 列数、宽度、子表数量 |
| 13 | 磁盘分布 | 超级表磁盘分布情况 |
| 14 | 磁盘使用率 | 空闲空间低于 15% 告警 |
| 15 | CPU 使用率 | 使用率超过 80% 告警 |
| 16 | 防火墙状态 | Windows 防火墙状态 |
| 17 | 服务版本 | taos/taosd/taosAdapter 版本检查 |
| 18 | 服务状态 | taosd、adapter、keeper、explorer 状态 |
| 19 | 错误日志 | 日志中的 ERROR 消息 |
| 20 | 数据库用户 | 用户列表、角色、权限 |
| 21 | 授权信息 | 使用量限制、过期时间 |
| 22 | 慢查询 | 最近 N 天的慢查询记录 |
| 23 | 副本数 | 集群副本因子 |
| 24 | 数据库参数 | TDengine 配置参数 |
| 25 | Vnode Leader 分布 | 每个 Dnode 的 Leader 数量，均衡性检查 |
| 26 | 测点数统计 | 每个数据库的测点总数 |

## 报告状态说明

- **Pass（通过）**：检查完成，未发现问题
- **Warning（警告）**：检查完成，存在需要关注的警告
- **Fail（失败）**：发现严重问题，需要立即处理

## 远程巡检

无需安装 TDengine 客户端即可远程巡检：

1. 使用 WebSocket 连接（6041 端口）
2. 确保远程服务器的 taosAdapter 正在运行
3. 配置防火墙允许 6041 端口

```json
{
    "connection": {
        "method": "websocket",
        "server": "192.168.1.100",
        "port": 6041,
        "user": "root",
        "password": "your_password"
    }
}
```

## 故障排除

### 认证失败

如果启动时看到 `Authentication Failed!`：
- 检查 `config.json` 中的 `user` 和 `password` 配置
- 确认该用户在 TDengine 中存在
- 程序会直接退出，直到凭据修正后才会继续执行

### 连接失败

如果启动时看到 `Connection Failed!`：
- 确认 TDengine 服务正在目标服务器上运行
- 检查防火墙设置（WebSocket 端口 6041，原生协议端口 6030）
- 检查 `config.json` 中的 `server` 和 `port` 配置
- 尝试切换 `method` 在 `websocket` 和 `native` 之间

### 权限不足

- 以管理员身份运行 PowerShell
- 检查 TDengine 用户权限
- 验证 Windows 防火墙规则

### 执行策略错误

如果遇到"禁止运行脚本"错误：
```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
```
或直接使用 `Run-Inspection.bat`（自动绕过执行策略限制）。

### 报告未生成

- 检查输出目录权限
- 确认 `templates/` 目录下模板文件存在
- 检查 PowerShell 执行策略

## 文件结构

```
TDengine-Inspect/
├── TDengine-Inspect.ps1     # 主巡检脚本
├── Run-Inspection.bat       # 快速启动批处理文件
├── build.ps1                 # EXE 打包脚本
├── config.json               # 配置文件
├── TaskScheduler.ps1         # 定时任务设置
├── Test-Modules.ps1          # 模块加载测试
├── README.md                 # 英文文档
├── README_CN.md              # 中文文档
├── CHANGELOG.md              # 版本历史
├── modules/                  # 巡检模块（26 项）
│   ├── 00-Connection.ps1    # 连接处理
│   ├── 01-SystemInfo.ps1    # 系统信息
│   ├── 02-CPUInfo.ps1       # CPU 信息
│   ├── 03-MemoryInfo.ps1    # 内存信息
│   ├── ...
│   ├── 25-VnodeLeader.ps1   # Vnode Leader 分布
│   └── 26-MeasurePoints.ps1 # 测点数统计
├── templates/                # 报告模板
│   └── report-template.html # HTML 模板
├── output/                   # 生成的报告
└── dist/                     # 打包输出（EXE）
```

## 版本历史

### 1.6.1
- SQL 标识符使用反引号包裹，支持特殊字符、连字符、中文名称
- 连接认证早期检测，密码错误时明确提示并直接退出
- 连接失败时区分认证错误和服务器不可达，给出对应提示
- 对不支持 `SHOW TABLE DISTRIBUTED` 的虚拟超级表静默跳过

### 1.6.0
- 修复原生查询挂起问题（改用 stdin 传递 SQL）
- 磁盘分布新增压缩比显示
- 改进原生输出解析

### 1.5.0
- 状态标签重命名：Fail → Critical
- 改进 WebSocket 与原生协议之间的回退逻辑
- 优化连接/认证失败的错误提示

### 1.4.0
- 新增第 26 项：测点数统计
- 新增第 25 项：Vnode Leader 分布检查

### 1.3.0
- 新增 Vnode Leader 分布检查

### 1.2.0
- 新增 EXE 打包支持（build.ps1）
- 专业 HTML 报告，支持侧边栏导航
- 报告顶部告警摘要

### 1.1.0
- 新增侧边栏导航菜单
- 新增内存信息模块
- 改进表格格式

### 1.0.0
- 初始版本，22 项巡检内容
- 支持 WebSocket 和原生连接
- HTML 报告生成
- 定时任务集成

完整版本历史请查看 [CHANGELOG.md](CHANGELOG.md)。

## 许可证

本工具按原样提供，用于 TDengine 数据库巡检。

## 技术支持

如有问题或建议：
- 查看 TDengine 官方文档：https://docs.taosdata.com/
- 联系您的 TDengine 管理员
