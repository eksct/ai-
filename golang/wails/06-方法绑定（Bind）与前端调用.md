# 06 方法绑定（Bind）与前端调用

`Bind` 是 Wails 最核心的能力之一：它决定前端能调用哪些 Go 方法。

关键点：

- Wails 会检查 `Bind` 里列出的**结构体实例**，把它们的**导出方法（大写开头）**生成对应的 JS/TS 调用封装
- 开发模式（`wails dev`）或执行 `wails generate module` 会生成前端可用的模块

生成内容通常包括：

- 所有绑定方法的 JavaScript 封装
- 所有绑定方法的 TypeScript 声明
- 绑定方法入参/出参涉及的 Go struct 对应的 TS 类型（`models`）

## 6.1 `wailsjs` 生成目录

运行 `wails dev` 后，常见生成目录：

```text
wailsjs/
  └─go/
    └─main/
      ├─App.d.ts
      └─App.js
```

## 6.2 前端调用示例

```js
import { Greet } from "../wailsjs/go/main/App";

function doGreeting(name) {
  Greet(name).then((result) => {
    // Do something with result
  });
}
```

对应的 TS 声明示例：

```ts
export function Greet(arg1: string): Promise<string>;
```

调用成功时：Go 的返回值会传递给 `resolve`；失败时：错误会通过 `reject` 传回（传递无效参数也可能触发错误）。

## 6.3 结构体类型映射（models）

如果绑定方法使用了 Go 结构体作为入参/出参，Wails 会生成 `models` 类型声明。

示例（`App.d.ts` 可能变为）：

```ts
import { main } from "../models";
export function Greet(arg1: main.Person): Promise<string>;
```

前端创建结构体并调用：

```ts
import { Greet } from "../wailsjs/go/main/App";
import { main } from "../wailsjs/go/models";

function generate() {
  const person = new main.Person();
  person.name = "Peter";
  person.age = 27;
  Greet(person).then((result) => {
    console.log(result);
  });
}
```

注意点：

- 结构体字段需要有效的 `json` tag，才能正确生成 TS 类型
- 目前不支持嵌套匿名结构体（以官方文档为准）
