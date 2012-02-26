
// Set or remove infobase lock,
// on the basis of data processor attribute values.
//
Procedure RunSetup() Export
	
	Block 			= New SessionsLock;
	Block.Begin     = LockBegin;
	Block.End       = LockEnding;
	Block.Message   = InfobaseConnections.GenerateBlockMessage(Message, KeyCode); 
	Block.Use       = RejectNewConnections;
	Block.KeyCode   = KeyCode;
	
	SetSessionsLock(Block);
	
EndProcedure

// Read infobase lock parameters
// to data processor attributes.
//
Procedure GetBlockParameters() Export
	
	CurrentMode = GetSessionsLock();
	
	RejectNewConnections = CurrentMode.Use;
	Message             = InfobaseConnectionsClientServer.ExtractLockMessage(CurrentMode.Message);
	KeyCode             = CurrentMode.KeyCode;
	
	If RejectNewConnections Then
		LockBegin       = CurrentMode.Begin;
		LockEnding      = CurrentMode.End;
	Else	
		// If lock is not set, then it's possible, that
		// user has opened form for lock setup.
		// Thus set lock date equal to current date
		LockBegin       = CurrentDate();
	EndIf;
	
EndProcedure

