# Nginx 生产踩坑与必配项

## client_max_body_size — 上传文件超过 1MB 就 413

Nginx 默认限制请求体 **1MB**。上传文件超出直接返回 413 Request Entity Too Large。

```nginx
http {
    client_max_body_size 100m;   # 全局，http 块
}

server {
    client_max_body_size 0;      # server 块覆盖，0 表示不限
}
```

建议在 http 块设一个合理值（如 10m），特殊接口在 server 或 location 覆盖。

## proxy_buffer — 502 的元凶

后端返回响应慢或响应头太大时，默认 buffer 不够会报 502。

```nginx
location /api/ {
    proxy_buffer_size       4k;     # 响应头缓冲
    proxy_buffers           8 4k;   # 8 个 4k 缓冲
    proxy_busy_buffers_size 8k;     # 发给客户端前的最大缓冲

    proxy_buffering off;            # 关掉缓冲，流式返回
}
```

调大一般能解决。如果不想等后端全部响应完再转发给客户端（比如 SSE 或大文件），关 `proxy_buffering`。

## try_files — 单页应用刷新 404

前后端分离部署，刷新某个路由页面（如 `/user/123`）时 Nginx 找不到文件直接 404。

```nginx
location / {
    root /data/frontend;
    index index.html;
    try_files $uri $uri/ /index.html;
}
```

`try_files` 做了三件事：
1. `$uri` — 先找这个路径有没有文件（`/user/123`）
2. `$uri/` — 再尝试找目录
3. `/index.html` — 都没有就返回 index.html，让前端路由接管

## access_log 不轮转 — 日志撑爆磁盘

Nginx 不切日志，1 天几十 GB 访问日志能写满磁盘，然后 Nginx 挂掉。

### 方法 1：logrotate（推荐）

```nginx
# /etc/logrotate.d/nginx
/var/log/nginx/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    sharedscripts
    postrotate
        [ -f /var/run/nginx.pid ] && kill -USR1 `cat /var/run/nginx.pid`
    endscript
}
```

改了 nginx.conf 后记得 `logrotate -f /etc/logrotate.d/nginx` 验证。

### 方法 2：根据日期动态写

```nginx
if ($time_iso8601 ~ "^(\d{4}-\d{2}-\d{2})") {
    set $log_date $1;
}
access_log /var/log/nginx/access-$log_date.log main;
```

## 安全加固

```nginx
# 隐藏版本
server_tokens off;

# 限制请求体大小
client_max_body_size 10m;

# 限制请求速率
limit_req_zone $binary_remote_addr zone=login:10m rate=5r/s;
location /login {
    limit_req zone=login burst=10 nodelay;
}

# 连接数限制
limit_conn_zone $binary_remote_addr zone=addr:10m;
location /download/ {
    limit_conn addr 1;        # 每 IP 一个连接
    limit_rate 5m;            # 限速 5MB/s
}

# 屏蔽非标准方法
if ($request_method !~ ^(GET|POST|HEAD)$) {
    return 405;
}

# 防 ClickJacking
add_header X-Frame-Options SAMEORIGIN;

# 防 XSS
add_header X-Content-Type-Options nosniff;
add_header X-XSS-Protection "1; mode=block";
```

## location 匹配优先级

```
= /login          → 1. 精确匹配（最高）
^~ /api/          → 2. 前缀匹配，不检查正则
~ \.php$          → 3. 正则匹配（大小写敏感）
~* \.(jpg|png)$   → 4. 正则匹配（大小写不敏感）
/api/             → 5. 普通前缀匹配（最长优先）
/                 → 6. 兜底
```

几个例子：

```nginx
location = /login { ... }          # 只匹配 /login

location ^~ /static/ { ... }       # 匹配 /static/xxx，不管后面有没有正则

location ~ \.php$ { ... }          # 匹配 .php 结尾，走 FastCGI

location /api/ { ... }             # 匹配所有 /api/ 开头

location / { ... }                 # 兜底
```

所有配置里最容易被坑的是 `location /` 和 `location /api/` 同时存在——`/api/` 的优先级比 `/` 高，所以 `/api/users` 不会误入兜底。

## map — 条件转发

根据请求特征转发到不同的后端，不用写 if。

```nginx
# 根据 User-Agent 判断移动端
map $http_user_agent $mobile_backend {
    default        web_backend;
    ~*mobile       mobile_backend;
    ~*android      mobile_backend;
    ~*iphone       mobile_backend;
}

upstream web_backend {
    server 10.0.0.1:8080;
}

upstream mobile_backend {
    server 10.0.0.2:8080;
}

server {
    listen 80;
    location / {
        proxy_pass http://$mobile_backend;
    }
}
```

也常用在根据 cookie、query 参数、请求头分发。

## certbot — 免费 HTTPS 一把梭

```bash
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d example.com -d www.example.com

# 测试自动续期
sudo certbot renew --dry-run
```

certbot 自动配完 SSL 并改写 nginx.conf，到期前自动续签。

## 调参模板（4 核 8G 起步）

```nginx
worker_processes auto;
worker_rlimit_nofile 65535;

events {
    worker_connections 16384;
    multi_accept on;
    use epoll;
}

http {
    include       mime.types;
    default_type  application/octet-stream;
    charset       utf-8;
    server_tokens off;

    sendfile       on;
    tcp_nopush     on;
    tcp_nodelay    on;

    client_max_body_size 10m;
    client_body_buffer_size 128k;
    client_body_timeout 10;

    keepalive_timeout 65;
    keepalive_requests 1000;

    proxy_connect_timeout 10;
    proxy_send_timeout    10;
    proxy_read_timeout    10;

    proxy_buffer_size    4k;
    proxy_buffers        8 4k;
    proxy_busy_buffers_size 8k;

    limit_req_zone $binary_remote_addr zone=api:10m rate=50r/s;

    access_log /var/log/nginx/access.log main buffer=32k flush=5s;
    error_log  /var/log/nginx/error.log warn;

    include /etc/nginx/conf.d/*.conf;
}
```

## 总结

生产要让 Nginx 稳定跑住，重点不在那些花哨功能，在这几件事：**请求体限制、buffer 调大、单页应用 try_files、日志轮转、安全加固**。这些都是上线前配好，上线后不会碰，但没配一定会出事的项。

## 参考

[[Nginx 基础]]
[[nginx.conf 全局块配置]]
[[nginx.conf events 块配置]]
