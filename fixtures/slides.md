---
title: "One source, three outputs"
subtitle: "A synthetic rendering bakeoff"
author: "Example Operations Team"
date: "26 August 2026"
language: "en-GB"
---

# The job

Turn maintained Markdown into documents people can read, print, present, and audit.

# One content model

## Inputs

- Markdown and metadata
- A named brand profile
- An explicit output format

## Optional depth

The horizontal story should still work when this supporting slide is skipped.

# Renderer boundary

```text
Markdown -> Pandoc -> semantic HTML -> Chromium / WeasyPrint / Vivliostyle
                    `-------------> Reveal.js
```

# Acceptance

Readable. Reproducible. Brand-specific without duplicating layout logic.
