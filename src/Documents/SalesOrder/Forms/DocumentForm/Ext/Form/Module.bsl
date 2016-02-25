//////////////////////////////////////////////////////////////////////////////// 
// Variables
// 

&AtClient
Var ProductAddressInStorage;

//////////////////////////////////////////////////////////////////////////////// 
// PROCEDURES AND FUNCTIONS 
// 

// Returns the product price for the specified date according to the price kind.
// 
// Parameters: 
// Date – Date – date, for which the price is retrieved. 
// Product – CatalogRef.Products – product or service whose price is retrieved. 
// PriceKind – CatalogRef.PriceKinds – price kind. 
// 
// Returns: 
// Number - product or service price for the specified date according to the price kind.
//
&AtServerNoContext
Function GetProductPrice(Date, Product, PriceKind)
	ProductPrice = InformationRegisters.ProductPrices.GetLast(
		Date, New Structure("Product, PriceKind", Product , PriceKind));
	Return ProductPrice.Price;
EndFunction

// Returns the price kind for the specified customer.
// 
// Parameters: 
// Customer – CatalogRef.Counterparties – counterparty. 
// 
// Returns: 
// CatalogRef.PriceKinds - price kind for the specified customer.
//
&AtServerNoContext
Function GetCustomerPriceKind(Customer)
	Query = New Query();
	Query.Text = "SELECT PriceKind FROM Catalog.Counterparties WHERE Ref = &Customer";
	Query.SetParameter("Customer", Customer);
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Return Selection.PriceKind;
	EndIf;
	Return Catalogs.PriceKinds.EmptyRef();
EndFunction

// Determines whether the item is a service.
//
Function IsService(Product)
	
	Return ?(Product.Kind = Enums.ProductKinds.Service, True, False);
	
EndFunction

// Sets item prices and calculates the column count if every column of the Products
// tabular section.
//
&AtServer
Procedure RecalculateProductPricesAndAmounts(RecalculateForAllProducts)
	Query = New Query();
	Query.Text = "SELECT
	               |	ProductPricesSliceLast.Price,
	               |	ProductPricesSliceLast.Product
	               |FROM
	               |	InformationRegister.ProductPrices.SliceLast(
	               |		,
	               |		PriceKind = &PriceKind
	               |			AND Product IN (&Products)) AS ProductPricesSliceLast";
	Query.SetParameter("PriceKind", Object.PriceKind);
	Products = New Array();
	For Each Row In Object.Products Do 
		Products.Add(Row.Product);
	EndDo;
	Query.SetParameter("Products", Products);
	
	PricesVT = Query.Execute().Unload();
	PricesVT.Indexes.Add("Product");
	For Each Row In Object.Products Do 
		If Row.Price = 0 Or RecalculateForAllProducts Then
			ProductPrice = PricesVT.Find(Row.Product, "Product");
			If ProductPrice <> Undefined Then
				Row.Price = ProductPrice.Price;
			Else 	
				Row.Price = 0;
			EndIf;
		EndIf;	
		Row.Amount = Row.Price * Row.Quantity;
		Row.AmountChanged = False;
		Row.IsService = IsService(Row.Product);
	EndDo;
EndProcedure

// Puts the product list into the temporary storage and returns the storage URL. 
//
&AtServer
Function PutProducts() 
	Return PutToTempStorage(Object.Products.Unload(,"Product,Price,Quantity"), UUID);
EndFunction	

// Retrieves the product list from the temporary storage.
//
&AtServer
Procedure GetProductsFromStorage(ProductAddressInStorage)
	Object.Products.Load(GetFromTempStorage(ProductAddressInStorage));
	RecalculateProductPricesAndAmounts(False);   
EndProcedure	


// Returns the reference to the current row of the product list. 
// 
// Returns: 
// CatalogRef.Products - current product in the list.
//
&AtClient
Function GetCurrentRowProducts()
	Return Items.Products.CurrentData;
EndFunction

// Determines the additional data of the document row.
//
&AtClientAtServerNoContext
Procedure FillAdditionalRowData(Row)
	
	Row.AmountChanged = Row.Amount <> Row.Quantity * Row.Price;
	
EndProcedure


//////////////////////////////////////////////////////////////////////////////// 
// EVENT HANDLERS 
// 

&AtClient
Procedure ProductsProductOnChange(Item)
	Row = GetCurrentRowProducts();
	Row.IsService = IsService(Row.Product);
	Row.Price = GetProductPrice(Object.Date, Row.Product, Object.PriceKind);
	Row.Quantity = ?(Row.IsService Or Row.Quantity = 0, 1, Row.Quantity);
	Row.Amount = Row.Quantity * Row.Price;
	FillAdditionalRowData(Row);
EndProcedure

&AtClient
Procedure CustomerOnChange(Item)
	PriceKind = GetCustomerPriceKind(Object.Customer);
	If Object.PriceKind <> PriceKind Then
		Object.PriceKind = PriceKind;
		If Object.Products.Count() > 0 Then
			RecalculateProductPricesAndAmounts(True);
		EndIf;	
	EndIf;
EndProcedure

&AtClient
Procedure PriceKindOnChange(Item)
	If Object.Products.Count() > 0 Then
		RecalculateProductPricesAndAmounts(True);
	EndIf;	
EndProcedure

&AtClient
Procedure ProductsPriceOnChange(Item)
	Row = GetCurrentRowProducts();
	Row.Amount = Row.Quantity * Row.Price;
	FillAdditionalRowData(Row);
EndProcedure

&AtClient
Procedure ProductsQuantityOnChange(Item) 
	Row = GetCurrentRowProducts();
	Row.Amount = Row.Quantity * Row.Price;
	FillAdditionalRowData(Row);
EndProcedure

&AtClient
Procedure ProductsAmountOnChange(Item)
	Row = GetCurrentRowProducts();
	FillAdditionalRowData(Row);
EndProcedure

// Filling handler
&AtClient
Procedure FillCommand()
	ProductAddressInStorage = PutProducts();
	FillParameters = New Structure("DocumentProductURL, PriceKind, Warehouse", ProductAddressInStorage, Object.PriceKind, Object.Warehouse);
	FillForm = OpenForm("CommonForm.FillForm", FillParameters, ThisObject);
EndProcedure

&AtClient
Procedure CompanyOnChange(Item)
	
	OptionsParameters = New Structure("Company", Object.Company);
	SetFormFunctionalOptionParameters(OptionsParameters);
	
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Key.IsEmpty() Then 
		
		OptionsParameters = New Structure("Company", Object.Company);
		SetFormFunctionalOptionParameters(OptionsParameters);
		
	EndIf;
	
	For Each Row In Object.Products Do
		
		FillAdditionalRowData(Row);
		
	EndDo;
	
	// StandardSubsystems.ObjectVersioning
	ObjectVersioning.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.ObjectVersioning
	
	// StandardSubsystems.ObjectAttributeEditProhibition
	ObjectAttributeEditProhibition.LockAttributes(ThisObject);
	// End StandardSubsystems.ObjectAttributeEditProhibition
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	OptionsParameters = New Structure("Company", Object.Company);
	SetFormFunctionalOptionParameters(OptionsParameters);

	For Each Row In Object.Products Do
		
		FillAdditionalRowData(Row);
		Row.IsService = IsService(Row.Product);
		
	EndDo
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	OptionsParameters = New Structure("Company", Object.Company);
	SetFormFunctionalOptionParameters(OptionsParameters);
	
	For Each Row In Object.Products Do
		
		FillAdditionalRowData(Row);
		
	EndDo;
	
	// StandardSubsystems.ObjectAttributeEditProhibition
	ObjectAttributeEditProhibition.LockAttributes(ThisObject);
	// End StandardSubsystems.ObjectAttributeEditProhibition
	
EndProcedure

&AtClient
Procedure ProcessFill() Export
	
	GetProductsFromStorage(ProductAddressInStorage);  
	
EndProcedure

&AtClient
Procedure NewWriteProcessing(NewObject, Source, StandardProcessing)
	If TypeOf(NewObject) = Type("CatalogRef.Counterparties") Then
		Object.Customer = NewObject;
		PriceKind = GetCustomerPriceKind(Object.Customer);
		If Object.PriceKind <> PriceKind Then
			Object.PriceKind = PriceKind;
			If Object.Products.Count() > 0 Then
				RecalculateProductPricesAndAmounts(True);
			EndIf;	
		EndIf;
		CurrentItem = Items.Customer;
	EndIf;
EndProcedure

// StandardSubsystems.ObjectAttributeEditProhibition
&AtClient
Procedure Attachable_AllowObjectAttributeEdit()

	ObjectAttributeEditProhibitionClient.AllowObjectAttributeEdit(ThisObject);	

EndProcedure 

// End StandardSubsystems.ObjectAttributeEditProhibition
