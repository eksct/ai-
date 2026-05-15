# Docker 容器

## 什么是容器

容器是镜像的可运行实例。与虚拟机不同，容器直接运行在宿主机内核上，实现进程级隔离。

## 容器生命周期

```
+--------+    docker run    +---------+   docker stop   +---------+
|  Created | -------------> | Running | --------------> | Stopped |
+--------+                 +---------+                 +---------+
     ^                         |                           |
     |     docker start        | docker pause/unpause      | docker rm
     +-------------------------+                           |
                                                    +---------+
                                                    | Removed |
                                                    +---------+
```

## 创建和运行容器

### 基本用法
```bash
# 前台运行
docker run nginx

# 后台运行 (detached)
docker run -d nginx

# 指定名称
docker run --name my-web -d nginx

# 交互式运行
docker run -it ubuntu:22.04 bash

# 端口映射
docker run -d -p 8080:80 nginx
# -p 宿主机端口:容器端口

# 自动清理
docker run --rm -it ubuntu:22.04 bash
# 容器退出后自动删除
```

### 资源限制
```bash
# 内存限制
docker run -d --memory="512m" --memory-reservation="256m" nginx

# CPU 限制
docker run -d --cpus="1.5" --cpu-shares=512 nginx

# 限制容器可用的 PID 数量
docker run -d --pids-limit=100 nginx

# 限制磁盘读写
docker run -d --device-read-bps=/dev/sda:1mb --device-write-bps=/dev/sda:1mb nginx

# 重启策略
docker run -d --restart=always nginx   # 始终重启
docker run -d --restart=on-failure:5   # 失败时重启最多 5 次
docker run -d --restart=unless-stopped # 除非手动停止，否则重启
```

## 管理容器

```bash
# 列出容器
docker ps                    # 运行中
docker ps -a                 # 全部
docker ps -a --format "table {{.ID}}\t{{.Names}}\t{{.Status}}"  # 自定义格式

# 停止/启动/重启
docker stop container
docker start container
docker restart container

# 暂停/恢复
docker pause container       # 暂停所有进程
docker unpause container     # 恢复

# 信号发送
docker kill container        # 直接 SIGKILL
docker kill -s SIGTERM container  # 发送自定义信号
```

## 进入容器

```bash
# exec（推荐方式）
docker exec -it container bash
docker exec -it container sh   # Alpine 镜像
docker exec -it container /bin/bash

# attach（附加到容器主进程）
docker attach container
# 注意：attach 会连接到容器的主进程，退出可能导致容器停止

# 查看容器内进程
docker top container
docker stats                   # 实时资源监控
```

## 容器日志

```bash
# 查看日志
docker logs container
docker logs -f container         # 实时跟踪
docker logs --tail 100 container # 最后 100 行
docker logs -t container         # 显示时间戳

# 日志驱动配置
docker run -d --log-driver json-file --log-opt max-size=10m --log-opt max-file=3 nginx
# 支持 json-file, syslog, journald, gelf, fluentd, awslogs 等
```

## 容器网络

默认情况下，容器可以访问外网，但外网不能直接访问容器。

```bash
# 端口映射
docker run -d -p 8080:80 nginx      # 映射到宿主机 8080
docker run -d -p 127.0.0.1:8080:80  # 仅本地访问
docker run -d -p 8080:80/udp nginx  # UDP 端口

# 端口暴露（不映射，仅声明）
docker run -d --expose 80 nginx

# 查看端口映射
docker port container
```

## 容器和宿主机交互

```bash
# 复制文件
docker cp /host/file container:/path/in/container
docker cp container:/path/in/container /host/file

# 查看变更
docker diff container
# A = Added, C = Changed, D = Deleted

# 导出/导入容器
docker export container > container.tar
cat container.tar | docker import - my-image:latest
```

## 容器状态查看

```bash
# 查看容器进程
docker inspect container

# 查看资源使用
docker stats                    # 实时
docker stats --no-stream        # 一次输出

# 查看容器内进程
docker top container
```

## 容器清理

```bash
# 删除指定容器
docker rm container

# 强制删除运行中的容器
docker rm -f container

# 删除所有已停止容器
docker container prune

# 删除所有容器（包括运行中的）
docker rm -f $(docker ps -aq)
```

## 容器化最佳实践

1. **每个容器只运行一个进程** - 保持容器职责单一
2. **容器是无状态的** - 数据持久化使用卷或绑定挂载
3. **使用 .dockerignore** - 减少构建上下文大小
4. **合理设置资源限制** - 避免单个容器耗尽宿主机资源
5. **不要以 root 运行** - 使用 USER 指令指定非 root 用户
6. **容器中不要运行 sshd** - 使用 docker exec 进入容器

## 官方文档

- 容器概览：https://docs.docker.com/engine/containers/
- 运行容器：https://docs.docker.com/engine/reference/run/
