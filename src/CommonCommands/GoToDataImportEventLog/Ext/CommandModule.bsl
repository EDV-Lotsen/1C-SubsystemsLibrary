////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS

&AtClient
Procedure CommandProcessing(InfoBaseNode, CommandExecuteParameters)
	
	DataExchangeClient.GoToDataEventLog(InfoBaseNode, CommandExecuteParameters, "DataImport");
	
EndProcedure
