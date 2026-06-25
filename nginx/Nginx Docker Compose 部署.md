# Nginx Docker Compose 部署

## 概述

Nginx 在容器化部署中充当统一入口，前端静态文件也由 Nginx 提供服务，后端 API 通过反代转发。

## 架构

```
用户 → 宿主机 80
        ↓
Nginx 容器
  ├ / → 挂载的前端静态文件（或反代到前端容器）
  └ /api → 反代到后端容器（服务名:端口）
```

Docker Compose 创建的内部网络中，容器之间用**服务名**通信，不走 `localhost`。

## 2 容器方案（推荐）

```yaml
services:
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/conf.d/default.conf
      - ./dist:/usr/share/nginx/html   # 前端构建产物
    depends_on:
      - backend
    networks:
      - app_net

  backend:
    image: my-backend:latest
    # 不暴露端口到宿主机
    networks:
      - app_net

networks:
  app_net:
    driver: bridge
```

```nginx
# nginx.conf
upstream backend {
    server backend:8080;    # Docker 服务名
}

server {
    listen 80;

    location / {
        root /usr/share/nginx/html;
        index index.html;
        try_files $uri $uri/ /index.html;
    }

    location /api/ {
        proxy_pass http://backend/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

## 3 容器方案（前端单独容器）

```yaml
services:
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/conf.d/default.conf
    depends_on:
      - frontend
      - backend
    networks:
      - app_net

  frontend:
    image: nginx:alpine
    volumes:
      - ./dist:/usr/share/nginx/html
    networks:
      - app_net

  backend:
    image: my-backend:latest
    networks:
      - app_net

networks:
  app_net:
    driver: bridge
```

```nginx
upstream frontend {
    server frontend:80;
}

upstream backend {
    server backend:8080;
}

server {
    listen 80;

    location / {
        proxy_pass http://frontend/;
    }

    location /api/ {
        proxy_pass http://backend/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

## 注意事项

### 容器间通信用服务名，不用 localhost

```nginx
proxy_pass http://backend:8080;    # 正确
proxy_pass http://localhost:8080;  # 错误，容器内 localhost 是自己
```

### Nginx 容器要 depends_on

```yaml
depends_on:
  - backend
```

确保后端先启动（但不保证后端已经就绪，只是容器创建顺序）。

### 后端不需要暴露 ports

Docker Compose 网络内容器之间通过服务名 + 端口即可访问，不需要将后端端口映射到宿主机。这样后端对外完全不可见，只有 Nginx 能访问。

## 参考

[[Nginx 基础]]
[[Nginx 跨域场景分析]]
