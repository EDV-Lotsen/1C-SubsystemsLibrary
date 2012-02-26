
////////////////////////////////////////////////////////////////////////////////
// Command handlers

&AtClient
Procedure WriteExecute()
	
	ClearMessages();
	
	If Object.BlockNewConnections Then
		
		// of checking of lock set possibility
		If ValueIsFilled(Object.LockEnding) And Object.LockBegin > Object.LockEnding Then
			CommonUseClientServer.MessageToUser(NStr("en = 'End date block cannot be earlier than start date block. Block has not been set up.'"));
			Return;
		EndIf;
		
		Try
			CheckBlockPreconditions();
		Except
			CommonUseClientServer.MessageToUser(ErrorInfo().Description);
			Return;
		EndTry;
		
		QuestionText = NStr("en = 'Upon setting block system will require exit all users (including you) for the period of blocking.
                             |Do you really want to set up blocking?'");
		
		QuestionTitle = NStr("en = 'Setting blocking of the connection  with information base '");
		
		Response = DoQueryBox(QuestionText, QuestionDialogMode.YesNoCancel, 60, DialogReturnCode.No,
		               QuestionTitle);
		
		If Response <> DialogReturnCode.Yes Then
			Return;
		EndIf;
		
	EndIf;
	
	SetRemoveLock();
	
	InfobaseConnectionsClient.SetUserSessionsTerminationIdleHandler(
		Object.BlockNewConnections);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures

&AtServer
Procedure SetRemoveLock()
	
	FormAttributeToValue("Object").RunSetup();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES - FORM EVENTS HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	If CommonUse.FileInformationBase() Then
		Items.InformationBaseAdministrationParameters.Visible = False;
	EndIf;
	
	DataProcessor = FormAttributeToValue("Object");
	DataProcessor.GetBlockParameters();
	
	ValueToFormAttribute(DataProcessor, "Object");
	
EndProcedure

&AtClient
Procedure ActiveUsers(Command)
	
	OpenForm("DataProcessor.ActiveUsers.Form",,ThisForm);
	
EndProcedure

&AtServerNoContext
Procedure CheckBlockPreconditions() Export
	
	If CommonUse.FileInformationBase() Then
		InfobaseConnectionsTitles = "";
		If NOT ActiveOnlyClientApplications(InfobaseConnectionsTitles) Then
			TextOfMessage = StringFunctionsClientServer.SubstitureParametersInString(
				NStr("en = 'There are active connections that cannot be completed.
                      |Block is not set up.""%1'"), 
				InfobaseConnectionsTitles);
			Raise TextOfMessage;
		EndIf;
	EndIf;

EndProcedure

&AtServerNoContext
Function ActiveOnlyClientApplications(InfobaseConnectionsTitles)
	
	Result = True;
	InfobaseConnectionsTitles = "";
	For each Connection In GetInfoBaseConnections() Do
		If Connection.ConnectionNumber = InfoBaseConnectionNumber() Then
			Continue;
		EndIf;
		If Connection.ApplicationName <> "1cv8" And Connection.ApplicationName <> "1cv8c" And
			Connection.ApplicationName <> "WebClient" Then
			InfobaseConnectionsTitles = InfobaseConnectionsTitles + Chars.LF + " - " + Connection;
			Result = False;
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

&AtClient
Procedure InformationBaseAdministrationParameters(Command)
	
	OpenForm("CommonForm.InfobaseServerAdministrationSettings");
	
EndProcedure
