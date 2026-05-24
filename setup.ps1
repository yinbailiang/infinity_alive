<#
.SYNOPSIS
    自动拉取 infinity_build 工具链并构建项目
.DESCRIPTION
    1. 克隆/更新 infinity_build 构建工具
    2. 使用 buildconfig.json 构建项目
.PARAMETER BuildConfig
    构建配置文件路径，默认为 buildconfig.json
.PARAMETER Mode
    构建模式：Debug（默认）或 Release
.PARAMETER SkipPull
    跳过拉取 infinity_build 步骤
#>
param(
    [Parameter(Mandatory = $false)]
    [string]$BuildConfig = "buildconfig.json",

    [Parameter(Mandatory = $false)]
    [ValidateSet("Debug", "Release")]
    [string]$Mode = "Debug",

    [Parameter(Mandatory = $false)]
    [switch]$SkipPull
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

$InfinityBuildRepo = "https://github.com/yinbailiang/infinity_build.git"
$InfinityBuildDir = Join-Path $ScriptDir "infinity_build"

# ============================================================
# Step 1: 拉取/更新 infinity_build
# ============================================================
if (-not $SkipPull) {
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  Step 1/2: 拉取 infinity_build 工具链" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan

    if (Test-Path $InfinityBuildDir) {
        Write-Host "[INFO] infinity_build 目录已存在，执行 git pull..." -ForegroundColor Yellow
        Push-Location $InfinityBuildDir
        try {
            git pull origin main 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) {
                # 可能 main 分支不存在，尝试 master
                git pull origin master 2>&1 | Out-Null
            }
            Write-Host "[OK] infinity_build 已更新到最新版本" -ForegroundColor Green
        }
        catch {
            Write-Warning "git pull 失败: $_ ，尝试使用当前版本继续..."
        }
        finally {
            Pop-Location
        }
    }
    else {
        Write-Host "[INFO] 正在克隆 infinity_build..." -ForegroundColor Yellow
        git clone $InfinityBuildRepo $InfinityBuildDir 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[OK] infinity_build 克隆成功" -ForegroundColor Green
        }
        else {
            Write-Error "克隆 infinity_build 失败，请检查网络连接和仓库地址"
            exit 1
        }
    }
}
else {
    Write-Host "[SKIP] 跳过拉取 infinity_build" -ForegroundColor DarkGray
}

# ============================================================
# Step 2: 构建项目
# ============================================================
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Step 2/2: 构建项目" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$BuilderScript = Join-Path $InfinityBuildDir "infinity_build.ps1"
if (-not (Test-Path $BuilderScript)) {
    Write-Error "未找到构建脚本: $BuilderScript"
    exit 2
}

# 如果指定了 Release 模式，通过 ExtraConfig 覆盖
$ExtraConfig = @{}
if ($Mode -eq "Release") {
    $ExtraConfig["System"] = @{ Mode = "Release" }
}

Write-Host "[INFO] 构建配置: $BuildConfig" -ForegroundColor Yellow
Write-Host "[INFO] 构建模式: $Mode" -ForegroundColor Yellow

if ($ExtraConfig.Count -gt 0) {
    & $BuilderScript -ConfigPath $BuildConfig -ExtraConfig $ExtraConfig
}
else {
    & $BuilderScript -ConfigPath $BuildConfig
}

if ($LASTEXITCODE -eq 0) {
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  构建完成！" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
}
else {
    Write-Error "构建失败，退出码: $LASTEXITCODE"
    exit $LASTEXITCODE
}
