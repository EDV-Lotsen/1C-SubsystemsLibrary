#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region InternalProceduresAndFunctions

// Adds a record to the register by the passed structure values.
Procedure AddRecord(RecordStructure) Export
	
	If CommonUseCached.DataSeparationEnabled()
		And CommonUseCached.CanUseSeparatedData() Then
		
		DataExchangeServer.AddRecordToInformationRegister(RecordStructure, "DataAreasSuccessfulDataExchangeStates");
	Else
		DataExchangeServer.AddRecordToInformationRegister(RecordStructure, "SuccessfulDataExchangeStates");
	EndIf;
	
EndProcedure

Procedure DeleteRecord(RecordStructure) Export
	
	DataExchangeServer.DeleteRecordSetFromInformationRegister(RecordStructure, "SuccessfulDataExchangeStates");
	
EndProcedure

#EndRegion

#EndIf