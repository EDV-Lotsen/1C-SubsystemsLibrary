#Region FormEventHandlers

// Overridable part.

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
  // Skipping the initialization to guarantee that the form will be 
  // received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then
		Return;
	EndIf;
	
	If IsBlankString(Parameters.ExchangePlanName) Then
		Raise NStr("en='The data processor cannot be opened manually'");
	EndIf;
	
  // Only users with administrative rights can enable data synchronization 
  // for subscribers
	DataExchangeServer.CheckExchangeManagementRights();
	
	SetPrivilegedMode(True);
	
	If Not DataExchangeSaaSCached.DataSynchronizationSupported() Then
		
		Raise NStr("en = 'The configuration does not support data synchronization.'");
		
	EndIf;
	
	ExchangePlanName         = Parameters.ExchangePlanName;
	CorrespondentDataArea    = Parameters.CorrespondentDataArea;
	CorrespondentDescription = Parameters.CorrespondentDescription;
	CorrespondentEndpoint    = Parameters.CorrespondentEndpoint;
	Prefix                   = Parameters.Prefix;
	CorrespondentPrefix      = Parameters.CorrespondentPrefix;
	CorrespondentVersion     = Parameters.CorrespondentVersion;
	
	ThisApplicationDescription = DataExchangeSaaS.GeneratePredefinedNodeDescription();
	
	// Getting a correspondent node code (creating a node if it does not exist)
	CorrespondentCode = DataExchangeSaaS.ExchangePlanNodeCodeInService(CorrespondentDataArea);
	
	Correspondent = Undefined;
	
	// Getting exchange plan manager by name
	ExchangePlanManager = ExchangePlans[ExchangePlanName];
	
	LinkToDetails = ExchangePlanManager.ExchangeDetailedInformation();
	
  // Getting default values for the exchange plan
	NodesSetupForm = "";
	DefaultValueSetupForm = "";
	CorrespondentInfobaseDefaultValueSetupForm = "";
	
	NodeFilterStructure = DataExchangeServer.NodeFilterStructure(ExchangePlanName, CorrespondentVersion);
	NodeDefaultValues = DataExchangeServer.NodeDefaultValues(ExchangePlanName, CorrespondentVersion, DefaultValueSetupForm);
	CorrespondentInfobaseNodeDefaultValues = DataExchangeServer.CorrespondentInfobaseNodeDefaultValues(ExchangePlanName, CorrespondentVersion, CorrespondentInfobaseDefaultValueSetupForm);
	DataExchangeServer.CommonNodeData(ExchangePlanName, CorrespondentVersion, NodesSetupForm);
	
	NodeFilterSettingsAvailable = NodeFilterStructure.Count() > 0;
	NodeDefaultValuesAvailable = NodeDefaultValues.Count() > 0;
	CorrespondentInfobaseNodeDefaultValuesAvailable = CorrespondentInfobaseNodeDefaultValues.Count() > 0;
	
	Items.DefaultValueDetailsGroup.Visible = NodeDefaultValuesAvailable;
	Items.DefaultCorrespondentValueDetailsGroup.Visible = CorrespondentInfobaseNodeDefaultValuesAvailable;
	Items.DataExportSetupDetailsGroup.Visible = NodeFilterSettingsAvailable;
	
	DefaultValueDetails = DefaultValueDetails(ExchangePlanName, NodeDefaultValues, CorrespondentVersion);
	DefaultCorrespondentValueDetails = DefaultCorrespondentValueDetails(ExchangePlanName, CorrespondentInfobaseNodeDefaultValues, CorrespondentVersion);
	
	AccountingParametersCommentLabel = ExchangePlanManager.AccountingSettingsSetupComment();
	CorrespondentAccountingParametersCommentLabel = DataExchangeServer.CorrespondentInfobaseAccountingSettingsSetupComment(ExchangePlanName, CorrespondentVersion);
	
	CorrespondentTables = DataExchangeServer.CorrespondentTablesForDefaultValues(ExchangePlanName, CorrespondentVersion);
	
	// Setting wizard title
	Title = StringFunctionsClientServer.SubstituteParametersInString(NStr("en = 'Setup of data synchronization with %1'"), CorrespondentDescription);
	Items.DataSynchronizationDetails.Title = StringFunctionsClientServer.SubstituteParametersInString(NStr("en = 'Details of data synchronization with %1'"), CorrespondentDescription);
	
	EventLogMessageTextDataSynchronizationSetup = DataExchangeSaaS.EventLogMessageTextDataSynchronizationSetup();
	
	NodesSetupFormContext = New Structure;
	
	GetMappingStatistics = False;
	StatisticsEmpty      = False;
	
	// Filling the navigation table
	DataSynchronizationSetupScenario();
	
	Modified = True;
	
	SetBackupDetailsText();
	StandardSubsystemsServer.SetGroupTitleRepresentation(ThisObject);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	UserAnsweredYesToQuestionAboutMapping = False;
	
	// Getting context details from the node settings form
	If NodeFilterSettingsAvailable Then
		
		FormParameters = New Structure;
		FormParameters.Insert("CorrespondentVersion", CorrespondentVersion);
		FormParameters.Insert("GetDefaultValue");
		FormParameters.Insert("Settings", NodesSetupFormContext);
		
		SettingsFormName = "ExchangePlan.[ExchangePlanName].Form.[NodesSetupForm]";
		SettingsFormName = StrReplace(SettingsFormName, "[ExchangePlanName]", ExchangePlanName);
		SettingsFormName = StrReplace(SettingsFormName, "[NodesSetupForm]", NodesSetupForm);
		
		SettingsForm = GetForm(SettingsFormName, FormParameters, ThisObject);
		
		NodesSetupFormContext         = SettingsForm.Context;
		DataExportSettingsDescription = SettingsForm.ContextDetails;
		
	EndIf;
	
	// Selecting the first wizard step
	GoToNumber = 0;
	SetGoToNumber(1);
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	WarningText = NStr("en = 'Do you want to cancel data synchronization setup?'");
	If Items.MainPanel.CurrentPage <> Items.Beginning Then
		NotifyDescription = New NotifyDescription("SynchronizationSetupCancellation", ThisObject);
	Else
		NotifyDescription = Undefined;
	EndIf;
	CommonUseClient.ShowArbitraryFormClosingConfirmation(
		ThisObject, Cancel, WarningText, "ForceCloseForm", NotifyDescription);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "CorrespondentDataReceived" Then
		
		CorrespondentDataStorageAddress = Parameter;
		
		OpenDefaultCorrespondentValueSetupForm(Parameter);
		
	ElsIf EventName = "CorrespondentNodeCommonDataReceived" Then
		
		OpenDataExportSetupForm(Parameter);
		
	ElsIf EventName = "ClosingObjectMappingForm" Then
		
		Statistics_Key                      = Parameter.UniquenessKey;
		Statistics_DataImportedSuccessfully = Parameter.DataImportedSuccessfully;
		
		GetMappingStatistics = True;
		
		GoToNumber = 0;
		SetGoToNumber( PageNumber_MappingStatisticsGetting() );
		
	EndIf;
	
EndProcedure

// Idle handlers

&AtClient
Procedure LongActionIdleHandler()
	
	Try
		SessionStatus = SessionStatus(Session);
	Except
		WriteErrorToEventLog(
			DetailErrorDescription(ErrorInfo()), EventLogMessageTextDataSynchronizationSetup);
		GoBack();
		ShowMessageBox(, NStr("en = 'Cannot execute the operation.'"));
		Return;
	EndTry;
	
	If SessionStatus = "Done" Then
		
		GoToNext();
		
	ElsIf SessionStatus = "Error" Then
		
		GoBack();
		
		ShowMessageBox(, NStr("en = 'Cannot execute the operation.'"));
		
	Else
		
		AttachIdleHandler("LongActionIdleHandler", 5, True);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure BackgroundJobIdleHandler()
	
	Try
		
		If JobCompleted(JobID) Then
			
			GoToNext();
			
		Else
			AttachIdleHandler("BackgroundJobIdleHandler", 5, True);
		EndIf;
		
	Except
		WriteErrorToEventLog(
			DetailErrorDescription(ErrorInfo()), EventLogMessageTextDataSynchronizationSetup);
		GoBack();
		ShowMessageBox(, NStr("en = 'Cannot execute the operation.'"));
	EndTry;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

// Supplied part.

&AtClient
Procedure NextCommand(Command)
	
	GoToNext();
	
EndProcedure

&AtClient
Procedure BackCommand(Command)
	
	GoBack();
	
EndProcedure

&AtClient
Procedure DoneCommand(Command)
	
	ForceCloseForm = True;
	
	Close();
	
EndProcedure

&AtClient
Procedure CancelCommand(Command)
	
	Close();
	
EndProcedure

&AtClient
Procedure DataSynchronizationDetails(Command)
	
	DataExchangeClient.OpenDetailedSynchronizationDetails(LinkToDetails);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Overridable part.

&AtClient
Procedure SetupDataExport(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("ExchangePlanName", ExchangePlanName);
	FormParameters.Insert("CorrespondentDataArea", CorrespondentDataArea);
	FormParameters.Insert("Mode", "GetCorrespondentNodeCommonData");
	FormParameters.Insert("OwnerUUID", ThisObject.UUID);
	
	OpenForm("DataProcessor.DataSynchronizationBetweenWebApplicationsSetupWizard.Form.CorrespondentDataGetting",
		FormParameters, ThisObject,,,,,FormWindowOpeningMode.LockOwnerWindow);
EndProcedure

&AtClient
Procedure SetUpDefaultCorrespondentValue(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("ExchangePlanName", ExchangePlanName);
	FormParameters.Insert("CorrespondentDataArea", CorrespondentDataArea);
	FormParameters.Insert("Mode", "GetCorrespondentData");
	FormParameters.Insert("OwnerUUID", ThisObject.UUID);
	FormParameters.Insert("CorrespondentTables", CorrespondentTables);
	
	OpenForm("DataProcessor.DataSynchronizationBetweenWebApplicationsSetupWizard.Form.CorrespondentDataGetting",
		FormParameters, ThisObject,,,,,FormWindowOpeningMode.LockOwnerWindow);
EndProcedure

&AtClient
Procedure SetUpDefaultValue(Command)
	
	NodeSettingsFormName = "ExchangePlan.[ExchangePlanName].Form.[DefaultValueSetupForm]";
	NodeSettingsFormName = StrReplace(NodeSettingsFormName, "[ExchangePlanName]", ExchangePlanName);
	NodeSettingsFormName = StrReplace(NodeSettingsFormName, "[DefaultValueSetupForm]", DefaultValueSetupForm);
	
	FormParameters = New Structure;
	FormParameters.Insert("CorrespondentVersion", CorrespondentVersion);
	FormParameters.Insert("NodeDefaultValues", NodeDefaultValues);
	
	Handler = New NotifyDescription("SetUpDefaultValueCompletion", ThisObject);
	Mode = FormWindowOpeningMode.LockOwnerWindow;
	OpenForm(NodeSettingsFormName, FormParameters, ThisObject,,,,Handler, Mode);
	
EndProcedure

&AtClient
Procedure SetUpDefaultValueCompletion(OpeningResult, AdditionalParameters) Export
	
	If OpeningResult <> Undefined Then
		
		For Each SettingsItem In NodeDefaultValues Do
			
			NodeDefaultValues[SettingsItem.Key] = OpeningResult[SettingsItem.Key];
			
		EndDo;
		
		DefaultValueDetails = DefaultValueDetails(ExchangePlanName, NodeDefaultValues, CorrespondentVersion);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure MapData(Command)
	
	OpenMappingForm();
	
EndProcedure

&AtClient
Procedure StatisticsSelection(Item, SelectedRow, Field, StandardProcessing)
	
	OpenMappingForm();
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

// Supplied part.

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
		
		If GoToRows.Count() > 0 Then
			
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
			
		EndIf;
		
	Else
		
		GoToRows = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber + 1));
		
		If GoToRows.Count() > 0 Then
			
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
		
		Cancel   = False;
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

// The procedure adds a row to the end of the current navigation table.
//
// Parameters:
//
//  GoToNumber (mandatory)         - Number - current step number. 
//  MainPageName (mandatory)       - String - name of the "MainPanel" panel page that matches the current step number. 
//  NavigationPageName (mandatory) - String - name of the "NavigationPanel" panel page that matches 
//                                   the current step number. 
//  DecorationPageName (optional)  - String - name of the "DecorationPanel" panel page that matches 
//                                   the current step number. 
//  OnOpenHandlerName (optional)   - String - name of the "open current wizard page" event handler. 
//  GoNextHandlerName (optional)   - String - name of the "go to next wizard page" event handler. 
//  GoBackHandlerName (optional)   - String - name of the "go to previous wizard page" event handler. 
//  LongAction (optional)          - Boolean - flag that shows whether a long action execution page is displayed.
//                                   If True, a long action execution page is displayed.
//                                   If False, a standard page is displayed. 
//                                   The default value is False. 
// 
&AtServer
Function GoToTableNewRow(GoToNumber,
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
	
	Return NewRow;
EndFunction

&AtClient
Function GetFormButtonByCommandName(FormItem, CommandName)
	
	For Each Item In FormItem.ChildItems Do
		
		If TypeOf(Item) = Type("FormGroup") Then
			
			FormItemByCommandName = GetFormButtonByCommandName(Item, CommandName);
			
			If FormItemByCommandName <> Undefined Then
				
				Return FormItemByCommandName;
				
			EndIf;
			
		ElsIf TypeOf(Item) = Type("FormButton")
			And Find(Item.CommandName, CommandName) > 0 Then
			
			Return Item;
			
		Else
			
			Continue;
			
		EndIf;
		
	EndDo;
	
	Return Undefined;
	
EndFunction

&AtClient
Procedure SynchronizationSetupCancellation(Result, AdditionalParameters) Export
	
	DeleteSynchronizationSettingsAtServer();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Overridable part: Internal procedures and functions.

&AtClient
Procedure GoToNext()
	
	ChangeGoToNumber(+1);
	
EndProcedure

&AtClient
Procedure GoBack()
	
	UserAnsweredYesToQuestionAboutMapping = False;
	ChangeGoToNumber(-1);
	
EndProcedure

&AtServerNoContext
Function SessionStatus(Val Session)
	
	SetPrivilegedMode(True);
	
	Return InformationRegisters.SystemMessageExchangeSessions.SessionStatus(Session);
	
EndFunction

&AtServerNoContext
Procedure WriteErrorToEventLog(ErrorMessageString, Event)
	
	WriteLogEvent(Event, EventLogLevel.Error,,, ErrorMessageString);
	
EndProcedure

&AtServerNoContext
Function JobCompleted(Val JobID)
	
	Return LongActions.JobCompleted(JobID);
	
EndFunction

&AtClient
Procedure OpenDataExportSetupForm(Val CorrespondentDataTemporaryStorageAddress)
	
	NodeSettingsFormName = "ExchangePlan.[ExchangePlanName].Form.[NodesSetupForm]";
	NodeSettingsFormName = StrReplace(NodeSettingsFormName, "[ExchangePlanName]", ExchangePlanName);
	NodeSettingsFormName = StrReplace(NodeSettingsFormName, "[NodesSetupForm]", NodesSetupForm);
	
	ConnectionParameters = New Structure;
	ConnectionParameters.Insert("JoinType", "TempStorage");
	ConnectionParameters.Insert("TempStorageAddress", CorrespondentDataTemporaryStorageAddress);
	
	FormParameters = New Structure;
	FormParameters.Insert("CorrespondentVersion", CorrespondentVersion);
	FormParameters.Insert("ConnectionParameters", ConnectionParameters);
	FormParameters.Insert("Settings", NodesSetupFormContext);
	
	Handler = New NotifyDescription("OpenDataExportSetupFormCompletion", ThisObject);
	Mode    = FormWindowOpeningMode.LockOwnerWindow;
	OpenForm(NodeSettingsFormName, FormParameters, ThisObject,,,,Handler, Mode);
	
EndProcedure

&AtClient
Procedure OpenDataExportSetupFormCompletion(OpeningResult, AdditionalParameters) Export
	
	If OpeningResult <> Undefined Then
		
		NodesSetupFormContext = OpeningResult;
		
		DataExportSettingsDescription = OpeningResult.ContextDetails;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenDefaultCorrespondentValueSetupForm(Val CorrespondentDataTemporaryStorageAddress)
	
	NodeSettingsFormName = "ExchangePlan.[ExchangePlanName].Form.[CorrespondentInfobaseDefaultValueSetupForm]";
	NodeSettingsFormName = StrReplace(NodeSettingsFormName, "[ExchangePlanName]", ExchangePlanName);
	NodeSettingsFormName = StrReplace(NodeSettingsFormName, "[CorrespondentInfobaseDefaultValueSetupForm]", CorrespondentInfobaseDefaultValueSetupForm);
	
	ConnectionParameters = New Structure;
	ConnectionParameters.Insert("JoinType", "TempStorage");
	ConnectionParameters.Insert("TempStorageAddress", CorrespondentDataTemporaryStorageAddress);
	
	FormParameters = New Structure;
	FormParameters.Insert("CorrespondentVersion", CorrespondentVersion);
	FormParameters.Insert("ExternalConnectionParameters", ConnectionParameters);
	FormParameters.Insert("NodeDefaultValues", CorrespondentInfobaseNodeDefaultValues);
	
	Handler = New NotifyDescription("OpenDefaultCorrespondentValueSetupFormCompletion", ThisObject);
	Mode = FormWindowOpeningMode.LockOwnerWindow;
	OpenForm(NodeSettingsFormName, FormParameters, ThisObject,,,,Handler, Mode);
	
EndProcedure

&AtClient
Procedure OpenDefaultCorrespondentValueSetupFormCompletion(OpeningResult, AdditionalParameters) Export
	
	If OpeningResult <> Undefined Then
		
		For Each SettingsItem In CorrespondentInfobaseNodeDefaultValues Do
			
			CorrespondentInfobaseNodeDefaultValues[SettingsItem.Key] = OpeningResult[SettingsItem.Key];
			
		EndDo;
		
		DefaultCorrespondentValueDetails = DefaultCorrespondentValueDetails(ExchangePlanName, CorrespondentInfobaseNodeDefaultValues, CorrespondentVersion);
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function DefaultValueDetails(Val ExchangePlanName, Val Settings, Val CorrespondentVersion)
	
	Return DataExchangeServer.DefaultValueDetails(ExchangePlanName, Settings, CorrespondentVersion);
	
EndFunction

&AtServerNoContext
Function DefaultCorrespondentValueDetails(Val ExchangePlanName, Val Settings, Val CorrespondentVersion)
	
	Return DataExchangeServer.CorrespondentInfobaseDefaultValueDetails(ExchangePlanName, Settings, CorrespondentVersion);
	
EndFunction

&AtServer
Procedure ReportError(Cancel)
	
	CommonUseClientServer.MessageToUser(NStr("en = 'Cannot execute the operation.'"),,,, Cancel);
	
EndProcedure

&AtServer
Procedure DeleteSynchronizationSettingsAtServer()
	
	DataExchangeSaaS.DeleteExchangeSettings(ExchangePlanName, CorrespondentDataArea);
	
EndProcedure

&AtClient
Procedure OpenMappingForm()
	
	CurrentData = Items.Statistics.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If IsBlankString(CurrentData.Key) Then
		Return;
	EndIf;
	
	If Not CurrentData.UsePreview Then
		ShowMessageBox(, NStr("en = 'Cannot create mapping for the selected data.'"));
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
	
	FormParameters.Insert("InfobaseNode",              Correspondent);
	FormParameters.Insert("ExchangeMessageFileName",   ExchangeMessageFileName);
	
	FormParameters.Insert("PerformDataImport",         False);
	
	OpenForm("DataProcessor.InfobaseObjectMapping.Form", FormParameters, ThisObject, , , , ,
		FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtServer
Function TableRowID(Val FieldName, Val _Key, FormDataCollection)
	
	CollectionItems = FormDataCollection.FindRows(New Structure(FieldName, _Key));
	
	If CollectionItems.Count() > 0 Then
		
		Return CollectionItems[0].GetID();
		
	EndIf;
	
	Return Undefined;
EndFunction

&AtServer
Function GetStatisticsTableRowIndexes(RowKeys)
	
	RowIndexes = New Array;
	
	For Each _Key In RowKeys Do
		
		TableRows = Object.Statistics.FindRows(New Structure("Key", _Key));
		
		LineIndex = Object.Statistics.IndexOf(TableRows[0]);
		
		RowIndexes.Add(LineIndex);
		
	EndDo;
	
	Return RowIndexes;
	
EndFunction

&AtClient
Procedure BackupLabelURLProcessing(Item, URL, StandardProcessing)
	StandardProcessing = False;
	
	If URL = "SaaS" Then
		DataAreaBackupClientModule = CommonUseClient.CommonModule("DataAreaBackupClient");
		DataAreaBackupClientModule.OpenBackupForm(ThisObject);
		
	ElsIf URL = "SaaSInstructionOnly" Then
		GotoURL(BackupInstructionAddress);
		
	ElsIf URL = "Backup" Then
		InfobaseBackupClientModule = CommonUseClient.CommonModule("InfobaseBackupClient");
		InfobaseBackupClientModule.OpenBackupForm(ThisObject);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SetBackupDetailsText()
	Option = DataExchangeServer.BackupOption();
	
	If IsBlankString(Option) Then
		Return;
		
	ElsIf Option = "SaaSInstructionOnly" Then
		BackupInstructionAddress = DataExchangeSaaS.BackupInstructionAddress();
		If IsBlankString(BackupInstructionAddress) Then 
			Return;
		EndIf;
		
	EndIf;
	
	Text = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = 'It is recommended that you create an <a href=%1>infobase backup</a> before synchronization setup.'"),
		Option);
		
	DocFormat = New FormattedDocument;
	DocFormat.SetHTML(Text, New Structure);
	Items.BackupLabel.Title = DocFormat.GetFormattedString();
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Overridable part: Step change handlers.

// Page 1 (Beginning):
// Checking whether a settings structure is filled.
//
&AtClient
Function Attachable_Start_OnGoNext(Cancel)
	
	// Checking whether form attributes are filled
	If NodeFilterSettingsAvailable Then
		
		FormParameters = New Structure;
		FormParameters.Insert("CorrespondentVersion", CorrespondentVersion);
		FormParameters.Insert("Settings", NodesSetupFormContext);
		FormParameters.Insert("FillChecking");
		
		SettingsFormName = "ExchangePlan.[ExchangePlanName].Form.[NodesSetupForm]";
		SettingsFormName = StrReplace(SettingsFormName, "[ExchangePlanName]", ExchangePlanName);
		SettingsFormName = StrReplace(SettingsFormName, "[NodesSetupForm]", NodesSetupForm);
		
		SettingsForm = GetForm(SettingsFormName, FormParameters, ThisObject);
		
		If Not SettingsForm.CheckFilling() Then
			
			CommonUseClientServer.MessageToUser(NStr("en = 'Specify the mandatory settings.'"),,, "DataExportSettingsDescription", Cancel);
			
		EndIf;
		
	EndIf;
	
EndFunction

// Page 2 (waiting):
// Creating exchange settings in the current infobase.
// Registering catalogs to be exported in the current infobase.
// Sending message to a correspondent:
//   Creating exchange settings in a correspondent infobase. 
//   Registering catalogs to be exported in a correspondent infobase.
//   Starting data export in a correspondent infobase.
//   Sending an export status message (success or error) to the current infobase.
// After the correspondent response is received:
//   Mapping data received from a correspondent.
//   Getting mapping statistics. 
//
&AtClient
Function Attachable_DataAnalysisWait_LongActionProcessing(Cancel, GoToNext)
	
	DataAnalysisWait_LongActionProcessing(Cancel);
	
EndFunction

// Page 2 (waiting):
// Creating exchange settings in the current infobase. 
// Registering catalogs to be exported in the current infobase. 
// Sending message to a correspondent.
&AtServer
Procedure DataAnalysisWait_LongActionProcessing(Cancel)
	
	Try
		MethodParameters = New Structure;
		MethodParameters.Insert("ExchangePlanName",         ExchangePlanName);
		MethodParameters.Insert("CorrespondentCode",        CorrespondentCode);
		MethodParameters.Insert("CorrespondentDescription", CorrespondentDescription);
		MethodParameters.Insert("CorrespondentDataArea",    CorrespondentDataArea);
		MethodParameters.Insert("CorrespondentEndpoint",    CorrespondentEndpoint);
		MethodParameters.Insert("NodeFilterStructure",      NodesSetupFormContext);
		MethodParameters.Insert("Prefix",                   Prefix);
		MethodParameters.Insert("CorrespondentPrefix",      CorrespondentPrefix);
		
		Result = LongActions.ExecuteInBackground(
			UUID,
			"DataProcessors.DataSynchronizationBetweenWebApplicationsSetupWizard.SetUpExchangeStep1",
			MethodParameters,
			NStr("en = 'Setup of data synchronization between two online applications (step 1)'"));
		
		JobID = Result.JobID;
		TempStorageAddress = Result.StorageAddress;
	Except
		WriteErrorToEventLog(DetailErrorDescription(ErrorInfo()),
			EventLogMessageTextDataSynchronizationSetup);
		ReportError(Cancel);
		Return;
	EndTry;
	
EndProcedure

// Page 2 (waiting): Waiting until a background job is completed.
//
&AtClient
Function Attachable_DataAnalysisWaitBackgroundJob_LongActionProcessing(Cancel, GoToNext)
	
	GoToNext = False;
	
	AttachIdleHandler("BackgroundJobIdleHandler", 5, True);
	
EndFunction

// Page 2 (waiting): Waiting for a correspondent response.
//
&AtClient
Function Attachable_DataAnalysisWaitLongAction_LongActionProcessing(Cancel, GoToNext)
	
	IncomingParameters = GetFromTempStorage(TempStorageAddress);
	Correspondent      = IncomingParameters.Correspondent;
	Session            = IncomingParameters.Session;
	
	GoToNext = False;
	
	AttachIdleHandler("LongActionIdleHandler", 5, True);
	
EndFunction

// Page 2 (waiting):
// After receiving correspondent answer:
//   Mapping data received from a correspondent.
//   Getting mapping statistics.
//
&AtClient
Function Attachable_DataAnalysisWaitLongActionCompletion_LongActionProcessing(Cancel, GoToNext)
	
	ExecuteAutomaticDataMapping(Cancel);
	
EndFunction

// Page 2 (waiting):
//   Mapping data received from a correspondent.
//   Getting mapping statistics.
//
&AtServer
Procedure ExecuteAutomaticDataMapping(Cancel)
	
	Try
		MethodParameters = New Structure;
		MethodParameters.Insert("Correspondent", Correspondent);
		
		Result = LongActions.ExecuteInBackground(
			UUID,
			"DataProcessors.DataSynchronizationBetweenWebApplicationsSetupWizard.ExecuteAutomaticDataMapping",
			MethodParameters,
			NStr("en = 'Setup of data synchronization between two online applications (automatic data mapping)'"));
		
		JobID = Result.JobID;
		TempStorageAddress = Result.StorageAddress;
	Except
		WriteErrorToEventLog(DetailErrorDescription(ErrorInfo()),
			EventLogMessageTextDataSynchronizationSetup);
		ReportError(Cancel);
		Return;
	EndTry;
	
EndProcedure

// Page 2 (waiting): Waiting until a background job is completed.
//
&AtClient
Function Attachable_DataMappingWaitBackgroundJob_LongActionProcessing(Cancel, GoToNext)
	
	GoToNext = False;
	
	AttachIdleHandler("BackgroundJobIdleHandler", 5, True);
	
EndFunction

// Page 2 (waiting).
//
&AtClient
Function Attachable_DataMappingWaitBackgroundJobCompletion_LongActionProcessing(Cancel, GoToNext)
	
	ImportMappingStatistics_21(Cancel);
	
EndFunction

// Page 2 (waiting).
//
&AtServer
Procedure ImportMappingStatistics_21(Cancel)
	
	Try
		
		IncomingParameters = GetFromTempStorage(TempStorageAddress);
		
		AllDataMapped = IncomingParameters.AllDataMapped;
		ExchangeMessageFileName = IncomingParameters.ExchangeMessageFileName;
		StatisticsEmpty = IncomingParameters.StatisticsEmpty;
		
		Object.Statistics.Load(IncomingParameters.Statistics);
		Object.Statistics.Sort("Presentation");
		
	Except
		WriteErrorToEventLog(DetailErrorDescription(ErrorInfo()),
			EventLogMessageTextDataSynchronizationSetup);
		ReportError(Cancel);
		Return;
	EndTry;
	
EndProcedure

//

// Page 2 (waiting): Getting mapping statistics (this operation is optional).
//
&AtClient
Function Attachable_MappingStatisticsGettingWait_LongActionProcessing(Cancel, GoToNext)
	
	If GetMappingStatistics Then
		
		GetMappingStatistics(Cancel);
		
	EndIf;
	
EndFunction

// Page 2 (waiting): Getting mapping statistics (this operation is optional).
//
&AtClient
Function Attachable_MappingStatisticsGettingWaitBackgroundJob_LongActionProcessing(Cancel, GoToNext)
	
	If GetMappingStatistics Then
		
		GoToNext = False;
		
		AttachIdleHandler("BackgroundJobIdleHandler", 5, True);
		
	EndIf;
	
EndFunction

// Page 2 (waiting): Getting mapping statistics (this operation is optional).
//
&AtClient
Function Attachable_MappingStatisticsGettingWaitBackgroundJobCompletion_LongActionProcessing(Cancel, GoToNext)
	
	If GetMappingStatistics Then
		
		ImportMappingStatistics_22(Cancel);
		
	EndIf;
	
EndFunction

// Page 2 (waiting): Getting mapping statistics (this operation is optional).
//
&AtServer
Procedure GetMappingStatistics(Cancel)
	
	Try
		
		TableRows = Object.Statistics.FindRows(New Structure("Key", Statistics_Key));
		TableRows[0].DataImportedSuccessfully = Statistics_DataImportedSuccessfully;
		
		RowKeys = New Array;
		RowKeys.Add(Statistics_Key);
		
		MethodParameters = New Structure;
		MethodParameters.Insert("Correspondent", Correspondent);
		MethodParameters.Insert("ExchangeMessageFileName", ExchangeMessageFileName);
		MethodParameters.Insert("Statistics", Object.Statistics.Unload());
		MethodParameters.Insert("RowIndexes", GetStatisticsTableRowIndexes(RowKeys));
		
		Result = LongActions.ExecuteInBackground(
			UUID,
			"DataProcessors.DataSynchronizationBetweenWebApplicationsSetupWizard.GetMappingStatistics",
			MethodParameters,
			NStr("en = 'Setup of data synchronization between two online applications (getting mapping statistics)'"));
		
		JobID = Result.JobID;
		TempStorageAddress = Result.StorageAddress;
	Except
		WriteErrorToEventLog(DetailErrorDescription(ErrorInfo()),
			EventLogMessageTextDataSynchronizationSetup);
		ReportError(Cancel);
		Return;
	EndTry;
	
EndProcedure

// Page 2 (waiting): Getting mapping statistics (this operation is optional).
//
&AtServer
Procedure ImportMappingStatistics_22(Cancel)
	
	Try
		
		GetMappingStatistics = False;
		
		IncomingParameters = GetFromTempStorage(TempStorageAddress);
		
		AllDataMapped = IncomingParameters.AllDataMapped;
		
		Object.Statistics.Load(IncomingParameters.Statistics);
		Object.Statistics.Sort("Presentation");
		
		// Specifying the current list row
		Items.Statistics.CurrentRow = TableRowID("Key", Statistics_Key, Object.Statistics);
		
	Except
		WriteErrorToEventLog(DetailErrorDescription(ErrorInfo()),
			EventLogMessageTextDataSynchronizationSetup);
		ReportError(Cancel);
		Return;
	EndTry;
	
EndProcedure

// Page 3: Manual data mapping.
//
&AtClient
Function Attachable_DataMapping_OnOpen(Cancel, SkipPage, IsGoNext)
	
	If StatisticsEmpty Then
		SkipPage = True;
	EndIf;
	
	Items.DataMappingStatusPages.CurrentPage = ?(AllDataMapped,
		Items.MappingStatusAllDataMapped,
		Items.MappingStatusHasUnmappedData);
EndFunction

// Page 3: Manual data mapping.
//
&AtClient
Function Attachable_DataMapping_OnGoNext(Cancel)
	
	If Not AllDataMapped And Not UserAnsweredYesToQuestionAboutMapping Then
		Buttons = New ValueList;
		Buttons.Add(DialogReturnCode.Yes, "Continue");
		Buttons.Add(DialogReturnCode.No, "Cancel");
		
		Message = NStr("en = 'Some data is not mapped. Leaving unmapped data can result in duplicate catalog items.
		                       |Do you want to continue?'");
		
		NotifyDescription = New NotifyDescription("ProcessUserAnswerOnMap", ThisObject);
		ShowQueryBox(NotifyDescription, Message, Buttons,, DialogReturnCode.No);
		Cancel = True;
	EndIf;
	
EndFunction

&AtClient
Procedure ProcessUserAnswerOnMap(Answer, AdditionalParameters) Export
	
	If Answer = DialogReturnCode.Yes Then
		
		UserAnsweredYesToQuestionAboutMapping = True;
		GoToNext();
		
	EndIf;
	
EndProcedure

//

// Page 4 (waiting):
// Data synchronization. 
// Importing exchange message received from a correspondent. 
// Exporting exchange message for a correspondent (catalogs only). 
// Sending message to a correspondent:
//   Importing an exchange message in a correspondent infobase. 
//   Sending an import status message (success or error) to the current infobase.
&AtClient
Function Attachable_DataSynchronizationWait_LongActionProcessing(Cancel, GoToNext)
	
	DataSynchronizationWait_LongActionProcessing(Cancel);
	
EndFunction

// Page 4 (waiting):
// Data synchronization. 
// Importing exchange message received from a correspondent. 
// Exporting exchange message for a correspondent (catalogs only). 
// Sending message to a correspondent.
//
&AtServer
Procedure DataSynchronizationWait_LongActionProcessing(Cancel)
	
	Try
		
		MethodParameters = New Structure;
		MethodParameters.Insert("Correspondent", Correspondent);
		MethodParameters.Insert("CorrespondentDataArea", CorrespondentDataArea);
		
		Result = LongActions.ExecuteInBackground(
			UUID,
			"DataProcessors.DataSynchronizationBetweenWebApplicationsSetupWizard.PerformCatalogSynchronization",
			MethodParameters,
			NStr("en = 'Setup of data synchronization between two online applications (catalog synchronization)'"));
		
		JobID = Result.JobID;
		TempStorageAddress = Result.StorageAddress;
	Except
		WriteErrorToEventLog(DetailErrorDescription(ErrorInfo()),
			EventLogMessageTextDataSynchronizationSetup);
		ReportError(Cancel);
		Return;
	EndTry;
	
EndProcedure

// Page 4 (waiting): Waiting until a background job is completed.
//
&AtClient
Function Attachable_DataSynchronizationWaitBackgroundJob_LongActionProcessing(Cancel, GoToNext)
	
	GoToNext = False;
	
	AttachIdleHandler("BackgroundJobIdleHandler", 5, True);
	
EndFunction

// Page 4 (waiting): Waiting for a correspondent response.
//
&AtClient
Function Attachable_DataSynchronizationWaitLongAction_LongActionProcessing(Cancel, GoToNext)
	
	Session = GetFromTempStorage(TempStorageAddress).Session;
	
	GoToNext = False;
	
	AttachIdleHandler("LongActionIdleHandler", 5, True);
	
EndFunction

// Page 4 (waiting): Getting the default values from a correspondent.
//
&AtClient
Function Attachable_DefaultCorrespondentValueCheck_LongActionProcessing(Cancel, GoToNext)
	
	If CorrespondentInfobaseNodeDefaultValuesAvailable Then
		
		GetCorrespondentData(Cancel);
		
	EndIf;
	
EndFunction

// Page 4 (waiting): Getting the default values from a correspondent.
//
&AtClient
Function Attachable_DefaultCorrespondentValueCheckLongAction_LongActionProcessing(Cancel, GoToNext)
	
	If CorrespondentInfobaseNodeDefaultValuesAvailable Then
		
		GoToNext = False;
		
		AttachIdleHandler("LongActionIdleHandler", 5, True);
		
	EndIf;
	
EndFunction

// Page 4 (waiting): Getting the default values from a correspondent.
//
&AtClient
Function Attachable_DefaultCorrespondentValueCheckLongActionCompletion_LongActionProcessing(Cancel, GoToNext)
	
	If CorrespondentInfobaseNodeDefaultValuesAvailable Then
		
		ImportCorrespondentDataToStorage(Cancel);
		
	EndIf;
	
EndFunction

// Page 4 (waiting).
//
&AtServer
Procedure GetCorrespondentData(Cancel)
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		
		// Sending message to a correspondent
		Message = MessagesSaaS.NewMessage(
			DataExchangeMessagesManagementInterface.GetCorrespondentDataMessage());
		Message.Body.CorrespondentZone = CorrespondentDataArea;
		
		Message.Body.Tables = XDTOSerializer.WriteXDTO(CorrespondentTables);
		Message.Body.ExchangePlan = ExchangePlanName;
		
		Session = DataExchangeSaaS.SendMessage(Message);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteErrorToEventLog(DetailErrorDescription(ErrorInfo()),
			EventLogMessageTextDataSynchronizationSetup);
		ReportError(Cancel);
		Return;
	EndTry;
	
	MessagesSaaS.DeliverQuickMessages();
	
EndProcedure

// Page 4 (waiting).
//
&AtServer
Procedure ImportCorrespondentDataToStorage(Cancel)
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		
		CorrespondentData = InformationRegisters.SystemMessageExchangeSessions.GetSessionData(Session);
		
		CorrespondentDataStorageAddress = PutToTempStorage(CorrespondentData, ThisObject.UUID);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteErrorToEventLog(DetailErrorDescription(ErrorInfo()),
			EventLogMessageTextDataSynchronizationSetup);
		ReportError(Cancel);
		Return;
	EndTry;
	
EndProcedure

// Pages 4 and 6 (waiting): Checking correspondent accounting parameters.
//
&AtClient
Function Attachable_CorrespondentAccountingParameterCheck_LongActionProcessing(Cancel, GoToNext)
	
	GetCorrespondentAccountingParameters(Cancel);
	
EndFunction

// Pages 4 and 6 (waiting): Checking correspondent accounting parameters.
//
&AtClient
Function Attachable_CorrespondentAccountingParameterCheckLongAction_LongActionProcessing(Cancel, GoToNext)
	
	GoToNext = False;
	
	AttachIdleHandler("LongActionIdleHandler", 5, True);
	
EndFunction

// Page 4 (waiting): Checking correspondent accounting parameters.
//
&AtClient
Function Attachable_CorrespondentAccountingParameterCheckLongActionCompletion4_LongActionProcessing(Cancel, GoToNext)
	
	ErrorMessage = "";
	CorrespondentErrorMessage = "";
	
	ImportCorrespondentAccountingParameters(Cancel, ErrorMessage, CorrespondentErrorMessage);
	
	If Cancel Then
		Return Undefined;
	EndIf;
	
	If Not AccountingParametersSpecified Then
		AccountingSettingsLabel = ErrorMessage;
	EndIf;
	
	If Not CorrespondentAccountingParametersSpecified Then
		CorrespondentAccountingSettingsLabel = CorrespondentErrorMessage;
	EndIf;
	
EndFunction

// Page 6 (waiting): Checking correspondent accounting parameters.
//
&AtClient
Function Attachable_CorrespondentAccountingParameterCheckLongActionCompletion6_LongActionProcessing(Cancel, GoToNext)
	
	ErrorMessage = "";
	CorrespondentErrorMessage = "";
	
	ImportCorrespondentAccountingParameters(Cancel, ErrorMessage, CorrespondentErrorMessage);
	
	If Cancel Then
		Return Undefined;
	EndIf;
	
	If Not AccountingParametersSpecified Then
		AccountingSettingsLabel = ErrorMessage;
		Cancel = True;
	EndIf;
	
	If Not CorrespondentAccountingParametersSpecified Then
		CorrespondentAccountingSettingsLabel = CorrespondentErrorMessage;
		Cancel = True;
	EndIf;
	
EndFunction

// Pages 4 and 6 (waiting).
//
&AtServer
Procedure GetCorrespondentAccountingParameters(Cancel)
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		
		// Sending message to a correspondent
		Message = MessagesSaaS.NewMessage(
			DataExchangeMessagesManagementInterface.GetCorrespondentAccountParametersMessage());
		Message.Body.CorrespondentZone = CorrespondentDataArea;
		
		Message.Body.ExchangePlan = ExchangePlanName;
		Message.Body.CorrespondentCode = DataExchangeCached.GetThisNodeCodeForExchangePlan(ExchangePlanName);
		
		Session = DataExchangeSaaS.SendMessage(Message);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteErrorToEventLog(DetailErrorDescription(ErrorInfo()),
			EventLogMessageTextDataSynchronizationSetup);
		ReportError(Cancel);
		Return;
	EndTry;
	
	MessagesSaaS.DeliverQuickMessages();
	
EndProcedure

// Pages 4 and 6 (waiting).
//
&AtServer
Procedure ImportCorrespondentAccountingParameters(Cancel, ErrorMessage = "", CorrespondentErrorMessage = "")
	
	SetPrivilegedMode(True);
	
	Try
		
		// Correspondent accounting parameters
		CorrespondentData = InformationRegisters.SystemMessageExchangeSessions.GetSessionData(Session).Get();
		
		CorrespondentAccountingParametersSpecified = CorrespondentData.AccountingParametersSpecified;
		CorrespondentErrorMessage    = CorrespondentData.ErrorPresentation;
		
		If IsBlankString(CorrespondentErrorMessage) Then
			CorrespondentErrorMessage = NStr("en = 'There are no accounting parameters specified in the infobase %1.'");
			CorrespondentErrorMessage = StringFunctionsClientServer.SubstituteParametersInString(CorrespondentErrorMessage, CorrespondentDescription);
		EndIf;
		
		// Current infobase accounting parameters
		AccountingParametersSpecified = DataExchangeServer.SystemAccountingSettingsAreSet(ExchangePlanName, Correspondent, ErrorMessage);
		
		If IsBlankString(ErrorMessage) Then
			ErrorMessage = NStr("en = 'There are no accounting parameters specified in the current infobase.'");
		EndIf;
		
	Except
		WriteErrorToEventLog(DetailErrorDescription(ErrorInfo()),
			EventLogMessageTextDataSynchronizationSetup);
		ReportError(Cancel);
		Return;
	EndTry;
	
	Items.AccountingParameters.Visible = Not AccountingParametersSpecified;
	Items.CorrespondentAccountingParameters.Visible = Not CorrespondentAccountingParametersSpecified;
	
EndProcedure

// Page 5 (Rules for getting data):
// If specifying default values is not required and accounting parameters are set, skip the step.
//
&AtClient
Function Attachable_DataReceivingRules_OnOpen(Cancel, SkipPage, IsGoNext)
	
	If Not NodeDefaultValuesAvailable
		And Not CorrespondentInfobaseNodeDefaultValuesAvailable Then
		
		SkipPage = True;
		
	EndIf;
	
	Items.ThisApplicationDescriptionRules.Visible = Items.DefaultValueDetailsGroup.Visible;
	Items.CorrespondentDescriptionRules.Visible   = Items.DefaultCorrespondentValueDetailsGroup.Visible;
	
EndFunction

// Page 5 (Rules for getting data):
// Specifying default values.
//
&AtClient
Function Attachable_DataReceivingRules_OnGoNext(Cancel)
	
	// Checking whether attributes of the additional settings form are filled
	If NodeDefaultValuesAvailable Then
		
		FormParameters = New Structure;
		FormParameters.Insert("CorrespondentVersion", CorrespondentVersion);
		FormParameters.Insert("NodeDefaultValues", NodeDefaultValues);
		
		SettingsFormName = "ExchangePlan.[ExchangePlanName].Form.[DefaultValueSetupForm]";
		SettingsFormName = StrReplace(SettingsFormName, "[ExchangePlanName]", ExchangePlanName);
		SettingsFormName = StrReplace(SettingsFormName, "[DefaultValueSetupForm]", DefaultValueSetupForm);
		
		SettingsForm = GetForm(SettingsFormName, FormParameters, ThisObject);
		
		If Not SettingsForm.CheckFilling() Then
			
			CommonUseClientServer.MessageToUser(NStr("en = 'Specify the mandatory settings.'"),,, "DefaultValueDetails", Cancel);
			
		EndIf;
		
	EndIf;
	
	// Checking whether attributes of the additional settings form are filled
	If CorrespondentInfobaseNodeDefaultValuesAvailable Then
		
		ConnectionParameters = New Structure;
		ConnectionParameters.Insert("JoinType", "TempStorage");
		ConnectionParameters.Insert("TempStorageAddress", CorrespondentDataStorageAddress);
		
		FormParameters = New Structure;
		FormParameters.Insert("CorrespondentVersion", CorrespondentVersion);
		FormParameters.Insert("ExternalConnectionParameters", ConnectionParameters);
		FormParameters.Insert("NodeDefaultValues", CorrespondentInfobaseNodeDefaultValues);
		
		SettingsFormName = "ExchangePlan.[ExchangePlanName].Form.[CorrespondentInfobaseDefaultValueSetupForm]";
		SettingsFormName = StrReplace(SettingsFormName, "[ExchangePlanName]", ExchangePlanName);
		SettingsFormName = StrReplace(SettingsFormName, "[CorrespondentInfobaseDefaultValueSetupForm]", CorrespondentInfobaseDefaultValueSetupForm);
		
		SettingsForm = GetForm(SettingsFormName, FormParameters, ThisObject);
		
		If Not SettingsForm.CheckFilling() Then
			
			CommonUseClientServer.MessageToUser(NStr("en = 'Specify the mandatory settings for the second application.'")
				,,, "DefaultCorrespondentValueDetails", Cancel);
		EndIf;
		
	EndIf;
	
EndFunction


// Page 6 (Setup of accounting parameters):
// If specifying default values is not required and accounting parameters are set, skip the step.
//
&AtClient
Function Attachable_AccountingParameterSetup_OnOpen(Cancel, SkipPage, IsGoNext)
	
	If AccountingParametersSpecified
		And CorrespondentAccountingParametersSpecified Then
		
		SkipPage = True;
		
	EndIf;
	
EndFunction


// Page 7 (waiting):
// Saving user-defined settings.
// Registering all data to be exported (except catalogs). 
// Sending message to a correspondent:
//   Saving user-defined settings.
//   Registering all data to be exported (except catalogs).
//   Sending an export status message (success or error) to the current infobase. 
// Starting background exchange from the current infobase.
//
&AtClient
Function Attachable_SettingsSavingWait_LongActionProcessing(Cancel, GoToNext)
	
	SettingsSavingWait_LongActionProcessing(Cancel);
	
EndFunction

// Page 7 (waiting):
// Saving user-defined settings.
// Registering all data to be exported (except catalogs). 
// Sending message to a correspondent.
//
&AtServer
Procedure SettingsSavingWait_LongActionProcessing(Cancel)
	
	Try
		MethodParameters = New Structure;
		MethodParameters.Insert("Correspondent", Correspondent);
		MethodParameters.Insert("CorrespondentDataArea", CorrespondentDataArea);
		MethodParameters.Insert("NodeDefaultValues", NodeDefaultValues);
		MethodParameters.Insert("CorrespondentInfobaseNodeDefaultValues", CorrespondentInfobaseNodeDefaultValues);
		
		Result = LongActions.ExecuteInBackground(
			UUID,
			"DataProcessors.DataSynchronizationBetweenWebApplicationsSetupWizard.SetUpExchangeStep2",
			MethodParameters,
			NStr("en = 'Setup of data synchronization between two online applications (step 2)'"));
		
		JobID = Result.JobID;
		TempStorageAddress = Result.StorageAddress;
	Except
		WriteErrorToEventLog(DetailErrorDescription(ErrorInfo()),
			EventLogMessageTextDataSynchronizationSetup);
		ReportError(Cancel);
		Return;
	EndTry;
	
EndProcedure

// Page 7 (waiting): Waiting until a background job is completed.
//
&AtClient
Function Attachable_SettingsSavingWaitBackgroundJob_LongActionProcessing(Cancel, GoToNext)
	
	GoToNext = False;
	
	AttachIdleHandler("BackgroundJobIdleHandler", 5, True);
	
EndFunction

// Page 7 (waiting): Waiting for a correspondent response.
//
&AtClient
Function Attachable_SettingsSavingWaitLongAction_LongActionProcessing(Cancel, GoToNext)
	
	Session = GetFromTempStorage(TempStorageAddress).Session;
	
	GoToNext = False;
	
	AttachIdleHandler("LongActionIdleHandler", 5, True);
	
EndFunction

//

// Page 7 (waiting): Committing exchange settings creation in the SaaS manager.
//
&AtClient
Function Attachable_ExchangeSettingsCreationCommit_LongActionProcessing(Cancel, GoToNext)
	
	CommitExchangeSettingsCreationInServiceManager(Cancel);
	
EndFunction

// Page 7 (waiting): Committing exchange settings creation in the SaaS manager.
//
&AtClient
Function Attachable_ExchangeSettingsCreationCommitLongAction_LongActionProcessing(Cancel, GoToNext)
	
	GoToNext = False;
	
	AttachIdleHandler("LongActionIdleHandler", 5, True);
	
EndFunction

// Page 7 (waiting): Committing exchange settings creation in the SaaS manager.
//
&AtClient
Function Attachable_ExchangeSettingsCreationCommitLongActionCompletion_LongActionProcessing(Cancel, GoToNext)
	
	Notify("Create_DataSynchronization");
	
EndFunction

// Page 7 (waiting): Committing exchange settings creation in the SaaS manager.
//
&AtServer
Procedure CommitExchangeSettingsCreationInServiceManager(Cancel)
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		
		// Sending "enable synchronization" message to the SaaS manager
		Message = MessagesSaaS.NewMessage(
			MessagesDataExchangeAdministrationManagementInterface.EnableSynchronizationMessage());
		Message.Body.CorrespondentZone = CorrespondentDataArea;
		
		Message.Body.ExchangePlan = ExchangePlanName;
		
		Session = DataExchangeSaaS.SendMessage(Message);
		
		// Sending message that contains a request for synchronization between two applications to the SaaS manager
		Message = MessagesSaaS.NewMessage(
			MessagesDataExchangeAdministrationManagementInterface.PushSynchronizationBetweenTwoApplicationsMessage());
		Message.Body.CorrespondentZone = CorrespondentDataArea;
		
		DataExchangeSaaS.SendMessage(Message);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteErrorToEventLog(DetailErrorDescription(ErrorInfo()),
			EventLogMessageTextDataSynchronizationSetup);
		ReportError(Cancel);
		Return;
	EndTry;
	
	MessagesSaaS.DeliverQuickMessages();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Overridable part: Filling wizard navigation table.

&AtServer
Procedure DataSynchronizationSetupScenario()
	
	GoToTable.Clear();
	
	GoToTableNewRow(1, "Beginning",                      "NavigationPageStart",,, "Start_OnGoNext");
	
	// Getting correspondent default values
	GoToTableNewRow(2, "DataSynchronizationWait", "NavigationPageWait",,,,, True, "DefaultCorrespondentValueCheck_LongActionProcessing");
	GoToTableNewRow(3, "DataSynchronizationWait", "NavigationPageWait",,,,, True, "DefaultCorrespondentValueCheckLongAction_LongActionProcessing");
	GoToTableNewRow(4, "DataSynchronizationWait", "NavigationPageWait",,,,, True, "DefaultCorrespondentValueCheckLongActionCompletion_LongActionProcessing");
	GoToTableNewRow(5, "DataReceivingRules",    "NavigationPageContinuation",, "DataReceivingRules_OnOpen", "DataReceivingRules_OnGoNext");
	
	// Adding steps of settings creation and automatic data mapping
	GoToTableNewRow(6, "DataAnalysisWait",       "NavigationPageWait",,,,, True, "DataAnalysisWait_LongActionProcessing");
	GoToTableNewRow(7, "DataAnalysisWait",       "NavigationPageWait",,,,, True, "DataAnalysisWaitBackgroundJob_LongActionProcessing");
	GoToTableNewRow(8, "DataAnalysisWait",       "NavigationPageWait",,,,, True, "DataAnalysisWaitLongAction_LongActionProcessing");
	GoToTableNewRow(9, "DataAnalysisWait",       "NavigationPageWait",,,,, True, "DataAnalysisWaitLongActionCompletion_LongActionProcessing");
	GoToTableNewRow(10, "DataAnalysisWait",       "NavigationPageWait",,,,, True, "DataMappingWaitBackgroundJob_LongActionProcessing");
	GoToTableNewRow(11, "DataAnalysisWait",       "NavigationPageWait",,,,, True, "DataMappingWaitBackgroundJobCompletion_LongActionProcessing");
	
	// Getting mapping statistics (this operation is optional)
	GoToTableNewRow(12, "DataAnalysisWait",       "NavigationPageWait",,,,, True, "MappingStatisticsGettingWait_LongActionProcessing").Mark = "StatisticsPage";
	
	GoToTableNewRow(13,  "DataAnalysisWait",       "NavigationPageWait",,,,, True, "MappingStatisticsGettingWaitBackgroundJob_LongActionProcessing");
	GoToTableNewRow(14, "DataAnalysisWait",       "NavigationPageWait",,,,, True, "MappingStatisticsGettingWaitBackgroundJobCompletion_LongActionProcessing");
	
	// Manual data mapping
	GoToTableNewRow(15, "DataMapping",         "NavigationPageContinuation",, "DataMapping_OnOpen", "DataMapping_OnGoNext");
	
	// Catalog synchronization
	GoToTableNewRow(16, "DataSynchronizationWait", "NavigationPageWait",,,,, True, "DataSynchronizationWait_LongActionProcessing");
	GoToTableNewRow(17, "DataSynchronizationWait", "NavigationPageWait",,,,, True, "DataSynchronizationWaitBackgroundJob_LongActionProcessing");
	GoToTableNewRow(18, "DataSynchronizationWait", "NavigationPageWait",,,,, True, "DataSynchronizationWaitLongAction_LongActionProcessing");
	
	// Checking correspondent accounting parameters
	GoToTableNewRow(19, "DataSynchronizationWait", "NavigationPageWait",,,,, True, "CorrespondentAccountingParameterCheck_LongActionProcessing");
	GoToTableNewRow(20, "DataSynchronizationWait", "NavigationPageWait",,,,, True, "CorrespondentAccountingParameterCheckLongAction_LongActionProcessing");
	GoToTableNewRow(21, "DataSynchronizationWait", "NavigationPageWait",,,,, True, "CorrespondentAccountingParameterCheckLongActionCompletion4_LongActionProcessing");
	
	GoToTableNewRow(22, "AccountingParameterSetup",    "NavigationPageContinuation",, "AccountingParameterSetup_OnOpen");
	
	// Checking correspondent accounting parameters
	GoToTableNewRow(23, "SettingsSavingWait", "NavigationPageWait",,,,, True, "CorrespondentAccountingParameterCheck_LongActionProcessing");
	GoToTableNewRow(24, "SettingsSavingWait", "NavigationPageWait",,,,, True, "CorrespondentAccountingParameterCheckLongAction_LongActionProcessing");
	GoToTableNewRow(25, "SettingsSavingWait", "NavigationPageWait",,,,, True, "CorrespondentAccountingParameterCheckLongActionCompletion6_LongActionProcessing");
	
	// Adding steps of settings update and data registration
	GoToTableNewRow(26, "SettingsSavingWait", "NavigationPageWait",,,,, True, "SettingsSavingWait_LongActionProcessing");
	GoToTableNewRow(27, "SettingsSavingWait", "NavigationPageWait",,,,, True, "SettingsSavingWaitBackgroundJob_LongActionProcessing");
	GoToTableNewRow(28, "SettingsSavingWait", "NavigationPageWait",,,,, True, "SettingsSavingWaitLongAction_LongActionProcessing");
	
	// Sending message to the SaaS manager to commit exchange settings
	GoToTableNewRow(29, "SettingsSavingWait", "NavigationPageWait",,,,, True, "ExchangeSettingsCreationCommit_LongActionProcessing");
	GoToTableNewRow(30, "SettingsSavingWait", "NavigationPageWait",,,,, True, "ExchangeSettingsCreationCommitLongAction_LongActionProcessing");
	GoToTableNewRow(31, "SettingsSavingWait", "NavigationPageWait",,,,, True, "ExchangeSettingsCreationCommitLongActionCompletion_LongActionProcessing");
	
	GoToTableNewRow(32, "End",                  "NavigationPageEnd");
	
EndProcedure

&AtServer
Function PageNumber_MappingStatisticsGetting()
	
	Rows = GoToTable.FindRows( New Structure("Mark", "StatisticsPage") );
	If Rows.Count() > 0 Then
		Return Rows[0].GoToNumber;
	EndIf;
	
	Return 0;
EndFunction

#EndRegion
