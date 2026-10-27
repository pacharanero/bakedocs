# Roadmap

Milestones R1-R13 are complete. Their implementation and verification history is recorded in [completed milestones](completed-milestones.md).

## Open

- [ ] **R14 - Stop discarding brand styles when a brand declares no logo**: in `filters/resources.lua`, `Meta` assigns `header-includes` (carrying `tokens.css` plus the bundled `document.css`) but does not set `changed`, and the function ends `if changed then return meta end`. A brand with no logo therefore leaves `changed` false, `Meta` returns `nil`, and Pandoc discards the modified metadata along with every brand style. Output silently falls back to Chromium defaults: US Letter instead of the `@page size: A4`, Times New Roman instead of the brand fonts, and no layout. Exit status is 0 and nothing is written to stderr.

  Reproduced on `v0.1.0` (installed release byte-identical to the working tree) with two brands differing only by a `logo:` line: with a logo the document HTML carries a second `<style>` block of 6041 bytes; without one the block is absent at 2965 bytes. The trigger is confirmed as the `changed` flag rather than the logo itself, because adding unrelated `language: "en"` front matter to the source restores every style through the `meta.lang` promotion path, which does set `changed`.

  The bundled `ohtf` profile is affected and currently renders its filing copy as US Letter in Times. Fixing this should also cover the general case: any brand-driven metadata mutation must mark the document changed, so prefer returning `meta` unconditionally over adding another targeted flag. Worth a conformance check that renders a logo-free brand and asserts A4 dimensions and the expected embedded fonts, since R7 already inspects PDF dimensions and fonts but evidently only for brands carrying logos.

## Release follow-up

- Publish the implemented Bitwarden integration in a future release. The published `v0.1.0` predates R12.

## Deferred until required

- Evaluate WeasyPrint if running headers, running footers, page counters, repeating table headers, or stronger CSS Paged Media support become requirements.
- Evaluate Vivliostyle for book-like publications, mixed page layouts, advanced footnotes, indexes, or similarly complex paged media.
- Consider Rust only if Bash cannot meet evidenced cross-platform, configuration, diagnostics, testability, or distribution requirements.
