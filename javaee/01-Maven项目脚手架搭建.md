# Maven 项目脚手架搭建

## 概述

Maven 是 Java 项目的事实标准构建工具，负责依赖管理、编译打包、生命周期管理。Gradle 在某些场景（Android、大数据）也有广泛应用，但企业级后端项目以 Maven 为主流，建议优先掌握 Maven。

## 核心概念

### 坐标（GAV）

```xml
<groupId>com.example</groupId>      <!-- 公司域名反写 -->
<artifactId>order-service</artifactId>  <!-- 项目/模块名 -->
<version>1.0.0-SNAPSHOT</version>      <!-- 版本号 -->
<packaging>jar</packaging>              <!-- jar/war/pom -->
```

**版本号规范（生产必须遵守）：**
- `1.0.0-SNAPSHOT`：开发中，不稳定
- `1.0.0-RC1`：发布候选
- `1.0.0.RELEASE`：正式发布
- `1.0.1`：Bugfix 版本
- `1.1.0`：小版本升级（兼容）
- `2.0.0`：大版本升级（不兼容）

### 依赖 scope

| scope | 编译 | 测试 | 运行 | 打包 | 说明 |
|-------|------|------|------|------|------|
| compile | ✅ | ✅ | ✅ | ✅ | 默认 |
| provided | ✅ | ✅ | ❌ | ❌ | 容器提供（servlet/lombok）|
| runtime | ❌ | ✅ | ✅ | ✅ | JDBC 驱动 |
| test | ❌ | ✅ | ❌ | ❌ | junit |
| system | ✅ | ✅ | ❌ | ❌ | 不推荐 |

## 生产级项目分层

```
order-service/
├── order-service-api/           # DTO、Feign 接口、常量（对外暴露）
├── order-service-common/        # 工具类、通用组件
├── order-service-dal/           # 数据访问层（Mapper + Entity）
├── order-service-biz/           # 核心业务层（Service）
├── order-service-web/           # 控制层（Controller）
├── order-service-start/         # 启动类、配置（打包入口）
│   ├── src/main/resources/
│   │   ├── application.yml          # 主配置
│   │   ├── application-dev.yml      # 开发环境
│   │   ├── application-prod.yml     # 生产环境（不提交 git）
│   │   └── bootstrap.yml            # Nacos 配置中心（可选）
│   └── Dockerfile
└── pom.xml                      # 父 POM
```

### 为什么这么分？

- **api 模块**：提供给其他服务调用（Feign 接口），不暴露内部实现
- **dal 模块**：数据库表的映射，独立变动不影响上层
- **biz 模块**：核心业务逻辑，事务边界在这里
- **web 模块**：对外提供 HTTP 接口
- **start 模块**：打包入口，配置外置的关键

**踩坑记录：**
- 早期项目把所有代码放在一个模块里，多人 merge 天天冲突，构建一次 5 分钟
- 拆分后每个模块独立构建，改动 dal 只需重新发布 dal 和依赖它的模块

## Parent POM 最佳实践

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0
         http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <groupId>com.example</groupId>
    <artifactId>order-service</artifactId>
    <version>1.0.0-SNAPSHOT</version>
    <packaging>pom</packaging>

    <properties>
        <java.version>17</java.version>
        <maven.compiler.source>${java.version}</maven.compiler.source>
        <maven.compiler.target>${java.version}</maven.compiler.target>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
        <project.reporting.outputEncoding>UTF-8</project.reporting.outputEncoding>

        <!-- 统一版本管理 -->
        <spring-boot.version>3.2.0</spring-boot.version>
        <spring-cloud.version>2023.0.0</spring-cloud.version>
        <mybatis-plus.version>3.5.5</mybatis-plus.version>
        <hutool.version>5.8.25</hutool.version>
    </properties>

    <!-- 统一依赖管理（子模块不需要写版本号） -->
    <dependencyManagement>
        <dependencies>
            <dependency>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-dependencies</artifactId>
                <version>${spring-boot.version}</version>
                <type>pom</type>
                <scope>import</scope>
            </dependency>
            <dependency>
                <groupId>com.baomidou</groupId>
                <artifactId>mybatis-plus-boot-starter</artifactId>
                <version>${mybatis-plus.version}</version>
            </dependency>
            <dependency>
                <groupId>cn.hutool</groupId>
                <artifactId>hutool-all</artifactId>
                <version>${hutool.version}</version>
            </dependency>
        </dependencies>
    </dependencyManagement>

    <build>
        <pluginManagement>
            <plugins>
                <plugin>
                    <groupId>org.springframework.boot</groupId>
                    <artifactId>spring-boot-maven-plugin</artifactId>
                    <configuration>
                        <mainClass>com.example.order.OrderApplication</mainClass>
                        <!-- 关键：打包时排除 Lombok（provided 依赖无需打入 jar） -->
                        <excludes>
                            <exclude>
                                <groupId>org.projectlombok</groupId>
                                <artifactId>lombok</artifactId>
                            </exclude>
                        </excludes>
                    </configuration>
                </plugin>
            </plugins>
        </pluginManagement>
    </build>
</project>
```

### Spring Boot Start 模块的 POM

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0
         http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <parent>
        <artifactId>order-service</artifactId>
        <groupId>com.example</groupId>
        <version>1.0.0-SNAPSHOT</version>
        <relativePath>../pom.xml</relativePath>
    </parent>
    <artifactId>order-service-start</artifactId>

    <dependencies>
        <dependency>
            <groupId>com.example</groupId>
            <artifactId>order-service-web</artifactId>
            <version>${project.version}</version>
        </dependency>
    </dependencies>

    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
            </plugin>
        </plugins>
    </build>
</project>
```

## 配置文件外置（生产必知）

**反模式：** 把 `application-prod.yml` 打到 jar 包里。

**正确做法：**

```bash
# 方式一：启动时指定外部配置
java -jar order-service.jar --spring.profiles.active=prod
java -jar order-service.jar --spring.config.location=/etc/order/config/

# 方式二：环境变量
SPRING_PROFILES_ACTIVE=prod java -jar order-service.jar

# 方式三：配置中心（推荐）
# bootstrap.yml 配置 Nacos，所有配置从 Nacos 拉取
```

## 常用 Maven 命令

```bash
# 清理编译打包（跳过测试）
mvn clean package -DskipTests -U

# 只编译不打包
mvn compile

# 安装到本地仓库
mvn clean install

# 多模块分批打包
mvn clean package -pl order-service-start -am

# 运行测试
mvn test
mvn test -Dtest=OrderServiceTest

# 依赖分析
mvn dependency:tree                  # 查看依赖树，排查冲突
mvn dependency:analyze               # 检查未使用和未声明的依赖

# 跳过指定模块
mvn clean install -pl '!order-service-api'
```

## 依赖冲突排查

**典型症状：** `NoSuchMethodError`、`ClassNotFoundException`

```bash
# 查看依赖树，找出冲突版本
mvn dependency:tree | grep slf4j

# 排除冲突依赖
<dependency>
    <groupId>com.example</groupId>
    <artifactId>some-lib</artifactId>
    <exclusions>
        <exclusion>
            <groupId>org.slf4j</groupId>
            <artifactId>slf4j-simple</artifactId>
        </exclusion>
    </exclusions>
</dependency>
```

## 踩坑记录

### 1. Lombok 在编译时未生效
**现象：** `Cannot find symbol 'log'` 等编译错误
**原因：** IDE 未安装 Lombok 插件，或 Maven 编译时 annotation processor 未配置
**解决：**
```xml
<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-compiler-plugin</artifactId>
    <configuration>
        <annotationProcessorPaths>
            <path>
                <groupId>org.projectlombok</groupId>
                <artifactId>lombok</artifactId>
            </path>
        </annotationProcessorPaths>
    </configuration>
</plugin>
```

### 2. SNAPSHOT 依赖不更新
**现象：** 明明改了代码，但用依赖方拿到的还是旧版本
**原因：** Maven 默认 24 小时才检查一次 SNAPSHOT 更新
**解决：** 加 `-U` 参数强制更新，或者配 `<snapshots><updatePolicy>always</updatePolicy></snapshots>`

### 3. 打包后配置文件没带进来
**现象：** jar 包启动说找不到配置
**原因：** resources 目录配置不对，或者用了 `<resources>` 覆盖了默认行为
**解决：**
```xml
<resources>
    <resource>
        <directory>src/main/resources</directory>
        <filtering>false</filtering>
        <includes>
            <include>**/*.yml</include>
            <include>**/*.xml</include>
        </includes>
    </resource>
</resources>
```

### 4. 多模块打包找不到依赖
**现象：** `Could not resolve dependencies`
**原因：** 子模块依赖其他模块时，必须先 `mvn install` 到本地仓库
**解决：** 使用 `-am`（also-make）参数自动构建依赖模块
```bash
mvn clean package -pl order-service-start -am
```
