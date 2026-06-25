# nginx.conf 全局块配置

## 概述

全局块（main context）是 `nginx.conf` 最外层的配置段落，作用于 Nginx 主进程和所有 worker 进程。`events {}`、`http {}`、`mail {}` 等块都在它之下。

## 常用配置

### 运行相关

| 指令 | 说明 |
|------|------|
| `user nginx;` | worker 进程运行用户，不要用 root |
| `pid /run/nginx.pid;` | PID 文件路径 |
| `worker_processes auto;` | worker 数量，auto = CPU 核心数 |
| `worker_rlimit_nofile 65535;` | worker 最大文件句柄数，防 "too many open files" |

### 日志

```nginx
error_log /var/log/nginx/error.log warn;
```

日志等级从低到高：debug → info → notice → warn → error → crit → alert → emerg。不写等级默认 `error`。

开发调试用 `debug`，生产用 `warn` 或 `error`。

### 性能

| 指令 | 说明 |
|------|------|
| `worker_cpu_affinity auto;` | worker 绑定 CPU 核心，避免缓存抖动 |
| `pcre_jit on;` | 正则表达式 JIT 编译加速，有提升但不大 |
| `ssl_engine` | 硬件 SSL 加速，用硬件 SSL 卡时才配 |

### 加载动态模块

```nginx
load_module modules/ngx_http_geoip_module.so;
```

### 调试

| 指令 | 说明 |
|------|------|
| `daemon on;` | 是否后台运行，容器化时设为 off |
| `master_process on;` | 是否多进程模式，调试分析时偶尔设为 off |

## 性能调参公式

单机 4 核 + 8G，常见 Web 场景：

```nginx
user                 nginx;
worker_processes     auto;
worker_rlimit_nofile 65535;
error_log            /var/log/nginx/error.log warn;
pid                  /var/run/nginx.pid;
pcre_jit             on;

events {
    worker_connections 16384;
    multi_accept on;
}
```

## 踩坑

### 忘记调 worker_rlimit_nofile

配了 `worker_connections 65535` 却忘了 `worker_rlimit_nofile`，压测时报：

```
2024/01/01 12:00:00 [alert] 1234#0: *5678 open() "/var/log/nginx/access.log" failed (24: Too many open files)
```

解决：全局块加 `worker_rlimit_nofile 65535;`，同时系统层面也要放行（`/etc/security/limits.conf`）。

### daemon off 的场景

Docker 容器中 Nginx 必须前台运行（`daemon off;`），否则容器启动即退出。CMD 通常是：

```dockerfile
CMD ["nginx", "-g", "daemon off;"]
```

## 总结

全局块 90% 场景只配四项：`user`、`worker_processes`、`worker_rlimit_nofile`、`error_log`。其他有需求再加。

## 参考

[[Nginx 基础]]
