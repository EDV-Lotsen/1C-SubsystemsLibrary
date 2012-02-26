

// Procedure fills tabular section with list of currencies. List contains only those
// currencies, whose rate does not depend on rate of other currencies.
//
Procedure FillCurrencyList() Export
	
	CurrencyList.Clear();
	
	LoadableCurrencies = WorkWithExchangeRates.GetLoadCurrenciesArray();
	
	For Each ItemCurrency In LoadableCurrencies Do
		NewRow = CurrencyList.Add();
		NewRow.CurrencyCode = ItemCurrency.Code;
		NewRow.Currency     = ItemCurrency;
	EndDo;
	
EndProcedure

// Procedure for every loaded currency requests file with rates
// After load, rates, matching period is written to information register
//
Function LoadCurrencyRates(Val ErrorMessage) Export
	
	Return WorkWithExchangeRatesClientServer.LoadCurrencyRatesByParameters(
	                  CurrencyList,
	                  LoadPeriodBegin,
	                  LoadPeriodEnding,
	                  ErrorMessage);
	
EndFunction
