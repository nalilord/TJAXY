(******************************************************************************)
(*                                                                            *)
(*  Delphi YAML Parser Class                                                  *)
(*                                                                            *)
(*  Version     : 0.02                                                        *)
(*  License     : BSD 2-Clause                                                *)
(*  Author      : NaliLord / TJAXY contributors                               *)
(*                                                                            *)
(*  This unit owns the central YAML DOM and implements KYAML/YAML parsing.    *)
(*  KYAML: https://kubernetes.io/docs/reference/encodings/kyaml/              *)
(*                                                                            *)
(******************************************************************************)

unit TJAXY.YAML;

interface

uses
  SysUtils, Classes, TJAXY.Core;

type
  TYAMLEncoding = (yeKYAML, yeYAML);
  TYAMLConfigurationOptions = record
    MaxInputBytes: Integer;
    MaxDepth: Integer;
    MaxNodes: Integer;
  end;
  TYAMLType = TTJAXYType;
  TYAMLStringWriteMode = (ywmReadable, ywmCondensed);

  TYAML = class;
  TYAMLValue = TTJAXYValue;
  TYAMLNull = TTJAXYNull;
  TYAMLString = TTJAXYString;
  TYAMLInteger = TTJAXYInteger;
  TYAMLFloat = TTJAXYFloat;
  TYAMLBoolean = TTJAXYBoolean;
  TYAMLObject = TTJAXYObject;
  TYAMLArray = TTJAXYArray;
  TYAMLClass = TTJAXYValueClass;

  EYAMLException = class(Exception)
  private
    FLine: Integer;
    FColumn: Integer;
    FReason: String;
  public
    constructor Create(AMessage: String; ALine, AColumn: Integer);
    property Line: Integer read FLine;
    property Column: Integer read FColumn;
    property Reason: String read FReason;
  end;

  TYAML = class(TTJAXYParser)
  private
    FData: TStringStream;
    FDocuments: TList;
    FEncoding: TYAMLEncoding;
    FConfigurationProfile: Boolean;
    FConfigurationOptions: TYAMLConfigurationOptions;
    FRoot: TYAMLValue;
    FWriteDocumentMarker: Boolean;
    function GetIsObject: Boolean;
    function GetIsArray: Boolean;
    function GetAsArray: TYAMLArray;
    function GetAsObject: TYAMLObject;
    function GetObjectValue(Key: String): TYAMLValue;
    function GetArrayValue(Index: Integer): TYAMLValue;
    function GetDocument(Index: Integer): TYAMLValue;
    function GetDocumentCount: Integer;
    procedure ReplaceDocuments(ANewDocuments: TList);
    procedure SetConfigurationOptions(const AValue: TYAMLConfigurationOptions);
  protected
    procedure Parse;
    procedure SetRoot(AValue: TTJAXYValue); override;
  public
    class function DefaultConfigurationOptions: TYAMLConfigurationOptions; static;
    class function EncodeString(AString: String): String;
    class function IsSafeKey(AKey: String): Boolean;
    class function CreateTemplate(AName: String): TTJAXYTemplate; static;
    class function Template(AName: String): TTJAXYTemplate; static;
    class function CreateArrayRoot: TYAML; reintroduce; static;
    class function CreateObjectRoot: TYAML; reintroduce; static;
    class function NewArrayRoot: TYAML; static;
    class function NewObjectRoot: TYAML; static;
    class function FromString(AValue: String; AEncoding: TYAMLEncoding = yeKYAML): TYAML; static;
    class function FromFile(AFile: String; AEncoding: TYAMLEncoding = yeKYAML): TYAML; static;
    class function FromStream(AStream: TStream; AEncoding: TYAMLEncoding = yeKYAML): TYAML; static;
    class function FromConfigurationString(const AValue: String): TYAML; overload; static;
    class function FromConfigurationString(const AValue: String; const AOptions: TYAMLConfigurationOptions): TYAML; overload; static;
    class function FromConfigurationFile(const AFile: String): TYAML; overload; static;
    class function FromConfigurationFile(const AFile: String; const AOptions: TYAMLConfigurationOptions): TYAML; overload; static;
    class function FromConfigurationStream(AStream: TStream): TYAML; overload; static;
    class function FromConfigurationStream(AStream: TStream; const AOptions: TYAMLConfigurationOptions): TYAML; overload; static;
    constructor Create; override;
    constructor CreateFromObject(AObject: TObject); override;
    class function CreateFromRecord<T>(const ARecord: T): TYAML; static;
    class function CreateFromRecordWithRules<T>(const ARecord: T; const ARules: TTJAXYSerializerRules): TYAML; static;
    constructor CreateFromString(AValue: String; AEncoding: TYAMLEncoding = yeKYAML);
    class function CreateFromFile(AFile: String; AEncoding: TYAMLEncoding = yeKYAML): TYAML; static;
    constructor CreateFromStream(AStream: TStream; AEncoding: TYAMLEncoding = yeKYAML);
    destructor Destroy; override;
    function IsEmpty: Boolean; override;
    function WriteToString(AWriteMode: TTJAXYStringWriteMode): String; overload; override;
    function WriteToString(AWriteMode: TYAMLStringWriteMode = ywmReadable): String; reintroduce; overload; virtual;
    function WriteToFile(const AFileName: String; AWriteMode: TTJAXYStringWriteMode): String; overload; override;
    function WriteToFile(const AFileName: String; AWriteMode: TYAMLStringWriteMode = ywmReadable): String; reintroduce; overload; virtual;
    function RootNewArray: TYAMLArray; reintroduce;
    function RootNewObject: TYAMLObject; reintroduce;
    function DocumentAsObject(Index: Integer): TYAMLObject;
    function DocumentAsArray(Index: Integer): TYAMLArray;
    procedure Assign(ASource: TPersistent); override;
    procedure Clear; override;
    procedure LoadFromFile(const AFileName: String); override;
    procedure LoadFromStream(AStream: TStream); override;
    procedure ReadFromString(const AValue: String); override;
    procedure SaveToFile(const AFileName: String); override;
    procedure SaveToStream(AStream: TStream); override;
    property Encoding: TYAMLEncoding read FEncoding write FEncoding;
    property ConfigurationOptions: TYAMLConfigurationOptions read FConfigurationOptions write SetConfigurationOptions;
    property WriteDocumentMarker: Boolean read FWriteDocumentMarker write FWriteDocumentMarker;
    property ObjectValue[Key: String]: TYAMLValue read GetObjectValue; default;
    property ArrayValue[Index: Integer]: TYAMLValue read GetArrayValue;
    property Document[Index: Integer]: TYAMLValue read GetDocument;
    property DocumentCount: Integer read GetDocumentCount;
    property Root: TYAMLValue read FRoot;
    property IsObject: Boolean read GetIsObject;
    property IsArray: Boolean read GetIsArray;
    property AsObject: TYAMLObject read GetAsObject;
    property AsArray: TYAMLArray read GetAsArray;
  end;

const
  kytNull = tjaxytNull;
  kytInteger = tjaxytInteger;
  kytFloat = tjaxytFloat;
  kytString = tjaxytString;
  kytBoolean = tjaxytBoolean;
  kytObject = tjaxytObject;
  kytArray = tjaxytArray;

implementation

uses
  Math;

function YAMLDecimalInteger(const AValue: String): Boolean;
var
  I, StartIndex: Integer;
begin
  Result:=False;
  if AValue = '' then
    Exit;
  StartIndex:=1;
  if AValue[1] = '-' then
    StartIndex:=2;
  if StartIndex > Length(AValue) then
    Exit;
  for I:=StartIndex to Length(AValue) do
    if NOT CharInSet(AValue[I], ['0'..'9']) then
      Exit;
  Result:=True;
end;

resourcestring
  RCS_KYAML_PARSER_EXCEPTION = 'KYAML Parser Exception at Line: %d Col: %d: %s';
  RCS_INVALID_VALUE_CAST = 'Invalid KYAML value cast';
  RCS_DUPLICATE_KEY = 'Duplicate KYAML object key "%s"';
  RCS_EXPECTED_VALUE = 'Expected KYAML value';
  RCS_EXPECTED_CHAR = 'Expected "%s"';
  RCS_EXPECTED_KEY = 'Expected KYAML object key';
  RCS_UNQUOTED_STRING_VALUE = 'Unquoted string values are not allowed in KYAML';
  RCS_FORBIDDEN_YAML_FEATURE = 'YAML feature "%s" is not allowed in KYAML';
  RCS_UNSUPPORTED_ENCODING = 'YAML encoding is not implemented yet';
  RCS_INVALID_YAML = 'Invalid YAML';
  RCS_UNSUPPORTED_YAML_FEATURE = 'YAML feature "%s" is not implemented yet';
  RCS_INVALID_NUMBER = 'Invalid KYAML number';
  RCS_TRAILING_DATA = 'Unexpected trailing data';
  RCS_UNTERMINATED_STRING = 'Unterminated string';
  RCS_INVALID_STRING_ESCAPE = 'Invalid string escape';
  RCS_INVALID_HEX_ESCAPE = 'Invalid hex escape';
  RCS_INVALID_UNICODE_ESCAPE = 'Invalid unicode escape';
  RCS_INVALID_CONTROL_CHAR_IN_STRING = 'Invalid control character in string';
  RCS_UNKNOWN_ALIAS = 'Unknown YAML alias "%s"';
  RCS_INVALID_MERGE_VALUE = 'YAML merge value must be an object or array of objects';
  RCS_TABS_NOT_ALLOWED = 'Tabs are not allowed for YAML indentation';
  RCS_ALIAS_WITH_PROPERTIES = 'Aliases may not have node properties';
  RCS_INVALID_TAG = 'Invalid YAML tag';
  RCS_UNEXPECTED_DIRECTIVE = 'Unexpected YAML directive';
  RCS_INVALID_DIRECTIVE = 'Invalid YAML directive';
  RCS_UNDEFINED_TAG_HANDLE = 'Undefined YAML tag handle';
  RCS_DIRECTIVE_WITHOUT_DOCUMENT = 'YAML directive without document';
  RCS_CONTENT_AFTER_DOCUMENT_END = 'Unexpected content after document end marker';
  RCS_INVALID_BLOCK_SCALAR_CHOMP = 'Invalid block scalar chomping indicator';
  RCS_INVALID_BLOCK_SCALAR_INDENT = 'Invalid block scalar indentation indicator';
  RCS_INVALID_BLOCK_SCALAR = 'Invalid block scalar indicator';
  RCS_DUPLICATE_SCALAR_ANCHOR = 'Scalar value may not have two anchors';

function TJAXYWriteModeToYAML(AWriteMode: TTJAXYStringWriteMode): TYAMLStringWriteMode;
begin
  case AWriteMode of
    tjaxywmReadable: Result:=ywmReadable;
    tjaxywmCondensed: Result:=ywmCondensed;
  else
    Result:=ywmReadable;
  end;
end;


type
  TYAMLChar = (
    ycNull, ycTab, ycLineFeed, ycCarriageReturn, ycSpace, ycExclamation, ycDoubleQuote, ycHash, ycPercent, ycAmpersand, ycSingleQuote, ycAsterisk, ycPlus, ycComma, 
    ycDash, ycDot, ycSlash, ycColon, ycLessThan, ycGreaterThan, ycQuestion, ycLeftBracket, ycBackslash, ycRightBracket, ycLeftBrace, ycPipe, ycRightBrace, ycOther
  );

  TYAMLChars = set of TYAMLChar;

const
  YAML_CHARS: Array[TYAMLChar] of Char = (
    #0, #9, #10, #13, ' ', '!', '"', '#', '%', '&', '''', '*', '+', ',', 
    '-', '.', '/', ':', '<', '>', '?', '[', '\', ']', '{', '|', '}', #0);

  YAML_LITERAL_TRUE = 'true';
  YAML_LITERAL_FALSE = 'false';
  YAML_LITERAL_NULL = 'null';
  YAML_LITERAL_NULL_SHORT = '~';
  YAML_DOCUMENT_START = '---';
  YAML_DOCUMENT_END = '...';
  YAML_FEATURE_ANCHORS = 'anchors';
  YAML_FEATURE_ALIASES = 'aliases';
  YAML_FEATURE_TAGS = 'tags';
  YAML_FEATURE_BLOCK_SCALARS = 'block scalars';
  YAML_FEATURE_MERGE_KEYS = 'merge keys';
  YAML_ESCAPE_DOUBLE_QUOTE = '\"';
  YAML_ESCAPE_BACKSLASH = '\\';
  YAML_ESCAPE_BACKSPACE = '\b';
  YAML_ESCAPE_TAB = '\t';
  YAML_ESCAPE_LINE_FEED = '\n';
  YAML_ESCAPE_FORM_FEED = '\f';
  YAML_ESCAPE_CARRIAGE_RETURN = '\r';
  YAML_ESCAPE_UNICODE_PREFIX = '\u';
  YAML_INDENT_SIZE = 2;

type
  TYAMLRestrictedFeature = (yrfAnchors, yrfAliases, yrfTags,
    yrfDirectives, yrfMergeKeys, yrfComplexKeys, yrfImplicitFlowMapping);

function YAMLProfileAllows(AConfigurationProfile: Boolean;
  AFeature: TYAMLRestrictedFeature): Boolean;
begin
  if NOT AConfigurationProfile then
    Exit(True);
  case AFeature of
    yrfAnchors, yrfAliases, yrfTags, yrfDirectives, yrfMergeKeys,
    yrfComplexKeys, yrfImplicitFlowMapping:
      Result:=False;
  else
    Result:=False;
  end;
end;

type
  TYAMLParseBudget = class
  public
    Nodes: Integer;
    MaxNodes: Integer;
    constructor Create(AMaxNodes: Integer);
    function Charge: Boolean;
  end;

  TYAMLParser = class
  private
    FText: String;
    FIndex: Integer;
    FLine: Integer;
    FColumn: Integer;
    FStrictKYAML: Boolean;
    FConfigurationProfile: Boolean;
    FDepth: Integer;
    FBudget: TYAMLParseBudget;
    FOwnsBudget: Boolean;
    FMaxDepth: Integer;
    procedure CountNode;
    function Current: Char;
    function Peek(AOffset: Integer = 1): Char;
    function Eof: Boolean;
    function IsIdentifierStart(AChar: Char): Boolean;
    function IsIdentifierChar(AChar: Char): Boolean;
    function ReadFlowKey: String;
    function ReadIdentifier: String;
    function ReadQuotedString: String;
    function ReadSingleQuotedString: String;
    function ReadPlainScalar: TYAMLValue;
    function ReadNumber: TYAMLValue;
    function ResolveScalar(AValue: String): TYAMLValue;
    function ValueToKey(AValue: TYAMLValue): String;
    procedure Advance;
    procedure CheckForbidden;
    procedure Error(AMessage: String);
    procedure Expect(AChar: Char);
    procedure SkipWhite;
    procedure ParseDocumentMarker;
  public
    constructor Create(AText: String; AStrictKYAML: Boolean = True; AConfigurationProfile: Boolean = False; AMaxDepth: Integer = 32;
      AMaxNodes: Integer = 10000; ABudget: TYAMLParseBudget = nil);
    destructor Destroy; override;
    function Parse: TYAMLValue;
    function ParseValue: TYAMLValue;
    function ParseObject: TYAMLObject;
    function ParseArray: TYAMLArray;
    function ParseKey: String;
  end;

  TYAMLBlockParser = class
  private
    FLines: TStringList;
    FAnchors: TStringList;
    FIndex: Integer;
    FConfigurationProfile: Boolean;
    FDepth: Integer;
    FBudget: TYAMLParseBudget;
    FMaxDepth: Integer;
    FLineOffset: Integer;
    procedure CountNode(ALine, AColumn: Integer);
    function AliasValue(const AName: String; ALineNo, AColumn: Integer): TYAMLValue;
    function CurrentLine: String;
    function CurrentLineNo: Integer;
    function CurrentIndent: Integer;
    function Eof: Boolean;
    function ExtractNodeProperties(var AValue: String; out AAnchor, AAlias: String): Boolean;
    function FindValueColon(const ALine: String): Integer;
    function FlowBalance(const AValue: String): Integer;
    function CollectFlowValue(AValue: String; AMinIndent: Integer = -1): String;
    function CollectPlainScalar(AValue: String; AIndent: Integer; AAllowContinuation: Boolean; ABreakOnSequence: Boolean = True): String;
    function QuoteBalance(const AValue: String): Char;
    function CollectQuotedValue(AValue: String): String;
    function HasContent(const ALine: String): Boolean;
    function IsSequenceLine(AIndent: Integer): Boolean;
    function ParseInlineValue(const AValue: String; ALineNo, AColumn: Integer): TYAMLValue;
    function ParseCompactSequenceItem(const AValue: String; ALineNo, AColumn: Integer): TYAMLValue;
    function ParseKey(const AKey: String; ALineNo: Integer): String;
    function IsBlockScalarHeader(const AValue: String): Boolean;
    function ParseBlockScalar(const AHeader: String; AIndent, ALineNo: Integer): TYAMLString;
    function RemoveComment(const ALine: String): String;
    function TrimRightSpaces(const AValue: String): String;
    function CountIndent(const ALine: String): Integer;
    procedure Error(const AMessage: String; ALine, AColumn: Integer);
    procedure Load(AText: String);
    procedure ApplyMerge(AObject: TYAMLObject; AValue: TYAMLValue);
    procedure StoreAnchor(const AName: String; AValue: TYAMLValue);
    function ValueToKey(AValue: TYAMLValue): String;
    procedure SkipIgnorable;
    procedure ParseObjectInto(AObject: TYAMLObject; AIndent: Integer);
  public
    constructor Create(AText: String; AConfigurationProfile: Boolean = False; AMaxDepth: Integer = 32; AMaxNodes: Integer = 10000;
      AFirstLine: Integer = 1);
    destructor Destroy; override;
    function Parse: TYAMLValue;
    function ParseNode(AIndent: Integer): TYAMLValue;
    function ParseObject(AIndent: Integer): TYAMLObject;
    function ParseArray(AIndent: Integer): TYAMLArray;
    procedure ParseDocuments(ADocuments: TList);
  end;

  TYAMLWriter = class
  private
    FMode: TYAMLStringWriteMode;
    function Indent(ALevel: Integer): String;
    function Space: String;
    function NewLine: String;
    function WriteKey(AKey: String): String;
    function WriteValue(AValue: TYAMLValue; ALevel: Integer): String;
    function WriteObject(AObject: TYAMLObject; ALevel: Integer): String;
    function WriteArray(AArray: TYAMLArray; ALevel: Integer): String;
  public
    constructor Create(AMode: TYAMLStringWriteMode);
    function Write(AValue: TYAMLValue; ADocumentMarker: Boolean): String;
  end;

function YAMLChar(AChar: TYAMLChar): Char; inline;
begin
  Result:=YAML_CHARS[AChar];
end;

function IsYAMLChar(AValue: Char; AChars: TYAMLChars): Boolean; inline;
var
  C: TYAMLChar;
begin
  Result:=False;
  for C:=Low(TYAMLChar) to High(TYAMLChar) do
    if (C in AChars) AND (AValue = YAML_CHARS[C]) then
      Exit(True);
end;

function CharToYAML(AValue: Char): TYAMLChar; inline;
begin
  case AValue of
    #0: Result:=ycNull;
    #9: Result:=ycTab;
    #10: Result:=ycLineFeed;
    #13: Result:=ycCarriageReturn;
    ' ': Result:=ycSpace;
    '!': Result:=ycExclamation;
    '"': Result:=ycDoubleQuote;
    '#': Result:=ycHash;
    '%': Result:=ycPercent;
    '&': Result:=ycAmpersand;
    '''': Result:=ycSingleQuote;
    '*': Result:=ycAsterisk;
    '+': Result:=ycPlus;
    ',': Result:=ycComma;
    '-': Result:=ycDash;
    '.': Result:=ycDot;
    '/': Result:=ycSlash;
    ':': Result:=ycColon;
    '<': Result:=ycLessThan;
    '>': Result:=ycGreaterThan;
    '?': Result:=ycQuestion;
    '[': Result:=ycLeftBracket;
    '\': Result:=ycBackslash;
    ']': Result:=ycRightBracket;
    '{': Result:=ycLeftBrace;
    '|': Result:=ycPipe;
    '}': Result:=ycRightBrace;
  else
    Result:=ycOther;
  end;
end;

function YAMLFormatSettings: TFormatSettings;
begin
  Result:=FormatSettings;
  Result.DecimalSeparator:=YAML_CHARS[ycDot];
  Result.ThousandSeparator:=YAML_CHARS[ycComma];
end;

function YAMLInvalidArray: TYAMLArray;
begin
  Result:=nil;
  raise Exception.Create(RCS_INVALID_VALUE_CAST);
end;

function YAMLInvalidBoolean: Boolean;
begin
  Result:=False;
  raise Exception.Create(RCS_INVALID_VALUE_CAST);
end;

function YAMLInvalidFloat: Extended;
begin
  Result:=0;
  raise Exception.Create(RCS_INVALID_VALUE_CAST);
end;

function YAMLInvalidInteger: Int64;
begin
  Result:=0;
  raise Exception.Create(RCS_INVALID_VALUE_CAST);
end;

function YAMLInvalidObject: TYAMLObject;
begin
  Result:=nil;
  raise Exception.Create(RCS_INVALID_VALUE_CAST);
end;

function YAMLInvalidString: String;
begin
  Result:='';
  raise Exception.Create(RCS_INVALID_VALUE_CAST);
end;

{ EYAMLException }

constructor EYAMLException.Create(AMessage: String; ALine, AColumn: Integer);
begin
  FLine:=ALine;
  FColumn:=AColumn;
  FReason:=AMessage;
  inherited Create(Format(RCS_KYAML_PARSER_EXCEPTION, [ALine, AColumn, AMessage]));
end;

{ TYAML }

class function TYAML.EncodeString(AString: String): String;
var
  I: Integer;
  C: Char;
begin
  Result:=YAML_CHARS[ycDoubleQuote];
  for I:=1 to Length(AString) do
  begin
    C:=AString[I];
    case C of
      '"': Result:=Result + YAML_ESCAPE_DOUBLE_QUOTE;
      '\': Result:=Result + YAML_ESCAPE_BACKSLASH;
      #8: Result:=Result + YAML_ESCAPE_BACKSPACE;
      #9: Result:=Result + YAML_ESCAPE_TAB;
      #10: Result:=Result + YAML_ESCAPE_LINE_FEED;
      #12: Result:=Result + YAML_ESCAPE_FORM_FEED;
      #13: Result:=Result + YAML_ESCAPE_CARRIAGE_RETURN;
    else
      if Ord(C) < 32 then
        Result:=Result + YAML_ESCAPE_UNICODE_PREFIX + IntToHex(Ord(C), 4)
      else
        Result:=Result + C;
    end;
  end;
  Result:=Result + YAML_CHARS[ycDoubleQuote];
end;

class function TYAML.IsSafeKey(AKey: String): Boolean;
var
  I: Integer;
begin
  Result:=AKey <> '';
  if NOT Result then
    Exit;

  Result:=CharInSet(AKey[1], ['A'..'Z', 'a'..'z', '_']);
  if NOT Result then
    Exit;

  for I:=2 to Length(AKey) do
    if NOT CharInSet(AKey[I], ['A'..'Z', 'a'..'z', '0'..'9', '_', '-', '.']) then
      Exit(False);

  if SameText(AKey, YAML_LITERAL_TRUE) OR SameText(AKey, YAML_LITERAL_FALSE) OR SameText(AKey, YAML_LITERAL_NULL) then
    Result:=False;
end;

class function TYAML.CreateTemplate(AName: String): TTJAXYTemplate;
begin
  Result:=TTJAXY.CreateTemplate(AName);
end;

class function TYAML.Template(AName: String): TTJAXYTemplate;
begin
  Result:=TTJAXY.Template(AName);
end;

constructor TYAML.Create;
begin
  inherited Create;
  FData:=TStringStream.Create('', TEncoding.UTF8, False);
  FDocuments:=TList.Create;
  FEncoding:=yeKYAML;
  FConfigurationOptions:=DefaultConfigurationOptions;
  SetRoot(TYAMLNull.Create);
end;

class function TYAML.DefaultConfigurationOptions: TYAMLConfigurationOptions;
begin
  Result.MaxInputBytes:=256 * 1024;
  Result.MaxDepth:=32;
  Result.MaxNodes:=10000;
end;

procedure TYAML.SetConfigurationOptions(const AValue: TYAMLConfigurationOptions);
begin
  if (AValue.MaxInputBytes <= 0) OR (AValue.MaxInputBytes = MaxInt) OR
    (AValue.MaxDepth <= 0) OR (AValue.MaxNodes <= 0) then
    raise EArgumentException.Create('Configuration limits must be positive');
  FConfigurationOptions:=AValue;
end;

class function TYAML.CreateArrayRoot: TYAML;
begin
  Result:=TYAML.Create;
  try
    Result.RootNewArray;
  except
    Result.Free;
    raise;
  end;
end;

class function TYAML.CreateObjectRoot: TYAML;
begin
  Result:=TYAML.Create;
  try
    Result.RootNewObject;
  except
    Result.Free;
    raise;
  end;
end;

class function TYAML.NewArrayRoot: TYAML;
begin
  Result:=TYAML.CreateArrayRoot;
end;

class function TYAML.NewObjectRoot: TYAML;
begin
  Result:=TYAML.CreateObjectRoot;
end;

class function TYAML.FromString(AValue: String; AEncoding: TYAMLEncoding): TYAML;
begin
  Result:=TYAML.Create;
  try
    Result.FEncoding:=AEncoding;
    Result.ReadFromString(AValue);
  except
    Result.Free;
    raise;
  end;
end;

class function TYAML.FromFile(AFile: String; AEncoding: TYAMLEncoding): TYAML;
begin
  Result:=TYAML.Create;
  try
    Result.FEncoding:=AEncoding;
    Result.LoadFromFile(AFile);
  except
    Result.Free;
    raise;
  end;
end;

class function TYAML.FromStream(AStream: TStream; AEncoding: TYAMLEncoding): TYAML;
begin
  Result:=TYAML.Create;
  try
    Result.FEncoding:=AEncoding;
    Result.LoadFromStream(AStream);
  except
    Result.Free;
    raise;
  end;
end;

class function TYAML.FromConfigurationString(const AValue: String): TYAML;
begin
  Result:=FromConfigurationString(AValue, DefaultConfigurationOptions);
end;

class function TYAML.FromConfigurationString(const AValue: String; const AOptions: TYAMLConfigurationOptions): TYAML;
begin
  Result:=TYAML.Create;
  try
    Result.FEncoding:=yeYAML;
    Result.FConfigurationProfile:=True;
    Result.ConfigurationOptions:=AOptions;
    Result.ReadFromString(AValue);
  except
    Result.Free;
    raise;
  end;
end;

class function TYAML.FromConfigurationFile(const AFile: String): TYAML;
begin
  Result:=FromConfigurationFile(AFile, DefaultConfigurationOptions);
end;

class function TYAML.FromConfigurationFile(const AFile: String; const AOptions: TYAMLConfigurationOptions): TYAML;
begin
  Result:=TYAML.Create;
  try
    Result.FEncoding:=yeYAML;
    Result.FConfigurationProfile:=True;
    Result.ConfigurationOptions:=AOptions;
    Result.LoadFromFile(AFile);
  except
    Result.Free;
    raise;
  end;
end;

class function TYAML.FromConfigurationStream(AStream: TStream): TYAML;
begin
  Result:=FromConfigurationStream(AStream, DefaultConfigurationOptions);
end;

class function TYAML.FromConfigurationStream(AStream: TStream; const AOptions: TYAMLConfigurationOptions): TYAML;
begin
  Result:=TYAML.Create;
  try
    Result.FEncoding:=yeYAML;
    Result.FConfigurationProfile:=True;
    Result.ConfigurationOptions:=AOptions;
    Result.LoadFromStream(AStream);
  except
    Result.Free;
    raise;
  end;
end;

constructor TYAML.CreateFromObject(AObject: TObject);
begin
  Create;
  LoadFromObject(AObject);
end;

class function TYAML.CreateFromFile(AFile: String; AEncoding: TYAMLEncoding): TYAML;
begin
  Result:=TYAML.Create;
  try
    Result.FEncoding:=AEncoding;
    Result.LoadFromFile(AFile);
  except
    Result.Free;
    raise;
  end;
end;

class function TYAML.CreateFromRecord<T>(const ARecord: T): TYAML;
var
  Doc: TTJAXY;
begin
  Result:=TYAML.Create;
  Doc:=TTJAXY.CreateFromRecord<T>(ARecord);
  try
    Result.SetRoot(Doc.Root.Copy);
  finally
    Doc.Free;
  end;
end;

class function TYAML.CreateFromRecordWithRules<T>(const ARecord: T; const ARules: TTJAXYSerializerRules): TYAML;
var
  Doc: TTJAXY;
begin
  Doc:=TTJAXY.CreateFromRecordWithRules<T>(ARecord, ARules);
  try
    Result:=TYAML.Create;
    try
      Result.SetRoot(Doc.Root.Copy);
    except
      Result.Free;
      raise;
    end;
  finally
    Doc.Free;
  end;
end;

constructor TYAML.CreateFromStream(AStream: TStream; AEncoding: TYAMLEncoding);
begin
  Create;
  FEncoding:=AEncoding;
  LoadFromStream(AStream);
end;

constructor TYAML.CreateFromString(AValue: String; AEncoding: TYAMLEncoding);
begin
  Create;
  FEncoding:=AEncoding;
  ReadFromString(AValue);
end;

destructor TYAML.Destroy;
var
  I: Integer;
begin
  if FDocuments <> nil then
    for I:=1 to FDocuments.Count - 1 do
      TObject(FDocuments[I]).Free;
  FreeAndNil(FDocuments);
  FreeAndNil(FData);
  inherited;
end;

procedure TYAML.Assign(ASource: TPersistent);
var
  I: Integer;
  NewDocuments: TList;
begin
  if ASource IS TYAML then
  begin
    if ASource = Self then
      Exit;
    NewDocuments:=TList.Create;
    try
      for I:=0 to TYAML(ASource).DocumentCount - 1 do
        NewDocuments.Add(TYAML(ASource).Document[I].Copy);
      ReplaceDocuments(NewDocuments);
      NewDocuments:=nil;
      FData.Clear;
      FEncoding:=TYAML(ASource).FEncoding;
      FConfigurationProfile:=TYAML(ASource).FConfigurationProfile;
      FConfigurationOptions:=TYAML(ASource).FConfigurationOptions;
      FWriteDocumentMarker:=TYAML(ASource).FWriteDocumentMarker;
    finally
      if NewDocuments <> nil then
      begin
        for I:=0 to NewDocuments.Count - 1 do
          TObject(NewDocuments[I]).Free;
        NewDocuments.Free;
      end;
    end;
  end
  else
    inherited;
end;

procedure TYAML.Clear;
begin
  FData.Clear;
  SetRoot(TYAMLNull.Create);
end;

function TYAML.DocumentAsArray(Index: Integer): TYAMLArray;
begin
  if Document[Index] IS TYAMLArray then
    Result:=TYAMLArray(Document[Index])
  else
    Result:=YAMLInvalidArray;
end;

function TYAML.DocumentAsObject(Index: Integer): TYAMLObject;
begin
  if Document[Index] IS TYAMLObject then
    Result:=TYAMLObject(Document[Index])
  else
    Result:=YAMLInvalidObject;
end;

function TYAML.GetArrayValue(Index: Integer): TYAMLValue;
begin
  Result:=AsArray[Index];
end;

function TYAML.GetAsArray: TYAMLArray;
begin
  if FRoot IS TYAMLArray then
    Result:=TYAMLArray(FRoot)
  else
    Result:=YAMLInvalidArray;
end;

function TYAML.GetAsObject: TYAMLObject;
begin
  if FRoot IS TYAMLObject then
    Result:=TYAMLObject(FRoot)
  else
    Result:=YAMLInvalidObject;
end;

function TYAML.GetDocument(Index: Integer): TYAMLValue;
begin
  Result:=TYAMLValue(FDocuments[Index]);
end;

function TYAML.GetDocumentCount: Integer;
begin
  Result:=FDocuments.Count;
end;

function TYAML.GetIsArray: Boolean;
begin
  Result:=FRoot IS TYAMLArray;
end;

function TYAML.GetIsObject: Boolean;
begin
  Result:=FRoot IS TYAMLObject;
end;

function TYAML.GetObjectValue(Key: String): TYAMLValue;
begin
  Result:=AsObject[Key];
end;

procedure TYAML.ReplaceDocuments(ANewDocuments: TList);
var
  I: Integer;
  OldDocuments: TList;
begin
  if ANewDocuments.Count = 0 then
    ANewDocuments.Add(TYAMLNull.Create);
  OldDocuments:=FDocuments;
  if OldDocuments <> nil then
    for I:=1 to OldDocuments.Count - 1 do
      TObject(OldDocuments[I]).Free;
  FRoot:=TYAMLValue(ANewDocuments[0]);
  inherited SetRoot(FRoot);
  FDocuments:=ANewDocuments;
  OldDocuments.Free;
end;

procedure TYAML.SetRoot(AValue: TTJAXYValue);
var
  NewDocuments: TList;
begin
  if AValue = FRoot then
    Exit;
  NewDocuments:=TList.Create;
  try
    NewDocuments.Add(AValue);
    ReplaceDocuments(NewDocuments);
  except
    NewDocuments.Free;
    raise;
  end;
end;

function TYAML.IsEmpty: Boolean;
begin
  Result:=(FRoot = nil) OR FRoot.IsEmpty;
end;

procedure TYAML.LoadFromFile(const AFileName: String);
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

procedure TYAML.LoadFromStream(AStream: TStream);
var
  Bytes: TBytes;
  Buffer: array[0..8191] of Byte;
  Accumulated: TMemoryStream;
  ByteCount, Offset, ReadCount, ReadLimit: Integer;
begin
  FData.Clear;
  if FConfigurationProfile then
  begin
    Accumulated:=TMemoryStream.Create;
    try
      while True do
      begin
        ReadLimit:=FConfigurationOptions.MaxInputBytes + 1 - Integer(Accumulated.Size);
        if ReadLimit > SizeOf(Buffer) then
          ReadLimit:=SizeOf(Buffer);
        ReadCount:=AStream.Read(Buffer, ReadLimit);
        if ReadCount = 0 then
          Break;
        Accumulated.WriteBuffer(Buffer, ReadCount);
        if Accumulated.Size > FConfigurationOptions.MaxInputBytes then
          raise EYAMLException.Create(Format('Configuration exceeds %d bytes', [FConfigurationOptions.MaxInputBytes]), 1, 1);
      end;
      ByteCount:=Accumulated.Size;
      SetLength(Bytes, ByteCount);
      Accumulated.Position:=0;
      if ByteCount > 0 then
        Accumulated.ReadBuffer(Bytes[0], ByteCount);
    finally
      Accumulated.Free;
    end;
    if NOT TJAXYValidUTF8(Bytes) then
      raise EYAMLException.Create('Configuration must be valid UTF-8 without NUL bytes', 1, 1);
    Offset:=0;
    if (ByteCount >= 3) AND (Bytes[0] = $EF) AND (Bytes[1] = $BB) AND (Bytes[2] = $BF) then
      Offset:=3;
    if ByteCount > Offset then
      FData.WriteBuffer(Bytes[Offset], ByteCount - Offset);
  end else
    FData.WriteString(TJAXYReadUTF8(AStream));
  FData.Position:=0;
  Parse;
end;

procedure TYAML.Parse;
var
  Parser: TYAMLParser;
  BlockParser: TYAMLBlockParser;
  I: Integer;
  NewDocuments: TList;
begin
  NewDocuments:=TList.Create;
  try
    case FEncoding of
      yeKYAML:
        begin
          Parser:=TYAMLParser.Create(FData.DataString);
          try
            NewDocuments.Add(Parser.Parse);
          finally
            Parser.Free;
          end;
        end;
      yeYAML:
        begin
          BlockParser:=TYAMLBlockParser.Create(FData.DataString, FConfigurationProfile,
            FConfigurationOptions.MaxDepth, FConfigurationOptions.MaxNodes);
          try
            BlockParser.ParseDocuments(NewDocuments);
            if FConfigurationProfile AND (NewDocuments.Count <> 1) then
              raise EYAMLException.Create('Configuration requires one document', 1, 1);
          finally
            BlockParser.Free;
          end;
        end;
    else
      raise Exception.Create(RCS_UNSUPPORTED_ENCODING);
    end;
    ReplaceDocuments(NewDocuments);
    NewDocuments:=nil;
  finally
    if NewDocuments <> nil then
    begin
      for I:=0 to NewDocuments.Count - 1 do
        TObject(NewDocuments[I]).Free;
      NewDocuments.Free;
    end;
  end;
end;

procedure TYAML.ReadFromString(const AValue: String);
var
  Bytes: TBytes;
  Offset: Integer;
begin
  TJAXYRequireValidText(AValue);
  if FConfigurationProfile then
  begin
    if Length(AValue) > FConfigurationOptions.MaxInputBytes then
      raise EYAMLException.Create(Format('Configuration exceeds %d bytes', [FConfigurationOptions.MaxInputBytes]), 1, 1);
    Bytes:=TEncoding.UTF8.GetBytes(AValue);
    if Length(Bytes) > FConfigurationOptions.MaxInputBytes then
      raise EYAMLException.Create(Format('Configuration exceeds %d bytes', [FConfigurationOptions.MaxInputBytes]), 1, 1);
    if NOT TJAXYValidUTF8(Bytes) then
      raise EYAMLException.Create('Configuration must be valid UTF-8 without NUL bytes', 1, 1);
  end;
  FData.Clear;
  if FConfigurationProfile then
  begin
    Offset:=0;
    if (Length(Bytes) >= 3) AND (Bytes[0] = $EF) AND (Bytes[1] = $BB) AND (Bytes[2] = $BF) then
      Offset:=3;
    if Length(Bytes) > Offset then
      FData.WriteBuffer(Bytes[Offset], Length(Bytes) - Offset);
  end
  else
    FData.WriteString(AValue);
  FData.Position:=0;
  Parse;
end;

function TYAML.RootNewArray: TYAMLArray;
begin
  FData.Clear;
  Result:=TYAMLArray.Create;
  SetRoot(Result);
end;

function TYAML.RootNewObject: TYAMLObject;
begin
  FData.Clear;
  Result:=TYAMLObject.Create;
  SetRoot(Result);
end;

procedure TYAML.SaveToFile(const AFileName: String);
begin
  WriteToFile(AFileName);
end;

procedure TYAML.SaveToStream(AStream: TStream);
var
  S: String;
begin
  S:=WriteToString;
  TJAXYWriteUTF8(AStream, S);
end;

function TYAML.WriteToFile(const AFileName: String; AWriteMode: TYAMLStringWriteMode): String;
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

function TYAML.WriteToFile(const AFileName: String; AWriteMode: TTJAXYStringWriteMode): String;
begin
  Result:=WriteToFile(AFileName, TJAXYWriteModeToYAML(AWriteMode));
end;

function TYAML.WriteToString(AWriteMode: TYAMLStringWriteMode): String;
var
  Writer: TYAMLWriter;
  I: Integer;
begin
  Writer:=TYAMLWriter.Create(AWriteMode);
  try
    if FDocuments.Count <= 1 then
      Result:=Writer.Write(FRoot, FWriteDocumentMarker)
    else
    begin
      Result:='';
      for I:=0 to FDocuments.Count - 1 do
      begin
        if I > 0 then
          Result:=Result + sLineBreak;
        Result:=Result + Writer.Write(TYAMLValue(FDocuments[I]), True);
      end;
    end;
  finally
    Writer.Free;
  end;
end;

function TYAML.WriteToString(AWriteMode: TTJAXYStringWriteMode): String;
begin
  Result:=WriteToString(TJAXYWriteModeToYAML(AWriteMode));
end;

{ TYAMLParser }

constructor TYAMLParseBudget.Create(AMaxNodes: Integer);
begin
  inherited Create;
  MaxNodes:=AMaxNodes;
end;

function YAMLConfigurationKeyError(AObject: TYAMLObject; const AKey: String): String;
begin
  if (AKey = '<<') AND NOT YAMLProfileAllows(True, yrfMergeKeys) then
    Exit('Configuration does not allow merge keys');
  if AObject.HasKey(AKey) then
    Exit(Format(RCS_DUPLICATE_KEY, [AKey]));
  Result:='';
end;

function TYAMLParseBudget.Charge: Boolean;
begin
  Result:=Nodes < MaxNodes;
  if Result then
    Inc(Nodes);
end;

constructor TYAMLParser.Create(AText: String; AStrictKYAML: Boolean; AConfigurationProfile: Boolean;
  AMaxDepth, AMaxNodes: Integer; ABudget: TYAMLParseBudget);
begin
  inherited Create;
  FText:=AText;
  FIndex:=1;
  FLine:=1;
  FColumn:=1;
  FStrictKYAML:=AStrictKYAML;
  FConfigurationProfile:=AConfigurationProfile;
  FMaxDepth:=AMaxDepth;
  FBudget:=ABudget;
  FOwnsBudget:=FBudget = nil;
  if FOwnsBudget then
    FBudget:=TYAMLParseBudget.Create(AMaxNodes);
end;

destructor TYAMLParser.Destroy;
begin
  if FOwnsBudget then
    FBudget.Free;
  inherited;
end;

procedure TYAMLParser.CountNode;
begin
  if FConfigurationProfile AND NOT FBudget.Charge then
    Error(Format('Configuration exceeds %d nodes', [FBudget.MaxNodes]));
end;

procedure TYAMLParser.Advance;
begin
  if Eof then
    Exit;

  if FText[FIndex] = YAML_CHARS[ycLineFeed] then
  begin
    Inc(FLine);
    FColumn:=1;
  end
  else
    Inc(FColumn);

  Inc(FIndex);
end;

procedure TYAMLParser.CheckForbidden;
begin
  if (NOT FStrictKYAML) AND (NOT FConfigurationProfile) then
    Exit;

  case CharToYAML(Current) of
    ycAmpersand:
      if FStrictKYAML OR NOT YAMLProfileAllows(FConfigurationProfile, yrfAnchors) then
        Error(Format(RCS_FORBIDDEN_YAML_FEATURE, [YAML_FEATURE_ANCHORS]));
    ycAsterisk:
      if FStrictKYAML OR NOT YAMLProfileAllows(FConfigurationProfile, yrfAliases) then
        Error(Format(RCS_FORBIDDEN_YAML_FEATURE, [YAML_FEATURE_ALIASES]));
    ycExclamation:
      if FStrictKYAML OR NOT YAMLProfileAllows(FConfigurationProfile, yrfTags) then
        Error(Format(RCS_FORBIDDEN_YAML_FEATURE, [YAML_FEATURE_TAGS]));
    ycPipe, ycGreaterThan: Error(Format(RCS_FORBIDDEN_YAML_FEATURE, [YAML_FEATURE_BLOCK_SCALARS]));
  end;
end;

function TYAMLParser.Current: Char;
begin
  if Eof then
    Result:=YAML_CHARS[ycNull]
  else
    Result:=FText[FIndex];
end;

function TYAMLParser.Eof: Boolean;
begin
  Result:=FIndex > Length(FText);
end;

procedure TYAMLParser.Error(AMessage: String);
begin
  raise EYAMLException.Create(AMessage, FLine, FColumn);
end;

procedure TYAMLParser.Expect(AChar: Char);
begin
  if Current <> AChar then
    Error(Format(RCS_EXPECTED_CHAR, [AChar]));
  Advance;
end;

function TYAMLParser.IsIdentifierChar(AChar: Char): Boolean;
begin
  Result:=CharInSet(AChar, ['A'..'Z', 'a'..'z', '0'..'9', '_', '-', '.']);
end;

function TYAMLParser.IsIdentifierStart(AChar: Char): Boolean;
begin
  Result:=CharInSet(AChar, ['A'..'Z', 'a'..'z', '_']);
end;

function TYAMLParser.Parse: TYAMLValue;
begin
  SkipWhite;
  ParseDocumentMarker;
  SkipWhite;
  Result:=ParseValue;
  SkipWhite;
  if NOT Eof then
  begin
    Result.Free;
    Error(RCS_TRAILING_DATA);
  end;
end;

function TYAMLParser.ParseArray: TYAMLArray;
var
  Value: TYAMLValue;
  Obj: TYAMLObject;
  Key: String;
begin
  Result:=TYAMLArray.Create;
  try
    Expect(YAML_CHARS[ycLeftBracket]);
    SkipWhite;
    if CharToYAML(Current) = ycRightBracket then
    begin
      Advance;
      Exit;
    end;

    while True do
    begin
      SkipWhite;
      if (CharToYAML(Current) = ycRightBracket) AND NOT FStrictKYAML then
        Break;
      Value:=ParseValue;
      SkipWhite;
      if (NOT FStrictKYAML) AND (CharToYAML(Current) = ycColon) then
      begin
        if NOT YAMLProfileAllows(FConfigurationProfile, yrfImplicitFlowMapping) then
        begin
          Value.Free;
          Error('Configuration does not allow implicit flow mapping entries');
        end;
        Key:=ValueToKey(Value);
        Value.Free;
        Advance;
        SkipWhite;
        Obj:=TYAMLObject.Create;
        try
          Obj.Add(Key, ParseValue);
          Result.Add(Obj);
          Obj:=nil;
        finally
          Obj.Free;
        end;
      end
      else
        Result.Add(Value);
      SkipWhite;
      if CharToYAML(Current) = ycComma then
      begin
        Advance;
        SkipWhite;
        Continue;
      end;
      Break;
    end;
    Expect(YAML_CHARS[ycRightBracket]);
  except
    Result.Free;
    raise;
  end;
end;

procedure TYAMLParser.ParseDocumentMarker;
begin
  if (CharToYAML(Current) = ycDash) AND (CharToYAML(Peek) = ycDash) AND (CharToYAML(Peek(2)) = ycDash) then
  begin
    Advance;
    Advance;
    Advance;
    if FStrictKYAML AND NOT IsYAMLChar(Current, [ycNull, ycTab, ycLineFeed, ycCarriageReturn,
      ycSpace, ycLeftBrace, ycLeftBracket]) then
      Error(RCS_TRAILING_DATA);
  end;
end;

function TYAMLParser.ParseKey: String;
begin
  Result:='';
  SkipWhite;
  CheckForbidden;
  if FStrictKYAML AND (CharToYAML(Current) = ycLessThan) AND (CharToYAML(Peek) = ycLessThan) then
    Error(Format(RCS_FORBIDDEN_YAML_FEATURE, [YAML_FEATURE_MERGE_KEYS]));

  if NOT FStrictKYAML then
    Result:=ReadFlowKey
  else
  begin
    case CharToYAML(Current) of
      ycDoubleQuote:
        Result:=ReadQuotedString;
      ycSingleQuote:
        if NOT FStrictKYAML then
          Result:=ReadSingleQuotedString
        else
          Error(RCS_EXPECTED_KEY);
    else
      if IsIdentifierStart(Current) then
        Result:=ReadIdentifier
      else
        Error(RCS_EXPECTED_KEY);
    end;
  end;
end;

function TYAMLParser.ParseObject: TYAMLObject;
var
  Key, KeyError: String;
  Value: TYAMLValue;
begin
  Result:=TYAMLObject.Create;
  try
    Expect(YAML_CHARS[ycLeftBrace]);
    SkipWhite;
    if CharToYAML(Current) = ycRightBrace then
    begin
      Advance;
      Exit;
    end;

    while True do
    begin
      Value:=nil;
      SkipWhite;
      if (CharToYAML(Current) = ycRightBrace) AND NOT FStrictKYAML then
        Break;
      if FConfigurationProfile AND (FDepth >= FMaxDepth) then
        Error(Format('Configuration exceeds %d nesting levels', [FMaxDepth]));
      CountNode;
      Key:=ParseKey;
      if FConfigurationProfile then
      begin
        KeyError:=YAMLConfigurationKeyError(Result, Key);
        if KeyError <> '' then
          Error(KeyError);
      end;
      SkipWhite;
      if CharToYAML(Current) = ycColon then
      begin
        Advance;
        SkipWhite;
        if (NOT FStrictKYAML) AND IsYAMLChar(Current, [ycComma, ycRightBrace]) then
        begin
          if FConfigurationProfile then
          begin
            CountNode;
          end;
          Value:=TYAMLNull.Create
        end
        else if FConfigurationProfile then
          Value:=ParseValue
        else if (NOT FStrictKYAML) AND (CharInSet(Current, ['0'..'9']) OR ((CharToYAML(Current) = ycDash) AND CharInSet(Peek, ['0'..'9']))) then
          Value:=ReadNumber
        else
          Value:=ParseValue;
      end
      else if FStrictKYAML then
        Expect(YAML_CHARS[ycColon])
      else
      begin
        if FConfigurationProfile then
        begin
          CountNode;
        end;
        Value:=TYAMLNull.Create;
      end;
      Result.Add(Key, Value);
      SkipWhite;
      if CharToYAML(Current) = ycComma then
      begin
        Advance;
        SkipWhite;
        Continue;
      end;
      Break;
    end;
    Expect(YAML_CHARS[ycRightBrace]);
  except
    Result.Free;
    raise;
  end;
end;

function TYAMLParser.ParseValue: TYAMLValue;
var
  Ident: String;
begin
  Result:=nil;
  SkipWhite;
  CheckForbidden;
  if FConfigurationProfile then
  begin
    Inc(FDepth);
    CountNode;
    if FDepth > FMaxDepth then
      Error(Format('Configuration exceeds %d nesting levels', [FMaxDepth]));
  end;

  case CharToYAML(Current) of
    ycLeftBrace:
      Result:=ParseObject;
    ycLeftBracket:
      Result:=ParseArray;
    ycDoubleQuote:
      Result:=TYAMLString.CreateFrom(ReadQuotedString);
    ycSingleQuote:
      begin
        if FStrictKYAML then
          Error(RCS_EXPECTED_VALUE);
        Result:=TYAMLString.CreateFrom(ReadSingleQuotedString);
      end;
    ycHash, ycComma:
      Error(RCS_EXPECTED_VALUE);
    ycDash:
      if FStrictKYAML then
        Result:=ReadNumber
      else
        Result:=ReadPlainScalar;
  else
    if CharInSet(Current, ['0'..'9']) then
    begin
      if FStrictKYAML then
        Result:=ReadNumber
      else
        Result:=ReadPlainScalar;
    end
    else if IsIdentifierStart(Current) then
    begin
      if FStrictKYAML then
      begin
        Ident:=ReadIdentifier;
        if Ident = YAML_LITERAL_TRUE then
          Result:=TYAMLBoolean.CreateFrom(True)
        else if Ident = YAML_LITERAL_FALSE then
          Result:=TYAMLBoolean.CreateFrom(False)
        else if Ident = YAML_LITERAL_NULL then
          Result:=TYAMLNull.Create
        else
          Error(RCS_UNQUOTED_STRING_VALUE);
      end
      else
        Result:=ReadPlainScalar;
    end
    else if Eof then
      Error(RCS_EXPECTED_VALUE)
    else if NOT FStrictKYAML then
      Result:=ReadPlainScalar
    else
      Error(RCS_EXPECTED_VALUE);
  end;
  if FConfigurationProfile then
    Dec(FDepth);
end;

function TYAMLParser.Peek(AOffset: Integer): Char;
begin
  if FIndex + AOffset > Length(FText) then
    Result:=YAML_CHARS[ycNull]
  else
    Result:=FText[FIndex + AOffset];
end;

function TYAMLParser.ReadFlowKey: String;
var
  S: String;
  Quote: Char;
  BracketDepth: Integer;
  Value: TYAMLValue;
begin
  SkipWhite;
  if NOT YAMLProfileAllows(FConfigurationProfile, yrfComplexKeys) AND
    CharInSet(Current, ['?', '[', '{', '&', '*', '!']) then
    Error('Configuration mapping keys must be strings');
  if Current = YAML_CHARS[ycQuestion] then
  begin
    Advance;
    if IsYAMLChar(Current, [ycSpace, ycTab, ycLineFeed, ycCarriageReturn]) then
      SkipWhite
    else
      S:='?';
  end
  else
    S:='';

  if Current = YAML_CHARS[ycDoubleQuote] then
    Exit(ReadQuotedString);
  if Current = YAML_CHARS[ycSingleQuote] then
    Exit(ReadSingleQuotedString);

  if IsYAMLChar(Current, [ycLeftBracket, ycLeftBrace]) then
  begin
    Value:=ParseValue;
    try
      Exit(Value.AsString);
    finally
      Value.Free;
    end;
  end;

  Quote:=#0;
  BracketDepth:=0;
  while NOT Eof do
  begin
    if Quote <> #0 then
    begin
      if Current = Quote then
        Quote:=#0;
      S:=S + Current;
      Advance;
      Continue;
    end;

    if IsYAMLChar(Current, [ycDoubleQuote, ycSingleQuote]) then
    begin
      Quote:=Current;
      S:=S + Current;
      Advance;
      Continue;
    end;

    if IsYAMLChar(Current, [ycLeftBrace, ycLeftBracket]) then
      Inc(BracketDepth)
    else if IsYAMLChar(Current, [ycRightBrace, ycRightBracket]) then
    begin
      if BracketDepth = 0 then
        Break;
      Dec(BracketDepth);
    end
    else if (BracketDepth = 0) AND (Current = YAML_CHARS[ycColon]) AND ((Peek = YAML_CHARS[ycNull]) OR IsYAMLChar(Peek, [ycSpace, ycTab, ycLineFeed, ycCarriageReturn, ycComma, ycRightBrace])) then
      Break
    else if (BracketDepth = 0) AND IsYAMLChar(Current, [ycComma, ycRightBrace]) then
      Break;

    S:=S + Current;
    Advance;
  end;

  Result:=Trim(S);
  if FConfigurationProfile then
  begin
    if Result = '' then
      Error('Configuration mapping keys must be strings');
    Value:=ResolveScalar(Result);
    try
      if NOT Value.IsString then
        Error('Configuration mapping keys must be strings');
    finally
      Value.Free;
    end;
  end;
end;

function TYAMLParser.ReadIdentifier: String;
begin
  Result:='';
  if NOT IsIdentifierStart(Current) then
    Error(RCS_EXPECTED_KEY);

  while IsIdentifierChar(Current) do
  begin
    Result:=Result + Current;
    Advance;
  end;
end;

function TYAMLParser.ReadPlainScalar: TYAMLValue;
var
  S: String;
  BracketDepth: Integer;
begin
  S:='';
  BracketDepth:=0;

  while NOT Eof do
  begin
    if IsYAMLChar(Current, [ycLeftBrace, ycLeftBracket]) then
      Inc(BracketDepth)
    else if IsYAMLChar(Current, [ycRightBrace, ycRightBracket]) then
    begin
      if BracketDepth = 0 then
        Break;
      Dec(BracketDepth);
    end
    else if (BracketDepth = 0) AND IsYAMLChar(Current, [ycComma, ycRightBrace, ycRightBracket]) then
      Break;
    if (NOT FStrictKYAML) AND (BracketDepth = 0) AND (Current = YAML_CHARS[ycColon]) AND ((Peek = YAML_CHARS[ycNull]) OR IsYAMLChar(Peek, [ycSpace, ycTab, ycComma, ycRightBrace, ycRightBracket])) then
      Break;

    S:=S + Current;
    Advance;
  end;

  S:=Trim(S);
  if S = '-' then
    Error(RCS_EXPECTED_VALUE);
  Result:=ResolveScalar(S);
end;

function TYAMLParser.ValueToKey(AValue: TYAMLValue): String;
begin
  if AValue = nil then
    Result:=''
  else
    Result:=AValue.AsString;
end;

function TYAMLParser.ReadNumber: TYAMLValue;
var
  S: String;
  I: Int64;
  F: Extended;
  IsFloat: Boolean;
  FormatSettings: TFormatSettings;
begin
  S:='';
  IsFloat:=False;

  if Current = YAML_CHARS[ycDash] then
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

  if Current = YAML_CHARS[ycDot] then
  begin
    IsFloat:=True;
    S:=S + Current;
    Advance;
    if NOT CharInSet(Current, ['0'..'9']) then
      Error(RCS_INVALID_NUMBER);
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
    if IsYAMLChar(Current, [ycPlus, ycDash]) then
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

  if IsIdentifierChar(Current) then
    Error(RCS_INVALID_NUMBER);

  FormatSettings:=YAMLFormatSettings;
  if IsFloat then
  begin
    if NOT TryStrToFloat(S, F, FormatSettings) then
      Error(RCS_INVALID_NUMBER);
    Result:=TYAMLFloat.CreateFrom(F);
  end
  else
  begin
    if NOT TryStrToInt64(S, I) then
      Error(RCS_INVALID_NUMBER);
    Result:=TYAMLInteger.CreateFrom(I);
  end;
end;

function TYAMLParser.ReadSingleQuotedString: String;
begin
  Result:='';
  Expect(YAML_CHARS[ycSingleQuote]);
  while NOT Eof do
  begin
    if Current = YAML_CHARS[ycSingleQuote] then
    begin
      Advance;
      if Current = YAML_CHARS[ycSingleQuote] then
      begin
        Result:=Result + YAML_CHARS[ycSingleQuote];
        Advance;
        Continue;
      end;
      Exit;
    end;

    if Current = YAML_CHARS[ycLineFeed] then
    begin
      Result:=Result + YAML_CHARS[ycSpace];
      Advance;
      while IsYAMLChar(Current, [ycSpace, ycTab]) do
        Advance;
    end
    else if Current = YAML_CHARS[ycCarriageReturn] then
      Advance
    else
    begin
      Result:=Result + Current;
      Advance;
    end;
  end;
  Error(RCS_UNTERMINATED_STRING);
end;

function TYAMLParser.ReadQuotedString: String;
var
  Hex: String;
  Code: Integer;
begin
  Result:='';
  Expect(YAML_CHARS[ycDoubleQuote]);
  while NOT Eof do
  begin
    case Current of
      '"':
        begin
          Advance;
          Exit;
        end;
      '\':
        begin
          Advance;
          case Current of
            '"': Result:=Result + YAML_CHARS[ycDoubleQuote];
            '\': Result:=Result + YAML_CHARS[ycBackslash];
            '/': Result:=Result + YAML_CHARS[ycSlash];
            'b': Result:=Result + #8;
            'f': Result:=Result + #12;
            'n': Result:=Result + #10;
            'r': Result:=Result + #13;
            't': Result:=Result + #9;
            #9:
              if FStrictKYAML then
                Error(RCS_INVALID_STRING_ESCAPE)
              else
                Result:=Result + YAML_CHARS[ycTab];
            #10:
              begin
                if FStrictKYAML then
                  Error(RCS_INVALID_STRING_ESCAPE);
                Advance;
                while IsYAMLChar(Current, [ycSpace, ycTab]) do
                  Advance;
                Continue;
              end;
            #13:
              begin
                if FStrictKYAML then
                  Error(RCS_INVALID_STRING_ESCAPE);
                Advance;
                if Current = YAML_CHARS[ycLineFeed] then
                  Advance;
                while IsYAMLChar(Current, [ycSpace, ycTab]) do
                  Advance;
                Continue;
              end;
            '0':
              if FStrictKYAML then
                Error(RCS_INVALID_STRING_ESCAPE)
              else
                Result:=Result + #0;
            'a':
              if FStrictKYAML then
                Error(RCS_INVALID_STRING_ESCAPE)
              else
                Result:=Result + #7;
            'v':
              if FStrictKYAML then
                Error(RCS_INVALID_STRING_ESCAPE)
              else
                Result:=Result + #11;
            'e':
              if FStrictKYAML then
                Error(RCS_INVALID_STRING_ESCAPE)
              else
                Result:=Result + Char(27);
            '_':
              if FStrictKYAML then
                Error(RCS_INVALID_STRING_ESCAPE)
              else
                Result:=Result + YAML_CHARS[ycSpace];
            ' ':
              if FStrictKYAML then
                Error(RCS_INVALID_STRING_ESCAPE)
              else
                Result:=Result + YAML_CHARS[ycSpace];
            'x':
              begin
                if FStrictKYAML then
                  Error(RCS_INVALID_STRING_ESCAPE);
                Advance;
                Hex:=Copy(FText, FIndex, 2);
                if (Length(Hex) < 2) OR NOT TryStrToInt('$' + Hex, Code) then
                  Error(RCS_INVALID_HEX_ESCAPE);
                Result:=Result + WideChar(Code);
                Advance;
                Advance;
                Continue;
              end;
            'u':
              begin
                Advance;
                Hex:=Copy(FText, FIndex, 4);
                if (Length(Hex) < 4) OR NOT TryStrToInt('$' + Hex, Code) then
                  Error(RCS_INVALID_UNICODE_ESCAPE);
                Result:=Result + WideChar(Code);
                Advance;
                Advance;
                Advance;
                Advance;
                Continue;
              end;
          else
            Error(RCS_INVALID_STRING_ESCAPE);
          end;
          Advance;
        end;
      #10:
        begin
          Result:=Result + YAML_CHARS[ycSpace];
          Advance;
          while IsYAMLChar(Current, [ycSpace, ycTab]) do
            Advance;
        end;
      #13:
        Advance;
      #0..#8, #9, #11..#12, #14..#31:
        if FStrictKYAML then
          Error(RCS_INVALID_CONTROL_CHAR_IN_STRING)
        else
        begin
          Result:=Result + Current;
          Advance;
        end;
    else
      Result:=Result + Current;
      Advance;
    end;
  end;
  Error(RCS_UNTERMINATED_STRING);
end;

function TYAMLParser.ResolveScalar(AValue: String): TYAMLValue;
var
  I: Int64;
  F: Extended;
  FormatSettings: TFormatSettings;
begin
  if AValue = '' then
    Exit(TYAMLNull.Create);

  if FConfigurationProfile AND (SameText(AValue, YAML_LITERAL_TRUE) OR SameText(AValue, YAML_LITERAL_FALSE)) AND
    (AValue <> YAML_LITERAL_TRUE) AND (AValue <> YAML_LITERAL_FALSE) then
    Error('Configuration booleans must use lowercase true or false');

  if SameText(AValue, YAML_LITERAL_NULL) OR (AValue = YAML_LITERAL_NULL_SHORT) then
    Exit(TYAMLNull.Create);
  if SameText(AValue, YAML_LITERAL_TRUE) then
    Exit(TYAMLBoolean.CreateFrom(True));
  if SameText(AValue, YAML_LITERAL_FALSE) then
    Exit(TYAMLBoolean.CreateFrom(False));

  if TryStrToInt64(AValue, I) then
  begin
    if FConfigurationProfile AND NOT YAMLDecimalInteger(AValue) then
      Error('Configuration integers must use decimal notation');
    Exit(TYAMLInteger.CreateFrom(I));
  end;

  FormatSettings:=YAMLFormatSettings;
  if (Pos('.', AValue) > 0) OR (Pos('e', LowerCase(AValue)) > 0) then
    if TryStrToFloat(AValue, F, FormatSettings) then
      Exit(TYAMLFloat.CreateFrom(F));

  Result:=TYAMLString.CreateFrom(AValue);
end;

procedure TYAMLParser.SkipWhite;
begin
  while IsYAMLChar(Current, [ycTab, ycLineFeed, ycCarriageReturn, ycSpace]) do
    Advance;
end;

{ TYAMLBlockParser }

procedure TYAMLBlockParser.CountNode(ALine, AColumn: Integer);
begin
  if NOT FConfigurationProfile then
    Exit;
  if NOT FBudget.Charge then
    Error(Format('Configuration exceeds %d nodes', [FBudget.MaxNodes]), ALine, AColumn);
end;

function TYAMLBlockParser.AliasValue(const AName: String; ALineNo, AColumn: Integer): TYAMLValue;
var
  I: Integer;
begin
  I:=FAnchors.IndexOf(AName);
  if I < 0 then
    Error(Format(RCS_UNKNOWN_ALIAS, [AName]), ALineNo, AColumn);

  Result:=TYAMLValue(FAnchors.Objects[I]).Copy;
end;

procedure TYAMLBlockParser.ApplyMerge(AObject: TYAMLObject; AValue: TYAMLValue);
var
  I: Integer;
  Obj: TYAMLObject;
begin
  if AValue IS TYAMLObject then
  begin
    Obj:=AValue.AsObject;
    for I:=0 to Obj.Count - 1 do
      if NOT AObject.HasKey(Obj.Name[I]) then
        AObject.Add(Obj.Name[I], Obj.Item[I].Copy);
  end
  else if AValue IS TYAMLArray then
  begin
    for I:=0 to AValue.AsArray.Count - 1 do
      ApplyMerge(AObject, AValue.AsArray[I]);
  end
  else
    raise Exception.Create(RCS_INVALID_MERGE_VALUE);
end;

constructor TYAMLBlockParser.Create(AText: String; AConfigurationProfile: Boolean; AMaxDepth, AMaxNodes, AFirstLine: Integer);
begin
  inherited Create;
  FLines:=TStringList.Create;
  FAnchors:=TStringList.Create;
  FAnchors.CaseSensitive:=True;
  FAnchors.Sorted:=False;
  FAnchors.OwnsObjects:=True;
  FIndex:=0;
  FConfigurationProfile:=AConfigurationProfile;
  FMaxDepth:=AMaxDepth;
  FBudget:=TYAMLParseBudget.Create(AMaxNodes);
  FLineOffset:=AFirstLine - 1;
  Load(AText);
end;

destructor TYAMLBlockParser.Destroy;
begin
  FBudget.Free;
  FreeAndNil(FAnchors);
  FreeAndNil(FLines);
  inherited;
end;

function TYAMLBlockParser.CountIndent(const ALine: String): Integer;
var
  I: Integer;
begin
  Result:=0;
  I:=1;
  while I <= Length(ALine) do
  begin
    if ALine[I] = YAML_CHARS[ycSpace] then
    begin
      Inc(Result)
    end
    else if ALine[I] = #9 then
    begin
      if Result > 0 then
        Break;
      if Result = 0 then
      begin
        while (I <= Length(ALine)) AND (ALine[I] = #9) do
          Inc(I);
        if (I <= Length(ALine)) AND CharInSet(ALine[I], ['[', '{', ']', '}']) then
          Exit(0);
      end;
      Error(RCS_TABS_NOT_ALLOWED, CurrentLineNo, I);
    end
    else
      Break;
    Inc(I);
  end;
end;

function TYAMLBlockParser.CurrentIndent: Integer;
begin
  if Eof then
    Result:=0
  else
    Result:=CountIndent(FLines[FIndex]);
end;

function TYAMLBlockParser.CurrentLine: String;
begin
  if Eof then
    Result:=''
  else
    Result:=FLines[FIndex];
end;

function TYAMLBlockParser.CurrentLineNo: Integer;
begin
  if Eof then
    Result:=FLines.Count + 1
  else
    Result:=Integer(NativeInt(FLines.Objects[FIndex]));
end;

function TYAMLBlockParser.Eof: Boolean;
begin
  Result:=FIndex >= FLines.Count;
end;

procedure TYAMLBlockParser.Error(const AMessage: String; ALine, AColumn: Integer);
begin
  raise EYAMLException.Create(AMessage, ALine + FLineOffset, AColumn);
end;

function TYAMLBlockParser.ExtractNodeProperties(var AValue: String; out AAnchor, AAlias: String): Boolean;
var
  Token: String;
  P: Integer;
  HadProperty: Boolean;
begin
  Result:=False;
  AAnchor:='';
  AAlias:='';
  AValue:=Trim(AValue);
  HadProperty:=False;

  while AValue <> '' do
  begin
    if CharInSet(AValue[1], ['&', '*', '!']) then
    begin
      if NOT YAMLProfileAllows(FConfigurationProfile, yrfAnchors) then
        Error('Configuration does not allow anchors, aliases, or tags', CurrentLineNo, 1);
      P:=Pos(YAML_CHARS[ycSpace], AValue);
      if P = 0 then
      begin
        Token:=AValue;
        AValue:='';
      end
      else
      begin
        Token:=Copy(AValue, 1, P - 1);
        AValue:=Trim(Copy(AValue, P + 1, MaxInt));
      end;

      if Token = '' then
        Break;

      case Token[1] of
        '&':
          begin
            AAnchor:=Copy(Token, 2, MaxInt);
            HadProperty:=True;
            Result:=True;
          end;
        '*':
          begin
            if HadProperty then
              Error(RCS_ALIAS_WITH_PROPERTIES, CurrentLineNo, 1);
            AAlias:=Copy(Token, 2, MaxInt);
            Result:=True;
            Break;
          end;
        '!':
          begin
            if (NOT ((Copy(Token, 1, 2) = '!<') AND (Copy(Token, Length(Token), 1) = '>'))) AND ((Pos(',', Token) > 0) OR (Pos('{', Token) > 0) OR (Pos('}', Token) > 0)) then
              Error(RCS_INVALID_TAG, CurrentLineNo, 1);
            HadProperty:=True;
            Result:=True; // Tags are accepted AND ignored by the current DOM model.
          end;
      end;
    end
    else
      Break;
  end;
end;

function TYAMLBlockParser.FindValueColon(const ALine: String): Integer;
var
  I, Depth: Integer;
  Quote: Char;

  function IsLeadingPropertyColon(AIndex: Integer): Boolean;
  var
    J: Integer;
  begin
    Result:=False;
    if (AIndex <= 1) OR NOT CharInSet(ALine[1], ['&', '!']) then
      Exit;

    for J:=1 to AIndex - 1 do
      if IsYAMLChar(ALine[J], [ycSpace, ycTab]) then
        Exit;

    Result:=True;
  end;

begin
  Result:=0;
  Depth:=0;
  Quote:=#0;

  I:=1;
  while I <= Length(ALine) do
  begin
    if Quote <> #0 then
    begin
      if (Quote = '"') AND (ALine[I] = '\') AND (I < Length(ALine)) then
      begin
        Inc(I, 2);
        Continue;
      end;
      if ALine[I] = Quote then
      begin
        if (Quote = '''') AND (I < Length(ALine)) AND (ALine[I + 1] = '''') then
        begin
          Inc(I);
          Continue;
        end;
        Quote:=#0;
      end;
      Inc(I);
      Continue;
    end;

    if CharInSet(ALine[I], ['"', '''']) AND ((I = 1) OR CharInSet(ALine[I - 1], [' ', #9, '[', '{', ','])) then
      Quote:=ALine[I]
    else if CharInSet(ALine[I], ['{', '[']) then
      Inc(Depth)
    else if CharInSet(ALine[I], ['}', ']']) AND (Depth > 0) then
      Dec(Depth)
    else if (ALine[I] = ':') AND (Depth = 0) AND (NOT IsLeadingPropertyColon(I)) AND ((I = Length(ALine)) OR IsYAMLChar(ALine[I + 1], [ycSpace, ycTab])) then
      Exit(I);
    Inc(I);
  end;
end;

function TYAMLBlockParser.FlowBalance(const AValue: String): Integer;
var
  I: Integer;
  Quote: Char;
begin
  Result:=0;
  Quote:=#0;
  I:=1;
  while I <= Length(AValue) do
  begin
    if Quote <> #0 then
    begin
      if AValue[I] = Quote then
      begin
        if (Quote = '''') AND (I < Length(AValue)) AND (AValue[I + 1] = '''') then
        begin
          Inc(I, 2);
          Continue;
        end;
        Quote:=#0;
      end
      else if (Quote = '"') AND (AValue[I] = '\') AND (I < Length(AValue)) then
        Inc(I);
    end
    else if CharInSet(AValue[I], ['"', '''']) then
      Quote:=AValue[I]
    else if CharInSet(AValue[I], ['{', '[']) then
      Inc(Result)
    else if CharInSet(AValue[I], ['}', ']']) then
      Dec(Result);

    Inc(I);
  end;
end;

function TYAMLBlockParser.CollectFlowValue(AValue: String; AMinIndent: Integer): String;
var
  Line: String;
begin
  Result:=AValue;
  while (FlowBalance(Result) > 0) AND (FIndex < FLines.Count) do
  begin
    if (AMinIndent >= 0) AND (CurrentIndent <= AMinIndent) then
      Break;
    if (CurrentLine <> '') AND (CurrentLine[1] = #9) AND (Trim(CurrentLine) <> '') AND (NOT CharInSet(Trim(CurrentLine)[1], [']', '}'])) then
      Error(RCS_TABS_NOT_ALLOWED, CurrentLineNo, 1);
    if (Trim(CurrentLine) <> '') AND (Trim(CurrentLine)[1] = ':') AND (Trim(Result) <> '') AND (Trim(Result)[1] = '[') then
      Error(RCS_INVALID_YAML, CurrentLineNo, CurrentIndent + 1);
    Line:=Trim(RemoveComment(CurrentLine));
    Result:=Result + YAML_CHARS[ycSpace] + Line;
    Inc(FIndex);
  end;
end;

function TYAMLBlockParser.CollectPlainScalar(AValue: String; AIndent: Integer; AAllowContinuation: Boolean;
  ABreakOnSequence: Boolean): String;
var
  Line, RawLine: String;
  Indent, LookAhead: Integer;
  IsSequenceContinuation: Boolean;
begin
  Result:=AValue;
  if NOT AAllowContinuation then
    Exit;

  while NOT Eof do
  begin
    RawLine:=CurrentLine;
    Line:=Trim(RemoveComment(RawLine));
    if Line = '' then
    begin
      if Trim(RawLine) <> '' then
        Break;
      LookAhead:=FIndex + 1;
      while (LookAhead < FLines.Count) AND (Trim(RemoveComment(FLines[LookAhead])) = '') do
        Inc(LookAhead);
      if LookAhead >= FLines.Count then
        Break;
      Result:=Result + sLineBreak;
      Inc(FIndex);
      Continue;
    end;

    if (Line = YAML_DOCUMENT_START) OR (Line = YAML_DOCUMENT_END) OR (CharToYAML(Line[1]) = ycPercent) then
      Break;

    if (RawLine <> '') AND (RawLine[1] = #9) AND (AIndent = 0) then
      Indent:=0
    else
      Indent:=CurrentIndent;
    if Indent < AIndent then
      Break;
    IsSequenceContinuation:=NOT ((RawLine <> '') AND (RawLine[1] = #9) AND (AIndent = 0));
    if (ABreakOnSequence AND (Indent = AIndent) AND IsSequenceContinuation AND IsSequenceLine(AIndent)) OR (FindValueColon(Line) > 0) OR CharInSet(Line[1], ['?', ':', '{', '[', '}', ']']) then
      Break;

    Result:=Result + YAML_CHARS[ycSpace] + Line;
    Inc(FIndex);
    if TrimRightSpaces(RawLine) <> TrimRightSpaces(RemoveComment(RawLine)) then
      Break;
  end;
end;

function TYAMLBlockParser.QuoteBalance(const AValue: String): Char;
var
  I: Integer;
  Quote: Char;
begin
  Quote:=#0;
  I:=1;
  while I <= Length(AValue) do
  begin
    if Quote <> #0 then
    begin
      if AValue[I] = Quote then
      begin
        if (Quote = '''') AND (I < Length(AValue)) AND (AValue[I + 1] = '''') then
        begin
          Inc(I, 2);
          Continue;
        end;
        Quote:=#0;
      end
      else if (Quote = '"') AND (AValue[I] = '\') AND (I < Length(AValue)) then
        Inc(I);
    end
    else if CharInSet(AValue[I], ['"', '''']) AND ((I = 1) OR CharInSet(AValue[I - 1], [' ', #9, '[', '{', ',', ':'])) then
      Quote:=AValue[I];
    Inc(I);
  end;
  Result:=Quote;
end;

function TYAMLBlockParser.CollectQuotedValue(AValue: String): String;
var
  Line: String;
begin
  Result:=AValue;
  while (QuoteBalance(Result) <> #0) AND (FIndex < FLines.Count) do
  begin
    Line:=RemoveComment(CurrentLine);
    Result:=Result + sLineBreak + Line;
    Inc(FIndex);
  end;
end;

function TYAMLBlockParser.HasContent(const ALine: String): Boolean;
begin
  Result:=Trim(RemoveComment(ALine)) <> '';
end;

function TYAMLBlockParser.IsSequenceLine(AIndent: Integer): Boolean;
var
  S: String;
begin
  S:=CurrentLine;
  Result:=(CurrentIndent = AIndent) AND (Length(S) > AIndent) AND (CharToYAML(S[AIndent + 1]) = ycDash) AND ((Length(S) = AIndent + 1) OR IsYAMLChar(S[AIndent + 2], [ycSpace, ycTab]));
end;

procedure TYAMLBlockParser.Load(AText: String);
var
  Raw: TStringList;
  I: Integer;
  S: String;
begin
  Raw:=TStringList.Create;
  try
    AText:=StringReplace(AText, #13#10, #10, [rfReplaceAll]);
    AText:=StringReplace(AText, #13, #10, [rfReplaceAll]);
    Raw.Text:=AText;
    for I:=0 to Raw.Count - 1 do
    begin
      S:=Raw[I];
      FLines.AddObject(S, TObject(NativeInt(I + 1)));
    end;
  finally
    Raw.Free;
  end;
end;

procedure TYAMLBlockParser.StoreAnchor(const AName: String; AValue: TYAMLValue);
var
  I: Integer;
begin
  if AName = '' then
    Exit;

  I:=FAnchors.IndexOf(AName);
  if I >= 0 then
  begin
    FAnchors.Objects[I].Free;
    FAnchors.Objects[I]:=AValue.Copy;
  end
  else
    FAnchors.AddObject(AName, AValue.Copy);
end;

function TYAMLBlockParser.ValueToKey(AValue: TYAMLValue): String;
begin
  if AValue = nil then
    Exit('');

  if AValue IS TYAMLNull then
    Result:=''
  else
    Result:=AValue.AsString;
end;

function TYAMLBlockParser.Parse: TYAMLValue;
begin
  SkipIgnorable;
  if Eof then
    Exit(TYAMLNull.Create);

  Result:=ParseNode(CurrentIndent);
  SkipIgnorable;
  if NOT Eof then
  begin
    Result.Free;
    Error(RCS_TRAILING_DATA, CurrentLineNo, CurrentIndent + 1);
  end;
end;

procedure TYAMLBlockParser.ParseDocuments(ADocuments: TList);
var
  I: Integer;
  Segment: TStringList;
  Parser: TYAMLBlockParser;
  S, Marker, PendingHeader: String;
  HasSegmentContent, SawMarker, HadYamlDirective, HadTagDirective, AtColumnZero: Boolean;
  SegmentStartLine: Integer;

  function HasTagShorthand(const AValue: String): Boolean;
  var
    FirstBang, SecondBang: Integer;
  begin
    FirstBang:=Pos('!', AValue);
    if FirstBang = 0 then
      Exit(False);
    if (FirstBang < Length(AValue)) AND CharInSet(AValue[FirstBang + 1], ['!', '<']) then
      Exit(False);
    SecondBang:=Pos('!', Copy(AValue, FirstBang + 1, MaxInt));
    Result:=SecondBang > 0;
  end;

  procedure ValidateDirective(const ADirective: String; ALineNo: Integer);
  var
    Parts: TStringList;
    Work: String;
    DotPos, J: Integer;
  begin
    if Copy(ADirective, 1, 5) <> '%YAML' then
    begin
      if Copy(ADirective, 1, 4) = '%TAG' then
        HadTagDirective:=True;
      Exit;
    end;

    if HasSegmentContent OR SawMarker OR (PendingHeader <> '') then
      Error(RCS_UNEXPECTED_DIRECTIVE, ALineNo, 1);

    Parts:=TStringList.Create;
    try
      Work:=Trim(ADirective);
      while Pos(#9, Work) > 0 do
      Work:=StringReplace(Work, YAML_CHARS[ycTab], YAML_CHARS[ycSpace], [rfReplaceAll]);
      while Pos(StringOfChar(YAML_CHARS[ycSpace], 2), Work) > 0 do
        Work:=StringReplace(Work, StringOfChar(YAML_CHARS[ycSpace], 2),
          YAML_CHARS[ycSpace], [rfReplaceAll]);
      Parts.StrictDelimiter:=True;
      Parts.Delimiter:=YAML_CHARS[ycSpace];
      Parts.DelimitedText:=Work;
      if HadYamlDirective OR (Parts.Count <> 2) OR (Parts[1] = '') then
        Error(RCS_INVALID_DIRECTIVE, ALineNo, 1);
      DotPos:=Pos('.', Parts[1]);
      if (DotPos <= 1) OR (DotPos = Length(Parts[1])) then
        Error(RCS_INVALID_DIRECTIVE, ALineNo, 1);
      for J:=1 to Length(Parts[1]) do
        if (J <> DotPos) AND NOT CharInSet(Parts[1][J], ['0'..'9']) then
          Error(RCS_INVALID_DIRECTIVE, ALineNo, 1);
      HadYamlDirective:=True;
    finally
      Parts.Free;
    end;
  end;

  procedure AddSegment(AForce: Boolean);
  begin
    if (NOT AForce) AND (NOT SawMarker) AND (NOT HasSegmentContent) AND (PendingHeader = '') then
    begin
      Segment.Clear;
      Exit;
    end;

    if PendingHeader <> '' then
    begin
      Segment.Insert(0, PendingHeader);
      PendingHeader:='';
      HasSegmentContent:=True;
    end;

    if FConfigurationProfile AND (ADocuments.Count > 0) then
      Error('Configuration requires one document', CurrentLineNo, 1);

    Parser:=TYAMLBlockParser.Create(Segment.Text, FConfigurationProfile, FMaxDepth, FBudget.MaxNodes, SegmentStartLine);
    try
      ADocuments.Add(Parser.Parse);
    finally
      Parser.Free;
    end;

    Segment.Clear;
    HasSegmentContent:=False;
    SawMarker:=False;
    HadYamlDirective:=False;
    HadTagDirective:=False;
  end;

begin
  Segment:=TStringList.Create;
  try
    HasSegmentContent:=False;
    SawMarker:=False;
    HadYamlDirective:=False;
    HadTagDirective:=False;
    PendingHeader:='';
    SegmentStartLine:=1;

    for I:=0 to FLines.Count - 1 do
    begin
      S:=FLines[I];
      Marker:=Trim(RemoveComment(S));
      AtColumnZero:=(S <> '') AND (NOT CharInSet(S[1], [YAML_CHARS[ycSpace], YAML_CHARS[ycTab]]));

      if AtColumnZero AND ((Marker = YAML_DOCUMENT_START) OR ((Copy(Marker, 1, Length(YAML_DOCUMENT_START)) = YAML_DOCUMENT_START) AND ((Length(Marker) = Length(YAML_DOCUMENT_START)) OR IsYAMLChar(Marker[Length(YAML_DOCUMENT_START) + 1], [ycSpace, ycTab])))) then
      begin
        AddSegment(False);
        SawMarker:=True;
        if Length(Marker) > 3 then
        begin
          SegmentStartLine:=Integer(NativeInt(FLines.Objects[I]));
          S:=Copy(S, Pos(YAML_DOCUMENT_START, S) + Length(YAML_DOCUMENT_START), MaxInt);
          PendingHeader:=Trim(S);
          if (PendingHeader <> '') AND (PendingHeader[1] = '&') AND (FindValueColon(PendingHeader) > 0) then
            Error(RCS_INVALID_YAML, Integer(NativeInt(FLines.Objects[I])), Pos('&', S) + 3);
          if HasTagShorthand(PendingHeader) AND (NOT HadTagDirective) then
            Error(RCS_UNDEFINED_TAG_HANDLE, Integer(NativeInt(FLines.Objects[I])), 1);
          HasSegmentContent:=True;
        end;
        Continue;
      end;

      if AtColumnZero AND (Marker <> '') AND (CharToYAML(Marker[1]) = ycPercent) then
      begin
        if NOT YAMLProfileAllows(FConfigurationProfile, yrfDirectives) then
          Error('Configuration does not allow directives', Integer(NativeInt(FLines.Objects[I])), 1);
        if (NOT HasSegmentContent) AND (NOT SawMarker) AND (PendingHeader = '') then
        begin
          ValidateDirective(Marker, Integer(NativeInt(FLines.Objects[I])));
          Continue;
        end;
        if (Copy(Marker, 1, 5) = '%YAML') AND ((PendingHeader <> '') OR (Segment.Count <> 1) OR (FindValueColon(Trim(RemoveComment(Segment[0]))) > 0) OR (TrimRightSpaces(Segment[0]) <> TrimRightSpaces(RemoveComment(Segment[0])))) then
          Error(RCS_UNEXPECTED_DIRECTIVE, Integer(NativeInt(FLines.Objects[I])), 1);
        if (Copy(Marker, 1, 4) = '%TAG') AND HasSegmentContent then
          Error(RCS_UNEXPECTED_DIRECTIVE, Integer(NativeInt(FLines.Objects[I])), 1);
      end;

      if AtColumnZero AND (Marker = YAML_DOCUMENT_END) then
      begin
        if HadYamlDirective AND (NOT SawMarker) AND (NOT HasSegmentContent) AND (PendingHeader = '') then
          Error(RCS_DIRECTIVE_WITHOUT_DOCUMENT, Integer(NativeInt(FLines.Objects[I])), 1);
        AddSegment(SawMarker);
        SawMarker:=False;
        Continue;
      end;

      if AtColumnZero AND (Copy(Marker, 1, Length(YAML_DOCUMENT_END)) = YAML_DOCUMENT_END) AND ((Length(Marker) = Length(YAML_DOCUMENT_END)) OR IsYAMLChar(Marker[Length(YAML_DOCUMENT_END) + 1], [ycSpace, ycTab])) then
        Error(RCS_CONTENT_AFTER_DOCUMENT_END, Integer(NativeInt(FLines.Objects[I])), Length(YAML_DOCUMENT_END) + 1);

      if (NOT SawMarker) AND (NOT HasSegmentContent) AND (PendingHeader = '') AND (NOT HasContent(S)) then
        Continue;

      if PendingHeader <> '' then
      begin
        Segment.Add(PendingHeader);
        PendingHeader:='';
      end;
      if Segment.Count = 0 then
        SegmentStartLine:=Integer(NativeInt(FLines.Objects[I]));
      Segment.Add(S);
      if HasContent(S) then
        HasSegmentContent:=True;
    end;

    if HadYamlDirective AND (NOT SawMarker) AND (NOT HasSegmentContent) AND (PendingHeader = '') then
      Error(RCS_DIRECTIVE_WITHOUT_DOCUMENT, CurrentLineNo, 1);
    AddSegment(SawMarker);
  finally
    Segment.Free;
  end;
end;

function TYAMLBlockParser.ParseCompactSequenceItem(const AValue: String;
  ALineNo, AColumn: Integer): TYAMLValue;
var
  Nested: TYAMLArray;
begin
  if (Length(AValue) < 2) OR (CharToYAML(AValue[1]) <> ycDash) OR
    NOT IsYAMLChar(AValue[2], [ycSpace, ycTab]) then
    Exit(ParseInlineValue(AValue, ALineNo, AColumn));

  if FConfigurationProfile AND (FDepth >= FMaxDepth) then
    Error(Format('Configuration exceeds %d nesting levels', [FMaxDepth]), ALineNo, AColumn);
  CountNode(ALineNo, AColumn);
  Nested:=TYAMLArray.Create;
  try
    if FConfigurationProfile then
      Inc(FDepth);
    try
      Nested.Add(ParseCompactSequenceItem(Trim(Copy(AValue, 3, MaxInt)), ALineNo, AColumn + 2));
    finally
      if FConfigurationProfile then
        Dec(FDepth);
    end;
    Result:=Nested;
  except
    Nested.Free;
    raise;
  end;
end;

function TYAMLBlockParser.ParseArray(AIndent: Integer): TYAMLArray;
var
  Line, Rest, Key, KeyError, ValueText, NodeAnchor, ValueAnchor, AliasName: String;
  Colon, DashColumn, LineNo, PairColon: Integer;
  Obj, PairObj: TYAMLObject;
  Arr: TYAMLArray;
  Value, KeyValue, PairKeyValue: TYAMLValue;

  function ParseInlinePairOrValue(const AText: String; ALineNo, AColumn: Integer): TYAMLValue;
  begin
    PairColon:=FindValueColon(AText);
    if PairColon <= 0 then
      Exit(ParseInlineValue(AText, ALineNo, AColumn));

    PairObj:=TYAMLObject.Create;
    try
      PairKeyValue:=ParseInlineValue(Trim(Copy(AText, 1, PairColon - 1)), ALineNo, AColumn);
      try
        PairObj.Add(ValueToKey(PairKeyValue),
          ParseInlineValue(Trim(Copy(AText, PairColon + 1, MaxInt)), ALineNo, AColumn + PairColon));
      finally
        PairKeyValue.Free;
      end;
      Result:=PairObj;
      PairObj:=nil;
    finally
      PairObj.Free;
    end;
  end;
begin
  Result:=TYAMLArray.Create;
  try
    while NOT Eof do
    begin
      SkipIgnorable;
      if Eof OR (CurrentIndent < AIndent) OR NOT IsSequenceLine(AIndent) then
        Break;
      if CurrentIndent > AIndent then
        Error(RCS_INVALID_YAML, CurrentLineNo, CurrentIndent + 1);
      if FConfigurationProfile AND (FDepth >= FMaxDepth) then
        Error(Format('Configuration exceeds %d nesting levels', [FMaxDepth]), CurrentLineNo, CurrentIndent + 1);

      Line:=RemoveComment(CurrentLine);
      LineNo:=CurrentLineNo;
      DashColumn:=AIndent + 1;
      Rest:=Trim(Copy(Line, DashColumn + 1, MaxInt));
      ExtractNodeProperties(Rest, NodeAnchor, AliasName);

      if AliasName <> '' then
      begin
        Inc(FIndex);
        Value:=AliasValue(AliasName, LineNo, DashColumn + 1);
        StoreAnchor(NodeAnchor, Value);
        Result.Add(Value);
        Continue;
      end;

      if Rest = '' then
      begin
        Inc(FIndex);
        SkipIgnorable;
        if Eof OR (CurrentIndent <= AIndent) then
        begin
          CountNode(LineNo, DashColumn + 1);
          Value:=TYAMLNull.Create
        end
        else
          Value:=ParseNode(CurrentIndent);
        StoreAnchor(NodeAnchor, Value);
        Result.Add(Value);
        Continue;
      end;

      if Rest = ':' then
      begin
        if FConfigurationProfile then
          Error('Configuration mapping keys must be strings', LineNo, DashColumn + 1);
        CountNode(LineNo, DashColumn + 1);
        Obj:=TYAMLObject.Create;
        try
          CountNode(LineNo, DashColumn + 2);
          Obj.Add('', TYAMLNull.Create);
          Inc(FIndex);
          StoreAnchor(NodeAnchor, Obj);
          Result.Add(Obj);
        except
          Obj.Free;
          raise;
        end;
      end
      else if (Length(Rest) >= 2) AND (CharToYAML(Rest[1]) = ycQuestion) and IsYAMLChar(Rest[2], [ycSpace, ycTab]) then
      begin
        if NOT YAMLProfileAllows(FConfigurationProfile, yrfComplexKeys) then
          Error('Configuration does not allow complex keys', LineNo, DashColumn + 1);
        KeyValue:=ParseInlinePairOrValue(Trim(Copy(Rest, 3, MaxInt)), LineNo, DashColumn + 2);
        try
          Inc(FIndex);
          SkipIgnorable;
          Value:=TYAMLNull.Create;
          if (NOT Eof) AND (CurrentIndent = AIndent + 2) then
          begin
            Line:=Trim(RemoveComment(CurrentLine));
            if (Line <> '') AND (Line[1] = ':') then
            begin
              ValueText:=Trim(Copy(Line, 2, MaxInt));
              Value.Free;
              Inc(FIndex);
              if ValueText = '' then
              begin
                SkipIgnorable;
                if Eof OR (CurrentIndent <= AIndent) then
                  Value:=TYAMLNull.Create
                else
                  Value:=ParseNode(CurrentIndent);
              end
              else
                Value:=ParseInlinePairOrValue(ValueText, CurrentLineNo, AIndent + 3);
            end;
          end;

          Obj:=TYAMLObject.Create;
          try
            Obj.Add(ValueToKey(KeyValue), Value);
            Value:=nil;
            StoreAnchor(NodeAnchor, Obj);
            Result.Add(Obj);
            Obj:=nil;
          finally
            Value.Free;
            Obj.Free;
          end;
        finally
          KeyValue.Free;
        end;
      end
      else
      begin
      Colon:=FindValueColon(Rest);
      if (Colon > 0) AND NOT CharInSet(Rest[1], ['{', '[', '"', '''']) then
      begin
        Inc(FIndex);
        CountNode(LineNo, DashColumn + 1);
        Obj:=TYAMLObject.Create;
        try
          if FConfigurationProfile then
            Inc(FDepth);
          try
          if FConfigurationProfile AND (FDepth >= FMaxDepth) then
            Error(Format('Configuration exceeds %d nesting levels', [FMaxDepth]), LineNo, DashColumn + 1);
          CountNode(LineNo, DashColumn + 1);
          Key:=Trim(Copy(Rest, 1, Colon - 1));
          if Key <> '' then
            Key:=ParseKey(Key, LineNo);
          if FConfigurationProfile then
          begin
            KeyError:=YAMLConfigurationKeyError(Obj, Key);
            if KeyError <> '' then
              Error(KeyError, LineNo, DashColumn + 1);
          end;
          ValueText:=Trim(Copy(Rest, Colon + 1, MaxInt));
          ExtractNodeProperties(ValueText, ValueAnchor, AliasName);
          if AliasName <> '' then
            Value:=AliasValue(AliasName, LineNo, DashColumn + Colon + 1)
          else
            Value:=nil;
          if ValueText = '' then
          begin
            SkipIgnorable;
            if Value = nil then
            begin
              if Eof OR (CurrentIndent <= AIndent) then
              begin
                CountNode(LineNo, DashColumn + Colon + 1);
                Value:=TYAMLNull.Create
              end
              else
                Value:=ParseNode(CurrentIndent);
            end;
          end
          else if Value = nil then
          begin
            ValueText:=CollectFlowValue(ValueText);
            Value:=ParseInlineValue(ValueText, LineNo, DashColumn + Colon + 1);
          end;

          StoreAnchor(ValueAnchor, Value);
          if Key = '<<' then
          begin
            ApplyMerge(Obj, Value);
            Value.Free;
          end
          else
            Obj.Add(Key, Value);

          ParseObjectInto(Obj, AIndent + 2);
          StoreAnchor(NodeAnchor, Obj);
          Result.Add(Obj);
          finally
            if FConfigurationProfile then
              Dec(FDepth);
          end;
        except
          Obj.Free;
          raise;
        end;
      end
      else
      begin
        if (Length(Rest) >= 2) AND (CharToYAML(Rest[1]) = ycDash) and IsYAMLChar(Rest[2], [ycSpace, ycTab]) then
        begin
          CountNode(LineNo, DashColumn + 1);
          Arr:=TYAMLArray.Create;
          try
            if FConfigurationProfile then
              Inc(FDepth);
            try
            if FConfigurationProfile AND (FDepth >= FMaxDepth) then
              Error(Format('Configuration exceeds %d nesting levels', [FMaxDepth]), LineNo, DashColumn + 1);
            Arr.Add(ParseCompactSequenceItem(Trim(Copy(Rest, 3, MaxInt)), LineNo, DashColumn + 2));
            Inc(FIndex);
            while (NOT Eof) AND IsSequenceLine(AIndent + 2) do
            begin
              Line:=Trim(Copy(RemoveComment(CurrentLine), AIndent + 4, MaxInt));
              Arr.Add(ParseCompactSequenceItem(Line, CurrentLineNo, AIndent + 3));
              Inc(FIndex);
            end;
            Value:=Arr;
            StoreAnchor(NodeAnchor, Value);
            Result.Add(Value);
            finally
              if FConfigurationProfile then
                Dec(FDepth);
            end;
          except
            Arr.Free;
            raise;
          end;
        end
        else if IsBlockScalarHeader(Rest) then
        begin
          CountNode(LineNo, DashColumn + 1);
          Value:=ParseBlockScalar(Rest, AIndent, LineNo);
          StoreAnchor(NodeAnchor, Value);
          Result.Add(Value);
        end
        else
        begin
          Inc(FIndex);
          if (QuoteBalance(Rest) = #0) AND (FlowBalance(Rest) = 0) AND (NOT CharInSet(Rest[1], ['{', '[', '"', ''''])) then
            Rest:=CollectPlainScalar(Rest, AIndent + 1, True, False);
          Rest:=CollectFlowValue(Rest);
          Value:=ParseInlineValue(Rest, LineNo, DashColumn + 1);
          StoreAnchor(NodeAnchor, Value);
          Result.Add(Value);
        end;
      end;
      end;
    end;
  except
    Result.Free;
    raise;
  end;
end;

function TYAMLBlockParser.IsBlockScalarHeader(const AValue: String): Boolean;
begin
  Result:=(AValue <> '') AND CharInSet(AValue[1], ['|', '>']);
end;

function TYAMLBlockParser.ParseBlockScalar(const AHeader: String; AIndent, ALineNo: Integer): TYAMLString;
var
  Lines: TStringList;
  BaseIndent, ExplicitIndent, I, J, LeadingBlankIndent: Integer;
  Chomp, Style: Char;
  S, Part: String;

  function BlockIndentOf(const ALine: String): Integer;
  begin
    Result:=0;
    while (Result < Length(ALine)) AND (ALine[Result + 1] = YAML_CHARS[ycSpace]) do
      Inc(Result);
  end;

  function IsAllSpaces(const ALine: String): Boolean;
  var
    K: Integer;
  begin
    Result:=ALine <> '';
    for K:=1 to Length(ALine) do
      if ALine[K] <> YAML_CHARS[ycSpace] then
        Exit(False);
  end;

begin
  Style:=AHeader[1];
  Chomp:=#0;
  ExplicitIndent:=0;

  for I:=2 to Length(AHeader) do
  begin
    if CharInSet(AHeader[I], ['+', '-']) then
    begin
      if Chomp <> #0 then
        Error(RCS_INVALID_BLOCK_SCALAR_CHOMP, ALineNo, I);
      Chomp:=AHeader[I];
    end
    else if CharInSet(AHeader[I], ['1'..'9']) then
    begin
      if ExplicitIndent <> 0 then
        Error(RCS_INVALID_BLOCK_SCALAR_INDENT, ALineNo, I);
      ExplicitIndent:=Ord(AHeader[I]) - Ord('0');
    end
    else if AHeader[I] = '0' then
      Error(RCS_INVALID_BLOCK_SCALAR_INDENT, ALineNo, I)
    else
      Error(RCS_INVALID_BLOCK_SCALAR, ALineNo, I);
  end;

  Lines:=TStringList.Create;
  try
    Inc(FIndex);
    if (NOT Eof) AND (CurrentLine <> '') AND (CurrentLine[1] = #9) AND (Trim(CurrentLine) = '') then
      Error(RCS_TABS_NOT_ALLOWED, CurrentLineNo, 1);
    LeadingBlankIndent:=-1;
    J:=FIndex;
    while J < FLines.Count do
    begin
      S:=FLines[J];
      if IsAllSpaces(S) then
      begin
        if Length(S) > LeadingBlankIndent then
          LeadingBlankIndent:=Length(S);
        Inc(J);
        Continue;
      end;
      if (LeadingBlankIndent >= 0) AND (Trim(S) <> '') AND (BlockIndentOf(S) < LeadingBlankIndent) then
        Error(RCS_INVALID_YAML, Integer(NativeInt(FLines.Objects[J])), BlockIndentOf(S) + 1);
      Break;
    end;
    SkipIgnorable;
    if Eof then
      Exit(TYAMLString.CreateFrom(''));

    if ExplicitIndent > 0 then
    begin
      BaseIndent:=AIndent + ExplicitIndent;
      if (NOT Eof) AND (HasContent(CurrentLine)) AND (BlockIndentOf(CurrentLine) < BaseIndent) then
        BaseIndent:=ExplicitIndent;
    end
    else
      BaseIndent:=BlockIndentOf(CurrentLine);

    while NOT Eof do
    begin
      if HasContent(CurrentLine) AND (BlockIndentOf(CurrentLine) < BaseIndent) then
        Break;

      S:=CurrentLine;
      if Length(S) >= BaseIndent then
        S:=Copy(S, BaseIndent + 1, MaxInt)
      else
        S:='';
      Lines.Add(S);
      Inc(FIndex);
    end;

    S:='';
    for I:=0 to Lines.Count - 1 do
    begin
      Part:=Lines[I];
      if Style = '>' then
      begin
        if Part = '' then
          S:=S + sLineBreak
        else
        begin
          if (S <> '') AND (Copy(S, Length(S), 1) <> sLineBreak) then
            S:=S + YAML_CHARS[ycSpace];
          S:=S + Part;
        end;
      end
      else
        S:=S + Part + sLineBreak;
    end;

    if Chomp = '-' then
      while (S <> '') AND ((Copy(S, Length(S), 1) = #10) OR (Copy(S, Length(S), 1) = #13)) do
        Delete(S, Length(S), 1)
    else if Chomp = #0 then
    begin
      while (Length(S) > Length(sLineBreak)) AND (Copy(S, Length(S) - Length(sLineBreak) + 1, Length(sLineBreak)) = sLineBreak) AND (Copy(S, Length(S) - (2 * Length(sLineBreak)) + 1, Length(sLineBreak)) = sLineBreak) do
        Delete(S, Length(S) - Length(sLineBreak) + 1, Length(sLineBreak));
    end;

    Result:=TYAMLString.CreateFrom(S);
  finally
    Lines.Free;
  end;
end;

function TYAMLBlockParser.ParseInlineValue(const AValue: String; ALineNo, AColumn: Integer): TYAMLValue;
var
  Parser: TYAMLParser;
  V, Anchor, AliasName: String;
begin
  V:=Trim(AValue);
  ExtractNodeProperties(V, Anchor, AliasName);
  V:=CollectQuotedValue(V);
  if V = '' then
  begin
    if AliasName <> '' then
      Result:=AliasValue(AliasName, ALineNo, AColumn)
    else
    begin
      CountNode(ALineNo, AColumn);
      Result:=TYAMLNull.Create;
    end;
    StoreAnchor(Anchor, Result);
    Exit;
  end;
  if AliasName <> '' then
  begin
    Result:=AliasValue(AliasName, ALineNo, AColumn);
    StoreAnchor(Anchor, Result);
    Exit;
  end;
  if IsBlockScalarHeader(V) then
  begin
    CountNode(ALineNo, AColumn);
    Exit(ParseBlockScalar(V, CurrentIndent, ALineNo));
  end;
  if (Pos(',', V) > 0) AND (FlowBalance(V) = 0) AND (NOT CharInSet(V[1], ['[', '{', '"', ''''])) then
  begin
    CountNode(ALineNo, AColumn);
    Result:=TYAMLString.CreateFrom(V);
    StoreAnchor(Anchor, Result);
    Exit;
  end;

  Parser:=TYAMLParser.Create(V, False, FConfigurationProfile, FMaxDepth - FDepth,
    FBudget.MaxNodes, FBudget);
  try
    try
      Result:=Parser.Parse;
    except
      on ParseError: EYAMLException do
      begin
        raise EYAMLException.Create(ParseError.Reason,
          ALineNo + ParseError.Line - 1 + FLineOffset, AColumn + ParseError.Column - 1);
      end;
    end;
    StoreAnchor(Anchor, Result);
  finally
    Parser.Free;
  end;
end;

function TYAMLBlockParser.ParseKey(const AKey: String; ALineNo: Integer): String;
var
  Parser: TYAMLParser;
  Value: TYAMLValue;
begin
  if AKey = '' then
    Error(RCS_EXPECTED_KEY, ALineNo, 1);

  if NOT YAMLProfileAllows(FConfigurationProfile, yrfComplexKeys) AND
    CharInSet(AKey[1], ['*', '&', '!', '?', '[', '{']) then
    Error('Configuration mapping keys must be strings', ALineNo, 1);
  if AKey[1] = '*' then
  begin
    Value:=AliasValue(Copy(AKey, 2, MaxInt), ALineNo, 1);
    try
      Result:=Value.AsString;
    finally
      Value.Free;
    end;
  end
  else if FConfigurationProfile OR CharInSet(AKey[1], ['"', '''']) then
  begin
    Parser:=TYAMLParser.Create(AKey, False, FConfigurationProfile, 1, 1);
    try
      Value:=Parser.Parse;
      try
        if FConfigurationProfile AND NOT Value.IsString then
          Error('Configuration mapping keys must be strings', ALineNo, 1);
        Result:=Value.AsString;
      finally
        Value.Free;
      end;
    finally
      Parser.Free;
    end;
  end
  else
    Result:=AKey;
end;

function TYAMLBlockParser.ParseNode(AIndent: Integer): TYAMLValue;
var
  Line, RawLine, Anchor, AliasName: String;
  LineNo: Integer;
  AllowContinuation: Boolean;
begin
  if FConfigurationProfile then
  begin
    Inc(FDepth);
    if FDepth > FMaxDepth then
      Error(Format('Configuration exceeds %d nesting levels', [FMaxDepth]), CurrentLineNo, CurrentIndent + 1);
  end;
  try
  SkipIgnorable;
  if Eof then
  begin
    CountNode(CurrentLineNo, CurrentIndent + 1);
    Exit(TYAMLNull.Create);
  end;

  if CurrentIndent < AIndent then
  begin
    CountNode(CurrentLineNo, CurrentIndent + 1);
    Exit(TYAMLNull.Create);
  end;
  if CurrentIndent > AIndent then
    Error(RCS_INVALID_YAML, CurrentLineNo, CurrentIndent + 1);

  LineNo:=CurrentLineNo;
  RawLine:=CurrentLine;
  Line:=Trim(RemoveComment(RawLine));
  AllowContinuation:=TrimRightSpaces(RawLine) = TrimRightSpaces(RemoveComment(RawLine));
  ExtractNodeProperties(Line, Anchor, AliasName);
  if AliasName <> '' then
  begin
    Inc(FIndex);
    Result:=AliasValue(AliasName, CurrentLineNo, AIndent + 1);
    StoreAnchor(Anchor, Result);
    Exit;
  end;
  if Line = '' then
  begin
    Inc(FIndex);
    SkipIgnorable;
    Result:=ParseNode(CurrentIndent);
    StoreAnchor(Anchor, Result);
    Exit;
  end;

  if (AIndent = 0) AND (Anchor <> '') AND (Length(Line) >= 2) AND (Line[1] = '-') and IsYAMLChar(Line[2], [ycSpace, ycTab]) then
    Error(RCS_INVALID_YAML, LineNo, AIndent + 1);

  if IsBlockScalarHeader(Line) then
  begin
    CountNode(LineNo, AIndent + 1);
    Result:=ParseBlockScalar(Line, AIndent, CurrentLineNo);
  end
  else if (Line <> '') AND CharInSet(Line[1], ['?', ':']) then
  begin
    CountNode(LineNo, AIndent + 1);
    Result:=ParseObject(AIndent)
  end
  else if IsSequenceLine(AIndent) then
  begin
    CountNode(LineNo, AIndent + 1);
    Result:=ParseArray(AIndent)
  end
  else if FindValueColon(Line) > 0 then
  begin
    CountNode(LineNo, AIndent + 1);
    Result:=ParseObject(AIndent)
  end
  else
  begin
    Inc(FIndex);
    if QuoteBalance(Line) = #0 then
      Line:=CollectPlainScalar(Line, AIndent, AllowContinuation);
    Line:=CollectFlowValue(Line);
    if FConfigurationProfile then
      Dec(FDepth);
    try
      Result:=ParseInlineValue(Line, LineNo, AIndent + 1);
    finally
      if FConfigurationProfile then
        Inc(FDepth);
    end;
    if (NOT Eof) AND ((Trim(RemoveComment(CurrentLine)) = '}') OR (Trim(RemoveComment(CurrentLine)) = ']')) then
      Inc(FIndex);
  end;
  StoreAnchor(Anchor, Result);
  finally
    if FConfigurationProfile then
      Dec(FDepth);
  end;
end;

function TYAMLBlockParser.ParseObject(AIndent: Integer): TYAMLObject;
begin
  Result:=TYAMLObject.Create;
  try
    ParseObjectInto(Result, AIndent);
  except
    Result.Free;
    raise;
  end;
end;

procedure TYAMLBlockParser.ParseObjectInto(AObject: TYAMLObject; AIndent: Integer);
var
  Line, Key, KeyError, KeyText, KeyAnchor, KeyAlias, ValueText, Anchor, AliasName, ItemText: String;
  Colon, LineNo, InnerIndent, PairColon: Integer;
  Value, KeyValue, PairKeyValue: TYAMLValue;
  Arr, InnerArr: TYAMLArray;
  PairObj: TYAMLObject;

  function LeadingSpacesOf(const ALine: String): Integer;
  begin
    Result:=0;
    while (Result < Length(ALine)) AND (ALine[Result + 1] = YAML_CHARS[ycSpace]) do
      Inc(Result);
  end;

begin
  while NOT Eof do
  begin
    SkipIgnorable;
    if Eof OR (CurrentIndent < AIndent) OR IsSequenceLine(AIndent) then
      Break;
    if CurrentIndent > AIndent then
      Error(RCS_INVALID_YAML, CurrentLineNo, CurrentIndent + 1);
    if FConfigurationProfile AND (FDepth >= FMaxDepth) then
      Error(Format('Configuration exceeds %d nesting levels', [FMaxDepth]), CurrentLineNo, CurrentIndent + 1);

    LineNo:=CurrentLineNo;
    Line:=RemoveComment(CurrentLine);
    Line:=Copy(Line, AIndent + 1, MaxInt);
    if (Line <> '') AND (Line[1] = #9) then
      Error(RCS_INVALID_YAML, LineNo, AIndent + 1);

    if (Trim(Line) = '?') OR ((Trim(Line) <> '') AND (Trim(Line)[1] = '?') AND ((Length(Trim(Line)) = 1) OR IsYAMLChar(Trim(Line)[2], [ycSpace, ycTab]))) then
    begin
      if NOT YAMLProfileAllows(FConfigurationProfile, yrfComplexKeys) then
        Error('Configuration does not allow complex keys', LineNo, AIndent + 1);
      if (Length(Trim(Line)) > 1) AND (Trim(Line)[2] = #9) then
        Error(RCS_INVALID_YAML, LineNo, AIndent + 2);
      ValueText:=Trim(Copy(Trim(Line), 2, MaxInt));
      if ValueText = '' then
      begin
        Inc(FIndex);
        SkipIgnorable;
        if Eof OR ((CurrentIndent <= AIndent) AND NOT IsSequenceLine(AIndent)) then
          KeyValue:=TYAMLNull.Create
        else
          KeyValue:=ParseNode(CurrentIndent);
      end
      else if IsBlockScalarHeader(ValueText) then
        KeyValue:=ParseBlockScalar(ValueText, AIndent, LineNo)
      else if (Length(ValueText) >= 2) AND (CharToYAML(ValueText[1]) = ycDash) and IsYAMLChar(ValueText[2], [ycSpace, ycTab]) then
      begin
        Arr:=TYAMLArray.Create;
        try
          Arr.Add(ParseInlineValue(Trim(Copy(ValueText, 3, MaxInt)), LineNo, AIndent + 3));
          Inc(FIndex);
          while (NOT Eof) AND IsSequenceLine(AIndent + 2) do
          begin
            Line:=Trim(Copy(RemoveComment(CurrentLine), AIndent + 4, MaxInt));
            Inc(FIndex);
            Arr.Add(ParseInlineValue(Line, CurrentLineNo, AIndent + 3));
          end;
          KeyValue:=Arr;
          Arr:=nil;
        finally
          Arr.Free;
        end;
      end
      else
      begin
        Inc(FIndex);
        if FlowBalance(ValueText) > 0 then
          ValueText:=CollectFlowValue(ValueText, AIndent)
        else if (QuoteBalance(ValueText) = #0) AND (FindValueColon(ValueText) <= 0) then
          ValueText:=CollectPlainScalar(ValueText, AIndent + 1, True);
        PairColon:=FindValueColon(ValueText);
        if PairColon > 0 then
        begin
          PairObj:=TYAMLObject.Create;
          try
            PairKeyValue:=ParseInlineValue(Trim(Copy(ValueText, 1, PairColon - 1)), LineNo, AIndent + 1);
            try
              PairObj.Add(ValueToKey(PairKeyValue),
                ParseInlineValue(Trim(Copy(ValueText, PairColon + 1, MaxInt)), LineNo,
                AIndent + PairColon + 1));
            finally
              PairKeyValue.Free;
            end;
            KeyValue:=PairObj;
            PairObj:=nil;
          finally
            PairObj.Free;
          end;
        end
        else
          KeyValue:=ParseInlineValue(ValueText, LineNo, AIndent + 1);
      end;
      try
        Key:=ValueToKey(KeyValue);
      finally
        KeyValue.Free;
      end;

      SkipIgnorable;
      Value:=nil;
      if (NOT Eof) AND (CurrentIndent = AIndent) then
      begin
        Line:=Trim(RemoveComment(CurrentLine));
        if (Line <> '') AND (Line[1] = ':') then
        begin
          if (Length(Line) > 1) AND (Line[2] = #9) then
            Error(RCS_INVALID_YAML, CurrentLineNo, AIndent + 2);
          ValueText:=Trim(Copy(Line, 2, MaxInt));
          Inc(FIndex);
          if ValueText = '' then
          begin
            SkipIgnorable;
            if Eof OR ((CurrentIndent <= AIndent) AND NOT IsSequenceLine(AIndent)) then
            begin
              CountNode(LineNo, AIndent + 2);
              Value:=TYAMLNull.Create
            end
            else
              Value:=ParseNode(CurrentIndent);
          end
          else if (Length(ValueText) >= 2) AND (CharToYAML(ValueText[1]) = ycDash) and IsYAMLChar(ValueText[2], [ycSpace, ycTab]) then
          begin
            if FConfigurationProfile AND (FDepth >= FMaxDepth) then
              Error(Format('Configuration exceeds %d nesting levels', [FMaxDepth]), LineNo, AIndent + 2);
            CountNode(LineNo, AIndent + 2);
            Arr:=TYAMLArray.Create;
            try
              if FConfigurationProfile then
                Inc(FDepth);
              try
              Arr.Add(ParseCompactSequenceItem(Trim(Copy(ValueText, 3, MaxInt)), LineNo, AIndent + 3));
              while (NOT Eof) AND IsSequenceLine(AIndent + 2) do
              begin
                ItemText:=Copy(RemoveComment(CurrentLine), AIndent + 4, MaxInt);
                Line:=Trim(ItemText);
                if (Length(Line) >= 2) AND (CharToYAML(Line[1]) = ycDash) and IsYAMLChar(Line[2], [ycSpace, ycTab]) then
                begin
                  InnerIndent:=AIndent + 3;
                  while (InnerIndent - AIndent - 2 <= Length(ItemText)) AND (ItemText[InnerIndent - AIndent - 2] = YAML_CHARS[ycSpace]) do
                    Inc(InnerIndent);
                  if FConfigurationProfile AND (FDepth >= FMaxDepth) then
                    Error(Format('Configuration exceeds %d nesting levels', [FMaxDepth]), CurrentLineNo, InnerIndent + 1);
                  CountNode(CurrentLineNo, InnerIndent + 1);
                  InnerArr:=TYAMLArray.Create;
                  try
                    if FConfigurationProfile then
                      Inc(FDepth);
                    try
                    InnerArr.Add(ParseCompactSequenceItem(Trim(Copy(Line, 3, MaxInt)), CurrentLineNo, InnerIndent + 2));
                    Inc(FIndex);
                    while (NOT Eof) AND IsSequenceLine(InnerIndent) do
                    begin
                      Line:=Trim(Copy(RemoveComment(CurrentLine), InnerIndent + 2, MaxInt));
                      Inc(FIndex);
                      InnerArr.Add(ParseCompactSequenceItem(Line, CurrentLineNo, InnerIndent + 2));
                    end;
                    finally
                      if FConfigurationProfile then
                        Dec(FDepth);
                    end;
                    Arr.Add(InnerArr);
                    InnerArr:=nil;
                  finally
                    InnerArr.Free;
                  end;
                end
                else
                begin
                  Inc(FIndex);
                  Arr.Add(ParseCompactSequenceItem(Line, CurrentLineNo, AIndent + 3));
                end;
              end;
              Value:=Arr;
              finally
                if FConfigurationProfile then
                  Dec(FDepth);
              end;
            except
              Arr.Free;
              raise;
            end;
          end
          else if IsBlockScalarHeader(ValueText) then
          begin
            CountNode(LineNo, AIndent + 2);
            Value:=ParseBlockScalar(ValueText, AIndent, LineNo)
          end
          else
          begin
            if (FlowBalance(ValueText) > 0) then
              ValueText:=CollectFlowValue(ValueText, AIndent)
            else if (QuoteBalance(ValueText) <> #0) AND (Eof OR ((CurrentLine <> '') AND (LeadingSpacesOf(CurrentLine) <= AIndent))) then
              Error(RCS_INVALID_YAML, CurrentLineNo, LeadingSpacesOf(CurrentLine) + 1)
            else if QuoteBalance(ValueText) = #0 then
              ValueText:=CollectPlainScalar(ValueText, AIndent + 1, True);
            Value:=ParseInlineValue(ValueText, LineNo, AIndent + 2);
          end;
        end;
      end;

      if Value = nil then
      begin
        CountNode(LineNo, AIndent + 2);
        Value:=TYAMLNull.Create;
      end;
      if FConfigurationProfile AND AObject.HasKey(Key) then
      begin
        Value.Free;
        Error(Format(RCS_DUPLICATE_KEY, [Key]), LineNo, AIndent + 1);
      end;
      AObject.SetOrAdd(Key, Value);
      Continue;
    end;

    Colon:=FindValueColon(Line);
    if Colon <= 0 then
      Break;

    KeyText:=Trim(Copy(Line, 1, Colon - 1));
    ExtractNodeProperties(KeyText, KeyAnchor, KeyAlias);
    if KeyAlias <> '' then
      KeyText:='*' + KeyAlias;

    CountNode(LineNo, AIndent + 1);
    if KeyText = '' then
      Key:=''
    else
      Key:=ParseKey(KeyText, LineNo);
    if FConfigurationProfile then
    begin
      KeyError:=YAMLConfigurationKeyError(AObject, Key);
      if KeyError <> '' then
        Error(KeyError, LineNo, AIndent + 1);
    end;

    if KeyAnchor <> '' then
    begin
      KeyValue:=TYAMLString.CreateFrom(Key);
      try
        StoreAnchor(KeyAnchor, KeyValue);
      finally
        KeyValue.Free;
      end;
    end;

    ValueText:=Trim(Copy(Line, Colon + 1, MaxInt));
    ExtractNodeProperties(ValueText, Anchor, AliasName);
    if AliasName <> '' then
      Value:=AliasValue(AliasName, LineNo, AIndent + Colon + 1)
    else
      Value:=nil;

    if ValueText = '' then
    begin
      Inc(FIndex);
      SkipIgnorable;
      if Value = nil then
      begin
        if Eof OR ((CurrentIndent <= AIndent) AND NOT IsSequenceLine(AIndent)) then
        begin
          CountNode(LineNo, AIndent + Colon + 1);
          Value:=TYAMLNull.Create
        end
        else
        begin
          if (Anchor <> '') AND (Trim(RemoveComment(CurrentLine)) <> '') AND (Trim(RemoveComment(CurrentLine))[1] = '&') AND (FindValueColon(Trim(RemoveComment(CurrentLine))) = 0) AND (NOT IsSequenceLine(CurrentIndent)) then
            Error(RCS_DUPLICATE_SCALAR_ANCHOR, CurrentLineNo, CurrentIndent + 1);
          Value:=ParseNode(CurrentIndent);
        end;
      end;
    end
    else if IsBlockScalarHeader(ValueText) then
    begin
      CountNode(LineNo, AIndent + Colon + 1);
      Value:=ParseBlockScalar(ValueText, AIndent, LineNo)
    end
    else if Value = nil then
    begin
      if (Length(ValueText) >= 2) AND (CharToYAML(ValueText[1]) = ycDash) and IsYAMLChar(ValueText[2], [ycSpace, ycTab]) then
        Error(RCS_INVALID_YAML, LineNo, AIndent + Colon + 1);
      Inc(FIndex);
      if FlowBalance(ValueText) > 0 then
        ValueText:=CollectFlowValue(ValueText, AIndent)
      else if (QuoteBalance(ValueText) <> #0) AND (Eof OR ((CurrentLine <> '') AND (LeadingSpacesOf(CurrentLine) <= AIndent))) then 
        Error(RCS_INVALID_YAML, CurrentLineNo, LeadingSpacesOf(CurrentLine) + 1)
      else if QuoteBalance(ValueText) = #0 then
      begin
        if (ValueText <> '') AND (NOT CharInSet(ValueText[1], ['[', '{', '"', ''''])) AND (FindValueColon(ValueText) > 0) AND (FindValueColon(Copy(ValueText, FindValueColon(ValueText) + 1, MaxInt)) > 0) then
          Error(RCS_INVALID_YAML, LineNo, AIndent + Colon + FindValueColon(ValueText));
        ValueText:=CollectPlainScalar(ValueText, AIndent + 1, True);
      end;
      Value:=ParseInlineValue(ValueText, LineNo, AIndent + Colon + 1);
    end
    else
    begin
      Inc(FIndex);
    end;

    StoreAnchor(Anchor, Value);
    if Key = '<<' then
    begin
      ApplyMerge(AObject, Value);
      Value.Free;
    end
    else
      AObject.SetOrAdd(Key, Value);
  end;
end;

function TYAMLBlockParser.RemoveComment(const ALine: String): String;
var
  I: Integer;
  SkipNext: Boolean;
  Quote: Char;
begin
  Result:='';
  Quote:=#0;
  SkipNext:=False;

  for I:=1 to Length(ALine) do
  begin
    if SkipNext then
    begin
      SkipNext:=False;
      Continue;
    end;

    if Quote <> #0 then
    begin
      Result:=Result + ALine[I];
      if (Quote = '"') AND (ALine[I] = '\') AND (I < Length(ALine)) then
      begin
        Result:=Result + ALine[I + 1];
        SkipNext:=True;
        Continue;
      end;
      if ALine[I] = Quote then
      begin
        if (Quote = '''') AND (I < Length(ALine)) AND (ALine[I + 1] = '''') then
          Continue;
        Quote:=#0;
      end;
      Continue;
    end;

    if CharInSet(ALine[I], ['"', '''']) AND ((I = 1) OR CharInSet(ALine[I - 1], [' ', #9, '[', '{', ','])) then
    begin
      Quote:=ALine[I];
      Result:=Result + ALine[I];
    end
    else if (CharToYAML(ALine[I]) = ycHash) AND ((I = 1) OR IsYAMLChar(ALine[I - 1], [ycSpace, ycTab])) then
      Break
    else
      Result:=Result + ALine[I];
  end;

  Result:=TrimRightSpaces(Result);
end;

procedure TYAMLBlockParser.SkipIgnorable;
var
  S: String;
begin
  while NOT Eof do
  begin
    S:=Trim(RemoveComment(CurrentLine));
    if S = '' then
      Inc(FIndex)
    else if (CurrentLine <> '') AND (CurrentLine[1] = S[1]) AND
      ((CharToYAML(S[1]) = ycPercent) OR (S = YAML_DOCUMENT_START)) then
      Inc(FIndex)
    else if (CurrentLine <> '') AND (CurrentLine[1] = S[1]) AND (S = YAML_DOCUMENT_END) then
    begin
      Inc(FIndex);
      Break;
    end
    else
      Break;
  end;
end;

function TYAMLBlockParser.TrimRightSpaces(const AValue: String): String;
begin
  Result:=AValue;
  while (Result <> '') AND IsYAMLChar(Result[Length(Result)], [ycSpace, ycTab]) do
    Delete(Result, Length(Result), 1);
end;

{ TYAMLWriter }

constructor TYAMLWriter.Create(AMode: TYAMLStringWriteMode);
begin
  inherited Create;
  FMode:=AMode;
end;

function TYAMLWriter.Indent(ALevel: Integer): String;
begin
  if FMode = ywmReadable then
    Result:=StringOfChar(YAML_CHARS[ycSpace], ALevel * YAML_INDENT_SIZE)
  else
    Result:='';
end;

function TYAMLWriter.NewLine: String;
begin
  if FMode = ywmReadable then
    Result:=sLineBreak
  else
    Result:='';
end;

function TYAMLWriter.Space: String;
begin
  if FMode = ywmReadable then
    Result:=YAML_CHARS[ycSpace]
  else
    Result:='';
end;

function TYAMLWriter.Write(AValue: TYAMLValue; ADocumentMarker: Boolean): String;
begin
  Result:='';
  if ADocumentMarker then
  begin
    Result:=YAML_CHARS[ycDash] + YAML_CHARS[ycDash] + YAML_CHARS[ycDash];
    if FMode = ywmReadable then
      Result:=Result + sLineBreak
    else
      Result:=Result + YAML_CHARS[ycSpace];
  end;
  Result:=Result + WriteValue(AValue, 0);
end;

function TYAMLWriter.WriteArray(AArray: TYAMLArray; ALevel: Integer): String;
var
  I: Integer;
begin
  if AArray.Count = 0 then
    Exit(YAML_CHARS[ycLeftBracket] + YAML_CHARS[ycRightBracket]);

  Result:=YAML_CHARS[ycLeftBracket];
  for I:=0 to AArray.Count - 1 do
  begin
    if I > 0 then
      Result:=Result + YAML_CHARS[ycComma];
    if FMode = ywmReadable then
      Result:=Result + NewLine + Indent(ALevel + 1);
    Result:=Result + WriteValue(AArray[I], ALevel + 1);
  end;
  if FMode = ywmReadable then
    Result:=Result + NewLine + Indent(ALevel);
  Result:=Result + YAML_CHARS[ycRightBracket];
end;

function TYAMLWriter.WriteKey(AKey: String): String;
begin
  if TYAML.IsSafeKey(AKey) then
    Result:=AKey
  else
    Result:=TYAML.EncodeString(AKey);
end;

function TYAMLWriter.WriteObject(AObject: TYAMLObject; ALevel: Integer): String;
var
  I: Integer;
begin
  if AObject.Count = 0 then
    Exit(YAML_CHARS[ycLeftBrace] + YAML_CHARS[ycRightBrace]);

  Result:=YAML_CHARS[ycLeftBrace];
  for I:=0 to AObject.Count - 1 do
  begin
    if I > 0 then
      Result:=Result + YAML_CHARS[ycComma];
    if FMode = ywmReadable then
      Result:=Result + NewLine + Indent(ALevel + 1);
    Result:=Result + WriteKey(AObject.Name[I]) + YAML_CHARS[ycColon] + Space +
      WriteValue(AObject.Item[I], ALevel + 1);
  end;
  if FMode = ywmReadable then
    Result:=Result + NewLine + Indent(ALevel);
  Result:=Result + YAML_CHARS[ycRightBrace];
end;

function TYAMLWriter.WriteValue(AValue: TYAMLValue; ALevel: Integer): String;
begin
  if AValue = nil then
    Result:=YAML_LITERAL_NULL
  else if AValue IS TYAMLNull then
    Result:=YAML_LITERAL_NULL
  else if AValue IS TYAMLString then
    Result:=TYAML.EncodeString(AValue.AsString)
  else if AValue IS TYAMLInteger then
    Result:=IntToStr(AValue.AsInteger)
  else if AValue IS TYAMLFloat then
    Result:=FloatToStr(AValue.AsFloat, YAMLFormatSettings)
  else if AValue IS TYAMLBoolean then
    Result:=AValue.AsString
  else if AValue IS TYAMLObject then
    Result:=WriteObject(AValue.AsObject, ALevel)
  else if AValue IS TYAMLArray then
    Result:=WriteArray(AValue.AsArray, ALevel)
  else
    Result:=YAML_LITERAL_NULL;
end;

// Small self-test example:
//
// var
//   K: TYAML;
//   Root, Metadata, Labels, Spec, Container: TYAMLObject;
//   Containers: TYAMLArray;
// begin
//   K:=TYAML.CreateObjectRoot;
//   try
//     K.WriteDocumentMarker:=True;
//     Root:=K.AsObject;
//     Root.Add('apiVersion', 'v1');
//     Root.Add('kind', 'Pod');
//     Metadata:=Root.AddObject('metadata');
//     Metadata.Add('name', 'my-pod');
//     Labels:=Metadata.AddObject('labels');
//     Labels.Add('app', 'demo');
//     Spec:=Root.AddObject('spec');
//     Containers:=Spec.AddArray('containers');
//     Container:=Containers.AddObject;
//     Container.Add('name', 'nginx');
//     Container.Add('image', 'nginx:1.20');
//     Writeln(K.WriteToString(ywmReadable));
//   finally
//     K.Free;
//   end;
// end;
//
// Parse example:
//
// K:=TYAML.FromString('--- {apiVersion: "v1", kind: "Pod", spec: {containers: [{name: "nginx", image: "nginx:1.20"}]}}');
// try
//   Writeln(K.AsObject['kind'].AsString);
//   Writeln(K.WriteToString(ywmCondensed));
// finally
//   K.Free;
// end;

end.
