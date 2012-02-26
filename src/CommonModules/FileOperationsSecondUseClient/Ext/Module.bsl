
////////////////////////////////////////////////////////////////////////////////
// MODULE CONTAINS AUXILIARY FUNCTIONS AND PROCEDURES FOR OPERATION WITH FILES
//
//

// Returns structure, containing distinct personal settings
Function GetFileOperationsPersonalSettings() Export
	Return StandardSubsystemsClientSecondUse.ClientParameters().FileOperationsPersonalSettings;
EndFunction	
	
// Returns form, which is used when new file is being created
// for a choice of creation variant
Function GetChoiceNewItemFormFileCreateVariant() Export
	CommandScanAvailable = WorkWithScannerClient.CommandScanAvailable();
	
	FormParameters = New Structure("CommandScanAvailable", CommandScanAvailable);
	Return GetForm("Catalog.Files.Form.NewItemForm", FormParameters);
EndFunction

// Returns session parameter UserWorkingDirectoryPath
Function GetSessionParameterWorkingDirectory() Export
	Return FileOperations.SessionParametersUserWorkingDirectoryPath();
EndFunction

// Returns form, which is used for showing messages
// to users about features of files edit and taking
// in web-client
Function GetTipsOnEditForm() Export
	Return GetForm("Catalog.Files.Form.ReminderFormBeforeEdit");
EndFunction

// Returns form, which is used for showing messages
// users about specifics of file return in web-client
Function GetTipsBeforePlaceFileForm() Export
	Return GetForm("Catalog.Files.Form.ReminderFormBeforePlacingFile");
EndFunction

// Returns form, that is used for return edited content
// file at server
Function GetFileReturnForm() Export
	Return GetForm("Catalog.Files.Form.FileReturnFormat");
EndFunction
