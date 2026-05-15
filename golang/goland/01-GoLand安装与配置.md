# GoLand 安装与配置

## 概述

GoLand 是 JetBrains 出品的 Go IDE，目前最好用的 Go 开发环境没有之一。VS Code + Go 插件也能用，但在重构、调试、代码导航上差 GoLand 一大截。

## 安装

1. 官网下载：https://www.jetbrains.com/go/download/
2. 激活：公司有授权用授权，没有可以试 30 天或申请开源项目许可
3. 如果已经有 JetBrains 系 IDE（IDEA、WebStorm），可以装 GoLand 插件，不过还是推荐独立版

## 首次启动配置

### 导入设置

如果你用过其他 JetBrains IDE，可以直接导入设置（快捷键、配色等）：
```
File → Manage IDE Settings → Import Settings
```

### GoLand 特有的配置项

```
Settings → Go
├── Go Modules
│   ├── Enable Go modules integration ✓
│   └── Proxy: https://goproxy.cn,https://goproxy.io,direct  # 国内必配
├── Build Tags & Vendoring
│   └── 如果你的项目用 vendor，在这里配
├── GOPATH
│   └── 新项目用 module，GOPATH 基本用不上了，不用管
└── Test Runner
    └── 默认就行，和 Go CLI 一致
```

### Go Proxy 配置（国内必做）

```
Settings → Go → Go Modules → Environment
添加: GOPROXY=https://goproxy.cn,https://goproxy.io,direct
```

不然你每次 `go mod tidy` 都要等半天，甚至超时报错。

## 项目导入

### 已有 Go 项目

```
File → Open → 选择项目目录
```

GoLand 会自动识别 `go.mod`，加载 module。

### 新建项目

```
File → New → Project
├── Type: Go Modules
├── Location: 选项目目录
└── Create "main.go" sample ✓   # 如果要 Hello World 就勾上
```

### 设置 module

```
File → New → Project
     → Go Modules
     → Module name: github.com/yourname/project
```

## 编译配置

### 默认 Run Configuration

```
Run → Edit Configurations → + → Go Build
├── Run kind: Directory（单文件）/ Package（整个包）/ File（测试用）
├── Directory: 选 main.go 所在的目录
├── Working directory: 默认项目根目录
├── Program arguments: 命令行参数（如 wails dev 的参数）
├── Environment: 环境变量
│   └── DB_PASSWORD=xxx;REDIS_HOST=localhost
└── Before launch: 可配编译前执行的任务
```

### Wails 项目的 Run Configuration

Wails 项目不能用普通的 Go Build 运行，要走 `wails dev`。

**方案一：Task 配置**
```
Run → Edit Configurations → + → Go Build（不直接运行 wails）
```

更好的方式是用 Terminal 直接跑 `wails dev`，GoLand 内置终端支持多 session。

**方案二：Shell Script 配置**
```
Run → Edit Configurations → + → Shell Script
Script: wails dev
Working directory: 项目目录
```

## 实用设置

```ini
# 自动导入（Save 时自动加 import）
Settings → Editor → General → Auto Import
  ✓ Add unambiguous imports on the fly
  ✓ Optimize imports on the fly

# 文件保存时格式化
Settings → Tools → Actions on Save
  ✓ Reformat code
  ✓ Optimize imports

# 禁用行对齐（GoLand 默认对齐很丑）
Settings → Editor → Code Style → Go → Other
  ✓ Align import statements: 关掉

# 字体放大
Settings → Editor → General → Mouse Control
  ✓ Change font size with Ctrl+Mouse Wheel
```

## 版本管理

GoLand 内置 Git 集成，不需要切命令行：

```
快捷键	           功能
Ctrl+K	           Commit
Ctrl+Shift+K       Push
Ctrl+T	           Update（pull + rebase）
Alt+9	           打开 Git 面板
Ctrl+Alt+Z	        Rollback（回退当前文件改动）
```

**Wails 项目开发时不要忘记：** `wails.json`、`go.mod` 这些构建相关文件在 commit 前看一眼有没有不该提交的改动。
