
// This procedure fills the list of active users and sets the current row
&AtClient
Procedure FillList()
	// Keeping the current session to restore the position
	CurrentSession = Undefined;
	CurrentData = Items.UsersList.CurrentData;
	If CurrentData <> Undefined Then
		CurrentSession = CurrentData.Session;
	EndIf;
	
	FillUsersList();
	
	// Restoring the current row by the kept session
	If CurrentSession <> Undefined Then
		SearchStructure = New Structure;
		SearchStructure.Insert("Session", CurrentSession);
		FoundSessions = UsersList.FindRows(SearchStructure);
		If FoundSessions.Count() = 1 Then
			Items.UsersList.CurrentRow = FoundSessions[0].GetID();
			Items.UsersList.SelectedRows.Clear();
			Items.UsersList.SelectedRows.Add(Items.UsersList.CurrentRow);
		EndIf;
	EndIf;
EndProcedure

&AtClient
Procedure OpenEventLog()
	EventLog = OpenForm("DataProcessor.EventLog.Form");
EndProcedure

&AtClient
Procedure OpenEventLogByUser()
	CurrentData = Items.UsersList.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	UserName  = CurrentData.UserName;
	
	OpenForm("DataProcessor.EventLog.Form", New Structure("User", UserName));
EndProcedure

&AtClient
Procedure RefreshExecute()
	FillList();
EndProcedure

&AtClient
Procedure SortByColumn(Direction)
	Column = Items.UsersList.CurrentControl;
	If Column = Undefined Then
		Return;
	EndIf;
	
	SortColumnName = Column.Name;
	SortDirection = Direction;
	
	FillList();
EndProcedure

&AtClient
Procedure SortAsc()
	SortByColumn("Asc");
EndProcedure

&AtClient
Procedure SortDesc()
	SortByColumn("Desc");
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	// Insert the handler content.
	SortColumnName = "StartedAt";
	SortDirection = "Asc";
	FillUsersList();
EndProcedure

&AtServer
Procedure FillUsersList()
	VTUsersList = FormAttributeToValue("UsersList");
	VTUsersList.Clear();
	
	IBSessions = GetInfoBaseSessions();
	If IBSessions <> Undefined Then
		For Each IBSession In IBSessions Do
			StrUser = VTUsersList.Add();
			If TypeOf(IBSession.User) = Type("InfoBaseUser") Then
				StrUser.User = IBSession.User.Name;
				StrUser.UserName = IBSession.User.Name;
			EndIf;
			StrUser.Application   = ApplicationPresentation(IBSession.ApplicationName);
			StrUser.StartedAt = IBSession.SessionStarted;
			StrUser.Computer    = IBSession.ComputerName;
			StrUser.Session        = IBSession.SessionNumber;
			If IBSession.SessionNumber = InfoBaseSessionNumber() Then
				StrUser.UserPictureNumber = 0;
			Else
				StrUser.UserPictureNumber = 1;
			EndIf;
		EndDo;
	EndIf;
	ActiveUsersCount = IBSessions.Count();
	VTUsersList.Sort(SortColumnName + " " + SortDirection);
	ValueToFormAttribute(VTUsersList, "UsersList");
EndProcedure
