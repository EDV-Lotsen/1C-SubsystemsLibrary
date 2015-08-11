////////////////////////////////////////////////////////////////////////////////
// Base functionality subsystem.
//
//////////////////////////////////////////////////////////////////////////////// 

////////////////////////////////////////////////////////////////////////////////
// INTERFACE

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
	
	//// StandardSubsystems.InfoBaseBackup
	//InfoBaseBackupClient.OnExit(Warnings);	
	//// End StandardSubsystems.InfoBaseBackup
	
	//// StandardSubsystems.FileOperations
	//FileOperationsClient.OnExit(Warnings);
	//// End StandardSubsystems.FileOperations

EndProcedure

// Is called if there is a need to open the active user lists form,
// Active users are users that are working with the application at this time.
//
// Implementation example:
// - One could use the ActiveUsers handler form at UserSessions subsystem deployment:
// OpenForm("DataProcessor.ActiveUsers.Form.ActiveUsersListForm");
//
Procedure OpenActiveUserList() Export
	
	// StandardSubsystems.UserSessions
	OpenForm("DataProcessor.ActiveUsers.Form.ActiveUsersListForm");
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
	
	//// StandardSubsystems.ServiceMode.SuppliedData
	//Return SuppliedDataClientServer.RefreshItemFromCommonData(Form);
	//// End StandardSubsystems.ServiceMode.SuppliedData
	
EndFunction

// Askes a user about a common data update rejection.
// Changes item state if the user answer is Yes.
Procedure ChangeSeparatedItem(Val Form) Export
	
	//// StandardSubsystems.ServiceMode.SuppliedData
	//SuppliedDataClientServer.ChangeSeparatedItem(Form);
	//// End StandardSubsystems.ServiceMode.SuppliedData
	
EndProcedure

Function CurrencyClassifierChoiceFormName() Export
	
	// StandardSubsystems.ServiceMode.CurrenciesServiceMode
	Return "Catalog.CurrencyClassifier.ChoiceForm";
	// End StandardSubsystems.ServiceMode.CurrenciesServiceMode
	
	Raise(NStr("en = 'Currencies (service mode) subsystem is not available'"))
	
EndFunction