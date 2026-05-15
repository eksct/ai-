# 服务发现与 Ingress

## Service 概述

Service 是 K8s 的服务发现和负载均衡机制，为一组 Pod 提供稳定的网络访问入口。

```
                 +-----------+
Client ─────────>|  Service  |─────────> Pod A (10.1.0.1)
                 | (10.0.0.1)|─────────> Pod B (10.1.0.2)
                 +-----------+─────────> Pod C (10.1.0.3)
```

## Service 类型

| 类型 | 访问方式 | 适用场景 |
|------|----------|----------|
| **ClusterIP** | 集群内虚拟 IP | 内部服务通信 |
| **NodePort** | 节点 IP + 固定端口 | 外部测试访问 |
| **LoadBalancer** | 云厂商 LB | 对外暴露服务 |
| **ExternalName** | DNS CNAME | 引用外部服务 |

---

### ClusterIP（默认）

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  type: ClusterIP
  selector:
    app: nginx
  ports:
    - name: http
      protocol: TCP
      port: 80              # Service 端口
      targetPort: 8080      # 容器端口
    - name: metrics
      port: 9113
      targetPort: 9113
```

集群内通过 `nginx-service` 或 `nginx-service.namespace.svc.cluster.local` 访问。

---

### NodePort

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-nodeport
spec:
  type: NodePort
  selector:
    app: nginx
  ports:
    - port: 80
      targetPort: 80
      nodePort: 30080       # 节点端口（30000-32767），不指定则随机
```

```bash
# 通过任意节点 IP + NodePort 访问
curl http://<node-ip>:30080
```

**注意：** NodePort 会占用宿主机端口，生产环境通常前面加一层 LB。

---

### LoadBalancer

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-lb
spec:
  type: LoadBalancer
  selector:
    app: nginx
  ports:
    - port: 80
      targetPort: 80
  externalTrafficPolicy: Local  # 保留客户端真实 IP
```

```bash
# 云厂商会自动创建 LB 并返回 External IP
kubectl get svc nginx-lb
# NAME        TYPE           CLUSTER-IP      EXTERNAL-IP     PORT(S)
# nginx-lb    LoadBalancer   10.96.12.34     a.b.c.d         80:30080/TCP
```

**externalTrafficPolicy：**
- `Cluster`（默认）：流量可能二次跳转
- `Local`：保留客户端 IP，但负载不均衡

---

### ExternalName

```yaml
apiVersion: v1
kind: Service
metadata:
  name: external-db
spec:
  type: ExternalName
  externalName: my-database.example.com
```

集群内通过 `external-db` 访问时，DNS 直接返回 `my-database.example.com` 的 CNAME。

---

## Service 工作原理

### kube-proxy 模式

| 模式 | 说明 | 性能 |
|------|------|------|
| **iptables** | 默认，通过 iptables 规则转发 | 中等 |
| **IPVS** | 基于内核 IPVS，支持更多调度算法 | 高 |
| **userspace** | 用户态代理（已废弃） | 低 |

```bash
# 查看当前模式
kubectl logs -n kube-system kube-proxy-xxxxx
# 或检查 Pod 日志
```

### 调度算法（IPVS 模式）

- `rr`：轮询（默认）
- `lc`：最少连接
- `dh`：目标哈希
- `sh`：源哈希（Session Affinity）
- `sed`：最短期望延迟

---

## Headless Service

用于 StatefulSet 或需要直接访问 Pod IP 的场景：

```yaml
apiVersion: v1
kind: Service
metadata:
  name: stateful-service
spec:
  clusterIP: None            # Headless
  selector:
    app: my-app
  ports:
    - port: 80
```

DNS 解析直接返回所有 Pod 的 IP 列表（A/AAAA 记录），而非虚拟 IP。

---

## Ingress（七层路由）

Ingress 提供 HTTP/HTTPS 路由，将外部请求转发到集群内 Service。

```
                    ┌────────────┐
Client ────────────>│  Ingress   │
                    │ Controller │
                    └─────┬──────┘
                   ┌──────┴──────┐
                   │              │
            ┌──────┴──────┐ ┌────┴───────┐
            │ Service: web │ │Service: api│
            └──────┬──────┘ └────┬───────┘
                   │              │
              ┌────┴────┐   ┌────┴────┐
              │ Pod:web │   │Pod:api  │
              └─────────┘   └─────────┘
```

### 安装 Ingress Controller

```bash
# Nginx Ingress Controller（最常用）
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml

# 其他选择：Traefik, HAProxy, Kong, AWS ALB Ingress Controller
```

### Ingress 基本示例

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: example-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - app.example.com
      secretName: app-tls
  rules:
    - host: app.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: web-service
                port:
                  number: 80
          - path: /api
            pathType: Prefix
            backend:
              service:
                name: api-service
                port:
                  number: 8080
```

### 多域名 Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: multi-domain-ingress
spec:
  ingressClassName: nginx
  rules:
    - host: blog.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: blog-service
                port:
                  number: 80
    - host: shop.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: shop-service
                port:
                  number: 80
```

### Path 匹配类型

| 类型 | 说明 | 示例 |
|------|------|------|
| `Exact` | 精确匹配 | `/api` 只匹配 `/api` |
| `Prefix` | 前缀匹配 | `/api` 匹配 `/api`, `/api/v1` |
| `ImplementationSpecific` | 取决于 Ingress Controller | 不同实现行为不同 |

### Nginx Ingress 常用注解

```yaml
metadata:
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$2
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/cors-enabled: "true"
    nginx.ingress.kubernetes.io/cors-allow-origin: "*"
    nginx.ingress.kubernetes.io/proxy-body-size: 10m
    nginx.ingress.kubernetes.io/proxy-connect-timeout: "30"
    nginx.ingress.kubernetes.io/limit-rps: "100"
    nginx.ingress.kubernetes.io/affinity: "cookie"
    nginx.ingress.kubernetes.io/session-cookie-name: "route"
    nginx.ingress.kubernetes.io/whitelist-source-range: "10.0.0.0/8, 172.16.0.0/12"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
```

## 蓝绿部署与金丝雀发布

### 金丝雀发布（Canary）

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: main-ingress
spec:
  ingressClassName: nginx
  rules:
    - host: app.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: app-stable
                port:
                  number: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: canary-ingress
  annotations:
    nginx.ingress.kubernetes.io/canary: "true"
    nginx.ingress.kubernetes.io/canary-weight: "10"  # 10% 流量
spec:
  ingressClassName: nginx
  rules:
    - host: app.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: app-canary
                port:
                  number: 80
```

---

## Gateway API（下一代）

K8s Gateway API 是 Ingress 的演进，支持更丰富的路由能力：

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: my-gateway
spec:
  gatewayClassName: nginx
  listeners:
    - name: http
      protocol: HTTP
      port: 80
    - name: https
      protocol: HTTPS
      port: 443
      tls:
        certificateRefs:
          - name: wildcard-cert
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: app-route
spec:
  parentRefs:
    - name: my-gateway
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /api
      backendRefs:
        - name: api-service
          port: 8080
```

---

## Session Affinity（会话保持）

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-service
spec:
  selector:
    app: web
  ports:
    - port: 80
  sessionAffinity: ClientIP
  sessionAffinityConfig:
    clientIP:
      timeoutSeconds: 10800  # 3 小时
```

---

## 生产实践建议

1. **内部服务用 ClusterIP**，不要每个服务都开 NodePort
2. **统一入口用 Ingress** 管理所有外部流量
3. **Ingress Controller 高可用**：至少 2 副本，设置 PDB
4. **HTTPS 终结在 Ingress**：Ingress 做 SSL 卸载，内部用 HTTP
5. **合理设置超时和重试**：避免级联超时
6. **外部流量用 LoadBalancer**：云环境用 LB + Ingress 的组合
7. **Headless Service 用于 StatefulSet**：数据库、消息队列等有状态应用

## 官方文档

- Service：https://kubernetes.io/docs/concepts/services-networking/service/
- Ingress：https://kubernetes.io/docs/concepts/services-networking/ingress/
- Ingress Controller：https://kubernetes.io/docs/concepts/services-networking/ingress-controllers/
- Gateway API：https://gateway-api.sigs.k8s.io/
