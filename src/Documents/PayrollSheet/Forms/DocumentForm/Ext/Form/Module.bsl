////////////////////////////////////////////////////////////////////////////////
// COMMON PROCEDURES AND FUNCTIONS

&AtServer
// Fills the Employees tabular section by the accrual balance.
//
Procedure FillByBalanceAtServer()	
	
	Document = FormAttributeToValue("Object");
	Document.FillByBalanceAtServer();
	ValueToFormAttribute(Document, "Object");
	
EndProcedure

&AtServerNoContext
// Retrieves a dataset from the server for the DateOnChange procedure.
//
Function GetDataDateOnChange(DocumentRef, DateNew, DateBeforeChange)
	
	StructureData = New Structure();
	StructureData.Insert("Datediff", _DemoPayrollAndHRServer.CheckDocumentNo(DocumentRef, DateNew, DateBeforeChange));
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
// Retrieves a record set from the server for the AgreementOnChange procedure.
//
Function GetCompanyDataOnChange(Company)
	
	StructureData = New Structure();
	StructureData.Insert("Company", Company);
	
	Return StructureData;
	
EndFunction

&AtClient

Procedure RecalculateAmountByCurrency(TabularSectionLine, ReverseDirection = False)	
	
	If ReverseDirection Then
		
		If Object.DocumentCurrency = Object.AccountsCurrency Then
			TabularSectionLine.AccountsAmount = TabularSectionLine.PaymentAmount;	
		ElsIf Object.ExchangeRate = 0 Then
			TabularSectionLine.AccountsAmount = 0;
		Else
			TabularSectionLine.AccountsAmount = TabularSectionLine.PaymentAmount * Object.Multiplicity / Object.ExchangeRate;	
		EndIf;
	
	Else
	
		If Object.DocumentCurrency = Object.AccountsCurrency Then
			TabularSectionLine.AccountsAmount = TabularSectionLine.PaymentAmount;	
		ElsIf Object.Multiplicity = 0 Then
			TabularSectionLine.PaymentAmount = 0;
		Else
			TabularSectionLine.PaymentAmount = TabularSectionLine.AccountsAmount * Object.ExchangeRate / Object.Multiplicity;	
		EndIf;
	
	EndIf;		 
	
EndProcedure

&AtServer
Procedure SetVisibilityFromCurrency()
	
	If Object.DocumentCurrency = Object.AccountsCurrency Then
		Items.EmployeesAccountsAmount.Visible 		= False;
		Items.EmployeesTotalAccountsAmount.Visible 	= False;
		Items.AccountsCurrency.Visible 				= False;
		Items.Comment.TitleLocation 				= FormItemTitleLocation.Left;
	Else
		Items.EmployeesAccountsAmount.Visible 		= True;
		Items.EmployeesTotalAccountsAmount.Visible 	= True;
		Items.AccountsCurrency.Visible 				= True;
		Items.Comment.TitleLocation 				= FormItemTitleLocation.Top;	
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS REQUIRED FOR MANAGING THE FORM INTERFACE

&AtClient
// Recalculates document tabular section once the "Prices and currency" form data is changed.
// The following columns are recalculated: Price, Discount, Amount, Total.
//
Procedure ProcessChangesOnButtonPricesAndCurrencies(Val AccountsCurrencyBeforeChange, RecalculatePrices = False)
	
	// 1. Generating a parameter structure to fill the "Prices and currency" form
	StructureOfParameters = New Structure;
	StructureOfParameters.Insert("DocumentCurrency",		  	Object.DocumentCurrency);
	StructureOfParameters.Insert("AccountsCurrency",		  	Object.AccountsCurrency);
	StructureOfParameters.Insert("ExchangeRate",				Object.ExchangeRate);
	StructureOfParameters.Insert("Multiplicity",			  	Object.Multiplicity);
	StructureOfParameters.Insert("Company",			  	        Company);
	StructureOfParameters.Insert("DocumentDate",		  		Object.Date);
	StructureOfParameters.Insert("RecalculatePricesByCurrency",	False);
	StructureOfParameters.Insert("WereMadeChanges",  			False);
	
	// 2. Opening the "Prices and currency" form
	StructurePricesAndCurrency = OpenFormModal("Document.PayrollSheet.Form.CurrencyForm", StructureOfParameters);
	
	// 3. Refilling the Inventory tabular section if the "Prices and Currency" form is changed
	If TypeOf(StructurePricesAndCurrency) = Type("Structure") And StructurePricesAndCurrency.WereMadeChanges Then
		
		Object.DocumentCurrency 	= StructurePricesAndCurrency.DocumentCurrency;
		Object.AccountsCurrency 	= StructurePricesAndCurrency.AccountsCurrency;
		Object.ExchangeRate 		= StructurePricesAndCurrency.ExchangeRate;
		Object.Multiplicity 			= StructurePricesAndCurrency.Multiplicity;
		
		// Recalculating the prices based on the currency
		If StructurePricesAndCurrency.RecalculatePricesByCurrency Then
			For each TabularSectionLine In Object.Employees Do
				RecalculateAmountByCurrency(TabularSectionLine);
			EndDo; 
		EndIf;
		
		SetVisibilityFromCurrency();
		
	EndIf;
	
	// Generating the price and currency label
	PricesAndCurrency = NStr("en = 'Accounts currency: %Currency%, rate: %ExchangeRate%; Document currency: %DocumentCurrency%'");
	PricesAndCurrency = StrReplace(PricesAndCurrency, "%Currency%", TrimAll(String(Object.AccountsCurrency)));
	PricesAndCurrency = StrReplace(PricesAndCurrency, "%ExchangeRate%", TrimAll(String(Object.ExchangeRate)));
	PricesAndCurrency = StrReplace(PricesAndCurrency, "%DocumentCurrency%", TrimAll(String(Object.DocumentCurrency)));
		
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
// OnCreateAtServer event handler.
// Performs the following actions:
// - initializes form parameters;
// - sets parameters of the form functional options.
//
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	_DemoPayrollAndHRServer.FillDocumentHeader(Object,
	Parameters.CopyingValue,
	Parameters.Basis,
	DocumentStatus,
	PictureDocumentStatus,
	PostingIsAllowed,
	Parameters.FillingValues);
	
	If NOT ValueIsFilled(Object.Ref)
		And NOT (Parameters.FillingValues.Property("AccountingPeriod") And ValueIsFilled(Parameters.FillingValues.AccountingPeriod)) Then
		Object.AccountingPeriod 	= BegOfMonth(CurrentDate());
	EndIf;
	
	// Setting the form attributes
	DocumentDate = Object.Date;
	If NOT ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentDate();
	EndIf;
	
	Company = Object.Company;
	
	// Filling the form data.
	PricesAndCurrency = NStr("en = 'Accounting currency: %Currency%, rate: %ExchangeRate%; Document currency: %DocumentCurrency%'");
	PricesAndCurrency = StrReplace(PricesAndCurrency, "%Currency%", TrimAll(String(Object.AccountsCurrency)));
	PricesAndCurrency = StrReplace(PricesAndCurrency, "%ExchangeRate%", TrimAll(String(Object.ExchangeRate)));
	PricesAndCurrency = StrReplace(PricesAndCurrency, "%DocumentCurrency%", TrimAll(String(Object.DocumentCurrency)));
	
	SetVisibilityFromCurrency();
	
	If Items.Find("EmployeesEmployeeCode") <> Undefined Then		
		Items.EmployeesEmployeeCode.Visible = False;		
	EndIf; 
	
EndProcedure

&AtClient
// AfterWrite event handler.
//
Procedure AfterWrite(WriteParameters)
	
	_DemoPayrollAndHRClient.RefreshDocumentStatus(Object, DocumentStatus, PictureDocumentStatus, PostingIsAllowed);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND BAR ACTION HANDLERS

&AtClient
// FillAndCalculateRun event handler.
//
Procedure FillByBalance(Command)
	
	FillByBalanceAtServer();		
	
EndProcedure

&AtClient
// Is called when clicking the PricesAndCurrency tabular section command bar button.
//
Procedure EditPricesAndCurrency(Command)
	
	ProcessChangesOnButtonPricesAndCurrencies(Object.DocumentCurrency);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// HEADER ATTRIBUTE EVENT HANDLERS

&AtClient
// AccountingPeriod attribute OnChange event handler.
//
Procedure AccountingPeriodOnChange(Item)
	
	_DemoPayrollAndHRClient.OnChangeAccountingPeriod(ThisForm);
	
EndProcedure

&AtClient
// Date input field OnChange event handler.
// Assigns a new unique number to the document if it is moved to another numbering 
// period because its date was changed. 
// Overrides the corresponding form parameter.
//
Procedure DateOnChange(Item)
	
	// Processing the date change event.
	DateBeforeChange = DocumentDate;
	DocumentDate = Object.Date;
	If Object.Date <> DateBeforeChange Then
		StructureData = GetDataDateOnChange(Object.Ref, Object.Date, DateBeforeChange);
		If StructureData.Datediff <> 0 Then
			Object.Number = "";
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
// Company input field OnChange event handler.
// Clears the document number and sets the form functional option parameters.
// Overrides the corresponding form parameter.
//
Procedure CompanyOnChange(Item)

	// Processing the Company change event.
	Object.Number = "";
	StructureData = Object.Company;
	Company = StructureData;
	
EndProcedure

&AtClient
// AccountsAmount input field OnChange event handler.
// Clears the document number and sets parameters of the form functional options.
// Overrides the corresponding form parameter.
//
Procedure AccountsAmountOnChange(Item)
	RecalculateAmountByCurrency(Items.Employees.CurrentData);
EndProcedure

&AtClient
// EmployeesPaymentAmount input field OnChange event handler.
// Clears the document number and sets parameters of the form functional options.
// Overrides the corresponding form parameter.
//
Procedure EmployeesPaymentAmountOnChange(Item)
	RecalculateAmountByCurrency(Items.Employees.CurrentData, True);
EndProcedure









