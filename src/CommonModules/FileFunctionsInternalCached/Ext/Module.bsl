////////////////////////////////////////////////////////////////////////////////
// File functions subsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region InternalProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Common and personal file operation settings

// Returns a structure that contains CommonSettings and PersonalSettings.
Function FileOperationSettings() Export
	
	CommonSettings        = New Structure;
	PersonalSettings = New Structure;
	
	FileFunctionsInternal.OnAddFileOperationSettings(
		CommonSettings, PersonalSettings);
	
	AddFileOperationSettings(CommonSettings, PersonalSettings);
	
	Settings = New Structure;
	Settings.Insert("CommonSettings",        CommonSettings);
	Settings.Insert("PersonalSettings", PersonalSettings);
	
	Return Settings;
	
EndFunction

// Sets common and personal file function settings.
Procedure AddFileOperationSettings(CommonSettings, PersonalSettings)
	
	SetPrivilegedMode(True);
	
	// Filling common settings
	
	// ExtractFileTextsAtServer
	CommonSettings.Insert(
		"ExtractFileTextsAtServer", FileFunctionsInternal.ExtractFileTextsAtServer());
	
	// MaxFileSize
	CommonSettings.Insert("MaxFileSize", FileFunctions.MaxFileSize());
	
	// ProhibitImportFilesByExtension
	ProhibitImportFilesByExtension = Constants.ProhibitImportFilesByExtension.Get();
	If ProhibitImportFilesByExtension = Undefined Then
		ProhibitImportFilesByExtension = False;
		Constants.ProhibitImportFilesByExtension.Set(ProhibitImportFilesByExtension);
	EndIf;
	CommonSettings.Insert("ProhibitImportFilesByExtension", ProhibitImportFilesByExtension);
	
	// ProhibitedFileExtensionList
	CommonSettings.Insert("ProhibitedFileExtensionList", ProhibitedFileExtensionList());
	
	// OpenDocumentFileExtensionList
	CommonSettings.Insert("OpenDocumentFileExtensionList", OpenDocumentFileExtensionList());
	
	// TextFileExtensionList
	CommonSettings.Insert("TextFileExtensionList", TextFileExtensionList());
	
	// Filling personal settings
	
	// MaxLocalFileCacheSize
	MaxLocalFileCacheSize = CommonUse.CommonSettingsStorageLoad(
		"LocalFileCache", "MaxLocalFileCacheSize");
	
	If MaxLocalFileCacheSize = Undefined Then
		MaxLocalFileCacheSize = 100*1024*1024; // 100 MB
		
		CommonUse.CommonSettingsStorageSave(
			"LocalFileCache",
			"MaxLocalFileCacheSize",
			MaxLocalFileCacheSize);
	EndIf;
	
	PersonalSettings.Insert(
		"MaxLocalFileCacheSize",
		MaxLocalFileCacheSize);
	
	// PathToLocalFileCache
	PathToLocalFileCache = CommonUse.CommonSettingsStorageLoad(
		"LocalFileCache", "PathToLocalFileCache");
	// Do not get this variable directly.
	// Use the UserWorkingDirectory function
	// of the FileFunctionsInternalClient module.
	PersonalSettings.Insert("PathToLocalFileCache", PathToLocalFileCache);
	
	// DeleteFileFromLocalFileCacheOnEditEnd
	DeleteFileFromLocalFileCacheOnEditEnd =
		CommonUse.CommonSettingsStorageLoad(
			"LocalFileCache", "DeleteFileFromLocalFileCacheOnEditEnd");
	
	If DeleteFileFromLocalFileCacheOnEditEnd = Undefined Then
		DeleteFileFromLocalFileCacheOnEditEnd = False;
	EndIf;
	
	PersonalSettings.Insert(
		"DeleteFileFromLocalFileCacheOnEditEnd",
		DeleteFileFromLocalFileCacheOnEditEnd);
	
	// ConfirmOnDeleteFromLocalFileCache
	ConfirmOnDeleteFromLocalFileCache =
		CommonUse.CommonSettingsStorageLoad(
			"LocalFileCache", "ConfirmOnDeleteFromLocalFileCache");
	
	If ConfirmOnDeleteFromLocalFileCache = Undefined Then
		ConfirmOnDeleteFromLocalFileCache = False;
	EndIf;
	
	PersonalSettings.Insert(
		"ConfirmOnDeleteFromLocalFileCache",
		ConfirmOnDeleteFromLocalFileCache);
	
	// ShowFileEditTips
	ShowFileEditTips = CommonUse.CommonSettingsStorageLoad(
		"ProgramSettings", "ShowFileEditTips");
	
	If ShowFileEditTips = Undefined Then
		ShowFileEditTips = True;
		
		CommonUse.CommonSettingsStorageSave(
			"ProgramSettings",
			"ShowFileEditTips",
			ShowFileEditTips);
	EndIf;
	PersonalSettings.Insert(
		"ShowFileEditTips",
		ShowFileEditTips);
	
	// PersonalCertificateThumbprintForEncryption
	//PARTIALLY_DELETED
	//DSSettings = DigitalSignatureClientServer.PersonalSettings();
	
	//PARTIALLY_DELETED
	//PersonalSettings.Insert(
	//	"PersonalCertificateThumbprintForEncryption",
	//	DSSettings.PersonalCertificateThumbprintForEncryption);	
	PersonalSettings.Insert(
		"PersonalCertificateThumbprintForEncryption",
		Undefined);
	
	// ShowFileNotChangedMessage
	ShowFileNotChangedMessage = CommonUse.CommonSettingsStorageLoad(
		"ProgramSettings", "ShowFileNotChangedMessage");
	
	If ShowFileNotChangedMessage = Undefined Then
		ShowFileNotChangedMessage = True;
		
		CommonUse.CommonSettingsStorageSave(
			"ProgramSettings",
			"ShowFileNotChangedMessage",
			ShowFileNotChangedMessage);
	EndIf;
	PersonalSettings.Insert(
		"ShowFileNotChangedMessage",
		ShowFileNotChangedMessage);
	
	// File opening settings
	TextFilesExtension = CommonUse.CommonSettingsStorageLoad(
		"FileOpeningSettings\TextFiles",
		"Extension", "TXT XML INI");
	
	TextFilesOpeningMethod = CommonUse.CommonSettingsStorageLoad(
		"FileOpeningSettings\TextFiles", 
		"OpeningMethod",
		Enums.OpenFileForViewingVariants.WithEmbeddedEditor);
	
	GraphicalSchemasExtension = CommonUse.CommonSettingsStorageLoad(
		"FileOpeningSettings\GraphicalSchemas", "Extension", "GRS");
	
	GraphicalSchemasOpeningMethod = CommonUse.CommonSettingsStorageLoad(
		"FileOpeningSettings\GraphicalSchemas",
		"OpeningMethod",
		Enums.OpenFileForViewingVariants.WithEmbeddedEditor);
	
	PersonalSettings.Insert("TextFilesExtension",       TextFilesExtension);
	PersonalSettings.Insert("TextFilesOpeningMethod",   TextFilesOpeningMethod);
	PersonalSettings.Insert("GraphicalSchemasExtension",     GraphicalSchemasExtension);
	PersonalSettings.Insert("GraphicalSchemasOpeningMethod", GraphicalSchemasOpeningMethod);
	
EndProcedure

Function ProhibitedFileExtensionList()
	
	SetPrivilegedMode(True);
	
	ProhibitedDataAreaFileExtensionList =
		Constants.ProhibitedDataAreaFileExtensionList.Get();
	
	If ProhibitedDataAreaFileExtensionList = Undefined
	 Or ProhibitedDataAreaFileExtensionList = "" Then
		
		ProhibitedDataAreaFileExtensionList = "COM EXE BAT CMD VBS VBE JS JSE WSF WSH SCR";
		
		Constants.ProhibitedDataAreaFileExtensionList.Set(
			ProhibitedDataAreaFileExtensionList);
	EndIf;
	
	FinalExtensionList = "";
	
	If CommonUseCached.DataSeparationEnabled()
	   And CommonUseCached.CanUseSeparatedData() Then
		
		ProhibitedFileExtensionList = Constants.ProhibitedFileExtensionList.Get();
		
		FinalExtensionList = 
			ProhibitedFileExtensionList + " "  + ProhibitedDataAreaFileExtensionList;
	Else
		FinalExtensionList = ProhibitedDataAreaFileExtensionList;
	EndIf;
		
	Return FinalExtensionList;
	
EndFunction

Function OpenDocumentFileExtensionList()
	
	SetPrivilegedMode(True);
	
	DataAreaOpenDocumentFileExtensionList =
		Constants.DataAreaOpenDocumentFileExtensionList.Get();
	
	If DataAreaOpenDocumentFileExtensionList = Undefined
	 Or DataAreaOpenDocumentFileExtensionList = "" Then
		
		DataAreaOpenDocumentFileExtensionList =
			"ODT OTT ODP OTP ODS OTS ODC OTC ODF OTF ODM OTH SDW STW SXW STC SXC SDC SDD STI";
		
		Constants.DataAreaOpenDocumentFileExtensionList.Set(
			DataAreaOpenDocumentFileExtensionList);
	EndIf;
	
	FinalExtensionList = "";
	
	If CommonUseCached.DataSeparationEnabled()
	   And CommonUseCached.CanUseSeparatedData() Then
		
		ProhibitedFileExtensionList = Constants.OpenDocumentFileExtensionList.Get();
		
		FinalExtensionList =
			ProhibitedFileExtensionList + " "  + DataAreaOpenDocumentFileExtensionList;
	Else
		FinalExtensionList = DataAreaOpenDocumentFileExtensionList;
	EndIf;
	
	Return FinalExtensionList;
	
EndFunction

Function TextFileExtensionList()

	SetPrivilegedMode(True);
	
	TextFileExtensionList = Constants.TextFileExtensionList.Get();
	
	If IsBlankString(TextFileExtensionList) Then
		TextFileExtensionList = "TXT";
		Constants.TextFileExtensionList.Set(TextFileExtensionList);
	EndIf;
	
	Return TextFileExtensionList;

EndFunction

#EndRegion