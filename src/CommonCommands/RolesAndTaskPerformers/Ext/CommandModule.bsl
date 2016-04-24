
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	OpenForm("InformationRegister.TaskPerformers.Form.AddressingByObject", 
		New Structure("MainAddressingObject", CommandParameter), 
		CommandExecuteParameters.Source, 
		CommandExecuteParameters.Uniqueness, 
		CommandExecuteParameters.Window);
EndProcedure
