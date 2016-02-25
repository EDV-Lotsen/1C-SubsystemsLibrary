///////////////////////////////////////////////////////////////////////////////////
// SaaSOperationsClient.
//
////////////////////////////////////////////////////////////////////////////////

#Region InternalProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// SL subsystem event handlers

// Is called before user starts interaction with the data area.
// Corresponds to the BeforeStart event of application modules.
//
Procedure BeforeStart(Parameters) Export
	
	ClientParameters = StandardSubsystemsClientCached.ClientParametersOnStart();
	
	If ClientParameters.Property("DataAreaLocked") Then
		Parameters.Cancel = True;
		Parameters.InteractiveHandler = New NotifyDescription(
			"ShowMessageBoxAndContinue",
			StandardSubsystemsClient.ThisObject,
			ClientParameters.DataAreaLocked);
		Return;
	EndIf;
	
EndProcedure

#EndRegion
