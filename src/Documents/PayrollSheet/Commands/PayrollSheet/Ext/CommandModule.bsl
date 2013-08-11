
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	_DemoPrintManagementClient.RunPrintCommand("Document.PayrollSheet", "Template", CommandParameter, CommandExecuteParameters, Undefined);
	
EndProcedure
