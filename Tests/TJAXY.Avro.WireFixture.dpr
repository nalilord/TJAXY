program TJAXYAvroWireFixture;

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, TJAXY.Core, TJAXY.Avro;

var
  Avro: TAvro;
  Stream: TFileStream;
begin
  if ParamCount <> 2 then
    raise Exception.Create('Usage: TJAXY.Avro.WireFixture <write|read> <path>');
  if SameText(ParamStr(1), 'write') then
  begin
    Avro:=TAvro.CreateFromString('1', '"int"');
    try
      Avro.ContainerCodec:='deflate';
      Avro.SaveContainerToFile(ParamStr(2));
    finally
      Avro.Free;
    end;
  end
  else if SameText(ParamStr(1), 'read') then
  begin
    Avro:=TAvro.Create;
    Stream:=TFileStream.Create(ParamStr(2), fmOpenRead OR fmShareDenyWrite);
    try
      Avro.LoadContainerFromStream(Stream);
      if Avro.Root.AsInteger <> 1 then
        raise Exception.Create('Independent Avro fixture decoded to the wrong value');
    finally
      Stream.Free;
      Avro.Free;
    end;
  end
  else
    raise Exception.Create('Unknown operation');
end.
