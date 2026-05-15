# 生命周期与 Runtime（context）

## context 就是"遥控器"

Wails 的 `context.Context` 不是传统 Go 里用来做超时取消的 context，它在 Wails 里是**调用 Runtime API 的通行证**。没有它，你就不能操作窗口、发事件、弹对话框。

### context 的保存

```go
type App struct {
    ctx context.Context  // 在 OnStartup 保存，全局使用
}

func (a *App) startup(ctx context.Context) {
    a.ctx = ctx  // 存起来，后面的 Bind 方法和业务逻辑都用它
}
```

## 生命周期回调详解

### OnStartup（应用启动）

```go
OnStartup: func(ctx context.Context) {
    a.ctx = ctx
    // 不要在这里调 runtime 方法！窗口还没准备好
    // ❌ runtime.OpenFileDialog(a.ctx, ...)  // 窗口还没初始化
    // ✅ 只做数据初始化
    a.initDatabase()
    a.loadSettings()
}
```

### OnDomReady（前端就绪）

```go
OnDomReady: func(ctx context.Context) {
    // ✅ 窗口已经初始化完毕，可以调 runtime 了
    // 适合在这里触发初始数据加载
    runtime.EventsEmit(ctx, "app:ready", nil)
}
```

### OnShutdown（应用退出）

```go
OnShutdown: func(ctx context.Context) {
    a.db.Close()
    a.saveSettings()
    a.cancelRunningTasks()
}
```

### BeforeClose（拦截关闭）

```go
// 在应用选项中配置
BeforeClose: func(ctx context.Context) bool {
    // 返回 true 阻止关闭，false 允许关闭
    // 适合：有未保存的编辑时弹窗确认
    if a.hasUnsavedChanges {
        selected, _ := runtime.MessageDialog(ctx, runtime.MessageDialogOptions{
            Type:          runtime.QuestionDialog,
            Title:         "确认退出",
            Message:       "有未保存的更改，确定退出吗？",
            DefaultButton: "取消",
            CancelButton:  "退出",
        })
        return selected == "Cancel"  // 点了取消就阻止关闭
    }
    return false  // 允许关闭
}
```

## 常见坑

### 1. OnStartup 里调 runtime 方法不生效

上面说了，窗口还没初始化。如果你确实需要在启动时调 runtime 方法，有两种选择：

```go
// 方案一：延迟执行
OnStartup: func(ctx context.Context) {
    a.ctx = ctx
    time.AfterFunc(100*time.Millisecond, func() {
        runtime.EventsEmit(ctx, "late:start", nil) // 延迟 100ms 等窗口就绪
    })
}

// 方案二：用 OnDomReady
OnDomReady: func(ctx context.Context) {
    runtime.EventsEmit(ctx, "app:ready", nil) // 这个时候窗口肯定就绪了
}
```

### 2. context 传给了 goroutine

```go
func (a *App) LongRunningTask() {
    go func() {
        // ✅ 可以把 ctx 传给 goroutine
        // ctx 在应用生命周期内一直有效
        for i := 0; i < 100; i++ {
            runtime.EventsEmit(a.ctx, "task:progress", i)
        }
    }()
}
```

但注意：如果应用退出了，ctx 就失效了。goroutine 里要用 `select` 监听 ctx.Done。

### 3. 多个结构体绑定时的 context

如果你的服务层也用了多个结构体，每个都需要 ctx：

```go
type ImageService struct {
    ctx context.Context
}

func (s *ImageService) OnStartup(ctx context.Context) {
    s.ctx = ctx
}

func (s *ImageService) LoadImage(path string) *Image {
    runtime.LogInfo(s.ctx, "加载图片: "+path)
    // ...
}

// main.go
imageService := &ImageService{}
wails.Run(&options.App{
    OnStartup: func(ctx context.Context) {
        app.startup(ctx)
        imageService.OnStartup(ctx)
    },
    Bind: []interface{}{
        app,
        imageService,
    },
})
```

## 执行顺序

```
应用启动
  → OnStartup（保存 ctx，初始化数据，但不能调 runtime）
  → 加载 index.html、前端资源
  → OnDomReady（可以调 runtime 了，通知前端数据加载）
  → 用户交互（Bind 调用、Events 推送）
  → BeforeClose（询问是否保存，可选阻止关闭）
  → OnShutdown（关闭连接，保存设置，清理临时文件）
应用结束
```
