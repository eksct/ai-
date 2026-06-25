# nginx 全功能配置

## 概述

生产可用的完整 nginx.conf 模板，涵盖反代、静态服务、HTTPS、限流、日志等，按需裁剪即可迁移使用。

## 配置

```nginx
# ==================== 全局块（main context） ====================
worker_processes  auto;               # worker 数量，auto = CPU 核心数
worker_rlimit_nofile  65535;          # worker 最大文件句柄数，防 too many open files

error_log  /var/log/nginx/error.log warn;   # 错误日志，生产用 warn 或 error
pid        /var/run/nginx.pid;              # PID 文件，供 logrotate 等工具发信号

# ==================== 事件块（events context） ====================
events {
    worker_connections  1024;   # 每个 worker 最大连接数，4 核 = 4096 并发
    multi_accept        on;    # 一次 accept 多个连接，提升吞吐
    use                 epoll; # Linux 事件模型，默认自动选，显式写更清晰
}

# ==================== HTTP 块（http context） ====================
http {
    include       mime.types;            # 文件后缀 → Content-Type 映射，必须配
    default_type  application/octet-stream; # 未识别的后缀默认当成二进制流下载
    charset       utf-8;                 # 响应字符集
    server_tokens off;                   # 隐藏 Nginx 版本号，安全加固

    # ---------- 传输优化 ----------
    sendfile        on;    # 零拷贝发文件，静态服务必开
    tcp_nopush      on;    # 合并数据包再发，减少网络小包，配合 sendfile 使用
    tcp_nodelay     on;    # 不延迟发小包，实时性优先（API 接口需要）

    # ---------- 连接 ----------
    keepalive_timeout    65;       # HTTP 长连接超时，65 秒无请求断开
    keepalive_requests   1000;     # 一个长连接最多处理 1000 次请求后断开
    client_max_body_size 10m;      # 允许上传的最大请求体，超了返回 413，按业务调

    # ---------- 日志 ----------
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';
    access_log /var/log/nginx/access.log main buffer=32k flush=5s;
    # buffer=32k：攒够 32KB 才写磁盘，减少 IO；flush=5s：最多等 5 秒写一次

    # ---------- 限流 ----------
    limit_req_zone $binary_remote_addr zone=api_limit:10m rate=20r/s;
    # 按 IP 限速，每 IP 每秒最多 20 个请求，超出排队，10m = 约 16 万个 IP
    limit_conn_zone $binary_remote_addr zone=addr:10m;
    # 按 IP 限制并发连接数

    # ---------- 反向代理：连接上游超时 ----------
    proxy_connect_timeout   10;   # 连后端服务器最大等待 10 秒
    proxy_send_timeout      10;   # 向后端发数据最大等待 10 秒
    proxy_read_timeout      10;   # 等后端返回数据最大等待 10 秒（接口慢要调大）

    # ---------- 反向代理：缓冲区 ----------
    proxy_buffer_size       4k;   # 存响应头的缓冲区大小，不够报 502，cookie 大时调大
    proxy_buffers           8 4k; # 8 个 4K 缓冲存响应体，总共 32K
    proxy_busy_buffers_size 8k;   # 发给客户端前的最大缓冲，一般设 proxy_buffers 的 2 倍

    # ---------- 反向代理：透传请求头 ----------
    proxy_set_header        Host $host;              # 传原始域名给后端
    proxy_set_header        X-Real-IP $remote_addr;  # 传真实用户 IP 给后端
    proxy_set_header        X-Forwarded-For $proxy_add_x_forwarded_for;  # 传完整转发链
    proxy_set_header        X-Forwarded-Proto $scheme;  # 传原始协议（http/https）

    # ==================== 服务器块（server context） ====================

    # ----- 示例 1：SPA 静态服务 -----
    server {
        listen 80;
        server_name app.example.com;

        location / {
            root /data/app;                        # 前端构建产物目录
            index index.html;                      # 默认首页
            try_files $uri $uri/ /index.html;      # SPA History 模式兜底
        }

        location ~* \.(css|js|jpg|jpeg|png|gif|ico|svg|woff2|ttf)$ {
            root /data/app;
            expires 30d;                            # 静态文件缓存 30 天
            add_header Cache-Control "public, immutable";  # 浏览器强缓存，不改文件不过期
            access_log off;                         # 静态文件不记日志，省磁盘
        }
    }

    # ----- 示例 2：API 反向代理 + 限流 -----
    server {
        listen 80;
        server_name api.example.com;

        location /api/ {
            limit_req zone=api_limit burst=10 nodelay;  # 限流 20r/s，突发允许 10 个

            proxy_pass http://backend/;                  # 反代到后端
        }

        location / {
            return 403;   # 非 /api/ 的请求全部拒绝
        }
    }

    # ----- 示例 3：HTTPS 反代（生产推荐） -----
    server {
        listen 443 ssl http2;           # 443 端口，开启 SSL + HTTP/2
        server_name www.example.com;

        ssl_certificate     /etc/nginx/ssl/example.com.pem;  # 证书公钥
        ssl_certificate_key /etc/nginx/ssl/example.com.key;  # 证书私钥（绝对保密）

        ssl_protocols       TLSv1.2 TLSv1.3;                # 只允许安全的 TLS 版本
        ssl_ciphers         ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256;
        ssl_prefer_server_ciphers on;                       # 优先使用服务端加密算法
        ssl_session_cache   shared:SSL:10m;                 # SSL 会话缓存，加速握手
        ssl_session_timeout 10m;                            # 缓存 10 分钟

        location / {
            root /data/www;
            index index.html;
        }

        location /api/ {
            proxy_pass http://backend/;
        }
    }

    # HTTP → HTTPS 重定向（配合上面的 HTTPS 用）
    server {
        listen 80;
        server_name www.example.com;
        return 301 https://$host$request_uri;   # 301 永久重定向到 HTTPS
    }

    # ----- 示例 4：上游服务器组（upstream context） -----
    upstream backend {
        server 10.0.0.1:8080 weight=3;   # weight=3 表示分配 3 倍流量
        server 10.0.0.2:8080;            # 默认 weight=1
        server 10.0.0.3:8080 backup;     # 前两台挂了才启用
    }

    # ----- 示例 5：文件服务器（内网文件分发） -----
    server {
        listen 80;
        server_name files.example.com;
        root /data/files;
        autoindex on;               # 开目录列表，访问 / 能看到文件列表
        autoindex_exact_size off;   # 显示可读大小（10MB 而不是 10485760）
        autoindex_localtime on;     # 显示本地时间

        location / {
            limit_rate 5m;          # 每连接限速 5MB/s
            limit_conn addr 1;      # 每 IP 只能同时下载一个文件
        }
    }
}
```

## 使用说明

1. **端口**：HTTP 80，HTTPS 443，按实际修改
2. **server_name**：替换成你自己的域名或留 `_` 用 IP
3. **限流参数**：`rate=20r/s` 按业务承载调整
4. **client_max_body_size**：上传场景按需调大
5. **日志路径**：Linux 下 `/var/log/nginx/`，Windows 下改为 `logs/`

## 参考

[[Nginx 基础]]
[[Nginx 生产踩坑与必配项]]
[[nginx.conf server 块配置]]
[[nginx.conf upstream 块配置]]
