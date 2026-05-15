# REST API 开发

## 概述

生产级的 REST API 开发不只是写几个 `@GetMapping` 和 `@PostMapping`，更重要的是**统一规范**——响应格式统一、异常处理统一、参数校验统一。没有规范的团队，接口千奇百怪，前端对接一次骂一次。

## 统一响应体

### 响应体定义

```java
@Data
@NoArgsConstructor
@AllArgsConstructor
public class ApiResult<T> {
    private int code;
    private String message;
    private T data;
    private long timestamp = System.currentTimeMillis();

    public static <T> ApiResult<T> success(T data) {
        return new ApiResult<>(200, "success", data, System.currentTimeMillis());
    }

    public static <T> ApiResult<T> success() {
        return new ApiResult<>(200, "success", null, System.currentTimeMillis());
    }

    public static <T> ApiResult<T> error(int code, String message) {
        return new ApiResult<>(code, message, null, System.currentTimeMillis());
    }

    public static <T> ApiResult<T> error(ResultCode resultCode) {
        return new ApiResult<>(resultCode.getCode(), resultCode.getMessage(), null, System.currentTimeMillis());
    }
}

// 业务状态码枚举
public enum ResultCode {
    SUCCESS(200, "success"),
    BAD_REQUEST(400, "参数错误"),
    UNAUTHORIZED(401, "未登录"),
    FORBIDDEN(403, "无权限"),
    NOT_FOUND(404, "资源不存在"),
    INTERNAL_ERROR(500, "系统繁忙"),
    BUSINESS_ERROR(1001, "业务异常");

    private final int code;
    private final String message;
}
```

### Controller 示例

```java
@RestController
@RequestMapping("/api/users")
public class UserController {

    @GetMapping("/{id}")
    public ApiResult<UserVO> getUser(@PathVariable Long id) {
        return ApiResult.success(userService.getById(id));
    }

    @PostMapping
    public ApiResult<Long> createUser(@Valid @RequestBody UserCreateReq req) {
        return ApiResult.success(userService.create(req));
    }
}
```

## 全局异常处理

```java
@RestControllerAdvice
public class GlobalExceptionHandler {

    private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    // 参数校验失败
    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ApiResult<Void> handleValidation(MethodArgumentNotValidException e) {
        String msg = e.getBindingResult().getFieldErrors().stream()
                .map(error -> error.getField() + ": " + error.getDefaultMessage())
                .collect(Collectors.joining(", "));
        return ApiResult.error(400, msg);
    }

    // 业务异常
    @ExceptionHandler(BusinessException.class)
    public ApiResult<Void> handleBusiness(BusinessException e) {
        log.warn("业务异常: code={}, msg={}", e.getCode(), e.getMessage());
        return ApiResult.error(e.getCode(), e.getMessage());
    }

    // 参数类型转换异常
    @ExceptionHandler(ConstraintViolationException.class)
    public ApiResult<Void> handleConstraintViolation(ConstraintViolationException e) {
        return ApiResult.error(400, e.getMessage());
    }

    // 404
    @ExceptionHandler(NoHandlerFoundException.class)
    public ApiResult<Void> handleNotFound(NoHandlerFoundException e) {
        return ApiResult.error(404, "接口不存在");
    }

    // 兜底异常（未捕获的都在这里）
    @ExceptionHandler(Exception.class)
    public ApiResult<Void> handleException(Exception e, HttpServletRequest request) {
        log.error("未捕获异常: {} {}", request.getMethod(), request.getRequestURI(), e);
        return ApiResult.error(500, "系统繁忙，请稍后重试");
    }
}

// 业务异常类
@Data
@EqualsAndHashCode(callSuper = true)
public class BusinessException extends RuntimeException {
    private final int code;
    private final String message;

    public BusinessException(ResultCode resultCode) {
        super(resultCode.getMessage());
        this.code = resultCode.getCode();
        this.message = resultCode.getMessage();
    }

    public BusinessException(int code, String message) {
        super(message);
        this.code = code;
        this.message = message;
    }
}
```

## 参数校验

### 请求体校验

```java
@Data
public class UserCreateReq {
    @NotBlank(message = "用户名不能为空")
    @Size(min = 2, max = 32, message = "用户名长度 2-32 位")
    private String username;

    @NotBlank(message = "密码不能为空")
    @Pattern(regexp = "^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d).{8,20}$",
             message = "密码需包含大小写字母和数字，8-20 位")
    private String password;

    @NotNull(message = "年龄不能为空")
    @Min(value = 1, message = "年龄不能小于 1")
    @Max(value = 150, message = "年龄不能大于 150")
    private Integer age;

    @Email(message = "邮箱格式不正确")
    private String email;

    @Pattern(regexp = "^1[3-9]\\d{9}$", message = "手机号格式不正确")
    private String phone;
}
```

### 路径参数和查询参数校验

```java
@RestController
@RequestMapping("/api/users")
@Validated  // 类上必须加这个注解
public class UserController {

    @GetMapping("/{id}")
    public ApiResult<UserVO> getUser(@PathVariable @NotNull Long id) {
        return ApiResult.success(userService.getById(id));
    }

    @GetMapping
    public ApiResult<PageResult<UserVO>> listUsers(
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "20") @Max(100) int size) {
        return ApiResult.success(userService.list(page, size));
    }
}
```

## 分页统一

```java
@Data
public class PageResult<T> {
    private List<T> list;
    private long total;
    private int page;
    private int size;

    public static <T> PageResult<T> of(IPage<T> page) {
        PageResult<T> result = new PageResult<>();
        result.setList(page.getRecords());
        result.setTotal(page.getTotal());
        result.setPage((int) page.getCurrent());
        result.setSize((int) page.getSize());
        return result;
    }
}

// Controller
@GetMapping
public ApiResult<PageResult<UserVO>> listUsers(
        @RequestParam(defaultValue = "1") int page,
        @RequestParam(defaultValue = "20") int size) {
    IPage<User> pageResult = userService.page(new Page<>(page, size));
    return ApiResult.success(PageResult.of(pageResult));
}
```

## API 设计规范

### URL 命名

```
GET    /api/users              # 列表
GET    /api/users/{id}         # 详情
POST   /api/users              # 新增
PUT    /api/users/{id}         # 全量更新
PATCH  /api/users/{id}         # 部分更新
DELETE /api/users/{id}         # 删除

# 嵌套资源
GET    /api/users/{id}/orders  # 用户下的订单
```

### 接口幂等性

```java
@PostMapping("/submit")
public ApiResult<Long> submitOrder(@Valid @RequestBody OrderSubmitReq req) {
    // 前端传入 idempotentKey（唯一标识）
    // 后端用 Redis SET NX 做幂等
    Boolean success = redisTemplate.opsForValue()
        .setIfAbsent("idempotent:" + req.getIdempotentKey(), "1", 1, TimeUnit.HOURS);
    if (Boolean.FALSE.equals(success)) {
        return ApiResult.error(ResultCode.BUSINESS_ERROR, "重复提交");
    }
    // 处理订单...
}
```

## 踩坑记录

### 1. Java 序列化导致的循环引用

```java
// User 引用 Order，Order 引用 User
@Data
public class UserVO {
    private List<OrderVO> orders;   // 序列化时会循环调用
}

@Data
public class OrderVO {
    private UserVO user;
}
```

**现象：** `StackOverflowError`

**解决：**
```java
// 方案一：Jackson 忽略
@JsonIgnoreProperties("orders")  // 在 OrderVO 上忽略 user 的 orders 字段
// 或
@JsonBackReference / @JsonManagedReference
// 或
// 方案二：用 DTO 而不是 VO，手动转换
```

### 2. 大数字精度丢失

```java
// 前端收到: {"id": 20000000000000001} → {"id": 20000000000000000}
```

**原因：** JavaScript 的 Number 只能精确表示 53 位整数，Long 有 64 位

**解决：**
```java
// ID 字段序列化为字符串
@JsonSerialize(using = ToStringSerializer.class)
private Long id;

// 或全局配置
@Bean
public Jackson2ObjectMapperBuilderCustomizer jacksonCustomizer() {
    return builder -> builder.serializerByType(Long.class, ToStringSerializer.instance);
}
```
