////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

// Adds record to the register by the passed structure values.
//
Procedure AddRecord(RecordStructure) Export
	
	DataExchangeServer.AddRecordToInformationRegister(RecordStructure, "SuccessfulDataExchangeStates");
	
EndProcedure
