program TJAXYFPCSmoke;

{$MODE DELPHI}

uses SysUtils, Classes, TJAXY.Core, TJAXY.JSON, TJAXY.YAML;

type TConfig = class
public
  Name: String;
end;

type TRecordConfig = record
  Name: String;
end;

type TRegisteredMapper = class(TInterfacedObject, ITJAXYObjectMapper)
public
  function Capabilities: TTJAXYMapperCapabilities;
  function SerializeObject(AObject: TObject): TTJAXYValue;
  procedure AssignObject(AObject: TObject; ASource: TTJAXYObject);
  function SerializeRecord(ATypeInfo, ARecord: Pointer): TTJAXYValue;
  procedure AssignRecord(ATypeInfo, ARecord: Pointer; ASource: TTJAXYObject);
  procedure RegisterFactory(AClass: TClass; AFactory: TTJAXYObjectFactory);
  procedure UnregisterFactory(AClass: TClass);
end;

function TRegisteredMapper.Capabilities: TTJAXYMapperCapabilities;
begin
  Result:=[tjaxymcObjects];
end;

function TRegisteredMapper.SerializeObject(AObject: TObject): TTJAXYValue;
begin
  if NOT (AObject IS TConfig) then
    raise ETJAXYException.Create('Unsupported mapped class');
  Result:=TTJAXYObject.Create;
  try
    Result.AsObject.Add('Name', TConfig(AObject).Name);
  except
    Result.Free;
    raise;
  end;
end;

procedure TRegisteredMapper.AssignObject(AObject: TObject; ASource: TTJAXYObject);
begin
  if NOT (AObject IS TConfig) then
    raise ETJAXYException.Create('Unsupported mapped class');
  if ASource.HasKey('Name') then
    TConfig(AObject).Name:=ASource['Name'].AsString;
end;

function TRegisteredMapper.SerializeRecord(ATypeInfo, ARecord: Pointer): TTJAXYValue;
begin
  Result:=nil;
  raise ETJAXYException.Create('Record mapping unsupported');
end;

procedure TRegisteredMapper.AssignRecord(ATypeInfo, ARecord: Pointer; ASource: TTJAXYObject);
begin
  raise ETJAXYException.Create('Record mapping unsupported');
end;

procedure TRegisteredMapper.RegisterFactory(AClass: TClass; AFactory: TTJAXYObjectFactory);
begin
  raise ETJAXYException.Create('Factory registration unsupported');
end;

procedure TRegisteredMapper.UnregisterFactory(AClass: TClass);
begin
  raise ETJAXYException.Create('Factory registration unsupported');
end;

var
  YAML: TYAML;
  JSON: TJSON;
  Stream: TBytesStream;
  Data: TBytes;
  Target: TConfig;
  Raised: Boolean;
  RecordConfig: TRecordConfig;
  RawOutput: TMemoryStream;
begin
  RawOutput:=TMemoryStream.Create;
  try
    TJAXYWriteUTF8(RawOutput, '€中');
    if RawOutput.Size <> 6 then Halt(10);
    if (PByte(RawOutput.Memory)[0] <> $E2) or
      (PByte(RawOutput.Memory)[1] <> $82) or
      (PByte(RawOutput.Memory)[2] <> $AC) or
      (PByte(RawOutput.Memory)[3] <> $E4) or
      (PByte(RawOutput.Memory)[4] <> $B8) or
      (PByte(RawOutput.Memory)[5] <> $AD) then Halt(11);
  finally RawOutput.Free; end;
  JSON:=TJSON.FromString('{"name":"ok"}');
  try
    if JSON.AsObject['name'].AsString <> 'ok' then Halt(1);
  finally JSON.Free; end;

  Data:=TEncoding.UTF8.GetBytes('name: "€中"');
  Stream:=TBytesStream.Create(Data);
  try
    YAML:=TYAML.FromConfigurationStream(Stream);
    try
      if YAML.AsObject['name'].AsString <> '€中' then Halt(2);
    finally YAML.Free; end;
  finally Stream.Free; end;

  JSON:=TJSON.FromString('{"Name":"ok"}');
  Target:=TConfig.Create;
  try
    Raised:=False;
    try JSON.AssignToObject(Target);
    except on ETJAXYException do Raised:=True; end;
    if NOT Raised then Halt(3);
  finally Target.Free; JSON.Free; end;

  RecordConfig.Name:='record';
  Raised:=False;
  try
    JSON:=TJSON.CreateFromRecord<TRecordConfig>(RecordConfig);
    JSON.Free;
  except on ETJAXYException do Raised:=True; end;
  if NOT Raised then Halt(4);
  JSON:=TJSON.FromString('{"Name":"record"}');
  try
    Raised:=False;
    try JSON.AssignToRecord<TRecordConfig>(RecordConfig);
    except on ETJAXYException do Raised:=True; end;
    if NOT Raised then Halt(5);
  finally JSON.Free; end;
  if TTJAXYDocument.MapperCapabilities <> [] then Halt(6);
  TTJAXYDocument.Mapper:=TRegisteredMapper.Create;
  try
    if TTJAXYDocument.MapperCapabilities <> [tjaxymcObjects] then Halt(7);
    Target:=TConfig.Create;
    try
      Target.Name:='before';
      JSON:=TJSON.CreateFromObject(Target);
      try
        if JSON.AsObject['Name'].AsString <> 'before' then Halt(8);
      finally JSON.Free; end;
      JSON:=TJSON.FromString('{"Name":"after"}');
      try
        JSON.AssignToObject(Target);
        if Target.Name <> 'after' then Halt(9);
      finally JSON.Free; end;
    finally Target.Free; end;
  finally
    TTJAXYDocument.Mapper:=nil;
  end;
  Writeln('FPC Core/JSON/YAML smoke: PASS');
end.
