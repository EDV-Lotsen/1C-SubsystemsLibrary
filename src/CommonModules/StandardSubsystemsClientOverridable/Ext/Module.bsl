////////////////////////////////////////////////////////////////////////////////
// Base functionality subsystem.
//
//////////////////////////////////////////////////////////////////////////////// 

////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// Сorresponds to the OnStart handler
//
// Parameters
// ProcessLaunchParameters - Boolean - True if the handler is called on 
// a direct application launch and it should process launch parameters
// (if its logic specifies such processing). False if the handler is called on 
// a shared user interactive logon to a data area and it 
// should not processes launch parameters.
//
Procedure OnStart(Val ProcessLaunchParameters = False) Export
	
	If InfoBaseUpdate.FirstRun() Then
		
		CommonUse.SetInfoBaseSeparationParameters(False);
		
	EndIf;
	
	StandardSubsystemsClient.SetAdvancedApplicationTitle();
	
	
	// StandardSubsystems.DataExchange
	If Not DataExchangeClient.CheckExchangeMessageWithConfigurationChangesForSubordinateNodeImport() Then
		Return;
	EndIf;
	// End StandardSubsystems.DataExchange
	
	// StandardSubsystems.InfoBaseVersionUpdate
	InfoBaseUpdateClient.ExecuteInfoBaseUpdate();
	
	InfoBaseUpdateClient.ShowUpdateDetails();
	// End StandardSubsystems.InfoBaseVersionUpdate
	
	// Processing application launch parameter 
	If ProcessLaunchParameters Then
		If ProcessLaunchParameters() Then
			Return;
		EndIf;
	EndIf;
	
	// StandardSubsystems.UserSessions
	InfoBaseConnectionsClient.OnStart();
	// End StandardSubsystems.UserSessions
	
	// StandardSubsystems.DataExchange
	DataExchangeClient.OnStart();
	// End StandardSubsystems.DataExchange
	
	// StandardSubsystems.ScheduledJobs
	// Note: The DynamicConfigurationUpdateControl subsystem 
	// should be set up after the ScheduledJobs subsystem because the Dynamic Update 
	// handler uses scheduled jobs during its work.
	ScheduledJobsClient.OnStart();
	// End StandardSubsystems.ScheduledJobs
	
EndProcedure

// Shows if there is a necessity to process application launch parameters.
// A function implementation could be expanded for processing of new parameters.
//
// Parameters
// LaunchParameter – String – launch parameter passed in the сonfiguration 
// using the command string /C key.
//
// Returns:
// Boolean – True if it is necessary to break OnStart handler execution.
//
Function ProcessLaunchParameters()

	Var Result;
	
	Result = False;
	
	// StandardSubsystems
	
	// If there are any launch parameters
	If IsBlankString(LaunchParameter) Then
		Return Result;
	EndIf;
	
	// The parameter can consist of parts separated by the ; symbol.
	// First part is a launch parameter main value. 
	// Main parameter pricessing logic defines if there are any additional parts.
	RunParameters = StringFunctionsClientServer.SplitStringIntoSubstringArray(LaunchParameter, ";");
	LaunchParameterValue = Upper(RunParameters[0]);
	
	// StandardSubsystems.UserSessions
	Result = InfoBaseConnectionsClient.ProcessLaunchParameters(LaunchParameterValue, RunParameters);
	// End StandardSubsystems.UserSessions

	// End StandardSubsystems
	
	// Configuration script
	// ...
	// End configuration script

	
	// StandardSubsystems
	Return Result;
	// End StandardSubsystems

EndFunction

// Is executed before interactive work with the data area start.
// Corresponds to the BeforeStart handler.
//
// Parameters:
// Cancel - Boolean - Cancel run. If this parameter is set to True
// the work with area will not be started.
//
Procedure BeforeStart(Cancel) Export
	
	// StandardSubsystems
	
	// StandardSubsystems.Users
	AuthorizationError = StandardSubsystemsClientCached.ClientParametersOnStart().AuthorizationError;
	If ValueIsFilled(AuthorizationError) Then
		DoMessageBox(AuthorizationError);
		Cancel = True;
		Return;
	EndIf;
	// End StandardSubsystems.Users
	
	StandardSubsystemsClient.SetAdvancedApplicationTitle();
	IsActualVersion = StandardSubsystemsClient.CheckPlatformVersionAtStart("BeforeStart");
	If Not IsActualVersion Then 
		Cancel = True;
		Return;
	EndIf;
	
	// StandardSubsystems.UserSessions
	InfoBaseConnectionsClient.BeforeStart(Cancel);
	If Cancel Then
		Return;
	EndIf;
	// End StandardSubsystems.UserSessions
	
	// StandardSubsystems.InfoBaseVersionUpdate
	Cancel = Not InfoBaseUpdateClient.CanExecuteInfoBaseUpdate();
	// End StandardSubsystems.InfoBaseVersionUpdate
	
	// End StandardSubsystems
	
EndProcedure

// Corresponds to the BeforeExit handler
//
Procedure BeforeExit(Cancel) Export
	
	If CommonUseCached.CanUseSeparatedData() Then
		StandardSubsystemsClient.OpenOnExitMessageForm(Cancel);
	EndIf;
	
EndProcedure

/////////////////////////////////////////////////////////////////////////////////
//Base functionality
//


// Is called on exit to get warning list to be displayed to a user.
// 
//
// Parameters:
//	Warnings - Array - warning list. Each of array items is a structure with following fields:
//		CheckBoxText - String - check box text.
//		InformationText - String - displayed on the form above the control (check box or hyperlink) text. 
//		ActionIfMarked - structure with following fields:
//			Form - path to the open form.
//			FormParameters - Any parameter structure for the open form. 
//		HyperlinkText - String - hyperlink text.
//		ActionOnHyperlinkClick - structure with following fields:
//			Form - String - path to the form that should be opened on a hyperlink click.
//			FormParameters - Structure - any parameter structure for the described aboved form.
//			ApplicationWarningForm - String - path to the form that shoud be opened instead of 
//				the universal forms if there is only one warning in the warning list.
//			ApplicationWarningFormParameters - Structure - any parameter structure for the described aboved form.
//
Procedure GetWarningList(Warnings) Export
	
EndProcedure

// Is called if there is a need to open the active user lists form,
// Active users are users that are working with the application at this time.
//
// Implementation example:
// - One could use the ActiveUsers handler form at UserSessions subsystem deployment:
// OpenForm("DataProcessor.ActiveUsers.Form.ActiveUserListForm");
//
Procedure OpenActiveUserList() Export
	
	// StandardSubsystems.UserSessions
	OpenForm("DataProcessor.ActiveUsers.Form.ActiveUserListForm");
	// End StandardSubsystems.UserSessions
	
EndProcedure

// Gets a minimum required platform version.
//
//
// Parameters: CheckParameters - FixedStructure - field list is the same as the 
//																						StandardSubsystemsClient.CheckPlatformVersion() function parameter list.
//			
Procedure GetMinRequiredPlatformVersion(CheckParameters) Export
	
		
EndProcedure	

/////////////////////////////////////////////////////////////////////////////////
// Supplied data

// Asks a user about a shared data update.
// Returns True if the user answer is Yes.
// 
Function RefreshItemFromCommonData(Val Form) Export
	
	// StandardSubsystems.ServiceMode.SuppliedData
	Return SuppliedDataClientServer.RefreshItemFromCommonData(Form);
	// End StandardSubsystems.ServiceMode.SuppliedData
	
EndFunction

// Askes a user about a common data update rejection.
// Changes item state if the user answer is Yes.
Procedure ChangeSeparatedItem(Val Form) Export
	
	// StandardSubsystems.ServiceMode.SuppliedData
	SuppliedDataClientServer.ChangeSeparatedItem(Form);
	// End StandardSubsystems.ServiceMode.SuppliedData
	
EndProcedure

Function CurrencyClassifierChoiceFormName() Export
	
	// StandardSubsystems.ServiceMode.CurrenciesServiceMode
	Return "Catalog.CurrencyClassifier.ChoiceForm";
	// End StandardSubsystems.ServiceMode.CurrenciesServiceMode
	
	Raise(NStr("en = 'Currencies (service mode) subsystem is not available'"))
	
EndFunction