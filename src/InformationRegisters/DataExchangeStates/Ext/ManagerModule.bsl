#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region InternalProceduresAndFunctions

// Adds a record to the register by the passed structure values.
Procedure AddRecord(RecordStructure) Export
	
	If CommonUseCached.DataSeparationEnabled()
		And CommonUseCached.CanUseSeparatedData() Then
		
		DataExchangeServer.AddRecordToInformationRegister(RecordStructure, "DataAreaDataExchangeStates");
	Else
		DataExchangeServer.AddRecordToInformationRegister(RecordStructure, "DataExchangeStates");
	EndIf;
	
EndProcedure

Procedure DeleteRecord(RecordStructure) Export
	
	DataExchangeServer.DeleteRecordSetFromInformationRegister(RecordStructure, "DataExchangeStates");
	
EndProcedure

#EndRegion

#EndIf