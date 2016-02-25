
#Region EventHandlers

&AtClient
Procedure CommandProcessing(InfobaseNode, CommandExecuteParameters)
	
	DataExchangeClient.GoToDataEventLog(InfobaseNode, CommandExecuteParameters, "DataImport");
	
EndProcedure

#EndRegion
