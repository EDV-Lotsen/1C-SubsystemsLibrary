////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

Procedure CreateScenario(InfoBaseNode, Schedule = Undefined) Export
	
	Cancel = False;
	
	Description = NStr("en = 'Automatic data exchange with %1'");
	Description = StringFunctionsClientServer.SubstituteParametersInString(Description,
			CommonUse.GetAttributeValue(InfoBaseNode, "Description")
	);
	
	ExchangeTransportKind = InformationRegisters.ExchangeTransportSettings.DefaultExchangeMessageTransportKind(InfoBaseNode);
	
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
	TableRow.TransactionItemCount = 200;
	TableRow.InfoBaseNode = InfoBaseNode;
	
	TableRow = DataExchangeScenario.ExchangeSettings.Add();
	TableRow.ExchangeTransportKind = ExchangeTransportKind;
	TableRow.CurrentAction = Enums.ActionsOnExchange.DataExport;
	TableRow.TransactionItemCount = 200;
	TableRow.InfoBaseNode = InfoBaseNode;
	
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
	Schedule.DaysRepeatPeriod  = 1;   // every day
	Schedule.Months            = Months;
	
	Return Schedule;
EndFunction

// Returns the exchange plan node reference that is specified in the first exchange 
// execution settings row.
//  
// Parameters:
//  ExchangeExecutionSettings - CatalogRef.DataExchangeScenarios - exchange settings from
//                              which the exchange plan node will be retrieved.
//  
// Returns:  
// ExchangePlanRef            - exchange plan node reference that is specified in the  
//                              first exchange execution settings row.
//                            - Undefined if settings contain no rows.
//
Function GetInfoBaseNodeFromFirstSettingsRow(ExchangeExecutionSettings) Export
	
	// Return value
	InfoBaseNode = Undefined;
	
	If ExchangeExecutionSettings.Empty() Then
		Return InfoBaseNode;
	EndIf;
	
	QueryText = "
	|SELECT TOP 1
	|	ExchangeExecutionSettingsExchangeSettings.InfoBaseNode AS InfoBaseNode
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
		
		Selection = QueryResult.Choose();
		Selection.Next();
		
		InfoBaseNode = Selection.InfoBaseNode;
		
	EndIf;
	
	Return InfoBaseNode;
EndFunction

// Retrieves the job schedule. If the job is not specified, the procedure returns an
// empty schedule.
Function GetDataExchangeExecutionSchedule(ExchangeExecutionSettings) Export
	
	ScheduledJobObject = DataExchangeServer.FindScheduledJobByParameter(ExchangeExecutionSettings.ScheduledJobGUID);
	
	If ScheduledJobObject <> Undefined Then
		
		JobSchedule = ScheduledJobObject.Schedule;
		
	Else
		
		JobSchedule = New JobSchedule;
		
	EndIf;
	
	Return JobSchedule;
	
EndFunction

Procedure UpdateScheduledJobData(Cancel, JobSchedule, CurrentObject) Export
	
	// Getting the scheduled job by ID. If the scheduled job is not found, a new one will be created.
	ScheduledJobObject = CreateScheduledJobIfNecessary(Cancel, CurrentObject);
	
	If Cancel Then
		Return;
	EndIf;
	
	// Updating scheduled job properties
	SetScheduledJobParameters(ScheduledJobObject, JobSchedule, CurrentObject);
	
	// Writing the modified job
	WriteScheduledJob(Cancel, ScheduledJobObject);
	
	// Storing the scheduled job GUID in the object attribute.
	CurrentObject.ScheduledJobGUID = String(ScheduledJobObject.UUID);
	
EndProcedure

Function CreateScheduledJobIfNecessary(Cancel, CurrentObject)
	
	ScheduledJobObject = DataExchangeServer.FindScheduledJobByParameter(CurrentObject.ScheduledJobGUID);
	
	// Creating a scheduled job, if necessary 
	If ScheduledJobObject = Undefined Then
		
		ScheduledJobObject = ScheduledJobs.CreateScheduledJob("DataExchangeExecution");
		
	EndIf;
	
	Return ScheduledJobObject;
	
EndFunction

Procedure SetScheduledJobParameters(ScheduledJobObject, JobSchedule, CurrentObject)
	
	If IsBlankString(CurrentObject.Code) Then
		
		CurrentObject.SetNewCode();
		
	EndIf;
	
	ScheduledJobParameters = New Array;
	ScheduledJobParameters.Add(CurrentObject.Code);
	
	ScheduledJobDescription = NStr("en = 'Executing exchange with the following script: %1'");
	ScheduledJobDescription = StringFunctionsClientServer.SubstituteParametersInString(ScheduledJobDescription, TrimAll(CurrentObject.Description));
	
	ScheduledJobObject.Description = Left(ScheduledJobDescription, 120);
	ScheduledJobObject.Use         = CurrentObject.UseScheduledJob;
	ScheduledJobObject.Parameters  = ScheduledJobParameters;
	
	// Updating the schedule if it is modified
	If JobSchedule <> Undefined Then
		ScheduledJobObject.Schedule = JobSchedule;
	EndIf;
	
EndProcedure

// Writing the scheduled job.
//
// Parameters:
//  Cancel             - Boolean – cancel flag. It is set to True if errors occur
//                       during the procedure execution.
//  ScheduledJobObject - scheduled job object to be written.
// 
Procedure WriteScheduledJob(Cancel, ScheduledJobObject)
	
	SetPrivilegedMode(True);
	
	Try
		
		// Writing the job
		ScheduledJobObject.Write();
		
	Except
		
		MessageString = NStr("en = 'Error writing the exchange schedule. Error details: %1'");
		MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, BriefErrorDescription(ErrorInfo()));
		DataExchangeServer.ReportError(MessageString, Cancel);
		
	EndTry;
	
EndProcedure

Procedure DeleteExportFromDataExchangeScenario(DataExchangeScenario, InfoBaseNode) Export
	
	DeleteRowInDataExchangeScenario(DataExchangeScenario, InfoBaseNode, Enums.ActionsOnExchange.DataExport);
	
EndProcedure

Procedure DeleteImportFromDataExchangeScenario(DataExchangeScenario, InfoBaseNode) Export
	
	DeleteRowInDataExchangeScenario(DataExchangeScenario, InfoBaseNode, Enums.ActionsOnExchange.DataImport);
	
EndProcedure

Procedure AddExportToDataExchangeScenarios(DataExchangeScenario, InfoBaseNode) Export
	
	MustWriteObject = False;
	
	If TypeOf(DataExchangeScenario) = Type("CatalogRef.DataExchangeScenarios") Then
		
		DataExchangeScenario = DataExchangeScenario.GetObject();
		
		MustWriteObject = True;
		
	EndIf;
	
	ExchangeTransportKind = InformationRegisters.ExchangeTransportSettings.DefaultExchangeMessageTransportKind(InfoBaseNode);
	
	ExchangeSettings = DataExchangeScenario.ExchangeSettings;
	
	// Adding the data export in a loop
	MaxIndex = ExchangeSettings.Count() - 1;
	
	For Index = 0 to MaxIndex Do
		
		ReverseIndex = MaxIndex - Index;
		
		TableRow = ExchangeSettings[ReverseIndex];
		
		If TableRow.CurrentAction = Enums.ActionsOnExchange.DataExport Then // the last export row
			
			NewRow = ExchangeSettings.Insert(ReverseIndex + 1);
			
			NewRow.InfoBaseNode = InfoBaseNode;
			NewRow.ExchangeTransportKind    = ExchangeTransportKind;
			NewRow.CurrentAction    = Enums.ActionsOnExchange.DataExport;
			NewRow.TransactionItemCount = 0;
			
			Break;
		EndIf;
		
	EndDo;
	
	// If the row was not added in the loop, adding the row to the end of the table
	Filter = New Structure("InfoBaseNode, CurrentAction", InfoBaseNode, Enums.ActionsOnExchange.DataExport);
	If ExchangeSettings.FindRows(Filter).Count() = 0 Then
		
		NewRow = ExchangeSettings.Add();
		
		NewRow.InfoBaseNode = InfoBaseNode;
		NewRow.ExchangeTransportKind = ExchangeTransportKind;
		NewRow.CurrentAction        = Enums.ActionsOnExchange.DataExport;
		NewRow.TransactionItemCount  = 0;
		
	EndIf;
	
	If MustWriteObject Then
		
		// Writing object changes
		DataExchangeScenario.Write();
		
	EndIf;
	
EndProcedure

Procedure AddImportToDataExchangeScenarios(DataExchangeScenario, InfoBaseNode) Export
	
	MustWriteObject = False;
	
	If TypeOf(DataExchangeScenario) = Type("CatalogRef.DataExchangeScenarios") Then
		
		DataExchangeScenario = DataExchangeScenario.GetObject();
		
		MustWriteObject = True;
		
	EndIf;
	
	ExchangeTransportKind = InformationRegisters.ExchangeTransportSettings.DefaultExchangeMessageTransportKind(InfoBaseNode);
	
	ExchangeSettings = DataExchangeScenario.ExchangeSettings;
	
	// Adding data import in a loop
	For Each TableRow In ExchangeSettings Do
		
		If TableRow.CurrentAction = Enums.ActionsOnExchange.DataImport Then // the first import row
			
			NewRow = ExchangeSettings.Insert(ExchangeSettings.IndexOf(TableRow));
			
			NewRow.InfoBaseNode = InfoBaseNode;
			NewRow.ExchangeTransportKind = ExchangeTransportKind;
			NewRow.CurrentAction        = Enums.ActionsOnExchange.DataImport;
			NewRow.TransactionItemCount  = 0;
			
			Break;
		EndIf;
		
	EndDo;
	
	// If the row was not added in the loop, adding the row to the beginning of the table
	Filter = New Structure("InfoBaseNode, CurrentAction", InfoBaseNode, Enums.ActionsOnExchange.DataImport);
	If ExchangeSettings.FindRows(Filter).Count() = 0 Then
		
		NewRow = ExchangeSettings.Insert(0);
		
		NewRow.InfoBaseNode = InfoBaseNode;
		NewRow.ExchangeTransportKind = ExchangeTransportKind;
		NewRow.CurrentAction        = Enums.ActionsOnExchange.DataImport;
		NewRow.TransactionItemCount  = 0;
		
	EndIf;
	
	If MustWriteObject Then
		
		// Writing object changes
		DataExchangeScenario.Write();
		
	EndIf;
	
EndProcedure

Procedure DeleteRowInDataExchangeScenario(DataExchangeScenario, InfoBaseNode, ActionOnExchange)
	
	MustWriteObject = False;
	
	If TypeOf(DataExchangeScenario) = Type("CatalogRef.DataExchangeScenarios") Then
		
		DataExchangeScenario = DataExchangeScenario.GetObject();
		
		MustWriteObject = True;
		
	EndIf;
	
	ExchangeSettings = DataExchangeScenario.ExchangeSettings;
	
	MaxIndex = ExchangeSettings.Count() - 1;
	
	For Index = 0 to MaxIndex Do
		
		ReverseIndex = MaxIndex - Index;
		
		TableRow = ExchangeSettings[ReverseIndex];
		
		If  TableRow.InfoBaseNode = InfoBaseNode
			And TableRow.CurrentAction = ActionOnExchange Then
			
			ExchangeSettings.Delete(ReverseIndex);
			
		EndIf;
		
	EndDo;
	
	If MustWriteObject Then
		
		// Writing object changes
		DataExchangeScenario.Write();
		
	EndIf;
	
EndProcedure
