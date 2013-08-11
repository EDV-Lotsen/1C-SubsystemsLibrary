&AtClient
Var ForceCloseForm;

////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
// There are two ways to parameterize the form:
//  - with the InfoBaseNode parameter. Pass the exchange plan node reference to this parameter.
//  - with the InfoBaseNodeCode and ExchangePlanName parameters. Pass the exchange plan
//    code to InfoBaseNodeCode and the exchange plan name whose manager is used for
//    searching the node to ExchangePlanName.

Procedure OnCreateAtServer(Cancel, StandardProcessing)
	Var InfoBaseNodeCode;
	
	// Skipping the initialization to guarantee that the form will be received if the SelfTest parameter is passed.
	If Parameters.Property("SelfTest") Then
		Return;
	EndIf;
	
	IsStartedFromAnotherApplication = False;
	
	If Parameters.Property("InfoBaseNode", Object.InfoBaseNode) Then
		
		Object.ExchangePlanName = DataExchangeCached.GetExchangePlanName(Object.InfoBaseNode);
		
	ElsIf Parameters.Property("InfoBaseNodeCode", InfoBaseNodeCode) Then
		
		IsStartedFromAnotherApplication = True;
		
		Object.InfoBaseNode = ExchangePlans[Parameters.ExchangePlanName].FindByCode(InfoBaseNodeCode);
		
		If Object.InfoBaseNode.IsEmpty() Then
			
			DataExchangeServer.ReportError(NStr("en = 'Data exchange settings are not found.'"), Cancel);
			Return;
			
		EndIf;
		
		Object.ExchangePlanName = Parameters.ExchangePlanName;
		
	Else
		
		DataExchangeServer.ReportError(NStr("en = 'The wizard cannot be opened directly.'"), Cancel);
		Return;
		
	EndIf;
	
	If Not DataExchangeCached.IsUniversalDataExchangeNode(Object.InfoBaseNode) Then
		
		// Only universal exchanges with conversion rules can be executed interactively
		DataExchangeServer.ReportError(
			NStr("en = 'Only universal exchanges with conversion rules can be executed interactively.'"), Cancel);
		Return;
		
	EndIf;
	
	NodeArray = DataExchangeCached.GetExchangePlanNodeArray(Object.ExchangePlanName);
	
	// Check whether exchange settings match the filter
	If NodeArray.Find(Object.InfoBaseNode) = Undefined Then
		
		CommonUseClientServer.MessageToUser(NStr("en = 'Selected node does not provide data mapping.'"),,,, Cancel);
		Return;
		
	EndIf;
	
	Parameters.Property("ExchangeMessageTransportKind", Object.ExchangeMessageTransportKind);
	
	// Specifying the exchange message transport kind if it was not passed
	If Not ValueIsFilled(Object.ExchangeMessageTransportKind) Then
		
		ExchangeTransportSettings = InformationRegisters.ExchangeTransportSettings.GetNodeTransportSettings(Object.InfoBaseNode);
		Object.ExchangeMessageTransportKind = ExchangeTransportSettings.DefaultExchangeMessageTransportKind;
		If Not ValueIsFilled(Object.ExchangeMessageTransportKind) Then
			Object.ExchangeMessageTransportKind = Enums.ExchangeMessageTransportKinds.FILE;
		EndIf;
		
	EndIf;
	
	DataExchangeServer.FillChoiceListWithAvailableTransportTypes(Object.InfoBaseNode, Items.ExchangeMessageTransportKind);
	Parameters.Property("ExecuteMappingOnOpen", ExecuteMappingOnOpen);
	WizardRunMode = "ExecuteMapping";
	RefreshTransportSettingsPages();
	DataImportEventLogMessage = DataExchangeServer.GetEventLogMessageKey(Object.InfoBaseNode, Enums.ActionsOnExchange.DataImport);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// Going to the first wizard step
	SetGoToNumber(1);
	
	ForceCloseForm = False;
	
	If ExecuteMappingOnOpen Then
		
		// Going to the statistic data import page if mapping must be executed when opening the wizard
		AttachIdleHandler("IdleHandlerNextCommand", 0.1, True);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	If ForceCloseForm = True Then
		Return;
	EndIf;
	
	NString = NStr("en = 'Do you want to close the interactive data exchange wizard?'");
	
	Response = DoQueryBox(NString, QuestionDialogMode.YesNo, ,DialogReturnCode.No);
	
	If Response = DialogReturnCode.No Then
		
		Cancel = True;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnClose()
	
	// Deleting the temporary directory
	DeleteTempExchangeMessageDirectory(Object.TempExchangeMessageDirectory);
	
	Notify("ObjectMappingWizardFormClosed");
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "ClosingObjectMappingForm" Then
		
		Cancel = False;
		
		Status(NStr("en = 'Gathering mapping data...'"));
		
		UpdateMappingStatisticsDataAtServer(Cancel, Parameter);
		
		If Cancel Then
			DoMessageBox(NStr("en = 'Error gathering statistic data.'"));
		Else
			
			ExpandStatisticsTree(Parameter.UniqueKey);
			
			Status(NStr("en = 'Data gathering completed.'"));
		EndIf;
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS

////////////////////////////////////////////////////////////////////////////////
// BeginningPage page

&AtClient
Procedure ExchangeMessageTransportKindOnChange(Item)
	
	ExchangeMessageTransportKindOnChangeAtServer();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM TABLE EVENT HANDLERS OF StatisticsTree TABLE 

&AtClient
Procedure StatisticsTreeChoice(Item, SelectedRow, Field, StandardProcessing)
	
	OpenMappingForm(Undefined);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure NextCommand(Command)
	
	ChangeGoToNumber(+1);
	
	If Items.MainPanel.CurrentPage = Items.DataExportIdlePage
		Or Items.MainPanel.CurrentPage = Items.DataImportIdlePage Then
		
		AttachIdleHandler("IdleHandlerNextCommand", 0.1, True);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure BackCommand(Command)
	
	ChangeGoToNumber(-1);
	
EndProcedure

&AtClient
Procedure CancelCommand(Command)
	
	Close();
	
EndProcedure

&AtClient
Procedure DoneCommand(Command)
	
	If Not NodeUsedInExchangeScenario
		And OpenDataExchangeScenarioCreationWizard Then
		
		FormParameters = New Structure("InfoBaseNode", Object.InfoBaseNode);
		
		OpenFormModal("Catalog.DataExchangeScenarios.ObjectForm", FormParameters, ThisForm);
		
	EndIf;
	
	// Update all opened dynamic lists
	DataExchangeClient.RefreshAllOpenDynamicLists();
	
	ForceCloseForm = True;
	Close();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// BeginningPage page

&AtClient
Procedure OpenDataExchangeDirectory(Command)
	
	// Calling the server without context
	DirectoryName = GetDirectoryNameAtServer(Object.ExchangeMessageTransportKind, Object.InfoBaseNode);
	
	If IsBlankString(DirectoryName) Then
		DoMessageBox(NStr("en = 'The data exchange directory is not specified.'"));
		Return;
	EndIf;
	
	// Opening the directory with Explorer
	RunApp(DirectoryName);
	
EndProcedure

&AtClient
Procedure SetupExchangeMessageTransportParameters(Command)
	
	Filter        = New Structure("Node", Object.InfoBaseNode);
	FillingValues = New Structure("Node", Object.InfoBaseNode);
	
	DataExchangeClient.OpenInformationRegisterRecordFormByFilter(Filter, FillingValues, "ExchangeTransportSettings", ThisForm);
	
	RefreshTransportSettingsPages();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// StatisticsPage page

&AtClient
Procedure UpdateMappingInfoForRow(Command)
	
	Cancel = False;
	
	SelectedRows = Items.StatisticsTree.SelectedRows;
	
	If SelectedRows.Count() = 0 Then
		
		NString = NStr("en = 'Select a table name in the statistic data field.'");
		CommonUseClientServer.MessageToUser(NString,,"Object.Statistics",, Cancel);
		Return;
	EndIf;
	
	RowKeys = GetSelectedRowKeys(SelectedRows);
	
	If RowKeys.Count() = 0 Then
		Return;
	EndIf;
	
	Status(NStr("en = 'Gathering mapping data...'"));
	
	UpdateMappingByRowDetailsAtServer(Cancel, RowKeys);
	
	If Cancel Then
		DoMessageBox(NStr("en = 'Error gathering statistic data.'"));
	Else
		
		ExpandStatisticsTree(RowKeys[RowKeys.UBound()]);
		
		Status(NStr("en = 'Data gathering completed.'"));
		
	EndIf;
	
EndProcedure

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
		DoMessageBox(NStr("en = 'Error gathering statistic data.'"));
	Else
		
		ExpandStatisticsTree(CurrentRowKey);
		
		Status(NStr("en = 'Data gathering completed.'"));
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteDefaultAutomaticMapping(Command)
	
	NString = NStr("en = 'Automatic mapping may take a long time. Do you want to continue?'");
	Response = DoQueryBox(NString, QuestionDialogMode.YesNo, ,DialogReturnCode.Yes);
	If Response = DialogReturnCode.No Then
		Return;
	EndIf;
	
	CurrentData = Items.StatisticsTree.CurrentData;
	
	If CurrentData <> Undefined Then
		
		CurrentRowKey = CurrentData.Key;
		
	EndIf;
	
	Cancel = False;
	
	RowKeys = New Array;
	
	GetAllRowKeys(RowKeys, StatisticsTree.GetItems());
	
	If RowKeys.Count() > 0 Then
		
		Status(NStr("en = 'Executing default automatic mapping...'"));
		
		ExecuteDefaultAutomaticMappingByRowAtServer(Cancel, RowKeys);
		
	EndIf;
	
	If Cancel Then
		
		DoMessageBox(NStr("en = 'Error executing automatic mapping.'"));
		
	Else
		
		ExpandStatisticsTree(CurrentRowKey);
		
		Status(NStr("en = 'Automatic mapping completed.'"));
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteAllTableDataImport(Command)
	
	NString = NStr("en = 'Do you want to import all data into the infobase?'");
	Response = DoQueryBox(NString, QuestionDialogMode.YesNo, ,DialogReturnCode.Yes);
	If Response = DialogReturnCode.No Then
		Return;
	EndIf;
	
	If Items.AdditionalInfoGroup.Visible Then
		
		NString = NStr("en = 'There are unmapped objects in the exchange plan.
					|Unmapped objects will be duplicated when importing data. Do you want to continue?'");
		
		Response = DoQueryBox(NString, QuestionDialogMode.YesNo, ,DialogReturnCode.No);
		If Response = DialogReturnCode.No Then
			Return;
		EndIf;
		
	EndIf;
	
	CurrentData = Items.StatisticsTree.CurrentData;
	
	If CurrentData <> Undefined Then
		
		CurrentRowKey = CurrentData.Key;
		
	EndIf;
	
	Cancel = False;
	
	RowKeys = New Array;
	
	GetAllRowKeys(RowKeys, StatisticsTree.GetItems());
	
	If RowKeys.Count() > 0 Then
		
		Status(NStr("en = 'Importing data...'"));
		
		ExecuteDataImportAtServer(Cancel, RowKeys);
		
	EndIf;
	
	If Cancel Then
		
		NString = NStr("en = 'Error importing data.
							|Do you want to open the event log?'");
		
		Response = DoQueryBox(NString, QuestionDialogMode.YesNo, ,DialogReturnCode.No);
		If Response = DialogReturnCode.Yes Then
			
			DataExchangeClient.GoToDataEventLogModally(Object.InfoBaseNode, ThisForm, "DataImport");
			
		EndIf;
		
	Else
		ExpandStatisticsTree(CurrentRowKey);
		
		Status(NStr("en = 'Data import has been completed.'"));
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteDataImportForRow(Command)
	
	Cancel = False;
	
	SelectedRows = Items.StatisticsTree.SelectedRows;
	
	If SelectedRows.Count() = 0 Then
		NString = NStr("en = 'Select a table name in the statistic data field.'");
		CommonUseClientServer.MessageToUser(NString,,"StatisticsTree",, Cancel);
		Return;
	EndIf;
	
	CheckIfMappedObjectsExist(Cancel, SelectedRows);
	
	If Cancel Then
		Return;
	EndIf;
	
	RowKeys = GetSelectedRowKeys(SelectedRows);
	
	If RowKeys.Count() = 0 Then
		Return;
	EndIf;
	
	Status(NStr("en = 'Importing data...'"));
	
	ExecuteDataImportAtServer(Cancel, RowKeys);
	
	If Cancel Then
		
		NString = NStr("en = 'Error importing data.
							|Do you want to open the event log?'");
		
		Response = DoQueryBox(NString, QuestionDialogMode.YesNo, ,DialogReturnCode.No);
		If Response = DialogReturnCode.Yes Then
			
			DataExchangeClient.GoToDataEventLogModally(Object.InfoBaseNode, ThisForm, "DataImport");
			
		EndIf;
		
	Else
		
		ExpandStatisticsTree(RowKeys[RowKeys.UBound()]);
		
		Status(NStr("en = 'Data import has been completed.'"));
		
	EndIf;
	
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
		DoMessageBox(NStr("en = 'Object mapping cannot be performed for the data type.'"));
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
	
	FormParameters.Insert("InfoBaseNode",              Object.InfoBaseNode);
	FormParameters.Insert("ExchangeMessageFileName",   Object.ExchangeMessageFileName);
	
	OpenForm("DataProcessor.InfoBaseObjectMapping.Form", FormParameters, ThisForm, CurrentData.Key);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// MappingCompletePage page

&AtClient
Procedure GoToDataImportEventLog(Command)
	
	DataExchangeClient.GoToDataEventLogModally(Object.InfoBaseNode, ThisForm, "DataImport");
	
EndProcedure

&AtClient
Procedure GoToDataExportEventLog(Command)
	
	DataExchangeClient.GoToDataEventLogModally(Object.InfoBaseNode, ThisForm, "DataExport");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

&AtServer
Procedure GetDataPackageTitleAtServer(Cancel, IsActualStatistics)
	
	DataProcessorObject = FormAttributeToValue("Object");
	
	DataProcessorObject.GetExchangeMessageToTemporaryDirectory(
	Cancel,
	DataPackageFileID,
	FileID,
	LongAction,
	ActionID
	);
	
	ValueToFormAttribute(DataProcessorObject, "Object");
	
	If LongAction Then
		
		// Getting correspondent web service connection settings.
		// This settings will be used for sampling the correspondent to find out whether the data export long action finished.
		SettingsStructure = InformationRegisters.ExchangeTransportSettings.GetWSTransportSettings(Object.InfoBaseNode);
		FillPropertyValues(ThisForm, SettingsStructure, "WSURL, WSUserName, WSPassword");
		Return;
	EndIf;
	
	If Not Cancel Then
		
		OnGetDataPackageTitleAtServer(Cancel, IsActualStatistics);
		
	EndIf;
	
	SetAdditionalInfoGroupVisible();
	
EndProcedure

&AtServer
Procedure GetDataPackageTitleAtServerLongActionEnd(Cancel, IsActualStatistics)
	
	DataProcessorObject = FormAttributeToValue("Object");
	
	DataProcessorObject.GetExchangeMessageToTempDirectoryLongActionEnd(
	Cancel,
	DataPackageFileID,
	FileID
	);
	
	ValueToFormAttribute(DataProcessorObject, "Object");
	
	If Not Cancel Then
		
		OnGetDataPackageTitleAtServer(Cancel, IsActualStatistics);
		
	EndIf;
	
	SetAdditionalInfoGroupVisible();
	
EndProcedure

&AtServer
Procedure OnGetDataPackageTitleAtServer(Cancel, IsActualStatistics)
	
	DataProcessorObject = FormAttributeToValue("Object");
	
	MappingStatisticsData = GetMappingStatisticsData();
	
	IsActualStatistics = (MappingStatisticsData.DataPackageFileID = DataPackageFileID);
	
	If Not IsActualStatistics Then
		
		// There is a new data package file. Importing data from the file.
		DataProcessorObject.ExecuteExchangeMessagAnalysis(Cancel);
		
		If Not Cancel Then
			
			WriteMappingStatisticsData(Object.ExchangePlanName, Object.InfoBaseNode, DataProcessorObject.StatisticsTable(), DataPackageFileID);
			
		EndIf;
		
	Else
		
		// The data package file has not been changed. Importing data from the cache.
		DataProcessorObject.Statistics.Load(MappingStatisticsData.ObjectMappingStatistics.Copy());
		
	EndIf;
	
	If Not Cancel Then
		
		GetStatisticsTree(DataProcessorObject.StatisticsTable());
		
		ValueToFormAttribute(DataProcessorObject, "Object");
		
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdateMappingByRowDetailsAtServer(Cancel, RowKeys)
	
	RowIndexes = GetStatisticsTableRowIndexes(RowKeys);
	
	DataProcessorObject = FormAttributeToValue("Object");
	
	// Getting mapping statistic data
	DataProcessorObject.GetObjectMappingByRowStats(Cancel, RowIndexes);
	
	ValueToFormAttribute(DataProcessorObject, "Object");
	
	// Writing mapping statistic data
	WriteMappingStatisticsData(Object.ExchangePlanName, Object.InfoBaseNode, DataProcessorObject.StatisticsTable(), DataPackageFileID);
	
	GetStatisticsTree(DataProcessorObject.StatisticsTable());
	
	SetAdditionalInfoGroupVisible();
	
EndProcedure

&AtServer
Procedure ExecuteDefaultAutomaticMappingByRowAtServer(Cancel, RowKeys)
	
	RowIndexes = GetStatisticsTableRowIndexes(RowKeys);
	
	DataProcessorObject = FormAttributeToValue("Object");
	
	// Performing automatic mapping and getting statistic data
	DataProcessorObject.ExecuteDefaultAutomaticMappingAndGetMappingStatistics(Cancel, RowIndexes);
	
	ValueToFormAttribute(DataProcessorObject, "Object");
	
	// Writing mapping statistic data
	WriteMappingStatisticsData(Object.ExchangePlanName, Object.InfoBaseNode, DataProcessorObject.StatisticsTable(), DataPackageFileID);
	
	GetStatisticsTree(DataProcessorObject.StatisticsTable());
	
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
	
	// Writing mapping statistic data
	WriteMappingStatisticsData(Object.ExchangePlanName, Object.InfoBaseNode, DataProcessorObject.StatisticsTable(), DataPackageFileID);
	
	GetStatisticsTree(DataProcessorObject.StatisticsTable());
	
	SetAdditionalInfoGroupVisible();
	
EndProcedure

&AtServer
Procedure UpdateMappingStatisticsDataAtServer(Cancel, NotificationParameters)
	
	TableRows = Object.Statistics.FindRows(New Structure("Key", NotificationParameters.UniqueKey));
	
	FillPropertyValues(TableRows[0], NotificationParameters, "DataImportedSuccessfully");
	
	RowKeys = New Array;
	RowKeys.Add(NotificationParameters.UniqueKey);
	
	UpdateMappingByRowDetailsAtServer(Cancel, RowKeys);
	
EndProcedure

&AtServer
Procedure GetStatisticsTree(Statistics)
	
	TreeItemCollection = StatisticsTree.GetItems();
	TreeItemCollection.Clear();
	
	CommonUse.FillFormDataTreeItemCollection(TreeItemCollection,
		DataExchangeServer.GetStatisticsTree(Statistics)
	);
	
EndProcedure

&AtServer
Procedure SetAdditionalInfoGroupVisible()
	
	// Making the group with additional information visible if statistic data table
	// contains one or more rows with mapping less than 100%.
	RowArray = Object.Statistics.FindRows(New Structure("PictureIndex", 1));
	
	Items.AdditionalInfoGroup.Visible = (RowArray.Count() > 0);
	
EndProcedure

&AtServer
Function GetMappingStatisticsData()
	Var MappingStatisticsData;
	
	FileName = MappingStatisticsDataFileName(Object.ExchangePlanName, Object.InfoBaseNode);
	
	File = New File(FileName);
	
	If File.Exist() Then
		
		MappingStatisticsData = ValueFromFile(FileName);
		
	EndIf;
	
	If TypeOf(MappingStatisticsData) <> Type("Structure") Then
		
		MappingStatisticsData = New Structure("DataPackageFileID, ObjectMappingStatistics");
		
	EndIf;
	
	Return MappingStatisticsData;
	
EndFunction

&AtServer
Function DataPackageFullyImported()
	
	SuccessfulImportTable = Object.Statistics.Unload(New Structure("DataImportedSuccessfully", True) ,"DataImportedSuccessfully");
	
	Return SuccessfulImportTable.Count() = Object.Statistics.Count();
	
EndFunction

&AtServer
Function AllObjectTablesMapped()
	
	Return (Object.Statistics.Unload(,"UnmappedObjectCount").Total("UnmappedObjectCount") = 0);
	
EndFunction

&AtServer
Procedure GetCheckStructureOnMappingComplete(CheckStructure)
	
	CheckStructure.DataPackageFullyImported = DataPackageFullyImported();
	CheckStructure.AllObjectTablesMapped    = AllObjectTablesMapped();
	
EndProcedure

&AtServer
Procedure ExchangeMessageTransportKindOnChangeAtServer()
	
	ExchangeOverExternalConnection = (Object.ExchangeMessageTransportKind = Enums.ExchangeMessageTransportKinds.COM);
	ExchangeOverWebService         = (Object.ExchangeMessageTransportKind = Enums.ExchangeMessageTransportKinds.WS);
	
	ExchangeOverConnectionToCorrespondent = ExchangeOverExternalConnection Or ExchangeOverWebService;
	
	ExternalConnectionParameterStructure = InformationRegisters.ExchangeTransportSettings.GetNodeTransportSettings(Object.InfoBaseNode);
	ExternalConnectionParameterStructure = DeletePrefixInCollectionKeys(ExternalConnectionParameterStructure, "COM");
	
	If IsStartedFromAnotherApplication Then
		
		Items.ScheduleSettingsInfoLabel.Visible = False;
		
		OpenDataExchangeScenarioCreationWizard = False;
		
	Else
		
		NodeUsedInExchangeScenario = InfobaseNodeUsedInExchangeScenario(Object.InfoBaseNode);
		
		Items.ScheduleSettingsInfoLabel.Visible = Not NodeUsedInExchangeScenario And Users.RolesAvailable("AddEditDataExchanges");
		
		OpenDataExchangeScenarioCreationWizard = Users.RolesAvailable("AddEditDataExchanges");
		
	EndIf;
	
	// Setting the current step change table
	If ExchangeOverConnectionToCorrespondent Then
		
		ExchangeScenarioOverExternalConnectionOrWebService();
		
	Else
		
		ExchangeScenarioOverOrdinaryCommunicationChannels();
		
	EndIf;
	
	SetExchangeDirectoryOpeningButtonVisible();
	
EndProcedure

// Deletes the specified literal (prefix) from key names of the passed structure.
// Creates a new structure with keys from the passed structure where literals were deleted.
//
//  Parameters:
//   Structure - Structure - source structure.
//   Literal   - String - characters to be deleted.
//
//  Returns:
//   Structure - new structure with keys from the passed structure where literals were deleted.
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
	
	For Each KeyStr In RowKeys Do
		
		TableRows = Object.Statistics.FindRows(New Structure("Key", KeyStr));
		
		RowIndex = Object.Statistics.IndexOf(TableRows[0]);
		
		RowIndexes.Add(RowIndex);
		
	EndDo;
	
	Return RowIndexes;
	
EndFunction

&AtServerNoContext
Procedure GetDataExchangeStates(DataImportResult, DataExportResult, Val InfoBaseNode)
	
	DataExchangeStates = InformationRegisters.DataExchangeStates.ExchangeNodeDataExchangeStates(InfoBaseNode);
	
	DataImportResult = DataExchangeStates["DataImportResult"];
	DataExportResult = DataExchangeStates["DataExportResult"];
	
EndProcedure

&AtServerNoContext
Function MappingStatisticsDataFileName(ExchangePlanName, InfoBaseNode)
	
	KeyStr = "MappingStatisticsData[ExchangePlanName][NodeCode]";
	
	KeyStr = StrReplace(KeyStr, "[ExchangePlanName]", ExchangePlanName);
	KeyStr = StrReplace(KeyStr, "[NodeCode]",        CommonUse.GetAttributeValue(InfoBaseNode, "Code"));
	
	Return CommonUseClientServer.GetFullFileName(TempFilesDir(), KeyStr);
	
EndFunction

&AtServerNoContext
Procedure WriteMappingStatisticsData(ExchangePlanName, InfoBaseNode, Val Statistics, DataPackageFileID)
	
	If TypeOf(Statistics) = Type("FormDataCollection") Then
		
		Statistics = Statistics.Unload();
		
	EndIf;
	
	MappingStatisticsData = New Structure;
	MappingStatisticsData.Insert("DataPackageFileID",          DataPackageFileID);
	MappingStatisticsData.Insert("ObjectMappingStatistics", Statistics);
	
	ValueToFile(MappingStatisticsDataFileName(ExchangePlanName, InfoBaseNode), MappingStatisticsData);
	
EndProcedure

&AtServerNoContext
Procedure DeleteTempExchangeMessageDirectory(TempDirectoryName)
	
	If Not IsBlankString(TempDirectoryName) Then
		
		Try
			DeleteFiles(TempDirectoryName);
			TempDirectoryName = "";
		Except
		EndTry;
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure WriteErrorToEventLog(ErrorMessageString, Event)
	
	WriteLogEvent(Event, EventLogLevel.Error,,, ErrorMessageString);
	
EndProcedure

&AtServerNoContext
Function GetDirectoryNameAtServer(ExchangeMessageTransportKind, InfoBaseNode)
	
	Return InformationRegisters.ExchangeTransportSettings.DataExchangeDirectoryName(ExchangeMessageTransportKind, InfoBaseNode);
	
EndFunction

&AtServerNoContext
Function InfobaseNodeUsedInExchangeScenario(InfoBaseNode)
	
	QueryText = "
	|SELECT TOP 1 1
	|FROM
	|	Catalog.DataExchangeScenarios.ExchangeSettings AS DataExchangeScenariosExchangeSettings
	|WHERE
	|		 DataExchangeScenariosExchangeSettings.InfoBaseNode = &InfoBaseNode
	|	AND NOT DataExchangeScenariosExchangeSettings.Ref.DeletionMark
	|";
	
	Query = New Query;
	Query.SetParameter("InfoBaseNode", InfoBaseNode);
	Query.Text = QueryText;
	
	Return Not Query.Execute().IsEmpty();
	
EndFunction

&AtServer
Procedure ExecuteDataExchangeForInfoBaseNodeAtServer(Cancel)
	
	ActionStartDate = CurrentSessionDate();
	
	DataExchangeServer.ExecuteDataExchangeForInfoBaseNode(
														Cancel,
														Object.InfoBaseNode,
														False,
														True,
														Object.ExchangeMessageTransportKind,
														LongAction,
														ActionID,
														FileID,
														True
	);
	
	If LongAction Then
		// Getting correspondent web service connection settings.
		// This settings will be used for sampling the correspondent to find out whether the
   // data export long action finished.
		SettingsStructure = InformationRegisters.ExchangeTransportSettings.GetWSTransportSettings(Object.InfoBaseNode);
		FillPropertyValues(ThisForm, SettingsStructure, "WSURL, WSUserName, WSPassword");
	EndIf;
	
EndProcedure

&AtServer
Procedure RefreshTransportSettingsPages()
	
	IsInRoleAddEditDataExchanges = Users.RolesAvailable("AddEditDataExchanges");
	
	Items.SetupExchangeMessageTransportParameters.Visible  = IsInRoleAddEditDataExchanges;
	Items.SetupExchangeMessageTransportParameters1.Visible = IsInRoleAddEditDataExchanges;
	
	ConfiguredTransportTypes = InformationRegisters.ExchangeTransportSettings.ConfiguredTransportTypes(Object.InfoBaseNode);
	
	DataExchangeServer.FillChoiceListWithAvailableTransportTypes(Object.InfoBaseNode, Items.ExchangeMessageTransportKind, ConfiguredTransportTypes);
	
	Object.ExchangeMessageTransportKind = Undefined;
	
	DefaultExchangeMessageTransportKind = InformationRegisters.ExchangeTransportSettings.DefaultExchangeMessageTransportKind(Object.InfoBaseNode);
	
	If Items.ExchangeMessageTransportKind.ChoiceList.FindByValue(DefaultExchangeMessageTransportKind) <> Undefined Then
		
		Object.ExchangeMessageTransportKind = DefaultExchangeMessageTransportKind;
		
	EndIf;
	
	If Not ValueIsFilled(Object.ExchangeMessageTransportKind)
		And Items.ExchangeMessageTransportKind.ChoiceList.Count() > 0 Then
		
		Object.ExchangeMessageTransportKind = Items.ExchangeMessageTransportKind.ChoiceList[0].Value;
		
	EndIf;
	
	Items.ExchangeMessageTransportKindString.Title = ?(Not ValueIsFilled(Object.ExchangeMessageTransportKind),
								NStr("en = '<Transport settings are not specified>'"),
								String(Object.ExchangeMessageTransportKind)
	);
	
	Items.TransportSettingsPages.CurrentPage = ?(
							Items.ExchangeMessageTransportKind.ChoiceList.Count() = 1,
							Items.OnlyOneTransportKindAvailablePage,
							Items.TransportTypeFromAvailableChoicePage
	);
	
	ExchangeMessageTransportKindOnChangeAtServer();
	
EndProcedure

&AtServer
Procedure SetExchangeDirectoryOpeningButtonVisible()
	
	ButtonVisibility = Object.ExchangeMessageTransportKind = Enums.ExchangeMessageTransportKinds.FILE
					Or Object.ExchangeMessageTransportKind = Enums.ExchangeMessageTransportKinds.FTP
	;
	
	Items.OpenDataExchangeDirectory.Visible = ButtonVisibility;
	Items.OpenDataExchangeDirectory1.Visible = ButtonVisibility;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Idle handlers.

&AtClient
Procedure IdleHandlerNextCommand()
	
	NextCommand(Undefined);
	
EndProcedure

&AtClient
Procedure DataImportIdleHandler()
	
	ErrorMessageString = "";
	
	ActionState = DataExchangeServer.LongActionState(
													ActionID,
													WSURL,
													WSUserName,
													WSPassword,
													ErrorMessageString
	);
	
	If ActionState = "Active" Then
		
		AttachIdleHandler("DataImportIdleHandler", 5, True);
		
	ElsIf ActionState = "Completed" Then
		
		LongAction = False;
		
		Cancel = False;
		IsActualStatistics = True;
		
		GetDataPackageTitleAtServerLongActionEnd(Cancel, IsActualStatistics);
		
		If Cancel Then
			
			// Setting a new script if error occurred during data import
			If ExchangeOverConnectionToCorrespondent Then
				
				ExchangeScenarioOverExternalConnectionOrWebServiceOnImportError();
				
			Else
				
				ExchangeScenarioOverOrdinaryCommunicationChannelsOnImportError();
				
			EndIf;
			
			NextCommand(Undefined);
			
		ElsIf Not IsActualStatistics Then
			
			// Updating if data is obsolete (there is a new data package file)
			UpdateMappingInfoFully(Undefined);
			
			NextCommand(Undefined);
			
		Else
			
			ExpandStatisticsTree(StatisticsTableCurrentRowKey);
			
			NextCommand(Undefined);
			
		EndIf;
		
	Else 
		
		LongAction = False;
		
		WriteErrorToEventLog(ErrorMessageString, DataImportEventLogMessage);
		
		// Setting a new script if error occurred during data import
		If ExchangeOverConnectionToCorrespondent Then
			
			ExchangeScenarioOverExternalConnectionOrWebServiceOnImportError();
			
		Else
			
			ExchangeScenarioOverOrdinaryCommunicationChannelsOnImportError();
			
		EndIf;
		
		NextCommand(Undefined);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure DataExportIdleHandler()
	
	ErrorMessageString = "";
	
	ActionState = DataExchangeServer.LongActionState(
													ActionID,
													WSURL,
													WSUserName,
													WSPassword,
													ErrorMessageString
	);
	
	If ActionState = "Active" Then
		
		AttachIdleHandler("DataExportIdleHandler", 5, True);
		
	ElsIf ActionState = "Completed" Then
		
		LongAction = False;
		
		DataExchangeServer.CommitDataExportExecutionInLongActionMode(Object.InfoBaseNode, ActionStartDate);
		
		NextCommand(Undefined);
		
	Else 
		
		LongAction = False;
		
		DataExchangeServer.AddExchangeFinishedWithErrorEventLogMessage(
											Object.InfoBaseNode,
											"DataExport",
											ActionStartDate,
											ErrorMessageString
		);
		
		NextCommand(Undefined);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteLongActionHandler()
	
	GoToRowsCurrent = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber));
	
	If GoToRowsCurrent.Count() = 0 Then
		Raise NStr("en = 'The page to be displayed is not specified.'");
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
Procedure CheckIfMappedObjectsExist(Cancel, SelectedRows)
	
	For Each RowID In SelectedRows Do
		
		TreeRow = StatisticsTree.FindByID(RowID);
		
		If IsBlankString(TreeRow.Key) Then
			Continue;
		EndIf;
		
		If TreeRow.UnmappedObjectCount <> 0 Then
			
			NString = NStr("en = 'There are unmapped objects in the exchange plan.
					|Unmapped objects will be duplicated when importing data. Do you want to continue?'");
			
			Response = DoQueryBox(NString, QuestionDialogMode.YesNo, ,DialogReturnCode.No);
			If Response = DialogReturnCode.No Then
				Cancel = True;
			EndIf;
			
			Break;
			
		EndIf;
		
	EndDo;
	
EndProcedure

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
Procedure RefreshDataExchangeStateItemPresentation()
	
	Items.DataImportStatusPages.CurrentPage = Items[DataExchangeClient.DataImportStatusPages()[DataImportResult]];
	Items.DataExportStatePages.CurrentPage = Items[DataExchangeClient.DataExportStatePages()[DataExportResult]];
	
	Items.GoToDataImportEventLog.Title = DataExchangeClient.DataImportHyperlinkHeaders()[DataImportResult];
	Items.GoToDataExportEventLog.Title = DataExchangeClient.DataExportHyperlinkHeaders()[DataExportResult];
	
EndProcedure

&AtClient
Procedure ExpandStatisticsTree(RowKey = "")
	
	ItemCollection = StatisticsTree.GetItems();
	
	For Each TreeRow In ItemCollection Do
		
		Items.StatisticsTree.Expand(TreeRow.GetID(), True);
		
	EndDo;
	
	// Determining the value tree cursor position
	If Not IsBlankString(RowKey) Then
		
		RowID = 0;
		
		CommonUseClientServer.GetTreeRowIDByFieldValue("Key", RowID, StatisticsTree.GetItems(), RowKey, False);
		
		Items.StatisticsTree.CurrentRow = RowID;
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

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
	
	// Executing the step change event handlers
	ExecuteGoToEventHandlers(IsGoNext);
	
	// Setting page visibility
	GoToRowsCurrent = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber));
	
	If GoToRowsCurrent.Count() = 0 Then
		Raise NStr("en = 'The page to be displayed is not specified.'");
	EndIf;
	
	GoToRowCurrent = GoToRowsCurrent[0];
	
	Items.MainPanel.CurrentPage  = Items[GoToRowCurrent.MainPageName];
	Items.NavigationPanel.CurrentPage = Items[GoToRowCurrent.NavigationPageName];
	
	// Setting the default button
	ButtonNext = GetFormButtonByCommandName(Items.NavigationPanel.CurrentPage, "NextCommand");
	
	If ButtonNext <> Undefined Then
		
		ButtonNext.DefaultButton = True;
		
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
	
	// Step change event handlers
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
		Raise NStr("en = 'The page to be displayed is not specified.'");
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
									GoBackHandlerName = ""
									)
	
	NewRow = GoToTable.Add();
	
	NewRow.GoToNumber = GoToNumber;
	NewRow.MainPageName     = MainPageName;
	NewRow.DecorationPageName    = DecorationPageName;
	NewRow.NavigationPageName    = NavigationPageName;
	
	NewRow.GoNextHandlerName = GoNextHandlerName;
	NewRow.GoBackHandlerName = GoBackHandlerName;
	NewRow.OnOpenHandlerName      = OnOpenHandlerName;
	
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
// Overridable part. Step change event handlers.

&AtClient
Function Attachable_BeginningPage_OnGoNext(Cancel)
	
	// Checking whether form attributes are filled
	If Object.InfoBaseNode.IsEmpty() Then
		
		NString = NStr("en = 'Specify the infobase node.'");
		CommonUseClientServer.MessageToUser(NString,, "Object.InfoBaseNode",, Cancel);
		Return Undefined;
		
	ElsIf Object.ExchangeMessageTransportKind.IsEmpty() Then
		
		NString = NStr("en = 'Specify the exchange message transport kind.'");
		CommonUseClientServer.MessageToUser(NString,, "Object.ExchangeMessageTransportKind",, Cancel);
		Return Undefined;
		
	EndIf;
	
	Return Undefined;
EndFunction

&AtClient
Function Attachable_StatisticsPage_OnGoNext(Cancel)
	
	// Executing various checks
	CheckStructure = New Structure("DataPackageFullyImported, AllObjectTablesMapped", False, False);
	
	GetCheckStructureOnMappingComplete(CheckStructure);
	
	If Not CheckStructure.DataPackageFullyImported Then
		
		NString = NStr("en = 'There are unmapped objects. Do you want to continue anyway?'");
		Response = DoQueryBox(NString, QuestionDialogMode.YesNo, ,DialogReturnCode.No);
		If Response = DialogReturnCode.No Then
			Cancel = True;
			Return Undefined;
		EndIf;
		
	EndIf;
	
	If Not CheckStructure.AllObjectTablesMapped Then
		
		NString = NStr("en = 'There are unmapped objects. Do you want to continue anyway?'");
		Response = DoQueryBox(NString, QuestionDialogMode.YesNo, ,DialogReturnCode.No);
		If Response = DialogReturnCode.No Then
			Cancel = True;
			Return Undefined;
		EndIf;
		
	EndIf;
	
	
	Return Undefined;
EndFunction

&AtClient
Function Attachable_DataImportIdlePage_OnGoNext(Cancel)
	
	CurrentData = Items.StatisticsTree.CurrentData;
	
	If CurrentData <> Undefined Then
		
		CurrentRowKey = CurrentData.Key;
		StatisticsTableCurrentRowKey = CurrentData.Key;
		
	EndIf;
	
	IsActualStatistics = True;
	
	FileID = "";
	LongAction = False;
	ActionID = "";
	
	GetDataPackageTitleAtServer(Cancel, IsActualStatistics);
	
	If LongAction Then
		Return Undefined;
	EndIf;
	
	If Cancel Then
		
		Cancel = False;
		
		// Setting a new script if error occurred during data import
		If ExchangeOverConnectionToCorrespondent Then
			
			ExchangeScenarioOverExternalConnectionOrWebServiceOnImportError();
			
		Else
			
			ExchangeScenarioOverOrdinaryCommunicationChannelsOnImportError();
			
		EndIf;
		
	ElsIf Not IsActualStatistics Then
		
		// Updating if data is obsolete (there is a new data package file)
		UpdateMappingInfoFully(Undefined);
		
	Else
		
		ExpandStatisticsTree(CurrentRowKey);
		
	EndIf;
	
	Return Undefined;
EndFunction

&AtClient
Function Attachable_DataImportIdlePage_OnOpen(Cancel, SkipPage, Val IsGoNext)
	
	If Not IsGoNext Then
		
		SkipPage = True;
		
	EndIf;
	
	Return Undefined;
EndFunction

&AtClient
Function Attachable_DataImportIdlePageLongAction_OnOpen(Cancel, SkipPage, Val IsGoNext)
	
	If Not IsGoNext Then
		
		SkipPage = True;
		Return Undefined;
		
	ElsIf Not LongAction Then
		
		SkipPage = True;
		Return Undefined;
		
	EndIf;
	
	If LongAction Then
		
		AttachIdleHandler("DataImportIdleHandler", 5, True);
		
	EndIf;
	
	Return Undefined;
EndFunction

&AtClient
Function Attachable_DataExportIdlePageLongAction_OnOpen(Cancel, SkipPage, Val IsGoNext)
	
	If Not IsGoNext Then
		
		SkipPage = True;
		Return Undefined;
		
	ElsIf Not LongAction Then
		
		SkipPage = True;
		Return Undefined;
		
	EndIf;
	
	If LongAction Then
		
		AttachIdleHandler("DataExportIdleHandler", 5, True);
		
	EndIf;
	
	Return Undefined;
EndFunction

&AtClient
Function Attachable_DataExportIdlePage_OnGoNext(Cancel)
	
	LongAction = False;
	ActionID = "";
	FileID = "";
	
	ExecuteDataExchangeForInfoBaseNodeAtServer(Cancel);
	
	If LongAction Then
		Return Undefined;
	EndIf;
	
	Cancel = False; // It is allowed to go to the next page
	
	Return Undefined;
EndFunction

&AtClient
Function Attachable_DataExportIdlePage_OnOpen(Cancel, SkipPage, Val IsGoNext)
	
	If Not IsGoNext Then
		
		SkipPage = True;
		
	EndIf;
	
	Return Undefined;
EndFunction

&AtClient
Function Attachable_MappingCompletePage_OnOpen(Cancel, SkipPage, Val IsGoNext)
	
	GetDataExchangeStates(DataImportResult, DataExportResult, Object.InfoBaseNode);
	
	RefreshDataExchangeStateItemPresentation();
	
	Return Undefined;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Overridable part. Wizard step change initialization.

&AtServer
Procedure ExchangeScenarioOverOrdinaryCommunicationChannels()
	
	GoToTable.Clear();
	
	GoToTableNewRow(1, "BeginningPage", "NavigationPageStart",,, "BeginningPage_OnGoNext");
	GoToTableNewRow(2, "DataImportIdlePage", "NavigationPageWait",, "DataImportIdlePage_OnOpen", "DataImportIdlePage_OnGoNext");
	GoToTableNewRow(3, "StatisticsPage", "NavigationPageContinuation",,, "StatisticsPage_OnGoNext");
	GoToTableNewRow(4, "DataExportIdlePage", "NavigationPageWait",, "DataExportIdlePage_OnOpen", "DataExportIdlePage_OnGoNext");
	GoToTableNewRow(5, "MappingCompletePage", "NavigationPageEnd",, "MappingCompletePage_OnOpen");
	
EndProcedure

&AtServer
Procedure ExchangeScenarioOverOrdinaryCommunicationChannelsOnImportError()
	
	GoToTable.Clear();
	
	GoToTableNewRow(1, "BeginningPage", "NavigationPageStart",,, "BeginningPage_OnGoNext");
	GoToTableNewRow(2, "DataImportIdlePage", "NavigationPageWait",, "DataImportIdlePage_OnOpen", "DataImportIdlePage_OnGoNext");
	GoToTableNewRow(3, "DataExportIdlePage", "NavigationPageWait",, "DataExportIdlePage_OnOpen", "DataExportIdlePage_OnGoNext");
	GoToTableNewRow(4, "MappingCompletePage", "NavigationPageEnd",, "MappingCompletePage_OnOpen");
	
EndProcedure

&AtServer
Procedure ExchangeScenarioOverExternalConnectionOrWebService()
	
	GoToTable.Clear();
	
	GoToTableNewRow(1, "BeginningPage",                                   "NavigationPageStart",,, "BeginningPage_OnGoNext");
	GoToTableNewRow(2, "DataImportIdlePage",                   "NavigationPageWait",, "DataImportIdlePage_OnOpen", "DataImportIdlePage_OnGoNext");
	GoToTableNewRow(3, "DataImportIdlePageLongAction", "NavigationPageWait",, "DataImportIdlePageLongAction_OnOpen");
	GoToTableNewRow(4, "StatisticsPage",                     "NavigationPageContinuation",,, "StatisticsPage_OnGoNext");
	GoToTableNewRow(5, "DataExportIdlePage",                   "NavigationPageWait",, "DataExportIdlePage_OnOpen", "DataExportIdlePage_OnGoNext");
	GoToTableNewRow(6, "DataExportIdlePageLongAction", "NavigationPageWait",, "DataExportIdlePageLongAction_OnOpen");
	GoToTableNewRow(7, "MappingCompletePage",                   "NavigationPageEnd",, "MappingCompletePage_OnOpen");
	
EndProcedure

&AtServer
Procedure ExchangeScenarioOverExternalConnectionOrWebServiceOnImportError()
	
	GoToTable.Clear();
	
	GoToTableNewRow(1, "BeginningPage",                                   "NavigationPageStart",,, "BeginningPage_OnGoNext");
	GoToTableNewRow(2, "DataImportIdlePage",                   "NavigationPageWait",, "DataImportIdlePage_OnOpen", "DataImportIdlePage_OnGoNext");
	GoToTableNewRow(3, "DataImportIdlePageLongAction", "NavigationPageWait",, "DataImportIdlePageLongAction_OnOpen");
	GoToTableNewRow(4, "DataExportIdlePage",                   "NavigationPageWait",, "DataExportIdlePage_OnOpen", "DataExportIdlePage_OnGoNext");
	GoToTableNewRow(5, "DataExportIdlePageLongAction", "NavigationPageWait",, "DataExportIdlePageLongAction_OnOpen");
	GoToTableNewRow(6, "MappingCompletePage",                   "NavigationPageEnd",, "MappingCompletePage_OnOpen");
	
EndProcedure
