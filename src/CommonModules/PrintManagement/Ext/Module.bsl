////////////////////////////////////////////////////////////////////////////////
// Print subsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// Returns the description of the print form found in the collection.
// If the description is not found, returns Undefined.
//
// Parameters:
//  PrintFormCollection - ValueTable - see PreparePrintFormCollection().
//  TemplateName        - String     - template name to check.
//
// Returns:
//  ValueTableRow - found print form description.
Function PrintFormInfo(PrintFormCollection, ID) Export
	Return PrintFormCollection.Find(Upper(ID), "NameUpper");
EndFunction

// Checks whether printing a template is required.
//  
// Parameters:
//  PrintFormCollection - ValueTable - see PreparePrintFormCollection().
//  TemplateName        - String     - template name to check.
//   
// Returns:
//  Boolean - True if the template must be printed.
Function MustPrintTemplate(PrintFormCollection, TemplateName) Export

	Return PrintFormCollection.Find(Upper(TemplateName), "NameUpper") <> Undefined;
	
EndFunction

// Adds a spreadsheet document to a print form collection.
//
// Parameters:
//  PrintFormCollection  - ValueTable - see PreparePrintFormCollection().
//  TemplateName         - String - template name.
//  TemplateSynonym      - String - template presentation.
//  SpreadsheetDocument  - SpreadsheetDocument - document print form.
//  Picture              - Picture.
//  FullPathToTemplate   - String - path to the template in the metadata tree, for example:
//                         "Document._DemoCustomerInvoice.PF_MXL_Invoice".
//                         If you do not specify this parameter, editing the template in the
//                         PrintDocuments form is not available to users.
//  PrintFormFileName    - String - name that is used when saving a print form to a file.
//                       - Map:
//                           * Key   - AnyRef - reference to a print object.
//                           * Value - String - file name.
Procedure OutputSpreadsheetDocumentToCollection(PrintFormCollection, TemplateName, TemplateSynonym, SpreadsheetDocument,
	Picture = Undefined, FullPathToTemplate = "", PrintFormFileName = Undefined) Export
	
	PrintFormDescription = PrintFormCollection.Find(Upper(TemplateName), "NameUpper");
	If PrintFormDescription <> Undefined Then
		PrintFormDescription.SpreadsheetDocument = SpreadsheetDocument;
		PrintFormDescription.TemplateSynonym = TemplateSynonym;
		PrintFormDescription.Picture = Picture;
		PrintFormDescription.FullPathToTemplate = FullPathToTemplate;
		PrintFormDescription.PrintFormFileName = PrintFormFileName;
	EndIf;
	
EndProcedure

// Sets the object printing area in a spreadsheet document.
// The procedure is used to connect an area in a spreadsheet document to a print object (reference).
// The procedure is called when generating the next print form area in a spreadsheet document.
//
// Parameters:
//  SpreadsheetDocument - SpreadsheetDocument - print form.
//  FirstRowNumber      - Number - position of the beginning of the next area in the document.
//  PrintObjects        - ValueList - print object list.
//  Ref                 - AnyRef - print object.
Procedure SetDocumentPrintArea(SpreadsheetDocument, FirstRowNumber, PrintObjects, Ref) Export
	
	Item = PrintObjects.FindByValue(Ref);
	If Item = Undefined Then
		AreaName = "Document_" + Format(PrintObjects.Count() + 1, "NZ=; NG=");
		PrintObjects.Add(Ref, AreaName);
	Else
		AreaName = Item.Presentation;
	EndIf;
	
	LineNumberEnd = SpreadsheetDocument.TableHeight;
	SpreadsheetDocument.Area(FirstRowNumber, , LineNumberEnd, ).Name = AreaName;

EndProcedure

// Returns the external print form list.
//
// Parameters:
//  MetadataObjectFullName - String - full name of the metadata object whose list of print forms is retrieved.
//
// Returns:
//  List:
//   * Value        - String - print form ID.
//   * Presentation - String - print form presentation.
Function PrintFormListFromExternalSources(MetadataObjectFullName) Export
	
	ExternalPrintForms = New ValueList;
	If Not IsBlankString(MetadataObjectFullName) Then
		OnReceiveExternalPrintFormList(ExternalPrintForms, MetadataObjectFullName);
	EndIf;
	
	Return ExternalPrintForms;
	
EndFunction

// Places print commands in a form.
//
// Parameters:
//   Form                   - ManagedForm - form for placing the Print submenu.
//   DefaultCommandLocation - FormItem - group for placing the Print submenu, the default location is the command bar.
//   PrintObjects           - Array - list of metadata objects, for generating a joint Print submenu.
Procedure OnCreateAtServer(Form, DefaultCommandLocation = Undefined, PrintObjects = Undefined) Export
	
	PrintCommands = FormPrintCommands(Form, PrintObjects);
	PrintCommands.Columns.Add("CommandNameOnForm", New TypeDescription("String"));
	
	CommandTable = PrintCommands.Copy(,"Location");
	CommandTable.GroupBy("Location");
	Locations = CommandTable.UnloadColumn("Location");
	
	For Each Location In Locations Do
		FoundCommands = PrintCommands.FindRows(New Structure("Location,HiddenByFunctionalOptions", Location, False));
		
		FormItemForPlacement = Form.Items.Find(Location);
		If FormItemForPlacement = Undefined Then
			FormItemForPlacement = DefaultCommandLocation;
		EndIf;
		
		If FoundCommands.Count() > 0 Then
			AddPrintCommands(Form, FoundCommands, FormItemForPlacement);
		EndIf;
	EndDo;
	
	PrintCommandAddressInTemporaryStorage = "PrintCommandAddressInTemporaryStorage";
	FormCommand = Form.Commands.Find(PrintCommandAddressInTemporaryStorage);
	If FormCommand = Undefined Then
		FormCommand = Form.Commands.Add(PrintCommandAddressInTemporaryStorage);
		FormCommand.Action = PutToTempStorage(PrintCommands, Form.UUID);
	Else
		CommonPrintFormCommandList = GetFromTempStorage(FormCommand.Action);
		For Each PrintCommand In PrintCommands Do
			FillPropertyValues(CommonPrintFormCommandList.Add(), PrintCommand);
		EndDo;
		FormCommand.Action = PutToTempStorage(CommonPrintFormCommandList, Form.UUID);
	EndIf;
	
EndProcedure

// Returns the list of print commands for the specified print form.
//
// Parameters:
//  Form - ManagedForm, String - form or full form name for getting the list of print commands.
//
// Returns:
//  ValueTable - see the description in CreatePrintCommandCollection().
Function FormPrintCommands(Form, ListOfObjects = Undefined) Export
	
	If TypeOf(Form) = Type("ManagedForm") Then
		FormName = Form.FormName;
	Else
		FormName = Form;
	EndIf;
	
	PrintCommands = CreatePrintCommandCollection();
	PrintCommands.Columns.Add("HiddenByFunctionalOptions", New TypeDescription("Boolean"));
	
	StandardProcessing = True;
	PrintManagementOverridable.BeforeAddPrintCommands(FormName, PrintCommands, StandardProcessing);
	
	If StandardProcessing Then
		MetadataObject = Metadata.FindByFullName(FormName);
		If MetadataObject <> Undefined Then
			MetadataObject = MetadataObject.Parent();
		EndIf;
		
		If ListOfObjects <> Undefined Then
			FillPrintCommandsForListOfObjects(ListOfObjects, PrintCommands);
		ElsIf MetadataObject = Undefined Then
			Return PrintCommands;
		Else
			PrintManager = CommonUse.ObjectManagerByFullName(MetadataObject.FullName());
			CommandsAdded = AddCommandsFromPrintManager(PrintManager, PrintCommands);
			If CommandsAdded Then
				For Each PrintCommand In PrintCommands Do
					If IsBlankString(PrintCommand.PrintManager) Then
						PrintCommand.PrintManager = MetadataObject.FullName();
					EndIf;
				EndDo;
				If CommonUse.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
					AdditionalReportsAndDataProcessorsModule = CommonUse.CommonModule("AdditionalReportsAndDataProcessors");
					AdditionalReportsAndDataProcessorsModule.OnReceivePrintCommands(PrintCommands, FormName);
				EndIf;
			ElsIf CommonUse.IsDocumentJournal(MetadataObject) Then
				FillPrintCommandsForListOfObjects(MetadataObject.RegisteredDocuments, PrintCommands);
			EndIf;
		EndIf;
	EndIf;
	
	For Each PrintCommand In PrintCommands Do
		If PrintCommand.Order = 0 Then
			PrintCommand.Order = 50;
		EndIf;
	EndDo;
	
	PrintCommands.Sort("Order Asc, Presentation Asc");
	
	NameParts = StringFunctionsClientServer.SplitStringIntoSubstringArray(FormName, ".", True);
	FormShortName = NameParts[NameParts.Count()-1];
	
	// Filter by form names
	For LineNumber = -PrintCommands.Count() + 1 To 0 Do
		PrintCommand = PrintCommands[-LineNumber];
		FormList = StringFunctionsClientServer.SplitStringIntoSubstringArray(PrintCommand.FormList, ",", True);
		If FormList.Count() > 0 And FormList.Find(FormShortName) = Undefined Then
			PrintCommands.Delete(PrintCommand);
		EndIf;
	EndDo;
	
	GetPrintCommandVisibilityByFunctionalOptions(PrintCommands, Form);
	
	Return PrintCommands;
	
EndFunction

// Creates an empty table for placing print commands.
// 
// Returns:
//  ValueTable - print command description:
//
//  * ID                 - String - print command ID. The print manager uses this ID to determine 
//                                 the print form that must be generated.
//                                 Example: "Invoice".
//
//                                        To print multiple print forms, you can specify all their IDs at once 
//                                       (as a comma-separated string or an array of strings), for example:
//                                         "Invoice,Bill".
//
//                                        To set the number of copies for a print form, duplicate its ID
//                                        as many times as the number of copies you want generated. 
//                                        Note. The order of print forms in the batch matches 
//                                        the order of print form IDs specified in this parameter. 
//                                        Example (2 invoices + 1 bill):
//                                        "Invoice,Invoice,Bill".
//
//                                        A print form ID can contain an alternative print manager if it is different from 
//                                        the print manager specified in the PrintManager parameter, for example: 
//                                        "Invoice,DataProcessor.PrintForm.Bill".
//
//                                        In this example Bill is generated in
//                                        the DataProcessor._DemoPrintForm print manager, and 
//                                        Invoice is generated in the print manager specified in the PrintManager parameter.
//
//                      - Array - list of print command IDs.
//
//  * Presentation      - String       -  command presentation in the Print menu. 
//                                         Example: "Invoice".
//
//  * PrintManager      - String       -  (optional) name of the object whose manager module contains 
//                                        the Print procedure that generates spreadsheet documents for this command.
//                                        Default value: name of the object manager module.
//                                         Example: "Document.Invoice".
//  * PrintObjectTypes  - Array           - (optional) list of object types that can have the print command.
//                                        The parameter is intended for print commands in document journals, which
//                                        require checking the passed object type before calling the print manager.
//                                        If the list is blank, when the list of print commands is generated
//                                        in a document journal, it is filled with the object type, from which
//                                        the print command was imported.
//
//  * Handler           - String      -  (optional) client command handler that is executed instead of the standard 
//                                        print command handler. It is used, for example, 
//                                        when the print form is generated on the client.
//                                        Example: "PrintHandlersClient.PrintInvoices".
//
//  * Order             - Number       - (optional) a value from 1 to 100 that indicates the position of the command 
//                                        among other commands. The Print menu commands are sorted by 
//                                        the Order field, then by presentation.
//                                        The default value is 50.
//
//  * Picture           - Picture      - (optional) a picture that is displayed next to the command in the Print menu.
//                                        Example: PictureLib.PDFFormat.
//
//  * FormList         - String        - (optional) comma-separated names of forms where the command is displayed.
//                                       If the parameter is not specified, the print command is available in all forms of  
//                                       each object that is included in the Print subsystem.
//                                         Example: "DocumentForm".
//
//  * Location          - String       - (optional) name of the form command bar that contains the print command.
//                                       Use this parameter only when the form has more than one Print submenu. 
//                                       In other cases specify the print command location in the form module, in the call of
//                                       PrintManagement.OnCreateAtServer method.
//                                        
//  * FormTitle         - String       - (optional) a free-form string overriding
//                                       the standard title of the "Print documents" form.
//                                         Example: "Custom batch".
//
//  * FunctionalOptions - String       - (optional) comma-separated names of functional options that affect
//                                       the  print command availability.
//
//  * CheckPostingBeforePrint - Boolean - (optional) flag that shows whether a check that the document is posted
//                                        is performed before printing. If the parameter is not specified,
//                                        the check is not performed.
//
//  * SkipPreview      - Boolean       - (optional) a flag that shows whether documents are sent directly to a printer,
//                                       without the print preview. If the parameter is not specified,
//                                       the print command opens the "Print documents" preview form.
//
//  * SavingFormat - SpreadsheetDocumentFileType - (optional) used for quick saving of print forms 
//                                        (without additional actions) in non-MXL formats.
//                                        If the parameter is not specified, the print form is saved in MXL format.
//                                         Example: SpreadsheetDocumentFileType.PDF.
//
//                                        In this example selecting a print command opens a PDF document.
//
//  * OverrideCopiesUserSetting - Boolean - (optional) a flag that shows whether the option to save/restore
//                                       the number of copies selected by the user for printing
//                                       in the PrintDocuments form is disabled.                     
//                                       If the parameter is not specified, the PrintDocument form is opened
//                                       with this option enabled.
//
//  * SupplementBatchWithExternalPrintForms - Boolean - (optional) flag that shows whether the document batch
//                                        is supplemented with all the external print forms attached to the object 
//                                        (the AdditionalReportsAndDataProcessors subsystem). If the parameter is
//                                        not specified, the external print forms are not added to the batch.
//
//  * FixedBatch            - Boolean     - (optional) flag that shows whether the user can change the content of
//                                       the document batch. If the parameter is not specified, the user can exclude individual
//                                       print forms from the batch in the PrintDocuments form, and also change the number of copies.
//
//  * DontWriteInForm      - Boolean     - (optional) flag that shows whether object writing before the execution
//                                       of the print command is disabled. This parameter is used in special circumstances. If 
//                                       the parameter is not specified, the object is written when the object form
//                                       has a modification flag.
//
//  * FileSystemExtensionRequired - Boolean     - (optional) flag that shows whether attaching the file system extension
//                                       is required before executing the command. If the parameter is not specified, 
//                                       the file system extension is not attached.
//
Function CreatePrintCommandCollection() Export
	
	Result = New ValueTable;
	
	// Description
	Result.Columns.Add("ID", New TypeDescription("String"));
	Result.Columns.Add("Presentation", New TypeDescription("String"));
	
	//////////
	// Options (optional parameters)
	
	// Print manager
	Result.Columns.Add("PrintManager", New TypeDescription("String"));
	Result.Columns.Add("PrintObjectTypes", New TypeDescription("Array"));
	
	// Alternative command handler
	Result.Columns.Add("Handler", New TypeDescription("String"));
	
	// Presentation
	Result.Columns.Add("Order", New TypeDescription("Number"));
	Result.Columns.Add("Picture", New TypeDescription("Picture"));
 // Names of forms for command placement, comma-separated.
 Result.Columns.Add("FormList", New TypeDescription("String")); 
	Result.Columns.Add("Location", New TypeDescription("String"));
	Result.Columns.Add("FormTitle", New TypeDescription("String"));
 // Names of functional options that affect the command visibility, comma-separated.
 Result.Columns.Add("FunctionalOptions", New TypeDescription("String")); 
 
	// Posting check
	Result.Columns.Add("CheckPostingBeforePrint", New TypeDescription("Boolean"));
	
	// Output
	Result.Columns.Add("SkipPreview", New TypeDescription("Boolean"));
	Result.Columns.Add("SavingFormat"); // SpreadsheetDocumentFileType
	
	// Batch settingss
	Result.Columns.Add("OverrideCopiesUserSetting", New TypeDescription("Boolean")); // Deny saving user settings 
	Result.Columns.Add("SupplementBatchWithExternalPrintForms", New TypeDescription("Boolean"));
	Result.Columns.Add("FixedBatch", New TypeDescription("Boolean")); // Deny changing the batch
	
	// Additional parameters
	Result.Columns.Add("AdditionalParameters", New TypeDescription("Structure"));
	
	// Special command execution mode. 
 // By default, the modified object is written before executing the command.
	Result.Columns.Add("DontWriteInForm", New TypeDescription("Boolean"));
	
	// For using office document templates in the web client.
	Result.Columns.Add("FileSystemExtensionRequired", New TypeDescription("Boolean"));
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Operations with office document templates

// Adds a new area record to the OfficeDocumentTemplateAreas parameter.
//	
// Parameters:
//   OfficeDocumentTemplateAreas - Array - an area set (array of structures) of an office document template.
//   AreaName                    - String - name of the added area.
//   AreaType                    - String - area type:
// 		Header
// 		Footer
// 		General
// 		TableRow
// 		List
//	
// Example:
// Function OfficeDocumentTemplateAreas()
//	
// 	Areas = New Structure;
//	
// 	PrintManagement.AddAreaInfo(Areas,	"Header", "Header");
// 	PrintManagement.AddAreaInfo(Areas,	"Footer", "Footer");
// 	PrintManagement.AddAreaInfo(Areas,	"Title", "General");
//	
// 	Return Areas;
//	
// EndFunction
//
Procedure AddAreaInfo(OfficeDocumentTemplateAreas, Val AreaName, Val AreaType) Export
	
	NewArea = New Structure;
	
	NewArea.Insert("AreaName", AreaName);
	NewArea.Insert("AreaType", AreaType);
	
	OfficeDocumentTemplateAreas.Insert(AreaName, NewArea);
	
EndProcedure

// Gets all data required for printing within a single call: object template data,
// binary template data, and descriptions of template areas.
// The function is intended for calling print forms based on office document templates from client modules.
//
// Parameters:
//   PrintManagerName  - String - name for accessing the object manager, for example, Document.<Document name>.
//   TemplateNames     - String - names of templates that are used as basis for print form generation.
//   DocumentContent   - Array - references to infobase objects (all references must have the same type).
//
Function TemplatesAndDataOfObjectsToPrint(Val PrintManagerName, Val TemplateNames, Val DocumentContent) Export
	
	TemplateNameArray = StringFunctionsClientServer.SplitStringIntoSubstringArray(StrReplace(TemplateNames, " ", ""), ",");
	
	ObjectManager = CommonUse.ObjectManagerByFullName(PrintManagerName);
	TemplatesAndData = ObjectManager.GetPrintInfo(DocumentContent, TemplateNameArray);
	TemplatesAndData.Insert("LocalPrintFileDirectory", GetPrintFileLocalDirectory());
	
	Return TemplatesAndData;
	
EndFunction

// Returns the print form template via the full path to the template.
//
// Parameters:
//  FullPathToTemplate - String - full path to the template in the following format:
// 							"Document.<DocumentName>.<TemplateName>"
// 							"DataProcessor.<DataProcessorName>.<TemplateName>"
// 							"CommonTemplate.<TemplateName>"
// Return value:
//   SpreadsheetDocument - for MXL templates.
//   BinaryData          - for DOC and ODT templates.
//
Function PrintFormTemplate(FullPathToTemplate) Export
	
	PathParts = StrReplace(FullPathToTemplate, ".", Chars.LF);
	
	If StrLineCount(PathParts) = 3 Then
		PathToMetadata = StrGetLine(PathParts, 1) + "." + StrGetLine(PathParts, 2);
		PathToMetadataObject = StrGetLine(PathParts, 3);
	ElsIf StrLineCount(PathParts) = 2 Then
		PathToMetadata = StrGetLine(PathParts, 1);
		PathToMetadataObject = StrGetLine(PathParts, 2);
	Else
		Raise StringFunctionsClientServer.SubstituteParametersInString(NStr("en = 'Template %1 is not found. Operation canceled'"), FullPathToTemplate);
	EndIf;
	
	Query = New Query;
	
	Query.Text = "Select Template AS Template, Use AS Use
					|FROM
					|	InformationRegister.UserPrintTemplates
					|WHERE
					|	Object=&Object
					|	AND	TemplateName=&TemplateName
					|	AND	Use";
	
	Query.Parameters.Insert("Object", PathToMetadata);
	Query.Parameters.Insert("TemplateName", PathToMetadataObject);
	
	SetPrivilegedMode(True);
	
	Selection = Query.Execute().Select();
	
	SetPrivilegedMode(False);
	
	Result = Undefined;
	
	If Selection.Next() Then
		Result = Selection.Template.Get();
	Else
		If StrLineCount(PathParts) = 3 Then
			Result = CommonUse.ObjectManagerByFullName(PathToMetadata).GetTemplate(PathToMetadataObject);
		Else
			Result = GetCommonTemplate(PathToMetadataObject);
		EndIf;
	EndIf;
	
	If Result = Undefined Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(NStr("en = 'Template %1 is not found. Operation canceled'"), FullPathToTemplate);
	EndIf;
		
	Return Result;
	
EndFunction

// Returns a spreadsheet document by spreadsheet document binary data.
//
// Parameters:
//  BinaryDocumentData - BinaryData - spreadsheet document binary data.
//
// Returns:
//  SpreadsheetDocument.
//
Function SpreadsheetDocumentByBinaryData(BinaryDocumentData) Export
	
	TempFileName = GetTempFileName();
	BinaryDocumentData.Write(TempFileName);
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.Read(TempFileName);
	If SafeMode() = False Then
		DeleteFiles(TempFileName);
	EndIf;
	
	Return SpreadsheetDocument;
	
EndFunction

// Obsolete. Use TemplatesAndDataOfObjectsToPrint instead.
//
Function GetTemplatesAndObjectData(Val PrintManagerName, Val TemplateNames, Val DocumentContent) Export
	
	Return TemplatesAndDataOfObjectsToPrint(PrintManagerName, TemplateNames, DocumentContent);
	
EndFunction

// Obsolete. Use PrintFormTemplate instead.
//
Function GetTemplate(FullPathToTemplate) Export
	
	Return PrintFormTemplate(FullPathToTemplate);
	
EndFunction

// Obsolete. Use SpreadsheetDocumentByBinaryData instead.
//
Function GetSpreadsheetDocumentByBinaryData(BinaryData) Export
	
	TempFileName = GetTempFileName();
	BinaryData.Write(TempFileName);
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.Read(TempFileName);
	If SafeMode() = False Then
		DeleteFiles(TempFileName);
	EndIf;
	
	Return SpreadsheetDocument;
	
EndFunction

// Returns the binary data for generating a QR code.
//
// Parameters:
//  QRString        - String - data to be stored in the QR code.
//
//  CorrectionLevel - Number - image error correction level at which it is still possible to 
//                    completely recognize this QR code.
//                    The parameter must have integer type and have one of the 4 valid values:
//                    0 (7% damage allowed), 1 (15% damage allowed), 2 (25% damage allowed), 3 (35% damage allowed).
//
//  Size            - Number - size of the output image side, in pixels.
//                    If the smallest possible image size is greater than this parameter,
//                    the code is not generated.
//
//  ErrorText       - String - error description (if any error occurred).
//
// Returns:
//  BinaryData  - buffer that contains the bytes of the QR code image in PNG format.
// 
Function QRCodeData(QRString, CorrectionLevel, Size) Export
	
	Cancel = False;
	
	QRCodeGenerator = QRCodeGenerationComponent(Cancel);
	If Cancel Then
		Return Undefined;
	EndIf;
	
	Try
		BinaryPictureData = QRCodeGenerator.GenerateQRCode(QRString, CorrectionLevel, Size);
	Except
		WriteLogEvent(NStr("en = 'Generating QR code'", CommonUseClientServer.DefaultLanguageCode()),
			EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
	EndTry;
	
	Return BinaryPictureData;
	
EndFunction
	
#EndRegion

#Region InternalInterface

// See the description of this procedure in the StandardSubsystemsServer module.
Procedure InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers) Export
	
	// SERVER HANDLERS
	
	ServerHandlers["StandardSubsystems.InfobaseVersionUpdate\OnAddUpdateHandlers"].Add(
		"PrintManagement");
	
	ServerHandlers["StandardSubsystems.BaseFunctionality\OnFillPermissionsToAccessExternalResources"].Add(
		"PrintManagement");
	
	If CommonUse.SubsystemExists("StandardSubsystems.ToDoList") Then
		ServerHandlers["StandardSubsystems.ToDoList\OnFillToDoList"].Add(
			"PrintManagement");
	EndIf;
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

// Adds update handlers that are required by the subsystem.
//
// Parameters:
//  Handlers - ValueTable - see the description of NewUpdateHandlerTable function in the InfobaseUpdate common module.
// 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.2.5";
	Handler.Procedure = "PrintManagement.ResetUserFormSettingsPrintDocuments";
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.3.22";
	Handler.Procedure = "PrintManagement.ConvertUserMXLTemplateBinaryDataToSpreadsheetDocuments";
	
EndProcedure

// Fills a list of requests for external permissions that must be granted when an infobase is created 
// or an application is updated.
//
// Parameters:
//  PermissionRequests - Array - list of values returned by 
//                       SafeMode.RequestToUseExternalResources() function.
//
Procedure OnFillPermissionsToAccessExternalResources(PermissionRequests) Export
	
	PermissionRequests.Add(
		SafeMode.RequestToUseExternalResources(Permissions()));
	
EndProcedure

// Fills a user's to-do list.
//
// Parameters:
//  ToDoList - ValueTable - value table with the following columns:
//    * ID             - String - internal user task ID used by the To-do list algorithm.
//    * HasUserTasks   - Boolean - if True, the user task is displayed in the user's to-do list.
//    * Important      - Boolean - If True, the user task is outlined in red.
//    * Presentation   - String - user task presentation displayed to the user.
//    * Quantity       - Number - quantitative indicator of the user task, displayed in the title of the user task.
//    * Form           - String - full path to the form that is displayed by a click 
//                                on the task hyperlink in the To-do list panel.
//    * FormParameters - Structure - parameters for opening the indicator form.
//    * Owner          - String, metadata object - string ID of the user task that is the owner of the current user task, or a subsystem metadata object.
//    * Hint           - String - hint text.
// 
Procedure OnFillToDoList(ToDoList) Export
	
	If Not AccessRight("Edit", Metadata.InformationRegisters.UserPrintTemplates) Then
		Return;
	EndIf;
	
	// If there is no Administration section, the user task is not added
	Subsystem = Metadata.Subsystems.Find("Administration");
	If Subsystem <> Undefined
		And Not AccessRight("View", Subsystem)
		And Not CommonUse.MetadataObjectEnabledByFunctionalOptions(Subsystem) Then
		Return;
	EndIf;
	
	OutputUserTask = True;
	VersionChecked = CommonSettingsStorage.Load("ToDoList", "PrintForms");
	If VersionChecked <> Undefined Then
		VersionArray  = StringFunctionsClientServer.SplitStringIntoSubstringArray(Metadata.Version, ".");
		CurrentVersion = VersionArray[0] + VersionArray[1] + VersionArray[2];
		If VersionChecked = CurrentVersion Then
			OutputUserTask = False; // Print forms are checked on the current version.
		EndIf;
	EndIf;
	
	UserTemplateCount = UsedUserTemplateCount();
	
	// Adding a user task
	UserTask = ToDoList.Add();
	UserTask.ID           = "PrintFormTemplates";
	UserTask.HasUserTasks = OutputUserTask And UserTemplateCount > 0;
	UserTask.Presentation = NStr("en = 'Print form templates'");
	UserTask.Quantity     = UserTemplateCount;
	UserTask.Form         = "InformationRegister.UserPrintTemplates.Form.PrintFormCheck";
	UserTask.Owner        = "ValidateCompatibilityWithCurrentVersion";
	
	// Checking for a user task group. If the group is missing, adding it
	UserTaskGroup = ToDoList.Find("ValidateCompatibilityWithCurrentVersion", "ID");
	If UserTaskGroup = Undefined Then
		UserTaskGroup = ToDoList.Add();
		UserTaskGroup.ID = "ValidateCompatibilityWithCurrentVersion";
		UserTaskGroup.HasUserTasks      = UserTask.HasUserTasks;
		UserTaskGroup.Presentation = NStr("en = 'Check compatibility'");
		If UserTask.HasUserTasks Then
			UserTaskGroup.Quantity = UserTask.Quantity;
		EndIf;
		UserTaskGroup.Owner = Subsystem;
	Else
		If Not UserTaskGroup.HasUserTasks Then
			UserTaskGroup.HasUserTasks = UserTask.HasUserTasks;
		EndIf;		
		If UserTask.HasUserTasks Then
			UserTaskGroup.Quantity = UserTaskGroup.Quantity + UserTask.Quantity;
		EndIf;
	EndIf;
	
EndProcedure

// Returns a demo list of permissions
//
// Returns:
//  Array.
//
Function Permissions()
	
	Permissions = New Array;
	Permissions.Add( 
		SafeMode.PermissionToUseAddIn("CommonTemplate.QRCodePrintingComponent", NStr("en = 'Print QR codes.'"))
	);
	
	Return Permissions;
	
EndFunction

// Resets the user print form settings: number of copies and order.
Procedure ResetUserFormSettingsPrintDocuments() Export
	CommonUse.CommonSettingsStorageDelete("PrintFormSettings", Undefined, Undefined);
EndProcedure

// Converts user MXL templates stored as binary data to spreadsheet documents.
Procedure ConvertUserMXLTemplateBinaryDataToSpreadsheetDocuments() Export
	
	QueryText = 
	"SELECT
	|	UserPrintTemplates.TemplateName,
	|	UserPrintTemplates.Object,
	|	UserPrintTemplates.Template,
	|	UserPrintTemplates.Use
	|FROM
	|	InformationRegister.UserPrintTemplates AS UserPrintTemplates";
	
	Query = New Query(QueryText);
	TemplateSelection = Query.Execute().Select();
	
	While TemplateSelection.Next() Do
		If Left(TemplateSelection.TemplateName, 6) = "PF_MXL" Then
			TempFileName = GetTempFileName();
			
			TemplateBinaryData = TemplateSelection.Template.Get();
			If TypeOf(TemplateBinaryData) <> Type("BinaryData") Then
				Continue;
			EndIf;
			
			TemplateBinaryData.Write(TempFileName);
			
			SpreadsheetDocumentRead = True;
			SpreadsheetDocument = New SpreadsheetDocument;
			Try
				SpreadsheetDocument.Read(TempFileName);
			Except
				SpreadsheetDocumentRead = False; // This file is not a spreadsheet document. Deleting the file.
			EndTry;
			
			Write = InformationRegisters.UserPrintTemplates.CreateRecordManager();
			FillPropertyValues(Write, TemplateSelection, , "Template");
			
			If SpreadsheetDocumentRead Then
				Write.Template = New ValueStorage(SpreadsheetDocument, New Deflation(9));
				Write.Write();
			Else
				Write.Delete();
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

// Returns the reference to the source object of the external print form.
//
// Parameters:
//  ID                     - String - form ID.
//  MetadataObjectFullName - String - full name of the metadata object for getting 
//                                    the reference to the external print form source.
//
// Returns:
//  Ref.
Function ExternalPrintForm(ID, MetadataObjectFullName)
	ExternalPrintFormRef = Undefined;
	
	OnReceiveExternalPrintForm(ID, MetadataObjectFullName, ExternalPrintFormRef);
	
	Return ExternalPrintFormRef;
EndFunction

// Generates print forms.
Procedure GeneratePrintForms(PrintManagerName, Val TemplateNames, ObjectArray, PrintParameters,
	PrintFormCollection, PrintObjects = Undefined, OutputParameters, AllowedPrintObjectTypes = Undefined) Export
	
	OutputParameters = PrepareOutputParametersStructure();
	
	If PrintObjects = Undefined Then
		PrintObjects = New ValueList;
	EndIf;
	
	PrintFormCollection = PreparePrintFormCollection(New Array);
	
	If TypeOf(TemplateNames) = Type("String") Then
		TemplateNames = StringFunctionsClientServer.SplitStringIntoSubstringArray(TemplateNames);
	Else // Type("Array")
		TemplateNames = CommonUseClientServer.CopyArray(TemplateNames);
	EndIf;
	
	ExternalPrintFormPrefix = "ExternalPrintForm.";
	
	ExternalPrintFormSource = PrintManagerName;
	If CommonUse.IsReference(TypeOf(ObjectArray)) Then
		ExternalPrintFormSource = ObjectArray.Metadata().FullName();
	Else
		If ObjectArray.Count() > 0 Then
			ExternalPrintFormSource = ObjectArray[0].Metadata().FullName();
		EndIf;
	EndIf;
	ExternalPrintForms = PrintFormListFromExternalSources(ExternalPrintFormSource);
	
	// Adding external print forms to a batch
	AddedExternalPrintForms = New Array;
	If TypeOf(PrintParameters) = Type("Structure") 
		And PrintParameters.Property("SupplementBatchWithExternalPrintForms") 
		And PrintParameters.SupplementBatchWithExternalPrintForms Then 
		
		ExternalPrintFormIds = ExternalPrintForms.UnloadValues();
		For Each ID In ExternalPrintFormIds Do
			If TemplateNames.Find(ID) = Undefined Then
				TemplateNames.Add(ExternalPrintFormPrefix + ID);
				AddedExternalPrintForms.Add(ExternalPrintFormPrefix + ID);
			EndIf;
		EndDo;
	EndIf;
	
	For Each TemplateName In TemplateNames Do
		// Checking for a printed form
		FoundPrintForm = PrintFormCollection.Find(TemplateName, "TemplateName");
		If FoundPrintForm <> Undefined Then
			LastAddedPrintForm = PrintFormCollection[PrintFormCollection.Count()-1];
			If LastAddedPrintForm.TemplateName = FoundPrintForm.TemplateName Then
				LastAddedPrintForm.Copies = LastAddedPrintForm.Copies + 1;
			Else
				PrintFormCopy = PrintFormCollection.Add();
				FillPropertyValues(PrintFormCopy, FoundPrintForm);
				PrintFormCopy.Copies = 1;
			EndIf;
			Continue;
		EndIf;
		
		// Checking whether an additional print manager is specified in the print form name
		AdditionalPrintManagerName = "";
		ID = TemplateName;
		ExternalPrintForm = Undefined;
		If Find(ID, ExternalPrintFormPrefix) > 0 Then // This is an external print form
			ID = Mid(ID, StrLen(ExternalPrintFormPrefix) + 1);
			ExternalPrintForm = ExternalPrintForms.FindByValue(ID);
		ElsIf Find(ID, ".") > 0 Then // Additional print manager is specified
			Position = StringFunctionsClientServer.FindCharFromEnd(ID, ".");
			AdditionalPrintManagerName = Left(ID, Position - 1);
			ID = Mid(ID, Position + 1);
		EndIf;
		
		// Determining the internal print manager
		UsedPrintManager = AdditionalPrintManagerName;
		If IsBlankString(UsedPrintManager) Then
			UsedPrintManager = PrintManagerName;
		EndIf;
		
		// Checking whether the printed objects match the selected print form
		ExpectedObjectType = Undefined;
		
		ObjectsCorrespondingToPrintForm = ObjectArray;
		If AllowedPrintObjectTypes <> Undefined And AllowedPrintObjectTypes.Count() > 0 Then
			If TypeOf(ObjectArray) = Type("Array") Then
				ObjectsCorrespondingToPrintForm = New Array;
				For Each Object In ObjectArray Do
					If AllowedPrintObjectTypes.Find(TypeOf(Object)) = Undefined Then
						MessagePrintFormIsNotAvailable(Object);
					Else
						ObjectsCorrespondingToPrintForm.Add(Object);
					EndIf;
				EndDo;
				If ObjectsCorrespondingToPrintForm.Count() = 0 Then
					ObjectsCorrespondingToPrintForm = Undefined;
				EndIf;
			ElsIf CommonUse.ReferenceTypeValue(ObjectArray) Then // The passed variable is not an array
				If AllowedPrintObjectTypes.Find(TypeOf(ObjectArray)) = Undefined Then
					MessagePrintFormIsNotAvailable(ObjectArray);
					ObjectsCorrespondingToPrintForm = Undefined;
				EndIf;
			EndIf;
		EndIf;
		
		TemporaryCollectionForSinglePrintForm = PreparePrintFormCollection(ID);
		
		// Calling the Print procedure from the print manager
		If ExternalPrintForm <> Undefined Then
			// Print manager in the external print form
			AdditionalReportsAndDataProcessorsModule = CommonUse.CommonModule("AdditionalReportsAndDataProcessors");
			AdditionalReportsAndDataProcessorsModule.PrintByExternalSource(
				ExternalPrintForm(ExternalPrintForm.Value, ExternalPrintFormSource),
				New Structure("CommandID, TargetObjects", ExternalPrintForm.Value, ObjectsCorrespondingToPrintForm),
				TemporaryCollectionForSinglePrintForm,
				PrintObjects,
				OutputParameters);
		Else
			If Not IsBlankString(UsedPrintManager) Then
				PrintManager = CommonUse.ObjectManagerByFullName(UsedPrintManager);
				// Printing an internal print form
				If ObjectsCorrespondingToPrintForm <> Undefined Then
					PrintManager.Print(ObjectsCorrespondingToPrintForm, PrintParameters, TemporaryCollectionForSinglePrintForm, PrintObjects, OutputParameters);
				Else
					TemporaryCollectionForSinglePrintForm[0].SpreadsheetDocument = New SpreadsheetDocument;
				EndIf;
			EndIf;
		EndIf;
		
		// Validating the filling of the print form collection received from a print manager
		For Each PrintFormDescription In TemporaryCollectionForSinglePrintForm Do
			CommonUseClientServer.Validate(
				TypeOf(PrintFormDescription.Copies) = Type("Number") And PrintFormDescription.Copies > 0,
				StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'The number of copies is not specified for %1 print form.'"),
					?(IsBlankString(PrintFormDescription.TemplateSynonym), PrintFormDescription.TemplateName, PrintFormDescription.TemplateSynonym)
					));
		EndDo;
				
		// Updating the collection
		Cancel = TemporaryCollectionForSinglePrintForm.Count() = 0;
		// A single print form is required but the entire collection is proccessed for backward compatibility
		For Each TemporaryPrintForm In TemporaryCollectionForSinglePrintForm Do 
			If TemporaryPrintForm.SpreadsheetDocument <> Undefined Then
				PrintForm = PrintFormCollection.Add();
				FillPropertyValues(PrintForm, TemporaryPrintForm);
				If TemporaryCollectionForSinglePrintForm.Count() = 1 Then
					PrintForm.TemplateName = TemplateName;
					PrintForm.NameUpper = Upper(TemplateName);
				EndIf;
			Else
				// An error occurred when generating a print form
				Cancel = True;
			EndIf;
		EndDo;
		
		// Raising an exception based on the error.
		If Cancel Then
			ErrorMessageText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'An error occurred when generating the %1 print form. Contact the application administrator.'"), TemplateName);
			Raise(ErrorMessageText);
		EndIf;
		
	EndDo;
	
	// Setting the number of spreadsheet document copies
	For Each PrintForm In PrintFormCollection Do
		If AddedExternalPrintForms.Find(PrintForm.TemplateName) <> Undefined Then
			PrintForm.Copies = 0; // For automatically added forms
		EndIf;
		If PrintForm.SpreadsheetDocument <> Undefined Then
			PrintForm.SpreadsheetDocument.Copies = PrintForm.Copies;
		EndIf;
	EndDo;
	
EndProcedure

// Generates print forms for direct output to a printer
Procedure GeneratePrintFormsForQuickPrint(
		PrintManagerName, TemplateNames, ObjectArray, PrintParameters,
		SpreadsheetDocuments, PrintObjects, OutputParameters, Cancel) Export
	
	If Not AccessRight("Output", Metadata) Then
		Cancel = True;
		Return;
	EndIf;
	
	PrintFormCollection = Undefined;
	PrintObjects = New ValueList;
	
	GeneratePrintForms(PrintManagerName, TemplateNames, ObjectArray, PrintParameters,
		PrintFormCollection, PrintObjects, OutputParameters);
		
	SpreadsheetDocuments = New ValueList;
	
	For Each Str In PrintFormCollection Do
		If (TypeOf(Str.SpreadsheetDocument) = Type("SpreadsheetDocument")) And (Str.SpreadsheetDocument.TableHeight <> 0) Then
			SpreadsheetDocuments.Add(Str.SpreadsheetDocument, Str.TemplateSynonym);
		EndIf;
	EndDo;
	
EndProcedure

// Generates print forms for direct output to a printer in the server mode in ordinary application.
Procedure GeneratePrintFormsForQuickPrintOrdinaryApplication(
				PrintManagerName, TemplateNames, ObjectArray, PrintParameters,
				Address, PrintObjects, OutputParameters, Cancel) Export
	
	Var PrintObjectsVL, SpreadsheetDocuments;
	
	GeneratePrintFormsForQuickPrint(
			PrintManagerName, TemplateNames, ObjectArray, PrintParameters,
			SpreadsheetDocuments, PrintObjectsVL, OutputParameters, Cancel);
	
	If Cancel Then
		Return;
	EndIf;
	
	PrintObjects = New Map;
	
	For Each PrintObject In PrintObjectsVL Do
		PrintObjects.Insert(PrintObject.Presentation, PrintObject.Value);
	EndDo;
	
	Address = PutToTempStorage(SpreadsheetDocuments);
	
EndProcedure

// Prepares a print form collection. This is the value table used when generating print forms.
//
Function PreparePrintFormCollection(Val TemplateNames) Export
	
	Templates = New ValueTable;
	Templates.Columns.Add("TemplateName");
	Templates.Columns.Add("NameUpper");
	Templates.Columns.Add("TemplateSynonym");
	Templates.Columns.Add("SpreadsheetDocument");
	Templates.Columns.Add("Copies");
	Templates.Columns.Add("Picture");
	Templates.Columns.Add("FullPathToTemplate");
	Templates.Columns.Add("PrintFormFileName");
	
	If TypeOf(TemplateNames) = Type("String") Then
		TemplateNames = StringFunctionsClientServer.SplitStringIntoSubstringArray(TemplateNames);
	EndIf;
	
	For Each TemplateName In TemplateNames Do
		Template = Templates.Find(TemplateName, "TemplateName");
		If Template = Undefined Then
			Template = Templates.Add();
			Template.TemplateName = TemplateName;
			Template.NameUpper = Upper(TemplateName);
			Template.Copies = 1;
		Else
			Template.Copies = Template.Copies + 1;
		EndIf;
	EndDo;
	
	Return Templates;
	
EndFunction

// Prepares the output parameter structure for the manager of the object that is a source of print forms.
//
Function PrepareOutputParametersStructure() Export
	
	OutputParameters = New Structure;
	OutputParameters.Insert("PrintBySetsAvailable", False);
	
	LetterParameterStructure = New Structure("Recipient,Subject,Text", Undefined, "", "");
	OutputParameters.Insert("SendingParameters", LetterParameterStructure);
	
	Return OutputParameters;
	
EndFunction

// Returns the path to the directory used when printing from the temporary storage.
//
Function GetPrintFileLocalDirectory() Export
	
	Value = CommonUse.CommonSettingsStorageLoad("LocalPrintFileDirectory");
	Return ?(Value = Undefined, "", Value);
	
EndFunction

// Stores the path to the directory used when printing to the temporary storage. 
// Parameters:
//  Directory - String - path to the print directory.
//
Procedure SaveLocalPrintFileDirectory(Directory) Export
	
	CommonUse.CommonSettingsStorageSave("LocalPrintFileDirectory", , Directory);
	
EndProcedure

// Returns the table of available formats for saving a spreadsheet document.
//
// RETURNS
//  ValueTable:
//  SpreadsheetDocumentFileType - SpreadsheetDocumentFileType - platform format that is mapped to the SL format.
//  Ref                         - EnumRef.ReportSaveFormats - reference to the metadata 
//                                that stores the format presentation.
//  Presentation                - String - file type presentation (filled from an enumeration).
//  Extension                   - String - file type for the operating system.
//  Picture                     - Picture - format icon.
//
// Note: the format table can be overridden in the
// PrintManagementOverridable.OnFillStorageFormatSettings() procedure.
//
Function SpreadsheetDocumentStorageFormatSettings() Export
	
	FormatTable = New ValueTable;
	
	FormatTable.Columns.Add("SpreadsheetDocumentFileType", New TypeDescription("SpreadsheetDocumentFileType"));
	FormatTable.Columns.Add("Ref", New TypeDescription("EnumRef.ReportSaveFormats"));
	FormatTable.Columns.Add("Presentation", New TypeDescription("String"));
	FormatTable.Columns.Add("Extension", New TypeDescription("String"));
	FormatTable.Columns.Add("Picture", New TypeDescription("Picture"));

	// PDF document (.pdf)
	NewFormat = FormatTable.Add();
	NewFormat.SpreadsheetDocumentFileType = SpreadsheetDocumentFileType.PDF;
	NewFormat.Ref = Enums.ReportSaveFormats.PDF;
	NewFormat.Extension = "pdf";
	NewFormat.Picture = PictureLib.PDFFormat;
	
	// Microsoft Excel Worksheet 2007 (.xlsx)
	NewFormat = FormatTable.Add();
	NewFormat.SpreadsheetDocumentFileType = SpreadsheetDocumentFileType.XLSX;
	NewFormat.Ref = Enums.ReportSaveFormats.XLSX;
	NewFormat.Extension = "xlsx";
	NewFormat.Picture = PictureLib.MSExcel2007Format;

	// Microsoft Excel 97-2003 worksheet (.xls)
	NewFormat = FormatTable.Add();
	NewFormat.SpreadsheetDocumentFileType = SpreadsheetDocumentFileType.XLS;
	NewFormat.Ref = Enums.ReportSaveFormats.XLS;
	NewFormat.Extension = "xls";
	NewFormat.Picture = PictureLib.MSExcelFormat;

	// OpenDocument spreadsheet (.ods)
	NewFormat = FormatTable.Add();
	NewFormat.SpreadsheetDocumentFileType = SpreadsheetDocumentFileType.ODS;
	NewFormat.Ref = Enums.ReportSaveFormats.ODS;
	NewFormat.Extension = "ods";
	NewFormat.Picture = PictureLib.OpenOfficeCalcFormat;
	
	// Spreadsheet document (.mxl)
	NewFormat = FormatTable.Add();
	NewFormat.SpreadsheetDocumentFileType = SpreadsheetDocumentFileType.MXL;
	NewFormat.Ref = Enums.ReportSaveFormats.MXL;
	NewFormat.Extension = "mxl";
	NewFormat.Picture = PictureLib.MXLFormat;

	// Word 2007 document (.docx)
	NewFormat = FormatTable.Add();
	NewFormat.SpreadsheetDocumentFileType = SpreadsheetDocumentFileType.DOCX;
	NewFormat.Ref = Enums.ReportSaveFormats.DOCX;
	NewFormat.Extension = "docx";
	NewFormat.Picture = PictureLib.MSWord2007Format;
	
	// Web page (.html)
	NewFormat = FormatTable.Add();
	NewFormat.SpreadsheetDocumentFileType = SpreadsheetDocumentFileType.HTML;
	NewFormat.Ref = Enums.ReportSaveFormats.HTML;
	NewFormat.Extension = "html";
	NewFormat.Picture = PictureLib.HTMLFormat;
	
	// Text document, UTF-8 (.txt)
	NewFormat = FormatTable.Add();
	NewFormat.SpreadsheetDocumentFileType = SpreadsheetDocumentFileType.TXT;
	NewFormat.Ref = Enums.ReportSaveFormats.TXT;
	NewFormat.Extension = "txt";
	NewFormat.Picture = PictureLib.TXTFormat;
	
	// Text document, ANSI (.txt)
	NewFormat = FormatTable.Add();
	NewFormat.SpreadsheetDocumentFileType = SpreadsheetDocumentFileType.ANSITXT;
	NewFormat.Ref = Enums.ReportSaveFormats.ANSITXT;
	NewFormat.Extension = "txt";
	NewFormat.Picture = PictureLib.TXTFormat;

	// Additional formats / Changing the list of available formats
	PrintManagementOverridable.OnFillSpeadsheetDocumentFileFormatSettings(FormatTable);
	
	For Each SavingFormat In FormatTable Do
		SavingFormat.Presentation = String(SavingFormat.Ref);
	EndDo;
		
	Return FormatTable;
	
EndFunction

// Creates the Print submenu on a form and adds print commands to it.
// If a single print command is available, a button with the print form name is added instead of a submenu.
Procedure AddPrintCommands(Form, PrintCommands, Val CommandLocation = Undefined)
	
	If CommandLocation = Undefined Then
		CommandLocation = Form.CommandBar;
	EndIf;
	
	OnePrintCommand = PrintCommands.Count() = 1;
	If Not OnePrintCommand Then
		PrintSubmenu = Form.Items.Add(CommandLocation.Name + "PrintSubmenu", Type("FormGroup"), CommandLocation);
		PrintSubmenu.Type = FormGroupType.Popup;
		PrintSubmenu.Title = NStr("en = 'Print'");
		PrintSubmenu.Picture = PictureLib.Print;
		
		CommandLocation = PrintSubmenu;
	EndIf;
	
	For Each PrintCommandDescription In PrintCommands Do
		CommandNumber = PrintCommandDescription.Owner().IndexOf(PrintCommandDescription);
		CommandName = CommandLocation.Name + "PrintCommand" + CommandNumber;
		
		FormCommand = Form.Commands.Add(CommandName);
		FormCommand.Action = "Attachable_ExecutePrintCommand";
		FormCommand.Title = PrintCommandDescription.Presentation;
		FormCommand.ModifiesStoredData = False;
		FormCommand.Representation = ButtonRepresentation.PictureAndText;
		
		If ValueIsFilled(PrintCommandDescription.Picture) Then
			FormCommand.Picture = PrintCommandDescription.Picture;
		ElsIf OnePrintCommand Then
			FormCommand.Picture = PictureLib.Print;
		EndIf;
		
		PrintCommandDescription.CommandNameOnForm = CommandName;
		
		NewItem = Form.Items.Add(CommandLocation.Name + CommandName, Type("FormButton"), CommandLocation);
		NewItem.Type = FormButtonType.CommandBarButton;
		NewItem.CommandName = CommandName;
	EndDo;
	
EndProcedure

// Returns a command description by form item name.
// 
// Returns
//  Structure - table row from the PrintFormCommands function, converted into a structure.
Function PrintCommandDescription(CommandName, PrintCommandAddressInTemporaryStorage) Export
	
	PrintCommands = GetFromTempStorage(PrintCommandAddressInTemporaryStorage);
	For Each PrintCommand In PrintCommands.FindRows(New Structure("CommandNameOnForm", CommandName)) Do
		Return CommonUse.ValueTableRowToStructure(PrintCommand);
	EndDo;
	
EndFunction

// Filters a list of print commands according to the available functional options.
Procedure GetPrintCommandVisibilityByFunctionalOptions(PrintCommands, Form)
	For CommandNumber = -PrintCommands.Count() + 1 To 0 Do
		PrintCommandDescription = PrintCommands[-CommandNumber];
		PrintCommandFunctionalOptions = StringFunctionsClientServer.SplitStringIntoSubstringArray(PrintCommandDescription.FunctionalOptions, ",", True);
		CommandVisibility = PrintCommandFunctionalOptions.Count() = 0;
		For Each FunctionalOption In PrintCommandFunctionalOptions Do
			If TypeOf(Form) = Type("ManagedForm") Then
				CommandVisibility = CommandVisibility Or Form.GetFormFunctionalOption(FunctionalOption);
			Else
				CommandVisibility = CommandVisibility Or GetFunctionalOption(FunctionalOption);
			EndIf;
			
			If CommandVisibility Then
				Break;
			EndIf;
		EndDo;
		PrintCommandDescription.HiddenByFunctionalOptions = Not CommandVisibility;
	EndDo;
EndProcedure

// Saves a user print template to the infobase.
Procedure SaveTemplate(TemplateMetadataObjectName, TemplateAddressInTempStorage) Export
	Template = GetFromTempStorage(TemplateAddressInTempStorage);
	
	NameParts = StringFunctionsClientServer.SplitStringIntoSubstringArray(TemplateMetadataObjectName, ".");
	TemplateName = NameParts[NameParts.UBound()];
	
	OwnerName = "";
	For PartNumber = 0 To NameParts.UBound()-1 Do
		If Not IsBlankString(OwnerName) Then
			OwnerName = OwnerName + ".";
		EndIf;
		OwnerName = OwnerName + NameParts[PartNumber];
	EndDo;
	
	Write = InformationRegisters.UserPrintTemplates.CreateRecordManager();
	Write.Object = OwnerName;
	Write.TemplateName = TemplateName;
	Write.Use = True;
	Write.Template = New ValueStorage(Template, New Deflation(9));
	Write.Write();
EndProcedure

Function QRCodeGenerationComponent(Cancel)
	
	SystemInfo = New SystemInfo;
	Platform = SystemInfo.PlatformType;
	
	ErrorText = NStr("en = 'Cannot attach the add-in for QR code generation' ");
	
	Try
		If AttachAddIn("CommonTemplate.QRCodePrintingComponent", "QR") Then
			QrCodeGenerator = New("AddIn.QR.QrCodeExtension");
		Else
			CommonUseClientServer.MessageToUser(ErrorText, , , , Cancel);
		EndIf
	Except
		DetailErrorDescription = DetailErrorDescription(ErrorInfo());
		CommonUseClientServer.MessageToUser(ErrorText + Chars.LF + DetailErrorDescription, , , , Cancel);
	EndTry;
	
	Return QrCodeGenerator;
	
EndFunction

// Returns True if the user has the right to post at least one document.
Function HasRightsToPost(DocumentList) Export
	DocumentTypes = New Array;
	For Each Document In DocumentList Do
		DocumentType = TypeOf(Document);
		If DocumentTypes.Find(DocumentType) <> Undefined Then
			Continue;
		Else
			DocumentTypes.Add(DocumentType);
		EndIf;
		If AccessRight("Posting", Metadata.FindByType(DocumentType)) Then
			Return True;
		EndIf;
	EndDo;
	Return False;
EndFunction

Procedure MessagePrintFormIsNotAvailable(Object)
	MessageText = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = 'Cannot print %1: the selected print form is not available.'"),
		Object);
	CommonUseClientServer.MessageToUser(MessageText, Object);
EndProcedure

// Generates a document batch for sending to the printer.
Function DocumentBatch(SpreadsheetDocuments, PrintObjects, Collate, Copies = 1) Export
	
	RepresentableDocumentBatch = New RepresentableDocumentBatch;
	PrintFormCollection = SpreadsheetDocuments.UnloadValues();
	
	If Collate And PrintObjects.Count() > 0 Then 
		For Each PrintObject In PrintObjects Do
			AreaName = PrintObject.Presentation;
			For Each PrintForm In PrintFormCollection Do
				Area = PrintForm.Areas.Find(AreaName);
				If Area = Undefined Then
					Continue;
				EndIf;
				SpreadsheetDocument = PrintForm.GetArea(Area.Top, , Area.Bottom);
				FillPropertyValues(SpreadsheetDocument, PrintForm, "FitToPage,Output,PageHeight,DuplexPrinting,Protection,PrinterName,TemplateLanguageCode,Copies,PrintScale,PageOrientation,TopMargin,LeftMargin,BottomMargin,RightMargin,Collate,HeaderSize,FooterSize,PageSize,PrintAccuracy,BlackAndWhite,PageWidth,PerPage");
				TableDocumentCopies = SpreadsheetDocument.Copies;
				SpreadsheetDocument.Copies = 1;
				AddressInTempStorage = PutToTempStorage(SpreadsheetDocument);
				For CopyNumber = 1 To TableDocumentCopies Do
					RepresentableDocumentBatch.Content.Add(AddressInTempStorage);
				EndDo;
			EndDo;
		EndDo;
	Else
		For Each PrintForm In PrintFormCollection Do
			SpreadsheetDocument = New SpreadsheetDocument;
			SpreadsheetDocument.Put(PrintForm);
			FillPropertyValues(SpreadsheetDocument, PrintForm, "FitToPage,Output,PageHeight,DuplexPrinting,Protection,PrinterName,TemplateLanguageCode,Copies,PrintScale,PageOrientation,TopMargin,LeftMargin,BottomMargin,RightMargin,Collate,HeaderSize,FooterSize,PageSize,PrintAccuracy,BlackAndWhite,PageWidth,PerPage");
			TableDocumentCopies = SpreadsheetDocument.Copies;
			SpreadsheetDocument.Copies = 1;
			AddressInTempStorage = PutToTempStorage(SpreadsheetDocument);
			For CopyNumber = 1 To TableDocumentCopies Do
				RepresentableDocumentBatch.Content.Add(AddressInTempStorage);
			EndDo;
		EndDo;
	EndIf;
	
	RepresentableDocumentBatch.Copies = Copies;
	
	Return RepresentableDocumentBatch;
	
EndFunction

// Adds print commands to the list if the print manager has matching procedures.
Function AddCommandsFromPrintManager(PrintManager, PrintCommands)
	PrintCommandsToAdd = CreatePrintCommandCollection();
	Try
		PrintManager.AddPrintCommands(PrintCommandsToAdd);
	Except
		If PrintCommandsToAdd.Count() > 0 Then
			Raise;
		Else
			Return False;
		EndIf;
	EndTry;
	
	For Each PrintCommand In PrintCommandsToAdd Do
		FillPropertyValues(PrintCommands.Add(), PrintCommand);
	EndDo;
	
	Return True;
EndFunction

// Generates a list of print commands for several objects.
Procedure FillPrintCommandsForListOfObjects(ListOfObjects, PrintCommands)
	For Each MetadataObject In ListOfObjects Do
		If MetadataObject.DefaultListForm = Undefined Then
			Continue; // The design of the main object form does not include print commands.
		EndIf;
		ListFormName = MetadataObject.DefaultListForm.FullName();
		For Each PrintCommandToAdd In FormPrintCommands(ListFormName) Do
			// Searching for a similar command that was added earlier.
			Filter = New Structure("PrintManager,ID,Handler,SkipPreview,SavingFormat");
			FillPropertyValues(Filter, PrintCommandToAdd);
			If PrintCommands.FindRows(Filter).Count() > 0 Then
				// If the command is in the list, adding types of objects that can have the command.
				For Each ExistingPrintCommand In PrintCommands Do
					ObjectType = Type(StrReplace(MetadataObject.FullName(), ".", "Ref."));
					If ExistingPrintCommand.PrintObjectTypes.Find(ObjectType) = Undefined Then
						ExistingPrintCommand.PrintObjectTypes.Add(ObjectType);
					EndIf;
				EndDo;
				Continue;
			EndIf;
			
			If PrintCommandToAdd.PrintObjectTypes.Count() = 0 Then
				PrintCommandToAdd.PrintObjectTypes.Add(Type(StrReplace(MetadataObject.FullName(), ".", "Ref.")));
			EndIf;
			FillPropertyValues(PrintCommands.Add(), PrintCommandToAdd);
		EndDo;
	EndDo;
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Handlers of conditional calls of other subsystems

// Attaches a print form file to the object.
// The procedure is called from the common PrintDocuments form.
//
// Parameters:
//  ObjectRef            - AnyRef - object for attaching a print form file.
//  FileName             - String - name of the file to attach, with an extension.
//  AddressInTempStorage - String - file binary data address in a temporary storage.
//
Procedure OnAttachPrintFormToObject(ObjectRef, FileName, AddressInTempStorage) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.AttachedFiles") Then
		ModuleAttachedFiles = CommonUse.CommonModule("AttachedFiles");
		ModuleAttachedFiles.AppendFile(ObjectRef, FileName, , , , AddressInTempStorage, , NStr("en = 'Print form'"));
	EndIf;
	
EndProcedure

// Determines whether a print form can be attached to an object.
// The procedure is called from the common SavePrintForm form.
//
// Parameters:
//  ObjectRef - AnyRef - object for attaching a print form file.
//  CanAttach - Boolean - (return value) flag showing whether files can be attached to the object.
//
Procedure OnCheckCanAttachFilesToObject(ObjectRef, CanAttach) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.AttachedFiles") Then
		ModuleAttachedFiles = CommonUse.CommonModule("AttachedFiles");
		CanAttach = ModuleAttachedFiles.YouCanAttachFilesToObject(ObjectRef);
	EndIf;
	
EndProcedure

// Fills a list of print forms from external sources.
//
// Parameters:
//  ExternalPrintForms     - ValueList:
//                                         Value        - String - print form ID.
//                                         Presentation - String - print form name.
//  MetadataObjectFullName - String - full name of the metadata object whose list of print forms is retrieved.
//
Procedure OnReceiveExternalPrintFormList(ExternalPrintForms, MetadataObjectFullName) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		AdditionalReportsAndDataProcessorsModule = CommonUse.CommonModule("AdditionalReportsAndDataProcessors");
		AdditionalReportsAndDataProcessorsModule.OnReceiveExternalPrintFormList(ExternalPrintForms, MetadataObjectFullName);
	EndIf;
	
EndProcedure

// Returns the reference to an external print form object.
//
Procedure OnReceiveExternalPrintForm(ID, MetadataObjectFullName, ExternalPrintFormRef) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		AdditionalReportsAndDataProcessorsModule = CommonUse.CommonModule("AdditionalReportsAndDataProcessors");
		AdditionalReportsAndDataProcessorsModule.OnReceiveExternalPrintForm(ID, MetadataObjectFullName, ExternalPrintFormRef);
	EndIf;
	
EndProcedure

#EndRegion

#Region AuxiliaryProceduresAndFunctions

// For internal use only
//
Function UsedUserTemplateCount()
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	UserPrintTemplates.TemplateName
	|FROM
	|	InformationRegister.UserPrintTemplates AS UserPrintTemplates
	|WHERE
	|	UserPrintTemplates.Use = TRUE";
	
	Result = Query.Execute().Unload();
	
	Return Result.Count();
	
EndFunction

#EndRegion