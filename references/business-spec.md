# 跨境吴老师周数据分析 Business Specification

Source of truth summary for the 跨境吴老师 weekly BI workflow.

## Data Source

Use LingXing MCP over HTTPS:

```text
https://openmcp.lingxing.com/mcp-servers/lingxing-mcp
```

Tools:

```text
get_my_sids
query_product_performance_asin_lists
```

## Runtime

Run the workflow directly in Codex.

GitHub private template repository:

```text
https://github.com/defway888-design/kuajing-wulaoshi-weekly-analysis-template
```

Default mode:

```text
试运行模式
```

Trial mode rules:

```text
allow repeated manual anomaly-analysis runs so the user can learn and verify the workflow
generate tables and BI dashboards
do not create a recurring automation
do not send formal weekly email automatically
allow test email only when explicitly requested
```

Automatic mode is enabled only when the user explicitly asks to enable automatic weekly email delivery. Manual analysis, dashboard generation, sender mailbox configuration, and test email do not imply automatic-send authorization.

Automatic mode schedule:

```text
first eligible run: first Monday after the user authorizes automatic delivery
weekly task start time: Monday 00:00
standard email send time: Monday 09:00
if processing is incomplete at 09:00: send immediately after processing and validation succeed
if processing fails or validation fails: do not send incomplete reports
```

Track:

```text
reporting_period
task_started_at
analysis_completed_at
actual_sent_at
send_status: processing | ready | sent | failed
```

## Data Calls

Use `get_my_sids` to get `sid`, store name, and site.

Use `query_product_performance_asin_lists` by `sid` and period:

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

Paginate by offset.

## Periods

```text
current: month day 1 to T-3
previous: previous month day 1 to same day count
historical current: same current period last year
historical previous: same previous comparison period last year
```

All comparison periods must use the same day count. Do not compare a partial current month against a full previous month.

## Metrics

Traffic:

```text
sessions_total daily average
```

Conversion:

```text
weighted period conversion rate = period total volume / period total sessions_total
```

Fallback:

```text
volume / sessions_total
```

Only use MCP `cvr` when it is known to be calculated for the whole period as total volume / total sessions_total. Otherwise calculate conversion from period totals.

## Thresholds

```text
traffic absolute change >= 30%
conversion absolute change >= 50%
```

History tolerance:

```text
traffic +/-10 percentage points
conversion +/-15 percentage points
```

History comparison must compare change magnitude within tolerance, not direction only.

Low sample rule:

```text
current daily average traffic <= 10 or previous daily average traffic <= 10
and threshold is triggered -> 待复核异动
历史判断 = 样本不足，需人工复核
```

Previous value zero rule:

```text
previous value = 0 and current value > 0 -> 从0新增, 待复核异动
previous value > 0 and current value = 0 -> -100%, continue anomaly judgment
previous value = 0 and current value = 0 -> not an anomaly
```

## Owner Transition

Purpose:

```text
detect whether a triggered anomaly may be caused by owner resignation, reassignment, or handover instead of product performance alone
```

Detection key:

```text
site + store + parent_asin
```

Owner comparison key:

```text
prefer principal_uid / principal_uids
fallback to normalized principal_names
if multiple owners exist, sort and join before comparison
```

Judgment:

```text
previous owner = current owner -> continue normal history judgment
previous owner != current owner -> 待复核异动
```

History judgment text:

```text
负责人变更：上期{previous_owner} -> 本期{current_owner}，需确认交接或运营动作影响
```

Send rule:

```text
owner-specific report is sent to the current owner only
departed previous owner does not receive the report
if current owner email is missing, prompt for the current owner email
if current owner is empty or 未分配, route to the boss management email with role = manager_proxy
```

## Final Status

Use only:

```text
高优先级异动
待复核异动
```

Rules:

```text
history exists and cannot explain movement -> 高优先级异动
no historical comparable data -> 待复核异动
history explains movement -> exclude from output
```

## High-Priority ASIN Diagnosis

Only rows with:

```text
最终状态 = 高优先级异动
```

enter deep diagnosis.

Dispatch by `异动指标`:

```text
流量异动 -> call only the traffic anomaly diagnosis Skill
转化率异动 -> call only the conversion anomaly diagnosis Skill
流量+转化率异动 -> call both Skills and merge into one combined ASIN report
```

Do not call both diagnosis Skills for every high-priority ASIN.

Diagnosis Skill repositories:

```text
traffic: https://github.com/defway888-design/kuajing-wulaoshi-amazon-traffic-anomaly-skil
conversion: https://github.com/defway888-design/kuajing-wulaoshi-amazon-conversion-anomaly-skill
```

Generate one Word report per high-priority ASIN and maintain:

```text
高优先级ASIN诊断报告索引.csv
```

Required diagnosis index columns:

```text
站点
店铺
负责人
父ASIN
商品名
异动指标
诊断状态
报告类型
摘要页地址
Word报告地址
失败原因
```

Allowed `诊断状态` values:

```text
已完成
部分完成
诊断失败
未生成
```

If diagnosis fails, keep the ASIN in the index with failure status and reason. Do not fabricate report content.

## Output Tables

负责人汇总表 columns:

```text
站点
店铺
负责人
异动商品数
高优先级异动
待复核异动
```

异动明细表 columns:

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
历史判断
待复核原因
最终状态
```

## BI Naming

```text
负责人BI = BI generated from 负责人汇总表
异动明细BI = BI generated from 异动明细表
```

异动明细BI is frozen unless explicitly requested.

The owner-facing operational 异动明细BI must show:

```text
高优先级ASIN诊断报告入口
待复核异动统计
待复核异动明细
```

`高优先级ASIN诊断报告入口` must be placed above `待复核异动统计` and `待复核异动明细`.

Owner-facing operational 异动明细BI must not display `负责人汇总与异动明细`.

Both boss and owner dashboards must not display:

```text
BI只展示入口，报告独立打开
```

Diagnosis reports are standalone Word reports. BI dashboards show only compact high-priority ASIN entries and `查看报告` links.

Known `待复核原因` labels:

```text
从0新增
低样本
负责人变更
无历史数据
```

If future review reasons are added, the dashboard must display the new reason text dynamically from `历史判断` in both the review statistics and the review-detail table instead of hiding it under a generic bucket.

负责人BI uses the `powerbi-full-panel-2026` visual direction but must keep the same module list and order as 异动明细BI.

Forbidden modules:

```text
Executive Overview
Owner Summary
Risk Split
Drilldown Table
```

## Email Scope

Sender mailbox:

```text
provided by the boss/customer
configured by the boss or with implementation assistance
not owned by the implementer
```

Management recipient:

```text
single boss management email only
receives one boss package by default
other management forwarding is handled by the boss in their mailbox
```

Boss package:

```text
default: one complete zip package
complete package: 负责人BI + summary/detail tables + diagnosis index + ASIN summary pages + Word reports
if the complete package exceeds the sender-provider usable threshold: send a light package
light package: 负责人BI + summary/detail tables + diagnosis index + ASIN summary pages, without full Word reports
```

Boss BI report links must use relative paths inside the zip package and open ASIN diagnosis summary pages.

Owner recipients:

```text
detected from current LingXing owner data
missing owner emails are prompted during the Codex run
each owner receives only their own 异动明细表 and 异动明细BI
each owner also receives their own high-priority ASIN Word diagnosis reports
```

Owner diagnosis attachments:

```text
few reports and under threshold -> send Word reports as individual attachments
many reports or over threshold -> send one owner diagnosis-report zip
if the owner package still exceeds threshold -> send BI/detail data and mark diagnosis attachment as manual follow-up required
```

## Sender Mailbox Guided Setup

Ask for the sender mailbox address first. Detect mailbox type from the domain and display only the matching provider-specific setup guide.

Flow:

```text
enter sender mailbox
-> detect provider
-> show provider-specific guide and official entry link
-> complete authorization
-> enter authorization result only in the secure setup flow
-> auto-load SMTP/OAuth preset
-> send test email
-> enable formal delivery only after the test succeeds
```

Known route examples:

```text
QQ -> authorization-code guide
NetEase -> authorization-code guide
Microsoft -> official authorization guide
Google -> official authorization guide
unknown custom domain -> provider selection or implementation assistance
```

Do not ask the boss to manually enter SMTP host, port, or encryption settings unless using the technical fallback path.
