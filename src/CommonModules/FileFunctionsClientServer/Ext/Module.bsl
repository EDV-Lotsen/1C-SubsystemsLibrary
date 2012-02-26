
// Get unique file name in working directory - if there are repeats - make name of type A1\qqq.doc
//
Function GetUniqueNameWithPath(DirectoryName, FileName) Export 
	ResultantPath = ""; 
	        	
	Counter 		= 0;
	CycleNumber 	= 0;
	Successfully 	= False;
	
	RandomNumberGenerator = Undefined;
	#If Not WebClient Then
		RandomNumberGenerator = New RandomNumberGenerator(Second(CurrentDate()));
	#EndIf
	
	While Not Successfully And CycleNumber < 100 Do
		DirectoryNumber = 0;
		#If Not WebClient Then
			DirectoryNumber = RandomNumberGenerator.RandomNumber(0, 25);
		#Else
			DirectoryNumber = Second(CurrentDate()) % 26;
		#EndIf
		
		LetterACode = CharCode("A", 1); 
		DirectoryCode = LetterACode + DirectoryNumber;
		
		DirectoryLetter = Char(DirectoryCode);
		
		Subdirectory = ""; // Partial path

		// By default save in root first, and after,
		//  if won't be able to write, then save to A, B, ... Z,  A1, B1, .. Z1, ..  A2, B2 and etc.
		If  Counter = 0 Then
			Subdirectory = "";
		Else
			Subdirectory = DirectoryLetter; 
			CycleNumber = Round(Counter / 26);
			
			If CycleNumber <> 0 Then
				CycleNumberRow 	= String(CycleNumber);
				Subdirectory 	= Subdirectory + CycleNumberRow;
			EndIf;
			
			Subdirectory = Subdirectory + "\";  
		EndIf;

		FullSubdirectory = DirectoryName + Subdirectory;  

		// Create directory for files
		DirectoryOnDisk = New File(FullSubdirectory);
		If Not DirectoryOnDisk.Exist() Then
			CreateDirectory(FullSubdirectory);
		EndIf;
		
		AttemptFile = FullSubdirectory + FileName;
		Counter = Counter + 1;
		
		// Check, if file with this name exists
		FileOnDisk = New File(AttemptFile);
		If Not FileOnDisk.Exist() Then  // no such file
			ResultantPath = Subdirectory + FileName;
			Successfully = True;
		EndIf;
	EndDo;
	
	Return ResultantPath;	
EndFunction

// Get unique file name in working directory - if there are repeats - make name of type A1\qqq.doc
//
Function GetUniqueNamesWithPathArray(DirectoryName, MainAndSubordinateFilesArray, FullNamesArray) Export 
	        	
	Counter 		= 0;
	CycleNumber 	= 0;
	Successfully 	= False;
	              	
	RandomNumberGenerator = Undefined;
	#If Not WebClient Then
		RandomNumberGenerator = New RandomNumberGenerator(Second(CurrentDate()));
	#EndIf
	
	While Not Successfully And CycleNumber < 100 Do
		DirectoryNumber = 0;
		#If Not WebClient Then
			DirectoryNumber = RandomNumberGenerator.RandomNumber(0, 25);
		#Else
			DirectoryNumber = Second(CurrentDate()) % 26;
		#EndIf
		
		LetterACode = CharCode("A", 1); 
		DirectoryCode = LetterACode + DirectoryNumber;
		
		DirectoryLetter = Char(DirectoryCode);
		
		Subdirectory = ""; // Partial path

		// By default save in root first, and after,
		//  if won't be able to write, then save to A, B, ... Z,  A1, B1, .. Z1, ..  A2, B2 and etc.
		If  Counter = 0 Then
			Subdirectory = "";
		Else
			Subdirectory = DirectoryLetter; 
			CycleNumber = Round(Counter / 26);
			
			If CycleNumber <> 0 Then
				CycleNumberRow = String(CycleNumber);
				Subdirectory = Subdirectory + CycleNumberRow;
			EndIf;
			
			Subdirectory = Subdirectory + "\";  
		EndIf;

		FullSubdirectory = DirectoryName + Subdirectory;  

		
		FullNamesArray.Clear();
		Successfully = True;
		
		For Each NameAndPath In MainAndSubordinateFilesArray Do
			
			AttemptFile = FullSubdirectory + NameAndPath;
			
			// Check, if file with such name exists
			FileOnDisk = New File(AttemptFile);
			
			If Not FileOnDisk.Exist() Then  // no such file
				
				// Create directory for the files
				CreateDirectory(FileOnDisk.Path);
				
				ResultantPath = Subdirectory + NameAndPath;
				FullNamesArray.Add(ResultantPath);
			Else	
				FullNamesArray.Clear();
				Successfully = False;
				Break; // break on over subordinate files
			EndIf;

		EndDo;	
		
		
		Counter = Counter + 1;
		
	EndDo;
	
	Return Successfully;	
EndFunction

// Return True if file can be loaded (size is less than max, extension is not prohibited)
Function CanLoadFile(SelectedFile, MaxFileSize, ProhibitFileLoadByExtension, 
	ProhibitedExtensionsList, FileNamesWithErrorsArray) Export
	
	// File size is too big
	If SelectedFile.Size() > MaxFileSize Then
		
		SizeInMB = SelectedFile.Size() / (1024 * 1024);
		MaxSizeInMB = MaxFileSize / (1024 * 1024);
		
		Record = New Structure;
		Record.Insert("FileName", SelectedFile.FullName);
		Record.Insert("Error", StringFunctionsClientServer.SubstitureParametersInString(
						NStr("en = 'File size (%1 MB) exceeds the maximum file size (%2 MB)'"),
						?(SizeInMB >= 1, Format(SizeInMB, "NFD=0"), Format(SizeInMB, "NFD=1; NZ=0")), 
						?(MaxSizeInMB >= 1, Format(MaxSizeInMB, "NFD=0"), Format(MaxSizeInMB, "NFD=1; NZ=0"))
						)); 
		FileNamesWithErrorsArray.Add(Record);
		
		Return False;
	EndIf;
	
	// file extension is in the list of prohibited extensions
	FileExtension = SelectedFile.Extension;
	If Not FileOperationsClientServer.FileExtensionAllowedForLoad(ProhibitFileLoadByExtension, ProhibitedExtensionsList, FileExtension) Then
		
		Record = New Structure;
		Record.Insert("FileName", SelectedFile.FullName);
		Record.Insert("Error", StringFunctionsClientServer.SubstitureParametersInString(
				NStr("en = 'Loading files with %1 extension is prohibited. If you have any questions contact administrator.'"),
				 FileExtension));
		FileNamesWithErrorsArray.Add(Record);
		
		Return False;
	EndIf;
	
	// do not import temporary Word files
	If Left(SelectedFile.Name, 1) = "~" And SelectedFile.GetHidden() = True Then
		Return False;
	EndIf;
	
	Return True;
EndFunction	

// creates Files catalog item
Function CreateFilesCatalogItem(SelectedFile, AllFilesStructuresArray, Owner, 
								FormID, Comment, StoreVersions, AddedFiles,
								FileTemporaryStorageAddress, TextTemporaryStorageAddress,
								User = Undefined) Export

	BaseName = SelectedFile.BaseName;
	Extension = SelectedFile.Extension;
	
	Extension = RemoveDotFromExtension(SelectedFile.Extension);
	ModificationTime = SelectedFile.GetModificationTime();
	ModificationDateUniversal = SelectedFile.GetModificationUniversalTime();
	Size = SelectedFile.Size();
	
	// Create file and version in infobase
	DocRef = FileOperations.CreateFileWithVersion(
		Owner,
		BaseName,
		Extension,
		ModificationTime,
		ModificationDateUniversal,
		Size,
		FileTemporaryStorageAddress,
		TextTemporaryStorageAddress,
		False,  // this is not web client
		User,
		Comment);
	
	DeleteFromTempStorage(FileTemporaryStorageAddress);	
	If Not IsBlankString(TextTemporaryStorageAddress) Then
		DeleteFromTempStorage(TextTemporaryStorageAddress);	
	EndIf;	

	AddedFileAndPath = New Structure("FileRef, Path", DocRef, SelectedFile.Path);	
	AddedFiles.Add(AddedFileAndPath);
	
	Record = New Structure;
	Record.Insert("FileName", SelectedFile.FullName);
	Record.Insert("File", DocRef);
	AllFilesStructuresArray.Add(Record);

EndFunction

// add "\" at the end
Procedure AddLastPathSeparatorIfMissing(NewPath) Export
	If Right(NewPath, 1) <> "\" And Right(NewPath,1) <> "/" Then
		NewPath = NewPath + "\";
	EndIf;
EndProcedure	

// deletes files after import or loading
Procedure DeleteFilesAfterAdding(AllFilesStructuresArray, AllFoldersArray, LoadMode) Export
	
	For Each Item In AllFilesStructuresArray Do
		SelectedFile = New File(Item.FileName);
		SelectedFile.SetReadOnly(False);
		DeleteFiles(SelectedFile.FullName);
	EndDo;
	
	If LoadMode Then
		For Each Item In AllFoldersArray Do
			FilesFound = FindFiles(Item, "*.*");
			If FilesFound.Count() = 0 Then
				SelectedFile = New File(Item);
				SelectedFile.SetReadOnly(False);
				DeleteFiles(SelectedFile.FullName);
			EndIf;
		EndDo;
	EndIf;
	
EndProcedure	

// Function transforms file extension to the following format: without points and in lower register
// Parameters:
//  StrExtension - String. Extension for transformation
// Value returned:
//  Transformed String
Function RemoveDotFromExtension(StrExtension) Export
	Extension = Lower(TrimAll(StrExtension));
	If Mid(Extension, 1, 1) = "." Then
		Extension = Mid(Extension, 2);
	EndIf;
	Return Extension;
EndFunction // RemoveDotFromExtension()

// Returns array of files, emulating operation FindFiles - not by the file system, but by Map
//  if PseudoFileSystem is empty - works with file system
Function FindPseudoFiles(Val PseudoFileSystem, Path) Export
	If PseudoFileSystem.Count() = 0 Then
		Files = FindFiles(Path, "*.*");
		Return Files;
	EndIf;
	
	Files = New Array;
	
	ValueFound = PseudoFileSystem.Get(String(Path));
	If ValueFound <> Undefined Then
		For Each FileName In ValueFound Do
			Try
				FileFromList = New File(FileName);
				Files.Add(FileFromList);
			Except
			EndTry;
		EndDo;
	EndIf;
	
	Return Files;
EndFunction
