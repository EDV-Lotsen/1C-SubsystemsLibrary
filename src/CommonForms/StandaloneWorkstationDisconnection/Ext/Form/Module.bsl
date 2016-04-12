
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
  // Skipping the initialization to guarantee that the form will be
  // received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then
		Return;
	EndIf;
	
	StandaloneWorkstation = Parameters.StandaloneWorkstation;
	
	If Not ValueIsFilled(StandaloneWorkstation) Then
		Raise NStr("en = 'Standalone workstation is not specified.'");
	EndIf;
	
	StandaloneWorkstationDeletionEventLogMessageText = StandaloneModeInternal.StandaloneWorkstationDeletionEventLogMessageText();
	
	SetMainScenario();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// Selecting the first wizard step
	SetGoToNumber(1);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure StopDataSynchronization(Command)
	
	GoToNext();
	
EndProcedure

&AtClient
Procedure Cancel(Command)
	
	Close();
	
EndProcedure

&AtClient
Procedure CloseForm(Command)
	
	Close();
	
EndProcedure

// Idle handlers

&AtClient
Procedure LongActionIdleHandler()
	
	Try
		
		If JobCompleted(JobID) Then
			
			LongAction = False;
			LongActionFinished = True;
			GoToNext();
			
		Else
			
			LongActionsClient.UpdateIdleHandlerParameters(IdleHandlerParameters);
			AttachIdleHandler("LongActionIdleHandler", IdleHandlerParameters.CurrentInterval, True);
			
		EndIf;
		
	Except
		
		WriteErrorToEventLog(
			DetailErrorDescription(ErrorInfo()), StandaloneWorkstationDeletionEventLogMessageText);
		
		LongAction = False;
		GoBack();
		ShowMessageBox(,NStr("en = 'Errors occurred when processing.'"));
		
	EndTry;
	
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
	
	If Not IsBlankString(GoToRowCurrent.DecorationPageName) Then
		
		Items.DecorationPanel.CurrentPage = Items[GoToRowCurrent.DecorationPageName];
		
	EndIf;
	
	// Setting the default button
	NextButton = GetFormButtonByCommandName(Items.NavigationPanel.CurrentPage, "StopDataSynchronization");
	
	If NextButton <> Undefined Then
		
		NextButton.DefaultButton = True;
		
	Else
		
		DoneButton = GetFormButtonByCommandName(Items.NavigationPanel.CurrentPage, "Close");
		
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
//  LongAction (optional)          - Boolean - flag that shows whether a long 
//                                   action execution page is displayed. 
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

&AtClient
Procedure GoToNext()
	
	ChangeGoToNumber(+1);
	
EndProcedure

&AtClient
Procedure GoBack()
	
	ChangeGoToNumber(-1);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Overridable part: Internal procedures and functions

&AtServer
Procedure DeleteStandaloneWorkstation(Cancel)
	
	If CommonUse.FileInfobase() Then
		
		Try
			StandaloneModeInternal.DeleteStandaloneWorkstation(New Structure("StandaloneWorkstation", StandaloneWorkstation), "");
		Except
			Cancel = True;
			WriteErrorToEventLog(DetailErrorDescription(ErrorInfo()),
				StandaloneWorkstationDeletionEventLogMessageText);
		EndTry;
		
	Else
		
		Result = LongActions.ExecuteInBackground(
						UUID,
						"StandaloneModeInternal.DeleteStandaloneWorkstation",
						New Structure("StandaloneWorkstation", StandaloneWorkstation),
						NStr("en = 'Deleting standalone workstation'"));
		
		If Not Result.JobCompleted Then
			
			LongAction = True;
			JobID = Result.JobID;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure WriteErrorToEventLog(ErrorMessageString, Event)
	
	WriteLogEvent(Event, EventLogLevel.Error,,, ErrorMessageString);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Overridable part: Step change handlers

&AtClient
Function Attachable_Wait_LongActionProcessing(Cancel, GoToNext)
	
	LongAction = False;
	LongActionFinished = False;
	JobID = Undefined;
	
	DeleteStandaloneWorkstation(Cancel);
	
	If Cancel Then
		
		ShowMessageBox(, NStr("en = Cannot delete the standalone workstation.'"));
		
	ElsIf Not LongAction Then
		
		Notify("Delete_StandaloneWorkstation");
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_LongActionWait_LongActionProcessing(Cancel, GoToNext)
	
	If LongAction Then
		
		GoToNext = False;
		
		LongActionsClient.InitIdleHandlerParameters(IdleHandlerParameters);
		
		AttachIdleHandler("LongActionIdleHandler", IdleHandlerParameters.CurrentInterval, True);
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_LongActionWaitCompletion_LongActionProcessing(Cancel, GoToNext)
	
	If LongActionFinished Then
		
		Notify("Delete_StandaloneWorkstation");
		
	EndIf;
	
EndFunction

&AtServerNoContext
Function JobCompleted(JobID)
	
	Return LongActions.JobCompleted(JobID);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Overridable part: Filling wizard navigation table

&AtServer
Procedure SetMainScenario()
	
	GoToTable.Clear();
	
	GoToTableNewRow(1, "Beginning",     "NavigationPageStart");
	GoToTableNewRow(2, "Waiting",   "NavigationPageWait",,,,, True, "Wait_LongActionProcessing");
	GoToTableNewRow(3, "Waiting",   "NavigationPageWait",,,,, True, "LongActionWait_LongActionProcessing");
	GoToTableNewRow(4, "Waiting",   "NavigationPageWait",,,,, True, "LongActionWaitCompletion_LongActionProcessing");
	GoToTableNewRow(5, "End", "NavigationPageEnd");
	
EndProcedure

#EndRegion
