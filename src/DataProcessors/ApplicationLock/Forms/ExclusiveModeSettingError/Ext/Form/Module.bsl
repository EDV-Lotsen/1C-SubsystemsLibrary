
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;

	ActiveUsersTemplate = NStr("en = 'Active users (%1)'");
	
	ActiveSessionCount = GetInfobaseSessions().Count();
	Items.ActiveUsers.Title = StringFunctionsClientServer.
		SubstituteParametersInString(ActiveUsersTemplate, ActiveSessionCount);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	AttachIdleHandler("UpdateActiveSessionCount", 30);
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure ActiveUsersClick(Item)
	
	OpenForm("DataProcessor.ActiveUsers.Form.ActiveUsersListForm");
	
EndProcedure

&AtClient
Procedure ActiveUsers2Click(Item)
	
	OpenForm("DataProcessor.ActiveUsers.Form.ActiveUsersListForm");
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure TerminateSessionsAndRestartApplication(Command)
	
	Items.GroupPages.CurrentPage = Items.Page2;
	CurrentWizardPage = "Page2";
	Items.FormRetryApplicationStart.Visible = False;
	Items.FormTerminateSessionsAndRestartApplication.Visible = False;
	
	// Setting the infobase lock parameters
	UpdateActiveSessionCount();
	LockFileInfobase();
	AttachIdleHandler("UserSessionTimeout", 60);
	
EndProcedure

&AtClient
Procedure CancelApplicationStart(Command)
	
	UnlockFileInfobase();
	
	Close(True);
	
EndProcedure

&AtClient
Procedure RetryApplicationStart(Command)
	
	Close(False);
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtClient
Procedure UpdateActiveSessionCount()
	
	Result = UpdateActiveServerSessionCount();
	If Result Then
		Close(False);
	EndIf;
	
EndProcedure

&AtServer
Function UpdateActiveServerSessionCount()
	
	If CurrentWizardPage = "Page2" Then
		ActiveUsers = "ActiveUsers2";
	Else
		ActiveUsers = "ActiveUsers";
	EndIf;

	InfobaseSessions = GetInfobaseSessions();
	ActiveSessionCount = InfobaseSessions.Count();
	Items[ActiveUsers].Title = StringFunctionsClientServer.
		SubstituteParametersInString(ActiveUsersTemplate, ActiveSessionCount);
	
	SessionsPreventingUpdateCount = 0;
	For Each InfobaseSession In InfobaseSessions Do
		
		If InfobaseSession.ApplicationName = "Designer" Then
			Continue;
		EndIf;
		
		SessionsPreventingUpdateCount = SessionsPreventingUpdateCount + 1;
	EndDo;
	
	If SessionsPreventingUpdateCount = 1 Then
		Return True;
	Else
		Return False;
	EndIf;
	
EndFunction

&AtClient
Procedure UserSessionTimeout()
	
	UserSessionTerminationDuration = UserSessionTerminationDuration + 1;
	
	If UserSessionTerminationDuration >= 3 Then
		UnlockFileInfobase();
		Items.GroupPages.CurrentPage = Items.Page1;
		CurrentWizardPage = "Page1";
		Items.ErrorMessageText.Title = NStr("en = 'Cannot update the application version as the following user sessions failed to terminate:'");
		Items.FormRetryApplicationStart.Visible = True;
		Items.FormTerminateSessionsAndRestartApplication.Visible = True;
		DetachIdleHandler("UserSessionTimeout");
		UserSessionTerminationDuration = 0;
	EndIf;
	
EndProcedure

&AtServer
Procedure LockFileInfobase()
	
	Object.ProhibitUserWorkTemporarily = True;
	Object.LockPeriodStart = CurrentSessionDate() + 2*60;
	Object.LockPeriodEnd = Object.LockPeriodStart + 5*60;
	Object.MessageForUsers = NStr("en = 'The application is locked for update purposes.'");
	
	Try
		FormAttributeToValue("Object").SetLock();
	Except
		WriteLogEvent(InfobaseConnectionsClientServer.EventLogMessageText(),
			EventLogLevel.Error,,, 
			DetailErrorDescription(ErrorInfo()));
		CommonUseClientServer.MessageToUser(BriefErrorDetails(ErrorDescription()), , );
	EndTry;
	
EndProcedure

&AtServer
Procedure UnlockFileInfobase()
	
	FormAttributeToValue("Object").Unlock();
	
EndProcedure

&AtServer
Function BriefErrorDetails(ErrorDescription)
	
	ErrorText = ErrorDescription;
	Position = Find(ErrorText, "}:");
	If Position > 0 Then
		ErrorText = TrimAll(Mid(ErrorText, Position + 2, StrLen(ErrorText)));
	EndIf;
	
	Return ErrorText;
EndFunction

#EndRegion
