////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	InfoBaseSessionNumber = InfoBaseSessionNumber();
	ConditionalAppearance.Items[0].Filter.Items[0].RightValue = InfoBaseSessionNumber;
	
	If CommonUse.FileInfoBase() Then
		If Items.Find("TerminateSession") <> Undefined Then
			Items.TerminateSession.Visible = False;
			Items.TerminateSessionContext.Visible = False;
		EndIf;
		If Items.Find("InfoBaseAdministrationParameters") <> Undefined Then
			Items.InfoBaseAdministrationParameters.Visible = False;
		EndIf;
	Else
		If Not Users.InfoBaseUserWithFullAccess(, True) Then
			Items.InfoBaseAdministrationParameters.Visible = False;
		EndIf;
	EndIf;
	
	SortingColumnName = "SessionStarted";
	SortDirection = "Asc";
	FillUserList();
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS

////////////////////////////////////////////////////////////////////////////////
// FORM TABLE EVENT HANDLERS OF UserList TABLE

&AtClient
Procedure UserListChoice(Item, SelectedRow, Field, StandardProcessing)
	OpenUserFromList();
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS
 
&AtClient
Procedure TerminateSession(Command)
	
	Message = "";
	
	SessionNumberToTerminate = Items.UserList.CurrentData.Session;
	
	If SessionNumberToTerminate = InfoBaseSessionNumber Then
		ShowMessageBox(, NStr("en = 'The current session cannot be terminated. You should close the main application window if you want exit the application.'"));
		Return;
	EndIf;
	
	Terminated = InfoBaseConnectionsClientServer.TerminateSessionWithMessage(SessionNumberToTerminate, Message);
	If Not IsBlankString(Message) And Not Terminated Then
		ShowMessageBox(, Message);
	EndIf;
	
	If Terminated Then
		ShowMessageBox(, NStr("en = 'The session was terminated.'"));
	EndIf;
	
	FillList();
	
EndProcedure

&AtClient
Procedure RefreshExecute(Command)
	
	FillList();
	
EndProcedure

&AtClient
Procedure OpenEventLog(Command)
	
	If Items.UserList.SelectedRows.Count() > 1 Then
		ShowMessageBox(, NStr("en = 'You have to choose only one user from the list if you want to view the event log.'"));
		Return;
	EndIf;
		
	CurrentData = Items.UserList.CurrentData;
	If CurrentData = Undefined Then
		ShowMessageBox(, NStr("en = 'The event log cannot be opened for the chosen user.'"));
		Return;
	EndIf;
	
	UserName = CurrentData.UserName;
	
	OpenForm("DataProcessor.EventLog.Form", New Structure("User", UserName));
	
EndProcedure

&AtClient
Procedure SortAsc(Command)
	
	SortByColumn("Asc");
	
EndProcedure

&AtClient
Procedure SortDesc(Command)
	
	SortByColumn("Desc");
	
EndProcedure

&AtClient
Procedure OpenUser(Command)
	OpenUserFromList();
EndProcedure

&AtClient
Procedure InfoBaseAdministrationParameters(Command)
	
	OpenForm("CommonForm.ServerInfoBaseAdministrationSettings");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

&AtClient
Procedure FillList()
	
	// Storing the current session to determine the selected row after filling the user list
	CurrentSession = Undefined;
	CurrentData = Items.UserList.CurrentData;
	
	If CurrentData <> Undefined Then
		CurrentSession = CurrentData.Session;
	EndIf;
	
	FillUserList();
	
	// Restoring the selected row by the stored session
	If CurrentSession <> Undefined Then
		SearchStructure = New Structure;
		SearchStructure.Insert("Session", CurrentSession);
		FoundSessions = UserList.FindRows(SearchStructure);
		If FoundSessions.Count() = 1 Then
			Items.UserList.CurrentRow = FoundSessions[0].GetID();
			Items.UserList.SelectedRows.Clear();
			Items.UserList.SelectedRows.Add(Items.UserList.CurrentRow);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure SortByColumn(Direction)
	
	Column = Items.UserList.CurrentItem;
	If Column = Undefined Then
		Return;
	EndIf;
	
	SortingColumnName = Column.Name;
	SortDirection = Direction;
	
	FillList();
	
EndProcedure

&AtServer
Procedure FillUserList()
	
	UserList.Clear();
	
	Users.FindAmbiguousInfoBaseUsers();
	
	InfoBaseSessions = GetInfoBaseSessions();
	
	For Each InfoBaseSession In InfoBaseSessions Do
		UserRow = UserList.Add();
		
		UserRow.Application = ApplicationPresentation(InfoBaseSession.ApplicationName);
		UserRow.SessionStarted = InfoBaseSession.SessionStarted;
		UserRow.Computer = InfoBaseSession.ComputerName;
		UserRow.Session = InfoBaseSession.SessionNumber;
		UserRow.Connection = InfoBaseSession.ConnectionNumber;

		If InfoBaseSession.User <> Undefined Then
			
			UserRow.User		= InfoBaseSession.User.Name;
			UserRow.UserName		= InfoBaseSession.User.FullName;
			UserRow.UserRef	= 
				FindRefByUserID(InfoBaseSession.User.UUID);
			
			If CommonUseCached.DataSeparationEnabled() 
				And Users.InfoBaseUserWithFullAccess(, True) Then
				
				UserRow.DataSeparation = DataSeparationValuesToString(InfoBaseSession.User.DataSeparation);
			EndIf;	
			
		Else
			UserRow.User = "";
			UserRow.UserName = "";
		EndIf;

		If InfoBaseSession.SessionNumber = InfoBaseSessionNumber Then
			UserRow.UserPictureNumber = 0;
		Else
			UserRow.UserPictureNumber = 1;
		EndIf;
		
	EndDo;
	
	ActiveUserCount = InfoBaseSessions.Count();
	UserList.Sort(SortingColumnName + " " + SortDirection);
	
EndProcedure

&AtServer
Function DataSeparationValuesToString(DataSeparation)
	
	Result = "";
	Value = "";
	If DataSeparation.Property("DataArea", Value) Then
		Result = String(Value);
	EndIf;
	
	HasOtherSeparators = False;
	For Each Separator In DataSeparation Do
		If Separator.Key = "DataArea" Then
			Continue;
		EndIf;
		If Not HasOtherSeparators Then
			If Not IsBlankString(Result) Then
				Result = Result + " ";
			EndIf;
			Result = Result + "(";
		EndIf;
		Result = Result + String(Separator.Value);
		HasOtherSeparators = True;
	EndDo;
	If HasOtherSeparators Then
		Result = Result + ")";
	EndIf;
	Return Result;
		
EndFunction

&AtServer
Function FindRefByUserID(ID)
	
	// If the separated catalog is not accessed from the shared session
	If CommonUseCached.DataSeparationEnabled() 
		And Not CommonUseCached.CanUseSeparatedData() Then
		Return Undefined;
	EndIf;	
	
	Query = New Query;
	
	QueryTextPattern = "SELECT
					|	Ref
					|FROM
					|	%1
					|WHERE
					|	InfoBaseUserID = &ID";
					
	QueryByUsersText = 
			StringFunctionsClientServer.SubstituteParametersInString(
					QueryTextPattern,
					"Catalog.Users");
	
	QueryByExternalUsersText = 
			StringFunctionsClientServer.SubstituteParametersInString(
					QueryTextPattern,
					"Catalog.ExternalUsers");
					
	Query.Text = QueryByUsersText;
	Query.Parameters.Insert("ID", ID);
	Result = Query.Execute();
	
	If Not Result.IsEmpty() Then
		Selection = Result.Select();
		Selection.Next();
		Return Selection.Ref;
	EndIf;
	
	Query.Text = QueryByExternalUsersText;
	Result = Query.Execute();
	
	If Not Result.IsEmpty() Then
		Selection = Result.Select();
		Selection.Next();
		Return Selection.Ref;
	EndIf;
	
	Return Catalogs.Users.EmptyRef();
	
EndFunction

&AtClient
Procedure OpenUserFromList()
	
	CurrentData = Items.UserList.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	User = CurrentData.UserRef;
	If ValueIsFilled(User) Then
		OpenParameters = New Structure("Key", User);
		If TypeOf(User) = Type("CatalogRef.Users") Then
			OpenForm("Catalog.Users.Form.ItemForm", OpenParameters);
		ElsIf TypeOf(User) = Type("CatalogRef.ExternalUsers") Then
			OpenForm("Catalog.ExternalUsers.Form.ItemForm", OpenParameters);
		EndIf;
	EndIf;
	
EndProcedure