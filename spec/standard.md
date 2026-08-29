# Branded document renderer specification

Status: accepted bakeoff baseline and implementation specification. The project and executable name are `bakedocs`; Bash is the MVP implementation language.

## Purpose

`bakedocs` turns Markdown into branded standalone HTML, PDF, or Reveal.js presentations through a command available anywhere on `$PATH`. A document's content remains independent of organisation-specific styling, and a brand profile can be reused across projects and output types.

## Goals

- Provide one command that works from any directory on `$PATH`.
- Make Markdown the maintained source while accepting formats Pandoc can ingest when explicitly requested.
- Produce semantic standalone HTML as a first-class output and as the intermediate representation for PDF.
- Produce Reveal.js HTML from the same brand tokens without pretending print and slide layouts are interchangeable.
- Support named brand profiles for arbitrary organisations without bundling private configuration or third-party brand assets.
- Make configuration selection visible, deterministic, testable, and safe for automation.
- Keep rendering adapters replaceable so Chromium, WeasyPrint, and Vivliostyle can be compared or selected without changing document content.
- Preserve useful diagnostics on stderr and machine-readable results on stdout.

## Non-goals for the first release

- A graphical editor or WYSIWYG page-layout application.
- Full fidelity round-tripping back to DOCX or ODT.
- Reimplementing Markdown, CSS layout, PDF generation, or Reveal.js in Bash, Rust, or another language.
- Introducing a compiled implementation before Bash has demonstrated a concrete limitation.
- Automatic legal approval, accessibility certification, or brand-governance approval.
- Silently downloading rendering engines, fonts, JavaScript, or remote images during a render.
- Combining print and presentation layout into one stylesheet.

## Ubiquitous language

- **Source document**: maintained Markdown content and its front matter.
- **Brand profile**: reusable organisation identity metadata, asset references, and semantic design tokens.
- **Document style**: print and long-form screen layout rules that consume brand tokens.
- **Presentation style**: Reveal.js layout rules that consume the same brand tokens.
- **Intermediate HTML**: standalone semantic HTML produced before PDF rendering.
- **Renderer adapter**: integration that turns intermediate HTML into PDF or another final artefact.
- **Render manifest**: machine-readable record of inputs, selected configuration, tools, versions, and generated artefacts.

Do not use “template” to mean all of these at once. A Pandoc HTML template, source document, brand profile, and stylesheet are separate artefacts.

## Command surface

Bare `bakedocs` prints compact help and exits successfully.

```text
bakedocs pdf <SOURCE> <BRAND-ID> [--values <PATH> ...] [--output <PATH>]
bakedocs html <SOURCE> <BRAND-ID> [--values <PATH> ...] [--output <PATH>]
bakedocs slides <SOURCE> <BRAND-ID> [--values <PATH> ...] [--output <PATH>]
bakedocs brands list
bakedocs brands show <BRAND-ID>
bakedocs check
bakedocs version
```

Global options:

```text
    --brands-dir <PATH>
    --values <PATH>       # repeatable
    --output <PATH>
    --offline
-V, --version
```

The output command is explicit. `bakedocs pdf` never silently falls back to HTML when Chromium is unavailable; it exits non-zero and explains what is missing. Without `--output`, each command writes beside the source using the appropriate extension.

`bakedocs check` reports the brand roots, brand assets, Pandoc, Chromium, versions, and whether remote resources would be required. It performs no render and no network access.

## Brand profiles

`BRAND-ID` is the name of a directory containing one brand profile:

```text
brands/<brand-id>/
|-- brand.yml
|-- tokens.css
|-- document.css       # optional
|-- reveal.css         # optional
`-- assets/            # optional and licence-dependent
```

`brand.yml` contains organisation metadata and paths such as `logo`. `tokens.css` contains semantic brand custom properties. Missing optional layout overrides fall back to the shared files under `styles/`.

Brand lookup is first-match-wins:

1. `--brands-dir <PATH>/<BRAND-ID>`
2. `$BAKEDOCS_BRANDS_DIR/<BRAND-ID>`
3. `./brands/<BRAND-ID>` when present
4. `$XDG_CONFIG_HOME/bakedocs/brands/<BRAND-ID>`, falling back to `$HOME/.config/bakedocs/brands/<BRAND-ID>`

An explicitly selected brand root is fail-closed. Missing discovered roots are skipped. Relative paths in `brand.yml` resolve against the selected brand directory.

## Deferred configuration discovery

TOML configuration is not required for the first Bash command surface. Brand-directory discovery and explicit command options are sufficient for R4. If repeated non-brand settings create a concrete need for a config file, use the following contract rather than inventing an incompatible hierarchy later.

The project name defines these paths:

- Config filename: `bakedocs.toml`
- Explicit config environment variable: `BAKEDOCS_CONFIG`
- Config-home override: `BAKEDOCS_CONFIG_HOME`
- User config directory: `$XDG_CONFIG_HOME/bakedocs`, falling back to `$HOME/.config/bakedocs`

First match wins:

1. `--config <PATH>`
2. `$BAKEDOCS_CONFIG`
3. `./bakedocs.toml` when it exists
4. `$BAKEDOCS_CONFIG_HOME/bakedocs.toml`, or the XDG/home fallback

There is no ancestor traversal, implicit system-wide search, or merging of multiple discovered config files in the first release.

Explicit selectors are fail-closed. If `--config` or `$BAKEDOCS_CONFIG` names a missing, unreadable, or invalid file, the command exits non-zero and does not try a lower-priority source. Missing discovered candidates are skipped. If no config exists, commands use built-in defaults.

A future `bakedocs config` diagnostic command should print the selected source and all discovery candidates. Text output is for humans; `--format json` provides stable fields for scripts:

```json
{
  "source": "project",
  "path": "/work/proposal/bakedocs.toml",
  "candidates": [],
  "environment": {
    "BAKEDOCS_CONFIG": null,
    "BAKEDOCS_CONFIG_HOME": null
  }
}
```

The final schema will list candidates even when an explicit selector wins, with a `considered` boolean, so diagnostics remain complete.

## Path semantics

- Every CLI path argument expands bare `~` and leading `~/` through one shared Bash helper, including quoted and `--option=~/path` forms the shell does not expand.
- Path values read from environment variables and config files use the same expansion helper.
- `~user` is not supported.
- A relative explicit config selector is relative to PWD.
- A relative source or output argument is relative to PWD.
- A relative path stored inside `bakedocs.toml`, including a font, stylesheet, or Pandoc template, is relative to that config file's directory. Relative paths inside `brand.yml` are relative to the brand directory.
- Diagnostic output retains the useful selected spelling and also supplies a normalised absolute path in JSON. It does not require the target to be canonicalisable before reporting an error.

The config-relative rule is deliberate: `brand/logo.svg` must continue to work when a project or user brand directory is invoked from another PWD. A logo may instead use an absolute path, `~/`, a symlink that resolves outside the profile, a remote HTTP(S) URL, a protocol-relative URL, or a data URL. Local logo paths must resolve to readable regular files no larger than 10 MiB. This logo flexibility does not relax the profile-containment requirement for font contracts. Users are responsible for determining whether they may use and redistribute their configured logos.

## Configuration model

Illustrative TOML:

```toml
default_brand = "example"
default_output = "pdf"

[pandoc]
executable = "pandoc"
from = "markdown"

[pdf]
renderer = "chromium"
paper = "a4"

[renderers.chromium]
executable = "chromium"

[renderers.weasyprint]
executable = "weasyprint"

[brands.example]
name = "Example Organisation"
logo = "brands/example/logo.svg"
tokens = "brands/example/tokens.css"
document_style = "styles/document.css"
presentation_style = "styles/reveal.css"
```

Brand token CSS defines semantic custom properties, not component-specific selectors:

```css
:root {
  --brand-primary: #26374a;
  --brand-accent: #287f8f;
  --brand-highlight: #d09b32;
  --brand-surface: #f4f1e9;
  --brand-ink: #20272d;
  --brand-heading-font: Georgia, serif;
  --brand-body-font: Arial, sans-serif;
}
```

Print and Reveal styles consume these tokens independently. A brand can override either style, but ordinary profiles should only need metadata, assets, and token values.

## Source metadata

Supported front matter for the first release:

```yaml
title: "Service review"
subtitle: "Quarterly governance paper"
author: "Operations Team"
date: "2026-08-26"
reference: "OPS-2026-004"
version: "1.0"
status: "Approved"
language: "en-GB"
```

Unknown metadata passes through to Pandoc. Required fields may be declared by a project config, but the built-in renderer requires only a title for cover-page output.

## Metadata interpolation

`--values <PATH>` is repeatable on `pdf`, `html`, and `slides`. Each path is an explicit readable YAML or JSON metadata input no larger than 1 MiB and follows the normal PWD-relative and `~` expansion rules. Pandoc applies the selected brand metadata first, values files in command-line order, and source front matter last. Later files replace earlier values at the same top-level key; maps are not recursively merged. The selected profile exclusively owns resource-bearing logo metadata, regardless of merged metadata layers.

The interpolation grammar is `{{ identifier }}` with optional surrounding whitespace and dotted lookup. Each identifier segment matches `[A-Za-z_][A-Za-z0-9_-]*`. `{{{{ identifier }}}}` emits a literal placeholder. There are no expressions, functions, filters, control flow, includes, environment values, or evaluation. Expansion is limited to 1 MiB per render and nested references are limited to 32 levels.

Interpolation occurs after Markdown parsing in metadata, prose, headings, tables, link labels, link titles, and link destinations. Inline code, code blocks, math, attributes, identifiers, image paths, and citation keys remain literal. Resolved values are scalar metadata converted to plain text; maps, lists, missing paths, malformed placeholders, and cycles are errors. Diagnostics list identifiers but never resolved values. Values that resemble Markdown or HTML remain inert text, and interpolated link destinations pass through the normal unsafe-scheme validation before output publication.

Images and raw nodes are forbidden in all document metadata. The renderer replaces merged CSS, header-include, body-include, logo, and Reveal.js URL metadata with trusted runtime and selected-profile values before writing output. Language tags are validated against the supported Pandoc translation set with value-free diagnostics.

## Rendering pipeline

### HTML and PDF

1. Resolve configuration and brand profile.
2. Validate all local inputs, values layers, and offline policy.
3. Invoke Pandoc with an argument array, never through a shell string.
4. Interpolate scalar metadata in the parsed document tree and apply the resource policy.
5. Generate standalone semantic HTML with embedded local assets by default.
6. Stop after HTML for `--to html`.
7. Pass the exact intermediate HTML to the selected renderer adapter for `--to pdf`.
8. Validate that every expected artefact exists and is non-empty.
9. Write a render manifest next to the output when requested.

The intermediate HTML can be retained with `--keep-intermediate`; otherwise a secure temporary directory is removed after successful or failed rendering.

### Reveal.js

1. Resolve the same brand profile and presentation-specific stylesheet.
2. Invoke Pandoc's Reveal.js writer with a pinned Reveal.js URL from config.
3. Produce static HTML without vendoring Reveal.js.
4. Reject offline mode if the chosen profile requires CDN resources and no local resource mapping is configured.

Two-dimensional slide structure follows the established house convention: level-one sections form the horizontal story and level-two sections provide vertical optional depth.

## Renderer adapters

Every adapter implements the conceptual operations `check`, `version`, and `render_html_to_pdf`. Adapter commands receive explicit input and output paths and return captured structured diagnostics.

Initial candidates:

- **Chromium**: baseline because it is already deployed, fast, and produced acceptable evaluation output. Limitations include weaker paged-media features and platform-dependent executable names.
- **WeasyPrint**: candidate for running headers, footers, counters, and mature print CSS without browser automation. Verify SVG, modern CSS custom properties, PDF links, and performance.
- **Vivliostyle**: candidate for strongest standards-based paged media and complex publications. Verify installation weight, Node runtime implications, command stability, and redistribution model.

`bakedocs` does not download an adapter automatically. `check` names the missing executable and provides a documentation URL; installation remains an explicit user or package-manager action.

## Reproducibility and offline behaviour

- The manifest records source digest, config digest, brand name, output digest, Pandoc version, renderer name and version, Reveal.js version where applicable, and the exact effective options after redaction.
- Local assets are embedded in standalone HTML by default.
- Remote assets are rejected under `--offline` before invoking a renderer.
- Network access is never introduced merely to discover a version.
- A deterministic mode may normalise generated timestamps, but byte-identical PDF output is not promised until each adapter proves it.

## Security

- Spawn executables directly with argument arrays; never concatenate source content or paths into a shell command.
- Treat Markdown raw HTML, SVG, remote URLs, and renderer flags as untrusted input at the CLI boundary.
- Default to no JavaScript for print documents. Reveal.js necessarily uses JavaScript and is a separate output mode.
- Do not allow document metadata to add arbitrary renderer command-line flags.
- Bound subprocess time, captured output, input size, embedded-resource size, and recursive include depth.
- Use a new renderer profile or isolated user-data directory rather than a user's normal Chromium profile.
- Redact credentials in URLs and environment diagnostics.
- Never put secrets in generated HTML, manifests, logs, or PDF metadata.

## Output contract

On success, stdout contains only the primary output path. Warnings, tool versions, and hints go to stderr. Errors are non-zero and identify the failing stage, executable, and safe next action. Add structured JSON output only when a real script or agent consumer requires it.

## Portability

The MVP ships as one Bash executable plus its filters, templates, and styles. Brand profiles remain external configuration; the fictional repository example is selected explicitly and is not an implicit installed default. `s/install` uses `$HOME/.local` unless `--prefix` selects another path, creates a complete versioned payload under `<prefix>/lib/bakedocs/releases/`, and atomically replaces the relative `<prefix>/bin/bakedocs` symlink only after that payload validates. Previous payloads remain available for in-flight commands. The installer refuses unrelated or symlinked command and application paths, does not edit shell startup files, and does not install brand profiles. `s/uninstall` requires the regular bakedocs ownership marker before removing the managed command or payload and preserves unrelated prefix contents.

Direct execution and relative or chained symlink invocation resolve the final executable before locating runtime data. Rendering engines remain external runtime capabilities. Platform discovery may recognise conventional executable names such as `chromium`, `chromium-browser`, `google-chrome`, and application bundle paths, but a configured explicit executable always wins.

Brand profiles may define independent heading and body font contracts using top-level quoted scalar fields. Each configured role supplies a safe CSS family, a profile-contained local WOFF2, WOFF, TTF, or OTF file no larger than 10 MiB, a CSS weight and style, and the expected PDF PostScript font name. Absolute paths, traversal outside the profile, and escaping symlinks are rejected. The renderer embeds the file as a data URI and overrides the corresponding semantic font token. PDF output for a profile with a font contract requires `pdffonts` and is published only when every configured role's expected font is embedded with a Unicode map; complete role fallback is an error and preserves any existing output. Additional PDF fonts are reported as possible partial glyph fallback because Poppler does not expose semantic-role attribution. Font files require explicit provenance, copyright, and redistribution review.

The checkout installer operates inside a prefix controlled by the invoking user and rejects symlinked path components at each operation boundary. Defending against another process owned by the same user replacing validated paths during installation or removal is outside this local installer's trust boundary.

A Rust implementation is a later option only if evidence shows Bash cannot provide the required cross-platform installation, configuration parsing, diagnostics, testing, or distribution quality. It is not the default next step.

Pandoc is also external in the first implementation. Bundling or replacing it is a later distribution decision, not an assumption hidden in MVP scope.

## Accessibility

- Standalone HTML uses semantic headings, landmarks, table headers, link text, document language, and meaningful logo alt text.
- Colour contrast targets WCAG 2.2 AA and information must not depend on colour alone.
- Generated content must reflow at 200% zoom in HTML.
- Reveal.js output must support keyboard navigation, visible focus, reduced motion, and a useful phone-landscape view.
- PDF review includes selectable text, reading order, links, metadata, and screen-reader inspection. A visually correct PDF is not automatically an accessible PDF.
- The first release must not claim PDF/UA compliance unless a renderer and validation workflow prove it.

## Test strategy

The repository should grow a conformance suite shared by every adapter:

```text
conformance/
|-- cases.json
|-- fixtures/
`-- expected/
```

Required cases include headings at page boundaries, long tables, wide tables, nested lists, code, blockquotes, footnotes, SVG, transparent PNG, missing fonts, long unbreakable text, non-ASCII text, local links, remote links, and malicious raw HTML/SVG.

Tests should cover:

- Complete config precedence and fail-closed explicit selectors if TOML configuration is implemented.
- PWD-relative selectors and config-relative asset paths.
- `~` handling for every path argument and both `--option path` and `--option=path` forms.
- Missing and malformed external tools.
- No network access in offline mode.
- Semantic HTML assertions rather than brittle full-byte snapshots.
- PDF page count, text extraction, links, dimensions, and metadata, with visual regression images used as reviewed supporting evidence.
- Configured local-font embedding and deliberate PDF fallback detection.
- Reveal.js slide count, horizontal and vertical structure, overflow checks, keyboard operation, and representative screenshots.

## Bakeoff decision gates

Choose the default PDF adapter only after all available candidates render the same conformance fixture and are scored for:

1. Pagination quality and paged-media capability.
2. HTML/CSS compatibility and brand fidelity.
3. Accessibility of produced PDFs.
4. Installation and cross-platform support.
5. Runtime performance and failure diagnostics.
6. Maintenance health and licence compatibility.
7. Reproducibility and offline operation.

Chromium is the accepted default. Evaluate another renderer only when a real document requirement exposes a Chromium limitation.

## Open questions

- Whether DOCX and ODT are supported inputs or documented pre-conversion workflows.
- Whether the product needs PDF/A, PDF/UA, signatures, form fields, or encryption.
- Whether brand profiles can inherit from another profile or remain deliberately flat.
- Whether logo palette extraction belongs in MVP; CorpDoc demonstrates its usefulness, but explicit reviewed tokens are safer for authoritative brands.
- Whether diagrams use Mermaid, Kroki, another preprocessor, or remain out of scope.
- Which external executables can be redistributed by installers rather than detected separately.
