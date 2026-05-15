# 反射与 unsafe

## 概述

反射让你在运行时检查类型信息和操作对象。Go 的反射基于 `reflect` 包，但和 Java 不一样——Go 的反射很慢而且容易写出 bug。

**原则：** 能用具体类型解决的问题不要用反射。

## reflect 包

```go
import "reflect"
```

### 检查类型

```go
var x float64 = 3.14

t := reflect.TypeOf(x)
fmt.Println(t.Name())       // "float64"
fmt.Println(t.Kind())       // Float64
fmt.Println(t.Size())       // 8

v := reflect.ValueOf(x)
fmt.Println(v.Float())      // 3.14
```

### 修改值

```go
var x float64 = 3.14

v := reflect.ValueOf(&x)    // 传指针才能修改
v.Elem().SetFloat(2.71)
fmt.Println(x)              // 2.71
```

### 读取结构体字段

```go
type User struct {
    Name string `json:"name" validate:"required"`
    Age  int    `json:"age" validate:"min=0"`
}

u := User{"Alice", 25}
t := reflect.TypeOf(u)

for i := 0; i < t.NumField(); i++ {
    field := t.Field(i)
    fmt.Printf("字段: %s, 类型: %s, json: %s\n",
        field.Name,
        field.Type,
        field.Tag.Get("json"),
    )
}
```

### 调用方法

```go
type MyMath struct{}

func (m MyMath) Add(a, b int) int { return a + b }

m := MyMath{}
v := reflect.ValueOf(m)
method := v.MethodByName("Add")

args := []reflect.Value{
    reflect.ValueOf(3),
    reflect.ValueOf(4),
}
result := method.Call(args)
fmt.Println(result[0].Int())  // 7
```

## 常见用途

### 1. 结构体标签解析

```go
func ValidateStruct(s interface{}) error {
    t := reflect.TypeOf(s)
    v := reflect.ValueOf(s)

    for i := 0; i < t.NumField(); i++ {
        field := t.Field(i)
        value := v.Field(i)

        tag := field.Tag.Get("validate")
        if tag == "required" && value.IsZero() {
            return fmt.Errorf("field %s is required", field.Name)
        }
    }
    return nil
}
```

### 2. 通用序列化

```go
func StructToMap(s interface{}) map[string]interface{} {
    result := make(map[string]interface{})
    v := reflect.ValueOf(s)
    t := v.Type()

    for i := 0; i < t.NumField(); i++ {
        field := t.Field(i)
        key := field.Tag.Get("json")
        if key == "" {
            key = field.Name
        }
        result[key] = v.Field(i).Interface()
    }
    return result
}
```

### 3. 自动生成 SQL

```go
func BuildInsertSQL(s interface{}) string {
    t := reflect.TypeOf(s)
    v := reflect.ValueOf(s)

    tableName := strings.ToLower(t.Name())
    var columns []string
    var values []string

    for i := 0; i < t.NumField(); i++ {
        field := t.Field(i)
        col := field.Tag.Get("db")
        if col == "" {
            col = strings.ToLower(field.Name)
        }
        columns = append(columns, col)
        values = append(values, fmt.Sprintf("'%v'", v.Field(i).Interface()))
    }

    return fmt.Sprintf("INSERT INTO %s (%s) VALUES (%s)",
        tableName,
        strings.Join(columns, ", "),
        strings.Join(values, ", "),
    )
}
```

## 什么时候不用反射

```go
// ❌ 不要用反射代替接口
// ❌ 不要用反射代替类型断言
// ❌ 不要在性能敏感路径用反射

// ✅ 需要用就用 encoding/json——它是用反射实现的
// ✅ 序列化框架（JSON/YAML）——这个必须用反射
// ✅ 自动测试工具
// ✅ 依赖注入框架
```

## unsafe 包

```go
import "unsafe"

// unsafe.Pointer 可以绕过类型系统
var f float64 = 3.14
i := *(*int64)(unsafe.Pointer(&f))
fmt.Println(i)  // 打印 float64 的二进制表示

// 获取结构体字段偏移
type S struct {
    A int32
    B int64
}
s := S{}
offset := unsafe.Offsetof(s.B)
```

**生产原则：** `unsafe` 包名已经说明了一切。只在极端性能优化或底层系统编程中使用。99% 的 Go 开发者开发了 10 年都没用过 unsafe。
