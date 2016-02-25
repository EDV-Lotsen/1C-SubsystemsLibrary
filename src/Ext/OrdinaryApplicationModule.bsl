
// StandardSubsystems

// StandardSubsystems.BaseFunctionality

// ValueList for accumulating a message package generated in the client business logic 
// for the event log.
Var MessagesForEventLog Export; 
// Flag that shows whether the file system installation must be suggested in the current session.
Var SuggestFileSystemExtensionInstallation Export;
// Flag that shows whether the standard exit confirmation required in the current session.
Var SkipExitConfirmation Export;
// Parameter structure used when starting and exiting the application.
Var ParametersOnApplicationStartAndExit Export;
// Form closure confirmation parameter structure.
Var FormClosingConfirmationParameters Export;
// External resource request confirmation notification.
Var NotificationOnExternalResourceRequestApply Export;
 
// End StandardSubsystems.BaseFunctionality

// StandardSubsystems.UserSessions
Var UserSessionTerminationParameters Export;
// End StandardSubsystems.UserSessions
		
// StandardSubsystems.ConfigurationUpdate

// Flag that shows whether a configuration update is found on the Internet
Var AvailableConfigurationUpdate Export;
// Structure with configuration update wizard parameters
Var ConfigurationUpdateSettings Export; 
// Flag that shows whether the infobase configuration must be updated when exiting the session.
Var SuggestInfobaseUpdateOnExitSession Export;
// End StandardSubsystems.ConfigurationUpdate

// StandardSubsystems.FileOperations
Var TwainAddIn Export; // Twain component for working with scanners
// End StandardSubsystems.FileOperations

// StandardSubsystems.FileFunctions
// Flag that shows whether access to the working directory is checked
Var AccessToWorkingDirectoryCheckExecuted Export;
// End StandardSubsystems.FileFunctions

// StandardSubsystems.InfobaseBackup

// Parameters for backups
Var InfobaseBackupParameters Export;
// End StandardSubsystems.InfobaseBackup

// StandardSubsystems.PerformanceMonitor
Var PerformanceMonitorTimeMeasurement Export;
// End StandardSubsystems.PerformanceMonitor
 
// StandardSubsystems.SaaSOperations.DataExchangeSaaS
Var SuggestDataSynchronizationWithWebApplicationOnExit Export;
// End StandardSubsystems.SaaSOperations.DataExchangeSaaS

// End StandardSubsystems

Procedure BeforeStart()
	
	// StandardSubsystems
	StandardSubsystemsClient.BeforeStart();
	// End StandardSubsystems
	
EndProcedure

Procedure OnStart()
	
	// StandardSubsystems
	StandardSubsystemsClient.OnStart();
	// End StandardSubsystems
	
EndProcedure

Procedure BeforeExit(Cancel)
	
	// StandardSubsystems
	StandardSubsystemsClient.BeforeExit(Cancel);
	// End StandardSubsystems
	
EndProcedure
