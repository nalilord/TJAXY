program TJAXYCrossFormat;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  TJAXY.Core,
  TJAXY.Avro,
  TJAXY.JSON,
  TJAXY.TOML,
  TJAXY.YAML,
  TJAXY.XML;

type
  TShortReadStream = class(TStream)
  private
    FBytes: TBytes;
    FPosition: Integer;
  public
    constructor Create(const ABytes: TBytes);
    function Read(var Buffer; Count: Longint): Longint; override;
    function Write(const Buffer; Count: Longint): Longint; override;
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;
  end;

constructor TShortReadStream.Create(const ABytes: TBytes);
begin
  inherited Create;
  FBytes:=ABytes;
end;

function TShortReadStream.Read(var Buffer; Count: Longint): Longint;
begin
  Result:=Length(FBytes) - FPosition;
  if Result > Count then Result:=Count;
  if Result > 2 then Result:=2;
  if Result > 0 then
  begin
    Move(FBytes[FPosition], Buffer, Result);
    Inc(FPosition, Result);
  end;
end;

function TShortReadStream.Write(const Buffer; Count: Longint): Longint;
begin
  raise Exception.Create('Read-only test stream');
end;

function TShortReadStream.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
begin
  raise Exception.Create('Non-seekable test stream');
end;

procedure Expect(ACondition: Boolean; const AMessage: String);
begin
  if ACondition then
    Writeln('[PASS] ', AMessage)
  else
    raise Exception.Create(AMessage);
end;

procedure ExpectUTF8Bytes(AParser: TTJAXYParser; const AName: String);
var
  Stream, Input: TMemoryStream;
  ShortInput: TShortReadStream;
  Expected, Actual: TBytes;
  I: Integer;
  TextBefore: String;
  FileName, WrittenText: String;
  Prefix: array[0..2] of Byte;
begin
  Stream:=TMemoryStream.Create;
  try
    TextBefore:=AParser.WriteToString;
    AParser.SaveToStream(Stream);
    Expected:=TEncoding.UTF8.GetBytes(TextBefore);
    Expect(Stream.Size = Length(Expected), AName + ' UTF-8 byte count');
    SetLength(Actual, Stream.Size);
    Stream.Position:=0;
    if Stream.Size > 0 then
      Stream.ReadBuffer(Actual[0], Stream.Size);
    for I:=0 to High(Expected) do
      if Actual[I] <> Expected[I] then
        raise Exception.Create(AName + ' UTF-8 byte mismatch at ' + IntToStr(I));
    Expect(True, AName + ' emits exact UTF-8 bytes');
    FileName:=TPath.GetTempFileName;
    try
      AParser.SaveToFile(FileName);
      Actual:=TFile.ReadAllBytes(FileName);
      Expect(Length(Actual) = Length(Expected), AName + ' SaveToFile byte count');
      for I:=0 to High(Expected) do
        if Actual[I] <> Expected[I] then
          raise Exception.Create(AName + ' SaveToFile UTF-8 mismatch at ' + IntToStr(I));
      AParser.LoadFromFile(FileName);
      Expect(AParser.WriteToString = TextBefore, AName + ' LoadFromFile preserves Unicode');
      WrittenText:=AParser.WriteToFile(FileName);
      Actual:=TFile.ReadAllBytes(FileName);
      Expected:=TEncoding.UTF8.GetBytes(WrittenText);
      Expect(Length(Actual) = Length(Expected), AName + ' WriteToFile byte count');
      for I:=0 to High(Expected) do
        if Actual[I] <> Expected[I] then
          raise Exception.Create(AName + ' WriteToFile UTF-8 mismatch at ' + IntToStr(I));
      Expect(True, AName + ' file overloads emit UTF-8');
    finally
      TFile.Delete(FileName);
    end;
    Actual:=TEncoding.UTF8.GetBytes(TextBefore);
    Input:=TMemoryStream.Create;
    try
      Prefix[0]:=Ord('x'); Prefix[1]:=Ord('y'); Prefix[2]:=Ord('z');
      Input.WriteBuffer(Prefix, Length(Prefix));
      if Length(Actual) > 0 then
        Input.WriteBuffer(Actual[0], Length(Actual));
      Input.Position:=Length(Prefix);
      AParser.LoadFromStream(Input);
      Expect(AParser.WriteToString = TextBefore, AName + ' reads UTF-8 from current stream position');

      Input.Clear;
      Prefix[0]:=$EF; Prefix[1]:=$BB; Prefix[2]:=$BF;
      Input.WriteBuffer(Prefix, Length(Prefix));
      if Length(Actual) > 0 then
        Input.WriteBuffer(Actual[0], Length(Actual));
      Input.Position:=0;
      AParser.LoadFromStream(Input);
      Expect(AParser.WriteToString = TextBefore, AName + ' accepts one leading UTF-8 BOM');

      ShortInput:=TShortReadStream.Create(Actual);
      try
        AParser.LoadFromStream(ShortInput);
        Expect(AParser.WriteToString = TextBefore, AName + ' reads short non-seekable chunks');
      finally
        ShortInput.Free;
      end;

      Input.Clear;
      Prefix[0]:=$C0; Prefix[1]:=$AF;
      Input.WriteBuffer(Prefix, 2);
      Input.Position:=0;
      try
        AParser.LoadFromStream(Input);
        raise Exception.Create(AName + ' accepted malformed UTF-8');
      except
        on ETJAXYException do Expect(True, AName + ' rejects malformed UTF-8');
      end;
    finally
      Input.Free;
    end;
  finally
    Stream.Free;
  end;
end;

procedure TestTextStreamEncoding;
var
  Parser: TTJAXYParser;
  Stream: TMemoryStream;
const
  UnicodeValue = #$20AC + #$4E2D + #$D83D + #$DE00;
begin
  Parser:=TJSON.FromString('{"name":"' + UnicodeValue + '"}');
  try ExpectUTF8Bytes(Parser, 'JSON'); finally Parser.Free; end;
  Parser:=TYAML.FromString('name: "' + UnicodeValue + '"', yeYAML);
  try ExpectUTF8Bytes(Parser, 'YAML'); finally Parser.Free; end;
  Parser:=TTOML.FromString('name = "' + UnicodeValue + '"');
  try ExpectUTF8Bytes(Parser, 'TOML'); finally Parser.Free; end;
  Parser:=TXML.FromString('<name>' + #$20AC + #$4E2D + '</name>');
  try ExpectUTF8Bytes(Parser, 'XML'); finally Parser.Free; end;
  Parser:=TAvro.CreateFromString('"' + UnicodeValue + '"', '"string"');
  try ExpectUTF8Bytes(Parser, 'Avro JSON'); finally Parser.Free; end;
  Stream:=TMemoryStream.Create;
  try
    try
      TJAXYWriteUTF8(Stream, #$D800);
      raise Exception.Create('Unpaired UTF-16 surrogate was emitted');
    except
      on ETJAXYException do Expect(True, 'UTF-8 writer rejects an unpaired UTF-16 surrogate');
    end;
  finally
    Stream.Free;
  end;
  try
    Parser:=TJSON.FromString('{"name":"' + #$D800 + '"}');
    Parser.Free;
    raise Exception.Create('JSON string input accepted an unpaired UTF-16 surrogate');
  except
    on ETJAXYException do Expect(True, 'JSON string input rejects an unpaired UTF-16 surrogate');
  end;
  try
    Parser:=TYAML.FromConfigurationString('name: "' + #$D800 + '"');
    Parser.Free;
    raise Exception.Create('YAML configuration input accepted an unpaired UTF-16 surrogate');
  except
    on ETJAXYException do Expect(True, 'YAML configuration input rejects an unpaired UTF-16 surrogate');
  end;
end;

procedure TestJSONAndYAMLSharedShape;
var
  Parser: TTJAXYParser;
begin
  Parser:=TJSON.FromString('{"name":"TJAXY","enabled":true,"items":["json","yaml"]}');
  try
    Expect(Parser.Root.AsObject['name'].AsString = 'TJAXY', 'JSON shared parser string');
    Expect(Parser.Root.AsObject.GetValue('name', '') = 'TJAXY', 'JSON GetValue reads current-level key');
    Expect(Parser.Root.AsObject.FindValue('name', '') = 'TJAXY', 'JSON FindValue finds current-level key');
    Expect(Parser.Root.AsObject.FindValue('items[1]', '') = 'yaml', 'JSON FindValue reads array index');
    Expect(Parser.Root.AsObject.FindValue('items[]', '') = 'json', 'JSON FindValue reads first array match');
    Expect(Parser.Root.AsObject['enabled'].AsBoolean, 'JSON shared parser boolean');
    Expect(Parser.Root.AsObject['items'].AsArray.Count = 2, 'JSON shared parser array');
    Expect(Pos('"items"', Parser.WriteToString(tjaxywmCondensed)) > 0, 'JSON shared writer');
  finally
    Parser.Free;
  end;

  Parser:=TYAML.FromString('--- {name: "TJAXY", enabled: true, items: ["json", "yaml"]}');
  try
    Expect(Parser.Root.AsObject['name'].AsString = 'TJAXY', 'YAML shared parser string');
    Expect(Parser.Root.AsObject['enabled'].AsBoolean, 'YAML shared parser boolean');
    Expect(Parser.Root.AsObject['items'].AsArray.Count = 2, 'YAML shared parser array');
    Expect(Pos('items:', Parser.WriteToString(tjaxywmCondensed)) > 0, 'YAML shared writer');
  finally
    Parser.Free;
  end;
end;

procedure TestTOMLSharedShape;
var
  Parser: TTJAXYParser;
begin
  Parser:=TTOML.FromString('name = "TJAXY"' + sLineBreak + 'enabled = true' + sLineBreak + 'items = ["json", "toml"]');
  try
    Expect(Parser.Root.AsObject['name'].AsString = 'TJAXY', 'TOML shared parser string');
    Expect(Parser.Root.AsObject['enabled'].AsBoolean, 'TOML shared parser boolean');
    Expect(Parser.Root.AsObject['items'].AsArray.Count = 2, 'TOML shared parser array');
    Expect(Pos('items=', Parser.WriteToString(tjaxywmCondensed)) > 0, 'TOML shared writer');
  finally
    Parser.Free;
  end;
end;

procedure TestXMLSharedShape;
var
  Parser: TTJAXYParser;
  Root: TTJAXYObject;
begin
  Parser:=TXML.FromString('<project enabled="true"><name>TJAXY</name><format>json</format><format>xml</format></project>');
  try
    Root:=Parser.Root.AsObject['project'].AsObject;
    Expect(Root['@'].AsObject['enabled'].AsString = 'true', 'XML shared parser attributes');
    Expect(Root.GetValue('enabled', False), 'XML GetValue reads attribute fallback');
    Expect(Root['name'].AsString = 'TJAXY', 'XML shared parser scalar child');
    Expect(Root.GetValue('name', '') = 'TJAXY', 'XML GetValue reads direct child before attributes');
    Expect(Root['format'].AsArray.Count = 2, 'XML shared parser repeated children');
    Expect(Parser.Root.AsObject.FindValue('enabled', False), 'XML FindValue finds nested attribute fallback');
    Expect(Parser.Root.AsObject.FindValue('project.name', '') = 'TJAXY', 'XML FindValue follows dotted path');
    Expect(Parser.Root.AsObject.FindValue('project.format[1]', '') = 'xml', 'XML FindValue reads repeated element array index');
    Expect(Parser.Root.AsObject.FindValue('project.format[*]', '') = 'json', 'XML FindValue reads wildcard first match');
    Expect(Pos('<project enabled="true">', Parser.WriteToString(tjaxywmCondensed)) > 0, 'XML shared writer');
  finally
    Parser.Free;
  end;
end;

procedure TestAvroSharedShape;
const
  Schema =
    '{"type":"record","name":"Project","fields":[' +
    '{"name":"name","type":"string"},' +
    '{"name":"enabled","type":"boolean"},' +
    '{"name":"items","type":{"type":"array","items":"string"}}' +
    ']}';
var
  Parser: TTJAXYParser;
begin
  Parser:=TAvro.FromString('{"name":"TJAXY","enabled":true,"items":["json","avro"]}', Schema);
  try
    Expect(Parser.Root.AsObject['name'].AsString = 'TJAXY', 'Avro shared parser string');
    Expect(Parser.Root.AsObject['enabled'].AsBoolean, 'Avro shared parser boolean');
    Expect(Parser.Root.AsObject['items'].AsArray.Count = 2, 'Avro shared parser array');
    Expect(Pos('"items"', Parser.WriteToString(tjaxywmCondensed)) > 0, 'Avro shared writer');
  finally
    Parser.Free;
  end;
end;

procedure TestAssignBetweenDocuments;
var
  JSON: TJSON;
  XML: TXML;
begin
  JSON:=TJSON.CreateObjectRoot;
  XML:=TXML.CreateObjectRoot;
  try
    JSON.AsObject.AddObject('project').Add('name', 'TJAXY');
    XML.Assign(JSON);
    Expect(XML.Root.AsObject['project'].AsObject['name'].AsString = 'TJAXY', 'documents assign through core DOM');
    Expect(Pos('<project>', XML.WriteToString(tjaxywmCondensed)) > 0, 'assigned XML writes core DOM');
  finally
    XML.Free;
    JSON.Free;
  end;
end;

begin
  try
    TestJSONAndYAMLSharedShape;
    TestTOMLSharedShape;
    TestXMLSharedShape;
    TestAvroSharedShape;
    TestAssignBetweenDocuments;
    TestTextStreamEncoding;
  except
    on E: Exception do
    begin
      Writeln('[FAIL] ', E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
end.
