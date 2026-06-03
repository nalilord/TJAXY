program TJSONTestRunner;

{$APPTYPE CONSOLE}
{$RTTI EXPLICIT METHODS([]) PROPERTIES([vcPublic]) FIELDS([vcPublic])}

uses
  System.SysUtils,
  System.Classes,
  TJAXY.Core,
  TJAXY.JSON;

type
  TTestStatus = (tsNew, tsDone);

  TTemplateCallbackHost = class
  public
    procedure FillCallback(ATemplateName, AKeyName: String; var AValue: TTJAXYValue);
  end;

  TTestChild = class
  private
    FName: String;
  public
    property Name: String read FName write FName;
  end;

  TTestPerson = class
  private
    FActive: Boolean;
    FAge: Integer;
    FChild: TTestChild;
    FName: String;
    FScores: TArray<Integer>;
    FStatus: TTestStatus;
  public
    constructor Create;
    destructor Destroy; override;
    property Active: Boolean read FActive write FActive;
    property Age: Integer read FAge write FAge;
    property Child: TTestChild read FChild write FChild;
    property Name: String read FName write FName;
    property Scores: TArray<Integer> read FScores write FScores;
    property Status: TTestStatus read FStatus write FStatus;
  end;

  TTestRecord = record
  public
    Name: String;
    Count: Integer;
    Tags: TArray<String>;
  end;

var
  TotalChecks: Integer = 0;
  PassedChecks: Integer = 0;
  FailedChecks: Integer = 0;

procedure TTemplateCallbackHost.FillCallback(ATemplateName, AKeyName: String; var AValue: TTJAXYValue);
begin
  AValue:=TTJAXYString.CreateFrom(ATemplateName + ':' + AKeyName);
end;

constructor TTestPerson.Create;
begin
  inherited Create;
  FChild:=TTestChild.Create;
end;

destructor TTestPerson.Destroy;
begin
  FChild.Free;
  inherited;
end;

procedure Expect(const ACondition: Boolean; const AName: String; const ADetails: String = '');
begin
  Inc(TotalChecks);

  if ACondition then
  begin
    Inc(PassedChecks);
    Writeln('[PASS] ', AName);
  end else
  begin
    Inc(FailedChecks);
    if ADetails = '' then
      Writeln('[FAIL] ', AName)
    else
      Writeln('[FAIL] ', AName, ' - ', ADetails);
  end;
end;

procedure ExpectEqInt(const AExpected, AActual: Int64; const AName: String);
begin
  Expect(AExpected = AActual, AName, 'Expected ' + IntToStr(AExpected) + ', got ' + IntToStr(AActual));
end;

procedure ExpectEqString(const AExpected, AActual, AName: String);
begin
  Expect(AExpected = AActual, AName, 'Expected "' + AExpected + '", got "' + AActual + '"');
end;

procedure ExpectEqBool(const AExpected, AActual: Boolean; const AName: String);
begin
  Expect(AExpected = AActual, AName, 'Expected ' + BoolToStr(AExpected, True) + ', got ' + BoolToStr(AActual, True));
end;

procedure ExpectParseFails(const AJSON: String; const AName: String; AExtension: TJSONExtension = jeDefault);
var
  JSON: TJSON;
begin
  JSON:=nil;
  try
    JSON:=TJSON.CreateFromString(AJSON, AExtension);
    Expect(False, AName, 'Parser accepted malformed input');
  except
    on E: EJSONException do
      Expect(True, AName, E.Message);
    on E: Exception do
      Expect(True, AName, E.Message);
  end;
  JSON.Free;
end;

procedure TestBasicDOM;
var
  JSON: TJSON;
  Arr: TTJAXYArray;
  Text: String;
begin
  JSON:=TJSON.CreateObjectRoot;
  try
    JSON.AsObject.Add('name', 'TJAXY');
    JSON.AsObject.Add('count', 7);
    JSON.AsObject.Add('active', True);
    Arr:=JSON.AsObject.AddArray('formats');
    Arr.Add('json');
    Arr.Add('yaml');

    Expect(JSON.IsObject, 'CreateObjectRoot creates shared object root');
    ExpectEqString('TJAXY', JSON.AsObject['name'].AsString, 'Object string access');
    ExpectEqInt(7, JSON.AsObject['count'].AsInteger, 'Object integer access');
    ExpectEqBool(True, JSON.AsObject['active'].AsBoolean, 'Object boolean access');
    ExpectEqInt(2, JSON.AsObject['formats'].AsArray.Count, 'Nested array access');

    Text:=JSON.WriteToString(jswmCondensed);
    Expect(Pos('"formats"', Text) > 0, 'Condensed write contains shared array');
  finally
    JSON.Free;
  end;
end;

procedure TestParsing;
var
  JSON: TJSON;
begin
  JSON:=TJSON.CreateFromString('{"name":"TJAXY","nested":{"value":42},"list":[1,2,3]}');
  try
    ExpectEqString('TJAXY', JSON.Root.AsObject['name'].AsString, 'Parse string');
    ExpectEqInt(42, JSON.Root.AsObject['nested'].AsObject['value'].AsInteger, 'Parse nested integer');
    ExpectEqInt(3, JSON.Root.AsObject['list'].AsArray.Count, 'Parse array count');
    Expect(JSON.Root.AsObject.FindNode('nested.value').AsInteger = 42, 'Shared FindNode path works');
    Expect(JSON.Root.AsObject.FindValue('list[2]', 0) = 3, 'Shared FindValue array index works');
  finally
    JSON.Free;
  end;
end;

procedure TestJSON5;
var
  JSON: TJSON;
begin
  JSON:=TJSON.CreateFromString(
    '{' + sLineBreak +
    '  // comment' + sLineBreak +
    '  name: ''TJAXY'',' + sLineBreak +
    '  hex: 0x10,' + sLineBreak +
    '  trailing: [1, 2,],' + sLineBreak +
    '}',
    jeJSON5
  );
  try
    ExpectEqString('TJAXY', JSON.AsObject['name'].AsString, 'JSON5 single quoted string and unquoted key');
    ExpectEqInt(16, JSON.AsObject['hex'].AsInteger, 'JSON5 hex integer');
    ExpectEqInt(2, JSON.AsObject['trailing'].AsArray.Count, 'JSON5 trailing comma');
  finally
    JSON.Free;
  end;
end;

procedure TestStreams;
var
  Source: TStringStream;
  Target: TStringStream;
  JSON: TJSON;
begin
  Source:=TStringStream.Create('{"stream":true}', TEncoding.UTF8);
  Target:=TStringStream.Create('', TEncoding.UTF8);
  try
    JSON:=TJSON.CreateFromStream(Source);
    try
      ExpectEqBool(True, JSON.AsObject['stream'].AsBoolean, 'CreateFromStream parses');
      JSON.SaveToStream(Target);
      Expect(Pos('"stream"', Target.DataString) > 0, 'SaveToStream writes');
    finally
      JSON.Free;
    end;
  finally
    Source.Free;
    Target.Free;
  end;
end;

procedure TestFailures;
begin
  ExpectParseFails('{"missing": true', 'Malformed object fails');
  ExpectParseFails('[1, 2,', 'Malformed array fails');
  ExpectParseFails('{"text": "unterminated}', 'Malformed string fails');
  ExpectParseFails('{name: "TJAXY"}', 'JSON5 feature rejected in default mode');
end;

procedure TestTemplates;
var
  Template: TTJAXYTemplate;
  Nested: TTJAXYTemplate;
  Doc: TTJAXY;
  Arr: TTJAXYArray;
  CallbackHost: TTemplateCallbackHost;
begin
  Nested:=TTJAXY.CreateTemplate('json-test-nested');
  Nested
    .Add('nestedName', tjaxytString)
    .Default(TTJAXYString.CreateFrom('child'));

  Template:=TJSON.CreateTemplate('json-test-template');
  Template
    .Add('templateName', tjaxyttName)
    .Add('created', tjaxyttUnixTime)
    .Add('int', tjaxytInteger)
    .Add('float', tjaxytFloat)
    .Add('str', tjaxytString)
    .Add('bool', tjaxytBoolean)
    .Add('arr', tjaxytArray)
    .Add('nested', 'json-test-nested');

  Doc:=Template.Empty;
  ExpectEqString('json-test-template', Doc.AsObject['templateName'].AsString, 'Template.Empty name field');
  Expect(Doc.AsObject['created'].AsInteger > 0, 'Template.Empty unix time field');
  ExpectEqString('child', Doc.AsObject['nested'].AsObject['nestedName'].AsString, 'Template.Empty nested template default');

  Arr:=TTJAXYArray.Create;
  Arr.Add(1);
  Arr.Add(2);
  Doc:=Template.Fill([7, 3.5, 'hello', True, Arr, TTJAXYObject.Create]);
  ExpectEqInt(7, Doc.AsObject['int'].AsInteger, 'Template.Fill integer');
  ExpectEqString('hello', Doc.AsObject['str'].AsString, 'Template.Fill string');
  ExpectEqBool(True, Doc.AsObject['bool'].AsBoolean, 'Template.Fill boolean');
  ExpectEqInt(2, Doc.AsObject['arr'].AsArray.Count, 'Template.Fill array object');

  Expect(Template.SetValue('int', 42), 'Template.SetValue accepts matching type');
  ExpectEqInt(42, Template.Document.AsObject['int'].AsInteger, 'Template.SetValue updates document cache');
  Expect(NOT Template.SetValue('int', 'wrong'), 'Template.SetValue rejects wrong type');

  Template:=TTJAXYTemplate.Create('omit-template');
  try
    Template
      .SetFlag(tjaxytfOmitEmpty)
      .Add('keep', tjaxytString).Default(TTJAXYString.CreateFrom('default'))
      .Add('omit', tjaxytString);
    Doc:=Template.Empty;
    Expect(Doc.AsObject.HasKey('keep'), 'Template tfOmitEmpty keeps default');
    Expect(NOT Doc.AsObject.HasKey('omit'), 'Template tfOmitEmpty omits empty field');
  finally
    Template.Free;
  end;

  CallbackHost:=TTemplateCallbackHost.Create;
  try
    Template:=TTJAXYTemplate.Create('callback-template');
    try
      Template.Add('callbackValue', CallbackHost.FillCallback);
      Doc:=Template.Fill([]);
      ExpectEqString('callback-template:callbackValue', Doc.AsObject['callbackValue'].AsString, 'Template callback fills value');
    finally
      Template.Free;
    end;
  finally
    CallbackHost.Free;
  end;
end;

procedure TestRTTIObjectMapping;
var
  Person: TTestPerson;
  Target: TTestPerson;
  JSON: TJSON;
  Rules: TTJAXYSerializerRules;
begin
  Rules:=TTJAXYDocument.DefaultSerializerRules;
  Rules.EnumMode:=tjaxjemName;
  Rules.EnumNameCase:=tjaxyncLower;
  Rules.EnumStripPrefixes:=['ts'];
  TTJAXYDocument.SerializerRules:=Rules;

  Person:=TTestPerson.Create;
  Target:=TTestPerson.Create;
  JSON:=nil;
  try
    Person.Name:='Ada';
    Person.Age:=37;
    Person.Active:=True;
    Person.Status:=tsDone;
    Person.Scores:=[10, 20, 30];
    Person.Child.Name:='Nested';

    JSON:=TJSON.CreateFromObject(Person);
    ExpectEqString('Ada', JSON.AsObject['Name'].AsString, 'RTTI object string property');
    ExpectEqInt(37, JSON.AsObject['Age'].AsInteger, 'RTTI object integer property');
    ExpectEqBool(True, JSON.AsObject['Active'].AsBoolean, 'RTTI object boolean property');
    ExpectEqString('done', JSON.AsObject['Status'].AsString, 'RTTI enum name rules');
    ExpectEqInt(3, JSON.AsObject['Scores'].AsArray.Count, 'RTTI dynamic array write');
    ExpectEqString('Nested', JSON.AsObject['Child'].AsObject['Name'].AsString, 'RTTI nested object write');

    JSON.AssignToObject(Target);
    ExpectEqString('Ada', Target.Name, 'RTTI AssignToObject string property');
    ExpectEqInt(37, Target.Age, 'RTTI AssignToObject integer property');
    ExpectEqBool(True, Target.Active, 'RTTI AssignToObject boolean property');
    Expect(Target.Status = tsDone, 'RTTI AssignToObject enum property');
    ExpectEqInt(3, Length(Target.Scores), 'RTTI AssignToObject dynamic array length');
    ExpectEqInt(20, Target.Scores[1], 'RTTI AssignToObject dynamic array value');
    ExpectEqString('Nested', Target.Child.Name, 'RTTI AssignToObject nested object');
  finally
    JSON.Free;
    Target.Free;
    Person.Free;
    TTJAXYDocument.SerializerRules:=TTJAXYDocument.DefaultSerializerRules;
  end;
end;

procedure TestRTTIRecordMapping;
var
  Rec: TTestRecord;
  Target: TTestRecord;
  JSON: TJSON;
begin
  Rec.Name:='record';
  Rec.Count:=12;
  Rec.Tags:=['json', 'yaml'];
  Target.Name:='';
  Target.Count:=0;
  SetLength(Target.Tags, 0);

  JSON:=TJSON.CreateFromRecord<TTestRecord>(Rec);
  try
    ExpectEqString('record', JSON.AsObject['Name'].AsString, 'RTTI record string field');
    ExpectEqInt(12, JSON.AsObject['Count'].AsInteger, 'RTTI record integer field');
    ExpectEqInt(2, JSON.AsObject['Tags'].AsArray.Count, 'RTTI record dynamic array write');

    JSON.AssignToRecord<TTestRecord>(Target);
    ExpectEqString('record', Target.Name, 'RTTI AssignToRecord string field');
    ExpectEqInt(12, Target.Count, 'RTTI AssignToRecord integer field');
    ExpectEqInt(2, Length(Target.Tags), 'RTTI AssignToRecord dynamic array length');
    ExpectEqString('yaml', Target.Tags[1], 'RTTI AssignToRecord dynamic array value');
  finally
    JSON.Free;
  end;
end;

begin
  try
    TestBasicDOM;
    TestParsing;
    TestJSON5;
    TestStreams;
    TestFailures;
    TestTemplates;
    TestRTTIObjectMapping;
    TestRTTIRecordMapping;

    Writeln('---------------------------------------------');
    Writeln('Checks: ', TotalChecks);
    Writeln('Passed: ', PassedChecks);
    Writeln('Failed: ', FailedChecks);

    if FailedChecks > 0 then
    begin
      Writeln('Result: FAILED');
      Halt(1);
    end;

    Writeln('Result: PASSED');
  except
    on E: Exception do
    begin
      Writeln('[ERROR] ', E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
end.
