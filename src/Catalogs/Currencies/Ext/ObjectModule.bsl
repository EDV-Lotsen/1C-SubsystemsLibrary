#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure FillCheckProcessing(Cancel, AttributesToCheck)
	
	If ValueIsFilled(MainCurrency.MainCurrency) Then
		CommonUseClientServer.MessageToUser(
			NStr("en = 'The main currency cannot be dependent.'"));
		Cancel = True;
	EndIf;
	
	If RateSettingMethod <> Enums.CurrencyRateSettingMethods.AnotherCurrencyMargin Then
		AttributesToExclude = New Array;
		AttributesToExclude.Add("MainCurrency");
		AttributesToExclude.Add("Margin");
		CommonUse.DeleteNoCheckAttributesFromArray(AttributesToCheck, AttributesToExclude);
	EndIf;
	
	If RateSettingMethod <> Enums.CurrencyRateSettingMethods.CalculateByFormula Then
		AttributesToExclude = New Array;
		AttributesToExclude.Add("RateCalculationFormula");
		CommonUse.DeleteNoCheckAttributesFromArray(AttributesToCheck, AttributesToExclude);
	EndIf;
	
	If Not IsNew()
		And RateSettingMethod = Enums.CurrencyRateSettingMethods.AnotherCurrencyMargin
		And CurrencyRateOperations.GetDependentCurrencyList(Ref).Count() > 0 Then
		CommonUseClientServer.MessageToUser(
			NStr("en = 'The currency cannot be dependent for it is the base for other currencies.'"));
		Cancel = True;
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	CurrencyRateOperations.CheckCurrencyRateFor01_01_1980(Ref);
	
	If RateSettingMethod = Enums.CurrencyRateSettingMethods.AnotherCurrencyMargin Then
		CurrencyRateOperations.WriteInfoForSubordinateRegister(MainCurrency, Ref);
	EndIf;
	
	If AdditionalProperties.Property("RefreshRates") Then
		CurrencyRateOperations.OnRefreshCurrencyRateSaaS(ThisObject);
	EndIf;
	
EndProcedure

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If CommonUseCached.DataSeparationEnabled() Then
		If Ref.IsEmpty() Or Ref.Code <> Code 
			Or Ref.RateSettingMethod <> RateSettingMethod Then
			AdditionalProperties.Insert("RefreshRates");
		EndIf;
	EndIf;
	
	If RateSettingMethod <> Enums.CurrencyRateSettingMethods.AnotherCurrencyMargin Then
		MainCurrency = Catalogs.Currencies.EmptyRef();
		Margin = 0;
	EndIf;
	
	If RateSettingMethod <> Enums.CurrencyRateSettingMethods.CalculateByFormula Then
		RateCalculationFormula = "";
	EndIf;
	
EndProcedure

#EndRegion

#EndIf
