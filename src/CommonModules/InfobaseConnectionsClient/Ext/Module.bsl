////////////////////////////////////////////////////////////////////////////////
// User sessions subsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// Opens the infobase (and/or cluster) administration parameters input form.
//
// Parameters:
// OnCloseNotifyDescription                      - NotifyDescription - Handler that will be called 
//                                                 once the administration parameters are entered.
// PromptForInfobaseAdministrationParameters           - Boolean - Flag specifying whether infobase 
//                                                 administration parameters must be entered.
// PromptForInfobaseAdministrationParameters           - Boolean - Flag specifying whether cluster 
//                                                 administration parameters must be entered.
// AdministrationParameters                      - Structure - Administration parameters entered earlier.
// Title                                         - String - Form title that explains the purpose of
//                                                 requesting the administration parameters. 
// CommentLabel                                  - String - Description of the action in whose context
//                                                 the administration parameters are requested.
//
Procedure ShowAdministrationParameters(OnCloseNotifyDescription, PromptForInfobaseAdministrationParameters = True,
	PromptForClusterAdministrationParameters = True, AdministrationParameters = Undefined,
	Title = "", CommentLabel = "") Export
	
	FormParameters = New Structure;
	FormParameters.Insert("PromptForInfobaseAdministrationParameters", PromptForInfobaseAdministrationParameters);
	FormParameters.Insert("PromptForClusterAdministrationParameters", PromptForClusterAdministrationParameters);
	FormParameters.Insert("AdministrationParameters", AdministrationParameters);
	FormParameters.Insert("Title", Title);
	FormParameters.Insert("CommentLabel", CommentLabel);
	
	OpenForm("CommonForm.ApplicationAdministrationParameters", FormParameters,,,,,OnCloseNotifyDescription);
	
EndProcedure

#EndRegion

#Region InternalInterface

// Executes operations before the system start.
Procedure BeforeStart(Parameters) Export
	
	ClientParameters = StandardSubsystemsClientCached.ClientParametersOnStart();
	
	If Not ClientParameters.Property("DataAreaSessionsLocked") Then
		Return;
	EndIf;
	
	Parameters.InteractiveHandler = New NotifyDescription(
		"BeforeStartInteractiveHandler", ThisObject);
	
EndProcedure

// Executes operations during the system start.
Procedure AfterStart() Export
	
	RunParameters = StandardSubsystemsClientCached.ClientParametersOnStart();
	If Not RunParameters.CanUseSeparatedData Then
		Return;
	EndIf;
	
	If GetClientConnectionSpeed() <> ClientConnectionSpeed.Normal Then
		Return;
	EndIf;
	
	LockMode = RunParameters.SessionLockParameters;
	CurrentTime = LockMode.CurrentSessionDate;
	If LockMode.Use 
		 And (Not ValueIsFilled(LockMode.Begin) Or CurrentTime >= LockMode.Begin) 
		 And (Not ValueIsFilled(LockMode.End) Or CurrentTime <= LockMode.End) Then
		// If the user logged on to a locked infobase, they must have used the /UC key.
		// Sessions by these users should not be terminated.
		Return;
	EndIf;
	
	AttachIdleHandler("SessionTerminationModeManagement", 60);
	
EndProcedure

// Processes start parameters related to allowing or prohibiting infobase connections.
//
// Parameters
//  LaunchParameterValue - String - primary start parameter.
//  LaunchParameters     - Array  - additional start parameters separated by semicolons.
//
// Returns:
//   Boolean - True if system start must be canceled.
//
Function ProcessLaunchParameters(Val LaunchParameterValue, Val LaunchParameters) Export

	RunParameters = StandardSubsystemsClientCached.ClientParametersOnStart();
	If Not RunParameters.CanUseSeparatedData Then
		Return False;
	EndIf;
	
	// Processing the application start parameters (ProhibitUserLogon and AllowUserLogon)
	If LaunchParameterValue = Upper("AllowUserLogon") Then
		
		If Not InfobaseConnectionsServerCall.AllowUserLogon() Then
			MessageText = NStr("en = 'AllowUserLogon start parameter is not processed. Insufficient rights for infobase administration.'");
			ShowMessageBox(,MessageText);
			Return False;
		EndIf;
		
		EventLogOperationsClient.AddMessageForEventLog(InfobaseConnectionsClientServer.EventLogMessageText(),,
			NStr("en = 'The application started with AllowUserLogon parameter. The application will be terminated.'"), ,True);
		Exit(False);
		Return True;
		
	// The parameter can contain two additional parts separated by semicolons: 
	// name and password of the infobase administrator on whose behalf a connection 
	// to the server cluster is established in the client/server mode. 
	// These parameters must be passed if the current user is not an infobase administrator.
	// For usage examples, see the TerminateSessions() procedure.
	ElsIf LaunchParameterValue = Upper("TerminateSessions") Then
		
		// As the lock is not set yet, a session termination handler was enabled for this user during the logon.
		// Disabling it now. 
		// Instead, enabling the TerminateSessions handler for this user, 
		// making sure that this user's session will be terminated last.
		DetachIdleHandler("SessionTerminationModeManagement");
		
		If Not InfobaseConnectionsServerCall.SetConnectionLock() Then
			MessageText = NStr("en = 'TerminateSessions start parameter is not processed. Insufficient rights for infobase administration.'");
			ShowMessageBox(,MessageText);
			Return False;
		EndIf;
		
		AttachIdleHandler("TerminateSessions", 60);
		TerminateSessions();
		Return False; // Proceeding with the application start
		
	EndIf;
	Return False;
	
EndFunction

// Enables the SessionTerminationModeManagement or TerminateSessions idle handler, 
// depending on the SetConnectionLock parameter.
//
Procedure SetSessionTerminationHandlers(Val SetConnectionLock) Export
	
	SetUserTerminationInProgressFlag(SetConnectionLock);
	If SetConnectionLock Then
		// As the lock is not set yet, a session termination handler was enabled for this user during the logon.
		// Disabling it now. 
		// Instead, enabling the TerminateSessions handler for this user, 
		// making sure that this user's session will be terminated last.
		
		DetachIdleHandler("SessionTerminationModeManagement");
		AttachIdleHandler("TerminateSessions", 60);
		TerminateSessions();
	Else
		DetachIdleHandler("TerminateSessions");
		AttachIdleHandler("SessionTerminationModeManagement", 60);
	EndIf;
	
EndProcedure

// Terminates the last remaining session run by the administrator who initiated user session termination.
//
Procedure TerminateThisSession(DisplayQuestion = True) Export
	
	SetUserTerminationInProgressFlag(False);
	DetachIdleHandler("TerminateSessions");
	
	If Not DisplayQuestion Then 
		Exit(False);
		Return;
	EndIf;
	
	Notification = New NotifyDescription("TerminateThisSessionCompletion", ThisObject);
	MessageText = NStr("en = 'User logon is not currently allowed. Terminate this session?'");
	Title = NStr("en = 'Terminate current session'");
	ShowQueryBox(Notification, MessageText, QuestionDialogMode.YesNo, 60, DialogReturnCode.Yes, Title, DialogReturnCode.Yes);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Handlers of the conditional subsystem calls

// The procedure is called during an unsuccessful attempt to set exclusive mode in a file infobase.
//
// Parameters:
//  Notification - NotifyDescription - describes the object which must be passed control 
//                                     after closing this form.
//
Procedure OnOpenExclusiveModeSetErrorForm(Notification) Export
	
	OpenForm("DataProcessor.ApplicationLock.Form.ExclusiveModeSettingError",
		, , , , , Notification);
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// SL event handlers

// The procedure is called when a user starts working with a data area interactively.
//
// Parameters:
//  FirstParameter   - String - first start parameter value
//                              (before the first semicolon, in uppercase).
//  LaunchParameters - Array -  arrays of semicolon-separated strings in the start parameter 
//                              passed to the application using the /C command-line key.
//  Cancel           - Boolean (return value). If True, the OnStart event processing is canceled.
//
Procedure LaunchParametersOnProcess(FirstParameter, LaunchParameters, Cancel) Export
	
	Cancel = Cancel Or ProcessLaunchParameters(FirstParameter, LaunchParameters);
	
EndProcedure

// Replaces the default notification with a custom form containing the active user list.
//
// Parameters:
//  FormName - String (return value).
//
Procedure ActiveUserFormOnDefine(FormName) Export
	
	FormName = "DataProcessor.ActiveUsers.Form.ActiveUsersListForm";
	
EndProcedure

///////////////////////////////////////////////////////////////////////////////
// BaseFunctionality subsystem event handlers.

// Sets the SessionTerminationInProgress variable to Value.
//
// Parameters
//   Value - Boolean - value to be set.
//
Procedure SetUserTerminationInProgressFlag(Value) Export
	
	If TypeOf(UserSessionTerminationParameters) <> Type("Structure") Then
		UserSessionTerminationParameters = New Structure;
	EndIf;
	
	UserSessionTerminationParameters.Insert("SessionTerminationInProgress", Value);
	
EndProcedure

Function SessionTerminationInProgress() Export
	
	Return TypeOf(UserSessionTerminationParameters) = Type("Structure")
		And UserSessionTerminationParameters.Property("SessionTerminationInProgress")
		And UserSessionTerminationParameters.SessionTerminationInProgress;
	
EndFunction

Function SavedAdministrationParameters() Export
	
	AdministrationParameters = Undefined;
	
	If TypeOf(UserSessionTerminationParameters) = Type("Structure")
		And UserSessionTerminationParameters.Property("AdministrationParameters") Then
		
		AdministrationParameters = UserSessionTerminationParameters.AdministrationParameters;
		
	EndIf;
		
	Return AdministrationParameters;
	
EndFunction

Procedure SaveAdministrationParameters(Value) Export
	
	If TypeOf(UserSessionTerminationParameters) <> Type("Structure") Then
		UserSessionTerminationParameters = New Structure;
	EndIf;
	
	UserSessionTerminationParameters.Insert("AdministrationParameters", Value);

EndProcedure

///////////////////////////////////////////////////////////////////////////////
// Notification handlers.

// Suggests to remove the application lock and log on, or to shut down the application.
Procedure BeforeStartInteractiveHandler(Parameters, NotDefined) Export
	
	ClientParameters = StandardSubsystemsClientCached.ClientParametersOnStart();
	
	QuestionText   = ClientParameters.LogonSuggestion;
	MessageText = ClientParameters.DataAreaSessionsLocked;
	
	If Not IsBlankString(QuestionText) Then
		Buttons = New ValueList();
		Buttons.Add(DialogReturnCode.Yes, NStr("en = 'Log on'"));
		If ClientParameters.CanUnlock Then
			Buttons.Add(DialogReturnCode.No, NStr("en = 'Remove lock and log on'"));
		EndIf;
		Buttons.Add(DialogReturnCode.Cancel, NStr("en = 'Cancel'"));
		
		ResponseHandler = New NotifyDescription(
			"AfterAnsweringLogonOrUnlock", ThisObject, Parameters);
		
		ShowQueryBox(ResponseHandler, QuestionText, Buttons, 15,
			DialogReturnCode.Cancel,, DialogReturnCode.Cancel);
		Return;
	Else
		Parameters.Cancel = True;
		ShowMessageBox(
			StandardSubsystemsClient.NotificationWithoutResult(Parameters.ContinuationHandler),
			MessageText, 15);
	EndIf;
	
EndProcedure

// Continues from the above procedure.
Procedure AfterAnsweringLogonOrUnlock(Answer, Parameters) Export
	
	If Answer = DialogReturnCode.Yes Then // Logging on to the locked application
		
	ElsIf Answer = DialogReturnCode.No Then // Removing the application lock and logging on
		InfobaseConnectionsServerCall.SetDataAreaSessionLock(
			New Structure("Use", False));
	Else
		Parameters.Cancel = True;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationHandler);
	
EndProcedure

Procedure AskOnTermination(MessageText) Export
	
	QuestionText = NStr("en = '%1
	 |Terminate session?'");
	QuestionText = StringFunctionsClientServer.SubstituteParametersInString(QuestionText, MessageText);
	NotifyDescription = New NotifyDescription("AskQuestionOnTerminateCompletion", ThisObject);
	ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo, 30, DialogReturnCode.Yes);
	
EndProcedure

Procedure AskQuestionOnTerminateCompletion(Answer, AdditionalParameters) Export
	
	If Answer = DialogReturnCode.Yes Then
		StandardSubsystemsClient.SkipExitConfirmation();
		Exit(True, False);
	EndIf;
	
EndProcedure

Procedure TerminateThisSessionCompletion(Answer, Parameters) Export
	
	If Answer <> DialogReturnCode.No Then
		StandardSubsystemsClient.SkipExitConfirmation();
		Exit(False);
	EndIf;
	
EndProcedure	

#EndRegion