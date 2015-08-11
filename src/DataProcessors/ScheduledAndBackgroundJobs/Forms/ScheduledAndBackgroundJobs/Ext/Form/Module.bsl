////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the SelfTest parameter is passed.
	If Parameters.Property("SelfTest")  Then
		Return;
	EndIf;
	
	If Not Users.InfoBaseUserWithFullAccess(, True) Then
Raise NStr("en = 'Insufficient access rights.
                 |
                 |Only administrators can manage scheduled jobs.'");
	EndIf;
	
	FileInfoBase = CommonUse.FileInfoBase();
	EmptyID = String(New UUID("00000000-0000-0000-0000-000000000000"));
	TextUndefined = ScheduledJobsServer.TextUndefined();
	
	If FileInfoBase Then
		Items.UserName.Visible = False;
		Items.ScheduledJobTableExecutionSettings.Visible = True;
		Items.ScheduledJobTableStartSeparateSession.Visible = True;
		Items.BackgroundJobTableCancel.Enabled = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If Not SettingsLoaded Then
		FillFormSettings(New Map);
	EndIf;
	
	UpdateScheduledJobChoiceList();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Write_ScheduledAndBackgroundJobs" Then
		
		If ValueIsFilled(Parameter) Then
			UpdateScheduledJobTable(Parameter);
		Else
			AttachIdleHandler("DeferredUpdate", 0.1, True);
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	FillFormSettings(Settings);
	
	SettingsLoaded = True;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS

&AtClient
Procedure FilterKindByPeriodOnChange(Item)
	
	CurrentSessionDate = CurrentSessionDateAtServer();
	
	Items.FilterPeriodFrom.ReadOnly  = Not (FilterKindByPeriod = 4);
	Items.FilterPeriodTill.ReadOnly = Not (FilterKindByPeriod = 4);
	
	If FilterKindByPeriod = 0 Then
		FilterPeriodFrom  = '00010101';
		FilterPeriodTill = '00010101';
		
	ElsIf FilterKindByPeriod = 1 Then
		FilterPeriodFrom  = BegOfDay(CurrentSessionDate) - 3*3600;
		FilterPeriodTill = BegOfDay(CurrentSessionDate) + 9*3600;
		
	ElsIf FilterKindByPeriod = 2 Then
		FilterPeriodFrom  = BegOfDay(CurrentSessionDate) - 24*3600;
		FilterPeriodTill = EndOfDay(FilterPeriodFrom);
		
	ElsIf FilterKindByPeriod = 3 Then
		FilterPeriodFrom  = BegOfDay(CurrentSessionDate);
		FilterPeriodTill = EndOfDay(FilterPeriodFrom);
		
	ElsIf FilterKindByPeriod = 4 Then
		FilterPeriodFrom  = BegOfDay(CurrentSessionDate);
		FilterPeriodTill = FilterPeriodFrom;
	EndIf;
	
EndProcedure

&AtClient
Procedure FilterByScheduledJobOnChange(Item)

	Items.ScheduledJobForFilter.Enabled = FilterByScheduledJob;
	
EndProcedure

&AtClient
Procedure ScheduledJobForFilterClear(Item, StandardProcessing)

	StandardProcessing = False;
	ScheduledJobForFilterID = EmptyID;
	ScheduledJobForFilterPresentation = TextUndefined;
	
EndProcedure

&AtClient
Procedure ScheduledJobForFilterChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	ListItem = Items.ScheduledJobForFilter.ChoiceList.FindByValue(SelectedValue);
	ScheduledJobForFilterID = ListItem.Value;
	ScheduledJobForFilterPresentation = ListItem.Presentation;
	StandardProcessing = False;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM TABLE EVENT HANDLERS OF BackgroundJobTable TABLE 

&AtClient
Procedure BackgroundJobTableChoice(Item, SelectedRow, Field, StandardProcessing)
	
	OpenBackgroundJob();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM TABLE EVENT HANDLERS OF ScheduledJobTable TABLE 

&AtClient
Procedure ScheduledJobTableChoice(Item, SelectedRow, Field, StandardProcessing)
	
	EditScheduledJob("Change");
	
EndProcedure

&AtClient
Procedure ScheduledJobTableBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	Cancel = True;
	
	EditScheduledJob(?(Copy, "Copy", "Add"));
	
EndProcedure

&AtClient
Procedure ScheduledJobTableBeforeDelete(Item, Cancel)
	
	Cancel = True;
	
	If Items.ScheduledJobTable.SelectedRows.Count() > 1 Then
		ShowMessageBox(,NStr("en = 'Select one scheduled job.'"));
		
	ElsIf Item.CurrentData.Predefined Then
		ShowMessageBox(,NStr("en = 'Predefined scheduled job cannot be deleted.'") );
	Else
		Response = Undefined;

		ShowQueryBox(New NotifyDescription("ScheduledJobTableBeforeDeleteEnd", ThisObject), NStr("en = 'Do you want to delete the scheduled job?'"), QuestionDialogMode.YesNo);
	EndIf;
	
EndProcedure

&AtClient
Procedure ScheduledJobTableBeforeDeleteEnd(QuestionResult, AdditionalParameters) Export
	
	Response = QuestionResult;
	If Response = DialogReturnCode.Yes Then
		
		DeleteScheduledJobExecuteAtServer(
		Items.ScheduledJobTable.CurrentData.ID);
	EndIf;

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure ExecuteScheduledJobManually(Command)

	If Items.ScheduledJobTable.CurrentData = Undefined Then
		ShowMessageBox(, NStr("en = 'Select the scheduled job.'") );
	Else
		SelectedRows = Items.ScheduledJobTable.SelectedRows;
		SelectedRows = New Array;
		For Each SelectedRow In Items.ScheduledJobTable.SelectedRows Do
			SelectedRows.Add(SelectedRow);
		EndDo;
		Index = 0;
		
		For Each SelectedRow In SelectedRows Do
			UpdateAll = Index = SelectedRows.Count()-1;
			ProcedureAlreadyExecuting = Undefined;
			CurrentData = ScheduledJobTable.FindByID(SelectedRow);
			
			If FileInfoBase Then
				
				StartedAt      = Undefined;
				FinishedAt     = Undefined;
				SessionNumber  = Undefined;
				SessionStarted = Undefined;
				If ExecuteScheduledJobManuallyAtServer(
						CurrentData.ID,
						StartedAt,
						,
						FinishedAt,
						SessionNumber,
						SessionStarted,
						,
						UpdateAll,
						ProcedureAlreadyExecuting) Then
					
					ShowUserNotification(
						NStr("en = 'Scheduled job procedure is complete'"),
						,
						StringFunctionsClientServer.SubstituteParametersInString(NStr("en = '%1.
							|The procedure was executed from %2 till %3'"),
							CurrentData.Description,
							String(StartedAt),
							String(FinishedAt)),
						PictureLib.ExecuteScheduledJobManually);
				Else
					If ProcedureAlreadyExecuting Then
						
						CommonUseClientServer.MessageToUser(
							StringFunctionsClientServer.SubstituteParametersInString(
								NStr("en = 'Cannot start the %1 scheduled job procedure because it is being executed in the %2 session started at %3.'"),
								CurrentData.Description,
								String(SessionNumber),
								String(SessionStarted)));
					Else
						Items.ScheduledJobTable.SelectedRows.Delete(
							Items.ScheduledJobTable.SelectedRows.Find(SelectedRow));
					EndIf;
				EndIf;
			Else
				StartedAt                 = Undefined;
				BackgroundJobID           = "";
				BackgroundJobPresentation = "";
				
				If ExecuteScheduledJobManuallyAtServer(
						CurrentData.ID,
						StartedAt,
						BackgroundJobID,
						,
						,
						,
						BackgroundJobPresentation,
						UpdateAll,
						ProcedureAlreadyExecuting) Then
					
					ShowUserNotification(
						NStr("en = 'Scheduled job procedure has been started'"),
						,
						StringFunctionsClientServer.SubstituteParametersInString(NStr("en = '%1.
							|The procedure is being executed in the %2 background job.'"),
							CurrentData.Description,
							String(StartedAt)),
						PictureLib.ExecuteScheduledJobManually);
					
					BackgroundJobIDsOnManualChange.Add(
						BackgroundJobID,
						CurrentData.Description);
					
					AttachIdleHandler(
						"NotifyAboutScheduledJobCompletion", 0.1, True);
				Else
					If ProcedureAlreadyExecuting Then
						
						CommonUseClientServer.MessageToUser(
							StringFunctionsClientServer.SubstituteParametersInString(
								NStr("en = 'Cannot start the %1 scheduled job procedure because it is being executed in the %2 session started at %3.'"),
								CurrentData.Description,
								BackgroundJobPresentation,
								String(StartedAt)));
					Else
						Items.ScheduledJobTable.SelectedRows.Delete(
							Items.ScheduledJobTable.SelectedRows.Find(SelectedRow));
					EndIf;
				EndIf;
			EndIf;
			Index = Index + 1;
		EndDo;
	EndIf;
	
EndProcedure

&AtClient
Procedure StartSeparateSession(Command)
	
	Status(NStr("en = 'Starting a separate session to perform scheduled jobs.'"),
	          ,
	          NStr("en = 'Please wait...'"));
	
	AttachIdleHandler(
		"StartSeparateSessionToExecuteScheduledJobsViaIdleHandler", 1, True);
	
EndProcedure

&AtClient
Procedure EditScheduledJobExecute(Command)
	
	EditScheduledJob("Change");
	
EndProcedure

&AtClient
Procedure ScheduledJobExecutionSetup(Command)
	
	FormParameters = New Structure("HideSeparateSessionStartCommand", True);
	
	OpenForm(
		"DataProcessor.ScheduledAndBackgroundJobs.Form.ScheduledJobExecutionSetup",
		FormParameters,,,,, Undefined, FormWindowOpeningMode.LockWholeInterface);
	
EndProcedure

&AtClient
Procedure UpdateDataExecute(Command)
	
	UpdateData();
	
EndProcedure

&AtClient
Procedure OpenJobScheduleExecute(Command)
	
	CurrentData = Items.ScheduledJobTable.CurrentData;
	
	If CurrentData = Undefined Then
		ShowMessageBox(, NStr("en='Select the scheduled job.'") );
	Else
		Dialog = New ScheduledJobDialog(
			ScheduledJobsClient.GetJobSchedule(CurrentData.ID));
		
		Dialog.Show(New NotifyDescription("OpenJobScheduleExecuteEnd", ThisForm));
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenJobScheduleExecuteEnd(Schedule, AdditionalParameters) Export
	
	CurrentData = Items.ScheduledJobTable.CurrentData;
	
	If Schedule <> Undefined And CurrentData <> Undefined Then
		
		ScheduledJobsClient.SetJobSchedule(
			CurrentData.ID,
			Schedule);
		
		UpdateScheduledJobTable(CurrentData.ID);
		
	EndIf;
		
EndProcedure

&AtClient
Procedure OpenBackgroundJobExecute(Command)
	
	OpenBackgroundJob();
	
EndProcedure

&AtClient
Procedure CancelBackgroundJobExecute(Command)
	
	If Items.BackgroundJobTable.CurrentData = Undefined Then
		ShowMessageBox(, NStr("en='Select the background job.'") );
		
	Else
		CancelBackgroundJobAtServer(Items.BackgroundJobTable.CurrentData.ID);
		
		ShowMessageBox(,NStr("en='The job is canceled but the state will be updated in "
"a few seconds, perhaps you will need to update data manually.'"));
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

&AtServer
Procedure FillFormSettings(Val Settings)
	
	UpdateScheduledJobTable();
	
	// Setting the background job filter.
	If Settings.Get("FilterByActiveState") = Undefined Then
		Settings.Insert("FilterByActiveState", True);
	EndIf;
	
	If Settings.Get("FilterByCompletedState") = Undefined Then
		Settings.Insert("FilterByCompletedState", True);
	EndIf;
	
	If Settings.Get("FilterByFailedState") = Undefined Then
		Settings.Insert("FilterByFailedState", True);
	EndIf;

	If Settings.Get("FilterByCanceledState") = Undefined Then
		Settings.Insert("FilterByCanceledState", True);
	EndIf;
	
	If Settings.Get("FilterByScheduledJob") = Undefined
	 Or Settings.Get("ScheduledJobForFilterID") = Undefined Then
		Settings.Insert("FilterByScheduledJob", False);
		Settings.Insert("ScheduledJobForFilterID", EmptyID);
	EndIf;
	
	// Setting filter by the "No filter" period.
	// See also the FilterKindByPeriodOnChange switch event handler.
	If Settings.Get("FilterKindByPeriod") = Undefined
	Or Settings.Get("FilterPeriodFrom")   = Undefined
	Or Settings.Get("FilterPeriodTill")   = Undefined Then
		
		Settings.Insert("FilterKindByPeriod", 0);
		CurrentSessionDate = CurrentSessionDate();
		Settings.Insert("FilterPeriodFrom",  BegOfDay(CurrentSessionDate) - 3*3600);
		Settings.Insert("FilterPeriodTill", BegOfDay(CurrentSessionDate) + 9*3600);
	EndIf;
	
	For Each KeyAndValue In Settings Do
		Try
			ThisForm[KeyAndValue.Key] = KeyAndValue.Value;
		Except
		EndTry;
	EndDo;
	
	// Setting visibility and availability.
	Items.FilterPeriodFrom.ReadOnly  = Not (FilterKindByPeriod = 4);
	Items.FilterPeriodTill.ReadOnly = Not (FilterKindByPeriod = 4);
	Items.ScheduledJobForFilter.Enabled = FilterByScheduledJob;
	
	UpdateBackgroundJobTable();
	
EndProcedure

&AtClient
Procedure OpenBackgroundJob()
	
	If Items.BackgroundJobTable.CurrentData = Undefined Then
		ShowMessageBox(Undefined, NStr("en='Select the background job.'"));
	Else
		PassedPropertyList =
		"ID,
		|Key,
		|Description,
		|MethodName,
		|State,
		|Begin,
		|End,
		|Placement,
		|UserMessagesAndErrorDetails,
		|ScheduledJobID,
		|ScheduledJobDescription";
		CurrentDataValues = New Structure(PassedPropertyList);
		FillPropertyValues(CurrentDataValues, Items.BackgroundJobTable.CurrentData);
		
		FormParameters = New Structure;
		FormParameters.Insert("ID", Items.BackgroundJobTable.CurrentData.ID);
		FormParameters.Insert("BackgroundJobProperties", CurrentDataValues);
		
		OpenForm("DataProcessor.ScheduledAndBackgroundJobs.Form.BackgroundJob", FormParameters,,,,, Undefined, FormWindowOpeningMode.LockWholeInterface);
	EndIf;
	
EndProcedure

&AtServerNoContext
Function CurrentSessionDateAtServer()
	
	Return CurrentSessionDate();
	
EndFunction

&AtServer
Function ScheduledJobsFinishedNotification()
	
	CompletionNotifications = New Array;
	
	If BackgroundJobIDsOnManualChange.Count() > 0 Then
		Index = BackgroundJobIDsOnManualChange.Count() - 1;
		
		SetPrivilegedMode(True);
		While Index >= 0 Do
			
			Filter = New Structure("UUID", New UUID(
				BackgroundJobIDsOnManualChange[Index].Value));
			
			BackgroundJobArray = BackgroundJobs.GetBackgroundJobs(Filter);
			
			If BackgroundJobArray.Count() = 1 Then
				FinishedAt = BackgroundJobArray[0].End;
				
				If ValueIsFilled(FinishedAt) Then
					
					CompletionNotifications.Add(
						New Structure(
							"ScheduledJobPresentation,
							|FinishedAt",
							BackgroundJobIDsOnManualChange[Index].Presentation,
							FinishedAt));
					
					BackgroundJobIDsOnManualChange.Delete(Index);
				EndIf;
			Else
				BackgroundJobIDsOnManualChange.Delete(Index);
			EndIf;
			Index = Index - 1;
		EndDo;
		SetPrivilegedMode(False);
	EndIf;
	
	UpdateData();
	
	Return CompletionNotifications;
	
EndFunction

&AtClient
Procedure NotifyAboutScheduledJobCompletion()
	
	CompletionNotifications = ScheduledJobsFinishedNotification();
	
	For Each Notification In CompletionNotifications Do
		
		ShowUserNotification(
			NStr("en = 'Schedule job procedure is complete'"),
			,
			StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = '%1.
				           |The procedure is been completed in the %2 background job.'"),
				Notification.ScheduledJobPresentation,
				String(Notification.FinishedAt)),
			PictureLib.ExecuteScheduledJobManually);
	EndDo;
	
	If BackgroundJobIDsOnManualChange.Count() > 0 Then
		
		AttachIdleHandler(
			"NotifyAboutScheduledJobCompletion", 2, True);
	EndIf;

EndProcedure

&AtServer
Procedure UpdateScheduledJobChoiceList()
	
	Table = ScheduledJobTable;
	List  = Items.ScheduledJobForFilter.ChoiceList;
	
	// Adding the predefined item
	If List.Count() = 0 Then
		List.Add(EmptyID, TextUndefined);
	EndIf;
	
	Index = 1;
	For Each Job In Table Do
		If Index >= List.Count()
		 Or List[Index].Value <> Job.ID Then
			// Inserting a new job
			List.Insert(Index, Job.ID, Job.Description);
		Else
			List[Index].Presentation = Job.Description;
		EndIf;
		Index = Index + 1;
	EndDo;
	
	// Deleting excess rows.
	While Index < List.Count() Do
		List.Delete(Index);
	EndDo;
	
	ListItem = List.FindByValue(ScheduledJobForFilterID);
	If ListItem = Undefined Then
		
		ScheduledJobForFilterID = EmptyID;
		ScheduledJobForFilterPresentation = TextUndefined;
	Else
		ScheduledJobForFilterPresentation = ListItem.Presentation;
	EndIf;
	
EndProcedure

&AtServer
Function ExecuteScheduledJobManuallyAtServer(Val ScheduledJobID,
                                                 StartedAt,
                                                 BackgroundJobID,
                                                 FinishedAt = Undefined,
                                                 SessionNumber = Undefined,
                                                 SessionStarted = Undefined,
                                                 BackgroundJobPresentation = Undefined,
                                                 UpdateAll = False,
                                                 ProcedureAlreadyExecuting = Undefined)
	
	If FileInfoBase Then
		StartedAt = CurrentSessionDate();
	EndIf;
	
	Started = ScheduledJobsServer.ExecuteScheduledJobManually(
		ScheduledJobID,
		StartedAt,
		BackgroundJobID,
		FinishedAt,
		SessionNumber,
		SessionStarted,
		BackgroundJobPresentation,
		ProcedureAlreadyExecuting);
	
	If UpdateAll Then
		UpdateData();
	Else
		UpdateScheduledJobTable(ScheduledJobID);
	EndIf;
	
	Return Started;
	
EndFunction

&AtServer
Procedure CancelBackgroundJobAtServer(Val ID)
	
	ScheduledJobsServer.CancelBackgroundJob(ID);
	
	UpdateData();
	
EndProcedure

&AtServer
Procedure DeleteScheduledJobExecuteAtServer(Val ID)
	
	Job = ScheduledJobsServer.GetScheduledJob(ID);
	String = ScheduledJobTable.FindRows(New Structure("ID", ID))[0];
	Job.Delete();
	ScheduledJobTable.Delete(ScheduledJobTable.IndexOf(String));
	
EndProcedure

&AtClient
Procedure EditScheduledJob(Val Action)
	
	If Items.ScheduledJobTable.CurrentData = Undefined Then
		ShowMessageBox(Undefined,  NStr("en = 'Select the scheduled job.'") );
		
	ElsIf Action = "Change"
	        And Items.ScheduledJobTable.SelectedRows.Count() > 1 Then
		
		ShowMessageBox(,NStr("en = 'Select one scheduled job.'"));
	Else
		FormParameters = New Structure;
		FormParameters.Insert("ID", Items.ScheduledJobTable.CurrentData.ID);
		FormParameters.Insert("Action",      Action);
		
		OpenForm("DataProcessor.ScheduledAndBackgroundJobs.Form.ScheduledJob", FormParameters,,,,, Undefined, FormWindowOpeningMode.LockWholeInterface);
	EndIf;
	
EndProcedure

&AtClient
Procedure DeferredUpdate()
	
	UpdateData();
	
EndProcedure

&AtServer
Procedure UpdateData()
	
	UpdateScheduledJobTable();
	UpdateBackgroundJobTable();
	UpdateScheduledJobChoiceList();
	
EndProcedure

&AtServer
Procedure UpdateScheduledJobTable(ScheduledJobID = Undefined)

	// Updating the ScheduledJobs table and the ChoiceList scheduled job list for a filter
	CurrentJobs = ScheduledJobs.GetScheduledJobs();
	Table = ScheduledJobTable;
	
	If ScheduledJobID = Undefined Then
		
		Index = 0;
		For Each Job In CurrentJobs Do
			ID = String(Job.UUID);
			
			If Index >= Table.Count()
			 Or Table[Index].ID <> ID Then
				
				// Inserting a new job
				Update = Table.Insert(Index);
				
				// Setting UUID
				Update.ID = ID;
			Else
				Update = Table[Index];
			EndIf;
			UpdateScheduledJobTableRow(Update, Job);
			Index = Index + 1;
		EndDo;
	
		// Deleting excess rows
		While Index < Table.Count() Do
			Table.Delete(Index);
		EndDo;
	Else
		Job = ScheduledJobs.FindByUUID(
			New UUID(ScheduledJobID));
		
		Rows = Table.FindRows(
			New Structure("ID", ScheduledJobID));
		
		If Job <> Undefined
		   And Rows.Count() > 0 Then
			
			UpdateScheduledJobTableRow(Rows[0], Job);
		EndIf;
	EndIf;
	
	Items.ScheduledJobTable.Refresh();
	
EndProcedure

&AtServer
Procedure UpdateScheduledJobTableRow(String, Job);
	
	FillPropertyValues(String, Job);
	
	// Giving a more precise description
	String.Description = ScheduledJobsServer.ScheduledJobPresentation(Job);
	
	// Setting EndDate and ExecutionState by last background procedure
	LastBackgroundJobProperties = ScheduledJobsServer
		.GetLastBackgroundJobForScheduledJobExecutionProperties(Job);
	
	If LastBackgroundJobProperties = Undefined Then
		
		String.EndDate       = TextUndefined;
		String.ExecutionState = TextUndefined;
	Else
		String.EndDate       = ?(ValueIsFilled(LastBackgroundJobProperties.End),
		                               LastBackgroundJobProperties.End,
		                               "<>");
		String.ExecutionState = LastBackgroundJobProperties.State;
	EndIf;
		
EndProcedure

&AtServer
Procedure UpdateBackgroundJobTable()
	
	// 1. Preparing a filter
	Filter = New Structure;
	
	// 1.1. Adding a filter by states
	StateArray = New Array;
	
	If FilterByActiveState Then 
		StateArray.Add(BackgroundJobState.Active);
	EndIf;
	
	If FilterByCompletedState Then 
		StateArray.Add(BackgroundJobState.Completed);
	EndIf;
	
	If FilterByFailedState Then 
		StateArray.Add(BackgroundJobState.Failed);
	EndIf;
	
	If FilterByCanceledState Then 
		StateArray.Add(BackgroundJobState.Canceled);
	EndIf;
	
	If StateArray.Count() <> 4 Then
		If StateArray.Count() = 1 Then
			Filter.Insert("State", StateArray[0]);
		Else
			Filter.Insert("State", StateArray);
		EndIf;
	EndIf;
	
	// 1.2. Adding a filter by scheduled job
	If FilterByScheduledJob Then
		Filter.Insert(
				"ScheduledJobID",
				?(ScheduledJobForFilterID = EmptyID,
				"",
				ScheduledJobForFilterID));
	EndIf;
	
	// 1.3. Adding a filter by period
	If FilterKindByPeriod <> 0 Then
		Filter.Insert("Start", FilterPeriodFrom);
		Filter.Insert("End",  FilterPeriodTill);
	EndIf;
	
	// 2. Updating background job list
	Table = BackgroundJobTable;
	BackgroundJobTotalCount = 0;
	
	CurrentTable = ScheduledJobsServer.GetBackgroundJobPropertyTable(
		Filter, BackgroundJobTotalCount);
	
	Index = 0;
	For Each Job In CurrentTable Do
		
		If Index >= Table.Count()
		 Or Table[Index].ID <> Job.ID Then
			// Inserting a new job
			Update = Table.Insert(Index);
			// Setting UUID
			Update.ID = Job.ID;
		Else
			Update = Table[Index];
		EndIf;
		
		FillPropertyValues(Update, Job);
		
		// Setting the scheduled job description from the ScheduledJobTable collection
		If ValueIsFilled(Update.ScheduledJobID) Then
			
			Update.ScheduledJobID
				= Update.ScheduledJobID;
			
			Rows = ScheduledJobTable.FindRows(
				New Structure("ID", Update.ScheduledJobID));
			
			Update.ScheduledJobDescription
				= ?(Rows.Count() = 0, NStr("en = '<not found>'"), Rows[0].Description);
		Else
			Update.ScheduledJobDescription  = TextUndefined;
			Update.ScheduledJobID = TextUndefined;
		EndIf;
		
		// Getting error details
		Update.UserMessagesAndErrorDetails 
			= ScheduledJobsServer.BackgroundJobMessagesAndErrorDescriptions(
				Update.ID, Job);
		
		// Increasing index
		Index = Index + 1;
	EndDo;
	
	// Deleting excess rows
	While Index < Table.Count() Do
		Table.Delete(Table.Count()-1);
	EndDo;
	BackgroundJobCountInTable = Table.Count();

	Items.BackgroundJobTable.Refresh();
	
EndProcedure

