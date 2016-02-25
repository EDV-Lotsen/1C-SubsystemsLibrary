
// StandardSubsystems.ObjectAttributeEditProhibition

Function GetObjectAttributesToLock() Export

	Result = New Array;
	Result.Add("Number");
	
	Return Result;

EndFunction // GetObjectAttributesToLock()

// End StandardSubsystems.ObjectAttributeEditProhibition

// StandardSubsystems.Print

Процедура AddPrintCommands(PrintCommands) Export
	
	//Product expense
	PrintCommand = PrintCommands.Добавить();
    PrintCommand.PrintManager = "Document.ProductExpense";
    PrintCommand.ID = "ProductExpense";
    PrintCommand.Presentation = NStr("en = 'Warehouse release'");
    PrintCommand.CheckPostingBeforePrint = True;
	
	//Product expense - print immediately
	PrintCommand = PrintCommands.Добавить();
    PrintCommand.PrintManager = "Document.ProductExpense";
    PrintCommand.ID = "ProductExpense";
    PrintCommand.Presentation = NStr("en = 'Warehouse release (skip preview)'");
	PrintCommand.Picture = PictureLib.PrintImmediately;
    PrintCommand.CheckPostingBeforePrint = True;
	PrintCommand.SkipPreview = True;
	
	//Product expense in Adobe PDF format
	PrintCommand = PrintCommands.Добавить();
    PrintCommand.PrintManager = "Document.ProductExpense";
    PrintCommand.ID = "ProductExpense";
    PrintCommand.Presentation = NStr("en = 'Warehouse release in Adobe PDF format'");
	PrintCommand.Picture = PictureLib.PDFFormat;
    PrintCommand.CheckPostingBeforePrint = True;
	PrintCommand.SavingFormat = SpreadsheetDocumentFileType.PDF;
	
	//Delivery request
	PrintCommand = PrintCommands.Добавить();
    PrintCommand.PrintManager = "Document.ProductExpense";
    PrintCommand.ID = "DeliveryRequest";
    PrintCommand.Presentation = NStr("en = 'Delivery form blank'");
    PrintCommand.CheckPostingBeforePrint = True;
	
	//Delivery request - print immediately
	PrintCommand = PrintCommands.Добавить();
    PrintCommand.PrintManager = "Document.ProductExpense";
    PrintCommand.ID = "DeliveryRequest";
    PrintCommand.Presentation = NStr("en = 'Delivery form blank (skip preview)'");
	PrintCommand.Picture = PictureLib.PrintImmediately;
    PrintCommand.CheckPostingBeforePrint = True;
	PrintCommand.SkipPreview = True;
	
	//Delivery request in Adobe PDF format
	PrintCommand = PrintCommands.Добавить();
    PrintCommand.PrintManager = "Document.ProductExpense";
    PrintCommand.ID = "DeliveryRequest";
    PrintCommand.Presentation = NStr("en = 'Delivery form blank in Adobe PDF format'");
	PrintCommand.Picture = PictureLib.PDFFormat;
    PrintCommand.CheckPostingBeforePrint = True;
	PrintCommand.SavingFormat = SpreadsheetDocumentFileType.PDF;
	
	
КонецПроцедуры

Procedure Print(ObjectArray, PrintParameters, PrintFormCollection, PrintObjects, OutputParameters) Export

	MustPrintTemplate = PrintManagement.MustPrintTemplate(PrintFormCollection, "ProductExpense");
    If MustPrintTemplate Then
        PrintManagement.OutputSpreadsheetDocumentToCollection(
		PrintFormCollection,
        "ProductExpense",
        NStr("en = 'Warehouse release'"),
        PrintProductExpense(ObjectArray, PrintObjects),
        ,
        "Document.ProductExpense.PrintTemplate");
	EndIf;
	
	MustPrintTemplate = PrintManagement.MustPrintTemplate(PrintFormCollection, "DeliveryRequest");
    If MustPrintTemplate Then
        PrintManagement.OutputSpreadsheetDocumentToCollection(
		PrintFormCollection,
        "DeliveryRequest",
        NStr("en = 'Delivery form blank'"),
        PrintDeliveryRequest(ObjectArray, PrintObjects),
        ,
        "Document.ProductExpense.DeliveryRequest");
    EndIf;

EndProcedure

Function PrintProductExpense(ObjectArray, PrintObjects) Export

	QueryText = "SELECT
	            |	ProductExpense.Ref AS Ref,
	            |	ProductExpense.Number,
	            |	ProductExpense.Date,
	            |	ProductExpense.Customer,
	            |	ProductExpense.Warehouse,
	            |	ProductExpense.Products.(
	            |		Product,
	            |		Price,
	            |		Quantity,
	            |		Amount
	            |	)
	            |FROM
	            |	Document.ProductExpense AS ProductExpense
	            |WHERE
	            |	ProductExpense.Ref IN(&ObjectArray)
	            |
	            |ORDER BY
	            |	Ref";
				
	Query = New Query(QueryText);
	Query.SetParameter("ObjectArray", ObjectArray);
	
	Header = Query.Execute().Select();
	
	SpreadsheetDocument = New SpreadsheetDocument;
	
	Template = Documents.ProductExpense.GetTemplate("PrintTemplate");
	
	While Header.Next() Do
		
		FirstRowNumber = SpreadsheetDocument.TableHeight + 1;
		
		// Title
		TemplateArea = Template.GetArea("Title");
		SpreadsheetDocument.Put(TemplateArea);
		
		// Header
		TemplateArea = Template.GetArea("Header");
		TemplateArea.Parameters.Fill(Header);
		SpreadsheetDocument.Put(TemplateArea);
		
		// Products
		TemplateArea = Template.GetArea("ProductsHeader");
		SpreadsheetDocument.Put(TemplateArea);
		ProductsArea = Template.GetArea("Products");
		
		ProductTable = Header.Products.Unload();
		
		For Each CurRowProducts In ProductTable Do
			
			ProductsArea.Parameters.Fill(CurRowProducts);
			SpreadsheetDocument.Put(ProductsArea);
			
		EndDo;
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstRowNumber, PrintObjects, Header.Ref);
		
	EndDo;
	
	Return SpreadsheetDocument;

EndFunction // PrintProductExpense()

Function PrintDeliveryRequest(ObjectArray, PrintObjects) Export

	QueryText = "SELECT
	            |	ProductExpense.Ref AS Ref,
	            |	ProductExpense.Date
	            |FROM
	            |	Document.ProductExpense AS ProductExpense
	            |WHERE
	            |	ProductExpense.Ref IN(&ObjectArray)
	            |
	            |ORDER BY
	            |	Ref";
				
	Query = New Query(QueryText);
	Query.SetParameter("ObjectArray", ObjectArray);
	
	Header = Query.Execute().Select();
	
	SpreadsheetDocument = New SpreadsheetDocument;
	
	Template = Documents.ProductExpense.GetTemplate("DeliveryRequest");
	
	While Header.Next() Do
		
		FirstRowNumber = SpreadsheetDocument.TableHeight + 1;
		
		Template.Area("OrderDate").Value = Header.Date;
		SpreadsheetDocument.Put(Template);
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstRowNumber, PrintObjects, Header.Ref);
		
	EndDo;
	
	Return SpreadsheetDocument;

EndFunction // PrintDeliveryRequest()
 

// End StandardSubsystems.Print