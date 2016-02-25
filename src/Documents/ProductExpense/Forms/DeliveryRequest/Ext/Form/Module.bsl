
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	Document = Parameters.Document;
	DocumentDate = Parameters.DocumentDate;
	SpreadsheetDocument = Documents.ProductExpense.GetTemplate("DeliveryRequest");
	SpreadsheetDocument.Area("OrderDate").Value = DocumentDate;
EndProcedure

&AtClient
Procedure SpreadsheetDocumentOnChangeAreaContent(Element, State)
	If State.Name = "DeliveryDate" Then
		SpreadsheetDocument.Area("DeliveryTerms").Value = 
		    Number(SpreadsheetDocument.Area("DeliveryDate").Value - BegOfDay(DocumentDate)) / (24 * 60 * 60);
	ElsIf State.Name = "DeliveryTerms" Then
		SpreadsheetDocument.Area("DeliveryDate").Value = 
		    BegOfDay(DocumentDate) + SpreadsheetDocument.Area("DeliveryTerms").Value * 24 * 60 * 60;
	EndIf	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	Items.SpreadsheetDocument.CurrentArea = SpreadsheetDocument.Area("Address");
EndProcedure

&AtClient
Procedure DocumentBatchPrint(Command)
	Batch = DocumentBatchPrintAtServer();
	Batch.Print(PrintDialogUseMode.Use);
EndProcedure

&AtServer
Function DocumentBatchPrintAtServer()
	Batch = New RepresentableDocumentBatch;
	
	Batch.Content.Add().Data = PutToTempStorage(SpreadsheetDocument, UUID);
	
	ExpenseToPrint = New SpreadsheetDocument;
	Document.GetObject().PrintForm(ExpenseToPrint);
	Batch.Content.Add().Data = PutToTempStorage(ExpenseToPrint, UUID);
	
	Return Batch;
EndFunction