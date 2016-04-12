&AtClient
Var HandlerParameters;

&AtClient
Var LongActionForm;

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardDataProcessor)
	
	If Parameters.Property("Autotest") Then
		Return;
	EndIf;
	
	If Parameters.Scenario = "ReferenceSearch" Then 
		ImportType = "ReferenceSearch";
	EndIf;

	SetDataAppearance();
	
	CreateIfNotMapped = 1;
	UpdateExisting = 0;
	
	StandardSubsystemsServer.SetGroupTitleRepresentation(ThisObject);
	
	If ValueIsFilled(Parameters.Title) Then 
		ThisObject.AutoTitle = False;
		ThisObject.Title = Parameters.Title;
	EndIf;

	If Parameters.Scenario = "ReferenceSearch" Then 
		MappingTableFilter = "Unmapped";
		If Parameters.Property("FieldPresentation") Then
			Title = NStr("en = 'Paste from clipboard") + " (" + Parameters.FieldPresentation 
+ ")";
			ThisObject.AutoTitle = False;
		Else
			Title = NStr("en = 'Paste from clipboard'");
		EndIf;
		
		DataProcessors.DataImportFromFile.InitRefSearchMode(TemplateWithData, ColumnInfo, Parameters.TypeDescription);
		CreateMappingTableByColumnInfoAuto(Parameters.TypeDescription);
		
		If ColumnInfo.Count() = 1 Then 
			Items.DataFillPages.CurrentPage = Items.PageOneColumn;
			Items.AddToList.Visible = False;
			Items.Next.Title = NStr("en = 'Add to list'");
		Else
			Items.DataFillPages.CurrentPage = Items.ManyColumnsPage;
		EndIf;
		
		Items.WizardPages.CurrentPage = Items.FillTableWithData;
		Items.MappingSettingsGroup.Visible = False;
		Items.MappingByColumn.Visible = False;
		Items.Close.Title = NStr("en = 'Cancel'");
		
	Else
		If Not ValueIsFilled(Parameters.FullTabularSectionName) Then 
			FillDataImportTypeList();
			Items.WizardPages.CurrentPage = Items.SelectCatalogForImport;
		Else
			MappingObjectName = DataProcessors.DataImportFromFile.FullTabularSectionObjectName(Parameters.FullTabularSectionName);
			ImportType = "TabularSection";
			DataProcessors.DataImportFromFile.InitializeImportToTabularSection(MappingObjectName, Parameters.TemplateNameWithTemplate, ColumnInfo, TemplateWithData, Cancel);
			If Cancel Then
				Return;
			EndIf;
			ShowInfoBarAboutMandatoryColumns();
			Items.WizardPages.CurrentPage = Items.FillTableWithData;
			Items.MappingSettingsGroup.Visible = False;
			Items.MappingByColumn.Visible = False;
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardDataProcessor)
	If OpenCatalogAfterWizardClosed Then 
		OpenForm(ListForm(MappingObjectName));
	EndIf;
EndProcedure


#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ResolveConflict(Command)
	OpenResolveConflictForm(Items.DataMappingTable.CurrentRow,Items.DataMappingTable.CurrentItem.Name, True);
EndProcedure

&AtClient
Procedure Map(Command)
	MappedByColumnsNumber = 0;
	ColumnList = "";
	MapBySelectedAttrubute(MappedByColumnsNumber, ColumnList);
	Items.Map.Check = True;
	ShowUserNotification(NStr("en = 'Mapping completed'"),, NStr("en = 'Items mapped:'") + " " + String(MappedByColumnsNumber));
	ShowCompareStatisticsImportFromFile();
	
EndProcedure

&AtClient
Procedure AddToList(Command)
	CloseFormAndReturnRefArray();
EndProcedure

&AtClient
Procedure Next(Command)
	
	If Items.WizardPages.CurrentPage = Items.SelectCatalogForImport Then 
		SelectionRowDescription = Items.DataImportType.CurrentData.Value;
		ExecuteStepFillTableWithDataAtServer(SelectionRowDescription);
		ExecuteStepFillTableWithDataAtClient();
	ElsIf Items.WizardPages.CurrentPage = Items.FillTableWithData Then
		ExecuteDataToImportMappingStep();
	ElsIf Items.WizardPages.CurrentPage = Items.MappingResults Then
		Items.WizardPages.CurrentPage = Items.DataToImportMapping;
		Items.AddToList.Visible = False;
		Items.Next.Title = NStr("en = 'Add to list'");
		Items.Next.DefaultButton = True;
		Items.Back.Title = NStr("en = '< To the beginning'");
	ElsIf Items.WizardPages.CurrentPage = Items.DataToImportMapping Then
		Items.AddToList.Visible = False;
		If ImportType = "TabularSection" Then
			Filter = New Structure("RowMappingResult", "NotMapped");
			Rows = DataMappingTable.FindRows(Filter);
			
			If Rows.Count() > 0 Then
				ShowMessageBox(Undefined, NStr("en = 'To start data import, fill all rows of the mandatory columns'"),, NStr("en = 'Missing data'"));
				Return;
			EndIf;
			
			ImportedDataAddress = MappingTableAddressInStorage();
			Close(ImportedDataAddress);
		ElsIf ImportType = "ReferenceSearch" Then
			Items.Back.Title = NStr("en = '< To the beginning_'");
			CloseFormAndReturnRefArray();
		Else
			Items.WizardPages.CurrentPage = Items.LongActions;
			WriteDataToImportClient();
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure FillMappingTableFromTempStorage()
	MappedData = GetFromTempStorage(BackgroundJobStorageAddress);
	ValueToFormAttribute(MappedData, "DataMappingTable");
EndProcedure

&AtClient
Procedure CloseFormAndReturnRefArray()
	RefArray = New Array;
	For Each Row In DataMappingTable Do
		If ValueIsFilled(Row.MappingObject) Then
			RefArray.Add(Row.MappingObject);
		EndIf;
	EndDo;
	
	Close(RefArray);
EndProcedure

&AtClient
Procedure Back(Command)
	
	If Items.WizardPages.CurrentPage = Items.FillTableWithData Then
		Items.WizardPages.CurrentPage = Items.SelectCatalogForImport;
		Items.Back.Visible = False;
		ClearTable();
	ElsIf Items.WizardPages.CurrentPage = Items.DataToImportMapping Or Items.WizardPages.CurrentPage = Items.NotFound Then
		Items.WizardPages.CurrentPage = Items.FillTableWithData; 
		Items.AddToList.Visible = False;
		Items.Next.DefaultButton = True;
		Items.Next.Visible = True;
		If ImportType = "ReferenceSearch" Then 
			Items.Next.Title = NStr("en = 'Add to list'");
			Items.Back.Visible = False;
		Else
			Items.Next.Title = NStr("en = 'Next >'");
		EndIf;
		
	ElsIf Items.WizardPages.CurrentPage = Items.DataImportReport Then
		Items.OpenCatalogAfterWizardClosed.Visible = False;
		Items.WizardPages.CurrentPage = Items.DataToImportMapping;
	EndIf;
	
EndProcedure

&AtClient
Procedure ExportTemplateToFile(Command)
	
	If AttachFileSystemExtension() Then
		If CommonUseClient.SubsystemExists("StandardSubsystems.FileFunctions") Then
			FileFunctionsInternalClientModule = CommonUseClientServer.CommonModule("FileFunctionsInternalClient");
			PathToFile = FileFunctionsInternalClientModule.MyDocumentsDirectory();
		Else
			PathToFile = "";
		EndIf;
	Else
		Notification = New NotifyDescription("AfterFileExtensionSelection", ThisObject);
		OpenForm("DataProcessor.DataImportFromFile.Form.FileExtention",, ThisObject, True,,, Notification, FormWindowOpeningMode.LockOwnerWindow);
		PathToFile = "";
	EndIf;
	
	FileName = GenerateFileNameForMetadataObject(MappingObjectName);
	GetPathToFileStartChoice(FileDialogMode.Save, PathToFile, FileName);
	SelectedFile = CommonUseClientServer.SplitFullFileName(PathToFile);
	FileExtention = CommonUseClientServer.ExtensionWithoutDot(SelectedFile.Extension);
	If ValueIsFilled(SelectedFile.Name) Then
		If FileExtention = "csv" Then
			SaveTableToCSVFile(PathToFile);
		ElsIf FileExtention = "xlsx" Then
			AddressInTempStorage = SpreadsheetDocumentDeleteAnnotations();
			SpreadsheetDocumentWithoutAnnotations = GetFromTempStorage(AddressInTempStorage);
			SpreadsheetDocumentWithoutAnnotations.Write(PathToFile, SpreadsheetDocumentFileType.xlsx);
		ElsIf FileExtention = "mxl" Then 
			TemplateWithData.Write(PathToFile, SpreadsheetDocumentFileType.mxl);
		Else
			ShowMessageBox(, NStr("en = 'The file template is not saved.'"));
		EndIf;
	EndIf;
EndProcedure

// Function that provides a workaround for the error that occurs when an attempt to save 
// a document with comments is made
//
&AtServer
Function SpreadsheetDocumentDeleteAnnotations()
	SpreadsheetDocumentToSave = new SpreadsheetDocument;
	
	SpreadsheetDocumentToSave = TemplateWithData;
	For Index = 1 To TemplateWithData.TableWidth Do 
		Cell = SpreadsheetDocumentToSave.GetArea(1, Index, 1, Index).CurrentArea;
		Cell.Comment = Undefined;
		Cell.BackColor = New Color();
	EndDo;
	
	AddressInTempStorage = PutToTempStorage(SpreadsheetDocumentToSave);
	Return AddressInTempStorage;
EndFunction

&AtClient
Procedure ImportTemplateFromFile(Command)
	
	TempStorageAddress = "";
	Notification = New NotifyDescription("SendFileToServer", ThisObject);
	BeginPutFile(Notification, TempStorageAddress);
	
	ReportTable.FixedTop = 1;
	
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure DataImportTypeValueChoice(Item, Value, StandardDataProcessor)
	StandardDataProcessor=False;
	Next(Undefined);
EndProcedure

&AtClient
Procedure ReportFilterOnChange(Item)

	ReportAtClientBackgroundJob();
	
	If ReportFilter = "Skipped" Then 
		Items.ChangeAttributes.Enabled=False;
	Else
		Items.ChangeAttributes.Enabled=True;
	EndIf;
EndProcedure

&AtClient
Procedure MappingTableFilterOnChange(Item)
	SetMappingTableFiltering();
EndProcedure

&AtClient
Procedure SetMappingTableFiltering()

	Filter = MappingTableFilter;
	
	If ImportType="TabularSection" Then 
		If Filter = "Mapped" Then 
			Items.DataMappingTable.RowFilter = New FixedStructure("RowMappingResult", "RowMapped"); 
		ElsIf Filter = "Unmapped" Then 
			Items.DataMappingTable.RowFilter = New FixedStructure("RowMappingResult", "NotMapped"); 
		ElsIf Filter = "Conflicting" Then 
			Items.DataMappingTable.RowFilter = New FixedStructure("ErrorDescription", "");
		Else
			Items.DataMappingTable.RowFilter = Undefined;
		EndIf;
	ElsIf ImportType="ReferenceSearch" Then
		If Filter = "Mapped" Then 
			Items.DataMappingTable.RowFilter = New FixedStructure("RowMappingResult", "RowMapped");
		ElsIf Filter = "Unmapped" Then
			Items.DataMappingTable.RowFilter = New FixedStructure("RowMappingResult", "Not");
		ElsIf Filter = "Conflicting" Then 
			Items.DataMappingTable.RowFilter = New FixedStructure("RowMappingResult", "Conflict");
		Else
			Items.DataMappingTable.RowFilter = Undefined;
		EndIf;
	Else
		If Filter = "Mapped" Then 
			Items.DataMappingTable.RowFilter = New FixedStructure("RowMappingResult", "RowMapped");
		ElsIf Filter = "Unmapped" Then 
			Items.DataMappingTable.RowFilter = New FixedStructure("RowMappingResult", "Not");
		ElsIf Filter = "Conflicting" Then 
			Items.DataMappingTable.RowFilter = New FixedStructure("RowMappingResult", "Conflict"); 
		Else
			Items.DataMappingTable.RowFilter = Undefined;
		EndIf;
	EndIf;

EndProcedure


&AtClient
Procedure MappingColumnListStartChoice(Item, ChoiceData, StandardDataProcessor)
	StandardDataProcessor = False;
	
	If MapByColumn.Count() = 0 Then 
		For Each Row In ColumnInfo Do 
			MapByColumn.Add(Row.ColumnName, Row.ColumnPresentation);
		EndDo;
	EndIf;
	FormParameters  = New Structure("ColumnList", MapByColumn);
	NotifyDescription  = New NotifyDescription("AfterSelectColumnsForMapping", ThisObject);
	OpenForm("DataProcessor.DataImportFromFile.Form.SelectColumns", FormParameters, ThisObject, , , , NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);
EndProcedure

&AtClient
Procedure AfterSelectColumnsForMapping(Result, Parameter) Export
	
	MapByColumn = Result;
	ColumnsToString = "";
	Separator = "";
	SelectedColumnCount = 0;
	For Each Item In MapByColumn Do 
		If Item.Check Then 
			ColumnsToString = ColumnsToString + Separator + Item.Presentation;
			Separator = ", ";
			SelectedColumnCount = SelectedColumnCount + 1;
		EndIf;
	EndDo;
	
	MappingColumnList = ColumnsToString;
	
	If SelectedColumnCount = 0 Then 
		Items.MappingColumnList.Title = NStr("en = 'by column'");
	ElsIf SelectedColumnCount = 1 Then
		Items.MappingColumnList.Title = NStr("en = 'by column'");
	Else
		Items.MappingColumnList.Title = NStr("en = 'By columns'") + " ("+String(SelectedColumnCount)+")";;
	EndIf;
	
EndProcedure


#EndRegion

#Region TemplateWithDataFormTableItemEventHandlers

&AtClient
Procedure TemplateWithDataSelection(Item, Region, StandardDataProcessor)
	If Region.Top = 1 Then 
		StandardDataProcessor = False; // Editing header is not allowed
	EndIf;
EndProcedure

#EndRegion

#Region DataMappingTableItemEventHandlers

&AtClient
Procedure DataMappingTableOnEndEdit(Item, NewRow, CancelEdit)
	
	If ImportType <> "TabularSection" Then
		If ValueIsFilled(Item.CurrentData.MappingObject) Then 
			Item.CurrentData.RowMappingResult = "RowMapped";
		else
			Item.CurrentData.RowMappingResult = "NotMapped";
		EndIf;
	Else
		If ValueIsFilled(Item.CurrentData.ts_ProductsAndServices) Then 
			Item.CurrentData.RowMappingResult = "RowMapped";
		else
			Item.CurrentData.RowMappingResult = "NotMapped";
		EndIf;
	EndIf;
	
	ShowCompareStatisticsImportFromFile();
	
EndProcedure

&AtClient
Procedure DataMappingTableOnActivateCell(Item)
	Items.ResolveConflict.Enabled = False;
	Items.DataMappingTableContextMenuResolveConflict.Enabled = False;
	
	If Item.CurrentData <> Undefined And ValueIsFilled(Item.CurrentData.RowMappingResult) Then 
		If ImportType = "TabularSection" Then 
			If StrLen(Item.CurrentItem.Name) > 3 And Left(Item.CurrentItem.Name,3) = 
"ts_" Then 
				ColumnName = Mid(Item.CurrentItem.Name, 4);
				If Find(Item.CurrentData.ErrorDescription, ColumnName) > 0 Then 
					Items.ResolveConflict.Enabled = True;
					Items.DataMappingTableContextMenuResolveConflict.Enabled = True;
				EndIf;
			EndIf;
		ElsIf Item.CurrentData.RowMappingResult = "Conflict" Then 
			Items.ResolveConflict.Enabled = True;
			Items.DataMappingTableContextMenuResolveConflict.Enabled = True;
		EndIf;
	EndIf;
EndProcedure

&AtClient
Procedure DataMappingTableSelection(Item, SelectedRow, Field, StandardDataProcessor)
	OpenResolveConflictForm(SelectedRow, Field.Name, StandardDataProcessor);
EndProcedure

#EndRegion

#Region ReportTableItemEventHandlers

&AtClient
Procedure BatchAttributeModification(Command)
	
	If CommonUseClient.SubsystemExists("StandardSubsystems.BatchObjectModification") Then
		RefArray = BatchAttributeModificationAtServer(ReportTable.CurrentArea.Top, ReportTable.CurrentArea.Bottom);
		If RefArray.Count() > 0 Then
			FormParameters = New Structure("ObjectArray", RefArray);
			ObjectName = "DataProcessor.";
			OpenForm(ObjectName + "BatchAttributeModification.Form", FormParameters);
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions


#Region SelectImportVariantStep

&AtServer
Procedure FillDataImportTypeList()
	DataProcessors.DataImportFromFile.CreateCatalogListForImport(ImportOptionList);
EndProcedure 

#EndRegion


#Region FillTableWithDataStep

&AtClient
Procedure ExecuteStepFillTableWithDataAtClient()
	
	Items.WizardPages.CurrentPage = Items.FillTableWithData;
	Items.Back.Visible = True;
	
EndProcedure

&AtClient
Function DataTableEmpty()
	
	If ColumnInfo.Count() = 1 Then
		If Not ValueIsFilled(TemplateWithDataSingleColumn) Then
			Return True;
		EndIf;
	Else 
		If TemplateWithData.TableHeight < 2 Then
			Return True;
		EndIf;
	EndIf;
	
	Return False;
EndFunction

&AtServerNoContext
Function GetFullMetadataObjectName(Name)
	MetadataObject = Metadata.Catalogs.Find(Name);
	If MetadataObject <> Undefined Then 
		Return MetadataObject.FullName();
	EndIf;
	MetadataObject = Metadata.Documents.Find(Name);
	If MetadataObject <> Undefined Then 
		Return MetadataObject.FullName();
	EndIf;
	MetadataObject = Metadata.ChartsOfCharacteristicTypes.Find(Name);
	If MetadataObject <> Undefined Then 
		Return MetadataObject.FullName();
	EndIf;
	
	Return Undefined;
EndFunction

&AtServer
Procedure ExecuteStepFillTableWithDataAtServer(SelectionRowDescription)
	
	If Find(SelectionRowDescription.MetadataObjectFullName, ".") > 0 Then 
		MappingObjectName = SelectionRowDescription.MetadataObjectFullName;
	Else
		MappingObjectName =  GetFullMetadataObjectName(SelectionRowDescription.MetadataObjectFullName);
	EndIf;
	
	ImportType = SelectionRowDescription.Type;
	
	If ImportType = "UniversalImport" Then
		DataProcessors.DataImportFromFile.GenerateTemplateByCatalogAttributes(MappingObjectName, TemplateWithData, ColumnInfo);
		ThisObject.Title = NStr("en = 'Import from file to catalog: ""'") + CatalogPresentation(MappingObjectName)+"""";
		ThisObject.AutoTitle = False;
		
	ElsIf ImportType = "AppliedImport" Then
		ImportTemplateToSpreadsheetDocument();
		
	ElsIf ImportType = "ExternalImport" Then
		CommandID = SelectionRowDescription.MetadataObjectFullName;
		ImportParameters = DataProcessors.DataImportFromFile.ParametersOfImportFromFileExternalDataProcessor(SelectionRowDescription.MetadataObjectFullName, 
		SelectionRowDescription.Ref, SelectionRowDescription.TemplateWithTemplate);
		
		ImportTemplateToSpreadsheetDocumentExternalDataProcessor(ImportParameters);
		ExternalDataProcessorRef = SelectionRowDescription.Ref;
		
	EndIf;
	
	CreateMappingTableForColumnInfo();
	ShowInfoBarAboutMandatoryColumns();
	
EndProcedure

&AtServer
Procedure SaveTableToCSVFile(FullFileName)
	DataProcessors.DataImportFromFile.SaveTableToCSVFile(FullFileName, ColumnInfo);
EndProcedure

#EndRegion

#Region ImportedDataMappingStep

&AtServer
Procedure CopySingleColumnToTemplateWithData ()
	
	ClearTemplateWithData();
	
	LineCount = StrLineCount(TemplateWithDataSingleColumn);
	StringNumberInTemplate = 2;
	For LineNumber = 1 To LineCount Do 
		String = StrGetLine(TemplateWithDataSingleColumn, LineNumber);
		If ValueIsFilled(String) Then
			Cell = TemplateWithData.GetArea(StringNumberInTemplate, 1, StringNumberInTemplate, 1);
			Cell.CurrentArea.Text = String;
			TemplateWithData.Put(Cell);
			StringNumberInTemplate = StringNumberInTemplate + 1;
		EndIf;
	EndDo;
EndProcedure

&AtServer
Function CreateTableWithConflictList()
	ConflictList = New ValueTable;
	ConflictList.Columns.Add("ID");
	ConflictList.Columns.Add("Column");
	
	Return ConflictList;
EndFunction

&AtServer
Procedure ExecuteDataToImportMappingStepAtServer(BackgroundJob = False)
	
	If ColumnInfo.Count() = 1 Then
		CopySingleColumnToTemplateWithData ();
	EndIf;
	
	MappingTable = FormAttributeToValue("DataMappingTable");
	If ImportType = "TabularSection" Then
		ImportedDataAddress = "";
		TabularSectionCopyAddress = "";
		ConflictList = CreateTableWithConflictList();
		
		DataProcessors.DataImportFromFile.ExportDataForTS(TemplateWithData, ColumnInfo, ImportedDataAddress);
		CopyTabularSectionStructure(TabularSectionCopyAddress);
		
		ObjectManager = ObjectManager(MappingObjectName);
		ObjectManager.MapDataToImport(ImportedDataAddress, TabularSectionCopyAddress, ConflictList, MappingObjectName);
		
		CreateMappingTableByColumnInfoForTS();
		PutDataInMappingTable(ImportedDataAddress, TabularSectionCopyAddress, ConflictList);
	ElsIf ImportType = "ReferenceSearch" Then
		
		DataProcessors.DataImportFromFile.FillMappingTableWithDataFromTemplate(TemplateWithData, MappingTable, ColumnInfo);
		DataProcessors.DataImportFromFile.MapAutoColumnValue(MappingTable, "References");
		ValueToFormAttribute(MappingTable, "DataMappingTable");
		
	Else
		
		ServerCallParameters = New Structure();
		ServerCallParameters.Insert("TemplateWithData", TemplateWithData);
		ServerCallParameters.Insert("MappingTable", MappingTable);
		ColumnInfoTable = FormAttributeToValue("ColumnInfo");
		ServerCallParameters.Insert("ColumnInfo", ColumnInfoTable);
		
		BackgroundJobResult = LongActions.ExecuteInBackground(UUID, 
		"DataProcessors.DataImportFromFile.FillMappingTableWithDataFromTemplateBackground",
		ServerCallParameters, 
		NStr("en = 'DataImportFromFile: Perform FillMappingTableWithDataFromTemplate server processing method'"));
		
		If BackgroundJobResult.JobCompleted Then
			BackgroundJobStorageAddress = BackgroundJobResult.StorageAddress;
			ExecuteDataToImportMappingStepAfterMapAtServer();
		Else 
			BackgroundJob = True;
			BackgroundJobID  = BackgroundJobResult.JobID;
			BackgroundJobStorageAddress = BackgroundJobResult.StorageAddress;
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ExecuteDataToImportMappingStepAfterMapAtServer()
	
	MappingTable = GetFromTempStorage(BackgroundJobStorageAddress);
	
	If ImportType = "AppliedImport" Then
		MapDataAppliedImport(MappingTable);
		Items.ExplanationForAppliedImport.Title = StringFunctionsClientServer.SubstituteParametersInString(
		Items.ExplanationForAppliedImport.Title, CatalogPresentation(MappingObjectName));
	ElsIf ImportType = "ExternalImport" Then
		MapDataExternalDataProcessor(MappingTable);
	EndIf;
	
	Items.ExplanationForAppliedImport.Title = StringFunctionsClientServer.SubstituteParametersInString(
	Items.ExplanationForAppliedImport.Title, CatalogPresentation(MappingObjectName));
	
	ValueToFormAttribute(MappingTable, "DataMappingTable");
	
EndProcedure

&AtClient
Procedure ExecuteDataToImportMappingStep()
	
	If DataTableEmpty() Then
		ShowMessageBox(, (NStr("en ='To proceed to the data mapping and import step, fill the table.'")));	
		Return;
	EndIf;
	
	UnfilledColumnsList = UnfilledColumnsList();
	If UnfilledColumnsList.Count() > 0 Then 
		If UnfilledColumnsList.Count() =1  Then 
			TextAboutColumns = NStr("en = 'Mandatory column""'") + " " + 
UnfilledColumnsList[0] +
				NStr("en = '"" contains blank rows. These rows will be skipped during the data import'");
		Else
			TextAboutColumns = NStr("en = 'Mandatory columns""'") + " " + StringFunctionsClientServer.StringFromSubstringArray(UnfilledColumnsList,", ") +
				NStr("en = '""  contain blank rows. These rows will be skipped during the data import'");
		EndIf;
		TextAboutColumns = TextAboutColumns + Chars.LF + NStr("en = 'Continue?'");
		
		Notification = New NotifyDescription("AfterQuestionAboutBlankStrings", ThisObject);
		ShowQueryBox(Notification, TextAboutColumns, QuestionDialogMode.YesNo,, DialogReturnCode.No);
	Else
		ExecuteMapDataToImportAfterCheckStep();
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterQuestionAboutBlankStrings(Result, Parameter) Export
	If Result = DialogReturnCode.Yes Then 
		ExecuteMapDataToImportAfterCheckStep();
	EndIf;
EndProcedure

&AtClient
Procedure ExecuteMapDataToImportAfterCheckStep()
	
	BackgroundJob = False;
	ExecuteDataToImportMappingStepAtServer(BackgroundJob);
	
	If BackgroundJob = True Then 
		Items.WizardPages.CurrentPage = Items.LongActions;
		LongActionsClient.InitIdleHandlerParameters(HandlerParameters);
		AttachIdleHandler("MappingAtClientBackgroundJob", 1, True);
		HandlerParameters.MaxInterval = 5;
	Else 
		If AllDataMapped() And ImportType = "ReferenceSearch" Then
			CloseFormAndReturnRefArray();
		Else
			ExecuteDataToImportMappingStepClient();
		EndIf;
	EndIf;

EndProcedure

#Region LongActions

&AtClient
Procedure ImportFileAtClientBackgroundJob()
	Result = GetResultImportFileBackgroundJob();
	If Result.BackgroundJobCompleted Then
		If LongActionForm.IsOpen() 
			And LongActionForm.JobID = BackgroundJobID Then
				LongActionsClient.CloseLongActionForm(LongActionForm);
		EndIf;
		TemplateWithData = GetFromTempStorage(BackgroundJobStorageAddress);
	Else
		LongActionsClient.UpdateIdleHandlerParameters(HandlerParameters);
		AttachIdleHandler("ImportFileAtClientBackgroundJob", HandlerParameters.CurrentInterval, True);
		
	EndIf;
EndProcedure

&AtClient
Procedure MappingAtClientBackgroundJob()
	Result = GetResultMappingBackgroundJob();
	If Result.BackgroundJobCompleted Then
		If AllDataMapped() And ImportType = "ReferenceSearch" Then
			CloseFormAndReturnRefArray();
		Else
			ExecuteDataToImportMappingStepClient();
		EndIf;
	Else
		LongActionsClient.UpdateIdleHandlerParameters(HandlerParameters);
		AttachIdleHandler("MappingAtClientBackgroundJob", HandlerParameters.CurrentInterval, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure WriteAtClientBackgroundJob()
	Result = WriteBackgroundJobGetResult();
	If Result.BackgroundJobCompleted Then
		FillMappingTableFromTempStorage();
		ReportAtClientBackgroundJob(False);
	Else
		LongActionsClient.UpdateIdleHandlerParameters(HandlerParameters);
		AttachIdleHandler("WriteAtClientBackgroundJob", HandlerParameters.CurrentInterval, True);
	EndIf;
EndProcedure

&AtClient
Procedure WriteDataToImportClient()
	
	BackgroundJobPercent = 0;
	BackgroundJob = False;
	SaveDataToImportReport(BackgroundJob);
	
	If BackgroundJob = True Then 
		Items.WizardPages.CurrentPage = Items.LongActions;
		LongActionsClient.InitIdleHandlerParameters(HandlerParameters);
		AttachIdleHandler("WriteAtClientBackgroundJob", 1, True);
		HandlerParameters.MaxInterval = 5;
	Else 
		ReportAtClientBackgroundJob(False);
	EndIf;
EndProcedure

&AtServer
Function WriteBackgroundJobGetResult()
	Result = New Structure;
	Result.Insert("BackgroundJobCompleted", False);
	Result.BackgroundJobCompleted = LongActions.JobCompleted(BackgroundJobID);
	If Not Result.BackgroundJobCompleted Then
		BackgroundJobReadInterimResult(Result);
	EndIf;
	Return Result;
EndFunction

&AtClient
Procedure ReportAtClientBackgroundJob(OutputWaitingWindow = True)
	
	BackgroundJob = False;
	GenerateReportOnImporting(ReportFilter, BackgroundJob, Not OutputWaitingWindow);
	
	If BackgroundJob Then
		If OutputWaitingWindow Then 
			LongActionForm = LongActionsClient.OpenLongActionForm(ThisObject, BackgroundJobID);
		EndIf;
		LongActionsClient.UpdateIdleHandlerParameters(HandlerParameters);
		AttachIdleHandler("CreatingReportAtClientBackgroundJob", HandlerParameters.CurrentInterval, True);
	Else
		Result = GetFromTempStorage(BackgroundJobStorageAddress);
		ShowReport(Result);
	EndIf;
EndProcedure

&AtClient
Procedure ShowReport(Report)
	
	If Items.WizardPages.CurrentPage <> Items.DataImportReport Then
		ExecuteDataImportReportStepClient();
	EndIf;
	
	TotalCreatedReport = Report.Created;
	TotalUpdatedReport = Report.Updated;
	TotalSkippedReport = Report.Skipped;
	TotalInvalidReport = Report.Invalid;
	
	Items.ReportFilter.ChoiceList.Clear();
	Items.ReportFilter.ChoiceList.Add("AllItems", NStr("en = 'All ('") + 
Report.Total + ")");
	Items.ReportFilter.ChoiceList.Add("New", NStr("en = 'New ('") + 
Report.Created+ ")");
	Items.ReportFilter.ChoiceList.Add("Updated", NStr("en = 'Updated ('") +
 Report.Updated+ ")");
	Items.ReportFilter.ChoiceList.Add("Skipped", NStr("en = 'Skipped ('") + 
Report.Skipped+ ")");
	ReportFilter = Report.ReportType;

	ReportTable = Report.ReportTable;
	
EndProcedure

&AtClient
Procedure CreatingReportAtClientBackgroundJob()

	ExecutionResult = ReportBackgroundJobGetResult();
	If ExecutionResult.BackgroundJobCompleted Then
		Try
			If LongActionForm.IsOpen() 
				And LongActionForm.JobID = BackgroundJobID Then
					LongActionsClient.CloseLongActionForm(LongActionForm);
				EndIf;
		Except
		EndTry;
		
		Result = GetFromTempStorage(BackgroundJobStorageAddress);
		ShowReport(Result);
	Else
		LongActionsClient.UpdateIdleHandlerParameters(HandlerParameters);
		AttachIdleHandler("CreatingReportAtClientBackgroundJob", HandlerParameters.CurrentInterval, True);
	EndIf;

EndProcedure

&AtServer
Function GetResultImportFileBackgroundJob()
	Result = New Structure;
	Result.Insert("BackgroundJobCompleted", False);
	Result.BackgroundJobCompleted = LongActions.JobCompleted
(BackgroundJobID);
	Return Result;
EndFunction

&AtServer
Function GetResultMappingBackgroundJob()
	Result = New Structure;
	Result.Insert("BackgroundJobCompleted", False);
	Result.BackgroundJobCompleted = LongActions.JobCompleted
(BackgroundJobID);
	If Result.BackgroundJobCompleted Then
		ExecuteDataToImportMappingStepAfterMapAtServer();
	Else
		BackgroundJobReadInterimResult(Result);
	EndIf;
	Return Result;
EndFunction

&AtServer
Function ReportBackgroundJobGetResult()
	Result = New Structure;
	Result.Insert("BackgroundJobCompleted", False);
	Result.BackgroundJobCompleted = LongActions.JobCompleted(BackgroundJobID);
	If Not Result.BackgroundJobCompleted Then
		BackgroundJobReadInterimResult(Result);
	EndIf;
	Return Result;
EndFunction

&AtServer
Procedure BackgroundJobReadInterimResult(Result)
	Progress = LongActions.ReadProgress(BackgroundJobID);
	If Progress <> Undefined Then
		BackgroundJobPercent = Progress.Percent;
	EndIf;
EndProcedure


#EndRegion


&AtClient
Procedure ExecuteDataToImportMappingStepClient()
	
	If ImportType = "ReferenceSearch" Then
		Statistics = ComparisonStatistics();
		
		If Statistics.Mapped > 0 Then
			TextFound = NStr("en = '%2 out of %1 entered rows will be added to the list.'");
			Items.MappingResultLabel.Title = StringFunctionsClientServer.SubstituteParametersInString(TextFound,
				Statistics.Total, Statistics.Mapped);
			
			If Statistics.Conflicting > 0 and Statistics.NotFound > 0 Then 
				TextNotFound = NStr("en = '11 rows will be skipped:'") + Chars.LF + "  - " + NStr("en = 'No data available in the application: %1'") 
					+ Chars.LF + "  - " +NStr("en = 'Multiple mapping options available: %2'");
				TextNotFound = StringFunctionsClientServer.SubstituteParametersInString(TextNotFound, Statistics.NotFound, Statistics.Conflicting);
			ElsIf Statistics.Conflicting > 0 Then
				TextNotFound = NStr("en = 'Rows with multiple mapping options will be skipped: %1'");
				TextNotFound = StringFunctionsClientServer.SubstituteParametersInString(TextNotFound, Statistics.Conflicting);
			ElsIf Statistics.NotFound > 0 Then
				TextNotFound = NStr("en = 'Rows with no data available in the application will be skipped: %1'");
				TextNotFound = StringFunctionsClientServer.SubstituteParametersInString(TextNotFound, Statistics.NotFound);
			EndIf;
			TextNotFound = TextNotFound + Chars.LF + NStr("en = 'To view skipped rows and select data to be added manually, click ""Next"".'");
			Items.NotFoundAndConflictDecoration.Title = TextNotFound;
			
			Items.WizardPages.CurrentPage = Items.MappingResults;
			Items.Back.Visible = True;
			Items.AddToList.Visible = True;
			Items.Next.Visible = True;
			Items.Back.Title = NStr("en = '< Back'");
			Items.Next.Title = NStr("en = 'Next >'");
			Items.Next.DefaultControl = False;
			Items.AddToList.DefaultControl = True;
			Items.AddToList.DefaultButton = True;
			
			ShowCompareStatisticsImportFromFile();
			SetAppearanceForMappingPage(False, Items.ExplanationForRefSearch, False, NStr("en = 'Next'>"));
		Else
			Items.WizardPages.CurrentPage = Items.NotFound;
			Items.Close.Title = NStr("en = 'Close'");
			Items.Back.Visible = True;
			Items.AddToList.Visible = False;
			Items.Next.Visible = False;
		EndIf;
		
	Else 
		Items.WizardPages.CurrentPage = Items.DataToImportMapping;
		ShowCompareStatisticsImportFromFile();
		
		If ImportType = "UniversalImport" Then
			SetAppearanceForMappingPage(True, Items.ExplanationForUniversalImport, True, NStr("en = 'Import  data >'"));
		ElsIf ImportType = "TabularSection" Then
			SetAppearanceForMappingPage(False, Items.ExplanationForTabularSection, True, NStr("en = 'Import data'"));
		ElsIf ImportType = "ExternalImport" Then
			SetAppearanceForMappingPage(False, Items.ExplanationForAppliedImport, False, NStr("en = 'Import  data >'"));
		Else
			SetAppearanceForMappingPage(False, Items.ExplanationForAppliedImport, False, NStr("en = 'Import  data >'"));
		EndIf;
		
	EndIf;
EndProcedure

&AtClient
Procedure SetAppearanceForMappingPage(MappingButtonVisibility, ItemForExplanatoryText, AllowConflictButtonVisibility, ButtonNextText)
	
	Items.MappingByColumn.Visible = MappingButtonVisibility;
	Items.Back.Visible = True;
	Items.ExplanationForUniversalImport.Visible = False;
	Items.ExplanationForAppliedImport.Visible = False;
	Items.ExplanationForTabularSection.Visible = False;
	Items.ExplanationForRefSearch.Visible = False;
	If ItemForExplanatoryText = Items.ExplanationForUniversalImport Then
		Items.ExplanationForUniversalImport.Visible = True;
	ElsIf ItemForExplanatoryText = Items.ExplanationForTabularSection Then
		Items.ExplanationForTabularSection.Visible = True;
	ElsIf ItemForExplanatoryText = Items.ExplanationForRefSearch Then
		Items.ExplanationForRefSearch.Visible = True;
		Items.ExplanationForDataMapping.ShowTitle = False;
	Else
		Items.ExplanationForAppliedImport.Visible = True;
	EndIf;
	
	Items.ResolveConflict.Visible = AllowConflictButtonVisibility;
	Items.Next.Title = ButtonNextText;
	
EndProcedure

&AtClient
Procedure OpenResolveConflictForm(SelectedRow, FieldName, StandardDataProcessor)
	Row = DataMappingTable.FindByID(SelectedRow);
	
	If ImportType = "TabularSection" Then
		If Row.RowMappingResult = "NotMapped" and StrLen(Row.ErrorDescription) > 0 Then
			
			If StrLen(FieldName) > 3 And Left(FieldName,3) = "ts_" Then
				Name = Mid(FieldName, 4);
				If Find(Row.ErrorDescription, Name) Then 
					StandardDataProcessor = False;
					RowFromTable = new Array;
					ValuesOfColumnsToImport = New Structure();
					For Each Column In ColumnInfo Do 
						a = New Array();
						a.Add(Column.ColumnName);
						a.Add(Column.ColumnPresentation);
						a.Add(Row["fl_" + Column.ColumnName]);
						a.Add(Column.ColumnType);
						RowFromTable.Add(a);
						If Name = Column.ColumnName Then
							ValuesOfColumnsToImport.Insert(Column.ColumnName, Row["fl_" + Column.ColumnName]); 
						EndIf;
					EndDo;
					
					FormParameters = New Structure();
					FormParameters.Insert("ImportType", ImportType);
					FormParameters.Insert("Name", Name);
					FormParameters.Insert("RowFromTable", RowFromTable);
					FormParameters.Insert("ValuesOfColumnsToImport", ValuesOfColumnsToImport);
					FormParameters.Insert("ConflictList", Undefined);
					FormParameters.Insert("FullTabularSectionName", MappingObjectName);
					
					Parameter = New Structure();
					Parameter.Insert("ID", SelectedRow);
					Parameter.Insert("Name", Name);
					
					Notification = New NotifyDescription("AfterMapConflicts", 
ThisObject, Parameter);
					OpenForm("DataProcessor.DataImportFromFile.Form.ResolveConflicts", 
FormParameters, ThisObject, True , , , Notification, FormWindowOpeningMode.LockOwnerWindow);
				EndIf;
			EndIf;
		EndIf;
	Else
		If Row.RowMappingResult = "Conflict" Then
			StandardDataProcessor = False;
			
			RowFromTable = new Array;
			For Each Column In ColumnInfo Do 
				a = New Array();
				a.Add(Column.ColumnName);
				a.Add(Column.ColumnPresentation);
				a.Add(Row[Column.ColumnName]);
				a.Add(Column.ColumnType);
				RowFromTable.Add(a);
			EndDo;
			
			MappingColumns = New ValueList;
			For Each Item In MapByColumn Do 
				If Item.Check Then
					MappingColumns.Add(Item.Value);
				EndIf;
			EndDo;
			
			FormParameters = New Structure();
			FormParameters.Insert("RowFromTable", RowFromTable);
			FormParameters.Insert("ConflictList", Row.ConflictList);
			FormParameters.Insert("MappingColumns", MappingColumns);
			FormParameters.Insert("ImportType", ImportType);
			
			Parameter = New Structure("ID", SelectedRow);
			
			Notification = New NotifyDescription("AfterMapConflicts", ThisObject, Parameter);
			OpenForm("DataProcessor.DataImportFromFile.Form.ResolveConflicts", FormParameters, ThisObject, True , , , Notification, FormWindowOpeningMode.LockOwnerWindow);
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure MapDataAppliedImport(DataMappingTableServer)
	
	ManagerObject = ObjectManager(MappingObjectName);
	
	ManagerObject.MapDataToImportFromFile(DataMappingTableServer);
	For Each Row In DataMappingTableServer Do 
		If ValueIsFilled(Row.MappingObject) Then 
			Row.RowMappingResult = "RowMapped";
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion

#Region ReportOnImportStep

&AtServer
Procedure SaveDataToImportReport(BackgroundJob = False)
	
	MappedData = FormAttributeToValue("DataMappingTable");
	
	If ImportType = "UniversalImport" Then
		
		ImportParameters = New Structure();
		ImportParameters.Insert("CreateIfNotMapped", CreateIfNotMapped);
		ImportParameters.Insert("UpdateExistingItems", UpdateExistingItems);

		ServerCallParameters = New Structure();
		ServerCallParameters.Insert("MappedData", MappedData);
		ServerCallParameters.Insert("ImportParameters", ImportParameters);
		ServerCallParameters.Insert("MappingObjectName", MappingObjectName);
		ColumnInfoTable = FormAttributeToValue("ColumnInfo");
		ServerCallParameters.Insert("ColumnInfo", ColumnInfoTable);
		
		BackgroundJobResult = LongActions.ExecuteInBackground(UUID, 
				"DataProcessors.DataImportFromFile.WriteMappedData",
				ServerCallParameters, 
				NStr("en = 'ImportDataFromFile subsystem. Writing imported data'"));
		
		If BackgroundJobResult.JobCompleted Then
			BackgroundJobStorageAddress = BackgroundJobResult.StorageAddress;
			MappedData = GetFromTempStorage(BackgroundJobStorageAddress);
		Else 
			BackgroundJob = True;
			BackgroundJobID  = BackgroundJobResult.JobID;
			BackgroundJobStorageAddress = BackgroundJobResult.StorageAddress;
		EndIf;
	ElsIf ImportType = "ExternalImport" Then
		WriteMappedDataExternalDataProcessor(MappedData);
	Else
		WriteMappedDataAppliedImport(MappedData);
	EndIf;
	
	If Not BackgroundJob Then
		ValueToFormAttribute(MappedData, "DataMappingTable");
	EndIf;
	
	Items.OpenCatalogAfterWizardClosed.Title = StringFunctionsClientServer.SubstituteParametersInString(Items.OpenCatalogAfterWizardClosed.Title, CatalogPresentation(MappingObjectName));
	Items.ExplanationForImportReport.Title = StringFunctionsClientServer.SubstituteParametersInString(Items.ExplanationForImportReport.Title, CatalogPresentation(MappingObjectName));
	
	ReportType = "AllItems";
	
EndProcedure


&AtClient
Procedure ExecuteDataImportReportStepClient()
	
	Items.WizardPages.CurrentPage = Items.DataImportReport;
	Items.OpenCatalogAfterWizardClosed.Visible = True;
	Items.Close.Title = "Done";
	Items.Next.Visible = False;
	Items.Back.Visible = False;
	
EndProcedure
#EndRegion

&AtServer
Procedure ClearTable()
	
	DataMappingTableServer = FormAttributeToValue("DataMappingTable");
	DataMappingTableServer.Columns.Clear();
	ColumnInfo.Clear();
	
	While Items.DataMappingTable.ChildItems.Count() > 0 Do
		ThisObject.Items.Delete(Items.DataMappingTable.ChildItems.Get(0));
	EndDo;
	TemplateWithData = New SpreadsheetDocument;
	
	MappingTableAttributes = ThisObject.GetAttributes("DataMappingTable");
	AttributePathArray = New Array;
	For Each TableAttribute In MappingTableAttributes Do
		AttributePathArray.Add("DataMappingTable." + TableAttribute.Name);
	EndDo;
	If AttributePathArray.Count() > 0 Then
		ChangeAttributes(,AttributePathArray);
	EndIf;
	
EndProcedure

&AtServer
Procedure SetDataAppearance()
	
	If ImportType = "ReferenceSearch" Then 
		TextObjectNotFound = NStr("en='<Not found>'");
		ColorObjectNotFound = StyleColors.LockedByAnotherUserFile;
		ColorConflict = StyleColors.ModifiedAttributeValueColor;
	Else
		TextObjectNotFound = NStr("en='<New>'");
		ColorObjectNotFound = StyleColors.SuccessResultColor;
		ColorConflict = StyleColors.ErrorInformationText;
	EndIf;
	
	ConditionalAppearance.Items.Clear();
	ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
	
	AppearanceField = ConditionalAppearanceItem.Fields.Items.Add();
	AppearanceField.Field = New DataCompositionField("MappingObject");
	AppearanceField.Use = True;
	
	FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.LeftValue = New DataCompositionField("DataMappingTable.MappingObject"); 
	FilterItem.ComparisonType = DataCompositionComparisonType.NotFilled; 
	FilterItem.Use = True;
	ConditionalAppearanceItem.Appearance.SetParameterValue("TextColor", ColorObjectNotFound);
	ConditionalAppearanceItem.Appearance.SetParameterValue("Text", TextObjectNotFound);
	
	ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
	AppearanceField = ConditionalAppearanceItem.Fields.Items.Add();
	AppearanceField.Field = New DataCompositionField("MappingObject");
	AppearanceField.Use = True;
	FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.LeftValue = New DataCompositionField("DataMappingTable.RowMappingResult"); 
	FilterItem.ComparisonType = DataCompositionComparisonType.Equal; 
	FilterItem.RightValue = "Conflict"; 
	FilterItem.Use = True;
	ConditionalAppearanceItem.Appearance.SetParameterValue("TextColor", ColorConflict);
	ConditionalAppearanceItem.Appearance.SetParameterValue("Text", NStr("en='<conflict>'"));
	
EndProcedure

&AtServer
Function ColumnInfo(ColumnName)
	Filter = new Structure("ColumnName", ColumnName);
	Result = ColumnInfo.FindRows(Filter);
	If Result.Count() > 0 Then
		Return Result[0];
	EndIf;
	
	Return Undefined;
EndFunction

&AtServer
Function MetadataObjectInfoByType(FullObjectType)
	ObjectDescription = new Structure("ObjectType, ObjectName");
	FullName = Metadata.FindByType(FullObjectType).FullName();
	Result = StringFunctionsClientServer.SplitStringIntoSubstringArray(FullName,".");
	If Result.Count()>1 Then
		ObjectDescription.ObjectType = Result[0];
		ObjectDescription.ObjectName = Result[1];
		
		Return ObjectDescription;
	Else
		Return Undefined;		
	EndIf;
	
EndFunction 

&AtServer
Function ConditionsBySelectedColumns()
	
	Separator = "";
	SeparatorAnd = "";
	ComparisonType = " = ";
	withWhere = "";
	ConditionString = "";
	
	For Each Item In MapByColumn Do
		If Item.Check Then
			Column = ColumnInfo(Item.Value);
			// Creating a query depending on the types
			If Column <> Undefined Then
				ColumnType = Column.ColumnType.Types()[0];
				If ColumnType = Type("String") Then
					If Column.ColumnType.StringQualifiers.Length = 0 Then
						ConditionString = ConditionString + SeparatorAnd + "ComparisonCatalog." + Column.ColumnName +  " LIKE MappingTable." + Column.ColumnName;
						withWHERE = withWHERE + " And ComparisonCatalog." + Column.ColumnName + " <> """"";
					Else
						ConditionString = ConditionString + SeparatorAnd + "ComparisonCatalog." + Column.ColumnName +  " = MappingTable." + Column.ColumnName;
						withWHERE = withWHERE + " And ComparisonCatalog." + Column.ColumnName + " <> """"";
					EndIf;
				ElsIf ColumnType = Type("Number") Then
					ConditionString = ConditionString + SeparatorAnd + "ComparisonCatalog." + Column.ColumnName + " =  MappingTable." + Column.ColumnName;
				ElsIf ColumnType = Type("Date") Then 
					ConditionString = ConditionString + SeparatorAnd + "ComparisonCatalog." + Column.ColumnName + " =  MappingTable." + Column.ColumnName;
				ElsIf ColumnType = Type("Boolean") Then 
					ConditionString = ConditionString + SeparatorAnd + "ComparisonCatalog." + Column.ColumnName + " =  MappingTable." + Column.ColumnName;
				Else
					InfoObject = MetadataObjectInfoByType(ColumnType);
					If InfoObject.ObjectType = "Catalog" Then
						Catalog = Metadata.Catalogs.Find(InfoObject.ObjectName);
						ConditionTextCatalog = "";
						SeparatorOR = "";
						For Each InputString In Catalog.InputByString Do 
							If InputString.Name = "Code" And Not Catalog.Autonumbering Then 
								InputByStringConditionText = "ComparisonCatalog." + Column.ColumnName+ ".Code " + ComparisonType + " MappingTable." + Column.ColumnName;	
							Else
								InputByStringConditionText = "ComparisonCatalog." + Column.ColumnName+ "." + InputString.Name  + ComparisonType + " MappingTable." + Column.ColumnName;
							EndIf;	
							ConditionTextCatalog = ConditionTextCatalog + SeparatorOR + InputByStringConditionText;
							SeparatorOR = " OR ";
						EndDo;
						ConditionString = ConditionString + SeparatorAnd + " ( "+ ConditionTextCatalog + " )";
					ElsIf InfoObject.ObjectType = "Enum" Then 
						ConditionString = ConditionString + SeparatorAnd + "ComparisonCatalog." + Column.ColumnName + " =  MappingTable." + Column.ColumnName;	
					EndIf;
				EndIf;
				
			EndIf;
			
			SeparatorAnd = " And ";
			Separator = ",";
			
		EndIf;
	EndDo;
	
	Conditions = New Structure("JoinCondition, Where");
	Conditions.JoinCondition  = ConditionString;
	Conditions.Where = withWHERE;
	Return Conditions;
EndFunction

&AtServer
Procedure MapBySelectedAttrubute(MappedItemCount = 0, MappingColumnList = "")
	
	Conditions = ConditionsBySelectedColumns();
	
	If Not ValueIsFilled(Conditions.JoinCondition ) Then
		Return;
	EndIf;
	
	ObjectStructure = DataProcessors.DataImportFromFile.SplitFullObjectName(MappingObjectName);
	CatalogName = ObjectStructure.ObjectName;
	MappingTable = FormAttributeToValue("DataMappingTable");
	
	ColumnList = "";
	Separator = "";
	For Each Column In MappingTable.Columns Do
		If Column.Name <> "ConflictList" And Column.Name <> "RowMappingResult" And Column.Name <> "ErrorDescription" Then
			ColumnList = ColumnList + Separator + Column.Name;
			Separator = ", ";
		EndIf;
	EndDo;
	
	Query = New Query;
	Query.Text = "SELECT " + ColumnList + "
	|INTO MappingTable
	|FROM &MappingTable AS MappingTable
	|;
	|SELECT
	|	ComparisonCatalog.Ref, MappingTable.ID
	|FROM
	|	Catalog." + CatalogName + " AS
	|		ComparisonCatalog RIGHT JOIN MappingTable AS
	|	        MappingTable By " + Conditions.JoinCondition + "
	|Where
 |         MappingCatalog.DeletionCheck = FALSE " + Conditions.Where + "
	|	Order By MappingTable. MappingTable Totals Id.Id";
	
	Query.SetParameter("MappingTable", MappingTable);
	
	QueryResult = Query.Execute();
	DetailedRecordSelection = QueryResult.Select(QueryResultIteration.ByGroups);
	
	EmptyValue = ObjectManager(MappingObjectName).EmptyRef();
	
	While DetailedRecordSelection.Next() Do
		Row = MappingTable.Find(DetailedRecordSelection.ID, "ID");
		
		If ValueIsFilled(Row.MappingObject) Then
			Continue;
		EndIf;
		
		DetailedRecordSelectionGroup = DetailedRecordSelection.Select();
		
		If DetailedRecordSelectionGroup.Count() > 1 Then
			ConflictList = New ValueList;
			While DetailedRecordSelectionGroup.Next() Do
				ConflictList.Add(DetailedRecordSelectionGroup.Ref);
			EndDo;
			Row.RowMappingResult = "Conflict";
			Row.ErrorDescription = MappingColumnList;
			Row.ConflictList = ConflictList;
		Else
			DetailedRecordSelectionGroup.Next();
			MappedItemCount = MappedItemCount + 1;
			Row.RowMappingResult = "RowMapped";
			Row.ErrorDescription = "";
			Row.MappingObject = DetailedRecordSelectionGroup.Ref;
		EndIf;
	EndDo;
	
	ValueToFormAttribute(MappingTable, "DataMappingTable");
	
EndProcedure

&AtServer
Procedure PutDataInMappingTable(ImportedDataAddress, TabularSectionCopyAddress, ConflictList)
	
	TabularSection =  GetFromTempStorage(TabularSectionCopyAddress);
	
	If TabularSection = Undefined Or TypeOf(TabularSection) <> Type("ValueTable") 
Or TabularSection.Count() = 0 Then 
		Return;
	EndIf;
	
	DataToImport = GetFromTempStorage(ImportedDataAddress);
	
	For Each Row In TabularSection Do 
		NewRow = DataMappingTable.Add();
		NewRow.ID = Row.ID;
		For Each Column In TabularSection.Columns Do 			
			If Column.Name <> "ID" Then
				NewRow["ts_" + Column.Name] = Row[Column.Name];	
			EndIf;
			If Column.Name = "ProductsAndServices" Then 
				If Not ValueIsFilled(Row[Column.Name]) Then 
					NewRow["RowMappingResult"] = "NotMapped";
				else
					NewRow["RowMappingResult"] = "RowMapped";
				EndIf;
			EndIf;
			
		EndDo;
		
		Filter = New Structure("ID", Row.ID); 
		
		Conflicts = ConflictList.FindRows(Filter);
		If Conflicts.Count() > 0 Then 
			NewRow["RowMappingResult"] = "NotMapped";
			For Each Conflict In Conflicts Do
				NewRow["ErrorDescription"] = NewRow["ErrorDescription"] + Conflict.Column+ ";";
				
				ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
				AppearanceField = ConditionalAppearanceItem.Fields.Items.Add();
				AppearanceField.Field = New DataCompositionField("ts_" + Conflict.Column);
				AppearanceField.Use = True;
				FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
				FilterItem.LeftValue = New DataCompositionField("DataMappingTableErrorDescription"); 
				FilterItem.ComparisonType = DataCompositionComparisonType.Contains; 
				FilterItem.RightValue = Conflict.Column; 
				FilterItem.Use = True;
				ConditionalAppearanceItem.Appearance.SetParameterValue("TextColor", StyleColors.ErrorInformationText);
				ConditionalAppearanceItem.Appearance.SetParameterValue("Text", NStr("en='<conflict>'"));
			EndDo;
			
		EndIf;
	EndDo;
	
	For Each Row In DataToImport Do 
		Filter = New Structure("ID", Row.ID);
		
		Rows = DataMappingTable.FindRows(Filter);
		If Rows.Count() > 0 Then 
			NewRow = Rows[0];
			For Each Column In DataToImport.Columns Do
				If Column.Name <> "ID" And Column.Name <> "RowMappingResult" And Column.Name <> "ErrorDescription" 
					And Column.Name <> "Quantity"  And Column.Name <> "Price" Then
					NewRow["fl_" + Column.Name] = Row[Column.Name];
				EndIf;
			EndDo;
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Function MappingTableAddressInStorage()
	Table = FormAttributeToValue("DataMappingTable");
	
	TableForTS = New ValueTable;
	For Each Column In Table.Columns Do 
		If Left(Column.Name, 3) = "ts_" Then 
			TableForTS.Columns.Add(Mid(Column.name, 4), Column.ValueType, Column.Title, Column.Width);
		ElsIf  Column.Name = "RowMappingResult" Or Column.Name = "ErrorDescription" Or Column.Name = "ID" Then 
			TableForTS.Columns.Add(Column.name, Column.ValueType, Column.Title, Column.Width);
		EndIf;
	EndDo;
	
	For Each Row In Table Do 
		NewRow = TableForTS.Add();	
		For Each Column In TableForTS.Columns Do
			If Column.Name = "ID" Then 
				NewRow[Column.Name] = Row[Column.Name];
			ElsIf Column.Name <> "RowMappingResult" And Column.Name <> "ErrorDescription" Then
				NewRow[Column.Name] = Row["ts_"+ Column.Name];				
			EndIf;
		EndDo;
	EndDo;
	
	Return PutToTempStorage(TableForTS);
EndFunction

&AtServerNoContext
Function CatalogPresentation(MetadataObjectFullName)
	Return Metadata.FindByFullName(MetadataObjectFullName).Presentation();
EndFunction

&AtServerNoContext
Function ObjectManager(MappingObjectName)
		ObjectArray = DataProcessors.DataImportFromFile.SplitFullObjectName(MappingObjectName);
		If ObjectArray.ObjectType = "Document" Then
			ObjectManager = Documents[ObjectArray.ObjectName];
		ElsIf ObjectArray.ObjectType = "Catalog" Then
			ObjectManager = Catalogs[ObjectArray.ObjectName];
		Else
			Raise StringFunctionsClientServer.SubstituteParametersInString(NStr("en = '%1 object is not found'"), MappingObjectName);
		EndIf;
		
		Return ObjectManager;
EndFunction

&AtServerNoContext
Function ListForm(MappingObjectName)
	MetadataObject = Metadata.FindByFullName(MappingObjectName);
	Return MetadataObject.DefaultListForm.FullName();
EndFunction


&AtServer
Function TypeDescriptionByMetadata(MetadataObjectFullName)
	Result = DataProcessors.DataImportFromFile.SplitFullObjectName(MetadataObjectFullName);
	If Result.ObjectType = "Catalog" Then 
		Return New TypeDescription("CatalogRef." +  Result.ObjectName);
	ElsIf Result.ObjectType = "Document" Then 
		Return New TypeDescription("DocumentRef." +  Result.ObjectName);
	EndIf;
	
	Return Undefined;
EndFunction

&AtServer
Function UnfilledColumnsList()
	ColumnNameWithoutData = New Array;
	
	Filter = New Structure("MandatoryForFilling", True);
	MandatoryColumns = ColumnInfo.FindRows(Filter);
	
	Header = TableTemplateTitleArea(TemplateWithData);
	For ColumnNumber = 1 To Header.TableWidth Do 
		Cell = Header.GetArea(1, ColumnNumber, 1, ColumnNumber);
		ColumnName = TrimAll(Cell.CurrentArea.Text);
		
		SingleColumnInfo = Undefined;
		Filter = New Structure("ColumnPresentation", ColumnName);
		ColumnFilter = ColumnInfo.FindRows(Filter);
		
		If ColumnFilter.Count() > 0 Then
			SingleColumnInfo = ColumnFilter[0];
		Else
			Filter = New Structure("ColumnName", ColumnName);
			ColumnFilter = ColumnInfo.FindRows(Filter);	
			
			If ColumnFilter.Count() > 0 Then
				SingleColumnInfo = ColumnFilter[0];
			EndIf;
		EndIf;
		If SingleColumnInfo <> Undefined Then
			If SingleColumnInfo.MandatoryForFilling Then 
				For LineNumber = 2 To TemplateWithData.TableHeight Do 
					Cell = TemplateWithData.GetArea(LineNumber, ColumnNumber, LineNumber, ColumnNumber);
					If Not ValueIsFilled(Cell.CurrentArea.Text) Then
						ColumnNameWithoutData.Add(SingleColumnInfo.ColumnPresentation);
						Break;
					EndIf;
				EndDo;
			EndIf;
		EndIf;
	EndDo;
	
	Return ColumnNameWithoutData;
EndFunction

#Region ExternalImport

&AtServer
Procedure MapDataExternalDataProcessor(DataMappingTableServer)
	If CommonUse.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		AdditionalReportsAndDataProcessorsModule = CommonUseClientServer.CommonModule("AdditionalReportsAndDataProcessors");
		ExternalObject = AdditionalReportsAndDataProcessorsModule.GetExternalDataProcessorsObject(ExternalDataProcessorRef);
		ExternalObject.MapDataToImportFromFile(CommandID, DataMappingTableServer);
	EndIf;
EndProcedure

&AtServer
Procedure WriteMappedDataExternalDataProcessor(MappedData) 
	
	If CommonUse.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		AdditionalReportsAndDataProcessorsModule = CommonUseClientServer.CommonModule("AdditionalReportsAndDataProcessors");
		ExternalObject = AdditionalReportsAndDataProcessorsModule.GetExternalDataProcessorsObject(ExternalDataProcessorRef);
	EndIf;
	
	Cancel = False;
	ImportParameters = New Structure();
	ImportParameters.Insert("CreateNew", CreateIfNotMapped);
	ImportParameters.Insert("UpdateExistingItems", UpdateExistingItems);
	ExternalObject.ImportFromFile(CommandID, MappedData, ImportParameters, Cancel); 
	
EndProcedure

&AtServer
Procedure ImportTemplateToSpreadsheetDocumentExternalDataProcessor(ImportParameters)
	
	TableTitleArea = TableTemplateTitleArea(ImportParameters.Template);
	TableTitleArea.Protection = True;
	TemplateWithData.FixedTop = 1;
	TemplateWithData.Put(TableTitleArea);
	
	DataProcessors.DataImportFromFile.CreateInformationByColumnsBasedOnTemplate(TableTitleArea, ImportParameters.ColumnDataTypeMap, ColumnInfo);
EndProcedure

#EndRegion

#Region ImportFromFile

&AtServer
Procedure WriteMappedDataAppliedImport(MappedData)
	
	ObjectManager = ObjectManager(MappingObjectName);
	
	Cancel = False;
	ImportParameters = New Structure();
	ImportParameters.Insert("CreateNew", CreateIfNotMapped);
	ImportParameters.Insert("UpdateExistingItems", UpdateExistingItems);
	ObjectManager.ImportFromFile(MappedData, ImportParameters, Cancel)
	
EndProcedure


#EndRegion

#Region ImportToTabularSection

&AtServer
Procedure CopyTabularSectionStructure(TabularSectionAddress)
	
	TabularSection = Metadata.FindByFullName(MappingObjectName);
	
	DataForTabularSection = New ValueTable;
	DataForTabularSection.Columns.Add("ID", New TypeDescription("Number"), "ID");
	For Each TabularSectionAttribute In TabularSection.Attributes Do
		DataForTabularSection.Columns.Add(TabularSectionAttribute.Name, TabularSectionAttribute.Type, TabularSectionAttribute.Presentation());	
	EndDo;
	
	TabularSectionAddress = PutToTempStorage(DataForTabularSection);
	
EndProcedure

#EndRegion

&AtServer
Procedure GenerateReportOnImporting(ReportType = "AllItems", BackgroundJob = False, CalculateProgressPercentage = False)
	
	MappedData = FormAttributeToValue("DataMappingTable");
	
	ServerCallParameters = New Structure();
	
	ServerCallParameters.Insert("ReportTable", ReportTable);
	ServerCallParameters.Insert("ReportType", ReportType);
	ServerCallParameters.Insert("MappedData", MappedData);
	ServerCallParameters.Insert("TemplateWithData", TemplateWithData);
	ServerCallParameters.Insert("MappingObjectName", MappingObjectName);
	ColumnInfoTable = FormAttributeToValue("ColumnInfo");
	ServerCallParameters.Insert("ColumnInfo", ColumnInfoTable);
	
	
	If CommonUse.FileInfobase() Then
		ServerCallParameters.Insert("CalculateProgressPercentage", False);
		StorageAddress = PutToTempStorage("");
		DataProcessors.DataImportFromFile.GenerateReportOnBackgroundImport(ServerCallParameters, StorageAddress);
		BackgroundJobStorageAddress = StorageAddress;
	Else
		ServerCallParameters.Insert("CalculateProgressPercentage", CalculateProgressPercentage);
		BackgroundJobResult = LongActions.ExecuteInBackground(UUID, 
				"DataProcessors.DataImportFromFile.GenerateReportOnBackgroundImport",
				ServerCallParameters, 
				NStr("en = 'DataImportFromFile subsystem: Execution of server method of GenerateReportOnImporting data processor'"));
		
		If BackgroundJobResult.JobCompleted Then
			BackgroundJobStorageAddress = BackgroundJobResult.StorageAddress;
		Else 
			BackgroundJob = True;
			BackgroundJobID  = BackgroundJobResult.JobID;
			BackgroundJobStorageAddress = BackgroundJobResult.StorageAddress;
		EndIf;

	EndIf;
	
EndProcedure

&AtServer
Function TableTemplateTitleArea(Template)
	MetadataTableTitleArea = Template.Areas.Find("Header");
	
	If MetadataTableTitleArea = Undefined Then 
		TableTitleArea = Template.GetArea("R1");
	Else 
		TableTitleArea = Template.GetArea("Header"); 
	EndIf;
	
	Return TableTitleArea;
	
EndFunction

&AtServer
Procedure ShowInfoBarAboutMandatoryColumns()
	
	HintText = NStr("en = 'To import the data, fill the table using one of the following methods:'") + Chars.LF;
	HintText = HintText + " " + NStr("en = '- Copy data into the table from an external file through clipboard using commands Copy and Paste).'") + Chars.LF;
	
	#If Not WebClient Then
		HintText = HintText +  " " + NStr("en = '- Save the table to file for filling in another program. Then import the prepared data.'") + Chars.LF;
	#EndIf
	
	Filter = New Structure("MandatoryForFilling", True);
	MandatoryColumns= ColumnInfo.FindRows(Filter);
	
	If MandatoryColumns.Count() > 0 Then 
		ColumnList = "";
		
		For Each Column In MandatoryColumns Do 
			ColumnList = ColumnList + ", """ + Column.ColumnPresentation + """"; 
		EndDo;
		ColumnList = Mid(ColumnList, 3);
		
		If MandatoryColumns.Count() = 1 Then
			HintText = HintText + NStr("en = 'The following column is mandatory:'") + " " + ColumnList;
		Else
			HintText = HintText + NStr("en = 'The following columns are mandatory:'") + " " + ColumnList;
		EndIf;
		
	EndIf;
	Items.FillingHintLabel.Title = HintText;
	
EndProcedure

&AtServer
Procedure ImportTemplateToSpreadsheetDocument()
	
	Template = ObjectManager(MappingObjectName).GetTemplate("ImportFromFile");
	ObjectMetadata = Metadata.FindByFullName(MappingObjectName);
	ImportFromFileParameters = DataProcessors.DataImportFromFile.ImportFromFileParameters(ObjectMetadata);
	
	ObjectManager(MappingObjectName).GetDataParametersForImportFromFile(ImportFromFileParameters);
	
	If ValueIsFilled(ImportFromFileParameters.Title) Then
		ThisObject.Title = ImportFromFileParameters.Title;
		ThisObject.AutoTitle = False;
	EndIf;
	
	TableTitleArea = TableTemplateTitleArea(Template);
	
	TemplateWithData.FixedTop=1;
	TableTitleArea.Protection=True;
	TemplateWithData.Put(TableTitleArea);
	
	DataProcessors.DataImportFromFile.CreateInformationByColumnsBasedOnTemplate(TableTitleArea, ImportFromFileParameters.ColumnDataType, ColumnInfo);
	
EndProcedure

&AtServer
Procedure AddStandardColumnsToMappingTable(TemporaryVT, MappingObjectStructure = Undefined, AddID = True,
		AddErrorDescription = True, AddRowMappingResult = True,
		AddConflictList = True)
		
	If AddID Then 
		TemporaryVT.Columns.Add("ID", New TypeDescription("Number"), NStr("en = '#'"));
	EndIf;
	If ValueIsFilled(MappingObjectStructure) Then 
		If Not ValueIsFilled(MappingObjectStructure.Synonym) Then
			ColumnHeader = "";
			If MappingObjectStructure.MappingObjectTypeDescription.Types().Count() > 1 Then 
				ColumnHeader = "Objects";
			Else
				ColumnHeader = String(MappingObjectStructure.MappingObjectTypeDescription.Types()[0]);
			EndIf;
			
		Else
			ColumnHeader = MappingObjectStructure.Synonym;
		EndIf;
		TemporaryVT.Columns.Add("MappingObject", MappingObjectStructure.MappingObjectTypeDescription, ColumnHeader);
	EndIf;
	If AddRowMappingResult Then 
		TemporaryVT.Columns.Add("RowMappingResult", New TypeDescription("String"), NStr("en = 'Result'"));
	EndIf;
	If AddErrorDescription Then
		TemporaryVT.Columns.Add("ErrorDescription", New TypeDescription("String"), NStr("en = 'Reason'"));
	EndIf;

	If AddConflictList Then 
		TypeVL = New TypeDescription("ValueList");
		TemporaryVT.Columns.Add("ConflictList", TypeVL, "ConflictList");
	EndIf;
EndProcedure

&AtServer
Procedure AddStandardColumnsToAttributeArray(AttributeArray, MappingObjectStructure = Undefined, AddID = True,
		AddErrorDescription = True, AddRowMappingResult = True,
		AddConflictList = True)
		
		StringType = New TypeDescription("String");
		If AddID Then 
			NumberType = New TypeDescription("Number");
			AttributeArray.Add(New FormAttribute("ID", NumberType, "DataMappingTable", "ID"));
		EndIf;
		If ValueIsFilled(MappingObjectStructure) Then 
			AttributeArray.Add(New FormAttribute("MappingObject", MappingObjectStructure.MappingObjectTypeDescription, "DataMappingTable", MappingObjectName));
		EndIf;
		
		If AddRowMappingResult Then
			AttributeArray.Add(New FormAttribute("RowMappingResult", StringType, "DataMappingTable", "Result"));
		EndIf;
		If AddErrorDescription Then 
			AttributeArray.Add(New FormAttribute("ErrorDescription", StringType, "DataMappingTable", "Reason"));
		EndIf;

	If AddConflictList Then 
		TypeVL = New TypeDescription("ValueList");
		AttributeArray.Add(New FormAttribute("ConflictList", TypeVL, "DataMappingTable", "ConflictList"));
	EndIf;

EndProcedure

&AtServer
Procedure CreateMappingTableByColumnInfoAuto(MappingObjectTypeDescription)
	
	AttributeArray = New Array;
	
	TemporaryVT = FormAttributeToValue("DataMappingTable");
	TemporaryVT.Columns.Clear();
	
	MappingObjectStructure = New Structure("MappingObjectTypeDescription, Synonym", MappingObjectTypeDescription, "");
	AddStandardColumnsToMappingTable(TemporaryVT, MappingObjectStructure,, False);
	AddStandardColumnsToAttributeArray(AttributeArray, MappingObjectStructure, ,False);
	
	For Each Column In ColumnInfo Do
		TemporaryVT.Columns.Add(Column.ColumnName, Column.ColumnType, Column.ColumnPresentation);
		AttributeArray.Add(New FormAttribute(Column.ColumnName, Column.ColumnType, "DataMappingTable", Column.ColumnPresentation));
	EndDo;
	
	ChangeAttributes(AttributeArray);
	
	ValueToFormAttribute(TemporaryVT, "DataMappingTable");
	
	For Each Column In TemporaryVT.Columns Do
		NewItem = Items.Add(Column.Name, Type("FormField"), Items.DataMappingTable);
		NewItem.Type = FormFieldType.InputField;
		NewItem.DataPath = "DataMappingTable" + Column.Name;
		NewItem.Title = Column.Title;
		NewItem.ReadOnly = True;
		If NewItem.Type <> FormFieldType.LabelField Then
			MandatoryForFilling = ThisColumnIsMandatoryForFilling(Column.Name);
			NewItem.AutoMarkIncomplete  = MandatoryForFilling;
			NewItem.ChoiceHistoryOnInput = ChoiceHistoryOnInput.DontUse;
			
		EndIf;
		If Column.Name = "MappingObject" Then
			NewItem.FixingInTable = FixingInTable.Left;
			NewItem.BgColor = StyleColors.MasterFieldBackground;
			NewItem.HeaderPicture = PictureLib.Change;
			NewItem.ReadOnly = False;
			
			NewItem.EditMode = ColumnEditMode.Enter;
			NewItem.DropListButton = False;
			NewItem.CreateButton = False;
			NewItem.TextEdit = False;
			NewItem.ChoiceHistoryOnInput = ChoiceHistoryOnInput.DontUse;
			NewItem.IncompleteChoiceMode = IncompleteChoiceMode.OnActivate;
		ElsIf Column.Name = "ID" Then
			NewItem.FixingInTable = FixingInTable.Left;
			NewItem.ReadOnly = True;
			NewItem.Width = 4;
		ElsIf Column.Name = "RowMappingResult" Or Column.Name = "ConflictList" Then
			NewItem.Visible = False;
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure CreateMappingTableForColumnInfo() 
	
	AttributeArray = New Array;
	
	MetadataObject = Metadata.FindByFullName(MappingObjectName);
	MappingObjectTypeDescription = TypeDescriptionByMetadata(MappingObjectName);
	StringType = New TypeDescription("String");
	NumberType = New TypeDescription("Number");
	TypeVL = New TypeDescription("ValueList");
	
	TemporaryVT = FormAttributeToValue("DataMappingTable"); 
	TemporaryVT.Columns.Clear();
	
	Synonym = MetadataObject.Synonym;
	MappingObjectStructure = New Structure("MappingObjectTypeDescription, Synonym", MappingObjectTypeDescription, Synonym);
	AddStandardColumnsToMappingTable(TemporaryVT, MappingObjectStructure);
	AddStandardColumnsToAttributeArray(AttributeArray, MappingObjectStructure);
	
	For Each Column In ColumnInfo Do 
		TemporaryVT.Columns.Add(Column.ColumnName, Column.ColumnType, Column.ColumnPresentation);	
		AttributeArray.Add(New FormAttribute(Column.ColumnName, Column.ColumnType, "DataMappingTable", Column.ColumnPresentation));
	EndDo;
	
	ChangeAttributes(AttributeArray);
	
	For Each Column In TemporaryVT.Columns Do
		NewItem = Items.Add(Column.Name, Type("FormField"), Items.DataMappingTable);
		NewItem.Type = FormFieldType.InputField;
		NewItem.DataPath = "DataMappingTable." + Column.Name;
		NewItem.Title = Column.Title;
		NewItem.ReadOnly = True;
		If NewItem.Type <> FormFieldType.LabelField Then 
			MandatoryForFilling = ThisColumnIsMandatoryForFilling(Column.Name);
			NewItem.AutoMarkIncomplete  = MandatoryForFilling;
			NewItem.ChoiceHistoryOnInput = ChoiceHistoryOnInput.DontUse;
		EndIf;
		If Column.Name = "MappingObject" Then 
			NewItem.FixingInTable = FixingInTable.Left;
			NewItem.BackColor = StyleColors.MasterFieldBackground;
			NewItem.HeaderPicture = PictureLib.Change;
			NewItem.ReadOnly = False;
			NewItem.EditMode =  ColumnEditMode.Directly;
			NewItem.IncompleteChoiceMode = IncompleteChoiceMode.OnActivate;
		ElsIf Column.Name = "ID" Then
			NewItem.FixingInTable = FixingInTable.Left;
			NewItem.ReadOnly = True;
			NewItem.Width = 4;
		ElsIf Column.Name = "RowMappingResult" Or Column.Name = "ErrorDescription" Or Column.Name = "ConflictList" Then
			NewItem.Visible = False;
		EndIf;
	EndDo; 
	
	ValueToFormAttribute(TemporaryVT, "DataMappingTable");
EndProcedure

&AtServer
Procedure CreateMappingTableByColumnInfoForTS() 
	
	AttributeArray = New Array;
	StringType = New TypeDescription("String");
	NumberType = New TypeDescription("Number");
	
	TemporaryVT = FormAttributeToValue("DataMappingTable"); 
	TemporaryVT.Columns.Clear();
	
	AddStandardColumnsToMappingTable(TemporaryVT,,,,, False);
	AddStandardColumnsToAttributeArray(AttributeArray,,,,, False);

	MandatoryColumns = New Array;
	TSAttributes = Metadata.FindByFullName(MappingObjectName).Attributes; 
	For Each Column In TSAttributes Do 
		If Column.FillChecking = FillChecking.ShowError  Then 
			MandatoryColumns.Add("ts_" + Column.Name);
		EndIf;
		TemporaryVT.Columns.Add("ts_" + Column.Name, Column.Type, Column.Presentation());	
		AttributeArray.Add(New FormAttribute("ts_" + Column.Name, Column.Type, "DataMappingTable", Column.Presentation()));
	EndDo;
	
	For Each Column In ColumnInfo Do 
		TemporaryVT.Columns.Add("fl_" + Column.ColumnName, StringType, Column.ColumnPresentation);	
		AttributeArray.Add(New FormAttribute("fl_" + Column.ColumnName, StringType, "DataMappingTable", Column.ColumnPresentation));
	EndDo;
	
	ChangeAttributes(AttributeArray);
	
	DataToImportColumnGroup = Items.Add("DataToImport", Type("FormGroup"), Items.DataMappingTable);
	DataToImportColumnGroup.Grouping = ColumnsGroup.Horizontal; 
	
	For Each Column In TemporaryVT.Columns Do
		
		If Left(Column.Name, 3) = "ts_" Then 
			TSDataToImportColumnGroup = Items.Add("DataToImport_" + Column.Name , Type("FormGroup"), DataToImportColumnGroup);
			TSDataToImportColumnGroup.Grouping = ColumnsGroup.Vertical;
			Parent = TSDataToImportColumnGroup; 
		ElsIf Left(Column.Name, 3) = "fl_" Then
			Continue;
		else 
			Parent = DataToImportColumnGroup;
		EndIf;
		
		NewItem = Items.Add(Column.Name, Type("FormField"), Parent); 
		NewItem.Type = FormFieldType.InputField;
		NewItem.DataPath = "DataMappingTable" + Column.Name;
		NewItem.Title = Column.Title;
		NewItem.ChoiceHistoryOnInput = ChoiceHistoryOnInput.DontUse;
		If Column.Name = "ID" Then
			NewItem.FixingInTable = FixingInTable.Left;
			NewItem.ReadOnly = True;
			NewItem.Width = 5;
		ElsIf Column.Name = "RowMappingResult" Or Column.Name = "ErrorDescription" Then
			NewItem.Visible = False;
		EndIf;
		
		If MandatoryColumns.Find(Column.Name) <> Undefined Then 
			NewItem.AutoMarkIncomplete = True;
		EndIf;
		
		If Left(Column.Name, 3) = "ts_" Then 
			ColumnType = Metadata.FindByType(Column.ValueType.Types()[0]);
			If ColumnType <> Undefined And Find(ColumnType.FullName(), "Catalog") > 0 Then 
				NewItem.HeaderPicture = PictureLib.Change;
			EndIf;
			
			Filter = New Structure("Association", Mid(Column.Name, 4));
			ColumnsFL = ColumnInfo.FindRows(Filter);
			
			If ColumnsFL.Count() = 1 Then
				
				ColumnLevel2 = TemporaryVT.Columns.Find("fl_" + ColumnsFL[0].ColumnName);
				If ColumnLevel2 <> Undefined Then 
					NewItem = Items.Add(ColumnLevel2.Name, Type("FormField"), Parent); 
					NewItem.Type = FormFieldType.InputField;
					NewItem.DataPath = "DataMappingTable" + ColumnLevel2.Name;
					ColumnType = Metadata.FindByType(ColumnLevel2.ValueType.Types()[0]);
					If ColumnType <> Undefined And Find(ColumnType.FullName(), "Catalog") > 0 Then 
						NewItem.Title = NStr("en = 'Data from file'");
					Else
						NewItem.Title = " ";
					EndIf;
					NewItem.ReadOnly = True;
					NewItem.TextColor = StyleColors.InformationText;
				EndIf;
				
			ElsIf ColumnsFL.Count() > 1 Then
				TSDataToImportColumnGroup = Items.Add("DataToImport_fl_" + Column.Name , Type("FormGroup"), Parent);
				TSDataToImportColumnGroup.Grouping = ColumnsGroup.InCell;
				Parent = TSDataToImportColumnGroup;	
				
				Prefix = NStr("en = 'Data from file:'");
				For Each ColumnFL In ColumnsFL Do 
					Column2 = TemporaryVT.Columns.Find("fl_" + ColumnFL.ColumnName);
					If Column2 <> Undefined Then 
						NewItem = Items.Add(Column2.Name, Type("FormField"), Parent); 
						NewItem.Type = FormFieldType.InputField;
						NewItem.DataPath = "DataMappingTable" + Column2.Name;
						NewItem.Title = Prefix + Column2.Title;
						NewItem.ReadOnly = True;
						NewItem.TextColor = StyleColors.InformationText;
					EndIf;
					Prefix = "";
				EndDo;
				
			EndIf;
		EndIf;
	EndDo; 
	
	ValueToFormAttribute(TemporaryVT, "DataMappingTable");
EndProcedure

&AtServer
Function ThisColumnIsMandatoryForFilling(ColumnName)
	Filter = New Structure("ColumnName", ColumnName);
	Column =  ColumnInfo.FindRows(Filter);
	If Column.Count()>0 Then 
		Return Column[0].MandatoryForFilling;
	EndIf;
	
	Return False;
EndFunction

&AtServer
Procedure ClearTemplateWithData()
	TitleArea = TemplateWithData.GetArea(1, 1, 1, TemplateWithData.TableWidth);
	TemplateWithData.Clear();
	TemplateWithData.Put(TitleArea);
EndProcedure

&AtClient
Procedure AfterMapConflicts(Result, Parameter) Export
	
	If ImportType  = "TabularSection" Then
		If Result <> Undefined Then
			Row = DataMappingTable.FindByID(Parameter.ID);
			
			Row["ts_" +  Parameter.Name] = Result;
			Row.ErrorDescription = StrReplace(Row.ErrorDescription, Parameter.Name+";", "");
			Row.RowMappingResult = ?(StrLen(Row.ErrorDescription) = 0, "RowMapped", "NotMapped");
		EndIf;
	Else
		Row = DataMappingTable.FindByID(Parameter.ID);
		Row.MappingObject = Result;
		If Result <> Undefined Then
			Row.RowMappingResult = "RowMapped";
			Row.ConflictList = Undefined;
		Else 
			If Row.RowMappingResult <> "Conflict" Then 
				Row.RowMappingResult = "NotMapped";
				Row.ConflictList = Undefined;
			EndIf;
		EndIf;
	EndIf;
	
	ShowCompareStatisticsImportFromFile();
	
EndProcedure

&AtClient
Function AllDataMapped()
	Filter = New Structure("RowMappingResult", "RowMapped");
	Result = DataMappingTable.FindRows(Filter);
	MappedItemCount = Result.Count();
	
	If DataMappingTable.Count() = MappedItemCount Then 
		Return True;
	Else
		Return False;
	EndIf;
	
EndFunction

&AtClient
Function ComparisonStatistics()
	Filter = New Structure("RowMappingResult", "RowMapped");
	Result = DataMappingTable.FindRows(Filter);
	MappedItemCount = Result.Count();
	
	Filter = New Structure("RowMappingResult", "Conflict");
	Result = DataMappingTable.FindRows(Filter);
	ConflictingItemCount  = Result.Count();
	
	NotMappedItemCount = DataMappingTable.Count() - MappedItemCount;
	
	Result = New Structure;
	Result.Insert("Total", DataMappingTable.Count());
	Result.Insert("Mapped", MappedItemCount);
	Result.Insert("Conflicting", ConflictingItemCount);
	Result.Insert("Unmapped", NotMappedItemCount);
	Result.Insert("NotFound", NotMappedItemCount - ConflictingItemCount);
	
	Return Result;
	
EndFunction

&AtClient
Procedure ShowCompareStatisticsImportFromFile()
	
	Statistics = ComparisonStatistics();
	
	MappingData = ComparisonStatistics();
	
	AllText = StringFunctionsClientServer.SubstituteParametersInString(NStr("en = 'All (%1)'"), Statistics.Total);
	
	Items.CreateIfNotMapped.Title = NStr("en = 'Unmapped ('") + Statistics.Unmapped + ")";
	Items.UpdateExisting.Title = NStr("en = 'Mapped ('") + String(Statistics.Mapped) + ")";
	
	ChoiceList = Items.MappingTableFilter.ChoiceList;
	ChoiceList.Clear();
	ChoiceList.Add("All", AllText, True);
	ChoiceList.Add("Unmapped", StringFunctionsClientServer.SubstituteParametersInString(
	NStr("en = 'Unmapped (%1)'"), Statistics.Unmapped));
	ChoiceList.Add("Mapped", StringFunctionsClientServer.SubstituteParametersInString(
	NStr("en = 'Mapped (%1)'"), Statistics.Mapped));
	ChoiceList.Add("Conflicting", StringFunctionsClientServer.SubstituteParametersInString(
	NStr("en = 'Conflicting (%1)'"), Statistics.Conflicting));
	
	If Statistics.Conflicting > 0 Then 
		Items.ConflictDescription.Visible = True;
		Items.ConflictDescription.Title = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = '(conflicts: %1)'"), Statistics.Conflicting);
	Else 
		Items.ConflictDescription.Visible = False;
	EndIf;
	
	If Not ValueIsFilled(MappingTableFilter) Then 
		MappingTableFilter = "All";
	EndIf;
	
	If ImportType = "ReferenceSearch" Then
		SetMappingTableFiltering();
	Else
		SetMappingTableFiltering();
	EndIf;
	
EndProcedure

&AtServer
Function BatchAttributeModificationAtServer(UpperPosition, LowerPosition)
	RefArray = new Array;
	For Position = UpperPosition To LowerPosition Do 
		Cell = ReportTable.GetArea(Position, 2, Position, 2);	
		If ValueIsFilled(Cell.CurrentArea.Details) Then 
			RefArray.Add(Cell.CurrentArea.Details);
		EndIf;
	EndDo;
	Return RefArray;
EndFunction

#Region FileOperations

&AtClient
Procedure SendFileToServer(Result, TempStorageAddress, FileName, Parameter) Export
	
	If Result = True Then
		Extension = CommonUseClientServer.ExtensionWithoutDot(
		CommonUseClientServer.GetFileNameExtension(FileName));
		If Extension = "csv"  Or Extension = "xlsx" Or Extension = "mxl" Then
			
			BackgroundJob = False;
			ImportFileWithDataToSpreadsheetDocumentAtServer(TempStorageAddress, Extension, BackgroundJob);
			If BackgroundJob Then
				LongActionsClient.InitIdleHandlerParameters(HandlerParameters);
				AttachIdleHandler("ImportFileAtClientBackgroundJob", 1, True);
				HandlerParameters.MaxInterval = 5;
				LongActionForm = LongActionsClient.OpenLongActionForm(ThisObject, BackgroundJobID);
			EndIf;
		Else
			ShowMessageBox(,NStr("en ='Cannot import data from this file. Ensure that the file contains correct data.'"));        
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterFileExtensionSelection(Result, Parameter) Export
	AddressInTempStorage = ThisObject.UUID;
	SaveTemplateToTempStorage(Result, AddressInTempStorage);	
	GetFile(AddressInTempStorage, MappingObjectName + "." + Result, True);
EndProcedure

&AtServer
Procedure SaveTemplateToTempStorage(FileExtention, AddressInTempStorage)
	
	FileName = GetTempFileName(FileExtention);
	If FileExtention = "csv" Then 
		SaveTableToCSVFile(FileName);
	ElsIf FileExtention = "xlsx" Then 
		TemplateWithData.Write(FileName, SpreadsheetDocumentFileType.xlsx);		
	Else 
		TemplateWithData.Write(FileName, SpreadsheetDocumentFileType.mxl);		
	EndIf;
	BinaryData = New BinaryData(FileName);
	
	AddressInTempStorage = PutToTempStorage(BinaryData, AddressInTempStorage);
EndProcedure

&AtServerNoContext
Function GenerateFileNameForMetadataObject(MetadataObjectName)
	CatalogMetadata = Metadata.FindByFullName(MetadataObjectName);
	
	If CatalogMetadata <> Undefined Then 
		FileName = TrimAll(CatalogMetadata.Synonym);
		If StrLen(FileName) = 0 Then 
			FileName = MetadataObjectName;	
		EndIf;
	Else
		FileName = MetadataObjectName;
	EndIf;
	
	FileName = StrReplace(FileName,":","");
	FileName = StrReplace(FileName,"*","");
	FileName = StrReplace(FileName,"\","");
	FileName = StrReplace(FileName,"/","");
	FileName = StrReplace(FileName,"&","");
	FileName = StrReplace(FileName,"<","");
	FileName = StrReplace(FileName,">","");
	FileName = StrReplace(FileName,"|","");
	FileName = StrReplace(FileName,"""","");
	
	Return FileName;
EndFunction 

&AtClient
Procedure GetPathToFileStartChoice(DialogMode, PathToFile, FileName = "")
	
	FileDialog = New FileDialog(DialogMode);
	
	FileDialog.Filter                      = NStr("en='Excel 2007 Workbook (*.xlsx)|*.xlsx|CSV (comma delimited) (*.csv)  |*.csv|Spreadsheet document(*.mxl)|*.mxl'");
	FileDialog.Title                       = Title;
	FileDialog.Preview                     = False;
	FileDialog.DefaultExt                  = "csv";
	FileDialog.FilterIndex                 = 0;
	FileDialog.FullFileName                = FileName;
	FileDialog.CheckFileExist = False;
	
	If FileDialog.Choose() Then
		PathToFile = FileDialog.FullFileName;
	EndIf;
	
EndProcedure

&AtServer
Procedure ImportFileWithDataToSpreadsheetDocumentAtServer(TempStorageAddress, Extension, BackgroundJob = False)
	TempFileName = GetTempFileName(Extension);
	BinaryData = GetFromTempStorage(TempStorageAddress);
	BinaryData.Write(TempFileName);
	
	ClearTemplateWithData();

	ServerCallParameters = New Structure();
	ServerCallParameters.Insert("Extension", Extension);
	ServerCallParameters.Insert("TemplateWithData", TemplateWithData);
	ServerCallParameters.Insert("TempFileName", TempFileName);
	ColumnInfoTable = FormAttributeToValue("ColumnInfo");
	ServerCallParameters.Insert("ColumnInfo", ColumnInfoTable);
	
	If CommonUse.FileInfobase() Then
		DataProcessors.DataImportFromFile.ImportFileToTable(ServerCallParameters, TempStorageAddress);
		TemplateWithData = GetFromTempStorage(TempStorageAddress);
	Else
		BackgroundJobResult = LongActions.ExecuteInBackground(UUID, 
		"DataProcessors.DataImportFromFile.ImportFileToTable",
		ServerCallParameters, 
		NStr("en = 'DataImportFromFile subsystem: Import data from file using the server method'"));
		
		If BackgroundJobResult.JobCompleted Then
			BackgroundJobStorageAddress = BackgroundJobResult.StorageAddress;
			TemplateWithData = GetFromTempStorage(BackgroundJobStorageAddress);
		Else 
			BackgroundJob = True;
			BackgroundJobID  = BackgroundJobResult.JobID;
			BackgroundJobStorageAddress = BackgroundJobResult.StorageAddress;
		EndIf;
	
	EndIf;
	
EndProcedure

#EndRegion 

#EndRegion