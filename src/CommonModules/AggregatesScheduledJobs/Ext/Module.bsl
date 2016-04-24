///////////////////////////////////////////////////////////////////////
// This module contains procedures and functions for aggregates operations, used
// by scheduled jobs

// UpdateSalesAggregates scheduled job.
// Parameters: 
//  No
Procedure UpdateSalesAggregates() Export
	If AccumulationRegisters.Sales.GetAggregatesMode() 
		 And  AccumulationRegisters.Sales.GetAggregatesUsing() Then
		AccumulationRegisters.Sales.UpdateAggregates(True);
	EndIf
EndProcedure

// RebuildingSalesAggregates scheduled job.
// Parameters: 
//  No
Procedure RebuildingSalesAggregates() Export
	If AccumulationRegisters.Sales.GetAggregatesMode() 
		 And  AccumulationRegisters.Sales.GetAggregatesUsing() Then
		AccumulationRegisters.Sales.RebuildAggregatesUsing();
	EndIf
EndProcedure