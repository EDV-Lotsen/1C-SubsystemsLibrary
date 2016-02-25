
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("Autotest") Then // Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
		Return;
	EndIf;

	If Not CommonUse.OnCreateAtServer(ThisObject, Cancel, StandardProcessing) Then
		Return;
	EndIf;
	
	ExchangePlanList = DataExchangeCached.SLExchangePlanList();
	If ExchangePlanList.Count() = 0 Then
		MessageText = NStr("en = 'Synchronization setup is not supported.'");
		CommonUseClientServer.MessageToUser(MessageText,,,, Cancel);
		Return;
	EndIf;
	
	IsInRoleAddEditDataExchanges = Users.RolesAvailable("DataSynchronizationSetup");
	If IsInRoleAddEditDataExchanges Then
		AddCreateNewExchangeCommands();
	Else
		Items.SetUpDataSynchronizationNotConfigured.Visible = False;
		Items.SynchronizationSetupGroup.Visible = False;
		Items.InfoLabel.CurrentPage = Items.HasNoRightsToSynchronize;
		Items.SynchronizationScenarioGroup.Visible = False;
		Items.SynchronizationSettingsGroup.Visible = False;
	EndIf;
	
	RefreshNodeStateList();
	
	If Not IsInRoleAddEditDataExchanges Or CommonUseCached.DataSeparationEnabled() Then
		
		Items.SynchronizationNotConfiguredPrefix.Visible = False;
		Items.SingleSynchronizationPrefix.Visible = False;
		Items.InfobasePrefix.Visible = False;
		
	Else
		
		InfobasePrefix = DataExchangeServer.InfobasePrefix();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	AttachIdleHandler("RefreshMonitorData", 60);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If    EventName = "DataExchangeCompleted"
		Or EventName = "Write_DataExchangeScenarios"
		Or EventName = "Write_ExchangePlanNode"
		Or EventName = "ObjectMappingWizardFormClosed"
		Or EventName = "DataExchangeCreationWizardFormClosed"
		Or EventName = "DataExchangeResultFormClosed" Then
		
		// Updating monitor data
		RefreshMonitorData();
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure SetUpDataSynchronization(Item)
	
	NotifyDescription = New NotifyDescription("SetUpDataSynchronizationCompletion", ThisObject);
	ShowChooseFromMenu(NotifyDescription, CustomizableSynchronizations, Item);
	
EndProcedure

&AtClient
Procedure SetUpDataSynchronizationCompletion(SelectedSynchronization, AdditionalParameters) Export
	
	If SelectedSynchronization <> Undefined Then
		
		DataExchangeClient.OpenDataExchangeSetupWizard(SelectedSynchronization.Value);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region NodeStateListFormTableItemEventHandlers

&AtClient
Procedure NodeStateListChoice(Item, SelectedRow, Field, StandardProcessing)
	
	NotifyDescription = New NotifyDescription("NodeStateListChoiceCompletion", ThisObject);
	ShowQueryBox(NotifyDescription, NStr("en = 'Do you want to synchronize data?'"), QuestionDialogMode.YesNo,, DialogReturnCode.Yes);
	
EndProcedure

&AtClient
Procedure NodeStateListChoiceCompletion(Answer, AdditionalParameters) Export
	
	If Answer = DialogReturnCode.Yes Then
		
		AutomaticSynchronization = (Items.NodeStateList.CurrentData.DataExchangeVariant = "Synchronization");
		
		Recipient = Items.NodeStateList.CurrentData.InfobaseNode;
		
		DataExchangeClient.ExecuteDataExchangeCommandProcessing(Recipient, ThisObject,, AutomaticSynchronization);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure NodeStateListOnActivateRow(Item)
	
	CurrentDataSet = Items.NodeStateList.CurrentData <> Undefined;
	
	Items.Settings.Enabled = CurrentDataSet;
	Items.NodeStateListChangeInfobaseNode.Enabled = CurrentDataSet;
	
	Items.DataExchangeExecutionButtonGroup.Enabled = CurrentDataSet;
	Items.ContextMenuStateListDiagnostics.Enabled  = CurrentDataSet;
	Items.ScheduleSettingsButtonGroup.Enabled      = CurrentDataSet;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ExecuteDataExchange(Command)
	
	RefreshMonitorData();
	
	CurrentData = ?(SynchronizationCount = 1, NodeStateList[0], Items.NodeStateList.CurrentData);
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	ExchangeNode = CurrentData.InfobaseNode;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ExchangeNode", ExchangeNode);
	AdditionalParameters.Insert("AutomaticSynchronization", (CurrentData.DataExchangeVariant = "Synchronization"));
	AdditionalParameters.Insert("InteractiveSending", False);
	
	ContinuationDetails = New NotifyDescription("ContinueSynchronizationExecution", ThisObject, AdditionalParameters);
	CheckConversionRuleCompatibility(ExchangeNode, ContinuationDetails);
	
EndProcedure

&AtClient
Procedure ExecuteDataExchangeInteractively(Command)
	
	CurrentData = ?(SynchronizationCount = 1, NodeStateList[0], Items.NodeStateList.CurrentData);
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	ExchangeNode = CurrentData.InfobaseNode;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ExchangeNode", ExchangeNode);
	AdditionalParameters.Insert("InteractiveSending", True);
	
	ContinuationDetails = New NotifyDescription("ContinueSynchronizationExecution", ThisObject, AdditionalParameters);
	
	CheckConversionRuleCompatibility(ExchangeNode, ContinuationDetails);
	
EndProcedure

&AtClient
Procedure SetUpDataExchangeScenarios(Command)
	
	CurrentData = Items.NodeStateList.CurrentData;
	
	DataExchangeClient.SetExchangeExecutionScheduleCommandProcessing(CurrentData.InfobaseNode, ThisObject);
	
EndProcedure

&AtClient
Procedure RefreshMonitor(Command)
	
	RefreshMonitorData();
	
EndProcedure

&AtClient
Procedure ChangeInfobaseNode(Command)
	
	If SynchronizationCount = 1 Then
		
		ExchangeNode = NodeStateList[0].InfobaseNode;
		
	Else
		
		CurrentData = Items.NodeStateList.CurrentData;
		ExchangeNode = CurrentData.InfobaseNode;
		
	EndIf;
	
	ShowValue(, ExchangeNode);
	
EndProcedure

&AtClient
Procedure GoToDataImportEventLog(Command)
	
	If SynchronizationCount = 1 Then
		
		ExchangeNode = NodeStateList[0].InfobaseNode;
		
	Else
		
		CurrentData  = Items.NodeStateList.CurrentData;
		ExchangeNode = CurrentData.InfobaseNode;
		
	EndIf;
	
	DataExchangeClient.GoToDataEventLogModally(ExchangeNode, ThisObject, "DataImport");
	
EndProcedure

&AtClient
Procedure GoToDataExportEventLog(Command)
	
	If SynchronizationCount = 1 Then
		
		ExchangeNode = NodeStateList[0].InfobaseNode;
		
	Else
		
		CurrentData  = Items.NodeStateList.CurrentData;
		ExchangeNode = CurrentData.InfobaseNode;
		
	EndIf;
	
	DataExchangeClient.GoToDataEventLogModally(ExchangeNode, ThisObject, "DataExport");
	
EndProcedure

&AtClient
Procedure OpenDataExchangeSetupWizard(Command)
	
	DataExchangeClient.OpenDataExchangeSetupWizard(Command.Name);
	
EndProcedure

&AtClient
Procedure InstallUpdate(Command)
	DataExchangeClient.ExecuteInfobaseUpdate();
EndProcedure

&AtClient
Procedure SetUpDataSynchronizationSingle(Command)
	
	SetUpDataSynchronization(Items.SetUpDataSynchronizationSingle);
	
EndProcedure

&AtClient
Procedure SetUpDataSynchronizationNotConfigured(Command)
	
	SetUpDataSynchronization(Items.SetUpDataSynchronizationNotConfigured);
	
EndProcedure

&AtClient
Procedure SetUpSynchronizationScenariosSingle(Command)
	
	ExchangeNode = NodeStateList[0].InfobaseNode;
	
	SynchronizationScenario = SynchronizationScenarioByNode(ExchangeNode);
	FormParameters = New Structure;
	
	If SynchronizationScenario = Undefined Then
		
		FormParameters.Insert("InfobaseNode", ExchangeNode);
		
	Else
		
		FormParameters.Insert("Key", SynchronizationScenario);
		
	EndIf;
	
	OpenForm("Catalog.DataExchangeScenarios.ObjectForm", FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure HideCompletedSynchronizations(Command)
	
	MustHideCompletedSynchronizations = Not MustHideCompletedSynchronizations;
	
	Items.NodeStateListMustHideCompletedSynchronizations.Check = MustHideCompletedSynchronizations;
	
	RefreshNodeStateList(True);
	
EndProcedure

&AtClient
Procedure ExchangeInfo(Command)
	
	If SynchronizationCount = 1 Then
		
		ExchangeNode = NodeStateList[0].InfobaseNode;
		
	Else
		
		CurrentData  = Items.NodeStateList.CurrentData;
		ExchangeNode = CurrentData.InfobaseNode;
		
	EndIf;
	
	LinkToDetails = DetailedInfoAtServer(ExchangeNode);
	
	DataExchangeClient.OpenDetailedSynchronizationDetails(LinkToDetails);
	
EndProcedure

&AtClient
Procedure OpenSingleSynchronizationResults(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("ExchangeNodes", UsedNodeArray(NodeStateList));
	OpenForm("InformationRegister.DataExchangeResults.Form.Form", FormParameters);
	
EndProcedure

&AtClient
Procedure SentDataContent(Command)
	
	If SynchronizationCount = 1 Then
		
		ExchangeNode = NodeStateList[0].InfobaseNode;
		
	Else
		
		CurrentData = Items.NodeStateList.CurrentData;
		
		If CurrentData = Undefined Then
			
			Return;
			
		EndIf;
		
		ExchangeNode = CurrentData.InfobaseNode;
		
	EndIf;
	
	DataExchangeClient.OpenSentDataContent(ExchangeNode);
	
EndProcedure

&AtClient
Procedure DeleteSynchronizationSettings(Command)
	
	If SynchronizationCount = 1 Then
		
		ExchangeNode = NodeStateList[0].InfobaseNode;
		
	Else
		
		CurrentData = Items.NodeStateList.CurrentData;
		
		If CurrentData = Undefined Then
			
			Return;
			
		EndIf;
		
		ExchangeNode = CurrentData.InfobaseNode;
		
	EndIf;
	
	DataExchangeClient.DeleteSynchronizationSettings(ExchangeNode);
	
EndProcedure


&AtClient
Procedure ImportDataSynchronizationRules(Command)
	
	CurrentData = ?(SynchronizationCount = 1, NodeStateList[0], Items.NodeStateList.CurrentData);
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	ExchangeNode = CurrentData.InfobaseNode;
	
	ExchangePlanName = FullExchangePlanName(ExchangeNode);
	DataExchangeClient.ImportDataSynchronizationRules(ExchangePlanName);
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Function FullExchangePlanName(Val InfobaseNode)
	
	Return DataExchangeCached.GetExchangePlanName(InfobaseNode);
	
EndFunction

&AtClient
Procedure RefreshMonitorData()
	
	NodeStateListRowIndex = GetCurrentRowIndex("NodeStateList");
	
	// Updating monitor tables on the server
	RefreshNodeStateList();
	
	// Specifying the cursor position
	MoveCursor("NodeStateList", NodeStateListRowIndex);
	
EndProcedure

&AtServer
Procedure RefreshNodeStateList(OnlyListUpdate = False)
	
	SLExchangePlans = DataExchangeCached.SLExchangePlans();
	
	// Updating data in the list of node states
	NodeStateList.Load(DataExchangeServer.DataExchangeMonitorTable(SLExchangePlans, "Code", MustHideCompletedSynchronizations));
	
	ConfiguredExchangeCount = DataExchangeServer.ConfiguredExchangeCount(SLExchangePlans);
	
	If Not OnlyListUpdate Then
		
		CheckStateOfExchangeWithMasterNode();
		
		If SynchronizationCount <> ConfiguredExchangeCount Then
			
			UpdateSynchronizationCount(ConfiguredExchangeCount);
			
		ElsIf SynchronizationCount = 1 Then
			
			SetSingleSynchronizationItems();
			
		EndIf;
		
		UpdateSynchronizationResultCommands();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdateSynchronizationCount(ConfiguredExchangeCount)
	
	SynchronizationCount = ConfiguredExchangeCount;
	SynchronizationPanel = Items.DataSynchronization;
	HasRightToUpdate = AccessRight("UpdateDataBaseConfiguration", Metadata);
	
	If SynchronizationCount = 0 Then
		
		SynchronizationPanel.CurrentPage = SynchronizationPanel.ChildItems.SynchronizationNotConfigured;
		Title = NStr("en = 'Data synchronization'");
		
	ElsIf SynchronizationCount = 1 Then
		
		Items.RightToUpdatePage.CurrentPage = ?(HasRightToUpdate, 
			Items.RightToUpdatePage.ChildItems.SynchronizationSuspendedHasRightToUpdateInfo1,
			Items.RightToUpdatePage.ChildItems.SynchronizationSuspendedHasNoRightToUpdateInfo1);
			
		SetSingleSynchronizationItems();
		
		SynchronizationPanel.CurrentPage = SynchronizationPanel.ChildItems.SingleSynchronization;
		
	Else
		
		SynchronizationPanel.CurrentPage = SynchronizationPanel.ChildItems.SeveralSynchronizations;
		
		Items.NodeStateListChangeInfobaseNode.Visible = IsInRoleAddEditDataExchanges;
		Items.SetExchangeExecutionSchedule.Visible    = IsInRoleAddEditDataExchanges;
		Items.SetExchangeExecutionSchedule1.Visible   = IsInRoleAddEditDataExchanges;
		
		Items.SynchronizationSuspendedHasRightToUpdateInfo.Visible   = HasRightToUpdate;
		Items.SynchronizationSuspendedHasNoRightToUpdateInfo.Visible = Not HasRightToUpdate;
		
		SynchronizationSuspendedLabel = ?(HasRightToUpdate,
		Items.SynchronizationSuspendedHasRightToUpdateLabel,
		Items.SynchronizationSuspendedHasNoRightToUpdateLabel);
		
		SynchronizationSuspendedLabel.Title = StringFunctionsClientServer.SubstituteParametersInString(SynchronizationSuspendedLabel.Title, DataExchangeServer.MasterNode());
		
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdateSynchronizationResultCommands()
	
	If SynchronizationCount <> 0 Then
		
		TitleStructure = DataExchangeServer.IssueMonitorHyperlinkTitleStructure(UsedNodeArray(NodeStateList));
		
		If SynchronizationCount = 1 Then
			
			FillPropertyValues(Items.OpenSingleSynchronizationResults, TitleStructure);
			
		ElsIf SynchronizationCount > 1 Then
			
			FillPropertyValues(Items.OpenDataSynchronizationResults, TitleStructure);
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Function UsedNodeArray(NodeStateList)
	
	ExchangeNodes = New Array;
	
	For Each NodeRow In NodeStateList Do
		ExchangeNodes.Add(NodeRow.InfobaseNode);
	EndDo;
	
	Return ExchangeNodes;
	
EndFunction

&AtServer
Procedure SetSingleSynchronizationItems()
	
	ConfiguredSynchronization = NodeStateList[0];
	
	If ConfiguredSynchronization.InfobaseNode = Undefined Then
		
		Raise NStr("en = 'Synchronization monitor cannot be used in a shared session.'");
		
	EndIf;
	
	Items.SchedulePage.Picture = ?(ConfiguredSynchronization.ScheduleConfigured,
		PictureLib.ScheduledJob, New Picture);
	
	FormTitle = NStr("en = 'Data synchronization with %Application%'");
		FormTitle = StrReplace(FormTitle, "%Application%", ConfiguredSynchronization.InfobaseNode.Description);
		Title = FormTitle;
		
	HasRightToViewEventLog = Users.RolesAvailable("ViewEventLog");
		
	If HasRightToViewEventLog Then
		
		Items.SuccessfulImportDate.Visible = True;
		Items.SuccessfulExportDate.Visible = True;
		Items.ReceiveDateLabel.Visible     = False;
		Items.SendDateLabel.Visible        = False;
		
		Items.SuccessfulImportDate.Title = ConfiguredSynchronization.LastSuccessfulImportDatePresentation;
		Items.SuccessfulExportDate.Title = ConfiguredSynchronization.LastSuccessfulExportDatePresentation;
		
	Else
		
		Items.SuccessfulImportDate.Visible = False;
		Items.SuccessfulExportDate.Visible = False;
		Items.ReceiveDateLabel.Visible     = True;
		Items.SendDateLabel.Visible        = True;
		
		Items.ReceiveDateLabel.Title = ConfiguredSynchronization.LastSuccessfulImportDatePresentation;
		Items.SendDateLabel.Title    = ConfiguredSynchronization.LastSuccessfulExportDatePresentation;
		
	EndIf;
	
	BlankDate = Date(1, 1, 1);
	
	If ConfiguredSynchronization.LastSuccessfulExportDate <> ConfiguredSynchronization.LastExportDate
		Or ConfiguredSynchronization.LastExportDate <> BlankDate
		Or ConfiguredSynchronization.LastDataExportResult <> 0 Then
		
		ExportTooltip = NStr("en = 'Data sent on: %SendDate%
										|Last attempt on: %AttemptDate%'");
		ExportTooltip = StrReplace(ExportTooltip, "%SendDate%",    ConfiguredSynchronization.LastSuccessfulExportDatePresentation);
		ExportTooltip = StrReplace(ExportTooltip, "%AttemptDate%", ConfiguredSynchronization.LastExportDatePresentation);
		
	Else
		
		ExportTooltip = "";
		
	EndIf;
	
	If ConfiguredSynchronization.LastSuccessfulImportDate <> ConfiguredSynchronization.LastImportDate
		Or ConfiguredSynchronization.LastImportDate <> BlankDate
		Or ConfiguredSynchronization.LastDataImportResult <> 0 Then
		
		ImportTooltip = NStr("en = 'Data received on: %ReceiveDate%
										|Last attempt on: %AttemptDate%'");
		ImportTooltip = StrReplace(ImportTooltip, "%ReceiveDate%", ConfiguredSynchronization.LastSuccessfulImportDatePresentation);
		ImportTooltip = StrReplace(ImportTooltip, "%AttemptDate%", ConfiguredSynchronization.LastImportDatePresentation);
		
	Else
		
		ImportTooltip = "";
		
	EndIf;
	
	If ConfiguredSynchronization.LastDataImportResult = 2 Then
		ConfiguredSynchronization.LastDataImportResult = ?(DataExchangeServer.DataExchangeCompletedWithWarnings(ConfiguredSynchronization.InfobaseNode), 2, 0);
	EndIf;
	
	StatusPicture(Items.ImportStatusDecoration, ConfiguredSynchronization.LastDataImportResult, ImportTooltip);
	StatusPicture(Items.ExportStatusDecoration, ConfiguredSynchronization.LastDataExportResult, ExportTooltip);
	
	Items.EmptyStatusDecoration.Visible = True;
	If ConfiguredSynchronization.LastDataImportResult <> 0
		Or (ConfiguredSynchronization.LastDataImportResult = 0
		And ConfiguredSynchronization.LastDataExportResult = 0) Then
		
		Items.EmptyStatusDecoration.Visible = False;
		
	EndIf;
	
	Items.SuccessfulExportDecoration.ToolTip = Items.ImportStatusDecoration.ToolTip;
	Items.SuccessfulImportDecoration.ToolTip = Items.ExportStatusDecoration.ToolTip;
	
	If DataExchangeCached.IsDistributedInfobaseNode(ConfiguredSynchronization.InfobaseNode) Then
		
		Items.ExecuteDataExchangeInteractively2.Visible = False;
		
	EndIf;
	
	DataSynchronizationRuleDetails = DataExchangeServer.DataSynchronizationRuleDetails(ConfiguredSynchronization.InfobaseNode);
	Items.DataSynchronizationRuleDetails.Height = StrLineCount(DataSynchronizationRuleDetails);
	
	InfobaseNodeSchedule = InfobaseNodeSchedule(ConfiguredSynchronization.InfobaseNode);
	
	If InfobaseNodeSchedule <> Undefined Then
		
		DataSynchronizationSchedule = InfobaseNodeSchedule;
		
	Else
		
		DataSynchronizationSchedule = NStr("en = 'Synchronization schedule is not configured.'");;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure AddCreateNewExchangeCommands()
	
	HasRightToAdministrateData = AccessRight("DataAdministration", Metadata);
	ExchangePlanList = DataExchangeCached.SLExchangePlanList();
	
	For Each Item In ExchangePlanList Do
		
		ExchangePlanName = Item.Value;
		
		ExchangePlanManager = ExchangePlans[ExchangePlanName];
		
		If ExchangePlanManager.UseDataExchangeCreationWizard() 
			And DataExchangeCached.CanUseExchangePlan(ExchangePlanName) Then
			
			CommandTitle = ExchangePlanManager.NewDataExchangeCreationCommandTitle();
			
			Commands.Add(ExchangePlanName);
			Commands[ExchangePlanName].Title  = CommandTitle + "...";
			Commands[ExchangePlanName].Action = "OpenDataExchangeSetupWizard";
			
			If Metadata.ExchangePlans[ExchangePlanName].DistributedInfobase Then
				
				If HasRightToAdministrateData Then
					
					Items.Add(ExchangePlanName, Type("FormButton"), Items.SubmenuDIB);
					Items[ExchangePlanName].CommandName = ExchangePlanName;
					
					CustomizableSynchronizations.Add(ExchangePlanName, Commands[ExchangePlanName].Title);
					
				EndIf;
				
			Else
				
				Items.Add(ExchangePlanName, Type("FormButton"), Items.SubmenuOther);
				Items[ExchangePlanName].CommandName = ExchangePlanName;
				
				CustomizableSynchronizations.Add(ExchangePlanName, Commands[ExchangePlanName].Title);
				
				If ExchangePlanManager.CorrespondentInSaaS() Then
					
					CommandName = "[ExchangePlanName]CorrespondentInSaaS";
					CommandName = StrReplace(CommandName, "[ExchangePlanName]", ExchangePlanName);
					
					Commands.Add(CommandName);
					Commands[CommandName].Title = CommandTitle + NStr("en = ' (SaaS)...'");
					Commands[CommandName].Action  = "OpenDataExchangeSetupWizard";
					
					Items.Add(CommandName, Type("FormButton"), Items.SubmenuOther);
					Items[CommandName].CommandName = CommandName;
					
					CustomizableSynchronizations.Add(CommandName, Commands[CommandName].Title);
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClient
Function GetCurrentRowIndex(TableName)
	
	// Return value
	LineIndex = Undefined;
	
	// Specifying the cursor position during the monitor update
	CurrentData = Items[TableName].CurrentData;
	
	If CurrentData <> Undefined Then
		
		LineIndex = ThisObject[TableName].IndexOf(CurrentData);
		
	EndIf;
	
	Return LineIndex;
EndFunction

&AtClient
Procedure MoveCursor(TableName, LineIndex)
	
	If LineIndex <> Undefined Then
		
		// Checking the cursor position once new data is received
		If ThisObject[TableName].Count() <> 0 Then
			
			If LineIndex > ThisObject[TableName].Count() - 1 Then
				
				LineIndex = ThisObject[TableName].Count() - 1;
				
			EndIf;
			
			// Specifying the cursor position
			Items[TableName].CurrentRow = ThisObject[TableName][LineIndex].GetID();
			
		EndIf;
		
	EndIf;
	
	// If setting the current row by TableName value failed, the first row is set as the current one
	If Items[TableName].CurrentRow = Undefined
		And ThisObject[TableName].Count() <> 0 Then
		
		Items[TableName].CurrentRow = ThisObject[TableName][0].GetID();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure CheckStateOfExchangeWithMasterNode()
	
	UpdateRequired = DataExchangeServerCall.InstallUpdateRequired();
	
	Items.UpdateRequiredInfoPanel1.Visible = UpdateRequired;
	Items.UpdateRequiredInfoPanel.Visible  = UpdateRequired;
	
	Items.ExecuteDataExchange2.Visible = Not UpdateRequired;
	
EndProcedure

&AtServer
Function SynchronizationScenarioByNode (InfobaseNode)
	
	ConfiguredScenario = Undefined;
	
	Query = New Query;
	Query.Text = "SELECT TOP 1
	|	DataExchangeScenarios.Ref
	|FROM
	|	Catalog.DataExchangeScenarios AS DataExchangeScenarios
	|WHERE
	|	DataExchangeScenarios.ExchangeSettings.InfobaseNode = &InfobaseNode
	|	AND DataExchangeScenarios.DeletionMark = FALSE";
	
	Query.SetParameter("InfobaseNode", InfobaseNode);
	
	Result = Query.Execute();
	
	If Not Result.IsEmpty() Then
		
		Selection = Result.Select();
		Selection.Next();
		
		ConfiguredScenario = Selection.Ref;
		
	EndIf;
	
	Return ConfiguredScenario;
	
EndFunction

&AtServer
Function InfobaseNodeSchedule(InfobaseNode)
	
	JobSchedule = Undefined;
	
	Query = New Query;
	Query.Text = "SELECT TOP 1
	|	DataExchangeScenarios.ScheduledJobGUID
	|FROM
	|	Catalog.DataExchangeScenarios AS DataExchangeScenarios
	|WHERE
	|	DataExchangeScenarios.UseScheduledJob = TRUE
	|	AND DataExchangeScenarios.ExchangeSettings.InfobaseNode = &InfobaseNode
	|	AND DataExchangeScenarios.DeletionMark = FALSE";
	
	Query.SetParameter("InfobaseNode", InfobaseNode);
	
	Result = Query.Execute();
	
	If Not Result.IsEmpty() Then
		
		Selection = Result.Select();
		
		Selection.Next();
		
		ScheduledJobObject = DataExchangeServerCall.FindScheduledJobByParameter(Selection.ScheduledJobGUID);
		If ScheduledJobObject <> Undefined Then
			JobSchedule = ScheduledJobObject.Schedule;
		EndIf;
		
	EndIf;
	
	Return JobSchedule;
	
EndFunction

&AtServer
Procedure StatusPicture(Control, EventKind, ToolTip)

	If EventKind = 1 Then
		Control.Picture = PictureLib.DataExchangeStateError;
		Control.Visible = True;
	ElsIf EventKind = 2 Then
		Control.Picture = PictureLib.Warning;
		Control.Visible = True;
	Else
		Control.Visible = False;
	EndIf;
	
	Control.ToolTip = ToolTip;
	
EndProcedure

&AtServer
Function DetailedInfoAtServer(ExchangeNode)
	
	ExchangePlanManager = ExchangePlans[ExchangeNode.Metadata().Name];
	LinkToDetails = ExchangePlanManager.ExchangeDetailedInformation();
	
	Return LinkToDetails;
	
EndFunction

&AtClient
Procedure ContinueSynchronizationExecution(Result, AdditionalParameters) Export
	
	If AdditionalParameters.InteractiveSending Then
		
		DataExchangeClient.OpenObjectMappingWizardCommandProcessing(AdditionalParameters.ExchangeNode, ThisObject);
		
	Else
		
		DataExchangeClient.ExecuteDataExchangeCommandProcessing(AdditionalParameters.ExchangeNode,
			ThisObject,, AdditionalParameters.AutomaticSynchronization);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CheckConversionRuleCompatibility(Val ExchangePlanName, ContinuationHandler)
	
	ErrorDescription = Undefined;
	If ConversionRulesCompatibleWithCurrentApplicationVersion(ExchangePlanName, ErrorDescription) Then
		
		ExecuteNotifyProcessing(ContinuationHandler);
		
	Else
		
		Buttons = New ValueList;
		Buttons.Add("GoToRuleImport", NStr("en = 'Import rules'"));
		If ErrorDescription.ErrorKind <> "IncorrectConfiguration" Then
			Buttons.Add("Continue", NStr("en = 'Continue'"));
		EndIf;
		Buttons.Add("Cancel", NStr("en = 'Cancel'"));
		
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("ContinuationHandler", ContinuationHandler);
		AdditionalParameters.Insert("ExchangePlanName", ExchangePlanName);
		Notification = New NotifyDescription("AfterConversionRulesCheckForCompatibility", ThisObject, AdditionalParameters);
		
		FormParameters = StandardSubsystemsClient.QuestionToUserParameters();
		FormParameters.Picture = ErrorDescription.Picture;
		FormParameters.SuggestDontAskAgain = False;
		If ErrorDescription.ErrorKind = "IncorrectConfiguration" Then
			FormParameters.Title = NStr("en = 'The synchronization cannot be completed.'");
		Else
			FormParameters.Title = NStr("en = 'The synchronization may be completed incorrectly.'");
		EndIf;
		
		StandardSubsystemsClient.ShowQuestionToUser(Notification, ErrorDescription.ErrorText, Buttons, FormParameters);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterConversionRulesCheckForCompatibility(Result, AdditionalParameters) Export
	
	If Result <> Undefined Then
		
		If Result.Value = "Continue" Then
			
			ExecuteNotifyProcessing(AdditionalParameters.ContinuationHandler);
			
		ElsIf Result.Value = "GoToRuleImport" Then
			
			DataExchangeClient.ImportDataSynchronizationRules(AdditionalParameters.ExchangePlanName);
			
		EndIf; // No action is required if the value is "Cancel"
		
	EndIf;
	
EndProcedure

&AtServer
Function ConversionRulesCompatibleWithCurrentApplicationVersion(ExchangePlanName, ErrorDescription)
	
	ExchangePlanName = DataExchangeCached.GetExchangePlanName(ExchangePlanName);
	RuleInfo = Undefined;
	
	If DataExchangeServer.ExchangePlanSettingValue(ExchangePlanName, "WarnAboutExchangeRuleVersionMismatch")
		And ConversionRulesImportedFromFile(ExchangePlanName, RuleInfo) Then
		
		If RuleInfo.ConfigurationName <> Metadata.Name Then
			
			ErrorDescription = New Structure;
			ErrorDescription.Insert("ErrorText", NStr("en = 'Synchronization cannot be completed because you are using the rules intended for %1 application. Use the rules from the configuration or import the appropriate rule set from a file.'"));
			ErrorDescription.ErrorText = StringFunctionsClientServer.SubstituteParametersInString(ErrorDescription.ErrorText,
				RuleInfo.ConfigurationSynonymInRules);
			ErrorDescription.Insert("ErrorKind", "IncorrectConfiguration");
			ErrorDescription.Insert("Picture", PictureLib.Error32);
			Return False;
			
		EndIf;
		
		VersionInRulesWithoutAssembly = CommonUseClientServer.ConfigurationVersionWithoutAssemblyNumber(RuleInfo.ConfigurationVersion);
		ConfigurationVersionWithoutAssembly = CommonUseClientServer.ConfigurationVersionWithoutAssemblyNumber(Metadata.Version);
		ComparisonResult = DataExchangeServer.CompareVersionsWithoutAssemblyNumbers(VersionInRulesWithoutAssembly, ConfigurationVersionWithoutAssembly);
		
		If ComparisonResult <> 0 Then
			
			If ComparisonResult < 0 Then
				
				ErrorText = NStr("en = 'Synchronization may be completed incorrectly because you are using rules that are intended for the previous version (%2) of %1 application. We recommend that you use rules from the configuration or import the rule set that is intended for the current application version (%3).'");
				ErrorKind = "ObsoleteConfigurationVersion";
				
			Else
				
				ErrorText = NStr("en = 'Synchronization may be completed incorrectly because you are using rules that are intended for the later version (%2) of the %1 application. We recommend that you update the application or use the rule set that is intended for the current application version (%3).'");
				ErrorKind = "ObsoleteRules";
				
			EndIf;
			
			ErrorText = StringFunctionsClientServer.SubstituteParametersInString(ErrorText, Metadata.Synonym,
					VersionInRulesWithoutAssembly, ConfigurationVersionWithoutAssembly);
			
			ErrorDescription = New Structure;
			ErrorDescription.Insert("ErrorText", ErrorText);
			ErrorDescription.Insert("ErrorKind", ErrorKind);
			ErrorDescription.Insert("Picture", PictureLib.Warning32);
			Return False;
			
		EndIf;
		
	EndIf;
	
	Return True;
	
EndFunction

&AtServer
Function ConversionRulesImportedFromFile(ExchangePlanName, RuleInfo)
	
	Query = New Query;
	Query.Text = "SELECT
	|	DataExchangeRules.ReadRulesAlready,
	|	DataExchangeRules.RuleKind
	|FROM
	|	InformationRegister.DataExchangeRules AS DataExchangeRules
	|WHERE
	|	DataExchangeRules.ExchangePlanName = &ExchangePlanName
	|	AND DataExchangeRules.RuleSource = VALUE(Enum.DataExchangeRuleSources.File)
	|	AND DataExchangeRules.RulesLoaded = TRUE
	|	AND DataExchangeRules.RuleKind = VALUE(Enum.DataExchangeRuleKinds.ObjectConversionRules)";
	
	Query.SetParameter("ExchangePlanName", ExchangePlanName);
	
	Result = Query.Execute();
	
	If Not Result.IsEmpty() Then
		
		Selection = Result.Select();
		Selection.Next();
		
		RuleStructure = Selection.ReadRulesAlready.Get().Conversion;
		
		RuleInfo = New Structure;
		RuleInfo.Insert("ConfigurationName", RuleStructure.Source);
		RuleInfo.Insert("ConfigurationVersion", RuleStructure.SourceConfigurationVersion);
		RuleInfo.Insert("ConfigurationSynonymInRules", RuleStructure.SourceConfigurationSynonym);
		
		Return True;
		
	EndIf;
	
	Return False;
	
EndFunction

#EndRegion
