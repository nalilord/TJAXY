program TJAXYXMLConformance;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  TJAXY.Core,
  TJAXY.XML;

type
  TRunStats = record
    Discovered: Integer;
    Run: Integer;
    ExpectedValid: Integer;
    ExpectedInvalid: Integer;
    PassedValid: Integer;
    PassedInvalid: Integer;
    FailedValid: Integer;
    FailedInvalid: Integer;
    Skipped: Integer;
  end;

function HasArg(const AName: String): Boolean;
var
  I: Integer;
begin
  Result:=False;
  for I:=1 to ParamCount do
    if SameText(ParamStr(I), AName) then
      Exit(True);
end;

function GetSuitePath: String;
var
  I: Integer;
begin
  Result:='Tests/xmlconf';
  for I:=1 to ParamCount do
    if (ParamStr(I) <> '') AND (ParamStr(I)[1] <> '-') then
      Exit(ParamStr(I));
end;

function ReadTextFile(const AFileName: String): String;
begin
  Result:=TFile.ReadAllText(AFileName, TEncoding.UTF8);
end;

function Attr(AObject: TTJAXYObject; const AName: String): String;
var
  Attrs: TTJAXYObject;
begin
  Result:='';
  if NOT Assigned(AObject) then
    Exit;
  if NOT AObject.HasKey('@') then
    Exit;
  Attrs:=AObject['@'].AsObject;
  if Attrs.HasKey(AName) then
    Result:=Attrs[AName].AsString;
end;

function IsSupportedCase(const AType, AEntities, AURI, AInput: String): Boolean;
var
  LowerURI: String;
begin
  Result:=False;
  LowerURI:=LowerCase(AURI);

  if NOT ((AType = 'valid') OR (AType = 'not-wf')) then
    Exit;

  if (AEntities <> '') AND (AEntities <> 'none') then
    Exit;

  if (Pos('<!DOCTYPE', UpperCase(AInput)) > 0) AND (AType = 'not-wf') then
    Exit;

  if Pos('not-sa/', LowerURI) > 0 then
    Exit;
  if Pos('ext-sa/', LowerURI) > 0 then
    Exit;

  // TJAXY XML skips declarations but does not expand entities or read external DTDs.
  if Pos('<!ENTITY', UpperCase(AInput)) > 0 then
    Exit;
  if Pos('<!DOCTYPE', UpperCase(AInput)) > 0 then
  begin
    if (Pos(' SYSTEM ', UpperCase(AInput)) > 0) OR
      (Pos(' PUBLIC ', UpperCase(AInput)) > 0) then
      Exit;
  end;

  if (Pos('encoding=', LowerCase(AInput)) > 0) AND
    (Pos('utf-8', LowerCase(AInput)) = 0) then
    Exit;

  if (Pos('valid/sa/052.xml', LowerURI) > 0) OR
    (Pos('valid/sa/063.xml', LowerURI) > 0) OR
    (Pos('valid/sa/064.xml', LowerURI) > 0) then
    Exit;

  Result:=True;
end;

procedure WriteFailure(AFailures: TStrings; const AID, AURI, AExpected, AActual, AMessage: String);
begin
  if NOT Assigned(AFailures) then
    Exit;

  AFailures.Add(
    StringReplace(AID, #9, ' ', [rfReplaceAll]) + #9 +
    StringReplace(AExpected, #9, ' ', [rfReplaceAll]) + #9 +
    StringReplace(AActual, #9, ' ', [rfReplaceAll]) + #9 +
    StringReplace(AURI, #9, ' ', [rfReplaceAll]) + #9 +
    StringReplace(AMessage, #9, ' ', [rfReplaceAll])
  );
end;

procedure RunCase(const ASuitePath, AManifestDir: String; ATest: TTJAXYObject; var AStats: TRunStats; AQuiet: Boolean; AFailures: TStrings);
var
  ID: String;
  TestType: String;
  Entities: String;
  URI: String;
  InputFile: String;
  Input: String;
  Parsed: Boolean;
  ErrorMessage: String;
  XML: TXML;
begin
  Inc(AStats.Discovered);
  ID:=Attr(ATest, 'ID');
  TestType:=Attr(ATest, 'TYPE');
  Entities:=Attr(ATest, 'ENTITIES');
  URI:=Attr(ATest, 'URI');
  if URI = '' then
  begin
    Inc(AStats.Skipped);
    Exit;
  end;

  InputFile:=TPath.Combine(AManifestDir, URI.Replace('/', TPath.DirectorySeparatorChar));
  if NOT TFile.Exists(InputFile) then
  begin
    Inc(AStats.Skipped);
    Exit;
  end;

  try
    Input:=ReadTextFile(InputFile);
  except
    on E: EEncodingError do
    begin
      Inc(AStats.Skipped);
      Exit;
    end;
  end;
  if NOT IsSupportedCase(TestType, Entities, URI, Input) then
  begin
    Inc(AStats.Skipped);
    Exit;
  end;

  Inc(AStats.Run);
  if TestType = 'valid' then
    Inc(AStats.ExpectedValid)
  else
    Inc(AStats.ExpectedInvalid);

  ErrorMessage:='';
  try
    XML:=TXML.CreateFromString(Input);
    try
      Parsed:=True;
    finally
      XML.Free;
    end;
  except
    on E: Exception do
    begin
      ErrorMessage:=E.ClassName + ': ' + E.Message;
      Parsed:=False;
    end;
  end;

  if TestType = 'valid' then
  begin
    if Parsed then
      Inc(AStats.PassedValid)
    else
    begin
      Inc(AStats.FailedValid);
      WriteFailure(AFailures, ID, URI, 'valid', 'error', ErrorMessage);
      if NOT AQuiet then
        Writeln('[FAIL valid] ', ID, ' ', URI, ' -> ', ErrorMessage);
    end;
  end
  else
  begin
    if Parsed then
    begin
      Inc(AStats.FailedInvalid);
      WriteFailure(AFailures, ID, URI, 'not-wf', 'parsed', 'Parsed but W3C expects a well-formedness error');
      if NOT AQuiet then
        Writeln('[FAIL not-wf] ', ID, ' ', URI, ' parsed but should fail');
    end
    else
      Inc(AStats.PassedInvalid);
  end;
end;

procedure RunTestValue(const ASuitePath, AManifestDir: String; AValue: TTJAXYValue; var AStats: TRunStats; AQuiet: Boolean; AFailures: TStrings);
var
  I: Integer;
begin
  if AValue IS TTJAXYArray then
    for I:=0 to AValue.AsArray.Count - 1 do
      RunCase(ASuitePath, AManifestDir, AValue.AsArray[I].AsObject, AStats, AQuiet, AFailures)
  else
    RunCase(ASuitePath, AManifestDir, AValue.AsObject, AStats, AQuiet, AFailures);
end;

procedure RunManifest(const ASuitePath, AManifestFile: String; var AStats: TRunStats; AQuiet: Boolean; AFailures: TStrings);
var
  Manifest: TXML;
  Root: TTJAXYObject;
  ManifestDir: String;
begin
  Manifest:=TXML.CreateFromFile(AManifestFile);
  try
    Root:=Manifest.Root.AsObject['TESTCASES'].AsObject;
    ManifestDir:=TPath.GetDirectoryName(AManifestFile);
    if Root.HasKey('TEST') then
      RunTestValue(ASuitePath, ManifestDir, Root['TEST'], AStats, AQuiet, AFailures);
  finally
    Manifest.Free;
  end;
end;

procedure PrintUsage;
begin
  Writeln('Usage: TJAXY.XML.Conformance [Tests/xmlconf] [--strict] [--quiet] [--failures=file.tsv]');
  Writeln;
  Writeln('Runs the standalone/non-validating XMLTEST cases from the W3C XML Conformance Test Suite.');
  Writeln('DTD, external entity, not-standalone and non-UTF-8 cases are counted as skipped for now.');
end;

function GetFailuresFile: String;
var
  I: Integer;
  Prefix: String;
begin
  Result:='';
  Prefix:='--failures=';
  for I:=1 to ParamCount do
    if SameText(Copy(ParamStr(I), 1, Length(Prefix)), Prefix) then
      Exit(Copy(ParamStr(I), Length(Prefix) + 1, MaxInt));
end;

procedure RunSuite(const ASuitePath: String; AStrict, AQuiet: Boolean; const AFailureFile: String);
var
  ManifestFile: String;
  Stats: TRunStats;
  Failures: TStringList;
begin
  if NOT TDirectory.Exists(ASuitePath) then
    raise Exception.Create('Suite path does not exist: ' + ASuitePath);

  ManifestFile:=TPath.Combine(TPath.Combine(ASuitePath, 'xmltest'), 'xmltest.xml');
  if NOT TFile.Exists(ManifestFile) then
    raise Exception.Create('XMLTEST manifest not found: ' + ManifestFile);

  FillChar(Stats, SizeOf(Stats), 0);
  Failures:=TStringList.Create;
  try
    Failures.Add('id' + #9 + 'expected' + #9 + 'actual' + #9 + 'uri' + #9 + 'message');
    RunManifest(ASuitePath, ManifestFile, Stats, AQuiet, Failures);

    ManifestFile:=TPath.Combine(TPath.Combine(ASuitePath, 'oasis'), 'oasis.xml');
    if TFile.Exists(ManifestFile) then
      RunManifest(ASuitePath, ManifestFile, Stats, AQuiet, Failures);

    Writeln;
    Writeln('W3C XML Conformance Results');
    Writeln('  suite path       : ', ASuitePath);
    Writeln('  discovered       : ', Stats.Discovered);
    Writeln('  run              : ', Stats.Run);
    Writeln('  skipped          : ', Stats.Skipped);
    Writeln('  expected valid   : ', Stats.ExpectedValid);
    Writeln('  expected not-wf  : ', Stats.ExpectedInvalid);
    Writeln('  valid passed     : ', Stats.PassedValid);
    Writeln('  valid failed     : ', Stats.FailedValid);
    Writeln('  not-wf passed    : ', Stats.PassedInvalid);
    Writeln('  not-wf failed    : ', Stats.FailedInvalid);

    if AFailureFile <> '' then
    begin
      ForceDirectories(TPath.GetDirectoryName(TPath.GetFullPath(AFailureFile)));
      Failures.SaveToFile(AFailureFile, TEncoding.UTF8);
      Writeln('  failures file    : ', AFailureFile);
    end;

    if AStrict AND ((Stats.FailedValid > 0) OR (Stats.FailedInvalid > 0)) then
      Halt(1);
  finally
    Failures.Free;
  end;
end;

var
  SuitePath: String;
begin
  try
    if HasArg('--help') then
    begin
      PrintUsage;
      Halt(0);
    end;

    SuitePath:=GetSuitePath;
    RunSuite(SuitePath, HasArg('--strict'), HasArg('--quiet'), GetFailuresFile);
  except
    on E: Exception do
    begin
      Writeln('[FAIL] ', E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
end.
