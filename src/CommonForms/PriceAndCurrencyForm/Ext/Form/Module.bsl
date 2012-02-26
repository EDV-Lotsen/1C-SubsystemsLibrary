

////////////////////////////////////////////////////////////////////////////////
// COMMON PROCEDURES AND FUNCTIONS

&AtServer
// Procedure fills parameters of form.
//
Procedure GetFormValuesOfParameters()
	
	If Parameters.Property("DocumentCurrencyAccessibility") Then
		
		Items.Currency.Enabled = Parameters.DocumentCurrencyAccessibility;
		Items.RecalculatePrices.Visible = Parameters.DocumentCurrencyAccessibility;
		
	EndIf;
	
	// Document currency .
	If Parameters.Property("DocumentCurrency") Then
		
		DocumentCurrency = Parameters.DocumentCurrency;
		DocumentCurrencyOnOpen = Parameters.DocumentCurrency;
		DocumentCurrencyIsAttribute = True;
		
	Else
		
		Items.DocumentCurrency.Visible 	= False;
		Items.ExchangeRate.Visible 		= False;
		Items.Multiplicity.Visible 		= False;
		Items.RecalculatePrices.Visible = False;
		DocumentCurrencyIsAttribute 	= False;
		
	EndIf;
	
	// Accounts currency.
	If Parameters.Property("Agreement") Then
		
		AccountsCurrency	  		= Parameters.Agreement.AccountsCurrency;
		AccountsRate 	  			= Parameters.ExchangeRate;
		AccountsMultiplicity 			= Parameters.Multiplicity;
		
		AccountsRateOnOpen 	 		= Parameters.ExchangeRate;
		AccountsMultiplicityOnOpen 	= Parameters.Multiplicity;
		
		AgreementIsAttribute = True;
		
	Else
		
		Items.AccountsCurrency.Visible 	 = False;
		Items.AccountsRate.Visible 		 = False;
		Items.AccountsMultiplicity.Visible = False;
		
		AgreementIsAttribute = False;
		
	EndIf;
	
	RecalculatePrices = Parameters.RecalculatePrices;
		
	If ValueIsFilled(DocumentCurrency) Then
		ArrayRateMultiplicity = CurrencyRates.FindRows(New Structure("Currency", DocumentCurrency));
		If DocumentCurrency = AccountsCurrency
		   And AccountsRate <> 0
		   And AccountsMultiplicity <> 0 Then
			ExchangeRate = AccountsRate;
			Multiplicity = AccountsMultiplicity;
		Else
			If ValueIsFilled(ArrayRateMultiplicity) Then
				ExchangeRate = ArrayRateMultiplicity[0].ExchangeRate;
				Multiplicity = ArrayRateMultiplicity[0].Multiplicity;
			Else
				ExchangeRate = 0;
				Multiplicity = 0;
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure // GetFormValuesOfParameters()

&AtServer
// Procedure fills table of currency rates
//
Procedure FillExchangeRatesTable()
	
	Query = New Query;
	Query.SetParameter("DocumentDate", Parameters.DocumentDate);
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
// Procedure checks filling correctness of form attributes.
//
Procedure CheckFillOfFormAttributes(Cancellation)
    	
	// Attribute filling check.
	
	// Document currency .
	If DocumentCurrencyIsAttribute Then
		If NOT ValueIsFilled(DocumentCurrency) Then
            Message = New UserMessage();
			Message.Text = NStr("en = 'Document currency not filled in!'");
			Message.Field = "DocumentCurrency";
			Message.Message();
			Cancellation = True;
   		EndIf;
	EndIf;
	
	// Accounts.
	If AgreementIsAttribute Then
		If NOT ValueIsFilled(AccountsRate) Then
			Message = New UserMessage();
			Message.Text = NStr("en = 'Zero currency accounts has been identified!'");
			Message.Field = "AccountsRate";
			Message.Message();
			Cancellation = True;
		EndIf;
		If NOT ValueIsFilled(AccountsMultiplicity) Then
			Message = New UserMessage();
			Message.Text = NStr("en = 'Zero Multiplicity of the  document''s currency accounts  has been detected'");
			Message.Field = "AccountsMultiplicity";
			Message.Message();
			Cancellation = True;
		EndIf;
	EndIf;
		
EndProcedure // CheckFillOfFormAttributes()

&AtClient
// Procedure checks if form modified.
//
Procedure CheckIfFormWasModified()

	WereMadeChanges = False;
	
	ChangesDocumentCurrency 		= ?(DocumentCurrencyIsAttribute, DocumentCurrencyOnOpen <> DocumentCurrency, False);
    ChangesAccountsRate 			= ?(AgreementIsAttribute, AccountsRateOnOpen <> AccountsRate, False);
    ChangesAccountsMultiplicity 		= ?(AgreementIsAttribute, AccountsMultiplicityOnOpen <> AccountsMultiplicity, False);
    
	If RecalculatePrices
	 OR ChangesDocumentCurrency
	 OR ChangesAccountsRate
	 OR ChangesAccountsMultiplicity Then	

		WereMadeChanges = True;

	EndIf;
	
EndProcedure // CheckIfFormWasModified()

&AtClient
// Procedure fills document currency rate and Multiplicity.
//
Procedure FillRateMultiplicityOfDocumentCurrency()
	
	If ValueIsFilled(DocumentCurrency) Then
		ArrayRateMultiplicity = CurrencyRates.FindRows(New Structure("Currency", DocumentCurrency));
		If DocumentCurrency = AccountsCurrency
		   And AccountsRate <> 0
		   And AccountsMultiplicity <> 0 Then
			ExchangeRate 	= AccountsRate;
			Multiplicity 		= AccountsMultiplicity;
		Else
			If ValueIsFilled(ArrayRateMultiplicity) Then
				ExchangeRate 	= ArrayRateMultiplicity[0].ExchangeRate;
				Multiplicity 		= ArrayRateMultiplicity[0].Multiplicity;
			Else
				ExchangeRate = 0;
				Multiplicity = 0;
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure // FillRateMultiplicityOfDocumentCurrency()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES - FORM EVENTS HANDLERS

&AtServer
// Procedure - handler of event OnCreateAtServer of form.
// Procedure does
// 			 - initialization of form parameters.
//
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	DefaultCurrency = Catalogs.Currencies.NationalCurrency;
	FillExchangeRatesTable();
	GetFormValuesOfParameters();
	
	If AgreementIsAttribute Then	
		NewArray = New Array();
		NewArray.Add(AccountsCurrency);
		NewParameter  = New ChoiceParameter("Filter.Ref", New FixedArray(NewArray));
		NewArray2 	  = New Array();
		NewArray2.Add(NewParameter);
		NewParameters = New FixedArray(NewArray2);
		Items.Currency.ChoiceParameters = NewParameters;
	EndIf;
	
EndProcedure // OnCreateAtServer()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES - ACTIONS OF FORM COMMAND BARS

&AtClient
// Procedure - handler of click event of button OK.
//
Procedure CommandOK(Command)
	
	Cancellation = False;

	CheckFillOfFormAttributes(Cancellation);
	CheckIfFormWasModified();
    
	If NOT Cancellation Then

		FormAttributesStructure = New Structure;

        FormAttributesStructure.Insert("WereMadeChanges", 		WereMadeChanges);

		FormAttributesStructure.Insert("DocumentCurrency", 		DocumentCurrency);

		FormAttributesStructure.Insert("AccountsCurrency", 		AccountsCurrency);
		FormAttributesStructure.Insert("ExchangeRate", 			ExchangeRate);
		FormAttributesStructure.Insert("AccountsRate", 			AccountsRate);
		FormAttributesStructure.Insert("Multiplicity", 			Multiplicity);
        FormAttributesStructure.Insert("AccountsMultiplicity", 	AccountsMultiplicity);
                         
		FormAttributesStructure.Insert("PrevDocumentCurrency", 	DocumentCurrencyOnOpen);

        FormAttributesStructure.Insert("RecalculatePrices", 	RecalculatePrices);

		FormAttributesStructure.Insert("FormName", 				"CommonForm.CurrencyForm");

		Close(FormAttributesStructure);

	EndIf;
	
EndProcedure // CommandOK()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES - EVENT HANDLERS OF FORM ATTRIBUTES

&AtClient
// Procedure - handler of event OnChange of text box Currency.
//
Procedure CurrencyOnChange(Item)
	
	FillRateMultiplicityOfDocumentCurrency();

	If ValueIsFilled(DocumentCurrency)
		
	   And DocumentCurrencyOnOpen <> DocumentCurrency Then
  		RecalculatePrices = True;
		
  	EndIf;

EndProcedure // CurrencyOnChange()

&AtClient
// Procedure - handler of event OnChange of text box AccountsCurrency.
//
Procedure AccountsCurrencyOnChange(Item)
	
	FillRateMultiplicityOfDocumentCurrency();

EndProcedure // AccountsCurrencyOnChange()

&AtClient
// Procedure - handler of event OnChange of text box AccountsRate.
//
Procedure AccountsRateOnChange(Item)
	
	FillRateMultiplicityOfDocumentCurrency();

EndProcedure // AccountsRateOnChange()

&AtClient
// Procedure - handler of event OnChange of text box AccountsMultiplicity.
//
Procedure AccountsMultiplicityOnChange(Item)
	
	FillRateMultiplicityOfDocumentCurrency();

EndProcedure // AccountsMultiplicityOnChange()
