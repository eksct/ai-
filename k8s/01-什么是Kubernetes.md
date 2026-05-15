# 什么是 Kubernetes

## 概述

Kubernetes（简称 K8s）是一个开源的容器编排平台，用于自动化部署、扩展和管理容器化应用。由 Google 设计并捐赠给 CNCF（Cloud Native Computing Foundation）管理。

## 为什么需要 K8s

当容器数量从几个增长到几百上千个时，会遇到以下问题：

| 问题 | 说明 |
|------|------|
| 服务发现 | 容器动态创建删除，IP 不固定 |
| 自动扩缩容 | 根据负载自动调整容器数量 |
| 负载均衡 | 流量分发到多个容器实例 |
| 滚动更新 | 不停机更新应用版本 |
| 自愈能力 | 容器故障时自动重启或迁移 |
| 配置管理 | 统一管理应用配置和密钥 |
| 存储编排 | 自动挂载持久化存储 |

## 核心架构

```
+-----------------------------------------------------+
|                     Control Plane                     |
|  +---------+  +---------+  +---------+  +---------+  |
|  |  API    |  | Scheduler|  |Controller|  | etcd    |  |
|  |  Server |  |          |  | Manager  |  | (KV DB) |  |
|  +---------+  +---------+  +---------+  +---------+  |
+-----------------------------------------------------+
          |                |
    +-----------+    +-----------+
    |   kubelet  |    |   kubelet  |   ... (Worker Nodes)
    +-----------+    +-----------+
    | +--------+|    | +--------+|
    | | Pod    ||    | | Pod    ||
    | |(容器组)||    | |(容器组)||
    | +--------+|    | +--------+|
    |   kube-proxy |    |   kube-proxy |
    +-----------+    +-----------+
```

### 控制平面组件

| 组件 | 角色 | 说明 |
|------|------|------|
| **kube-apiserver** | 网关 | 所有组件通信的入口，提供 REST API |
| **kube-scheduler** | 调度器 | 将 Pod 分配到合适的 Worker 节点 |
| **kube-controller-manager** | 控制器 | 运行各种控制器（Node/Deployment/ReplicaSet 等） |
| **etcd** | 数据库 | 分布式 KV 存储，保存集群所有状态数据 |
| **cloud-controller-manager** | 云控制器 | 与云厂商 API 集成（可选） |

### 工作节点组件

| 组件 | 角色 | 说明 |
|------|------|------|
| **kubelet** | 节点代理 | 管理节点上 Pod 的生命周期 |
| **kube-proxy** | 网络代理 | 实现 Service 的网络规则和负载均衡 |
| **CRI（如 containerd）** | 容器运行时 | 实际运行容器的引擎 |

## 核心资源对象

```
API 资源层级：

Namespace（命名空间 - 逻辑隔离）
  ├── Pod（最小的调度单位）
  ├── Service（服务发现与负载均衡）
  ├── Deployment（无状态应用）
  ├── StatefulSet（有状态应用）
  ├── DaemonSet（每个节点一个 Pod）
  ├── ConfigMap / Secret（配置管理）
  ├── PV / PVC（持久化存储）
  ├── Ingress（七层路由）
  ├── NetworkPolicy（网络策略）
  └── RBAC（权限控制）
```

## K8s 声明式模型

Kubernetes 采用**声明式**（Declarative）而非命令式（Imperative）的方式管理资源：

```bash
# 命令式（告诉系统怎么做）
docker run -d --name nginx -p 80:80 nginx

# 声明式（告诉系统想要什么状态）
kubectl apply -f deployment.yaml
```

**YAML 声明式工作流：**
```
用户编写 YAML → kubectl apply → API Server 校验 → etcd 存储
→ Controller 检测状态差异 → 执行操作 → 达到期望状态
```

## 为什么选择 K8s

1. **云原生标准**：CNCF 生态核心，几乎所有云厂商都支持
2. **可移植性**：可在任何基础设施上运行（物理机、虚拟机、公有云、混合云）
3. **自动化**：自动部署、自动扩缩容、自愈、自动回滚
4. **生态丰富**：Prometheus、Istio、ArgoCD、Helm 等数百种扩展
5. **社区活跃**：GitHub 上最活跃的开源项目之一

## 官方文档

- 概念：https://kubernetes.io/docs/concepts/
- 架构：https://kubernetes.io/docs/concepts/architecture/
