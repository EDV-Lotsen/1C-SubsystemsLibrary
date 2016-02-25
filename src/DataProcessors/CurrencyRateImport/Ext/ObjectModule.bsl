#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region InternalProceduresAndFunctions

// The procedure fills the table with a currency list. The list contains 
// only currencies whose rates are independent of other currency rates.
// 
Procedure FillCurrencyList() Export
	
	CurrencyList.Clear();
	
	CurrenciesToBeImported = CurrencyRateOperations.GetCurrenciesToBeImportedArray();
	
	For Each CurrencyItem In CurrenciesToBeImported Do
		NewRow = CurrencyList.Add();
		NewRow.CurrencyCode = CurrencyItem.Code;
		NewRow.Currency     = CurrencyItem;
	EndDo;
	
EndProcedure

// For each currency to be imported the procedure invokes the rate file
// The imported rates that satisfy the period are written in the information register
//
Function ImportCurrencyRates(ErrorsOccurredOnImport = False) Export
	
	Return CurrencyRateOperationsClientServer.ImportCurrencyRatesByParameters(
		CurrencyList,
		ImportPeriodBegin,
		ImportPeriodEnd,
		ErrorsOccurredOnImport);
	
EndFunction

#EndRegion

#EndIf
