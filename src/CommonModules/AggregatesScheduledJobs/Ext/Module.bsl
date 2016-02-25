///////////////////////////////////////////////////////////////////////
// This module contains procedures and functions for aggregates operations, used
// by scheduled jobs

// Scheduled job UpdateSalesAggregates.
// Parameters: 
//  No
Procedure UpdateSalesAggregates() Export
	If AccumulationRegisters.Sales.GetAggregatesMode() 
		 And  AccumulationRegisters.Sales.GetAggregatesUsing() Then
		AccumulationRegisters.Sales.UpdateAggregates(True);
	EndIf
EndProcedure

// Routine job RebuildingSalesAggregates.
// Parameters: 
//  No
Procedure RebuildingSalesAggregates() Export
	If AccumulationRegisters.Sales.GetAggregatesMode() 
		 And  AccumulationRegisters.Sales.GetAggregatesUsing() Then
		AccumulationRegisters.Sales.RebuildAggregatesUsing();
	EndIf
EndProcedure