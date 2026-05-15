&lt;#
.SYNOPSIS
    新增笔记后审阅并推送到 Git 仓库
.DESCRIPTION
    自动检测新增/变更的笔记文件，显示变更内容确认后，一键提交并推送
.EXAMPLE
    .\push-notes.ps1
    .\push-notes.ps1 -m "添加 Docker 网络笔记"
.PARAMETER m
    提交信息，不指定则自动生成
#&gt;

param(
    [string]$m = ""
)

$ErrorActionPreference = "Continue"

function Write-Step {
    param([string]$msg, [string]$color = "Cyan")
    Write-Host "`n==> $msg" -ForegroundColor $color
}

function Confirm-Action {
    param([string]$prompt)
    return (Read-Host "$prompt (y/n)").ToLower() -eq "y"
}

# ============================================================
# Step 1: 检测变更
# ============================================================
Write-Step "Step 1: 检测工作区状态..."

$status = git status --porcelain
if (-not $status) {
    Write-Host "✅ 工作区干净，没有变更需要提交。" -ForegroundColor Green
    exit 0
}

Write-Host "`n以下文件有变更：" -ForegroundColor Yellow
Write-Host "------------------------"
git status --short
Write-Host "------------------------"

# ============================================================
# Step 2: 审阅（显示 diff 摘要）
# ============================================================
Write-Step "Step 2: 审阅变更内容..."

$diff = git diff --stat
if ($diff) {
    Write-Host $diff
}

# 检查新增的 .md 文件是否存在明显的格式问题
$newFiles = git ls-files --others --exclude-standard -- '*.md'
foreach ($file in $newFiles) {
    if (-not (Test-Path $file)) { continue }

    $content = Get-Content $file -Raw

    # 检查是否有标题
    if ($content -notmatch "^# ") {
        Write-Host "⚠️  警告: $file 缺少一级标题 (#)" -ForegroundColor Yellow
    }
}

# ============================================================
# Step 3: 确认并提交
# ============================================================
if (-not (Confirm-Action "`n确认提交以上变更？")) {
    Write-Host "已取消。" -ForegroundColor Red
    exit 0
}

Write-Step "Step 3: 提交变更..."

# 构建提交信息
if (-not $m) {
    $added = (git diff --cached --name-only; git ls-files --others --exclude-standard) |
        Where-Object { $_ -match '\.md$' } |
        ForEach-Object {
            $parts = $_ -split '[\\/]'
            $name = $parts[-1] -replace '\.md$', ''
            $name -replace '^\d+-', ''
        } | Select-Object -First 3

    if ($added) {
        $m = "Add notes: $($added -join ', ')"
    } else {
        $m = "Update notes"
    }
}

git add -A
git commit -m $m

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ 提交失败。" -ForegroundColor Red
    exit 1
}

# ============================================================
# Step 4: 推送到远程
# ============================================================
Write-Step "Step 4: 推送到远程仓库..."

if (Confirm-Action "推送到远程仓库？") {
    git push
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n✅ 已完成！" -ForegroundColor Green
        Write-Host "   提交: $m" -ForegroundColor Green
    } else {
        Write-Host "❌ 推送失败，请检查网络或认证。" -ForegroundColor Red
    }
} else {
    Write-Host "已跳过推送。下次手动执行 git push 即可。" -ForegroundColor Yellow
}
