// Set or remove infobase lock,
// on the basis of data processor attribute values.
//
Procedure RunSetup() Export
	
	Block 			= New SessionsLock;
	Block.Begin           = LockBegin;
	Block.End            = LockEnding;
	Block.Message   = InfoBaseConnections.GenerateLockMessage(Message, KeyCode);
	Block.Use      = SetConnectionsBlock;
	Block.KeyCode   = KeyCode;
	
	SetSessionsLock(Block);
	
EndProcedure

// Read infobase lock parameters
// to data processor attributes.
//
Procedure GetBlockParameters() Export
	
	CurrentMode = GetSessionsLock();
	
	SetConnectionsBlock = CurrentMode.Use;
	Message = InfoBaseConnectionsClientServer.ExtractLockMessage(CurrentMode.Message);
	KeyCode = CurrentMode.KeyCode;
	
	If SetConnectionsBlock Then
		LockBegin    = CurrentMode.Begin;
		LockEnding = CurrentMode.End;
	Else	
		// If lock is not set, then it's possible, that
		// user has opened form for lock setup.
		// Thus set lock date equal to current date
		LockBegin     = CurrentDate();
	EndIf;

EndProcedure

