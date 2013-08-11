
&AtClient
Procedure BankAccountOnChange(Item)
	
	Items.BankAccountLabel.Title =
		CommonUse.GetAttributeValue(Object.BankAccount, "Description");

	Object.Number = _DemoGeneralFunctions.NextCheckNumber(Object.BankAccount);	
	
	AccountCurrency = CommonUse.GetAttributeValue(Object.BankAccount, "Currency");
	Object.ExchangeRate = _DemoGeneralFunctions.GetExchangeRate(Object.Date, AccountCurrency);
	
	Items.ExchangeRate.Title = _DemoGeneralFunctionsCached.DefaultCurrencySymbol() + "/1" + CommonUse.GetAttributeValue(AccountCurrency, "Symbol");
	
	Items.FCYCurrency.Title = CommonUse.GetAttributeValue(AccountCurrency, "Symbol");
    Items.RCCurrency.Title = _DemoGeneralFunctionsCached.DefaultCurrencySymbol(); 
	
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
		
	If Object.DontCreate Then
		Cancel = True;
		Return;
	EndIf;
	
	If NOT Object.ParentDocument = Undefined Then
		Items.LineItems.ReadOnly = True;
	EndIf;
	
	If Object.BankAccount.IsEmpty() Then
		Object.BankAccount = Constants.BankAccount.Get();
		AccountCurrency = CommonUse.GetAttributeValue(Object.BankAccount, "Currency");
		Object.ExchangeRate = _DemoGeneralFunctions.GetExchangeRate(Object.Date, AccountCurrency);
	Else
	EndIf; 
	
	If Object.Ref.IsEmpty() Then
		Object.Number = _DemoGeneralFunctions.NextCheckNumber(Object.BankAccount);
	EndIf;
	
	Items.BankAccountLabel.Title =
		CommonUse.GetAttributeValue(Object.BankAccount, "Description");
		
	AccountCurrency = CommonUse.GetAttributeValue(Object.BankAccount, "Currency");
	Items.ExchangeRate.Title = _DemoGeneralFunctionsCached.DefaultCurrencySymbol() + "/1" + CommonUse.GetAttributeValue(AccountCurrency, "Symbol");

	Items.FCYCurrency.Title = CommonUse.GetAttributeValue(AccountCurrency, "Symbol");
    Items.RCCurrency.Title = _DemoGeneralFunctionsCached.DefaultCurrencySymbol();
	
	If NOT _DemoGeneralFunctionsCached.FunctionalOptionValue("MultiCurrency") Then
		Items.FCYGroup.Visible = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure LineItemsAmountOnChange(Item)
	
	Object.DocumentTotal = Object.LineItems.Total("Amount");
	Object.DocumentTotalRC = Object.LineItems.Total("Amount") * Object.ExchangeRate;
	
EndProcedure

&AtClient
Procedure LineItemsAfterDeleteRow(Item)
	
	Object.DocumentTotal = Object.LineItems.Total("Amount");
	Object.DocumentTotalRC = Object.LineItems.Total("Amount") * Object.ExchangeRate;
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	NoOfRows = Object.LineItems.Count();
	
	If NoOfRows = 0 AND Object.ParentDocument = Undefined Then
		
		Cancel = True;
		Message = New UserMessage();
		Message.Text=NStr("en='Enter at least one account and amount in the line items'");
		Message.Field = "Object.LineItems";
		Message.Message();

	EndIf;
	
	If Object.DocumentTotal < 0 Then
		Cancel = True;
		Message = New UserMessage();
		Message.Text=NStr("en='Check amount needs to be greater or equal to zero'");
		Message.Message();
		Return;
	EndIf;
	
EndProcedure

&AtClient
Procedure LineItemsAccountOnChange(Item)
	
	TabularPartRow = Items.LineItems.CurrentData;
	TabularPartRow.AccountDescription = CommonUse.GetAttributeValue
		(TabularPartRow.Account, "Description");

EndProcedure

&AtClient
Procedure DateOnChange(Item)
	
	AccountCurrency = CommonUse.GetAttributeValue(Object.BankAccount, "Currency");
    Object.ExchangeRate = _DemoGeneralFunctions.GetExchangeRate(Object.Date, AccountCurrency);

EndProcedure

&AtClient
Procedure CounterpartyOnChange(Item)
	
	Object.CounterpartyCode = CommonUse.GetAttributeValue(Object.Counterparty, "Code");
	
EndProcedure
