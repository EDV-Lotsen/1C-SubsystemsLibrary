
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	FormParameters = New Structure("PerformerRole", CommandParameter);
	OpenForm("InformationRegister.TaskPerformers.Form.RolePerformers", FormParameters, 
		CommandExecuteParameters.Source, CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window);
EndProcedure
