#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region InternalProceduresAndFunctions

// Locks or unlocks the infobase, depending on the data processor attribute values.
//
Procedure SetLock() Export
	
	ExecuteSetLock(ProhibitUserWorkTemporarily);
	
EndProcedure

// Disables the previously enabled session lock.
//
Procedure Unlock() Export
	
	ExecuteSetLock(False);
	
EndProcedure

// Reads the infobase lock parameters and passes them to the data processor attributes.
// 
Procedure GetLockParameters() Export
	
	If Users.InfobaseUserWithFullAccess(, True) Then
		CurrentMode = GetSessionsLock();
		UnlockCode  = CurrentMode.KeyCode;
	Else	
		CurrentMode = InfobaseConnections.GetDataAreaSessionLock();
	EndIf;
	
	ProhibitUserWorkTemporarily = CurrentMode.Use;
	MessageForUsers = InfobaseConnectionsClientServer.ExtractLockMessage(CurrentMode.Message);
	
	If ProhibitUserWorkTemporarily Then
		LockPeriodStart = CurrentMode.Beginning;
		LockPeriodEnd   = CurrentMode.End;
	Else	
		// If data lock is not set, most probably the form is opened by user in order to set the lock.
		// Setting the lock date equal to the current date.
		LockPeriodStart     = BegOfMinute(CurrentSessionDate() + 5 * 60);
	EndIf;
	
EndProcedure

Procedure ExecuteSetLock(Value)
	
	ConnectionsLocked = InfobaseConnections.ConnectionsLocked();
	If Users.InfobaseUserWithFullAccess(, True) Then
		DataLock = New SessionsLock;
		DataLock.KeyCode    = UnlockCode;
	Else
		DataLock = InfobaseConnections.NewConnectionLockParameters();
	EndIf;
	
	DataLock.Begin          = LockPeriodStart;
	DataLock.End            = LockPeriodEnd;
	DataLock.Message        = InfobaseConnections.GenerateLockMessage(MessageForUsers, 
		UnlockCode); 
	DataLock.Use            = Value;
	
	If Users.InfobaseUserWithFullAccess(, True) Then
		SetSessionsLock(DataLock);
	Else
		InfobaseConnections.SetDataAreaSessionLock(DataLock);
	EndIf;
	
EndProcedure

#EndRegion

#EndIf