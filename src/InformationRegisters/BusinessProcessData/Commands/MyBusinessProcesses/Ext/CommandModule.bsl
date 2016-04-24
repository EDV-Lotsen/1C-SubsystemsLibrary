
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	OpenForm("InformationRegister.BusinessProcessData.Form.MyBusinessProcesses", 
		, 
		CommandExecuteParameters.Source, 
		CommandExecuteParameters.Uniqueness, 
		CommandExecuteParameters.Window);
EndProcedure



