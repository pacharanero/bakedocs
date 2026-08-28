# `s/`

The `s/` directory contains the canonical convenience scripts for developing and checking `bakedocs`.

## `s/check-tools`

Reports the availability and versions of evaluated rendering tools without installing anything.

## `s/lint`

Checks the syntax of the public command, project scripts, and integration tests.

## `s/test`

Parses all maintained Markdown through Pandoc's native writer, then runs the isolated command-surface integration suite.

## `s/render`

Renders the synthetic document and slide fixtures through the public command surface. It uses the fictional `example` profile by default; set `BAKEDOCS_BRANDS_DIR` to exercise an external profile root.

```console
s/render
BAKEDOCS_BRANDS_DIR="$HOME/.config/bakedocs/brands" s/render <brand-id>
```

## `s/render-all`

Regenerates synthetic bakeoff output for every profile in `BAKEDOCS_BRANDS_DIR`, falling back to the public example profile, under ignored `out/` directories.
