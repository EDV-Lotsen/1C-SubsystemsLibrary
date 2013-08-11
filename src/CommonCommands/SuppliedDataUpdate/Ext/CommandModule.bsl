
////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS 

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	UpdateSuppliedData();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// СЛУЖЕБНЫЕ ПРОЦЕДУРЫ И ФУНКЦИИ

&AtServer
Procedure UpdateSuppliedData()
	
	SuppliedData.UpdateSuppliedData(CommonUse.SessionSeparatorValue(), 0);
	
EndProcedure
