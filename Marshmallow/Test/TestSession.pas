unit TestSession;

{$I sv.inc}
{.$DEFINE PERFORMANCE_TESTS}

interface

uses
  TestFramework,
  Classes,
{$IFDEF POSIX}
  Posix.Unistd,
{$ENDIF}
{$IFDEF MSWINDOWS}
  Windows,
{$ENDIF}
{$IFDEF FMX}
  FMX.Graphics,
{$ENDIF}
  SQLiteTable3,
  Spring.TestUtils,
  Spring.Collections,
  Spring.Persistence.Core.DetachedSession,
  Spring.Persistence.Core.Interfaces,
  Spring.Persistence.Core.Session,
  Spring.Persistence.SQL.Params;

type
  TMockSession = class(TSession)
  end;

  TSessionTest = class(TTestCase)
  protected
    FConnection: IDBConnection;
    FSession: TMockSession;
  protected
    function GenericCreate<T: class, constructor>: T;
    function SimpleCreate(AClass: TClass): TObject;
    function CreateConnection: IDBConnection; virtual;
    procedure TestExecutionListener(const command: string;
      const params: IEnumerable<TDBParam>);
    procedure TestQueryListener(Sender: TObject; const SQL: string);
  public
    procedure SetUp; override;
    procedure TearDown; override;

    class procedure InsertProducts(iCount: Integer);
  published
    procedure First;
    procedure Fetch;
    procedure Inheritance_Simple_Customer;
    procedure Insert;
    procedure InsertFromCollection;
    procedure Update;
    procedure Update_NotMapped;
    procedure Delete;
    procedure Save;
    procedure When_SaveAll_UpdateOneToMany;
    procedure When_SaveAll_InsertOneToMany;
    procedure When_SaveAll_DoNotSaveTransient;
    procedure When_FindAll_GetOneToMany;
    procedure SaveAll_ManyToOne;
    procedure ExecutionListeners;
    procedure Page;
    procedure ExecuteScalar;
    procedure Execute;
    procedure Nullable;
    procedure GetLazyValue;
    procedure GetLazyNullable;
    procedure FindOne;
    procedure FindWhere;
    procedure When_UnannotatedEntity_FindOne_ThrowException;
    procedure When_WithoutTableAttribute_FindOne_ThrowException;
    procedure When_WithoutPrimaryKey_FindOne_ThrowException;
    procedure FindAll;
    procedure Enums;
    procedure Streams;
    procedure ManyToOne;
    procedure ManyToMany;
    procedure Transactions;
    procedure Transactions_Nested;
    {$IFDEF PERFORMANCE_TESTS}
    procedure GetOne;
    procedure InsertList;
    {$ENDIF}
    procedure FetchCollection;
    procedure Versioning;
    procedure ListSession_Begin_Commit;
    procedure When_Lazy_Is_OneToMany;
    procedure When_Registered_RowMapper_And_FindOne_Make_Sure_Its_Used_On_TheSameType;
    procedure When_Registered_RowMapper_And_FindAll_Make_Sure_Its_Used_On_TheSameType;
    procedure When_Registered_RowMapper_And_GetList_Make_Sure_Its_Used_On_TheSameType;
    procedure When_Trying_To_Register_RowMapper_Again_For_The_Same_Type_Throw_Exception;
    procedure Can_Use_RowMapper_With_Unannotated_Entity;
    procedure Memoizer_Cache_Constructors;
  end;

  TDetachedSessionTest = class(TTestCase)
  private
    FConnection: IDBConnection;
    FSession: TDetachedSession;
  public
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure SaveAlwaysInsertsEntity;
    procedure Update;
    {$IFDEF PERFORMANCE_TESTS}
    procedure Performance;
    procedure Performance_RowMapper;
    {$ENDIF}
  end;

  TInsertData = record
    Age: Integer;
    Name: string;
    Height: Double;
    Picture: TStream;
  end;

var
  TestDB: TSQLiteDatabase = nil;

function InsertCustomer(AAge: Integer = 25; AName: string = 'Demo'; AHeight: Double = 15.25; APicture: TStream = nil): Variant;
function InsertCustomerOrder(ACustID: Integer; ACustPaymID: Integer; AOrderStatusCode: Integer; ATotalPrice: Double): Variant;
procedure ClearTable(const ATableName: string);
function GetTableRecordCount(const ATablename: string; AConnection: TSQLiteDatabase = nil; const OnQuery: THookQuery = nil): Int64;
function GetValueFromDB(const table, columnName, where: string): Variant;
function PrettyPrintVariant(const value: Variant): string;


implementation

uses
  Diagnostics,
  IOUtils,
  SysUtils,
  TypInfo,
  Variants,
  TestConsts,
  TestEntities,
  Spring,
  Spring.Persistence.Adapters.SQLite,
  Spring.Persistence.Core.ConnectionFactory,
  Spring.Persistence.Core.Exceptions,
  Spring.Persistence.Core.Graphics,
  Spring.Persistence.Criteria.Interfaces,
  Spring.Persistence.Criteria.Properties,
  Spring.Collections.Extensions,
  Spring.Persistence.Mapping.Attributes,
  Spring.Persistence.SQL.Register,
  Spring.Persistence.SQL.Types,
  Spring.Reflection;

const
  SQL_GET_ALL_CUSTOMERS = 'SELECT * FROM ' + TBL_PEOPLE + ';';

function GetPictureSize(const APicture: TPicture): Int64;
var
  LStream: TMemoryStream;
begin
  Result := 0;
  if Assigned(APicture) then
  begin
    LStream := TMemoryStream.Create;
    try
      APicture.Graphic.SaveToStream(LStream);

      Result := LStream.Size;
    finally
      LStream.Free;
    end;
  end;
end;

procedure CreateTables(const AConnection: TSQLiteDatabase = nil);
var
  LConn: TSQLiteDatabase;
begin
  if Assigned(AConnection) then
    LConn := AConnection
  else
    LConn := TestDB;

  LConn.ExecSQL('pragma foreign_keys=ON');

  LConn.ExecSQL('CREATE TABLE IF NOT EXISTS '+ TBL_PEOPLE + ' ([CUSTID] INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, [CUSTAGE] INTEGER NULL,'+
    '[CUSTNAME] VARCHAR (255), [CUSTHEIGHT] FLOAT, [LastEdited] DATETIME, [EMAIL] TEXT, [MIDDLENAME] TEXT, [AVATAR] BLOB, [AVATARLAZY] BLOB NULL'+
    ',[CUSTTYPE] INTEGER, [CUSTSTREAM] BLOB, [COUNTRY] TEXT );');

  LConn.ExecSQL('CREATE TABLE IF NOT EXISTS '+ TBL_ORDERS + ' ('+
    '"ORDER_ID" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,'+
    '"Customer_ID" INTEGER NOT NULL CONSTRAINT "FK_Customer_Orders" REFERENCES "Customers"("CUSTID") ON DELETE CASCADE ON UPDATE CASCADE,'+
    '"Customer_Payment_Method_Id" INTEGER,'+
    '"Order_Status_Code" INTEGER,'+
    '"Date_Order_Placed" DATETIME DEFAULT CURRENT_TIMESTAMP,'+
    '"Total_Order_Price" FLOAT) '+
    ';');

  LConn.ExecSQL('CREATE TABLE IF NOT EXISTS '+ TBL_PRODUCTS + ' ([PRODID] INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '+
    '[PRODNAME] VARCHAR (255), [PRODPRICE] FLOAT, [_version] INTEGER );');

  LConn.ExecSQL('CREATE TABLE IF NOT EXISTS User ([Id] INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '+
    '[Name] VARCHAR (255));');

  LConn.ExecSQL('CREATE TABLE IF NOT EXISTS Role ([Id] INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '+
    '[Description] VARCHAR (255));');

  LConn.ExecSQL('CREATE TABLE IF NOT EXISTS UserRole ([Id] INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '+
    '[UserId] INTEGER NOT NULL CONSTRAINT "FK_UserRole_Users" REFERENCES "User"("Id") ON DELETE CASCADE ON UPDATE CASCADE, '+
    '[RoleId] INTEGER NOT NULL CONSTRAINT "FK_UserRole_Roles" REFERENCES "Role"("Id") ON DELETE CASCADE ON UPDATE CASCADE, '+
    '[AssignedDate] DATETIME DEFAULT CURRENT_TIMESTAMP);');    

  if not LConn.TableExists(TBL_PEOPLE) then
    raise Exception.Create('Table CUSTOMERS does not exist');
end;

function InsertCustomer(AAge: Integer = 25; AName: string = 'Demo'; AHeight: Double = 15.25; APicture: TStream = nil): Variant;
begin
  TestDB.ExecSQL('INSERT INTO  ' + TBL_PEOPLE + ' (['+CUSTAGE+'], ['+CUSTNAME+'], ['+CUSTHEIGHT+']) VALUES (?,?,?);',
    [AAge, AName, AHeight]);
  Result := TestDB.GetLastInsertRowID;
end;

procedure InsertCustomerEnum(AType: Integer; AAge: Integer = 25; AName: string = 'Demo'; AHeight: Double = 15.25);
begin
  TestDB.ExecSQL('INSERT INTO  ' + TBL_PEOPLE + ' (['+CUSTAGE+'], ['+CUSTNAME+'], ['+CUSTHEIGHT+'], ['+CUSTTYPE+']) VALUES (?,?,?,?);',
    [AAge, AName, AHeight, AType]);
end;

procedure InsertCustomerNullable(AAge: Integer = 25; AName: string = 'Demo'; AHeight: Double = 15.25; const AMiddleName: string = ''; APicture: TStream = nil);
begin
  TestDB.ExecSQL('INSERT INTO  ' + TBL_PEOPLE + ' (['+CUSTAGE+'], ['+CUSTNAME+'], ['+CUSTHEIGHT+'], ['+CUST_MIDDLENAME+']) VALUES (?,?,?,?);',
    [AAge, AName, AHeight, AMiddleName]);
end;

procedure InsertCustomerAvatar(AAge: Integer = 25; AName: string = 'Demo'; AHeight: Double = 15.25; const AMiddleName: string = ''; APicture: TStream = nil);
var
  LRows: Integer;
begin
  TestDB.ExecSQL('INSERT INTO  ' + TBL_PEOPLE + ' (['+CUSTAGE+'], ['+CUSTNAME+'], ['+CUSTHEIGHT+'], ['+CUST_MIDDLENAME+'], ['+CUSTAVATAR+'], ['+CUSTAVATAR_LAZY+']) VALUES (?,?,?,?,?,?);',
    [AAge, AName, AHeight, AMiddleName, APicture, APicture], LRows);
  if LRows < 1 then
    raise Exception.Create('Cannot insert into table');
end;

function InsertCustomerOrder(ACustID: Integer; ACustPaymID: Integer; AOrderStatusCode: Integer; ATotalPrice: Double): Variant;
begin
  TestDB.ExecSQL('INSERT INTO  ' + TBL_ORDERS + ' ([Customer_Id], [Customer_Payment_Method_Id], [Order_Status_Code], [Total_Order_Price]) '+
    ' VALUES (?,?,?,?);',
    [ACustID, ACustPaymID, AOrderStatusCode, ATotalPrice]);
  Result := TestDB.GetLastInsertRowID;
end;

function InsertProduct(const AName: string = 'Product'; APrice: Double = 1.99): Variant;
begin
  TestDB.ExecSQL('INSERT INTO  ' + TBL_PRODUCTS + ' (['+PRODNAME+'], ['+PRODPRICE+']) VALUES (?,?);',
    [AName, APrice]);
  Result := TestDB.GetLastInsertRowID;
end;

procedure ClearTable(const ATableName: string);
begin
  TestDB.ExecSQL('DELETE FROM ' + ATableName + ';');
end;

function GetDBValue(const ASql: string): Variant;
begin
  Result := TestDB.GetUniTableIntf(ASql).Fields[0].Value;
end;

function GetValueFromDB(const table, columnName, where: string): Variant;
begin
  Result := TestDB.GetUniTableIntf(Format('select %s from %s where %s', [columnName, table, where])).Fields[0].Value;
end;

function GetTableRecordCount(const ATablename: string; AConnection: TSQLiteDatabase = nil; const OnQuery: THookQuery = nil): Int64;
var
  LConn: TSQLiteDatabase;
  LTable: ISQLiteTable;
  LField: TSQLiteField;
begin
  if Assigned(AConnection) then
  begin
    LConn := TSQLiteDatabase.Create(AConnection.Filename);
    try
      LConn.OnQuery := OnQuery;
      LTable := LConn.GetUniTableIntf('SELECT COUNT(*) FROM ' + ATablename);
      LField := LTable.Fields[0];
      Result := LField.Value;
      // Cleanup all sqlite statements and handles
{$IFDEF AUTOREFCOUNT}
      LField := nil;
{$ENDIF}
      LTable := nil;
    finally
      LConn.Free;
    end;
  end
  else
    Result := GetDBValue('SELECT COUNT(*) FROM ' + ATablename);
end;

type
  TMemoize = class
  public
    class function Memoize<T,R>(const func: TFunc<T, R>): TFunc<T,R>; overload;
  end;

{ TMemoize }

class function TMemoize.Memoize<T, R>(const func: TFunc<T, R>): TFunc<T, R>;
var
  cache: IDictionary<T,R>;
begin
  cache := TCollections.CreateDictionary<T,R>;
  Result := function(arg: T): R
    begin
      if not cache.TryGetValue(arg, Result) then
      begin
        Result := func(arg);
        cache.AddOrSetValue(arg, Result);
      end;
    end;
end;

type
  TUnannotatedProduct = class
  private
    FID: Integer;
    FName: string;
    FPrice: Double;
  public
    property ID: Integer read FID write FID;
    property Name: string read FName write FName;
    property Price: Double read FPrice write FPrice;
  end;

  TUnannotatedProductRowMapper = class(TInterfacedObject, IRowMapper<TUnannotatedProduct>)
  protected
    function MapRow(const resultSet: IDBResultSet): TUnannotatedProduct;
  end;

  { TUnnanotatedProductRowMapper }

  function TUnannotatedProductRowMapper.MapRow(const resultSet: IDBResultSet): TUnannotatedProduct;
  begin
    Result := TUnannotatedProduct.Create;
    Result.ID := resultSet.GetFieldValue('PRODID');
    Result.Name := resultSet.GetFieldValue('PRODNAME');
    Result.Price := resultSet.GetFieldValue('PRODPRICE');
  end;

procedure TSessionTest.Can_Use_RowMapper_With_Unannotated_Entity;
var
  id: Integer;
  product: TUnannotatedProduct;
begin
  FSession.RegisterRowMapper<TUnannotatedProduct>(TUnannotatedProductRowMapper.Create);
  id := InsertProduct('Bread', 0.99);

  product := FSession.Single<TUnannotatedProduct>('select * from '+ TBL_PRODUCTS +' where PRODID = :0', [id]);
  CheckEquals(id, product.ID, 'Primary key should be equal');
  CheckEquals('Bread', product.Name, 'Name should be equal');
  CheckEquals(0.99, product.Price, 0.01, 'Price should be equal');
  product.Free;
end;

function TSessionTest.CreateConnection: IDBConnection;
begin
  Result := TConnectionFactory.GetInstance(dtSQLite, TestDB);
end;

procedure TSessionTest.Delete;
var
  LCustomer: TCustomer;
  sSql: string;
  LResults: ISQLiteTable;
begin
  sSql := 'select * from ' + TBL_PEOPLE;

  InsertCustomer;

  LCustomer := FSession.FirstOrDefault<TCustomer>(sSql, []);
  try
    CheckEquals(25, LCustomer.Age);

    FSession.Delete(LCustomer);

    LResults := TestDB.GetUniTableIntf('SELECT COUNT(*) FROM ' + TBL_PEOPLE);
    CheckEquals(0, LResults.Fields[0].AsInteger);

  finally
    LCustomer.Free;
  end;

  //try insert after deletion
  LCustomer := TCustomer.Create;
  try
    LCustomer.Name := 'Inserted';

    FSession.Save(LCustomer);

    LResults := TestDB.GetUniTableIntf('SELECT COUNT(*) FROM ' + TBL_PEOPLE);
    CheckEquals(1, LResults.Fields[0].AsInteger);

  finally
    LCustomer.Free;
  end;
end;

const
  SQL_EXEC_SCALAR = 'SELECT COUNT(*) FROM ' + TBL_PEOPLE + ';';

procedure TSessionTest.Enums;
var
  LCustomer: TCustomer;
  iLastID: Integer;
  LVal: Variant;
begin
  InsertCustomer;
  iLastID := TestDB.GetLastInsertRowID;
  LCustomer := FSession.FindOne<TCustomer>(iLastID);
  try
    CheckTrue(ctOneTime = LCustomer.CustomerType);
  finally
    LCustomer.Free;
  end;

  InsertCustomerEnum(Ord(ctBusinessClass));
  iLastID := TestDB.GetLastInsertRowID;
  LCustomer := FSession.FindOne<TCustomer>(iLastID);
  try
    CheckTrue(ctBusinessClass = LCustomer.CustomerType);

    LCustomer.CustomerType := ctReturning;
    FSession.Save(LCustomer);
    LVal := GetDBValue(Format('select custtype from ' + TBL_PEOPLE + ' where custid = %D', [iLastID]));
    CheckTrue(Integer(LVal) = Ord(ctReturning));
  finally
    LCustomer.Free;
  end;

  InsertCustomerEnum(20);
  iLastID := TestDB.GetLastInsertRowID;
  LCustomer := FSession.FindOne<TCustomer>(iLastID);
  try
    CheckTrue(20 = Ord(LCustomer.CustomerType));
  finally
    LCustomer.Free;
  end;
end;

procedure TSessionTest.Execute;
begin
  FSession.Execute('INSERT INTO CUSTOMERS SELECT * FROM CUSTOMERS;', []);
  Pass;
end;

const
  SQL_EXEC_SCALAR_DOUBLE = 'SELECT CAST( COUNT(*) AS TEXT) FROM ' + TBL_PEOPLE + ';';

procedure TSessionTest.ExecuteScalar;
var
  LRes: Integer;
  LResDouble: Double;
begin
  LRes := FSession.ExecuteScalar<Integer>(SQL_EXEC_SCALAR, []);
  CheckEquals(0, LRes);
  InsertCustomer;
  LRes := FSession.ExecuteScalar<Integer>(SQL_EXEC_SCALAR, []);
  CheckEquals(1, LRes);
  LResDouble := FSession.ExecuteScalar<Double>(SQL_EXEC_SCALAR_DOUBLE, []);
  CheckEquals(1, LResDouble, 0.1);
end;

procedure TSessionTest.ExecutionListeners;
var
  sLog, sLog2, sSql: string;
  iParamCount1, iParamCount2: Integer;
  LCustomer: TCustomer;
begin
  sLog := '';
  sLog2 := '';
  FConnection.AddExecutionListener(
    procedure(const command: string; const params: IEnumerable<TDBParam>)
    begin
      sLog := command;
      iParamCount1 := params.Count;
    end);

  FConnection.AddExecutionListener(
    procedure(const command: string; const params: IEnumerable<TDBParam>)
    begin
      sLog2 := command;
      iParamCount2 := params.Count;
    end);

  InsertCustomer;
  sSql := 'select * from ' + TBL_PEOPLE;
  LCustomer := FSession.FirstOrDefault<TCustomer>(sSql, []);
  try
    CheckTrue(sLog <> '');
    CheckTrue(sLog2 <> '');
    CheckEqualsString(sLog, sLog2);
    CheckEquals(0, iParamCount1);
    CheckEquals(0, iParamCount2);

    LCustomer.Name := 'Execution Listener test';
    LCustomer.Age := 58;

    sLog := '';
    sLog2 := '';

    FSession.Update(LCustomer);

    CheckTrue(sLog <> '');
    CheckTrue(sLog2 <> '');
    CheckEqualsString(sLog, sLog2);
    CheckTrue(iParamCount1 > 1);
    CheckTrue(iParamCount2 > 1);

    sLog := '';
    sLog2 := '';
    LCustomer.Name := 'Insert Execution Listener test';
    FSession.Insert(LCustomer);

    CheckTrue(sLog <> '');
    CheckTrue(sLog2 <> '');
    CheckEqualsString(sLog, sLog2);
    CheckTrue(iParamCount1 = 0);  //last statement fetches identity value so there are no parameteres
    CheckTrue(iParamCount2 = 0);

    sLog := '';
    sLog2 := '';
    FSession.Delete(LCustomer);
    CheckTrue(sLog <> '');
    CheckTrue(sLog2 <> '');
    CheckEqualsString(sLog, sLog2);
    CheckTrue(iParamCount1 = 1);
    CheckTrue(iParamCount2 = 1);

    Status(sLog);

  finally
    LCustomer.Free;
  end;
end;

procedure TSessionTest.ManyToMany;
var
  user: TUser;
  role: TRole;
  users: IList<TUser>;
  roles: IList<TRole>;
begin
  user := TUser.Create;
  user.Name := 'Foo';

  role := TRole.Create;
  role.Description := 'FooBar';
  user.AddRole(role);

  FSession.SaveAll(user);

  CheckEquals(1, GetTableRecordCount('User'), 'Should insert 1 user into User table');
  CheckEquals(1, GetTableRecordCount('Role'), 'Should insert 1 role into Role table');
  CheckEquals(1, GetTableRecordCount('UserRole'), 'Should insert 1 userrole into UserRole table');

  user.Free;
  role.Free;

  users := FSession.FindAll<TUser>;
  CheckEquals(1, users.Count, 'Should find 1 user from User table');
  CheckEquals('Foo', users.First.Name, 'User name is Foo');
  CheckEquals('FooBar', users.First.Roles.First.Description, 'User''s role description is FooBar');

  roles := FSession.FindAll<TRole>;
  CheckEquals(1, roles.Count, 'Should find 1 role from Role table');
  CheckEquals('FooBar', roles.First.Description, 'Role description is FooBar');
  CheckEquals('Foo', roles.First.Users.First.Name, 'Role''s user name is Foo');
end;

procedure TSessionTest.Fetch;
var
  LCollection: IList<TCustomer>;
  sSql: string;
begin
  sSql := 'SELECT * FROM ' + TBL_PEOPLE;
  LCollection := TCollections.CreateList<TCustomer>(True);

  FSession.FetchFromQueryText(sSql, [], LCollection as IObjectList, TCustomer);
  CheckEquals(0, LCollection.Count);

  LCollection.Clear;

  InsertCustomer;
  FSession.FetchFromQueryText(sSql, [], LCollection as IObjectList, TCustomer);
  CheckEquals(1, LCollection.Count);
  CheckEquals(25, LCollection[0].Age);

  LCollection.Clear;

  InsertCustomer(15);
  FSession.FetchFromQueryText(sSql, [], LCollection as IObjectList, TCustomer);
  CheckEquals(2, LCollection.Count);
  CheckEquals(15, LCollection[1].Age);
end;

procedure TSessionTest.FetchCollection;
var
  LCollection: IList<TCustomer>;
begin
  InsertCustomer;
  LCollection := TCollections.CreateObjectList<TCustomer>;
  FSession.FetchFromQueryText('SELECT * FROM ' + TBL_PEOPLE, [], LCollection as IObjectList, TCustomer);
  CheckEquals(1, LCollection.Count);
end;

procedure TSessionTest.FindAll;
var
  LCollection: IList<TCustomer>;
  i: Integer;
begin
  LCollection := FSession.FindAll<TCustomer>;
  CheckEquals(0, LCollection.Count);
  TestDB.BeginTransaction;
  for i := 1 to 10 do
  begin
    InsertCustomer(i);
  end;
  TestDB.Commit;

  LCollection := FSession.FindAll<TCustomer>;
  CheckEquals(10, LCollection.Count);
end;

procedure TSessionTest.FindOne;
var
  LCustomer: TCustomer;
  RowID: Integer;
begin
  LCustomer := FSession.FindOne<TCustomer>(1);
  CheckTrue(LCustomer = nil);

  InsertCustomer;
  RowID := TestDB.GetLastInsertRowID;
  LCustomer := FSession.FindOne<TCustomer>(RowID);
  try
    CheckTrue(LCustomer <> nil);
    CheckEquals(RowID, LCustomer.ID);
  finally
    LCustomer.Free;
  end;
end;

procedure TSessionTest.FindWhere;
var
  Age: Prop;
begin
  InsertCustomer(10);
  Age := Prop.Create(CUSTAGE);
  CheckEquals(10, FSession.FindWhere<TCustomer>(Age = 10).First.Age);
end;

procedure TSessionTest.First;
var
  LCustomer: TCustomer;
  sSql: string;
  fsPic: TFileStream;
begin
  sSql := 'SELECT * FROM ' + TBL_PEOPLE;
  LCustomer := FSession.FirstOrDefault<TCustomer>(sSql, []);

  CheckTrue(System.Default(TCustomer) = LCustomer);

  fsPic := TFileStream.Create(PictureFilename, fmOpenRead or fmShareDenyNone);
  try
    fsPic.Position := 0;
    InsertCustomerAvatar(25, 'Demo', 15.25, '', fsPic);
  finally
    fsPic.Free;
  end;

  CheckEquals(1, GetTableRecordCount(TBL_PEOPLE));

  LCustomer := FSession.First<TCustomer>(sSql, []);
  try
    CheckTrue(Assigned(LCustomer));
    CheckEquals(25, LCustomer.Age);

    CheckTrue(LCustomer.Avatar.Graphic <> nil);
  finally
    FreeAndNil(LCustomer);
  end;
  InsertCustomer(15);

  LCustomer := FSession.First<TCustomer>(sSql, []);
  try
    CheckTrue(Assigned(LCustomer));
    CheckEquals(25, LCustomer.Age);
  finally
    FreeAndNil(LCustomer);
  end;

  sSql := sSql + ' WHERE '+CUSTAGE+' = :0 AND '+CUSTNAME+'=:1';
  LCustomer := FSession.First<TCustomer>(sSql, [15, 'Demo']);
  try
    CheckTrue(Assigned(LCustomer));
    CheckEquals(15, LCustomer.Age);
  finally
    FreeAndNil(LCustomer);
  end;
end;

function TSessionTest.GenericCreate<T>: T;
begin
  Result := T.Create;
end;

procedure TSessionTest.GetLazyNullable;
var
  LCustomer: TCustomer;
  fsPic: TFileStream;
begin
  fsPic := TFileStream.Create(PictureFilename, fmOpenRead or fmShareDenyNone);
  try
    LCustomer := FSession.SingleOrDefault<TCustomer>(SQL_GET_ALL_CUSTOMERS, []);
    CheckFalse(Assigned(LCustomer));
    InsertCustomerAvatar(25, 'Nullable Lazy', 2.36, 'Middle', fsPic);

    LCustomer := FSession.SingleOrDefault<TCustomer>(SQL_GET_ALL_CUSTOMERS, []);
    try
      CheckNotNull(LCustomer.Avatar, 'Lazy should have value');
      CheckTrue(LCustomer.Avatar.Height > 0, 'Height should be more than 0');
      CheckTrue(LCustomer.Avatar.Width > 0, 'Width should be more than 0');
    finally
      LCustomer.Free;
    end;

  finally
    fsPic.Free;
  end;
end;

procedure TSessionTest.GetLazyValue;
var
  LCustomer: TCustomer;
  LList: IList<TCustomer_Orders>;
  LCustomerID: Integer;
begin
  LCustomer := TCustomer.Create;
  try
    LCustomer.Name := 'Test';
    LCustomer.Age := 10;

    FSession.Save(LCustomer);

    InsertCustomerOrder(LCustomer.ID, 10, 5, 100.59);
    InsertCustomerOrder(LCustomer.ID, 20, 15, 150.59);

    CheckEquals(0, LCustomer.Orders.Count);
    LCustomerID := LCustomer.ID;
    LCustomer.Free;
    LCustomer := FSession.FindOne<TCustomer>(LCustomerID);
    LList := LCustomer.Orders;
    CheckEquals(2, LList.Count);
    CheckEquals(LCustomer.ID, LList.First.Customer_ID);
    CheckEquals(10, LList.First.Customer_Payment_Method_Id);
    CheckEquals(5, LList.First.Order_Status_Code);
    CheckEquals(LCustomer.ID, LList.Last.Customer_ID);
    CheckEquals(20, LList.Last.Customer_Payment_Method_Id);
    CheckEquals(15, LList.Last.Order_Status_Code);
  finally
    LCustomer.Free;
  end;
  ClearTable(TBL_ORDERS);
  LCustomer := FSession.SingleOrDefault<TCustomer>('SELECT * FROM ' + TBL_PEOPLE, []);
  try
    CheckEquals(0, LCustomer.OrdersIntf.Count);
  finally
    LCustomer.Free;
  end;
end;

{$IFDEF PERFORMANCE_TESTS}
procedure TSessionTest.GetOne;
var
  LResultset: IDBResultset;
  LEntity: TCustomer;
  LObject: TObject;
  sw: TStopwatch;
  iCount: Integer;
  i: Integer;
  LVal, LVal2: Variant;
  LCustomers: IList<TCustomer>;
  LProducts: IList<TProduct>;
begin
  iCount := 50000;

  FConnection.ClearExecutionListeners;

  //insert customers
  TestDB.BeginTransaction;
  for i := 0 to iCount - 1 do
  begin
    InsertCustomer(i);
  end;
  TestDB.Commit;

  InsertProducts(iCount);

  sw := TStopwatch.StartNew;
  for i := 1 to iCount do
  begin
    LEntity := GenericCreate<TCustomer>;
    LEntity.Free;
  end;
  sw.Stop;
  Status(Format('GenericCreate %D objects in %D ms.',
    [iCount, sw.ElapsedMilliseconds]));

  sw := TStopwatch.StartNew;
  for i := 1 to iCount do
  begin
    LObject := SimpleCreate(TCustomer);
    LObject.Free;
  end;
  sw.Stop;
  Status(Format('SimpleCreate %D objects in %D ms.',
    [iCount, sw.ElapsedMilliseconds]));
  sw := TStopwatch.StartNew;
  LCustomers := TCollections.CreateObjectList<TCustomer>;
  for i := 1 to iCount do
  begin
    LCustomers.Add(TCustomer.Create);
  end;
  sw.Stop;
  Status(Format('Add %D objects in %D ms.',
    [iCount, sw.ElapsedMilliseconds]));
  //get customers
  LResultset := FSession.GetResultset('SELECT * FROM ' + TBL_PEOPLE, []);
  sw := TStopwatch.StartNew;
  LCustomers := FSession.FindAll<TCustomer>;
  sw.Stop;
  CheckEquals(iCount, LCustomers.Count);

  Status(Format('FindAll complex TCustomer %D objects in %D ms.',
    [iCount, sw.ElapsedMilliseconds]));

  //get products
  sw := TStopwatch.StartNew;
  LProducts := FSession.FindAll<TProduct>;
  sw.Stop;
  CheckEquals(iCount, LProducts.Count);

  Status(Format('FindAll simple TProduct %D objects in %D ms.',
    [iCount, sw.ElapsedMilliseconds]));

  //get customers non object
  LResultset := FSession.GetResultset('SELECT * FROM CUSTOMERS', []);
  sw := TStopwatch.StartNew;
  while not LResultset.IsEmpty do
  begin
    for i := 0 to LResultset.GetFieldCount - 1 do
    begin
      LVal := LResultset.GetFieldValue(i);
      if not VarIsNull(LVal) then
        LVal2 := LVal;
    end;
    LResultset.Next;
  end;
  sw.Stop;
  Status(Format('Resultset %D objects in %D ms. %S',
    [iCount, sw.ElapsedMilliseconds, LVal2]));
end;

procedure TSessionTest.InsertList;
var
  LCustomers: IList<TCustomer>;
  LCustomer: TCustomer;
  i, LCount: Integer;
  LStopwatch: TStopwatch;
  LTran: IDBTransaction;
begin
  LCount := 10000;
  FConnection.ClearExecutionListeners;
  LCustomers := TCollections.CreateObjectList<TCustomer>;
  for i := 1 to LCount do
  begin
    LCustomer := TCustomer.Create;
    LCustomer.Age := i;
    LCustomers.Add(LCustomer);
  end;
  LStopwatch := TStopwatch.StartNew;
  LTran := FSession.BeginTransaction;
  FSession.SaveList<TCustomer>(LCustomers);
  LTran.Commit;
  LStopwatch.Stop;
  CheckEquals(LCount, GetTableRecordCount(TBL_PEOPLE));
  Status(Format('Save List %d customers in %d ms', [LCount, LStopwatch.ElapsedMilliseconds]));

  ClearTable(TBL_PEOPLE);
  LCustomers.Clear;
  for i := 1 to LCount do
  begin
    LCustomer := TCustomer.Create;
    LCustomer.Age := i;
    LCustomers.Add(LCustomer);
  end;
  LStopwatch := TStopwatch.StartNew;
  LTran := FSession.BeginTransaction;
  FSession.InsertList<TCustomer>(LCustomers);
  LTran.Commit;
  LStopwatch.Stop;
  CheckEquals(LCount, GetTableRecordCount(TBL_PEOPLE));
  Status(Format('Insert List %d customers in %d ms', [LCount, LStopwatch.ElapsedMilliseconds]));

  for LCustomer in LCustomers do
  begin
    LCustomer.Age :=  LCount + 1;
  end;
  LStopwatch := TStopwatch.StartNew;
  LTran := FSession.BeginTransaction;
  FSession.UpdateList<TCustomer>(LCustomers);
  LTran.Commit;
  LStopwatch.Stop;
  CheckEquals(LCount, GetTableRecordCount(TBL_PEOPLE));
  Status(Format('Update List %d customers in %d ms', [LCount, LStopwatch.ElapsedMilliseconds]));

  LStopwatch := TStopwatch.StartNew;
  LTran := FSession.BeginTransaction;
  FSession.DeleteList<TCustomer>(LCustomers);
  LTran.Commit;
  LStopwatch.Stop;
  CheckEquals(0, GetTableRecordCount(TBL_PEOPLE));
  Status(Format('Delete List %d customers in %d ms', [LCount, LStopwatch.ElapsedMilliseconds]));
end;

{$ENDIF}

procedure TSessionTest.Inheritance_Simple_Customer;
var
  LCustomer: TCustomer;
  LForeignCustomer: TForeignCustomer;
begin
  LForeignCustomer := TForeignCustomer.Create;
  LCustomer := nil;
  try
    LForeignCustomer.Country := 'US';
    LForeignCustomer.Name := 'John';
    LForeignCustomer.Age := 28;
    LForeignCustomer.EMail := 'john@gmail.com';

    FSession.Save(LForeignCustomer);

    CheckEquals('John', GetValueFromDB(TBL_PEOPLE, CUSTNAME, CUSTID + '=' + IntToStr(LForeignCustomer.ID)), 'Name is not saved');

    LCustomer := FSession.FindOne<TCustomer>(LForeignCustomer.ID);

    CheckEquals('John', LCustomer.Name);
    CheckEquals(28, LCustomer.Age);
    LForeignCustomer.Free;

    LForeignCustomer := FSession.FindOne<TForeignCustomer>(LCustomer.ID);
    CheckEquals('US', LForeignCustomer.Country);
    CheckEquals('John', LForeignCustomer.Name);
    CheckEquals(28, LForeignCustomer.Age);

    LCustomer.Free;
    LForeignCustomer.Free;
    ClearTable(TBL_PEOPLE);

    LCustomer := TCustomer.Create;
    LCustomer.Name := 'Foo';
    FSession.Save(LCustomer);
    LForeignCustomer := FSession.FindOne<TForeignCustomer>(LCustomer.ID);

    CheckEquals('Foo', LForeignCustomer.Name);
    CheckFalse(LForeignCustomer.Country.HasValue);
  finally
    LForeignCustomer.Free;
    LCustomer.Free;
  end;
end;

procedure TSessionTest.Insert;
var
  LCustomer: TCustomer;
  LTable: ISQLiteTable;
  LID, LCount: Int64;
  LPicture: TPicture;
begin
  LCustomer := TCustomer.Create;
  LPicture := TPicture.Create;
  try
    LPicture.LoadFromFile(PictureFilename);
    LCustomer.Name := 'Insert test';
    LCustomer.Age := 10;
    LCustomer.Height := 1.1;
    LCustomer.Avatar := LPicture;

    CheckTrue(Assigned(LCustomer.Avatar), 'Picture assigned successfully');

    FSession.Insert(LCustomer);

    LTable := TestDB.GetUniTableIntf('select * from ' + TBL_PEOPLE);
    CheckEqualsString(LCustomer.Name, LTable.FieldByName[CUSTNAME].AsString, 'String column should be inserted');
    CheckEquals(LCustomer.Age, LTable.FieldByName[CUSTAGE].AsInteger, 'Integer column should be inserted');
    LID := LTable.FieldByName[CUSTID].AsInteger;
    CheckEquals(LID, LCustomer.ID, 'Primary keys should be equal');
    CheckTrue(LTable.FieldByName[CUST_MIDDLENAME].IsNull, 'Nullable should not be inserted');
    CheckFalse(LTable.FieldByName[CUSTAVATAR].IsNull, 'Lazy object should be inserted');
  finally
    LCustomer.Free;
  end;
  Exit;
  LCustomer := TCustomer.Create;
  try
    LCustomer.Name := 'Insert test 2';
    LCustomer.Age := 15;
    LCustomer.Height := 41.1;
    LCustomer.MiddleName := 'Middle Test';

    FSession.Insert(LCustomer);
    LTable := TestDB.GetUniTableIntf('select * from ' + TBL_PEOPLE + ' where ['+CUSTAGE+'] = 15;');
    CheckEqualsString(LCustomer.Name, LTable.FieldByName[CUSTNAME].AsString);
    CheckEquals(LCustomer.Age, LTable.FieldByName[CUSTAGE].AsInteger);
    LID := LTable.FieldByName[CUSTID].AsInteger;
    CheckEquals(LID, LCustomer.ID);
    CheckEqualsString(LCustomer.MiddleName, LTable.FieldByName[CUST_MIDDLENAME].AsString, 'Nullable should be inserted');

    LCount := TestDB.GetUniTableIntf('select count(*) from ' + TBL_PEOPLE).Fields[0].AsInteger;
    CheckEquals(2, LCount);
  finally
    LCustomer.Free;
  end;
end;

function IsAdult(const customer: TCustomer): Boolean;
begin
  Result := customer.Age >= 18;
end;

procedure TSessionTest.InsertFromCollection;
var
  customers: IList<TCustomer>;
  LCustomer: TCustomer;
  i: Integer;
  LTran: IDBTransaction;
begin
  customers := TCollections.CreateList<TCustomer>(True);
  for i := 1 to 100 do
  begin
    LCustomer := TCustomer.Create;
    LCustomer.Name := IntToStr(i);
    LCustomer.Age := i;
    LCustomer.LastEdited := EncodeDate(2009, 1, 12);
    customers.Add(LCustomer);
  end;
  LTran := FSession.BeginTransaction;
  FSession.InsertList<TCustomer>(customers);
  LTran.Commit;
  CheckEquals(100, GetTableRecordCount(TBL_PEOPLE), 'Should be 100 records inserted');
  LTran := FSession.BeginTransaction;
  FSession.DeleteList<TCustomer>(customers.Where(IsAdult));
  LTran.Commit;
  CheckEquals(17, GetTableRecordCount(TBL_PEOPLE));
end;

procedure TSessionTest.ListSession_Begin_Commit;
var
  LCustomers: IList<TCustomer>;
  LCustomer: TCustomer;
  LListSession: IListSession<TCustomer>;
  LProp: IProperty;
begin
  //fetch some customers from db
  InsertCustomer(15, 'Bar');
  InsertCustomer(10, 'Foo');
  LCustomers := FSession.FindAll<TCustomer>;
  CheckEquals(2, LCustomers.Count);
  LListSession := FSession.BeginListSession<TCustomer>(LCustomers);

  //add some customers
  LCustomer := TCustomer.Create;
  LCustomer.Age := 1;
  LCustomer.Name := 'New';
  LCustomers.Add(LCustomer);

  LCustomer := TCustomer.Create;
  LCustomer.Age := 9;
  LCustomer.Name := 'Cloud';
  LCustomers.Add(LCustomer);


  //delete customer which was fetched from database
  LCustomers.Delete(0);

  //edit customer which was fetched from the database
  LCustomers.First.Name := 'Edited Foo';
  LListSession.CommitListSession;

 // LCustomers := FSession.FindAll<TCustomer>;
  LProp := TProperty<TCustomer>.Create('CUSTAGE');
  LCustomers := FSession.CreateCriteria<TCustomer>.OrderBy(LProp.Asc).ToList;
  CheckEquals(3, LCustomers.Count);
  CheckEquals(1, LCustomers.First.Age);
  CheckEquals(9, LCustomers[1].Age);
  CheckEquals(10, LCustomers[2].Age);
  CheckEquals('Edited Foo', LCustomers[2].Name);
end;

class procedure TSessionTest.InsertProducts(iCount: Integer);
var
  Local_i: Integer;
begin
  //insert products
  TestDB.BeginTransaction;
  for Local_i := 1 to iCount do
  begin
    InsertProduct('Product ' + IntToStr(Local_i), Local_i);
  end;
  TestDB.Commit;
end;

const
  SQL_MANY_TO_ONE: string = 'SELECT O.*, C.CUSTID %0:S$CUSTID '+
    ' ,C.CUSTNAME %0:S$CUSTNAME, C.CUSTAGE %0:S$CUSTAGE '+
    ' FROM '+ TBL_ORDERS + ' O '+
    ' LEFT OUTER JOIN ' + TBL_PEOPLE + ' C ON C.CUSTID=O.Customer_ID;';

 {
 SELECT B.Order_Status_Code,B.Date_Order_Placed,B.Total_Order_Price,B.ORDER_ID,B.Customer_ID,
 B.Customer_Payment_Method_Id,A0.CUSTID Customers_Customer_ID_CUSTID,A0.AVATAR Customers_Customer_ID_AVATAR,
 A0.CUSTSTREAM Customers_Customer_ID_CUSTSTREAM,A0.CUSTNAME Customers_Customer_ID_CUSTNAME,
 A0.CUSTAGE Customers_Customer_ID_CUSTAGE,A0.CUSTHEIGHT Customers_Customer_ID_CUSTHEIGHT,
 A0.LastEdited Customers_Customer_ID_LastEdited,A0.EMAIL Customers_Customer_ID_EMAIL,
 A0.MIDDLENAME Customers_Customer_ID_MIDDLENAME,A0.CUSTTYPE Customers_Customer_ID_CUSTTYPE
 FROM Customer_Orders B
  LEFT OUTER JOIN Customers A0 ON A0.CUSTID=B.Customer_ID LIMIT 0,1 ;

 }

procedure TSessionTest.ManyToOne;
var
  LOrder: TCustomer_Orders;
  LCustomer: TCustomer;
  LID: Integer;
  sql: string;
begin
  LCustomer := TCustomer.Create;
  try
    LCustomer.Name := 'ManyToOne';
    LCustomer.Age := 15;

    FSession.Save(LCustomer);

    InsertCustomerOrder(LCustomer.ID, 1, 1, 100.50);

    sql := Format(SQL_MANY_TO_ONE, [TSQLAliasGenerator.GetAlias(TBL_PEOPLE)]);

    LOrder := FSession.Single<TCustomer_Orders>(sql, []);
    CheckTrue(Assigned(LOrder), 'Cannot get Order from DB');
    LID := LOrder.ORDER_ID;
    CheckTrue(Assigned(LOrder.Customer), 'Cannot get customer (inside order) from DB');
    CheckEqualsString(LCustomer.Name, LOrder.Customer.Name);
    CheckEquals(LCustomer.Age, LOrder.Customer.Age);
    FreeAndNil(LOrder);

    LOrder := FSession.FindOne<TCustomer_Orders>(LID);
    CheckTrue(Assigned(LOrder), 'Cannot get Order from DB');
    CheckTrue(Assigned(LOrder.Customer), 'Cannot get customer (inside order) from DB');
    CheckEquals('ManyToOne', LOrder.Customer.Name);
    CheckEquals(15, LOrder.Customer.Age);
    FreeAndNil(LOrder);

    ClearTable(TBL_PEOPLE);  //cascade also deletes records from related table
    LOrder := FSession.SingleOrDefault<TCustomer_Orders>(sql, []);
    CheckFalse(Assigned(LOrder), 'Cannot get Order from DB');
  finally
    LCustomer.Free;
  end;
end;

procedure TSessionTest.Memoizer_Cache_Constructors;
var
  cachedFunc: TFunc<PTypeInfo,TObject>;
  instance: TObject;
  sw: TStopwatch;
begin
  cachedFunc := TMemoize.Memoize<PTypeInfo, TObject>(
    function(arg: PTypeInfo): TObject
    begin
      Result := TActivator.CreateInstance(arg);
    end);
  sw := TStopwatch.StartNew;
  instance := cachedFunc(TCustomer.ClassInfo);
  sw.Stop;
  CheckNotNull(instance);
  Status(Format('First call in %d ticks', [sw.ElapsedTicks]));
  sw := TStopwatch.StartNew;
  instance := cachedFunc(TCustomer.ClassInfo);
  sw.Stop;
  CheckNotNull(instance);
  Status(Format('Second call in %d ticks', [sw.ElapsedTicks]));
  instance.Free;
end;

procedure TSessionTest.Nullable;
var
  LCustomer: TCustomer;
begin
  InsertCustomerNullable(25, 'Demo', 15.25, 'Middle');
  LCustomer := FSession.SingleOrDefault<TCustomer>('SELECT * FROM ' + TBL_PEOPLE, []);
  try
    CheckTrue(LCustomer.MiddleName.HasValue);
    CheckEqualsString('Middle', LCustomer.MiddleName.Value);
  finally
    LCustomer.Free;
  end;

  TestDB.ExecSQL('UPDATE ' + TBL_PEOPLE + ' SET '+CUST_MIDDLENAME+' = NULL;');
  LCustomer := FSession.SingleOrDefault<TCustomer>('SELECT * FROM ' + TBL_PEOPLE, []);
  try
    CheckFalse(LCustomer.MiddleName.HasValue);
  finally
    LCustomer.Free;
  end;
end;

procedure TSessionTest.Page;
var
  LPage: IDBPage<TCustomer>;
  i: Integer;
  iTotal: Integer;
begin
  iTotal := 50;
  TestDB.BeginTransaction;
  for i := 1 to iTotal do
  begin
    InsertCustomer(i);
  end;
  TestDB.Commit;

  LPage := FSession.Page<TCustomer>(1, 10, 'select * from ' + TBL_PEOPLE, []);
  CheckEquals(iTotal, LPage.GetTotalItems);
  CheckEquals(10, LPage.Items.Count);
  CheckEquals(1, LPage.Items[0].Age);

  LPage := FSession.Page<TCustomer>(2, 10, 'select * from ' + TBL_PEOPLE, []);
  CheckEquals(iTotal, LPage.GetTotalItems);
  CheckEquals(10, LPage.Items.Count);
  CheckEquals(11, LPage.Items[0].Age);

  LPage := FSession.Page<TCustomer>(3, 4);
  CheckEquals(iTotal, LPage.GetTotalItems);
  CheckEquals(4, LPage.Items.Count);
  CheckEquals(9, LPage.Items[0].Age);
end;

procedure TSessionTest.Save;
var
  LCustomer: TCustomer;
  LTable: ISQLiteTable;
  LID, LCount: Int64;
  LPicture: TPicture;
begin
  LCustomer := TCustomer.Create;
  LPicture := TPicture.Create;
  try
    LPicture.LoadFromFile(PictureFilename);
    LCustomer.Name := 'Insert test';
    LCustomer.Age := 10;
    LCustomer.Height := 1.1;
    LCustomer.Avatar := LPicture;

    FSession.Save(LCustomer);

    LTable := TestDB.GetUniTableIntf('select * from ' + TBL_PEOPLE);
    CheckEqualsString(LCustomer.Name, LTable.FieldByName[CUSTNAME].AsString);
    CheckEquals(LCustomer.Age, LTable.FieldByName[CUSTAGE].AsInteger);
    LID := LTable.FieldByName[CUSTID].AsInteger;
    CheckEquals(LID, LCustomer.ID);
    CheckTrue(LTable.FieldByName[CUST_MIDDLENAME].IsNull);
    CheckFalse(LTable.FieldByName[CUSTAVATAR].IsNull);
  finally
    LCustomer.Free;
  end;

  LCustomer := TCustomer.Create;
  try
    LCustomer.Name := 'Insert test 2';
    LCustomer.Age := 15;
    LCustomer.Height := 41.1;
    LCustomer.MiddleName := 'Middle Test';

    FSession.Save(LCustomer);
    LTable := TestDB.GetUniTableIntf('select * from ' + TBL_PEOPLE + ' where ['+CUSTAGE+'] = 15;');
    CheckEqualsString(LCustomer.Name, LTable.FieldByName[CUSTNAME].AsString);
    CheckEquals(LCustomer.Age, LTable.FieldByName[CUSTAGE].AsInteger);
    LID := LTable.FieldByName[CUSTID].AsInteger;
    CheckEquals(LID, LCustomer.ID);
    CheckEqualsString(LCustomer.MiddleName, LTable.FieldByName[CUST_MIDDLENAME].AsString);

    LCount := TestDB.GetUniTableIntf('select count(*) from ' + TBL_PEOPLE).Fields[0].AsInteger;
    CheckEquals(2, LCount);
  finally
    LCustomer.Free;
  end;
end;

procedure TSessionTest.SaveAll_ManyToOne;
var
  LCustomers: IList<TCustomer>;
  LOrder1, LOrder2, LNewOrder1, LNewOrder2: TCustomer_Orders;
begin
  InsertCustomer;
  LCustomers := FSession.FindAll<TCustomer>;

  LOrder1 := TCustomer_Orders.Create;
  LOrder2 := TCustomer_Orders.Create;
  LNewOrder1 := nil;
  LNewOrder2 := nil;
  try
    LOrder1.Customer_ID := LCustomers.First.ID;
    LOrder1.Order_Status_Code := 100;

    LOrder2.Customer_ID := LCustomers.First.ID;
    LOrder2.Order_Status_Code := 2;

    LOrder1.Customer := FSession.FindOne<TCustomer>(LOrder1.Customer_ID);
    LOrder2.Customer := FSession.FindOne<TCustomer>(LOrder2.Customer_ID);

    LOrder1.Customer.Name := 'John Malkowich';

    FSession.SaveAll(LOrder1);

    CheckEquals(1, GetTableRecordCount(TBL_ORDERS));

    LNewOrder1 := FSession.FindOne<TCustomer_Orders>(LOrder1.ORDER_ID);
    CheckEquals(LOrder1.Customer.Name, LNewOrder1.Customer.Name);

    LOrder2.Customer.Name := 'Bob Marley';
    FSession.SaveAll(LOrder2);

    LNewOrder2 := FSession.FindOne<TCustomer_Orders>(LOrder2.ORDER_ID);
    CheckEquals(LOrder2.Customer.Name, LNewOrder2.Customer.Name);

  finally
    LOrder1.Free;
    LOrder2.Free;
    LNewOrder1.Free;
    LNewOrder2.Free;
  end;
end;

procedure TSessionTest.When_FindAll_GetOneToMany;
var
  id: Integer;
  customers: IList<TCustomer>;
  order: TCustomer_Orders;
begin
  id := InsertCustomer(18, 'Foo');
  InsertCustomerOrder(id, 1, 5, 0);
  InsertCustomerOrder(id, 2, 57, 0);

  customers := FSession.FindAll<TCustomer>;
  CheckEquals(2, customers.First.Orders.Count);

  order := TCustomer_Orders.Create;
  order.Customer_ID := id;
  order.Order_Status_Code := 3;

  customers.First.Orders.Add(order);

  FSession.SaveAll(customers.First);

  customers := FSession.FindAll<TCustomer>;
  CheckEquals(3, customers.First.Orders.Count);
end;


type
  [Table('Customers')]
  TTransientCustomer = class
  private
    [Column('CUSTID', [cpRequired, cpPrimaryKey, cpNotNull], 0, 0, 0, 'Primary Key')]
    [AutoGenerated]
    FId: Integer;
    FName: string;
    function GetOrders: IList<TCustomer_Orders>;
  public
    constructor Create;
  public
    [OneToMany(False, [ckCascadeAll])]
    [Transient]
    FOrders: Lazy<IList<TCustomer_Orders>>;

    property Id: Integer read FId;

    [Column('CUSTNAME', [], 50, 0, 0, 'Customers name')]
    property Name: string read FName write FName;

    property Orders: IList<TCustomer_Orders> read GetOrders;

end;

constructor TTransientCustomer.Create;
begin
  inherited Create;
  FId := -1;
  FOrders := TCollections.CreateObjectList<TCustomer_Orders>;
end;

function TTransientCustomer.GetOrders: IList<TCustomer_Orders>;
begin
  Result := FOrders.Value;
end;

procedure TSessionTest.When_SaveAll_DoNotSaveTransient;
var
  customer: TTransientCustomer;
begin
  customer := TTransientCustomer.Create;
  customer.Name := 'Foo';
  customer.Orders.Add(TCustomer_Orders.Create(123));

  FSession.SaveAll(customer);

  CheckTrue(customer.Id <> -1);
  CheckEquals(1, GetTableRecordCount(TBL_PEOPLE));
  CheckEquals(0, GetTableRecordCount(TBL_ORDERS));

  customer.Free;
end;

procedure TSessionTest.When_SaveAll_InsertOneToMany;
var
  customer: TCustomer;
  order: TCustomer_Orders;
begin
  customer := TCustomer.Create;
  customer.Name := 'Foo';

  order := TCustomer_Orders.Create;
  order.Order_Status_Code := 123;
  order.Total_Order_Price := 100;
  customer.Orders.Add(order);

  FSession.SaveAll(customer);

  CheckEquals(1, GetTableRecordCount(TBL_PEOPLE));
  CheckEquals(1, GetTableRecordCount(TBL_ORDERS));
  CheckEquals(customer.ID, order.Customer_ID, 'CustomerIDs should be equal in both primary and foreign key entities');

  customer.Free;
end;

procedure TSessionTest.When_SaveAll_UpdateOneToMany;
var
  LCustomer: TCustomer;
  LNewCustomers: IList<TCustomer>;
  LNewOrders: IList<TCustomer_Orders>;
  LCustId: Integer;
begin
  LCustomer := TCustomer.Create;
  try
    CheckEquals(0, GetTableRecordCount(TBL_PEOPLE));
    CheckEquals(0, GetTableRecordCount(TBL_ORDERS));

    LCustomer.Name := 'Foo';
    LCustomer.Age := 15;

    FSession.Save(LCustomer);
    LCustId := LCustomer.ID;
    LCustomer.Free;
    InsertCustomerOrder(LCustId, 1, 2, 10);
    InsertCustomerOrder(LCustId, 2, 3, 20);

    LCustomer := FSession.FindOne<TCustomer>(LCustId);
    CheckEquals(2, LCustomer.OrdersIntf.Count);

    //change values of subentities
    LCustomer.OrdersIntf.First.Order_Status_Code := 99;
    LCustomer.OrdersIntf.Last.Order_Status_Code := 111;

    FSession.SaveAll(LCustomer);

    CheckEquals(1, GetTableRecordCount(TBL_PEOPLE));
    CheckEquals(2, GetTableRecordCount(TBL_ORDERS));

    LNewCustomers := FSession.FindAll<TCustomer>;
    CheckEquals(1, LNewCustomers.Count);
    CheckEquals('Foo', LNewCustomers.First.Name);
    CheckEquals(15, LNewCustomers.First.Age);

    LNewOrders := FSession.FindAll<TCustomer_Orders>;
    CheckEquals(2, LNewOrders.Count);
    CheckEquals(10, LNewOrders.First.Total_Order_Price);
    CheckEquals(99, LNewOrders.First.Order_Status_Code);

    CheckEquals(20, LNewOrders.Last.Total_Order_Price, 0.01);
    CheckEquals(111, LNewOrders.Last.Order_Status_Code, 0.01);
  finally
    LCustomer.Free;
  end;
end;

function PrettyPrintVariant(const value: Variant): string;
begin
  Result := VarToStrDef(value, '');
  if (Result = '') then
  begin
    if VarIsArray(value) then
      Result := 'array size: ' + IntToStr(VarArrayHighBound(value, VarArrayDimCount(value)));
  end;
end;

procedure TSessionTest.SetUp;
begin
  FConnection := CreateConnection;
  FSession := TMockSession.Create(FConnection);
  FConnection.AddExecutionListener(TestExecutionListener);
end;

function TSessionTest.SimpleCreate(AClass: TClass): TObject;
begin
  Result := AClass.Create;
end;

procedure TSessionTest.Streams;
var
  LCustomer: TCustomer;
  LResults: ISQLiteTable;
  LStream, LCustStream: TMemoryStream;
begin
  LCustomer := TCustomer.Create;
  LCustStream := TMemoryStream.Create;
  try
    LCustStream.LoadFromFile(PictureFilename);
    LCustomer.StreamLazy := LCustStream;

    FSession.Save(LCustomer);

    LResults := TestDB.GetUniTableIntf(SQL_GET_ALL_CUSTOMERS);
    CheckFalse(LResults.EOF);
    LStream := LResults.FieldByName[CUST_STREAM].AsBlob;
    CheckTrue(Assigned(LStream));
    try
      CheckTrue(LStream.Size > 0);
      CheckEquals(LCustomer.CustStream.Size, LStream.Size);
    finally
      LStream.Free;
    end;
  finally
    LCustomer.Free;
    LCustStream.Free;
  end;
end;

procedure TSessionTest.TearDown;
begin
  ClearTable(TBL_PEOPLE);
  ClearTable(TBL_ORDERS);
  ClearTable(TBL_PRODUCTS);
  ClearTable(TBL_USERS);
  ClearTable(TBL_ROLES);
  FSession.Free;
  FConnection := nil;
end;

procedure TSessionTest.TestExecutionListener(const command: string;
  const params: IEnumerable<TDBParam>);
var
  i: Integer;
  param: TDBParam;
begin
  Status(command);
  i := 0;
  for param in params do
  begin
    Status(Format('%2:d %0:s = %1:s. Type: %3:s',
      [param.Name,
      PrettyPrintVariant(param.ToVariant),
      i,
      VarTypeAsText(VarType(param.ToVariant))]));
    Inc(i);
  end;
  Status('-----');
end;

procedure TSessionTest.TestQueryListener(Sender: TObject; const SQL: string);
begin
  Status('Native: ' + SQL);
end;

procedure TSessionTest.Transactions;
var
  LCustomer: TCustomer;
  LDatabase: TSQLiteDatabase;
  LSession: TSession;
  LConn: IDBConnection;
  LTran: IDBTransaction;
  sFile: string;
begin
  LCustomer := TCustomer.Create;
  sFile := OutputDir + 'test.db';
  DeleteFile(sFile);
  LDatabase := TSQLiteDatabase.Create(sFile);
  LDatabase.OnQuery := TestQueryListener;
 // LDatabase.Open;
  LConn := TConnectionFactory.GetInstance(dtSQLite, LDatabase);
  LConn.AddExecutionListener(TestExecutionListener);
  LSession := TSession.Create(LConn);
  CreateTables(LDatabase);
  try
    LCustomer.Name := 'Transactions';
    LCustomer.Age := 1;

    LTran := LSession.BeginTransaction;
    LSession.Save(LCustomer);

    CheckEquals(0, GetTableRecordCount(TBL_PEOPLE, LDatabase, TestQueryListener));
    LTran.Commit;
    CheckEquals(1, GetTableRecordCount(TBL_PEOPLE, LDatabase, TestQueryListener));

    LTran := LSession.BeginTransaction;
    LSession.Delete(LCustomer);
    LTran.Rollback;
    CheckEquals(1, GetTableRecordCount(TBL_PEOPLE, LDatabase, TestQueryListener));
  finally
    LCustomer.Free;
    LDatabase.Close;
    LDatabase.Free;
    LSession.Free;
    LConn := nil;
    if not DeleteFile(sFile) then
      Fail('Cannot delete file. Error: ' + SysErrorMessage(GetLastError));
  end;
end;

procedure TSessionTest.Transactions_Nested;
var
  LTran1, LTran2: IDBTransaction;
  LCustomer, LDbCustomer: TCustomer;
  sFile: string;
  LDatabase: TSQLiteDatabase;
  LConn: IDBConnection;
  LSession: TSession;
begin
  sFile := OutputDir + 'test.db';
  DeleteFile(sFile);
  LDatabase := TSQLiteDatabase.Create(sFile);
  LDatabase.OnQuery := TestQueryListener;
  LConn := TConnectionFactory.GetInstance(dtSQLite, LDatabase);
  LConn.AddExecutionListener(TestExecutionListener);
  LSession := TSession.Create(LConn);
  CreateTables(LDatabase);

  LTran1 := LSession.Connection.BeginTransaction;
  LCustomer := TCustomer.Create;
  LDbCustomer := TCustomer.Create;
  try
    LCustomer.Name := 'Tran1';
    LDbCustomer.Name := 'Tran2';

    LSession.Save(LCustomer);
    LTran2 := LSession.Connection.BeginTransaction;
    LSession.Save(LDbCustomer);
    CheckEquals(0, GetTableRecordCount(TBL_PEOPLE, LDatabase));

    LTran2.Commit;
    CheckEquals(0, GetTableRecordCount(TBL_PEOPLE, LDatabase));

    LTran1.Commit;
    CheckEquals(2, GetTableRecordCount(TBL_PEOPLE, LDatabase));
  finally
    LTran1 := nil;
    LTran2 := nil;
    LCustomer.Free;
    LDbCustomer.Free;
    LDatabase.Close;
    LDatabase.Free;
    LSession.Free;
    LConn := nil;
    if not DeleteFile(sFile) then
      Fail('Cannot delete file. Error: ' + SysErrorMessage(GetLastError));
  end;
end;

procedure TSessionTest.Update;
var
  LCustomer: TCustomer;
  sSql: string;
  LResults: ISQLiteTable;
begin
  sSql := 'select * from ' + TBL_PEOPLE;

  InsertCustomer;

  LCustomer := FSession.FirstOrDefault<TCustomer>(sSql, []);
  try
    CheckEquals(25, LCustomer.Age);

    LCustomer.Age := 55;
    LCustomer.Name := 'Update Test';


    FSession.Update(LCustomer);

    LResults := TestDB.GetUniTableIntf('SELECT * FROM ' + TBL_PEOPLE);
    CheckEquals(LCustomer.Age, LResults.FieldByName[CUSTAGE].AsInteger);
    CheckEqualsString(LCustomer.Name, LResults.FieldByName[CUSTNAME].AsString);
    CheckFalse(LCustomer.MiddleName.HasValue);

    LCustomer.MiddleName := 'Middle';
    FSession.Update(LCustomer);

    LResults := TestDB.GetUniTableIntf('SELECT * FROM ' + TBL_PEOPLE);
    CheckEqualsString(LCustomer.MiddleName, LResults.FieldByName[CUST_MIDDLENAME].AsString);

  finally
    LCustomer.Free;
  end;
end;

procedure TSessionTest.Update_NotMapped;
var
  LId: Integer;
  LCustomer, LDBCustomer: TCustomer;
begin
  LId := InsertCustomer(25, 'Foo', 1.1);

  LCustomer := TCustomer.Create;
  LDBCustomer := nil;
  try
    TType.GetType(LCustomer).GetField('FId').SetValue(LCustomer, LId);
    LCustomer.Age := 25;
    LCustomer.Name := 'Bar';
    LCustomer.Height := 1.1;

    FSession.Update(LCustomer);

    LDBCustomer := FSession.FindOne<TCustomer>(LId);
    CheckEquals(LCustomer.Name, LDBCustomer.Name);
  finally
    LCustomer.Free;
    LDBCustomer.Free;
  end;
end;

procedure TSessionTest.Versioning;
var
  LModel, LModelOld, LModelLoaded: TProduct;
  bOk: Boolean;
begin
  LModel := TProduct.Create;
  LModel.Name := 'Initial version';
  FSession.Save(LModel);

  LModelLoaded := FSession.FindOne<TProduct>(TValue.FromVariant(LModel.Id));
  CheckEquals(1, LModelLoaded.Version);
  LModelLoaded.Name := 'Updated version No. 1';

  LModelOld := FSession.FindOne<TProduct>(TValue.FromVariant(LModel.Id));
  CheckEquals(1, LModelOld.Version);
  LModelOld.Name := 'Updated version No. 2';

  FSession.Save(LModelLoaded);
  CheckEquals(2, LModelLoaded.Version);

  try
    FSession.Save(LModelOld);
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

type
  TUnanotatedEntity = class
  private
    FName: string;
  public
    property Name: string read FName write FName;
  end;

  TCustomerWithLazyOneToMany = class(TCustomer)
  private
    [OneToMany(False, [ckCascadeAll])]
    FOrders: Lazy<IList<TCustomer_Orders>>;
    function GetOrders: IList<TCustomer_Orders>;
  public
    property OrdersLazy: IList<TCustomer_Orders> read GetOrders;
  end;

function TCustomerWithLazyOneToMany.GetOrders: IList<TCustomer_Orders>;
begin
  Result := FOrders;
end;

type
  TCustomerRowMapper = class(TInterfacedObject, IRowMapper<TCustomer>)
  protected
    function MapRow(const resultSet: IDBResultSet): TCustomer;
  end;

function TCustomerRowMapper.MapRow(const resultSet: IDBResultSet): TCustomer;
begin
  Result := TCustomer.Create;
  Result.Name := resultSet.GetFieldValue('CUSTNAME');
end;


procedure TSessionTest.When_Registered_RowMapper_And_FindAll_Make_Sure_Its_Used_On_TheSameType;
var
  customer: TCustomer;
  customers: IList<TCustomer>;
begin
  FSession.RegisterRowMapper<TCustomer>(TCustomerRowMapper.Create);
  InsertCustomer(20, 'Demo');
  customers := FSession.FindAll<TCustomer>;
  customer := customers.First;
  CheckEquals('Demo', customer.Name, 'Make sure name is mapped');
  CheckEquals(-1, customer.ID, 'We are not mapping id in customer row mapper so it should be -1');
end;

procedure TSessionTest.When_Registered_RowMapper_And_FindOne_Make_Sure_Its_Used_On_TheSameType;
var
  customer: TCustomer;
  id: TValue;
begin
  FSession.RegisterRowMapper<TCustomer>(TCustomerRowMapper.Create);
  id := TValue.FromVariant(InsertCustomer(20, 'Demo'));

  customer := FSession.FindOne<TCustomer>(id);
  CheckEquals('Demo', customer.Name, 'Make sure name is mapped');
  CheckEquals(-1, customer.ID, 'We are not mapping id in customer row mapper so it should be -1');
  customer.Free;
end;

procedure TSessionTest.When_Registered_RowMapper_And_GetList_Make_Sure_Its_Used_On_TheSameType;
var
  customer: TCustomer;
  customers: IList<TCustomer>;
begin
  FSession.RegisterRowMapper<TCustomer>(TCustomerRowMapper.Create);
  InsertCustomer(20, 'Demo');
  customers := FSession.GetList<TCustomer>(SQL_GET_ALL_CUSTOMERS, []);
  customer := customers.First;
  CheckEquals('Demo', customer.Name, 'Make sure name is mapped');
  CheckEquals(-1, customer.ID, 'We are not mapping id in customer row mapper so it should be -1');
end;

procedure TSessionTest.When_Lazy_Is_OneToMany;
var
  customer: TCustomerWithLazyOneToMany;
  id: Integer;
begin
  id := InsertCustomer;
  InsertCustomerOrder(id, 1, 1, 100);
  InsertCustomerOrder(id, 2, 10, 200);
  InsertCustomerOrder(id, 3, 10, 300);

  customer := FSession.FindOne<TCustomerWithLazyOneToMany>(id);
  CheckEquals(3, customer.OrdersLazy.Count);
  CheckEquals(1, customer.OrdersLazy[0].Customer_Payment_Method_Id);
  CheckEquals(2, customer.OrdersLazy[1].Customer_Payment_Method_Id);
  CheckEquals(3, customer.OrdersLazy[2].Customer_Payment_Method_Id);
  customer.Free;
end;

procedure TSessionTest.When_Trying_To_Register_RowMapper_Again_For_The_Same_Type_Throw_Exception;
begin
  FSession.RegisterRowMapper<TCustomer>(TCustomerRowMapper.Create);
  CheckException(
    EORMRowMapperAlreadyRegistered,
    procedure begin FSession.RegisterRowMapper<TCustomer>(TCustomerRowMapper.Create); end
    , 'Registering multiple RowMappers for the same type is not allowed');
end;

procedure TSessionTest.When_UnannotatedEntity_FindOne_ThrowException;
begin
  ExpectedException := EORMUnsupportedType;
  FSession.FindOne<TUnanotatedEntity>(1);
  StopExpectingException('Should not succeed if entity is not annotated');
end;

type
  [Entity]
  TWithoutTable = class
  private
    FName: string;
  public
    [Column]
    property Name: string read FName write FName;
  end;

  [Table('Test')]
  TWithoutPrimaryKey = class
  private
    FName: string;
  public
    [Column]
    property Name: string read FName write FName;
  end;

procedure TSessionTest.When_WithoutPrimaryKey_FindOne_ThrowException;
begin
  ExpectedException := EORMUnsupportedType;
  FSession.FindOne<TWithoutPrimaryKey>(1);
  StopExpectingException('Should not succeed if entity has no primary key column');
end;

procedure TSessionTest.When_WithoutTableAttribute_FindOne_ThrowException;
begin
  ExpectedException := EORMUnsupportedType;
  FSession.FindOne<TWithoutTable>(1);
  StopExpectingException('Should not succeed if entity is not annotated with table');
end;

type
  TSQLiteEvents = class
  public
    class procedure DoOnAfterOpen(Sender: TObject);
  end;

{ TSQLiteEvents }

class procedure TSQLiteEvents.DoOnAfterOpen(Sender: TObject);
begin
  CreateTables;
end;

{ TestTDetachedSession }

{$IFDEF PERFORMANCE_TESTS}
procedure TDetachedSessionTest.Performance;
var
  LCount: Integer;
  LStopWatch: TStopwatch;
  LProducts: IList<TProduct>;
begin
  LCount := 50000;
  TSessionTest.InsertProducts(LCount);

  LStopWatch := TStopwatch.StartNew;
  LProducts := FSession.FindAll<TProduct>;
  LStopWatch.Stop;
  Status(Format('Loaded %d simple products in %d ms', [LCount, LStopWatch.ElapsedMilliseconds]));
  CheckEquals(LCount, LProducts.Count);
end;

type
  TProductRowMapper = class(TInterfacedObject, IRowMapper<TProduct>)
  protected
    function MapRow(const resultSet: IDBResultSet): TProduct;
  end;

function TProductRowMapper.MapRow(const resultSet: IDBResultSet): TProduct;
begin
  Result := TProduct.Create;
  Result.ID := resultSet.GetFieldValue('PRODID');
  Result.Name := resultSet.GetFieldValue('PRODNAME');
  Result.Price := resultSet.GetFieldValue('PRODPRICE');
end;

procedure TDetachedSessionTest.Performance_RowMapper;
var
  LCount: Integer;
  LStopWatch: TStopwatch;
  LProducts: IList<TProduct>;
begin
  LCount := 50000;
  TSessionTest.InsertProducts(LCount);
  FSession.RegisterRowMapper<TProduct>(TProductRowMapper.Create);

  LStopWatch := TStopwatch.StartNew;
  LProducts := FSession.FindAll<TProduct>;
  LStopWatch.Stop;
  Status(Format('Loaded %d simple products using RowMapper in %d ms', [LCount, LStopWatch.ElapsedMilliseconds]));
  CheckEquals(LCount, LProducts.Count);
end;
{$ENDIF}

procedure TDetachedSessionTest.SaveAlwaysInsertsEntity;
var
  LCustomer: TCustomer;
begin
  LCustomer := TCustomer.Create;
  LCustomer.Name := 'Foo';
  FSession.Insert(LCustomer);

  LCustomer.Name := 'Bar';
  FSession.Save(LCustomer);
  LCustomer.Free;

  CheckEquals(2, FSession.FindAll<TCustomer>.Count);
end;

procedure TDetachedSessionTest.SetUp;
begin
  FConnection := TConnectionFactory.GetInstance(dtSQLite, TestDB);
  FSession := TDetachedSession.Create(FConnection);
end;

procedure TDetachedSessionTest.TearDown;
begin
  ClearTable(TBL_PEOPLE);
  ClearTable(TBL_ORDERS);
  ClearTable(TBL_PRODUCTS);
  FSession.Free;
end;

procedure TDetachedSessionTest.Update;
var
  LCustomer: TCustomer;
begin
  LCustomer := TCustomer.Create;
  LCustomer.Name := 'Foo';
  FSession.Insert(LCustomer);

  LCustomer.Name := 'Bar';
  FSession.Update(LCustomer);
  LCustomer.Free;

  CheckEquals('Bar', FSession.FindAll<TCustomer>.First.Name);
  CheckEquals(1, FSession.FindAll<TCustomer>.Count);
end;

initialization
  RegisterTest(TSessionTest.Suite);
  RegisterTest(TDetachedSessionTest.Suite);

  TestDB := TSQLiteDatabase.Create(':memory:');
 // TestDB := TSQLiteDatabase.Create('file::memory:?cache=shared');
  TestDB.OnAfterOpen := TSQLiteEvents.DoOnAfterOpen;
  CreateTables;

finalization
  TestDB.Free;

end.
