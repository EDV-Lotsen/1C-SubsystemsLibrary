////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	DataExchangeClient.ExecuteDataExchangeCommandProcessing(CommandParameter, CommandExecuteParameters.Source);
	
EndProcedure
