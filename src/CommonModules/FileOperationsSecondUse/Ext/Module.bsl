
////////////////////////////////////////////////////////////////////////////////
// MODULE CONTAINS AUXILIARY FUNCTIONS AND PROCEDURES FOR OPERATION WITH FILES
//
//

// Returns server platform type
Function ServerPlatformType() Export
	SysInfo = New SystemInfo;
	Return SysInfo.PlatformType;
EndFunction	

