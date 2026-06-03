program YAMLTestSuiteRunner;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  TJAXY.YAML in '..\Source\TJAXY.YAML.pas';

type
  TRunStats = record
    Total: Integer;
    ExpectedValid: Integer;
    ExpectedInvalid: Integer;
    PassedValid: Integer;
    PassedInvalid: Integer;
    FailedValid: Integer;
    FailedInvalid: Integer;
    Skipped: Integer;
  end;

function EscapeTSV(const AValue: String): String;
begin
  Result := AValue;
  Result := StringReplace(Result, #9, '\t', [rfReplaceAll]);
  Result := StringReplace(Result, #13, '\r', [rfReplaceAll]);
  Result := StringReplace(Result, #10, '\n', [rfReplaceAll]);
end;

function HasArg(const AName: String): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 1 to ParamCount do
    if SameText(ParamStr(I), AName) then
      Exit(True);
end;

function GetArgValue(const AName: String): String;
var
  I: Integer;
  Prefix: String;
begin
  Result := '';
  Prefix := AName + '=';
  for I := 1 to ParamCount do
  begin
    if SameText(ParamStr(I), AName) and (I < ParamCount) then
      Exit(ParamStr(I + 1));
    if SameText(Copy(ParamStr(I), 1, Length(Prefix)), Prefix) then
      Exit(Copy(ParamStr(I), Length(Prefix) + 1, MaxInt));
  end;
end;

function GetSuitePath: String;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to ParamCount do
    if (ParamStr(I) <> '') and (ParamStr(I)[1] <> '-') and
      ((I = 1) or not SameText(ParamStr(I - 1), '--failures')) then
      Exit(ParamStr(I));
end;

function CaseIdForDir(const ACaseDir: String): String;
begin
  Result := TPath.GetFileName(ACaseDir);
  if (Length(Result) = 2) and TDirectory.Exists(TPath.GetDirectoryName(ACaseDir)) then
    Result := TPath.GetFileName(TPath.GetDirectoryName(ACaseDir)) + '/' + Result;
end;

function FileExistsInDir(const ADir, AName: String): Boolean;
begin
  Result := TFile.Exists(TPath.Combine(ADir, AName));
end;

function ReadTextFile(const AFileName: String): String;
begin
  Result := TFile.ReadAllText(AFileName, TEncoding.UTF8);
end;

function DisplayNameForCase(const ACaseDir: String): String;
var
  NameFile: String;
begin
  Result := ACaseDir;
  NameFile := TPath.Combine(ACaseDir, '===');
  if TFile.Exists(NameFile) then
    Result := Trim(ReadTextFile(NameFile));
end;

procedure CollectCases(const ADir: String; ACases: TStrings);
var
  InFile: String;
  Dir: String;
begin
  InFile := TPath.Combine(ADir, 'in.yaml');
  if TFile.Exists(InFile) then
    ACases.Add(ADir);

  for Dir in TDirectory.GetDirectories(ADir) do
    CollectCases(Dir, ACases);
end;

procedure PrintUsage;
begin
  Writeln('Usage: YAMLTestSuiteRunner <yaml-test-suite-data-dir> [--strict] [--quiet] [--valid-only] [--invalid-only] [--failures <file.tsv>]');
  Writeln;
  Writeln('Expected input is the generated yaml-test-suite data layout, e.g. directories containing in.yaml and optional error files.');
  Writeln('Get it with: git clone --branch data-2022-01-17 --depth 1 https://github.com/yaml/yaml-test-suite.git yaml-test-suite-data');
  Writeln;
  Writeln('--strict exits with code 1 when any suite expectation fails.');
  Writeln('--failures writes TSV diagnostics for failed expectations.');
end;

procedure WriteFailure(AFailures: TStrings; const ACaseDir, AName, AExpected, AActual, AMessage: String);
begin
  if AFailures = nil then
    Exit;

  AFailures.Add(
    EscapeTSV(CaseIdForDir(ACaseDir)) + #9 +
    EscapeTSV(AExpected) + #9 +
    EscapeTSV(AActual) + #9 +
    EscapeTSV(AName) + #9 +
    EscapeTSV(ACaseDir) + #9 +
    EscapeTSV(AMessage)
  );
end;

procedure RunCase(const ACaseDir: String; var AStats: TRunStats; AQuiet, AValidOnly, AInvalidOnly: Boolean; AFailures: TStrings);
var
  InputFile: String;
  Input: String;
  ExpectedError: Boolean;
  Parsed: Boolean;
  Name: String;
  ErrorMessage: String;
  Y: TYAML;
begin
  ExpectedError := FileExistsInDir(ACaseDir, 'error');
  if AValidOnly and ExpectedError then
  begin
    Inc(AStats.Skipped);
    Exit;
  end;
  if AInvalidOnly and not ExpectedError then
  begin
    Inc(AStats.Skipped);
    Exit;
  end;

  Inc(AStats.Total);
  if ExpectedError then
    Inc(AStats.ExpectedInvalid)
  else
    Inc(AStats.ExpectedValid);

  InputFile := TPath.Combine(ACaseDir, 'in.yaml');
  Input := ReadTextFile(InputFile);
  Name := DisplayNameForCase(ACaseDir);
  ErrorMessage := '';

  try
    Y := TYAML.FromString(Input, yeYAML);
    try
      Parsed := True;
    finally
      Y.Free;
    end;
  except
    on E: Exception do
    begin
      Parsed := False;
      ErrorMessage := E.ClassName + ': ' + E.Message;
      if (not ExpectedError) and (not AQuiet) then
        Writeln('[FAIL valid] ', ACaseDir, ' - ', Name, ' -> ', ErrorMessage);
    end;
  end;

  if ExpectedError then
  begin
    if Parsed then
    begin
      Inc(AStats.FailedInvalid);
      WriteFailure(AFailures, ACaseDir, Name, 'invalid', 'parsed', 'Parsed but suite expects an error');
      if not AQuiet then
        Writeln('[FAIL invalid] ', ACaseDir, ' - ', Name, ' parsed but should fail');
    end
    else
      Inc(AStats.PassedInvalid);
  end
  else
  begin
    if Parsed then
      Inc(AStats.PassedValid)
    else
    begin
      Inc(AStats.FailedValid);
      WriteFailure(AFailures, ACaseDir, Name, 'valid', 'error', ErrorMessage);
    end;
  end;
end;

procedure RunSuite(const ASuitePath: String; AStrict, AQuiet, AValidOnly, AInvalidOnly: Boolean; const AFailureFile: String);
var
  Cases: TStringList;
  Failures: TStringList;
  Stats: TRunStats;
  CaseDir: String;
begin
  if not TDirectory.Exists(ASuitePath) then
    raise Exception.Create('Suite path does not exist: ' + ASuitePath);

  Cases := TStringList.Create;
  Failures := TStringList.Create;
  try
    Failures.Add('id' + #9 + 'expected' + #9 + 'actual' + #9 + 'name' + #9 + 'path' + #9 + 'message');
    Cases.Sorted := True;
    CollectCases(ASuitePath, Cases);
    if Cases.Count = 0 then
      raise Exception.Create('No in.yaml files found under: ' + ASuitePath);

    FillChar(Stats, SizeOf(Stats), 0);
    for CaseDir in Cases do
      RunCase(CaseDir, Stats, AQuiet, AValidOnly, AInvalidOnly, Failures);

    Writeln;
    Writeln('YAML Test Suite Results');
    Writeln('  total run        : ', Stats.Total);
    Writeln('  skipped          : ', Stats.Skipped);
    Writeln('  expected valid   : ', Stats.ExpectedValid);
    Writeln('  expected invalid : ', Stats.ExpectedInvalid);
    Writeln('  valid passed     : ', Stats.PassedValid);
    Writeln('  valid failed     : ', Stats.FailedValid);
    Writeln('  invalid passed   : ', Stats.PassedInvalid);
    Writeln('  invalid failed   : ', Stats.FailedInvalid);

    if AFailureFile <> '' then
    begin
      ForceDirectories(TPath.GetDirectoryName(TPath.GetFullPath(AFailureFile)));
      Failures.SaveToFile(AFailureFile, TEncoding.UTF8);
      Writeln('  failures file    : ', AFailureFile);
    end;

    if AStrict and ((Stats.FailedValid > 0) or (Stats.FailedInvalid > 0)) then
      Halt(1);
  finally
    Failures.Free;
    Cases.Free;
  end;
end;

var
  SuitePath: String;
begin
  try
    if (ParamCount = 0) or HasArg('--help') or HasArg('-h') then
    begin
      PrintUsage;
      Halt(0);
    end;

    SuitePath := GetSuitePath;
    if SuitePath = '' then
      raise Exception.Create('Missing yaml-test-suite data path');

    RunSuite(
      SuitePath,
      HasArg('--strict'),
      HasArg('--quiet'),
      HasArg('--valid-only'),
      HasArg('--invalid-only'),
      GetArgValue('--failures')
    );
  except
    on E: Exception do
    begin
      Writeln('Runner failed: ', E.ClassName, ': ', E.Message);
      Halt(2);
    end;
  end;
end.
