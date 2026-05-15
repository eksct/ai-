# Runtime：Events / Log

## Events（事件系统）

Events 是 Wails 里**后端主动推数据给前端**的唯一方式。Bind 是你调用我，Events 是我通知你。

### Go 端发送事件

```go
import "github.com/wailsapp/wails/v2/pkg/runtime"

// 发送简单事件
runtime.EventsEmit(ctx, "image:selected", imagePath)

// 发送带进度的事件（图像处理场景）
func (a *App) ProcessImages(images []string) {
    // 注意：要在 goroutine 里跑，否则会阻塞前端
    go func() {
        for i, img := range images {
            result := processOneImage(img)
            // 推送进度给前端
            runtime.EventsEmit(a.ctx, "image:progress", map[string]interface{}{
                "current": i + 1,
                "total":   len(images),
                "path":    img,
                "result":  result,
            })
        }
        // 全部完成
        runtime.EventsEmit(a.ctx, "image:done", nil)
    }()
}
```

### 前端接收事件

```js
import { EventsOn, EventsOff } from "../wailsjs/runtime";

// 监听事件
EventsOn("image:progress", (data) => {
    // data 是 Go 端传过来的 map
    const percent = Math.round((data.current / data.total) * 100);
    progressBar.value = percent;
    statusText.value = `处理中: ${data.path}`;
});

// 记得在组件卸载时取消监听
onUnmounted(() => {
    EventsOff("image:progress");
});
```

### 前端发送事件给 Go

```js
import { EventsEmit } from "../wailsjs/runtime";

// 前端主动发事件给 Go
EventsEmit("ui:themeChanged", "dark");
```

Go 端接收：
```go
runtime.EventsOn(a.ctx, "ui:themeChanged", func(optionalData ...interface{}) {
    if len(optionalData) > 0 {
        theme := optionalData[0].(string)
        a.currentTheme = theme
    }
})
```

### Events 事件命名规范

```
前缀 + 冒号 + 动作

✅ image:selected
✅ image:progress
✅ image:done
✅ ui:themeChanged
✅ file:saved
✅ app:beforeClose

❌ progressUpdate（太宽泛）
❌ DONE（冲突风险）
❌ 123event（首字母数字）
```

### Events 时序陷阱

```
Go → EventsEmit("progress", 50)
     │
     ▼
     问题是：如果前端这时候还没注册 EventsOn("progress")
     这个事件就丢了，前端永远收不到
```

**解决：** 如果 Go 端在 `OnStartup` 里发了事件，前端要在 `OnDomReady` 之后才注册监听，就可能错过。稳妥做法：
- Go 端延迟发送（等前端就绪）
- 或者前端在 `onMounted` 先注册监听，再通知 Go 端开始

## Log（日志）

### Go 端

```go
import "github.com/wailsapp/wails/v2/pkg/runtime"

runtime.LogInfo(a.ctx, "用户打开了图片")
runtime.LogWarning(a.ctx, "图片格式不支持: %s", ext)
runtime.LogError(a.ctx, "读取文件失败: %v", err)
```

### 前端

```js
import { LogInfo, LogError } from "../wailsjs/runtime";

LogInfo("前端日志");
LogError("出错了");
```

**日志最佳实践（桌面端）：**
- 用户操作日志写到 `Info`（方便排查用户操作路径）
- 异常写 `Error`（跟 Bind 返回的 error 不同——日志是自己看的，错误提示是给用户看的）
- 不要打敏感信息（用户本地路径、文件名可能暴露隐私）
- Wails 的 Log 默认只输出到终端，生产环境建议搭一个自定义 Logger 落文件

### 自定义 Logger 落文件

```go
type FileLogger struct {
    file *os.File
}

func NewFileLogger(path string) *FileLogger {
    f, _ := os.OpenFile(path, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0644)
    return &FileLogger{file: f}
}

func (l *FileLogger) Print(message string)  { l.file.WriteString("[PRINT] " + message + "\n") }
func (l *FileLogger) Trace(message string)  { l.file.WriteString("[TRACE] " + message + "\n") }
func (l *FileLogger) Debug(message string)  { l.file.WriteString("[DEBUG] " + message + "\n") }
func (l *FileLogger) Info(message string)   { l.file.WriteString("[INFO] " + message + "\n") }
func (l *FileLogger) Warning(message string){ l.file.WriteString("[WARN] " + message + "\n") }
func (l *FileLogger) Error(message string)  { l.file.WriteString("[ERROR] " + message + "\n") }
func (l *FileLogger) Fatal(message string)  { l.file.WriteString("[FATAL] " + message + "\n") }

// 在 main.go 中使用
appOptions := &options.App{
    Logger: NewFileLogger(filepath.Join(homeDir, ".imageapp", "app.log")),
}
```
