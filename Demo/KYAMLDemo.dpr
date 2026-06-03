program KYAMLDemo;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  TJAXY.YAML in '..\Source\TJAXY.YAML.pas';

procedure PrintSection(const ATitle: String);
begin
  Writeln;
  Writeln('== ', ATitle, ' ==');
end;

procedure AssertTrue(ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
    raise Exception.Create(AMessage);
end;

procedure DemoManualBuild;
var
  K: TYAML;
  Root, Metadata, Labels, Spec, Container: TYAMLObject;
  Containers: TYAMLArray;
begin
  PrintSection('Manual Build');

  K := TYAML.CreateObjectRoot;
  try
    K.Encoding := yeKYAML;
    K.WriteDocumentMarker := True;

    Root := K.AsObject;
    Root.Add('apiVersion', 'v1');
    Root.Add('kind', 'Pod');

    Metadata := Root.AddObject('metadata');
    Metadata.Add('name', 'my-pod');

    Labels := Metadata.AddObject('labels');
    Labels.Add('app', 'demo');

    Spec := Root.AddObject('spec');
    Containers := Spec.AddArray('containers');

    Container := Containers.AddObject;
    Container.Add('name', 'nginx');
    Container.Add('image', 'nginx:1.20');
    Container.AddArray('ports');

    Root.SetOrAdd('replicas', 1);
    Root.GetOrAdd('restartPolicy', 'Always');

    Writeln(K.WriteToString(ywmReadable));
    Writeln;
    Writeln('Condensed:');
    Writeln(K.WriteToString(ywmCondensed));

    AssertTrue(K.IsObject, 'Root must be an object');
    AssertTrue(Root['kind'].AsString = 'Pod', 'kind mismatch');
    AssertTrue(Containers.Count = 1, 'container count mismatch');
  finally
    K.Free;
  end;
end;

procedure DemoParse;
var
  K: TYAML;
  Containers: TYAMLArray;
begin
  PrintSection('Parse');

  K := TYAML.FromString(
    '--- {' +
    'apiVersion: "v1",' +
    'kind: "Pod",' +
    'replicas: 2,' +
    'ready: true,' +
    'ratio: 1.5,' +
    'metadata: {name: "parsed-pod"},' +
    'spec: {containers: [{name: "nginx", image: "nginx:1.20"}]}' +
    '}',
    yeKYAML
  );
  try
    Containers := K.AsObject['spec'].AsObject['containers'].AsArray;

    Writeln('kind       = ', K.AsObject['kind'].AsString);
    Writeln('replicas   = ', K.AsObject['replicas'].AsInteger);
    Writeln('ready      = ', BoolToStr(K.AsObject['ready'].AsBoolean, True));
    Writeln('ratio      = ', K.AsObject['ratio'].AsString);
    Writeln('image      = ', Containers[0].AsObject['image'].AsString);
    Writeln('round-trip = ', K.WriteToString(ywmCondensed));

    AssertTrue(K.AsObject['kind'].AsString = 'Pod', 'parsed kind mismatch');
    AssertTrue(K.AsObject['replicas'].AsInteger = 2, 'parsed replicas mismatch');
    AssertTrue(K.AsObject['ready'].AsBoolean, 'parsed ready mismatch');
    AssertTrue(Containers[0].AsObject['name'].AsString = 'nginx', 'parsed container mismatch');
  finally
    K.Free;
  end;
end;

procedure DemoYAMLParse;
var
  K: TYAML;
  Root: TYAMLObject;
  Containers: TYAMLArray;
  Ports: TYAMLArray;
begin
  PrintSection('YAML Parse');

  K := TYAML.FromString(
    '---' + sLineBreak +
    'apiVersion: v1' + sLineBreak +
    'kind: Pod' + sLineBreak +
    'metadata:' + sLineBreak +
    '  name: yaml-pod' + sLineBreak +
    '  labels:' + sLineBreak +
    '    app: demo' + sLineBreak +
    'spec:' + sLineBreak +
    '  containers:' + sLineBreak +
    '    - name: nginx' + sLineBreak +
    '      image: nginx:1.20' + sLineBreak +
    '      ports: [80, 443]' + sLineBreak +
    '      command:' + sLineBreak +
    '        - nginx' + sLineBreak +
    '        - -g' + sLineBreak +
    '        - daemon off;' + sLineBreak +
    '  restartPolicy: Always' + sLineBreak +
    'replicas: 2' + sLineBreak +
    'ready: true' + sLineBreak +
    'notes: |' + sLineBreak +
    '  first line' + sLineBreak +
    '  second line' + sLineBreak,
    yeYAML
  );
  try
    Root := K.AsObject;
    Containers := Root['spec'].AsObject['containers'].AsArray;
    Ports := Containers[0].AsObject['ports'].AsArray;

    Writeln('kind       = ', Root['kind'].AsString);
    Writeln('name       = ', Root['metadata'].AsObject['name'].AsString);
    Writeln('image      = ', Containers[0].AsObject['image'].AsString);
    Writeln('first port = ', Ports[0].AsInteger);
    Writeln('round-trip = ', K.WriteToString(ywmCondensed));

    AssertTrue(Root['apiVersion'].AsString = 'v1', 'YAML apiVersion mismatch');
    AssertTrue(Root['replicas'].AsInteger = 2, 'YAML replicas mismatch');
    AssertTrue(Root['ready'].AsBoolean, 'YAML ready mismatch');
    AssertTrue(Containers.Count = 1, 'YAML container count mismatch');
    AssertTrue(Ports[1].AsInteger = 443, 'YAML port mismatch');
  finally
    K.Free;
  end;
end;

procedure DemoYAMLReferences;
var
  K: TYAML;
  Root, Metadata: TYAMLObject;
begin
  PrintSection('YAML Anchors and Merge Keys');

  K := TYAML.FromString(
    'defaults: &defaults' + sLineBreak +
    '  labels:' + sLineBreak +
    '    app: demo' + sLineBreak +
    '  namespace: default' + sLineBreak +
    'metadata:' + sLineBreak +
    '  <<: *defaults' + sLineBreak +
    '  name: merged-pod' + sLineBreak +
    'copy: *defaults' + sLineBreak +
    'tagged: !str tagged value' + sLineBreak,
    yeYAML
  );
  try
    Root := K.AsObject;
    Metadata := Root['metadata'].AsObject;

    Writeln('metadata.name      = ', Metadata['name'].AsString);
    Writeln('metadata.namespace = ', Metadata['namespace'].AsString);
    Writeln('metadata.label.app = ', Metadata['labels'].AsObject['app'].AsString);
    Writeln('copy.namespace     = ', Root['copy'].AsObject['namespace'].AsString);

    AssertTrue(Metadata['namespace'].AsString = 'default', 'YAML merge namespace mismatch');
    AssertTrue(Metadata['labels'].AsObject['app'].AsString = 'demo', 'YAML merge labels mismatch');
    AssertTrue(Root['copy'].AsObject['namespace'].AsString = 'default', 'YAML alias object mismatch');
    AssertTrue(Root['tagged'].AsString = 'tagged value', 'YAML tag handling mismatch');
  finally
    K.Free;
  end;
end;

procedure DemoYAMLMultiDocument;
var
  K: TYAML;
begin
  PrintSection('YAML Multi-Document Stream');

  K := TYAML.FromString(
    '---' + sLineBreak +
    'kind: ConfigMap' + sLineBreak +
    'metadata:' + sLineBreak +
    '  name: first' + sLineBreak +
    '---' + sLineBreak +
    'kind: Secret' + sLineBreak +
    'metadata:' + sLineBreak +
    '  name: second' + sLineBreak,
    yeYAML
  );
  try
    Writeln('document count = ', K.DocumentCount);
    Writeln('root kind      = ', K.AsObject['kind'].AsString);
    Writeln('second kind    = ', K.DocumentAsObject(1)['kind'].AsString);

    AssertTrue(K.DocumentCount = 2, 'YAML document count mismatch');
    AssertTrue(K.AsObject['metadata'].AsObject['name'].AsString = 'first', 'YAML first document mismatch');
    AssertTrue(K.DocumentAsObject(1)['metadata'].AsObject['name'].AsString = 'second', 'YAML second document mismatch');
  finally
    K.Free;
  end;
end;

procedure ExpectReject(const AName, AInput: String);
var
  K: TYAML;
begin
  try
    K := TYAML.FromString(AInput, yeKYAML);
    try
      raise Exception.Create('Expected parser rejection for ' + AName);
    finally
      K.Free;
    end;
  except
    on E: EYAMLException do
      Writeln(AName, ' rejected at line ', E.Line, ', column ', E.Column, ': ', E.Message);
  end;
end;

procedure DemoRejects;
begin
  PrintSection('Rejected YAML Features');

  ExpectReject('block mapping', 'apiVersion: "v1"');
  ExpectReject('unquoted string value', '{kind: Pod}');
  ExpectReject('anchor', '{metadata: &m {name: "pod"}}');
  ExpectReject('alias', '{metadata: *m}');
  ExpectReject('tag', '{value: !str "x"}');
  ExpectReject('block scalar', '{script: | echo test}');
  ExpectReject('merge key', '{<<: {app: "demo"}}');
end;

begin
  try
    DemoManualBuild;
    DemoParse;
    DemoYAMLParse;
    DemoYAMLReferences;
    DemoYAMLMultiDocument;
    DemoRejects;
    Writeln;
    Writeln('YAML/KYAML demo completed successfully.');
  except
    on E: Exception do
    begin
      Writeln;
      Writeln('Demo failed: ', E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
end.
