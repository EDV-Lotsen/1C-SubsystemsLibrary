//////////////////////////////////////////////////////////////////////////////// 
// Variables
// 

&AtClient
Var ProductsAddressInStorage;

//////////////////////////////////////////////////////////////////////////////// 
// PROCEDURES AND FUNCTIONS 
// 

// This function returns the price of a certain product for the date according to the price kind
// 
// Parameters: 
//  Date       – Date – the date the price is determined at which.
//  Product  – CatalogRef.Products – product for which the price is defined.
//  PriceKind  – CatalogRef.PriceKinds – the prices kind. 
// 
// Returns: 
//  Number - the goods item price for the date according to a prices kind.
&AtServerNoContext
Function GetProductPrice(Date, Product, PriceKind)
	ProductPrice = InformationRegisters.ProductPrices.GetLast(
		Date, New Structure("Product, PriceKind", Product, PriceKind));
	Return ProductPrice.Price;
EndFunction

// This function returns prices kind for the specific customer
// 
// Parameters: 
//  Customer – CatalogRef.Counterparties – counterparty. 
// 
// Returns: 
//  CatalogRef.PriceKinds - the prices kind for the specified customer.
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

// This function determines whether this is a service or not
&AtServerNoContext
Function IsService(Product)
	
	Return ?(Product.Kind = Enums.ProductKinds.Service, True, False);
	
EndFunction

// This procedure sets goods prices and calculates amounts for each row in
// the Products tabular section.
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
	
	VTPrices = Query.Execute().Unload();
	VTPrices.Indexes.Add("Product");
	For Each Row In Object.Products Do 
		If Row.Price = 0 Or RecalculateForAllProducts Then
			ProductPrice = VTPrices.Find(Row.Product, "Product");
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

// This function places the goods list into the temporary storage and returns the address
&AtServer
Function PutProducts() 
	Return PutToTempStorage(Object.Products.Unload(,"Product,Price,Quantity"), Uuid);
EndFunction	

// This function restores the goods list from the temporary storage
&AtServer
Procedure GetProductsFromStorage(ProductsAddressInStorage)
	Object.Products.Load(GetFromTempStorage(ProductsAddressInStorage));
	RecalculateProductPricesAndAmounts(False);   
EndProcedure	


// This function returns a reference to the current row in the list of goods
// 
// Parameters: 
//  No. 
// 
// Returns: 
//  CatalogRef.Products - the current goods item in the list.
&AtClient
Function GetCurrentRowProducts()
	Return Items.Products.CurrentData;
EndFunction

// This procedure calculates the additional data of the document row
&AtClientAtServerNoContext
Procedure FillAdditionalRowData(Row)
	
	Row.AmountChanged = Row.Amount <> Row.Quantity * Row.Price;
	
EndProcedure


//////////////////////////////////////////////////////////////////////////////// 
// EVENT HANDLERS 
// 

&AtClient
Procedure ProductsProductOnChange(Element)
	Row = GetCurrentRowProducts();
	Row.IsService = IsService(Row.Product);
	Row.Price = GetProductPrice(Object.Date, Row.Product, Object.PriceKind);
	Row.Quantity = ?(Row.IsService OR Row.Quantity = 0, 1, Row.Quantity);
	Row.Amount = Row.Quantity * Row.Price;
	FillAdditionalRowData(Row);
EndProcedure

&AtClient
Procedure CustomerOnChange(Element)
	PriceKind = GetCustomerPriceKind(Object.Customer);
	If Object.PriceKind <> PriceKind Then
		Object.PriceKind = PriceKind;
		If Object.Products.Count() > 0 Then
			RecalculateProductPricesAndAmounts(True);
		EndIf;	
	EndIf;
EndProcedure

&AtClient
Procedure PriceKindOnChange(Element)
	If Object.Products.Count() > 0 Then
		RecalculateProductPricesAndAmounts(True);
	EndIf;	
EndProcedure

&AtClient
Procedure ProductsPriceOnChange(Element)
	Row = GetCurrentRowProducts();
	Row.Amount = Row.Quantity * Row.Price;
	FillAdditionalRowData(Row);
EndProcedure

&AtClient
Procedure ProductsQuantityOnChange(Element) 
	Row = GetCurrentRowProducts();
	Row.Amount = Row.Quantity * Row.Price;
	FillAdditionalRowData(Row);
EndProcedure

&AtClient
Procedure ProductsAmountOnChange(Element)
	Row = GetCurrentRowProducts();
	FillAdditionalRowData(Row);
EndProcedure

// Fill command handler
&AtClient
Procedure FillCommand()
	ProductsAddressInStorage = PutProducts();
	FillParameters = New Structure("DocumentProductURL, PriceKind, Warehouse", ProductsAddressInStorage, Object.PriceKind, Object.Warehouse);
	FillForm = OpenForm("CommonForm.FillForm", FillParameters, ThisObject);
EndProcedure

&AtServer
Procedure RecalculateAtServer()
	Document = FormAttributeToValue("Object");
	Document.Recalculate();
	ValueToFormAttribute(Document, "Object");
	
	For Each Row In Object.Products Do
		
		FillAdditionalRowData(Row);
		
	EndDo
	
EndProcedure

&AtClient
Procedure RecalculateExecute()
	RecalculateAtServer();
EndProcedure

&AtClient
Procedure OrderDeliveryExecute()
	DeliveryParameters = New Structure("DocumentDate", Object.Date);
	OpenForm("Document.ProductExpense.Form.DeliveryRequest", DeliveryParameters);
EndProcedure

&AtClient
Procedure CompanyOnChange(Element)
	
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
	
	// StandardSubsystems.Print
	PrintManagement.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.Print
	
	//StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
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
	
	GetProductsFromStorage(ProductsAddressInStorage);  
	
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
		CurrentControl = Items.Customer;
	EndIf;
EndProcedure

// StandardSubsystems.ObjectAttributeEditProhibition
&AtClient
Procedure Attachable_AllowObjectAttributeEdit()

	ObjectAttributeEditProhibitionClient.AllowObjectAttributeEdit(ThisObject);	

EndProcedure 

// End StandardSubsystems.ObjectAttributeEditProhibition

// StandardSubsystems.Print
&AtClient
Процедура Attachable_ExecutePrintCommand(Command)
	
    PrintManagementClient.RunAttachablePrintCommand(Command, ThisObject, Object);
	
КонецПроцедуры

// End StandardSubsystems.Print

