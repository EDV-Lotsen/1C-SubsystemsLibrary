#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Interface

////////////////////////////////////////////////////////////////////////////////
// Batch object modification

// Returns a list of attributes excluded from the batch object modification.
//
Function BatchProcessingEditableAttributes() Export
	
	Result = New Array;
	Result.Add("RateSettingMethod");
	Result.Add("Margin");
	Result.Add("MainCurrency");
	Result.Add("RateCalculationFormula");
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Import data from file

// Prohibits catalog data import from the ImportDataFromFile subsystem, as 
// the catalog implements its data update method.
// 
Function UseDataImportFromFile() Export
	Return False;
EndFunction

#EndRegion

#EndIf