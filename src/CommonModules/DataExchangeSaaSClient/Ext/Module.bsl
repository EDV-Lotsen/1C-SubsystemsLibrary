////////////////////////////////////////////////////////////////////////////////
// Data exchange SaaS subsystem.
// 
////////////////////////////////////////////////////////////////////////////////

#Region InternalInterface

// Client application session startup handler.
// If the current session is a standalone workstation session, the procedure
// notifies a user that data synchronization with a web application is
// required (provided that the appropriate flag is set).
//
Procedure OnStart(Parameters) Export
	
	ClientParameters = StandardSubsystemsClientCached.ClientParametersOnStart();
	
	If ClientParameters.DataSeparationEnabled Then
		Return;
	EndIf;
	
	If ClientParameters.IsStandaloneWorkstation Then
		
		SuggestDataSynchronizationWithWebApplicationOnExit =
			ClientParameters.SynchronizeDataWithWebApplicationOnExit;
		
		If ClientParameters.SynchronizeDataWithWebApplicationOnStart Then
			
			ShowUserNotification(NStr("en = 'Standalone mode'"), "e1cib/app/Processing.DataExchangeExecution",
				NStr("en = 'It is recommended that you synchronize your local data with the web application.'"), PictureLib.Information32);
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Fills the list of warnings displayed to users. 
// The procedure is called when a user exits the application.  
//
// Parameters:
// see OnGetExitWarningList.
//
Procedure OnExit(Warnings) Export
	
	StandaloneModeParameters = StandardSubsystemsClient.ClientParametersOnExit().StandaloneModeParameters;
	If SuggestDataSynchronizationWithWebApplicationOnExit = True
		And StandaloneModeParameters.SynchronizationWithServiceNotExecuteLongTime Then
		
		WarningParameters = StandardSubsystemsClient.ExitWarning();
		WarningParameters.ExtendedTooltip = NStr("en = 'In some cases data synchronization can take a long time. This includes:
         | - low bandwidth
         | - large amount of data
         | - application update is available on the Internet'");  

		WarningParameters.CheckBoxText = NStr("en = 'Synchronize data with the web application'");
		WarningParameters.Priority = 80;
		
		ActionIfMarked = WarningParameters.ActionIfMarked;
		ActionIfMarked.Form = "DataProcessor.DataExchangeExecution.Form.Form";
		
		FormParameters = StandaloneModeParameters.DataExchangeExecutionFormParameters;
		FormParameters = CommonUseClientServer.CopyStructure(FormParameters);
		FormParameters.Insert("ExitApplication", True);
		ActionIfMarked.FormParameters = FormParameters;
		
		Warnings.Add(WarningParameters);
	EndIf;
	
EndProcedure
////////////////////////////////////////////////////////////////////////////////
// Internal event handlers of SL subsystems

// Redefines the list of warnings displayed to a user before they exit the
// application.
//
// Parameters:
//  Warnings - Array - array element type is Structure,
//                     the structure properties are listed in
//                     StandardSubsystemsClient.ExitWarning.
//
Procedure OnGetExitWarningList(Warnings) Export
	
	OnExit(Warnings);
	
EndProcedure

#EndRegion
