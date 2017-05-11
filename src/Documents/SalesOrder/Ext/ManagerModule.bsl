﻿
////////////////////////////////////////////////////////////////////////////////
// Sales Order: Manager module
//
////////////////////////////////////////////////////////////////////////////////
// DOCUMENT POSTING

// Collect document data for posting on the server (in terms of document)
Function PrepareDataStructuresForPosting(DocumentRef, AdditionalProperties, RegisterRecords) Export
	
	// Create list of posting tables (according to the list of registers)
	TablesList = New Structure;
	
	// Create a query to request document data
	Query = New Query;
	Query.SetParameter("Ref", DocumentRef);
	
	// Query for document's tables
	Query.Text  = Query_OrdersStatuses(TablesList) +
	              Query_OrdersRegistered(TablesList);
	QueryResult = Query.ExecuteBatch();
	
	// Save documents table in posting parameters
	For Each DocumentTable In TablesList Do
		AdditionalProperties.Posting.PostingTables.Insert(DocumentTable.Key, QueryResult[DocumentTable.Value].Unload());
	EndDo;
	
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
	"SELECT
	// ------------------------------------------------------
	// Standard Attributes
	|	Document.Ref                          AS Recorder,
	|	Document.Date                         AS Period,
	|	1                                     AS LineNumber,
	|	True								  AS Active,
	// ------------------------------------------------------
	// Dimensions
	|	Document.Ref                          AS Order,
	// ------------------------------------------------------
	// Resources
	|	VALUE(Enum.OrderStatuses.Open)        AS Status
	// ------------------------------------------------------
	// Attributes
	// ------------------------------------------------------
	|FROM
	|	Document.SalesOrder AS Document
	|WHERE
	|	Document.Ref = &Ref";
	
	Return QueryText + _DemoDocumentPosting.GetDelimiterOfBatchQuery();
	
EndFunction

// Query for document data
Function Query_OrdersRegistered(TablesList)

	// Add OrdersRegistered table to document structure
	TablesList.Insert("Table_OrdersRegistered", TablesList.Count());
	
	// Collect orders registered data
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
	|	LineItems.Ref                         AS Order,
	|	LineItems.Item                     AS Item,
	// ------------------------------------------------------
	// Resources
	|	LineItems.Quantity                    AS Quantity,
	|	0                                     AS Shipped,
	|	0                                     AS Invoiced,
	// ------------------------------------------------------
	// Attributes
	|	LineItems.Ref.PromisedDate            AS DeliveryDate
	// ------------------------------------------------------
	|FROM
	|	Document.SalesOrder.LineItems AS LineItems
	|WHERE
	|	LineItems.Ref = &Ref
	|ORDER BY
	|	LineNumber";
	
	Return QueryText + _DemoDocumentPosting.GetDelimiterOfBatchQuery();
	
EndFunction

// Put an array of registers, which balance should be checked during posting
Procedure FillRegistersCheckList(AdditionalProperties, RegisterRecords)

	// Create structure of registers and its resources to check balances
	BalanceCheck = New Structure;
		
	// Fill structure depending on document write mode
	If AdditionalProperties.Posting.WriteMode = DocumentWriteMode.Posting Then
		
		// Add resources for check changes in recordset
		CheckPostings = New Array;
		CheckPostings.Add("{Table}.Quantity{Posting}, <, 0"); // Check decreasing quantity
		
		// Add resources for check register balances
		CheckBalances = New Array;
		CheckBalances.Add("{Table}.Quantity{Balance}, <, {Table}.Shipped{Balance}");  // Check over-shipping balance
		CheckBalances.Add("{Table}.Quantity{Balance}, <, {Table}.Invoiced{Balance}"); // Check over-invoiced balance
		
		// Add messages for different error situations
		CheckMessages = New Array;
		CheckMessages.Add(NStr("en = '{Item}:
		                             |Order quantity {Quantity} is lower then shipped quantity {Shipped}'"));   // Over-shipping balance
		CheckMessages.Add(NStr("en = '{Item}:
		                             |Order quantity {Quantity} is lower then invoiced quantity {Invoiced}'")); // Over-invoiced balance
									 
		// Add register to check it's recordset changes and balances during posting
		BalanceCheck.Insert("OrdersRegistered", New Structure("CheckPostings, CheckBalances, CheckMessages", CheckPostings, CheckBalances, CheckMessages));
		
	ElsIf AdditionalProperties.Posting.WriteMode = DocumentWriteMode.UndoPosting Then
		
		// Add resources for check the balances
		CheckPostings = New Array;
		CheckPostings.Add("{Table}.Quantity{Posting},  <, 0"); // Check decreasing quantity
		
		// Add resources for check register balances
		CheckBalances = New Array;
		CheckBalances.Add("{Table}.Quantity{Balance}, <, {Table}.Shipped{Balance}");  // Check over-shipping balance
		CheckBalances.Add("{Table}.Quantity{Balance}, <, {Table}.Invoiced{Balance}"); // Check over-invoiced balance
		
		// Add messages for different error situations
		CheckMessages = New Array;
		CheckMessages.Add(NStr("en = '{Item}:
		                             |{Shipped} items already shipped'"));    // Over-shipping balance
		CheckMessages.Add(NStr("en = '{Item}:
		                             |{Invoiced} items already invoiced'"));  // Over-invoiced balance
		
		// Add registers to check it's recordset changes and balances during undo posting
		BalanceCheck.Insert("OrdersRegistered", New Structure("CheckPostings, CheckBalances, CheckMessages", CheckPostings, CheckBalances, CheckMessages));
		
	EndIf;

	// Return structure of registers to check
	If BalanceCheck.Count() > 0 Then
		AdditionalProperties.Posting.Insert("BalanceCheck", BalanceCheck);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// DOCUMENT PRINTING (OLD)

Procedure Print(ObjectArray, PrintParameters, PrintFormsCollection,
           PrintObjects, OutputParameters) Export

     // Setting the kit printing option.
     OutputParameters.AvailablePrintingByKits = True;

     // Checking if a spreadsheet document generation needed for the Sales Order template.
    If _DemoPrintManagement.NeedToPrintTemplate(PrintFormsCollection, "SalesOrder") Then

         // Generating a spreadsheet document and adding it into the print form collection.
         _DemoPrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection,
             "SalesOrder", "Sales order", PrintTemplate(ObjectArray, PrintObjects));

	EndIf;

		 
EndProcedure
	 
Function PrintTemplate(ObjectArray, PrintObjects)
	
	// Create a spreadsheet document and set print parameters.
   SpreadsheetDocument = New SpreadsheetDocument;
   SpreadsheetDocument.PrintParametersName = "PrintParameters_SalesOrder";

   // Quering necessary data.
   Query = New Query();
   Query.Text =
   "SELECT
   |	SalesOrder.Ref,
   |	SalesOrder.Counterparty,
   |	SalesOrder.Date,
   |	SalesOrder.DocumentTotal,
   |	SalesOrder.SalesTax,
   |	SalesOrder.PriceIncludesVAT,
   |	SalesOrder.Number,
   |	SalesOrder.ShipTo,
   |	SalesOrder.Currency,
   |	SalesOrder.VATTotal,
   |	SalesOrder.LineItems.(
   |		Item,
   |		ItemDescription,
   |		Item.Units AS Units,
   |		Quantity,
   |		VATCode,
   |		VAT,
   |		Price,
   |		LineTotal
   |	)
   |FROM
   |	Document.SalesOrder AS SalesOrder
   |WHERE
   |	SalesOrder.Ref IN(&ObjectArray)";
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

	 
	Template = _DemoPrintManagement.GetTemplate("Document.SalesOrder.PF_MXL_SalesOrder");
	 
	TemplateArea = Template.GetArea("Header");
	 
	UsBill = _DemoPrintTemplates.ContactInfoDataset(Us, "UsBill", Catalogs.Addresses.EmptyRef());
	ThemShip = _DemoPrintTemplates.ContactInfoDataset(Selection.Counterparty, "ThemShip", Selection.ShipTo);
	ThemBill = _DemoPrintTemplates.ContactInfoDataset(Selection.Counterparty, "ThemBill", Catalogs.Addresses.EmptyRef());
	
	TemplateArea.Parameters.Fill(UsBill);
	TemplateArea.Parameters.Fill(ThemShip);
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