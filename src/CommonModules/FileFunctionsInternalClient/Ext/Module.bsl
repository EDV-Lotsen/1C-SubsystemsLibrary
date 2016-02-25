////////////////////////////////////////////////////////////////////////////////
// File functions subsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region InternalInterface

// Shows file editing tips in the web client if the Show file editing tips option is enabled.
//
// Parameters:
//  ResultHandler - NotifyDescription, Undefined - description of the result handler procedure.
//    The method result is passed to this procedure.
//
Procedure ShowReminderOnEdit(ResultHandler) Export
	PersonalSettings = FileFunctionsInternalClientServer.PersonalFileOperationSettings();
	If PersonalSettings.ShowFileEditTips = True Then
		If Not AttachFileSystemExtension() Then
			Form = FileFunctionsInternalClientCached.GetReminderOnEditForm();
			SetFormNotification(Form, ResultHandler);
			Form.Open();
			Return;
		EndIf;
	EndIf;
	ReturnResult(ResultHandler, Undefined);
EndProcedure

// Shows a standard warning.
//
// Parameters:
//  ResultHandler       - NotifyDescription, Undefined - description of the result handler procedure.
//    The method result is passed to this procedure.
//  CommandPresentation - String - Optional. The name of the command that requires the file system extension.
//
Procedure ShowFileSystemExtensionRequiredMessageBox(ResultHandler, CommandPresentation = "") Export
	WarningText = NStr("en = 'To execute the %1 command,
	                                 |install 1C:Enterprise file system extension.'");
	If ValueIsFilled(CommandPresentation) Then
		WarningText = StrReplace(WarningText, "%1", CommandPresentation);
	Else
		WarningText = StrReplace(WarningText, " ""%1""", "");
	EndIf;
	ReturnResultAfterShowWarning(ResultHandler, WarningText, Undefined);
EndProcedure

// Shows a standard warning.
//
// Parameters:
//  ResultHandler       - NotifyDescription, Undefined - description of the result handler procedure.
//    The method result is passed to this procedure.
//  CommandPresentation - String - Optional. The name of the command that requires cryptography extension.
//
Procedure ShowCryptoExtensionRequiredMessageBox(ResultHandler, CommandPresentation = "") Export
	WarningText = NStr("en = 'To execute the %1 command,
	                                 |install the cryptography extension.'");
	If ValueIsFilled(CommandPresentation) Then
		WarningText = StrReplace(WarningText, "%1", CommandPresentation);
	Else
		WarningText = StrReplace(WarningText, " ""%1""", "");
	EndIf;
	ReturnResultAfterShowWarning(ResultHandler, WarningText, Undefined);
EndProcedure

// Returns the path to the user working directory.
Function UserWorkingDirectory() Export
	
	Return FileFunctionsInternalClientCached.UserWorkingDirectory();
	
EndFunction

// Stores the path to the user working directory to the settings.
//
// Parameters:
//  DirectoryName - String - directory name.
//
Procedure SetUserWorkingDirectory(DirectoryName) Export
	
	CommonUseServerCall.CommonSettingsStorageSaveAndRefreshCachedValues(
		"LocalFileCache", "PathToLocalFileCache", DirectoryName);
	
EndProcedure

// Returns My documents directory + the current user name or
// the folder previously used for data export.
//
Function ExportDirectory() Export
	
	Path = "";
	
#If Not WebClient Then
	
	ClientParameters = StandardSubsystemsClientCached.ClientParameters();
	
	Path = CommonUseServerCall.CommonSettingsStorageLoad("ExportFolderName", "ExportFolderName");
	
	If Path = Undefined Then
		If Not ClientParameters.IsBaseConfigurationVersion Then
			Path = MyDocumentsDirectory();
			CommonUseServerCall.CommonSettingsStorageSave(
				"ExportFolderName", "ExportFolderName", Path);
		EndIf;
	EndIf;
	
#EndIf
	
	Return Path;
	
EndFunction

// Returns the My Documents directory.
//
Function MyDocumentsDirectory() Export
	Return DocumentsDir();
EndFunction

// Shows the file selection dialog to the user and returns
// the array of files selected for importing.
//
Function GetImportedFileList() Export
	
	FileDialog = New FileDialog(FileDialogMode.Open);
	FileDialog.FullFileName     = "";
	FileDialog.Filter             = NStr("en = 'All files (*.*)|*.*'");
	FileDialog.Multiselect = True;
	FileDialog.Title          = NStr("en = 'Select files'");
	
	FileNameArray = New Array;
	
	If FileDialog.Choose() Then
		FileArray = FileDialog.SelectedFiles;
		
		For Each FileName In FileArray Do
			FileNameArray.Add(FileName);
		EndDo;
		
	EndIf;
	
	Return FileNameArray;
	
EndFunction

// Adds the trailing slash to the directory name, if necessary,
// removes all prohibited characters from the directory name and replaces "/" with "\".
//
Function NormalizeDirectory(DirectoryName) Export
	
	Result = TrimAll(DirectoryName);
	
	// Remembering the drive name at the beginning of the path: "Drive:" without the colon
	StrDrive = "";
	If Mid(Result, 2, 1) = ":" Then
		StrDrive = Mid(Result, 1, 2);
		Result = Mid(Result, 3);
	Else
		
		// Checking that it is not a UNC path (deleting "\\" from the beginning, if any)
		If Mid(Result, 2, 2) = "\\" Then
			StrDrive = Mid(Result, 1, 2);
			Result = Mid(Result, 3);
		EndIf;
	EndIf;
	
	// Converting slashes to Windows format
	Result = StrReplace(Result, "/", "\");
	
	// Adding a trailing slash
	Result = TrimAll(Result);
	If Right(Result,1) <> "\" Then
		Result = Result + "\";
	EndIf;
	
	// Converting all double slashes to single slashes and getting the full path
	Result = StrDrive + StrReplace(Result, "\\", "\");
	
	Return Result;
	
EndFunction

// Checks if the file name contains prohibited characters.
//
// Parameters:
//  FileName - String - file name.
//
//  DeleteInvalidCharacters - Boolean - If true, deletes the prohibited characters 
//                                      from the file name.
//
Procedure CorrectFileName(FileName, DeleteInvalidCharacters = False) Export
	
	// For the list of prohibited characters, see http://support.microsoft.com/en-us/kb/100108
	// Сharacters prohibited in both FAT and NTFS file systems are processed.
	
	ExceptionStr = CommonUseClientServer.GetProhibitedCharsInFileName();
	
	ErrorText = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = 'A file name should not contain the following characters: %1'"), ExceptionStr);
	
	Result = True;
	
	FoundProhibitedCharArray =
		CommonUseClientServer.FindProhibitedCharsInFileName(FileName);
	
	If FoundProhibitedCharArray.Count() <> 0 Then
		
		Result = False;
		
		If DeleteInvalidCharacters Then
			FileName = CommonUseClientServer.ReplaceProhibitedCharsInFileName(FileName, "");
		EndIf;
		
	EndIf;
	
	If Not Result Then
		Raise ErrorText;
	EndIf;
	
EndProcedure

// Iterates through directories recursively and counts the number of files and their total size.
Procedure GetFileListSize(Path, FileArray, TotalSize, TotalCount) Export
	
	For Each SelectedFile In FileArray Do
		
		If SelectedFile.IsDirectory() Then
			NewPath = String(Path);
			
			NewPath = NewPath + CommonUseClientServer.PathSeparator();
			
			NewPath = NewPath + String(SelectedFile.Name);
			FileArrayInDirectory = FindFiles(NewPath, "*.*");
			
			If FileArrayInDirectory.Count() <> 0 Then
				GetFileListSize(
					NewPath, FileArrayInDirectory, TotalSize, TotalCount);
			EndIf;
		
			Continue;
		EndIf;
		
		TotalSize  = TotalSize  + SelectedFile.Size();
		TotalCount = TotalCount + 1;
		
	EndDo;
	
EndProcedure

// Returns the full file path.
Function GetFullPathToFileInWorkingDirectory(FileData) Export
	
	Return FileData.FullFileNameInWorkingDirectory;
	
EndFunction

// Returns the path to the directory of current user for the given infobase within 
// standard directory of application data.
//
Function SelectPathToUserDataDirectory() Export
	
	DirectoryName = "";
	ExtensionAttached = AttachFileSystemExtension();
	
	If ExtensionAttached Then
		DirectoryName = UserDataWorkDir();
	EndIf;
	
	Return DirectoryName;
	
EndFunction

// Opens Windows Explorer and selects the specified file.
Function OpenExplorerWithFile(Val FullFileName) Export
	
	FileOnHardDisk = New File(FullFileName);
	
	If Not FileOnHardDisk.Exist() Then
		Return False;
	EndIf;
	
	If CommonUseClientServer.IsLinuxClient() Then
		RunApp(FileOnHardDisk.Path);
	Else
		RunApp("explorer.exe /select, """ + FileOnHardDisk.FullName + """");
	EndIf;
		
	Return True;
	
EndFunction

// Checks file properties in the working directory and in the file storage,
// asks for user confirmation if necessary and returns the action to be performed on the file.
//
// Parameters:
//  ResultHandler    - NotifyDescription, Undefined - description of the result handler procedure.
//    The method result is passed to this procedure.
//  FileNameWithPath - String - full file name with its path in the working directory.
// 
//  FileData    - Structure with the following properties:
//                Size                       - Number.
//                ModificationDateUniversal  - Date.
//                InWorkingDirectoryForRead  - Boolean.
//
// Returns:
//  String - one of the following:
//  OpenExistingFile, TakeFromStorageAndOpen, Cancel.
// 
Procedure ActionOnOpenFileInWorkingDirectory(ResultHandler, FileNameWithPath, FileData) Export
	
	If FileData.Property("PathToUpdateFromFileOnDisk") Then
		ReturnResult(ResultHandler, "TakeFromStorageAndOpen");
		Return;
	EndIf;
	
	Parameters = New Structure;
	Parameters.Insert("FileOperation", "OpenInWorkingDirectory");
	Parameters.Insert("FullFileNameInWorkingDirectory", FileNameWithPath);
	
	File = New File(Parameters.FullFileNameInWorkingDirectory);
	
	Parameters.Insert("ChangeDateUniversalInFileStorage",
		FileData.ModificationDateUniversal);
	
	Parameters.Insert("ChangeDateUniversalInWorkingDirectory",
		File.GetModificationUniversalTime());
	
	Parameters.Insert("ChangeDateInWorkingDirectory",
		ToLocalTime(Parameters.ChangeDateUniversalInWorkingDirectory));
	
	Parameters.Insert("ChangeDateInFileStorage",
		ToLocalTime(Parameters.ChangeDateUniversalInFileStorage));
	
	Parameters.Insert("SizeInWorkingDirectory", File.Size());
	Parameters.Insert("SizeInFileStorage", FileData.Size);
	
	DateDifference = Parameters.ChangeDateUniversalInWorkingDirectory
	           - Parameters.ChangeDateUniversalInFileStorage;
	
	If DateDifference < 0 Then
		DateDifference = -DateDifference;
	EndIf;
	
	If DateDifference <= 1 Then // 1 second is an acceptable difference (this can occur on Windows 95)
		
		If Parameters.SizeInFileStorage <> 0
		   And Parameters.SizeInFileStorage <> Parameters.SizeInWorkingDirectory Then
			// The date is the same but the size is different: a rare but possible case
			
			Parameters.Insert("Title",
				NStr("en = 'Different file sizes'"));
			
			Parameters.Insert("Message",
				NStr("en = 'The file size in the working directory is different from the file size in the file storage.
				           |
				           |Update the file from the storage
				           |or open the current file without updating it?'"));
		Else
			// Total match: both dates and sizes match
			ReturnResult(ResultHandler, "OpenExistingFile");
			Return;
		EndIf;
		
	ElsIf Parameters.ChangeDateUniversalInWorkingDirectory
	        < Parameters.ChangeDateUniversalInFileStorage Then
		// The most recent file is in the file storage
		
		If FileData.InWorkingDirectoryForRead = False Then
			// The file in the working directory is for editing
			
			Parameters.Insert("Title", NStr("en = 'Newer file in file storage'"));
			
			Parameters.Insert("Message",
				NStr("en = 'The file in the storage, which is locked for editing,
				           |has a later modification date than the file in the working directory.
				           |
				           |Update the file from the storage 
				           |or open the current file without updating it?'"));
		Else
			// The file in the working directory is for reading
			
			// Updating the file from the storage without asking for confirmation
			ReturnResult(ResultHandler, "TakeFromStorageAndOpen");
			Return;
		EndIf;
	
	ElsIf Parameters.ChangeDateUniversalInWorkingDirectory
	        > Parameters.ChangeDateUniversalInFileStorage Then
		// The most recent file is in the working directory
		
		If FileData.InWorkingDirectoryForRead = False
		   And FileData.Edits = UsersClientServer.CurrentUser() Then
			
			// A working directory file to edit is used by the current user
			ReturnResult(ResultHandler, "OpenExistingFile");
			Return;
		Else
			// A working directory file to read
		
			Parameters.Insert("Title", NStr("en = 'A recent file in the working directory'"));
			
			Parameters.Insert(
				"Message",
				NStr("en = 'The file in the working directory has a later modification date 
				           |than the file in the file storage. Perhaps it was changed.
				           |
				           |Open the current file or discard the changes, update the file
				           |from the storage, and open that file?'"));
		EndIf;
	EndIf;
	
	//SelectActionIfDifferenceInFilesFound
	OpenForm("CommonForm.SelectActionIfDifferenceInFilesFound", Parameters, , , , , ResultHandler, FormWindowOpeningMode.LockWholeInterface);
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

#If Not WebClient Then
// Extracts the text from the file on the client hard disk and stores the result to the server.
Procedure ExtractVersionText(FileOrFileVersion,
                             FileURL,
                             Extension,
                             UUID,
                             Encoding = Undefined) Export
	
	FileNameWithPath = GetTempFileName(Extension);
	
	If Not GetFile(FileURL, FileNameWithPath, False) Then
		Return;
	EndIf;
	
	// If files are stored on the hard disk (on the server), deleting a file from the temporary storage
	// after receiving it.
	If IsTempStorageURL(FileURL) Then
		DeleteFromTempStorage(FileURL);
	EndIf;
	
	ExtractionResult = "NotExtracted";
	TempTextStorageAddress = "";
	
	Text = "";
	If FileNameWithPath <> "" Then
		
		// Extracting text from the file
		Cancel = False;
		Text = FileFunctionsInternalClientServer.ExtractText(FileNameWithPath, Cancel, Encoding);
		
		If Cancel = False Then
			ExtractionResult = "Extracted";
			
			If Not IsBlankString(Text) Then
				TempFileName = GetTempFileName();
				TextFile = New TextWriter(TempFileName, TextEncoding.UTF8);
				TextFile.Write(Text);
				TextFile.Close();
				
				UploadResult = PutFileFromDiskInTempStorage(TempFileName, , UUID);
				If UploadResult <> Undefined Then
					TempTextStorageAddress = UploadResult;
				EndIf;
				
				DeleteFiles(TempFileName);
			EndIf;
		Else
			// If there is no handler to extract the text, it is not an error.
			// No error message is generated.
			ExtractionResult = "FailedExtraction";
		EndIf;
		
	EndIf;
	
	DeleteFiles(FileNameWithPath);
	
	FileFunctionsInternalServerCall.RecordTextExtractionResult(
		FileOrFileVersion, ExtractionResult, TempTextStorageAddress);
	
EndProcedure
#EndIf

// Uploads the file from the client to a temporary storage on the server. Requires the file system extension.
Function PutFileFromDiskInTempStorage(FullFileName, FileURL = "", UUID = Undefined) Export
	If Not AttachFileSystemExtension() Then
		Return Undefined;
	EndIf;
	WhatToUpload = New Array;
	WhatToUpload.Add(New TransferableFileDescription(FullFileName, FileURL));
	UploadResult = New Array;
	FileUploaded = PutFiles(WhatToUpload, UploadResult, , False, UUID);
	If Not FileUploaded Or UploadResult.Count() = 0 Then
		Return Undefined;
	EndIf;
	Return UploadResult[0].Location;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures intended to support the asynchronous model.
//
// Common parameter description:
//   ResultHandler - asynchronous method handler procedure.
//       - Undefined           - handler is not required.
//       - NotifyDescription   - handler procedure description.
//   Result        - Arbitrary - value to be returned to ResultHandler.

// Shows the text and calls the handler with the specified result.
Procedure ReturnResultAfterShowWarning(ResultHandler, WarningText, Result) Export
	If TypeOf(ResultHandler) = Type("NotifyDescription") Then
		HandlerParameters = New Structure;
		HandlerParameters.Insert("ResultHandler", ResultHandler);
		HandlerParameters.Insert("Result",             Result);
		Handler = New NotifyDescription("ReturnResultAfterCloseSimpleDialog", ThisObject, HandlerParameters);
		ShowMessageBox(Handler, WarningText);
	Else
		ShowMessageBox(, WarningText);
	EndIf;
EndProcedure

// Handler of ReturnResultAfterShowWarning procedure result.
Procedure ReturnResultAfterCloseSimpleDialog(Structure) Export
	ExecuteNotifyProcessing(Structure.ResultHandler, Structure.Result);
EndProcedure

// Returns the direct call result when dialog opening is not required.
Procedure ReturnResult(ResultHandler, Result) Export
	If TypeOf(ResultHandler) = Type("NotifyDescription") Then
		ExecuteNotifyProcessing(ResultHandler, Result);
	EndIf;
EndProcedure

// Sets the window closing handler for the form received through the GetForm method.
Procedure SetFormNotification(Form, ResultHandler)
	If TypeOf(ResultHandler) = Type("NotifyDescription") Then
		Form.OnCloseNotifyDescription = ResultHandler;
	EndIf;
EndProcedure

#EndRegion
