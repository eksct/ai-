# nginx.conf upstream 块配置

## 概述

`upstream {}` 定义一组后端服务器，用于负载均衡。`proxy_pass` 引用它，请求轮询发送到组内的服务器。

## 基础配置

```nginx
upstream backend {
    server 10.0.0.1:8080;
    server 10.0.0.2:8080;
    server 10.0.0.3:8080;
}

server {
    listen 80;
    location / {
        proxy_pass http://backend;
    }
}
```

## 服务器参数

```nginx
upstream backend {
    server 10.0.0.1:8080 weight=3;          # 权重，3 倍流量
    server 10.0.0.2:8080 max_fails=3 fail_timeout=30s; # 连续 3 次失败后暂停 30s
    server 10.0.0.3:8080 backup;            # 备用，其他全挂了才用
    server 10.0.0.4:8080 down;              # 手动下线
}
```

| 参数 | 说明 |
|------|------|
| `weight` | 权重，默认 1。越高分配越多请求 |
| `max_fails` | 连续失败几次后判为不可用，默认 1 |
| `fail_timeout` | 不可用后暂停多少秒再重试，默认 10s |
| `backup` | 备用服务器，其他都挂了才用 |
| `down` | 标记下线，不参与负载，配合 nginx -s reload 做灰度 |

## 负载均衡算法

```nginx
upstream backend {
    # 默认：轮询（Round Robin）
    server 10.0.0.1:8080;
    server 10.0.0.2:8080;

    # least_conn：最少连接，适合长连接场景
    # least_conn;

    # ip_hash：同一 IP 始终打到同一台服务器，解决 Session
    # ip_hash;

    # hash $request_uri：根据请求 URI 哈希，缓存友好
    # hash $request_uri consistent;
}
```

| 算法 | 适用场景 |
|------|---------|
| 轮询（默认） | 大部分场景，各后端性能相近 |
| weight | 后端配置不同（高配多分流量） |
| least_conn | 长连接、请求处理时间不均衡 |
| ip_hash | 需要 Session 保持，简单场景 |
| hash | 缓存穿透防护、URL 与后端绑定 |

## 健康检查

### 被动检查（Nginx 免费版自带）

```nginx
upstream backend {
    server 10.0.0.1:8080 max_fails=3 fail_timeout=30s;
    server 10.0.0.2:8080 max_fails=3 fail_timeout=30s;
}
```

连续 3 次失败 → 标记不可用 → 30s 后重新尝试。

### 主动检查（Nginx Plus 付费功能）

```
# 只有 Nginx Plus 支持
upstream backend {
    zone backend 64k;
    server 10.0.0.1:8080;
    check interval=3000 rise=2 fall=5 timeout=1000;
}
```

开源版需要第三方模块（如 nginx_upstream_check_module）。

## upstream 的常用模式

### 简单反向代理（单后端）

```nginx
upstream myapp {
    server 127.0.0.1:8080;
}
```

等价于 `proxy_pass http://127.0.0.1:8080;`，但用 upstream 保留了日后扩容的弹性。

### 按模块拆分

```nginx
upstream product_server { server 10.0.0.1:8081; }
upstream admin_server   { server 10.0.0.2:8082; }
upstream finance_server { server 10.0.0.3:8083; }

server {
    location /product/  { proxy_pass http://product_server; }
    location /admin/    { proxy_pass http://admin_server; }
    location /finance/  { proxy_pass http://finance_server; }
}
```

### 本地开发

```nginx
upstream backend {
    server host.docker.internal:8080;  # Docker 内访问宿主机的地址
}
```

## 参考

[[Nginx 基础]]
[[nginx.conf server 块配置]]
[[Nginx 生产踩坑与必配项]]
