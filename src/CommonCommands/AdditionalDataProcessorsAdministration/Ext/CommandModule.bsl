&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	AdditionalReportsAndDataProcessorsClient.OpenAdditionalReportsAndDataProcessorsCommandListForm(
			CommandParameter,
			CommandExecuteParameters,
			AdditionalReportsAndDataProcessorsClientServer.DataProcessorTypeAdditionalDataProcessor(),
			"AdditionalDataProcessorsAdministration");
		
EndProcedure
