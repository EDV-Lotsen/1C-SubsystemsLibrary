////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

Procedure AddRecord(RecordStructure) Export
	
	DataExchangeServer.AddRecordToInformationRegister(RecordStructure, "DataExchangeMessages");
	
EndProcedure

Procedure DeleteRecord(RecordStructure) Export
	
	DataExchangeServer.DeleteRecordSetFromInformationRegister(RecordStructure, "DataExchangeMessages");
	
EndProcedure
