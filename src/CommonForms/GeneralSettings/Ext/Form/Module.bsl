&AtClient
Var RestartRequired;

&AtClient
Procedure MultiLocationOnChange(Item)
	RestartRequired = True;
	RefreshInterface();
EndProcedure

&AtClient
Procedure MultiCurrencyOnChange(Item)
	RestartRequired = True;
	RefreshInterface();
EndProcedure

&AtClient
Procedure USFiscalLocalizationOnChange(Item)
	RestartRequired = True;
	RefreshInterface();
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
		
	Items.BankAccountLabel.Title =
		CommonUse.GetAttributeValue(Constants.BankAccount.Get(), "Description");
	Items.ExchangeGainLabel.Title =
		CommonUse.GetAttributeValue(Constants.ExchangeGain.Get(), "Description");
	Items.ExchangeLossLabel.Title =
		CommonUse.GetAttributeValue(Constants.ExchangeLoss.Get(), "Description");
	Items.UndepositedFundsAccountLabel.Title =
		CommonUse.GetAttributeValue(Constants.UndepositedFundsAccount.Get(), "Description");
	Items.BankInterestEarnedAccountLabel.Title =
		CommonUse.GetAttributeValue(Constants.BankInterestEarnedAccount.Get(), "Description");
	Items.BankServiceChargeAccountLabel.Title =
		CommonUse.GetAttributeValue(Constants.BankServiceChargeAccount.Get(), "Description");
				
EndProcedure

&AtClient
Procedure BankAccountOnChange(Item)
	Items.BankAccountLabel.Title = _DemoGeneralFunctions.AccountName(Items.BankAccount.SelectedText);
EndProcedure

&AtClient
Procedure IncomeAccountOnChange(Item)
	Items.IncomeAccountLabel.Title = _DemoGeneralFunctions.AccountName(Items.IncomeAccount.SelectedText);
EndProcedure

&AtClient
Procedure COGSAccountOnChange(Item)
	Items.COGSAccountLabel.Title = _DemoGeneralFunctions.AccountName(Items.COGSAccount.SelectedText);
EndProcedure

&AtClient
Procedure ExpenseAccountOnChange(Item)
	Items.ExpenseAccountLabel.Title = _DemoGeneralFunctions.AccountName(Items.ExpenseAccount.SelectedText);
EndProcedure

&AtClient
Procedure InventoryAccountOnChange(Item)
	Items.InventoryAccountLabel.Title =
		_DemoGeneralFunctions.AccountName(Items.InventoryAccount.SelectedText);
EndProcedure

&AtClient
Procedure ExchangeGainOnChange(Item)
	Items.ExchangeGainLabel.Title = _DemoGeneralFunctions.AccountName(Items.ExchangeGain.SelectedText);
EndProcedure

&AtClient
Procedure ExchangeLossOnChange(Item)
	Items.ExchangeLossLabel.Title = _DemoGeneralFunctions.AccountName(Items.ExchangeLoss.SelectedText);
EndProcedure

&AtClient
Procedure TaxPayableAccountOnChange(Item)
	Items.TaxPayableAccountLabel.Title =
		_DemoGeneralFunctions.AccountName(Items.TaxPayableAccount.SelectedText);
EndProcedure

&AtClient
Procedure UndepositedFundsAccountOnChange(Item)
	Items.UndepositedFundsAccountLabel.Title =
		_DemoGeneralFunctions.AccountName(Items.UndepositedFundsAccount.SelectedText);
EndProcedure

&AtClient
Procedure BankInterestEarnedAccountOnChange(Item)
	Items.BankInterestEarnedAccountLabel.Title =
		_DemoGeneralFunctions.AccountName(Items.BankInterestEarnedAccount.SelectedText);
EndProcedure

&AtClient
Procedure BankServiceChargeAccountOnChange(Item)
	Items.BankServiceChargeAccountLabel.Title =
		_DemoGeneralFunctions.AccountName(Items.BankServiceChargeAccount.SelectedText);
EndProcedure

&AtClient
Procedure DefaultCurrencyOnChange(Item)
	RestartRequired = True;
EndProcedure

&AtClient
Procedure VATFiscalLocalizationOnChange(Item)
	
	RestartRequired = True;
	RefreshInterface();

EndProcedure

&AtClient
Procedure VendorNameOnChange(Item)
	
	RestartRequired = True;
	
EndProcedure

&AtClient
Procedure CustomerNameOnChange(Item)
	
	RestartRequired = True;
	
EndProcedure

&AtClient
Procedure EmailClientOnChange(Item)
	
	RestartRequired = True;
	RefreshInterface();

EndProcedure

&AtClient
Procedure PriceIncludesVATOnChange(Item)
	
	RestartRequired = True;
	RefreshInterface();

EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	If RestartRequired = True Then
		ShowMessageBox(, NStr("en = 'Restart the application for the settings to take effect.'"));
		RestartRequired = False;
	EndIf;
EndProcedure

&AtClient
Procedure UseDataExchangeOnChange(Item)
		
	RestartRequired = True;

EndProcedure

&AtClient
Procedure UseDataExchangeServiceModeOnChange(Item)
		
	RestartRequired = True;

EndProcedure

&AtClient
Procedure UseDataExchangeLocalModeOnChange(Item)
		
	RestartRequired = True;

EndProcedure
