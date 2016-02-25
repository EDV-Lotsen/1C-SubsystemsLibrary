// StandardSubsystems.Print

Процедура AddPrintCommands(PrintCommands) Export
	
	//Product expense
	PrintCommand = PrintCommands.Добавить();
    PrintCommand.PrintManager = "Catalog.Products";
    PrintCommand.ID = "BarcodePrintTemplate";
    PrintCommand.Presentation = NStr("en = 'Barcode'");
    PrintCommand.CheckPostingBeforePrint = True;
	
	//Product expense - print immediately
	PrintCommand = PrintCommands.Добавить();
    PrintCommand.PrintManager = "Catalog.Products";
    PrintCommand.ID = "BarcodePrintTemplate";
    PrintCommand.Presentation = NStr("en = 'Barcode (skip preview)'");
	PrintCommand.Picture = PictureLib.PrintImmediately;
    PrintCommand.CheckPostingBeforePrint = True;
	PrintCommand.SkipPreview = True;
	
	//Product expense in Adobe PDF format
	PrintCommand = PrintCommands.Добавить();
    PrintCommand.PrintManager = "Catalog.Products";
    PrintCommand.ID = "BarcodePrintTemplate";
    PrintCommand.Presentation = NStr("en = 'Barcode in Adobe PDF format'");
	PrintCommand.Picture = PictureLib.PDFFormat;
    PrintCommand.CheckPostingBeforePrint = True;
	PrintCommand.SavingFormat = SpreadsheetDocumentFileType.PDF;
	
	//Delivery request
	PrintCommand = PrintCommands.Добавить();
    PrintCommand.PrintManager = "Catalog.Products";
    PrintCommand.ID = "PriceListTemplate";
    PrintCommand.Presentation = NStr("en = 'Price list'");
    PrintCommand.CheckPostingBeforePrint = True;
	
	//Delivery request - print immediately
	PrintCommand = PrintCommands.Добавить();
    PrintCommand.PrintManager = "Catalog.Products";
    PrintCommand.ID = "PriceListTemplate";
    PrintCommand.Presentation = NStr("en = 'Price list (skip preview)'");
	PrintCommand.Picture = PictureLib.PrintImmediately;
    PrintCommand.CheckPostingBeforePrint = True;
	PrintCommand.SkipPreview = True;
	
	//Delivery request in Adobe PDF format
	PrintCommand = PrintCommands.Добавить();
    PrintCommand.PrintManager = "Catalog.Products";
    PrintCommand.ID = "PriceListTemplate";
    PrintCommand.Presentation = NStr("en = 'Price list in Adobe PDF format'");
	PrintCommand.Picture = PictureLib.PDFFormat;
    PrintCommand.CheckPostingBeforePrint = True;
	PrintCommand.SavingFormat = SpreadsheetDocumentFileType.PDF;
	
	
КонецПроцедуры

Procedure Print(ObjectArray, PrintParameters, PrintFormCollection, PrintObjects, OutputParameters) Export

	MustPrintTemplate = PrintManagement.MustPrintTemplate(PrintFormCollection, "BarcodePrintTemplate");
	If MustPrintTemplate Then
	    PrintManagement.OutputSpreadsheetDocumentToCollection(
		PrintFormCollection,
	    "BarcodePrintTemplate",
	    NStr("en = 'Barcode'"),
	    PrintBarcode(ObjectArray, PrintObjects),
	    ,
	    "Catalog.Products.BarcodePrintTemplate");
	EndIf;
	
	MustPrintTemplate = PrintManagement.MustPrintTemplate(PrintFormCollection, "PriceListTemplate");
	If MustPrintTemplate Then
	    PrintManagement.OutputSpreadsheetDocumentToCollection(
		PrintFormCollection,
	    "PriceListTemplate",
	    NStr("en = 'Price list'"),
	    PrintPriceList(ObjectArray, PrintObjects),
	    ,
	    "Catalog.Products.PriceListTemplate");
	EndIf;

EndProcedure

Function PrintBarcode(ObjectArray, PrintObjects)

	QueryText = "SELECT
	            |	Products.Ref
	            |FROM
	            |	Catalog.Products AS Products
	            |WHERE
	            |	Products.Ref IN(&ObjectArray)";
				
	Query = New Query(QueryText);
	Query.SetParameter("ObjectArray", ObjectArray);
	
	Header = Query.Execute().Select();
	
	SpreadsheetDocument = New SpreadsheetDocument;
	
	Template = Catalogs.Products.GetTemplate("BarcodePrintTemplate");
	
	While Header.Next() Do
		
		FirstRowNumber = SpreadsheetDocument.TableHeight + 1;
		
		Object = Header.Ref.GetObject();
		Object.BarcodePrintForm(SpreadsheetDocument);
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstRowNumber, PrintObjects, Header.Ref);
		
	EndDo;
	
	Return SpreadsheetDocument;	

EndFunction // PrintBarcode()

Function PrintPriceList(ObjectArray, PrintObjects)

	QueryText = "SELECT
	            |	Products.Ref
	            |FROM
	            |	Catalog.Products AS Products
	            |WHERE
	            |	Products.Ref IN(&ObjectArray)";
				
	Query = New Query(QueryText);
	Query.SetParameter("ObjectArray", ObjectArray);
	
	Header = Query.Execute().Select();
	
    Query.Text =  "SELECT
                  |	Products.Code AS Code,
                  |	Products.Description AS Description,
                  |	Products.SKU AS SKU,
                  |	Products.PictureFile AS Picture,
                  |	Products.Details AS Details,
                  |	Products.Kind AS Kind,
                  |	ProductPrices.Price AS Price,
                  |	Products.Ref
                  |FROM
                  |	Catalog.Products AS Products
                  |		LEFT JOIN InformationRegister.ProductPrices AS ProductPrices
                  |		ON Products.Ref = ProductPrices.Product
                  |WHERE
                  |	Products.IsFolder = FALSE
                  |	AND ProductPrices.PriceKind = &PriceKind
                  |	AND Products.Ref IN(&ObjectArray)
                  |
                  |ORDER BY
                  |	Kind,
                  |	Products.Parent.Code,
                  |	Code";

    Query.SetParameter("PriceKind", Catalogs.PriceKinds.FindByDescription("Retail"));
						
	Selection = Query.Execute().Select();
	
	SpreadsheetDocument = New SpreadsheetDocument;
	
	Template = Catalogs.Products.GetTemplate("PriceListTemplate");
	
	SpreadsheetDocument.Put(Template.GetArea("Header"));
	
	While Header.Next() Do
		
		FirstRowNumber = SpreadsheetDocument.TableHeight + 1;
		
		Selection.Reset();
		
		TemplArea = Template.GetArea("ItemsArea");
		
		While Selection.FindNext(New Structure("Ref", Header.Ref)) Do
			TemplArea.Parameters.Fill(Selection);
		    SpreadsheetDocument.Put(TemplArea);
		EndDo; 
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstRowNumber, PrintObjects, Header.Ref);
		
	EndDo;
	
	Return SpreadsheetDocument;	

EndFunction // PrintPriceList()

// End StandardSubsystems.Print