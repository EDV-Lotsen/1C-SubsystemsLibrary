
////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS 

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	GetSuppliedData();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

&AtServer
Procedure GetSuppliedData()
	
	SuppliedData.UpdateSharedSuppliedData();

EndProcedure
