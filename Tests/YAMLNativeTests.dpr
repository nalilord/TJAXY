program YAMLNativeTests;

{$APPTYPE CONSOLE}
{$RTTI EXPLICIT METHODS([]) PROPERTIES([vcPublic]) FIELDS([vcPublic])}

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  TJAXY.Core,
  TJAXY.YAML in '..\Source\TJAXY.YAML.pas';

type
  TTestConfig = class
  private
    FEnabled: Boolean;
    FName: String;
    FPorts: TArray<Integer>;
  public
    property Enabled: Boolean read FEnabled write FEnabled;
    property Name: String read FName write FName;
    property Ports: TArray<Integer> read FPorts write FPorts;
  end;

  TTestRecord = record
  public
    Name: String;
    Count: Integer;
  end;

  TReadOnlyNonSeekStream = class(TStream)
  private
    FBytes: TBytes;
    FPosition: Integer;
  public
    constructor Create(const ABytes: TBytes);
    function Read(var Buffer; Count: Longint): Longint; override;
    function Write(const Buffer; Count: Longint): Longint; override;
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;
  end;

constructor TReadOnlyNonSeekStream.Create(const ABytes: TBytes);
begin
  inherited Create;
  FBytes:=ABytes;
end;

function TReadOnlyNonSeekStream.Read(var Buffer; Count: Longint): Longint;
begin
  Result:=Length(FBytes) - FPosition;
  if Result > Count then
    Result:=Count;
  if Result > 3 then
    Result:=3;
  if Result > 0 then
  begin
    Move(FBytes[FPosition], Buffer, Result);
    Inc(FPosition, Result);
  end;
end;

function TReadOnlyNonSeekStream.Write(const Buffer; Count: Longint): Longint;
begin
  raise Exception.Create('Read-only stream');
end;

function TReadOnlyNonSeekStream.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
begin
  raise Exception.Create('Stream is not seekable');
end;

procedure AssertTrue(ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
    raise Exception.Create(AMessage);
end;

procedure AssertEquals(const AExpected, AActual, AMessage: String); overload;
begin
  if AExpected <> AActual then
    raise Exception.Create(AMessage + ': expected "' + AExpected + '", got "' + AActual + '"');
end;

procedure AssertEquals(AExpected, AActual: Int64; const AMessage: String); overload;
begin
  if AExpected <> AActual then
    raise Exception.Create(AMessage + ': expected ' + IntToStr(AExpected) + ', got ' + IntToStr(AActual));
end;

procedure ExpectRejectKYAML(const AInput, AMessage: String);
var
  Y: TYAML;
begin
  try
    Y := TYAML.FromString(AInput, yeKYAML);
    try
      raise Exception.Create(AMessage + ': expected KYAML rejection');
    finally
      Y.Free;
    end;
  except
    on EYAMLException do
      Exit;
  end;
end;

procedure ExpectRejectConfiguration(const AInput, AMessage: String);
var
  Y: TYAML;
begin
  Y:=nil;
  try
    try
      Y:=TYAML.FromConfigurationString(AInput);
      raise Exception.Create(AMessage + ': expected configuration rejection');
    except
      on EYAMLException do Exit;
    end;
  finally
    Y.Free;
  end;
end;

procedure TestConfigurationProfile;
var
  Y: TYAML;
  Options: TYAMLConfigurationOptions;
  Stream: TMemoryStream;
  NonSeek: TReadOnlyNonSeekStream;
  Bytes: TBytes;
  I: Integer;
  FlowText: String;
  FileName: String;
begin
  ExpectRejectConfiguration('- <<: {a: 1}', 'sequence merge key rejected');
  ExpectRejectConfiguration('<<: {a: 1}', 'root merge key rejected');
  ExpectRejectConfiguration('outer:' + #10 + '  <<: {a: 1}', 'nested merge key rejected');
  ExpectRejectConfiguration('{<<: {a: 1}}', 'flow merge key rejected');
  ExpectRejectConfiguration('- {<<: {a: 1}}', 'sequence flow merge key rejected');
  ExpectRejectConfiguration('- ? [a, b]' + #10 + '  : value', 'sequence complex key rejected');
  ExpectRejectConfiguration('? [a, b]' + #10 + ': value', 'root complex key rejected');
  ExpectRejectConfiguration('outer:' + #10 + '  ? [a, b]' + #10 + '  : value', 'nested complex key rejected');
  ExpectRejectConfiguration('{[a, b]: value}', 'flow complex key rejected');
  ExpectRejectConfiguration('a: &anchor 1', 'anchor rejected');
  ExpectRejectConfiguration('a: *anchor', 'alias rejected');
  ExpectRejectConfiguration('a: !!str 1', 'tag rejected');
  ExpectRejectConfiguration('%YAML 1.2' + #10 + '---' + #10 + 'a: 1', 'directive rejected');
  ExpectRejectConfiguration('---' + #10 + '---' + #10 + 'a: 1', 'explicit empty document counted');
  ExpectRejectConfiguration('"name"junk: yes', 'quoted key requires end of input');
  Y:=TYAML.FromConfigurationString('3rd_party: yes');
  try AssertEquals('yes', Y.AsObject['3rd_party'].AsString, 'plain string key may start with digit');
  finally Y.Free; end;
  Y:=TYAML.FromConfigurationString('nested: ' + #10 + '- - - []');
  try
    AssertTrue(Y.AsObject['nested'].AsArray[0].AsArray[0].AsArray[0].IsArray,
      'compact nested sequence preserves each array level');
  finally Y.Free; end;
  Y:=TYAML.FromConfigurationString('text: |' + #10 + '  before' + #10 + '  ---' + #10 + '  after');
  try AssertTrue(Pos('---', Y.AsObject['text'].AsString) > 0, 'literal marker remains content');
  finally Y.Free; end;
  Y:=TYAML.FromConfigurationString('text: |' + #10 + '  %hello');
  try AssertTrue(Pos('%hello', Y.AsObject['text'].AsString) > 0, 'literal directive remains content');
  finally Y.Free; end;
  Y:=TYAML.FromConfigurationString('text: "before' + #10 + '  ---' + #10 + '  %hello' + #10 + '  after"');
  try
    AssertTrue(Pos('---', Y.AsObject['text'].AsString) > 0, 'quoted marker remains content');
    AssertTrue(Pos('%hello', Y.AsObject['text'].AsString) > 0, 'quoted directive remains content');
  finally Y.Free; end;

  Options:=TYAML.DefaultConfigurationOptions;
  Options.MaxInputBytes:=4;
  Y:=TYAML.FromConfigurationString('a: 1', Options);
  Y.Free;
  try
    Y:=TYAML.FromConfigurationString('a: 12', Options);
    Y.Free;
    raise Exception.Create('custom input limit: expected rejection');
  except on EYAMLException do ; end;

  Options:=TYAML.DefaultConfigurationOptions;
  Options.MaxNodes:=3;
  Y:=TYAML.FromConfigurationString('a: 1', Options);
  Y.Free;
  try
    Y:=TYAML.FromConfigurationString('- a: 1', Options);
    Y.Free;
    raise Exception.Create('compact mapping node budget: expected rejection');
  except on EYAMLException do ; end;
  Options.MaxNodes:=4;
  Y:=TYAML.FromConfigurationString('- a: 1', Options);
  Y.Free;
  Y:=TYAML.FromConfigurationString('a: [1]', Options);
  Y.Free;
  Options.MaxNodes:=3;
  Y:=TYAML.FromConfigurationString('a:', Options);
  Y.Free;
  Y:=TYAML.FromConfigurationString('{a:}', Options);
  Y.Free;
  Y:=TYAML.FromConfigurationString('[1, 2]', Options);
  Y.Free;
  try
    Y:=TYAML.FromConfigurationString('a: [1]', Options);
    Y.Free;
    raise Exception.Create('mixed block-flow node budget: expected rejection');
  except on EYAMLException do ; end;
  Options.MaxNodes:=2;
  try
    Y:=TYAML.FromConfigurationString('a:', Options);
    Y.Free;
    raise Exception.Create('implicit null node budget: expected rejection');
  except on EYAMLException do ; end;
  try
    Y:=TYAML.FromConfigurationString('{a:}', Options);
    Y.Free;
    raise Exception.Create('flow implicit null node budget: expected rejection');
  except on EYAMLException do ; end;
  try
    Y:=TYAML.FromConfigurationString('[1, 2]', Options);
    Y.Free;
    raise Exception.Create('flow sequence node budget: expected rejection');
  except on EYAMLException do ; end;
  Options.MaxNodes:=3;
  try
    Y:=TYAML.FromConfigurationString('a: 1' + #10 + 'b: 2', Options);
    Y.Free;
    raise Exception.Create('custom node limit: expected rejection');
  except on EYAMLException do ; end;

  Options:=TYAML.DefaultConfigurationOptions;
  Options.MaxDepth:=1;
  Y:=TYAML.FromConfigurationString('{}', Options);
  Y.Free;
  try
    Y:=TYAML.FromConfigurationString('a: 1', Options);
    Y.Free;
    raise Exception.Create('mapping key depth limit: expected rejection');
  except on EYAMLException do ; end;
  try
    Y:=TYAML.FromConfigurationString('{a: 1}', Options);
    Y.Free;
    raise Exception.Create('flow mapping key depth limit: expected rejection');
  except on EYAMLException do ; end;
  Options.MaxDepth:=2;
  Y:=TYAML.FromConfigurationString('a: 1', Options);
  Y.Free;
  Y:=TYAML.FromConfigurationString('{a: 1}', Options);
  Y.Free;
  try
    Y:=TYAML.FromConfigurationString('- a: 1', Options);
    Y.Free;
    raise Exception.Create('compact mapping key depth limit: expected rejection');
  except on EYAMLException do ; end;
  try
    Y:=TYAML.FromConfigurationString('- - 1', Options);
    Y.Free;
    raise Exception.Create('compact nested sequence depth limit: expected rejection');
  except on EYAMLException do ; end;
  Options.MaxDepth:=3;
  Y:=TYAML.FromConfigurationString('- a: 1', Options);
  Y.Free;
  Y:=TYAML.FromConfigurationString('- - 1', Options);
  Y.Free;
  try
    Y:=TYAML.FromConfigurationString('a: {b: {c: 2}}', Options);
    Y.Free;
    raise Exception.Create('nested mapping depth limit: expected rejection');
  except on EYAMLException do ; end;

  FlowText:='{';
  for I:=1 to 10001 do
  begin
    if I > 1 then
      FlowText:=FlowText + ', ';
    FlowText:=FlowText + 'k' + IntToStr(I) + ': 1';
  end;
  FlowText:=FlowText + '}';
  ExpectRejectConfiguration(FlowText, '10,001 numeric flow entries exceed node limit');

  Stream:=TMemoryStream.Create;
  try
    Bytes:=TEncoding.UTF8.GetBytes('name: ' + #$20AC + #$4E2D);
    Stream.WriteBuffer(Bytes[0], Length(Bytes));
    Stream.Position:=0;
    Y:=TYAML.FromConfigurationStream(Stream);
    try AssertEquals(#$20AC + #$4E2D, Y.AsObject['name'].AsString, 'configuration stream preserves UTF-8');
    finally Y.Free; end;
  finally Stream.Free; end;

  Options:=TYAML.DefaultConfigurationOptions;
  Options.MaxInputBytes:=4;
  NonSeek:=TReadOnlyNonSeekStream.Create(TEncoding.UTF8.GetBytes('a: 1'));
  try
    Y:=TYAML.FromConfigurationStream(NonSeek, Options);
    try AssertEquals(1, Y.AsObject['a'].AsInteger, 'non-seekable configuration stream works');
    finally Y.Free; end;
  finally NonSeek.Free; end;
  NonSeek:=TReadOnlyNonSeekStream.Create(TEncoding.UTF8.GetBytes('a: 12'));
  try
    try
      Y:=TYAML.FromConfigurationStream(NonSeek, Options);
      Y.Free;
      raise Exception.Create('non-seekable input limit: expected rejection');
    except on EYAMLException do ; end;
  finally NonSeek.Free; end;

  Options:=TYAML.DefaultConfigurationOptions;
  Options.MaxInputBytes:=6;
  Y:=TYAML.FromConfigurationString('a: ' + #$20AC, Options);
  try AssertEquals(#$20AC, Y.AsObject['a'].AsString, 'multibyte input fits exact byte limit');
  finally Y.Free; end;
  Options.MaxInputBytes:=5;
  try
    Y:=TYAML.FromConfigurationString('a: ' + #$20AC, Options);
    Y.Free;
    raise Exception.Create('multibyte byte limit: expected rejection');
  except on EYAMLException do ; end;
  Y:=TYAML.FromConfigurationString(#$FEFF + '{}', Options);
  try AssertTrue(Y.Root.IsObject, 'leading BOM accepted at exact byte limit');
  finally Y.Free; end;
  Options.MaxInputBytes:=4;
  try
    Y:=TYAML.FromConfigurationString(#$FEFF + '{}', Options);
    Y.Free;
    raise Exception.Create('BOM byte budget: expected rejection');
  except on EYAMLException do ; end;

  FileName:=TPath.GetTempFileName;
  try
    TFile.WriteAllBytes(FileName, TEncoding.UTF8.GetBytes('a: 1'));
    Options.MaxInputBytes:=4;
    Y:=TYAML.FromConfigurationFile(FileName, Options);
    try AssertEquals(1, Y.AsObject['a'].AsInteger, 'configuration file respects byte limit');
    finally Y.Free; end;
    TFile.WriteAllBytes(FileName, TEncoding.UTF8.GetBytes('a: 12'));
    try
      Y:=TYAML.FromConfigurationFile(FileName, Options);
      Y.Free;
      raise Exception.Create('configuration file byte limit: expected rejection');
    except on EYAMLException do ; end;
  finally
    TFile.Delete(FileName);
  end;
end;

procedure TestDOMAndWriter;
var
  Y: TYAML;
  Root, Metadata, Container: TYAMLObject;
  Containers: TYAMLArray;
  Text: String;
begin
  Y := TYAML.CreateObjectRoot;
  try
    Y.WriteDocumentMarker := True;
    Root := Y.AsObject;
    Root.Add('apiVersion', 'v1');
    Root.Add('kind', 'Pod');
    Root.SetOrAdd('replicas', Int64(2));
    Metadata := Root.AddObject('metadata');
    Metadata.Add('name', 'native-test');
    Containers := Root.AddObject('spec').AddArray('containers');
    Container := Containers.AddObject;
    Container.Add('name', 'nginx');
    Container.Add('image', 'nginx:1.20');

    AssertTrue(Y.IsObject, 'root is object');
    AssertEquals('Pod', Root['kind'].AsString, 'DOM kind');
    AssertEquals(2, Root['replicas'].AsInteger, 'DOM replicas');
    AssertEquals('nginx:1.20', Containers[0].AsObject['image'].AsString, 'DOM container image');

    Text := Y.WriteToString(ywmCondensed);
    AssertTrue(Pos('--- ', Text) = 1, 'document marker written');
    AssertTrue(Pos('apiVersion:"v1"', Text) > 0, 'condensed output has apiVersion');
  finally
    Y.Free;
  end;
end;

procedure TestKYAMLStrict;
var
  Y: TYAML;
begin
  Y := TYAML.CreateFromString(
    '--- {apiVersion: "v1", kind: "Pod", replicas: 1, ready: true, spec: {containers: [{name: "nginx"}]}}',
    yeKYAML);
  try
    AssertEquals('Pod', Y.AsObject['kind'].AsString, 'KYAML kind');
    AssertEquals(1, Y.AsObject['replicas'].AsInteger, 'KYAML integer');
    AssertTrue(Y.AsObject['ready'].AsBoolean, 'KYAML boolean');
    AssertEquals('nginx', Y.AsObject['spec'].AsObject['containers'].AsArray[0].AsObject['name'].AsString,
      'KYAML nested array');
  finally
    Y.Free;
  end;

  ExpectRejectKYAML('kind: "Pod"', 'block mapping');
  ExpectRejectKYAML('{kind: Pod}', 'unquoted string value');
  ExpectRejectKYAML('{metadata: &m {name: "pod"}}', 'anchor');
  ExpectRejectKYAML('{metadata: *m}', 'alias');
  ExpectRejectKYAML('{value: !str "x"}', 'tag');
  ExpectRejectKYAML('{script: | echo test}', 'block scalar');
  ExpectRejectKYAML('{<<: {app: "demo"}}', 'merge key');
end;

procedure TestYAMLFeatures;
var
  Y: TYAML;
  Root, Metadata: TYAMLObject;
begin
  Y := TYAML.FromString(
    'defaults: &defaults' + sLineBreak +
    '  labels:' + sLineBreak +
    '    app: demo' + sLineBreak +
    '  namespace: default' + sLineBreak +
    'metadata:' + sLineBreak +
    '  <<: *defaults' + sLineBreak +
    '  name: merged-pod' + sLineBreak +
    'containers:' + sLineBreak +
    '  - name: nginx' + sLineBreak +
    '    ports: [80, 443]' + sLineBreak +
    'notes: |' + sLineBreak +
    '  first line' + sLineBreak +
    '  second line' + sLineBreak,
    yeYAML);
  try
    Root := Y.AsObject;
    Metadata := Root['metadata'].AsObject;
    AssertEquals('merged-pod', Metadata['name'].AsString, 'YAML mapping value');
    AssertEquals('default', Metadata['namespace'].AsString, 'YAML merge key');
    AssertEquals('demo', Metadata['labels'].AsObject['app'].AsString, 'YAML nested merge value');
    AssertEquals(443, Root['containers'].AsArray[0].AsObject['ports'].AsArray[1].AsInteger, 'YAML flow array');
    AssertTrue(Pos('first line', Root['notes'].AsString) > 0, 'YAML block scalar');
  finally
    Y.Free;
  end;
end;

procedure TestMultiDocumentAndStreamFactory;
var
  Stream: TStringStream;
  Y: TYAML;
begin
  Stream := TStringStream.Create(
    '---' + sLineBreak +
    'kind: ConfigMap' + sLineBreak +
    '---' + sLineBreak +
    'kind: Secret' + sLineBreak,
    TEncoding.UTF8);
  try
    Y := TYAML.FromStream(Stream, yeYAML);
    try
      AssertEquals(2, Y.DocumentCount, 'multi-document count');
      AssertEquals('ConfigMap', Y.AsObject['kind'].AsString, 'first document');
      AssertEquals('Secret', Y.DocumentAsObject(1)['kind'].AsString, 'second document');
    finally
      Y.Free;
    end;
  finally
    Stream.Free;
  end;
end;

procedure TestMultiDocumentDiagnostics;
var
  Y: TYAML;
begin
  Y:=nil;
  try
    try
      Y:=TYAML.FromString('---' + #10 + 'a: 1' + #10 + '---' + #10 + 'b: [1, 2', yeYAML);
      raise Exception.Create('second document syntax should fail');
    except
      on E: EYAMLException do
        AssertEquals(4, E.Line, 'second document error keeps original line');
    end;
  finally
    Y.Free;
  end;
end;

procedure TestTJAXYParserReference;
var
  Parser: TTJAXYParser;
  Text: String;
begin
  Parser:=TYAML.Create;
  try
    Parser.ReadFromString('--- {kind: "Pod", ready: true}');
    AssertEquals('Pod', Parser.Root.AsObject['kind'].AsString, 'YAML shared root object access works');
    AssertTrue(Parser.Root.AsObject['ready'].AsBoolean, 'YAML shared root boolean access works');
    Text:=Parser.WriteToString(tjaxywmCondensed);
    AssertTrue(Pos('kind:"Pod"', Text) > 0, 'YAML writes through TTJAXYParser reference');
    AssertTrue(Pos('ready:true', Text) > 0, 'YAML boolean writes through TTJAXYParser reference');
  finally
    Parser.Free;
  end;
end;

procedure TestSharedDOMMutations;
var
  Y, CopyY: TYAML;
  Base: TTJAXYParser;
  Config: TTestConfig;
  Text: String;
  I: Integer;
begin
  Y:=TYAML.FromString('---' + sLineBreak + 'inner:' + sLineBreak + '  count: 1' + sLineBreak +
    '---' + sLineBreak + 'name: second' + sLineBreak, yeYAML);
  try
    Base:=Y;
    AssertTrue(Pointer(Y.Root) = Pointer(Base.Root), 'YAML native and Core roots are identical');
    Y.AsObject['inner'].AsObject.Add('native', 2);
    AssertEquals(2, Base.AsObject['inner'].AsObject['native'].AsInteger,
      'nested native edit reaches Core view');
    Base.AsObject['inner'].AsObject.Add('core', 3);
    AssertEquals(3, Y.AsObject['inner'].AsObject['core'].AsInteger,
      'nested Core edit reaches native view');
    Text:=Y.WriteToString;
    AssertTrue(Pos('native: 2', Text) > 0, 'native edit reaches YAML writer');
    AssertTrue(Pos('core: 3', Text) > 0, 'Core edit reaches YAML writer');
    Y.DocumentAsObject(1).Add('extra', 'visible');
    AssertTrue(Pos('extra:', Y.WriteToString) > 0, 'second document edit reaches writer');

    CopyY:=TYAML.Create;
    try
      CopyY.Assign(Y);
      AssertEquals(2, CopyY.DocumentCount, 'Assign keeps YAML document count');
      AssertEquals(3, CopyY.AsObject['inner'].AsObject['core'].AsInteger,
        'Assign keeps nested Core edit');
      CopyY.Clear;
      AssertEquals(1, CopyY.DocumentCount, 'Clear leaves one null document');
      AssertTrue(CopyY.Root.IsNull, 'Clear replaces shared root');
      Base:=CopyY;
      Base.RootNewObject.Add('replaced', True);
      AssertTrue(CopyY.AsObject['replaced'].AsBoolean, 'Core root replacement reaches YAML');
    finally
      CopyY.Free;
    end;
  finally
    Y.Free;
  end;

  Y:=TYAML.CreateObjectRoot;
  Config:=TTestConfig.Create;
  try
    Base:=Y;
    Y.AsObject.Add('Name', 'first');
    Base.AsObject.SetOrAdd('Name', 'shared');
    Y.AssignToObject(Config);
    AssertEquals('shared', Config.Name, 'mapped object sees Core edit');
  finally
    Config.Free;
    Y.Free;
  end;

  for I:=1 to 200 do
  begin
    Y:=TYAML.FromString('---' + sLineBreak + 'a: 1' + sLineBreak +
      '---' + sLineBreak + 'b: 2' + sLineBreak, yeYAML);
    try
      Y.DocumentAsObject(1).SetOrAdd('b', I);
      Y.RootNewArray.Add(I);
      Y.Clear;
    finally
      Y.Free;
    end;
  end;
end;

procedure TestCoreTemplatesFromYAML;
var
  Template: TTJAXYTemplate;
  Doc: TTJAXY;
begin
  Template:=TYAML.CreateTemplate('yaml-template-test');
  Template
    .Add('name', tjaxyttName)
    .Add('kind', tjaxytString)
    .Add('enabled', tjaxytBoolean);

  Doc:=TYAML.Template('yaml-template-test').Fill(['Pod', True]);
  AssertEquals('yaml-template-test', Doc.AsObject['name'].AsString, 'YAML template name field');
  AssertEquals('Pod', Doc.AsObject['kind'].AsString, 'YAML template string field');
  AssertTrue(Doc.AsObject['enabled'].AsBoolean, 'YAML template boolean field');
end;

procedure TestCoreRTTIFromYAML;
var
  Config: TTestConfig;
  Target: TTestConfig;
  RecordValue: TTestRecord;
  RecordTarget: TTestRecord;
  Y: TYAML;
begin
  Config:=TTestConfig.Create;
  Target:=TTestConfig.Create;
  Y:=nil;
  try
    Config.Name:='service';
    Config.Enabled:=True;
    Config.Ports:=[80, 443];

    Y:=TYAML.CreateFromObject(Config);
    AssertEquals('service', Y.AsObject['Name'].AsString, 'YAML RTTI object string');
    AssertTrue(Y.AsObject['Enabled'].AsBoolean, 'YAML RTTI object boolean');
    AssertEquals(2, Y.AsObject['Ports'].AsArray.Count, 'YAML RTTI object array');

    Y.AssignToObject(Target);
    AssertEquals('service', Target.Name, 'YAML RTTI AssignToObject string');
    AssertTrue(Target.Enabled, 'YAML RTTI AssignToObject boolean');
    AssertEquals(443, Target.Ports[1], 'YAML RTTI AssignToObject array');
  finally
    Y.Free;
    Target.Free;
    Config.Free;
  end;

  RecordValue.Name:='record';
  RecordValue.Count:=3;
  RecordTarget.Name:='';
  RecordTarget.Count:=0;

  Y:=TYAML.CreateFromRecord<TTestRecord>(RecordValue);
  try
    AssertEquals('record', Y.AsObject['Name'].AsString, 'YAML RTTI record string');
    AssertEquals(3, Y.AsObject['Count'].AsInteger, 'YAML RTTI record integer');
    Y.AssignToRecord<TTestRecord>(RecordTarget);
    AssertEquals('record', RecordTarget.Name, 'YAML RTTI AssignToRecord string');
    AssertEquals(3, RecordTarget.Count, 'YAML RTTI AssignToRecord integer');
  finally
    Y.Free;
  end;
end;

procedure TestConfigurationUTF8IO;
var
  Source, Target: TYAML;
  Stream: TMemoryStream;
  Expected, Actual: TBytes;
  I: Integer;
const
  UnicodeValue = #$20AC + #$4E2D + #$D83D + #$DE00;
begin
  Source:=TYAML.FromConfigurationString('name: "' + UnicodeValue + '"');
  Stream:=TMemoryStream.Create;
  try
    AssertEquals(UnicodeValue, Source.AsObject['name'].AsString, 'configuration string preserves Unicode');
    Source.SaveToStream(Stream);
    Expected:=TEncoding.UTF8.GetBytes(Source.WriteToString);
    AssertEquals(Length(Expected), Stream.Size, 'YAML stream emits UTF-8 byte length');
    SetLength(Actual, Stream.Size);
    Stream.Position:=0;
    if Stream.Size > 0 then
      Stream.ReadBuffer(Actual[0], Stream.Size);
    for I:=0 to High(Expected) do
      AssertTrue(Expected[I] = Actual[I], 'YAML stream emits exact UTF-8 bytes');
    Stream.Position:=0;
    Target:=TYAML.Create;
    try
      Target.Encoding:=yeYAML;
      Target.LoadFromStream(Stream);
      AssertEquals(UnicodeValue, Target.AsObject['name'].AsString, 'YAML stream preserves Unicode');
    finally
      Target.Free;
    end;
  finally
    Stream.Free;
    Source.Free;
  end;
end;

begin
  try
    TestDOMAndWriter;
    TestKYAMLStrict;
    TestYAMLFeatures;
    TestMultiDocumentAndStreamFactory;
    TestMultiDocumentDiagnostics;
    TestTJAXYParserReference;
    TestSharedDOMMutations;
    TestCoreTemplatesFromYAML;
    TestCoreRTTIFromYAML;
    TestConfigurationUTF8IO;
    TestConfigurationProfile;
    Writeln('YAML native tests passed.');
  except
    on E: Exception do
    begin
      Writeln('YAML native tests failed: ', E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
end.
