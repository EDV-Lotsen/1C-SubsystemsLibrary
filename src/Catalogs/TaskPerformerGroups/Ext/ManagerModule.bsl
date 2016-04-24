#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Interface

// Returns a list of attributes that are excluded from the scope of the batch 
// object modification data processor
//
Function AttributesToSkipOnGroupProcessing() Export
	
	Result = New Array;
	Result.Add("*");
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Import data from file

// Prohibits importing data to the catalog from the "Import data from file" subsystem. 
// Batch data import to that catalog is potentially insecure.
// 
Function UseDataImportFromFile() Export
	Return False;
EndFunction

#EndRegion

#EndIf