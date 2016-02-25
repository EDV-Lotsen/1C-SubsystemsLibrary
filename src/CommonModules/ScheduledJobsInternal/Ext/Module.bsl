////////////////////////////////////////////////////////////////////////////////
// Scheduled jobs subsystem.
// 
////////////////////////////////////////////////////////////////////////////////

#Region InternalInterface

// See the description of this procedure in the StandardSubsystemsServer module.
Procedure InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers) Export
	
	// SERVER HANDLERS.
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaSOperations") Then
		ServerHandlers["StandardSubsystems.SaaSOperations\InfobaseParameterTableOnFill"].Add(
			"ScheduledJobsInternal");
	EndIf;
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

// Throws an exception if the user does not have the administration right.
Procedure RaiseIfNoAdministrationRights() Export
	
	If Not PrivilegedMode() Then
		VerifyAccessRights("Administration", Metadata);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// SL event handlers

// Generates the list of infobase parameters.
//
// Parameters:
// ParameterTable - ValueTable - parameter description table.
// For column content details - see SaaSOperations.GetInfobaseParameterTable()
//
Procedure InfobaseParameterTableOnFill(Val ParameterTable) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaSOperations") Then
		SaasOperationsModule = CommonUse.CommonModule("SaaSOperations");
		SaasOperationsModule.AddConstantToInfobaseParameterTable(ParameterTable, "MaxActiveBackgroundJobExecutionTime");
		SaasOperationsModule.AddConstantToInfobaseParameterTable(ParameterTable, "MaxActiveBackgroundJobCount");
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for working with scheduled jobs

// Is used for "manual" immediate execution of the scheduled job procedure
// either in the client session (in the file infobase) or in the background job on 
// the server (in the server infobase) 
// Is used in any connection mode 
// The "manual" run mode does not affect the scheduled job execution according to 
// the emergency and main schedules, as the background job has no reference to 
// the scheduled job
// The BackgroundJob type does not allow such a reference, so
// the same rule is applied to the file mode
// 
// Parameters:
//  Job       -       ScheduledJob, String - of the ScheduledJob unique ID 
//  StartTime -       Undefined, Date
//                    For the file infobase, sets the passed time as
//                    the scheduled job method start time 
//                    For the server infobase, returns the background job start 
//                    time upon completion 
//  BackgroundJobID - String
//                    For the server infobase, returns the running background job ID
//  FinishedAt -      Undefined,Date 
//                    For the file infobase, returns the scheduled job method completion time
//
Function ExecuteScheduledJobManually(Val Job,
                                     StartTime = Undefined,
                                     BackgroundJobID = "",
                                     FinishedAt = Undefined,
                                     SessionNumber = Undefined,
                                     SessionStarted = Undefined,
                                     BackgroundJobPresentation = "",
                                     ProcedureAlreadyExecuting = Undefined) Export
	
	RaiseIfNoAdministrationRights();
	SetPrivilegedMode(True);
	
	ProcedureAlreadyExecuting = False;
	Job = ScheduledJobsServer.GetScheduledJob(Job);
	
	Started = False;
	LastBackgroundJobProperties = GetLastBackgroundJobForScheduledJobExecutionProperties(Job);
	
	If LastBackgroundJobProperties <> Undefined
	   And LastBackgroundJobProperties.State = BackgroundJobState.Active Then
		
		StartTime  = LastBackgroundJobProperties.Beginning;
		If ValueIsFilled(LastBackgroundJobProperties.Description) Then
			BackgroundJobPresentation = LastBackgroundJobProperties.Description;
		Else
			BackgroundJobPresentation = ScheduledJobPresentation(Job);
		EndIf;
	Else
		BackgroundJobDescription = StringFunctionsClientServer.SubstituteParametersInString(NStr("en = '%1 started manually'"), ScheduledJobPresentation(Job));
		BackgroundJob = BackgroundJobs.Execute(Job.Metadata.MethodName, Job.Parameters, String(Job.UUID), BackgroundJobDescription);
		BackgroundJobID = String(BackgroundJob.UUID);
		StartTime = BackgroundJobs.FindByUUID(BackgroundJob.UUID).Begin;
		Started = True;
	EndIf;
	
	ProcedureAlreadyExecuting = Not Started;
	
	Return Started;
	
EndFunction

// Returns the scheduled job presentation,
// according to the blank details exception order:
// Description, Metadata.Synonym, Metadata.Name.
//
// Parameters:
//  Job      - ScheduledJob, String - if a string, then a UUID string.
//
// Returns:
//  String.
//
Function ScheduledJobPresentation(Val Job) Export
	
	RaiseIfNoAdministrationRights();
	SetPrivilegedMode(True);
	
	If TypeOf(Job) = Type("ScheduledJob") Then
		ScheduledJob = Job;
	Else
		ScheduledJob = ScheduledJobs.FindByUUID(New UUID(Job));
	EndIf;
	
	If ScheduledJob <> Undefined Then
		Presentation = ScheduledJob.Description;
		
		If IsBlankString(ScheduledJob.Description) Then
			Presentation = ScheduledJob.Metadata.Synonym;
			
			If IsBlankString(Presentation) Then
				Presentation = ScheduledJob.Metadata.Name;
			EndIf
		EndIf;
	Else
		Presentation = TextUndefined();
	EndIf;
	
	Return Presentation;
	
EndFunction

// Returns the text "<not defined>".
Function TextUndefined() Export
	
	Return NStr("en = '<not defined>'");
	
EndFunction

// Returns a multiline String containing Messages and ErrorDetails,
// the last background job is found by the scheduled job ID
// and there are messages/errors.
//
// Parameters:
//  Job      - ScheduledJob, String - a ScheduledJob
//                 UUID string.
//
// Returns:
//  String.
//
Function ScheduledJobMessagesAndErrorDescriptions(Val Job) Export
	
	RaiseIfNoAdministrationRights();
	SetPrivilegedMode(True);

	ScheduledJobID = ?(TypeOf(Job) = Type("ScheduledJob"), String(Job.UUID), Job);
	LastBackgroundJobProperties = GetLastBackgroundJobForScheduledJobExecutionProperties(ScheduledJobID);
	Return ?(LastBackgroundJobProperties = Undefined,
	          "",
	          BackgroundJobMessagesAndErrorDescriptions(LastBackgroundJobProperties.ID) );
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for working with background jobs

// Cancels the background job if possible, i.e. if it is running on the server 
// and is active.
//
// Parameters:
//  ID  - a BackgroundJob unique ID string.
// 
Procedure CancelBackgroundJob(ID) Export
	
	RaiseIfNoAdministrationRights();
	SetPrivilegedMode(True);
	
	Filter = New Structure("UUID", New UUID(ID));
	BackgroundJobArray = BackgroundJobs.GetBackgroundJobs(Filter);
	If BackgroundJobArray.Count() = 1 Then
		BackgroundJob = BackgroundJobArray[0];
	Else
		Raise NStr("en = 'The background job is not found on the server.'");
	EndIf;
	
	If BackgroundJob.State <> BackgroundJobState.Active Then
		Raise NStr("en = 'The job is not running, it cannot be cancelled.'");
	EndIf;
	
	BackgroundJob.Cancel();
	
EndProcedure

// Returns a background job property table.
// See the table structure in the EmptyBackgroundJobPropertyTable() function.
// 
// Parameters:
//  Filter - Structure - valid fields:
//                       ID, Key, State, Beginning, End,
//                       Description, MethodName, ScheduledJob. 
//
// Returns:
//  ValueTable  - returns a table after filter.
//
Function GetBackgroundJobPropertyTable(Filter = Undefined) Export
	
	RaiseIfNoAdministrationRights();
	SetPrivilegedMode(True);
	
	Table = EmptyBackgroundJobPropertyTable();
	
	If ValueIsFilled(Filter) And Filter.Property("GetLastScheduledJobBackgroundJob") Then
		Filter.Delete("GetLastScheduledJobBackgroundJob");
		GetLast = True;
	Else
		GetLast = False;
	EndIf;
	
	ScheduledJob = Undefined;
	
	// Adding the history of background jobs received from the server.
	If ValueIsFilled(Filter) And Filter.Property("ScheduledJobID") Then
		If Filter.ScheduledJobID <> "" Then
			ScheduledJob = ScheduledJobs.FindByUUID(
				New UUID(Filter.ScheduledJobID));
			CurrentFilter = New Structure("Key", Filter.ScheduledJobID);
			BackgroundJobsStartedManually = BackgroundJobs.GetBackgroundJobs(CurrentFilter);
			If ScheduledJob <> Undefined Then
				LastBackgroundJob = ScheduledJob.LastJob;
			EndIf;
			If Not GetLast Or LastBackgroundJob = Undefined Then
				CurrentFilter = New Structure("ScheduledJob", ScheduledJob);
				AutomaticBackgroundJobs = BackgroundJobs.GetBackgroundJobs(CurrentFilter);
			EndIf;
			If GetLast Then
				If LastBackgroundJob = Undefined Then
					LastBackgroundJob = LastBackgroundJobInArray(AutomaticBackgroundJobs);
				EndIf;
				
				LastBackgroundJob = LastBackgroundJobInArray(
					BackgroundJobsStartedManually, LastBackgroundJob);
				
				If LastBackgroundJob <> Undefined Then
					BackgroundJobArray = New Array;
					BackgroundJobArray.Add(LastBackgroundJob);
					AddBackgroundJobProperties(BackgroundJobArray, Table);
				EndIf;
				Return Table;
			EndIf;
			AddBackgroundJobProperties(BackgroundJobsStartedManually, Table);
			AddBackgroundJobProperties(AutomaticBackgroundJobs, Table);
		Else
			BackgroundJobArray = New Array;
			AllScheduledJobIDs = New Map;
			For Each CurrentJob In ScheduledJobs.GetScheduledJobs() Do
				AllScheduledJobIDs.Insert(
					String(CurrentJob.UUID), True);
			EndDo;
			AllBackgroundJobs = BackgroundJobs.GetBackgroundJobs();
			For Each CurrentJob In AllBackgroundJobs Do
				If CurrentJob.ScheduledJob = Undefined
				   And AllScheduledJobIDs[CurrentJob.Key] = Undefined Then
				
					BackgroundJobArray.Add(CurrentJob);
				EndIf;
			EndDo;
			AddBackgroundJobProperties(BackgroundJobArray, Table);
		EndIf;
	Else
		If Not ValueIsFilled(Filter) Then
			BackgroundJobArray = BackgroundJobs.GetBackgroundJobs();
		Else
			If Filter.Property("ID") Then
				Filter.Insert("UUID", New UUID(Filter.ID));
				Filter.Delete("ID");
			EndIf;
			BackgroundJobArray = BackgroundJobs.GetBackgroundJobs(Filter);
			If Filter.Property("UUID") Then
				Filter.Insert("ID", String(Filter.UUID));
				Filter.Delete("UUID");
			EndIf;
		EndIf;
		AddBackgroundJobProperties(BackgroundJobArray, Table);
	EndIf;
	
	If ValueIsFilled(Filter) And Filter.Property("ScheduledJobID") Then
		ScheduledJobsForProcessing = New Array;
		If Filter.ScheduledJobID <> "" Then
			If ScheduledJob = Undefined Then
				ScheduledJob = ScheduledJobs.FindByUUID(
					New UUID(Filter.ScheduledJobID));
			EndIf;
			If ScheduledJob <> Undefined Then
				ScheduledJobsForProcessing.Add(ScheduledJob);
			EndIf;
		EndIf;
	Else
		ScheduledJobsForProcessing = ScheduledJobs.GetScheduledJobs();
	EndIf;
	
	Table.Sort("Beginning Desc, End Desc");
	
	// Filtering background jobs.
	If ValueIsFilled(Filter) Then
		Beginning    = Undefined;
		End     = Undefined;
		State = Undefined;
		If Filter.Property("Beginning") Then
			Beginning = ?(ValueIsFilled(Filter.Beginning), Filter.Beginning, Undefined);
			Filter.Delete("Beginning");
		EndIf;
		If Filter.Property("End") Then
			End = ?(ValueIsFilled(Filter.End), Filter.End, Undefined);
			Filter.Delete("End");
		EndIf;
		If Filter.Property("State") Then
			If TypeOf(Filter.State) = Type("Array") Then
				State = Filter.State;
				Filter.Delete("State");
			EndIf;
		EndIf;
		
		If Filter.Count() <> 0 Then
			Rows = Table.FindRows(Filter);
		Else
			Rows = Table;
		EndIf;
		// Performing additional filter by period and state (if the filter is defined).
		ItemNumber = Rows.Count() - 1;
		While ItemNumber >= 0 Do
			If Beginning <> Undefined And Beginning > Rows[ItemNumber].Beginning Or
			   End       <> Undefined And End       < ?(ValueIsFilled(Rows[ItemNumber].End), Rows[ItemNumber].End, CurrentSessionDate()) Or
			   State     <> Undefined And State.Find(Rows[ItemNumber].State) = Undefined Then
				Rows.Delete(ItemNumber);
			EndIf;
			ItemNumber = ItemNumber - 1;
		EndDo;
		// Deleting unnecessary rows from the table.
		If TypeOf(Rows) = Type("Array") Then
			LineNumber = Table.Count() - 1;
			While LineNumber >= 0 Do
				If Rows.Find(Table[LineNumber]) = Undefined Then
					Table.Delete(Table[LineNumber]);
				EndIf;
				LineNumber = LineNumber - 1;
			EndDo;
		EndIf;
	EndIf;
	
	Return Table;
	
EndFunction

// Returns BackgroundJob properties by the unique ID string.
// 
// Parameters:
//  ID - String - of the BackgroundJob unique ID.
//  PropertyNames  - String, if filled, returns a structure with the specified properties.
// 
// Returns:
//  ValueTableRow, Structure - BackgroundJob properties.
//
Function GetBackgroundJobProperties(ID, PropertyNames = "") Export
	
	RaiseIfNoAdministrationRights();
	SetPrivilegedMode(True);
	
	Filter = New Structure("ID", ID);
	BackgroundJobPropertyTable = GetBackgroundJobPropertyTable(Filter);
	
	If BackgroundJobPropertyTable.Count() > 0 Then
		If ValueIsFilled(PropertyNames) Then
			Result = New Structure(PropertyNames);
			FillPropertyValues(Result, BackgroundJobPropertyTable[0]);
		Else
			Result = BackgroundJobPropertyTable[0];
		EndIf;
	Else
		Result = Undefined;
	EndIf;
	
	Return Result;
	
EndFunction

// Returns the properties of the last background job executed with the scheduled job, 
// if there is one.
// The procedure works both in file mode and client/server mode.
//
// Parameters:
//  ScheduledJob - ScheduledJob, String - ScheduledJob unique ID string.
//
// Returns:
//  ValueTableRow, Undefined.
//
Function GetLastBackgroundJobForScheduledJobExecutionProperties(ScheduledJob) Export
	
	RaiseIfNoAdministrationRights();
	SetPrivilegedMode(True);
	
	ScheduledJobID = ?(TypeOf(ScheduledJob) = Type("ScheduledJob"), String(ScheduledJob.UUID), ScheduledJob);
	Filter = New Structure;
	Filter.Insert("ScheduledJobID", ScheduledJobID);
	Filter.Insert("GetLastScheduledJobBackgroundJob");
	BackgroundJobPropertyTable = GetBackgroundJobPropertyTable(Filter);
	BackgroundJobPropertyTable.Sort("End Asc");
	
	If BackgroundJobPropertyTable.Count() = 0 Then
		BackgroundJobProperties = Undefined;
	ElsIf Not ValueIsFilled(BackgroundJobPropertyTable[0].End) Then
		BackgroundJobProperties = BackgroundJobPropertyTable[0];
	Else
		BackgroundJobProperties = BackgroundJobPropertyTable[BackgroundJobPropertyTable.Count()-1];
	EndIf;
	
	Return BackgroundJobProperties;
	
EndFunction

// Returns a multiline String containing Messages and ErrorDetails 
// if the background job is found by the ID and there are messages/errors.
//
// Parameters:
//  Job - String - a BackgroundJob UUID string.
//
// Returns:
//  String.
//
Function BackgroundJobMessagesAndErrorDescriptions(ID, BackgroundJobProperties = Undefined) Export
	
	RaiseIfNoAdministrationRights();
	SetPrivilegedMode(True);
	
	If BackgroundJobProperties = Undefined Then
		BackgroundJobProperties = GetBackgroundJobProperties(ID);
	EndIf;
	
	String = "";
	If BackgroundJobProperties <> Undefined Then
		For Each Message In BackgroundJobProperties.UserMessages Do
			String = String + ?(String = "",
			                    "",
			                    "
			                    |
			                    |") + Message.Text;
		EndDo;
		If ValueIsFilled(BackgroundJobProperties.ErrorDetails) Then
			String = String + ?(String = "",
			                    BackgroundJobProperties.ErrorDetails,
			                    "
			                    |
			                    |" + BackgroundJobProperties.ErrorDetails);
		EndIf;
	EndIf;
	
	Return String;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions

// Returns a new background job property table.
//
// Returns:
//  ValueTable.
//
Function EmptyBackgroundJobPropertyTable()
	
	NewTable = New ValueTable;
	NewTable.Columns.Add("ID",             New TypeDescription("String"));
	NewTable.Columns.Add("Description",    New TypeDescription("String"));
	NewTable.Columns.Add("Key",            New TypeDescription("String"));
	NewTable.Columns.Add("Beginning",      New TypeDescription("Date"));
	NewTable.Columns.Add("End",            New TypeDescription("Date"));
	NewTable.Columns.Add("ScheduledJobID", New TypeDescription("String"));
	NewTable.Columns.Add("State",          New TypeDescription("BackgroundJobState"));
	NewTable.Columns.Add("MethodName",     New TypeDescription("String"));
	NewTable.Columns.Add("Location",       New TypeDescription("String"));
	NewTable.Columns.Add("ErrorDetails",   New TypeDescription("String"));
	NewTable.Columns.Add("StartAttempt",   New TypeDescription("Number"));
	NewTable.Columns.Add("UserMessages",   New TypeDescription("Array"));
	NewTable.Columns.Add("SessionNumber",  New TypeDescription("Number"));
	NewTable.Columns.Add("SessionStarted", New TypeDescription("Date"));
	NewTable.Indexes.Add("ID, Beginning");
	
	Return NewTable;
	
EndFunction

Procedure AddBackgroundJobProperties(Val BackgroundJobArray, Val BackgroundJobPropertyTable)
	
	Index = BackgroundJobArray.Count() - 1;
	While Index >= 0 Do
		BackgroundJob = BackgroundJobArray[Index];
		Row = BackgroundJobPropertyTable.Add();
		FillPropertyValues(Row, BackgroundJob);
		Row.ID = BackgroundJob.UUID;
		ScheduledJob = BackgroundJob.ScheduledJob;
		
		If ScheduledJob = Undefined
		   And StringFunctionsClientServer.IsUUID(BackgroundJob.Key) Then
			
			ScheduledJob = ScheduledJobs.FindByUUID(New UUID(BackgroundJob.Key));
		EndIf;
		Row.ScheduledJobID = ?(
			ScheduledJob = Undefined,
			"",
			ScheduledJob.UUID);
		
		Row.ErrorDetails = ?(
			BackgroundJob.ErrorInfo = Undefined,
			"",
			DetailErrorDescription(BackgroundJob.ErrorInfo));
		
		Index = Index - 1;
	EndDo;
	
EndProcedure

Function LastBackgroundJobInArray(BackgroundJobArray, LastBackgroundJob = Undefined)
	
	For Each CurrentBackgroundJob In BackgroundJobArray Do
		If LastBackgroundJob = Undefined Then
			LastBackgroundJob = CurrentBackgroundJob;
			Continue;
		EndIf;
		If ValueIsFilled(LastBackgroundJob.End) Then
			If Not ValueIsFilled(CurrentBackgroundJob.End)
			 Or LastBackgroundJob.End < CurrentBackgroundJob.End Then
				LastBackgroundJob = CurrentBackgroundJob;
			EndIf;
		Else
			If Not ValueIsFilled(CurrentBackgroundJob.End)
			   And LastBackgroundJob.Beginning < CurrentBackgroundJob.Beginning Then
				LastBackgroundJob = CurrentBackgroundJob;
			EndIf;
		EndIf;
	EndDo;
	
	Return LastBackgroundJob;
	
EndFunction

#EndRegion
