
// StandardSubsystems

// StandardSubsystems.BaseFunctionality

// ValueList for accumulating a message package generated in the client business logic 
// for the event log.
Var MessagesForEventLog Export; 
// Flag that shows whether the file system installation must be suggested in the current session.
Var SuggestFileSystemExtensionInstallation Export;
// Flag that shows whether the standard exit confirmation required in the current session.
Var SkipExitConfirmation Export;

// End StandardSubsystems.BaseFunctionality

// StandardSubsystems.UserSessions
Var SessionTerminationInProgress Export;
// End StandardSubsystems.UserSessions
		
// StandardSubsystems.ConfigurationUpdate

// Flag that shows whether a configuration update is found on the Internet
Var AvailableConfigurationUpdate Export;
// Structure with configuration update wizard parameters
Var ConfigurationUpdateSettings Export; 

// End StandardSubsystems.ConfigurationUpdate

// StandardSubsystems.FileOperations
Var TwainAddIn Export; // Twain component for working with scanners
// End StandardSubsystems.FileOperations

// StandardSubsystems.FileFunctions
// Flag that shows whether access to the working directory is checked
Var AccessToWorkingDirectoryCheckExecuted Export;
// End StandardSubsystems.FileFunctions

// StandardSubsystems.InfoBaseBackup

// Parameters for backups
Var InfoBaseBackupParameters Export;
// Flag that shows whether a backup is performed once the session is terminated
Var NotifyAboutBackupOnExit Export;
// Date of the deferred backup 
Var DeferredBackupDate Export;

// End StandardSubsystems.InfoBaseBackup

// StandardSubsystems.PerformanceEstimation
Var PerformanceEstimationTimeMeasurement Export;
// End StandardSubsystems.PerformanceEstimation

// End StandardSubsystems

Procedure BeforeStart(Cancel)
	
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
