# Spring Boot 核心

## 概述

Spring Boot 解决了 Spring 框架最烦人的问题：XML 配置地狱、依赖版本冲突、应用部署复杂。它通过"约定大于配置"让你几分钟跑起一个生产级应用。

## 设计原理

### Spring Boot 在做什么？

```
传统 Spring：
  pom.xml 引入一堆 jar → 写 applicationContext.xml → 配置 web.xml → 部署到 Tomcat

Spring Boot：
  引入 spring-boot-starter-web → 写一个 @SpringBootApplication → java -jar
```

**核心权衡：**
- 好处：零配置启动、内嵌容器、自动装配
- 代价：过度封装导致排坑困难（出了问题不知道底层怎么工作的）

### @SpringBootApplication 是什么？

```java
@SpringBootApplication   // = @Configuration + @EnableAutoConfiguration + @ComponentScan
public class Application {
    public static void main(String[] args) {
        SpringApplication.run(Application.class, args);
    }
}
```

**坑：** `@SpringBootApplication` 默认扫描**当前包及子包**。如果你把启动类放在 `com.example`，而某个配置类在 `com.other`，它扫不到。很多人因为这个浪费半天。

解决办法：`@SpringBootApplication(scanBasePackages = {"com.example", "com.other"})`

## 核心概念

### IoC 容器（控制反转）

不是你 new 对象，而是容器帮你创建和管理。

```java
@Service        // 注册到容器
public class OrderService {
    @Autowired  // 容器自动注入
    private OrderMapper orderMapper;
}
```

**经验：** 构造器注入优于 @Autowired

```java
// ❌ 不推荐：@Autowired + Field 注入
@Service
public class OrderService {
    @Autowired
    private OrderMapper orderMapper;
}

// ✅ 推荐：构造器注入（final + 不可变、方便测试）
@Service
public class OrderService {
    private final OrderMapper orderMapper;

    public OrderService(OrderMapper orderMapper) {
        this.orderMapper = orderMapper;
    }
}
```

为什么？字段注入导致：
- 无法用 `new` 创建对象（测试麻烦）
- 循环依赖在编译期检查不出来
- IDEA 也会报黄

### AOP（面向切面编程）

经典场景：日志、权限、事务、缓存

```java
@Aspect
@Component
public class LogAspect {
    // 环绕通知：方法执行前后
    @Around("@annotation(loggable)")
    public Object around(ProceedingJoinPoint point, Loggable loggable) throws Throwable {
        long start = System.currentTimeMillis();
        try {
            Object result = point.proceed();
            log.info("{} 执行耗时: {}ms", point.getSignature(), System.currentTimeMillis() - start);
            return result;
        } catch (Exception e) {
            log.error("{} 异常: {}", point.getSignature(), e.getMessage());
            throw e;  // 注意：必须重新抛出，否则事务失效
        }
    }
}
```

**AOP 失效场景（生产踩坑）：**
1. 同类中的方法互相调用：`this.doSomething()` → AOP 不生效（代理对象没生效）
   - 解决：注入自己 `@Autowired` `OrderService self;` → `self.doSomething()`
2. private 方法不生效
3. final 方法不生效

## 配置加载优先级

Spring Boot 配置加载有 17 种来源，记住前 5 个就够用（**后面的覆盖前面的**）：

1. 命令行参数：`--server.port=8081`
2. `SPRING_APPLICATION_JSON` 环境变量
3. 操作系统环境变量
4. `application-{profile}.yml`（外部）
5. `application-{profile}.yml`（jar 内）
6. `application.yml`（外部）
7. `application.yml`（jar 内）

```yaml
# application.yml（jar 内）
server:
  port: 8080

# application-prod.yml（外部 /etc/order/application-prod.yml）
server:
  port: 80        # 生产环境用 80，覆盖默认的 8080
```

## 自动装配原理

```java
// 调用 SpringFactoriesLoader.loadFactoryNames()
// 从 META-INF/spring.factories 读取所有 AutoConfiguration
// 按 @Conditional 条件判断是否生效

@EnableAutoConfiguration
  → AutoConfigurationImportSelector
    → 加载 META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports
      → 逐一判断 @ConditionalOnClass、@ConditionalOnMissingBean...
        → 符合条件的生效
```

**生产价值：** 知道自动装配的原理，才能排查"为什么我加的配置不生效"。常见问题是某些 Starter 没引入，导致 `@ConditionalOnClass` 不满足，自动装配跳过。

## 踩坑记录

### 1. 循环依赖

```java
@Service
public class UserService {
    @Autowired
    private OrderService orderService;
}

@Service
public class OrderService {
    @Autowired
    private UserService userService;
}
```

Spring Boot 2.6+ 默认禁止循环依赖，启动直接报错。

**解决（按推荐顺序）：**
1. 重构：抽出一个新 Service 消除循环
2. 懒加载：`@Lazy`
3. 用 `@PostConstruct` 延迟初始化
4. 改配置：`spring.main.allow-circular-references=true`（不推荐，只是续命）

### 2. @Value 注入为 null

```java
@Service
public class OrderService {
    @Value("${order.timeout}")
    private Integer timeout;  // null! 为什么？
}
```

**原因：** 这个 Bean 不是 Spring 管理的（比如自己 `new` 出来的，或者在别的配置类中用 `@Bean` 创建时没扫描到）。

**排查：**
- 确认类上有 `@Service/@Component`
- 确认启动类的包能扫描到
- 确认配置文件中有这个 key

**经验：** `@ConfigurationProperties` 比 `@Value` 更安全，支持校验

```java
@Data
@ConfigurationProperties(prefix = "order")
@Component
public class OrderProperties {
    @NotEmpty
    private String timeout;
    private int maxRetries = 3;  // 有默认值
}
```

### 3. 配置文件注入乱码

**现象：** 中文配置读出来是 `???`

**原因：** Spring Boot 默认用 `ISO-8859-1` 读取 properties 文件

**解决：**
- 用 YAML 代替 properties（YAML 默认 UTF-8）
- 或者在 resources 目录下加一个自定义编码配置
