////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// Returns the 1C:Cloud technology library version.
//
// Returns: String - library version in RR.{S|SS}.VV.BB format.
//
Function LibVersion() Export
	
	Return "1.0.2.21";
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// INTERNAL INTERFACE

// See the description of this procedure in the StandardSubsystemsServer module.
Procedure InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers) Export
	
	// SERVER HANDLERS
	
	ServerHandlers["StandardSubsystems.BaseFunctionality\OnEnableSeparationByDataAreas"].Add(
		"CloudTechnology");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// SL event handlers

// Called when enabling data separation by data area.
//
Procedure OnEnableSeparationByDataAreas() Export
	
	CheckCanUseConfigurationSaaS();
	
EndProcedure

// Adds update handler procedures required by the subsystem to the Handlers list.
//
// Parameters:
//   Handlers - ValueTable - see the description of NewUpdateHandlerTable function 
//                           in the InfobaseUpdate common module.
// 
Procedure RegisterUpdateHandlers(Handlers) Export
	
	If CommonUseCached.DataSeparationEnabled() Then
		
		Handler = Handlers.Add();
		Handler.Version = "*";
		Handler.Procedure = "CloudTechnology.CheckCanUseConfigurationSaaS";
		Handler.SharedData = True;
		Handler.ExecuteInMandatoryGroup = True;
		Handler.Priority = 99;
		Handler.ExclusiveMode = False;
		
	EndIf;
	
EndProcedure

// "True" internal interface

// Called when setting session parameters.
//
// Parameters:
//  SessionParameterNames - Array, Undefined.
//
Procedure ExecuteActionsOnSessionParametersSetting(Parameters) Export
	
	If CTLAndSLIntegration.SubsystemExists("CloudTechnology.SaaSOperations.UsersSaaS") Then
		
		ModuleUsersInternalSaaSCTL = CTLAndSLIntegration.CommonModule("UsersInternalSaaSCTL");
		ModuleUsersInternalSaaSCTL.OnSetSessionSettings(Parameters);
		
	EndIf;
	
EndProcedure

// Checks whether the configuration can be used SaaS.
// If it cannot be used SaaS, generates an exception and elaborates why it cannot be used SaaS.
//
Procedure CheckCanUseConfigurationSaaS() Export
	
	SubsystemDescriptions = StandardSubsystemsCached.SubsystemDescriptions().ByNames;
	SLDescription = SubsystemDescriptions.Get("StandardSubsystems");
	
	If SLDescription = Undefined Then
		
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = '1C:Subsystems library is not embedded.
                  |The configuration cannot be used SaaS unless the library is embedded.
                  |
                  |In order to use this configuration SaaS, 1C:Subsystems library 
                  |version %1 or later must be embedded.'", 
Metadata.DefaultLanguage.LanguageCode),
			RequiredSLVersion());
		
	Else
		
		SLVersion = SLDescription.Version;
		
		If CommonUseClientServer.CompareVersions(SLVersion, RequiredSLVersion()) < 0 Then
			
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'In order to use this configuration SaaS with
                      |the current version of 1C:Cloud technology library,
                      |1C:Subsystems library version must be updated.
                      |
                      |Version in use: %1, required at least %2.'", 
Metadata.DefaultLanguage.LanguageCode),
				SLVersion, RequiredSLVersion());
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Internal procedures and functions

// Returns the earliest supported 1C:Subsystems library version.
//
// Returns: String - library version in RR.{S|SS}.VV.BB format.
//
Function RequiredSLVersion()
	
	Return "2.2.1.26";
	
EndFunction