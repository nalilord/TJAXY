(******************************************************************************)
(*                                                                            *)
(*  TJAXY JSON Codec                                                          *)
(*                                                                            *)
(*  Version     : 0.10                                                        *)
(*  License     : BSD 2-Clause                                                *)
(*  Author      : NaliLord / TJAXY contributors                               *)
(*                                                                            *)
(*  This unit parses and writes JSON/JSON5 using the shared TJAXY DOM.        *)
(*                                                                            *)
(******************************************************************************)

unit TJAXY.JSON;

interface

uses
  SysUtils, Classes, Math, TJAXY.Core;

type
  TJSONExtension = (jeDefault, jeJSON5);
  TJSONStringWriteMode = (jswmReadable, jswmCondensed);

  EJSONException = class(Exception)
  private
    FLine: Integer;
    FColumn: Integer;
  public
    constructor Create(const AMessage: String; ALine, AColumn: Integer);
    property Line: Integer read FLine;
    property Column: Integer read FColumn;
  end;

  TJSON = class(TTJAXYParser)
  private
    FData: TStringStream;
    FExtension: TJSONExtension;
  public
    class function EncodeString(AString: String): String; static;
    class function CreateTemplate(AName: String): TTJAXYTemplate; static;
    class function Template(AName: String): TTJAXYTemplate; static;
    class function FromString(AJSON: String; AExtension: TJSONExtension = jeDefault): TJSON; static;
    class function FromFile(AFile: String; AExtension: TJSONExtension = jeDefault): TJSON; static;
    class function FromStream(AStream: TStream; AExtension: TJSONExtension = jeDefault): TJSON; static;
    constructor Create; override;
    class function CreateArrayRoot: TJSON; reintroduce; static;
    class function CreateObjectRoot: TJSON; reintroduce; static;
    constructor CreateFromObject(AObject: TObject); override;
    class function CreateFromRecord<T>(const ARecord: T): TJSON; static;
    class function CreateFromRecordWithRules<T>(const ARecord: T; const ARules: TTJAXYSerializerRules): TJSON; static;
    constructor CreateFromString(AJSON: String; AExtension: TJSONExtension = jeDefault);
    class function CreateFromFile(AFile: String; AExtension: TJSONExtension = jeDefault): TJSON; static;
    constructor CreateFromStream(AStream: TStream; AExtension: TJSONExtension = jeDefault);
    destructor Destroy; override;
    procedure Clear; override;
    procedure LoadFromFile(const AFileName: String); override;
    procedure LoadFromStream(AStream: TStream); override;
    procedure ReadFromString(const AValue: String); override;
    procedure SaveToFile(const AFileName: String); override;
    procedure SaveToStream(AStream: TStream); override;
    function WriteToString(AWriteMode: TTJAXYStringWriteMode = tjaxywmReadable): String; overload; override;
    function WriteToString(AWriteMode: TJSONStringWriteMode): String; reintroduce; overload; virtual;
    function WriteToFile(const AFileName: String; AWriteMode: TTJAXYStringWriteMode = tjaxywmReadable): String; overload; override;
    function WriteToFile(const AFileName: String; AWriteMode: TJSONStringWriteMode): String; reintroduce; overload; virtual;
    property Extension: TJSONExtension read FExtension write FExtension;
  end;

implementation

resourcestring
  RCS_JSON_PARSER_EXCEPTION = 'JSON Parser Exception at Line: %d Col: %d: %s';
  RCS_EXPECTED_VALUE = 'Expected JSON value';
  RCS_EXPECTED_CHAR = 'Expected "%s"';
  RCS_INVALID_CHARACTER = 'Invalid or unexpected character "%s"';
  RCS_INVALID_IDENTIFIER = 'Invalid JSON identifier';
  RCS_INVALID_NUMBER = 'Invalid JSON number';
  RCS_INVALID_STRING_ESCAPE = 'Invalid string escape';
  RCS_INVALID_UNICODE_ESCAPE = 'Invalid unicode escape';
  RCS_UNTERMINATED_STRING = 'Unterminated string';
  RCS_UNTERMINATED_COMMENT = 'Unterminated block comment';
  RCS_TRAILING_DATA = 'Unexpected trailing data';
  RCS_JSON5_REQUIRED = 'JSON5 feature "%s" is not enabled';

type
  TJSONParser = class
  private
    FText: String;
    FIndex: Integer;
    FLine: Integer;
    FColumn: Integer;
    FJSON5: Boolean;
    function Current: Char;
    function Eof: Boolean;
    function IsIdentifierChar(AChar: Char): Boolean;
    function IsIdentifierStart(AChar: Char): Boolean;
    function Peek(AOffset: Integer = 1): Char;
    function ReadIdentifier: String;
    function ReadNumber: TTJAXYValue;
    function ReadString(AQuote: Char): String;
    procedure Advance;
    procedure Error(const AMessage: String);
    procedure Expect(AChar: Char);
    procedure RequireJSON5(const AFeature: String);
    procedure SkipBlockComment;
    procedure SkipLineComment;
    procedure SkipWhite;
  public
    constructor Create(const AText: String; AJSON5: Boolean);
    function Parse: TTJAXYValue;
    function ParseArray: TTJAXYArray;
    function ParseObject: TTJAXYObject;
    function ParseValue: TTJAXYValue;
  end;

function JSONWriteModeToTJAXY(AWriteMode: TJSONStringWriteMode): TTJAXYStringWriteMode;
begin
  case AWriteMode of
    jswmReadable: Result:=tjaxywmReadable;
    jswmCondensed: Result:=tjaxywmCondensed;
  else
    Result:=tjaxywmReadable;
  end;
end;

function JSONFormatSettings: TFormatSettings;
begin
  Result:=FormatSettings;
  Result.DecimalSeparator:='.';
  Result.ThousandSeparator:=',';
end;

{ EJSONException }

constructor EJSONException.Create(const AMessage: String; ALine, AColumn: Integer);
begin
  FLine:=ALine;
  FColumn:=AColumn;
  inherited Create(Format(RCS_JSON_PARSER_EXCEPTION, [ALine, AColumn, AMessage]));
end;

{ TJSONParser }

constructor TJSONParser.Create(const AText: String; AJSON5: Boolean);
begin
  inherited Create;
  FText:=AText;
  FIndex:=1;
  FLine:=1;
  FColumn:=1;
  FJSON5:=AJSON5;
end;

procedure TJSONParser.Advance;
begin
  if Eof then
    Exit;

  if FText[FIndex] = #10 then
  begin
    Inc(FLine);
    FColumn:=1;
  end else
    Inc(FColumn);

  Inc(FIndex);
end;

function TJSONParser.Current: Char;
begin
  if Eof then
    Result:=#0
  else
    Result:=FText[FIndex];
end;

function TJSONParser.Eof: Boolean;
begin
  Result:=FIndex > Length(FText);
end;

procedure TJSONParser.Error(const AMessage: String);
begin
  raise EJSONException.Create(AMessage, FLine, FColumn);
end;

procedure TJSONParser.Expect(AChar: Char);
begin
  if Current <> AChar then
    Error(Format(RCS_EXPECTED_CHAR, [AChar]));
  Advance;
end;

function TJSONParser.IsIdentifierChar(AChar: Char): Boolean;
begin
  Result:=CharInSet(AChar, ['A'..'Z', 'a'..'z', '0'..'9', '_', '$']);
end;

function TJSONParser.IsIdentifierStart(AChar: Char): Boolean;
begin
  Result:=CharInSet(AChar, ['A'..'Z', 'a'..'z', '_', '$']);
end;

function TJSONParser.Parse: TTJAXYValue;
begin
  SkipWhite;
  Result:=ParseValue;
  SkipWhite;
  if NOT Eof then
  begin
    Result.Free;
    Error(RCS_TRAILING_DATA);
  end;
end;

function TJSONParser.ParseArray: TTJAXYArray;
var
  Value: TTJAXYValue;
begin
  Result:=TTJAXYArray.Create;
  try
    Expect('[');
    SkipWhite;

    if Current = ']' then
    begin
      Advance;
      Exit;
    end;

    while NOT Eof do
    begin
      SkipWhite;
      if (Current = ']') AND FJSON5 then
      begin
        Advance;
        Exit;
      end;

      Value:=ParseValue;
      Result.Insert(Result.Count, Value);
      SkipWhite;

      if Current = ',' then
      begin
        Advance;
        Continue;
      end;

      Expect(']');
      Exit;
    end;

    Error(RCS_EXPECTED_VALUE);
  except
    Result.Free;
    raise;
  end;
end;

function TJSONParser.ParseObject: TTJAXYObject;
var
  Key: String;
  Value: TTJAXYValue;
begin
  Result:=TTJAXYObject.Create;
  try
    Expect('{');
    SkipWhite;

    if Current = '}' then
    begin
      Advance;
      Exit;
    end;

    while NOT Eof do
    begin
      SkipWhite;
      if (Current = '}') AND FJSON5 then
      begin
        Advance;
        Exit;
      end;

      case Current of
        '"': Key:=ReadString('"');
        '''':
          begin
            RequireJSON5('single quoted strings');
            Key:=ReadString('''');
          end;
      else
        begin
          RequireJSON5('unquoted object keys');
          if NOT IsIdentifierStart(Current) then
            Error(RCS_INVALID_IDENTIFIER);
          Key:=ReadIdentifier;
        end;
      end;

      SkipWhite;
      Expect(':');
      SkipWhite;
      Value:=ParseValue;
      Result.Add(Key, Value);
      SkipWhite;

      if Current = ',' then
      begin
        Advance;
        Continue;
      end;

      Expect('}');
      Exit;
    end;

    Error(RCS_EXPECTED_VALUE);
  except
    Result.Free;
    raise;
  end;
end;

function TJSONParser.ParseValue: TTJAXYValue;
var
  Identifier: String;
begin
  Result:=nil;
  SkipWhite;

  case Current of
    '{': Result:=ParseObject;
    '[': Result:=ParseArray;
    '"': Result:=TTJAXYString.CreateFrom(ReadString('"'));
    '''':
      begin
        RequireJSON5('single quoted strings');
        Result:=TTJAXYString.CreateFrom(ReadString(''''));
      end;
    '-', '+', '0'..'9', '.': Result:=ReadNumber;
    't':
      begin
        Identifier:=ReadIdentifier;
        if Identifier = 'true' then
          Result:=TTJAXYBoolean.CreateFrom(True)
        else
          Error(RCS_INVALID_IDENTIFIER);
      end;
    'f':
      begin
        Identifier:=ReadIdentifier;
        if Identifier = 'false' then
          Result:=TTJAXYBoolean.CreateFrom(False)
        else
          Error(RCS_INVALID_IDENTIFIER);
      end;
    'n', 'N', 'I':
      begin
        Identifier:=ReadIdentifier;
        if Identifier = 'null' then
          Result:=TTJAXYNull.Create
        else if SameText(Identifier, 'NaN') then
        begin
          RequireJSON5('NaN');
          Result:=TTJAXYFloat.CreateFrom(NaN);
        end else
        if SameText(Identifier, 'Infinity') then
        begin
          RequireJSON5('Infinity');
          Result:=TTJAXYFloat.CreateFrom(Infinity);
        end else
          Error(RCS_INVALID_IDENTIFIER);
      end;
  else
    Error(RCS_EXPECTED_VALUE);
  end;

  if Result = nil then
  begin
    Error(RCS_EXPECTED_VALUE);
    Result:=TTJAXYNull.Create;
  end;
end;

function TJSONParser.Peek(AOffset: Integer): Char;
begin
  if FIndex + AOffset > Length(FText) then
    Result:=#0
  else
    Result:=FText[FIndex + AOffset];
end;

function TJSONParser.ReadIdentifier: String;
begin
  Result:='';
  if NOT IsIdentifierStart(Current) then
    Error(RCS_INVALID_IDENTIFIER);

  while NOT Eof AND IsIdentifierChar(Current) do
  begin
    Result:=Result + Current;
    Advance;
  end;
end;

function TJSONParser.ReadNumber: TTJAXYValue;
var
  S: String;
  I: Int64;
  U: UInt64;
  F: Extended;
  IsFloat: Boolean;
  Negative: Boolean;
begin
  S:='';
  IsFloat:=False;
  Negative:=False;

  if Current = '+' then
  begin
    RequireJSON5('leading plus sign');
    S:=S + Current;
    Advance;
  end else
  if Current = '-' then
  begin
    Negative:=True;
    S:=S + Current;
    Advance;
  end;

  if (Current = 'I') AND SameText(Copy(FText, FIndex, 8), 'Infinity') then
  begin
    RequireJSON5('Infinity');
    Inc(FIndex, 8);
    Inc(FColumn, 8);
    if S = '-' then
      Result:=TTJAXYFloat.CreateFrom(NegInfinity)
    else
      Result:=TTJAXYFloat.CreateFrom(Infinity);
    Exit;
  end;

  if (Current = '0') AND CharInSet(Peek, ['x', 'X']) then
  begin
    RequireJSON5('hex numbers');
    S:='$';
    Advance;
    Advance;
    while NOT Eof AND CharInSet(Current, ['0'..'9', 'a'..'f', 'A'..'F']) do
    begin
      S:=S + Current;
      Advance;
    end;
    if NOT TryStrToUInt64(S, U) then
      Error(RCS_INVALID_NUMBER);
    if Negative then
    begin
      if U > UInt64(High(Int64)) + 1 then
        Error(RCS_INVALID_NUMBER);
      if U = UInt64(High(Int64)) + 1 then
        I:=Low(Int64)
      else
        I:=-Int64(U);
    end
    else
    begin
      if U > UInt64(High(Int64)) then
        Error(RCS_INVALID_NUMBER);
      I:=Int64(U);
    end;
    Result:=TTJAXYInteger.CreateFrom(I);
    Exit;
  end;

  if Current = '.' then
  begin
    RequireJSON5('leading decimal point');
    IsFloat:=True;
    S:=S + '0';
  end
  else if Current = '0' then
  begin
    S:=S + Current;
    Advance;
    if CharInSet(Current, ['0'..'9']) then
      Error(RCS_INVALID_NUMBER);
  end
  else
  begin
    if NOT CharInSet(Current, ['1'..'9']) then
      Error(RCS_INVALID_NUMBER);
    while CharInSet(Current, ['0'..'9']) do
    begin
      S:=S + Current;
      Advance;
    end;
  end;

  if Current = '.' then
  begin
    IsFloat:=True;
    S:=S + Current;
    Advance;
    if NOT CharInSet(Current, ['0'..'9']) then
    begin
      RequireJSON5('trailing decimal point');
      S:=S + '0';
    end
    else
      while CharInSet(Current, ['0'..'9']) do
      begin
        S:=S + Current;
        Advance;
      end;
  end;

  if CharInSet(Current, ['e', 'E']) then
  begin
    IsFloat:=True;
    S:=S + Current;
    Advance;
    if CharInSet(Current, ['+', '-']) then
    begin
      S:=S + Current;
      Advance;
    end;
    if NOT CharInSet(Current, ['0'..'9']) then
      Error(RCS_INVALID_NUMBER);
    while CharInSet(Current, ['0'..'9']) do
    begin
      S:=S + Current;
      Advance;
    end;
  end;

  if IsFloat then
  begin
    if NOT TryStrToFloat(S, F, JSONFormatSettings) then
      Error(RCS_INVALID_NUMBER);
    Result:=TTJAXYFloat.CreateFrom(F);
  end else
  begin
    if NOT TryStrToInt64(S, I) then
      Error(RCS_INVALID_NUMBER);
    Result:=TTJAXYInteger.CreateFrom(I);
  end;
end;

function TJSONParser.ReadString(AQuote: Char): String;
var
  Hex: String;
  Code: Integer;
begin
  Result:='';
  Expect(AQuote);

  while NOT Eof do
  begin
    case Current of
      #0: Error(RCS_UNTERMINATED_STRING);
      #10, #13:
      begin
        if NOT FJSON5 then
          Error(RCS_UNTERMINATED_STRING);
        Result:=Result + Current;
        Advance;
      end;
      '\':
      begin
        Advance;
        case Current of
          '"', '\', '/': Result:=Result + Current;
          '''':
            begin
              RequireJSON5('single quote escape');
              Result:=Result + Current;
            end;
          'b': Result:=Result + #8;
          'f': Result:=Result + #12;
          'n': Result:=Result + #10;
          'r': Result:=Result + #13;
          't': Result:=Result + #9;
          #10:
            begin
              RequireJSON5('multiline strings');
              Advance;
              Continue;
            end;
          #13:
            begin
              RequireJSON5('multiline strings');
              Advance;
              if Current = #10 then
                Advance;
              Continue;
            end;
          'u':
            begin
              Advance;
              Hex:=Copy(FText, FIndex, 4);
              if (Length(Hex) < 4) OR NOT TryStrToInt('$' + Hex, Code) then
                Error(RCS_INVALID_UNICODE_ESCAPE);
              Result:=Result + Char(Code);
              Inc(FIndex, 4);
              Inc(FColumn, 4);
              Continue;
            end;
          'x':
            begin
              RequireJSON5('hex string escapes');
              Advance;
              Hex:=Copy(FText, FIndex, 2);
              if (Length(Hex) < 2) OR NOT TryStrToInt('$' + Hex, Code) then
                Error(RCS_INVALID_UNICODE_ESCAPE);
              Result:=Result + Char(Code);
              Inc(FIndex, 2);
              Inc(FColumn, 2);
              Continue;
            end;
        else
          Error(RCS_INVALID_STRING_ESCAPE);
        end;
        Advance;
      end;
    else
      if Ord(Current) < 32 then
        Error(RCS_INVALID_CHARACTER);
      if Current = AQuote then
      begin
        Advance;
        Exit;
      end;
      Result:=Result + Current;
      Advance;
    end;
  end;

  Error(RCS_UNTERMINATED_STRING);
end;

procedure TJSONParser.RequireJSON5(const AFeature: String);
begin
  if NOT FJSON5 then
    Error(Format(RCS_JSON5_REQUIRED, [AFeature]));
end;

procedure TJSONParser.SkipBlockComment;
begin
  RequireJSON5('block comments');
  Advance;
  Advance;

  while NOT Eof do
  begin
    if (Current = '*') AND (Peek = '/') then
    begin
      Advance;
      Advance;
      Exit;
    end;
    Advance;
  end;

  Error(RCS_UNTERMINATED_COMMENT);
end;

procedure TJSONParser.SkipLineComment;
begin
  RequireJSON5('line comments');
  while NOT Eof AND NOT CharInSet(Current, [#10, #13]) do
    Advance;
end;

procedure TJSONParser.SkipWhite;
begin
  while NOT Eof do
  begin
    case Current of
      #9, #10, #13, #32: Advance;
      '/':
        if Peek = '/' then
          SkipLineComment
        else if Peek = '*' then
          SkipBlockComment
        else
          Exit;
    else
      Exit;
    end;
  end;
end;

{ TJSON }

class function TJSON.EncodeString(AString: String): String;
begin
  Result:=TTJAXYWriter.EncodeString(AString);
  if (Length(Result) >= 2) AND (Result[1] = '"') then
    Result:=Copy(Result, 2, Length(Result) - 2);
end;

class function TJSON.CreateTemplate(AName: String): TTJAXYTemplate;
begin
  Result:=TTJAXY.CreateTemplate(AName);
end;

class function TJSON.Template(AName: String): TTJAXYTemplate;
begin
  Result:=TTJAXY.Template(AName);
end;

class function TJSON.FromFile(AFile: String; AExtension: TJSONExtension): TJSON;
begin
  Result:=TJSON.CreateFromFile(AFile, AExtension);
end;

class function TJSON.FromStream(AStream: TStream; AExtension: TJSONExtension): TJSON;
begin
  Result:=TJSON.CreateFromStream(AStream, AExtension);
end;

class function TJSON.FromString(AJSON: String; AExtension: TJSONExtension): TJSON;
begin
  Result:=TJSON.CreateFromString(AJSON, AExtension);
end;

constructor TJSON.Create;
begin
  inherited Create;
  FData:=TStringStream.Create('', TEncoding.UTF8, False);
  FExtension:=jeDefault;
end;

class function TJSON.CreateArrayRoot: TJSON;
begin
  Result:=TJSON.Create;
  Result.RootNewArray;
end;

class function TJSON.CreateObjectRoot: TJSON;
begin
  Result:=TJSON.Create;
  Result.RootNewObject;
end;

constructor TJSON.CreateFromObject(AObject: TObject);
begin
  Create;
  LoadFromObject(AObject);
end;

class function TJSON.CreateFromRecord<T>(const ARecord: T): TJSON;
var
  Doc: TTJAXY;
begin
  Doc:=TTJAXY.CreateFromRecord<T>(ARecord);
  try
    Result:=TJSON.CreateObjectRoot;
    try
      Result.Assign(Doc);
    except
      Result.Free;
      raise;
    end;
  finally
    Doc.Free;
  end;
end;

class function TJSON.CreateFromRecordWithRules<T>(const ARecord: T; const ARules: TTJAXYSerializerRules): TJSON;
var
  Doc: TTJAXY;
begin
  Doc:=TTJAXY.CreateFromRecordWithRules<T>(ARecord, ARules);
  try
    Result:=TJSON.CreateObjectRoot;
    try
      Result.Assign(Doc);
    except
      Result.Free;
      raise;
    end;
  finally
    Doc.Free;
  end;
end;

class function TJSON.CreateFromFile(AFile: String; AExtension: TJSONExtension): TJSON;
begin
  Result:=TJSON.Create;
  try
    Result.FExtension:=AExtension;
    Result.LoadFromFile(AFile);
  except
    Result.Free;
    raise;
  end;
end;

constructor TJSON.CreateFromStream(AStream: TStream; AExtension: TJSONExtension);
begin
  Create;
  FExtension:=AExtension;
  LoadFromStream(AStream);
end;

constructor TJSON.CreateFromString(AJSON: String; AExtension: TJSONExtension);
begin
  Create;
  FExtension:=AExtension;
  ReadFromString(AJSON);
end;

destructor TJSON.Destroy;
begin
  FreeAndNil(FData);
  inherited;
end;

procedure TJSON.Clear;
begin
  FData.Clear;
  inherited Clear;
end;

procedure TJSON.LoadFromFile(const AFileName: String);
var
  Stream: TFileStream;
begin
  Stream:=TFileStream.Create(AFileName, fmOpenRead OR fmShareDenyWrite);
  try
    LoadFromStream(Stream);
  finally
    Stream.Free;
  end;
end;

procedure TJSON.LoadFromStream(AStream: TStream);
begin
  ReadFromString(TJAXYReadUTF8(AStream));
end;

procedure TJSON.ReadFromString(const AValue: String);
var
  Parser: TJSONParser;
begin
  TJAXYRequireValidText(AValue);
  FData.Clear;
  FData.WriteString(AValue);
  FData.Position:=0;

  Parser:=TJSONParser.Create(AValue, FExtension = jeJSON5);
  try
    SetRoot(Parser.Parse);
  finally
    Parser.Free;
  end;
end;

procedure TJSON.SaveToFile(const AFileName: String);
begin
  WriteToFile(AFileName);
end;

procedure TJSON.SaveToStream(AStream: TStream);
begin
  TJAXYWriteUTF8(AStream, WriteToString(tjaxywmReadable));
end;

function TJSON.WriteToFile(const AFileName: String; AWriteMode: TTJAXYStringWriteMode): String;
var
  Stream: TFileStream;
begin
  Result:=WriteToString(AWriteMode);
  Stream:=TFileStream.Create(AFileName, fmCreate);
  try
    TJAXYWriteUTF8(Stream, Result);
  finally
    Stream.Free;
  end;
end;

function TJSON.WriteToFile(const AFileName: String; AWriteMode: TJSONStringWriteMode): String;
begin
  Result:=WriteToFile(AFileName, JSONWriteModeToTJAXY(AWriteMode));
end;

function TJSON.WriteToString(AWriteMode: TTJAXYStringWriteMode): String;
begin
  Result:=inherited WriteToString(AWriteMode);
end;

function TJSON.WriteToString(AWriteMode: TJSONStringWriteMode): String;
begin
  Result:=WriteToString(JSONWriteModeToTJAXY(AWriteMode));
end;

end.
