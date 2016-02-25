
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// First of all, checking the access rights
	If Not AccessRight("Administration", Metadata) Then
		Raise NStr("en = 'Running the data processor manually requires administrator rights.'");
	EndIf;
	
  // Skipping the initialization to guarantee that the form will be 
  // received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then
		Return;
	EndIf;
	
	CheckPlatformVersionAndCompatibilityMode();
	
	Object.IsInteractiveMode = True;
	
	FormTitle = NStr("en = 'Universal data exchange in XML format (%DataProcessorVersion%)'");
	FormTitle = StrReplace(FormTitle, "%DataProcessorVersion%", ObjectVersionStringAtServer());
	
	Title = FormTitle;
	
	If IsBlankString(ChangeRecordsForExchangeNodeDeleteAfterExportType) Then
		Object.ChangeRecordsForExchangeNodeDeleteAfterExportType = 0;
	Else
		Object.ChangeRecordsForExchangeNodeDeleteAfterExportType = Number(ChangeRecordsForExchangeNodeDeleteAfterExportType);
	EndIf;
		
	FillTypeAvailableToDeleteList();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	Items.RuleFileName.ChoiceList.LoadValues(ExchangeRules.UnloadValues());
	Items.ExchangeFileName.ChoiceList.LoadValues(DataImportFromFile.UnloadValues());
	Items.DataFileName.ChoiceList.LoadValues(DataExportToFile.UnloadValues());
	
	OnPeriodChange();
	
	ClearDataImportFileData();
	
	DirectExport = ?(Object.DirectReadingInTargetInfobase, 1, 0);
	
	SavedImportMode = (Object.ExchangeMode = "Import");
	
	If SavedImportMode Then
		
		// Setting appropriate page
		Items.FormMainPanel.CurrentPage = Items.FormMainPanel.ChildItems.Import;
		
	EndIf;
	
	ProcessTransactionManagementItemsEnabled();
	
	ExpandTreeRows(DataToDelete, Items.DataToDelete, "Mark");
	
	ArchiveFileOnValueChange();
	DirectExportOnValueChange();
	
	ChangeProcessingMode(IsClient);
	
	#If WebClient Then
		Items.ExportDebugPages.CurrentPage = Items.ExportDebugPages.ChildItems.WebClientExportGroup;
		Items.ImportDebugPages.CurrentPage = Items.ImportDebugPages.ChildItems.WebClientImportGroup;
		Object.HandlerDebugModeFlag = False;
	#EndIf
	
	SetDebugCommandsEnabled();
	
	If SavedImportMode
		And Object.AutomaticDataImportSetup <> 0 Then
		
		If Object.AutomaticDataImportSetup = 1 Then
			
			NotifyDescription = New NotifyDescription("OnOpenCompletion", ThisObject);
			ShowQueryBox(NotifyDescription, NStr("en = 'Do you want to import data from the exchange file?'"), QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
			
		Else
			
			OnOpenCompletion(DialogReturnCode.Yes, Undefined);
			
		EndIf;
		
	EndIf;
	
	If IsLinuxClient() Then
		Items.GroupOS.CurrentPage = Items.GroupOS.ChildItems.LinuxGroup;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpenCompletion(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		ExecuteImportFromForm();
		ExportPeriodPresentation = PeriodPresentation(Object.StartDate, Object.EndDate);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure ArchiveFileOnChange(Item)
	
	ArchiveFileOnValueChange();
	
EndProcedure

&AtClient
Procedure ExchangeRuleFileNameStartChoice(Item, ChoiceData, StandardProcessing)
	
	SelectFile(Item, RuleFileName, True, , False, True);
	
EndProcedure

&AtClient
Procedure ExchangeRuleFileNameOpen(Item, StandardProcessing)
	
	OpenInApplication(Item.EditText, StandardProcessing);
	
EndProcedure

&AtClient
Procedure DirectExportOnChange(Item)
	
	DirectExportOnValueChange();
	
EndProcedure

&AtClient
Procedure FormMainPanelOnCurrentPageChange(Item, CurrentPage)
	
	If CurrentPage.Name = "Data" Then
		
		Object.ExchangeMode = "Data";
		
	ElsIf CurrentPage.Name = "Import" Then
		
		Object.ExchangeMode = "Import";
		
	EndIf;
	
EndProcedure

&AtClient
Procedure DebugModeFlagOnChange(Item)
	
	If Object.DebugModeFlag Then
		
		Object.UseTransactions = False;
				
	EndIf;
	
	ProcessTransactionManagementItemsEnabled();

EndProcedure

&AtClient
Procedure ProcessedObjectNumberToUpdateStatusOnChange(Item)
	
	If Object.ProcessedObjectNumberToUpdateStatus = 0 Then
		Object.ProcessedObjectNumberToUpdateStatus = 100;
	EndIf;
	
EndProcedure

&AtClient
Procedure ExchangeFileNameStartChoice(Item, ChoiceData, StandardProcessing)
	
	SelectFile(Item, ExchangeFileName, , , Object.ArchiveFile);
	
EndProcedure

&AtClient
Procedure ExchangeLogFileNameStartChoice(Item, ChoiceData, StandardProcessing)
	
	SelectFile(Item, Object.ExchangeLogFileName, , "txt", False);
	
EndProcedure

&AtClient
Procedure ImportExchangeLogFileNameStartChoice(Item, ChoiceData, StandardProcessing)
	
	SelectFile(Item, Object.ImportExchangeLogFileName, , "txt", False);
	
EndProcedure

&AtClient
Procedure DataFileNameStartChoice(Item, ChoiceData, StandardProcessing)
	
	SelectFile(Item, DataFileName, , , Object.ArchiveFile);
	
EndProcedure

&AtClient
Procedure InfobaseConnectionDirectoryStartChoice(Item, ChoiceData, StandardProcessing)
	
	FileDialog = New FileDialog(FileDialogMode.ChooseDirectory);
	
	FileDialog.Title = NStr("en = 'Select infobase directory'");
	FileDialog.Directory = Object.InfobaseConnectionDirectory;
	FileDialog.CheckFileExist = True;
	
	If FileDialog.Choose() Then
		
		Object.InfobaseConnectionDirectory = FileDialog.Directory;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExchangeLogFileNameOpen(Item, StandardProcessing)
	
	OpenInApplication(Item.EditText, StandardProcessing);
	
EndProcedure

&AtClient
Procedure ImportExchangeLogFileNameOpen(Item, StandardProcessing)
	
	OpenInApplication(Item.EditText, StandardProcessing);
	
EndProcedure

&AtClient
Procedure InfobaseConnectionDirectoryOpen(Item, StandardProcessing)
	
	OpenInApplication(Item.EditText, StandardProcessing);
	
EndProcedure

&AtClient
Procedure InfobaseConnectionWindowsAuthenticationOnChange(Item)
	
	Items.InfobaseUserForConnection.Enabled  = Not Object.InfobaseConnectionWindowsAuthentication;
	Items.InfobaseConnectionPassword.Enabled = Not Object.InfobaseConnectionWindowsAuthentication;
	
EndProcedure

&AtClient
Procedure RuleFileNameOnChange(Item)
	
	File = New File(RuleFileName);
	If IsBlankString(RuleFileName) Or Not File.Exist() Then
		MessageToUser(NStr("en = 'Exchange rule file not found'"), "RuleFileName");
		SetImportRuleFlag(False);
		Return;
	EndIf;
	
	If RuleAndExchangeFileNamesMatch() Then
		Return;
	EndIf;
	
	NotifyDescription = New NotifyDescription("RuleFileNameOnChangeCompletion", ThisObject);
	ShowQueryBox(NotifyDescription, NStr("en = 'Do you want to import data exchange rules?'"), QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
	
EndProcedure

&AtClient
Procedure RuleFileNameOnChangeCompletion(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		ExecuteImportExchangeRules();
		
	Else
		
		SetImportRuleFlag(False);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExchangeFileNameOpen(Item, StandardProcessing)
	
	OpenInApplication(Item.EditText, StandardProcessing);
	
EndProcedure

&AtClient
Procedure ExchangeFileNameOnChange(Item)
	
	ClearDataImportFileData();
	
EndProcedure

&AtClient
Procedure UseTransactionsOnChange(Item)
	
	ProcessTransactionManagementItemsEnabled();
	
EndProcedure

&AtClient
Procedure ImportHandlerDebugModeFlagOnChange(Item)
	
	SetDebugCommandsEnabled();
	
EndProcedure

&AtClient
Procedure ExportHandlerDebugModeFlagOnChange(Item)
	
	SetDebugCommandsEnabled();
	
EndProcedure

&AtClient
Procedure DataFileNameOpening(Item, StandardProcessing)
	
	OpenInApplication(Item.EditText, StandardProcessing);
	
EndProcedure

&AtClient
Procedure DataFileNameOnChange(Item)
	
	If EmptyAttributeValue(DataFileName, "DataFileName", Items.DataFileName.Title)
		OR RuleAndExchangeFileNamesMatch() Then
		Return;
	EndIf;
	
	Object.ExchangeFileName = DataFileName;
	
	File = New File(Object.ExchangeFileName);
	ArchiveFile = (Upper(File.Extension) = Upper(".zip"));
	
EndProcedure

&AtClient
Procedure InfobaseConnectionTypeOnChange(Item)
	
	InfobaseConnectionTypeOnValueChange();
	
EndProcedure

&AtClient
Procedure InfobaseConnectionPlatformVersionOnChange(Item)
	
	If IsBlankString(Object.InfobaseConnectionPlatformVersion) Then
		
		Object.InfobaseConnectionPlatformVersion = "V8";
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ChangeRecordsForExchangeNodeDeleteAfterExportTypeOnChange(Item)
	
	If IsBlankString(ChangeRecordsForExchangeNodeDeleteAfterExportType) Then
		Object.ChangeRecordsForExchangeNodeDeleteAfterExportType = 0;
	Else
		Object.ChangeRecordsForExchangeNodeDeleteAfterExportType = Number(ChangeRecordsForExchangeNodeDeleteAfterExportType);
	EndIf;
	
EndProcedure

&AtClient
Procedure ExportPeriodOnChange(Item)
	
	OnPeriodChange();
	
EndProcedure

&AtClient
Procedure DeletionPeriodOnChange(Item)
	
	OnPeriodChange();
	
EndProcedure

#EndRegion

#Region ExportRuleTableFormTableItemEventHandlers

&AtClient
Procedure ExportRuleTableBeforeRowChange(Item, Cancel)
	
	If Item.CurrentItem.Name = "ExchangeNodeRef" Then
		
		If Item.CurrentData.IsFolder Then
			Cancel = True;
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExportRuleTableOnChange(Item)
	
	If Item.CurrentItem.Name = "DER" Then
		
		CurRow = Item.CurrentData;
		
		If CurRow.PrivilegedModeOn = 2 Then
			CurRow.PrivilegedModeOn = 0;
		EndIf;
		
		SetSubordinateMarks(CurRow, "PrivilegedModeOn");
		SetParentMarks(CurRow, "PrivilegedModeOn");
		
	EndIf;
	
EndProcedure

#EndRegion

#Region DataToDeleteFormTableItemEventHandlers

&AtClient
Procedure DataToDeleteOnChange(Item)
	
	CurRow = Item.CurrentData;
	
	SetSubordinateMarks(CurRow, "Mark");
	SetParentMarks(CurRow, "Mark");

EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ConnectionTest(Command)
	
	EstablishConnectionWithTargetInfobaseAtServer();
	
EndProcedure

&AtClient
Procedure GetExchangeFileInfo(Command)
	
	FileURL = "";
	
	If IsClient Then
		
		NotifyDescription = New NotifyDescription("GetExchangeFileInfoCompletion", ThisObject);
		BeginPutFile(NotifyDescription, FileURL,NStr("en = 'Exchange file'"),, UUID);
		
	Else
		
		GetExchangeFileInfoCompletion(True, FileURL, "", Undefined);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure GetExchangeFileInfoCompletion(Result, Address, SelectedFileName, AdditionalParameters) Export
	
	If Result Then
		
		Try
			
			OpenImportFileAtServer(Address);
			ExportPeriodPresentation = PeriodPresentation(Object.StartDate, Object.EndDate);
			
		Except
			
			MessageToUser(NStr("en = 'Cannot read the exchange file.'"));
			ClearDataImportFileData();
			
		EndTry;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure DeletionCheckAll(Command)
	
	For Each Row In DataToDelete.GetItems() Do
		
		Row.Check = 1;
		SetSubordinateMarks(Row, "Mark");
		
	EndDo;
	
EndProcedure

&AtClient
Procedure DeletionCancelAll(Command)
	
	For Each Row In DataToDelete.GetItems() Do
		Row.Check = 0;
		SetSubordinateMarks(Row, "Mark");
	EndDo;
	
EndProcedure

&AtClient
Procedure DeletionDelete(Command)
	
	NotifyDescription = New NotifyDescription("DeletionDeleteCompletion", ThisObject);
	ShowQueryBox(NotifyDescription, NStr("en = 'Do you want to delete selected data?'"), QuestionDialogMode.YesNo, , DialogReturnCode.No);
	
EndProcedure

&AtClient
Procedure DeletionDeleteCompletion(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		Status(NStr("en = 'Deleting data. Please wait...'"));
		DeleteAtServer();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExportCheckAll(Command)
	
	For Each Row In Object.ExportRuleTable.GetItems() Do
		Row.PrivilegedModeOn = 1;
		SetSubordinateMarks(Row, "PrivilegedModeOn");
	EndDo;
	
EndProcedure

&AtClient
Procedure ExportCancelAll(Command)
	
	For Each Row In Object.ExportRuleTable.GetItems() Do
		Row.PrivilegedModeOn = 0;
		SetSubordinateMarks(Row, "PrivilegedModeOn");
	EndDo;
	
EndProcedure

&AtClient
Procedure ExportClearExchangeNodes(Command)
	
	FillExchangeNodeInTreeRowsAtServer(Undefined);
	
EndProcedure

&AtClient
Procedure ExportSetExchangeNode(Command)
	
	If Items.ExportRuleTable.CurrentData = Undefined Then
		Return;
	EndIf;
	
	FillExchangeNodeInTreeRowsAtServer(Items.ExportRuleTable.CurrentData.ExchangeNodeRef);
	
EndProcedure

&AtClient
Procedure SaveParameters(Command)
	
	SaveParametersAtServer();
	
EndProcedure

&AtClient
Procedure RestoreParameters(Command)
	
	RestoreParametersAtServer();
	
EndProcedure

&AtClient
Procedure ExportDebugSetup(Command)
	
	Object.ExchangeRuleFileName = FileNameAtServerOrClient(RuleFileName, RuleFileAddressInStorage);
	
	OpenHandlerDebugSetupForm(True);
	
EndProcedure

&AtClient
Procedure AtClient(Command)
	
	If Not IsClient Then
		
		IsClient = True;
		
		ChangeProcessingMode(IsClient);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AtServer(Command)
	
	If IsClient Then
		
		IsClient = False;
		
		ChangeProcessingMode(IsClient);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ImportDebugSetup(Command)
	
	ExchangeFileAddressInStorage = "";
	FileNameForExtension = "";
	
	If IsClient Then
		
		NotifyDescription = New NotifyDescription("ImportDebugSetupCompletion", ThisObject);
		BeginPutFile(NotifyDescription, ExchangeFileAddressInStorage,NStr("en = 'Exchange file'"),, UUID);
		
	Else
		
		If EmptyAttributeValue(ExchangeFileName, "ExchangeFileName", Items.ExchangeFileName.Title) Then
			Return;
		EndIf;
		
		ImportDebugSetupCompletion(True, ExchangeFileAddressInStorage, FileNameForExtension, Undefined);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ImportDebugSetupCompletion(Result, Address, SelectedFileName, AdditionalParameters) Export
	
	If Result Then
		
		Object.ExchangeFileName = FileNameAtServerOrClient(ExchangeFileName ,Address, SelectedFileName);
		
		OpenHandlerDebugSetupForm(False);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteExport(Command)
	
	ExecuteExportFromForm();
	
EndProcedure

&AtClient
Procedure ExecuteImport(Command)
	
	ExecuteImportFromForm();
	
EndProcedure

&AtClient
Procedure ReadExchangeRules(Command)
	
	If IsLinuxClient() And DirectExport = 1 Then
		ShowMessageBox(,NStr("en = 'Direct infobase connection is not supported if the client application is running on Linux.'"));
		Return;
	EndIf;
	
	FileNameForExtension = "";
	
	If IsClient Then
		
		NotifyDescription = New NotifyDescription("ReadExchangeRulesCompletion", ThisObject);
		BeginPutFile(NotifyDescription, RuleFileAddressInStorage,NStr("en = 'Exchange rule file'"),, UUID);
		
	Else
		
		RuleFileAddressInStorage = "";
		If EmptyAttributeValue(RuleFileName, "RuleFileName", Items.RuleFileName.Title) Then
			Return;
		EndIf;
		
		ReadExchangeRulesCompletion(True, RuleFileAddressInStorage, FileNameForExtension, Undefined);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ReadExchangeRulesCompletion(Result, Address, SelectedFileName, AdditionalParameters) Export
	
	If Result Then
		
		RuleFileAddressInStorage = Address;
		
		Status(NStr("en = 'Reading exchange rules. Please wait...'"));
		ExecuteImportExchangeRules(Address, SelectedFileName);
		
		If Object.ErrorFlag Then
			
			SetImportRuleFlag(False);
			
		Else
			
			SetImportRuleFlag(True);
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

// Opens an exchange file in an external application.
//
&AtClient
Procedure OpenInApplication(FileName, StandardProcessing = False)

	File = New File(FileName);
	
	If File.Exist() Then
		
		RunApp(FileName);
		
	EndIf;
	
	StandardProcessing = False;
	
EndProcedure

&AtClient
Procedure ClearDataImportFileData()
	
	Object.ExchangeRulesVersion = "";
	Object.DataExportDate = "";
	ExportPeriodPresentation = "";
	
EndProcedure

&AtClient
Procedure ProcessTransactionManagementItemsEnabled()
	
	Items.UseTransactions.Enabled = Not Object.DebugModeFlag;
	
	Items.ObjectCountPerTransaction.Enabled = Object.UseTransactions;
	
EndProcedure

&AtClient
Procedure ArchiveFileOnValueChange()
	
	If Object.ArchiveFile Then
		DataFileName = StrReplace(DataFileName, ".xml", ".zip");
	Else
		DataFileName = StrReplace(DataFileName, ".zip", ".xml");
	EndIf;
	
	Items.ExchangeFileCompressionPassword.Enabled = Object.ArchiveFile;
	
EndProcedure

&AtServer
Procedure FillExchangeNodeInTreeRows(Tree, ExchangeNode)
	
	For Each Row In Tree Do
		
		If Row.IsFolder Then
			
			FillExchangeNodeInTreeRows(Row.GetItems(), ExchangeNode);
			
		Else
			
			Row.ExchangeNodeRef = ExchangeNode;
			
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClient
Function RuleAndExchangeFileNamesMatch()
	
	If Upper(TrimAll(RuleFileName)) = Upper(TrimAll(DataFileName)) Then
		
		MessageToUser(NStr("en = 'A rule file name and a data file name cannot be identical.
		|Select another file to export data.'"));
		Return True;
		
	Else
		
		Return False;
		
	EndIf;
	
EndFunction

// Fills a value tree with metadata objects available for deletion
&AtServer
Procedure FillTypeAvailableToDeleteList()
	
	DataTree = FormAttributeToValue("DataToDelete");
	
	DataTree.Rows.Clear();
	
	TreeRow = DataTree.Rows.Add();
	TreeRow.Presentation = NStr("en = 'Catalogs'");
	
	For Each MDObject In Metadata.Catalogs Do
		
		If Not AccessRight("Delete", MDObject) Then
			Continue;
		EndIf;
		
		MDRow = TreeRow.Rows.Add();
		MDRow.Presentation = MDObject.Name;
		MDRow.Metadata = "CatalogRef." + MDObject.Name;
		
	EndDo;
	
	TreeRow = DataTree.Rows.Add();
	TreeRow.Presentation = NStr("en = 'Charts of characteristic types'");
	
	For Each MDObject In Metadata.ChartsOfCharacteristicTypes Do
		
		If Not AccessRight("Delete", MDObject) Then
			Continue;
		EndIf;
		
		MDRow = TreeRow.Rows.Add();
		MDRow.Presentation = MDObject.Name;
		MDRow.Metadata = "ChartOfCharacteristicTypesRef." + MDObject.Name;
		
	EndDo;
	
	TreeRow = DataTree.Rows.Add();
	TreeRow.Presentation = NStr("en = 'Documents'");
	
	For Each MDObject In Metadata.Documents Do
		
		If Not AccessRight("Delete", MDObject) Then
			Continue;
		EndIf;
		
		MDRow = TreeRow.Rows.Add();
		MDRow.Presentation = MDObject.Name;
		MDRow.Metadata = "DocumentRef." + MDObject.Name;
		
	EndDo;
	
	TreeRow = DataTree.Rows.Add();
	TreeRow.Presentation = NStr("en = 'Information registers'");
	
	For Each MDObject In Metadata.InformationRegisters Do
		
		If Not AccessRight("Delete", MDObject) Then
			Continue;
		EndIf;
		
		Subordinate = (MDObject.WriteMode = Metadata.ObjectProperties.RegisterWriteMode.RecorderSubordinate);
		If Subordinate Then Continue EndIf;
		
		MDRow = TreeRow.Rows.Add();
		MDRow.Presentation = MDObject.Name;
		MDRow.Metadata = "InformationRegisterRecord." + MDObject.Name;
		
	EndDo;
	
	ValueToFormAttribute(DataTree, "DataToDelete");
	
EndProcedure

// Returns data processor version.
&AtServer
Function ObjectVersionStringAtServer()
	
	Return FormAttributeToValue("Object").ObjectVersionString();
	
EndFunction

&AtClient
Procedure ExecuteImportExchangeRules(RuleFileAddressInStorage = "", FileNameForExtension = "")
	
	Object.ErrorFlag = False;
	
	ImportExchangeRulesAndParametersAtServer(RuleFileAddressInStorage, FileNameForExtension);
	
	If Object.ErrorFlag Then
		
		SetImportRuleFlag(False);
		
	Else
		
		SetImportRuleFlag(True);
		ExpandTreeRows(Object.ExportRuleTable, Items.ExportRuleTable, "PrivilegedModeOn");
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExpandTreeRows(DataTree, PresentationOnForm, FlagName)
	
	TreeRows = DataTree.GetItems();
	
	For Each Row In TreeRows Do
		
		RowID = Row.GetID();
		PresentationOnForm.Expand(RowID, False);
		EnableParentIfSubordinateItemsEnabled(Row, FlagName);
		
	EndDo;
	
EndProcedure

&AtClient
Procedure EnableParentIfSubordinateItemsEnabled(TreeRow, FlagName)
	
	PrivilegedModeOn = TreeRow[FlagName];
	
	For Each SubordinateRow In TreeRow.GetItems() Do
		
		If SubordinateRow[FlagName] = 1 Then
			
			PrivilegedModeOn = 1;
			
		EndIf;
		
		If SubordinateRow.GetItems().Count() > 0 Then
			
			EnableParentIfSubordinateItemsEnabled(SubordinateRow, FlagName);
			
		EndIf;
		
	EndDo;
	
	TreeRow[FlagName] = PrivilegedModeOn;
	
EndProcedure

&AtClient
Procedure OnPeriodChange()
	
	Object.StartDate = ExportPeriod.StartDate;
	Object.EndDate   = ExportPeriod.EndDate;
	
EndProcedure

&AtServer
Procedure ImportExchangeRulesAndParametersAtServer(RuleFileAddressInStorage, FileNameForExtension)
	
	ExchangeRuleFileName = FileNameAtServerOrClient(RuleFileName ,RuleFileAddressInStorage, FileNameForExtension);
	
	If ExchangeRuleFileName = Undefined Then
		
		Return;
		
	Else
		
		Object.ExchangeRuleFileName = ExchangeRuleFileName;
		
	EndIf;
	
	ObjectForServer = FormAttributeToValue("Object");
	ObjectForServer.ExportRuleTable = FormAttributeToValue("Object.ExportRuleTable");
	ObjectForServer.ParameterSetupTable = FormAttributeToValue("Object.ParameterSetupTable");
	
	ObjectForServer.ImportExchangeRules();
	ObjectForServer.InitializeInitialParameterValues();
	ObjectForServer.Parameters.Clear();
	Object.ErrorFlag = ObjectForServer.ErrorFlag;
	
	If IsClient Then
		
		DeleteFiles(Object.ExchangeRuleFileName);
		
	EndIf;
	
	ValueToFormAttribute(ObjectForServer.ExportRuleTable, "Object.ExportRuleTable");
	ValueToFormAttribute(ObjectForServer.ParameterSetupTable, "Object.ParameterSetupTable");
	
EndProcedure

// Opens file selection dialog.
//
// Parameters:
//  Item           - control where a file is selected. 
//  CheckExistence - if True, selection is canceled if the specified file does not exist.
// 
&AtClient
Procedure SelectFile(Item, PropertyName, CheckForExistence=False, Val DefaultExtension = "xml",
	ArchiveDataFile = True, RuleFileSelection = False)
	
	FileDialog = New FileDialog(FileDialogMode.Open);

	If DefaultExtension = "txt" Then
		
		FileDialog.Filter = "Exchange log file (*.txt)|*.txt";
		FileDialog.DefaultExt = "txt";
		
	ElsIf Object.ExchangeMode = "Data" Then
		
		If ArchiveDataFile Then
			
			FileDialog.Filter = "Archived data file (*.zip)|*.zip";
			FileDialog.DefaultExt = "zip";
			
		ElsIf RuleFileSelection Then
			
			FileDialog.Filter = "Data file (*.xml)|*.xml|Archived data file (*.zip)|*.zip";
			FileDialog.DefaultExt = "xml";
			
		Else
			
			FileDialog.Filter = "Data file (*.xml)|*.xml";
			FileDialog.DefaultExt = "xml";
			
		EndIf; 
		
	Else
		
		FileDialog.Filter = "Data file (*.xml)|*.xml|Archived data file (*.zip)|*.zip";
		FileDialog.DefaultExt = "xml";
		
	EndIf;
	
	FileDialog.Title = NStr("en = 'Select file'");
	FileDialog.Preview = False;
	FileDialog.FilterIndex = 0;
	FileDialog.FullFileName = Item.EditText;
	FileDialog.CheckFileExist = CheckForExistence;
	
	If FileDialog.Choose() Then
		
		PropertyName = FileDialog.FullFileName;
		
		If Item = Items.RuleFileName Then
			RuleFileNameOnChange(Item);
			
		ElsIf Item = Items.ExchangeFileName Then
			ExchangeFileNameOnChange(Item);
			
		ElsIf Item = Items.DataFileName Then
			DataFileNameOnChange(Item);
	
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Function EstablishConnectionWithTargetInfobaseAtServer()
	
	ObjectForServer = FormAttributeToValue("Object");
	FillPropertyValues(ObjectForServer, Object);
	ConnectionResult = ObjectForServer.EstablishConnectionWithTargetInfobase();
	
	If ConnectionResult <> Undefined Then
		
		MessageToUser(NStr("en = 'Connection established.'"));
		
	EndIf;
	
EndFunction

// Sets mark values in subordinate tree rows according to the mark value in the current row.
//
// Parameters:
//  CurRow - Value tree row.
// 
&AtClient
Procedure SetSubordinateMarks(CurRow, FlagName)
	
	Subordinate = CurRow.GetItems();
	
	If Subordinate.Count() = 0 Then
		Return;
	EndIf;
	
	For Each Row In Subordinate Do
		
		Row[FlagName] = CurRow[FlagName];
		
		SetSubordinateMarks(Row, FlagName);
		
	EndDo;
		
EndProcedure

// Sets mark values in parent tree rows according to the mark value in the current row.
//
// Parameters:
//  CurRow - Value tree row.
// 
&AtClient
Procedure SetParentMarks(CurRow, FlagName)
	
	Parent = CurRow.GetParent();
	If Parent = Undefined Then
		Return;
	EndIf; 
	
	CurState = Parent[FlagName];
	
	EnabledItemsFound  = False;
	DisabledItemsFound = False;
	
	For Each Row In Parent.GetItems() Do
		If Row[FlagName] = 0 Then
			DisabledItemsFound = True;
		ElsIf Row[FlagName] = 1
			Or Row[FlagName] = 2 Then
			EnabledItemsFound  = True;
		EndIf; 
		If EnabledItemsFound And DisabledItemsFound Then
			Break;
		EndIf; 
	EndDo;
	
	If EnabledItemsFound And DisabledItemsFound Then
		PrivilegedModeOn = 2;
	ElsIf EnabledItemsFound And (Not DisabledItemsFound) Then
		PrivilegedModeOn = 1;
	ElsIf (Not EnabledItemsFound) And DisabledItemsFound Then
		PrivilegedModeOn = 0;
	ElsIf (Not EnabledItemsFound) And (Not DisabledItemsFound) Then
		PrivilegedModeOn = 2;
	EndIf;
	
	If PrivilegedModeOn = CurState Then
		Return;
	Else
		Parent[FlagName] = PrivilegedModeOn;
		SetParentMarks(Parent, FlagName);
	EndIf; 
	
EndProcedure

&AtServer
Procedure OpenImportFileAtServer(FileURL)
	
	If IsClient Then
		
		BinaryData = GetFromTempStorage (FileURL);
		AddressOnServer = GetTempFileName(".xml");
		BinaryData.Write(AddressOnServer);
		Object.ExchangeFileName = AddressOnServer;
		
	Else
		
		FileOnServer = New File(ExchangeFileName);
		
		If Not FileOnServer.Exist() Then
			
			MessageToUser(NStr("en = 'Exchange file not found on the server.'"), "ExchangeFileName");
			Return;
			
		EndIf;
		
		Object.ExchangeFileName = ExchangeFileName;
		
	EndIf;
	
	ObjectForServer = FormAttributeToValue("Object");
	
	ObjectForServer.OpenImportFile(True);
	
	Object.StartDate = ObjectForServer.StartDate;
	Object.EndDate = ObjectForServer.EndDate;
	Object.DataExportDate = ObjectForServer.DataExportDate;
	Object.ExchangeRulesVersion = ObjectForServer.ExchangeRulesVersion;
	Object.Comment = ObjectForServer.Comment;
	
EndProcedure

// Deletes marked metadata tree rows.
//
&AtServer
Procedure DeleteAtServer()
	
	ObjectForServer = FormAttributeToValue("Object");
	DataBeingDeletedTree = FormAttributeToValue("DataToDelete");
	
	ObjectForServer.InitManagersAndMessages();
	
	For Each TreeRow In DataBeingDeletedTree.Rows Do
		
		For Each MDRow In TreeRow.Rows Do
			
			If Not MDRow.Check Then
				Continue;
			EndIf;
			
			TypeString = MDRow.Metadata;
			ObjectForServer.DeleteObjectsOfType(TypeString);
			
		EndDo;
		
	EndDo;
	
EndProcedure

// Fills exchange nodes in tree rows.
//
&AtServer
Procedure FillExchangeNodeInTreeRowsAtServer(ExchangeNode)
	
	FillExchangeNodeInTreeRows(Object.ExportRuleTable.GetItems(), ExchangeNode);
	
EndProcedure

//Saves parameter values.
//
&AtServer
Procedure SaveParametersAtServer()
	
	ParameterTable = FormAttributeToValue("Object.ParameterSetupTable");
	
	ParametersToSave = New Structure;
	
	For Each TableRow In ParameterTable Do
		ParametersToSave.Insert(TableRow.Description, TableRow.Value);
	EndDo;
	
	SystemSettingsStorage.Save("UniversalDataExchangeXML", "Parameters", ParametersToSave);
	
EndProcedure

//Restores parameter values.
//
&AtServer
Procedure RestoreParametersAtServer()
	
	ParameterTable = FormAttributeToValue("Object.ParameterSetupTable");
	RestoredParameters = SystemSettingsStorage.Load("UniversalDataExchangeXML", "Parameters");
	
	If TypeOf(RestoredParameters) <> Type("Structure") Then
		Return;
	EndIf;
	
	If RestoredParameters.Count() = 0 Then
		Return;
	EndIf;
	
	For Each Param In RestoredParameters Do
		
		ParameterName = Param.Key;
		
		TableRow = ParameterTable.Find(Param.Key, "Description");
		
		If TableRow <> Undefined Then
			
			TableRow.Value = Param.Value;
			
		EndIf;
		
	EndDo;
	
	ValueToFormAttribute(ParameterTable, "Object.ParameterSetupTable");
	
EndProcedure

//Performs interactive data export.
//
&AtClient
Procedure ExecuteImportFromForm()
	
	FileURL = "";
	FileNameForExtension = "";
	
	AddRowToChoiceList(Items.ExchangeFileName.ChoiceList, ExchangeFileName, DataImportFromFile);
	
	If IsClient Then
		
		NotifyDescription = New NotifyDescription("ExecuteImportFromFormCompletion", ThisObject);
		BeginPutFile(NotifyDescription, FileURL,NStr("en = 'Exchange file'"),, UUID);
		
	Else
		
		If EmptyAttributeValue(ExchangeFileName, "ExchangeFileName", Items.ExchangeFileName.Title) Then
			Return;
		EndIf;
		
		ExecuteImportFromFormCompletion(True, FileURL, FileNameForExtension, Undefined);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteImportFromFormCompletion(Result, Address, SelectedFileName, AdditionalParameters) Export
	
	If Result Then
		
		Status(NStr("en = 'Importing data. Please wait...'"));
		ExecuteImportAtServer(Address, SelectedFileName);
		
		OpenExchangeProtocolDataIfNecessary();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ExecuteImportAtServer(FileURL, FileNameForExtension)
	
	FileToBeImportedName = FileNameAtServerOrClient(ExchangeFileName ,FileURL, FileNameForExtension);
	
	If FileToBeImportedName = Undefined Then
		
		Return;
		
	Else
		
		Object.ExchangeFileName = FileToBeImportedName;
		
	EndIf;
	
	ObjectForServer = FormAttributeToValue("Object");
	FillPropertyValues(ObjectForServer, Object);
	ObjectForServer.ExecuteImport();
	
	Try
		
		If Not IsBlankString(FileURL) Then
			DeleteFiles(FileToBeImportedName);
		EndIf;
		
	Except
		
	EndTry;
	
	ObjectForServer.Parameters.Clear();
	ValueToFormAttribute(ObjectForServer, "Object");
	
	RulesLoaded = False;
	Items.FormExecuteExport.Enabled = False;
	Items.ExportDetailsLabel.Visible = True;
	Items.ExportDebugEnabledGroup.Enabled = False;
	
EndProcedure

&AtServer
Function FileNameAtServerOrClient(AttributeName ,Val FileURL = "", Val FileNameForExtension = ".xml",
									CreateNew = False, CheckForExistence = True)
	
	FileName = Undefined;
	
	If IsClient Then
		
		If CreateNew Then
			
			Extension = ? (Object.ArchiveFile, ".zip", ".xml");
			
			FileName = GetTempFileName(Extension);
			
			File = New File(FileName);
			
		Else
			
			Extension = FileExtention(FileNameForExtension);
			BinaryData = GetFromTempStorage(FileURL);
			AddressOnServer = GetTempFileName(Extension);
			BinaryData.Write(AddressOnServer);
			FileName = AddressOnServer;
			
		EndIf;
		
	Else
		
		FileOnServer = New File(AttributeName);
		
		If Not FileOnServer.Exist() And CheckForExistence Then
			
			MessageToUser(NStr("en = 'The file does not exist.'"));
			
		Else
			
			FileName = AttributeName;
			
		EndIf;
		
	EndIf;
	
	Return FileName;
	
EndFunction

&AtServer
Function FileExtention(Val FileName)
	
	DotPosition = LastSeparator(FileName);
	
	Extension = Right(FileName,StrLen(FileName) - DotPosition + 1);
	
	Return Extension;
	
EndFunction

&AtServer
Function LastSeparator(StringWithSeparator, Separator = ".")
	
	StringLength = StrLen(StringWithSeparator);
	
	While StringLength > 0 Do
		
		If Mid(StringWithSeparator, StringLength, 1) = Separator Then
			
			Return StringLength; 
			
		EndIf;
		
		StringLength = StringLength - 1;
		
	EndDo;

EndFunction

&AtClient
Procedure ExecuteExportFromForm()
	
	// Adding rule file name and data file name to the selection list
	AddRowToChoiceList(Items.RuleFileName.ChoiceList, RuleFileName, ExchangeRules);
	
	If Not Object.DirectReadingInTargetInfobase and Not IsClient Then
		
		If RuleAndExchangeFileNamesMatch() Then
			Return;
		EndIf;
		
		AddRowToChoiceList(Items.DataFileName.ChoiceList, DataFileName, DataExportToFile);
		
	EndIf;
	
	Status(NStr("en = 'Exporting data. Please wait...'"));
	DataFileAddressInStorage = ExecuteExportAtServer();
	
	If DataFileAddressInStorage = Undefined Then
		Return;
	EndIf;
	
	ExpandTreeRows(Object.ExportRuleTable, Items.ExportRuleTable, "PrivilegedModeOn");
	
	If IsClient And Not DirectExport And Not Object.ErrorFlag Then
		
		FileToBeSavedName = ?(Object.ArchiveFile, NStr("en = 'Export file.zip'"),NStr("en = 'Export file.xml'"));
		
		GetFile(DataFileAddressInStorage, FileToBeSavedName)
		
	EndIf;
	
	OpenExchangeProtocolDataIfNecessary();
	
EndProcedure

&AtServer
Function ExecuteExportAtServer()
	
	Object.ExchangeRuleFileName = FileNameAtServerOrClient(RuleFileName, RuleFileAddressInStorage);
	
	If Not DirectExport Then
		
		TemporaryDataFileName = FileNameAtServerOrClient(DataFileName, ,,True, False);
		
		If TemporaryDataFileName = Undefined Then
			
			Return Undefined;
			MessageToUser(NStr("en = 'The data file is not specified'"));
			
		Else
			
			Object.ExchangeFileName = TemporaryDataFileName;
			
		EndIf;
		
	EndIf;
	
	ExportRuleTable = FormAttributeToValue("Object.ExportRuleTable");
	ParameterSetupTable = FormAttributeToValue("Object.ParameterSetupTable");
	
	ObjectForServer = FormAttributeToValue("Object");
	FillPropertyValues(ObjectForServer, Object);
	
	If ObjectForServer.HandlerDebugModeFlag Then
		
		Cancel = False;
		
		File = New File(ObjectForServer.EventHandlerExternalDataProcessorFileName);
		
		If Not File.Exist() Then
			
			MessageToUser(NStr("en = 'Event debugger external data processor file does not exist on the server'"));
			Return Undefined;
			
		EndIf;
		
		ObjectForServer.ExportEventHandlers(Cancel);
		
		If Cancel Then
			
			MessageToUser(NStr("en = 'Cannot export event handlers'"));
			Return "";
			
		EndIf;
		
	Else
		
		ObjectForServer.ImportExchangeRules();
		ObjectForServer.InitializeInitialParameterValues();
		
	EndIf;
	
	ChangeExportRuleTree(ObjectForServer.ExportRuleTable.Rows, ExportRuleTable.Rows);
	ChangeParameterTable(ObjectForServer.ParameterSetupTable, ParameterSetupTable);
	
	ObjectForServer.ExecuteExport();
	ObjectForServer.ExportRuleTable = FormAttributeToValue("Object.ExportRuleTable");
	
	If IsClient And Not DirectExport Then
		
		DataFileAddress = PutToTempStorage(New BinaryData(Object.ExchangeFileName), UUID);
		DeleteFiles(Object.ExchangeFileName);
		
	Else
		
		DataFileAddress = "";
		
	EndIf;
	
	If IsClient Then
		
		DeleteFiles(ObjectForServer.ExchangeRuleFileName);
		
	EndIf;
	
	ObjectForServer.Parameters.Clear();
	ValueToFormAttribute(ObjectForServer, "Object");
	
	Return DataFileAddress;
	
EndFunction

&AtClient
Procedure SetDebugCommandsEnabled();
	
	Items.ImportDebugSetup.Enabled = Object.HandlerDebugModeFlag;
	Items.ExportDebugSetup.Enabled = Object.HandlerDebugModeFlag;
	
EndProcedure

// Modifies an exchange rule tree according to the tree specified in the form.
//
&AtServer
Procedure ChangeExportRuleTree(InitialTreeRows, TreeToReplaceRows)
	
	EnableColumn = TreeToReplaceRows.UnloadColumn("PrivilegedModeOn");
	InitialTreeRows.LoadColumn(EnableColumn, "PrivilegedModeOn");
	NodeColumn = TreeToReplaceRows.UnloadColumn("ExchangeNodeRef");
	InitialTreeRows.LoadColumn(NodeColumn, "ExchangeNodeRef");
	
	For Each InitialTreeRow In InitialTreeRows Do
		
		LineIndex = InitialTreeRows.IndexOf(InitialTreeRow);
		TreeToReplaceRow = TreeToReplaceRows.Get(LineIndex);
		
		ChangeExportRuleTree(InitialTreeRow.Rows, TreeToReplaceRow.Rows);
		
	EndDo;
	
EndProcedure

// Modifies a parameter table according to the table specified in the form.
//
&AtServer
Procedure ChangeParameterTable(BaseTable, FormTable)
	
	DescriptionColumn = FormTable.UnloadColumn("Description");
	BaseTable.LoadColumn(DescriptionColumn, "Description");
	ValueColumn = FormTable.UnloadColumn("Value");
	BaseTable.LoadColumn(ValueColumn, "Value");
	
EndProcedure

&AtClient
Procedure DirectExportOnValueChange()
	
	ExportParameters = Items.ExportParameters;
	
	ExportParameters.CurrentPage = ?(DirectExport = 0,
										  ExportParameters.ChildItems.ExportToFile,
										  ExportParameters.ChildItems.ExportToTargetInfobase);
	
	Object.DirectReadingInTargetInfobase = (DirectExport = 1);
	
	InfobaseConnectionTypeOnValueChange();
	
EndProcedure

Procedure InfobaseConnectionTypeOnValueChange()
	
	BaseType = Items.BaseType;
	BaseType.CurrentPage = ?(Object.InfobaseConnectionType,
								BaseType.ChildItems.FileInfobase,
								BaseType.ChildItems.BaseOnServer);
	
EndProcedure

&AtClient
Procedure AddRowToChoiceList(ValueListToSave, SavingValue, ParameterNameToSave)
	
	If IsBlankString(SavingValue) Then
		Return;
	EndIf;
	
	FoundItem = ValueListToSave.FindByValue(SavingValue);
	If FoundItem <> Undefined Then
		ValueListToSave.Delete(FoundItem);
	EndIf;
	
	ValueListToSave.Insert(0, SavingValue);
	
	While ValueListToSave.Count() > 10 Do
		ValueListToSave.Delete(ValueListToSave.Count() - 1);
	EndDo;
	
	ParameterNameToSave = ValueListToSave;
	
EndProcedure

&AtClient
Procedure OpenHandlerDebugSetupForm(EventHandlersFromRuleFile)
	
	DataProcessorName = Left(FormName, LastSeparator(FormName));
	FormNameToCall = DataProcessorName + "HandlerDebugSetupManagedForm";
	
	FormParameters = New Structure;
	FormParameters.Insert("EventHandlerExternalDataProcessorFileName", Object.EventHandlerExternalDataProcessorFileName);
	FormParameters.Insert("AlgorithmDebugMode", Object.AlgorithmDebugMode);
	FormParameters.Insert("ExchangeRuleFileName", Object.ExchangeRuleFileName);
	FormParameters.Insert("ExchangeFileName", Object.ExchangeFileName);
	FormParameters.Insert("ReadEventHandlersFromExchangeRuleFile", EventHandlersFromRuleFile);
	FormParameters.Insert("DataProcessorName", DataProcessorName);
	
	Mode = FormWindowOpeningMode.LockOwnerWindow;
	Handler = New NotifyDescription("OpenHandlerDebugSetupFormCompletion", ThisObject, EventHandlersFromRuleFile);
	DebugParameters = OpenForm(FormNameToCall, FormParameters, ThisObject,,,,Handler, Mode);
	
EndProcedure

&AtClient
Procedure OpenHandlerDebugSetupFormCompletion(DebugParameters, EventHandlersFromRuleFile) Export
	
	If DebugParameters <> Undefined Then
		
		FillPropertyValues(Object, DebugParameters);
		
		If IsClient Then
			
			If EventHandlersFromRuleFile Then
				
				FileName = Object.ExchangeRuleFileName;
				
			Else
				
				FileName = Object.ExchangeFileName;
				
			EndIf;
			
			DeleteFiles(FileName);
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ChangeFileLocation()
	
	Items.RuleFileName.Visible     = Not IsClient;
	Items.DataFileName.Visible     = Not IsClient;
	Items.ExchangeFileName.Visible = Not IsClient;
	
	SetImportRuleFlag(False);
	
EndProcedure

&AtClient
Procedure ChangeProcessingMode(Mode)
	
	ModeGroup = CommandBar.ChildItems.ProcessingMode.ChildItems;
	
	ModeGroup.FormOnClient.Check = Mode;
	ModeGroup.FormOnServer.Check = Not Mode;
	
	CommandBar.ChildItems.ProcessingMode.Title = 
	?(Mode, NStr("en = 'Mode (client)'"), NStr("en = 'Mode (server)'"));
	
	Object.ExportRuleTable.GetItems().Clear();
	Object.ParameterSetupTable.Clear();
	
	ChangeFileLocation();
	
EndProcedure

&AtClient
Procedure OpenExchangeProtocolDataIfNecessary()
	
	If Not Object.OpenExchangeLogsAfterOperationsExecuted Then
		Return;
	EndIf;
	
	#If Not WebClient Then
		
		If Not IsBlankString(Object.ExchangeLogFileName) Then
			OpenInApplication(Object.ExchangeLogFileName);
		EndIf;
		
		If Object.DirectReadingInTargetInfobase Then
			
			Object.ImportExchangeLogFileName = GetProtocolNameForSecondCOMConnectionInfobaseAtServer();
			
			If Not IsBlankString(Object.ImportExchangeLogFileName) Then
				OpenInApplication(Object.ImportLogName);
			EndIf;
			
		EndIf;
		
	#EndIf
	
EndProcedure

&AtServer
Function GetProtocolNameForSecondCOMConnectionInfobaseAtServer()
	
	Return FormAttributeToValue("Object").GetProtocolNameForCOMConnectionSecondInfobase();
	
EndFunction

&AtClient
Function EmptyAttributeValue(Attribute, DataPath, Title)
	
	If IsBlankString(Attribute) Then
		
		MessageText = NStr("en = 'Field ""%1"" is empty'");
		MessageText = StrReplace(MessageText, "%1", Title);
		
		MessageToUser(MessageText, DataPath);
		
		Return True;
		
	Else
		
		Return False;
		
	EndIf;
	
EndFunction

&AtClient
Procedure SetImportRuleFlag(Flag)
	
	RulesLoaded = Flag;
	Items.FormExecuteExport.Enabled = Flag;
	Items.ExportDetailsLabel.Visible = Not Flag;
	Items.ExportDebugGroup.Enabled = Flag;
	
EndProcedure

&AtClientAtServerNoContext
Procedure MessageToUser(Text, DataPath = "")
	
	Message = New UserMessage;
	Message.Text = Text;
	Message.DataPath = DataPath;
	Message.Message();
	
EndProcedure

// Returns True if the client application is running on Linux.
//
// Returns:
//  Boolean. Returns False if the client OS is not Linux.
//
&AtClient
Function IsLinuxClient()
	
	SystemInfo = New SystemInfo;
	
	IsLinuxClient = SystemInfo.PlatformType = PlatformType.Linux_x86
				 Or SystemInfo.PlatformType = PlatformType.Linux_x86_64;
	
	Return IsLinuxClient;
	
EndFunction

&AtServer
Function CheckPlatformVersionAndCompatibilityMode()
	
	Information = New SystemInfo;
	If Not (Left(Information.AppVersion, 3) = "8.3"
		And (Metadata.CompatibilityMode = Metadata.ObjectProperties.CompatibilityMode.DontUse
		OR (Metadata.CompatibilityMode <> Metadata.ObjectProperties.CompatibilityMode.Version8_1
		And Metadata.CompatibilityMode <> Metadata.ObjectProperties.CompatibilityMode.Version8_2_13
		And Metadata.CompatibilityMode <> Metadata.ObjectProperties.CompatibilityMode["Version8_2_16"]
		And Metadata.CompatibilityMode <> Metadata.ObjectProperties.CompatibilityMode["Version8_3_1"]
		And Metadata.CompatibilityMode <> Metadata.ObjectProperties.CompatibilityMode["Version8_3_2"]))) Then
		
		Raise NStr("en = 'This data processor is intended to
			|run on 1C:Enterprise platform version 8.3 or later (with disabled compatibility mode)'");
		
	EndIf;
	
EndFunction

#EndRegion
