////////////////////////////////////////////////////////////////////////////////
// Print subsystem.
//
////////////////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////////////////
// Printing using templates in Microsoft Word format
//
// Data structure descriptions:
//
// Handler - structure used for connecting to COM objects:
//  - COMConnection - COMObject.
//  - Type - String - either "DOC" or "ODT".
//  - FileName - String - template file name (filled only for the template).
//  - LastOutputType - type of the last output area (see AreaType).
//
// Document area:
//  - COMConnection - COMObject.
//  - Type - String - either "DOC" or "ODT".
//  - Start - area beginning position.
//  - End - area end position.
//

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS    

// Creates a COM connection to a Word.Application COM object, creates a single document in it.
//
Function InitPrintFormMSWord(Template) Export
	
	Handler = New Structure("Type", "DOC");
	
	Try
		COMObject = New COMObject("Word.Application");
	Except
		EventLogOperationsClient.AddMessageForEventLog(EventLogMessageText(), "Error",
			DetailErrorDescription(ErrorInfo()),,True);
		FailedToGeneratePrintForm(ErrorInfo());
	EndTry;
	
	Handler.Insert("COMConnection", COMObject);
	Try
		COMObject.Documents.Add();
	Except
		COMObject.Quit(0);
		COMObject = 0;
		EventLogOperationsClient.AddMessageForEventLog(EventLogMessageText(), "Error",
			DetailErrorDescription(ErrorInfo()),,True);
		FailedToGeneratePrintForm(ErrorInfo());
	EndTry;
	

	TemplatePageSettings = Template; // For backward compatibility (the type of the function input parameter is changed)
	If TypeOf(Template) = Type("Structure") Then
		TemplatePageSettings = Template.TemplatePageSettings;
		// Copying styles from the template
		Template.COMConnection.ActiveDocument.Close();
		Handler.COMConnection.ActiveDocument.CopyStylesTemplateFromclauseclauseClause(Template.FileName);
		Template.COMConnection.Documents.Open(Template.FileName);
	EndIf;
	
	// Copying page settings
	If TemplatePageSettings <> Undefined Then
		For Each Settings In TemplatePageSettings Do
			Try
				COMObject.ActiveDocument.PageSetup[Settings.Key] = Settings.Value;
			Except
				// Skipping if the settings are not supported by this application version.
			EndTry;
		EndDo;
	EndIf;
	// Remembering the document view type
	Handler.Insert("ViewType", COMObject.Application.ActiveWindow.View.Type);	
	
	Return Handler;
	
EndFunction

// Creates a COM connection to a Word.Application COM object and
// opens a template in it. The template file is saved based on the binary data passed in the 
// function parameters.
//
// Parameters:
// TemplateBinaryData - BinaryData - template binary data.
// Returns:
// Structure - template reference.
//
Function GetMSWordTemplate(Val TemplateBinaryData, Val TempFileName = "") Export
	
	Handler = New Structure("Type", "DOC");
	Try
		COMObject = New COMObject("Word.Application");
	Except
		EventLogOperationsClient.AddMessageForEventLog(EventLogMessageText(), "Error",
			DetailErrorDescription(ErrorInfo()),,True);
		FailedToGeneratePrintForm(ErrorInfo());
	EndTry;
	
#If Not WebClient Then
	TempFileName = GetTempFileName("DOC");
	TemplateBinaryData.Write(TempFileName);
#EndIf
	
	Try
		COMObject.Documents.Open(TempFileName);
	Except
		COMObject.Quit(0);
		COMObject = 0;
		DeleteFiles(TempFileName);
		EventLogOperationsClient.AddMessageForEventLog(EventLogMessageText(), "Error",
			DetailErrorDescription(ErrorInfo()),,True);
		Raise(NStr("en = 'Error opening the template file.'") + Chars.LF 
			+ BriefErrorDescription(ErrorInfo()));
	EndTry;
	
	Handler.Insert("COMConnection", COMObject);
	Handler.Insert("FileName", TempFileName);
	Handler.Insert("IsTemplate", True);
	
	Handler.Insert("TemplatePageSettings", New Map);
	
	For Each SettingName In PageParameterSettings() Do
		Try
			Handler.TemplatePageSettings.Insert(SettingName, COMObject.ActiveDocument.PageSetup[SettingName]);
		Except
			// Skipping if the settings are not supported by this application version.
		EndTry;
	EndDo;
	
	Return Handler;
	
EndFunction

// Closes the connection to the Word.Application COM object.
// Parameters:
// Handler - reference to a print form or a template. 
// ExitApplication - Boolean - shows whether the application should be closed.
//
Procedure CloseConnection(Handler, Val ExitApplication) Export
	
	If ExitApplication Then
		Handler.COMConnection.Quit(0);
	EndIf;
	
	Handler.COMConnection = 0;
	
	#If Not WebClient Then
	If Handler.Property("FileName") Then
		DeleteFiles(Handler.FileName);
	EndIf;
	#EndIf
	
EndProcedure

// Sets the visibility property for the Microsoft Word application. 
// Handler - reference to a print form.
//
Procedure ShowMSWordDocument(Val Handler) Export
	
	COMConnection = Handler.COMConnection;
	COMConnection.Application.Selection.Collapse();
	
	// Restoring the document view type
	If Handler.Property("ViewType") Then
		COMConnection.Application.ActiveWindow.View.Type = Handler.ViewType;
	EndIf;
	
	COMConnection.Application.Visible = True;
	COMConnection.Activate();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Functions for getting areas from a template

// Gets a template area.
//
// Parameters:
//  Handler         - reference to a template.
//  AreaName        - area name in the template.
//  OffsetBeginning - Number - overrides the boundary that marks the beginning of the area for 
// cases when the area beginning is located not directly after the operator parenthesis but a 
// few characters later.
//                                 Default value: 1  - a newline character, which should not be included in the area,
//                                is expected after the operator parenthesis that marks the area beginning.
//  OffsetEnd - Number - overrides the boundary that marks the end of the area for cases when the area end is located 
//                       not directly before the operator parenthesis but a few characters earlier. This must be a negative value.
//                                 Default value:-1  - a newline character, which should not be included in the area,
//                                 is expected beforethe operator parenthesis
//                                 that marks the area end.
//
Function GetMSWordTemplateArea(Val Handler,
									Val AreaName,
									Val OffsetBeginning = 1,
									Val OffsetEnd = -1) Export
	
	Result = New Structure("Document,Start,End");
	
	PositionStart = OffsetBeginning + GetAreaBeginPosition(Handler.COMConnection, AreaName);
	PositionEnd = OffsetEnd + GetAreaEndPosition(Handler.COMConnection, AreaName);
	
	If PositionStart >= PositionEnd Or PositionStart < 0 Then
		Return Undefined;
	EndIf;
	
	Result.Document = Handler.COMConnection.ActiveDocument;
	Result.Start = PositionStart;
	Result.End   = PositionEnd;
	
	Return Result;
	
EndFunction

// Gets the header area of the first template area. 
// Parameters:
// Handler - reference to the template. 
// Returns: 
// Reference to the header.
//
Function GetHeaderArea(Val Handler) Export
	
	Return New Structure("Header", Handler.COMConnection.ActiveDocument.Sections(1).Headers.Item(1));
	
EndFunction

// Gets the footer area of the first template area.
// Parameters:
// Handler - reference to the template.
// Returns: 
// Reference to the footer.
//
Function GetFooterArea(Handler) Export
	
	Return New Structure("Footer", Handler.COMConnection.ActiveDocument.Sections(1).Footers.Item(1));
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Functions for adding areas to the print form

// Start: operations with Microsoft Word document headers and footers
 
// Adds a footer from a template to a print form.
// Parameters:
// PrintForm   - reference to a print form. 
// HandlerArea - reference to an area in the template. 
// Parameters  - list of parameters that will be replaced by values. 
// ObjectData  - object data for filling.
//
Procedure AddFooter(Val PrintForm, Val HandlerArea) Export
	
	HandlerArea.Footer.Range.Copy();
	Footer(PrintForm).Paste();
	
EndProcedure

// Fills footer parameters.
// Parameters:
// PrintForm   - reference to a print form. 
// HandlerArea - reference to an area in the template. 
// Parameters  - list of parameters that will be replaced by values. 
// ObjectData  - object data for filling.
//
Procedure FillFooterParameters(Val PrintForm, Val ObjectData = Undefined) Export
	
	If ObjectData = Undefined Then
		Return;
	EndIf;
	
	For Each ParameterValue In ObjectData Do
		If TypeOf(ParameterValue.Value) <> Type("Array") Then
			Replace(Footer(PrintForm), ParameterValue.Key, ParameterValue.Value);
		EndIf;
	EndDo;
	
EndProcedure

Function Footer(PrintForm)
	Return PrintForm.COMConnection.ActiveDocument.Sections(1).Footers.Item(1).Range;
EndFunction

// Adds a header from a template to a print form.
// Parameters:
// PrintForm   - reference to a print form. 
// HandlerArea - reference to an area in the template. 
// Parameters  - list of parameters that will be replaced by values. 
// ObjectData  - object data for filling.
//
Procedure AddHeader(Val PrintForm, Val HandlerArea) Export
	
	HandlerArea.Header.Range.Copy();
	Header(PrintForm).Paste();
	
EndProcedure

// Fills header parameters.
// Parameters:
// PrintForm   - reference to a print form. 
// HandlerArea - reference to an area in the template. 
// Parameters  - list of parameters that will be replaced by values.
// ObjectData  - object data for filling.
//
Procedure FillHeaderParameters(Val PrintForm, Val ObjectData = Undefined) Export
	
	If ObjectData = Undefined Then
		Return;
	EndIf;
	
	For Each ParameterValue In ObjectData Do
		If TypeOf(ParameterValue.Value) <> Type("Array") Then
			Replace(Header(PrintForm), ParameterValue.Key, ParameterValue.Value);
		EndIf;
	EndDo;
	
EndProcedure

Function Header(PrintForm)
	Return PrintForm.COMConnection.ActiveDocument.Sections(1).Headers.Item(1).Range;
EndFunction

// End: operations with Microsoft Word document headers and footers 
 
// Adds an area from a template to a print form, replacing the area parameters
// with the values from the object data.
// The procedure is used during the output of a single area.
//
// Parameters:
// PrintForm      - reference to a print form. 
// HandlerArea    - reference to an area in the template.
// MoveToNextLine - Boolean, shows whether a line break is added after outputting the area.
//
// Returns:
// AreaCoordinates.
//
Function PutArea(Val PrintForm,
							Val HandlerArea,
							Val MoveToNextLine = True,
							Val JoinTableRow = False) Export
	
	HandlerArea.Document.Range(HandlerArea.Start, HandlerArea.End).Copy();
	
	FF_ActiveDocument = PrintForm.COMConnection.ActiveDocument;
	DocumentEndPosition	= FF_ActiveDocument.Range().End;
	InsertionArea				= FF_ActiveDocument.Range(DocumentEndPosition-1, DocumentEndPosition-1);
	
	If JoinTableRow Then
		InsertionArea.PasteAppendTable();
	Else
		InsertionArea.Paste();
	EndIf;
	
	// Returning the boundaries of the inserted area
	Result = New Structure("Document, Start, End",
							FF_ActiveDocument,
							DocumentEndPosition-1,
							FF_ActiveDocument.Range().End-1);
	
	If MoveToNextLine Then
		InsertBreakAtNewLine(PrintForm);
	EndIf;
	
	Return Result;
	
EndFunction

// Adds a list area from a template to a print form, replacing the area parameters with the values from the object data.
// The procedure is used when outputting list data (the list can be bulleted or numbered).
//
// Parameters:
// PrintFormArea - reference to an area in a print form.
// ObjectData    - ObjectData.
//
Procedure FillParameters(Val PrintFormArea, Val ObjectData = Undefined) Export
	
	If ObjectData = Undefined Then
		Return;
	EndIf;
	
	For Each ParameterValue In ObjectData Do
		If TypeOf(ParameterValue.Value) <> Type("Array") Then
			Replace(PrintFormArea.Document.Content, ParameterValue.Key, ParameterValue.Value);
		EndIf;
	EndDo;
	
EndProcedure

// Start: operations with collections

// Adds a list area from a template to a print form, replacing the area parameters with the 
// values from the object data.
// The procedure is used when outputting list data (the list can be bulleted or numbered).
//
// Parameters:
// PrintForm      - reference to a print form. 
// HandlerArea    - reference to an area in the template.
// Parameters     - String, list of parameters that will be replaced by values.
// ObjectData     - ObjectData. 
// MoveToNextLine - Boolean, shows whether a line break is added after outputting the area.
//
Procedure JoinAndFillSet(Val PrintForm,
									  Val HandlerArea,
									  Val ObjectData = Undefined,
									  Val MoveToNextLine = True) Export
	
	HandlerArea.Document.Range(HandlerArea.Start, HandlerArea.End).Copy();
	
	ActiveDocument = PrintForm.COMConnection.ActiveDocument;
	
	If ObjectData <> Undefined Then
		For Each RowData In ObjectData Do
			InsertPosition = ActiveDocument.Range().End;
			InsertionArea = ActiveDocument.Range(InsertPosition-1, InsertPosition-1);
			InsertionArea.Paste();
			
			If TypeOf(RowData) = Type("Structure") Then
				For Each ParameterValue In RowData Do
					Replace(ActiveDocument.Content, ParameterValue.Key, ParameterValue.Value);
				EndDo;
			EndIf;
		EndDo;
	EndIf;
	
	If MoveToNextLine Then
		InsertBreakAtNewLine(PrintForm);
	EndIf;
	
EndProcedure

// Adds a list area from a template to a print form, replacing the area parameters with the 
// values from the object data.
// The procedure is used when outputting a table row.
//
// Parameters:
// PrintForm      - reference to a print form. 
// HandlerArea    - reference to an area in the template.
// TableName      - table name (for data access).
// ObjectData     - ObjectData.
// MoveToNextLine - Boolean, shows whether a line break is added after outputting the area.
//
Procedure JoinAndFillTableArea(Val PrintForm,
												Val HandlerArea,
												Val ObjectData = Undefined,
												Val MoveToNextLine = True) Export
	
	If ObjectData = Undefined Or ObjectData.Count() = 0 Then
		Return;
	EndIf;
	
	FirstLine = True;
	
	HandlerArea.Document.Range(HandlerArea.Start, HandlerArea.End).Copy();
	
	ActiveDocument = PrintForm.COMConnection.ActiveDocument;
	
// Inserting the first line. The next lines are inserted with the formatting based on the 
// first one.
	InsertBreakAtNewLine(PrintForm); 
	InsertPosition = ActiveDocument.Range().End;
	InsertionArea = ActiveDocument.Range(InsertPosition-1, InsertPosition-1);
	InsertionArea.Paste();
	ActiveDocument.Range(InsertPosition-2, InsertPosition-2).Delete();
	
	If TypeOf(ObjectData[0]) = Type("Structure") Then
		For Each ParameterValue In ObjectData[0] Do
			Replace(ActiveDocument.Content, ParameterValue.Key, ParameterValue.Value);
		EndDo;
	EndIf;
	
	For Each TableRowData In ObjectData Do
		If FirstLine Then
			FirstLine = False;
			Continue;
		EndIf;
		
		NewInsertionPosition = ActiveDocument.Range().End;
		ActiveDocument.Range(InsertPosition-1, ActiveDocument.Range().End-1).Select();
		PrintForm.COMConnection.Selection.InsertRowsBelow();
		
		ActiveDocument.Range(NewInsertionPosition-1, ActiveDocument.Range().End-2).Select();
		PrintForm.COMConnection.Selection.Paste();
		InsertPosition = NewInsertionPosition;
		
		If TypeOf(TableRowData) = Type("Structure") Then
			For Each ParameterValue In TableRowData Do
				Replace(ActiveDocument.Content, ParameterValue.Key, ParameterValue.Value);
			EndDo;
		EndIf;
		
	EndDo;
	
	If MoveToNextLine Then
		InsertBreakAtNewLine(PrintForm);
	EndIf;
	
EndProcedure

// End: operations with collections

// Inserts a line break to the next line.
// Parameters:
// Handler - reference to a Microsoft Word document. A line break is added to this document.
//
Procedure InsertBreakAtNewLine(Val Handler) Export
	ActiveDocument = Handler.COMConnection.ActiveDocument;
	DocumentEndPosition = ActiveDocument.Range().End;
	ActiveDocument.Range(DocumentEndPosition-1, DocumentEndPosition-1).InsertParagraphAfter();
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Other procedures and functions

Function GetAreaBeginPosition(Val COMConnection, Val AreaID)
	
	AreaID = "{v8 Area." + AreaID + "}";
	
	EntireDocument = COMConnection.ActiveDocument.Content;
	EntireDocument.Select();
	
	Search = COMConnection.Selection.Find;
	Search.Text = AreaID;
	Search.ClearFormatting();
	Search.Forward = True;
	Search.execute();
	
	If Search.Found Then
		Return COMConnection.Selection.End;
	EndIf;
	
	Return -1;
	
EndFunction

Function GetAreaEndPosition(Val COMConnection, Val AreaID)
	
	AreaID = "{/v8 Area." + AreaID + "}";
	
	EntireDocument = COMConnection.ActiveDocument.Content;
	EntireDocument.Select();
	
	Search = COMConnection.Selection.Find;
	Search.Text = AreaID;
	Search.ClearFormatting();
	Search.Forward = True;
	Search.execute();
	
	If Search.Found Then
		Return COMConnection.Selection.Start;
	EndIf;
	
	Return -1;

	
EndFunction

Function PageParameterSettings()
	
	SettingsArray = New Array;
	SettingsArray.Add("Orientation");
	SettingsArray.Add("TopMargin");
	SettingsArray.Add("BottomMargin");
	SettingsArray.Add("LeftMargin");
	SettingsArray.Add("RightMargin");
	SettingsArray.Add("Gutter");
	SettingsArray.Add("HeaderDistance");
	SettingsArray.Add("FooterDistance");
	SettingsArray.Add("PageWidth");
	SettingsArray.Add("PageHeight");
	SettingsArray.Add("FirstPageTray");
	SettingsArray.Add("OtherPagesTray");
	SettingsArray.Add("SectionStart");
	SettingsArray.Add("OddAndEvenPagesHeaderFooter");
	SettingsArray.Add("DifferentFirstPageHeaderFooter");
	SettingsArray.Add("VerticalAlignment");
	SettingsArray.Add("SuppressEndnotes");
	SettingsArray.Add("MirrorMargins");
	SettingsArray.Add("TwoPagesOnOne");
	SettingsArray.Add("BookFoldPrinting");
	SettingsArray.Add("BookFoldRevPrinting");
	SettingsArray.Add("BookFoldPrintingSheets");
	SettingsArray.Add("GutterPos");
	
	Return SettingsArray;
	
EndFunction

Function EventLogMessageText()
	Return NStr("en = 'Print'", CommonUseClientServer.DefaultLanguageCode());
EndFunction

Procedure FailedToGeneratePrintForm(ErrorInfo)
#If WebClient Then
	ClarificationText = NStr("en = 'The web access requires Internet Explorer web browser for Windows operating system. For more information, see the ""Configuring the web browsers for web client operation"" section of the 1C:Enterprise Administrator guide'");
#Else		
	ClarificationText = "";	
#EndIf
	ErrorMessage = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = 'Cannot generate a print form: %1. 
			|To output print forms in Microsoft Word format, you must have Microsoft Office software package installed on your computer. %2'"),
		BriefErrorDescription(ErrorInfo), ClarificationText);
	Raise ErrorMessage;
EndProcedure

Procedure Replace(Object, Val SearchString, Val ReplacementString)
	
	SearchString = "{v8 " + SearchString + "}";
	ReplacementString = String(ReplacementString);
	
	Object.Select();
	Selection = Object.Application.Selection;
	
	FindObject = Selection.Find;
	FindObject.ClearFormatting();
	While FindObject.Execute(SearchString) Do
		If IsBlankString(ReplacementString) Then
			Selection.Delete();
		Else
			Selection.TypeText(ReplacementString);
		EndIf;
	EndDo;
	
	Selection.Collapse();
	
EndProcedure