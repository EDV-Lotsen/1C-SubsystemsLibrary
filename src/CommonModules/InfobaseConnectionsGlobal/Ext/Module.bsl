
///////////////////////////////////////////////////////////////////////////////
// PROCEDURES - IDLE HANDLERS

// Terminate current session, if IB connections lock
//  is enabled.
//
Procedure MonitorUserSessionTerminationMode() Export

	// Get current value of lock parameters
	CurrentMode = InfobaseConnections.SessionLockParameters();
	Blocked 	= CurrentMode.Use;
	
	If Not Blocked Then
		Return;	
	EndIf;
		
	LockTimeBegin  = CurrentMode.Begin;
	EndingTimeLock = CurrentMode.End;
	
	WarningInterval   		 	= CurrentMode.UserExitWaitPeriod;
	CloseWithQueryInterval  	= 0;
	CloseWithoutQueryInterval 	= - WarningInterval / 5;
	StopInterval        		= - WarningInterval / 2.5;
	CurrentMoment             	= CurrentDate();
	
	If EndingTimeLock <> '00010101' And CurrentMoment > EndingTimeLock Then
		Return;
	EndIf;
	
	MessageText = InfobaseConnectionsClientServer.ExtractLockMessage(CurrentMode.Message);
	
	If Not ValueIsFilled(LockTimeBegin)
	   Or LockTimeBegin - CurrentMoment <= StopInterval Then
		
		Exit(True);
		
	ElsIf LockTimeBegin - CurrentMoment <= CloseWithoutQueryInterval Then
		
		DoMessageBox(NStr("en = 'System is shutting down.'"), 30);
		Exit(False);
		
	ElsIf LockTimeBegin - CurrentMoment <= CloseWithQueryInterval Then
		
		DoMessageBox(NStr("en = 'System is shutting down.'"), 30);
		Exit(True);
		
	ElsIf LockTimeBegin - CurrentMoment <= WarningInterval Then
		
		MessageText = StringFunctionsClientServer.SubstitureParametersInString(
		                   NStr("en = 'System will shut down at %1.'"),
		                   LockTimeBegin);
		DoMessageBox(MessageText, 30);
		
	EndIf;
	
EndProcedure

// Terminate active sessions, if wait time has expired, and then
// terminate current session.
//
Procedure TerminateUserSessions() Export

	// Get current value of lock parameters
	CurrentMode = InfobaseConnections.SessionLockParameters();
	
	SessionsCount = CurrentMode.SessionsCount;
	If SessionsCount <= 1 Then
		// All users except current session owner are terminated
		// SessionNumber with parameter "TerminateUserSessions" is being terminated in the last turn.
		// Such order of termination is required for configuration update using a batch file
		Exit(False);
		Return;
	EndIf; 
	
	Blocked = CurrentMode.Use;
	If Not Blocked Then
		Return;
	EndIf;
	
	LockTimeBegin 			= CurrentMode.Begin;
	TerminationInterval 	= - CurrentMode.UserExitWaitPeriod;
	CurrentMoment 			= CurrentDate();
	SessionTerminationTime 	= Not ValueIsFilled(LockTimeBegin)
		Or LockTimeBegin - CurrentMoment <= TerminationInterval;
		
	If Not SessionTerminationTime Then
		
		MessageText = NStr("en = 'Active Connections: %1. Next connections test will be performed in one minute.'");
		MessageText = StringFunctionsClientServer.SubstitureParametersInString(
			MessageText, SessionsCount);
		Status(NStr("en = 'Terminating user sessions'"), , 
			MessageText, PictureLib.Information32);
			
		Return;
	EndIf;
	
	// after the infobase is locked all user sessions must be terminated
	// if this did not happen trying to force drop connections forcibly
	DetachIdleHandler("TerminateUserSessions");
	
	Result = InfobaseConnections.CloseInfobaseConnectionsByOptionsLaunch(LaunchParameter);
	If Result Then	
		Status(NStr("en = 'User sessions terminated successfully'"), , 
			NStr("en = 'System is Shutting Down...'"), PictureLib.Information32);
		Exit(False);
	Else
		Status(NStr("en = 'User sessions terminated successfully'"), 
			NStr("en = 'For details see the Event Log.'"), 
			PictureLib.Warning32);
	EndIf;
	
EndProcedure
