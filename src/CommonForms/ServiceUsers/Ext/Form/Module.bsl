
////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the SelfTest parameter is passed.
	If Parameters.Property("SelfTest") Then
		Return;
	EndIf;
	
	If Not Users.InfoBaseUserWithFullAccess() Then
		Raise(NStr("en = 'Insufficient rights to add users.'"));
	EndIf;
	
	RunMode = Constants.InfoBaseUsageMode.Get();
	If RunMode = Enums.InfoBaseUsageModes.Demo Then
		Raise(NStr("en = 'New users cannot be added in the demo mode.'"));
	EndIf;
	
	SetPrivilegedMode(True);
	
	Proxy = ServiceMode.GetServiceManagerProxy();
	
	ErrorMessage = "";
	UserList = Undefined;
	
	CurrentDataArea = CommonUse.SessionSeparatorValue();
	
	Result = Proxy.GetUserList(CurrentDataArea, UserList, ErrorMessage);
	
	If Not Result Then
		MessagePattern = NStr("en = 'Error retrieving the service user list:
			|%1'");
		Raise(StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, ErrorMessage));
	EndIf;
	
	UserIDs = New Array;
	
	For Each UserInfo In UserList.User Do
		UserIDs.Add(New UUID(UserInfo.UserID));
	EndDo;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Users.Ref,
	|	Users.ServiceUserID AS Id
	|FROM
	|	Catalog.Users AS Users
	|WHERE
	|	Users.ServiceUserID IN(&IDs)";
	Query.SetParameter("IDs", UserIDs);
	Result = Query.Execute();
	UserWithAccessIDs = Result.Unload().UnloadColumn("ID");
	
	For Each UserInfo In UserList.User Do
		UserID = New UUID(UserInfo.UserID);
		If UserWithAccessIDs.Find(UserID) <> Undefined Then
			Continue;
		EndIf;
		
		UserRow = ServiceUsers.Add();
		UserRow.Name = UserInfo.Name;
		UserRow.FullName = UserInfo.FullName;
		UserRow.Comment = UserInfo.Comment;
		UserRow.ID = UserID;
		UserRow.HasAccess = UserInfo.HasAccess;
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure CheckAll(Command)
	
	For Each TableRow In ServiceUsers Do
		TableRow.Add = True;
	EndDo;
	
EndProcedure

&AtClient
Procedure UncheckAll(Command)
	
	For Each TableRow In ServiceUsers Do
		TableRow.Add = False;
	EndDo;
	
EndProcedure

&AtClient
Procedure AddSelectedUsers(Command)
	
	AddSelectedUsersAtServer();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

&AtServer
Procedure AddSelectedUsersAtServer()
	
	SetPrivilegedMode(True);
	
	Proxy = ServiceMode.GetServiceManagerProxy();
	
	RightSet = "DataAreaUser";
	
	Counter = 0;
	RowCount = ServiceUsers.Count();
	For Counter = 1 to RowCount Do
		TableRow = ServiceUsers[RowCount - Counter];
		If Not TableRow.Add Then
			Continue;
		EndIf;
		
		UserInfo = Undefined;
		ErrorMessage = "";
		Result = Proxy.GetUserInfo(String(TableRow.ID), 
			UserInfo, ErrorMessage);
		If Not Result Then
			MessagePattern = NStr("en = 'Error retrieving details of a user whose ID is %1:
				|%2'");
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessageText, TableRow.ID, ErrorMessage);
			WriteLogEvent(NStr("en = 'ManagementApplication'", Metadata.DefaultLanguage.LanguageCode), EventLogLevel.Error, , , MessageText);
			CommonUseClientServer.MessageToUser(MessageText);
			Continue;
		EndIf;
		
		ErrorMessage = "";
		CurrentDataArea = CommonUse.SessionSeparatorValue();
		
		Result = Proxy.GrantUserAccess(String(TableRow.ID), CurrentDataArea, "User", ErrorMessage);
		
		If Not Result Then
			MessagePattern = NStr("en = 'Error providing user access to the application %1 with the service:
				|%2'");
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessageText, TableRow.Name, ErrorMessage);
			WriteLogEvent(NStr("en = 'ManagementApplication'", Metadata.DefaultLanguage.LanguageCode), EventLogLevel.Error, , , MessageText);
			CommonUseClientServer.MessageToUser(MessageText);
			RollbackTransaction();
			Continue;
		EndIf;
		
		ServiceUsers.Delete(TableRow);
		
	EndDo;
	
EndProcedure
