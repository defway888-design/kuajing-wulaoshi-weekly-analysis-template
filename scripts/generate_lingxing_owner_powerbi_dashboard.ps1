param(
    [Parameter(Mandatory = $true)]
    [string]$OwnerName,
    [string]$OutputDir
)

$ErrorActionPreference = "Stop"

$ScriptDir = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($ScriptDir)) {
    $ScriptDir = Join-Path (Get-Location) "scripts"
}
$Root = Resolve-Path (Join-Path $ScriptDir "..")
$OutDir = if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    Join-Path $Root "runtime_output"
} else {
    $OutputDir
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$SummaryPath = Join-Path $OutDir "负责人汇总表_优先级命名.csv"
$DetailPath = Join-Path $OutDir "异动明细表_优先级命名.csv"
$DiagnosisIndexPath = Join-Path $OutDir "高优先级ASIN诊断报告索引.csv"
$TemplatePath = Join-Path $OutDir "dashboard_powerbi.html"

if (-not (Test-Path -LiteralPath $SummaryPath)) { throw "缺少负责人汇总表：$SummaryPath" }
if (-not (Test-Path -LiteralPath $DetailPath)) { throw "缺少异动明细表：$DetailPath" }
$TemplateNeedsRefresh = -not (Test-Path -LiteralPath $TemplatePath)
if (-not $TemplateNeedsRefresh) {
    $ExistingTemplate = Get-Content -LiteralPath $TemplatePath -Raw -Encoding UTF8
    $TemplateNeedsRefresh = -not $ExistingTemplate.Contains("const diagnosisReports =")
}
if ($TemplateNeedsRefresh) {
    $RendererCode = Get-Content -LiteralPath (Join-Path $ScriptDir "generate_lingxing_powerbi_style_dashboard.ps1") -Raw -Encoding UTF8
    $Renderer = [ScriptBlock]::Create($RendererCode)
    & $Renderer -OutputDir $OutDir | Out-Null
    Copy-Item -LiteralPath (Join-Path $OutDir "anomaly_detail_dashboard_powerbi.html") -Destination $TemplatePath -Force
}

function HtmlEscape([string]$Value) {
    if ($null -eq $Value) { return "" }
    return $Value.Replace("&", "&amp;").Replace("<", "&lt;").Replace(">", "&gt;").Replace('"', "&quot;")
}

function SafeFileName([string]$Value) {
    $invalid = [System.IO.Path]::GetInvalidFileNameChars()
    $chars = $Value.ToCharArray() | ForEach-Object {
        if ($invalid -contains $_) { "_" } else { $_ }
    }
    return -join $chars
}

function Get-FieldValue($Row, [string[]]$Names) {
    foreach ($Name in $Names) {
        $Property = $Row.PSObject.Properties[$Name]
        if ($null -ne $Property -and $null -ne $Property.Value) {
            return [string]$Property.Value
        }
    }
    return ""
}

function Get-DiagnosisReportType([string]$MetricType) {
    switch ($MetricType) {
        "流量异动" { return "流量诊断" }
        "转化率异动" { return "转化率诊断" }
        "流量+转化率异动" { return "流量+转化率综合诊断" }
        default { return "待确认诊断类型" }
    }
}

$Summary = @(Import-Csv -LiteralPath $SummaryPath | Where-Object { $_.'负责人' -eq $OwnerName })
$Details = @(Import-Csv -LiteralPath $DetailPath | Where-Object { $_.'负责人' -eq $OwnerName })

if ($Summary.Count -eq 0 -or $Details.Count -eq 0) {
    throw "未找到负责人数据：$OwnerName"
}

if (Test-Path -LiteralPath $DiagnosisIndexPath) {
    $DiagnosisRows = @(Import-Csv -LiteralPath $DiagnosisIndexPath | Where-Object {
        (Get-FieldValue $_ @("负责人", "owner", "owner_name")) -eq $OwnerName
    } | ForEach-Object {
        [PSCustomObject]@{
            "站点" = Get-FieldValue $_ @("站点", "site")
            "店铺" = Get-FieldValue $_ @("店铺", "store")
            "负责人" = Get-FieldValue $_ @("负责人", "owner", "owner_name")
            "父ASIN" = Get-FieldValue $_ @("父ASIN", "parent_asin", "asin")
            "商品名" = Get-FieldValue $_ @("商品名", "product_name")
            "异动指标" = Get-FieldValue $_ @("异动指标", "metric_type")
            "诊断状态" = Get-FieldValue $_ @("诊断状态", "diagnosis_status")
            "报告类型" = Get-FieldValue $_ @("报告类型", "report_type")
            "摘要页地址" = Get-FieldValue $_ @("摘要页地址", "summary_page_path", "summary_url", "报告地址")
            "Word报告地址" = Get-FieldValue $_ @("Word报告地址", "word_report_path", "docx_path")
            "失败原因" = Get-FieldValue $_ @("失败原因", "failure_reason")
        }
    })
} else {
    $DiagnosisRows = @($Details | Where-Object { $_.'最终状态' -eq "高优先级异动" } | ForEach-Object {
        [PSCustomObject]@{
            "站点" = $_.'站点'
            "店铺" = $_.'店铺'
            "负责人" = $_.'负责人'
            "父ASIN" = $_.'父ASIN'
            "商品名" = $_.'商品名'
            "异动指标" = $_.'异动指标'
            "诊断状态" = "未生成"
            "报告类型" = Get-DiagnosisReportType $_.'异动指标'
            "摘要页地址" = ""
            "Word报告地址" = ""
            "失败原因" = ""
        }
    })
}

$SummaryJson = ($Summary | ConvertTo-Json -Depth 8 -Compress).Replace("<", "\u003c")
$DetailsJson = ($Details | ConvertTo-Json -Depth 8 -Compress).Replace("<", "\u003c")
$DiagnosisJson = (ConvertTo-Json -InputObject @($DiagnosisRows) -Depth 8 -Compress).Replace("<", "\u003c")
$Total = ($Summary | Measure-Object -Property "异动商品数" -Sum).Sum
$High = ($Summary | Measure-Object -Property "高优先级异动" -Sum).Sum
$Review = ($Summary | Measure-Object -Property "待复核异动" -Sum).Sum

$SiteOptions = (($Summary | Select-Object -ExpandProperty "站点" -Unique | Sort-Object) | ForEach-Object { '<option value="' + (HtmlEscape $_) + '">' + (HtmlEscape $_) + '</option>' }) -join ""
$StoreOptions = (($Summary | Select-Object -ExpandProperty "店铺" -Unique | Sort-Object) | ForEach-Object { '<option value="' + (HtmlEscape $_) + '">' + (HtmlEscape $_) + '</option>' }) -join ""
$OwnerOptions = '<option value="' + (HtmlEscape $OwnerName) + '">' + (HtmlEscape $OwnerName) + '</option>'

$Html = Get-Content -LiteralPath $TemplatePath -Raw -Encoding UTF8
$Html = [regex]::Replace(
    $Html,
    'const summary = [\s\S]*?let selectedKey =',
    "const summary = $SummaryJson;`nconst details = $DetailsJson;`nconst diagnosisReports = $DiagnosisJson;`nlet selectedKey ="
)
$Html = [regex]::Replace($Html, '<select id="siteFilter">.*?</select>', '<select id="siteFilter"><option value="">全部站点</option>' + $SiteOptions + '</select>', [System.Text.RegularExpressions.RegexOptions]::Singleline)
$Html = [regex]::Replace($Html, '<select id="storeFilter">.*?</select>', '<select id="storeFilter"><option value="">全部店铺</option>' + $StoreOptions + '</select>', [System.Text.RegularExpressions.RegexOptions]::Singleline)
$Html = [regex]::Replace($Html, '<select id="ownerFilter">.*?</select>', '<select id="ownerFilter"><option value="">全部负责人</option>' + $OwnerOptions + '</select>', [System.Text.RegularExpressions.RegexOptions]::Singleline)
$Html = [regex]::Replace($Html, '<div class="value" id="totalCard">.*?</div>', '<div class="value" id="totalCard">' + $Total + '</div>')
$Html = [regex]::Replace($Html, '<div class="value" id="highCard">.*?</div>', '<div class="value" id="highCard">' + $High + '</div>')
$Html = [regex]::Replace($Html, '<div class="value" id="reviewCard">.*?</div>', '<div class="value" id="reviewCard">' + $Review + '</div>')
$Html = $Html.Replace("<title>异动明细BI</title>", "<title>$OwnerName 异动明细BI</title>")

$SafeOwner = SafeFileName $OwnerName
$OwnerDir = Join-Path $OutDir ("owner_" + $SafeOwner)
New-Item -ItemType Directory -Force -Path $OwnerDir | Out-Null

$OwnerSummaryPath = Join-Path $OwnerDir ("负责人汇总表_" + $SafeOwner + ".csv")
$OwnerDetailPath = Join-Path $OwnerDir ("异动明细表_" + $SafeOwner + ".csv")
$OwnerDiagnosisIndexPath = Join-Path $OwnerDir ("高优先级ASIN诊断报告索引_" + $SafeOwner + ".csv")
$OwnerDashboardPath = Join-Path $OwnerDir ("dashboard_powerbi_" + $SafeOwner + ".html")
$OwnerShortcutPath = Join-Path $OwnerDir ("open_dashboard_powerbi_" + $SafeOwner + ".url")
$OwnerManifestPath = Join-Path $OwnerDir ("owner_dashboard_manifest_" + $SafeOwner + ".json")

$Summary | Export-Csv -LiteralPath $OwnerSummaryPath -NoTypeInformation -Encoding UTF8
$Details | Export-Csv -LiteralPath $OwnerDetailPath -NoTypeInformation -Encoding UTF8
$DiagnosisRows | Export-Csv -LiteralPath $OwnerDiagnosisIndexPath -NoTypeInformation -Encoding UTF8
Set-Content -LiteralPath $OwnerDashboardPath -Value $Html -Encoding UTF8

$FileUri = "file:///" + ($OwnerDashboardPath -replace "\\", "/" -replace " ", "%20")
Set-Content -LiteralPath $OwnerShortcutPath -Value "[InternetShortcut]`r`nURL=$FileUri" -Encoding ASCII

$Manifest = [PSCustomObject]@{
    generated_at = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    dashboard_name = "异动明细BI"
    owner_name = $OwnerName
    data_scope = "owner_only"
    style_name = "powerbi-sales-dashboard-inspired-v1"
    summary_rows = @($Summary).Count
    detail_rows = @($Details).Count
    total_anomaly_products = $Total
    high_priority = $High
    review_required = $Review
    output_files = [PSCustomObject]@{
        owner_summary_csv = $OwnerSummaryPath
        owner_detail_csv = $OwnerDetailPath
        owner_diagnosis_index_csv = $OwnerDiagnosisIndexPath
        owner_dashboard_html = $OwnerDashboardPath
        shortcut = $OwnerShortcutPath
    }
}
$Manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OwnerManifestPath -Encoding UTF8
$Manifest | ConvertTo-Json -Depth 6
