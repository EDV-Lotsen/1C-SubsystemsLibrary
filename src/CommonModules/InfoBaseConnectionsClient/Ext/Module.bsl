////////////////////////////////////////////////////////////////////////////////
//User sessions subsystem.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// Performs actions before the application launch.
//
//Procedure BeforeStart(Cancel) Export
//	
//	ClientParametersOnStart = StandardSubsystemsClientCached.ClientParametersOnStart();
//	MessageText = "";
//	If Not ClientParametersOnStart.Property("DataAreaSessionsLocked", MessageText) Then
//		Return;
//	EndIf;
//	
//	QuestionText = ClientParametersOnStart.SuggestUnlockingMessage;
//	If Not IsBlankString(QuestionText) Then
//		Buttons = New ValueList();
//		Buttons.Add(DialogReturnCode.Yes, NStr("en= 'Log on'"));
//		Buttons.Add(DialogReturnCode.No, NStr("en= 'Unlock and log on'"));
//		Buttons.Add(DialogReturnCode.Cancel, NStr("en = 'Cancel'"));
//		Response = DoQueryBox(QuestionText, Buttons, 15, DialogReturnCode.Cancel,, DialogReturnCode.Cancel);
//		If Response = DialogReturnCode.Yes Then // logging on to the locked application
//			Return;
//		ElsIf Response = DialogReturnCode.No Then // unlocking and loging on to the application
//			InfoBaseConnections.SetDataAreaSessionLock(New Structure("Use", False));
//			Return;
//		Else	
//			Exit(False); // exiting without restarting
//		EndIf;	
//	Else	
//		ShowMessageBox(, MessageText, 15);
//		Exit(False); // exiting without restarting
//	EndIf;
//	
//	Cancel = True;
//	
//EndProcedure

Procedure OnStart() Export
	
EndProcedure
//// Performs actions on the application start.
////
//Procedure OnStart() Export
//	
//	If Not CommonUseCached.CanUseSeparatedData() Then
//		Return;
//	EndIf;
//	
//	If GetClientConnectionSpeed() <> ClientConnectionSpeed.Normal Then
//		Return;	
//	EndIf;
//	
//	LockMode = StandardSubsystemsClientCached.ClientParameters().SessionLockParameters;
//	CurrentTime = LockMode.CurrentSessionDate;
//	If LockMode.Use 
//		 And (Not ValueIsFilled(LockMode.Start) Or CurrentTime >= LockMode.Start) 
//		 And (Not ValueIsFilled(LockMode.End) Or CurrentTime <= LockMode.End) Then
//		// Logon to the locked infobase meens that the user used the /UC switch. 
//		// The session started with the /UC switch must not be terminated.
//		Return;
//	EndIf;
//	
//	AttachIdleHandler("UserTerminiationControlMode", 60);	
//	
//EndProcedure

// Processes start parameters associated with session terminations and infobase connections.
//
// Parameters:
// LaunchParameterValue – String – main start parameter;
// LaunchParameters – Array – additional start parameters separated by
// the ; symbol.
//
// Returns:
// Boolean – True if application start must be canceled.
//
Function ProcessLaunchParameters(Val LaunchParameterValue, Val LaunchParameters) Export

	If Not CommonUseCached.CanUseSeparatedData() Then
		Return False;
	EndIf;
	
	// Processing the AllowUserLogon start parameter
	If LaunchParameterValue = Upper("AllowUserLogon") Then
		
		If Not InfoBaseConnections.AllowUserLogon() Then
			MessageText = NStr("en= 'The AllowUserLogon start parameter is not processed. You do not have administrative rights to the infobase.'");
			ShowMessageBox(, MessageText);
			Return False;
		EndIf;
		
		Exit(False);
		Return True;
		
	// Parameter can contain two additional parts separated by the ; symbol - 
	// the name and the password of the infobase administrator used to connect the server cluster 
	// in the client/server mode. They must be passed if 
	// the current user does not have administrative rights to the infobase.
	// See the TerminateSessions() procedure for details.
	ElsIf LaunchParameterValue = Upper("TerminateSessions") Then
		
		// The UserTerminiationControlMode idle handler was attached for
		// the current user because the data lock is not enabled yet. 
		// This handler must be detached because the TerminateSessions 
		// idle handler will be attached. This special handler takes into account the fact
		// that the current user session must be the last session to be terminated.
		DetachIdleHandler("UserTerminiationControlMode");
		
		If Not InfoBaseConnections.SetConnectionsLockExecute() Then
			MessageText = NStr("en= 'The AllowUserLogon start parameter is not processed. You do not have administrative rights to the infobase.'");
			ShowMessageBox(, MessageText);
			Return False;
		EndIf;
		
		AttachIdleHandler("TerminateSessions", 60);
		TerminateSessions();
		Return True;
		
	EndIf;
	
	Return False;
	
EndFunction

// Attaches the UserTerminiationControlMode or the TerminateSessions
// idle handler based on the SetConnectionsLock parameter.
//
Procedure SetSessionTerminationHandlers(Val SetConnectionsLock) Export
	
	SetSessionTerminationInProgressFlag(SetConnectionsLock);
	If SetConnectionsLock Then
		// The UserTerminiationControlMode idle handler was attached for
		// the current user because the data lock is not enabled yet. 
		// This handler must be detached because the TerminateSessions 
		// idle handler. This special handler takes into account the fact that the current user session must be the last session to be terminated.
		
		DetachIdleHandler("UserTerminiationControlMode");
		AttachIdleHandler("TerminateSessions", 60);
		TerminateSessions();
	Else
		DetachIdleHandler("TerminateSessions");
		AttachIdleHandler("UserTerminiationControlMode", 60);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

// Sets the SessionTerminationInProgress variable value.
//
// Parameters:
// Value - Boolean - new value.
//
Procedure SetSessionTerminationInProgressFlag(Value) Export
	
	SessionTerminationInProgress = Value;
	
EndProcedure	

// Internal use only.
Procedure BeforeStart(Parameters) Export
	
	ClientParameters = StandardSubsystemsClientCached.ClientParametersOnStart();
	
	If Not ClientParameters.Property("DataAreaSessionsLocked") Then
		Return;
	EndIf;
	
	Parameters.InteractiveProcessing = New NotifyDescription(
		"InteractiveProcessingSystemBeforeStart", ThisObject);
	
EndProcedure

// Internal use only.
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
		Return;
	EndIf;
	
	AttachIdleHandler("SessionTerminationControlMode", 60);
	
EndProcedure

// Internal use only.
Procedure InteractiveProcessingSystemBeforeStart(Parameters, NotDefined) Export
	
	ClientParameters = StandardSubsystemsClientCached.ClientParametersOnStart();
	
	QueryText   = ClientParameters.SuggestLogOn;
	MessageText = ClientParameters.DataAreaSessionsLocked;
	
	If Not IsBlankString(QueryText) Then
		Buttons = New ValueList();
		Buttons.Add(DialogReturnCode.Yes, NStr("en = 'log on'"));
		If ClientParameters.CanUnlock Then
			Buttons.Add(DialogReturnCode.No, NStr("en = 'Unlock and log on'"));
		EndIf;
		Buttons.Add(DialogReturnCode.Cancel, NStr("en = 'Cancel'"));
		
		ResponseHandler = New NotifyDescription(
			"AfterAnsweringQuestionLoginOrUnlock", ThisObject, Parameters);
		
		ShowQueryBox(ResponseHandler, QueryText, Buttons, 15,
			DialogReturnCode.Cancel,, DialogReturnCode.Cancel);
		Return;
	Else
		Parameters.Cancel = True;
		ShowMessageBox(
			StandardSubsystemsClient.NotificationWithoutResult(Parameters.ContinuationProcessor),
			MessageText, 15);
	EndIf;
	
EndProcedure

