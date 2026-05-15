# FAQ（常见问题）

## 1. 命令行找不到 wails

**原因：** Go 的 bin 目录不在 PATH 里

```bash
# 查看 GOBIN
go env GOBIN
# 如果为空，默认是 GOPATH/bin
go env GOPATH
# 把输出的路径加到 PATH
# Windows PowerShell
$env:Path += ";$env:USERPROFILE\go\bin"
```

## 2. OnStartup 里调 runtime 方法不生效

**原因：** 窗口还没初始化完成，runtime API 不可用

**解决：** 把需要窗口的调用放到 OnDomReady 里，或者用 `time.AfterFunc` 延迟 100ms

## 3. Bind 方法返回了，但前端拿不到结果

**可能原因：**
- 方法没有导出（小写字母开头）
- 返回值类型不支持 JSON 序列化（比如 channel、func）
- 方法 panic 了但没 recover

```go
// ✅ 正确的绑定方法
func (a *App) GetImageInfo(path string) (*ImageInfo, error) {
    // 返回 struct pointer + error 是最标准的模式
}

// ❌ 不支持的返回类型
func (a *App) GetData() chan int  // channel 无法序列化
```

## 4. wails dev 热更新不生效

**原因：** 取决于前端框架。如果是 vanilla 或 react-ts，确认：
- frontend 目录结构没有乱改
- 前端 dev server 正常运行（Wails 会启动它并在后台监听）

**排查：** 改一个前端文件，看命令行有没有触发重新构建。如果改了没反应，`wails dev` 重启一次。

## 5. Build 出来的 exe 太大（100MB+）

**原因：** Wails 嵌入了 WebView2 和前端资源

**优化：**
```bash
# 使用 UPX 压缩
wails build -upx

# 或者指定压缩级别
wails build -upxflags "--best --lzma"

# 如果不用内嵌 WebView2，可以指定 system 模式（但要用户自己装）
# wails.json 中指定 webview2: "download" 或 "embed"
```

## 6. 图片解码 OOM

**现象：** 用户选了张超大图（如扫描仪导出的 200MB TIFF），应用直接崩溃

**解决：** 参考《09-异步与性能》的图像解码节流做法：先读头获取尺寸、缩略图按需解码、限制并发数

## 7. 窗口位置记不住

每次打开应用都在屏幕左上角——很烦。参考《08-窗口管理与对话框》的保存/恢复窗口位置。

## 8. Mac 上菜单事件不触发

Wails v2 在某些 macOS 版本上菜单回调可能有问题。如果遇到：
```go
// 替代方案：不用菜单，用 Events + 前端快捷键
runtime.EventsOn(a.ctx, "menu:open", func(data ...interface{}) {
    // 处理打开文件
})
```
然后在快捷键回调中发 Events。

## 9. Windows 上应用打不开（报 dll 缺失）

**原因：** 缺少 WebView2 运行时

**解决：** 
- 在安装包中附带 WebView2 安装程序
- 或用户手动下载安装：https://developer.microsoft.com/en-us/microsoft-edge/webview2/
- build 时指定 `webview2: "embed"`（增大 2MB 但用户不用额外安装）

## 10. 前端如何检测 Go 端是否就绪

```js
import { EventsOn, EventsEmit } from '../wailsjs/runtime'

// 在 Go 的 OnDomReady 里发了 "app:ready" 事件
EventsOn("app:ready", () => {
    // Go 端准备好了，可以开始加载数据
    startApp()
})
```
