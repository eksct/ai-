# Nginx 跨域场景分析

## 概述

跨域是浏览器的安全策略，不是服务器的限制。Nginx 不能"解决"跨域，但它能把前后端收拢到同一入口，让跨域根本不需要出现。

## 同源条件

协议 + 域名 + 端口三者完全一致，才算同源。

```javascript
// 以下都是跨域：
http://a.com → https://a.com      // 协议不同
http://a.com → http://b.com       // 域名不同
http://a.com:80 → http://a.com:8080 // 端口不同
```

## Nginx 能解决的场景

前后端共享 Nginx 统一入口，浏览器看到的是同一个地址：

```
浏览器 → Nginx http://example.com:80
          ├ /          → 前端静态文件
          └ /api/*     → 反代到后端服务器

浏览器眼里：所有请求都是 http://example.com:80 → 同源 ✓
```

前端代码里 API 地址写**相对路径** `/api/users`，不要写绝对路径。

## Nginx 解决不了的场景

### 场景 1：前后端不同域名

```
前端 http://example.com
后端 https://api.example.com
→ 域名不同 → 跨域 ✗ → 需要后端配 CORS
```

### 场景 2：前端直连后端的 IP/端口

```
前端 http://example.com  (Nginx)
JS 调 http://192.168.1.10:8080/api  (后端裸 IP)
→ 不同源 → 跨域 ✗ → 重构成统一入口或后端配 CORS
```

### 场景 3：调用第三方 API

```
前端 http://example.com
调 https://stripe.com/api
→ 完全不同的域名 → 跨域 ✗ → 要么第三方配 CORS，要么 Nginx 自己做个中转
```

第三方不支持 CORS 时，可以在 Nginx 自己中转：

```nginx
location /stripe/ {
    proxy_pass https://stripe.com/api/;
    # 浏览器调 /stripe/xxx 实际上打的是 example.com，不跨域
}
```

## 关键结论

```
Nginx 统一入口 → 跨域不出现            ← 正确做法
Nginx 加 CORS 头 → 不推荐              ← 后端代码该做的事

跨域是浏览器对 发起方 和 目标方 的判断
Nginx 管不到 JS 从哪个页面发起请求
它只能让自己成为那个"目标方"
```

## 参考

[[Nginx 基础]]
[[正向代理与反向代理]]
