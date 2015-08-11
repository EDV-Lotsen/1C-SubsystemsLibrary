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
	
	Status(NStr("en='Executing the infobase update. "
"Please wait...'"));
	DocumentUpdateDetails = Undefined;
	
	Try
		ExecutedUpdateHandlers = InfoBaseUpdate.ExecuteInfoBaseUpdate();
	Except
		ErrorMessageText = StringFunctionsClientServer.SubstituteParametersInString(NStr("en='Error updating the infobase:"
""
"%1"
""
"See the event log for details.'"), 
			BriefErrorDescription(ErrorInfo()));
		
		Raise ErrorMessageText;
	EndTry;
	
	Status(NStr("en='The infobase update completed successfully.'"));
		
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
	
	ExecutedHandlers = InfoBaseUpdateServerCall.GetExecutedHandlers();
	
	If ExecutedHandlers = Undefined Then
		OpenForm("CommonForm.UpdateDetails"); 
	Else
		OpenForm("CommonForm.UpdateDetails", 
			New Structure("ExecutedUpdateHandlers", ExecutedHandlers));
		CommonUse.CommonSettingsStorageSave("UpdateInfoBase", "ExecutedHandlers", Undefined);
	EndIf;
	
EndProcedure

// Checks whether the infobase can be updated.
//
Function CanExecuteInfoBaseUpdate() Export
	
	Result = StandardSubsystemsClientCached.ClientParameters().InfoBaseLockedForUpdate;
	If Result Then
		Message = NStr("en='Infobase is locked to execute the configuration update. The application will be terminated."
"Please contact your infobase administrator for details or log in using a user with Full administrator role.'");
		ShowMessageBox(, Message);
	EndIf;
	
	Return Not Result;
	
EndFunction

// Internal use only.
Procedure StartInfoBaseUpdate(StandardProcessing, AdditionalParameters) Export
	ExecuteInfoBaseUpdate();
EndProcedure

// Internal use only.
Procedure UpdateInfobase(Parameters) Export
	
	ClientParameters = StandardSubsystemsClientCached.ClientParametersOnStart();
	If Not ClientParameters.CanUseSeparatedData Then
		CloseUpdateProgressFormIfOpened(Parameters);
		Return;
	EndIf;
	
	If ClientParameters.Property("InfoBaseUpdateRequired") 
	   Or ClientParameters.Property("SharedDataUpdateRequired") Then
		Parameters.InteractiveProcessing = New NotifyDescription(
			"StartInfoBaseUpdate", ThisObject);
	Else
		If ClientParameters.Property("LoadDataExchangeMessage") Then
			Restart = False;
			InfoBaseUpdateServerCall.UpdateInfoBase(, True, Restart);
			If Restart Then                                         
				Parameters.Cancel = True;
				Parameters.Restart = True;
			EndIf;
		EndIf;
		CloseUpdateProgressFormIfOpened(Parameters);
	EndIf;
	
EndProcedure     

// Internal use only.
Procedure CloseUpdateProgressFormIfOpened(Parameters)
	
	If Parameters.Property("InfoBaseUpdateProgressForm") Then
		If Parameters.InfoBaseUpdateProgressForm.IsOpen() Then
			Parameters.InfoBaseUpdateProgressForm.StartClosing();
		EndIf;
		Parameters.Delete("InfoBaseUpdateProgressForm");
	EndIf;
	
EndProcedure

// Internal use only.
Procedure LoadRefreshClientParameters(Parameters, NotSet) Export
	
	FormName = "DataProcessor.InfoBaseUpdate.Form.InfoBaseUpdateProgress";
	
	Form = OpenForm(FormName,,,,,, New NotifyDescription(
		"AfterCloseInfoBaseUpdateProgress", ThisObject, Parameters));
	
	Parameters.Insert("InfoBaseUpdateProgressForm", Form);
	
	Form.LoadRefreshClientParameters(Parameters);
	
EndProcedure

// Internal use only.
Procedure AfterCloseInfoBaseUpdateProgress(Result, Parameters) Export
	
	If TypeOf(Result) <> Type("Structure") Then
		Result = New Structure("Cancel, Restart", True, False);
	EndIf;
	
	If Result.Cancel Then
		Parameters.Cancel = True;
		If Result.Restart Then
			Parameters.Restart = True;
		EndIf;
	EndIf;
	
	//ExecuteNotifyProcessing(Parameters.ContinuationHandler);
	
EndProcedure

// Internal use only.
Procedure AfterStart() Export
	
	ClientParameters = StandardSubsystemsClientCached.ClientParametersOnStart();
	
	If ClientParameters.Property("ShowInvalidHandlersMessage")
		Or ClientParameters.Property("ShowNotProcessedHandlersMessage") Then
		AttachIdleHandler("ShowDeferredUpdateStatus", 2, True);
	EndIf;
	
EndProcedure     

// Internal use only.
Procedure BeforeStart(Parameters) Export
	
	ClientParameters = StandardSubsystemsClientCached.ClientParametersOnStart();
	
	If ClientParameters.Property("InfoBaseLockedForUpdate") Then
		Parameters.Cancel = True;
		Parameters.InteractiveProcessing = New NotifyDescription(
			"ShowMessageBoxAndContinue",
			StandardSubsystemsClient.ThisObject,
			ClientParameters.InfoBaseLockedForUpdate);
		
	ElsIf ClientParameters.Property("ClientParametersUpdateRequired") Then
		Parameters.InteractiveProcessing = New NotifyDescription(
			"LoadRefreshClientParameters", ThisObject, Parameters);
		
	ElsIf Find(Lower(LaunchParameter), Lower("RegisterFullChangeMOForSubordinateDIBNodes")) > 0 Then
		Parameters.Cancel = True;
		Parameters.InteractiveProcessing = New NotifyDescription(
			"ShowMessageBoxAndContinue",
			StandardSubsystemsClient.ThisObject,
			NStr("en='The RegisterFullChangeMOForSubordinateDIBNodes launch parameter"
"can be used only with the StartInfoBaseUpdate parameter.'"));
	EndIf;
	
EndProcedure

// Internal use only.
Procedure OnStart(Parameters) Export
	
	ClientParameters = StandardSubsystemsClientCached.ClientParametersOnStart();
	If Not ClientParameters.CanUseSeparatedData Then
		Return;
	EndIf;
	
	ShowUpdateDetails();
	
EndProcedure
