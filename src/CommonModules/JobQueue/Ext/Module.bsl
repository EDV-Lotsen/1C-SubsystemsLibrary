////////////////////////////////////////////////////////////////////////////////
// JobQueue: Job queue management
//
////////////////////////////////////////////////////////////////////////////////

#Region Interface

////////////////////////////////////////////////////////////////////////////////
// Main procedures and functions.

// All methods accessible via API work with job parameters. Accessibility of
// any given parameter depends on the selected method and, in some cases, 
// on the values of other parameters. For more information, see method descriptions.
//
// Parameter description:
//   DataArea - Number - job data area separator value. 
//    -1 for unseparated jobs. If session separation is enabled,
//    session value will be used.
//   ID - CatalogRef.JobQueue, CatalogRef.DataAreaJobQueue - job ID.
//   Use - Boolean - job usage flag.
//   ScheduledStartTime - Date (DateTime) - scheduled job launch date
//    (as adjusted for the data area time zone).
//   JobState - EnumRef.JobStates - queue job state
//   ExclusiveExecution - Boolean - If this flag is set, the job will be executed 
//    even if session launch is prohibited in the data area. If any jobs with
//    this flag are available in a data area, they will be executed first.
//   Template - CatalogRef.QueueJobTemplates - job template, used
//    for separated queue jobs only.
//   MethodName - String - Job handler method name (or alias). Not applicable 
//    to jobs created from templates.
//    Only methods with aliases registered via the
//    StandardSubsystems.SaaSOperations.JobQueue\OnDefineHandlerAliases
//    event can be used here
//  Parameters - Array - Parameters to be passed to job handler.
//  Key - String - job key. Duplicate jobs with identical keys and method
//   names are not allowed within the same data area.
//  RestartIntervalOnFailure - Number - Time interval (sec) between job failure
//   and job restart. Measured from the moment of failed job completion. 
//   Used only in combination with RestartCountOnFailure.
//  Schedule - JobSchedule - Job execution schedule. If not specified, the job 
//   will be executed once only.
//  RestartCountOnFailure - Number - Number of repeated job execution attempts 
//   in case of failure.

// Receives queue jobs by specified filter.
// Inconsistent data can be received.
// Parameters:
//  Filter - Structure, Array - job filtering values. 
//  Allowed structure keys:
//   DataArea 
//   MethodName
//   ID
//   JobState
//   Key
//   Template
//   Use
//  Structure array can also be passed, containing filter descriptions with these keys:
//   ComparisonType - ComparisonType - the only allowed values are
//    ComparisonType.Equal,
//    ComparisonType.NotEqual,
//    ComparisonType.InList,
//    ComparisonType.NotInList
//  Value - Filter value. For InList and NotInList comparison types, value array is used.
//    For Equal and NotEqual comparison types, single values are used.
//  All filter conditions are combined by comjunction (logical AND).
// Returned value:
//  ValueTable - found jobs table. Each column corresponds to a job parameter.
//
Function GetJobs(Val Filter) Export
	
	CheckJobParameters(Filter, "Filter");
	
	// Generating a table with filter conditions
	ConditionTable = New ValueTable;
	ConditionTable.Columns.Add("Field", New TypeDescription("String", , New StringQualifiers(0, AllowedLength.Variable)));
	ConditionTable.Columns.Add("ComparisonType", New TypeDescription("ComparisonType"));
	ConditionTable.Columns.Add("Parameter", New TypeDescription("String", , New StringQualifiers(0, AllowedLength.Variable)));
	ConditionTable.Columns.Add("Value");
	
	ParameterDescriptions = JobQueueInternalCached.QueueJobParameters();
	
	GetSeparated = True;
	GetUnseparated = True;
	
	For Each KeyAndValue In Filter Do
		
		ParameterDescription = ParameterDescriptions.Find(Upper(KeyAndValue.Key), "NameUpper");
		
		If ParameterDescription.DataSeparation Then
			SeparationControl = True;
		Else
			SeparationControl = False;
		EndIf;
		
		If TypeOf(KeyAndValue.Value) = Type("Array") Then
			For Index = 0 To KeyAndValue.Value.UBound() Do
				FilterDetails = KeyAndValue.Value[Index];
				
				Where = ConditionTable.Add();
				Where.Field = ParameterDescription.Field;
				Where.ComparisonType = FilterDetails.ComparisonType;
				Where.Parameter = ParameterDescription.Name + IndexFormat(Index);
				Where.Value = FilterDetails.Value;
				
				If SeparationControl Then
					DefineFilterByCatalogSeparation(
						FilterDetails.Value,
						ParameterDescription,
						GetSeparated,
						GetUnseparated);
				EndIf;
				
			EndDo;
		Else
			
			Where = ConditionTable.Add();
			Where.Field = ParameterDescription.Field;
			Where.ComparisonType = ComparisonType.Equal;
			Where.Parameter = ParameterDescription.Name;
			Where.Value = KeyAndValue.Value;
			
			If SeparationControl Then
				DefineFilterByCatalogSeparation(
					KeyAndValue.Value,
					ParameterDescription,
					GetSeparated,
					GetUnseparated);
			EndIf;
			
		EndIf;
		
	EndDo;
	
	// Preparing query
	Query = New Query;
	
	DataAreaJobSeparator = CommonUseCached.AuxiliaryDataSeparator();
	
	JobCatalogs = JobQueueInternalCached.GetJobCatalogs();
	QueryText = "";
	For Each JobCatalog In JobCatalogs Do
		
		Cancel = False;
		CatalogName = JobCatalog.CreateItem().Metadata().FullName();
		
		If Not GetSeparated Then
			
			If CommonUseCached.IsSeparatedConfiguration() And CommonUseCached.IsSeparatedMetadataObject(CatalogName, DataAreaJobSeparator) Then
				Continue;
			EndIf;
			
		EndIf;
		
		If Not GetUnseparated Then
			
			If Not CommonUseCached.IsSeparatedConfiguration() Or Not CommonUseCached.IsSeparatedMetadataObject(CatalogName, DataAreaJobSeparator) Then
				Continue;
			EndIf;
			
		EndIf;
		
		If Not IsBlankString(QueryText) Then
			
			QueryText = QueryText + "
			|
			|UNION ALL
			|"
			
		EndIf;
		
		SelectionFields = JobQueueInternalCached.JobQueueSelectionFields(CatalogName);
		
		ConditionString = "";
		If ConditionTable.Count() > 0 Then
			
			ComparisonTypes = JobQueueInternalCached.JobFilterComparisonTypes();
			
			For Each Where In ConditionTable Do
				
				If Where.Field = DataAreaJobSeparator Then
					If Not CommonUseCached.IsSeparatedConfiguration() Or Not CommonUseCached.IsSeparatedMetadataObject(CatalogName, DataAreaJobSeparator) Then
						Cancel = True;
						Continue;
					EndIf;
				EndIf;
				
				If Not IsBlankString(ConditionString) Then
					ConditionString = ConditionString + Chars.LF + Chars.Tab + "And ";
				EndIf;
				
				ConditionString = ConditionString + "Queue." + Where.Field + " " + 
					ComparisonTypes.Get(Where.ComparisonType) + " (&" + Where.Parameter + ")";
				
				Query.SetParameter(Where.Parameter, Where.Value);
			EndDo;
			
		EndIf;
		
		If Cancel Then
			Continue;
		EndIf;
		
		If CommonUseCached.IsSeparatedConfiguration() And CommonUseCached.IsSeparatedMetadataObject(CatalogName, CommonUseCached.AuxiliaryDataSeparator()) Then
			
			QueryText = QueryText + StringFunctionsClientServer.SubstituteParametersInString(
				"SELECT
				|" + SelectionFields + ",
				|	ISNULL(TimeZones.Value, """") AS TimeZone
				|FROM
				|	%1 AS Queue LEFT JOIN Constant.DataAreaTimeZone AS TimeZones
				|		ON Queue.DataAreaAuxiliaryData = TimeZones.DataAreaAuxiliaryData",
				JobCatalog.EmptyRef().Metadata().FullName());
			
		Else
			
			QueryText = QueryText + StringFunctionsClientServer.SubstituteParametersInString(
				"SELECT
				|" + SelectionFields + ",
				|	"""" AS TimeZone
				|FROM
				|	%1 AS Queue",
				JobCatalog.EmptyRef().Metadata().FullName());
			
		EndIf;
		
		If Not IsBlankString(ConditionString) Then
			
			QueryText = QueryText + "
			|WHERE
			|	" + ConditionString;
			
		EndIf;
		
	EndDo;
	
	If IsBlankString(QueryText) Then
		Raise NStr("en = 'Invalid filter value - found no catalogs with jobs meeting the filter conditions!'");
	EndIf;
	
	Query.Text = QueryText;
	
	// Getting data
	If TransactionActive() Then
		Result = Query.Execute().Unload();
	Else
		Result = CommonUse.ExecuteQueryOutsideTransaction(Query).Unload();
	EndIf;
	
	// Processing results
	Result.Columns.Schedule.Name = "ScheduleStorage";
	Result.Columns.Parameters.Name = "ParametersStorage";
	Result.Columns.Add("Schedule", New TypeDescription("JobSchedule, Undefined"));
	Result.Columns.Add("Parameters", New TypeDescription("Array"));
	
	For Each JobRow In Result Do
		JobRow.Schedule = JobRow.ScheduleStorage.Get();
		JobRow.Parameters = JobRow.ParametersStorage.Get();
		
		AreaTimeZone = JobRow.TimeZone;
		If Not ValueIsFilled(AreaTimeZone) Then
			AreaTimeZone = Undefined;
		EndIf;
		
		JobRow.ScheduledStartTime = 
			ToLocalTime(JobRow.ScheduledStartTime, AreaTimeZone);
	EndDo;
	
	Result.Columns.Delete("ScheduleStorage");
	Result.Columns.Delete("ParametersStorage");
	Result.Columns.Delete("TimeZone");
	
	Return Result;
	
EndFunction

// Adds a new job to the queue.
// If called from within a transaction, object lock is set for the job.
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
//
// Returns: 
//  CatalogRef.JobQueue, CatalogRef.DataAreaJobQueue - Added job ID
// 
Function AddJob(JobParameters) Export
	
	CheckJobParameters(JobParameters, "Insert");
	
	// Checking method name
	If Not JobParameters.Property("MethodName") Then
		Raise(NStr("en = 'Mandatory parameter not set for job MethodName'"));
	EndIf;
	
	CheckJobHandlerRegistration(JobParameters.MethodName);
	
	// Checking key for uniqueness
	If JobParameters.Property("Key") And ValueIsFilled(JobParameters.Key) Then
		Filter = New Structure;
		Filter.Insert("MethodName", JobParameters.MethodName);
		Filter.Insert("Key", JobParameters.Key);
		Filter.Insert("DataArea", JobParameters.DataArea);
		Filter.Insert("JobState", New Array);
		
		// Ignore completed jobs
		FilterDetails = New Structure;
		FilterDetails.Insert("ComparisonType", ComparisonType.NotEqual);
		FilterDetails.Insert("Value", Enums.JobStates.Completed);
		
		Filter.JobState.Add(FilterDetails);
		
		If GetJobs(Filter).Count() > 0 Then
			Raise GetJobsWithSameKeyDuplicationErrorMessage();
		EndIf;
	EndIf;
	
	// Default preferences
	If Not JobParameters.Property("Use") Then
		JobParameters.Insert("Use", True);
	EndIf;
	
	ScheduledStartTime = Undefined;
	If JobParameters.Property("ScheduledStartTime", ScheduledStartTime) Then
		
		StandardProcessing = True;
		If CommonUseCached.IsSeparatedConfiguration() Then
			
			JobQueueInternalDataSeparationModule = CommonUse.CommonModule("JobQueueInternalDataSeparation");
			JobQueueInternalDataSeparationModule.OnDefineScheduledStartTime(
				JobParameters,
				ScheduledStartTime,
				StandardProcessing);
			
		EndIf;
		
		If StandardProcessing Then
			ScheduledStartTime = ToUniversalTime(ScheduledStartTime);
		EndIf;
		
		JobParameters.Insert("ScheduledStartTime", ScheduledStartTime);
		
		StartTimeSet = True;
		
	Else
		
		JobParameters.Insert("ScheduledStartTime", CurrentUniversalDate());
		StartTimeSet = False;
		
	EndIf;
	
	// Types stored in value storage
	If JobParameters.Property("Parameters") Then
		JobParameters.Insert("Parameters", New ValueStorage(JobParameters.Parameters));
	Else
		JobParameters.Insert("Parameters", New ValueStorage(New Array));
	EndIf;
	
	If JobParameters.Property("Schedule") 
		And JobParameters.Schedule <> Undefined Then
		
		JobParameters.Insert("Schedule", New ValueStorage(JobParameters.Schedule));
	Else
		JobParameters.Insert("Schedule", Undefined);
	EndIf;
	
	// Generating job record
	
	CatalogForJob = Catalogs.JobQueue;
	StandardProcessing = True;
	
	If CommonUseCached.IsSeparatedConfiguration() Then
		JobQueueInternalDataSeparationModule = CommonUse.CommonModule("JobQueueInternalDataSeparation");
		OverriddenCatalog = JobQueueInternalDataSeparationModule.OnSelectCatalogForJob(JobParameters);
		If OverriddenCatalog <> Undefined Then
			CatalogForJob = OverriddenCatalog;
		EndIf;
	EndIf;
	
	Job = CatalogForJob.CreateItem();
	For Each ParameterDescription In JobQueueInternalCached.QueueJobParameters() Do
		If JobParameters.Property(ParameterDescription.Name) Then
			If ParameterDescription.DataSeparation Then
				If Not CommonUseCached.IsSeparatedConfiguration() Or Not CommonUse.IsSeparatedMetadataObject(Job.Metadata(), CommonUseCached.AuxiliaryDataSeparator()) Then
					Continue;
				EndIf;
			EndIf;
			Job[ParameterDescription.Field] = JobParameters[ParameterDescription.Name];
		EndIf;
	EndDo;
	
	If Job.Use
		And (StartTimeSet Or JobParameters.Schedule = Undefined) Then
			
		Job.JobState = Enums.JobStates.Scheduled;
	Else
		Job.JobState = Enums.JobStates.NotScheduled;
	EndIf;
	
	JobRef = CatalogForJob.GetRef();
	Job.SetNewObjectRef(JobRef);
	
	If TransactionActive() Then
		
		LockDataForEdit(JobRef);
		// Lock will be automatically removed once the transaction is completed
	EndIf;
	
	CommonUse.WriteAuxiliaryData(Job);
	
	Return Job.Ref;
	
EndFunction

// Changes a job with the specified ID
// If called from within a transaction, object lock is set for the job.
//   
// Parameters: 
//  ID - CatalogRef.JobQueue, CatalogRef.DataAreaJobQueue - Job ID
//  JobParameters - Structure - Job parameters, allowed keys:
//   Use
//   ScheduledStartTime
//   ExclusiveExecution
//   MethodName
//   Parameters
//   Key
//   RestartIntervalOnFailure
//   Schedule
//   RestartCountOnFailure
//   
//   If the job is based on a template, only the following keys are allowed:
//    Use.
// 
Procedure ChangeJob(ID, JobParameters) Export
	
	CheckJobParameters(JobParameters, "Update");
	
	Job = JobDescriptionByID(ID);
	
	// Checking for attempts to change a job in another area
	If CommonUseCached.DataSeparationEnabled()
		And CommonUseCached.CanUseSeparatedData()
		And Job.DataArea <> CommonUse.SessionSeparatorValue() Then
		
		Raise(GetExceptionTextToReceiveDataFromOtherAreas());
	EndIf;
	
	// Checking for attempts to change parameters for a template-based job
	If CommonUseCached.IsSeparatedConfiguration() And CommonUseCached.IsSeparatedMetadataObject(
				ID.Metadata().FullName(),
				CommonUseCached.AuxiliaryDataSeparator()
			) Then
		If ValueIsFilled(Job.Template) Then
			ParameterDescriptions = JobQueueInternalCached.QueueJobParameters();
			For Each KeyAndValue In JobParameters Do
				ParameterDescription = ParameterDescriptions.Find(Upper(KeyAndValue.Key), "NameUpper");
				If Not ParameterDescription.Template Then
					MessagePattern = NStr("en = 'Queue job with ID %1 is template-based.
						|Changing parameter %2 for template-based jobs is prohibited.'");
					MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, 
						ID, ParameterDescription.Name);
					Raise(MessageText);
				EndIf;
			EndDo;
		EndIf;
	EndIf;
	
	// Checking key for uniqueness
	If JobParameters.Property("Key") And ValueIsFilled(JobParameters.Key) Then
		Filter = New Structure;
		Filter.Insert("MethodName", JobParameters.MethodName);
		Filter.Insert("Key", JobParameters.Key);
		Filter.Insert("DataArea", Job.DataArea);
		Filter.Insert("ID", New Array);
		
		// Ignore the changed job
		FilterDetails = New Structure;
		FilterDetails.Insert("ComparisonType", ComparisonType.NotEqual);
		FilterDetails.Insert("Value", ID);
		
		Filter.ID.Add(FilterDetails);
		
		If GetJobs(Filter).Count() > 0 Then
			Raise GetJobsWithSameKeyDuplicationErrorMessage();
		EndIf;
	EndIf;
	
	ScheduledStartTime = Undefined;
	If JobParameters.Property("ScheduledStartTime", ScheduledStartTime)
			And ValueIsFilled(JobParameters.ScheduledStartTime) Then
		
		StandardProcessing = True;
		If CommonUseCached.IsSeparatedConfiguration() Then
			
			JobQueueInternalDataSeparationModule = CommonUse.CommonModule("JobQueueInternalDataSeparation");
			JobQueueInternalDataSeparationModule.OnDefineScheduledStartTime(
				JobParameters,
				ScheduledStartTime,
				StandardProcessing);
			
		EndIf;
		
		If StandardProcessing Then
			ScheduledStartTime = ToUniversalTime(ScheduledStartTime);
		EndIf;
		
		JobParameters.Insert("ScheduledStartTime", ScheduledStartTime);
		
		StartTimeSet = True;
	Else
		StartTimeSet = False;
	EndIf;
	
	// Types stored in value storage
	If JobParameters.Property("Parameters") Then
		JobParameters.Insert("Parameters", New ValueStorage(JobParameters.Parameters));
	EndIf;
	
	If JobParameters.Property("Schedule")
		And JobParameters.Schedule <> Undefined Then
		
		JobParameters.Insert("Schedule", New ValueStorage(JobParameters.Schedule));
	EndIf;
	
	// Rescheduling a scheduled job
	If Not JobParameters.Property("ScheduledStartTime", ScheduledStartTime)
		And JobParameters.Property("Schedule") Then
		
		JobParameters.Insert("ScheduledStartTime", ScheduledStartTime);
	EndIf;
	
	// Locking a job record
	LockDataForEdit(ID);
	
	BeginTransaction();
	Try
		DataLock = New DataLock;
		LockItem = DataLock.Add(ID.Metadata().FullName());
		LockItem.SetValue("Ref", ID);
		DataLock.Lock();
		
		// Generating job record
		
		If Not CommonUse.RefExists(ID) Then
			MessagePattern = NStr("en = 'Job with ID %1 not found. Data area: %2'");
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, ID, Job.DataArea);
			Raise(MessageText);
		EndIf;
		
		Job = ID.GetObject();
		
		For Each ParameterDescription In JobQueueInternalCached.QueueJobParameters() Do
			If JobParameters.Property(ParameterDescription.Name) Then
				Job[ParameterDescription.Field] = JobParameters[ParameterDescription.Name];
			EndIf;
		EndDo;
		
		If Job.Use
			And (StartTimeSet 
			Or Not JobParameters.Property("Schedule")
			Or JobParameters.Schedule = Undefined) Then
				
			Job.JobState = Enums.JobStates.Scheduled;
		Else
			Job.JobState = Enums.JobStates.NotScheduled;
		EndIf;
		
		CommonUse.WriteAuxiliaryData(Job);
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		Raise;
		
	EndTry;
	
	If Not TransactionActive() Then // Otherwise, the lock will be removed once the transaction is completed
		UnlockDataForEdit(ID);
	EndIf;
	
EndProcedure

// Removes a job from the job queue.
// Removing template-based jobs is prohibited.
// If called from within a transaction, object lock is set for the job.
// 
// Parameters: 
//  ID - CatalogRef.JobQueue, CatalogRef.DataAreaJobQueue, - Job ID
// 
Procedure DeleteJob(ID) Export
	
	Job = ID.GetObject();
	
	If CommonUseCached.IsSeparatedConfiguration() And CommonUseCached.IsSeparatedMetadataObject(
				Job.Metadata().FullName(),
				CommonUseCached.AuxiliaryDataSeparator()
			) Then
		If ValueIsFilled(Job.Template) Then
			MessagePattern = NStr("en = 'Queue job with ID %1 is template-based.
				|Removing the template-based jobs is prohibited.'");
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, ID);
			Raise(MessageText);
		EndIf;
	EndIf;
	
	LockDataForEdit(ID);
	
	Job.DataExchange.Load = True;
	CommonUse.DeleteAuxiliaryData(Job);
	
	If Not TransactionActive() Then // Otherwise, the lock will be removed once the transaction is completed
		UnlockDataForEdit(ID);
	EndIf;
	
EndProcedure

// Returns a queue job template corresponding to the name 
// of a predefined scheduled job used to create the template.
//
// Parameters:
//  Name - String - name of the predefined scheduled job
//
// Returns:
//  CatalogRef.QueueJobTemplates - job template
//
Function TemplateByName(Val Name) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	QueueJobTemplates.Ref AS Ref
	|FROM
	|	Catalog.QueueJobTemplates AS QueueJobTemplates
	|WHERE
	|	QueueJobTemplates.Name = &Name";
	Query.SetParameter("Name", Name);
	
	Result = Query.Execute();
	If Result.IsEmpty() Then
		MessagePattern = NStr("en = 'Job template %1 not found'");
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, Name);
		Raise(MessageText);
	EndIf;
	
	Selection = Result.Select();
	Selection.Next();
	
	Return Selection.Ref;
	
EndFunction

#EndRegion

#Region InternalProceduresAndFunctions

// Checks the passed parameter structure for
// compliance with subsystem requirements:
//  - key list
//  - parameter types
//
// Parameters:
//  Parameters - Structure - job parameters
//  Mode - String - mode used for parameter check 
//   Allowed values:
//    Filter - checking parameters for filtering 
//    Add - checking parameters for adding
//    Change - checking parameters for changing
// 
Procedure CheckJobParameters(Parameters, Mode)
	
	If TypeOf(Parameters) <> Type("Structure") Then
		MessagePattern = NStr("en = 'Invalid job parameter set type passed - %1'");
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, TypeOf(Parameters));
		Raise(MessageText);
	EndIf;
	
	Filter = Mode = "Filter";
	
	ParameterDescriptions = JobQueueInternalCached.QueueJobParameters();
	
	ComparisonTypes = JobQueueInternalCached.JobFilterComparisonTypes();
	
	FilterDescriptionKeys = New Array;
	FilterDescriptionKeys.Add("ComparisonType");
	FilterDescriptionKeys.Add("Value");
	
	For Each KeyAndValue In Parameters Do
		ParameterDescription = ParameterDescriptions.Find(Upper(KeyAndValue.Key), "NameUpper");
		If ParameterDescription = Undefined 
			Or Not ParameterDescription[Mode] Then
			
			MessagePattern = NStr("en = 'Invalid job parameter passed - %1'");
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, 
				KeyAndValue.Key);
			Raise(MessageText);
		EndIf;
		
		If Filter And TypeOf(KeyAndValue.Value) = Type("Array") Then
			// Filter description array
			For Each FilterDetails In KeyAndValue.Value Do
				If TypeOf(FilterDetails) <> Type("Structure") Then
					MessagePattern = NStr("en = 'Invalid type %1 passed in filter description collection %2'");
					MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, 
						TypeOf(FilterDetails), KeyAndValue.Key);
					Raise(MessageText);
				EndIf;
				
				// Checking keys
				For Each KeyName In FilterDescriptionKeys Do
					If Not FilterDetails.Property(KeyName) Then
						MessagePattern = NStr("en = 'Invalid filter description %1 passed in filter description collection %2.
							|Missing property %2.'");
						MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, 
							KeyAndValue.Key, KeyName);
						Raise(MessageText);
					EndIf;
				EndDo;
				
				// Checking comparison type
				If ComparisonTypes.Get(FilterDetails.ComparisonType) = Undefined Then
					MessagePattern = NStr("en = 'Invalid comparison type passed in filter description in filter description collection %1'");
					MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, 
						KeyAndValue.Key);
					Raise(MessageText);
				EndIf;
				
				// Value check
				If FilterDetails.ComparisonType = ComparisonType.InList
					Or FilterDetails.ComparisonType = ComparisonType.NotInList Then
					
					If TypeOf(FilterDetails.Value) <> Type("Array") Then
						MessagePattern = NStr("en = 'Invalid type %1 passed in filter description in filter description collection %2.
							|Array type expected for comparison type %3.'");
						MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, 
							TypeOf(FilterDetails.Value), KeyAndValue.Key, FilterDetails.ComparisonType);
						Raise(MessageText);
					EndIf;
					
					For Each SelectValue In FilterDetails.Value Do
						CheckValueForComplianceWithParameterDescription(SelectValue, ParameterDescription);
					EndDo;
				Else
					CheckValueForComplianceWithParameterDescription(FilterDetails.Value, ParameterDescription);
				EndIf;
			EndDo;
		Else
			CheckValueForComplianceWithParameterDescription(KeyAndValue.Value, ParameterDescription);
		EndIf;
	EndDo;
	
	// Data area
	If CommonUseCached.DataSeparationEnabled()
		And CommonUseCached.CanUseSeparatedData() Then
		
		If Parameters.Property("DataArea") Then
			If Parameters.DataArea <> CommonUse.SessionSeparatorValue() Then
				Raise(NStr("en = 'In this session, accessing data from other data areas is prohibited!'"));
			EndIf;
		Else
			ParameterDescription = ParameterDescriptions.Find(Upper("DataArea"), "NameUpper");
			If ParameterDescription[Mode] Then
				Parameters.Insert("DataArea", CommonUse.SessionSeparatorValue());
			EndIf;
		EndIf;
		
	EndIf;
	
	// ScheduledStartTime
	If Parameters.Property("ScheduledStartTime")
		And Not ValueIsFilled(Parameters.ScheduledStartTime) Then
		
		MessagePattern = NStr("en = 'Invalid value %1 of job parameter %2 passed'");
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, 
			Parameters.ScheduledStartTime, 
			ParameterDescriptions.Find(Upper("ScheduledStartTime"), "NameUpper").Name);
		Raise(MessageText);
	EndIf;
	
EndProcedure

Procedure CheckValueForComplianceWithParameterDescription(Val Value, Val ParameterDescription)
	
	If Not ParameterDescription.Type.ContainsType(TypeOf(Value)) Then
		MessagePattern = NStr("en = 'Invalid type %1 of job parameter %2 passed'");
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, 
			TypeOf(Value), ParameterDescription.Name);
		Raise(MessageText);
	EndIf;
	
EndProcedure

Function IndexFormat(Val Index)
	
	Return Format(Index, "NZ=0;NG=")
	
EndFunction

Procedure CheckJobHandlerRegistration(Val MethodName)
	
	If JobQueueInternalCached.MapBetweenMethodNamesAndAliases().Get(Upper(MethodName)) = Undefined Then
		MessagePattern = NStr("en = 'Alias not registered for method %1 to be used as queue job handler.'");
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, MethodName);
		Raise(MessageText);
	EndIf;
	
EndProcedure

Function JobDescriptionByID(Val ID)
	
	If Not ValueIsFilled(ID) Or Not CommonUse.RefExists(ID) Then
		MessagePattern = NStr("en = 'Invalid value %1 of job parameter ID passed'");
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, ID);
		Raise(MessageText);
	EndIf;
	
	Jobs = GetJobs(New Structure("ID", ID));
	If Jobs.Count() = 0 Then
		MessagePattern = NStr("en = 'Queue job with ID %1 not found'");
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, ID);
		Raise(MessageText);
	EndIf;
	
	Return Jobs[0];
	
EndFunction

// Returns error text related to an attempt to execute two jobs with identical keys simultaneously.
//
// Returns:
// String.
//
Function GetJobsWithSameKeyDuplicationErrorMessage() Export
	
	Return NStr("en = 'Duplicate jobs with identical values of field ''Key'' not allowed.'");
	
EndFunction

// Returns error text related to an attempt to get job list
// for another data area while in a session with separator values set.
//
// Returns:
// String.
//
Function GetExceptionTextToReceiveDataFromOtherAreas()
	
	Return NStr("en = 'In this session, accessing data from other data areas is prohibited!'");
	
EndFunction

Procedure DefineFilterByCatalogSeparation(Val Value, Val ParameterDescription, GetSeparated, GetUnseparated)
	
	ValueType = TypeOf(Value);
	ValueTypeArray = New Array();
	ValueTypeArray.Add(ValueType);
	TypeDescription = New TypeDescription(ValueTypeArray);
	DefaultValue = TypeDescription.AdjustValue(
		ParameterDescription.ValueForUnseparatedJobs);
	If Value = DefaultValue Then
		
		GetSeparated = False;
		
	Else
		
		GetUnseparated = False;
		
	EndIf;
	
EndProcedure

#EndRegion
