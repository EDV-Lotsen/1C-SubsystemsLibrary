
////////////////////////////////////////////////////////////////////////////////
// Data exchange subsystem.
// 
///////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// Is called when the user clicks the Done button in the data exchange creation wizard.
//
// Parameters:
//  Wizard          - Managed form, Ordinary form - data exchange creation wizard form 
//                    that initiates the event.
//  StartJobManager - Boolean - flag that shows whether the job manager (separate
//                    application session) must be started for performing background
//                    and scheduled jobs when application runs in the file mode.
//                    True is passed to this parameter it the user specified a schedule 
//                    in the wizard and application runs in the file mode.
//                    If the application runs in the client/server mode, the passed
//                    value is always False.
//
Procedure OnExchangeCreationWizardExit(Wizard, StartJobManager) Export
	
	// StandardSubsystems.ScheduledJobs
	If StartJobManager Then
		StartSeparateSessionToExecuteScheduledJobsViaIdleHandler();
	EndIf;
	// End StandardSubsystems.ScheduledJobs
	
EndProcedure
