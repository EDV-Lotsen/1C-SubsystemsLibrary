

// Function returns directory "My Documents" + current user name
Function LatestUnloadDirectory() Export
	Path = "";
	#If Not WebClient Then	
		
	Path = CommonUse.CommonSettingsStorageLoad("UnloadFolderName", "UnloadFolderName");
	If Path = Undefined Then
		If Not StandardSubsystemsClientSecondUse.ClientParameters().ThisIsBasicConfigurationVersion Then
			Shell = New COMObject("MSScriptControl.ScriptControl");
			Shell.Language = "vbscript";
			Shell.AddCode("
				|Function SpecialFoldersName(Name)
				|set Shell=CreateObject(""WScript.Shell"")
				|SpecialFoldersName=Shell.SpecialFolders(Name)
				|End Function");
			Path = NormalizeDirectory(Shell.Run("SpecialFoldersName", "MyDocuments"));
			CommonUse.CommonSettingsStorageSave("UnloadFolderName", "UnloadFolderName", Path);
		EndIf;	
	EndIf;
		
	#EndIf
	Return Path;
EndFunction

// Function adds closing slash to a directory name, if required
// and also deleted all invalid chars from the directory name
// also, "/" is replaced for "\"
Function NormalizeDirectory(DirectoryName) Export
	Result = TrimAll(DirectoryName);
	
	// Remember presence of "Drive:" in the beginning of the path and then return ":" after disk name
	StrDrive = "";
	If Mid(Result, 2, 1) = ":" Then
		StrDrive = Mid(Result, 1, 2);
		Result = Mid(Result, 3);
	Else
		
		// And here check, that our path is not UNC-path (i.e. path starting from "\\")
		If Mid(Result, 2, 2) = "\\" Then
			StrDrive = Mid(Result, 1, 2);
			Result = Mid(Result, 3);
		EndIf;
	EndIf;
	
	// Create slashes in Windows-style
	Result = StrReplace(Result, "/", "\");
	
	// Adding closing slash
	Result = TrimAll(Result);
	If Right(Result,1) <> "\" Then
		Result = Result + "\";
	EndIf;
	
	// Replace all double slashes for single slashes and get full path
	Result = StrDrive + StrReplace(Result, "\\", "\");
	
	Return Result;
EndFunction

// Procedure checks file name for invalid chars in it
// Parameters:
//  FileName  		- String
//                 file name being checked
//  DeleteInvalid 	- Boolean
//                 delete or not invalid chars from the passed string
Procedure CheckForInvalidCharactersInFileName(FileName, DeleteInvalid = False) Export
	// List of invalid chars is taken from: http://support.microsoft.com/kb/100108/en
	//  where FAT and NTFS chars has been combined
	InvalidChars = """ / \ [ ] : ; | = , ? * < >";
	InvalidChars = StrReplace(InvalidChars, " ", "");
	
	ErrorText =
		StringFunctionsClientServer.SubstitureParametersInString(
		  NStr("en = 'There should be none of the following symbols %1 in file name'"), InvalidChars);
	
	Result = True;
	
	For Acc=1 to StrLen(InvalidChars) Do
		Char = Mid(InvalidChars, Acc, 1);
		If Find(FileName, Char) <> 0 Then
			Result = False;
			If DeleteInvalid Then
				FileName = StrReplace(FileName, Char, "");
			Else
				Break;
			EndIf;
		EndIf;
	EndDo;
	
	If Not Result Then
		Raise ErrorText;
	EndIf;
EndProcedure // CheckForInvalidCharactersInFileName()

// Recursively bypass all directories and calculate number of files and their total size
Procedure CalculateFilesSizeRecursive(Path, FilesArray, TotalSize, TotalQuantity) Export
	For Each ChosenFile In FilesArray Do
		
		If ChosenFile.IsDirectory() Then
			NewPath = String(Path);
			NewPath = NewPath + "\";
			NewPath = NewPath + String(ChosenFile.Name);
			DirectoryFilesArray = FindFiles(NewPath, "*.*");
			
			If DirectoryFilesArray.Count() <> 0 Then
				CalculateFilesSizeRecursive(NewPath, DirectoryFilesArray, TotalSize, TotalQuantity);
			EndIf;
		
			Continue;
		EndIf;
		
		TotalSize = TotalSize + ChosenFile.Size();
		TotalQuantity = TotalQuantity + 1;
		
	EndDo;
EndProcedure

// Gets relative file path in working directory - if it is present in information register - from there then,
// if not - generate it - and write into information register
Function GetFilePathInWorkingDirectory(FileData) Export
	FullPath	= "";
	FileNameWithPath = "";
	FileOperationsClient.InitializeWorkingDirectoryPath();
	DirectoryName = FileOperationsSecondUseClient.GetFileOperationsPersonalSettings().LocalFilesCachePath;

	// First trying to find such record in information register
	FileNameWithPath = FileData.FileNameWithPathInWorkingDirectory;
	ReadonlyInWorkingDirectory = FileData.ReadonlyInWorkingDirectory;
	
	If FileNameWithPath <> "" Then
		// checking if file exists on disk in this case
		FileOnHardDisk = New File(FileNameWithPath);
		If FileOnHardDisk.Exist() Then
			Return FileNameWithPath;	
		EndIf;
	EndIf;
	
	// Generate file name with extension
	FileName = FileData.VersionDetails;
	Extension = FileData.Extension;
	If Not IsBlankString(Extension) Then 
		FileName = FileFunctionsClient.GetNameWithExtention(FileName, Extension);
	EndIf;
	
	FileNameWithPath = "";
	If Not IsBlankString(FileName) Then
		If FileData.OwnerWorkingDirectory <> "" Then
			FileNameWithPath = FileData.OwnerWorkingDirectory + FileData.VersionDetails + "." + FileData.Extension;
		Else
			FileNameWithPath = FileFunctionsClientServer.GetUniqueNameWithPath(DirectoryName, FileName);
		EndIf;		
	EndIf;
	
	If IsBlankString(FileName) Then
		Return "";
	EndIf;
	
	// Write file name in register
	ForRead = True;
	InOwnerWorkingDirectory = FileData.OwnerWorkingDirectory <> "";
	FileOperations.WriteFileNameWithPathToRegister(FileData.Version, FileNameWithPath, ForRead, InOwnerWorkingDirectory);
	
	If FileData.OwnerWorkingDirectory = "" Then
		FullPath = DirectoryName + FileNameWithPath;
	Else
		FullPath = FileNameWithPath;
	EndIf;

	Return FullPath;
EndFunction

// Do recursive loop over the files in working directory and collect information about them
Procedure GetFilesInformationRecursive(Path, FilesArray, FileTable)
#If Not WebClient Then
	Var Version;
	Var PlacementDate;	
	
	DirectoryName = FileOperationsSecondUseClient.GetFileOperationsPersonalSettings().LocalFilesCachePath;
			
	For Each ChosenFile In FilesArray Do
		
		If ChosenFile.IsDirectory() Then
			NewPath = String(Path);
			NewPath = NewPath + "\";
			NewPath = NewPath + String(ChosenFile.Name);
			DirectoryFilesArray = FindFiles(NewPath, "*.*");
			
			If DirectoryFilesArray.Count() <> 0 Then
				GetFilesInformationRecursive(NewPath, DirectoryFilesArray, FileTable);
			EndIf;
		
			Continue;
		EndIf;
		
		// Do not delete temporary Word files from working directory
		If Left(ChosenFile.Name, 1) = "~" And ChosenFile.GetHidden() = True Then
			Continue;
		EndIf;
		
		RelativePath = Mid(ChosenFile.FullName, StrLen(DirectoryName) + 1);
		
		// If file not found on disk the minimum date will be the oldest
		// and will be deleted on clearing the oldest files from working directory
		PlacementDate = Date('00010101');
		
		Owner	   = Undefined;
		VersionNo  = Undefined;
		ReadOnly   = Undefined;
		FileCode   = Undefined;
		FileFolder = Undefined;
		FileIsInRegister   = FileOperations.FindInRegisterByPath(RelativePath, Version, PlacementDate, Owner, VersionNo, 
			ReadOnly, FileCode, FileFolder);

		If FileIsInRegister Then
			LockedByCurrentUser = FileOperations.IsLockedByCurrentUser(Version);

			// If file is not locked by current user - delete it
			If Not LockedByCurrentUser Then
				Record = New Structure;
				Record.Insert("Path", 						   RelativePath);
				Record.Insert("Size", 						   ChosenFile.Size());
				Record.Insert("Version", 					   Version);
				Record.Insert("WorkingDirectoryPlacementDate", PlacementDate);
				FileTable.Add(Record);
			EndIf;
		Else
			Record = New Structure;
			Record.Insert("Path", 							RelativePath);
			Record.Insert("Size",	 						ChosenFile.Size());
			Record.Insert("Version", 						Version);
			Record.Insert("WorkingDirectoryPlacementDate", 	PlacementDate);
			FileTable.Add(Record);
		EndIf;
			
	EndDo;
#EndIf
EndProcedure

// Clearing working directory - to empty space - first delete files
// placed into the working directory earlier
Procedure ClearWorkingDirectory(FileSizesInWorkingDirectory, SizeOfFileBeingAdded, ClearAll) Export
#If Not WebClient Then
	FileOperationsClient.InitializeWorkingDirectoryPath();
	DirectoryName = FileOperationsSecondUseClient.GetFileOperationsPersonalSettings().LocalFilesCachePath;
	
	FileTable = New Array;
	
	FilesArray = FindFiles(DirectoryName, "*.*");
	
	GetFilesInformationRecursive(DirectoryName, FilesArray, FileTable);
	
	// Server call for sorting
	//  sort by date - the first ones are for oldest files
	FileOperations.SortStructuresArray(FileTable);
	
	MaxSize = FileOperationsSecondUseClient.GetFileOperationsPersonalSettings().LocalFilesCacheMaximumSize;
	
	AverageFileSize = 1000;
	If FileTable.Count() <> 0 Then
		AverageFileSize = FileSizesInWorkingDirectory / FileTable.Count();
	EndIf;
	
	HowMuchSpaceNeedsToBeEmptied = MaxSize / 10;
	If AverageFileSize * 3 / 2 > HowMuchSpaceNeedsToBeEmptied Then
		HowMuchSpaceNeedsToBeEmptied = AverageFileSize * 3 / 2;
	EndIf;
	
	HowMuchLeft = FileSizesInWorkingDirectory + SizeOfFileBeingAdded;	
	
	For Each String in FileTable Do
		
		If String.Version.IsEmpty() Then
			QuestionText =
			StringFunctionsClientServer.SubstitureParametersInString(
			    NStr("en = '%1%2 file was not found on the server. Remove it from the working directory?'"),
			    DirectoryName, String.Path);
				
				
			If ClearAll	= False Then
				QuestionText = NStr("en = 'Clearing of the main working directory while adding a file.'") + Chars.LF + Chars.LF + QuestionText;
			EndIf;	
			
			ReturnCode = DoQueryBox(QuestionText, QuestionDialogMode.YesNo);

			If ReturnCode = DialogReturnCode.No Then
				Continue;
			EndIf;
		EndIf;

		FullPath = DirectoryName + String.Path;
		FileOnHardDisk = New File(FullPath);
		FileOnHardDisk.SetReadOnly(False);
		QuestionHeader = NStr("en = 'Clearing of the main working directory while adding a file.'");
		FileOperationsClient.DeleteFile(FullPath, Undefined, QuestionHeader);
		
		PathWithSubdirectory = DirectoryName;
		charPosition = Find(String.Path, "\");
		If charPosition <> 0 Then
			PathWithSubdirectory = DirectoryName + Left(String.Path, charPosition);
		EndIf;
		
		// If directory became empty - delete it
		DirectoryFilesArray = FindFiles(PathWithSubdirectory, "*.*");
		If DirectoryFilesArray.Count() = 0 Then
			If PathWithSubdirectory <> DirectoryName Then
				DeleteFiles(PathWithSubdirectory);
			EndIf;
		EndIf;
	
		// Delete from information register
		FileOperations.DeleteFromRegister(String.Version);
		
		HowMuchLeft = HowMuchLeft - String.Size;
		If HowMuchLeft < MaxSize - HowMuchSpaceNeedsToBeEmptied Then
			If Not ClearAll Then
				Break; // Emptied enough space - exit
			EndIf;
		EndIf;
			
	EndDo;
	
	If ClearAll Then
		FileOperations.DeleteUnusedRecordsFromFilesInWorkingDirectoryRegister();
	EndIf;
#EndIf
EndProcedure

// Get file full path
Function GetFullFilePathInWorkingDirectory(FileData) Export
	Return FileData.FileNameWithPathInWorkingDirectory;
EndFunction

// Delete from disk and from information register
Procedure DeleteFileFromWorkingDirectory(Ref, DeleteEvenInWorkingDirectory = Undefined) Export
	FileOperationsClient.InitializeWorkingDirectoryPath();
	DirectoryName = FileOperationsSecondUseClient.GetFileOperationsPersonalSettings().LocalFilesCachePath;
	
	ReadonlyInWorkingDirectory = False;
	InOwnerWorkingDirectory = False;
	PathInRegister = FileOperations.GetFileNameWithPathFromRegister(Ref, DirectoryName, ReadonlyInWorkingDirectory, InOwnerWorkingDirectory);	
	
	// Get path from register
	FileNameWithPath = PathInRegister;
	If FileNameWithPath <> "" Then
		
		// normally do not delete in working directory- only if DeleteEvenInWorkingDirectory is passed
		If Not InOwnerWorkingDirectory OR DeleteEvenInWorkingDirectory = True Then
		
			FileOnHardDisk = New File(FileNameWithPath);
			If FileOnHardDisk.Exist() Then
				file = New File(FileNameWithPath);
				file.SetReadOnly(False);
				FileOperationsClient.DeleteFile(FileNameWithPath);
				
				PathWithSubdirectory = DirectoryName;
				charPosition = Find(PathInRegister, "\");
				If charPosition <> 0 Then
					PathWithSubdirectory = DirectoryName + Left(PathInRegister, charPosition);
				EndIf;
						
				DirectoryFilesArray = FindFiles(PathWithSubdirectory, "*.*");
				If DirectoryFilesArray.Count() = 0 Then
					If PathWithSubdirectory <> DirectoryName Then
						DeleteFiles(PathWithSubdirectory);
					EndIf;
				EndIf;
				
			EndIf;
			
		EndIf;
	
	EndIf;
	
	FileOperations.DeleteFromRegister(Ref);
EndProcedure


// Dereference lnk file
Function DereferenceLnkFile(ChosenFile) Export
	#If Not WebClient Then
		
		If Not StandardSubsystemsClientSecondUse.ClientParameters().ThisIsBasicConfigurationVersion Then
			ShellApp = New COMObject("shell.application");
			FolderObj = ShellApp.NameSpace(ChosenFile.Path);			// full (only) path to lnk-file
			FolderObjItem = FolderObj.items().item(ChosenFile.Name); 	// only lnk-file name
			Link = FolderObjItem.GetLink();
			Return New File(Link.path);
		EndIf;
		
	#EndIf
	
	Return ChosenFile;
EndFunction

// Loop by files is recursive - to know total files size
Procedure CheckFileSizesLimitRecursive(
	FilesArray, 
	TooLargeFilesArray, 
	Recursively, 
	TotalQuantity,
	Val PseudoFileSystem) Export
	
	MaxFileSize = FileOperationsSecondUseClient.GetFileOperationsPersonalSettings().MaximumFileSize;
	
	For Each ChosenFile In FilesArray Do
		Try
			
			If ChosenFile.Exist() Then
				
				If ChosenFile.Extension = ".lnk" Then
					ChosenFile = DereferenceLnkFile(ChosenFile);
				EndIf;
									
				If ChosenFile.IsDirectory() Then
					
					If Recursively Then
						NewPath = String(ChosenFile.Path);
						If Right(NewPath, 1) <> "\" Then
							NewPath = NewPath + "\";
						EndIf;
						NewPath = NewPath + String(ChosenFile.Name);
						DirectoryFilesArray = FileFunctionsClientServer.FindPseudoFiles(PseudoFileSystem, NewPath);
						
						// Recursion
						If DirectoryFilesArray.Count() <> 0 Then
							CheckFileSizesLimitRecursive(DirectoryFilesArray, TooLargeFilesArray, Recursively, TotalQuantity, PseudoFileSystem);
						EndIf;
					EndIf;
				
					Continue;
				EndIf;
				
				TotalQuantity = TotalQuantity + 1;
				
				// File size is too large
				If ChosenFile.Size() > MaxFileSize Then
					TooLargeFilesArray.Add(ChosenFile.FullName);
					Continue;
				EndIf;
			
			EndIf;
			
		Except
			ErrorInfo = ErrorInfo();
			CommonUseClientServer.MessageToUser(StringFunctionsClientServer.SubstitureParametersInString(
						  NStr("en = 'Description=""%1""'"), ErrorInfo.Description));
		EndTry;
	EndDo;
EndProcedure

// Check Max Size Of Files - return False, if there are files exceeding this size,
//   and user has picked 'cancel' in warning dialog about existence of such  files
Function CheckFileSizesLimit(SelectedFiles, Recursively, TotalQuantity, Val PseudoFileSystem, LoadMode = False) Export
	TooLargeFilesArray = New Array; 
	
	Path = "";
	
	FilesArray = New Array;
	TotalQuantity = 0;
	
	For Each FileName In SelectedFiles Do
		
		Path = FileName.Value;
		ChosenFile = New File(Path);

		Try
			ChosenFile = New File(FileName.Value);
			DirectoryChosen = False;
			
			If ChosenFile.Exist() Then
				DirectoryChosen = ChosenFile.IsDirectory();
			EndIf;
			
			If DirectoryChosen Then
				Status(StringFunctionsClientServer.SubstitureParametersInString(
					   NStr("en = 'Collecting %1 folder information. Please wait.'"), Path ));
				
				ThisDirectoryFilesArray = FileFunctionsClientServer.FindPseudoFiles(PseudoFileSystem, Path);
				CheckFileSizesLimitRecursive(ThisDirectoryFilesArray, TooLargeFilesArray, Recursively, TotalQuantity, PseudoFileSystem);
			Else
				FilesArray.Add(ChosenFile);
			EndIf;
		Except
			ErrorInfo = ErrorInfo();
			CommonUseClientServer.MessageToUser(StringFunctionsClientServer.SubstitureParametersInString(
						  NStr("en = 'Description=""%1""'"), ErrorInfo.Description));
		EndTry;
	EndDo;
	
	If FilesArray.Count() <> 0 Then
		CheckFileSizesLimitRecursive(FilesArray, TooLargeFilesArray, Recursively, TotalQuantity, PseudoFileSystem);
	EndIf;
	
	// There is at least one too big file
	If TooLargeFilesArray.Count() <> 0 Then 
		
		FilesBig = New ValueList;
		Parameters = New Structure;
		
		For Each File In TooLargeFilesArray Do
			BigFile = New File(File);
			FileSizeInMB = Int(BigFile.Size() / (1024 * 1024));
			RowText = String(File) + " (" + String(FileSizeInMB) + " " + NStr("en = 'MB)'");
			FilesBig.Add(RowText);
		EndDo; 	
		
		Parameters.Insert("FilesBig", FilesBig);
		Parameters.Insert("LoadMode", LoadMode);
		Parameters.Insert("Title", 	  "Warning on loading files");
		
		Result = OpenFormModal("Catalog.Files.Form.QuestionImportForm", Parameters);
		RefreshReusableValues(); // due to system settings (max size) might be modified already
		Return Result = DialogReturnCode.OK;
		
	EndIf;
	
	Return True;
EndFunction


// Recursive function importing files from disk - accepts files (or directories) array
// - if file, simply adds it, if directory - creates group and recursively calls itself
Procedure ImportFiles(Owner, 
					  FilesArgument, 
					  Indicator, 
					  FileNamesWithErrorsArray, 
					  AllFilesStructuresArray, 
					  Comment, 
					  StoreVersions, 
					  Recursively, 
					  TotalQuantity, 
					  Counter,
					  FormID,
					  Val PseudoFileSystem,
					  AddedFiles,
					  AllFoldersArray,
					  LoadMode = False) Export
	
	Var FirstFolderWithThisName;
	Var DocGroupRef;
	
	MaxFileSize 			    = FileOperationsSecondUseClient.GetFileOperationsPersonalSettings().MaximumFileSize;
	ProhibitFileLoadByExtension = FileOperationsSecondUseClient.GetFileOperationsPersonalSettings().ProhibitFileLoadByExtension;
	ProhibitedExtensionsList    = FileOperationsSecondUseClient.GetFileOperationsPersonalSettings().ProhibitedExtensionsList;
	
	For Each ChosenFile In FilesArgument Do
		Try

			If ChosenFile.Exist() Then

				If ChosenFile.Extension = ".lnk" Then
					ChosenFile = DereferenceLnkFile(ChosenFile);
				EndIf;
				
				If ChosenFile.IsDirectory() Then
					
					If Recursively = True Then
						NewPath = String(ChosenFile.Path);
						FileFunctionsClientServer.AddLastPathSeparatorIfMissing(NewPath);
						NewPath = NewPath + String(ChosenFile.Name);
						FilesArray = FileFunctionsClientServer.FindPseudoFiles(PseudoFileSystem, NewPath);
						
						// Create group in catalog - analog of directory on disk
						If FilesArray.Count() <> 0 Then
							FileName = ChosenFile.Name;
							
							FolderIsAlreadyFound = False;
							
							If FileOperations.FolderExists(FileName, Owner, FirstFolderWithThisName) Then
								
								If LoadMode Then
									FolderIsAlreadyFound = True;
									DocGroupRef = FirstFolderWithThisName;
								Else	
								
									QuestionText = StringFunctionsClientServer.SubstitureParametersInString(
													NStr("en = 'Attention! The %1 folder already exists. Do you want to continue importing folder?'"),
													FileName);
										
									ReturnCode = DoQueryBox(QuestionText, QuestionDialogMode.YesNo);

									If ReturnCode = DialogReturnCode.No Then
										Continue;
									EndIf;
									
								EndIf;
							EndIf;
							
							If Not FolderIsAlreadyFound Then							
								DocGroupRef = FileOperations.CatalogsFoldersCreateItem(FileName, Owner);
							EndIf;
							
							ImportFiles(
								DocGroupRef, 
								FilesArray, 
								Indicator, 
								FileNamesWithErrorsArray, 
								AllFilesStructuresArray, 
								Comment, 
								StoreVersions, 
								Recursively, 
								TotalQuantity, 
								Counter,
								FormID,
								PseudoFileSystem,
								AddedFiles,
								AllFoldersArray,
								LoadMode);
								
							AllFoldersArray.Add(NewPath);	
						EndIf;
					EndIf;
				
					Continue;
				EndIf;
				
				If Not FileFunctionsClientServer.CanLoadFile(ChosenFile, MaxFileSize, ProhibitFileLoadByExtension, ProhibitedExtensionsList, FileNamesWithErrorsArray) Then
					Continue;
				EndIf;	
					
				// Update progress indicator
				Counter = Counter + 1;
				Indicator = Counter * 100 / TotalQuantity; // Calculate percents
				SizeInMB = ChosenFile.Size() / (1024 * 1024);
				LabelMoreDetailed =
				StringFunctionsClientServer.SubstitureParametersInString(
					 NStr("en = 'Processing %1 file (%2 MB)...'"),
					 ChosenFile.Name, ? (SizeInMB >= 1, Format(SizeInMB, "NFD=0"), Format(SizeInMB, "NFD=1; NZ=0") ) );
					 
				StatusText = NStr("en = 'Importing files from disk...'");	 
				If LoadMode Then
					StatusText = NStr("en = 'Loading files from disk...'");	 
				EndIf;
				
				Status(StatusText, 
					   Indicator, 
					   LabelMoreDetailed, 
					   PictureLib.Information32);
				
				// Create item of Files catalog
				BaseName = ChosenFile.BaseName;
				Extension = ChosenFile.Extension;
				
				If LoadMode Then
					If FileOperations.FileExists(BaseName, Owner) Then
						Record = New Structure;
						Record.Insert("FileName", ChosenFile.FullName);
						Record.Insert("Error", NStr("en = 'File with this name already exists in the infobase'"));
						FileNamesWithErrorsArray.Add(Record);
						Continue;
					EndIf;	
				EndIf;	
				
				FileTemporaryStorageAddress = "";

				FilesBeingPlaced = New Array;
				Details = New TransferableFileDescription(ChosenFile.FullName, "");
				FilesBeingPlaced.Add(Details);
				
				PlacedFiles = New Array;
				
				If Not PutFiles(FilesBeingPlaced, PlacedFiles, , False, FormID) Then
					Raise
					  StringFunctionsClientServer.SubstitureParametersInString(
						NStr("en = 'Error of placing file into storage: %1'"), ChosenFile.FullName);
				EndIf;

				If PlacedFiles.Count() = 1 Then
					FileTemporaryStorageAddress = PlacedFiles[0].Location;
				EndIf;
				
				TextTemporaryStorageAddress = ExtractTextToTemporaryStorage(
					ChosenFile.FullName,
					FormID);

				// Create item of Files catalog
				FileFunctionsClientServer.CreateFilesCatalogItem(ChosenFile, AllFilesStructuresArray, 
					Owner, FormID, Comment, StoreVersions, AddedFiles,
					FileTemporaryStorageAddress, TextTemporaryStorageAddress);
				
			Else
				Record = New Structure;
				Record.Insert("FileName", ChosenFile.FullName);
				Record.Insert("Error", NStr("en = 'File does not exist on disk'"));
				FileNamesWithErrorsArray.Add(Record);
			EndIf;

		Except
			ErrorInformation = ErrorInfo();
			ErrorMessage = "";
			If ErrorInformation.Cause = Undefined Then
				ErrorMessage = ErrorInformation.Details;
			Else
				ErrorMessage = ErrorInformation.Cause.Details;
			EndIf;
			CommonUseClientServer.MessageToUser(ErrorMessage);
			
			Record = New Structure;
			Record.Insert("FileName", ChosenFile.FullName);
			Record.Insert("Error", ErrorMessage);
			FileNamesWithErrorsArray.Add(Record);
		
		EndTry;
	EndDo;
EndProcedure

// Import - with auxiliary operations like max size check and final files deletion and errors output
//   if importing sinfle dirs - return link to it
Function ImportFilesExecute(FolderForAdd, 
							SelectedFiles, 
							Comment, 
							StoreVersions, 
							DeleteFilesAfterAdd, 
							Recursively, 
							FormID,
							Val PseudoFileSystem,
							AddedFiles,
							LoadMode = False) Export
	
	Var FirstFolderWithThisName;
	Var FolderForAddingCurrent;

	DirectoryChosen = False;
	Path = "";
	
	TotalQuantity = 0;
	If CheckFileSizesLimit(SelectedFiles, Recursively, TotalQuantity, PseudoFileSystem, LoadMode) = False Then
		Status();
		Return Undefined;
	EndIf;

	Status();
	
	If TotalQuantity = 0 Then
		
		If Not LoadMode Then
			DoMessageBox(NStr("en = 'No files to add'"));
		EndIf;
		
		Return Undefined;
	EndIf;
	
	Indicator = 0;
	
	FilesArray 					= New Array;
	Counter 					= 0;
	FileNamesWithErrorsArray 	= New Array;
	AllFilesStructuresArray 	= New Array;
	AllFoldersArray	 			= New Array;
	
	FolderForAddingCurrent = Undefined;
	
	For Each FileName In SelectedFiles Do
		Try
			ChosenFile = New File(FileName.Value);
			
			DirectoryChosen = False;
			If ChosenFile.Exist() Then
				DirectoryChosen = ChosenFile.IsDirectory();
			EndIf;
			
			If DirectoryChosen Then
				Path = FileName.Value;
				ThisDirectoryFilesArray = FileFunctionsClientServer.FindPseudoFiles(PseudoFileSystem, Path);
				
				FolderName = ChosenFile.Name;
				
				FolderIsAlreadyFound = False;
				
				If FileOperations.FolderExists(FolderName, FolderForAdd, FirstFolderWithThisName) Then
					
					If LoadMode Then
						FolderIsAlreadyFound = True;
						FolderForAddingCurrent = FirstFolderWithThisName;
					Else	
					
						QuestionText = StringFunctionsClientServer.SubstitureParametersInString(
										NStr("en = 'Attention! The %1 folder already exists. Do you want to continue folder importing?'"),
										FolderName);
							
						ReturnCode = DoQueryBox(QuestionText, QuestionDialogMode.YesNo);

						If ReturnCode = DialogReturnCode.No Then
							Continue;
						EndIf;
						
					EndIf;
				EndIf;
				
				If Not FolderIsAlreadyFound Then
					FolderForAddingCurrent = FileOperations.CatalogsFoldersCreateItem(FolderName, FolderForAdd);
				EndIf;
				
				// Import itself
				ImportFiles(
					FolderForAddingCurrent, 
					ThisDirectoryFilesArray, 
					Indicator, 
					FileNamesWithErrorsArray, 
					AllFilesStructuresArray, 
					Comment, 
					StoreVersions, 
					Recursively, 
					TotalQuantity, 
					Counter,
					FormID,
					PseudoFileSystem,
					AddedFiles,
					AllFoldersArray,
					LoadMode);
				AllFoldersArray.Add(Path);	
					
			Else
				FilesArray.Add(ChosenFile);
			EndIf;
		Except
			ErrorInfo = ErrorInfo();
			CommonUseClientServer.MessageToUser(StringFunctionsClientServer.SubstitureParametersInString(
					   NStr("en = 'Description=""%1""'"), ErrorInfo.Description));
		EndTry;
	EndDo;
	
	If FilesArray.Count() <> 0 Then
		// Import itself
		ImportFiles(
			FolderForAdd, 
			FilesArray, 
			Indicator, 
			FileNamesWithErrorsArray, 
			AllFilesStructuresArray, 
			Comment, 
			StoreVersions, 
			Recursively, 
			TotalQuantity, 
			Counter,
			FormID,
			PseudoFileSystem,
			AddedFiles,
			AllFoldersArray,
			LoadMode);
	EndIf;
	
	If AllFilesStructuresArray.Count() > 1 Then
		
		StatusText = StringFunctionsClientServer.SubstitureParametersInString(
			NStr("en = 'File import has been completed. %1 files imported'"), String(AllFilesStructuresArray.Count()) );
			
		If LoadMode Then
			StatusText = StringFunctionsClientServer.SubstitureParametersInString(
				NStr("en = 'Files loading completed. %1 files loaded'"), String(AllFilesStructuresArray.Count()) );
		EndIf;
		
		Status(StatusText);
	Else
		Status();
	EndIf;
	
	If DeleteFilesAfterAdd = True Then
		FileFunctionsClientServer.DeleteFilesAfterAdding(AllFilesStructuresArray, AllFoldersArray, LoadMode);
	EndIf;
	
	If AllFilesStructuresArray.Count() = 1 Then
		FirstItem = AllFilesStructuresArray[0];
		Ref = GetURL(FirstItem.File);
		ShowUserNotification(
			NStr("en = 'Updating:'"),
			ref,
			FirstItem.File,
			PictureLib.Information32);
	EndIf;
	
	// Output error messages
	If FileNamesWithErrorsArray.Count() <> 0 Then
		
		Parameters = New Structure;
		Parameters.Insert("FileNamesWithErrorsArray", FileNamesWithErrorsArray);
		If LoadMode Then
			Parameters.Insert("Title", "Report about files loading");
		EndIf;
		
		OpenForm("Catalog.Files.Form.ReportForm", Parameters);
	EndIf;
	
	If SelectedFiles.Count() <> 1 Then
		FolderForAddingCurrent = Undefined;
	EndIf;	
	
	Return FolderForAddingCurrent;
EndFunction

// Extract text from file and place it in temporary storage
Function ExtractTextToTemporaryStorage(FullFileName, FormID) Export
	TemporaryStorageAddress = "";
	
#If Not WebClient Then
	ExtractFileTextsAtServer = FileOperationsSecondUseClient.GetFileOperationsPersonalSettings().ExtractFileTextsAtServer;
	If Not ExtractFileTextsAtServer Then
		Try
			Extraction = New TextExtraction(FullFileName);
			Text = Extraction.GetText();
		Except
			Text = "";
		EndTry;
	EndIf;

	If IsBlankString(Text) Then
		Return "";
 	EndIf;

	TemporaryFileName = GetTempFileName();
	TextFile = New TextWriter(TemporaryFileName, TextEncoding.Utf8);
	TextFile.Write(Text);
	TextFile.Close();

	PutFile(TemporaryStorageAddress, TemporaryFileName, , False, FormID);
	DeleteFiles(TemporaryFileName);
#EndIf

	Return TemporaryStorageAddress;
EndFunction

// Function gets path to a catalog in format: "C:\Documents and Settings\USER NAME\Application Data\1C\FilesA8\"
Function GetPathToUserDataDirectory() Export
	DirectoryName = "";
#If Not WebClient Then

	If Not StandardSubsystemsClientSecondUse.ClientParameters().ThisIsBasicConfigurationVersion Then
		Shell = New COMObject("WScript.Shell");
		Path = Shell.ExpandEnvironmentStrings("%APPDATA%");
		Path = Path + "\1C\Files\";
		Path = Path + FileOperationsSecondUseClient.GetFileOperationsPersonalSettings().ConfigurationName + "\";
		
		DirectoryName = Path + FileOperationsSecondUseClient.GetFileOperationsPersonalSettings().CurrentUser + " " + FileOperations.SessionParametersCurrentUserID() + "\";
		DirectoryName = StrReplace(DirectoryName, "<", " ");
		DirectoryName = StrReplace(DirectoryName, ">", " ");
		DirectoryName = TrimAll(DirectoryName);
	EndIf;	
#Else // WebClient
	IsExtensionAttached = AttachFileSystemExtension();
	
	If IsExtensionAttached Then
		
		Mode = FileDialogMode.ChooseDirectory;
		FileOpenDialog = New FileDialog(Mode);
		FileOpenDialog.FullFileName = "";
		FileOpenDialog.Directory = "";
		FileOpenDialog.Multiselect = False;
		FileOpenDialog.Title = NStr("en = 'Select path to the the local file cache'");
		If FileOpenDialog.Choose() Then
			DirectoryName = FileOpenDialog.Directory;
			DirectoryName = DirectoryName + "\";
		EndIf;
		
	EndIf;		
#EndIf

	Return DirectoryName;
EndFunction

// Returns name with extesion - if extension is empty - just name
Function GetNameWithExtention(Name, Extension) Export
	NameWithExtention = Name;
	
	If Extension <> "" Then
		NameWithExtention = NameWithExtention + "." + Extension;
	EndIf;
	
	Return NameWithExtention;
EndFunction

// Extracts text from file on disk at client and places result at server
&AtClient
Procedure ExtractVersionText(VersionRef, FileAddress, Extension, UUID) Export
#If Not WebClient Then
	
	FileNameWithPath = GetTempFileName(Extension);
	
	If Not GetFile(FileAddress, FileNameWithPath, False) Then
		Return;
	EndIf;	
		
	// for the variant when files are located on disk (at server) - delete file from temporary storage after getting it
	If IsTempStorageURL(FileAddress) Then
		DeleteFromTempStorage(FileAddress);
	EndIf;
	
	ExtractionResult = "NotExtracted";
	TextTemporaryStorageAddress = "";
	
	Text = "";
	If FileNameWithPath <> "" Then
		Try
			// Extracting text from file
			Extraction = New TextExtraction(FileNameWithPath);
			Text = Extraction.GetText();
			ExtractionResult = "Extracted";
			
			If Not IsBlankString(Text) Then
				TemporaryFileName = GetTempFileName();
				TextFile = New TextWriter(TemporaryFileName, TextEncoding.Utf8);
				TextFile.Write(Text);
				TextFile.Close();

				PutFile(TextTemporaryStorageAddress, TemporaryFileName, , False, UUID);
				DeleteFiles(TemporaryFileName);
			EndIf;
			
		Except // Write nothing - it's normal - when can not extract text
			ExtractionResult = "ExtractFailed";
		EndTry;
	EndIf;
	
	DeleteFiles(FileNameWithPath);

	FileOperations.WriteTextExtractionResult(VersionRef, 
		ExtractionResult, TextTemporaryStorageAddress);
		
	If Not IsBlankString(TextTemporaryStorageAddress) Then
		DeleteFromTempStorage(TextTemporaryStorageAddress);
	EndIf;
	
#EndIf	
EndProcedure	
