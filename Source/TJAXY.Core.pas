(******************************************************************************)
(*                                                                            *)
(*  Delphi TJAXY Shared Parser Model                                          *)
(*                                                                            *)
(*  Version     : 0.01                                                        *)
(*  License     : BSD 2-Clause                                                *)
(*  Author      : NaliLord / TJAXY contributors                               *)
(*                                                                            *)
(*  This unit owns the shared DOM used by JSON/YAML/XML/TOML style parsers.   *)
(*                                                                            *)
(******************************************************************************)

unit TJAXY.Core;

interface

uses
  SysUtils, Classes, Variants, DateUtils;

{$IFNDEF FPC}
{$DEFINE TJAXY_USE_RTTI}
{$ENDIF}

type
  TTJAXYType = (tjaxytNull, tjaxytInteger, tjaxytFloat, tjaxytString, tjaxytBoolean, tjaxytObject, tjaxytArray);
  TTJAXYStringWriteMode = (tjaxywmReadable, tjaxywmCondensed);
  TTJAXYEnumMode = (tjaxjemOrdinal, tjaxjemName);
  TTJAXYNameCase = (tjaxyncPreserve, tjaxyncLower, tjaxyncUpper, tjaxyncPascal, tjaxyncCamel, tjaxyncSnake, tjaxyncScreamingSnake);
  TTJAXYUnknownEnumRead = (tjaxjurIgnore, tjaxjurDefaultFirst, tjaxjurRaise);

  TTJAXYSerializerRules = record
    EnumMode: TTJAXYEnumMode;
    EnumNameCase: TTJAXYNameCase;
    EnumStripPrefixes: TArray<String>;
    EnumAcceptOrdinalOnRead: Boolean;
    EnumAcceptRawNameOnRead: Boolean;
    EnumUnknownRead: TTJAXYUnknownEnumRead;
  end;

  TTJAXYObjectFactory = function: TObject;

  TTJAXYDocument = class;
  TTJAXY = class;
  TTJAXYParser = class;
  TTJAXYValue = class;
  TTJAXYNull = class;
  TTJAXYString = class;
  TTJAXYDateTime = class;
  TTJAXYInteger = class;
  TTJAXYFloat = class;
  TTJAXYBoolean = class;
  TTJAXYObject = class;
  TTJAXYArray = class;
  TTJAXYTemplate = class;

  TTJAXYMapperCapability = (tjaxymcObjects, tjaxymcRecords, tjaxymcFactories);
  TTJAXYMapperCapabilities = set of TTJAXYMapperCapability;

  TTJAXYMappingDiagnostic = record
    Path: String;
    Message: String;
  end;

  ITJAXYObjectMapper = interface
    ['{73F5C775-45DD-4D9C-B2B2-82A5F13C92C0}']
    function Capabilities: TTJAXYMapperCapabilities;
    function SerializeObject(AObject: TObject): TTJAXYValue;
    procedure AssignObject(AObject: TObject; ASource: TTJAXYObject);
    function SerializeRecord(ATypeInfo, ARecord: Pointer): TTJAXYValue;
    procedure AssignRecord(ATypeInfo, ARecord: Pointer; ASource: TTJAXYObject);
    procedure RegisterFactory(AClass: TClass; AFactory: TTJAXYObjectFactory);
    procedure UnregisterFactory(AClass: TClass);
  end;

  TTJAXYValueClass = class of TTJAXYValue;
  TTJAXYDateTimeKind = (tjaxydtkLocalDate, tjaxydtkLocalTime, tjaxydtkLocalDateTime, tjaxydtkOffsetDateTime);
  TTJAXYTemplateType = (tjaxyttNull, tjaxyttInteger, tjaxyttFloat, tjaxyttString, tjaxyttBoolean, tjaxyttObject, tjaxyttArray, tjaxyttName, tjaxyttUnixTime, tjaxyttTemplate, tjaxyttCallback);
  TTJAXYTemplateFlag = (tjaxytfOmitEmpty);
  TTJAXYTemplateFlags = set of TTJAXYTemplateFlag;
  TTJAXYTemplateFillCallback = procedure(ATemplateName, AKeyName: String; var AValue: TTJAXYValue) of object;

  ETJAXYException = class(Exception);

  TTJAXYDocument = class(TPersistent)
  private
    FRoot: TTJAXYValue;
    function GetArrayValue(Index: Integer): TTJAXYValue;
    function GetAsArray: TTJAXYArray;
    function GetAsObject: TTJAXYObject;
    function GetIsArray: Boolean;
    function GetIsObject: Boolean;
    function GetObjectValue(Key: String): TTJAXYValue;
    class function GetSerializerRules: TTJAXYSerializerRules; static;
    class procedure SetSerializerRules(const AValue: TTJAXYSerializerRules); static;
    class function GetMapper: ITJAXYObjectMapper; static;
    class procedure SetMapper(const AValue: ITJAXYObjectMapper); static;
    class function GetMapperCapabilities: TTJAXYMapperCapabilities; static;
  protected
    procedure SetRoot(AValue: TTJAXYValue); virtual;
    class procedure BeginMappingOperation; static;
    class procedure EndMappingOperation; static;
    class procedure PushMappingRules(const ARules: TTJAXYSerializerRules;
      out APrevious: TTJAXYSerializerRules); static;
    class procedure PopMappingRules(const APrevious: TTJAXYSerializerRules); static;
    class procedure ValidateMappingTree(AValue: TTJAXYValue); static;
    class procedure BeginDiagnosticsCollection(out APrevious, ACollector: TList); static;
    class procedure EndDiagnosticsCollection(APrevious, ACollector: TList;
      out ADiagnostics: TArray<TTJAXYMappingDiagnostic>); static;
  public
    class function DefaultSerializerRules: TTJAXYSerializerRules; static;
    class procedure RegisterObjectFactory(AClass: TClass; AFactory: TTJAXYObjectFactory); static;
    class procedure UnregisterObjectFactory(AClass: TClass); static;
    constructor Create; virtual;
    class function CreateArrayRoot: TTJAXYDocument; virtual;
    class function CreateObjectRoot: TTJAXYDocument; virtual;
    constructor CreateFromObject(AObject: TObject); virtual;
    class function CreateFromRecord<T>(const ARecord: T): TTJAXY; static;
    class function CreateFromRecordWithRules<T>(const ARecord: T; const ARules: TTJAXYSerializerRules): TTJAXY; static;
    destructor Destroy; override;
    procedure Assign(ASource: TPersistent); override;
    procedure Clear; virtual;
    procedure LoadFromFile(const AFileName: String); virtual;
    procedure LoadFromObject(AObject: TObject); overload; virtual;
    procedure LoadFromObject(AObject: TObject; const ARules: TTJAXYSerializerRules); overload;
    procedure LoadFromStream(AStream: TStream); virtual; abstract;
    procedure ReadFromString(const AValue: String); virtual;
    procedure AssignToObject(AObject: TObject); overload; virtual;
    procedure AssignToObject(AObject: TObject; const ARules: TTJAXYSerializerRules); overload;
    procedure AssignToObject(AObject: TObject; out ADiagnostics: TArray<TTJAXYMappingDiagnostic>); overload;
    procedure AssignToObject(AObject: TObject; const ARules: TTJAXYSerializerRules;
      out ADiagnostics: TArray<TTJAXYMappingDiagnostic>); overload;
    procedure AssignToRecord<T>(var ARecord: T); overload;
    procedure AssignToRecord<T>(var ARecord: T; const ARules: TTJAXYSerializerRules); overload;
    procedure AssignToRecord<T>(var ARecord: T;
      out ADiagnostics: TArray<TTJAXYMappingDiagnostic>); overload;
    procedure AssignToRecord<T>(var ARecord: T; const ARules: TTJAXYSerializerRules;
      out ADiagnostics: TArray<TTJAXYMappingDiagnostic>); overload;
    procedure SaveToFile(const AFileName: String); virtual;
    procedure SaveToStream(AStream: TStream); virtual;
    function IsEmpty: Boolean; virtual;
    function RootNewArray: TTJAXYArray; virtual;
    function RootNewObject: TTJAXYObject; virtual;
    function WriteToFile(const AFileName: String; AWriteMode: TTJAXYStringWriteMode = tjaxywmReadable): String; virtual;
    function WriteToString(AWriteMode: TTJAXYStringWriteMode = tjaxywmReadable): String; virtual;
    property ObjectValue[Key: String]: TTJAXYValue read GetObjectValue; default;
    property ArrayValue[Index: Integer]: TTJAXYValue read GetArrayValue;
    property Root: TTJAXYValue read FRoot;
    property IsObject: Boolean read GetIsObject;
    property IsArray: Boolean read GetIsArray;
    property AsObject: TTJAXYObject read GetAsObject;
    property AsArray: TTJAXYArray read GetAsArray;
    class property SerializerRules: TTJAXYSerializerRules read GetSerializerRules write SetSerializerRules;
    class property Mapper: ITJAXYObjectMapper read GetMapper write SetMapper;
    class property MapperCapabilities: TTJAXYMapperCapabilities read GetMapperCapabilities;
  end;

  TTJAXY = class(TTJAXYDocument)
  public
    class function CreateTemplate(AName: String): TTJAXYTemplate; static;
    class function Template(AName: String): TTJAXYTemplate; static;
    class function CreateArrayRoot: TTJAXY; reintroduce; static;
    class function CreateObjectRoot: TTJAXY; reintroduce; static;
    procedure LoadFromStream(AStream: TStream); override;
  end;

  TTJAXYParser = class(TTJAXYDocument)
  end;

  TTJAXYTemplateField = record
    Name: String;
    Typ: TTJAXYTemplateType;
    Nested: TTJAXYTemplate;
    Default: TTJAXYValue;
    Callback: TTJAXYTemplateFillCallback;
  end;

  TTJAXYTemplate = class(TPersistent)
  private
    FName: String;
    FFlags: TTJAXYTemplateFlags;
    FDocument: TTJAXY;
    FValues: Array of TTJAXYTemplateField;
    FLastAdded: Integer;
    FOnTemplateFillCallback: TTJAXYTemplateFillCallback;
  protected
    function Add(AName: String; AType: TTJAXYTemplateType; ATemplate: TTJAXYTemplate; ACallback: TTJAXYTemplateFillCallback): TTJAXYTemplate; overload;
    function GetTemplateFieldCount: Integer;
    procedure Cleanup;
    procedure DoTemplateFillCallback(ATemplateName, AKeyName: String; var AValue: TTJAXYValue);
  public
    constructor Create(AName: String);
    destructor Destroy; override;
    procedure Clear;
    function Add(AName: String; AType: TTJAXYType): TTJAXYTemplate; overload;
    function Add(AName: String; AType: TTJAXYTemplateType): TTJAXYTemplate; overload;
    function Add(AName: String; ATemplate: TTJAXYTemplate): TTJAXYTemplate; overload;
    function Add(AName: String; ATemplateName: String): TTJAXYTemplate; overload;
    function Add(AName: String; ACallback: TTJAXYTemplateFillCallback): TTJAXYTemplate; overload;
    function Add(AField: TTJAXYTemplateField): TTJAXYTemplate; overload;
    function Default(AValue: TTJAXYValue): TTJAXYTemplate; overload;
    function Empty(AUseDefaults: Boolean = True): TTJAXY;
    function Fill(AValues: Array of const): TTJAXY;
    function SetFlag(AFlag: TTJAXYTemplateFlag): TTJAXYTemplate;
    function SetFlags(AFlags: TTJAXYTemplateFlags): TTJAXYTemplate;
    function SetValue(AName: String; const AValue: Variant): Boolean;
    property Name: String read FName;
    property Flags: TTJAXYTemplateFlags read FFlags write FFlags;
    property Document: TTJAXY read FDocument;
    property OnTemplateFillCallback: TTJAXYTemplateFillCallback read FOnTemplateFillCallback write FOnTemplateFillCallback;
  end;

  TTJAXYValue = class(TPersistent)
  private
    function GetIsArray: Boolean;
    function GetIsBoolean: Boolean;
    function GetIsFloat: Boolean;
    function GetIsInteger: Boolean;
    function GetIsNull: Boolean;
    function GetIsObject: Boolean;
    function GetIsString: Boolean;
    function GetTyp: TTJAXYType;
  protected
    function GetAsArray: TTJAXYArray; virtual; abstract;
    function GetAsBoolean: Boolean; virtual; abstract;
    function GetAsFloat: Extended; virtual; abstract;
    function GetAsInteger: Int64; virtual; abstract;
    function GetAsObject: TTJAXYObject; virtual; abstract;
    function GetAsString: String; virtual; abstract;
    function GetClass: TTJAXYValueClass; reintroduce; virtual;
  public
    constructor Create; virtual;
    function Copy: TTJAXYValue; virtual;
    function IsEmpty: Boolean; virtual; abstract;
    property Typ: TTJAXYType read GetTyp;
    property IsNull: Boolean read GetIsNull;
    property IsString: Boolean read GetIsString;
    property IsInteger: Boolean read GetIsInteger;
    property IsFloat: Boolean read GetIsFloat;
    property IsBoolean: Boolean read GetIsBoolean;
    property IsObject: Boolean read GetIsObject;
    property IsArray: Boolean read GetIsArray;
    property AsString: String read GetAsString;
    property AsInteger: Int64 read GetAsInteger;
    property AsFloat: Extended read GetAsFloat;
    property AsBoolean: Boolean read GetAsBoolean;
    property AsObject: TTJAXYObject read GetAsObject;
    property AsArray: TTJAXYArray read GetAsArray;
  end;

  TTJAXYNull = class(TTJAXYValue)
  protected
    function GetAsArray: TTJAXYArray; override;
    function GetAsBoolean: Boolean; override;
    function GetAsFloat: Extended; override;
    function GetAsInteger: Int64; override;
    function GetAsObject: TTJAXYObject; override;
    function GetAsString: String; override;
    function GetClass: TTJAXYValueClass; override;
  public
    constructor Create; override;
    function IsEmpty: Boolean; override;
  end;

  TTJAXYString = class(TTJAXYValue)
  private
    FValue: String;
  protected
    function GetAsArray: TTJAXYArray; override;
    function GetAsBoolean: Boolean; override;
    function GetAsFloat: Extended; override;
    function GetAsInteger: Int64; override;
    function GetAsObject: TTJAXYObject; override;
    function GetAsString: String; override;
    function GetClass: TTJAXYValueClass; override;
  public
    constructor Create; override;
    constructor CreateFrom(AValue: String);
    function IsEmpty: Boolean; override;
    property Value: String read FValue write FValue;
  end;

  TTJAXYDateTime = class(TTJAXYString)
  private
    FKind: TTJAXYDateTimeKind;
  protected
    function GetClass: TTJAXYValueClass; override;
  public
    constructor Create; override;
    constructor CreateFrom(AValue: String; AKind: TTJAXYDateTimeKind);
    property Kind: TTJAXYDateTimeKind read FKind write FKind;
  end;

  TTJAXYInteger = class(TTJAXYValue)
  private
    FValue: Int64;
  protected
    function GetAsArray: TTJAXYArray; override;
    function GetAsBoolean: Boolean; override;
    function GetAsFloat: Extended; override;
    function GetAsInteger: Int64; override;
    function GetAsObject: TTJAXYObject; override;
    function GetAsString: String; override;
    function GetClass: TTJAXYValueClass; override;
  public
    constructor Create; override;
    constructor CreateFrom(AValue: Int64);
    function IsEmpty: Boolean; override;
    property Value: Int64 read FValue write FValue;
  end;

  TTJAXYFloat = class(TTJAXYValue)
  private
    FValue: Extended;
  protected
    function GetAsArray: TTJAXYArray; override;
    function GetAsBoolean: Boolean; override;
    function GetAsFloat: Extended; override;
    function GetAsInteger: Int64; override;
    function GetAsObject: TTJAXYObject; override;
    function GetAsString: String; override;
    function GetClass: TTJAXYValueClass; override;
  public
    constructor Create; override;
    constructor CreateFrom(AValue: Extended);
    function IsEmpty: Boolean; override;
    property Value: Extended read FValue write FValue;
  end;

  TTJAXYBoolean = class(TTJAXYValue)
  private
    FValue: Boolean;
  protected
    function GetAsArray: TTJAXYArray; override;
    function GetAsBoolean: Boolean; override;
    function GetAsFloat: Extended; override;
    function GetAsInteger: Int64; override;
    function GetAsObject: TTJAXYObject; override;
    function GetAsString: String; override;
    function GetClass: TTJAXYValueClass; override;
  public
    constructor Create; override;
    constructor CreateFrom(AValue: Boolean);
    function IsEmpty: Boolean; override;
    property Value: Boolean read FValue write FValue;
  end;

  TTJAXYObject = class(TTJAXYValue)
  private
    FKeys: TStringList;
    function GetCount: Integer;
    function GetItem(Index: Integer): TTJAXYValue;
    function GetName(Index: Integer): String;
    function GetItemByKey(Key: String): TTJAXYValue;
  protected
    function GetAsArray: TTJAXYArray; override;
    function GetAsBoolean: Boolean; override;
    function GetAsFloat: Extended; override;
    function GetAsInteger: Int64; override;
    function GetAsObject: TTJAXYObject; override;
    function GetAsString: String; override;
    function GetClass: TTJAXYValueClass; override;
  public
    constructor Create; override;
    constructor CreateFrom(AObject: TTJAXYObject);
    destructor Destroy; override;
    procedure Add(AKey: String); overload;
    procedure Add(AKey: String; AValue: String); overload;
    procedure Add(AKey: String; AValue: Int64); overload;
    procedure Add(AKey: String; AValue: Extended); overload;
    procedure Add(AKey: String; AValue: Boolean); overload;
    procedure Add(AKey: String; AValue: TTJAXYValue); overload;
    procedure AddArray(AKey: String; AArray: TTJAXYArray); overload;
    procedure AddObject(AKey: String; AObject: TTJAXYObject); overload;
    procedure Clear;
    procedure Delete(AKey: String);
    procedure Merge(ASource: TTJAXYObject);
    procedure SetOrAdd(AKey: String); overload;
    procedure SetOrAdd(AKey: String; AValue: String); overload;
    procedure SetOrAdd(AKey: String; AValue: Int64); overload;
    procedure SetOrAdd(AKey: String; AValue: Extended); overload;
    procedure SetOrAdd(AKey: String; AValue: Boolean); overload;
    procedure SetOrAdd(AKey: String; AValue: TTJAXYValue); overload;
    function AddArray(AKey: String): TTJAXYArray; overload;
    function AddObject(AKey: String): TTJAXYObject; overload;
    function GetOrAdd(AKey: String; ADefault: String): String; overload;
    function GetOrAdd(AKey: String; ADefault: Int64): Int64; overload;
    function GetOrAdd(AKey: String; ADefault: Extended): Extended; overload;
    function GetOrAdd(AKey: String; ADefault: Boolean): Boolean; overload;
    function GetOrAddArray(AKey: String): TTJAXYArray;
    function GetOrAddObject(AKey: String): TTJAXYObject;
    function GetNode(const AKey: String): TTJAXYValue;
    function FindNode(const AQuery: String): TTJAXYValue;
    function GetValue(const AKey, ADefault: String): String; overload;
    function GetValue(const AKey: String; ADefault: Int64): Int64; overload;
    function GetValue(const AKey: String; ADefault: Extended): Extended; overload;
    function GetValue(const AKey: String; ADefault: Boolean): Boolean; overload;
    function FindValue(const AQuery, ADefault: String): String; overload;
    function FindValue(const AQuery: String; ADefault: Int64): Int64; overload;
    function FindValue(const AQuery: String; ADefault: Extended): Extended; overload;
    function FindValue(const AQuery: String; ADefault: Boolean): Boolean; overload;
    function HasKey(AKey: String): Boolean;
    function IndexOf(AKey: String): Integer;
    function IsEmpty: Boolean; override;
    function ToString: String; override;
    property Count: Integer read GetCount;
    property Value[Key: String]: TTJAXYValue read GetItemByKey; default;
    property Item[Index: Integer]: TTJAXYValue read GetItem;
    property Name[Index: Integer]: String read GetName;
  end;

  TTJAXYArray = class(TTJAXYValue)
  private
    FValues: TList;
    function GetCount: Integer;
    function GetItem(Index: Integer): TTJAXYValue;
  protected
    function GetAsArray: TTJAXYArray; override;
    function GetAsBoolean: Boolean; override;
    function GetAsFloat: Extended; override;
    function GetAsInteger: Int64; override;
    function GetAsObject: TTJAXYObject; override;
    function GetAsString: String; override;
    function GetClass: TTJAXYValueClass; override;
  public
    constructor Create; override;
    destructor Destroy; override;
    procedure Add(AValue: TTJAXYValue); overload;
    procedure Add; overload;
    procedure Add(AValue: String); overload;
    procedure Add(AValue: Int64); overload;
    procedure Add(AValue: Extended); overload;
    procedure Add(AValue: Boolean); overload;
    procedure AddArray(AArray: TTJAXYArray); overload;
    procedure AddObject(AObject: TTJAXYObject); overload;
    procedure Clear;
    procedure Delete(AIndex: Integer);
    procedure Exchange(AIndex1, AIndex2: Integer);
    procedure Insert(AIndex: Integer; AValue: TTJAXYValue);
    procedure Move(ACurIndex, ANewIndex: Integer);
    procedure Replace(AIndex: Integer; AValue: TTJAXYValue);
    function AddArray: TTJAXYArray; overload;
    function AddObject: TTJAXYObject; overload;
    function AddObject(AKey: String; AValue: TTJAXYValue): TTJAXYObject; overload;
    function IsEmpty: Boolean; override;
    function ToString: String; override;
    property Count: Integer read GetCount;
    property Item[Index: Integer]: TTJAXYValue read GetItem; default;
  end;

  TTJAXYWriter = class
  private
    FMode: TTJAXYStringWriteMode;
    function Indent(ALevel: Integer): String;
    function NewLine: String;
    function Space: String;
    function WriteArray(AArray: TTJAXYArray; ALevel: Integer): String;
    function WriteObject(AObject: TTJAXYObject; ALevel: Integer): String;
    function WriteValue(AValue: TTJAXYValue; ALevel: Integer): String;
  public
    constructor Create(AMode: TTJAXYStringWriteMode);
    class function EncodeString(AString: String): String; static;
    function Write(AValue: TTJAXYValue): String;
  end;

procedure TJAXYWriteUTF8(AStream: TStream; const AText: String);
procedure TJAXYRequireValidText(const AText: String);
function TJAXYValidUTF8(const ABytes: TBytes): Boolean;
function TJAXYDecodeUTF8(const ABytes: TBytes): String;
function TJAXYReadUTF8(AStream: TStream): String;

implementation

uses
  SyncObjs
  {$IFDEF TJAXY_USE_RTTI}
  , System.Rtti, System.TypInfo
  {$ENDIF};

procedure TJAXYRequireValidText(const AText: String);
var
  I: Integer;
  CodeUnit: Integer;
  {$IFDEF FPC}
  RawBytes: TBytes;
  {$ENDIF}
begin
  {$IFDEF FPC}
  SetLength(RawBytes, Length(AText));
  if Length(RawBytes) > 0 then
    Move(AText[1], RawBytes[0], Length(RawBytes));
  if NOT TJAXYValidUTF8(RawBytes) then
    raise ETJAXYException.Create('Text must be valid UTF-8 without NUL bytes');
  {$ELSE}
  I:=1;
  while I <= Length(AText) do
  begin
    CodeUnit:=Ord(AText[I]);
    if (CodeUnit >= $D800) AND (CodeUnit <= $DBFF) then
    begin
      if (I = Length(AText)) OR (Ord(AText[I + 1]) < $DC00) OR
        (Ord(AText[I + 1]) > $DFFF) then
        raise ETJAXYException.Create('Text contains an unpaired UTF-16 surrogate');
      Inc(I);
    end
    else if (CodeUnit >= $DC00) AND (CodeUnit <= $DFFF) then
      raise ETJAXYException.Create('Text contains an unpaired UTF-16 surrogate');
    Inc(I);
  end;
  {$ENDIF}
end;

procedure TJAXYWriteUTF8(AStream: TStream; const AText: String);
var
  Bytes: TBytes;
begin
  TJAXYRequireValidText(AText);
  Bytes:=TEncoding.UTF8.GetBytes(AText);
  if Length(Bytes) > 0 then
    AStream.WriteBuffer(Bytes[0], Length(Bytes));
end;

function TJAXYValidUTF8(const ABytes: TBytes): Boolean;
var
  I, J, Continuations: Integer;
  First, SecondMinimum, SecondMaximum: Byte;
begin
  Result:=False;
  I:=0;
  while I < Length(ABytes) do
  begin
    First:=ABytes[I];
    if First = 0 then
      Exit;
    if First < $80 then
    begin
      Inc(I);
      Continue;
    end;
    SecondMinimum:=$80;
    SecondMaximum:=$BF;
    if (First >= $C2) AND (First <= $DF) then
      Continuations:=1
    else if (First >= $E0) AND (First <= $EF) then
    begin
      Continuations:=2;
      if First = $E0 then SecondMinimum:=$A0;
      if First = $ED then SecondMaximum:=$9F;
    end
    else if (First >= $F0) AND (First <= $F4) then
    begin
      Continuations:=3;
      if First = $F0 then SecondMinimum:=$90;
      if First = $F4 then SecondMaximum:=$8F;
    end
    else
      Exit;
    if I + Continuations >= Length(ABytes) then
      Exit;
    if (ABytes[I + 1] < SecondMinimum) OR (ABytes[I + 1] > SecondMaximum) then
      Exit;
    for J:=2 to Continuations do
      if (ABytes[I + J] < $80) OR (ABytes[I + J] > $BF) then
        Exit;
    Inc(I, Continuations + 1);
  end;
  Result:=True;
end;

function TJAXYDecodeUTF8(const ABytes: TBytes): String;
var
  Offset: Integer;
  Content: TBytes;
begin
  if NOT TJAXYValidUTF8(ABytes) then
    raise ETJAXYException.Create('Input must be valid UTF-8 without NUL bytes');
  Offset:=0;
  if (Length(ABytes) >= 3) AND (ABytes[0] = $EF) AND
    (ABytes[1] = $BB) AND (ABytes[2] = $BF) then
    Offset:=3;
  SetLength(Content, Length(ABytes) - Offset);
  if Length(Content) > 0 then
    Move(ABytes[Offset], Content[0], Length(Content));
  Result:=TEncoding.UTF8.GetString(Content);
end;

function TJAXYReadUTF8(AStream: TStream): String;
var
  Buffer: array[0..8191] of Byte;
  Accumulated: TMemoryStream;
  Bytes: TBytes;
  ReadCount: Integer;
begin
  Accumulated:=TMemoryStream.Create;
  try
    repeat
      ReadCount:=AStream.Read(Buffer, SizeOf(Buffer));
      if ReadCount > 0 then
      begin
        if Accumulated.Size > MaxInt - ReadCount then
          raise ETJAXYException.Create('UTF-8 input exceeds supported size');
        Accumulated.WriteBuffer(Buffer, ReadCount);
      end;
    until ReadCount = 0;
    SetLength(Bytes, Integer(Accumulated.Size));
    Accumulated.Position:=0;
    if Length(Bytes) > 0 then
      Accumulated.ReadBuffer(Bytes[0], Length(Bytes));
  finally
    Accumulated.Free;
  end;
  Result:=TJAXYDecodeUTF8(Bytes);
end;

resourcestring
  RCS_INVALID_VALUE_CAST = 'Invalid TJAXY value cast';
  RCS_DUPLICATE_KEY = 'Duplicate TJAXY object key "%s"';
  RCS_FIELD_VALUE_TYPE_MISMATCH = 'Field value type mismatch, declaration differs! (%s <> %s)';
  RCS_FIELD_COUNT_MISMATCH = 'Fields and value count mismatch!';
  RCS_FIELD_NAME_ALREADY_EXISTS = 'A field with this name already exists!';
  RCS_TEMPLATE_NAME_REQUIRED = 'Error creating template "%s", nested name is required!';
  RCS_TEMPLATE_NAME_NOT_FOUND = 'Template with name "%s" not found!';
  RCS_TEMPLATE_REQUIRED = 'A template object is required!';
  RCS_INVALID_ENUM_VALUE = 'Invalid enum value "%s" for type "%s"!';

const
  TJAXY_ATTR_KEY = '@';
  TJAXY_TEXT_KEY = '#text';
  TJAXY_PATH_SEPARATOR = '.';
  TJAXY_PATH_ARRAY_OPEN = '[';
  TJAXY_PATH_ARRAY_CLOSE = ']';
  TJAXY_PATH_ARRAY_WILDCARD = '*';
  TJAXY_LITERAL_NULL = 'null';
  TJAXY_LITERAL_TRUE = 'true';
  TJAXY_LITERAL_FALSE = 'false';
  TJAXY_LINE_FEED = #13#10;
  TJAXY_INDENT_COUNT = 2;
  TJAXY_TYPE_STRINGS: Array[TTJAXYType] of String = ('Null', 'Integer', 'Float', 'String', 'Boolean', 'Object', 'Array');
  TJAXY_TEMPLATE_TYPE_STRINGS: Array[TTJAXYTemplateType] of String = ('Null', 'Integer', 'Float', 'String', 'Boolean', 'Object', 'Array', '<Name>', '<UnixTime>', '<Template>', '<Callback>');
  TJAXY_TYPE_TO_TEMPLATE_TYPE: Array[TTJAXYType] of TTJAXYTemplateType = (tjaxyttNull, tjaxyttInteger, tjaxyttFloat, tjaxyttString, tjaxyttBoolean, tjaxyttObject, tjaxyttArray);
  TJAXY_ADVANCED_TEMPLATE_TYPES: set of TTJAXYTemplateType = [tjaxyttName, tjaxyttUnixTime, tjaxyttTemplate, tjaxyttCallback];
  TJAXY_AUTOFILL_TEMPLATE_TYPES: set of TTJAXYTemplateType = [tjaxyttName, tjaxyttUnixTime, tjaxyttCallback];

type
  TTJAXYTemplatesList = class(TStringList)
  private
    function GetTemplate(Name: String): TTJAXYTemplate;
  public
    constructor Create;
    destructor Destroy; override;
    function AddTemplate(AName: String; ATemplate: TTJAXYTemplate): Integer;
    property Templates[Name: String]: TTJAXYTemplate read GetTemplate; default;
  end;

  TTJAXYFactoryEntry = record
    TargetClass: TClass;
    Factory: TTJAXYObjectFactory;
  end;

  TTJAXYMappingDiagnosticItem = class
    Path: String;
    Message: String;
  end;

  {$IFDEF TJAXY_USE_RTTI}
  TTJAXYDefaultMapper = class(TInterfacedObject, ITJAXYObjectMapper)
  public
    function Capabilities: TTJAXYMapperCapabilities;
    function SerializeObject(AObject: TObject): TTJAXYValue;
    procedure AssignObject(AObject: TObject; ASource: TTJAXYObject);
    function SerializeRecord(ATypeInfo, ARecord: Pointer): TTJAXYValue;
    procedure AssignRecord(ATypeInfo, ARecord: Pointer; ASource: TTJAXYObject);
    procedure RegisterFactory(AClass: TClass; AFactory: TTJAXYObjectFactory);
    procedure UnregisterFactory(AClass: TClass);
  end;
  {$ENDIF}


var
  GlobTemplates: TTJAXYTemplatesList = nil;
  GlobSerializerRules: TTJAXYSerializerRules;
  GlobObjectFactories: array of TTJAXYFactoryEntry;
  GlobMapper: ITJAXYObjectMapper;
  GlobRulesLock: TCriticalSection;

threadvar
  ThreadMappingDepth: Integer;
  ThreadMappingDiagnostics: TList;

procedure TJAXYAddMappingDiagnostic(const APath, AMessage: String);
var
  Item: TTJAXYMappingDiagnosticItem;
begin
  if ThreadMappingDiagnostics = nil then
    Exit;
  Item:=TTJAXYMappingDiagnosticItem.Create;
  Item.Path:=APath;
  Item.Message:=AMessage;
  ThreadMappingDiagnostics.Add(Item);
end;

function TJAXYMappingChildPath(const APath, AName: String): String;
begin
  if APath = '' then
    Result:=AName
  else
    Result:=APath + '.' + AName;
end;

procedure TJAXYCopyMappingDiagnostics(AList: TList;
  out ADiagnostics: TArray<TTJAXYMappingDiagnostic>);
var
  I: Integer;
  Item: TTJAXYMappingDiagnosticItem;
begin
  SetLength(ADiagnostics, AList.Count);
  for I:=0 to AList.Count - 1 do
  begin
    Item:=TTJAXYMappingDiagnosticItem(AList[I]);
    ADiagnostics[I].Path:=Item.Path;
    ADiagnostics[I].Message:=Item.Message;
  end;
end;

procedure TJAXYFreeMappingDiagnostics(AList: TList);
var
  I: Integer;
begin
  for I:=0 to AList.Count - 1 do
    TObject(AList[I]).Free;
  AList.Free;
end;

function TJAXYCloneSerializerRules(const ARules: TTJAXYSerializerRules): TTJAXYSerializerRules;
var
  I: Integer;
begin
  Result:=ARules;
  Result.EnumStripPrefixes:=nil;
  SetLength(Result.EnumStripPrefixes, Length(ARules.EnumStripPrefixes));
  for I:=0 to High(ARules.EnumStripPrefixes) do
    Result.EnumStripPrefixes[I]:=ARules.EnumStripPrefixes[I];
end;

function TJAXYCreateRegisteredObject(AClass: TClass): TObject;
var
  I: Integer;
begin
  Result:=nil;
  for I:=0 to High(GlobObjectFactories) do
    if GlobObjectFactories[I].TargetClass = AClass then
    begin
      Result:=GlobObjectFactories[I].Factory();
      if (Result <> nil) AND NOT Result.InheritsFrom(AClass) then
      begin
        Result.Free;
        raise ETJAXYException.Create('Object factory returned an incompatible class');
      end;
      Exit;
    end;
end;

procedure TJAXYRegisterFactoryDefault(AClass: TClass; AFactory: TTJAXYObjectFactory);
var
  I: Integer;
begin
  for I:=0 to High(GlobObjectFactories) do
    if GlobObjectFactories[I].TargetClass = AClass then
    begin
      GlobObjectFactories[I].Factory:=AFactory;
      Exit;
    end;
  I:=Length(GlobObjectFactories);
  SetLength(GlobObjectFactories, I + 1);
  GlobObjectFactories[I].TargetClass:=AClass;
  GlobObjectFactories[I].Factory:=AFactory;
end;

procedure TJAXYUnregisterFactoryDefault(AClass: TClass);
var
  I, J: Integer;
begin
  for I:=0 to High(GlobObjectFactories) do
    if GlobObjectFactories[I].TargetClass = AClass then
    begin
      for J:=I to High(GlobObjectFactories) - 1 do
        GlobObjectFactories[J]:=GlobObjectFactories[J + 1];
      SetLength(GlobObjectFactories, Length(GlobObjectFactories) - 1);
      Exit;
    end;
end;

function TJAXYStripEnumPrefix(const AName: String): String;
var
  I: Integer;
  Prefix: String;
begin
  Result:=AName;
  for I:=0 to Length(TTJAXYDocument.SerializerRules.EnumStripPrefixes) - 1 do
  begin
    Prefix:=TTJAXYDocument.SerializerRules.EnumStripPrefixes[I];
    if (Prefix <> '') AND SameText(Copy(Result, 1, Length(Prefix)), Prefix) then
    begin
      Delete(Result, 1, Length(Prefix));
      Break;
    end;
  end;
end;

function TJAXYToSnakeCase(const AName: String; const AUpper: Boolean): String;
var
  I: Integer;
  Ch: Char;
begin
  Result:='';
  for I:=1 to Length(AName) do
  begin
    Ch:=AName[I];
    if (I > 1) AND CharInSet(Ch, ['A'..'Z']) AND
       (CharInSet(AName[I - 1], ['a'..'z', '0'..'9']) OR ((I < Length(AName)) AND CharInSet(AName[I + 1], ['a'..'z']))) then
      Result:=Result + '_';
    Result:=Result + Ch;
  end;

  if AUpper then
    Result:=UpperCase(Result)
  else
    Result:=LowerCase(Result);
end;

function TJAXYApplyNameCase(const AName: String): String;
begin
  Result:=AName;
  case TTJAXYDocument.SerializerRules.EnumNameCase of
    tjaxyncLower: Result:=LowerCase(Result);
    tjaxyncUpper: Result:=UpperCase(Result);
    tjaxyncPascal:
      if Result <> '' then
        Result[1]:=UpCase(Result[1]);
    tjaxyncCamel:
      if Result <> '' then
        Result:=LowerCase(Copy(Result, 1, 1)) + Copy(Result, 2, MaxInt);
    tjaxyncSnake: Result:=TJAXYToSnakeCase(Result, False);
    tjaxyncScreamingSnake: Result:=TJAXYToSnakeCase(Result, True);
  end;
end;

{$IFDEF TJAXY_USE_RTTI}
function TJAXYFormatSettings: TFormatSettings; forward;
{$I TJAXY.Mapper.Delphi.inc}
{$ENDIF}

function TJAXYFormatSettings: TFormatSettings;
begin
  Result:=FormatSettings;
  Result.DecimalSeparator:='.';
  Result.ThousandSeparator:=',';
end;

function TJAXYInvalidArray: TTJAXYArray;
begin
  Result:=nil;
  raise ETJAXYException.Create(RCS_INVALID_VALUE_CAST);
end;

function TJAXYInvalidBoolean: Boolean;
begin
  Result:=False;
  raise ETJAXYException.Create(RCS_INVALID_VALUE_CAST);
end;

function TJAXYInvalidFloat: Extended;
begin
  Result:=0;
  raise ETJAXYException.Create(RCS_INVALID_VALUE_CAST);
end;

function TJAXYInvalidInteger: Int64;
begin
  Result:=0;
  raise ETJAXYException.Create(RCS_INVALID_VALUE_CAST);
end;

function TJAXYInvalidObject: TTJAXYObject;
begin
  Result:=nil;
  raise ETJAXYException.Create(RCS_INVALID_VALUE_CAST);
end;

function TJAXYInvalidString: String;
begin
  Result:='';
  raise ETJAXYException.Create(RCS_INVALID_VALUE_CAST);
end;

function TJAXYUsefulValue(AValue: TTJAXYValue): TTJAXYValue;
begin
  Result:=AValue;
  if Assigned(Result) AND Result.IsObject AND Result.AsObject.HasKey(TJAXY_TEXT_KEY) then
    Result:=Result.AsObject[TJAXY_TEXT_KEY];
end;

function TJAXYValueAsStringOrDefault(AValue: TTJAXYValue; const ADefault: String): String;
begin
  AValue:=TJAXYUsefulValue(AValue);
  if Assigned(AValue) AND (NOT AValue.IsNull) then
    Result:=AValue.AsString
  else
    Result:=ADefault;
end;

function TJAXYValueAsIntegerOrDefault(AValue: TTJAXYValue; const ADefault: Int64): Int64;
begin
  AValue:=TJAXYUsefulValue(AValue);
  if NOT Assigned(AValue) OR AValue.IsNull then
    Exit(ADefault);
  if AValue.IsInteger then
    Exit(AValue.AsInteger);
  if NOT TryStrToInt64(Trim(AValue.AsString), Result) then
    Result:=ADefault;
end;

function TJAXYValueAsFloatOrDefault(AValue: TTJAXYValue; const ADefault: Extended): Extended;
begin
  AValue:=TJAXYUsefulValue(AValue);
  if NOT Assigned(AValue) OR AValue.IsNull then
    Exit(ADefault);
  if AValue.IsFloat OR AValue.IsInteger then
    Exit(AValue.AsFloat);
  if NOT TryStrToFloat(Trim(AValue.AsString), Result) then
    Result:=ADefault;
end;

function TJAXYValueAsBooleanOrDefault(AValue: TTJAXYValue; const ADefault: Boolean): Boolean;
var
  S: String;
begin
  AValue:=TJAXYUsefulValue(AValue);
  if NOT Assigned(AValue) OR AValue.IsNull then
    Exit(ADefault);
  if AValue.IsBoolean then
    Exit(AValue.AsBoolean);

  S:=LowerCase(Trim(AValue.AsString));
  if (S = TJAXY_LITERAL_TRUE) OR (S = '1') OR (S = 'yes') then
    Result:=True
  else if (S = TJAXY_LITERAL_FALSE) OR (S = '0') OR (S = 'no') then
    Result:=False
  else
    Result:=ADefault;
end;

function TJAXYTemplateTypeForValue(AValue: TTJAXYValue): TTJAXYTemplateType;
begin
  if Assigned(AValue) then
    Result:=TJAXY_TYPE_TO_TEMPLATE_TYPE[AValue.Typ]
  else
    Result:=tjaxyttNull;
end;

function TJAXYTemplateValue(AType: TTJAXYTemplateType): TTJAXYValue;
begin
  case AType of
    tjaxyttNull: Result:=TTJAXYNull.Create;
    tjaxyttInteger: Result:=TTJAXYInteger.CreateFrom(0);
    tjaxyttFloat: Result:=TTJAXYFloat.CreateFrom(0.0);
    tjaxyttString: Result:=TTJAXYString.CreateFrom('');
    tjaxyttBoolean: Result:=TTJAXYBoolean.CreateFrom(False);
    tjaxyttObject: Result:=TTJAXYObject.Create;
    tjaxyttArray: Result:=TTJAXYArray.Create;
  else
    Result:=nil;
  end;
end;

{ TTJAXYTemplatesList }

constructor TTJAXYTemplatesList.Create;
begin
  inherited Create;
  CaseSensitive:=False;
  Duplicates:=dupError;
  Sorted:=False;
end;

destructor TTJAXYTemplatesList.Destroy;
var
  I: Integer;
begin
  for I:=0 to Count - 1 do
    Objects[I].Free;
  inherited;
end;

function TTJAXYTemplatesList.AddTemplate(AName: String; ATemplate: TTJAXYTemplate): Integer;
begin
  Result:=AddObject(AnsiLowerCase(AName), ATemplate);
end;

function TTJAXYTemplatesList.GetTemplate(Name: String): TTJAXYTemplate;
var
  Idx: Integer;
begin
  Result:=nil;
  Idx:=IndexOf(AnsiLowerCase(Name));
  if Idx >= 0 then
    Result:=TTJAXYTemplate(Objects[Idx]);
end;

{ TTJAXYDocument }

class procedure TTJAXYDocument.BeginMappingOperation;
begin
  GlobRulesLock.Enter;
  Inc(ThreadMappingDepth);
end;

class procedure TTJAXYDocument.BeginDiagnosticsCollection(out APrevious,
  ACollector: TList);
begin
  ACollector:=TList.Create;
  APrevious:=ThreadMappingDiagnostics;
  ThreadMappingDiagnostics:=ACollector;
end;

class procedure TTJAXYDocument.EndDiagnosticsCollection(APrevious,
  ACollector: TList; out ADiagnostics: TArray<TTJAXYMappingDiagnostic>);
begin
  ThreadMappingDiagnostics:=APrevious;
  try
    TJAXYCopyMappingDiagnostics(ACollector, ADiagnostics);
  finally
    TJAXYFreeMappingDiagnostics(ACollector);
  end;
end;

class procedure TTJAXYDocument.EndMappingOperation;
begin
  Dec(ThreadMappingDepth);
  GlobRulesLock.Leave;
end;

class procedure TTJAXYDocument.PushMappingRules(const ARules: TTJAXYSerializerRules;
  out APrevious: TTJAXYSerializerRules);
begin
  BeginMappingOperation;
  try
    APrevious:=GlobSerializerRules;
    GlobSerializerRules:=TJAXYCloneSerializerRules(ARules);
  except
    EndMappingOperation;
    raise;
  end;
end;

class procedure TTJAXYDocument.PopMappingRules(const APrevious: TTJAXYSerializerRules);
begin
  GlobSerializerRules:=APrevious;
  EndMappingOperation;
end;

class procedure TTJAXYDocument.ValidateMappingTree(AValue: TTJAXYValue);
var
  Seen: TList;

  procedure Visit(ANode: TTJAXYValue; ADepth: Integer; const APath: String);
  var
    I: Integer;
  begin
    if ADepth > 64 then
      raise ETJAXYException.Create(APath + ': object mapping exceeds 64 nesting levels');
    if Seen.IndexOf(ANode) >= 0 then
      raise ETJAXYException.Create(APath + ': object mapping cycle detected');
    Seen.Add(ANode);
    try
      if ANode IS TTJAXYObject then
      begin
        for I:=0 to ANode.AsObject.Count - 1 do
          Visit(ANode.AsObject.Item[I], ADepth + 1, APath + '.' + ANode.AsObject.Name[I]);
      end
      else if ANode IS TTJAXYArray then
        for I:=0 to ANode.AsArray.Count - 1 do
          Visit(ANode.AsArray[I], ADepth + 1, APath + '[' + IntToStr(I) + ']');
    finally
      Seen.Delete(Seen.Count - 1);
    end;
  end;

begin
  if AValue = nil then
    Exit;
  Seen:=TList.Create;
  try
    Visit(AValue, 1, '$');
  finally
    Seen.Free;
  end;
end;

constructor TTJAXYDocument.Create;
begin
  inherited Create;
  FRoot:=TTJAXYNull.Create;
end;

class function TTJAXYDocument.CreateArrayRoot: TTJAXYDocument;
begin
  Result:=Self.Create;
  Result.RootNewArray;
end;

class function TTJAXYDocument.CreateObjectRoot: TTJAXYDocument;
begin
  Result:=Self.Create;
  Result.RootNewObject;
end;

constructor TTJAXYDocument.CreateFromObject(AObject: TObject);
begin
  Create;
  LoadFromObject(AObject);
end;

class procedure TTJAXYDocument.RegisterObjectFactory(AClass: TClass; AFactory: TTJAXYObjectFactory);
var
  ActiveMapper: ITJAXYObjectMapper;
begin
  if (AClass = nil) OR (NOT Assigned(AFactory)) then
    raise EArgumentException.Create('Object factory requires a class and callback');
  BeginMappingOperation;
  try
    ActiveMapper:=GetMapper;
    if (ActiveMapper = nil) OR NOT (tjaxymcFactories IN ActiveMapper.Capabilities) then
      raise ETJAXYException.Create('Factory registration requires a registered mapper on this compiler');
    ActiveMapper.RegisterFactory(AClass, AFactory);
  finally
    EndMappingOperation;
  end;
end;

class procedure TTJAXYDocument.UnregisterObjectFactory(AClass: TClass);
var
  ActiveMapper: ITJAXYObjectMapper;
begin
  BeginMappingOperation;
  try
    ActiveMapper:=GetMapper;
    if (ActiveMapper = nil) OR NOT (tjaxymcFactories IN ActiveMapper.Capabilities) then
      raise ETJAXYException.Create('Factory registration requires a registered mapper on this compiler');
    ActiveMapper.UnregisterFactory(AClass);
  finally
    EndMappingOperation;
  end;
end;

class function TTJAXYDocument.DefaultSerializerRules: TTJAXYSerializerRules;
begin
  Result.EnumMode:=tjaxjemOrdinal;
  Result.EnumNameCase:=tjaxyncPreserve;
  SetLength(Result.EnumStripPrefixes, 0);
  Result.EnumAcceptOrdinalOnRead:=True;
  Result.EnumAcceptRawNameOnRead:=True;
  Result.EnumUnknownRead:=tjaxjurIgnore;
end;

class function TTJAXYDocument.CreateFromRecord<T>(const ARecord: T): TTJAXY;
var
  Value: TTJAXYValue;
  ActiveMapper: ITJAXYObjectMapper;
begin
  BeginMappingOperation;
  try
    ActiveMapper:=GetMapper;
    if (ActiveMapper = nil) OR NOT (tjaxymcRecords IN ActiveMapper.Capabilities) then
      raise ETJAXYException.Create('Record mapping requires a registered mapper on this compiler');
    Result:=TTJAXY.CreateObjectRoot;
    try
      Value:=ActiveMapper.SerializeRecord(TypeInfo(T), @ARecord);
      Result.SetRoot(Value);
    except
      Result.Free;
      raise;
    end;
  finally
    EndMappingOperation;
  end;
end;

class function TTJAXYDocument.CreateFromRecordWithRules<T>(const ARecord: T;
  const ARules: TTJAXYSerializerRules): TTJAXY;
var
  Previous: TTJAXYSerializerRules;
begin
  PushMappingRules(ARules, Previous);
  try
    Result:=CreateFromRecord<T>(ARecord);
  finally
    PopMappingRules(Previous);
  end;
end;

destructor TTJAXYDocument.Destroy;
begin
  FreeAndNil(FRoot);
  inherited;
end;

procedure TTJAXYDocument.AssignToObject(AObject: TObject);
var
  ActiveMapper: ITJAXYObjectMapper;
begin
  BeginMappingOperation;
  try
  if Assigned(AObject) AND IsObject then
  begin
    ValidateMappingTree(Root);
    ActiveMapper:=GetMapper;
    if (ActiveMapper = nil) OR NOT (tjaxymcObjects IN ActiveMapper.Capabilities) then
      raise ETJAXYException.Create('Object mapping requires a registered mapper on this compiler');
    ActiveMapper.AssignObject(AObject, AsObject);
  end;
  finally
    EndMappingOperation;
  end;
end;

procedure TTJAXYDocument.AssignToObject(AObject: TObject; const ARules: TTJAXYSerializerRules);
var
  PreviousRules: TTJAXYSerializerRules;
begin
  GlobRulesLock.Enter;
  try
    PreviousRules:=GlobSerializerRules;
    GlobSerializerRules:=TJAXYCloneSerializerRules(ARules);
    try
      AssignToObject(AObject);
    finally
      GlobSerializerRules:=PreviousRules;
    end;
  finally
    GlobRulesLock.Leave;
  end;
end;

procedure TTJAXYDocument.AssignToObject(AObject: TObject;
  out ADiagnostics: TArray<TTJAXYMappingDiagnostic>);
var
  Collector, Previous: TList;
begin
  Collector:=TList.Create;
  Previous:=ThreadMappingDiagnostics;
  ThreadMappingDiagnostics:=Collector;
  try
    try
      AssignToObject(AObject);
    finally
      TJAXYCopyMappingDiagnostics(Collector, ADiagnostics);
    end;
  finally
    ThreadMappingDiagnostics:=Previous;
    TJAXYFreeMappingDiagnostics(Collector);
  end;
end;

procedure TTJAXYDocument.AssignToObject(AObject: TObject;
  const ARules: TTJAXYSerializerRules;
  out ADiagnostics: TArray<TTJAXYMappingDiagnostic>);
var
  Collector, Previous: TList;
begin
  Collector:=TList.Create;
  Previous:=ThreadMappingDiagnostics;
  ThreadMappingDiagnostics:=Collector;
  try
    try
      AssignToObject(AObject, ARules);
    finally
      TJAXYCopyMappingDiagnostics(Collector, ADiagnostics);
    end;
  finally
    ThreadMappingDiagnostics:=Previous;
    TJAXYFreeMappingDiagnostics(Collector);
  end;
end;

procedure TTJAXYDocument.AssignToRecord<T>(var ARecord: T);
var
  ActiveMapper: ITJAXYObjectMapper;
begin
  BeginMappingOperation;
  try
    if IsObject then
    begin
      ValidateMappingTree(Root);
      ActiveMapper:=GetMapper;
      if (ActiveMapper = nil) OR NOT (tjaxymcRecords IN ActiveMapper.Capabilities) then
        raise ETJAXYException.Create('Record mapping requires a registered mapper on this compiler');
      ActiveMapper.AssignRecord(TypeInfo(T), @ARecord, AsObject);
    end;
  finally
    EndMappingOperation;
  end;
end;

procedure TTJAXYDocument.AssignToRecord<T>(var ARecord: T;
  const ARules: TTJAXYSerializerRules);
var
  Previous: TTJAXYSerializerRules;
begin
  PushMappingRules(ARules, Previous);
  try
    AssignToRecord<T>(ARecord);
  finally
    PopMappingRules(Previous);
  end;
end;

procedure TTJAXYDocument.AssignToRecord<T>(var ARecord: T;
  out ADiagnostics: TArray<TTJAXYMappingDiagnostic>);
var
  Collector, Previous: TList;
begin
  BeginDiagnosticsCollection(Previous, Collector);
  try
    AssignToRecord<T>(ARecord);
  finally
    EndDiagnosticsCollection(Previous, Collector, ADiagnostics);
  end;
end;

procedure TTJAXYDocument.AssignToRecord<T>(var ARecord: T;
  const ARules: TTJAXYSerializerRules;
  out ADiagnostics: TArray<TTJAXYMappingDiagnostic>);
var
  Collector, Previous: TList;
begin
  BeginDiagnosticsCollection(Previous, Collector);
  try
    AssignToRecord<T>(ARecord, ARules);
  finally
    EndDiagnosticsCollection(Previous, Collector, ADiagnostics);
  end;
end;

procedure TTJAXYDocument.Assign(ASource: TPersistent);
begin
  if ASource IS TTJAXYDocument then
    SetRoot(TTJAXYDocument(ASource).Root.Copy)
  else
    inherited;
end;

procedure TTJAXYDocument.Clear;
begin
  SetRoot(TTJAXYNull.Create);
end;

function TTJAXYDocument.GetArrayValue(Index: Integer): TTJAXYValue;
begin
  Result:=AsArray[Index];
end;

function TTJAXYDocument.GetAsArray: TTJAXYArray;
begin
  if FRoot IS TTJAXYArray then
    Result:=TTJAXYArray(FRoot)
  else
    Result:=TJAXYInvalidArray;
end;

function TTJAXYDocument.GetAsObject: TTJAXYObject;
begin
  if FRoot IS TTJAXYObject then
    Result:=TTJAXYObject(FRoot)
  else
    Result:=TJAXYInvalidObject;
end;

function TTJAXYDocument.GetIsArray: Boolean;
begin
  Result:=FRoot IS TTJAXYArray;
end;

function TTJAXYDocument.GetIsObject: Boolean;
begin
  Result:=FRoot IS TTJAXYObject;
end;

function TTJAXYDocument.GetObjectValue(Key: String): TTJAXYValue;
begin
  Result:=AsObject[Key];
end;

class function TTJAXYDocument.GetSerializerRules: TTJAXYSerializerRules;
begin
  GlobRulesLock.Enter;
  try
    Result:=TJAXYCloneSerializerRules(GlobSerializerRules);
  finally
    GlobRulesLock.Leave;
  end;
end;

class function TTJAXYDocument.GetMapper: ITJAXYObjectMapper;
begin
  GlobRulesLock.Enter;
  try
    Result:=GlobMapper;
  finally
    GlobRulesLock.Leave;
  end;
end;

class procedure TTJAXYDocument.SetMapper(const AValue: ITJAXYObjectMapper);
begin
  if ThreadMappingDepth <> 0 then
    raise ETJAXYException.Create('Mapper cannot change during a mapping operation');
  GlobRulesLock.Enter;
  try
    GlobMapper:=AValue;
  finally
    GlobRulesLock.Leave;
  end;
end;

class function TTJAXYDocument.GetMapperCapabilities: TTJAXYMapperCapabilities;
var
  ActiveMapper: ITJAXYObjectMapper;
begin
  ActiveMapper:=GetMapper;
  if ActiveMapper = nil then
    Result:=[]
  else
    Result:=ActiveMapper.Capabilities;
end;

function TTJAXYDocument.IsEmpty: Boolean;
begin
  Result:=(FRoot = nil) OR FRoot.IsEmpty;
end;

procedure TTJAXYDocument.LoadFromFile(const AFileName: String);
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

procedure TTJAXYDocument.LoadFromObject(AObject: TObject);
var
  ActiveMapper: ITJAXYObjectMapper;
begin
  BeginMappingOperation;
  try
  if Assigned(AObject) then
  begin
    ActiveMapper:=GetMapper;
    if (ActiveMapper = nil) OR NOT (tjaxymcObjects IN ActiveMapper.Capabilities) then
      raise ETJAXYException.Create('Object mapping requires a registered mapper on this compiler');
    SetRoot(ActiveMapper.SerializeObject(AObject));
  end
  else
    RootNewObject;
  finally
    EndMappingOperation;
  end;
end;

procedure TTJAXYDocument.LoadFromObject(AObject: TObject; const ARules: TTJAXYSerializerRules);
var
  PreviousRules: TTJAXYSerializerRules;
begin
  GlobRulesLock.Enter;
  try
    PreviousRules:=GlobSerializerRules;
    GlobSerializerRules:=TJAXYCloneSerializerRules(ARules);
    try
      LoadFromObject(AObject);
    finally
      GlobSerializerRules:=PreviousRules;
    end;
  finally
    GlobRulesLock.Leave;
  end;
end;

procedure TTJAXYDocument.ReadFromString(const AValue: String);
var
  Stream: TStringStream;
begin
  TJAXYRequireValidText(AValue);
  Stream:=TStringStream.Create(AValue, TEncoding.UTF8, False);
  try
    LoadFromStream(Stream);
  finally
    Stream.Free;
  end;
end;

function TTJAXYDocument.RootNewArray: TTJAXYArray;
begin
  Result:=TTJAXYArray.Create;
  SetRoot(Result);
end;

function TTJAXYDocument.RootNewObject: TTJAXYObject;
begin
  Result:=TTJAXYObject.Create;
  SetRoot(Result);
end;

procedure TTJAXYDocument.SaveToFile(const AFileName: String);
begin
  WriteToFile(AFileName);
end;

procedure TTJAXYDocument.SaveToStream(AStream: TStream);
var
  S: String;
begin
  S:=WriteToString;
  TJAXYWriteUTF8(AStream, S);
end;

procedure TTJAXYDocument.SetRoot(AValue: TTJAXYValue);
begin
  if FRoot = AValue then
    Exit;

  FreeAndNil(FRoot);
  if Assigned(AValue) then
    FRoot:=AValue
  else
    FRoot:=TTJAXYNull.Create;
end;

class procedure TTJAXYDocument.SetSerializerRules(const AValue: TTJAXYSerializerRules);
begin
  if ThreadMappingDepth > 0 then
    raise ETJAXYException.Create('Serializer rules cannot change during a mapping operation');
  GlobRulesLock.Enter;
  try
    GlobSerializerRules:=TJAXYCloneSerializerRules(AValue);
  finally
    GlobRulesLock.Leave;
  end;
end;

function TTJAXYDocument.WriteToFile(const AFileName: String; AWriteMode: TTJAXYStringWriteMode): String;
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

function TTJAXYDocument.WriteToString(AWriteMode: TTJAXYStringWriteMode): String;
var
  Writer: TTJAXYWriter;
begin
  Writer:=TTJAXYWriter.Create(AWriteMode);
  try
    Result:=Writer.Write(FRoot);
  finally
    Writer.Free;
  end;
end;

{ TTJAXY }

class function TTJAXY.CreateTemplate(AName: String): TTJAXYTemplate;
begin
  Result:=TTJAXYTemplate.Create(AName);
  GlobTemplates.AddTemplate(AName, Result);
end;

class function TTJAXY.Template(AName: String): TTJAXYTemplate;
begin
  Result:=GlobTemplates[AName];
end;

class function TTJAXY.CreateArrayRoot: TTJAXY;
begin
  Result:=TTJAXY.Create;
  Result.RootNewArray;
end;

class function TTJAXY.CreateObjectRoot: TTJAXY;
begin
  Result:=TTJAXY.Create;
  Result.RootNewObject;
end;

procedure TTJAXY.LoadFromStream(AStream: TStream);
begin
  raise ETJAXYException.Create('TTJAXY documents do not parse streams directly; use a format codec.');
end;

{ TTJAXYValue }

constructor TTJAXYValue.Create;
begin
  inherited;
end;

function TTJAXYValue.Copy: TTJAXYValue;
var
  I: Integer;
begin
  if Self IS TTJAXYNull then
    Result:=TTJAXYNull.Create
  else if Self IS TTJAXYDateTime then
    Result:=TTJAXYDateTime.CreateFrom(AsString, TTJAXYDateTime(Self).Kind)
  else if Self IS TTJAXYString then
    Result:=TTJAXYString.CreateFrom(AsString)
  else if Self IS TTJAXYInteger then
    Result:=TTJAXYInteger.CreateFrom(AsInteger)
  else if Self IS TTJAXYFloat then
    Result:=TTJAXYFloat.CreateFrom(AsFloat)
  else if Self IS TTJAXYBoolean then
    Result:=TTJAXYBoolean.CreateFrom(AsBoolean)
  else if Self IS TTJAXYObject then
    Result:=TTJAXYObject.CreateFrom(TTJAXYObject(Self))
  else if Self IS TTJAXYArray then
  begin
    Result:=TTJAXYArray.Create;
    for I:=0 to TTJAXYArray(Self).Count - 1 do
      TTJAXYArray(Result).Add(TTJAXYArray(Self).Item[I].Copy);
  end
  else
    Result:=nil;
end;

function TTJAXYValue.GetClass: TTJAXYValueClass;
begin
  Result:=TTJAXYValue;
end;

function TTJAXYValue.GetIsArray: Boolean;
begin
  Result:=Self IS TTJAXYArray;
end;

function TTJAXYValue.GetIsBoolean: Boolean;
begin
  Result:=Self IS TTJAXYBoolean;
end;

function TTJAXYValue.GetIsFloat: Boolean;
begin
  Result:=Self IS TTJAXYFloat;
end;

function TTJAXYValue.GetIsInteger: Boolean;
begin
  Result:=Self IS TTJAXYInteger;
end;

function TTJAXYValue.GetIsNull: Boolean;
begin
  Result:=Self IS TTJAXYNull;
end;

function TTJAXYValue.GetIsObject: Boolean;
begin
  Result:=Self IS TTJAXYObject;
end;

function TTJAXYValue.GetIsString: Boolean;
begin
  Result:=Self IS TTJAXYString;
end;

function TTJAXYValue.GetTyp: TTJAXYType;
begin
  if Self IS TTJAXYNull then
    Result:=tjaxytNull
  else if Self IS TTJAXYInteger then
    Result:=tjaxytInteger
  else if Self IS TTJAXYFloat then
    Result:=tjaxytFloat
  else if Self IS TTJAXYString then
    Result:=tjaxytString
  else if Self IS TTJAXYBoolean then
    Result:=tjaxytBoolean
  else if Self IS TTJAXYObject then
    Result:=tjaxytObject
  else
    Result:=tjaxytArray;
end;

{ TTJAXYNull }

constructor TTJAXYNull.Create;
begin
  inherited;
end;

function TTJAXYNull.GetAsArray: TTJAXYArray;
begin
  Result:=TJAXYInvalidArray;
end;

function TTJAXYNull.GetAsBoolean: Boolean;
begin
  Result:=TJAXYInvalidBoolean;
end;

function TTJAXYNull.GetAsFloat: Extended;
begin
  Result:=TJAXYInvalidFloat;
end;

function TTJAXYNull.GetAsInteger: Int64;
begin
  Result:=TJAXYInvalidInteger;
end;

function TTJAXYNull.GetAsObject: TTJAXYObject;
begin
  Result:=TJAXYInvalidObject;
end;

function TTJAXYNull.GetAsString: String;
begin
  Result:='';
end;

function TTJAXYNull.GetClass: TTJAXYValueClass;
begin
  Result:=TTJAXYNull;
end;

function TTJAXYNull.IsEmpty: Boolean;
begin
  Result:=True;
end;

{ TTJAXYString }

constructor TTJAXYString.Create;
begin
  inherited;
  FValue:='';
end;

constructor TTJAXYString.CreateFrom(AValue: String);
begin
  Create;
  FValue:=AValue;
end;

function TTJAXYString.GetAsArray: TTJAXYArray;
begin
  Result:=TJAXYInvalidArray;
end;

function TTJAXYString.GetAsBoolean: Boolean;
begin
  Result:=TJAXYInvalidBoolean;
end;

function TTJAXYString.GetAsFloat: Extended;
begin
  Result:=TJAXYInvalidFloat;
end;

function TTJAXYString.GetAsInteger: Int64;
begin
  Result:=TJAXYInvalidInteger;
end;

function TTJAXYString.GetAsObject: TTJAXYObject;
begin
  Result:=TJAXYInvalidObject;
end;

function TTJAXYString.GetAsString: String;
begin
  Result:=FValue;
end;

function TTJAXYString.GetClass: TTJAXYValueClass;
begin
  Result:=TTJAXYString;
end;

function TTJAXYString.IsEmpty: Boolean;
begin
  Result:=FValue = '';
end;

{ TTJAXYDateTime }

constructor TTJAXYDateTime.Create;
begin
  inherited;
  FKind:=tjaxydtkLocalDateTime;
end;

constructor TTJAXYDateTime.CreateFrom(AValue: String; AKind: TTJAXYDateTimeKind);
begin
  inherited CreateFrom(AValue);
  FKind:=AKind;
end;

function TTJAXYDateTime.GetClass: TTJAXYValueClass;
begin
  Result:=TTJAXYDateTime;
end;

{ TTJAXYInteger }

constructor TTJAXYInteger.Create;
begin
  inherited;
  FValue:=0;
end;

constructor TTJAXYInteger.CreateFrom(AValue: Int64);
begin
  Create;
  FValue:=AValue;
end;

function TTJAXYInteger.GetAsArray: TTJAXYArray;
begin
  Result:=TJAXYInvalidArray;
end;

function TTJAXYInteger.GetAsBoolean: Boolean;
begin
  Result:=TJAXYInvalidBoolean;
end;

function TTJAXYInteger.GetAsFloat: Extended;
begin
  Result:=FValue;
end;

function TTJAXYInteger.GetAsInteger: Int64;
begin
  Result:=FValue;
end;

function TTJAXYInteger.GetAsObject: TTJAXYObject;
begin
  Result:=TJAXYInvalidObject;
end;

function TTJAXYInteger.GetAsString: String;
begin
  Result:=IntToStr(FValue);
end;

function TTJAXYInteger.GetClass: TTJAXYValueClass;
begin
  Result:=TTJAXYInteger;
end;

function TTJAXYInteger.IsEmpty: Boolean;
begin
  Result:=FValue = 0;
end;

{ TTJAXYFloat }

constructor TTJAXYFloat.Create;
begin
  inherited;
  FValue:=0;
end;

constructor TTJAXYFloat.CreateFrom(AValue: Extended);
begin
  Create;
  FValue:=AValue;
end;

function TTJAXYFloat.GetAsArray: TTJAXYArray;
begin
  Result:=TJAXYInvalidArray;
end;

function TTJAXYFloat.GetAsBoolean: Boolean;
begin
  Result:=TJAXYInvalidBoolean;
end;

function TTJAXYFloat.GetAsFloat: Extended;
begin
  Result:=FValue;
end;

function TTJAXYFloat.GetAsInteger: Int64;
begin
  Result:=Trunc(FValue);
end;

function TTJAXYFloat.GetAsObject: TTJAXYObject;
begin
  Result:=TJAXYInvalidObject;
end;

function TTJAXYFloat.GetAsString: String;
begin
  Result:=FloatToStr(FValue, TJAXYFormatSettings);
end;

function TTJAXYFloat.GetClass: TTJAXYValueClass;
begin
  Result:=TTJAXYFloat;
end;

function TTJAXYFloat.IsEmpty: Boolean;
begin
  Result:=FValue = 0;
end;

{ TTJAXYBoolean }

constructor TTJAXYBoolean.Create;
begin
  inherited;
  FValue:=False;
end;

constructor TTJAXYBoolean.CreateFrom(AValue: Boolean);
begin
  Create;
  FValue:=AValue;
end;

function TTJAXYBoolean.GetAsArray: TTJAXYArray;
begin
  Result:=TJAXYInvalidArray;
end;

function TTJAXYBoolean.GetAsBoolean: Boolean;
begin
  Result:=FValue;
end;

function TTJAXYBoolean.GetAsFloat: Extended;
begin
  Result:=TJAXYInvalidFloat;
end;

function TTJAXYBoolean.GetAsInteger: Int64;
begin
  Result:=TJAXYInvalidInteger;
end;

function TTJAXYBoolean.GetAsObject: TTJAXYObject;
begin
  Result:=TJAXYInvalidObject;
end;

function TTJAXYBoolean.GetAsString: String;
begin
  if FValue then
    Result:=TJAXY_LITERAL_TRUE
  else
    Result:=TJAXY_LITERAL_FALSE;
end;

function TTJAXYBoolean.GetClass: TTJAXYValueClass;
begin
  Result:=TTJAXYBoolean;
end;

function TTJAXYBoolean.IsEmpty: Boolean;
begin
  Result:=NOT FValue;
end;

{ TTJAXYObject }

constructor TTJAXYObject.Create;
begin
  inherited;
  FKeys:=TStringList.Create;
  FKeys.Sorted:=False;
  FKeys.CaseSensitive:=True;
  FKeys.Duplicates:=dupError;
end;

constructor TTJAXYObject.CreateFrom(AObject: TTJAXYObject);
var
  I: Integer;
begin
  Create;
  for I:=0 to AObject.Count - 1 do
    Add(AObject.Name[I], AObject.Item[I].Copy);
end;

destructor TTJAXYObject.Destroy;
begin
  Clear;
  FreeAndNil(FKeys);
  inherited;
end;

procedure TTJAXYObject.Add(AKey: String);
begin
  Add(AKey, TTJAXYNull.Create);
end;

procedure TTJAXYObject.Add(AKey: String; AValue: String);
begin
  Add(AKey, TTJAXYString.CreateFrom(AValue));
end;

procedure TTJAXYObject.Add(AKey: String; AValue: Int64);
begin
  Add(AKey, TTJAXYInteger.CreateFrom(AValue));
end;

procedure TTJAXYObject.Add(AKey: String; AValue: Extended);
begin
  Add(AKey, TTJAXYFloat.CreateFrom(AValue));
end;

procedure TTJAXYObject.Add(AKey: String; AValue: Boolean);
begin
  Add(AKey, TTJAXYBoolean.CreateFrom(AValue));
end;

procedure TTJAXYObject.Add(AKey: String; AValue: TTJAXYValue);
begin
  if HasKey(AKey) then
  begin
    AValue.Free;
    raise ETJAXYException.CreateFmt(RCS_DUPLICATE_KEY, [AKey]);
  end;
  FKeys.AddObject(AKey, AValue);
end;

procedure TTJAXYObject.AddArray(AKey: String; AArray: TTJAXYArray);
begin
  Add(AKey, AArray);
end;

function TTJAXYObject.AddArray(AKey: String): TTJAXYArray;
begin
  Result:=TTJAXYArray.Create;
  Add(AKey, Result);
end;

procedure TTJAXYObject.AddObject(AKey: String; AObject: TTJAXYObject);
begin
  Add(AKey, AObject);
end;

function TTJAXYObject.AddObject(AKey: String): TTJAXYObject;
begin
  Result:=TTJAXYObject.Create;
  Add(AKey, Result);
end;

procedure TTJAXYObject.Clear;
var
  I: Integer;
begin
  for I:=0 to FKeys.Count - 1 do
    FKeys.Objects[I].Free;
  FKeys.Clear;
end;

procedure TTJAXYObject.Delete(AKey: String);
var
  I: Integer;
begin
  I:=IndexOf(AKey);
  if I >= 0 then
  begin
    FKeys.Objects[I].Free;
    FKeys.Delete(I);
  end;
end;

function TTJAXYObject.GetAsArray: TTJAXYArray;
begin
  Result:=TJAXYInvalidArray;
end;

function TTJAXYObject.GetAsBoolean: Boolean;
begin
  Result:=TJAXYInvalidBoolean;
end;

function TTJAXYObject.GetAsFloat: Extended;
begin
  Result:=TJAXYInvalidFloat;
end;

function TTJAXYObject.GetAsInteger: Int64;
begin
  Result:=TJAXYInvalidInteger;
end;

function TTJAXYObject.GetAsObject: TTJAXYObject;
begin
  Result:=Self;
end;

function TTJAXYObject.GetAsString: String;
begin
  Result:=ToString;
end;

function TTJAXYObject.GetClass: TTJAXYValueClass;
begin
  Result:=TTJAXYObject;
end;

function TTJAXYObject.GetCount: Integer;
begin
  Result:=FKeys.Count;
end;

function TTJAXYObject.GetItem(Index: Integer): TTJAXYValue;
begin
  Result:=TTJAXYValue(FKeys.Objects[Index]);
end;

function TTJAXYObject.GetName(Index: Integer): String;
begin
  Result:=FKeys[Index];
end;

function TTJAXYObject.GetOrAdd(AKey: String; ADefault: String): String;
begin
  if NOT HasKey(AKey) then
    Add(AKey, ADefault);
  Result:=Value[AKey].AsString;
end;

function TTJAXYObject.GetOrAdd(AKey: String; ADefault: Int64): Int64;
begin
  if NOT HasKey(AKey) then
    Add(AKey, ADefault);
  Result:=Value[AKey].AsInteger;
end;

function TTJAXYObject.GetOrAdd(AKey: String; ADefault: Extended): Extended;
begin
  if NOT HasKey(AKey) then
    Add(AKey, ADefault);
  Result:=Value[AKey].AsFloat;
end;

function TTJAXYObject.GetOrAdd(AKey: String; ADefault: Boolean): Boolean;
begin
  if NOT HasKey(AKey) then
    Add(AKey, ADefault);
  Result:=Value[AKey].AsBoolean;
end;

function TTJAXYObject.GetOrAddArray(AKey: String): TTJAXYArray;
begin
  if NOT HasKey(AKey) then
    Result:=AddArray(AKey)
  else if Value[AKey] IS TTJAXYArray then
    Result:=Value[AKey].AsArray
  else
  begin
    SetOrAdd(AKey, TTJAXYArray.Create);
    Result:=Value[AKey].AsArray;
  end;
end;

function TTJAXYObject.GetOrAddObject(AKey: String): TTJAXYObject;
begin
  if NOT HasKey(AKey) then
    Result:=AddObject(AKey)
  else if Value[AKey] IS TTJAXYObject then
    Result:=Value[AKey].AsObject
  else
  begin
    SetOrAdd(AKey, TTJAXYObject.Create);
    Result:=Value[AKey].AsObject;
  end;
end;

function TTJAXYObject.GetItemByKey(Key: String): TTJAXYValue;
var
  I: Integer;
begin
  I:=IndexOf(Key);
  if I >= 0 then
    Result:=TTJAXYValue(FKeys.Objects[I])
  else
    Result:=nil;
end;

function TTJAXYObject.GetNode(const AKey: String): TTJAXYValue;
var
  Attrs: TTJAXYValue;
begin
  if AKey = '' then
  begin
    if HasKey(TJAXY_TEXT_KEY) then
      Exit(TJAXYUsefulValue(Value[TJAXY_TEXT_KEY]));
    Exit(nil);
  end;

  Result:=TJAXYUsefulValue(Value[AKey]);
  if Assigned(Result) then
    Exit;

  Attrs:=Value[TJAXY_ATTR_KEY];
  if Assigned(Attrs) AND Attrs.IsObject then
    Result:=TJAXYUsefulValue(Attrs.AsObject.Value[AKey])
  else
    Result:=nil;
end;

function TTJAXYObject.FindNode(const AQuery: String): TTJAXYValue;
var
  Parts: TStringList;

  function FindRecursive(AValue: TTJAXYValue; const AKey: String): TTJAXYValue;
  var
    J: Integer;
  begin
    Result:=nil;
    if NOT Assigned(AValue) then
      Exit;

    if AValue.IsObject then
    begin
      Result:=AValue.AsObject.GetNode(AKey);
      if Assigned(Result) then
        Exit;

      for J:=0 to AValue.AsObject.Count - 1 do
      begin
        if AValue.AsObject.Name[J] = TJAXY_ATTR_KEY then
          Continue;
        Result:=FindRecursive(AValue.AsObject.Item[J], AKey);
        if Assigned(Result) then
          Exit;
      end;
    end
    else if AValue.IsArray then
      for J:=0 to AValue.AsArray.Count - 1 do
      begin
        Result:=FindRecursive(AValue.AsArray[J], AKey);
        if Assigned(Result) then
          Exit;
      end;
  end;

  function HasPathSyntax(const AValue: String): Boolean;
  begin
    Result:=(Pos(TJAXY_PATH_SEPARATOR, AValue) > 0) OR (Pos(TJAXY_PATH_ARRAY_OPEN, AValue) > 0);
  end;

  procedure SplitPath(const AValue: String; ADest: TStrings);
  var
    P: Integer;
    Token: String;
  begin
    Token:='';
    for P:=1 to Length(AValue) + 1 do
    begin
      if (P > Length(AValue)) OR (AValue[P] = TJAXY_PATH_SEPARATOR) then
      begin
        ADest.Add(Token);
        Token:='';
      end
      else
        Token:=Token + AValue[P];
    end;
  end;

  function ParseSegment(const ASegment: String; out AKey, ASelector: String; out AHasSelector: Boolean): Boolean;
  var
    OpenPos: Integer;
    ClosePos: Integer;
  begin
    Result:=False;
    AKey:=ASegment;
    ASelector:='';
    AHasSelector:=False;

    OpenPos:=Pos(TJAXY_PATH_ARRAY_OPEN, ASegment);
    if OpenPos <= 0 then
      Exit(ASegment <> '');

    ClosePos:=Pos(TJAXY_PATH_ARRAY_CLOSE, ASegment);
    if (ClosePos <= OpenPos) OR (ClosePos <> Length(ASegment)) then
      Exit;

    AKey:=System.Copy(ASegment, 1, OpenPos - 1);
    ASelector:=System.Copy(ASegment, OpenPos + 1, ClosePos - OpenPos - 1);
    AHasSelector:=True;
    Result:=True;
  end;

  function ResolvePath(AValue: TTJAXYValue; APartIndex: Integer): TTJAXYValue;
  var
    Key: String;
    Selector: String;
    HasSelector: Boolean;
    Index: Integer;
    J: Integer;
    Next: TTJAXYValue;
  begin
    Result:=nil;
    if NOT Assigned(AValue) then
      Exit;

    if APartIndex >= Parts.Count then
      Exit(TJAXYUsefulValue(AValue));

    if NOT ParseSegment(Parts[APartIndex], Key, Selector, HasSelector) then
      Exit;

    if AValue.IsArray AND (Key <> '') then
    begin
      for J:=0 to AValue.AsArray.Count - 1 do
      begin
        Result:=ResolvePath(AValue.AsArray[J], APartIndex);
        if Assigned(Result) then
          Exit;
      end;
      Exit;
    end;

    Next:=AValue;
    if Key <> '' then
    begin
      if NOT Next.IsObject then
        Exit;
      Next:=Next.AsObject.GetNode(Key);
    end;

    if HasSelector then
    begin
      if NOT Assigned(Next) OR NOT Next.IsArray then
        Exit;

      if (Selector = '') OR (Selector = TJAXY_PATH_ARRAY_WILDCARD) then
      begin
        for J:=0 to Next.AsArray.Count - 1 do
        begin
          Result:=ResolvePath(Next.AsArray[J], APartIndex + 1);
          if Assigned(Result) then
            Exit;
        end;
        Exit;
      end;

      if NOT TryStrToInt(Selector, Index) then
        Exit;
      if (Index < 0) OR (Index >= Next.AsArray.Count) then
        Exit;
      Next:=Next.AsArray[Index];
    end;

    Result:=ResolvePath(Next, APartIndex + 1);
  end;

begin
  if AQuery = '' then
    Exit(GetNode(''));

  if NOT HasPathSyntax(AQuery) then
    Exit(FindRecursive(Self, AQuery));

  Parts:=TStringList.Create;
  try
    SplitPath(AQuery, Parts);
    Result:=ResolvePath(Self, 0);
  finally
    Parts.Free;
  end;
end;

function TTJAXYObject.GetValue(const AKey, ADefault: String): String;
begin
  Result:=TJAXYValueAsStringOrDefault(GetNode(AKey), ADefault);
end;

function TTJAXYObject.GetValue(const AKey: String; ADefault: Int64): Int64;
begin
  Result:=TJAXYValueAsIntegerOrDefault(GetNode(AKey), ADefault);
end;

function TTJAXYObject.GetValue(const AKey: String; ADefault: Extended): Extended;
begin
  Result:=TJAXYValueAsFloatOrDefault(GetNode(AKey), ADefault);
end;

function TTJAXYObject.GetValue(const AKey: String; ADefault: Boolean): Boolean;
begin
  Result:=TJAXYValueAsBooleanOrDefault(GetNode(AKey), ADefault);
end;

function TTJAXYObject.FindValue(const AQuery, ADefault: String): String;
begin
  Result:=TJAXYValueAsStringOrDefault(FindNode(AQuery), ADefault);
end;

function TTJAXYObject.FindValue(const AQuery: String; ADefault: Int64): Int64;
begin
  Result:=TJAXYValueAsIntegerOrDefault(FindNode(AQuery), ADefault);
end;

function TTJAXYObject.FindValue(const AQuery: String; ADefault: Extended): Extended;
begin
  Result:=TJAXYValueAsFloatOrDefault(FindNode(AQuery), ADefault);
end;

function TTJAXYObject.FindValue(const AQuery: String; ADefault: Boolean): Boolean;
begin
  Result:=TJAXYValueAsBooleanOrDefault(FindNode(AQuery), ADefault);
end;

function TTJAXYObject.HasKey(AKey: String): Boolean;
begin
  Result:=IndexOf(AKey) >= 0;
end;

function TTJAXYObject.IndexOf(AKey: String): Integer;
var
  I: Integer;
begin
  Result:=-1;
  for I:=0 to FKeys.Count - 1 do
    if FKeys[I] = AKey then
      Exit(I);
end;

function TTJAXYObject.IsEmpty: Boolean;
begin
  Result:=FKeys.Count = 0;
end;

procedure TTJAXYObject.Merge(ASource: TTJAXYObject);
var
  I: Integer;
  Key: String;
begin
  if NOT Assigned(ASource) then
    Exit;

  for I:=0 to ASource.Count - 1 do
  begin
    Key:=ASource.Name[I];
    if HasKey(Key) AND (Value[Key] IS TTJAXYObject) AND (ASource.Item[I] IS TTJAXYObject) then
      Value[Key].AsObject.Merge(ASource.Item[I].AsObject)
    else
      SetOrAdd(Key, ASource.Item[I].Copy);
  end;
end;

procedure TTJAXYObject.SetOrAdd(AKey: String);
begin
  SetOrAdd(AKey, TTJAXYNull.Create);
end;

procedure TTJAXYObject.SetOrAdd(AKey: String; AValue: String);
begin
  SetOrAdd(AKey, TTJAXYString.CreateFrom(AValue));
end;

procedure TTJAXYObject.SetOrAdd(AKey: String; AValue: Int64);
begin
  SetOrAdd(AKey, TTJAXYInteger.CreateFrom(AValue));
end;

procedure TTJAXYObject.SetOrAdd(AKey: String; AValue: Extended);
begin
  SetOrAdd(AKey, TTJAXYFloat.CreateFrom(AValue));
end;

procedure TTJAXYObject.SetOrAdd(AKey: String; AValue: Boolean);
begin
  SetOrAdd(AKey, TTJAXYBoolean.CreateFrom(AValue));
end;

procedure TTJAXYObject.SetOrAdd(AKey: String; AValue: TTJAXYValue);
var
  I: Integer;
begin
  I:=IndexOf(AKey);
  if I < 0 then
    Add(AKey, AValue)
  else
  begin
    FKeys.Objects[I].Free;
    FKeys.Objects[I]:=AValue;
  end;
end;

function TTJAXYObject.ToString: String;
var
  Writer: TTJAXYWriter;
begin
  Writer:=TTJAXYWriter.Create(tjaxywmCondensed);
  try
    Result:=Writer.Write(Self);
  finally
    Writer.Free;
  end;
end;

{ TTJAXYArray }

constructor TTJAXYArray.Create;
begin
  inherited;
  FValues:=TList.Create;
end;

destructor TTJAXYArray.Destroy;
begin
  Clear;
  FreeAndNil(FValues);
  inherited;
end;

procedure TTJAXYArray.Add;
begin
  Add(TTJAXYNull.Create);
end;

procedure TTJAXYArray.Add(AValue: String);
begin
  Add(TTJAXYString.CreateFrom(AValue));
end;

procedure TTJAXYArray.Add(AValue: Int64);
begin
  Add(TTJAXYInteger.CreateFrom(AValue));
end;

procedure TTJAXYArray.Add(AValue: Extended);
begin
  Add(TTJAXYFloat.CreateFrom(AValue));
end;

procedure TTJAXYArray.Add(AValue: Boolean);
begin
  Add(TTJAXYBoolean.CreateFrom(AValue));
end;

procedure TTJAXYArray.Add(AValue: TTJAXYValue);
begin
  FValues.Add(AValue);
end;

procedure TTJAXYArray.AddArray(AArray: TTJAXYArray);
begin
  Add(AArray);
end;

function TTJAXYArray.AddArray: TTJAXYArray;
begin
  Result:=TTJAXYArray.Create;
  Add(Result);
end;

procedure TTJAXYArray.AddObject(AObject: TTJAXYObject);
begin
  Add(AObject);
end;

function TTJAXYArray.AddObject: TTJAXYObject;
begin
  Result:=TTJAXYObject.Create;
  Add(Result);
end;

function TTJAXYArray.AddObject(AKey: String; AValue: TTJAXYValue): TTJAXYObject;
begin
  Result:=AddObject;
  Result.Add(AKey, AValue);
end;

procedure TTJAXYArray.Clear;
var
  I: Integer;
begin
  for I:=0 to FValues.Count - 1 do
    TObject(FValues[I]).Free;
  FValues.Clear;
end;

procedure TTJAXYArray.Delete(AIndex: Integer);
begin
  TObject(FValues[AIndex]).Free;
  FValues.Delete(AIndex);
end;

procedure TTJAXYArray.Exchange(AIndex1, AIndex2: Integer);
begin
  FValues.Exchange(AIndex1, AIndex2);
end;

function TTJAXYArray.GetAsArray: TTJAXYArray;
begin
  Result:=Self;
end;

function TTJAXYArray.GetAsBoolean: Boolean;
begin
  Result:=TJAXYInvalidBoolean;
end;

function TTJAXYArray.GetAsFloat: Extended;
begin
  Result:=TJAXYInvalidFloat;
end;

function TTJAXYArray.GetAsInteger: Int64;
begin
  Result:=TJAXYInvalidInteger;
end;

function TTJAXYArray.GetAsObject: TTJAXYObject;
begin
  Result:=TJAXYInvalidObject;
end;

function TTJAXYArray.GetAsString: String;
begin
  Result:=ToString;
end;

function TTJAXYArray.GetClass: TTJAXYValueClass;
begin
  Result:=TTJAXYArray;
end;

function TTJAXYArray.GetCount: Integer;
begin
  Result:=FValues.Count;
end;

function TTJAXYArray.GetItem(Index: Integer): TTJAXYValue;
begin
  Result:=TTJAXYValue(FValues[Index]);
end;

procedure TTJAXYArray.Insert(AIndex: Integer; AValue: TTJAXYValue);
begin
  FValues.Insert(AIndex, AValue);
end;

function TTJAXYArray.IsEmpty: Boolean;
begin
  Result:=FValues.Count = 0;
end;

procedure TTJAXYArray.Move(ACurIndex, ANewIndex: Integer);
begin
  FValues.Move(ACurIndex, ANewIndex);
end;

procedure TTJAXYArray.Replace(AIndex: Integer; AValue: TTJAXYValue);
begin
  TObject(FValues[AIndex]).Free;
  FValues[AIndex]:=AValue;
end;

function TTJAXYArray.ToString: String;
var
  Writer: TTJAXYWriter;
begin
  Writer:=TTJAXYWriter.Create(tjaxywmCondensed);
  try
    Result:=Writer.Write(Self);
  finally
    Writer.Free;
  end;
end;

{ TTJAXYTemplate }

constructor TTJAXYTemplate.Create(AName: String);
begin
  inherited Create;
  FName:=AName;
  FDocument:=TTJAXY.CreateObjectRoot;
  FLastAdded:=-1;
  SetLength(FValues, 0);
end;

destructor TTJAXYTemplate.Destroy;
begin
  Cleanup;
  FreeAndNil(FDocument);
  inherited;
end;

function TTJAXYTemplate.Add(AName: String; AType: TTJAXYTemplateType; ATemplate: TTJAXYTemplate; ACallback: TTJAXYTemplateFillCallback): TTJAXYTemplate;
var
  I: Integer;
begin
  Result:=Self;
  for I:=Low(FValues) to High(FValues) do
    if SameText(AName, FValues[I].Name) then
      raise ETJAXYException.Create(RCS_FIELD_NAME_ALREADY_EXISTS);

  SetLength(FValues, Length(FValues) + 1);
  FLastAdded:=High(FValues);
  FValues[FLastAdded].Name:=AName;
  FValues[FLastAdded].Typ:=AType;
  FValues[FLastAdded].Nested:=ATemplate;
  FValues[FLastAdded].Callback:=ACallback;
end;

function TTJAXYTemplate.Add(AName: String; AType: TTJAXYType): TTJAXYTemplate;
begin
  Result:=Add(AName, TJAXY_TYPE_TO_TEMPLATE_TYPE[AType], nil, nil);
end;

function TTJAXYTemplate.Add(AName: String; AType: TTJAXYTemplateType): TTJAXYTemplate;
begin
  Result:=Add(AName, AType, nil, nil);
end;

function TTJAXYTemplate.Add(AName: String; ATemplate: TTJAXYTemplate): TTJAXYTemplate;
begin
  if Assigned(ATemplate) then
    Result:=Add(AName, tjaxyttTemplate, ATemplate, nil)
  else
    raise ETJAXYException.Create(RCS_TEMPLATE_REQUIRED);
end;

function TTJAXYTemplate.Add(AName: String; ATemplateName: String): TTJAXYTemplate;
begin
  if Length(Trim(ATemplateName)) = 0 then
    raise ETJAXYException.CreateFmt(RCS_TEMPLATE_NAME_REQUIRED, [AName]);
  if NOT Assigned(TTJAXY.Template(ATemplateName)) then
    raise ETJAXYException.CreateFmt(RCS_TEMPLATE_NAME_NOT_FOUND, [ATemplateName]);
  Result:=Add(AName, tjaxyttTemplate, TTJAXY.Template(ATemplateName), nil);
end;

function TTJAXYTemplate.Add(AName: String; ACallback: TTJAXYTemplateFillCallback): TTJAXYTemplate;
begin
  Result:=Add(AName, tjaxyttCallback, nil, ACallback);
end;

function TTJAXYTemplate.Add(AField: TTJAXYTemplateField): TTJAXYTemplate;
begin
  Result:=Add(AField.Name, AField.Typ, AField.Nested, AField.Callback);
end;

procedure TTJAXYTemplate.Cleanup;
var
  I: Integer;
begin
  for I:=Low(FValues) to High(FValues) do
    FreeAndNil(FValues[I].Default);
end;

procedure TTJAXYTemplate.Clear;
begin
  FDocument.RootNewObject;
end;

function TTJAXYTemplate.Default(AValue: TTJAXYValue): TTJAXYTemplate;
begin
  Result:=Self;
  if FLastAdded >= 0 then
  begin
    FreeAndNil(FValues[FLastAdded].Default);
    FValues[FLastAdded].Default:=AValue;
  end;
end;

procedure TTJAXYTemplate.DoTemplateFillCallback(ATemplateName, AKeyName: String; var AValue: TTJAXYValue);
begin
  if Assigned(FOnTemplateFillCallback) then
    FOnTemplateFillCallback(ATemplateName, AKeyName, AValue);
end;

function TTJAXYTemplate.Empty(AUseDefaults: Boolean): TTJAXY;
var
  I: Integer;
  V: TTJAXYValue;
begin
  FDocument.RootNewObject;
  for I:=Low(FValues) to High(FValues) do
  begin
    if (tjaxytfOmitEmpty IN FFlags) AND NOT (AUseDefaults AND Assigned(FValues[I].Default)) AND NOT (FValues[I].Typ IN TJAXY_ADVANCED_TEMPLATE_TYPES) then
      Continue;

    if AUseDefaults AND Assigned(FValues[I].Default) then
      V:=FValues[I].Default.Copy
    else
      V:=TJAXYTemplateValue(FValues[I].Typ);

    if Assigned(V) then
    begin
      if TJAXYTemplateTypeForValue(V) = FValues[I].Typ then
        FDocument.AsObject.Add(FValues[I].Name, V)
      else
      begin
        V.Free;
        raise ETJAXYException.CreateFmt(RCS_FIELD_VALUE_TYPE_MISMATCH, [TJAXY_TEMPLATE_TYPE_STRINGS[FValues[I].Typ], TJAXY_TYPE_STRINGS[V.Typ]]);
      end;
    end else
    case FValues[I].Typ of
      tjaxyttName: FDocument.AsObject.Add(FValues[I].Name, TTJAXYString.CreateFrom(FName));
      tjaxyttUnixTime: FDocument.AsObject.Add(FValues[I].Name, TTJAXYInteger.CreateFrom(DateTimeToUnix(Now)));
      tjaxyttTemplate: FDocument.AsObject.Add(FValues[I].Name, FValues[I].Nested.Empty.AsObject.Copy);
      else FDocument.AsObject.Add(FValues[I].Name, TTJAXYNull.Create);
    end;
  end;
  Result:=FDocument;
end;

function TTJAXYTemplate.Fill(AValues: Array of const): TTJAXY;
var
  I, Skipped: Integer;
  V: TTJAXYValue;
begin
  FDocument.RootNewObject;
  if GetTemplateFieldCount <> Length(AValues) then
    raise ETJAXYException.Create(RCS_FIELD_COUNT_MISMATCH);

  Skipped:=0;
  for I:=Low(FValues) to High(FValues) do
  begin
    V:=nil;
    if FValues[I].Typ IN TJAXY_AUTOFILL_TEMPLATE_TYPES then
    begin
      Inc(Skipped);
      if FValues[I].Typ = tjaxyttCallback then
      begin
        if Assigned(FValues[I].Callback) then
          FValues[I].Callback(FName, FValues[I].Name, V)
        else
          DoTemplateFillCallback(FName, FValues[I].Name, V);
      end;
    end else
    case AValues[I - Skipped].VType of
      vtInteger: V:=TTJAXYInteger.CreateFrom(AValues[I - Skipped].VInteger);
      vtBoolean: V:=TTJAXYBoolean.CreateFrom(AValues[I - Skipped].VBoolean);
      vtChar: V:=TTJAXYString.CreateFrom(String(AValues[I - Skipped].VChar));
      vtExtended: V:=TTJAXYFloat.CreateFrom(AValues[I - Skipped].VExtended^);
      vtString: V:=TTJAXYString.CreateFrom(String(AValues[I - Skipped].VString^));
      vtPointer: V:=TTJAXYNull.Create;
      vtPChar: V:=TTJAXYString.CreateFrom(String(AValues[I - Skipped].VPChar));
      vtObject:
      begin
        if AValues[I - Skipped].VObject IS TTJAXYDocument then
          V:=TTJAXYDocument(AValues[I - Skipped].VObject).Root.Copy
        else if AValues[I - Skipped].VObject IS TTJAXYValue then
          V:=TTJAXYValue(AValues[I - Skipped].VObject).Copy
        else
          V:=TTJAXYNull.Create;
      end;
{$IF DECLARED(vtDynArray)}
      vtDynArray: V:=TTJAXYArray.Create;
{$ENDIF}
      vtClass: V:=TTJAXYNull.Create;
      vtWideChar: V:=TTJAXYString.CreateFrom(String(WideString(AValues[I - Skipped].VWideChar)));
      vtPWideChar: V:=TTJAXYString.CreateFrom(String(AValues[I - Skipped].VPWideChar));
      vtAnsiString: V:=TTJAXYString.CreateFrom(String(AnsiString(AValues[I - Skipped].VAnsiString)));
      vtCurrency: V:=TTJAXYFloat.CreateFrom(AValues[I - Skipped].VCurrency^);
      vtVariant: V:=TTJAXYNull.Create;
      vtInterface: V:=TTJAXYNull.Create;
      vtWideString: V:=TTJAXYString.CreateFrom(String(PWideChar(AValues[I - Skipped].VWideString)));
      vtInt64: V:=TTJAXYInteger.CreateFrom(AValues[I - Skipped].VInt64^);
      vtUnicodeString: V:=TTJAXYString.CreateFrom(String(AValues[I - Skipped].VUnicodeString));
    else
      V:=TTJAXYNull.Create;
    end;

    if Assigned(V) then
    begin
      if (TJAXYTemplateTypeForValue(V) = FValues[I].Typ) OR V.IsNull OR (FValues[I].Typ IN [tjaxyttTemplate, tjaxyttCallback]) then
        FDocument.AsObject.Add(FValues[I].Name, V)
      else
      begin
        V.Free;
        raise ETJAXYException.CreateFmt(RCS_FIELD_VALUE_TYPE_MISMATCH, [TJAXY_TEMPLATE_TYPE_STRINGS[FValues[I].Typ], TJAXY_TYPE_STRINGS[V.Typ]]);
      end;
    end else
    if NOT (tjaxytfOmitEmpty IN FFlags) then
    case FValues[I].Typ of
      tjaxyttName: FDocument.AsObject.Add(FValues[I].Name, TTJAXYString.CreateFrom(FName));
      tjaxyttUnixTime: FDocument.AsObject.Add(FValues[I].Name, TTJAXYInteger.CreateFrom(DateTimeToUnix(Now)));
      tjaxyttTemplate: FDocument.AsObject.Add(FValues[I].Name, FValues[I].Nested.Empty.AsObject.Copy);
      else FDocument.AsObject.Add(FValues[I].Name, TTJAXYNull.Create);
    end;
  end;
  Result:=FDocument;
end;

function TTJAXYTemplate.GetTemplateFieldCount: Integer;
var
  I: Integer;
begin
  Result:=0;
  for I:=Low(FValues) to High(FValues) do
    if NOT (FValues[I].Typ IN TJAXY_AUTOFILL_TEMPLATE_TYPES) then
      Inc(Result);
end;

function TTJAXYTemplate.SetFlag(AFlag: TTJAXYTemplateFlag): TTJAXYTemplate;
begin
  Result:=Self;
  FFlags:=FFlags + [AFlag];
end;

function TTJAXYTemplate.SetFlags(AFlags: TTJAXYTemplateFlags): TTJAXYTemplate;
begin
  Result:=Self;
  FFlags:=AFlags;
end;

function TTJAXYTemplate.SetValue(AName: String; const AValue: Variant): Boolean;
var
  I: Integer;
  V: TTJAXYValue;
  TargetIndex: Integer;
begin
  Result:=False;
  TargetIndex:=-1;
  for I:=Low(FValues) to High(FValues) do
    if SameText(FValues[I].Name, AName) then
    begin
      TargetIndex:=I;
      Break;
    end;
  if TargetIndex < 0 then
    Exit;

  case VarType(AValue) of
    varSmallInt, varShortInt, varInteger, varByte, varWord, varLongWord, varInt64, varUInt64: V:=TTJAXYInteger.CreateFrom(AValue);
    varSingle, varDouble, varCurrency, varDate: V:=TTJAXYFloat.CreateFrom(AValue);
    varBoolean: V:=TTJAXYBoolean.CreateFrom(AValue);
    varOleStr, varString, varUString: V:=TTJAXYString.CreateFrom(AValue);
  else
    V:=TTJAXYNull.Create;
  end;

  if FValues[TargetIndex].Typ = TJAXYTemplateTypeForValue(V) then
  begin
    FDocument.AsObject.SetOrAdd(AName, V);
    Result:=True;
  end else
    V.Free;
end;

{ TTJAXYWriter }

constructor TTJAXYWriter.Create(AMode: TTJAXYStringWriteMode);
begin
  inherited Create;
  FMode:=AMode;
end;

class function TTJAXYWriter.EncodeString(AString: String): String;
var
  I: Integer;
  C: Char;
begin
  Result:='"';
  for I:=1 to Length(AString) do
  begin
    C:=AString[I];
    case C of
      '"': Result:=Result + '\"';
      '\': Result:=Result + '\\';
      #8: Result:=Result + '\b';
      #9: Result:=Result + '\t';
      #10: Result:=Result + '\n';
      #12: Result:=Result + '\f';
      #13: Result:=Result + '\r';
    else
      if Ord(C) < 32 then
        Result:=Result + '\u' + IntToHex(Ord(C), 4)
      else
        Result:=Result + C;
    end;
  end;
  Result:=Result + '"';
end;

function TTJAXYWriter.Indent(ALevel: Integer): String;
begin
  if FMode = tjaxywmReadable then
    Result:=StringOfChar(' ', ALevel * TJAXY_INDENT_COUNT)
  else
    Result:='';
end;

function TTJAXYWriter.NewLine: String;
begin
  if FMode = tjaxywmReadable then
    Result:=TJAXY_LINE_FEED
  else
    Result:='';
end;

function TTJAXYWriter.Space: String;
begin
  if FMode = tjaxywmReadable then
    Result:=' '
  else
    Result:='';
end;

function TTJAXYWriter.Write(AValue: TTJAXYValue): String;
begin
  Result:=WriteValue(AValue, 0);
end;

function TTJAXYWriter.WriteArray(AArray: TTJAXYArray; ALevel: Integer): String;
var
  I: Integer;
begin
  if AArray.Count = 0 then
    Exit('[]');

  Result:='[' + NewLine;
  for I:=0 to AArray.Count - 1 do
  begin
    if I > 0 then
      Result:=Result + ',' + NewLine;
    Result:=Result + Indent(ALevel + 1) + WriteValue(AArray[I], ALevel + 1);
  end;
  Result:=Result + NewLine + Indent(ALevel) + ']';
end;

function TTJAXYWriter.WriteObject(AObject: TTJAXYObject; ALevel: Integer): String;
var
  I: Integer;
begin
  if AObject.Count = 0 then
    Exit('{}');

  Result:='{' + NewLine;
  for I:=0 to AObject.Count - 1 do
  begin
    if I > 0 then
      Result:=Result + ',' + NewLine;
    Result:=Result + Indent(ALevel + 1) + EncodeString(AObject.Name[I]) + ':' + Space + WriteValue(AObject.Item[I], ALevel + 1);
  end;
  Result:=Result + NewLine + Indent(ALevel) + '}';
end;

function TTJAXYWriter.WriteValue(AValue: TTJAXYValue; ALevel: Integer): String;
begin
  if (AValue = nil) OR AValue.IsNull then
    Result:=TJAXY_LITERAL_NULL
  else
  case AValue.Typ of
    tjaxytNull: Result:=TJAXY_LITERAL_NULL;
    tjaxytInteger: Result:=IntToStr(AValue.AsInteger);
    tjaxytFloat: Result:=FloatToStr(AValue.AsFloat, TJAXYFormatSettings);
    tjaxytString: Result:=EncodeString(AValue.AsString);
    tjaxytBoolean:
      if AValue.AsBoolean then
        Result:=TJAXY_LITERAL_TRUE
      else
        Result:=TJAXY_LITERAL_FALSE;
    tjaxytObject: Result:=WriteObject(AValue.AsObject, ALevel);
    tjaxytArray: Result:=WriteArray(AValue.AsArray, ALevel);
  else
    Result:=TJAXY_LITERAL_NULL;
  end;
end;

initialization
  GlobRulesLock:=TCriticalSection.Create;
  GlobTemplates:=TTJAXYTemplatesList.Create;
  GlobSerializerRules:=TTJAXYDocument.DefaultSerializerRules;
  {$IFDEF TJAXY_USE_RTTI}
  GlobMapper:=TTJAXYDefaultMapper.Create;
  {$ENDIF}

finalization
  GlobMapper:=nil;
  FreeAndNil(GlobTemplates);
  FreeAndNil(GlobRulesLock);

end.
