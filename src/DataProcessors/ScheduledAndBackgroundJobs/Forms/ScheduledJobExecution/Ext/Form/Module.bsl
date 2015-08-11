

&AtClient
Var LeftToExecutionStart; // The time (in seconds) left till the next scheduled job
                          // execution check.


////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	ExecutionCheckInterval = 5; // 5 seconds
	UpdateScheduledJobTable();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	LeftToExecutionStart =  ExecutionCheckInterval + 1;  
	ExecuteScheduledJobs();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure ScheduledJobExecutionSetup(Command)
	
	FormParameters = New Structure("HideSeparateSessionStartCommand", True);
	
	OpenForm(
		"DataProcessor.ScheduledAndBackgroundJobs.Form.ScheduledJobExecutionSetup",
		FormParameters,,,,, Undefined, FormWindowOpeningMode.LockWholeInterface);
	
EndProcedure

&AtClient
Procedure StopExecutionAndTerminateSession(Command)
	
	StopExecutionAndTerminateSessionExecute();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

&AtClient
Procedure  StopExecutionAndTerminateSessionExecute()
	
	Close();
	
EndProcedure

&AtClient
Procedure ExecuteScheduledJobs()
	
	LeftToExecutionStart =  LeftToExecutionStart - 1;
	If LeftToExecutionStart <= 0 Then
		
		LeftToExecutionStart =  ExecutionCheckInterval;
		Items.StateString.Title  = NStr("en = 'Scheduled jobs are being executed...'");
		RefreshDataRepresentation();
		
		Result = ExecuteScheduledJobsServer(LaunchParameter);
		If Result.StopExecution Then
			Close(?(Result.Restart, "Restart", Undefined));
		EndIf;
	EndIf;

	
	// Terminating the job execution if the user pressed Ctrl+Break.
	AttachIdleHandler(
		"StopExecutionAndTerminateSessionExecute", 1, True);
	
	UserInterruptProcessing();
	
	DetachIdleHandler(
		"StopExecutionAndTerminateSessionExecute");
	
	AttachIdleHandler("ExecuteScheduledJobs", 1, True);
	Items.StateString.Title = NStr("en = 'Waiting for scheduled job completion...'");
	
EndProcedure

&AtServer
Function ExecuteScheduledJobsServer(LaunchParameter)
	
	ScheduledJobsServer.ExecuteScheduledJobs();
	UpdateScheduledJobTable();
	
	Result = New Structure;
	Result.Insert("Restart", DataBaseConfigurationChangedDynamically());
	Result.Insert(
		"StopExecution",
		Result.Restart
		Or ScheduledJobsServer.IsParentSessionSetAndClosed(LaunchParameter)
		Or Not ScheduledJobsServer.CurrentSessionPerformsScheduledJobs() );
	
	Return Result;
	
EndFunction

&AtServer
Procedure UpdateScheduledJobTable()

	SetPrivilegedMode(True);
	CurrentJobs = ScheduledJobs.GetScheduledJobs(New Structure("Use", True));
	
	NewJobTable = FormAttributeToValue("ScheduledJobTable");
	NewJobTable.Clear();
	
	
For Each Job In CurrentJobs Do
		JobString = NewJobTable.Add();
		
		JobString.ScheduledJob = ScheduledJobsServer.ScheduledJobPresentation(Job);
		JobString.Completed = Date(1, 1, 1);
		JobString.ID = Job.UUID;
		
		LastBackgroundJobProperties =  ScheduledJobsServer.GetLastBackgroundJobForScheduledJobExecutionProperties(Job);
		
		If LastBackgroundJobProperties <> Undefined
		   And ValueIsFilled(LastBackgroundJobProperties.End) Then
			
			JobString.Completed =  LastBackgroundJobProperties.End;
		EndIf;
		
		JobProperties = ScheduledJobTable.FindRows(
			New Structure("ID", JobString.ID));
		
		JobString.Changed = (JobProperties = Undefined)
		                 Or (JobProperties.Count() =  0) 
		                 Or (JobProperties[0].Completed <> JobString.Completed);
	EndDo;
	
	NewJobTable.Sort("ScheduledJob");
	
	JobNumber = 1;
	For Each JobRow In NewJobTable Do
		JobRow.Number =  JobNumber;
		JobNumber = JobNumber + 1;
	EndDo;
	
	ValueToFormAttribute(NewJobTable, "ScheduledJobTable");
	
EndProcedure







