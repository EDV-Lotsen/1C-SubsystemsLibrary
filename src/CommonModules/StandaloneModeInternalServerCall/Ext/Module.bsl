////////////////////////////////////////////////////////////////////////////////
// Data exchange SaaS subsystem.
// 
////////////////////////////////////////////////////////////////////////////////

#Region InternalProceduresAndFunctions

// For internal use
// 
Function SynchronizationWithServiceNotExecuteLongTime() Export
	
	Return StandaloneModeInternal.SynchronizationWithServiceNotExecuteLongTime();
	
EndFunction

// For internal use
// 
Function DataExchangeExecutionFormParameters() Export
	
	Return StandaloneModeInternal.DataExchangeExecutionFormParameters();
	
EndFunction

#EndRegion
