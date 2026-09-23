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

  TConstructedChild = class(TTestChild)
  public
    Initialized: Boolean;
    constructor Create;
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

  TNestedRecord = record
  public
    Count: Integer;
    Name: String;
  end;

  TNestedHolder = class
  public
    Inner: TNestedRecord;
  end;

  TRecordOuter = record
  public
    Inner: TNestedRecord;
  end;

  TRecordArrayHolder = class
  public
    Items: TArray<TNestedRecord>;
  end;

  TStatusRecord = record
  public
    Status: TTestStatus;
  end;

  TEnumChild = class
  public
    Status: TTestStatus;
  end;

  TEnumHolder = class
  public
    Child: TEnumChild;
    destructor Destroy; override;
  end;

  TUninitializedHolder = class
  public
    Child: TTestChild;
  end;

  TArrayBoundsHolder = class
  public
    Values: array[0..1] of Integer;
    Children: TArray<TTestChild>;
  end;

  TScalarBoundsHolder = class
  public
    Small: Single;
    Count: Comp;
    Money: Currency;
    Narrow: AnsiChar;
    Wide: WideChar;
  end;

  TThrowingSetter = class
  private
    FValue: Integer;
    procedure SetValue(AValue: Integer);
  public
    property Value: Integer read FValue write SetValue;
  end;

  TTrackedChild = class(TTestChild)
  public
    class var Alive: Integer;
    constructor Create;
    destructor Destroy; override;
  end;

  TRejectingChildHolder = class
  private
    FChild: TTestChild;
    procedure SetChild(AValue: TTestChild);
  public
    CommitBeforeRaise: Boolean;
    destructor Destroy; override;
    property Child: TTestChild read FChild write SetChild;
  end;

  TSetBit = (sb00,sb01,sb02,sb03,sb04,sb05,sb06,sb07,sb08,sb09,sb10,sb11,sb12,sb13,sb14,sb15,
    sb16,sb17,sb18,sb19,sb20,sb21,sb22,sb23,sb24,sb25,sb26,sb27,sb28,sb29,sb30,sb31,
    sb32,sb33,sb34,sb35,sb36,sb37,sb38,sb39,sb40,sb41,sb42,sb43,sb44,sb45,sb46,sb47,
    sb48,sb49,sb50,sb51,sb52,sb53,sb54,sb55,sb56,sb57,sb58,sb59,sb60,sb61,sb62,sb63,
    sb64,sb65,sb66,sb67,sb68,sb69,sb70);
  TLargeSet = set of TSetBit;

  TSetHolder = class
  public
    Bits: TLargeSet;
  end;

  TSmallSet = set of TTestStatus;

  TSmallSetHolder = class
  public
    Bits: TSmallSet;
  end;

  TAnonymousSetHolder = class
  public
    Bits: set of TTestStatus;
  end;

  TCycleNode = class
  public
    Child: TCycleNode;
  end;

  TReferencePair = class
  public
    Left: TCycleNode;
    Right: TCycleNode;
  end;

  TRulesThread = class(TThread)
  private
    FPerson: TTestPerson;
    FRules: TTJAXYSerializerRules;
    FExpectName: Boolean;
    FFailure: String;
  protected
    procedure Execute; override;
  public
    constructor Create(APerson: TTestPerson; const ARules: TTJAXYSerializerRules; AExpectName: Boolean);
    property Failure: String read FFailure;
  end;

var
  TotalChecks: Integer = 0;
  PassedChecks: Integer = 0;
  FailedChecks: Integer = 0;

procedure TTemplateCallbackHost.FillCallback(ATemplateName, AKeyName: String; var AValue: TTJAXYValue);
begin
  AValue:=TTJAXYString.CreateFrom(ATemplateName + ':' + AKeyName);
end;

constructor TConstructedChild.Create;
begin
  inherited Create;
  Initialized:=True;
end;

destructor TEnumHolder.Destroy;
begin
  Child.Free;
  inherited;
end;

procedure TThrowingSetter.SetValue(AValue: Integer);
begin
  raise Exception.Create('setter refused value ' + IntToStr(AValue));
end;

constructor TTrackedChild.Create;
begin
  inherited Create;
  Inc(Alive);
end;

destructor TTrackedChild.Destroy;
begin
  Dec(Alive);
  inherited;
end;

procedure TRejectingChildHolder.SetChild(AValue: TTestChild);
begin
  if CommitBeforeRaise then
    FChild:=AValue;
  raise Exception.Create('child setter refused value');
end;

destructor TRejectingChildHolder.Destroy;
begin
  FChild.Free;
  inherited;
end;

function NewTrackedChild: TObject;
begin
  Result:=TTrackedChild.Create;
end;

function NewEnumChild: TObject;
begin
  Result:=TEnumChild.Create;
end;

constructor TRulesThread.Create(APerson: TTestPerson; const ARules: TTJAXYSerializerRules; AExpectName: Boolean);
begin
  inherited Create(True);
  FreeOnTerminate:=False;
  FPerson:=APerson;
  FRules:=ARules;
  FExpectName:=AExpectName;
end;

procedure TRulesThread.Execute;
var
  I: Integer;
  JSON: TJSON;
begin
  try
    for I:=1 to 100 do
    begin
      JSON:=TJSON.Create;
      try
        JSON.LoadFromObject(FPerson, FRules);
        if FExpectName then
        begin
          if (not JSON.AsObject['Status'].IsString) or
            (JSON.AsObject['Status'].AsString <> 'done') then
            raise Exception.Create('name policy changed during operation');
        end
        else if (not JSON.AsObject['Status'].IsInteger) or
          (JSON.AsObject['Status'].AsInteger <> Ord(tsDone)) then
          raise Exception.Create('ordinal policy changed during operation');
      finally
        JSON.Free;
      end;
    end;
  except
    on E: Exception do
      FFailure:=E.ClassName + ': ' + E.Message;
  end;
end;

function NewTestChild: TObject;
begin
  Result:=TConstructedChild.Create;
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
  OriginalChild: TTestChild;
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
    OriginalChild:=Target.Child;

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
    Expect(Target.Child = OriginalChild, 'RTTI reuses existing child object');
  finally
    JSON.Free;
    Target.Free;
    Person.Free;
    TTJAXYDocument.SerializerRules:=TTJAXYDocument.DefaultSerializerRules;
  end;
end;

procedure TestRTTIErrorsAndNestedRecord;
var
  JSON: TJSON;
  Person: TTestPerson;
  Holder: TNestedHolder;
  Uninitialized: TUninitializedHolder;
  Rules: TTJAXYSerializerRules;
  Raised: Boolean;
begin
  Rules:=TTJAXYDocument.DefaultSerializerRules;
  Rules.EnumUnknownRead:=tjaxjurRaise;
  TTJAXYDocument.SerializerRules:=Rules;
  Person:=TTestPerson.Create;
  JSON:=TJSON.FromString('{"Status":"unknown"}');
  try
    Raised:=False;
    try JSON.AssignToObject(Person);
    except on E: ETJAXYException do Raised:=Pos('Status', E.Message) > 0; end;
    Expect(Raised, 'RTTI unknown enum raise reaches caller with member name');
  finally
    JSON.Free;
    Person.Free;
    TTJAXYDocument.SerializerRules:=TTJAXYDocument.DefaultSerializerRules;
  end;

  Rules:=TTJAXYDocument.DefaultSerializerRules;
  Rules.EnumAcceptOrdinalOnRead:=True;
  Rules.EnumUnknownRead:=tjaxjurRaise;
  Person:=TTestPerson.Create;
  try
    JSON:=TJSON.FromString('{"Status":1}');
    try
      JSON.AssignToObject(Person, Rules);
      Expect(Person.Status = tsDone, 'RTTI valid enum ordinal assigned');
    finally
      JSON.Free;
    end;
    JSON:=TJSON.FromString('{"Status":4294967297}');
    try
      Raised:=False;
      try JSON.AssignToObject(Person, Rules);
      except on E: ETJAXYException do Raised:=Pos('Status', E.Message) > 0; end;
      Expect(Raised, 'RTTI large enum ordinal rejected without truncation');
      Expect(Person.Status = tsDone, 'RTTI invalid enum leaves member unchanged');
    finally
      JSON.Free;
    end;
  finally
    Person.Free;
  end;

  Holder:=TNestedHolder.Create;
  Holder.Inner.Count:=9;
  JSON:=TJSON.FromString('{"Inner":{"Count":42,"Name":"nested"}}');
  try
    JSON.AssignToObject(Holder);
    ExpectEqInt(42, Holder.Inner.Count, 'RTTI nested record integer assigned');
    ExpectEqString('nested', Holder.Inner.Name, 'RTTI nested record string assigned');
  finally
    JSON.Free;
    Holder.Free;
  end;

  Uninitialized:=TUninitializedHolder.Create;
  JSON:=TJSON.FromString('{"Child":{}}');
  try
    Raised:=False;
    try JSON.AssignToObject(Uninitialized);
    except on E: ETJAXYException do Raised:=Pos('Child', E.Message) > 0; end;
    Expect(Raised, 'RTTI missing child constructor fails explicitly');
    TTJAXYDocument.RegisterObjectFactory(TTestChild, NewTestChild);
    try
      JSON.AssignToObject(Uninitialized);
      Expect((Uninitialized.Child IS TConstructedChild) AND TConstructedChild(Uninitialized.Child).Initialized,
        'RTTI registered child factory runs constructor');
    finally
      TTJAXYDocument.UnregisterObjectFactory(TTestChild);
    end;
  finally
    JSON.Free;
    Uninitialized.Child.Free;
    Uninitialized.Free;
  end;
end;

procedure TestRTTIIgnoredEnumDiagnostics;
var
  Person: TTestPerson;
  Holder: TEnumHolder;
  RecordTarget: TStatusRecord;
  JSON: TJSON;
  Rules: TTJAXYSerializerRules;
  Diagnostics: TArray<TTJAXYMappingDiagnostic>;
begin
  Rules:=TTJAXYDocument.DefaultSerializerRules;
  Rules.EnumUnknownRead:=tjaxjurIgnore;
  Person:=TTestPerson.Create;
  try
    Person.Status:=tsDone;
    JSON:=TJSON.FromString('{"Status":"missing"}');
    try
      JSON.AssignToObject(Person, Rules, Diagnostics);
      Expect(Person.Status = tsDone, 'ignored enum keeps existing value');
      Expect((Length(Diagnostics) = 1) AND (Diagnostics[0].Path = 'Status'),
        'ignored enum returns structured member diagnostic');
    finally JSON.Free; end;
  finally Person.Free; end;

  Rules.EnumUnknownRead:=tjaxjurDefaultFirst;
  Person:=TTestPerson.Create;
  try
    Person.Status:=tsDone;
    JSON:=TJSON.FromString('{"Status":"missing"}');
    try
      JSON.AssignToObject(Person, Rules, Diagnostics);
      Expect(Person.Status = tsNew, 'unknown enum default-first policy assigns first value');
      Expect(Length(Diagnostics) = 0, 'default-first enum conversion has no ignored diagnostic');
    finally JSON.Free; end;
  finally Person.Free; end;
  Rules.EnumUnknownRead:=tjaxjurIgnore;

  RecordTarget.Status:=tsDone;
  JSON:=TJSON.FromString('{"Status":"missing"}');
  try
    JSON.AssignToRecord<TStatusRecord>(RecordTarget, Rules, Diagnostics);
    Expect(RecordTarget.Status = tsDone, 'ignored record enum keeps existing value');
    Expect((Length(Diagnostics) = 1) AND (Diagnostics[0].Path = 'Status'),
      'ignored record enum returns structured field diagnostic');
  finally JSON.Free; end;

  TTJAXYDocument.RegisterObjectFactory(TEnumChild, NewEnumChild);
  try
    Holder:=TEnumHolder.Create;
    try
      JSON:=TJSON.FromString('{"Child":{"Status":"missing"}}');
      try
        JSON.AssignToObject(Holder, Rules, Diagnostics);
        Expect(Holder.Child <> nil, 'registered nested enum child constructed');
        Expect((Length(Diagnostics) = 1) AND (Diagnostics[0].Path = 'Child.Status'),
          'nested ignored enum returns full member path');
      finally JSON.Free; end;
    finally Holder.Free; end;
  finally
    TTJAXYDocument.UnregisterObjectFactory(TEnumChild);
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

procedure TestRTTILargeSet;
var
  Source, Target: TSetHolder;
  JSON: TJSON;
begin
  Source:=TSetHolder.Create;
  Target:=TSetHolder.Create;
  try
    Source.Bits:=[sb31, sb63, sb70];
    JSON:=TJSON.CreateFromObject(Source);
    try
      Expect(JSON.AsObject['Bits'].IsArray, 'large set uses enum-name array');
      ExpectEqInt(3, JSON.AsObject['Bits'].AsArray.Count, 'large set keeps high bits');
      JSON.AssignToObject(Target);
      Expect(Target.Bits = Source.Bits, 'large set round-trips all bits');
    finally
      JSON.Free;
    end;
  finally
    Target.Free;
    Source.Free;
  end;
end;

procedure TestRTTISmallSetBounds;
var
  Holder: TSmallSetHolder;
  AnonymousHolder: TAnonymousSetHolder;
  JSON: TJSON;
  Raised: Boolean;
begin
  Holder:=TSmallSetHolder.Create;
  try
    JSON:=TJSON.FromString('{"Bits":2}');
    try
      JSON.AssignToObject(Holder);
      Expect(tsDone IN Holder.Bits, 'small numeric set accepts valid bit');
    finally JSON.Free; end;
    JSON:=TJSON.FromString('{"Bits":4}');
    try
      Raised:=False;
      try JSON.AssignToObject(Holder);
      except on E: ETJAXYException do Raised:=Pos('Bits', E.Message) > 0; end;
      Expect(Raised, 'small numeric set rejects bit outside enum range');
      Expect(tsDone IN Holder.Bits, 'invalid set input leaves target unchanged');
    finally JSON.Free; end;
  finally Holder.Free; end;
  AnonymousHolder:=TAnonymousSetHolder.Create;
  try
    JSON:=TJSON.FromString('{"Bits":2}');
    try
      Raised:=False;
      try JSON.AssignToObject(AnonymousHolder);
      except on E: ETJAXYException do Raised:=Pos('Bits', E.Message) > 0; end;
      Expect(Raised, 'anonymous set without complete RTTI fails explicitly');
    finally JSON.Free; end;
  finally AnonymousHolder.Free; end;
end;

procedure TestRTTIIntegerBounds;
var
  Person: TTestPerson;
  JSON: TJSON;
begin
  Person:=TTestPerson.Create;
  try
    Person.Age:=7;
    JSON:=TJSON.CreateFromString('{"Age":2147483648}');
    try
      try
        JSON.AssignToObject(Person);
        raise Exception.Create('32-bit integer overflow should fail');
      except
        on E: ETJAXYException do
          Expect(Pos('Age', E.Message) > 0, 'integer overflow reports member path');
      end;
      ExpectEqInt(7, Person.Age, 'integer overflow leaves member unchanged');
    finally
      JSON.Free;
    end;
    JSON:=TJSON.CreateFromString('{"Age":2.5}');
    try
      try
        JSON.AssignToObject(Person);
        raise Exception.Create('fractional integer conversion should fail');
      except
        on E: ETJAXYException do
          Expect(Pos('Age', E.Message) > 0, 'fractional integer reports member path');
      end;
    finally
      JSON.Free;
    end;
  finally
    Person.Free;
  end;
end;

procedure TestRTTIArrayBounds;
var
  Holder: TArrayBoundsHolder;
  JSON: TJSON;
  Raised: Boolean;
begin
  Holder:=TArrayBoundsHolder.Create;
  try
    JSON:=TJSON.FromString('{"Values":[1,2,3]}');
    try
      Raised:=False;
      try JSON.AssignToObject(Holder);
      except on E: ETJAXYException do Raised:=Pos('Values', E.Message) > 0; end;
      Expect(Raised, 'fixed array rejects excess elements with member path');
    finally JSON.Free; end;
    JSON:=TJSON.FromString('{"Children":[{}]}');
    try
      Raised:=False;
      try JSON.AssignToObject(Holder);
      except on E: ETJAXYException do Raised:=Pos('Children', E.Message) > 0; end;
      Expect(Raised, 'class array requires explicit ownership policy');
      Expect(Length(Holder.Children) = 0, 'rejected class array leaves target unchanged');
    finally JSON.Free; end;
  finally Holder.Free; end;
end;

procedure TestRTTIScalarBounds;
var
  Holder: TScalarBoundsHolder;
  JSON: TJSON;
  Raised: Boolean;

  procedure ExpectFieldFails(const AText, AField: String);
  begin
    JSON:=TJSON.FromString(AText);
    try
      Raised:=False;
      try JSON.AssignToObject(Holder);
      except on E: ETJAXYException do Raised:=Pos(AField, E.Message) > 0; end;
      Expect(Raised, AField + ' rejects out-of-range or truncated scalar');
    finally JSON.Free; end;
  end;

begin
  Holder:=TScalarBoundsHolder.Create;
  try
    ExpectFieldFails('{"Small":1e100}', 'Small');
    ExpectFieldFails('{"Count":2.5}', 'Count');
    ExpectFieldFails('{"Money":0.00001}', 'Money');
    ExpectFieldFails('{"Narrow":"' + #$4E2D + '"}', 'Narrow');
    ExpectFieldFails('{"Wide":"ab"}', 'Wide');
    JSON:=TJSON.FromString('{"Small":2.5,"Count":3,"Money":1.25,"Narrow":"A","Wide":"' + #$4E2D + '"}');
    try
      JSON.AssignToObject(Holder);
      Expect(Holder.Small = 2.5, 'Single accepts representable value');
      Expect(Holder.Count = 3, 'Comp accepts integral value');
      Expect(Holder.Money = 1.25, 'Currency accepts four-decimal value');
      Expect(Holder.Narrow = 'A', 'AnsiChar accepts representable character');
      Expect(Holder.Wide = #$4E2D, 'WideChar accepts one Unicode code unit');
    finally JSON.Free; end;
  finally Holder.Free; end;
end;

procedure TestRTTISetterFailure;
var
  Target: TThrowingSetter;
  ChildTarget: TRejectingChildHolder;
  JSON: TJSON;
  Raised: Boolean;
begin
  Target:=TThrowingSetter.Create;
  try
    JSON:=TJSON.FromString('{"Value":3}');
    try
      Raised:=False;
      try JSON.AssignToObject(Target);
      except on E: ETJAXYException do
        Raised:=(Pos('Value', E.Message) > 0) AND
          (Pos('setter refused', E.Message) > 0);
      end;
      Expect(Raised, 'setter exception reaches caller with member name');
    finally JSON.Free; end;
  finally Target.Free; end;

  TTJAXYDocument.RegisterObjectFactory(TTestChild, NewTrackedChild);
  try
    ChildTarget:=TRejectingChildHolder.Create;
    try
      JSON:=TJSON.FromString('{"Child":{}}');
      try
        Raised:=False;
        try JSON.AssignToObject(ChildTarget);
        except on E: ETJAXYException do Raised:=Pos('Child', E.Message) > 0; end;
        Expect(Raised, 'failed class setter reports member path');
        Expect(TTrackedChild.Alive = 0, 'factory object freed when setter rejects before storing');

        ChildTarget.CommitBeforeRaise:=True;
        Raised:=False;
        try JSON.AssignToObject(ChildTarget);
        except on E: ETJAXYException do Raised:=Pos('Child', E.Message) > 0; end;
        Expect(Raised, 'setter failure after storing still reports member path');
        Expect(TTrackedChild.Alive = 1, 'factory object remains owned by target after storing');
      finally JSON.Free; end;
    finally ChildTarget.Free; end;
    Expect(TTrackedChild.Alive = 0, 'target releases committed factory object');
  finally
    TTJAXYDocument.UnregisterObjectFactory(TTestChild);
  end;
end;

procedure TestRTTIUnsupportedAndNull;
var
  Person: TTestPerson;
  PreviousChild: TTestChild;
  JSON: TJSON;
begin
  Person:=TTestPerson.Create;
  try
    JSON:=TJSON.CreateFromString('{"Name":{}}');
    try
      try
        JSON.AssignToObject(Person);
        raise Exception.Create('object-to-string conversion should fail');
      except
        on E: ETJAXYException do
          Expect(Pos('Name', E.Message) > 0, 'unsupported conversion reports member path');
      end;
    finally
      JSON.Free;
    end;
    PreviousChild:=Person.Child;
    PreviousChild.Name:='borrowed';
    JSON:=TJSON.CreateFromString('{"Child":null}');
    try
      JSON.AssignToObject(Person);
      Expect(Person.Child = nil, 'null clears object reference');
      ExpectEqString('borrowed', PreviousChild.Name, 'null does not free caller-owned object');
    finally
      JSON.Free;
      if Person.Child = nil then
        PreviousChild.Free;
    end;
  finally
    Person.Free;
  end;
end;

procedure TestRTTIRecordNesting;
var
  JSON: TJSON;
  Outer: TRecordOuter;
  Holder: TRecordArrayHolder;
begin
  Outer.Inner.Count:=9;
  Outer.Inner.Name:='old';
  JSON:=TJSON.CreateFromString('{"Inner":{"Count":42,"Name":"nested"}}');
  try
    JSON.AssignToRecord<TRecordOuter>(Outer);
    ExpectEqInt(42, Outer.Inner.Count, 'record inside record converts integer');
    ExpectEqString('nested', Outer.Inner.Name, 'record inside record converts managed field');
  finally
    JSON.Free;
  end;

  Holder:=TRecordArrayHolder.Create;
  try
    JSON:=TJSON.CreateFromString('{"Items":[{"Count":42,"Name":"array"}]}');
    try
      JSON.AssignToObject(Holder);
      ExpectEqInt(1, Length(Holder.Items), 'record array length');
      ExpectEqInt(42, Holder.Items[0].Count, 'record inside array converts integer');
      ExpectEqString('array', Holder.Items[0].Name, 'record inside array converts managed field');
    finally
      JSON.Free;
    end;
  finally
    Holder.Free;
  end;
end;

procedure TestRTTICycles;
var
  Node: TCycleNode;
  Pair: TReferencePair;
  JSON: TJSON;
  Chain: array[0..65] of TCycleNode;
  I: Integer;
  CurrentObject: TTJAXYObject;
begin
  Node:=TCycleNode.Create;
  try
    Node.Child:=Node;
    try
      JSON:=TJSON.CreateFromObject(Node);
      JSON.Free;
      raise Exception.Create('object cycle should fail');
    except
      on E: ETJAXYException do
        Expect((Pos('Child', E.Message) > 0) and (Pos('cycle', LowerCase(E.Message)) > 0),
          'object cycle reports member path');
    end;
    Node.Child:=nil;
    Pair:=TReferencePair.Create;
    try
      Pair.Left:=Node;
      Pair.Right:=Node;
      JSON:=TJSON.CreateFromObject(Pair);
      try
        Expect(JSON.AsObject['Left'].IsObject and JSON.AsObject['Right'].IsObject,
          'repeated acyclic reference serializes twice');
      finally
        JSON.Free;
      end;
    finally
      Pair.Free;
    end;
  finally
    Node.Free;
  end;

  for I:=Low(Chain) to High(Chain) do
    Chain[I]:=TCycleNode.Create;
  try
    for I:=Low(Chain) to High(Chain) - 1 do
      Chain[I].Child:=Chain[I + 1];
    try
      JSON:=TJSON.CreateFromObject(Chain[0]);
      JSON.Free;
      raise Exception.Create('mapping depth limit should fail');
    except
      on E: ETJAXYException do
        Expect(Pos('64 nesting levels', E.Message) > 0, 'mapping depth limit reports error');
    end;
  finally
    for I:=Low(Chain) to High(Chain) do
      Chain[I].Free;
  end;

  Node:=TCycleNode.Create;
  JSON:=TJSON.CreateObjectRoot;
  try
    CurrentObject:=JSON.AsObject;
    for I:=1 to 65 do
      CurrentObject:=CurrentObject.AddObject('Child');
    try
      JSON.AssignToObject(Node);
      raise Exception.Create('assignment depth limit should fail');
    except
      on E: ETJAXYException do
        Expect(Pos('64 nesting levels', E.Message) > 0, 'assignment depth limit reports error');
    end;
  finally
    JSON.Free;
    Node.Free;
  end;
end;

procedure TestRTTIPerOperationRules;
var
  Person: TTestPerson;
  NameRules, OrdinalRules, BeforeRules: TTJAXYSerializerRules;
  NameThread, OrdinalThread: TRulesThread;
begin
  Person:=TTestPerson.Create;
  try
    Person.Status:=tsDone;
    BeforeRules:=TTJAXYDocument.SerializerRules;
    NameRules:=TTJAXYDocument.DefaultSerializerRules;
    NameRules.EnumMode:=tjaxjemName;
    NameRules.EnumNameCase:=tjaxyncLower;
    NameRules.EnumStripPrefixes:=['ts'];
    OrdinalRules:=TTJAXYDocument.DefaultSerializerRules;
    NameThread:=TRulesThread.Create(Person, NameRules, True);
    OrdinalThread:=TRulesThread.Create(Person, OrdinalRules, False);
    try
      NameThread.Start;
      OrdinalThread.Start;
      NameThread.WaitFor;
      OrdinalThread.WaitFor;
      Expect(NameThread.Failure = '', 'concurrent name policy remains independent', NameThread.Failure);
      Expect(OrdinalThread.Failure = '', 'concurrent ordinal policy remains independent', OrdinalThread.Failure);
      Expect(TTJAXYDocument.SerializerRules.EnumMode = BeforeRules.EnumMode,
        'per-operation rules restore global defaults');
    finally
      OrdinalThread.Free;
      NameThread.Free;
    end;
  finally
    Person.Free;
  end;
end;

procedure TestRTTIRecordRules;
var
  Source, Target: TStatusRecord;
  Rules: TTJAXYSerializerRules;
  JSON: TJSON;
begin
  Rules:=TTJAXYDocument.DefaultSerializerRules;
  Rules.EnumMode:=tjaxjemName;
  Rules.EnumNameCase:=tjaxyncLower;
  Rules.EnumStripPrefixes:=['ts'];
  Source.Status:=tsDone;
  Target.Status:=tsNew;
  JSON:=TJSON.CreateFromRecordWithRules<TStatusRecord>(Source, Rules);
  try
    ExpectEqString('done', JSON.AsObject['Status'].AsString, 'record serialization uses operation rules');
    JSON.AssignToRecord<TStatusRecord>(Target, Rules);
    Expect(Target.Status = tsDone, 'record assignment uses operation rules');
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
    Expect(TTJAXYDocument.MapperCapabilities = [tjaxymcObjects, tjaxymcRecords, tjaxymcFactories],
      'Delphi default mapper reports object, record, and factory capabilities');
    TestRTTIObjectMapping;
    TestRTTIRecordMapping;
    TestRTTILargeSet;
    TestRTTISmallSetBounds;
    TestRTTIIntegerBounds;
    TestRTTIArrayBounds;
    TestRTTIScalarBounds;
    TestRTTISetterFailure;
    TestRTTIUnsupportedAndNull;
    TestRTTIRecordNesting;
    TestRTTICycles;
    TestRTTIPerOperationRules;
    TestRTTIRecordRules;
    TestRTTIErrorsAndNestedRecord;
    TestRTTIIgnoredEnumDiagnostics;

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
