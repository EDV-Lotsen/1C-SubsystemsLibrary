﻿
&AtServer
// Prefills default accounts, VAT codes, determines accounts descriptions, and sets field visibility
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Object.Ref <> Catalogs.Items.EmptyRef() Then
		Query = New Query("SELECT
						  |	PriceListSliceLast.Price
						  |FROM
						  |	InformationRegister.PriceList.SliceLast AS PriceListSliceLast
						  |WHERE
						  |	PriceListSliceLast.Item = &Ref");
		Query.SetParameter("Ref", Object.Ref);
		Selection = Query.Execute();
		
		If Selection.IsEmpty() Then
		Else
			Dataset = Selection.Unload();
			Price = Dataset[0][0];
		EndIf;

		
	EndIf;
		
	If Object.Type <> Enums.InventoryTypes.Inventory Then
		Items.CostingMethod.ReadOnly = True;
	EndIf;
	
	If Object.IncomeAccount.IsEmpty() AND Object.Ref.IsEmpty() Then
		IncomeAcct = Constants.IncomeAccount.Get();
		Object.IncomeAccount = IncomeAcct;
		Items.IncomeAcctLabel.Title = IncomeAcct.Description;
	ElsIf NOT Object.Ref.IsEmpty() Then
		Items.IncomeAcctLabel.Title = Object.IncomeAccount.Description;
	EndIf;
	
	If Object.COGSAccount.IsEmpty() AND Object.Ref.IsEmpty() Then
		COGSAcct = Constants.COGSAccount.Get();
		Object.COGSAccount = COGSAcct;
		Items.COGSAcctLabel.Title = COGSAcct.Description;
	ElsIf NOT Object.Ref.IsEmpty() Then
		Items.COGSAcctLabel.Title = Object.COGSAccount.Description;
	EndIf;
	
	If NOT Object.InventoryOrExpenseAccount.IsEmpty() Then
		Items.InventoryAcctLabel.Title = Object.InventoryOrExpenseAccount.Description;
	EndIf;
	
	If Object.Type <> Enums.InventoryTypes.Inventory Then
		//Items.COGSAccount.ReadOnly = True;
	EndIf;
	
	If Object.PurchaseVATCode.IsEmpty() AND Object.Ref.IsEmpty() Then
		Object.PurchaseVATCode = Constants.DefaultPurchaseVAT.Get();
	EndIf;
	
	If Object.SalesVATCode.IsEmpty() AND Object.Ref.IsEmpty() Then
		Object.SalesVATCode = Constants.DefaultSalesVAT.Get();
	EndIf;
	
	// Display indicators
	If ValueIsFilled(Object.Ref) Then
		
		// Fill last item cost
		If  (Object.Type = Enums.InventoryTypes.Inventory) Then
			// Fill item cost values
			FillLastAverageAccountingCost();
		EndIf;
		
		// Fill item quantities
		FillItemQuantity_OnPO_OnSO_OnHand_AvailableToPromise();
		
		// Update visibility
		ChildItems.Indicators.Visible = True;
		IsInventoryType = (Object.Type = Enums.InventoryTypes.Inventory);
		ChildItems.Indicators.ChildItems.Left.Visible = IsInventoryType;
		ChildItems.Indicators.ChildItems.Right.ChildItems.QtyOnHand.Visible = IsInventoryType;
		ChildItems.Indicators.ChildItems.Right.ChildItems.QtyAvailableToPromise.Visible = IsInventoryType;
	Else
		// New item: hide indicators
		ChildItems.Indicators.Visible = False;
	EndIf;
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	// when the first item is created change the 15 character code to 5
	// user can then go back and change it to anything they want
	
	//Query = New Query("SELECT
	//				  |	COUNT(Items.Ref) AS Ref
	//				  |FROM
	//				  |	Catalog.Items AS Items");
	//Selection = Query.Execute().Unload();
	//NumOfItems = Selection[0][0];
	//
	//If NumOfItems = 1 Then
	//	
	//	Try
	//		
	//		Item1 = Catalogs.Items.FindByCode("000000000000001");
	//		If Item1.Change15to5 = False Then
	//			Item1Obj = Item1.GetObject();
	//			Item1Obj.Code = "00001";
	//			Item1Obj.Change15to5 = True;
	//			Item1Obj.Write();
	//		EndIf;
	//	Except
	//	EndTry;
	//EndIf;

	///
	
	If  (Object.Type = Enums.InventoryTypes.Inventory) Then
		// Fill item cost values
		FillLastAverageAccountingCost();
	EndIf;
	
	// Fill item quantities
	FillItemQuantity_OnPO_OnSO_OnHand_AvailableToPromise();
	
	// Update visibility
	ChildItems.Indicators.Visible = True;
	IsInventoryType = (Object.Type = Enums.InventoryTypes.Inventory);
	ChildItems.Indicators.ChildItems.Left.Visible = IsInventoryType;
	ChildItems.Indicators.ChildItems.Right.ChildItems.QtyOnHand.Visible = IsInventoryType;
	ChildItems.Indicators.ChildItems.Right.ChildItems.QtyAvailableToPromise.Visible = IsInventoryType;
	
EndProcedure

&AtServer
Procedure FillLastAverageAccountingCost()
	
	// Default values for new item (or item without lots - no goods recepts / purchase invoices occured)
	LastCost = 0;
	AverageCost = 0;
	AccountingCost = 0;
		
	// Check object is new
	If ValueIsFilled(Object.Ref) Then
	
		// Define query for all types of cost
		QTItemLastCost = "
			|// Last item cost from information register ItemLastCost
			|SELECT
			|	ItemLastCost.Cost AS Cost
			|INTO
			|	LastCost
			|FROM
			|	InformationRegister.ItemLastCost AS ItemLastCost
			|WHERE
			|	ItemLastCost.Item = &Ref;";
		
		QTItemAverageCost = "
			|// Average cost, based on all availble stock
			|SELECT
			|	CASE WHEN InventoryBalance.QtyBalance <= 0 THEN 0
			|		 ELSE CAST(InventoryBalance.AmountBalance / InventoryBalance.QtyBalance AS Number(15, 2)) END AS Cost
			|INTO
			|	AverageCost
			|FROM
			|	AccumulationRegister.Inventory.Balance(&Boundary, Item = &Ref) AS InventoryBalance;";
		
		QTItemAccountingFirstLastCost = "
			|// Current accounting cost => First / Last lot item cost
			|SELECT TOP 1
			|	CASE WHEN InventoryBalance.QtyBalance <= 0 THEN 0
			|		 ELSE CAST(InventoryBalance.AmountBalance / InventoryBalance.QtyBalance AS Number(15, 2)) END AS Cost,
			|	InventoryBalance.Layer AS Layer
			|INTO
			|	AccountingCost
			|FROM
			|	AccumulationRegister.Inventory.Balance(&Boundary, Item = &Ref) AS InventoryBalance
			|ORDER BY
			|	InventoryBalance.Layer.PointInTime %1;";
		
		Query = New Query(
			// Last item cost from information register ItemLastCost
			QTItemLastCost + 	// INTO LastCost.Cost
			// Average cost, based on all availble stock
			QTItemAverageCost + // INTO AverageCost.Cost
			// Current accounting cost => First / Last lot item cost for FIFO/LIFO, NONE for Average
			?(Object.CostingMethod = Enums.InventoryCostingMethods.FIFO OR Object.CostingMethod = Enums.InventoryCostingMethods.LIFO,
				StringFunctionsClientServer.SubstituteParametersInString(QTItemAccountingFirstLastCost, ?(Object.CostingMethod = Enums.InventoryCostingMethods.FIFO, "Asc", "Desc")), // FIFO = ORDER BY Layer Asc (TOP 1 Old); LIFO = ORDER BY Layer Desc (TOP 1 New);
				"") +			// INTO AccountingCost.Cost
			"
			|SELECT
			|	ISNULL(LastCost.Cost, 0) AS Cost
			|
			|UNION ALL
			|SELECT
			|	ISNULL(AverageCost.Cost, 0)" +
			?(Object.CostingMethod = Enums.InventoryCostingMethods.FIFO OR Object.CostingMethod = Enums.InventoryCostingMethods.LIFO, "
			|
			|UNION ALL
			|SELECT
			|	ISNULL(AccountingCost.Cost, 0)",""));
			
		Query.SetParameter("Boundary", New Boundary(EndOfDay(CurrentSessionDate()), BoundaryType.Including));
		Query.SetParameter("Ref", Object.Ref);
		
		// Execute query and read costs
		Selection = Query.Execute().Choose();
		// Last cost
		If Selection.Next() Then LastCost = Selection.Cost;	Else LastCost = 0; EndIf;
		// Average cost
		If Selection.Next() Then AverageCost = Selection.Cost;	Else AverageCost = 0; EndIf;
		// Accounting cost
		If (Object.CostingMethod = Enums.InventoryCostingMethods.FIFO OR Object.CostingMethod = Enums.InventoryCostingMethods.LIFO) And Selection.Next() Then
			AccountingCost = Selection.Cost;
		Else
			AccountingCost = AverageCost;
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillItemQuantity_OnPO_OnSO_OnHand_AvailableToPromise()
	
	// Default values for new item (or item without lots - no goods recepts / purchase invoices occured)
	QtyOnPO = 0;
	QtyOnSO = 0;
	QtyOnHand = 0;
	QtyAvailableToPromise = 0;
	
	// Check object is new
	If ValueIsFilled(Object.Ref) Then
		
		// Create new query
		Query = New Query;
		Query.TempTablesManager = New TempTablesManager;
		Query.SetParameter("Ref",  Object.Ref);
		Query.SetParameter("Type", Object.Type);
		
		// Empty query text and tables
		QueryText   = "";
		QueryTables = -1;
		
		// Request data from database
		QueryText = QueryText +
		"SELECT
		// ------------------------------------------------------
		// QtyOnPO = OrdersDispatched.Quantity - OrdersDispatched.Received(Invoiced) > 0 
		|	OrdersDispatchedBalance.Counterparty AS Counterparty,
		|	OrdersDispatchedBalance.Order   AS Order,
		|	OrdersDispatchedBalance.Item   	AS Item,
		|	CASE WHEN &Type = VALUE(Enum.InventoryTypes.Inventory)
		|             THEN CASE WHEN OrdersDispatchedBalance.QuantityBalance - OrdersDispatchedBalance.ReceivedBalance > 0
		|	                    THEN OrdersDispatchedBalance.QuantityBalance - OrdersDispatchedBalance.ReceivedBalance 
		|	                    ELSE 0 END
		|        WHEN &Type = VALUE(Enum.InventoryTypes.NonInventory)
		|             THEN CASE WHEN OrdersDispatchedBalance.QuantityBalance - OrdersDispatchedBalance.InvoicedBalance > 0
		|	                    THEN OrdersDispatchedBalance.QuantityBalance - OrdersDispatchedBalance.InvoicedBalance 
		|	                    ELSE 0 END
		|        ELSE 0 END                   AS QtyOnPO,
		|	0                                 AS QtyOnSO,
		|	0                                 AS QtyOnHand
		|INTO
		|	Table_OrdersDispatched_OrdersRegistered_Inventory
		|FROM
		|	AccumulationRegister.OrdersDispatched.Balance AS OrdersDispatchedBalance
		|	LEFT JOIN InformationRegister.OrdersStatuses.SliceLast AS OrdersStatusesSliceLast
		|		ON   OrdersDispatchedBalance.Order = OrdersStatusesSliceLast.Order
		|		AND (OrdersStatusesSliceLast.Status = VALUE(Enum.OrderStatuses.Open)
		|		  OR OrdersStatusesSliceLast.Status = VALUE(Enum.OrderStatuses.Backordered))
		|WHERE
		|	OrdersDispatchedBalance.Item = &Ref
		|
		|UNION ALL
		|
		|SELECT
		// ------------------------------------------------------
		// QtyOnSO = OrdersRegistered.Quantity - OrdersRegistered.Shipped(Invoiced) > 0 
		|	OrdersRegisteredBalance.Counterparty,
		|	OrdersRegisteredBalance.Order,
		|	OrdersRegisteredBalance.Item,
		|	0,
		|	CASE WHEN &Type = VALUE(Enum.InventoryTypes.Inventory)
		|             THEN CASE WHEN OrdersRegisteredBalance.QuantityBalance - OrdersRegisteredBalance.ShippedBalance > 0
		|	                    THEN OrdersRegisteredBalance.QuantityBalance - OrdersRegisteredBalance.ShippedBalance 
		|	                    ELSE 0 END
		|        WHEN &Type = VALUE(Enum.InventoryTypes.NonInventory)
		|             THEN CASE WHEN OrdersRegisteredBalance.QuantityBalance - OrdersRegisteredBalance.InvoicedBalance > 0
		|	                    THEN OrdersRegisteredBalance.QuantityBalance - OrdersRegisteredBalance.InvoicedBalance 
		|	                    ELSE 0 END
		|        ELSE 0 END,
		|	0
		|FROM
		|	AccumulationRegister.OrdersRegistered.Balance AS OrdersRegisteredBalance
		|	LEFT JOIN InformationRegister.OrdersStatuses.SliceLast AS OrdersStatusesSliceLast
		|		ON   OrdersRegisteredBalance.Order = OrdersStatusesSliceLast.Order
		|		AND (OrdersStatusesSliceLast.Status = VALUE(Enum.OrderStatuses.Open)
		|		  OR OrdersStatusesSliceLast.Status = VALUE(Enum.OrderStatuses.Backordered))
		|WHERE
		|	OrdersRegisteredBalance.Item = &Ref
		|
		|UNION ALL
		|
		|SELECT
		// ------------------------------------------------------
		// QtyOnHand = Inventory.Qty(0) 
		|	NULL,
		|	NULL,
		|	InventoryBalance.Item,
		|	0,
		|	0,
		|	CASE WHEN &Type = VALUE(Enum.InventoryTypes.Inventory)
		|	          THEN InventoryBalance.QtyBalance
		|        WHEN &Type = VALUE(Enum.InventoryTypes.NonInventory)
		|             THEN 0
		|        ELSE 0 END
		|FROM
		|	AccumulationRegister.Inventory.Balance(, Item = &Ref) AS InventoryBalance";
		QueryText   = QueryText + _DemoDocumentPosting.GetDelimiterOfBatchQuery();
		QueryTables = QueryTables + 1;
		
		// Group data by item accumulating quantities by different companies and orders
		QueryText = QueryText +
		"SELECT
		|	TableBalances.Item        AS Item,
		|	SUM(TableBalances.QtyOnPO)   AS QtyOnPO,
		|	SUM(TableBalances.QtyOnSO)   AS QtyOnSO,
		|	SUM(TableBalances.QtyOnHand) AS QtyOnHand,
		|	CASE WHEN &Type = VALUE(Enum.InventoryTypes.Inventory)
		|             THEN CASE WHEN SUM(TableBalances.QtyOnHand) + SUM(TableBalances.QtyOnPO) - SUM(TableBalances.QtyOnSO) > 0
		|	                    THEN SUM(TableBalances.QtyOnHand) + SUM(TableBalances.QtyOnPO) - SUM(TableBalances.QtyOnSO)
		|		                ELSE 0 END
		|        WHEN &Type = VALUE(Enum.InventoryTypes.NonInventory)
		|             THEN 0
		|        ELSE 0 END              AS QtyAvailableToPromise
		|FROM
		|	Table_OrdersDispatched_OrdersRegistered_Inventory AS TableBalances
		|GROUP BY
		|	TableBalances.Item";
		QueryText   = QueryText + _DemoDocumentPosting.GetDelimiterOfBatchQuery();
		QueryTables = QueryTables + 1;
		
		// Execute query
		Query.Text  = QueryText;
		QueryResult = Query.ExecuteBatch();
		
		// Fill form attributes with query result
		Selection = QueryResult[QueryTables].Choose();
		If Selection.Next() Then
			FillPropertyValues(ThisForm, Selection, "QtyOnPO, QtyOnSO, QtyOnHand, QtyAvailableToPromise");
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
// Prefills default accounts, determines accounts descriptions, and sets accounts visibility
//
Procedure TypeOnChange(Item)
	
	NewItemType = Object.Type;
	
	If _DemoGeneralFunctions.InventoryType(NewItemType) AND Object.Ref.IsEmpty() Then
		Items.CostingMethod.ReadOnly = False;
		Items.DefaultLocation.ReadOnly = False;
	Else
		Items.CostingMethod.ReadOnly = True;
		Items.DefaultLocation.ReadOnly = True;
	EndIf;
	
	Acct = _DemoGeneralFunctions.InventoryAcct(NewItemType);
	AccountDescription = CommonUse.GetAttributeValue(Acct, "Description");
	Object.InventoryOrExpenseAccount = Acct;
	Items.InventoryAcctLabel.Title = AccountDescription;
		
EndProcedure

&AtClient
// Determines an account description
//
Procedure InventoryOrExpenseAccountOnChange(Item)
	
	Items.InventoryAcctLabel.Title =
		CommonUse.GetAttributeValue(Object.InventoryOrExpenseAccount, "Description");
		
EndProcedure

&AtClient
// Determines an account description
//
Procedure IncomeAccountOnChange(Item)
	
	Items.IncomeAcctLabel.Title =
		CommonUse.GetAttributeValue(Object.IncomeAccount, "Description");
		
EndProcedure

&AtClient
// Determines an account description
//
Procedure COGSAccountOnChange(Item)
	
	Items.COGSAcctLabel.Title =
		CommonUse.GetAttributeValue(Object.COGSAccount, "Description");	
		
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// Doesn't allow to save an inventory item type without a set costing type
	
	If Object.Type = Enums.InventoryTypes.Inventory Then
		If Object.CostingMethod.IsEmpty() Then
			Message = New UserMessage();
			Message.Text=NStr("en='Costing method field is empty'");
			Message.Field = "Object.CostingMethod";
			Message.Message();
			Cancel = True;
			Return;
		EndIf;
	EndIf;

	// Doesn't allow to save a LIFO costing item if the Disable LIFO setting is set
	
	If Object.Type = Enums.InventoryTypes.Inventory Then
		If Object.CostingMethod = Enums.InventoryCostingMethods.LIFO Then
			If Constants.DisableLIFO.Get() = True Then
				Message = New UserMessage();
				Message.Text=NStr("en='The Disable LIFO (IFRS) setting is on'");
				Message.Field = "Object.CostingMethod";
				Message.Message();
				Cancel = True;
				Return;
            EndIf;
        EndIf;
	EndIf;
		
EndProcedure






