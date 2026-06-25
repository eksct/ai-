# nginx.conf server 块配置

## 概述

`server {}` 定义一个虚拟主机（VirtualHost），是 Nginx 处理 HTTP 请求的核心单位。Nginx 收到请求后根据 `listen` + `server_name` 决定由哪个 server 处理。

## 基础结构

```nginx
server {
    listen      80;
    server_name example.com;

    root        /var/www/html;
    index       index.html index.htm;

    location / {
        try_files $uri $uri/ =404;
    }

    error_page  404 /404.html;
    error_page  500 502 503 504 /50x.html;
}
```

## listen

`listen` 决定 server 块监听哪个 IP 和端口。

```nginx
listen 80;                      # IPv4，所有网卡
listen 8080;
listen 443 ssl;                 # HTTPS
listen [::]:80;                 # IPv6
listen 192.168.1.10:80;         # 只监听特定 IP
listen 80 default_server;       # 默认服务器（兜底）
```

**同一个端口可以有多个 server 块，靠 server_name 区分。**

## server_name

匹配 HTTP 请求头里的 `Host` 字段，决定请求进入哪个 server。

```nginx
server_name example.com;          # 精确匹配
server_name *.example.com;        # 泛域名，匹配 a.example.com
server_name ~^www\d+\.com$;       # 正则匹配
server_name _;                    # 兜底，不写 server_name 时默认行为
```

## root

响应静态文件时的根目录。

```nginx
root /var/www/html;
# 请求 /css/style.css → 文件路径 /var/www/html/css/style.css
```

与 `alias` 的区别：

```nginx
location /api/ {
    root /data;           # /api/users → /data/api/users
}

location /api/ {
    alias /data/;         # /api/users → /data/users（/api/ 被替换）
}
```

## index

访问目录时默认返回的文件。Nginx 按顺序查找，找到第一个就返回。

```nginx
index index.html index.htm index.php;
```

## error_page

自定义错误页面。

```nginx
error_page 404 /404.html;
error_page 500 502 503 504 /50x.html;

# 根据状态码跳转不同页面
error_page 403 http://example.com/forbidden.html;
```

## location 匹配规则

### 语法

```nginx
location [ = | ~ | ~* | ^~ ] pattern { ... }
```

### 修饰符

| 修饰符 | 含义 | 示例 |
|--------|------|------|
| 无 | 普通前缀匹配 | `/api/` 匹配 `/api/users` |
| `=` | 精确匹配 | `= /login` 只匹配 `/login` |
| `~` | 正则匹配（大小写敏感） | `~ \.php$` |
| `~*` | 正则匹配（不敏感） | `~* \.(jpg\|png)$` |
| `^~` | 前缀匹配，命中后不再查正则 | `^~ /static/` |

### 匹配顺序

```
= 精确匹配（最高）
  ↓ 命中即停
^~ 前缀匹配（命中即停，不查正则）
  ↓
~ / ~* 正则匹配（按顺序，命中即停）
  ↓
普通前缀匹配（最长匹配优先）
  ↓
/ 兜底
```

### 常见场景

```nginx
# 精确匹配 — 登录页
location = /login { ... }

# 静态资源 — 不需要正则，直接前缀匹配
location /static/ { ... }

# PHP 动态请求 — 正则匹配
location ~ \.php$ { ... }

# API 反向代理
location /api/ {
    proxy_pass http://backend/;
}

# 兜底 — 单页应用
location / {
    try_files $uri $uri/ /index.html;
}
```

## 多个 server 块共存

```nginx
http {
    server {
        listen 80;
        server_name a.com;
        root /var/www/a;
    }

    server {
        listen 80;
        server_name b.com;
        root /var/www/b;
    }

    server {
        listen 80 default_server;
        server_name _;
        root /var/www/default;
    }

    server {
        listen 443 ssl;
        server_name a.com;
        ssl_certificate ...;
        ssl_certificate_key ...;
        root /var/www/a;
    }
}
```

## 参考

[[Nginx 基础]]
[[nginx.conf 全局块配置]]
[[Nginx 生产踩坑与必配项]]
