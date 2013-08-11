&AtServer
// Request order status from database
Procedure FillOrderStatuses()
	
	// Request order status
	If Not ValueIsFilled(Object.Ref) Then
		// New order has open status
		OrderStatus = Enums.OrderStatuses.Open;
		
	Else
		// Create new query
		Query = New Query;
		Query.SetParameter("Ref", Object.Ref);
		
		Query.Text = 
			"SELECT TOP 1
			|	OrdersStatuses.Status
			|FROM
			|	InformationRegister.OrdersStatuses AS OrdersStatuses
			|WHERE
			|	Order = &Ref
			|ORDER BY
			|	OrdersStatuses.Status.Order Desc";
		Selection = Query.Execute().Choose();
		
		// Fill order status
		If Selection.Next() Then
			OrderStatus = Selection.Status;
		Else
			OrderStatus = Enums.OrderStatuses.Open;
		EndIf;
	EndIf;
	OrderStatusIndex = Enums.OrderStatuses.IndexOf(OrderStatus);
	
	// Build order status presentation (depending of document state)
	If Not ValueIsFilled(Object.Ref) Then
		OrderStatusPresentation = String(Enums.OrderStatuses.New);
		Items.OrderStatusPresentation.TextColor = WebColors.DarkGreen;
	ElsIf Object.DeletionMark Then
		OrderStatusPresentation = String(Enums.OrderStatuses.Deleted);
		Items.OrderStatusPresentation.TextColor = WebColors.DarkGray;
	ElsIf Not Object.Posted Then 
		OrderStatusPresentation = String(Enums.OrderStatuses.Draft);
		Items.OrderStatusPresentation.TextColor = WebColors.DarkGray;
	Else
		OrderStatusPresentation = String(OrderStatus);
		If OrderStatus = Enums.OrderStatuses.Open Then 
			ThisForm.Items.OrderStatusPresentation.TextColor = WebColors.DarkGreen;
		ElsIf OrderStatus = Enums.OrderStatuses.Backordered Then 
			ThisForm.Items.OrderStatusPresentation.TextColor = WebColors.DarkGoldenRod;
		ElsIf OrderStatus = Enums.OrderStatuses.Closed Then
			ThisForm.Items.OrderStatusPresentation.TextColor = WebColors.DarkRed;
		Else
			ThisForm.Items.OrderStatusPresentation.TextColor = WebColors.DarkGray;
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
// Request demanded order items from database
Procedure FillOrdersRegistered()
	
	// Request ordered items quantities
	If ValueIsFilled(Object.Ref) Then
		
		// Create new query
		Query = New Query;
		Query.SetParameter("Ref", Object.Ref);
		Query.SetParameter("OrderStatus", OrderStatus);
		
		Query.Text = 
			"SELECT
			|	OrdersRegistered.LineNumber              AS LineNumber,
			|	OrdersRegisteredBalance.Item          AS Item,                                                            // ---------------------------------------
			|	OrdersRegisteredBalance.QuantityBalance  AS Quantity,                                                           // Backorder quantity calculation
			|	CASE                                                                                                            // ---------------------------------------
			|		WHEN &OrderStatus = VALUE(Enum.OrderStatuses.Open)        THEN 0                                            // Order status = Open:
			|		WHEN &OrderStatus = VALUE(Enum.OrderStatuses.Backordered) THEN                                              //   Backorder = 0
			|			CASE                                                                                                    // Order status = Backorder:
			|				WHEN OrdersRegisteredBalance.Item.Type = VALUE(Enum.InventoryTypes.Inventory) THEN               //   Inventory:
			|					CASE                                                                                            //     Backorder = Ordered - Shipped >= 0
			|						WHEN OrdersRegisteredBalance.QuantityBalance > OrdersRegisteredBalance.ShippedBalance THEN  //     |
			|							 OrdersRegisteredBalance.QuantityBalance - OrdersRegisteredBalance.ShippedBalance       //     |
			|						ELSE 0 END                                                                                  //     |
			|				ELSE                                                                                                //   Non-inventory:
			|					CASE                                                                                            //     Backorder = Ordered - Invoiced >= 0
			|						WHEN OrdersRegisteredBalance.QuantityBalance > OrdersRegisteredBalance.InvoicedBalance THEN //     |
			|							 OrdersRegisteredBalance.QuantityBalance - OrdersRegisteredBalance.InvoicedBalance      //     |
			|						ELSE 0 END                                                                                  //     |
			|				END                                                                                                 //     |
			|		WHEN &OrderStatus = VALUE(Enum.OrderStatuses.Closed)      THEN 0                                            // Order status = Closed:
			|		END AS Backorder,                                                                                           //   Backorder = 0
			|	OrdersRegisteredBalance.ShippedBalance   AS Shipped,
			|	OrdersRegisteredBalance.InvoicedBalance  AS Invoiced
			|FROM
			|	AccumulationRegister.OrdersRegistered.Balance(,
			|		(Counterparty, Order, Item) IN
			|			(SELECT
			|				LineItems.Ref.Counterparty,
			|				LineItems.Ref,
			|				LineItems.Item
			|			FROM
			|				Document.SalesOrder.LineItems AS LineItems
			|			WHERE
			|				LineItems.Ref = &Ref)) AS OrdersRegisteredBalance
			|	LEFT JOIN AccumulationRegister.OrdersRegistered AS OrdersRegistered
			|		ON    ( OrdersRegistered.Recorder = &Ref
			|			AND OrdersRegistered.Counterparty	= OrdersRegisteredBalance.Counterparty
			|			AND OrdersRegistered.Order			= OrdersRegisteredBalance.Order
			|			AND OrdersRegistered.Item		= OrdersRegisteredBalance.Item
			|			AND OrdersRegistered.Quantity		= OrdersRegisteredBalance.QuantityBalance)
			|ORDER BY
			|	OrdersRegistered.LineNumber";
		Selection = Query.Execute().Choose();
		
		// Fill ordered items quantities
		SearchRec = New Structure("LineNumber, Item, Quantity");
		While Selection.Next() Do
			
			// Search for appropriate line in tabular section of order
			FillPropertyValues(SearchRec, Selection);
			FoundLineItems = Object.LineItems.FindRows(SearchRec);
			
			// Fill quantities in tabular section
			If FoundLineItems.Count() > 0 Then
				FillPropertyValues(FoundLineItems[0], Selection, "Backorder, Shipped, Invoiced");
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure

&AtServer
// Request and fill indexes of item type (required to calculate bacorder property)
Procedure FillItemTypes()
	
	// Fill line item's item types
	If ValueIsFilled(Object.Ref) Then
		
		// Create new query
		Query = New Query;
		Query.SetParameter("Ref", Object.Ref);
		
		Query.Text =
		"SELECT
		|	SalesOrderLineItems.LineNumber         AS LineNumber,
		|	SalesOrderLineItems.Item.Type.Order AS ItemTypeIndex
		|FROM
		|	Document.SalesOrder.LineItems AS SalesOrderLineItems
		|WHERE
		|	SalesOrderLineItems.Ref = &Ref
		|ORDER BY
		|	LineNumber";
		Selection = Query.Execute().Choose();
		
		// Fill ordered items quantities
		While Selection.Next() Do
			
			// Search for appropriate line in tabular section of order
			LineItem = Object.LineItems.Get(Selection.LineNumber-1);
			If LineItem <> Undefined Then
				LineItem.ItemTypeIndex = Selection.ItemTypeIndex;
			EndIf;
		EndDo;
		
	EndIf;
EndProcedure

&AtClient
// ItemOnChange UI event handler.
// The procedure clears quantities, line total, and taxable amount in the line item,
// selects price for the new item from the price-list, divides the price by the document
// exchange rate, selects a default unit of measure for the item, and
// selects a item's sales tax type.
// 
Procedure LineItemsItemOnChange(Item)
	
	TabularPartRow = Items.LineItems.CurrentData;
	
	ItemProperties = CommonUse.GetAttributeValues(TabularPartRow.Item, "Description, Type.Order, SalesVATCode");
	TabularPartRow.ItemDescription = ItemProperties.Description;
	TabularPartRow.ItemTypeIndex   = ItemProperties.TypeOrder;
	
	TabularPartRow.Quantity = 0;
	TabularPartRow.Backorder = 0;
	TabularPartRow.Shipped = 0;
	TabularPartRow.Invoiced = 0;
	TabularPartRow.LineTotal = 0;
	TabularPartRow.TaxableAmount = 0;
	TabularPartRow.Price = 0;
    TabularPartRow.VAT = 0;
	
	Price = _DemoGeneralFunctions.RetailPrice(CurrentDate(), TabularPartRow.Item);
	TabularPartRow.Price = Price / Object.ExchangeRate;

	TabularPartRow.SalesTaxType = _DemoUS_FL.GetSalesTaxType(TabularPartRow.Item);	
	
	TabularPartRow.VATCode = ItemProperties.SalesVATCode;
	
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
	Object.ShipTo = _DemoGeneralFunctions.GetShipToAddress(Object.Counterparty);
	Object.Currency = CommonUse.GetAttributeValue(Object.Counterparty, "DefaultCurrency");
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
// LineitemsSalesTaxTypeOnChange UI event handler.
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
	
	// Request current string
	TabularPartRow = Items.LineItems.CurrentData;
	
	// Calculate sum and taxes by line
	TabularPartRow.LineTotal = TabularPartRow.Quantity * TabularPartRow.Price;
	TabularPartRow.VAT = _DemoVAT_FL.VATLine(TabularPartRow.LineTotal, TabularPartRow.VATCode, "Sales", Object.PriceIncludesVAT);
	
	// Update backorder quantity based on document status
	If    OrderStatusIndex = 0 Then // OrderStatus = Enums.OrderStatuses.Open
		TabularPartRow.Backorder = 0;
	ElsIf OrderStatusIndex = 1 Then // OrderStatus = Enums.OrderStatuses.Backordered
		If TabularPartRow.ItemTypeIndex = 0 Then // Item.Type = Enums.InventoryTypes.Inventory
			TabularPartRow.Backorder = Max(TabularPartRow.Quantity - TabularPartRow.Shipped, 0);
		Else 
			TabularPartRow.Backorder = Max(TabularPartRow.Quantity - TabularPartRow.Invoiced, 0);
		EndIf;
	ElsIf OrderStatusIndex = 2 Then // OrderStatus = Enums.OrderStatuses.Closed
		TabularPartRow.Backorder = 0;
	Else
		TabularPartRow.Backorder = 0;
	EndIf;
	
	// Calculate totals
	RecalcTaxableAmount();
	RecalcSalesTax();
	RecalcTotal();

EndProcedure

&AtServer
// Procedure fills in default values, used mostly when the corresponding functional
// options are turned off.
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
		Object.ExchangeRate = 1;	
	Else
	EndIf; 
	
	Items.ExchangeRate.Title = _DemoGeneralFunctionsCached.DefaultCurrencySymbol() + "/1" + Object.Currency.Symbol;
	Items.VATCurrency.Title = _DemoGeneralFunctionsCached.DefaultCurrencySymbol();
	Items.RCCurrency.Title = _DemoGeneralFunctionsCached.DefaultCurrencySymbol();
	Items.FCYCurrency.Title = CommonUse.GetAttributeValue(Object.Currency, "Symbol");

	// Request and fill order status
	FillOrderStatuses();

	// Request and fill ordered items from database
	FillOrdersRegistered();
	
	// Request and fill indexes of item type (required to calculate bacorder property)
	FillItemTypes();
	
EndProcedure

&AtClient
// Calculates a VAT amount for the document line
//
Procedure LineItemsVATCodeOnChange(Item)
	
	TabularPartRow = Items.LineItems.CurrentData;
	TabularPartRow.VAT = _DemoVAT_FL.VATLine(TabularPartRow.LineTotal, TabularPartRow.VATCode, "Sales", Object.PriceIncludesVAT);
    RecalcTotal();

EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	// Request and fill order status from database
	FillOrderStatuses();
	
	// Request and fill ordered items from database
	FillOrdersRegistered();
	
	// Request and fill indexes of item type (required to calculate bacorder property)
	FillItemTypes();
		
EndProcedure
