# Redis Cluster 集群

## 概述

哨兵模式解决了高可用（主挂了自动切），但**单机容量和性能有上限**：内存 64GB 封顶、QPS 10 万扛不住。Redis Cluster 提供**数据分片**——把数据分散到多台机器，每台只存一部分，整体容量和吞吐可以水平扩展。

## 设计原理

### 为什么需要 Cluster

| 问题 | 哨兵 | Cluster |
|------|------|---------|
| 单机内存不够 | ❌ 加内存有上限，fork 卡死 | ✅ 数据分片到多台机器 |
| 单机 QPS 瓶颈 | ❌ 读写都在一台 | ✅ 多台分摊请求 |
| 写入量爆炸 | ❌ 所有写走主库 | ✅ 多个主库分散写 |

### 数据分片（哈希槽）

Cluster 把整个 key 空间分成 **16384 个哈希槽**，每个节点负责一段槽位。

```
key "user:1001" → CRC16("user:1001") % 16384 → 槽位 3522 → 节点 A
key "order:888" → CRC16("order:888") % 16384 → 槽位 11890 → 节点 B
```

```
Cluster 架构：
+----------+    +----------+    +----------+
| 节点 A   |    | 节点 B   |    | 节点 C   |
| 槽 0-5460|    | 5461-10922|   | 10923-16383|
| 主       |    | 主       |    | 主       |
| +------+ |    | +------+ |    | +------+ |
| |从 A1 | |    | |从 B1 | |    | |从 C1 | |
| +------+ |    | +------+ |    | +------+ |
+----------+    +----------+    +----------+
     |                |               |
     +------- gossip 协议互相通信 ------+
```

每个主节点配一个从节点做高可用。主挂了，从顶上。

### 节点间通信（gossip 协议）

Cluster 的节点之间用 gossip 协议交换状态信息（谁活着、槽位分配等），不是全部靠一个中心节点，避免单点瓶颈和脑裂。

每个节点每 100ms 随机选几个节点 ping 一下，交换信息。集群状态在几秒内收敛。

## 搭建 Cluster

### 最小集群（3 主 3 从）

```bash
# 启动 6 个 Redis 实例（不同端口）
redis-server --port 7000 --cluster-enabled yes --cluster-config-file nodes-7000.conf
redis-server --port 7001 --cluster-enabled yes --cluster-config-file nodes-7001.conf
redis-server --port 7002 --cluster-enabled yes --cluster-config-file nodes-7002.conf
redis-server --port 7003 --cluster-enabled yes --cluster-config-file nodes-7003.conf
redis-server --port 7004 --cluster-enabled yes --cluster-config-file nodes-7004.conf
redis-server --port 7005 --cluster-enabled yes --cluster-config-file nodes-7005.conf

# 用 redis-cli 一键组建集群
redis-cli --cluster create 127.0.0.1:7000 127.0.0.1:7001 127.0.0.1:7002 \
    127.0.0.1:7003 127.0.0.1:7004 127.0.0.1:7005 \
    --cluster-replicas 1
# --cluster-replicas 1 表示每个主库配 1 个从库
# 前 3 个会自动成为主库，后 3 个成为对应的从库
```

### 验证

```bash
# 查看集群状态
redis-cli -p 7000 cluster info
redis-cli -p 7000 cluster nodes

# 测试写入（-c 参数自动重定向到正确节点）
redis-cli -c -p 7000
SET foo bar
# 如果 foo 的槽位不在 7000，客户端自动重连到正确节点
```

### Go 客户端连接 Cluster

```go
// go-redis Cluster 模式
rdb := redis.NewClusterClient(&redis.ClusterOptions{
    Addrs: []string{
        "127.0.0.1:7000",
        "127.0.0.1:7001",
        "127.0.0.1:7002",
    },
})
// 客户端自动发现所有节点，key 自动路由到正确节点
err := rdb.Set(ctx, "foo", "bar", 0).Err()
```

## 客户端路由

客户端写一个 key，如果目标槽位不在当前节点，Redis 返回 **MOVED 重定向**：

```bash
# 客户端连 7000，但 foo 的槽在 7001
127.0.0.1:7000> SET foo bar
-> Redirected to slot [12182] located at 127.0.0.1:7001
OK
```

- **Smart 客户端**（go-redis / Jedis）：内部维护槽位映射表，直接算好槽位连到正确节点，不需要重定向
- **普通客户端**：每次收到 MOVED 再重新连，性能差。生产必须用 Smart 客户端

## 生产实践

### 常用架构

| 规模 | 集群方案 | 说明 |
|------|---------|------|
| < 50GB | 哨兵 | 单机够用，无需分片 |
| 50~500GB | 3 主 3 从 | 9 节点起步，数据平均分到 3 台 |
| > 500GB | 6 主 6 从 | 更多分片，每台内存压力小 |

### 踩坑记录

1. **跨槽事务不支持**：Redis Cluster 不支持跨节点的 `MULTI/EXEC` 事务和 `Lua` 脚本（除非涉及的 key 在同一个槽）。设计时要把需要事务的 key 用 `{}` 强制放到同一槽：`{user}:1001`、`{user}:1002:orders`（`{}` 里的内容参与哈希计算）
2. **mget/mset 跨槽性能差**：`MGET` 的 key 分布在多个节点上，客户端需要并发请求再聚合。用 `{}` 把相关 key 放到同一槽，或者不用批量操作
3. **resharding 期间性能下降**：扩缩容时需要迁移槽位（`redis-cli --cluster rebalance`），数据迁移会占用网络和磁盘 IO。生产环境安排在低峰期操作
4. **Cluster 不支持多 DB**：单机 Redis 可以用 `SELECT 0/1/2` 切换数据库，Cluster 不支持。只能用不同的 key 前缀做逻辑隔离
5. **最小节点数 3**：Cluster 至少需要 3 个主节点（因为投票需要多数存活），少于 3 个建不起来。测试环境最低配 3 主 0 从，生产至少 3 主 3 从

## 总结

| 模式 | 容量 | QPS | 高可用 | 自动分片 |
|------|------|-----|--------|---------|
| 单机 | 内存上限 | 10 万 | ❌ | ❌ |
| 哨兵 | 内存上限 | 10 万 | ✅ | ❌ |
| Cluster | 几乎无限 | 百万级 | ✅ | ✅ |

数据量 < 50GB 用哨兵，> 50GB 用 Cluster。

## 参考

[[03-主从与哨兵]]
[[05-缓存设计与淘汰策略]]
