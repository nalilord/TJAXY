# TJAXY Tests

Run the Delphi package and smoke/conformance suite from the repository root:

```bash
./run-tests-wsl.sh
```

The script builds the Win64 package and runs JSON, cross-format, YAML native,
XML smoke, optional XML conformance, Avro, and TOML tests. Pass another
platform name as the first argument if the build helper supports it.

## XML Conformance Suite

The W3C XML Conformance Test Suite is not bundled because it contains hundreds
of fixture files. Download it when needed:

```text
https://www.w3.org/XML/Test/xmlts20130923.zip
```

Extract the archive to `Tests/xmlconf` so `Tests/xmlconf/xmlconf.xml` exists.
`run-tests-wsl.sh` skips XML conformance automatically when that directory is
not present.

## YAML Test Suite Runner

This directory contains two test programs:

- `YAMLNativeTests.dpr` runs fast Delphi-native regression tests for the DOM, writer, KYAML strict parser, YAML parser, and multi-document stream handling.
- `YAMLTestSuiteRunner.dpr` checks `TYAML` against the generated data layout from the official YAML test suite.

## YAML Test Suite

Fetch the released data fixtures outside this repository:

```bash
git clone --branch data-2022-01-17 --depth 1 https://github.com/yaml/yaml-test-suite.git /tmp/yaml-test-suite-data
```

Build with Delphi from the `Tests` directory.

Run (WSL):

```bash
./Win64/Debug/YAMLTestSuiteRunner.exe "$(wslpath -w /tmp/yaml-test-suite-data)" --quiet --failures "$(wslpath -w /tmp/kyaml-yaml-failures.tsv)"
```

By default the runner reports counts and exits successfully even when YAML conformance failures exist. Use `--strict` to return exit code `1` when any suite expectation fails.

Useful filters:

- `--valid-only` runs only fixtures that should parse.
- `--invalid-only` runs only fixtures with an `error` file.
- `--quiet` suppresses per-case failure details.
- `--failures <file.tsv>` writes failed expectations as TSV with test id, expected/actual result, name, path, and message.

Current baseline against `data-2022-01-17`:

```text
total run        : 402
expected valid   : 308
expected invalid : 94
valid passed     : 308
valid failed     : 0
invalid passed   : 94
invalid failed   : 0
```
