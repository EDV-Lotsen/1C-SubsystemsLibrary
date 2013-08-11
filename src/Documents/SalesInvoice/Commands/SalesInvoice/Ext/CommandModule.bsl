
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	_DemoPrintManagementClient.RunPrintCommand("Document.SalesInvoice",
     "SalesInvoice", CommandParameter, CommandExecuteParameters, Undefined);
	
EndProcedure
