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
if (-not (Test-Path -LiteralPath $SummaryPath)) { throw "缺少负责人汇总表：$SummaryPath" }
if (-not (Test-Path -LiteralPath $DetailPath)) { throw "缺少异动明细表：$DetailPath" }

function HtmlEscape([string]$Value) {
    if ($null -eq $Value) { return "" }
    return $Value.Replace("&", "&amp;").Replace("<", "&lt;").Replace(">", "&gt;").Replace('"', "&quot;")
}

$Summary = Import-Csv -LiteralPath $SummaryPath
$Details = Import-Csv -LiteralPath $DetailPath

$SummaryJson = ($Summary | ConvertTo-Json -Depth 8 -Compress).Replace("<", "\u003c")
$DetailsJson = ($Details | ConvertTo-Json -Depth 8 -Compress).Replace("<", "\u003c")

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
  grid-template-columns:.95fr 1fr 1.55fr;
  gap:14px;
}
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
  .title-card h1 { font-size:26px; }
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
    <div class="panel"><h2>异动商品数 by 站点</h2><div class="bar-chart" id="siteBars"></div></div>
    <div class="panel"><h2>异动类型占比</h2><div class="donut-wrap"><div class="donut" id="typeDonut"></div><div class="legend" id="typeLegend"></div></div></div>
    <div class="panel"><h2>高优先级异动 by 负责人</h2><div class="bar-chart" id="ownerHighBars"></div></div>
  </section>

  <section class="lower-grid">
    <div class="panel"><h2>异动指标 by 类型</h2><div class="donut-wrap"><div class="donut" id="metricDonut"></div><div class="legend" id="metricLegend"></div></div></div>
    <div class="panel"><h2>异动商品数 by 店铺</h2><div class="bar-chart" id="storeBars"></div></div>
    <div class="panel"><h2>异动走势 by 负责人排序</h2><div class="line-chart" id="ownerLine"></div></div>
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
      <div class="table-wrap"><table id="summaryTable"><thead><tr><th>站点</th><th>店铺</th><th>负责人</th><th class="num">异动商品数</th><th class="num">高优先级异动</th><th class="num">待复核异动</th></tr></thead><tbody></tbody></table></div>
      <div class="detail-title" id="detailTitle">当前显示全部明细</div>
      <div class="table-wrap detail"><table id="detailTable"><thead><tr><th>站点</th><th>店铺</th><th>负责人</th><th>父ASIN</th><th class="product">商品名</th><th>异动指标</th><th>当前值</th><th>上月值</th><th>变化率</th><th>历史判断</th><th>最终状态</th></tr></thead><tbody></tbody></table></div>
    </div>
  </section>
</main>

<script>
const summary = __SUMMARY_JSON__;
const details = __DETAILS_JSON__;
let selectedKey = "";
let selectedStatus = "";
let selectedSite = "";
let selectedStore = "";
let selectedOwner = "";
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
const ownerLine = document.getElementById("ownerLine");
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
    return `<div class="bar-row"><div title="${esc(row.label)}">${esc(String(row.label).slice(0,12))}</div><div class="bar-track"><div class="bar-fill" style="width:${Math.max(2, val / max * 100)}%"></div></div><div class="num">${val}</div></div>`;
  }).join("") : `<div>无数据</div>`;
}
function renderDonut(el, legend, high, review, labels = ["高优先级异动", "待复核异动"]) {
  const total = Math.max(0, high + review);
  const deg = total ? (high / total * 360) : 0;
  el.style.setProperty("--high-deg", `${deg}deg`);
  legend.innerHTML = `<div><span class="high"></span>${esc(labels[0])}：${high}</div><div><span class="review"></span>${esc(labels[1])}：${review}</div><div>合计：${total}</div>`;
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
  const traffic = metricRows.filter(row => String(row["异动指标"]).includes("流量")).length;
  const cvr = metricRows.filter(row => String(row["异动指标"]).includes("转化率")).length;
  renderDonut(metricDonut, metricLegend, traffic, cvr, ["流量异动", "转化率异动"]);
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
    <td>${esc(row["商品名"])}</td><td>${esc(row["异动指标"])}</td><td>${esc(row["当前值"])}</td>
    <td>${esc(row["上月值"])}</td><td>${esc(row["变化率"])}</td><td>${esc(row["历史判断"])}</td><td class="${row["最终状态"] === "高优先级异动" ? "status-high" : "status-review"}">${esc(row["最终状态"])}</td>
  </tr>`).join("");
}
function renderButtons() { document.querySelectorAll("button[data-status]").forEach(btn => btn.classList.toggle("active", btn.dataset.status === selectedStatus)); }
function renderAll() { renderFilters(); renderCards(); renderVisuals(); renderSummary(); renderDetails(); renderButtons(); }
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
clearFilter.addEventListener("click", () => { selectedKey = ""; selectedStatus = ""; selectedSite = ""; selectedStore = ""; selectedOwner = ""; searchBox.value = ""; renderAll(); });
document.querySelectorAll("button[data-status]").forEach(btn => btn.addEventListener("click", () => { selectedStatus = selectedStatus === btn.dataset.status ? "" : btn.dataset.status; selectedKey = ""; renderAll(); }));
searchBox.addEventListener("input", renderDetails);
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
    Replace("__DETAILS_JSON__", $DetailsJson)

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
