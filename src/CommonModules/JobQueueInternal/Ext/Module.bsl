////////////////////////////////////////////////////////////////////////////////
// JobQueue: Managing the job queue
//
////////////////////////////////////////////////////////////////////////////////

#Region InternalInterface

// Calculates the next job start time. 
// 
// Parameters: 
// Schedule             - JobSchedule - schedule that needs the next start time calculated.
// TimeZone             - String.
// BeginDateOfLastStart - Date - Start date of the last start of scheduled job. 
//                        If the date is set, it will be used to check conditions
//                        such as DaysRepeatPeriod, WeeksPeriod, RepeatPeriodInDay.
//                        If the date is not set, the job is considered to have
//                        never started and these conditions are not checked.
// 
// Returns: 
// Date - Next job start time calculated. 
// 
Function GetScheduledJobStartTime(Val Schedule, Val TimeZone, 
		Val BeginDateOfLastStart = '00010101', Val EndDateOfLastStart = '00010101') Export
	
	If IsBlankString(TimeZone) Then
		TimeZone = Undefined;
	EndIf;
	
	If ValueIsFilled(BeginDateOfLastStart) Then 
		BeginDateOfLastStart = ToLocalTime(BeginDateOfLastStart, TimeZone);
	EndIf;
	
	If ValueIsFilled(EndDateOfLastStart) Then
		EndDateOfLastStart = ToLocalTime(EndDateOfLastStart, TimeZone);
	EndIf;
	
	CalculationDate = ToLocalTime(CurrentUniversalDate(), TimeZone);
	
	FoundDate = NextScheduleExecutionDate(Schedule, CalculationDate, BeginDateOfLastStart, EndDateOfLastStart);
	
	If ValueIsFilled(FoundDate) Then
		Return ToUniversalTime(FoundDate, TimeZone);
	Else
		Return FoundDate;
	EndIf;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Declarations of internal events (SL handlers can be attached to these events).

// Declares events of the JobQueue subsystem:
//
// Server events:
//   OnReceiveTemplateList
//   OnDefineHandlerAliases
//   OnDefineErrorHandlers
//   OnDetermineScheduledJobUsed
//
// See the description of this procedure in the StandardSubsystemsServer module.
Procedure OnAddInternalEvent(ClientEvents, ServerEvents) Export
	
	// SERVER EVENTS
	
	// Generates a list of templates for queued jobs.
	//
	// Parameters:
	//  Templates - Array of String - The parameter should include
	//              names of predefined shared scheduled jobs to be
	//              used as queue job templates.
	//
	// Syntax:
	// Procedure OnReceiveTemplateList(Templates) Export
	//
	// Identical to JobQueueOverridable.FillSeparatedScheduledJobList.
	ServerEvents.Add(
		"StandardSubsystems.SaaSOperations.JobQueue\OnReceiveTemplateList");
	
	// Fills a map of method names and their aliases for calling from a job queue
	//
	// Parameters:
	//  NameAndAliasMap - Map
	//   Key   - method alias, example: ClearDataArea.
	//   Value - method name, example: SaaSOperations.ClearDataArea. 
 //            You can pass Undefined if the name is identical to the alias.
	//
	// Syntax:
	// Procedure OnDefineHandlesAlias(CorrespondenceBetweenNamesAndAlias) Export
	//
	// Identical to JobQueueOverridable.GetJobQueueAllowedMethods.
	ServerEvents.Add(
		"StandardSubsystems.SaaSOperations.JobQueue\OnDefineHandlerAliases");
		
	// Sets correspondence between error handler methods and
	// alias of methods where errors occurred.
	//
	// Parameters:
	//  ErrorHandlers - Map
	//   Key - method alias, example: ClearDataArea.
	//   Value - Method name - error handler, called upon error. The error handler is called 
	//                         whenever a job execution fails. The error handler is always 
	//                         called in the data area of the failed job. The error handler 
	//                         method can be called by the queue mechanisms. 
	//    Error handler parameters:
	//     JobParameters - Structure - queue job parameters:
	//      Parameters,
	//      AttemptNumber,
	//      RestartCountOnFailure,
	//      BeginDateOfLastStart
  //     ErrorInfo - ErrorInfo - description of error that occurred during job execution.
	//
	// Syntax:
	// Procedure OnDefineErrorHandlers(ErrorHandlers) Export
	//
	// Identical to JobQueueOverridable.OnDefineErrorHandlers.
	ServerEvents.Add(
		"StandardSubsystems.SaaSOperations.JobQueue\OnDefineErrorHandlers");
	
	// Generates a scheduled job table with flags that show whether a job is used in SaaS mode.
	//
	// Parameters:
	// UsageTable - ValueTable - table to be filled with scheduled jobs with usage flags. It contains the following columns::
	//   ScheduledJob - String - predefined scheduled job name.
	//   Use - Boolean - True if the scheduled job must be executed in SaaS mode. False otherwise.
	//
	// Syntax:
	// Procedure OnDetermineScheduledJobUsed(UsageTable) Export
	//
	ServerEvents.Add(
		"StandardSubsystems.SaaSOperations.JobQueue\OnDetermineScheduledJobsUsed");
	
EndProcedure

// See the description of this procedure in the StandardSubsystemsServer module.
Procedure InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers) Export
	
	// SERVER HANDLERS
	
	ServerHandlers["StandardSubsystems.InfobaseVersionUpdate\OnAddUpdateHandlers"].Add(
		"JobQueueInternal");
	
	ServerHandlers["StandardSubsystems.BaseFunctionality\OnEnableSeparationByDataAreas"].Add(
		"JobQueueInternal");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// SL event handlers

// Called when enabling data separation by data area.
//
Procedure OnEnableSeparationByDataAreas() Export
	
	SetScheduledJobUse();
	
	If Constants.MaxActiveBackgroundJobExecutionTime.Get() = 0 Then
		Constants.MaxActiveBackgroundJobExecutionTime.Set(600);
	EndIf;
	
	If Constants.MaxActiveBackgroundJobCount.Get() = 0 Then
		Constants.MaxActiveBackgroundJobCount.Set(1);
	EndIf;
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Export internal procedures and functions

// Generates execution schedule for jobs in JobQueue information register.
// 
Procedure JobProcessingPlanning() Export
	
	If Not CommonUseCached.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	// OnScheduledJobStart is not called because the necessary actions are executed privately.
	
	// Selecting events with Executing, Completed, NotScheduled, or ExecutionError status
	Query = New Query;
	
	JobCatalogs = JobQueueInternalCached.GetJobCatalogs();
	QueryText = "";
	For Each JobCatalog In JobCatalogs Do
		
		If Not IsBlankString(QueryText) Then
			
			QueryText = QueryText + "
			|
			|UNION ALL
			|"
			
		EndIf;
		
		If CommonUseCached.IsSeparatedConfiguration() And CommonUseCached.IsSeparatedMetadataObject(JobCatalog.CreateItem().Metadata().FullName(), CommonUseCached.AuxiliaryDataSeparator()) Then
			
			QueryText = QueryText + StringFunctionsClientServer.SubstituteParametersInString(
			"SELECT
			|	Queue.DataAreaAuxiliaryData AS DataArea,
			|	Queue.Ref AS ID,
			|	ISNULL(Queue.Template, UNDEFINED) AS Template,
			|	ISNULL(TimeZones.Value, """") AS TimeZone,
			|	CASE
			|		WHEN Queue.Template = VALUE(Catalog.QueueJobTemplates.EmptyRef)
			|			THEN Queue.Schedule
			|		ELSE Queue.Template.Schedule
			|	END AS Schedule,
			|	CASE
			|		WHEN Queue.Template = VALUE(Catalog.QueueJobTemplates.EmptyRef)
			|			THEN Queue.RestartCountOnFailure
			|		ELSE Queue.Template.RestartCountOnFailure
			|	END AS RestartCountOnFailure,
			|	CASE
			|		WHEN Queue.Template = VALUE(Catalog.QueueJobTemplates.EmptyRef)
			|			THEN Queue.RestartIntervalOnFailure
			|		ELSE Queue.Template.RestartIntervalOnFailure
			|	END AS RestartIntervalOnFailure
			|FROM
			|	%1 AS Queue
			|		LEFT JOIN Constant.DataAreaTimeZone AS TimeZones
			|		ON Queue.DataAreaAuxiliaryData = TimeZones.DataAreaAuxiliaryData
			|WHERE
			|	Queue.JobState IN (VALUE(Enum.JobStates.Executing), VALUE(Enum.JobStates.Completed), VALUE(Enum.JobStates.NotScheduled), VALUE(Enum.JobStates.ExecutionError))"
			, JobCatalog.EmptyRef().Metadata().FullName());
			
		Else
			
			QueryText = QueryText + StringFunctionsClientServer.SubstituteParametersInString(
			"SELECT
			|	-1 AS DataArea,
			|	Queue.Ref AS ID,
			|	UNDEFINED AS Template,
			|	"""" AS TimeZone,
			|	Queue.Schedule AS Schedule,
			|	Queue.RestartCountOnFailure AS RestartCountOnFailure,
			|	Queue.RestartIntervalOnFailure AS RestartIntervalOnFailure
			|FROM
			|	%1 AS Queue
			|WHERE
			|	Queue.JobState IN (VALUE(Enum.JobStates.Executing), VALUE(Enum.JobStates.Completed), VALUE(Enum.JobStates.NotScheduled), VALUE(Enum.JobStates.ExecutionError))"
			, JobCatalog.EmptyRef().Metadata().FullName());
			
		EndIf;
		
	EndDo;
	
	Query.Text = QueryText;
	Result = CommonUse.ExecuteQueryOutsideTransaction(Query);
	Selection = Result.Select();
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaSOperations") Then
		SaasOperationsModule = CommonUse.CommonModule("SaaSOperations");
	Else
		SaasOperationsModule = Undefined;
	EndIf;
	
	While Selection.Next() Do
		
		Try
			LockDataForEdit(Selection.ID);
		Except
			// The record is locked, proceed to the next record
			Continue;
		EndTry;
		
		// Checking for data area lock
		If SaasOperationsModule <> Undefined
			And Selection.DataArea <> -1 
			And SaasOperationsModule.DataAreaLocked(Selection.DataArea) Then
			
			// The area is locked, proceeding to the next record
			Continue;
		EndIf;
		
		// Rescheduling the completed scheduled jobs and failed background jobs; deleting the completed background jobs
		ScheduleJob(Selection);
		
	EndDo;

	// Calculating the required number of active background jobs
	BackgroundJobsToStartCount = ActiveBackgroundJobCountToStart();
	
	// Starting active background jobs
	StartActiveBackgroundJob(BackgroundJobsToStartCount);
	
EndProcedure

// Executes jobs from JobQueue information register.
// 
// Parameters: 
// BackgroundJobKey - UUID - the key is required to find active background jobs.
//
Procedure ProcessJobQueue(BackgroundJobKey) Export
	
	// OnScheduledJobStart is not called
	// because the necessary actions are executed privately.
	
	FoundBackgroundJob = BackgroundJobs.GetBackgroundJobs(New Structure("Key", BackgroundJobKey));
	If FoundBackgroundJob.Count() = 1 Then
		ActiveBackgroundJob = FoundBackgroundJob[0];
	Else
		Return;
	EndIf;
	
	CanExecute = True;
	ExecutionStarted = CurrentUniversalDate();
	
	MaxActiveBackgroundJobExecutionTime = 
		Constants.MaxActiveBackgroundJobExecutionTime.Get();
	MaxActiveBackgroundJobCount =
		Constants.MaxActiveBackgroundJobCount.Get();
	
	Query = New Query;
	
	JobCatalogs = JobQueueInternalCached.GetJobCatalogs();
	QueryText = "";
	For Each JobCatalog In JobCatalogs Do
		
		FirstLine = IsBlankString(QueryText);
		
		If Not FirstLine Then
			
			QueryText = QueryText + "
			|
			|UNION ALL
			|"
			
		EndIf;
		
		If CommonUseCached.IsSeparatedConfiguration() And CommonUse.IsSeparatedMetadataObject(JobCatalog.CreateItem().Metadata().FullName(), CommonUseCached.AuxiliaryDataSeparator()) Then
			
			QueryText = QueryText + StringFunctionsClientServer.SubstituteParametersInString(
			"SELECT
			|	Queue.DataAreaAuxiliaryData AS DataArea,
			|	Queue.Ref AS ID,
			|	Queue.Use,
			|	Queue.ScheduledStartTime AS ScheduledStartTime,
			|	Queue.JobState,
			|	Queue.ActiveBackgroundJob,
			|	Queue.ExclusiveExecution AS ExclusiveExecution,
			|	Queue.AttemptNumber,
			|	Queue.Template AS Template,
			|	ISNULL(Queue.Template.Ref, UNDEFINED) AS TemplateRef,
			|	ISNULL(TimeZones.Value, """") AS TimeZone,
			|	CASE
			|		WHEN Queue.Template = VALUE(Catalog.QueueJobTemplates.EmptyRef)
			|			THEN Queue.Schedule
			|		ELSE Queue.Template.Schedule
			|	END AS Schedule,
			|	CASE
			|		WHEN Queue.Template = VALUE(Catalog.QueueJobTemplates.EmptyRef)
			|			THEN Queue.MethodName
			|		ELSE Queue.Template.MethodName
			|	END AS MethodName,
			|	Queue.Parameters,
			|	Queue.BeginDateOfLastStart,
			|	Queue.EndDateOfLastStart
			|FROM %1 AS QUEUE LEFT JOIN InformationRegister.DataAreaSessionLocks AS Locks
			|		ON Queue.DataAreaAuxiliaryData = Locks.DataAreaAuxiliaryData
			|		LEFT JOIN Constant.DataAreaTimeZone AS TimeZones
			|		ON Queue.DataAreaAuxiliaryData = TimeZones.DataAreaAuxiliaryData
			|WHERE
			|	Queue.Use
			|	AND Queue.ScheduledStartTime <= &CurrentUniversalDate
			|	AND Queue.JobState = VALUE(Enum.JobStates.Scheduled)
			|	AND (Queue.ExclusiveExecution
			|			OR Locks.DataAreaAuxiliaryData IS NULL 
			|			OR Locks.LockPeriodStart > &CurrentUniversalDate
			|			OR Locks.LockPeriodEnd < &CurrentUniversalDate)"
			, JobCatalog.EmptyRef().Metadata().FullName());
			
		Else
			
			QueryText = QueryText + StringFunctionsClientServer.SubstituteParametersInString(
			"SELECT
			|	-1 AS DataArea,
			|	Queue.Ref AS ID,
			|	Queue.Use,
			|	Queue.ScheduledStartTime AS ScheduledStartTime,
			|	Queue.JobState,
			|	Queue.ActiveBackgroundJob,
			|	Queue.ExclusiveExecution AS ExclusiveExecution,
			|	Queue.AttemptNumber,
			|	UNDEFINED AS Template,
			|	UNDEFINED AS TemplateRef,
			|	"""" AS TimeZone,
			|	Queue.Schedule AS Schedule,
			|	Queue.MethodName AS MethodName,
			|	Queue.Parameters,
			|	Queue.BeginDateOfLastStart,
			|	Queue.EndDateOfLastStart
			|FROM %1 AS Queue
			|WHERE
			|	Queue.Use
			|	AND Queue.ScheduledStartTime <= &CurrentUniversalDate
			|	AND Queue.JobState = VALUE(Enum.JobStates.Scheduled)"
			, JobCatalog.EmptyRef().Metadata().FullName());
			
		EndIf;
		
	EndDo;
	
	QueryText = "SELECT TOP 111
	|	NestedQuery.DataArea,
	|	NestedQuery.ID AS ID,
	|	NestedQuery.Use,
	|	NestedQuery.ScheduledStartTime AS ScheduledStartTime,
	|	NestedQuery.ActiveBackgroundJob,
	|	NestedQuery.ExclusiveExecution AS ExclusiveExecution,
	|	NestedQuery.AttemptNumber,
	|	NestedQuery.Template,
	|	NestedQuery.TemplateRef,
	|	NestedQuery.TimeZone,
	|	NestedQuery.Schedule,
	|	NestedQuery.MethodName,
	|	NestedQuery.Parameters,
	|	NestedQuery.BeginDateOfLastStart,
	|	NestedQuery.EndDateOfLastStart
	|FROM
	|	(" +  QueryText + ") AS NestedQuery
	|
	|ORDER BY
	|	ExclusiveExecution DESC,
	|	ScheduledStartTime,
	|	ID";
	
	Query.Text = QueryText;
	SelectionSizeText = Format(MaxActiveBackgroundJobCount * 3, "NZ=; NG=");
	Query.Text = StrReplace(Query.Text, "111", SelectionSizeText);
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaSOperations") Then
		SaasOperationsModule = CommonUse.CommonModule("SaaSOperations");
	Else
		SaasOperationsModule = Undefined;
	EndIf;
	
	While CanExecute Do 
		Query.SetParameter("CurrentUniversalDate", CurrentUniversalDate());
		
		Selection = CommonUse.ExecuteQueryOutsideTransaction(Query).Select();
		
		Locked = False;
		While Selection.Next() Do 
			Try
				
				LockDataForEdit(Selection.ID);
				
				// Checking for data area lock
				If SaasOperationsModule <> Undefined
					And Selection.DataArea <> -1 
					And SaasOperationsModule.DataAreaLocked(Selection.DataArea) Then
					
					UnlockDataForEdit(Selection.ID);
					
					// The area is locked, proceeding to the next record
					Continue;
				EndIf;
				
				If ValueIsFilled(Selection.Template)
						And Selection.TemplateRef = Undefined Then
					
					MessagePattern = NStr("en = 'Queue creation template with ID %1 not found'");
					MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, Selection.Template);
					WriteLogEvent(NStr("en = 'Job queue.Execution'", 
						CommonUseClientServer.DefaultLanguageCode()), 
						EventLogLevel.Error,
						,
						,
						MessageText);
					
					UnlockDataForEdit(Selection.ID);
					Continue;
				EndIf;
				
				Locked = True;
				Break;
			Except
				// Locking failed
			EndTry;
		EndDo;
		
		If Not Locked Then 
			Return;
		EndIf;
		
		Schedule = Selection.Schedule.Get();
		If Schedule <> Undefined Then
			// Checking for compliance with acceptable queue interval
			TimeZone = Selection.TimeZone;
			
			If IsBlankString(TimeZone) Then
				TimeZone = Undefined;
			EndIf;
			
			AreaTime = ToLocalTime(CurrentUniversalDate(), TimeZone);
			Overdue = Not Schedule.ExecutionRequired(AreaTime);
		Else
			Overdue = False;
		EndIf;
		
		If Overdue Then
			// Job needs rescheduling
			BeginTransaction();
			Try
				DataLock = New DataLock;
				LockItem = DataLock.Add(Selection.ID.Metadata().FullName());
				LockItem.SetValue("Ref", Selection.ID);
				
				If Selection.DataArea <> -1 Then
					CommonUse.SetSessionSeparation(True, Selection.DataArea);
				EndIf;
				DataLock.Lock();
				
				Job = Selection.ID.GetObject();
				Job.JobState = Enums.JobStates.NotScheduled;
				Job.Write();
				CommitTransaction();
			Except
				CommonUse.SetSessionSeparation(False);
				RollbackTransaction();
				Raise;
			EndTry;
			CommonUse.SetSessionSeparation(False);
		Else
			ExecuteQueueJob(Selection.ID, ActiveBackgroundJob, Selection.Template, Selection.MethodName);
		EndIf;
		
		UnlockDataForEdit(Selection.ID);
		
		// Checking if further execution is allowed
		ExecutionTime = CurrentUniversalDate() - ExecutionStarted;
		If ExecutionTime > MaxActiveBackgroundJobExecutionTime Then
			CanExecute = False;
		EndIf;
	EndDo;
	
EndProcedure

// An internal procedure called to execute job error handler
// whenever the job execution process fails to complete the job.
//
// Parameters:
//  Job - CatalogRef - reference to a job that requires error handler execution.
//
Procedure HandleError(Val Job) Export
	
	Try
		
		LockDataForEdit(Job);
		
		ErrorHandlerParameters = GetErrorHandlerParameters(Job);
		If ErrorHandlerParameters.HandlerExists Then
			ExecuteConfigurationMethod(ErrorHandlerParameters.MethodName, ErrorHandlerParameters.HandlerCallParameters);
		EndIf;
		
		Job = ErrorHandlerParameters.Job.GetObject();
		Job.JobState = Enums.JobStates.ExecutionError;
		CommonUse.WriteAuxiliaryData(Job);
		
	Except
		
		CommentPattern = NStr("en = 'Error handler error
			|Method alias: %1
			|Error handler method:
			|%2
			|Reason: %3'");
		CommentText = StringFunctionsClientServer.SubstituteParametersInString(
			CommentPattern,
			ErrorHandlerParameters.JobMethodName,
			ErrorHandlerParameters.MethodName,
			DetailErrorDescription(ErrorInfo()));
			
		WriteLogEvent(
			NStr("en = 'Scheduled job queue.Error handler error'", 
				CommonUseClientServer.DefaultLanguageCode()),
			EventLogLevel.Error,
			,
			,
			CommentText);
			
	EndTry;
	
	UnlockDataForEdit(Job.Ref);
	
EndProcedure

// Internal procedure that cancels both error handler jobs and own jobs. 
// Required whenever HandleError job execution fails.
//
// Parameters:
//  CallParameters   - Array - Parameter array sent to the failed job being handled 
//                             is only used to determine the failed job.
//  ErrorInformation - ErrorDescription - Not used; included only because this parameter is 
//                                        mandatory for the error handler.
//  RecursionCounter - Number - Used to count the created job cancellation jobs.
//
Procedure CancelErrorHandlerJobs(Val CallParameters, Val ErrorInfo = Undefined, Val RecursionCounter = 1) Export
	
	BeginTransaction();
	Try
		
		JobReference = CallParameters.Parameters[0];
		
		If Not CommonUse.RefExists(JobReference) Then
		
			RollbackTransaction();
			Return;
		
		EndIf;
		
		Job = JobReference.GetObject();
		
		LockDataForEdit(JobReference);
		
		Job.JobState = Enums.JobStates.ExecutionError;
		CommonUse.WriteAuxiliaryData(Job);
		
		ErrorHandlerParameters = GetErrorHandlerParameters(Job);
		If ErrorHandlerParameters.MethodName = "JobQueueInternal.CancelErrorHandlerJobs" Then
			
			CancelErrorHandlerJobs(ErrorHandlerParameters.HandlerCallParameters[0], ErrorInfo, RecursionCounter + 1);
			
		Else
			
			CommentPattern = NStr("en = 'Job cancel handler was executed.
			|Method alias:
			|%1 Recursion level: %2'");
			CommentText = StringFunctionsClientServer.SubstituteParametersInString(
				CommentPattern,
				ErrorHandlerParameters.JobMethodName,
				RecursionCounter);
				
			WriteLogEvent(
				NStr("en = 'Scheduled job queue.Cancel error handler jobs'",
					CommonUseClientServer.DefaultLanguageCode()),
				EventLogLevel.Information,
				,
				,
				CommentText);
			
		EndIf;
			
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
	
	EndTry;
	
	UnlockDataForEdit(JobReference);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Local internal procedures and functions

// This method is used to call job handler and error handler methods.
//
// Parameters: 
// MethodName - String - Name of the method that is called.
// Parameters - Array  - Values of parameters sent to method, 
//                       according to parameter order in the called method.
//
Procedure ExecuteConfigurationMethod(MethodName, Parameters = Undefined)

	If CommonUseCached.DataSeparationEnabled() And CommonUseCached.CanUseSeparatedData() Then
		SeparatorSet = True;
		SeparatorValue = SaaSOperations.SessionSeparatorValue();
	Else
		SeparatorSet = False;
	EndIf;
	
	If TransactionActive() Then
		
		ErrorMessageText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Active transactions found when starting handler %1.'"),
				MethodName);
			
		WriteLogEvent(NStr("en = 'Scheduled job queue.Execution'", 
			CommonUseClientServer.DefaultLanguageCode()),
			EventLogLevel.Error,
			,
			,
			ErrorMessageText);
			
		Raise ErrorMessageText;
		
	EndIf;
	
	Try
		
		SafeMode.ExecuteConfigurationMethod(MethodName, Parameters);
		
		If TransactionActive() Then
		
			While TransactionActive() Do
				RollbackTransaction();
			EndDo;
			
			MessagePattern = NStr("en = 'Unclosed transaction found upon handler %1 execution'");
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, MethodName);
			WriteLogEvent(NStr("en = 'Scheduled job queue.Execution'", 
				CommonUseClientServer.DefaultLanguageCode()),
				EventLogLevel.Error, 
				,
				, 
				MessageText);
			
		EndIf;
		
		If Not(SeparatorSet) And CommonUse.UseSessionSeparator() Then
			
			ErrorMessageText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Session separation was not disabled upon handler %1 execution.'"),
				MethodName);
			
			WriteLogEvent(NStr("en = 'Scheduled job queue.Execution'", 
				CommonUseClientServer.DefaultLanguageCode()),
				EventLogLevel.Error,
				,
				,
				ErrorMessageText);
			
			CommonUse.SetSessionSeparation(False);
			
		ElsIf SeparatorSet And SeparatorValue <> SaaSOperations.SessionSeparatorValue() Then
			
			ErrorMessageText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Session separator value was changed upon handler %1 execution.'"),
				MethodName);
			
			WriteLogEvent(NStr("en = 'Scheduled job queue.Execution'", 
				CommonUseClientServer.DefaultLanguageCode()),
				EventLogLevel.Error,
				,
				,
				ErrorMessageText);
			
			CommonUse.SetSessionSeparation(True,SeparatorValue);
			
		EndIf;
		
		
	Except
		
		While TransactionActive() Do
			RollbackTransaction();
		EndDo;
		
		If Not(SeparatorSet) And CommonUse.UseSessionSeparator() Then
			CommonUse.SetSessionSeparation(False);
		ElsIf SeparatorSet And SeparatorValue <> SaaSOperations.SessionSeparatorValue() Then
			CommonUse.SetSessionSeparation(True,SeparatorValue);
		EndIf;
		
		ErrorText = ErrorInfo().Description;
		
		Raise ErrorText;
		
	EndTry;
	
EndProcedure

// Receives error handler start parameters via job reference.
//
// Parameters:
//  Job  - CatalogRef.JobQueue or CatalogRef.DataAreaJobQueue - 
//         Reference to job used to get the error handler parameters.
//
// Returns:
//   Structure                - Error handler start parameters.
//      MethodName            - String containing the name of error handler method to be executed.
//      JobMethodName         - String containing the name of job method that was to be executed.
//      HandlerCallParameters - array containing parameters to be sent to the error handler procedure.
//      HandlerExists         - Boolean, error handler exists for this job.
//      Job                   - CatalogRef.JobQueue or CatalogRef.DataAreaJobQueue -
//                              Reference to job sent as input parameter.
//
Function GetErrorHandlerParameters(Val Job,Val JobFailureInfo = Undefined)

	Result = New Structure("MethodName,JobMethodName,HandlerCallParameters,HandlerExists,Job");
	Result.Job = Job.Ref;
	
	If CommonUseCached.IsSeparatedMetadataObject(Job.Metadata().FullName(), 
			CommonUseCached.AuxiliaryDataSeparator()) 
		And ValueIsFilled(Job.Template) Then
		
		Result.JobMethodName = Job.Template.MethodName;
		
	Else
		
		Result.JobMethodName = Job.MethodName;
		
	EndIf;
	
	ErrorHandlerMethodName = 
		JobQueueInternalCached.MapBetweenErrorHandlersAndAliases().Get(Upper(Result.JobMethodName));
	Result.MethodName = ErrorHandlerMethodName;
	Result.HandlerExists = ValueIsFilled(Result.MethodName);
	If Result.HandlerExists Then
		JobParameters = New Structure;
		JobParameters.Insert("Parameters", Job.Parameters.Get());
		JobParameters.Insert("AttemptNumber", Job.AttemptNumber);
		JobParameters.Insert("RestartCountOnFailure", Job.RestartCountOnFailure);
		JobParameters.Insert("BeginDateOfLastStart", Job.BeginDateOfLastStart);
		
		HandlerCallParameters = New Array;
		HandlerCallParameters.Add(JobParameters);
		HandlerCallParameters.Add(JobFailureInfo);
		
		Result.HandlerCallParameters = HandlerCallParameters;
	Else
		Result.HandlerCallParameters = Undefined;
	EndIf;

	Return Result;
	
EndFunction

// Generates and returns a table containing names of scheduled jobs with usage flag.
//
// Returns:
//  ValueTable - table to be filled with scheduled jobs and usage flags.
//
Function GetScheduledJobUsageTable()
	
	UsageTable = New ValueTable;
	UsageTable.Columns.Add("ScheduledJob", New TypeDescription("String"));
	UsageTable.Columns.Add("Use", New TypeDescription("Boolean"));
	
	// Mandatory for this subsystem.
	NewRow = UsageTable.Add();
	NewRow.ScheduledJob = "JobProcessingPlanning";
	NewRow.Use       = True;
	
	EventHandlers = CommonUse.InternalEventHandlers(
		"StandardSubsystems.SaaSOperations.JobQueue\OnDetermineScheduledJobsUsed");
	
	For Each Handler In EventHandlers Do
		Handler.Module.OnDetermineScheduledJobsUsed(UsageTable);
	EndDo;
	
	JobQueueOverridable.OnDetermineScheduledJobsUsed(UsageTable);
	
	Return UsageTable;
	
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
	
	ActiveBackgroundJobCountToStart = 
		Constants.MaxActiveBackgroundJobCount.Get() - ActiveBackgroundJobCount;
	
	If ActiveBackgroundJobCountToStart < 0 Then
		ActiveBackgroundJobCountToStart = 0;
	EndIf;

	Return ActiveBackgroundJobCountToStart;
	
EndFunction

// Starts the required number of background jobs.
// 
// Parameters: 
// BackgroundJobsToStartCount - Number - number of background jobs to be started.
//
Procedure StartActiveBackgroundJob(BackgroundJobsToStartCount) 
	
	For Index = 1 To BackgroundJobsToStartCount Do
		JobKey = New UUID;
		Parameters = New Array;
		Parameters.Add(JobKey);
		BackgroundJobs.Execute("JobQueueInternal.ProcessJobQueue", Parameters, JobKey, GetActiveBackgroundJobDescription());
	EndDo;
	
EndProcedure

Function GetActiveBackgroundJobDescription()
	
	Return "ActiveBackgroundJobs_5340185be5b240538bc73d9f18ef8df1";
	
EndFunction

Procedure WriteExecutionControlEventLog(Val EventName, Val WritingJob, Val Comment = "")
	
	If Not IsBlankString(Comment) Then
		Comment = Comment + Chars.LF;
	EndIf;
	
	WriteLogEvent(EventName, EventLogLevel.Information, ,
		String(WritingJob.UUID()), Comment + WritingJob.MethodName + ";" + 
			?(CommonUseCached.IsSeparatedConfiguration() And CommonUse.IsSeparatedMetadataObject(WritingJob.Metadata().FullName(),
				CommonUseCached.AuxiliaryDataSeparator()),
				Format(WritingJob.DataAreaAuxiliaryData, "NZ=0;NG="), "-1"));
	
EndProcedure

// Executes handler for a job not based on a template.
// 
// Parameters: 
//  Alias      - String - alias of method to be executed.
//  Parameters - Array - parameters are sent to MethodName according to the array item order.
// 
Procedure ExecuteJobHandler(Template, Alias, Parameters)
	
	MethodName = JobQueueInternalCached.MapBetweenMethodNamesAndAliases().Get(Upper(Alias));
	If MethodName = Undefined Then
		MessagePattern = NStr("en = 'Method %1 cannot be called via job queue.'");
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, Alias);
		Raise(MessageText);
	EndIf;
	
	ExecuteConfigurationMethod(MethodName,Parameters);
	
EndProcedure

// Returns the next schedule execution date.
//
// Parameters:
//  Schedule               - JobSchedule - schedule used to determine the date.
//  DateToCheck            - Date (DateTime) - nearest date that can be scheduled for execution.
//  BeginDateOfLastStart   - Date (DateTime) - Start date of the job's last start. 
//                           If the date is set, it will be used to check conditions 
//                           such as DaysRepeatPeriod, WeeksPeriod, RepeatPeriodInDay. 
//                           If the date is not set, the job is considered to have
//                           never started and these conditions are not checked. 
//  EndDateOfLastStart     - Date (DateTime) - End date of the job's last start. 
//                           If the date is set, it will be used to check the 
//                           RepeatPause condition. If the date is not set, the
//                           job is considered to have never completed 
//                           and these conditions are not checked. 
//  MaximumPlanningHorizon - Number - Maximum number of seconds relative to DateToCheck 
//                           allowed for scheduling. Increasing this value can result 
//                           in longer calculation time for large schedules.
//
Function NextScheduleExecutionDate(Val Schedule, Val DateToCheck, 
	Val BeginDateOfLastStart = Undefined, Val EndDateOfLastStart = Undefined, 
	Val MaximumPlanningHorizon = Undefined) Export
	
	If MaximumPlanningHorizon = Undefined Then
		MaximumPlanningHorizon = 366 * 86400 * 10;
	EndIf;
	
	InitialDateToCheck = DateToCheck;
	BeginTimeOfLastStart = '00010101' + (BeginDateOfLastStart - BegOfDay(BeginDateOfLastStart));
	
	// Boundary dates
	If ValueIsFilled(Schedule.EndDate)
		And DateToCheck > Schedule.EndDate Then
		
		// Daily execution interval has ended
		Return '00010101';
	EndIf;
		
	If DateToCheck < Schedule.BeginDate Then
		DateToCheck = Schedule.BeginDate;
	EndIf;
	
	CanChangeDay = True;
	
	// Periodicity management
	If ValueIsFilled(BeginDateOfLastStart) Then
		
		// Weekly period
		If Schedule.WeeksPeriod > 1
			And (BegOfWeek(DateToCheck) - BegOfWeek(BeginDateOfLastStart)) / (7 * 86400) < Schedule.WeeksPeriod Then
		
			DateToCheck = BegOfWeek(BeginDateOfLastStart) + 7 * 86400 * Schedule.WeeksPeriod;
		EndIf;
		
		// Daily period
		If Schedule.DaysRepeatPeriod = 0 Then
			If BegOfDay(DateToCheck) <> BegOfDay(BeginDateOfLastStart) Then
				// Job already completed, repetition not set
				Return '00010101';
			EndIf;
			
			CanChangeDay = False;
		EndIf;
		
		If Schedule.DaysRepeatPeriod > 1
			And BegOfDay(DateToCheck) - BegOfDay(BeginDateOfLastStart) < (Schedule.DaysRepeatPeriod - 1)* 86400 Then
			
			DateToCheck = BegOfDay(BeginDateOfLastStart) + Schedule.DaysRepeatPeriod * 86400;
		EndIf;
		
		// If a job is repeated once per day (but not more often), 
   // shift it to the next day following the last start
		If Schedule.DaysRepeatPeriod = 1 And Schedule.RepeatPeriodInDay = 0 Then
			DateToCheck = Max(DateToCheck, BegOfDay(BeginDateOfLastStart+86400));
		EndIf;

	EndIf;
	
	// Allowed start interval management
	ChangeMonth = False;
	ChangeDay = False;
	While True Do
		
		If DateToCheck - InitialDateToCheck > MaximumPlanningHorizon Then
			// Postpone planning
			Return '00010101';
		EndIf;
		
		If Not CanChangeDay
			And (ChangeDay Or ChangeMonth) Then
			
			// Job already completed, repetition not set
			Return '00010101';
		EndIf;
		
		// Months
		While ChangeMonth
			Or Schedule.Months.Count() > 0 
			And Schedule.Months.Find(Month(DateToCheck)) = Undefined Do
			
			ChangeMonth = False;
			
			// Advance to next month
			DateToCheck = BegOfMonth(AddMonth(DateToCheck, 1));
		EndDo;
		
		// Day of the month
		DaysInMonth = Day(EndOfMonth(DateToCheck));
		If Schedule.DayInMonth <> 0 Then
			
			CurrentDay = Day(DateToCheck);
			
			If Schedule.DayInMonth > 0 
				And (DaysInMonth < Schedule.DayInMonth Or CurrentDay > Schedule.DayInMonth)
				Or Schedule.DayInMonth < 0 
				And (DaysInMonth < -Schedule.DayInMonth Or CurrentDay > DaysInMonth - -Schedule.DayInMonth) Then
				
				// This month does not include this day, or this day has already passed
				ChangeMonth = True;
				Continue;
			EndIf;
			
			If Schedule.DayInMonth > 0 Then
				DateToCheck = BegOfMonth(DateToCheck) + (Schedule.DayInMonth - 1) * 86400;
			EndIf;
			
			If Schedule.DayInMonth < 0 Then
				DateToCheck = BegOfDay(EndOfMonth(DateToCheck)) - (-Schedule.DayInMonth -1) * 86400;
			EndIf;
		EndIf;
		
		// Day of week in the month
		If Schedule.WeekDayInMonth <> 0 Then
			If Schedule.WeekDayInMonth > 0 Then
				WeekStartDay = (Schedule.WeekDayInMonth - 1) * 7 + 1;
			EndIf;
			If Schedule.WeekDayInMonth < 0 Then
				WeekStartDay = DaysInMonth - (-Schedule.WeekDayInMonth) * 7 + 1;
			EndIf;
			
			WeekEndDay = Min(WeekStartDay + 6, DaysInMonth);
			
			If Day(DateToCheck) > WeekEndDay 
				Or WeekStartDay > DaysInMonth Then
				// This month does not include this week, or this week has already passed
				ChangeMonth = True;
				Continue;
			EndIf;
			
			If Day(DateToCheck) < WeekStartDay Then
				If Schedule.DayInMonth <> 0 Then
					
					// The day is fixed and inappropriate
					ChangeMonth = True;
					Continue;
				EndIf;
				DateToCheck = BegOfMonth(DateToCheck) + (WeekStartDay - 1) * 86400;
			EndIf;
		EndIf;
		
		// Day of the week
		While ChangeDay
			Or Schedule.WeekDays.Find(WeekDay(DateToCheck)) = Undefined
			And Schedule.WeekDays.Count() > 0 Do
			
			ChangeDay = False;
			
			If Schedule.DayInMonth <> 0 Then
				// The day is fixed and inappropriate
				ChangeMonth = True;
				Break;
			EndIf;
			
			If Day(DateToCheck) = DaysInMonth Then
				// The month is over
				ChangeMonth = True;
				Break;
			EndIf;
			
			If Schedule.WeekDayInMonth <> 0
				And Day(DateToCheck) = WeekEndDay Then
				
				// The week is over
				ChangeMonth = True;
				Break;
			EndIf;
			
			DateToCheck = BegOfDay(DateToCheck) + 86400;
		EndDo;
		If ChangeMonth Then
			Continue;
		EndIf;
		
		// Time management
		TimeToCheck = '00010101' + (DateToCheck - BegOfDay(DateToCheck));
		
		If Schedule.DetailedDailySchedules.Count() = 0 Then
			DetailedSchedules = New Array;
			DetailedSchedules.Add(Schedule);
		Else
			DetailedSchedules = Schedule.DetailedDailySchedules;
		EndIf;
		
		// If we have an interval including midnight, split it into two intervals
		Index = 0;
		While Index < DetailedSchedules.Count() Do
			
			DaySchedule = DetailedSchedules[Index];
			
			If Not ValueIsFilled(DaySchedule.BeginTime) Or Not ValueIsFilled(DaySchedule.EndTime) Then
				Index = Index + 1;
				Continue;
			EndIf;
			
			If DaySchedule.BeginTime > DaySchedule.EndTime Then
				
				DailyScheduleFirstHalf = New JobSchedule();
				FillPropertyValues(DailyScheduleFirstHalf,DaySchedule);
				DailyScheduleFirstHalf.BeginTime = BegOfDay(DailyScheduleFirstHalf.BeginTime);
				DetailedSchedules.Add(DailyScheduleFirstHalf);
				
				DailyScheduleSecondHalf = New JobSchedule();
				FillPropertyValues(DailyScheduleSecondHalf,DaySchedule);
				DailyScheduleSecondHalf.EndTime = EndOfDay(DailyScheduleSecondHalf.BeginTime);
				DetailedSchedules.Add(DailyScheduleSecondHalf);
				
				DetailedSchedules.Delete(Index);
				
			Else
				
				Index = Index + 1;
				
			EndIf;
		
		EndDo;
		
		For Index = 0 To DetailedSchedules.UBound() Do
			DaySchedule = DetailedSchedules[Index];
			
			// Boundary times
			If ValueIsFilled(DaySchedule.BeginTime)
				And TimeToCheck < DaySchedule.BeginTime Then
				
				TimeToCheck = DaySchedule.BeginTime;
			EndIf;
			
			If ValueIsFilled(DaySchedule.EndTime)
				And TimeToCheck > DaySchedule.EndTime Then
				
				If Index < DetailedSchedules.UBound() Then
					// More daily schedules available
					Continue;
				EndIf;
				
				// Appropriate time is over for this day
				ChangeDay = True;
				Break;
			EndIf;
			
			// Repetition periodicity during the day
			If ValueIsFilled(BeginDateOfLastStart) Then
				
				If DaySchedule.RepeatPeriodInDay = 0
					And BegOfDay(DateToCheck) = BegOfDay(BeginDateOfLastStart)
					And (Not ValueIsFilled(DaySchedule.BeginTime) 
						Or ValueIsFilled(DaySchedule.BeginTime) And BeginTimeOfLastStart >= DaySchedule.BeginTime)
					And (Not ValueIsFilled(DaySchedule.EndTime) 
						Or ValueIsFilled(DaySchedule.EndTime) And BeginTimeOfLastStart <= DaySchedule.EndTime) Then
					
					// Job already completed during this interval (daily schedule), repetition not set
					If Index < DetailedSchedules.UBound() Then
						Continue;
					EndIf;
					
					ChangeDay = True;
					Break;
				EndIf;
				
				If BegOfDay(DateToCheck) = BegOfDay(BeginDateOfLastStart)
					And TimeToCheck - BeginTimeOfLastStart < DaySchedule.RepeatPeriodInDay Then
					
					NewTimeToCheck = BeginTimeOfLastStart + DaySchedule.RepeatPeriodInDay;
					
					If ValueIsFilled(DaySchedule.EndTime) And NewTimeToCheck > DaySchedule.EndTime
						Or BegOfDay(NewTimeToCheck) <> BegOfDay(TimeToCheck) Then
						
						// The time is out of the allowed interval
						If Index < DetailedSchedules.UBound() Then
							Continue;
						EndIf;
						
						ChangeDay = True;
						Break;
					EndIf;
					
					TimeToCheck = NewTimeToCheck;
					
				EndIf;
				
			EndIf;
			
			// Pause
			If ValueIsFilled(EndDateOfLastStart) 
				And ValueIsFilled(DaySchedule.RepeatPause) Then
				
				EndTimeOfLastStart = '00010101' + (EndDateOfLastStart - BegOfDay(EndDateOfLastStart));
				
				If BegOfDay(DateToCheck) = BegOfDay(BeginDateOfLastStart)
					And TimeToCheck - EndTimeOfLastStart < DaySchedule.RepeatPause Then
					
					NewTimeToCheck = EndTimeOfLastStart + DaySchedule.RepeatPause;
					
					If ValueIsFilled(DaySchedule.EndTime) And NewTimeToCheck > DaySchedule.EndTime
						Or BegOfDay(NewTimeToCheck) <> BegOfDay(TimeToCheck) Then
						
						// The time is out of the allowed interval
						If Index < DetailedSchedules.UBound() Then
							Continue;
						EndIf;
						
						ChangeDay = True;
						Break;
					EndIf;
					
					TimeToCheck = NewTimeToCheck;
					
				EndIf;
			EndIf;
			
			// Appropriate time found
			Break;
			
		EndDo;
		
		If ChangeDay Then
			Continue;
		EndIf;
		
		If ValueIsFilled(Schedule.CompletionTime)
			And TimeToCheck > Schedule.CompletionTime Then
			// Too late for execution on this day
			ChangeDay = True;
			Continue;
		EndIf;
		
		DateToCheck = BegOfDay(DateToCheck) + (TimeToCheck - BegOfDay(TimeToCheck));
		
		Return DateToCheck;
		
	EndDo;
	
EndFunction

Procedure ScheduleJob(Val Selection)
	
	If ValueIsFilled(Selection.TimeZone) Then
		TimeZone = Selection.TimeZone;
	Else
		TimeZone = Undefined;
	EndIf;
	
	BeginTransaction();
	
	Try
		
		If Selection.DataArea <> -1 Then
			CommonUse.SetSessionSeparation(True, Selection.DataArea);
		EndIf;
		
		DataLock = New DataLock;
		LockItem = DataLock.Add(Selection.ID.Metadata().FullName());
		LockItem.SetValue("Ref", Selection.ID);
		DataLock.Lock();
		
		If Not CommonUse.RefExists(Selection.ID) Then
			DataLock.Lock();
			UnlockDataForEdit(Selection.ID);
			RollbackTransaction();
			Return;
		EndIf;
		
		Job = Selection.ID.GetObject();
		
		If CommonUseCached.IsSeparatedConfiguration() And CommonUseCached.IsSeparatedMetadataObject(Job.Metadata().FullName(), CommonUseCached.AuxiliaryDataSeparator()) Then
			
			If ValueIsFilled(Job.Template)
				And Selection.Template = Undefined Then
				
				MessagePattern = NStr("en = 'Queue creation template %1 not found'");
				MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, Job.Template);
				
				WriteLogEvent(NStr("en = 'Job queue.Scheduling'", 
					CommonUseClientServer.DefaultLanguageCode()), 
					EventLogLevel.Error,
					,
					,
					MessageText);
				
				CommonUse.SetSessionSeparation(False);
				UnlockDataForEdit(Selection.ID);
				RollbackTransaction();
				Return;
				
			EndIf;
			
		EndIf;
			
		If Job.JobState = Enums.JobStates.ExecutionError
			And Job.AttemptNumber < Selection.RestartCountOnFailure Then // Restart attempt
			
			If ValueIsFilled(Job.EndDateOfLastStart) Then
				RestartReferencePoint = Job.EndDateOfLastStart;
			Else
				RestartReferencePoint = Job.BeginDateOfLastStart;
			EndIf;
			
			Job.ScheduledStartTime  = RestartReferencePoint + Selection.RestartIntervalOnFailure;
			Job.AttemptNumber           = Job.AttemptNumber + 1;
			Job.JobState            = Enums.JobStates.Scheduled;
			Job.ActiveBackgroundJob = Undefined;
			Job.Write();
			
		ElsIf Job.JobState = Enums.JobStates.Executing Then // Job not completed, scheduling the error handler
			
			WriteExecutionControlEventLog(NStr("en = 'Scheduled job queue.Completed with errors'", 
				CommonUseClientServer.DefaultLanguageCode()), Selection.ID, 
				NStr("en = 'Active job was aborted'"));
				
			// Scheduling a one-time job for error handler execution
			HandlerParameters = GetErrorHandlerParameters(Job);
			If HandlerParameters.HandlerExists Then
				
				NewJob = Catalogs[Job.Metadata().Name].CreateItem();
				NewJob.ScheduledStartTime = CurrentUniversalDate();
				NewJob.Use = True;
				NewJob.JobState = Enums.JobStates.Scheduled;
				CallParameters = New Array;
				CallParameters.Add(Job.Ref);
				NewJob.Parameters = New ValueStorage(CallParameters);
				NewJob.MethodName = "JobQueueInternal.HandleError";
				If CommonUse.IsSeparatedMetadataObject(Job.Metadata(),"DataAreaAuxiliaryData") Then
					NewJob.DataAreaAuxiliaryData = Job.DataAreaAuxiliaryData;
				EndIf;
				CommonUse.WriteAuxiliaryData(NewJob);
				
				// Pausing the job until the error handler execution is complete
				Job.JobState = Enums.JobStates.ErrorHandlerOnFailure;
				Job.Write();
				
			EndIf;
			
		Else
			Schedule = Selection.Schedule.Get();
			If Schedule <> Undefined Then
				
				Job.ScheduledStartTime = GetScheduledJobStartTime(
					Schedule, TimeZone, Job.BeginDateOfLastStart, Job.EndDateOfLastStart);
				Job.AttemptNumber = 0;
				If ValueIsFilled(Job.ScheduledStartTime) Then
					Job.JobState = Enums.JobStates.Scheduled;
				Else
					Job.JobState = Enums.JobStates.NotActive;
				EndIf;
				Job.ActiveBackgroundJob = Undefined;
				Job.Write();
				
			Else // No schedule
				
				If CommonUseCached.IsSeparatedConfiguration() And CommonUseCached.IsSeparatedMetadataObject(
							Job.Metadata().FullName(),
							CommonUseCached.AuxiliaryDataSeparator()
						) Then
					If ValueIsFilled(Job.Template) Then // Job by template without schedule
						
						MessagePattern = NStr("en = 'No schedule found for queue job template %1'");
						MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, Job.Template);
						WriteLogEvent(NStr("en = 'Job queue.Scheduling'", 
							CommonUseClientServer.DefaultLanguageCode()), 
							EventLogLevel.Error,
							,
							,
							MessageText);
						
						CommonUse.SetSessionSeparation(False);
						RollbackTransaction();
						UnlockDataForEdit(Selection.ID);
						Return;
						
					EndIf;
				EndIf;
				
				// One-time job
				Job.DataExchange.Load = True;
				Job.Delete();
				
			EndIf;
		EndIf;
		
		CommonUse.SetSessionSeparation(False);
		CommitTransaction();
		UnlockDataForEdit(Selection.ID);
		
	Except
		
		CommonUse.SetSessionSeparation(False);
		RollbackTransaction();
		UnlockDataForEdit(Selection.ID);
		Raise;
		
	EndTry;
	
EndProcedure

Procedure ExecuteQueueJob(Val Ref, Val ActiveBackgroundJob, 
		Val Template, Val MethodName)
	
	DataArea = Undefined;
	If CommonUseCached.IsSeparatedConfiguration() Then
		JobQueueInternalDataSeparationModule = CommonUse.CommonModule("JobQueueInternalDataSeparation");
		RedefinedDataArea = JobQueueInternalDataSeparationModule.DefineDataAreaForJob(Ref);
		If RedefinedDataArea <> Undefined Then
			DataArea = RedefinedDataArea;
		EndIf;
	EndIf;
	
	If DataArea = Undefined Then
		DataArea = -1;
	EndIf;
	
	BeginTransaction();
	Try
		
		If DataArea <> -1 Then
			CommonUse.SetSessionSeparation(True, DataArea);
		EndIf;
		
		DataLock = New DataLock;
		LockItem = DataLock.Add(Ref.Metadata().FullName());
		LockItem.SetValue("Ref", Ref);
		DataLock.Lock();
		
		Job = Ref.GetObject();
		
		If Job.JobState = Enums.JobStates.Scheduled
			And Job.Use
			And Job.ScheduledStartTime <= CurrentUniversalDate() Then 
			
			Job.JobState = Enums.JobStates.Executing;
			Job.ActiveBackgroundJob = ActiveBackgroundJob.UUID;
			Job.BeginDateOfLastStart = CurrentUniversalDate();
			Job.EndDateOfLastStart = Undefined;
			Job.Write();
			
			CommitTransaction();
			
		Else
			
			CommonUse.SetSessionSeparation(False);
			CommitTransaction();
			Return;
			
		EndIf;
		
	Except
		
		CommonUse.SetSessionSeparation(False);
		RollbackTransaction();
		Raise;
		
	EndTry;
	
	// Executing job
	CompletedSuccessfully = False;
	JobFailureInfo = Undefined;
	Try
		WriteExecutionControlEventLog(NStr("en = 'Scheduled job queue.Start'", 
			CommonUseClientServer.DefaultLanguageCode()), Ref);
		
		If ValueIsFilled(Template) Then
			ExecuteConfigurationMethod(MethodName);
		Else
			ExecuteJobHandler(Template, MethodName, Job.Parameters.Get());
		EndIf;
		
		CompletedSuccessfully = True;
		
		WriteExecutionControlEventLog(NStr("en = 'Scheduled job queue.Completed successfully'", 
			CommonUseClientServer.DefaultLanguageCode()), Ref);
		
	Except
		
		WriteExecutionControlEventLog(NStr("en = 'Scheduled job queue.Completed with errors'", 
			CommonUseClientServer.DefaultLanguageCode()), Ref, 
			DetailErrorDescription(ErrorInfo()));
		
		WriteLogEvent(NStr("en = 'Scheduled job queue.Execution'", 
			CommonUseClientServer.DefaultLanguageCode()),
			EventLogLevel.Error, 
			,
			ActiveBackgroundJob, 
			DetailErrorDescription(ErrorInfo())); 
			
		JobFailureInfo = ErrorInfo();
		
	EndTry;
		
	If Not CompletedSuccessfully Then
		
		// Calling error handlers
		HandleError(Ref);
		
	EndIf;
	
	BeginTransaction();
	Try
		
		If CommonUse.RefExists(Ref) Then // otherwise, the job could be deleted in the handler
			
			DataLock = New DataLock;
			LockItem = DataLock.Add(Ref.Metadata().FullName());
			LockItem.SetValue("Ref", Ref);
			DataLock.Lock();
			
			Job = Ref.GetObject();
			Job.EndDateOfLastStart = CurrentUniversalDate();
			
			If CompletedSuccessfully Then
				Job.JobState = Enums.JobStates.Completed;
			Else
				Job.JobState = Enums.JobStates.ExecutionError;
			EndIf;
			Job.Write();
			
		EndIf;
		
		CommitTransaction();
		
	Except
		
		CommonUse.SetSessionSeparation(False);
		RollbackTransaction();
		Raise;
		
	EndTry;
	
	CommonUse.SetSessionSeparation(False);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Infobase update

// Adds update handlers that are required by the subsystem.
//
// Parameters:
//   Handlers - ValueTable - see the description of NewUpdateHandlerTable function in the InfobaseUpdate common module.
// 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version = "*";
	Handler.Procedure = "JobQueueInternal.SetScheduledJobUse";
	Handler.SharedData = True;
	Handler.Priority = 50;
	Handler.ExclusiveMode = False;
	
EndProcedure

// Disables scheduled jobs used in local mode only;
// enables scheduled jobs used in SaaS only.
//
Procedure SetScheduledJobUse() Export
	
	InvertUse = Not CommonUseCached.DataSeparationEnabled();
	
	ScheduledJobUsageTable = GetScheduledJobUsageTable();
		
	For Each Row In ScheduledJobUsageTable Do
		
		Filter = New Structure("Metadata", Metadata.ScheduledJobs[Row.ScheduledJob]);
		FoundScheduledJobs = ScheduledJobs.GetScheduledJobs(Filter);
		
		For Each ScheduledJob In FoundScheduledJobs Do
			If InvertUse Then
				RequiredUse = Not Row.Use;
			Else
				RequiredUse = Row.Use;
			EndIf;
			
			If ScheduledJob.Use <> RequiredUse Then
				ScheduledJob.Use = RequiredUse;
				ScheduledJob.Write();
			EndIf;
		EndDo;
		
	EndDo;
	
EndProcedure

#EndRegion