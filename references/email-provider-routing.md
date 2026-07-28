# Sender Mailbox Provider Routing

Use this reference when configuring the boss-provided sender mailbox.

## Goal

Minimize boss-facing work:

```text
enter sender email
-> system recognizes mailbox type
-> system shows only the matching guide
-> user completes authorization
-> system sends a test email
```

Do not ask the boss to understand SMTP host, SMTP port, SSL/TLS, or STARTTLS.

## Provider Detection

Detect by sender email domain first:

| Email domain or provider | Setup route |
|---|---|
| `qq.com` | QQ authorization-code guide |
| `163.com`, `126.com`, `yeah.net` | NetEase authorization-code guide |
| `outlook.com`, `hotmail.com`, Microsoft 365 | Microsoft official authorization guide |
| `gmail.com`, Google Workspace | Google official authorization guide |
| recognized enterprise-mail provider | matching enterprise-mail guide |
| unknown custom domain | provider selection, then implementation-assisted fallback if needed |

Maintain the detailed routing table in:

```text
config/email_provider_presets.json
```

## Guided Setup Contract

After provider detection, show:

```text
detected mailbox type
short provider-specific steps
button or link to the official provider entry page
authorization input field in the secure setup flow when required
send test email button
```

Never request authorization codes, passwords, or tokens in chat.

## Provider-Specific Guidance

### QQ

```text
open QQ Mail official entry
log in to the boss-owned mailbox
enable the required SMTP mail service in mailbox settings
generate an authorization code
return to the secure setup flow
enter the authorization code
send a test email
```

Use the QQ preset internally. Do not ask the boss to enter technical SMTP values.

### NetEase

```text
open the matching NetEase Mail official entry
log in to the boss-owned mailbox
enable the required SMTP mail service in mailbox settings
generate an authorization code
return to the secure setup flow
enter the authorization code
send a test email
```

### Microsoft

Prefer:

```text
official Microsoft login and authorization flow
```

Do not default to asking for the mailbox login password.

### Google

Prefer:

```text
official Google login and authorization flow
```

Do not default to asking for the mailbox login password.

### Unknown Custom Domain

Ask:

```text
Which mailbox provider hosts this address?
```

Offer a simple provider list. If no preset matches:

```text
mark sender setup as implementation assistance required
do not enable automatic weekly sending
allow manual analysis runs to continue
```

Expose custom SMTP only as a fallback configuration path.

## Test And Activation

After authorization:

```text
send one test email to the boss management recipient
record test result and timestamp
enable formal weekly delivery only after test succeeds
```

Also determine the attachment threshold used for boss and owner packages:

```text
detect sender provider
verify the provider's current official attachment-size rule
record official max size, source, and review date in runtime config
usable threshold = official max size * safety ratio
default safety ratio = 0.70
```

Use the usable threshold, not the official max size, when deciding:

```text
boss complete package vs boss light package
owner individual Word attachments vs owner diagnosis-report zip
manual follow-up when package remains too large
```

If the current official threshold cannot be confirmed:

```text
keep automatic formal sending disabled
ask for manual threshold confirmation or implementation assistance
allow trial analysis and BI generation to continue
```

If the test fails:

```text
show a provider-specific troubleshooting message
keep automatic weekly delivery disabled
allow the user to retry or request implementation assistance
```

## Versioning

Provider pages and authorization requirements may change. Store official provider entry links, short guide text, preset version, and last-reviewed date in:

```text
config/email_provider_presets.json
```

Do not hard-code volatile page paths into the core skill.
