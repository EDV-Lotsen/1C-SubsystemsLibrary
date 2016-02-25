////////////////////////////////////////////////////////////////////////////////
// File functions subsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region InternalProceduresAndFunctions

// Returns a form that informs users about locking and editing files in the web client.
//
Function GetReminderOnEditForm() Export
	
	Return GetForm("CommonForm.ReminderOnEdit");
	
EndFunction

// Returns a structure that contains various personal settings.
Function PersonalFileOperationSettings() Export
	
	PersonalSettings = StandardSubsystemsClientCached.ClientParameters(
		).PersonalFileOperationSettings;
	
	// Checking and updating the settings that are stored on the server
	// and calculated on the client.
	
	Return PersonalSettings;
	
EndFunction

// Returns a structure that contains various personal settings.
Function CommonFileOperationSettings() Export
	
	CommonSettings = StandardSubsystemsClientCached.ClientParameters(
		).CommonFileOperationSettings;
	
	// Checking and updating the settings that are stored on the server
	// and calculated on the client.
	
	Return CommonSettings;
	
EndFunction

// Returns PutToUserWorkingDirectory session parameter.
Function UserWorkingDirectory() Export
	
	DirectoryName = StandardSubsystemsClientCached.ClientParameters(
		).PersonalFileOperationSettings.PathToLocalFileCache;
	
	// Already set
	If DirectoryName <> Undefined
	   And Not IsBlankString(DirectoryName)
	   And AccessToWorkingDirectoryCheckExecuted = True Then
		
		Return DirectoryName;
	EndIf;
	
	If DirectoryName = Undefined Then
		DirectoryName = FileFunctionsInternalClient.SelectPathToUserDataDirectory();
		If Not IsBlankString(DirectoryName) Then
			FileFunctionsInternalClient.SetUserWorkingDirectory(DirectoryName);
		Else
			AccessToWorkingDirectoryCheckExecuted = True;
			Return ""; // Web client without file system extension
		EndIf;
	EndIf;
	
#If Not WebClient Then
	
	// Creating file directory
	Try
		CreateDirectory(DirectoryName);
		TestDirectoryName = DirectoryName + "CheckAccess\";
		CreateDirectory(TestDirectoryName);
		DeleteFiles(TestDirectoryName);
	Except
		// The path does not exist or not enough rights to create a directory,
		// using the default settings.
		DirectoryName = FileFunctionsInternalClient.SelectPathToUserDataDirectory();
		FileFunctionsInternalClient.SetUserWorkingDirectory(DirectoryName);
	EndTry;
	
#EndIf
	
	AccessToWorkingDirectoryCheckExecuted = True;
	
	Return DirectoryName;
	
EndFunction

#EndRegion
