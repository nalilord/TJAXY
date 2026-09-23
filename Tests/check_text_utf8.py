#!/usr/bin/env python3
"""Check TJAXY text fixtures with independent Python format readers."""

import json
from pathlib import Path
import sys
import tomllib
import xml.etree.ElementTree as ET

import yaml


EXPECTED = "€中😀"


def read_utf8(directory: Path, name: str) -> str:
    data = (directory / name).read_bytes()
    assert not data.startswith(b"\xef\xbb\xbf"), f"{name}: unexpected BOM"
    assert b"\x00" not in data, f"{name}: NUL byte"
    return data.decode("utf-8", errors="strict")


def main(directory: Path) -> None:
    values = {
        "JSON": json.loads(read_utf8(directory, "data.json"))["name"],
        "YAML": yaml.safe_load(read_utf8(directory, "data.yaml"))["name"],
        "TOML": tomllib.loads(read_utf8(directory, "data.toml"))["name"],
        "XML": ET.fromstring(read_utf8(directory, "data.xml")).text,
        "Avro JSON": json.loads(read_utf8(directory, "data.avro.json")),
    }
    for name, value in values.items():
        expected = EXPECTED[:2] if name == "XML" else EXPECTED
        assert value == expected, f"{name}: {value!r} != {expected!r}"
        print(f"[PASS] independent {name} UTF-8 reader")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("Usage: check_text_utf8.py <fixture-directory>")
    main(Path(sys.argv[1]))
