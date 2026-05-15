# Docker 镜像

## 什么是 Docker 镜像

Docker 镜像是一个轻量级、独立、可执行的软件包，包含运行应用程序所需的一切：代码、运行时、系统工具、库和配置。

## 镜像分层结构

Docker 镜像由多个只读层叠加组成，每一层代表一个 Dockerfile 指令：

```
+-------------------+
|    Container      |  (可写层，容器运行时修改)
+-------------------+
|   Layer 3: CMD    |  (只读)
+-------------------+
|   Layer 2: RUN    |  (只读)
+-------------------+
|   Layer 1: COPY   |  (只读)
+-------------------+
|   Base Image      |  (只读，如 ubuntu:22.04)
+-------------------+
```

**特点**：
- 层可复用，多个镜像共享相同层
- 层只读，容器运行时在顶层添加可写层
- 每个层有唯一 ID (SHA256)
- 分层机制节省磁盘空间和网络带宽

## 常用镜像命令

```bash
# 拉取镜像
docker pull ubuntu:22.04
docker pull nginx:alpine

# 列出本地镜像
docker images
docker image ls

# 查看镜像历史（查看分层）
docker history nginx:alpine

# 查看镜像详细信息
docker inspect nginx:alpine

# 标记镜像（打标签）
docker tag nginx:alpine my-nginx:v1

# 删除镜像
docker rmi my-nginx:v1

# 构建镜像
docker build -t my-app:v1 .
```

## 镜像仓库

### Docker Hub
- 官方公共镜像仓库
- 搜索镜像：https://hub.docker.com
- 拉取限制（匿名用户每 6 小时 100 次，认证用户 200 次）

### 镜像命名规则
```
[registry-host/][username/]repository[:tag|@digest]

示例：
nginx                  # 官方镜像，默认 latest 标签
nginx:alpine           # 指定标签
username/my-app:v1     # 用户仓库
myregistry.com:5000/my-app:v1  # 私有仓库
```

### 推送镜像到 Docker Hub
```bash
docker login                  # 登录
docker tag my-app username/my-app:v1
docker push username/my-app:v1
```

### 私有仓库
```bash
# 运行本地 registry
docker run -d -p 5000:5000 --name registry registry:2

# 推送镜像到本地仓库
docker tag my-app localhost:5000/my-app:v1
docker push localhost:5000/my-app:v1

# 从本地仓库拉取
docker pull localhost:5000/my-app:v1
```

## 镜像构建原理

### 构建上下文 (Build Context)
```bash
docker build -t my-app .
```
- `.` 指定构建上下文路径
- Docker daemon 将整个上下文打包发送给构建进程
- 使用 `.dockerignore` 排除不必要的文件

### 缓存机制
- 每条指令执行后生成一个新层并缓存
- 如果指令和上下文未变，直接使用缓存
- 某层缓存失效后，后续层都会重新构建
- 优化：将不常变的指令放在前面

## 多架构镜像 (Multi-arch)

Docker 支持在一个清单中引用多个架构的镜像：

```bash
# 查看支持的架构
docker buildx ls

# 创建多架构构建器
docker buildx create --name mybuilder --use

# 构建多架构镜像
docker buildx build --platform linux/amd64,linux/arm64 \
  -t username/my-app:latest --push .
```

## 镜像大小优化

| 方法 | 说明 |
|------|------|
| 选择小型基础镜像 | `alpine` (5MB) vs `ubuntu` (70MB) |
| 多阶段构建 | 只保留运行所需产物 |
| 合并 RUN 指令 | 减少层数，清除缓存 |
| 使用 `.dockerignore` | 排除不必要的文件 |
| --squash (实验性) | 将多层合并为一层 |

## 官方文档

- 镜像概览：https://docs.docker.com/engine/storage/drivers/
- 构建最佳实践：https://docs.docker.com/engine/userguide/eng-image/dockerfile_best-practices/
- 镜像仓库：https://docs.docker.com/registry/
