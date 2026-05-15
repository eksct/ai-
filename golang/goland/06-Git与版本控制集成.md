# Git 与版本控制集成

## 概述

GoLand 的 Git 集成可以直接替代命令行 Git 的大部分操作——对 Go 开发者来说，这比切到终端然后输命令的体验好很多。

## 常用 Git 操作

### Commit

```text
快捷键：Ctrl+K
```

面板结构：
```
Commit Changes
├── Unversioned Files（新增文件列表）
├── Changes（已修改文件列表）
├── Commit Message
│   └── 提交信息模板（见下方）
├── Author
└── Options
    ├── ✓ Optimize imports
    ├── ✓ Reformat code
    ├── ✓ Perform code analysis
    └── ✓ Cleanup
```

**Commit 前的三个勾最好都打上：**
- `Reformat code`：自动格式化
- `Optimize imports`：清理未用的 import
- `Perform code analysis`：做一次代码检查，有问题会阻止提交

### 提交信息模板

```
Settings → Version Control → Commit → Commit Message → Templates

添加：
[JIRA-${issue}] ${summary}

# 变更说明：
# - 修改了 xxx
# - 修复了 xxx
```

### Diff 对比

```
快捷键：Ctrl+D（在 Commit 面板中查看改动文件）
```

GoLand 的 Diff 比命令行的更直观：
- 左侧旧代码，右侧新代码
- 绿色：新增行
- 红色：删除行
- 蓝色：修改行
- 可以边审查边直接改（改完回到编辑器）

### Blame 查看

```
右键装订线（行号旁边） → Annotate with Git Blame
```

会显示每一行是谁改的、什么时候改的、commit message 是什么。排查问题的时候靠这个找"是谁写了这行 bug"。

### 分支管理

```
快捷键：Ctrl+Shift+`（反引号）
或底部状态栏的分支名点击
```

```text
分支操作面板：
├── New Branch
├── Checkout
├── Merge
├── Rebase
├── Delete
├── Compare with...
└── Show Branches in Git Log
```

**Rebase vs Merge：** 项目如果规定了 git flow，不要在这里混用，统一团队规范。

## 历史查看

```
Alt+9 打开 Git 面板 → Log 标签
```

功能：
- 按分支/作者/日期过滤
- 右键 commit → Create Patch（生成补丁文件）
- 右键 commit → Cherry-Pick（挑拣提交）
- 右键文件 → Show History（查看单个文件的历史改动）
- **`右键方法 → Git → Show History for Selection`**（看某个函数的改动历史——非常实用）

## Shelve（暂存改动）

```go
// 场景：正在写某个功能，突然要修一个紧急 bug
// 当前改动不想 commit，先搁置

右键 Git 面板中的文件 → Shelve Changes
// 改动被保存，工作区回到干净状态
// 修完 bug 后 Unshelve 恢复
```

比 `git stash` 好在：有界面管理多个 shelve，不会搞混。

## 冲突解决

冲突文件会标红，双击打开冲突解决面板：

```
Merge Revisions
├── Left（你的改动）
├── Middle（最终结果）
└── Right（远程改动）
```

操作：
- `>>` 采用你的
- `<<` 采用远程的
- `X` 都删掉
- 手动编辑中间面板

**原则：** 不要只点 Accept Left/Accept Right，看清楚两边的改动逻辑再合并。很多生产 bug 就是因为冲突时直接覆盖了对方的改动。

## Wails 项目的 Git 注意事项

### 不需要提交的文件

检查 `.gitignore` 确保以下文件不会被提交：

```gitignore
# Wails 生成的绑定文件
wailsjs/

# 构建产物
build/bin/

# 本地配置
.env.local
*.local.yml

# IDE 配置
.idea/
*.iml
```

### wails.json 修改要谨慎

`wails.json` 里包含了构建配置。团队协作时这个文件的改动要互相知会——有人改了构建参数，其他人的环境可能受影响。

```json
{
  "name": "image-app",
  "outputfilename": "image-app",
  "frontend:install": "npm install",
  "frontend:build": "npm run build",
  "frontend:dev:watcher": "npm run dev",
  "wailsjsdir": "./frontend/src/wailsjs",
  "version": "2"
}
```

### 调试信息的 commit

`fmt.Println`、`log.Println` 调试语句 commit 前记得删除。GoLand 的 Code Inspection 会提示"unresolved"但没有专门的检查规则。

可以用 `Before Commit` 勾选 `Perform code analysis` 来拦截。
