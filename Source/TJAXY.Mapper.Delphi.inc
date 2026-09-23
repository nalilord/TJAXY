{ Delphi RTTI mapper implementation. Included only by TJAXY.Core on Delphi. }

function TJAXYRTTIRecordToTJAXY(const AContext: TRttiContext; const AValue: TValue;
  ASeen: TList; ADepth: Integer): TTJAXYObject; forward;

function TJAXYRTTIIsStringKind(const AKind: TTypeKind): Boolean;
begin
  Result:=(AKind = tkString) OR (AKind = tkLString) OR (AKind = tkWString) OR
    (AKind = tkUString) OR (AKind = tkAnsiString) OR (AKind = tkUnicodeString);
end;

function TJAXYRTTIGetMemberValue(AObject: TTJAXYObject; const AName: String): TTJAXYValue;
var
  I: Integer;
begin
  Result:=nil;
  if NOT Assigned(AObject) then
    Exit;

  for I:=0 to AObject.Count - 1 do
    if SameText(AObject.Name[I], AName) then
      Exit(AObject.Item[I]);
end;

function TJAXYRTTIIsAccessible(AMember: TRttiMember): Boolean;
begin
  Result:=Ord(AMember.Visibility) >= 2;
end;

function TJAXYRTTIEnumToTJAXYName(ATypeInfo: PTypeInfo; const AName: String): String;
begin
  Result:=TJAXYApplyNameCase(TJAXYStripEnumPrefix(AName));
end;

function TJAXYRTTITJAXYNameToEnumValue(ATargetType: TRttiType; const AName: String): Integer;
var
  TypeData: PTypeData;
  I: Integer;
  RawName: String;
begin
  Result:=-1;

  if TTJAXYDocument.SerializerRules.EnumAcceptRawNameOnRead then
  begin
    Result:=GetEnumValue(ATargetType.Handle, AName);
    if Result >= 0 then
      Exit;
  end;

  TypeData:=GetTypeData(ATargetType.Handle);
  if TypeData = nil then
    Exit;

  for I:=TypeData^.MinValue to TypeData^.MaxValue do
  begin
    RawName:=GetEnumName(ATargetType.Handle, I);
    if SameText(TJAXYRTTIEnumToTJAXYName(ATargetType.Handle, RawName), AName) then
      Exit(I);
  end;
end;

function TJAXYRTTIToTJAXY(AObject: TObject; ASeen: TList; ADepth: Integer): TTJAXYObject; forward;
function TJAXYRTTISerializeValue(const AContext: TRttiContext; const AValue: TValue;
  ASeen: TList; ADepth: Integer): TTJAXYValue; forward;
function TJAXYRTTITJAXYToValue(const AContext: TRttiContext; ATargetType: TRttiType;
  ASource: TTJAXYValue; const APath: String): TValue; forward;
procedure TJAXYRTTIFromTJAXY(ATargetType: TRttiType; ATarget: TObject;
  ASource: TTJAXYObject; const APath: String); forward;

function TJAXYRTTISerializeValue(const AContext: TRttiContext; const AValue: TValue;
  ASeen: TList; ADepth: Integer): TTJAXYValue;
var
  I: Integer;
  Arr: TTJAXYArray;
  Raw: PByte;
  SetOrdinal: Int64;
  SetElementType: PTypeInfo;
  SetTypeData: PTypeData;
  SetMin, SetMax, SetBase, BitIndex: Integer;
begin
  if ADepth > 64 then
    raise ETJAXYException.Create('Object mapping exceeds 64 nesting levels');
  if AValue.IsEmpty then
    Exit(TTJAXYNull.Create);

  if TJAXYRTTIIsStringKind(AValue.Kind) then
    Exit(TTJAXYString.CreateFrom(AValue.AsString));

  case AValue.Kind of
    tkClass:
      if AValue.AsObject = nil then
        Result:=TTJAXYNull.Create
      else
        Result:=TJAXYRTTIToTJAXY(AValue.AsObject, ASeen, ADepth);
    tkRecord:
      Result:=TJAXYRTTIRecordToTJAXY(AContext, AValue, ASeen, ADepth);
    tkArray, tkDynArray:
    begin
      Arr:=TTJAXYArray.Create;
      try
        for I:=0 to AValue.GetArrayLength - 1 do
          Arr.Add(TJAXYRTTISerializeValue(AContext, AValue.GetArrayElement(I), ASeen, ADepth + 1));
        Result:=Arr;
      except
        Arr.Free;
        raise;
      end;
    end;
    tkChar, tkWideChar:
      if AValue.AsString <> '' then
        Result:=TTJAXYString.CreateFrom(AValue.AsString[1])
      else
        Result:=TTJAXYString.CreateFrom('');
    tkInteger:
      Result:=TTJAXYInteger.CreateFrom(AValue.AsOrdinal);
    tkInt64:
      Result:=TTJAXYInteger.CreateFrom(AValue.AsInt64);
    tkFloat:
      Result:=TTJAXYFloat.CreateFrom(AValue.AsExtended);
    tkEnumeration:
      if AValue.TypeInfo = TypeInfo(Boolean) then
        Result:=TTJAXYBoolean.CreateFrom(AValue.AsBoolean)
      else if TTJAXYDocument.SerializerRules.EnumMode = tjaxjemName then
        Result:=TTJAXYString.CreateFrom(TJAXYRTTIEnumToTJAXYName(AValue.TypeInfo, GetEnumName(AValue.TypeInfo, AValue.AsOrdinal)))
      else
        Result:=TTJAXYInteger.CreateFrom(AValue.AsOrdinal);
    tkSet:
    begin
      if AValue.DataSize > SizeOf(SetOrdinal) then
      begin
        SetTypeData:=GetTypeData(AValue.TypeInfo);
        if (SetTypeData = nil) OR (SetTypeData^.CompType = nil) then
          raise ETJAXYException.Create('Set element type information is unavailable');
        SetElementType:=SetTypeData^.CompType^;
        if SetElementType = nil then
          raise ETJAXYException.Create('Set element type is unavailable');
        SetMin:=GetTypeData(SetElementType)^.MinValue;
        SetMax:=GetTypeData(SetElementType)^.MaxValue;
        SetBase:=(SetMin div 8) * 8;
        Raw:=AValue.GetReferenceToRawData;
        Arr:=TTJAXYArray.Create;
        try
          for I:=SetMin to SetMax do
          begin
            BitIndex:=I - SetBase;
            if (BitIndex < 0) OR (BitIndex div 8 >= AValue.DataSize) then
              raise ETJAXYException.Create('Set element lies outside its storage');
            if (Raw[BitIndex div 8] AND (Byte(1) shl (BitIndex mod 8))) <> 0 then
              Arr.Add(TJAXYRTTIEnumToTJAXYName(SetElementType, GetEnumName(SetElementType, I)));
          end;
          Result:=Arr;
        except
          Arr.Free;
          raise;
        end;
        Exit;
      end;
      SetOrdinal:=0;
      Raw:=AValue.GetReferenceToRawData;
      if Assigned(Raw) then
      begin
        for I:=0 to AValue.DataSize - 1 do
        begin
          if I >= SizeOf(SetOrdinal) then
            Break;
          SetOrdinal:=SetOrdinal OR (Int64(Raw^) SHL (I * 8));
          Inc(Raw);
        end;
      end;
      Result:=TTJAXYInteger.CreateFrom(SetOrdinal);
    end;
    tkVariant:
      if VarIsNull(AValue.AsVariant) OR VarIsEmpty(AValue.AsVariant) then
        Result:=TTJAXYNull.Create
      else
        Result:=TTJAXYString.CreateFrom(VarToStr(AValue.AsVariant));
  else
    raise ETJAXYException.Create('Unsupported RTTI source type');
  end;
end;

function TJAXYRTTIToTJAXY(AObject: TObject; ASeen: TList; ADepth: Integer): TTJAXYObject;
var
  Context: TRttiContext;
  RType: TRttiType;
  Prop: TRttiProperty;
  Field: TRttiField;
  V: TTJAXYValue;
begin
  if Assigned(AObject) AND (ASeen.IndexOf(AObject) >= 0) then
    raise ETJAXYException.Create('Object mapping cycle detected');
  Result:=TTJAXYObject.Create;
  if NOT Assigned(AObject) then
    Exit;

  ASeen.Add(AObject);
  try
  try
    Context:=TRttiContext.Create;
    RType:=Context.GetType(AObject.ClassType);

    for Prop in RType.GetProperties do
    begin
      if (NOT TJAXYRTTIIsAccessible(Prop)) OR (NOT Prop.IsReadable) OR Result.HasKey(Prop.Name) then
        Continue;
      try
        V:=TJAXYRTTISerializeValue(Context, Prop.GetValue(AObject), ASeen, ADepth + 1);
        if Assigned(V) then
          Result.Add(Prop.Name, V);
      except
        on E: Exception do
          raise ETJAXYException.Create(Prop.Name + ': ' + E.Message);
      end;
    end;

    for Field in RType.GetFields do
    begin
      if (NOT TJAXYRTTIIsAccessible(Field)) OR Result.HasKey(Field.Name) then
        Continue;
      try
        V:=TJAXYRTTISerializeValue(Context, Field.GetValue(AObject), ASeen, ADepth + 1);
        Result.Add(Field.Name, V);
      except
        on E: Exception do
          raise ETJAXYException.Create(Field.Name + ': ' + E.Message);
      end;
    end;
  except
    Result.Free;
    raise;
  end;
  finally
    ASeen.Delete(ASeen.Count - 1);
  end;
end;

procedure TJAXYRTTIDeserializeArrayToValue(const AContext: TRttiContext; const ATargetType: TRttiType;
  var ATargetValue: TValue; ASource: TTJAXYArray; const APath: String);
var
  I: Integer;
  ArrayLen: Integer;
  ElemType: TRttiType;
  ElementValue: TValue;
begin
  if (ATargetType = nil) OR (NOT Assigned(ASource)) OR ATargetValue.IsEmpty then
    Exit;

  case ATargetType.TypeKind of
    tkArray: ElemType:=TRttiArrayType(ATargetType).ElementType;
    tkDynArray: ElemType:=TRttiDynamicArrayType(ATargetType).ElementType;
  else
    raise ETJAXYException.Create('Target is not an array');
  end;

  if NOT Assigned(ElemType) then
    raise ETJAXYException.Create('Array element type is unavailable');
  if ElemType.TypeKind = tkClass then
    raise ETJAXYException.Create('Arrays of class references require explicit ownership handling');

  ArrayLen:=ATargetValue.GetArrayLength;
  if ASource.Count > ArrayLen then
    raise ETJAXYException.Create('Array input exceeds target bounds');
  if ASource.Count < ArrayLen then
    ArrayLen:=ASource.Count;

  for I:=0 to ArrayLen - 1 do
  begin
    ElementValue:=TJAXYRTTITJAXYToValue(AContext, ElemType, ASource[I],
      APath + '[' + IntToStr(I) + ']');
    if NOT ElementValue.IsEmpty then
      ATargetValue.SetArrayElement(I, ElementValue);
  end;
end;

function TJAXYRTTITJAXYToValue(const AContext: TRttiContext; ATargetType: TRttiType;
  ASource: TTJAXYValue; const APath: String): TValue;
var
  LObj: TObject;
  LString: String;
  I: Integer;
  I64: Int64;
  Dbl: Extended;
  IObj: TRttiInstanceType;
  ArrValue: Pointer;
  ArrLen: NativeInt;
  FSingle: Single;
  FDouble: Double;
  FExtended: Extended;
  FCurrency: Currency;
  Ch: Char;
  AnsiCode: Byte;
  Scaled: Extended;
  VarValue: Variant;
  HasSetValue: Boolean;
  SetBytes: TBytes;
  SetElementType: PTypeInfo;
  SetTypeData: PTypeData;
  SetMin, SetMax, SetBase, BitIndex: Integer;
  SetName: String;
  RecordField: TRttiField;
  RecordSource: TTJAXYValue;
  RecordValue: TValue;
  OrdData: PTypeData;
  OrdMin, OrdMax: Int64;
begin
  Result:=TValue.Empty;
  if (ATargetType = nil) OR (NOT Assigned(ASource)) then
    Exit;
  if ATargetType.Handle = nil then
    raise ETJAXYException.Create('Target RTTI type information is unavailable');

  if TJAXYRTTIIsStringKind(ATargetType.TypeKind) then
  begin
    case ASource.Typ of
      tjaxytString: Result:=TValue.From<String>(ASource.AsString);
      tjaxytInteger: Result:=TValue.From<String>(IntToStr(ASource.AsInteger));
      tjaxytFloat: Result:=TValue.From<String>(FloatToStr(ASource.AsFloat, TJAXYFormatSettings));
      tjaxytBoolean: Result:=TValue.From<String>(BoolToStr(ASource.AsBoolean, True));
      tjaxytNull: Result:=TValue.From<String>('');
    else
      raise ETJAXYException.Create('Expected scalar string value');
    end;
    Exit;
  end;

  case ATargetType.TypeKind of
    tkInteger:
    begin
      case ASource.Typ of
        tjaxytInteger: I64:=ASource.AsInteger;
        tjaxytFloat:
          begin
            Dbl:=ASource.AsFloat;
            if (Dbl < Low(Int64)) OR (Dbl >= -Extended(Low(Int64))) OR (Frac(Dbl) <> 0) then
              raise ETJAXYException.Create('Integer conversion would overflow or truncate');
            I64:=Trunc(Dbl);
          end;
        tjaxytString:
          if NOT TryStrToInt64(Trim(ASource.AsString), I64) then
            raise ETJAXYException.Create('Invalid integer value');
      else
        raise ETJAXYException.Create('Expected integer value');
      end;
      OrdData:=GetTypeData(ATargetType.Handle);
      case OrdData^.OrdType of
        otSByte: begin OrdMin:=-128; OrdMax:=127; end;
        otUByte: begin OrdMin:=0; OrdMax:=255; end;
        otSWord: begin OrdMin:=-32768; OrdMax:=32767; end;
        otUWord: begin OrdMin:=0; OrdMax:=65535; end;
        otSLong: begin OrdMin:=Low(Integer); OrdMax:=High(Integer); end;
        otULong: begin OrdMin:=0; OrdMax:=High(Cardinal); end;
      else
        raise ETJAXYException.Create('Unsupported integer storage');
      end;
      if OrdData^.MinValue > OrdMin then
        OrdMin:=OrdData^.MinValue;
      if (OrdData^.MaxValue >= 0) AND (OrdData^.MaxValue < OrdMax) then
        OrdMax:=OrdData^.MaxValue;
      if (I64 < OrdMin) OR (I64 > OrdMax) then
        raise ETJAXYException.Create('Integer value is outside target range');
      Result:=TValue.FromOrdinal(ATargetType.Handle, I64);
    end;
    tkInt64:
    begin
      if ASource.Typ = tjaxytInteger then
        Result:=TValue.From<Int64>(ASource.AsInteger)
      else if ASource.Typ = tjaxytFloat then
      begin
        Dbl:=ASource.AsFloat;
        if (Dbl < Low(Int64)) OR (Dbl >= -Extended(Low(Int64))) OR (Frac(Dbl) <> 0) then
          raise ETJAXYException.Create('Int64 conversion would overflow or truncate');
        Result:=TValue.From<Int64>(Trunc(Dbl));
      end
      else if ASource.Typ = tjaxytString then
      begin
        if NOT TryStrToInt64(Trim(ASource.AsString), I64) then
          raise ETJAXYException.Create('Invalid Int64 value');
        Result:=TValue.From<Int64>(I64);
      end
      else
        raise ETJAXYException.Create('Expected Int64 value');
    end;
    tkFloat:
    begin
      if ASource.Typ = tjaxytInteger then
        Dbl:=ASource.AsInteger
      else if ASource.Typ = tjaxytFloat then
        Dbl:=ASource.AsFloat
      else if (ASource.Typ <> tjaxytString) OR
        (NOT TryStrToFloat(Trim(ASource.AsString), Dbl, TJAXYFormatSettings)) then
        raise ETJAXYException.Create('Invalid floating-point value');

      case GetTypeData(ATargetType.Handle)^.FloatType of
        ftSingle:
        begin
          if (Dbl > 3.4028234663852886E38) OR
            (Dbl < -3.4028234663852886E38) then
            raise ETJAXYException.Create('Single value is outside target range');
          FSingle:=Dbl;
          if (Dbl <> 0) AND (FSingle = 0) then
            raise ETJAXYException.Create('Single conversion would underflow');
          TValue.Make(@FSingle, ATargetType.Handle, Result);
        end;
        ftDouble:
        begin
          FDouble:=Dbl;
          TValue.Make(@FDouble, ATargetType.Handle, Result);
        end;
        ftExtended:
        begin
          FExtended:=Dbl;
          TValue.Make(@FExtended, ATargetType.Handle, Result);
        end;
        ftComp:
        begin
          if (Dbl < Low(Int64)) OR (Dbl >= -Extended(Low(Int64))) OR
            (Frac(Dbl) <> 0) then
            raise ETJAXYException.Create('Comp conversion would overflow or truncate');
          I64:=Trunc(Dbl);
          TValue.Make(@I64, ATargetType.Handle, Result);
        end;
        ftCurr:
        begin
          Scaled:=Dbl * 10000;
          if (Scaled < Low(Int64)) OR (Scaled >= -Extended(Low(Int64))) OR
            (Frac(Scaled) <> 0) then
            raise ETJAXYException.Create('Currency conversion would overflow or truncate');
          FCurrency:=Dbl;
          TValue.Make(@FCurrency, ATargetType.Handle, Result);
        end;
      end;
    end;
    tkChar, tkWideChar:
      if (ASource.Typ = tjaxytString) AND (Length(ASource.AsString) = 1) then
      begin
        Ch:=ASource.AsString[1];
        if ATargetType.TypeKind = tkChar then
        begin
          if Ord(Ch) > 255 then
            raise ETJAXYException.Create('Character is outside AnsiChar range');
          AnsiCode:=Ord(Ch);
          TValue.Make(@AnsiCode, ATargetType.Handle, Result);
        end
        else
          TValue.Make(@Ch, ATargetType.Handle, Result);
      end
      else
        raise ETJAXYException.Create('Expected one character');
    tkEnumeration:
    begin
      I:=-1;
      if ATargetType.Handle = TypeInfo(Boolean) then
      begin
        if ASource.Typ = tjaxytBoolean then
          Result:=TValue.From<Boolean>(ASource.AsBoolean)
        else if ASource.Typ = tjaxytInteger then
          Result:=TValue.From<Boolean>(ASource.AsInteger <> 0)
        else if ASource.Typ = tjaxytString then
        begin
          LString:=LowerCase(Trim(ASource.AsString));
          if LString = 'true' then
            Result:=TValue.From<Boolean>(True)
          else if LString = 'false' then
            Result:=TValue.From<Boolean>(False);
        end;
      end else
      begin
        if ASource.Typ = tjaxytString then
          I:=TJAXYRTTITJAXYNameToEnumValue(ATargetType, ASource.AsString)
        else if (ASource.Typ = tjaxytInteger) AND
          TTJAXYDocument.SerializerRules.EnumAcceptOrdinalOnRead then
        begin
          I64:=ASource.AsInteger;
          if (I64 >= GetTypeData(ATargetType.Handle)^.MinValue) AND
            (I64 <= GetTypeData(ATargetType.Handle)^.MaxValue) then
            I:=I64;
        end;

        if (I >= GetTypeData(ATargetType.Handle)^.MinValue) AND
          (I <= GetTypeData(ATargetType.Handle)^.MaxValue) then
          Result:=TValue.FromOrdinal(ATargetType.Handle, I)
        else
          case TTJAXYDocument.SerializerRules.EnumUnknownRead of
            tjaxjurDefaultFirst:
              Result:=TValue.FromOrdinal(ATargetType.Handle, GetTypeData(ATargetType.Handle)^.MinValue);
            tjaxjurRaise:
              raise ETJAXYException.Create(Format(RCS_INVALID_ENUM_VALUE, [ASource.AsString, ATargetType.Name]));
          end;
      end;
    end;
    tkSet:
    begin
      if ASource.Typ = tjaxytArray then
      begin
        SetTypeData:=GetTypeData(ATargetType.Handle);
        if (SetTypeData = nil) OR (SetTypeData^.CompType = nil) then
          raise ETJAXYException.Create('Set element type information is unavailable');
        SetElementType:=SetTypeData^.CompType^;
        if SetElementType = nil then
          raise ETJAXYException.Create('Set element type is unavailable');
        SetMin:=GetTypeData(SetElementType)^.MinValue;
        SetMax:=GetTypeData(SetElementType)^.MaxValue;
        SetBase:=(SetMin div 8) * 8;
        SetLength(SetBytes, ATargetType.TypeSize);
        if Length(SetBytes) = 0 then
          raise ETJAXYException.Create('Set storage is unavailable');
        for I:=0 to ASource.AsArray.Count - 1 do
        begin
          if NOT (ASource.AsArray[I] IS TTJAXYString) then
            raise ETJAXYException.Create('Set elements must be enum names');
          SetName:=ASource.AsArray[I].AsString;
          BitIndex:=TJAXYRTTITJAXYNameToEnumValue(AContext.GetType(SetElementType), SetName);
          if (BitIndex < SetMin) OR (BitIndex > SetMax) then
            raise ETJAXYException.Create('Unknown set element: ' + SetName);
          Dec(BitIndex, SetBase);
          if (BitIndex < 0) OR (BitIndex div 8 >= Length(SetBytes)) then
            raise ETJAXYException.Create('Set element lies outside its storage');
          SetBytes[BitIndex div 8]:=SetBytes[BitIndex div 8] OR (Byte(1) shl (BitIndex mod 8));
        end;
        TValue.Make(@SetBytes[0], ATargetType.Handle, Result);
        Exit;
      end;
      if ATargetType.TypeSize > SizeOf(I64) then
        raise ETJAXYException.Create('Large sets require enum-name arrays');
      HasSetValue:=False;
      if ASource.Typ = tjaxytString then
        HasSetValue:=TryStrToInt64(Trim(ASource.AsString), I64)
      else if ASource.Typ = tjaxytInteger then
      begin
        I64:=ASource.AsInteger;
        HasSetValue:=True;
      end;
      if HasSetValue then
      begin
        SetTypeData:=GetTypeData(ATargetType.Handle);
        if (SetTypeData = nil) OR (SetTypeData^.CompType = nil) then
          raise ETJAXYException.Create('Set element type information is unavailable');
        SetElementType:=SetTypeData^.CompType^;
        if SetElementType = nil then
          raise ETJAXYException.Create('Set element type is unavailable');
        SetMin:=GetTypeData(SetElementType)^.MinValue;
        SetMax:=GetTypeData(SetElementType)^.MaxValue;
        SetBase:=(SetMin div 8) * 8;
        for I:=0 to 63 do
          if ((UInt64(I64) shr I) AND 1) <> 0 then
            if (I >= ATargetType.TypeSize * 8) OR
              (SetBase + I < SetMin) OR (SetBase + I > SetMax) then
              raise ETJAXYException.Create('Set bit lies outside target range');
        TValue.Make(@I64, ATargetType.Handle, Result);
      end;
    end;
    tkVariant:
    begin
      case ASource.Typ of
        tjaxytNull: VarValue:=Null;
        tjaxytInteger: VarValue:=ASource.AsInteger;
        tjaxytFloat: VarValue:=ASource.AsFloat;
        tjaxytString: VarValue:=ASource.AsString;
        tjaxytBoolean: VarValue:=ASource.AsBoolean;
      else
        raise ETJAXYException.Create('Unsupported variant source type');
      end;
      Result:=TValue.FromVariant(VarValue);
    end;
    tkClass:
    begin
      if ASource.Typ = tjaxytNull then
      begin
        LObj:=nil;
        TValue.Make(@LObj, ATargetType.Handle, Result);
        Exit;
      end;
      if NOT (ATargetType IS TRttiInstanceType) then
        raise ETJAXYException.Create('Target is not a class instance type');
      IObj:=TRttiInstanceType(ATargetType);

      if IObj.MetaclassType.InheritsFrom(TTJAXYValue) then
      begin
        LObj:=ASource.Copy;
        if LObj.InheritsFrom(IObj.MetaclassType) then
          TValue.Make(@LObj, ATargetType.Handle, Result)
        else
        begin
          LObj.Free;
          raise ETJAXYException.Create('DOM node type does not match target class');
        end;
        Exit;
      end;

      if ASource.Typ <> tjaxytObject then
        raise ETJAXYException.Create('Expected object value');

      LObj:=TJAXYCreateRegisteredObject(IObj.MetaclassType);
      if LObj = nil then
        raise ETJAXYException.Create('No registered factory or existing instance for ' + ATargetType.Name);
      try
        TJAXYRTTIFromTJAXY(ATargetType, LObj, ASource.AsObject, APath);
        TValue.Make(@LObj, ATargetType.Handle, Result);
      except
        LObj.Free;
        raise;
      end;
    end;
    tkDynArray:
      if ASource.Typ = tjaxytArray then
      begin
        ArrLen:=ASource.AsArray.Count;
        ArrValue:=nil;
        try
          DynArraySetLength(ArrValue, ATargetType.Handle, 1, @ArrLen);
          TValue.Make(@ArrValue, ATargetType.Handle, Result);
          TJAXYRTTIDeserializeArrayToValue(AContext, ATargetType, Result, ASource.AsArray, APath);
        finally
          DynArrayClear(ArrValue, ATargetType.Handle);
        end;
      end;
    tkRecord:
      if ASource.Typ = tjaxytObject then
      begin
        TValue.Make(nil, ATargetType.Handle, Result);
        for RecordField in ATargetType.GetFields do
        begin
          if NOT TJAXYRTTIIsAccessible(RecordField) then
            Continue;
          RecordSource:=TJAXYRTTIGetMemberValue(ASource.AsObject, RecordField.Name);
          if RecordSource = nil then
            Continue;
          if (RecordField.FieldType.TypeKind = tkArray) AND (RecordSource IS TTJAXYArray) then
          begin
            RecordValue:=RecordField.GetValue(Result.GetReferenceToRawData);
            TJAXYRTTIDeserializeArrayToValue(AContext, RecordField.FieldType,
              RecordValue, RecordSource.AsArray, TJAXYMappingChildPath(APath, RecordField.Name));
          end
          else
            RecordValue:=TJAXYRTTITJAXYToValue(AContext, RecordField.FieldType,
              RecordSource, TJAXYMappingChildPath(APath, RecordField.Name));
          if (NOT RecordValue.IsEmpty) OR ((RecordField.FieldType.TypeKind = tkClass) AND RecordSource.IsNull) then
            RecordField.SetValue(Result.GetReferenceToRawData, RecordValue);
        end;
      end;
  end;
  if Result.IsEmpty then
  begin
    if (ATargetType.TypeKind = tkEnumeration) AND
      (TTJAXYDocument.SerializerRules.EnumUnknownRead = tjaxjurIgnore) then
      TJAXYAddMappingDiagnostic(APath, 'Unknown enum value ignored for ' + ATargetType.Name)
    else
      raise ETJAXYException.Create('Unsupported conversion to ' + ATargetType.Name);
  end;
end;

procedure TJAXYRTTIFromTJAXY(ATargetType: TRttiType; ATarget: TObject;
  ASource: TTJAXYObject; const APath: String);
var
  Context: TRttiContext;
  Prop: TRttiProperty;
  Field: TRttiField;
  Source: TTJAXYValue;
  NewValue: TValue;
  ExistingObject, CreatedObject, CurrentObject: TObject;
  MemberPath: String;
begin
  if (ATarget = nil) OR (ASource = nil) then
    Exit;

  Context:=TRttiContext.Create;
  for Prop in Context.GetType(ATarget.ClassType).GetProperties do
  begin
    if (NOT TJAXYRTTIIsAccessible(Prop)) OR (NOT Prop.IsWritable) OR (NOT Prop.IsReadable) then
      Continue;
    Source:=TJAXYRTTIGetMemberValue(ASource, Prop.Name);
    if Source = nil then
      Continue;
    MemberPath:=TJAXYMappingChildPath(APath, Prop.Name);
    try
      if (Prop.PropertyType.TypeKind = tkDynArray) AND (Source IS TTJAXYArray) then
      begin
        NewValue:=TJAXYRTTITJAXYToValue(Context, Prop.PropertyType, Source, MemberPath);
        if NOT NewValue.IsEmpty then
          Prop.SetValue(ATarget, NewValue);
      end
      else if (Prop.PropertyType.TypeKind = tkArray) AND (Source IS TTJAXYArray) then
      begin
        NewValue:=Prop.GetValue(ATarget);
        TJAXYRTTIDeserializeArrayToValue(Context, Prop.PropertyType,
          NewValue, Source.AsArray, MemberPath);
        Prop.SetValue(ATarget, NewValue);
      end
      else
      begin
        ExistingObject:=nil;
        if (Prop.PropertyType.TypeKind = tkClass) AND (Source IS TTJAXYObject) then
          ExistingObject:=Prop.GetValue(ATarget).AsObject;
        if ExistingObject <> nil then
          TJAXYRTTIFromTJAXY(Prop.PropertyType, ExistingObject, Source.AsObject, MemberPath)
        else
        begin
          NewValue:=TJAXYRTTITJAXYToValue(Context, Prop.PropertyType, Source, MemberPath);
          if (NOT NewValue.IsEmpty) OR ((Prop.PropertyType.TypeKind = tkClass) AND Source.IsNull) then
          begin
            CreatedObject:=nil;
            if (Prop.PropertyType.TypeKind = tkClass) AND (Source IS TTJAXYObject) then
              CreatedObject:=NewValue.AsObject;
            try
              Prop.SetValue(ATarget, NewValue);
            except
              if CreatedObject <> nil then
              begin
                CurrentObject:=CreatedObject;
                try
                  CurrentObject:=Prop.GetValue(ATarget).AsObject;
                except
                  { A failing getter cannot establish whether the setter kept the reference. }
                end;
                if CurrentObject <> CreatedObject then
                  CreatedObject.Free;
              end;
              raise;
            end;
          end;
        end;
      end;
    except
      on E: Exception do
        raise ETJAXYException.Create(Prop.Name + ': ' + E.Message);
    end;
  end;

  for Field in Context.GetType(ATarget.ClassType).GetFields do
  begin
    if NOT TJAXYRTTIIsAccessible(Field) then
      Continue;
    Source:=TJAXYRTTIGetMemberValue(ASource, Field.Name);
    if Source = nil then
      Continue;
    MemberPath:=TJAXYMappingChildPath(APath, Field.Name);
    try
      if (Field.FieldType.TypeKind = tkDynArray) AND (Source IS TTJAXYArray) then
      begin
        NewValue:=TJAXYRTTITJAXYToValue(Context, Field.FieldType, Source, MemberPath);
        if NOT NewValue.IsEmpty then
          Field.SetValue(ATarget, NewValue);
      end
      else if (Field.FieldType.TypeKind = tkArray) AND (Source IS TTJAXYArray) then
      begin
        NewValue:=Field.GetValue(ATarget);
        TJAXYRTTIDeserializeArrayToValue(Context, Field.FieldType,
          NewValue, Source.AsArray, MemberPath);
        Field.SetValue(ATarget, NewValue);
      end
      else
      begin
        ExistingObject:=nil;
        if (Field.FieldType.TypeKind = tkClass) AND (Source IS TTJAXYObject) then
          ExistingObject:=Field.GetValue(ATarget).AsObject;
        if ExistingObject <> nil then
          TJAXYRTTIFromTJAXY(Field.FieldType, ExistingObject, Source.AsObject, MemberPath)
        else
        begin
          NewValue:=TJAXYRTTITJAXYToValue(Context, Field.FieldType, Source, MemberPath);
          if (NOT NewValue.IsEmpty) OR ((Field.FieldType.TypeKind = tkClass) AND Source.IsNull) then
          begin
            CreatedObject:=nil;
            if (Field.FieldType.TypeKind = tkClass) AND (Source IS TTJAXYObject) then
              CreatedObject:=NewValue.AsObject;
            try
              Field.SetValue(ATarget, NewValue);
            except
              if CreatedObject <> nil then
              begin
                CurrentObject:=CreatedObject;
                try
                  CurrentObject:=Field.GetValue(ATarget).AsObject;
                except
                  { A failed readback leaves ownership with the caller. }
                end;
                if CurrentObject <> CreatedObject then
                  CreatedObject.Free;
              end;
              raise;
            end;
          end;
        end;
      end;
    except
      on E: Exception do
        raise ETJAXYException.Create(Field.Name + ': ' + E.Message);
    end;
  end;
end;

function TJAXYRTTIRecordToTJAXY(const AContext: TRttiContext; const AValue: TValue;
  ASeen: TList; ADepth: Integer): TTJAXYObject;
var
  RType: TRttiType;
  Field: TRttiField;
  V: TTJAXYValue;
begin
  if ADepth > 64 then
    raise ETJAXYException.Create('Object mapping exceeds 64 nesting levels');
  Result:=TTJAXYObject.Create;
  if AValue.IsEmpty then
    Exit;

  try
    RType:=AContext.GetType(AValue.TypeInfo);
    for Field in RType.GetFields do
    begin
      if NOT TJAXYRTTIIsAccessible(Field) then
        Continue;
      try
        V:=TJAXYRTTISerializeValue(AContext, Field.GetValue(AValue.GetReferenceToRawData), ASeen, ADepth + 1);
        if Assigned(V) then
          Result.Add(Field.Name, V);
      except
        on E: Exception do
          raise ETJAXYException.Create(Field.Name + ': ' + E.Message);
      end;
    end;
  except
    Result.Free;
    raise;
  end;
end;

procedure TJAXYRTTIRecordFromTJAXY(ATargetType: PTypeInfo; ARecord: Pointer; ASource: TTJAXYObject);
var
  Context: TRttiContext;
  RType: TRttiType;
  Field: TRttiField;
  Source: TTJAXYValue;
  NewValue: TValue;
begin
  if (ATargetType = nil) OR (ARecord = nil) OR (ASource = nil) then
    Exit;

  Context:=TRttiContext.Create;
  RType:=Context.GetType(PTypeInfo(ATargetType));

  for Field in RType.GetFields do
  begin
    if NOT TJAXYRTTIIsAccessible(Field) then
      Continue;
    Source:=TJAXYRTTIGetMemberValue(ASource, Field.Name);
    if Source = nil then
      Continue;
    try
      if (Field.FieldType.TypeKind = tkDynArray) AND (Source IS TTJAXYArray) then
      begin
        NewValue:=TJAXYRTTITJAXYToValue(Context, Field.FieldType, Source, Field.Name);
        if NOT NewValue.IsEmpty then
          Field.SetValue(ARecord, NewValue);
      end
      else if (Field.FieldType.TypeKind = tkArray) AND (Source IS TTJAXYArray) then
      begin
        NewValue:=Field.GetValue(ARecord);
        TJAXYRTTIDeserializeArrayToValue(Context, Field.FieldType,
          NewValue, Source.AsArray, Field.Name);
        Field.SetValue(ARecord, NewValue);
      end
      else
      begin
        NewValue:=TJAXYRTTITJAXYToValue(Context, Field.FieldType, Source, Field.Name);
        if (NOT NewValue.IsEmpty) OR ((Field.FieldType.TypeKind = tkClass) AND Source.IsNull) then
          Field.SetValue(ARecord, NewValue);
      end;
    except
      on E: Exception do
        raise ETJAXYException.Create(Field.Name + ': ' + E.Message);
    end;
  end;
end;


function TTJAXYDefaultMapper.Capabilities: TTJAXYMapperCapabilities;
begin
  Result:=[tjaxymcObjects, tjaxymcRecords, tjaxymcFactories];
end;

function TTJAXYDefaultMapper.SerializeObject(AObject: TObject): TTJAXYValue;
var
  Seen: TList;
begin
  Seen:=TList.Create;
  try
    Result:=TJAXYRTTIToTJAXY(AObject, Seen, 1);
  finally
    Seen.Free;
  end;
end;

procedure TTJAXYDefaultMapper.AssignObject(AObject: TObject; ASource: TTJAXYObject);
var
  Context: TRttiContext;
  TargetType: TRttiType;
begin
  Context:=TRttiContext.Create;
  TargetType:=Context.GetType(AObject.ClassType);
  if Assigned(TargetType) then
    TJAXYRTTIFromTJAXY(TargetType, AObject, ASource, '');
end;

function TTJAXYDefaultMapper.SerializeRecord(ATypeInfo, ARecord: Pointer): TTJAXYValue;
var
  Context: TRttiContext;
  RecordValue: TValue;
  Seen: TList;
begin
  if (ATypeInfo = nil) OR (ARecord = nil) then
    raise ETJAXYException.Create('Record type and value are required');
  TValue.Make(ARecord, PTypeInfo(ATypeInfo), RecordValue);
  Seen:=TList.Create;
  try
    Context:=TRttiContext.Create;
    Result:=TJAXYRTTIRecordToTJAXY(Context, RecordValue, Seen, 1);
  finally
    Seen.Free;
  end;
end;

procedure TTJAXYDefaultMapper.AssignRecord(ATypeInfo, ARecord: Pointer; ASource: TTJAXYObject);
begin
  TJAXYRTTIRecordFromTJAXY(PTypeInfo(ATypeInfo), ARecord, ASource);
end;

procedure TTJAXYDefaultMapper.RegisterFactory(AClass: TClass; AFactory: TTJAXYObjectFactory);
begin
  TJAXYRegisterFactoryDefault(AClass, AFactory);
end;

procedure TTJAXYDefaultMapper.UnregisterFactory(AClass: TClass);
begin
  TJAXYUnregisterFactoryDefault(AClass);
end;
