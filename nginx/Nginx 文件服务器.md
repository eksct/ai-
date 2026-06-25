# Nginx 文件服务器

## 概述

Nginx 可以不依赖后端应用，直接暴露本地目录供 HTTP 下载。

## 基础配置

```nginx
server {
    listen 80;
    server_name files.example.com;
    root /data/files;
    autoindex on;               # 开启目录列表
    autoindex_exact_size off;   # 显示可读大小（KB/MB/GB）
    autoindex_localtime on;     # 显示本地时间
}
```

## 图片/静态资源服务器

```nginx
server {
    listen 80;
    server_name static.example.com;
    root /data/static;

    location / {
        try_files $uri =404;
    }

    location ~* \.(jpg|jpeg|png|gif|ico|webp)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    location ~* \.(css|js)$ {
        expires 7d;
        add_header Cache-Control "public, immutable";
    }
}
```

## 大文件下载场景

```nginx
server {
    listen 80;
    server_name download.example.com;
    root /data/downloads;

    location / {
        # 限速，防单请求拖垮带宽
        limit_rate 5m;
        limit_rate_after 50m;    # 前 50MB 不限速

        # 连接数限制，防盗刷
        limit_conn per_ip 1;

        # 防盗链
        valid_referers none blocked ~\.example\.com;
        if ($invalid_referer) {
            return 403;
        }
    }
}
```

## 使用建议

| 场景 | Nginx 是否够用 |
|------|---------------|
| 内网软件包/ISO 分发 | 够用，autoindex 就很好用 |
| 日志归档下载 | 够用 |
| 静态资源 CDN 源站 | 够用，加 expires 缓存 |
| 企业级文件管理（权限、预览、搜索、多人协作） | 不够，换 MinIO / Nextcloud / SeaFile |

## 参考

[[Nginx 基础]]
[[Nginx 生产踩坑与必配项]]
