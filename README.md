# bakedocs

Turn Markdown into branded PDF, standalone HTML, and Reveal.js presentations.

[![CI](https://github.com/pacharanero/bakedocs/actions/workflows/ci.yml/badge.svg)](https://github.com/pacharanero/bakedocs/actions/workflows/ci.yml)
[![Licence: GPL-3.0-or-later](https://img.shields.io/badge/Licence-GPL--3.0--or--later-blue.svg)](LICENSE)

## Quick Start

Prerequisites: Bash 4.0 or later, Pandoc 3.7.1 or later, and a Chromium-based browser. `bakedocs` auto-detects `chromium`, `chromium-browser`, `google-chrome`, or `google-chrome-stable`; set `BAKEDOCS_CHROMIUM=/path/to/browser` when the executable has another name or location.

```console
git clone https://github.com/pacharanero/bakedocs.git
cd bakedocs
./bakedocs check --brands-dir examples/brands
./bakedocs pdf fixtures/document.md example --brands-dir examples/brands --output example.pdf
```

The command prints only the generated path on success. Generated output under `out/` is ignored by Git.

## What It Is

`bakedocs` is a small Bash-orchestrated document-rendering project for people who maintain content in Markdown but need reusable organisation-specific output. Pandoc produces semantic HTML, headless Chromium produces PDF, and a custom Reveal.js 6 template produces slides. The name is a mild baking pun on MkDocs.

It is not a WYSIWYG editor, a mature general-purpose CLI, or a justification for replacing proven external renderers with a new runtime.

## Status

The repository contains a successful rendering bakeoff and the initial Bash command surface for arbitrary source documents. The command runs from this checkout; path-independent installation and broader conformance coverage remain under development.

The bakeoff produced visually approved PDFs and presentations across representative SVG and PNG profiles. A Rust implementation is not currently justified; it remains an option only if the Bash CLI develops concrete portability, testing, configuration, or distribution problems.

The current command surface is:

```console
bakedocs pdf report.md <brand-id>
bakedocs html report.md <brand-id>
bakedocs slides presentation.md <brand-id>
bakedocs brands list
bakedocs brands show <brand-id>
bakedocs check
bakedocs version
```

An optional output path is available without making the common case verbose:

```console
bakedocs pdf report.md <brand-id> --output review-pack.pdf
```

## Commands

Render any Markdown source using a discovered brand profile:

```console
./bakedocs html report.md <brand-id>
./bakedocs pdf report.md <brand-id> --output review-pack.pdf
./bakedocs slides presentation.md <brand-id>
```

Brand lookup is first-match-wins: `--brands-dir`, `BAKEDOCS_BRANDS_DIR`, a project-local `brands/`, then `$XDG_CONFIG_HOME/bakedocs/brands/` or `$HOME/.config/bakedocs/brands/`. Explicit roots are fail-closed. Real organisation profiles are user configuration and are not shipped in this repository.

`./bakedocs check` reports required tools, discovered profiles, logo availability, and the Reveal.js remote-resource requirement without rendering or accessing the network.

`--offline` rejects remote document and brand images before rendering. Reveal.js output currently requires its pinned CDN and is therefore rejected in offline mode. Source raw HTML is disabled; use Pandoc fenced divs such as `::: {.page-break}` for supported structural hooks instead of embedding executable HTML.

Runtime overrides:

| Variable | Default | Purpose |
| --- | --- | --- |
| `BAKEDOCS_BRANDS_DIR` | Discovered roots | Select one fail-closed brand root. |
| `BAKEDOCS_PANDOC` | First `pandoc` on `$PATH` | Select the Pandoc executable. |
| `BAKEDOCS_CHROMIUM` | First recognised Chromium on `$PATH` | Select the PDF renderer executable. |
| `BAKEDOCS_RENDER_TIMEOUT` | `120` | Bound each Pandoc and Chromium process in seconds. |

## Development Rendering

Render the fixtures with the fictional public example profile:

```console
./s/render
```

Render every profile in an explicitly selected root:

```console
BAKEDOCS_BRANDS_DIR="$HOME/.config/bakedocs/brands" ./s/render-all
```

Outputs are written to `out/<brand>/`. Each brand receives standalone document HTML, a Chromium PDF, and a Reveal.js HTML deck.

Run the repository checks:

```console
./s/lint
./s/test
reuse lint
zizmor --strict-collection .
```

`reuse` and `zizmor` are development checks used locally and in CI; they are not `bakedocs` runtime dependencies.

## Brand Layout

Each `BRAND-ID` selects a self-contained profile directory. User profiles normally live under the XDG configuration directory:

```text
~/.config/bakedocs/brands/
`-- <brand-id>/
    |-- brand.yml
    |-- tokens.css
    |-- document.css       # optional override
    |-- reveal.css         # optional override
    `-- assets/            # only when redistribution is permitted
```

`tokens.css` deliberately contains only semantic custom properties such as `--brand-primary` and `--brand-heading-font`. The name distinguishes those reusable brand values from `document.css` and `reveal.css`, which contain layout selectors; `brand.css` would suggest that one file owns both concerns.

Relative paths inside `brand.yml` resolve against the brand directory, not the caller's PWD. This allows `bakedocs` to be invoked from anywhere while keeping each profile portable.

## Contents

- `examples/brands/` contains one fictional, explicitly selected example profile.
- `bakedocs` is the public Bash command.
- `fixtures/` contains synthetic Markdown designed to exercise common document and slide features.
- `filters/` contains the Pandoc resource-policy and local-image embedding filter.
- `styles/` contains separate document and presentation styles that consume shared brand tokens.
- `templates/` contains explicit Pandoc HTML and Reveal.js 6 templates.
- `out/` contains ignored generated bakeoff output; regenerate it rather than editing or committing it.
- `s/` contains the current reproducible bakeoff commands.
- `tests/` contains isolated command-surface integration tests.
- `findings.md` records measured results and renderer conclusions.
- `spec/` contains the product and implementation contract and its reading order.
- `roadmap.md` records the immediate handoff and implementation sequence.

## Renderer decision

Pandoc plus Chromium is the supported baseline. WeasyPrint and Vivliostyle do not need evaluation unless a real requirement appears for richer paged media, such as running headers and footers, sophisticated counters, repeating table headers, mixed page layouts, book-style footnotes, or indexes.

## Contributing

Issues and focused pull requests are welcome. Keep profiles for real organisations outside this repository unless their names, marks, fonts, and other assets are explicitly cleared for redistribution.

## Licensing and privacy

The fixtures and example profile are fictional, contain no member or client data, and use an original geometric logo. Keep local profiles and assets under the XDG configuration directory rather than adding them to this repository.

Original code and repository content are copyright 2026 Marcus Baw and licensed under `GPL-3.0-or-later`. Third-party names, trade marks, logos, fonts, and assets retain their owners' rights and terms and are not relicensed by this repository. See [LICENSE](LICENSE).

Review provenance and redistribution rights before adding any external asset, even when it is used only by an example profile.

Report sensitive findings privately as described in [SECURITY.md](SECURITY.md).
