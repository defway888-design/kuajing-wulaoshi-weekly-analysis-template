---
name: kuajing-wulaoshi-weekly-analysis
description: Build and operate the 跨境吴老师周数据分析 workflow for weekly parent-ASIN anomaly review. Use when Codex needs to calculate single-period or 30-day dual-window trend traffic/conversion anomalies, run high-priority ASIN diagnosis routing, generate Word diagnosis reports, generate 负责人BI and 异动明细BI outputs, split owner-only dashboards, package boss/owner email attachments, guide sender mailbox setup, configure weekly email delivery, or maintain the fixed rules, schemas, templates, and permissions for this branded workflow.
---

# 跨境吴老师周数据分析Skill

Use this skill to implement or operate the 跨境吴老师 weekly parent-ASIN anomaly workflow.

## Brand Ownership

This is the dedicated business-process skill for `跨境吴老师`.

Preserve the `跨境吴老师` brand in:

```text
skill name and display name
skill description
Codex progress messages
BI dashboard title
```

Do not add the brand prefix to:

```text
output file names
email subject lines
email attachment names
```

Do not place data-source tool names in the brand name, display name, or progress messages. Data-source details belong only in technical sections.

Default progress messages:

```text
跨境吴老师正在检查业务模板版本...
跨境吴老师正在获取业务数据...
跨境吴老师正在分析父商品流量与转化率异动...
跨境吴老师正在筛选30天趋势候选商品...
跨境吴老师正在判断30天双窗口趋势异动...
跨境吴老师正在识别高优先级ASIN...
跨境吴老师正在生成高优先级ASIN诊断报告...
跨境吴老师正在生成负责人汇总表...
跨境吴老师正在生成负责人BI...
跨境吴老师正在生成异动明细BI...
跨境吴老师正在准备老板汇总包...
跨境吴老师正在准备负责人专属附件...
跨境吴老师正在检查负责人邮箱...
跨境吴老师正在准备邮件发送...
跨境吴老师周数据分析已完成。
```

## Non-Negotiable Terms

- `负责人BI`: generated from `负责人汇总表`; management/full-scope dashboard.
- `异动明细BI`: generated from `异动明细表`; owner-specific detail dashboard.
- Do not rename these two dashboard types.
- Do not use old labels `真实异动数` or `人工复核数`.
- Use only `高优先级异动` and `待复核异动` as final statuses.
- Split `高优先级异动` into `当期高优先异动` and `缓慢高优先异动` with the `高优先级类型` field.
- `缓慢异动` / `30天双窗口趋势异动` belongs under `高优先级异动`, not `待复核异动`.

## Fixed Data Source

Use LingXing MCP:

```text
https://openmcp.lingxing.com/mcp-servers/lingxing-mcp
```

Require HTTPS. HTTP returns `405 Method Not Allowed`.

Use these MCP tools:

```text
get_my_sids
query_product_performance_asin_lists
```

Do not assume LingXing MCP can return owner emails. The current known toolset does not provide owner email or address-book lookup.

## Runtime Standard

Run the workflow directly in Codex.

Do not assume Windows Task Scheduler, a server, GitHub Actions, or a third-party scheduler unless the user explicitly changes the runtime.

GitHub public template repository:

```text
https://github.com/defway888-design/kuajing-wulaoshi-weekly-analysis-template
```

Do not require users to submit a GitHub username or accept a private-repository invitation for the standard installation flow.

Do not depend on a fixed local path such as:

```text
C:\Users\20085\
```

For local user paths, use the Codex default installation mechanism or resolve the current Windows user directory dynamically:

```powershell
$env:USERPROFILE
```

When writing user-facing docs, show local examples as:

```text
C:\Users\<your-windows-user-name>\...
```

Default runtime mode:

```text
试运行模式
```

In `试运行模式`:

```text
allow repeated manual analysis runs in Codex
generate tables and dashboards
allow test email only when explicitly requested
do not create a recurring automation
do not automatically send weekly formal email
```

Switch to `自动发送模式` only after the user explicitly asks to enable automatic weekly email delivery. A previous manual run, report generation, or sender mailbox setup does not count as authorization.

When the user authorizes automatic delivery, create or enable the Codex recurring automation with:

```text
first eligible run: the first Monday after authorization
weekly task start time: Monday 00:00
standard email send time: Monday 09:00
late-send rule: if processing is incomplete at 09:00, send immediately after processing and validation succeed
never send blocking-failed or unvalidated core outputs; auxiliary evidence gaps do not block sending
```

Track each reporting period with:

```text
reporting_period
task_started_at
analysis_completed_at
actual_sent_at
send_status: processing | ready | sent | failed
```

## Fixed Product Data Call

Call `query_product_performance_asin_lists` by `sid` and date range.

Fixed arguments:

```json
{
  "summary_field": "parent_asin",
  "turn_on_summary": 1,
  "date_type": "purchase",
  "currency_code": "CNY",
  "sort_field": "volume",
  "sort_type": "desc",
  "length": 500
}
```

Paginate with `offset` until `offset >= total` or the list is empty.

## Field Mapping And Blocking Rules

Do not require one fixed vendor field name when the MCP returns an equivalent semantic field. Normalize fields by meaning first, then record the mapping in `字段映射记录`.

Core fields are required for anomaly calculation and formal sending:

```text
站点
店铺
父ASIN
当前周期流量
当前周期订单量
上月周期流量
上月周期订单量
周期天数
当前周期日期范围
上月周期日期范围
```

If any core field is missing and cannot be mapped from an equivalent field, mark the row or run as `阻断失败` and `禁止发送`.

Auxiliary fields improve diagnosis quality but must not block table generation, BI generation, package generation, or formal sending:

```text
Seller ID
子ASIN
SKU
商品名
负责人
主图
五点
配送类型
站外推广证据
联盟客推广证据
严格相似竞品审核证据
```

When an auxiliary field or auxiliary evidence cannot be confirmed, record:

```text
核心诊断状态 = 可用但有证据缺口
可发送状态 = 允许发送
证据缺口类型
证据缺口说明
```

Default semantic mappings:

| Business meaning | Preferred field | Allowed equivalent fields | Blocking |
|---|---|---|---|
| 父ASIN | parent_asin | asin, asin1, parentAsin | yes |
| 子ASIN | asin1 | asin, child_asin | no |
| SKU | seller_sku | msku, sku | no |
| Seller ID | seller_id | sid, sellerId | no |
| 流量 | sessions | sessions_total, traffic | yes |
| 订单量 | order_count | volume, sales, units_ordered | yes |
| 商品名 | product_name | title, item_name | no |
| 负责人 | owner | principal_name, principal_names | no |
| 主图 | main_image | image, image_url | no |
| 五点 | bullet_points | bullets, features | no |
| 配送类型 | fulfillment_type | delivery_type, fulfillment | no |

## Fixed Analysis Logic

Analyze all accessible parent ASINs.

Exclude invalid parent ASIN values:

```text
empty
-
invalid
```

Periods:

```text
current period: month day 1 through T-3
previous period: previous month day 1 through same day count
historical current: same period last year
historical previous: previous-month comparison period last year
```

The four periods must use the same day count. Never compare a partial current month with a full previous month.

Traffic:

```text
sessions_total daily average
```

Conversion:

```text
weighted period conversion rate = period total volume / period total sessions_total
```

If the MCP returns `cvr`, use it only when it is known to be calculated as total volume / total sessions_total for the full period.

Fallback when period `cvr` is unavailable or not trustworthy:

```text
volume / sessions_total
```

Anomaly thresholds:

```text
traffic absolute change >= 30%
conversion absolute change >= 50%
```

30-day dual-window trend anomaly:

Use this only as a second-layer check after a parent ASIN does not trigger the single-period anomaly thresholds above.

Candidate pool:

```text
10% <= traffic absolute change < 30%
or
20% <= conversion absolute change < 50%
```

If a parent ASIN does not enter this candidate pool, do not run the 30-day trend calculation.

Trend query principle:

```text
use date-range summaries from query_product_performance_asin_lists
do not require daily-granularity output
recent 30-day observation window ending at T-3
early window = first 7 days in that 30-day window
late window = last 7 days in that 30-day window
middle 16 days = not used for calculation, reserved only as buffer/context
```

Trend comparison:

```text
traffic trend change = late-window daily average traffic vs early-window daily average traffic
conversion trend change = late-window weighted conversion vs early-window weighted conversion
```

Trend anomaly thresholds reuse the fixed anomaly thresholds:

```text
traffic absolute trend change >= 30%
conversion absolute trend change >= 50%
```

Trend history check:

```text
compare the same early/late 7-day windows in the corresponding 30-day period last year
use the same history tolerances as the single-period rule
history must explain the movement magnitude, not only direction
```

Trend anomaly output fields:

```text
异动识别方式 = 30天双窗口趋势异动
趋势候选原因 = 流量接近阈值 / 转化率接近阈值 / 流量+转化率同时接近阈值
趋势判断窗口 = 最近30天前7天 vs 后7天
最终状态 = 高优先级异动
高优先级类型 = 缓慢高优先异动
```

For 30-day dual-window trend anomalies, `无历史数据`, `低样本`, `从0新增`, and `负责人变更` are diagnosis attention notes written into `历史判断`; they do not change the row to `待复核异动`.

Single-period anomaly output fields:

```text
异动识别方式 = 单周期异动
趋势候选原因 = empty
趋势判断窗口 = empty
```

History check:

```text
traffic tolerance: +/-10 percentage points
conversion tolerance: +/-15 percentage points
```

History must compare movement magnitude, not direction only.

Single-period low sample rule:

```text
if current daily average traffic <= 10 or previous daily average traffic <= 10,
and an anomaly threshold is triggered,
classify as 待复核异动 with 历史判断 = 样本不足，需人工复核
```

Single-period previous value zero rule:

```text
previous value = 0 and current value > 0 -> mark change as 从0新增, classify as 待复核异动
previous value > 0 and current value = 0 -> mark change as -100%, continue anomaly judgment
previous value = 0 and current value = 0 -> not an anomaly
```

Single-period owner transition rule:

```text
compare owner_key by site + store + parent_asin between the current period and previous period
owner_key priority: principal_uid/principal_uids first, normalized principal_names second
multiple owners must be sorted and joined before comparison
```

If the owner changed between the previous period and the current period:

```text
do not classify the triggered anomaly as 高优先级异动
classify as 待复核异动
历史判断 = 负责人变更：上期{previous_owner} -> 本期{current_owner}，需确认交接或运营动作影响
```

If the previous owner left:

```text
send the owner-specific detail package only to the current owner
do not send to the departed previous owner
if the current owner has no mapped email, prompt for the current owner email
if the current owner is empty or 未分配, route to the boss management email with role = manager_proxy
```

If history explains the movement, exclude the product from all outputs.

If history exists but does not explain it:

```text
高优先级异动
```

If no historical comparable data exists for a single-period anomaly:

```text
待复核异动
```

Never use rolling 4-week/8-week or category fallback in the current standard.

## High-Priority ASIN Deep Diagnosis

Only deep-diagnose rows where:

```text
最终状态 = 高优先级异动
```

High-priority diagnosis includes both:

```text
高优先级类型 = 当期高优先异动
高优先级类型 = 缓慢高优先异动
```

30-day dual-window trend anomalies must enter this diagnosis flow as `缓慢高优先异动`.

Dispatch strictly by `异动指标`:

```text
流量异动 -> call 跨境吴老师流量异动数据分析Skill only
转化率异动 -> call 跨境吴老师转化率异动数据分析Skill only
流量+转化率异动 -> call both Skills and produce one combined report
```

Do not call both diagnosis Skills for every high-priority ASIN. The diagnosis Skills consume substantial compute, so the trigger must match the anomaly type.

Diagnosis Skill repositories:

```text
traffic: https://github.com/defway888-design/kuajing-wulaoshi-amazon-traffic-anomaly-skil
conversion: https://github.com/defway888-design/kuajing-wulaoshi-amazon-conversion-anomaly-skill
```

Output one standalone Word report per high-priority ASIN:

```text
diagnosis_reports/{reporting_period}/{site}_{store}_{owner}_{parent_asin}_{metric_type}.docx
```

Create a diagnosis index:

```text
高优先级ASIN诊断报告索引.csv
```

Required index columns:

```text
站点
店铺
负责人
父ASIN
商品名
异动指标
高优先级类型
诊断状态
核心诊断状态
可发送状态
报告类型
摘要页地址
Word报告地址
证据缺口类型
证据缺口说明
字段映射记录
失败原因
阻断原因
```

Allowed `诊断状态` values:

```text
已完成
部分完成
诊断失败
未生成
```

Allowed `核心诊断状态` values:

```text
完整完成
可用但有证据缺口
阻断失败
未生成
```

Allowed `可发送状态` values:

```text
允许发送
禁止发送
```

Status rules:

```text
核心诊断状态 = 完整完成 -> 可发送状态 = 允许发送
核心诊断状态 = 可用但有证据缺口 -> 可发送状态 = 允许发送
核心诊断状态 = 阻断失败 or 未生成 -> 可发送状态 = 禁止发送
```

If a diagnosis Skill call fails:

```text
record 诊断失败
set 核心诊断状态 = 阻断失败
set 可发送状态 = 禁止发送
write the failure reason into 高优先级ASIN诊断报告索引.csv
do not fabricate a Word report
show the failed ASIN in BI with the failure status
include a manual-review note in the owner email
```

If Seller ID, main image, five bullet points, fulfillment type, off-site promotion evidence, affiliate promotion evidence, or strict similar-competitor review cannot be confirmed:

```text
do not mark the diagnosis as blocked
set 核心诊断状态 = 可用但有证据缺口
set 可发送状态 = 允许发送
write the missing item into 证据缺口类型 and 证据缺口说明
show the evidence gap in BI and email body
```

If multiple owners share one ASIN:

```text
generate the ASIN diagnosis once
reuse the same report in every current owner's package
send to all current mapped owners
```

If owner is empty or `未分配`:

```text
do not send an owner-specific email
show it in 负责人BI
route handling to the boss management package
mark recipient role as manager_proxy
```

## Fixed Output Tables

### 负责人汇总表

File:

```text
负责人汇总表_优先级命名.csv
```

Columns:

```text
站点
店铺
负责人
异动商品数
高优先级异动
当期高优先异动
缓慢高优先异动
待复核异动
```

Invariant:

```text
高优先级异动 = 当期高优先异动 + 缓慢高优先异动
异动商品数 = 高优先级异动 + 待复核异动
```

### 异动明细表

File:

```text
异动明细表_优先级命名.csv
```

Columns:

```text
站点
店铺
负责人
父ASIN
商品名
异动指标
当前值
上月值
变化率
异动识别方式
趋势候选原因
趋势判断窗口
历史判断
待复核原因
最终状态
高优先级类型
```

Allowed `最终状态` values:

```text
高优先级异动
待复核异动
```

## Dashboard Rules

### 异动明细BI

The current purple PowerBI-style template is approved.

Do not modify it unless the user explicitly asks to modify 异动明细BI.

Owner-specific 异动明细BI must embed only that owner’s data. Do not send a full dashboard with a default owner filter.

When generating the owner-facing operational 异动明细BI, include visible `待复核异动统计` and `待复核异动明细` modules, and include a `待复核原因` column in the detail table.

Also include `高优先级ASIN诊断报告入口` above `待复核异动统计` and `待复核异动明细`.

The operational 异动明细BI must not display the old `负责人汇总与异动明细` module.

The BI must not display this text:

```text
BI只展示入口，报告独立打开
```

Long diagnosis text is never placed directly inside the BI. The BI shows high-priority ASIN entries and opens the independent diagnosis summary/report path when the user clicks `查看报告`.

The reason logic must be dynamic:

```text
known review reasons:
- 从0新增
- 低样本
- 负责人变更
- 无历史数据

future review reasons:
- derive the display label from 历史判断
- do not hide or collapse unknown reasons
- show the new reason text in 待复核异动统计, 待复核异动明细, and in the full detail table
```

### 负责人BI

Use the visual style direction from:

```text
https://github.com/shrewsendlessmer84/powerbi-full-panel-2026
```

负责人BI must use the following fixed visual card order:

```text
1. 标题卡片
2. 站点 / 店铺 / 负责人筛选器
3. KPI 卡片
4. 异动类型占比
5. 高优先异动分类占比
6. 待复核异动分类占比
7. 异动指标 by 类型
8. 异动商品数 by 站点
9. 异动商品数 by 店铺
10. 异动商品数 by 负责人
11. 高优先级ASIN诊断报告入口
12. 负责人汇总表
13. 异动明细表
```

The top `高优先级异动` KPI card must match the same format as `异动商品数` and `待复核异动`: show only the number and label. Do not place `当期 / 缓慢` subtext inside that KPI card.

The `高优先级ASIN诊断报告入口` module must include local filters for `站点`, `店铺`, and `运营人员` so management can narrow a large diagnosis-report list without losing the dashboard overview.

Forbidden in 负责人BI:

```text
Executive Overview
Owner Summary
Risk Split
Drilldown Table
any invented extra module
```

Dashboard title:

```text
跨境吴老师
周数据分析看板
```

Font:

```css
font-family: "Microsoft YaHei", Arial, sans-serif;
```

## Email Delivery

Use the boss-provided sender mailbox for all outgoing email.

The sender mailbox belongs to the boss/customer. It may be configured by the boss directly or with implementation assistance. Do not use an implementer-owned mailbox or third-party default sender as the standard sending identity.

The system maintains one management recipient mailbox only:

```text
boss name / remark
boss management email
send test email: yes/no
```

This management mailbox receives:

```text
老板汇总包
```

Boss package rules:

```text
default: send one complete zip package
package name pattern: {reporting_period}_运营数据汇总.zip
complete package includes 负责人BI, summary/detail tables, diagnosis index, ASIN diagnosis summary pages, and full Word diagnosis reports
if complete package exceeds the usable sender attachment threshold, automatically send a light summary package
light package includes 负责人BI, summary/detail tables, diagnosis index, and ASIN diagnosis summary pages only
```

Boss BI links must be relative paths inside the zip package. The boss should download and unzip the package first, then open the BI. In the light package, BI report links open the ASIN diagnosis summary page, not the full Word report.

Do not maintain extra management recipients, CC rules, or management forwarding rules in the workflow. If other managers need the report, the boss handles forwarding in their own mailbox.

Each owner receives:

```text
that owner’s 异动明细表
that owner’s 异动明细BI
that owner’s high-priority ASIN Word diagnosis reports
```

Owner dashboards must not contain other owners’ data.

Owner attachment rules:

```text
few reports and under threshold -> attach Word reports one by one
too many reports or over threshold -> compress that owner’s Word reports into one zip
if the owner package still exceeds threshold -> send the owner BI/detail data plus a manual follow-up note
```

Attachment size threshold:

```text
detect sender provider during setup
verify the current official attachment rule for that provider
usable threshold = official max attachment size * configured safety ratio
default safety ratio = 0.70
unknown provider -> require manual threshold confirmation before automatic formal sending
```

## Sender Mailbox Setup Routing

During sender mailbox setup, ask for the sender email address first. Detect the provider from the email domain and show only the matching setup guide.

Routing:

```text
@qq.com -> QQ mailbox authorization-code guide
@163.com / @126.com / @yeah.net -> NetEase mailbox authorization-code guide
@outlook.com / @hotmail.com / Microsoft 365 -> Microsoft official authorization guide
@gmail.com / Google Workspace -> Google official authorization guide
recognized enterprise provider -> matching enterprise-mail guide
unknown custom domain -> ask for provider selection; expose custom SMTP only as a fallback or implementation-assisted path
```

Required interaction:

```text
1. enter sender email
2. detect mailbox provider
3. show the matching guide and official provider entry link
4. complete provider-side authorization
5. enter authorization result only in the secure setup flow, never in chat
6. auto-load SMTP/OAuth preset
7. send test email
8. mark sender mailbox as configured only after the test succeeds
```

Keep provider guide text and official links in a versioned preset file. Do not hard-code volatile provider-page paths into the core workflow.

## Owner Email Mapping

Because LingXing MCP does not expose owner emails, maintain recipient mapping for owner mailboxes:

```text
config/owner_email_map.csv
config/recipient_config.json
```

On every run:

```text
1. extract current owners from 异动明细表
2. compare against owner_email_map.csv
3. prompt for missing/new/inactive owners
4. save valid email with active = 1
5. allow skip, manager, quit
```

Input commands:

```text
valid email: save and enable
skip: skip this owner this run and prompt again next run
manager: send this owner package to management email
quit: stop without sending
```

## Validation Checklist

Always validate:

```text
汇总表异动商品数合计 = 明细表行数
each summary row: 异动商品数 = 高优先级异动 + 待复核异动
each summary row: 高优先级异动 = 当期高优先异动 + 缓慢高优先异动
最终状态 only uses allowed values
异动明细表 includes 异动识别方式 / 趋势候选原因 / 趋势判断窗口
30天双窗口趋势异动 only runs for the locked candidate pool
30天双窗口趋势异动 rows must include 趋势候选原因 and 趋势判断窗口
30天双窗口趋势异动 rows must have 最终状态 = 高优先级异动 and 高优先级类型 = 缓慢高优先异动
负责人BI contains no forbidden modules
异动明细BI was not modified unless explicitly requested
owner-specific HTML contains no other owner data
dropdowns contain site/store/owner options
if 高优先级异动 > 0 in formal-send mode, 高优先级ASIN诊断报告索引.csv exists
diagnosis index rows match high-priority ASIN scope
BI report links use relative package paths, not absolute local paths
老板完整包 or 老板轻量包 is selected by provider attachment threshold
owner emails include only that owner’s data and allowed diagnosis attachments
```

## Packaged Resources

Use the packaged scripts when rendering or validating outputs:

```text
scripts/generate_lingxing_manager_full_panel_dashboard.ps1
scripts/generate_lingxing_powerbi_style_dashboard.ps1
scripts/generate_lingxing_owner_powerbi_dashboard.ps1
scripts/validate_weekly_analysis_outputs.ps1
```

Use `references/trend-anomaly-flow.md` for the locked 30-day dual-window trend anomaly logic.

The `lingxing` text in script file names is technical implementation detail only. Do not expose it as the skill brand.

On Windows PowerShell 5, load UTF-8 scripts explicitly before invocation:

```powershell
$code = Get-Content -LiteralPath "<script-path>" -Raw -Encoding UTF8
$script = [ScriptBlock]::Create($code)
& $script -OutputDir "<runtime-output-dir>"
```

Use:

```text
config/runtime_config.example.json
config/email_provider_presets.example.json
template_manifest.json
```

as schemas and examples only. Copy them into runtime-local configuration before use. Never write secrets, recipient emails, customer data, logs, or generated reports into the skill directory or the online template repository.

## References

Read these only when needed:

- `references/business-spec.md`: full business specification.
- `references/email-flow.md`: email distribution and owner email entry flow.
- `references/email-provider-routing.md`: sender mailbox provider detection and guided setup.
- `references/high-priority-diagnosis-flow.md`: high-priority ASIN diagnosis, Word reports, BI links, and package rules.
- `references/online-template-distribution.md`: multi-user online template distribution model.
