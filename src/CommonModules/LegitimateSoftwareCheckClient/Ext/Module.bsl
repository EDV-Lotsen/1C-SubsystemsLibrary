////////////////////////////////////////////////////////////////////////////////
// Legitimate software check subsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// Asks the user to confirm that the update was received legally and shuts down system 
// work if the update was received illegally (see. parameter TerminateApplication).
//
// Parameters:
//  TerminateApplication - Boolean - shut down system work if the user confirmed that the 
//                                 update was received illegally.
//
// Returns:
//   Boolean - True if the check is done(the user confirmed that the update was 
//             received legally).
//
Procedure ShowLegitimateSoftwareCheck(Notification, 
TerminateApplication = False) Export
	
	If StandardSubsystemsClientCached.ClientParameters().IsBaseConfigurationVersion Then
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("ShowRestartWarning", TerminateApplication);
	FormParameters.Insert("OpenedProgrammatically", True);
	
	OpenForm("DataProcessor.LegitimateSoftware.Form", FormParameters,,,,, Notification);
	
EndProcedure

#EndRegion

#Region InternalInterface

// Validate legitimate software on the application start.
// Should be called before updating the infobase.
//
Procedure CheckInfobaseUpdatedLegallyOnStart(Parameters) Export
	
	ClientParameters = StandardSubsystemsClientCached.ClientParametersOnStart();
	
	If Not ClientParameters.Property("CheckLegitimateSoftware") Then
		Return;
	EndIf;
	
	Parameters.InteractiveHandler = New NotifyDescription(
		"LegitimateSoftwareCheckInteractiveHandler", ThisObject);
	
EndProcedure

// For internal use only. Continues the execution of CheckLegitimateSoftwareOnStart procedure.
Procedure LegitimateSoftwareCheckInteractiveHandler(Parameters, NotDefined) Export
	
	FormParameters = New Structure;
	FormParameters.Insert("OpenedProgrammatically", True);
	FormParameters.Insert("ShowRestartWarning", True);
	FormParameters.Insert("IgnoreRestart", True);
	
	OpenForm("DataProcessor.LegitimateSoftware.Form", FormParameters, , , , ,
		New NotifyDescription("AfterCloseLegitimateSoftwareFormOnStart",
			ThisObject, Parameters));
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

// For internal use only. Continues the execution of CheckLegitimateSoftwareOnStart procedure..
Procedure AfterCloseLegitimateSoftwareFormOnStart(Result, Parameters) Export
	
	If Result <> True Then
		Parameters.Cancel = True;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationHandler);
	
EndProcedure

#EndRegion
