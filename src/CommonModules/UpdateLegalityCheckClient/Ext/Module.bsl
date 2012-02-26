
// Displays user dialog with the confirmation of legality of obtained
// updates and closes the program if update has been obrained illegally
// (see parameter StopSystemOperation).
//
// Parameters
//  StopSystemOperation 	- Boolean - close 1C application, if user
//							  specified that update has been obtained illegally
//
// Value returned:
//   Boolean   				- True, if verification completed successfully (user
//							  confirmed, that update has been obtained legally)
//
Function CheckUpdateObtainingLegality(Val StopSystemOperation = False) Export
	
	If StandardSubsystemsClientSecondUse.ClientParameters().ThisIsBasicConfigurationVersion Then
		Return True;
	EndIf;
	
	Result = OpenFormModal("DataProcessor.UpdateLegalityCheck.Form",
							New Structure("ShowWarningAboutRestart,ForcedStart", 
											?(StopSystemOperation, True, False),
											True) );
	
	If Result <> True Then
		If StopSystemOperation Then
			Exit(False);
		EndIf;
		Return False;
	EndIf;
		
	Return True;
	
EndFunction

// Procedure for checking the legality of obtained updates.
// Should be called before infobase update.
//
Function ConfirmLegalityOfUpdateObtaining() Export
	
	If StandardSubsystemsClientSecondUse.ClientParameters().InfobaseUpdateRequired
		And StandardSubsystemsClientSecondUse.ClientParameters().ThisIsMasterNode
		And NOT UpdateLegalityCheckClient.CheckUpdateObtainingLegality(True) Then
			Return False;
	EndIf;
	
	Return True;
	
EndFunction
