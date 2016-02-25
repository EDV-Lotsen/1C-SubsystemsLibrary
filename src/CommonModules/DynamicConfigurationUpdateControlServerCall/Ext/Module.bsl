////////////////////////////////////////////////////////////////////////////////
// Dynamic configuration update control subsystem
//  
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// Checks that the infobase was updated dynamically.
//
Function DBConfigurationWasChangedDynamically() Export
	
	Return DataBaseConfigurationChangedDynamically();
	
EndFunction

#EndRegion
