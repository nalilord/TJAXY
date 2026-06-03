program TJAXYCrossFormat;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  TJAXY.Core,
  TJAXY.Avro,
  TJAXY.JSON,
  TJAXY.TOML,
  TJAXY.YAML,
  TJAXY.XML;

procedure Expect(ACondition: Boolean; const AMessage: String);
begin
  if ACondition then
    Writeln('[PASS] ', AMessage)
  else
    raise Exception.Create(AMessage);
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
  except
    on E: Exception do
    begin
      Writeln('[FAIL] ', E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
end.
