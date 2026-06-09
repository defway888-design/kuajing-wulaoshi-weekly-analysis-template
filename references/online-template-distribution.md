# Online Template Distribution

Use this reference when making the workflow reusable for multiple people.

## Principle

Fixed content belongs online.

Codex is the standard runtime for this workflow.

Runtime-local configuration keeps only:

```text
MCP key
email credentials or connector auth
local output directory
runtime logs
generated files
boss management recipient email
owner recipient email mapping
```

Online template source keeps:

```text
business rules
schemas
dashboard templates
CSS/JS
renderer scripts
quality checks
version metadata
```

## Recommended Repository

Use a private GitHub repository as the online template source.

The final repository URL may be TBD during drafting. Keep it as a placeholder until the user provides the actual URL.

```text
kuajing-wulaoshi-weekly-analysis-template/
├─ template_manifest.json
├─ rules/
│  └─ anomaly_rules.v1.json
├─ schemas/
│  ├─ summary.schema.json
│  └─ detail.schema.json
├─ templates/
│  ├─ manager-dashboard.template.html
│  └─ owner-dashboard.template.html
├─ assets/
│  └─ dashboard.css
└─ scripts/
   └─ render_dashboard.ps1
```

## Local Config

Codex runtime config supplies:

```json
{
  "template_manifest_url": "https://raw.githubusercontent.com/defway888-design/kuajing-wulaoshi-weekly-analysis-template/main/template_manifest.json",
  "lingxing_mcp_url": "https://openmcp.lingxing.com/mcp-servers/lingxing-mcp",
  "lingxing_mcp_key": "<secret>",
  "output_dir": "D:\\lingxing_weekly_output"
}
```

## Template Manifest

Manifest should include:

```json
{
  "template_name": "kuajing-wulaoshi-weekly-analysis",
  "template_version": "1.0.0",
  "rules_version": "anomaly-rules-v1",
  "manager_dashboard_style": "manager-full-panel-style-same-modules-v1",
  "owner_dashboard_style": "powerbi-sales-dashboard-inspired-v1",
  "files": {
    "rules": "rules/anomaly_rules.v1.json",
    "summary_schema": "schemas/summary.schema.json",
    "detail_schema": "schemas/detail.schema.json",
    "manager_template": "templates/manager-dashboard.template.html",
    "owner_template": "templates/owner-dashboard.template.html",
    "renderer": "scripts/render_dashboard.ps1"
  }
}
```

## Versioning

Use:

```text
template_version
rules_version
schema_version
style_version
```

Rules:

```text
text-only change -> patch
style/layout change -> minor
field/rule change -> major
```

## Runtime Flow

```text
1. run in Codex
2. read runtime config
3. download template_manifest.json from the GitHub private template repository
4. download rules, schemas, templates, renderer
5. call LingXing MCP
6. calculate anomalies with online rules
7. generate tables with online schemas
8. render 负责人BI and owner-specific 异动明细BI
9. validate
10. send email if sender mailbox and recipients are configured
```

Default to trial mode:

```text
allow repeated manual runs
do not create recurring automation
do not send formal weekly email automatically
```

After the user explicitly authorizes automatic weekly delivery:

```text
weekly task starts: Monday 00:00
standard email send time: Monday 09:00
late-send rule: send immediately after processing and validation succeed
```

Do not include business data, MCP keys, sender credentials, boss email, owner emails, or generated reports in the GitHub private template repository.
