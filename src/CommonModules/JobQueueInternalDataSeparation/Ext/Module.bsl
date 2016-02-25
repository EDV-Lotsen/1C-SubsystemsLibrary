////////////////////////////////////////////////////////////////////////////////
// JobQueue: Separated queue job support
//
////////////////////////////////////////////////////////////////////////////////

#Region InternalInterface

// Called when filling the array of catalogs
// that can be used to store the queue jobs.
//
// Parameters:
//  ArrayCatalog - Array. You need to add to this parameter any managers of catalogs 
//    that can be used to store the queue jobs to this parameter.
//
Procedure OnFillJobCatalog(CatalogArray) Export
	
	CatalogArray.Add(Catalogs.DataAreaJobQueue);
	
EndProcedure

// Selects a catalog to be used for adding a queue job
//
// Parameters:
// JobParameters - - Structure - Parameters of the job to be added. The following keys can be used:
//   DataArea
//   Use
//   ScheduledStartTime
//   ExclusiveExecution
//   MethodName - mandatory.
//   Parameters
//   Key
//   RestartIntervalOnFailure
//   Schedule
//   RestartCountOnFailure,
// Catalog - CatalogManager, event subscription must set a catalog manager to be used for the
//  job as a value for this parameter 
// StandardProcessing - boolean. Event subscription must set standard processing flag 
//  as a value for this parameter (the DataAreaJobQueue catalog will be selected 
//  as catalog for standard processing).
//
Function OnSelectCatalogForJob(Val JobParameters) Export
	
	If JobParameters.Property("DataArea") And JobParameters.DataArea <> -1 Then
		
		Return Catalogs.DataAreaJobQueue;
		
	EndIf;
	
EndFunction

// Defines value of DataAreaMainData separator that must be set before launching the job.
//
// Parameters:
//  Job - CatalogRef, queue job.
//
// Returns: Arbitrary.
//
Function DefineDataAreaForJob(Val Job) Export
	
	If TypeOf(Job) = Type("CatalogRef.DataAreaJobQueue") Then
		Return CommonUse.ObjectAttributeValue(Job, "DataAreaAuxiliaryData");
	EndIf;
	
EndFunction

// Adjusts the scheduled job launch time to the data area time zone.
//
// Parameters:
//  JobParameters - Structure - Parameters of the job to be added. The following keys can be used:
//   DataArea
//   Use
//   ScheduledStartTime
//   ExclusiveExecution
//   MethodName - mandatory.
//   Parameters
//   Key
//   RestartIntervalOnFailure
//   Schedule
//   RestartCountOnFailure
//  Result = Date (date and time), scheduled job launch time.
//  StandardProcessing - Boolean. This flag specifies that job launch
//    time must be adjusted to the server time zone
//
Procedure OnDefineScheduledStartTime(Val JobParameters, Result, StandardProcessing) Export
	
	DataArea = Undefined;
	If Not JobParameters.Property("DataArea", DataArea) Then
		Return;
	EndIf;
	
	If DataArea <> - 1 Then
		
		// Time adjustment for the area time zone
		TimeZone = SaaSOperations.GetDataAreaTimeZone(JobParameters.DataArea);
		Result = ToUniversalTime(JobParameters.ScheduledStartTime, TimeZone);
		StandardProcessing = False;
		
	EndIf;
	
EndProcedure

/// Updates queue jobs based on templates.
Procedure UpdateQueueJobsByTemplates(Parameters = Undefined) Export
	
	If Not CommonUseCached.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	If Parameters = Undefined Then
		Parameters = New Structure;
		Parameters.Insert("ExclusiveMode", True);
	EndIf;
	
	LaunchInExclusiveMode = Parameters.ExclusiveMode;
	
	DataLock = New DataLock;
	DataLock.Add("Catalog.DataAreaJobQueue");
	
	BeginTransaction();
	Try
		DataLock.Lock();
		
		TemplateChanges = UpdateQueueJobTemplates(Parameters);
		If Not LaunchInExclusiveMode 
			And Parameters.ExclusiveMode Then
			
			RollbackTransaction();
			Return;
		EndIf;
		
		If TemplateChanges.Deleted.Count() > 0
			Or TemplateChanges.AddedChanged.Count() > 0 Then
			
			// Deleting jobs based on deleted templates
			Query = New Query(
			"SELECT
			|	Queue.Ref
			|FROM
			|	Catalog.DataAreaJobQueue AS Queue
			|WHERE
			|	Queue.Template IN(&DeletedTemplates)");
			Query.SetParameter("DeletedTemplates", TemplateChanges.Deleted);
			
			Selection = Query.Execute().Select();
			While Selection.Next() Do
				
				Job = Selection.Ref.GetObject();
				Job.DataExchange.Load = True;
				Job.Delete();
				
			EndDo;
			
			// Adding jobs based on added templates
			AddedChanged = TemplateChanges.AddedChanged;
			
			Query = New Query(
			"SELECT
			|	Areas.DataAreaAuxiliaryData AS DataArea,
			|	Queue.Ref AS ID,
			|	Templates.Ref AS Template,
			|	ISNULL(Queue.BeginDateOfLastStart, DATETIME(1, 1, 1)) AS BeginDateOfLastStart,
			|	TimeZones.Value AS TimeZone
			|FROM
			|	InformationRegister.DataAreas AS Areas
			|		INNER JOIN Catalog.QueueJobTemplates AS Templates
			|		ON (Templates.Ref IN (&AddedChangedTemplates))
			|			AND (Areas.Status = VALUE(Enum.DataAreaStatuses.Used))
			|		LEFT JOIN Catalog.DataAreaJobQueue AS Queue
			|		ON Areas.DataAreaAuxiliaryData = Queue.DataAreaAuxiliaryData
			|			AND (Templates.Ref = Queue.Template)
			|		LEFT JOIN Constant.DataAreaTimeZone AS TimeZones
			|		ON Areas.DataAreaAuxiliaryData = TimeZones.DataAreaAuxiliaryData");
			Query.SetParameter("AddedChangedTemplates", AddedChanged.UnloadColumn("Ref"));
			
			Selection = Query.Execute().Select();
			While Selection.Next() Do
				
				TemplateRow = AddedChanged.Find(Selection.Template, "Ref");
				If TemplateRow = Undefined Then
					MessagePattern = NStr("en = 'Job template %1 not found when updating'");
					MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, Selection.Ref);
					Raise(MessageText);
				EndIf;
				
				If ValueIsFilled(Selection.ID) Then
					Job = Selection.ID.GetObject();
				Else
					
					Job = Catalogs.DataAreaJobQueue.CreateItem();
					Job.Template = Selection.Template;
					Job.DataAreaAuxiliaryData = Selection.DataArea;
					
				EndIf;
				
				Job.Use = TemplateRow.Use;
				Job.Key = TemplateRow.Key;
				
				Job.ScheduledStartTime = 
					JobQueueInternal.GetScheduledJobStartTime(
						TemplateRow.Schedule,
						Selection.TimeZone,
						Selection.BeginDateOfLastStart);
						
				If ValueIsFilled(Job.ScheduledStartTime) Then
					Job.JobState = Enums.JobStates.Scheduled;
				Else
					Job.JobState = Enums.JobStates.NotScheduled;
				EndIf;
				
				Job.Write();
				
			EndDo;
		
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure


// Creates jobs by templates in the current data area
Procedure CreateQueueJobsByTemplatesInCurrentArea() Export
	
	If Not CommonUseCached.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	BeginTransaction();
	Try
		DataLock = New DataLock;
		DataLock.Add("Catalog.DataAreaJobQueue");
		DataLock.Lock();
		
		Query = New Query;
		Query.Text =
		"SELECT
		|	Queue.Ref AS ID,
		|	Templates.Ref AS Template,
		|	ISNULL(Queue.BeginDateOfLastStart, DATETIME(1, 1, 1)) AS BeginDateOfLastStart,
		|	TimeZones.Value AS TimeZone,
		|	Templates.Schedule AS Schedule,
		|	Templates.Use AS Use,
		|	Templates.Key AS Key
		|FROM
		|	Catalog.QueueJobTemplates AS Templates
		|		LEFT JOIN Catalog.DataAreaJobQueue AS Queue
		|		ON Templates.Ref = Queue.Template
		|		LEFT JOIN Constant.DataAreaTimeZone AS TimeZones
		|		ON (TRUE)";
		Result = Query.Execute();
		Selection = Result.Select();
		While Selection.Next() Do
			
			If ValueIsFilled(Selection.ID) Then
				Job = Selection.ID.GetObject();
			Else
				Job = Catalogs.DataAreaJobQueue.CreateItem();
				Job.Template = Selection.Template;
			EndIf;
			
			Job.Use = Selection.Use;
			Job.Key = Selection.Key;
			Job.ScheduledStartTime = 
				JobQueueInternal.GetScheduledJobStartTime(Selection.Schedule.Get(), 
					Selection.TimeZone, 
					Selection.BeginDateOfLastStart);
					
			If ValueIsFilled(Job.ScheduledStartTime) Then
				Job.JobState = Enums.JobStates.Scheduled;
			Else
				Job.JobState = Enums.JobStates.NotScheduled;
			EndIf;
			
			Job.Write();
			
		EndDo;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Declarations of internal events (SL handlers can be attached to these events).

// See the description of this procedure in the StandardSubsystemsServer module.
Procedure InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers) Export
	
	// SERVER HANDLERS
	
	ServerHandlers[
		"StandardSubsystems.InfobaseVersionUpdate\OnAddUpdateHandlers"].Add(
			"JobQueueInternalDataSeparation");
	
	ServerHandlers[
		"StandardSubsystems.BaseFunctionality\OnEnableSeparationByDataAreas"].Add(
			"JobQueueInternalDataSeparation");
	
	If CommonUse.SubsystemExists("CloudTechnology.DataImportExport") Then
		
		ServerHandlers[
			"CloudTechnology.DataImportExport\OnFillExcludedFromImportExportTypes"].Add(
				"JobQueueInternalDataSeparation");
		
		ServerHandlers[
		"CloudTechnology.DataImportExport\AfterDataImportFromOtherMode"].Add(
			"JobQueueInternalDataSeparation");
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Internal event handlers of SL subsystems

// Adds update handlers that are required by the subsystem.
//
// Parameters:
//  Handlers - ValueTable - see the description of NewUpdateHandlerTable function in the InfobaseUpdate common module.
// 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.InitialFilling = True;
	Handler.Procedure = "JobQueueInternalDataSeparation.CreateQueueJobsByTemplatesInCurrentArea";
	Handler.ExclusiveMode = True;
	Handler.ExecuteInMandatoryGroup = True;
	Handler.Priority = 98;
	
	Handler = Handlers.Add();
	Handler.Version = "*";
	Handler.Procedure = "JobQueueInternalDataSeparation.UpdateQueueJobsByTemplates";
	Handler.SharedData = True;
	Handler.ExclusiveMode = True;
	Handler.Priority = 63;
	
EndProcedure

// Called when enabling data separation by data area.
//
Procedure OnEnableSeparationByDataAreas() Export
	
	UpdateQueueJobsByTemplates();
	
EndProcedure

// Called after data import from local version to service data area 
// (or vice versa) is completed.
//
Procedure AfterDataImportFromOtherMode() Export
	
	If Not CommonUseCached.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	CreateQueueJobsByTemplatesInCurrentArea();
	
EndProcedure

// Fills the array of types excluded from data import and export.
//
// Parameters:
//  Types - Array(Types).
//
Procedure OnFillExcludedFromImportExportTypes(Types) Export
	
	Types.Add(Metadata.Catalogs.DataAreaJobQueue);
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

// Fills the QueueJobTemplates catalog with a list of scheduled jobs used 
// as templates for queue jobs, and clears the Usage flag for these jobs.
//
// Returns:
//  Structure - templates that were added or deleted during update, keys:
//   AddedChanged - ValueTable with the following columns:
//    Ref - CatalogRef.QueueJobTemplates - template reference.
//      Reference ID is identical to scheduled job ID 
//    Usage    - Boolean - job usage flag
//    Schedule - JobSchedule - job schedule
//
//   Deleted   - Value array UUID - added template IDs
//
Function UpdateQueueJobTemplates(Parameters)
	
	If Not CommonUseCached.DataSeparationEnabled() Then
		Return New Structure("Added, Deleted", New Array, New Array);
	EndIf;
	
	DataLock = New DataLock;
	DataLock.Add("Catalog.QueueJobTemplates");
	
	BeginTransaction();
	Try
		DataLock.Lock();
		
		TemplateTable = New ValueTable;
		TemplateTable.Columns.Add("Ref", New TypeDescription("CatalogRef.QueueJobTemplates"));
		TemplateTable.Columns.Add("Use", New TypeDescription("Boolean"));
		TemplateTable.Columns.Add("MethodName", New TypeDescription("String", , New StringQualifiers(255, AllowedLength.Variable)));
		TemplateTable.Columns.Add("Key", New TypeDescription("String", , New StringQualifiers(128, AllowedLength.Variable)));
		TemplateTable.Columns.Add("RestartCountOnFailure", New TypeDescription("Number", New NumberQualifiers(10, 0)));
		TemplateTable.Columns.Add("RestartIntervalOnFailure", New TypeDescription("Number", New NumberQualifiers(10, 0)));
		TemplateTable.Columns.Add("Schedule", New TypeDescription("JobSchedule"));
		TemplateTable.Columns.Add("Presentation", New TypeDescription("String", , New StringQualifiers(150, AllowedLength.Variable)));
		TemplateTable.Columns.Add("Name", New TypeDescription("String", , New StringQualifiers(255, AllowedLength.Variable)));
		
		TemplateNames = GetQueueJobTemplateList();
		
		Jobs = ScheduledJobs.GetScheduledJobs();
		For Each Job In Jobs Do
			If TemplateNames.Find(Job.Metadata.Name) <> Undefined Then
				NewRow = TemplateTable.Add();
				NewRow.Ref = Catalogs.QueueJobTemplates.GetRef(Job.UUID);
				NewRow.Use = Job.Metadata.Use;
				NewRow.MethodName = Job.Metadata.MethodName;
				NewRow.Key = Job.Metadata.Key;
				NewRow.RestartCountOnFailure = 
					Job.Metadata.RestartCountOnFailure;
				NewRow.RestartIntervalOnFailure = 
					Job.Metadata.RestartIntervalOnFailure;
				NewRow.Schedule = Job.Schedule;
				NewRow.Presentation = Job.Metadata.Presentation();
				NewRow.Name = Job.Metadata.Name;
				
				If Not Parameters.ExclusiveMode
					And Job.Use Then
					
					Parameters.ExclusiveMode = True;
					
					RollbackTransaction();
					
					Return Undefined;
				EndIf;
				
				Job.Use = False;
				Job.Write();
			EndIf;
		EndDo;
		
		DeletedTemplates = New Array;
		AddedChangedTemplates = New ValueTable;
		AddedChangedTemplates.Columns.Add("Ref", New TypeDescription("CatalogRef.QueueJobTemplates"));
		AddedChangedTemplates.Columns.Add("Use", New TypeDescription("Boolean"));
		AddedChangedTemplates.Columns.Add("Key", New TypeDescription("String", , New StringQualifiers(128, AllowedLength.Variable)));
		AddedChangedTemplates.Columns.Add("Schedule", New TypeDescription("JobSchedule"));
		
		Query = New Query;
		Query.Text =
		"SELECT
		|	QueueJobTemplates.Ref AS Ref,
		|	QueueJobTemplates.Use,
		|	QueueJobTemplates.Key,
		|	QueueJobTemplates.Schedule
		|FROM
		|	Catalog.QueueJobTemplates AS QueueJobTemplates";
		InitialTemplateTable = Query.Execute().Unload();
		
		// Managing added / changed templates
		For Each TableRow In TemplateTable Do
			
			TemplateChanged = False;
			
			InitialTemplateRow = InitialTemplateTable.Find(TableRow.Ref, "Ref");
			If InitialTemplateRow = Undefined
				Or TableRow.Use <> InitialTemplateRow.Use
				Or TableRow.Key <> InitialTemplateRow.Key
				Or Not CommonUseClientServer.SchedulesAreEqual(TableRow.Schedule, 
					InitialTemplateRow.Schedule.Get()) Then
					
				ChangedRow = AddedChangedTemplates.Add();
				ChangedRow.Ref = TableRow.Ref;
				ChangedRow.Use = TableRow.Use;
				ChangedRow.Key = TableRow.Key;
				ChangedRow.Schedule = TableRow.Schedule;
				
				TemplateChanged = True;
				
			EndIf;
			
			If InitialTemplateRow = Undefined Then
				Template = Catalogs.QueueJobTemplates.CreateItem();
				Template.SetNewObjectRef(TableRow.Ref);
			Else
				Template = TableRow.Ref.GetObject();
				InitialTemplateTable.Delete(InitialTemplateRow);
			EndIf;
			
			If TemplateChanged
				Or Template.Description <> TableRow.Presentation
				Or Template.MethodName <> TableRow.MethodName
				Or Template.RestartCountOnFailure <> TableRow.RestartCountOnFailure
				Or Template.RestartIntervalOnFailure <> TableRow.RestartIntervalOnFailure
				Or Template.Name <> TableRow.Name Then
				
				If Not Parameters.ExclusiveMode Then
					Parameters.ExclusiveMode = True;
					RollbackTransaction();
					Return Undefined;
				EndIf;
				
				Template.Description = TableRow.Presentation;
				Template.Use = TableRow.Use;
				Template.MethodName = TableRow.MethodName;
				Template.Key = TableRow.Key;
				Template.RestartCountOnFailure = TableRow.RestartCountOnFailure;
				Template.RestartIntervalOnFailure = TableRow.RestartIntervalOnFailure;
				Template.Schedule = New ValueStorage(TableRow.Schedule);
				Template.Name = TableRow.Name;
				Template.Write();
			EndIf;
			
		EndDo;
		
		// Managing deleted templates
		For Each InitialTemplateRow In InitialTemplateTable Do
			If Not Parameters.ExclusiveMode Then
				Parameters.ExclusiveMode = True;
				RollbackTransaction();
				Return Undefined;
			EndIf;
			
			Template = InitialTemplateRow.Ref.GetObject();
			Template.DataExchange.Load = True;
			Template.Delete();
			
			DeletedTemplates.Add(InitialTemplateRow.Ref);
		EndDo;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	Return New Structure("AddedChanged, Deleted", AddedChangedTemplates, DeletedTemplates);
	
EndFunction

Function GetQueueJobTemplateList()
	
	Templates = New Array;
	
	EventHandlers = CommonUse.InternalEventHandlers(
		"StandardSubsystems.SaaSOperations.JobQueue\OnReceiveTemplateList");
	
	For Each Handler In EventHandlers Do
		Handler.Module.OnReceiveTemplateList(Templates);
	EndDo;
	
	JobQueueOverridable.OnReceiveTemplateList(Templates);
	JobQueueOverridable.FillSeparatedScheduledJobList(Templates); // For obsolete version compatibility
	
	Return Templates;
	
EndFunction

#EndRegion
