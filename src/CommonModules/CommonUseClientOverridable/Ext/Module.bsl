////////////////////////////////////////////////////////////////////////////////
// Base functionality subsystem.
// Implementation of application module handlers.
// 
////////////////////////////////////////////////////////////////////////////////


////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// Is executing before interactive work with the data area start.
// It corresponds to the BeforeStart handler.
//
// Parameters:
// Cancel - Boolean - Cancel start. If this parameter is set to True
// work with area will not be started.
//
Procedure BeforeStart(Cancel) Export
	
EndProcedure

// Is executing on interactive work with the data area start.
// It corresponds to the OnStart handler.
//
// Parameters
// ProcessLaunchParameters - Boolean - True if the processor is raised
// on the direct user login and should handle the launch
// parameters (if it is provided by its logic). In other case the processor is raised
// on the interactive shared user login to the data area and 
// launch parameters should not be handled.
//
Procedure OnStart(Val ProcessLaunchParameters = False) Export
	
EndProcedure

// Corresponds to the BeforeExit handler.
//
Procedure BeforeExit(Cancel) Export
	
EndProcedure

// Internal use only.
Procedure AfterStart() Export
	
EndProcedure

// Internal use only.
Procedure ClientSystemTitleOnSet(SystemTitle, OnStart) Export
	
EndProcedure

