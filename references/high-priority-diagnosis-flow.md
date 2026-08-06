# High-Priority ASIN Diagnosis Flow

Use this reference when adding deep diagnosis, Word reports, BI report links, and email packaging for high-priority anomalies.

## Trigger

Run deep diagnosis only for rows where:

```text
最终状态 = 高优先级异动
```

Do not diagnose `待复核异动` automatically. In the single-period anomaly rule, review-required rows include low sample, from-zero growth, owner transition, no history, and any future manual-review reason.

For `30天双窗口趋势异动`, those same notes are diagnosis attention points, not review reasons. A trend anomaly row must use:

```text
最终状态 = 高优先级异动
高优先级类型 = 缓慢高优先异动
```

High-priority rows are split into:

```text
当期高优先异动
缓慢高优先异动
```

## Diagnosis Skill Dispatch

Dispatch strictly by `异动指标`:

| 异动指标 | Required diagnosis action |
|---|---|
| 流量异动 | Call the traffic anomaly diagnosis Skill only |
| 转化率异动 | Call the conversion anomaly diagnosis Skill only |
| 流量+转化率异动 | Call both Skills and merge the findings into one combined ASIN report |

Repositories:

```text
traffic: https://github.com/defway888-design/kuajing-wulaoshi-amazon-traffic-anomaly-skil
conversion: https://github.com/defway888-design/kuajing-wulaoshi-amazon-conversion-anomaly-skill
```

Cost-control rule:

```text
Never call both diagnosis Skills unless 异动指标 = 流量+转化率异动.
```

## Report Output

Generate one standalone Word report per high-priority ASIN.

Recommended path:

```text
diagnosis_reports/{reporting_period}/{site}_{store}_{owner}_{parent_asin}_{metric_type}.docx
```

Recommended report filename fields:

```text
reporting_period
site
store
owner
parent_asin
metric_type
```

Do not add the brand prefix to the report filename.

## Diagnosis Index

Create:

```text
高优先级ASIN诊断报告索引.csv
```

Required columns:

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

Status mapping:

```text
完整完成 -> 允许发送
可用但有证据缺口 -> 允许发送
阻断失败 -> 禁止发送
未生成 -> 禁止发送
```

`摘要页地址` must point to an HTML summary page that can be opened from the BI package. `Word报告地址` points to the full `.docx` report when included in the package or owner attachment.

Use relative paths for BI links inside packages. Never write absolute local paths into BI links that will be emailed.

## BI Display

Both 负责人BI and 异动明细BI show a `高优先级ASIN诊断报告入口` module.

Position:

```text
place above 待复核异动统计 and 待复核异动明细
place above 负责人汇总与异动明细 when that full table is shown
```

The module shows only compact entry information:

```text
父ASIN
商品名
负责人
异动指标
高优先级类型
报告类型
诊断状态
核心诊断状态
可发送状态
证据缺口类型
查看报告 / 待生成
```

Do not put long diagnosis text directly in the BI dashboard.

Do not display:

```text
BI只展示入口，报告独立打开
```

## Boss Package

Boss receives one zip package by default.

Complete package includes:

```text
负责人BI
负责人汇总表
异动明细表
高优先级ASIN诊断报告索引.csv
ASIN diagnosis summary pages
full Word diagnosis reports
```

Light package includes:

```text
负责人BI
负责人汇总表
异动明细表
高优先级ASIN诊断报告索引.csv
ASIN diagnosis summary pages
```

Light package excludes full Word reports.

Boss BI click path:

```text
负责人BI -> ASIN诊断摘要页
```

If using a complete package, the summary page may also link to the full Word report inside the package. If using a light package, the summary page shows the diagnosis summary only and states that the full report is sent to the responsible owner.

Package selection:

```text
if complete package size <= usable sender threshold -> send complete package
if complete package size > usable sender threshold -> send light package
```

Do not create multi-volume split archives for the boss package.

## Owner Package

Each owner receives only their own data:

```text
owner-specific 异动明细表
owner-specific 异动明细BI
owner-specific high-priority ASIN Word diagnosis reports
```

Attachment rule:

```text
few reports and under threshold -> attach Word reports one by one
many reports or over threshold -> zip that owner's Word reports into one package
if the owner package still exceeds threshold -> send owner BI/detail data and mark diagnosis attachment as manual follow-up required
```

Multiple owners sharing the same ASIN:

```text
generate the ASIN report once
attach or include the same report for every current owner
```

Unassigned owner:

```text
do not send an owner-specific package
include the row in boss package
mark recipient role as manager_proxy
```

## Attachment Threshold

Determine the attachment threshold from the sender mailbox configured during setup.

Required steps:

```text
detect sender provider
verify the provider's current official attachment-size rule
store official max size, source, and review date in runtime config
calculate usable threshold = official max size * safety ratio
```

Default safety ratio:

```text
0.70
```

Reason: email attachment encoding can expand the actual sent payload.

If provider is unknown or the official threshold cannot be confirmed:

```text
do not enable automatic formal sending
ask for manual threshold confirmation or implementation assistance
```

## Failure Handling

If a diagnosis Skill call fails:

```text
do not fabricate content
record the ASIN in 高优先级ASIN诊断报告索引.csv
set 诊断状态 = 诊断失败
set 核心诊断状态 = 阻断失败
set 可发送状态 = 禁止发送
write 失败原因 and 阻断原因
show the status in BI
include a manual-review note in the owner email
keep the boss package generation running if the base BI/tables are valid
```

Formal-send rule:

```text
do not send formal weekly email until tables, BI, package selection, diagnosis index, recipient scoping, and all core diagnosis rows have passed validation
allow formal sending when only auxiliary evidence gaps remain
```

## Auxiliary Evidence Gap Policy

These checks improve the deep diagnosis but do not determine whether the weekly email can be sent:

```text
Seller ID
main image
five bullet points
fulfillment type
off-site promotion evidence
affiliate promotion evidence
strict similar-competitor review evidence
```

Off-site promotion verification:

```text
find candidate pages
confirm the page can be opened
confirm the page is related to the target ASIN or product
confirm publish date
confirm the date belongs to the analysis or anomaly period
```

If the page cannot be opened, the publish date cannot be confirmed, or the relation to the analysis period cannot be confirmed, record:

```text
证据缺口类型 = 站外推广证据未闭环
核心诊断状态 = 可用但有证据缺口
可发送状态 = 允许发送
```

Affiliate promotion verification:

```text
find candidate pages
confirm the page can be opened
confirm the page is related to the target ASIN or product
confirm publish date
confirm promotion or affiliate nature
```

If the publish date or affiliate/promotion nature cannot be confirmed, record:

```text
证据缺口类型 = 联盟客推广证据未闭环
核心诊断状态 = 可用但有证据缺口
可发送状态 = 允许发送
```
