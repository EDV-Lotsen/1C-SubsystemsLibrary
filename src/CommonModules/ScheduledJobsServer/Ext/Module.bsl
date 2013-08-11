////////////////////////////////////////////////////////////////////////////////
// Scheduled jobs subsystem.
// 
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// Adds update handlers required by this subsystem to the Handlers list. 
// 
// Parameters:
// Handlers - ValueTable - see the description of the 
// InfoBaseUpdate.NewUpdateHandlerTable function for details.
// 
Procedure RegisterUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version = "1.2.2.2";
	Handler.Procedure = "ScheduledJobsServer.ConvertScheduledJobExecutionSettings_1_2_2_2";
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for controlling job execution. 

// Determines whether scheduled jobs are executed in the current session.
// If they are not executed in this session and the session number is equal to
// GetScheduledJobExecutionStates().SessionNumber, the function attempts to assign the
// session to perform scheduled jobs (sets CurrentSessionPerformsScheduledJobs to True).
//
// Parameters:
//  JobsExecutedCorrectly                               - Boolean - True if jobs are 
//                                                        executed correctly.
//  SetCurrentSessionAsSessionThatPerformsScheduledJobs - Boolean - True if scheduled
//                                                        jobs must be executed in the
//                                                        current session.
//                                                        If the function fails to 
//                                                        assign the session to perform 
//                                                        scheduled jobs, this
//                                                        parameter is set to False. 
//  ErrorDescription                                    - String - contains the error 
//                                                        description if
//                                                        JobsExecutedCorrectly is
//                                                        False. It can describe two 
//                                                        basic situations: the  
//                                                        execution has not  
//                                                        started for a long time or 
//                                                        the execution is taking too
//                                                        much time.
//
// Returns:
//  Boolean.
//
Function CurrentSessionPerformsScheduledJobs(JobsExecutedCorrectly = Undefined,
                                                 Val SetCurrentSessionAsSessionThatPerformsScheduledJobs = False,
                                                 ErrorDescription = "") Export
	
	If Not CommonUse.FileInfoBase() Then
		JobsExecutedCorrectly = True;
		ErrorDescription = NStr("en = 'Jobs are executed on the server.'");
		Return False;
	EndIf;
	
	SetPrivilegedMode(True);
	
	State = GetScheduledJobExecutionStates();
	
	Sessions = GetInfoBaseSessions();
	FoundSessionForPerformingJobs       = False;
	CurrentSessionPerformsScheduledJobs = False;
	JobsExecutedCorrectly               = True;
	
	// Searching the list of active sessions for the session that performs scheduled  
	// jobs (this session is specified in the ScheduledJobExecutionStates structure).
	// Searching for the current session (its SessionStarted parameter value might be 
	// required for the structure initialization).
	For Each Session In Sessions Do
		If Session.SessionNumber = InfoBaseSessionNumber() Then
			CurrentSession = Session;
		EndIf;
		If Session.SessionNumber  = State.SessionNumber
		   And Session.SessionStarted = State.SessionStarted Then
			//
			FoundSession = Session;
			FoundSessionForPerformingJobs = True;
			CurrentSessionPerformsScheduledJobs = (Session.SessionNumber = InfoBaseSessionNumber());
		EndIf;
	EndDo;
	
	If Not FoundSessionForPerformingJobs And SetCurrentSessionAsSessionThatPerformsScheduledJobs Then
		CurrentSessionTime                  = CurrentSessionDate();
		State.SessionNumber                 = CurrentSession.SessionNumber;
		State.SessionStarted                = CurrentSession.SessionStarted;
		State.ComputerName                  = ComputerName();
		State.ApplicationName               = CurrentSession.ApplicationName;
		State.UserName                      = UserName();
		State.NextJobID                     = Undefined;
		State.NextJobExecutionStartTime     = CurrentSessionTime;
		State.NextJobExecutionEndTime       = CurrentSessionTime;
		SaveScheduledJobExecutionStates(State);
		FoundSessionForPerformingJobs       = True;
		CurrentSessionPerformsScheduledJobs = True;
	EndIf;
	
	If Not FoundSessionForPerformingJobs Then
		ErrorDescription = NStr("en = 'No session is assigned to perform scheduled jobs.'");
		JobsExecutedCorrectly = False;
		//
	ElsIf Not ValueIsFilled(State.NextJobExecutionEndTime) Then
		// If the last job started more than an hour ago, notifying the user about the start delay.
		If CurrentSessionDate() - 3600 > State.NextJobExecutionEndTime Then
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'The scheduled job execution does not start for more than one hour.
					           |Perhaps you have to restart the session. Expected execution details:
					           |    Computer:       %1,
					           |    Application:    %2,
					           |    User name:      %3,
					           |    Session number: %4.'"),
					String(State.ComputerName),
					String(State.ApplicationName),
					String(State.UserName),
					String(State.SessionNumber) );
			JobsExecutedCorrectly = False;
		EndIf;
	Else
				// If the job is being executed uninterruptedly for more than one hour, notifying the user. 
If CurrentSessionDate() - 3600 > State.NextJobExecutionStartTime Then
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'The scheduled job is being executed uninterruptedly for more than one hour.
					           |Perhaps you have to restart the session. Execution details:
					           | Computer:       %1,
					           | Application:    %2,
					           | User name:      %3,
					           | Session number: %4.'"),
					String(State.ComputerName),
					String(State.ApplicationName),
					String(State.UserName),
					String(State.SessionNumber));
			JobsExecutedCorrectly = False;
		EndIf;
	EndIf;
	
	Return CurrentSessionPerformsScheduledJobs;
	
EndFunction

// Checks whether the session that opened this additional session for performing
// scheduled jobs was closed, provided that the parent session is specified.
//
// Parameters:
//  LaunchParameter    - String - the value of the LaunchParameter global property;
//                       passing this parameter is requred, because it is not available
//                       on the server. 
//  IsParentSessionSet - Boolean - returns True if the parent session is set, otherwise
//                       returns False.
//
// Returns:
//  Boolean.
//
Function IsParentSessionSetAndClosed(Val LaunchParameter) Export

	IsParentSessionSet = False;
	If Find(LaunchParameter, "ExecuteScheduledJobs") <> 0 Then
		SessionNumberIndex = Find(LaunchParameter, "SessionNumber=");
		SessionStartIndex = Find(LaunchParameter, "SessionStarted=");
		If SessionNumberIndex <> 0 And
		     SessionStartIndex <> 0 And
		     SessionNumberIndex < SessionStartIndex Then
			IsParentSessionSet = True;
		    Sessions = GetInfoBaseSessions();
			For Each Session In Sessions Do
				If Find(LaunchParameter, "SessionNumber="  + Session.SessionNumber)  <> 0 And
				     Find(LaunchParameter, "SessionStarted=" + Session.SessionStarted) <> 0 Then
					Return False;
				EndIf;
			EndDo;
			Return True;
		EndIf;
	EndIf;
	Return False;

EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for working with scheduled jobs.

Procedure SetScheduledJobUse(Val ID, Val Use) Export
	
	SetPrivilegedMode(True);
	
	Job = GetScheduledJob(ID);
	Job.Use = Use;
	Job.Write();
	
EndProcedure

Function GetJobScheduleInStructure(Val ID) Export
	
	RaiseIfNoAdministrativeRights();
	SetPrivilegedMode(True);
	
	Return CommonUseClientServer.ScheduleToStructure(GetScheduledJob(ID).Schedule);
	
EndFunction

Procedure SetJobScheduleFromStructure(Val ID, Val ScheduleInStructure) Export
	
	SetPrivilegedMode(True);
	
	Job = GetScheduledJob(ID);
	Job.Schedule = CommonUseClientServer.StructureToSchedule(ScheduleInStructure);
	Job.Write();
	
EndProcedure

// Returns scheduled job execution settings for the file mode.
// 
// Returns:
//  Structure.
//
Function GetScheduledJobExecutionSettings() Export
	
	SetPrivilegedMode(True);
	
	Settings = Constants.ScheduledJobExecutionSettings.Get();
	Settings = ?(TypeOf(Settings) = Type("ValueStorage"), Settings.Get(), Undefined);
	
	Return CheckSettings(Settings);
	
EndFunction

// Sets scheduled job execution settings for the file mode.
// 
// Parameters:
//  Settings - Structure.
//
Procedure SetScheduledJobExecutionSettings(Settings) Export
	
	SetPrivilegedMode(True);
	
	Settings = CheckSettings(Settings);
	
	Constants.ScheduledJobExecutionSettings.Set(New ValueStorage(Settings));
	
EndProcedure

// Emulates the execution of the ProcessJobs internal procedure in the thin client mode.
// Can be executed in the thick client mode.
// 
// Background job instances are stored in TempStorage.
// Instances are stored while the session that performs scheduled jobs is running.
// The maximum number of simultaneously stored scheduled jobs is 1000.
// 
// The ID of the session that performs scheduled jobs is stored in the
// ScheduledJobExecutionStates structure (ValueStorage). This structure contains the 
// following properties: 
//   SessionNumber,
//   SessionStarted,
//   NextJobID,
//   NextJobExecutionStartTime,
//   NextJobExecutionEndTime,
//   and others.
//
// The procedure checks whether scheduled jobs must be executed in the current session as follows:
// If SessionNumber and SessionStarted match the current session number and start
// time, the job is executed in the current session, otherwise the 
// procedure checks whether the session is present in the session list.
//   If the session is not present in the list, the job is executed in the
//   current session,
//   otherwise the job is not executed in the curent session bu the execution/idle time
//   must be checked. 
//     If the execution/idle time is more than one hour, the procedure notifies the  
//     user (a detailed error message is displayed).
//
// The procedure defines the job execution order as follows:
// Jobs are executed consecutively. The last started job is registered. During the next
// check, the job that follows the last started job is checked to get parallel 
// executione effect.
//
// The procedure checks the schedule as follows:
// The emergency schedule is used if an error occurs, otherwise the main schedule is used.
// 
// Parameters:
//  ExecutionTime - Number(10.0) - execution time (in seconds) of the next set of
//                  scheduled jobs. If it is not specified, a single execution 
//                  iteration is performed. The iteration ends when one background job 
//                  is completed or when all scheduled jobs are completed without
//                  running background jobs (schedule checking).
//
Procedure ExecuteScheduledJobs(ExecutionTime = 0) Export
	
	If Not CommonUse.FileInfoBase() Then
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	
	If Not CurrentSessionPerformsScheduledJobs() Then
		Return;
	EndIf;
	
	State = GetScheduledJobExecutionStates();
	
	ExecutionTime = ?(TypeOf(ExecutionTime) = Type("Number"), ExecutionTime, 0);

	Jobs                   = ScheduledJobs.GetScheduledJobs();
	ExecutionCompleted     = False; // Determines whether ExecutionTime is up, or
	                                // whether all enabled scheduled jobs are completed.
	ExecutionStarted       = CurrentSessionDate();
	ExecutedJobCount      = 0;
	BackgroundJobExecuted  = False;
	LastJobID              = State.NextJobID;

	// The jobs are counted every time the execution is started in order to prevent the 
	// infinite loop error, which might be caused by deleting a job in another session.
	While Not ExecutionCompleted And Jobs.Count() > 0 Do
		FirstJobFound = (LastJobID = Undefined);
		NextJobFound  = False;
		For Each Job In Jobs Do
			// Finishing the execution if:
			// a) the specified execution time is up;
			// b) the execution time is not specified and one background job is completed;
			// c) the execution time is not specified and all background jobs are completed 
     //   (this check is performed by counting the jobs).
			If ( ExecutionTime = 0 And
			       ( BackgroundJobExecuted Or
			         ExecutedJobCount >= Jobs.Count() ) ) Or
			     ( ExecutionTime <> 0 And
			       ExecutionStarted + ExecutionTime <= CurrentSessionDate() ) Then
				ExecutionCompleted = True;
				Break;
			EndIf;
			If Not FirstJobFound Then
				If String(Job.UUID) = LastJobID Then
				   // The last completed scheduled job is found, the next scheduled job 
				   // therefore requires a check whether background job execution is required. 
				   FirstJobFound = True;
				EndIf;
				// If the first scheduled job to be checked is not yet found, the current job is skipped.
				Continue;
			EndIf;
			NextJobFound                    = True;
			ExecutedJobCount                = ExecutedJobCount + 1;
			State.NextJobID                 = String(Job.UUID);
			State.NextJobExecutionStartTime = CurrentSessionDate();
			State.NextJobExecutionEndTime   = '00010101';
			SaveScheduledJobExecutionStates(State,
			                               "NextJobID, 
			                               |NextJobExecutionStartTime, 
			                               |NextJobExecutionEndTime");
			If Job.Use Then
				ExecuteScheduledJob = False;
				LastBackgroundJobProperties = GetLastBackgroundJobForScheduledJobExecutionProperties(Job);
				
				If LastBackgroundJobProperties <> Undefined And
				     LastBackgroundJobProperties.State = BackgroundJobState.Failed Then
					// Checking the emergency schedule.
					If LastBackgroundJobProperties.StartAttempt <= Job.RestartCountOnFailure Then
						If LastBackgroundJobProperties.End + Job.RestartIntervalOnFailure <= CurrentSessionDate() Then
						    // Restarting the background job by the scheduled job.
						    ExecuteScheduledJob = True;
						EndIf;
					EndIf;
				Else
					// Checking the standard schedule.
					ExecuteScheduledJob = Job.Schedule.ExecutionRequired(
						CurrentSessionDate(),
						?(LastBackgroundJobProperties = Undefined, '00010101', LastBackgroundJobProperties.Start),
						?(LastBackgroundJobProperties = Undefined, '00010101', LastBackgroundJobProperties.End) );
				EndIf;
				If ExecuteScheduledJob Then
					BackgroundJobExecuted = ExecuteScheduledJob(Job);
				EndIf;
			EndIf;
			State.NextJobExecutionEndTime = CurrentSessionDate();
			SaveScheduledJobExecutionStates(State, "NextJobExecutionEndTime");
		EndDo;
		// Clearing LastJobID if the last completed job is not found,
		// to start checking scheduled jobs from the beginning.
		LastJobID = Undefined;
	EndDo;
	
EndProcedure

// Retrieves ScheduledJob from the infobase by UUID.
// 
// Parameters:
//  ID - ScheduledJob UUID.
// 
// Returns:
//  ScheduledJob.
//
Function GetScheduledJob(Val ID) Export

	RaiseIfNoAdministrativeRights();
	SetPrivilegedMode(True);
	
	ScheduledJob = ScheduledJobs.FindByUUID(New UUID(ID));
	
	If ScheduledJob = Undefined Then
		Raise( NStr("en = 'The job is not found in the list.
		                              |Perhaps another user deletes it.'") );
	EndIf;
	
	Return ScheduledJob;
	
EndFunction

// This function is intended for immediate execution of a scheduled job manually in a 
// client session (if 1C:Enterprise is running in the file mode) or in a background  
// job on the server (if 1C:Enterprise is running in the client/server mode).
// This function can be used in any connection mode.
// The manual execution has no effect on the scheduled execution of jobs because the 
// scheduled job reference of the background job is not specified during this
// operation.
// Specifying such references is not allowed for the BackgroundJob type, therefore 
// this rule also applies in the file mode.
// 
// Parameters:
//  Job             - ScheduledJob, String - scheduled job or its UUID. 
//  StartedAt       - Undefined, Date - in the file mode, it specifies the point in 
//                    time of the scheduled job start.
//                    in the client/server mode, returns start date and time of the
//                    background job.
//  BackgroundJobID - String - in the client/server mode, it returns ID of the started
//                    background job. 
//  FinishedAt      - Undefined, Date - in the file mode, returns the end date and
//                    time of the scheduled.
//
Function ExecuteScheduledJobManually(Val Job,
                                     StartedAt = Undefined,
                                     BackgroundJobID = "",
                                     FinishedAt = Undefined,
                                     SessionNumber = Undefined,
                                     SessionStarted = Undefined,
                                     BackgroundJobPresentation = "",
                                     ProcedureAlreadyExecuting = Undefined) Export
	
	RaiseIfNoAdministrativeRights();
	SetPrivilegedMode(True);
	
	ProcedureAlreadyExecuting = False;
	Job = ?(TypeOf(Job) = Type("ScheduledJob"), Job, GetScheduledJob(Job));
	
	Start = False;
	If CommonUse.FileInfoBase() Then
		Start = ExecuteScheduledJob(Job, True, StartedAt, FinishedAt, SessionNumber, SessionStarted);
	Else
		LastBackgroundJobProperties = GetLastBackgroundJobForScheduledJobExecutionProperties(Job);
		If LastBackgroundJobProperties <> Undefined
		   And LastBackgroundJobProperties.State = BackgroundJobState.Active Then
			//
			StartedAt  = LastBackgroundJobProperties.Start;
			If ValueIsFilled(LastBackgroundJobProperties.Description) Then
				BackgroundJobPresentation = LastBackgroundJobProperties.Description;
			Else
				BackgroundJobPresentation = ScheduledJobPresentation(Job);
			EndIf;
		Else
			BackgroundJobDescription = StringFunctionsClientServer.SubstituteParametersInString(NStr("en = 'Started manually: "), ScheduledJobPresentation(Job));
			BackgroundJob = BackgroundJobs.Execute(Job.Metadata.MethodName, Job.Parameters, String(Job.UUID), BackgroundJobDescription);
			BackgroundJobID = String(BackgroundJob.UUID);
			StartedAt = BackgroundJobs.FindByUUID(BackgroundJob.UUID).Start;
			Start = True;
		EndIf;
	EndIf;
	
	ProcedureAlreadyExecuting = Not Start;
	
	Return Start;
	
EndFunction

// Returns the scheduled job presentation.
// The scheduled job presentation is the first filled value of the following sequence:
// Description, Metadata.Synonym, Metadata.Name.
// If none of these values are filled, the function returns "<not defined>". 
//
// Parameters:
//  Job - ScheduledJob, String - scheduled job or its UUID string.
//
// Returns:
//  String.
//
Function ScheduledJobPresentation(Val Job) Export
	
	RaiseIfNoAdministrativeRights();
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

// Returns the "<not defined>" text.
Function TextUndefined() Export
	
	Return NStr("en = '<not defined>'");
	
EndFunction

// Returns the value of the flag that shows whether the user is notified about
// job execution errors.
//
// Returns:
//  Boolean.
//
Function NotifyAboutScheduledJobExecutionErrors(NotificationPeriod) Export
	
	SetPrivilegedMode(True);
	
	NotifyAboutIncorrectState = False;
	
	If CommonUse.FileInfoBase() Then
		Settings = GetScheduledJobExecutionSettings();
		NotificationPeriod = Settings.ScheduledJobErrorNotificationPeriod;
		NotificationPeriod = ?(NotificationPeriod <= 0, 1, NotificationPeriod);
		NotifyAboutIncorrectState = Settings.NotifyAboutIncorrectScheduledJobExecution;
	Else
		NotificationPeriod = 1;
	EndIf;
	
	Return NotifyAboutIncorrectState;
	
EndFunction

// Returns multiline String that contains Messages and ErrorDetails of the last
// scheduled job found by scheduled job ID.
//
// Parameters:
// Job - ScheduledJob, String - scheduled job or its UUID string.
//
// Returns:
//  String.
//
Function ScheduledJobMessagesAndErrorDescriptions(Val Job) Export
	
	RaiseIfNoAdministrativeRights();
	SetPrivilegedMode(True);

	ScheduledJobID = ?(TypeOf(Job) = Type("ScheduledJob"), String(Job.UUID), Job);
	LastBackgroundJobProperties = GetLastBackgroundJobForScheduledJobExecutionProperties(ScheduledJobID);
	Return ?(LastBackgroundJobProperties = Undefined,
	          "",
	          BackgroundJobMessagesAndErrorDescriptions(LastBackgroundJobProperties.ID) );
	
EndFunction

// Returns the start parameters of the separate session that performs scheduled jobs.
//
// Parameters:
//  ByAutoStart - Boolean - flag that shows whether the session will be started if
//                the following three conditions is true: 
//                 the automatic session start is enabled,
//                 the infobase runs in the file mode,
//                 the session has not been started.
//
// Returns:
//  Structure with the following fields:
//                RequiredSeparateSessionStart    - Boolean - True.
//                AdditionalCommandLineOptions    - String - additional command-line
//                                                  options for starting the session 
//                                                  that will perform jobs.
//                TriedToOpen                    - Boolean - False, to be used in 
//                                                  the calling procedure.
//                NotifyAboutIncorrectExecution   - Boolean.
//                NotificationPeriod              - Number.
//                Cancel                          - Boolean.
//                ErrorDescription                - String.
//
Function ScheduledJobExecutionSeparateSessionLaunchParameters(Val ByAutoStart = False) Export
	
	Result = New Structure;
	Result.Insert("RequiredSeparateSessionStart", False);
	Result.Insert("TriedToOpen", False);
	Result.Insert("AdditionalCommandLineOptions", "");
	Result.Insert("NotifyAboutIncorrectExecution", False);
	Result.Insert("NotificationPeriod", Undefined);
	Result.Insert("Cancel", False);
	Result.Insert("ErrorDescription", "");
	
	If ByAutoStart Then
		Result.Insert("CurrentUserAdministrator", Users.InfoBaseUserWithFullAccess(, True));
	EndIf;
	
	SetPrivilegedMode(True);
	Result.NotifyAboutIncorrectExecution = NotifyAboutScheduledJobExecutionErrors(Result.NotificationPeriod);
	
	Settings = GetScheduledJobExecutionSettings();
	If ByAutoStart And Not Settings.AutomaticallyStartSeparateSessionForExecutingSchedledJobs Then
		Return Result;
	EndIf;
	
	If Not CommonUse.FileInfoBase() Then
		If ByAutoStart Then
			Return Result;
		Else
			Result.Cancel = True;
			Result.ErrorDescription = NStr("en = 'Scheduled jobs are executed on the server.'");
			Return Result;
		EndIf;
	EndIf;

	JobsExecutedCorrectly = Undefined;
	CurrentSessionPerformsScheduledJobs(JobsExecutedCorrectly);
	If JobsExecutedCorrectly Then
		If ByAutoStart Then
			Return Result;
		Else
			Result.Cancel = True;
			Result.ErrorDescription = NStr("en = 'The session that performs scheduled jobs is already started.'");
			Return Result;
		EndIf;
	EndIf;
	
	CurrentSessionNumber = InfoBaseSessionNumber();
	// Determining the start time of the current session.
	CurrentSessionStarted = '00010101';
	Sessions = GetInfoBaseSessions();
	For Each Session In Sessions Do
		If Session.SessionNumber = CurrentSessionNumber Then
			CurrentSessionStarted = Session.SessionStarted;
			Break;
		EndIf;
	EndDo;
	Result.AdditionalCommandLineOptions = """"
		+ " /C""ExecuteScheduledJobs IgnoreWarnings SeparateSession FromApplication"
		+ "SessionNumber=" + CurrentSessionNumber + " SessionStarted=" + CurrentSessionStarted + """";
	
	Result.RequiredSeparateSessionStart = True;
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for working with background jobs.

// Cancels the background job if it is possible (that is, the background job is executed on the server and is active).
//
// Parameters:
//  ID  - BackgroundJob UUID.
// 
Procedure CancelBackgroundJob(ID) Export
	
	If CommonUse.FileInfoBase() Then
		Raise( NStr("en = 'Background jobs are not used
		                             |in the file mode.'"));
	EndIf;
	
	RaiseIfNoAdministrativeRights();
	SetPrivilegedMode(True);
	
	Filter = New Structure("UUID", New UUID(ID));
	BackgroundJobArray = BackgroundJobs.GetBackgroundJobs(Filter);
	If BackgroundJobArray.Count() = 1 Then
		BackgroundJob = BackgroundJobArray[0];
	Else
		Raise( NStr("en = 'The background job is not found on the server.'") );
	EndIf;
	
	If BackgroundJob.State <> BackgroundJobState.Active Then
		Raise( NStr("en = 'The job is not being executed, therefore it cannot be canceled.'") );
	EndIf;
	
	BackgroundJob.Cancel();
	
EndProcedure

// Emulates the BackgroundJobs.GetBackgroundJobs() function in the file mode.
//  For details on the table structure, see the description of the 
//  EmptyBackgroundJobPropertyTable function.
// 
// Parameters:
//  Filter        - Structure that can contain the following fields:
//                  ID, Key, State, Start, End, Description, MethodName, ScheduledJob. 
//  TotalJobCount - Number - returns the number of jobs without taking the filter into
//                  account.
//  ReadState     - Undefined - for internal use only.
//
// Returns:
//  ValueTable  - filtered table.
//
Function GetBackgroundJobPropertyTable(Filter = Undefined, TotalJobCount = 0) Export
	
	RaiseIfNoAdministrativeRights();
	SetPrivilegedMode(True);
	
	Table = EmptyBackgroundJobPropertyTable();
	
	If Filter <> Undefined And Filter.Property("GetLastBackgroundJobOfScheduledJob") Then
		Filter.Delete("GetLastBackgroundJobOfScheduledJob");
		GetLast = True;
	Else
		GetLast = False;
	EndIf;
	
	ScheduledJob = Undefined;
	
	// Adding a history of background jobs that were received from the server
	If Not CommonUse.FileInfoBase() Then
		If Filter <> Undefined And Filter.Property("ScheduledJobID") Then
			ScheduledJob = ScheduledJobs.FindByUUID(New UUID(Filter.ScheduledJobID));
			BackgroundJobArray = New Array;
			If ScheduledJob <> Undefined Then
				LastBackgroundJob = ScheduledJob.LastJob;
				If GetLast And LastBackgroundJob <> Undefined Then
					BackgroundJobArray.Add(LastBackgroundJob);
					AddBackgroundJobProperties(BackgroundJobArray, Table);
				Else
					FirstFilter = New Structure("ScheduledJob", ScheduledJob);
					BackgroundJobArray = BackgroundJobs.GetBackgroundJobs(FirstFilter);
					AddBackgroundJobProperties(BackgroundJobArray, Table);
				EndIf;
			EndIf;
			If Not GetLast Or BackgroundJobArray.Count() = 0 Then
				SecondFilter = New Structure("Key", Filter.ScheduledJobID);
				AddBackgroundJobProperties(BackgroundJobs.GetBackgroundJobs(SecondFilter), Table);
			EndIf;
			If GetLast Then
				Return Table;
			EndIf;
		Else
			If Filter = Undefined Then
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
	EndIf;
	
	If Filter <> Undefined And Filter.Property("ScheduledJobID") Then
		ScheduledJobsToProcess = New Array;
		If ScheduledJob = Undefined Then
			ScheduledJob = ScheduledJobs.FindByUUID(New UUID(Filter.ScheduledJobID));
		EndIf;
		If ScheduledJob <> Undefined Then
			ScheduledJobsToProcess.Add(ScheduledJob);
		EndIf;
	Else
		ScheduledJobsToProcess = ScheduledJobs.GetScheduledJobs();
	EndIf;
	
	// Adding and saving scheduled job states
	For Each ScheduledJob In ScheduledJobsToProcess Do
		ScheduledJobID = String(ScheduledJob.UUID);
		Properties = CommonSettingsStorage.Load("ScheduledJobState_" + ScheduledJobID, , , "");
		Properties = ?(TypeOf(Properties) = Type("ValueStorage"), Properties.Get(), Undefined);
		
		If TypeOf(Properties) = Type("Structure")
		   And Properties.ScheduledJobID = ScheduledJobID
		   And Table.FindRows(New Structure("ID, AtServer", Properties.ID, Properties.AtServer)).Count() = 0 Then
			
			If Properties.AtServer Then
				CommonSettingsStorage.Save("ScheduledJobState_" + ScheduledJobID, , Undefined, , "");
			Else
				If Properties.State = BackgroundJobState.Active Then
					FoundSessionForPerformingJobs = False;
					For Each Session In GetInfoBaseSessions() Do
						If Session.SessionNumber = Properties.SessionNumber
						   And Session.SessionStarted = Properties.SessionStarted Then
							FoundSessionForPerformingJobs = InfoBaseSessionNumber() <> Session.SessionNumber;
							Break;
						EndIf;
					EndDo;
					If Not FoundSessionForPerformingJobs Then
						Properties.End = CurrentSessionDate();
						Properties.State = BackgroundJobState.Failed;
						Properties.ErrorDetails = NStr("en = 'The session that executes the scheduled job procedure is not found.'");
					EndIf;
				EndIf;
				FillPropertyValues(Table.Add(), Properties);
			EndIf;
		EndIf;
	EndDo;
	Table.Sort("Start Desc, End Desc");
	
	TotalJobCount = Table.Count();
	
	// Filtering background jobs
	If Filter <> Undefined Then
		Start = Undefined;
		End   = Undefined;
		State = Undefined;
		If Filter.Property("Start") Then
			Start = ?(ValueIsFilled(Filter.Start), Filter.Start, Undefined);
			Filter.Delete("Start");
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
		// Applying an additional filter by period and state (if the filter is specified)
		ItemNumber = Rows.Count() - 1;
		While ItemNumber >= 0 Do
			If Start <> Undefined And Start > Rows[ItemNumber].Start Or
				 End   <> Undefined And End  < ?(ValueIsFilled(Rows[ItemNumber].End), Rows[ItemNumber].End, CurrentSessionDate()) Or
				 State <> Undefined And State.Find(Rows[ItemNumber].State) = Undefined Then
				Rows.Delete(ItemNumber);
			EndIf;
			ItemNumber = ItemNumber - 1;
		EndDo;
		// Deleting excess rows from the table
		If TypeOf(Rows) = Type("Array") Then
			LineNumber = TotalJobCount - 1;
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

// Returns BackgroundJob properties by UUID.
// 
// Parameters:
//  ID                       - String - BackgroundJob UUID.
//  PropertyNames            - String, Optional - names of properties to be included in
//                             the result structure.
// 
// Returns:
//  ValueTableRow, Structure - BackgroundJob properties.
//
Function GetBackgroundJobProperties(ID, PropertyNames = "") Export
	
	RaiseIfNoAdministrativeRights();
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

// Returns properties of the last background job completed for a scheduled job
// execution. If there is no such job, Undefined is returned.
// Can be called in the file and client/server modes.
//
// Parameters:
//  ScheduledJob - ScheduledJob, String - ScheduledJob UUID.
//
// Returns:
//  ValueTableRow, Undefined.
//
Function GetLastBackgroundJobForScheduledJobExecutionProperties(ScheduledJob) Export
	
	RaiseIfNoAdministrativeRights();
	SetPrivilegedMode(True);
	
	ScheduledJobID = ?(TypeOf(ScheduledJob) = Type("ScheduledJob"), String(ScheduledJob.UUID), ScheduledJob);
	Filter = New Structure;
	Filter.Insert("ScheduledJobID", ScheduledJobID);
	Filter.Insert("GetLastBackgroundJobOfScheduledJob");
	BackgroundJobPropertyTable = GetBackgroundJobPropertyTable(Filter);
	BackgroundJobPropertyTable.Sort("End Asc");
	
	If BackgroundJobPropertyTable.Count() = 0 Then
		BackgroundJobProperties = Undefined;
	ElsIf Not ValueIsFilled(BackgroundJobPropertyTable[0].End) Then
		BackgroundJobProperties = BackgroundJobPropertyTable[0];
	Else
		BackgroundJobProperties = BackgroundJobPropertyTable[BackgroundJobPropertyTable.Count()-1];
	EndIf;
	
	ValueToStore = New ValueStorage(?(BackgroundJobProperties = Undefined, Undefined, CommonUse.ValueTableRowToStructure(BackgroundJobProperties)));
	CommonSettingsStorage.Save("ScheduledJobState_" + ScheduledJobID, , ValueToStore, , "");
	
	Return BackgroundJobProperties;
	
EndFunction

// Returns multiline String that contains Messages and ErrorDetails of the last
// background job found by scheduled job ID.
//
// Parameters:
//  Job - String - BackgroundJob UUID string.
//
// Returns:
//  String.
//
Function BackgroundJobMessagesAndErrorDescriptions(ID, BackgroundJobProperties = Undefined) Export
	
	RaiseIfNoAdministrativeRights();
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
// INTERNAL PROCEDURES AND FUNCTIONS

// Raises an exception if the user has no administrative rights.
Procedure RaiseIfNoAdministrativeRights()
	
	If Not PrivilegedMode() Then
		VerifyAccessRights("Administration", Metadata);
	EndIf;
	
EndProcedure

// Returns a new background job property table.
//
// Returns:
//  ValueTable.
//
Function EmptyBackgroundJobPropertyTable()
	
	NewTable = New ValueTable;
	NewTable.Columns.Add("AtServer",       New TypeDescription("Boolean"));
	NewTable.Columns.Add("ID",             New TypeDescription("String"));
	NewTable.Columns.Add("Description",    New TypeDescription("String"));
	NewTable.Columns.Add("Key",            New TypeDescription("String"));
	NewTable.Columns.Add("Start",          New TypeDescription("Date"));
	NewTable.Columns.Add("End",            New TypeDescription("Date"));
	NewTable.Columns.Add("ScheduledJobID", New TypeDescription("String"));
	NewTable.Columns.Add("State",          New TypeDescription("BackgroundJobState"));
	NewTable.Columns.Add("MethodName",     New TypeDescription("String"));
	NewTable.Columns.Add("Placement",      New TypeDescription("String"));
	NewTable.Columns.Add("ErrorDetails",   New TypeDescription("String"));
	NewTable.Columns.Add("StartAttempt",   New TypeDescription("Number"));
	NewTable.Columns.Add("UserMessages",   New TypeDescription("Array"));
	NewTable.Columns.Add("SessionNumber",  New TypeDescription("Number"));
	NewTable.Columns.Add("SessionStarted", New TypeDescription("Date"));
	NewTable.Indexes.Add("ID, Start");
	
	Return NewTable;
	
EndFunction

// Is intended for filling or updating the property structure of the settings that are 
// stored in the State structure of the Settings property.
//
// Parameters:
//  Settings - Undefined, Structure.
//
// Returns:
//  Structure - updated settings.
//
Function CheckSettings(Val Settings = Undefined)
	
	NewSettingsStructure = New Structure();
	// A flag that shows whether the session that runs scheduled jobs must be started
	// during the start of the client application, if it is allowed.
	NewSettingsStructure.Insert("AutomaticallyStartSeparateSessionForExecutingSchedledJobs",        False);
	// A flag that shows whether the user is notified when jobs are not executed or when
	// the job execution is not responding.
	NewSettingsStructure.Insert("NotifyAboutIncorrectScheduledJobExecution",                        False);
	// The notification period in minutes
	NewSettingsStructure.Insert("ScheduledJobErrorNotificationPeriod", 15);
	
	// Coping properties that are already filled
	If TypeOf(Settings) = Type("Structure") Then
		For Each KeyAndValue In NewSettingsStructure Do
			If Settings.Property(KeyAndValue.Key) Then
				If TypeOf(NewSettingsStructure[KeyAndValue.Key]) = TypeOf(Settings[KeyAndValue.Key]) Then
					NewSettingsStructure[KeyAndValue.Key] = Settings[KeyAndValue.Key];
				EndIf;
			EndIf;
		EndDo;
	EndIf;
	
	If Not (NewSettingsStructure.ScheduledJobErrorNotificationPeriod >= 1 And
	         NewSettingsStructure.ScheduledJobErrorNotificationPeriod <= 99 ) Then
	
		NewSettingsStructure.ScheduledJobErrorNotificationPeriod = 15;
	EndIf;
	
	Return NewSettingsStructure;
	
EndFunction

// Returns the structure that describes scheduled job execution states.
//
Function GetScheduledJobExecutionStates(Lock = False)
	
	// Preparing data for checking properties of the retrieved state or for their initial filling.
	NewStructure = New Structure();
	// Storing the background job execution history
	NewStructure.Insert("SessionNumber",             0);
	NewStructure.Insert("SessionStarted",            '00010101');
	NewStructure.Insert("ComputerName",              "");
	NewStructure.Insert("ApplicationName",           "");
	NewStructure.Insert("UserName",                  "");
	NewStructure.Insert("NextJobID",                 "");
	NewStructure.Insert("NextJobExecutionStartTime", '00010101');
	NewStructure.Insert("NextJobExecutionEndTime",   '00010101');
	
	State = CommonSettingsStorage.Load("ScheduledJobExecutionStates", , , "");
	State = ?(TypeOf(State) = Type("ValueStorage"), State.Get(), Undefined);
	
	// Coping properties that already filled
	If TypeOf(State) = Type(NewStructure) Then
		For Each KeyAndValue In NewStructure Do
			If State.Property(KeyAndValue.Key) Then
				If TypeOf(NewStructure[KeyAndValue.Key]) = TypeOf(State[KeyAndValue.Key]) Then
					NewStructure[KeyAndValue.Key] = State[KeyAndValue.Key];
				EndIf;
			EndIf;
		EndDo;
	EndIf;
	
	Return NewStructure;
	
EndFunction

// Stores the passed state into the ScheduledJobExecutionStates structure.
//
// Parameters:
//  State             - Structure - changed value of the GetScheduledJobExecutionStates
//                      function.
//  ChangedProperties - Undefined - state must be saved.
//                    - String    - comma-separated list of properties to be stored.<?xml:namespace prefix = o ns = "urn:schemas-microsoft-com:office:office" /><o:p></o:p>

//
Procedure SaveScheduledJobExecutionStates(State, Val ChangedProperties = Undefined)
	
	If ChangedProperties <> Undefined Then
		CurrentState = GetScheduledJobExecutionStates();
		FillPropertyValues(CurrentState, State, ChangedProperties);
		State = CurrentState;
	EndIf;
	
	CommonSettingsStorage.Save("ScheduledJobExecutionStates", , New ValueStorage(State), , "");
	
EndProcedure

// Executes the scheduled job in the file mode.
// Is used in the ExecuteScheduledJobs procedure.
// 
// Parameters:
//  State       - Structure.
//  Job         - ScheduledJob.
//  RunManually - Boolean.
//  StartedAt   - Undefined, Date - sets or returns the job start date and time.
//  FinishedAt  - Undefined, Date - returns the job end date and time.
//
// Returns: 
//  Boolean      - False means that the scheduled job procedure is being already 
//                 executed.
//
Function ExecuteScheduledJob(Val Job,
                             Val RunManually = False,
                             StartedAt = Undefined,
                             FinishedAt = Undefined,
                             SessionNumber = Undefined,
                             SessionStarted = Undefined)
	
	LastBackgroundJobProperties = GetLastBackgroundJobForScheduledJobExecutionProperties(Job);
	
	If LastBackgroundJobProperties <> Undefined
	   And LastBackgroundJobProperties.State = BackgroundJobState.Active Then
		
		SessionNumber  = LastBackgroundJobProperties.SessionNumber;
		SessionStarted = LastBackgroundJobProperties.SessionStarted;
		Return False;
	EndIf;
	
	MethodName = Job.Metadata.MethodName;
	BackgroundJobDescription = StringFunctionsClientServer.SubstituteParametersInString(
		?(RunManually,
		  NStr("en = 'Started manually: %1'"),
		  NStr("en = 'Autorun: %1'")),
		ScheduledJobPresentation(Job));
	
	StartedAt = ?(TypeOf(StartedAt) <> Type("Date") Or Not ValueIsFilled(StartedAt), CurrentSessionDate(), StartedAt);
	
	// Filling properties of a new background job
	BackgroundJobProperties = EmptyBackgroundJobPropertyTable().Add();
	BackgroundJobProperties.ID  = String(New UUID());
	BackgroundJobProperties.StartAttempt = ?(
		LastBackgroundJobProperties <> Undefined
		And LastBackgroundJobProperties.State = BackgroundJobState.Failed,
		LastBackgroundJobProperties.StartAttempt + 1,
		1);
	BackgroundJobProperties.Description    = BackgroundJobDescription;
	BackgroundJobProperties.ScheduledJobID = String(Job.UUID);
	BackgroundJobProperties.Placement      = "\\" + ComputerName();
	BackgroundJobProperties.MethodName     = MethodName;
	BackgroundJobProperties.State          = BackgroundJobState.Active;
	BackgroundJobProperties.Start          = StartedAt;
	BackgroundJobProperties.SessionNumber  = InfoBaseSessionNumber();
	
	For Each Session In GetInfoBaseSessions() Do
		If Session.SessionNumber = BackgroundJobProperties.SessionNumber Then
			BackgroundJobProperties.SessionStarted = Session.SessionStarted;
			Break;
		EndIf;
	EndDo;
	
	// Preparing a script to be executed instead of the background job
	ParameterString = "";
	Index = 0;
	While Index < Job.Parameters.Count() Do
		ParameterString = ParameterString + "Job.Parameters[" + Index + "]";
		If Index < (Job.Parameters.Count()-1) Then
			ParameterString = ParameterString + ",";
		EndIf;
		Index = Index + 1;
	EndDo;
	
	// Saving start time details
	ValueToStore = New ValueStorage(CommonUse.ValueTableRowToStructure(BackgroundJobProperties));
	CommonSettingsStorage.Save("ScheduledJobState_" + String(Job.UUID), , ValueToStore, , "");
	
	GetUserMessages(True);
	Try
		Execute("" + MethodName + "(" + ParameterString + ");");
		BackgroundJobProperties.State = BackgroundJobState.Completed;
	Except
		BackgroundJobProperties.State = BackgroundJobState.Failed;
		BackgroundJobProperties.ErrorDetails = DetailErrorDescription(ErrorInfo());
	EndTry;
	
	// Saving end time details
	FinishedAt = CurrentSessionDate();
	BackgroundJobProperties.End = FinishedAt;
	BackgroundJobProperties.UserMessages = New Array;
	For Each Message In GetUserMessages() Do
		BackgroundJobProperties.UserMessages.Add(Message);
	EndDo;
	GetUserMessages(True);
	
	Properties = CommonSettingsStorage.Load("ScheduledJobState_" + String(Job.UUID), , , "");
	Properties = ?(TypeOf(Properties) = Type("ValueStorage"), Properties.Get(), Undefined);
	
	If Properties.SessionNumber = BackgroundJobProperties.SessionNumber
	   And Properties.SessionStarted = BackgroundJobProperties.SessionStarted Then
		// SessionNumber and SessionStarted parameters are not overwritten, properties can be stored.
		ValueToStore = New ValueStorage(CommonUse.ValueTableRowToStructure(BackgroundJobProperties));
		CommonSettingsStorage.Save("ScheduledJobState_" + String(Job.UUID), , ValueToStore, , "");
	EndIf;
	
	Return True;
	
EndFunction

Procedure AddBackgroundJobProperties(Val BackgroundJobArray, Val BackgroundJobPropertyTable)
	
	Index = BackgroundJobArray.Count() - 1;
	While Index >= 0 Do
		BackgroundJob = BackgroundJobArray[Index];
		String = BackgroundJobPropertyTable.Add();
		FillPropertyValues(String, BackgroundJob);
		String.AtServer = True;
		String.ID = BackgroundJob.UUID;
		ScheduledJob = BackgroundJob.ScheduledJob;
		
		If ScheduledJob = Undefined
		   And StringFunctionsClientServer.IsUUID(BackgroundJob.Key) Then
			
			ScheduledJob = ScheduledJobs.FindByUUID(New UUID(BackgroundJob.Key));
		EndIf;
		String.ScheduledJobID = ?(
			ScheduledJob = Undefined,
			"",
			ScheduledJob.UUID);
		
		String.ErrorDetails = ?(
			BackgroundJob.ErrorInfo = Undefined,
			"",
			DetailErrorDescription(BackgroundJob.ErrorInfo));
		
		Index = Index - 1;
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Infobase update.

// The scheduled job execution settings update handler.
Procedure ConvertScheduledJobExecutionSettings_1_2_2_2() Export
	
	SetPrivilegedMode(True);
	
	Settings = CommonSettingsStorage.Load("ScheduledJobExecutionSettings", , , "");
	Settings = ?(TypeOf(Settings) = Type("ValueStorage"), Settings.Get(), Undefined);
	
	If Settings <> Undefined Then
		Settings = CheckSettings(Settings);
		Constants.ScheduledJobExecutionSettings.Set(Settings);
	EndIf;
	
	CommonSettingsStorage.Delete("ScheduledJobExecutionSettings", Undefined, "");
	
EndProcedure















