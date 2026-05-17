# 部署与 DevOps

## 概述

一个 Spring Boot 应用从开发到上线的标准路径：代码 → 构建 → 镜像 → 部署。这篇讲的是**生产级别的部署规范**，不是开发环境 `java -jar`。

## Docker 镜像构建

### Dockerfile

```dockerfile
# ========== 多阶段构建 ==========
# 第一阶段：编译
FROM eclipse-temurin:17-jdk-alpine AS builder
WORKDIR /build
COPY . .
# 只打包 start 模块，跳过测试
RUN ./mvnw clean package -pl order-service-start -am -DskipTests -T 4

# 第二阶段：运行（最小化镜像）
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app

# 非 root 用户运行（安全）
RUN addgroup -S app && adduser -S app -G app

# 从 builder 阶段复制 jar 包
COPY --from=builder /build/order-service-start/target/*.jar app.jar

USER app

EXPOSE 8080

# 健康检查
HEALTHCHECK --interval=10s --timeout=3s --retries=3 \
    CMD wget -qO- http://localhost:8080/actuator/health || exit 1

ENTRYPOINT ["java", "-jar", "app.jar"]
```

### .dockerignore

```
.git
.gitignore
**/target/
**/node_modules/
**/.idea/
**/*.md
**/logs/
```

### 构建和推送

```bash
# 构建镜像
docker build -t registry.example.com/order-service:1.0.0 .

# 推送
docker push registry.example.com/order-service:1.0.0
```

## 配置外置（重要）

```yaml
# 反模式：把 application-prod.yml 打到镜像里
# 正确做法：启动时指定外部配置

# 方式一：挂载配置目录
# docker run -v /etc/order:/app/config -e SPRING_CONFIG_ADDITIONAL-LOCATION=/app/config/

# 方式二：环境变量
-e SPRING_PROFILES_ACTIVE=prod
-e DB_URL=jdbc:mysql://...
-e DB_USERNAME=...
-e DB_PASSWORD=...
-e REDIS_HOST=...
-e RABBIT_HOST=...

# 方式三：配置中心（推荐）
# Nacos / Apollo / Spring Cloud Config
# bootstrap.yml 配置即可
```

### 配置分类

```yaml
# 按敏感程度分类

# 1. 不敏感：提交到代码仓库
# application.yml（通用配置）
server:
  port: 8080
logging:
  level:
    root: INFO

# 2. 环境差异：各环境不同但非敏感
# application-dev.yml / application-prod.yml
spring:
  datasource:
    url: jdbc:mysql://prod-db:3306/order_db

# 3. 敏感信息：永远不进代码仓库
# 环境变量或配置中心
DB_PASSWORD: xxxx
REDIS_PASSWORD: xxxx
JWT_SECRET: xxxx
```

## 健康检查和优雅停机

```yaml
# application-prod.yml
server:
  shutdown: graceful            # 优雅停机

spring:
  lifecycle:
    timeout-per-shutdown-phase: 30s  # 最多等 30 秒

management:
  endpoints:
    web:
      exposure:
        include: health,info
  endpoint:
    health:
      show-details: never       # 生产不暴露详情
```

```java
// 自定义健康检查
@Component
public class DatabaseHealthIndicator implements HealthIndicator {
    @Autowired
    private DataSource dataSource;

    @Override
    public Health health() {
        try (Connection conn = dataSource.getConnection()) {
            if (conn.isValid(3)) {
                return Health.up().withDetail("database", "连接正常").build();
            }
            return Health.down().withDetail("database", "连接异常").build();
        } catch (Exception e) {
            return Health.down(e).build();
        }
    }
}
```

## 生产启动脚本

```bash
#!/bin/bash
# start.sh - 生产启动脚本

APP_NAME="order-service"
JAR_PATH="/opt/app/${APP_NAME}.jar"
LOG_PATH="/data/logs/${APP_NAME}"
JAVA_OPTS="-Xms2g -Xmx2g -Xmn1g"

# JVM 参数（生产必配）
JAVA_OPTS="${JAVA_OPTS}
    -XX:+UseG1GC
    -XX:MaxGCPauseMillis=200
    -XX:+HeapDumpOnOutOfMemoryError
    -XX:HeapDumpPath=${LOG_PATH}/heapdump.hprof
    -XX:+PrintGCDetails
    -Xloggc:${LOG_PATH}/gc.log
    -Dspring.profiles.active=prod
"

# 检查是否已在运行
PID_FILE="/var/run/${APP_NAME}.pid"
if [ -f "$PID_FILE" ]; then
    echo "应用已在运行，PID: $(cat $PID_FILE)"
    exit 1
fi

# 启动
nohup java ${JAVA_OPTS} -jar ${JAR_PATH} > ${LOG_PATH}/console.log 2>&1 &
echo $! > $PID_FILE
echo "应用启动完成，PID: $(cat $PID_FILE)"

# 等待就绪
for i in {1..30}; do
    if curl -s http://localhost:8080/actuator/health | grep -q "UP"; then
        echo "应用就绪！"
        exit 0
    fi
    sleep 2
done
echo "启动超时，请检查日志"
exit 1
```

## CI/CD 流水线（GitHub Actions 示例）

```yaml
# .github/workflows/deploy.yml
name: Deploy

on:
  push:
    branches: [main]
    paths:
      - 'order-service/**'

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up JDK
        uses: actions/setup-java@v4
        with:
          java-version: '25'
          distribution: 'temurin'

      - name: Build
        run: ./mvnw clean package -pl order-service-start -am -DskipTests

      - name: Build Docker image
        run: |
          docker build -t registry.example.com/order-service:${{ github.sha }} .
          docker tag registry.example.com/order-service:${{ github.sha }} \
                    registry.example.com/order-service:latest

      - name: Push Docker image
        run: |
          docker login -u ${{ secrets.REGISTRY_USER }} -p ${{ secrets.REGISTRY_PASS }}
          docker push registry.example.com/order-service:${{ github.sha }}
          docker push registry.example.com/order-service:latest

      - name: Deploy
        run: |
          ssh deploy@prod-server "
            docker pull registry.example.com/order-service:${{ github.sha }}
            docker stop order-service || true
            docker rm order-service || true
            docker run -d --name order-service \
              --restart=unless-stopped \
              -v /etc/order/config:/app/config \
              -p 8080:8080 \
              registry.example.com/order-service:${{ github.sha }}
          "
```

## 踩坑记录

### 1. JVM 参数未配置导致 OOM

**现象：** 部署后没设 `-Xmx`，JVM 默认用 1/4 宿主机内存，容器只有 512m，直接 OOM

**教训：** Dockerfile 里设 `JAVA_OPTS`，用环境变量传入

### 2. Graceful Shutdown 没配，重启时大量 502

**现象：** 滚动更新时，K8s 把旧 Pod 杀掉了，但还在处理的请求全部断开

**解决：** 配置优雅停机和 preStop hook

```yaml
# K8s deployment
lifecycle:
  preStop:
    exec:
      command: ["sleep", "10"]  # 给负载均衡器时间摘除节点
```

### 3. 配置文件打包进了镜像

**现象：** 构建镜像时把 `application-prod.yml` 打进去了，里面有数据库密码

**解决：** 配置外置，环境变量注入，镜像里不放任何敏感配置

### 4. 多环境混乱

**现象：** 开发连了生产数据库，测试环境用了生产 Redis

**解决：** 统一配置中心，**每个环境用不同的 namespace**，代码里不硬编码任何连接信息
