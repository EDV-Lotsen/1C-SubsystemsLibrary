//Cutting SL1_0
//// Handler of event OnWrite of information register CurrencyRates.
//// On record of the new item(s) calls functionality of
//// recording of subordinate currency rates.
////
//Procedure OnWrite(Cancellation, Replacing)
//	
//	If DataExchange.Load Then
//		Return;
//	EndIf;
//	
//	If Count() > 0 Then
//		For Each Record In ThisObject Do
//			// Find all currencies depending on the current currency and change their rate
//			LoadRateForSubordinateCurrencies(Record.Currency,
//											 Record.Period,
//											 Record.ExchangeRate,
//											 Record.Multiplicity);
//		EndDo;
//	Else
//		DeleteRateForSubordinateCurrencies(Filter.Currency.Value, Filter.Period);
//	EndIf;
//	
//EndProcedure

//Procedure LoadRateForSubordinateCurrencies(CurrencyBasic, Period, ExchangeRate, Multiplicity)
//	
//	CurrenciesTable = WorkWithExchangeRates.GetDependentCurrenciesList(CurrencyBasic);
//	
//	RegisterCurrencyRates = InformationRegisters.CurrencyRates;
//		
//	For Each ItemCurrency In CurrenciesTable Do
//		WriteCurrencyRates = RegisterCurrencyRates.CreateRecordManager();
//		
//		WriteCurrencyRates.Currency     = ItemCurrency.Ref;
//		WriteCurrencyRates.Period    	= Period;
//		WriteCurrencyRates.ExchangeRate = ExchangeRate + ExchangeRate * ItemCurrency.SubordinateExchangeRateFactor / 100;
//		WriteCurrencyRates.Multiplicity = Multiplicity;
//		WriteCurrencyRates.Write();
//	EndDo;
//	
//EndProcedure

//Procedure DeleteRateForSubordinateCurrencies(CurrencyBasic, Period)
//	
//	CurrenciesTable = WorkWithExchangeRates.GetDependentCurrenciesList(CurrencyBasic);
//	
//	For Each ItemCurrency In CurrenciesTable Do
//		RecordSetCurrencyRates = InformationRegisters.CurrencyRates.CreateRecordSet();
//		RecordSetCurrencyRates.Filter.Currency.Value 		= ItemCurrency.Ref;
//		RecordSetCurrencyRates.Filter.Period.Value 			= Period.Value;
//		RecordSetCurrencyRates.Filter.Period.ValueTo 		= Period.ValueTo;
//		RecordSetCurrencyRates.Filter.Period.ValueFrom 		= Period.ValueFrom;
//		RecordSetCurrencyRates.Filter.Period.ComparisonType = Period.ComparisonType;
//		RecordSetCurrencyRates.Filter.Currency.Use 			= True;
//		RecordSetCurrencyRates.Filter.Period.Use 			= True;
//		
//		RecordSetCurrencyRates.Write();
//	EndDo;
//	
//EndProcedure
