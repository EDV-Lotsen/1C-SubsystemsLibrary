&AtClient
// ItemOnChange UI event handler.
// The procedure clears quantities, line total, and taxable amount in the line item,
// selects price for the new item from the price-list, divides the price by the document
// exchange rate, selects a default unit of measure for the item, and
// selects a item's sales tax type.
// 
Procedure LineItemsItemOnChange(Item)
	
	TabularPartRow = Items.LineItems.CurrentData;
	
	TabularPartRow.ItemDescription = CommonUse.GetAttributeValue(TabularPartRow.Item, "Description");
	TabularPartRow.Quantity = 0;
	TabularPartRow.LineTotal = 0;
	TabularPartRow.Price = 0;
	TabularPartRow.TaxableAmount = 0;
	TabularPartRow.VAT = 0;
	
	Price = _DemoGeneralFunctions.RetailPrice(CurrentDate(), TabularPartRow.Item);
	TabularPartRow.Price = Price / Object.ExchangeRate;
		
	TabularPartRow.SalesTaxType = _DemoUS_FL.GetSalesTaxType(TabularPartRow.Item);
	TabularPartRow.VATCode = CommonUse.GetAttributeValue(TabularPartRow.Item, "SalesVATCode");
	
	RecalcTotal();
	
EndProcedure

&AtClient
// The procedure recalculates a document's sales tax amount
// 
Procedure RecalcSalesTax()
	
	If Object.Counterparty.IsEmpty() Then
		TaxRate = 0;
	Else
		TaxRate = _DemoUS_FL.GetTaxRate(Object.Counterparty);
	EndIf;
	
	Object.SalesTax = Object.LineItems.Total("TaxableAmount") * TaxRate/100;
	
EndProcedure

&AtClient
// The procedure recalculates the document's total.
// DocumentTotal - document's currency in FCY (foreign currency).
// DocumentTotalRC - company's reporting currency.
//
Procedure RecalcTotal()
	
	If Object.PriceIncludesVAT Then
		Object.DocumentTotal = Object.LineItems.Total("LineTotal") + Object.SalesTax;
		Object.DocumentTotalRC = (Object.LineItems.Total("LineTotal") + Object.SalesTax) * Object.ExchangeRate;		
	Else
		Object.DocumentTotal = Object.LineItems.Total("LineTotal") + Object.LineItems.Total("VAT") + Object.SalesTax;
		Object.DocumentTotalRC = (Object.LineItems.Total("LineTotal") + Object.LineItems.Total("VAT") + Object.SalesTax) * Object.ExchangeRate;
	EndIf;	
	Object.VATTotal = Object.LineItems.Total("VAT") * Object.ExchangeRate;
	
EndProcedure

&AtClient
// The procedure recalculates a taxable amount for a line item.
// 
Procedure RecalcTaxableAmount()
	
	TabularPartRow = Items.LineItems.CurrentData;
	
	If TabularPartRow.SalesTaxType = _DemoUS_FL.Taxable() Then
		TabularPartRow.TaxableAmount = TabularPartRow.LineTotal;
	Else
		TabularPartRow.TaxableAmount = 0;
	EndIf;
	
EndProcedure

&AtClient
// CustomerOnChange UI event handler.
// Selects default currency for the customer, determines an exchange rate, and
// recalculates the document's sales tax and total amounts.
//  
Procedure CounterpartyOnChange(Item)
	
	Object.CounterpartyCode = CommonUse.GetAttributeValue(Object.Counterparty, "Code");
	Object.Currency = CommonUse.GetAttributeValue(Object.Counterparty, "DefaultCurrency");
	Object.ARAccount = CommonUse.GetAttributeValue(Object.Currency, "DefaultARAccount");
	Object.ExchangeRate = _DemoGeneralFunctions.GetExchangeRate(Object.Date, Object.Currency);
	Items.ExchangeRate.Title = _DemoGeneralFunctionsCached.DefaultCurrencySymbol() + "/1" + CommonUse.GetAttributeValue(Object.Currency, "Symbol");
	Items.FCYCurrency.Title = CommonUse.GetAttributeValue(Object.Currency, "Symbol");
	RecalcSalesTax();
	RecalcTotal();
	
EndProcedure

&AtClient
// PriceOnChange UI event handler.
// Calculates line total by multiplying a price by a quantity in either the selected
// unit of measure (U/M) or in the base U/M, and recalculates the line's taxable amount and total.
//  
Procedure LineItemsPriceOnChange(Item)
	
	TabularPartRow = Items.LineItems.CurrentData;
	
	TabularPartRow.LineTotal = TabularPartRow.Quantity * TabularPartRow.Price;
	
	TabularPartRow.VAT = _DemoVAT_FL.VATLine(TabularPartRow.LineTotal, TabularPartRow.VATCode, "Sales", Object.PriceIncludesVAT);
	
	RecalcTaxableAmount();
	RecalcSalesTax();
	RecalcTotal();

EndProcedure

&AtClient
// DateOnChange UI event handler.
// Determines an exchange rate on the new date, and recalculates the document's
// sales tax and total.
//
Procedure DateOnChange(Item)
	
	Object.ExchangeRate = _DemoGeneralFunctions.GetExchangeRate(Object.Date, Object.Currency);
	RecalcSalesTax();
	RecalcTotal();
	
EndProcedure

&AtClient
// CurrencyOnChange UI event handler.
// Determines an exchange rate for the new currency, and recalculates the document's
// sales tax and total.
//
Procedure CurrencyOnChange(Item)
	
	Object.ExchangeRate = _DemoGeneralFunctions.GetExchangeRate(Object.Date, Object.Currency);
	Object.ARAccount = CommonUse.GetAttributeValue(Object.Currency, "DefaultARAccount");
	Items.ExchangeRate.Title = _DemoGeneralFunctionsCached.DefaultCurrencySymbol() + "/1" + CommonUse.GetAttributeValue(Object.Currency, "Symbol");
	Items.FCYCurrency.Title = CommonUse.GetAttributeValue(Object.Currency, "Symbol");
	RecalcSalesTax();
	RecalcTotal();
	
EndProcedure

&AtClient
// LineItemsAfterDeleteRow UI event handler.
// 
Procedure LineItemsAfterDeleteRow(Item)
	
	RecalcSalesTax();
	RecalcTotal();
	
EndProcedure

&AtClient
// LineItemsSalesTaxTypeOnChange UI event handler.
//
Procedure LineItemsSalesTaxTypeOnChange(Item)
	
	RecalcTaxableAmount();
	RecalcSalesTax();
	RecalcTotal();
	
EndProcedure

&AtClient
// LineItemsQuantityOnChange UI event handler.
// This procedure is used when the units of measure (U/M) functional option is turned off
// and base quantities are used instead of U/M quantities.
// The procedure recalculates line total, line taxable amount, and a document's sales tax and total.
//  
Procedure LineItemsQuantityOnChange(Item)
	
	TabularPartRow = Items.LineItems.CurrentData;
	TabularPartRow.LineTotal = TabularPartRow.Quantity * TabularPartRow.Price;
	TabularPartRow.VAT = _DemoVAT_FL.VATLine(TabularPartRow.LineTotal, TabularPartRow.VATCode, "Sales", Object.PriceIncludesVAT);
	
	RecalcTaxableAmount();
	RecalcSalesTax();
	RecalcTotal();

EndProcedure

&AtServer
// Procedure fills in default values, used mostly when the corresponding functional options are
// turned off.
// The following defaults are filled in - warehouse location, and currency.
// 
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Items.Counterparty.Title = _DemoGeneralFunctionsCached.GetCustomerName();
	
	If Object.Ref.IsEmpty() Then
    	Object.PriceIncludesVAT = _DemoGeneralFunctionsCached.PriceIncludesVAT();
	EndIf;

	If NOT _DemoGeneralFunctionsCached.FunctionalOptionValue("USFiscalLocalization") Then
		Items.SalesTaxGroup.Visible = False;
	EndIf;
	
	If NOT _DemoGeneralFunctionsCached.FunctionalOptionValue("VATFiscalLocalization") Then
		Items.VATGroup.Visible = False;
	EndIf;
	
	If NOT _DemoGeneralFunctionsCached.FunctionalOptionValue("MultiCurrency") Then
		Items.FCYGroup.Visible = False;
	EndIf;
		
	If Object.Location.IsEmpty() Then
		Object.Location = Catalogs.Locations.MainWarehouse;
	EndIf;

	If Object.Currency.IsEmpty() Then
		Object.Currency = Constants.DefaultCurrency.Get();
		Object.ARAccount = Object.Currency.DefaultARAccount;
		Object.ExchangeRate = 1;	
	Else
	EndIf; 
	
	Items.ExchangeRate.Title = _DemoGeneralFunctionsCached.DefaultCurrencySymbol() + "/1" + Object.Currency.Symbol;
	Items.VATCurrency.Title = _DemoGeneralFunctionsCached.DefaultCurrencySymbol();
	Items.RCCurrency.Title = _DemoGeneralFunctionsCached.DefaultCurrencySymbol();
	Items.SalesTaxCurrency.Title = _DemoGeneralFunctionsCached.DefaultCurrencySymbol();
	Items.FCYCurrency.Title = CommonUse.GetAttributeValue(Object.Currency, "Symbol");
	
EndProcedure

&AtClient
// Calculates a VAT amount for the document line
//
Procedure LineItemsVATCodeOnChange(Item)
	
	TabularPartRow = Items.LineItems.CurrentData;
	TabularPartRow.VAT = _DemoVAT_FL.VATLine(TabularPartRow.LineTotal, TabularPartRow.VATCode, "Sales", Object.PriceIncludesVAT);
    RecalcTotal();

EndProcedure
