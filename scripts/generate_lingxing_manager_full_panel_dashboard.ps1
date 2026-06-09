param(
    [string]$OutputDir
)

$ErrorActionPreference = "Stop"
$ScriptDir = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($ScriptDir)) { $ScriptDir = Join-Path (Get-Location) "scripts" }
$Root = Resolve-Path (Join-Path $ScriptDir "..")
$OutDir = if ([string]::IsNullOrWhiteSpace($OutputDir)) { Join-Path $Root "runtime_output" } else { $OutputDir }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$SummaryPath = Join-Path $OutDir "负责人汇总表_优先级命名.csv"
$DetailPath = Join-Path $OutDir "异动明细表_优先级命名.csv"
if (-not (Test-Path -LiteralPath $SummaryPath)) { throw "缺少负责人汇总表：$SummaryPath" }
if (-not (Test-Path -LiteralPath $DetailPath)) { throw "缺少异动明细表：$DetailPath" }

function HtmlEscape([string]$Value) {
    if ($null -eq $Value) { return "" }
    return $Value.Replace("&", "&amp;").Replace("<", "&lt;").Replace(">", "&gt;").Replace('"', "&quot;")
}

$Summary = @(Import-Csv -LiteralPath $SummaryPath)
$Details = @(Import-Csv -LiteralPath $DetailPath)
$SummaryJson = ($Summary | ConvertTo-Json -Depth 8 -Compress).Replace("<", "\u003c")
$DetailsJson = ($Details | ConvertTo-Json -Depth 8 -Compress).Replace("<", "\u003c")
$Total = ($Summary | Measure-Object -Property "异动商品数" -Sum).Sum
$High = ($Summary | Measure-Object -Property "高优先级异动" -Sum).Sum
$Review = ($Summary | Measure-Object -Property "待复核异动" -Sum).Sum
$DashboardPath = Join-Path $OutDir "manager_dashboard_full_panel.html"
$ShortcutPath = Join-Path $OutDir "open_manager_dashboard.url"
$ManifestPath = Join-Path $OutDir "manager_full_panel_manifest.json"

$Html = @"
<!doctype html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<title>负责人BI</title>
<style>
*{box-sizing:border-box}body{margin:0;background:#f3f6fb;color:#1d2433;font-family:"Microsoft YaHei",Arial,sans-serif}.top{background:#172033;color:#fff;padding:28px 36px}.top h1{margin:0;font-size:34px;line-height:1.25}.wrap{padding:24px;max-width:1500px;margin:0 auto}.grid{display:grid;grid-template-columns:repeat(12,1fr);gap:16px}.card{background:#fff;border:1px solid #dce3ef;border-radius:8px;padding:16px;box-shadow:0 6px 16px rgba(18,34,56,.06)}.filters{grid-column:span 12;display:flex;gap:12px;align-items:end}.kpi{grid-column:span 4}.kpi .num{font-size:38px;font-weight:800;color:#1d4ed8}.chart{grid-column:span 6}.table-card{grid-column:span 12}label{display:block;font-size:13px;color:#667085;margin-bottom:6px}select,input,button{font-family:inherit;border:1px solid #cbd5e1;border-radius:6px;padding:9px 10px;background:#fff}button{cursor:pointer}.active{background:#1d4ed8;color:#fff}table{width:100%;border-collapse:collapse;font-size:13px}th,td{border-bottom:1px solid #e6ebf2;padding:9px;text-align:left}th{background:#f8fafc;color:#334155}.num{text-align:right}.bar{height:18px;background:#dbeafe;border-radius:20px;overflow:hidden}.bar span{display:block;height:100%;background:#1d4ed8}.status-high{color:#dc2626;font-weight:700}.status-review{color:#d97706;font-weight:700}@media(max-width:900px){.filters{display:block}.filters>*{margin:8px 0}.kpi,.chart{grid-column:span 12}}
</style>
</head>
<body>
<header class="top"><h1>跨境吴老师<br>周数据分析看板</h1></header>
<main class="wrap">
<section class="grid">
<div class="card filters">
  <div><label>站点</label><select id="siteFilter"><option value="">全部站点</option></select></div>
  <div><label>店铺</label><select id="storeFilter"><option value="">全部店铺</option></select></div>
  <div><label>负责人</label><select id="ownerFilter"><option value="">全部负责人</option></select></div>
  <div><label>搜索</label><input id="searchBox" placeholder="父ASIN / 商品名"></div>
  <button id="clearFilter">清空</button>
</div>
<div class="card kpi"><div>异动商品数</div><div class="num" id="totalCard">$Total</div></div>
<div class="card kpi"><div>高优先级异动</div><div class="num" id="highCard">$High</div></div>
<div class="card kpi"><div>待复核异动</div><div class="num" id="reviewCard">$Review</div></div>
<div class="card chart"><h3>异动商品数 by 站点</h3><div id="siteBars"></div></div>
<div class="card chart"><h3>高优先级异动 by 负责人</h3><div id="ownerBars"></div></div>
<div class="card table-card"><h3>负责人汇总表</h3><table id="summaryTable"><thead><tr><th>站点</th><th>店铺</th><th>负责人</th><th class="num">异动商品数</th><th class="num">高优先级异动</th><th class="num">待复核异动</th></tr></thead><tbody></tbody></table></div>
<div class="card table-card"><h3 id="detailTitle">异动明细表</h3><table id="detailTable"><thead><tr><th>站点</th><th>店铺</th><th>负责人</th><th>父ASIN</th><th>商品名</th><th>异动指标</th><th>当前值</th><th>上月值</th><th>变化率</th><th>历史判断</th><th>最终状态</th></tr></thead><tbody></tbody></table></div>
</section>
</main>
<script>
const summary = $SummaryJson;
const details = $DetailsJson;
let selectedKey = "";
function esc(v){return String(v??"").replace(/[&<>"']/g,ch=>({"&":"&amp;","<":"&lt;",">":"&gt;","\"":"&quot;","'":"&#39;"}[ch]));}
function uniq(rows,f){return [...new Set(rows.map(r=>r[f]).filter(Boolean))].sort((a,b)=>String(a).localeCompare(String(b),'zh-Hans-CN'));}
function pass(r){return (!siteFilter.value||r['站点']===siteFilter.value)&&(!storeFilter.value||r['店铺']===storeFilter.value)&&(!ownerFilter.value||r['负责人']===ownerFilter.value);}
function key(r){return [r['站点'],r['店铺'],r['负责人']].join('||');}
function fill(sel,values,label){const old=sel.value;sel.innerHTML='<option value="">'+label+'</option>'+values.map(v=>'<option value="'+esc(v)+'">'+esc(v)+'</option>').join('');sel.value=values.includes(old)?old:'';}
function filters(){fill(siteFilter,uniq(summary,'站点'),'全部站点');fill(storeFilter,uniq(summary.filter(r=>!siteFilter.value||r['站点']===siteFilter.value),'店铺'),'全部店铺');fill(ownerFilter,uniq(summary.filter(r=>(!siteFilter.value||r['站点']===siteFilter.value)&&(!storeFilter.value||r['店铺']===storeFilter.value)),'负责人'),'全部负责人');}
function agg(rows,field,value){const m=new Map();rows.forEach(r=>{const k=r[field]||'未分配';m.set(k,(m.get(k)||0)+Number(r[value]||0));});return [...m.entries()].sort((a,b)=>b[1]-a[1]);}
function bars(el,rows){const max=Math.max(1,...rows.map(x=>x[1]));el.innerHTML=rows.slice(0,8).map(x=>'<div style="display:grid;grid-template-columns:110px 1fr 42px;gap:8px;margin:9px 0"><div>'+esc(x[0])+'</div><div class="bar"><span style="width:'+Math.max(3,x[1]/max*100)+'%"></span></div><div class="num">'+x[1]+'</div></div>').join('')||'无数据';}
function render(){filters();const rows=summary.filter(pass);totalCard.textContent=rows.reduce((s,r)=>s+Number(r['异动商品数']||0),0);highCard.textContent=rows.reduce((s,r)=>s+Number(r['高优先级异动']||0),0);reviewCard.textContent=rows.reduce((s,r)=>s+Number(r['待复核异动']||0),0);bars(siteBars,agg(rows,'站点','异动商品数'));bars(ownerBars,agg(rows,'负责人','高优先级异动'));summaryTable.tBodies[0].innerHTML=rows.map(r=>'<tr data-key="'+esc(key(r))+'"><td>'+esc(r['站点'])+'</td><td>'+esc(r['店铺'])+'</td><td>'+esc(r['负责人'])+'</td><td class="num">'+esc(r['异动商品数'])+'</td><td class="num status-high">'+esc(r['高优先级异动'])+'</td><td class="num status-review">'+esc(r['待复核异动'])+'</td></tr>').join('');summaryTable.querySelectorAll('tbody tr').forEach(tr=>tr.onclick=()=>{selectedKey=tr.dataset.key;renderDetails();});renderDetails();}
function renderDetails(){const q=searchBox.value.trim().toLowerCase();let rows=details.filter(r=>pass(r)&&(!selectedKey||key(r)===selectedKey));if(q)rows=rows.filter(r=>String(r['父ASIN']).toLowerCase().includes(q)||String(r['商品名']).toLowerCase().includes(q));detailTitle.textContent='异动明细表：'+rows.length+' 条';detailTable.tBodies[0].innerHTML=rows.map(r=>'<tr><td>'+esc(r['站点'])+'</td><td>'+esc(r['店铺'])+'</td><td>'+esc(r['负责人'])+'</td><td>'+esc(r['父ASIN'])+'</td><td>'+esc(r['商品名'])+'</td><td>'+esc(r['异动指标'])+'</td><td>'+esc(r['当前值'])+'</td><td>'+esc(r['上月值'])+'</td><td>'+esc(r['变化率'])+'</td><td>'+esc(r['历史判断'])+'</td><td class="'+(r['最终状态']==='高优先级异动'?'status-high':'status-review')+'">'+esc(r['最终状态'])+'</td></tr>').join('');}
[siteFilter,storeFilter,ownerFilter].forEach(x=>x.onchange=()=>{selectedKey='';render();});searchBox.oninput=renderDetails;clearFilter.onclick=()=>{siteFilter.value='';storeFilter.value='';ownerFilter.value='';searchBox.value='';selectedKey='';render();};render();
</script>
</body>
</html>
"@

Set-Content -LiteralPath $DashboardPath -Value $Html -Encoding UTF8
$FileUri = "file:///" + ($DashboardPath -replace "\\", "/" -replace " ", "%20")
Set-Content -LiteralPath $ShortcutPath -Value "[InternetShortcut]`r`nURL=$FileUri" -Encoding ASCII
$Manifest = [PSCustomObject]@{ generated_at=(Get-Date).ToString("yyyy-MM-dd HH:mm:ss"); dashboard_name="负责人BI"; style_name="manager-full-panel-style-same-modules-v1"; summary_rows=@($Summary).Count; detail_rows=@($Details).Count; total_anomaly_products=$Total; high_priority=$High; review_required=$Review; output_files=[PSCustomObject]@{ manager_dashboard_html=$DashboardPath; shortcut=$ShortcutPath } }
$Manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $ManifestPath -Encoding UTF8
$Manifest | ConvertTo-Json -Depth 6
