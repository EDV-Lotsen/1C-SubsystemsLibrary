﻿
////////////////////////////////////////////////////////////////////////////////
// Purchase Invoice: Manager module
//
////////////////////////////////////////////////////////////////////////////////
// DOCUMENT POSTING

// Pre-check, lock, calculate data before write document
Function PrepareDataBeforeWrite(AdditionalProperties, DocumentParameters, Cancel) Export
	
	// 0.1. Access data without rights checking
	SetPrivilegedMode(True);
	
	// 0.2. Create list of query tables (according to the list of requested balances)
	PreCheck     = New Structure;
	LocksList    = New Structure;
	BalancesList = New Structure;
	
	
	// 1.1. Create a query to request data
	Query = New Query;
	Query.TempTablesManager = New TempTablesManager;
	
	// 1.2. Put supplied DocumentParameters in query parameters and temporary tables
	For Each Parameter In DocumentParameters Do
		If TypeOf(Parameter.Value) = Type("ValueTable") Then
			_DemoDocumentPosting.PutTemporaryTable(Parameter.Value, "Table_"+Parameter.Key, Query.TempTablesManager);
		ElsIf TypeOf(Parameter.Value) = Type("PointInTime") Then
			Query.SetParameter(Parameter.Key, New Boundary(Parameter.Value, BoundaryType.Excluding));
		Else
			Query.SetParameter(Parameter.Key, Parameter.Value);
		EndIf;
	EndDo;
	
	
	// 2.1. Request data for lock in register before accessing balances
	Query.Text = "";
	If AdditionalProperties.Orders.Count() > 0 Then
		Query.Text = Query.Text + Query_OrdersDispatched_Lock(LocksList);
	EndIf;
	
	// 2.2. Proceed with locking the data
	If Not IsBlankString(Query.Text) Then
		QueryResult = Query.ExecuteBatch();
		For Each LockTable In LocksList Do
			_DemoDocumentPosting.LockDataSourceBeforeWrite(StrReplace(LockTable.Key, "_", "."), QueryResult[LockTable.Value], DataLockMode.Exclusive);
		EndDo;
	EndIf;
		
	
	// 3.1. Query for order balances excluding document data (if it already affected to)
	Query.Text = "";
	If AdditionalProperties.Orders.Count() > 0 Then
		Query.Text = Query.Text + Query_OrdersDispatched_Balance(BalancesList);
	EndIf;
	
	// 3.2. Save balances in posting parameters
	If Not IsBlankString(Query.Text) Then
		QueryResult = Query.ExecuteBatch();
		For Each BalanceTable In BalancesList Do
			PreCheck.Insert(BalanceTable.Key, QueryResult[BalanceTable.Value].Unload());
		EndDo;
	EndIf;
	
	// 3.3. Put structure of prechecked registers in additional properties
	If PreCheck.Count() > 0 Then
		AdditionalProperties.Posting.Insert("PreCheck", PreCheck);
	EndIf;
	
EndFunction

// Collect document data for posting on the server (in terms of document)
Function PrepareDataStructuresForPosting(DocumentRef, AdditionalProperties, RegisterRecords) Export
	Var PreCheck;
	
	// Create list of posting tables (according to the list of registers)
	TablesList = New Structure;
	
	// Create a query to request document data
	Query = New Query;
	Query.TempTablesManager = New TempTablesManager;
	Query.SetParameter("Ref", DocumentRef);
	
	// Query for document's tables
	Query.Text   = "";
	If AdditionalProperties.Orders.Count() > 0 Then
		Query.Text = Query.Text +
		             Query_OrdersStatuses(TablesList) +
	                 Query_OrdersDispatched(TablesList);
	EndIf;
				  
	// Execute query, fill temporary tables with postings data
	If Not IsBlankString(Query.Text) Then
		// Fill data from precheck
		If AdditionalProperties.Posting.Property("PreCheck", PreCheck) And PreCheck.Count() > 0 Then
			For Each PreCheckTable In PreCheck Do
				_DemoDocumentPosting.PutTemporaryTable(PreCheckTable.Value, PreCheckTable.Key, Query.TempTablesManager);
			EndDo;
		EndIf;
		
		// Execute query
		QueryResult = Query.ExecuteBatch();
		
		// Save documents table in posting parameters
		For Each DocumentTable In TablesList Do
			AdditionalProperties.Posting.PostingTables.Insert(DocumentTable.Key, QueryResult[DocumentTable.Value].Unload());
		EndDo;
		
		// Custom update after filling of all tables
		CheckCloseParentOrders(DocumentRef, AdditionalProperties, Query.TempTablesManager);
	EndIf;
	
	// Fill list of registers to check (non-negative) balances in posting parameters
	FillRegistersCheckList(AdditionalProperties, RegisterRecords);
	
EndFunction

// Collect document data for posting on the server (in terms of document)
Function PrepareDataStructuresForPostingClearing(DocumentRef, AdditionalProperties, RegisterRecords) Export
	
	// Fill list of registers to check (non-negative) balances in posting parameters
	FillRegistersCheckList(AdditionalProperties, RegisterRecords);
	
EndFunction

// Query for document data
Function Query_OrdersStatuses(TablesList)

	// Add OrdersStatuses table to document structure
	TablesList.Insert("Table_OrdersStatuses", TablesList.Count());
	
	// Collect orders statuses data
	QueryText =
	"SELECT DISTINCT
	// ------------------------------------------------------
	// Standard Attributes
	|	LineItems.Ref                         AS Recorder,
	|	LineItems.Ref.Date                    AS Period,
	|	1                                     AS LineNumber,
	|	True								  AS Active,
	// ------------------------------------------------------
	// Dimensions
	|	LineItems.Order                       AS Order,
	// ------------------------------------------------------
	// Resources
	|	VALUE(Enum.OrderStatuses.Backordered) AS Status
	// ------------------------------------------------------
	// Attributes
	// ------------------------------------------------------
	|FROM
	|	Document.PurchaseInvoice.LineItems AS LineItems
	|WHERE
	|	LineItems.Ref = &Ref
	|   AND LineItems.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|ORDER BY
	|	LineItems.Order.Date";	
	
	Return QueryText + _DemoDocumentPosting.GetDelimiterOfBatchQuery();
	
EndFunction

// Query for document data
Function Query_OrdersDispatched(TablesList)

	// Add OrdersDispatched table to document structure
	TablesList.Insert("Table_OrdersDispatched", TablesList.Count());
	
	// Collect orders dispatched data
	QueryText =
	"SELECT
	// ------------------------------------------------------
	// Standard Attributes
	|	LineItems.Ref                         AS Recorder,
	|	LineItems.Ref.Date                    AS Period,
	|	LineItems.LineNumber                  AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	True								  AS Active,
	// ------------------------------------------------------
	// Dimensions
	|	LineItems.Ref.Counterparty            AS Counterparty,
	|	LineItems.Order                       AS Order,
	|	LineItems.Item                     AS Item,
	// ------------------------------------------------------
	// Resources
	|	0                                     AS Quantity,
	|	CASE WHEN LineItems.Item.Type = VALUE(Enum.InventoryTypes.Inventory)
	|	     THEN CASE WHEN LineItems.Quantity - 
	|	                    CASE WHEN OrdersDispatchedBalance.Received - OrdersDispatchedBalance.Invoiced > 0
	|	                         THEN OrdersDispatchedBalance.Received - OrdersDispatchedBalance.Invoiced
	|	                         ELSE 0 END > 0
	|	               THEN LineItems.Quantity - 
	|	                    CASE WHEN OrdersDispatchedBalance.Received - OrdersDispatchedBalance.Invoiced > 0
	|	                         THEN OrdersDispatchedBalance.Received - OrdersDispatchedBalance.Invoiced
	|	                         ELSE 0 END
	|	               ELSE 0 END
	|	     ELSE 0 END                       AS Received,
	|	LineItems.Quantity                    AS Invoiced
	// ------------------------------------------------------
	// Attributes
	// ------------------------------------------------------
	|FROM
	|	Document.PurchaseInvoice.LineItems AS LineItems
	|	LEFT JOIN Table_OrdersDispatched_Balance AS OrdersDispatchedBalance
	|		ON  OrdersDispatchedBalance.Counterparty = LineItems.Ref.Counterparty
	|		AND OrdersDispatchedBalance.Order   = LineItems.Order
	|		AND OrdersDispatchedBalance.Item = LineItems.Item
	|WHERE
	|	LineItems.Ref = &Ref
	|   AND LineItems.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|ORDER BY
	|	LineNumber";
	
	Return QueryText + _DemoDocumentPosting.GetDelimiterOfBatchQuery();
	
EndFunction

// Query for dimensions lock data
Function Query_OrdersDispatched_Lock(TablesList)
	
	// Add OrdersDispatched - Lock table to locks structure
	TablesList.Insert("AccumulationRegister_OrdersDispatched", TablesList.Count());
	
	// Collect dimensions for orders dispatched locking
	QueryText = 
	"SELECT DISTINCT
	// ------------------------------------------------------
	// Dimensions
	|	&Counterparty                         AS Counterparty,
	|	LineItems.Order                       AS Order,
	|	LineItems.Item                     AS Item
	// ------------------------------------------------------
	|FROM
	|	Table_LineItems AS LineItems
	|WHERE
	|   LineItems.Order <> VALUE(Document.PurchaseOrder.EmptyRef)";

	Return QueryText + _DemoDocumentPosting.GetDelimiterOfBatchQuery();
	
EndFunction

// Query for balances data
Function Query_OrdersDispatched_Balance(TablesList)
	
	// Add OrdersDispatched - Balances table to balances structure
	TablesList.Insert("Table_OrdersDispatched_Balance", TablesList.Count());
	
	// Collect orders dispatched balances
	QueryText =
	"SELECT
	// ------------------------------------------------------
	// Dimensions
	|	OrdersDispatchedBalance.Counterparty     AS Counterparty,
	|	OrdersDispatchedBalance.Order            AS Order,
	|	OrdersDispatchedBalance.Item          AS Item,
	// ------------------------------------------------------
	// Resources
	|	OrdersDispatchedBalance.QuantityBalance  AS Quantity,
	|	OrdersDispatchedBalance.ReceivedBalance  AS Received,
	|	OrdersDispatchedBalance.InvoicedBalance  AS Invoiced
	// ------------------------------------------------------
	|FROM
	|	AccumulationRegister.OrdersDispatched.Balance(&PointInTime,
	|		(Counterparty, Order) IN
	|			(SELECT
	|				&Counterparty,
	|				LineItems.Order
	|			FROM
	|				Table_LineItems AS LineItems)) AS OrdersDispatchedBalance";
	
	Return QueryText + _DemoDocumentPosting.GetDelimiterOfBatchQuery();
	
EndFunction

// Put structure of registers, which balance should be checked during posting
Procedure FillRegistersCheckList(AdditionalProperties, RegisterRecords)

	// Create structure of registers and its resources to check balances
	BalanceCheck = New Structure;
		
	// Fill structure depending on document write mode
	If AdditionalProperties.Posting.WriteMode = DocumentWriteMode.Posting Then
		
		// No checks performed while posting
	ElsIf AdditionalProperties.Posting.WriteMode = DocumentWriteMode.UndoPosting Then
		
		// No checks performed while unposting
	EndIf;

	// Return structure of registers to check
	If BalanceCheck.Count() > 0 Then
		AdditionalProperties.Posting.Insert("BalanceCheck", BalanceCheck);
	EndIf;
	
EndProcedure

// Custom check for closing of parent orders
// Procedure uses custom data of document to check orders closing
// This prevents from requesting already acquired data
Procedure CheckCloseParentOrders(DocumentRef, AdditionalProperties, TempTablesManager)
	Var Table_OrdersStatuses;
	
	// Skip check if order absent
	If AdditionalProperties.Orders.Count() = 0 Then
		Return;
	EndIf;
	
	// Create new query
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.SetParameter("Ref", DocumentRef);
	
	// Empty query text and tables
	QueryText   = "";
	QueryTables = -1;
	
	// Put temporary table for calculating of final status
	// Table_OrdersDispatched_Balance already placed in TempTablesManager 
	_DemoDocumentPosting.PutTemporaryTable(AdditionalProperties.Posting.PostingTables.Table_OrdersDispatched, "Table_OrdersDispatched", Query.TempTablesManager);
	
	// Create query for calculate order status
	QueryText = QueryText +
	// Combine balance with document postings
	"SELECT
	// ------------------------------------------------------
	// Dimensions
	|	OrdersDispatchedBalance.Counterparty     AS Counterparty,
	|	OrdersDispatchedBalance.Order            AS Order,
	|	OrdersDispatchedBalance.Item          AS Item,
	// ------------------------------------------------------
	// Resources
	|	OrdersDispatchedBalance.Quantity         AS Quantity,
	|	OrdersDispatchedBalance.Received         AS Received,
	|	OrdersDispatchedBalance.Invoiced         AS Invoiced
	// ------------------------------------------------------
	|INTO
	|	OrdersDispatched_Balance_And_Postings
	|FROM
	|	Table_OrdersDispatched_Balance AS OrdersDispatchedBalance
	|   // (Counterparty, Order) IN (SELECT Counterparty, Order FROM Table_LineItems)
	|
	|UNION ALL
	|
	|SELECT
	// ------------------------------------------------------
	// Dimensions
	|	OrdersDispatched.Counterparty,
	|	OrdersDispatched.Order,
	|	OrdersDispatched.Item,
	// ------------------------------------------------------
	// Resources
	|	OrdersDispatched.Quantity,
	|	OrdersDispatched.Received,
	|	OrdersDispatched.Invoiced
	// ------------------------------------------------------
	|FROM
	|	Table_OrdersDispatched AS OrdersDispatched
	|   // Table_LineItems WHERE LineItems.Ref = &Ref AND Order <> EmptyRef()
	|";
	QueryText   = QueryText + _DemoDocumentPosting.GetDelimiterOfBatchQuery();
	QueryTables = QueryTables + 1;
	
	// Calculate final balance after posting the invoice
	QueryText = QueryText +
	"SELECT
	// ------------------------------------------------------
	// Dimensions
	|	OrdersDispatchedBalance.Counterparty     AS Counterparty,
	|	OrdersDispatchedBalance.Order            AS Order,
	|	OrdersDispatchedBalance.Item          AS Item,
	|	OrdersDispatchedBalance.Item.Type     AS Type,
	// ------------------------------------------------------
	// Resources
	|	SUM(OrdersDispatchedBalance.Quantity)    AS Quantity,
	|	SUM(OrdersDispatchedBalance.Received)    AS Received,
	|	SUM(OrdersDispatchedBalance.Invoiced)    AS Invoiced
	// ------------------------------------------------------
	|INTO
	|	OrdersDispatched_Balance_AfterWrite
	|FROM
	|	OrdersDispatched_Balance_And_Postings AS OrdersDispatchedBalance
	|GROUP BY
	|	OrdersDispatchedBalance.Counterparty,
	|	OrdersDispatchedBalance.Order,
	|	OrdersDispatchedBalance.Item,
	|	OrdersDispatchedBalance.Item.Type";
	QueryText   = QueryText + _DemoDocumentPosting.GetDelimiterOfBatchQuery();
	QueryTables = QueryTables + 1;
	
	// Calculate unreceived and uninvoiced items
	QueryText = QueryText +
	"SELECT
	// ------------------------------------------------------
	// Dimensions
	|	OrdersDispatchedBalance.Counterparty     AS Counterparty,
	|	OrdersDispatchedBalance.Order            AS Order,
	|	OrdersDispatchedBalance.Item          AS Item,
	// ------------------------------------------------------
	// Resources
	|   CASE WHEN OrdersDispatchedBalance.Type = VALUE(Enum.InventoryTypes.Inventory)
	|	     THEN OrdersDispatchedBalance.Quantity - OrdersDispatchedBalance.Received
	|	     ELSE 0 END                          AS UnReceived,
	|   CASE WHEN OrdersDispatchedBalance.Type = VALUE(Enum.InventoryTypes.Inventory)
	|	     THEN OrdersDispatchedBalance.Received - OrdersDispatchedBalance.Invoiced
	|        WHEN OrdersDispatchedBalance.Type = VALUE(Enum.InventoryTypes.NonInventory)
	|	     THEN OrdersDispatchedBalance.Quantity - OrdersDispatchedBalance.Invoiced
	|	     ELSE 0 END                          AS UnInvoiced
	// ------------------------------------------------------
	|INTO
	|	OrdersDispatched_Balance_Unclosed
	|FROM
	|	OrdersDispatched_Balance_AfterWrite AS OrdersDispatchedBalance
	|WHERE
	|   CASE WHEN OrdersDispatchedBalance.Type = VALUE(Enum.InventoryTypes.Inventory)
	|	     THEN OrdersDispatchedBalance.Quantity - OrdersDispatchedBalance.Received
	|	     ELSE 0 END > 0
	|OR CASE WHEN OrdersDispatchedBalance.Type = VALUE(Enum.InventoryTypes.Inventory)
	|	     THEN OrdersDispatchedBalance.Received - OrdersDispatchedBalance.Invoiced
	|        WHEN OrdersDispatchedBalance.Type = VALUE(Enum.InventoryTypes.NonInventory)
	|	     THEN OrdersDispatchedBalance.Quantity - OrdersDispatchedBalance.Invoiced
	|	     ELSE 0 END > 0";
	QueryText   = QueryText + _DemoDocumentPosting.GetDelimiterOfBatchQuery();
	QueryTables = QueryTables + 1;
	
	// Determine orders having unclosed items in balance
	QueryText = QueryText +
	"SELECT
	// ------------------------------------------------------
	// Dimensions
	|	OrdersDispatchedBalance.Order            AS Order,
	|	SUM(OrdersDispatchedBalance.UnReceived
	|     + OrdersDispatchedBalance.UnInvoiced)  AS Unclosed
	// ------------------------------------------------------
	|INTO
	|	OrdersDispatched_Balance_Orders_Unclosed
	|FROM
	|	OrdersDispatched_Balance_Unclosed AS OrdersDispatchedBalance
	|GROUP BY
	|	OrdersDispatchedBalance.Order";
	QueryText   = QueryText + _DemoDocumentPosting.GetDelimiterOfBatchQuery();
	QueryTables = QueryTables + 1;
	
	// Calculate closed orders (those in invoice, which don't have unclosed items in theirs balance)
	QueryText = QueryText +
	"SELECT DISTINCT
	|	OrdersDispatched.Order AS Order
	|FROM
	|	Table_OrdersDispatched AS OrdersDispatched
	|   // Table_LineItems WHERE LineItems.Ref = &Ref AND Order <> EmptyRef()
	|	LEFT JOIN OrdersDispatched_Balance_Orders_Unclosed AS OrdersDispatchedBalanceUnclosed
	|		  ON  OrdersDispatchedBalanceUnclosed.Order = OrdersDispatched.Order
	|WHERE
	|	// No unclosed items
	|	ISNULL(OrdersDispatchedBalanceUnclosed.Unclosed, 0) = 0";
	QueryText   = QueryText + _DemoDocumentPosting.GetDelimiterOfBatchQuery();
	QueryTables = QueryTables + 1;
	
	// Clear orders registered postings table
	QueryText   = QueryText + 
	"DROP Table_OrdersDispatched";
	QueryText   = QueryText + _DemoDocumentPosting.GetDelimiterOfBatchQuery();
	
	// Clear balance with document postings table
	QueryText   = QueryText + 
	"DROP OrdersDispatched_Balance_And_Postings";
	QueryText   = QueryText + _DemoDocumentPosting.GetDelimiterOfBatchQuery();
	
	// Clear final balance after posting the invoice table
	QueryText   = QueryText + 
	"DROP OrdersDispatched_Balance_AfterWrite";
	QueryText   = QueryText + _DemoDocumentPosting.GetDelimiterOfBatchQuery();
		
	// Clear unshipped and uninvoiced items table
	QueryText   = QueryText + 
	"DROP OrdersDispatched_Balance_Unclosed";
	QueryText   = QueryText + _DemoDocumentPosting.GetDelimiterOfBatchQuery();
	
	// Clear orders having unclosed items in balance table
	QueryText   = QueryText + 
	"DROP OrdersDispatched_Balance_Orders_Unclosed";
	QueryText   = QueryText + _DemoDocumentPosting.GetDelimiterOfBatchQuery();
	
	// Execute query
	Query.Text  = QueryText;
	QueryResult = Query.ExecuteBatch();
	
	// Check status of final query
	If Not QueryResult[QueryTables].IsEmpty()
	// Update OrderStatus in prefilled table of postings
	And AdditionalProperties.Posting.PostingTables.Property("Table_OrdersStatuses", Table_OrdersStatuses) Then
		
	    // Update closed orders
		Selection = QueryResult[QueryTables].Choose();
		While Selection.Next() Do
			
			// Set OrderStatus -> Closed
			Row = Table_OrdersStatuses.Find(Selection.Order, "Order");
			If Not Row = Undefined Then
				Row.Status = Enums.OrderStatuses.Closed;
			EndIf;
		EndDo;
	EndIf;
	
EndProcedure
	
////////////////////////////////////////////////////////////////////////////////
// DOCUMENT FILLING

// Collect source data for filling document on the server (in terms of document)
Function PrepareDataStructuresForFilling(DocumentRef, AdditionalProperties) Export
	
	// Create list of posting tables (according to the list of registers)
	TablesList = New Structure;
	
	// Create a query to request document data
	Query = New Query;
	Query.TempTablesManager = New TempTablesManager;
	Query.SetParameter("Ref",  DocumentRef);
	Query.SetParameter("Date", AdditionalProperties.Date);
	
	// Query for document's tables
	Query.Text   = "";
	For Each FillingData In AdditionalProperties.Filling.FillingData Do
		
		// Construct query by passed sources
		If FillingData.Key = "Document_PurchaseOrder" Then
			Query.Text = Query.Text +
						 Query_Filling_Document_PurchaseOrder_Attributes(TablesList) +
						 Query_Filling_Document_PurchaseOrder_OrdersStatuses(TablesList) +
						 Query_Filling_Document_PurchaseOrder_OrdersDispatched(TablesList) +
						 Query_Filling_Document_PurchaseOrder_LineItems(TablesList) +
						 Query_Filling_Document_PurchaseOrder_Totals(TablesList);
			
		Else // Next filling source
		EndIf;
		
		Query.SetParameter("FillingData_" + FillingData.Key, FillingData.Value);
	EndDo;
	
	// Add combining query
	Query.Text = Query.Text +
				 Query_Filling_Attributes(TablesList) +
				 Query_Filling_LineItems(TablesList);
				 
	// Add check query
	Query.Text = Query.Text +
				 Query_Filling_Check(TablesList, FillingCheckList(AdditionalProperties));
	
	// Execute query, fill temporary tables with filling data
	If TablesList.Count() > 3 Then
		
		// Execute query
		QueryResult = Query.ExecuteBatch();
		
		AdditionalProperties.Filling.FillingTables.Insert("Table_Attributes", _DemoDocumentPosting.GetTemporaryTable(Query.TempTablesManager, "Table_Attributes"));
		For Each TabularSection In AdditionalProperties.Metadata.TabularSections Do
			If TablesList.Property("Table_"+TabularSection.Name) Then
				AdditionalProperties.Filling.FillingTables.Insert("Table_"+TabularSection.Name, _DemoDocumentPosting.GetTemporaryTable(Query.TempTablesManager, "Table_"+TabularSection.Name));
			EndIf;
		EndDo;	
		AdditionalProperties.Filling.FillingTables.Insert("Table_Check", _DemoDocumentPosting.GetTemporaryTable(Query.TempTablesManager, "Table_Check"));
	EndIf;
	
EndFunction

// Query for document filling
Function Query_Filling_Document_PurchaseOrder_Attributes(TablesList)

	// Add Attributes table to document structure
	TablesList.Insert("Table_Document_PurchaseOrder_Attributes", TablesList.Count());
	
	// Collect attributes data
	QueryText =
		"SELECT
		|	PurchaseOrder.Ref                       AS FillingData,
		|	PurchaseOrder.Counterparty              AS Counterparty,
		|	PurchaseOrder.CounterpartyCode          AS CounterpartyCode,
		|	PurchaseOrder.Currency                  AS Currency,
		|	PurchaseOrder.ExchangeRate              AS ExchangeRate,
		|	PurchaseOrder.Location                  AS Location,
		|	CASE
		|		WHEN PurchaseOrder.Counterparty.Terms.Days IS NULL THEN DATEADD(&Date, DAY, 14)
		|		WHEN PurchaseOrder.Counterparty.Terms.Days = 0          THEN DATEADD(&Date, DAY, 14)
		|		ELSE                                               DATEADD(&Date, DAY, PurchaseOrder.Counterparty.Terms.Days)
		|	END                                     AS DueDate,
		|	ISNULL(PurchaseOrder.Counterparty.Terms, VALUE(Catalog.PaymentTerms.EmptyRef))
		|	                                        AS Terms,
		|	ISNULL(PurchaseOrder.Currency.DefaultAPAccount, VALUE(ChartOfAccounts.ChartOfAccounts.EmptyRef))
		|	                                        AS APAccount,
		|	PurchaseOrder.PriceIncludesVAT          AS PriceIncludesVAT
		|INTO
		|	Table_Document_PurchaseOrder_Attributes
		|FROM
		|	Document.PurchaseOrder AS PurchaseOrder
		|WHERE
		|	PurchaseOrder.Ref IN (&FillingData_Document_PurchaseOrder)";

	Return QueryText + _DemoDocumentPosting.GetDelimiterOfBatchQuery();
	
EndFunction

// Query for document filling
Function Query_Filling_Document_PurchaseOrder_OrdersStatuses(TablesList)

	// Add OrdersStatuses table to document structure
	TablesList.Insert("Table_Document_PurchaseOrder_OrdersStatuses", TablesList.Count());
	
	// Collect orders statuses data
	QueryText =
		"SELECT
		// ------------------------------------------------------
		// Dimensions
		|	PurchaseOrder.Ref                        AS Order,
		// ------------------------------------------------------
		// Resources
		|	CASE
		|		WHEN PurchaseOrder.DeletionMark THEN
		|			 VALUE(Enum.OrderStatuses.Deleted)
		|		WHEN NOT PurchaseOrder.Posted THEN
		|			 VALUE(Enum.OrderStatuses.Draft)
		|		WHEN OrdersStatuses.Status IS NULL THEN
		|			 VALUE(Enum.OrderStatuses.Open)
		|		WHEN OrdersStatuses.Status = VALUE(Enum.OrderStatuses.EmptyRef) THEN
		|			 VALUE(Enum.OrderStatuses.Open)
		|		ELSE
		|			 OrdersStatuses.Status
		|	END                                     AS Status
		// ------------------------------------------------------
		|INTO
		|	Table_Document_PurchaseOrder_OrdersStatuses
		|FROM
		|	Document.PurchaseOrder AS PurchaseOrder
		|		LEFT JOIN InformationRegister.OrdersStatuses.SliceLast AS OrdersStatuses
		|		ON PurchaseOrder.Ref = OrdersStatuses.Order
		|WHERE
		|	PurchaseOrder.Ref IN (&FillingData_Document_PurchaseOrder)";

	Return QueryText + _DemoDocumentPosting.GetDelimiterOfBatchQuery();
	
EndFunction

// Query for document filling
Function Query_Filling_Document_PurchaseOrder_OrdersDispatched(TablesList)

	// Add OrdersDispatched table to document structure
	TablesList.Insert("Table_Document_PurchaseOrder_OrdersDispatched", TablesList.Count());
	
	// Collect orders items data
	QueryText =
		"SELECT
		// ------------------------------------------------------
		// Dimensions
		|	OrdersDispatchedBalance.Counterparty     AS Counterparty,
		|	OrdersDispatchedBalance.Order            AS Order,
		|	OrdersDispatchedBalance.Item          AS Item,
		// ------------------------------------------------------
		// Resources                                                                                                        // ---------------------------------------
		|	OrdersDispatchedBalance.QuantityBalance  AS Quantity,                                                           // Backorder quantity calculation
		|	CASE                                                                                                            // ---------------------------------------
		|		WHEN OrdersStatuses.Status = VALUE(Enum.OrderStatuses.Open)        THEN 0                                   // Order status = Open:
		|		WHEN OrdersStatuses.Status = VALUE(Enum.OrderStatuses.Backordered) THEN                                     //   Backorder = 0
		|			CASE                                                                                                    // Order status = Backorder:
		|				WHEN OrdersDispatchedBalance.Item.Type = VALUE(Enum.InventoryTypes.Inventory) THEN               //   Inventory:
		|					CASE                                                                                            //     Backorder = Ordered - Received >= 0
		|						WHEN OrdersDispatchedBalance.QuantityBalance > OrdersDispatchedBalance.ReceivedBalance THEN //     |
		|							 OrdersDispatchedBalance.QuantityBalance - OrdersDispatchedBalance.ReceivedBalance      //     |
		|						ELSE 0 END                                                                                  //     |
		|				WHEN OrdersDispatchedBalance.Item.Type = VALUE(Enum.InventoryTypes.NonInventory) THEN            //   Non-inventory:
		|					CASE                                                                                            //     Backorder = Ordered - Invoiced >= 0
		|						WHEN OrdersDispatchedBalance.QuantityBalance > OrdersDispatchedBalance.InvoicedBalance THEN //     |
		|							 OrdersDispatchedBalance.QuantityBalance - OrdersDispatchedBalance.InvoicedBalance      //     |
		|						ELSE 0 END                                                                                  //     |
		|				ELSE 0                                                                                              //   NULL or something else:
		|               END                                                                                                 //     0
		|		WHEN OrdersStatuses.Status = VALUE(Enum.OrderStatuses.Closed)      THEN 0                                   // Order status = Closed:
		|		ELSE 0                                                                                                      //   Backorder = 0
		|		END                                  AS Backorder
		// ------------------------------------------------------
		|INTO
		|	Table_Document_PurchaseOrder_OrdersDispatched
		|FROM
		|	AccumulationRegister.OrdersDispatched.Balance(,
		|		(Counterparty, Order, Item) IN
		|			(SELECT
		|				PurchaseOrderLineItems.Ref.Counterparty,
		|				PurchaseOrderLineItems.Ref,
		|				PurchaseOrderLineItems.Item
		|			FROM
		|				Document.PurchaseOrder.LineItems AS PurchaseOrderLineItems
		|			WHERE
		|				PurchaseOrderLineItems.Ref IN (&FillingData_Document_PurchaseOrder))) AS OrdersDispatchedBalance
		|	LEFT JOIN Table_Document_PurchaseOrder_OrdersStatuses AS OrdersStatuses
		|		ON OrdersDispatchedBalance.Order = OrdersStatuses.Order";

	Return QueryText + _DemoDocumentPosting.GetDelimiterOfBatchQuery();
	
EndFunction

// Query for document filling
Function Query_Filling_Document_PurchaseOrder_LineItems(TablesList)

	// Add LineItems table to document structure
	TablesList.Insert("Table_Document_PurchaseOrder_LineItems", TablesList.Count());
	
	// Collect line items data
	QueryText =
		"SELECT
		|	PurchaseOrderLineItems.Ref                 AS FillingData,
		|	PurchaseOrderLineItems.Item             AS Item,
		|	PurchaseOrderLineItems.ItemDescription  AS ItemDescription,
		|	PurchaseOrderLineItems.Price               AS Price,
		|	PurchaseOrderLineItems.Price               AS OrderPrice,
		|	CASE
		|		WHEN OrdersStatuses.Status = VALUE(Enum.OrderStatuses.Open)
		|			THEN ISNULL(OrdersDispatched.Quantity, PurchaseOrderLineItems.Quantity)
		|		WHEN OrdersStatuses.Status = VALUE(Enum.OrderStatuses.Backordered)
		|			THEN ISNULL(OrdersDispatched.Backorder, PurchaseOrderLineItems.Quantity)
		|		WHEN OrdersStatuses.Status = VALUE(Enum.OrderStatuses.Closed)
		|			THEN ISNULL(OrdersDispatched.Backorder, 0)
		|		ELSE 0
		|	END                                        AS Quantity,
		|	CAST( // Format(Quantity * Price, ""ND=15; NFD=2"")
		|		CASE
		|			WHEN OrdersStatuses.Status = VALUE(Enum.OrderStatuses.Open)
		|				THEN ISNULL(OrdersDispatched.Quantity, PurchaseOrderLineItems.Quantity)
		|			WHEN OrdersStatuses.Status = VALUE(Enum.OrderStatuses.Backordered)
		|				THEN ISNULL(OrdersDispatched.Backorder, PurchaseOrderLineItems.Quantity)
		|			WHEN OrdersStatuses.Status = VALUE(Enum.OrderStatuses.Closed)
		|				THEN ISNULL(OrdersDispatched.Backorder, 0)
		|			ELSE 0
		|		END * PurchaseOrderLineItems.Price 
		|		AS NUMBER (15, 2))                     AS LineTotal,
		|	PurchaseOrderLineItems.VATCode             AS VATCode,
		|	CAST( // Format(LineTotal * VATRate / 100, ""ND=15; NFD=2"")
		|		CAST( // Format(Quantity * Price, ""ND=15; NFD=2"")
		|			CASE
		|				WHEN OrdersStatuses.Status = VALUE(Enum.OrderStatuses.Open)
		|					THEN ISNULL(OrdersDispatched.Quantity, PurchaseOrderLineItems.Quantity)
		|				WHEN OrdersStatuses.Status = VALUE(Enum.OrderStatuses.Backordered)
		|					THEN ISNULL(OrdersDispatched.Backorder, PurchaseOrderLineItems.Quantity)
		|				WHEN OrdersStatuses.Status = VALUE(Enum.OrderStatuses.Closed)
		|					THEN ISNULL(OrdersDispatched.Backorder, 0)
		|				ELSE 0
		|			END * PurchaseOrderLineItems.Price
		|		AS NUMBER (15, 2)) *
		|		CASE // VATRate = ?(Ref.PriceIncludesVAT, VATCode.PurchaseInclRate, VATCode.PurchaseExclRate)
		|			WHEN PurchaseOrderLineItems.Ref.PriceIncludesVAT IS NULL THEN 0
		|			WHEN PurchaseOrderLineItems.Ref.PriceIncludesVAT         THEN ISNULL(PurchaseOrderLineItems.VATCode.PurchaseInclRate, 0)
		|			ELSE                                                          ISNULL(PurchaseOrderLineItems.VATCode.PurchaseExclRate, 0)
		|		END /
		|		100
		|	AS NUMBER (15, 2))                         AS VAT,
		|	PurchaseOrderLineItems.Ref                 AS Order,
		|	PurchaseOrderLineItems.Ref.Counterparty    AS Counterparty
		|INTO
		|	Table_Document_PurchaseOrder_LineItems
		|FROM
		|	Document.PurchaseOrder.LineItems AS PurchaseOrderLineItems
		|	LEFT JOIN Table_Document_PurchaseOrder_OrdersDispatched AS OrdersDispatched
		|		ON  OrdersDispatched.Counterparty = PurchaseOrderLineItems.Ref.Counterparty
		|		AND OrdersDispatched.Order   = PurchaseOrderLineItems.Ref
		|		AND OrdersDispatched.Item = PurchaseOrderLineItems.Item
		|	LEFT JOIN Table_Document_PurchaseOrder_OrdersStatuses AS OrdersStatuses
		|		ON OrdersStatuses.Order = PurchaseOrderLineItems.Ref
		|WHERE
		|	PurchaseOrderLineItems.Ref IN (&FillingData_Document_PurchaseOrder)";
		
	Return QueryText + _DemoDocumentPosting.GetDelimiterOfBatchQuery();
	
EndFunction

// Query for document filling
Function Query_Filling_Document_PurchaseOrder_Totals(TablesList)

	// Add Totals table to document structure
	TablesList.Insert("Table_Document_PurchaseOrder_Totals", TablesList.Count());
	
	// Collect totals data
	QueryText =
		"SELECT
		// Totals of document
		|	PurchaseOrderLineItems.FillingData      AS FillingData,
		|
		|	CAST( // Format(Total(VAT) * ExchangeRate, ""ND=15; NFD=2"")
		|		SUM(PurchaseOrderLineItems.VAT) *
		|		PurchaseOrder.ExchangeRate
		|		AS NUMBER (15, 2))                  AS VATTotal,
		|
		|	CASE
		|		WHEN PurchaseOrder.PriceIncludesVAT THEN // Total(LineTotal)
		|			SUM(PurchaseOrderLineItems.LineTotal)
		|		ELSE                                     // Total(LineTotal) + Total(VAT)
		|			SUM(PurchaseOrderLineItems.LineTotal) +
		|			SUM(PurchaseOrderLineItems.VAT)
		|	END                                     AS DocumentTotal,
		|
		|	CAST( // Format(DocumentTotal * ExchangeRate, ""ND=15; NFD=2"")
		|		CASE // DocumentTotal
		|			WHEN PurchaseOrder.PriceIncludesVAT THEN // Total(LineTotal)
		|				SUM(PurchaseOrderLineItems.LineTotal)
		|			ELSE                                     // Total(LineTotal) + Total(VAT)
		|				SUM(PurchaseOrderLineItems.LineTotal) +
		|				SUM(PurchaseOrderLineItems.VAT)
		|		END *
		|		PurchaseOrder.ExchangeRate
		|		AS NUMBER (15, 2))                  AS DocumentTotalRC
		|
		|INTO
		|	Table_Document_PurchaseOrder_Totals
		|FROM
		|	Table_Document_PurchaseOrder_LineItems AS PurchaseOrderLineItems
		|	LEFT JOIN Table_Document_PurchaseOrder_Attributes AS PurchaseOrder
		|		ON PurchaseOrder.FillingData = PurchaseOrderLineItems.FillingData
		|GROUP BY
		|	PurchaseOrderLineItems.FillingData,
		|	PurchaseOrder.ExchangeRate,
		|	PurchaseOrder.PriceIncludesVAT";

	Return QueryText + _DemoDocumentPosting.GetDelimiterOfBatchQuery();
	
EndFunction

// Query for document filling
Function Query_Filling_Attributes(TablesList)

	// Add Attributes table to document structure
	TablesList.Insert("Table_Attributes", TablesList.Count());
	
	// Fill data from attributes and totals
	QueryText = "";
	If TablesList.Property("Table_Document_PurchaseOrder_Attributes") Then
		QueryText = QueryText + ?(Not IsBlankString(QueryText), 
		"
		|
		|UNION ALL
		|
		|",
		"");
			
		SelectionText =
		"SELECT
		|	Document_PurchaseOrder_Attributes.FillingData,
		|	Document_PurchaseOrder_Attributes.Counterparty,
		|	Document_PurchaseOrder_Attributes.CounterpartyCode,
		|	Document_PurchaseOrder_Totals.DocumentTotal,
		|	Document_PurchaseOrder_Attributes.Currency,
		|	Document_PurchaseOrder_Attributes.ExchangeRate,
		|	Document_PurchaseOrder_Totals.DocumentTotalRC,
		|	Document_PurchaseOrder_Attributes.Location,
		|	Document_PurchaseOrder_Attributes.DueDate,
		|	Document_PurchaseOrder_Attributes.Terms,
		|	Document_PurchaseOrder_Totals.VATTotal,
		|	Document_PurchaseOrder_Attributes.APAccount,
		|	Document_PurchaseOrder_Attributes.PriceIncludesVAT
		|{Into}
		|FROM
		|	Table_Document_PurchaseOrder_Attributes AS Document_PurchaseOrder_Attributes
		|	LEFT JOIN Table_Document_PurchaseOrder_Totals AS Document_PurchaseOrder_Totals
		|		ON Document_PurchaseOrder_Totals.FillingData = Document_PurchaseOrder_Attributes.FillingData";
		
		QueryText = QueryText + StrReplace(SelectionText, "{Into}",
		?(IsBlankString(QueryText), 
		"INTO
		|	Table_Attributes",
		""));
	EndIf;
	
	// Fill data from next source
	// --------------------------
	
	Return QueryText + _DemoDocumentPosting.GetDelimiterOfBatchQuery();
	
EndFunction

// Query for document filling
Function Query_Filling_LineItems(TablesList)

	// Add LineItems table to document structure
	TablesList.Insert("Table_LineItems", TablesList.Count());
	
	// Fill data from attributes and totals
	QueryText = "";
	If TablesList.Property("Table_Document_PurchaseOrder_LineItems") Then
		QueryText = QueryText + ?(Not IsBlankString(QueryText), 
		"
		|
		|UNION ALL
		|
		|",
		"");
		
		SelectionText =
		"SELECT
		|	Document_PurchaseOrder_LineItems.FillingData,
		|	Document_PurchaseOrder_LineItems.Item,
		|	Document_PurchaseOrder_LineItems.ItemDescription,
		|	Document_PurchaseOrder_LineItems.Price,
		|	Document_PurchaseOrder_LineItems.OrderPrice,
		|	Document_PurchaseOrder_LineItems.Quantity,
		|	Document_PurchaseOrder_LineItems.LineTotal,
		|	Document_PurchaseOrder_LineItems.VATCode,
		|	Document_PurchaseOrder_LineItems.VAT,
		|	Document_PurchaseOrder_LineItems.Order
		|{Into}
		|FROM
		|	Table_Document_PurchaseOrder_LineItems AS Document_PurchaseOrder_LineItems
		|WHERE
		|	Document_PurchaseOrder_LineItems.Quantity > 0";
		
		QueryText = QueryText + StrReplace(SelectionText, "{Into}",
		?(IsBlankString(QueryText), 
		"INTO
		|	Table_LineItems",
		""));
	EndIf;
	
	// Fill data from next source
	// --------------------------
	
	Return QueryText + _DemoDocumentPosting.GetDelimiterOfBatchQuery();
	
EndFunction

// Fill structure of attributes, which should be checked during filling
Function FillingCheckList(AdditionalProperties)

	// Create structure of registers and its resources to check balances
	CheckAttributes = New Structure;
	// Group by attributes to check uniqueness
	CheckAttributes.Insert("Counterparty",     "Check");
	CheckAttributes.Insert("Currency",         "Check");
	CheckAttributes.Insert("ExchangeRate",     "Check");
	CheckAttributes.Insert("Location",         "Check");
	CheckAttributes.Insert("APAccount",        "Check");
	CheckAttributes.Insert("PriceIncludesVAT", "Check");
	// Maximal possible values
	CheckAttributes.Insert("DueDate",          "Max");
	// Summarize totals
	CheckAttributes.Insert("VATTotal",         "Sum");
	CheckAttributes.Insert("DocumentTotal",    "Sum");
	CheckAttributes.Insert("DocumentTotalRC",  "Sum");
	
	// Save structure of attributes to check
	If CheckAttributes.Count() > 0 Then
		AdditionalProperties.Filling.Insert("CheckAttributes", CheckAttributes);
	EndIf;
	
	// Return saved structure
	Return CheckAttributes;
	
EndFunction

// Query for document filling
Function Query_Filling_Check(TablesList, CheckAttributes)

	// Check attributes to be checked
	If CheckAttributes.Count() = 0 Then
		Return "";
	EndIf;
	
	// Add Attributes table to document structure
	TablesList.Insert("Table_Check", TablesList.Count());
	
	// Fill data from attributes and totals
	QueryText =
	"SELECT
	|	{Selection}
	|INTO
	|	Table_Check
	|FROM
	|	Table_Attributes AS Attributes
	|GROUP BY
	|	{GroupBy}";
	
	SelectionText = ""; GroupByText = "";
	For Each Attribute In CheckAttributes Do
		If Attribute.Value = "Check" Then
			// Attributes - uniqueness check
			DimensionText = StrReplace("Attributes.{Attribute} AS {Attribute}", "{Attribute}", Attribute.Key);
			SelectionText = ?(IsBlankString(SelectionText), DimensionText, SelectionText+",
				|	"+DimensionText);
			// Group by section	
			DimensionText = StrReplace("Attributes.{Attribute}", "{Attribute}", Attribute.Key);
			GroupByText   = ?(IsBlankString(GroupByText), DimensionText, GroupByText+",
				|	"+DimensionText);
		Else
			// Agregate function
			DimensionText = StrReplace(Upper(Attribute.Value)+"(Attributes.{Attribute}) AS {Attribute}", "{Attribute}", Attribute.Key);
			SelectionText = ?(IsBlankString(SelectionText), DimensionText, SelectionText+",
				|	"+DimensionText);
		EndIf;
	EndDo;
	QueryText = StrReplace(QueryText, "{Selection}", SelectionText);
	QueryText = StrReplace(QueryText, "{GroupBy}",   GroupByText);
	
	Return QueryText + _DemoDocumentPosting.GetDelimiterOfBatchQuery();
	
EndFunction

// Check status of passed purchase order by ref
// Returns True if status passed for invoice filling
Function CheckStatusOfPurchaseOrder(Ref) Export
	
	// Create new query
	Query = New Query;
	Query.SetParameter("Ref", Ref);
	
	QueryText = 
		"SELECT
		|	CASE
		|		WHEN PurchaseOrder.DeletionMark THEN
		|			 VALUE(Enum.OrderStatuses.Deleted)
		|		WHEN NOT PurchaseOrder.Posted THEN
		|			 VALUE(Enum.OrderStatuses.Draft)
		|		WHEN OrdersStatuses.Status IS NULL THEN
		|			 VALUE(Enum.OrderStatuses.Open)
		|		WHEN OrdersStatuses.Status = VALUE(Enum.OrderStatuses.EmptyRef) THEN
		|			 VALUE(Enum.OrderStatuses.Open)
		|		ELSE
		|			 OrdersStatuses.Status
		|	END AS Status
		|FROM
		|	Document.PurchaseOrder AS PurchaseOrder
		|	LEFT JOIN InformationRegister.OrdersStatuses.SliceLast AS OrdersStatuses
		|		ON PurchaseOrder.Ref = OrdersStatuses.Order
		|WHERE
		|	PurchaseOrder.Ref = &Ref";
	Query.Text  = QueryText;
	OrderStatus = Query.Execute().Unload()[0].Status;
	
	StatusOK = (OrderStatus = Enums.OrderStatuses.Open) Or (OrderStatus = Enums.OrderStatuses.Backordered);
	If Not StatusOK Then
		MessageText = NStr("en = 'Failed to generate the invoice on the base of %1 %2.'");
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessageText,
																			   Lower(OrderStatus),
																			   Lower(Metadata.FindByType(TypeOf(Ref)).Presentation())); 
		CommonUseClientServer.MessageToUser(MessageText, Ref);
	EndIf;
	Return StatusOK;	
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// DOCUMENT PRINTING (OLD)

Procedure Print(ObjectArray, PrintParameters, PrintFormsCollection,
           PrintObjects, OutputParameters) Export

     // Setting the kit printing option.
     OutputParameters.AvailablePrintingByKits = True;

     // Checking if a spreadsheet document generation needed for the Purchase Invoice template.
    If _DemoPrintManagement.NeedToPrintTemplate(PrintFormsCollection, "PurchaseInvoice") Then

         // Generating a spreadsheet document and adding it into the print form collection.
         _DemoPrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection,
             "PurchaseInvoice", "Purchase invoice", PrintTemplate(ObjectArray, PrintObjects));

	EndIf;
		 
EndProcedure
	 
Function PrintTemplate(ObjectArray, PrintObjects)
	
	// Create a spreadsheet document and set print parameters.
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersName = "PrintParameters_PurchaseInvoice";

	// Quering necessary data.
	Query = New Query();
	Query.Text =
	"SELECT
	|	PurchaseInvoice.Ref,
	|	PurchaseInvoice.Counterparty,
	|	PurchaseInvoice.Date,
	|	PurchaseInvoice.DocumentTotal,
	|	PurchaseInvoice.Number,
	|	PurchaseInvoice.PriceIncludesVAT,
	|	PurchaseInvoice.Currency,
	|	PurchaseInvoice.VATTotal,
	|	PurchaseInvoice.LineItems.(
	|		Item,
	|		ItemDescription,
	|		Item.Units AS Units,
	|		Quantity,
	|		Price,
	|		VATCode,
	|		VAT,
	|		LineTotal
	|	)
	|FROM
	|	Document.PurchaseInvoice AS PurchaseInvoice
	|WHERE
	|	PurchaseInvoice.Ref IN(&ObjectArray)";
	Query.SetParameter("ObjectArray", ObjectArray);
	Selection = Query.Execute().Select();
   
   	FirstDocument = True;

	Us = Catalogs.Counterparties.OurCompany;
   
   	While Selection.Next() Do
		
		If Not FirstDocument Then
			// All documents need to be outputted on separate pages.
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		FirstDocument = False;
		// Remember current document output beginning line number.
		BeginningLineNumber = SpreadsheetDocument.TableHeight + 1;
	 
	Template = _DemoPrintManagement.GetTemplate("Document.PurchaseInvoice.PF_MXL_PurchaseInvoice");
	 
	TemplateArea = Template.GetArea("Header");
	
	UsBill = _DemoPrintTemplates.ContactInfoDataset(Us, "UsBill", Catalogs.Addresses.EmptyRef());
	ThemBill = _DemoPrintTemplates.ContactInfoDataset(Selection.Counterparty, "ThemBill", Catalogs.Addresses.EmptyRef());
	
	TemplateArea.Parameters.Fill(UsBill);
	TemplateArea.Parameters.Fill(ThemBill);
	 	 
	 TemplateArea.Parameters.Date = Selection.Date;
	 TemplateArea.Parameters.Number = Selection.Number;
	 
	 SpreadsheetDocument.Put(TemplateArea);

	 TemplateArea = Template.GetArea("LineItemsHeader");
	 SpreadsheetDocument.Put(TemplateArea);
	 
	 SelectionLineItems = Selection.LineItems.Choose();
	 TemplateArea = Template.GetArea("LineItems");
	 LineTotalSum = 0;
	 While SelectionLineItems.Next() Do
		 
		 TemplateArea.Parameters.Fill(SelectionLineItems);
		 LineTotal = SelectionLineItems.LineTotal;
		 LineTotalSum = LineTotalSum + LineTotal;
		 SpreadsheetDocument.Put(TemplateArea, SelectionLineItems.Level());
		 
	 EndDo;
	 
	If Selection.VATTotal <> 0 Then;
		 TemplateArea = Template.GetArea("Subtotal");
		 TemplateArea.Parameters.Subtotal = LineTotalSum;
		 SpreadsheetDocument.Put(TemplateArea);
		 
		 TemplateArea = Template.GetArea("VAT");
		 TemplateArea.Parameters.VATTotal = Selection.VATTotal;
		 SpreadsheetDocument.Put(TemplateArea);
	EndIf; 
		 
	 TemplateArea = Template.GetArea("Total");
	If Selection.PriceIncludesVAT Then
	 	TemplateArea.Parameters.DocumentTotal = LineTotalSum;
	Else
		TemplateArea.Parameters.DocumentTotal = LineTotalSum + Selection.VATTotal;
	EndIf;

	 SpreadsheetDocument.Put(TemplateArea);

	 TemplateArea = Template.GetArea("Currency");
	 TemplateArea.Parameters.Currency = Selection.Currency;
	 SpreadsheetDocument.Put(TemplateArea);
	 
     // Setting a print area in the spreadsheet document where to output the object.
     // Necessary for kit printing. 
     _DemoPrintManagement.SetDocumentPrintArea(SpreadsheetDocument, BeginningLineNumber, PrintObjects, Selection.Ref);

   EndDo;
   
   Return SpreadsheetDocument;
   
EndFunction