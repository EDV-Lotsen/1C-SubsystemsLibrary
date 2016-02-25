////////////////////////////////////////////////////////////////////////
// This module supports the common settings repository

// Load attaching settings of the scanner driver from the settings storage.
// 
// Parameters: 
//  OSType – String – the type of the operating system.  (IN)
// 
// Returns: 
//  Structure, containing parameters of the scanner attachment
Function LoadScannerAttachingParameters(OSType) Export

	If OSType = "Windows" Then
		
		Return CommonSettingsStorage.Load("CurrentScannerSettingsWindows");
		
	ElsIf OSType = "Linux" Then
	
		Return CommonSettingsStorage.Load("CurrentScannerSettingsLinux");
		
	EndIf;

EndFunction

// Get directory used for storing the local files
// Returns: 
//  A string containing the directory
Function GetWorkingDirectory() Export

	Return CommonSettingsStorage.Load("UserWorkingDirectory");

EndFunction

// Save directory used For the location of local files
// Parameters: 
//  A string containing the Directory
Procedure SaveWorkingDirectory(Directory) Export
	
	CommonSettingsStorage.Save("UserWorkingDirectory",,Directory);	

EndProcedure

// Get the string, which will be uset as a short aplications Title
Function GetShortApplicationTitleText() Export

	ShortCaption = CommonSettingsStorage.Load("ShortApplicationCaption");
	Return ?(ShortCaption = Undefined, "", ShortCaption);

EndFunction

// Saving a string, which is set as a short application Title
Procedure SaveTextHeaderApplicationsSummary(CaptionString) Export

	CommonSettingsStorage.Save("ShortApplicationCaption", , CaptionString);

EndProcedure
