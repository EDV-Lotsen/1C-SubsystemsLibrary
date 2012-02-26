
// Can the file be released
Function CanUnlockFile(ObjectRef, LockedByCurrentUser, LockedBy, ErrorString = "") Export

	If LockedByCurrentUser Then 
		Return True;
	ElsIf LockedBy.IsEmpty() Then
		ErrorString = StringFunctionsClientServer.SubstitureParametersInString(
		                           NStr("en = 'It is impossible to unlock %1 file because it is not locked by anyone.'"), String(ObjectRef));
		Return False;
	Else
		If FileOperationsSecondUseClient.GetFileOperationsPersonalSettings().CurrentUserHaveFullAccess Then
			Return True;
		EndIf;
		
		ErrorString = StringFunctionsClientServer.SubstitureParametersInString(
		                           NStr("en = 'It is impossible to release %1 file as it is being used by %2 user.'"),
		                           String(ObjectRef),
		                           String(LockedBy));
		Return False;
	EndIf;
	
EndFunction // CanUnlockFile()

// Mark file as locked for edit - by ref
// (without GetFileData 		- for minimizing server calls)
Procedure LockFileByRef(ObjectRef, UUID = Undefined) Export
	
	Var FileData;
	
	CommonUseClient.SuggestWorkWithFilesExtensionInstallationNow();
	
	IsExtensionAttached = AttachFileSystemExtension();
	
	ErrorString = "";
	If Not FileOperations.GetFileDataAndLockFile(ObjectRef, FileData, ErrorString, UUID) Then
		// Displaying a error message if the file can not be locked
		DoMessageBox(ErrorString);
		Return;
	EndIf;	
	
	If IsExtensionAttached Then
		ForRead = False;
		InOwnerWorkingDirectory = FileData.OwnerWorkingDirectory <> "";
		ReregisterFileInWorkingDirectory(FileData, ForRead, InOwnerWorkingDirectory);
		
	EndIf;
	
	ShowUserNotification(
		NStr("en = 'File Editing'"),
		FileData.URL,
		StringFunctionsClientServer.SubstitureParametersInString(
		    NStr("en = '%1 file is locked for editing.'"), String(FileData.Ref)),
			PictureLib.Information32);
	
EndProcedure //LockFileByRef

// Mark files as locked for edit - by the array of refs
//
Procedure LockFilesByRefs(Val FilesArray) Export
	
	CommonUseClient.SuggestWorkWithFilesExtensionInstallationNow();
	
	// Get array of file data
	FilesData 	 = New Array;
	FileOperations.GetDataForFilesArray(FilesArray, FilesData);
	UBoundArray  = FilesData.UBound();
	
	For Indd = 0 To UBoundArray Do
		FileData = FilesData[UBoundArray - Indd];
		
		ErrorString = "";
		If Not FileOperationsClientServer.CanLockFile(FileData, ErrorString) 
		   Or Not FileData.LockedBy.IsEmpty() Then // impossible to lock
			FilesData.Delete(UBoundArray - Indd);
		EndIf;	
	EndDo;	
	
	IsExtensionAttached = AttachFileSystemExtension();
	
	// Locking files
	LockedFilesCount = 0;
	
	For Each FileData In FilesData Do
		
		If Not FileOperations.LockFile(FileData) Then 
			Continue;
		EndIf;	
		
		If IsExtensionAttached Then
			ForRead 				= False;
			InOwnerWorkingDirectory = FileData.OwnerWorkingDirectory <> "";
			ReregisterFileInWorkingDirectory(FileData, ForRead, InOwnerWorkingDirectory);
		EndIf;
		
		LockedFilesCount = LockedFilesCount + 1;
	EndDo;
	
	ShowUserNotification(  
		NStr("en = 'Files Locking'"),
		,
		StringFunctionsClientServer.SubstitureParametersInString(
			NStr("en = '%1 of %2 files are locked for editing.'"), 
			LockedFilesCount, FilesArray.Count()),
		PictureLib.Information32);
	
EndProcedure //LockFileByRefs

// Mark file as locked for edit
Procedure LockFile(FileData)
	
	CommonUseClient.SuggestWorkWithFilesExtensionInstallationNow();
	
	ErrorString = "";
	If FileOperationsClientServer.CanLockFile(FileData, ErrorString) Then
		
		IsExtensionAttached = AttachFileSystemExtension();
	
		ErrorString = "";
		If Not FileOperations.LockFile(FileData, ErrorString) Then 
			DoMessageBox(ErrorString);
			Return;
		EndIf;	
		
		If IsExtensionAttached Then
			ForRead = False;
			InOwnerWorkingDirectory = FileData.OwnerWorkingDirectory <> "";
			ReregisterFileInWorkingDirectory(FileData, ForRead, InOwnerWorkingDirectory);
		EndIf;

		ShowUserNotification(
			NStr("en = 'File Editing'"),
			FileData.URL,
			StringFunctionsClientServer.SubstitureParametersInString(
				NStr("en = '%1 file is locked for editing.'"), 
				String(FileData.Ref)),
			PictureLib.Information32);
		
	Else
		DoMessageBox(ErrorString);
		Return;
	EndIf;
	
EndProcedure

// Procedure opens File in edit mode - accepts File ref
// by ref (without GetFileData - for minimizing server calls)
Procedure EditFileByRef(ObjectRef, UUID = Undefined, OwnerWorkingDirectory = Undefined) Export
	Var FileData;
	
	CommonUseClient.SuggestWorkWithFilesExtensionInstallationNow();
	
	IsExtensionAttached = AttachFileSystemExtension();
	
	ErrorString = "";
	If Not FileOperations.GetFileDataForOpeningAndLockFile(ObjectRef, FileData, ErrorString, UUID, OwnerWorkingDirectory) Then
		// Displaying error message if can not lock a file
		DoMessageBox(ErrorString);
		Return;
	EndIf;
	
	If IsExtensionAttached Then
		ForRead = False;
		InOwnerWorkingDirectory = FileData.OwnerWorkingDirectory <> "";
		ReregisterFileInWorkingDirectory(FileData, ForRead, InOwnerWorkingDirectory);
	EndIf;

	ShowUserNotification(
		NStr("en = 'File Editing'"),
		FileData.URL,
		StringFunctionsClientServer.SubstitureParametersInString(
			NStr("en = '%1 file locked for editing.'"), 
			String(FileData.Ref)),
		PictureLib.Information32);
	
	// If File object does not contain a file to save then opening a catalog item
	If FileData.Version.IsEmpty() Then 
		OpenValue(FileData.Ref);
		Return;
	EndIf;
	
	If IsExtensionAttached Then
		FullFileName = "";
		Result 		 = GetVersionFileToWorkingDirectory(FileData, FullFileName, UUID);
		If Result Then
			OpenFileByApplication(FileData, FullFileName);
		EndIf;
	Else
		ShowTipsOnEdit();
		FileName = FileFunctionsClient.GetNameWithExtention(FileData.VersionDetails, FileData.Extension);
		GetFile(FileData.CurrentVersionURL, FileName, True);		
		
		// deleting file from temporary storage after getting it
		// for case when files are located on disk (at server)
		If IsTempStorageURL(FileData.CurrentVersionURL) Then
			DeleteFromTempStorage(FileData.CurrentVersionURL);
		EndIf;
	EndIf;
	
EndProcedure // EditFileByRef()

// Will display reminder - if setting is on
Procedure ShowTipsOnEdit()
	If FileOperationsSecondUseClient.GetFileOperationsPersonalSettings().ShowTipsOnEditFiles = True Then
		
		IsExtensionAttached = AttachFileSystemExtension();
		If Not IsExtensionAttached Then
			Form = FileOperationsSecondUseClient.GetTipsOnEditForm();

			Form.DoNotShowAnyMore = False;
			Form.DoModal();
			
			If Form.DoNotShowAnyMore = True Then
				FileOperationsSecondUseClient.GetFileOperationsPersonalSettings().ShowTipsOnEditFiles = False;
				CommonUse.CommonSettingsStorageSave("ApplicationSettings", "ShowTipsOnEditFiles", FileOperationsSecondUseClient.GetFileOperationsPersonalSettings().ShowTipsOnEditFiles);
			EndIf;
		EndIf;
		
	EndIf;
EndProcedure // ShowTipsOnEdit()

// Will display reminder - if setting is on
Procedure ShowTipsBeforePutFile()
	If FileOperationsSecondUseClient.GetFileOperationsPersonalSettings().ShowTipsOnEditFiles = True Then
		
		IsExtensionAttached = AttachFileSystemExtension();
		If Not IsExtensionAttached Then
			// Caches form at client
			Form = FileOperationsSecondUseClient.GetTipsBeforePlaceFileForm();
			Form.DoNotShowAnyMore = False;
			Form.DoModal();
			
			If Form.DoNotShowAnyMore = True Then
				FileOperationsSecondUseClient.GetFileOperationsPersonalSettings().ShowTipsOnEditFiles = False;
				CommonUse.CommonSettingsStorageSave("ApplicationSettings", "ShowTipsOnEditFiles", FileOperationsSecondUseClient.GetFileOperationsPersonalSettings().ShowTipsOnEditFiles);
			EndIf;
		EndIf;
		
	EndIf;
EndProcedure // ShowTipsBeforePutFile()

// Procedure opens File in edit mode
Procedure EditFile(FileData, UUID = Undefined) Export
	
	CommonUseClient.SuggestWorkWithFilesExtensionInstallationNow();
	
	IsExtensionAttached = AttachFileSystemExtension();
	
	ErrorString = "";
	If Not FileOperationsClientServer.CanLockFile(FileData, ErrorString) Then
		DoMessageBox(ErrorString);
		Return;
	EndIf;	
	
	// Locking the file if it is not locked yet
	If FileData.LockedBy.IsEmpty() Then
		LockFile(FileData);
	EndIf;
	
	// If File object does not contain a file to save then opening a catalog item
	If FileData.Version.IsEmpty() Then 
		OpenValue(FileData.Ref);
		Return;
	EndIf;
	
	If IsExtensionAttached Then
		FullFileName = "";
		Result 		 = GetVersionFileToWorkingDirectory(FileData, FullFileName, UUID);
		If Result Then
			OpenFileByApplication(FileData, FullFileName);
		EndIf;
	Else
		ShowTipsOnEdit();
		FileName = FileFunctionsClient.GetNameWithExtention(FileData.VersionDetails, FileData.Extension);
		GetFile(FileData.CurrentVersionURL, FileName, True);
		
		// deleting file from temporary storage after getting it
		// for case when files are located on disk (at server)
		If IsTempStorageURL(FileData.CurrentVersionURL) Then
			DeleteFromTempStorage(FileData.CurrentVersionURL);
		EndIf;
	EndIf;
	
EndProcedure // EditFile()

// Procedure of File open
Procedure OpenFile(FileData, UUID = Undefined) Export
	
	CommonUseClient.SuggestWorkWithFilesExtensionInstallationNow();
	
	// If File object does not contain a file to save then opening a catalog item
	If FileData.Version.IsEmpty() Then 
		OpenValue(FileData.Ref);
		Return;
	EndIf;
	
	IsExtensionAttached = AttachFileSystemExtension();
	
	If IsExtensionAttached Then
		FullFileName = "";
		Result 		 = GetVersionFileToWorkingDirectory(FileData, FullFileName, UUID);
		If Result Then
			OpenFileByApplication(FileData, FullFileName);
		EndIf;
	Else
		If FileData.LockedByCurrentUser Then 
			ShowTipsOnEdit();
		EndIf;
		FileName = FileFunctionsClient.GetNameWithExtention(FileData.VersionDetails, FileData.Extension);
		GetFile(FileData.CurrentVersionURL, FileName, True);
		
		// deleting file from temporary storage after getting it
		// for case when files are located on disk (at server)
		If IsTempStorageURL(FileData.CurrentVersionURL) Then
			DeleteFromTempStorage(FileData.CurrentVersionURL);
		EndIf;
	EndIf;
	
EndProcedure // OpenFile()

// Procedure opens File version
Procedure OpenFileVersion(FileData, UUID = Undefined) Export
	
	CommonUseClient.SuggestWorkWithFilesExtensionInstallationNow();
	
	IsExtensionAttached = AttachFileSystemExtension();
	If IsExtensionAttached Then
		FullFileName = "";
		Result		 = GetVersionFileToWorkingDirectory(FileData, FullFileName, UUID);
		If Result Then
			OpenFileByApplication(FileData, FullFileName);
		EndIf;
	Else
		Address  = FileOperations.GetURLForOpening(FileData.Version, UUID);
		
		FileName = FileFunctionsClient.GetNameWithExtention(FileData.VersionDetails, FileData.Extension);
		GetFile(Address, FileName, True);		
		
		// deleting file from temporary storage after getting it
		// for case when files are located on disk (at server)
		If IsTempStorageURL(Address) Then
			DeleteFromTempStorage(Address);
		EndIf;
	EndIf;
EndProcedure // OpenFileVersion()


// Creates File based on the passed path on disk and opens a dossier
Procedure CreateDocumentBasedOnFile(FullFileName, FileOwner, FormOwner, 
	DoNotOpenCardAfterCreateFromFile = Undefined, GeneratedFileName = Undefined) Export
	
	CommonUseClient.SuggestWorkWithFilesExtensionInstallationNow();
	
	// Create a file here
	File = New File(FullFileName);
	
	ProhibitFileLoadByExtension = FileOperationsSecondUseClient.GetFileOperationsPersonalSettings().ProhibitFileLoadByExtension;
	ProhibitedExtensionsList 	= FileOperationsSecondUseClient.GetFileOperationsPersonalSettings().ProhibitedExtensionsList;
	FileExtension 				= File.Extension;
	If Not FileOperationsClientServer.FileExtensionAllowedForLoad(ProhibitFileLoadByExtension, ProhibitedExtensionsList, FileExtension) Then
		Raise StringFunctionsClientServer.SubstitureParametersInString(
			NStr("en = 'Downloading files with %1 extension prohibited. Contact system administrator.'"),
			FileExtension);
	EndIf;	
	
	MaxFileSize = FileOperationsSecondUseClient.GetFileOperationsPersonalSettings().MaximumFileSize;
	
	SizeInMB = File.Size() / (1024 * 1024);
	MaxSizeInMB = MaxFileSize / (1024 * 1024);
	
	If File.Size() > MaxFileSize Then
		
		RefreshReusableValues();
		
		Raise StringFunctionsClientServer.SubstitureParametersInString(
			NStr("en = 'Size of %1 file (%2 MB) exceeds the maximum allowed file size (%3 MB).'"),
			File.Name, 
			?(SizeInMB 	>= 1, 	Format(SizeInMB, 	"NFD=0"), Format(SizeInMB,	  "NFD=1; NZ=0")), 
			?(MaxSizeInMB  >= 1, 	Format(MaxSizeInMB, "NFD=0"), Format(MaxSizeInMB, "NFD=1; NZ=0")));
	EndIf;
	
	TextTemporaryStorageAddress = FileFunctionsClient.ExtractTextToTemporaryStorage(
		File.FullName, 
		FormOwner.UUID);
	
	ModificationTime  = File.GetModificationTime();
	ModificationDateUniversal = File.GetModificationUniversalTime();
	
	CreationName = File.BaseName;
	If GeneratedFileName <> Undefined Then
		CreationName = GeneratedFileName;
	EndIf;	
	
	FileName = CreationName + File.Extension;
	SizeInMB = File.Size() / (1024 * 1024);
	
	ClarificationText =
	StringFunctionsClientServer.SubstitureParametersInString(
		NStr("en = 'Saving %1 file (%2 MB). Please wait...'"),
		FileName,
		?(SizeInMB >= 1, Format(SizeInMB, "NFD=0"), Format(SizeInMB, "NFD=1; NZ=0")));
	
	Status(ClarificationText);
	
	
	// Put File to TemporaryStorage
	FileTemporaryStorageAddress = "";
	
	FilesBeingPlaced = New Array;
	FileName = New TransferableFileDescription(File.FullName, "");
	FilesBeingPlaced.Add(FileName);
	
	PlacedFiles = New Array;

	If Not PutFiles(FilesBeingPlaced, PlacedFiles, , False, FormOwner.UUID) Then		
		Raise StringFunctionsClientServer.SubstitureParametersInString(
			NStr("en = 'Error while placing file to the storage: %1'"), 
			File.FullName);
	EndIf;
	
	If PlacedFiles.Count() = 1 Then
		FileTemporaryStorageAddress = PlacedFiles[0].Location;
	EndIf;
	
	// Creating File catalog item in infobase
	Doc = FileOperations.CreateFileWithVersion(
		FileOwner,
		CreationName,
		FileFunctionsClientServer.RemoveDotFromExtension(File.Extension),
		ModificationTime,
		ModificationDateUniversal,
		File.Size(),
		FileTemporaryStorageAddress,
		TextTemporaryStorageAddress,
		False); // this is not web client

	Status();
	
	AlertParameters = New Structure("Owner, File", FileOwner, Doc);
	Notify("FileCreated", AlertParameters);
	
	URL = GetURL(Doc);
	ShowUserNotification(
		NStr("en = 'Creating:'"),
		URL,
		Doc,
		PictureLib.Information32);
	
	Parameters = New Structure("Key, CardIsOpenAfterFileCreate, NewFile", Doc, True, True);
	
	If DoNotOpenCardAfterCreateFromFile <> True Then
		OpenForm("Catalog.Files.ObjectForm", Parameters, FormOwner);
	EndIf;
EndProcedure	

// Procedure of new File creation
// Parameters:
//	CreationMode  - how to create new File
//		1 		- create from template
//		2 		- create from file
//		3 		- create empty dossier
Procedure CreateFile(CreationMode, FileOwner, FormOwner, DoNotOpenCardAfterCreateFromFile = Undefined) Export
	
	CommonUseClient.SuggestWorkWithFilesExtensionInstallationNow();
	
	If CreationMode = 1 Then
		
		// Creating from template
		FormOpenParameters = New Structure("TemplateChoice, CurrentRow", 
			True, PredefinedValue("Catalog.FileFolders.FileTemplates"));
		Result = OpenFormModal("Catalog.Files.Form.ChoiceForm", FormOpenParameters);
		
		If Result = Undefined Then
			Return;
		EndIf;
		
		Parameters = New Structure("FileBasis, FileOwner, CreationMode", 
			Result, FileOwner, "FromTemplate");
		OpenForm("Catalog.Files.ObjectForm", Parameters, FormOwner);
		
	ElsIf CreationMode = 2 Then
		
		// Creating from file
		FullFileName = "";
		
		IsExtensionAttached = AttachFileSystemExtension();
		If IsExtensionAttached Then
			FileChoice 				= New FileDialog(FileDialogMode.Open);
			FileChoice.Multiselect 	= False;
			FileChoice.Title  		= NStr("en = 'Choose File'");
			FileChoice.Filter 		= NStr("en = 'All files (*.*)|*.*'");
			
			WorkingDirectory 		= FileOperations.GetWorkingDirectory(FileOwner);
			FileChoice.Directory 	= WorkingDirectory;

			Result 		 = FileChoice.Choose();
			FullFileName = FileChoice.FullFileName;
		
			If Not Result Then
				Return;
			EndIf;
			
			CreateDocumentBasedOnFile(FullFileName, FileOwner, FormOwner, DoNotOpenCardAfterCreateFromFile);
				
		Else 
			// If web-client
			ModificationTime  = CurrentDate(); // Because we can't get file modification date on disk
			ModificationDateUniversal = ToUniversalTime(CurrentDate());
			Size 						= 0;   // Because we can't get file size on disk
			BaseName 					= "";
			Extension 					= "";
			TextTemporaryStorageAddress = "";

			// Put File to TemporaryStorage
			FileTemporaryStorageAddress = "";
			FileName = "";
			If Not PutFile(FileTemporaryStorageAddress, FileName, FileName, True, FormOwner.UUID) Then
				Return;
			EndIf;

			PathRows = SplitStringByDotsAndSlashes(FileName);
			If PathRows.Count() >= 2 Then
				Extension = PathRows[PathRows.Count()-1];
				BaseName  = PathRows[PathRows.Count()-2];
			Else
				Raise
				  StringFunctionsClientServer.SubstitureParametersInString(
				    NStr("en = 'Error while placing a file to the storage: %1'"), FileName);
			EndIf;
			
			// Create File dossier in DB
			Doc = FileOperations.CreateFileWithVersion(
				FileOwner,
				BaseName,
				FileFunctionsClientServer.RemoveDotFromExtension(Extension),
				ModificationTime,
				ModificationDateUniversal,
				Size,
				FileTemporaryStorageAddress,
				TextTemporaryStorageAddress,
				True); // this is a web client
			
			If DoNotOpenCardAfterCreateFromFile <> True Then
				Parameters = New Structure("Key, NewFile", Doc, True);
				OpenForm("Catalog.Files.ObjectForm", Parameters, FormOwner);
			EndIf;
		EndIf;
		
	ElsIf CreationMode = 3 Then
		// from scanner
		WorkWithScannerClient.ScanAndShowViewDialog(
			FileOwner, 
			FormOwner.UUID, 
			FormOwner, 
			DoNotOpenCardAfterCreateFromFile);
	Else
		Raise
		  StringFunctionsClientServer.SubstitureParametersInString(
		    NStr("en = 'Incorrect file creation mode: %1'"), CreationMode);
	EndIf;
	
EndProcedure // CreateFile()

// Finish edit - by the refs array
//
Function EndEditByRefs(Val FilesArray, FormID) Export
	
	CommonUseClient.SuggestWorkWithFilesExtensionInstallationNow();
	
	// Get array of file data
	FilesData = New Array;
	FileOperations.GetDataForFilesArray(FilesArray, FilesData);
	UBoundArray  = FilesData.UBound();
	
	For Ind = 0 To UBoundArray Do
		FileData = FilesData[UBoundArray - Ind];
		
		// Check possibility to release the file
		ErrorString = "";
		If Not CanUnlockFile(FileData.Ref, FileData.LockedByCurrentUser, FileData.LockedBy, ErrorString) Then
			FilesData.Delete(UBoundArray - Ind);
		EndIf;
		
	EndDo;	
	
	IsExtensionAttached = AttachFileSystemExtension();
	
	
	ReturnForm = FileOperationsSecondUseClient.GetFileReturnForm();
	
	ReturnForm.Parameters.FileRef = Undefined;
	ReturnForm.CommentToVersion   = "";

	ReturnForm.File = Undefined;

	ReturnForm.CreateNewVersion 			  = True;
	ReturnForm.Items.CreateNewVersion.Enabled = True;

	ReturnArray = New Array;
	
	Result = ReturnForm.DoModal();
	If TypeOf(Result) <> Type("Structure") Then
		Return ReturnArray;
	EndIf;	
	
	ReturnCode = Result.ReturnCode;
	If ReturnCode <> DialogReturnCode.OK Then
		Return ReturnArray;
	EndIf;	
	
	CreateNewVersion = Result.CreateNewVersion;
	CommentToVersion = Result.CommentToVersion;
	
	ApplyToAll = False;
	UnlockFiles = True;
	
	// Lock files
	For Each Data In FilesData Do
		
		ShowAlert = False;
		
		If EndEdit(
					Data.Ref, 
					FormID, 
					Data.StoreVersions,
					Data.LockedByCurrentUser, 
					Data.LockedBy,
					Data.CurrentVersionAuthor,
					"",
					CreateNewVersion,
					CommentToVersion,
					ShowAlert,
					ApplyToAll,
					UnlockFiles) Then
					
			ReturnArray.Add(Data.Ref);
		EndIf;	
		
	EndDo;
	
	ShowUserNotification(  
		NStr("en = 'Finish Editing Files'"),
		,
		StringFunctionsClientServer.SubstitureParametersInString(
			NStr("en = '%1 of %2 files editing completed'"), 
			ReturnArray.Count(), FilesArray.Count()),
		PictureLib.Information32);
	
	Return ReturnArray;
	
EndFunction //EndEditByRefs

// Finish File edit and put it on server
//
Function EndEdit(ObjectRef, FormID, Val StoreVersions = Undefined,
				 Val LockedByCurrentUser  = Undefined, 
				 Val LockedBy 			  = Undefined,
				 Val CurrentVersionAuthor = Undefined,
				 PassedFullFilePath = "",
				 CreateNewVersion 	= Undefined,
				 CommentToVersion 	= Undefined,
				 ShowAlert 			= True,
				 ApplyToAll 		= False,
				 UnlockFiles  		= True) Export
	Var FileData;
	
	CommonUseClient.SuggestWorkWithFilesExtensionInstallationNow();
	
	IsExtensionAttached = AttachFileSystemExtension();
	IsCryptoExtensionAttached = AttachCryptoExtension();
	
	If Not IsExtensionAttached Then // web client with no work with files extension

		If StoreVersions = Undefined Then
			FileData 			 = FileOperations.GetFileData(ObjectRef);
			StoreVersions 		 = FileData.StoreVersions;
			LockedByCurrentUser  = FileData.LockedByCurrentUser;
			LockedBy 			 = FileData.LockedBy;
			CurrentVersionAuthor = FileData.CurrentVersionAuthor;
		EndIf;

		// Check possibility to release the file
		ErrorString = "";
		If Not CanUnlockFile(ObjectRef, LockedByCurrentUser, LockedBy, ErrorString) Then
			DoMessageBox(ErrorString);
			Return False;
		EndIf;
		
		FullFilePath = "";

		If CreateNewVersion = Undefined Then
			ReturnForm = FileOperationsSecondUseClient.GetFileReturnForm();
			
			ReturnForm.Parameters.FileRef = ObjectRef;
			ReturnForm.CommentToVersion = "";

			ReturnForm.File = ObjectRef;

			If StoreVersions Then
				ReturnForm.CreateNewVersion = True;
				
				// making check "Don't create new version" disabled
				// If the current user is not an author of the current version
				If CurrentVersionAuthor <> LockedBy Then
					ReturnForm.Items.CreateNewVersion.Enabled = False;
				Else
					ReturnForm.Items.CreateNewVersion.Enabled = True;
				EndIf;			
			Else
				ReturnForm.CreateNewVersion = False;
				ReturnForm.Items.CreateNewVersion.Enabled = False;
			EndIf;	

			
			Result = ReturnForm.DoModal();
			If TypeOf(Result) <> Type("Structure") Then
				Return False;
			EndIf;	
			
			ReturnCode = Result.ReturnCode;
			If ReturnCode <> DialogReturnCode.OK Then
				Return False;
			EndIf;	
			
			CreateNewVersion = Result.CreateNewVersion;
			CommentToVersion = Result.CommentToVersion;
			
		Else // CreateNewVersion and CommentToVersion are passed from outside
			
			If StoreVersions Then
				
				// making check "Don't create new version" disabled
				// If the current user is not an author of the current version
				If CurrentVersionAuthor <> LockedBy Then
					CreateNewVersion = True;
				EndIf;			
				
			Else
				CreateNewVersion = False;
			EndIf;	
			
		EndIf;
		
		Interactively = True;
		
		While True Do
			Try
				TemporaryStorageAddress = "";	
				SelectedFilePath = "";
				ShowTipsBeforePutFile();
				If PutFile(TemporaryStorageAddress, FullFilePath, SelectedFilePath, Interactively, FormID) Then
					
					TextTemporaryStorageAddress = "";
					BaseName  = "";
					Extension = "";
					
					ThisIsWebClient = True;
					
					TextNotExtractedAtClient = False;
					#If WebClient Then
						TextNotExtractedAtClient = True;
					#EndIf	
					
					ModificationTime  = CurrentDate(); // Because we can't get file modification date on disk
					ModificationDateUniversal = ToUniversalTime(CurrentDate());
					Size = 0; // Because we can't get file size on disk
					
					PathRows = SplitStringByDotsAndSlashes(SelectedFilePath);
					If PathRows.Count() >= 2 Then
						Extension = PathRows[PathRows.Count()-1];
						BaseName  = PathRows[PathRows.Count()-2];
					EndIf;

					FileOperations.GetFileDataSaveAndUnlockFile(
						ObjectRef,
						FileData,
						CreateNewVersion,
						TemporaryStorageAddress,
						CommentToVersion,
						ModificationTime,
						ModificationDateUniversal,
						Size,
						BaseName,
						Extension,
						FullFilePath,
						TextTemporaryStorageAddress,
						ThisIsWebClient,
						TextNotExtractedAtClient,
						FormID);
					
					NewVersion = FileData.CurrentVersion;
					
					If ShowAlert Then
						ShowUserNotification(
							NStr("en = 'Finished Editing'"),
							FileData.URL,
							StringFunctionsClientServer.SubstitureParametersInString(
							    NStr("en = '%1 file has been updated and unlocked.'"), String(FileData.Ref)),
							PictureLib.Information32);
					EndIf;	
						
					Return True;
				Else
					Return False;
				EndIf;
			Except
				
				ErrorInformation = ErrorInfo();
				
				If ErrorInformation.Cause = Undefined Then
					ErrorMessage = ErrorInformation.Details;
				Else
					ErrorMessage = ErrorInformation.Cause.Details;
				EndIf;

				QuestionText = StringFunctionsClientServer.SubstitureParametersInString(
					NStr("en = 'Unable to save %1 file into infobase because: %2. Do you want to repeat the operation?'"),
					String(ObjectRef), ErrorMessage);
				ReturnCode = DoQueryBox(QuestionText, QuestionDialogMode.RetryCancel);
				
				If ReturnCode = DialogReturnCode.Cancel Then
					Return False;
				EndIf;
				
			EndTry;
		EndDo;

	Else // below code for thin (or thick) client (or web with installed extension)
		FileData = FileOperations.GetFileDataAndWorkingDirectory(ObjectRef);
	
		// Checking if it is possible to unlock the file
		ErrorString = "";
		If Not CanUnlockFile(FileData.Ref, FileData.LockedByCurrentUser, FileData.LockedBy, ErrorString) Then
			DoMessageBox(ErrorString);
			Return False;
		EndIf;
		
		FullFilePath     = PassedFullFilePath;
		If FullFilePath  = "" Then
			FullFilePath = FileFunctionsClient.GetFullFilePathInWorkingDirectory(FileData);
		EndIf;
		
		// Check if file exists on disk
		NewVersionFile = New File(FullFilePath);
		If Not NewVersionFile.Exist() Then
			
			If ApplyToAll = False Then
			
				WarningString = StringFunctionsClientServer.SubstitureParametersInString(
				    NStr("en = 'Failed loading %1 file back into infobase because it is not found at the local computer.'"),
				    String(FileData.Ref));
					
				If Not IsBlankString(FullFilePath) Then
					WarningString = WarningString + " (" + FullFilePath + ").";	
				Else
					WarningString = WarningString + ".";	
				EndIf;
				
				WarningString = WarningString + Chars.LF + NStr("en = 'Release file?'");
					
				FormParameters = 
				New Structure("Title, Information", 
					NStr("en = 'Finish Editing'"), WarningString);
					
				Result = OpenFormModal("Catalog.Files.Form.QuestionFormEndEdit", FormParameters);
				
				If TypeOf(Result) <> Type("Structure") Then
					UnlockFiles = False;
				Else
					ReturnCode = Result.ReturnCode;
					
					If ReturnCode  = DialogReturnCode.Yes Then
						ApplyToAll = Result.ApplyToAll;
						UnlockFiles = True;
					ElsIf ReturnCode  = DialogReturnCode.No Then
						ApplyToAll 	  = Result.ApplyToAll;
						UnlockFiles = False; 
					EndIf;
				EndIf;
				
			EndIf;
			
			If UnlockFiles Then
				UnlockFileWithoutQuestion(FileData, FormID);
				Return True;
			EndIf;
			
			Return False;
			
		EndIf;
	
		Try
			ReadOnly = NewVersionFile.GetReadOnly();
			NewVersionFile.SetReadOnly(Not ReadOnly);
			NewVersionFile.SetReadOnly(ReadOnly);
		Except
			
			DoMessageBox(
				StringFunctionsClientServer.SubstitureParametersInString(
					NStr("en = 'Unable to load %1 file back into infobase because it is locked by another application.'"),
					String(FileData.Ref)));

		EndTry;
			
		// Request comment and version storing flag
		If CreateNewVersion = Undefined Then
			
			ReturnForm = FileOperationsSecondUseClient.GetFileReturnForm();
			
			ReturnForm.Parameters.FileRef = FileData.Ref;
			ReturnForm.CommentToVersion   = "";
			
			ReturnForm.File = FileData.Ref;

			If FileData.StoreVersions Then
				ReturnForm.CreateNewVersion = True;
				
				// making check "Don't create new version" disabled
				// If the current user is not an author of the current version				
				If FileData.CurrentVersionAuthor <> FileData.LockedBy Then
					ReturnForm.Items.CreateNewVersion.Enabled = False;
				Else
					ReturnForm.Items.CreateNewVersion.Enabled = True;
				EndIf;			
			Else
				ReturnForm.CreateNewVersion = False;
				ReturnForm.Items.CreateNewVersion.Enabled = False;
			EndIf;	

			Result = ReturnForm.DoModal();
			If TypeOf(Result) <> Type("Structure") Then
				Return False;
			EndIf;	
			
			ReturnCode = Result.ReturnCode;
			If ReturnCode <> DialogReturnCode.OK Then
				Return False;
			EndIf;	
			
			CreateNewVersion = Result.CreateNewVersion;
			CommentToVersion = Result.CommentToVersion;
				
		Else //  CreateNewVersion and CommentToVersion are passed from outside
			
			If FileData.StoreVersions Then
				
				// making check "Don't create new version" disabled
				// If the current user is not an author of the current version				
				If FileData.CurrentVersionAuthor <> FileData.LockedBy Then
					CreateNewVersion = True;
				EndIf;			
				
			Else
				CreateNewVersion = False;
			EndIf;	
			
		EndIf;
		
		OldVersion = FileData.CurrentVersion;
		Interactively = False;
		
		SizeInMB 			 	  = NewVersionFile.Size() / (1024 * 1024);
		ModificationTime 		  = NewVersionFile.GetModificationTime();
		ModificationDateUniversal = NewVersionFile.GetModificationUniversalTime();
		Size 					  = NewVersionFile.Size();
		
		While True Do
			Try
				TemporaryStorageAddress = "";
				SelectedFilePath = "";
				
				FileName = NewVersionFile.Name;
				
				ClarificationText =
				StringFunctionsClientServer.SubstitureParametersInString(
				    NStr("en = 'Transferring file %1 (%2 MB)... Please wait.'"),
				    FileName, ?(SizeInMB >= 1, Format(SizeInMB, "NFD=0"), Format(SizeInMB, "NFD=1; NZ=0")));
				
				Status(ClarificationText);
				
				FilesBeingPlaced = New Array;
				Details = New TransferableFileDescription(FullFilePath, "");
				FilesBeingPlaced.Add(Details);
				
				PlacedFiles = New Array;
				
				If PutFiles(FilesBeingPlaced, PlacedFiles, , Interactively, FormID) Then
					Status();
					
					If PlacedFiles.Count() = 1 Then
						TemporaryStorageAddress = PlacedFiles[0].Location;
					EndIf;
					
					ThisIsWebClient = False;
					
					TextNotExtractedAtClient = False;
					#If WebClient Then
						TextNotExtractedAtClient = True;
					#EndIf	
					
					BaseName  = NewVersionFile.BaseName;
					Extension = NewVersionFile.Extension;

					TextTemporaryStorageAddress = FileFunctionsClient.ExtractTextToTemporaryStorage(
						FullFilePath, FormID);
						
					InOwnerWorkingDirectory = FileData.OwnerWorkingDirectory <> "";	

					DoNotChangeRecordInWorkingDirectory = False;
					If PassedFullFilePath <> "" Then
						DoNotChangeRecordInWorkingDirectory = True;
					EndIf;
					
					FileOperations.SaveAndUnlockFile(
						FileData, 
						CreateNewVersion,
						TemporaryStorageAddress,
						CommentToVersion,
						ModificationTime,
						ModificationDateUniversal,
						Size,
						BaseName,
						Extension,
						FullFilePath,
						TextTemporaryStorageAddress,
						ThisIsWebClient,
						TextNotExtractedAtClient,
						InOwnerWorkingDirectory,
						DoNotChangeRecordInWorkingDirectory,
						FormID);
					
					NewVersion = FileData.CurrentVersion;
					
					If PassedFullFilePath = "" Then
						DeleteFileFromFilesLocalCacheOnEditEnd = FileOperationsSecondUseClient.GetFileOperationsPersonalSettings().DeleteFileFromFilesLocalCacheOnEditEnd;
						If DeleteFileFromFilesLocalCacheOnEditEnd = Undefined Then
							DeleteFileFromFilesLocalCacheOnEditEnd = False;
						EndIf;
						
						If FileData.OwnerWorkingDirectory <> "" Then
							DeleteFileFromFilesLocalCacheOnEditEnd = False;
						EndIf;
						
						If DeleteFileFromFilesLocalCacheOnEditEnd Then
							FileFunctionsClient.DeleteFileFromWorkingDirectory(OldVersion);
						Else
							File = New File(FullFilePath);
							File.SetReadOnly(True);	
						EndIf;
					EndIf;
					
					If ShowAlert Then
						ShowUserNotification(
							NStr("en = 'Finished Editing'"),
							FileData.URL,
							StringFunctionsClientServer.SubstitureParametersInString(
								NStr("en = '%1 file has been updated and unlocked.'"),
									String(FileData.Ref)),
								PictureLib.Information32);
					EndIf;		
					
					// delete encrypted file from cache
					If FileData.Encrypted Then
						DeleteFile(FullFilePath);	
					EndIf;	
					
					Return True;
				Else
					Status();
					Return False;
				EndIf;

			Except

				ErrorInformation = ErrorInfo();
				
				If ErrorInformation.Cause = Undefined Then
					ErrorMessage = ErrorInformation.Description;
				Else
					ErrorMessage = ErrorInformation.Cause.Description;
				EndIf;

				QuestionText = "";
							 
				QuestionText = StringFunctionsClientServer.SubstitureParametersInString(
					NStr("en = 'Unable to %1 save file back into infobase because of: %2. Do you want to repeat the operation?'"),
					String(FileData.Ref), ErrorMessage);
				
				ReturnCode = DoQueryBox(QuestionText, QuestionDialogMode.RetryCancel);
				
				If ReturnCode = DialogReturnCode.Cancel Then
					Return False;
				EndIf;
				
			EndTry;
		EndDo;
		
	EndIf;
	
	Return True;
	
EndFunction

// Procedure releases the file. File file is not being
// updated, but its current holder is being cleared. Action is performed by the refs array.
Procedure UnlockFilesByRefs(Val FilesArray) Export
	
	CommonUseClient.SuggestWorkWithFilesExtensionInstallationNow();
	
	// Get array of file data
	FilesData = New Array;
	FileOperations.GetDataForFilesArray(FilesArray, FilesData);
	UBoundArray  = FilesData.UBound();
	
	For Ind = 0 To UBoundArray Do
		FileData = FilesData[UBoundArray - Ind];
		
		ErrorString = "";
		If Not CanUnlockFile(FileData.Ref, FileData.LockedByCurrentUser, FileData.LockedBy, ErrorString) Then
			FilesData.Delete(UBoundArray - Ind);
		EndIf;
		
	EndDo;	
	
	IsExtensionAttached = AttachFileSystemExtension();
	
	Result = DoQueryBox(
	  	NStr("en = 'Cancel files editing will cause unsaved changes to be lost. Do you want to continue?'"),
		QuestionDialogMode.YesNo, , DialogReturnCode.No);
	
	If Result <> DialogReturnCode.Yes Then
		Return;
	EndIf;	
	
	// Unlocking files
	For Each FileData In FilesData Do
		
		DoNotAskQuestion = True;
		
		UnlockFile(FileData.Ref, FileData.StoreVersions,
			FileData.LockedByCurrentUser, FileData.LockedBy,
			Undefined, DoNotAskQuestion);
	
	EndDo;
	
	ShowUserNotification(  
		NStr("en = 'Cancel Files Editing'"),
		,
		StringFunctionsClientServer.SubstitureParametersInString(
			NStr("en = 'Canceled editing %1 of %2 files.'"), 
			FilesData.Count(), FilesArray.Count()),
		PictureLib.Information32);
	
EndProcedure //UnlockFilesByRefs

// Procedure releases the file. File file is not being
// updated, but its current holder is being cleared.
Procedure UnlockFile(ObjectRef, Val StoreVersions = Undefined,
	Val LockedByCurrentUser = Undefined, Val LockedBy = Undefined,
	UUID = Undefined, DoNotAskQuestion = False) Export
	
	Var FileData;
	
	CommonUseClient.SuggestWorkWithFilesExtensionInstallationNow();	
	
	If StoreVersions = Undefined Then
		FileData            = FileOperations.GetFileData(ObjectRef);
		StoreVersions       = FileData.StoreVersions;
		LockedByCurrentUser = FileData.LockedByCurrentUser;
		LockedBy            = FileData.LockedBy;
	EndIf;

	ErrorString = "";
	If Not CanUnlockFile(ObjectRef, LockedByCurrentUser, LockedBy, ErrorString) Then
		DoMessageBox(ErrorString);
		Return;
	EndIf;
	
	ContinueWork = True;
	
	If DoNotAskQuestion = False Then
		
		Result = DoQueryBox(
		  StringFunctionsClientServer.SubstitureParametersInString(
		    NStr("en = 'Cancel files editing will cause unsaved changes to be lost. Do you want to continue?'"), String(ObjectRef)),
		QuestionDialogMode.YesNo, , DialogReturnCode.No);
		
		If Result <> DialogReturnCode.Yes Then
			ContinueWork = False;
		EndIf;	
		
	EndIf;	
	
	If ContinueWork Then
		
		IsExtensionAttached = AttachFileSystemExtension();
		
		FileOperations.GetFileDataAndUnlockFile(ObjectRef, FileData, UUID);
		
		If IsExtensionAttached Then
			ForRead = True;
			InOwnerWorkingDirectory = FileData.OwnerWorkingDirectory <> "";
			ReregisterFileInWorkingDirectory(FileData, ForRead, InOwnerWorkingDirectory);
		EndIf;
		
		If Not DoNotAskQuestion Then
			ShowUserNotification(
				NStr("en = 'File Unlocked'"),
				FileData.URL,
				FileData.VersionDetails,
				PictureLib.Information32);
		EndIf;	
		
	EndIf;
	
EndProcedure // UnlockFile()

// Procedure releases the file. File file is not being
// updated, but its current holder is being cleared.
Procedure UnlockFileWithoutQuestion(FileData, UUID = Undefined) Export
	
	FileOperations.UnlockFile(FileData, UUID);
	
	IsExtensionAttached = AttachFileSystemExtension();
	If IsExtensionAttached Then
		ForRead = True;
		InOwnerWorkingDirectory = FileData.OwnerWorkingDirectory <> "";
		ReregisterFileInWorkingDirectory(FileData, ForRead, InOwnerWorkingDirectory);
	EndIf;
	
	ShowUserNotification(
		NStr("en = 'File Unlocked'"),
		FileData.URL,
		FileData.VersionDetails,
		PictureLib.Information32);
	
EndProcedure // UnlockFile()

// Procedure releases files by the refs array
//
Procedure UnlockFiles(ObjectsRef) Export
	
	ListImpossibleToRelease = New ValueList;

	// Get array of file data
	FilesData	 = FileOperations.GetFileData(ObjectsRef);
	UBoundArray  = FilesData.UBound();	
	
	For Ind = 0 To UBoundArray Do
		FileData = FilesData[UBoundArray - Ind];
		
		ErrorString = "";
		If Not CanUnlockFile(
				FileData.Ref, 
				FileData.LockedByCurrentUser, 
				FileData.LockedBy, 
				ErrorString) Then // impossible to release
			
			ListImpossibleToRelease.Add(FileData.Ref, ErrorString);
			FilesData.Delete(UBoundArray - Ind);
		EndIf;
	EndDo;
	
	// displaying a dialog if can not unlock the file
	If ListImpossibleToRelease.Count() > 0 Then 
		If Not QuestionWithFilesListDialog(
				ListImpossibleToRelease, 
				NStr("en = 'The following errors occurred while attempting to unlock files: '"),
				NStr("en = 'Unlock Files'"),
				NStr("en = 'Unlock Files'")) Then
			Return;
		EndIf;
	Else
		Response = DoQueryBox(
			NStr("en = 'Unlocking files will cause unsaved changes to be lost. Do you want to release files?'"),
			QuestionDialogMode.YesNo, , DialogReturnCode.No);

		If Response = DialogReturnCode.No Then
			Return;
		EndIf;
	EndIf;
	
	IsExtensionAttached = AttachFileSystemExtension();
	
	// Release files
	For Each FileData In FilesData Do
		
		FileOperations.UnlockFile(FileData);
		
		If IsExtensionAttached Then
			ForRead					= True;
			InOwnerWorkingDirectory = FileData.OwnerWorkingDirectory <> "";
			ReregisterFileInWorkingDirectory(FileData, ForRead, InOwnerWorkingDirectory);
		EndIf;
		
		ShowUserNotification(
			NStr("en = 'File Unlocked'"),
			FileData.URL,
			FileData.VersionDetails,
			PictureLib.Information32);
		
	EndDo;
	
EndProcedure

// Procedure performs moving of files to a different folder - by the refs array
//
Procedure MoveFilesToFolder(ObjectsRef, Folder) Export
	
	// Get array of file data
	FilesData = FileOperations.GetFileData(ObjectsRef);

	For Each FileData In FilesData Do
		
		FileOperations.MoveFileToFolder(FileData, Folder);
		
		ShowUserNotification(
			NStr("en = 'Moving File'"),
			FileData.URL,
			StringFunctionsClientServer.SubstitureParametersInString(
			    NStr("en = '%1 file moved to %2 folder.'"), String(FileData.Ref), String(Folder)),
				PictureLib.Information32);

	EndDo;	
		
EndProcedure	

// Function parses string into array of strings, using "./\" as separator
Function SplitStringByDotsAndSlashes(Val Presentation)
	Var CurrentPosition;

	Parts = New Array;
	
	StartPosition = 1;
	
	For CurrentPosition = 1 To StrLen(Presentation) Do
		CurrentChar = Mid(Presentation, CurrentPosition, 1);
		If CurrentChar = "." Or CurrentChar = "/" Or CurrentChar = "\" Then
			CurrentPart 	= Mid(Presentation, StartPosition, CurrentPosition - StartPosition);
			StartPosition	= CurrentPosition + 1;
			Parts.Add(CurrentPart);
		EndIf;	
	EndDo;	
	
	If StartPosition <> CurrentPosition Then
		CurrentParticle = Mid(Presentation, StartPosition, CurrentPosition - StartPosition);
		Parts.Add(CurrentPart);
	EndIf;	
		
	Return Parts;
EndFunction

// Publish - by the refs array
//
Procedure SaveFileByRefs(Val FilesArray, FormID) Export
	
	CommonUseClient.SuggestWorkWithFilesExtensionInstallationNow();
	
	// Get array of file data
	FilesData 	 = New Array;
	FileOperations.GetDataForFilesArray(FilesArray, FilesData);
	UBoundArray  = FilesData.UBound();
	
	For Ind = 0 To UBoundArray Do
		FileData = FilesData[UBoundArray - Ind];
		
		// Check possibility to release the file
		ErrorString = "";
		If Not CanUnlockFile(FileData.Ref, FileData.LockedByCurrentUser, FileData.LockedBy, ErrorString) Then
			FilesData.Delete(UBoundArray - Ind);
		EndIf;
		
	EndDo;	
	
	IsExtensionAttached = AttachFileSystemExtension();
	
	
	ReturnForm = FileOperationsSecondUseClient.GetFileReturnForm();
	
	ReturnForm.Parameters.FileRef = Undefined;
	ReturnForm.CommentToVersion = "";

	ReturnForm.File = Undefined;

	ReturnForm.CreateNewVersion = True;
	ReturnForm.Items.CreateNewVersion.Enabled = True;

	Result = ReturnForm.DoModal();
	If TypeOf(Result) <> Type("Structure") Then
		Return;
	EndIf;	
	
	ReturnCode = Result.ReturnCode;
	If ReturnCode <> DialogReturnCode.OK Then
		Return;
	EndIf;	
	
	CreateNewVersion = Result.CreateNewVersion;
	CommentToVersion = Result.CommentToVersion;
	
	For Each Data In FilesData Do
		
		ShowAlert = False;
		
		SaveFile(Data.Ref, 
				 FormID, 
				 Data.StoreVersions,
				 Data.LockedByCurrentUser, 
				 Data.LockedBy,
				 Data.CurrentVersionAuthor,
				 "",
				 CreateNewVersion,
				 CommentToVersion,
				 ShowAlert);
	EndDo;
	
	ShowUserNotification(  
		NStr("en = 'Save File Changes'"),
		,
		StringFunctionsClientServer.SubstitureParametersInString(
			NStr("en = 'Changed in %1 of %2 files saved.'"), 
			FilesData.Count(), FilesArray.Count()),
		PictureLib.Information32);
	
EndProcedure //SaveFileByRefs

// Procedure publishes file without releasing it
//
// Parameters:
//
Procedure SaveFile(ObjectRef, FormID, Val StoreVersions = Undefined,
				   Val LockedByCurrentUser	= Undefined, 
				   Val LockedBy 			= Undefined,
				   Val CurrentVersionAuthor = Undefined,
				   PassedFullFilePath = "",
				   CreateNewVersion   = Undefined,
				   CommentToVersion   = Undefined,
				   ShowAlert 		  = True) Export
			
	Var FileData;
	Var TemporaryStorageAddress;
	
	CommonUseClient.SuggestWorkWithFilesExtensionInstallationNow();	

	IsExtensionAttached 	  = AttachFileSystemExtension();
	IsCryptoExtensionAttached = AttachCryptoExtension();
	
	If Not IsExtensionAttached Then  // web client with no work with files extension

		If StoreVersions = Undefined Then
			FileData 				= FileOperations.GetFileData(ObjectRef);
			StoreVersions 			= FileData.StoreVersions;
			LockedByCurrentUser 	= FileData.LockedByCurrentUser;
			LockedBy 				= FileData.LockedBy;
			CurrentVersionAuthor	= FileData.CurrentVersionAuthor;
		EndIf;

		// Check possibility to release the file
		ErrorString = "";
		If Not CanUnlockFile(ObjectRef, LockedByCurrentUser, LockedBy, ErrorString) Then
			DoMessageBox(ErrorString);
			Return;
		EndIf;
		
		FullFilePath = "";

		If CreateNewVersion = Undefined Then
			
			// Request comment and version storing flag
			ReturnForm = FileOperationsSecondUseClient.GetFileReturnForm();
			
			ReturnForm.Parameters.FileRef = ObjectRef;
			ReturnForm.CommentToVersion = "";

			ReturnForm.File = ObjectRef;

			If StoreVersions Then
				ReturnForm.CreateNewVersion = True;
				
				// making check "Don't create new version" disabled
				// If the current user is not an author of the current version				
				If CurrentVersionAuthor <> LockedBy Then
					ReturnForm.Items.CreateNewVersion.Enabled = False;
				Else
					ReturnForm.Items.CreateNewVersion.Enabled = True;
				EndIf;			
			Else
				ReturnForm.CreateNewVersion = False;
				ReturnForm.Items.CreateNewVersion.Enabled = False;
			EndIf;	

			Result = ReturnForm.DoModal();
			If TypeOf(Result) <> Type("Structure") Then
				Return;
			EndIf;	
			
			ReturnCode = Result.ReturnCode;
			If ReturnCode <> DialogReturnCode.OK Then
				Return;
			EndIf;	
			
			CreateNewVersion = Result.CreateNewVersion;
			CommentToVersion = Result.CommentToVersion;
			
		Else //  CreateNewVersion and CommentToVersion are passed from outside
			
			If StoreVersions Then
				
				// making check "Don't create new version" disabled
				// If the current user is not an author of the current version				
				If CurrentVersionAuthor <> LockedBy Then
					CreateNewVersion = True;
				EndIf;			
				
			Else
				CreateNewVersion = False;
			EndIf;	
			
		EndIf;
		
		Interactively = True;
		
		SelectedFilePath = "";
		ShowTipsBeforePutFile();
		If PutFile(TemporaryStorageAddress, FullFilePath, SelectedFilePath, Interactively, FormID) Then
			
			BaseName 		  = "";
			Extension 		  = "";
			ModificationTime  = CurrentDate(); // Because we can't get file modification date on disk
			ModificationDateUniversal = ToUniversalTime(CurrentDate());
			FileSize 		  = 0; // Because we can't get file size on disk
			
			RelativeFilePath = "";
			TextTemporaryStorageAddress = "";

			PathParts = SplitStringByDotsAndSlashes(SelectedFilePath);
			If PathParts.Count() >= 2 Then
				Extension = PathParts[PathParts.Count()-1];
				BaseName  = PathParts[PathParts.Count()-2];
			EndIf;

			ThisIsWebClient = True;
			
			TextNotExtractedAtClient = False;
			#If WebClient Then
				TextNotExtractedAtClient = True;
			#EndIf	
			
			InOwnerWorkingDirectory = False;
			
			FileOperations.GetFileDataAndSaveFile(
				ObjectRef, 
				FileData,
				CreateNewVersion,
				TemporaryStorageAddress,
				CommentToVersion,
				ModificationTime,
				ModificationDateUniversal,
				FileSize,
				BaseName,
				Extension,
				RelativeFilePath,
				FullFilePath,
				TextTemporaryStorageAddress,
				ThisIsWebClient,
				TextNotExtractedAtClient,
				InOwnerWorkingDirectory,
				FormID);
				
			If ShowAlert Then
				ShowUserNotification(
					NStr("en = 'New Version Saved'"),
					FileData.URL,
					FileData.VersionDetails,
					PictureLib.Information32);
			EndIf;	
		
		EndIf;

	Else // below code for thin, thick clients or web client with installed extension

		FileData = FileOperations.GetFileDataAndWorkingDirectory(ObjectRef);
		
		StoreVersions = FileData.StoreVersions;
	
		// Check possibility to release the file
		ErrorString = "";
		If Not CanUnlockFile(FileData.Ref, FileData.LockedByCurrentUser, FileData.LockedBy, ErrorString) Then
			DoMessageBox(ErrorString);
			Return;
		EndIf;

		FullFilePath = PassedFullFilePath;
		If FullFilePath = "" Then
			FullFilePath = FileFunctionsClient.GetFullFilePathInWorkingDirectory(FileData);
		EndIf;
		
		DoNotChangeRecordInWorkingDirectory = False;
		If PassedFullFilePath <> "" Then
			DoNotChangeRecordInWorkingDirectory = True;
		EndIf;
		
		// Check if file exists on disk
		NewVersionFile = New File(FullFilePath);
		If Not NewVersionFile.Exist() Then
			
			WarningString = StringFunctionsClientServer.SubstitureParametersInString(
			    NStr("en = 'Loading %1 file into infobase failed because the file is not found at the local computer.'"),
			    String(FileData.Ref));
			If Not IsBlankString(FullFilePath) Then
				WarningString = WarningString + " (" + FullFilePath + ").";	
			Else
				WarningString = WarningString + ".";	
			EndIf;
			
			WarningString = WarningString + Chars.LF + NStr("en = 'Release file?'");
			                                                        			
			ReturnCode = DoQueryBox(WarningString, QuestionDialogMode.YesNo);
			
			If ReturnCode = DialogReturnCode.Yes Then
				UnlockFileWithoutQuestion(FileData, FormID);
			EndIf;
				
			Return;
			
		EndIf;
		
		// Request comment and version storing flag
		If CreateNewVersion = Undefined Then

			ReturnForm = FileOperationsSecondUseClient.GetFileReturnForm();
			ReturnForm.Parameters.FileRef = FileData.Ref;
			ReturnForm.CommentToVersion = "";

			ReturnForm.File = FileData.Ref;

			If FileData.StoreVersions Then
				ReturnForm.CreateNewVersion = True;
				
				// making check "Don't create new version" disabled
				// If the current user is not an author of the current version								
				If FileData.CurrentVersionAuthor <> FileData.LockedBy Then
					ReturnForm.Items.CreateNewVersion.Enabled = False;
				Else
					ReturnForm.Items.CreateNewVersion.Enabled = True;
				EndIf;			
			Else
				ReturnForm.CreateNewVersion = False;
				ReturnForm.Items.CreateNewVersion.Enabled = False;
			EndIf;	
			
			Result = ReturnForm.DoModal();
			If TypeOf(Result) <> Type("Structure") Then
				Return;
			EndIf;	
			
			ReturnCode = Result.ReturnCode;
			If ReturnCode <> DialogReturnCode.OK Then
				Return;
			EndIf;	
			
			CreateNewVersion = Result.CreateNewVersion;
			CommentToVersion = Result.CommentToVersion;
			
		Else //  CreateNewVersion and CommentToVersion are passed from outside
			
			If StoreVersions Then
				
				// If author of  the current version - is not current user - then make checkmark "Don't create new version" disabled
				If CurrentVersionAuthor <> LockedBy Then
					CreateNewVersion = True;
				EndIf;			
				
			Else
				CreateNewVersion = False;
			EndIf;	
			
		EndIf;
			
		Interactively = False;
		SelectedFilePath = "";
		
		FileNameWithPathTemporary = "";
		
		SizeInMB 			= NewVersionFile.Size() / (1024 * 1024);
		ModificationTime 	= NewVersionFile.GetModificationTime();
		ModificationDateUniversal 	= NewVersionFile.GetModificationUniversalTime();
		FileSize 			= NewVersionFile.Size();
		
		FileName = NewVersionFile.Name;
		
		ClarificationText =
		StringFunctionsClientServer.SubstitureParametersInString(
			NStr("en = 'Moving file %1 (%2 MB)... Please wait.'"),
		    FileName, ?(SizeInMB >= 1, Format(SizeInMB, "NFD=0"), Format(SizeInMB, "NFD=1; NZ=0")));
		
		Status(ClarificationText);

		FilesBeingPlaced = New Array;
		Details = New TransferableFileDescription(FullFilePath, "");
		FilesBeingPlaced.Add(Details);
		
		PlacedFiles = New Array;
		
		If PutFiles(FilesBeingPlaced, PlacedFiles, , Interactively, FormID) Then
			Status();
			
			If PlacedFiles.Count() = 1 Then
				TemporaryStorageAddress = PlacedFiles[0].Location;
			EndIf;

			InitializeWorkingDirectoryPath();
			DirectoryName = FileOperationsSecondUseClient.GetFileOperationsPersonalSettings().LocalFilesCachePath;
			
			RelativeFilePath = "";
			
			BaseName  = NewVersionFile.BaseName;
			Extension = NewVersionFile.Extension;
			
			InOwnerWorkingDirectory = FileData.OwnerWorkingDirectory <> "";
			
			If FileData.OwnerWorkingDirectory <> "" Then // there is working directory
				RelativeFilePath = FullFilePath;
			Else
				CharPosition = Find(FullFilePath, DirectoryName);
				If CharPosition <> 0 Then
					RelativeFilePath = Mid(FullFilePath, StrLen(DirectoryName) + 1);
				EndIf;
			EndIf;
			
			TextTemporaryStorageAddress = FileFunctionsClient.ExtractTextToTemporaryStorage(
				FullFilePath, FormID);

			ThisIsWebClient = False;
			
			TextNotExtractedAtClient = False;
			#If WebClient Then
				TextNotExtractedAtClient = True;
			#EndIf	
			
			FileOperations.SaveFile(
				FileData.Ref, 
				CreateNewVersion,
				TemporaryStorageAddress,
				CommentToVersion,
				ModificationTime,
				ModificationDateUniversal,
				FileSize,
				BaseName,
				Extension,
				RelativeFilePath,
				FullFilePath,
				TextTemporaryStorageAddress,
				ThisIsWebClient,
				TextNotExtractedAtClient,
				InOwnerWorkingDirectory,
				DoNotChangeRecordInWorkingDirectory,
				FormID);
				
			If ShowAlert Then
				ShowUserNotification(
					NStr("en = 'New Version Saved'"),
					FileData.URL,
					FileData.VersionDetails,
					PictureLib.Information32);
			EndIf;	
				
			// delete encrypted file from cache
			If FileData.Encrypted Then
				MoveFile(FileNameWithPathTemporary, FullFilePath);
			EndIf;	
				
		Else
			Status();
		EndIf;
		
	EndIf;
EndProcedure // SaveFile()

// Procedure for interactive creation of a new File
// In particular, choice dialog of File creation mode is being called
// Parameters:
//	FileOwner - defines group, where Item is created, if
//		group is unknown at the time when method is called - it will be equal to Undefined
Procedure CreateNewFile(FileOwner, FormOwner, CreationMode = 1, DoNotOpenCardAfterCreateFromFile = Undefined) Export
	Form = FileOperationsSecondUseClient.GetChoiceNewItemFormFileCreateVariant();

	Form.CreationMode = CreationMode;
	Result = Form.DoModal();
	
	If Result = DialogReturnCode.Yes Then
		
		CreateFile(Form.CreationMode, FileOwner, FormOwner, DoNotOpenCardAfterCreateFromFile);
		
	EndIf;
	
EndProcedure // CreateNewFile()

// Procedure copies existing File
// Parameters:
//	FileBasis - where the File (type - CatalogRef) is being copied from
Procedure CopyFile(FileOwner, FileBasis) Export
	
	Parameters = New Structure("FileBasis, FileOwner", FileBasis, FileOwner);
	Form = OpenForm("Catalog.Files.ObjectForm", Parameters);
	
EndProcedure // CopyFile()

// If File for the current version is in working directory
Function FileIsInFilesLocalCache(FileData, CurrentVersion, FileNameWithPath, ReadonlyInWorkingDirectory, InOwnerWorkingDirectory)
	FileNameWithPath = "";
	
	// If this is an active version - take it from FileData
	If FileData <> Undefined And FileData.CurrentVersion = CurrentVersion Then
		FileNameWithPath = FileData.FileNameWithPathInWorkingDirectory;
		ReadonlyInWorkingDirectory = FileData.ReadonlyInWorkingDirectory;
	Else
		ReadonlyInWorkingDirectory = True;
		DirectoryName = FileOperationsSecondUseClient.GetFileOperationsPersonalSettings().LocalFilesCachePath;
		// Trying to find this record in information register
		FileNameWithPath = FileOperations.GetFileNameWithPathFromRegister(CurrentVersion, DirectoryName, ReadonlyInWorkingDirectory, InOwnerWorkingDirectory);
	EndIf;
	
	If FileNameWithPath <> "" Then
		// Need to check if file exists on disk in this case
		FileOnDisk = New File(FileNameWithPath);
	    If FileOnDisk.Exist() Then
			Return True;	
		Else
			FileNameWithPath = "";
			// Deleting record from register because file is in register, but not on disk
			FileOperations.DeleteFromRegister(CurrentVersion);
	    EndIf;
	EndIf;
	
	Return False;
EndFunction

// Empty space to file place the file - if there is enough of space, do nothing
Procedure FreePlaceInWorkingDirectory(VersionAttributes)
	#If Not WebClient Then
		MaxSize = FileOperationsSecondUseClient.GetFileOperationsPersonalSettings().LocalFilesCacheMaximumSize;
		
		// If size WorkingDirectory is 0, then there is no restriction
		// and default of 10 MB is not used.
		If MaxSize = 0 Then
			Return;
		EndIf;
		
		InitializeWorkingDirectoryPath();
		DirectoryName = FileOperationsSecondUseClient.GetFileOperationsPersonalSettings().LocalFilesCachePath;
		
		FilesArray = FindFiles(DirectoryName, "*.*");
		
		FileSizesInWorkingDirectory = 0;
		QuantityTotal = 0;
		// Calculate total size of files in working directory
		FileFunctionsClient.CalculateFilesSizeRecursive(DirectoryName, FilesArray, FileSizesInWorkingDirectory, QuantityTotal);
		
		Size = VersionAttributes.Size;
		If FileSizesInWorkingDirectory + Size > MaxSize Then
			FileFunctionsClient.ClearWorkingDirectory(FileSizesInWorkingDirectory, Size, False); // ClearAll = False
		EndIf;
	#EndIf
EndProcedure

// Get File from server and register in local cache
Function GetFromServerAndRegisterInFilesLocalCache(FileData, FileNameWithPath, FileInBaseDate, ForRead, FormID = Undefined)
	
	InOwnerWorkingDirectory = FileData.OwnerWorkingDirectory <> "";
	
	If FileNameWithPath = "" Then
		InitializeWorkingDirectoryPath();
		DirectoryName = FileOperationsSecondUseClient.GetFileOperationsPersonalSettings().LocalFilesCachePath;
		
		// Generate file name with extension
		FileName = FileData.VersionDetails;
		If Not IsBlankString(FileData.Extension) Then 
			FileName = FileFunctionsClient.GetNameWithExtention(FileName, FileData.Extension);
		EndIf;
		
		FileNameWithPath = "";
		If Not IsBlankString(FileName) Then
			FileNameWithPath = FileFunctionsClientServer.GetUniqueNameWithPath(DirectoryName, FileName);
			FileNameWithPath = DirectoryName + FileNameWithPath;
		EndIf;
		
		If IsBlankString(FileName) Then
			Return False;
		EndIf;
	EndIf;
	
	If InOwnerWorkingDirectory = False Then
		// in web client it is impossible to know space available on disk
		#If Not WebClient Then 
			FreePlaceInWorkingDirectory(FileData);
		#EndIf
	EndIf;		

	FileSize = 0;
	
	
	// Write File to directory
	Try
		
		FileAddress = FileData.CurrentVersionURL;
		If FileData.Version <> FileData.CurrentVersion Then 
			FileAddress = FileOperations.GetURLForOpening(FileData.Version, FormID);
		EndIf;
		
		FileName = FileFunctionsClient.GetNameWithExtention(FileData.VersionDetails, FileData.Extension);
		SizeInMB = FileData.Size / (1024 * 1024);
		
		ClarificationText =
		StringFunctionsClientServer.SubstitureParametersInString(
		    NStr("en = 'Moving file %1 (%2 MB)... Please wait'"),
		    FileName, ?(SizeInMB >= 1, Format(SizeInMB, "NFD=0"), Format(SizeInMB, "NFD=1; NZ=0")));
		
		Status(ClarificationText);
		
		FilesBeingTransmitted = New Array;
		Details = New TransferableFileDescription(FileName, FileAddress);
		FilesBeingTransmitted.Add(Details);
		
		FileOnDiskByName = New File(FileNameWithPath);
		FilePath = FileOnDiskByName.Path;
		If Right(FilePath,1) <> "\" Then
			FilePath = FilePath + "\";
		EndIf;
		FileNameWithPath = FilePath + FileName; // extension could be changed
		
		If Not GetFiles(FilesBeingTransmitted,, FilePath, False) Then
			Return False;
		EndIf;
		
		// delete file from temporary storage after getting it
		// in case when files are located on disk (at server)
		If IsTempStorageURL(FileAddress) Then
			DeleteFromTempStorage(FileAddress);
		EndIf;
		
		Status();
		
		// Set file modification time equal to the time in current version
		FileOnDisk = New File(FileNameWithPath);
		FileOnDisk.SetModificationTime(FileInBaseDate);
		
		FileSize = FileOnDisk.Size(); // Because size on disk may differ from the size in db (on adding from web client)
		
		FileOnDisk.SetReadOnly(ForRead);
		
	Except
		DoMessageBox(BriefErrorDescription(ErrorInfo()));
		Return False;
	EndTry;
	
	InitializeWorkingDirectoryPath();
	DirectoryName = FileOperationsSecondUseClient.GetFileOperationsPersonalSettings().LocalFilesCachePath;
	
	FileOperations.AddFilesInWorkingDirectoryRegisterRecord(FileData.Version, FileNameWithPath, DirectoryName, ForRead, FileSize, InOwnerWorkingDirectory);	
	
	Return True;
EndFunction

// Reregister in working directory with another flag ForRead
Procedure ReregisterInWorkingDirectory(CurrentVersion, FileNameWithPath, ForRead, InOwnerWorkingDirectory)
	InitializeWorkingDirectoryPath();
	DirectoryName = FileOperationsSecondUseClient.GetFileOperationsPersonalSettings().LocalFilesCachePath;
	
	FileOperations.AddFilesInWorkingDirectoryRegisterRecord(CurrentVersion, FileNameWithPath, DirectoryName, ForRead, 0, InOwnerWorkingDirectory);	
	File = New File(FileNameWithPath);
	File.SetReadOnly(ForRead);	
EndProcedure

// On renaming File and FileVersion updates info in working directory (file name on disk and in register)
Procedure UpdateInformationInWorkingDirectory(CurrentVersion, NewName) Export
	InitializeWorkingDirectoryPath();
	DirectoryName = FileOperationsSecondUseClient.GetFileOperationsPersonalSettings().LocalFilesCachePath;
	FullFileName = "";
	
	ReadonlyInWorkingDirectory = True;
	InOwnerWorkingDirectory = False;
	FileInWorkingDirectory = FileIsInFilesLocalCache(Undefined, CurrentVersion, FullFileName, ReadonlyInWorkingDirectory, InOwnerWorkingDirectory);
	If FileInWorkingDirectory = False Then
		Return;
	EndIf;
	
	Try
		File 			= New File(FullFileName);
		OnlyName 		= File.Name;
		FileSize 		= File.Size();
		PathWithoutName = Left(FullFileName, StrLen(FullFileName) - StrLen(OnlyName));
		NewFullName 	= PathWithoutName + NewName + File.Extension;
		MoveFile(FullFileName, NewFullName);
		
		FileOperations.DeleteFromRegister(CurrentVersion);
		FileOperations.AddFilesInWorkingDirectoryRegisterRecord(CurrentVersion, NewFullName, DirectoryName, ReadonlyInWorkingDirectory, FileSize, InOwnerWorkingDirectory);
	Except
	EndTry;
	
EndProcedure

// Reregister in working directory with another flag ForRead - if such file exist there
Procedure ReregisterFileInWorkingDirectory(FileData, ForRead, InOwnerWorkingDirectory)
	// If File without file - do nothing in working directory
	If FileData.Version.IsEmpty() Then 
		Return;
	EndIf;

	InitializeWorkingDirectoryPath();
	DirectoryName = FileOperationsSecondUseClient.GetFileOperationsPersonalSettings().LocalFilesCachePath;
	FullFileName = "";
	
	ReadonlyInWorkingDirectory = True;
	FileInWorkingDirectory = FileIsInFilesLocalCache(FileData, FileData.CurrentVersion, FullFileName, ReadonlyInWorkingDirectory, InOwnerWorkingDirectory);
	If FileInWorkingDirectory = False Then
		Return;
	EndIf;
	
	FileOperations.AddFilesInWorkingDirectoryRegisterRecord(FileData.CurrentVersion, FullFileName, DirectoryName, ForRead, 0, InOwnerWorkingDirectory);
	File = New File(FullFileName);
	File.SetReadOnly(ForRead);	
EndProcedure

// Delete file with clearing readonly attribute
Procedure DeleteFile(FullFileName, AskQuestion = Undefined, QuestionHeader = Undefined) Export
	ConfirmWhenDeletingFromLocalFilesCache = FileOperationsSecondUseClient.GetFileOperationsPersonalSettings().ConfirmWhenDeletingFromLocalFilesCache;
	If AskQuestion <> Undefined Then
		ConfirmWhenDeletingFromLocalFilesCache = AskQuestion;
	EndIf;		
	
	If ConfirmWhenDeletingFromLocalFilesCache = True Then
		QuestionText = StringFunctionsClientServer.SubstitureParametersInString(NStr("en = 'Delete %1 file from main working directory?'"), FullFileName);
		
		If QuestionHeader <> Undefined Then
			QuestionText = QuestionHeader + Chars.LF + Chars.LF + QuestionText;
		EndIf;	
		
		If DoQueryBox(QuestionText, QuestionDialogMode.YesNo) = DialogReturnCode.No Then
			Return;
		EndIf;
	EndIf;	
	
	File = New File(FullFileName);
	File.SetReadOnly(False);
	DeleteFiles(FullFileName);
EndProcedure

// Gets File from infobase for reading on local disk - to local cache
// and returns path to this file in parameter
Function GetVersionFileToFilesLocalCacheForRead(FileData, FullFileName, FormID = Undefined)
	
	FullFileName = "";
	ForRead = True;
	
	FileInBaseDate = FileData.ModificationDateUniversal;
	CommonUseClient.ConvertSummerTimeToCurrentTime(FileInBaseDate);
	
	InitializeWorkingDirectoryPath();
	
	ReadonlyInWorkingDirectory = True;
	InOwnerWorkingDirectory = False;
	FileInWorkingDirectory = FileIsInFilesLocalCache(FileData, FileData.Version, FullFileName, ReadonlyInWorkingDirectory, InOwnerWorkingDirectory);
	If Not FileInWorkingDirectory Then
		Return GetFromServerAndRegisterInFilesLocalCache(FileData, FullFileName, FileInBaseDate, ForRead, FormID);
	EndIf;
	
	// Get file path in working directory - with uniqueness check
	FileNameWithPath = FullFileName;
	If FileNameWithPath = "" Then
		DoMessageBox(NStr("en = 'Error placing file into local file cache.'"));
		Return False;
	EndIf;
	
	// Below - we don't know if file exists in working directory.
	// Need to check when it was modified and decide what to do:
	// overwrite, ask user, etc.
	
	VersionFile 	= New File(FullFileName);
	FileOnDiskDate  = VersionFile.GetModificationTime();
	FileSizeOnDisk = VersionFile.Size();
	FileSizeInBase  = FileData.Size;
	
	DatesDifference = FileOnDiskDate - FileInBaseDate;
	If DatesDifference < 0 Then
		DatesDifference = -DatesDifference;
	EndIf;
	
	If DatesDifference <= 1 Then // 1 second - allowed difference (may happen on Win95)
		// Date is equal, but the size is different - wierd, but possible
		If FileSizeInBase <> 0 And FileSizeOnDisk <> FileSizeInBase Then
			
			FormOpenParameters = New Structure;
			FormOpenParameters.Insert("File",                		FileNameWithPath);
			FormOpenParameters.Insert("FilesizeOnServer",     		FileSizeInBase);
			FormOpenParameters.Insert("SizeInWorkingDirectory",     FileSizeOnDisk);
			FormOpenParameters.Insert("Message",            		NStr("en = 'The file size in working directory and at server differ. Overwrite file in the working directory?'"));
			
			Response = OpenFormModal("Catalog.Files.Form.FilesizeInWorkingFolderIsDifferent", FormOpenParameters);
			
			If Response = DialogReturnCode.Yes Then // Overwrite
				DeleteFile(FullFileName);
				Return GetFromServerAndRegisterInFilesLocalCache(FileData, FullFileName, FileInBaseDate, ForRead, FormID);
			ElsIf Response = DialogReturnCode.No Then // Open existing one
				Return True;
			Else  // Exit with no actions
				FullFileName = "";
				Return False;
			EndIf;
		EndIf;
		
		Return True; // All matches - date, and size
	ElsIf FileOnDiskDate < FileInBaseDate Then // In working directory is older one
		If ReadonlyInWorkingDirectory = False Then // In working directory for edit
			
			FormOpenParameters = New Structure;
			FormOpenParameters.Insert("File",                	  FileNameWithPath);
			FormOpenParameters.Insert("ModificationTimeOnServer", FileInBaseDate);
			FormOpenParameters.Insert("InWorkingDirectory",       FileOnDiskDate);
			FormOpenParameters.Insert("Title",            		  NStr("en = 'There is an older file in working directory'"));
			
			Message = NStr("en = 'File at the local computer which is marked as locked for editing has a modification date lower than the one at server. Open the file from local directory or get from server and overwrite it?'");
			FormOpenParameters.Insert("Message", Message);
			
			Response = OpenFormModal("Catalog.Files.Form.NewerFileInWorkingFolder", FormOpenParameters);
			
			If Response = DialogReturnCode.Yes Then  // Open existing one
				Return True;
			ElsIf Response = DialogReturnCode.Cancel Then // Exit with no actions
				FullFileName = "";
				Return False;
			ElsIf Response = DialogReturnCode.No Then  // Overwrite
				DeleteFile(FullFileName);
				Return GetFromServerAndRegisterInFilesLocalCache(FileData, FullFileName, FileInBaseDate, ForRead, FormID);
			EndIf;
		Else // In working directory for read
			// Overwrite without confirmation
			DeleteFile(FullFileName);
			Return GetFromServerAndRegisterInFilesLocalCache(FileData, FullFileName, FileInBaseDate, ForRead, FormID);
		EndIf;
	ElsIf FileOnDiskDate > FileInBaseDate Then // In working directory is newer one (modified by user from outside)
		LockedByCurrentUser = (FileData.LockedBy = FileOperationsSecondUseClient.GetFileOperationsPersonalSettings().CurrentUser);
		If (ReadonlyInWorkingDirectory = False) And LockedByCurrentUser Then // In working directory for edit and is locked by the current user
			Return True; // Do nothing
		Else // In working directory for read
			
			FormOpenParameters = New Structure;
			FormOpenParameters.Insert("File",                	  FileNameWithPath);
			FormOpenParameters.Insert("ModificationTimeOnServer", FileInBaseDate);
			FormOpenParameters.Insert("InWorkingDirectory",       FileOnDiskDate);
			FormOpenParameters.Insert("Title",            		  NStr("en = 'There is a newer file in working directory'"));
			
			Message = NStr("en = 'File at the local computer has a later creation date. It could be modified. Open current file? If no it will be get from server and overwritten.'");
			FormOpenParameters.Insert("Message", Message);
			
			Result = OpenFormModal("Catalog.Files.Form.NewerFileInWorkingFolder", FormOpenParameters);
			
			If Result = DialogReturnCode.Yes Then  // Open existing one
				Return True;
			ElsIf Result = DialogReturnCode.Cancel Then // Exit with no actions
				FullFileName = "";
				Return False;
			ElsIf Result = DialogReturnCode.No Then  // Overwrite
				DeleteFile(FullFileName);
				Return GetFromServerAndRegisterInFilesLocalCache(FileData, FullFileName, FileInBaseDate, ForRead, FormID);
			EndIf;
			
		EndIf;
	EndIf;
	
	Return False;
EndFunction // GetVersionFileToWorkingDirectory()

// Gets File from infobase for edit to a local disk - to local cache
// and returns path to this file in parameter
Function GetVersionFileToFilesLocalCacheForEdit(FileData, FullFileName, FormID = Undefined)
	FullFileName = "";
	ForRead = False;
	
	FileInBaseDate = FileData.ModificationDateUniversal;
	CommonUseClient.ConvertSummerTimeToCurrentTime(FileInBaseDate);
	FileSizeInBase = FileData.Size;
	
	InitializeWorkingDirectoryPath();
	
	ReadonlyInWorkingDirectory = True;
	InOwnerWorkingDirectory = False;
	FileInWorkingDirectory = FileIsInFilesLocalCache(FileData, FileData.Version, FullFileName, ReadonlyInWorkingDirectory, InOwnerWorkingDirectory);
	If FileInWorkingDirectory = False Then
		Return GetFromServerAndRegisterInFilesLocalCache(FileData, FullFileName, FileInBaseDate, ForRead, FormID);
	EndIf;

	// Get file path in working directory - with uniqueness check
	FileNameWithPath = FullFileName;
	If FileNameWithPath = "" Then
		CommonUseClientServer.MessageToUser(NStr("en = 'Error placing file into local file cache.'"));
		Return False;
	EndIf;
	
	// Below - we don't know, that File exists in working directory.
	// Need to check when it was modified and decide what to do:
	// overwrite, ask user, etc.
	
	VersionFile 	= New File(FullFileName);
	FileOnDiskDate = VersionFile.GetModificationTime();
	FileSizeOnDisk = VersionFile.Size();
	
	DatesDifference = FileOnDiskDate - FileInBaseDate;
	If DatesDifference < 0 Then
		DatesDifference = -DatesDifference;
	EndIf;
	
	If DatesDifference <= 1 Then // 1 second is allowed difference (may be on Win95)
		// Date is equal, but the size is different - wierd, but possible
		If FileSizeInBase <> 0 And FileSizeOnDisk <> FileSizeInBase Then
			
			FormOpenParameters = New Structure;
			FormOpenParameters.Insert("File",                	FileNameWithPath);
			FormOpenParameters.Insert("FilesizeOnServer",     	FileSizeInBase);
			FormOpenParameters.Insert("SizeInWorkingDirectory", FileSizeOnDisk);
			FormOpenParameters.Insert("Message",            	NStr("en = 'File size in working directory and at server differ. Overwrite file in the working directory?'"));
			
			Response = OpenFormModal("Catalog.Files.Form.FilesizeInWorkingFolderIsDifferent", FormOpenParameters);
			
			If Response = DialogReturnCode.Yes Then // Overwrite
				DeleteFile(FullFileName);
				Return GetFromServerAndRegisterInFilesLocalCache(FileData, FullFileName, FileInBaseDate, ForRead, FormID);
			ElsIf Response = DialogReturnCode.No Then // Open existing one
				Return True;
			Else // Exit with no actions
				FullFileName = "";
				Return False;
			EndIf;
		EndIf;
		
		// All matches - date, and size
		If ReadonlyInWorkingDirectory = ForRead Then
			Return True;
		Else
			InOwnerWorkingDirectory = FileData.OwnerWorkingDirectory <> "";
			ReregisterInWorkingDirectory(FileData.Version, FileNameWithPath, ForRead, InOwnerWorkingDirectory);
			Return True;
		EndIf;
	ElsIf FileOnDiskDate < FileInBaseDate Then // In working directory is older one
		If ReadonlyInWorkingDirectory = False Then // In working directory for edit
			
			FormOpenParameters = New Structure;
			FormOpenParameters.Insert("File",                	  FileNameWithPath);
			FormOpenParameters.Insert("ModificationTimeOnServer", FileInBaseDate);
			FormOpenParameters.Insert("InWorkingDirectory",       FileOnDiskDate);
			FormOpenParameters.Insert("Title",            		  NStr("en = 'There is an older file in working directory'"));
			
			Message = NStr("en = 'File which is marked as locked for editing has earlier modification date at local computer than the one an server. Open file from local directory? If no it will be get from server and overwritten.'");
			FormOpenParameters.Insert("Message", Message);
			
			Response = OpenFormModal("Catalog.Files.Form.NewerFileInWorkingFolder", FormOpenParameters);
			
			If Response = DialogReturnCode.Yes Then  // Open existing one
				Return True;
			ElsIf Response = DialogReturnCode.Cancel Then // Exit with no actions
				FullFileName = "";
				Return False;
			ElsIf Response = DialogReturnCode.No Then  // Overwrite
				DeleteFile(FullFileName);
				Return GetFromServerAndRegisterInFilesLocalCache(FileData, FullFileName, FileInBaseDate, ForRead, FormID);
			EndIf;
		Else // In working directory for read
			// Overwrite with no request
			DeleteFile(FullFileName);
			Return GetFromServerAndRegisterInFilesLocalCache(FileData, FullFileName, FileInBaseDate, ForRead, FormID);
		EndIf;
	ElsIf FileOnDiskDate > FileInBaseDate Then // In working directory is newer one (modified by user from outside)
		
		If ReadonlyInWorkingDirectory = False Then // In working directory for edit
			Return True; // Do nothing
		Else // In working directory for read
			
			FormOpenParameters = New Structure;
			FormOpenParameters.Insert("File",                			FileNameWithPath);
			FormOpenParameters.Insert("ModificationTimeOnServer",     	FileInBaseDate);
			FormOpenParameters.Insert("InWorkingDirectory",            	FileOnDiskDate);
			FormOpenParameters.Insert("Title",            				NStr("en = 'There is a newer file in working directory'"));
			
			Message = NStr("en = 'Locked for editing file has a later modification date at the local computer than the one at server. Open file form local directory? If no the file will be get from server and overwritten.'");
			FormOpenParameters.Insert("Message", Message);
			
			Response = OpenFormModal("Catalog.Files.Form.NewerFileInWorkingFolder", FormOpenParameters);
			
			If Response = DialogReturnCode.Yes Then  // Open existing one
				Return True;
			ElsIf Response = DialogReturnCode.Cancel Then // Exit with no actions
				FullFileName = "";
				Return False;
			ElsIf Response = DialogReturnCode.No Then  // Overwrite
				DeleteFile(FullFileName);
				Return GetFromServerAndRegisterInFilesLocalCache(FileData, FullFileName, FileInBaseDate, ForRead, FormID);
			EndIf;
			
		EndIf;
	EndIf;
	
	Return False;	
EndFunction // GetVersionFileToWorkingDirectory()

// Gets File from infobase for read to a local disk - into folder working directory
// and returns path to this file in parameter
Function GetVersionFileToWorkingDirectoryForReading(FileData, FullFileName, FormID = Undefined)
	
	Var Version;
	Var PlacementDate;	
	
	ForRead = True;
	InOwnerWorkingDirectory = True;
	
	FileInBaseDate = FileData.ModificationDateUniversal;
	CommonUseClient.ConvertSummerTimeToCurrentTime(FileInBaseDate);
	
	InitializeWorkingDirectoryPath();
	
	If FullFileName = "" Then
		FullFileName = FileData.OwnerWorkingDirectory + FileData.VersionDetails + "." + FileData.Extension;
	EndIf;
	
	// find in working directory by path, but not by FileVersion
	Owner 				= Undefined;
	VersionNo 			= Undefined;
	InRegisterForRead 	= Undefined;
	InRegisterFileCode 	= Undefined;
	InRegisterFolder 	= Undefined;
	FileIsInRegister 	= FileOperations.FindInRegisterByPath(FullFileName, Version, PlacementDate, Owner, VersionNo, 
		InRegisterForRead, InRegisterFileCode, InRegisterFolder);
		
	If FileIsInRegister Then
		// check that file at this path already exists
		FileOnDisk = New File(FullFileName);
		If Not FileOnDisk.Exist() Then
			FileOperations.DeleteFromRegister(Version);
			FileIsInRegister = False;
		EndIf;	
	EndIf;
	
	If Not FileIsInRegister Then // no references to file in register
		
		// check that there already exists file at this path
		FileOnDisk = New File(FullFileName);
		If FileOnDisk.Exist() Then
			
			FileInBaseDate = FileData.ModificationDateUniversal;
			CommonUseClient.ConvertSummerTimeToCurrentTime(FileInBaseDate);
			FileSizeInBase = FileData.Size;

			FileOnDiskDate = FileOnDisk.GetModificationTime();
			FileSizeOnDisk = FileOnDisk.Size();
			
			DatesDifference = FileOnDiskDate - FileInBaseDate;
			If DatesDifference < 0 Then
				DatesDifference = -DatesDifference;
			EndIf;
			
			// size and modification date are identical - use it - register in cache
			If DatesDifference <= 1 And FileSizeInBase = FileSizeOnDisk Then
				FileOnDisk.SetReadOnly(ForRead);
				InitializeWorkingDirectoryPath();
				DirectoryName = FileOperationsSecondUseClient.GetFileOperationsPersonalSettings().LocalFilesCachePath;
				FileOperations.AddFilesInWorkingDirectoryRegisterRecord(FileData.Version, FullFileName, DirectoryName, ForRead, FileSizeInBase, InOwnerWorkingDirectory);
				Return True;	// use existing on disk file
			EndIf;
			
			If DatesDifference > 1 Then
				
				FormOpenParameters = New 								Structure;
				FormOpenParameters.Insert("File",                		FullFileName);
				FormOpenParameters.Insert("ModificationTimeOnServer",   FileInBaseDate);
				FormOpenParameters.Insert("InWorkingDirectory",         FileOnDiskDate);
				
				If FileOnDiskDate < FileInBaseDate Then
					FormOpenParameters.Insert("Title", NStr("en = 'There is an older file in working directory'"));
				Else	
					FormOpenParameters.Insert("Title", NStr("en = 'There is a newer file in working directory'"));
				EndIf;	
				
				Message = StringFunctionsClientServer.SubstitureParametersInString(NStr("en = '%1 file already exists in working directory on local computer but its modification time differs from the one in infobase. Open file from local directory? If no it will be get it from infobase and overwritten.'"),
					String(FileData.Ref));
				FormOpenParameters.Insert("Message", Message);
				
				Response = OpenFormModal("Catalog.Files.Form.NewerFileInWorkingFolder", FormOpenParameters);
				
				If Response = DialogReturnCode.Yes Then  // Open existing one
					FileOnDisk.SetReadOnly(ForRead);
					InitializeWorkingDirectoryPath();
					DirectoryName = FileOperationsSecondUseClient.GetFileOperationsPersonalSettings().LocalFilesCachePath;
					FileOperations.AddFilesInWorkingDirectoryRegisterRecord(FileData.Version, FullFileName, DirectoryName, ForRead, FileSizeInBase, InOwnerWorkingDirectory);
					Return True;
				ElsIf Response = DialogReturnCode.Cancel Or Response = Undefined Then // Exit with no actions
					FullFileName = "";
					Return False;
				ElsIf Response = DialogReturnCode.No Then  // Overwrite
					DeleteFile(FullFileName);
					Return GetFromServerAndRegisterInWorkingDirectory(FileData, FullFileName, FileInBaseDate, ForRead, FormID);
				EndIf;
									  
    		Else
				MessageString = StringFunctionsClientServer.SubstitureParametersInString(
					NStr("en = '%3 file already exists ing working directory but its size differs from the one at server.
                          |File size in working directory: %1
                          |File size at server: %2
                          |Rename file or move it to another directory.'"),
				        FileSizeOnDisk, FileSizeInBase, FullFileName);			
									  
				DoMessageBox(MessageString);
				Return False; // cancel operation
								  
			EndIf;					  
		EndIf;	
		
		// no reference to File in register and no file on disk as well
		Return GetFromServerAndRegisterInWorkingDirectory(FileData, FullFileName, FileInBaseDate, ForRead, FormID);
	EndIf; // no reference to File in register
	
	
	// File by path in working directory has a reference in information register
	If Version <> FileData.CurrentVersion Then // there is file of another FileVersion in working directory (or another File object at all)
		
		If Owner = FileData.Ref And InRegisterForRead = True Then // the same File on disk, but of different FileVersion - and it is for read
			Return GetFromServerAndRegisterInWorkingDirectory(FileData, FullFileName, FileInBaseDate, ForRead, FormID);
		EndIf;
		
		MessageString = "";
			
		MessageString = StringFunctionsClientServer.SubstitureParametersInString(
			NStr("en = 'The working directory already contains %1 file linked to another infobase File object. 
                  | File code at server: %2
                  | File code at local computer: %3'"),
			FullFileName,
			FileData.FileCode, 
			InRegisterFileCode);			
							  
		If FileData.Owner = InRegisterFolder Then // the same folder
			MessageString = MessageString + Chars.LF + NStr("en = 'Rename one of files in the database.'");
		Else
			MessageString = MessageString + Chars.LF + NStr("en = 'Change working directory of one of folders in the infobase. 
                                                             |(Two folders cannot have the same working directory).'");
		EndIf;	
								  
		DoMessageBox(MessageString);
		Return False;
		
	Else // File by path in working directory - is of required version and it has ref in register
		
		// Below - we don't know, that File exists in working directory.
		// Need to check when it was modified and decide what to do
		// overwrite, ask user, etc.
		
		FileNameWithPath = FullFileName;
		ReadonlyInWorkingDirectory = InRegisterForRead;
	
		VersionFile 	= New File(FullFileName);
		FileOnDiskDate = VersionFile.GetModificationTime();
		FileSizeOnDisk = VersionFile.Size();
		FileSizeInBase  = FileData.Size;
		
		DatesDifference = FileOnDiskDate - FileInBaseDate;
		If DatesDifference < 0 Then
			DatesDifference = -DatesDifference;
		EndIf;
		
		If DatesDifference <= 1 Then // 1 second - allowed difference (may be on Win95)
			// Date is equal, but the size is different - wierd, but possible
			If FileSizeInBase <> 0 And FileSizeOnDisk <> FileSizeInBase Then
				
				FormOpenParameters = New Structure;
				FormOpenParameters.Insert("File",                		FileNameWithPath);
				FormOpenParameters.Insert("FilesizeOnServer",     		FileSizeInBase);
				FormOpenParameters.Insert("SizeInWorkingDirectory",     FileSizeOnDisk);
				FormOpenParameters.Insert("Message",            		NStr("en = 'File size in working directory and server is different. ""Would you like to replace the existing file?'"));
				
				Response = OpenFormModal("Catalog.Files.Form.FilesizeInWorkingFolderIsDifferent", FormOpenParameters);
				
				If Response = DialogReturnCode.Yes Then // Overwrite
					DeleteFile(FullFileName, False); // setting of delete confirmation is not used in working directory
					Return GetFromServerAndRegisterInFilesLocalCache(FileData, FullFileName, FileInBaseDate, ForRead, FormID);
				ElsIf Response = DialogReturnCode.No Then // Open existing one
					Return True;
				Else  // Exit with no actions
					FullFileName = "";
					Return False;
				EndIf;
			EndIf;
			
			Return True; // All matches - date, and size
		ElsIf FileOnDiskDate < FileInBaseDate Then // In working directory is older one
			If ReadonlyInWorkingDirectory = False Then // In working directory for edit
				
				FormOpenParameters = New Structure;
				FormOpenParameters.Insert("File",                			FileNameWithPath);
				FormOpenParameters.Insert("ModificationTimeOnServer",     	FileInBaseDate);
				FormOpenParameters.Insert("InWorkingDirectory",           	FileOnDiskDate);
				FormOpenParameters.Insert("Title",            				NStr("en = 'There is an older file in working directory'"));
				
				Message = NStr("en = 'The locked for editing file at local computer has earlier modification date than the one at server. Open file from local directory? If no it will be get from server and overwritten.'");
				FormOpenParameters.Insert("Message", Message);
				
				Response = OpenFormModal("Catalog.Files.Form.NewerFileInWorkingFolder", FormOpenParameters);
				
				If Response = DialogReturnCode.Yes Then  // Open existing one
					Return True;
				ElsIf Response = DialogReturnCode.Cancel Then // Exit with no actions
					FullFileName = "";
					Return False;
				ElsIf Response = DialogReturnCode.No Then  // Overwrite
					DeleteFile(FullFileName, False); // setting of delete confirmation is not used in working directory
					Return GetFromServerAndRegisterInFilesLocalCache(FileData, FullFileName, FileInBaseDate, ForRead, FormID);
				EndIf;
			Else // In working directory for read
				// Overwrite with no request
				DeleteFile(FullFileName, False); // setting of delete confirmation is not used in working directory
				Return GetFromServerAndRegisterInFilesLocalCache(FileData, FullFileName, FileInBaseDate, ForRead, FormID);
			EndIf;
		ElsIf FileOnDiskDate > FileInBaseDate Then // In working directory is newer one (modified by user from outside)
			LockedByCurrentUser = (FileData.LockedBy = FileOperationsSecondUseClient.GetFileOperationsPersonalSettings().CurrentUser);
			If (ReadonlyInWorkingDirectory = False) And LockedByCurrentUser Then // In working directory for edit and is locked by the current user
				Return True; // Do nothing
			Else // In working directory for read
				
				FormOpenParameters = New Structure;
				FormOpenParameters.Insert("File",                			FileNameWithPath);
				FormOpenParameters.Insert("ModificationTimeOnServer",     	FileInBaseDate);
				FormOpenParameters.Insert("InWorkingDirectory",            	FileOnDiskDate);
				FormOpenParameters.Insert("Title",            				NStr("en = 'There is a newer file in working directory'"));
				
				Message = NStr("en = 'File at the local computer has later creation date. It might have been modified. Open current file? The file will be get from server and overwritten?'");
				FormOpenParameters.Insert("Message", Message);
				
				Result = OpenFormModal("Catalog.Files.Form.NewerFileInWorkingFolder", FormOpenParameters);
				
				If Result = DialogReturnCode.Yes Then  // Open existing one
					Return True;
				ElsIf Result = DialogReturnCode.Cancel Then // Exit with no actions
					FullFileName = "";
					Return False;
				ElsIf Result = DialogReturnCode.No Then  // Overwrite
					DeleteFile(FullFileName, False); // setting of delete confirmation is not used in working directory
					Return GetFromServerAndRegisterInFilesLocalCache(FileData, FullFileName, FileInBaseDate, ForRead, FormID);
				EndIf;
				
			EndIf;
		EndIf;
		
		Return False;
	EndIf;		
	
	
	Return False;
EndFunction // GetVersionFileToWorkingDirectory()

// Gets File from infobase for edit to local disk - into folder working directory
// and returns path to this file in parameter
Function GetVersionFileToWorkingDirectoryForEdit(FileData, FullFileName, FormID = Undefined)
	
	Var Version;
	Var PlacementDate;	
	
	ForRead = False;
	InOwnerWorkingDirectory = True;
	
	FileInBaseDate = FileData.ModificationDateUniversal;
	CommonUseClient.ConvertSummerTimeToCurrentTime(FileInBaseDate);
	
	InitializeWorkingDirectoryPath();
	
	If FullFileName = "" Then
		FullFileName = FileData.OwnerWorkingDirectory + FileData.VersionDetails + "." + FileData.Extension;
	EndIf;
	
	// find in working directory by path, but not by FileVersion
	Owner 				= Undefined;
	VersionNo 			= Undefined;
	InRegisterForRead 	= Undefined;
	InRegisterFileCode 	= Undefined;
	InRegisterFolder 	= Undefined;
	FileIsInRegister 	= FileOperations.FindInRegisterByPath(FullFileName, Version, PlacementDate, Owner, VersionNo, 
		InRegisterForRead, InRegisterFileCode, InRegisterFolder);
	
	If FileIsInRegister Then
		// check that there already exists file at this path
		FileOnDisk = New File(FullFileName);
		If Not FileOnDisk.Exist() Then
			FileOperations.DeleteFromRegister(Version);
			FileIsInRegister = False;
		EndIf;	
	EndIf;
	
	If Not FileIsInRegister Then // no ref to File in register
		
		// check that there already exists file at this path
		FileOnDisk = New File(FullFileName);
		If FileOnDisk.Exist() Then
			
			FileInBaseDate = FileData.ModificationDateUniversal;
			CommonUseClient.ConvertSummerTimeToCurrentTime(FileInBaseDate);
			FileSizeInBase = FileData.Size;

			FileOnDiskDate = FileOnDisk.GetModificationTime();
			FileSizeOnDisk = FileOnDisk.Size();
			
			DatesDifference = FileOnDiskDate - FileInBaseDate;
			If DatesDifference < 0 Then
				DatesDifference = -DatesDifference;
			EndIf;
			
			// size and modification date are identical - use it - register in cache
			If DatesDifference <= 1 And FileSizeInBase = FileSizeOnDisk Then
				FileOnDisk.SetReadOnly(ForRead);
				InitializeWorkingDirectoryPath();
				DirectoryName = FileOperationsSecondUseClient.GetFileOperationsPersonalSettings().LocalFilesCachePath;
				
				FileOperations.AddFilesInWorkingDirectoryRegisterRecord(FileData.Version, FullFileName, DirectoryName, ForRead, FileSizeInBase, InOwnerWorkingDirectory);
				Return True;	// use File existing on disk
			EndIf;
			
			If DatesDifference > 1 Then
				MessageString = StringFunctionsClientServer.SubstitureParametersInString(
					NStr("en = '%3 file already exists in working directory, but its modification time differs from the one at server.
                          | File modification date in working directory: %1
                          | File modification date at server: %2
                          |Rename file or move it to another directory.'"),
				        FileOnDiskDate, FileInBaseDate, FullFileName);
									  
				FormOpenParameters = New Structure;
				FormOpenParameters.Insert("File",                			FullFileName);
				FormOpenParameters.Insert("ModificationTimeOnServer",     	FileInBaseDate);
				FormOpenParameters.Insert("InWorkingDirectory",            	FileOnDiskDate);
				
				If FileOnDiskDate < FileInBaseDate Then
					FormOpenParameters.Insert("Title", NStr("en = 'There is an older file in working directory'"));
				Else	
					FormOpenParameters.Insert("Title", NStr("en = 'There is a newer file in working directory'"));
				EndIf;	
				
				Message = StringFunctionsClientServer.SubstitureParametersInString(NStr("en = 'File ""%1"" already exists on local computer, but its modification time differs from the one on server. Open file from local directory or take it from server and overwrite it? '"),
					String(FileData.Ref));
				FormOpenParameters.Insert("Message", Message);
				
				Response = OpenFormModal("Catalog.Files.Form.NewerFileInWorkingFolder", FormOpenParameters);
				
				If Response = DialogReturnCode.Yes Then  // Open existing one
					FileOnDisk.SetReadOnly(ForRead);
					InitializeWorkingDirectoryPath();
					DirectoryName = FileOperationsSecondUseClient.GetFileOperationsPersonalSettings().LocalFilesCachePath;
					
					FileOperations.AddFilesInWorkingDirectoryRegisterRecord(FileData.Version, FullFileName, DirectoryName, ForRead, FileSizeInBase, InOwnerWorkingDirectory);
					Return True;	// use existing on disk file
				ElsIf Response = DialogReturnCode.Cancel Or Response = Undefined Then // Exit with no actions
					FullFileName = "";
					Return False;
				ElsIf Response = DialogReturnCode.No Then  // Overwrite
					DeleteFile(FullFileName);
					Return GetFromServerAndRegisterInWorkingDirectory(FileData, FullFileName, FileInBaseDate, ForRead, FormID);
				EndIf;
									  
    		Else
				MessageString = StringFunctionsClientServer.SubstitureParametersInString(
					NStr("en = '%3 file already exists in working directory but its size differs form the one at server.
                          | File size in working directory: %1
                          | File size on server: %2
                          |Rename file or move it to another directory.'"),
				        FileSizeOnDisk, FileSizeInBase, FullFileName);			
									  
				DoMessageBox(MessageString);
				Return False; // cancel operation
									  
			EndIf;					  
		EndIf;	
		
		// no ref to file in register and no file on disk as well
		Return GetFromServerAndRegisterInWorkingDirectory(FileData, FullFileName, FileInBaseDate, ForRead, FormID);
	EndIf; // no ref to file in register
	
	
	// File by path in working directory has ref in information register
	If Version <> FileData.CurrentVersion Then 
		// there is File of another FileVersion in working directory (or another File object at all)
		
		If Owner = FileData.Ref And InRegisterForRead = True Then 
			// the same File on disk, but of different FileVersion - and it is for read
			Return GetFromServerAndRegisterInWorkingDirectory(FileData, FullFileName, FileInBaseDate, ForRead, FormID);
		EndIf;
		
		MessageString = "";
			
		MessageString = StringFunctionsClientServer.SubstitureParametersInString(
			NStr("en = 'Working directory already contains %1 file linked to another infobase File. 
                  | File code at server: %2
                  | File code on local computer: %3'"),
			FullFileName,
			FileData.FileCode, 
			InRegisterFileCode);			
							  
		If FileData.Owner = InRegisterFolder Then // the same folder
			MessageString = MessageString + Chars.LF + NStr("en = 'Rename one of files in the infobase.'");
		Else
			MessageString = MessageString + Chars.LF + NStr("en = 'Change working directory of one of folders in the infobase. Two folders cannot have the same working directory.'");
		EndIf;	
								  
		DoMessageBox(MessageString);
		Return False;
		
	Else // File by path in working directory - is of required version and it has ref in register
		
		// Below - we don't know, that File exists in working directory.
		// Need to check when it was modified and decide what to do
		// - overwrite, ask user, etc.
		
		FileNameWithPath = FullFileName;
		ReadonlyInWorkingDirectory = InRegisterForRead;
	
		VersionFile 	= New File(FullFileName);
		FileOnDiskDate = VersionFile.GetModificationTime();
		FileSizeOnDisk = VersionFile.Size();
		FileSizeInBase  = FileData.Size;
		
		DatesDifference = FileOnDiskDate - FileInBaseDate;
		If DatesDifference < 0 Then
			DatesDifference = -DatesDifference;
		EndIf;
		
		If DatesDifference <= 1 Then // 1 second - allowed difference (may be on Win95)
			// Date is equal but the size is different, wierd, but possible
			If FileSizeInBase <> 0 And FileSizeOnDisk <> FileSizeInBase Then
				
				FormOpenParameters = New Structure;
				FormOpenParameters.Insert("File",                	FileNameWithPath);
				FormOpenParameters.Insert("FilesizeOnServer",     	FileSizeInBase);
				FormOpenParameters.Insert("SizeInWorkingDirectory", FileSizeOnDisk);
				FormOpenParameters.Insert("Message",            	NStr("en = 'File sizes in working directory and at server are different. Overwrite the file in working directory?'"));
				
				Response = OpenFormModal("Catalog.Files.Form.FilesizeInWorkingFolderIsDifferent", FormOpenParameters);
				
				If Response = DialogReturnCode.Yes Then // Overwrite
					DeleteFile(FullFileName, False); // setting of delete confirmation is not used in working directory
					Return GetFromServerAndRegisterInFilesLocalCache(FileData, FullFileName, FileInBaseDate, ForRead, FormID);
				ElsIf Response = DialogReturnCode.No Then // Open existing one
					Return True;
				Else // Exit with no actions
					FullFileName = "";
					Return False;
				EndIf;
			EndIf;
			
			// All matches - date, and size
			If ReadonlyInWorkingDirectory = ForRead Then
				Return True;
			Else
				InOwnerWorkingDirectory = FileData.OwnerWorkingDirectory <> "";
				ReregisterInWorkingDirectory(FileData.Version, FileNameWithPath, ForRead, InOwnerWorkingDirectory);
				Return True;
			EndIf;
		ElsIf FileOnDiskDate < FileInBaseDate Then // In working directory is older one
			If ReadonlyInWorkingDirectory = False Then // In working directory for edit
				
				FormOpenParameters = New Structure;
				FormOpenParameters.Insert("File",                	  FileNameWithPath);
				FormOpenParameters.Insert("ModificationTimeOnServer", FileInBaseDate);
				FormOpenParameters.Insert("InWorkingDirectory",       FileOnDiskDate);
				FormOpenParameters.Insert("Title",            		  NStr("en = 'There is an older file in working directory'"));
				
				Message = NStr("en = 'The locked for editing file at local computer has earlier modification date than the one at server. Open file from local directory? If no it will be get from server and overwritten.'");
				FormOpenParameters.Insert("Message", Message);
				
				Response = OpenFormModal("Catalog.Files.Form.NewerFileInWorkingFolder", FormOpenParameters);
				
				If Response = DialogReturnCode.Yes Then  // Open existing one
					Return True;
				ElsIf Response = DialogReturnCode.Cancel Then // Exit with no actions
					FullFileName = "";
					Return False;
				ElsIf Response = DialogReturnCode.No Then  // Overwrite
					DeleteFile(FullFileName, False); // setting of delete confirmation is not used in working directory
					Return GetFromServerAndRegisterInFilesLocalCache(FileData, FullFileName, FileInBaseDate, ForRead, FormID);
				EndIf;
			Else // In working directory for read
				// Overwrite with no request
				DeleteFile(FullFileName, False); // setting of delete confirmation is not used in working directory
				Return GetFromServerAndRegisterInFilesLocalCache(FileData, FullFileName, FileInBaseDate, ForRead, FormID);
			EndIf;
		ElsIf FileOnDiskDate > FileInBaseDate Then // In working directory is newer one (modified by user from outside)
			
			If ReadonlyInWorkingDirectory = False Then // In working directory for edit
				Return True; // Do nothing
			Else // In working directory for read
				
				FormOpenParameters = New Structure;
				FormOpenParameters.Insert("File",                	  FileNameWithPath);
				FormOpenParameters.Insert("ModificationTimeOnServer", FileInBaseDate);
				FormOpenParameters.Insert("InWorkingDirectory",       FileOnDiskDate);
				FormOpenParameters.Insert("Title",            		  NStr("en = 'There is a newer file in working directory'"));
				
				Message = NStr("en = 'The locked for editing file at local computer has a later modification date than the one at server. Open file form local directory? If no it will be taked from server and overwritten.'");
				FormOpenParameters.Insert("Message", Message);
				
				Response = OpenFormModal("Catalog.Files.Form.NewerFileInWorkingFolder", FormOpenParameters);
				
				If Response = DialogReturnCode.Yes Then  // Open existing one
					Return True;
				ElsIf Response = DialogReturnCode.Cancel Then // Exit with no actions
					FullFileName = "";
					Return False;
				ElsIf Response = DialogReturnCode.No Then  // Overwrite
					DeleteFile(FullFileName, False); // setting of delete confirmation is not used in working directory
					Return GetFromServerAndRegisterInFilesLocalCache(FileData, FullFileName, FileInBaseDate, ForRead, FormID);
				EndIf;
				
			EndIf;
		EndIf;
		
		Return False;
	EndIf;		
	
	
	Return False;
EndFunction // GetVersionFileToWorkingDirectory()

// Get File from infobase to local disk and return path
//to this file in parameter
Function GetVersionFileToWorkingDirectory(FileData, FullFileName, FormID = Undefined) Export
	
	InitializeWorkingDirectoryPath();
	DirectoryName = FileOperationsSecondUseClient.GetFileOperationsPersonalSettings().LocalFilesCachePath;
	If DirectoryName = Undefined Or IsBlankString(DirectoryName) Then
		Return False;
	EndIf;
	
	OwnerWorkingDirectory = FileData.OwnerWorkingDirectory;
	
	ForRead = FileData.ForRead;
	If (ForRead And OwnerWorkingDirectory = "") Or FileData.Version <> FileData.CurrentVersion Then 
		Return GetVersionFileToFilesLocalCacheForRead(FileData, FullFileName, FormID);
	ElsIf OwnerWorkingDirectory = "" Then
		Return GetVersionFileToFilesLocalCacheForEdit(FileData, FullFileName, FormID);
	ElsIf ForRead And OwnerWorkingDirectory <> "" Then 
		Return GetVersionFileToWorkingDirectoryForReading(FileData, FullFileName, FormID);
	ElsIf ForRead = False And OwnerWorkingDirectory <> "" Then
		Return GetVersionFileToWorkingDirectoryForEdit(FileData, FullFileName, FormID);
	EndIf;
	
EndFunction // GetVersionFileToWorkingDirectory()

// Get File from server and register in working directory
Function GetFromServerAndRegisterInWorkingDirectory(FileData, FullFileNameInWorkingDirectory, FileInBaseDate, ForRead, FormID)
	
	FullFileName = "";
	
	FileInBaseDate = FileData.ModificationDateUniversal;
	CommonUseClient.ConvertSummerTimeToCurrentTime(FileInBaseDate);
	
	InitializeWorkingDirectoryPath();
	
	ReadonlyInWorkingDirectory = True;
	InOwnerWorkingDirectory   = False;
	FileInWorkingDirectory    = FileIsInFilesLocalCache(FileData, FileData.Version, FullFileName, ReadonlyInWorkingDirectory, InOwnerWorkingDirectory);
	If FileInWorkingDirectory Then
		// Get file path in working directory - with uniqueness check
		FileNameWithPath = FullFileName;
		If FileNameWithPath = "" Then
			DoMessageBox(NStr("en = 'Error of placing file into working directory.'"));
			Return False;
		EndIf;
		
		// Below 	- We don't know, that File exists in working directory.
		// Need to check when it was modified and decide what to do
		// Overwrite, ask user, etc.
		
		VersionFile 	= New File(FullFileName);
		FileOnDiskDate = VersionFile.GetModificationTime();
		FileSizeOnDisk = VersionFile.Size();
		FileSizeInBase 	= FileData.Size;
		
		DatesDifference = FileOnDiskDate - FileInBaseDate;
		If DatesDifference < 0 Then
			DatesDifference = -DatesDifference;
		EndIf;
		
		If DatesDifference <= 1 Then // 1 second - allowed difference (may be on Win95)
			// Date is equal, but the size is different: wierd, but possible
			If FileSizeInBase <> 0 And FileSizeOnDisk <> FileSizeInBase Then
				
				FormOpenParameters = New Structure;
				FormOpenParameters.Insert("File",                		FileNameWithPath);
				FormOpenParameters.Insert("FilesizeOnServer",     		FileSizeInBase);
				FormOpenParameters.Insert("SizeInWorkingDirectory",     FileSizeOnDisk);
				FormOpenParameters.Insert("Message",            		NStr("en = 'File size in working directory and at server differ. Overwrite file in the working directory?'"));
				
				Response = OpenFormModal("Catalog.Files.Form.FilesizeInWorkingFolderIsDifferent", FormOpenParameters);
				
				If Response = DialogReturnCode.Yes Then // Overwrite
					DeleteFile(FullFileName, False); // setting of delete confirmation is not used in working directory
				ElsIf Response = DialogReturnCode.No Then // Open existing one
					Return True;
				Else  // Exit with no actions
					FullFileName = "";
					Return False;
				EndIf;
			EndIf;
			
			// All matches - date, and size - delete and after get into folder working directory
			DeleteFile(FullFileName, False); // setting of delete confirmation is not used in working directory
			
		ElsIf FileOnDiskDate < FileInBaseDate Then // In working directory is older one
			If ReadonlyInWorkingDirectory = False Then // In working directory for edit
				
				FormOpenParameters = New Structure;
				FormOpenParameters.Insert("File",                			FileNameWithPath);
				FormOpenParameters.Insert("ModificationTimeOnServer",     	FileInBaseDate);
				FormOpenParameters.Insert("InWorkingDirectory",           	FileOnDiskDate);
				FormOpenParameters.Insert("Title",            				NStr("en = 'There is an older file in working directory'"));
				
				Message = NStr("en = 'The locked for editing file at local computer has earlier modification date than the one at server. Open file from local directory? If no it will be get from server and overwritten.'");
				FormOpenParameters.Insert("Message", Message);
				
				Response = OpenFormModal("Catalog.Files.Form.NewerFileInWorkingFolder", FormOpenParameters);
				
				If Response = DialogReturnCode.Yes Then  // Open existing one
					Return True;
				ElsIf Response = DialogReturnCode.Cancel Then // Exit with no actions
					FullFileName = "";
					Return False;
				ElsIf Response = DialogReturnCode.No Then  // Overwrite
					DeleteFile(FullFileName, False); // setting of delete confirmation is not used in working directory
				EndIf;
			Else // In working directory for read
				// Overwrite with no request
				DeleteFile(FullFileName, False); // setting of delete confirmation is not used in working directory
			EndIf;
		ElsIf FileOnDiskDate > FileInBaseDate Then // In working directory is newer one (modified by user from outside)
			LockedByCurrentUser = (FileData.LockedBy = FileOperationsSecondUseClient.GetFileOperationsPersonalSettings().CurrentUser);
			If (ReadonlyInWorkingDirectory = False) And LockedByCurrentUser Then // In working directory for edit and is locked by the current user
				Return True; // Do nothing - i.e. do not delete from local cache and put into working directory - i.e. all changes will be lost
			Else // In working directory for read
				
				FormOpenParameters = New Structure;
				FormOpenParameters.Insert("File",                	  FileNameWithPath);
				FormOpenParameters.Insert("ModificationTimeOnServer", FileInBaseDate);
				FormOpenParameters.Insert("InWorkingDirectory",       FileOnDiskDate);
				FormOpenParameters.Insert("Title",            		  NStr("en = 'There is a newer file in working directory'"));
				
				Message = NStr("en = 'The file at local computer has a later creation date. It might have been modified. Open current file? If no it will be get from server and overwritten.'");
				FormOpenParameters.Insert("Message", Message);
				
				Result = OpenFormModal("Catalog.Files.Form.NewerFileInWorkingFolder", FormOpenParameters);
				
				If Result = DialogReturnCode.Yes Then  // Open existing one
					Return True;
				ElsIf Result = DialogReturnCode.Cancel Then // Exit with no actions
					FullFileName = "";
					Return False;
				ElsIf Result = DialogReturnCode.No Then  // Overwrite
					DeleteFile(FullFileName, False); // setting of delete confirmation is not used in working directory
				EndIf;
				
			EndIf;
		EndIf;
	EndIf;
	
	Return GetFromServerAndRegisterInFilesLocalCache(FileData, FullFileNameInWorkingDirectory, FileInBaseDate, ForRead, FormID);
EndFunction

// Function is required for file opening via appropriate application
//
Procedure OpenFileByApplication(FileData, OpenedFileName)
	
	IsExtensionAttached = AttachFileSystemExtension();
	If IsExtensionAttached Then
		// Open File
		Try
			
			RunApp(OpenedFileName);
			
		Except
			
			ErrorInfo = ErrorInfo();
			DoMessageBox(StringFunctionsClientServer.SubstitureParametersInString(
				NStr("en = 'Description=""%1""'"),
				ErrorInfo.Details));
			
		EndTry;
	EndIf;
EndProcedure // OpenFile()

// Save File to disk
//
Function SaveAs(FileData) Export
	IsExtensionAttached = AttachFileSystemExtension();
	IsCryptoExtensionAttached = AttachCryptoExtension();
	
	If IsExtensionAttached Then

		// check - if file is already in cache, and it is newer than in IB display dialog with choice
		FilePathInCache = "";
		If FileData.LockedByCurrentUser Then
			InitializeWorkingDirectoryPath();
			ReadonlyInWorkingDirectory 	= True;
			InOwnerWorkingDirectory 	= False;
			FullFileName 				= "";
			FileInWorkingDirectory 		= FileIsInFilesLocalCache(FileData, FileData.Version, FullFileName, ReadonlyInWorkingDirectory, InOwnerWorkingDirectory);
			
			If FileInWorkingDirectory = True Then
				
				FileInBaseDate = FileData.ModificationDateUniversal;
				CommonUseClient.ConvertSummerTimeToCurrentTime(FileInBaseDate);

				VersionFile 	= New File(FullFileName);
				FileOnDiskDate = VersionFile.GetModificationTime();
				
				If FileOnDiskDate > FileInBaseDate Then // In working directory is newer one (modified by user from outside)
				
					FormOpenParameters = New Structure;
					FormOpenParameters.Insert("File", FullFileName);
					
					Message = StringFunctionsClientServer.SubstitureParametersInString(
						NStr("en = 'File modification date %1 at the local computer is more recent than the one in the infobase. The file might be modified.'"), 
						String(FileData.Ref));
					FormOpenParameters.Insert("Message", Message);
					
					Response = OpenFormModal("Catalog.Files.Form.FileCreationModeForSaveAs", FormOpenParameters);
					
					If Response = DialogReturnCode.Cancel Or Response = Undefined Then
						Return "";
					EndIf;	
					
					If Response = 1 Then // Based on file on local computer
						FilePathInCache = FullFileName;
					EndIf;
					
				EndIf;
				
			EndIf;
		EndIf;	
		
		ChoicePath = FileData.FolderForSaveAs;
		If ChoicePath = Undefined Or ChoicePath = "" Then
			
			ChoicePath = "";
			#If Not WebClient Then	

			If StandardSubsystemsClientSecondUse.ClientParameters().ThisIsBasicConfigurationVersion Then
				CommonUseClientServer.MessageToUser(NStr("en = 'This operation is not supported in basic version.'"));
				Return "";
			EndIf;
			
			Shell = New COMObject("MSScriptControl.ScriptControl");
			Shell.Language = "vbscript";
			Shell.AddCode("
				|Function SpecialFoldersName(Name)
				|set Shell=CreateObject(""WScript.Shell"")
				|SpecialFoldersName=Shell.SpecialFolders(Name)
				|End Function");
			ChoicePath = Shell.Run("SpecialFoldersName", "MyDocuments");
			#EndIf	
		
		EndIf;

		Password 					= "";
		SaveWithDetails 			= False;
		ExtensionForEncryptedFiles 	= "";
		NameWithExtention = FileFunctionsClient.GetNameWithExtention(FileData.VersionDetails, FileData.Extension);
		Extension = FileData.Extension;
		
		If Not SaveWithDetails Then
			NameWithExtention = NameWithExtention + "." + ExtensionForEncryptedFiles;
			Extension = ExtensionForEncryptedFiles;
		EndIf;	
		
		// chose path to file on disk
		FileChoice = New FileDialog(FileDialogMode.Save);
		FileChoice.Multiselect = False;
		FileChoice.FullFileName = NameWithExtention;
		Filter = StringFunctionsClientServer.SubstitureParametersInString(
			NStr("en = 'All files (*.%1)|*.%1'"), Extension, Extension);
		FileChoice.Filter = Filter;
		FileChoice.Directory = ChoicePath;
		
		If FileChoice.Choose() Then
			
			FileAddress = FileData.CurrentVersionURL;
			
			FileName = FileFunctionsClient.GetNameWithExtention(FileData.VersionDetails, FileData.Extension);
			SizeInMB = FileData.Size / (1024 * 1024);
			
			ClarificationText =
			StringFunctionsClientServer.SubstitureParametersInString(
				NStr("en = 'Saving file %1 (%2Mb)... Please wait.'"),
				FileName, ?(SizeInMB >= 1, Format(SizeInMB, "NFD=0"), Format(SizeInMB, "NFD=1; NZ=0")));
				
			Status(ClarificationText);	
			
			File = New File(FileChoice.FullFileName);
			If File.Exist() Then
				If FilePathInCache <> FileChoice.FullFileName Then
					File.SetReadOnly(False);
					DeleteFiles(FileChoice.FullFileName);
				EndIf;
			EndIf;
			
			If FilePathInCache = "" Then
				
				FilesBeingTransmitted = New Array;
				Details = New TransferableFileDescription(FileChoice.FullFileName, FileAddress);
				FilesBeingTransmitted.Add(Details);
				
				FilePath = File.Path;
				If Right(FilePath,1) <> "\" Then
					FilePath = FilePath + "\";
				EndIf;
				
				// Save file from IB to a disk
				If GetFiles(FilesBeingTransmitted,, FilePath, False) Then
					
					// delete file from temporary storage after getting it
					// for case when files are located on disk (at server)
					If IsTempStorageURL(FileAddress) Then
						DeleteFromTempStorage(FileAddress);
					EndIf;
					
			
					
					NewFile = New File(FileChoice.FullFileName);
					
					FileToBeCreatedOnDiskDate = FileData.ModificationDateUniversal;
					CommonUseClient.ConvertSummerTimeToCurrentTime(FileToBeCreatedOnDiskDate);
					
					NewFile.SetModificationTime(FileToBeCreatedOnDiskDate);

					Status(NStr("en = 'The file saved successfully'"), , FileChoice.FullFileName);
				EndIf;
			Else
				If FilePathInCache <> FileChoice.FullFileName Then
					FileCopy(FilePathInCache, FileChoice.FullFileName);
				EndIf;
				Status(NStr("en = 'The file saved successfully'"), , FileChoice.FullFileName);
			EndIf;
			
			ChoicePathOld = ChoicePath;
			File = New File(FileChoice.FullFileName);
			ChoicePath = File.Path;
			If ChoicePathOld <> ChoicePath Then
				CommonUse.CommonSettingsStorageSave("ApplicationSettings", "FolderForSaveAs",  ChoicePath);
			EndIf;
			
			Return FileChoice.FullFileName;
		EndIf;
		
	Else  // web client
		FileAddress = FileData.CurrentVersionURL;
		
		FileName = FileFunctionsClient.GetNameWithExtention(FileData.VersionDetails, FileData.Extension);
		SizeInMB = FileData.Size / (1024 * 1024);
		
		ClarificationText =
		StringFunctionsClientServer.SubstitureParametersInString(
			NStr("en = 'Saving file %1 (%2 MB)... Please wait.'"),
			FileName, ?(SizeInMB >= 1, Format(SizeInMB, "NFD=0"), Format(SizeInMB, "NFD=1; NZ=0")));
			
		Status(ClarificationText);	
		
		// Save file from infobase to a disk
		GetFile(FileAddress, FileName, True);
			
		// delete file from temporary storage after getting it
		// in case when files are located on disk (at server)
		If IsTempStorageURL(FileAddress) Then
			DeleteFromTempStorage(FileAddress);
		EndIf;
	EndIf;	
	
	Return "";
EndFunction

// open Windows explorer, chosing specified file in it
Function OpenExplorerWithFile(Val FullFileName) Export
#If Not WebClient Then
	If FullFileName <> "" Then
		FileOnDisk = New File(FullFileName);
		If FileOnDisk.Exist() Then
			
			If Left(FullFileName, 0) <> """" Then
				FullFileName = """" + FullFileName + """";
			EndIf;
			
			Param = "explorer.exe /select, " + FullFileName;
			RunApp(Param);
			Return True;
		EndIf;
	EndIf;
#EndIf	
	
	Return False;
EndFunction

// Procedure opens Windows explorer, positioning cursor on File
//
Procedure FileDir(FileData) Export
	
	// If File does not contain file this operation has no sense
	If FileData.Version.IsEmpty() Then 
		Return;
	EndIf;
	
#If Not WebClient Then
	FullFileName = FileFunctionsClient.GetFilePathInWorkingDirectory(FileData);
	If OpenExplorerWithFile(FullFileName) = True Then
		Return;
	EndIf;	
	
	FileName = FileFunctionsClient.GetNameWithExtention(FileData.VersionDetails, FileData.Extension);
	
	ReturnCode = DoQueryBox(StringFunctionsClientServer.SubstitureParametersInString(
	  		NStr("en = '%1 file does not exist in the working directory. Get the file from server?'"), 
			FileName),
	  	QuestionDialogMode.YesNo);
	  
	  If ReturnCode = DialogReturnCode.Yes Then
		  GetVersionFileToWorkingDirectory(FileData, FullFileName);
		  OpenExplorerWithFile(FullFileName);
	  EndIf;		 
	  
	// delete file from temporary storage after getting it
	// in case when files are located on disk (at server)
	If IsTempStorageURL(FileData.CurrentVersionURL) Then
		DeleteFromTempStorage(FileData.CurrentVersionURL);
	EndIf;
#Else	
	  DoMessageBox(NStr("en = 'This function is not supported in Web Client.'"));
#EndIf
EndProcedure

// Opens question dialog with the list of Files or information about Files
//
Function QuestionWithFilesListDialog(List, MessageQuestion, MessageTitle, Title)
	Parameters = New Structure;	
	Parameters.Insert("MessageQuestion", MessageQuestion);
	Parameters.Insert("MessageTitle", 	 MessageTitle);
	Parameters.Insert("Title", 			 Title);
	Parameters.Insert("Files", 			 List);
	
	Result = OpenFormModal("Catalog.Files.Form.QuestionForm", Parameters);
	Return (Result = DialogReturnCode.Yes);

EndFunction

// Handler of event Drag in object forms - owners of File (except form FilesByFolders)
//
Procedure DragAndDropProcessingToLinearList(DragParameters, ListFileOwner, ThisForm,
	DoNotOpenCardAfterCreateFromFile = Undefined) Export
	
	If TypeOf(DragParameters.Value) = Type("File") And DragParameters.Value.IsFile() = True Then
		
		CreateDocumentBasedOnFile(DragParameters.Value.FullName, ListFileOwner, ThisForm, DoNotOpenCardAfterCreateFromFile);
		
	ElsIf TypeOf(DragParameters.Value) = Type("File") And DragParameters.Value.IsFile() = False Then
		
		DoMessageBox(NStr("en = 'Choose files only but not directories for import.'"));
		Return;
		
	ElsIf TypeOf(DragParameters.Value) = Type("CatalogRef.Files") Then	
		
		MoveFileToAttachedFiles(DragParameters.Value, ListFileOwner);	
		
	ElsIf TypeOf(DragParameters.Value) = Type("Array") Then
		
		If DragParameters.Value.Count() >= 1 And TypeOf(DragParameters.Value[0]) = Type("File") Then
			For Each FileAccepted In DragParameters.Value Do
				If Not FileAccepted.IsFile() Then 
					// files only, but not directories
					DoMessageBox(NStr("en = 'Choose files only but not directories for import.'"));
					Return;
				EndIf;
			EndDo;
		EndIf;
		
		If DragParameters.Value.Count() >= 1 And TypeOf(DragParameters.Value[0]) = Type("File") Then
			For Each FileAccepted In DragParameters.Value Do
				DoNotOpenCardAfterCreateFromFile = True;
				CreateDocumentBasedOnFile(FileAccepted.FullName, ListFileOwner, ThisForm, DoNotOpenCardAfterCreateFromFile);
			EndDo;
		EndIf;
		
		If DragParameters.Value.Count() >= 1 And TypeOf(DragParameters.Value[0]) = Type("CatalogRef.Files") Then
			MoveFilesToAttachedFiles(DragParameters.Value, ListFileOwner);
		EndIf;
		
	EndIf;
EndProcedure

// moves file from one list of attached files to another
Procedure MoveFileToAttachedFiles(FileRef, FileOwner)

	Result = FileOperations.GetDataForTransferToAttachedFiles(FileRef, FileOwner).Get(FileRef);
	
	If Result = "Copy" Then
		
		FileCreated = FileOperations.CopyFileInAttached(FileRef, FileOwner);
		Notify("FileCreated", New Structure("Owner, File", FileOwner, FileCreated));
		
		ShowUserNotification(
			"Creating:", 
			GetURL(FileCreated),
			String(FileCreated),
			PictureLib.Information32);
		
	ElsIf Result = "Refresh" Then	
		
		FileUpdated = FileOperations.RefreshFileInAttachedFiles(FileRef, FileOwner);
			
		ShowUserNotification(
			"Update:", 
			GetURL(FileUpdated),
			String(FileUpdated),
			PictureLib.Information32);
		
	EndIf;
	
EndProcedure	

// moves files from one list of attached files to another
Procedure MoveFilesToAttachedFiles(FilesArray, FileOwner)
	
	If FilesArray.Count() = 1 Then 
		MoveFileToAttachedFiles(FilesArray[0], FileOwner);
	Else
		
		Result = FileOperations.GetDataForTransferToAttachedFiles(FilesArray, FileOwner);
		
		ArrayRefresh = New Array;
		ArrayCopy = New Array;
		For Each FileRef In FilesArray Do
			If Result.Get(FileRef) = "Copy" Then
				ArrayCopy.Add(FileRef);
			ElsIf Result.Get(FileRef) = "Refresh" Then
				ArrayRefresh.Add(FileRef);
			EndIf;
		EndDo;	
		
		If ArrayCopy.Count() > 0 Then 
			FileOperations.CopyFileInAttached(ArrayCopy, FileOwner);
		EndIf;	
		
		If ArrayRefresh.Count() > 0 Then 
			FileOperations.RefreshFileInAttachedFiles(ArrayRefresh, FileOwner);
		EndIf;	
		
		TotalQuantity = ArrayCopy.Count() + ArrayRefresh.Count();
		If TotalQuantity > 0 Then 
			
			FullDetails = StringFunctionsClientServer.SubstitureParametersInString(
				NStr("en = '%1 of files are moved to %2'"),
				TotalQuantity,
				FileOwner);
			
			ShowUserNotification(
				NStr("en = 'Files are transferred'"), 
				,
				FullDetails,
				PictureLib.Information32);
				
		EndIf;	
			
	EndIf;	
	
EndProcedure

// Fills file on disk and creates new version from it - low level implementation
Procedure UpdateFromFileOnDiskImplementation(FileData, FormID, DialogFullFileName, 
	CreateNewVersion = Undefined, CommentToVersion = Undefined) Export
	
	// file data could be modified - update
	FileData = FileOperations.GetFileDataAndWorkingDirectory(FileData.Ref);

	PreviousVersion = FileData.Version;
	
	FileOnDisk 				    = New File(DialogFullFileName);
	FileNameAndExtensionOnDisk 	= FileOnDisk.Name;
	FileNameAndExtensionInBase 	= FileFunctionsClient.GetNameWithExtention(FileData.VersionDetails, FileData.Extension);
	ModificationTimeSelected 	= FileOnDisk.GetModificationTime();
	
	LockedByCurrentUser = FileData.LockedByCurrentUser;
	
	FileInBaseDate = FileData.ModificationDateUniversal;
	CommonUseClient.ConvertSummerTimeToCurrentTime(FileInBaseDate);
	
	If ModificationTimeSelected < FileInBaseDate Then // the newer file in cache
		ErrorString = StringFunctionsClientServer.SubstitureParametersInString(
			NStr("en = '%1 file at server has a later modification time (%2) than selected file (%3). Operation aborted.'"), 
			String(FileData.Ref), FileInBaseDate, ModificationTimeSelected);
		DoMessageBox(ErrorString);
		Return;
	EndIf;
	
	// check  - if there is file in local cache
	InitializeWorkingDirectoryPath();
	ReadonlyInWorkingDirectory 	= True;
	InOwnerWorkingDirectory 	= False;
	FullFileName 				= "";
	FileInWorkingDirectory 		= FileIsInFilesLocalCache(Undefined, PreviousVersion, FullFileName, ReadonlyInWorkingDirectory, InOwnerWorkingDirectory);
	
	If LockedByCurrentUser Then // file has already been locked
		
		If FileInWorkingDirectory = True Then
			FileInCache = New File(FullFileName);
			ModificationTimeInCache = FileInCache.GetModificationTime();
			
			If ModificationTimeSelected < ModificationTimeInCache Then 
				// the newer file in cache
				ErrorString = StringFunctionsClientServer.SubstitureParametersInString(
					NStr("en = '%1 file at server has a later modification time (%2) than selected file (%3). Operation aborted.'"), 
					String(FileData.Ref), ModificationTimeInCache, ModificationTimeSelected);
				DoMessageBox(ErrorString);
				Return;
			EndIf;
			
			#If Not WebClient Then
			Try
				// check that file is locked by an application
				TextDocument = New TextDocument;
				TextDocument.Read(FullFileName);
			Except
				ErrorString = StringFunctionsClientServer.SubstitureParametersInString(
					NStr("en = '%1 file in the main working directory is opened for editing. Finish editing prior updating the file from disk.'"), 
					FullFileName);
				DoMessageBox(ErrorString);
				Return;
			EndTry;
			#EndIf
			
		EndIf;
		
	EndIf;
	
	If FileInWorkingDirectory And FileNameAndExtensionOnDisk <> FileNameAndExtensionInBase Then
		Try
			FileFunctionsClient.DeleteFileFromWorkingDirectory(FileData.CurrentVersion, True);
			FileInWorkingDirectory = False;
		Except
			InfoInfo = ErrorInfo();
			DoMessageBox(StringFunctionsClientServer.SubstitureParametersInString(
				NStr("en = 'Description=""%1""'"), InfoInfo.Details));
			
			Return;
		EndTry;
	EndIf;	

	If Not LockedByCurrentUser Then
		
		ErrorString = "";
		If Not FileOperationsClientServer.CanLockFile(FileData, ErrorString) Then
			DoMessageBox(ErrorString);
			Return;
		EndIf;
		
		ErrorString = "";
		If Not FileOperations.LockFile(FileData, ErrorString, FormID) Then 
			DoMessageBox(ErrorString);
			Return;
		EndIf;
		
		ForRead = False;
		InOwnerWorkingDirectory = FileData.OwnerWorkingDirectory <> "";
		ReregisterFileInWorkingDirectory(FileData, ForRead, InOwnerWorkingDirectory);
		
	EndIf;
	
	PassedFullFilePath = "";
	
	If FileInWorkingDirectory Then
		FileCopy(DialogFullFileName, FullFileName);
	Else
		PassedFullFilePath = DialogFullFileName;
	EndIf;
	
	If LockedByCurrentUser Then // file has already been locked
		
		SaveFile(FileData.Ref, 
			FormID,
			Undefined,
			Undefined, 
			Undefined,
			Undefined,
			PassedFullFilePath,
			CreateNewVersion, 
			CommentToVersion);
			
	Else
		
		EndEdit(
			FileData.Ref, 
			FormID,
			FileData.StoreVersions,
			FileData.LockedByCurrentUser,
			FileData.LockedBy,
			FileData.CurrentVersionAuthor,
			PassedFullFilePath,
			CreateNewVersion, 
			CommentToVersion); 
			
	EndIf;	
	
	If FileNameAndExtensionOnDisk <> FileNameAndExtensionInBase Or Not FileInWorkingDirectory Then
		
		// refresh data
		FileData = FileOperations.GetFileDataForOpening(
			FileData.Ref, Undefined, FormID);
			
		// get to cache
		GetVersionFileToWorkingDirectory(FileData, FullFileName);
	EndIf;	
EndProcedure

// Choses file on disk and creates new version from it
//
Procedure UpdateFromFileOnDisk(FileData, FormID) Export
	
	IsExtensionAttached = AttachFileSystemExtension();
	
	If IsExtensionAttached Then
	
		Dialog = New FileDialog(FileDialogMode.Open);
		
		ChoicePath = CommonUse.CommonSettingsStorageLoad("ApplicationSettings", "FolderForUpdateFromFile");
		If ChoicePath = Undefined OR ChoicePath = "" Then
			
			#If Not WebClient Then
				
				If StandardSubsystemsClientSecondUse.ClientParameters().ThisIsBasicConfigurationVersion Then
					CommonUseClientServer.MessageToUser(NStr("en = 'This operation is not supported in basic version.'"));
					Return;
				EndIf;
				
				Shell = New COMObject("MSScriptControl.ScriptControl");
				Shell.Language = "vbscript";
				Shell.AddCode("
					|Function SpecialFoldersName(Name)
					|set Shell=CreateObject(""WScript.Shell"")
					|SpecialFoldersName=Shell.SpecialFolders(Name)
					|End Function");
				ChoicePath = Shell.Run("SpecialFoldersName", "MyDocuments");
			#Else	
				ChoicePath = "";
			#EndIf
		EndIf;
		
		Dialog.Title          = NStr("en = 'Choose File'");
		Dialog.Preview        = False;
		Dialog.CheckFileExist = False;
		Dialog.Multiselect    = False;
		Dialog.Directory	  = ChoicePath;
		Dialog.FullFileName	  = FileFunctionsClient.GetNameWithExtention(FileData.VersionDetails, FileData.Extension); 
		Dialog.Filter         = StringFunctionsClientServer.SubstitureParametersInString(
			NStr("en = '*.%1 file|*.%1|All files (*.*)|*.*'"), FileData.Extension, FileData.Extension);
		
		If Dialog.Choose() Then
					
			ChoicePathOld 	= ChoicePath;
			FileOnDisk 	    = New File(Dialog.FullFileName);
			ChoicePath 		= FileOnDisk.Path;
			If ChoicePathOld <> ChoicePath Then
				CommonUse.CommonSettingsStorageSave("ApplicationSettings", "FolderForUpdateFromFile",  ChoicePath);
			EndIf;
			
			UpdateFromFileOnDiskImplementation(FileData, FormID, Dialog.FullFileName);
			
		EndIf;
		
	EndIf;
EndProcedure

Procedure ShowLockedFilesOnExit(Cancellation) Export
	
	CurrentUser = FileOperationsSecondUseClient.GetFileOperationsPersonalSettings().CurrentUser;
	
	LockedFiles = FileOperations.GetLockedFiles(, CurrentUser);
	If LockedFiles.Count() > 0 Then 
		
		FormParameters = New Structure;	
		FormParameters.Insert("MessageQuestion", NStr("en = 'Do you want to exit the application?'"));
		FormParameters.Insert("MessageTitle", 	 NStr("en = 'The following files are locked for editing:'"));
		FormParameters.Insert("Title", 			 NStr("en = 'Exit Application'"));
		FormParameters.Insert("LockedBy", 		 CurrentUser);
		
		Result = OpenFormModal("Catalog.Files.Form.ListOfLockedWithQuestion", FormParameters);
		If Result <> DialogReturnCode.Yes Then 
			Cancellation = True;
		EndIf;
		
	EndIf;
	
EndProcedure	

// saves path to the directory in settings
Procedure SavePathToDirectoryInSettings(DirectoryName)
	FileOperations.SaveUserWorkingDirectoryPath(DirectoryName);
	RefreshReusableValues();
EndProcedure

// Initialize session parameter UserWorkingDirectoryPath, by checking that path is correct, and correcting it if needed
Procedure InitializeWorkingDirectoryPath() Export
	SessionParameterWorkingDirectory = FileOperationsSecondUseClient.GetSessionParameterWorkingDirectory();
	If Not IsBlankString(SessionParameterWorkingDirectory) Then // has been already initialized
		Return;
	EndIf;	
	
	DirectoryName = FileOperationsSecondUseClient.GetFileOperationsPersonalSettings().LocalFilesCachePath;
	If DirectoryName = Undefined Then
		DirectoryName = FileFunctionsClient.GetPathToUserDataDirectory();
		If Not IsBlankString(DirectoryName) Then
			SavePathToDirectoryInSettings(DirectoryName);
		Else
			Return;
		EndIf;	
	Else
		FileOperations.SetSessionParameterUserWorkingDirectoryPath(DirectoryName);
		RefreshReusableValues();
	EndIf;
	
#If Not WebClient Then
	// Create directory for files
	Try
		CreateDirectory(DirectoryName);
		DirectoryNameIsTest = DirectoryName + "AccessVerification\";
		CreateDirectory(DirectoryNameIsTest);
		DeleteFiles(DirectoryNameIsTest);
	Except
		// no rights to create directory, or this path is missing, resetting to default settings
		DirectoryName = FileFunctionsClient.GetPathToUserDataDirectory();
		SavePathToDirectoryInSettings(DirectoryName);
	EndTry;
#EndIf

EndProcedure
