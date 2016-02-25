////////////////////////////////////////////////////////////////////////////////
// User sessions subsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region InternalProceduresAndFunctions

// Returns a structure with parameters used for session termination.
//
Function SessionTerminationParameters() Export
	
	ServerPlatformType = CommonUseCached.ServerPlatformType();
	
	Return New Structure("InfobaseSessionNumber,WindowsPlatformAtServer",
		InfobaseSessionNumber(),
		ServerPlatformType = PlatformType.Windows_x86
			Or ServerPlatformType = PlatformType.Windows_x86_64);
	
EndFunction

#EndRegion
