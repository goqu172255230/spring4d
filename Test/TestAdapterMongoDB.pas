﻿unit TestAdapterMongoDB;

interface

uses
  TestFramework, Core.Interfaces, bsonDoc, Generics.Collections, MongoDB, Core.Base, SvSerializer,
  SysUtils, Mapping.Attributes, SQL.Params, Adapters.MongoDB, mongoId, Core.Session.MongoDB
  , SQL.Interfaces, MongoBson, Core.Repository.MongoDB, Spring.Collections, Rtti
  {$IF CompilerVersion > 21}
  ,Core.Repository.Proxy
  {$IFEND}

  ;

type

  [Table('MongoTest', 'UnitTests')]
  TMongoAdapter = class
  private
    FId: Int64;
    FKey: Int64;
    FName: string;
  public
    [Column('KEY')]
    property Key: Int64 read FKey write FKey;

    [Column('_id', [cpNotNull, cpPrimaryKey])]
    property Id: Int64 read FId write FId;

    [Column]
    property Name: string read FName write FName;
  end;

  [Table('AutoId', 'UnitTests')]
  TMongoAutogeneratedIdModel = class
  private
    FName: string;
    FId: Variant;
    FKey: TMongoAdapter;
  public
    constructor Create(); virtual;
    destructor Destroy; override;

    [Column]
    property Name: string read FName write FName;

    [Column('_id', [cpPrimaryKey])] [AutoGenerated]
    property Id: Variant read FId write FId;
    [Column('KEY')]
    property Key: TMongoAdapter read FKey write FKey;
  end;

  TPerson = class
  private
    FName: string;
  public
    constructor Create(); overload; virtual;
    constructor Create(const AName: string); overload; virtual;

    [Column]
    property Name: string read FName write FName;
  end;

  [Table('AutoId', 'UnitTests')]
  TMongoSubArrayModel = class(TMongoAutogeneratedIdModel)
  private
    FPersons: IList<TPerson>;
    FVersion: Integer;
  public
    constructor Create(); override;
    [Column]
    property Persons: IList<TPerson> read FPersons write FPersons;

    [Version]
    property Version: Integer read FVersion write FVersion;
  end;


  [Table('AutoId', 'UnitTests')]
  TMongoSubSimpleArrayModel = class(TMongoAutogeneratedIdModel)
  private
    FAges: IList<Integer>;
  public
    constructor Create(); override;
    [Column]
    property Ages: IList<Integer> read FAges write FAges;
  end;


  // Test methods for class TMongoResultSetAdapter
  TBaseMongoTest = class(TTestCase)
  private
    FConnection: TMongoDBConnection;
    FQuery: TMongoDBQuery;
    function GetKeyValue(const AValue: Variant): Variant;
  public
    procedure SetUp; override;
    procedure TearDown; override;

    property Connection: TMongoDBConnection read FConnection;
    property Query: TMongoDBQuery read FQuery write FQuery;
  end;


  TestTMongoResultSetAdapter = class(TBaseMongoTest)
  private
    FMongoResultSetAdapter: TMongoResultSetAdapter;
  protected
    procedure FetchValue(const AValue: Variant);
  public
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestIsEmpty;
    procedure TestIsEmpty_False;
    procedure TestNext;
    procedure TestGetFieldValue;
    procedure TestGetFieldValue1;
    procedure TestGetFieldCount;
    procedure TestGetFieldName;
  end;
  // Test methods for class TMongoStatementAdapter

  TestTMongoStatementAdapter = class(TBaseMongoTest)
  private
//    FConnection: TMongoDBConnection;
   // FQuery: TMongoDBQuery;
    FMongoStatementAdapter: TMongoStatementAdapter;
  public
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestSetSQLCommand;
    procedure TestSetParams;
    procedure TestExecute;
    procedure TestExecuteQuery;
  end;
  // Test methods for class TMongoConnectionAdapter

  TestTMongoConnectionAdapter = class(TTestCase)
  private
    FConnection: TMongoDBConnection;
    FMongoConnectionAdapter: TMongoConnectionAdapter;
  protected
    class constructor Create;
  public
    class var
      DirMongoDB: string;

    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestConnect;
    procedure TestDisconnect;
    procedure TestIsConnected;
    procedure TestCreateStatement;
    procedure TestBeginTransaction;
    procedure TestGetDriverName;
  end;

  TestMongoSession = class(TTestCase)
  private
    FConnection: IDBConnection;
    FMongoConnection: TMongoDBConnection;
    FManager: TMongoDBSession;
  public
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure First();
    procedure FindAll();
    procedure Save_Update_Delete();
    procedure Page();
    procedure AutogenerateId();
    procedure SubObjectArray();
    procedure SubSimpleArray();
    procedure RawQuery();
    procedure BulkInsert();
    procedure FindAndModify();
    procedure Versioning();
    procedure SimpleCriteria_Eq();
    procedure SimpleCriteria_In();
    procedure SimpleCriteria_Null();
    procedure SimpleCriteria_Between;
    procedure SimpleCriteria_Or();
    procedure SimpleCriteria_OrderBy();
    procedure SimpleCriteria_Like();
    procedure SimpleCriteria_Not();
    procedure Performance();
  end;

  TestMongoRepository = class(TTestCase)
  private
    FConnection: IDBConnection;
    FMongoConnection: TMongoDBConnection;
    FSession: TMongoDBSession;
    FRepository: IPagedRepository<TMongoAdapter, Integer>;
  public
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure InsertList();
    procedure Query();
  end;

  ICustomerRepository = interface(IPagedRepository<TMongoAdapter, Integer>)
    ['{DE23725D-8E4D-45FB-92C0-1FE4A8531C1C}']

    [Query('{"_id": 1}')]
    function CustomQuery(): IList<TMongoAdapter>;

    [Query('{"_id": 1}')]
    function CustomQueryReturnObject(): TMongoAdapter;

    [Query('{"_id": ?0}')]
    function CustomQueryWithArgumentReturnObject(AId: Integer): TMongoAdapter;

    [Query('{"Name": ?0}')]
    function CustomQueryWithStringArgumentReturnObject(AKey: string): TMongoAdapter;
  end;

  TestMongoProxyRepository = class(TBaseMongoTest)
  private
    FDBConnection: IDBConnection;
    FSession: TMongoDBSession;
    FProxyRepository: ICustomerRepository;
  public
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure DefaultMethod_Count();
    procedure DefaultMethod_Page();
    procedure DefaultMethod_FindOne();
    procedure DefaultMethod_FindAll();
    procedure DefaultMethod_Exists();
    procedure DefaultMethod_Insert();
    procedure DefaultMethod_InsertList();
    procedure DefaultMethod_Save();
    procedure DefaultMethod_SaveList();
    procedure DefaultMethod_SaveCascade();
    procedure DefaultMethod_Delete();
    procedure DefaultMethod_DeleteList();
    procedure DefaultMethod_Query();
    procedure DefaultMethod_Execute();
    procedure CustomMethod();
    procedure CustomMethod_ReturnObject();
    procedure CustomMethodWithArgument_ReturnObject();
    procedure CustomMethodWithStringArgument_ReturnObject();
  end;

implementation

uses
  Windows
  ,ShellAPI
  ,Forms
  ,Messages
  ,Core.ConnectionFactory
  ,Core.Exceptions
  ,Core.Criteria.Properties
  ,Core.Criteria.Restrictions
  ,Core.Session
  ,SQL.Generator.MongoDB
  ,Variants
  ,Diagnostics
  ;

const
  CT_KEY = 'KEY';
  NAME_COLLECTION = 'UnitTests.MongoTest';




procedure InsertObject(AConnection: TMongoDBConnection; const AValue: Variant; AID: Integer = 1; AName: string = '');
begin
  AConnection.Insert(NAME_COLLECTION, BSON([CT_KEY, AValue, '_id', AID, 'Name', AName]));
end;

procedure RemoveObject(AConnection: TMongoDBConnection; const AValue: Variant);
begin
  AConnection.remove(NAME_COLLECTION, BSON(['_id', 1]))
end;

procedure TestTMongoResultSetAdapter.FetchValue(const AValue: Variant);
var
  LDoc: IBSONDocument;
begin
  LDoc := BSON([CT_KEY, AValue]);
  FMongoResultSetAdapter.Document := LDoc;
  FQuery.query := FMongoResultSetAdapter.Document;
//  FQuery.Query(NAME_COLLECTION, FMongoResultSetAdapter.Document);
  FMongoResultSetAdapter.Next;
end;

procedure TestTMongoResultSetAdapter.SetUp;
begin
  inherited;
  FMongoResultSetAdapter := TMongoResultSetAdapter.Create(Query);
end;

procedure TestTMongoResultSetAdapter.TearDown;
begin
  FMongoResultSetAdapter.Free;
  FQuery := nil;
  inherited;
end;

procedure TestTMongoResultSetAdapter.TestIsEmpty;
begin
  Connection.find(NAME_COLLECTION, Query) ;
  CheckTrue(FMongoResultSetAdapter.IsEmpty);
end;

procedure TestTMongoResultSetAdapter.TestIsEmpty_False;
begin
  InsertObject(Connection, 10);
  Connection.find(NAME_COLLECTION, Query);
  CheckFalse(FMongoResultSetAdapter.IsEmpty);
end;

procedure TestTMongoResultSetAdapter.TestNext;
begin
  CheckTrue(FMongoResultSetAdapter.Next);
end;

procedure TestTMongoResultSetAdapter.TestGetFieldValue;
var
  ReturnValue: Variant;
  iValue: Integer;
begin
  iValue := Random(1000000);
  InsertObject(FConnection, iValue);
  try
    FetchValue(iValue);
    ReturnValue := FMongoResultSetAdapter.GetFieldValue(0);
    CheckEquals(iValue, Integer(ReturnValue));
  finally
    RemoveObject(FConnection, iValue);
  end;
end;

procedure TestTMongoResultSetAdapter.TestGetFieldValue1;
var
  ReturnValue: Variant;
  iValue: Integer;
begin
  iValue := Random(1000000);
  InsertObject(FConnection, iValue);
  try
    FetchValue(iValue);
    ReturnValue := FMongoResultSetAdapter.GetFieldValue(CT_KEY);
    CheckEquals(iValue, Integer(ReturnValue));
  finally
    RemoveObject(FConnection, iValue);
  end;
end;

procedure TestTMongoResultSetAdapter.TestGetFieldCount;
var
  ReturnValue: Integer;
  iValue: Integer;
begin
  ReturnValue := FMongoResultSetAdapter.GetFieldCount;
  CheckEquals(0, ReturnValue);
  iValue := Random(1000000);
  InsertObject(FConnection, iValue);
  try
    FetchValue(iValue);
    ReturnValue := FMongoResultSetAdapter.GetFieldCount;
    CheckEquals(1, ReturnValue);
  finally
    RemoveObject(FConnection, iValue);
  end;
end;

procedure TestTMongoResultSetAdapter.TestGetFieldName;
var
  ReturnValue: string;
  iValue: Integer;
begin
  iValue := Random(1000000);
  InsertObject(FConnection, iValue);
  try
    FetchValue(iValue);
    ReturnValue := FMongoResultSetAdapter.GetFieldName(0);
    CheckEqualsString(CT_KEY, ReturnValue);
  finally
    RemoveObject(FConnection, iValue);
  end;
end;

procedure TestTMongoStatementAdapter.SetUp;
begin
  inherited;
  FMongoStatementAdapter := TMongoStatementAdapter.Create(Query);
end;

procedure TestTMongoStatementAdapter.TearDown;
begin
  FMongoStatementAdapter.Free;
  FMongoStatementAdapter := nil;
  Connection.Free;
end;

procedure TestTMongoStatementAdapter.TestSetSQLCommand;
var
  LJson: string;
  LResult: Variant;
begin
  LJson := 'I[UnitTests.MongoTest]{"KEY": 1}';
  FMongoStatementAdapter.SetSQLCommand(LJson);
  FMongoStatementAdapter.Execute;

  LResult := GetKeyValue(1);
  CheckEquals(1, LResult);
end;

procedure TestTMongoStatementAdapter.TestSetParams;
begin
  // TODO: Setup method call parameters
//  FMongoStatementAdapter.SetParams(Params);
  // TODO: Validate method results
end;

procedure TestTMongoStatementAdapter.TestExecute;
var
  LJson: string;
  LResult: Variant;
begin
  LJson := 'I[UnitTests.MongoTest]{"KEY": 1}';
  FMongoStatementAdapter.SetSQLCommand(LJson);
  FMongoStatementAdapter.Execute;

  LResult := GetKeyValue(1);
  CheckEquals(1, LResult);
end;

procedure TestTMongoStatementAdapter.TestExecuteQuery;
var
  LJson: string;
  LResult: Variant;
  LResultset: IDBResultset;
begin
  LJson := 'I[UnitTests.MongoTest]{"KEY": 1}';
  FMongoStatementAdapter.SetSQLCommand(LJson);
  LResultset := FMongoStatementAdapter.ExecuteQuery;
  LResult := LResultset.GetFieldValue(0);
  CheckEquals(1, LResult);
end;

class constructor TestTMongoConnectionAdapter.Create;
begin
  DirMongoDB := 'D:\Downloads\Programming\General\NoSQL\mongodb-win32-i386-2.6.1\bin\';
end;

procedure TestTMongoConnectionAdapter.SetUp;
begin
  inherited;
  FConnection := TMongoDBConnection.Create('localhost');
  FConnection.Connected := True;
  FMongoConnectionAdapter := TMongoConnectionAdapter.Create(FConnection);
end;

procedure TestTMongoConnectionAdapter.TearDown;
begin
  FMongoConnectionAdapter.Free;
  FMongoConnectionAdapter := nil;
  FConnection.Free;
  inherited;
end;

procedure TestTMongoConnectionAdapter.TestConnect;
begin
  FMongoConnectionAdapter.Connect;
  CheckTrue(FMongoConnectionAdapter.IsConnected);
end;

procedure TestTMongoConnectionAdapter.TestDisconnect;
begin
  FMongoConnectionAdapter.Connect;
  CheckTrue(FMongoConnectionAdapter.IsConnected);
  FMongoConnectionAdapter.Disconnect;
  CheckFalse(FMongoConnectionAdapter.IsConnected);
end;

procedure TestTMongoConnectionAdapter.TestIsConnected;
begin
  FMongoConnectionAdapter.Connect;
  CheckTrue(FMongoConnectionAdapter.IsConnected);
  FMongoConnectionAdapter.Disconnect;
  CheckFalse(FMongoConnectionAdapter.IsConnected);
end;

procedure TestTMongoConnectionAdapter.TestCreateStatement;
var
  LStatement: IDBStatement;
begin
  LStatement := FMongoConnectionAdapter.CreateStatement;
  CheckTrue(Assigned(LStatement));
  LStatement := nil;
end;

procedure TestTMongoConnectionAdapter.TestBeginTransaction;
var
  LTran: IDBTransaction;
begin
  LTran := FMongoConnectionAdapter.BeginTransaction;
  CheckTrue(Assigned(LTran));
end;

procedure TestTMongoConnectionAdapter.TestGetDriverName;
var
  LDriverName: string;
begin
  LDriverName := FMongoConnectionAdapter.GetDriverName;
  CheckEquals('MongoDB', LDriverName);
end;

var
  sExecLine: string;
  StartInfo  : TStartupInfo;
  ProcInfo   : TProcessInformation;
  bCreated: Boolean;



{ TBaseMongoTest }

function TBaseMongoTest.GetKeyValue(const AValue: Variant): Variant;
var
  LDoc, LFound: IBSONDocument;
begin
  LDoc := BSON([CT_KEY, AValue]);
  LFound := FConnection.findOne(NAME_COLLECTION, LDoc);
  if Assigned(LFound) then
    Result := LFound.value(CT_KEY);
end;

procedure TBaseMongoTest.SetUp;
begin
  inherited;
  FConnection := TMongoDBConnection.Create('localhost');
  FConnection.Connected := True;
  FQuery := TMongoDBQuery.Create(FConnection);
  FConnection.drop(NAME_COLLECTION); //delete all
end;

procedure TBaseMongoTest.TearDown;
begin
  FQuery.Free;
  FConnection.Free;
  inherited;
end;

{ TestMongoSession }

procedure TestMongoSession.AutogenerateId;
var
  LModel: TMongoAutogeneratedIdModel;
  LModelSaved: TMongoAutogeneratedIdModel;
begin
  LModel := TMongoAutogeneratedIdModel.Create;
  LModelSaved := nil;
  try
    LModel.Name := 'Autogenerated';
    LModel.Key := TMongoAdapter.Create;
    LModel.Key.Key := 999;
    CheckTrue(VarIsEmpty(LModel.Id));
    FManager.Save(LModel);
    CheckFalse(VarIsEmpty(LModel.Id));


    LModelSaved := FManager.FindOne<TMongoAutogeneratedIdModel>(TValue.FromVariant(LModel.Id));
    CheckFalse(VarIsEmpty(LModelSaved.Id));
    CheckEquals('Autogenerated', LModelSaved.Name);
    CheckEquals(999, LModelSaved.Key.Key);
  finally
    LModel.Free;
    LModelSaved.Free;
  end;
end;

procedure TestMongoSession.SubObjectArray;
var
  LModel, LModelSaved: TMongoSubArrayModel;
begin
  LModel := TMongoSubArrayModel.Create;
  LModel.Name := 'SubArrayTest';
  LModel.Persons.Add(TPerson.Create('Foo'));
  LModel.Persons.Add(TPerson.Create('Bar'));

  FManager.Save(LModel);
  LModelSaved := FManager.FindOne<TMongoSubArrayModel>(TValue.FromVariant(LModel.Id));
  CheckEquals(2, LModelSaved.Persons.Count);
  CheckEquals('Foo', LModelSaved.Persons.First.Name);
  CheckEquals('Bar', LModelSaved.Persons.Last.Name);
  LModel.Free;
  LModelSaved.Free;
end;

procedure TestMongoSession.SubSimpleArray;
var
  LModel, LModelSaved: TMongoSubSimpleArrayModel;
begin
  LModel := TMongoSubSimpleArrayModel.Create;
  LModel.Name := 'SubArrayTest';
  LModel.Ages.Add(123);
  LModel.Ages.Add(999);

  FManager.Save(LModel);
  LModelSaved := FManager.FindOne<TMongoSubSimpleArrayModel>(TValue.FromVariant(LModel.Id));
  CheckEquals(2, LModelSaved.Ages.Count);
  CheckEquals(123, LModelSaved.Ages.First);
  CheckEquals(999, LModelSaved.Ages.Last);
  LModel.Free;
  LModelSaved.Free;
end;

procedure TestMongoSession.BulkInsert;
var
  LKeys: IList<TMongoAutogeneratedIdModel>;
  LKey: TMongoAutogeneratedIdModel;
  i, iSize: Integer;
  sw: TStopwatch;
begin
  LKeys := TCollections.CreateList<TMongoAutogeneratedIdModel>(True);
  iSize := 10000;
  sw :=TStopwatch.StartNew;
  for i := 1 to iSize do
  begin
    LKey := TMongoAutogeneratedIdModel.Create;
    LKey.Name := 'Name ' + IntToStr(i);
    LKeys.Add(LKey);
  end;

  FManager.BulkInsert<TMongoAutogeneratedIdModel>(LKeys);
  sw.Stop;
  LKeys := FManager.FindAll<TMongoAutogeneratedIdModel>;
  CheckEquals(iSize, LKeys.Count);
  Status(Format('Bulk insert of %d entities in %d ms', [iSize, sw.ElapsedMilliseconds]));
end;

procedure TestMongoSession.FindAndModify;
var
  LResultDoc, LDoc: IBsonDocument;
  LIter: IDBResultset;
  LValue: Variant;
  LIntf: IInterface;
  i: Integer;
begin
  LResultDoc := FMongoConnection.findAndModify('UnitTests.AutoId', BSON(['_id', 1, '_version', 0]), bsonEmpty
  , BSON(['$inc', BSON(['_version', 1])]), true);
  CheckNotNull(LResultDoc);
  LValue := LResultDoc['ok'];
  CheckEquals(1, LValue);
  LValue := LResultDoc['value'];

  LResultDoc := FMongoConnection.findAndModify('UnitTests.AutoId', BSON(['_id', 1, '_version', 1]), bsonEmpty
  , BSON(['$inc', BSON(['_version', 1])]), true);
  CheckNotNull(LResultDoc);
  LValue := LResultDoc['ok'];
  CheckEquals(1, LValue);
  LValue := LResultDoc['value'];
  LIntf := LValue;
  LIter := (LIntf as IDBResultset);
  while not LIter.IsEmpty do
  begin
    for i := 0 to LIter.GetFieldCount - 1 do
    begin
      Status(Format('"%S": %S', [LIter.GetFieldName(i), VarToStrDef(LIter.GetFieldValue(i), 'Null')]));
    end;
  end;

  LDoc := FMongoConnection.findAndModify('UnitTests.AutoId', BSON(['_id', 2, '_version', 1]), bsonEmpty
  , BSON(['$inc', BSON(['_version', 1])]), false);
  LValue := LDoc['value'];
  CheckTrue(VarIsNull(LValue));
end;

procedure TestMongoSession.FindAll;
var
  LKey: TMongoAdapter;
  LKeys: IList<TMongoAdapter>;
begin
  LKey := TMongoAdapter.Create;
  try
    LKey.Id := 1;
    LKey.Key := 100;

    FManager.Save(LKey);

    LKey.Id := 2;
    LKey.Key := 900;

    FManager.Save(LKey);

    LKeys := FManager.FindAll<TMongoAdapter>();
    CheckEquals(2, LKeys.Count);

    FManager.Delete(LKey);
    LKey.Id := 1;
    FManager.Delete(LKey);
  finally
    LKey.Free;
  end;
end;

procedure TestMongoSession.First;
var
  LKey: TMongoAdapter;
begin
  InsertObject(FMongoConnection, 100);
  LKey := nil;
  try
    LKey := FManager.FindOne<TMongoAdapter>(1);
    CheckEquals(100, LKey.Key);
  finally
    RemoveObject(FMongoConnection, 100);
    LKey.Free;
  end;
end;

procedure TestMongoSession.Page;
var
  LPage: IDBPage<TMongoAdapter>;
  LKey: TMongoAdapter;
begin
  LKey := TMongoAdapter.Create;
  try
    LKey.Id := 1;
    LKey.Key := 100;

    FManager.Save(LKey);

    LKey.Id := 2;
    LKey.Key := 900;

    FManager.Save(LKey);

    LPage := FManager.Page<TMongoAdapter>(1, 10);
    CheckEquals(2, LPage.Items.Count);
  finally
    FManager.Delete(LKey);
    LKey.Id := 1;
    FManager.Delete(LKey);
    LKey.Free;
  end;
end;

procedure TestMongoSession.Performance;
var
  LKey: TMongoAdapter;
  i, iCount: Integer;
  sw : TStopwatch;
begin
  FConnection.ClearExecutionListeners;
  iCount := 10000;
  sw := TStopwatch.StartNew;
  for i := 1 to iCount do
  begin
    LKey := TMongoAdapter.Create;
    try
      LKey.FId := i;
      LKey.Key := i + 1;
      FManager.Save(LKey);
    finally
      LKey.Free;
    end;
  end;
  sw.Stop;
  Status(Format('Saved %D simple entities in %D ms', [iCount, sw.ElapsedMilliseconds]));
end;

procedure TestMongoSession.RawQuery;
var
  LKeys: IList<TMongoAdapter>;
begin
  InsertObject(FMongoConnection, 123, 1);
  //FirstLetter - Operation (S - select, U - update, I - insert, D - delete)
  //[Namespace.Collection]
  //{json query}
  LKeys := FManager.GetList<TMongoAdapter>('S[UnitTests.MongoTest]{"KEY": 123}', []);
  CheckEquals(123, LKeys[0].Key);
  InsertObject(FMongoConnection, 124, 2);
  LKeys := FManager.GetList<TMongoAdapter>('S[UnitTests.MongoTest]{"KEY": {"$gt": 122} }', []);
  CheckEquals(2, LKeys.Count);
end;

procedure TestMongoSession.Save_Update_Delete;
var
  LKey: TMongoAdapter;
begin
  LKey := TMongoAdapter.Create();
  try
    LKey.FId := 2;
    LKey.Key := 100;

    FManager.Save(LKey);
    LKey.Free;

    LKey := FManager.FindOne<TMongoAdapter>(2);
    CheckEquals(100, LKey.Key);

    LKey.Key := 999;
    FManager.Save(LKey);
    LKey.Free;

    LKey := FManager.FindOne<TMongoAdapter>(2);
    CheckEquals(999, LKey.Key);


    FManager.Delete(LKey);
  finally
    LKey.Free;
  end;
  LKey := FManager.FindOne<TMongoAdapter>(2);
  CheckNull(LKey);
end;

procedure TestMongoSession.SetUp;
begin
  inherited;
  FMongoConnection := TMongoDBConnection.Create();
  FMongoConnection.Connected := True;
  FConnection := TConnectionFactory.GetInstance(dtMongo, FMongoConnection);
  FConnection.AutoFreeConnection := True;
  FConnection.SetQueryLanguage(qlMongoDB);
  FManager := TMongoDBSession.Create(FConnection);
  FManager.Execute('D[UnitTests.MongoTest]{}', []); //delete all
  FManager.Execute('D[UnitTests.AutoId]{}', []); //delete all
  {$WARNINGS OFF}
  if DebugHook <> 0 then
  begin
    FConnection.AddExecutionListener(
    procedure(const ACommand: string; const AParams: IList<TDBParam>)
    var
      i: Integer;
    begin
      Status(ACommand);
      for i := 0 to AParams.Count - 1 do
      begin
        if (VarType(AParams[i].Value) <> varUnknown) then
        begin
          Status(Format('%2:D Param %0:S = %1:S', [AParams[i].Name, VarToStrDef(AParams[i].Value, 'NULL'), i]));
        end;
      end;
      Status('-----');
    end);
  end;
  {$WARNINGS ON}
end;



procedure TestMongoSession.SimpleCriteria_Between;
var
  LCriteria: ICriteria<TMongoAdapter>;
  Key: IProperty;
  LKeys: IList<TMongoAdapter>;
begin
  InsertObject(FMongoConnection, 100, 1);
  LCriteria := FManager.CreateCriteria<TMongoAdapter>;
  Key := TProperty<TMongoAdapter>.ForName('KEY');

  LKeys := LCriteria.Add(Key.Between(1, 2)).ToList();
  CheckEquals(0, LKeys.Count, 'Between 0');

  LCriteria.Clear;

  LKeys := LCriteria.Add(Key.Between(99, 100)).ToList();
  CheckEquals(1, LKeys.Count, 'Between 1');
end;

procedure TestMongoSession.SimpleCriteria_Eq;
var
  LCriteria: ICriteria<TMongoAdapter>;
  Key: IProperty;
  LKeys: IList<TMongoAdapter>;
begin
  InsertObject(FMongoConnection, 100, 1);
  LCriteria := FManager.CreateCriteria<TMongoAdapter>;
  Key := TProperty<TMongoAdapter>.ForName('KEY');
  LKeys := LCriteria.Add(Key.Eq(100)).ToList();
  CheckEquals(1, LKeys.Count, 'Eq');

  LCriteria.Clear;
  LKeys := LCriteria.Add(Key.NotEq(100)).ToList();
  CheckEquals(0, LKeys.Count, 'Not Eq');

  LCriteria.Clear;
  LKeys := LCriteria.Add(Key.GEq(101)).ToList();
  CheckEquals(0, LKeys.Count, 'Greater Eq');

  LCriteria.Clear;
  LKeys := LCriteria.Add(Key.Gt(100)).ToList();
  CheckEquals(0, LKeys.Count, 'Greater Than');

  LCriteria.Clear;
  LKeys := LCriteria.Add(Key.Lt(100)).ToList();
  CheckEquals(0, LKeys.Count, 'Less Than');

  LCriteria.Clear;
  LKeys := LCriteria.Add(Key.LEq(100)).ToList();
  CheckEquals(1, LKeys.Count, 'Less Than or equals');
end;

procedure TestMongoSession.SimpleCriteria_In;
var
  LCriteria: ICriteria<TMongoAdapter>;
  Key: IProperty;
  LKeys: IList<TMongoAdapter>;
begin
  InsertObject(FMongoConnection, 100, 1);
  LCriteria := FManager.CreateCriteria<TMongoAdapter>;
  Key := TProperty<TMongoAdapter>.ForName('KEY');
  LKeys := LCriteria.Add(Key.InInt(TArray<Integer>.Create(100,1,2))).ToList();
  CheckEquals(1, LKeys.Count, 'In');

  LCriteria.Clear;
  LKeys := LCriteria.Add(Key.NotInInt(TArray<Integer>.Create(0,1,2))).ToList();
  CheckEquals(1, LKeys.Count, 'Not In');
end;

procedure TestMongoSession.SimpleCriteria_Like;
var
  LCriteria: ICriteria<TMongoAdapter>;
  Name: IProperty;
  LKeys: IList<TMongoAdapter>;
begin
  InsertObject(FMongoConnection, 100, 1, 'Foobar');
  LCriteria := FManager.CreateCriteria<TMongoAdapter>;
  Name := TProperty<TMongoAdapter>.ForName('Name');

  LKeys := LCriteria.Add(Name.NotLike('bar')).ToList();
  CheckEquals(0, LKeys.Count, 'Not Like');

  LCriteria.Clear;
  LKeys := LCriteria.Add(Name.Like('bar')).ToList();
  CheckEquals(1, LKeys.Count, 'Like');
end;

procedure TestMongoSession.SimpleCriteria_Not;
var
  LCriteria: ICriteria<TMongoAdapter>;
  Key: IProperty;
  LKeys: IList<TMongoAdapter>;
begin
  InsertObject(FMongoConnection, 100, 1);
  LCriteria := FManager.CreateCriteria<TMongoAdapter>;
  Key := TProperty<TMongoAdapter>.ForName('KEY');

  LKeys := LCriteria.Add(TRestrictions.&Not( Key.Eq(100))).ToList();
  CheckEquals(0, LKeys.Count, 'Not');
end;

procedure TestMongoSession.SimpleCriteria_Null;
var
  LCriteria: ICriteria<TMongoAdapter>;
  Key: IProperty;
  LKeys: IList<TMongoAdapter>;
begin
  InsertObject(FMongoConnection, Null, 1);
  LCriteria := FManager.CreateCriteria<TMongoAdapter>;
  Key := TProperty<TMongoAdapter>.ForName('KEY');
  LKeys := LCriteria.Add(Key.IsNotNull).ToList();
  CheckEquals(0, LKeys.Count, 'Not Null');

  LCriteria.Clear;
  LKeys := LCriteria.Add(Key.IsNull).ToList();
  CheckEquals(1, LKeys.Count, 'Is Null');
end;

procedure TestMongoSession.SimpleCriteria_Or;
var
  LCriteria: ICriteria<TMongoAdapter>;
  Key, Id: IProperty;
  LKeys: IList<TMongoAdapter>;
begin
  InsertObject(FMongoConnection, 999, 1);
  LCriteria := FManager.CreateCriteria<TMongoAdapter>;
  Key := TProperty<TMongoAdapter>.ForName('KEY');
  Id := TProperty<TMongoAdapter>.ForName('_id');

  LKeys := LCriteria.Add(TRestrictions.Or(Key.NotEq(999), Id.NotEq(1)) ).ToList();
  CheckEquals(0, LKeys.Count, 'Simple Or');
end;

procedure TestMongoSession.SimpleCriteria_OrderBy;
var
  LCriteria: ICriteria<TMongoAdapter>;
  Key: IProperty;
  LKeys: IList<TMongoAdapter>;
begin
  InsertObject(FMongoConnection, 999, 1);
  InsertObject(FMongoConnection, 1000, 2);
  LCriteria := FManager.CreateCriteria<TMongoAdapter>;
  Key := TProperty<TMongoAdapter>.ForName('KEY');

  LKeys := LCriteria.AddOrder(Key.Desc).ToList();
  CheckEquals(2, LKeys.Count);
  CheckEquals(1000, LKeys.First.Key);
  CheckEquals(999, LKeys.Last.Key);
end;

procedure TestMongoSession.TearDown;
begin
  inherited;
  FManager.Execute('D[UnitTests.MongoTest]{}', []); //delete all
  FManager.Execute('D[UnitTests.AutoId]{}', []); //delete all
  FManager.Free;
  FConnection := nil;
end;

procedure TestMongoSession.Versioning;
var
  LModel, LModelOld, LModelLoaded: TMongoSubArrayModel;
  bOk: Boolean;
begin
  LModel := TMongoSubArrayModel.Create;
  LModel.Name := 'Initial version';
  LModel.Version := 454; //doesnt matter what we set now
  FManager.Save(LModel);

  LModelLoaded := FManager.FindOne<TMongoSubArrayModel>(TValue.FromVariant(LModel.Id));
  CheckEquals(0, LModelLoaded.Version);
  LModelLoaded.Name := 'Updated version No. 1';

  LModelOld := FManager.FindOne<TMongoSubArrayModel>(TValue.FromVariant(LModel.Id));
  CheckEquals(0, LModelOld.Version);
  LModelOld.Name := 'Updated version No. 2';

  FManager.Save(LModelLoaded);
  CheckEquals(1, LModelLoaded.Version);

  try
    FManager.Save(LModelOld);
    bOk := False;
  except
    on E:EORMOptimisticLockException do
    begin
      bOk := True;
    end;
  end;
  CheckTrue(bOk, 'This should fail because version already changed to the same entity');

  LModel.Free;
  LModelLoaded.Free;
  LModelOld.Free;
end;

{ TestMongoRepository }

procedure TestMongoRepository.InsertList;
var
  LKeys: IList<TMongoAdapter>;
  LKey: TMongoAdapter;
  i, iSize: Integer;
begin
  LKeys := TCollections.CreateList<TMongoAdapter>(True);
  iSize := 100;
  for i := 1 to iSize do
  begin
    LKey := TMongoAdapter.Create;
    LKey.Id := i;
    LKey.Key := 1234;
    LKeys.Add(LKey);
  end;
  FRepository.Insert(LKeys);
  CheckEquals(iSize, FRepository.Count);
end;

procedure TestMongoRepository.Query;
var
  LKeys: IList<TMongoAdapter>;
begin
  InsertObject(FMongoConnection, 100, 1);
  InsertObject(FMongoConnection, 999, 2);

  LKeys := FRepository.Query('{_id: { $in: [1, 2] } }', []);
  CheckEquals(2, LKeys.Count);
end;

procedure TestMongoRepository.SetUp;
begin
  inherited;
  FMongoConnection := TMongoDBConnection.Create;
  FMongoConnection.Connected := True;
  FConnection := TConnectionFactory.GetInstance(dtMongo, FMongoConnection);
  FConnection.AutoFreeConnection := True;
  FConnection.SetQueryLanguage(qlMongoDB);
  FSession := TMongoDBSession.Create(FConnection);
  FSession.Execute('D[UnitTests.MongoTest]{}', []); //delete all
  FSession.Execute('D[UnitTests.AutoId]{}', []); //delete all
  FRepository := TMongoDBRepository<TMongoAdapter, Integer>.Create(FSession);
end;

procedure TestMongoRepository.TearDown;
begin
  FSession.Execute('D[UnitTests.MongoTest]{}', []); //delete all
  FSession.Execute('D[UnitTests.AutoId]{}', []); //delete all
  FSession.Free;
  FConnection := nil;
  inherited;
end;

{ TMongoAutogeneratedIdModel }

constructor TMongoAutogeneratedIdModel.Create;
begin
  inherited Create;
 // FKey := TMongoAdapter.Create;
end;

destructor TMongoAutogeneratedIdModel.Destroy;
begin
  FKey.Free;
  inherited;
end;

{ TMongoSubArrayModel }

constructor TMongoSubArrayModel.Create;
begin
  inherited;
  FPersons := TCollections.CreateObjectList<TPerson>();
end;

{ TPerson }

constructor TPerson.Create;
begin
  inherited;
end;

constructor TPerson.Create(const AName: string);
begin
  Create;
  FName := AName;
end;

{ TMongoSubSimpleArrayModel }

constructor TMongoSubSimpleArrayModel.Create;
begin
  inherited;
  FAges := TCollections.CreateList<Integer>;
end;

{ TestMongoProxyRepository }

procedure TestMongoProxyRepository.CustomMethod;
var
  LKeys: IList<TMongoAdapter>;
begin
  InsertObject(FConnection, 100, 1);

  LKeys := FProxyRepository.CustomQuery();
  CheckEquals(1, LKeys.Count);
end;

procedure TestMongoProxyRepository.CustomMethodWithArgument_ReturnObject;
var
  LModel: TMongoAdapter;
begin
  InsertObject(FConnection, 100, 1);
  LModel := FProxyRepository.CustomQueryWithArgumentReturnObject(1);
  CheckEquals(100, LModel.Key);
  LModel.Free;
end;

procedure TestMongoProxyRepository.CustomMethodWithStringArgument_ReturnObject;
var
  LModel: TMongoAdapter;
begin
  InsertObject(FConnection, 100, 1, 'Foo');
  LModel := FProxyRepository.CustomQueryWithStringArgumentReturnObject('Foo');
  CheckEquals(100, LModel.Key);
  CheckEquals('Foo', LModel.Name);
  LModel.Free;
end;

procedure TestMongoProxyRepository.CustomMethod_ReturnObject;
var
  LModel: TMongoAdapter;
begin
  InsertObject(FConnection, 100, 1);

  LModel := FProxyRepository.CustomQueryReturnObject();
  CheckEquals(100, LModel.Key);
  LModel.Free;
end;

procedure TestMongoProxyRepository.DefaultMethod_Count;
begin
  InsertObject(FConnection, 100, 1);

  CheckEquals(1, FProxyRepository.Count);
end;

procedure TestMongoProxyRepository.DefaultMethod_Delete;
var
  LModel: TMongoAdapter;
begin
  InsertObject(FConnection, 100, 1);
  LModel := TMongoAdapter.Create();
  LModel.Id := 1;
  LModel.Key := 100;
  FProxyRepository.Delete(LModel);
  CheckFalse(FProxyRepository.Exists(1));
  LModel.Free;
end;

procedure TestMongoProxyRepository.DefaultMethod_DeleteList;
var
  LModel: TMongoAdapter;
  LKeys: IList<TMongoAdapter>;
begin
  InsertObject(FConnection, 100, 1);
  LKeys := TCollections.CreateObjectList<TMongoAdapter>();
  LModel := TMongoAdapter.Create();
  LModel.Id := 1;
  LModel.Key := 100;
  LKeys.Add(LModel);
  FProxyRepository.Delete(LKeys);
  CheckFalse(FProxyRepository.Exists(1));
  InsertObject(FConnection, 100, 1);
  FProxyRepository.DeleteAll;
  CheckFalse(FProxyRepository.Exists(1));
end;

procedure TestMongoProxyRepository.DefaultMethod_Execute;
var
  LRes: NativeUInt;
begin
  LRes := FProxyRepository.Execute('I[UnitTests.MongoTest]{"KEY": ?$}', [1]);
  CheckEquals(1, LRes);
end;

procedure TestMongoProxyRepository.DefaultMethod_Exists;
begin
  InsertObject(FConnection, 100, 1);
  CheckTrue(FProxyRepository.Exists(1));
end;

procedure TestMongoProxyRepository.DefaultMethod_FindAll;
begin
  InsertObject(FConnection, 100, 1);
  CheckEquals(1, FProxyRepository.FindAll.Count);
end;

procedure TestMongoProxyRepository.DefaultMethod_FindOne;
var
  LModel: TMongoAdapter;
begin
  InsertObject(FConnection, 100, 1);
  LModel := FProxyRepository.FindOne(1);
  CheckEquals(100, LModel.Key);
  LModel.Free;
end;

procedure TestMongoProxyRepository.DefaultMethod_Insert;
var
  LModel: TMongoAdapter;
begin
  LModel := TMongoAdapter.Create();
  LModel.Id := 1;
  LModel.Key := 100;
  FProxyRepository.Insert(LModel);
  CheckTrue(FProxyRepository.Exists(1));
  LModel.Free;
end;

procedure TestMongoProxyRepository.DefaultMethod_InsertList;
var
  LModel: TMongoAdapter;
  LKeys: IList<TMongoAdapter>;
begin
  CheckFalse(FProxyRepository.Exists(1));
  LKeys := TCollections.CreateObjectList<TMongoAdapter>();
  LModel := TMongoAdapter.Create();
  LModel.Id := 1;
  LModel.Key := 100;
  LKeys.Add(LModel);

  FProxyRepository.Insert(LKeys);
  CheckTrue(FProxyRepository.Exists(1));
end;

procedure TestMongoProxyRepository.DefaultMethod_Page;
begin
  InsertObject(FConnection, 100, 1);
  CheckEquals(1, FProxyRepository.Page(1, 10).GetTotalItems);
end;

procedure TestMongoProxyRepository.DefaultMethod_Query;
var
  LKeys: IList<TMongoAdapter>;
begin
  LKeys := FProxyRepository.Query('{}', []);
  CheckEquals(0, LKeys.Count);
end;

procedure TestMongoProxyRepository.DefaultMethod_Save;
var
  LModel: TMongoAdapter;
begin
  LModel := TMongoAdapter.Create();
  LModel.Id := 1;
  LModel.Key := 100;
  LModel := FProxyRepository.Save(LModel);
  CheckTrue(FProxyRepository.Exists(1));
  LModel.Free;
end;

procedure TestMongoProxyRepository.DefaultMethod_SaveCascade;
var
  LModel: TMongoAdapter;
begin
  LModel := TMongoAdapter.Create();
  LModel.Id := 1;
  LModel.Key := 100;
  FProxyRepository.SaveCascade(LModel);
  CheckTrue(FProxyRepository.Exists(1));
  LModel.Free;
end;

procedure TestMongoProxyRepository.DefaultMethod_SaveList;
var
  LKeys: IList<TMongoAdapter>;
  LSavedKeys: ICollection<TMongoAdapter>;
  LModel: TMongoAdapter;
begin
  LKeys := TCollections.CreateObjectList<TMongoAdapter>();
  LModel := TMongoAdapter.Create();
  LModel.Id := 1;
  LModel.Key := 100;
  LKeys.Add(LModel);
  LSavedKeys := FProxyRepository.Save(LKeys);
  CheckTrue(FProxyRepository.Exists(1));
end;

procedure TestMongoProxyRepository.SetUp;
begin
  inherited;
  FDBConnection := TConnectionFactory.GetInstance(dtMongo, Connection);
  FDBConnection.SetQueryLanguage(qlMongoDB);
  FSession := TMongoDBSession.Create(FDBConnection);
  FProxyRepository := TProxyRepository<TMongoAdapter, Integer>.Create(FSession, TypeInfo(ICustomerRepository)
    , TMongoDBRepository<TMongoAdapter, Integer>) as ICustomerRepository;
end;

procedure TestMongoProxyRepository.TearDown;
begin
  FSession.Free;
  inherited;
end;

initialization
  if DirectoryExists(TestTMongoConnectionAdapter.DirMongoDB) then
  begin
    sExecLine := TestTMongoConnectionAdapter.DirMongoDB + 'mongod.exe' +
      Format(' --dbpath "%S" --journal', [TestTMongoConnectionAdapter.DirMongoDB + 'data\db']);

    FillChar(StartInfo,SizeOf(TStartupInfo),#0);
    FillChar(ProcInfo,SizeOf(TProcessInformation),#0);
    StartInfo.cb := SizeOf(TStartupInfo);
    StartInfo.wShowWindow := SW_HIDE;
    bCreated := CreateProcess(nil, PChar(sExecLine), nil, nil, True, 0, nil, nil, StartInfo, ProcInfo);
    if bCreated then
    begin
      RegisterTest(TestTMongoResultSetAdapter.Suite);
      RegisterTest(TestTMongoStatementAdapter.Suite);
      RegisterTest(TestTMongoConnectionAdapter.Suite);
      RegisterTest(TestMongoSession.Suite);
      RegisterTest(TestMongoRepository.Suite);
      {$IF CompilerVersion > 22}
      RegisterTest(TestMongoProxyRepository.Suite);
      {$IFEND}
    end;
  end;

finalization
  if bCreated then
  begin
    TerminateProcess(ProcInfo.hProcess, 0);
  end;


end.

