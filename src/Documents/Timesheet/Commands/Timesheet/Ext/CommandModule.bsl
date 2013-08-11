
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	_DemoPrintManagementClient.RunPrintCommand("Document.Timesheet", "Template", CommandParameter, CommandExecuteParameters, Undefined);
	
EndProcedure
