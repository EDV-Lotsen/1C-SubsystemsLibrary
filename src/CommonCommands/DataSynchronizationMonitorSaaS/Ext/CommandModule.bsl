
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	OpenForm("CommonForm.DataSynchronizationMonitorSaaS",,
			CommandExecuteParameters.Source,
			CommandExecuteParameters.Uniqueness,
			CommandExecuteParameters.Window);
	
EndProcedure
