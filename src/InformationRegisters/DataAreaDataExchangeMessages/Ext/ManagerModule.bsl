#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region InternalProceduresAndFunctions

Procedure AddRecord(RecordStructure) Export
	
	DataExchangeServer.AddRecordToInformationRegister(RecordStructure, "DataAreaDataExchangeMessages");
	
EndProcedure

Procedure DeleteRecord(RecordStructure) Export
	
	DataExchangeServer.DeleteRecordSetFromInformationRegister(RecordStructure, "DataAreaDataExchangeMessages");
	
EndProcedure

#EndRegion

#EndIf