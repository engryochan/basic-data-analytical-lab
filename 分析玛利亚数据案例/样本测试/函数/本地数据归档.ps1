# ==============================================================================
# 本地数据归档.ps1
# ==============================================================================
# 用途：把基于旧版10万行样本(每张表各自独立LIMIT导出、时间窗口不对齐)的
# 本地数据文件夹，改名归档到"已废弃"目录，并为即将下载的新版候选名单
# 数据(基于1.74亿行全量、132,982人候选名单)预建干净的新文件夹，
# 确保新旧数据物理隔离，不会被同名路径互相覆盖或读串。
#
# 使用方法：
#   1. 打开PowerShell，cd到您项目根目录(basic-data-analytical-lab那一层)
#   2. 执行：.\本地数据归档.ps1
#   3. 脚本只做"改名"和"建新文件夹"，不删除任何真实数据，可以放心跑
# ==============================================================================

$归档时间戳 = Get-Date -Format "yyyyMMdd_HHmm"

Write-Host "=== 第一步：归档旧版10万行样本原始数据 ===" -ForegroundColor Cyan

# 原始129张CSV（每张表各自独立LIMIT导出，member与bet01等表时间窗口不对齐）
if (Test-Path "数据库") {
    Rename-Item -Path "数据库" -NewName "数据库_旧版10万行样本_已废弃_$归档时间戳"
    Write-Host "✅ 数据库/ 已改名归档" -ForegroundColor Green
} else {
    Write-Host "⚠️ 未找到 数据库/ 文件夹，跳过（可能已经归档过，或路径不在当前目录）" -ForegroundColor Yellow
}

# 正名后的129张表（基于上面那批有问题的原始数据翻译而来，一并归档）
if (Test-Path "数据库_已正名") {
    Rename-Item -Path "数据库_已正名" -NewName "数据库_已正名_旧版10万行样本_已废弃_$归档时间戳"
    Write-Host "✅ 数据库_已正名/ 已改名归档" -ForegroundColor Green
} else {
    Write-Host "⚠️ 未找到 数据库_已正名/ 文件夹，跳过" -ForegroundColor Yellow
}

Write-Host "`n=== 第二步：归档基于旧样本算出的分析产出文件 ===" -ForegroundColor Cyan

$旧产出文件夹 = "历史诊断_10万行样本"
New-Item -ItemType Directory -Path $旧产出文件夹 -Force | Out-Null

$待归档文件 = @(
    "129表分类目录.csv",
    "129表_最终纳入判定.csv",
    "joinability_scan.csv",
    "风控主表_最大维度版.csv",
    "analysis_core.py",
    "荷官玩家风控.qmd",
    "risk_analysis_report.qmd",
    "风控三项筛选.R",
    "风控三项筛选_Superset生产环境SQL模板.sql"
)

foreach ($文件 in $待归档文件) {
    if (Test-Path $文件) {
        Move-Item -Path $文件 -Destination $旧产出文件夹 -Force
        Write-Host "✅ $文件 → $旧产出文件夹/" -ForegroundColor Green
    } else {
        Write-Host "⚠️ 未找到 $文件，跳过" -ForegroundColor Yellow
    }
}

Write-Host "`n=== 第三步：为新版全局候选名单数据预建干净文件夹 ===" -ForegroundColor Cyan

New-Item -ItemType Directory -Path "数据库_v2_候选名单版" -Force | Out-Null
Write-Host "✅ 已创建 数据库_v2_候选名单版/ —— 后续下载的候选人特征表等新数据，请统一放进这个文件夹" -ForegroundColor Green

New-Item -ItemType Directory -Path "历史迭代_SQL脚本" -Force | Out-Null
Write-Host "✅ 已创建 历史迭代_SQL脚本/ —— 建议把之前反复调试过程中产生的各版SQL文件(带_修正版/_只读版这类后缀的)手动挪进这个文件夹留档" -ForegroundColor Green

Write-Host "`n=== 归档完成 ===" -ForegroundColor Cyan
Write-Host "当前目录结构：" -ForegroundColor Cyan
Get-ChildItem -Directory | Select-Object Name | Format-Table -AutoSize
