
#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	DataExchangeClient.ExecuteDataExchangeCommandProcessing(CommandParameter, CommandExecuteParameters.Source);
	
EndProcedure

#EndRegion
