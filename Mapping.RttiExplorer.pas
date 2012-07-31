(*
* Copyright (c) 2012, Linas Naginionis
* Contacts: lnaginionis@gmail.com or support@soundvibe.net
* All rights reserved.
*
* Redistribution and use in source and binary forms, with or without
* modification, are permitted provided that the following conditions are met:
*     * Redistributions of source code must retain the above copyright
*       notice, this list of conditions and the following disclaimer.
*     * Redistributions in binary form must reproduce the above copyright
*       notice, this list of conditions and the following disclaimer in the
*       documentation and/or other materials provided with the distribution.
*     * Neither the name of the <organization> nor the
*       names of its contributors may be used to endorse or promote products
*       derived from this software without specific prior written permission.
*
* THIS SOFTWARE IS PROVIDED BY THE AUTHOR ''AS IS'' AND ANY
* EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
* WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
* DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
* DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
* (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
* LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
* ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
* (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
* SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*)
unit Mapping.RttiExplorer;

interface

uses
  Rtti, Generics.Collections, Mapping.Attributes;

type
  TValueHelper = record helper for TValue
  public
    function AsByte: Byte;
    function AsCardinal: Cardinal;
    function AsCurrency: Currency;
    function AsDate: TDate;
    function AsDateTime: TDateTime;
    function AsDouble: Double;
    function AsFloat: Extended;
    function AsPointer: Pointer;
    function AsShortInt: ShortInt;
    function AsSingle: Single;
    function AsSmallInt: SmallInt;
    function AsTime: TTime;
    function AsUInt64: UInt64;
    function AsWord: Word;
  
    function IsFloat: Boolean;
    function IsNumeric: Boolean;
    function IsPointer: Boolean;
    function IsString: Boolean;
    function IsInstance: Boolean;
    function IsInterface: Boolean;
    function IsBoolean: Boolean;
    function IsByte: Boolean;
    function IsCardinal: Boolean;
    function IsCurrency: Boolean;
    function IsDate: Boolean;
    function IsDateTime: Boolean;
    function IsDouble: Boolean;
    function IsInteger: Boolean;
    function IsInt64: Boolean;
    function IsShortInt: Boolean;
    function IsSingle: Boolean;
    function IsSmallInt: Boolean;
    function IsTime: Boolean;
    function IsUInt64: Boolean;
    function IsWord: Boolean;
    function IsVariant: Boolean;

    function IsSameAs(const AValue: TValue): Boolean;
  end;

  TRttiExplorer = class
  private
    class var FCtx: TRttiContext;
  public
    class function GetClassMembers<T: TORMAttribute>(AClass: TClass): TList<T>;
    class function GetClassAttribute<T: TORMAttribute>(AClass: TClass): T;
    class function GetTable(AClass: TClass): Table;
    class function GetUniqueConstraints(AClass: TClass): TList<UniqueConstraint>;
    class function GetAssociations(AClass: TClass): TList<Association>;
    class function GetColumns(AClass: TClass): TList<Column>;
    class function GetSequence(AClass: TClass): SequenceAttribute;
    class function HasSequence(AClass: TClass): Boolean;
    class function GetAutoGeneratedColumnMemberName(AClass: TClass): string;
    class function GetPrimaryKeyColumn(AClass: TClass): Column;
    class function GetPrimaryKeyColumnMemberName(AClass: TClass): string;
    class function GetPrimaryKeyColumnName(AClass: TClass): string;
    class function GetPrimaryKeyValue(AEntity: TObject): TValue;
    class function GetMemberValue(AEntity: TObject; const AMemberName: string): TValue; overload;
    class function GetMemberValue(AEntity: TObject; const AMember: TRttiMember): TValue; overload;
    class procedure SetMemberValue(AEntity: TObject; const AMemberName: string; const AValue: TValue); overload;
    class procedure SetMemberValue(AEntity: TObject; const AMemberColumn: Column; const AValue: TValue); overload;
    class function EntityChanged(AEntity1, AEntity2: TObject): Boolean;
    class function GetChangedMembers(AOriginalObj, ADirtyObj: TObject): TList<string>;
    class procedure CopyFieldValues(AEntityFrom, AEntityTo: TObject);
    class function Clone(AEntity: TObject): TObject;
  end;

implementation

uses
  Core.Exceptions,
  Math,
  TypInfo;

(*
  Copyright (c) 2011, Stefan Glienke
  All rights reserved.

  Redistribution and use in source and binary forms, with or without
  modification, are permitted provided that the following conditions are met:

  - Redistributions of source code must retain the above copyright notice,
    this list of conditions and the following disclaimer.
  - Redistributions in binary form must reproduce the above copyright notice,
    this list of conditions and the following disclaimer in the documentation
    and/or other materials provided with the distribution.
  - Neither the name of this library nor the names of its contributors may be
    used to endorse or promote products derived from this software without
    specific prior written permission.

  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
  POSSIBILITY OF SUCH DAMAGE.
*)  

function ValueIsEqual(const Left, Right: TValue): Boolean;
begin  
  if Left.IsNumeric and Right.IsNumeric then
  begin
    if Left.IsOrdinal then
    begin
      if Right.IsOrdinal then
      begin
        Result := Left.AsOrdinal = Right.AsOrdinal;
      end else
      if Right.IsSingle then
      begin
        Result := Math.SameValue(Left.AsOrdinal, Right.AsSingle);
      end else
      if Right.IsDouble then
      begin
        Result := Math.SameValue(Left.AsOrdinal, Right.AsDouble);
      end
      else
      begin
        Result := Math.SameValue(Left.AsOrdinal, Right.AsExtended);
      end;
    end else
    if Left.IsSingle then
    begin
      if Right.IsOrdinal then
      begin
        Result := Math.SameValue(Left.AsSingle, Right.AsOrdinal);
      end else
      if Right.IsSingle then
      begin
        Result := Math.SameValue(Left.AsSingle, Right.AsSingle);
      end else
      if Right.IsDouble then
      begin
        Result := Math.SameValue(Left.AsSingle, Right.AsDouble);
      end
      else
      begin
        Result := Math.SameValue(Left.AsSingle, Right.AsExtended);
      end;
    end else
    if Left.IsDouble then
    begin
      if Right.IsOrdinal then
      begin
        Result := Math.SameValue(Left.AsDouble, Right.AsOrdinal);
      end else
      if Right.IsSingle then
      begin
        Result := Math.SameValue(Left.AsDouble, Right.AsSingle);
      end else
      if Right.IsDouble then
      begin
        Result := Math.SameValue(Left.AsDouble, Right.AsDouble);
      end
      else
      begin
        Result := Math.SameValue(Left.AsDouble, Right.AsExtended);
      end;
    end
    else
    begin
      if Right.IsOrdinal then
      begin
        Result := Math.SameValue(Left.AsExtended, Right.AsOrdinal);
      end else
      if Right.IsSingle then
      begin
        Result := Math.SameValue(Left.AsExtended, Right.AsSingle);
      end else
      if Right.IsDouble then
      begin
        Result := Math.SameValue(Left.AsExtended, Right.AsDouble);
      end
      else
      begin
        Result := Math.SameValue(Left.AsExtended, Right.AsExtended);
      end;
    end;
  end else
  if Left.IsString and Right.IsString then
  begin
    Result := Left.AsString = Right.AsString;
  end else
  if Left.IsClass and Right.IsClass then
  begin
    Result := Left.AsClass = Right.AsClass;
  end else
  if Left.IsObject and Right.IsObject then
  begin
    Result := Left.AsObject = Right.AsObject;
  end else
  if Left.IsVariant and Right.IsVariant then
  begin
    Result := Left.AsVariant = Right.AsVariant;
  end else
  if Left.IsPointer and Right.IsPointer then
  begin
    Result := Left.AsPointer = Right.AsPointer;
  end else
  if Left.TypeInfo = Right.TypeInfo then
  begin
    Result := Left.AsPointer = Right.AsPointer;
  end else
  begin
    Result := False;
  end;
end;

{ TValueHelper }

function TValueHelper.AsByte: Byte;
begin
  Result := AsType<Byte>;
end;

function TValueHelper.AsCardinal: Cardinal;
begin
  Result := AsType<Cardinal>;
end;

function TValueHelper.AsCurrency: Currency;
begin
  Result := AsType<Currency>;
end;

function TValueHelper.AsDate: TDate;
begin
  Result := AsType<TDate>;
end;

function TValueHelper.AsDateTime: TDateTime;
begin
  Result := AsType<TDateTime>;
end;

function TValueHelper.AsDouble: Double;
begin
  Result := AsType<Double>;
end;

function TValueHelper.AsFloat: Extended;
begin
  Result := AsType<Extended>;
end;

function TValueHelper.AsPointer: Pointer;
begin
  Result := AsType<Pointer>;
end;

function TValueHelper.AsShortInt: ShortInt;
begin
  Result := AsType<ShortInt>;
end;

function TValueHelper.AsSingle: Single;
begin
  Result := AsType<Single>;
end;

function TValueHelper.AsSmallInt: SmallInt;
begin
  Result := AsType<SmallInt>;
end;

function TValueHelper.AsTime: TTime;
begin
  Result := AsType<TTime>;
end;

function TValueHelper.AsUInt64: UInt64;
begin
  Result := AsType<UInt64>;
end;

function TValueHelper.AsWord: Word;
begin
  Result := AsType<Word>;
end;

function TValueHelper.IsSameAs(const AValue: TValue): Boolean;
begin
  Result := ValueIsEqual(Self, AValue);
end;

function TValueHelper.IsBoolean: Boolean;
begin
  Result := TypeInfo = System.TypeInfo(Boolean);
end;

function TValueHelper.IsByte: Boolean;
begin
  Result := TypeInfo = System.TypeInfo(Byte);
end;

function TValueHelper.IsCardinal: Boolean;
begin
  Result := TypeInfo = System.TypeInfo(Cardinal);
  {$IFNDEF CPUX64}
  Result := Result or (TypeInfo = System.TypeInfo(NativeUInt));
  {$ENDIF}
end;

function TValueHelper.IsCurrency: Boolean;
begin
  Result := TypeInfo = System.TypeInfo(Currency);
end;

function TValueHelper.IsDate: Boolean;
begin
  Result := TypeInfo = System.TypeInfo(TDate);
end;

function TValueHelper.IsDateTime: Boolean;
begin
  Result := TypeInfo = System.TypeInfo(TDateTime);
end;

function TValueHelper.IsDouble: Boolean;
begin
  Result := TypeInfo = System.TypeInfo(Double);
end;

function TValueHelper.IsFloat: Boolean;
begin
  Result := TypeInfo = System.TypeInfo(Extended);
end;

function TValueHelper.IsInstance: Boolean;
begin
  Result := Kind in [tkClass, tkInterface];
end;

function TValueHelper.IsInt64: Boolean;
begin
  Result := TypeInfo = System.TypeInfo(Int64);
  {$IFDEF CPUX64}
  Result := Result or (TypeInfo = System.TypeInfo(NativeInt));
  {$ENDIF}
end;

function TValueHelper.IsInteger: Boolean;
begin
  Result := TypeInfo = System.TypeInfo(Integer);
  {$IFNDEF CPUX64}
  Result := Result or (TypeInfo = System.TypeInfo(NativeInt));
  {$ENDIF}
end;

function TValueHelper.IsInterface: Boolean;
begin
  Result := Assigned(TypeInfo) and (TypeInfo.Kind = tkInterface);
end;

function TValueHelper.IsNumeric: Boolean;
begin
  Result := Kind in [tkInteger, tkChar, tkEnumeration, tkFloat, tkWChar, tkInt64];
end;

function TValueHelper.IsPointer: Boolean;
begin
  Result := Kind = tkPointer;
end;

function TValueHelper.IsShortInt: Boolean;
begin
  Result := TypeInfo = System.TypeInfo(ShortInt);
end;

function TValueHelper.IsSingle: Boolean;
begin
  Result := TypeInfo = System.TypeInfo(Single);
end;

function TValueHelper.IsSmallInt: Boolean;
begin
  Result := TypeInfo = System.TypeInfo(SmallInt);
end;

function TValueHelper.IsString: Boolean;
begin
  Result := Kind in [tkChar, tkString, tkWChar, tkLString, tkWString, tkUString];
end;

function TValueHelper.IsTime: Boolean;
begin
  Result := TypeInfo = System.TypeInfo(TTime);
end;

function TValueHelper.IsUInt64: Boolean;
begin
  Result := TypeInfo = System.TypeInfo(UInt64);
  {$IFDEF CPUX64}
  Result := Result or (TypeInfo = System.TypeInfo(NativeInt));
  {$ENDIF}
end;

function TValueHelper.IsVariant: Boolean;
begin
  Result := TypeInfo = System.TypeInfo(Variant);
end;

function TValueHelper.IsWord: Boolean;
begin
  Result := TypeInfo = System.TypeInfo(Word);
end;

{ TRttiExplorer }

class function TRttiExplorer.Clone(AEntity: TObject): TObject;
begin
  Assert(Assigned(AEntity));

  Result := AEntity.ClassType.Create;
  CopyFieldValues(AEntity, Result);
end;

class procedure TRttiExplorer.CopyFieldValues(AEntityFrom, AEntityTo: TObject);
var
  LField: TRttiField;
  LType: TRttiType;
  LValue: TValue;
begin
  Assert(AEntityFrom.ClassType = AEntityTo.ClassType);
  Assert(Assigned(AEntityFrom) and Assigned(AEntityTo));

  LType := FCtx.GetType(AEntityFrom.ClassInfo);
  for LField in LType.GetFields do
  begin
    LValue := LField.GetValue(AEntityFrom);
    LField.SetValue(AEntityTo, LValue);
  end;
  {TODO -oLinas -cGeneral : what to do with properties? Should we need to write them too?}
end;

class function TRttiExplorer.EntityChanged(AEntity1, AEntity2: TObject): Boolean;
var
  LChangedMembers: TList<string>;
begin
  LChangedMembers := GetChangedMembers(AEntity1, AEntity2);
  try
    Result := (LChangedMembers.Count > 0);
  finally
    LChangedMembers.Free;
  end;
end;

class function TRttiExplorer.GetAssociations(AClass: TClass): TList<Association>;
begin
  Result := GetClassMembers<Association>(AClass);
end;

class function TRttiExplorer.GetAutoGeneratedColumnMemberName(AClass: TClass): string;
var
  LIds: TList<AutoGenerated>;
begin
  Result := '';

  LIds := GetClassMembers<AutoGenerated>(AClass);
  try
    if LIds.Count > 0 then
    begin
      Result := LIds.First.ClassMemberName;
    end;
  finally
    LIds.Free;
  end;
end;

class function TRttiExplorer.GetChangedMembers(AOriginalObj, ADirtyObj: TObject): TList<string>;
var
  LRttiType: TRttiType;
  LMember: TRttiMember;
  LOriginalValue, LDirtyValue: TValue;
  LCol: Column;
  LColumns: TList<Column>;
begin
  Assert(AOriginalObj.ClassType = ADirtyObj.ClassType);
  LRttiType := FCtx.GetType(AOriginalObj.ClassType);
  Result := TList<string>.Create;
  LColumns := GetColumns(AOriginalObj.ClassType);
  try
    for LCol in LColumns do
    begin
      if not LCol.IsDiscriminator then
      begin

        case LCol.MemberType of
          mtField:    LMember := LRttiType.GetField(LCol.ClassMemberName);
          mtProperty: LMember := LRttiType.GetProperty(LCol.ClassMemberName);
        else
          LMember := nil;
        end;

        if not Assigned(LMember) then
          raise EUnknownMember.Create('Unknown column member: ' + LCol.ClassMemberName);

        LOriginalValue := GetMemberValue(AOriginalObj, LMember);
        LDirtyValue := GetMemberValue(ADirtyObj, LMember);
        if not ValueIsEqual(LOriginalValue, LDirtyValue) then
          Result.Add(LMember.Name);
      end;
    end;
  finally
    LColumns.Free;
  end;
end;

class function TRttiExplorer.GetClassAttribute<T>(AClass: TClass): T;
var
  LAttr: TCustomAttribute;
  LTypeInfo: Pointer;
  LType: TRttiType;
begin
  LTypeInfo := TypeInfo(T);
  LType := FCtx.GetType(AClass);
  for LAttr in LType.GetAttributes do
  begin
    if (LAttr.ClassInfo = LTypeInfo) then
    begin
      Exit(T(LAttr));
    end;
  end;
  Result := nil;
end;

class function TRttiExplorer.GetClassMembers<T>(AClass: TClass): TList<T>;
var
  LType: TRttiType;
  LField: TRttiField;
  LProp: TRttiProperty;
  LAttr: TCustomAttribute;
  LTypeInfo: Pointer;
begin
  Result := TList<T>.Create;
  LType := FCtx.GetType(AClass);
  LTypeInfo := TypeInfo(T);
  for LField in LType.GetFields do
  begin
    for LAttr in LField.GetAttributes do
    begin
      if (LTypeInfo = LAttr.ClassInfo) then
      begin
        TORMAttribute(LAttr).MemberType := mtField;
        TORMAttribute(LAttr).ClassMemberName := LField.Name;
        Result.Add(T(LAttr));
      end;
    end;
  end;

  for LProp in LType.GetProperties do
  begin
    for LAttr in LProp.GetAttributes do
    begin
      if (LTypeInfo = LAttr.ClassInfo) then
      begin
        TORMAttribute(LAttr).MemberType := mtProperty;
        TORMAttribute(LAttr).ClassMemberName := LProp.Name;
        Result.Add(T(LAttr));
      end;
    end;
  end;
end;

class function TRttiExplorer.GetColumns(AClass: TClass): TList<Column>;
begin
  Result := GetClassMembers<Column>(AClass);
end;

class function TRttiExplorer.GetMemberValue(AEntity: TObject; const AMember: TRttiMember): TValue;
begin
  if AMember is TRttiField then
  begin
    Result := TRttiField(AMember).GetValue(AEntity);
  end
  else if AMember is TRttiProperty then
  begin
    Result := TRttiProperty(AMember).GetValue(AEntity); 
  end
  else
  begin
    Result := TValue.Empty;
  end;
end;

class function TRttiExplorer.GetPrimaryKeyColumn(AClass: TClass): Column;
var
  LColumns: TList<Column>;
  LCol: Column;
begin
  LColumns := GetColumns(AClass);
  try
    for LCol in LColumns do
    begin
      if (cpPrimaryKey in LCol.Properties) then
      begin
        Exit(LCol);
      end;
    end;
  finally
    LColumns.Free;
  end;
  Result := nil;
end;

class function TRttiExplorer.GetPrimaryKeyColumnMemberName(AClass: TClass): string;
var
  LCol: Column;
begin
  Result := '';

  LCol := GetPrimaryKeyColumn(AClass);
  if Assigned(LCol) then
  begin
    Result := LCol.ClassMemberName;
  end;
end;

class function TRttiExplorer.GetPrimaryKeyColumnName(AClass: TClass): string;
var
  LCol: Column;
begin
  Result := '';

  LCol := GetPrimaryKeyColumn(AClass);
  if Assigned(LCol) then
  begin
    Result := LCol.Name;
  end;
end;

class function TRttiExplorer.GetPrimaryKeyValue(AEntity: TObject): TValue;
begin
  Result := GetMemberValue(AEntity, GetPrimaryKeyColumnMemberName(AEntity.ClassType));
end;

class function TRttiExplorer.GetMemberValue(AEntity: TObject; const AMemberName: string): TValue;
var
  LField: TRttiField;
  LProp: TRttiProperty;
begin
  LField := FCtx.GetType(AEntity.ClassInfo).GetField(AMemberName);
  if Assigned(LField) then
  begin
    Result := LField.GetValue(AEntity);
    Exit;
  end;

  LProp := FCtx.GetType(AEntity.ClassInfo).GetProperty(AMemberName);
  if Assigned(LProp) then
  begin
    Result := LProp.GetValue(AEntity);
    Exit;
  end;

  Result := TValue.Empty;
end;

class function TRttiExplorer.GetSequence(AClass: TClass): SequenceAttribute;
begin
  Result := GetClassAttribute<SequenceAttribute>(AClass);
end;

class function TRttiExplorer.GetTable(AClass: TClass): Table;
begin
  Result := GetClassAttribute<Table>(AClass);
end;

class function TRttiExplorer.GetUniqueConstraints(AClass: TClass): TList<UniqueConstraint>;
begin
  Result := GetClassMembers<UniqueConstraint>(AClass);
end;

class function TRttiExplorer.HasSequence(AClass: TClass): Boolean;
begin
  Result := (GetSequence(AClass) <> System.Default(SequenceAttribute) );
end;

class procedure TRttiExplorer.SetMemberValue(AEntity: TObject; const AMemberColumn: Column;
  const AValue: TValue);
begin
  Assert(Assigned(AMemberColumn));
  SetMemberValue(AEntity, AMemberColumn.ClassMemberName, AValue);
end;

class procedure TRttiExplorer.SetMemberValue(AEntity: TObject; const AMemberName: string; const AValue: TValue);
var
  LField: TRttiField;
  LProp: TRttiProperty;
begin
  LField := FCtx.GetType(AEntity.ClassInfo).GetField(AMemberName);
  if Assigned(LField) then
  begin
    LField.SetValue(AEntity, AValue);
    Exit;
  end;

  LProp := FCtx.GetType(AEntity.ClassInfo).GetProperty(AMemberName);
  if Assigned(LProp) then
  begin
    LProp.SetValue(AEntity, AValue);
    Exit;
  end;
end;



end.
