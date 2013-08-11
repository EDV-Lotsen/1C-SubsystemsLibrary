////////////////////////////////////////////////////////////////////////////////
// Infobase version update subsystem.
// Client procedures and functions of an interactive infobase update.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// Checks whether the infobase must be updated, and if it is, executes an update. 
// If the update fails, the procedure suggests to terminate the application.
//
Procedure ExecuteInfoBaseUpdate() Export
	

	If Not CommonUseCached.CanUseSeparatedData() Then
		Return;
	EndIf;
	
	If Not StandardSubsystemsClientCached.ClientParameters().InfoBaseUpdateRequired Then
		Return;
	EndIf;
	
	Status(NStr("en = 'Executing the infobase update. 
	|Please wait...'"));
	DocumentUpdateDetails = Undefined;
	
	Try
		ExecutedUpdateHandlers = InfoBaseUpdate.ExecuteInfoBaseUpdate();
	Except
		ErrorMessageText = StringFunctionsClientServer.SubstituteParametersInString(NStr(
			"en = 'Error updating the infobase:
			|
			|%1
			|
			|See the event log for details.'"), 
			BriefErrorDescription(ErrorInfo()));
		
		Raise ErrorMessageText;
	EndTry;
	
	Status(NStr("en = 'The infobase update completed successfully.'"));
		
	If ExecutedUpdateHandlers <> Undefined Then	
		RefreshInterface();
	EndIf;
	
	If ExecutedUpdateHandlers <> "" Then	
		OpenForm("CommonForm.UpdateDetails", 
			New Structure("ExecutedUpdateHandlers", ExecutedUpdateHandlers));
	EndIf;
	
EndProcedure

// If there are update details that were not shown and the user does not disable
// showing details, the UpdateDetails form must be opened.
//
Procedure ShowUpdateDetails() Export
	
	If Not CommonUseCached.CanUseSeparatedData() Then
		Return;
	EndIf;
	
	ClientParameters = StandardSubsystemsClientCached.ClientParameters();
	If Not ClientParameters.Property("ShowUpdateDetails")
		Or Not ClientParameters.ShowUpdateDetails Then
		
		Return;
	EndIf;
	
	OpenForm("CommonForm.UpdateDetails"); 
	
EndProcedure

// Checks whether the infobase can be updated.
//
Function CanExecuteInfoBaseUpdate() Export
	
	Result = StandardSubsystemsClientCached.ClientParameters().InfoBaseLockedForUpdate;
	If Result Then
		Message = NStr("en = 'Infobase is locked to execute the configuration update. The application will be terminated.
		 |Please contact your infobase administrator for details.'");
		DoMessageBox(Message);
	EndIf;
	
	Return Not Result;
	
EndFunction
