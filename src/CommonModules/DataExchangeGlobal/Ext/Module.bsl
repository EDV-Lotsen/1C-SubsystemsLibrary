////////////////////////////////////////////////////////////////////////////////
// Data exchange subsystem
//
////////////////////////////////////////////////////////////////////////////////

#Region InternalProceduresAndFunctions

// Checks whether subordinate node configuration update is required.
//
Procedure CheckSubordinateNodeConfigurationUpdateRequired() Export
	
	UpdateRequired = StandardSubsystemsClientCached.ClientParameters().DIBNodeConfigurationUpdateRequired;
	CheckUpdateRequired(UpdateRequired);
	
EndProcedure

// Checks whether subordinate node configuration update is required.
// The check is performed during application startup.
//
Procedure CheckSubordinateNodeConfigurationUpdateRequiredOnStart() Export
	
	UpdateRequired = StandardSubsystemsClientCached.ClientParametersOnStart().DIBNodeConfigurationUpdateRequired;
	CheckUpdateRequired(UpdateRequired);
	
EndProcedure

Procedure CheckUpdateRequired(DIBNodeConfigurationUpdateRequired)
	
	If DIBNodeConfigurationUpdateRequired Then
		Explanation = NStr("en = 'Received update from %1.
			|Data synchronization will be continued after the application update will be set.'");
		Explanation = StringFunctionsClientServer.SubstituteParametersInString(Explanation, StandardSubsystemsClientCached.ClientParameters().MasterNode);
		ShowUserNotification(NStr("en = 'Install the update'"), "e1cib/app/DataProcessor.DataExchangeExecution",
			Explanation, PictureLib.Warning32);
		Notify("DataExchangeCompleted");
	EndIf;
	
	AttachIdleHandler("CheckSubordinateNodeConfigurationUpdateRequired", 60 * 60, True); // every hour
	
EndProcedure

#EndRegion
