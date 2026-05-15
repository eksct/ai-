# 05 生命周期与 Runtime（context）

## 5.1 Runtime 包

Wails 的 Go Runtime 包：

```go
import "github.com/wailsapp/wails/v2/pkg/runtime"
```

该包中多数方法都要求把 `context.Context` 作为第一个参数。

## 5.2 context 的常见获取方式

- **应用启动回调（OnStartup）**：通常在这里保存 `ctx` 引用
- **前端 DOM 加载完成回调（OnDomReady）**：如果你要在“启动时”调用某些 runtime 方法，更建议在这个时机调用

注意：虽然 `ctx` 会传入应用启动回调，但此时窗口仍在初始化，runtime 方法在该回调中不一定可用；如果需要更可靠的时机，请使用“前端 DOM 加载完成回调”。

参考：

- https://wails.io/zh-Hans/docs/reference/runtime/

## 5.3 生命周期回调

### 5.3.1 应用启动回调（OnStartup）

- **时机**：加载 `index.html` 之前
- **做什么**：框架调用你注册的函数，并传入标准 Go `context`
- **常见用法**：保存 `ctx` 引用（例如存到结构体字段），供后续 runtime 调用/业务逻辑使用

### 5.3.2 应用退出回调（OnShutdown）

- **时机**：应用关闭之前
- **常见用法**：清理资源（关闭 DB、保存状态、释放系统资源等）

### 5.3.3 前端 DOM 加载完成回调（OnDomReady）

- **时机**：`index.html` 相关资源加载完成后
- **类比**：类似前端的 `window.onload`
- **常见用法**：更适合在此时机调用 runtime 方法或触发“需要窗口就绪”的逻辑

### 5.3.4 应用关闭前回调（BeforeClose）

- **时机**：用户关闭窗口/应用退出之前
- **用途**：可弹窗确认、阻止关闭或做异步清理

## 5.4 典型执行顺序

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
