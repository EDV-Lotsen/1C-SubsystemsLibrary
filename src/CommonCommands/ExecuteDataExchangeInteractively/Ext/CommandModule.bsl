
#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	DataExchangeClient.OpenObjectMappingWizardCommandProcessing(CommandParameter, CommandExecuteParameters.Source);
	
EndProcedure

#EndRegion
