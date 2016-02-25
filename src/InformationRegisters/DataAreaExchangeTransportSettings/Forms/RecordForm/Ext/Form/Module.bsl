
#Region FormCommandHandlers

&AtClient
Procedure OpenCommonTransportSettings(Command)
	
	Filter        = New Structure("CorrespondentEndpoint", Record.CorrespondentEndpoint);
	FillingValues = New Structure("CorrespondentEndpoint", Record.CorrespondentEndpoint);
	
	DataExchangeClient.OpenInformationRegisterRecordFormByFilter(Filter, FillingValues, "DataAreasExchangeTransportSettings", ThisObject);
	
EndProcedure

#EndRegion
