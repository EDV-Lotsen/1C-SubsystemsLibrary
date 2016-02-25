&AtClient
Var AdministrationParameters, PromptForInfobaseAdministrationParameters;

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	If Not CommonUse.OnCreateAtServer(ThisObject, Cancel, StandardProcessing) Then
		Return;
	EndIf;
	
	Parameters.Property("NotifyOnClose", NotifyOnClose);
	
	InfobaseSessionNumber = InfobaseSessionNumber();
	ConditionalAppearance.Items[0].Filter.Items[0].RightValue = InfobaseSessionNumber;
	
	If CommonUse.FileInfobase()
		Or Not ((Not CommonUseCached.SessionWithoutSeparators() And Users.InfobaseUserWithFullAccess())
		Or Users.InfobaseUserWithFullAccess(, True)) Then
		
		Items.TerminateSession.Visible = False;
		Items.TerminateSessionContext.Visible = False;
		
	EndIf;
	
	If CommonUseCached.CanUseSeparatedData() Then
		Items.UserListDataSeparation.Visible = False;
	EndIf;
	
	SortingColumnName = "SessionStarted";
	SortDirection = "Asc";
	
	FillConnectionFilterSelectionList();
	If Parameters.Property("ApplicationNameFilter") Then
		If Items.ApplicationNameFilter.ChoiceList.FindByValue(Parameters.ApplicationNameFilter) <> Undefined Then
			ApplicationNameFilter = Parameters.ApplicationNameFilter;
		EndIf;
	EndIf;
	
	FillUserList();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	PromptForInfobaseAdministrationParameters = True;
EndProcedure

&AtClient
Procedure OnClose()
	If NotifyOnClose Then
		NotifyOnClose = False;
		NotifyChoice(Undefined);
	EndIf;
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure ApplicationNameFilterOnChange(Item)
	FillList();
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// UserList table item event handlers

&AtClient
Procedure UserListChoice(Item, SelectedRow, Field, StandardProcessing)
	OpenUserFromList();
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure TerminateSession(Command)
	
	SessionToTerminate = Items.UserList.CurrentData.Session;
	
	If SessionToTerminate = InfobaseSessionNumber Then
		ShowMessageBox(,NStr("en = 'Cannot terminate the current session. To exit the application, close the main application window.'"));
		Return;
	EndIf;
	
	StandardProcessing = True;
	
	EventHandlers = CommonUseClient.InternalEventHandlers(
		"StandardSubsystems.UserSessions\OnTerminateSession");
	
	For Each Handler In EventHandlers Do
		Handler.Module.OnTerminateSession(ThisObject, SessionToTerminate, StandardProcessing);
	EndDo;
	
	If StandardProcessing Then
		
		If PromptForInfobaseAdministrationParameters Then
			
			NotifyDescription = New NotifyDescription("TerminateSessionContinuation", ThisObject);
			FormTitle = NStr("en = 'Terminate session'");
			CommentLabel = NStr("en = 'For session termination, enter the
				|server cluster administration parameters'");
			InfobaseConnectionsClient.ShowAdministrationParameters(NotifyDescription, False,, AdministrationParameters, FormTitle, CommentLabel);
			
		Else
			
			TerminateSessionContinuation(AdministrationParameters);
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure RefreshExecute()
	
	FillList();
	
EndProcedure

&AtClient
Procedure OpenEventLog()
	
	If Items.UserList.SelectedRows.Count() > 1 Then
		ShowMessageBox(,NStr("en = 'To access the event log, select a user from the list.'"));
		Return;
	EndIf;
		
	CurrentData = Items.UserList.CurrentData;
	If CurrentData = Undefined Then
		ShowMessageBox(,NStr("en = 'Cannot open the event log for the selected user.'"));
		Return;
	EndIf;
	
	UserName  = CurrentData.UserName;
	OpenForm("DataProcessor.EventLog.Form", New Structure("User", UserName));
	
EndProcedure

&AtClient
Procedure SortAsc()
	
	SortByColumn("Asc");
	
EndProcedure

&AtClient
Procedure SortDesc()
	
	SortByColumn("Desc");
	
EndProcedure

&AtClient
Procedure OpenUser(Command)
	OpenUserFromList();
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.UserList.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("UserList.Session");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = 0;

	Item.Appearance.SetParameterValue("Font", New Font(WindowsFonts.DefaultGUIFont, , , True, False, False, False, ));

EndProcedure

&AtClient
Procedure FillList()
	
	// Saving the current session data that will be used to restore the row position
	CurrentSession = Undefined;
	CurrentData = Items.UserList.CurrentData;
	
	If CurrentData <> Undefined Then
		CurrentSession = CurrentData.Session;
	EndIf;
	
	FillUserList();
	
	// Restoring the current row position based on the saved session data
	If CurrentSession <> Undefined Then
		TheStructureOfTheSearch = New Structure;
		TheStructureOfTheSearch.Insert("Session", CurrentSession);
		FoundSessions = UserList.FindRows(TheStructureOfTheSearch);
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
Procedure FillConnectionFilterSelectionList()
	ApplicationNames = New Array;
	ApplicationNames.Add("1CV8");
	ApplicationNames.Add("1CV8C");
	ApplicationNames.Add("WebClient");
	ApplicationNames.Add("Designer");
	ApplicationNames.Add("COMConnection");
	ApplicationNames.Add("WSConnection");
	ApplicationNames.Add("BackgroundJob");
	ApplicationNames.Add("SystemBackgroundJob");
	ApplicationNames.Add("SrvrConsole");
	ApplicationNames.Add("COMConsole");
	ApplicationNames.Add("JobScheduler");
	ApplicationNames.Add("Debugger");
	ApplicationNames.Add("OpenIDProvider");
	ApplicationNames.Add("RAS");
	
	ChoiceList = Items.ApplicationNameFilter.ChoiceList;
	For Each ApplicationName In ApplicationNames Do
		ChoiceList.Add(ApplicationName, ApplicationPresentation(ApplicationName));
	EndDo;
EndProcedure

&AtServer
Procedure FillUserList()
	
	UserList.Clear();
	
	If Not CommonUseCached.DataSeparationEnabled()
	 Or CommonUseCached.CanUseSeparatedData() Then
		
		Users.FindAmbiguousInfobaseUsers();
	EndIf;
	
	InfobaseSessions = GetInfobaseSessions();
	ActiveUserCount = InfobaseSessions.Count();
	
	FilterApplicationNames = ValueIsFilled(ApplicationNameFilter);
	If FilterApplicationNames Then
		ApplicationNames = StringFunctionsClientServer.SplitStringIntoSubstringArray(ApplicationNameFilter, ",");
	EndIf;
	
	For Each InfobaseSession In InfobaseSessions Do
		If FilterApplicationNames
			And ApplicationNames.Find(InfobaseSession.ApplicationName) = Undefined Then
			ActiveUserCount = ActiveUserCount - 1;
			Continue;
		EndIf;
		
		UserRow = UserList.Add();
		
		UserRow.Application    = ApplicationPresentation(InfobaseSession.ApplicationName);
		UserRow.SessionStarted = InfobaseSession.SessionStarted;
		UserRow.Computer       = InfobaseSession.ComputerName;
		UserRow.Session        = InfobaseSession.SessionNumber;
		UserRow.Connection     = InfobaseSession.ConnectionNumber;
		
		If TypeOf(InfobaseSession.User) = Type("InfobaseUser")
		   And ValueIsFilled(InfobaseSession.User.Name) Then
			
			UserRow.User     = InfobaseSession.User.Name;
			UserRow.UserName = InfobaseSession.User.Name;
			UserRow.UserRef  = FindRefByUserID(
				InfobaseSession.User.UUID);
			
			If CommonUseCached.DataSeparationEnabled() 
				And Users.InfobaseUserWithFullAccess(, True) Then
				
				UserRow.DataSeparation = DataSeparationValuesToString(
					InfobaseSession.User.DataSeparation);
			EndIf;
			
		Else
			UnspecifiedProperties = UsersInternal.UnspecifiedUserProperties();
			UserRow.User          = UnspecifiedProperties.FullName;
			UserRow.UserName      = "";
			UserRow.UserRef       = UnspecifiedProperties.Ref;
		EndIf;

		If InfobaseSession.SessionNumber = InfobaseSessionNumber Then
			UserRow.UserPictureNumber = 0;
		Else
			UserRow.UserPictureNumber = 1;
		EndIf;
		
	EndDo;
	
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
	
	// Cannot access the separated catalog from a shared session
	If CommonUseCached.DataSeparationEnabled() 
		And Not CommonUseCached.CanUseSeparatedData() Then
		Return Undefined;
	EndIf;	
	
	Query = New Query;
	
	QueryTextPattern = "SELECT
					|	Ref AS Ref
					|FROM
					|	%1
					|WHERE
					|	InfobaseUserID = &ID";
					
	QueryByUsersText = 
			StringFunctionsClientServer.SubstituteParametersInString(
					QueryTextPattern,
					"Catalog.Users");
	
	ExternalUserQueryText = 
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
	
	Query.Text = ExternalUserQueryText;
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

&AtClient
Procedure TerminateSessionContinuation(Result, AdditionalParameters = Undefined) Export
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	AdministrationParameters = Result;
	
	Message = "";
	SessionNumberToTerminate = Items.UserList.CurrentData.Session;
	
	Filter = New Structure("Number", SessionNumberToTerminate);
	ClientConnectedViaWebServer = CommonUseClient.ClientConnectedViaWebServer();
	
	Try
		If ClientConnectedViaWebServer Then
			DeleteInfobaseSessionsAtServer(AdministrationParameters, Filter)
		Else
			ClusterAdministrationClientServer.DeleteInfobaseSessions(AdministrationParameters,, Filter);
		EndIf;
	Except
		PromptForInfobaseAdministrationParameters = True;
		Raise;
	EndTry;
	
	PromptForInfobaseAdministrationParameters = False;
	NotificationText = NStr("en = 'Session %1 is terminated.'");
	NotificationText = StringFunctionsClientServer.SubstituteParametersInString(NotificationText, SessionNumberToTerminate);
	ShowUserNotification(NStr("en = 'Terminating session'"),, NotificationText);
	
	FillList();
	
EndProcedure

&AtServer
Procedure DeleteInfobaseSessionsAtServer(AdministrationParameters, Filter)
	
	ClusterAdministrationClientServer.DeleteInfobaseSessions(AdministrationParameters,, Filter);
	
EndProcedure

#EndRegion
