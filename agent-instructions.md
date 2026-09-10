# Agent Instructions

`bakedocs` turns Markdown into branded PDF, standalone HTML, and Reveal.js presentations. It is an early Bash CLI backed by a successful rendering bakeoff and a product specification; it is not a Rust project.

This file is the entry point for AI coding agents. Read it before changing anything.

## Read First

- [README.md](README.md) - project purpose, current commands, renderer decision, and brand-profile layout.
- [spec/README.md](spec/README.md) - product specification index and reading order.
- [spec/roadmap.md](spec/roadmap.md) - sequenced work with stable item IDs.
- [findings.md](findings.md) - measured bakeoff evidence and discovered compatibility constraints.
- [pacharanero/house-style](https://github.com/pacharanero/house-style/blob/main/AGENTS.md) - adopted cross-repository engineering standards.

## Current State

- The top-level `bakedocs` executable implements the initial Bash command surface against arbitrary source files.
- Brand profiles use `brands/<brand-id>/` directories discovered from project or XDG configuration roots.
- Pandoc plus Chromium is the accepted PDF baseline. The generated PDFs were visually approved.
- WeasyPrint and Vivliostyle are deferred candidates, not required dependencies.
- `templates/reveal.html` is intentional. Pandoc 3.10.2's stock Reveal template uses pre-6 plugin paths; Reveal.js 6 requires the explicit `dist/plugin/*.mjs` imports used here.
- `out/` is ignored generated output. Do not hand-edit or commit it; regenerate it.
- The repository is public and GPL-3.0-or-later licensed. It contains only fictional example branding; do not add third-party marks or private profiles without verified redistribution rights.

## Core Invariants

- Markdown remains the maintained content source. HTML is the semantic intermediate representation for PDF.
- Print and Reveal.js styles stay separate while consuming shared semantic brand tokens.
- Source raw HTML remains disabled. Use supported Markdown structures and fenced divs rather than allowing source content to execute in Chromium.
- Metadata interpolation remains a strict scalar lookup over parsed Pandoc content. Do not grow it into a general template language or reparse resolved values as Markdown.
- Metadata cannot supply images, raw content, CSS, includes, logos, or renderer URLs; those resource-bearing controls remain trusted runtime or selected-profile inputs.
- Offline document rendering rejects remote image resources; slides remain unavailable offline while Reveal.js uses its pinned CDN.
- `BRAND-ID` identifies a brand directory; relative logo paths resolve against that directory, never the caller's PWD, while logos may also use absolute, home-relative, symlinked, or remote locations.
- Invocation must work from any directory once `bakedocs` is installed on `$PATH`, including through a symlink.
- The common PDF path remains Pandoc plus Chromium until a real requirement proves it insufficient.
- Do not add Rust, Python, Node, WeasyPrint, Vivliostyle, or another runtime merely to make the project look more complete. Admit complexity in response to evidence.
- Do not copy logos, fonts, contracts, private administrative material, credentials, or personal data into this repository without checking provenance, redistribution rights, and necessity.
- A configured font contract is fail-closed: keep font files local and embedded, preserve the 10 MiB bound, and verify the expected PostScript names before publishing PDF output.
- Bitwarden is explicit `--bitwarden` opt-in only. Keep raw responses and selected values in bounded pipes/memory, never files or argv. Private rendered intermediates are allowed under the protected-render-files policy in `spec/standard.md`; suppress sensitive tool diagnostics and never pass vault metadata to writers. Use fake `bw` in tests; real vault access requires separate approval.
- Never claim PDF/UA compliance from Chromium's `Tagged: yes` flag alone.

## Immediate Direction

Continue hardening the smallest useful Bash CLI described by [R4](spec/completed-milestones.md):

```console
bakedocs pdf <SOURCE> <BRAND-ID> [--values <PATH> | --bitwarden <PATH> ...] [--output <PATH>]
bakedocs html <SOURCE> <BRAND-ID> [--values <PATH> | --bitwarden <PATH> ...] [--output <PATH>]
bakedocs slides <SOURCE> <BRAND-ID> [--values <PATH> | --bitwarden <PATH> ...] [--output <PATH>]
bakedocs brands list
bakedocs check
```

Prefer a single readable executable until functions are genuinely reusable. Keep data on stdout and diagnostics on stderr. Preserve argument boundaries and quote every path passed to Pandoc or Chromium; do not construct commands with `eval`.

## Workflow

- `s/check-tools` - report which evaluated renderers are available.
- `s/install` / `s/uninstall` - install or remove a guarded user-prefix runtime payload.
- `s/package-release` - create the deterministic versioned archive, bootstrap installer, and checksums consumed by manually approved tagged release automation.
- `s/render [brand]` - render the synthetic document and deck through the fictional example profile or `BAKEDOCS_BRANDS_DIR`.
- `s/render-all` - regenerate outputs for every profile in the selected root.
- `s/lint` - check every executable shell script's syntax.
- `s/test` - parse maintained Markdown and run command-surface, checkout-installation, release-bootstrap, and real-rendering conformance tests; the latter requires Chromium and Poppler utilities.
- `tests/bitwarden` - exercise isolated fake-vault selection, failure, privacy, and real rendering with GNU `timeout`/`gtimeout`; no real vault or installed `bw` is needed.

For presentation changes, serve the repository over HTTP and inspect every stable slide at 1280 x 720 and phone landscape. For print changes, inspect every page produced by the example profile and at least the cover for any additional test profile; successful process exit is not visual proof.

## Before Every Commit

Run the checks enforced by CI:

```console
s/lint
s/test
reuse lint
zizmor --strict-collection .
```

For renderer changes, also run `s/render-all` and the relevant visual and PDF inspection described above. Inspect the diff and state any visual or dependency checks that could not be performed.

## Git Workflow

- This is a solo public repository. Direct commits to `main` are permitted after validation while the repository remains single-maintainer.
- Once a remote exists, protect `main` at the house-style Solo tier: require CI and block force pushes and branch deletion.
- Commit and push each validated coherent parcel when a remote is configured. Ask before choosing a different branch or review workflow.
- Use conventional commit messages.

## Assurance

- Review the diff and validation output after agent changes.
- Treat visual review as independent evidence for print and slide changes; automated process success is not sufficient.
- Treat all brand names, marks, and referenced assets as third-party material unless provenance explicitly says otherwise.

## Approval Required

- Ask before creating a remote, publishing the repository or a package, uploading brand assets, installing system-wide dependencies, or taking any externally visible action.
- Ask before changing the project licence or extracting material for public release.
- Never force-push, bypass branch protection, delete remote state, or handle production credentials without explicit approval.
