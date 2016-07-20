//////////////////////////////////////////////////////////////////////////////// 
// PROCEDURES AND FUNCTIONS
//

// Generats the printed form of the document.
// 
// Returns: 
//  SpreadsheetDocument - generated spreadsheet document.
//
Procedure PrintForm(SpreadsheetDocument) Export

	Template = Documents.ProductExpense.GetTemplate("PrintTemplate");

	// Title
	State = Template.GetArea("Title");
	SpreadsheetDocument.Put(State);

	// Header
	Header = Template.GetArea("Header");
	Header.Parameters.Fill(ThisObject);
	SpreadsheetDocument.Put(Header);

	// Products
	State = Template.GetArea("ProductsHeader");
	SpreadsheetDocument.Put(State);
	ProductsArea = Template.GetArea("Products");

	For Each CurRowProducts In Products Do

		ProductsArea.Parameters.Fill(CurRowProducts);
		SpreadsheetDocument.Put(ProductsArea);

	EndDo;

EndProcedure

// Generates the printed form of the document.
// 
// Returns: 
//  SpreadsheetDocument - the generated spreadsheet document.
//
Procedure Recalculate() Export

	For Each CurRowProducts In Products Do

		CurRowProducts.Amount = CurRowProducts.Quantity * CurRowProducts.Price;

	EndDo;

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// OBJECT EVENT HANDLERS

Procedure Posting(Cancel, Mode)

	// Generating the Inventory and Sales RegisterRecords.
	RegisterRecords.Inventory.Write = True;
	RegisterRecords.Sales.Write = True;
	If Mode = DocumentPostingMode.RealTime Then
		RegisterRecords.Inventory.LockForUpdate = True;
	EndIf;	

	// Creating a query to Get the information about services
	Query = New Query("SELECT
						  |    ProductsInDocument.LineNumber AS LineNumber
						  |FROM
						  |    Document.ProductExpense.Products AS ProductsInDocument
						  |WHERE
						  |    ProductsInDocument.Ref = &Ref
						  |    AND ProductsInDocument.Product.Kind = VALUE(Enum.ProductKinds.Service)");

	Query.SetParameter("Ref", Ref);
	ResultServices = Query.Execute().Unload();
	ResultServices.Indexes.Add("LineNumber");

	For Each CurRowProducts In Products Do

		Row = ResultServices.Find(CurRowProducts.LineNumber, "LineNumber");
		If Row = Undefined Then
			
			// Not a service
			Record = RegisterRecords.Inventory.Add();
			Record.RecordType = AccumulationRecordType.Expense;
			Record.Period = Date;
			Record.Product = CurRowProducts.Product;
			Record.Warehouse = Warehouse;
			Record.Quantity = CurRowProducts.Quantity;

		EndIf;

		Record = RegisterRecords.Sales.Add();
		Record.Period = Date;
		Record.Product = CurRowProducts.Product;
		Record.Customer = Customer;
		Record.Quantity = CurRowProducts.Quantity;
		Record.Amount = CurRowProducts.Amount;

	EndDo;

	// Generating the accumulation register MutualSettlements RegisterRecords.
	RegisterRecords.MutualSettlements.Write = True;
	Record = RegisterRecords.MutualSettlements.Add();
	Record.RecordType = AccumulationRecordType.Expense;
	Record.Period = Date;
	Record.Counterparty = Customer;
	Record.Currency = Currency;

	If Currency.IsEmpty() Then
		Record.Amount = Products.Total("Amount");
	Else

		Rate = InformationRegisters.CurrencyRates.GetLast(Date, New Structure("Currency", Currency)).Rate;

		If Rate = 0 Then
			Record.Amount = Products.Total("Amount");
		Else
			Record.Amount = Products.Total("Amount") / Rate;
		EndIf;

	EndIf;

	//Writing RegisterRecords
	RegisterRecords.Write();
	
	//The balances control on real-time posting
	If Mode = DocumentPostingMode.RealTime Then
		// Creating a query to control the balances by products
		Query = New Query("SELECT
							  |    ProductsInDocument.Product AS Product,
							  |    SUM(ProductsInDocument.Quantity) AS Quantity,
							  |    MAX(ProductsInDocument.LineNumber) AS LineNumber
							  |
							  |INTO ProductsRequired
							  |
							  |FROM
							  |    Document.ProductExpense.Products AS ProductsInDocument
							  |
							  |WHERE
							  |    ProductsInDocument.Ref = &Ref
							  |    AND ProductsInDocument.Product.Kind = VALUE(Enum.ProductKinds.Product)
							  |
							  |GROUP BY
							  |    ProductsInDocument.Product
							  |
							  |INDEX BY
							  |    Product
							  |;
							  |
							  |////////////////////////////////////////////////////////////////////////////////
							  |SELECT
							  |    PRESENTATION(ProductsRequired.Product) AS ProductPresentation,
							  |    CASE
							  |        WHEN - ISNULL(InventoryBalance.QuantityBalance, 0) > ProductsInDocument.Quantity
							  |            THEN ProductsInDocument.Quantity
							  |        ELSE - ISNULL(InventoryBalance.QuantityBalance, 0)
							  |    END AS Shortage,
							  |    ProductsInDocument.Quantity - CASE
							  |        WHEN - ISNULL(InventoryBalance.QuantityBalance, 0) > ProductsInDocument.Quantity
							  |            THEN ProductsInDocument.Quantity
							  |        ELSE - ISNULL(InventoryBalance.QuantityBalance, 0)
							  |    END AS MaximumCount,
							  |    ProductsRequired.LineNumber AS LineNumber
							  |
							  |FROM
							  |    ProductsRequired AS ProductsRequired
							  |        LEFT JOIN AccumulationRegister.Inventory.Balance(
							  |                ,
							  |                Product IN
							  |                        (SELECT
							  |                            ProductsRequired.Product
							  |                        FROM
							  |                            ProductsRequired)
							  |                    AND Warehouse = &Warehouse) AS InventoryBalance
							  |        ON ProductsRequired.Product = InventoryBalance.Product
							  |        LEFT JOIN Document.ProductExpense.Products AS ProductsInDocument
							  |        ON ProductsRequired.Product = ProductsInDocument.Product
							  |            AND ProductsRequired.LineNumber = ProductsInDocument.LineNumber
							  |
							  |WHERE
							  |    ProductsInDocument.Ref = &Ref AND
							  |    0 > ISNULL(InventoryBalance.QuantityBalance, 0)
							  |
							  |ORDER BY
							  |    LineNumber");

		Query.SetParameter("Warehouse", Warehouse);
		Query.SetParameter("Ref", Ref);
		ResultWithShortage = Query.Execute();

		ResultSelectionWithShortage = ResultWithShortage.Select();

		// Displaying errors for rows, which does not have enough balance
		While ResultSelectionWithShortage.Next() Do

			Message = New UserMessage();
			Message.Text = NStr("en = 'Shortage '") 
				+ ResultSelectionWithShortage.Shortage 
				+ NStr("en = ' product units'") + """" 
				+ ResultSelectionWithShortage.ProductPresentation 
				+ """" 
				+ NStr("en = ' in warehouse'") 
				+ """" 
				+ Warehouse 
				+ """." 
				+ NStr("en = 'Maximum quantiy: '") 
				+ ResultSelectionWithShortage.MaximumQuantity 
				+ ".";
			Message.Field = NStr("en = 'Products'") 
				+ "[" 
				+ (ResultSelectionWithShortage.LineNumber - 1) 
				+ "]." 
				+ NStr("en =  'Quantity'");
			Message.SetData(ThisObject);
			Message.Message();
			Cancel = True;

		EndDo;

	EndIf;
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)

	//Removing the currency from the checking attributes if the accounting in currency
	//is not performed for this company
	If Not GetFunctionalOption("Multicurrency", New Structure("Company", Company)) Then
		CheckedAttributes.Delete(CheckedAttributes.Find("Currency"));
	EndIf;	
	
	
	// Checking if the "Customer" field is filled
	If Customer.IsEmpty() Then

		// If the customer field is required, informing a user about that
		Message = New UserMessage();
		Message.Text = NStr("en = 'The customer, bill of lading issue to, is not specified.'");
		Message.Field = NStr("en =  'Customer'");
		Message.SetData(ThisObject);

		Message.Message();

		// Informing the platform that we have checked the "Customer" field by ourself
		CheckedAttributes.Delete(CheckedAttributes.Find("Customer"));
		// Due to the data in the document is not consistent, there is no reason to continue working
		Cancel = True;

	EndIf;

	//If the Warehouse is not filled, checking whether there is something but services in a document
	If Warehouse.IsEmpty() And Products.Count() > 0 Then

		// Creating a query to Get the information on products
		Query = New Query("SELECT
							  |    Count(*) AS Count
							  |FROM
							  |    Catalog.Products AS Products
							  |WHERE
							  |    Products.Ref IN (&ProductsInDocument)
							  |    AND Products.Kind = VALUE(Enum.ProductKinds.Product)");

		Query.SetParameter("ProductsInDocument", Products.UnloadColumn("Product"));
		Selection = Query.Execute().Select();
		Selection.Next();
		If Selection.Count = 0 Then
			// Informing the platform that we have checked the "Warehouse" field filling
			CheckedAttributes.Delete(CheckedAttributes.Find("Warehouse"));
		EndIf;

	EndIf;

EndProcedure

Procedure Filling(FillingData, StandardProcessing)

	If TypeOf(FillingData) = Type("CatalogRef.Counterparties") Then

		QueryByCounterparty = New Query("SELECT
		                                   |	Counterparties.IsFolder,
		                                   |	Counterparties.PriceKind
		                                   |FROM
		                                   |	Catalog.Counterparties AS Counterparties
		                                   |WHERE
		                                   |	Counterparties.Ref = &CounterpartyRef");
		QueryByCounterparty.SetParameter("CounterpartyRef", FillingData);
		Selection = QueryByCounterparty.Execute().Select();
		If Selection.Next() And Selection.IsFolder Then
			Return;
		EndIf;
		
		PriceKind     = Selection.PriceKind;
		Customer = FillingData.Ref;

	ElsIf TypeOf(FillingData) = Type("Structure") Then

		Value = Undefined;

		If FillingData.Property("Customer", Value) Then
			PriceKind = Value.PriceKind;
		EndIf;

	EndIf;

EndProcedure

