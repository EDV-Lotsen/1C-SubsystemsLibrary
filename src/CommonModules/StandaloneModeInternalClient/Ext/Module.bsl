////////////////////////////////////////////////////////////////////////////////
// Data exchange SaaS subsystem.
// 
////////////////////////////////////////////////////////////////////////////////

#Region InternalProceduresAndFunctions

// Checks standalone workstation setup and generates a notification if an
// error occurs.
Procedure BeforeStart(Parameters) Export
	
	ClientParameters = StandardSubsystemsClientCached.ClientParametersOnStart();
	
	If ClientParameters.Property("RestartAfterStandaloneWorkstationSetup") Then
		Parameters.Cancel = True;
		Parameters.Restart = True;
		Return;
	EndIf;
	
	If Not ClientParameters.Property("StandaloneWorkstationSetupError") Then
		Return;
	EndIf;
	
	Parameters.Cancel = True;
	Parameters.InteractiveHandler = New NotifyDescription(
		"OnCheckStandaloneWorkstationSetupInteractiveHandler", ThisObject);
	
EndProcedure

///////////////////////////////////////////////////////////////////////////////
// Notification handlers.

// Notifies about a standalone workstation setup error.
Procedure OnCheckStandaloneWorkstationSetupInteractiveHandler(Parameters, NotDefined) Export
	
	ClientParameters = StandardSubsystemsClientCached.ClientParametersOnStart();
	
	StandardSubsystemsClient.ShowMessageBoxAndContinue(
		Parameters, ClientParameters.StandaloneWorkstationSetupError);
	
EndProcedure

#EndRegion
