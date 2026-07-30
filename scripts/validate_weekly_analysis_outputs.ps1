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

if (-not (Test-Path -LiteralPath $SummaryPath)) {
    Add-Error "缺少负责人汇总表：$SummaryPath"
}
if (-not (Test-Path -LiteralPath $DetailPath)) {
    Add-Error "缺少异动明细表：$DetailPath"
}

if ($Errors.Count -eq 0) {
    $Summary = @(Import-Csv -LiteralPath $SummaryPath)
    $Details = @(Import-Csv -LiteralPath $DetailPath)

    Require-Columns $Summary @("站点", "店铺", "负责人", "异动商品数", "高优先级异动", "待复核异动") "负责人汇总表"
    Require-Columns $Details @("站点", "店铺", "负责人", "父ASIN", "商品名", "异动指标", "当前值", "上月值", "变化率", "异动识别方式", "趋势候选原因", "趋势判断窗口", "历史判断", "待复核原因", "最终状态") "异动明细表"

    $SummaryTotal = 0
    foreach ($Row in $Summary) {
        $Total = [int]$Row.'异动商品数'
        $High = [int]$Row.'高优先级异动'
        $Review = [int]$Row.'待复核异动'
        $SummaryTotal += $Total
        if ($Total -ne ($High + $Review)) {
            Add-Error "汇总表关系错误：$($Row.'站点') / $($Row.'店铺') / $($Row.'负责人')"
        }
    }

    if ($SummaryTotal -ne $Details.Count) {
        Add-Error "汇总表异动商品数合计 $SummaryTotal 与明细表行数 $($Details.Count) 不一致"
    }

    $AllowedStatuses = @("高优先级异动", "待复核异动")
    $AllowedDetectionModes = @("单周期异动", "30天双窗口趋势异动", "单周期+30天双窗口趋势异动")
    $AllowedTrendReasons = @("", "流量接近阈值", "转化率接近阈值", "流量+转化率同时接近阈值")
    foreach ($Row in $Details) {
        if ($AllowedStatuses -notcontains $Row.'最终状态') {
            Add-Error "明细表存在非法最终状态：$($Row.'最终状态')"
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
        }
        if ($Row.'异动识别方式' -eq "单周期异动" -and -not [string]::IsNullOrWhiteSpace($Row.'趋势判断窗口')) {
            Add-Error "单周期异动不应填写趋势判断窗口：$($Row.'父ASIN')"
        }
    }

    if (Test-Path -LiteralPath $DiagnosisIndexPath) {
        $DiagnosisRows = @(Import-Csv -LiteralPath $DiagnosisIndexPath)
        Require-Columns $DiagnosisRows @("站点", "店铺", "负责人", "父ASIN", "商品名", "异动指标", "诊断状态", "报告类型", "摘要页地址", "Word报告地址", "失败原因") "高优先级ASIN诊断报告索引"
        $AllowedDiagnosisStatuses = @("已完成", "部分完成", "诊断失败", "未生成")
        foreach ($Row in $DiagnosisRows) {
            if ($AllowedDiagnosisStatuses -notcontains $Row.'诊断状态') {
                Add-Error "诊断索引存在非法诊断状态：$($Row.'诊断状态')"
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
