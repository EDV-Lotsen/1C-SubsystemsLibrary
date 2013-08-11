
////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetPrivilegedMode(True);
	
	// Skipping the initialization to guarantee that the form will be received if the SelfTest parameter is passed.
	If Parameters.Property("SelfTest") Then
		Return;
	EndIf;
	
	InfoBaseNode = Parameters.InfoBaseNode;
	
	If Not ValueIsFilled(InfoBaseNode) Then
		DataExchangeServer.ReportError(NStr("en = 'Form parameters are not specified. The form cannot be opened.'"), Cancel);
		Return;
	EndIf;
	
	// Check whether the subordinate distributed infobase setup was completed. 
	SubordinateDIBNodeSetupCompleted = True;
	
	If DataExchangeServer.IsSubordinateDIBNode() Then
		
		DIBExchangePlanName = ExchangePlans.MasterNode().Metadata().Name;
		ExchangePlanName = DataExchangeCached.GetExchangePlanName(InfoBaseNode);
		
		If ExchangePlanName = DIBExchangePlanName
			And Not Constants.SubordinateDIBNodeSetupCompleted.Get() Then
			
			SubordinateDIBNodeSetupCompleted = False;
			Return;
			
		EndIf;
		
	EndIf;
	
	// Specifying the form caption
	Title = NStr("en = 'Data exchange with %1.'");
	Title = StringFunctionsClientServer.SubstituteParametersInString(Title, String(InfoBaseNode));
	
	
	
	ExchangeMessageTransportKind = InformationRegisters.ExchangeTransportSettings.DefaultExchangeMessageTransportKind(InfoBaseNode);
	
	If ExchangeMessageTransportKind = Enums.ExchangeMessageTransportKinds.WS Then
		
		TransportSettingsWS = InformationRegisters.ExchangeTransportSettings.GetWSTransportSettings(InfoBaseNode);
		
		FillPropertyValues(ThisForm, TransportSettingsWS);
		
	EndIf;
	
	If ExchangeMessageTransportKind = Enums.ExchangeMessageTransportKinds.WS Then
		
		ExchangeScenarioOverWebService();
		
	Else
		
		DataExchangeScenarioNormal();
		
	EndIf;
	
	ExecutingDataExchange = True;
	HasErrors = False;
	
	IsInRoleAddEditDataExchanges = Users.RolesAvailable("AddEditDataExchanges");
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// Going to the first wizard step
	SetGoToNumber(1);
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	If ExecutingDataExchange Then
		Cancel = True;
		Return;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure GoToEventLog(Command)
	
	OpenFormModal("DataProcessor.EventLogMonitor.Form", GetEventLogFilterDataStructure(InfoBaseNode), ThisForm);
	
EndProcedure

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
	
	// Executing the step change event handlers
	ExecuteGoToEventHandlers(IsGoNext);
	
	// Setting page visibility
	GoToRowsCurrent = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber));
	
	If GoToRowsCurrent.Count() = 0 Then
		Raise NStr("en = 'The page to be displayed is not specified.'");
	EndIf;
	
	GoToRowCurrent = GoToRowsCurrent[0];
	
	Items.DataExchangeExecution.CurrentPage  = Items[GoToRowCurrent.MainPageName];
	
	If IsGoNext And GoToRowCurrent.LongAction Then
		
		AttachIdleHandler("ExecuteLongActionHandler", 0.1, True);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteGoToEventHandlers(Val IsGoNext)
	
	// Switching to the next page event handlers
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

// Adds a new string to the end of the current table of page switching.
//
// Parameters:

//  GoToNumber         – Number (mandatory) - serial number that corresponds to the
//                       current step.
//  MainPageName       – String (mandatory) - page name of MainPanel that corresponds to
//                       the current step switching number.
//  NavigationPageName – String (mandatory) -  page name of the NavigationPanel that
//                       corresponds to the current step switching number.
//  DecorationPageName – String (optional) - page name of the DecorationPanel that
//                       corresponds to the current step switching number.
//  OnOpenHandlerName  – String (optional) - current page OnOpen event handler name.
//  GoNextHandlerName  – String (optional) - current page GoNext event handler name.
//  GoBackHandlerName  – String (optional) - current page GoBack event handler name.
//  LongAction         - Boolean (optional) - flag that shows whether the long action 
//                       page will be displayed. Pass True to display the long action
//                       page or pass False to display the ordinary page. The default 
//                       value is False.
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
									LongActionHandlerName = ""
	)
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
//  OVERRIDABLE PART
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS

&AtClient
Procedure LongActionIdleHandler()
	
	LongActionCompletedWithError = False;
	ErrorMessage = "";
	
	ActionState = DataExchangeServer.LongActionState(LongActionID,
																		WSURL,
																		WSUserName,
																		WSPassword,
																		ErrorMessage
	);
	
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
Function GetEventLogFilterDataStructure(InfoBaseNode)
	
	SelectedEvents = New Array;
	SelectedEvents.Add(DataExchangeServer.GetEventLogMessageKey(InfoBaseNode, Enums.ActionsOnExchange.DataImport));
	SelectedEvents.Add(DataExchangeServer.GetEventLogMessageKey(InfoBaseNode, Enums.ActionsOnExchange.DataExport));
	
	DataExchangeStatesImport = InformationRegisters.DataExchangeStates.DataExchangeStates(InfoBaseNode, Enums.ActionsOnExchange.DataImport);
	DataExchangeStatesExport = InformationRegisters.DataExchangeStates.DataExchangeStates(InfoBaseNode, Enums.ActionsOnExchange.DataExport);
	
	Result = New Structure;
	Result.Insert("EventLogMessageText", SelectedEvents);
	Result.Insert("StartDate",    min(DataExchangeStatesImport.StartDate, DataExchangeStatesExport.StartDate));
	Result.Insert("EndDate", Max(DataExchangeStatesImport.EndDate, DataExchangeStatesExport.EndDate));
	
	Return Result;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// STEP SWITCHING EVENT HANDLER SECTION

// Procedures and functions that provide the exchange via ordinary connection channels.

&AtClient
Function Attachable_OrdinaryDataImport_LongActionProcessing(Cancel, GoToNext)
	
	OrdinaryDataImport_LongActionProcessing(Cancel, InfoBaseNode, ExchangeMessageTransportKind);
	
	HasErrors = HasErrors Or Cancel;
	
	Cancel = False; 
	
EndFunction

&AtServerNoContext
Procedure OrdinaryDataImport_LongActionProcessing(Cancel, InfoBaseNode, ExchangeMessageTransportKind)
	
	// Starting the exchange
	DataExchangeServer.ExecuteDataExchangeForInfoBaseNode(
											Cancel,
											InfoBaseNode,
											True,
											False,
											ExchangeMessageTransportKind
	);
	
EndProcedure

&AtClient
Function Attachable_OrdinaryDataExport_LongActionProcessing(Cancel, GoToNext)
	
	OrdinaryDataExport_LongActionProcessing(Cancel, InfoBaseNode, ExchangeMessageTransportKind);
	
	HasErrors = HasErrors Or Cancel;
	
	Cancel = False;
	
EndFunction

&AtServerNoContext
Procedure OrdinaryDataExport_LongActionProcessing(Cancel, InfoBaseNode, ExchangeMessageTransportKind)
	
	// Starting the exchange
	DataExchangeServer.ExecuteDataExchangeForInfoBaseNode(
											Cancel,
											InfoBaseNode,
											False,
											True,
											ExchangeMessageTransportKind
	);
	
EndProcedure

// Exchange via the web service.

&AtClient
Function Attachable_DataImport_LongActionProcessing(Cancel, GoToNext)
	
	LongAction = False;
	LongActionFinished = False;
	MessageFileIDInService = "";
	LongActionID = "";
	
	DataImport_LongActionProcessing(
											Cancel,
											InfoBaseNode,
											LongAction,
											LongActionID,
											MessageFileIDInService,
											ActionStartDate
	);
	
	HasErrors = HasErrors Or Cancel;
	
	Cancel = False;
	
EndFunction

&AtServerNoContext
Procedure DataImport_LongActionProcessing(
											Cancel,
											InfoBaseNode,
											LongAction,
											ActionID,
											FileID,
											ActionStartDate
	)
	
	ActionStartDate = CurrentSessionDate();
	
	// Starting the exchange
	DataExchangeServer.ExecuteDataExchangeForInfoBaseNode(
											Cancel,
											InfoBaseNode,
											True,
											False,
											Enums.ExchangeMessageTransportKinds.WS,
											LongAction,
											ActionID,
											FileID,
											True
	);
	
EndProcedure

&AtClient
Function Attachable_DataImportLongAction_LongActionProcessing(Cancel, GoToNext)
	
	If LongAction Then
		
		GoToNext = False;
		
		AttachIdleHandler("LongActionIdleHandler", 5, True);
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_DataImportLongActionFinish_LongActionProcessing(Cancel, GoToNext)
	
	If LongActionFinished Then
		
		If LongActionCompletedWithError Then
			
			DataExchangeServer.AddExchangeFinishedWithErrorEventLogMessage(
											InfoBaseNode,
											"DataImport",
											ActionStartDate,
											ErrorMessage
			);
			
		Else
			
			DataExchangeServer.ExecuteDataExchangeForInfoBaseNodeFinishLongAction(
											False,
											InfoBaseNode,
											MessageFileIDInService,
											ActionStartDate
			);
			
		EndIf;
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_DataExport_LongActionProcessing(Cancel, GoToNext)
	
	LongAction = False;
	LongActionFinished = False;
	MessageFileIDInService = "";
	LongActionID = "";
	
	DataExport_LongActionProcessing(
											Cancel,
											InfoBaseNode,
											LongAction,
											LongActionID,
											MessageFileIDInService,
											ActionStartDate
	);
	
	HasErrors = HasErrors Or Cancel;
	
	Cancel = False;
	
EndFunction

&AtServerNoContext
Procedure DataExport_LongActionProcessing(
											Cancel,
											InfoBaseNode,
											LongAction,
											ActionID,
											FileID,
											ActionStartDate
	)
	
	ActionStartDate = CurrentSessionDate();
	
	// Starting the exchange
	DataExchangeServer.ExecuteDataExchangeForInfoBaseNode(
											Cancel,
											InfoBaseNode,
											False,
											True,
											Enums.ExchangeMessageTransportKinds.WS,
											LongAction,
											ActionID,
											FileID,
											True
	);
	
EndProcedure

&AtClient
Function Attachable_DataExportLongAction_LongActionProcessing(Cancel, GoToNext)
	
	If LongAction Then
		
		GoToNext = False;
		
		AttachIdleHandler("LongActionIdleHandler", 5, True);
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_DataExportLongActionFinish_LongActionProcessing(Cancel, GoToNext)
	
	If LongActionFinished Then
		
		If LongActionCompletedWithError Then
			
			DataExchangeServer.AddExchangeFinishedWithErrorEventLogMessage(
											InfoBaseNode,
											"DataExport",
											ActionStartDate,
											ErrorMessage
			);
			
		Else
			
			DataExchangeServer.CommitDataExportExecutionInLongActionMode(
											InfoBaseNode,
											ActionStartDate
			);
			
		EndIf;
		
	EndIf;
	
EndFunction



&AtClient
Function Attachable_ExchangeEnd_OnOpen(Cancel, SkipPage, IsGoNext)
	
	ExchangeCompletedWithErrorPage = ?(IsInRoleAddEditDataExchanges,
				Items.ExchangeCompletedWithErrorForAdministrator,
				Items.ExchangeCompletedWithError
	);
	
	Items.ExchangeCompletionState.CurrentPage = ?(HasErrors,
										ExchangeCompletedWithErrorPage,
										Items.ExchangeCompletedSuccessfully
	);
	
	// Updating all open dynamic lists
	DataExchangeClient.RefreshAllOpenDynamicLists();
	
EndFunction

&AtClient
Function Attachable_ExchangeEnd_LongActionProcessing(Cancel, GoToNext)
	
	GoToNext = False;
	ExecutingDataExchange = False;
	
	Notify("DataExchangeCompleted");
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// STEP SWITCHING INITIALIZE SECTION

&AtServer
Procedure DataExchangeScenarioNormal()
	
	GoToTable.Clear();
	
	GoToTableNewRow(1, "DataImport",,,,,, True, "OrdinaryDataImport_LongActionProcessing");
	GoToTableNewRow(2, "DataExport",,,,,, True, "OrdinaryDataExport_LongActionProcessing");
	GoToTableNewRow(3, "ExchangeEnd",,, "ExchangeEnd_OnOpen",,, True, "ExchangeEnd_LongActionProcessing");
	
EndProcedure

&AtServer
Procedure ExchangeScenarioOverWebService()
	
	GoToTable.Clear();
	
	GoToTableNewRow(1, "DataImport",,,,,, True, "DataImport_LongActionProcessing");
	GoToTableNewRow(2, "DataImport",,,,,, True, "DataImportLongAction_LongOperationProcessing");
	GoToTableNewRow(3, "DataImport",,,,,, True, "DataImportLongActionFinish_LongActionProcessing");
	GoToTableNewRow(4, "DataExport",,,,,, True, "DataExport_LongActionProcessing");
	GoToTableNewRow(5, "DataExport",,,,,, True, "DataExportLongAction_LongOperationProcessing");
	GoToTableNewRow(6, "DataExport",,,,,, True, "DataExportLongActionFinish_LongActionProcessing");
	GoToTableNewRow(7, "ExchangeEnd",,, "ExchangeEnd_OnOpen",,, True, "ExchangeEnd_LongActionProcessing");
	
EndProcedure
