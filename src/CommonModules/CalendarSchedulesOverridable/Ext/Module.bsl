////////////////////////////////////////////////////////////////////////////////
// Calendar schedules subsystem.
// 
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// The procedure is called when business calendar data is changed.
//
// Parameters:
//  UpdateConditions - value table with the following columns:
// 	- BusinessCalendarCode - business calendar code.
// 	- Year - change enforcement year.
//
Procedure OnUpdateBusinessCalendars(UpdateConditions) Export
	
EndProcedure

#EndRegion
