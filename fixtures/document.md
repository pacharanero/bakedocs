---
title: "Managed Community Service Review"
subtitle: "Synthetic fixture for document rendering"
author: "Example Operations Team"
date: "26 August 2026"
reference: "BAKEOFF-2026-001"
status: "Draft for rendering review"
language: "en-GB"
abstract: |
  This deliberately fictional report exercises the structures commonly needed in proposals, contracts, technical reports, and governance papers. It contains no client or member data.
---

# Executive summary

The service is stable, the planned maintenance was completed, and the next review should concentrate on onboarding quality. The document must remain legible when printed, viewed as standalone HTML, or restyled for another organisation.

> **Decision required:** approve the staged onboarding trial, subject to accessibility review and a documented rollback point.

## Review status

| Workstream | Owner | State | Evidence | Next review |
| --- | --- | --- | --- | --- |
| Availability | Operations | Complete | Synthetic uptime report | 30 September |
| Accessibility | Product | In progress | Keyboard and zoom review | 5 September |
| Onboarding | Community | Proposed | Draft welcome sequence | 12 September |
| Data retention | Governance | Complete | Retention schedule | Annual |

The important comparison is not visual novelty. It is whether hierarchy, tables, links, warnings, page breaks, and source provenance survive each renderer predictably.

# Findings

## What worked

- The content has one clear source of truth in Markdown.
- Brand values are separate from document layout rules.
- The HTML output remains inspectable and can be retained as an accessible companion to PDF.

## Risks to test

1. Long table rows must not disappear or overlap a footer.
2. A heading must not be stranded at the bottom of a page.
3. Links must remain clickable in PDF output.
4. SVG and transparent PNG logos must retain their proportions.
5. Missing fonts must fall back without changing the information hierarchy.

### Example command

```console
bakedocs pdf review.md example --output review.pdf
```

Configuration should be discoverable rather than magical:

```toml
[document]
paper = "a4"
renderer = "chromium"

[brand]
name = "Example Organisation"
primary = "#26374A"
accent = "#287F8F"
```

## A longer table

| Check | HTML | Chromium PDF | WeasyPrint PDF | Vivliostyle PDF | Acceptance rule | Reviewer |
| --- | --- | --- | --- | --- | --- | --- |
| Headings | Pass | Pass | Not installed | Not installed | No orphan heading | Human |
| Tables | Pass | Pass | Not installed | Not installed | No clipped columns | Human |
| Links | Pass | Pass | Not installed | Not installed | Clickable target retained | Automated |
| Logo | Pass | Pass | Not installed | Not installed | Correct aspect ratio | Human |
| Metadata | Pass | Pass | Not installed | Not installed | Visible reference and status | Automated |

::: {.page-break}
:::

# Recommendation

Use a two-stage architecture: Pandoc normalises Markdown into semantic HTML, then a selected browser or paged-media engine produces PDF. Keep renderer-specific behaviour behind an explicit adapter and preserve standalone HTML as a first-class output.

This fixture includes a footnote to test references.[^source]

[^source]: The fixture is synthetic and was created solely for this local bakeoff.
