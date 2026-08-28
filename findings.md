# Bakeoff findings

## Environment

Measured on 26 August 2026:

| Tool | Result |
| --- | --- |
| Pandoc | Available, version 3.10.2 |
| Chromium | Available, version 151.0.7922.173 |
| WeasyPrint | Not installed as an executable |
| Vivliostyle CLI | Not installed as an executable |

## Initial architecture finding

Pandoc is the strongest common front end for this project because it already ingests Markdown, ODT, and DOCX; produces semantic standalone HTML; and has a first-class Reveal.js writer. The renderer boundary should come after HTML generation. This keeps content parsing, brand tokens, and renderer selection separate.

CorpDoc validates the product need and offers useful ideas such as brand profiles, cover variants, logo colour extraction, document-control metadata, table handling, and AI-facing authoring guidance. Its ReportLab-native layout is less aligned with this project's requirement for Reveal.js and interchangeable browser or paged-media renderers. Treat it as a product and schema reference rather than the rendering core.

## Evaluation matrix

Legend: pass, partial, fail, unavailable, not yet tested.

| Criterion | Pandoc + Chromium | Pandoc + WeasyPrint | Pandoc + Vivliostyle |
| --- | --- | --- | --- |
| Markdown ingestion | Pass | Pass through shared Pandoc stage | Pass through shared Pandoc stage |
| Standalone accessible HTML | Pass | Pass through shared Pandoc stage | Pass through shared Pandoc stage |
| PDF on this host | Pass | Unavailable | Unavailable |
| SVG and PNG logo support | Pass for tested assets | Not yet tested | Not yet tested |
| CSS custom properties | Pass | Not yet tested | Not yet tested |
| Page-break control | Pass for explicit breaks | Not yet tested | Not yet tested |
| Running headers and footers | Limited Chromium paged-media model | Expected strength; verify | Expected strength; verify |
| Wide-table handling | Requires explicit design or preprocessing | Requires explicit design or preprocessing | Strong paged-media candidate; verify |
| Reveal.js output | Pass via Pandoc writer and an explicit Reveal.js 6 template | Same shared Reveal.js output | Same shared Reveal.js output |
| Single-binary deployment | No, external engine required | No, external engine required | No, external engine required |

## Acceptance checks still required

- Install or run isolated current versions of WeasyPrint and Vivliostyle only after confirming their latest stable releases and installation requirements.
- Compare PDF text extraction and tagged-PDF accessibility rather than judging screenshots alone.
- Decide whether PDF/A, PDF/UA, signatures, form fields, or DOCX output are product requirements. They materially affect renderer choice.

## Chromium baseline results

Representative profiles with SVG and transparent PNG artwork rendered successfully to standalone HTML, five-page A4 PDFs, and Reveal.js source. Chromium identified every PDF as tagged, retained selectable text, embedded the fonts it actually used, preserved logo aspect ratios, and produced no JavaScript or file attachments. The PDFs report `Skia/PDF m151` as producer and PDF 1.4 as their format.

Visual inspection covered every page of the primary evaluation PDF and the cover of each additional profile. No clipped table, orphan heading, distorted logo, unexpected blank page, or overlapping content was found. Named PDF destinations exist for the contents links, headings, footnote, and return link. The tagged flag and named destinations are useful baseline evidence, not a PDF/UA claim.

Reveal.js was inspected at 1280 × 720 and 844 × 390, including horizontal navigation and the vertical `Inputs` and `Optional depth` slides. The current deck has no browser console errors, clipped content, or phone-landscape overlap. Review captures are temporary artefacts and are not part of the repository.

One evaluation profile requested a locally unavailable font and Chromium fell back to an embedded system font, demonstrating that a CSS family name is not enough to guarantee intended typography. The product needs explicit font-file support, licence-aware embedding, and a detectable fallback warning if typography is part of the brand contract.

Pandoc 3.10.2's stock Reveal.js template still points to the pre-6 plugin paths under `plugin/<name>/<name>.js`. Reveal.js 6 moved CDN plugin files to `dist/plugin/<name>.js` and its modules to `dist/plugin/<name>.mjs`. The bakeoff therefore uses a small explicit Reveal.js 6 template with ES module imports. This is a renderer-version compatibility boundary that the future CLI must test and own.
