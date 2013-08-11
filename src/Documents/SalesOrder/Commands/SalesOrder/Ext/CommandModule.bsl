
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	_DemoPrintManagementClient.RunPrintCommand("Document.SalesOrder",
     "SalesOrder", CommandParameter, CommandExecuteParameters, Undefined);
	 
EndProcedure
