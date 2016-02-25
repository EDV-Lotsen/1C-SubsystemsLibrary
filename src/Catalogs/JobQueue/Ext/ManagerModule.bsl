#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Interface

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