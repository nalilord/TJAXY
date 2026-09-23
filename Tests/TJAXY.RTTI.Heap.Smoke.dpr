program TJAXYRTTIHeapSmoke;

{$APPTYPE CONSOLE}
{$RTTI EXPLICIT METHODS([]) PROPERTIES([]) FIELDS([vcPublic])}

uses
  System.SysUtils, TJAXY.Core, TJAXY.JSON;

type
  THolder = class
  public
    Numbers: TArray<Integer>;
    Tags: TArray<String>;
  end;

var
  Holder: THolder;
  JSON, CopyJSON: TJSON;
  I: Integer;
  Failed: Boolean;
begin
  ReportMemoryLeaksOnShutdown:=True;
  for I:=1 to 1000 do
  begin
    Holder:=THolder.Create;
    try
      Holder.Numbers:=[7];
      JSON:=TJSON.CreateFromString('{"Numbers":[1,2.5]}');
      try
        Failed:=False;
        try
          JSON.AssignToObject(Holder);
        except
          on ETJAXYException do
            Failed:=True;
        end;
        if (not Failed) or (Length(Holder.Numbers) <> 1) or (Holder.Numbers[0] <> 7) then
          raise Exception.Create('Failed dynamic-array conversion changed target');
      finally
        JSON.Free;
      end;

      JSON:=TJSON.CreateFromString('{"Tags":["alpha","beta"]}');
      try
        JSON.AssignToObject(Holder);
        if (Length(Holder.Tags) <> 2) or (Holder.Tags[1] <> 'beta') then
          raise Exception.Create('Managed dynamic-array conversion failed');
      finally
        JSON.Free;
      end;
      CopyJSON:=TJSON.CreateFromObject(Holder);
      try
        if CopyJSON.AsObject['Tags'].AsArray.Count <> 2 then
          raise Exception.Create('Managed dynamic-array serialization failed');
      finally
        CopyJSON.Free;
      end;
    finally
      Holder.Free;
    end;
  end;
  Writeln('RTTI managed-array allocation smoke: PASS');
end.
