///////////////////////////////////////////////////////////////////////////////////
// JobQueueOverridable: Unseparated scheduled job management.
//
///////////////////////////////////////////////////////////////////////////////////

#Region InternalProceduresAndFunctions

// Generates a list of templates for queued jobs.
//
// Parameters:
//  Templates - Array of String The parameter should include
//   names of predefined unseparated scheduled jobs to be
//   used as queue job templates.
//
Procedure OnReceiveTemplateList(Templates) Export
	
EndProcedure

// Fills a map of method names and their aliases for calling from a job queue
//
// Parameters:
//  NameAndAliasMap - Map
//   Key   - Method alias, example: ClearDataArea
//   Value - method name, example: SaaSOperations.ClearDataArea. You can pass Undefined if the
//           name is identical to the alias.
//
Procedure OnDefineHandlerAliases(NameAndAliasMap) Export
	
EndProcedure

// Sets correspondence between error handler methods and
// aliases of methods where errors occurred.
//
// Parameters:
//  ErrorHandlers - Map
//   Key - method alias, example: ClearDataArea
//   Value - Method name - error handler, called upon error. 
//    The error handler is called whenever a job execution fails. The error handler 
//    is always called in the data area of the failed job.
//    The error handler method can be called by the queue mechanisms. 
//    Error handler parameters:
//     JobParameters - Structure - queue job parameters
//      Parameters
//      AttemptNumber
//      RestartCountOnFailure
//      LastLaunchBeginDate
//
Procedure OnDefineErrorHandlers(ErrorHandlers) Export
	
EndProcedure

// Generates a scheduled job table with flags 
// that show whether a job is used in SaaS
//
// Parameters:
// UsageTable - ValueTable - table to be filled with scheduled jobs 
// with SaaS usage flag. Columns:
//  ScheduledJob - String - predefined scheduled job name.
//  Use - Boolean - True if the scheduled job must be executed in SaaS mode. 
//   False - otherwise.
//
Procedure OnDetermineScheduledJobsUsed(UsageTable) Export
	
EndProcedure

// Obsolete. We recommend that you use OnReceiveTemplateList().
//
Procedure FillSeparatedScheduledJobList(SeparatedScheduledJobList) Export
	
EndProcedure

// Obsolete. We recommend that you use OnDefineHandlerAliases().
//
Procedure GetJobQueueAllowedMethods(Val AllowedMethods) Export
	
EndProcedure

#EndRegion
