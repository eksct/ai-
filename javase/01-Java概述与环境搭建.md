# Java 概述与环境搭建

## Java 是什么

Java 是一种面向对象的编程语言，由 Sun Microsystems（现属 Oracle）于 1995 年发布。核心特性：**一次编写，到处运行**（Write Once, Run Anywhere）。

## JVM / JRE / JDK

| 组件 | 说明 |
|------|------|
| **JVM**（Java Virtual Machine） | 运行 Java 字节码的虚拟机，是跨平台的核心 |
| **JRE**（Java Runtime Environment） | JVM + 核心类库，运行 Java 程序所需 |
| **JDK**（Java Development Kit） | JRE + 开发工具（javac, jar, javadoc 等），开发 Java 程序所需 |

```
JDK
 ├── JRE
 │    ├── JVM
 │    └── 核心类库
 └── 开发工具（javac, javadoc, jar...）
```

## Java 程序运行流程

```
源文件 (.java) → javac 编译 → 字节码 (.class) → JVM 运行
```

## JDK 安装

### 下载
- **Oracle JDK**：https://www.oracle.com/java/technologies/downloads/
- **OpenJDK**：https://jdk.java.net/
- **Adoptium**（推荐）：https://adoptium.net/

### 环境变量配置
```
JAVA_HOME = C:\Program Files\Java\jdk-17
PATH = %JAVA_HOME%\bin;%PATH%
```

### 验证安装
```bash
java -version
javac -version
```

## 第一个 Java 程序

```java
public class HelloWorld {
    public static void main(String[] args) {
        System.out.println("Hello, World!");
    }
}
```

```bash
javac HelloWorld.java   # 编译 → 生成 HelloWorld.class
java HelloWorld          # 运行
```

## Java 版本演进

| 版本 | 发布日期 | 重要特性 |
|------|----------|----------|
| Java 8 | 2014.03 | Lambda, Stream, Optional, 新日期 API |
| Java 11 (LTS) | 2018.09 | 标准化 HttpClient, Nest-Based Access Control |
| Java 17 (LTS) | 2021.09 | 密封类, 模式匹配, 记录类 |
| Java 21 (LTS) | 2023.09 | 虚拟线程, 模式匹配 switch, Record Pattern |
| Java 25 (LTS) | 2025.09 | 值对象 (Value Objects), 模块导入, 字符串模板 |

> **生产建议**：使用 LTS 版本（17 / 21 / 25），推荐 Java 25+。

## IDE 推荐

- **IntelliJ IDEA**（首选，社区版免费）
- **Eclipse**（老牌，免费）
- **VS Code** + Java 扩展包（轻量级）
