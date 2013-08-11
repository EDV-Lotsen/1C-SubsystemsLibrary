///////////////////////////////////////////////////////////////////////////////////
// JobQueueCached: Procedures and functions for working with shared scheduled jobs.
//
///////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

// Returns a list of methods that are allowed to be called with the job queue mechanism.
//
// Returns:
// Array - array of method names that are allowed to be called with the job queue mechanism.
//
Function GetAllowedMethods() Export
	
	AllowedMethods = New Array;
	StandardSubsystemsOverridable.GetJobQueueAllowedMethods(AllowedMethods);
	JobQueueOverridable.GetJobQueueAllowedMethods(AllowedMethods);
	
	For Each ScheduledJobMetadata In Metadata.ScheduledJobs Do
		AllowedMethods.Add(ScheduledJobMetadata.MethodName);
	EndDo;
	
	Result = New Array;
	For Each MethodName In AllowedMethods Do
		Result.Add(Upper(MethodName));
	EndDo;
	
	Return New FixedArray(Result);
	
EndFunction
