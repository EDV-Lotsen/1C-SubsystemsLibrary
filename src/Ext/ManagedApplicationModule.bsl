
// StandardSubsystems

// ConfigurationUpdate

// Information of available configuration update, found on Internet
// on program start.
Var AvailableConfigurationUpdate Export;
// ValueList for accumulation of messages into eventlog,
// generated in client business-logics of the subsystem.
Var MessagesForEventLog Export; 
// Structure with parameters of configuration update wizard.
Var ConfigurationUpdateOptions Export; 

// End ConfigurationUpdate

// FileOperations
Var TwainComponent Export;		// Twain component for work with scanner
// End FileOperations

// End StandardSubsystems

Procedure BeforeStart(Cancellation) 
	
	// StandardSubsystems
	
	// Users
	If ValueIsFilled(StandardSubsystemsClientSecondUse.ClientParameters().AuthorizationError) Then
		
		DoMessageBox(StandardSubsystemsClientSecondUse.ClientParameters().AuthorizationError);
		Cancellation = True;
		Return;
		
	EndIf;
	// End Users
	
	// InfobaseVersionUpdate
	Cancellation = Cancellation OR NOT InfobaseUpdateClient.RunningInfobaseUpdatePermitted();
	// End InfobaseVersionUpdate
	
	// End StandardSubsystems
	
EndProcedure

Procedure OnStart()
	
	// StandardSubsystems
	CommonUseClient.SetArbitraryApplicationTitle();
	
	// UpdateLegalityCheck
	If NOT UpdateLegalityCheckClient.ConfirmLegalityOfUpdateObtaining() Then
		Return;
	EndIf;
	// End UpdateLegalityCheck
	
	// InfobaseVersionUpdate
	InfobaseUpdateClient.RunInfobaseUpdate();
	// End InfobaseVersionUpdate
	
	// process system start parameters
	If ProcessStartParameters(LaunchParameter) Then
		Return;
	EndIf;
	
	// UserSessionTermination
	InfobaseConnectionsClient.SetMonitorUserSessionTerminationMode();
	// End UserSessionTermination
	
	// ScheduledJobs
	// Note : subsystem DynamicUpdateMonitoring
	//        should be configured after subsystem ScheduledJobs, cause in the mode of start
	//        separate session of scheduled jobs, control will not be shared with this session.
	ScheduledJobsClient.OnStart();
	// End ScheduledJobs
	
	// DynamicUpdateMonitoring
	DynamicUpdateMonitoringClient.OnStart();
	// End DynamicUpdateMonitoring
	
	// End StandardSubsystems
	
EndProcedure

// Process program start parameter.
// Function implementation can be extended to handle new parameters.
//
// Parameters:
//  LaunchParameter  – String – start parameter, passed into configuartion
//                              using command line parameter /C.
//
// Value returned:
//   Boolean   – True, if it is required to abort execution of procedure OnStart.
//
Function ProcessStartParameters(Val LaunchParameter)
	
	Var Result;
	Result = False;
	
	// StandardSubsystems
	
	// If start parameters exist
	If IsBlankString(LaunchParameter) Then
		Return Result;
	EndIf;
	
	// Parameter can consist of parts, splited by char ";".
	// First part - main value of start parameter.
	// Availability of other parts is defined by logics of main parameter processing.
	LaunchParameters = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(LaunchParameter, ";");
	StartParameterValue = Upper(LaunchParameters[0]);
	
	// UserSessionTermination
	Result = InfobaseConnectionsClient.ProcessStartParameters(StartParameterValue, LaunchParameters);
	// End UserSessionTermination
	
	// End StandardSubsystems
	
	// Configuration code
		// ...
	// End Configuration code
	
	// StandardSubsystems
	Return Result;
	// End StandardSubsystems
	
EndFunction
