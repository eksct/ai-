# nginx.conf events 块配置

## 概述

`events {}` 块控制 Nginx 如何管理网络连接，位于全局块之下、`http {}` 之上。大多数情况下默认值就够用。

## 可配置项

```
events {
    worker_connections  1024;    # 每个 worker 最大并发连接数
    multi_accept        on;      # 一次收完所有等待的连接
    use                 epoll;   # 事件模型，默认自动选最优
    accept_mutex        on;      # 多个 worker 抢连接时加锁
}
```

### worker_connections

唯一需要关心的一行。每个 worker 进程能同时保持的最大连接数。

```
最大并发 ≈ worker_processes × worker_connections
```

反向代理场景每个请求消耗两个连接（客户端→Nginx + Nginx→上游），所以实际并发约减半。

### multi_accept

`off`（默认）：收到新连接通知后一次只收一个。
`on`：把内核等待队列里排队的连接一次收完。

高并发下建议 `on`，减少系统调用次数。

### use

| 平台 | 事件模型 |
|------|---------|
| Linux | epoll（默认） |
| FreeBSD / macOS | kqueue（默认） |
| Windows | select（默认，不推荐生产） |
| Solaris | event ports / poll |

不用显式写，Nginx 编译时自动选最优。

### accept_mutex

`on`（默认）：多个 worker 抢新连接时加锁轮流接收，防止惊群（thundering herd）。
`off`：所有 worker 一起抢。

新版 Nginx 的 `accept_mutex` 默认已优化，不需要改。

## 踩坑

### 只配 worker_connections 没配 worker_rlimit_nofile

高并发下报 "Too many open files"。

### 反向代理下误解并发数

`worker_connections 1024` **不是**能同时服务 1024 个用户。反向代理时一个请求占用两个连接，实际并发约 500 左右。

## 总结

`events {}` 配好 `worker_connections` 就够了。其他指令默认值已经是最佳实践。

## 参考

[[nginx.conf 全局块配置]]
[[Nginx 基础]]
