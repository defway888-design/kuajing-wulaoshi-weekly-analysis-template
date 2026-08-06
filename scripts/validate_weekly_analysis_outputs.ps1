param(
    [Parameter(Mandatory = $true)]
    [string]$OutputDir
)

$ErrorActionPreference = "Stop"

$SummaryPath = Join-Path $OutputDir "负责人汇总表_优先级命名.csv"
$DetailPath = Join-Path $OutputDir "异动明细表_优先级命名.csv"
$DiagnosisIndexPath = Join-Path $OutputDir "高优先级ASIN诊断报告索引.csv"
$Errors = [System.Collections.Generic.List[string]]::new()

function Add-Error([string]$Message) {
    $Errors.Add($Message)
}

function Require-Columns($Rows, [string[]]$Required, [string]$Label) {
    if (@($Rows).Count -eq 0) {
        Add-Error "$Label 没有数据行"
        return
    }
    $Columns = @($Rows[0].PSObject.Properties.Name)
    foreach ($Column in $Required) {
        if ($Columns -notcontains $Column) {
            Add-Error "$Label 缺少字段：$Column"
        }
    }
}

function Convert-Count($Value) {
    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) {
        return 0
    }
    return [int]$Value
}

if (-not (Test-Path -LiteralPath $SummaryPath)) {
    Add-Error "缺少负责人汇总表：$SummaryPath"
}
if (-not (Test-Path -LiteralPath $DetailPath)) {
    Add-Error "缺少异动明细表：$DetailPath"
}

if ($Errors.Count -eq 0) {
    $Summary = @(Import-Csv -LiteralPath $SummaryPath)
    $Details = @(Import-Csv -LiteralPath $DetailPath)

    Require-Columns $Summary @("站点", "店铺", "负责人", "异动商品数", "高优先级异动", "当期高优先异动", "缓慢高优先异动", "待复核异动") "负责人汇总表"
    Require-Columns $Details @("站点", "店铺", "负责人", "父ASIN", "商品名", "异动指标", "当前值", "上月值", "变化率", "异动识别方式", "趋势候选原因", "趋势判断窗口", "历史判断", "待复核原因", "最终状态", "高优先级类型") "异动明细表"

    $SummaryTotal = 0
    foreach ($Row in $Summary) {
        $Total = Convert-Count $Row.'异动商品数'
        $High = Convert-Count $Row.'高优先级异动'
        $HighCurrent = Convert-Count $Row.'当期高优先异动'
        $HighSlow = Convert-Count $Row.'缓慢高优先异动'
        $Review = Convert-Count $Row.'待复核异动'
        $SummaryTotal += $Total
        if ($Total -ne ($High + $Review)) {
            Add-Error "汇总表关系错误：$($Row.'站点') / $($Row.'店铺') / $($Row.'负责人')"
        }
        if ($High -ne ($HighCurrent + $HighSlow)) {
            Add-Error "高优先级拆分关系错误：$($Row.'站点') / $($Row.'店铺') / $($Row.'负责人')"
        }
    }

    if ($SummaryTotal -ne $Details.Count) {
        Add-Error "汇总表异动商品数合计 $SummaryTotal 与明细表行数 $($Details.Count) 不一致"
    }

    $AllowedStatuses = @("高优先级异动", "待复核异动")
    $AllowedDetectionModes = @("单周期异动", "30天双窗口趋势异动", "单周期+30天双窗口趋势异动")
    $AllowedTrendReasons = @("", "流量接近阈值", "转化率接近阈值", "流量+转化率同时接近阈值")
    $AllowedHighPriorityTypes = @("", "当期高优先异动", "缓慢高优先异动")
    foreach ($Row in $Details) {
        if ($AllowedStatuses -notcontains $Row.'最终状态') {
            Add-Error "明细表存在非法最终状态：$($Row.'最终状态')"
        }
        if ($AllowedHighPriorityTypes -notcontains $Row.'高优先级类型') {
            Add-Error "明细表存在非法高优先级类型：$($Row.'高优先级类型')"
        }
        if ($Row.'最终状态' -eq "高优先级异动" -and [string]::IsNullOrWhiteSpace($Row.'高优先级类型')) {
            Add-Error "高优先级异动缺少高优先级类型：$($Row.'父ASIN')"
        }
        if ($Row.'最终状态' -eq "待复核异动" -and -not [string]::IsNullOrWhiteSpace($Row.'高优先级类型')) {
            Add-Error "待复核异动不应填写高优先级类型：$($Row.'父ASIN')"
        }
        if ($AllowedDetectionModes -notcontains $Row.'异动识别方式') {
            Add-Error "明细表存在非法异动识别方式：$($Row.'异动识别方式')"
        }
        if ($AllowedTrendReasons -notcontains $Row.'趋势候选原因') {
            Add-Error "明细表存在非法趋势候选原因：$($Row.'趋势候选原因')"
        }
        if ($Row.'异动识别方式' -eq "30天双窗口趋势异动") {
            if ([string]::IsNullOrWhiteSpace($Row.'趋势候选原因')) {
                Add-Error "30天趋势异动缺少趋势候选原因：$($Row.'父ASIN')"
            }
            if ([string]::IsNullOrWhiteSpace($Row.'趋势判断窗口')) {
                Add-Error "30天趋势异动缺少趋势判断窗口：$($Row.'父ASIN')"
            }
            if ($Row.'最终状态' -ne "高优先级异动" -or $Row.'高优先级类型' -ne "缓慢高优先异动") {
                Add-Error "30天趋势异动必须归入缓慢高优先异动：$($Row.'父ASIN')"
            }
        }
        if ($Row.'异动识别方式' -eq "单周期异动" -and -not [string]::IsNullOrWhiteSpace($Row.'趋势判断窗口')) {
            Add-Error "单周期异动不应填写趋势判断窗口：$($Row.'父ASIN')"
        }
        if ($Row.'异动识别方式' -eq "单周期异动" -and $Row.'最终状态' -eq "高优先级异动" -and $Row.'高优先级类型' -ne "当期高优先异动") {
            Add-Error "单周期高优先异动必须归入当期高优先异动：$($Row.'父ASIN')"
        }
    }

    $HighPriorityDetailCount = @($Details | Where-Object { $_.'最终状态' -eq "高优先级异动" }).Count
    if ($HighPriorityDetailCount -gt 0 -and -not (Test-Path -LiteralPath $DiagnosisIndexPath)) {
        Add-Error "存在高优先级异动，但缺少高优先级ASIN诊断报告索引：$DiagnosisIndexPath"
    }

    if (Test-Path -LiteralPath $DiagnosisIndexPath) {
        $DiagnosisRows = @(Import-Csv -LiteralPath $DiagnosisIndexPath)
        Require-Columns $DiagnosisRows @("站点", "店铺", "负责人", "父ASIN", "商品名", "异动指标", "高优先级类型", "诊断状态", "核心诊断状态", "可发送状态", "报告类型", "摘要页地址", "Word报告地址", "证据缺口类型", "证据缺口说明", "字段映射记录", "失败原因", "阻断原因") "高优先级ASIN诊断报告索引"
        if ($HighPriorityDetailCount -gt 0 -and $DiagnosisRows.Count -lt $HighPriorityDetailCount) {
            Add-Error "高优先级诊断索引行数少于高优先级明细行数"
        }
        $AllowedDiagnosisStatuses = @("已完成", "部分完成", "诊断失败", "未生成")
        $AllowedCoreDiagnosisStatuses = @("完整完成", "可用但有证据缺口", "阻断失败", "未生成")
        $AllowedSendStatuses = @("允许发送", "禁止发送")
        foreach ($Row in $DiagnosisRows) {
            if ($AllowedHighPriorityTypes -notcontains $Row.'高优先级类型' -or [string]::IsNullOrWhiteSpace($Row.'高优先级类型')) {
                Add-Error "诊断索引存在非法高优先级类型：$($Row.'高优先级类型')"
            }
            if ($AllowedDiagnosisStatuses -notcontains $Row.'诊断状态') {
                Add-Error "诊断索引存在非法诊断状态：$($Row.'诊断状态')"
            }
            if ($AllowedCoreDiagnosisStatuses -notcontains $Row.'核心诊断状态') {
                Add-Error "诊断索引存在非法核心诊断状态：$($Row.'核心诊断状态')"
            }
            if ($AllowedSendStatuses -notcontains $Row.'可发送状态') {
                Add-Error "诊断索引存在非法可发送状态：$($Row.'可发送状态')"
            }
            if ($Row.'核心诊断状态' -in @("完整完成", "可用但有证据缺口") -and $Row.'可发送状态' -ne "允许发送") {
                Add-Error "诊断索引发送状态错误：$($Row.'父ASIN') 核心诊断状态为 $($Row.'核心诊断状态') 时应允许发送"
            }
            if ($Row.'核心诊断状态' -in @("阻断失败", "未生成") -and $Row.'可发送状态' -ne "禁止发送") {
                Add-Error "诊断索引发送状态错误：$($Row.'父ASIN') 核心诊断状态为 $($Row.'核心诊断状态') 时应禁止发送"
            }
            if ($Row.'核心诊断状态' -eq "可用但有证据缺口" -and [string]::IsNullOrWhiteSpace($Row.'证据缺口类型')) {
                Add-Error "诊断索引证据缺口状态缺少证据缺口类型：$($Row.'父ASIN')"
            }
            if ($Row.'核心诊断状态' -eq "阻断失败" -and [string]::IsNullOrWhiteSpace($Row.'阻断原因')) {
                Add-Error "诊断索引阻断失败缺少阻断原因：$($Row.'父ASIN')"
            }
            foreach ($PathField in @("摘要页地址", "Word报告地址")) {
                $Property = $Row.PSObject.Properties[$PathField]
                $PathValue = if ($null -eq $Property -or $null -eq $Property.Value) { "" } else { [string]$Property.Value }
                if ($PathValue -match '^[A-Za-z]:\\' -or $PathValue -match '^file:///') {
                    Add-Error "诊断索引链接不能使用本机绝对路径：$PathField=$PathValue"
                }
            }
        }
    }

    $ManagerDashboardPath = Join-Path $OutputDir "manager_dashboard_full_panel.html"
    if (Test-Path -LiteralPath $ManagerDashboardPath) {
        $ManagerHtml = Get-Content -LiteralPath $ManagerDashboardPath -Raw -Encoding UTF8
        foreach ($Forbidden in @("Executive Overview", "Owner Summary", "Risk Split", "Drilldown Table")) {
            if ($ManagerHtml.Contains($Forbidden)) {
                Add-Error "负责人BI包含禁止模块：$Forbidden"
            }
        }
        foreach ($FilterId in @('id="siteFilter"', 'id="storeFilter"', 'id="ownerFilter"')) {
            if (-not $ManagerHtml.Contains($FilterId)) {
                Add-Error "负责人BI缺少筛选器：$FilterId"
            }
        }
        foreach ($ReportFilterId in @('id="reportSiteFilter"', 'id="reportStoreFilter"', 'id="reportOwnerFilter"')) {
            if (-not $ManagerHtml.Contains($ReportFilterId)) {
                Add-Error "负责人BI高优先级ASIN诊断报告入口缺少筛选器：$ReportFilterId"
            }
        }
        foreach ($RequiredModule in @("异动类型占比", "高优先异动分类占比", "待复核异动分类占比", "异动指标 by 类型", "异动商品数 by 站点", "异动商品数 by 店铺", "异动商品数 by 负责人")) {
            if (-not $ManagerHtml.Contains($RequiredModule)) {
                Add-Error "负责人BI缺少指定模块：$RequiredModule"
            }
        }
        if ($ManagerHtml.Contains('id="highSubtypeCard"')) {
            Add-Error "负责人BI顶部高优先级KPI不应显示当期/缓慢子文案"
        }
        if ($ManagerHtml.Contains("BI只展示入口，报告独立打开")) {
            Add-Error "负责人BI包含已禁用提示语：BI只展示入口，报告独立打开"
        }
    }

    $AllOwners = @($Details | Select-Object -ExpandProperty "负责人" -Unique)
    $OwnerDirs = @(Get-ChildItem -LiteralPath $OutputDir -Directory -Filter "owner_*" -ErrorAction SilentlyContinue)
    foreach ($OwnerDir in $OwnerDirs) {
        $OwnerDetail = @(Get-ChildItem -LiteralPath $OwnerDir.FullName -File -Filter "异动明细表_*.csv" | Select-Object -First 1)
        $OwnerDashboard = @(Get-ChildItem -LiteralPath $OwnerDir.FullName -File -Filter "dashboard_powerbi_*.html" | Select-Object -First 1)
        if ($OwnerDetail.Count -eq 0 -or $OwnerDashboard.Count -eq 0) {
            Add-Error "负责人输出目录不完整：$($OwnerDir.FullName)"
            continue
        }

        $OwnerRows = @(Import-Csv -LiteralPath $OwnerDetail[0].FullName)
        $CurrentOwners = @($OwnerRows | Select-Object -ExpandProperty "负责人" -Unique)
        if ($CurrentOwners.Count -ne 1) {
            Add-Error "负责人明细表包含多个负责人：$($OwnerDir.FullName)"
            continue
        }

        $CurrentOwner = $CurrentOwners[0]
        $OwnerHtml = Get-Content -LiteralPath $OwnerDashboard[0].FullName -Raw -Encoding UTF8
        if ($OwnerHtml.Contains("BI只展示入口，报告独立打开")) {
            Add-Error "负责人BI包含已禁用提示语：BI只展示入口，报告独立打开"
        }
        foreach ($OtherOwner in @($AllOwners | Where-Object { $_ -ne $CurrentOwner })) {
            if ($OwnerHtml.Contains('"负责人":"' + $OtherOwner + '"') -or $OwnerHtml.Contains('<option value="' + $OtherOwner + '">')) {
                Add-Error "负责人BI权限泄漏：$CurrentOwner 输出中包含 $OtherOwner"
            }
        }
    }
}

$Result = [PSCustomObject]@{
    validated_at = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    output_dir = $OutputDir
    valid = ($Errors.Count -eq 0)
    errors = @($Errors)
}

$Result | ConvertTo-Json -Depth 5
if ($Errors.Count -gt 0) {
    exit 1
}
