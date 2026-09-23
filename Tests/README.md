# TJAXY Tests

Run the Delphi package and smoke/conformance suite from the repository root:

```bash
./run-tests-wsl.sh
```

The script builds the selected Delphi package and runs JSON, cross-format,
YAML native, XML smoke, optional XML conformance, Avro (including an independent
Python raw-deflate fixture exchange), a Python UTF-8 reader exchange for the
five text codecs, and TOML tests. The text checker needs Python 3.11+
(`tomllib`) and PyYAML (`python3 -m pip install pyyaml`). `Win64` is the default;
`./run-tests-wsl.sh Win32` runs the same suite with the 32-bit compiler.

FPC 3.2.2 Linux x86-64 smoke coverage for Core, JSON, and YAML configuration:

```bash
FPC_EXTRA_ARGS=-Mdelphi OUTPUT_ROOT=/tmp/tjaxy-audit-fpc \
  bash build-wsl-generic.sh Tests/TJAXY.FPC.Smoke.pas Linux64
/tmp/tjaxy-audit-fpc/Linux64/TJAXY.FPC.Smoke
```

The FPC smoke also checks explicit unsupported mapping errors, mapper
capabilities, and an object-only `ITJAXYObjectMapper` registration. Delphi
Win32/Win64 use the built-in RTTI mapper and run the larger mapping and heap
regressions through `run-tests-wsl.sh`.

## XML Conformance Suite

The W3C XML Conformance Test Suite is not bundled because it contains hundreds
of fixture files. Download it when needed:

```text
https://www.w3.org/XML/Test/xmlts20130923.zip
```

Extract the archive to `Tests/xmlconf` so `Tests/xmlconf/xmlconf.xml` exists.
Alternatively set `XML_SUITE_DIR` to a Windows-visible extracted `xmlconf`
directory outside the repository. `run-tests-wsl.sh` skips XML conformance
when neither path is present.

## YAML Test Suite Runner

This directory contains two test programs:

- `YAMLNativeTests.dpr` runs fast Delphi-native regression tests for the DOM, writer, KYAML strict parser, YAML parser, and multi-document stream handling.
- `YAMLTestSuiteRunner.dpr` checks `TYAML` against the generated data layout from the official YAML test suite.

## YAML Test Suite

Fetch the pinned data fixtures outside this repository. The Windows runner
cannot follow the release's Linux symlink indexes (`name` and `tags`) on a WSL
drive, so copy only the four-character case directories to a Windows-visible
path:

```bash
git clone --branch data-2022-01-17 --depth 1 \
  https://github.com/yaml/yaml-test-suite.git /tmp/yaml-test-suite-data
mkdir -p /mnt/i/Delphi/tjaxy-yaml-cases
for case_dir in /tmp/yaml-test-suite-data/[A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9]; do
  cp -a "$case_dir" /mnt/i/Delphi/tjaxy-yaml-cases/
done
```

This uses revision `6e6c296ae9c9d2d5c4134b4b64d01b29ac19ff6f`.
Build from the repository root:

```bash
./build-wsl-generic.sh Tests/YAMLTestSuiteRunner.dpr Win64
```

Run from WSL:

```bash
./Bin/Win64/YAMLTestSuiteRunner.exe \
  "$(wslpath -w /mnt/i/Delphi/tjaxy-yaml-cases)" --quiet --strict \
  --failures "$(wslpath -w /mnt/i/Delphi/tjaxy-yaml-failures.tsv)"
```

Set `YAML_SUITE_DIR=/mnt/i/Delphi/tjaxy-yaml-cases` when running
`run-tests-wsl.sh` to include the external YAML checks. It runs full-suite
acceptance with `--strict`, then the declared basic semantic subset with
`--basic-semantic --strict-semantic`.

The runner reports parse acceptance, document count, and value/type comparisons
against `in.json` for single-document fixtures. `--strict` fails on acceptance
errors; `--strict-semantic` also fails on document-count or value/type errors.
`--basic-semantic` selects valid single-document cases with an `in.json`
expectation and simple one-line scalar/flow or block mapping/sequence syntax.
It excludes anchors, aliases, tags, directives, explicit keys, block scalar
indicators, tabs, document markers, and multiline plain scalars. This is a
defined interoperability subset; unrestricted semantic differences remain
visible in the full run.
The TSV file records both kinds of difference.

Useful filters:

- `--valid-only` runs only fixtures that should parse.
- `--invalid-only` runs only fixtures with an `error` file.
- `--quiet` suppresses per-case failure details.
- `--failures <file.tsv>` writes failed expectations as TSV with test id, expected/actual result, name, path, and message.

Current Win64 baseline against that pinned revision (23 September 2026):

```text
total run        : 402
expected valid   : 308
expected invalid : 94
valid passed     : 308
valid failed     : 0
invalid passed   : 94
invalid failed   : 0
doc count passed : 303
doc count failed : 5
semantic passed  : 180
semantic failed  : 76
semantic skipped : 52
```

The basic semantic subset passes 45/45 document counts and value/type
comparisons on Win32 and Win64. The unrestricted run still reports 76
semantic differences, mainly advanced multiline scalar, tag, anchor, and
folding cases. They remain known YAML compatibility limitations.

The five document-count differences are empty/comment-only streams, which
`TYAML` currently exposes as one null root document. Semantic skips are valid
fixtures without an `in.json` expectation or with multiple JSON texts.
Acceptance success alone does not imply YAML semantic conformance.

The W3C XML 20130923 supported slice currently passes 288 valid/not-well-formed
cases and skips 425 cases outside the runner's declared scope. Reproduce with
the archive from the W3C URL above, extracted to a Windows-visible directory,
then run `TJAXY.XML.Conformance.exe <xmlconf-dir> --quiet`.
