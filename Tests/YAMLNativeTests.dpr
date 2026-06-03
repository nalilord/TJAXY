program YAMLNativeTests;

{$APPTYPE CONSOLE}
{$RTTI EXPLICIT METHODS([]) PROPERTIES([vcPublic]) FIELDS([vcPublic])}

uses
  System.SysUtils,
  System.Classes,
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

begin
  try
    TestDOMAndWriter;
    TestKYAMLStrict;
    TestYAMLFeatures;
    TestMultiDocumentAndStreamFactory;
    TestTJAXYParserReference;
    TestCoreTemplatesFromYAML;
    TestCoreRTTIFromYAML;
    Writeln('YAML native tests passed.');
  except
    on E: Exception do
    begin
      Writeln('YAML native tests failed: ', E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
end.
