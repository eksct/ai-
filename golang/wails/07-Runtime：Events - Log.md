# 07 Runtime：Events / Log

你也可以在前端通过 `window.runtime` 调用部分 runtime 方法。

## 7.1 Events

参考：

- https://wails.io/zh-Hans/docs/reference/runtime/events

## 7.2 Log

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

## 7.3 自定义日志（Logger）

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
