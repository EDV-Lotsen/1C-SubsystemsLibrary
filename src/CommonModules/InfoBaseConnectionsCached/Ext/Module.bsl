////////////////////////////////////////////////////////////////////////////////
// User sessions subsystem.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// Get saved infobase administration parameters.
// 
// Returns:
// Structure.
//
Function GetInfoBaseAdministrationParameters() Export

	Return InfoBaseConnections.GetInfoBaseAdministrationParameters();
	
EndFunction

// Returns a structure with parameters for forced session termination.
//
Function SessionTerminationParameters() Export
	
	SystemInfo = New SystemInfo;
	Return New Structure("InfoBaseSessionNumber,WindowsPlatformAtServer", 
		InfoBaseSessionNumber(), 
		SystemInfo.PlatformType = PlatformType.Windows_x86 
			Or SystemInfo.PlatformType = PlatformType.Windows_x86_64);
	
EndFunction	