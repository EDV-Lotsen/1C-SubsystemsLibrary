////////////////////////////////////////////////////////////////////////////////
// Scheduled jobs subsystem.
// 
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// Returns the scheduled job use.
//  Before calling, it is required to have the right to Administer or SetPrivilegedMode.
//
// Parameters:
//  ID - MetadataObject - a scheduled job metadata object
//                  for searching the predefined scheduled job.
//                - UUID - the scheduled job ID.
//                - String - the scheduled job unique ID string.
//                - ScheduledJob - the scheduled job.
//
// Returns:
//  Boolean - if True, the scheduled job is used.
// 
Function GetScheduledJobUse(Val ID) Export
	
	ScheduledJobsInternal.RaiseIfNoAdministrationRights();
	SetPrivilegedMode(True);
	
	Job = GetScheduledJob(ID);
	
	Return Job.Use;
	
EndFunction

// Sets the use of the scheduled job.
//  Before calling, it is required to have the right to Administer or SetPrivilegedMode.
//
// Parameters:
//  ID - MetadataObject - a scheduled job metadata object
//                  for searching the predefined scheduled job.
//                - UUID - the scheduled job ID.
//                - String - the scheduled job unique ID string.
//                - ScheduledJob - the scheduled job.
//
// Use  - Boolean - the use value to be installed.
// 
Procedure SetUseScheduledJob(Val ID, Val Use) Export
	
	ScheduledJobsInternal.RaiseIfNoAdministrationRights();
	SetPrivilegedMode(True);
	
	Job = GetScheduledJob(ID);
	
	If Job.Use <> Use Then
		Job.Use = Use;
	EndIf;
	
	Job.Write();
	
EndProcedure

// Returns the scheduled job schedule.
//  Before calling, it is required to have the right to Administer or SetPrivilegedMode.
// 
// Parameters:
//  ID - MetadataObject - a scheduled job metadata object
//                  for searching the predefined scheduled job.
//                - UUID - the scheduled job ID.
//                - String - the scheduled job unique ID string.
//                - ScheduledJob - the scheduled job.
// 
//  InStructure    - Boolean - if True, then the schedule
//                  will be transformed into a structure that you can pass to the client.
// 
// Returns:
//  JobSchedule, Structure - the structure contains the same properties as the schedule.
// 
Function GetJobSchedule(Val ID, Val InStructure = False) Export
	
	ScheduledJobsInternal.RaiseIfNoAdministrationRights();
	SetPrivilegedMode(True);
	
	Job = GetScheduledJob(ID);
	
	If InStructure Then
		Return CommonUseClientServer.ScheduleToStructure(Job.Schedule);
	EndIf;
	
	Return Job.Schedule;
	
EndFunction

// Sets the scheduled job schedule.
//  Before calling, it is required to have the right to Administer or SetPrivilegedMode.
//
// Parameters:
//  ID - MetadataObject - a scheduled job metadata object
//                  for searching the predefined scheduled job.
//                - UUID - the scheduled job ID.
//                - String - the scheduled job unique ID string.
//                - ScheduledJob - the scheduled job.
//
//  Schedule      - JobSchedule - the schedule.
//                - Structure - the value returned
//                  by the ScheduleToStructure function of the CommonUseClientServer 
//                  common module.
// 
Procedure SetJobSchedule(Val ID, Val Schedule) Export
	
	ScheduledJobsInternal.RaiseIfNoAdministrationRights();
	SetPrivilegedMode(True);
	
	Job = GetScheduledJob(ID);
	
	If TypeOf(Schedule) = Type("JobSchedule") Then
		Job.Schedule = Schedule;
	Else
		Job.Schedule = CommonUseClientServer.StructureToSchedule(Schedule);
	EndIf;
	
	Job.Write();
	
EndProcedure

// Returns ScheduledJob from the infobase.
// 
// Parameters:
//  ID - MetadataObject - a scheduled job metadata object
//                  for searching the predefined scheduled job.
//                - UUID - the scheduled job ID.
//                - String - the scheduled job unique ID string.
//                - ScheduledJob - a scheduled job from which you need to get 
//                  the unique ID for getting a fresh copy of the scheduled job.
// 
// Returns:
//  ScheduledJob - read from the database.
//
Function GetScheduledJob(Val ID) Export
	
 
	ScheduledJobsInternal.RaiseIfNoAdministrationRights();
	SetPrivilegedMode(True);
	
	If TypeOf(ID) = Type("ScheduledJob") Then
		ID = ID.UUID;
	EndIf;
	
	If TypeOf(ID) = Type("String") Then
		ID = New UUID(ID);
	EndIf;
	
	If TypeOf(ID) = Type("MetadataObject") Then
		ScheduledJob = ScheduledJobs.FindPredefined(ID);
	Else
		ScheduledJob = ScheduledJobs.FindByUUID(ID);
	EndIf;
	
	If ScheduledJob = Undefined Then
		Raise( NStr("en = 'The scheduled job is not found.
		                              |It may have been deleted by another user.'") );
	EndIf;
	
	Return ScheduledJob;
	
EndFunction

#EndRegion
