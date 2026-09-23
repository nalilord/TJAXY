(******************************************************************************)
(*                                                                            *)
(*  TJAXY TOML Codec                                                          *)
(*                                                                            *)
(*  Version     : 0.01                                                        *)
(*  License     : BSD 2-Clause                                                *)
(*  Author      : NaliLord / TJAXY contributors                               *)
(*                                                                            *)
(*  This unit parses and writes practical TOML using the shared TJAXY DOM.    *)
(*                                                                            *)
(******************************************************************************)

unit TJAXY.TOML;

interface

uses
  SysUtils, Classes, Math, TJAXY.Core;

type
  TTOMLStringWriteMode = (tomlwmReadable, tomlwmCondensed);

  ETOMLException = class(Exception);

  TTOML = class(TTJAXYParser)
  private
    FData: TStringStream;
  public
    class function CreateTemplate(AName: String): TTJAXYTemplate; static;
    class function Template(AName: String): TTJAXYTemplate; static;
    class function FromString(ATOML: String): TTOML; static;
    class function FromFile(AFile: String): TTOML; static;
    class function FromStream(AStream: TStream): TTOML; static;
    constructor Create; override;
    class function CreateArrayRoot: TTOML; reintroduce; static;
    class function CreateObjectRoot: TTOML; reintroduce; static;
    constructor CreateFromObject(AObject: TObject); override;
    class function CreateFromRecord<T>(const ARecord: T): TTOML; static;
    constructor CreateFromString(ATOML: String);
    class function CreateFromFile(AFile: String): TTOML; static;
    constructor CreateFromStream(AStream: TStream);
    destructor Destroy; override;
    procedure Clear; override;
    procedure LoadFromFile(const AFileName: String); override;
    procedure LoadFromStream(AStream: TStream); override;
    procedure ReadFromString(const AValue: String); override;
    procedure SaveToFile(const AFileName: String); override;
    procedure SaveToStream(AStream: TStream); override;
    function WriteToString(AWriteMode: TTJAXYStringWriteMode = tjaxywmReadable): String; overload; override;
    function WriteToString(AWriteMode: TTOMLStringWriteMode): String; reintroduce; overload; virtual;
    function WriteToFile(const AFileName: String; AWriteMode: TTJAXYStringWriteMode = tjaxywmReadable): String; overload; override;
    function WriteToFile(const AFileName: String; AWriteMode: TTOMLStringWriteMode): String; reintroduce; overload; virtual;
  end;

implementation

const
  TOML_LINE_FEED = #13#10;
  TOML_MULTILINE_BASIC = '"""';
  TOML_MULTILINE_LITERAL = #39#39#39;

function TJAXYWriteModeToTOML(AWriteMode: TTJAXYStringWriteMode): TTOMLStringWriteMode;
begin
  case AWriteMode of
    tjaxywmReadable: Result:=tomlwmReadable;
    tjaxywmCondensed: Result:=tomlwmCondensed;
  else
    Result:=tomlwmReadable;
  end;
end;

function TOMLFormatSettings: TFormatSettings;
begin
  Result:=TFormatSettings.Create('en-US');
  Result.DecimalSeparator:='.';
  Result.ThousandSeparator:=',';
end;

function TOMLEncodeString(const AValue: String): String;
var
  I: Integer;
begin
  Result:='"';
  for I:=1 to Length(AValue) do
    case AValue[I] of
      '\': Result:=Result + '\\';
      '"': Result:=Result + '\"';
      #8: Result:=Result + '\b';
      #9: Result:=Result + '\t';
      #10: Result:=Result + '\n';
      #12: Result:=Result + '\f';
      #13: Result:=Result + '\r';
    else
      Result:=Result + AValue[I];
    end;
  Result:=Result + '"';
end;

function TOMLIsBareKey(const AKey: String): Boolean;
var
  I: Integer;
begin
  Result:=AKey <> '';
  for I:=1 to Length(AKey) do
    if NOT CharInSet(AKey[I], ['A'..'Z', 'a'..'z', '0'..'9', '_', '-']) then
      Exit(False);
end;

function TOMLWriteKey(const AKey: String): String;
begin
  if TOMLIsBareKey(AKey) then
    Result:=AKey
  else
    Result:=TOMLEncodeString(AKey);
end;

function TOMLPathAppend(const APath, AKey: String): String;
begin
  if APath = '' then
    Result:=TOMLWriteKey(AKey)
  else
    Result:=APath + '.' + TOMLWriteKey(AKey);
end;

function TOMLStartsWithAt(const AValue, APrefix: String; AIndex: Integer): Boolean;
begin
  Result:=Copy(AValue, AIndex, Length(APrefix)) = APrefix;
end;

function TOMLHexCharToInt(AChar: Char): Integer;
begin
  if CharInSet(AChar, ['0'..'9']) then
    Result:=Ord(AChar) - Ord('0')
  else if CharInSet(AChar, ['A'..'F']) then
    Result:=Ord(AChar) - Ord('A') + 10
  else if CharInSet(AChar, ['a'..'f']) then
    Result:=Ord(AChar) - Ord('a') + 10
  else
    Result:=-1;
end;

function TOMLIsDigits(const AValue: String): Boolean;
var
  I: Integer;
begin
  Result:=AValue <> '';
  for I:=1 to Length(AValue) do
    if NOT CharInSet(AValue[I], ['0'..'9']) then
      Exit(False);
end;

function TOMLIsFixedDigits(const AValue: String; AStart, ACount: Integer): Boolean;
var
  I: Integer;
begin
  Result:=False;
  if AStart + ACount - 1 > Length(AValue) then
    Exit;
  for I:=AStart to AStart + ACount - 1 do
    if NOT CharInSet(AValue[I], ['0'..'9']) then
      Exit;
  Result:=True;
end;

function TOMLIntInRange(const AValue: String; AMin, AMax: Integer): Boolean;
var
  N: Integer;
begin
  Result:=TryStrToInt(AValue, N) AND (N >= AMin) AND (N <= AMax);
end;

function TOMLPreviousNonSpaceIndex(const AValue: String; AIndex: Integer): Integer;
begin
  Result:=AIndex;
  while (Result >= 1) AND CharInSet(AValue[Result], [#9, #10, #13, ' ']) do
    Dec(Result);
end;

function TOMLParseSpecialFloat(const AValue: String; out AResult: Extended): Boolean;
begin
  Result:=True;
  if (AValue = 'inf') OR (AValue = '+inf') then
    AResult:=Infinity
  else if AValue = '-inf' then
    AResult:=NegInfinity
  else if (AValue = 'nan') OR (AValue = '+nan') OR (AValue = '-nan') then
    AResult:=NaN
  else
    Result:=False;
end;

function TOMLIsLocalDateValue(const AValue: String): Boolean;
begin
  Result:=
    (Length(AValue) = 10) AND
    TOMLIsFixedDigits(AValue, 1, 4) AND
    (AValue[5] = '-') AND
    TOMLIsFixedDigits(AValue, 6, 2) AND
    (AValue[8] = '-') AND
    TOMLIsFixedDigits(AValue, 9, 2) AND
    TOMLIntInRange(Copy(AValue, 6, 2), 1, 12) AND
    TOMLIntInRange(Copy(AValue, 9, 2), 1, 31);
end;

function TOMLIsLocalTimeValue(const AValue: String; AAllowOffset: Boolean): Boolean;
var
  TimePart: String;
  OffsetPart: String;
  P: Integer;
begin
  TimePart:=AValue;
  OffsetPart:='';

  if AAllowOffset then
  begin
    if (Length(TimePart) > 0) AND (TimePart[Length(TimePart)] = 'Z') then
      Delete(TimePart, Length(TimePart), 1)
    else
    begin
      P:=Length(TimePart);
      while (P >= 1) AND NOT CharInSet(TimePart[P], ['+', '-']) do
        Dec(P);
      if P > 1 then
      begin
        OffsetPart:=Copy(TimePart, P, MaxInt);
        TimePart:=Copy(TimePart, 1, P - 1);
      end;
    end;
  end;

  Result:=False;
  if (Length(TimePart) < 5) OR
     (NOT TOMLIsFixedDigits(TimePart, 1, 2)) OR
     (TimePart[3] <> ':') OR
     (NOT TOMLIsFixedDigits(TimePart, 4, 2)) OR
     (NOT TOMLIntInRange(Copy(TimePart, 1, 2), 0, 23)) OR
     (NOT TOMLIntInRange(Copy(TimePart, 4, 2), 0, 59)) then
    Exit;

  if Length(TimePart) > 5 then
  begin
    if (Length(TimePart) < 8) OR (TimePart[6] <> ':') OR
       (NOT TOMLIsFixedDigits(TimePart, 7, 2)) OR
       (NOT TOMLIntInRange(Copy(TimePart, 7, 2), 0, 59)) then
      Exit;
    if Length(TimePart) > 8 then
    begin
      if (TimePart[9] <> '.') OR (NOT TOMLIsDigits(Copy(TimePart, 10, MaxInt))) then
        Exit;
    end;
  end;

  if OffsetPart <> '' then
  begin
    if (Length(OffsetPart) <> 6) OR
       (NOT CharInSet(OffsetPart[1], ['+', '-'])) OR
       (OffsetPart[4] <> ':') OR
       (NOT TOMLIsFixedDigits(OffsetPart, 2, 2)) OR
       (NOT TOMLIsFixedDigits(OffsetPart, 5, 2)) OR
       (NOT TOMLIntInRange(Copy(OffsetPart, 2, 2), 0, 23)) OR
       (NOT TOMLIntInRange(Copy(OffsetPart, 5, 2), 0, 59)) then
      Exit;
  end;

  Result:=True;
end;

function TOMLIsDateTimeValue(const AValue: String): Boolean;
var
  P: Integer;
begin
  Result:=False;
  if Length(AValue) < 16 then
    Exit;
  if NOT TOMLIsLocalDateValue(Copy(AValue, 1, 10)) then
    Exit;
  if NOT CharInSet(AValue[11], ['T', 't', ' ']) then
    Exit;
  P:=12;
  Result:=TOMLIsLocalTimeValue(Copy(AValue, P, MaxInt), True);
end;

function TOMLIsDateOrTimeValue(const AValue: String; out AKind: TTJAXYDateTimeKind): Boolean;
begin
  Result:=True;
  if TOMLIsLocalDateValue(AValue) then
    AKind:=tjaxydtkLocalDate
  else if TOMLIsLocalTimeValue(AValue, False) then
    AKind:=tjaxydtkLocalTime
  else if TOMLIsDateTimeValue(AValue) then
  begin
    if (Pos('Z', AValue) > 0) OR (Pos('+', Copy(AValue, 12, MaxInt)) > 0) OR (Pos('-', Copy(AValue, 12, MaxInt)) > 0) then
      AKind:=tjaxydtkOffsetDateTime
    else
      AKind:=tjaxydtkLocalDateTime;
  end
  else
    Result:=False;
end;

function TOMLPartsPath(AParts: TStrings): String;
var
  I: Integer;
begin
  Result:='';
  for I:=0 to AParts.Count - 1 do
  begin
    if Result <> '' then
      Result:=Result + '.';
    Result:=Result + TOMLWriteKey(AParts[I]);
  end;
end;

type
  TTOMLParser = class
  private
    FLines: TStringList;
    FDefinedTables: TStringList;
    FArrayTablePaths: TStringList;
    FRoot: TTJAXYObject;
    FCurrent: TTJAXYObject;
    function ParseArray(const AValue: String): TTJAXYArray;
    function ParseInlineTable(const AValue: String): TTJAXYObject;
    function ParseInteger(const AValue: String; out AResult: Int64): Boolean;
    function ParseKeyPath(const AValue: String): TStringList;
    function ParseString(const AValue: String; var AIndex: Integer): String;
    function ParseValue(const AValue: String): TTJAXYValue;
    function StripComment(const ALine: String): String;
    function MultilineStringOpen(const AValue: String; out ADelimiter: String): Boolean;
    function MultilineStringClosed(const AValue, ADelimiter: String): Boolean;
    procedure AssignKeyValue(ATable: TTJAXYObject; const AKeyPath, AValue: String);
    procedure ParseTable(const ALine: String);
  public
    constructor Create(const AText: String);
    destructor Destroy; override;
    function Parse: TTJAXYObject;
  end;

  TTOMLWriter = class
  private
    FMode: TTOMLStringWriteMode;
    function Space: String;
    function WriteArray(AArray: TTJAXYArray): String;
    function WriteScalar(AValue: TTJAXYValue): String;
    procedure WriteObject(AObject: TTJAXYObject; const APath: String; ALines: TStrings);
  public
    constructor Create(AMode: TTOMLStringWriteMode);
    function Write(AValue: TTJAXYValue): String;
  end;

constructor TTOMLParser.Create(const AText: String);
begin
  inherited Create;
  FLines:=TStringList.Create;
  FLines.Text:=StringReplace(AText, #13#10, #10, [rfReplaceAll]);
  FDefinedTables:=TStringList.Create;
  FArrayTablePaths:=TStringList.Create;
  FRoot:=TTJAXYObject.Create;
  FCurrent:=FRoot;
end;

destructor TTOMLParser.Destroy;
begin
  FDefinedTables.Free;
  FArrayTablePaths.Free;
  FLines.Free;
  inherited;
end;

function TTOMLParser.ParseString(const AValue: String; var AIndex: Integer): String;
var
  Quote: Char;
  Delimiter: String;
  Multiline: Boolean;
  EscapeValue: String;
  EscapeLen: Integer;
  Code: Integer;
  HexDigit: Integer;
  J: Integer;
begin
  Result:='';
  Quote:=AValue[AIndex];
  Delimiter:=StringOfChar(Quote, 3);
  Multiline:=TOMLStartsWithAt(AValue, Delimiter, AIndex);
  if Multiline then
  begin
    Inc(AIndex, 3);
    if TOMLStartsWithAt(AValue, #13#10, AIndex) then
      Inc(AIndex, 2)
    else if TOMLStartsWithAt(AValue, #10, AIndex) then
      Inc(AIndex);
  end
  else
    Inc(AIndex);

  while AIndex <= Length(AValue) do
  begin
    if Multiline AND TOMLStartsWithAt(AValue, Delimiter, AIndex) then
    begin
      Inc(AIndex, 3);
      Exit;
    end;

    if (NOT Multiline) AND (AValue[AIndex] = Quote) then
    begin
      Inc(AIndex);
      Exit;
    end;

    if (Quote = '"') AND (AValue[AIndex] = '\') then
    begin
      Inc(AIndex);
      if AIndex > Length(AValue) then
        raise ETOMLException.Create('Unterminated TOML string escape');

      if Multiline AND CharInSet(AValue[AIndex], [#10, #13, ' ', #9]) then
      begin
        while (AIndex <= Length(AValue)) AND CharInSet(AValue[AIndex], [#10, #13, ' ', #9]) do
          Inc(AIndex);
        Continue;
      end;

      case AValue[AIndex] of
        'b': Result:=Result + #8;
        't': Result:=Result + #9;
        'n': Result:=Result + #10;
        'f': Result:=Result + #12;
        'r': Result:=Result + #13;
        'e': Result:=Result + #27;
        '"': Result:=Result + '"';
        '\': Result:=Result + '\';
        'x', 'u', 'U':
          begin
            case AValue[AIndex] of
              'x': EscapeLen:=2;
              'u': EscapeLen:=4;
            else
              EscapeLen:=8;
            end;
            if AIndex + EscapeLen > Length(AValue) then
              raise ETOMLException.Create('Invalid TOML unicode escape');
            EscapeValue:=Copy(AValue, AIndex + 1, EscapeLen);
            Code:=0;
            for J:=1 to Length(EscapeValue) do
            begin
              HexDigit:=TOMLHexCharToInt(EscapeValue[J]);
              if HexDigit < 0 then
                raise ETOMLException.Create('Invalid TOML unicode escape');
              Code:=(Code * 16) + HexDigit;
            end;
            if (Code < 0) OR (Code > $FFFF) then
              raise ETOMLException.Create('Unsupported TOML unicode escape');
            Result:=Result + Char(Code);
            Inc(AIndex, EscapeLen);
          end;
      else
        raise ETOMLException.Create('Invalid TOML string escape');
      end;
    end
    else
    begin
      if (NOT Multiline) AND CharInSet(AValue[AIndex], [#10, #13]) then
        raise ETOMLException.Create('Unterminated TOML string');
      Result:=Result + AValue[AIndex];
    end;
    Inc(AIndex);
  end;
  raise ETOMLException.Create('Unterminated TOML string');
end;

function TTOMLParser.StripComment(const ALine: String): String;
var
  I: Integer;
  Quote: Char;
  InString: Boolean;
  Multiline: Boolean;
begin
  InString:=False;
  Multiline:=False;
  Quote:=#0;
  I:=1;
  while I <= Length(ALine) do
  begin
    if InString then
    begin
      if Multiline AND TOMLStartsWithAt(ALine, StringOfChar(Quote, 3), I) then
      begin
        InString:=False;
        Inc(I, 2);
      end
      else if (NOT Multiline) AND (Quote = '"') AND (ALine[I] = '\') then
        Inc(I)
      else if (NOT Multiline) AND (ALine[I] = Quote) then
        InString:=False;
    end
    else if CharInSet(ALine[I], ['"', '''']) then
    begin
      InString:=True;
      Quote:=ALine[I];
      Multiline:=TOMLStartsWithAt(ALine, StringOfChar(Quote, 3), I);
      if Multiline then
        Inc(I, 2);
    end
    else if ALine[I] = '#' then
      Exit(Trim(Copy(ALine, 1, I - 1)));
    Inc(I);
  end;
  Result:=Trim(ALine);
end;

function TTOMLParser.MultilineStringOpen(const AValue: String; out ADelimiter: String): Boolean;
var
  S: String;
begin
  S:=Trim(AValue);
  Result:=False;
  ADelimiter:='';
  if TOMLStartsWithAt(S, TOML_MULTILINE_BASIC, 1) then
  begin
    ADelimiter:=TOML_MULTILINE_BASIC;
    Result:=True;
  end
  else if TOMLStartsWithAt(S, TOML_MULTILINE_LITERAL, 1) then
  begin
    ADelimiter:=TOML_MULTILINE_LITERAL;
    Result:=True;
  end;
end;

function TTOMLParser.MultilineStringClosed(const AValue, ADelimiter: String): Boolean;
begin
  Result:=Pos(ADelimiter, Copy(AValue, Length(ADelimiter) + 1, MaxInt)) > 0;
end;

function TTOMLParser.ParseKeyPath(const AValue: String): TStringList;
var
  I, Start: Integer;
  Part: String;
  Quoted: Boolean;
begin
  Result:=TStringList.Create;
  try
    I:=1;
    while I <= Length(AValue) do
    begin
      while (I <= Length(AValue)) AND CharInSet(AValue[I], [' ', #9]) do
        Inc(I);
      if I > Length(AValue) then
        Break;
      Quoted:=CharInSet(AValue[I], ['"', '''']);
      if Quoted then
      begin
        if TOMLStartsWithAt(AValue, StringOfChar(AValue[I], 3), I) then
          raise ETOMLException.Create('Multiline strings are invalid TOML keys');
        Part:=ParseString(AValue, I);
      end
      else
      begin
        Start:=I;
        while (I <= Length(AValue)) AND CharInSet(AValue[I], ['A'..'Z', 'a'..'z', '0'..'9', '_', '-']) do
          Inc(I);
        Part:=Copy(AValue, Start, I - Start);
        if Part = '' then
          raise ETOMLException.Create('Invalid TOML key');
      end;
      Result.Add(Part);
      while (I <= Length(AValue)) AND CharInSet(AValue[I], [' ', #9]) do
        Inc(I);
      if I <= Length(AValue) then
      begin
        if AValue[I] <> '.' then
          raise ETOMLException.Create('Invalid TOML dotted key');
        Inc(I);
        while (I <= Length(AValue)) AND CharInSet(AValue[I], [' ', #9]) do
          Inc(I);
        if I > Length(AValue) then
          raise ETOMLException.Create('Invalid TOML dotted key');
      end;
    end;
  except
    Result.Free;
    raise;
  end;
end;

function TTOMLParser.ParseArray(const AValue: String): TTJAXYArray;
var
  I, Start: Integer;
  Depth: Integer;
  Quote: Char;
  InString: Boolean;
  Part: String;
  LastWasComma: Boolean;
begin
  Result:=TTJAXYArray.Create;
  I:=2;
  Start:=I;
  Depth:=0;
  InString:=False;
  Quote:=#0;
  LastWasComma:=False;
  while I <= Length(AValue) do
  begin
    if InString then
    begin
      if (Quote = '"') AND (AValue[I] = '\') then
        Inc(I)
      else if AValue[I] = Quote then
        InString:=False;
    end
    else
    begin
      case AValue[I] of
        '"', '''':
          begin
            InString:=True;
            Quote:=AValue[I];
          end;
        '[', '{': Inc(Depth);
        ']':
          if Depth = 0 then
          begin
            Part:=Trim(Copy(AValue, Start, I - Start));
            if Part <> '' then
              Result.Insert(Result.Count, ParseValue(Part));
            if (Part = '') AND LastWasComma AND (Result.Count = 0) then
            begin
              Result.Free;
              raise ETOMLException.Create('Invalid empty TOML array item');
            end;
            if Trim(Copy(AValue, I + 1, MaxInt)) <> '' then
            begin
              Result.Free;
              raise ETOMLException.Create('Invalid trailing TOML array content');
            end;
            Exit;
          end
          else
            Dec(Depth);
        '}':
          if Depth > 0 then
            Dec(Depth);
        ',':
          if Depth = 0 then
          begin
            Part:=Trim(Copy(AValue, Start, I - Start));
            if Part = '' then
            begin
              Result.Free;
              raise ETOMLException.Create('Invalid empty TOML array item');
            end;
            Result.Insert(Result.Count, ParseValue(Part));
            Start:=I + 1;
            LastWasComma:=True;
          end;
      end;
    end;
    if (NOT InString) AND (AValue[I] <> ',') AND NOT CharInSet(AValue[I], [' ', #9, #10, #13]) then
      LastWasComma:=False;
    Inc(I);
  end;
  Result.Free;
  raise ETOMLException.Create('Unterminated TOML array');
end;

function TTOMLParser.ParseInlineTable(const AValue: String): TTJAXYObject;
var
  I, Start: Integer;
  Depth: Integer;
  Quote: Char;
  InString: Boolean;

  procedure AddPair(const APair: String);
  var
    EqPos: Integer;
  begin
    if Trim(APair) = '' then
      Exit;
    EqPos:=Pos('=', APair);
    if EqPos <= 0 then
      raise ETOMLException.Create('Invalid TOML inline table pair');
    AssignKeyValue(Result, Trim(Copy(APair, 1, EqPos - 1)), Trim(Copy(APair, EqPos + 1, MaxInt)));
  end;

begin
  Result:=TTJAXYObject.Create;
  I:=2;
  Start:=I;
  Depth:=0;
  InString:=False;
  Quote:=#0;
  try
    while I <= Length(AValue) do
    begin
      if InString then
      begin
        if (Quote = '"') AND (AValue[I] = '\') then
          Inc(I)
        else if AValue[I] = Quote then
          InString:=False;
      end
      else
      begin
        case AValue[I] of
          '"', '''':
            begin
              InString:=True;
              Quote:=AValue[I];
            end;
          '[', '{': Inc(Depth);
          ']':
            if Depth > 0 then
              Dec(Depth);
          '}':
            if Depth = 0 then
            begin
              if (Trim(Copy(AValue, Start, I - Start)) = '') AND
                 (TOMLPreviousNonSpaceIndex(AValue, I - 1) >= 1) AND
                 (AValue[TOMLPreviousNonSpaceIndex(AValue, I - 1)] = ',') then
                raise ETOMLException.Create('Trailing comma in TOML inline table');
              AddPair(Copy(AValue, Start, I - Start));
              if Trim(Copy(AValue, I + 1, MaxInt)) <> '' then
                raise ETOMLException.Create('Invalid trailing TOML inline table content');
              Exit;
            end
            else
              Dec(Depth);
          ',':
            if Depth = 0 then
            begin
              if Trim(Copy(AValue, Start, I - Start)) = '' then
                raise ETOMLException.Create('Invalid empty TOML inline table pair');
              AddPair(Copy(AValue, Start, I - Start));
              Start:=I + 1;
            end;
        end;
      end;
      Inc(I);
    end;
    raise ETOMLException.Create('Unterminated TOML inline table');
  except
    Result.Free;
    raise;
  end;
end;

function TTOMLParser.ParseInteger(const AValue: String; out AResult: Int64): Boolean;
var
  S: String;
  Negative: Boolean;
  Base: Integer;
  I: Integer;
  Digit: Integer;
  HasDigit: Boolean;
  LastUnderscore: Boolean;
begin
  Result:=False;
  AResult:=0;
  S:=Trim(AValue);
  if S = '' then
    Exit;

  Negative:=False;
  if CharInSet(S[1], ['+', '-']) then
  begin
    Negative:=S[1] = '-';
    Delete(S, 1, 1);
  end;

  Base:=10;
  if (Length(S) > 2) AND (S[1] = '0') AND CharInSet(S[2], ['x', 'X', 'o', 'O', 'b', 'B']) then
  begin
    if Negative then
      Exit;
    case S[2] of
      'x', 'X': Base:=16;
      'o', 'O': Base:=8;
      'b', 'B': Base:=2;
    end;
    Delete(S, 1, 2);
  end
  else if (Length(S) > 1) AND (S[1] = '0') AND (S[2] <> '_') then
    Exit;

  HasDigit:=False;
  LastUnderscore:=False;
  for I:=1 to Length(S) do
  begin
    if S[I] = '_' then
    begin
      if (NOT HasDigit) OR LastUnderscore then
        Exit;
      LastUnderscore:=True;
      Continue;
    end;

    case Base of
      2:
        if CharInSet(S[I], ['0', '1']) then
          Digit:=Ord(S[I]) - Ord('0')
        else
          Exit;
      8:
        if CharInSet(S[I], ['0'..'7']) then
          Digit:=Ord(S[I]) - Ord('0')
        else
          Exit;
      10:
        if CharInSet(S[I], ['0'..'9']) then
          Digit:=Ord(S[I]) - Ord('0')
        else
          Exit;
    else
      Digit:=TOMLHexCharToInt(S[I]);
      if Digit < 0 then
        Exit;
    end;

    AResult:=(AResult * Base) + Digit;
    HasDigit:=True;
    LastUnderscore:=False;
  end;

  if (NOT HasDigit) OR LastUnderscore then
    Exit;
  if Negative then
    AResult:=-AResult;
  Result:=True;
end;

function TTOMLParser.ParseValue(const AValue: String): TTJAXYValue;
var
  S: String;
  I: Integer;
  IntValue: Int64;
  FloatValue: Extended;
  DateTimeKind: TTJAXYDateTimeKind;
begin
  S:=Trim(AValue);
  if S = '' then
    raise ETOMLException.Create('Missing TOML value');

  if CharInSet(S[1], ['"', '''']) then
  begin
    I:=1;
    Result:=TTJAXYString.CreateFrom(ParseString(S, I));
    if Trim(Copy(S, I, MaxInt)) <> '' then
    begin
      Result.Free;
      raise ETOMLException.Create('Invalid trailing TOML string content');
    end;
  end
  else if S[1] = '[' then
    Result:=ParseArray(S)
  else if S[1] = '{' then
    Result:=ParseInlineTable(S)
  else if SameText(S, 'true') then
    Result:=TTJAXYBoolean.CreateFrom(True)
  else if SameText(S, 'false') then
    Result:=TTJAXYBoolean.CreateFrom(False)
  else if TOMLParseSpecialFloat(S, FloatValue) then
    Result:=TTJAXYFloat.CreateFrom(FloatValue)
  else if TOMLIsDateOrTimeValue(S, DateTimeKind) then
    Result:=TTJAXYDateTime.CreateFrom(S, DateTimeKind)
  else if ParseInteger(S, IntValue) then
    Result:=TTJAXYInteger.CreateFrom(IntValue)
  else if (Pos('.', S) > 0) OR (Pos('e', LowerCase(S)) > 0) then
  begin
    if NOT TryStrToFloat(StringReplace(S, '_', '', [rfReplaceAll]), FloatValue, TOMLFormatSettings) then
      raise ETOMLException.CreateFmt('Invalid TOML float "%s"', [S]);
    Result:=TTJAXYFloat.CreateFrom(FloatValue);
  end
  else
  begin
    raise ETOMLException.CreateFmt('Invalid TOML value "%s"', [S]);
  end;
end;

procedure TTOMLParser.AssignKeyValue(ATable: TTJAXYObject; const AKeyPath, AValue: String);
var
  Parts: TStringList;
  Obj: TTJAXYObject;
  I: Integer;
  Key: String;
begin
  Parts:=ParseKeyPath(AKeyPath);
  try
    if Parts.Count = 0 then
      raise ETOMLException.Create('Missing TOML key');
    Obj:=ATable;
    for I:=0 to Parts.Count - 2 do
    begin
      Key:=Parts[I];
      if Obj.HasKey(Key) then
      begin
        if NOT Obj[Key].IsObject then
          raise ETOMLException.CreateFmt('TOML key "%s" is not a table', [Key]);
        Obj:=Obj[Key].AsObject;
      end
      else
        Obj:=Obj.AddObject(Key);
    end;

    Key:=Parts[Parts.Count - 1];
    if Obj.HasKey(Key) then
      raise ETOMLException.CreateFmt('Duplicate TOML key "%s"', [Key]);
    Obj.Add(Key, ParseValue(AValue));
  finally
    Parts.Free;
  end;
end;

procedure TTOMLParser.ParseTable(const ALine: String);
var
  IsArrayTable: Boolean;
  Header: String;
  Path: String;
  Key: String;
  Parts: TStringList;
  Obj: TTJAXYObject;
  Arr: TTJAXYArray;
  I: Integer;
  TableIdentity: String;
begin
  IsArrayTable:=Copy(ALine, 1, 2) = '[[';
  if IsArrayTable then
    Header:=Trim(Copy(ALine, 3, Length(ALine) - 4))
  else
    Header:=Trim(Copy(ALine, 2, Length(ALine) - 2));

  Parts:=ParseKeyPath(Header);
  try
    if Parts.Count = 0 then
      raise ETOMLException.Create('Missing TOML table name');
    Path:=TOMLPartsPath(Parts);
    Obj:=FRoot;
    for I:=0 to Parts.Count - 2 do
    begin
      Key:=Parts[I];
      if Obj.HasKey(Key) then
      begin
        if Obj[Key].IsObject then
          Obj:=Obj[Key].AsObject
        else if Obj[Key].IsArray AND
          (FArrayTablePaths.IndexOf(IntToHex(NativeUInt(Obj), SizeOf(Pointer) * 2) + ':' + Key) >= 0) AND
          (Obj[Key].AsArray.Count > 0) then
          Obj:=Obj[Key].AsArray[Obj[Key].AsArray.Count - 1].AsObject
        else
          raise ETOMLException.CreateFmt('TOML key "%s" is not a table', [Key]);
      end
      else
        Obj:=Obj.AddObject(Key);
    end;

    Key:=Parts[Parts.Count - 1];
    TableIdentity:=IntToHex(NativeUInt(Obj), SizeOf(Pointer) * 2) + ':' + Key;
    if IsArrayTable then
    begin
      if Obj.HasKey(Key) AND Obj[Key].IsArray AND (FArrayTablePaths.IndexOf(TableIdentity) >= 0) then
        Arr:=Obj[Key].AsArray
      else if Obj.HasKey(Key) then
        raise ETOMLException.CreateFmt('TOML key "%s" is not an array of tables', [Key])
      else
      begin
        Arr:=Obj.AddArray(Key);
        FArrayTablePaths.Add(TableIdentity);
      end;
      FCurrent:=Arr.AddObject;
    end
    else
    begin
      if FDefinedTables.IndexOf(TableIdentity) >= 0 then
        raise ETOMLException.CreateFmt('Duplicate TOML table "%s"', [Path]);
      if Obj.HasKey(Key) then
      begin
        if NOT Obj[Key].IsObject then
          raise ETOMLException.CreateFmt('TOML key "%s" is not a table', [Key]);
        FCurrent:=Obj[Key].AsObject;
      end
      else
        FCurrent:=Obj.AddObject(Key);
      FDefinedTables.Add(TableIdentity);
    end;
  finally
    Parts.Free;
  end;
end;

function TTOMLParser.Parse: TTJAXYObject;
var
  I, EqPos: Integer;
  Line: String;
  ValueText: String;
  Delimiter: String;
begin
  I:=0;
  while I < FLines.Count do
  begin
    Line:=StripComment(FLines[I]);
    if Line = '' then
    begin
      Inc(I);
      Continue;
    end;
    if (Line[1] = '[') then
      ParseTable(Line)
    else
    begin
      EqPos:=Pos('=', Line);
      if EqPos <= 0 then
        raise ETOMLException.CreateFmt('Invalid TOML line %d', [I + 1]);
      ValueText:=Trim(Copy(Line, EqPos + 1, MaxInt));
      if MultilineStringOpen(ValueText, Delimiter) AND NOT MultilineStringClosed(ValueText, Delimiter) then
      begin
        while (I + 1) < FLines.Count do
        begin
          Inc(I);
          ValueText:=ValueText + #10 + FLines[I];
          if MultilineStringClosed(ValueText, Delimiter) then
            Break;
        end;
        if NOT MultilineStringClosed(ValueText, Delimiter) then
          raise ETOMLException.Create('Unterminated TOML string');
      end;
      AssignKeyValue(FCurrent, Trim(Copy(Line, 1, EqPos - 1)), ValueText);
    end;
    Inc(I);
  end;
  Result:=FRoot;
  FRoot:=nil;
end;

constructor TTOMLWriter.Create(AMode: TTOMLStringWriteMode);
begin
  inherited Create;
  FMode:=AMode;
end;

function TTOMLWriter.Space: String;
begin
  if FMode = tomlwmReadable then
    Result:=' '
  else
    Result:='';
end;

function TTOMLWriter.WriteArray(AArray: TTJAXYArray): String;
var
  I: Integer;
begin
  Result:='[';
  for I:=0 to AArray.Count - 1 do
  begin
    if I > 0 then
      Result:=Result + ',' + Space;
    if AArray[I].IsArray then
      Result:=Result + WriteArray(AArray[I].AsArray)
    else
      Result:=Result + WriteScalar(AArray[I]);
  end;
  Result:=Result + ']';
end;

function TTOMLWriter.WriteScalar(AValue: TTJAXYValue): String;
begin
  if (AValue = nil) OR AValue.IsNull then
    Result:='""'
  else if AValue IS TTJAXYDateTime then
    Result:=AValue.AsString
  else if AValue.IsString then
    Result:=TOMLEncodeString(AValue.AsString)
  else if AValue.IsInteger then
    Result:=IntToStr(AValue.AsInteger)
  else if AValue.IsFloat then
    Result:=FloatToStr(AValue.AsFloat, TOMLFormatSettings)
  else if AValue.IsBoolean then
    Result:=LowerCase(BoolToStr(AValue.AsBoolean, True))
  else if AValue.IsArray then
    Result:=WriteArray(AValue.AsArray)
  else
    Result:=TOMLEncodeString(AValue.AsString);
end;

procedure TTOMLWriter.WriteObject(AObject: TTJAXYObject; const APath: String; ALines: TStrings);
var
  I, J: Integer;
  V: TTJAXYValue;
  TablePath: String;
begin
  for I:=0 to AObject.Count - 1 do
  begin
    V:=AObject.Item[I];
    if V.IsObject then
      Continue;
    if V.IsArray then
    begin
      for J:=0 to V.AsArray.Count - 1 do
        if V.AsArray[J].IsObject then
          Break;
      if (V.AsArray.Count > 0) AND (J < V.AsArray.Count) then
        Continue;
    end;
    ALines.Add(TOMLWriteKey(AObject.Name[I]) + Space + '=' + Space + WriteScalar(V));
  end;

  for I:=0 to AObject.Count - 1 do
  begin
    V:=AObject.Item[I];
    TablePath:=TOMLPathAppend(APath, AObject.Name[I]);
    if V.IsObject then
    begin
      if ALines.Count > 0 then
        ALines.Add('');
      ALines.Add('[' + TablePath + ']');
      WriteObject(V.AsObject, TablePath, ALines);
    end
    else if V.IsArray then
      for J:=0 to V.AsArray.Count - 1 do
        if V.AsArray[J].IsObject then
        begin
          if ALines.Count > 0 then
            ALines.Add('');
          ALines.Add('[[' + TablePath + ']]');
          WriteObject(V.AsArray[J].AsObject, TablePath, ALines);
        end;
  end;
end;

function TTOMLWriter.Write(AValue: TTJAXYValue): String;
var
  Lines: TStringList;
begin
  if (AValue = nil) OR (NOT AValue.IsObject) then
    raise ETOMLException.Create('TOML root must be an object');
  Lines:=TStringList.Create;
  try
    WriteObject(AValue.AsObject, '', Lines);
    Result:=Lines.Text;
    while (Result <> '') AND CharInSet(Result[Length(Result)], [#10, #13]) do
      Delete(Result, Length(Result), 1);
  finally
    Lines.Free;
  end;
end;

{ TTOML }

class function TTOML.CreateTemplate(AName: String): TTJAXYTemplate;
begin
  Result:=TTJAXY.CreateTemplate(AName);
end;

class function TTOML.Template(AName: String): TTJAXYTemplate;
begin
  Result:=TTJAXY.Template(AName);
end;

class function TTOML.FromFile(AFile: String): TTOML;
begin
  Result:=TTOML.CreateFromFile(AFile);
end;

class function TTOML.FromStream(AStream: TStream): TTOML;
begin
  Result:=TTOML.CreateFromStream(AStream);
end;

class function TTOML.FromString(ATOML: String): TTOML;
begin
  Result:=TTOML.CreateFromString(ATOML);
end;

constructor TTOML.Create;
begin
  inherited Create;
  FData:=TStringStream.Create('', TEncoding.UTF8, False);
end;

class function TTOML.CreateArrayRoot: TTOML;
begin
  Result:=TTOML.Create;
  Result.RootNewArray;
end;

class function TTOML.CreateObjectRoot: TTOML;
begin
  Result:=TTOML.Create;
  Result.RootNewObject;
end;

constructor TTOML.CreateFromObject(AObject: TObject);
begin
  Create;
  LoadFromObject(AObject);
end;

class function TTOML.CreateFromRecord<T>(const ARecord: T): TTOML;
var
  Doc: TTJAXY;
begin
  Result:=TTOML.CreateObjectRoot;
  Doc:=TTJAXY.CreateFromRecord<T>(ARecord);
  try
    Result.SetRoot(Doc.Root.Copy);
  finally
    Doc.Free;
  end;
end;

class function TTOML.CreateFromFile(AFile: String): TTOML;
begin
  Result:=TTOML.Create;
  try
    Result.LoadFromFile(AFile);
  except
    Result.Free;
    raise;
  end;
end;

constructor TTOML.CreateFromStream(AStream: TStream);
begin
  Create;
  LoadFromStream(AStream);
end;

constructor TTOML.CreateFromString(ATOML: String);
begin
  Create;
  ReadFromString(ATOML);
end;

destructor TTOML.Destroy;
begin
  FData.Free;
  inherited;
end;

procedure TTOML.Clear;
begin
  FData.Clear;
  inherited Clear;
end;

procedure TTOML.LoadFromFile(const AFileName: String);
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

procedure TTOML.LoadFromStream(AStream: TStream);
begin
  ReadFromString(TJAXYReadUTF8(AStream));
end;

procedure TTOML.ReadFromString(const AValue: String);
var
  Parser: TTOMLParser;
begin
  TJAXYRequireValidText(AValue);
  FData.Clear;
  FData.WriteString(AValue);
  FData.Position:=0;
  Parser:=TTOMLParser.Create(AValue);
  try
    SetRoot(Parser.Parse);
  finally
    Parser.Free;
  end;
end;

procedure TTOML.SaveToFile(const AFileName: String);
begin
  WriteToFile(AFileName);
end;

procedure TTOML.SaveToStream(AStream: TStream);
var
  S: String;
begin
  S:=WriteToString;
  TJAXYWriteUTF8(AStream, S);
end;

function TTOML.WriteToFile(const AFileName: String; AWriteMode: TTOMLStringWriteMode): String;
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

function TTOML.WriteToFile(const AFileName: String; AWriteMode: TTJAXYStringWriteMode): String;
begin
  Result:=WriteToFile(AFileName, TJAXYWriteModeToTOML(AWriteMode));
end;

function TTOML.WriteToString(AWriteMode: TTOMLStringWriteMode): String;
var
  Writer: TTOMLWriter;
begin
  Writer:=TTOMLWriter.Create(AWriteMode);
  try
    Result:=Writer.Write(Root);
  finally
    Writer.Free;
  end;
end;

function TTOML.WriteToString(AWriteMode: TTJAXYStringWriteMode): String;
begin
  Result:=WriteToString(TJAXYWriteModeToTOML(AWriteMode));
end;

end.
