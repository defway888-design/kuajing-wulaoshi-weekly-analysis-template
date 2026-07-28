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
$DetailPath = Join-Path $OutDir "异动明细表_优先级命名.csv"
if (-not (Test-Path -LiteralPath $DetailPath)) {
    $DetailPath = Join-Path $OutDir "异动明细表.csv"
}
$DiagnosisIndexPath = Join-Path $OutDir "高优先级ASIN诊断报告索引.csv"

$StatusMap = @{
    "真实异动" = "高优先级异动"
    "人工复核" = "待复核异动"
}

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

$RawDetails = Import-Csv -LiteralPath $DetailPath
$Details = foreach ($Row in $RawDetails) {
    $Status = $Row.'最终状态'
    if ($StatusMap.ContainsKey($Status)) { $Status = $StatusMap[$Status] }
    [PSCustomObject]@{
        "站点" = $Row.'站点'
        "店铺" = $Row.'店铺'
        "负责人" = $Row.'负责人'
        "父ASIN" = $Row.'父ASIN'
        "商品名" = $Row.'商品名'
        "异动指标" = $Row.'异动指标'
        "当前值" = $Row.'当前值'
        "上月值" = $Row.'上月值'
        "变化率" = $Row.'变化率'
        "历史判断" = $Row.'历史判断'
        "最终状态" = $Status
    }
}

$Summary = $Details |
    Group-Object "站点", "店铺", "负责人" |
    ForEach-Object {
        $First = $_.Group[0]
        [PSCustomObject]@{
            "站点" = $First.'站点'
            "店铺" = $First.'店铺'
            "负责人" = $First.'负责人'
            "异动商品数" = $_.Count
            "高优先级异动" = @($_.Group | Where-Object { $_.'最终状态' -eq "高优先级异动" }).Count
            "待复核异动" = @($_.Group | Where-Object { $_.'最终状态' -eq "待复核异动" }).Count
        }
    } |
    Sort-Object "站点", "店铺", "负责人"

if (Test-Path -LiteralPath $DiagnosisIndexPath) {
    $DiagnosisRows = @(Import-Csv -LiteralPath $DiagnosisIndexPath | ForEach-Object {
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

$SummaryJson = (ConvertTo-Json -InputObject @($Summary) -Depth 8 -Compress).Replace("<", "\u003c")
$DetailsJson = (ConvertTo-Json -InputObject @($Details) -Depth 8 -Compress).Replace("<", "\u003c")
$DiagnosisJson = (ConvertTo-Json -InputObject @($DiagnosisRows) -Depth 8 -Compress).Replace("<", "\u003c")
$SiteOptions = (($Summary | Select-Object -ExpandProperty "站点" -Unique | Sort-Object) | ForEach-Object { '<option value="' + (HtmlEscape $_) + '">' + (HtmlEscape $_) + '</option>' }) -join ""
$StoreOptions = (($Summary | Select-Object -ExpandProperty "店铺" -Unique | Sort-Object) | ForEach-Object { '<option value="' + (HtmlEscape $_) + '">' + (HtmlEscape $_) + '</option>' }) -join ""
$OwnerOptions = (($Summary | Select-Object -ExpandProperty "负责人" -Unique | Sort-Object) | ForEach-Object { '<option value="' + (HtmlEscape $_) + '">' + (HtmlEscape $_) + '</option>' }) -join ""

$Total = ($Summary | Measure-Object -Property "异动商品数" -Sum).Sum
$High = ($Summary | Measure-Object -Property "高优先级异动" -Sum).Sum
$Review = ($Summary | Measure-Object -Property "待复核异动" -Sum).Sum
$OwnerCount = @($Summary | Select-Object -ExpandProperty "负责人" -Unique).Count

$DashboardPath = Join-Path $OutDir "anomaly_detail_dashboard_powerbi.html"
$ShortcutPath = Join-Path $OutDir "open_anomaly_detail_dashboard.url"
$ManifestPath = Join-Path $OutDir "powerbi_style_manifest.json"

$Template = @'
<!doctype html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>异动明细BI</title>
<style>
:root {
  --page:#3a147b;
  --panel-a:#9f78bf;
  --panel-b:#df5d9c;
  --panel-c:#c874b9;
  --text:#ffffff;
  --ink:#1a1230;
  --blue:#1595f9;
  --blue-dark:#1727a2;
  --yellow:#f4fb20;
  --hot:#ff5db2;
  --high:#ff7a1a;
  --review:#7a00a8;
}
* { box-sizing:border-box; }
body {
  margin:0;
  min-height:100vh;
  font-family:"Microsoft YaHei",Arial,sans-serif;
  color:var(--text);
  background:
    radial-gradient(circle at 10% 10%, rgba(255,120,220,.35), transparent 28%),
    linear-gradient(135deg, #40208b 0%, #801d8e 43%, #e22075 100%);
}
.dashboard {
  width:min(1360px, 100vw);
  margin:0 auto;
  padding:8px;
}
.top-grid {
  display:grid;
  grid-template-columns: 1.45fr 1.72fr .66fr .66fr .66fr;
  gap:10px;
  align-items:stretch;
}
.tile {
  border:1.5px solid #13071e;
  border-radius:13px;
  background:linear-gradient(145deg, rgba(183,126,193,.94), rgba(224,91,157,.93));
  box-shadow:0 2px 0 rgba(0,0,0,.22);
  overflow:hidden;
}
.title-card {
  min-height:82px;
  display:flex;
  align-items:center;
  padding:0 24px;
  background:rgba(183,126,193,.95);
}
.title-card h1 {
  margin:0;
  font-size:32px;
  line-height:1.18;
  color:#16121e;
  letter-spacing:0;
  font-weight:800;
}
.slicer-card {
  min-height:82px;
  display:grid;
  grid-template-columns:repeat(3, minmax(0,1fr));
  gap:0;
  padding:9px 16px;
  align-items:stretch;
}
.select-box {
  display:grid;
  align-content:center;
  gap:4px;
  border:2px solid rgba(255,255,255,.3);
  background:#704fc5;
  padding:8px 12px;
  position:relative;
  z-index:5;
}
.select-box:first-child { border-radius:0; }
.select-box label { font-size:12px; opacity:.84; }
select {
  width:100%;
  min-height:34px;
  border:1px solid rgba(0,0,0,.38);
  border-radius:6px;
  outline:0;
  color:#111827;
  background:#ffffff;
  font-family:"Microsoft YaHei",Arial,sans-serif;
  font-size:14px;
  font-weight:700;
  padding:5px 8px;
  appearance:auto;
  -webkit-appearance:menulist;
  cursor:pointer;
}
select option { color:#111827; background:#ffffff; }
.kpi {
  min-height:98px;
  display:flex;
  flex-direction:column;
  justify-content:center;
  align-items:center;
  text-align:center;
  background:#df5d9c;
}
.kpi .value { font-size:38px; line-height:1; font-weight:800; }
.kpi .label { margin-top:10px; font-size:16px; }
.visual-grid {
  margin-top:46px;
  display:grid;
  grid-template-columns: .95fr 1fr 1.55fr;
  gap:14px;
}
.lower-grid {
  margin-top:14px;
  display:grid;
  grid-template-columns:.95fr 1fr 1.55fr;
  gap:14px;
}
.panel {
  min-height:286px;
  padding:12px 16px 14px;
  background:rgba(183,126,193,.86);
  border:1.5px solid #13071e;
  border-radius:13px;
  box-shadow:0 2px 0 rgba(0,0,0,.24);
}
.panel.pink { background:rgba(220,96,158,.88); }
.panel h2 {
  margin:0 0 10px;
  text-align:center;
  font-size:20px;
  line-height:1.28;
  color:#fff;
  letter-spacing:0;
}
.bar-chart { display:grid; gap:10px; padding:10px 2px 0; }
.bar-row { display:grid; grid-template-columns:92px 1fr 46px; gap:10px; align-items:center; font-size:12px; font-weight:700; }
.bar-track { height:22px; background:rgba(255,255,255,.12); border-left:1px dotted rgba(255,255,255,.7); border-right:1px dotted rgba(255,255,255,.45); }
.bar-fill { height:100%; background:var(--blue); }
.reason-list { display:grid; gap:8px; padding:8px 2px 0; }
.reason-row { display:grid; grid-template-columns:1fr 46px; gap:10px; align-items:center; padding:8px 10px; border:1px solid rgba(255,255,255,.24); border-radius:8px; background:rgba(255,255,255,.10); font-size:12px; font-weight:700; cursor:pointer; }
.reason-row.active { background:rgba(255,241,168,.24); border-color:#fff1a8; box-shadow:inset 0 0 0 1px rgba(255,255,255,.22); }
.reason-row .label { overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }
.reason-row .count { text-align:right; color:#fff1a8; font-weight:900; font-variant-numeric:tabular-nums; text-decoration:underline; text-underline-offset:2px; }
.report-panel { grid-column:1 / -1; min-height:188px; }
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
  padding:10px 12px;
  border:1px solid rgba(255,255,255,.28);
  border-radius:9px;
  background:rgba(255,255,255,.12);
}
.report-card .asin { font-size:15px; font-weight:900; color:#fff1a8; }
.report-card .meta { font-size:12px; line-height:1.4; color:#fff; opacity:.94; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }
.report-card a, .report-card .pending {
  width:max-content;
  min-height:28px;
  display:inline-flex;
  align-items:center;
  padding:0 10px;
  border-radius:8px;
  font-size:12px;
  font-weight:900;
  color:#2a1050;
  background:#fff1a8;
  text-decoration:none;
}
.report-card .pending { color:#fff; background:rgba(255,255,255,.18); }
.empty-note { padding:12px; color:#fff; font-weight:800; }
.donut-wrap { display:grid; grid-template-columns:190px 1fr; align-items:center; min-height:214px; gap:10px; }
.donut {
  width:166px;
  height:166px;
  border-radius:50%;
  background:conic-gradient(var(--high) 0deg, var(--high) var(--high-deg), var(--review) var(--high-deg), var(--review) 360deg);
  margin:auto;
  position:relative;
}
.donut::after {
  content:"";
  position:absolute;
  inset:48px;
  background:rgba(183,126,193,.98);
  border-radius:50%;
}
.legend { display:grid; gap:12px; font-size:13px; }
.legend span { display:inline-flex; width:12px; height:12px; margin-right:7px; vertical-align:middle; }
.legend .high { background:var(--high); }
.legend .review { background:var(--review); }
.legend .traffic { background:var(--high); }
.legend .cvr { background:var(--review); }
.legend .both { background:var(--blue); }
.line-chart {
  height:222px;
  position:relative;
  padding:18px 8px 24px;
}
.line-chart svg { width:100%; height:100%; overflow:visible; }
.grid-line { stroke:rgba(255,255,255,.6); stroke-dasharray:1 5; }
.line-path { fill:none; stroke:var(--yellow); stroke-width:4; stroke-linecap:round; stroke-linejoin:round; }
.point { fill:var(--yellow); }
.axis-label { fill:#fff; font-size:12px; font-weight:700; }
.table-panel { min-height:300px; padding-bottom:10px; }
.table-tools { display:flex; gap:8px; justify-content:space-between; align-items:center; margin-bottom:8px; }
button, input {
  height:32px;
  border:1px solid rgba(0,0,0,.45);
  border-radius:8px;
  background:rgba(255,255,255,.18);
  color:#fff;
  font-family:"Microsoft YaHei",Arial,sans-serif;
  padding:0 10px;
}
button { cursor:pointer; font-weight:700; }
button.active { background:#704fc5; box-shadow:inset 0 0 0 2px rgba(255,255,255,.22); }
input::placeholder { color:rgba(255,255,255,.72); }
.table-wrap { max-height:236px; overflow:auto; border-radius:8px; border:1px solid rgba(0,0,0,.35); }
table { width:100%; border-collapse:collapse; table-layout:fixed; background:rgba(255,255,255,.06); }
th, td { padding:8px 9px; border-bottom:1px solid rgba(255,255,255,.24); font-size:12px; vertical-align:top; }
th { position:sticky; top:0; z-index:1; background:rgba(83,39,139,.95); text-align:left; }
tr { cursor:pointer; }
tr:hover, tr.selected { background:rgba(255,255,255,.16); }
.num { text-align:right; font-variant-numeric:tabular-nums; }
.link { color:#fff; text-decoration:underline; text-decoration-thickness:1px; text-underline-offset:2px; font-weight:800; }
.status-high { color:#ffd2a9; font-weight:800; }
.status-review { color:#f5ddff; font-weight:800; }
.detail-title { font-size:12px; font-weight:700; opacity:.92; }
.detail-grid { grid-column:1 / -1; min-height:350px; }
.detail-grid .table-wrap { max-height:288px; }
.review-detail-grid { grid-column:2 / -1; min-height:286px; }
.review-detail-grid .table-wrap { max-height:228px; }
.product { width:28%; }
@media (max-width:980px) {
  .top-grid, .visual-grid, .lower-grid { grid-template-columns:1fr; margin-top:12px; }
  .slicer-card { grid-template-columns:1fr; gap:8px; }
  .title-card h1 { font-size:30px; }
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
    <div class="tile kpi"><div class="value" id="highCard">__HIGH__</div><div class="label">高优先级异动</div></div>
    <div class="tile kpi"><div class="value" id="reviewCard">__REVIEW__</div><div class="label">待复核异动</div></div>
  </section>

  <section class="visual-grid">
    <div class="panel"><h2>异动商品数 by 站点</h2><div class="bar-chart" id="siteBars"></div></div>
    <div class="panel"><h2>异动类型占比</h2><div class="donut-wrap"><div class="donut" id="typeDonut"></div><div class="legend" id="typeLegend"></div></div></div>
    <div class="panel pink"><h2>高优先级异动 by 负责人</h2><div class="bar-chart" id="ownerHighBars"></div></div>
  </section>

  <section class="lower-grid">
    <div class="panel"><h2>异动指标 by 类型</h2><div class="donut-wrap"><div class="donut" id="metricDonut"></div><div class="legend" id="metricLegend"></div></div></div>
    <div class="panel"><h2>异动商品数 by 店铺</h2><div class="bar-chart" id="storeBars"></div></div>
    <div class="panel pink"><h2>异动走势 by 负责人排序</h2><div class="line-chart" id="ownerLine"></div></div>
    <div class="panel pink report-panel">
      <h2>高优先级ASIN诊断报告入口</h2>
      <div class="detail-title" id="diagnosisTitle">当前高优先级ASIN诊断报告</div>
      <div class="report-list" id="diagnosisList"></div>
    </div>
    <div class="panel"><h2>待复核异动统计</h2><div class="reason-list" id="reviewReasonBars"></div></div>
    <div class="panel pink table-panel review-detail-grid">
      <h2>待复核异动明细</h2>
      <div class="detail-title" id="reviewDetailTitle">当前显示全部待复核明细</div>
      <div class="table-wrap"><table id="reviewDetailTable"><thead><tr><th>父ASIN</th><th class="product">商品名</th><th>异动指标</th><th>变化率</th><th>待复核原因</th><th>历史判断</th></tr></thead><tbody></tbody></table></div>
    </div>
    <div class="panel pink table-panel detail-grid" style="display:none;">
      <h2>负责人汇总与异动明细</h2>
      <div class="table-tools">
        <div>
          <button id="clearFilter">全部</button>
          <button data-status="高优先级异动">高优先级异动</button>
          <button data-status="待复核异动">待复核异动</button>
        </div>
        <input id="searchBox" placeholder="搜索父ASIN / 商品名">
      </div>
      <div class="table-wrap" style="margin-bottom:10px;"><table id="summaryTable"><thead><tr><th>站点</th><th>店铺</th><th>负责人</th><th class="num">异动商品数</th><th class="num">高优先级异动</th><th class="num">待复核异动</th></tr></thead><tbody></tbody></table></div>
      <div class="detail-title" id="detailTitle">当前显示全部明细</div>
      <div class="table-wrap"><table id="detailTable"><thead><tr><th>站点</th><th>店铺</th><th>负责人</th><th>父ASIN</th><th class="product">商品名</th><th>异动指标</th><th>当前值</th><th>上月值</th><th>变化率</th><th>历史判断</th><th>待复核原因</th><th>最终状态</th></tr></thead><tbody></tbody></table></div>
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
let selectedReviewReason = "";
const siteFilter = document.getElementById("siteFilter");
const storeFilter = document.getElementById("storeFilter");
const ownerFilter = document.getElementById("ownerFilter");
const totalCard = document.getElementById("totalCard");
const highCard = document.getElementById("highCard");
const reviewCard = document.getElementById("reviewCard");
const siteBars = document.getElementById("siteBars");
const ownerHighBars = document.getElementById("ownerHighBars");
const storeBars = document.getElementById("storeBars");
const typeDonut = document.getElementById("typeDonut");
const typeLegend = document.getElementById("typeLegend");
const metricDonut = document.getElementById("metricDonut");
const metricLegend = document.getElementById("metricLegend");
const reviewReasonBars = document.getElementById("reviewReasonBars");
const diagnosisTitle = document.getElementById("diagnosisTitle");
const diagnosisList = document.getElementById("diagnosisList");
const ownerLine = document.getElementById("ownerLine");
const summaryTable = document.getElementById("summaryTable");
const reviewDetailTitle = document.getElementById("reviewDetailTitle");
const reviewDetailTable = document.getElementById("reviewDetailTable");
const detailTitle = document.getElementById("detailTitle");
const detailTable = document.getElementById("detailTable");
const clearFilter = document.getElementById("clearFilter");
const searchBox = document.getElementById("searchBox");

function esc(value) { return String(value ?? "").replace(/[&<>"']/g, ch => ({ "&":"&amp;", "<":"&lt;", ">":"&gt;", '"':"&quot;", "'":"&#39;" }[ch])); }
function rowKey(row) { return [row["站点"], row["店铺"], row["负责人"]].join("||"); }
function uniqueValues(rows, field) { return [...new Set(rows.map(row => row[field]).filter(Boolean))].sort((a,b) => String(a).localeCompare(String(b), "zh-Hans-CN")); }
function reviewReason(row) {
  if (row["最终状态"] !== "待复核异动") return "";
  const history = String(row["历史判断"] || "").trim();
  const normalized = history.replace(/\s+/g, "");
  if (/从0新增|从零新增|上月值为0/.test(normalized)) return "从0新增";
  if (/样本不足|低样本|日均流量/.test(normalized)) return "低样本";
  if (/负责人变更|负责人变化|负责人调整|交接/.test(normalized)) return "负责人变更";
  if (/无历史|没有历史|历史数据缺失|无可比历史|缺少历史/.test(normalized)) return "无历史数据";
  if (!history) return "未注明待复核原因";
  return history.split(/[：:，,。；;]/).map(part => part.trim()).filter(Boolean)[0] || history;
}
function passDimensions(row) {
  if (selectedSite && row["站点"] !== selectedSite) return false;
  if (selectedStore && row["店铺"] !== selectedStore) return false;
  if (selectedOwner && row["负责人"] !== selectedOwner) return false;
  return true;
}
function filteredSummaryRows() { return summary.filter(passDimensions); }
function filteredDetails() {
  const q = document.querySelector("#searchBox").value.trim().toLowerCase();
  return details.filter(row => {
    if (!passDimensions(row)) return false;
    if (selectedKey && rowKey(row) !== selectedKey) return false;
    if (selectedStatus && row["最终状态"] !== selectedStatus) return false;
    if (!q) return true;
    return String(row["父ASIN"]).toLowerCase().includes(q) || String(row["商品名"]).toLowerCase().includes(q);
  });
}
function filteredReviewDetails() {
  return filteredReviewBaseDetails().filter(row => !selectedReviewReason || reviewReason(row) === selectedReviewReason);
}
function filteredDiagnosisReports() {
  const q = document.querySelector("#searchBox").value.trim().toLowerCase();
  return diagnosisReports.filter(row => {
    if (!passDimensions(row)) return false;
    if (selectedKey && rowKey(row) !== selectedKey) return false;
    if (selectedStatus && selectedStatus !== "高优先级异动") return false;
    if (!q) return true;
    const haystack = [row["父ASIN"], row["商品名"], row["异动指标"], row["诊断状态"], row["报告类型"]].join(" ").toLowerCase();
    return haystack.includes(q);
  });
}
function filteredReviewBaseDetails() {
  const q = document.querySelector("#searchBox").value.trim().toLowerCase();
  return details.filter(row => {
    if (row["最终状态"] !== "待复核异动") return false;
    if (!passDimensions(row)) return false;
    if (selectedKey && rowKey(row) !== selectedKey) return false;
    if (!q) return true;
    return String(row["父ASIN"]).toLowerCase().includes(q) || String(row["商品名"]).toLowerCase().includes(q);
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
    return `<div class="bar-row"><div title="${esc(row.label)}">${esc(row.label)}</div><div class="bar-track"><div class="bar-fill" style="width:${Math.max(2, val / max * 100)}%"></div></div><div class="num">${val}</div></div>`;
  }).join("") : `<div>无数据</div>`;
}
function aggregateReviewReasons(rows) {
  const map = new Map();
  rows.filter(row => row["最终状态"] === "待复核异动").forEach(row => {
    const label = reviewReason(row);
    map.set(label, (map.get(label) || 0) + 1);
  });
  return [...map.entries()].map(([label,total]) => ({ label, total })).sort((a,b) => b.total - a.total || String(a.label).localeCompare(String(b.label), "zh-Hans-CN"));
}
function renderReviewReasons(el, rows, limit = 8) {
  const list = aggregateReviewReasons(rows).slice(0, limit);
  if (selectedReviewReason && !list.some(row => row.label === selectedReviewReason)) selectedReviewReason = "";
  el.innerHTML = list.length ? list.map(row => `<div class="reason-row${row.label === selectedReviewReason ? " active" : ""}" data-reason="${esc(row.label)}" title="${esc(row.label)}"><div class="label">${esc(row.label)}</div><div class="count">${row.total}</div></div>`).join("") : `<div>无待复核异动</div>`;
  el.querySelectorAll(".reason-row").forEach(row => row.addEventListener("click", () => {
    selectedReviewReason = selectedReviewReason === row.dataset.reason ? "" : row.dataset.reason;
    renderVisuals();
    renderReviewDetails();
  }));
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
    const reason = row["失败原因"] ? `｜${row["失败原因"]}` : "";
    return `<div class="report-card">
      <div class="asin">${esc(row["父ASIN"])}</div>
      <div class="meta">${esc(row["商品名"])}</div>
      <div class="meta">${esc(row["异动指标"])}｜${esc(row["报告类型"])}｜${esc(row["诊断状态"] || "未生成")}${esc(reason)}</div>
      ${action}
    </div>`;
  }).join("");
}
function renderDonut(el, legend, high, review, labels = ["高优先级异动", "待复核异动"]) {
  const total = Math.max(0, high + review);
  const deg = total ? (high / total * 360) : 0;
  el.style.setProperty("--high-deg", `${deg}deg`);
  el.style.removeProperty("background");
  legend.innerHTML = `<div><span class="high"></span>${esc(labels[0])}：${high}</div><div><span class="review"></span>${esc(labels[1])}：${review}</div><div>合计：${total}</div>`;
}
function renderMetricCategoryDonut(el, legend, items) {
  const colors = ["var(--high)", "var(--review)", "var(--blue)"];
  const classes = ["traffic", "cvr", "both"];
  const total = items.reduce((sum, item) => sum + item.value, 0);
  if (!total) {
    el.style.background = "conic-gradient(rgba(255,255,255,.16) 0deg, rgba(255,255,255,.16) 360deg)";
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
  const high = rows.reduce((s,row) => s + Number(row["高优先级异动"] || 0), 0);
  const review = rows.reduce((s,row) => s + Number(row["待复核异动"] || 0), 0);
  renderBars(siteBars, aggregate(rows, "站点"), "total");
  renderBars(ownerHighBars, aggregate(rows, "负责人"), "high");
  renderBars(storeBars, aggregate(rows, "店铺"), "total");
  renderDonut(typeDonut, typeLegend, high, review);
  const metricRows = filteredDetails();
  const reviewRows = filteredReviewBaseDetails();
  renderMetricCategoryDonut(metricDonut, metricLegend, [
    { label:"流量异动", value:metricRows.filter(row => String(row["异动指标"]).trim() === "流量异动").length },
    { label:"转化率异动", value:metricRows.filter(row => String(row["异动指标"]).trim() === "转化率异动").length },
    { label:"流量+转化率异动", value:metricRows.filter(row => String(row["异动指标"]).trim() === "流量+转化率异动").length }
  ]);
  renderReviewReasons(reviewReasonBars, reviewRows);
  renderLine(aggregate(rows, "负责人"));
}
function renderSummary() {
  const rows = filteredSummaryRows();
  summaryTable.querySelector("tbody").innerHTML = rows.map(row => {
    const key = rowKey(row);
    return `<tr data-key="${esc(key)}" class="${key === selectedKey ? "selected" : ""}">
      <td>${esc(row["站点"])}</td><td>${esc(row["店铺"])}</td><td>${esc(row["负责人"])}</td>
      <td class="num link" data-scope="all">${esc(row["异动商品数"])}</td>
      <td class="num link status-high" data-scope="高优先级异动">${esc(row["高优先级异动"])}</td>
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
    <td>${esc(row["商品名"])}</td><td>${esc(row["异动指标"])}</td><td>${esc(row["当前值"])}</td><td>${esc(row["上月值"])}</td>
    <td>${esc(row["变化率"])}</td><td>${esc(row["历史判断"])}</td><td>${esc(reviewReason(row))}</td><td class="${row["最终状态"] === "高优先级异动" ? "status-high" : "status-review"}">${esc(row["最终状态"])}</td>
  </tr>`).join("");
}
function renderReviewDetails() {
  const rows = filteredReviewDetails();
  const reasonText = selectedReviewReason ? ` / ${selectedReviewReason}` : "";
  reviewDetailTitle.textContent = selectedKey ? `${selectedKey.replaceAll("||", " / ")}${reasonText}：${rows.length} 条待复核` : `待复核异动明细${reasonText}：${rows.length} 条`;
  reviewDetailTable.querySelector("tbody").innerHTML = rows.map(row => `<tr>
    <td>${esc(row["父ASIN"])}</td><td>${esc(row["商品名"])}</td><td>${esc(row["异动指标"])}</td>
    <td>${esc(row["变化率"])}</td><td>${esc(reviewReason(row))}</td><td>${esc(row["历史判断"])}</td>
  </tr>`).join("");
}
function renderButtons() { document.querySelectorAll("button[data-status]").forEach(btn => btn.classList.toggle("active", btn.dataset.status === selectedStatus)); }
function renderAll() { renderFilters(); renderCards(); renderVisuals(); renderDiagnosisReports(); renderSummary(); renderDetails(); renderReviewDetails(); renderButtons(); }
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
clearFilter.addEventListener("click", () => { selectedKey = ""; selectedStatus = ""; selectedSite = ""; selectedStore = ""; selectedOwner = ""; selectedReviewReason = ""; searchBox.value = ""; renderAll(); });
document.querySelectorAll("button[data-status]").forEach(btn => btn.addEventListener("click", () => { selectedStatus = selectedStatus === btn.dataset.status ? "" : btn.dataset.status; selectedKey = ""; renderAll(); }));
searchBox.addEventListener("input", () => { renderVisuals(); renderDiagnosisReports(); renderDetails(); renderReviewDetails(); });
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
$Shortcut = "[InternetShortcut]`r`nURL=$FileUri"
Set-Content -LiteralPath $ShortcutPath -Value $Shortcut -Encoding ASCII

$Manifest = [PSCustomObject]@{
    generated_at = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    style_reference = "https://github.com/yashsdoshi/Sales_report_using_PowerBi"
    style_name = "powerbi-sales-dashboard-inspired-v1"
    summary_rows = @($Summary).Count
    detail_rows = @($Details).Count
    total_anomaly_products = $Total
    high_priority = $High
    review_required = $Review
    owners = $OwnerCount
    output_files = [PSCustomObject]@{
        dashboard_html = $DashboardPath
        shortcut = $ShortcutPath
    }
}
$Manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $ManifestPath -Encoding UTF8
$Manifest | ConvertTo-Json -Depth 6
