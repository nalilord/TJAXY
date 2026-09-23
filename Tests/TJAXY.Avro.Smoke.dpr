program TJAXYAvroSmoke;

{$APPTYPE CONSOLE}

uses
  System.Classes,
  System.SysUtils,
  TJAXY.Core,
  TJAXY.JSON,
  TJAXY.Avro;

const
  TEST_SCHEMA =
    '{' +
    '  "type": "record",' +
    '  "name": "Message",' +
    '  "fields": [' +
    '    {"name": "id", "type": "long"},' +
    '    {"name": "title", "type": "string"},' +
    '    {"name": "active", "type": "boolean"},' +
    '    {"name": "score", "type": "double"},' +
    '    {"name": "status", "type": {"type": "enum", "name": "Status", "symbols": ["NEW", "DONE"]}},' +
    '    {"name": "tags", "type": {"type": "array", "items": "string"}},' +
    '    {"name": "props", "type": {"type": "map", "values": "string"}},' +
    '    {"name": "note", "type": ["null", "string"], "default": null}' +
    '  ]' +
    '}';

  TEST_VALUE =
    '{' +
    '  "id": 7,' +
    '  "title": "hello",' +
    '  "active": true,' +
    '  "score": 3.5,' +
    '  "status": "DONE",' +
    '  "tags": ["json", "avro"],' +
    '  "props": {"kind": "demo"},' +
    '  "note": {"string": "optional"}' +
    '}';

procedure Expect(ACondition: Boolean; const AMessage: String);
begin
  if ACondition then
    Writeln('[PASS] ', AMessage)
  else
    raise Exception.Create(AMessage);
end;

procedure ExpectFails(const AValueJSON, AMessage: String);
var
  Avro: TAvro;
begin
  Avro:=TAvro.CreateFromSchemaString(TEST_SCHEMA);
  try
    try
      Avro.LoadFromString(AValueJSON);
      raise Exception.Create(AMessage + ': expected Avro validation failure');
    except
      on E: EAvroException do
        Writeln('[PASS] ', AMessage);
    end;
  finally
    Avro.Free;
  end;
end;

procedure ExpectSchemaFails(const ASchemaJSON, AMessage: String);
var
  Schema: TAvroSchema;
begin
  Schema:=nil;
  try
    try
      Schema:=TAvroSchema.FromString(ASchemaJSON);
      raise Exception.Create(AMessage + ': expected Avro schema failure');
    except
      on E: EAvroException do
        Writeln('[PASS] ', AMessage);
    end;
  finally
    Schema.Free;
  end;
end;

function BuildContainerBlock(const ASchema: String; ARecordCount, ADeclaredSize: Int64;
  const APayload: TBytes): TMemoryStream;
var
  Sync, SchemaBytes, KeyBytes: TBytes;
  I: Integer;

  procedure WriteLong(AValue: Int64);
  var
    N: UInt64;
    B: Byte;
  begin
    N:=UInt64((AValue shl 1) xor (AValue shr 63));
    while (N AND not UInt64($7F)) <> 0 do
    begin
      B:=Byte((N AND $7F) OR $80);
      Result.WriteBuffer(B, 1);
      N:=N shr 7;
    end;
    B:=Byte(N);
    Result.WriteBuffer(B, 1);
  end;

begin
  Result:=TMemoryStream.Create;
  try
    SchemaBytes:=TEncoding.UTF8.GetBytes(ASchema);
    KeyBytes:=TEncoding.UTF8.GetBytes('avro.schema');
    SetLength(Sync, 16);
    for I:=0 to High(Sync) do
      Sync[I]:=I;
    Result.WriteBuffer(TBytes.Create(Ord('O'), Ord('b'), Ord('j'), 1)[0], 4);
    WriteLong(1);
    WriteLong(Length(KeyBytes));
    Result.WriteBuffer(KeyBytes[0], Length(KeyBytes));
    WriteLong(Length(SchemaBytes));
    Result.WriteBuffer(SchemaBytes[0], Length(SchemaBytes));
    WriteLong(0);
    Result.WriteBuffer(Sync[0], Length(Sync));
    WriteLong(ARecordCount);
    WriteLong(ADeclaredSize);
    if Length(APayload) > 0 then
      Result.WriteBuffer(APayload[0], Length(APayload));
    Result.WriteBuffer(Sync[0], Length(Sync));
    Result.Position:=0;
  except
    Result.Free;
    raise;
  end;
end;

procedure TestMalformedContainerBlocks;
var
  Target: TAvro;
  Stream: TMemoryStream;
  I: Integer;

  procedure ExpectBlockFails(ARecordCount, ADeclaredSize: Int64;
    const APayload: TBytes; const AName: String);
  begin
    Stream:=BuildContainerBlock('"null"', ARecordCount, ADeclaredSize, APayload);
    Target:=TAvro.Create;
    try
      try
        Target.LoadContainerFromStream(Stream);
        raise Exception.Create(AName + ': expected Avro validation failure');
      except
        on E: EAvroException do Writeln('[PASS] ', AName);
      end;
    finally
      Target.Free;
      Stream.Free;
    end;
  end;

begin
  Stream:=BuildContainerBlock('"null"', 3, 0, nil);
  Target:=TAvro.Create;
  try
    Target.LoadContainerFromStream(Stream);
    Expect(Target.Root.IsArray AND (Target.Root.AsArray.Count = 3),
      'three zero-byte null records follow declared count');
    for I:=0 to 2 do
      Expect(Target.Root.AsArray[I].IsNull, 'zero-byte null record ' + IntToStr(I));
  finally
    Target.Free;
    Stream.Free;
  end;
  Stream:=BuildContainerBlock('"null"', 3, 0, nil);
  Target:=TAvro.Create;
  try
    Target.MaxContainerRecords:=2;
    try
      Target.LoadContainerFromStream(Stream);
      raise Exception.Create('configured container record limit should fail');
    except
      on E: EAvroException do Writeln('[PASS] configured container record limit rejected');
    end;
  finally
    Target.Free;
    Stream.Free;
  end;
  ExpectBlockFails(0, 0, nil, 'zero container block count rejected');
  ExpectBlockFails(1000001, 0, nil, 'container record count bound rejects zero-byte amplification');
  ExpectBlockFails(2, 1, TBytes.Create(42), 'zero-byte record block rejects excess payload');
  ExpectBlockFails(1, 1, nil, 'truncated container block rejected');
  ExpectBlockFails(1, -1, nil, 'negative container block size rejected');
end;

procedure TestRead;
var
  Avro: TAvro;
begin
  Avro:=TAvro.CreateFromString(TEST_VALUE, TEST_SCHEMA);
  try
    Expect(Avro.Root.AsObject['id'].AsInteger = 7, 'record long field');
    Expect(Avro.Root.AsObject['title'].AsString = 'hello', 'record string field');
    Expect(Avro.Root.AsObject['active'].AsBoolean, 'record boolean field');
    Expect(Avro.Root.AsObject['status'].AsString = 'DONE', 'enum field');
    Expect(Avro.Root.AsObject['tags'].AsArray.Count = 2, 'array field');
    Expect(Avro.Root.AsObject['props'].AsObject['kind'].AsString = 'demo', 'map field');
    Expect(Avro.Root.AsObject['note'].AsString = 'optional', 'union field unwraps into plain DOM');
  finally
    Avro.Free;
  end;
end;

procedure TestWrite;
var
  Avro: TAvro;
  Text: String;
begin
  Avro:=TAvro.CreateFromString(TEST_VALUE, TEST_SCHEMA);
  try
    Text:=Avro.WriteToString(tjaxywmCondensed);
    Expect(Pos('"id":7', Text) > 0, 'writer emits record field');
    Expect(Pos('"status":"DONE"', Text) > 0, 'writer emits enum symbol');
    Expect(Pos('"note":{"string":"optional"}', Text) > 0, 'writer emits Avro JSON union wrapper');
  finally
    Avro.Free;
  end;
end;

procedure TestDefaultsAndNullUnion;
var
  Avro: TAvro;
begin
  Avro:=TAvro.CreateFromString(
    '{"id": 8, "title": "default", "active": false, "score": 1.25, "status": "NEW", "tags": [], "props": {}}',
    TEST_SCHEMA);
  try
    Expect(Avro.Root.AsObject['note'].IsNull, 'missing field uses default null');
    Expect(Pos('"note":null', Avro.WriteToString(tjaxywmCondensed)) > 0, 'writer emits null union branch');
  finally
    Avro.Free;
  end;
end;

procedure TestParserReference;
var
  Parser: TTJAXYParser;
begin
  Parser:=TAvro.CreateFromString(TEST_VALUE, TEST_SCHEMA);
  try
    Expect(Parser.Root.AsObject['title'].AsString = 'hello', 'Avro works through TTJAXYParser reference');
  finally
    Parser.Free;
  end;
end;

procedure TestSchemaJSONAndNamedReferences;
const
  SchemaText =
    '{' +
    '  "type": "record",' +
    '  "name": "Tree",' +
    '  "namespace": "demo",' +
    '  "fields": [' +
    '    {"name": "root", "type": {"type": "record", "name": "Node", "fields": [' +
    '      {"name": "name", "type": "string"}' +
    '    ]}},' +
    '    {"name": "children", "type": {"type": "array", "items": "Node"}}' +
    '  ]' +
    '}';
  ValueText =
    '{' +
    '  "root": {"name": "top"},' +
    '  "children": [{"name": "left"}, {"name": "right"}]' +
    '}';
var
  SchemaJSON: TJSON;
  Avro: TAvro;
begin
  SchemaJSON:=TJSON.CreateFromString(SchemaText);
  try
    Avro:=TAvro.CreateFromSchemaJSON(SchemaJSON);
    try
      Avro.LoadFromString(ValueText);
      Expect(Avro.Root.AsObject['root'].AsObject['name'].AsString = 'top', 'schema can be supplied as TJSON');
      Expect(Avro.Root.AsObject['children'].AsArray[1].AsObject['name'].AsString = 'right', 'named schema reference resolves');
    finally
      Avro.Free;
    end;
  finally
    SchemaJSON.Free;
  end;
end;

procedure TestLogicalTypes;
const
  SchemaText =
    '{"type":"record","name":"Event","fields":[' +
    '{"name":"day","type":{"type":"int","logicalType":"date"}},' +
    '{"name":"clock","type":{"type":"int","logicalType":"time-millis"}},' +
    '{"name":"clock_us","type":{"type":"long","logicalType":"time-micros"}},' +
    '{"name":"seen","type":{"type":"long","logicalType":"timestamp-millis"}},' +
    '{"name":"seen_us","type":{"type":"long","logicalType":"timestamp-micros"}},' +
    '{"name":"local_seen","type":{"type":"long","logicalType":"local-timestamp-millis"}}' +
    ']}';
var
  Avro: TAvro;
  Text: String;
begin
  Avro:=TAvro.CreateFromString('{"day":1,"clock":3723004,"clock_us":3723004005,"seen":1000,"seen_us":1000005,"local_seen":1000}', SchemaText);
  try
    Expect(Avro.Root.AsObject['day'] IS TTJAXYDateTime, 'logical date maps to temporal value');
    Expect(Avro.Root.AsObject['day'].AsString = '1970-01-02', 'logical date value');
    Expect(Avro.Root.AsObject['clock'].AsString = '01:02:03.004', 'logical time-millis value');
    Expect(Avro.Root.AsObject['clock_us'].AsString = '01:02:03.004005', 'logical time-micros value');
    Expect(Avro.Root.AsObject['seen_us'].AsString = '1970-01-01T00:00:01.000005Z', 'logical timestamp-micros value');
    Text:=Avro.WriteToString(tjaxywmCondensed);
    Expect(Pos('"day":1', Text) > 0, 'logical date writes underlying value');
    Expect(Pos('"clock":3723004', Text) > 0, 'logical time writes underlying value');
    Expect(Pos('"clock_us":3723004005', Text) > 0, 'logical time micros writes underlying value');
  finally
    Avro.Free;
  end;
end;

procedure TestUUIDAndDecimal;
const
  SchemaText =
    '{"type":"record","name":"Invoice","fields":[' +
    '{"name":"id","type":{"type":"string","logicalType":"uuid"}},' +
    '{"name":"price","type":{"type":"bytes","logicalType":"decimal","precision":9,"scale":2}}' +
    ']}';
var
  Source, Target: TAvro;
  Root: TTJAXYObject;
  Bytes: TBytes;
begin
  Source:=TAvro.CreateFromSchemaString(SchemaText);
  try
    Root:=Source.RootNewObject;
    Root.Add('id', '123e4567-e89b-12d3-a456-426614174000');
    Root.Add('price', '12.34');
    Bytes:=Source.WriteToBinaryBytes;
    Target:=TAvro.CreateFromSchemaString(SchemaText);
    try
      Target.LoadFromBinaryBytes(Bytes);
      Expect(Target.Root.AsObject['id'].AsString = '123e4567-e89b-12d3-a456-426614174000', 'uuid logical value round-trips');
      Expect(Target.Root.AsObject['price'].AsString = '12.34', 'decimal logical value round-trips');
    finally
      Target.Free;
    end;
  finally
    Source.Free;
  end;
end;

procedure TestAliases;
var
  Schema: TAvroSchema;
begin
  Schema:=TAvroSchema.FromString('{"type":"record","name":"Thing","namespace":"demo","aliases":["OldThing"],"fields":[]}');
  try
    Expect(Schema.Aliases.Count = 1, 'schema aliases captured');
    Expect(Schema.Aliases[0] = 'demo.OldThing', 'relative alias is namespace-qualified');
  finally
    Schema.Free;
  end;
end;

procedure TestCanonicalAndFingerprint;
var
  SchemaA, SchemaB: TAvroSchema;
begin
  SchemaA:=TAvroSchema.FromString(TEST_SCHEMA);
  SchemaB:=TAvroSchema.FromString(TEST_SCHEMA);
  try
    Expect(Pos('"type":"record"', SchemaA.ParsingCanonicalForm) > 0, 'schema parsing canonical form');
    Expect(SchemaA.Fingerprint64 = SchemaB.Fingerprint64, 'schema fingerprint is stable');
    Expect(SchemaA.Fingerprint64 <> 0, 'schema fingerprint is non-zero');
  finally
    SchemaB.Free;
    SchemaA.Free;
  end;
end;

procedure TestBinaryRoundTrip;
var
  Source, Target: TAvro;
  Bytes: TBytes;
begin
  Source:=TAvro.CreateFromString(TEST_VALUE, TEST_SCHEMA);
  try
    Bytes:=Source.WriteToBinaryBytes;
    Expect(Length(Bytes) > 0, 'binary encoder emits bytes');
    Target:=TAvro.CreateFromSchemaString(TEST_SCHEMA);
    try
      Target.LoadFromBinaryBytes(Bytes);
      Expect(Target.Root.AsObject['title'].AsString = 'hello', 'binary decoder record string');
      Expect(Target.Root.AsObject['note'].AsString = 'optional', 'binary decoder union value');
    finally
      Target.Free;
    end;
  finally
    Source.Free;
  end;
end;

procedure TestMalformedLongEncoding;
var
  Target: TAvro;
  Payload: TBytes;
  I: Integer;
begin
  Target:=TAvro.CreateFromSchemaString('"long"');
  try
    SetLength(Payload, 10);
    for I:=0 to 8 do
      Payload[I]:=$80;
    Payload[9]:=$02;
    try
      Target.LoadFromBinaryBytes(Payload);
      raise Exception.Create('malformed Avro long fails: expected validation error');
    except
      on E: EAvroException do
        Writeln('[PASS] malformed Avro long fails');
    end;
    Payload[9]:=$80;
    try
      Target.LoadFromBinaryBytes(Payload);
      raise Exception.Create('unterminated Avro long fails: expected validation error');
    except
      on E: EAvroException do
        Writeln('[PASS] unterminated Avro long fails');
    end;
  finally
    Target.Free;
  end;
end;

procedure TestSingleObjectRoundTrip;
var
  Source, Target: TAvro;
  Bytes: TBytes;
begin
  Source:=TAvro.CreateFromString(TEST_VALUE, TEST_SCHEMA);
  try
    Bytes:=Source.WriteSingleObjectBytes;
    Expect((Length(Bytes) > 10) AND (Bytes[0] = $C3) AND (Bytes[1] = $01), 'single-object encoder emits marker');
    Target:=TAvro.CreateFromSchemaString(TEST_SCHEMA);
    try
      Target.LoadSingleObjectBytes(Bytes);
      Expect(Target.Root.AsObject['title'].AsString = 'hello', 'single-object decoder record string');
    finally
      Target.Free;
    end;
  finally
    Source.Free;
  end;
end;

procedure TestContainerRoundTrip;
var
  Source, Target: TAvro;
  Stream: TMemoryStream;
begin
  Source:=TAvro.CreateFromString(TEST_VALUE, TEST_SCHEMA);
  Stream:=TMemoryStream.Create;
  try
    Source.SaveContainerToStream(Stream);
    Expect(Stream.Size > 4, 'container writer emits object container');
    Stream.Position:=0;
    Target:=TAvro.Create;
    try
      Target.LoadContainerFromStream(Stream);
      Expect(Target.Root.AsObject['title'].AsString = 'hello', 'container reader record string');
    finally
      Target.Free;
    end;
  finally
    Stream.Free;
    Source.Free;
  end;
end;

procedure TestDeflateContainerRoundTrip;
var
  Source, Target: TAvro;
  Stream: TMemoryStream;
begin
  Source:=TAvro.CreateFromString(TEST_VALUE, TEST_SCHEMA);
  Source.ContainerCodec:='deflate';
  Stream:=TMemoryStream.Create;
  try
    Source.SaveContainerToStream(Stream);
    Expect(Stream.Size > 4, 'deflate container writer emits object container');
    Stream.Position:=0;
    Target:=TAvro.Create;
    try
      Target.LoadContainerFromStream(Stream);
      Expect(Target.Root.AsObject['title'].AsString = 'hello', 'deflate container reader record string');
    finally
      Target.Free;
    end;
  finally
    Stream.Free;
    Source.Free;
  end;
end;

procedure TestZeroByteContainerRecord;
var
  Source, Target: TAvro;
  Stream: TMemoryStream;
begin
  Source:=TAvro.CreateFromString('null', '"null"');
  Stream:=TMemoryStream.Create;
  try
    Source.SaveContainerToStream(Stream);
    Stream.Position:=0;
    Target:=TAvro.Create;
    try
      Target.LoadContainerFromStream(Stream);
      Expect(Target.Root.IsNull, 'null container record consumes zero bytes');
    finally
      Target.Free;
    end;
  finally
    Stream.Free;
    Source.Free;
  end;
end;

procedure TestContainerMultiBlockRead;
var
  First, Second, Target: TAvro;
  B1, B2, Sync, SchemaBytes, CodecBytes: TBytes;
  Stream: TMemoryStream;
  I: Integer;

  procedure WriteLong(AValue: Int64);
  var
    N: UInt64;
    B: Byte;
  begin
    N:=UInt64((AValue shl 1) xor (AValue shr 63));
    while (N AND not UInt64($7F)) <> 0 do
    begin
      B:=Byte((N AND $7F) OR $80);
      Stream.WriteBuffer(B, SizeOf(B));
      N:=N shr 7;
    end;
    B:=Byte(N);
    Stream.WriteBuffer(B, SizeOf(B));
  end;

  procedure WriteMeta(const AKey: String; const AValue: TBytes);
  var
    KeyBytes: TBytes;
  begin
    KeyBytes:=TEncoding.UTF8.GetBytes(AKey);
    WriteLong(Length(KeyBytes));
    if Length(KeyBytes) > 0 then
      Stream.WriteBuffer(KeyBytes[0], Length(KeyBytes));
    WriteLong(Length(AValue));
    if Length(AValue) > 0 then
      Stream.WriteBuffer(AValue[0], Length(AValue));
  end;

  procedure WriteBlock(const ABytes: TBytes);
  begin
    WriteLong(1);
    WriteLong(Length(ABytes));
    Stream.WriteBuffer(ABytes[0], Length(ABytes));
    Stream.WriteBuffer(Sync[0], Length(Sync));
  end;

begin
  First:=TAvro.CreateFromString(TEST_VALUE, TEST_SCHEMA);
  Second:=TAvro.CreateFromString(
    '{"id": 9, "title": "second", "active": false, "score": 1.5, "status": "NEW", "tags": [], "props": {}, "note": null}',
    TEST_SCHEMA);
  Stream:=TMemoryStream.Create;
  try
    B1:=First.WriteToBinaryBytes;
    B2:=Second.WriteToBinaryBytes;
    SetLength(Sync, 16);
    for I:=0 to High(Sync) do
      Sync[I]:=I + 1;
    SchemaBytes:=TEncoding.UTF8.GetBytes(TEST_SCHEMA);
    CodecBytes:=TEncoding.UTF8.GetBytes('null');

    Stream.WriteBuffer(TBytes.Create(Ord('O'), Ord('b'), Ord('j'), 1)[0], 4);
    WriteLong(2);
    WriteMeta('avro.schema', SchemaBytes);
    WriteMeta('avro.codec', CodecBytes);
    WriteLong(0);
    Stream.WriteBuffer(Sync[0], Length(Sync));
    WriteBlock(B1);
    WriteBlock(B2);
    Stream.Position:=0;

    Target:=TAvro.Create;
    try
      Target.LoadContainerFromStream(Stream);
      Expect(Target.Root.IsArray, 'multi-block container reads as array root');
      Expect(Target.Root.AsArray.Count = 2, 'multi-block container item count');
      Expect(Target.Root.AsArray[1].AsObject['title'].AsString = 'second', 'multi-block container second item');
    finally
      Target.Free;
    end;
  finally
    Stream.Free;
    Second.Free;
    First.Free;
  end;
end;

procedure TestContainerInvalidBlockCount;
var
  Source, Target: TAvro;
  Payload, Sync, SchemaBytes, CodecBytes: TBytes;
  Stream: TMemoryStream;
  I: Integer;

  procedure WriteLong(AValue: Int64);
  var
    N: UInt64;
    B: Byte;
  begin
    N:=UInt64((AValue shl 1) xor (AValue shr 63));
    while (N AND not UInt64($7F)) <> 0 do
    begin
      B:=Byte((N AND $7F) OR $80);
      Stream.WriteBuffer(B, SizeOf(B));
      N:=N shr 7;
    end;
    B:=Byte(N);
    Stream.WriteBuffer(B, SizeOf(B));
  end;

  procedure WriteMeta(const AKey: String; const AValue: TBytes);
  var
    KeyBytes: TBytes;
  begin
    KeyBytes:=TEncoding.UTF8.GetBytes(AKey);
    WriteLong(Length(KeyBytes));
    if Length(KeyBytes) > 0 then
      Stream.WriteBuffer(KeyBytes[0], Length(KeyBytes));
    WriteLong(Length(AValue));
    if Length(AValue) > 0 then
      Stream.WriteBuffer(AValue[0], Length(AValue));
  end;

begin
  Source:=TAvro.CreateFromString(TEST_VALUE, TEST_SCHEMA);
  Stream:=TMemoryStream.Create;
  try
    Payload:=Source.WriteToBinaryBytes;
    SetLength(Sync, 16);
    for I:=0 to High(Sync) do
      Sync[I]:=I + 17;
    SchemaBytes:=TEncoding.UTF8.GetBytes(TEST_SCHEMA);
    CodecBytes:=TEncoding.UTF8.GetBytes('null');

    Stream.WriteBuffer(TBytes.Create(Ord('O'), Ord('b'), Ord('j'), 1)[0], 4);
    WriteLong(2);
    WriteMeta('avro.schema', SchemaBytes);
    WriteMeta('avro.codec', CodecBytes);
    WriteLong(0);
    Stream.WriteBuffer(Sync[0], Length(Sync));
    WriteLong(2);
    WriteLong(Length(Payload));
    Stream.WriteBuffer(Payload[0], Length(Payload));
    Stream.WriteBuffer(Sync[0], Length(Sync));
    Stream.Position:=0;

    Target:=TAvro.Create;
    try
      try
        Target.LoadContainerFromStream(Stream);
        raise Exception.Create('invalid container block count fails: expected Avro validation failure');
      except
        on E: EAvroException do
          Writeln('[PASS] invalid container block count fails');
      end;
    finally
      Target.Free;
    end;
  finally
    Stream.Free;
    Source.Free;
  end;
end;

procedure TestReaderWriterResolution;
const
  WriterSchemaText =
    '{"type":"record","name":"Compat","fields":[' +
    '{"name":"old_name","type":"int"},' +
    '{"name":"count","type":"int"}' +
    ']}';
  ReaderSchemaText =
    '{"type":"record","name":"Compat","fields":[' +
    '{"name":"new_name","type":"int","aliases":["old_name"]},' +
    '{"name":"count","type":"long"},' +
    '{"name":"extra","type":"string","default":"fallback"}' +
    ']}';
var
  Writer, Reader: TAvro;
  WriterSchema: TAvroSchema;
  Root: TTJAXYObject;
  Bytes: TBytes;
begin
  Writer:=TAvro.CreateFromSchemaString(WriterSchemaText);
  WriterSchema:=TAvroSchema.FromString(WriterSchemaText);
  try
    Root:=Writer.RootNewObject;
    Root.Add('old_name', Int64(7));
    Root.Add('count', Int64(8));
    Bytes:=Writer.WriteToBinaryBytes;
    Reader:=TAvro.CreateFromSchemaString(ReaderSchemaText);
    try
      Reader.LoadFromBinaryBytes(Bytes, WriterSchema);
      Expect(Reader.Root.AsObject['new_name'].AsInteger = 7, 'reader field alias resolves writer field');
      Expect(Reader.Root.AsObject['count'].AsInteger = 8, 'reader schema promotes int to long');
      Expect(Reader.Root.AsObject['extra'].AsString = 'fallback', 'reader default fills missing field');
    finally
      Reader.Free;
    end;
  finally
    WriterSchema.Free;
    Writer.Free;
  end;
end;

procedure TestFailures;
begin
  ExpectFails('{"title":"missing"}', 'missing required field fails');
  ExpectFails(
    '{"id":"wrong","title":"hello","active":true,"score":3.5,"status":"DONE","tags":[],"props":{},"note":null}',
    'wrong primitive type fails');
  ExpectFails(
    '{"id":7,"title":"hello","active":true,"score":3.5,"status":"BAD","tags":[],"props":{},"note":null}',
    'invalid enum symbol fails');
  ExpectFails(
    '{"id":7,"title":"hello","active":true,"score":3.5,"status":"DONE","tags":[],"props":{},"note":"optional"}',
    'invalid union shape fails');
  ExpectSchemaFails('{"type":"record","name":"Bad","fields":[{"name":"x","type":"int"},{"name":"x","type":"int"}]}', 'duplicate field name fails');
  ExpectSchemaFails('{"type":"enum","name":"BadEnum","symbols":["A","A"]}', 'duplicate enum symbol fails');
  ExpectSchemaFails('{"type":"array"}', 'missing array items fails');
  ExpectSchemaFails('{"type":"fixed","name":"BadFixed","size":0}', 'invalid fixed size fails');
end;

begin
  try
    TestRead;
    TestWrite;
    TestDefaultsAndNullUnion;
    TestParserReference;
    TestSchemaJSONAndNamedReferences;
    TestLogicalTypes;
    TestUUIDAndDecimal;
    TestAliases;
    TestCanonicalAndFingerprint;
    TestBinaryRoundTrip;
    TestMalformedLongEncoding;
    TestSingleObjectRoundTrip;
    TestContainerRoundTrip;
    TestDeflateContainerRoundTrip;
    TestZeroByteContainerRecord;
    TestMalformedContainerBlocks;
    TestContainerMultiBlockRead;
    TestContainerInvalidBlockCount;
    TestReaderWriterResolution;
    TestFailures;
  except
    on E: Exception do
    begin
      Writeln('[FAIL] ', E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
end.
