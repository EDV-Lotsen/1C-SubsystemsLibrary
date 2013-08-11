///////////////////////////////////////////////////////////////////////////////////
// JobQueueOverridable: Procedures and functions for working with shared scheduled jobs.
//
///////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

// Fills a list of shared schedule jobs that must be executed in the separated mode.
//
// Parameters:
// SeparatedScheduledJobList - Array - array of shared schedule jobs to be executed with
// the Schedule jobs subsystem mechanism in data areas.
//
Procedure FillSeparatedScheduledJobList(SeparatedScheduledJobList) Export

	
	
EndProcedure

// Generates a scheduled job table that contains usage flags.
//
// Parameters:
// UsageTable - ValueTable - table to be filled with scheduled jobs and usage flags.
//
Procedure FillScheduledJobUsageTable(UsageTable) Export
	
	// StandardSubsystems.ScheduledJobs
	NewRow = UsageTable.Add();
	NewRow.ScheduledJob = "JobProcessingPlanning";
	NewRow.Use = True;
	// End StandardSubsystems.ScheduledJobs
	
EndProcedure

// Returns a list of methods that are allowed to be called with the job queue mechanism.
//
// Returns:
// Array - array of method names that are allowed to be called with the job queue mechanism.
//
Procedure GetJobQueueAllowedMethods(Val AllowedMethods) Export
	
	
	
EndProcedure
