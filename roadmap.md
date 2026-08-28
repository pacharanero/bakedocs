# Roadmap

Legend: [x] done, [~] in progress or partial, [ ] not started

- [x] **R1 - Prove Pandoc and Chromium document rendering**: representative profiles render approved standalone HTML and tagged five-page A4 PDFs.
- [x] **R2 - Prove branded Reveal.js output**: an explicit Reveal.js 6 ES-module template renders desktop and phone-landscape slides without console errors or clipping.
- [x] **R3 - Select the project name and implementation level**: use `bakedocs`; implement the MVP in Bash and consider Rust only in response to demonstrated limitations.
- [x] **R4 - Build the public Bash command surface**: implement `bakedocs pdf|html|slides <SOURCE> <BRAND-ID>`, `brands list`, and `check` against arbitrary source files.
- [x] **R5 - Migrate brand profiles to directories**: use self-contained `brands/<id>/` profiles with config-relative assets, discovered from project or XDG configuration roots.
- [ ] **R6 - Make installation path-independent**: install `bakedocs` on `$PATH`, resolve accompanying templates/styles reliably through direct and symlinked invocation, and document uninstall.
- [~] **R7 - Add conformance checks**: shell syntax, command dispatch, missing-tool failures, unknown brands, output paths, HTML semantics, and Reveal.js structure are automated; PDF structure and broader fixtures remain.
- [x] **R8 - Decide output retention**: keep `out/` as ignored local generated output; regenerate it from maintained fixtures and explicitly selected profiles rather than committing rendered brand assets.
- [ ] **R9 - Make brand fonts explicit**: support licence-reviewed local font files and detect or report fallback where typography is part of the brand contract.
- [x] **R10 - Apply repository house style**: initialise and scaffold the repository, adopt GPL-3.0-or-later, add focused ignore/editor settings, and enforce meaningful checks in CI.

## Deferred until required

- Evaluate WeasyPrint if running headers, running footers, page counters, repeating table headers, or stronger CSS Paged Media support become requirements.
- Evaluate Vivliostyle for book-like publications, mixed page layouts, advanced footnotes, indexes, or similarly complex paged media.
- Consider Rust only if Bash cannot meet evidenced cross-platform, configuration, diagnostics, testability, or distribution requirements.
