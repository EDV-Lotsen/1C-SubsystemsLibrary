//////////////////////////////////////////////////////////////////////////////// 
// PROCEDURES AND FUNCTIONS
//

// This function returns the purchase price of a certain products item to a date
// 
// Parameters: 
//  Date – Date – the date on which the price should be found. 
//  Product – CatalogRef.Products – the products item, the price should be found for. 
// 
// Returns: 
//  Number - The price of the products item to the specified date.
&AtServerNoContext
Function GetProductPrice(Date, Product)

	PriceKind = Catalogs.PriceKinds.Purchasing;
	ProductPrice = InformationRegisters.ProductPrices.GetLast(
		Date, New Structure("Product, PriceKind", Product, PriceKind));

	Return ProductPrice.Price;

EndFunction

// This function returns a reference to the current row in the list of products
// 
// Parameters: 
//  No. 
// 
// Returns: 
//  CatalogRef.Products - the current products item in the list.
&AtClient
Function GetCurrentRowProducts()
	Return Items.Products.CurrentData;
EndFunction

// The function returns a products item by a barcode
&AtServerNoContext
Function GetProductByBarcode(Barcode)
	Return Catalogs.Products.FindByAttribute("Barcode", Barcode);
EndFunction


// This function adds a products item into the bill of lading or increases count of the existing one.
&AtClient
Function AddProduct(Product)

	Rows = Object.Products.FindRows(New Structure("Product", Product));

	If Rows.Count() > 0 Then

		Element = Rows[0];

	Else

		Element = Object.Products.Add();
		Element.Product = Product;
		Element.Price = GetProductPrice(Object.Date, Product);

	EndIf;

	Element.Quantity = Element.Quantity + 1;
	Element.Amount = Element.Quantity * Element.Price;

	Items.Products.CurrentRow = Element.GetID();
	Items.Products.CurrentItem = Items.Products.ChildItems.ProductsQuantity;
	Items.Products.ChangeRow();

EndFunction

//////////////////////////////////////////////////////////////////////////////// 
// EVENT HANDLERS
//

&AtClient
Procedure ProductsProductOnChange(Element)

	Str = GetCurrentRowProducts();
	Str.Price = GetProductPrice(Object.Date, Str.Product);
	Str.Amount = Str.Quantity * Str.Price;

EndProcedure

&AtClient
Procedure ProductsPriceOnChange(Element)

	Str = GetCurrentRowProducts();
	Str.Amount = Str.Quantity * Str.Price;

EndProcedure

&AtClient
Procedure ProductsQuantityOnChange(Element)

	Str = GetCurrentRowProducts();
	Str.Amount = Str.Quantity * Str.Price;

EndProcedure

&AtClient
Procedure ExternalEvent(Source, Event, Data)
	
	//If Source = BarcodeScannerDriverSource Then
	//	
	//	If IsInputAvailable() Then
	//		Product = GetProductByBarcode(Data);
	//		If Not Product.IsEmpty() Then
	//			AddProduct(Product);
	//		EndIf
	//	EndIf
	//		
	//EndIf

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
	
	SetPrivilegedMode(True);
	ShopEquipmentEnabled = Constants.HandlingShopEquipment.Get();
	SetPrivilegedMode(False);
	
	// StandardSubsystems.ObjectVersioning
	ObjectVersioning.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.ObjectVersioning
	
	// StandardSubsystems.ObjectAttributeEditProhibition
	ObjectAttributeEditProhibition.LockAttributes(ThisObject);
	// End StandardSubsystems.ObjectAttributeEditProhibition
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If ShopEquipmentEnabled Then
		
		HandlingShopEquipment.AttachBarcodeScanner();
		
	EndIf;
		
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	OptionsParameters = New Structure("Company", Object.Company);
	SetFormFunctionalOptionParameters(OptionsParameters);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	OptionsParameters = New Structure("Company", Object.Company);
	SetFormFunctionalOptionParameters(OptionsParameters);
	
	// StandardSubsystems.ObjectAttributeEditProhibition
	ObjectAttributeEditProhibition.LockAttributes(ThisObject);
	// End StandardSubsystems.ObjectAttributeEditProhibition
	
EndProcedure

// StandardSubsystems.ObjectAttributeEditProhibition
&AtClient
Procedure Attachable_AllowObjectAttributeEdit()

	ObjectAttributeEditProhibitionClient.AllowObjectAttributeEdit(ThisObject);	

EndProcedure 

// End StandardSubsystems.ObjectAttributeEditProhibition


