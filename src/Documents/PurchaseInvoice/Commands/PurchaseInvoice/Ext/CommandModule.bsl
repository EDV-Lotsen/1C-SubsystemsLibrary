
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
		_DemoPrintManagementClient.RunPrintCommand("Document.PurchaseInvoice",
     "PurchaseInvoice", CommandParameter, CommandExecuteParameters, Undefined);

	
EndProcedure
