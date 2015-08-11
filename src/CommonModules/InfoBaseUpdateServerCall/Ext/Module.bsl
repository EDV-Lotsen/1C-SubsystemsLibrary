// Internal use only.
Function UpdateInfoBase(ExceptionIfUnableLockInfoBase = True,
	OnStartClientApplication = False, Restart = False) Export
	
	Return InfoBaseUpdateInternal.UpdateInfoBase(
		ExceptionIfUnableLockInfoBase, OnStartClientApplication, Restart);
	
EndFunction

// Gets executed update handlers for the current user.
//
Function GetExecutedHandlers() Export
	
	HandlerTree = CommonUse.CommonSettingsStorageLoad("UpdateInfoBase", 
		"ExecutedHandlers");
		
	Return PutToTempStorage(HandlerTree, New UUID);
		
EndFunction

