
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
 
	// Skipping the initialization to guarantee that the form
  // will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then
		Return;
	EndIf;
	
	WarnOnFormClose = True;
	
	// Checking whether the form is opened from 1C:Enterprise script
	If Not Parameters.Property("ExchangeMessageFileName") Then
		
		NString = NStr("en = 'The form cannot be opened interactively.'");
		CommonUseClientServer.MessageToUser(NString,,,, Cancel);
		Return;
		
	EndIf;
	
	// Initializing the data processor with the passed parameters
	FillPropertyValues(Object, Parameters,, "UsedFieldList, TableFieldList");
	
	MaxCustomFieldCount                       = Parameters.MaxCustomFieldCount;
	UnapprovedMappingTableTempStorageAddress = Parameters.UnapprovedMappingTableTempStorageAddress;
	UsedFieldList    = Parameters.UsedFieldList;
	TableFieldList   = Parameters.TableFieldList;
	MappingFieldList = Parameters.MappingFieldList;
	
	// Setting the form title
	Title = Parameters.Title;
	
	AutomaticObjectMappingScenario();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	GoToNumber = 0;
	
	// Selecting the second wizard step
	SetGoToNumber(2);
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	If  Object.AutomaticallyMappedObjectTable.Count() > 0
		And WarnOnFormClose = True Then
			
		ShowMessageBox(, NStr("en = 'The form contains data to be used in automatic object mapping. Action canceled.'"));
		
		Cancel = True;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Apply(Command)
	
	WarnOnFormClose = False;
	
	// Context server call
	NotifyChoice(PutAutomaticallyMappedObjectTableIntoTempStorage());
	
EndProcedure

&AtClient
Procedure Cancel(Command)
	
	WarnOnFormClose = False;
	
	NotifyChoice(Undefined);
	
EndProcedure

&AtClient
Procedure ClearAllMarks(Command)
	
	SetAllMarksAtServer(False);
	
EndProcedure

&AtClient
Procedure SetAllMarks(Command)
	
	SetAllMarksAtServer(True);
	
EndProcedure

&AtClient
Procedure CloseForm(Command)
	
	WarnOnFormClose = False;
	
	NotifyChoice(Undefined);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS (supplied part)

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
	
	NewRow.LongAction            = LongAction;
	NewRow.LongActionHandlerName = LongActionHandlerName;
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Function PutAutomaticallyMappedObjectTableIntoTempStorage()
	
	Return PutToTempStorage(Object.AutomaticallyMappedObjectTable.Unload(New Structure("Mark", True), "SourceUUID, TargetUUID, TargetType, SourceType"));
	
EndFunction

&AtServer
Procedure SetTableFieldVisible(Val FormTableName, Val MaxCustomFieldCount)
	
	SourceFieldName = StrReplace("#FormTableName#SourceFieldNN","#FormTableName#", FormTableName);
	TargetFieldName = StrReplace("#FormTableName#TargetFieldNN","#FormTableName#", FormTableName);
	
	// Making all mapping table fields invisible
	For FieldNumber = 1 To MaxCustomFieldCount Do
		
		SourceField = StrReplace(SourceFieldName, "NN", String(FieldNumber));
		TargetField = StrReplace(TargetFieldName, "NN", String(FieldNumber));
		
		Items[SourceField].Visible = False;
		Items[TargetField].Visible = False;
		
	EndDo;
	
	// Making all mapping table fields that are selected by user visible 
	For Each Item In Object.UsedFieldList Do
		
		FieldNumber = Object.UsedFieldList.IndexOf(Item) + 1;
		
		SourceField = StrReplace(SourceFieldName, "NN", String(FieldNumber));
		TargetField = StrReplace(TargetFieldName, "NN", String(FieldNumber));
		
		// Setting field visibility
		Items[SourceField].Visible = Item.Check;
		Items[TargetField].Visible = Item.Check;
		
		// Setting field titles
		Items[SourceField].Title = Item.Presentation;
		Items[TargetField].Title = Item.Presentation;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure SetAllMarksAtServer(Check)
	
	ValueTable = Object.AutomaticallyMappedObjectTable.Unload();
	
	ValueTable.FillValues(Check, "Mark");
	
	Object.AutomaticallyMappedObjectTable.Load(ValueTable);
	
EndProcedure

&AtClient
Procedure GoToNext()
	
	ChangeGoToNumber(+1);
	
EndProcedure

&AtClient
Procedure GoBack()
	
	ChangeGoToNumber(-1);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Idle handlers

&AtClient
Procedure BackgroundJobIdleHandler()
	
	LongActionFinished = False;
	
	State = DataExchangeServerCall.JobState(JobID);
	
	If State = "Active" Then
		
		AttachIdleHandler("BackgroundJobIdleHandler", 5, True);
		
	ElsIf State = "Completed" Then
		
		LongAction = False;
		LongActionFinished = True;
		
		GoToNext();
		
	Else // Failed
		
		LongAction = False;
		
		GoBack();
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Step change handlers

// Page 0: Automatic object mapping error
//
&AtClient
Function Attachable_ObjectMappingError_OnOpen(Cancel, SkipPage, IsGoNext)
	
	Items.Close1.DefaultButton = True;
	
EndFunction

// Page 1 (waiting): Object mapping
//
&AtClient
Function Attachable_ObjectMappingWait_LongActionProcessing(Cancel, GoToNext)
	
	ExecuteObjectMapping(Cancel);
	
EndFunction

// Page 1 (waiting): Object mapping
//
&AtClient
Function Attachable_ObjectMappingWaitLongAction_LongActionProcessing(Cancel, GoToNext)
	
	If LongAction Then
		
		GoToNext = False;
		
		AttachIdleHandler("BackgroundJobIdleHandler", 5, True);
		
	EndIf;
	
EndFunction

// Page 1 (waiting): Object mapping
//
&AtClient
Function Attachable_ObjectMappingWaitLongActionCompletion_LongActionProcessing(Cancel, GoToNext)
	
	If LongActionFinished Then
		
		ExecuteObjectMappingCompletion(Cancel);
		
	EndIf;
	
EndFunction

// Page 1: Object mapping
//
&AtServer
Procedure ExecuteObjectMapping(Cancel)
	
	LongAction = False;
	LongActionFinished = False;
	JobID = Undefined;
	TempStorageAddress = "";
	
	Try
		
		FormAttributes = New Structure;
		FormAttributes.Insert("UsedFieldList",    UsedFieldList);
		FormAttributes.Insert("TableFieldList",   TableFieldList);
		FormAttributes.Insert("MappingFieldList", MappingFieldList);
		
		MethodParameters = New Structure;
		MethodParameters.Insert("ObjectContext", DataExchangeServer.GetObjectContext(FormAttributeToValue("Object")));
		MethodParameters.Insert("FormAttributes", FormAttributes);
		MethodParameters.Insert("UnapprovedMappingTable", GetFromTempStorage(UnapprovedMappingTableTempStorageAddress));
		
		If CommonUse.FileInfobase() Then
			
			MappingResult = DataProcessors.InfobaseObjectMapping.AutomaticObjectMappingResult(MethodParameters);
			AfterObjectMapping(MappingResult);
			
		Else
			
			Result = LongActions.ExecuteInBackground(
				UUID,
				"DataProcessors.InfobaseObjectMapping.ExecuteAutomaticObjectMapping",
				MethodParameters,
				NStr("en = 'Automatic object mapping'")
			);
			
			If Result.JobCompleted Then
				
				AfterObjectMapping(GetFromTempStorage(Result.StorageAddress));
				
			Else
				
				LongAction = True;
				JobID = Result.JobID;
				TempStorageAddress = Result.StorageAddress;
				
			EndIf;
			
		EndIf;
		
	Except
		Cancel = True;
		WriteLogEvent(NStr("en = 'Object mapping wizard.Automatic object mapping'", CommonUseClientServer.DefaultLanguageCode()),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo())
		);
		Return;
	EndTry;
	
EndProcedure

// Page 1: Object mapping
//
&AtServer
Procedure ExecuteObjectMappingCompletion(Cancel)
	
	Try
		AfterObjectMapping(GetFromTempStorage(TempStorageAddress));
	Except
		Cancel = True;
		WriteLogEvent(NStr("en = 'Object mapping wizard.Automatic object mapping'", CommonUseClientServer.DefaultLanguageCode()),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo())
		);
		Return;
	EndTry;
	
EndProcedure

// Page 1: Object mapping
//
&AtServer
Procedure AfterObjectMapping(Val MappingResult)
	
	DataProcessorObject = DataProcessors.InfobaseObjectMapping.Create();
	DataExchangeServer.ImportObjectContext(MappingResult.ObjectContext, DataProcessorObject);
	ValueToFormAttribute(DataProcessorObject, "Object");
	
	EmptyResult = MappingResult.EmptyResult;
	
	If Not EmptyResult Then
		
		Modified = True;
		
		// Setting titles and table field visibility on the form
		SetTableFieldVisible("AutomaticallyMappedObjectTable", MaxCustomFieldCount);
		
	EndIf;
	
EndProcedure

// Page 2: Operations with the automatic object mapping result
//
&AtClient
Function Attachable_ObjectMapping_OnOpen(Cancel, SkipPage, IsGoNext)
	
	Items.Apply.DefaultButton = True;
	
	If EmptyResult Then
		SkipPage = True;
	EndIf;
	
EndFunction

// Page 3: Empty result of automatic object mapping
//
&AtClient
Function Attachable_EmptyObjectMappingResultEmptyObjectMappingResult_OnOpen(Cancel, SkipPage, IsGoNext)
	
	Items.Close.DefaultButton = True;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Filling wizard navigation table

&AtServer
Procedure AutomaticObjectMappingScenario()
	
	GoToTable.Clear();
	
	GoToTableNewRow(1, "ObjectMappingError",,, "ObjectMappingError_OnOpen");
	
	// Waiting for object mapping
	GoToTableNewRow(2, "ObjectMappingWait",,,,,, True, "ObjectMappingWait_LongActionProcessing");
	GoToTableNewRow(3, "ObjectMappingWait",,,,,, True, "ObjectMappingWaitLongAction_LongActionProcessing");
	GoToTableNewRow(4, "ObjectMappingWait",,,,,, True, "ObjectMappingWaitLongActionCompletion_LongActionProcessing");
	
	// Operations with the automatic object mapping result
	GoToTableNewRow(5, "ObjectMapping",,, "ObjectMapping_OnOpen");
	
	GoToTableNewRow(6, "EmptyObjectMappingResult",,, "EmptyObjectMappingResultEmptyObjectMappingResult_OnOpen");
	
EndProcedure

#EndRegion
