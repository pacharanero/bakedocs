# bakedocs

Turn Markdown into branded PDF, standalone HTML, and Reveal.js presentations.

[![CI](https://github.com/pacharanero/bakedocs/actions/workflows/ci.yml/badge.svg)](https://github.com/pacharanero/bakedocs/actions/workflows/ci.yml)
[![Licence: GPL-3.0-or-later](https://img.shields.io/badge/Licence-GPL--3.0--or--later-blue.svg)](LICENSE)

## Quick Start

Prerequisites: Bash 4.0 or later, Pandoc 3.7.1 or later, and a Chromium-based browser. `bakedocs` auto-detects `chromium`, `chromium-browser`, `google-chrome`, or `google-chrome-stable`; set `BAKEDOCS_CHROMIUM=/path/to/browser` when the executable has another name or location. Profiles that declare a font contract also require Poppler's `pdffonts` for verified PDF output; HTML and slides need only the standard `base64` and `tr` utilities to embed those fonts.

```console
git clone https://github.com/pacharanero/bakedocs.git
cd bakedocs
./s/install
export PATH="$HOME/.local/bin:$PATH"
bakedocs check --brands-dir examples/brands
bakedocs pdf fixtures/document.md example --brands-dir examples/brands --output example.pdf
```

The command prints only the generated path on success. Generated output under `out/` is ignored by Git.

## What It Is

`bakedocs` is a small Bash-orchestrated document-rendering project for people who maintain content in Markdown but need reusable organisation-specific output. Pandoc produces semantic HTML, headless Chromium produces PDF, and a custom Reveal.js 6 template produces slides. The name is a mild baking pun on MkDocs.

It is not a WYSIWYG editor, a mature general-purpose CLI, or a justification for replacing proven external renderers with a new runtime.

## Status

The repository contains a successful rendering bakeoff and the initial Bash command surface for arbitrary source documents. Path-independent user installation and automated HTML, Reveal.js, and PDF rendering conformance checks are supported.

The bakeoff produced visually approved PDFs and presentations across representative SVG and PNG profiles. A Rust implementation is not currently justified; it remains an option only if the Bash CLI develops concrete portability, testing, configuration, or distribution problems.

## Installation

`./s/install` installs a complete versioned runtime payload under `$HOME/.local/lib/bakedocs/` and atomically links `$HOME/.local/bin/bakedocs` to it. Rerun it after updating the checkout. Use `./s/install --prefix <path>` for another prefix and ensure that prefix's `bin/` directory is on `PATH`.

Remove a managed installation with `./s/uninstall`, passing the same `--prefix` when applicable. The uninstaller refuses unrelated files and leaves other prefix contents untouched. A release-backed copy-and-paste installer that can bootstrap compatible Pandoc and Chromium versions is tracked separately; the checkout installer deliberately does not invoke a package manager or `sudo`.

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

Layer YAML or JSON metadata without coupling the source to one engagement:

```console
bakedocs pdf agreement.md <brand-id> \
  --values "$HOME/.config/bakedocs/values/provider.yml" \
  --values engagement.json
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

## Metadata Interpolation

Source prose, headings, tables, link text, link titles, link destinations, and metadata may reference scalar values as `{{ provider.company_number }}`. Identifiers may contain letters, digits, underscores, or hyphens and may use dots for nested lookup. `{{{{ provider.company_number }}}}` emits the literal placeholder.

Each repeatable `--values` file is an explicit fail-closed YAML or JSON metadata layer limited to 1 MiB. Files are applied in command-line order, later top-level keys replace earlier keys, and source front matter has final precedence. Missing paths, oversized inputs, maps or lists used as values, cycles, and malformed placeholders stop rendering without replacing an existing output. Inline code, fenced code, math, attributes, identifiers, image paths, and citation keys are not interpolated. Resource-bearing logo metadata is always taken from the selected brand profile and cannot be replaced by values or source metadata.

This feature is deliberately metadata interpolation rather than a general template language. It has no expressions, calls, filters, conditionals, loops, includes, environment lookup, filesystem access, or evaluation. Resolved values become plain text in the existing Pandoc document tree; Markdown-looking or HTML-looking values cannot create structure or executable content, and completed links still pass through the unsafe-scheme policy. Images and raw nodes are rejected anywhere in metadata, while CSS, header includes, body includes, the logo, and the Reveal.js URL are reserved to trusted `bakedocs` and brand inputs. Language metadata is accepted only when its primary code belongs to the renderer's supported translation set, and invalid-language errors never echo the supplied value.

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

The full rendering conformance suite also requires Poppler's `pdfinfo`, `pdffonts`, and `pdftotext` utilities. `reuse`, `zizmor`, `pdfinfo`, and `pdftotext` are development checks used locally and in CI; `pdffonts` is additionally a conditional runtime dependency for PDF output when the selected profile declares a font contract.

## Brand Layout

Each `BRAND-ID` selects a profile directory. User profiles normally live under the XDG configuration directory:

```text
~/.config/bakedocs/brands/
`-- <brand-id>/
    |-- brand.yml
    |-- tokens.css
    |-- document.css       # optional override
    |-- reveal.css         # optional override
    `-- assets/            # optional profile-local assets
```

`tokens.css` deliberately contains only semantic custom properties such as `--brand-primary` and `--brand-heading-font`. The name distinguishes those reusable brand values from `document.css` and `reveal.css`, which contain layout selectors; `brand.css` would suggest that one file owns both concerns.

Logo paths inside `brand.yml` may be profile-relative, absolute, home-relative with `~/`, symlinked, or remote URLs. Relative paths resolve against the brand directory, not the caller's PWD, so portable profiles continue to work when `bakedocs` is invoked from anywhere. Local logos must resolve to readable regular files no larger than 10 MiB. Users are responsible for deciding whether they may use or redistribute a selected logo.

Local fonts are optional but fail closed once any field for a role is declared. A heading or body role requires top-level quoted scalar fields for `heading-font-family`, `heading-font-file`, `heading-font-weight`, `heading-font-style`, and `heading-font-pdf-name` (or the equivalent `body-*` fields). Supported files are profile-contained WOFF2, WOFF, TTF, and OTF files up to 10 MiB each; absolute paths, traversal, and escaping symlinks are rejected. `bakedocs` embeds configured files as data URIs in HTML and slides, overrides the corresponding semantic font token, and uses the expected PostScript `*-font-pdf-name` to require an embedded font with a Unicode map before publishing a Chromium PDF. Additional PDF fonts are reported as possible partial glyph fallback for review because Poppler cannot attribute each glyph to a semantic role. `bakedocs check` validates the files and reports whether PDF font verification is available.

Review each font's provenance and redistribution terms before adding it to a profile. The fictional example uses unmodified Atkinson Hyperlegible Next Latin subsets under `OFL-1.1`; its exact package version and hashes are recorded beside the files.

## Contents

- `examples/brands/` contains one fictional, explicitly selected example profile.
- `bakedocs` is the public Bash command.
- `fixtures/` contains synthetic Markdown designed to exercise common document and slide features.
- `filters/` contains the strict metadata-interpolation and resource-policy filters.
- `styles/` contains separate document and presentation styles that consume shared brand tokens.
- `templates/` contains explicit Pandoc HTML and Reveal.js 6 templates.
- `out/` contains ignored generated bakeoff output; regenerate it rather than editing or committing it.
- `s/` contains the current reproducible bakeoff commands.
- `tests/` contains isolated command-surface, installation, and real-rendering conformance tests.
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
