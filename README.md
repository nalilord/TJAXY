# TJAXY

TJAXY is a Delphi-first parser model for TOML, JSON, Avro, XML, YAML, and
other document/data formats. Format codecs share the same core DOM:

- `TTJAXYDocument`
- `TTJAXYParser`
- `TTJAXYValue`
- `TTJAXYObject`
- `TTJAXYArray`

That lets an application keep parser handling generic while still choosing a
specific codec at the boundary.

```pascal
var
  Parser: TTJAXYParser;
begin
  Parser := TJSON.CreateFromFile('config.json');
  try
    Writeln(Parser.Root.AsObject['name'].AsString);
  finally
    Parser.Free;
  end;
end;
```

## Units

- `TJAXY.Core`: shared DOM, writer, templates, RTTI/object mapping
- `TJAXY.TOML`: TOML config codec
- `TJAXY.JSON`: JSON and JSON5 codec
- `TJAXY.Avro`: Avro schema + JSON encoding codec
- `TJAXY.YAML`: KYAML/YAML codec
- `TJAXY.XML`: XML codec

All codecs expose `CreateFromString` / `CreateFromFile` / `CreateFromStream`
class factories plus shorter `FromString` / `FromFile` / `FromStream` aliases
where the format can be loaded without extra state. Avro factories take an
explicit schema string.

## Feature Matrix

| Format | Unit | V1 support | Not yet covered |
| --- | --- | --- | --- |
| TOML | `TJAXY.TOML` | root keys, dotted keys, tables, arrays, arrays of tables, inline tables, basic/literal/multiline strings, decimal/hex/octal/binary integers, floats/special floats, booleans, shared date/time values, comments | full TOML 1.1 compliance edge-case coverage |
| JSON | `TJAXY.JSON` | JSON DOM read/write, JSON5 mode, comments/trailing commas/unquoted keys in JSON5 | streaming SAX-style parser |
| Avro | `TJAXY.Avro` | explicit schema parsing through `TJAXY.JSON`, Avro JSON encoding, binary encoding, single-object encoding, null/deflate object containers with multi-block read, parsing canonical form, CRC-64-AVRO fingerprints, logical date/time/uuid/decimal values, records, enums, arrays, maps, unions, named references, aliases metadata, basic reader/writer schema resolution, primitives, defaults | snappy/zstandard container codecs, full arbitrary-precision decimal, full reader/writer schema resolution matrix |
| XML | `TJAXY.XML` | elements, attributes via `@`, text via `#text`, repeated elements as arrays, namespace preserve/strip modes, CDATA/entity decoding, internal DOCTYPE declaration skipping, self-contained reader/writer | processing instructions round-trip, DTD validation/entity expansion |
| YAML | `TJAXY.YAML` | KYAML flow mode, YAML block mode, anchors/aliases/merge keys, multi-document read/write | full YAML 1.2 compliance suite parity |

Delphi 37.0 Win32 and Win64 are the tested full-feature targets. FPC 3.2.2 on
Linux x86-64 is currently tested for Core, JSON, and YAML configuration input.
Its default mapper has no RTTI mapping capability and raises an explicit error;
the FPC smoke test also exercises a registered object-only mapper.
The other codecs have not been validated on FPC.
Byte-oriented text input is strict UTF-8, accepts one leading BOM, and rejects
malformed sequences and NUL. Text output is BOM-free UTF-8. Delphi `String`
overloads take Unicode text and reject unpaired UTF-16 surrogates when writing.
On the declared FPC Linux target, `String` overloads require UTF-8 text in the
process code page; stream/file overloads validate UTF-8 bytes explicitly.

## Common Parser Use

Applications can accept a `TTJAXYParser` and keep format-specific code at the
edge:

```pascal
procedure PrintName(Parser: TTJAXYParser);
begin
  Writeln(Parser.AsObject.FindValue('name', 'unnamed'));
end;

var
  Parser: TTJAXYParser;
begin
  Parser := TTOML.CreateFromFile('settings.toml');
  try
    PrintName(Parser);
  finally
    Parser.Free;
  end;
end;
```

Use the typed codec variable when you need codec-specific options such as
`TJSON.Extension`, `TXML.NamespaceMode`, `TYAML.Encoding`, or
`TAvro.ContainerCodec`.

## DOM

```pascal
var
  Doc: TJSON;
  Items: TTJAXYArray;
begin
  Doc := TJSON.CreateObjectRoot;
  try
    Doc.AsObject.Add('name', 'TJAXY');
    Items := Doc.AsObject.AddArray('formats');
    Items.Add('json');
    Items.Add('yaml');
    Items.Add('xml');
    Writeln(Doc.WriteToString(tjaxywmReadable));
  finally
    Doc.Free;
  end;
end;
```

Core objects also provide generic lookup helpers for application code:

```pascal
Name := Doc.AsObject.GetValue('name', 'unnamed');      // current object only
Title := Doc.AsObject.FindValue('book.title', '');     // dotted path lookup
Format := Doc.AsObject.FindValue('formats[0]', '');    // array index lookup
First := Doc.AsObject.FindValue('formats[]', '');      // first array match
AnyID := Doc.AsObject.FindValue('id', '');             // recursive lookup
```

`GetValue` checks only the current object level. Direct keys win, then an
attribute bucket named `@` is used as a fallback, and an empty key returns
`#text` when present. `FindNode` returns the matching node. `FindValue` uses the
same value rules but can recurse by name or follow a dotted path with array
selectors such as `[0]`, `[]`, and `[*]`.

## Templates

Templates live in `TJAXY.Core`, so every codec can use the same template
registry and generated document tree.

```pascal
TTJAXY.CreateTemplate('pod')
  .Add('template', tjaxyttName)
  .Add('kind', tjaxytString)
  .Add('enabled', tjaxytBoolean);

Doc := TTJAXY.Template('pod').Fill(['Pod', True]);
```

## RTTI

Object and record mapping also belongs to the core DOM.

```pascal
JSON := TJSON.CreateFromObject(Config);
JSON.AssignToObject(TargetConfig);

JSON := TJSON.CreateFromRecord<TConfigRecord>(ConfigRecord);
JSON.AssignToRecord<TConfigRecord>(TargetRecord);
```

Serializer enum rules are shared:

```pascal
Rules := TTJAXYDocument.DefaultSerializerRules;
Rules.EnumMode := tjaxjemName;
Rules.EnumNameCase := tjaxyncLower;
Rules.EnumStripPrefixes := ['ts'];
TTJAXYDocument.SerializerRules := Rules;
```

When deserializing a nested class into a nil reference, register a factory for
the declared class first with `TTJAXYDocument.RegisterObjectFactory`. Existing
non-nil objects are updated in place. A `null` value clears a class reference;
the mapper does not free the old application-owned object. Assignment stops at
the first conversion or setter error and earlier successful member writes
remain. Use `UnregisterObjectFactory` when the registration is no longer needed.
If a class setter raises, the mapper reads the property back: it frees a newly
created factory object when the setter did not store it and leaves a stored
object with the target. A setter whose getter also raises must manage that
uncertain ownership itself.

Sets of at most eight bytes retain the legacy numeric representation. Larger
sets use arrays of enum names so high bits can be round-tripped. For a policy
specific to one operation, call `JSON.LoadFromObject(Config, Rules)` or
`JSON.AssignToObject(TargetConfig, Rules)`. These calls snapshot the rules and
serialize concurrent mapper operations internally. The global
`SerializerRules` property remains the compatibility default. Records use
`TJSON.CreateFromRecordWithRules<T>(Value, Rules)` and
`JSON.AssignToRecord<T>(Target, Rules)` for the same override.
Arrays of class references are rejected during deserialization because Delphi
managed arrays do not own their referenced objects; callers can map those
members with an application mapper that defines construction and cleanup.
Fixed arrays reject excess input elements instead of truncating them.

`TTJAXYDocument.MapperCapabilities` reports whether the active mapper supports
objects, records, and factory registration. Delphi uses the RTTI mapper in
`TJAXY.Mapper.Delphi.inc`; its compiler-specific types stay inside the Core
implementation. FPC starts without a reflection mapper and raises for object
or record mapping until an application assigns an `ITJAXYObjectMapper` to
`TTJAXYDocument.Mapper`. A registered mapper can support a narrower set of
classes and reports that through `Capabilities`; unsupported operations must
raise. The FPC smoke test contains a complete object-only registration example.
The mapper interface takes ownership of nodes returned by `SerializeObject`
and `SerializeRecord`; `AssignObject` and `AssignRecord` borrow their source
nodes and target instances. Register a mapper before starting concurrent
mapping work, and do not replace it during an operation.

The default Delphi mapper accepts integer fields from integral numbers or
decimal strings and rejects overflow or fractions. Float fields accept numbers
or invariant-decimal strings; `Single`, `Comp`, and `Currency` reject range or
precision loss. Boolean fields accept booleans, integer zero/nonzero, or
`true`/`false` strings. Enum fields use the configured name/ordinal rules;
unknown values raise, choose the first value, or leave the member unchanged
according to `EnumUnknownRead`. In ignore mode, `AssignToObject` and
`AssignToRecord` overloads with an `out Diagnostics` array report ignored values
as `TTJAXYMappingDiagnostic` entries with member paths. String fields accept
scalar values; character fields require exactly one representable code unit.
Variants serialize as strings (or null) and deserialize from scalar or null
values. Unsupported RTTI kinds raise with a member path.

## YAML configuration profile

Use the configuration factories when loading untrusted configuration documents:

```pascal
var
  Options: TYAMLConfigurationOptions;
  Config: TYAML;
begin
  Options := TYAML.DefaultConfigurationOptions;
  Options.MaxInputBytes := 512 * 1024;
  Config := TYAML.FromConfigurationFile('settings.yaml', Options);
  try
    Writeln(Config.AsObject['name'].AsString);
  finally
    Config.Free;
  end;
end;
```

`FromConfigurationString` and `FromConfigurationStream` accept the same options;
the stream factory reads from the current position and supports non-seekable
streams. Convenience overloads use `MaxInputBytes = 256 * 1024`, `MaxDepth =
32`, and `MaxNodes = 10000`. The old literal `262144` is exactly 256 KiB: it
limits **raw input bytes**, including whitespace, comments, and any leading
UTF-8 BOM. It does not cap the number of Unicode characters or peak memory.
Limits must be positive; there is no unlimited profile setting. Ordinary
`TYAML.FromString` and `TYAML.FromFile` do not enable this profile.
The root is at depth 1. Each mapping key and value and each sequence element
is a child one level deeper. Keys, scalars, containers, and implicit nulls each
count as one node. `MaxInputBytes` must be less than `MaxInt` so the loader can
read one additional byte to detect overflow.

The profile accepts UTF-8 with one optional leading BOM and writes BOM-free
UTF-8. It rejects malformed UTF-8, NUL, multiple documents, duplicate keys,
complex keys, merge keys, anchors, aliases, tags, and directives. The profile
bounds input bytes and the parser's counted nodes and depth; it is not a peak
memory guarantee.

YAML nodes now use the Core DOM directly. `TYAMLValue`, `TYAMLObject`, and
related names are aliases for their `TTJAXY*` counterparts; both typed `TYAML`
and generic `TTJAXYParser` references observe the same edits. Code that
relied on the old distinct YAML class hierarchy or its exact exception types
may need updating.

## XML Mapping

XML maps into the shared object model with these reserved keys:

- `@`: attributes object
- `#text`: text content when an element also has attributes or child elements
- repeated child elements: array under the element name
- document root: top-level object key named after the root element

Namespace prefixes are preserved by default. Use `xnmStripPrefixes` when reading
to map prefixed names to local names and omit `xmlns` declarations:

```pascal
XML := TXML.CreateFromString('<h:root xmlns:h="urn:test"><h:item>value</h:item></h:root>', xnmStripPrefixes);
```

Example:

```xml
<catalog version="1">
  <item id="a">First</item>
  <item id="b"><name>Second</name></item>
</catalog>
```

Maps to:

```json
{
  "catalog": {
    "@": { "version": "1" },
    "item": [
      { "@": { "id": "a" }, "#text": "First" },
      { "@": { "id": "b" }, "name": "Second" }
    ]
  }
}
```

So application code can avoid hard-coding the reserved XML keys for common
reads:

```pascal
Catalog := XML.AsObject['catalog'].AsObject;
Version := Catalog.GetValue('version', '1');     // attribute fallback
FirstID := Catalog.FindValue('item[0].id', '');  // first item attribute
FirstText := Catalog.FindValue('item[0]', '');   // element text fallback
```

## Avro

Avro V1 support is schema-explicit and supports Avro JSON encoding, binary
encoding, single-object encoding, null/deflate object container files,
multi-block container reads, parsing canonical form, CRC-64-AVRO fingerprints,
named references, aliases metadata, basic reader/writer schema resolution, and
date/time/uuid/decimal logical values. Snappy/zstandard codecs, arbitrary-
precision decimal, and the full reader/writer schema resolution matrix are
planned as later layers.

```pascal
const
  Schema =
    '{"type":"record","name":"Message","fields":[' +
    '{"name":"id","type":"long"},' +
    '{"name":"title","type":"string"},' +
    '{"name":"note","type":["null","string"],"default":null}' +
    ']}';

  Value =
    '{"id":7,"title":"hello","note":{"string":"optional"}}';

var
  Avro: TAvro;
begin
  Avro := TAvro.CreateFromString(Value, Schema);
  try
    Writeln(Avro.Root.AsObject['title'].AsString);
    Writeln(Avro.WriteToString(tjaxywmCondensed));
  finally
    Avro.Free;
  end;
end;
```

Avro unions use the Avro JSON wrapper on input/output, but the TJAXY DOM remains
plain. For the example above, `note` is available as a normal string in
`Root.AsObject['note']`.

Schemas are parsed through `TJAXY.JSON`; use `TAvro.CreateFromSchemaJSON` when
the application already has a parsed `TJSON` schema document. Named schema
references are resolved for records, enums, and fixed definitions that have
already appeared in the schema.

Use `WriteToBinaryBytes` / `LoadFromBinaryBytes` for raw Avro binary payloads,
`WriteSingleObjectBytes` / `LoadSingleObjectBytes` for single-object encoding,
and `SaveContainerToStream` / `LoadContainerFromStream` for object container
files. Set `ContainerCodec := 'deflate'` for deflated containers; the default is
`'null'`. Deflate containers now use raw RFC 1951 streams as Avro requires.
Older TJAXY files written with a zlib wrapper are not accepted by the strict
reader and should be regenerated or converted before upgrading.
Container readers limit the total number of records to 1,000,000 by default,
including records whose schema consumes zero bytes. Set
`MaxContainerRecords` on the reader before loading to choose a lower limit.

## TOML

TOML support covers practical configuration documents: root keys, dotted keys,
tables, arrays, arrays of tables, inline tables, strings, numbers, special
floats, booleans, shared `TTJAXYDateTime` date/time values, and comments.

```pascal
TOML := TTOML.CreateFromString(
  'name = "TJAXY"' + sLineBreak +
  'enabled = true' + sLineBreak +
  '[database]' + sLineBreak +
  'server = "db.local"');
try
  Writeln(TOML.Root.AsObject['database'].AsObject['server'].AsString);
finally
  TOML.Free;
end;
```

## Building Tests

```bash
./run-tests-wsl.sh

# or build/run individual programs:
./build-wsl-generic.sh Source/TJAXY.dpk Win64
./build-wsl-generic.sh Tests/TJSON.TestRunner.dpr Win64
./build-wsl-generic.sh Tests/YAMLNativeTests.dpr Win64
./build-wsl-generic.sh Tests/TJAXY.XML.Smoke.dpr Win64
./build-wsl-generic.sh Tests/TJAXY.XML.Conformance.dpr Win64
./build-wsl-generic.sh Tests/TJAXY.Avro.Smoke.dpr Win64
./build-wsl-generic.sh Tests/TJAXY.TOML.Smoke.dpr Win64
```

The XML conformance runner is built by `run-tests-wsl.sh`, but the W3C XML
Conformance Test Suite is not bundled in this repository. Download it from:

```text
https://www.w3.org/XML/Test/xmlts20130923.zip
```

Extract the archive so the manifest is available at `Tests/xmlconf/xmlconf.xml`.
When that directory exists, `run-tests-wsl.sh` runs the supported
non-validating standalone well-formedness slice, including declaration-only
internal DOCTYPE valid cases. DTD validation/entity expansion, external entity,
not-standalone, non-UTF-8 and non-BMP/name-range cases are reported as skipped:

```bash
./Bin/Win64/TJAXY.XML.Conformance.exe Tests/xmlconf --quiet
```

## License

TJAXY is licensed under the BSD 2-Clause License. See `LICENSE`.
