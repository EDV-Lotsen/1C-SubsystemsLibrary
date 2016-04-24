
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	OpenForm("Task.PerformerTask.Form.TasksByBusinessProcess",
		New Structure("SelectValue", CommandParameter),
			CommandExecuteParameters.Source,
			CommandExecuteParameters.Source.UniquenessKey,
			CommandExecuteParameters.Window);	
EndProcedure
