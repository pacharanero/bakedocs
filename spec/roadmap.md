# Roadmap

Legend: [x] done, [~] in progress or partial, [ ] not started

- [x] **R1 - Prove Pandoc and Chromium document rendering**: representative profiles render approved standalone HTML and tagged five-page A4 PDFs.
- [x] **R2 - Prove branded Reveal.js output**: an explicit Reveal.js 6 ES-module template renders desktop and phone-landscape slides without console errors or clipping.
- [x] **R3 - Select the project name and implementation level**: use `bakedocs`; implement the MVP in Bash and consider Rust only in response to demonstrated limitations.
- [x] **R4 - Build the public Bash command surface**: implement `bakedocs pdf|html|slides <SOURCE> <BRAND-ID>`, `brands list`, and `check` against arbitrary source files.
- [x] **R5 - Migrate brand profiles to directories**: use self-contained `brands/<id>/` profiles with config-relative assets, discovered from project or XDG configuration roots.
- [x] **R6 - Make installation path-independent**: install `bakedocs` on `$PATH`, resolve accompanying templates/styles reliably through direct and symlinked invocation, and document uninstall.
- [x] **R7 - Add conformance checks**: automate shell syntax and command behaviour, render the maintained fixtures through real Pandoc and Chromium, inspect semantic HTML and Reveal.js structure, and verify PDF dimensions, metadata, logical tags, links, selectable text, and embedded Unicode fonts with Poppler.
- [x] **R8 - Decide output retention**: keep `out/` as ignored local generated output; regenerate it from maintained fixtures and explicitly selected profiles rather than committing rendered brand assets.
- [x] **R9 - Make brand fonts explicit**: support licence-reviewed local heading and body font files, embed them portably, validate bounded profile-relative inputs, reject complete role fallback, and report additional PDF fonts as possible partial glyph fallback.
- [x] **R10 - Apply repository house style**: initialise and scaffold the repository, adopt GPL-3.0-or-later, add focused ignore/editor settings, and enforce meaningful checks in CI.
- [x] **R11 - Add layered values and metadata interpolation**: accept repeatable fail-closed YAML or JSON `--values` inputs, apply ordered metadata precedence, and resolve strict nested scalar placeholders in the parsed Pandoc document without introducing expressions, control flow, includes, or executable evaluation.

## Deferred until required

- [ ] **R12 - Add opt-in Bitwarden values integration**: after R11 establishes the provider-neutral values model, investigate an explicit Bitwarden-backed values source for genuinely sensitive fields such as bank details, tax identifiers, signatures, or account-specific data. It must never be required for ordinary public company information, must not depend on an interactive vault session in unattended rendering, must map only explicitly selected vault fields into named values, and must keep secrets out of stdout, diagnostics, temporary files, generated manifests, HTML, and PDF metadata except where the source deliberately renders the value into the document itself. Prefer consuming a short-lived structured stream from the official Bitwarden CLI over teaching `bakedocs` vault semantics or storing vault exports.
- [x] **R13 - Add a release-backed bootstrap installer**: deterministic versioned runtime payloads, `SHA256SUMS`, guarded Linux/macOS bootstrap installation, dependency routes, adversarial tests, and manually approved tagged release automation are implemented. The public `v0.1.0` release passed installation, real rendering, and verified uninstall through the latest-release URL.
- Evaluate WeasyPrint if running headers, running footers, page counters, repeating table headers, or stronger CSS Paged Media support become requirements.
- Evaluate Vivliostyle for book-like publications, mixed page layouts, advanced footnotes, indexes, or similarly complex paged media.
- Consider Rust only if Bash cannot meet evidenced cross-platform, configuration, diagnostics, testability, or distribution requirements.
