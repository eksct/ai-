# Kubernetes 学习笔记

由浅入深，系统学习 Kubernetes。参考官方文档并结合实际生产经验编写。

## 目录

| 文件 | 内容 | 难度 |
|------|------|------|
| [01-什么是Kubernetes.md](01-什么是Kubernetes.md) | K8s 概念、架构、组件 | ⭐ |
| [02-核心概念.md](02-核心概念.md) | Namespace/Node/Pod/Label/命令 | ⭐ |
| [03-Pod详解.md](03-Pod详解.md) | 生命周期/Probe/资源/Sidecar | ⭐⭐ |
| [04-工作负载.md](04-工作负载.md) | Deployment/StatefulSet/DaemonSet/Job | ⭐⭐ |
| [05-服务发现与Ingress.md](05-服务发现与Ingress.md) | Service/Ingress/Gateway API | ⭐⭐ |
| [06-配置管理.md](06-配置管理.md) | ConfigMap/Secret/热更新 | ⭐⭐ |
| [07-存储.md](07-存储.md) | Volume/PV/PVC/StorageClass/CSI | ⭐⭐⭐ |
| [08-调度与亲和性.md](08-调度与亲和性.md) | NodeSelector/亲和性/污点/拓扑分布 | ⭐⭐⭐ |
| [09-安全.md](09-安全.md) | RBAC/NetworkPolicy/Pod Security | ⭐⭐⭐ |
| [10-Helm.md](10-Helm.md) | Helm Chart/模板/仓库/实战 | ⭐⭐⭐ |
| [11-监控与日志.md](11-监控与日志.md) | Prometheus/Grafana/Loki/告警 | ⭐⭐⭐ |
| [12-网络原理.md](12-网络原理.md) | CNI/Calico/Cilium/kube-proxy/DNS | ⭐⭐⭐⭐ |
| [13-生产集群搭建.md](13-生产集群搭建.md) | kubeadm/高可用/组件部署 | ⭐⭐⭐⭐ |
| [14-实战案例.md](14-实战案例.md) | 微服务/CI-CD/大数据/故障排查 | ⭐⭐⭐⭐ |
| [15-最佳实践.md](15-最佳实践.md) | 安全/性能/成本/运维清单 | ⭐⭐⭐⭐ |

## 学习路径

```
初学者路线：
  01 → 02 → 03 → 04 → 05 → 06 → README + 动手实践

进阶路线：
  07 → 08 → 09 → 10 → 11 → 12

生产路线：
  13 → 14 → 15
```

## 官方参考

- [Kubernetes 官方文档](https://kubernetes.io/docs/)
- [kubectl 速查](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [API 参考](https://kubernetes.io/docs/reference/generated/kubernetes-api/)
- [CNCF 全景图](https://landscape.cncf.io/)
