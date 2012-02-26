
////////////////////////////////////////////////////////////////////////////////
// Block of form and form item event handlers
//

// Handler of event "on create at server"
// Sets start and end dates for load rates by default
//
&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	Object.LoadPeriodBegin = BegOfMonth(CurrentDate());
	Object.LoadPeriodEnding = CurrentDate();
	
EndProcedure

// Handler of form event "choice processing"
// Handles currency choice in choice fomr
//
&AtClient
Procedure ChoiceProcessing(ChoiceResult, ChoiceSource)
	
	If TypeOf(ChoiceResult) = Type("CatalogRef.Currencies") Then
		
		If Object.CurrencyList.FindRows(New Structure("Currency", ChoiceResult)).Count() = 0 Then
			AddCurrencyToList(ChoiceResult);
		Else
			DoMessageBox(NStr("en = 'Currency is in the list already'"));
		EndIf;
		
	EndIf;
	
EndProcedure

// Handler of event "before add row" of form item CurrencyList
// Calls currency choice form in choice mode
//
&AtClient
Procedure CurrencyListBeforeAddRow(Item, Cancellation, Clone, Parent, Folder)
	
	ParametersForm = New Structure("LoadableCurrencies", True);
	OpenForm("Catalog.Currencies.ChoiceForm", ParametersForm, ThisForm);
	Cancellation = True;
	
EndProcedure

// Handler of event "Selection" of tabular section "CurrencyList" of form
// Open currency form
//
&AtClient
Procedure CurrencyListSelection(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	OpenValue(Items.CurrencyList.CurrentData.Currency);
	
EndProcedure

// Handler of button click event "Clear"
// Clears list of currencies
//
&AtClient
Procedure CommandClearExecute()
	
	Object.CurrencyList.Clear();
	
EndProcedure

// Handler of click event "Fill"
// Calls functionality of currency list filling
//
&AtClient
Procedure CommandFillCurrencyListExecute()
	
	FillCurrencies();
	
EndProcedure

// Handler of click event "Fill"
// Calls currency choice form in pickup mode
//
&AtClient
Procedure CommandCurrenciesFillExecute()
	
	FormParameters = New Structure("CloseOnChoice, Filter", False, New Structure("DownloadRatesPeriodically", True));
	OpenForm("Catalog.Currencies.ChoiceForm", FormParameters, ThisForm);
	
EndProcedure

// Handler of click event "Load"
// Calls functionality of rate loading
//
&AtClient
Procedure CommandLoadExecute()
	
	If Not ValueIsFilled(Object.LoadPeriodBegin) Then
		CommonUseClientServer.MessageToUser(
					NStr("en = 'Beginning date of loading period has not been defined'"), ,
					"Object.LoadPeriodBegin");
		Return;
	EndIf;
	
	If Not ValueIsFilled(Object.LoadPeriodEnding) Then
		CommonUseClientServer.MessageToUser(
					NStr("en = 'End date of loading period has not been defined'"), ,
					"Object.LoadPeriodEnding");
		Return;
	EndIf;
	
	If Object.CurrencyList.Count() = 0 Then
		CommonUseClientServer.MessageToUser(
					NStr("en = 'To download rates from the RBK web server it is necessary to add at least one currency.'"), ,
					"Object.CurrencyList");
		Return;
	EndIf;
	
	ClearMessages();
	
	Status(NStr("en = 'Download exchange rates...'"));
	ExplainingMessage = "";
	OperationStatus = LoadCurrencyRatesFromRBK(ExplainingMessage);
	
	If OperationStatus Then
		Notify("CurrencyRateUpdate");
		MessageTextThatLoadCompleted = NStr("en = 'Exchange rates update completed'");
		If ValueIsFilled(ExplainingMessage) Then
			MessageTextThatLoadCompleted = MessageTextThatLoadCompleted + Chars.LF
										+ ExplainingMessage;
		EndIf;
		Status(MessageTextThatLoadCompleted);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Section of service procedures
//

&AtClient
Function LoadCurrencyRatesFromRBK(ExplainingMessage)
	
	ExplainingMessage = "";
	
#If WebClient Then
	OperationStatus = LoadCurrencyRatesFromRBKServer(
			Object.CurrencyList,
			Object.LoadPeriodBegin,
			Object.LoadPeriodEnding,
			ExplainingMessage);
#Else
	OperationStatus = WorkWithExchangeRatesClientServer.LoadCurrencyRatesByParameters(
				Object.CurrencyList,
				Object.LoadPeriodBegin,
				Object.LoadPeriodEnding,
				ExplainingMessage);
#EndIf
	
	If Not OperationStatus Then
		CommonUseClientServer.MessageToUser(ExplainingMessage);
	Else
		RefreshInfoInCurrencyList();
	EndIf;
	
	Return OperationStatus;
	
EndFunction

&AtServerNoContext
Function LoadCurrencyRatesFromRBKServer(Val CurrencyList, Val LoadPeriodBegin, Val LoadPeriodEnding, ExplainingMessage)
	
	Return WorkWithExchangeRatesClientServer.LoadCurrencyRatesByParameters(
				CurrencyList, LoadPeriodBegin, LoadPeriodEnding, ExplainingMessage);
	
EndFunction

// Procedure fills tabular section with list of currencies. List contains only those
// currencies, whose rate does not depend on rate of other currencies.
//
&AtServer
Procedure FillCurrencies()
	
	LoadPeriodEnding = Object.LoadPeriodEnding;
	CurrencyList = Object.CurrencyList;
	CurrencyList.Clear();
	
	LoadableCurrencies = WorkWithExchangeRates.GetLoadCurrenciesArray();
	
	For Each ItemCurrency In LoadableCurrencies Do
		AddCurrencyToList(ItemCurrency);
	EndDo;
	
EndProcedure

// Procedure adds new row to currency list and fills it with information
// about rate based on ref to currency
//
// Parameters:
// Currency - Catalog.Currencies / Ref - ref to currency, being added
//                 to the list
//
&AtServer
Procedure AddCurrencyToList(Currency)
	
	NewRow = Object.CurrencyList.Add();
	FillTableRowDataBasedOnCurrency(NewRow, Currency);
	
EndProcedure

// Procedure refreshes currency rate records in the list.
//
&AtServer
Procedure RefreshInfoInCurrencyList()
	
	For Each DataString In Object.CurrencyList Do
		CurrencyRef = DataString.Currency;
		FillTableRowDataBasedOnCurrency(DataString, CurrencyRef);
	EndDo;
	
EndProcedure

// Procedure fills tabular section line with information about rate based on
// ref to currency.
//
// Parameters:
// CurRow       - FormDataCollectionItem - ref to tabular section
//                  line, that has to be filled with information about
//                  currency rate
// SelectedCurrency - Catalog.Currencies / Ref - ref to currency, whose information
//                  needs to be received.
//
&AtServer
Procedure FillTableRowDataBasedOnCurrency(CurRow, CurrencyRef);
	
	CurRow.Currency = CurrencyRef;
	CurRow.CurrencyCode = CurrencyRef.Code;
	
	RateData = WorkWithExchangeRates.FillRateDataForCurrencies(CurrencyRef);
	
	If TypeOf(RateData) = Type ("Structure") Then
		CurRow.RateDate = RateData.RateDate;
		CurRow.ExchangeRate      = RateData.ExchangeRate;
		CurRow.Multiplicity = RateData.Multiplicity;
	EndIf;
	
EndProcedure
