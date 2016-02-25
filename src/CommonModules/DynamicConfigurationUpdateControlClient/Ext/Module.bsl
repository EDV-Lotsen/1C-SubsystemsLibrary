////////////////////////////////////////////////////////////////////////////////
// Dynamic configuration update control subsystem
//  
////////////////////////////////////////////////////////////////////////////////

#Region InternalInterface

// The procedure is executed when a user accesses a data area interactively 
// or starts the application in the local mode.
// It is called after OnStart handler execution.
// Attaches the idle handlers that are only required after OnStart.
//
Procedure AfterStart() Export
	
	AttachIdleHandler("InfobaseDynamicChangeCheckIdleHandler", 20 * 60); // once per 20 minutes
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

// The idle handler checks whether the infobase is updated dynamically 
// and informs the user when an update is detected.
// 
Procedure DynamicUpdateChecksIdleHandler() Export
	
	If Not DynamicConfigurationUpdateControlServerCall.DBConfigurationWasChangedDynamically() Then
		Return;
	EndIf;
		
	DetachIdleHandler("InfobaseDynamicChangeCheckIdleHandler");
	
	MessageText = NStr("en = 'The application is updated (the infobase configuration is changed).
								|It is recommended that you restart the application.
								|Restart now?'");
								
	NotifyDescription = New NotifyDescription("DynamicUpdateChecksIdleHandlerCompletion", ThisObject);
	ShowQueryBox(NotifyDescription, MessageText, QuestionDialogMode.YesNo);
	
EndProcedure

// Notification handler that is called from the InfobaseDynamicChangeCheckIdleHandler procedure.
//
Procedure DynamicUpdateChecksIdleHandlerCompletion(Answer, AdditionalParameters) Export
	
	If Answer = DialogReturnCode.Yes Then
		StandardSubsystemsClient.SkipExitConfirmation();
		Exit(True, True);
	EndIf;
	
	AttachIdleHandler("InfobaseDynamicChangeCheckIdleHandler", 20 * 60); // once per 20 minutes
	
EndProcedure

#EndRegion
