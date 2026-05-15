# Java 基础语法

## 变量与数据类型

### 基本数据类型（8 种）

| 类型 | 大小 | 范围 | 默认值 |
|------|------|------|--------|
| `byte` | 1 字节 | -128 ~ 127 | 0 |
| `short` | 2 字节 | -32768 ~ 32767 | 0 |
| `int` | 4 字节 | -2^31 ~ 2^31-1 | 0 |
| `long` | 8 字节 | -2^63 ~ 2^63-1 | 0L |
| `float` | 4 字节 | ±3.4E-38 ~ ±3.4E+38 | 0.0f |
| `double` | 8 字节 | ±1.7E-308 ~ ±1.7E+308 | 0.0d |
| `char` | 2 字节 | Unicode 字符 | '\u0000' |
| `boolean` | 不定 | true / false | false |

### 引用数据类型
- 类（class）
- 接口（interface）
- 数组（array）
- 枚举（enum）

### 变量声明

```java
int age = 25;
double price = 99.9;
String name = "Alice";
final double PI = 3.14159;  // 常量
```

### 类型转换

```java
// 自动转换（小→大）
int i = 10;
long l = i;
double d = l;

// 强制转换（大→小，可能丢失精度）
double d = 9.99;
int i = (int) d;  // → 9（精度丢失）

// 自动提升
int a = 3;
double b = 2.5;
double result = a + b;  // int 自动提升为 double
```

## 运算符

### 算术运算符
```java
+  -  *  /  %   ++   --
```

### 比较运算符
```java
==  !=  >  <  >=  <=
```
> **注意**：比较字符串用 `equals()`，不用 `==`

### 逻辑运算符
```java
&&  ||  !      // 短路与、短路或、非
&   |   ^      // 不短路与、不短路或、异或
```

### 位运算符
```java
&  |  ~  ^  <<  >>  >>>
```

### 三元运算符
```java
int max = (a > b) ? a : b;
```

## 控制流程

### if-else
```java
if (score >= 90) {
    System.out.println("优秀");
} else if (score >= 60) {
    System.out.println("及格");
} else {
    System.out.println("不及格");
}
```

### switch
```java
// Java 14+ 支持箭头语法
switch (day) {
    case MONDAY, FRIDAY -> System.out.println("工作日");
    case SATURDAY, SUNDAY -> System.out.println("周末");
    default -> System.out.println("其他");
}

// 作为表达式返回值
String result = switch (day) {
    case MONDAY -> "周一";
    case FRIDAY -> "周五";
    default -> "未知";
};
```

### for 循环
```java
// 普通 for
for (int i = 0; i < 10; i++) {
    System.out.println(i);
}

// 增强 for
int[] arr = {1, 2, 3};
for (int num : arr) {
    System.out.println(num);
}
```

### while / do-while
```java
while (condition) {
    // 先判断后执行
}

do {
    // 先执行后判断（至少执行一次）
} while (condition);
```

### break / continue
```java
break;       // 跳出当前循环
continue;    // 跳过当前迭代，进入下一次
label:       // 带标签的 break/continue
for (...) {
    for (...) {
        break label;  // 跳出外层循环
    }
}
```

## 注释

```java
// 单行注释

/*
 * 多行注释
 */

/**
 * 文档注释（生成 javadoc）
 * @param name 用户名
 * @return 问候语
 */
public String greet(String name) { ... }
```

## 输入输出

```java
// 输出
System.out.println("带换行");
System.out.print("不带换行");
System.out.printf("格式化: %s, %d", name, age);

// 输入（Scanner）
Scanner sc = new Scanner(System.in);
String name = sc.nextLine();
int age = sc.nextInt();
double price = sc.nextDouble();
```

## 包（package）

```java
// 文件顶部声明包
package com.example.myapp;

// 导入
import java.util.List;
import java.util.ArrayList;
import java.util.*;       // 通配符导入
import static java.lang.Math.PI;  // 静态导入
```
