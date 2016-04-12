#Region FormEventHandlers

// Overridable part

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
 
  // Skipping the initialization to guarantee that the form will be
  // received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then
		Return;
	EndIf;
	
	// Only users with administrative rights can disable data synchronization for subscribers.
	DataExchangeServer.CheckExchangeManagementRights();
	
	SetPrivilegedMode(True);
	
	ExchangePlanName              = Parameters.ExchangePlanName;
	CorrespondentDataArea = Parameters.CorrespondentDataArea;
	
	EventLogMessageTextDataSynchronizationSetup = DataExchangeSaaS.EventLogMessageTextDataSynchronizationSetup();
	
	Items.WarningLabel.Title = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = 'Disable data synchronization
			|with %1?'"), Parameters.CorrespondentDescription);
	
	Items.InfoLabel.Title = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = 'Data synchronization
			|with %1 is disabled.'"), Parameters.CorrespondentDescription);
	
	// Filling the navigation table
	DataSynchronizationDisablingScenario();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// Selecting the first wizard step
	SetGoToNumber(1);
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	If GoToNumber > 1
		And GoToNumber < 5 Then
		
		Notify("Disable_DataSynchronization");
		
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

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure DisableDataSynchronization(Command)
	
	GoToNext();
	
EndProcedure

&AtClient
Procedure CancelCommand(Command)
	
	Close();
	
EndProcedure

&AtClient
Procedure CloseCommand(Command)
	
	Close();
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

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
	
	Items.MainPanel.CurrentPage  = Items[GoToRowCurrent.MainPageName];
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

// The procedure adds a row to the end of the current navigation table.
//
// Parameters:
//
//  GoToNumber (mandatory)         - Number - current step number.
//  MainPageName (mandatory)       - String - name of the "MainPanel" panel page 
//                                   that matches the current step number.
//  NavigationPageName (mandatory) - String - name of the "NavigationPanel" panel page 
//                                   that matches the current step number.
//  DecorationPageName (optional)  - String - name of the "DecorationPanel" panel page 
//                                   that matches the current step number.
//  OnOpenHandlerName (optional)   - String - name of the "open current wizard page" event handler. 
//  GoNextHandlerName (optional)   - String - name of the "go to next wizard page" event handler. 
//  GoBackHandlerName (optional)   - String - name of the "go to previous wizard page" event handler.
//  LongAction (optional)          - Boolean - flag that shows whether a long action execution page is displayed. 
//                                   If True, a long action execution page is displayed. 
//                                   If False, a standard page is displayed. 
//                                   The default value is False.
// 
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
	
	NewRow.GoNextHandlerName  = GoNextHandlerName;
	NewRow.GoBackHandlerName  = GoBackHandlerName;
	NewRow.OnOpenHandlerName  = OnOpenHandlerName;
	
	NewRow.LongAction            = LongAction;
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
// Overridable part: Internal procedures and functions

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
Procedure WriteErrorToEventLog(ErrorMessageString, Event)
	
	WriteLogEvent(Event, EventLogLevel.Error,,, ErrorMessageString);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Overridable part: Step change handlers

// Page 2 (waiting)
//
&AtClient
Function Attachable_SynchronizationDisablingWait_LongActionProcessing(Cancel, GoToNext)
	
	RequestSynchronizationDisabling(Cancel);
	
	If Cancel Then
		ShowMessageBox(, NStr("en = 'Cannot execute the operation.'"));
	EndIf;
	
EndFunction

// Page 2 (waiting)
//
&AtClient
Function Attachable_SynchronizationDisablingWaitLongAction_LongActionProcessing(Cancel, GoToNext)
	
	GoToNext = False;
	
	AttachIdleHandler("LongActionIdleHandler", 5, True);
	
EndFunction

// Page 2 (waiting)
//
&AtClient
Function Attachable_SynchronizationDisablingWaitLongActionCompletion_LongActionProcessing(Cancel, GoToNext)
	
	Notify("Disable_DataSynchronization");
	
	Items.CloseCommand.DefaultButton = True;
	
EndFunction

&AtServer
Procedure RequestSynchronizationDisabling(Cancel)
	
	If Not DataExchangeSaaS.DeleteExchangeSettings(ExchangePlanName, CorrespondentDataArea, Session) Then
		Cancel = True;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Overridable part: Filling wizard navigation table

&AtServer
Procedure DataSynchronizationDisablingScenario()
	
	GoToTable.Clear();
	
	GoToTableNewRow(1, "Beginning",                          "NavigationPageStart");
	GoToTableNewRow(2, "SynchronizationDisablingWait", "NavigationPageWait",,,,, True, "SynchronizationDisablingWait_LongActionProcessing");
	GoToTableNewRow(3, "SynchronizationDisablingWait", "NavigationPageWait",,,,, True, "SynchronizationDisablingWaitLongAction_LongActionProcessing");
	GoToTableNewRow(4, "SynchronizationDisablingWait", "NavigationPageWait",,,,, True, "SynchronizationDisablingWaitLongActionCompletion_LongActionProcessing");
	GoToTableNewRow(5, "End",                       "NavigationPageEnd");
	
EndProcedure

#EndRegion