# reverse-proxy.conf — 生产内网反向代理模板

## 说明

独立文件，放到 `/etc/nginx/conf.d/` 即可生效，不需要改 `nginx.conf`。适用于 Linux + HTTP + IP 直连 + 上游 HTTPS 自签证书。

## 配置内容

```nginx
# ==================== 限流定义（必须放 http 块，这里用文件头占位） ====================
# 如果主 nginx.conf 里没有这行，会报错。所以这个文件包含 http 块
# 但是直接作为独立文件放到 conf.d 会导致 http 嵌套。正确做法：

# 方式一（推荐）：只写 server/upstream，在主 nginx.conf 的 http 块末尾加：
#   limit_req_zone $binary_remote_addr zone=api_limit:10m rate=20r/s;
#   include /etc/nginx/conf.d/*.conf;

# 方式二：本文件作为主配置替换 nginx.conf
```

---

## 正确使用方式

### 方式一：独立 server 文件（推荐，不碰主配置）

**步骤 1**：在 `nginx.conf` 的 `http` 块里加两行（**只做一次**）：

```nginx
http {
    # ... 已有配置 ...

    # 加这两行
    limit_req_zone $binary_remote_addr zone=api_limit:10m rate=20r/s;
    include /etc/nginx/conf.d/*.conf;
}
```

**步骤 2**：新建 `/etc/nginx/conf.d/reverse-proxy.conf`：

```nginx
upstream backend {
    server 192.168.110.242:50000;
    # server 192.168.110.243:50000;      # 多后端取消注释
    # server 192.168.110.244:50000 backup;
}

server {
    listen 80 default_server;
    server_name _;

    client_max_body_size 10m;

    location / {
        proxy_pass http://backend;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # 上游 HTTPS 自签证书时跳过校验
        proxy_ssl_verify off;

        # 调优
        proxy_read_timeout 60;
        proxy_buffers 8 4k;

        # 限流（依赖 http 块定义的 api_limit）
        limit_req zone=api_limit burst=10 nodelay;
    }
}
```

**步骤 3**：`nginx -t && nginx -s reload`

### 方式二：完整替换 nginx.conf（新人装机一次搞定）

```nginx
# ==================== 全局 ====================
worker_processes  auto;
worker_rlimit_nofile  65535;
error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;

# ==================== 事件 ====================
events {
    worker_connections  1024;
    multi_accept        on;
    use                 epoll;
}

# ==================== HTTP ====================
http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    charset       utf-8;
    server_tokens off;

    sendfile        on;
    tcp_nopush      on;
    tcp_nodelay     on;

    keepalive_timeout    65;
    keepalive_requests   1000;
    client_max_body_size 10m;

    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';
    access_log /var/log/nginx/access.log main buffer=32k flush=5s;

    # 限流
    limit_req_zone $binary_remote_addr zone=api_limit:10m rate=20r/s;

    # 反向代理默认头
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_ssl_verify off;

    # 反向代理默认调优
    proxy_connect_timeout   10;
    proxy_send_timeout      10;
    proxy_read_timeout      60;
    proxy_buffer_size       4k;
    proxy_buffers           8 4k;
    proxy_busy_buffers_size 8k;

    # ==================== 上游 ====================
    upstream backend {
        server 192.168.110.242:50000;
        # server 192.168.110.243:50000;
    }

    # ==================== 服务器 ====================
    server {
        listen 80 default_server;
        server_name _;

        limit_req zone=api_limit burst=10 nodelay;

        location / {
            proxy_pass http://backend;
        }
    }
}
```

## 参数速查

| 参数 | 你当前的值 | 调大时机 |
|------|-----------|---------|
| `client_max_body_size` | 10m | 上传文件超过 10MB |
| `proxy_read_timeout` | 60s | 后端接口响应超过 60s |
| `limit_req rate` | 20r/s | 压测正常后逐步调大 |
| `worker_connections` | 1024 | 并发超过 1024 × CPU 核数 |
| `proxy_buffers` | 8 4k | 接口返回大 JSON 时 502 |

## 参考

[[nginx.conf 全局块配置]]
[[nginx.conf server 块配置]]
[[nginx.conf upstream 块配置]]
[[Nginx 生产踩坑与必配项]]
