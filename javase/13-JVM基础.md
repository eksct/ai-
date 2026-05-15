# JVM 基础

## JVM 内存结构

```
┌─────────────────────────────────────┐
│            Java 堆 (Heap)            │ 线程共享
│  ┌──────┬──────┬─────────────────┐  │
│  │ 新生代 │ 老年代 │                 │  │
│  │ Eden  │      │                 │  │
│  │ S0 S1 │      │                 │  │
│  └──────┴──────┴─────────────────┘  │
├─────────────────────────────────────┤
│        方法区 / Metaspace            │ 线程共享
│  (类信息、常量、静态变量)              │
├─────────────────────────────────────┤
│          虚拟机栈 (VM Stack)          │ 线程私有
│  ┌───────────────────────────────┐  │
│  │ 栈帧 1 │ 栈帧 2 │ ... │ 栈帧 N│  │
│  └───────────────────────────────┘  │
├─────────────────────────────────────┤
│          本地方法栈 (Native Stack)     │ 线程私有
├─────────────────────────────────────┤
│     程序计数器 (PC Register)          │ 线程私有
└─────────────────────────────────────┘
```

### 堆（Heap）

所有线程共享，存放对象实例。

| 区域 | 说明 |
|------|------|
| **Eden** | 新对象分配区域 |
| **Survivor 0 (S0)** | 年轻代回收后存活的对象 |
| **Survivor 1 (S1)** | 同上，S0 和 S1 互为空闲和活跃 |
| **老年代 (Old Gen)** | 长期存活的对象 |

### 方法区（Metaspace，Java 8+）

存储类信息、常量、静态变量、JIT 编译后的代码。

Java 8 之前叫 PermGen（永久代），Java 8 之后改为 Metaspace（使用本地内存）。

### 虚拟机栈（VM Stack）

每个线程创建时分配一个栈，每个方法调用对应一个栈帧：

```
栈帧包含：
  ├── 局部变量表（基本类型、对象引用）
  ├── 操作数栈（字节码指令操作）
  ├── 动态链接（常量池引用）
  └── 方法返回地址
```

## 垃圾回收（GC）

### 判断对象是否存活

**引用计数法：**
- 每个对象维护引用计数器
- 无法解决循环引用（已不常用）

**可达性分析（GC Roots）：**
- 从 GC Roots 对象开始搜索
- 不可达的对象判定为可回收
- GC Roots 包括：栈帧中的引用、静态变量、JNI 引用

### 垃圾回收算法

| 算法 | 说明 | 适用区域 |
|------|------|----------|
| **标记-清除** | 标记存活对象，清除未标记的 | 老年代（有碎片问题） |
| **标记-复制** | 复制存活对象到另一半空间 | 新生代（复制少，效率高） |
| **标记-整理** | 标记存活对象，向一端移动 | 老年代（无碎片） |

### 分代回收

```
新生代（Minor GC / Young GC）        老年代（Major GC / Full GC）
┌─────────────────┐                ┌─────────────────────┐
│ Eden + S0 + S1  │ ──年龄够大──→  │   Old Generation     │
│                 │               │                     │
│ Minor GC 频繁    │               │ Major GC 频率低      │
│ 复制算法         │               │ 标记-整理/标记-清除   │
└─────────────────┘               └─────────────────────┘
```

**对象晋升条件：**
1. 年龄达到阈值（默认 15，可通过 `-XX:MaxTenuringThreshold` 设置）
2. S0/S1 空间不足时提前晋升
3. 大对象直接进入老年代（`-XX:PretenureSizeThreshold`）

### 常用 GC 收集器

| 收集器 | 适用场景 | 特点 |
|--------|----------|------|
| **Serial GC** | 单核、客户端 | 单线程，停顿时间长 |
| **Parallel GC**（默认） | 多核、吞吐量优先 | 多线程并行，适合后台计算 |
| **CMS** | 响应时间优先 | 并发收集，碎片多（Java 9 已弃用） |
| **G1 GC** | 大堆、低延迟 | 分区收集，可预测停顿（Java 9+ 默认） |
| **ZGC** | 超大堆、超低延迟 | 亚毫秒级停顿，JDK 15 正式版 |
| **Shenandoah** | 超低延迟 | 与 ZGC 类似，JDK 12+ |

### JVM 参数

```bash
# 堆内存
-Xms512m          # 初始堆大小
-Xmx2g            # 最大堆大小
-Xmn256m          # 年轻代大小
-XX:MetaspaceSize=128m
-XX:MaxMetaspaceSize=256m

# GC 选择
-XX:+UseG1GC                   # G1 GC
-XX:+UseParallelGC             # Parallel GC
-XX:+UseZGC                    # ZGC（JDK 15+）

# GC 日志
-XX:+PrintGCDetails
-XX:+PrintGCDateStamps
-Xloggc:gc.log
# JDK 9+ 统一日志
-Xlog:gc*:gc.log

# 内存溢出
-XX:+HeapDumpOnOutOfMemoryError
-XX:HeapDumpPath=/path/dump.hprof

# 调优
-XX:MaxGCPauseMillis=200       # G1 目标停顿时间
-XX:ParallelGCThreads=4        # 并行 GC 线程数
-XX:ConcGCThreads=2            # 并发 GC 线程数
```

## 类加载机制

### 类加载过程

```
加载（Loading）→ 验证（Verification）→ 准备（Preparation）→ 解析（Resolution）→ 初始化（Initialization）
                                      ↓
                                  使用 → 卸载
```

### 类加载器

```
Bootstrap ClassLoader（JVM 内置，C++ 实现）
    ↑
Extension ClassLoader（Java 9+：Platform ClassLoader）
    ↑
Application ClassLoader（加载 classpath 下的类）
    ↑
自定义 ClassLoader
```

### 双亲委派模型

> 当一个类加载器收到类加载请求时，先委派给父加载器加载，父加载器无法加载时，子加载器才自己加载。

**为什么？**
- 避免重复加载
- 安全性：核心类库不会被用户自定义类替代

## 编译与执行

```bash
# Java → 字节码
javac Source.java          # 生成 Source.class

# 字节码 → 机器码（JIT 编译）
# 热点代码被 JIT 编译为本地机器码
# 非热点代码由解释器执行

# JIT 编译器
C1（Client Compiler）：快速启动，优化程度低
C2（Server Compiler）：启动慢，优化程度高
分层编译（Java 8+ 默认）：先用 C1，热点代码再用 C2
```

## 常用 JVM 监控工具

```bash
# 命令行
jps              # 查看 Java 进程
jstat -gc pid    # GC 统计
jmap -heap pid   # 堆信息
jmap -dump:file=heap.hprof pid  # dump 堆
jstack pid       # 线程栈
jinfo pid        # JVM 配置

# 图形化
jconsole         # JMX 监控
jvisualvm        # 综合监控（JDK 9+ 需独立下载）
```

## OOM 常见场景

| 异常 | 原因 | 解决 |
|------|------|------|
| `Java heap space` | 堆内存不足 | 增大 -Xmx，检查内存泄漏 |
| `Metaspace` | 类元数据过多 | 增大 MetaspaceSize，检查类加载 |
| `Direct buffer memory` | 直接内存溢出 | NIO 使用不当，调整 -XX:MaxDirectMemorySize |
| `unable to create new native thread` | 线程数超限 | 减少线程数，调整 ulimit |
| `GC overhead limit exceeded` | GC 消耗超过 98% | 增大堆或调优 GC |

## 诊断命令速查

```bash
# 查看运行中的 Java 进程
jps -l

# 查看堆使用
jstat -gc 12345 1000 5    # PID 12345，每秒一次，共 5 次

# 查看线程
jstack 12345 > threads.txt

# dump 堆
jmap -dump:live,format=b,file=heap.hprof 12345

# 分析 dump（使用 jhat 或 Eclipse MAT / VisualVM）
jhat heap.hprof
```
