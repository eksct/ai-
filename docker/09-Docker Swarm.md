# Docker Swarm

## 什么是 Docker Swarm

Docker Swarm 是 Docker 原生的容器编排工具，用于管理跨多个主机的 Docker 容器集群。它将一组 Docker 主机组合成一个虚拟的 Docker 主机。

## 核心概念

### 节点 (Node)
- **Manager 节点**：管理集群状态、调度服务、处理编排任务
- **Worker 节点**：执行由 Manager 分配的任务

### 服务 (Service)
- Swarm 中最基本的调度单元
- 定义要在集群中运行的任务模板
- 可声明副本数、网络、端口等

### 任务 (Task)
- 服务的一个具体实例（即一个容器）
- Swarm 调度器将任务分配给合适的节点

## Swarm 架构

```
+--------------------------------------------------+
|                   Swarm Cluster                    |
|                                                    |
|  +-------------+    +-------------+                |
|  | Manager 1   |    | Manager 2   |                |
|  | (leader)    |<-->|             |                |
|  +------+------+    +------+------+                |
|         |                  |                        |
|  +------+------+    +------+------+                |
|  | Manager 3   |    |   Worker 1  |                |
|  +-------------+    +-------------+                |
|                          |                          |
|                   +------+------+                   |
|                   |   Worker 2  |                   |
|                   +-------------+                   |
+--------------------------------------------------+
```

## 初始化 Swarm

```bash
# 初始化 swarm（当前节点成为 Manager）
docker swarm init --advertise-addr 192.168.1.100

# 查看节点状态
docker node ls

# 生成 Worker 加入令牌
docker swarm join-token worker

# 生成 Manager 加入令牌
docker swarm join-token manager

# Worker 节点加入集群
docker swarm join --token <WORKER_TOKEN> 192.168.1.100:2377

# 离开集群
docker swarm leave

# Manager 离开集群（需要先降级）
docker node demote <node-name>
docker swarm leave --force
```

## 部署服务

```bash
# 创建服务
docker service create \
  --name web \
  --replicas 3 \
  --publish 80:80 \
  nginx:alpine

# 列出服务
docker service ls

# 查看服务详情
docker service ps web

# 查看服务日志
docker service logs web

# 扩缩容
docker service scale web=5

# 更新服务
docker service update \
  --image nginx:latest \
  --update-parallelism 2 \
  --update-delay 10s \
  web

# 回滚服务
docker service rollback web

# 删除服务
docker service rm web
```

## 服务模式

### 副本模式 (Replicated)
```bash
docker service create \
  --name web \
  --replicas 3 \
  nginx:alpine
```

### 全局模式 (Global)
```bash
# 每个节点运行一个任务
docker service create \
  --name monitor \
  --mode global \
  prom/node-exporter
```

## 网络

```bash
# 创建 overlay 网络
docker network create -d overlay my-network

# 部署服务时指定网络
docker service create \
  --name web \
  --network my-network \
  nginx:alpine

# 创建可路由网络
docker network create -d overlay \
  --subnet 10.0.0.0/24 \
  --gateway 10.0.0.1 \
  --attachable \
  my-network
```

## 配置文件与密钥

### Config（配置文件）
```bash
# 创建配置
docker config create nginx.conf ./nginx.conf

# 使用配置
docker service create \
  --name web \
  --config source=nginx.conf,target=/etc/nginx/nginx.conf \
  nginx:alpine
```

### Secret（密钥）
```bash
# 创建密钥
echo "my-password" | docker secret create db_password -

# 使用密钥
docker service create \
  --name db \
  --secret source=db_password,target=/run/secrets/db_password \
  -e MYSQL_ROOT_PASSWORD_FILE=/run/secrets/db_password \
  mysql:8.0

# 密钥特点：仅存储于 Manager 节点，仅在需要时传递给 Worker
```

## 滚动更新

```bash
docker service create \
  --name web \
  --replicas 5 \
  --update-delay 10s \          # 每批更新间隔
  --update-parallelism 2 \       # 并行更新数
  --update-failure-action pause \ # 更新失败时暂停
  --rollback-monitor 20s \       # 回滚监控时间
  --rollback-parallelism 1 \     # 回滚并行数
  nginx:1.27

# 触发更新
docker service update --image nginx:1.27 web
```

## Swarm 模式下的 Compose

```yaml
# docker-stack.yml
version: "3.8"

services:
  web:
    image: nginx:alpine
    ports:
      - "80:80"
    deploy:
      mode: replicated
      replicas: 3
      update_config:
        parallelism: 2
        delay: 10s
      restart_policy:
        condition: on-failure
      resources:
        limits:
          cpus: "0.5"
          memory: "512M"
    networks:
      - frontend

  app:
    image: myapp:latest
    depends_on:
      - db
    deploy:
      replicas: 2
    networks:
      - frontend
      - backend

  db:
    image: postgres:15
    volumes:
      - db_data:/var/lib/postgresql/data
    deploy:
      mode: global
    networks:
      - backend

networks:
  frontend:
    driver: overlay
  backend:
    driver: overlay

volumes:
  db_data:
```

```bash
# 部署 Stack
docker stack deploy -c docker-stack.yml myapp

# 查看 Stack
docker stack ls
docker stack services myapp
docker stack ps myapp

# 删除 Stack
docker stack rm myapp
```

## Swarm 管理命令

```bash
# 节点管理
docker node ls                          # 列出节点
docker node inspect <node>              # 节点详情
docker node promote <node>              # 升级为 Manager
docker node demote <node>               # 降级为 Worker
docker node update --availability drain <node>  # 设为不可调度

# 服务管理
docker service ls                       # 列出服务
docker service ps <service>             # 列出服务任务
docker service logs <service>           # 查看服务日志
docker service inspect <service>        # 服务详情

# Stack 管理
docker stack deploy -c compose.yml <name>
docker stack ls
docker stack ps <name>
docker stack services <name>
docker stack rm <name>
```

## Raft 一致性

Swarm 使用 Raft 协议保证集群状态一致：
- Manager 节点数量应为奇数（1, 3, 5, 7）
- 建议 3 或 5 个 Manager 节点
- 超过 7 个 Manager 会影响性能
- 半数以上 Manager 存活才能正常工作

## 官方文档

- Swarm 模式：https://docs.docker.com/engine/swarm/
- Swarm 教程：https://docs.docker.com/engine/swarm/swarm-tutorial/
- Stack 部署：https://docs.docker.com/engine/swarm/stack/
