# Nginx 基础

## 概述

Nginx 是一个高性能的 HTTP 和反向代理服务器，核心优势：事件驱动模型（非多线程）、占用资源少、处理静态文件效率极高、配置简单灵活。常用于反向代理、负载均衡、静态资源服务。

## 安装

```bash
# Ubuntu / Debian
sudo apt update && sudo apt install nginx -y

# CentOS / RHEL
sudo yum install epel-release -y
sudo yum install nginx -y

# Windows（仅开发测试，不推荐生产）
# 下载 http://nginx.org/en/download.html → 解压 → 直接运行
```

验证：`nginx -v` 看版本；`curl -I http://localhost` 看响应头。

## 基础命令

```bash
nginx            # 启动
nginx -s stop    # 强制停止
nginx -s quit    # 优雅退出（处理完当前请求）
nginx -s reload  # 重载配置（不中断服务，推荐用这个）
nginx -t         # 测试配置文件语法
nginx -T         # 测试并打印完整配置（调试神器）
```

## nginx.conf 结构

```nginx
# 全局块 — 全局配置
user  nginx;
worker_processes  auto;      # 一般设为 CPU 核心数
error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;

# events 块 — 连接配置
events {
    worker_connections  1024;  # 每个 worker 最大连接数
    multi_accept on;           # 一次 accept 多个连接
}

# http 块 — HTTP 配置主体
http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    sendfile      on;
    keepalive_timeout  65;

    # server 块 — 虚拟主机
    server {
        listen       80;
        server_name  example.com;

        # location 块 — URL 匹配规则
        location / {
            root   /usr/share/nginx/html;
            index  index.html;
        }
    }
}
```

> **最佳实践**：不把所有配置塞进 nginx.conf，用 `include` 拆分。`/etc/nginx/conf.d/*.conf` 放 server 块，`/etc/nginx/sites-enabled/` 也行。

## 核心配置实操

### 静态资源服务

```nginx
server {
    listen 80;
    server_name static.example.com;
    root /data/www;

    location / {
        try_files $uri $uri/ /404.html;
    }

    # 静态文件缓存
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|woff2)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
}
```

### 反向代理

```nginx
server {
    listen 80;
    server_name api.example.com;

    location / {
        proxy_pass http://127.0.0.1:8080/;    # 注意：带尾部斜杠！
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### 负载均衡

```nginx
upstream backend {
    # 默认轮询
    server 10.0.0.1:8080 weight=3;  # weight 越大，分配越多
    server 10.0.0.2:8080;
    server 10.0.0.3:8080 backup;    # 其他都挂了才用这个

    # 其他算法（去掉注释启用）：
    # least_conn;    # 最少连接
    # ip_hash;       # IP 哈希，解决 Session 问题
}

server {
    listen 80;
    server_name app.example.com;

    location / {
        proxy_pass http://backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### HTTPS 配置

```nginx
server {
    listen 443 ssl http2;
    server_name example.com;

    ssl_certificate     /etc/nginx/ssl/example.com.crt;
    ssl_certificate_key /etc/nginx/ssl/example.com.key;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256;
    ssl_prefer_server_ciphers on;

    location / {
        proxy_pass http://backend;
    }
}

# HTTP → HTTPS 重定向
server {
    listen 80;
    server_name example.com;
    return 301 https://$host$request_uri;
}
```

## 常用场景模板

### 前后端分离部署

```nginx
# 前端静态文件 + API 反向代理到后端
server {
    listen 80;
    server_name www.example.com;

    # 前端
    location / {
        root /data/frontend/dist;
        index index.html;
        try_files $uri $uri/ /index.html;  # SPA History 模式
    }

    # 后端 API
    location /api/ {
        proxy_pass http://127.0.0.1:3000/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### 单页应用 History 模式

```nginx
location / {
    root /data/app;
    index index.html;
    try_files $uri $uri/ /index.html;
}
```

核心是 `try_files $uri $uri/ /index.html`——匹配不到文件或目录就返回 index.html，让前端路由接管。

## 踩坑 & 生产建议

### 1. proxy_pass 斜杠陷阱

```nginx
# 不带斜杠 — 路径原样传递
proxy_pass http://backend;         # /api/user → /api/user

# 带斜杠 — 匹配部分被替换
proxy_pass http://backend/;        # /api/user → /user
```

很坑，记住：**带斜杠 = 替换 location 路径**。

### 2. buffer 不足导致 502

高并发或后端响应慢时，默认 buffer 不够会报 502：

```nginx
proxy_buffer_size       4k;
proxy_buffers           8 4k;
proxy_busy_buffers_size 8k;
```

### 3. 日志切割

生产环境日志不切会撑爆磁盘。用 `logrotate`：

```nginx
# /etc/logrotate.d/nginx
/var/log/nginx/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    sharedscripts
    postrotate
        [ -f /var/run/nginx.pid ] && kill -USR1 `cat /var/run/nginx.pid`
    endscript
}
```

### 4. 安全加固速查

```nginx
# 隐藏版本号
server_tokens off;

# 限制请求体和超时
client_max_body_size 10m;
client_body_timeout 10;

# 限制请求速率 — 防爆破
limit_req_zone $binary_remote_addr zone=login:10m rate=5r/s;
location /login {
    limit_req zone=login burst=10 nodelay;
}

# 禁止非 GET/POST 方法
if ($request_method !~ ^(GET|POST)$) {
    return 405;
}
```

### 5. worker 数量与连接数

- `worker_processes auto` — 等于 CPU 核心数
- `worker_connections 1024` — 每进程最大连接数
- 最大并发数 = `worker_processes * worker_connections`（反向代理模式下约减半）

## 总结

Nginx 核心就三块：**server（虚拟主机）+ location（路由规则）+ upstream（后端集群）**。配上反向代理、HTTPS、负载均衡，90% 的场景都够用了。配置完记得 `nginx -t` 检查再 `nginx -s reload`。

## 参考

[[Docker 基础]]（Nginx 容器化部署）
