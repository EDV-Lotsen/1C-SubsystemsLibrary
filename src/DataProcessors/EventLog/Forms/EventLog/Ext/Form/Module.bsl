////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("SelfTest") Then
		Return;
	EndIf;
	
	EventLogFilter = New Structure;
	
	If Not IsBlankString(Parameters.User) Then
		
		UserName = Parameters.User;
		FilterByUser = New ValueList;
		ByUser = FilterByUser.Add(UserName);
		If IsBlankString(UserName) Then
			ByUser.Presentation = Users.UnspecifiedUserFullName();
		Else
			ByUser.Presentation = UserName;
		EndIf;
		
		EventLogFilter.Insert("User", FilterByUser);
		
	EndIf;
	
	If ValueIsFilled(Parameters.EventLogMessageText) Then
		FilterByEvent = New ValueList;
		If TypeOf(Parameters.EventLogMessageText) = Type("Array") Then
			For Each Event In Parameters.EventLogMessageText Do
				FilterByEvent.Add(Event, Event);
			EndDo;
		Else
			FilterByEvent.Add(Parameters.EventLogMessageText, Parameters.EventLogMessageText);
		EndIf;
		EventLogFilter.Insert("Event", FilterByEvent);
	EndIf;
	
	If Parameters.Property("StartDate") Then
		EventLogFilter.Insert("StartDate", Parameters.StartDate);
	EndIf;
	
	If Parameters.Property("EndDate") Then
		EventLogFilter.Insert("EndDate", Parameters.EndDate);
	EndIf;
	
	If Parameters.Property("Data") Then
		EventLogFilter.Insert("Data", Parameters.Data);
	EndIf;
	
	If Parameters.Property("Session") Then
		EventLogFilter.Insert("Session", Parameters.Session);
	EndIf; 
	
	EventCountLimit = 200;
	
	ReadEventLogOnCreateAtServer();
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS

&AtClient
Procedure EventCountLimitOnChange(Item)
	
	RefreshCurrentListExecute();
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM TABLE EVENT HANDLERS OF Event log TABLE

&AtClient
Procedure EventLogChoice(Item, SelectedRow, Field, StandardProcessing)
	
	EventLogClient.EventsChoice(
		Items.Log.CurrentData, 
		Field, 
		DateInterval, 
		EventLogFilter
	);
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If TypeOf(SelectedValue) = Type("Structure") And SelectedValue.Property("Event") Then
		
		If SelectedValue.Event = "EventLogFilterSet" Then
			
			EventLogFilter.Clear();
			For Each ListItem In SelectedValue.Filter Do
				EventLogFilter.Insert(ListItem.Presentation, ListItem.Value);
			EndDo;
			RefreshCurrentListExecute();
			
		EndIf;
		
	EndIf;
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure RefreshCurrentList(Command) 
	
	RefreshCurrentListExecute();
	
EndProcedure

&AtClient
Procedure ClearFilter(Command)
	
	EventLogFilter = New FixedStructure;
	RefreshCurrentListExecute();
	
EndProcedure

&AtClient
Procedure OpenDataForViewing(Command)
	
	EventLogClient.OpenDataForViewing(Items.Log.CurrentData);
	
EndProcedure

&AtClient
Procedure ViewCurrentEventInSeparateWindow(Command)
	
	EventLogClient.ViewCurrentEventInSeparateWindow(Items.Log.CurrentData);
	
EndProcedure

&AtClient
Procedure SetViewDateInterval(Command)
	
	If EventLogClient.SetViewDateInterval(
			DateInterval, 
			EventLogFilter
		) Then
		
		RefreshCurrentListExecute();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SetFilter(Command)
	
	FormFilter = New ValueList;
	For Each KeyAndValue In EventLogFilter Do
		FormFilter.Add(KeyAndValue.Value, KeyAndValue.Key);
	EndDo;
	
	OpenForm(
		"DataProcessor.EventLog.Form.EventLogFilter", 
		New Structure("Filter", FormFilter), 
		ThisForm
	);
	
EndProcedure

&AtClient
Procedure SetFilterByValueInCurrentColumn(Command)
	
	ExcludeColumns = New Array;
	ExcludeColumns.Add("Date");
	
	If EventLogClient.SetFilterByValueInCurrentColumn(
			Items.Log.CurrentData, 
			Items.Log.CurrentItem, 
			EventLogFilter, 
			ExcludeColumns
		) Then
		
		RefreshCurrentListExecute();
		
	EndIf;
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

&AtClient
Procedure RefreshCurrentListExecute() 
	
	Items.Pages.CurrentPage = Items.LongActionIndicator;
	
	ExecutionResult = ReadEventLog();
	
	IdleHandlerParameters = New Structure;
	
	If Not ExecutionResult.JobCompleted Then		
		LongActionsClient.InitIdleHandlerParameters(IdleHandlerParameters);
		AttachIdleHandler("Attachable_CheckJobExecution", 1, True);
		CommonUseClientServer.SetSpreadsheetDocumentFieldState(Items.LongActionIndicatorField, "ReportCreation");
	Else
		Items.Pages.CurrentPage = Items.EventLog;
		MoveToListEnd();
	EndIf;
	
EndProcedure

&AtServer
Function ReadEventLog()
	
	ReportParameters = ReportParameters();
	
	FileInfoBase = Undefined;
	If Not CheckFilling() Then 
		Return New Structure("JobCompleted", True);
	EndIf;
	
	If FileInfoBase = Undefined Then
		FileInfoBase = CommonUse.FileInfoBase();
	EndIf;
	
	LongActions.CancelJobExecution(JobID);
	
	JobID = Undefined;
	
	CommonUseClientServer.SetSpreadsheetDocumentFieldState(Items.LongActionIndicatorField, "DontUse");
	
	If FileInfoBase Then
		StorageAddress = PutToTempStorage(Undefined, UUID);
		EventLogServerCall.ReadEventLogEvents(ReportParameters, StorageAddress);
		ExecutionResult = New Structure("JobCompleted", True);
	Else
		ExecutionResult = LongActions.ExecuteInBackground(
			UUID, 
			"EventLogServerCall.ReadEventLogEvents", 
			ReportParameters, 
			NStr("en = 'Updating event log.'"));
						
		StorageAddress = ExecutionResult.StorageAddress;
		JobID = ExecutionResult.JobID;		
	EndIf;
	
	If ExecutionResult.JobCompleted Then
		LoadPreparedData();
	EndIf;
	
	EventLogServerCall.GenerateFilterPresentation(FilterPresentation, EventLogFilter);
	
	Return ExecutionResult;
	
EndFunction

&AtServer
Procedure ReadEventLogOnCreateAtServer()
	Items.Pages.CurrentPage = Items.EventLog;
	ReportParameters = ReportParameters();
	StorageAddress = PutToTempStorage(Undefined, UUID);
	
	EventLogServerCall.ReadEventLogEvents(ReportParameters, StorageAddress);
	LoadPreparedData();
	EventLogServerCall.GenerateFilterPresentation(FilterPresentation, EventLogFilter); 	
EndProcedure

&AtServer
Function ReportParameters()
	ReportParameters = New Structure;
	ReportParameters.Insert("EventLogFilter", EventLogFilter);
	ReportParameters.Insert("EventCountLimit", EventCountLimit);
	ReportParameters.Insert("UUID", UUID);
	ReportParameters.Insert("OwnerManager", DataProcessors.EventLog);
	ReportParameters.Insert("AddAdditionalColumns", False);
	ReportParameters.Insert("Log", FormAttributeToValue("Log"));

	Return ReportParameters;
EndFunction

&AtServer
Procedure LoadPreparedData()	
	ExecutionResult = GetFromTempStorage(StorageAddress);
	LogEvents = ExecutionResult.LogEvents;
	
	ValueToFormData(LogEvents, Log);	
	JobID = Undefined; 	
EndProcedure

&AtClient
Procedure MoveToListEnd()
	If Log.Count() > 0 Then
		Items.Log.CurrentRow = Log[Log.Count() - 1].GetID();
	EndIf;
EndProcedure 

&AtClient
Procedure Attachable_CheckJobExecution() 
	
	Try
		If LongActions.JobCompleted(JobID) Then 
			LoadPreparedData();
			CommonUseClientServer.SetSpreadsheetDocumentFieldState(Items.LongActionIndicatorField, "DontUse");
			Items.Pages.CurrentPage = Items.EventLog;
			MoveToListEnd();
		Else
			LongActionsClient.UpdateIdleHandlerParameters(IdleHandlerParameters);
			AttachIdleHandler(
				"Attachable_CheckJobExecution", 
				IdleHandlerParameters.CurrentInterval, 
				True);
		EndIf;
	Except
		CommonUseClientServer.SetSpreadsheetDocumentFieldState(Items.LongActionIndicatorField, "DontUse");
		Items.Pages.CurrentPage = Items.EventLog;
		MoveToListEnd();
		Raise;
	EndTry;	
EndProcedure