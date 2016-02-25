
#Region EventHandlers

&AtClient
Procedure CommandProcessing(InfobaseNode, CommandExecuteParameters)
	
	DataExchangeClient.GoToDataEventLog(InfobaseNode, CommandExecuteParameters, "DataExport");
	
EndProcedure

#EndRegion
