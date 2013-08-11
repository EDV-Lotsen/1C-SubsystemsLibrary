
////////////////////////////////////////////////////////////////////////////////
// Scheduled jobs subsystem.
// 
/////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// Starts a new session that will perform scheduled jobs.
// Is used only for thin and ordinary clients (The web client is not supported).
//
// Returns:
//  Structure with the following fields:
//   Cancel           - Boolean.
//   ErrorDescription - String.
// 
Function StartSeparateSessionToExecuteScheduledJobs() Export
                                                          
	Parameters = ScheduledJobsServer.ScheduledJobExecutionSeparateSessionLaunchParameters(False);
	
	If Not Parameters.Cancel And Parameters.RequiredSeparateSessionStart Then
		TryStartSeparateSessionForScheduledJobsExecution(Parameters);
	EndIf;
	
	Return Parameters;
	
EndFunction

// Returns a job schedule by ID.
// 
// Parameters:
//  ID - scheduled job UUID string.
// 
// Returns:
//  JobSchedule.
//
Function GetJobSchedule(Val ID) Export
	
	Return CommonUseClientServer.StructureToSchedule(ScheduledJobsServer.GetJobScheduleInStructure(ID));
	
EndFunction

// Sets the job scheduled by ID.
//
// Parameters:
//  ID       - scheduled job UUID string.
//  Schedule - JobSchedule.
//
Procedure SetJobSchedule(Val ID, Val Schedule) Export
	
	ScheduledJobsServer.SetJobScheduleFromStructure(ID, CommonUseClientServer.ScheduleToStructure(Schedule));
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

// The OnStart event handler.
// Is called for performing actions required for the ScheduledJobs subsystem.
//
Procedure OnStart() Export
	
	If Not CommonUseCached.CanUseSeparatedData()
		Or CommonUseCached.DataSeparationEnabled() Then
		
		Return;
	EndIf;
	
	If Find(LaunchParameter, "ExecuteScheduledJobs") <> 0 Then
		Warn = (Find(LaunchParameter, "IgnoreWarnings") =  0);
		SeparateSession = (Find(LaunchParameter, "SeparateSession") <> 0);
		#If WebClient Then
			SkipExitConfirmation = True;
			Exit(False);
		#EndIf
		If StandardSubsystemsClientCached.ClientParameters().FileInfoBase Then
			JobsExecutedCorrectly = Undefined;
			ErrorDescription = "";
			If ScheduledJobsServer.CurrentSessionPerformsScheduledJobs(JobsExecutedCorrectly, True, ErrorDescription) Then
				SetApplicationCaption(StringFunctionsClientServer.SubstituteParametersInString(NStr("en = 'Executing scheduled jobs: %1'"),
				                                                                                      GetApplicationCaption() ));
				If SeparateSession Then
					// Executing in a separate session
					MainWindow = MainWindow();
	
					FromApplication = (Find(LaunchParameter, "FromApplication") <> 0); 
					ParametersToForm = New Structure("LabelTitle", 
						?(FromApplication, NStr("en = 'The session will be automatically terminated when you exit the base session.'"), ""));
					
					If MainWindow = Undefined Then
						OpenForm("DataProcessor.ScheduledAndBackgroundJobs.Form.SeparateScheduledJobExecutionSessionDesktop",ParametersToForm );
					Else
						OpenForm("DataProcessor.ScheduledAndBackgroundJobs.Form.SeparateScheduledJobExecutionSessionDesktop",ParametersToForm,,, MainWindow);
					EndIf;

					If OpenFormModal("DataProcessor.ScheduledAndBackgroundJobs.Form.ScheduledJobExecution") = "Restart" Then
						SkipExitConfirmation = True;
						Exit(False, True, " /C""" + LaunchParameter + """");
					EndIf;
					SkipExitConfirmation = True;
					Exit(False);
				Else
					// Executing in this session
					AttachIdleHandler("ScheduledJobExecutionInMainSession", 1, True);
				EndIf;
			Else
				If Warn Then
					
					If JobsExecutedCorrectly Then
						MessageText = NStr("en = 'The session that performs scheduled jobs is already started.'");
					Else
						MessageText = StringFunctionsClientServer.SubstituteParametersInString(
							NStr("en = 'The session that performs scheduled jobs is already started.'
								| 
								|%1'"), ErrorDescription);
						DoMessageBox(MessageText);
					EndIf;
				EndIf;
				If SeparateSession Then
					SkipExitConfirmation = True;
					Exit(False);
				EndIf;
			EndIf;
		Else
			If Warn Then
				DoMessageBox(NStr("en = 'Scheduled jobs are executed on the server.'"));
			EndIf;
			If SeparateSession Then
				SkipExitConfirmation = True;
				Exit(False);
			EndIf;
		EndIf;
		
	ElsIf StandardSubsystemsClientCached.ClientParameters().FileInfoBase Then
		
		ParametersReadOnly = StandardSubsystemsClientCached.ClientParameters().ScheduledJobExecutionSeparateSessionLaunchParameters;
		
		If ParametersReadOnly.Cancel Then
			OnScheduledJobExecutionError(ParametersReadOnly.ErrorDescription);
		ElsIf ParametersReadOnly.RequiredSeparateSessionStart Then
			AttachIdleHandler("StartSeparateSessionToExecuteScheduledJobsViaIdleHandler", 1, True);
		EndIf;
		
		If ParametersReadOnly.NotifyAboutIncorrectExecution Then
			AttachIdleHandler("NotifyAboutIncorrectScheduledJobExecution", ParametersReadOnly.NotificationPeriod * 60, True);
		EndIf;
	EndIf;
	
EndProcedure

// Attempts to start a new session that will handle scheduled jobs.
//
// Parameters:
//  Parameters    - Structure with the following fields:
//                  AdditionalCommandLineOptions - String.
//                  Cancel                       - Boolean - output parameter.
//                  ErrorDescription             - String - output parameter.
// 
Procedure TryStartSeparateSessionForScheduledJobsExecution(Val Parameters) Export
	
	#If Not WebClient Then
		Try
			Parameters.TriedToOpen = True;
			RunSystem(
				?(Find(Upper(LaunchParameter), "/DEBUG") = 0, "", "/DEBUG ")
				+ Parameters.AdditionalCommandLineOptions);
		Except
			Parameters.ErrorDescription = ErrorDescription();
			Parameters.Cancel = True;
		EndTry;
	#Else
		Parameters.Cancel = True;
		Parameters.ErrorDescription = NStr("en = 'Scheduled jobs cannot be executed in a separate web client session.
			|
			|If you want scheduled jobs to be executed, an administrator must set up thin or
			|ordinary client run on the web server.'");
	#EndIf
	Parameters.ErrorDescription =
		?(IsBlankString(Parameters.ErrorDescription),
		  "",
		  StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Error starting the session for executing scheduled jobs:
				           |
				           |%1'"),
				Parameters.ErrorDescription));
	
EndProcedure

// Notifies the user about the scheduled job execution error.
//
// Is called from the ScheduledJobsGlobal.NotifyAboutIncorrectScheduledJobExecution and
// ScheduledJobsClient.OnStart procedures.
//
// Is call if there is no scheduled job execution session or this session hangs.
//
// Parameters:
//  ErrorDescription - String.
//
Procedure OnScheduledJobExecutionError(ErrorDescription) Export
	
	If StandardSubsystemsClientCached.ClientParameters().ScheduledJobExecutionSeparateSessionLaunchParameters.CurrentUserAdministrator Then
		ShowUserNotification(
				NStr("en = 'Scheduled jobs are not executed.'"),
				"e1cib/app/DataProcessor.ScheduledAndBackgroundJobs",
				ErrorDescription,
				PictureLib.ErrorExecutingScheduledJobs);
	Else
		ShowUserNotification(
				NStr("en = 'Scheduled jobs are not executed.'"),
				,
				ErrorDescription + Chars.LF + NStr("en = 'Please contact your infobase administrator.'"),
				PictureLib.ErrorExecutingScheduledJobs);
	EndIf;
	
EndProcedure

// Attaches the global idle handler on the form.
Procedure AttachGlobalIdleHandler(ProcedureName, Interval, Once = False) Export
	
	AttachIdleHandler(ProcedureName, Interval, Once);
	
EndProcedure

// Detaches the global idle handler on the form
Procedure DisableGlobalIdleHandler(ProcedureName) Export
	
	DetachIdleHandler(ProcedureName);
	
EndProcedure

Function MainWindow() Export
	
	MainWindow = Undefined;
	
	Windows = GetWindows();
	If Windows <> Undefined Then
		For Each Window In Windows Do
			If Window.IsMain Then
				MainWindow = Window;
				Break;
			EndIf;
		EndDo;
	EndIf;
	
	Return MainWindow;
	
EndFunction
