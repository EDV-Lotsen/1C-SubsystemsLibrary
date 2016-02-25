////////////////////////////////////////////////////////////////////////////////
// Print subsystem.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// Open Office Writer-specific functions
//
// Print form and template reference description
// Structure with the following fields:
// ServiceManager - service manager, Open Office service
// Desktop - Open Office application (UNO service).
// Document - document (print form)
// Type - print form type ("ODT")
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS    

// Initializes the print form: creates a COM object and sets its properties.
Function InitOOWriterPrintForm(Val Template = Undefined) Export
	
	Try
		ServiceManager = New COMObject("com.sun.star.ServiceManager");
	Except
		EventLogOperationsClient.AddMessageForEventLog(EventLogMessageText(), "Error",
			NStr("en = 'Error connecting to the service manager (com.sun.star.ServiceManager).'") + 
			+ Chars.LF + DetailErrorDescription(ErrorInfo()),,True);
		FailedToGeneratePrintForm(ErrorInfo());
	EndTry;
	
	Try
		Desktop = ServiceManager.CreateInstance("com.sun.star.frame.Desktop");
	Except
		EventLogOperationsClient.AddMessageForEventLog(EventLogMessageText(), "Error",
			NStr("en = 'Error starting Desktop service (com.sun.star.frame.Desktop).'") + 
			+ Chars.LF + DetailErrorDescription(ErrorInfo()),,True);
		FailedToGeneratePrintForm(ErrorInfo());
	EndTry;
	
	Parameters = GetComSafeArray();
	
#If Not WebClient Then
	Parameters.SetValue(0, PropertyValue(ServiceManager, "Hidden", True));
#EndIf
	
	Document = Desktop.LoadComponentFromURL("private:factory/swriter", "_blank", 0, Parameters);
	
#If WebClient Then
	Document.getCurrentController().getFrame().getContainerWindow().setVisible(False);
#EndIf

    // Customizing the fields based on a template
	If Template <> Undefined Then
		TemplateStyleName = Template.Document.CurrentController.getViewCursor().PageStyleName;
		TemplateStyle = Template.Document.StyleFamilies.getByName("PageStyles").getByName(TemplateStyleName);
			
		StyleName = Document.CurrentController.getViewCursor().PageStyleName;
		Style = Document.StyleFamilies.getByName("PageStyles").getByName(StyleName);
		
		Style.TopMargin = TemplateStyle.TopMargin;
		Style.LeftMargin = TemplateStyle.LeftMargin;
		Style.RightMargin = TemplateStyle.RightMargin;
		Style.BottomMargin = TemplateStyle.BottomMargin;
	EndIf;

	// Preparing the template reference
	Handler = New Structure("ServiceManager,Desktop,Document,Type");
	Handler.ServiceManager = ServiceManager;
	Handler.Desktop = Desktop;
	Handler.Document = Document;
	
	Return Handler;
	
EndFunction

// Returns a structure with a print form template.
//
// Parameters:
// TemplateBinaryData - BinaryData - template binary data 
// Returns:
// Structure - template reference.
//
Function GetOOWriterTemplate(Val TemplateBinaryData, TempFileName) Export
	
	Handler = New Structure("ServiceManager,Desktop,Document,FileName");
	
	Try
		ServiceManager = New COMObject("com.sun.star.ServiceManager");
	Except
		EventLogOperationsClient.AddMessageForEventLog(EventLogMessageText(), "Error",
			NStr("en = 'Error connecting to the service manager (com.sun.star.ServiceManager).'") + 
			+ Chars.LF + DetailErrorDescription(ErrorInfo()),,True);
		FailedToGeneratePrintForm(ErrorInfo());
	EndTry;
	
	Try
		Desktop = ServiceManager.CreateInstance("com.sun.star.frame.Desktop");
	Except
		EventLogOperationsClient.AddMessageForEventLog(EventLogMessageText(), "Error",
			NStr("en = 'Error starting Desktop service (com.sun.star.frame.Desktop).'") + 
			+ Chars.LF + DetailErrorDescription(ErrorInfo()),,True);
		FailedToGeneratePrintForm(ErrorInfo());
	EndTry;
	
#If Not WebClient Then
	TempFileName = GetTempFileName("ODT");
	TemplateBinaryData.Write(TempFileName);
#EndIf
	
	Parameters = GetComSafeArray();
#If Not WebClient Then
	Parameters.SetValue(0, PropertyValue(ServiceManager, "Hidden", True));
#EndIf
	
	Document = Desktop.LoadComponentFromURL("file:///" + StrReplace(TempFileName, "\", "/"), "_blank", 0, Parameters);
	
#If WebClient Then
	Document.getCurrentController().getFrame().getContainerWindow().setVisible(False);
#EndIf
	
	// Preparing the template reference
	Handler.ServiceManager = ServiceManager;
	Handler.Desktop = Desktop;
	Handler.Document = Document;
	Handler.FileName = TempFileName;
	
	Return Handler;
	
EndFunction

// Closes a print form template and deletes the references to the COM object.
//
Function CloseConnection(Handler, Val ExitApplication) Export
	
	If ExitApplication Then
		Handler.Document.Close(0);
	EndIf;
	
	Handler.Document = Undefined;
	Handler.Desktop = Undefined;
	Handler.ServiceManager = Undefined;
	ScriptControl = Undefined;
	
	If Handler.Property("FileName") Then
		DeleteFiles(Handler.FileName);
	EndIf;
	
	Handler = Undefined;
	
EndFunction

// Sets the visibility property for Open Office Writer application.
// Handler - reference to a print form.
//
Procedure ShowOOWriterDocument(Val Handler) Export
	
	ContainerWindow = Handler.Document.getCurrentController().getFrame().getContainerWindow();
	ContainerWindow.setVisible(True);
	ContainerWindow.SetFocus();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Template operations
// Gets a template area.
// Parameters:
// Handler      - reference to the template. 
// AreaName     - area name in the template. 
// OffsetBeginning  - offset from the beginning of the area,
//     default offset: 1 - the area is taken without the newline character 
//     that is located after the operator parenthesis that marks the area beginning. 
// OffsetEnd - offset from the end of the area,
// 				default offset: -11 - the area is taken without the newline character
//     that is located before the operator parenthesis that marks the area end.
//
Function GetTemplateArea(Val Handler, Val AreaName) Export
	
	Result = New Structure("Document,Start,End");
	
	Result.Start = GetAreaBeginPosition(Handler.Document, AreaName);
	Result.End   = GetAreaEndPosition(Handler.Document, AreaName);
	Result.Document = Handler.Document;
	
	Return Result;
	
EndFunction

// Gets the header area.
//
Function GetHeaderArea(Val TemplateRef) Export
	
	Return New Structure("Document, ServiceManager", TemplateRef.Document, TemplateRef.ServiceManager);
	
EndFunction

// Gets the footer area.
//
Function GetFooterArea(TemplateRef) Export
	
	Return New Structure("Document, ServiceManager", TemplateRef.Document, TemplateRef.ServiceManager);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Print form operations

// Inserts a line break to the next line. 
// Parameters:
// Handler - reference to an Open Office document. A line break is added to this document.
//
Procedure InsertBreakAtNewLine(Val Handler) Export
	
	oText = Handler.Document.getText();
	oCursor = oText.createTextCursor();
	oCursor.gotoEnd(False);
	oText.insertControlCharacter(oCursor, 0, False);
	
EndProcedure

// Adds a header to a print form.
//
Procedure AddHeader(Val PrintForm, Val Area) Export
	
	Template_oTxtCrsr = SetMainCursorOnHeader(Area);
	While Template_oTxtCrsr.goRight(1, True) Do
	EndDo;
	TransferableObject = Area.Document.getCurrentController().Frame.controller.getTransferable();
	
	SetMainCursorOnHeader(PrintForm);
	PrintForm.Document.getCurrentController().insertTransferable(TransferableObject);
	
EndProcedure

// Adds a footer to a print form.
//
Procedure AddFooter(Val PrintForm, Val Area) Export
	
	Template_oTxtCrsr = SetMainCursorToFooter(Area);
	While Template_oTxtCrsr.goRight(1, True) Do
	EndDo;
	TransferableObject = Area.Document.getCurrentController().Frame.controller.getTransferable();
	
	SetMainCursorToFooter(PrintForm);
	PrintForm.Document.getCurrentController().insertTransferable(TransferableObject);
	
EndProcedure

// Adds an area from a template to a print form, replacing the area parameters with the values from the object data.
// The procedure is used during the output of a single area.
//
// Parameters:
// PrintForm             - reference to a print form. 
// HandlerArea           - reference to an area in the template.
// MoveToNextLine - Boolean, shows whether a line break is added after outputting the area.
//
// Returns:
// AreaCoordinates.
//
Procedure PutArea(Val HandlerPrintForm,
							Val HandlerArea,
							Val MoveToNextLine = True,
							Val JoinTableRow = False) Export
	
	Template_oTxtCrsr = HandlerArea.Document.getCurrentController().getViewCursor();
	Template_oTxtCrsr.gotoRange(HandlerArea.Start, False);
	
	If Not JoinTableRow Then
		Template_oTxtCrsr.goRight(1, False);
	EndIf;
	
	Template_oTxtCrsr.gotoRange(HandlerArea.End, True);
	
	TransferableObject = HandlerArea.Document.getCurrentController().Frame.controller.getTransferable();
	HandlerPrintForm.Document.getCurrentController().insertTransferable(TransferableObject);
	
	If JoinTableRow Then
		DeleteRow(HandlerPrintForm);
	EndIf;
	
	If MoveToNextLine Then
		InsertBreakAtNewLine(HandlerPrintForm);
	EndIf;
	
EndProcedure

// Fills parameters in a print form tabular section.
//
Procedure FillParameters(PrintForm, Data) Export
	
	For Each KeyValue In Data Do
		If TypeOf(KeyValue) <> Type("Array") Then
			FF_oDoc = PrintForm.Document;
			FF_ReplaceDescriptor = FF_oDoc.createReplaceDescriptor();
			FF_ReplaceDescriptor.SearchString = "{v8 " + KeyValue.Key + "}";
			FF_ReplaceDescriptor.ReplaceString = String(KeyValue.Value);
			FF_oDoc.replaceAll(FF_ReplaceDescriptor);
		EndIf;
	EndDo;
	
EndProcedure

// Adds a collection area to a print form.
//
Procedure JoinAndFillCollection(Val HandlerPrintForm,
										  Val HandlerArea,
										  Val Data,
										  Val IsTableRow = False,
										  Val MoveToNextLine = True) Export
	
	Template_oTxtCrsr = HandlerArea.Document.getCurrentController().getViewCursor();
	Template_oTxtCrsr.gotoRange(HandlerArea.Start, False);
	
	If Not IsTableRow Then
		Template_oTxtCrsr.goRight(1, False);
	EndIf;
	Template_oTxtCrsr.gotoRange(HandlerArea.End, True);
	
	TransferableObject = HandlerArea.Document.getCurrentController().Frame.controller.getTransferable();
	
	For Each RowWithData In Data Do
		HandlerPrintForm.Document.getCurrentController().insertTransferable(TransferableObject);
		If IsTableRow Then
			DeleteRow(HandlerPrintForm);
		EndIf;
		FillParameters(HandlerPrintForm, RowWithData);
	EndDo;
	
	If MoveToNextLine Then
		InsertBreakAtNewLine(HandlerPrintForm);
	EndIf;
	
EndProcedure

// Sets the cursor to the end of the DocumentRef document.
//
Procedure SetMainCursorToDocumentBody(Val DocumentRef) Export
	
	oDoc = DocumentRef.Document;
	oViewCursor = oDoc.getCurrentController().getViewCursor();
	oTextCursor = oDoc.Text.createTextCursor();
	oViewCursor.gotoRange(oTextCursor, False);
	oViewCursor.gotoEnd(False);
	
EndProcedure

// Sets the cursor to the header.
//
Function SetMainCursorOnHeader(Val DocumentRef) Export
	
	xCursor = DocumentRef.Document.getCurrentController().getViewCursor();
	PageStyleName = xCursor.GetPropertyValue("PageStyleName");
	oPStyle = DocumentRef.Document.getStyleFamilies().getByName("PageStyles").getByName(PageStyleName);
	oPStyle.HeaderIsOn = True;
	HeaderTextCursor = oPStyle.GetPropertyValue("HeaderText").createTextCursor();
	xCursor.gotoRange(HeaderTextCursor, False);
	Return xCursor;
	
EndFunction

// Sets the cursor to the footer.
//
Function SetMainCursorToFooter(Val DocumentRef) Export
	
	xCursor = DocumentRef.Document.getCurrentController().getViewCursor();
	PageStyleName = xCursor.GetPropertyValue("PageStyleName");
	oPStyle = DocumentRef.Document.getStyleFamilies().getByName("PageStyles").getByName(PageStyleName);
	oPStyle.FooterIsOn = True;
	FooterTextCursor = oPStyle.GetPropertyValue("FooterText").createTextCursor();
	xCursor.gotoRange(FooterTextCursor, False);
	Return xCursor;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Other procedures and functions

// Gets a structure used to set UNO object parameters.
//
Function PropertyValue(Val ServiceManager, Val Property, Val Value)
	
	PropertyValue = ServiceManager.Bridge_GetStruct("com.sun.star.beans.PropertyValue");
	PropertyValue.Name = Property;
	PropertyValue.Value = Value;
	
	Return PropertyValue;
	
EndFunction

Function GetAreaBeginPosition(Val XDocument, Val AreaName)
	
	SearchText = "{v8 Area." + AreaName + "}";
	
	xSearchDescr = XDocument.createSearchDescriptor();
	xSearchDescr.SearchString = SearchText;
	xSearchDescr.SearchCaseSensitive = False;
	xSearchDescr.SearchWords = True;
	xFound = XDocument.findFirst(xSearchDescr);
	If xFound = Undefined Then
		Raise NStr("en = 'Area template beginning is not found:'") + " " + AreaName;	
	EndIf;
	Return xFound.End;
	
EndFunction

Function GetAreaEndPosition(Val XDocument, Val AreaName)
	
	SearchText = "{/v8 Region." + AreaName + "}";
	
	xSearchDescr = XDocument.createSearchDescriptor();
	xSearchDescr.SearchString = SearchText;
	xSearchDescr.SearchCaseSensitive = False;
	xSearchDescr.SearchWords = True;
	xFound = XDocument.findFirst(xSearchDescr);
	If xFound = Undefined Then
		Raise NStr("en = 'Area template end is not found:'") + " " + AreaName;	
	EndIf;
	Return xFound.Start;
	
EndFunction

Procedure DeleteRow(HandlerPrintForm)
	
	oFrame = HandlerPrintForm.Document.getCurrentController().Frame;
	
	dispatcher = HandlerPrintForm.ServiceManager.CreateInstance ("com.sun.star.frame.DispatchHelper");
	
	oViewCursor = HandlerPrintForm.Document.getCurrentController().getViewCursor();
	
	dispatcher.executeDispatch(oFrame, ".uno:GoUp", "", 0, GetComSafeArray());
	
	While oViewCursor.TextTable <> Undefined Do
		dispatcher.executeDispatch(oFrame, ".uno:GoUp", "", 0, GetComSafeArray());
	EndDo;
	
	dispatcher.executeDispatch(oFrame, ".uno:Delete", "", 0, GetComSafeArray());
	
	While oViewCursor.TextTable <> Undefined Do
		dispatcher.executeDispatch(oFrame, ".uno:GoDown", "", 0, GetComSafeArray());
	EndDo;
	
EndProcedure

Function GetComSafeArray()
	
#If WebClient Then
	scr = New COMObject("MSScriptControl.ScriptControl");
	scr.language = "javascript";
	scr.eval("Array=New Array()");
	Return scr.eval("Array");
#Else
	Return New COMSafeArray("VT_DISPATCH", 1);
#EndIf
	
EndFunction

Function EventLogMessageText()
	Return NStr("en = 'Print'");
EndFunction

Procedure FailedToGeneratePrintForm(ErrorInfo)
#If WebClient Then
	ClarificationText = NStr("en = 'The web access requires Internet Explorer web browser for Windows operating system.'");
#Else		
	ClarificationText = "";	
#EndIf
	ErrorMessage = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = 'Cannot generate a print form: %1. 
			|To output print forms in the OpenOffice.org Writer format, you have to install OpenOffice.org package. %2'"),
		BriefErrorDescription(ErrorInfo), ClarificationText);
	Raise ErrorMessage;
EndProcedure