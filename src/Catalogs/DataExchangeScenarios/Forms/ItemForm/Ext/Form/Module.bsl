&AtClient
Var CurrentlyProcessedRowNumber;

&AtClient
Var LineCount;

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
  
  // Skipping the initialization to guarantee that the form 
  // will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then
		Return;
	EndIf;
	
	IsNew = (Object.Ref.IsEmpty());
	
	InfobaseNode = Undefined;
	
	If IsNew
		And Parameters.Property("InfobaseNode", InfobaseNode)
		And InfobaseNode <> Undefined Then
		
		Catalogs.DataExchangeScenarios.AddImportToDataExchangeScenarios(Object, InfobaseNode);
		Catalogs.DataExchangeScenarios.AddExportToDataExchangeScenarios(Object, InfobaseNode);
		
		Description = NStr("en = 'Synchronization scenario for %1'");
		Object.Description = StringFunctionsClientServer.SubstituteParametersInString(Description, String(InfobaseNode));
		
		JobSchedule = Catalogs.DataExchangeScenarios.DefaultJobSchedule();
		
		Object.UseScheduledJob = True;
		
	Else
		
		// Getting a schedule from the scheduled job.
		// If the scheduled job is not specified, the schedule is Undefined and it will be created on the client during editing.
		JobSchedule = Catalogs.DataExchangeScenarios.GetDataExchangeExecutionSchedule(Object.Ref);
		
	EndIf;
	
	If Not IsNew Then
		
		RefreshDataExchangeStates();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	RefreshSchedulePresentation();
	
	SetScheduleSetupHyperlinkEnabled();
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject)
	
	Catalogs.DataExchangeScenarios.UpdateScheduledJobData(Cancel, JobSchedule, CurrentObject);
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("Write_DataExchangeScenarios", WriteParameters, Object.Ref);
	
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure UseScheduledJobOnChange(Item)
	
	SetScheduleSetupHyperlinkEnabled();
	
EndProcedure

&AtClient
Procedure ScheduleContentOnActivateRow(Item)
	
	If Item.CurrentData = Undefined Then
		Return;
	EndIf;
	
	FillExchangeTransportTypeChoiceList(Item.ChildItems.ExchangeSettingsExchangeTransportKind.ChoiceList, Item.CurrentData.InfobaseNode);
	
EndProcedure

&AtClient
Procedure ExchangeSettingsInfobaseNodeOnChange(Item)
	
	Items.ScheduleContent.CurrentData.ExchangeTransportKind = Undefined;
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonUseClient.ShowCommentEditingForm(Item.EditText, 
		ThisObject, "Object.Comment");
	
EndProcedure

#EndRegion

#Region ExchangeSettingsFormTableItemEventHandlers

&AtClient
Procedure ExchangeSettingsExchangeTransportKindStartChoice(Item, ChoiceData, StandardProcessing)
	
	CurrentData = Items.ScheduleContent.CurrentData;
	
	If CurrentData <> Undefined Then
		
		FillExchangeTransportTypeChoiceList(Item.ChoiceList, CurrentData.InfobaseNode);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ExecuteExchange(Command)
	
	IsNew = (Object.Ref.IsEmpty());
	
	If Modified Or IsNew Then
		
		Write();
		
	EndIf;
	
	CurrentlyProcessedRowNumber = 1;
	LineCount = Object.ExchangeSettings.Count();
	
	AttachIdleHandler("ExecuteDataExchangeAtClient", 0.1, True);
	
EndProcedure

&AtClient
Procedure SetJobSchedule(Command)
	
	EditJobSchedule();
	
	RefreshSchedulePresentation();
	
EndProcedure

&AtClient
Procedure TransportSettings(Command)
	
	CurrentData = Items.ScheduleContent.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	ElsIf Not ValueIsFilled(CurrentData.InfobaseNode) Then
		Return;
	EndIf;
	
	Filter        = New Structure("Node", CurrentData.InfobaseNode);
	FillingValues = New Structure("Node", CurrentData.InfobaseNode);
	
	DataExchangeClient.OpenInformationRegisterRecordFormByFilter(Filter, FillingValues, "ExchangeTransportSettings", ThisObject);
	
EndProcedure

&AtClient
Procedure GoToEventLog(Command)
	
	CurrentData = Items.ScheduleContent.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	DataExchangeClient.GoToDataEventLogModally(CurrentData.InfobaseNode,
																	ThisObject,
																	CurrentData.CurrentAction);
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtClient
Procedure EditJobSchedule()
	
	// Creating a new schedule if it was not initialized by a form handler on the server
	If JobSchedule = Undefined Then
		
		JobSchedule = New JobSchedule;
		
	EndIf;
	
	Dialog = New ScheduledJobDialog(JobSchedule);
	
	// Opening a dialog for editing the schedule
	NotifyDescription = New NotifyDescription("EditJobScheduleCompletion", ThisObject);
	Dialog.Show(NotifyDescription);
	
EndProcedure

&AtClient
Procedure EditJobScheduleCompletion(Schedule, AdditionalParameters) Export
	
	If Schedule <> Undefined Then
		
		JobSchedule = Schedule;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure RefreshSchedulePresentation()
	
	SchedulePresentation = String(JobSchedule);
	
	If SchedulePresentation = String(New JobSchedule) Then
		
		SchedulePresentation = NStr("en = 'The schedule is not set'");
		
	EndIf;
	
	Items.SetJobSchedule.Title = SchedulePresentation;
	
EndProcedure

&AtClient
Procedure SetScheduleSetupHyperlinkEnabled()
	
	Items.SetJobSchedule.Enabled = Object.UseScheduledJob;
	
EndProcedure

&AtClient
Procedure ExecuteDataExchangeAtClient()
	
	If CurrentlyProcessedRowNumber > LineCount Then // exiting from the recursion
		ShowProgress = (LineCount > 1);
		Status(NStr("en = 'Synchronization completed.'"), ?(ShowProgress, 100, Undefined));
		Return; // exiting
	EndIf;
	
	CurrentData = Object.ExchangeSettings[CurrentlyProcessedRowNumber - 1];
	
	ShowProgress = (LineCount > 1);
	
	MessageString = NStr("en = 'Executing %1 for %2'");
	MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, 
							String(CurrentData.CurrentAction),
							String(CurrentData.InfobaseNode));
 
	Progress = Round(100 * (CurrentlyProcessedRowNumber -1) / ?(LineCount = 0, 1, LineCount));
	Status(MessageString, ?(ShowProgress, Progress, Undefined));
	
	// Starting exchange by setting row
	ExecuteDataExchangeBySettingRow(CurrentlyProcessedRowNumber);
	
	UserInterruptProcessing();
	
	CurrentlyProcessedRowNumber = CurrentlyProcessedRowNumber + 1;
	
	// Calling this procedure recursively
	AttachIdleHandler("ExecuteDataExchangeAtClient", 0.1, True);
	
EndProcedure

&AtServer
Procedure RefreshDataExchangeStates()
	
	QueryText = "
	|SELECT
	|	DataExchangeScenarioExchangeSettings.InfobaseNode,
	|	DataExchangeScenarioExchangeSettings.ExchangeTransportKind,
	|	DataExchangeScenarioExchangeSettings.CurrentAction,
	|	CASE
	|	WHEN DataExchangeStates.ExchangeExecutionResult IS NULL
	|	THEN 0
	|	WHEN DataExchangeStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.Warning_ExchangeMessageReceivedPreviously)
	|	THEN 2
	|	WHEN DataExchangeStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.CompletedWithWarnings)
	|	THEN 2
	|	WHEN DataExchangeStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.Completed)
	|	THEN 0
	|	ELSE 1
	|	END AS ExchangeExecutionResult
	|FROM
	|	Catalog.DataExchangeScenarios.ExchangeSettings AS DataExchangeScenarioExchangeSettings
	|LEFT JOIN InformationRegister.DataExchangeStates AS DataExchangeStates
	|	ON DataExchangeStates.InfobaseNode = DataExchangeScenarioExchangeSettings.InfobaseNode
	|	 AND DataExchangeStates.ActionOnExchange      = DataExchangeScenarioExchangeSettings.CurrentAction
	|WHERE
	|	DataExchangeScenarioExchangeSettings.Ref = &Ref
	|ORDER BY
	|	DataExchangeScenarioExchangeSettings.LineNumber ASC
	|";
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("Ref", Object.Ref);
	
	Object.ExchangeSettings.Load(Query.Execute().Unload());
	
EndProcedure

&AtServer
Procedure ExecuteDataExchangeBySettingRow(Val Index)
	
	Cancel = False;
	
	// Starting synchronization
	DataExchangeServer.ExecuteDataExchangeUsingDataExchangeScenario(Cancel, Object.Ref, Index);
	
	// Updating tabular section data of the synchronization scenario
	RefreshDataExchangeStates();
	
EndProcedure

&AtClient
Procedure FillExchangeTransportTypeChoiceList(ChoiceList, InfobaseNode)
	
	ChoiceList.Clear();
	
	If ValueIsFilled(InfobaseNode) Then
		
		For Each Item In UsedExchangeMessageTransports(InfobaseNode) Do
			
			ChoiceList.Add(Item, String(Item));
			
		EndDo;
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function UsedExchangeMessageTransports(Val InfobaseNode)
	
	Return DataExchangeCached.UsedExchangeMessageTransports(InfobaseNode);
	
EndFunction

#EndRegion
