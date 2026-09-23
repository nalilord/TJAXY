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

procedure ExpectInvalidJSON(const AText, AName: String);
var
  Parsed: TJSON;
begin
  Parsed:=nil;
  try
    try
      Parsed:=TJSON.FromString(AText);
      raise Exception.Create(AName + ': expected JSON rejection');
    except
      on EJSONException do Writeln('[PASS] ', AName);
    end;
  finally
    Parsed.Free;
  end;
end;

var
  Parser: TJSON;
  BaseParser: TTJAXYParser;
  Text: String;
  Control: Integer;

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

  ExpectInvalidJSON('01', 'leading zero is invalid JSON');
  ExpectInvalidJSON('.5', 'leading decimal point is invalid JSON');
  ExpectInvalidJSON('1.', 'trailing decimal point is invalid JSON');
  ExpectInvalidJSON('1e+', 'missing exponent digits are invalid JSON');
  ExpectInvalidJSON('1e-', 'missing negative exponent digits are invalid JSON');
  ExpectInvalidJSON('+1', 'leading plus is invalid JSON');
  ExpectInvalidJSON('0x10', 'hexadecimal is invalid in strict JSON');
  ExpectInvalidJSON('1a', 'number token must terminate');
  for Control:=0 to 31 do
    ExpectInvalidJSON('"a' + Char(Control) + 'b"',
      'literal control character ' + IntToStr(Control) + ' is invalid JSON');
  Parser:=TJSON.FromString('"\u0009\n"');
  try
    Expect(Parser.Root.AsString = #9#10, 'escaped JSON controls parse');
  finally
    Parser.Free;
  end;
  Parser:=TJSON.FromString('0.5e+2');
  try
    Expect(Abs(Parser.Root.AsFloat - 50) < 0.001, 'valid JSON exponent parses');
  finally
    Parser.Free;
  end;
  Parser:=TJSON.FromString('-0x10', jeJSON5);
  try
    Expect(Parser.Root.AsInteger = -16, 'JSON5 negative hexadecimal sign preserved');
  finally
    Parser.Free;
  end;
  Parser:=TJSON.FromString('-0x8000000000000000', jeJSON5);
  try
    Expect(Parser.Root.AsInteger = Low(Int64), 'JSON5 negative hexadecimal lower bound');
  finally
    Parser.Free;
  end;
  Parser:=TJSON.FromString('0x7FFFFFFFFFFFFFFF', jeJSON5);
  try
    Expect(Parser.Root.AsInteger = High(Int64), 'JSON5 positive hexadecimal upper bound');
  finally
    Parser.Free;
  end;
  Parser:=nil;
  try
    try
      Parser:=TJSON.FromString('0x8000000000000000', jeJSON5);
      raise Exception.Create('JSON5 positive hexadecimal overflow accepted');
    except
      on EJSONException do Writeln('[PASS] JSON5 positive hexadecimal overflow rejected');
    end;
  finally
    Parser.Free;
  end;
  Parser:=nil;
  try
    try
      Parser:=TJSON.FromString('-0x8000000000000001', jeJSON5);
      raise Exception.Create('JSON5 negative hexadecimal overflow accepted');
    except
      on EJSONException do Writeln('[PASS] JSON5 negative hexadecimal overflow rejected');
    end;
  finally
    Parser.Free;
  end;
end.
