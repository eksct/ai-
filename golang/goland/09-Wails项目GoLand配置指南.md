# Wails 项目 GoLand 配置指南

## 概述

这是专门针对 Wails 项目的 GoLand 配置指南。普通 Go 项目直接点运行就行，Wails 项目因为有 WebView 前端，需要一些额外配置。

## 项目结构

Wails 项目在 GoLand 中的典型结构：

```
image-app/                         ← GoLand 项目根
├── main.go                        ← 入口
├── app.go                         ← App struct
├── go.mod
├── wails.json
├── frontend/                      ← 前端（Vue/React/Svelte）
│   ├── src/
│   ├── package.json
│   └── dist/
├── build/                         ← 构建配置
├── wailsjs/                       ← 生成的绑定代码
│   └── go/main/App.js
└── .gitignore
```

## 运行配置

Wails 不能用普通的 `Go Build` 运行，因为需要 Wails CLI 管理 WebView。

### 方案一：Terminal（推荐）

在 GoLand Terminal 中运行：

```bash
# 终端 1（主）
wails dev

# 如果出了编译报错，GoLand 的 Problems 面板也能看到
# 终端 2（备，用于前端调试）
cd frontend && npm run dev  # 如果 wails dev 没有自动启动前端 dev server
```

**优势：** 简单、热更新正常、Log 实时输出

### 方案二：Shell Script 配置

```
Run → Edit Configurations → + → Shell Script
Name: Wails Dev
Script: wails dev
Working directory: 项目根目录
```

这样点绿色三角就能运行。但 Terminal 里输出的日志会出现在 Run 面板而不是 Terminal。

### 方案三：npm Script（如果前端需要单独调试）

```
Run → Edit Configurations → + → npm
Name: Frontend Dev
Script: dev
Package.json: frontend/package.json
```

## 目录标记

```
右键 wailsjs/     → Mark Directory as → Excluded
右键 build/bin/   → Mark Directory as → Excluded
右键 frontend/node_modules/ → Mark Directory as → Excluded
```

标记为 Excluded 后 GoLand 不再索引这些目录——搜索更快、CPU 占用更低。

## 文件监视

Wails 的热更新（`wails dev`）会监控 Go 文件变动并重新编译。GoLand 保存文件时会触发文件系统的修改事件，Wails 检测到后会自动重新编译。

**需要注意：**
- GoLand 的自动保存默认是在失去焦点时
- 切到浏览器看效果时，GoLand 自动保存 → Wails 检测到变化 → 重新编译 → 刷新

整个过程是全自动的，不需要手动操作。但如果改了 `main.go` 或 `wails.json`，建议手动重启 `wails dev`。

## 调试配置

Wails 项目调试不能直接 Debug——`wails dev` 启动的是 WebView 进程。

### Attach 方式

```bash
# 终端运行
wails dev

# 然后 GoLand 中
Run → Attach to Process → 选择 image-app
```

这时候在 Go 代码中设断点就会停住。

### Debug Mode

Wails v2 不支持直接的 debug 模式启动。
Wails v3（alpha）支持。

当前版本建议用 Attach 方式。

## Go Module 配置

Wails 的 go.mod 看起来像这样：

```
module image-app

go 1.21

require github.com/wailsapp/wails/v2 v2.x.x
```

GoLand 会自动识别 module，不需要额外配置。唯一要确认的是：

```
Settings → Go → Go Modules → Enable Go modules integration: ✓
```

## 前端代码提示

GoLand 对前端框架的支持有限。如果你用 Vue/React + TypeScript：

```
Settings → Languages & Frameworks → JavaScript → Libraries
→ 添加 frontend/node_modules 为库
```

或者干脆前端用 VS Code 写，Go 后端用 GoLand。很多人这样做。

## .gitignore

```
# Wails
wailsjs/
build/bin/

# Go
vendor/

# IDE
.idea/
*.iml

# 前端
frontend/node_modules/
frontend/dist/

# 本地环境
.env.local
*.local
```
