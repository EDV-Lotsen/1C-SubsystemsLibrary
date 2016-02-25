
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	DataExchangeClient.ImportDataSynchronizationRules(ExchangePlanName(CommandParameter));
	
EndProcedure

&AtServer
Function ExchangePlanName(Val InfobaseNode)
	
	Return DataExchangeCached.GetExchangePlanName(InfobaseNode);
	
EndFunction
