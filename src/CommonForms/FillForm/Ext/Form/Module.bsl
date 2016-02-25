//////////////////////////////////////////////////////////////////////////////// 
// PROCEDURES AND FUNCTIONS 
//       

// Writes the fill result to the storage.
&AtServer
Procedure WriteFillToStorage() 
    
	PutToTempStorage(Products.Unload(), DocumentProductURL);
    
EndProcedure

&AtClient
Procedure AddProduct(Product)
    
	Rows = Products.FindRows(New Structure("Product", Product));
	If Rows.Count() > 0 Then
		CurRow = Rows[0];
		CurRow.Quantity = Rows[0].Quantity + 1;
	Else 
		CurRow = Products.Add();
		CurRow.Product = Product;
		CurRow.Quantity = 1;
	EndIf;	
	
	Items.Products.CurrentRow = CurRow.GetID();
    
EndProcedure

//////////////////////////////////////////////////////////////////////////////// 
// EVENT HANDLERS   
// 

&AtClient
Procedure ProductListValueChoice(Item, Value, StandardProcessing)
    
	StandardProcessing = False;
	AddProduct(Value);
    
EndProcedure
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	Warehouse = Parameters.Warehouse;
	PriceKind = Parameters.PriceKind;
	ProductList.Parameters.SetParameterValue("Warehouse", Warehouse); 
	ProductList.Parameters.SetParameterValue("PriceKind", PriceKind); 
	DocumentProductURL = Parameters.DocumentProductURL;
	Products.Load(GetFromTempStorage(DocumentProductURL));
	
	Rows = New Array;
	If ValueIsFilled(Warehouse) Then
		Rows.Add(NStr("en = 'Warehouse: '"));
		Rows.Add(New FormattedString(Warehouse.Description, StyleFonts.ImportantInformationFont, StyleColors.ImportantInformationTextColor));
	EndIf;
	
	If ValueIsFilled(PriceKind) Then
		If ValueIsFilled(Warehouse) Then
			Rows.Add(" ");
		EndIf;
		
		Rows.Add(NStr("en = 'Price kind: '"));
		Rows.Add(New FormattedString(PriceKind.Description, StyleFonts.ImportantInformationFont, StyleColors.ImportantInformationTextColor));
	EndIf;
	
	PriceKindsAndWarehouse = New FormattedString(Rows);
EndProcedure

&AtClient
Procedure OKExecute()
	WriteFillToStorage();
	FormOwner.ProcessFill();
	Close();
EndProcedure

&AtClient
Procedure ProductTreeOnActivateRow(Item)
	Items.ProductList.CurrentParent = Item.CurrentRow;
EndProcedure

&AtClient
Procedure ProductsDrag(Item, DragParameters, StandardProcessing, String, Field)
	AddProduct(DragParameters.Value);
	StandardProcessing = False;	
EndProcedure

&AtClient
Procedure ProductListDragStart(Item, DragParameters, StandardProcessing)
	Data = Items.ProductList.RowData(DragParameters.Value);
	If Data <> Undefined Then
		StandardProcessing = Not Data.IsFolder;
	EndIf;
EndProcedure

&AtClient
Procedure ProductsCheckDrag(Item, DragParameters, StandardProcessing, String, Field)
	Data = Items.ProductList.RowData(DragParameters.Value);
	If Data <> Undefined And Not Data.IsFolder Then
		StandardProcessing = False;
	EndIf;
EndProcedure
