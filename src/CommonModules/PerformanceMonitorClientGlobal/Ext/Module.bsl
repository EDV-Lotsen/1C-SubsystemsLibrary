////////////////////////////////////////////////////////////////////////////////
// Idle handlers for performance monitor subsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region InternalProceduresAndFunctions

// Ends the measurement of key operation execution time. 
// The procedure is called from an idle handler.
Procedure EndTimeMeasurementAuto() Export
	
	PerformanceMonitorClient.EndTimeMeasurementAutoNotGlobal();
	
EndProcedure

// Calls a function that records the measurement result on the server. 
// The procedure is called from an idle handler.
Procedure WriteResultsAuto() Export
	
	PerformanceMonitorClient.WriteResultsAutoNotGlobal();
	
EndProcedure

#EndRegion
