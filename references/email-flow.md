# Email Flow

Use this reference when implementing weekly email distribution.

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
if analysis or validation fails: do not send incomplete reports
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
负责人汇总表
负责人BI
full-scope output
```

Do not maintain other management recipients, CC lists, or forwarding rules in the workflow. If other management users need the report, the boss configures forwarding in their own mailbox.

Owners receive:

```text
their own 异动明细表
their own 异动明细BI
```

Never send full-scope HTML to an owner with only a default filter applied. Owner-specific HTML must embed only that owner’s data.

## Owner Email Source

Current LingXing MCP does not expose owner email lookup. Use:

```text
config/owner_email_map.csv
config/recipient_config.json
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
3. detect missing/new/inactive owners
4. prompt operator for each missing owner
```

Prompt should show:

```text
负责人
涉及站点
涉及店铺
异动商品数
高优先级异动
待复核异动
```

Accepted inputs:

```text
valid email: save email and active = 1
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
missing owners
attachments to be sent
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
