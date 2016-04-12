////////////////////////////////////////////////////////////////////////////////
// User sessions subsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region InternalProceduresAndFunctions

// Terminates active sessions if infobase connection lock is set.
// 
Procedure SessionTerminationModeManagement() Export

	// Getting the current lock parameter values
	CurrentMode = InfobaseConnectionsServerCall.SessionLockParameters();
	Locked = CurrentMode.Use;
	RunParameters = StandardSubsystemsClientCached.ClientParameters();
	
	If Not Locked Then
		Return;
	EndIf;
		
	LockBeginTime = CurrentMode.Begin;
	LockEndTime = CurrentMode.End;
	
	// Values of ExitWithConfirmationTimeout and StopTimeout are negative.
	// Therefore, "<=" operator is used to compare these parameters 
	// with (LockBeginTime - CurrentTime) difference, as this difference decreases over time.
	WaitTimeout                 = CurrentMode.SessionTerminationTimeout;
	ExitWithConfirmationTimeout = WaitTimeout / 3;
	StopSaaSTimeout             = 60; // one minute before the lock initiation.
	StopTimeout                 = 0; // at the moment of lock initiation.
	CurrentTime                 = CurrentMode.CurrentSessionDate;
	
	If LockEndTime <> '00010101' And CurrentTime > LockEndTime Then
		Return;
	EndIf;
	
	LockBeginTimeDate  = Format(LockBeginTime, "DLF=DD");
	LockBeginTimeTime = Format(LockBeginTime, "DLF=T");
	
	MessageText = InfobaseConnectionsClientServer.ExtractLockMessage(CurrentMode.Message);
	MessageText = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = 'Please complete your activities and save your data. The application will be terminated on %1 at %2. 
		|%3'"),
		LockBeginTimeDate, LockBeginTimeTime, MessageText);
	
	If Not RunParameters.DataSeparationEnabled
		And (Not ValueIsFilled(LockBeginTime) Or LockBeginTime - CurrentTime < StopTimeout) Then
		
		StandardSubsystemsClient.SkipExitConfirmation();
		Exit(False, True);
		
	ElsIf RunParameters.DataSeparationEnabled
		And (Not ValueIsFilled(LockBeginTime) Or LockBeginTime - CurrentTime < StopSaaSTimeout) Then
		
		StandardSubsystemsClient.SkipExitConfirmation();
		Exit(False, False);
		
	ElsIf LockBeginTime - CurrentTime <= ExitWithConfirmationTimeout Then
		
		InfobaseConnectionsClient.AskOnTermination(MessageText);
		
	ElsIf LockBeginTime - CurrentTime <= WaitTimeout Then
		
		ShowMessageBox(, MessageText, 30);
		
	EndIf;
	
EndProcedure

// Terminates active sessions upon timeout, and then terminates the current session.
//
Procedure TerminateSessions() Export

	// Getting the current lock parameter values
	CurrentMode = InfobaseConnectionsServerCall.SessionLockParameters(True);
	
	LockBeginTime = CurrentMode.Begin;
	LockEndTime = CurrentMode.End;
	CurrentTime = CurrentMode.CurrentSessionDate;
	
	If CurrentTime < LockBeginTime Then
		MessageText = NStr("en = 'User sessions will be locked at %1.'");
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(
			MessageText, LockBeginTime);
		ShowUserNotification(NStr("en = 'User sessions'"), 
			"e1cib/app/Processing.ApplicationLock", 
			MessageText, PictureLib.Information32);
		Return;
	EndIf;
		
	SessionCount = CurrentMode.SessionCount;
	If SessionCount <= 1 Then
		// All user sessions except the current one are terminated.
		// The session started with the TerminateSessions parameter should be terminated last.
		// This termination order is required for correct application update via a batch file.
		InfobaseConnectionsClient.SetUserTerminationInProgressFlag(False);
		Notify("UserSessions", New Structure("Status, SessionCount", "Done", SessionCount));
		InfobaseConnectionsClient.TerminateThisSession();
		Return;
	EndIf; 
	
	Locked = CurrentMode.Use;
	If Not Locked Then
		Return;
	EndIf;
	
	TerminationTimeout = - CurrentMode.SessionTerminationTimeout;
	DisconnectionTime = Not ValueIsFilled(LockBeginTime)
		Or LockBeginTime - CurrentTime <= TerminationTimeout;
		
	If Not DisconnectionTime Then
		
		MessageText = NStr("en = 'Active sessions: %1.
			|The next session check will be performed in one minute.'");
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(
			MessageText, SessionCount);
		ShowUserNotification(NStr("en = 'User sessions'"), 
			"e1cib/app/Processing.ApplicationLock", 
			MessageText, PictureLib.Information32);
		Notify("UserSessions", New Structure("Status, SessionCount", "Executing", SessionCount));
		Return;
	EndIf;
	
	// Once the session lock is enabled, all user sessions must be terminated.
	// Terminating connections for users that are still connected.
	DetachIdleHandler("TerminateSessions");
	
	Result = True;
	Try
		
		AdministrationParameters = InfobaseConnectionsClient.SavedAdministrationParameters();
		InfobaseConnectionsClientServer.DeleteAllSessionsExceptCurrent(AdministrationParameters);
		InfobaseConnectionsClient.SaveAdministrationParameters(Undefined);
		
	Except
		Result = False;
	EndTry;
	
	If Result Then
		InfobaseConnectionsClient.SetUserTerminationInProgressFlag(False);
		ShowUserNotification(NStr("en = 'User sessions'"), 
			"e1cib/app/Processing.ApplicationLock", 
			NStr("en = 'User sessions are terminated.'"), PictureLib.Information32);
		Notify("UserSessions", New Structure("Status, SessionCount", "Done", SessionCount));
		InfobaseConnectionsClient.TerminateThisSession();
	Else
		InfobaseConnectionsClient.SetUserTerminationInProgressFlag(False);
		ShowUserNotification(NStr("en = 'User sessions'"), 
			"e1cib/app/Processing.ApplicationLock", 
			NStr("en = 'Session termination failed. See the event log for details.'"), PictureLib.Warning32);
		Notify("UserSessions", New Structure("Status, SessionCount", "Error", SessionCount));
	EndIf;
	
EndProcedure

#EndRegion
