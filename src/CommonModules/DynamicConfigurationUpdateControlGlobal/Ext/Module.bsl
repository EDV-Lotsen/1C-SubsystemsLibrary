////////////////////////////////////////////////////////////////////////////////
// Dynamic configuration update control subsystem
//  
////////////////////////////////////////////////////////////////////////////////

#Region InternalProceduresAndFunctions

// The idle handler checks whether the infobase is updated dynamically and informs the user
// when an update is detected.
// 
Procedure InfobaseDynamicChangeCheckIdleHandler() Export
	
	DynamicConfigurationUpdateControlClient.DynamicUpdateChecksIdleHandler();
	
EndProcedure

#EndRegion
