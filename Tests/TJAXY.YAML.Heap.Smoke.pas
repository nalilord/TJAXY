program TJAXYYAMLHeapSmoke;

{$IFDEF FPC}
{$mode delphi}
{$ENDIF}

uses
  SysUtils, TJAXY.Core, TJAXY.YAML;

var
  Y, CopyY: TYAML;
  Base: TTJAXYParser;
  I: Integer;
  Options: TYAMLConfigurationOptions;
begin
  {$IFNDEF FPC}
  ReportMemoryLeaksOnShutdown:=True;
  {$ENDIF}
  Options:=TYAML.DefaultConfigurationOptions;
  Options.MaxNodes:=3;
  for I:=1 to 1000 do
  begin
    Y:=TYAML.FromString('---' + sLineBreak + 'first: {nested: [1, 2]}' + sLineBreak +
      '---' + sLineBreak + 'second: true' + sLineBreak, yeYAML);
    try
      Base:=Y;
      Y.AsObject['first'].AsObject.Add('native', I);
      Base.AsObject['first'].AsObject.Add('core', I);
      Y.AsObject['first'].AsObject.Delete('native');
      Base.AsObject['first'].AsObject['nested'].AsArray.Delete(0);
      CopyY:=TYAML.Create;
      try
        CopyY.Assign(Y);
        CopyY.RootNewArray.Add(I);
        CopyY.Clear;
      finally
        CopyY.Free;
      end;
      Base.RootNewObject.Add('replaced', I);
    finally
      Y.Free;
    end;
    try
      Y:=TYAML.FromConfigurationString('a: [1, 2]', Options);
      Y.Free;
      raise Exception.Create('configuration node-budget failure was accepted');
    except
      on EYAMLException do ;
    end;
  end;
  Writeln('YAML shared DOM allocation smoke: PASS');
end.
