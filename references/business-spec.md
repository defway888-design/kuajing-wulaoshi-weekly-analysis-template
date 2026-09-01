# 跨境吴老师周数据分析 Business Specification

Source of truth summary for the 跨境吴老师 weekly BI workflow.

The following extension contracts are authoritative for diagnosis integration, system action suggestions, and owner online-table delivery:

```text
references/diagnosis-integration-contract.md
references/action-plan-contract.md
references/online-table-delivery.md
```

If older wording in this specification conflicts with one of those contracts, use the corresponding extension contract.

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

GitHub public template repository:

```text
https://github.com/defway888-design/kuajing-wulaoshi-weekly-analysis-template
```

Standard installation does not require collecting user GitHub names or sending private-repository invitations.

Local path policy:

```text
do not hard-code C:\Users\20085\ or any other single-user path
use Codex default skill installation
use $env:USERPROFILE when a Windows user directory is required
write docs as C:\Users\<your-windows-user-name>\...
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

## Field Mapping And Blocking Rules

Returned MCP fields may vary by endpoint version. Implement semantic field mapping instead of requiring a single fixed field name.

Record the resolved mapping in:

```text
字段映射记录
```

Core fields are blocking because they are required to calculate the anomaly:

```text
站点
店铺
父ASIN
当前周期流量
当前周期成交量（volume）
上月周期流量
上月周期成交量（volume）
周期天数
当前周期日期范围
上月周期日期范围
```

If a core field cannot be found through semantic mapping, the affected output is invalid for formal sending.

Auxiliary fields and auxiliary evidence are non-blocking:

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

Missing auxiliary fields must be recorded as evidence gaps, not as send blockers.

Default mapping table:

| Business meaning | Preferred field | Allowed equivalent fields | Blocking |
|---|---|---|---|
| 父ASIN | parent_asin | asin, asin1, parentAsin | yes |
| 子ASIN | asin1 | asin, child_asin | no |
| SKU | seller_sku | msku, sku | no |
| Seller ID | seller_id | sid, sellerId | no |
| 流量 | sessions | sessions_total, traffic | yes |
| 成交量 | volume | order_count, sales, units_ordered | yes |
| 商品名 | product_name | title, item_name | no |
| 负责人 | owner | principal_name, principal_names | no |
| 主图 | main_image | image, image_url | no |
| 五点 | bullet_points | bullets, features | no |
| 配送类型 | fulfillment_type | delivery_type, fulfillment | no |

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

Single-period low sample rule:

```text
current daily average traffic <= 10 or previous daily average traffic <= 10
and threshold is triggered -> 待复核异动
历史判断 = 样本不足，需人工复核
```

Single-period previous value zero rule:

```text
previous value = 0 and current value > 0 -> 从0新增, 待复核异动
previous value > 0 and current value = 0 -> -100%, continue anomaly judgment
previous value = 0 and current value = 0 -> not an anomaly
```

## 30-Day Dual-Window Trend Anomaly

Purpose:

```text
catch gradual traffic or conversion deterioration/improvement that does not trigger the single-period threshold in the current cycle
```

This rule runs only after the single-period anomaly rule does not trigger.

Candidate pool:

```text
10% <= traffic absolute change < 30%
or
20% <= conversion absolute change < 50%
```

If the parent ASIN is outside this candidate pool, do not run the 30-day trend calculation.

Data-call principle:

```text
use query_product_performance_asin_lists with summary_field = parent_asin
use date-range summary windows instead of requiring daily-granularity output
```

Recent trend windows:

```text
recent 30-day observation window ending at T-3
early window = first 7 days in that 30-day window
late window = last 7 days in that 30-day window
middle 16 days are not used for calculation
```

Trend metrics:

```text
traffic trend = late-window daily average traffic vs early-window daily average traffic
conversion trend = late-window weighted conversion vs early-window weighted conversion
```

Trend thresholds:

```text
traffic absolute trend change >= 30%
conversion absolute trend change >= 50%
```

Historical trend judgment:

```text
compare the same early/late 7-day windows in the corresponding 30-day period last year
history must explain movement magnitude within tolerance, not direction only
history explains the trend -> exclude from output
history exists but does not explain the trend -> 高优先级异动, 高优先级类型 = 缓慢高优先异动
no comparable historical trend data -> 高优先级异动, 高优先级类型 = 缓慢高优先异动
```

Trend output fields:

```text
异动识别方式 = 30天双窗口趋势异动
趋势候选原因 = 流量接近阈值 / 转化率接近阈值 / 流量+转化率同时接近阈值
趋势判断窗口 = 最近30天前7天 vs 后7天
最终状态 = 高优先级异动
高优先级类型 = 缓慢高优先异动
```

For 30-day trend anomalies, no-history, low-sample, from-zero, and owner-transition signals are written into `历史判断` as diagnosis attention points. They do not change the row to `待复核异动`.

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
previous owner != current owner and detection mode = 单周期异动 -> 待复核异动
previous owner != current owner and detection mode = 30天双窗口趋势异动 -> 高优先级异动, 高优先级类型 = 缓慢高优先异动
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
single-period history exists and cannot explain movement -> 高优先级异动, 高优先级类型 = 当期高优先异动
single-period no historical comparable data -> 待复核异动
30-day trend anomaly not explained by history or lacking comparable history -> 高优先级异动, 高优先级类型 = 缓慢高优先异动
history explains movement -> exclude from output
```

## High-Priority ASIN Diagnosis

Follow `references/diagnosis-integration-contract.md`. The main Skill must pass the complete anomaly context to the selected diagnosis Skill and receive the Word report plus the same-run structured evidence object. Do not parse the Word report to reconstruct evidence.

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
高优先级类型
异动来源
当前比较窗口
基准比较窗口
当前流量值
基准流量值
流量变化率
当前转化率
基准转化率
转化率变化率
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
行动方案状态
在线表格写入状态
在线表格地址
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

Diagnosis send rules:

```text
完整完成 -> 允许发送
可用但有证据缺口 -> 允许发送
阻断失败 -> 禁止发送
未生成 -> 禁止发送
```

If diagnosis fails because a required core input or diagnosis Skill call is unavailable, keep the ASIN in the index with `核心诊断状态 = 阻断失败`, `可发送状态 = 禁止发送`, and `阻断原因`. Do not fabricate report content. Create only a `待复核观察` action row for that ASIN and continue processing other ASINs, other owners, and the boss package; an individual diagnosis failure is not a global batch blocker.

If only auxiliary evidence is missing, keep the ASIN sendable and record `证据缺口类型` and `证据缺口说明`.

`可发送状态` controls only the diagnosis attachment. It does not decide whether the owner's detail table, BI, verified online-table link, or other completed records may be sent.

## System Action Suggestions

Follow `references/action-plan-contract.md`.

The weekly main Skill is the only owner of system action-suggestion generation. Generate one action item per anomaly record key; keep `流量+转化率异动` as one project. The fixed reasoning sequence is:

```text
异动事实
-> 证据摘要
-> 可控制因素
-> 可执行动作
-> 不可控制因素
-> 观察记录
-> P0/P1建议
```

Use `正式行动方案` only when diagnosis evidence supports a concrete controllable action. Otherwise generate `待复核观察` with evidence gaps and review requirements, without fabricating P0/P1 actions. System fields are read-only and must carry the record key, rule version, batch version, content hash, online-record hash, and batch aggregate hash.

## Owner Online Action Tables

Follow `references/online-table-delivery.md`.

Every current owner with at least one anomaly row, including owners who only have review anomalies, must have a unique online-table link. Detect Feishu, Tencent Docs, Google Sheets, Excel Online, or WPS from the submitted link, then verify the matching MCP authorization, write capability, and readback capability. A browser-simulation fallback is forbidden.

Write formal actions and review-observation rows to the owner's long-term table, verify by readback, and isolate platform/write failures to the affected owner. Shared ASINs are written to every responsible owner's table. Never overwrite operator-entered final-plan fields.

## Output Tables

负责人汇总表 columns:

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

负责人汇总表 invariant:

```text
高优先级异动 = 当期高优先异动 + 缓慢高优先异动
异动商品数 = 高优先级异动 + 待复核异动
```

异动明细表 columns:

```text
站点
店铺
负责人
父ASIN
商品名
异动指标
异动来源
当前比较窗口
基准比较窗口
当前流量值
基准流量值
流量变化率
当前转化率
基准转化率
转化率变化率
异动识别方式
趋势候选原因
趋势判断窗口
历史判断
待复核原因
最终状态
高优先级类型
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

负责人BI uses the `powerbi-full-panel-2026` visual direction and must keep this fixed visual card order:

```text
1. 异动类型占比
2. 高优先异动分类占比
3. 待复核异动分类占比
4. 异动指标 by 类型
5. 异动商品数 by 站点
6. 异动商品数 by 店铺
7. 异动商品数 by 负责人
8. 高优先级ASIN诊断报告入口
```

The top `高优先级异动` KPI card shows only number + label, matching `异动商品数` and `待复核异动`; it must not show `当期 / 缓慢` subtext.

The `高优先级ASIN诊断报告入口` module must include local filters for `站点`, `店铺`, and `运营人员`.

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
complete package: 负责人BI + summary/detail tables + diagnosis index + ASIN summary pages + Word reports + 系统行动建议审计快照.csv + 负责人在线表格投递状态.csv
if the complete package exceeds the sender-provider usable threshold: send a light package
light package: 负责人BI + summary/detail tables + diagnosis index + ASIN summary pages + action audit snapshot + owner online-table delivery status, without full Word reports
```

Boss BI report links must use relative paths inside the zip package and open ASIN diagnosis summary pages.

Owner recipients:

```text
detected from current LingXing owner data
missing owner emails are prompted during the Codex run
each owner receives only their own 异动明细表 and 异动明细BI
each owner receives their verified online action-table link and writeback status
each owner also receives only their own sendable high-priority ASIN Word diagnosis reports
```

Do not attach `行动方案建议表_<负责人>.csv`. The online table is the action-plan delivery surface.

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
