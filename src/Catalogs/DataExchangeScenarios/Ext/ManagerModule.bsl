#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region InternalProceduresAndFunctions

Procedure CreateScenario(InfobaseNode, Schedule = Undefined) Export
	
	Cancel = False;
	
	Description = NStr("en = 'Automatic synchronization with %1'");
	Description = StringFunctionsClientServer.SubstituteParametersInString(Description,
			CommonUse.ObjectAttributeValue(InfobaseNode, "Description"));
	
	ExchangeTransportKind = InformationRegisters.ExchangeTransportSettings.DefaultExchangeMessageTransportKind(InfobaseNode);
	
	DataExchangeScenario = Catalogs.DataExchangeScenarios.CreateItem();
	
	// Filling header attributes
	DataExchangeScenario.Description = Description;
	DataExchangeScenario.UseScheduledJob = True;
	
	// Creating a scheduled job
	UpdateScheduledJobData(Cancel, Schedule, DataExchangeScenario);
	
	// Tabular section
	TableRow = DataExchangeScenario.ExchangeSettings.Add();
	TableRow.ExchangeTransportKind = ExchangeTransportKind;
	TableRow.CurrentAction = Enums.ActionsOnExchange.DataImport;
	TableRow.InfobaseNode = InfobaseNode;
	
	TableRow = DataExchangeScenario.ExchangeSettings.Add();
	TableRow.ExchangeTransportKind = ExchangeTransportKind;
	TableRow.CurrentAction = Enums.ActionsOnExchange.DataExport;
	TableRow.InfobaseNode = InfobaseNode;
	
	DataExchangeScenario.Write();
	
EndProcedure

Function DefaultJobSchedule() Export
	
	Months = New Array;
	Months.Add(1);
	Months.Add(2);
	Months.Add(3);
	Months.Add(4);
	Months.Add(5);
	Months.Add(6);
	Months.Add(7);
	Months.Add(8);
	Months.Add(9);
	Months.Add(10);
	Months.Add(11);
	Months.Add(12);
	
	WeekDays = New Array;
	WeekDays.Add(1);
	WeekDays.Add(2);
	WeekDays.Add(3);
	WeekDays.Add(4);
	WeekDays.Add(5);
	WeekDays.Add(6);
	WeekDays.Add(7);
	
	Schedule = New JobSchedule;
	Schedule.WeekDays          = WeekDays;
	Schedule.RepeatPeriodInDay = 900; // 15 minutes
	Schedule.DaysRepeatPeriod  = 1; // every day
	Schedule.Months            = Months;
	
	Return Schedule;
EndFunction

// Returns the exchange plan node reference that is specified in the first row of exchange 
// execution settings.
//  
// Parameters:
//  ExchangeExecutionSettings - CatalogRef.DataExchangeScenarios - exchange settings. The exchange plan node 
//                              is retrieved from these settings.
//  
// Returns:
//  
// ExchangePlanRef - exchange plan node reference that is specified in the 
//                   first row of exchange execution settings.
//                   The function returns Undefined if the settings contain no rows.
//
Function GetInfobaseNodeFromFirstSettingsRow(ExchangeExecutionSettings) Export
	
	// Return value
	InfobaseNode = Undefined;
	
	If ExchangeExecutionSettings.IsEmpty() Then
		Return InfobaseNode;
	EndIf;
	
	QueryText = "
	|SELECT TOP 1
	|	ExchangeExecutionSettingsExchangeSettings.InfobaseNode AS InfobaseNode
	|FROM
	|	Catalog.DataExchangeScenarios.ExchangeSettings AS ExchangeExecutionSettingsExchangeSettings
	|WHERE
	|	ExchangeExecutionSettingsExchangeSettings.Ref = &Ref
	|";
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("Ref", ExchangeExecutionSettings);
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		
		InfobaseNode = Selection.InfobaseNode;
		
	EndIf;
	
	Return InfobaseNode;
EndFunction

// Retrieves the job schedule. 
// If the scheduled job is not specified, the function returns an empty schedule.
Function GetDataExchangeExecutionSchedule(ExchangeExecutionSettings) Export
	
	ScheduledJobObject = DataExchangeServerCall.FindScheduledJobByParameter(ExchangeExecutionSettings.ScheduledJobGUID);
	
	If ScheduledJobObject <> Undefined Then
		
		JobSchedule = ScheduledJobObject.Schedule;
		
	Else
		
		JobSchedule = New JobSchedule;
		
	EndIf;
	
	Return JobSchedule;
	
EndFunction

Procedure UpdateScheduledJobData(Cancel, JobSchedule, CurrentObject) Export
	
	// Getting the scheduled job by ID. If the scheduled job is not found, a new one is created.
	ScheduledJobObject = CreateScheduledJobIfNecessary(Cancel, CurrentObject);
	
	If Cancel Then
		Return;
	EndIf;
	
	// Updating scheduled job properties
	SetScheduledJobParameters(ScheduledJobObject, JobSchedule, CurrentObject);
	
	// Writing the modified scheduled job
	WriteScheduledJob(Cancel, ScheduledJobObject);
	
	// Storing the scheduled job GUID in object attributes
	CurrentObject.ScheduledJobGUID = String(ScheduledJobObject.UUID);
	
EndProcedure

Function CreateScheduledJobIfNecessary(Cancel, CurrentObject)
	
	ScheduledJobObject = DataExchangeServerCall.FindScheduledJobByParameter(CurrentObject.ScheduledJobGUID);
	
	// Creating a scheduled job if necessary
	If ScheduledJobObject = Undefined Then
		
		ScheduledJobObject = ScheduledJobs.CreateScheduledJob("DataSynchronization");
		
	EndIf;
	
	Return ScheduledJobObject;
	
EndFunction

Procedure SetScheduledJobParameters(ScheduledJobObject, JobSchedule, CurrentObject)
	
	If IsBlankString(CurrentObject.Code) Then
		
		CurrentObject.SetNewCode();
		
	EndIf;
	
	ScheduledJobParameters = New Array;
	ScheduledJobParameters.Add(CurrentObject.Code);
	
	ScheduledJobDescription = NStr("en = 'Exchange with the following scenario: %1'");
	ScheduledJobDescription = StringFunctionsClientServer.SubstituteParametersInString(ScheduledJobDescription, TrimAll(CurrentObject.Description));
	
	ScheduledJobObject.Description  = Left(ScheduledJobDescription, 120);
	ScheduledJobObject.Use          = CurrentObject.UseScheduledJob;
	ScheduledJobObject.Parameters   = ScheduledJobParameters;
	
	// Updating the schedule if it is modified
	If JobSchedule <> Undefined Then
		ScheduledJobObject.Schedule = JobSchedule;
	EndIf;
	
EndProcedure

// Writes a scheduled job.
//
// Parameters:
//  Cancel             - Boolean - cancellation flag. 
//                       It is set to True if errors occur during the procedure execution. 
//  ScheduledJobObject - scheduled job object to be written.
// 
Procedure WriteScheduledJob(Cancel, ScheduledJobObject)
	
	SetPrivilegedMode(True);
	
	Try
		
		// Writing the scheduled job
		ScheduledJobObject.Write();
		
	Except
		
		MessageString = NStr("en = 'Error writing the synchronization schedule. Error details: %1'");
		MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, BriefErrorDescription(ErrorInfo()));
		DataExchangeServer.ReportError(MessageString, Cancel);
		
	EndTry;
	
EndProcedure

// Deletes a specific node from all synchronization scenarios.
// If the node deletion leaves some scenario empty, the scenario is also deleted.
//
Procedure ClearReferencesToInfobaseNode(Val InfobaseNode) Export
	
	If CommonUseCached.DataSeparationEnabled()
		And CommonUseCached.CanUseSeparatedData() Then
		Return;
	EndIf;
	
	QueryText = "
	|SELECT DISTINCT
	|	DataExchangeScenarioExchangeSettings.Ref AS DataExchangeScenario
	|FROM
	|	Catalog.DataExchangeScenarios.ExchangeSettings AS DataExchangeScenarioExchangeSettings
	|WHERE
	|	DataExchangeScenarioExchangeSettings.InfobaseNode = &InfobaseNode
	|";
	
	Query = New Query;
	Query.SetParameter("InfobaseNode", InfobaseNode);
	Query.Text = QueryText;
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		DataExchangeScenario = Selection.DataExchangeScenario.GetObject();
		
		DeleteExportFromDataExchangeScenario(DataExchangeScenario, InfobaseNode);
		DeleteImportFromDataExchangeScenario(DataExchangeScenario, InfobaseNode);
		
		DataExchangeScenario.Write();
		
		If DataExchangeScenario.ExchangeSettings.Count() = 0 Then
			DataExchangeScenario.Delete();
		EndIf;
		
	EndDo;
	
EndProcedure


Procedure DeleteExportFromDataExchangeScenario(DataExchangeScenario, InfobaseNode) Export
	
	DeleteRowInDataExchangeScenario(DataExchangeScenario, InfobaseNode, Enums.ActionsOnExchange.DataExport);
	
EndProcedure

Procedure DeleteImportFromDataExchangeScenario(DataExchangeScenario, InfobaseNode) Export
	
	DeleteRowInDataExchangeScenario(DataExchangeScenario, InfobaseNode, Enums.ActionsOnExchange.DataImport);
	
EndProcedure

Procedure AddExportToDataExchangeScenarios(DataExchangeScenario, InfobaseNode) Export
	
	MustWriteObject = False;
	
	If TypeOf(DataExchangeScenario) = Type("CatalogRef.DataExchangeScenarios") Then
		
		DataExchangeScenario = DataExchangeScenario.GetObject();
		
		MustWriteObject = True;
		
	EndIf;
	
	ExchangeTransportKind = InformationRegisters.ExchangeTransportSettings.DefaultExchangeMessageTransportKind(InfobaseNode);
	
	ExchangeSettings = DataExchangeScenario.ExchangeSettings;
	
	// Adding the data export in a loop
	MaxIndex = ExchangeSettings.Count() - 1;
	
	For Index = 0 To MaxIndex Do
		
		ReverseIndex = MaxIndex - Index;
		
		TableRow = ExchangeSettings[ReverseIndex];
		
		If TableRow.CurrentAction = Enums.ActionsOnExchange.DataExport Then // the last export row
			
			NewRow = ExchangeSettings.Insert(ReverseIndex + 1);
			
			NewRow.InfobaseNode          = InfobaseNode;
			NewRow.ExchangeTransportKind = ExchangeTransportKind;
			NewRow.CurrentAction         = Enums.ActionsOnExchange.DataExport;
			
			Break;
		EndIf;
		
	EndDo;
	
	// If the row was not added in the loop, adding the row to the end of the table
	Filter = New Structure("InfobaseNode, CurrentAction", InfobaseNode, Enums.ActionsOnExchange.DataExport);
	If ExchangeSettings.FindRows(Filter).Count() = 0 Then
		
		NewRow = ExchangeSettings.Add();
		
		NewRow.InfobaseNode = InfobaseNode;
		NewRow.ExchangeTransportKind    = ExchangeTransportKind;
		NewRow.CurrentAction    = Enums.ActionsOnExchange.DataExport;
		
	EndIf;
	
	If MustWriteObject Then
		
		// Writing object changes
		DataExchangeScenario.Write();
		
	EndIf;
	
EndProcedure

Procedure AddImportToDataExchangeScenarios(DataExchangeScenario, InfobaseNode) Export
	
	MustWriteObject = False;
	
	If TypeOf(DataExchangeScenario) = Type("CatalogRef.DataExchangeScenarios") Then
		
		DataExchangeScenario = DataExchangeScenario.GetObject();
		
		MustWriteObject = True;
		
	EndIf;
	
	ExchangeTransportKind = InformationRegisters.ExchangeTransportSettings.DefaultExchangeMessageTransportKind(InfobaseNode);
	
	ExchangeSettings = DataExchangeScenario.ExchangeSettings;
	
	// Adding data import in a loop
	For Each TableRow In ExchangeSettings Do
		
		If TableRow.CurrentAction = Enums.ActionsOnExchange.DataImport Then // the first import row
			
			NewRow = ExchangeSettings.Insert(ExchangeSettings.IndexOf(TableRow));
			
			NewRow.InfobaseNode = InfobaseNode;
			NewRow.ExchangeTransportKind    = ExchangeTransportKind;
			NewRow.CurrentAction    = Enums.ActionsOnExchange.DataImport;
			
			Break;
		EndIf;
		
	EndDo;
	
	// If the row was not added in the loop, adding the row to the beginning of the table
	Filter = New Structure("InfobaseNode, CurrentAction", InfobaseNode, Enums.ActionsOnExchange.DataImport);
	If ExchangeSettings.FindRows(Filter).Count() = 0 Then
		
		NewRow = ExchangeSettings.Insert(0);
		
		NewRow.InfobaseNode = InfobaseNode;
		NewRow.ExchangeTransportKind    = ExchangeTransportKind;
		NewRow.CurrentAction    = Enums.ActionsOnExchange.DataImport;
		
	EndIf;
	
	If MustWriteObject Then
		
		// Writing object changes
		DataExchangeScenario.Write();
		
	EndIf;
	
EndProcedure

Procedure DeleteRowInDataExchangeScenario(DataExchangeScenario, InfobaseNode, ActionOnExchange)
	
	MustWriteObject = False;
	
	If TypeOf(DataExchangeScenario) = Type("CatalogRef.DataExchangeScenarios") Then
		
		DataExchangeScenario = DataExchangeScenario.GetObject();
		
		MustWriteObject = True;
		
	EndIf;
	
	ExchangeSettings = DataExchangeScenario.ExchangeSettings;
	
	MaxIndex = ExchangeSettings.Count() - 1;
	
	For Index = 0 To MaxIndex Do
		
		ReverseIndex = MaxIndex - Index;
		
		TableRow = ExchangeSettings[ReverseIndex];
		
		If  TableRow.InfobaseNode = InfobaseNode
			And TableRow.CurrentAction = ActionOnExchange Then
			
			ExchangeSettings.Delete(ReverseIndex);
			
		EndIf;
		
	EndDo;
	
	If MustWriteObject Then
		
		// Writing object changes
		DataExchangeScenario.Write();
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Batch object modification

// Returns a list of attributes that are excluded from the scope of the batch object
// modification data processor
//
Function AttributesToSkipOnGroupProcessing() Export
	
	Result = New Array;
	Result.Add("ScheduledJobGUID");
	Return Result;
	
EndFunction

#EndRegion

#EndIf
