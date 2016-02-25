///////////////////////////////////////////////////////////////////////////////////
// "SaaS users" subsystem.
// 
///////////////////////////////////////////////////////////////////////////////////

#Region InternalProceduresAndFunctions

// Returns the subsystem name to be included in the name of log event names.
//
// Returns: String.
//
Function SubsystemNameForEventLogEvents() Export
	
	Return Metadata.Subsystems.StandardSubsystems.Subsystems.SaaSOperations.Subsystems.UsersSaaS.Name;
	
EndFunction

#EndRegion
