# 04 Wails 工作原理（核心概念）

Wails 应用可以理解为：

- **后端**：标准 Go 应用 + Wails Runtime（窗口、事件、对话框、日志等能力）
- **前端**：运行在 WebView（WebKit/WebView2）的页面（展示 `index.html` 及其资源）
- **通信**：把 Go 的结构体方法“绑定（Bind）”到前端，前端以调用 JS 函数的方式调用 Go 方法

你在前端通过 `import` 引入 Wails 生成的 JS/TS 绑定函数，然后像普通异步函数一样调用，就能执行对应的 Go 方法。
