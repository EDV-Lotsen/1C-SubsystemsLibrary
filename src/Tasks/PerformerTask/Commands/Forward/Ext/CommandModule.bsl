
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)

	BusinessProcessesAndTasksClient.ForwardTasks(CommandParameter, CommandExecuteParameters.Source);
	
EndProcedure
