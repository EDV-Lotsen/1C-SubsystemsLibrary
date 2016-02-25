
#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Filter        = New Structure("Node", CommandParameter);
	FillingValues = New Structure("Node", CommandParameter);
	
	DataExchangeClient.OpenInformationRegisterRecordFormByFilter(Filter, FillingValues, "ExchangeTransportSettings", CommandExecuteParameters.Source);
	
EndProcedure

#EndRegion
