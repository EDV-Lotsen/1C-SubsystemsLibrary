
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	// Skipping the initialization to guarantee that the form will 
 // be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then
		Return;
	EndIf;
	
	AddressForRestoringAccountPassword = Parameters.AddressForRestoringAccountPassword;
	CloseOnSynchronizationDone         = Parameters.CloseOnSynchronizationDone;
	InfobaseNode                       = Parameters.InfobaseNode;
	ExitApplication                    = Parameters.ExitApplication;
	
	If Not ValueIsFilled(InfobaseNode) Then
		
		If DataExchangeServer.IsSubordinateDIBNode() Then
			InfobaseNode = DataExchangeServer.MasterNode();
		Else
			DataExchangeServer.ReportError(NStr("en = 'Cannot open the form. The form parameters are not specified.'"), Cancel);
			Return;
		EndIf;
		
	EndIf;
	
	HasErrors = ((DataExchangeServer.MasterNode() = InfobaseNode) And ConfigurationChanged());
	
	// Setting form title
	Title = NStr("en = 'Data synchronization with %1'");
	Title = StringFunctionsClientServer.SubstituteParametersInString(Title, String(InfobaseNode));
	
	IsInRoleAddEditDataExchanges = Users.RolesAvailable("DataSynchronizationSetup");
	IsInRoleFullAccess = Users.InfobaseUserWithFullAccess();
	
	Items.PanelUpdateRequired.CurrentPage          = ?(IsInRoleFullAccess, Items.UpdateRequiredFullAccess, Items.UpdateRequiredRestrictedAccess);
	Items.UpdateRequiredFullAccessText.Title       = StringFunctionsClientServer.SubstituteParametersInString(Items.UpdateRequiredFullAccessText.Title, InfobaseNode);
	Items.UpdateRequiredRestrictedAccessText.Title = StringFunctionsClientServer.SubstituteParametersInString(Items.UpdateRequiredRestrictedAccessText.Title, InfobaseNode);
	
	Items.ForgotPassword.Visible = Not IsBlankString(AddressForRestoringAccountPassword);
	
	DataSynchronizationDisabled = False;
	ExecuteDataSending          = False;
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaSOperations.DataExchangeSaaS") Then
		
		StandaloneModeInternalModule = CommonUse.CommonModule("StandaloneModeInternal");
		
		NoLongSynchronizationPrompt = StandaloneModeInternalModule.IsStandaloneWorkstation()
			And (Not StandaloneModeInternalModule.LongSynchronizationQuestionSetupFlag());
		
	Else
		NoLongSynchronizationPrompt = True;
		
	EndIf;
	
	ExchangeMessageTransportKind = InformationRegisters.ExchangeTransportSettings.DefaultExchangeMessageTransportKind(InfobaseNode);
	
  // In "DIB exchange over a web service" scenario authentication parameters
  // (user name and password) stored in the infobase are redefined.
  // In "non-DIB exchange over a web service" scenario authentication parameters 
  // are only redefined (requested) if the infobase does not store the password. 	
	UseCurrentUserForAuthentication  = False;
	UseSavedAuthenticationParameters = False;
	SynchronizationPasswordSpecified = False;
	WSPassword                       = "";
	
	If ExchangeMessageTransportKind = Enums.ExchangeMessageTransportKinds.WS Then
		
		If DataExchangeCached.IsDistributedInfobaseNode(InfobaseNode) Then
			// If the current infobase is a DIB node and exchange is performed over a web service, 
     // using the session user name and password
			UseCurrentUserForAuthentication = True;
			SynchronizationPasswordSpecified = DataExchangeServer.DataSynchronizationPasswordSpecified(InfobaseNode);
			If SynchronizationPasswordSpecified Then
				WSPassword = DataExchangeServer.DataSynchronizationPassword(InfobaseNode);
			EndIf;
			
		Else
			// If the current infobase is not a DIB node, reading the transport settings from the infobase
			TransportSettings = InformationRegisters.ExchangeTransportSettings.TransportSettingsWS(InfobaseNode);
			SynchronizationPasswordSpecified = TransportSettings.WSRememberPassword;
			If SynchronizationPasswordSpecified Then
				UseSavedAuthenticationParameters = True;
				WSPassword = TransportSettings.WSPassword;
			Else
				// If user name and password are not available in the register, 
      // using the session user name and password
				SynchronizationPasswordSpecified = DataExchangeServer.DataSynchronizationPasswordSpecified(InfobaseNode);
				If SynchronizationPasswordSpecified Then
					UseSavedAuthenticationParameters = True;
					WSPassword = DataExchangeServer.DataSynchronizationPassword(InfobaseNode);
				EndIf;
			EndIf;
			
		EndIf;
		
	EndIf;

	// Selecting exchange scenario
	If HasErrors Then
		HasErrorsOnStartScenario();
		
	ElsIf ExchangeMessageTransportKind <> Enums.ExchangeMessageTransportKinds.WS Then
		// Data exchange is not performed over a web service
		DataExchangeScenarioNormal();
		
	Else
		
		ExecuteDataSending = InformationRegisters.CommonInfobaseNodeSettings.ExecuteDataSending(InfobaseNode);
		
		Items.LongSynchronizationWarningGroup.Visible = Not NoLongSynchronizationPrompt;
		Items.PasswordRequestGroup.Visible            = Not SynchronizationPasswordSpecified;
		
		If SynchronizationPasswordSpecified And NoLongSynchronizationPrompt Then
			// Executing data exchange
			If ExecuteDataSending Then
				ExchangeScenarioOverWebService_SendingReceivingSending();
			Else
				ExchangeScenarioOverWebService();
			EndIf;
			
		Else
			If ExecuteDataSending Then
				ExchangeScenarioOverWebServiceWithPasswordRequest_SendingReceivingSending();
			Else
				ExchangeScenarioOverWebServiceWithPasswordRequest();
			EndIf;
			
		EndIf;
		
	EndIf;
	
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaSOperations.DataExchangeSaaS") Then
		
		StandaloneModeInternalModule = CommonUse.CommonModule("StandaloneModeInternal");
	
		If Not StandaloneModeInternalModule.IsStandaloneWorkstation() Then
			CheckVersionDifference = True;
		EndIf;
		
	EndIf;
	
	WindowOptionsKey = ?(SynchronizationPasswordSpecified And NoLongSynchronizationPrompt, "SynchronizationPasswordSpecified", "") + "/" + ?(NoLongSynchronizationPrompt, "NoLongSynchronizationPrompt", "");
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SetGoToNumber(1);
	
EndProcedure

&AtClient
Procedure OnClose()
	
	SaveLongSynchronizationRequestFlag(Not NoLongSynchronizationPrompt);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure GoToEventLog(Command)
	
	FormParameters = GetEventLogFilterDataStructure(InfobaseNode);
	OpenForm("DataProcessor.EventLog.Form", FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure InstallUpdate(Command)
	Close();
	DataExchangeClient.ExecuteInfobaseUpdate(ExitApplication);
EndProcedure

&AtClient
Procedure ForgotPassword(Command)
	
	DataExchangeClient.OnOpenHowToChangeDataSynchronizationPasswordInstruction(AddressForRestoringAccountPassword);
	
EndProcedure

&AtClient
Procedure ExecuteExchange(Command)
	
	GoNextExecute();
	
EndProcedure

&AtClient
Procedure ContinueSynchronization(Command)
	
	GoToNumber = GoToNumber - 1;
	SetGoToNumber(GoToNumber + 1);
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// SUPPLIED PART
////////////////////////////////////////////////////////////////////////////////

&AtClient
Procedure GoNextExecute()
	
	ChangeGoToNumber(+1);
	
EndProcedure

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
	
	Items.DataExchangeExecution.CurrentPage  = Items[GoToRowCurrent.MainPageName];
	
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
			
			If VersionDifferenceErrorOnGetData.HasError Then
				
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
Procedure GoToTableNewRow(
									GoToNumber,
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

////////////////////////////////////////////////////////////////////////////////
// OVERRIDABLE PART
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS

&AtClient
Procedure LongActionIdleHandler()
	
	LongActionCompletedWithError = False;
	ErrorMessage = "";
	
	AuthenticationParameters = ?(UseSavedAuthenticationParameters,
		Undefined,
		New Structure("UseCurrentUser", UseCurrentUserForAuthentication));
	
	ActionState = DataExchangeServerCall.LongActionStateForInfobaseNode(
		LongActionID,
		InfobaseNode,
		AuthenticationParameters,
		ErrorMessage);
	
	If ActionState = "Active" Then
		
		AttachIdleHandler("LongActionIdleHandler", 5, True);
		
	Else
		
		If ActionState <> "Completed" Then
			
			LongActionCompletedWithError = True;
			
			HasErrors = True;
			
		EndIf;
		
		LongAction = False;
		LongActionFinished = True;
		
		GoNextExecute();
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function GetEventLogFilterDataStructure(InfobaseNode)
	
	SelectedEvents = New Array;
	SelectedEvents.Add(DataExchangeServer.GetEventLogMessageKey(InfobaseNode, Enums.ActionsOnExchange.DataImport));
	SelectedEvents.Add(DataExchangeServer.GetEventLogMessageKey(InfobaseNode, Enums.ActionsOnExchange.DataExport));
	
	DataExchangeStatesImport = DataExchangeServer.DataExchangeStates(InfobaseNode, Enums.ActionsOnExchange.DataImport);
	DataExchangeStatesExport = DataExchangeServer.DataExchangeStates(InfobaseNode, Enums.ActionsOnExchange.DataExport);
	
	Result = New Structure;
	Result.Insert("EventLogMessageText", SelectedEvents);
	Result.Insert("StartDate",           Min(DataExchangeStatesImport.StartDate, DataExchangeStatesExport.StartDate));
	Result.Insert("EndDate",             Max(DataExchangeStatesImport.EndDate, DataExchangeStatesExport.EndDate));
	
	Return Result;
EndFunction

&AtClient
Procedure SaveLongSynchronizationRequestFlag(Val Flag)
	
	Settings = Undefined;
	If SaveLongSynchronizationRequestFlagServer(Flag, Settings) Then
		ChangedSettings = New Array;
		ChangedSettings.Add(Settings);
		Notify("UserSettingsChanged", ChangedSettings, ThisObject);
	EndIf;
	
EndProcedure
	
&AtServerNoContext
Function SaveLongSynchronizationRequestFlagServer(Val Flag, Settings = Undefined)
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaSOperations.DataExchangeSaaS") Then
		
		StandaloneModeInternalModule = CommonUse.CommonModule("StandaloneModeInternal");
	
		MustSave = StandaloneModeInternalModule.IsStandaloneWorkstation() 
			And Flag <> StandaloneModeInternalModule.LongSynchronizationQuestionSetupFlag(); 
		
		If MustSave Then
			StandaloneModeInternalModule.LongSynchronizationQuestionSetupFlag(Flag, Settings);
		EndIf;
		
	Else
		MustSave = False;
	EndIf;
	
	Return MustSave;
EndFunction

&AtClient
Procedure ProcessVersionDifferenceError()
	
	Items.DataExchangeExecution.CurrentPage = Items.ExchangeCompletion;
	Items.ExchangeCompletionStatus.CurrentPage = Items.VersionDifferenceError;
	Items.ActionsPanel.CurrentPage = Items.ContinueCancelActions;
	Items.ContinueSynchronization.DefaultButton = True;
	Items.DecorationVersionDifferenceError.Title = VersionDifferenceErrorOnGetData.ErrorText;
	CheckVersionDifference = False;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// STEP CHANGE HANDLER SECTION

// Exchange over regular communication channels.

&AtClient
Function Attachable_OrdinaryDataExport_LongActionProcessing(Cancel, GoToNext)
	
	OrdinaryDataExport_LongActionProcessing(Cancel, InfobaseNode,
		ExchangeMessageTransportKind, VersionDifferenceErrorOnGetData, CheckVersionDifference);
	
	If VersionDifferenceErrorOnGetData.HasError Then
		
		Cancel = True;
		
	Else
		
		HasErrors = HasErrors Or Cancel;
		Cancel = False;
		
	EndIf;
	
EndFunction

&AtServerNoContext
Procedure OrdinaryDataExport_LongActionProcessing(Cancel, Val InfobaseNode,
	Val ExchangeMessageTransportKind, VersionDifferenceErrorOnGetData, CheckVersionDifference)
	
	DataExchangeServer.InitializeVersionDifferenceCheckParameters(CheckVersionDifference);
	
	// Starting data exchange
	DataExchangeServer.ExecuteDataExchangeForInfobaseNode(
											Cancel,
											InfobaseNode,
											True,
											False,
											ExchangeMessageTransportKind);
											
	VersionDifferenceErrorOnGetData = DataExchangeServer.VersionDifferenceErrorOnGetData();
	
EndProcedure

&AtClient
Function Attachable_OrdinaryDataImport_LongActionProcessing(Cancel, GoToNext)
	
	OrdinaryDataImport_LongActionProcessing(Cancel, InfobaseNode, ExchangeMessageTransportKind);
	
	HasErrors = HasErrors Or Cancel;
	Cancel = False;
	
EndFunction

&AtServerNoContext
Procedure OrdinaryDataImport_LongActionProcessing(Cancel, Val InfobaseNode, Val ExchangeMessageTransportKind)
	
	// Starting data exchange
	DataExchangeServer.ExecuteDataExchangeForInfobaseNode(
											Cancel,
											InfobaseNode,
											False,
											True,
											ExchangeMessageTransportKind);
	
EndProcedure

// Exchange over a web service.

&AtClient
Function Attachable_UserPasswordRequest_OnOpen(Cancel, SkipPage, IsGoNext)
	
	Items.ExecuteExchange.DefaultButton = True;
	
EndFunction

&AtClient
Function Attachable_UserPasswordRequest_OnGoNext(Cancel)
	
	If IsBlankString(WSPassword) Then
		NString = NStr("en = 'No password specified.'");
		CommonUseClientServer.MessageToUser(NString,, "WSPassword",, Cancel);
		Return Undefined;
	EndIf;
	
	SaveLongSynchronizationRequestFlag(Not NoLongSynchronizationPrompt);
EndFunction

&AtClient
Function Attachable_ConnectionCheckWait_LongActionProcessing(Cancel, GoToNext)
	
	TestConnection();
	
EndFunction

&AtServer
Procedure TestConnection()
	
	SetPrivilegedMode(True);
	
	AuthenticationParameters = ?(UseSavedAuthenticationParameters,
		Undefined,
		New Structure("UseCurrentUser, Password",
			UseCurrentUserForAuthentication, ?(SynchronizationPasswordSpecified, Undefined, WSPassword)));
	
	ConnectionParameters = InformationRegisters.ExchangeTransportSettings.TransportSettingsWS(InfobaseNode, AuthenticationParameters);
	
	If Not DataExchangeServer.CorrespondentConnectionEstablished(InfobaseNode, ConnectionParameters, UserErrorMessage) Then
		DataSynchronizationDisabled = True;
	EndIf;
	
	// Resetting password after connection test
	WSPassword = "";
EndProcedure

&AtClient
Function Attachable_DataImport_LongActionProcessing(Cancel, GoToNext)
	
	LongAction = False;
	LongActionFinished = False;
	MessageFileIDInService = "";
	LongActionID = "";
	
	HasVersionDifferenceError = False;
	
	If Not DataSynchronizationDisabled Then
		
		AuthenticationParameters = ?(UseSavedAuthenticationParameters, Undefined,
			New Structure("UseCurrentUser", UseCurrentUserForAuthentication)
		);
		
		DataImport_LongActionProcessing(
			Cancel,
			InfobaseNode,
			LongAction,
			LongActionID,
			MessageFileIDInService,
			ActionStartDate,
			AuthenticationParameters,
			CheckVersionDifference,
			VersionDifferenceErrorOnGetData
		);
		
		If VersionDifferenceErrorOnGetData.HasError Then
			HasVersionDifferenceError = True;
		EndIf;
		
	EndIf;
	
	If HasVersionDifferenceError Then
		Cancel = True;
		
	Else
		HasErrors = HasErrors OR Cancel;
		Cancel = False;
		
	EndIf;
	
EndFunction

&AtServerNoContext
Procedure DataImport_LongActionProcessing(
											Cancel,
											Val InfobaseNode,
											LongAction,
											ActionID,
											FileID,
											ActionStartDate,
											Val AuthenticationParameters,
											CheckVersionDifference,
											VersionDifferenceErrorOnGetData)
	
	ActionStartDate = CurrentSessionDate();
	
	DataExchangeServer.InitializeVersionDifferenceCheckParameters(CheckVersionDifference);
	
	// Starting data exchange
	DataExchangeServer.ExecuteDataExchangeForInfobaseNode(
											Cancel,
											InfobaseNode,
											True,
											False,
											Enums.ExchangeMessageTransportKinds.WS,
											LongAction,
											ActionID,
											FileID,
											True,
											AuthenticationParameters);
	
	VersionDifferenceErrorOnGetData = DataExchangeServer.VersionDifferenceErrorOnGetData();
	
EndProcedure

&AtClient
Function Attachable_DataImportLongAction_LongActionProcessing(Cancel, GoToNext)
	
	If LongAction Then
		
		GoToNext = False;
		
		AttachIdleHandler("LongActionIdleHandler", 5, True);
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_DataImportLongActionCompletion_LongActionProcessing(Cancel, GoToNext)
	
	If LongActionFinished Then
		
		If LongActionCompletedWithError Then
			
			DataExchangeServerCall.AddExchangeFinishedWithErrorEventLogMessage(
											InfobaseNode,
											"DataImport",
											ActionStartDate,
											ErrorMessage);
			
		Else
			
			AuthenticationParameters = ?(UseSavedAuthenticationParameters,
				Undefined,
				New Structure("UseCurrentUser", UseCurrentUserForAuthentication));
			
			DataExchangeServerCall.ExecuteDataExchangeForInfobaseNodeFinishLongAction(
											False,
											InfobaseNode,
											MessageFileIDInService,
											ActionStartDate,
											AuthenticationParameters);
			
		EndIf;
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_DataExport_LongActionProcessing(Cancel, GoToNext)
	
	LongAction = False;
	LongActionFinished = False;
	MessageFileIDInService = "";
	LongActionID = "";
	
	If Not DataSynchronizationDisabled Then
		
		AuthenticationParameters = ?(UseSavedAuthenticationParameters,
			Undefined,
			New Structure("UseCurrentUser", UseCurrentUserForAuthentication));
		
		DataExport_LongActionProcessing(
												Cancel,
												InfobaseNode,
												LongAction,
												LongActionID,
												MessageFileIDInService,
												ActionStartDate,
												AuthenticationParameters);
		
	EndIf;
	
	HasErrors = HasErrors Or Cancel;
	
	Cancel = False;
	
EndFunction

&AtServerNoContext
Procedure DataExport_LongActionProcessing(
											Cancel,
											Val InfobaseNode,
											LongAction,
											ActionID,
											FileID,
											ActionStartDate,
											Val AuthenticationParameters)
	
	ActionStartDate = CurrentSessionDate();
	
	// Starting data exchange
	DataExchangeServer.ExecuteDataExchangeForInfobaseNode(
											Cancel,
											InfobaseNode,
											False,
											True,
											Enums.ExchangeMessageTransportKinds.WS,
											LongAction,
											ActionID,
											FileID,
											True,
											AuthenticationParameters);
	
EndProcedure

&AtClient
Function Attachable_DataExportLongAction_LongActionProcessing(Cancel, GoToNext)
	
	If LongAction Then
		
		GoToNext = False;
		
		AttachIdleHandler("LongActionIdleHandler", 5, True);
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_DataExportLongActionCompletion_LongActionProcessing(Cancel, GoToNext)
	
	If LongActionFinished Then
		
		If LongActionCompletedWithError Then
			
			DataExchangeServerCall.AddExchangeFinishedWithErrorEventLogMessage(
											InfobaseNode,
											"DataExport",
											ActionStartDate,
											ErrorMessage);
			
		Else
			
			DataExchangeServerCall.CommitDataExportExecutionInLongActionMode(
											InfobaseNode,
											ActionStartDate);
			
		EndIf;
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_ExchangeCompletion_OnOpen(Cancel, SkipPage, IsGoNext)
	
	Items.ActionsPanel.CurrentPage = Items.ActionsClose;
	Items.FormClose.DefaultButton = True;
	
	ExchangeCompletedWithErrorPage = ?(IsInRoleAddEditDataExchanges,
				Items.ExchangeCompletedWithErrorForAdministrator,
				Items.ExchangeCompletedWithError);
	
	If DataSynchronizationDisabled Then
		
		Items.ExchangeCompletionStatus.CurrentPage = Items.ExchangeCompletedWithConnectionError;
		
	ElsIf HasErrors Then
		
		If UpdateRequired Or DataExchangeServerCall.InstallUpdateRequired() Then
			If IsInRoleFullAccess Then 
				Items.ActionsPanel.CurrentPage = Items.SetActionsClose;
				Items.InstallUpdate.DefaultButton = True;
			EndIf;
			Items.ExchangeCompletionStatus.CurrentPage = Items.UpdateRequired;
		Else
			Items.ExchangeCompletionStatus.CurrentPage = ExchangeCompletedWithErrorPage;
		EndIf;
		
	Else
		
		Items.ExchangeCompletionStatus.CurrentPage = Items.ExchangeCompletedSuccessfully;
		
	EndIf;
	
	// Updating all open dynamic lists
	DataExchangeClient.RefreshAllOpenDynamicLists();
	
EndFunction

&AtClient
Function Attachable_ExchangeCompletion_LongActionProcessing(Cancel, GoToNext)
	
	GoToNext = False;
	
	Notify("DataExchangeCompleted");
	
	If CloseOnSynchronizationDone
		And Not DataSynchronizationDisabled
		And Not HasErrors Then
		
		Close();
	EndIf;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// FILLING WIZARD NAVIGATION TABLE SECTION

&AtServer
Procedure DataExchangeScenarioNormal()
	
	GoToTable.Clear();
	
	GoToTableNewRow(1, "DataSynchronizationWait",,,,,, True, "OrdinaryDataImport_LongActionProcessing");
	GoToTableNewRow(2, "DataSynchronizationWait",,,,,, True, "OrdinaryDataExport_LongActionProcessing");
	GoToTableNewRow(3, "ExchangeCompletion",,, "ExchangeCompletion_OnOpen",,, True, "ExchangeCompletion_LongActionProcessing");
	
EndProcedure

&AtServer
Procedure ExchangeScenarioOverWebService()
	
	GoToTable.Clear();
	
	GoToTableNewRow(1, "DataSynchronizationWait",,,,,, True, "ConnectionCheckWait_LongActionProcessing");
	GoToTableNewRow(2, "DataSynchronizationWait",,,,,, True, "DataImport_LongActionProcessing");
	GoToTableNewRow(3, "DataSynchronizationWait",,,,,, True, "DataImportLongAction_LongActionProcessing");
	GoToTableNewRow(4, "DataSynchronizationWait",,,,,, True, "DataImportLongActionCompletion_LongActionProcessing");
	GoToTableNewRow(5, "DataSynchronizationWait",,,,,, True, "DataExport_LongActionProcessing");
	GoToTableNewRow(6, "DataSynchronizationWait",,,,,, True, "DataExportLongAction_LongActionProcessing");
	GoToTableNewRow(7, "DataSynchronizationWait",,,,,, True, "DataExportLongActionCompletion_LongActionProcessing");
	GoToTableNewRow(8, "ExchangeCompletion",,, "ExchangeCompletion_OnOpen",,, True, "ExchangeCompletion_LongActionProcessing");
	
EndProcedure

&AtServer
Procedure ExchangeScenarioOverWebService_SendingReceivingSending()
	
	GoToTable.Clear();
	
	GoToTableNewRow(1, "DataSynchronizationWait",,,,,, True, "ConnectionCheckWait_LongActionProcessing");
	
	// Sending
	GoToTableNewRow(2, "DataSynchronizationWait",,,,,, True, "DataExport_LongActionProcessing");
	GoToTableNewRow(3, "DataSynchronizationWait",,,,,, True, "DataExportLongAction_LongActionProcessing");
	GoToTableNewRow(4, "DataSynchronizationWait",,,,,, True, "DataExportLongActionCompletion_LongActionProcessing");
	
	// Receiving
	GoToTableNewRow(5, "DataSynchronizationWait",,,,,, True, "DataImport_LongActionProcessing");
	GoToTableNewRow(6, "DataSynchronizationWait",,,,,, True, "DataImportLongAction_LongActionProcessing");
	GoToTableNewRow(7, "DataSynchronizationWait",,,,,, True, "DataImportLongActionCompletion_LongActionProcessing");
	
	// Sending
	GoToTableNewRow(8,  "DataSynchronizationWait",,,,,, True, "DataExport_LongActionProcessing");
	GoToTableNewRow(9,  "DataSynchronizationWait",,,,,, True, "DataExportLongAction_LongActionProcessing");
	GoToTableNewRow(10, "DataSynchronizationWait",,,,,, True, "DataExportLongActionCompletion_LongActionProcessing");
	
	GoToTableNewRow(11, "ExchangeCompletion",,, "ExchangeCompletion_OnOpen",,, True, "ExchangeCompletion_LongActionProcessing");
	
EndProcedure

&AtServer
Procedure ExchangeScenarioOverWebServiceWithPasswordRequest()
	
	GoToTable.Clear();
	
	GoToTableNewRow(1, "UserPasswordRequest",,, "UserPasswordRequest_OnOpen", "UserPasswordRequest_OnGoNext");
	GoToTableNewRow(2, "DataSynchronizationWait",,,,,, True, "ConnectionCheckWait_LongActionProcessing");
	GoToTableNewRow(3, "DataSynchronizationWait",,,,,, True, "DataImport_LongActionProcessing");
	GoToTableNewRow(4, "DataSynchronizationWait",,,,,, True, "DataImportLongAction_LongActionProcessing");
	GoToTableNewRow(5, "DataSynchronizationWait",,,,,, True, "DataImportLongActionCompletion_LongActionProcessing");
	GoToTableNewRow(6, "DataSynchronizationWait",,,,,, True, "DataExport_LongActionProcessing");
	GoToTableNewRow(7, "DataSynchronizationWait",,,,,, True, "DataExportLongAction_LongActionProcessing");
	GoToTableNewRow(8, "DataSynchronizationWait",,,,,, True, "DataExportLongActionCompletion_LongActionProcessing");
	GoToTableNewRow(9, "ExchangeCompletion",,, "ExchangeCompletion_OnOpen",,, True, "ExchangeCompletion_LongActionProcessing");
	
EndProcedure

&AtServer
Procedure ExchangeScenarioOverWebServiceWithPasswordRequest_SendingReceivingSending()
	
	GoToTable.Clear();
	
	GoToTableNewRow(1, "UserPasswordRequest",,, "UserPasswordRequest_OnOpen", "UserPasswordRequest_OnGoNext");
	GoToTableNewRow(2, "DataSynchronizationWait",,,,,, True, "ConnectionCheckWait_LongActionProcessing");
	
	// Sending
	GoToTableNewRow(3, "DataSynchronizationWait",,,,,, True, "DataExport_LongActionProcessing");
	GoToTableNewRow(4, "DataSynchronizationWait",,,,,, True, "DataExportLongAction_LongActionProcessing");
	GoToTableNewRow(5, "DataSynchronizationWait",,,,,, True, "DataExportLongActionCompletion_LongActionProcessing");
	
	// Receiving
	GoToTableNewRow(6, "DataSynchronizationWait",,,,,, True, "DataImport_LongActionProcessing");
	GoToTableNewRow(7, "DataSynchronizationWait",,,,,, True, "DataImportLongAction_LongActionProcessing");
	GoToTableNewRow(8, "DataSynchronizationWait",,,,,, True, "DataImportLongActionCompletion_LongActionProcessing");
	
	// Sending
	GoToTableNewRow(9,  "DataSynchronizationWait",,,,,, True, "DataExport_LongActionProcessing");
	GoToTableNewRow(10, "DataSynchronizationWait",,,,,, True, "DataExportLongAction_LongActionProcessing");
	GoToTableNewRow(11, "DataSynchronizationWait",,,,,, True, "DataExportLongActionCompletion_LongActionProcessing");
	
	GoToTableNewRow(12, "ExchangeCompletion",,, "ExchangeCompletion_OnOpen",,, True, "ExchangeCompletion_LongActionProcessing");
	
EndProcedure

&AtServer
Procedure HasErrorsOnStartScenario()
	
	GoToTable.Clear();
	
	GoToTableNewRow(1, "ExchangeCompletion",,, "ExchangeCompletion_OnOpen");
	
EndProcedure

#EndRegion
