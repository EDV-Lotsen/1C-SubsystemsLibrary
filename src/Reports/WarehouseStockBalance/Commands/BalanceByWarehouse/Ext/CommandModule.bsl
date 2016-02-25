
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FormParameters = New Structure("Filter,PurposeUseKey,GenerateOnOpen", New Structure("Warehouse", CommandParameter), "BalanceByWarehouse", True);
	OpenForm("Report.WarehouseStockBalance.Form", FormParameters, CommandExecuteParameters.Source, CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window);
	
EndProcedure
