# 中间件集成（Redis + RabbitMQ）

## 第一部分：Redis

## 概述

Redis 在 Java 生产中最常用的场景：缓存、分布式锁、限流、计数器。别把它当万能数据库，它就是缓存 + 一些简单数据结构的用途。

## 集成

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-data-redis</artifactId>
</dependency>
<dependency>
    <groupId>org.apache.commons</groupId>
    <artifactId>commons-pool2</artifactId>  <!-- 连接池 -->
</dependency>
```

```yaml
spring:
  data:
    redis:
      host: ${REDIS_HOST:localhost}
      port: ${REDIS_PORT:6379}
      password: ${REDIS_PASSWORD:}
      database: 0
      timeout: 3000ms
      lettuce:
        pool:
          max-active: 16       # 连接池最大连接数
          max-idle: 8          # 最大空闲连接
          min-idle: 4          # 最小空闲连接
          max-wait: 500ms      # 获取连接超时
```

## 缓存操作

### RedisTemplate 配置

```java
@Configuration
public class RedisConfig {
    @Bean
    public RedisTemplate<String, Object> redisTemplate(RedisConnectionFactory factory) {
        RedisTemplate<String, Object> template = new RedisTemplate<>();
        template.setConnectionFactory(factory);

        // 使用 Jackson 序列化
        Jackson2JsonRedisSerializer<Object> serializer = new Jackson2JsonRedisSerializer<>(
                new ObjectMapper().findAndRegisterModules(), Object.class);

        // key 用 String 序列化
        template.setKeySerializer(new StringRedisSerializer());
        template.setHashKeySerializer(new StringRedisSerializer());
        // value 用 JSON 序列化
        template.setValueSerializer(serializer);
        template.setHashValueSerializer(serializer);

        template.afterPropertiesSet();
        return template;
    }
}
```

### 缓存 Service

```java
@Service
public class CacheService {
    @Autowired
    private RedisTemplate<String, Object> redisTemplate;

    private static final long DEFAULT_TTL = 3600; // 1 小时

    public void set(String key, Object value) {
        redisTemplate.opsForValue().set(key, value, DEFAULT_TTL, TimeUnit.SECONDS);
    }

    public void set(String key, Object value, long ttl, TimeUnit unit) {
        redisTemplate.opsForValue().set(key, value, ttl, unit);
    }

    public <T> T get(String key, Class<T> clazz) {
        Object value = redisTemplate.opsForValue().get(key);
        if (clazz.isInstance(value)) {
            return clazz.cast(value);
        }
        return null;
    }

    public Boolean setNx(String key, Object value, long ttl, TimeUnit unit) {
        // SET NX EX — 原子操作，分布式锁基础
        return redisTemplate.opsForValue().setIfAbsent(key, value, ttl, unit);
    }

    public void delete(String key) {
        redisTemplate.delete(key);
    }

    // 缓存穿透防护：查询不到时设置空值
    public <T> T getWithBlank(String key, Class<T> clazz, long ttl, Supplier<T> loader) {
        Object value = redisTemplate.opsForValue().get(key);
        if (value != null) {
            // 命中空值标记，直接返回 null
            if ("EMPTY".equals(value)) return null;
            return clazz.cast(value);
        }

        T result = loader.get();
        if (result == null) {
            // 缓存空值，防穿透，TTL 短一点
            set(key, "EMPTY", 60, TimeUnit.SECONDS);
        } else {
            set(key, result, ttl, TimeUnit.SECONDS);
        }
        return result;
    }
}
```

## 分布式锁

### 生产级 Redis 锁

```java
@Service
public class RedisLock {
    @Autowired
    private RedisTemplate<String, Object> redisTemplate;

    private static final String LOCK_PREFIX = "lock:";
    private static final long DEFAULT_LEASE_TIME = 30; // 租约时间 30s

    /**
     * 尝试获取锁
     * @param key 锁的 key
     * @param requestId 请求标识（用于解锁时校验）
     * @param leaseTime 自动释放时间（秒）
     */
    public boolean tryLock(String key, String requestId, long leaseTime) {
        return Boolean.TRUE.equals(
            redisTemplate.opsForValue().setIfAbsent(
                LOCK_PREFIX + key, requestId, leaseTime, TimeUnit.SECONDS
            )
        );
    }

    /**
     * 释放锁（必须用 Lua 脚本保证原子性）
     */
    private static final String UNLOCK_SCRIPT =
        "if redis.call('get', KEYS[1]) == ARGV[1] then " +
        "    return redis.call('del', KEYS[1]) " +
        "else " +
        "    return 0 " +
        "end";

    public boolean unlock(String key, String requestId) {
        Long result = redisTemplate.execute(
            new DefaultRedisScript<>(UNLOCK_SCRIPT, Long.class),
            Collections.singletonList(LOCK_PREFIX + key),
            requestId
        );
        return Long.valueOf(1).equals(result);
    }
}
```

### 使用示例

```java
@Service
public class OrderService {
    @Autowired
    private RedisLock redisLock;

    public void processOrder(Long orderId) {
        String lockKey = "order:" + orderId;
        String requestId = UUID.randomUUID().toString();

        try {
            if (!redisLock.tryLock(lockKey, requestId, 30)) {
                throw new BusinessException(500, "订单正在处理中，请勿重复操作");
            }
            // 处理订单...
        } finally {
            redisLock.unlock(lockKey, requestId);
        }
    }
}
```

**重要提醒：** 不要用 `setIfAbsent` + 单独 `expire` —— 那不是原子操作。始终用 `set key value NX EX seconds` 一个命令完成。

## 缓存常见问题

### 缓存穿透

**现象：** 查询一个不存在的数据，缓存没有，每次都打到数据库。

**解决：**
1. 缓存空值（上面 `getWithBlank` 方法已实现）
2. 布隆过滤器（大规模场景，提前判断 key 是否存在）

### 缓存击穿

**现象：** 热点 key 过期瞬间，大量请求打到数据库。

**解决：**
```java
public <T> T getWithMutex(String key, Class<T> clazz, long ttl, Supplier<T> loader) {
    T value = get(key, clazz);
    if (value != null) return value;

    // 只有一个线程去加载数据
    String lockKey = "lock:" + key;
    String requestId = UUID.randomUUID().toString();
    try {
        if (redisLock.tryLock(lockKey, requestId, 10)) {
            value = loader.get();
            set(key, value, ttl, TimeUnit.SECONDS);
            return value;
        }
        // 其他线程等待后读取缓存
        Thread.sleep(50);
        return get(key, clazz);
    } catch (InterruptedException e) {
        Thread.currentThread().interrupt();
        return loader.get();
    } finally {
        redisLock.unlock(lockKey, requestId);
    }
}
```

### 缓存雪崩

**现象：** 大量 key 同一时间过期，DB 被打垮。

**解决：**
1. TTL 加随机偏移：`TTL = 基础时间 + Random(0, 300)` 秒
2. 多级缓存（本地缓存 + Redis）
3. 数据库限流降级

---

## 第二部分：RabbitMQ

## 概述

RabbitMQ 是生产环境中最常用的消息队列，适合业务解耦、异步处理、削峰填谷。

**选型对比：**
| 场景 | 推荐 |
|------|------|
| 业务消息（最终一致） | RabbitMQ |
| 大数据量日志 | Kafka |
| 延时消息 | RabbitMQ（DLX）|
| 严格有序 | Kafka（分区内）|

## 集成

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-amqp</artifactId>
</dependency>
```

```yaml
spring:
  rabbitmq:
    host: ${RABBIT_HOST:localhost}
    port: ${RABBIT_PORT:5672}
    username: ${RABBIT_USER:guest}
    password: ${RABBIT_PASSWORD:guest}
    virtual-host: /
    # 生产者确认
    publisher-confirm-type: correlated
    publisher-returns: true
    # 消费者配置
    listener:
      simple:
        acknowledge-mode: manual      # 手动 ACK（生产必选）
        prefetch: 1                   # 一次只拉一条，处理完再拉下一条
        retry:
          enabled: true
          max-attempts: 3
          initial-interval: 1000ms
```

## 可靠消息配置

```java
@Configuration
public class RabbitConfig {
    // ========== 交换机定义 ==========
    @Bean
    public DirectExchange orderExchange() {
        return ExchangeBuilder.directExchange("exchange.order")
                .durable(true)
                .build();
    }

    // ========== 队列定义 ==========
    @Bean
    public Queue orderQueue() {
        return QueueBuilder.durable("queue.order")
                .deadLetterExchange("exchange.dlx")     // 死信交换机
                .deadLetterRoutingKey("order.dead")      // 死信路由键
                .ttl(300000)                              // 消息 TTL 5 分钟
                .maxLength(100000)
                .build();
    }

    // ========== 死信队列 ==========
    @Bean
    public DirectExchange dlxExchange() {
        return ExchangeBuilder.directExchange("exchange.dlx").durable(true).build();
    }

    @Bean
    public Queue deadLetterQueue() {
        return QueueBuilder.durable("queue.order.dead").build();
    }

    @Bean
    public Binding deadLetterBinding() {
        return BindingBuilder.bind(deadLetterQueue())
                .to(dlxExchange())
                .with("order.dead");
    }

    // ========== 绑定关系 ==========
    @Bean
    public Binding orderBinding() {
        return BindingBuilder.bind(orderQueue())
                .to(orderExchange())
                .with("order.create");
    }

    // ========== 消息确认回调 ==========
    @Bean
    public RabbitTemplate rabbitTemplate(ConnectionFactory connectionFactory) {
        RabbitTemplate template = new RabbitTemplate(connectionFactory);
        template.setConfirmCallback((correlationData, ack, cause) -> {
            if (!ack) {
                log.error("消息发送失败: correlation={}, cause={}", correlationData, cause);
                // 落库记录，定时任务补偿
            }
        });
        template.setReturnsCallback(returned -> {
            log.warn("消息路由失败: exchange={}, routingKey={}, reason={}",
                    returned.getExchange(), returned.getRoutingKey(), returned.getReplyText());
        });
        return template;
    }
}
```

## 消息发送

```java
@Service
public class OrderEventPublisher {
    @Autowired
    private RabbitTemplate rabbitTemplate;

    public void publishOrderCreated(Order order) {
        // 发送前先落库（本地消息表）
        EventMessage event = new EventMessage();
        event.setEventType("ORDER_CREATED");
        event.setContent(JSON.toJSONString(order));
        event.setStatus(0);
        eventMessageMapper.insert(event);

        // 发送消息
        CorrelationData correlation = new CorrelationData(event.getId().toString());
        rabbitTemplate.convertAndSend("exchange.order", "order.create", order, correlation);
    }
}
```

## 消息消费

```java
@Component
@Slf4j
public class OrderConsumer {

    @RabbitListener(queues = "queue.order")
    public void handleOrderCreate(Order order, Channel channel, @Header(AmqpHeaders.DELIVERY_TAG) long tag) {
        try {
            log.info("收到订单消息: orderNo={}", order.getOrderNo());
            // 业务处理...

            // 手动 ACK
            channel.basicAck(tag, false);
        } catch (BusinessException e) {
            // 业务异常（比如重复消息，直接确认）
            log.warn("业务异常: {}", e.getMessage());
            channel.basicAck(tag, false);
        } catch (Exception e) {
            log.error("消息处理失败, orderNo={}", order.getOrderNo(), e);
            // requeue=false，不重新入队，进入死信队列
            channel.basicNack(tag, false, false);
        }
    }
}
```

## 踩坑记录

### 1. Redis 大 Key

**现象：** 某个 key 存了 10MB 数据，Redis 阻塞了几秒，所有请求卡住

**原因：** Redis 单线程，操作大 key 会阻塞其他命令

**规范：**
- 单个 string 不超过 10KB
- 单个 hash/set/zset 不超过 1 万个元素
- 如果确实需要存大对象，压缩后存，或者拆成多个小 key

### 2. Redis 连接泄露

**现象：** 运行一段时间后 Redis 报 `Cannot get connection from pool`

**原因：** 忘记归还连接（比如 RedisTemplate 用完后没 close）

**解决：** 确保使用连接池，配置合理参数，不用手动 close——Spring 的 RedisTemplate 会自动管理

### 3. RabbitMQ 消息堆积

**现象：** 消费者处理速度 < 生产者投递速度，队列越来越长

**排查：**
```bash
# 查看队列状态
rabbitmqctl list_queues name messages messages_ready messages_unacknowledged
```

**解决：**
1. 增加消费者数量（水平扩展）
2. 检查消费者是否有慢 SQL 等瓶颈
3. 设置队列最大长度，超出的消息丢弃或进入死信

### 4. 重复消息

**现象：** 数据库里出现了两条相同的订单

**原因：** 生产者重试导致同一消息发了两次

**解决：** 消费端做幂等

```java
// 消费端幂等处理
public void handleMessage(String msgId, Order order) {
    // Redis 判断是否已处理
    Boolean processed = redisTemplate.opsForValue()
            .setIfAbsent("processed:" + msgId, "1", 1, TimeUnit.DAYS);
    if (Boolean.FALSE.equals(processed)) {
        log.info("消息已处理，跳过: {}", msgId);
        return;
    }
    // 处理业务...
}
```
