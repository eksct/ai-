# Docker 网络

## 网络驱动类型

| 驱动 | 说明 | 适用场景 |
|------|------|----------|
| `bridge` | 默认驱动，通过网桥连接容器 | 单机容器通信 |
| `host` | 容器直接使用宿主机网络 | 性能要求高，端口冲突风险 |
| `overlay` | 跨宿主机容器网络 | Docker Swarm 多机通信 |
| `macvlan` | 容器分配 MAC 地址，直连物理网络 | 遗留应用迁移 |
| `none` | 无网络 | 不需要网络的容器 |

## 默认 Bridge 网络

Docker 安装时自动创建一个名为 `bridge` 的默认网桥：

```bash
# 查看网络
docker network ls

# 查看默认 bridge 详情
docker network inspect bridge
```

### 容器通信（通过 IP）

```bash
# 同一个 bridge 网络中的容器可以通过 IP 通信
docker run -d --name container1 nginx
docker run -it --name container2 ubuntu:22.04 bash

# 查看 container1 的 IP
docker inspect container1 | grep IPAddress
# 在 container2 中 ping container1 的 IP
```

### 端口映射（外网访问）

```bash
# 通过宿主机端口访问容器
docker run -d -p 8080:80 nginx
# 访问 http://localhost:8080 即可访问容器内的 80 端口
```

## 自定义 Bridge 网络（推荐）

自定义 bridge 比默认 bridge 功能更强，提供了 DNS 解析。

```bash
# 创建网络
docker network create --driver bridge my-network

# 指定子网和网关
docker network create \
  --driver bridge \
  --subnet 172.20.0.0/16 \
  --gateway 172.20.0.1 \
  my-network

# 运行容器时指定网络
docker run -d --name web --network my-network nginx
docker run -d --name db --network my-network mysql:8.0

# 容器之间可以通过容器名通信（内置 DNS）
docker exec -it web ping db    # 通过容器名 ping
```

### 连接/断开网络
```bash
# 将运行中的容器连接到网络
docker network connect my-network container

# 断开连接
docker network disconnect my-network container

# 一个容器可以连接多个网络
docker network connect bridge container
```

## Host 网络

容器使用宿主机网络，不进行网络隔离：

```bash
docker run -d --network host nginx
# 直接通过宿主机 IP 访问，无需端口映射
# -p 参数无效，因为容器直接使用宿主机网络栈
```

**适用场景**：
- 对网络性能要求极高
- 容器需要监听大量端口

## Overlay 网络

用于 Swarm 集群中跨节点容器通信：

```bash
# 需要先初始化 Swarm
docker swarm init

# 创建 overlay 网络
docker network create -d overlay my-overlay-network

# 创建可被非 Swarm 服务使用的 overlay 网络
docker network create -d overlay --attachable my-overlay
```

## 网络命令总结

```bash
# 列出网络
docker network ls

# 创建网络
docker network create --driver bridge my-net

# 查看网络详情
docker network inspect my-net

# 删除网络
docker network rm my-net

# 清理未使用的网络
docker network prune

# 连接容器到网络
docker network connect my-net container

# 断开容器和网络
docker network disconnect my-net container
```

## DNS 配置

```bash
# 自定义 DNS
docker run --dns 8.8.8.8 --dns 114.114.114.114 nginx

# 自定义 hosts
docker run --add-host host.docker.internal:host-gateway nginx

# DNS 搜索域
docker run --dns-search example.com nginx
```

## 网络隔离与安全

```bash
# 创建两个网络隔离不同服务
docker network create frontend
docker network create backend

# 前端服务可以访问后端
docker network connect frontend web
docker network connect frontend api
docker network connect backend api
docker network connect backend db

# 结果：web 不能直接访问 db（不在同一网络）
```

## 常见网络拓扑

```
Frontend Network          Backend Network
+----------+             +----------+
|   Nginx  |             |   API    |
| (front)  |<----------->| (front+  |
+----------+             |  back)   |
                         +----------+
                              |
                         +----------+
                         |   MySQL  |
                         | (back)   |
                         +----------+
```

## 官方文档

- 网络概览：https://docs.docker.com/engine/network/
- bridge 驱动：https://docs.docker.com/engine/network/drivers/bridge/
- overlay 驱动：https://docs.docker.com/engine/network/drivers/overlay/
