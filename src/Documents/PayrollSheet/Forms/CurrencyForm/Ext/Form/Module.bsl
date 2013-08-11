////////////////////////////////////////////////////////////////////////////////
// COMMON PROCEDURES AND FUNCTIONS

&AtServer
// Fills form parameters.
//
Procedure GetFormValuesOfParameters()
	
	DocumentCurrency				= Parameters.DocumentCurrency;
	DocumentCurrencyBeforeChange 	= Parameters.DocumentCurrency;
	AccountsCurrency				= Parameters.AccountsCurrency;
	AccountsCurrencyBeforeChange 	= Parameters.AccountsCurrency;
	ExchangeRate 					= Parameters.ExchangeRate;
	RateBeforeChange 				= Parameters.ExchangeRate;
	Multiplicity 						= Parameters.Multiplicity;
	MultiplicityBeforeChange 			= Parameters.Multiplicity;
	
	DocumentDate = Parameters.DocumentDate;
			
EndProcedure

&AtServer
// Fills the table of currency rates
//
Procedure FillExchangeRatesTable()
	
	Query = New Query;
	Query.SetParameter("DocumentDate", DocumentDate);
	Query.Text = 
	"SELECT
	|	CurrencyRatesSliceLast.Currency,
	|	CurrencyRatesSliceLast.ExchangeRate,
	|	CurrencyRatesSliceLast.Multiplicity
	|FROM
	|	InformationRegister.CurrencyRates.SliceLast(&DocumentDate, ) AS CurrencyRatesSliceLast";
	
	QueryResultTable = Query.Execute().Unload();
	CurrencyRates.Load(QueryResultTable);
	
EndProcedure

&AtClient
// Fills the document currency rate and Multiplicity.
//
Procedure FillRateMultiplicityOfAccountsCurrency()
	
	If ValueIsFilled(DocumentCurrency) Then
		ArrayRateMultiplicity = CurrencyRates.FindRows(New Structure("Currency", AccountsCurrency));
		If ValueIsFilled(ArrayRateMultiplicity) Then
			ExchangeRate = ArrayRateMultiplicity[0].ExchangeRate;
			Multiplicity = ArrayRateMultiplicity[0].Multiplicity;
		Else
			ExchangeRate = 0;
			Multiplicity = 0;
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
// Checks whether form attributes are filled correctly.
//
Procedure CheckFillOfFormAttributes(Cancellation)
    	
	If NOT ValueIsFilled(DocumentCurrency) Then
		Message = New UserMessage();
		Message.Text = NStr("en = 'The currency to be filled is not selected.'");
		Message.Field = "DocumentCurrency";
		Message.Message();
		Cancellation = True;
	EndIf;
	If NOT ValueIsFilled(ExchangeRate) Then
		Message = New UserMessage();
		Message.Text = NStr("en = 'The accounting currency rate is equal to zero.'");
		Message.Field = "ExchangeRate";
		Message.Message();
		Cancellation = True;
	EndIf;
	If NOT ValueIsFilled(Multiplicity) Then
		Message = New UserMessage();
		Message.Text = NStr("en = 'The accounting currency multiplicity is equal to zero.'");
		Message.Field = "AccountsMultiplicity";
		Message.Message();
		Cancellation = True;
	EndIf;
	If NOT ValueIsFilled(AccountsCurrency) Then
		Message = New UserMessage();
		Message.Text = NStr("en = 'The accounting currency to be filled is not selected.'");
		Message.Field = "AccountsCurrency";
		Message.Message();
		Cancellation = True;
	EndIf;
	
EndProcedure

&AtClient
// Checks whether the form is modified.
//
Function CheckIfFormWasModified()

	WereMadeChanges = False;

	If RecalculatePricesByCurrency 
		OR (RateBeforeChange <> ExchangeRate)
		OR (MultiplicityBeforeChange <> Multiplicity)
		OR (AccountsCurrencyBeforeChange <> AccountsCurrency)
		OR (DocumentCurrencyBeforeChange <> DocumentCurrency) Then

        WereMadeChanges = True;

	EndIf; 
	
	Return WereMadeChanges;

EndFunction

////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
// OnCreateAtServe event handler.
// Initializes form parameters.
//
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	GetFormValuesOfParameters();
	FillExchangeRatesTable();
		
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND BAR ACTION HANDLERS

&AtClient
// Cancel button click event handler.
//
Procedure CancelExecute()
	
	ReturnStructure = New Structure();
	ReturnStructure.Insert("DialogReturnCode", DialogReturnCode.Cancel);
	ReturnStructure.Insert("WereMadeChanges", False);
	Close(ReturnStructure);

EndProcedure

&AtClient
// OK button click event handler.
//
Procedure ButtOKExecute()
	
	Cancellation = False;

	CheckFillOfFormAttributes(Cancellation);
	If NOT Cancellation Then
		WereMadeChanges = CheckIfFormWasModified();
		ReturnStructure = New Structure();
		ReturnStructure.Insert("DocumentCurrency", 				DocumentCurrency);
		ReturnStructure.Insert("AccountsCurrency", 				AccountsCurrency);
		ReturnStructure.Insert("ExchangeRate", 					ExchangeRate);
		ReturnStructure.Insert("Multiplicity", 					Multiplicity);
		ReturnStructure.Insert("RecalculatePricesByCurrency", 	RecalculatePricesByCurrency);
		ReturnStructure.Insert("WereMadeChanges", 				WereMadeChanges);
		ReturnStructure.Insert("DialogReturnCode", 				DialogReturnCode.OK);
		Close(ReturnStructure);
	EndIf;

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM ATTRIBUTE EVENT HANDLERS

&AtClient
// Currency input field OnChange event handler.
//
Procedure CurrencyOnChange(Item)
	
	FillRateMultiplicityOfAccountsCurrency();
	If ValueIsFilled(AccountsCurrency) 
	   And AccountsCurrencyBeforeChange <> AccountsCurrency Then
  		RecalculatePricesByCurrency = True;
  	Else
  		RecalculatePricesByCurrency = False;
	EndIf;
	
EndProcedure

&AtClient
// AccountsCurrencyRate input field OnChange event handler.
//
Procedure AccountsCurrencyRateOnChange(Item)
	
	If ValueIsFilled(ExchangeRate) 
	   And RateBeforeChange <> ExchangeRate Then
		RecalculatePricesByCurrency = True;
	Else
		RecalculatePricesByCurrency = False;
	EndIf;
	
EndProcedure

&AtClient
// MultiplicityAccountsCurrencies input field OnChange event handler.
//
Procedure MultiplicityAccountsCurrenciesOnChange(Item)
	
	If ValueIsFilled(Multiplicity) 
	   And MultiplicityBeforeChange <> Multiplicity Then
		RecalculatePricesByCurrency = True;
	Else
		RecalculatePricesByCurrency = False;
	EndIf;
	
EndProcedure
