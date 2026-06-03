program TJAXYJSONSmoke;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  TJAXY.Core,
  TJAXY.JSON;

procedure Expect(ACondition: Boolean; const AName: String; const ADetails: String = '');
begin
  if NOT ACondition then
  begin
    if ADetails <> '' then
      raise Exception.Create(AName + ': ' + ADetails)
    else
      raise Exception.Create(AName);
  end;
  Writeln('[PASS] ', AName);
end;

var
  Parser: TJSON;
  BaseParser: TTJAXYParser;
  Text: String;

begin
  Parser:=TJSON.Create;
  try
    Parser.ReadFromString('{"name":"TJAXY","formats":["json","yaml"],"active":true,"count":2}');

    Expect(Parser.IsObject, 'JSON parser exposes object root');
    Expect(Parser.AsObject['name'].AsString = 'TJAXY', 'Object string access works');
    Expect(Parser.AsObject['formats'].AsArray.Count = 2, 'Array access works');
    Expect(Parser.AsObject['active'].AsBoolean, 'Boolean access works');
    Expect(Parser.AsObject.FindNode('formats') = Parser.AsObject['formats'], 'FindNode access works');
    Expect(Parser.AsObject.FindValue('formats[1]', '') = 'yaml', 'FindValue array index works');

    Parser.AsObject.SetOrAdd('xml', True);
    Text:=Parser.WriteToString(jswmCondensed);
    Expect(Pos('"xml":true', Text) > 0, 'JSON write includes edited values', Text);
  finally
    Parser.Free;
  end;

  BaseParser:=TJSON.Create;
  try
    BaseParser.ReadFromString('{"base":true}');
    Expect(BaseParser.Root.AsObject['base'].AsBoolean, 'JSON shared root object access works');
    Text:=BaseParser.WriteToString(tjaxywmCondensed);
    Expect(Pos('"base":true', Text) > 0, 'JSON works through TTJAXYParser reference', Text);
  finally
    BaseParser.Free;
  end;
end.
