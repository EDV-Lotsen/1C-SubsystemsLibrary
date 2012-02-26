

////////////////////////////////////////////////////////////////////////////////
// COMMON PROCEDURES AND FUNCTIONS

&AtServer
// Procedure fills parameters of form.
//
Procedure GetFormValuesOfParameters()
	
	DocumentCurrency				= Parameters.DocumentCurrency;
	DocumentCurrencyBeforeChange 	= Parameters.DocumentCurrency;
	ExchangeRate					= Parameters.ExchangeRate;
	RateBeforeChange 				= Parameters.ExchangeRate;
	Multiplicity 						= Parameters.Multiplicity;
	MultiplicityBeforeChange 			= Parameters.Multiplicity;
	
	DocumentDate = Parameters.DocumentDate;
	
EndProcedure // GetFormValuesOfParameters()

&AtServer
// Procedure fills table of currency rates
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
	
EndProcedure // FillExchangeRatesTable()

&AtClient
// Procedure fills document currency rate and Multiplicity.
//
Procedure FillRateMultiplicityOfDocumentCurrency()
	
	If ValueIsFilled(DocumentCurrency) Then
		ArrayRateMultiplicity = CurrencyRates.FindRows(New Structure("Currency", DocumentCurrency));
		If ValueIsFilled(ArrayRateMultiplicity) Then
			ExchangeRate = ArrayRateMultiplicity[0].ExchangeRate;
			Multiplicity = ArrayRateMultiplicity[0].Multiplicity;
		Else
			ExchangeRate = 0;
			Multiplicity = 0;
		EndIf;
	EndIf;
	
EndProcedure // FillRateMultiplicityOfDocumentCurrency()

&AtClient
// Procedure checks filling correctness of form attributes.
//
Procedure CheckFillOfFormAttributes(Cancellation)
    	
	If NOT ValueIsFilled(DocumentCurrency) Then
		Message = New UserMessage();
		Message.Text = NStr("en = 'Currency to fill in has not been selected'");
		Message.Field = "DocumentCurrency";
		Message.Message();
		Cancellation = True;
	EndIf;
	If NOT ValueIsFilled(ExchangeRate) Then
		Message = New UserMessage();
		Message.Text = NStr("en = 'Zero currency rate of the  document has been identified!'");
		Message.Field = "ExchangeRate";
		Message.Message();
		Cancellation = True;
	EndIf;
	If NOT ValueIsFilled(Multiplicity) Then
		Message = New UserMessage();
		Message.Text = NStr("en = 'Zero Multiplicity of the  document''s currency rate has been detected'");
		Message.Field = "AccountsMultiplicity";
		Message.Message();
		Cancellation = True;
	EndIf;	
	
EndProcedure // CheckFillOfFormAttributes()

&AtClient
// Procedure checks if form modified.
//
Function CheckIfFormWasModified()

	WereMadeChanges = False;

	If RecalculatePricesByCurrency 
		OR (RateBeforeChange 				<> ExchangeRate)
		OR (MultiplicityBeforeChange 			<> Multiplicity)
		OR (DocumentCurrencyBeforeChange 	<> DocumentCurrency) Then

        WereMadeChanges = True;

	EndIf; 
	
	Return WereMadeChanges;

EndFunction // CheckIfFormWasModified()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES - FORM EVENTS HANDLERS

&AtServer
// Procedure - handler of event OnCreateAtServer of form.
// Procedure does
// - initialization of form parameters.
//
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	GetFormValuesOfParameters();
	FillExchangeRatesTable();
		
EndProcedure // OnCreateAtServer()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES - ACTIONS OF FORM COMMAND BARS

&AtClient
// Procedure - handler of click event of button Cancel.
//
Procedure CancelExecute()
	
	ReturnStructure = New Structure();
	ReturnStructure.Insert("DialogReturnCode", DialogReturnCode.Cancel);
	ReturnStructure.Insert("WereMadeChanges",  False);
	Close(ReturnStructure);

EndProcedure // CancelExecute()

&AtClient
// Procedure - handler of click event of button OK.
//
Procedure ButtOKExecute()
	
	Cancellation = False;

	CheckFillOfFormAttributes(Cancellation);
	If NOT Cancellation Then
		WereMadeChanges = CheckIfFormWasModified();
		ReturnStructure = New Structure();
		ReturnStructure.Insert("DocumentCurrency", 				DocumentCurrency);
		ReturnStructure.Insert("ExchangeRate", 					ExchangeRate);
		ReturnStructure.Insert("Multiplicity", 					Multiplicity);
		ReturnStructure.Insert("RecalculatePricesByCurrency", 	RecalculatePricesByCurrency);
		ReturnStructure.Insert("WereMadeChanges", 				WereMadeChanges);
		ReturnStructure.Insert("DialogReturnCode", 				DialogReturnCode.OK);
		Close(ReturnStructure);
	EndIf;

EndProcedure // ButtOKExecute()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES - EVENT HANDLERS OF FORM ATTRIBUTES

&AtClient
// Procedure - handler of event OnChange of text box Currency.
//
Procedure CurrencyOnChange(Item)
	
	FillRateMultiplicityOfDocumentCurrency();
	If ValueIsFilled(DocumentCurrency) 
	   And DocumentCurrencyBeforeChange <> DocumentCurrency Then
  		RecalculatePricesByCurrency = True;
		FillRateMultiplicityOfDocumentCurrency();
  	Else
  		RecalculatePricesByCurrency = False;
	EndIf;
	
EndProcedure // CurrencyOnChange()

&AtClient
// Procedure - handler of event OnChange of text box DocumentCurrencyRate.
//
Procedure DocumentCurrencyRateOnChange(Item)
	
	If ValueIsFilled(ExchangeRate) 
	   And RateBeforeChange <> ExchangeRate Then
		RecalculatePricesByCurrency = True;
	Else
		RecalculatePricesByCurrency = False;
	EndIf;
	
EndProcedure

&AtClient
// Procedure - handler of event OnChange of text box MultiplicityDocumentCurrencies.
//
Procedure MultiplicityDocumentCurrenciesOnChange(Item)
	
	If ValueIsFilled(Multiplicity) 
	   And MultiplicityBeforeChange <> Multiplicity Then
		RecalculatePricesByCurrency = True;
	Else
		RecalculatePricesByCurrency = False;
	EndIf;
	
EndProcedure
