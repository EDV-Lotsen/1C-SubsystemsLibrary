
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
		_DemoPrintManagementClient.RunPrintCommand("Document.PurchaseOrder",
     "PurchaseOrder", CommandParameter, CommandExecuteParameters, Undefined);

	
EndProcedure
