
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
  // Skipping the initialization to guarantee that the form will be
  // received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then
		Return;
	EndIf;
	
 // Only users with administrative rights can enable and disable data
 // synchronization for subscribers.
	DataExchangeServer.CheckExchangeManagementRights();
	
	If Not DataExchangeSaaSCached.DataSynchronizationSupported() Then
		
		Raise NStr("en = 'The configuration does not support data synchronization.'");
		
	EndIf;
	
	EventLogMessageTextDataSynchronizationMonitor = DataExchangeSaaS.EventLogMessageTextDataSynchronizationMonitor();
	
	SynchronizationSettingsGettingScenario();
	
	Items.DataSynchronizationSettingsDisableDataSynchronization.Enabled = False;
	Items.DataSynchronizationSettingsContextMenuDisableDataSynchronization.Enabled = False;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// Selecting the second wizard step
	SetGoToNumber(2);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Create_DataSynchronization"
		Or EventName = "Disable_DataSynchronization" Then
		
		RefreshMonitor();
		
	ElsIf EventName = "DataExchangeResultFormClosed" Then
		
		UpdateDataSynchronizationSettings();
		
	EndIf;
	
EndProcedure

// Idle handlers

&AtClient
Procedure LongActionIdleHandler()
	
	Try
		SessionStatus = SessionStatus(Session);
	Except
		WriteErrorToEventLog(
			DetailErrorDescription(ErrorInfo()), EventLogMessageTextDataSynchronizationMonitor);
		GoBack();
		Return;
	EndTry;
	
	If SessionStatus = "Done" Then
		
		GoToNext();
		
	ElsIf SessionStatus = "Error" Then
		
		GoBack();
		Return;
		
	Else
		
		AttachIdleHandler("LongActionIdleHandler", 5, True);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure SendData(Command)
	// Adding new data items to the exported data
	
	ApplicationData = Items.DataSynchronizationSettings.CurrentData;
	If ApplicationData = Undefined Or Not ApplicationData.SynchronizationConfigured Then
		Return;
	EndIf;
	
	OpenForm("DataProcessor.InteractiveDataExchangeWizardSaaS.Form.Form",
		New Structure("DenyUploadingOnlyModified, InfobaseNode", 
			True, ApplicationData.Correspondent
		), ThisObject);
	
EndProcedure

&AtClient
Procedure PerformDataSynchronization(Command)
	
	GoToNext();
	
EndProcedure

&AtClient
Procedure SetUpDataSynchronization(Command)
	
	PerformDataSynchronizationSetup(Items.DataSynchronizationSettings.CurrentData);
	
EndProcedure

&AtClient
Procedure DisableDataSynchronization(Command)
	
	CurrentData = Items.DataSynchronizationSettings.CurrentData;
	
	If CurrentData <> Undefined
		And CurrentData.SynchronizationConfigured Then
		
		If CurrentData.SynchronizationSetupInServiceManager Then
			
			ShowMessageBox(, NStr("en = 'To disable data synchronization, switch to SaaS manager
				|and use the ""Data synchronization"" command.'"));
		Else
			
			FormParameters = New Structure;
			FormParameters.Insert("ExchangePlanName",              CurrentData.ExchangePlan);
			FormParameters.Insert("CorrespondentDataArea", CurrentData.DataArea);
			FormParameters.Insert("CorrespondentDescription",  CurrentData.ApplicationDescription);
			
			OpenForm("DataProcessor.DataSynchronizationBetweenWebApplicationsSetupWizard.Form.DataSynchronizationDisabling", FormParameters, ThisObject,,,,,FormWindowOpeningMode.LockOwnerWindow);
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure Refresh(Command)
	
	RefreshMonitor();
	
EndProcedure

&AtClient
Procedure DataSynchronizationSettingsSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	PerformDataSynchronizationSetup(Items.DataSynchronizationSettings.CurrentData);
	
EndProcedure

&AtClient
Procedure DataSynchronizationSettingsOnActivateRow(Item)
	
	CurrentData = Item.CurrentData;
	If CurrentData = Undefined Then
		Items.DataSynchronizationSettingsDisableDataSynchronization.Enabled = False;
		Items.DataSynchronizationSettingsContextMenuDisableDataSynchronization.Enabled = False;
		DataSynchronizationSettingsDescription = "";
		
		Items.DataSynchronizationSettingsPrepareData.Enabled = False;
		Items.DataSynchronizationSettingsContextMenuSendData.Enabled = False;
	Else		
		Items.DataSynchronizationSettingsDisableDataSynchronization.Enabled = CurrentData.SynchronizationConfigured;
		Items.DataSynchronizationSettingsContextMenuDisableDataSynchronization.Enabled = CurrentData.SynchronizationConfigured;
		DataSynchronizationSettingsDescription = CurrentData.Description;
		
		Items.DataSynchronizationSettingsPrepareData.Enabled = CurrentData.SynchronizationConfigured;
		Items.DataSynchronizationSettingsContextMenuSendData.Enabled = CurrentData.SynchronizationConfigured;
	EndIf;
	
EndProcedure

&AtClient
Procedure GoToConflicts(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("ExchangeNodes", UsedNodeArray(DataSynchronizationSettings));
	OpenForm("InformationRegister.DataExchangeResults.Form.Form", FormParameters);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS (Supplied part)

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
	
	Items.MainPanel.CurrentPage = Items[GoToRowCurrent.MainPageName];
	
	If Not IsBlankString(GoToRowCurrent.DecorationPageName) Then
		
		Items.DataSynchronizationPanel.CurrentPage = Items[GoToRowCurrent.DecorationPageName];
		
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

&AtServer
Procedure GoToTableNewRow(GoToNumber,
									MainPageName,
									NavigationPageName = "",
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

&AtClientAtServerNoContext
Function UsedNodeArray(DataSynchronizationSettings)
	
	ExchangeNodes = New Array;
	
	For Each NodeRow In DataSynchronizationSettings Do
		If NodeRow.SynchronizationConfigured Then
			ExchangeNodes.Add(NodeRow.Correspondent);
		EndIf;
	EndDo;
	
	Return ExchangeNodes;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS (Overridable part)

&AtClient
Procedure GoToNext()
	
	ChangeGoToNumber(+1);
	
EndProcedure

&AtClient
Procedure GoBack()
	
	ChangeGoToNumber(-1);
	
EndProcedure

&AtServerNoContext
Function SessionStatus(Val Session)
	
	SetPrivilegedMode(True);
	
	Return InformationRegisters.SystemMessageExchangeSessions.SessionStatus(Session);
	
EndFunction

&AtServerNoContext
Procedure WriteErrorToEventLog(Val ErrorMessageString, Val Event)
	
	WriteLogEvent(Event, EventLogLevel.Error,,, ErrorMessageString);
	
EndProcedure

&AtServer
Function NewSession()
	
	Session = InformationRegisters.SystemMessageExchangeSessions.NewSession();
	
	Return Session;
EndFunction

&AtServer
Procedure SetSynchronizationSettingsGettingScenario()
	
	SynchronizationSettingsGettingScenario();
	
EndProcedure

&AtClient
Procedure PerformDataSynchronizationSetup(Val CurrentData)
	
	If CurrentData <> Undefined Then
		
		If CurrentData.SynchronizationConfigured Then
			
			ShowValue(, CurrentData.Correspondent);
			
		ElsIf CurrentData.SynchronizationSetupInServiceManager Then
			
			ShowMessageBox(, NStr("en = 'For data synchronization setup, switch to SaaS manager
				|and use the ""Data synchronization"" command.'"));
		Else
			
			FormParameters = New Structure;
			FormParameters.Insert("ExchangePlanName",         CurrentData.ExchangePlan);
			FormParameters.Insert("CorrespondentDataArea",    CurrentData.DataArea);
			FormParameters.Insert("CorrespondentDescription", CurrentData.ApplicationDescription);
			FormParameters.Insert("CorrespondentEndpoint",    CurrentData.CorrespondentEndpoint);
			FormParameters.Insert("Prefix",                   CurrentData.Prefix);
			FormParameters.Insert("CorrespondentPrefix",      CurrentData.CorrespondentPrefix);
			FormParameters.Insert("CorrespondentVersion",     CurrentData.CorrespondentVersion);
			
			Uniqueness = CurrentData.ExchangePlan + Format(CurrentData.DataArea, "ND=7; NLZ=; NG=0");
			
			OpenForm("DataProcessor.DataSynchronizationBetweenWebApplicationsSetupWizard.Form.Form",
				FormParameters, ThisObject, Uniqueness,,,,FormWindowOpeningMode.LockOwnerWindow);
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure RefreshMonitor()
	
	SetSynchronizationSettingsGettingScenario();
	
	GoToNumber = 0;
	
	// Selecting the second wizard step
	SetGoToNumber(2);
	
EndProcedure

&AtServer
Procedure UpdateDataSynchronizationSettings()
	
	IssueCount = 0;
	
	// Getting synchronization statuses for the settings table
	SynchronizationStatuses = DataExchangeSaaS.DataSynchronizationStatuses();
	
	For Each Settings In DataSynchronizationSettings Do
		
		If Settings.SynchronizationConfigured Then
			
			SynchronizationStatus = SynchronizationStatuses.Find(Settings.Correspondent, "Package");
			
			If SynchronizationStatus <> Undefined Then
				
				Settings.SynchronizationStatus = SynchronizationStatus.Status;
				
				If SynchronizationStatus.Status = 1 Then // SaaS administrator action required
					
					Settings.Status = NStr("en = 'Data synchronization errors'");
					
				ElsIf SynchronizationStatus.Status = 2 Then // The user can solve issues on their own
					
					Settings.Status = NStr("en = 'Data synchronization issues'");
					
					IssueCount = IssueCount + SynchronizationStatus.IssueCount;
					
				ElsIf SynchronizationStatus.Status = 3 Then
					
					Settings.Status = NStr("en = 'Data synchronization configured'");
					
				EndIf;
				
			Else
				Settings.Status = NStr("en = 'Data synchronization configured'");
				Settings.SynchronizationStatus = 3;
			EndIf;
			
		Else
			
			Settings.Description = NStr("en = 'Data synchronization not configured'");
			Settings.SynchronizationStatus = 0;
			
		EndIf;
		
	EndDo;
		
	// Displaying synchronization issues in monitor header
	TitleStructure = DataExchangeServer.IssueMonitorHyperlinkTitleStructure(UsedNodeArray(DataSynchronizationSettings));
	FillPropertyValues(Items.GoToConflicts, TitleStructure);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Step change handlers

// Page 1 (waiting): Getting synchronization settings
//
&AtClient
Function Attachable_DataGettingWait_LongActionProcessing(Cancel, GoToNext)
	
	RequestDataSynchronizationSettings(Cancel);
	
EndFunction

// Page 1 (waiting): Getting synchronization settings
//
&AtClient
Function Attachable_DataGettingWaitLongAction_LongActionProcessing(Cancel, GoToNext)
	
	GoToNext = False;
	
	AttachIdleHandler("LongActionIdleHandler", 5, True);
	
EndFunction

// Page (waiting): Getting synchronization settings
//
&AtClient
Function Attachable_DataGettingWaitLongActionCompletion_LongActionProcessing(Cancel, GoToNext)
	
	GetDataSynchronizationSettings(Cancel);
	
EndFunction

// Page (waiting): Getting synchronization settings
//
&AtServer
Procedure RequestDataSynchronizationSettings(Cancel)
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		
		// Sending message to the SaaS manager
		Message = MessagesSaaS.NewMessage(
			MessagesDataExchangeAdministrationManagementInterface.GetDataSynchronizationSettingsMessage());
		Message.Body.Zone = CommonUse.SessionSeparatorValue();
		Message.Body.SessionId = NewSession();
		
		MessagesSaaS.SendMessage(Message,
			SaaSOperationsCached.ServiceManagerEndpoint(), True);
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteErrorToEventLog(DetailErrorDescription(ErrorInfo()),
			EventLogMessageTextDataSynchronizationMonitor);
		Cancel = True;
		Return;
	EndTry;
	
	MessagesSaaS.DeliverQuickMessages();
	
EndProcedure

// Page (waiting): Getting synchronization settings
//
&AtServer
Procedure GetDataSynchronizationSettings(Cancel)
	
	SetPrivilegedMode(True);
	
	Try
		
		SynchronizationSettingsFromServiceManager = MessageExchangeInternal.ConvertSynchronizationSettingsTable(InformationRegisters.SystemMessageExchangeSessions.GetSessionData(Session).Get());
		
		If SynchronizationSettingsFromServiceManager.Count() = 0 Then
			
			SynchronizationSettingsAbsenceScenario();
			Cancel = True;
			Return;
		EndIf;
		
		HasPrefix               = SynchronizationSettingsFromServiceManager.Columns.Find("Prefix") <> Undefined;
		HasCorrespondentVersion = SynchronizationSettingsFromServiceManager.Columns.Find("CorrespondentVersion") <> Undefined;
		
		// Filling the DataSynchronizationSettings table with SaaS manager data
		DataSynchronizationSettings.Clear();
		
		SynchronizationConfigured = False;
		
		For Each SettingsItemFromSaaSManager In SynchronizationSettingsFromServiceManager Do
			
			Settings = DataSynchronizationSettings.Add();
			
			Settings.ExchangePlan                      = SettingsItemFromSaaSManager.ExchangePlan;
			Settings.DataArea                          = SettingsItemFromSaaSManager.DataArea;
			Settings.ApplicationDescription            = SettingsItemFromSaaSManager.ApplicationDescription;
			Settings.SynchronizationConfigured         = SettingsItemFromSaaSManager.SynchronizationConfigured;
			Settings.SynchronizationSetupInServiceManager = SettingsItemFromSaaSManager.SynchronizationSetupInServiceManager;
			
			// Filling the CorrespondentEndpoint field
			Settings.CorrespondentEndpoint = ExchangePlans.MessageExchange.FindByCode(SettingsItemFromSaaSManager.CorrespondentEndpoint);
			
			If Settings.CorrespondentEndpoint.IsEmpty() Then
				Raise StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'Correspondent endpoint with code ""%1"" is not found.'"),
					SettingsItemFromSaaSManager.CorrespondentEndpoint);
			EndIf;
			
			If Settings.SynchronizationConfigured Then
				
				SynchronizationConfigured = True;
				
				// Filling the Correspondent field based on the current settings
				Settings.Correspondent = ExchangePlans[Settings.ExchangePlan].FindByCode(
					DataExchangeSaaS.ExchangePlanNodeCodeInService(Settings.DataArea));
				
				Settings.Description = DataExchangeServer.DataSynchronizationRuleDetails(Settings.Correspondent);
				
			EndIf;
			
			If HasPrefix Then
				Settings.Prefix              = SettingsItemFromSaaSManager.Prefix;
				Settings.CorrespondentPrefix = SettingsItemFromSaaSManager.CorrespondentPrefix;
			Else
				Settings.Prefix              = "";
				Settings.CorrespondentPrefix = "";
			EndIf;
			
			If HasCorrespondentVersion Then
				Settings.CorrespondentVersion = SettingsItemFromSaaSManager.CorrespondentVersion;
			Else
				Settings.CorrespondentVersion = "";
			EndIf;
			
		EndDo;
		
		Items.DataSynchronizationPanel.Visible = SynchronizationConfigured;
		
	Except
		
		WriteErrorToEventLog(DetailErrorDescription(ErrorInfo()),
			EventLogMessageTextDataSynchronizationMonitor);
		Cancel = True;
		Return;
	EndTry;
	
EndProcedure


// Page 2: Editing the synchronization settings list
//
&AtClient
Function Attachable_DataSynchronizationSetup_OnOpen(Cancel, SkipPage, IsGoNext)
	
	DataSynchronizationSetup_OnOpen(Cancel);
	
EndFunction

// Page 2: Editing the synchronization settings list
//
&AtServer
Procedure DataSynchronizationSetup_OnOpen(Cancel)
	
	SetPrivilegedMode(True);
	
	Try
		
		Items.SynchronizationMonitorGroup.Enabled = True;
		
		// Getting presentation of the date of successful synchronization
		Items.SynchronizationDatePresentation.Title = DataExchangeServer.SynchronizationDatePresentation(
			DataExchangeSaaS.LastSuccessfulImportForAllInfobaseNodesDate());
		
		UpdateDataSynchronizationSettings();
		
	Except
		WriteErrorToEventLog(DetailErrorDescription(ErrorInfo()),
			EventLogMessageTextDataSynchronizationMonitor);
		Cancel = True;
		Return;
	EndTry;
	
EndProcedure


// Page 3 (waiting): Performing synchronization
//
&AtClient
Function Attachable_SynchronizationPerforming_LongActionProcessing(Cancel, GoToNext)
	
	PushDataSynchronization(Cancel);
	
EndFunction

// Page 3 (waiting): Performing synchronization
//
&AtClient
Function Attachable_SynchronizationPerformingLongAction_LongActionProcessing(Cancel, GoToNext)
	
	GoToNext = False;
	
	AttachIdleHandler("LongActionIdleHandler", 5, True);
	
EndFunction

// Page 3 (waiting): Performing synchronization
//
&AtClient
Function Attachable_SynchronizationPerformingLongActionCompletion_LongActionProcessing(Cancel, GoToNext)
	
	Cancel = True; // Back to the monitor page (page 2)
	
	// Updating all opened dynamic lists
	DataExchangeClient.RefreshAllOpenDynamicLists();
	
EndFunction

// Page 3 (waiting): Performing synchronization
//
&AtServer
Procedure PushDataSynchronization(Cancel)
	
	Items.SynchronizationMonitorGroup.Enabled = False;
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		
		// Sending message to the SaaS manager
		Message = MessagesSaaS.NewMessage(
			MessagesDataExchangeAdministrationManagementInterface.PushSynchronizationMessage());
		Message.Body.Zone = CommonUse.SessionSeparatorValue();
		Message.Body.SessionId = NewSession();
		
		MessagesSaaS.SendMessage(Message,
			SaaSOperationsCached.ServiceManagerEndpoint(), True);
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteErrorToEventLog(DetailErrorDescription(ErrorInfo()),
			EventLogMessageTextDataSynchronizationMonitor);
		Cancel = True;
		Return;
	EndTry;
	
	MessagesSaaS.DeliverQuickMessages();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Filling wizard navigation table

&AtServer
Procedure SynchronizationSettingsGettingScenario()
	
	GoToTable.Clear();
	
	GoToTableNewRow(1, "DataGettingError");
	
	// Getting synchronization settings
	GoToTableNewRow(2, "DataGettingWait",,,,,, True, "DataGettingWait_LongActionProcessing");
	GoToTableNewRow(3, "DataGettingWait",,,,,, True, "DataGettingWaitLongAction_LongActionProcessing");
	GoToTableNewRow(4, "DataGettingWait",,,,,, True, "DataGettingWaitLongActionCompletion_LongActionProcessing");
	
	// Editing the synchronization settings list
	GoToTableNewRow(5, "DataSynchronizationSetup",, "SynchronizationState", "DataSynchronizationSetup_OnOpen");
	
	// Performing synchronization
	GoToTableNewRow(6, "DataSynchronizationSetup",, "SynchronizationPerforming",,,, True, "SynchronizationPerforming_LongActionProcessing");
	GoToTableNewRow(7, "DataSynchronizationSetup",, "SynchronizationPerforming",,,, True, "SynchronizationPerformingLongAction_LongActionProcessing");
	GoToTableNewRow(8, "DataSynchronizationSetup",, "SynchronizationPerforming",,,, True, "SynchronizationPerformingLongActionCompletion_LongActionProcessing");
	
EndProcedure

&AtServer
Procedure SynchronizationSettingsAbsenceScenario()
	
	GoToTable.Clear();
	
	GoToTableNewRow(1, "NoApplicationToSynchronize");
	GoToTableNewRow(2, "DataGettingWait",,,,,, True, "DataGettingWait_LongActionProcessing");
	GoToTableNewRow(3, "DataGettingWait",,,,,, True, "DataGettingWaitLongAction_LongActionProcessing");
	GoToTableNewRow(4, "DataGettingWait",,,,,, True, "DataGettingWaitLongActionCompletion_LongActionProcessing");
	
EndProcedure

#EndRegion
