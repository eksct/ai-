# Nginx Gzip 压缩

## 概述

Nginx 将响应内容压缩后再发回客户端，浏览器解压后正常渲染。核心目的：减少传输体积，加快页面加载。

## 基础配置

```nginx
gzip on;
gzip_types text/plain text/css application/javascript application/json image/svg+xml;
gzip_min_length 1000;           # 小于 1KB 不压，太小的文件压缩反而更大
gzip_vary on;                   # 加 Vary: Accept-Encoding 头
gzip_proxied any;               # 对代理请求也压缩
gzip_comp_level 3;              # 压缩等级 1-9，默认 1
```

## 各指令详解

| 指令 | 默认 | 说明 |
|------|------|------|
| `gzip on/off` | off | 总开关 |
| `gzip_types` | text/html （默认只有 HTML） | 哪些 MIME 类型要压缩。JS、CSS、JSON、SVG 都要手动加 |
| `gzip_min_length` | 20 | 小于此值的响应不压缩 |
| `gzip_comp_level` | 1 | 1-9，越高压缩率越大但越费 CPU。3 是性价比拐点 |
| `gzip_vary` | off | 加 Vary 头，让 CDN 正确处理压缩 |
| `gzip_proxied` | off | 对代理请求的处理方式，生产建议 `any` |
| `gzip_disable` | — | 禁用某些 User-Agent，如 `"msie6"` |

## 压缩效果

| 类型 | 原始 | 压缩后 | 节省 |
|------|------|--------|------|
| HTML | 100KB | ~25KB | 75% |
| CSS | 50KB | ~10KB | 80% |
| JS | 200KB | ~60KB | 70% |
| JSON API 返回 | 500KB | ~80KB | 84% |
| PNG/JPEG | 不压缩 | — | 无效果，且更慢 |

## 调优建议

```nginx
gzip on;
gzip_comp_level 3;                    # 1-3 够用，5+ 收益递减
gzip_min_length 1000;                 # 小文件不压缩
gzip_types text/plain text/css application/javascript application/json application/xml text/xml image/svg+xml;
gzip_vary on;
gzip_proxied any;
gzip_disable "msie6";                 # IE6 不支持 gzip
```

压缩等级不建议超过 3——4 级以上 CPU 消耗翻倍，压缩率提升不到 5%。

## 参考

[[Nginx 基础]]
[[Nginx 生产踩坑与必配项]]
