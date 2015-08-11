////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS FOR PRINTING THE FORM

Function PrintForm(ObjectsArray, PrintObjects)
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_PayrollSheet";
	
	FirstDocument = True;
	
	For Each CurrentDocument In ObjectsArray Do
		
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		FirstDocument = False;
		
		LineNumberBegin = SpreadsheetDocument.TableHeight + 1;
		
		Query = New Query();
		Query.SetParameter("CurrentDocument", CurrentDocument);
		Query.Text = 
		"SELECT
		|	PayrollSheet.Date AS DocumentDate,
		|	PayrollSheet.AccountingPeriod AS AccountingPeriod,
		|	PayrollSheet.Number,
		|	PayrollSheet.DocumentCurrency,
		|	PayrollSheet.Company.Description AS CompanyPrintedName,
		|	PayrollSheet.Company
		|FROM
		|	Document.PayrollSheet AS PayrollSheet
		|WHERE
		|	PayrollSheet.Ref = &CurrentDocument";
		
		Header = Query.Execute().Select();
		Header.Next();
		
		Query = New Query;
		Query.SetParameter("CurrentDocument",   CurrentDocument);
		Query.SetParameter("AccountingPeriod", EndOfMonth(CurrentDocument.AccountingPeriod));

		Query.Text =
		"SELECT
		|	PayrollSheetEmployees.Employee.Code AS EmployeeNumber,
		|	SUM(PayrollSheetEmployees.PaymentAmount) AS Amount,
		|	PayrollSheetEmployees.Employee.Description AS Surname,
		|	PayrollSheetEmployees.Employee AS Individual,
		|	PayrollSheetEmployees.Employee.Description AS EmployeePresentation
		|FROM
		|	Document.PayrollSheet.Employees AS PayrollSheetEmployees
		|WHERE
		|	PayrollSheetEmployees.Ref = &CurrentDocument
		|
		|GROUP BY
		|	PayrollSheetEmployees.Employee,
		|	PayrollSheetEmployees.Employee.Code,
		|	PayrollSheetEmployees.Employee.Description
		|
		|ORDER BY
		|	EmployeePresentation";
		
		Selection = Query.Execute().Select();

		SpreadsheetDocument.PrintParametersKey = "PRINT_PARAMETERS_PayrollSheet_Template";
		
		Template = _DemoPrintManagement.GetTemplate("Document.PayrollSheet.PF_MXL_Template");
		
		AreaDocumentHeader = Template.GetArea("DocumentHeader");
		AreaHeader          = Template.GetArea("Header");
		AreaDetails         = Template.GetArea("Details");
		FooterArea         = Template.GetArea("Footer");
		
		If Header.DocumentDate < Date('20110101') Then
			DocumentNo = _DemoPayrollAndHRServer.GetNumberForPrinting(Header.Number, Header.Prefix);
		Else
			DocumentNo = ObjectPrefixationClientServer.GetNumberForPrinting(Header.Number, True, True);
		EndIf;		
		
		AreaDocumentHeader.Parameters.CompanyTitle = Header.CompanyPrintedName;
		AreaDocumentHeader.Parameters.DocAmountInWords = _DemoPayrollAndHRServer.GenerateAmountInWords(CurrentDocument.Employees.Total("PaymentAmount"), Header.DocumentCurrency);
		AreaDocumentHeader.Parameters.DocAmount = CurrentDocument.Employees.Total("PaymentAmount");
		AreaDocumentHeader.Parameters.Currency = Header.DocumentCurrency;
		AreaDocumentHeader.Parameters.DocNo = DocumentNo;
		AreaDocumentHeader.Parameters.DocDate = Header.DocumentDate;
		AreaDocumentHeader.Parameters.ReportingPeriodFrom = Header.AccountingPeriod;
		AreaDocumentHeader.Parameters.ReportingPeriodTo = EndOfMonth(Header.AccountingPeriod);
		Heads = _DemoPayrollAndHRServer.CompanyResponsiblePersons(Header.Company, Header.DocumentDate);
		AreaDocumentHeader.Parameters.Fill(Heads);
		
		SpreadsheetDocument.Put(AreaDocumentHeader);
		SpreadsheetDocument.Put(AreaHeader);
			
		CON = 0;
		While Selection.Next() Do
			CON = CON + 1;
			AreaDetails.Parameters.LineNumber = CON;
			AreaDetails.Parameters.Fill(Selection);
			If ValueIsFilled(Selection.Surname) Then
				NAMEANDSURNAME = Selection.Surname;
			EndIf; 
			SpreadsheetDocument.Put(AreaDetails);
		EndDo;
		
		SpreadsheetDocument.Put(FooterArea);
		
		_DemoPrintManagement.SetDocumentPrintArea(SpreadsheetDocument, LineNumberBegin, PrintObjects, CurrentDocument);
	
	EndDo;
	
	SpreadsheetDocument.FitToPage = True;
	
	Return SpreadsheetDocument;
	
EndFunction

// Generates object print forms.
//
// INCOMING:
//  TemplateNames - String - template names separated by commas.
//  ObjectsArray - Array - array of reference to objects to be printed.
//  PrintParameters - Structure - structure of additional printing parameters.
//
// OUTGOING:
//  PrintFormsCollection - Value table - generated spreadsheet documents.
//  OutputParameters - Structure - generated spreadsheet document parameters.
//
Procedure Print(ObjectsArray, PrintParameters, 
	
	PrintFormsCollection, PrintObjects, OutputParameters) Export
	
	OutputParameters.AvailablePrintingByKits = True;
	
	If _DemoPrintManagement.NeedToPrintTemplate(PrintFormsCollection, "Template") Then
		_DemoPrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "Template", "Purchasing sheet", PrintForm(ObjectsArray, PrintObjects));
	EndIf;
	
EndProcedure

Function GetPrintData(Val DocumentsArray, Val TemplateNamesArray) Export
	
	AllObjectsData = New Map;
	AreasDetails = New Map;
	BinaryDataOfLayouts = New Map;
	TemplateTypes = New Map;
	
	Return New Structure("Data, Templates",
							AllObjectsData,
							New Structure("AreasDetails, TemplateTypes, BinaryDataOfLayouts",
											AreasDetails,
											TemplateTypes,
											BinaryDataOfLayouts));
	
EndFunction
