
// Procedure attaches idle handler MonitorUserSessionTerminationMode
//
Procedure SetMonitorUserSessionTerminationMode()  Export
	
	If GetClientConnectionSpeed() <> ClientConnectionSpeed.Normal Then
		Return;	
	EndIf;
	
	BlockMode 	= StandardSubsystemsClientSecondUse.ClientParameters().SessionLockParameters;
	CurrentTime = BlockMode.CurrentSessionDate;
	If BlockMode.Use 
		 And (Not ValueIsFilled(BlockMode.Begin) Or CurrentTime >= BlockMode.Begin) 
		 And (Not ValueIsFilled(BlockMode.End) 	 Or CurrentTime <= BlockMode.End) Then
		// If user has logged into the base with enabled lock mode, it means that key /UC was used.
		// Don't terminate such user session
		Return;
	EndIf;
	
	AttachIdleHandler("MonitorUserSessionTerminationMode", 60);	
	
EndProcedure

// Process launch parameters, related to IB connections allowing and termination.
//
// Parameters
//  StartParameterValue  		– String 	– main start parameter
//  LaunchParameters          	– Array 	– additional start parameters separated
//                                       with symbol ";".
//
// Value returned:
//   Boolean   					– True, if need to abort system start.
//
Function ProcessStartParameters(Val StartParameterValue, Val LaunchParameters) Export

	// Process start parameters -
	// BanUserWork and PermitUserConnections
	If StartParameterValue = Upper("PermitUserConnections") Then
		
		If Not InfobaseConnections.PermitUserConnections() Then
			MessageText = NStr("en = 'Run mode parameter PermitUserConnections not worked out. No right for infobase administration.'");
			DoMessageBox(MessageText);
			Return False;
		EndIf;
		
		Exit(False);
		Return True;
		
	// Parameter may contain two additional parts, separated with ";" -
	// IB admin name and password, used to connect to a servers cluster
	// in client-server setup. Need to pass them in case,
	// if current user is not an IB administrator.
	// see usage in procedure TerminateUserSessions().
	ElsIf StartParameterValue = Upper("TerminateUserSessions") Then
		
		// because lock is not enabled yet, then on system start
		// for the current user work termination idle handler has been attached.
		// Terminate it. Because for this user specific idle handler "TerminateUserSessions" is being attached.
		// The handler is configured the way that current user
		// must be the last terminated user.
		DetachIdleHandler("MonitorUserSessionTerminationMode");
		
		If Not InfobaseConnections.RejectNewConnections() Then
			MessageText = NStr("en = 'Run mode parameter TerminateUserSessions not worked out. No right for information base administration.'");
			DoMessageBox(MessageText);
			Return False;
		EndIf;
		
		AttachIdleHandler("TerminateUserSessions", 60);
		TerminateUserSessions();
		Return True;
		
	EndIf;
	
	Return False;
	
EndFunction

// Connect idle handler MonitorUserSessionTerminationMode or
// TerminateUserSessions depending on parameter RejectNewConnections.
//
Procedure SetUserSessionsTerminationIdleHandler(Val RejectNewConnections) Export
	
	If RejectNewConnections Then
		// because locking is not enabled yet, then on system start
		// for the current user work termination idle handler has been attached.
		// Disable it. Because for this user specific idle handler "TerminateUserSessions" is being attached.
		// The handler is configured the way that current user
		// must be the last terminated user.
		
		DetachIdleHandler("MonitorUserSessionTerminationMode");
		AttachIdleHandler("TerminateUserSessions", 60);
		TerminateUserSessions();
		ShowUserNotification(NStr("en = 'Block Mode'"),
			NStr("en = 'Infobase connection locking is enabled.'"), 
			PictureLib.Information32);
	Else
		DetachIdleHandler("TerminateUserSessions");
		AttachIdleHandler("MonitorUserSessionTerminationMode", 60);
		ShowUserNotification(NStr("en = 'Block Mode'"),
			NStr("en = 'Infobase connection locking is disabled.'"), 
			PictureLib.Information32);
	EndIf;
	
EndProcedure
