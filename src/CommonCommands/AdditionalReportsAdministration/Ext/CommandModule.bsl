&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	AdditionalReportsAndDataProcessorsClient.OpenAdditionalReportsAndDataProcessorsCommandListForm(
			CommandParameter,
			CommandExecuteParameters,
			AdditionalReportsAndDataProcessorsClientServer.DataProcessorTypeAdditionalReport(),
			"AdditionalReportsAdministration");
		
EndProcedure
