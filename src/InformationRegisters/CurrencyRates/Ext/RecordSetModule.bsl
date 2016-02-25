#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

// The dependent currency rates are controlled while writing
//
Procedure OnWrite(Cancel, Replacing)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Not AdditionalProperties.Property("DisableDependentCurrencyControl") Then
		
		AdditionalProperties.Insert("DependentCurrencies", New Map);
		
		If Count() > 0 Then
			ImportDependentCurrencyRates();
		Else
			DeleteDependentCurrencyRates();
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

// Finds all dependent currencies to change their rates
//
Procedure ImportDependentCurrencyRates()
	
	For Each WriteOwnerCurrency In ThisObject Do
		
		DependentCurrencies = CurrencyRateOperations.GetDependentCurrencyList(WriteOwnerCurrency.Currency, AdditionalProperties);
		For Each TableRow In DependentCurrencies Do
			
			RecordSet = InformationRegisters.CurrencyRates.CreateRecordSet();
			RecordSet.Filter.Currency.Set(TableRow.Ref, True);
			RecordSet.Filter.Period.Set(WriteOwnerCurrency.Period, True);
			
			WriteCurrencyRate = RecordSet.Add();
			WriteCurrencyRate.Currency = TableRow.Ref;
			WriteCurrencyRate.Period = WriteOwnerCurrency.Period;
			If TableRow.RateSettingMethod = Enums.CurrencyRateSettingMethods.AnotherCurrencyMargin Then
				WriteCurrencyRate.Rate = WriteOwnerCurrency.Rate + WriteOwnerCurrency.Rate * TableRow.Margin / 100;
				WriteCurrencyRate.UnitConversionFactor = WriteOwnerCurrency.UnitConversionFactor;
			Else // by formula
				Rate = CurrencyRateByFormula(TableRow.Ref, TableRow.RateCalculationFormula, WriteOwnerCurrency.Period);
				If Rate <> Undefined Then
					WriteCurrencyRate.Rate = Rate;
					WriteCurrencyRate.UnitConversionFactor = 1;
				EndIf;
			EndIf;
				
			RecordSet.AdditionalProperties.Insert("DisableDependentCurrencyControl", True);
			
			If WriteCurrencyRate.Rate > 0 Then
				RecordSet.Write();
			EndIf;
			
		EndDo;
		
	EndDo;
	
EndProcedure

// Cleans dependent currency rates
//
Procedure DeleteDependentCurrencyRates()
	
	CurrencyOwner = Filter.Currency.Value;
	Period = Filter.Period;
	
	DependentCurrencies = CurrencyRateOperations.GetDependentCurrencyList(CurrencyOwner, AdditionalProperties);
	For Each TableRow In DependentCurrencies Do
		RecordSet = InformationRegisters.CurrencyRates.CreateRecordSet();
		RecordSet.Filter.Currency.Set(TableRow.Ref, True);
		RecordSet.Filter.Period.Set(Period, True);
		RecordSet.AdditionalProperties.Insert("DisableDependentCurrencyControl", True);
		RecordSet.Write();
	EndDo;
	
EndProcedure

Function CurrencyRateByFormula(Currency, Formula, Period)
	QueryText =
	"SELECT
	|	Currencies.Description AS AlphabeticCode,
	|	CurrencyRatesSliceLast.Rate / CurrencyRatesSliceLast.UnitConversionFactor AS Rate
	|FROM
	|	Catalog.Currencies AS Currencies
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&Period, ) AS CurrencyRatesSliceLast
	|		ON CurrencyRatesSliceLast.Currency = Currencies.Ref
	|WHERE
	|	Currencies.RateSettingMethod <> VALUE(Enum.CurrencyRateSettingMethods.AnotherCurrencyMargin)
	|	AND Currencies.RateSettingMethod <> VALUE(Enum.CurrencyRateSettingMethods.CalculateByFormula)";
	
	Query = New Query(QueryText);
	Query.SetParameter("Period", Period);
	Expression = Formula;
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		Expression = StrReplace(Expression, Selection.AlphabeticCode, Format(Selection.Rate, "NDS=.; NG=0"));
	EndDo;
	
	Try
		Result = SafeMode.EvaluateInSafeMode(Expression);
	Except
		ErrorInfo = ErrorInfo();
		ErrorText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'The %1 currency rate calculation by %2 formula is not executed:'", CommonUseClientServer.DefaultLanguageCode()), Currency, Formula);
			
		WriteLogEvent(NStr("en = 'Currencies.Currency rate import'", CommonUseClientServer.DefaultLanguageCode()),
			EventLogLevel.Error, Currency.Metadata(), Currency, 
			ErrorText + Chars.LF + DetailErrorDescription(ErrorInfo));
		CommonUseClientServer.MessageToUser(ErrorText + Chars.LF + BriefErrorDescription(ErrorInfo));
		Result = Undefined;
	EndTry;
	
	Return Result;
EndFunction

#EndRegion

#EndIf