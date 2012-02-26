

&AtClient
Procedure FillList()
	
	// To be able to restore position save current session
	CurrentSessionNumber = Undefined;
	CurrentData = Items.ListOfUsers.CurrentData;
	
	If CurrentData <> Undefined Then
		CurrentSessionNumber = CurrentData.SessionNumber;
	EndIf;
	
	FillUsersList();
	
	// Restore current row using saved session
	If CurrentSessionNumber <> Undefined Then
		SearchStructure = New Structure;
		SearchStructure.Insert("SessionNumber", CurrentSessionNumber);
		SessionsFound = ListOfUsers.FindRows(SearchStructure);
		If SessionsFound.Count() = 1 Then
			Items.ListOfUsers.CurrentRow = SessionsFound[0].GetID();
			Items.ListOfUsers.SelectedRows.Clear();
			Items.ListOfUsers.SelectedRows.Add(Items.ListOfUsers.CurrentRow);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure SortByColumn(Direction)
	
	Column = Items.ListOfUsers.CurrentItem;
	If Column = Undefined Then
		Return;
	EndIf;
	
	SortingColumnName = Column.Name;
	SortDirection = Direction;
	
	FillList();
	
EndProcedure

&AtServer
Procedure FillUsersList()
	
	ListOfUsers.Clear();
	
	InformationBaseSessions = GetInfoBaseSessions();
	
	For Each InfobaseSession In InformationBaseSessions Do
		UserStr = ListOfUsers.Add();
		
		UserStr.ApplicationType   		= ApplicationPresentation(InfobaseSession.ApplicationName);
		UserStr.SessionStartTime 	= InfobaseSession.SessionStarted;
		UserStr.Computer    	= InfobaseSession.ComputerName;
		UserStr.SessionNumber        	= InfobaseSession.SessionNumber;
		UserStr.Connection  	= InfobaseSession.ConnectionNumber;

		If InfobaseSession.User <> Undefined Then
			UserStr.User		= InfobaseSession.User.Name;
			UserStr.UserName	= InfobaseSession.User.FullName;
			UserStr.UserRef		= FindRefByUserID(InfobaseSession.User.Uuid);
		Else
			UserStr.User     	= "";
			UserStr.UserName 	= "";
		EndIf;

		If InfobaseSession.SessionNumber = InfoBaseSessionNumber Then
			UserStr.UserPictureNumber = 0;
		Else
			UserStr.UserPictureNumber = 1;
		EndIf;
	EndDo;
	
	NumberOfActiveUsers = InformationBaseSessions.Count();
	ListOfUsers.Sort(SortingColumnName + " " + SortDirection);
	
EndProcedure

Function FindRefByUserID(Id)
	
	Query = New Query;
	
	QueryTextTemplate = "SELECT
					|	Ref
					|FROM
					|	%1
					|WHERE
					|	IBUserID = &Id";
					
	QueryTextByUsers = 
			StringFunctionsClientServer.SubstitureParametersInString(
					QueryTextTemplate,
					"Catalog.Users");
	
	QueryTextByExternalUsers = 
			StringFunctionsClientServer.SubstitureParametersInString(
					QueryTextTemplate,
					"Catalog.ExternalUsers");
					
	Query.Text = QueryTextByUsers;
	Query.Parameters.Insert("Id", Id);
	Result = Query.Execute();
	
	If NOT Result.IsEmpty() Then
		Selection = Result.Choose();
		Selection.Next();
		Return Selection.Ref;
	EndIf;
	
	Query.Text = QueryTextByExternalUsers;
	Result = Query.Execute();
	
	If NOT Result.IsEmpty() Then
		Selection = Result.Choose();
		Selection.Next();
		Return Selection.Ref;
	EndIf;
	
	Return Catalogs.Users.EmptyRef();
	
EndFunction


////////////////////////////////////////////////////////////////////////////////
// Event handlers of form, form items, and form commands

&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	InfoBaseSessionNumber = InfoBaseSessionNumber();
	
	If CommonUse.FileInformationBase() Then
		If Items.Find("TerminateSession") <> Undefined Then
			Items.TerminateSession.Visible = False;
		EndIf;
		If Items.Find("TerminateSessionContext") <> Undefined Then
			Items.TerminateSessionContext.Visible = False;
		EndIf;
		If Items.Find("InformationBaseAdministrationParameters") <> Undefined Then
			Items.InformationBaseAdministrationParameters.Visible = False;
		EndIf;
	EndIf;
	
	// Insert handler content.
	SortingColumnName = "SessionStartTime";
	SortDirection = "Asc";
	FillUsersList();
	
EndProcedure

&AtClient
Procedure TerminateSession(Command)
	
	Message = "";
	
	If Items.ListOfUsers.CurrentData.SessionNumber = InfoBaseSessionNumber Then
		// Don't drop current connection - or session will stay
		DoMessageBox(NStr("en = 'It is impossible to close the connection because it is your current connection'"));
		Return;
	EndIf;
	
	Disabled = InfobaseConnections.CloseInfobaseConnection(InfobaseConnections.GetInfobaseAdministrationParameters(),
										Items.ListOfUsers.CurrentData.Connection,
										Message);
	
	If NOT Disabled And Message <> "" Then
		DoMessageBox(Message);
	EndIf;
	
	FillList();
	
EndProcedure

&AtClient
Procedure RefreshExecute()
	
	FillList();
	
EndProcedure

&AtClient
Procedure OpenEventLog()
	
	If Items.ListOfUsers.SelectedRows.Count() > 1 Then
		DoMessageBox(NStr("en = 'To view event log select only one user.'"));
		Return;
	EndIf;
		
	CurrentData = Items.ListOfUsers.CurrentData;
	If CurrentData = Undefined Then
		DoMessageBox(NStr("en = 'It is impossible to open the event log for the specified user'"));
		Return;
	EndIf;
	
	UserName  = CurrentData.UserName;
	
	OpenForm("DataProcessor.EventLog.Form", New Structure("User", UserName));
	
EndProcedure

&AtClient
Procedure SortAscending()
	
	SortByColumn("Asc");
	
EndProcedure

&AtClient
Procedure SortDescending()
	
	SortByColumn("Desc");
	
EndProcedure

&AtClient
Procedure ListOfUsersSelection(Item, RowSelected, Field, StandardProcessing)
	
	User = Items.ListOfUsers.CurrentData.UserRef;
	
	If ValueIsFilled(User) Then
		OpenParameters = New Structure("Key", User);
		If TypeOf(User) = Type("CatalogRef.Users") Then
			OpenForm("Catalog.Users.Form.ItemForm", OpenParameters);
		ElsIf TypeOf(User) = Type("CatalogRef.ExternalUsers") Then
			OpenForm("Catalog.ExternalUsers.Form.ItemForm", OpenParameters);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure InformationBaseAdministrationParameters(Command)
	
	OpenForm("CommonForm.InfobaseServerAdministrationSettings");
	
EndProcedure
