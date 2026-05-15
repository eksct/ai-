# Pod 详解

## Pod 生命周期

```
Pending → Running → Succeeded/Failed
                    ↓
                 Unknown
    ↓                    ↓
  CrashLoopBackOff     Evicted
```

### 生命周期阶段

| 阶段 | 说明 |
|------|------|
| `Pending` | Pod 已创建，但容器尚未全部运行（拉镜像、调度中等） |
| `Running` | Pod 已调度到节点，所有容器已启动 |
| `Succeeded` | 所有容器正常退出（Job 类 Pod） |
| `Failed` | 容器异常退出 |
| `CrashLoopBackOff` | 容器反复崩溃重启 |
| `Unknown` | 节点失联，无法获取 Pod 状态 |

## Pod 健康检查（Probe）

K8s 提供三种探针来检测容器状态：

| 探针 | 用途 | 失败后果 |
|------|------|----------|
| **livenessProbe** | 判断容器是否存活 | 重启容器 |
| **readinessProbe** | 判断容器是否就绪 | 从 Service 端点移除 |
| **startupProbe** | 判断容器是否启动完成 | 重启容器（用于慢启动应用） |

### 完整示例

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: web-app
  labels:
    app: web
spec:
  containers:
    - name: app
      image: my-app:latest
      ports:
        - containerPort: 8080
      # 启动探针 - 给慢启动应用充足时间
      startupProbe:
        httpGet:
          path: /health/startup
          port: 8080
        initialDelaySeconds: 3
        periodSeconds: 5
        failureThreshold: 30   # 最多等 150s

      # 存活探针 - 检测应用是否死锁
      livenessProbe:
        httpGet:
          path: /healthz
          port: 8080
        initialDelaySeconds: 10
        periodSeconds: 10
        timeoutSeconds: 3
        failureThreshold: 3

      # 就绪探针 - 检测是否可以接收流量
      readinessProbe:
        httpGet:
          path: /ready
          port: 8080
        initialDelaySeconds: 5
        periodSeconds: 5
        successThreshold: 1
        failureThreshold: 2
```

### 探针类型

```yaml
# HTTP 请求
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
    httpHeaders:
      - name: X-Custom-Header
        value: health

# TCP 端口检测
readinessProbe:
  tcpSocket:
    port: 3306
  initialDelaySeconds: 15
  periodSeconds: 10

# 执行命令
livenessProbe:
  exec:
    command:
      - cat
      - /tmp/healthy
  initialDelaySeconds: 5
  periodSeconds: 5
```

**探针参数说明：**
- `initialDelaySeconds`：容器启动后等待多久开始探测
- `periodSeconds`：探测间隔（默认 10s）
- `timeoutSeconds`：超时时间（默认 1s）
- `successThreshold`：成功阈值（默认 1）
- `failureThreshold`：失败阈值（默认 3）

## 资源限制

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: resource-demo
spec:
  containers:
    - name: app
      image: nginx
      resources:
        requests:       # 调度时保证的最小资源
          cpu: "0.5"    # 500 毫核
          memory: "256Mi"
        limits:         # 运行时上限
          cpu: "1"      # 1000 毫核
          memory: "512Mi"
```

**CPU 单位：**
- `1` = 1 核（vCPU/hyperthread）
- `500m` = 0.5 核
- `100m` = 0.1 核

**内存单位：**
- `256Mi` = 256 Mebibytes
- `1Gi` = 1 Gibibyte
- `512M` = 512 Megabytes（不推荐用 M 后缀）

**资源行为对比：**

| 场景 | CPU | 内存 |
|------|-----|------|
| 超出 requests 但未达 limits | 允许（可抢占） | 允许 |
| 超出 limits | 限流（throttle） | **OOM Kill** |
| 节点资源不足 | 按 QoS 驱逐 | 按 QoS 驱逐 |

**QoS 等级：**
```yaml
# Guaranteed（最高优先级）
resources:
  limits: { cpu: "1", memory: "1Gi" }
  requests: { cpu: "1", memory: "1Gi" }    # 必须等于 limits

# Burstable
resources:
  limits: { cpu: "2", memory: "2Gi" }
  requests: { cpu: "1", memory: "1Gi" }    # 小于 limits

# BestEffort（最低优先级）
# 不设置任何 requests/limits
```

## Init 容器

Init 容器在主容器启动前执行，用于初始化工作：

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: init-demo
spec:
  initContainers:
    - name: init-myservice
      image: busybox:1.28
      command: ["sh", "-c", "until nslookup myservice; do echo waiting; sleep 2; done"]
    - name: init-mydb
      image: busybox:1.28
      command: ["sh", "-c", "until nslookup mydb; do echo waiting; sleep 2; done"]
  containers:
    - name: main
      image: nginx
```

**特点：**
- 按顺序执行，前一个成功才启动下一个
- 如果失败，Pod 重启
- 只支持 `restartPolicy: Always` 的部分场景
- Init 容器不支持 `readinessProbe`

## Sidecar 模式

在同一个 Pod 中运行辅助容器，增强或扩展主容器功能：

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: sidecar-demo
spec:
  containers:
    - name: app               # 主应用
      image: my-app:latest
      ports:
        - containerPort: 8080
    - name: sidecar            # 边车容器
      image: fluentd:latest
      volumeMounts:
        - name: logs
          mountPath: /var/log/app
    - name: proxy              # 代理容器
      image: envoyproxy/envoy:v1.28-latest
      ports:
        - containerPort: 9901
  volumes:
    - name: logs
      emptyDir: {}
```

**常见 Sidecar 场景：**
- 日志采集（Filebeat/Fluentd）
- 服务网格代理（Envoy/Istio）
- 配置热加载
- 指标采集

## Pod 调度

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: scheduled-pod
spec:
  # 节点选择器（简单匹配）
  nodeSelector:
    disktype: ssd
    gpu: "true"

  # 容忍污点
  tolerations:
    - key: "gpu"
      operator: "Equal"
      value: "true"
      effect: "NoSchedule"

  # 节点亲和性（灵活匹配）
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: topology.kubernetes.io/zone
                operator: In
                values:
                  - us-east-1a
                  - us-east-1b

  containers:
    - name: app
      image: nginx
```

## Pod 安全上下文

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: security-demo
spec:
  securityContext:
    runAsUser: 1000
    runAsGroup: 3000
    fsGroup: 2000
    supplementalGroups: [4000]
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: app
      image: nginx
      securityContext:
        runAsUser: 2000          # 覆盖 Pod 级别
        allowPrivilegeEscalation: false
        capabilities:
          drop: ["ALL"]
        readOnlyRootFilesystem: true
```

## 常见排查命令

```bash
# Pod 状态排查
kubectl get pod <pod-name>                 # 查看状态
kubectl describe pod <pod-name>            # 查看事件
kubectl logs <pod-name>                    # 查看日志
kubectl logs <pod-name> -c <container>     # 多容器时指定容器
kubectl logs --previous <pod-name>         # 查看上次崩溃日志

# 调试
kubectl exec -it <pod-name> -- sh
kubectl cp <pod-name>:/path /local/path
kubectl port-forward pod/<pod-name> 8080:80  # 端口转发到本地

# 事件
kubectl get events --sort-by='.lastTimestamp'
kubectl get events -w                      # 实时监控事件
```

## Pod 中断预算（PDB）

保证应用在节点维护时最少可用实例数：

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: web-pdb
spec:
  minAvailable: 2          # 最少可用 2 个
  # maxUnavailable: 1      # 或：最多不可用 1 个
  selector:
    matchLabels:
      app: web
```

## 官方文档

- Pod 概述：https://kubernetes.io/docs/concepts/workloads/pods/
- Pod 生命周期：https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/
- 配置探针：https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/
- 资源管理：https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/
