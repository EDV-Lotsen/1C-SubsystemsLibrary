&AtServer
Function PrintForm(CommandParameter)
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.ShowGrid = True;
	SpreadsheetDocument.ShowHeaders = True;
	
	Created = False;
	TabTemplate = Catalogs.Products.GetTemplate("PriceListTemplate"); 

	Header = TabTemplate.GetArea("Header");
	SpreadsheetDocument.Put(Header);

	ItemsArea = TabTemplate.GetArea("ItemsArea");
	
	Query = New Query;
    Query.Text =  "SELECT
                    |    Products.Code AS Code,
                    |    Products.Description AS Description,
                    |    Products.SKU AS SKU,
                    |    Products.PictureFile AS Picture,
                    |    Products.Details AS Details,
                    |    Products.Kind AS Kind,
                    |    ProductPrices.Price AS Price
                    |FROM
                    |    InformationRegister.ProductPrices AS ProductPrices
                    |        LEFT JOIN Catalog.Products AS Products
                    |         ON ProductPrices.Product = Products.Ref
                    |WHERE
                    |    Products.IsFolder = FALSE
                    |    AND ProductPrices.PriceKind = &PriceKind
                    |
                    |ORDER  BY
                    |    Kind,
                    |    Products.Parent.Code,
                    |    Code";

    Query.SetParameter("PriceKind", Catalogs.PriceKinds.FindByDescription("Retail"));
						
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		ItemsArea.Parameters.Fill(Selection);
		
		Details = "";
		
		Read = New HTMLReader();
		Read.SetString(Selection.Details);
		
		DocDOM = New DOMBuilder();
		HTML = DocDOM.Read(Read);
		
		If Not HTML.DocumentItem = Undefined Then
			For Each Node In HTML.DocumentItem.ChildNodes Do 
				If Node.NodeName = "body" Then
					For Each DescriptionItem In Node.ChildNodes Do 
						Details = Details + DescriptionItem.TextContent;
					EndDo;
				EndIf;
			EndDo;
		EndIf;
		ItemsArea.Parameters.Details = Details;
		
		If (Selection.Picture <> Null) Then 
			ItemsArea.Parameters.PictureParameter = New Picture(Selection.Picture.FileData.Get());
		EndIf;
		
		SpreadsheetDocument.Put(ItemsArea, Selection.Level());
		Created = True;
	EndDo;
	
	If Created Then
		Return SpreadsheetDocument;
	Else 	
		Return Undefined;
	EndIf;	
EndFunction

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	SpreadsheetDocument = PrintForm(CommandParameter);
	
	If SpreadsheetDocument <> Undefined Then
		SpreadsheetDocument.Show();
	EndIf;	
	
EndProcedure
