---
name: kuajing-wulaoshi-weekly-analysis
description: Build and operate the 跨境吴老师周数据分析 workflow for weekly parent-ASIN anomaly review. Use when Codex needs to calculate traffic or conversion anomalies, generate 负责人BI and 异动明细BI outputs, split owner-only dashboards, guide sender mailbox setup, configure weekly email delivery, or maintain the fixed rules, schemas, templates, and permissions for this branded workflow.
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
跨境吴老师正在生成负责人汇总表...
跨境吴老师正在生成负责人BI...
跨境吴老师正在生成异动明细BI...
跨境吴老师正在检查负责人邮箱...
跨境吴老师正在准备邮件发送...
跨境吴老师周数据分析已完成。
```

## Non-Negotiable Terms

- `负责人BI`: generated from `负责人汇总表`; management/full-scope dashboard.
- `异动明细BI`: generated from `异动明细表`; owner-specific detail dashboard.
- Do not rename these two dashboard types.
- Do not use old labels `真实异动数` or `人工复核数`.
- Use only `高优先级异动` and `待复核异动`.

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

GitHub private template repository:

```text
https://github.com/defway888-design/kuajing-wulaoshi-weekly-analysis-template
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
never send incomplete, failed, or unvalidated outputs
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

History check:

```text
traffic tolerance: +/-10 percentage points
conversion tolerance: +/-15 percentage points
```

History must compare movement magnitude, not direction only.

Low sample rule:

```text
if current daily average traffic <= 10 or previous daily average traffic <= 10,
and an anomaly threshold is triggered,
classify as 待复核异动 with 历史判断 = 样本不足，需人工复核
```

Previous value zero rule:

```text
previous value = 0 and current value > 0 -> mark change as 从0新增, classify as 待复核异动
previous value > 0 and current value = 0 -> mark change as -100%, continue anomaly judgment
previous value = 0 and current value = 0 -> not an anomaly
```

Owner transition rule:

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

If no historical comparable data exists:

```text
待复核异动
```

Never use rolling 4-week/8-week or category fallback in the current standard.

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
待复核异动
```

Invariant:

```text
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
历史判断
最终状态
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

### 负责人BI

Use the visual style direction from:

```text
https://github.com/shrewsendlessmer84/powerbi-full-panel-2026
```

But do not add modules.

负责人BI must keep the same module names and order as 异动明细BI:

```text
1. 标题卡片
2. 站点 / 店铺 / 负责人筛选器
3. KPI 卡片
4. 异动商品数 by 站点
5. 异动类型占比
6. 高优先级异动 by 负责人
7. 异动指标 by 类型
8. 异动商品数 by 店铺
9. 异动走势 by 负责人排序
10. 负责人汇总表
11. 异动明细表
```

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
负责人汇总表
负责人BI
full-scope summary data
```

Do not maintain extra management recipients, CC rules, or management forwarding rules in the workflow. If other managers need the report, the boss handles forwarding in their own mailbox.

Each owner receives:

```text
that owner’s 异动明细表
that owner’s 异动明细BI
```

Owner dashboards must not contain other owners’ data.

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
最终状态 only uses allowed values
负责人BI contains no forbidden modules
异动明细BI was not modified unless explicitly requested
owner-specific HTML contains no other owner data
dropdowns contain site/store/owner options
```

## Packaged Resources

Use the packaged scripts when rendering or validating outputs:

```text
scripts/generate_lingxing_manager_full_panel_dashboard.ps1
scripts/generate_lingxing_powerbi_style_dashboard.ps1
scripts/generate_lingxing_owner_powerbi_dashboard.ps1
scripts/validate_weekly_analysis_outputs.ps1
```

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
- `references/online-template-distribution.md`: multi-user online template distribution model.
