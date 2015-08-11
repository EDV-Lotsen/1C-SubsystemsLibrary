////////////////////////////////////////////////////////////////////////////////
// Scheduled jobs subsystem.
// 
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

// Notifies users about schedule job failures and background job hangs.
//
// Works only if the infobase runs in the file mode.
// If the infobase runs in the server mode, scheduled jobs are executed on the
// application server.
//
//  Is attached in the ScheduledJobsClient.OnStart procedure.
//
Procedure NotifyAboutIncorrectScheduledJobExecution() Export

	NotificationPeriod = Undefined; // in minutes
	If ScheduledJobsServer.NotifyAboutScheduledJobExecutionErrors(NotificationPeriod) Then
		ErrorDescription = "";
		JobsExecutedCorrectly = Undefined;
		ScheduledJobsServer.CurrentSessionPerformsScheduledJobs(JobsExecutedCorrectly, , ErrorDescription);
		If Not JobsExecutedCorrectly Then
			ScheduledJobsClient.OnScheduledJobExecutionError(ErrorDescription);
		EndIf;
		AttachIdleHandler("NotifyAboutIncorrectScheduledJobExecution", NotificationPeriod * 60, True);
	EndIf;

EndProcedure

// Executes next scheduled job in the main session.
//
// Is called from the idle handler that is attached in the ScheduledJobsClient.OnStart
// procedure.
//
// If you want to execute a scheduled job in a separate session, use 
// DataProcessors.ScheduledAndBackgroundJobs.Form.ScheduledJobExecution instead.
//
Procedure ScheduledJobExecutionInMainSession() Export

	If ScheduledJobsServer.CurrentSessionPerformsScheduledJobs() Then
		ScheduledJobsServer.ExecuteScheduledJobs();
		AttachIdleHandler("ScheduledJobExecutionInMainSession", 60, True);
	EndIf;
	
EndProcedure

Procedure StartSeparateSessionToExecuteScheduledJobsViaIdleHandler() Export
	
	Result = ScheduledJobsClient.StartSeparateSessionToExecuteScheduledJobs();
	
	If Result.Cancel Then
		ShowMessageBox(,Result.ErrorDescription);
		
	ElsIf Result.TriedToOpen Then
		
		AttachIdleHandler("ActivateCurrentSessionMainWindowAfterStartingSeparateSessionForExecutingScheduleJobs", 2, True);
	EndIf;
	
EndProcedure

Procedure ActivateCurrentSessionMainWindowAfterStartingSeparateSessionForExecutingScheduleJobs() Export
	
	MainWindow = ScheduledJobsClient.MainWindow();
	If MainWindow <> Undefined Then
		MainWindow.Activate();
	EndIf;
	
EndProcedure







