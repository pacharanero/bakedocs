# `s/`

The `s/` directory contains the canonical convenience scripts for developing and checking `bakedocs`.

## `s/install`

Installs this checkout under `$HOME/.local` by default. Use `s/install --prefix <path>` for another prefix. Rerun the same command to atomically switch to a complete new payload.

## `s/uninstall`

Removes only an installation managed by `s/install`. Use the same `--prefix` value supplied at installation time.

## `s/check-tools`

Reports the availability and versions of evaluated rendering tools and the optional `pdffonts` font-contract verifier without installing anything.

## `s/lint`

Checks the syntax of the public command, project scripts, and integration tests.

## `s/test`

Parses all maintained Markdown through Pandoc's native writer, runs the isolated command-surface and installation suites, then renders the maintained fixtures through real Chromium and inspects the resulting HTML, Reveal.js, and PDF structures. Rendering conformance requires Poppler's `pdfinfo`, `pdffonts`, and `pdftotext` utilities.

## `s/render`

Renders the synthetic document and slide fixtures through the public command surface. It uses the fictional `example` profile by default; set `BAKEDOCS_BRANDS_DIR` to exercise an external profile root.

```console
s/render
BAKEDOCS_BRANDS_DIR="$HOME/.config/bakedocs/brands" s/render <brand-id>
```

## `s/render-all`

Regenerates synthetic bakeoff output for every profile in `BAKEDOCS_BRANDS_DIR`, falling back to the public example profile, under ignored `out/` directories.
