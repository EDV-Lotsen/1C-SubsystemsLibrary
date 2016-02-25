#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region InternalProceduresAndFunctions

// Adds a record to the register by the passed structure values
Procedure AddRecord(RecordStructure) Export
	
	DataExchangeServer.AddRecordToInformationRegister(RecordStructure, "DataAreaDataExchangeStates");
	
EndProcedure

#EndRegion

#EndIf