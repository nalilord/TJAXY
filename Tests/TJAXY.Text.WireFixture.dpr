program TJAXYTextWireFixture;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  TJAXY.Core,
  TJAXY.JSON,
  TJAXY.YAML,
  TJAXY.TOML,
  TJAXY.XML,
  TJAXY.Avro;

const
  UnicodeValue = #$20AC + #$4E2D + #$D83D + #$DE00;
  XMLUnicodeValue = #$20AC + #$4E2D;
  CDataValue = '<raw>&amp;' + XMLUnicodeValue + #10 + 'end]]>tail]]>';

procedure SaveDocument(ADocument: TTJAXYDocument; const APath: String);
begin
  try
    ADocument.SaveToFile(APath);
  finally
    ADocument.Free;
  end;
end;

var
  OutputDirectory: String;
  CDataXML: TXML;
  Root: TTJAXYObject;
  Parts: TTJAXYArray;
begin
  if ParamCount <> 1 then
    raise Exception.Create('Usage: TJAXY.Text.WireFixture <output-directory>');
  OutputDirectory:=IncludeTrailingPathDelimiter(ParamStr(1));
  SaveDocument(TJSON.FromString('{"name":"' + UnicodeValue + '"}'), OutputDirectory + 'data.json');
  SaveDocument(TYAML.FromString('name: "' + UnicodeValue + '"', yeYAML), OutputDirectory + 'data.yaml');
  SaveDocument(TTOML.FromString('name = "' + UnicodeValue + '"'), OutputDirectory + 'data.toml');
  SaveDocument(TXML.FromString('<name>' + XMLUnicodeValue + '</name>'), OutputDirectory + 'data.xml');
  CDataXML:=TXML.CreateObjectRoot;
  try
    Root:=CDataXML.AsObject.AddObject('root');
    Root.AddObject('payload').Add('#cdata', CDataValue);
    Root.AddObject('empty').Add('#cdata', '');
    Parts:=Root.AddObject('mixed').AddArray('#children');
    Parts.AddObject.Add('#text', 'before&');
    Parts.AddObject.Add('#cdata', '<middle>&');
    Parts.AddObject.Add('child', 'value');
    Parts.AddObject.Add('#text', 'after');
    CDataXML.SaveToFile(OutputDirectory + 'data.cdata.xml');
  finally
    CDataXML.Free;
  end;
  SaveDocument(TAvro.CreateFromString('"' + UnicodeValue + '"', '"string"'), OutputDirectory + 'data.avro.json');
end.
