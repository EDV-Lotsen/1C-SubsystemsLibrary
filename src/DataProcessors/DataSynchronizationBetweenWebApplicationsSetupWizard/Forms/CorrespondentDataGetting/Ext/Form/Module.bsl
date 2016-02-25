#Region FormEventHandlers

// Overridable part

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
  // Skipping the initialization to guarantee that the form will be 
  // received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then
		Return;
	EndIf;
	
	// Only users with administrative rights can get subscriber correspondent data.
	DataExchangeServer.CheckExchangeManagementRights();
	
	SetPrivilegedMode(True);
	
	ExchangePlanName       = Parameters.ExchangePlanName;
	CorrespondentDataArea  = Parameters.CorrespondentDataArea;
	CorrespondentTables    = Parameters.CorrespondentTables;
	Mode                   = Parameters.Mode;
	OwnerUUID              = Parameters.OwnerUUID;
	
	EventLogMessageTextDataSynchronizationSetup = DataExchangeSaaS.EventLogMessageTextDataSynchronizationSetup();
	
	// Filling the navigation table
	CorrespondentDataGettingScenario();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// Selecting the first wizard step
	SetGoToNumber(1);
	
EndProcedure

// Idle handlers

&AtClient
Procedure LongActionIdleHandler()
	
	Try
		SessionStatus = SessionStatus(Session);
	Except
		WriteErrorToEventLog(
			DetailErrorDescription(ErrorInfo()), EventLogMessageTextDataSynchronizationSetup);
		CancelAction();
		Return;
	EndTry;
	
	If SessionStatus = "Done" Then
		
		GoToNext();
		
	ElsIf SessionStatus = "Error" Then
		
		CancelAction();
		Return;
		
	Else
		
		AttachIdleHandler("LongActionIdleHandler", 5, True);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure CancelCommand(Command)
	
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
		
		ProcedureName = "Attachable_[HandleName](Cancel, SkipPage, IsGoNext)";
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
		
		ProcedureName = "Attachable_[HandleName](Cancel, GoToNext)";
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
//  GoBackHandlerName (optional)   - String - name of the "go to previous wizard page" 
//                                   event handler.
//  LongAction (optional)          - Boolean - flag that shows whether a long action execution page 
//                                   is displayed. 
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

&AtServerNoContext
Function SessionStatus(Val Session)
	
	SetPrivilegedMode(True);
	
	Return InformationRegisters.SystemMessageExchangeSessions.SessionStatus(Session);
	
EndFunction

&AtServerNoContext
Procedure WriteErrorToEventLog(ErrorMessageString, Event)
	
	WriteLogEvent(Event, EventLogLevel.Error,,, ErrorMessageString);
	
EndProcedure

&AtClient
Procedure CancelAction()
	
	ShowMessageBox(, NStr("en = 'Cannot execute the operation.'"));
	Close();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Overridable part: Step change handlers

&AtClient
Function Attachable_DataGettingWait_LongActionProcessing(Cancel, GoToNext)
	
	DataGettingWait_LongActionProcessing(Cancel);
	
	If Cancel Then
		Cancel = False;
		CancelAction();
	EndIf;
	
EndFunction

&AtServer
Procedure DataGettingWait_LongActionProcessing(Cancel)
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		
		If Mode = "GetCorrespondentData" Then
			
			// Sending message to a correspondent
			Message = MessagesSaaS.NewMessage(
				DataExchangeMessagesManagementInterface.GetCorrespondentDataMessage());
			Message.Body.CorrespondentZone = CorrespondentDataArea;
			Message.Body.Tables = XDTOSerializer.WriteXDTO(CorrespondentTables);
			Message.Body.ExchangePlan = ExchangePlanName;
			Session = DataExchangeSaaS.SendMessage(Message);
			
		ElsIf Mode = "GetCorrespondentNodeCommonData" Then
			
			// Sending message to a correspondent
			Message = MessagesSaaS.NewMessage(
				DataExchangeMessagesManagementInterface.GetCorrespondentNodeCommonDataMessage());
			Message.Body.CorrespondentZone = CorrespondentDataArea;
			Message.Body.ExchangePlan = ExchangePlanName;
			Session = DataExchangeSaaS.SendMessage(Message);
			
		Else
			
			Raise NStr("en = 'Unknown mode of getting correspondent data.'");
			
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteErrorToEventLog(DetailErrorDescription(ErrorInfo()),
			EventLogMessageTextDataSynchronizationSetup);
		Cancel = True;
		Return;
	EndTry;
	
	MessagesSaaS.DeliverQuickMessages();
	
EndProcedure

&AtClient
Function Attachable_DataGettingWaitLongAction_LongActionProcessing(Cancel, GoToNext)
	
	GoToNext = False;
	
	AttachIdleHandler("LongActionIdleHandler", 5, True);
	
EndFunction

&AtClient
Function Attachable_DataGettingWaitLongActionCompletion_LongActionProcessing(Cancel, GoToNext)
	
	GoToNext = False;
	
	DataGettingWaitLongActionCompletion_LongActionProcessing(Cancel);
	
	If Cancel Then
		CancelAction();
		Return Undefined;
	EndIf;
	
	Close();
	
	If Mode = "GetCorrespondentData" Then
		
		Notify("CorrespondentDataReceived", TempStorageAddress);
		
	ElsIf Mode = "GetCorrespondentNodeCommonData" Then
		
		Notify("CorrespondentNodeCommonDataReceived", TempStorageAddress);
		
	EndIf;
	
EndFunction

&AtServer
Procedure DataGettingWaitLongActionCompletion_LongActionProcessing(Cancel)
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		
		CorrespondentData = InformationRegisters.SystemMessageExchangeSessions.GetSessionData(Session);
		
		TempStorageAddress = PutToTempStorage(CorrespondentData, OwnerUUID);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteErrorToEventLog(DetailErrorDescription(ErrorInfo()),
			EventLogMessageTextDataSynchronizationSetup);
		Cancel = True;
		Return;
	EndTry;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Overridable part: Filling wizard navigation table

&AtServer
Procedure CorrespondentDataGettingScenario()
	
	GoToTable.Clear();
	
	GoToTableNewRow(1, "DataGettingWait", "NavigationPageCancel",,,,, True, "DataGettingWait_LongActionProcessing");
	GoToTableNewRow(2, "DataGettingWait", "NavigationPageCancel",,,,, True, "DataGettingWaitLongAction_LongActionProcessing");
	GoToTableNewRow(3, "DataGettingWait", "NavigationPageCancel",,,,, True, "DataGettingWaitLongActionCompletion_LongActionProcessing");
	
EndProcedure

#EndRegion
