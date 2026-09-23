#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLATFORM="${1:-Win64}"
BUILD_HELPER="$(mktemp /tmp/tjaxy-build.XXXXXX.sh)"

cleanup() {
  rm -f "$BUILD_HELPER"
  if [[ -n "${WIRE_OUT:-}" ]]; then rm -f "$WIRE_OUT"; fi
  if [[ -n "${WIRE_IN:-}" ]]; then rm -f "$WIRE_IN"; fi
  if [[ -n "${TEXT_OUT:-}" ]]; then rm -rf "$TEXT_OUT"; fi
}
trap cleanup EXIT

tr -d '\r' < "$ROOT/build-wsl-generic.sh" > "$BUILD_HELPER"

build() {
  PROJECT_ROOT="$ROOT" bash "$BUILD_HELPER" "$1" "$PLATFORM"
}

run_exe() {
  local exe="$ROOT/Bin/$PLATFORM/$1"
  shift
  "$exe" "$@"
}

build "Source/TJAXY.dpk"

build "Tests/TJSON.TestRunner.dpr"
run_exe "TJSON.TestRunner.exe"

build "Tests/TJAXY.RTTI.Heap.Smoke.dpr"
run_exe "TJAXY.RTTI.Heap.Smoke.exe"

build "Tests/TJAXY.JSON.Smoke.dpr"
run_exe "TJAXY.JSON.Smoke.exe"

build "Tests/TJAXY.CrossFormat.dpr"
run_exe "TJAXY.CrossFormat.exe"

build "Tests/TJAXY.Text.WireFixture.dpr"
TEXT_OUT="$(mktemp -d "$ROOT/Bin/$PLATFORM/tjaxy-text-out-XXXXXX")"
run_exe "TJAXY.Text.WireFixture.exe" "$(wslpath -w "$TEXT_OUT")"
python3 "$ROOT/Tests/check_text_utf8.py" "$TEXT_OUT"

build "Tests/YAMLNativeTests.dpr"
run_exe "YAMLNativeTests.exe"

build "Tests/YAMLTestSuiteRunner.dpr"
if [[ -n "${YAML_SUITE_DIR:-}" && -d "$YAML_SUITE_DIR" ]]; then
  run_exe "YAMLTestSuiteRunner.exe" "$(wslpath -w "$YAML_SUITE_DIR")" --quiet --strict
  run_exe "YAMLTestSuiteRunner.exe" "$(wslpath -w "$YAML_SUITE_DIR")" --quiet --basic-semantic --strict --strict-semantic
else
  printf 'Skipping external YAML fixtures: set YAML_SUITE_DIR to the pinned fixture directory\n'
fi

build "Tests/TJAXY.YAML.Heap.Smoke.pas"
run_exe "TJAXY.YAML.Heap.Smoke.exe"

build "Tests/TJAXY.XML.Smoke.dpr"
run_exe "TJAXY.XML.Smoke.exe"

build "Tests/TJAXY.XML.Conformance.dpr"
if [[ -n "${XML_SUITE_DIR:-}" && -d "$XML_SUITE_DIR" ]]; then
  run_exe "TJAXY.XML.Conformance.exe" "$(wslpath -w "$XML_SUITE_DIR")" --quiet
elif [[ -d "$ROOT/Tests/xmlconf" ]]; then
  run_exe "TJAXY.XML.Conformance.exe" "$(wslpath -w "$ROOT/Tests/xmlconf")" --quiet
else
  printf 'Skipping XML conformance: set XML_SUITE_DIR or provide Tests/xmlconf\n'
fi

build "Tests/TJAXY.Avro.Smoke.dpr"
run_exe "TJAXY.Avro.Smoke.exe"

build "Tests/TJAXY.Avro.WireFixture.dpr"
WIRE_OUT="$(mktemp "$ROOT/Bin/$PLATFORM/tjaxy-avro-out-XXXXXX.avro")"
WIRE_IN="$(mktemp "$ROOT/Bin/$PLATFORM/tjaxy-avro-in-XXXXXX.avro")"
run_exe "TJAXY.Avro.WireFixture.exe" write "$(wslpath -w "$WIRE_OUT")"
python3 "$ROOT/Tests/check_avro_deflate.py" "$WIRE_OUT" "$WIRE_IN"
run_exe "TJAXY.Avro.WireFixture.exe" read "$(wslpath -w "$WIRE_IN")"

build "Tests/TJAXY.TOML.Smoke.dpr"
run_exe "TJAXY.TOML.Smoke.exe"

printf 'TJAXY test suite passed for %s\n' "$PLATFORM"
