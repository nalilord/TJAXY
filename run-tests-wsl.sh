#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLATFORM="${1:-Win64}"
BUILD_HELPER="$(mktemp /tmp/tjaxy-build.XXXXXX.sh)"

cleanup() {
  rm -f "$BUILD_HELPER"
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

build "Tests/TJAXY.JSON.Smoke.dpr"
run_exe "TJAXY.JSON.Smoke.exe"

build "Tests/TJAXY.CrossFormat.dpr"
run_exe "TJAXY.CrossFormat.exe"

build "Tests/YAMLNativeTests.dpr"
run_exe "YAMLNativeTests.exe"

build "Tests/TJAXY.XML.Smoke.dpr"
run_exe "TJAXY.XML.Smoke.exe"

build "Tests/TJAXY.XML.Conformance.dpr"
if [[ -d "$ROOT/Tests/xmlconf" ]]; then
  run_exe "TJAXY.XML.Conformance.exe" "$(wslpath -w "$ROOT/Tests/xmlconf")" --quiet
else
  printf 'Skipping XML conformance: Tests/xmlconf not found\n'
fi

build "Tests/TJAXY.Avro.Smoke.dpr"
run_exe "TJAXY.Avro.Smoke.exe"

build "Tests/TJAXY.TOML.Smoke.dpr"
run_exe "TJAXY.TOML.Smoke.exe"

printf 'TJAXY test suite passed for %s\n' "$PLATFORM"
