
///////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS OF INTERACTIVE INFOBASE UPDATE

// Check, if there is a necessity to update infobase, and
// if required - run update.
// If update was not successful, then procedure suggests to close the session.
//
Procedure RunInfobaseUpdate() Export
	
	If Not StandardSubsystemsClientSecondUse.ClientParameters().InfobaseUpdateRequired Then
		Return;
	EndIf;
	
	Status(NStr("en = 'Please wait updating the infobase...'"));
	UpdateDetailsDocument = Undefined;
	
	Try
		ExecutedUpdateHandlers = InfobaseUpdate.RunInfobaseUpdate();
	Except
		ErrorMessageText = StringFunctionsClientServer.SubstitureParametersInString(NStr(
		"en = 'Error occurred while updating the infobase:
         |
         |%1
         |
         |See Event Log for details.'"), 
		
		DetailErrorDescription(ErrorInfo()));
		
		Raise ErrorMessageText;
	EndTry;
	
	Status(NStr("en = 'Infobase update completed successfully.'"));
		
	If ExecutedUpdateHandlers <> Undefined Then	
		RefreshInterface();
	EndIf;
	If ExecutedUpdateHandlers <> "" Then	
		OpenForm("CommonForm.UpdateDetails", 
			New Structure("ExecutedUpdateHandlers", ExecutedUpdateHandlers));
	EndIf;
	
EndProcedure

// Check if infobase update can be performed.
//
Function RunningInfobaseUpdatePermitted() Export
	
	Result = StandardSubsystemsClientSecondUse.ClientParameters().InformationBaseLockedForUpdate;
	
	If Result Then
		Message = NStr("en = 'Infobase is locked for the configuration update. The system will now shut down.
                        |Contact system administrator for details. '");
		DoMessageBox(Message);
	EndIf;
	
	Return NOT Result;
	
EndFunction
