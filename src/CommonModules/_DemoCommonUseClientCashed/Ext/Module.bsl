
////////////////////////////////////////////////////////////////////////////////
// Client procedures of common use

// Returns session parameter SuggestWorkWithFilesExtensionInstallationByDefault
Function GetOfferInstallationOfExtensionOfWorkWithFiles() Export
	Return _DemoCommonUse.SessionParametersSuggestWorkWithFilesExtensionInstallationByDefault();
EndFunction

// Returns True, if this web client does not support extension of work with files
Function ThisIsWebClientWithoutSupportOfWorkWithFilesExtension() Export
	
	SystemInformation = New SystemInfo;
	
	If Find(SystemInformation.UserAgentInformation, "Safari") <> 0 Then
		Return True;
	EndIf;
	
	If Find(SystemInformation.UserAgentInformation, "Chrome") <> 0 Then
		Return True;
	EndIf;
	
	Return False;
	
EndFunction
