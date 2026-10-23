program TJAXYXMLSmoke;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
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
    Expect(Root['item'].AsArray[1].AsObject['name'].AsObject['#cdata'].AsString = 'Second <raw>',
      'CDATA is explicit by default');
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

  XML:=nil;
  try
    try
      XML:=TXML.CreateFromString('<a:x xmlns:a="urn:a" xmlns:b="urn:b"></b:x>', xnmStripPrefixes);
      raise Exception.Create('mismatched qualified close tag: expected XML rejection');
    except
      on EXMLException do Writeln('[PASS] mismatched qualified close tag fails when stripping prefixes');
    end;
  finally
    XML.Free;
  end;

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

procedure TestOrderedContent;
const
  Mixed = '<root>A<item id="a"/>B<other/>C<item id="b"/>D</root>';
var
  XML: TXML;
  Root: TTJAXYObject;
  Children: TTJAXYArray;
  Failed: Boolean;
begin
  XML:=TXML.Create;
  try
    Expect(XML.ChildMode = xcmGrouped, 'grouped child mapping remains the default');
    XML.ChildMode:=xcmOrdered;
    XML.ReadFromString(Mixed);
    Children:=XML.AsObject['root'].AsObject['#children'].AsArray;
    Expect(Children.Count = 7, 'ordered mode retains interleaved elements and text');
    Expect(Children[1].AsObject.Name[0] = 'item', 'ordered mode exposes element wrapper names');
    Expect(Children[3].AsObject.Name[0] = 'other', 'ordered mode retains unlike siblings in position');
    Expect(XML.WriteToString(xwmCondensed) = Mixed, 'ordered mixed content round trips exactly');
    Expect(XML.WriteToString(xwmReadable) = Mixed, 'readable writer does not inject mixed-content whitespace');
    XML.ReadFromString('<root><entry/><note/><entry/></root>');
    Expect(XML.WriteToString(xwmCondensed) = '<root><entry/><note/><entry/></root>',
      'ordered mode retains interleaved repeated sibling names');
    XML.NamespaceMode:=xnmStripPrefixes;
    XML.ReadFromString('<n:root xmlns:n="urn:test"><n:a/><n:b/><n:a/></n:root>');
    Expect(XML.WriteToString(xwmCondensed) = '<root><a/><b/><a/></root>', 'ordered mode combines with namespace stripping');
    XML.ReadFromString('<root> '#13#10'<a/> '#13#10'<b/> </root>');
    Expect(XML.WriteToString(xwmReadable) = '<root> '#13#10'<a/> '#13#10'<b/> </root>', 'ordered mode retains existing whitespace nodes');
  finally
    XML.Free;
  end;

  XML:=TXML.CreateObjectRoot;
  try
    Root:=XML.AsObject.AddObject('root');
    Children:=Root.AddArray('#children');
    Children.AddObject.Add('a');
    Children.AddObject.Add('b');
    Children.AddObject.Add('a');
    Expect(XML.WriteToString(xwmCondensed) = '<root><a/><b/><a/></root>', 'ordered writer accepts generated single-key child wrappers');
    Expect(XML.WriteToString(xwmReadable) = '<root>'#13#10'  <a/>'#13#10'  <b/>'#13#10'  <a/>'#13#10'</root>',
      'generated ordered children retain readable line boundaries');
    Root.Add('grouped', 'conflict');
    Failed:=False;
    try
      XML.WriteToString;
    except
      on EXMLException do
        Failed:=True;
    end;
    Expect(Failed, 'ambiguous grouped and ordered children are rejected');
    Root.Delete('grouped');
    Children.AddObject.Add('#text', Int64(7));
    Failed:=False;
    try
      XML.WriteToString;
    except
      on EXMLException do
        Failed:=True;
    end;
    Expect(Failed, 'non-string ordered text is rejected');
  finally
    XML.Free;
  end;
end;

procedure ExpectWriteFails(AXML: TXML; const AMessage: String);
var
  Failed: Boolean;
begin
  Failed:=False;
  try
    AXML.WriteToString;
  except
    on EXMLException do Failed:=True;
  end;
  Expect(Failed, AMessage);
end;

procedure TestCDataReading;
const
  Literal = '  <tag>&amp; &#65; <!--comment--><?pi value?>' + #10 + '  ';
  Mixed = '<root>A<first/>B<![CDATA[ <raw>&amp; ]]>C<second/>D<![CDATA[]]>E</root>';
var
  XML: TXML;
  Parts: TTJAXYArray;
  Mode: TXMLChildMode;
begin
  XML:=TXML.FromString('<root id="1"><![CDATA[' + Literal + ']]></root>');
  try
    Expect(XML.CDataMode = xcdPreserve, 'CDATA preservation is the default');
    Expect(XML.AsObject['root'].AsObject['#cdata'].AsString = Literal,
      'CDATA remains literal, including entities, markup, and surrounding whitespace');
    Expect(XML.WriteToString(xwmCondensed) = '<root id="1"><![CDATA[' + Literal + ']]></root>',
      'attribute and multiline CDATA round trip');
    XML.ReadFromString('<root id="1"><![CDATA[ '#9#10' ]]></root>');
    Expect(XML.AsObject['root'].AsObject['#cdata'].AsString = ' '#9#10' ',
      'whitespace-only CDATA with attributes is retained');
    XML.ReadFromString('<root><![CDATA[]]></root>');
    Expect(XML.AsObject['root'].AsObject.HasKey('#cdata'), 'empty CDATA remains present');
    Expect(XML.WriteToString(xwmReadable) = '<root><![CDATA[]]></root>',
      'empty CDATA writes as a section rather than an empty element');
    XML.ReadFromString('<root><![CDATA[a]]><![CDATA[]]><![CDATA[b]]></root>');
    Parts:=XML.AsObject['root'].AsObject['#children'].AsArray;
    Expect((Parts.Count = 3) AND (Parts[1].AsObject['#cdata'].AsString = ''),
      'adjacent CDATA boundaries and empty sections are preserved');
    Expect(XML.WriteToString(xwmCondensed) = '<root><![CDATA[a]]><![CDATA[]]><![CDATA[b]]></root>',
      'adjacent CDATA sections round trip');

    for Mode:=Low(TXMLChildMode) to High(TXMLChildMode) do
    begin
      XML.ChildMode:=Mode;
      XML.ReadFromString(Mixed);
      Parts:=XML.AsObject['root'].AsObject['#children'].AsArray;
      Expect((Parts.Count = 9) AND (Parts[1].AsObject.Name[0] = 'first') AND
        (Parts[3].AsObject['#cdata'].AsString = ' <raw>&amp; ') AND
        (Parts[5].AsObject.Name[0] = 'second'), 'CDATA preserves all mixed-content positions');
      Expect(XML.WriteToString(xwmCondensed) = Mixed, 'mixed CDATA round trips in either child mode');
      Expect(XML.WriteToString(xwmReadable) = Mixed, 'readable output adds no whitespace around mixed CDATA');
    end;
    XML.NamespaceMode:=xnmStripPrefixes;
    XML.ReadFromString('<n:root xmlns:n="urn:test"><![CDATA[n:raw &amp;]]></n:root>');
    Expect(XML.WriteToString(xwmCondensed) = '<root><![CDATA[n:raw &amp;]]></root>',
      'namespace normalization leaves CDATA payload untouched');
  finally
    XML.Free;
  end;
end;

procedure TestCDataTextMode;
var
  XML: TXML;
begin
  XML:=TXML.Create;
  try
    XML.CDataMode:=xcdText;
    XML.ReadFromString('<root>A&amp;<![CDATA[<raw>&amp;]]>B</root>');
    Expect(XML.AsObject['root'].AsString = 'A&<raw>&amp;B',
      'text mode merges literal CDATA with decoded surrounding text');
    XML.ReadFromString('<root id="1"><![CDATA[ '#9#10' ]]></root>');
    Expect(XML.AsObject['root'].AsObject['#text'].AsString = ' '#9#10' ',
      'text mode retains whitespace-only CDATA with attributes');
    XML.ReadFromString('<root id="1"><![CDATA[]]></root>');
    Expect(XML.AsObject['root'].AsObject.HasKey('#text'), 'text mode retains explicitly empty CDATA with attributes');
    XML.ChildMode:=xcmOrdered;
    XML.ReadFromString('<root>A<![CDATA[<raw>]]><child/>B</root>');
    Expect(XML.WriteToString(xwmCondensed) = '<root>A&lt;raw&gt;<child/>B</root>',
      'text mode escapes flattened CDATA while preserving mixed-content positions');
  finally
    XML.Free;
  end;
end;

procedure TestCDataWritingAndIO;
const
  Payload = ' <raw>&amp; ' + #$20AC + #$4E2D + #10 + 'one]]>two]]> ';
var
  XML, CopyXML: TXML;
  Root: TTJAXYObject;
  Parts: TTJAXYArray;
  Stream: TMemoryStream;
  FileName, Written, Mixed: String;
begin
  XML:=TXML.CreateObjectRoot;
  CopyXML:=TXML.Create;
  Stream:=TMemoryStream.Create;
  try
    Root:=XML.AsObject.AddObject('root');
    Root.AddObject('@').Add('kind', 'raw');
    Root.Add('#cdata', Payload);
    Written:=XML.WriteToString(xwmCondensed);
    Expect(Pos(']]]]><![CDATA[>', Written) > 0, 'writer safely splits embedded CDATA terminators');
    Expect(Pos('&amp;amp;', Written) = 0, 'CDATA payload is not entity escaped');
    CopyXML.CDataMode:=xcdText;
    CopyXML.ReadFromString(Written);
    Expect(CopyXML.AsObject['root'].AsObject['#text'].AsString = Payload,
      'split CDATA sections retain their original text');

    XML.SaveToStream(Stream);
    Stream.Position:=0;
    CopyXML.LoadFromStream(Stream);
    Expect(CopyXML.AsObject['root'].AsObject['#text'].AsString = Payload,
      'CDATA UTF-8 stream I/O preserves the value');
    FileName:=TPath.GetTempFileName;
    try
      XML.SaveToFile(FileName);
      CopyXML.LoadFromFile(FileName);
      Expect(CopyXML.AsObject['root'].AsObject['#text'].AsString = Payload,
        'CDATA file I/O preserves the value');
    finally
      TFile.Delete(FileName);
    end;
    CopyXML.Assign(XML);
    Expect(CopyXML.WriteToString(xwmCondensed) = Written, 'Assign copies explicit CDATA nodes');

    Root.Delete('#cdata');
    Root.Add('#text', '<normal>&');
    Expect(XML.WriteToString(xwmCondensed) = '<root kind="raw">&lt;normal&gt;&amp;</root>',
      'ordinary text continues to use XML escaping');
    Root.Delete('#text');
    Parts:=Root.AddArray('#children');
    Parts.AddObject.Add('#text', 'before&');
    Parts.AddObject.Add('#cdata', '<literal>&');
    Parts.AddObject.Add('child');
    Parts.AddObject.Add('#cdata', '');
    Mixed:='<root kind="raw">before&amp;<![CDATA[<literal>&]]><child/><![CDATA[]]></root>';
    Expect(XML.WriteToString(xwmReadable) = Mixed, 'generated ordered CDATA writes without formatting changes');
    CopyXML.CDataMode:=xcdPreserve;
    CopyXML.ReadFromString(Mixed);
    Expect(CopyXML.WriteToString(xwmCondensed) = Mixed, 'generated mixed CDATA reads back explicitly');
  finally
    Stream.Free;
    CopyXML.Free;
    XML.Free;
  end;
end;

procedure TestCDataFailures;
var
  XML: TXML;
  Root: TTJAXYObject;
  Parts: TTJAXYArray;
  I: Integer;
begin
  ExpectFails('<root><![CDATA[unterminated</root>', 'unterminated CDATA fails');
  ExpectFails('<![CDATA[outside]]><root/>', 'CDATA before the root fails');
  ExpectFails('<root/><![CDATA[outside]]>', 'CDATA after the root fails');
  ExpectFails('<root>stray]]></root>', 'bare CDATA terminator in text fails');
  ExpectFails('<root><![CDATA['#1']]></root>', 'invalid XML character in CDATA fails');
  XML:=TXML.CreateObjectRoot;
  try
    Root:=XML.AsObject.AddObject('root');
    Root.Add('#cdata', Int64(7));
    ExpectWriteFails(XML, 'non-string CDATA fails');
    Root.SetOrAdd('#cdata');
    ExpectWriteFails(XML, 'null CDATA fails');
    Root.SetOrAdd('#cdata', TTJAXYArray.Create);
    ExpectWriteFails(XML, 'array CDATA fails');
    Root.SetOrAdd('#cdata', 'raw');
    Root.Add('#text', 'ambiguous');
    ExpectWriteFails(XML, 'grouped CDATA and text require explicit ordering');
    Root.Delete('#text');
    Root.Add('child');
    ExpectWriteFails(XML, 'grouped CDATA and child elements require explicit ordering');
    Root.Delete('child');
    Root.SetOrAdd('#cdata', String(#1));
    ExpectWriteFails(XML, 'invalid XML character in CDATA output fails');
    Root.Delete('#cdata');
    Parts:=Root.AddArray('#children');
    Parts.AddObject.Add('#cdata', Int64(7));
    ExpectWriteFails(XML, 'non-string ordered CDATA fails');
    Parts.Clear;
    Parts.AddObject.Add('#cdata', 'raw');
    Root.Add('#cdata', 'conflict');
    ExpectWriteFails(XML, 'grouped and ordered CDATA cannot be combined');

    XML.ReadFromString('<root><![CDATA[kept]]></root>');
    for I:=1 to 200 do
    begin
      try
        XML.ReadFromString('<root><child/><![CDATA[raw]]><broken>');
        raise Exception.Create('Expected incomplete mixed CDATA rejection');
      except on EXMLException do ; end;
      try
        XML.ReadFromString('<root><![CDATA[raw]]></root>trailing');
        raise Exception.Create('Expected trailing content rejection');
      except on EXMLException do ; end;
    end;
    Expect(XML.WriteToString(xwmCondensed) = '<root><![CDATA[kept]]></root>',
      'failed CDATA loads retain the previous tree');
  finally
    XML.Free;
  end;
end;

begin
  ReportMemoryLeaksOnShutdown:=True;
  try
    TestParseConvention;
    TestNamespaceModes;
    TestWriteConvention;
    TestParserReference;
    TestOrderedContent;
    TestCDataReading;
    TestCDataTextMode;
    TestCDataWritingAndIO;
    TestCDataFailures;
    TestFailures;
  except
    on E: Exception do
    begin
      Writeln('[FAIL] ', E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
end.
