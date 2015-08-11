// InternalUseOnly
Function Parameters() Export
	
	SetPrivilegedMode(True);
	SavedParameters = StandardSubsystemsServer.ApplicationParameters(
		"UserSessionParameters");
	SetPrivilegedMode(False);
	
	Return SavedParameters;
	
EndFunction
