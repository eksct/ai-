# 99 FAQ（常见问题）

## 1. 安装了 Wails，但命令行提示找不到 `wails`

- **检查** `GOBIN` / `GOPATH/bin` 是否在 `PATH`
- **确认** `go env GOBIN` 输出目录里是否存在 `wails.exe`

## 2. 在 `OnStartup` 调用 runtime 方法不生效

- **原因**：窗口初始化可能尚未完成
- **建议**：将需要依赖窗口就绪的 runtime 调用放到 `OnDomReady` 对应回调中（以官方文档为准）
