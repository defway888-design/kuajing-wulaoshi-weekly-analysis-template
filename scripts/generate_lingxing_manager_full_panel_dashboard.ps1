param(
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
if (-not (Test-Path -LiteralPath $SummaryPath)) { throw "缺少负责人汇总表：$SummaryPath" }
if (-not (Test-Path -LiteralPath $DetailPath)) { throw "缺少异动明细表：$DetailPath" }

function HtmlEscape([string]$Value) {
    if ($null -eq $Value) { return "" }
    return $Value.Replace("&", "&amp;").Replace("<", "&lt;").Replace(">", "&gt;").Replace('"', "&quot;")
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

$Summary = Import-Csv -LiteralPath $SummaryPath
$Details = Import-Csv -LiteralPath $DetailPath

if (Test-Path -LiteralPath $DiagnosisIndexPath) {
    $DiagnosisRows = @(Import-Csv -LiteralPath $DiagnosisIndexPath | ForEach-Object {
        [PSCustomObject]@{
            "站点" = Get-FieldValue $_ @("站点", "site")
            "店铺" = Get-FieldValue $_ @("店铺", "store")
            "负责人" = Get-FieldValue $_ @("负责人", "owner", "owner_name")
            "父ASIN" = Get-FieldValue $_ @("父ASIN", "parent_asin", "asin")
            "商品名" = Get-FieldValue $_ @("商品名", "product_name")
            "异动指标" = Get-FieldValue $_ @("异动指标", "metric_type")
            "高优先级类型" = Get-FieldValue $_ @("高优先级类型", "high_priority_type")
            "异动来源" = Get-FieldValue $_ @("异动来源", "异动识别方式", "anomaly_source", "detection_mode")
            "当前比较窗口" = Get-FieldValue $_ @("当前比较窗口", "current_window")
            "基准比较窗口" = Get-FieldValue $_ @("基准比较窗口", "baseline_window", "previous_window")
            "当前流量值" = Get-FieldValue $_ @("当前流量值", "current_traffic")
            "基准流量值" = Get-FieldValue $_ @("基准流量值", "baseline_traffic", "previous_traffic")
            "流量变化率" = Get-FieldValue $_ @("流量变化率", "traffic_change_rate")
            "当前转化率" = Get-FieldValue $_ @("当前转化率", "current_conversion_rate")
            "基准转化率" = Get-FieldValue $_ @("基准转化率", "baseline_conversion_rate", "previous_conversion_rate")
            "转化率变化率" = Get-FieldValue $_ @("转化率变化率", "conversion_change_rate")
            "诊断状态" = Get-FieldValue $_ @("诊断状态", "diagnosis_status")
            "核心诊断状态" = Get-FieldValue $_ @("核心诊断状态", "core_diagnosis_status")
            "可发送状态" = Get-FieldValue $_ @("可发送状态", "send_status")
            "报告类型" = Get-FieldValue $_ @("报告类型", "report_type")
            "摘要页地址" = Get-FieldValue $_ @("摘要页地址", "summary_page_path", "summary_url", "报告地址")
            "Word报告地址" = Get-FieldValue $_ @("Word报告地址", "word_report_path", "docx_path")
            "证据缺口类型" = Get-FieldValue $_ @("证据缺口类型", "evidence_gap_type")
            "证据缺口说明" = Get-FieldValue $_ @("证据缺口说明", "evidence_gap_detail")
            "字段映射记录" = Get-FieldValue $_ @("字段映射记录", "field_mapping_log")
            "失败原因" = Get-FieldValue $_ @("失败原因", "failure_reason")
            "阻断原因" = Get-FieldValue $_ @("阻断原因", "blocking_reason")
            "行动方案状态" = Get-FieldValue $_ @("行动方案状态", "action_plan_status")
            "在线表格写入状态" = Get-FieldValue $_ @("在线表格写入状态", "online_table_write_status")
            "在线表格地址" = Get-FieldValue $_ @("在线表格地址", "online_table_url")
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
            "高优先级类型" = $_.'高优先级类型'
            "异动来源" = $_.'异动来源'
            "当前比较窗口" = $_.'当前比较窗口'
            "基准比较窗口" = $_.'基准比较窗口'
            "当前流量值" = $_.'当前流量值'
            "基准流量值" = $_.'基准流量值'
            "流量变化率" = $_.'流量变化率'
            "当前转化率" = $_.'当前转化率'
            "基准转化率" = $_.'基准转化率'
            "转化率变化率" = $_.'转化率变化率'
            "诊断状态" = "未生成"
            "核心诊断状态" = "未生成"
            "可发送状态" = "禁止发送"
            "报告类型" = Get-DiagnosisReportType $_.'异动指标'
            "摘要页地址" = ""
            "Word报告地址" = ""
            "证据缺口类型" = ""
            "证据缺口说明" = ""
            "字段映射记录" = ""
            "失败原因" = ""
            "阻断原因" = "未生成诊断报告"
            "行动方案状态" = "待复核观察"
            "在线表格写入状态" = "未写入"
            "在线表格地址" = ""
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
$OwnerOptions = (($Summary | Select-Object -ExpandProperty "负责人" -Unique | Sort-Object) | ForEach-Object { '<option value="' + (HtmlEscape $_) + '">' + (HtmlEscape $_) + '</option>' }) -join ""

$DashboardPath = Join-Path $OutDir "manager_dashboard_full_panel.html"
$ShortcutPath = Join-Path $OutDir "open_manager_dashboard.url"
$ManifestPath = Join-Path $OutDir "manager_full_panel_manifest.json"

$Template = @'
<!doctype html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>负责人BI</title>
<style>
:root {
  --bg:#eef3f8;
  --panel:#ffffff;
  --panel-soft:#f8fbff;
  --text:#172033;
  --muted:#667085;
  --line:#d8e0ea;
  --blue:#2563eb;
  --cyan:#0ea5e9;
  --orange:#ea580c;
  --amber:#a16207;
  --green:#059669;
  --shadow:0 10px 28px rgba(16, 42, 67, .08);
}
* { box-sizing:border-box; }
body {
  margin:0;
  min-height:100vh;
  color:var(--text);
  font-family:"Microsoft YaHei", Arial, sans-serif;
  background:
    linear-gradient(135deg, rgba(37,99,235,.11), transparent 36%),
    linear-gradient(180deg,#fbfdff 0%,var(--bg) 100%);
}
.dashboard {
  width:min(1440px, 100vw);
  margin:0 auto;
  padding:18px;
}
.top-grid {
  display:grid;
  grid-template-columns:1.15fr 1.55fr repeat(3, .72fr);
  gap:12px;
  align-items:stretch;
}
.tile, .panel {
  background:var(--panel);
  border:1px solid var(--line);
  border-radius:16px;
  box-shadow:var(--shadow);
  overflow:hidden;
}
.title-card {
  min-height:104px;
  display:flex;
  align-items:center;
  padding:18px 22px;
  background:linear-gradient(135deg,#ffffff,#eaf3ff);
  border-left:6px solid var(--blue);
}
.title-card h1 {
  margin:0;
  font-size:30px;
  line-height:1.18;
  letter-spacing:0;
}
.slicer-card {
  min-height:104px;
  display:grid;
  grid-template-columns:repeat(3, minmax(0,1fr));
  gap:10px;
  padding:14px;
  background:var(--panel-soft);
}
.select-box {
  display:grid;
  gap:7px;
  align-content:center;
}
.select-box label {
  color:var(--muted);
  font-size:12px;
}
select, button, input {
  width:100%;
  min-height:36px;
  border:1px solid var(--line);
  border-radius:9px;
  background:#fff;
  color:var(--text);
  font-family:"Microsoft YaHei", Arial, sans-serif;
  font-size:13px;
  padding:6px 9px;
}
button {
  width:auto;
  cursor:pointer;
  font-weight:700;
}
button.active {
  background:#eff6ff;
  color:var(--blue);
  border-color:var(--blue);
}
.kpi {
  min-height:104px;
  padding:16px;
  display:flex;
  flex-direction:column;
  justify-content:center;
  position:relative;
}
.kpi::after {
  content:"";
  position:absolute;
  right:-28px;
  top:-28px;
  width:92px;
  height:92px;
  border-radius:50%;
  background:rgba(37,99,235,.08);
}
.kpi .value {
  font-size:34px;
  line-height:1;
  font-weight:900;
}
.kpi .label {
  margin-top:10px;
  color:var(--muted);
  font-size:14px;
}
.kpi.high .value { color:var(--orange); }
.kpi.review .value { color:var(--amber); }
.visual-grid, .lower-grid {
  margin-top:14px;
  display:grid;
  gap:14px;
}
.visual-grid { grid-template-columns:repeat(3, minmax(0,1fr)); }
.lower-grid { grid-template-columns:repeat(4, minmax(0,1fr)); }
.panel {
  min-height:286px;
  padding:16px;
}
.panel h2 {
  margin:0 0 14px;
  text-align:center;
  font-size:18px;
  line-height:1.28;
  letter-spacing:0;
}
.bar-chart {
  display:grid;
  gap:10px;
}
.bar-row {
  display:grid;
  grid-template-columns:98px 1fr 42px;
  gap:10px;
  align-items:center;
  font-size:12px;
}
.bar-track {
  height:20px;
  border-radius:999px;
  overflow:hidden;
  background:#e9eef5;
}
.bar-fill {
  height:100%;
  border-radius:999px;
  background:linear-gradient(90deg,var(--blue),var(--cyan));
}
.report-panel { grid-column:1 / -1; min-height:188px; }
.report-filter-grid {
  display:grid;
  grid-template-columns:repeat(3, minmax(0,1fr));
  gap:10px;
  margin-bottom:10px;
  padding:10px;
  border:1px solid var(--line);
  border-radius:10px;
  background:var(--panel-soft);
}
.report-filter-grid .select-box {
  gap:5px;
}
.report-list {
  display:grid;
  grid-template-columns:repeat(3, minmax(0,1fr));
  gap:10px;
  max-height:292px;
  overflow:auto;
}
.report-card {
  min-height:96px;
  display:grid;
  gap:6px;
  align-content:start;
  padding:12px;
  border:1px solid var(--line);
  border-radius:10px;
  background:var(--panel-soft);
}
.report-card .asin { font-size:15px; font-weight:900; color:var(--orange); }
.report-card .meta { font-size:12px; line-height:1.4; color:var(--muted); overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }
.report-card a, .report-card .pending {
  width:max-content;
  min-height:28px;
  display:inline-flex;
  align-items:center;
  padding:0 10px;
  border-radius:8px;
  font-size:12px;
  font-weight:900;
  color:#fff;
  background:var(--blue);
  text-decoration:none;
}
.report-card .pending { color:var(--muted); background:#e9eef5; }
.empty-note { padding:12px; color:var(--muted); font-weight:800; }
.donut-wrap {
  display:grid;
  grid-template-columns:180px 1fr;
  gap:12px;
  align-items:center;
  min-height:214px;
}
.donut {
  width:162px;
  height:162px;
  border-radius:50%;
  background:conic-gradient(var(--orange) 0deg,var(--orange) var(--high-deg),var(--amber) var(--high-deg),var(--amber) 360deg);
  position:relative;
  margin:auto;
}
.donut::after {
  content:"";
  position:absolute;
  inset:48px;
  background:#fff;
  border-radius:50%;
  box-shadow:inset 0 0 0 1px var(--line);
}
.legend {
  display:grid;
  gap:10px;
  color:var(--muted);
  font-size:13px;
}
.legend span {
  display:inline-flex;
  width:12px;
  height:12px;
  margin-right:7px;
  border-radius:50%;
}
.legend .high { background:var(--orange); }
.legend .review { background:var(--amber); }
.legend .traffic { background:var(--orange); }
.legend .cvr { background:var(--amber); }
.legend .both { background:var(--blue); }
.line-chart {
  height:222px;
  position:relative;
  padding:14px 8px 24px;
}
.line-chart svg {
  width:100%;
  height:100%;
  overflow:visible;
}
.grid-line {
  stroke:#d8e0ea;
  stroke-dasharray:2 6;
}
.line-path {
  fill:none;
  stroke:var(--green);
  stroke-width:4;
  stroke-linecap:round;
  stroke-linejoin:round;
}
.point { fill:var(--green); }
.axis-label {
  fill:var(--muted);
  font-size:12px;
  font-weight:700;
}
.table-panel {
  grid-column:1 / -1;
  min-height:360px;
}
.table-tools {
  display:flex;
  gap:8px;
  justify-content:space-between;
  align-items:center;
  margin-bottom:10px;
  flex-wrap:wrap;
}
.table-tools > div {
  display:flex;
  gap:8px;
  flex-wrap:wrap;
}
.table-tools input {
  width:230px;
}
.detail-title {
  font-size:13px;
  color:var(--muted);
  font-weight:700;
  margin:10px 0 8px;
}
.table-wrap {
  max-height:250px;
  overflow:auto;
  border:1px solid var(--line);
  border-radius:10px;
}
.table-wrap.detail {
  max-height:310px;
}
table {
  width:100%;
  border-collapse:collapse;
  table-layout:fixed;
}
th, td {
  padding:9px 10px;
  border-bottom:1px solid var(--line);
  font-size:12px;
  vertical-align:top;
}
th {
  position:sticky;
  top:0;
  z-index:1;
  background:#f7f9fc;
  color:#344054;
  text-align:left;
}
tr { cursor:pointer; }
tr:hover, tr.selected { background:#eff6ff; }
.num {
  text-align:right;
  font-variant-numeric:tabular-nums;
}
.link {
  color:var(--blue);
  text-decoration:underline;
  text-underline-offset:2px;
  font-weight:800;
}
.status-high { color:var(--orange); font-weight:800; }
.status-review { color:var(--amber); font-weight:800; }
.product { width:28%; }
@media (max-width:980px) {
  .top-grid, .visual-grid, .lower-grid { grid-template-columns:1fr; }
  .slicer-card { grid-template-columns:1fr; }
  .report-filter-grid { grid-template-columns:1fr; }
  .title-card h1 { font-size:26px; }
  .report-list { grid-template-columns:1fr; }
  .donut-wrap { grid-template-columns:1fr; }
}
</style>
</head>
<body>
<main class="dashboard">
  <section class="top-grid">
    <div class="tile title-card"><h1>跨境吴老师<br>周数据分析看板</h1></div>
    <div class="tile slicer-card">
      <div class="select-box"><label>站点</label><select id="siteFilter"><option value="">全部站点</option>__SITE_OPTIONS__</select></div>
      <div class="select-box"><label>店铺</label><select id="storeFilter"><option value="">全部店铺</option>__STORE_OPTIONS__</select></div>
      <div class="select-box"><label>负责人</label><select id="ownerFilter"><option value="">全部负责人</option>__OWNER_OPTIONS__</select></div>
    </div>
    <div class="tile kpi"><div class="value" id="totalCard">__TOTAL__</div><div class="label">异动商品数</div></div>
    <div class="tile kpi high"><div class="value" id="highCard">__HIGH__</div><div class="label">高优先级异动</div></div>
    <div class="tile kpi review"><div class="value" id="reviewCard">__REVIEW__</div><div class="label">待复核异动</div></div>
  </section>

  <section class="visual-grid">
    <div class="panel"><h2>异动类型占比</h2><div class="donut-wrap"><div class="donut" id="typeDonut"></div><div class="legend" id="typeLegend"></div></div></div>
    <div class="panel"><h2>高优先异动分类占比</h2><div class="donut-wrap"><div class="donut" id="highSubtypeDonut"></div><div class="legend" id="highSubtypeLegend"></div></div></div>
    <div class="panel"><h2>待复核异动分类占比</h2><div class="donut-wrap"><div class="donut" id="reviewReasonDonut"></div><div class="legend" id="reviewReasonLegend"></div></div></div>
  </section>

  <section class="lower-grid">
    <div class="panel"><h2>异动指标 by 类型</h2><div class="donut-wrap"><div class="donut" id="metricDonut"></div><div class="legend" id="metricLegend"></div></div></div>
    <div class="panel"><h2>异动商品数 by 站点</h2><div class="bar-chart" id="siteBars"></div></div>
    <div class="panel"><h2>异动商品数 by 店铺</h2><div class="bar-chart" id="storeBars"></div></div>
    <div class="panel"><h2>异动商品数 by 负责人</h2><div class="bar-chart" id="ownerBars"></div></div>
    <div class="panel report-panel">
      <h2>高优先级ASIN诊断报告入口</h2>
      <div class="report-filter-grid">
        <div class="select-box"><label>站点</label><select id="reportSiteFilter"><option value="">全部站点</option></select></div>
        <div class="select-box"><label>店铺</label><select id="reportStoreFilter"><option value="">全部店铺</option></select></div>
        <div class="select-box"><label>运营人员</label><select id="reportOwnerFilter"><option value="">全部运营人员</option></select></div>
      </div>
      <div class="detail-title" id="diagnosisTitle">当前高优先级ASIN诊断报告</div>
      <div class="report-list" id="diagnosisList"></div>
    </div>
    <div class="panel table-panel">
      <h2>负责人汇总与异动明细</h2>
      <div class="table-tools">
        <div>
          <button id="clearFilter">全部</button>
          <button data-status="高优先级异动">高优先级异动</button>
          <button data-status="待复核异动">待复核异动</button>
        </div>
        <input id="searchBox" placeholder="搜索父ASIN / 商品名">
      </div>
      <div class="table-wrap"><table id="summaryTable"><thead><tr><th>站点</th><th>店铺</th><th>负责人</th><th class="num">异动商品数</th><th class="num">高优先级异动</th><th class="num">当期高优先异动</th><th class="num">缓慢高优先异动</th><th class="num">待复核异动</th></tr></thead><tbody></tbody></table></div>
      <div class="detail-title" id="detailTitle">当前显示全部明细</div>
      <div class="table-wrap detail"><table id="detailTable"><thead><tr><th>站点</th><th>店铺</th><th>负责人</th><th>父ASIN</th><th class="product">商品名</th><th>异动指标</th><th>异动来源</th><th>当前比较窗口</th><th>基准比较窗口</th><th>当前流量值</th><th>基准流量值</th><th>流量变化率</th><th>当前转化率</th><th>基准转化率</th><th>转化率变化率</th><th>趋势候选原因</th><th>趋势判断窗口</th><th>历史判断</th><th>待复核原因</th><th>最终状态</th><th>高优先级类型</th></tr></thead><tbody></tbody></table></div>
    </div>
  </section>
</main>

<script>
const summary = __SUMMARY_JSON__;
const details = __DETAILS_JSON__;
const diagnosisReports = __DIAGNOSIS_JSON__;
let selectedKey = "";
let selectedStatus = "";
let selectedSite = "";
let selectedStore = "";
let selectedOwner = "";
let reportSite = "";
let reportStore = "";
let reportOwner = "";
const siteFilter = document.getElementById("siteFilter");
const storeFilter = document.getElementById("storeFilter");
const ownerFilter = document.getElementById("ownerFilter");
const totalCard = document.getElementById("totalCard");
const highCard = document.getElementById("highCard");
const reviewCard = document.getElementById("reviewCard");
const siteBars = document.getElementById("siteBars");
const ownerBars = document.getElementById("ownerBars");
const storeBars = document.getElementById("storeBars");
const typeDonut = document.getElementById("typeDonut");
const typeLegend = document.getElementById("typeLegend");
const highSubtypeDonut = document.getElementById("highSubtypeDonut");
const highSubtypeLegend = document.getElementById("highSubtypeLegend");
const reviewReasonDonut = document.getElementById("reviewReasonDonut");
const reviewReasonLegend = document.getElementById("reviewReasonLegend");
const metricDonut = document.getElementById("metricDonut");
const metricLegend = document.getElementById("metricLegend");
const diagnosisTitle = document.getElementById("diagnosisTitle");
const diagnosisList = document.getElementById("diagnosisList");
const reportSiteFilter = document.getElementById("reportSiteFilter");
const reportStoreFilter = document.getElementById("reportStoreFilter");
const reportOwnerFilter = document.getElementById("reportOwnerFilter");
const summaryTable = document.getElementById("summaryTable");
const detailTitle = document.getElementById("detailTitle");
const detailTable = document.getElementById("detailTable");
const clearFilter = document.getElementById("clearFilter");
const searchBox = document.getElementById("searchBox");
function esc(value) { return String(value ?? "").replace(/[&<>"']/g, ch => ({ "&":"&amp;", "<":"&lt;", ">":"&gt;", '"':"&quot;", "'":"&#39;" }[ch])); }
function rowKey(row) { return [row["站点"], row["店铺"], row["负责人"]].join("||"); }
function uniqueValues(rows, field) { return [...new Set(rows.map(row => row[field]).filter(Boolean))].sort((a,b) => String(a).localeCompare(String(b), "zh-Hans-CN")); }
function passDimensions(row) {
  if (selectedSite && row["站点"] !== selectedSite) return false;
  if (selectedStore && row["店铺"] !== selectedStore) return false;
  if (selectedOwner && row["负责人"] !== selectedOwner) return false;
  return true;
}
function passReportDimensions(row) {
  if (reportSite && row["站点"] !== reportSite) return false;
  if (reportStore && row["店铺"] !== reportStore) return false;
  if (reportOwner && row["负责人"] !== reportOwner) return false;
  return true;
}
function filteredSummaryRows() { return summary.filter(passDimensions); }
function filteredDetails() {
  const q = searchBox.value.trim().toLowerCase();
  return details.filter(row => {
    if (!passDimensions(row)) return false;
    if (selectedKey && rowKey(row) !== selectedKey) return false;
    if (selectedStatus && row["最终状态"] !== selectedStatus) return false;
    if (!q) return true;
    return String(row["父ASIN"]).toLowerCase().includes(q) || String(row["商品名"]).toLowerCase().includes(q);
  });
}
function filteredDiagnosisReports() {
  const q = searchBox.value.trim().toLowerCase();
  return diagnosisReports.filter(row => {
    if (!passDimensions(row)) return false;
    if (!passReportDimensions(row)) return false;
    if (selectedKey && rowKey(row) !== selectedKey) return false;
    if (selectedStatus && selectedStatus !== "高优先级异动") return false;
    if (!q) return true;
    const haystack = [row["父ASIN"], row["商品名"], row["异动指标"], row["诊断状态"], row["核心诊断状态"], row["可发送状态"], row["证据缺口类型"], row["报告类型"]].join(" ").toLowerCase();
    return haystack.includes(q);
  });
}
function setSelectOptions(select, values, allLabel, currentValue) {
  select.innerHTML = `<option value="">${esc(allLabel)}</option>` + values.map(value => `<option value="${esc(value)}">${esc(value)}</option>`).join("");
  select.value = values.includes(currentValue) ? currentValue : "";
  return select.value;
}
function renderFilters() {
  selectedSite = setSelectOptions(siteFilter, uniqueValues(summary, "站点"), "全部站点", selectedSite);
  const storeBase = summary.filter(row => !selectedSite || row["站点"] === selectedSite);
  selectedStore = setSelectOptions(storeFilter, uniqueValues(storeBase, "店铺"), "全部店铺", selectedStore);
  const ownerBase = storeBase.filter(row => !selectedStore || row["店铺"] === selectedStore);
  selectedOwner = setSelectOptions(ownerFilter, uniqueValues(ownerBase, "负责人"), "全部负责人", selectedOwner);
}
function renderReportFilters() {
  const base = diagnosisReports.filter(passDimensions);
  reportSite = setSelectOptions(reportSiteFilter, uniqueValues(base, "站点"), "全部站点", reportSite);
  const storeBase = base.filter(row => !reportSite || row["站点"] === reportSite);
  reportStore = setSelectOptions(reportStoreFilter, uniqueValues(storeBase, "店铺"), "全部店铺", reportStore);
  const ownerBase = storeBase.filter(row => !reportStore || row["店铺"] === reportStore);
  reportOwner = setSelectOptions(reportOwnerFilter, uniqueValues(ownerBase, "负责人"), "全部运营人员", reportOwner);
}
function aggregate(rows, field) {
  const map = new Map();
  rows.forEach(row => {
    const key = row[field] || "未分配";
    if (!map.has(key)) map.set(key, { label:key, total:0, high:0, review:0 });
    const item = map.get(key);
    item.total += Number(row["异动商品数"] || 0);
    item.high += Number(row["高优先级异动"] || 0);
    item.review += Number(row["待复核异动"] || 0);
  });
  return [...map.values()].sort((a,b) => b.total - a.total);
}
function renderCards() {
  const rows = filteredSummaryRows();
  totalCard.textContent = rows.reduce((s,row) => s + Number(row["异动商品数"] || 0), 0);
  highCard.textContent = rows.reduce((s,row) => s + Number(row["高优先级异动"] || 0), 0);
  reviewCard.textContent = rows.reduce((s,row) => s + Number(row["待复核异动"] || 0), 0);
}
function renderBars(el, rows, valueField, limit = 6) {
  const list = rows.slice(0, limit);
  const max = Math.max(1, ...list.map(row => Number(row[valueField] || 0)));
  el.innerHTML = list.length ? list.map(row => {
    const val = Number(row[valueField] || 0);
    return `<div class="bar-row"><div title="${esc(row.label)}">${esc(String(row.label).slice(0,12))}</div><div class="bar-track"><div class="bar-fill" style="width:${Math.max(2, val / max * 100)}%"></div></div><div class="num">${val}</div></div>`;
  }).join("") : `<div>无数据</div>`;
}
function renderDonut(el, legend, high, review, labels = ["高优先级异动", "待复核异动"]) {
  const total = Math.max(0, high + review);
  const deg = total ? (high / total * 360) : 0;
  el.style.setProperty("--high-deg", `${deg}deg`);
  el.style.removeProperty("background");
  legend.innerHTML = `<div><span class="high"></span>${esc(labels[0])}：${high}</div><div><span class="review"></span>${esc(labels[1])}：${review}</div><div>合计：${total}</div>`;
}
function renderMetricCategoryDonut(el, legend, items) {
  const colors = ["var(--orange)", "var(--amber)", "var(--blue)"];
  const classes = ["traffic", "cvr", "both"];
  const total = items.reduce((sum, item) => sum + item.value, 0);
  if (!total) {
    el.style.background = "conic-gradient(#e5ebf3 0deg,#e5ebf3 360deg)";
  } else {
    let start = 0;
    const segments = items.map((item, index) => {
      const end = start + (item.value / total * 360);
      const segment = `${colors[index]} ${start}deg ${end}deg`;
      start = end;
      return segment;
    });
    el.style.background = `conic-gradient(${segments.join(",")})`;
  }
  legend.innerHTML = items.map((item, index) => `<div><span class="${classes[index]}"></span>${esc(item.label)}：${item.value}</div>`).join("") + `<div>合计：${total}</div>`;
}
function renderCategoryDonut(el, legend, items) {
  const colors = ["var(--orange)", "var(--blue)", "var(--amber)", "var(--green)", "#7c3aed", "#0f766e", "#be123c"];
  const total = items.reduce((sum, item) => sum + Number(item.value || 0), 0);
  const cleanItems = items.filter(item => Number(item.value || 0) > 0);
  if (!total || !cleanItems.length) {
    el.style.background = "conic-gradient(#e5ebf3 0deg,#e5ebf3 360deg)";
    legend.innerHTML = `<div>暂无数据</div><div>合计：0</div>`;
    return;
  }
  let start = 0;
  const segments = cleanItems.map((item, index) => {
    const end = start + (Number(item.value || 0) / total * 360);
    const segment = `${colors[index % colors.length]} ${start}deg ${end}deg`;
    start = end;
    return segment;
  });
  el.style.background = `conic-gradient(${segments.join(",")})`;
  legend.innerHTML = cleanItems.map((item, index) => `<div><span style="background:${colors[index % colors.length]}"></span>${esc(item.label)}：${item.value}</div>`).join("") + `<div>合计：${total}</div>`;
}
function reviewReason(row) {
  const direct = String(row["待复核原因"] || "").trim();
  if (direct) return direct;
  const history = String(row["历史判断"] || "");
  if (history.includes("从0新增")) return "从0新增";
  if (history.includes("样本不足") || history.includes("低样本")) return "低样本";
  if (history.includes("负责人变更")) return "负责人变更";
  if (history.includes("无历史数据")) return "无历史数据";
  return "其他";
}
function countDetailsBy(rows, labelFn) {
  const map = new Map();
  rows.forEach(row => {
    const label = labelFn(row) || "其他";
    map.set(label, (map.get(label) || 0) + 1);
  });
  return [...map.entries()].map(([label, value]) => ({ label, value })).sort((a,b) => b.value - a.value);
}
function renderDiagnosisReports() {
  const rows = filteredDiagnosisReports();
  diagnosisTitle.textContent = selectedKey ? `${selectedKey.replaceAll("||", " / ")}：${rows.length} 个高优先级ASIN` : `高优先级ASIN诊断报告：${rows.length} 个`;
  if (!rows.length) {
    diagnosisList.innerHTML = `<div class="empty-note">暂无高优先级ASIN诊断报告</div>`;
    return;
  }
  diagnosisList.innerHTML = rows.map(row => {
    const href = row["摘要页地址"] || row["Word报告地址"] || "";
    const action = href ? `<a href="${esc(href)}" target="_blank" rel="noopener">查看报告</a>` : `<span class="pending">待生成</span>`;
    const diagnosisState = row["核心诊断状态"] || row["诊断状态"] || "未生成";
    const sendState = row["可发送状态"] ? `｜${row["可发送状态"]}` : "";
    const gap = row["证据缺口类型"] ? `｜证据缺口：${row["证据缺口类型"]}` : "";
    const reasonText = row["阻断原因"] || row["失败原因"] || "";
    const reason = reasonText ? `｜${reasonText}` : "";
    return `<div class="report-card">
      <div class="asin">${esc(row["父ASIN"])}</div>
      <div class="meta">${esc(row["负责人"])}｜${esc(row["异动指标"])}｜${esc(row["高优先级类型"] || "高优先级异动")}｜${esc(row["报告类型"])}</div>
      <div class="meta">${esc(row["商品名"])}</div>
      <div class="meta">${esc(diagnosisState)}${esc(sendState)}${esc(gap)}${esc(reason)}</div>
      ${action}
    </div>`;
  }).join("");
}
function renderLine(rows) {
  const list = rows.slice(0, 10);
  const max = Math.max(1, ...list.map(row => Number(row.total || 0)));
  const width = 520, height = 190, padX = 28, padY = 20;
  const points = list.map((row, i) => {
    const x = padX + (list.length <= 1 ? 0 : i * ((width - padX * 2) / (list.length - 1)));
    const y = height - padY - (Number(row.total) / max) * (height - padY * 2);
    return { x, y, label: row.label, value: row.total };
  });
  const path = points.map((p, i) => `${i ? "L" : "M"}${p.x},${p.y}`).join(" ");
  ownerLine.innerHTML = `<svg viewBox="0 0 ${width} ${height}" preserveAspectRatio="none">
    <line class="grid-line" x1="20" y1="40" x2="${width-20}" y2="40"></line>
    <line class="grid-line" x1="20" y1="95" x2="${width-20}" y2="95"></line>
    <line class="grid-line" x1="20" y1="150" x2="${width-20}" y2="150"></line>
    <path class="line-path" d="${path}"></path>
    ${points.map(p => `<circle class="point" cx="${p.x}" cy="${p.y}" r="4"></circle><text class="axis-label" x="${p.x}" y="${p.y - 9}" text-anchor="middle">${p.value}</text>`).join("")}
    ${points.map(p => `<text class="axis-label" x="${p.x}" y="184" text-anchor="middle" transform="rotate(-35 ${p.x} 184)">${esc(String(p.label).slice(0,8))}</text>`).join("")}
  </svg>`;
}
function renderVisuals() {
  const rows = filteredSummaryRows();
  const dimensionDetails = details.filter(passDimensions);
  const high = rows.reduce((s,row) => s + Number(row["高优先级异动"] || 0), 0);
  const currentHigh = rows.reduce((s,row) => s + Number(row["当期高优先异动"] || 0), 0);
  const slowHigh = rows.reduce((s,row) => s + Number(row["缓慢高优先异动"] || 0), 0);
  const review = rows.reduce((s,row) => s + Number(row["待复核异动"] || 0), 0);
  renderDonut(typeDonut, typeLegend, high, review);
  renderCategoryDonut(highSubtypeDonut, highSubtypeLegend, [
    { label:"当期高优先异动", value:currentHigh },
    { label:"缓慢高优先异动", value:slowHigh }
  ]);
  renderCategoryDonut(reviewReasonDonut, reviewReasonLegend, countDetailsBy(dimensionDetails.filter(row => row["最终状态"] === "待复核异动"), reviewReason));
  const metricRows = dimensionDetails;
  renderMetricCategoryDonut(metricDonut, metricLegend, [
    { label:"流量异动", value:metricRows.filter(row => String(row["异动指标"]).trim() === "流量异动").length },
    { label:"转化率异动", value:metricRows.filter(row => String(row["异动指标"]).trim() === "转化率异动").length },
    { label:"流量+转化率异动", value:metricRows.filter(row => String(row["异动指标"]).trim() === "流量+转化率异动").length }
  ]);
  renderBars(siteBars, aggregate(rows, "站点"), "total");
  renderBars(storeBars, aggregate(rows, "店铺"), "total");
  renderBars(ownerBars, aggregate(rows, "负责人"), "total");
}
function renderSummary() {
  const rows = filteredSummaryRows();
  summaryTable.querySelector("tbody").innerHTML = rows.map(row => {
    const key = rowKey(row);
    return `<tr data-key="${esc(key)}" class="${key === selectedKey ? "selected" : ""}">
      <td>${esc(row["站点"])}</td><td>${esc(row["店铺"])}</td><td>${esc(row["负责人"])}</td>
      <td class="num link" data-scope="all">${esc(row["异动商品数"])}</td>
      <td class="num link status-high" data-scope="高优先级异动">${esc(row["高优先级异动"])}</td>
      <td class="num link status-high" data-scope="高优先级异动">${esc(row["当期高优先异动"] || 0)}</td>
      <td class="num link status-high" data-scope="高优先级异动">${esc(row["缓慢高优先异动"] || 0)}</td>
      <td class="num link status-review" data-scope="待复核异动">${esc(row["待复核异动"])}</td>
    </tr>`;
  }).join("");
  summaryTable.querySelectorAll("tbody tr").forEach(tr => tr.addEventListener("click", event => {
    selectedKey = tr.dataset.key;
    const scope = event.target.dataset.scope;
    selectedStatus = scope && scope !== "all" ? scope : "";
    renderAll();
  }));
}
function renderDetails() {
  const rows = filteredDetails();
  detailTitle.textContent = selectedKey ? `${selectedKey.replaceAll("||", " / ")}${selectedStatus ? " / " + selectedStatus : ""}：${rows.length} 条` : `${selectedStatus || "全部明细"}：${rows.length} 条`;
  detailTable.querySelector("tbody").innerHTML = rows.map(row => `<tr>
    <td>${esc(row["站点"])}</td><td>${esc(row["店铺"])}</td><td>${esc(row["负责人"])}</td><td>${esc(row["父ASIN"])}</td>
    <td>${esc(row["商品名"])}</td><td>${esc(row["异动指标"])}</td><td>${esc(row["异动来源"] || row["异动识别方式"])}</td>
    <td>${esc(row["当前比较窗口"])}</td><td>${esc(row["基准比较窗口"])}</td><td>${esc(row["当前流量值"])}</td><td>${esc(row["基准流量值"])}</td><td>${esc(row["流量变化率"])}</td>
    <td>${esc(row["当前转化率"])}</td><td>${esc(row["基准转化率"])}</td><td>${esc(row["转化率变化率"])}</td>
    <td>${esc(row["趋势候选原因"])}</td><td>${esc(row["趋势判断窗口"])}</td><td>${esc(row["历史判断"])}</td><td>${esc(row["待复核原因"])}</td><td class="${row["最终状态"] === "高优先级异动" ? "status-high" : "status-review"}">${esc(row["最终状态"])}</td><td>${esc(row["高优先级类型"])}</td>
  </tr>`).join("");
}
function renderButtons() { document.querySelectorAll("button[data-status]").forEach(btn => btn.classList.toggle("active", btn.dataset.status === selectedStatus)); }
function renderAll() { renderFilters(); renderReportFilters(); renderCards(); renderVisuals(); renderDiagnosisReports(); renderSummary(); renderDetails(); renderButtons(); }
function handleDimensionChange() {
  selectedSite = siteFilter.value;
  selectedStore = storeFilter.value;
  selectedOwner = ownerFilter.value;
  selectedKey = "";
  renderAll();
}
siteFilter.addEventListener("change", handleDimensionChange);
storeFilter.addEventListener("change", handleDimensionChange);
ownerFilter.addEventListener("change", handleDimensionChange);
function handleReportDimensionChange() {
  reportSite = reportSiteFilter.value;
  reportStore = reportStoreFilter.value;
  reportOwner = reportOwnerFilter.value;
  renderReportFilters();
  renderDiagnosisReports();
}
reportSiteFilter.addEventListener("change", handleReportDimensionChange);
reportStoreFilter.addEventListener("change", handleReportDimensionChange);
reportOwnerFilter.addEventListener("change", handleReportDimensionChange);
clearFilter.addEventListener("click", () => { selectedKey = ""; selectedStatus = ""; selectedSite = ""; selectedStore = ""; selectedOwner = ""; reportSite = ""; reportStore = ""; reportOwner = ""; searchBox.value = ""; renderAll(); });
document.querySelectorAll("button[data-status]").forEach(btn => btn.addEventListener("click", () => { selectedStatus = selectedStatus === btn.dataset.status ? "" : btn.dataset.status; selectedKey = ""; renderAll(); }));
searchBox.addEventListener("input", () => { renderVisuals(); renderDiagnosisReports(); renderDetails(); });
renderAll();
</script>
</body>
</html>
'@

$Dashboard = $Template.
    Replace("__TOTAL__", [string]$Total).
    Replace("__HIGH__", [string]$High).
    Replace("__REVIEW__", [string]$Review).
    Replace("__SITE_OPTIONS__", $SiteOptions).
    Replace("__STORE_OPTIONS__", $StoreOptions).
    Replace("__OWNER_OPTIONS__", $OwnerOptions).
    Replace("__SUMMARY_JSON__", $SummaryJson).
    Replace("__DETAILS_JSON__", $DetailsJson).
    Replace("__DIAGNOSIS_JSON__", $DiagnosisJson)

Set-Content -LiteralPath $DashboardPath -Value $Dashboard -Encoding UTF8

$FileUri = "file:///" + ($DashboardPath -replace "\\", "/" -replace " ", "%20")
Set-Content -LiteralPath $ShortcutPath -Value "[InternetShortcut]`r`nURL=$FileUri" -Encoding ASCII

$Manifest = [PSCustomObject]@{
    generated_at = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    dashboard_name = "负责人BI"
    style_reference = "https://github.com/shrewsendlessmer84/powerbi-full-panel-2026"
    style_name = "manager-full-panel-style-same-modules-v1"
    module_policy = "same_modules_as_anomaly_detail_bi; no_extra_modules"
    summary_rows = @($Summary).Count
    detail_rows = @($Details).Count
    total_anomaly_products = $Total
    high_priority = $High
    review_required = $Review
    output_files = [PSCustomObject]@{
        manager_dashboard_html = $DashboardPath
        shortcut = $ShortcutPath
    }
}
$Manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $ManifestPath -Encoding UTF8
$Manifest | ConvertTo-Json -Depth 6
