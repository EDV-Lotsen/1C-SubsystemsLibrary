&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	OpenForm(
		"Task.PerformerTask.ListForm",
		New Structure("FormTitle", NStr("en = 'All tasks'")),
		CommandExecuteParameters.Source, 
		CommandExecuteParameters.Uniqueness, 
		CommandExecuteParameters.Window);
	
EndProcedure