
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	OpenForm("DataProcessor.BusinessProcessFlowchart.Form", 
		New Structure("BusinessProcess", CommandParameter), 
		CommandExecuteParameters.Source, 
		CommandExecuteParameters.Uniqueness, 
		CommandExecuteParameters.Window);
EndProcedure
