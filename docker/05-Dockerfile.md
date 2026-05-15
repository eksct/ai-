# Dockerfile

## 什么是 Dockerfile

Dockerfile 是一个文本文件，包含了一系列指令，用于自动化构建 Docker 镜像。

## 基本结构

```dockerfile
# 基础镜像
FROM ubuntu:22.04

# 维护者信息（已弃用，推荐使用 LABEL）
LABEL maintainer="your-email@example.com"
LABEL version="1.0"
LABEL description="My application"

# 设置工作目录
WORKDIR /app

# 复制文件
COPY . .

# 运行命令
RUN apt-get update && apt-get install -y python3

# 暴露端口
EXPOSE 8080

# 设置环境变量
ENV APP_ENV=production

# 设置默认命令
CMD ["python3", "app.py"]
```

## 指令详解

### FROM
```dockerfile
FROM ubuntu:22.04
FROM node:18-alpine
FROM python:3.11-slim
FROM scratch              # 空镜像，用于构建极简镜像
```
- 必须是 Dockerfile 的第一条指令
- 可多次使用（多阶段构建）

### LABEL
```dockerfile
LABEL version="1.0"
LABEL maintainer="team@example.com"
LABEL com.example.vendor="ACME Inc"
```
- 添加元数据到镜像
- 可用 `docker inspect` 查看

### RUN
```dockerfile
# shell 形式
RUN apt-get update && apt-get install -y curl

# exec 形式
RUN ["/bin/bash", "-c", "apt-get update"]
```
- 在镜像构建时执行命令
- 每条 RUN 创建一层
- 建议用 `&&` 合并命令以减少层数

### CMD vs ENTRYPOINT

**CMD** - 提供默认执行命令，可被 `docker run` 参数覆盖：
```dockerfile
CMD ["python", "app.py"]
CMD python app.py           # shell 形式
CMD ["executable", "param"] # exec 形式（推荐）
```

**ENTRYPOINT** - 容器主命令，不易被覆盖：
```dockerfile
ENTRYPOINT ["python"]
CMD ["app.py"]              # 提供给 ENTRYPOINT 的默认参数
```
运行：`docker run my-image app2.py` 实际执行 `python app2.py`

组合使用 ENTRYPOINT + CMD 是常见模式。

### COPY vs ADD

**COPY** - 复制文件到镜像（推荐）：
```dockerfile
COPY package.json /app/
COPY . /app/
COPY --chown=node:node . /app/  # 指定所有者
```

**ADD** - 增强版 COPY，支持 URL 和自动解压：
```dockerfile
ADD app.tar.gz /app/        # 自动解压 tar
ADD https://example.com/file /app/  # 不推荐，应使用 curl/wget
```
- 建议：尽量使用 COPY，特殊需求才用 ADD

### WORKDIR
```dockerfile
WORKDIR /app
RUN pwd                     # 输出 /app
WORKDIR src
RUN pwd                     # 输出 /app/src
```
- 设置工作目录
- 后续指令的当前目录
- 目录不存在会自动创建

### ENV
```dockerfile
ENV NODE_ENV=production
ENV APP_HOME=/app
ENV PATH=$PATH:/app/bin
```

### ARG
```dockerfile
ARG VERSION=latest
FROM ubuntu:${VERSION}
ARG DEBIAN_FRONTEND=noninteractive
```
- 构建时变量，构建后不存在于镜像中
- `docker build --build-arg VERSION=22.04 -t my-image .`

### EXPOSE
```dockerfile
EXPOSE 80
EXPOSE 443/tcp
EXPOSE 53/udp
```
- 声明容器运行时监听的端口（文档性质）
- 实际映射仍需 `-p` 或 `-P` 参数

### USER
```dockerfile
RUN groupadd -r app && useradd -r -g app app
USER app
```
- 指定后续指令的运行用户
- 安全最佳实践：避免以 root 运行

### HEALTHCHECK
```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1
```
- 定义容器健康检查
- `docker inspect` 可查看健康状态

### SHELL
```dockerfile
SHELL ["/bin/bash", "-c"]
SHELL ["powershell", "-Command"]  # Windows
```
- 修改默认 shell

## 多阶段构建

```dockerfile
# 第一阶段：构建应用
FROM golang:1.21 AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o main .

# 第二阶段：运行镜像
FROM alpine:latest
RUN apk --no-cache add ca-certificates
WORKDIR /root/
COPY --from=builder /app/main .
CMD ["./main"]
```

**优势**：
- 最终镜像只包含运行时所需文件
- Go 二进制 + Alpine ≈ 15MB
- 构建工具和中间产物不进入最终镜像

## 构建缓存优化

```dockerfile
# 不好的做法（依赖变动会导致整个缓存失效）
COPY . .
RUN npm install

# 好的做法（先复制依赖文件，单独安装）
COPY package.json package-lock.json ./
RUN npm install
COPY . .
```

**缓存失效规则**：
- 基础镜像变更
- Dockerfile 指令变更
- COPY/ADD 的文件内容变更
- 之前的层缓存失效

## .dockerignore

```
.git
node_modules
*.md
.gitignore
Dockerfile
.dockerignore
dist
.cache
```

## 构建命令

```bash
# 基本构建
docker build -t my-app:v1 .

# 指定 Dockerfile 路径
docker build -f docker/Dockerfile.prod -t my-app:v1 .

# 带构建参数
docker build --build-arg VERSION=1.0 -t my-app:v1 .

# 不使用缓存
docker build --no-cache -t my-app:v1 .

# 指定平台
docker build --platform linux/amd64 -t my-app:v1 .
```

## 官方文档

- Dockerfile 参考：https://docs.docker.com/engine/reference/builder/
- 多阶段构建：https://docs.docker.com/build/building/multi-stage/
- 最佳实践：https://docs.docker.com/engine/userguide/eng-image/dockerfile_best-practices/
