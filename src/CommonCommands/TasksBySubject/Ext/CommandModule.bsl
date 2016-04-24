
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	OpenForm("Task.PerformerTask.Form.TasksBySubject",
		New Structure("SelectValue", CommandParameter),
			CommandExecuteParameters.Source,
			CommandExecuteParameters.Source.UniquenessKey,
			CommandExecuteParameters.Window);	
EndProcedure
