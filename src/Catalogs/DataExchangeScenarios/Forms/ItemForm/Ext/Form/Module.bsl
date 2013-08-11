&AtClient
Var CurrentlyProcessedRowNumber;

&AtClient
Var RowCount;

////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	IsNew = (Object.Ref.IsEmpty());
	
	InfoBaseNode = Undefined;
	
	If IsNew
		And Parameters.Property("InfoBaseNode", InfoBaseNode)
		And InfoBaseNode <> Undefined Then
		
		Catalogs.DataExchangeScenarios.AddImportToDataExchangeScenarios(Object, InfoBaseNode);
		Catalogs.DataExchangeScenarios.AddExportToDataExchangeScenarios(Object, InfoBaseNode);
		
		Description = NStr("en = 'The data exchange script for %1'");
		Object.Description = StringFunctionsClientServer.SubstituteParametersInString(Description, String(InfoBaseNode));
		
		JobSchedule = Catalogs.DataExchangeScenarios.DefaultJobSchedule();
		
		Object.UseScheduledJob = True;
		
	Else
		
		// Getting a schedule from the scheduled jobs.
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

////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS

&AtClient
Procedure UseScheduledJobOnChange(Item)
	
	SetScheduleSetupHyperlinkEnabled();
	
EndProcedure

&AtClient
Procedure ScheduleContentOnActivateRow(Item)
	
	If Item.CurrentData = Undefined Then
		Return;
	EndIf;
	
	FillExchangeTransportKindChoiceList(Item.ChildItems.ExchangeSettingsExchangeTransportKind.ChoiceList, Item.CurrentData.InfoBaseNode);
	
EndProcedure

&AtClient
Procedure ExchangeSettingsInfoBaseNodeOnChange(Item)
	
	Items.ScheduleContent.CurrentData.ExchangeTransportKind = Undefined;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM TABLE EVENT HANDLERS OF ExchangeSettings TABLE 

&AtClient
Procedure ExchangeSettingsExchangeTransportKindStartChoice(Item, ChoiceData, StandardProcessing)
	
	CurrentData = Items.ScheduleContent.CurrentData;
	
	If CurrentData <> Undefined Then
		
		FillExchangeTransportKindChoiceList(Item.ChoiceList, CurrentData.InfoBaseNode);
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure ExecuteExchange(Command)
	
	IsNew = (Object.Ref.IsEmpty());
	
	If Modified Or IsNew Then
		
		Write();
		
	EndIf;
	
	CurrentlyProcessedRowNumber     = 1;
	RowCount = Object.ExchangeSettings.Count();
	
	AttachIdleHandler("ExecuteDataExchangeAtClient", 0.1, True);
	
EndProcedure

&AtClient
Procedure SetupJobSchedule(Command)
	
	EditJobSchedule();
	
	RefreshSchedulePresentation();
	
EndProcedure

&AtClient
Procedure TransportSettings(Command)
	
	CurrentData = Items.ScheduleContent.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	ElsIf Not ValueIsFilled(CurrentData.InfoBaseNode) Then
		Return;
	EndIf;
	
	Filter        = New Structure("Node", CurrentData.InfoBaseNode);
	FillingValues = New Structure("Node", CurrentData.InfoBaseNode);
	
	DataExchangeClient.OpenInformationRegisterRecordFormByFilter(Filter, FillingValues, "ExchangeTransportSettings", ThisForm);
	
EndProcedure

&AtClient
Procedure GoToEventLog(Command)
	
	CurrentData = Items.ScheduleContent.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	DataExchangeClient.GoToDataEventLogModally(CurrentData.InfoBaseNode,
																	ThisForm,
																	CurrentData.CurrentAction);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

&AtClient
Procedure EditJobSchedule()
	
	// Creating a new schedule if it was not initialized by a form handler on the server
	If JobSchedule = Undefined Then
		
		JobSchedule = New JobSchedule;
		
	EndIf;
	
	Dialog = New ScheduledJobDialog(JobSchedule);
	
	// Open a dialog for editing the schedule
	If Dialog.DoModal() Then
		
		JobSchedule = Dialog.Schedule;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure RefreshSchedulePresentation()
	
	SchedulePresentation = String(JobSchedule);
	
	If SchedulePresentation = String(New JobSchedule) Then
		
		SchedulePresentation = NStr("en = 'The schedule is not specified.'");
		
	EndIf;
	
	Items.SetupJobSchedule.Title = SchedulePresentation;
	
EndProcedure

&AtClient
Procedure SetScheduleSetupHyperlinkEnabled()
	
	Items.SetupJobSchedule.Enabled = Object.UseScheduledJob;
	
EndProcedure

&AtClient
Procedure ExecuteDataExchangeAtClient()
	
	If CurrentlyProcessedRowNumber > RowCount Then // exiting from the recursion
		ShowProgress = (RowCount > 1);
		Status(NStr("en = 'Data exchange executed.'"), ?(ShowProgress, 100, Undefined));
		Return; 
	EndIf;
	
	CurrentData = Object.ExchangeSettings[CurrentlyProcessedRowNumber - 1];
	
	// Progress bar value
	ShowProgress = (RowCount > 1);
	
	MessageString = NStr("en = 'Executing %1 for %2'");
	MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, 
							String(CurrentData.CurrentAction),
							String(CurrentData.InfoBaseNode));
	
	Progress = Round(100 * (CurrentlyProcessedRowNumber -1) / ?(RowCount = 0, 1, RowCount));
	Status(MessageString, ?(ShowProgress, Progress, Undefined));
	
	// Starting exchange by the setting row
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
	|	DataExchangeScenariosExchangeSettings.InfoBaseNode,
	|	DataExchangeScenariosExchangeSettings.ExchangeTransportKind,
	|	DataExchangeScenariosExchangeSettings.CurrentAction,
	|	DataExchangeScenariosExchangeSettings.TransactionItemCount,
	|	CASE
	|	WHEN DataExchangeStates.ExchangeExecutionResult IS NULL
	|	THEN 0
	|	WHEN DataExchangeStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.Warning_ExchangeMessageReceivedPreviously)
	|	THEN 3
	|	WHEN DataExchangeStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.CompletedWithWarnings)
	|	THEN 3
	|	WHEN DataExchangeStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.Completed)
	|	THEN 2
	|	ELSE 1
	|	END AS ExchangeExecutionResult
	|FROM
	|	Catalog.DataExchangeScenarios.ExchangeSettings AS DataExchangeScenariosExchangeSettings
	|LEFT JOIN InformationRegister.DataExchangeStates AS DataExchangeStates
	|		ON DataExchangeStates.InfoBaseNode = DataExchangeScenariosExchangeSettings.InfoBaseNode
	|	 AND DataExchangeStates.ActionOnExchange      = DataExchangeScenariosExchangeSettings.CurrentAction
	|WHERE
	|	DataExchangeScenariosExchangeSettings.Ref = &Ref
	|ORDER  BY
	|	DataExchangeScenariosExchangeSettings.RowNumber ASC
	|";
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("Ref", Object.Ref);
	
	Object.ExchangeSettings.Load(Query.Execute().Unload());
	
EndProcedure

&AtServer
Procedure ExecuteDataExchangeBySettingRow(Val Index)
	
	Cancel = False;
	
	// Starting the exchange
	DataExchangeServer.ExecuteDataExchangeByDataExchangeScenario(Cancel, Object.Ref, Index);
	
	// Updating exchange script tabular section data
	RefreshDataExchangeStates();
	
EndProcedure

&AtClient
Procedure FillExchangeTransportKindChoiceList(ChoiceList, InfoBaseNode)
	
	ChoiceList.Clear();
	
	If ValueIsFilled(InfoBaseNode) Then
		
		UsedTransports = DataExchangeCached.UsedExchangeMessageTransports(InfoBaseNode);
		
		For Each Item In UsedTransports Do
			
			ChoiceList.Add(Item, String(Item));
			
		EndDo;
		
	EndIf;
	
EndProcedure







