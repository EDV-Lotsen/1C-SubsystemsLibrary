
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
		
	If Not Users.InfobaseUserWithFullAccess(, True) Then
		Raise NStr("en = 'Limited access rights.
		                             |
		                             |Only administrators can
		                             |manage scheduled and background jobs.'");
	EndIf;
	
	EmptyID = String(New UUID("00000000-0000-0000-0000-000000000000"));
	TextUndefined = ScheduledJobsInternal.TextUndefined();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If Not SettingsImported Then
		FillFormSettings(New Map);
	EndIf;
	
	UpdateScheduledJobChoiceList();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Write_ScheduledJobs" Then
		
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
	
	SettingsImported = True;
	
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure FilterKindByPeriodOnChange(Item)
	
	CurrentSessionDate = CurrentSessionDateAtServer();
	
	Items.FilterPeriodFrom.ReadOnly  = Not (FilterKindByPeriod = 4);
	Items.FilterPeriodTo.ReadOnly = Not (FilterKindByPeriod = 4);
	
	If FilterKindByPeriod = 0 Then
		FilterPeriodFrom  = '00010101';
		FilterPeriodTo = '00010101';
		Items.SettingArbitraryPeriod.Visible = False;
	ElsIf FilterKindByPeriod = 4 Then
		FilterPeriodFrom  = BegOfDay(CurrentSessionDate);
		FilterPeriodTo = FilterPeriodFrom;
		Items.SettingArbitraryPeriod.Visible = True;
	Else
		RefreshAutomaticPeriod(ThisObject, CurrentSessionDate);
		Items.SettingArbitraryPeriod.Visible = False;
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
	
EndProcedure

#EndRegion

#Region BackgroundJobTableFormTableItemEventHandlers

&AtClient
Procedure BackgroundJobTableChoice(Item, SelectedRow, Field, StandardProcessing)
	
	OpenBackgroundJob();
	
EndProcedure

#EndRegion

#Region ScheduledJobTableFormTableItemEventHandlers

&AtClient
Procedure ScheduledJobTableChoice(Item, SelectedRow, Field, StandardProcessing)
	
	If Field = "Predefined"
	 Or Field = "Use" Then
		
		AddCopyEditScheduledJob("Change");
	EndIf;
	
EndProcedure

&AtClient
Procedure ScheduledJobTableBeforeAddRow(Item, Cancel, Clone, Parent, Group)
	
	Cancel = True;
	
	AddCopyEditScheduledJob(?(Clone, "Copy", "Add"));
	
EndProcedure

&AtClient
Procedure ScheduledJobTableBeforeChange(Item, Cancel)
	
	Cancel = True;
	
	AddCopyEditScheduledJob("Change");
	
EndProcedure

&AtClient
Procedure ScheduledJobTableBeforeDelete(Item, Cancel)
	
	Cancel = True;
	
	If Items.ScheduledJobTable.SelectedRows.Count() > 1 Then
		ShowMessageBox(, NStr("en = 'Select one scheduled job.'"));
		
	ElsIf Item.CurrentData.Predefined Then
		ShowMessageBox(, NStr("en = 'The predefined scheduled job cannot be deleted.'") );
	Else
		ShowQueryBox(
			New NotifyDescription("ScheduledJobTableBeforeDeleteEnd", ThisObject),
			NStr("en = 'Do you want to delete the scheduled job?'"), QuestionDialogMode.YesNo);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ExecuteScheduledJobManually(Command)

	If Items.ScheduledJobTable.CurrentData = Undefined Then
		ShowMessageBox(, NStr("en = 'Select a scheduled job.'"));
		Return;
	EndIf;
	
	SelectedRows = New Array;
	For Each SelectedRow In Items.ScheduledJobTable.SelectedRows Do
		SelectedRows.Add(SelectedRow);
	EndDo;
	Index = 0;
	
	ErrorMessageArray = New Array;
	
	For Each SelectedRow In SelectedRows Do
		UpdateAll = Index = SelectedRows.Count()-1;
		ProcedureAlreadyExecuting = Undefined;
		CurrentData = ScheduledJobTable.FindByID(SelectedRow);
		
		StartTime = Undefined;
		BackgroundJobID = "";
		BackgroundJobPresentation = "";
		
		If ExecuteScheduledJobManuallyAtServer(
				CurrentData.ID,
				StartTime,
				BackgroundJobID,
				,
				,
				,
				BackgroundJobPresentation,
				UpdateAll,
				ProcedureAlreadyExecuting) Then
			
			ShowUserNotification(
				NStr("en = 'The scheduled job procedure is running'"),
				,
				StringFunctionsClientServer.SubstituteParametersInString(NStr("en = '%1.
					|The procedure is running in the background job %2'"),
					CurrentData.Description,
					String(StartTime)),
				PictureLib.ExecuteScheduledJobManually);
			
			BackgroundJobIDsOnManualChange.Add(
				BackgroundJobID,
				CurrentData.Description);
			
			AttachIdleHandler(
				"NotifyAboutScheduledJobCompletion", 0.1, True);
		Else
			If ProcedureAlreadyExecuting Then
				ErrorMessageArray.Add(
					StringFunctionsClientServer.SubstituteParametersInString(
						NStr("en = 'The %1 scheduled job procedure 
						|  is already running in the %2 background job started at %3.'"),
						CurrentData.Description,
						BackgroundJobPresentation,
						String(StartTime)));
			Else
				Items.ScheduledJobTable.SelectedRows.Delete(
					Items.ScheduledJobTable.SelectedRows.Find(SelectedRow));
			EndIf;
		EndIf;
		
		Index = Index + 1;
	EndDo;
	
	ErrorsCount = ErrorMessageArray.Count();
	If ErrorsCount > 0 Then
		ErrorTextTitle = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'The jobs have been executed with errors (%1 out of %2)'"),
			Format(ErrorsCount, "NG="),
			Format(SelectedRows.Count(), "NG="));
		
		AllErrorText = New TextDocument;
		AllErrorText.AddLine(ErrorTextTitle + ":");
		For Each ThisErrorText In ErrorMessageArray Do
			AllErrorText.AddLine("");
			AllErrorText.AddLine(ThisErrorText);
		EndDo;
		
		If ErrorsCount > 5 Then
			Buttons = New ValueList;
			Buttons.Add(1, NStr("en = 'Show errors'"));
			Buttons.Add(DialogReturnCode.Cancel);
			
			ShowQueryBox(
				New NotifyDescription(
					"ExecuteScheduledJobManuallyEnd", ThisObject, AllErrorText),
				ErrorTextTitle, Buttons);
		Else
			ShowMessageBox(, TrimAll(AllErrorText.GetText()));
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure RefreshData(Command)
	
	RefreshDataAtServer();
	
EndProcedure

&AtClient
Procedure SetScheduleCommand(Command)
	
	CurrentData = Items.ScheduledJobTable.CurrentData;
	
	If CurrentData = Undefined Then
		ShowMessageBox(, NStr("en = 'Select a scheduled job.'"));
	
	ElsIf Items.ScheduledJobTable.SelectedRows.Count() > 1 Then
		ShowMessageBox(, NStr("en = 'Select one scheduled job.'"));
	Else
		Dialog = New ScheduledJobDialog(
			GetSchedule(CurrentData.ID));
		
		Dialog.Show(New NotifyDescription(
			"OpenScheduleEnd", ThisObject, CurrentData));
	EndIf;
	
EndProcedure

&AtClient
Procedure EnableScheduledJob(Command)
	
	SetUseScheduledJob(True);
	
EndProcedure

&AtClient
Procedure DisableScheduledJob(Command)
	
	SetUseScheduledJob(False);
	
EndProcedure

&AtClient
Procedure OpenBackgroundJobAtClient(Command)
	
	OpenBackgroundJob();
	
EndProcedure

&AtClient
Procedure CancelBackgroundJob(Command)
	
	If Items.BackgroundJobTable.CurrentData = Undefined Then
		ShowMessageBox(, NStr("en = 'Select a background job.'"));
	Else
		CancelBackgroundJobAtServer(Items.BackgroundJobTable.CurrentData.ID);
		
		ShowMessageBox(,
			NStr("en = 'The job has been cancelled, but the cancellation
			           |state will be set by the server only in a few seconds,
			           |it may be necessary to update the data manually.'"));
	EndIf;
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.End.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("BackgroundJobTable.End");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;
	Item.Appearance.SetParameterValue("Text", NStr("en = '<>'"));
	
	//
	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ExecutionState.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ScheduledJobTable.ExecutionState");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = NStr("en = '<not defined>'");
	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleDataColor);
	
	//
	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.EndDate.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ScheduledJobTable.EndDate");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = NStr("en = '<not defined>'");
	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleDataColor);


EndProcedure

&AtClient
Procedure ScheduledJobTableBeforeDeleteEnd(Answer, NotDefined) Export
	
	If Answer = DialogReturnCode.Yes Then
		DeleteScheduledJobExecuteAtServer(
			Items.ScheduledJobTable.CurrentData.ID);
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteScheduledJobManuallyEnd(Answer, AllErrorText) Export
	
	If Answer = 1 Then
		AllErrorText.Show();
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenScheduleEnd(NewSchedule, CurrentData) Export

	If NewSchedule <> Undefined Then
		SetSchedule(CurrentData.ID, NewSchedule);
		UpdateScheduledJobTable(CurrentData.ID);
	EndIf;
	
EndProcedure

&AtServerNoContext
Function GetSchedule(Val ScheduledJobID)
	
	SetPrivilegedMode(True);
	
	Return ScheduledJobsServer.GetJobSchedule(ScheduledJobID);
	
EndFunction

&AtServerNoContext
Procedure SetSchedule(Val ScheduledJobID, Val Schedule)
	
	SetPrivilegedMode(True);
	
	ScheduledJobsServer.SetJobSchedule(ScheduledJobID, Schedule);
	
EndProcedure

&AtServer
Procedure FillFormSettings(Val Settings)
	
	UpdateScheduledJobTable();
	
	// Background job filter setting.
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
	
	// Setting filter by the All time period.
	// See also the FilterKindByPeriodOnChange switch event handler.
	If Settings.Get("FilterKindByPeriod") = Undefined
	 Or Settings.Get("FilterPeriodFrom")  = Undefined
	 Or Settings.Get("FilterPeriodTo")  = Undefined Then
		
		Settings.Insert("FilterKindByPeriod", 0);
		CurrentSessionDate = CurrentSessionDate();
		Settings.Insert("FilterPeriodFrom", BegOfDay(CurrentSessionDate) - 3*3600);
		Settings.Insert("FilterPeriodTo", BegOfDay(CurrentSessionDate) + 9*3600);
	EndIf;
	
	For Each KeyAndValue In Settings Do
		Try
			ThisObject[KeyAndValue.Key] = KeyAndValue.Value;
		Except
		EndTry;
	EndDo;
	
	// Setting visibility and accessibility.
	Items.FilterPeriodFrom.ReadOnly = Not (FilterKindByPeriod = 4);
	Items.FilterPeriodTo.ReadOnly = Not (FilterKindByPeriod = 4);
	Items.ScheduledJobForFilter.Enabled = FilterByScheduledJob;
	
	RefreshAutomaticPeriod(ThisObject, CurrentSessionDate());
	
	UpdateBackgroundJobTable();
	
EndProcedure

&AtClient
Procedure OpenBackgroundJob()
	
	If Items.BackgroundJobTable.CurrentData = Undefined Then
		ShowMessageBox(, NStr("en = 'Select a background job.'"));
		Return;
	EndIf;
	
	PassedPropertyList =
	"ID,
	|Key,
	|Description,
	|MethodName,
	|State,
	|Beginning,
	|End,
	|Location,
	|UserMessagesAndErrorDetails,
	|ScheduledJobID,
	|ScheduledJobDescription";
	CurrentDataValues = New Structure(PassedPropertyList);
	FillPropertyValues(CurrentDataValues, Items.BackgroundJobTable.CurrentData);
	
	FormParameters = New Structure;
	FormParameters.Insert("ID", Items.BackgroundJobTable.CurrentData.ID);
	FormParameters.Insert("BackgroundJobProperties", CurrentDataValues);
	
	OpenForm("DataProcessor.ScheduledAndBackgroundJobs.Form.BackgroundJob", FormParameters, ThisObject);
	
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
	
	RefreshDataAtServer();
	
	Return CompletionNotifications;
	
EndFunction

&AtClient
Procedure NotifyAboutScheduledJobCompletion()
	
	CompletionNotifications = ScheduledJobsFinishedNotification();
	
	For Each Notification In CompletionNotifications Do
		
		ShowUserNotification(
			NStr("en = 'The scheduled job procedure has been executed'"),
			,
			StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = '%1.
				           |The procedure is completed in the background job %2'"),
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
	
	// Adding a predefined item.
	If List.Count() = 0 Then
		List.Add(EmptyID, TextUndefined);
	EndIf;
	
	Index = 1;
	For Each Job In Table Do
		If Index >= List.Count()
		 Or List[Index].Value <> Job.ID Then
			// Inserting a new job.
			List.Insert(Index, Job.ID, Job.Description);
		Else
			List[Index].Presentation = Job.Description;
		EndIf;
		Index = Index + 1;
	EndDo;
	
	// Deleting unnecessary rows.
	While Index < List.Count() Do
		List.Delete(Index);
	EndDo;
	
	ListItem = List.FindByValue(ScheduledJobForFilterID);
	If ListItem = Undefined Then
		ScheduledJobForFilterID = EmptyID;
	EndIf;
	
EndProcedure

&AtServer
Function ExecuteScheduledJobManuallyAtServer(Val ScheduledJobID,
                                             StartTime,
                                             BackgroundJobID,
                                             FinishedAt = Undefined,
                                             SessionNumber = Undefined,
                                             SessionStarted = Undefined,
                                             BackgroundJobPresentation = Undefined,
                                             UpdateAll = False,
                                             ProcedureAlreadyExecuting = Undefined)
	
	Started = ScheduledJobsInternal.ExecuteScheduledJobManually(
		ScheduledJobID,
		StartTime,
		BackgroundJobID,
		FinishedAt,
		SessionNumber,
		SessionStarted,
		BackgroundJobPresentation,
		ProcedureAlreadyExecuting);
	
	If UpdateAll Then
		RefreshDataAtServer();
	Else
		UpdateScheduledJobTable(ScheduledJobID);
	EndIf;
	
	Return Started;
	
EndFunction

&AtServer
Procedure CancelBackgroundJobAtServer(Val ID)
	
	ScheduledJobsInternal.CancelBackgroundJob(ID);
	
	RefreshDataAtServer();
	
EndProcedure

&AtServer
Procedure DeleteScheduledJobExecuteAtServer(Val ID)
	
	Job = ScheduledJobsServer.GetScheduledJob(ID);
	String = ScheduledJobTable.FindRows(New Structure("ID", ID))[0];
	Job.Delete();
	ScheduledJobTable.Delete(ScheduledJobTable.IndexOf(String));
	
EndProcedure

&AtClient
Procedure AddCopyEditScheduledJob(Val Action)
	
	If Items.ScheduledJobTable.CurrentData = Undefined Then
		ShowMessageBox(, NStr("en = 'Select a scheduled job.'"));
	Else
		FormParameters = New Structure;
		FormParameters.Insert("ID", Items.ScheduledJobTable.CurrentData.ID);
		FormParameters.Insert("Action", Action);
		
		OpenForm("DataProcessor.ScheduledAndBackgroundJobs.Form.ScheduledJob", FormParameters, ThisObject);
	EndIf;
	
EndProcedure

&AtClient
Procedure DeferredUpdate()
	
	RefreshDataAtServer();
	
EndProcedure

&AtServer
Procedure RefreshDataAtServer()
	
	UpdateScheduledJobTable();
	UpdateBackgroundJobTable();
	UpdateScheduledJobChoiceList();
	
EndProcedure

&AtServer
Procedure UpdateScheduledJobTable(ScheduledJobID = Undefined)

	// Updating the ScheduledJobs table and the ChoiceList list of the scheduled job for filter.
	CurrentJobs = ScheduledJobs.GetScheduledJobs();
	Table = ScheduledJobTable;
	
	SaaSJobs = New Map;
	SaaSOperationSubsystem = Metadata.Subsystems.StandardSubsystems.Subsystems.Find("SaaSOperations");
	If Not CommonUseCached.DataSeparationEnabled() And SaaSOperationSubsystem <> Undefined Then
		For Each MetadataObject In Metadata.ScheduledJobs Do
			If SaaSOperationSubsystem.Content.Contains(MetadataObject) Then
				SaaSJobs.Insert(MetadataObject.Name, True);
				Continue;
			EndIf;
			For Each Subsystem In SaaSOperationSubsystem.Subsystems Do
				If Subsystem.Content.Contains(MetadataObject) Then
					SaaSJobs.Insert(MetadataObject.Name, True);
					Continue;
				EndIf;
			EndDo;
		EndDo;
	EndIf;
	
	If ScheduledJobID = Undefined Then
		
		Index = 0;
		For Each Job In CurrentJobs Do
			If Not CommonUseCached.DataSeparationEnabled()
			   And SaaSJobs[Job.Metadata.Name] <> Undefined Then
				
				Continue;
			EndIf;
			
			ID = String(Job.UUID);
			
			If Index >= Table.Count() Or Table[Index].ID <> ID Then
				
				// Inserting a new job.
				Update = Table.Insert(Index);
				
				// Setting a unique ID.
				Update.ID = ID;
			Else
				Update = Table[Index];
			EndIf;
			UpdateScheduledJobTableRow(Update, Job);
			Index = Index + 1;
		EndDo;
	
		// Deleting unnecessary rows.
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
	
	BracketPosition = Find(Items.ScheduledJobs.Title, " (");
	If BracketPosition > 0 Then
		Items.ScheduledJobs.Title = Left(Items.ScheduledJobs.Title, BracketPosition - 1);
	EndIf;
	ItemsOnList = ScheduledJobTable.Count();
	If ItemsOnList > 0 Then
		Items.ScheduledJobs.Title = Items.ScheduledJobs.Title + " (" + Format(ItemsOnList, "NG=") + ")";
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdateScheduledJobTableRow(Row, Job)
	
	FillPropertyValues(Row, Job);
	
	// Description adjustment
	Row.Description = ScheduledJobsInternal.ScheduledJobPresentation(Job);
	
	// Setting the Completion date and the Completion state by the last background procedure
	LastBackgroundJobProperties = ScheduledJobsInternal
		.GetLastBackgroundJobForScheduledJobExecutionProperties(Job);
	
	If LastBackgroundJobProperties = Undefined Then
		
		Row.EndDate        = TextUndefined;
		Row.ExecutionState = TextUndefined;
	Else
		Row.EndDate        = ?(ValueIsFilled(LastBackgroundJobProperties.End),
		                       LastBackgroundJobProperties.End,
		                       "<>");
		Row.ExecutionState = LastBackgroundJobProperties.State;
	EndIf;
		
EndProcedure

&AtServer
Procedure UpdateBackgroundJobTable()
	
	// 1. Filter preparation.
	Filter = New Structure;
	
	// 1.1. Adding filter by state.
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
	
	// 1.2. Adding filter by scheduled job.
	If FilterByScheduledJob Then
		Filter.Insert(
				"ScheduledJobID",
				?(ScheduledJobForFilterID = EmptyID,
				"",
				ScheduledJobForFilterID));
	EndIf;
	
	// 1.3. Adding filter by period.
	If FilterKindByPeriod <> 0 Then
		RefreshAutomaticPeriod(ThisObject, CurrentSessionDate());
		Filter.Insert("Beginning", FilterPeriodFrom);
		Filter.Insert("End",       FilterPeriodTo);
	EndIf;
	
	// 2. Refreshing the background job list.
	Table = BackgroundJobTable;
	
	CurrentTable = ScheduledJobsInternal.GetBackgroundJobPropertyTable(Filter);
	
	Index = 0;
	For Each Job In CurrentTable Do
		
		If Index >= Table.Count() Or Table[Index].ID <> Job.ID Then
			// Inserting a new job.
			Update = Table.Insert(Index);
			// Setting a unique ID.
			Update.ID = Job.ID;
		Else
			Update = Table[Index];
		EndIf;
		
		FillPropertyValues(Update, Job);
		
		// Setting the scheduled job description from the ScheduledJobTable collection.
		If ValueIsFilled(Update.ScheduledJobID) Then
			
			Update.ScheduledJobID
				= Update.ScheduledJobID;
			
			Rows = ScheduledJobTable.FindRows(
				New Structure("ID", Update.ScheduledJobID));
			
			Update.ScheduledJobDescription
				= ?(Rows.Count() = 0, NStr("en = '<not found>'"), Rows[0].Description);
		Else
			Update.ScheduledJobDescription = TextUndefined;
			Update.ScheduledJobID          = TextUndefined;
		EndIf;
		
		// Getting error details.
		Update.UserMessagesAndErrorDetails 
			= ScheduledJobsInternal.BackgroundJobMessagesAndErrorDescriptions(
				Update.ID, Job);
		
		// Index increase
		Index = Index + 1;
	EndDo;
	
	// Deleting unnecessary rows.
	While Index < Table.Count() Do
		Table.Delete(Table.Count()-1);
	EndDo;
	
	Items.BackgroundJobTable.Refresh();
	
	BracketPosition = Find(Items.BackgroundJobs.Title, " (");
	If BracketPosition > 0 Then
		Items.BackgroundJobs.Title = Left(Items.BackgroundJobs.Title, BracketPosition - 1);
	EndIf;
	ItemsOnList = BackgroundJobTable.Count();
	If ItemsOnList > 0 Then
		Items.BackgroundJobs.Title = Items.BackgroundJobs.Title + " (" + Format(ItemsOnList, "NG=") + ")";
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Procedure RefreshAutomaticPeriod(Form, CurrentSessionDate)
	
	If Form.FilterKindByPeriod = 1 Then
		Form.FilterPeriodFrom  = BegOfDay(CurrentSessionDate) - 3*3600;
		Form.FilterPeriodTo = BegOfDay(CurrentSessionDate) + 9*3600;
		
	ElsIf Form.FilterKindByPeriod = 2 Then
		Form.FilterPeriodFrom  = BegOfDay(CurrentSessionDate) - 24*3600;
		Form.FilterPeriodTo = EndOfDay(Form.FilterPeriodFrom);
		
	ElsIf Form.FilterKindByPeriod = 3 Then
		Form.FilterPeriodFrom  = BegOfDay(CurrentSessionDate);
		Form.FilterPeriodTo = EndOfDay(Form.FilterPeriodFrom);
	EndIf;
	
EndProcedure

&AtServer
Procedure SetUseScheduledJob(Enabled)
	
	For Each SelectedRow In Items.ScheduledJobTable.SelectedRows Do
		CurrentData = ScheduledJobTable.FindByID(SelectedRow);
		Job = ScheduledJobsServer.GetScheduledJob(CurrentData.ID);
		If Job.Use <> Enabled Then
			Job.Use = Enabled;
			Job.Write();
			CurrentData.Use = Enabled;
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion
