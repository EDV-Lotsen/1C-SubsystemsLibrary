////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

// Locks or unlocks the infobase,
// depends on the ProhibitUserWorkTemporarily attribute value.
//
Procedure SetLock() Export
	
	ExecuteSetLock(ProhibitUserWorkTemporarily);
	
EndProcedure

// Disables the previously enabled session lock.
//
Procedure Unlock() Export
	
	ExecuteSetLock(False);
	
EndProcedure

// Reads infobase lock parameters 
// and passes them to the DataProcessor attributes.
//
Procedure GetLockParameters() Export
	
	If Users.InfoBaseUserWithFullAccess(, True) Then
		CurrentMode = GetSessionsLock();
		UnlockCode = CurrentMode.KeyCode;
	Else	
		CurrentMode = InfoBaseConnections.GetDataAreaSessionLock();
	EndIf;
	
	ProhibitUserWorkTemporarily = CurrentMode.Use;
	MessageForUsers = InfoBaseConnectionsClientServer.ExtractLockMessage(CurrentMode.Message);
	
	If ProhibitUserWorkTemporarily Then
		LockPeriodStart = CurrentMode.Begin;
		LockPeriodEnd = CurrentMode.End;
	Else	
		// If data lock is disabled, most probably
		// the user opened the form to enable the lock.
		// Setting the lock date equal to the current date.
		LockPeriodStart = BegOfMinute(CurrentSessionDate() + 5 * 60);
	EndIf;
	
	If Users.InfoBaseUserWithFullAccess(, True) Then
		DisableScheduledJobs = InfoBaseConnectionsClientServer.ScheduledJobsLocked();
	EndIf;

EndProcedure

Procedure ExecuteSetLock(Value)
	
	ConnectionsLocked = InfoBaseConnections.ConnectionsLocked();
	If Users.InfoBaseUserWithFullAccess(, True) Then
		DataLock = New SessionsLock;
		DataLock.KeyCode = UnlockCode;
	Else
		DataLock = InfoBaseConnections.NewLockConnectionParameters();
	EndIf;
	
	DataLock.Begin = LockPeriodStart;
	DataLock.End = LockPeriodEnd;
	DataLock.Message = InfoBaseConnections.GenerateLockMessage(MessageForUsers, 
		UnlockCode); 
	DataLock.Use = Value;
	
	If Users.InfoBaseUserWithFullAccess(, True) Then
		SetSessionsLock(DataLock);
		If Not CommonUse.FileInfoBase() Then
			Try
				InfoBaseConnectionsClientServer.SetSheduledJobLock(DisableScheduledJobs);
			Except
				// Rolling lock enabling back in case of error
				If Not ConnectionsLocked And Value Then
					DataLock.Use = False;
					SetSessionsLock(DataLock);
				EndIf;
				Raise;
			EndTry;
		EndIf;
	Else
		InfoBaseConnections.SetDataAreaSessionLock(DataLock);
	EndIf;
	
EndProcedure