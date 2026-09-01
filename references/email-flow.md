# Email Flow

Use this reference when implementing weekly email distribution.

For owner online-table delivery, platform recognition, authorization, writeback, readback, retries, and failure isolation, `references/online-table-delivery.md` is authoritative. If older wording in this file conflicts with that contract, use the online-table contract.

## Delivery Activation

Default mode:

```text
试运行模式
```

During the first-use trial period, allow repeated manual analysis runs in Codex. Do not create a recurring automation and do not send weekly formal email automatically.

Only switch to:

```text
自动发送模式
```

when the user explicitly asks to enable automatic weekly email delivery.

The following actions do not authorize automatic delivery:

```text
manual data analysis
dashboard generation
sender mailbox configuration
recipient email entry
test email
```

After authorization:

```text
first eligible run: first Monday after authorization
weekly task starts: Monday 00:00
standard email send time: Monday 09:00
if analysis is still running at 09:00: send immediately after analysis and validation succeed
if analysis or core validation fails: do not send blocking-failed reports
if only auxiliary evidence gaps remain: allow sending and show the gaps in the email body
```

Track:

```text
reporting_period
task_started_at
analysis_completed_at
actual_sent_at
send_status: processing | ready | sent | failed
```

## Recipients

The workflow uses the boss-provided sender mailbox. The sender mailbox belongs to the boss/customer, not the implementer.

The system maintains exactly one management recipient mailbox:

```text
boss_name
boss_management_email
send_test_email
```

This mailbox receives:

```text
老板汇总包
```

Boss package rules:

```text
default: send one complete zip package
complete package includes 负责人BI, 负责人汇总表, 异动明细表, 高优先级ASIN诊断报告索引.csv, ASIN diagnosis summary pages, full Word diagnosis reports, 系统行动建议审计快照.csv, and 负责人在线表格投递状态.csv
if complete package exceeds the usable sender-provider threshold: send one light package instead
light package includes 负责人BI, 负责人汇总表, 异动明细表, 高优先级ASIN诊断报告索引.csv, ASIN diagnosis summary pages, 系统行动建议审计快照.csv, and 负责人在线表格投递状态.csv only
do not split the boss package into multi-volume archives
```

Boss BI links:

```text
use relative paths inside the zip package
open ASIN diagnosis summary pages
do not depend on absolute local paths or cloud storage
```

Do not maintain other management recipients, CC lists, or forwarding rules in the workflow. If other management users need the report, the boss configures forwarding in their own mailbox.

Owners receive:

```text
their own 异动明细表
their own 异动明细BI
their own online action-table link and verified writeback status
their own high-priority ASIN Word diagnosis reports only when the diagnosis attachment status allows sending
```

Do not attach `行动方案建议表_<负责人>.csv`. System suggestions are written to each owner's configured online table and the email carries the link.

Never send full-scope HTML to an owner with only a default filter applied. Owner-specific HTML must embed only that owner’s data.

Owner attachment rules:

```text
few Word reports and under threshold -> send as individual attachments
too many Word reports or over threshold -> compress that owner's diagnosis reports into one zip
if owner package still exceeds threshold -> send owner BI/detail data and mark diagnosis attachment as manual follow-up required
```

High-priority diagnosis failures:

```text
include the ASIN and failure status in the owner email body
do not fabricate a Word report
keep the diagnosis index row for audit
create a 待复核观察 action row with the evidence gap and review requirement
do not create a formal P0/P1 action suggestion
continue processing other ASINs, other owners, and the boss package
```

High-priority diagnosis evidence gaps:

```text
send when 可发送状态 = 允许发送
state in the email body: 可发送，存在辅助证据缺口
list 证据缺口类型 and 证据缺口说明 by ASIN
do not treat Seller ID, main image, five bullet points, fulfillment type, off-site promotion evidence, affiliate promotion evidence, or strict similar-competitor evidence gaps as send blockers
```

## Owner Email Source

Current LingXing MCP does not expose owner email lookup. Use:

```text
config/owner_email_map.csv
config/recipient_config.json
config/owner_delivery_map.csv
```

Recommended `owner_email_map.csv` columns:

```text
owner_key
owner_uid
owner_name
site
store
email
cc_email
active
role
first_seen_at
last_seen_at
remark
```

First version owner key:

```text
owner_name
```

Upgrade to `owner_name + site + store` if duplicate owner names need different emails.

Recommended `owner_delivery_map.csv` columns:

```text
owner_name
site
store
email
online_table_url
online_table_platform
mcp_connection_name
active
first_seen_at
last_verified_at
remark
```

## Owner Resignation Or Handover

When a parent ASIN owner changes between the previous period and current period, the current owner is the report recipient.

Rules:

```text
do not send owner-specific reports to the departed previous owner
if current owner has no email mapping, prompt for the current owner email
if current owner is empty or 未分配, send the owner package to the boss management email with role = manager_proxy
keep inactive departed owners in owner_email_map.csv for audit history, but do not prompt or send unless they reappear in current data
```

The anomaly detail should explain the handover in `历史判断`:

```text
负责人变更：上期{previous_owner} -> 本期{current_owner}，需确认交接或运营动作影响
```

## Command-Line Entry

After every analysis run:

```text
1. extract owners from current 异动明细表
2. read owner_email_map.csv
3. detect missing/new/inactive owners and missing online-table mappings
4. prompt operator for each missing email or online-table link
```

Prompt should show:

```text
负责人
涉及站点
涉及店铺
异动商品数
高优先级异动
当期高优先异动
缓慢高优先异动
待复核异动
高优先级诊断报告数
在线行动表链接
识别到的平台
```

Accepted inputs:

```text
valid email: save email and active = 1
valid online-table URL: detect the platform, verify the matching MCP authorization, perform a test write/readback, then save the mapping
multiple emails: separate by semicolon
skip: active = 0, prompt again next run
manager: send owner package to management email, role = manager_proxy
quit: exit without sending
```

## Send Preview

Before sending, print:

```text
boss management email
owner -> email mapping
owner -> online-table mapping and platform
missing owners
attachments to be sent
boss package type: complete | light
boss package size and usable threshold
owner diagnosis attachments or owner diagnosis zip
diagnosis failures needing manual review
diagnosis evidence gaps that are still sendable
online-table write/readback failures
action rule version, batch version, and aggregate hash
```

Require:

```text
yes
no
test
```

Meanings:

```text
yes: send
no: do not send
test: send test to management only
```

## Logs

Generate:

```text
email_send_log.csv
unmatched_owner_email_report.csv
package_manifest.json
```

Never log MCP keys or email passwords.

## Sender Email UX

The sender mailbox is provided by the boss/customer.

Configuration options:

```text
boss configures the sender mailbox directly
implementer assists the boss to configure the sender mailbox
```

Do not make an implementer-owned mailbox the standard sender. Do not store sender credentials in the online template repository, logs, generated reports, or skill files.

When possible, reduce the boss-facing configuration to:

```text
sender email account
provider detected from email domain
authorization credential entered only in the secure setup flow
send test email
```

Do not require the boss to understand or manually enter:

```text
SMTP host
SMTP port
SSL/TLS
STARTTLS
```

The program should auto-detect provider from the email domain and load SMTP settings from an internal preset file when available:

```text
email_provider_presets.json
```

If provider detection fails, show a simple provider selection list. Only expose custom SMTP as a technical fallback.

Always send a test email before formal weekly report delivery.

Security rule:

```text
sender mailbox belongs to the boss/customer
owner and management emails are recipient emails only
never log or commit sender credentials
```

If unattended weekly sending is required later, use encrypted local credentials, a customer-owned service mailbox, or a customer-approved email service.

OAuth-capable providers should use official OAuth login/consent pages. SMTP-code providers should link users to the provider’s official authorization-code settings page, then accept the authorization code only in the local setup page. Never store credentials in the online template repository or logs.

Read `email-provider-routing.md` when implementing provider detection, provider-specific guidance, and preset loading.
