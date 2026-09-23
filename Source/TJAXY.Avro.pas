(******************************************************************************)
(*                                                                            *)
(*  TJAXY Avro Codec                                                          *)
(*                                                                            *)
(*  Version     : 0.01                                                        *)
(*  License     : BSD 2-Clause                                                *)
(*  Author      : NaliLord / TJAXY contributors                               *)
(*                                                                            *)
(*  This unit reads/writes Avro JSON encoding using an explicit Avro schema.  *)
(*                                                                            *)
(******************************************************************************)

unit TJAXY.Avro;

interface

uses
  SysUtils, Classes, DateUtils, Math, System.ZLib, TJAXY.Core, TJAXY.JSON;

type
  TAvroSchemaKind = (askNull, askBoolean, askInt, askLong, askFloat, askDouble, askBytes, askString,
    askRecord, askEnum, askArray, askMap, askUnion, askFixed, askReference);

  EAvroException = class(Exception);

  TAvroSchema = class;
  TAvroSchemaField = class;

  TAvroSchemaField = class
  private
    FAliases: TStringList;
    FDefault: TTJAXYValue;
    FName: String;
    FSchema: TAvroSchema;
    function GetHasDefault: Boolean;
  public
    constructor Create(const AName: String; ASchema: TAvroSchema; ADefault: TTJAXYValue);
    destructor Destroy; override;
    property Aliases: TStringList read FAliases;
    property Name: String read FName;
    property Schema: TAvroSchema read FSchema;
    property Default: TTJAXYValue read FDefault;
    property HasDefault: Boolean read GetHasDefault;
  end;

  TAvroSchema = class
  private
    FFields: TList;
    FItems: TAvroSchema;
    FKind: TAvroSchemaKind;
    FAliases: TStringList;
    FLogicalType: String;
    FName: String;
    FPrecision: Integer;
    FReference: TAvroSchema;
    FReferenceName: String;
    FScale: Integer;
    FSize: Integer;
    FSymbols: TStringList;
    FValues: TAvroSchema;
    function GetBranch(Index: Integer): TAvroSchema;
    function GetBranchCount: Integer;
    function GetField(Index: Integer): TAvroSchemaField;
    function GetFieldCount: Integer;
  public
    constructor Create(AKind: TAvroSchemaKind);
    destructor Destroy; override;
    class function FromJSON(AValue: TTJAXYValue): TAvroSchema; static;
    class function FromJSONDocument(AJSON: TJSON): TAvroSchema; static;
    class function FromString(const ASchemaJSON: String): TAvroSchema; static;
    function AddBranch(ASchema: TAvroSchema): TAvroSchema;
    function AddField(const AName: String; ASchema: TAvroSchema; ADefault: TTJAXYValue = nil): TAvroSchemaField;
    function BranchName: String;
    function FindField(const AName: String): TAvroSchemaField;
    function HasSymbol(const AName: String): Boolean;
    function ParsingCanonicalForm: String;
    function Fingerprint64: UInt64;
    property Branch[Index: Integer]: TAvroSchema read GetBranch;
    property BranchCount: Integer read GetBranchCount;
    property Field[Index: Integer]: TAvroSchemaField read GetField;
    property FieldCount: Integer read GetFieldCount;
    property Items: TAvroSchema read FItems write FItems;
    property Kind: TAvroSchemaKind read FKind;
    property Aliases: TStringList read FAliases;
    property LogicalType: String read FLogicalType write FLogicalType;
    property Name: String read FName write FName;
    property Precision: Integer read FPrecision write FPrecision;
    property Reference: TAvroSchema read FReference write FReference;
    property ReferenceName: String read FReferenceName write FReferenceName;
    property Scale: Integer read FScale write FScale;
    property Size: Integer read FSize write FSize;
    property Symbols: TStringList read FSymbols;
    property Values: TAvroSchema read FValues write FValues;
  end;

  TAvro = class(TTJAXYParser)
  private
    FData: TStringStream;
    FContainerCodec: String;
    FSchema: TAvroSchema;
    FSchemaJSON: String;
    FMaxContainerRecords: Integer;
    procedure SetMaxContainerRecords(AValue: Integer);
    procedure SetSchema(AValue: TAvroSchema);
  protected
    function ReadValue(AValue: TTJAXYValue; ASchema: TAvroSchema; const APath: String): TTJAXYValue;
    function WriteValue(AValue: TTJAXYValue; ASchema: TAvroSchema; const APath: String): TTJAXYValue;
    function ReadBinaryValue(AStream: TStream; ASchema: TAvroSchema; const APath: String): TTJAXYValue;
    function ResolveValue(AValue: TTJAXYValue; AWriterSchema, AReaderSchema: TAvroSchema; const APath: String): TTJAXYValue;
    procedure WriteBinaryValue(AStream: TStream; AValue: TTJAXYValue; ASchema: TAvroSchema; const APath: String);
  public
    class function CreateTemplate(AName: String): TTJAXYTemplate; static;
    class function Template(AName: String): TTJAXYTemplate; static;
    class function FromSchemaString(const ASchemaJSON: String): TAvro; static;
    class function FromSchemaJSON(AJSON: TJSON): TAvro; static;
    class function FromString(const AValueJSON, ASchemaJSON: String): TAvro; static;
    class function FromFile(const AFileName, ASchemaJSON: String): TAvro; static;
    class function FromStream(AStream: TStream; const ASchemaJSON: String): TAvro; static;
    constructor Create; overload; override;
    constructor Create(ASchema: TAvroSchema); reintroduce; overload;
    constructor CreateFromSchemaJSON(AJSON: TJSON);
    constructor CreateFromSchemaString(const ASchemaJSON: String);
    constructor CreateFromString(const AValueJSON, ASchemaJSON: String);
    class function CreateFromFile(const AFileName, ASchemaJSON: String): TAvro; static;
    constructor CreateFromStream(AStream: TStream; const ASchemaJSON: String);
    destructor Destroy; override;
    procedure Clear; override;
    procedure LoadFromFile(const AFileName: String); override;
    procedure LoadFromStream(AStream: TStream); override;
    procedure LoadFromString(const AValueJSON: String);
    procedure LoadFromBinaryStream(AStream: TStream); overload;
    procedure LoadFromBinaryStream(AStream: TStream; AWriterSchema: TAvroSchema); overload;
    procedure LoadFromBinaryBytes(const ABytes: TBytes); overload;
    procedure LoadFromBinaryBytes(const ABytes: TBytes; AWriterSchema: TAvroSchema); overload;
    procedure LoadSingleObjectFromStream(AStream: TStream);
    procedure LoadSingleObjectBytes(const ABytes: TBytes);
    procedure LoadContainerFromStream(AStream: TStream);
    procedure LoadContainerFromFile(const AFileName: String);
    procedure ReadFromString(const AValue: String); override;
    procedure SaveToFile(const AFileName: String); override;
    procedure SaveToStream(AStream: TStream); override;
    procedure SaveToBinaryStream(AStream: TStream);
    function WriteToBinaryBytes: TBytes;
    procedure SaveSingleObjectToStream(AStream: TStream);
    function WriteSingleObjectBytes: TBytes;
    procedure SaveContainerToStream(AStream: TStream);
    procedure SaveContainerToFile(const AFileName: String);
    function WriteToString(AWriteMode: TTJAXYStringWriteMode = tjaxywmReadable): String; override;
    property ContainerCodec: String read FContainerCodec write FContainerCodec;
    property MaxContainerRecords: Integer read FMaxContainerRecords write SetMaxContainerRecords;
    property Schema: TAvroSchema read FSchema write SetSchema;
  end;

implementation

const
  AVRO_MAX_CONTAINER_BLOCK_RECORDS = 1000000;

resourcestring
  RCS_SCHEMA_REQUIRED = 'Avro schema is required';
  RCS_INVALID_SCHEMA = 'Invalid Avro schema at %s';
  RCS_UNSUPPORTED_SCHEMA = 'Unsupported Avro schema type "%s"';
  RCS_FIELD_REQUIRED = 'Required Avro field "%s" is missing at %s';
  RCS_VALUE_TYPE = 'Invalid Avro value type at %s, expected %s';
  RCS_ENUM_SYMBOL = 'Invalid Avro enum symbol "%s" at %s';
  RCS_UNION_VALUE = 'Invalid Avro union value at %s';
  RCS_BINARY_EOF = 'Unexpected end of Avro binary data';
  RCS_CONTAINER_CODEC = 'Unsupported Avro container codec "%s"';

function AvroPath(const AParent, AName: String): String;
begin
  if AParent = '' then
    Result:=AName
  else
    Result:=AParent + '.' + AName;
end;

function AvroTypeName(AKind: TAvroSchemaKind): String;
begin
  case AKind of
    askNull: Result:='null';
    askBoolean: Result:='boolean';
    askInt: Result:='int';
    askLong: Result:='long';
    askFloat: Result:='float';
    askDouble: Result:='double';
    askBytes: Result:='bytes';
    askString: Result:='string';
    askRecord: Result:='record';
    askEnum: Result:='enum';
    askArray: Result:='array';
    askMap: Result:='map';
    askUnion: Result:='union';
    askFixed: Result:='fixed';
    askReference: Result:='reference';
  else
    Result:='unknown';
  end;
end;

function AvroKindFromName(const AName: String; out AKind: TAvroSchemaKind): Boolean;
begin
  Result:=True;
  if SameText(AName, 'null') then AKind:=askNull
  else if SameText(AName, 'boolean') then AKind:=askBoolean
  else if SameText(AName, 'int') then AKind:=askInt
  else if SameText(AName, 'long') then AKind:=askLong
  else if SameText(AName, 'float') then AKind:=askFloat
  else if SameText(AName, 'double') then AKind:=askDouble
  else if SameText(AName, 'bytes') then AKind:=askBytes
  else if SameText(AName, 'string') then AKind:=askString
  else if SameText(AName, 'record') then AKind:=askRecord
  else if SameText(AName, 'enum') then AKind:=askEnum
  else if SameText(AName, 'array') then AKind:=askArray
  else if SameText(AName, 'map') then AKind:=askMap
  else if SameText(AName, 'fixed') then AKind:=askFixed
  else Result:=False;
end;

function AvroCopyOrNull(AValue: TTJAXYValue): TTJAXYValue;
begin
  if Assigned(AValue) then
    Result:=AValue.Copy
  else
    Result:=TTJAXYNull.Create;
end;

function AvroFullName(const AName, ANamespace: String): String;
begin
  if (AName = '') OR (Pos('.', AName) > 0) OR (ANamespace = '') then
    Result:=AName
  else
    Result:=ANamespace + '.' + AName;
end;

function AvroSchemaResolve(ASchema: TAvroSchema): TAvroSchema;
begin
  Result:=ASchema;
  while Assigned(Result) AND (Result.Kind = askReference) do
    Result:=Result.Reference;
end;

function AvroIsName(const AValue: String): Boolean;
var
  I: Integer;
begin
  Result:=AValue <> '';
  if NOT CharInSet(AValue[1], ['A'..'Z', 'a'..'z', '_']) then
    Exit(False);
  for I:=2 to Length(AValue) do
    if NOT CharInSet(AValue[I], ['A'..'Z', 'a'..'z', '0'..'9', '_']) then
      Exit(False);
end;

function AvroIsFullName(const AValue: String): Boolean;
var
  Part: String;
  I, Start: Integer;
begin
  Result:=AValue <> '';
  Start:=1;
  for I:=1 to Length(AValue) + 1 do
    if (I > Length(AValue)) OR (AValue[I] = '.') then
    begin
      Part:=Copy(AValue, Start, I - Start);
      if NOT AvroIsName(Part) then
        Exit(False);
      Start:=I + 1;
    end;
end;

procedure AvroWriteByte(AStream: TStream; AValue: Byte);
begin
  AStream.WriteBuffer(AValue, SizeOf(AValue));
end;

function AvroReadByte(AStream: TStream): Byte;
begin
  if AStream.Read(Result, SizeOf(Result)) <> SizeOf(Result) then
    raise EAvroException.Create(RCS_BINARY_EOF);
end;

procedure AvroWriteLong(AStream: TStream; AValue: Int64);
var
  N: UInt64;
  B: Byte;
begin
  N:=UInt64((AValue shl 1) xor (AValue shr 63));
  while (N AND not UInt64($7F)) <> 0 do
  begin
    B:=Byte((N AND $7F) OR $80);
    AvroWriteByte(AStream, B);
    N:=N shr 7;
  end;
  AvroWriteByte(AStream, Byte(N));
end;

function AvroReadLong(AStream: TStream): Int64;
var
  Index: Integer;
  B: Byte;
  N: UInt64;
begin
  N:=0;
  for Index:=0 to 9 do
  begin
    B:=AvroReadByte(AStream);
    if (Index = 9) AND ((B AND $FE) <> 0) then
      raise EAvroException.Create('Invalid Avro long encoding');
    N:=N OR (UInt64(B AND $7F) shl (Index * 7));
    if (B AND $80) = 0 then
      Break;
  end;
  if (B AND $80) <> 0 then
    raise EAvroException.Create('Invalid Avro long encoding');
  if (N AND 1) <> 0 then
    Result:=-Int64(N shr 1) - 1
  else
    Result:=Int64(N shr 1);
end;

procedure AvroWriteRawBytes(AStream: TStream; const AValue: TBytes);
begin
  if Length(AValue) > 0 then
    AStream.WriteBuffer(AValue[0], Length(AValue));
end;

function AvroReadRawBytes(AStream: TStream; ACount: Int64): TBytes;
begin
  if (ACount < 0) OR (ACount > MaxInt) then
    raise EAvroException.Create('Invalid Avro byte length');
  SetLength(Result, Integer(ACount));
  if ACount > 0 then
    if AStream.Read(Result[0], Integer(ACount)) <> ACount then
      raise EAvroException.Create(RCS_BINARY_EOF);
end;

function AvroStringToBytes(const AValue: String): TBytes;
var
  I: Integer;
begin
  SetLength(Result, Length(AValue));
  for I:=1 to Length(AValue) do
    Result[I - 1]:=Byte(Ord(AValue[I]) AND $FF);
end;

function AvroBytesToString(const AValue: TBytes): String;
var
  I: Integer;
begin
  SetLength(Result, Length(AValue));
  for I:=0 to High(AValue) do
    Result[I + 1]:=Char(AValue[I]);
end;

function AvroUTF8Bytes(const AValue: String): TBytes;
begin
  Result:=TEncoding.UTF8.GetBytes(AValue);
end;

function AvroUTF8String(const AValue: TBytes): String;
begin
  Result:=TEncoding.UTF8.GetString(AValue);
end;

function AvroJSONEncode(const AValue: String): String;
begin
  Result:=TJSON.EncodeString(AValue);
end;

function AvroDateStringFromDays(ADays: Int64): String;
begin
  Result:=FormatDateTime('yyyy"-"mm"-"dd', IncDay(EncodeDate(1970, 1, 1), ADays));
end;

function AvroDaysFromDateString(const AValue: String; out ADays: Int64): Boolean;
var
  Y, M, D: Integer;
  DateValue: TDateTime;
begin
  Result:=False;
  if Length(AValue) <> 10 then
    Exit;
  Y:=StrToIntDef(Copy(AValue, 1, 4), -1);
  M:=StrToIntDef(Copy(AValue, 6, 2), -1);
  D:=StrToIntDef(Copy(AValue, 9, 2), -1);
  if (AValue[5] <> '-') OR (AValue[8] <> '-') OR NOT TryEncodeDate(Y, M, D, DateValue) then
    Exit;
  ADays:=DaysBetween(EncodeDate(1970, 1, 1), DateValue);
  if DateValue < EncodeDate(1970, 1, 1) then
    ADays:=-ADays;
  Result:=True;
end;

function AvroTimeStringFromMillis(AMillis: Int64): String;
var
  H, M, S, MS: Integer;
begin
  H:=AMillis div 3600000;
  AMillis:=AMillis mod 3600000;
  M:=AMillis div 60000;
  AMillis:=AMillis mod 60000;
  S:=AMillis div 1000;
  MS:=AMillis mod 1000;
  if MS = 0 then
    Result:=Format('%.2d:%.2d:%.2d', [H, M, S])
  else
    Result:=Format('%.2d:%.2d:%.2d.%.3d', [H, M, S, MS]);
end;

function AvroTimeStringFromMicros(AMicros: Int64): String;
var
  H, M, S, US: Integer;
begin
  H:=AMicros div 3600000000;
  AMicros:=AMicros mod 3600000000;
  M:=AMicros div 60000000;
  AMicros:=AMicros mod 60000000;
  S:=AMicros div 1000000;
  US:=AMicros mod 1000000;
  if US = 0 then
    Result:=Format('%.2d:%.2d:%.2d', [H, M, S])
  else
    Result:=Format('%.2d:%.2d:%.2d.%.6d', [H, M, S, US]);
end;

function AvroMillisFromTimeString(const AValue: String; out AMillis: Int64): Boolean;
var
  H, M, S, MS: Integer;
  Rest: String;
begin
  Result:=False;
  if Length(AValue) < 8 then
    Exit;
  H:=StrToIntDef(Copy(AValue, 1, 2), -1);
  M:=StrToIntDef(Copy(AValue, 4, 2), -1);
  S:=StrToIntDef(Copy(AValue, 7, 2), -1);
  MS:=0;
  if (AValue[3] <> ':') OR (AValue[6] <> ':') OR (H < 0) OR (H > 23) OR (M < 0) OR (M > 59) OR (S < 0) OR (S > 59) then
    Exit;
  if Length(AValue) > 8 then
  begin
    if AValue[9] <> '.' then
      Exit;
    Rest:=Copy(AValue, 10, 3);
    while Length(Rest) < 3 do
      Rest:=Rest + '0';
    MS:=StrToIntDef(Rest, -1);
    if MS < 0 then
      Exit;
  end;
  AMillis:=H * 3600000 + M * 60000 + S * 1000 + MS;
  Result:=True;
end;

function AvroMicrosFromTimeString(const AValue: String; out AMicros: Int64): Boolean;
var
  H, M, S, US: Integer;
  Rest: String;
begin
  Result:=False;
  if Length(AValue) < 8 then
    Exit;
  H:=StrToIntDef(Copy(AValue, 1, 2), -1);
  M:=StrToIntDef(Copy(AValue, 4, 2), -1);
  S:=StrToIntDef(Copy(AValue, 7, 2), -1);
  US:=0;
  if (AValue[3] <> ':') OR (AValue[6] <> ':') OR (H < 0) OR (H > 23) OR (M < 0) OR (M > 59) OR (S < 0) OR (S > 59) then
    Exit;
  if Length(AValue) > 8 then
  begin
    if AValue[9] <> '.' then
      Exit;
    Rest:=Copy(AValue, 10, 6);
    while Length(Rest) < 6 do
      Rest:=Rest + '0';
    US:=StrToIntDef(Rest, -1);
    if US < 0 then
      Exit;
  end;
  AMicros:=Int64(H) * 3600000000 + Int64(M) * 60000000 + Int64(S) * 1000000 + US;
  Result:=True;
end;

function AvroTimestampStringFromMillis(AMillis: Int64): String;
begin
  Result:=FormatDateTime('yyyy"-"mm"-"dd"T"hh":"nn":"ss"."zzz"Z"', UnixToDateTime(AMillis div 1000, True) + ((AMillis mod 1000) / MSecsPerDay));
end;

function AvroTimestampStringFromMicros(AMicros: Int64): String;
var
  Seconds: Int64;
  US: Integer;
begin
  Seconds:=AMicros div 1000000;
  US:=Abs(AMicros mod 1000000);
  Result:=FormatDateTime('yyyy"-"mm"-"dd"T"hh":"nn":"ss', UnixToDateTime(Seconds, True)) + Format('.%.6dZ', [US]);
end;

function AvroMillisFromTimestampString(const AValue: String; out AMillis: Int64): Boolean;
var
  DatePart, TimePart: String;
  Days, TimeMillis: Int64;
begin
  Result:=False;
  if Length(AValue) < 19 then
    Exit;
  DatePart:=Copy(AValue, 1, 10);
  TimePart:=Copy(AValue, 12, MaxInt);
  if (AValue[11] <> 'T') AND (AValue[11] <> ' ') then
    Exit;
  if (Length(TimePart) > 0) AND (TimePart[Length(TimePart)] = 'Z') then
    Delete(TimePart, Length(TimePart), 1);
  if NOT AvroDaysFromDateString(DatePart, Days) then
    Exit;
  if NOT AvroMillisFromTimeString(TimePart, TimeMillis) then
    Exit;
  AMillis:=Days * MSecsPerDay + TimeMillis;
  Result:=True;
end;

function AvroMicrosFromTimestampString(const AValue: String; out AMicros: Int64): Boolean;
var
  DatePart, TimePart: String;
  Days, TimeMicros: Int64;
begin
  Result:=False;
  if Length(AValue) < 19 then
    Exit;
  DatePart:=Copy(AValue, 1, 10);
  TimePart:=Copy(AValue, 12, MaxInt);
  if (AValue[11] <> 'T') AND (AValue[11] <> ' ') then
    Exit;
  if (Length(TimePart) > 0) AND (TimePart[Length(TimePart)] = 'Z') then
    Delete(TimePart, Length(TimePart), 1);
  if NOT AvroDaysFromDateString(DatePart, Days) then
    Exit;
  if NOT AvroMicrosFromTimeString(TimePart, TimeMicros) then
    Exit;
  AMicros:=Days * Int64(MSecsPerDay) * 1000 + TimeMicros;
  Result:=True;
end;

function AvroLogicalRead(AValue: TTJAXYValue; ASchema: TAvroSchema): TTJAXYValue;
begin
  Result:=AValue;
  if (ASchema.LogicalType = 'date') AND AValue.IsInteger then
    Result:=TTJAXYDateTime.CreateFrom(AvroDateStringFromDays(AValue.AsInteger), tjaxydtkLocalDate)
  else if (ASchema.LogicalType = 'time-millis') AND AValue.IsInteger then
    Result:=TTJAXYDateTime.CreateFrom(AvroTimeStringFromMillis(AValue.AsInteger), tjaxydtkLocalTime)
  else if (ASchema.LogicalType = 'time-micros') AND AValue.IsInteger then
    Result:=TTJAXYDateTime.CreateFrom(AvroTimeStringFromMicros(AValue.AsInteger), tjaxydtkLocalTime)
  else if (ASchema.LogicalType = 'timestamp-millis') AND AValue.IsInteger then
    Result:=TTJAXYDateTime.CreateFrom(AvroTimestampStringFromMillis(AValue.AsInteger), tjaxydtkOffsetDateTime)
  else if (ASchema.LogicalType = 'timestamp-micros') AND AValue.IsInteger then
    Result:=TTJAXYDateTime.CreateFrom(AvroTimestampStringFromMicros(AValue.AsInteger), tjaxydtkOffsetDateTime)
  else if (ASchema.LogicalType = 'local-timestamp-millis') AND AValue.IsInteger then
    Result:=TTJAXYDateTime.CreateFrom(AvroTimestampStringFromMillis(AValue.AsInteger), tjaxydtkLocalDateTime)
  else if (ASchema.LogicalType = 'local-timestamp-micros') AND AValue.IsInteger then
    Result:=TTJAXYDateTime.CreateFrom(AvroTimestampStringFromMicros(AValue.AsInteger), tjaxydtkLocalDateTime);
  if Result <> AValue then
    AValue.Free;
end;

function AvroLogicalWrite(AValue: TTJAXYValue; ASchema: TAvroSchema): TTJAXYValue;
var
  N: Int64;
begin
  if (ASchema.LogicalType = '') OR (AValue = nil) then
    Exit(AValue.Copy);
  if AValue.IsInteger then
    Exit(AValue.Copy);
  if (ASchema.LogicalType = 'date') AND AvroDaysFromDateString(AValue.AsString, N) then
    Exit(TTJAXYInteger.CreateFrom(N));
  if (ASchema.LogicalType = 'time-millis') AND AvroMillisFromTimeString(AValue.AsString, N) then
    Exit(TTJAXYInteger.CreateFrom(N));
  if (ASchema.LogicalType = 'time-micros') AND AvroMicrosFromTimeString(AValue.AsString, N) then
    Exit(TTJAXYInteger.CreateFrom(N));
  if (ASchema.LogicalType = 'timestamp-millis') AND AvroMillisFromTimestampString(AValue.AsString, N) then
    Exit(TTJAXYInteger.CreateFrom(N));
  if (ASchema.LogicalType = 'timestamp-micros') AND AvroMicrosFromTimestampString(AValue.AsString, N) then
    Exit(TTJAXYInteger.CreateFrom(N));
  if (ASchema.LogicalType = 'local-timestamp-millis') AND AvroMillisFromTimestampString(AValue.AsString, N) then
    Exit(TTJAXYInteger.CreateFrom(N));
  if (ASchema.LogicalType = 'local-timestamp-micros') AND AvroMicrosFromTimestampString(AValue.AsString, N) then
    Exit(TTJAXYInteger.CreateFrom(N));
  Result:=AValue.Copy;
end;

function AvroIsUUID(const AValue: String): Boolean;
var
  I: Integer;
begin
  Result:=Length(AValue) = 36;
  if NOT Result then
    Exit;
  for I:=1 to Length(AValue) do
    if I IN [9, 14, 19, 24] then
    begin
      if AValue[I] <> '-' then
        Exit(False);
    end
    else if NOT CharInSet(AValue[I], ['0'..'9', 'A'..'F', 'a'..'f']) then
      Exit(False);
end;

function AvroDecimalBytesToInt64(const ABytes: TBytes): Int64;
var
  I: Integer;
begin
  if Length(ABytes) = 0 then
    Exit(0);
  if Length(ABytes) > SizeOf(Int64) then
    raise EAvroException.CreateFmt(RCS_VALUE_TYPE, ['decimal', 'decimal']);
  if (ABytes[0] AND $80) <> 0 then
    Result:=-1
  else
    Result:=0;
  for I:=0 to High(ABytes) do
    Result:=(Result shl 8) OR ABytes[I];
end;

function AvroDecimalInt64ToBytes(AValue: Int64; AFixedSize: Integer = 0): TBytes;
var
  I, Size: Integer;
  V: UInt64;
  SignByte: Byte;
begin
  if AFixedSize > 0 then
    Size:=AFixedSize
  else
    Size:=SizeOf(Int64);
  SetLength(Result, Size);
  V:=UInt64(AValue);
  for I:=Size - 1 downto 0 do
  begin
    Result[I]:=Byte(V AND $FF);
    V:=V shr 8;
  end;
  if AFixedSize <= 0 then
  begin
    SignByte:=0;
    if AValue < 0 then
      SignByte:=$FF;
    while (Length(Result) > 1) AND (Result[0] = SignByte) AND (((Result[1] AND $80) = (SignByte AND $80))) do
      Delete(Result, 0, 1);
  end;
end;

function AvroDecimalStringFromUnscaled(AValue: Int64; AScale: Integer): String;
var
  Negative: Boolean;
  Digits: String;
begin
  Negative:=AValue < 0;
  if Negative then
    Digits:=IntToStr(-AValue)
  else
    Digits:=IntToStr(AValue);
  while Length(Digits) <= AScale do
    Digits:='0' + Digits;
  if AScale > 0 then
    Insert('.', Digits, Length(Digits) - AScale + 1);
  if Negative then
    Result:='-' + Digits
  else
    Result:=Digits;
end;

function AvroUnscaledFromDecimalString(const AValue: String; AScale: Integer; out AResult: Int64): Boolean;
var
  S: String;
  P: Integer;
  FractionLen: Integer;
begin
  S:=Trim(AValue);
  P:=Pos('.', S);
  FractionLen:=0;
  if P > 0 then
  begin
    FractionLen:=Length(S) - P;
    Delete(S, P, 1);
  end;
  while FractionLen < AScale do
  begin
    S:=S + '0';
    Inc(FractionLen);
  end;
  while FractionLen > AScale do
  begin
    Delete(S, Length(S), 1);
    Dec(FractionLen);
  end;
  Result:=TryStrToInt64(S, AResult);
end;

function AvroDecimalRead(AValue: TTJAXYValue; ASchema: TAvroSchema): TTJAXYValue;
var
  Bytes: TBytes;
begin
  if NOT AValue.IsString then
    Exit(AValue);
  Bytes:=AvroStringToBytes(AValue.AsString);
  Result:=TTJAXYString.CreateFrom(AvroDecimalStringFromUnscaled(AvroDecimalBytesToInt64(Bytes), ASchema.Scale));
  AValue.Free;
end;

function AvroDecimalWrite(AValue: TTJAXYValue; ASchema: TAvroSchema): TTJAXYValue;
var
  Unscaled: Int64;
  FixedSize: Integer;
begin
  if (AValue = nil) OR (NOT AvroUnscaledFromDecimalString(AValue.AsString, ASchema.Scale, Unscaled)) then
    Exit(AValue.Copy);
  FixedSize:=0;
  if ASchema.Kind = askFixed then
    FixedSize:=ASchema.Size;
  Result:=TTJAXYString.CreateFrom(AvroBytesToString(AvroDecimalInt64ToBytes(Unscaled, FixedSize)));
end;

function AvroCompressDeflate(const ABytes: TBytes): TBytes;
var
  Source, Dest: TBytesStream;
  Compressor: TCompressionStream;
begin
  Source:=TBytesStream.Create(ABytes);
  Dest:=TBytesStream.Create;
  try
    Compressor:=TCompressionStream.Create(Dest, zcDefault, -15);
    try
      Compressor.CopyFrom(Source, 0);
    finally
      Compressor.Free;
    end;
    Result:=Dest.Bytes;
    SetLength(Result, Dest.Size);
  finally
    Dest.Free;
    Source.Free;
  end;
end;

function AvroDecompressDeflate(const ABytes: TBytes): TBytes;
var
  Source, Dest: TBytesStream;
  Decompressor: TDecompressionStream;
begin
  Source:=TBytesStream.Create(ABytes);
  Dest:=TBytesStream.Create;
  try
    Decompressor:=TDecompressionStream.Create(Source, -15);
    try
      Dest.CopyFrom(Decompressor, 0);
    finally
      Decompressor.Free;
    end;
    Result:=Dest.Bytes;
    SetLength(Result, Dest.Size);
  finally
    Dest.Free;
    Source.Free;
  end;
end;

{ TAvroSchemaField }

constructor TAvroSchemaField.Create(const AName: String; ASchema: TAvroSchema; ADefault: TTJAXYValue);
begin
  inherited Create;
  FAliases:=TStringList.Create;
  FAliases.CaseSensitive:=True;
  FName:=AName;
  FSchema:=ASchema;
  FDefault:=ADefault;
end;

destructor TAvroSchemaField.Destroy;
begin
  FAliases.Free;
  FDefault.Free;
  FSchema.Free;
  inherited;
end;

function TAvroSchemaField.GetHasDefault: Boolean;
begin
  Result:=Assigned(FDefault);
end;

{ TAvroSchema }

constructor TAvroSchema.Create(AKind: TAvroSchemaKind);
begin
  inherited Create;
  FKind:=AKind;
  FAliases:=TStringList.Create;
  FAliases.CaseSensitive:=True;
  FFields:=TList.Create;
  FSymbols:=TStringList.Create;
  FSymbols.CaseSensitive:=True;
end;

destructor TAvroSchema.Destroy;
var
  I: Integer;
begin
  for I:=0 to FFields.Count - 1 do
    TObject(FFields[I]).Free;
  FFields.Free;
  FAliases.Free;

  if FKind = askUnion then
    for I:=0 to FSymbols.Count - 1 do
      FSymbols.Objects[I].Free;
  FSymbols.Free;

  FItems.Free;
  FValues.Free;
  inherited;
end;

function TAvroSchema.AddBranch(ASchema: TAvroSchema): TAvroSchema;
begin
  if (ASchema.Kind = askUnion) OR ((FSymbols.IndexOf(ASchema.BranchName) >= 0) AND NOT (AvroSchemaResolve(ASchema).Kind IN [askRecord, askEnum, askFixed])) then
  begin
    ASchema.Free;
    raise EAvroException.CreateFmt(RCS_INVALID_SCHEMA, ['union']);
  end;
  FSymbols.AddObject(ASchema.BranchName, ASchema);
  Result:=ASchema;
end;

function TAvroSchema.AddField(const AName: String; ASchema: TAvroSchema; ADefault: TTJAXYValue): TAvroSchemaField;
begin
  if (NOT AvroIsName(AName)) OR Assigned(FindField(AName)) then
  begin
    ASchema.Free;
    ADefault.Free;
    raise EAvroException.CreateFmt(RCS_INVALID_SCHEMA, ['record.field.name']);
  end;
  Result:=TAvroSchemaField.Create(AName, ASchema, ADefault);
  FFields.Add(Result);
end;

function TAvroSchema.BranchName: String;
var
  Resolved: TAvroSchema;
begin
  Resolved:=AvroSchemaResolve(Self);
  if Assigned(Resolved) AND (Resolved <> Self) then
    Exit(Resolved.BranchName);
  if FName <> '' then
    Result:=FName
  else
    Result:=AvroTypeName(FKind);
end;

function TAvroSchema.FindField(const AName: String): TAvroSchemaField;
var
  I: Integer;
begin
  Result:=nil;
  for I:=0 to FieldCount - 1 do
    if Field[I].Name = AName then
      Exit(Field[I]);
end;

class function TAvroSchema.FromString(const ASchemaJSON: String): TAvroSchema;
var
  JSON: TJSON;
begin
  JSON:=TJSON.CreateFromString(ASchemaJSON);
  try
    Result:=FromJSONDocument(JSON);
  finally
    JSON.Free;
  end;
end;

class function TAvroSchema.FromJSON(AValue: TTJAXYValue): TAvroSchema;
var
  Names: TStringList;

  function ParseSchema(AValue: TTJAXYValue; const ANamespace, APath: String): TAvroSchema;
  var
    I: Integer;
    Kind: TAvroSchemaKind;
    Obj: TTJAXYObject;
    TypeValue: TTJAXYValue;
  FieldObj: TTJAXYObject;
  Field: TAvroSchemaField;
  DefaultValue: TTJAXYValue;
    TypeName: String;
  SchemaName: String;
  SchemaNamespace: String;
  FullName: String;
  AliasName: String;
  AliasIndex: Integer;
  begin
    if AValue = nil then
      raise EAvroException.CreateFmt(RCS_INVALID_SCHEMA, [APath]);

    if AValue.IsString then
    begin
      TypeName:=AValue.AsString;
      if AvroKindFromName(TypeName, Kind) then
        Exit(TAvroSchema.Create(Kind));

      FullName:=AvroFullName(TypeName, ANamespace);
      I:=Names.IndexOf(FullName);
      if I < 0 then
        I:=Names.IndexOf(TypeName);
      if I < 0 then
        raise EAvroException.CreateFmt(RCS_UNSUPPORTED_SCHEMA, [TypeName]);
      Result:=TAvroSchema.Create(askReference);
      Result.ReferenceName:=FullName;
      Result.Reference:=TAvroSchema(Names.Objects[I]);
      Exit;
    end;

    if AValue.IsArray then
    begin
      Result:=TAvroSchema.Create(askUnion);
      try
        for I:=0 to AValue.AsArray.Count - 1 do
          Result.AddBranch(ParseSchema(AValue.AsArray[I], ANamespace, APath + '[]'));
      except
        Result.Free;
        raise;
      end;
      Exit;
    end;

    if NOT AValue.IsObject then
      raise EAvroException.CreateFmt(RCS_INVALID_SCHEMA, [APath]);

    Obj:=AValue.AsObject;
    if NOT Obj.HasKey('type') then
      raise EAvroException.CreateFmt(RCS_INVALID_SCHEMA, [APath + '.type']);

    TypeValue:=Obj['type'];
    if TypeValue.IsArray then
      Exit(ParseSchema(TypeValue, ANamespace, APath + '.type'));

    if TypeValue.IsObject then
      Exit(ParseSchema(TypeValue, ANamespace, APath + '.type'));

    if NOT TypeValue.IsString then
      raise EAvroException.CreateFmt(RCS_INVALID_SCHEMA, [APath + '.type']);

    TypeName:=TypeValue.AsString;
    if NOT AvroKindFromName(TypeName, Kind) then
    begin
      FullName:=AvroFullName(TypeName, ANamespace);
      I:=Names.IndexOf(FullName);
      if I < 0 then
        I:=Names.IndexOf(TypeName);
      if I < 0 then
        raise EAvroException.CreateFmt(RCS_UNSUPPORTED_SCHEMA, [TypeName]);
      Result:=TAvroSchema.Create(askReference);
      Result.ReferenceName:=FullName;
      Result.Reference:=TAvroSchema(Names.Objects[I]);
      Exit;
    end;

    Result:=TAvroSchema.Create(Kind);
    try
      SchemaNamespace:=ANamespace;
      if Obj.HasKey('namespace') AND Obj['namespace'].IsString then
        SchemaNamespace:=Obj['namespace'].AsString;
      if Obj.HasKey('logicalType') AND Obj['logicalType'].IsString then
      begin
        Result.LogicalType:=Obj['logicalType'].AsString;
        if Result.LogicalType = 'decimal' then
        begin
          if NOT (Kind IN [askBytes, askFixed]) then
            raise EAvroException.CreateFmt(RCS_INVALID_SCHEMA, [APath + '.logicalType']);
          if NOT (Obj.HasKey('precision') AND Obj['precision'].IsInteger AND (Obj['precision'].AsInteger > 0)) then
            raise EAvroException.CreateFmt(RCS_INVALID_SCHEMA, [APath + '.precision']);
          Result.Precision:=Obj['precision'].AsInteger;
          if Obj.HasKey('scale') then
          begin
            if NOT (Obj['scale'].IsInteger AND (Obj['scale'].AsInteger >= 0) AND (Obj['scale'].AsInteger <= Result.Precision)) then
              raise EAvroException.CreateFmt(RCS_INVALID_SCHEMA, [APath + '.scale']);
            Result.Scale:=Obj['scale'].AsInteger;
          end;
        end
        else if (Result.LogicalType = 'uuid') AND (Kind <> askString) then
          raise EAvroException.CreateFmt(RCS_INVALID_SCHEMA, [APath + '.logicalType']);
      end;
      if Obj.HasKey('aliases') AND Obj['aliases'].IsArray then
        for I:=0 to Obj['aliases'].AsArray.Count - 1 do
          if Obj['aliases'].AsArray[I].IsString then
          begin
            AliasName:=AvroFullName(Obj['aliases'].AsArray[I].AsString, SchemaNamespace);
            if AvroIsFullName(AliasName) AND (Result.Aliases.IndexOf(AliasName) < 0) then
              Result.Aliases.Add(AliasName);
          end;
      if Obj.HasKey('name') AND Obj['name'].IsString then
      begin
        SchemaName:=Obj['name'].AsString;
        Result.Name:=AvroFullName(SchemaName, SchemaNamespace);
        if (Kind IN [askRecord, askEnum, askFixed]) then
        begin
          if NOT AvroIsFullName(Result.Name) then
            raise EAvroException.CreateFmt(RCS_INVALID_SCHEMA, [APath + '.name']);
          if Names.IndexOf(Result.Name) >= 0 then
            raise EAvroException.CreateFmt(RCS_INVALID_SCHEMA, [APath + '.name']);
          Names.AddObject(Result.Name, Result);
        end;
      end;

      case Kind of
        askRecord:
        begin
          if Result.Name = '' then
            raise EAvroException.CreateFmt(RCS_INVALID_SCHEMA, [APath + '.name']);
          if NOT (Obj.HasKey('fields') AND Obj['fields'].IsArray) then
            raise EAvroException.CreateFmt(RCS_INVALID_SCHEMA, [APath + '.fields']);

          for I:=0 to Obj['fields'].AsArray.Count - 1 do
          begin
            if NOT Obj['fields'].AsArray[I].IsObject then
              raise EAvroException.CreateFmt(RCS_INVALID_SCHEMA, [APath + '.fields[]']);
            FieldObj:=Obj['fields'].AsArray[I].AsObject;
            if NOT (FieldObj.HasKey('name') AND FieldObj['name'].IsString AND FieldObj.HasKey('type')) then
              raise EAvroException.CreateFmt(RCS_INVALID_SCHEMA, [APath + '.field']);
            if FieldObj.HasKey('default') then
              DefaultValue:=FieldObj['default'].Copy
            else
              DefaultValue:=nil;
            Field:=Result.AddField(FieldObj['name'].AsString, ParseSchema(FieldObj['type'], SchemaNamespace, APath + '.' + FieldObj['name'].AsString), DefaultValue);
            if FieldObj.HasKey('aliases') AND FieldObj['aliases'].IsArray then
              for AliasIndex:=0 to FieldObj['aliases'].AsArray.Count - 1 do
                if FieldObj['aliases'].AsArray[AliasIndex].IsString AND AvroIsName(FieldObj['aliases'].AsArray[AliasIndex].AsString) AND
                   (Field.Aliases.IndexOf(FieldObj['aliases'].AsArray[AliasIndex].AsString) < 0) then
                  Field.Aliases.Add(FieldObj['aliases'].AsArray[AliasIndex].AsString);
          end;
        end;
        askEnum:
        begin
          if Result.Name = '' then
            raise EAvroException.CreateFmt(RCS_INVALID_SCHEMA, [APath + '.name']);
          if NOT (Obj.HasKey('symbols') AND Obj['symbols'].IsArray) then
            raise EAvroException.CreateFmt(RCS_INVALID_SCHEMA, [APath + '.symbols']);
          for I:=0 to Obj['symbols'].AsArray.Count - 1 do
          begin
            if (NOT Obj['symbols'].AsArray[I].IsString) OR
               (NOT AvroIsName(Obj['symbols'].AsArray[I].AsString)) OR
               (Result.Symbols.IndexOf(Obj['symbols'].AsArray[I].AsString) >= 0) then
              raise EAvroException.CreateFmt(RCS_INVALID_SCHEMA, [APath + '.symbols']);
            Result.Symbols.Add(Obj['symbols'].AsArray[I].AsString);
          end;
        end;
        askArray:
        begin
          if NOT Obj.HasKey('items') then
            raise EAvroException.CreateFmt(RCS_INVALID_SCHEMA, [APath + '.items']);
          Result.Items:=ParseSchema(Obj['items'], SchemaNamespace, APath + '.items');
        end;
        askMap:
        begin
          if NOT Obj.HasKey('values') then
            raise EAvroException.CreateFmt(RCS_INVALID_SCHEMA, [APath + '.values']);
          Result.Values:=ParseSchema(Obj['values'], SchemaNamespace, APath + '.values');
        end;
        askFixed:
        begin
          if Result.Name = '' then
            raise EAvroException.CreateFmt(RCS_INVALID_SCHEMA, [APath + '.name']);
          if NOT (Obj.HasKey('size') AND Obj['size'].IsInteger AND (Obj['size'].AsInteger > 0)) then
            raise EAvroException.CreateFmt(RCS_INVALID_SCHEMA, [APath + '.size']);
          Result.Size:=Obj['size'].AsInteger;
        end;
      end;
    except
      Result.Free;
      raise;
    end;
  end;
begin
  Names:=TStringList.Create;
  try
    Names.CaseSensitive:=True;
    Result:=ParseSchema(AValue, '', '$');
  finally
    Names.Free;
  end;
end;

class function TAvroSchema.FromJSONDocument(AJSON: TJSON): TAvroSchema;
begin
  if AJSON = nil then
    raise EAvroException.CreateFmt(RCS_INVALID_SCHEMA, ['<nil>']);
  Result:=FromJSON(AJSON.Root);
end;

function TAvroSchema.GetBranch(Index: Integer): TAvroSchema;
begin
  Result:=TAvroSchema(FSymbols.Objects[Index]);
end;

function TAvroSchema.GetBranchCount: Integer;
begin
  if FKind = askUnion then
    Result:=FSymbols.Count
  else
    Result:=0;
end;

function TAvroSchema.GetField(Index: Integer): TAvroSchemaField;
begin
  Result:=TAvroSchemaField(FFields[Index]);
end;

function TAvroSchema.GetFieldCount: Integer;
begin
  Result:=FFields.Count;
end;

function TAvroSchema.HasSymbol(const AName: String): Boolean;
begin
  Result:=FSymbols.IndexOf(AName) >= 0;
end;

function TAvroSchema.ParsingCanonicalForm: String;
var
  I: Integer;
  Resolved: TAvroSchema;
begin
  Resolved:=AvroSchemaResolve(Self);
  if Assigned(Resolved) AND (Resolved <> Self) then
    Exit(AvroJSONEncode(Resolved.Name));

  case FKind of
    askNull, askBoolean, askInt, askLong, askFloat, askDouble, askBytes, askString:
      Result:=AvroJSONEncode(AvroTypeName(FKind));
    askRecord:
      begin
        Result:='{"name":' + AvroJSONEncode(FName) + ',"type":"record","fields":[';
        for I:=0 to FieldCount - 1 do
        begin
          if I > 0 then
            Result:=Result + ',';
          Result:=Result + '{"name":' + AvroJSONEncode(Field[I].Name) + ',"type":' + Field[I].Schema.ParsingCanonicalForm + '}';
        end;
        Result:=Result + ']}';
      end;
    askEnum:
      begin
        Result:='{"name":' + AvroJSONEncode(FName) + ',"type":"enum","symbols":[';
        for I:=0 to FSymbols.Count - 1 do
        begin
          if I > 0 then
            Result:=Result + ',';
          Result:=Result + AvroJSONEncode(FSymbols[I]);
        end;
        Result:=Result + ']}';
      end;
    askArray:
      Result:='{"type":"array","items":' + FItems.ParsingCanonicalForm + '}';
    askMap:
      Result:='{"type":"map","values":' + FValues.ParsingCanonicalForm + '}';
    askUnion:
      begin
        Result:='[';
        for I:=0 to BranchCount - 1 do
        begin
          if I > 0 then
            Result:=Result + ',';
          Result:=Result + Branch[I].ParsingCanonicalForm;
        end;
        Result:=Result + ']';
      end;
    askFixed:
      Result:='{"name":' + AvroJSONEncode(FName) + ',"type":"fixed","size":' + IntToStr(FSize) + '}';
  else
    Result:=AvroJSONEncode(AvroTypeName(FKind));
  end;
end;

function TAvroSchema.Fingerprint64: UInt64;
const
  EMPTY: UInt64 = $C15D213AA4D7A795;
var
  Table: Array[0..255] of UInt64;
  FP: UInt64;
  Bytes: TBytes;
  I, J: Integer;
begin
  for I:=0 to 255 do
  begin
    FP:=I;
    for J:=0 to 7 do
      if (FP AND 1) <> 0 then
        FP:=(FP shr 1) xor EMPTY
      else
        FP:=FP shr 1;
    Table[I]:=FP;
  end;

  Result:=EMPTY;
  Bytes:=AvroUTF8Bytes(ParsingCanonicalForm);
  for I:=0 to High(Bytes) do
    Result:=(Result shr 8) xor Table[Byte(Result xor Bytes[I])];
end;

{ TAvro }

class function TAvro.CreateTemplate(AName: String): TTJAXYTemplate;
begin
  Result:=TTJAXY.CreateTemplate(AName);
end;

class function TAvro.Template(AName: String): TTJAXYTemplate;
begin
  Result:=TTJAXY.Template(AName);
end;

class function TAvro.FromFile(const AFileName, ASchemaJSON: String): TAvro;
begin
  Result:=TAvro.CreateFromFile(AFileName, ASchemaJSON);
end;

class function TAvro.FromSchemaString(const ASchemaJSON: String): TAvro;
begin
  Result:=TAvro.CreateFromSchemaString(ASchemaJSON);
end;

class function TAvro.FromSchemaJSON(AJSON: TJSON): TAvro;
begin
  Result:=TAvro.CreateFromSchemaJSON(AJSON);
end;

class function TAvro.FromStream(AStream: TStream; const ASchemaJSON: String): TAvro;
begin
  Result:=TAvro.CreateFromStream(AStream, ASchemaJSON);
end;

class function TAvro.FromString(const AValueJSON, ASchemaJSON: String): TAvro;
begin
  Result:=TAvro.CreateFromString(AValueJSON, ASchemaJSON);
end;

constructor TAvro.Create;
begin
  inherited Create;
  FContainerCodec:='null';
  FMaxContainerRecords:=AVRO_MAX_CONTAINER_BLOCK_RECORDS;
  FData:=TStringStream.Create('', TEncoding.UTF8, False);
end;

procedure TAvro.SetMaxContainerRecords(AValue: Integer);
begin
  if AValue <= 0 then
    raise EAvroException.Create('MaxContainerRecords must be positive');
  FMaxContainerRecords:=AValue;
end;

constructor TAvro.Create(ASchema: TAvroSchema);
begin
  Create;
  FSchema:=ASchema;
  if Assigned(FSchema) then
    FSchemaJSON:=FSchema.ParsingCanonicalForm;
end;

constructor TAvro.CreateFromSchemaString(const ASchemaJSON: String);
begin
  Create;
  FSchemaJSON:=ASchemaJSON;
  FSchema:=TAvroSchema.FromString(ASchemaJSON);
end;

constructor TAvro.CreateFromSchemaJSON(AJSON: TJSON);
begin
  Create;
  if Assigned(AJSON) then
    FSchemaJSON:=AJSON.WriteToString(tjaxywmCondensed);
  FSchema:=TAvroSchema.FromJSONDocument(AJSON);
end;

constructor TAvro.CreateFromString(const AValueJSON, ASchemaJSON: String);
begin
  CreateFromSchemaString(ASchemaJSON);
  LoadFromString(AValueJSON);
end;

class function TAvro.CreateFromFile(const AFileName, ASchemaJSON: String): TAvro;
begin
  Result:=TAvro.CreateFromSchemaString(ASchemaJSON);
  try
    Result.LoadFromFile(AFileName);
  except
    Result.Free;
    raise;
  end;
end;

constructor TAvro.CreateFromStream(AStream: TStream; const ASchemaJSON: String);
begin
  CreateFromSchemaString(ASchemaJSON);
  LoadFromStream(AStream);
end;

destructor TAvro.Destroy;
begin
  FSchema.Free;
  FData.Free;
  inherited;
end;

procedure TAvro.Clear;
begin
  FData.Clear;
  inherited Clear;
end;

procedure TAvro.LoadFromFile(const AFileName: String);
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

procedure TAvro.LoadFromStream(AStream: TStream);
begin
  LoadFromString(TJAXYReadUTF8(AStream));
end;

procedure TAvro.LoadFromString(const AValueJSON: String);
var
  JSON: TJSON;
begin
  TJAXYRequireValidText(AValueJSON);
  if FSchema = nil then
    raise EAvroException.Create(RCS_SCHEMA_REQUIRED);

  FData.Clear;
  FData.WriteString(AValueJSON);
  FData.Position:=0;

  JSON:=TJSON.CreateFromString(AValueJSON);
  try
    SetRoot(ReadValue(JSON.Root, FSchema, '$'));
  finally
    JSON.Free;
  end;
end;

procedure TAvro.LoadFromBinaryStream(AStream: TStream);
begin
  if FSchema = nil then
    raise EAvroException.Create(RCS_SCHEMA_REQUIRED);
  SetRoot(ReadBinaryValue(AStream, FSchema, '$'));
end;

procedure TAvro.LoadFromBinaryBytes(const ABytes: TBytes);
var
  Stream: TBytesStream;
begin
  Stream:=TBytesStream.Create(ABytes);
  try
    LoadFromBinaryStream(Stream);
  finally
    Stream.Free;
  end;
end;

procedure TAvro.LoadFromBinaryStream(AStream: TStream; AWriterSchema: TAvroSchema);
var
  WriterValue: TTJAXYValue;
begin
  if AWriterSchema = nil then
    raise EAvroException.Create(RCS_SCHEMA_REQUIRED);
  WriterValue:=ReadBinaryValue(AStream, AWriterSchema, '$');
  try
    if FSchema = nil then
      SetRoot(WriterValue.Copy)
    else
      SetRoot(ResolveValue(WriterValue, AWriterSchema, FSchema, '$'));
  finally
    WriterValue.Free;
  end;
end;

procedure TAvro.LoadFromBinaryBytes(const ABytes: TBytes; AWriterSchema: TAvroSchema);
var
  Stream: TBytesStream;
begin
  Stream:=TBytesStream.Create(ABytes);
  try
    LoadFromBinaryStream(Stream, AWriterSchema);
  finally
    Stream.Free;
  end;
end;

procedure TAvro.LoadSingleObjectFromStream(AStream: TStream);
var
  Magic: TBytes;
  Fingerprint: UInt64;
  I: Integer;
  B: Byte;
begin
  if FSchema = nil then
    raise EAvroException.Create(RCS_SCHEMA_REQUIRED);
  Magic:=AvroReadRawBytes(AStream, 2);
  if (Length(Magic) <> 2) OR (Magic[0] <> $C3) OR (Magic[1] <> $01) then
    raise EAvroException.CreateFmt(RCS_INVALID_SCHEMA, ['single-object.magic']);
  Fingerprint:=0;
  for I:=0 to 7 do
  begin
    B:=AvroReadByte(AStream);
    Fingerprint:=Fingerprint OR (UInt64(B) shl (I * 8));
  end;
  if Fingerprint <> FSchema.Fingerprint64 then
    raise EAvroException.CreateFmt(RCS_INVALID_SCHEMA, ['single-object.fingerprint']);
  LoadFromBinaryStream(AStream);
end;

procedure TAvro.LoadSingleObjectBytes(const ABytes: TBytes);
var
  Stream: TBytesStream;
begin
  Stream:=TBytesStream.Create(ABytes);
  try
    LoadSingleObjectFromStream(Stream);
  finally
    Stream.Free;
  end;
end;

procedure TAvro.LoadContainerFromFile(const AFileName: String);
var
  Stream: TFileStream;
begin
  Stream:=TFileStream.Create(AFileName, fmOpenRead OR fmShareDenyWrite);
  try
    LoadContainerFromStream(Stream);
  finally
    Stream.Free;
  end;
end;

procedure TAvro.LoadContainerFromStream(AStream: TStream);
var
  Magic, BlockSync: TBytes;
  MetaCount, KeyLen, ValueLen, BlockCount, BlockSize, MetaBlockSize: Int64;
  Key, Value: String;
  Codec: String;
  ReaderSchema: TAvroSchema;
  WriterSchema: TAvroSchema;
  Sync: TBytes;
  Block: TBytes;
  BlockStream: TBytesStream;
  RootArray: TTJAXYArray;
  Item: TTJAXYValue;
  I: Integer;
begin
  Magic:=AvroReadRawBytes(AStream, 4);
  if (Length(Magic) <> 4) OR (Magic[0] <> Ord('O')) OR (Magic[1] <> Ord('b')) OR (Magic[2] <> Ord('j')) OR (Magic[3] <> 1) then
    raise EAvroException.CreateFmt(RCS_INVALID_SCHEMA, ['container.magic']);

  Codec:='null';
  WriterSchema:=nil;
  ReaderSchema:=FSchema;
  MetaCount:=AvroReadLong(AStream);
  while MetaCount <> 0 do
  begin
    if MetaCount < 0 then
    begin
      if MetaCount = Low(Int64) then
        raise EAvroException.CreateFmt(RCS_INVALID_SCHEMA, ['container.meta.count']);
      MetaCount:=-MetaCount;
      MetaBlockSize:=AvroReadLong(AStream);
      if MetaBlockSize < 0 then
        raise EAvroException.CreateFmt(RCS_INVALID_SCHEMA, ['container.meta.size']);
    end;
    while MetaCount > 0 do
    begin
      KeyLen:=AvroReadLong(AStream);
      if (KeyLen < 0) OR (KeyLen > MaxInt) then
        raise EAvroException.CreateFmt(RCS_INVALID_SCHEMA, ['container.meta.key']);
      Key:=AvroUTF8String(AvroReadRawBytes(AStream, KeyLen));
      ValueLen:=AvroReadLong(AStream);
      if (ValueLen < 0) OR (ValueLen > MaxInt) then
        raise EAvroException.CreateFmt(RCS_INVALID_SCHEMA, ['container.meta.value']);
      Value:=AvroUTF8String(AvroReadRawBytes(AStream, ValueLen));
      if Key = 'avro.schema' then
      begin
        FreeAndNil(WriterSchema);
        WriterSchema:=TAvroSchema.FromString(Value);
        FSchemaJSON:=Value;
      end
      else if Key = 'avro.codec' then
        Codec:=Value;
      Dec(MetaCount);
    end;
    MetaCount:=AvroReadLong(AStream);
  end;

  if Codec <> 'null' then
    if Codec <> 'deflate' then
      raise EAvroException.CreateFmt(RCS_CONTAINER_CODEC, [Codec]);
  Sync:=AvroReadRawBytes(AStream, 16);

  RootArray:=TTJAXYArray.Create;
  try
    if WriterSchema = nil then
      raise EAvroException.CreateFmt(RCS_INVALID_SCHEMA, ['container.schema']);
    while AStream.Position < AStream.Size do
    begin
      BlockCount:=AvroReadLong(AStream);
      if (BlockCount <= 0) OR
        (BlockCount > FMaxContainerRecords - RootArray.Count) then
        raise EAvroException.CreateFmt(RCS_INVALID_SCHEMA, ['container.block.count']);
      BlockSize:=AvroReadLong(AStream);
      if (BlockSize < 0) OR (BlockSize > MaxInt) then
        raise EAvroException.CreateFmt(RCS_INVALID_SCHEMA, ['container.block.size']);
      Block:=AvroReadRawBytes(AStream, BlockSize);
      if Codec = 'deflate' then
        Block:=AvroDecompressDeflate(Block);
      BlockSync:=AvroReadRawBytes(AStream, Length(Sync));
      if Length(BlockSync) <> Length(Sync) then
        raise EAvroException.CreateFmt(RCS_INVALID_SCHEMA, ['container.sync']);
      for I:=0 to High(Sync) do
        if BlockSync[I] <> Sync[I] then
          raise EAvroException.CreateFmt(RCS_INVALID_SCHEMA, ['container.sync']);
      BlockStream:=TBytesStream.Create(Block);
      try
        while BlockCount > 0 do
        begin
          Item:=ReadBinaryValue(BlockStream, WriterSchema, '$');
          try
            if Assigned(ReaderSchema) then
              RootArray.Insert(RootArray.Count, ResolveValue(Item, WriterSchema, ReaderSchema, '$'))
            else
              RootArray.Insert(RootArray.Count, Item.Copy);
          finally
            Item.Free;
          end;
          Dec(BlockCount);
        end;
        if BlockCount <> 0 then
          raise EAvroException.CreateFmt(RCS_INVALID_SCHEMA, ['container.block.count']);
        if BlockStream.Position <> BlockStream.Size then
          raise EAvroException.CreateFmt(RCS_INVALID_SCHEMA, ['container.block.size']);
      finally
        BlockStream.Free;
      end;
    end;

    if RootArray.Count = 1 then
    begin
      Item:=RootArray[0].Copy;
      SetRoot(Item);
      RootArray.Free;
    end
    else
      SetRoot(RootArray);
    if FSchema = nil then
      FSchema:=WriterSchema
    else
      WriterSchema.Free;
    WriterSchema:=nil;
  except
    WriterSchema.Free;
    RootArray.Free;
    raise;
  end;
end;

procedure TAvro.ReadFromString(const AValue: String);
begin
  LoadFromString(AValue);
end;

function TAvro.ReadValue(AValue: TTJAXYValue; ASchema: TAvroSchema; const APath: String): TTJAXYValue;
var
  I: Integer;
  Obj: TTJAXYObject;
  Arr: TTJAXYArray;
  Field: TAvroSchemaField;
  BranchSchema: TAvroSchema;
  BranchValue: TTJAXYValue;
  BranchName: String;
begin
  if ASchema = nil then
    raise EAvroException.Create(RCS_SCHEMA_REQUIRED);
  ASchema:=AvroSchemaResolve(ASchema);
  if ASchema = nil then
    raise EAvroException.Create(RCS_SCHEMA_REQUIRED);

  case ASchema.Kind of
    askNull:
      if (AValue = nil) OR AValue.IsNull then
        Result:=TTJAXYNull.Create
      else
        raise EAvroException.CreateFmt(RCS_VALUE_TYPE, [APath, 'null']);
    askBoolean:
      if Assigned(AValue) AND AValue.IsBoolean then
        Result:=TTJAXYBoolean.CreateFrom(AValue.AsBoolean)
      else
        raise EAvroException.CreateFmt(RCS_VALUE_TYPE, [APath, 'boolean']);
    askInt, askLong:
      if Assigned(AValue) AND AValue.IsInteger then
        Result:=AvroLogicalRead(TTJAXYInteger.CreateFrom(AValue.AsInteger), ASchema)
      else
        raise EAvroException.CreateFmt(RCS_VALUE_TYPE, [APath, AvroTypeName(ASchema.Kind)]);
    askFloat, askDouble:
      if Assigned(AValue) AND (AValue.IsFloat OR AValue.IsInteger) then
      begin
        if AValue.IsInteger then
          Result:=TTJAXYFloat.CreateFrom(AValue.AsInteger)
        else
          Result:=TTJAXYFloat.CreateFrom(AValue.AsFloat);
      end
      else
        raise EAvroException.CreateFmt(RCS_VALUE_TYPE, [APath, AvroTypeName(ASchema.Kind)]);
    askBytes, askString, askFixed:
      if Assigned(AValue) AND AValue.IsString then
      begin
        if (ASchema.LogicalType = 'uuid') AND NOT AvroIsUUID(AValue.AsString) then
          raise EAvroException.CreateFmt(RCS_VALUE_TYPE, [APath, 'uuid']);
        if (ASchema.Kind = askFixed) AND (Length(AValue.AsString) <> ASchema.Size) then
          raise EAvroException.CreateFmt(RCS_VALUE_TYPE, [APath, 'fixed']);
        Result:=TTJAXYString.CreateFrom(AValue.AsString);
        if ASchema.LogicalType = 'decimal' then
          Result:=AvroDecimalRead(Result, ASchema);
      end
      else
        raise EAvroException.CreateFmt(RCS_VALUE_TYPE, [APath, AvroTypeName(ASchema.Kind)]);
    askEnum:
      if Assigned(AValue) AND AValue.IsString then
      begin
        if NOT ASchema.HasSymbol(AValue.AsString) then
          raise EAvroException.CreateFmt(RCS_ENUM_SYMBOL, [AValue.AsString, APath]);
        Result:=TTJAXYString.CreateFrom(AValue.AsString);
      end
      else
        raise EAvroException.CreateFmt(RCS_VALUE_TYPE, [APath, 'enum']);
    askRecord:
    begin
      if NOT (Assigned(AValue) AND AValue.IsObject) then
        raise EAvroException.CreateFmt(RCS_VALUE_TYPE, [APath, 'record']);

      Obj:=TTJAXYObject.Create;
      try
        for I:=0 to ASchema.FieldCount - 1 do
        begin
          Field:=ASchema.Field[I];
          if AValue.AsObject.HasKey(Field.Name) then
            Obj.Add(Field.Name, ReadValue(AValue.AsObject[Field.Name], Field.Schema, AvroPath(APath, Field.Name)))
          else if Field.HasDefault then
            Obj.Add(Field.Name, AvroCopyOrNull(Field.Default))
          else
            raise EAvroException.CreateFmt(RCS_FIELD_REQUIRED, [Field.Name, APath]);
        end;
        Result:=Obj;
      except
        Obj.Free;
        raise;
      end;
    end;
    askArray:
    begin
      if NOT (Assigned(AValue) AND AValue.IsArray) then
        raise EAvroException.CreateFmt(RCS_VALUE_TYPE, [APath, 'array']);
      Arr:=TTJAXYArray.Create;
      try
        for I:=0 to AValue.AsArray.Count - 1 do
          Arr.Insert(Arr.Count, ReadValue(AValue.AsArray[I], ASchema.Items, APath + '[' + IntToStr(I) + ']'));
        Result:=Arr;
      except
        Arr.Free;
        raise;
      end;
    end;
    askMap:
    begin
      if NOT (Assigned(AValue) AND AValue.IsObject) then
        raise EAvroException.CreateFmt(RCS_VALUE_TYPE, [APath, 'map']);
      Obj:=TTJAXYObject.Create;
      try
        for I:=0 to AValue.AsObject.Count - 1 do
          Obj.Add(AValue.AsObject.Name[I], ReadValue(AValue.AsObject.Item[I], ASchema.Values, AvroPath(APath, AValue.AsObject.Name[I])));
        Result:=Obj;
      except
        Obj.Free;
        raise;
      end;
    end;
    askUnion:
    begin
      if Assigned(AValue) AND AValue.IsNull then
      begin
        for I:=0 to ASchema.BranchCount - 1 do
          if ASchema.Branch[I].Kind = askNull then
            Exit(TTJAXYNull.Create);
        raise EAvroException.CreateFmt(RCS_UNION_VALUE, [APath]);
      end;

      if NOT (Assigned(AValue) AND AValue.IsObject AND (AValue.AsObject.Count = 1)) then
        raise EAvroException.CreateFmt(RCS_UNION_VALUE, [APath]);

      BranchName:=AValue.AsObject.Name[0];
      BranchValue:=AValue.AsObject.Item[0];
      for I:=0 to ASchema.BranchCount - 1 do
      begin
        BranchSchema:=ASchema.Branch[I];
        if BranchSchema.BranchName = BranchName then
          Exit(ReadValue(BranchValue, BranchSchema, APath + '<' + BranchName + '>'));
      end;
      raise EAvroException.CreateFmt(RCS_UNION_VALUE, [APath]);
    end;
  else
    raise EAvroException.CreateFmt(RCS_VALUE_TYPE, [APath, AvroTypeName(ASchema.Kind)]);
  end;
end;

procedure TAvro.SaveToFile(const AFileName: String);
begin
  WriteToFile(AFileName);
end;

procedure TAvro.SaveToStream(AStream: TStream);
var
  S: String;
begin
  S:=WriteToString;
  TJAXYWriteUTF8(AStream, S);
end;

procedure TAvro.SaveToBinaryStream(AStream: TStream);
begin
  if FSchema = nil then
    raise EAvroException.Create(RCS_SCHEMA_REQUIRED);
  WriteBinaryValue(AStream, Root, FSchema, '$');
end;

function TAvro.WriteToBinaryBytes: TBytes;
var
  Stream: TBytesStream;
begin
  Stream:=TBytesStream.Create;
  try
    SaveToBinaryStream(Stream);
    Result:=Stream.Bytes;
    SetLength(Result, Stream.Size);
  finally
    Stream.Free;
  end;
end;

procedure TAvro.SaveSingleObjectToStream(AStream: TStream);
var
  Fingerprint: UInt64;
  I: Integer;
begin
  if FSchema = nil then
    raise EAvroException.Create(RCS_SCHEMA_REQUIRED);
  AvroWriteByte(AStream, $C3);
  AvroWriteByte(AStream, $01);
  Fingerprint:=FSchema.Fingerprint64;
  for I:=0 to 7 do
    AvroWriteByte(AStream, Byte((Fingerprint shr (I * 8)) AND $FF));
  SaveToBinaryStream(AStream);
end;

function TAvro.WriteSingleObjectBytes: TBytes;
var
  Stream: TBytesStream;
begin
  Stream:=TBytesStream.Create;
  try
    SaveSingleObjectToStream(Stream);
    Result:=Stream.Bytes;
    SetLength(Result, Stream.Size);
  finally
    Stream.Free;
  end;
end;

procedure TAvro.SaveContainerToFile(const AFileName: String);
var
  Stream: TFileStream;
begin
  Stream:=TFileStream.Create(AFileName, fmCreate);
  try
    SaveContainerToStream(Stream);
  finally
    Stream.Free;
  end;
end;

procedure TAvro.SaveContainerToStream(AStream: TStream);
var
  SchemaText: String;
  Binary: TBytes;
  Sync: TBytes;
  I: Integer;

  procedure WriteMeta(const AKey, AValue: String);
  var
    B: TBytes;
  begin
    B:=AvroUTF8Bytes(AKey);
    AvroWriteLong(AStream, Length(B));
    AvroWriteRawBytes(AStream, B);
    B:=AvroUTF8Bytes(AValue);
    AvroWriteLong(AStream, Length(B));
    AvroWriteRawBytes(AStream, B);
  end;

begin
  if FSchema = nil then
    raise EAvroException.Create(RCS_SCHEMA_REQUIRED);
  SchemaText:=FSchemaJSON;
  if SchemaText = '' then
    SchemaText:=FSchema.ParsingCanonicalForm;
  Binary:=WriteToBinaryBytes;
  if SameText(FContainerCodec, 'deflate') then
    Binary:=AvroCompressDeflate(Binary)
  else if NOT SameText(FContainerCodec, 'null') then
    raise EAvroException.CreateFmt(RCS_CONTAINER_CODEC, [FContainerCodec]);

  AvroWriteRawBytes(AStream, TBytes.Create(Ord('O'), Ord('b'), Ord('j'), 1));
  AvroWriteLong(AStream, 2);
  WriteMeta('avro.schema', SchemaText);
  WriteMeta('avro.codec', FContainerCodec);
  AvroWriteLong(AStream, 0);

  SetLength(Sync, 16);
  for I:=0 to 15 do
    Sync[I]:=Byte((FSchema.Fingerprint64 shr ((I mod 8) * 8)) AND $FF);
  AvroWriteRawBytes(AStream, Sync);

  AvroWriteLong(AStream, 1);
  AvroWriteLong(AStream, Length(Binary));
  AvroWriteRawBytes(AStream, Binary);
  AvroWriteRawBytes(AStream, Sync);
end;

procedure TAvro.SetSchema(AValue: TAvroSchema);
begin
  if FSchema = AValue then
    Exit;
  FSchema.Free;
  FSchema:=AValue;
  if Assigned(FSchema) then
    FSchemaJSON:=FSchema.ParsingCanonicalForm
  else
    FSchemaJSON:='';
end;

function TAvro.ReadBinaryValue(AStream: TStream; ASchema: TAvroSchema; const APath: String): TTJAXYValue;
var
  I: Integer;
  Count: Int64;
  BlockCount: Int64;
  Obj: TTJAXYObject;
  Arr: TTJAXYArray;
  Bytes: TBytes;
  Field: TAvroSchemaField;
  BranchIndex: Int64;
  SingleValue: Single;
  DoubleValue: Double;
  MapKey: String;
begin
  ASchema:=AvroSchemaResolve(ASchema);
  if ASchema = nil then
    raise EAvroException.Create(RCS_SCHEMA_REQUIRED);

  case ASchema.Kind of
    askNull:
      Result:=TTJAXYNull.Create;
    askBoolean:
      Result:=TTJAXYBoolean.CreateFrom(AvroReadByte(AStream) <> 0);
    askInt, askLong:
      Result:=AvroLogicalRead(TTJAXYInteger.CreateFrom(AvroReadLong(AStream)), ASchema);
    askFloat:
      begin
        Bytes:=AvroReadRawBytes(AStream, SizeOf(SingleValue));
        Move(Bytes[0], SingleValue, SizeOf(SingleValue));
        Result:=TTJAXYFloat.CreateFrom(SingleValue);
      end;
    askDouble:
      begin
        Bytes:=AvroReadRawBytes(AStream, SizeOf(DoubleValue));
        Move(Bytes[0], DoubleValue, SizeOf(DoubleValue));
        Result:=TTJAXYFloat.CreateFrom(DoubleValue);
      end;
    askBytes:
      begin
        Count:=AvroReadLong(AStream);
        Result:=TTJAXYString.CreateFrom(AvroBytesToString(AvroReadRawBytes(AStream, Count)));
        if ASchema.LogicalType = 'decimal' then
          Result:=AvroDecimalRead(Result, ASchema);
      end;
    askString:
      begin
        Count:=AvroReadLong(AStream);
        Result:=TTJAXYString.CreateFrom(AvroUTF8String(AvroReadRawBytes(AStream, Count)));
      end;
    askFixed:
      begin
        Result:=TTJAXYString.CreateFrom(AvroBytesToString(AvroReadRawBytes(AStream, ASchema.Size)));
        if ASchema.LogicalType = 'decimal' then
          Result:=AvroDecimalRead(Result, ASchema);
      end;
    askEnum:
      begin
        I:=AvroReadLong(AStream);
        if (I < 0) OR (I >= ASchema.Symbols.Count) then
          raise EAvroException.CreateFmt(RCS_ENUM_SYMBOL, [IntToStr(I), APath]);
        Result:=TTJAXYString.CreateFrom(ASchema.Symbols[I]);
      end;
    askRecord:
      begin
        Obj:=TTJAXYObject.Create;
        try
          for I:=0 to ASchema.FieldCount - 1 do
          begin
            Field:=ASchema.Field[I];
            Obj.Add(Field.Name, ReadBinaryValue(AStream, Field.Schema, AvroPath(APath, Field.Name)));
          end;
          Result:=Obj;
        except
          Obj.Free;
          raise;
        end;
      end;
    askArray:
      begin
        Arr:=TTJAXYArray.Create;
        try
          BlockCount:=AvroReadLong(AStream);
          while BlockCount <> 0 do
          begin
            if BlockCount < 0 then
            begin
              BlockCount:=-BlockCount;
              AvroReadLong(AStream);
            end;
            for I:=0 to BlockCount - 1 do
              Arr.Insert(Arr.Count, ReadBinaryValue(AStream, ASchema.Items, APath + '[]'));
            BlockCount:=AvroReadLong(AStream);
          end;
          Result:=Arr;
        except
          Arr.Free;
          raise;
        end;
      end;
    askMap:
      begin
        Obj:=TTJAXYObject.Create;
        try
          BlockCount:=AvroReadLong(AStream);
          while BlockCount <> 0 do
          begin
            if BlockCount < 0 then
            begin
              BlockCount:=-BlockCount;
              AvroReadLong(AStream);
            end;
            for I:=0 to BlockCount - 1 do
            begin
              Count:=AvroReadLong(AStream);
              MapKey:=AvroUTF8String(AvroReadRawBytes(AStream, Count));
              Obj.Add(MapKey, ReadBinaryValue(AStream, ASchema.Values, APath + '{}'));
            end;
            BlockCount:=AvroReadLong(AStream);
          end;
          Result:=Obj;
        except
          Obj.Free;
          raise;
        end;
      end;
    askUnion:
      begin
        BranchIndex:=AvroReadLong(AStream);
        if (BranchIndex < 0) OR (BranchIndex >= ASchema.BranchCount) then
          raise EAvroException.CreateFmt(RCS_UNION_VALUE, [APath]);
        Result:=ReadBinaryValue(AStream, ASchema.Branch[BranchIndex], APath + '<' + IntToStr(BranchIndex) + '>');
      end;
  else
    raise EAvroException.CreateFmt(RCS_VALUE_TYPE, [APath, AvroTypeName(ASchema.Kind)]);
  end;
end;

function TAvro.ResolveValue(AValue: TTJAXYValue; AWriterSchema, AReaderSchema: TAvroSchema; const APath: String): TTJAXYValue;
var
  I, AliasIndex: Integer;
  Obj: TTJAXYObject;
  Arr: TTJAXYArray;
  Field: TAvroSchemaField;
  SourceName: String;
  WriterField: TAvroSchemaField;
begin
  AWriterSchema:=AvroSchemaResolve(AWriterSchema);
  AReaderSchema:=AvroSchemaResolve(AReaderSchema);
  if (AWriterSchema = nil) OR (AReaderSchema = nil) then
    raise EAvroException.Create(RCS_SCHEMA_REQUIRED);

  if AReaderSchema.Kind = askUnion then
    for I:=0 to AReaderSchema.BranchCount - 1 do
      try
        Exit(ResolveValue(AValue, AWriterSchema, AReaderSchema.Branch[I], APath));
      except
        on E: EAvroException do
          Continue;
      end;

  if AWriterSchema.Kind = askUnion then
    for I:=0 to AWriterSchema.BranchCount - 1 do
      try
        Exit(ResolveValue(AValue, AWriterSchema.Branch[I], AReaderSchema, APath));
      except
        on E: EAvroException do
          Continue;
      end;

  case AReaderSchema.Kind of
    askLong:
      if AWriterSchema.Kind IN [askInt, askLong] then
        Exit(ReadValue(AValue, AReaderSchema, APath));
    askFloat:
      if AWriterSchema.Kind IN [askInt, askLong, askFloat] then
        Exit(ReadValue(AValue, AReaderSchema, APath));
    askDouble:
      if AWriterSchema.Kind IN [askInt, askLong, askFloat, askDouble] then
        Exit(ReadValue(AValue, AReaderSchema, APath));
    askRecord:
      begin
        if (AWriterSchema.Kind <> askRecord) OR NOT (Assigned(AValue) AND AValue.IsObject) then
          raise EAvroException.CreateFmt(RCS_VALUE_TYPE, [APath, 'record']);
        Obj:=TTJAXYObject.Create;
        try
          for I:=0 to AReaderSchema.FieldCount - 1 do
          begin
            Field:=AReaderSchema.Field[I];
            SourceName:=Field.Name;
            WriterField:=AWriterSchema.FindField(SourceName);
            if (WriterField = nil) OR (NOT AValue.AsObject.HasKey(SourceName)) then
            begin
              for AliasIndex:=0 to Field.Aliases.Count - 1 do
                if AValue.AsObject.HasKey(Field.Aliases[AliasIndex]) then
                begin
                  SourceName:=Field.Aliases[AliasIndex];
                  WriterField:=AWriterSchema.FindField(SourceName);
                  Break;
                end;
            end;

            if AValue.AsObject.HasKey(SourceName) then
            begin
              if Assigned(WriterField) then
                Obj.Add(Field.Name, ResolveValue(AValue.AsObject[SourceName], WriterField.Schema, Field.Schema, AvroPath(APath, Field.Name)))
              else
                Obj.Add(Field.Name, ReadValue(AValue.AsObject[SourceName], Field.Schema, AvroPath(APath, Field.Name)));
            end
            else if Field.HasDefault then
              Obj.Add(Field.Name, AvroCopyOrNull(Field.Default))
            else
              raise EAvroException.CreateFmt(RCS_FIELD_REQUIRED, [Field.Name, APath]);
          end;
          Exit(Obj);
        except
          Obj.Free;
          raise;
        end;
      end;
    askArray:
      begin
        if (AWriterSchema.Kind <> askArray) OR NOT (Assigned(AValue) AND AValue.IsArray) then
          raise EAvroException.CreateFmt(RCS_VALUE_TYPE, [APath, 'array']);
        Arr:=TTJAXYArray.Create;
        try
          for I:=0 to AValue.AsArray.Count - 1 do
            Arr.Insert(Arr.Count, ResolveValue(AValue.AsArray[I], AWriterSchema.Items, AReaderSchema.Items, APath + '[]'));
          Exit(Arr);
        except
          Arr.Free;
          raise;
        end;
      end;
    askMap:
      begin
        if (AWriterSchema.Kind <> askMap) OR NOT (Assigned(AValue) AND AValue.IsObject) then
          raise EAvroException.CreateFmt(RCS_VALUE_TYPE, [APath, 'map']);
        Obj:=TTJAXYObject.Create;
        try
          for I:=0 to AValue.AsObject.Count - 1 do
            Obj.Add(AValue.AsObject.Name[I], ResolveValue(AValue.AsObject.Item[I], AWriterSchema.Values, AReaderSchema.Values, AvroPath(APath, AValue.AsObject.Name[I])));
          Exit(Obj);
        except
          Obj.Free;
          raise;
        end;
      end;
  end;

  if AWriterSchema.Kind = AReaderSchema.Kind then
    Result:=ReadValue(AValue, AReaderSchema, APath)
  else
    raise EAvroException.CreateFmt(RCS_VALUE_TYPE, [APath, AvroTypeName(AReaderSchema.Kind)]);
end;

procedure TAvro.WriteBinaryValue(AStream: TStream; AValue: TTJAXYValue; ASchema: TAvroSchema; const APath: String);
var
  I: Integer;
  Bytes: TBytes;
  Field: TAvroSchemaField;
  BranchSchema: TAvroSchema;
  BranchValue: TTJAXYValue;
  TryStream: TBytesStream;
  LogicalValue: TTJAXYValue;
  SingleValue: Single;
  DoubleValue: Double;
begin
  ASchema:=AvroSchemaResolve(ASchema);
  if ASchema = nil then
    raise EAvroException.Create(RCS_SCHEMA_REQUIRED);

  case ASchema.Kind of
    askNull:
      if NOT ((AValue = nil) OR AValue.IsNull) then
        raise EAvroException.CreateFmt(RCS_VALUE_TYPE, [APath, 'null']);
    askBoolean:
      begin
        if NOT (Assigned(AValue) AND AValue.IsBoolean) then
          raise EAvroException.CreateFmt(RCS_VALUE_TYPE, [APath, 'boolean']);
        AvroWriteByte(AStream, Ord(AValue.AsBoolean));
      end;
    askInt, askLong:
      begin
        BranchValue:=AvroLogicalWrite(AValue, ASchema);
        try
          if NOT BranchValue.IsInteger then
            raise EAvroException.CreateFmt(RCS_VALUE_TYPE, [APath, AvroTypeName(ASchema.Kind)]);
          AvroWriteLong(AStream, BranchValue.AsInteger);
        finally
          BranchValue.Free;
        end;
      end;
    askFloat:
      begin
        if NOT (Assigned(AValue) AND (AValue.IsFloat OR AValue.IsInteger)) then
          raise EAvroException.CreateFmt(RCS_VALUE_TYPE, [APath, 'float']);
        SingleValue:=AValue.AsFloat;
        AStream.WriteBuffer(SingleValue, SizeOf(SingleValue));
      end;
    askDouble:
      begin
        if NOT (Assigned(AValue) AND (AValue.IsFloat OR AValue.IsInteger)) then
          raise EAvroException.CreateFmt(RCS_VALUE_TYPE, [APath, 'double']);
        DoubleValue:=AValue.AsFloat;
        AStream.WriteBuffer(DoubleValue, SizeOf(DoubleValue));
      end;
    askBytes:
      begin
        LogicalValue:=AValue;
        if ASchema.LogicalType = 'decimal' then
          LogicalValue:=AvroDecimalWrite(AValue, ASchema);
        try
          if NOT (Assigned(LogicalValue) AND LogicalValue.IsString) then
            raise EAvroException.CreateFmt(RCS_VALUE_TYPE, [APath, 'bytes']);
          Bytes:=AvroStringToBytes(LogicalValue.AsString);
          AvroWriteLong(AStream, Length(Bytes));
          AvroWriteRawBytes(AStream, Bytes);
        finally
          if LogicalValue <> AValue then
            LogicalValue.Free;
        end;
      end;
    askString:
      begin
        if NOT (Assigned(AValue) AND AValue.IsString) then
          raise EAvroException.CreateFmt(RCS_VALUE_TYPE, [APath, 'string']);
        if (ASchema.LogicalType = 'uuid') AND NOT AvroIsUUID(AValue.AsString) then
          raise EAvroException.CreateFmt(RCS_VALUE_TYPE, [APath, 'uuid']);
        Bytes:=AvroUTF8Bytes(AValue.AsString);
        AvroWriteLong(AStream, Length(Bytes));
        AvroWriteRawBytes(AStream, Bytes);
      end;
    askFixed:
      begin
        LogicalValue:=AValue;
        if ASchema.LogicalType = 'decimal' then
          LogicalValue:=AvroDecimalWrite(AValue, ASchema);
        try
          if NOT (Assigned(LogicalValue) AND LogicalValue.IsString AND (Length(LogicalValue.AsString) = ASchema.Size)) then
            raise EAvroException.CreateFmt(RCS_VALUE_TYPE, [APath, 'fixed']);
          AvroWriteRawBytes(AStream, AvroStringToBytes(LogicalValue.AsString));
        finally
          if LogicalValue <> AValue then
            LogicalValue.Free;
        end;
      end;
    askEnum:
      begin
        if NOT (Assigned(AValue) AND AValue.IsString) then
          raise EAvroException.CreateFmt(RCS_VALUE_TYPE, [APath, 'enum']);
        I:=ASchema.Symbols.IndexOf(AValue.AsString);
        if I < 0 then
          raise EAvroException.CreateFmt(RCS_ENUM_SYMBOL, [AValue.AsString, APath]);
        AvroWriteLong(AStream, I);
      end;
    askRecord:
      begin
        if NOT (Assigned(AValue) AND AValue.IsObject) then
          raise EAvroException.CreateFmt(RCS_VALUE_TYPE, [APath, 'record']);
        for I:=0 to ASchema.FieldCount - 1 do
        begin
          Field:=ASchema.Field[I];
          if AValue.AsObject.HasKey(Field.Name) then
            WriteBinaryValue(AStream, AValue.AsObject[Field.Name], Field.Schema, AvroPath(APath, Field.Name))
          else if Field.HasDefault then
            WriteBinaryValue(AStream, Field.Default, Field.Schema, AvroPath(APath, Field.Name))
          else
            raise EAvroException.CreateFmt(RCS_FIELD_REQUIRED, [Field.Name, APath]);
        end;
      end;
    askArray:
      begin
        if NOT (Assigned(AValue) AND AValue.IsArray) then
          raise EAvroException.CreateFmt(RCS_VALUE_TYPE, [APath, 'array']);
        if AValue.AsArray.Count > 0 then
        begin
          AvroWriteLong(AStream, AValue.AsArray.Count);
          for I:=0 to AValue.AsArray.Count - 1 do
            WriteBinaryValue(AStream, AValue.AsArray[I], ASchema.Items, APath + '[]');
        end;
        AvroWriteLong(AStream, 0);
      end;
    askMap:
      begin
        if NOT (Assigned(AValue) AND AValue.IsObject) then
          raise EAvroException.CreateFmt(RCS_VALUE_TYPE, [APath, 'map']);
        if AValue.AsObject.Count > 0 then
        begin
          AvroWriteLong(AStream, AValue.AsObject.Count);
          for I:=0 to AValue.AsObject.Count - 1 do
          begin
            Bytes:=AvroUTF8Bytes(AValue.AsObject.Name[I]);
            AvroWriteLong(AStream, Length(Bytes));
            AvroWriteRawBytes(AStream, Bytes);
            WriteBinaryValue(AStream, AValue.AsObject.Item[I], ASchema.Values, APath + '{}');
          end;
        end;
        AvroWriteLong(AStream, 0);
      end;
    askUnion:
      begin
        if Assigned(AValue) AND AValue.IsNull then
          for I:=0 to ASchema.BranchCount - 1 do
            if AvroSchemaResolve(ASchema.Branch[I]).Kind = askNull then
            begin
              AvroWriteLong(AStream, I);
              Exit;
            end;
        for I:=0 to ASchema.BranchCount - 1 do
        begin
          BranchSchema:=AvroSchemaResolve(ASchema.Branch[I]);
          if BranchSchema.Kind = askNull then
            Continue;
          TryStream:=TBytesStream.Create;
          try
            try
              WriteBinaryValue(TryStream, AValue, BranchSchema, APath + '<' + BranchSchema.BranchName + '>');
              AvroWriteLong(AStream, I);
              if TryStream.Size > 0 then
                AStream.WriteBuffer(TryStream.Bytes[0], TryStream.Size);
              Exit;
            except
              on E: EAvroException do
                Continue;
            end;
          finally
            TryStream.Free;
          end;
        end;
        raise EAvroException.CreateFmt(RCS_UNION_VALUE, [APath]);
      end;
  else
    raise EAvroException.CreateFmt(RCS_VALUE_TYPE, [APath, AvroTypeName(ASchema.Kind)]);
  end;
end;

function TAvro.WriteValue(AValue: TTJAXYValue; ASchema: TAvroSchema; const APath: String): TTJAXYValue;
var
  I: Integer;
  Obj: TTJAXYObject;
  Arr: TTJAXYArray;
  Field: TAvroSchemaField;
  BranchSchema: TAvroSchema;
  BranchObj: TTJAXYObject;
  LogicalValue: TTJAXYValue;
begin
  if ASchema = nil then
    raise EAvroException.Create(RCS_SCHEMA_REQUIRED);
  ASchema:=AvroSchemaResolve(ASchema);
  if ASchema = nil then
    raise EAvroException.Create(RCS_SCHEMA_REQUIRED);

  if ASchema.LogicalType <> '' then
  begin
    if ASchema.LogicalType = 'uuid' then
    begin
      if (AValue = nil) OR (NOT AValue.IsString) OR (NOT AvroIsUUID(AValue.AsString)) then
        raise EAvroException.CreateFmt(RCS_VALUE_TYPE, [APath, 'uuid']);
      Exit(AValue.Copy);
    end;
    if ASchema.LogicalType = 'decimal' then
      Exit(AvroDecimalWrite(AValue, ASchema));
    LogicalValue:=AvroLogicalWrite(AValue, ASchema);
    try
      if ASchema.Kind IN [askInt, askLong] then
      begin
        if NOT LogicalValue.IsInteger then
          raise EAvroException.CreateFmt(RCS_VALUE_TYPE, [APath, AvroTypeName(ASchema.Kind)]);
        Exit(TTJAXYInteger.CreateFrom(LogicalValue.AsInteger));
      end;
      Exit(LogicalValue.Copy);
    finally
      LogicalValue.Free;
    end;
  end;

  case ASchema.Kind of
    askUnion:
    begin
      if Assigned(AValue) AND AValue.IsNull then
      begin
        for I:=0 to ASchema.BranchCount - 1 do
          if ASchema.Branch[I].Kind = askNull then
            Exit(TTJAXYNull.Create);
      end;

      for I:=0 to ASchema.BranchCount - 1 do
      begin
        BranchSchema:=ASchema.Branch[I];
        if BranchSchema.Kind = askNull then
          Continue;
        try
          BranchObj:=TTJAXYObject.Create;
          try
            BranchObj.Add(BranchSchema.BranchName, WriteValue(AValue, BranchSchema, APath + '<' + BranchSchema.BranchName + '>'));
            Exit(BranchObj);
          except
            BranchObj.Free;
            raise;
          end;
        except
          on E: EAvroException do
            Continue;
        end;
      end;
      raise EAvroException.CreateFmt(RCS_UNION_VALUE, [APath]);
    end;
    askRecord:
    begin
      if NOT (Assigned(AValue) AND AValue.IsObject) then
        raise EAvroException.CreateFmt(RCS_VALUE_TYPE, [APath, 'record']);
      Obj:=TTJAXYObject.Create;
      try
        for I:=0 to ASchema.FieldCount - 1 do
        begin
          Field:=ASchema.Field[I];
          if AValue.AsObject.HasKey(Field.Name) then
            Obj.Add(Field.Name, WriteValue(AValue.AsObject[Field.Name], Field.Schema, AvroPath(APath, Field.Name)))
          else if Field.HasDefault then
            Obj.Add(Field.Name, AvroCopyOrNull(Field.Default))
          else
            raise EAvroException.CreateFmt(RCS_FIELD_REQUIRED, [Field.Name, APath]);
        end;
        Result:=Obj;
      except
        Obj.Free;
        raise;
      end;
    end;
    askArray:
    begin
      if NOT (Assigned(AValue) AND AValue.IsArray) then
        raise EAvroException.CreateFmt(RCS_VALUE_TYPE, [APath, 'array']);
      Arr:=TTJAXYArray.Create;
      try
        for I:=0 to AValue.AsArray.Count - 1 do
          Arr.Insert(Arr.Count, WriteValue(AValue.AsArray[I], ASchema.Items, APath + '[' + IntToStr(I) + ']'));
        Result:=Arr;
      except
        Arr.Free;
        raise;
      end;
    end;
    askMap:
    begin
      if NOT (Assigned(AValue) AND AValue.IsObject) then
        raise EAvroException.CreateFmt(RCS_VALUE_TYPE, [APath, 'map']);
      Obj:=TTJAXYObject.Create;
      try
        for I:=0 to AValue.AsObject.Count - 1 do
          Obj.Add(AValue.AsObject.Name[I], WriteValue(AValue.AsObject.Item[I], ASchema.Values, AvroPath(APath, AValue.AsObject.Name[I])));
        Result:=Obj;
      except
        Obj.Free;
        raise;
      end;
    end;
  else
    Result:=ReadValue(AValue, ASchema, APath);
  end;
end;

function TAvro.WriteToString(AWriteMode: TTJAXYStringWriteMode): String;
var
  Value: TTJAXYValue;
  Writer: TTJAXYWriter;
begin
  if FSchema = nil then
    raise EAvroException.Create(RCS_SCHEMA_REQUIRED);
  Value:=WriteValue(Root, FSchema, '$');
  try
    Writer:=TTJAXYWriter.Create(AWriteMode);
    try
      Result:=Writer.Write(Value);
    finally
      Writer.Free;
    end;
  finally
    Value.Free;
  end;
end;

end.
