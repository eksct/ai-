# Lambda 与 Stream

## Lambda 表达式

Lambda 是 Java 8 引入的函数式编程特性，本质是匿名函数的简洁写法。

### 语法

```
(参数列表) -> { 方法体 }
(参数列表) -> 表达式
```

### 基本用法

```java
// 无参数
Runnable r1 = () -> System.out.println("Hello");

// 一个参数
Consumer<String> c1 = s -> System.out.println(s);
Consumer<String> c2 = System.out::println;  // 方法引用

// 多个参数
Comparator<Integer> comp = (a, b) -> a - b;

// 多行语句
BiFunction<Integer, Integer, Integer> calc = (a, b) -> {
    int sum = a + b;
    return sum * 2;
};
```

### 函数式接口

Java 内置的函数式接口（`java.util.function` 包）：

| 接口 | 方法签名 | 说明 |
|------|----------|------|
| `Predicate<T>` | `boolean test(T)` | 判断 |
| `Consumer<T>` | `void accept(T)` | 消费 |
| `Function<T,R>` | `R apply(T)` | 转换 |
| `Supplier<T>` | `T get()` | 提供 |
| `UnaryOperator<T>` | `T apply(T)` | 一元操作 |
| `BinaryOperator<T>` | `T apply(T,T)` | 二元操作 |

```java
// Predicate
Predicate<String> isEmpty = s -> s.isEmpty();
Predicate<String> isNotEmpty = isEmpty.negate();
Predicate<String> shortStr = s -> s.length() < 5;
Predicate<String> all = isNotEmpty.and(shortStr);

// Consumer
Consumer<String> print = System.out::println;
Consumer<String> log = s -> logger.info(s);
Consumer<String> combined = print.andThen(log);

// Function
Function<String, Integer> toLength = String::length;
Function<Integer, String> toStr = Object::toString;
Function<String, String> composed = toLength.andThen(toStr);

// Supplier
Supplier<Double> random = Math::random;
Supplier<User> createUser = User::new;
```

### 方法引用

```java
// 静态方法引用
Function<String, Integer> f1 = Integer::parseInt;

// 实例方法引用（特定对象）
Consumer<String> f2 = System.out::println;

// 实例方法引用（任意对象）
Function<String, String> f3 = String::toUpperCase;

// 构造方法引用
Supplier<User> f4 = User::new;
Function<String, User> f5 = User::new;
```

---

## Stream API

Stream 是对集合操作的高阶抽象，支持链式操作。

### 创建 Stream

```java
// 从集合
list.stream();
list.parallelStream();   // 并行流
set.stream();

// 从数组
Arrays.stream(arr);

// 从值
Stream.of("a", "b", "c");

// 无限流
Stream.generate(Math::random).limit(10);
Stream.iterate(0, n -> n + 1).limit(10);     // 0,1,2,...
Stream.iterate(0, n -> n < 100, n -> n + 1); // Java 9+，带终止条件

// 从文件
Files.lines(Paths.get("test.txt"));

// 从字符串
"hello".chars().mapToObj(c -> (char) c);

// 拼接
Stream.concat(stream1, stream2);

// 空流
Stream.empty();
```

### 中间操作（Intermediate）

中间操作返回新的 Stream，惰性执行。

#### 筛选

```java
// filter：过滤
list.stream()
    .filter(s -> s.startsWith("A"))
    .filter(s -> s.length() > 3);

// distinct：去重（依赖 equals）
list.stream().distinct();

// limit：限制数量
list.stream().limit(5);

// skip：跳过前 N 个
list.stream().skip(10);

// takeWhile / dropWhile（Java 9+）
list.stream().takeWhile(s -> s.length() < 5);   // 直到条件为假
list.stream().dropWhile(s -> s.length() < 5);   // 跳过直到条件为假
```

#### 映射

```java
// map：元素转换
list.stream()
    .map(String::toUpperCase)
    .map(s -> s.length());

// flatMap：展平
List<List<String>> nested = Arrays.asList(
    Arrays.asList("a", "b"),
    Arrays.asList("c", "d")
);
nested.stream()
    .flatMap(Collection::stream)    // ["a", "b", "c", "d"]
    .collect(Collectors.toList());

// 拆分单词
List<String> sentences = Arrays.asList("hello world", "java stream");
sentences.stream()
    .flatMap(s -> Arrays.stream(s.split(" ")))
    .collect(Collectors.toList());   // ["hello", "world", "java", "stream"]
```

#### 排序

```java
// 自然排序
list.stream().sorted();

// 自定义排序
list.stream().sorted((a, b) -> b.compareTo(a));
list.stream().sorted(Comparator.reverseOrder());
list.stream().sorted(Comparator.comparing(String::length));
list.stream().sorted(Comparator.comparing(User::getAge).reversed());
list.stream().sorted(Comparator.comparing(User::getAge).thenComparing(User::getName));
```

#### 窥视

```java
// peek：调试用，不改变元素
list.stream()
    .peek(System.out::println)
    .map(String::toUpperCase)
    .collect(Collectors.toList());
```

### 终端操作（Terminal）

终端操作触发流计算，产生结果或副作用。

#### 收集

```java
// 收集为 List / Set
List<String> list = stream.collect(Collectors.toList());
Set<String> set = stream.collect(Collectors.toSet());

// 收集为指定类型
ArrayList<String> arrayList = stream.collect(Collectors.toCollection(ArrayList::new));
TreeSet<String> treeSet = stream.collect(Collectors.toCollection(TreeSet::new));

// 收集为 Map
Map<Long, User> userMap = users.stream()
    .collect(Collectors.toMap(User::getId, Function.identity()));

// 处理重复 key
Map<String, User> userMap = users.stream()
    .collect(Collectors.toMap(
        User::getName,
        Function.identity(),
        (existing, replacement) -> existing  // 冲突时保留第一个
    ));

// 分组
Map<String, List<User>> byRole = users.stream()
    .collect(Collectors.groupingBy(User::getRole));

// 多级分组
Map<String, Map<Integer, List<User>>> byRoleAndAge = users.stream()
    .collect(Collectors.groupingBy(
        User::getRole,
        Collectors.groupingBy(User::getAge)
    ));

// 分区（true/false 两组）
Map<Boolean, List<User>> adultUsers = users.stream()
    .collect(Collectors.partitioningBy(u -> u.getAge() >= 18));

// 连接字符串
String joined = names.stream()
    .collect(Collectors.joining(", ", "[", "]"));  // [a, b, c]

// 汇总统计
IntSummaryStatistics stat = users.stream()
    .collect(Collectors.summarizingInt(User::getAge));
stat.getAverage();
stat.getMax();
stat.getMin();
stat.getSum();
stat.getCount();
```

#### 归约

```java
// reduce：自定义聚合
Optional<Integer> sum = list.stream().reduce(Integer::sum);
Integer sum2 = list.stream().reduce(0, Integer::sum);  // 有初始值
Optional<String> longest = words.stream()
    .reduce((a, b) -> a.length() >= b.length() ? a : b);

// 内置归约
list.stream().count();
list.stream().anyMatch(s -> s.startsWith("A"));  // 任意匹配
list.stream().allMatch(s -> s.length() > 0);     // 全部匹配
list.stream().noneMatch(s -> s.isEmpty());        // 无匹配
list.stream().findFirst();   // 第一个元素
list.stream().findAny();     // 任意元素（并行流用）
list.stream().min(Comparator.naturalOrder());
list.stream().max(Comparator.naturalOrder());
```

#### 遍历

```java
list.stream().forEach(System.out::println);
// 或直接
list.forEach(System.out::println);
```

### 数值流

```java
int[] numbers = {1, 2, 3, 4, 5};

IntStream intStream = Arrays.stream(numbers);
IntStream.range(0, 100);      // [0, 100)
IntStream.rangeClosed(0, 99); // [0, 99]

// 数值操作（每次需重新创建流，流只能消费一次）
Arrays.stream(numbers).sum();
Arrays.stream(numbers).average();
Arrays.stream(numbers).max();
Arrays.stream(numbers).min();
Arrays.stream(numbers).summaryStatistics();

// 转换
Arrays.stream(numbers).boxed();   // 转 Stream<Integer>

// mapToInt / mapToLong / mapToDouble
int totalAge = users.stream()
    .mapToInt(User::getAge)
    .sum();
```

### Optional（避免 NPE）

```java
// 创建
Optional<String> empty = Optional.empty();
Optional<String> nonNull = Optional.of("hello");    // 不能传 null
Optional<String> nullable = Optional.ofNullable(s); // 可传 null

// 使用
if (nonNull.isPresent()) {
    System.out.println(nonNull.get());
}

nonNull.ifPresent(System.out::println);          // 存在则消费
nonNull.ifPresentOrElse(System.out::println, () -> log.warn("缺失"));

// 默认值
String result = nullable.orElse("default");
String result2 = nullable.orElseGet(() -> fetchDefault());
String result3 = nullable.orElseThrow(() -> new RuntimeException("缺失"));

// 转换
Optional<String> upper = nullable.map(String::toUpperCase);
Optional<Integer> length = nullable.flatMap(s -> Optional.of(s.length()));

// Stream + Optional
String firstMatch = list.stream()
    .filter(s -> s.startsWith("A"))
    .findFirst()
    .orElse("未找到");
```

### 实战示例

```java
// 数据
List<User> users = Arrays.asList(
    new User(1L, "Alice", 25, "admin"),
    new User(2L, "Bob", 17, "user"),
    new User(3L, "Charlie", 30, "admin"),
    new User(4L, "David", 22, "user")
);

// 需求：获取所有管理员中成年人（>=18）的名字，按年龄排序，用逗号连接
String result = users.stream()
    .filter(u -> "admin".equals(u.getRole()))
    .filter(u -> u.getAge() >= 18)
    .sorted(Comparator.comparing(User::getAge))
    .map(User::getName)
    .collect(Collectors.joining(", "));
// → "Alice, Charlie"

// 统计各角色人数
Map<String, Long> roleCount = users.stream()
    .collect(Collectors.groupingBy(User::getRole, Collectors.counting()));

// 平均年龄按角色分组
Map<String, Double> avgAgeByRole = users.stream()
    .collect(Collectors.groupingBy(User::getRole, Collectors.averagingInt(User::getAge)));

// 每个角色下年龄最大的用户
Map<String, Optional<User>> oldestByRole = users.stream()
    .collect(Collectors.groupingBy(User::getRole,
        Collectors.maxBy(Comparator.comparing(User::getAge))));
```
