program TJAXYXMLSmoke;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  TJAXY.Core,
  TJAXY.XML;

procedure Expect(ACondition: Boolean; const AMessage: String);
begin
  if ACondition then
    Writeln('[PASS] ', AMessage)
  else
    raise Exception.Create(AMessage);
end;

procedure ExpectFails(const AXML, AMessage: String);
var
  XML: TXML;
begin
  XML:=nil;
  try
    try
      XML:=TXML.CreateFromString(AXML);
      raise Exception.Create(AMessage + ': expected XML rejection');
    except
      on EXMLException do
        Writeln('[PASS] ', AMessage);
    end;
  finally
    XML.Free;
  end;
end;

procedure TestParseConvention;
var
  XML: TXML;
  Root, Item: TTJAXYObject;
begin
  XML:=TXML.CreateFromString(
    '<?xml version="1.0"?>' +
    '<!DOCTYPE catalog [<!ELEMENT catalog ANY><!ELEMENT item ANY><!ELEMENT name ANY>]>' +
    '<catalog version="1">' +
    '<?touch ignored?>' +
    '<item id="a">First &amp; &#x41;</item>' +
    '<item id="b"><name><![CDATA[Second <raw>]]></name></item>' +
    '</catalog>');
  try
    Root:=XML.Root.AsObject['catalog'].AsObject;
    Expect(Root['@'].AsObject['version'].AsString = '1', 'attributes are stored under @');
    Expect(Root.GetValue('version', '') = '1', 'GetValue reads XML attributes without @ decoration');
    Expect(Root['item'].AsArray.Count = 2, 'repeated child elements become arrays');
    Item:=Root['item'].AsArray[0].AsObject;
    Expect(Item['@'].AsObject['id'].AsString = 'a', 'child attributes are preserved');
    Expect(Item.GetValue('id', '') = 'a', 'GetValue reads child attribute fallback');
    Expect(Item['#text'].AsString = 'First & A', 'mixed element text is stored under #text and entities decode');
    Expect(Item.GetValue('', '') = 'First & A', 'GetValue with empty key reads current text value');
    Expect(Root.FindValue('id', '') = 'a', 'FindValue recursively finds XML attribute fallback');
    Expect(Root['item'].AsArray[1].AsObject['name'].AsString = 'Second <raw>', 'CDATA text can be scalar');
  finally
    XML.Free;
  end;

  XML:=TXML.CreateFromString('<entry id="attr"><id>child</id></entry>');
  try
    Root:=XML.Root.AsObject['entry'].AsObject;
    Expect(Root.GetValue('id', '') = 'child', 'GetValue direct child wins over attribute fallback');
  finally
    XML.Free;
  end;
end;

procedure TestNamespaceModes;
var
  XML: TXML;
begin
  XML:=TXML.CreateFromString('<h:root xmlns:h="urn:test" h:id="7"><h:item>value</h:item></h:root>');
  try
    Expect(XML.Root.AsObject['h:root'].AsObject['@'].AsObject['xmlns:h'].AsString = 'urn:test', 'namespace preserve keeps declaration');
    Expect(XML.Root.AsObject['h:root'].AsObject['h:item'].AsString = 'value', 'namespace preserve keeps element prefix');
  finally
    XML.Free;
  end;

  XML:=TXML.CreateFromString('<h:root xmlns:h="urn:test" h:id="7"><h:item>value</h:item></h:root>', xnmStripPrefixes);
  try
    Expect(XML.Root.AsObject['root'].AsObject['@'].AsObject['id'].AsString = '7', 'namespace strip removes attribute prefix');
    Expect(NOT XML.Root.AsObject['root'].AsObject['@'].AsObject.HasKey('xmlns:h'), 'namespace strip omits namespace declaration');
    Expect(XML.Root.AsObject['root'].AsObject['item'].AsString = 'value', 'namespace strip removes element prefix');
  finally
    XML.Free;
  end;
end;

procedure TestWriteConvention;
var
  XML: TXML;
  Catalog, Attrs, Item: TTJAXYObject;
  Items: TTJAXYArray;
  Text: String;
begin
  XML:=TXML.CreateObjectRoot;
  try
    Catalog:=XML.AsObject.AddObject('catalog');
    Attrs:=Catalog.AddObject('@');
    Attrs.Add('version', '1');

    Items:=Catalog.AddArray('item');
    Item:=Items.AddObject;
    Item.AddObject('@').Add('id', 'a');
    Item.Add('#text', 'First');

    Item:=Items.AddObject;
    Item.AddObject('@').Add('id', 'b');
    Item.Add('name', 'Second');

    Text:=XML.WriteToString(tjaxywmCondensed);
    Expect(Pos('<catalog version="1">', Text) > 0, 'writer emits attributes from @');
    Expect(Pos('<item id="a">First</item>', Text) > 0, 'writer emits #text content');
    Expect(Pos('<name>Second</name>', Text) > 0, 'writer emits nested elements');
  finally
    XML.Free;
  end;
end;

procedure TestFailures;
var
  XML: TXML;
begin
  ExpectFails('<root><item></root>', 'mismatched close tag fails');
  ExpectFails('<root><item>', 'unclosed element fails');
  ExpectFails('<root><!DOCTYPE root></root>', 'doctype inside document fails clearly');
  ExpectFails('<root bad="<"/>', 'literal < in attribute fails');
  ExpectFails('<root>&unknown;</root>', 'unknown entity fails');
  ExpectFails('<root><!-- bad -- comment --></root>', 'invalid comment fails');
  ExpectFails('<root><? ?></root>', 'invalid processing instruction fails');

  XML:=TXML.CreateObjectRoot;
  try
    XML.AsObject.Add('bad name', 'value');
    try
      XML.WriteToString;
      raise Exception.Create('invalid writer name: expected XML rejection');
    except
      on EXMLException do
        Writeln('[PASS] invalid writer name fails');
    end;
  finally
    XML.Free;
  end;
end;

procedure TestParserReference;
var
  Parser: TTJAXYParser;
begin
  Parser:=TXML.CreateFromString('<root><enabled>true</enabled></root>');
  try
    Expect(Parser.Root.AsObject['root'].AsObject['enabled'].AsString = 'true', 'XML works through TTJAXYParser reference');
  finally
    Parser.Free;
  end;
end;

begin
  try
    TestParseConvention;
    TestNamespaceModes;
    TestWriteConvention;
    TestParserReference;
    TestFailures;
  except
    on E: Exception do
    begin
      Writeln('[FAIL] ', E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
end.
