# Docker Compose

## 什么是 Docker Compose

Docker Compose 是一个用于定义和运行多容器 Docker 应用的工具。通过 YAML 文件配置应用的服务、网络和卷，然后通过单条命令创建和启动所有服务。

## 安装

```bash
# Windows/Mac Docker Desktop 自带 Compose

# Linux 安装 Compose 插件
sudo apt install docker-compose-plugin

# 验证
docker compose version
```

## Compose 文件结构

### docker-compose.yml 基本结构

```yaml
version: "3.8"  # 版本号

services:       # 服务定义
  web:
    image: nginx:alpine
    ports:
      - "8080:80"
    volumes:
      - ./html:/usr/share/nginx/html
    networks:
      - frontend

  app:
    build: .
    environment:
      - DB_HOST=db
    depends_on:
      - db
    networks:
      - frontend
      - backend

  db:
    image: mysql:8.0
    volumes:
      - db_data:/var/lib/mysql
    environment:
      MYSQL_ROOT_PASSWORD: root
    networks:
      - backend

volumes:        # 卷定义
  db_data:

networks:       # 网络定义
  frontend:
  backend:
```

### 版本说明

| 版本 | Docker Engine | 主要特性 |
|------|---------------|----------|
| 3.8+ | 19.03.0+ | 最新特性 |
| 3.x | 18.06.0+ | Swarm 支持 |
| 2.x | 17.06.0+ | 推荐单机使用 |

> 最新版 Compose 已废弃 `version` 字段，YAML 根级定义即可。

## 核心配置项

### 服务配置

```yaml
services:
  web:
    # 使用已有的镜像
    image: nginx:alpine

    # 使用 Dockerfile 构建
    build:
      context: .
      dockerfile: Dockerfile.prod
      args:
        VERSION: 1.0

    # 容器名称
    container_name: my-web

    # 端口映射
    ports:
      - "8080:80"           # HOST:CONTAINER
      - "443:443"

    # 环境变量
    environment:
      - NODE_ENV=production
      - DB_HOST=db
    env_file:
      - ./config/app.env

    # 卷挂载
    volumes:
      - ./html:/usr/share/nginx/html:ro
      - web-data:/data

    # 依赖关系
    depends_on:
      - db
      - redis

    # 网络
    networks:
      - frontend

    # 重启策略
    restart: unless-stopped

    # 资源限制
    # 注意: deploy.resources 仅在 docker stack deploy（Swarm 模式）下生效
    # docker compose up 会忽略此配置，请使用 docker run --cpus/--memory 在单机模式限制资源
    deploy:
      resources:
        limits:
          cpus: "0.5"
          memory: "512M"
        reservations:
          cpus: "0.25"
          memory: "256M"

    # 健康检查
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:80"]
      interval: 30s
      timeout: 10s
      retries: 3
```

### 网络配置

```yaml
networks:
  frontend:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
  backend:
    driver: bridge
    internal: true    # 禁止外部访问
```

### 卷配置

```yaml
volumes:
  db_data:
    driver: local
  logs:
    driver: local
    driver_opts:
      type: none
      device: /opt/logs
      o: bind
```

## 常用命令

```bash
# 启动所有服务（前台）
docker compose up

# 后台启动
docker compose up -d

# 构建并启动
docker compose up -d --build

# 停止所有服务
docker compose down

# 停止并删除卷
docker compose down -v

# 查看运行中的服务
docker compose ps

# 查看日志
docker compose logs
docker compose logs -f web     # 跟踪特定服务

# 执行命令
docker compose exec web bash

# 重启服务
docker compose restart web

# 查看服务状态
docker compose top

# 拉取所有镜像
docker compose pull

# 构建所有镜像
docker compose build

# 查看配置
docker compose config
```

## 完整示例

### Web 应用 + 数据库 + 缓存

```yaml
services:
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
    depends_on:
      - app
    networks:
      - frontend

  app:
    build: ./app
    environment:
      - DB_HOST=db
      - REDIS_HOST=redis
    depends_on:
      - db
      - redis
    networks:
      - frontend
      - backend

  db:
    image: postgres:15
    volumes:
      - postgres_data:/var/lib/postgresql/data
    environment:
      POSTGRES_DB: myapp
      POSTGRES_USER: user
      POSTGRES_PASSWORD: password
    networks:
      - backend

  redis:
    image: redis:alpine
    volumes:
      - redis_data:/data
    networks:
      - backend

networks:
  frontend:
  backend:

volumes:
  postgres_data:
  redis_data:
```

## 环境变量与变量替换

```yaml
# .env 文件中的变量自动可用
services:
  db:
    image: postgres:${POSTGRES_VERSION:-15}
    environment:
      - POSTGRES_DB=${DB_NAME}
```

**变量替换语法**：
- `${VARIABLE}` - 直接替换
- `${VARIABLE:-default}` - 设置默认值
- `${VARIABLE:?error}` - 必须设置，否则报错

## Profiles（配置文件）

```yaml
services:
  app:
    image: myapp

  db:
    image: postgres

  redis:
    image: redis
    profiles: ["dev"]      # 仅开发环境启动

  admin:
    image: adminer
    profiles: ["dev", "staging"]
```

```bash
# 启动默认服务
docker compose up -d

# 启动包含 dev profile 的服务
docker compose --profile dev up -d
```

## Compose Watch（文件监控）

```yaml
services:
  app:
    build: .
    develop:
      watch:
        - action: sync
          path: ./src
          target: /app/src
        - action: rebuild
          path: package.json
```

```bash
docker compose watch
```

## 官方文档

- Compose 参考：https://docs.docker.com/compose/compose-file/
- Compose 命令：https://docs.docker.com/compose/reference/
- Compose 快速入门：https://docs.docker.com/compose/gettingstarted/
