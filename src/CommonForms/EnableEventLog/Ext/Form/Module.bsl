////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("SelfTest") Then
		Return;
	EndIf;
	
	RefreshActiveUserCountServer();
	CheckList = Parameters.CheckList;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	AttachIdleHandler("RefreshActiveUserCount", 10);
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure OpenActiveUsersForm(Command)
	StandardSubsystemsClientOverridable.OpenActiveUserList();
	RefreshActiveUserCount();
EndProcedure

&AtClient
Procedure Retry(Command)
	Close();
	CommonUseClient.EventLogEnabled(CheckList, False);
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

&AtClient
Procedure RefreshActiveUserCount()
	RefreshActiveUserCountServer();
EndProcedure

&AtServer
Procedure RefreshActiveUserCountServer()
	InfoBaseSessions = GetInfoBaseSessions();
	
	If InfoBaseSessions = Undefined Then
		Items.ActiveUsersButton.Title = 1; 
	Else
		Items.ActiveUsersButton.Title = InfoBaseSessions.Count();
	EndIf;
EndProcedure
