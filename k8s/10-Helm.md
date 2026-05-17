# Helm - Kubernetes 包管理工具

## 什么是 Helm

Helm 是 K8s 的包管理器，用于定义、安装和升级复杂的 K8s 应用。类似 Linux 的 apt/yum。

### 核心概念

| 概念 | 说明 |
|------|------|
| **Chart** | 应用的打包格式，包含 YAML 模板和依赖 |
| **Repository** | Chart 存储仓库 |
| **Release** | Chart 在集群中的部署实例 |
| **Values** | 配置值，注入到模板中 |
| **Template** | Go 模板引擎，生成最终 YAML |

### Helm v3 的变化

- 删除 Tiller（服务端组件）
- 不再依赖 `helm init`
- 三路合并策略（当前状态 + 新配置 + 旧 Release）
- 支持 OCI 仓库存储 Chart

---

## 安装 Helm

```bash
# Windows (Chocolatey / Scoop)
choco install kubernetes-helm
scoop install helm

# macOS
brew install helm

# Linux
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# 验证
helm version
helm repo list
```

---

## 仓库管理

```bash
# 添加官方仓库
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add stable https://charts.helm.sh/stable
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add jetstack https://charts.jetstack.io

# 更新仓库
helm repo update

# 搜索 Chart
helm search repo nginx
helm search hub nginx           # 搜索 Artifact Hub

# 查看仓库列表
helm repo list

# 删除仓库
helm repo remove <name>
```

---

## Chart 基本使用

### 安装 Chart

```bash
helm install [name] [chart] [flags]

# 示例
helm install my-nginx bitnami/nginx

# 指定命名空间
helm install my-nginx bitnami/nginx --namespace dev --create-namespace

# 自定义 values
helm install my-nginx bitnami/nginx --set replicaCount=3 --set service.type=NodePort

# 从 values 文件
helm install my-nginx bitnami/nginx -f values.yaml
helm install my-nginx bitnami/nginx -f values.yaml -f override.yaml  # 合并

# 不同环境
helm install my-app ./my-chart -f values-prod.yaml
```

### 查看和管理 Release

```bash
# 列出所有 Release
helm list
helm list -n dev
helm list -A                      # 所有命名空间

# 查看 Release 状态
helm status my-nginx

# 查看 Release 信息
helm get notes my-nginx
helm get values my-nginx
helm get manifest my-nginx        # 查看渲染后的 YAML

# 升级 Release
helm upgrade my-nginx bitnami/nginx --set replicaCount=5
helm upgrade my-nginx bitnami/nginx -f values-new.yaml

# 回滚
helm rollback my-nginx 1          # 回滚到版本 1
helm history my-nginx             # 查看历史版本

# 删除 Release
helm uninstall my-nginx
```

---

## 创建自己的 Chart

### 目录结构

```
my-chart/
├── Chart.yaml                 # Chart 元数据
├── values.yaml                # 默认配置值
├── values.schema.json         # values 的 JSON Schema（可选）
├── charts/                    # 子 Chart 依赖
├── crds/                      # CRD 定义
└── templates/                 # Go 模板文件
    ├── _helpers.tpl           # 模板辅助函数
    ├── NOTES.txt              # 安装后提示信息
    ├── deployment.yaml
    ├── service.yaml
    ├── ingress.yaml
    ├── hpa.yaml
    ├── serviceaccount.yaml
    └── tests/
        └── test-connection.yaml
```

### Chart.yaml

```yaml
apiVersion: v2
name: my-app
description: My application Helm chart
type: application
version: 1.0.0                 # Chart 版本
appVersion: "v2.5.1"          # 应用版本
kubeVersion: ">=1.21.0-0"

dependencies:
  - name: mysql
    version: "9.x"
    repository: "https://charts.bitnami.com/bitnami"
    condition: mysql.enabled
    alias: database
  - name: redis
    version: "17.x"
    repository: "https://charts.bitnami.com/bitnami"
    condition: redis.enabled

keywords:
  - web
  - api

maintainers:
  - name: developer
    email: dev@example.com

sources:
  - https://github.com/example/my-app
```

### values.yaml

```yaml
# 全局配置
global:
  environment: production
  imageRegistry: ""

# 镜像配置
image:
  repository: my-app
  tag: v2.5.1
  pullPolicy: IfNotPresent
  pullSecrets: []

# 副本数
replicaCount: 3

# 服务配置
service:
  type: ClusterIP
  port: 8080
  targetPort: 8080

# Ingress
ingress:
  enabled: true
  className: nginx
  hosts:
    - host: app.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: app-tls
      hosts:
        - app.example.com
  annotations:
    nginx.ingress.kubernetes.io/proxy-body-size: "10m"

# 资源限制
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 256Mi

# 自动扩缩容
autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 20
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80

# 环境变量
env:
  - name: APP_ENV
    value: production
  - name: DB_HOST
    value: ""

# 探针配置
probes:
  liveness:
    path: /healthz
    initialDelaySeconds: 30
    periodSeconds: 10
  readiness:
    path: /ready
    initialDelaySeconds: 5
    periodSeconds: 5

# 持久化存储
persistence:
  enabled: true
  size: 10Gi
  storageClass: gp3
  accessMode: ReadWriteOnce

# 依赖服务
mysql:
  enabled: true
  auth:
    database: myapp
    username: myapp
  primary:
    persistence:
      size: 20Gi

redis:
  enabled: true
  architecture: standalone
  auth:
    enabled: false

# 节点选择
nodeSelector:
  environment: production

tolerations:
  - key: "dedicated"
    operator: "Exists"

affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchLabels:
              app.kubernetes.io/name: my-app
          topologyKey: kubernetes.io/hostname
```

### 模板文件示例

```yaml
# templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "my-app.fullname" . }}
  labels:
    {{- include "my-app.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      {{- include "my-app.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "my-app.selectorLabels" . | nindent 8 }}
    spec:
      {{- with .Values.image.pullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      containers:
        - name: {{ .Chart.Name }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - name: http
              containerPort: {{ .Values.service.targetPort }}
              protocol: TCP
          env:
            {{- toYaml .Values.env | nindent 12 }}
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
          {{- with .Values.probes }}
          livenessProbe:
            httpGet:
              path: {{ .liveness.path }}
              port: http
            initialDelaySeconds: {{ .liveness.initialDelaySeconds }}
          readinessProbe:
            httpGet:
              path: {{ .readiness.path }}
              port: http
            initialDelaySeconds: {{ .readiness.initialDelaySeconds }}
          {{- end }}
```

### _helpers.tpl（模板辅助函数）

```yaml
{{- define "my-app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "my-app.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{- define "my-app.labels" -}}
helm.sh/chart: {{ include "my-app.name" . }}-{{ .Chart.Version | replace "+" "_" }}
{{ include "my-app.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "my-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "my-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
```

### 生成 Chart 脚手架

```bash
# 创建 Chart 模板
helm create my-chart

# 验证模板
helm lint my-chart

# 渲染模板（查看生成的 YAML）
helm template my-chart
helm template my-chart --debug

# 模拟安装
helm install --dry-run --debug my-release ./my-chart -f values-prod.yaml
```

---

## 依赖管理

```bash
# 更新 Chart 依赖
helm dependency update my-chart/

# 构建依赖（将依赖下载到 charts/ 目录）
helm dependency build my-chart/

# 查看依赖
helm dependency list my-chart/
```

---

## 发布 Chart 到 OCI 仓库

```bash
# 登录 OCI 仓库
helm registry login registry.example.com

# 打包 Chart
helm package my-chart/

# 推送到 OCI 仓库
helm push my-chart-1.0.0.tgz oci://registry.example.com/charts

# 从 OCI 仓库安装
helm install my-app oci://registry.example.com/charts/my-app --version 1.0.0
```

---

## Chart 版本管理

```bash
# 打包 Chart
helm package my-chart/

# 生成索引（用于仓库）
helm repo index ./ --url https://charts.example.com

# 版本规范
# Chart 版本遵循 SemVer 2：MAJOR.MINOR.PATCH
# 应用版本可独立于 Chart 版本
```

---

## Helm 测试

```yaml
# templates/tests/test-connection.yaml
apiVersion: v1
kind: Pod
metadata:
  name: "{{ include "my-app.fullname" . }}-test-connection"
  labels:
    {{- include "my-app.labels" . | nindent 4 }}
  annotations:
    "helm.sh/hook": test
spec:
  containers:
    - name: wget
      image: busybox
      command: ['wget']
      args: ['{{ include "my-app.fullname" . }}:{{ .Values.service.port }}']
  restartPolicy: Never
```

```bash
helm test my-release
```

---

## 生产实践

1. **区分环境**：`values-dev.yaml` / `values-staging.yaml` / `values-prod.yaml`
2. **版本锁定**：提交 `Chart.lock`，确保依赖版本一致
3. **CI/CD 集成**：`helm template` + `kubectl apply` 或 `helm upgrade --install`
4. **使用 Helmfile** 管理多个 Chart 的编排关系
5. **不要存储 Secret 在 values 中**，使用外部密钥管理
6. **Hooks 用于数据库迁移**：`pre-upgrade`, `post-upgrade` hooks
7. **NOTES.txt 写清楚**：安装后需要执行的操作

### Helmfile 示例

```yaml
# helmfile.yaml
repositories:
  - name: bitnami
    url: https://charts.bitnami.com/bitnami
  - name: jetstack
    url: https://charts.jetstack.io

releases:
  - name: cert-manager
    namespace: cert-manager
    chart: jetstack/cert-manager
    version: v1.13.0
    values:
      - installCRDs: true

  - name: nginx-ingress
    namespace: ingress-nginx
    chart: ingress-nginx/ingress-nginx
    version: 4.8.0
    values:
      - "./helm-values/ingress-nginx.yaml"

  - name: my-app
    namespace: production
    chart: ./charts/my-app
    version: 1.0.0
    values:
      - "./helm-values/my-app-prod.yaml"
    secrets:
      - "./helm-secrets/my-app-secrets.yaml"
    needs:
      - cert-manager
      - nginx-ingress
```

```bash
helmfile sync         # 部署所有
helmfile destroy      # 删除所有
```

## 官方文档

- Helm 文档：https://helm.sh/docs/
- Chart 模板指南：https://helm.sh/docs/chart_template_guide/
- 最佳实践：https://helm.sh/docs/chart_best_practices/
- Chart 仓库：https://artifacthub.io/
