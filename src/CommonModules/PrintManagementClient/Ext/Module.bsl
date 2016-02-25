////////////////////////////////////////////////////////////////////////////////
// Print subsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// Executes the print command that opens the result in the document print form.
//
// If you pass a structure with *OverrideCopiesUserSetting = True property in PrintParameters,
// the user settings for the number of copies are neither restored nor written.
Procedure ExecutePrintCommand(PrintManagerName, TemplateNames, CommandParameter, FormOwner, PrintParameters = Undefined) Export
	
	// Checking the number of objects
	If Not CheckPassedObjectCount(CommandParameter) Then
		Return;
	EndIf;
	
	// Getting a uniqueness key for the form being opened
	UniquenessKey = String(New UUID);
	
	OpenParameters = New Structure("PrintManagerName,TemplateNames,CommandParameter,PrintParameters");
	OpenParameters.PrintManagerName = PrintManagerName;
	OpenParameters.TemplateNames		 = TemplateNames;
	OpenParameters.CommandParameter	 = CommandParameter;
	OpenParameters.PrintParameters	 = PrintParameters;
	
	// Opening the document print form
	OpenForm("CommonForm.PrintDocuments", OpenParameters, FormOwner, UniquenessKey);
	
EndProcedure

// Executes the print command that outputs the result to the printer
Procedure ExecutePrintToPrinterCommand(PrintManagerName, TemplateNames, CommandParameter, PrintParameters = Undefined) Export

	Var SpreadsheetDocuments, PrintObjects, OutputParameters, Address, PrintObjectsMap, Cancel;
	
	Cancel = False;
	
	// Checking the number of objects
	If Not CheckPassedObjectCount(CommandParameter) Then
		Return;
	EndIf;
	
	OutputParameters = Undefined;
	
	// Generating spreadsheet documents
#If ThickClientOrdinaryApplication Then
	PrintManagementServerCall.GeneratePrintFormsForQuickPrintOrdinaryApplication(
			PrintManagerName, TemplateNames, CommandParameter, PrintParameters,
			Address, PrintObjectsMap, OutputParameters, Cancel);
	If Not Cancel Then
		PrintObjects = New ValueList;
		SpreadsheetDocuments = GetFromTempStorage(Address);
		For Each PrintObject In PrintObjectsMap Do
			PrintObjects.Add(PrintObject.Value, PrintObject.Key);
		EndDo;
	EndIf;
#Else
	PrintManagementServerCall.GeneratePrintFormsForQuickPrint(
			PrintManagerName, TemplateNames, CommandParameter, PrintParameters,
			SpreadsheetDocuments, PrintObjects, OutputParameters, Cancel);
#EndIf
	
	If Cancel Then
		CommonUseClientServer.MessageToUser(NStr("en = 'You have no rights to output the print form to the printer, contact the application administrator.'"));
		Return;
	EndIf;
	
	// Printing
	PrintSpreadsheetDocuments(SpreadsheetDocuments, PrintObjects,
			OutputParameters.PrintBySetsAvailable);
	
EndProcedure

// Outputs spreadsheet documents to the printer.
Procedure PrintSpreadsheetDocuments(SpreadsheetDocuments, PrintObjects, Val Collate = False, Val BatchCopies = 1) Export
	
	RepresentableDocumentBatch = PrintManagementServerCall.DocumentBatch(SpreadsheetDocuments,
		PrintObjects, Collate, BatchCopies);
		
	RepresentableDocumentBatch.Print(PrintDialogUseMode.DontUse);
EndProcedure

// Executes interactive document posting before printing.
// If there are unposted documents, prompts the user to post them. Asks the user whether they want to continue if any of the documents are not posted and at the same time some of the documents are posted.
//
// Parameters:
//  CompletionProcedureDescription - NotifyDescription - procedure that gets the control after the execution.
//                                Parameters of that procedure:
//                                  DocumentList         - Array - posted documents.
//                                  AdditionalParameters - value that was specified when creating the notification object.
//  DocumentList                  - Array            - references to the documents that require posting.
//  Form                          - ManagedForm      - form where the command is called. The parameter is needed to reread the form when the procedure is called from an object form.
Procedure CheckDocumentsPosted(CompletionProcedureDescription, DocumentList, Form = Undefined) Export
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("CompletionProcedureDescription", CompletionProcedureDescription);
	AdditionalParameters.Insert("DocumentList", DocumentList);
	AdditionalParameters.Insert("Form", Form);
	
	UnpostedDocuments = CommonUseServerCall.CheckDocumentsPosted(DocumentList);
	HasUnpostedDocuments = UnpostedDocuments.Count() > 0;
	If HasUnpostedDocuments Then
		AdditionalParameters.Insert("UnpostedDocuments", UnpostedDocuments);
		PrintManagementInternalClient.CheckDocumentsPostedPostingDialog(AdditionalParameters);
	Else
		ExecuteNotifyProcessing(CompletionProcedureDescription, DocumentList);
	EndIf;
	
EndProcedure

// Handler of the dynamically linked print command.
//
// Command  - FormCommand - dinamically linked form command that executes the Attachable_ExecutePrintCommand handler.
//            (alternative call*) Structure    - PrintCommand table row converted into a structure.
// Source - FormTable, FormDataStructure - print object source (Form.Object, Form.Item.List).
//            (alternative call*) Array - print object list.
//
// *Alternative call - these types are used if the call is not performed from the standard Attachable_ExecutePrintCommand handler.
//
Procedure RunAttachablePrintCommand(Val Command, Val Form, Val Source) Export
	
	CommandDescription = Command;
	If TypeOf(Command) = Type("FormCommand") Then
		CommandDescription = PrintCommandDescription(Command.Name, Form.Commands.Find("PrintCommandAddressInTemporaryStorage").Action);
	EndIf;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("CommandDescription", CommandDescription);
	AdditionalParameters.Insert("Form", Form);
	AdditionalParameters.Insert("Source", Source);
	
	If Not CommandDescription.DontWriteInForm And TypeOf(Source) = Type("FormDataStructure")
		And (Source.Ref.IsEmpty() Or Form.Modified) Then
		
		If Source.Ref.IsEmpty() Then
			QuestionText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Data is not written yet.
					|The ""%1"" action is only available after data writing.
					|Data will be recorded.'"),
				CommandDescription.Presentation);
				
			NotifyDescription = New NotifyDescription("RunAttachablePrintCommandConfirmWriting", PrintManagementInternalClient, AdditionalParameters);
			ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.OKCancel);
			Return;
		EndIf;
		PrintManagementInternalClient.RunAttachablePrintCommandConfirmWriting(DialogReturnCode.OK, AdditionalParameters);
		Return;
	EndIf;
	
	PrintManagementInternalClient.RunAttachablePrintCommandConfirmWriting(Undefined, AdditionalParameters);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Operations with office document templates

// The section contains interface functions (API) used for creating print forms based on office 
// documents. Microsoft Office (Word templates) and Open Office (Writer templates) office
// packages are currently supported.
//
// /////////////////////////////////////////////////////////////////////////////
// Used data types (determined by specific implementations):
// RefPrintForm    - reference to a print form. 
// RefTemplate     - reference to a template. 
// Region          - reference to an area in a print form or template (structure), its definition
//                   is completed with internal area data in the interface module.
// AreaDescription - template area description (see below).
// FillingData     - either structure, or array of structures (for lists and tables).
// ///////////////////////////////////////////////////////////////////////////
// AreaDescription - structure that describes template areas prepared by the user 
// key AreaName    - area name
// key AreaType    - 	Header 
//         Footer
//         General
//         TableRow
//         List
//

////////////////////////////////////////////////////////////////////////////////
// Functions for initializing and closing COM connections

// Creates a connection to the output print form.
// Call this function before performing any actions on the form.
// Parameters:
// DocumentType         - String - print form type: "DOC" or "ODT".
// TemplatePageSettings - Map - parameters from the structure returned by the InitTemplate function.
// Template             - Structure - InitTemplate function result.
// 
// Returns:
//  Structure.
// 
// Note: The TemplatePageSettings parameter is obsolete, skip it and use the Template parameter instead.
//
Function InitPrintForm(Val DocumentType, Val TemplatePageSettings = Undefined, Template = Undefined) Export
	
	If Not AttachFileSystemExtension() Then
		Return Undefined;
	EndIf;
	
	If Upper(DocumentType) = "DOC" Then
		Parameter = ?(Template = Undefined, TemplatePageSettings, Template); // For backward compatibility
		PrintForm = PrintManagementMSWordClient.InitPrintFormMSWord(Parameter);
		PrintForm.Insert("Type", "DOC");
		PrintForm.Insert("LastOutputArea", Undefined);
		Return PrintForm;
	ElsIf Upper(DocumentType) = "ODT" Then
		PrintForm = PrintManagementOOWriterClient.InitOOWriterPrintForm(Template);
		PrintForm.Insert("Type", "ODT");
		PrintForm.Insert("LastOutputArea", Undefined);
		Return PrintForm;
	EndIf;
	
EndFunction

// Creates a COM connection to the template. This connection is used later for getting template areas (tags and tables).
//
// Parameters:
//  TemplateBinaryData - BinaryData - template binary data.
//  TemplateType       - String - print form template type: "DOC" or "ODT".
//  TemplateName       - String - name to be used for creating the template temporary file.
// Returns:
//  Structure.
//
Function InitOfficeDocumentTemplate(Val TemplateBinaryData, Val TemplateType, Val TemplateName = "") Export
	
	If Not AttachFileSystemExtension() Then
		ShowMessageBox(, NStr("en = 'The file system extension is not attached. Printing is not available'"));
		Return Undefined;
	EndIf;
	
	Template = Undefined;
	TempFileName = "";
	
	#If WebClient Then
		If IsBlankString(TemplateName) Then
			TempFileName = String(New UUID) + "." + Lower(TemplateType);
		Else
			TempFileName = TemplateName + "." + Lower(TemplateType);
		EndIf;
		
		FileDescriptions = New Array;
		FileDescriptions.Add(New TransferableFileDescription(TempFileName, PutToTempStorage(TemplateBinaryData)));
		
		If Not GetFiles(FileDescriptions, , TempFilesDir(), False) Then
			Return Undefined;
		EndIf;
		
		TempFileName = CommonUseClientServer.AddFinalPathSeparator(TempFilesDir()) + TempFileName;
	#EndIf
	
	If Upper(TemplateType) = "DOC" Then
		Template = PrintManagementMSWordClient.GetMSWordTemplate(TemplateBinaryData, TempFileName);
		Template.Insert("Type", "DOC");
	ElsIf Upper(TemplateType) = "ODT" Then
		Template = PrintManagementOOWriterClient.GetOOWriterTemplate(TemplateBinaryData, TempFileName);
		Template.Insert("Type", "ODT");
		Template.Insert("TemplatePageSettings", Undefined);
	EndIf;
	
	Return Template;
	
EndFunction

// Releases the connection in the created office application connection interface.
// Always call this procedure after the template generation is completed and the print form is 
// displayed to the user.
// Parameters:
// Handler  - RefPrintForm, RefTemplate
// ExitApplication - Boolean - flag that shows whether closing the application is required.
// 				Connection to the template must be closed when the application is closed.
// 				PrintForm does not need closing.
//
Procedure ClearReferences(Handler, Val ExitApplication = True) Export
	
	If Handler <> Undefined Then
		If Handler.Type = "DOC" Then
			PrintManagementMSWordClient.CloseConnection(Handler, ExitApplication);
		Else
			PrintManagementOOWriterClient.CloseConnection(Handler, ExitApplication);
		EndIf;
		Handler = Undefined;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Function that displays the print form to a user

// Displays the generated document to the user
// (technically, sets a visibility flag for the document).
// Parameters:
//  Handler - RefPrintForm.
//
Procedure ShowDocument(Val Handler) Export
	
	If Handler.Type = "DOC" Then
		PrintManagementMSWordClient.ShowMSWordDocument(Handler);
	ElsIf Handler.Type = "ODT" Then
		PrintManagementOOWriterClient.ShowOOWriterDocument(Handler);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Functions for getting template areas, for outputting template areas to print forms, and 
// filling parameters in template areas

// Gets a print form template area.
//
// Parameters:
//   RefToTemplate   - Structure - reference to the template print form.
//   AreaDescription - Structure - area description.
//
// Returns:
//   Structure - template area.
//
Function TemplateArea(Val RefToTemplate, Val AreaDescription) Export
	
	Region = Undefined;
	If RefToTemplate.Type = "DOC" Then
		
		If		AreaDescription.AreaType = "Header" Then
			Region = PrintManagementMSWordClient.GetHeaderArea(RefToTemplate);
		ElsIf	AreaDescription.AreaType = "Footer" Then
			Region = PrintManagementMSWordClient.GetFooterArea(RefToTemplate);
		ElsIf	AreaDescription.AreaType = "General" Then
			Region = PrintManagementMSWordClient.GetMSWordTemplateArea(RefToTemplate, AreaDescription.AreaName, 1, 0);
		ElsIf	AreaDescription.AreaType = "TableRow" Then
			Region = PrintManagementMSWordClient.GetMSWordTemplateArea(RefToTemplate, AreaDescription.AreaName);
		ElsIf	AreaDescription.AreaType = "List" Then
			Region = PrintManagementMSWordClient.GetMSWordTemplateArea(RefToTemplate, AreaDescription.AreaName, 1, 0);
		Else
			Raise
				StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'The area type is not specified or specified incorrectly: %1.'"), AreaDescription.AreaType);
		EndIf;
		
		If Region <> Undefined Then
			Region.Insert("AreaDescription", AreaDescription);
		EndIf;
	ElsIf RefToTemplate.Type = "ODT" Then
		
		If		AreaDescription.AreaType = "Header" Then
			Region = PrintManagementOOWriterClient.GetHeaderArea(RefToTemplate);
		ElsIf	AreaDescription.AreaType = "Footer" Then
			Region = PrintManagementOOWriterClient.GetFooterArea(RefToTemplate);
		ElsIf	AreaDescription.AreaType = "General"
				Or AreaDescription.AreaType = "TableRow"
				Or AreaDescription.AreaType = "List" Then
			Region = PrintManagementOOWriterClient.GetTemplateArea(RefToTemplate, AreaDescription.AreaName);
		Else
			Raise
				StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'The area type is not specified or specified incorrectly: %1.'"), AreaDescription.AreaName);
		EndIf;
		
		If Region <> Undefined Then
			Region.Insert("AreaDescription", AreaDescription);
		EndIf;
	EndIf;
	
	Return Region;
	
EndFunction

// Attaches an area from a template to a print form.
// The procedure is used during the output of a single area.
//
// Parameters:
// PrintForm      - RefPrintForm - reference to a print form. 
// TemplateArea   - Region - template area. 
// MoveToNextLine - Boolean, shows whether a line break is added after outputting the area.
//
Procedure PutArea(Val PrintForm,
							  Val TemplateArea,
							  Val MoveToNextLine = True) Export
							  
	If TemplateArea = Undefined Then
		Return;						  
	EndIf; 
								  
	Try
		AreaDescription = TemplateArea.AreaDescription;
		
		If PrintForm.Type = "DOC" Then
			
			OutputArea = Undefined;
			
			If		AreaDescription.AreaType = "Header" Then
				PrintManagementMSWordClient.AddHeader(PrintForm, TemplateArea);
			ElsIf	AreaDescription.AreaType = "Footer" Then
				PrintManagementMSWordClient.AddFooter(PrintForm, TemplateArea);
			ElsIf	AreaDescription.AreaType = "General" Then
				OutputArea = PrintManagementMSWordClient.PutArea(PrintForm, TemplateArea, MoveToNextLine);
			ElsIf	AreaDescription.AreaType = "List" Then
				OutputArea = PrintManagementMSWordClient.PutArea(PrintForm, TemplateArea, MoveToNextLine);
			ElsIf	AreaDescription.AreaType = "TableRow" Then
				If PrintForm.LastOutputArea <> Undefined
				   And PrintForm.LastOutputArea.AreaType = "TableRow"
				   And Not PrintForm.LastOutputArea.MoveToNextLine Then
					OutputArea = PrintManagementMSWordClient.PutArea(PrintForm, TemplateArea, MoveToNextLine, True);
				Else
					OutputArea = PrintManagementMSWordClient.PutArea(PrintForm, TemplateArea, MoveToNextLine);
				EndIf;
			Else
				Raise(NStr("en = 'The area type is not specified or specified incorrectly.'"));
			EndIf;
			
			AreaDescription.Insert("Area", OutputArea);
			AreaDescription.Insert("MoveToNextLine", MoveToNextLine);
			
			PrintForm.LastOutputArea = AreaDescription; // Contains the area type and the area borders (if required)
			
		ElsIf PrintForm.Type = "ODT" Then
			If		AreaDescription.AreaType = "Header" Then
				PrintManagementOOWriterClient.AddHeader(PrintForm, TemplateArea);
			ElsIf	AreaDescription.AreaType = "Footer" Then
				PrintManagementOOWriterClient.AddFooter(PrintForm, TemplateArea);
			ElsIf	AreaDescription.AreaType = "General"
					Or AreaDescription.AreaType = "List" Then
				PrintManagementOOWriterClient.SetMainCursorToDocumentBody(PrintForm);
				PrintManagementOOWriterClient.PutArea(PrintForm, TemplateArea, MoveToNextLine);
			ElsIf	AreaDescription.AreaType = "TableRow" Then
				PrintManagementOOWriterClient.SetMainCursorToDocumentBody(PrintForm);
				PrintManagementOOWriterClient.PutArea(PrintForm, TemplateArea, MoveToNextLine, True);
			Else
				Raise(NStr("en = 'The area type is not specified or specified incorrectly'"));
			EndIf;
			PrintForm.LastOutputArea = AreaDescription; // Contains the area type and the area borders (if required)
		EndIf;
	Except
		ErrorMessage = TrimAll(BriefErrorDescription(ErrorInfo()));
		ErrorMessage = ?(Right(ErrorMessage, 1) = ".", ErrorMessage, ErrorMessage + ".");
		ErrorMessage = ErrorMessage + " " +
				StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'Error outputting the ""%1"" template area.'"),
					TemplateArea.AreaDescription.AreaName);
		Raise ErrorMessage;
	EndTry;
	
EndProcedure

// Fills the parameters of the print form area.
//
// Parameters:
// PrintForm	- RefPrintForm, Area - print form area or the print form itself. 
// Data      - FillingData.
//
Procedure FillParameters(Val PrintForm, Val Data) Export
	
	AreaDescription = PrintForm.LastOutputArea;
	
	If PrintForm.Type = "DOC" Then
		If		AreaDescription.AreaType = "Header" Then
			PrintManagementMSWordClient.FillHeaderParameters(PrintForm, Data);
		ElsIf	AreaDescription.AreaType = "Footer" Then
			PrintManagementMSWordClient.FillFooterParameters(PrintForm, Data);
		ElsIf	AreaDescription.AreaType = "General"
				Or AreaDescription.AreaType = "TableRow"
				Or AreaDescription.AreaType = "List" Then
			PrintManagementMSWordClient.FillParameters(PrintForm.LastOutputArea.Region, Data);
		Else
			Raise(NStr("en = 'The area type is not specified or specified incorrectly'"));
		EndIf;
	ElsIf PrintForm.Type = "ODT" Then
		If		PrintForm.LastOutputArea.AreaType = "Header" Then
			PrintManagementOOWriterClient.SetMainCursorOnHeader(PrintForm);
		ElsIf	PrintForm.LastOutputArea.AreaType = "Footer" Then
			PrintManagementOOWriterClient.SetMainCursorToFooter(PrintForm);
		ElsIf	AreaDescription.AreaType = "General"
				Or AreaDescription.AreaType = "TableRow"
				Or AreaDescription.AreaType = "List" Then
			PrintManagementOOWriterClient.SetMainCursorToDocumentBody(PrintForm);
		EndIf;
		PrintManagementOOWriterClient.FillParameters(PrintForm, Data);
	EndIf;
	
EndProcedure

// Adds an area from a template to a print form, replacing the area parameters with the values
// from the object data.
// The procedure is used during the output of a single area.
//
// Parameters:
// PrintForm      - RefPrintForm.
// TemplateArea   - Area.
// Data           - ObjectData.
// MoveToNextLine - Boolean, shows whether a line break is added after outputting the area.
//
Procedure PutAreaAndFillParameters(Val PrintForm,
										Val TemplateArea,
										Val Data,
										Val MoveToNextLine = True) Export
																			
	If TemplateArea <> Undefined Then
		PutArea(PrintForm, TemplateArea, MoveToNextLine);
		FillParameters(PrintForm, Data)
	EndIf;
	
EndProcedure

// Adds an area from a template to a print form, replacing the area parameters with the values 
// from the object data.
// The procedure is used during the output of a single area.
//
// Parameters
// PrintForm      - RefPrintForm.
// TemplateArea   - Area - template area.
// Data           - ObjectData (array of structures).
// MoveToNextLine - Boolean, shows whether a line break is added after outputting the area.
//
Procedure JoinAndFillCollection(Val PrintForm,
										Val TemplateArea,
										Val Data,
										Val MoveToNextLine = True) Export
	If TemplateArea = Undefined Then
		Return;
	EndIf;
	
	AreaDescription = TemplateArea.AreaDescription;
	
	If PrintForm.Type = "DOC" Then
		If		AreaDescription.AreaType = "TableRow" Then
			PrintManagementMSWordClient.JoinAndFillTableArea(PrintForm, TemplateArea, Data, MoveToNextLine);
		ElsIf	AreaDescription.AreaType = "List" Then
			PrintManagementMSWordClient.JoinAndFillSet(PrintForm, TemplateArea, Data, MoveToNextLine);
		Else
			Raise(NStr("en = 'The area type is not specified or specified incorrectly'"));
		EndIf;
	ElsIf PrintForm.Type = "ODT" Then
		If		AreaDescription.AreaType = "TableRow" Then
			PrintManagementOOWriterClient.JoinAndFillCollection(PrintForm, TemplateArea, Data, True, MoveToNextLine);
		ElsIf	AreaDescription.AreaType = "List" Then
			PrintManagementOOWriterClient.JoinAndFillCollection(PrintForm, TemplateArea, Data, False, MoveToNextLine);
		Else
			Raise(NStr("en = 'The area type is not specified or specified incorrectly'"));
		EndIf;
	EndIf;
	
EndProcedure

// Inserts a line break as a newline character.
// Parameters:
// PrintForm - RefPrintForm.
//
Procedure InsertBreakAtNewLine(Val PrintForm) Export
	
	If	  PrintForm.Type = "DOC" Then
		PrintManagementMSWordClient.InsertBreakAtNewLine(PrintForm);
	ElsIf PrintForm.Type = "ODT" Then
		PrintManagementOOWriterClient.InsertBreakAtNewLine(PrintForm);
	EndIf;
	
EndProcedure

// Obsolete. Use TemplateArea instead.
//
Function GetArea(Val RefTemplate, Val AreaDescription) Export
	
	Return TemplateArea(RefTemplate, AreaDescription);
	
EndFunction

#EndRegion

#Region InternalProceduresAndFunctions

// Before the implementation of a print command, check whether at least one object is passed, 
// as an empty array can be passed to a command that accepts multiple objects.
Function CheckPassedObjectCount(CommandParameter)
	
	If TypeOf(CommandParameter) = Type("Array") And CommandParameter.Count() = 0 Then
		Return False;
	Else
		Return True;
	EndIf;
	
EndFunction

// Returns a command description by form item name.
// 
// See PrintManagement.PrintCommandDescription.
//
Function PrintCommandDescription(CommandName, PrintCommandAddressInTemporaryStorage)
	
	Return PrintManagementClientCached.PrintCommandDescription(CommandName, PrintCommandAddressInTemporaryStorage);
	
EndFunction

#EndRegion