&AtServer
// Check presence of non-closed orders for the passed counterparty
Function HasNonClosedOrders(Counterparty)
	
	// Create new query
	Query = New Query;
	Query.SetParameter("Counterparty", Counterparty);
	
	QueryText = 
		"SELECT
		|	SalesOrder.Ref
		|FROM
		|	Document.SalesOrder AS SalesOrder
		|	LEFT JOIN InformationRegister.OrdersStatuses.SliceLast AS OrdersStatuses
		|		ON SalesOrder.Ref = OrdersStatuses.Order
		|WHERE
		|	SalesOrder.Counterparty = &Counterparty
		|AND
		|	CASE
		|		WHEN SalesOrder.DeletionMark THEN
		|			 VALUE(Enum.OrderStatuses.Deleted)
		|		WHEN NOT SalesOrder.Posted THEN
		|			 VALUE(Enum.OrderStatuses.Draft)
		|		WHEN OrdersStatuses.Status IS NULL THEN
		|			 VALUE(Enum.OrderStatuses.Open)
		|		WHEN OrdersStatuses.Status = VALUE(Enum.OrderStatuses.EmptyRef) THEN
		|			 VALUE(Enum.OrderStatuses.Open)
		|		ELSE
		|			 OrdersStatuses.Status
		|	END IN (VALUE(Enum.OrderStatuses.Open), VALUE(Enum.OrderStatuses.Backordered))";
	Query.Text  = QueryText;
	
	// Returns true if there are open or backordered orders
	Return Not Query.Execute().IsEmpty();
	
EndFunction

&AtServer
// Returns array of Order Statuses indicating non-closed orders
Function GetNonClosedOrderStatuses()
	
	// Define all non-closed statuses array
	OrderStatuses  = New Array;
	OrderStatuses.Add(Enums.OrderStatuses.Open);
	OrderStatuses.Add(Enums.OrderStatuses.Backordered);
	
	// Return filled array
	Return OrderStatuses;
	
EndFunction

&AtServer
// Fills document on the base of passed array of orders
// Returns flag o successfull filing
Function FillDocumentWithSelectedOrders(SelectedOrders)
	
	// Fill table on the base of selected orders
	If SelectedOrders <> Undefined Then
		
		// Fill object by orders
		DocObject = FormAttributeToValue("Object");
		DocObject.Fill(SelectedOrders);
		
		// Return filled object to form
		ValueToFormAttribute(DocObject, "Object");
		
		// Return filling success
		Return True;
	Else
		// Order wasn't selected: Clear foreign orders
		If  (Object.LineItems.Count() > 0)
			// Will assume that all previosly selected orders are filled correctly, and belong to the same counterparty
		And (Not Object.LineItems[0].Order.Counterparty = Object.Counterparty) Then
			// Clear existing dataset
			Object.LineItems.Clear();
		EndIf;
		
		// Return fail (selection cancelled)
		Return False;
	EndIf;
	
EndFunction

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
	TabularPartRow.TaxableAmount = 0;
	TabularPartRow.Price = 0;
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
	Object.ShipTo = _DemoGeneralFunctions.GetShipToAddress(Object.Counterparty);
	Object.ARAccount = CommonUse.GetAttributeValue(Object.Currency, "DefaultARAccount");
	Object.ExchangeRate = _DemoGeneralFunctions.GetExchangeRate(Object.Date, Object.Currency);
	Object.Terms = CommonUse.GetAttributeValue(Object.Counterparty, "Terms"); 
	Items.ExchangeRate.Title = _DemoGeneralFunctionsCached.DefaultCurrencySymbol() + "/1" + CommonUse.GetAttributeValue(Object.Currency, "Symbol");
	Items.FCYCurrency.Title = CommonUse.GetAttributeValue(Object.Currency, "Symbol");
	DuePeriod = CommonUse.GetAttributeValue(Object.Terms, "Days");
	Object.DueDate = Object.Date + ?(DuePeriod <> Undefined, DuePeriod, 14) * 60*60*24;
	
	// Open list of non-closed sales orders
	If (Not Object.Counterparty.IsEmpty()) And (HasNonClosedOrders(Object.Counterparty)) Then
		
		// Define form parameters
		FormParameters = New Structure();
		FormParameters.Insert("ChoiceMode", True);
		FormParameters.Insert("MultipleChoice", True);
		
		// Define list filter
		FltrParameters = New Structure();
		FltrParameters.Insert("Counterparty", Object.Counterparty); 
		FltrParameters.Insert("OrderStatus", GetNonClosedOrderStatuses());
		FormParameters.Insert("Filter", FltrParameters);
		
		// Open choice form
		SelectOrdersForm = GetForm("Document.SalesOrder.ChoiceForm", FormParameters, Item);
		SelectedOrders   = SelectOrdersForm.DoModal();
		
		// Execute orders filling
		FillDocumentWithSelectedOrders(SelectedOrders);
		
	EndIf;
	
	// Recalc totals
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
	
	If NOT Object.Terms.IsEmpty() Then
		Object.DueDate = Object.Date + CommonUse.GetAttributeValue(Object.Terms, "Days") * 60*60*24;
	EndIf;
	
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
// TermsOnChange UI event handler.
// Determines number of days in the payment term, and calculates a due date as
// a multiplication of a number of days (e.g. 30 for "Net 30") by the number of seconds
// in a day, since
// the system treats numbers as seconds when adding to a date.
// 
Procedure TermsOnChange(Item)
		
	Object.DueDate = Object.Date + CommonUse.GetAttributeValue(Object.Terms, "Days") * 60*60*24;
	
EndProcedure

&AtClient
// DueDateOnChange UI event handler.
// Clears the selected payment term when a user inputs a custom due date.
//
Procedure DueDateOnChange(Item)
	
	Object.Terms = NULL;
	
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
// Procedure fills in default values, used mostly when the corresponding functional
// options are turned off.
// The following defaults are filled in - warehouse location, currency, due date, payment term, and
// due date based on a default payment term.
// 
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Cancel opening form if filling on the base was failed
	If Object.Ref.IsEmpty() And Parameters.Basis <> Undefined
	And Object.Counterparty <> Parameters.Basis.Counterparty Then
		// Object is not filled as expected
		Cancel = True;
		Return;
	EndIf;
	
	// Initialization of LineItems_OnCloneRow variable
	LineItems_OnCloneRow = False;
	
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
			
	//If _DemoGeneralFunctionsCached.FunctionalOptionValue("MultiLocation") Then
	//Else
		If Object.Location.IsEmpty() Then			
			Object.Location = Catalogs.Locations.MainWarehouse;
		EndIf;
	//EndIf;

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

&AtClient
Procedure LineItemsBeforeAddRow(Item, Cancel, Clone, Parent, Folder)
	
	// Set Clone Row flag
	If Clone And Not Cancel Then
		LineItems_OnCloneRow = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure LineItemsOnChange(Item)
	
	// Row previously was cloned from another and became edited
	If LineItems_OnCloneRow Then
		// Clear used flag
		LineItems_OnCloneRow = False;
		
		// Clear Order on duplicate row
        CurrentData = Item.CurrentData;
		CurrentData.Order = Undefined;
	EndIf;
		
EndProcedure
