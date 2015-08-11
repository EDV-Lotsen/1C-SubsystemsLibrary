////////////////////////////////////////////////////////////////////////////////
//User sessions subsystem.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

// Terminates the current session if the infobase is locked.
//
Procedure UserSessionTerminationControlMode() Export

	// Getting current values of lock parameters.
	CurrentMode = InfoBaseConnections.SessionLockParameters();
	Locked = CurrentMode.Use;
	
	If Not Locked Then
		Return;	
	EndIf;
		
	LockBeginTime = CurrentMode.Start;
	LockEndTime = CurrentMode.End;
	
	WaitTimeout = CurrentMode.UserSessionTerminationTimeout;
	ExitWithConfirmationInterval = 0;
	CloseWithoutConfirmationInterval = - WaitTimeout / 5;
	StopInterval = - WaitTimeout / 2.5;
	CurrentTime = CommonUseClient.SessionDate();
	
	If LockEndTime <> '00010101' And CurrentTime > LockEndTime Then
		Return;
	EndIf;
	
	MessageText = InfoBaseConnectionsClientServer.ExtractLockMessage(CurrentMode.Message);
	MessageText = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en= 'It is recommended that you save all your data and exit the application. The application will be terminated at %1. 
		|%2'"),
		LockBeginTime, MessageText);
	
	If Not ValueIsFilled(LockBeginTime)
	 Or LockBeginTime - CurrentTime <= StopInterval Then
		
		StandardSubsystemsClient.SkipExitConfirmation();
		Exit(True, True);
		
	ElsIf LockBeginTime - CurrentTime <= CloseWithoutConfirmationInterval Then
		
		ShowMessageBox(, MessageText, 30);
		StandardSubsystemsClient.SkipExitConfirmation();
		Exit(False, True);
		
	ElsIf LockBeginTime - CurrentTime <= ExitWithConfirmationInterval Then
		
		ShowMessageBox(, MessageText, 30);
		StandardSubsystemsClient.SkipExitConfirmation();
		Exit(True, True);
		
	ElsIf LockBeginTime - CurrentTime <= WaitTimeout Then
		
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(
		 NStr("en= 'The application will be terminated at %1.'"),
		 LockBeginTime);
		ShowMessageBox(, MessageText, 30);
		
	EndIf;
	
EndProcedure

// Terminates active sessions if timeout is occurred and then
// terminates the current session.
//
Procedure TerminateSessions() Export

	// Get current values of the lock parameters
	CurrentMode = InfoBaseConnections.SessionLockParameters(True);

	SessionsCount = CurrentMode.SessionsCount;
	If SessionsCount <= 1 Then
		// There are no sessions except the current one.
		// Update with the batch file requires the following termination order:
		// the session with Terminate user sessions parameter must be the last session to be terminated.
		InfoBaseConnectionsClient.SetSessionTerminationInProgressFlag(False);
		Notify("UserSessions", New Structure("Status,SessionsCount", "Done", SessionsCount));
		DisconnectThisSession();
		Return;
	EndIf; 
	
	Locked = CurrentMode.Use;
	If Not Locked Then
		Return;
	EndIf;
	
	LockBeginTime = CurrentMode.Start;
	TerminationInterval = - CurrentMode.UserSessionTerminationTimeout;
	CurrentTime = CommonUseClient.SessionDate();
	ForceTermination = Not ValueIsFilled(LockBeginTime)
		Or LockBeginTime - CurrentTime <= TerminationInterval;
		
	If Not ForceTermination Then
		
		MessageText = NStr("en= '%1 active session(s).
			|Next session check will be executed in one minute.'");
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(
			MessageText, SessionsCount);
		ShowUserNotification(NStr("en= 'User session termination'"), 
			"e1cib/app/DataProcessor.ApplicationLocking", 
			MessageText, PictureLib.Information32);
		Notify("UserSessions", New Structure("Status,SessionsCount", "Executing", SessionsCount));
		Return;
	EndIf;
	
	// Once the lock is enabled, all user sessions must be terminated.
	// Trying to terminate connections for users who are still connected.
	DetachIdleHandler("TerminateSessions");
	
	Result = InfoBaseConnectionsClientServer.TerminateAllSessions();
	If Result Then	
		InfoBaseConnectionsClient.SetSessionTerminationInProgressFlag(False);
		ShowUserNotification(NStr("en= 'User session termination'"), 
			"e1cib/app/DataProcessor.ApplicationLocking", 
			NStr("en= 'Session termination completed successfully'"), PictureLib.Information32);
		Notify("UserSessions", New Structure("Status,SessionsCount", "Done", SessionsCount));
		DisconnectThisSession();
	Else
		InfoBaseConnectionsClient.SetSessionTerminationInProgressFlag(False);
		ShowUserNotification(NStr("en= 'User session termination'"), 
			"e1cib/app/DataProcessor.ApplicationLocking", 
			NStr("en= 'Session termination failed! See the event log for details.'"), PictureLib.Warning32);
		Notify("UserSessions", New Structure("Status,SessionsCount", "Error", SessionsCount));
	EndIf;
	
EndProcedure

// Terminates the last session (administrator session) that initiated the user session termination.
//
Procedure DisconnectThisSession()
	
	InfoBaseConnectionsClient.SetSessionTerminationHandlers(False);
	MessageText = NStr("en= 'Users are denied access to the infobase. The session is terminated.'");
	ShowMessageBox(, MessageText, 60);
	
EndProcedure

