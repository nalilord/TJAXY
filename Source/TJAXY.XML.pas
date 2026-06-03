(******************************************************************************)
(*                                                                            *)
(*  TJAXY XML Codec                                                           *)
(*                                                                            *)
(*  Version     : 0.01                                                        *)
(*  License     : BSD 2-Clause                                                *)
(*  Author      : NaliLord / TJAXY contributors                               *)
(*                                                                            *)
(*  This unit parses and writes XML using the shared TJAXY DOM.               *)
(*                                                                            *)
(******************************************************************************)

unit TJAXY.XML;

interface

uses
  SysUtils, Classes, Variants, TJAXY.Core;

type
  TXMLStringWriteMode = (xwmReadable, xwmCondensed);
  TXMLNamespaceMode = (xnmPreserve, xnmStripPrefixes);

  EXMLException = class(Exception);

  TXML = class(TTJAXYParser)
  private
    FData: TStringStream;
    FNamespaceMode: TXMLNamespaceMode;
  public
    class function CreateTemplate(const AName: String): TTJAXYTemplate; static;
    class function Template(const AName: String): TTJAXYTemplate; static;
    class function FromString(const AXML: String; const ANamespaceMode: TXMLNamespaceMode = xnmPreserve): TXML; static;
    class function FromFile(const AFile: String; const ANamespaceMode: TXMLNamespaceMode = xnmPreserve): TXML; static;
    class function FromStream(AStream: TStream; const ANamespaceMode: TXMLNamespaceMode = xnmPreserve): TXML; static;
    constructor Create; override;
    class function CreateArrayRoot: TXML; reintroduce; static;
    class function CreateObjectRoot: TXML; reintroduce; static;
    constructor CreateFromObject(AObject: TObject); override;
    class function CreateFromRecord<T>(const ARecord: T): TXML; static;
    constructor CreateFromString(const AXML: String; const ANamespaceMode: TXMLNamespaceMode = xnmPreserve);
    class function CreateFromFile(const AFile: String; const ANamespaceMode: TXMLNamespaceMode = xnmPreserve): TXML; static;
    constructor CreateFromStream(AStream: TStream; const ANamespaceMode: TXMLNamespaceMode = xnmPreserve);
    destructor Destroy; override;
    procedure Clear; override;
    procedure LoadFromFile(const AFileName: String); override;
    procedure LoadFromStream(AStream: TStream); override;
    procedure ReadFromString(const AValue: String); override;
    procedure SaveToFile(const AFileName: String); override;
    procedure SaveToStream(AStream: TStream); override;
    function WriteToString(AWriteMode: TTJAXYStringWriteMode = tjaxywmReadable): String; overload; override;
    function WriteToString(AWriteMode: TXMLStringWriteMode): String; reintroduce; overload; virtual;
    function WriteToFile(const AFileName: String; AWriteMode: TTJAXYStringWriteMode = tjaxywmReadable): String; overload; override;
    function WriteToFile(const AFileName: String; AWriteMode: TXMLStringWriteMode): String; reintroduce; overload; virtual;
    property NamespaceMode: TXMLNamespaceMode read FNamespaceMode write FNamespaceMode;
  end;

implementation

const
  XML_ATTR_KEY = '@';
  XML_TEXT_KEY = '#text';
  XML_LINE_FEED = #13#10;
  XML_INDENT_COUNT = 2;

  XML_CHAR_ENTITY_PREFIX = '#';
  XML_HEX_ENTITY_PREFIX = 'x';
  XML_ENTITY_OPEN = '&';
  XML_ENTITY_CLOSE = ';';
  XML_TAG_OPEN = '<';
  XML_TAG_CLOSE = '>';
  XML_ATTRIBUTE_SEPARATOR = ' ';
  XML_ATTRIBUTE_EQUALS = '=';
  XML_ATTRIBUTE_QUOTE = '"';
  XML_COLON = ':';
  XML_DTD_SUBSET_OPEN = '[';
  XML_DTD_SUBSET_CLOSE = ']';
  XML_COMMENT_HYPHENS = '--';
  XML_HEX_INT_PREFIX = '$';

  XML_ENTITY_LT = 'lt';
  XML_ENTITY_GT = 'gt';
  XML_ENTITY_QUOT = 'quot';
  XML_ENTITY_APOS = 'apos';
  XML_ENTITY_AMP = 'amp';
  XML_ENCODED_LT = '&lt;';
  XML_ENCODED_GT = '&gt;';
  XML_ENCODED_QUOT = '&quot;';
  XML_ENCODED_APOS = '&apos;';
  XML_ENCODED_AMP = '&amp;';

  XML_MARKER_CDATA_OPEN = '<![CDATA[';
  XML_MARKER_CDATA_CLOSE = ']]>';
  XML_MARKER_COMMENT_OPEN = '<!--';
  XML_MARKER_COMMENT_CLOSE = '-->';
  XML_MARKER_DOCTYPE_OPEN = '<!DOCTYPE';
  XML_MARKER_PI_OPEN = '<?';
  XML_MARKER_PI_CLOSE = '?>';
  XML_MARKER_EMPTY_ELEMENT_CLOSE = '/>';
  XML_MARKER_END_TAG_OPEN = '</';
  XML_MARKER_INTERNAL_SUBSET_CLOSE = ']>';
  XML_MARKER_XML_DECL_OPEN = '<?xml';
  XML_MARKER_XML_DECL_BODY = 'xml';
  XML_MARKER_XMLNS = 'xmlns';
  XML_MARKER_XMLNS_PREFIX = 'xmlns:';

  XML_DECL_VERSION = 'version';
  XML_DECL_ENCODING = 'encoding';
  XML_DECL_STANDALONE = 'standalone';
  XML_VERSION_1_0 = '1.0';
  XML_BOOL_YES = 'yes';
  XML_BOOL_NO = 'no';

  XML_NAME_START_CHARS: TSysCharSet = ['A'..'Z', 'a'..'z', '_', ':'];
  XML_NAME_CHARS: TSysCharSet = ['A'..'Z', 'a'..'z', '0'..'9', '_', '-', '.', ':'];
  XML_WHITESPACE_CHARS: TSysCharSet = [#9, #10, #13, ' '];
  XML_ALPHA_CHARS: TSysCharSet = ['A'..'Z', 'a'..'z'];
  XML_HEX_CHARS: TSysCharSet = ['0'..'9', 'A'..'F', 'a'..'f'];
  XML_DECIMAL_CHARS: TSysCharSet = ['0'..'9'];
  XML_ENCODING_CHARS: TSysCharSet = ['A'..'Z', 'a'..'z', '0'..'9', '.', '_', '-'];
  XML_QUOTE_CHARS: TSysCharSet = ['"', ''''];

resourcestring
  SXMLExpected = 'Expected "%s"';
  SXMLInvalidCharacter = 'Invalid XML character';
  SXMLUnterminatedEntity = 'Unterminated XML entity reference';
  SXMLInvalidCharacterReference = 'Invalid XML character reference';
  SXMLUnknownEntity = 'Unknown XML entity reference "%s"';
  SXMLInvalidComment = 'XML comment may not contain "--"';
  SXMLDuplicateDoctype = 'XML document may only contain one DOCTYPE declaration';
  SXMLUnterminatedDoctype = 'Unterminated XML DOCTYPE declaration';
  SXMLInvalidDeclaration = 'Invalid XML declaration';
  SXMLInvalidProcessingInstruction = 'Invalid XML processing instruction';
  SXMLDeclarationLocation = 'XML declaration is only allowed before the document element';
  SXMLDeclarationMustStartDocument = 'XML declaration must start at the beginning of the document';
  SXMLDoctypeLocation = 'DOCTYPE is only allowed before the document element';
  SXMLExpectedName = 'Expected XML name';
  SXMLExpectedQuotedValue = 'Expected quoted XML value';
  SXMLUnterminatedValue = 'Unterminated XML value';
  SXMLAttributeContainsElementOpen = 'XML attribute value may not contain "<"';
  SXMLCDataOutsideElement = 'CDATA must be inside an element';
  SXMLExpectedAttributeWhitespace = 'Expected whitespace between XML attributes';
  SXMLUnexpectedClosingTag = 'Unexpected closing tag for "%s"';
  SXMLCDataCloseInText = 'CDATA close marker is not allowed in character data';
  SXMLUnclosedElement = 'Unclosed XML element "%s"';
  SXMLUnexpectedTrailingContent = 'Unexpected trailing XML content';
  SXMLInvalidName = 'Invalid XML name "%s"';
  SXMLRootMustBeObject = 'XML root must be an object with at least one element name';

function TJAXYWriteModeToXML(AWriteMode: TTJAXYStringWriteMode): TXMLStringWriteMode;
begin
  case AWriteMode of
    tjaxywmReadable: Result:=xwmReadable;
    tjaxywmCondensed: Result:=xwmCondensed;
  else
    Result:=xwmReadable;
  end;
end;

function XMLEncode(const AValue: String): String;
begin
  Result:=StringReplace(AValue, XML_ENTITY_OPEN, XML_ENCODED_AMP, [rfReplaceAll]);
  Result:=StringReplace(Result, XML_TAG_OPEN, XML_ENCODED_LT, [rfReplaceAll]);
  Result:=StringReplace(Result, XML_TAG_CLOSE, XML_ENCODED_GT, [rfReplaceAll]);
end;

function XMLEncodeAttribute(const AValue: String): String;
begin
  Result:=XMLEncode(AValue);
  Result:=StringReplace(Result, XML_ATTRIBUTE_QUOTE, XML_ENCODED_QUOT, [rfReplaceAll]);
  Result:=StringReplace(Result, '''', XML_ENCODED_APOS, [rfReplaceAll]);
end;

procedure XMLValidateChars(const AValue: String);
var
  I: Integer;
  Code: Integer;
begin
  for I:=1 to Length(AValue) do
  begin
    Code:=Ord(AValue[I]);
    if NOT ((Code = 9) OR (Code = 10) OR (Code = 13) OR
      ((Code >= 32) AND (Code <= $D7FF)) OR
      ((Code >= $E000) AND (Code <= $FFFD))) then
      raise EXMLException.Create(SXMLInvalidCharacter);
  end;
end;

function XMLAllCharsInSet(const AValue: String; const ASet: TSysCharSet): Boolean;
var
  I: Integer;
begin
  Result:=AValue <> '';
  for I:=1 to Length(AValue) do
    if NOT CharInSet(AValue[I], ASet) then
      Exit(False);
end;

function XMLDecode(const AValue: String): String;
var
  I: Integer;
  SemiPos: Integer;
  Entity: String;
  Code: Integer;
  Hex: Boolean;
begin
  Result:='';
  I:=1;
  while I <= Length(AValue) do
  begin
    if AValue[I] <> XML_ENTITY_OPEN then
    begin
      Result:=Result + AValue[I];
      Inc(I);
      Continue;
    end;

    SemiPos:=I + 1;
    while (SemiPos <= Length(AValue)) AND (AValue[SemiPos] <> XML_ENTITY_CLOSE) do
      Inc(SemiPos);
    if SemiPos > Length(AValue) then
      raise EXMLException.Create(SXMLUnterminatedEntity);

    Entity:=Copy(AValue, I + 1, SemiPos - I - 1);
    if Entity = XML_ENTITY_LT then
      Result:=Result + XML_TAG_OPEN
    else if Entity = XML_ENTITY_GT then
      Result:=Result + XML_TAG_CLOSE
    else if Entity = XML_ENTITY_QUOT then
      Result:=Result + XML_ATTRIBUTE_QUOTE
    else if Entity = XML_ENTITY_APOS then
      Result:=Result + ''''
    else if Entity = XML_ENTITY_AMP then
      Result:=Result + XML_ENTITY_OPEN
    else if (Entity <> '') AND (Entity[1] = XML_CHAR_ENTITY_PREFIX) then
    begin
      Hex:=(Length(Entity) > 2) AND (Entity[2] = XML_HEX_ENTITY_PREFIX);
      if Hex then
      begin
        if NOT XMLAllCharsInSet(Copy(Entity, 3, MaxInt), XML_HEX_CHARS) then
          raise EXMLException.Create(SXMLInvalidCharacterReference);
        Code:=StrToIntDef(XML_HEX_INT_PREFIX + Copy(Entity, 3, MaxInt), -1)
      end
      else
      begin
        if NOT XMLAllCharsInSet(Copy(Entity, 2, MaxInt), XML_DECIMAL_CHARS) then
          raise EXMLException.Create(SXMLInvalidCharacterReference);
        Code:=StrToIntDef(Copy(Entity, 2, MaxInt), -1);
      end;
      if (Code < 0) OR (Code > $FFFF) then
        raise EXMLException.Create(SXMLInvalidCharacterReference);
      Result:=Result + Char(Code);
    end
    else
      raise EXMLException.CreateFmt(SXMLUnknownEntity, [Entity]);

    I:=SemiPos + 1;
  end;
  XMLValidateChars(Result);
end;

procedure XMLAddGroupedChild(const AObject: TTJAXYObject; const AName: String; const AValue: TTJAXYValue);
var
  Existing: TTJAXYValue;
  Arr: TTJAXYArray;
begin
  if NOT AObject.HasKey(AName) then
  begin
    AObject.Add(AName, AValue);
    Exit;
  end;

  Existing:=AObject[AName];
  if Existing IS TTJAXYArray then
    Existing.AsArray.Insert(Existing.AsArray.Count, AValue)
  else
  begin
    Arr:=TTJAXYArray.Create;
    try
      Arr.Insert(Arr.Count, Existing.Copy);
      Arr.Insert(Arr.Count, AValue);
      AObject.SetOrAdd(AName, Arr);
    except
      Arr.Free;
      raise;
    end;
  end;
end;

type
  TTJAXYXMLParser = class
  private
    FNamespaceMode: TXMLNamespaceMode;
    FSeenDoctype: Boolean;
    FText: String;
    FIndex: Integer;
    function Current: Char;
    function Eof: Boolean;
    function StartsWith(const AValue: String): Boolean;
    procedure Expect(const AChar: Char);
    procedure SkipWhitespace;
    procedure SkipDeclarationAndTrivia(AAllowDoctype: Boolean);
    procedure SkipComment;
    procedure SkipDoctype;
    procedure SkipProcessingInstruction(AAllowXMLTarget: Boolean);
    procedure ValidateXMLDeclaration(const ABody: String);
    function StartsWithText(const AValue: String): Boolean;
    function ReadName: String;
    function ReadQuotedValue: String;
    function ReadUntil(const AMarker: String): String;
    function NormalizeName(const AName: String): String;
    function ShouldKeepAttribute(const AName: String): Boolean;
    function ParseElement(out AName: String): TTJAXYValue;
  public
    constructor Create(const AText: String; const ANamespaceMode: TXMLNamespaceMode);
    function Parse: TTJAXYValue;
  end;

  TXMLWriter = class
  private
    FMode: TXMLStringWriteMode;
    function Indent(const ALevel: Integer): String;
    function NewLine: String;
    procedure ValidateName(const AName: String);
    function WriteElement(const AName: String; const AValue: TTJAXYValue; const ALevel: Integer): String;
    function WriteObjectElement(const AName: String; const AObject: TTJAXYObject; const ALevel: Integer): String;
    function WriteScalarElement(const AName: String; const AValue: TTJAXYValue; const ALevel: Integer): String;
    function WriteValueAsText(const AValue: TTJAXYValue): String;
  public
    constructor Create(const AMode: TXMLStringWriteMode);
    function Write(const AValue: TTJAXYValue): String;
  end;

constructor TTJAXYXMLParser.Create(const AText: String; const ANamespaceMode: TXMLNamespaceMode);
begin
  inherited Create;
  FText:=AText;
  FIndex:=1;
  FNamespaceMode:=ANamespaceMode;
  FSeenDoctype:=False;
end;

function TTJAXYXMLParser.Current: Char;
begin
  if Eof then
    Result:=#0
  else
    Result:=FText[FIndex];
end;

function TTJAXYXMLParser.Eof: Boolean;
begin
  Result:=FIndex > Length(FText);
end;

function TTJAXYXMLParser.StartsWith(const AValue: String): Boolean;
begin
  Result:=Copy(FText, FIndex, Length(AValue)) = AValue;
end;

function TTJAXYXMLParser.StartsWithText(const AValue: String): Boolean;
begin
  Result:=SameText(Copy(FText, FIndex, Length(AValue)), AValue);
end;

procedure TTJAXYXMLParser.Expect(const AChar: Char);
begin
  if Current <> AChar then
    raise EXMLException.CreateFmt(SXMLExpected, [AChar]);
  Inc(FIndex);
end;

procedure TTJAXYXMLParser.SkipWhitespace;
begin
  while CharInSet(Current, XML_WHITESPACE_CHARS) do
    Inc(FIndex);
end;

function TTJAXYXMLParser.ReadUntil(const AMarker: String): String;
var
  Start: Integer;
  PosMarker: Integer;
begin
  Start:=FIndex;
  PosMarker:=Pos(AMarker, Copy(FText, FIndex, MaxInt));
  if PosMarker <= 0 then
    raise EXMLException.CreateFmt(SXMLExpected, [AMarker]);
  Result:=Copy(FText, Start, PosMarker - 1);
  FIndex:=Start + PosMarker - 1 + Length(AMarker);
end;

procedure TTJAXYXMLParser.SkipComment;
var
  Body: String;
begin
  Inc(FIndex, Length(XML_MARKER_COMMENT_OPEN));
  Body:=ReadUntil(XML_MARKER_COMMENT_CLOSE);
  XMLValidateChars(Body);
  if (Pos(XML_COMMENT_HYPHENS, Body) > 0) OR ((Body <> '') AND (Body[Length(Body)] = '-')) then
    raise EXMLException.Create(SXMLInvalidComment);
end;

procedure TTJAXYXMLParser.SkipDoctype;
var
  Start: Integer;
  Body: String;
  Quote: Char;
  HasInternalSubset: Boolean;
begin
  if FSeenDoctype then
    raise EXMLException.Create(SXMLDuplicateDoctype);

  Start:=FIndex;
  Inc(FIndex, Length(XML_MARKER_DOCTYPE_OPEN));
  Quote:=#0;
  HasInternalSubset:=False;
  while NOT Eof do
  begin
    if (Quote = #0) AND StartsWith(XML_MARKER_COMMENT_OPEN) then
    begin
      SkipComment;
      Continue;
    end;

    if Quote <> #0 then
    begin
      if Current = Quote then
        Quote:=#0;
      Inc(FIndex);
      Continue;
    end;

    if CharInSet(Current, XML_QUOTE_CHARS) then
    begin
      Quote:=Current;
      Inc(FIndex);
      Continue;
    end;

    if Current = XML_DTD_SUBSET_OPEN then
      HasInternalSubset:=True;

    if ((NOT HasInternalSubset) AND (Current = XML_TAG_CLOSE)) OR
      (HasInternalSubset AND (Current = XML_DTD_SUBSET_CLOSE) AND StartsWith(XML_MARKER_INTERNAL_SUBSET_CLOSE)) then
    begin
      if HasInternalSubset then
        Inc(FIndex, 2)
      else
        Inc(FIndex);
      Body:=Copy(FText, Start, FIndex - Start);
      XMLValidateChars(Body);
      FSeenDoctype:=True;
      Exit;
    end;
    Inc(FIndex);
  end;

  raise EXMLException.Create(SXMLUnterminatedDoctype);
end;

procedure TTJAXYXMLParser.ValidateXMLDeclaration(const ABody: String);
var
  I: Integer;
  Name: String;
  Value: String;
  Quote: Char;
  SeenVersion: Boolean;
  SeenEncoding: Boolean;
  SeenStandalone: Boolean;
  AttrIndex: Integer;

  procedure NeedSpace;
  var
    HadSpace: Boolean;
  begin
    HadSpace:=False;
    while (I <= Length(ABody)) AND CharInSet(ABody[I], XML_WHITESPACE_CHARS) do
    begin
      HadSpace:=True;
      Inc(I);
    end;
    if NOT HadSpace then
      raise EXMLException.Create(SXMLInvalidDeclaration);
  end;

  function ReadPseudoName: String;
  var
    Start: Integer;
  begin
    Start:=I;
    if (I > Length(ABody)) OR NOT CharInSet(ABody[I], XML_NAME_START_CHARS) then
      raise EXMLException.Create(SXMLInvalidDeclaration);
    Inc(I);
    while (I <= Length(ABody)) AND CharInSet(ABody[I], XML_NAME_CHARS) do
      Inc(I);
    Result:=Copy(ABody, Start, I - Start);
  end;

  function ReadPseudoValue: String;
  var
    Start: Integer;
  begin
    while (I <= Length(ABody)) AND CharInSet(ABody[I], XML_WHITESPACE_CHARS) do
      Inc(I);
    if (I > Length(ABody)) OR (ABody[I] <> XML_ATTRIBUTE_EQUALS) then
      raise EXMLException.Create(SXMLInvalidDeclaration);
    Inc(I);
    while (I <= Length(ABody)) AND CharInSet(ABody[I], XML_WHITESPACE_CHARS) do
      Inc(I);
    if (I > Length(ABody)) OR NOT CharInSet(ABody[I], XML_QUOTE_CHARS) then
      raise EXMLException.Create(SXMLInvalidDeclaration);
    Quote:=ABody[I];
    Inc(I);
    Start:=I;
    while (I <= Length(ABody)) AND (ABody[I] <> Quote) do
      Inc(I);
    if I > Length(ABody) then
      raise EXMLException.Create(SXMLInvalidDeclaration);
    Result:=Copy(ABody, Start, I - Start);
    Inc(I);
  end;

begin
  XMLValidateChars(ABody);
  I:=1;
  SeenVersion:=False;
  SeenEncoding:=False;
  SeenStandalone:=False;
  AttrIndex:=0;
  NeedSpace;

  while I <= Length(ABody) do
  begin
    if CharInSet(ABody[I], XML_WHITESPACE_CHARS) then
    begin
      NeedSpace;
      if I > Length(ABody) then
        Break;
    end;

    Inc(AttrIndex);
    Name:=ReadPseudoName;
    Value:=ReadPseudoValue;
    if (I <= Length(ABody)) AND NOT CharInSet(ABody[I], XML_WHITESPACE_CHARS) then
      raise EXMLException.Create(SXMLInvalidDeclaration);

    if Name = XML_DECL_VERSION then
    begin
      if SeenVersion OR (AttrIndex <> 1) OR (Value <> XML_VERSION_1_0) then
        raise EXMLException.Create(SXMLInvalidDeclaration);
      SeenVersion:=True;
    end
    else if Name = XML_DECL_ENCODING then
    begin
      if (NOT SeenVersion) OR SeenEncoding OR SeenStandalone OR
        (Value = '') OR NOT CharInSet(Value[1], XML_ALPHA_CHARS) OR
        (NOT XMLAllCharsInSet(Value, XML_ENCODING_CHARS)) then
        raise EXMLException.Create(SXMLInvalidDeclaration);
      SeenEncoding:=True;
    end
    else if Name = XML_DECL_STANDALONE then
    begin
      if (NOT SeenVersion) OR SeenStandalone OR NOT ((Value = XML_BOOL_YES) OR (Value = XML_BOOL_NO)) then
        raise EXMLException.Create(SXMLInvalidDeclaration);
      SeenStandalone:=True;
    end
    else
      raise EXMLException.Create(SXMLInvalidDeclaration);
  end;

  if NOT SeenVersion then
    raise EXMLException.Create(SXMLInvalidDeclaration);
end;

procedure TTJAXYXMLParser.SkipProcessingInstruction(AAllowXMLTarget: Boolean);
var
  Target: String;
  Body: String;
begin
  Inc(FIndex, Length(XML_MARKER_PI_OPEN));
  Target:=ReadName;
  if (NOT StartsWith(XML_MARKER_PI_CLOSE)) AND NOT CharInSet(Current, XML_WHITESPACE_CHARS) then
    raise EXMLException.Create(SXMLInvalidProcessingInstruction);
  Body:=ReadUntil(XML_MARKER_PI_CLOSE);
  if SameText(Target, XML_MARKER_XML_DECL_BODY) then
  begin
    if (NOT AAllowXMLTarget) OR (Target <> XML_MARKER_XML_DECL_BODY) then
      raise EXMLException.Create(SXMLDeclarationLocation);
    ValidateXMLDeclaration(Body);
  end
  else
    XMLValidateChars(Body);
end;

procedure TTJAXYXMLParser.SkipDeclarationAndTrivia(AAllowDoctype: Boolean);
var
  BeforeWhitespace: Integer;
begin
  BeforeWhitespace:=FIndex;
  SkipWhitespace;
  if (FIndex > BeforeWhitespace) AND StartsWithText(XML_MARKER_XML_DECL_OPEN) then
    raise EXMLException.Create(SXMLDeclarationMustStartDocument);
  while StartsWith(XML_MARKER_PI_OPEN) OR StartsWith(XML_MARKER_COMMENT_OPEN) OR StartsWithText(XML_MARKER_DOCTYPE_OPEN) do
  begin
    if StartsWith(XML_MARKER_PI_OPEN) then
    begin
      if StartsWithText(XML_MARKER_XML_DECL_OPEN) AND (FIndex <> 1) then
        raise EXMLException.Create(SXMLDeclarationMustStartDocument);
      SkipProcessingInstruction(True)
    end
    else if StartsWith(XML_MARKER_COMMENT_OPEN) then
      SkipComment
    else if StartsWithText(XML_MARKER_DOCTYPE_OPEN) then
    begin
      if NOT AAllowDoctype then
        raise EXMLException.Create(SXMLDoctypeLocation);
      SkipDoctype;
    end;
    SkipWhitespace;
  end;
end;

function TTJAXYXMLParser.ReadName: String;
var
  Start: Integer;
begin
  Start:=FIndex;
  if NOT CharInSet(Current, XML_NAME_START_CHARS) then
    raise EXMLException.Create(SXMLExpectedName);
  Inc(FIndex);
  while CharInSet(Current, XML_NAME_CHARS) do
    Inc(FIndex);
  Result:=Copy(FText, Start, FIndex - Start);
  if Result = '' then
    raise EXMLException.Create(SXMLExpectedName);
end;

function TTJAXYXMLParser.NormalizeName(const AName: String): String;
var
  P: Integer;
begin
  Result:=AName;
  if FNamespaceMode = xnmStripPrefixes then
  begin
    P:=Pos(XML_COLON, Result);
    if P > 0 then
      Delete(Result, 1, P);
  end;
end;

function TTJAXYXMLParser.ShouldKeepAttribute(const AName: String): Boolean;
begin
  Result:=True;
  if FNamespaceMode = xnmStripPrefixes then
    Result:=NOT ((AName = XML_MARKER_XMLNS) OR (Copy(AName, 1, Length(XML_MARKER_XMLNS_PREFIX)) = XML_MARKER_XMLNS_PREFIX));
end;

function TTJAXYXMLParser.ReadQuotedValue: String;
var
  Quote: Char;
  Start: Integer;
  Raw: String;
begin
  Quote:=Current;
  if NOT CharInSet(Quote, XML_QUOTE_CHARS) then
    raise EXMLException.Create(SXMLExpectedQuotedValue);
  Inc(FIndex);
  Start:=FIndex;
  while (NOT Eof) AND (Current <> Quote) do
    Inc(FIndex);
  if Eof then
    raise EXMLException.Create(SXMLUnterminatedValue);
  Raw:=Copy(FText, Start, FIndex - Start);
  if Pos(XML_TAG_OPEN, Raw) > 0 then
    raise EXMLException.Create(SXMLAttributeContainsElementOpen);
  Result:=XMLDecode(Raw);
  Inc(FIndex);
end;

function TTJAXYXMLParser.ParseElement(out AName: String): TTJAXYValue;
var
  Obj: TTJAXYObject;
  Attrs: TTJAXYObject;
  AttrName: String;
  ChildName: String;
  ChildValue: TTJAXYValue;
  Text: String;
  HasAttributes: Boolean;
  HasElements: Boolean;
  Closed: Boolean;
  Start: Integer;
  RawText: String;
begin
  Expect(XML_TAG_OPEN);
  if StartsWith(Copy(XML_MARKER_CDATA_OPEN, 2, MaxInt)) then
    raise EXMLException.Create(SXMLCDataOutsideElement);
  if StartsWithText(Copy(XML_MARKER_DOCTYPE_OPEN, 2, MaxInt)) then
    raise EXMLException.Create(SXMLDoctypeLocation);
  AName:=NormalizeName(ReadName);

  Obj:=TTJAXYObject.Create;
  HasAttributes:=False;
  HasElements:=False;
  Closed:=False;
  Attrs:=nil;
  try
    SkipWhitespace;
    while (Current <> XML_TAG_CLOSE) AND (NOT StartsWith(XML_MARKER_EMPTY_ELEMENT_CLOSE)) do
    begin
      AttrName:=ReadName;
      SkipWhitespace;
      Expect(XML_ATTRIBUTE_EQUALS);
      SkipWhitespace;
      if ShouldKeepAttribute(AttrName) then
      begin
        AttrName:=NormalizeName(AttrName);
        if NOT Assigned(Attrs) then
        begin
          Attrs:=TTJAXYObject.Create;
          Obj.Add(XML_ATTR_KEY, Attrs);
        end;
        Attrs.Add(AttrName, ReadQuotedValue);
        HasAttributes:=True;
      end
      else
      begin
        ReadQuotedValue;
      end;
      if (NOT Eof) AND (Current <> XML_TAG_CLOSE) AND (NOT StartsWith(XML_MARKER_EMPTY_ELEMENT_CLOSE)) AND
        NOT CharInSet(Current, XML_WHITESPACE_CHARS) then
        raise EXMLException.Create(SXMLExpectedAttributeWhitespace);
      SkipWhitespace;
    end;

    if StartsWith(XML_MARKER_EMPTY_ELEMENT_CLOSE) then
    begin
      Inc(FIndex, Length(XML_MARKER_EMPTY_ELEMENT_CLOSE));
      if HasAttributes then
        Exit(Obj);
      Obj.Free;
      Exit(TTJAXYNull.Create);
    end;

    Expect(XML_TAG_CLOSE);
    Text:='';
    while NOT Eof do
    begin
      if StartsWith(XML_MARKER_END_TAG_OPEN) then
      begin
        Inc(FIndex, Length(XML_MARKER_END_TAG_OPEN));
        if NormalizeName(ReadName) <> AName then
          raise EXMLException.CreateFmt(SXMLUnexpectedClosingTag, [AName]);
        SkipWhitespace;
        Expect(XML_TAG_CLOSE);
        Closed:=True;
        Break;
      end
      else if StartsWith(XML_MARKER_COMMENT_OPEN) then
        SkipComment
      else if StartsWith(XML_MARKER_PI_OPEN) then
        SkipProcessingInstruction(False)
      else if StartsWith(XML_MARKER_CDATA_OPEN) then
      begin
        Inc(FIndex, Length(XML_MARKER_CDATA_OPEN));
        RawText:=ReadUntil(XML_MARKER_CDATA_CLOSE);
        XMLValidateChars(RawText);
        Text:=Text + RawText;
      end
      else if Current = XML_TAG_OPEN then
      begin
        HasElements:=True;
        ChildValue:=ParseElement(ChildName);
        XMLAddGroupedChild(Obj, ChildName, ChildValue);
      end
      else
      begin
        Start:=FIndex;
        while (NOT Eof) AND (Current <> XML_TAG_OPEN) do
          Inc(FIndex);
        RawText:=Copy(FText, Start, FIndex - Start);
        if Pos(XML_MARKER_CDATA_CLOSE, RawText) > 0 then
          raise EXMLException.Create(SXMLCDataCloseInText);
        Text:=Text + XMLDecode(RawText);
      end;
    end;

    if NOT Closed then
      raise EXMLException.CreateFmt(SXMLUnclosedElement, [AName]);

    if (NOT HasAttributes) AND (NOT HasElements) then
    begin
      Result:=TTJAXYString.CreateFrom(Text);
      Obj.Free;
      Exit;
    end;

    if Trim(Text) <> '' then
      Obj.Add(XML_TEXT_KEY, Text);
    Result:=Obj;
  except
    Obj.Free;
    raise;
  end;
end;

function TTJAXYXMLParser.Parse: TTJAXYValue;
var
  RootName: String;
  RootValue: TTJAXYValue;
  Obj: TTJAXYObject;
begin
  SkipDeclarationAndTrivia(True);
  RootValue:=ParseElement(RootName);
  SkipDeclarationAndTrivia(False);
  if NOT Eof then
    raise EXMLException.Create(SXMLUnexpectedTrailingContent);

  Obj:=TTJAXYObject.Create;
  try
    Obj.Add(RootName, RootValue);
    Result:=Obj;
  except
    Obj.Free;
    raise;
  end;
end;

constructor TXMLWriter.Create(const AMode: TXMLStringWriteMode);
begin
  inherited Create;
  FMode:=AMode;
end;

function TXMLWriter.Indent(const ALevel: Integer): String;
begin
  if FMode = xwmReadable then
    Result:=StringOfChar(XML_ATTRIBUTE_SEPARATOR, ALevel * XML_INDENT_COUNT)
  else
    Result:='';
end;

function TXMLWriter.NewLine: String;
begin
  if FMode = xwmReadable then
    Result:=XML_LINE_FEED
  else
    Result:='';
end;

procedure TXMLWriter.ValidateName(const AName: String);
var
  I: Integer;
begin
  if (AName = '') OR (NOT CharInSet(AName[1], XML_NAME_START_CHARS)) then
    raise EXMLException.CreateFmt(SXMLInvalidName, [AName]);
  for I:=2 to Length(AName) do
    if NOT CharInSet(AName[I], XML_NAME_CHARS) then
      raise EXMLException.CreateFmt(SXMLInvalidName, [AName]);
end;

function TXMLWriter.WriteValueAsText(const AValue: TTJAXYValue): String;
begin
  if (AValue = nil) OR AValue.IsNull then
    Result:=''
  else if AValue.IsBoolean then
    Result:=BoolToStr(AValue.AsBoolean, True)
  else
    Result:=AValue.AsString;
end;

function TXMLWriter.WriteScalarElement(const AName: String; const AValue: TTJAXYValue; const ALevel: Integer): String;
begin
  ValidateName(AName);
  if (AValue = nil) OR AValue.IsNull then
    Result:=Indent(ALevel) + XML_TAG_OPEN + AName + XML_MARKER_EMPTY_ELEMENT_CLOSE
  else
    Result:=Indent(ALevel) + XML_TAG_OPEN + AName + XML_TAG_CLOSE + XMLEncode(WriteValueAsText(AValue)) +
      XML_MARKER_END_TAG_OPEN + AName + XML_TAG_CLOSE;
end;

function TXMLWriter.WriteObjectElement(const AName: String; const AObject: TTJAXYObject; const ALevel: Integer): String;
var
  I: Integer;
  Attrs: TTJAXYObject;
  AttrText: String;
  Body: String;
  TextValue: TTJAXYValue;
  HasChildElements: Boolean;
begin
  ValidateName(AName);
  AttrText:='';
  if AObject.HasKey(XML_ATTR_KEY) AND AObject[XML_ATTR_KEY].IsObject then
  begin
    Attrs:=AObject[XML_ATTR_KEY].AsObject;
    for I:=0 to Attrs.Count - 1 do
    begin
      ValidateName(Attrs.Name[I]);
      AttrText:=AttrText + XML_ATTRIBUTE_SEPARATOR + Attrs.Name[I] + XML_ATTRIBUTE_EQUALS + XML_ATTRIBUTE_QUOTE +
        XMLEncodeAttribute(WriteValueAsText(Attrs.Item[I])) + XML_ATTRIBUTE_QUOTE;
    end;
  end;

  Body:='';
  HasChildElements:=False;
  TextValue:=nil;
  if AObject.HasKey(XML_TEXT_KEY) then
    TextValue:=AObject[XML_TEXT_KEY];

  if Assigned(TextValue) then
    Body:=Body + XMLEncode(WriteValueAsText(TextValue));

  for I:=0 to AObject.Count - 1 do
    if (AObject.Name[I] <> XML_ATTR_KEY) AND (AObject.Name[I] <> XML_TEXT_KEY) then
    begin
      if Body <> '' then
        Body:=Body + NewLine;
      Body:=Body + WriteElement(AObject.Name[I], AObject.Item[I], ALevel + 1);
      HasChildElements:=True;
    end;

  if Body = '' then
    Result:=Indent(ALevel) + XML_TAG_OPEN + AName + AttrText + XML_MARKER_EMPTY_ELEMENT_CLOSE
  else if HasChildElements AND (TextValue = nil) then
    Result:=Indent(ALevel) + XML_TAG_OPEN + AName + AttrText + XML_TAG_CLOSE + NewLine + Body + NewLine +
      Indent(ALevel) + XML_MARKER_END_TAG_OPEN + AName + XML_TAG_CLOSE
  else
    Result:=Indent(ALevel) + XML_TAG_OPEN + AName + AttrText + XML_TAG_CLOSE + Body +
      XML_MARKER_END_TAG_OPEN + AName + XML_TAG_CLOSE;
end;

function TXMLWriter.WriteElement(const AName: String; const AValue: TTJAXYValue; const ALevel: Integer): String;
var
  I: Integer;
begin
  if AValue IS TTJAXYArray then
  begin
    Result:='';
    for I:=0 to AValue.AsArray.Count - 1 do
    begin
      if I > 0 then
        Result:=Result + NewLine;
      Result:=Result + WriteElement(AName, AValue.AsArray[I], ALevel);
    end;
  end
  else if AValue IS TTJAXYObject then
    Result:=WriteObjectElement(AName, AValue.AsObject, ALevel)
  else
    Result:=WriteScalarElement(AName, AValue, ALevel);
end;

function TXMLWriter.Write(const AValue: TTJAXYValue): String;
var
  I: Integer;
begin
  if (AValue = nil) OR (NOT AValue.IsObject) then
    raise EXMLException.Create(SXMLRootMustBeObject);

  Result:='';
  for I:=0 to AValue.AsObject.Count - 1 do
  begin
    if I > 0 then
      Result:=Result + NewLine;
    Result:=Result + WriteElement(AValue.AsObject.Name[I], AValue.AsObject.Item[I], 0);
  end;
end;

{ TXML }

class function TXML.CreateTemplate(const AName: String): TTJAXYTemplate;
begin
  Result:=TTJAXY.CreateTemplate(AName);
end;

class function TXML.Template(const AName: String): TTJAXYTemplate;
begin
  Result:=TTJAXY.Template(AName);
end;

class function TXML.FromFile(const AFile: String; const ANamespaceMode: TXMLNamespaceMode): TXML;
begin
  Result:=TXML.CreateFromFile(AFile, ANamespaceMode);
end;

class function TXML.FromStream(AStream: TStream; const ANamespaceMode: TXMLNamespaceMode): TXML;
begin
  Result:=TXML.CreateFromStream(AStream, ANamespaceMode);
end;

class function TXML.FromString(const AXML: String; const ANamespaceMode: TXMLNamespaceMode): TXML;
begin
  Result:=TXML.CreateFromString(AXML, ANamespaceMode);
end;

constructor TXML.Create;
begin
  inherited Create;
  FData:=TStringStream.Create('', TEncoding.UTF8, False);
  FNamespaceMode:=xnmPreserve;
end;

class function TXML.CreateArrayRoot: TXML;
begin
  Result:=TXML.Create;
  Result.RootNewArray;
end;

class function TXML.CreateObjectRoot: TXML;
begin
  Result:=TXML.Create;
  Result.RootNewObject;
end;

constructor TXML.CreateFromObject(AObject: TObject);
begin
  Create;
  LoadFromObject(AObject);
end;

class function TXML.CreateFromRecord<T>(const ARecord: T): TXML;
var
  Doc: TTJAXY;
begin
  Result:=TXML.CreateObjectRoot;
  Doc:=TTJAXY.CreateFromRecord<T>(ARecord);
  try
    Result.SetRoot(Doc.Root.Copy);
  finally
    Doc.Free;
  end;
end;

class function TXML.CreateFromFile(const AFile: String; const ANamespaceMode: TXMLNamespaceMode): TXML;
begin
  Result:=TXML.Create;
  try
    Result.FNamespaceMode:=ANamespaceMode;
    Result.LoadFromFile(AFile);
  except
    Result.Free;
    raise;
  end;
end;

constructor TXML.CreateFromStream(AStream: TStream; const ANamespaceMode: TXMLNamespaceMode);
begin
  Create;
  FNamespaceMode:=ANamespaceMode;
  LoadFromStream(AStream);
end;

constructor TXML.CreateFromString(const AXML: String; const ANamespaceMode: TXMLNamespaceMode);
begin
  Create;
  FNamespaceMode:=ANamespaceMode;
  ReadFromString(AXML);
end;

destructor TXML.Destroy;
begin
  FreeAndNil(FData);
  inherited;
end;

procedure TXML.Clear;
begin
  FData.Clear;
  inherited Clear;
end;

procedure TXML.LoadFromFile(const AFileName: String);
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

procedure TXML.LoadFromStream(AStream: TStream);
begin
  FData.Clear;
  FData.CopyFrom(AStream, 0);
  FData.Position:=0;
  ReadFromString(FData.DataString);
end;

procedure TXML.ReadFromString(const AValue: String);
var
  Parser: TTJAXYXMLParser;
begin
  FData.Clear;
  FData.WriteString(AValue);
  FData.Position:=0;

  Parser:=TTJAXYXMLParser.Create(AValue, FNamespaceMode);
  try
    SetRoot(Parser.Parse);
  finally
    Parser.Free;
  end;
end;

procedure TXML.SaveToFile(const AFileName: String);
begin
  WriteToFile(AFileName);
end;

procedure TXML.SaveToStream(AStream: TStream);
var
  S: String;
begin
  S:=WriteToString;
  if S <> '' then
    AStream.WriteBuffer(Pointer(S)^, Length(S) * SizeOf(Char));
end;

function TXML.WriteToFile(const AFileName: String; AWriteMode: TXMLStringWriteMode): String;
var
  Stream: TFileStream;
begin
  Result:=WriteToString(AWriteMode);
  Stream:=TFileStream.Create(AFileName, fmCreate);
  try
    if Result <> '' then
      Stream.WriteBuffer(Pointer(Result)^, Length(Result) * SizeOf(Char));
  finally
    Stream.Free;
  end;
end;

function TXML.WriteToFile(const AFileName: String; AWriteMode: TTJAXYStringWriteMode): String;
begin
  Result:=WriteToFile(AFileName, TJAXYWriteModeToXML(AWriteMode));
end;

function TXML.WriteToString(AWriteMode: TXMLStringWriteMode): String;
var
  Writer: TXMLWriter;
begin
  Writer:=TXMLWriter.Create(AWriteMode);
  try
    Result:=Writer.Write(Root);
  finally
    Writer.Free;
  end;
end;

function TXML.WriteToString(AWriteMode: TTJAXYStringWriteMode): String;
begin
  Result:=WriteToString(TJAXYWriteModeToXML(AWriteMode));
end;

end.
