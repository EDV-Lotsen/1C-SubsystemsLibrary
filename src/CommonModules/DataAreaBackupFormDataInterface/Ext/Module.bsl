////////////////////////////////////////////////////////////////////////////////
// Data area backup subsystem.
//  
////////////////////////////////////////////////////////////////////////////////

#Region InternalProceduresAndFunctions

Function GetSettingsFormParameters(Val DataArea) Export
	
	Parameters = Implementation().GetSettingsFormParameters(DataArea);
	Parameters.Insert("DataArea", DataArea);
	
	Return Parameters;
	
EndFunction

Function GetAreaSettings(Val DataArea) Export
	
	Return Implementation().GetAreaSettings(DataArea);
	
EndFunction

Procedure SetAreaSettings(Val DataArea, Val NewSettings, Val InitialSettings) Export
	
	Implementation().SetAreaSettings(DataArea, NewSettings, InitialSettings);
	
EndProcedure

Function GetStandardSettings() Export
	
	Return Implementation().GetStandardSettings();
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// AUXILIARY PROCEDURES AND FUNCTIONS

Function Implementation()
	
	If CommonUse.SubsystemExists("StandardSubsystems.SMDataAreaBackup") Then
		Return CommonUse.CommonModule("DataAreaBackupFormDataImplementationInfobase");
	Else
		Return CommonUse.CommonModule("DataAreaBackupFormDataImplementationWebService");
	EndIf;
	
EndFunction

#EndRegion
