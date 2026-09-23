program TJAXYTOMLSmoke;

{$APPTYPE CONSOLE}

uses
  System.Math,
  System.SysUtils,
  TJAXY.Core,
  TJAXY.TOML;

procedure Expect(ACondition: Boolean; const AMessage: String);
begin
  if ACondition then
    Writeln('[PASS] ', AMessage)
  else
    raise Exception.Create(AMessage);
end;

procedure ExpectFails(const ATOML, AMessage: String);
var
  TOML: TTOML;
begin
  TOML:=nil;
  try
    try
      TOML:=TTOML.CreateFromString(ATOML);
      raise Exception.Create(AMessage + ': expected TOML rejection');
    except
      on ETOMLException do
        Writeln('[PASS] ', AMessage);
    end;
  finally
    TOML.Free;
  end;
end;

procedure TestParse;
var
  TOML: TTOML;
begin
  TOML:=TTOML.CreateFromString(
    '# comment' + sLineBreak +
    'title = "TJAXY"' + sLineBreak +
    'enabled = true' + sLineBreak +
    'count = 7' + sLineBreak +
    'hex = 0xDEAD_BEEF' + sLineBreak +
    'oct = 0o755' + sLineBreak +
    'bin = 0b1101' + sLineBreak +
    'ratio = 3.5' + sLineBreak +
    'pos_inf = inf' + sLineBreak +
    'neg_inf = -inf' + sLineBreak +
    'not_a_number = nan' + sLineBreak +
    'local_date = 1979-05-27' + sLineBreak +
    'local_time = 07:32:00' + sLineBreak +
    'local_datetime = 1979-05-27 07:32:00' + sLineBreak +
    'offset_datetime = 1979-05-27T07:32:00Z' + sLineBreak +
    'escaped = "Hello\tJos\xE9"' + sLineBreak +
    'literal = ''C:\Data\templates''' + sLineBreak +
    'multiline = """' + sLineBreak +
    'Roses are red' + sLineBreak +
    'Violets are blue"""' + sLineBreak +
    'literal_multiline = ' + #39#39#39 + sLineBreak +
    'Line one \ stays literal' + sLineBreak +
    'Line two' + #39#39#39 + sLineBreak +
    'formats = ["json", "toml"]' + sLineBreak +
    'owner.name = "NaliLord"' + sLineBreak +
    'metadata = { license = "BSD-2-Clause", nested = { ok = true } }' + sLineBreak +
    sLineBreak +
    '[database]' + sLineBreak +
    'server = "db.local"' + sLineBreak +
    'ports = [8000, 8001]' + sLineBreak +
    sLineBreak +
    '[[products]]' + sLineBreak +
    'name = "Hammer"' + sLineBreak +
    'sku = 738594937' + sLineBreak +
    sLineBreak +
    '[[products]]' + sLineBreak +
    'name = "Nail"' + sLineBreak);
  try
    Expect(TOML.AsObject['title'].AsString = 'TJAXY', 'root string');
    Expect(TOML.AsObject['enabled'].AsBoolean, 'root boolean');
    Expect(TOML.AsObject['count'].AsInteger = 7, 'root integer');
    Expect(TOML.AsObject['hex'].AsInteger = Int64($DEADBEEF), 'hex integer');
    Expect(TOML.AsObject['oct'].AsInteger = 493, 'octal integer');
    Expect(TOML.AsObject['bin'].AsInteger = 13, 'binary integer');
    Expect(Abs(TOML.AsObject['ratio'].AsFloat - 3.5) < 0.001, 'root float');
    Expect(TOML.AsObject['pos_inf'].AsFloat = Infinity, 'positive infinity float');
    Expect(TOML.AsObject['neg_inf'].AsFloat = NegInfinity, 'negative infinity float');
    Expect(TOML.AsObject['not_a_number'].AsFloat <> TOML.AsObject['not_a_number'].AsFloat, 'nan float');
    Expect(TOML.AsObject['local_date'].AsString = '1979-05-27', 'local date token');
    Expect(TOML.AsObject['local_date'] IS TTJAXYDateTime, 'local date token has temporal value class');
    Expect(TTJAXYDateTime(TOML.AsObject['local_date']).Kind = tjaxydtkLocalDate, 'local date token kind');
    Expect(TOML.AsObject['local_time'].AsString = '07:32:00', 'local time token');
    Expect(TOML.AsObject['local_datetime'].AsString = '1979-05-27 07:32:00', 'local datetime token');
    Expect(TOML.AsObject['offset_datetime'].AsString = '1979-05-27T07:32:00Z', 'offset datetime token');
    Expect(TOML.AsObject['escaped'].AsString = 'Hello' + #9 + 'Jos' + Char($E9), 'basic string escape decoding');
    Expect(TOML.AsObject['literal'].AsString = 'C:\Data\templates', 'literal string preserves backslashes');
    Expect(Pos('Roses are red', TOML.AsObject['multiline'].AsString) > 0, 'multiline basic string');
    Expect(Pos('Line one \ stays literal', TOML.AsObject['literal_multiline'].AsString) > 0, 'multiline literal string');
    Expect(TOML.AsObject['formats'].AsArray.Count = 2, 'array value');
    Expect(TOML.AsObject['owner'].AsObject['name'].AsString = 'NaliLord', 'dotted key creates object');
    Expect(TOML.AsObject['metadata'].AsObject['license'].AsString = 'BSD-2-Clause', 'inline table value');
    Expect(TOML.AsObject['metadata'].AsObject['nested'].AsObject['ok'].AsBoolean, 'nested inline table value');
    Expect(TOML.AsObject['database'].AsObject['ports'].AsArray[1].AsInteger = 8001, 'table array value');
    Expect(TOML.AsObject['products'].AsArray.Count = 2, 'array of tables count');
    Expect(TOML.AsObject['products'].AsArray[1].AsObject['name'].AsString = 'Nail', 'array of tables object');
  finally
    TOML.Free;
  end;
end;

procedure TestFailures;
begin
  ExpectFails('a. = 1', 'trailing dotted key component rejected');
  ExpectFails('a b = 1', 'space inside bare key rejected');
  ExpectFails('a..b = 1', 'empty dotted key component rejected');
  ExpectFails('a.#b = 1', 'missing dotted key component before comment rejected');
  ExpectFails('name = "one"' + sLineBreak + 'name = "two"', 'duplicate root key rejected');
  ExpectFails('name = "one" "two"', 'trailing string content rejected');
  ExpectFails('values = [1] nope', 'trailing array content rejected');
  ExpectFails('metadata = { license = "BSD-2-Clause", }', 'inline table trailing comma rejected');
  ExpectFails('value = 0123', 'leading zero integer rejected');
  ExpectFails('value = 1__2', 'invalid integer underscore rejected');
  ExpectFails('when = 1979-15-27', 'invalid date token rejected');
  ExpectFails('[database]' + sLineBreak + '[database]', 'duplicate table rejected');
  ExpectFails('database = "db.local"' + sLineBreak + '[database]', 'scalar cannot become table');
  ExpectFails('values = [1,,2]', 'empty array item rejected');
  ExpectFails('metadata = { license = "BSD-2-Clause", , owner = "TJAXY" }', 'empty inline table pair rejected');
end;

procedure TestNestedArrayTables;
var
  TOML: TTOML;
begin
  TOML:=TTOML.FromString(
    '[[products]]' + sLineBreak +
    'name = "a"' + sLineBreak +
    '[products.details]' + sLineBreak +
    'color = "red"' + sLineBreak +
    '[[products]]' + sLineBreak +
    'name = "b"' + sLineBreak +
    '[products.details]' + sLineBreak +
    'color = "blue"');
  try
    Expect(TOML.AsObject['products'].AsArray.Count = 2, 'nested array table retains two products');
    Expect(TOML.AsObject['products'].AsArray[0].AsObject['details'].AsObject['color'].AsString = 'red',
      'first array table detail retained');
    Expect(TOML.AsObject['products'].AsArray[1].AsObject['details'].AsObject['color'].AsString = 'blue',
      'second array table detail retained');
  finally
    TOML.Free;
  end;
  TOML:=TTOML.FromString(
    '"" = 1' + sLineBreak +
    '"spaced key".child = 2' + sLineBreak +
    '[parent.child]' + sLineBreak +
    'value = 3' + sLineBreak +
    '[parent]' + sLineBreak +
    'other = 4');
  try
    Expect(TOML.AsObject[''].AsInteger = 1, 'quoted empty TOML key is valid');
    Expect(TOML.AsObject['spaced key'].AsObject['child'].AsInteger = 2,
      'quoted dotted TOML key is valid');
    Expect(TOML.AsObject['parent'].AsObject['child'].AsObject['value'].AsInteger = 3,
      'implicit TOML parent keeps child table');
    Expect(TOML.AsObject['parent'].AsObject['other'].AsInteger = 4,
      'implicit TOML parent can be defined later');
  finally
    TOML.Free;
  end;
  TOML:=TTOML.FromString(
    '[[products]]' + sLineBreak +
    '[[products.variants]]' + sLineBreak +
    'name = "small"' + sLineBreak +
    '[[products]]' + sLineBreak +
    '[[products.variants]]' + sLineBreak +
    'name = "large"');
  try
    Expect(TOML.AsObject['products'].AsArray[0].AsObject['variants'].AsArray[0].AsObject['name'].AsString = 'small',
      'first nested array of tables stays under first product');
    Expect(TOML.AsObject['products'].AsArray[1].AsObject['variants'].AsArray[0].AsObject['name'].AsString = 'large',
      'second nested array of tables stays under second product');
  finally
    TOML.Free;
  end;
end;

procedure TestWrite;
var
  TOML: TTOML;
  Root, Owner, Product: TTJAXYObject;
  Products, Formats: TTJAXYArray;
  Text: String;
begin
  TOML:=TTOML.CreateObjectRoot;
  try
    Root:=TOML.AsObject;
    Root.Add('title', 'TJAXY');
    Root.Add('enabled', True);
    Root.Add('released', TTJAXYDateTime.CreateFrom('2026-05-31', tjaxydtkLocalDate));
    Formats:=Root.AddArray('formats');
    Formats.Add('json');
    Formats.Add('toml');
    Owner:=Root.AddObject('owner');
    Owner.Add('name', 'NaliLord');
    Products:=Root.AddArray('products');
    Product:=Products.AddObject;
    Product.Add('name', 'Hammer');
    Product.Add('sku', Int64(738594937));

    Text:=TOML.WriteToString(tjaxywmCondensed);
    Expect(Pos('title="TJAXY"', Text) > 0, 'writer scalar');
    Expect(Pos('released=2026-05-31', Text) > 0, 'writer temporal scalar');
    Expect(Pos('formats=["json","toml"]', Text) > 0, 'writer array');
    Expect(Pos('[owner]', Text) > 0, 'writer table');
    Expect(Pos('[[products]]', Text) > 0, 'writer array of tables');
  finally
    TOML.Free;
  end;
end;

procedure TestParserReference;
var
  Parser: TTJAXYParser;
begin
  Parser:=TTOML.CreateFromString('name = "TJAXY"' + sLineBreak + 'enabled = true');
  try
    Expect(Parser.Root.AsObject['name'].AsString = 'TJAXY', 'TOML works through TTJAXYParser reference');
    Expect(Parser.Root.AsObject['enabled'].AsBoolean, 'TOML parser reference boolean');
  finally
    Parser.Free;
  end;
end;

begin
  try
    TestParse;
    TestWrite;
    TestParserReference;
    TestFailures;
    TestNestedArrayTables;
  except
    on E: Exception do
    begin
      Writeln('[FAIL] ', E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
end.
