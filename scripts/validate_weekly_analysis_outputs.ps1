param(
    [Parameter(Mandatory = $true)]
    [string]$OutputDir
)

$ErrorActionPreference = "Stop"

$SummaryPath = Join-Path $OutputDir "负责人汇总表_优先级命名.csv"
$DetailPath = Join-Path $OutputDir "异动明细表_优先级命名.csv"
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
    Require-Columns $Details @("站点", "店铺", "负责人", "父ASIN", "商品名", "异动指标", "当前值", "上月值", "变化率", "历史判断", "最终状态") "异动明细表"

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
    foreach ($Row in $Details) {
        if ($AllowedStatuses -notcontains $Row.'最终状态') {
            Add-Error "明细表存在非法最终状态：$($Row.'最终状态')"
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
