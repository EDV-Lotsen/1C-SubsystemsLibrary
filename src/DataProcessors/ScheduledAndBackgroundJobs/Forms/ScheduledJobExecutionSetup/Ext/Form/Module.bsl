////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	If Not CommonUse.FileInfoBase() Then
		Cancel = True;
	EndIf;
	
	Settings = ScheduledJobsServer.GetScheduledJobExecutionSettings();
	FillPropertyValues(ThisForm, Settings);
	
	If Not Users.InfoBaseUserWithFullAccess(, True) Then
		Items.AutomaticallyStartSeparateSessionForExecutingSchedledJobs.Enabled = False;
	EndIf;
	
	Items.StartSeparateSessionToExecuteScheduledJobs.Visible
		= Not Parameters.HideSeparateSessionStartCommand;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	CommonUseClient.RequestCloseFormConfirmation(Cancel, Modified);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS

&AtClient
Procedure ScheduledJobErrorNotificationPeriodOnChange(Item)
	
	If ScheduledJobErrorNotificationPeriod <= 0 Then
		ScheduledJobErrorNotificationPeriod = 1;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure Write(Command)
	
	
WriteChanges();
	
EndProcedure

&AtClient
Procedure WriteAndCloseExecute()
	
	WriteChanges();
	Close();
	
EndProcedure

&AtClient
Procedure  StartSeparateSessionToExecuteScheduledJobs(Command)
	
	AttachIdleHandler(
		"StartSeparateSessionToExecuteScheduledJobsViaIdleHandler",
		1,
		True);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

&AtClient
Procedure WriteChanges()
	
	WriteChangesAtServer();
	Modified = False;
	
	ScheduledJobsClient.DisableGlobalIdleHandler(
		"NotifyAboutIncorrectScheduledJobExecution");
	
	If NotifyAboutIncorrectScheduledJobExecution Then
		
		ScheduledJobsClient.AttachGlobalIdleHandler(
			"NotifyAboutIncorrectScheduledJobExecution",
			ScheduledJobErrorNotificationPeriod * 60,
			True);
	EndIf;
	
EndProcedure

&AtServer
Procedure WriteChangesAtServer()
	
	Settings = ScheduledJobsServer.GetScheduledJobExecutionSettings();
	
	If Users.InfoBaseUserWithFullAccess(, True) Then
		FillPropertyValues(Settings, ThisForm);
	Else
		FillPropertyValues(
			Settings,
			ThisForm,
			,
			"AutomaticallyStartSeparateSessionForExecutingSchedledJobs");
	EndIf;
	
	ScheduledJobsServer.SetScheduledJobExecutionSettings(Settings);
	FillPropertyValues(ThisForm, Settings);
	
EndProcedure







