// There are two ways to parameterize a form:
//
// Option 1:
//    Parameters: 
//         InfobaseNode               - ExchangePlanRef - exchange plan node for which the wizard is started. 
//         ExportAdditionExtendedMode - Boolean - flag that shows whether the export addition setup is enabled.
//
// Option 2:
//     Parameters: 
//         InfobaseNode               - ExchangePlanRef - exchange plan for which the wizard is started. 
//         ExportAdditionExtendedMode - Boolean - flag that shows whether the export addition setup is enabled.
//         ExchangePlanName           - String - exchange plan manager name that is used for searching an exchange plan node
//                                      whose code is specified in the InfobaseNodeCode parameter.
//

&AtClient
Var SkipCurrentPageCancelControl;

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
 Var InfobaseNodeCode;
 // Skipping the initialization to guarantee that the form will be
 // received if the Autotest parameter is passed.
 If Parameters.Property("Autotest") Then
		Return;
 EndIf;
	
	Parameters.Property("ActivateOnDataExchangeSetupWizardClosing", ActivateOnDataExchangeSetupWizardClosing);
	
	IsStartedFromAnotherApplication = False;
	
	If Parameters.Property("InfobaseNode", Object.InfobaseNode) Then
		
		Object.ExchangePlanName = DataExchangeCached.GetExchangePlanName(Object.InfobaseNode);
		
	ElsIf Parameters.Property("InfobaseNodeCode", InfobaseNodeCode) Then
		
		IsStartedFromAnotherApplication = True;
		
		Object.InfobaseNode = ExchangePlans[Parameters.ExchangePlanName].FindByCode(InfobaseNodeCode);
		
		If Object.InfobaseNode.IsEmpty() Then
			
			DataExchangeServer.ReportError(NStr("en = 'Data exchange settings item not found.'"), Cancel);
			Return;
			
		EndIf;
		
		Object.ExchangePlanName = Parameters.ExchangePlanName;
		
	Else
		
		DataExchangeServer.ReportError(NStr("en = 'The wizard cannot be opened directly.'"), Cancel);
		Return;
		
	EndIf;
	
	If Not DataExchangeCached.IsUniversalDataExchangeNode(Object.InfobaseNode) Then
		
		// Only universal exchanges with conversion rules can be executed interactively
		DataExchangeServer.ReportError(
			NStr("en = 'Only universal exchanges with conversion rules can be executed interactively.'"), Cancel);
		Return;
		
	EndIf;
	
	NodeArray = DataExchangeCached.GetExchangePlanNodeArray(Object.ExchangePlanName);
	
	// Check whether exchange settings match the filter
	If NodeArray.Find(Object.InfobaseNode) = Undefined Then
		
		CommonUseClientServer.MessageToUser(NStr("en = 'The selected node does not provide data mapping.'"),,,, Cancel);
		Return;
		
	EndIf;
	
	Parameters.Property("ExchangeMessageTransportKind", Object.ExchangeMessageTransportKind);
	
	// Specifying the exchange message transport kind if it was not passed
	If Not ValueIsFilled(Object.ExchangeMessageTransportKind) Then
		
		ExchangeTransportSettings = InformationRegisters.ExchangeTransportSettings.TransportSettings(Object.InfobaseNode);
		Object.ExchangeMessageTransportKind = ExchangeTransportSettings.DefaultExchangeMessageTransportKind;
		If Not ValueIsFilled(Object.ExchangeMessageTransportKind) Then
			Object.ExchangeMessageTransportKind = Enums.ExchangeMessageTransportKinds.FILE;
		EndIf;
		
	EndIf;
	
	GetData  = True;
	SendData = True;
	CheckVersionDifference = True;
	
	If Parameters.Property("GetData") Then
		GetData = Parameters.GetData;
	EndIf;
	
	If Parameters.Property("SendData") Then
		SendData = Parameters.SendData;
	EndIf;
	
	DataExchangeServer.FillChoiceListWithAvailableTransportTypes(Object.InfobaseNode, Items.ExchangeMessageTransportKind);
	Parameters.Property("ExecuteMappingOnOpen", ExecuteMappingOnOpen);
	WizardRunVariant = "ExecuteMapping";
	
	DataImportEventLogMessage = DataExchangeServer.GetEventLogMessageKey(Object.InfobaseNode, Enums.ActionsOnExchange.DataImport);
	
	Title = StrReplace(Title, "%1", Object.InfobaseNode);
	
	// Export addition
	InitializeExportAdditionAttributes();
	
	// Flag that shows whether the transport page is skipped
	SkipTransportPage = ExportAdditionExtendedMode Or CommonUseClientServer.IsWebClient();
	
	RefreshTransportSettingsPages();
	
	// If the current interface version is 8.2
	If ClientApplicationInterfaceCurrentVariant() = ClientApplicationInterfaceVariant.Version8_2 Then
		SetGroupTitleFont(Items.PageTitle);
		SetGroupTitleFont(Items.StatisticsPageTitle);
		SetGroupTitleFont(Items.MappingEndPageTitle);
		SetGroupTitleFont(Items.ExportAdditionPageTitle);
		SetGroupTitleFont(Items.DataAnalysisWaitPageTitle);
		SetGroupTitleFont(Items.DataSynchronizationWaitPageTitle);
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	ForceCloseForm = False;
	
	GoToNumber = 1;
	SetGoToNumber(1);
	
	// Skipping the transport analysis page if setup is not required
	NextPage = False;
	ChangeTitle = Items.ExchangeMessageTransportKind.ChoiceList.Count()=1;
	
	If ExecuteMappingOnOpen Then
		NextPage = True;
	ElsIf SkipTransportPage Then
		// Going to the next page only if the password is not required
		If ExchangeOverWebService And Not WSRememberPassword Then
			// Hiding other items if the password is required
			Items.TransportKindSelectionFromAvailableKindsGroup.Visible = False;
			Items.Decoration3.Visible = False;
			Items.DataExchangeDirectory.Visible = False;
			ChangeTitle = True;
		Else
			// Password is not required. Skipping the page.
			NextPage = True;
		EndIf;
	EndIf;
	
	If ChangeTitle Then
		Items.PageTitle.Title = NStr("en='Connection parameters'");
	EndIf;
	
	If NextPage And ValueIsFilled(Object.ExchangeMessageTransportKind) Then
		// Going to the next page that provides statistics import
		GoNextExecute();
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	CurrentPage = Items.MainPanel.CurrentPage;
	
	If CurrentPage = Items.BeginningPage Then
		ConfirmationText = NStr("en='Do you want to cancel the data synchronization?'");
		
	Else
		ConfirmationText = NStr("en='Do you want to abort data synchronization?'");
		
	EndIf;
	
	CommonUseClient.ShowArbitraryFormClosingConfirmation(ThisObject, Cancel, ConfirmationText,
		"ForceCloseForm");
EndProcedure

&AtClient
Procedure OnClose()
	
	// Deleting the temporary directory
	DeleteTempExchangeMessageDirectory(Object.TempExchangeMessageDirectory);
	
	Notify("ObjectMappingWizardFormClosed");
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	// Checking whether the additional export item initialization event occurred 
	If DataExchangeClient.ExportAdditionChoiceProcessing(SelectedValue, ChoiceSource, ExportAddition) Then
		// Event is handled, updating filter details
		SetExportAdditionFilterDescription();
		Return;
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "ClosingObjectMappingForm" Then
		
		Cancel = False;
		
		Status(NStr("en = 'Gathering mapping data...'"));
		
		UpdateMappingStatisticsDataAtServer(Cancel, Parameter);
		
		If Cancel Then
			ShowMessageBox(, NStr("en = 'Error gathering statistic data.'"));
		Else
			
			ExpandStatisticsTree(Parameter.UniquenessKey);
			
			Status(NStr("en = 'Data gathering completed'"));
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

////////////////////////////////////////////////////////////////////////////////
// BeginningPage page.

&AtClient
Procedure ExchangeMessageTransportKindOnChange(Item)
	
	ExchangeMessageTransportKindOnChangeAtServer();
	
EndProcedure

&AtClient
Procedure DataExchangeDirectoryClick(Item)
	
	OpenNodeDataExchangeDirectory();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// QuestionAboutExportContentPage page.

&AtClient
Procedure ExportAdditionExportVariantOnChange(Item)
	ExportAdditionExportVariantSetVisibility();
EndProcedure

&AtClient
Procedure ExportAdditionNodeScenarioFilterPeriodOnChange(Item)
	ExportAdditionNodeScenarioPeriodChanging();
EndProcedure

&AtClient
Procedure ExportAdditionGeneralDocumentPeriodClearing(Item, StandardProcessing)
	// Prohibiting period clearing
	StandardProcessing = False;
EndProcedure

&AtClient
Procedure ExportAdditionNodeScenarioFilterPeriodClearing(Item, StandardProcessing)
	// Prohibiting period clearing
	StandardProcessing = False;
EndProcedure

#EndRegion

#Region StatisticsTreeFormTableItemEventHandlers

&AtClient
Procedure StatisticsTreeChoice(Item, SelectedRow, Field, StandardProcessing)
	
	OpenMappingForm(Undefined);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure NextCommand(Command)
	
	ChangeGoToNumber(+1);
	
EndProcedure

&AtClient
Procedure CancelCommand(Command)
	
	Close();
	
EndProcedure

&AtClient
Procedure DoneCommand(Command)
	// Updating all opened dynamic lists
	DataExchangeClient.RefreshAllOpenDynamicLists();
	
	ForceCloseForm = True;
	Close();
	
EndProcedure

&AtClient
Procedure OpenScheduleSetup(Command)
	FormParameters = New Structure("InfobaseNode", Object.InfobaseNode);
	OpenForm("Catalog.DataExchangeScenarios.ObjectForm", FormParameters, ThisObject);
EndProcedure

&AtClient
Procedure ContinueSynchronization(Command)
	
	GoToNumber = GoToNumber - 1;
	SetGoToNumber(GoToNumber + 1);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// BeginningPage page.

&AtClient
Procedure GoNextExecute()
	
	ChangeGoToNumber(+1);
	
EndProcedure

&AtClient
Procedure OpenDataExchangeDirectory(Command)
	
	OpenNodeDataExchangeDirectory();
	
EndProcedure

&AtClient
Procedure SetupExchangeMessageTransportParameters(Command)
	
	Filter        = New Structure("Node", Object.InfobaseNode);
	FillingValues = New Structure("Node", Object.InfobaseNode);
	
	Notification = New NotifyDescription("SetupExchangeMessageTransportParametersCompletion", ThisObject);
	DataExchangeClient.OpenInformationRegisterRecordFormByFilter(Filter, FillingValues, "ExchangeTransportSettings", ThisObject,,, Notification);

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// StatisticsPage page.

&AtClient
Procedure UpdateMappingInfoFully(Command)
	
	CurrentData = Items.StatisticsTree.CurrentData;
	
	If CurrentData <> Undefined Then
		
		CurrentRowKey = CurrentData.Key;
		
	EndIf;
	
	Cancel = False;
	
	RowKeys = New Array;
	
	GetAllRowKeys(RowKeys, StatisticsTree.GetItems());
	
	If RowKeys.Count() > 0 Then
		
		Status(NStr("en = 'Gathering mapping data...'"));
		
		UpdateMappingByRowDetailsAtServer(Cancel, RowKeys);
		
	EndIf;
	
	If Cancel Then
		ShowMessageBox(, NStr("en = 'Error gathering statistic data.'"));
	Else
		
		ExpandStatisticsTree(CurrentRowKey);
		
		Status(NStr("en = 'Data gathering completed.'"));
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteDataImportForRow(Command)
	
	Cancel = False;
	
	SelectedRows = Items.StatisticsTree.SelectedRows;
	
	If SelectedRows.Count() = 0 Then
		NString = NStr("en = 'Select a table name in the statistics field.'");
		CommonUseClientServer.MessageToUser(NString,,"StatisticsTree",, Cancel);
		Return;
	EndIf;
	
	HasUnmappedObjects = False;
	For Each RowID In SelectedRows Do
		TreeRow = StatisticsTree.FindByID(RowID);
		
		If IsBlankString(TreeRow.Key) Then
			Continue;
		EndIf;
		
		If TreeRow.UnmappedObjectCount <> 0 Then
			HasUnmappedObjects = True;
			Break;
		EndIf;
	EndDo;
	
	If HasUnmappedObjects Then
		NString = NStr("en = 'Unmapped objects are detected.
		                     |Duplicates of unmapped objects will be created during data import. Do you want to continue?'");
		
		Notification = New NotifyDescription("ExecuteDataImportForRowQuestionUnmapped", ThisObject, New Structure);
		Notification.AdditionalParameters.Insert("SelectedRows", SelectedRows);
		ShowQueryBox(Notification, NString, QuestionDialogMode.YesNo, , DialogReturnCode.No);
		Return;
	EndIf;
	
	ExecuteDataImportForRowContinued(SelectedRows);
EndProcedure

&AtClient
Procedure OpenMappingForm(Command)
	
	CurrentData = Items.StatisticsTree.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If IsBlankString(CurrentData.Key) Then
		Return;
	EndIf;
	
	If Not CurrentData.UsePreview Then
		ShowMessageBox(, NStr("en = 'Object mapping cannot be performed for the data type.'"));
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("TargetTableName",           CurrentData.TargetTableName);
	FormParameters.Insert("SourceTableObjectTypeName", CurrentData.ObjectTypeString);
	FormParameters.Insert("TargetTableFields",         CurrentData.TableFields);
	FormParameters.Insert("TargetTableSearchFields",   CurrentData.SearchFields);
	FormParameters.Insert("SourceTypeString",          CurrentData.SourceTypeString);
	FormParameters.Insert("TargetTypeString",          CurrentData.TargetTypeString);
	FormParameters.Insert("IsObjectDeletion",          CurrentData.IsObjectDeletion);
	FormParameters.Insert("DataImportedSuccessfully",  CurrentData.DataImportedSuccessfully);
	FormParameters.Insert("Key",                       CurrentData.Key);
	
	FormParameters.Insert("InfobaseNode",               Object.InfobaseNode);
	FormParameters.Insert("ExchangeMessageFileName",    Object.ExchangeMessageFileName);
	
	OpenForm("DataProcessor.InfobaseObjectMapping.Form", FormParameters, ThisObject);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// MappingCompletePage page.

&AtClient
Procedure GoToDataImportEventLog(Command)
	
	DataExchangeClient.GoToDataEventLogModally(Object.InfobaseNode, ThisObject, "DataImport");
	
EndProcedure

&AtClient
Procedure GoToDataExportEventLog(Command)
	
	DataExchangeClient.GoToDataEventLogModally(Object.InfobaseNode, ThisObject, "DataExport");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// QuestionAboutExportContentPage page.

&AtClient
Procedure ExportAdditionGeneralDocumentFilter(Command)
	DataExchangeClient.OpenExportAdditionFormAllDocuments(ExportAddition, ThisObject);
EndProcedure

&AtClient
Procedure ExportAdditionDetailedFilter(Command)
	DataExchangeClient.OpenExportAdditionFormDetailedFilter(ExportAddition, ThisObject);
EndProcedure

&AtClient
Procedure ExportAdditionFilterByNodeScenario(Command)
	DataExchangeClient.OpenExportAdditionFormNodeScenario(ExportAddition, ThisObject);
EndProcedure

&AtClient
Procedure ExportAdditionExportContent(Command)
	DataExchangeClient.OpenExportAdditionFormDataContent(ExportAddition, ThisObject);
EndProcedure

&AtClient
Procedure ExportAdditionGeneralFilterClearing(Command)
	
	TitleText    = NStr("en='Confirmation'");
	QuestionText = NStr("en='Clear general filter?'");
	NotifyDescription = New NotifyDescription("ExportAdditionGeneralFilterClearingCompletion", ThisObject);
	ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo,,,TitleText);
	
EndProcedure

&AtClient
Procedure ExportAdditionDetailedFilterClearing(Command)
	TitleText    = NStr("en='Confirmation'");
	QuestionText = NStr("en='Clear detailed filter?'");
	NotifyDescription = New NotifyDescription("ExportAdditionDetailedFilterClearingCompletion", ThisObject);
	ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo,,,TitleText);
EndProcedure

&AtClient
Procedure ExportAdditionFilterHistory(Command)
	// Filling a menu list with all saved settings options
	VariantList = ExportAdditionServerSettingsHistory();
	
	// Adding the option for saving the current settings
	Text = NStr("en='Save current settings...'");
	VariantList.Add(1, Text, , PictureLib.SaveReportSettings);
	
	NotifyDescription = New NotifyDescription("ExportAdditionFilterHistoryMenuSelection", ThisObject);
	ShowChooseFromMenu(NotifyDescription, VariantList, Items.ExportAdditionFilterHistory);
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure SetGroupTitleFont(Val GroupItem)
	
	GroupItem.TitleFont = New Font(StyleFonts.LargeTextFont, , , True);
	
EndProcedure

&AtClient
Procedure SetupExchangeMessageTransportParametersCompletion(CloseResult, AdditionalParameters) Export
	
	RefreshTransportSettingsPages();
	
EndProcedure
	
&AtClient
Procedure ExportAdditionFilterHistoryCompletion(Answer, SettingsItemPresentation) Export
	
	If Answer = DialogReturnCode.Yes Then
		ExportAdditionSetSettingsServer(SettingsItemPresentation);
		ExportAdditionExportVariantSetVisibility();
	EndIf;
	
EndProcedure

&AtClient
Procedure ExportAdditionGeneralFilterClearingCompletion(Answer, AdditionalParameters) Export
	
	If Answer = DialogReturnCode.Yes Then
		ExportAdditionGeneralFilterClearingServer();
	EndIf;
	
EndProcedure

&AtClient
Procedure ExportAdditionDetailedFilterClearingCompletion(Answer, AdditionalParameters) Export
	If Answer = DialogReturnCode.Yes Then
		ExportAdditionDetailedFilterClearingServer();
	EndIf;
EndProcedure

&AtClient
Procedure ExportAdditionFilterHistoryMenuSelection(Val SelectedItem, Val AdditionalParameters) Export
	
	If SelectedItem = Undefined Then
		Return;
	EndIf;
		
	SettingsItemPresentation = SelectedItem.Value;
	If TypeOf(SettingsItemPresentation) = Type("String") Then
		// A previously saved settings item is selected
		
		TitleText    = NStr("en='Confirmation'");
		QuestionText = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en='Restore ""%1"" settings?'"), SettingsItemPresentation);
		
		NotifyDescription = New NotifyDescription("ExportAdditionFilterHistoryCompletion", ThisObject, SettingsItemPresentation);
		ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo,,,TitleText);
		
	ElsIf SettingsItemPresentation=1 Then
		// The option to save the settings is selected. Opening the settings form.
		DataExchangeClient.OpenExportAdditionFormSettingsSaving(ExportAddition, ThisObject);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteDataImportForRowQuestionUnmapped(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	ExecuteDataImportForRowContinued(AdditionalParameters.SelectedRows);
EndProcedure

&AtClient
Procedure ExecuteDataImportForRowContinued(Val SelectedRows) 

	RowKeys = GetSelectedRowKeys(SelectedRows);
	If RowKeys.Count() = 0 Then
		Return;
	EndIf;
	
	Status(NStr("en = 'Importing data...'"));
	
	Cancel = False;
	ExecuteDataImportAtServer(Cancel, RowKeys);
	
	If Cancel Then
		NString = NStr("en = 'Errors occurred during data import.
		                     |Do you want to view the event log?'");
		
		NotifyDescription = New NotifyDescription("GoToEventLog", ThisObject);
		ShowQueryBox(NotifyDescription, NString, QuestionDialogMode.YesNo, ,DialogReturnCode.No);
		Return;
	EndIf;
		
	ExpandStatisticsTree(RowKeys[RowKeys.UBound()]);
	Status(NStr("en = 'Data import completed.'"));
EndProcedure

&AtClient
Procedure OpenNodeDataExchangeDirectory()
	
	// Server call without context
	DirectoryName = GetDirectoryNameAtServer(Object.ExchangeMessageTransportKind, Object.InfobaseNode);
	
	If IsBlankString(DirectoryName) Then
		ShowMessageBox(, NStr("en = 'Data exchange directory is not specified.'"));
		Return;
	EndIf;
	
	Notification = New NotifyDescription("OpenNodeDataExchangeDirectoryCompletion", ThisObject, New Structure);
	Notification.AdditionalParameters.Insert("DirectoryName", DirectoryName);
	SuggestionText = NStr("en = 'To be able to select directory, install the file system extension.'");
	
	CommonUseClient.CheckFileSystemExtensionAttached(Notification, SuggestionText);
EndProcedure

&AtClient
Procedure OpenNodeDataExchangeDirectoryCompletion(Result, AdditionalParameters) Export
	
	DirectoryName = AdditionalParameters.DirectoryName;
	
	WarningText = "";
	
	File = New File(DirectoryName);
	If Not File.Exist() Then
		WarningText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'The %1 directory does not exist or is inaccessible.'"),
			DirectoryName
		);
		
	ElsIf Not File.IsDirectory() Then
		WarningText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = '%1 is not a directory, it is a file.'"),
			DirectoryName
		);
		
	EndIf;
	
	If IsBlankString(WarningText) Then
		// Opening the directory using operating system methods
		RunApp(DirectoryName);
	Else
		ShowMessageBox(, WarningText);
	EndIf;
	
EndProcedure

&AtClient
Procedure GoToEventLog(Val QuestionResult, Val AdditionalParameters) Export
	
	If QuestionResult = DialogReturnCode.Yes Then
		
		DataExchangeClient.GoToDataEventLogModally(Object.InfobaseNode, ThisObject, "DataImport");
		
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdateMappingByRowDetailsAtServer(Cancel, RowKeys)
	
	RowIndexes = GetStatisticsTableRowIndexes(RowKeys);
	
	DataProcessorObject = FormAttributeToValue("Object");
	
	// Getting mapping statistic data
	DataProcessorObject.GetObjectMappingByRowStats(Cancel, RowIndexes);
	
	ValueToFormAttribute(DataProcessorObject, "Object");
	
	GetStatisticsTree(DataProcessorObject.StatisticsTable());
	
	AllDataMapped = DataProcessors.InteractiveDataExchangeWizard.AllDataMapped(DataProcessorObject.StatisticsTable());
	
	SetAdditionalInfoGroupVisible();
	
EndProcedure

&AtServer
Procedure ExecuteDataImportAtServer(Cancel, RowKeys)
	
	RowIndexes = GetStatisticsTableRowIndexes(RowKeys);
	
	DataProcessorObject = FormAttributeToValue("Object");
	
	// Importing data
	DataProcessorObject.ExecuteDataImport(Cancel, RowIndexes);
	
	// Getting mapping statistic data
	DataProcessorObject.GetObjectMappingByRowStats(Cancel, RowIndexes);
	
	ValueToFormAttribute(DataProcessorObject, "Object");
	
	GetStatisticsTree(DataProcessorObject.StatisticsTable());
	
	AllDataMapped = DataProcessors.InteractiveDataExchangeWizard.AllDataMapped(DataProcessorObject.StatisticsTable());
	
	SetAdditionalInfoGroupVisible();
	
EndProcedure

&AtServer
Procedure UpdateMappingStatisticsDataAtServer(Cancel, NotificationParameters)
	
	TableRows = Object.Statistics.FindRows(New Structure("Key", NotificationParameters.UniquenessKey));
	
	FillPropertyValues(TableRows[0], NotificationParameters, "DataImportedSuccessfully");
	
	RowKeys = New Array;
	RowKeys.Add(NotificationParameters.UniquenessKey);
	
	UpdateMappingByRowDetailsAtServer(Cancel, RowKeys);
	
EndProcedure

&AtServer
Procedure GetStatisticsTree(Statistics)
	
	TreeItemCollection = StatisticsTree.GetItems();
	TreeItemCollection.Clear();
	
	CommonUse.FillFormDataTreeItemCollection(TreeItemCollection,
		DataExchangeServer.GetStatisticsTree(Statistics));
	
EndProcedure

&AtServer
Procedure SetAdditionalInfoGroupVisible()
	
	Items.DataMappingStatusPages.CurrentPage = ?(AllDataMapped,
		Items.MappingStatusAllDataMapped,
		Items.MappingStatusHasUnmappedData
	);
EndProcedure

&AtServer
Procedure ExchangeMessageTransportKindOnChangeAtServer()
	
	ExchangeOverExternalConnection = (Object.ExchangeMessageTransportKind = Enums.ExchangeMessageTransportKinds.COM);
	ExchangeOverWebService         = (Object.ExchangeMessageTransportKind = Enums.ExchangeMessageTransportKinds.WS);
	
	ExchangeOverConnectionToCorrespondent = ExchangeOverExternalConnection Or ExchangeOverWebService;
	
	ExternalConnectionParameterStructure = InformationRegisters.ExchangeTransportSettings.TransportSettings(Object.InfobaseNode);
	ExternalConnectionParameterStructure = DeletePrefixInCollectionKeys(ExternalConnectionParameterStructure, "COM");
	
	If IsStartedFromAnotherApplication Then
		
		Items.ScheduleSettingsInfoLabel.Visible = False;
		
		OpenDataExchangeScenarioCreationWizard = False;
		
	Else
		
		NodeUsedInExchangeScenario = InfobaseNodeUsedInExchangeScenario(Object.InfobaseNode);
		
		Items.ScheduleSettingsInfoLabel.Visible = Not NodeUsedInExchangeScenario And Users.RolesAvailable("DataSynchronizationSetup");
		
		OpenDataExchangeScenarioCreationWizard = Users.RolesAvailable("DataSynchronizationSetup");
        
        Items.ScheduleSettingsInfoLabel.Visible = OpenDataExchangeScenarioCreationWizard;
	EndIf;
    
	// Filling the navigation table
	If ExchangeOverConnectionToCorrespondent Then
		
		If GetData And SendData Then
			
			SendAndReceiveDataOverExternalConnectionOrWebService();
			
		ElsIf GetData Then
			
			ReceiveDataOverExternalConnectionOrWebService();;
			
		ElsIf SendData Then
			
			SendDataOverExternalConnectionOrWebService();
			
		Else
			
			Raise NStr("en = 'The specified data synchronization scenario is not supported.'");
			
		EndIf;
		
	Else
		
		If GetData And SendData Then
			
			SendAndReceiveDataOverRegularCommunicationChannels();
			
		ElsIf GetData Then
			
			ReceiveDataOverRegularCommunicationChannels();
			
		ElsIf SendData Then
			
			SendDataOverRegularCommunicationChannels();
			
		Else
			
			Raise NStr("en = 'The specified data synchronization scenario is not supported.'");
			
		EndIf;
		
	EndIf;
	
	SetExchangeDirectoryOpeningButtonVisible();
	
	Items.WSPassword.Visible         = False;
	Items.WSPasswordLabel.Title      = "";
	Items.WSRememberPassword.Visible = False;

	If ExchangeOverWebService Then
		
		// Getting connection settings of the correspondent web service.
		// These settings are used for the recurrent request sending to the correspondent to check whether 
   // the long data exporting is completed.
		SettingsStructure = InformationRegisters.ExchangeTransportSettings.TransportSettingsWS(Object.InfobaseNode);
		FillPropertyValues(ThisObject, SettingsStructure, "WSURL, WSUserName, WSPassword, WSRememberPassword");
		
        Items.WSPassword.Visible = Not WSRememberPassword;
        Items.WSRememberPassword.Visible = Not WSRememberPassword;		
	EndIf;
	
EndProcedure

// Deletes the specified literal (prefix) from key names of the passed structure.
// Creates a new structure with keys from the passed structure where literals were deleted.
//
// Parameters:
//  Structure - Structure - source structure.
//  Literal   - String - characters to be deleted.
//
// Returns:
//  Structure - new structure with keys from the passed structure where literals were deleted.
//
&AtServer
Function DeletePrefixInCollectionKeys(Structure, Literal)
	
	Result = New Structure;
	
	For Each Item In Structure Do
		
		Result.Insert(StrReplace(Item.Key, Literal, ""), Item.Value);
		
	EndDo;
	
	Return Result;
EndFunction

&AtServer
Function GetStatisticsTableRowIndexes(RowKeys)
	
	RowIndexes = New Array;
	
	For Each Key In RowKeys Do
		
		TableRows = Object.Statistics.FindRows(New Structure("Key", Key));
		
		LineIndex = Object.Statistics.IndexOf(TableRows[0]);
		
		RowIndexes.Add(LineIndex);
		
	EndDo;
	
	Return RowIndexes;
	
EndFunction

&AtServerNoContext
Procedure GetDataExchangeStates(DataImportResult, DataExportResult, Val InfobaseNode)
	
	DataExchangeStates = DataExchangeServer.ExchangeNodeDataExchangeStates(InfobaseNode);
	
	DataImportResult = DataExchangeStates["DataImportResult"];
	If IsBlankString(DataExportResult) Then
		DataExportResult = DataExchangeStates["DataExportResult"];
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure DeleteTempExchangeMessageDirectory(TempDirectoryName)
	
	If Not IsBlankString(TempDirectoryName) Then
		
		Try
			DeleteFiles(TempDirectoryName);
			TempDirectoryName = "";
		Except
			WriteLogEvent(NStr("en = 'Data exchange.Temporary file deletion'", CommonUseClientServer.DefaultLanguageCode()),
				EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo())
			);
		EndTry;
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure WriteErrorToEventLog(ErrorMessageString, Event)
	
	WriteLogEvent(Event, EventLogLevel.Error,,, ErrorMessageString);
	
EndProcedure

&AtServerNoContext
Function GetDirectoryNameAtServer(ExchangeMessageTransportKind, InfobaseNode)
	
	Return InformationRegisters.ExchangeTransportSettings.DataExchangeDirectoryName(ExchangeMessageTransportKind, InfobaseNode);
	
EndFunction

&AtServerNoContext
Function InfobaseNodeUsedInExchangeScenario(InfobaseNode)
	
	QueryText = "
	|SELECT TOP 1 1
	|FROM
	|	Catalog.DataExchangeScenarios.ExchangeSettings AS DataExchangeScenarioExchangeSettings
	|WHERE
	|		 DataExchangeScenarioExchangeSettings.InfobaseNode = &InfobaseNode
	|	AND Not DataExchangeScenarioExchangeSettings.Ref.DeletionMark
	|";
	
	Query = New Query;
	Query.SetParameter("InfobaseNode", InfobaseNode);
	Query.Text = QueryText;
	
	Return Not Query.Execute().IsEmpty();
	
EndFunction

&AtServer
Procedure ExecuteDataExchangeForInfobaseNodeAtServer(Cancel)
	
	ActionStartDate = CurrentSessionDate();
	
	// Saving export addition settings
	DataExchangeServer.InteractiveExportModificationSaveSettings(ExportAddition, 
		DataExchangeServer.ExportAdditionSettingsAutoSavingName());
	
	// Registering additional data
	DataExchangeServer.InteractiveExportModificationRegisterAdditionalData(ExportAddition);

	DataExchangeServer.ExecuteDataExchangeForInfobaseNode(
		Cancel,
		Object.InfobaseNode,
		False,
		True,
		Object.ExchangeMessageTransportKind,
		LongAction,
		ActionID,
		FileID,
		True,
		WSPassword);
	
EndProcedure

&AtServer
Procedure RefreshTransportSettingsPages()
	
	IsInRoleAddEditDataExchanges = Users.RolesAvailable("DataSynchronizationSetup");
	
	Items.SetupExchangeMessageTransportParameters.Visible = IsInRoleAddEditDataExchanges;
	
	DefaultExchangeMessageTransportKind = InformationRegisters.ExchangeTransportSettings.DefaultExchangeMessageTransportKind(Object.InfobaseNode);
	ConfiguredTransportTypes            = InformationRegisters.ExchangeTransportSettings.ConfiguredTransportTypes(Object.InfobaseNode);
	CurrentTransportKind                = Object.ExchangeMessageTransportKind;
	
	DataExchangeServer.FillChoiceListWithAvailableTransportTypes(Object.InfobaseNode, Items.ExchangeMessageTransportKind, ConfiguredTransportTypes);
	
	TransportChoiceList = Items.ExchangeMessageTransportKind.ChoiceList;
	
	Items.ExchangeMessageTransportKindString.TextColor = New Color;
	
	If TransportChoiceList.FindByValue(CurrentTransportKind)<>Undefined Then
		// No changes
		
	ElsIf TransportChoiceList.FindByValue(DefaultExchangeMessageTransportKind)<>Undefined Then
		
		Object.ExchangeMessageTransportKind = DefaultExchangeMessageTransportKind;
		
	ElsIf TransportChoiceList.Count()>0 Then
		Object.ExchangeMessageTransportKind = TransportChoiceList[0].Value;
		
	Else
		// No data to process
		Object.ExchangeMessageTransportKind = Undefined;
		
		TransportChoiceList.Clear();
		TransportChoiceList.Add(Undefined, NStr("en='connection not configured'") );
		
		Items.ExchangeMessageTransportKindString.TextColor = StyleColors.ErrorInformationText
	EndIf;
	
	Items.ExchangeMessageTransportKindString.Title   = TransportChoiceList[0].Presentation;
	Items.ExchangeMessageTransportKindString.Visible = TransportChoiceList.Count()=1;
	Items.ExchangeMessageTransportKind.Visible       = Not Items.ExchangeMessageTransportKindString.Visible;
	
	ExchangeMessageTransportKindOnChangeAtServer();
EndProcedure

&AtServer
Procedure SetExchangeDirectoryOpeningButtonVisible()
	
	ButtonVisibility = Object.ExchangeMessageTransportKind = Enums.ExchangeMessageTransportKinds.FILE
	Or Object.ExchangeMessageTransportKind = Enums.ExchangeMessageTransportKinds.FTP;
	
	Items.DataExchangeDirectory.Visible = ButtonVisibility;
	If ButtonVisibility Then
		Items.DataExchangeDirectory.Title = GetDirectoryNameAtServer(Object.ExchangeMessageTransportKind, Object.InfobaseNode);
	EndIf;
EndProcedure

&AtClient
Procedure ProcessVersionDifferenceError()
	
	Items.MainPanel.CurrentPage = Items.VersionMismatchErrorPage;
	Items.NavigationPanel.CurrentPage = Items.VersionMismatchErrorNavigationPage;
	Items.ContinueSynchronization.DefaultButton = True;
	Items.DecorationVersionDifferenceError.Title = VersionDifferenceErrorOnGetData.ErrorText;
	VersionDifferenceErrorOnGetData = Undefined;
	CheckVersionDifference = False;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Idle handlers.

&AtClient
Procedure LongActionIdleHandler()
	
	LongActionCompletedWithError = False;
	LongActionErrorMessageString = "";
	
	ActionState = DataExchangeServerCall.LongActionState(ActionID,
																		WSURL,
																		WSUserName,
																		WSPassword,
																		LongActionErrorMessageString);
	
	If ActionState = "Active" Then
		
		AttachIdleHandler("LongActionIdleHandler", 5, True);
		
	Else
		
		If ActionState <> "Completed" Then
			
			LongActionCompletedWithError = True;
			
		EndIf;
		
		LongAction = False;
		LongActionFinished = True;
		
		GoNextExecute();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure BackgroundJobIdleHandler()
	
	LongActionCompletedWithError = False;
	
	State = DataExchangeServerCall.JobState(JobID);
	
	If State = "Active" Then
		
		AttachIdleHandler("BackgroundJobIdleHandler", 5, True);
		
	Else // Completed, Failed
		
		If State <> "Completed" Then
			
			LongActionCompletedWithError = True;
			
		EndIf;
		
		LongAction = False;
		LongActionFinished = True;
		
		GoNextExecute();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteLongActionHandler()
	
	GoToRowsCurrent = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber));
	
	If GoToRowsCurrent.Count() = 0 Then
		Raise NStr("en = 'Page to be displayed is not specified.'");
	EndIf;
	
	GoToRowCurrent = GoToRowsCurrent[0];
	
	// LongActionProcessing handler
	If Not IsBlankString(GoToRowCurrent.LongActionHandlerName) Then
		
		ProcedureName = "Attachable_[HandlerName](Cancel, GoToNext)";
		ProcedureName = StrReplace(ProcedureName, "[HandlerName]", GoToRowCurrent.LongActionHandlerName);
		
		Cancel = False;
		GoToNext = True;
		
		A = Eval(ProcedureName);
		
		If Cancel Then
			
			If VersionDifferenceErrorOnGetData <> Undefined
				And VersionDifferenceErrorOnGetData.HasError Then
				
				ProcessVersionDifferenceError();
				Return;
				
			EndIf;
			
			SetGoToNumber(GoToNumber - 1);
			
			Return;
			
		ElsIf GoToNext Then
			
			SetGoToNumber(GoToNumber + 1);
			
			Return;
			
		EndIf;
		
	Else
		
		SetGoToNumber(GoToNumber + 1);
		
		Return;
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Wizard procedures and functions.

&AtClient
Function GetSelectedRowKeys(SelectedRows)
	
	// Return value
	RowKeys = New Array;
	
	For Each RowID In SelectedRows Do
		
		TreeRow = StatisticsTree.FindByID(RowID);
		
		If Not IsBlankString(TreeRow.Key) Then
			
			RowKeys.Add(TreeRow.Key);
			
		EndIf;
		
	EndDo;
	
	Return RowKeys;
EndFunction

&AtClient
Procedure GetAllRowKeys(RowKeys, TreeItemCollection)
	
	For Each TreeRow In TreeItemCollection Do
		
		If Not IsBlankString(TreeRow.Key) Then
			
			RowKeys.Add(TreeRow.Key);
			
		EndIf;
		
		ItemCollection = TreeRow.GetItems();
		
		If ItemCollection.Count() > 0 Then
			
			GetAllRowKeys(RowKeys, ItemCollection);
			
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure RefreshDataExchangeStatusItemPresentation()
	
	Items.DataImportStatusPages.CurrentPage = Items[DataExchangeClient.DataImportStatusPages()[DataImportResult]];
	If Items.DataImportStatusPages.CurrentPage=Items.ImportStatusUndefined Then
		Items.GoToDataImportEventLog.Title = NStr("en='Data is not imported.'");
	Else
		Items.GoToDataImportEventLog.Title = DataExchangeClient.DataImportHyperlinkHeaders()[DataImportResult];
	EndIf;
	
	Items.DataExportStatusPages.CurrentPage = Items[DataExchangeClient.DataExportStatusPages()[DataExportResult]];
	If Items.DataExportStatusPages.CurrentPage=Items.ExportStatusUndefined Then
		Items.GoToDataExportEventLog.Title = NStr("en='Data is not exported.'");
	Else
		Items.GoToDataExportEventLog.Title = DataExchangeClient.DataExportHyperlinkHeaders()[DataExportResult];
	EndIf;
	
EndProcedure

&AtClient
Procedure ExpandStatisticsTree(RowKey = "")
	
	ItemCollection = StatisticsTree.GetItems();
	
	For Each TreeRow In ItemCollection Do
		
		Items.StatisticsTree.Expand(TreeRow.GetID(), True);
		
	EndDo;
	
	// Specifying the value tree cursor position
	If Not IsBlankString(RowKey) Then
		
		RowID = 0;
		
		CommonUseClientServer.GetTreeRowIDByFieldValue("Key", RowID, StatisticsTree.GetItems(), RowKey, False);
		
		Items.StatisticsTree.CurrentRow = RowID;
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Internal procedures and functions.

&AtClient
Procedure ChangeGoToNumber(Iterator)
	
	ClearMessages();
	
	SetGoToNumber(GoToNumber + Iterator);
	
EndProcedure

&AtClient
Procedure SetGoToNumber(Val Value)
	
	IsGoNext = (Value > GoToNumber);
	
	GoToNumber = Value;
	
	If GoToNumber < 0 Then
		
		GoToNumber = 0;
		
	EndIf;
	
	GoToNumberOnChange(IsGoNext);
	
EndProcedure

&AtClient
Procedure GoToNumberOnChange(Val IsGoNext)
	
	// Executing wizard step change event handlers
	ExecuteGoToEventHandlers(IsGoNext);
	
	// Setting page to be displayed
	GoToRowsCurrent = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber));
	
	If GoToRowsCurrent.Count() = 0 Then
		Raise NStr("en = 'Page to be displayed is not specified.'");
	EndIf;
	
	GoToRowCurrent = GoToRowsCurrent[0];
	
	Items.MainPanel.CurrentPage       = Items[GoToRowCurrent.MainPageName];
	Items.NavigationPanel.CurrentPage = Items[GoToRowCurrent.NavigationPageName];
	
	// Setting the default button
	NextButton = GetFormButtonByCommandName(Items.NavigationPanel.CurrentPage, "NextCommand");
	
	If NextButton <> Undefined Then
		
		NextButton.DefaultButton = True;
		
	Else
		
		DoneButton = GetFormButtonByCommandName(Items.NavigationPanel.CurrentPage, "DoneCommand");
		
		If DoneButton <> Undefined Then
			
			DoneButton.DefaultButton = True;
			
		EndIf;
		
	EndIf;
	
	If IsGoNext And GoToRowCurrent.LongAction Then
		
		AttachIdleHandler("ExecuteLongActionHandler", 0.1, True);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteGoToEventHandlers(Val IsGoNext)
	
	// Step change handlers
	If IsGoNext Then
		
		GoToRows = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber - 1));
		
		If GoToRows.Count() = 0 Then
			Return;
		EndIf;
		
		GoToRow = GoToRows[0];
		
		// OnGoNext handler
		If Not IsBlankString(GoToRow.GoNextHandlerName)
			And Not GoToRow.LongAction Then
			
			ProcedureName = "Attachable_[HandlerName](Cancel)";
			ProcedureName = StrReplace(ProcedureName, "[HandlerName]", GoToRow.GoNextHandlerName);
			
			Cancel = False;
			
			A = Eval(ProcedureName);
			
			If Cancel Then
				
				SetGoToNumber(GoToNumber - 1);
				
				Return;
				
			EndIf;
			
		EndIf;
		
	Else
		
		GoToRows = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber + 1));
		
		If GoToRows.Count() = 0 Then
			Return;
		EndIf;
		
		GoToRow = GoToRows[0];
		
		// OnGoBack handler
		If Not IsBlankString(GoToRow.GoBackHandlerName)
			And Not GoToRow.LongAction Then
			
			ProcedureName = "Attachable_[HandlerName](Cancel)";
			ProcedureName = StrReplace(ProcedureName, "[HandlerName]", GoToRow.GoBackHandlerName);
			
			Cancel = False;
			
			A = Eval(ProcedureName);
			
			If Cancel Then
				
				SetGoToNumber(GoToNumber + 1);
				
				Return;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	GoToRowsCurrent = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber));
	
	If GoToRowsCurrent.Count() = 0 Then
		Raise NStr("en = 'Page to be displayed is not specified.'");
	EndIf;
	
	GoToRowCurrent = GoToRowsCurrent[0];
	
	If GoToRowCurrent.LongAction And Not IsGoNext Then
		
		SetGoToNumber(GoToNumber - 1);
		Return;
	EndIf;
	
	// OnOpen handler
	If Not IsBlankString(GoToRowCurrent.OnOpenHandlerName) Then
		
		ProcedureName = "Attachable_[HandlerName](Cancel, SkipPage, IsGoNext)";
		ProcedureName = StrReplace(ProcedureName, "[HandlerName]", GoToRowCurrent.OnOpenHandlerName);
		
		Cancel = False;
		SkipPage = False;
		
		A = Eval(ProcedureName);
		
		If Cancel Then
			
			SetGoToNumber(GoToNumber - 1);
			
			Return;
			
		ElsIf SkipPage Then
			
			If IsGoNext Then
				
				SetGoToNumber(GoToNumber + 1);
				
				Return;
				
			Else
				
				SetGoToNumber(GoToNumber - 1);
				
				Return;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure GoToTableNewRow(GoToNumber,
									MainPageName,
									NavigationPageName,
									DecorationPageName = "",
									OnOpenHandlerName = "",
									GoNextHandlerName = "",
									GoBackHandlerName = "",
									LongAction = False,
									LongActionHandlerName = "")
	NewRow = GoToTable.Add();
	
	NewRow.GoToNumber         = GoToNumber;
	NewRow.MainPageName       = MainPageName;
	NewRow.DecorationPageName = DecorationPageName;
	NewRow.NavigationPageName = NavigationPageName;
	
	NewRow.GoNextHandlerName = GoNextHandlerName;
	NewRow.GoBackHandlerName = GoBackHandlerName;
	NewRow.OnOpenHandlerName = OnOpenHandlerName;
	
	NewRow.LongAction = LongAction;
	NewRow.LongActionHandlerName = LongActionHandlerName;
	
EndProcedure

&AtClient
Function GetFormButtonByCommandName(FormItem, CommandName)
	
	For Each Item In FormItem.ChildItems Do
		
		If TypeOf(Item) = Type("FormGroup") Then
			
			//Return GetFormButtonByCommandName(Item, CommandName);
			FormItemByCommandName = GetFormButtonByCommandName(Item, CommandName);
			
			If FormItemByCommandName <> Undefined Then
				
				Return FormItemByCommandName;
				
			EndIf;
			
		ElsIf TypeOf(Item) = Type("FormButton")
			And Item.CommandName = CommandName Then
			
			Return Item;
			
		Else
			
			Continue;
			
		EndIf;
		
	EndDo;
	
	Return Undefined;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Overridable part. Step change handlers.

&AtClient
Function Attachable_BeginningPage_OnGoNext(Cancel)
	
	// Checking whether form attributes are filled
	If Object.InfobaseNode.IsEmpty() Then
		
		NString = NStr("en = 'Specify the infobase node.'");
		CommonUseClientServer.MessageToUser(NString,, "Object.InfobaseNode",, Cancel);
		
	ElsIf Object.ExchangeMessageTransportKind.IsEmpty() Then
		
		NString = NStr("en = 'Specify the exchange message transport kind.'");
		CommonUseClientServer.MessageToUser(NString,, "Object.ExchangeMessageTransportKind",, Cancel);
		
	ElsIf ExchangeOverWebService And IsBlankString(WSPassword) Then
		
		NString = NStr("en = 'No password specified.'");
		CommonUseClientServer.MessageToUser(NString,, "WSPassword",, Cancel);
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_ConnectionCheckIdlePage_LongActionProcessing(Cancel, GoToNext)
	
	If ExchangeOverWebService Then
		
		TestConnectionAndSaveSettings(Cancel);
		
		If Cancel Then
			
			ShowMessageBox(, NStr("en = 'Cannot execute the operation.'"));
			
		EndIf;
		
	EndIf;
	
EndFunction

&AtServer
Procedure TestConnectionAndSaveSettings(Cancel)
	
	ConnectionParameters = DataExchangeServer.WSParameterStructure();
	FillPropertyValues(ConnectionParameters, ThisObject);
	
	UserMessage = "";
	WSProxy = DataExchangeServer.GetWSProxy(ConnectionParameters,, UserMessage);
	If WSProxy = Undefined Then
		CommonUseClientServer.MessageToUser(UserMessage,,"WSPassword",, Cancel);
		Return;
	EndIf;
	
	If WSRememberPassword Then
		
		Try
			
			SetPrivilegedMode(True);
			
			// Updating record in the information register
			RecordStructure = New Structure;
			RecordStructure.Insert("Node", Object.InfobaseNode);
			RecordStructure.Insert("WSRememberPassword", True);
			RecordStructure.Insert("WSPassword", WSPassword);
			InformationRegisters.ExchangeTransportSettings.UpdateRecord(RecordStructure);
			
		Except
			WriteLogEvent(DataExchangeServer.EventLogMessageTextDataExchange(),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
			CommonUseClientServer.MessageToUser(BriefErrorDescription(ErrorInfo()),,,, Cancel);
			Return;
		EndTry;
		
	EndIf;
	
EndProcedure

// Getting data (exchange message transport).

&AtClient
Function Attachable_DataAnalysisIdlePage_LongActionProcessing(Cancel, GoToNext)
	
	ExchangeMessageTransport();
	
EndFunction

&AtServer
Procedure ExchangeMessageTransport()
	
	Try
		
		SkipGettingData = False;
		
		LongAction = False;
		LongActionFinished = False;
		LongActionCompletedWithError = False;
		FileID = "";
		ActionID = "";
		
		DataProcessorObject = FormAttributeToValue("Object");
		
		Cancel = False;
		
		DataProcessorObject.GetExchangeMessageToTemporaryDirectory(
				Cancel,
				DataPackageFileID,
				FileID,
				LongAction,
				ActionID,
				WSPassword
		);
		ValueToFormAttribute(DataProcessorObject, "Object");
		
		If Cancel Then
			SkipGettingData = True;
		EndIf;
		
	Except
		SkipGettingData = True;
		WriteErrorToEventLog(DetailErrorDescription(ErrorInfo()),
			NStr("en = 'Interactive data exchange wizard.Exchange message transport'")
		);
		Return;
	EndTry;
	
EndProcedure

&AtClient
Function Attachable_DataAnalysisIdlePageLongAction_LongActionProcessing(Cancel, GoToNext)
	
	If SkipGettingData Then
		Return Undefined;
	EndIf;
	
	If LongAction Then
		
		GoToNext = False;
		
		AttachIdleHandler("LongActionIdleHandler", 5, True);
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_DataAnalysisIdlePageLongActionCompletion_LongActionProcessing(Cancel, GoToNext)
	
	If SkipGettingData Then
		Return Undefined;
	EndIf;
	
	If LongActionFinished Then
		
		If LongActionCompletedWithError Then
			
			SkipGettingData = True;
			
			WriteErrorToEventLog(LongActionErrorMessageString, DataImportEventLogMessage);
			
		Else
			
			ExchangeMessageTransportLongActionCompletion();
			
		EndIf;
		
	EndIf;
	
EndFunction

&AtServer
Procedure ExchangeMessageTransportLongActionCompletion()
	
	Try
		DataProcessorObject = FormAttributeToValue("Object");
		
		Cancel = False;
		
		DataProcessorObject.GetExchangeMessageToTempDirectoryLongActionEnd(
			Cancel,
			DataPackageFileID,
			FileID,
			WSPassword);
		
		ValueToFormAttribute(DataProcessorObject, "Object");
		
		If Cancel Then
			SkipGettingData = True;
		EndIf;
		
	Except
		SkipGettingData = True;
		WriteErrorToEventLog(DetailErrorDescription(ErrorInfo()),
			NStr("en = 'Interactive data exchange wizard.Exchange message transport'")
		);
		Return;
	EndTry;
	
EndProcedure

// Data analysis.
// Automatic data mapping.

&AtClient
Function Attachable_DataAnalysis_LongActionProcessing(Cancel, GoToNext)
	
	If SkipGettingData Then
		Return Undefined;
	EndIf;
	
	DataAnalysis();
	
	If VersionDifferenceErrorOnGetData <> Undefined
		And VersionDifferenceErrorOnGetData.HasError Then
		Cancel = True;
	EndIf;
	
EndFunction

&AtServer
Procedure DataAnalysis()
	
	LongAction = False;
	LongActionFinished = False;
	JobID = Undefined;
	TempStorageAddress = "";
	
	Try
		
		If CommonUse.FileInfobase() Then
			
			AnalysisResult = DataProcessors.InteractiveDataExchangeWizard.AutomaticDataMappingResult(
				Object.InfobaseNode,
				Object.ExchangeMessageFileName,
				Object.TempExchangeMessageDirectory,
				CheckVersionDifference);
			
			AfterDataAnalysis(AnalysisResult);
			
		Else
			
			MethodParameters = New Structure;
			MethodParameters.Insert("InfobaseNode",                 Object.InfobaseNode);
			MethodParameters.Insert("ExchangeMessageFileName",      Object.ExchangeMessageFileName);
			MethodParameters.Insert("TempExchangeMessageDirectory", Object.TempExchangeMessageDirectory);
			MethodParameters.Insert("CheckVersionDifference",       CheckVersionDifference);
			
			Result = LongActions.ExecuteInBackground(
				UUID,
				"DataProcessors.InteractiveDataExchangeWizard.ExecuteAutomaticDataMapping",
				MethodParameters,
				NStr("en = 'Analyzing exchange message data'")
			);
			
			If Result.JobCompleted Then
				
				AfterDataAnalysis(GetFromTempStorage(Result.StorageAddress));
				
			Else
				
				LongAction = True;
				JobID = Result.JobID;
				TempStorageAddress = Result.StorageAddress;
				
			EndIf;
			
		EndIf;
		
	Except
		
		SkipGettingData = True;
		WriteErrorToEventLog(DetailErrorDescription(ErrorInfo()),
			NStr("en = 'Interactive data exchange wizard.Data analysis'"));
		
	EndTry;
	
EndProcedure

&AtClient
Function Attachable_DataAnalysisLongAction_LongActionProcessing(Cancel, GoToNext)
	
	If SkipGettingData Then
		Return Undefined;
	EndIf;
	
	If LongAction Then
		
		GoToNext = False;
		
		AttachIdleHandler("BackgroundJobIdleHandler", 5, True);
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_DataAnalysisLongActionCompletion_LongActionProcessing(Cancel, GoToNext)
	
	If SkipGettingData Then
		Return Undefined;
	EndIf;
	
	If LongActionFinished Then
		
		If LongActionCompletedWithError Then
			
			SkipGettingData = True;
			
		Else
			
			DataAnalysisLongActionCompletion();
			
		EndIf;
		
	EndIf;
	
	If SkipGettingData Then
		Return Undefined;
	EndIf;
	
	ExpandStatisticsTree();
	
EndFunction

&AtServer
Procedure DataAnalysisLongActionCompletion()
	
	Try
		AfterDataAnalysis(GetFromTempStorage(TempStorageAddress));
	Except
		SkipGettingData = True;
		WriteErrorToEventLog(DetailErrorDescription(ErrorInfo()),
			NStr("en = 'Interactive data exchange wizard.Data analysis'")
		);
		Return;
	EndTry;
	
EndProcedure

&AtServer
Procedure AfterDataAnalysis(Val AnalysisResult)
	
	If AnalysisResult.Property("ErrorText") Then
		VersionDifferenceErrorOnGetData = AnalysisResult;
	Else
		
		AllDataMapped   = AnalysisResult.AllDataMapped;
		StatisticsEmpty = AnalysisResult.StatisticsEmpty;
		Object.Statistics.Load(AnalysisResult.Statistics);
		Object.Statistics.Sort("Presentation");
		
		GetStatisticsTree(Object.Statistics.Unload());
		
		SetAdditionalInfoGroupVisible();
		
	EndIf;
	
EndProcedure

// Manual data mapping.

&AtClient
Function Attachable_StatisticsPage_OnOpen(Cancel, SkipPage, IsGoNext)
	
	If StatisticsEmpty Or SkipGettingData Then
		SkipPage = True;
	EndIf;
	
EndFunction

&AtClient
Function Attachable_StatisticsPage_OnGoNext(Cancel)
	
	If StatisticsEmpty Or SkipGettingData Or AllDataMapped Then
		Return Undefined;
	EndIf;
	
	If True = SkipCurrentPageCancelControl Then
		SkipCurrentPageCancelControl = Undefined;
		Return Undefined;
	EndIf;
	
	// Going to the next page after user confirmation
	Cancel = True;
	
	Buttons = New ValueList;
	Buttons.Add(DialogReturnCode.Yes,  NStr("en = 'Continue'"));
	Buttons.Add(DialogReturnCode.No, NStr("en = 'Cancel'"));
	
	Message = NStr("en = 'Some data is not mapped. Leaving unmapped
	                       |data can result in duplicate catalog items.
	                       |Do you want to continue?'");
	
	Notification = New NotifyDescription("StatisticsPage_OnGoNextQuestionCompletion", ThisObject);
	
	ShowQueryBox(Notification, Message, Buttons,, DialogReturnCode.Yes);
EndFunction

&AtClient
Procedure StatisticsPage_OnGoNextQuestionCompletion(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	AttachIdleHandler("Attachable_GoToStepForwardWithDeferredProcessing", 0.1, True);
EndProcedure

&AtClient
Procedure Attachable_GoToStepForwardWithDeferredProcessing()
	
	// Going a step forward (forced)
	SkipCurrentPageCancelControl = True;
	ChangeGoToNumber( +1 );
	
EndProcedure
	
// Data import.

&AtClient
Function Attachable_DataImport_LongActionProcessing(Cancel, GoToNext)
	
	If SkipGettingData Then
		Return Undefined;
	EndIf;
	
	DataImport();
	
	// Going to the next page regardless of the data import result
	
EndFunction

&AtServer
Procedure DataImport()
	
	LongAction = False;
	LongActionFinished = False;
	JobID = Undefined;
	
	Try
		
		If CommonUse.FileInfobase() Then
			
			DataExchangeServer.ExecuteDataExchangeForInfobaseNodeOverFileOrString(
				Object.InfobaseNode,
				Object.ExchangeMessageFileName,
				Enums.ActionsOnExchange.DataImport
			);
			
			DeleteTempExchangeMessageDirectory(Object.TempExchangeMessageDirectory);
			
		Else
			
			MethodParameters = New Structure;
			MethodParameters.Insert("InfobaseNode", Object.InfobaseNode);
			MethodParameters.Insert("ExchangeMessageFileName", Object.ExchangeMessageFileName);
			
			Result = LongActions.ExecuteInBackground(
				UUID,
				"DataProcessors.InteractiveDataExchangeWizard.ExecuteDataImport",
				MethodParameters,
				NStr("en = 'Importing data from the exchange message'")
			);
			
			If Result.JobCompleted Then
				
				DeleteTempExchangeMessageDirectory(Object.TempExchangeMessageDirectory);
				
			Else
				
				LongAction = True;
				JobID = Result.JobID;
				
			EndIf;
			
		EndIf;
		
	Except
		SkipGettingData = True;
		DeleteTempExchangeMessageDirectory(Object.TempExchangeMessageDirectory);
		WriteErrorToEventLog(DetailErrorDescription(ErrorInfo()),
			NStr("en = 'Interactive data exchange wizard.Data import'")
		);
		Return;
	EndTry;
	
EndProcedure

&AtClient
Function Attachable_DataImportLongAction_LongActionProcessing(Cancel, GoToNext)
	
	If SkipGettingData Then
		Return Undefined;
	EndIf;
	
	If LongAction Then
		
		GoToNext = False;
		
		AttachIdleHandler("BackgroundJobIdleHandler", 5, True);
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_DataImportLongActionCompletion_LongActionProcessing(Cancel, GoToNext)
	
	If SkipGettingData Then
		Return Undefined;
	EndIf;
	
	If LongActionFinished Then
		
		DeleteTempExchangeMessageDirectory(Object.TempExchangeMessageDirectory);
		
	EndIf;
	
EndFunction

// Additional export.

&AtClient
Function Attachable_QuestionAboutExportContentPage_OnOpen(Cancel, SkipPage, IsGoNext)
	
	If ExportAddition.ExportVariant<0 Then
		// According to the node settings, export addition is not performed. Going to the next page.
		SkipPage = True;
	EndIf;
	
EndFunction

// Data export.

&AtClient
Function Attachable_DataExportIdlePage_LongActionProcessing(Cancel, GoToNext)
	
	LongAction = False;
	LongActionFinished = False;
	LongActionCompletedWithError = False;
	FileID = "";
	ActionID = "";
	
	// Going to the next page (unconditionally)
	IntermediateCancel = False;
	ExecuteDataExchangeForInfobaseNodeAtServer(IntermediateCancel);
EndFunction

&AtClient
Function Attachable_DataExportIdlePageLongAction_LongActionProcessing(Cancel, GoToNext)
	
	If LongAction Then
		
		GoToNext = False;
		
		AttachIdleHandler("LongActionIdleHandler", 5, True);
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_DataExportIdlePageLongActionCompletion_LongActionProcessing(Cancel, GoToNext)
	
	If LongActionFinished Then
		
		If LongActionCompletedWithError Then
			
			DataExchangeServerCall.AddExchangeFinishedWithErrorEventLogMessage(
									Object.InfobaseNode,
									"DataExport",
									ActionStartDate,
									LongActionErrorMessageString);
			
		Else
			
			DataExchangeServerCall.CommitDataExportExecutionInLongActionMode(Object.InfobaseNode, ActionStartDate);
			
		EndIf;
		
	EndIf;
	
EndFunction

// Totals.

&AtClient
Function Attachable_MappingCompletePage_OnOpen(Cancel, SkipPage, Val IsGoNext)
	
	GetDataExchangeStates(DataImportResult, DataExportResult, Object.InfobaseNode);
	
	RefreshDataExchangeStatusItemPresentation();
	
	Return Undefined;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for export addition operations.

&AtServer
Procedure InitializeExportAdditionAttributes()
	
	// Filling the form attribute with the parameter value
	Parameters.Property("ExportAdditionExtendedMode", ExportAdditionExtendedMode);
	
	// Getting settings structure. The settings are implicitly saved to a temporary form storage.
	ExportAdditionSettings = DataExchangeServer.InteractiveExportModification(
		Object.InfobaseNode, ThisObject.UUID, ExportAdditionExtendedMode);
		
	// Setting up the form.
	// Converting ThisObject form attribute to a value of DataProcessor type.
  // This simplifies access to form data.
	DataExchangeServer.InteractiveExportModificationAttributeBySettings(ThisObject, ExportAdditionSettings, "ExportAddition");
	
	AdditionScenarioParameters = ExportAddition.AdditionScenarioParameters;
	
	// Configuring interface according to the specified scenario
	
	// Special cases
	StandardVariantsProhibited = Not AdditionScenarioParameters.VariantWithoutAddition.Use
		And Not AdditionScenarioParameters.AllDocumentVariant.Use
		And Not AdditionScenarioParameters.ArbitraryFilterVariant.Use;
		
	If StandardVariantsProhibited Then
		If AdditionScenarioParameters.AdditionalVariant.Use Then
			// A single node scenario option is available
			Items.ExportAdditionExportVariantNodeString.Visible = True;
			Items.ExportAdditionNodeExportVariant.Visible = False;
			Items.DecorationCustomGroupIndent.Visible = False;
			ExportAddition.ExportVariant = 3;
		Else
			// No options are available.
     // Setting the skip page flag value to True and exiting the procedure.
			ExportAddition.ExportVariant = -1;
			Items.ExportAdditionVariants.Visible = False;
			Return;
		EndIf;
	EndIf;
	
	// Setting input field properties
	Items.StandardAdditionVariantNo.Visible = AdditionScenarioParameters.VariantWithoutAddition.Use;
	If Not IsBlankString(AdditionScenarioParameters.VariantWithoutAddition.Title) Then
		Items.ExportAdditionExportVariant0.ChoiceList[0].Presentation = AdditionScenarioParameters.VariantWithoutAddition.Title;
	EndIf;
	Items.StandardAdditionVariantNoExplanation.Title = AdditionScenarioParameters.VariantWithoutAddition.Explanation;
	If IsBlankString(Items.StandardAdditionVariantNoExplanation.Title) Then
		Items.StandardAdditionVariantNoExplanation.Visible = False;
	EndIf;
	
	Items.StandardAdditionVariantDocuments.Visible = AdditionScenarioParameters.AllDocumentVariant.Use;
	If Not IsBlankString(AdditionScenarioParameters.AllDocumentVariant.Title) Then
		Items.ExportAdditionExportVariant1.ChoiceList[0].Presentation = AdditionScenarioParameters.AllDocumentVariant.Title;
	EndIf;
	Items.StandardAdditionVariantDocumentsExplanation.Title = AdditionScenarioParameters.AllDocumentVariant.Explanation;
	If IsBlankString(Items.StandardAdditionVariantDocumentsExplanation.Title) Then
		Items.StandardAdditionVariantDocumentsExplanation.Visible = False;
	EndIf;
	
	Items.StandardAdditionVariantArbitrary.Visible = AdditionScenarioParameters.ArbitraryFilterVariant.Use;
	If Not IsBlankString(AdditionScenarioParameters.ArbitraryFilterVariant.Title) Then
		Items.ExportAdditionExportVariant2.ChoiceList[0].Presentation = AdditionScenarioParameters.ArbitraryFilterVariant.Title;
	EndIf;
	Items.StandardAdditionVariantArbitraryExplanation.Title = AdditionScenarioParameters.ArbitraryFilterVariant.Explanation;
	If IsBlankString(Items.StandardAdditionVariantArbitraryExplanation.Title) Then
		Items.StandardAdditionVariantArbitraryExplanation.Visible = False;
	EndIf;
	
	Items.CustomAdditionVariant.Visible              = AdditionScenarioParameters.AdditionalVariant.Use;
	Items.ExportPeriodNodeScenarioGroup.Visible      = AdditionScenarioParameters.AdditionalVariant.UseFilterPeriod;
	Items.ExportAdditionFilterByNodeScenario.Visible = Not IsBlankString(AdditionScenarioParameters.AdditionalVariant.FilterFormName);
	
	Items.ExportAdditionNodeExportVariant.ChoiceList[0].Presentation = AdditionScenarioParameters.AdditionalVariant.Title;
	Items.ExportAdditionExportVariantNodeString.Title                = AdditionScenarioParameters.AdditionalVariant.Title;
	
	Items.CustomAdditionVariantExplanation.Title = AdditionScenarioParameters.AdditionalVariant.Explanation;
	If IsBlankString(Items.CustomAdditionVariantExplanation.Title) Then
		Items.CustomAdditionVariantExplanation.Visible = False;
	EndIf;
	
	// Command titles
	If Not IsBlankString(AdditionScenarioParameters.AdditionalVariant.FormCommandTitle) Then
		Items.ExportAdditionFilterByNodeScenario.Title = AdditionScenarioParameters.AdditionalVariant.FormCommandTitle;
	EndIf;
	
	// Sorting visible items
	AdditionGroupOrder = New ValueList;
	If Items.StandardAdditionVariantNo.Visible Then
		AdditionGroupOrder.Add(Items.StandardAdditionVariantNo, 
			Format(AdditionScenarioParameters.VariantWithoutAddition.Order, "ND=10; NZ=; NLZ=; NG="));
	EndIf;
	If Items.StandardAdditionVariantDocuments.Visible Then
		AdditionGroupOrder.Add(Items.StandardAdditionVariantDocuments, 
			Format(AdditionScenarioParameters.AllDocumentVariant.Order, "ND=10; NZ=; NLZ=; NG="));
	EndIf;
	If Items.StandardAdditionVariantArbitrary.Visible Then
		AdditionGroupOrder.Add(Items.StandardAdditionVariantArbitrary, 
			Format(AdditionScenarioParameters.ArbitraryFilterVariant.Order, "ND=10; NZ=; NLZ=; NG="));
	EndIf;
	If Items.CustomAdditionVariant.Visible Then
		AdditionGroupOrder.Add(Items.CustomAdditionVariant, 
			Format(AdditionScenarioParameters.AdditionalVariant.Order, "ND=10; NZ=; NLZ=; NG="));
	EndIf;
	AdditionGroupOrder.SortByPresentation();
	For Each AdditionGroupItem In AdditionGroupOrder Do
		Items.Move(AdditionGroupItem.Value, Items.ExportAdditionVariants);
	EndDo;
	
	// Editing settings is only allowed if the appropriate rights are granted
	HasRightsToSetup = AccessRight("SaveUserData", Metadata);
	Items.StandardSettingsVariantImportGroup.Visible = HasRightsToSetup;
	If HasRightsToSetup Then
		// Restoring predefined settings
		SetFirstItem = Not ExportAdditionSetSettingsServer(DataExchangeServer.ExportAdditionSettingsAutoSavingName());
		ExportAddition.CurrentSettingsItemPresentation = "";
	Else
		SetFirstItem = True;
	EndIf;
		
	SetFirstItem = SetFirstItem
		Or
		ExportAddition.ExportVariant<0 
		Or
		( (ExportAddition.ExportVariant=0) And (Not AdditionScenarioParameters.VariantWithoutAddition.Use) )
		Or
		( (ExportAddition.ExportVariant=1) And (Not AdditionScenarioParameters.AllDocumentVariant.Use) )
		Or
		( (ExportAddition.ExportVariant=2) And (Not AdditionScenarioParameters.ArbitraryFilterVariant.Use) )
		Or
		( (ExportAddition.ExportVariant=3) And (Not AdditionScenarioParameters.AdditionalVariant.Use) );
	
	If SetFirstItem Then
		For Each AdditionGroupItem In AdditionGroupOrder[0].Value.ChildItems Do
			If TypeOf(AdditionGroupItem) = Type("FormField") And AdditionGroupItem.Type = FormFieldType.RadioButtonField Then
				ExportAddition.ExportVariant = AdditionGroupItem.ChoiceList[0].Value;
				Break;
			EndIf;
		EndDo;
	EndIf;
	
	// Initial view, same as ExportAdditionExportVariantSetVisibility client procedure
	Items.AllDocumentsFilterGroup.Enabled  = ExportAddition.ExportVariant=1;
	Items.DetailedFilterGroup.Enabled     = ExportAddition.ExportVariant=2;
	Items.CustomFilterGroup.Enabled = ExportAddition.ExportVariant=3;
	
	// Description of standard initial filters
	SetExportAdditionFilterDescription();
EndProcedure

&AtClient
Procedure ExportAdditionExportVariantSetVisibility()
	Items.AllDocumentsFilterGroup.Enabled = ExportAddition.ExportVariant=1;
	Items.DetailedFilterGroup.Enabled     = ExportAddition.ExportVariant=2;
	Items.CustomFilterGroup.Enabled       = ExportAddition.ExportVariant=3;
EndProcedure

&AtServer
Procedure ExportAdditionNodeScenarioPeriodChanging()
	DataExchangeServer.InteractiveExportModificationSetNodeScenarioPeriod(ExportAddition);
EndProcedure

&AtServer
Procedure ExportAdditionGeneralFilterClearingServer()
	DataExchangeServer.InteractiveExportModificationGeneralFilterClearing(ExportAddition);
	SetGeneralFilterAdditionDescription();
EndProcedure

&AtServer
Procedure ExportAdditionDetailedFilterClearingServer()
	DataExchangeServer.InteractiveExportModificationDetailsClearing(ExportAddition);
	SetAdditionDetailDescription();
EndProcedure

&AtServer
Procedure SetExportAdditionFilterDescription()
	SetGeneralFilterAdditionDescription();
	SetAdditionDetailDescription();
EndProcedure

&AtServer
Procedure SetGeneralFilterAdditionDescription()
	
	Text = DataExchangeServer.InteractiveExportModificationGeneralFilterAdditionDescription(ExportAddition);
	NoFilter = IsBlankString(Text);
	If NoFilter Then
		Text = NStr("en='All documents'");
	EndIf;
	
	Items.ExportAdditionGeneralDocumentFilter.Title   = Text;
	Items.ExportAdditionGeneralFilterClearing.Visible = Not NoFilter;
EndProcedure

&AtServer
Procedure SetAdditionDetailDescription()
	
	Text = DataExchangeServer.InteractiveExportModificationDetailedFilterDetails(ExportAddition);
	NoFilter = IsBlankString(Text);
	If NoFilter Then
		Text = NStr("en='Additional data is not selected'");
	EndIf;
	
	Items.ExportAdditionDetailedFilter.Title = Text;
	Items.ExportAdditionDetailedFilterClearing.Visible = Not NoFilter;
EndProcedure

// Returns a Boolean value: True if settings are restored, False if settings are not found.
&AtServer 
Function ExportAdditionSetSettingsServer(SettingsItemPresentation)
	Result = DataExchangeServer.InteractiveExportModificationRestoreSettings(ExportAddition, SettingsItemPresentation);
	SetExportAdditionFilterDescription();
	Return Result;
EndFunction

&AtServer 
Function ExportAdditionServerSettingsHistory() 
	Return DataExchangeServer.InteractiveExportModificationSettingsHistory(ExportAddition);
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Overridable part. Filling wizard navigation table.

&AtServer
Procedure ReceiveDataOverRegularCommunicationChannels()
	
	GoToTable.Clear();
	
	// Beginning
	GoToTableNewRow(1, "BeginningPage", "NavigationPageStart",,, "BeginningPage_OnGoNext");
	
	// Getting data (exchange message transport)
	GoToTableNewRow(2, "DataAnalysisIdlePage", "NavigationPageWait",,,,, True, "DataAnalysisIdlePage_LongActionProcessing");
	GoToTableNewRow(3, "DataAnalysisIdlePage", "NavigationPageWait",,,,, True, "DataAnalysisIdlePageLongAction_LongActionProcessing");
	GoToTableNewRow(4, "DataAnalysisIdlePage", "NavigationPageWait",,,,, True, "DataAnalysisIdlePageLongActionCompletion_LongActionProcessing");
	
	// Data analysis
	// Automatic data mapping
	GoToTableNewRow(5, "DataAnalysisIdlePage", "NavigationPageWait",,,,, True, "DataAnalysis_LongActionProcessing");
	GoToTableNewRow(6, "DataAnalysisIdlePage", "NavigationPageWait",,,,, True, "DataAnalysisLongAction_LongActionProcessing");
	GoToTableNewRow(7, "DataAnalysisIdlePage", "NavigationPageWait",,,,, True, "DataAnalysisLongActionCompletion_LongActionProcessing");
	
	// Manual data mapping
	GoToTableNewRow(8, "StatisticsPage", "NavigationPageContinuation",, "StatisticsPage_OnOpen", "StatisticsPage_OnGoNext");
	
	// Data import
	GoToTableNewRow(9,  "DataSynchronizationWaitPage", "NavigationPageWait",,,,, True, "DataImport_LongActionProcessing");
	GoToTableNewRow(10, "DataSynchronizationWaitPage", "NavigationPageWait",,,,, True, "DataImportLongAction_LongActionProcessing");
	GoToTableNewRow(11, "DataSynchronizationWaitPage", "NavigationPageWait",,,,, True, "DataImportLongActionCompletion_LongActionProcessing");
	
	// Totals
	GoToTableNewRow(12, "MappingCompletePage", "NavigationPageEnd",, "MappingCompletePage_OnOpen");
	
EndProcedure

&AtServer
Procedure ReceiveDataOverExternalConnectionOrWebService()
	
	GoToTable.Clear();
	
	// Connection test
	GoToTableNewRow(1, "BeginningPage",         "NavigationPageStart",,, "BeginningPage_OnGoNext");
	GoToTableNewRow(2, "DataAnalysisIdlePage",  "NavigationPageWait",,,,, True, "ConnectionCheckIdlePage_LongActionProcessing");
	
	// Getting data (exchange message transport)
	GoToTableNewRow(3, "DataAnalysisIdlePage", "NavigationPageWait",,,,, True, "DataAnalysisIdlePage_LongActionProcessing");
	GoToTableNewRow(4, "DataAnalysisIdlePage", "NavigationPageWait",,,,, True, "DataAnalysisIdlePageLongAction_LongActionProcessing");
	GoToTableNewRow(5, "DataAnalysisIdlePage", "NavigationPageWait",,,,, True, "DataAnalysisIdlePageLongActionCompletion_LongActionProcessing");
	
	// Data analysis
	// Automatic data mapping
	GoToTableNewRow(6, "DataAnalysisIdlePage", "NavigationPageWait",,,,, True, "DataAnalysis_LongActionProcessing");
	GoToTableNewRow(7, "DataAnalysisIdlePage", "NavigationPageWait",,,,, True, "DataAnalysisLongAction_LongActionProcessing");
	GoToTableNewRow(8, "DataAnalysisIdlePage", "NavigationPageWait",,,,, True, "DataAnalysisLongActionCompletion_LongActionProcessing");
	
	// Manual data mapping
	GoToTableNewRow(9, "StatisticsPage", "NavigationPageContinuation",, "StatisticsPage_OnOpen", "StatisticsPage_OnGoNext");
	
	// Data import
	GoToTableNewRow(10, "DataSynchronizationWaitPage", "NavigationPageWait",,,,, True, "DataImport_LongActionProcessing");
	GoToTableNewRow(11, "DataSynchronizationWaitPage", "NavigationPageWait",,,,, True, "DataImportLongAction_LongActionProcessing");
	GoToTableNewRow(12, "DataSynchronizationWaitPage", "NavigationPageWait",,,,, True, "DataImportLongActionCompletion_LongActionProcessing");
	
	// Totals
	GoToTableNewRow(13, "MappingCompletePage", "NavigationPageEnd",, "MappingCompletePage_OnOpen");
	
EndProcedure

&AtServer
Procedure SendDataOverRegularCommunicationChannels()
	
	GoToTable.Clear();
	
	// Beginning
	GoToTableNewRow(1, "BeginningPage", "NavigationPageStart",,, "BeginningPage_OnGoNext");
	
	// Data export setup
	DataExportResult = "";
	GoToTableNewRow(2, "QuestionAboutExportContentPage", "NavigationPageContinuation",, "QuestionAboutExportContentPage_OnOpen");
	
	// Data export
	GoToTableNewRow(3, "DataSynchronizationWaitPage", "NavigationPageWait",,,,, True, "DataExportIdlePage_LongActionProcessing");
	GoToTableNewRow(4, "DataSynchronizationWaitPage", "NavigationPageWait",,,,, True, "DataExportIdlePageLongAction_LongActionProcessing");
	GoToTableNewRow(5, "DataSynchronizationWaitPage", "NavigationPageWait",,,,, True, "DataExportIdlePageLongActionCompletion_LongActionProcessing");
	
	// Totals
	GoToTableNewRow(6, "MappingCompletePage", "NavigationPageEnd",, "MappingCompletePage_OnOpen");
	
EndProcedure

&AtServer
Procedure SendDataOverExternalConnectionOrWebService()
	
	GoToTable.Clear();
	
	// Connection test
	GoToTableNewRow(1, "BeginningPage",               "NavigationPageStart",,, "BeginningPage_OnGoNext");
	GoToTableNewRow(2, "DataSynchronizationWaitPage", "NavigationPageWait",,,,, True, "ConnectionCheckIdlePage_LongActionProcessing");
	
	// Data export setup
	DataExportResult = "";
	GoToTableNewRow(3, "QuestionAboutExportContentPage",  "NavigationPageContinuation",, "QuestionAboutExportContentPage_OnOpen");
	
	// Data export
	GoToTableNewRow(4, "DataSynchronizationWaitPage", "NavigationPageWait",,,,, True, "DataExportIdlePage_LongActionProcessing");
	GoToTableNewRow(5, "DataSynchronizationWaitPage", "NavigationPageWait",,,,, True, "DataExportIdlePageLongAction_LongActionProcessing");
	GoToTableNewRow(6, "DataSynchronizationWaitPage", "NavigationPageWait",,,,, True, "DataExportIdlePageLongActionCompletion_LongActionProcessing");
	
	// Totals
	GoToTableNewRow(7, "MappingCompletePage", "NavigationPageEnd",, "MappingCompletePage_OnOpen");
	
EndProcedure

&AtServer
Procedure SendAndReceiveDataOverRegularCommunicationChannels()
	
	GoToTable.Clear();
	
	// Beginning
	GoToTableNewRow(1, "BeginningPage", "NavigationPageStart",,, "BeginningPage_OnGoNext");
	
	// Getting data (exchange message transport)
	GoToTableNewRow(2, "DataAnalysisIdlePage", "NavigationPageWait",,,,, True, "DataAnalysisIdlePage_LongActionProcessing");
	GoToTableNewRow(3, "DataAnalysisIdlePage", "NavigationPageWait",,,,, True, "DataAnalysisIdlePageLongAction_LongActionProcessing");
	GoToTableNewRow(4, "DataAnalysisIdlePage", "NavigationPageWait",,,,, True, "DataAnalysisIdlePageLongActionCompletion_LongActionProcessing");
	
	// Data analysis
	// Automatic data mapping
	GoToTableNewRow(5, "DataAnalysisIdlePage", "NavigationPageWait",,,,, True, "DataAnalysis_LongActionProcessing");
	GoToTableNewRow(6, "DataAnalysisIdlePage", "NavigationPageWait",,,,, True, "DataAnalysisLongAction_LongActionProcessing");
	GoToTableNewRow(7, "DataAnalysisIdlePage", "NavigationPageWait",,,,, True, "DataAnalysisLongActionCompletion_LongActionProcessing");
	
	// Manual data mapping
	GoToTableNewRow(8, "StatisticsPage", "NavigationPageContinuation",, "StatisticsPage_OnOpen", "StatisticsPage_OnGoNext");
	
	// Data import
	GoToTableNewRow(9,  "DataSynchronizationWaitPage", "NavigationPageWait",,,,, True, "DataImport_LongActionProcessing");
	GoToTableNewRow(10, "DataSynchronizationWaitPage", "NavigationPageWait",,,,, True, "DataImportLongAction_LongActionProcessing");
	GoToTableNewRow(11, "DataSynchronizationWaitPage", "NavigationPageWait",,,,, True, "DataImportLongActionCompletion_LongActionProcessing");
	
	// Data export setup
	DataExportResult = "";
	GoToTableNewRow(12, "QuestionAboutExportContentPage", "NavigationPageContinuation",, "QuestionAboutExportContentPage_OnOpen");
	
	// Data export
	GoToTableNewRow(13, "DataSynchronizationWaitPage", "NavigationPageWait",,,,, True, "DataExportIdlePage_LongActionProcessing");
	GoToTableNewRow(14, "DataSynchronizationWaitPage", "NavigationPageWait",,,,, True, "DataExportIdlePageLongAction_LongActionProcessing");
	GoToTableNewRow(15, "DataSynchronizationWaitPage", "NavigationPageWait",,,,, True, "DataExportIdlePageLongActionCompletion_LongActionProcessing");
	
	// Totals
	GoToTableNewRow(16, "MappingCompletePage", "NavigationPageEnd",, "MappingCompletePage_OnOpen");
	
EndProcedure

&AtServer
Procedure SendAndReceiveDataOverExternalConnectionOrWebService()
	
	GoToTable.Clear();
	
	// Connection test
	GoToTableNewRow(1, "BeginningPage",        "NavigationPageStart",,, "BeginningPage_OnGoNext");
	GoToTableNewRow(2, "DataAnalysisIdlePage", "NavigationPageWait",,,,, True, "ConnectionCheckIdlePage_LongActionProcessing");
	
	// Getting data (exchange message transport)
	GoToTableNewRow(3, "DataAnalysisIdlePage", "NavigationPageWait",,,,, True, "DataAnalysisIdlePage_LongActionProcessing");
	GoToTableNewRow(4, "DataAnalysisIdlePage", "NavigationPageWait",,,,, True, "DataAnalysisIdlePageLongAction_LongActionProcessing");
	GoToTableNewRow(5, "DataAnalysisIdlePage", "NavigationPageWait",,,,, True, "DataAnalysisIdlePageLongActionCompletion_LongActionProcessing");
	
	// Data analysis 
	// Automatic data mapping
	GoToTableNewRow(6, "DataAnalysisIdlePage", "NavigationPageWait",,,,, True, "DataAnalysis_LongActionProcessing");
	GoToTableNewRow(7, "DataAnalysisIdlePage", "NavigationPageWait",,,,, True, "DataAnalysisLongAction_LongActionProcessing");
	GoToTableNewRow(8, "DataAnalysisIdlePage", "NavigationPageWait",,,,, True, "DataAnalysisLongActionCompletion_LongActionProcessing");
	
	// Manual data mapping
	GoToTableNewRow(9, "StatisticsPage", "NavigationPageContinuation",, "StatisticsPage_OnOpen", "StatisticsPage_OnGoNext");
	
	// Data import
	GoToTableNewRow(10, "DataSynchronizationWaitPage", "NavigationPageWait",,,,, True, "DataImport_LongActionProcessing");
	GoToTableNewRow(11, "DataSynchronizationWaitPage", "NavigationPageWait",,,,, True, "DataImportLongAction_LongActionProcessing");
	GoToTableNewRow(12, "DataSynchronizationWaitPage", "NavigationPageWait",,,,, True, "DataImportLongActionCompletion_LongActionProcessing");
	
	// Data export setup
	DataExportResult = "";
	GoToTableNewRow(13, "QuestionAboutExportContentPage", "NavigationPageContinuation",, "QuestionAboutExportContentPage_OnOpen");
	
	// Data export
	GoToTableNewRow(14, "DataSynchronizationWaitPage", "NavigationPageWait",,,,, True, "DataExportIdlePage_LongActionProcessing");
	GoToTableNewRow(15, "DataSynchronizationWaitPage", "NavigationPageWait",,,,, True, "DataExportIdlePageLongAction_LongActionProcessing");
	GoToTableNewRow(16, "DataSynchronizationWaitPage", "NavigationPageWait",,,,, True, "DataExportIdlePageLongActionCompletion_LongActionProcessing");
	
	// Totals
	GoToTableNewRow(17, "MappingCompletePage", "NavigationPageEnd",, "MappingCompletePage_OnOpen");
	
EndProcedure

#EndRegion
