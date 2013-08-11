////////////////////////////////////////////////////////////////////////////////
// JobQueue: Procedures and functions for working with shared scheduled jobs.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

////////////////////////////////////////////////////////////////////////////////
// Export internal procedures and functions.

// Plans to handle jobs from the JobQueue information register. 
// 
Procedure JobProcessingPlanning() Export
	
	If IsBlankString(UserName()) Then
		SetPrivilegedMode(True);
	EndIf;
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	JobQueue.DataArea,
	|	JobQueue.Job,
	|	JobQueue.Use,
	|	JobQueue.ScheduledStartTime,
	|	JobQueue.JobState,
	|	JobQueue.ActiveBackgroundJob,
	|	JobQueue.ExclusiveExecution,
	|	JobQueue.TryNumber,
	|	JobQueue.ScheduledJob,
	|	JobQueue.MethodName,
	|	JobQueue.Parameters,
	|	JobQueue.LastStartDate,
	|	DataAreas.TimeZone
	|FROM
	|	InformationRegister.JobQueue AS JobQueue
	|		INNER JOIN InformationRegister.DataAreas AS DataAreas
	|			ON JobQueue.DataArea = DataAreas.DataArea
	|WHERE
	|	JobQueue.JobState IN (VALUE(Enum.JobStates.Executing), VALUE(Enum.JobStates.Completed), VALUE(Enum.JobStates.NotScheduled))";
	
	TryCount = 0;
	Result = Undefined;
	While TryCount < 5 Do
		Try
			Result = Query.Execute();
			Break;
		Except
			TryCount = TryCount + 1;
			If TryCount = 5 Then
				WriteLogEvent(NStr("en = 'Job queue. Planning to handle jobs'"), EventLogLevel.Error, , ,
					DetailErrorDescription(ErrorInfo()));
				Raise;
			EndIf;
		EndTry;
	EndDo;
	
	Selection = Result.Choose();
	
	MapScheduledJobs = New Map;
	
	While Selection.Next() Do
		If ValueIsFilled(Selection.TimeZone) Then
			TimeZone = Selection.TimeZone;
		Else
			TimeZone = Undefined;
		EndIf;
		
		Try
			RecordKey = InformationRegisters.JobQueue.CreateRecordKey(New Structure("DataArea, Job", Selection.DataArea, Selection.Job));
			LockDataForEdit(RecordKey);
		Except
			// The record is locked, going to the next one
			Continue;
		EndTry;
		
		RecordSet = InformationRegisters.JobQueue.CreateRecordSet();
		RecordSet.Filter.DataArea.Set(Selection.DataArea);
		RecordSet.Filter.Job.Set(Selection.Job);
		RecordSet.Read();
		If RecordSet.Count() = 0 Then
			UnlockDataForEdit(RecordKey);
			Continue;
		EndIf;
		
		Record = RecordSet[0];
		
		If ValueIsFilled(Record.ScheduledJob) Then
			If MapScheduledJobs[Record.ScheduledJob] = Undefined Then
				ScheduledJob = ScheduledJobs.FindByUUID(Record.ScheduledJob);
				If ScheduledJob <> Undefined Then
					MapScheduledJobs.Insert(Record.ScheduledJob, ScheduledJob);
				EndIf;
			EndIf;
		EndIf;
		
		If Record.JobState = Enums.JobStates.Executing Then
			WriteExecutionControlEventLog("ScheduledJobQueue.CompletedWithErrors", Record);
		EndIf;
		
		If ValueIsFilled(Record.ScheduledJob)Then
			ScheduledJob = MapScheduledJobs[Record.ScheduledJob];
			If ScheduledJob <> Undefined Then
				
				TryNumber = Record.TryNumber + 1;
				If Record.JobState = Enums.JobStates.Executing
					And TryNumber < ScheduledJob.RestartCountOnFailure Then
					
					Record.ScheduledStartTime = CurrentUniversalDate();
					Record.TryNumber = TryNumber;
					Record.JobState = Enums.JobStates.Scheduled;
					Record.ActiveBackgroundJob = Undefined;
				Else
					Record.ScheduledStartTime = GetScheduledJobStartTime(
						ScheduledJob.Schedule, TimeZone, Record.LastStartDate);
					Record.TryNumber = 0;
					If ValueIsFilled(Record.ScheduledStartTime) Then
						Record.JobState = Enums.JobStates.Scheduled;
					Else
						Record.JobState = Enums.JobStates.NotScheduled;
					EndIf;
					Record.ActiveBackgroundJob = Undefined;
				EndIf;
			EndIf;			
		Else
			// This is a background job, it must be deleted after execution
			RecordSet.Clear();
		EndIf;
		RecordSet.Write();
		UnlockDataForEdit(RecordKey);
	EndDo;

	// Calculating number of background jobs to be executed
	BackgroundJobsToStartCount = ActiveBackgroundJobCountToStart();
	
	// Starting active background jobs
	StartActiveBackgroundJob(BackgroundJobsToStartCount);
	
EndProcedure

// Returns an error text when two jobs with the same key are attempted to be executed.
//
// Returns:
// String.
//
Function GetJobsWithSameKeyDuplicationErrorMessage() Export
	
	Return NStr("en = 'Existence of several jobs with equal Key field values is not allowed.'");
	
EndFunction

// Executes jobs from the JobQueue information register. 
// 
// Parameters: 
// BackgroundJobKey - UUID - key that is used for searching for the current background job.
//
Procedure ProcessJobQueue(BackgroundJobKey) Export
	
	If IsBlankString(UserName()) Then
		SetPrivilegedMode(True);
	EndIf;
	
	FoundBackgroundJob = BackgroundJobs.GetBackgroundJobs(New Structure("Key", BackgroundJobKey));
	If FoundBackgroundJob.Count() = 1 Then
		ActiveBackgroundJob = FoundBackgroundJob[0];
	Else
		Return;
	EndIf;	
	
	CanExecute = True;
	ExecutionStarted = CurrentUniversalDate();
	
	While CanExecute Do 
		// Choosing a job for execution
		Query = New Query;
		Query.Text = 
		"SELECT TOP 111
		|	JobQueue.DataArea,
		|	JobQueue.Job AS Job,
		|	JobQueue.Use,
		|	JobQueue.ScheduledStartTime AS ScheduledStartTime,
		|	JobQueue.JobState,
		|	JobQueue.ActiveBackgroundJob,
		|	JobQueue.ExclusiveExecution AS ExclusiveExecution,
		|	JobQueue.TryNumber,
		|	JobQueue.ScheduledJob,
		|	JobQueue.MethodName,
		|	JobQueue.Parameters,
		|	JobQueue.LastStartDate
		|FROM
		|	InformationRegister.JobQueue AS JobQueue
		|		LEFT JOIN InformationRegister.DataAreaSessionLocks AS SessionLocks
		|			ON JobQueue.DataArea = SessionLocks.DataArea
		|WHERE
		|	JobQueue.Use
		|	AND JobQueue.ScheduledStartTime <= &CurrentUniversalDate
		|	AND JobQueue.JobState = VALUE(Enum.JobStates.Scheduled)
		|	AND (JobQueue.ExclusiveExecution
		|			OR SessionLocks.DataArea IS NULL 
		|			OR SessionLocks.LockPeriodStart > &CurrentUniversalDate
		|			OR SessionLocks.LockPeriodEnd < &CurrentUniversalDate)
		|
		|ORDER BY
		|	ExclusiveExecution DESC,
		|	ScheduledStartTime DESC,
		|	Job";
		Query.SetParameter("CurrentUniversalDate", CurrentUniversalDate());
		
		SelectionSizeText = Format(Constants.MaxActiveBackgroundJobCount.Get(), "NZ=; NG=");
		Query.Text = StrReplace(Query.Text, "111", SelectionSizeText);
		
		TryCount = 0;
		Selection = Undefined;
		While TryCount < 5 Do
			Try
				Selection = Query.Execute().Choose();
				Break;
			Except
				TryCount = TryCount + 1;
				If TryCount = 5 Then
					WriteLogEvent(NStr("Job queue. Job execution"), EventLogLevel.Error, , ,
						DetailErrorDescription(ErrorInfo()));
					Raise;
				EndIf;
			EndTry;
		EndDo;
		
		Locked = False;
		While Selection.Next() Do 
			Try
				RecordKey = InformationRegisters.JobQueue.CreateRecordKey(New Structure("DataArea, Job", Selection.DataArea, Selection.Job));
				LockDataForEdit(RecordKey);
				Locked = True;
				
				Job = Selection.Job;
				DataArea = Selection.DataArea;
				Break;
			Except
			EndTry;
		EndDo;	
		
		If Not Locked Then 
			Return;
		EndIf;
		
		BeginTransaction();
		Try
			Lock = New DataLock;
			LockItem = Lock.Add("InformationRegister.JobQueue");
			LockItem.SetValue("DataArea", DataArea);
			LockItem.SetValue("Job" , Job);
			Lock.Lock(); 
			
			Query = New Query;
			Query.Text = 
			"SELECT
			|	JobQueue.DataArea,
			|	JobQueue.Job,
			|	JobQueue.Use,
			|	JobQueue.ScheduledStartTime,
			|	JobQueue.JobState,
			|	JobQueue.ActiveBackgroundJob,
			|	JobQueue.ExclusiveExecution,
			|	JobQueue.TryNumber,
			|	JobQueue.ScheduledJob,
			|	JobQueue.MethodName,
			|	JobQueue.Parameters,
			|	JobQueue.LastStartDate
			|FROM
			|	InformationRegister.JobQueue AS JobQueue
			|WHERE
			|	JobQueue.DataArea = &DataArea
			|	AND JobQueue.Job = &Job
			|	AND JobQueue.JobState = VALUE(Enum.JobStates.Scheduled)
			|	AND JobQueue.Use
			|	AND JobQueue.ScheduledStartTime <= &CurrentUniversalDate";
			
			Query.SetParameter("DataArea" , DataArea);
			Query.SetParameter("Job" , Job);
			Query.SetParameter("CurrentUniversalDate", CurrentUniversalDate());
			
			Selection = Query.Execute().Choose();
			If Selection.Next() Then 
				RecordSet = InformationRegisters.JobQueue.CreateRecordSet();
				RecordSet.Filter.DataArea.Set(DataArea);
				RecordSet.Filter.Job.Set(Job);
				
				NewRecord = RecordSet.Add();
				FillPropertyValues(NewRecord, Selection);
				NewRecord.JobState = Enums.JobStates.Executing;
				NewRecord.ActiveBackgroundJob = ActiveBackgroundJob.UUID;
				NewRecord.LastStartDate = CurrentUniversalDate();
				
				RecordSet.Write();
			Else
				Return;
			EndIf;
			
			CommitTransaction();
		Except
			RollbackTransaction();
			WriteLogEvent(NStr("en = 'Handling job queue'"), 
				EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
			Raise;
		EndTry;
		
		SetPrivilegedMode(True);
	
		CommonUse.SetSessionSeparation(True, DataArea);
		
		SetPrivilegedMode(False);
		
		// Executing the job
		Try
			WriteExecutionControlEventLog("ScheduledJobQueue.Start", RecordSet[0]);
			
			ExecuteJob(Selection.MethodName, Selection.Parameters.Get());
			
			WriteExecutionControlEventLog("ScheduledJobQueue.CompletedSuccessfully", RecordSet[0]);
		Except
			WriteExecutionControlEventLog("ScheduledJobQueue.CompletedWithErrors", RecordSet[0]);
			
			WriteLogEvent(NStr("en = 'Background job. Error'"), EventLogLevel.Error, ,
				ActiveBackgroundJob, DetailErrorDescription(ErrorInfo())); 
				
			While TransactionActive() Do
				RollbackTransaction();
			EndDo;
		EndTry;
		
		SetPrivilegedMode(True);
		CommonUse.SetSessionSeparation(False);
		SetPrivilegedMode(False);
		
		RecordSet[0].JobState = Enums.JobStates.Completed;
		RecordSet.Write();
		
		UnlockDataForEdit(RecordKey);
		
		// Checking whether further execution is possible
		ActiveBackgroundJobCount = ActiveBackgroundJobCount();
		
		ExecutionTime = CurrentUniversalDate() - ExecutionStarted;
		If ExecutionTime > Constants.MaxActiveBackgroundJobExecutionTime.Get()
			Or ActiveBackgroundJobCount > Constants.MaxActiveBackgroundJobCount.Get() Then
			
			CanExecute = False;
		EndIf;
	EndDo;
	
EndProcedure

// Fills the SeparatedScheduledJobs information register with a list of
// separated scheduled jobs and disables the Use attribute for these jobs in the system
// scheduled job table.
// 
Procedure UpdateSeparatedScheduledJobs() Export
	
	If Not CommonUseCached.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	// Scheduled jobs must be retrieved in the shared mode.
	// Saving the current state.
	CurrentState = CommonUse.UseSessionSeparator();
	If CurrentState Then
		CommonUse.SetSessionSeparation(False);
	EndIf;
	
	BeginTransaction();
	Try
		ScheduledJobUsageTable = GetScheduledJobUsageTable();
		
		For Each Row In ScheduledJobUsageTable Do
			
			Filter = New Structure("Metadata", Metadata.ScheduledJobs[Row.ScheduledJob]);
			FoundScheduledJobs = ScheduledJobs.GetScheduledJobs(Filter);
			
			For Each ScheduledJob In FoundScheduledJobs Do
				ScheduledJob.Use = Row.Use;
				ScheduledJob.Write();
			EndDo;
			
		EndDo;
		
		// If data separation is enabled, scheduled job separation must be disabled, 
		// and SeparatedScheduledJobs register must be filled.
		SharedScheduledJobTable = New ValueTable;
		SharedScheduledJobTable.Columns.Add("ScheduledJob" , New TypeDescription("UUID"));
		SharedScheduledJobTable.Columns.Add("Use" , New TypeDescription("Boolean"));
		SharedScheduledJobTable.Columns.Add("CustomSettings", New TypeDescription("Boolean"));
		
		SeparatedScheduledJobList = GetSeparatedScheduledJobList();
		
		Jobs = ScheduledJobs.GetScheduledJobs();
		For Each Job In Jobs Do
			If SeparatedScheduledJobList.Find(Job.Metadata.Name) <> Undefined Then
				NewRow = SharedScheduledJobTable.Add();
				NewRow.ScheduledJob = Job.UUID;
				NewRow.Use = Job.Metadata.Use;
				
				Job.Use = False;
				Job.Write();
			EndIf;
		EndDo;
		
		RecordSet = InformationRegisters.SeparatedScheduledJobs.CreateRecordSet();
		RecordSet.Read();
		SourceJobTable = RecordSet.Unload();
		For Each TableRow In SharedScheduledJobTable Do
			SourceJobRow = SourceJobTable.Find(TableRow.ScheduledJob, "ScheduledJob");
			If SourceJobRow <> Undefined Then
				TableRow.Use = SourceJobRow.Use;
				TableRow.CustomSettings = SourceJobRow.CustomSettings;
			EndIf;
		EndDo;
		RecordSet.Load(SharedScheduledJobTable);
		RecordSet.Write();
		
		// Restoring session parameter state
		If CurrentState <> CommonUse.UseSessionSeparator() Then
			CommonUse.SetSessionSeparation(CurrentState);
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteLogEvent(NStr("en = 'Updating separated scheduled jobs'"), 
			EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
EndProcedure

// Synchronizes the JobQueue information register with jobs from
// the SeparatedScheduledJobs information register.
// If a scheduled job has been added to the SeparatedScheduledJobs information register, 
// it is added to the JobQueue information register.
// If a scheduled job has been deleted from the SeparatedScheduledJobs information 
// register, it is deleted from the JobQueue information register.
// The Use attribute of a job in the JobQueue information register becomes equal with
// the Use attribute of this job in the SeparatedScheduledJobs information register. 
// The procedure synchronizes jobs of the specified data area.
//
// Parameters: 
// DataArea (Optional) - Number - data area whose jobs will be synchronized. 
// If this parameter is not set, jobs of the current data area will be synchronized.
//
Procedure UpdateJobQueue(DataArea = Undefined) Export 
	
	If Not CommonUseCached.IsSeparatedConfiguration() Then
		Return;
	EndIf;
	
	If DataArea = Undefined Then
		DataArea = CommonUse.SessionSeparatorValue();
	EndIf;
	
	TimeZone = GetDataAreaTimeZone(DataArea);
	
	ScheduledJobListCustomSettings = New Array;
		
	// Scheduled jobs must be retrieved in the shared mode.
	CurrentState = CommonUse.UseSessionSeparator();
	If CurrentState Then
		CommonUse.SetSessionSeparation(False);
	EndIf;
	
	ScheduledJobList = New ValueList;
	Query = New Query;
	Query.Text = 
	"SELECT
	|	SeparatedScheduledJobs.ScheduledJob,
	|	SeparatedScheduledJobs.Use,
	|	SeparatedScheduledJobs.CustomSettings
	|FROM
	|	InformationRegister.SeparatedScheduledJobs AS SeparatedScheduledJobs";
	
	Selection = Query.Execute().Choose();
	While Selection.Next() Do
		ScheduledJob = ScheduledJobs.FindByUUID(Selection.ScheduledJob);
		If ScheduledJob <> Undefined Then
			ScheduledJobList.Add(ScheduledJob,, Selection.Use);
			
			If Selection.CustomSettings Then
				ScheduledJobListCustomSettings.Add(Selection.ScheduledJob);
			EndIf;
		EndIf;
	EndDo;
	
	BeginTransaction();
	Try
		// Deleting existing scheduled jobs from the JobQueue information register
		Query = New Query;
		Query.Text = 
		"SELECT
		|	JobQueue.DataArea,
		|	JobQueue.Job,
		|	JobQueue.ScheduledJob
		|FROM
		|	InformationRegister.JobQueue AS JobQueue
		|WHERE
		|	JobQueue.ScheduledJob <> &EmptyUUID
		|	AND JobQueue.DataArea = &DataArea";
		Query.SetParameter("EmptyUUID", New UUID("00000000-0000-0000-0000-000000000000"));
		Query.SetParameter("DataArea" , DataArea);
		
		Result = Query.Execute();
		Selection = Result.Choose();
		RecordManager = InformationRegisters.JobQueue.CreateRecordManager();
		
		While Selection.Next() Do
			RecordKey = InformationRegisters.JobQueue.CreateRecordKey(New Structure("DataArea, Job",
				Selection.DataArea, Selection.Job));
			LockDataForEdit(RecordKey);
		EndDo;
		
		Lock = New DataLock;
		LockItem = Lock.Add("InformationRegister.JobQueue");
		LockItem.DataSource = Result;
		LockItem.UseFromDataSource("DataArea", "DataArea");			
		LockItem.UseFromDataSource("Job" , "Job");
		Lock.Lock();
		
		Selection.Reset();
		While Selection.Next() Do
			If ScheduledJobListCustomSettings.Find(Selection.ScheduledJob) = Undefined Then
				RecordManager.DataArea = Selection.DataArea;
				RecordManager.Job = Selection.Job;
				RecordManager.Delete();
			EndIf;
		EndDo;
		
		// Adding jobs to the JobQueue information register according to scheduled jobs from
		// the SeparatedScheduledJobs information register.
		For Each ScheduledJob In ScheduledJobList Do
			Schedule = ScheduledJob.Value.Schedule;
			If ScheduledJob <> Undefined
				And ScheduledJobListCustomSettings.Find(ScheduledJob.Value.UUID) = Undefined Then
				Job = New UUID;
				
				NewRecordSet = InformationRegisters.JobQueue.CreateRecordSet();
				NewRecordSet.Filter.DataArea.Set(DataArea);
				NewRecordSet.Filter.Job.Set(Job);
				
				NewRecord = NewRecordSet.Add();
				NewRecord.DataArea = DataArea;
				NewRecord.Job = Job;
				NewRecord.Use = ScheduledJob.Check;
				NewRecord.ScheduledJob = ScheduledJob.Value.UUID;	
				NewRecord.Key = ScheduledJob.Value.Key;
				NewRecord.Parameters = New ValueStorage(ScheduledJob.Value.Parameters);
				NewRecord.MethodName = ScheduledJob.Value.Metadata.MethodName;
				NewRecord.ScheduledStartTime = GetScheduledJobStartTime(Schedule, TimeZone);
				
				// If start time is not planned, the job is not started.
				If ValueIsFilled(NewRecord.ScheduledStartTime) Then
					NewRecord.JobState = Enums.JobStates.Scheduled;
				Else
					NewRecord.JobState = Enums.JobStates.NotScheduled;
				EndIf;
				
				RecordKey = InformationRegisters.JobQueue.CreateRecordKey(New Structure("DataArea, Job",
					NewRecord.DataArea, NewRecord.Job));
				LockDataForEdit(RecordKey);
				
				NewRecordSet.Write();
			EndIf;
		EndDo;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteLogEvent(NStr("en = 'Updating job queue'"), 
			EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
		// Restoring session parameter state
	If CurrentState Then
		CommonUse.SetSessionSeparation(CurrentState);
	EndIf;
	
EndProcedure

// Retrieves a job by specified filter. 
// 
// Parameters: 
// Filter - Structure - structure that specifies the filter. 
// The following parameters can be values of this structure: 
// MethodName, Job, JobState, ScheduledJob, Key.
// DataArea - Number - sets the data area where a new job will be added.
// 
// Returns: 
// Array, String, or Undefined. 
// String - job ID if job is found, 
// Array - if there are several jobs, 
// Undefined - if job is not found.
// 
Function GetJob(Filter, DataArea = Undefined) Export
	
	If TypeOf(Filter) <> Type("Structure") Then
		Raise NStr("en = 'Invalid value of the parameter #1.'");
	EndIf;
	If Filter.Property("Key") Then
		If TypeOf(Filter.Key) <> Type("String") Then
			Raise NStr("en = 'Invalid Key property type of the parameter #1.'");
		EndIf;	
	EndIf;
	If Filter.Property("Metadata") Then
		If TypeOf(Filter.Metadata) <> Type("String")
			And TypeOf(Filter.Metadata) <> Type("MetadataObject") Then
			Raise NStr("en = 'Invalid Metadata property type of the parameter #1.'");
		EndIf;	
	EndIf;
	If Filter.Property("ScheduledJob") Then
		If TypeOf(Filter.ScheduledJob) <> Type("UUID") Then
			Raise NStr("en = 'Invalid ScheduledJob property type of the parameter #1.'");
		EndIf;	
	EndIf;
	If Filter.Property("MethodName") Then
		If TypeOf(Filter.MethodName) <> Type("String") Then
			Raise NStr("en = 'Invalid MethodName property type of the parameter #1.'");
		EndIf;	
	EndIf;
	If Filter.Property("Job") Then
		If TypeOf(Filter.Description) <> Type("String") Then
			Raise NStr("en = 'Invalid Job property type of the parameter #1.'");
		EndIf;	
	EndIf;	
	
	If DataArea = Undefined Then
		DataArea = CommonUse.SessionSeparatorValue();
	EndIf;
	
	Jobs = Undefined;
	
	SetPrivilegedMode(True);
	
	If Filter.Property("MethodName") And ValueIsFilled(Filter.MethodName)
		Or Filter.Property("ScheduledJob") And ValueIsFilled(Filter.ScheduledJob) Then
		Query = New Query;
		Query.Text =
		"SELECT
		|	JobQueue.Job
		|FROM
		|	InformationRegister.JobQueue AS JobQueue
		|WHERE
		|	JobQueue.DataArea = &DataArea";
		Query.SetParameter("DataArea", DataArea);
		
		If Filter.Property("MethodName") And ValueIsFilled(Filter.MethodName) Then
			Query.Text = Query.Text + "	AND JobQueue.MethodName = &MethodName";
			Query.SetParameter("MethodName", Filter.MethodName);
		EndIf;
		If Filter.Property("JobState") And ValueIsFilled(Filter.JobState) Then
			Query.Text = Query.Text + "	AND JobQueue.JobState = &JobState";
			Query.SetParameter("JobState", Filter.JobState);
		EndIf;
		If Filter.Property("ScheduledJob") And ValueIsFilled(Filter.ScheduledJob) Then 
			Query.Text = Query.Text + " AND JobQueue.ScheduledJob = &ScheduledJob";
			Query.SetParameter("ScheduledJob", Filter.ScheduledJob);
		EndIf;
		If Filter.Property("Key") And ValueIsFilled(Filter.Key) Then 
			Query.Text = Query.Text + " AND JobQueue.Key = &Key";
			Query.SetParameter("Key", Filter.Key);
		EndIf;
		If Filter.Property("Job") And ValueIsFilled(Filter.Job) Then 
			Query.Text = Query.Text + " AND JobQueue.Job = &Job";
			Query.SetParameter("Job", Filter.Job);
		EndIf;
		
		QueryResult = Query.Execute();
		If Not QueryResult.IsEmpty() Then
			JobList = QueryResult.Unload().UnloadColumn("Job");
			If JobList.Count() = 1 Then
				Jobs = JobList[0];
			Else
				Jobs = JobList;
			EndIf;
		EndIf;
	EndIf;
	
	Return Jobs;
	
EndFunction

// Adds a new job to the JobQueue information register. 
// 
// Parameters: 
// JobParameters - Structure - following parameters of a job to be added:
// 		 Use, ScheduledStartTime, MethodName, 
// 		 Parameters, ExclusiveExecution, ScheduledJob. 
// DataArea - Number - sets the data area where a new job will be added.
// 
// Returns: 
// String - ID of the added job.
// 
Function AddJob(JobParameters, DataArea = Undefined) Export
	
	If TypeOf(JobParameters) <> Type("Structure") Then
		Raise NStr("en = 'Invalid value of the parameter #1.'");
	EndIf;
	If JobParameters.Property("Use") Then
		If TypeOf(JobParameters.Use) <> Type("Boolean") Then
			Raise NStr("en = 'Invalid Use property type of the parameter #1.'");
		Else
			Use = JobParameters.Use;
		EndIf;	
	Else
		Use = True;
	EndIf;
	If JobParameters.Property("ExclusiveExecution") Then
		If TypeOf(JobParameters.ExclusiveExecution) <> Type("Boolean") Then
			Raise NStr("en = 'Invalid ExclusiveExecution property type of the parameter #1.'");
		EndIf;	
	EndIf;
	If JobParameters.Property("Key") Then
		If TypeOf(JobParameters.Key) <> Type("String") Then
			Raise NStr("en = 'Invalid Key property type of the parameter #1.'");
		EndIf;	
	EndIf;
	If JobParameters.Property("ScheduledJob") Then
		If TypeOf(JobParameters.ScheduledJob) <> Type("UUID") Then
			Raise NStr("en = 'Invalid ScheduledJob property type of the parameter #1.'");
		EndIf;	
	EndIf;
	If JobParameters.Property("MethodName") Then
		If TypeOf(JobParameters.MethodName) <> Type("String") Then
			Raise NStr("en = 'Invalid MethodName property type of the parameter #1.'");
		EndIf;	
	EndIf;
	If JobParameters.Property("ScheduledStartTime") Then
		If TypeOf(JobParameters.ScheduledStartTime) <> Type("Date") Then
			Raise NStr("en = 'Invalid ScheduledStartTime property type of the parameter #1.'");
		EndIf;	
	EndIf;
	
	If DataArea = Undefined Then
		DataArea = CommonUse.SessionSeparatorValue();
	Else
		If Not CommonUseCached.SessionWithoutSeparator() 
			And DataArea <> CommonUse.SessionSeparatorValue() Then
					Raise(NStr("en = 'It is not allowed to process data from another data area in this session.'"));
		EndIf;	
	EndIf;
	
	If JobParameters.Property("Key") And ValueIsFilled(JobParameters.Key) Then
		If GetJob(JobParameters, DataArea) <> Undefined Then
			Raise GetJobsWithSameKeyDuplicationErrorMessage();
		EndIf;
	EndIf;
	
	Parameters = New ValueStorage(New Array);
	If JobParameters.Property("Parameters") Then
		If TypeOf(JobParameters.Parameters) = Type("ValueStorage") Then
			Parameters = JobParameters.Parameters;
		ElsIf TypeOf(JobParameters.Parameters) = Type("Array") Then
			Parameters = New ValueStorage(JobParameters.Parameters);
		EndIf;
	EndIf;

	SetPrivilegedMode(True);
	
	RecordManager = InformationRegisters.JobQueue.CreateRecordManager();
	FillPropertyValues(RecordManager, JobParameters);
	RecordManager.DataArea = DataArea;
	RecordManager.Job = New UUID;
	
	TimeZone = GetDataAreaTimeZone(DataArea);
	If ValueIsFilled(RecordManager.ScheduledStartTime) Then
		RecordManager.ScheduledStartTime = ToUniversalTime(RecordManager.ScheduledStartTime, TimeZone);
	EndIf;
	
	If ValueIsFilled(RecordManager.ScheduledStartTime) Then
		RecordManager.JobState = Enums.JobStates.Scheduled;
	Else
		If ValueIsFilled(RecordManager.ScheduledJob) Then 
			RecordManager.JobState = Enums.JobStates.NotScheduled;
		Else
			RecordManager.ScheduledStartTime = CurrentUniversalDate();
			RecordManager.JobState = Enums.JobStates.Scheduled;
		EndIf;
	EndIf;
	RecordManager.Parameters = Parameters;
	RecordManager.Use = Use;
	RecordManager.Write();
	
	Return RecordManager.Job;
	
EndFunction

// Changes the job in the JobQueue information register. 
// 
// Parameters: 
// Job - String - job ID.
// JobParameters - Structure - following parameters of the job to be set:
// 		 Use, ScheduledStartTime, MethodName, 
// 		 Parameters, ExclusiveExecution, ScheduledJob. 
// DataArea - Number - sets the data area where the job will be changed.
//
Procedure ChangeJob(Job, JobParameters, DataArea = Undefined) Export
	
	If Not ValueIsFilled(Job) Or TypeOf(Job) <> Type("String") Then
		Raise NStr("en = 'Invalid value of the parameter #1.'");
	EndIf;
	
	If TypeOf(JobParameters) <> Type("Structure") Then
		Raise NStr("en = 'Invalid value of the parameter #2.'");
	EndIf;
	If JobParameters.Property("Use") Then
		If TypeOf(JobParameters.Use) <> Type("Boolean") Then
			Raise NStr("en = 'Invalid Use property type of the parameter #2.'");
		EndIf;	
	EndIf;
	If JobParameters.Property("ExclusiveExecution") Then
		If TypeOf(JobParameters.ExclusiveExecution) <> Type("Boolean") Then
			Raise NStr("en = 'Invalid ExclusiveExecution property type of the parameter #2.'");
		EndIf;	
	EndIf;
	If JobParameters.Property("Key") Then
		If TypeOf(JobParameters.Key) <> Type("String") Then
			Raise NStr("en = 'Invalid Key property type of the parameter #2.'");
		EndIf;	
	EndIf;
	If JobParameters.Property("ScheduledJob") Then
		If TypeOf(JobParameters.ScheduledJob) <> Type("UUID") Then
			Raise NStr("en = 'Invalid ScheduledJob property type of the parameter #2.'");
		EndIf;	
	EndIf;
	If JobParameters.Property("MethodName") Then
		If TypeOf(JobParameters.MethodName) <> Type("String") Then
			Raise NStr("en = 'Invalid MethodName property type of the parameter #2.'");
		EndIf;	
	EndIf;
	If JobParameters.Property("ScheduledStartTime") Then
		If TypeOf(JobParameters.ScheduledStartTime) <> Type("Date") Then
			Raise NStr("en = 'Invalid ScheduledStartTime property type of the parameter #2.'");
		EndIf;	
	EndIf;
	
	If DataArea = Undefined Then
		DataArea = CommonUse.SessionSeparatorValue();
	EndIf;
	
	If JobParameters.Property("Key") And ValueIsFilled(JobParameters.Key) Then
		If GetJob(JobParameters, DataArea) <> Undefined Then
			Raise NStr("en = 'Existence of several jobs with equal Key field values is not allowed.'");
		EndIf;
	EndIf;

	SetPrivilegedMode(True);
	
	RecordKey = InformationRegisters.JobQueue.CreateRecordKey(New Structure("DataArea, Job", DataArea, Job));
	LockDataForEdit(RecordKey);
	
	RecordManager = InformationRegisters.JobQueue.CreateRecordManager();
	FillPropertyValues(RecordManager, JobParameters);
	RecordManager.DataArea = DataArea;
	RecordManager.Job = Job;
	RecordManager.Read();
	FillPropertyValues(RecordManager, JobParameters);
	
	If ValueIsFilled(RecordManager.ScheduledStartTime) Then
		RecordManager.JobState = Enums.JobStates.Scheduled;
	Else
		If ValueIsFilled(RecordManager.ScheduledJob) Then 
			RecordManager.JobState = Enums.JobStates.NotScheduled;
		Else
			RecordManager.ScheduledStartTime = CurrentUniversalDate();
			RecordManager.JobState = Enums.JobStates.Scheduled;
		EndIf;
	EndIf;
	
	RecordManager.Write();
	
EndProcedure

// Deletes the job from the JobQueue information register. 
// 
// Parameters: 
// Job - String - job ID.
// DataArea - Number - sets the data area where the job will be deleted.
// 
Procedure DeleteJob(Job, DataArea = Undefined) Export
	
	If Not ValueIsFilled(Job) Or TypeOf(Job) <> Type("String") Then
		Raise NStr("en = 'Invalid value of the parameter #1.'");
	EndIf;
	
	If DataArea = Undefined Then
		DataArea = CommonUse.SessionSeparatorValue();
	EndIf;

	SetPrivilegedMode(True);
	
	RecordKey = InformationRegisters.JobQueue.CreateRecordKey(New Structure("DataArea, Job", DataArea, Job));
	LockDataForEdit(RecordKey);
	
	RecordManager = InformationRegisters.JobQueue.CreateRecordManager();
	RecordManager.DataArea = DataArea;
	RecordManager.Job = Job;
	RecordManager.Delete();
	
EndProcedure

// Searches for the scheduled job by ID in the separated mode.
// Parameters: 
// ID - UUID - scheduled job ID. 
//
// Returns: 
// ScheduledJob, Structure, Undefined. 
//
Function FindByUUID(ID) Export
	
	If TypeOf(ID) <> Type("UUID") Then
		Raise NStr("en = 'Invalid value of the parameter #1.'");
	EndIf;
	
	ScheduledJob = Undefined;
	If CommonUseCached.DataSeparationEnabled() Then
		DataArea = CommonUse.SessionSeparatorValue();
		
		Filter = New Structure("UUID", ID);
		Query = New Query;
		Query.Text = 
		"SELECT TOP 1
		|	JobQueue.DataArea,
		|	JobQueue.Job,
		|	JobQueue.Use,
		|	JobQueue.ScheduledStartTime,
		|	JobQueue.JobState,
		|	JobQueue.ActiveBackgroundJob,
		|	JobQueue.ExclusiveExecution,
		|	JobQueue.TryNumber,
		|	JobQueue.ScheduledJob,
		|	JobQueue.MethodName,
		|	JobQueue.Parameters,
		|	JobQueue.LastStartDate,
		|	JobQueue.Key
		|FROM
		|	InformationRegister.JobQueue AS JobQueue
		|WHERE
		|	JobQueue.DataArea = &DataArea
		|	AND JobQueue.ScheduledJob = &ScheduledJob";
		Query.SetParameter("ScheduledJob", ID);
		Query.SetParameter("DataArea" , DataArea);
		Result = Query.Execute();
		If Not Result.IsEmpty() Then
			Selection = Result.Choose();
			Selection.Next();
			
			ScheduledJob = New Structure;
			ScheduledJob.Insert("Job" , Selection.Job);
			ScheduledJob.Insert("Use" , Selection.Use);
			ScheduledJob.Insert("UUID", Selection.ScheduledJob);
			ScheduledJob.Insert("MethodName" , Selection.MethodName);
			ScheduledJob.Insert("Key" , Selection.Key);
			If TypeOf(Selection.Parameters) = Type("ValueStorage") Then
				ScheduledJob.Insert("Parameters", Selection.Parameters.Get());
			Else
				ScheduledJob.Insert("Parameters", New Array);
			EndIf;
		EndIf;
	Else
		ScheduledJob = ScheduledJobs.FindByUUID(ID);
	EndIf;
	
	Return ScheduledJob;
	
EndFunction

// Returns True if the separated scheduled job with the ScheduledJobGUID key is used.
// 
Function SeparatedScheduledJobUsed(ScheduledJobGUID) Export
	
	RecordSet = InformationRegisters.SeparatedScheduledJobs.CreateRecordSet();
	RecordSet.Filter.ScheduledJob.Set(ScheduledJobGUID);
	RecordSet.Read();
	If RecordSet.Count() = 0 Then
		Return False;
	Else
		Return RecordSet[0].Use;
	EndIf;
		
EndFunction	

// Retrieves an array of scheduled jobs by specified filter.
//
// Parameters:
// Filter - Structure - structure that specifies the filter. 
// The following parameters can be values of this structure:
// UUID, Key, Use, Job. 
// If the filter is not set, all scheduled jobs will be retrieved.
//
// Returns:
// Array.
// 
Function GetScheduledJobs(Filter) Export
	
	If Filter <> Undefined Then
		If TypeOf(Filter) <> Type("Structure") Then
				Raise NStr("en = 'Invalid value of the parameter #1.'");
		EndIf;
		If Filter.Property("Use") Then
			If TypeOf(Filter.Use) <> Type("Boolean") Then
				Raise NStr("en = 'Invalid Use property type of the parameter #1.'");
			EndIf;	
		EndIf;
		If Filter.Property("Key") Then
			If TypeOf(Filter.Key) <> Type("String") Then
				Raise NStr("en = 'Invalid Key property type of the parameter #1.'");
			EndIf;	
		EndIf;
		If Filter.Property("UUID") Then
			If TypeOf(Filter.UUID) <> Type("UUID") Then
				Raise NStr("en = 'Invalid UUID property type of the parameter #1.'");
			EndIf;	
		EndIf;
		If Filter.Property("Job") Then
			If TypeOf(Filter.Job) <> Type("String") Then
				Raise NStr("en = 'Invalid Job property type of the parameter #1.'");
			EndIf;	
		EndIf;
		If Filter.Property("MethodName") Then
			If TypeOf(Filter.MethodName) <> Type("String") Then
				Raise NStr("en = 'Invalid MethodName property type of the parameter #1.'");
			EndIf;	
		EndIf;
	EndIf;
	
	FoundScheduledJobs = New Array;
	If CommonUseCached.DataSeparationEnabled() Then 
		DataArea = CommonUse.SessionSeparatorValue();
		
		SeparatedScheduledJobs = New Array;
		Query = New Query;
		Query.Text = 
		"SELECT
		|	JobQueue.DataArea,
		|	JobQueue.Job,
		|	JobQueue.Use,
		|	JobQueue.ScheduledStartTime,
		|	JobQueue.JobState,
		|	JobQueue.ActiveBackgroundJob,
		|	JobQueue.ExclusiveExecution,
		|	JobQueue.TryNumber,
		|	JobQueue.ScheduledJob,
		|	JobQueue.MethodName,
		|	JobQueue.Parameters,
		|	JobQueue.LastStartDate,
		|	JobQueue.Key
		|FROM
		|	InformationRegister.JobQueue AS JobQueue
		|WHERE
		|	JobQueue.DataArea = &DataArea";
		Query.SetParameter("DataArea", DataArea);
		
		If Filter.Property("Use") 
			Or Filter.Property("Key") 
			Or Filter.Property("UUID") 
			Or Filter.Property("Job")
			Or Filter.Property("MethodName") Then
			PropertyArray = New Array;
			PropertyArray.Add("Use");
			PropertyArray.Add("Key");
			PropertyArray.Add("UUID");
			PropertyArray.Add("Job");
			PropertyArray.Add("MethodName");
			For Each Property In PropertyArray Do
				If Filter.Property(Property) Then 
					If Property = "UUID" Then
						Query.Text = Query.Text + " AND JobQueue.ScheduledJob = &UUID";
					Else
						Query.Text = Query.Text + " AND JobQueue." + Property + " = &" + Property;
					EndIf;
					Query.SetParameter(Property, Filter[Property]);
				EndIf;
			EndDo;
		EndIf;
		Selection = Query.Execute().Choose();
		While Selection.Next() Do
			ScheduledJob = New Structure;
			ScheduledJob.Insert("Job" , Selection.Job);
			ScheduledJob.Insert("Use" , Selection.Use);
			ScheduledJob.Insert("UUID", Selection.ScheduledJob);
			ScheduledJob.Insert("MethodName" , Selection.MethodName);
			ScheduledJob.Insert("Key" , Selection.Key);
			If TypeOf(Selection.Parameters) = Type("ValueStorage") Then
				ScheduledJob.Insert("Parameters", Selection.Parameters.Get());
			Else
				ScheduledJob.Insert("Parameters", New Array);
			EndIf;
			FoundScheduledJobs.Add(ScheduledJob);
		EndDo;
	Else
		If Not Filter.Property("MethodName") Then
			Raise NStr("en = 'Scheduled jobs can be found only by MethodName'");
		EndIf;
		
		For Each ScheduledJobMetadata In Metadata.ScheduledJobs Do
			If Upper(ScheduledJobMetadata.MethodName) = Upper(Filter.MethodName) Then
				FoundScheduledJobs = ScheduledJobs.GetScheduledJobs(New Structure("Metadata", ScheduledJobMetadata));
				Break;
			EndIf;
		EndDo;
	EndIf;
	
	Return FoundScheduledJobs;
	
EndFunction

// Writes the scheduled job to the data base.
//
// Parameters:
// ScheduledJob - ScheduledJob or Structure.
//
Procedure Write(ScheduledJob) Export
	
	If CommonUseCached.DataSeparationEnabled() Then
		If TypeOf(ScheduledJob) <> Type("Structure") Then
			Raise NStr("en = 'Invalid value of the parameter #1.'");
		EndIf;
		DataArea = CommonUse.SessionSeparatorValue();
		If Not ScheduledJob.Property("Job") 
			Or Not ValueIsFilled(ScheduledJob.Job) 
			Or TypeOf(ScheduledJob.Job) <> Type("String") Then
			Raise NStr("en = 'Invalid Job property type of the parameter #1.'");
		EndIf;
		ChangeJob(ScheduledJob.Job, ScheduledJob, DataArea);
	Else
		If TypeOf(ScheduledJob) <> Type("ScheduledJob") Then
			Raise NStr("en = 'Invalid value of the parameter #1.'");
		EndIf;
		
		ScheduledJob.Write();
	EndIf;
	
EndProcedure

// Deletes the scheduled job from the data base.
//
// Parameters:
// ScheduledJob - ScheduledJob or Structure.
//
Procedure Delete(ScheduledJob) Export
	
	If CommonUseCached.DataSeparationEnabled() Then
		If TypeOf(ScheduledJob) <> Type("Structure") Then
			Raise NStr("en = 'Invalid value of the parameter #1.'");
		EndIf;
		
		DataArea = CommonUse.SessionSeparatorValue();
		If Not ScheduledJob.Property("Job") 
			Or Not ValueIsFilled(ScheduledJob.Job) 
			Or TypeOf(ScheduledJob.Job) <> Type("String") Then
			Raise NStr("en = 'Invalid Job property type of the parameter #1.'");
		EndIf;
		DeleteJob(ScheduledJob.Job, DataArea);
	Else
		If TypeOf(ScheduledJob) <> Type("ScheduledJob") Then
			Raise NStr("en = 'Invalid value of the parameter #1.'");
		EndIf;
		
		ScheduledJob.Delete();
	EndIf;

EndProcedure

// Adds a new job to the JobQueue information register. 
// 
// Parameters: 
//  MethodName - String - name of a method from a not global 
//   common module in the following format: ModuleName.MethodName.
//  Parameters - Array - array of parameters that are passed to the method. 
//   Number of parameters and their types must match with
//   method parameters.
//  Key - String - job key. If the key is set, 
//   it must be unique among keys of jobs with the same method name. 
//  ExclusiveExecution - Boolean - flag that shows whether the job will be executed
//   exclusively.
//  DataArea - Number - sets the data area where the job will be added.
// 
// Returns: 
//  String - added job ID.
// 
Function ScheduleJobExecution(MethodName, Parameters = Undefined, Key = "", ExclusiveExecution = False, DataArea = Undefined) Export 
	
	If CommonUseCached.DataSeparationEnabled() Then
		JobParameters = New Structure;
		JobParameters.Insert("MethodName" , MethodName);
		JobParameters.Insert("Parameters" , Parameters);
		JobParameters.Insert("Key" , Key);
		JobParameters.Insert("Use", True);
		
		Return AddJob(JobParameters, DataArea);
		
	EndIf;
	
EndFunction

// Adds update handlers required by this subsystem to the Handlers list. 
// 
// Parameters:
// Handlers - ValueTable - see InfoBaseUpdate.NewUpdateHandlerTable function for details.
// 
Procedure RegisterUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version = "*";
	Handler.Procedure = "JobQueue.UpdateJobQueue";
	
	Handler = Handlers.Add();
	Handler.Version = "*";
	Handler.Procedure = "JobQueue.UpdateSeparatedScheduledJobs";
	Handler.SharedData = True;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Local internal procedures and functions.

Function GetSeparatedScheduledJobList()
	
	SeparatedScheduledJobList = New Array;
	StandardSubsystemsOverridable.FillSeparatedScheduledJobList(SeparatedScheduledJobList);
	JobQueueOverridable.FillSeparatedScheduledJobList(SeparatedScheduledJobList);
	
	Return SeparatedScheduledJobList;
	
EndFunction

Function GetScheduledJobUsageTable()
	
	UsageTable = New ValueTable;
	
	UsageTable.Columns.Add("ScheduledJob", New TypeDescription("String"));
	UsageTable.Columns.Add("Use", New TypeDescription("Boolean"));
	
	StandardSubsystemsOverridable.FillScheduledJobUsageTable(UsageTable);
	JobQueueOverridable.FillScheduledJobUsageTable(UsageTable);
	
	Return UsageTable;
	
EndFunction

Function GetDataAreaTimeZone(DataArea)
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	DataAreas.TimeZone
	|FROM
	|	InformationRegister.DataAreas AS DataAreas
	|WHERE
	|	DataAreas.DataArea = &DataArea";
	Query.SetParameter("DataArea", DataArea);
	QueryResult = Query.Execute();
	
	TimeZone = "";
	If Not QueryResult.IsEmpty() Then 
		Selection = QueryResult.Choose();
		Selection.Next();
		TimeZone = Selection.TimeZone;
	EndIf;
	
	If Not ValueIsFilled(TimeZone) Then
		TimeZone = Undefined;
	EndIf;
	
	Return TimeZone;
	
EndFunction

Function ActiveBackgroundJobCount()
	
	Filter = New Structure("Description, State", GetActiveBackgroundJobDescription(), BackgroundJobState.Active); 
	ActiveBackgroundJobs = BackgroundJobs.GetBackgroundJobs(Filter); 
	
	ActiveBackgroundJobCount = ActiveBackgroundJobs.Count();
	
	Return ActiveBackgroundJobCount;
	
EndFunction

// Calculates the required number of active background jobs.
// 
Function ActiveBackgroundJobCountToStart()
	
	ActiveBackgroundJobCount = ActiveBackgroundJobCount();
	
	ActiveBackgroundJobCountToStart = Constants.MaxActiveBackgroundJobCount.Get() - ActiveBackgroundJobCount;
	If ActiveBackgroundJobCountToStart < 0 Then
		ActiveBackgroundJobCountToStart = 0;
	EndIf;

	Return ActiveBackgroundJobCountToStart;
	
EndFunction

// Starts the specified number of background jobs. 
// 
// Parameters: 
// BackgroundJobsToStartCount - Number - number of background jobs to be started.
//
Procedure StartActiveBackgroundJob(BackgroundJobsToStartCount) 
	
	For Index = 1 to BackgroundJobsToStartCount Do
		JobKey = New UUID;
		Parameters = New Array;
		Parameters.Add(JobKey);
		BackgroundJobs.Execute("JobQueue.ProcessJobQueue", Parameters, JobKey, GetActiveBackgroundJobDescription());
	EndDo;
	
EndProcedure

Function GetActiveBackgroundJobDescription()
	
	Return "ActiveBackgroundJobs_5340185be5b240538bc73d9f18ef8df1";
	
EndFunction

Procedure WriteExecutionControlEventLog(Val EventName, Val WritingJob)
	
	WriteLogEvent(EventName, EventLogLevel.Information, ,
		WritingJob.Job, WritingJob.MethodName + ";" + Format(WritingJob.DataArea, "NZ=0; NG="));
	
EndProcedure

// Executes the method by its string presentation.
// 
// Parameters: 
// MethodName - String - name of the method to be executed.
// Parameters - Array - parameters that are passed to MethodName 
// in their order in the array.
// 
Procedure ExecuteJob(MethodName, Parameters = Undefined)
	
	If JobQueueCached.GetAllowedMethods().Find(Upper(MethodName)) = Undefined Then
		MessagePattern = NStr("en = 'The %1 method is not allowed to be called with job queue.'");
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, MethodName);
		Raise(MessageText);
	EndIf;
	
	ParametersString = "";
	If Parameters <> Undefined And Parameters.Count() > 0 Then
		For Index = 0 to Parameters.UBound() Do 
			ParametersString = ParametersString + "Parameters[" + Index + "],";
		EndDo;
		ParametersString = Mid(ParametersString, 1, StrLen(ParametersString) - 1);
	EndIf;
	
	Execute(MethodName + "(" + ParametersString + ")");
	
EndProcedure

// Calculates the next job start date. 
// 
// Parameters: 
//  Schedule - JobSchedule - schedule whose start date will be calculated.
//  TimeZone - String.
//  LastStartDate - Date - last scheduled job start date. 
//   If the date is set, it is used to check such conditions as 
//   DaysRepeatPeriod, WeeksPeriod, RepeatPeriodInDay. 
//   If the date is not set, it is considered 
//   that the job was not executed before and there is no need to check these conditions.
// 
// Returns: 
// Date - the next job start date.
// 
Function GetScheduledJobStartTime(Val Schedule, Val TimeZone, Val LastStartDate = '00010101')
	
	If ValueIsFilled(LastStartDate) Then 
		LastStartDate = ToLocalTime(LastStartDate, TimeZone);
	EndIf;
	
	CalculationDate = ToLocalTime(CurrentUniversalDate(), TimeZone);

	CalculationPrecision = 5; // start date calculation precision is 5 seconds
	CalculationLimit = 367 * 86400; // calculation limit is 367 days
	Delta = 0;

	// If there is no need to execute the job in the following interval: [CurrentDate; CurrentDate + CalculationLimit], 
	// an empty date is returned.
	If Not Schedule.ExecutionRequired(CalculationDate + CalculationLimit, LastStartDate) Then
		Return '00010101';
	Else
		IntervalBegin = 0;
		IntervalEnd = CalculationLimit;
		While (IntervalEnd - IntervalBegin) > CalculationPrecision Do
			Delta = Round((IntervalEnd - IntervalBegin) / 2);
			If Schedule.ExecutionRequired(CalculationDate + IntervalBegin + Delta, LastStartDate) Then
				IntervalEnd = IntervalBegin + Delta;
			Else
				IntervalBegin = IntervalBegin + Delta + 1;
			EndIf;
		EndDo;
	EndIf;

	FoundDate = CalculationDate + IntervalBegin + Delta;
	
	Return ToUniversalTime(FoundDate, TimeZone);
	
EndFunction
