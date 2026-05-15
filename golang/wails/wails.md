# Wails 学习笔记
 
 > 提示：这份 `wails.md` 为历史单文件笔记。
 > 
 > 后续内容建议按目录化方式维护：请从 `README.md` 进入，并在对应章节文件中追加。
 
 - 目录入口：`README.md`

## 1. 安装与环境检查
 
### 1.1 安装 Wails CLI
 
要求：Go 版本建议 `>= 1.18`（以 Wails 官方要求为准）。
 
```bash
go install github.com/wailsapp/wails/v2/cmd/wails@latest
```
 
### 1.2 检查依赖
 
运行 `wails doctor` 检查依赖是否齐全；若缺少依赖，它会给出建议。

```bash
wails doctor
```

### 1.3 常见问题：命令行找不到 wails

如果命令行提示找不到 `wails`：

- **检查** `GOBIN` / `GOPATH/bin` 是否在 `PATH` 环境变量中
- **确认** `go env GOBIN` 输出目录里是否存在 `wails.exe`

## 2. 创建项目

使用 `wails init` 生成新项目。

- **内置模板**：`svelte`、`react`、`vue`、`preact`、`lit`、`vanilla` 等
- **社区模板**：
  - https://wails.io/zh-Hans/docs/community/templates/
- **TypeScript 模板**：通常在模板名后追加 `-ts`，例如 `vanilla-ts`

查看参数：

```bash
wails init --help
```

## 3. 项目结构

典型目录结构：

```text
.
├── build/
│   ├── appicon.png
│   ├── darwin/
│   └── windows/
├── frontend/
├── go.mod
├── go.sum
├── main.go
└── wails.json
```

结构说明：

- **`main.go`**：主应用入口
- **`frontend/`**：前端项目（本质上不要求特定框架/结构）
- **`build/`**：打包相关配置/资源
  - **`build/appicon.png`**：应用图标
  - **`build/darwin/`**：macOS 相关配置
  - **`build/windows/`**：Windows 相关配置
- **`wails.json`**：Wails 项目配置
- **`go.mod` / `go.sum`**：Go Module 文件

补充：`build/` 中的文件可修改以自定义构建；如果从 `build/` 删除文件，Wails 会重新生成默认版本。

## 4. 常用命令

开发运行（带热更新）：

```bash
wails dev
```

编译为二进制：

```bash
wails build
```

CLI 参考：

- https://wails.io/zh-Hans/docs/reference/cli/#%E5%BC%80%E5%8F%91

## 5. Wails 的工作原理（核心概念）

Wails 应用可以理解为：

- **后端**：标准 Go 应用 + Wails Runtime（窗口、事件、对话框、日志等能力）
- **前端**：运行在 WebView（WebKit/WebView2）的页面（展示 `index.html` 及其资源）
- **通信**：把 Go 的结构体方法“绑定（Bind）”到前端，前端以调用 JS 函数的方式调用 Go 方法

你在前端通过 `import` 引入 Wails 生成的 JS/TS 绑定函数，然后像普通异步函数一样调用，就能执行对应的 Go 方法。

## 6. `main.go` 示例（含关键选项）

下面是一个典型的 `main.go` 结构（示例中补全了必要 import，方便直接理解/编译）：

```go
package main

import (
    "context"
    "embed"
    "fmt"
    "log"

    "github.com/wailsapp/wails/v2"
    "github.com/wailsapp/wails/v2/pkg/options"
    "github.com/wailsapp/wails/v2/pkg/options/assetserver"
)

//go:embed all:frontend/dist
var assets embed.FS

type App struct {
    ctx context.Context
}

func (a *App) startup(ctx context.Context) {
    a.ctx = ctx
}

func (a *App) shutdown(ctx context.Context) {}

func (a *App) Greet(name string) string {
    return fmt.Sprintf("Hello %s!", name)
}

func main() {
    app := &App{}

    err := wails.Run(&options.App{
        Title:  "Basic Demo",
        Width:  1024,
        Height: 768,
        AssetServer: &assetserver.Options{
            Assets: assets,
        },
        OnStartup:  app.startup,
        OnShutdown: app.shutdown,
        Bind: []interface{}{
            app,
        },
    })
    if err != nil {
        log.Fatal(err)
    }
}
```

### 6.1 选项概要

- **`Title`**：窗口标题
- **`Width` / `Height`**：窗口尺寸
- **`AssetServer.Assets`**：前端资源（`embed.FS`）
- **`OnStartup`**：窗口创建完成、即将加载前端资源时的回调
- **`OnShutdown`**：应用即将退出时的回调
- **`Bind`**：要暴露给前端调用的结构体实例列表

参数参考：

- http://wails.io/zh-Hans/docs/reference/options/

## 7. `embed.FS` 与前端资源加载

`Assets` 选项是必须的：Wails 必须有前端资源（HTML/JS/CSS/SVG/PNG 等）。

关键点：

- 生产环境：二进制中包含 `embed.FS` 的资源，不需要额外拷贝前端文件
- 开发模式：`wails dev` 会从磁盘加载资源，并提供热更新；资源位置会根据 `embed.FS` 路径推断

示例：

```go
//go:embed all:frontend/dist
var assets embed.FS
```

启动时，Wails 会在嵌入文件中查找 `index.html`；其他资源以该目录为根进行相对加载。

默认模板通常是：

- `main.go`：配置并启动应用
- `app.go`：承载业务逻辑（结构体方法、生命周期回调等）

## 8. Runtime 与生命周期（context 的来源）

Wails 的 Go Runtime 包：

```go
import "github.com/wailsapp/wails/v2/pkg/runtime"
```

该包中多数方法都要求把 `context.Context` 作为第一个参数。

`context` 的常见获取方式：

- **应用启动回调（OnStartup）**：通常在这里保存 `ctx` 引用
- **前端 DOM 加载完成回调（OnDomReady）**：如果你要在“启动时”调用某些 runtime 方法，更建议在这个时机调用

注意：虽然 `ctx` 会传入应用启动回调，但此时窗口仍在初始化，runtime 方法在该回调中不一定可用；如果需要更可靠的时机，请使用“前端 DOM 加载完成回调”。

参考：

- https://wails.io/zh-Hans/docs/reference/runtime/

Wails 提供多种生命周期回调，这些方法都会被传入一个标准的 Go `context`。

### 8.1 应用启动回调（OnStartup）

- **时机**：加载 `index.html` 之前
- **做什么**：框架调用你注册的函数，并传入标准 Go `context`
- **常见用法**：保存 `ctx` 引用（例如存到结构体字段），供后续 runtime 调用/业务逻辑使用

### 8.2 应用退出回调（OnShutdown）

- **时机**：应用关闭之前
- **常见用法**：清理资源（关闭 DB、保存状态、释放系统资源等）

### 8.3 前端 DOM 加载完成回调（OnDomReady）

- **时机**：`index.html` 相关资源加载完成后
- **类比**：类似前端的 `window.onload`
- **常见用法**：更适合在此时机调用 runtime 方法或触发“需要窗口就绪”的逻辑

### 8.4 应用关闭前回调（BeforeClose）

- **时机**：用户关闭窗口/应用退出之前
- **用途**：可弹窗确认、阻止关闭或做异步清理

### 8.5 典型执行顺序

```text
应用启动
  -> OnStartup（保存 context）
  -> 加载 index.html
  -> OnDomReady（前端资源就绪）
用户使用应用
  -> BeforeClose（可阻止关闭）
  -> OnShutdown（清理资源）
应用结束
```

## 9. 方法绑定（Bind）与前端调用

`Bind` 是 Wails 最核心的能力之一：它决定前端能调用哪些 Go 方法。

关键点：

- Wails 会检查 `Bind` 里列出的**结构体实例**，把它们的**导出方法（大写开头）**生成对应的 JS/TS 调用封装
- 开发模式（`wails dev`）或执行 `wails generate module` 会生成前端可用的模块

生成内容通常包括：

- 所有绑定方法的 JavaScript 封装
- 所有绑定方法的 TypeScript 声明
- 绑定方法入参/出参涉及的 Go struct 对应的 TS 类型（`models`）

运行 `wails dev` 后，常见生成目录：

```text
wailsjs/
  └─go/
    └─main/
      ├─App.d.ts
      └─App.js
```

前端调用示例：

```js
import { Greet } from "../wailsjs/go/main/App";

function doGreeting(name) {
  Greet(name).then((result) => {
    // Do something with result
  });
}
```

对应的 TS 声明示例：

```ts
export function Greet(arg1: string): Promise<string>;
```

调用成功时：Go 的返回值会传递给 `resolve`；失败时：错误会通过 `reject` 传回（传递无效参数也可能触发错误）。

### 9.1 结构体类型映射（models）

如果绑定方法使用了 Go 结构体作为入参/出参，Wails 会生成 `models` 类型声明。

示例（`App.d.ts` 可能变为）：

```ts
import { main } from "../models";
export function Greet(arg1: main.Person): Promise<string>;
```

前端创建结构体并调用：

```ts
import { Greet } from "../wailsjs/go/main/App";
import { main } from "../wailsjs/go/models";

function generate() {
  const person = new main.Person();
  person.name = "Peter";
  person.age = 27;
  Greet(person).then((result) => {
    console.log(result);
  });
}
```

注意点：

- 结构体字段需要有效的 `json` tag，才能正确生成 TS 类型
- 目前不支持嵌套匿名结构体（以官方文档为准）

## 10. Runtime 能力（Events / Log 等）

你也可以在前端通过 `window.runtime` 调用部分 runtime 方法。

### 10.1 Events

参考：

- https://wails.io/zh-Hans/docs/reference/runtime/events

### 10.2 Log

参考：

- https://wails.io/zh-Hans/docs/reference/runtime/log

Wails runtime 提供日志级别：

- **Trace**
- **Debug**
- **Info**
- **Warning**
- **Error**
- **Fatal**

日志器会输出“当前级别及以上”的日志。例如设置为 `Debug` 时会输出 `Debug/Info/Warning/Error/Fatal`，但不会输出 `Trace`。

### 10.3 自定义日志（Logger）

可以通过应用参数选项配置自定义 logger。要求：实现 `github.com/wailsapp/wails/v2/pkg/logger` 中的 `logger.Logger` 接口。

接口示例：

```go
type Logger interface {
    Print(message string)
    Trace(message string)
    Debug(message string)
    Info(message string)
    Warning(message string)
    Error(message string)
    Fatal(message string)
}
```

## 11. 参考

- https://wails.io/zh-Hans/docs/introduction