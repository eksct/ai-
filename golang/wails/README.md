# Wails 学习笔记（目录）

## 学习路线（从 0 到 1）

### 第 1 阶段：跑起来

- 目标
  - 安装 Wails CLI
  - 能创建并运行一个模板项目
- 阅读
  - [01-安装与环境检查](./01-%E5%AE%89%E8%A3%85%E4%B8%8E%E7%8E%AF%E5%A2%83%E6%A3%80%E6%9F%A5.md)
  - [02-创建项目与项目结构](./02-%E5%88%9B%E5%BB%BA%E9%A1%B9%E7%9B%AE%E4%B8%8E%E9%A1%B9%E7%9B%AE%E7%BB%93%E6%9E%84.md)
  - [03-常用命令（dev/build）](./03-%E5%B8%B8%E7%94%A8%E5%91%BD%E4%BB%A4%EF%BC%88dev-build%EF%BC%89.md)
- 练习
  - 用你常用的前端模板（如 `vanilla-ts` 或 `react-ts`）新建一个项目并运行 `wails dev`

### 第 2 阶段：理解架构与数据流

- 目标
  - 理解 Wails 的基本组成：Go 后端 + WebView 前端 + runtime + Bind
  - 能解释清楚“前端如何调用 Go 方法”
- 阅读
  - [04-Wails 工作原理（核心概念）](./04-Wails%20%E5%B7%A5%E4%BD%9C%E5%8E%9F%E7%90%86%EF%BC%88%E6%A0%B8%E5%BF%83%E6%A6%82%E5%BF%B5%EF%BC%89.md)
  - [05-生命周期与 Runtime（context）](./05-%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E4%B8%8E%20Runtime%EF%BC%88context%EF%BC%89.md)

### 第 3 阶段：前后端通信与类型

- 目标
  - 熟练使用 `Bind`
  - 理解 `wailsjs` 生成物（JS/TS 声明、models）
- 阅读
  - [06-方法绑定（Bind）与前端调用](./06-%E6%96%B9%E6%B3%95%E7%BB%91%E5%AE%9A%EF%BC%88Bind%EF%BC%89%E4%B8%8E%E5%89%8D%E7%AB%AF%E8%B0%83%E7%94%A8.md)

### 第 4 阶段：Runtime 常用能力

- 目标
  - 会用 Events 做事件通信
  - 会用 Log 记录与排查问题
- 阅读
  - [07-Runtime：Events / Log](./07-Runtime%EF%BC%9AEvents%20-%20Log.md)

## 其他

- 常见问题与坑位：
  - [99-FAQ（常见问题）](./99-FAQ%EF%BC%88%E5%B8%B8%E8%A7%81%E9%97%AE%E9%A2%98%EF%BC%89.md)

## 说明

- 本目录下 `wails.md` 作为旧版单文件笔记保留；后续建议统一往本目录结构里追加内容。
