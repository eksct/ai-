# Docker 数据管理

## 概述

Docker 提供三种数据存储方式：

| 方式 | 说明 | 存储位置 | 生命周期 |
|------|------|----------|----------|
| **Volume**（卷） | Docker 管理的数据持久化方式 | `/var/lib/docker/volumes/` | 独立于容器 |
| **Bind Mount**（绑定挂载） | 宿主机目录直接挂载到容器 | 宿主机任意路径 | 依赖宿主机 |
| **tmpfs Mount** | 内存中的临时文件系统 | 宿主机内存 | 随容器停止而清除 |

## Volume（卷） - 推荐方式

### 创建和管理 Volume

```bash
# 创建卷
docker volume create my-volume

# 列出卷
docker volume ls

# 查看卷详情
docker volume inspect my-volume

# 删除卷
docker volume rm my-volume

# 清理未使用的卷
docker volume prune

# 删除所有未使用卷
docker volume prune -a
```

### 使用 Volume

```bash
# 运行容器并挂载卷
docker run -d \
  --name mysql \
  -v mysql-data:/var/lib/mysql \
  -e MYSQL_ROOT_PASSWORD=root \
  mysql:8.0

# 多个容器共享同一个卷
docker run -d --name app1 -v shared-data:/data nginx
docker run -d --name app2 -v shared-data:/data nginx

# 卷驱动（支持 NFS 等第三方驱动）
docker volume create \
  --driver local \
  --opt type=nfs \
  --opt o=addr=192.168.1.100,rw \
  --opt device=:/path/to/dir \
  nfs-volume
```

## Bind Mount（绑定挂载）

### 基本用法

```bash
# 挂载宿主机目录到容器
docker run -d \
  --name web \
  -v /host/path:/usr/share/nginx/html:ro \
  nginx

# 或者使用 --mount 语法（更明确）
docker run -d \
  --name web \
  --mount type=bind,source=/host/path,target=/usr/share/nginx/html,readonly \
  nginx
```

### 应用场景

```bash
# 1. 开发时热重载
docker run -d \
  -v $(pwd):/app \
  -w /app \
  node:18 \
  npm run dev

# 2. 配置文件挂载
docker run -d \
  -v /etc/nginx/nginx.conf:/etc/nginx/nginx.conf:ro \
  nginx

# 3. 日志持久化
docker run -d \
  -v $(pwd)/logs:/var/log/nginx \
  nginx
```

### 注意事项
- 宿主机路径必须为绝对路径
- 如果宿主机路径不存在，Docker 会**自动创建目录**
- 绑定挂载会覆盖容器内原有内容（如果目标路径非空）
- 使用 `:ro` 设置只读挂载

## tmpfs Mount（内存挂载）

```bash
# 创建 tmpfs 挂载
docker run -d \
  --name temp \
  --tmpfs /tmp:size=100M,noexec \
  nginx

# 或使用 --mount 语法
docker run -d \
  --name temp \
  --mount type=tmpfs,destination=/tmp,tmpfs-size=100000000 \
  nginx
```

**适用场景**：
- 敏感信息（密码、密钥等）
- 不需要持久化的临时数据
- 高频读写且无需持久化的数据

## Volume vs Bind Mount 对比

| 对比项 | Volume | Bind Mount |
|--------|--------|------------|
| 管理方式 | Docker 管理 | 用户管理 |
| 备份迁移 | 容易（`docker run --volumes-from`） | 手动处理 |
| 跨平台 | 支持所有 Docker 平台 | 依赖路径语法 |
| 安全性 | 仅 Docker 可管理 | 任何进程可读写 |
| 远程存储 | 支持卷驱动插件 | 不支持 |
| 适用场景 | 生产环境、数据库持久化 | 开发环境、配置注入 |

## 数据备份与恢复

### 备份 Volume
```bash
# 使用临时容器备份
docker run --rm \
  -v my-volume:/data \
  -v $(pwd):/backup \
  ubuntu:22.04 \
  tar czf /backup/my-volume-backup.tar.gz -C /data .
```

### 恢复 Volume
```bash
# 创建新卷并恢复
docker volume create my-volume-restored
docker run --rm \
  -v my-volume-restored:/data \
  -v $(pwd):/backup \
  ubuntu:22.04 \
  tar xzf /backup/my-volume-backup.tar.gz -C /data
```

## 权限管理

```bash
# 指定容器内的文件所有者
docker run -d \
  --user 1000:1000 \
  -v data:/data \
  nginx

# 使用 named volume 自动初始化权限
# Docker 会在首次使用时复制镜像中该路径的文件和权限
```

## 存储驱动

Docker 使用存储驱动管理镜像层和容器层数据：

| 驱动 | 适用系统 | 特点 |
|------|----------|------|
| overlay2 | Linux（推荐） | 性能好，稳定 |
| fuse-overlayfs | rootless 模式 | 用户态文件系统 |
| aufs | 旧版 Linux | 已弃用 |
| devicemapper | 旧版 Linux | 已弃用 |
| windowsfilter | Windows | Windows 容器 |

```bash
# 查看当前存储驱动
docker info | grep "Storage Driver"
```

## 官方文档

- 数据管理：https://docs.docker.com/engine/storage/
- 卷：https://docs.docker.com/engine/storage/volumes/
- 绑定挂载：https://docs.docker.com/engine/storage/bind-mounts/
- tmpfs：https://docs.docker.com/engine/storage/tmpfs/
