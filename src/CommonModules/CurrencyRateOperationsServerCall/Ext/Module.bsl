////////////////////////////////////////////////////////////////////////////////
// Currency subsystem
//
////////////////////////////////////////////////////////////////////////////////

#Region InternalProceduresAndFunctions

// Imports currency rate data.
//
Function ImportCurrencyRateFromFile(Currency, PathToFile, ImportPeriodBegin, ImportPeriodEnd) Export
	Return CurrencyRateOperations.ImportCurrencyRateFromFile(Currency, PathToFile, ImportPeriodBegin, ImportPeriodEnd);
EndFunction

// Verifies that all currency rates are current.
//
Function RatesRelevant() Export
	Return CurrencyRateOperations.RatesRelevant();
EndFunction

#EndRegion
