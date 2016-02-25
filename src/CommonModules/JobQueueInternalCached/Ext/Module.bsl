///////////////////////////////////////////////////////////////////////////////////
// JobQueueInternalCached: Job queue management.
//
///////////////////////////////////////////////////////////////////////////////////

#Region InternalProceduresAndFunctions

// Returns mapping between methods and method aliases
// (uppercase) that can be called from the job queue
//
// Returns:
//  FixedMap
//   Key - Method alias
//   Value - Name of the called method
//
Function MapBetweenMethodNamesAndAliases() Export
	
	Result = New Map;
	
	// For obsolete version compatibility
	AllowedMethods = New Array;
	JobQueueOverridable.GetJobQueueAllowedMethods(AllowedMethods);
	For Each MethodName In AllowedMethods Do
		Result.Insert(Upper(MethodName), MethodName);
	EndDo;
	
	ApplicationMethods = New Map;
	EventHandlers = CommonUse.InternalEventHandlers(
		"StandardSubsystems.SaaSOperations.JobQueue\OnDefineHandlerAliases");
	
	For Each Handler In EventHandlers Do
		Handler.Module.OnDefineHandlerAliases(ApplicationMethods);
	EndDo;
	
	// Determining internal procedure methods used for job error handling
	ApplicationMethods.Insert("JobQueueInternal.HandleError");
	ApplicationMethods.Insert("JobQueueInternal.CancelErrorHandlerJobs");
	
	JobQueueOverridable.OnDefineHandlerAliases(ApplicationMethods);
	
	For Each KeyAndValue In ApplicationMethods Do
		Result.Insert(Upper(KeyAndValue.Key),
			?(IsBlankString(KeyAndValue.Value), KeyAndValue.Key, KeyAndValue.Value));
	EndDo;
	
	Return New FixedMap(Result);
	
EndFunction

// Returns mapping between error handlers and aliases of methods
// called for these error handlers (uppercase)
//
// Returns:
//  FixedMap
//   Key - Method alias
//   Value - Full name of handler method
//
Function MapBetweenErrorHandlersAndAliases() Export
	
	ErrorHandlers = New Map;
	
	// Filling the embedded error handlers
	ErrorHandlers.Insert("JobQueueInternal.HandleError","JobQueueInternal.CancelErrorHandlerJobs");
	ErrorHandlers.Insert("JobQueueInternal.CancelErrorHandlerJobs","JobQueueInternal.CancelErrorHandlerJobs");
	
	EventHandlers = CommonUse.InternalEventHandlers(
		"StandardSubsystems.SaaSOperations.JobQueue\OnDefineErrorHandlers");
	
	For Each Handler In EventHandlers Do
		Handler.Module.OnDefineErrorHandlers(ErrorHandlers);
	EndDo;
	
	JobQueueOverridable.OnDefineErrorHandlers(ErrorHandlers);
	
	Result = New Map;
	For Each KeyAndValue In ErrorHandlers Do
		Result.Insert(Upper(KeyAndValue.Key), KeyAndValue.Value);
	EndDo;
	
	Return New FixedMap(Result);
	
EndFunction

// Returns description of queue job parameters
//
// Returns:
//  ValueTable - parameter descriptions, columns
//   Name - String - parameter name
//   NameUpper - String - parameter name in uppercase
//   Field - String - name of field used to store the parameter in queue table 
//   Type - TypeDescription - allowed parameter value types
//   Filter - Boolean - this parameter can be used as filter 
//   Adding - Boolean - this parameter can be used when adding a job to queue
//   Editing - Boolean - this parameter can be edited
//   Template - Boolean - this parameter can be edited for jobs
//    created by template 
//   DataSeparation - Boolean - this parameter is only used for
//    separated job management 
//   ValueForUnseparatedJobs - String - this value must be returned from API 
//    for separated parameters of unseparated jobs (as a string that can be 
//    substituted into queries).
//
Function QueueJobParameters() Export
	
	Result = New ValueTable;
	Result.Columns.Add("Name", New TypeDescription("String", , New StringQualifiers(0, AllowedLength.Variable)));
	Result.Columns.Add("NameUpper", New TypeDescription("String", , New StringQualifiers(0, AllowedLength.Variable)));
	Result.Columns.Add("Field", New TypeDescription("String", , New StringQualifiers(0, AllowedLength.Variable)));
	Result.Columns.Add("Type", New TypeDescription("TypeDescription"));
	Result.Columns.Add("Filter", New TypeDescription("Boolean"));
	Result.Columns.Add("Insert", New TypeDescription("Boolean"));
	Result.Columns.Add("Update", New TypeDescription("Boolean"));
	Result.Columns.Add("Template", New TypeDescription("Boolean"));
	Result.Columns.Add("DataSeparation", New TypeDescription("Boolean"));
	Result.Columns.Add("ValueForUnseparatedJobs", New TypeDescription("String"));
	
	ParameterDescription = Result.Add();
	ParameterDescription.Name = "DataArea";
	ParameterDescription.Field = "DataAreaAuxiliaryData";
	ParameterDescription.Type = New TypeDescription("Number");
	ParameterDescription.Filter = True;
	ParameterDescription.Insert = True;
	ParameterDescription.DataSeparation = True;
	ParameterDescription.ValueForUnseparatedJobs = "-1";
	
	ParameterDescription = Result.Add();
	ParameterDescription.Name = "ID";
	ParameterDescription.Field = "Ref";
	TypeArray = New Array();
	JobCatalogs = JobQueueInternalCached.GetJobCatalogs();
	For Each JobCatalog In JobCatalogs Do
		TypeArray.Add(TypeOf(JobCatalog.EmptyRef()));
	EndDo;
	ParameterDescription.Type = New TypeDescription(TypeArray);
	ParameterDescription.Filter = True;
	
	ParameterDescription = Result.Add();
	ParameterDescription.Name = "Use";
	ParameterDescription.Field = ParameterDescription.Name;
	ParameterDescription.Type = New TypeDescription("Boolean");
	ParameterDescription.Filter = True;
	ParameterDescription.Insert = True;
	ParameterDescription.Update = True;
	ParameterDescription.Template = True;
	
	ParameterDescription = Result.Add();
	ParameterDescription.Name = "ScheduledStartTime";
	ParameterDescription.Field = ParameterDescription.Name;
	ParameterDescription.Type = New TypeDescription("Date");
	ParameterDescription.Insert = True;
	ParameterDescription.Update = True;
	
	ParameterDescription = Result.Add();
	ParameterDescription.Name = "JobState";
	ParameterDescription.Field = ParameterDescription.Name;
	ParameterDescription.Type = New TypeDescription("EnumRef.JobStates");
	ParameterDescription.Filter = True;
	
	ParameterDescription = Result.Add();
	ParameterDescription.Name = "ExclusiveExecution";
	ParameterDescription.Field = ParameterDescription.Name;
	ParameterDescription.Type = New TypeDescription("Boolean");
	ParameterDescription.Insert = True;
	ParameterDescription.Update = True;
	
	ParameterDescription = Result.Add();
	ParameterDescription.Name = "Template";
	ParameterDescription.Field = ParameterDescription.Name;
	ParameterDescription.Type = New TypeDescription("CatalogRef.QueueJobTemplates");
	ParameterDescription.Filter = True;
	ParameterDescription.DataSeparation = True;
	ParameterDescription.ValueForUnseparatedJobs = "UNDEFINED";
	
	ParameterDescription = Result.Add();
	ParameterDescription.Name = "MethodName";
	ParameterDescription.Field = ParameterDescription.Name;
	ParameterDescription.Type = New TypeDescription("String");
	ParameterDescription.Filter = True;
	ParameterDescription.Insert = True;
	ParameterDescription.Update = True;
	
	ParameterDescription = Result.Add();
	ParameterDescription.Name = "Parameters";
	ParameterDescription.Field = ParameterDescription.Name;
	ParameterDescription.Type = New TypeDescription("Array");
	ParameterDescription.Insert = True;
	ParameterDescription.Update = True;
	
	ParameterDescription = Result.Add();
	ParameterDescription.Name = "Key";
	ParameterDescription.Field = ParameterDescription.Name;
	ParameterDescription.Type = New TypeDescription("String");
	ParameterDescription.Filter = True;
	ParameterDescription.Insert = True;
	ParameterDescription.Update = True;
	
	ParameterDescription = Result.Add();
	ParameterDescription.Name = "RestartIntervalOnFailure";
	ParameterDescription.Field = ParameterDescription.Name;
	ParameterDescription.Type = New TypeDescription("Number");
	ParameterDescription.Insert = True;
	ParameterDescription.Update = True;
	
	ParameterDescription = Result.Add();
	ParameterDescription.Name = "Schedule";
	ParameterDescription.Field = ParameterDescription.Name;
	ParameterDescription.Type = New TypeDescription("JobSchedule, Undefined");
	ParameterDescription.Insert = True;
	ParameterDescription.Update = True;
	
	ParameterDescription = Result.Add();
	ParameterDescription.Name = "RestartCountOnFailure";
	ParameterDescription.Field = ParameterDescription.Name;
	ParameterDescription.Type = New TypeDescription("Number");
	ParameterDescription.Insert = True;
	ParameterDescription.Update = True;
	
	For Each ParameterDescription In Result Do
		ParameterDescription.NameUpper = Upper(ParameterDescription.Name);
	EndDo;
	
	Return Result;
	
EndFunction

// Returns allowed comparison types for queue job filters
Function JobFilterComparisonTypes() Export
	
	Result = New Map;
	Result.Insert(ComparisonType.Equal, "=");
	Result.Insert(ComparisonType.NotEqual, "<>");
	Result.Insert(ComparisonType.InList, "IN");
	Result.Insert(ComparisonType.NotInList, "NOT IN");
	
	Return New FixedMap(Result);
	
EndFunction

// Returns partial text of job retrieval query to be returned via interface.
//
// Parameters:
//  JobCatalog - CatalogManager, manager of the catalog used to retrieve 
//  the queue jobs. Used to filter selection fields only applicable 
//  to some of the job catalogs.
//
Function JobQueueSelectionFields(Val JobCatalog = Undefined) Export
	
	SelectionFields = "";
	For Each ParameterDescription In JobQueueInternalCached.QueueJobParameters() Do
		
		If Not IsBlankString(SelectionFields) Then
			SelectionFields = SelectionFields + "," + Chars.LF;
		EndIf;
		
		SelectionFieldDescription = "Queue." + ParameterDescription.Field + " AS " + ParameterDescription.Name;
		
		If JobCatalog <> Undefined Then
			
			If ParameterDescription.DataSeparation Then
				
				If Not CommonUseCached.IsSeparatedConfiguration() Or Not CommonUse.IsSeparatedMetadataObject(JobCatalog, CommonUseCached.AuxiliaryDataSeparator()) Then
					
					SelectionFieldDescription = ParameterDescription.ValueForUnseparatedJobs + " AS " + ParameterDescription.Name;
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
		SelectionFields = SelectionFields + Chars.Tab + SelectionFieldDescription;
		
	EndDo;
	
	Return SelectionFields;
	
EndFunction

// Returns an array of catalog managers that can be used to store queue jobs.
//
Function GetJobCatalogs() Export
	
	CatalogArray = New Array();
	CatalogArray.Add(Catalogs.JobQueue);
	
	If CommonUseCached.IsSeparatedConfiguration() Then
		JobQueueInternalDataSeparationModule = CommonUse.CommonModule("JobQueueInternalDataSeparation");
		JobQueueInternalDataSeparationModule.OnFillJobCatalog(CatalogArray);
	EndIf;
	
	Return CatalogArray;
	
EndFunction

#EndRegion
