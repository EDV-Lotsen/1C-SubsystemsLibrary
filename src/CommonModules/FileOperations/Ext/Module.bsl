
////////////////////////////////////////////////////////////////////////////////
// MODULE CONTAINS MECHANICS OF OPERATIONS WITH FILES
//

// Releases the file
// Parameters:
// FileData - structure, containing file info
// 	see function GetFileData()
Procedure UnlockFile(FileData, UUID = Undefined) Export
	
	FileObject = FileData.Ref.GetObject();
	
	LockDataForEdit(FileObject.Ref, , UUID);
	FileObject.LockedBy = Catalogs.Users.EmptyRef();
	FileObject.Write();
	UnlockDataForEdit(FileObject.Ref, UUID);
	
EndProcedure	

// Locks file for edit (checkout)
Function LockFile(FileData, ErrorString = "", UUID = Undefined) Export

	If Not FileOperationsOverrided.FileLockingPermitted(FileData, ErrorString) Then 
		Return False;
	EndIf;
	
	FileObject = FileData.Ref.GetObject();
	
	LockDataForEdit(FileObject.Ref, , UUID);
	FileObject.LockedBy = CommonUse.CurrentUser();
	FileObject.Write();
	UnlockDataForEdit(FileObject.Ref, UUID);

	CurrentVersionURL   = FileData.CurrentVersionURL;
	OwnerWorkingDirectory = FileData.OwnerWorkingDirectory;
	
	FileData = GetFileData(FileData.Ref, FileData.Version);
		
	FileData.CurrentVersionURL 	= CurrentVersionURL;
	FileData.OwnerWorkingDirectory  = OwnerWorkingDirectory;
	
	Return True;
	
EndFunction // LockFile()

// Move File to another folder
Procedure MoveFileToFolder(FileData, Folder) Export 
	
	FileObject = FileData.Ref.GetObject();
	FileObject.Lock();
	FileObject.FileOwner = Folder;
	FileObject.Write();
	
EndProcedure

// Creates File dossier in DB
Function CreateFile(Val Owner, Val Comment, Val BaseName, 
	Val Extension, Val StoreVersions, Val TextTemporaryStorageAddress,
	User = Undefined) Export
	
	File 			 = Catalogs.Files.CreateItem();
	File.FileOwner   = Owner;
	File.Description = BaseName;
	File.FileName 	 = BaseName;
	
	If User = Undefined Then
		File.Author = CommonUse.CurrentUser();
	Else	
		File.Author = User;
	EndIf;	
	
	File.CreationDate 	= CurrentDate();
	File.Details 		= Comment;
	File.PictureIndex 	= FileOperationsClientServer.GetFilePictogramIndex(Undefined);
	File.StoreVersions 	= StoreVersions;
	
	Text 			 = GetStringFromTemporaryStorage(TextTemporaryStorageAddress);
	File.TextStorage = New ValueStorage(Text);
	
	File.Write();
	Return File.Ref;
	
EndFunction // CreateFile()

// Function transforms file extension to the
// following presentation: without points and in lower register
//
// Parameters:
//  StrExtension - String. Extension for transformation
// Value returned:
//  Transformed String
//
Function RemoveDotFromExtension(strExtension) Export
	Extension = Lower(TrimAll(strExtension));
	If Mid(Extension, 1, 1) = "." Then
		Extension = Mid(Extension, 2);
	EndIf;
	Return Extension;
EndFunction // RemoveDotFromExtension()

// Creates version of the file being saved for storing in File dossier
// and inserts link to the version into File dossier
Procedure CreateVersionAndUpdateFileCurrentVersion(Modified,
												   ModificationDateUniversal,
												   DocRef, 
												   BaseName, 
												   Size, 
												   Extension, 
												   FileTemporaryStorageAddress, 
												   TextTemporaryStorageAddress,
												   ThisIsWebClient = False,
												   User 		   = Undefined) Export
	
	VersionRef = CreateFileVersion(
		Modified, 
		ModificationDateUniversal,
		DocRef, 
		BaseName, 
		Size, 
		Extension, 
		FileTemporaryStorageAddress, 
		TextTemporaryStorageAddress,
		ThisIsWebClient,
		Undefined, // RefToVersionSource
		Undefined, // NewVersionCreationDate
		User,
		Undefined, // NewVersionComment
		Undefined  // NewVersionVersionNo
		);

	UpdateFileCurrentVersion(DocRef, VersionRef, TextTemporaryStorageAddress);
	
EndProcedure // CreateVersionAndUpdateFileCurrentVersion()


// Finds maximum version number for the current File object. If there are no versions - 0
Function FindMaximumVersionNumber(FileRef)
	Query = New Query;
	Query.Text = 
		"SELECT
		|	ISNULL(MAX(Versions.VersionNo), 0) AS MaximumNumber
		|FROM
		|	Catalog.FileVersions AS Versions
		|WHERE
		|	Versions.Owner = &File";
	
	Query.Parameters.Insert("File", FileRef);
		
	Selection = Query.Execute().Choose();
	If Selection.Next() Then
		
		If Selection.MaximumNumber = Null Then
			Return 0;
		EndIf;
		
		Return Number(Selection.MaximumNumber);
	EndIf;
	
	Return 0;
EndFunction // FindMaximumVersionNumber

// Returns full volume path - depending on OS
Function VolumeFullPath(VolumeRef) Export
	
	ServerPlatformType = FileOperationsSecondUse.ServerPlatformType();
	
	If ServerPlatformType = PlatformType.Windows_x86 OR ServerPlatformType = PlatformType.Windows_x86_64 Then
		Return VolumeRef.FullPathWindows;
	Else	
		Return VolumeRef.FullPathLinux;
	EndIf;
	
EndFunction

// Adds file to one of the volumes (where is enough of space)
Procedure AddToDisk(BinaryData, FilePath, VolumeRef, ModificationTime, 
	VersionNo, BaseName, Extension, FileSize) Export
	
	PathToVolume = "";
	VolumeRef = Catalogs.FileStorageVolumes.EmptyRef();
	
	Selection = Catalogs.FileStorageVolumes.Select(,,, "FillSequence Asc");
	
	VolumeFound  		  = False;
	FileSuccessfullyAdded = False;
	
	AllErrorDetails = ""; // collect errors from all volumes here
	
	While Selection.Next() Do
		VolumeRef   = Selection.GetObject();
		VolumeFound = True;
		
		PathToVolume = VolumeFullPath(VolumeRef);
		// Add closing slash, if it is missing
		PathToVolume = FileFunctionsClientServer.AddLastPathSeparatorIfMissing(PathToVolume);
		
		// Name file for storing on disk generate in following format:
		// - file name.version number.file extension
		FileName = BaseName + "." + VersionNo + "." + Extension;
		
		Try
			
			// If MaximumSize = 0 - there is no restriction for max file size on volume
			If VolumeRef.MaximumSize <> 0 Then
				CurrentSizeInBytes 	= FileOperations.CalculateFilesSizeOnVolume(VolumeRef.Ref); 
				NewSizeInBytes 		= CurrentSizeInBytes + FileSize;
				NewSize 			= NewSizeInBytes / (1024 * 1024);
				
				If NewSize > VolumeRef.MaximumSize Then
					ErrorString 
						= StringFunctionsClientServer.SubstitureParametersInString(NStr("en = 'Maximum volume size (%1 MB) exceeded'"),
						VolumeRef.MaximumSize);
					Raise(ErrorString);
				EndIf;		
			EndIf;
			
			Date = CurrentDate();
			DayPath = Format(Date, "DF=yyyyMMdd") + "\";
			PathToVolume = PathToVolume + DayPath;
			
			FileNameWithPath = FileFunctionsClientServer.GetUniqueNameWithPath(PathToVolume, FileName);
			FullFileNameWithPath = PathToVolume + FileNameWithPath;
			
			If TypeOf(BinaryData) = Type("BinaryData") Then
				BinaryData.Write(FullFileNameWithPath);
			Else // consider, that otherwise this is a path to file on disk
				FileCopy(BinaryData, FullFileNameWithPath);
			EndIf;
			
			// Set file modification time equal to the time in current version
			FileOnDisk = New File(FullFileNameWithPath);
			FileOnDisk.SetModificationTime(ModificationTime);
			FileOnDisk.SetReadOnly(True);
			
			FilePath = DayPath + FileNameWithPath;
			FileSuccessfullyAdded = True;
			Break; // completed, breaking the loop
		Except
			If AllErrorDetails <> "" Then
				AllErrorDetails = AllErrorDetails + Chars.LF + Chars.LF;
			EndIf;
			
			AllErrorDetails = AllErrorDetails + NStr("en = 'Error occurred while adding a file to a volume:'");
			AllErrorDetails = AllErrorDetails + VolumeRef;
			AllErrorDetails = AllErrorDetails + " (" + PathToVolume + "): ";
			AllErrorDetails = AllErrorDetails + DetailErrorDescription(ErrorInfo());
			
			If VolumeRef.FullPathLinux = VolumeRef.FullPathWindows Then
				AllErrorDetails = AllErrorDetails + Chars.LF;
				AllErrorDetails = AllErrorDetails + NStr("en = 'Customise full path to volume.'");
			EndIf;	
			// need to jump to the next volume
			Continue;
		EndTry;
		
	EndDo;
	
	If VolumeFound = False Then
		Raise(NStr("en = 'There is no volumes to place a file at.'"));
	EndIf;
	
	If FileSuccessfullyAdded = False Then
		// eventlog record for the administrator
		// output errors from all the volumes here
		ErrorMessage = NStr("en = 'Failed to add a file to any of volumes.
                             |Error list:'") + Chars.LF + Chars.LF + AllErrorDetails;
		WriteLogEvent("File insert", EventLogLevel.Error, , , ErrorMessage);
		
		// here user message
		ExceptionString = StringFunctionsClientServer.SubstitureParametersInString(
				 NStr("en = 'Failed to add file ""%1.%2"". Contact the system administrator.'"),
				 BaseName, Extension);
		Raise(ExceptionString);
	EndIf;

EndProcedure // AddToDisk

// Returns maximum file size
Function GetMaximumFileSize() Export
	SetPrivilegedMode(True);
	MaximumFileSize = Constants.MaximumFileSize.Get();
	SetPrivilegedMode(False);
	Return MaximumFileSize;
EndFunction

// Returns ProhibitFileLoadByExtension
Function GetProhibitFileLoadByExtension() Export
	SetPrivilegedMode(True);
	ProhibitFileLoadByExtension = Constants.ProhibitFileLoadByExtension.Get();
	SetPrivilegedMode(False);
	Return ProhibitFileLoadByExtension;
EndFunction

// Returns ProhibitedExtensionsList
Function GetProhibitedExtensionsList() Export
	SetPrivilegedMode(True);
	ProhibitedExtensionsList = Constants.ProhibitedExtensionsList.Get();
	SetPrivilegedMode(False);
	Return ProhibitedExtensionsList;
EndFunction

// Creates version of the file being saved for storing in File dossier
Function CreateFileVersion(
	ModificationTime,
	ModificationDateUniversal,
	DocRef, 
	BaseName, 
	Size, 
	Extension, 
	FileTemporaryStorageAddress, 
	TextTemporaryStorageAddress,
	ThisIsWebClient 		= False,
	RefToVersionSource 		= Undefined,
	NewVersionCreationDate 	= Undefined,
	NewVersionAuthor 		= Undefined,
	NewVersionComment 		= Undefined,
	NewVersionVersionNo 	= Undefined) Export
	
	Var VolumeRef;
	
	SetPrivilegedMode(True);

	ProhibitFileLoadByExtension = GetProhibitFileLoadByExtension();
	ProhibitedExtensionsList 	= GetProhibitedExtensionsList();
	FileExtension = Extension;
	If Not FileOperationsClientServer.FileExtensionAllowedForLoad(ProhibitFileLoadByExtension, ProhibitedExtensionsList, FileExtension) Then
		Raise StringFunctionsClientServer.SubstitureParametersInString(
			NStr("en = 'Loading files with %1 extension is prohibited. Contact the system administrator.'"),
			FileExtension);
	EndIf;	
	
	Version = Catalogs.FileVersions.CreateItem();
	
	If NewVersionVersionNo = Undefined Then
		Version.VersionNo = FindMaximumVersionNumber(DocRef) + 1;
	Else
		Version.VersionNo = NewVersionVersionNo;
	EndIf;
	
	Version.Owner = DocRef;
	Version.ModificationDateUniversal = ModificationDateUniversal;
	
	Version.Comment = NewVersionComment;
	
	If NewVersionAuthor = Undefined Then
		Version.Author = CommonUse.CurrentUser();
	Else
		Version.Author = NewVersionAuthor;
	EndIf;	
	
	If NewVersionCreationDate = Undefined Then
		Version.CreationDate = CurrentDate();
	Else
		Version.CreationDate = NewVersionCreationDate;
	EndIf;	
	
	Version.FileName 	= BaseName;
	Version.Size 		= Size;
	Version.Extension 	= RemoveDotFromExtension(Extension);
	
	FileStorageType 		= Constants.FileStorageType.Get();
	Version.FileStorageType = FileStorageType;

	If RefToVersionSource <> Undefined Then // creating file from template
		
		TemplateFilesStorageType = RefToVersionSource.FileStorageType;
		
		If TemplateFilesStorageType = Enums.FileStorageTypes.Infobase And FileStorageType = Enums.FileStorageTypes.Infobase Then
			//  the template, and a new file - in the database
			
			// When creating file from template -  value storage is being copied directly
			Version.FileStorage = FileTemporaryStorageAddress;
			
		ElsIf TemplateFilesStorageType = Enums.FileStorageTypes.VolumesOnHardDisk And FileStorageType = Enums.FileStorageTypes.VolumesOnHardDisk Then
			//  the template, and a new file - are on disk - simply copy file
			
			If Not RefToVersionSource.Volume.IsEmpty() Then
				FullTemplateFilePath = VolumeFullPath(RefToVersionSource.Volume) + RefToVersionSource.FilePath; 
				
				FilePath = "";
				
				// add to one of the volumes (where is enough of space)
				AddToDisk(FullTemplateFilePath, FilePath, VolumeRef, ModificationTime, Version.VersionNo, BaseName, Extension, Version.Size);
				Version.FilePath = FilePath;
				Version.Volume = VolumeRef.Ref;
			EndIf;
			
		ElsIf TemplateFilesStorageType = Enums.FileStorageTypes.Infobase And FileStorageType = Enums.FileStorageTypes.VolumesOnHardDisk Then
			// template is in database, new File - on disk
			
			BinaryData = FileTemporaryStorageAddress.Get(); // in this case ValueStorage with file is in FileTemporaryStorageAddress
			
			FilePath = "";
			
			// add to one of the volumes (where is enough of space)
			AddToDisk(BinaryData, FilePath, VolumeRef, ModificationTime, Version.VersionNo, BaseName, Extension, Version.Size);
			Version.FilePath = FilePath;
			Version.Volume = VolumeRef.Ref;
			
		ElsIf TemplateFilesStorageType = Enums.FileStorageTypes.VolumesOnHardDisk And FileStorageType = Enums.FileStorageTypes.Infobase Then
			// template is on disk, new file - in database
			
			If Not RefToVersionSource.Volume.IsEmpty() Then
				FullTemplateFilePath = VolumeFullPath(RefToVersionSource.Volume) + RefToVersionSource.FilePath; 
				BinaryData = New BinaryData(FullTemplateFilePath);
				Version.FileStorage = New ValueStorage(BinaryData);
			EndIf;
			
		EndIf;
	Else // creating file object based on the file picked from disk
		
		If FileStorageType = Enums.FileStorageTypes.Infobase Then
			Version.FileStorage = New ValueStorage(
				GetFromTempStorage(FileTemporaryStorageAddress));
				
			If (ThisIsWebClient = True) And (Version.Size = 0) Then
				FileBinaryData = Version.FileStorage.Get();
				Version.Size = FileBinaryData.Size();
				
				MaxFileSize = GetMaximumFileSize();
				SizeInMB = Version.Size / (1024 * 1024);
				MaxSizeInMB = MaxFileSize / (1024 * 1024);
				
				If Version.Size > MaxFileSize Then
					Raise
						   StringFunctionsClientServer.SubstitureParametersInString(
							 NStr("en = 'Size of %1 file (%2 MB) exceeds the maximum allowed file size (%3MB).'"),
							 BaseName, 
							 ?(SizeInMB >= 1, Format(SizeInMB, "NFD=0"), Format(SizeInMB, "NFD=1; NZ=0")), 
							 ?(MaxSizeInMB >= 1, Format(MaxSizeInMB, "NFD=0"), Format(MaxSizeInMB, "NFD=1; NZ=0")));
				EndIf;
				
			EndIf;
				
		Else // storing on disk
			
			BinaryData = GetFromTempStorage(FileTemporaryStorageAddress);
			
			If (ThisIsWebClient = True) And (Version.Size = 0) Then
				Version.Size = BinaryData.Size();
				
				MaxFileSize = GetMaximumFileSize();
				SizeInMB = Version.Size / (1024 * 1024);
				MaxSizeInMB = MaxFileSize / (1024 * 1024);
				
				If Version.Size > MaxFileSize Then
					Raise
						   StringFunctionsClientServer.SubstitureParametersInString(
							 NStr("en = 'Size of %1 file (%2 MB) exceeds the maximum allowed file size (%3MB).'"),
							 BaseName, 
							 ?(SizeInMB >= 1, Format(SizeInMB, "NFD=0"), Format(SizeInMB, "NFD=1; NZ=0")), 
							 ?(MaxSizeInMB >= 1, Format(MaxSizeInMB, "NFD=0"), Format(MaxSizeInMB, "NFD=1; NZ=0")));
				EndIf;
			EndIf;
			
			FilePath = "";
			
			// add to one of the volumes (where is enough of space)
			AddToDisk(BinaryData, FilePath, VolumeRef, ModificationTime, Version.VersionNo, BaseName, Extension, Version.Size);
			Version.FilePath = FilePath;
			Version.Volume = VolumeRef.Ref;
			
		EndIf; // storing on disk
			
	EndIf;	
	
	Version.TextExtractionStatus = Enums.FileTextExtractionStatuses.NotExtracted;

	If TypeOf(TextTemporaryStorageAddress) = Type("ValueStorage") Then
		// When creating File from template the value storage is being copied directly
		Version.TextStorage 		 = TextTemporaryStorageAddress;
		Version.TextExtractionStatus = Enums.FileTextExtractionStatuses.Extracted;
	ElsIf Not IsBlankString(TextTemporaryStorageAddress) Then
		Text 						 = GetStringFromTemporaryStorage(TextTemporaryStorageAddress);
		Version.TextStorage 		 = New ValueStorage(Text);
		Version.TextExtractionStatus = Enums.FileTextExtractionStatuses.Extracted;
	EndIf;
		
	If (ThisIsWebClient = True) And (Version.Size = 0) Then
		FileBinaryData	= Version.FileStorage.Get();
		Version.Size 	= FileBinaryData.Size();
	EndIf;

	Version.Write();
	
	Return Version.Ref;
EndFunction // CreateFileVersion()

// Adds version link to the File dossier
Procedure UpdateFileCurrentVersion(FileRef, Version, Val TextTemporaryStorageAddress,
	UUID = Undefined) Export
	
	FileObject = FileRef.GetObject();
	LockDataForEdit(FileObject.Ref, , UUID);
	
	FileObject.CurrentVersion = Version.Ref;
	
	If TypeOf(TextTemporaryStorageAddress) = Type("ValueStorage") Then
		// When creating file from template -  value storage is being copied directly
		FileObject.TextStorage = TextTemporaryStorageAddress;
	Else
		Text = GetStringFromTemporaryStorage(TextTemporaryStorageAddress);
		FileObject.TextStorage = New ValueStorage(Text);
	EndIf;
	
	FileObject.Write();
	UnlockDataForEdit(FileObject.Ref, UUID);
	
EndProcedure // UpdateFileCurrentVersion()

// Updates text portion from file in file catalog
Procedure UpdateTextInFile(FileRef, Val TextTemporaryStorageAddress, UUID = Undefined)
	
	FileObject = FileRef.GetObject();
	LockDataForEdit(FileObject.Ref, , UUID);
	
	Text = GetStringFromTemporaryStorage(TextTemporaryStorageAddress);
	FileObject.TextStorage = New ValueStorage(Text);
	
	FileObject.Write();
	UnlockDataForEdit(FileObject.Ref, UUID);
	
EndProcedure // UpdateTextInFile()

// Update or create File version and return ref to updated version
Function UpdateVersion(File, 
					   CreateVersion, 
					   FileTemporaryStorageAddress,
					   Comment, 
					   ModificationTime, 
					   ModificationDateUniversal,
					   Size, 
					   BaseName, 
					   Extension, 
					   FullFilePath,
					   TextTemporaryStorageAddress,
					   ThisIsWebClient,
					   TextNotExtractedAtClient,
					   UUID 				= Undefined,
					   Encrypted 			= Undefined,
					   VersionRef 			= Undefined,
					   TextExtractionStatus = Undefined) 
	
	Var VolumeRef;
	
	SetPrivilegedMode(True);
	
	ProhibitFileLoadByExtension = GetProhibitFileLoadByExtension();
	ProhibitedExtensionsList = GetProhibitedExtensionsList();
	FileExtension = Extension;
	If Not FileOperationsClientServer.FileExtensionAllowedForLoad(ProhibitFileLoadByExtension, ProhibitedExtensionsList, FileExtension) Then
		Raise
			   StringFunctionsClientServer.SubstitureParametersInString(
				 NStr("en = 'Downloading files with %1 extension prohibited. Contact system administrator.'"),
				 FileExtension);
	EndIf;	
	
	FormerStorageType 	= Undefined;
	VersionLocked 		= False;
	Version 			= Undefined;

	If CreateVersion Then
		Version 				= Catalogs.FileVersions.CreateItem();
		Version.ParentalVersion = File.CurrentVersion;
		Version.VersionNo 		= FindMaximumVersionNumber(File) + 1;
	Else	
		
		If VersionRef = Undefined Then
			Version = File.CurrentVersion.GetObject();
		Else
			Version = VersionRef.GetObject();
		EndIf;
	
		LockDataForEdit(Version.Ref, , UUID);
		VersionLocked = True;
		
		// deleting file from disk by replacing it with new one
		If Version.FileStorageType = Enums.FileStorageTypes.VolumesOnHardDisk Then
			If Not Version.Volume.IsEmpty() Then
				FullPath = VolumeFullPath(Version.Volume) + Version.FilePath; 
				Try
					FileOnDisk = New File(FullPath);
					FileOnDisk.SetReadOnly(False);
					DeleteFiles(FullPath);
					
					PathWithSubdirectory = File.Path;
					FilesArrayInDirectory = FindFiles(PathWithSubdirectory, "*.*");
					If FilesArrayInDirectory.Count() = 0 Then
						DeleteFiles(PathWithSubdirectory);
					EndIf;
				Except
				EndTry;
			EndIf;
		EndIf;
		
	EndIf;
	
	Version.Owner 					= File.Ref;
	Version.Author 					= CommonUse.CurrentUser();
	Version.ModificationDateUniversal 	= ModificationDateUniversal;
	Version.CreationDate 			= CurrentDate();
	Version.Size 					= Size;
	Version.FileName 				= BaseName;
	Version.Comment 				= Comment;
	
	Version.Extension 				= RemoveDotFromExtension(Extension);
	
	FileStorageType 				= Constants.FileStorageType.Get();
	Version.FileStorageType			= FileStorageType;
	
	If FileStorageType = Enums.FileStorageTypes.Infobase Then
		
		Version.FileStorage = New ValueStorage(
			GetFromTempStorage(FileTemporaryStorageAddress));
			
		If (ThisIsWebClient = True) And (Version.Size = 0) Then
			FileBinaryData = Version.FileStorage.Get();
			Version.Size = FileBinaryData.Size();
			
			MaxFileSize = GetMaximumFileSize();
			SizeInMB = Version.Size / (1024 * 1024);
			MaxSizeInMB = MaxFileSize / (1024 * 1024);
			
			If Version.Size > MaxFileSize Then
				Raise StringFunctionsClientServer.SubstitureParametersInString(
					NStr("en = 'Size of %1 file (%2 MB) exceeds the maximum allowed file size (%3MB).'"),
					BaseName, 
					?(SizeInMB >= 1, Format(SizeInMB, "NFD=0"), Format(SizeInMB, "NFD=1; NZ=0")), 
					?(MaxSizeInMB >= 1, Format(MaxSizeInMB, "NFD=0"), Format(MaxSizeInMB, "NFD=1; NZ=0")));
			EndIf;
			
		EndIf;
			
		// clear fields
		Version.FilePath = "";
		Version.Volume = Catalogs.FileStorageVolumes.EmptyRef();
	Else // storing on disk
		
		BinaryData = GetFromTempStorage(FileTemporaryStorageAddress);
		
		If (ThisIsWebClient = True) And (Version.Size = 0) Then
			Version.Size = BinaryData.Size();
			
			MaxFileSize = GetMaximumFileSize();
			SizeInMB = Version.Size / (1024 * 1024);
			MaxSizeInMB = MaxFileSize / (1024 * 1024);
			
			If Version.Size > MaxFileSize Then
				Raise StringFunctionsClientServer.SubstitureParametersInString(
					NStr("en = 'Size of %1 file (%2 MB) exceeds the maximum allowed file size (%3MB).'"),
					BaseName, 
					?(SizeInMB >= 1, Format(SizeInMB, "NFD=0"), Format(SizeInMB, "NFD=1; NZ=0")), 
					?(MaxSizeInMB >= 1, Format(MaxSizeInMB, "NFD=0"), Format(MaxSizeInMB, "NFD=1; NZ=0")));
			EndIf;
			
		EndIf;
		
		FilePath = "";
		
		// add to one of the volumes (where is enough of space)
		AddToDisk(BinaryData, FilePath, VolumeRef, ModificationTime, Version.VersionNo, BaseName, Version.Extension, Version.Size);
		Version.FilePath 	= FilePath;
		Version.Volume 		= VolumeRef.Ref;
		Version.FileStorage = New ValueStorage(""); // clear ValueStorage
	EndIf; // storing on disk
	
	If Not TextNotExtractedAtClient Then		
		ExtractFileTextsAtServer = Constants.ExtractFileTextsAtServer.Get();
		If ExtractFileTextsAtServer = False Then
			Text = GetStringFromTemporaryStorage(TextTemporaryStorageAddress);
			Version.TextStorage = New ValueStorage(Text);
		Else
			Version.TextExtractionStatus = Enums.FileTextExtractionStatuses.NotExtracted;
		EndIf;
	Else		
		Version.TextExtractionStatus = Enums.FileTextExtractionStatuses.NotExtracted;
	EndIf;
	
	If TextExtractionStatus <> Undefined Then
		Version.TextExtractionStatus = TextExtractionStatus;
	EndIf;	

	If (ThisIsWebClient = True) And (Version.Size = 0) Then
		FileBinaryData = Version.FileStorage.Get();
		Version.Size = FileBinaryData.Size();
	EndIf;
	
	If Encrypted <> Undefined Then
		Version.Encrypted = Encrypted;
	EndIf;	
	
	Version.Write();
	
	If VersionLocked Then
		UnlockDataForEdit(Version.Ref, UUID);		
	EndIf;
	
	FileURL = GetURL(File);
	UserWorkHistory.Add(FileURL);
	
	Return Version.Ref;
	
EndFunction // UpdateVersion

// Updates or creates File version and releases it
Procedure SaveAndUnlockFile(
	FileData, 
	CreateVersion, 
	FileTemporaryStorageAddress, 
	Comment, 
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
	UUID = Undefined) Export
	
	FileDataCurrent = GetFileData(FileData.Ref);
	If Not FileDataCurrent.LockedByCurrentUser Then
		Raise NStr("en = 'File is not in use by the current user'");
	EndIf;	
	
	BeginTransaction();
	Try
	
		PreviousVersion 	= FileData.CurrentVersion;
		NewVersion 			= UpdateVersion(
			FileData.Ref, 
			CreateVersion, 
			FileTemporaryStorageAddress, 
			Comment, 
			ModificationTime, 
			ModificationDateUniversal,
			Size, 
			BaseName, 
			Extension, 
			FullFilePath,
			TextTemporaryStorageAddress,
			ThisIsWebClient,
			TextNotExtractedAtClient,
			UUID);

		If CreateVersion Then
			UpdateFileCurrentVersion(FileData.Ref, NewVersion, TextTemporaryStorageAddress, UUID);
		Else
			UpdateTextInFile(FileData.Ref, TextTemporaryStorageAddress, UUID);
		EndIf;
		FileData.CurrentVersion = NewVersion;
		
		UnlockFile(FileData, UUID);
		
		If Not ThisIsWebClient And Not DoNotChangeRecordInWorkingDirectory Then
			DirectoryPath = CommonUse.CommonSettingsStorageLoad("LocalFilesCache", "LocalFilesCachePath");
			DeleteVersionAndAddFilesInWorkingDirectoryRegisterRecord(
				PreviousVersion, 
				NewVersion, 
				FullFilePath, 
				DirectoryPath,
				FileData.OwnerWorkingDirectory <> "");
		EndIf;
		
		CommitTransaction();
	Except
	    RollbackTransaction();
	    Raise;
	EndTry;

EndProcedure // SaveAndUnlockFile()

// Gets file data, after updates or creates File version and releases the file
// Need it in case, when there is no FileData( to minimize client-server calls) at client
Procedure GetFileDataSaveAndUnlockFile(ObjectRef, 
									   FileData,
									   CreateVersion, 
									   FileTemporaryStorageAddress, 
									   Comment, 
									   ModificationTime, 
									   ModificationDateUniversal,
									   Size, 
									   BaseName, 
									   Extension, 
									   FullFilePath,
									   TextTemporaryStorageAddress,
									   ThisIsWebClient,
									   TextNotExtractedAtClient,
									   UUID = Undefined) Export

	FileData = GetFileData(ObjectRef);
	
	If Not FileData.LockedByCurrentUser Then
		Raise NStr("en = 'File is not in use by the current user'");
	EndIf;	
	
	BeginTransaction();
	Try
	
		PreviousVersion = FileData.CurrentVersion;
		NewVersion = UpdateVersion(
			FileData.Ref, 
			CreateVersion, 
			FileTemporaryStorageAddress, 
			Comment, 
			ModificationTime, 
			ModificationDateUniversal,
			Size, 
			BaseName, 
			Extension, 
			FullFilePath,
			TextTemporaryStorageAddress,
			ThisIsWebClient,
			TextNotExtractedAtClient,
			UUID);

		If CreateVersion Then
			UpdateFileCurrentVersion(FileData.Ref, NewVersion, TextTemporaryStorageAddress, UUID);
		Else
			UpdateTextInFile(FileData.Ref, TextTemporaryStorageAddress, UUID);
		EndIf;
		FileData.CurrentVersion = NewVersion;
		
		UnlockFile(FileData, UUID);
		
		If NOT ThisIsWebClient Then
			DirectoryPath = CommonUse.CommonSettingsStorageLoad("LocalFilesCache", "LocalFilesCachePath");
			DeleteVersionAndAddFilesInWorkingDirectoryRegisterRecord(
				PreviousVersion, 
				NewVersion, 
				FullFilePath, 
				DirectoryPath,
				FileData.OwnerWorkingDirectory <> "");
		EndIf;
		
		CommitTransaction();
	Except
	    RollbackTransaction();
	    Raise;
	EndTry;
	
EndProcedure // GetFileDataSaveAndUnlockFile()

// Procedure publishes file without releasing it
Procedure SaveFile(File, 
				   CreateVersion, 
				   FileTemporaryStorageAddress, 
				   Comment, 
				   ModificationTime,
				   ModificationDateUniversal,
				   Size, 
				   BaseName, 
				   Extension, 
				   RelativeFilePath, 
				   FullFilePath,
				   TextTemporaryStorageAddress,
				   ThisIsWebClient,
				   TextNotExtractedAtClient,
				   InOwnerWorkingDirectory,
				   DoNotChangeRecordInWorkingDirectory,
				   UUID = Undefined) Export
	
	FileDataCurrent = GetFileData(File);
	If Not FileDataCurrent.LockedByCurrentUser Then
		Raise NStr("en = 'File is not in use by the current user'");
	EndIf;	
	
	BeginTransaction();
	Try
	
		OldVersion = File.CurrentVersion;
		
		Version = UpdateVersion(
			File, 
			CreateVersion, 
			FileTemporaryStorageAddress, 
			Comment, 
			ModificationTime, 
			ModificationDateUniversal,
			Size, 
			BaseName, 
			Extension, 
			FullFilePath,
			TextTemporaryStorageAddress,
			ThisIsWebClient,
			TextNotExtractedAtClient,
			UUID);

		If CreateVersion Then
			UpdateFileCurrentVersion(File, Version, TextTemporaryStorageAddress, UUID);
		Else
			UpdateTextInFile(File, TextTemporaryStorageAddress, UUID);
		EndIf;
		
		If Not ThisIsWebClient And Not DoNotChangeRecordInWorkingDirectory Then
			DeleteFromRegister(OldVersion);
			ForRead = False; 
			WriteFileNameWithPathToRegister(Version, RelativeFilePath, ForRead, InOwnerWorkingDirectory);
		EndIf;
		
		CommitTransaction();
	Except
	    RollbackTransaction();
	    Raise;
	EndTry;
	
EndProcedure // SaveFile()

// gets LockedByCurrentUser - in priviledged mode
Function IsLockedByCurrentUser(VersionRef) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	
	Query.Text = "SELECT
	             |	Files.LockedBy AS LockedBy
	             |FROM
	             |	Catalog.Files AS Files
	             |		INNER JOIN Catalog.FileVersions AS FileVersions
	             |		ON (TRUE)
	             |WHERE
	             |	FileVersions.Ref = &Version
	             |	AND Files.Ref = FileVersions.Owner";
				   
	Query.Parameters.Insert("Version", VersionRef);
	
	Selection = Query.Execute().Choose();
	While Selection.Next() Do
		LockedByCurrentUser = (Selection.LockedBy = CommonUse.CurrentUser());
		Return LockedByCurrentUser;
	EndDo;
	
	Return False;
EndFunction	

// Function returns structure, containig different info about File and version
Function GetFileData(FileRef, VersionRef = Undefined) Export
	
	Query = New Query;

	If VersionRef = Catalogs.FileVersions.EmptyRef() Then
		VersionRef = Undefined;
	EndIf;
	
	If VersionRef = Undefined Then
		
		Query.Text = "SELECT
		             |	Files.Ref AS Ref,
		             |	Files.Code AS Code,
		             |	Files.LockedBy AS LockedBy,
		             |	Files.CurrentVersion AS CurrentVersion,
		             |	Files.FileOwner AS FileOwner,
		             |	Files.StoreVersions AS StoreVersions,
		             |	Files.DeletionMark AS DeletionMark,
		             |	FileVersions.FileName AS Details,
		             |	FileVersions.Extension AS Extension,
		             |	FileVersions.Size AS Size,
		             |	FileVersions.VersionNo AS VersionNo,
		             |	FileVersions.FilePath AS FilePath,
		             |	FileVersions.Volume AS Volume,
		             |	FileVersions.ModificationDateUniversal AS ModificationDateUniversal,
		             |	FileVersions.Author AS Author,
		             |	FileVersions.TextExtractionStatus AS TextExtractionStatus,
		             |	Files.Encrypted AS Encrypted
		             |FROM
		             |	Catalog.Files AS Files
		             |		LEFT JOIN Catalog.FileVersions AS FileVersions
		             |		ON Files.CurrentVersion = FileVersions.Ref";
		
		If TypeOf(FileRef) = Type("Array") Then 
			Query.Text = Query.Text + " WHERE Files.Ref In (&File) ";
		Else
			Query.Text = Query.Text + " WHERE Files.Ref = &File ";
		EndIf;

		Query.Parameters.Insert("File", FileRef);
		
	Else
		
		If FileRef <> Undefined Then 
			Query.Text = "SELECT
			             |	Files.Ref AS Ref,
			             |	Files.Code AS Code,
			             |	Files.LockedBy AS LockedBy,
			             |	Files.CurrentVersion AS CurrentVersion,
			             |	Files.FileOwner AS FileOwner,
			             |	Files.StoreVersions AS StoreVersions,
			             |	Files.DeletionMark AS DeletionMark,
			             |	FileVersions.FileName AS Details,
			             |	FileVersions.Extension AS Extension,
			             |	FileVersions.Size AS Size,
			             |	FileVersions.VersionNo AS VersionNo,
			             |	FileVersions.FilePath AS FilePath,
			             |	FileVersions.Volume AS Volume,
			             |	FileVersions.ModificationDateUniversal AS ModificationDateUniversal,
			             |	FileVersions.Author AS Author,
			             |	FileVersions.TextExtractionStatus AS TextExtractionStatus,
			             |	Files.Encrypted AS Encrypted
			             |FROM
			             |	Catalog.Files AS Files
			             |		INNER JOIN Catalog.FileVersions AS FileVersions
			             |		ON (TRUE)
			             |WHERE
			             |	Files.Ref = &File
			             |	AND FileVersions.Ref = &Version";
						   
			Query.Parameters.Insert("File", FileRef);
			Query.Parameters.Insert("Version", VersionRef);
		Else
			Query.Text = "SELECT
			             |	Files.Ref AS Ref,
			             |	Files.Code AS Code,
			             |	Files.LockedBy AS LockedBy,
			             |	Files.CurrentVersion AS CurrentVersion,
			             |	Files.FileOwner AS FileOwner,
			             |	Files.StoreVersions AS StoreVersions,
			             |	Files.DeletionMark AS DeletionMark,
			             |	FileVersions.FileName AS Details,
			             |	FileVersions.Extension AS Extension,
			             |	FileVersions.Size AS Size,
			             |	FileVersions.VersionNo AS VersionNo,
			             |	FileVersions.FilePath AS FilePath,
			             |	FileVersions.Volume AS Volume,
			             |	FileVersions.ModificationDateUniversal AS ModificationDateUniversal,
			             |	FileVersions.Author AS Author,
			             |	FileVersions.TextExtractionStatus AS TextExtractionStatus,
			             |	Files.Encrypted AS Encrypted
			             |FROM
			             |	Catalog.Files AS Files
			             |		INNER JOIN Catalog.FileVersions AS FileVersions
			             |		ON (TRUE)
			             |WHERE
			             |	FileVersions.Ref = &Version
			             |	AND Files.Ref = FileVersions.Owner";
						   
			Query.Parameters.Insert("Version", VersionRef);
		EndIf;	
		
	EndIf;	
	
	FileDataArray = New Array;
	
	Selection = Query.Execute().Choose();
	While Selection.Next() Do
	
		FileData = New Structure;
		FileData.Insert("Ref", 		Selection.Ref);
		FileData.Insert("FileCode", Selection.Code);
		FileData.Insert("LockedBy", Selection.LockedBy);
		FileData.Insert("Owner", 	Selection.FileOwner);
		FileData.Insert("URL", 		GetURL(Selection.Ref));
		
		If VersionRef <> Undefined Then
			FileData.Insert("Version", VersionRef);
		Else
			FileData.Insert("Version", Selection.CurrentVersion);
		EndIf;	

		FileData.Insert("CurrentVersion", 		 Selection.CurrentVersion);
		FileData.Insert("CurrentVersionURL",   GetURL(FileData.CurrentVersion, "FileStorage"));
		
		FileData.Insert("Size", 				 Selection.Size);
		FileData.Insert("VersionNo", 			 Selection.VersionNo);
		FileData.Insert("ModificationDateUniversal", Selection.ModificationDateUniversal);
		FileData.Insert("Extension", 			 Selection.Extension);
		FileData.Insert("VersionDetails", 	     TrimAll(Selection.Details));
		FileData.Insert("StoreVersions", 		 Selection.StoreVersions);
		FileData.Insert("DeletionMark", 		 Selection.DeletionMark);
		FileData.Insert("CurrentVersionAuthor",  Selection.Author);
		FileData.Insert("Encrypted", 			 Selection.Encrypted);
		
		If FileData.Encrypted Then
			EncryptionCertificatesArray = GetEncryptionCertificatesArray(FileData.Ref);
			FileData.Insert("EncryptionCertificatesArray", EncryptionCertificatesArray);
		EndIf;	
		
		ForRead = FileData.LockedBy <> CommonUse.CurrentUser();
		FileData.Insert("ForRead", ForRead);
		
		ReadonlyInWorkingDirectory = True;
		InOwnerWorkingDirectory = False;
		DirectoryPath = CommonUse.CommonSettingsStorageLoad("LocalFilesCache", "LocalFilesCachePath");
		If DirectoryPath = Undefined Then
			DirectoryPath = "";
		EndIf;	

		If VersionRef <> Undefined Then
			FileNameWithPathInWorkingDirectory = GetFileNameWithPathFromRegister(VersionRef, DirectoryPath, ReadonlyInWorkingDirectory, InOwnerWorkingDirectory);
		Else
			FileNameWithPathInWorkingDirectory = GetFileNameWithPathFromRegister(Selection.CurrentVersion, DirectoryPath, ReadonlyInWorkingDirectory, InOwnerWorkingDirectory);
		EndIf;	

		FileData.Insert("FileNameWithPathInWorkingDirectory",	FileNameWithPathInWorkingDirectory);
		FileData.Insert("ReadonlyInWorkingDirectory", 			ReadonlyInWorkingDirectory);
		FileData.Insert("OwnerWorkingDirectory", "");
		
		LockedByCurrentUser = (FileData.LockedBy = CommonUse.CurrentUser());
		FileData.Insert("LockedByCurrentUser", LockedByCurrentUser);
		
		TextExtractionStatusString = "NotExtracted";
		If Selection.TextExtractionStatus = Enums.FileTextExtractionStatuses.NotExtracted Then
			TextExtractionStatusString = "NotExtracted";
		ElsIf Selection.TextExtractionStatus = Enums.FileTextExtractionStatuses.Extracted Then
			TextExtractionStatusString = "Extracted";
		ElsIf Selection.TextExtractionStatus = Enums.FileTextExtractionStatuses.ExtractFailed Then
			TextExtractionStatusString = "ExtractFailed";
		EndIf;	
		FileData.Insert("TextExtractionStatus", TextExtractionStatusString);
		
		FileDataArray.Add(FileData); 
		
	EndDo;
	
	// if array was passed - return array
	If TypeOf(FileRef) = Type("Array") Then 
		Return FileDataArray;
	EndIf;

	If FileDataArray.Count() > 0 Then 
		Return FileDataArray[0];
	Else
		Return New Structure;
	EndIf;
	
EndFunction

// Gets line from temporary storage (transfer from client to server
//is performed via temporary storage)
Function GetStringFromTemporaryStorage(TextTemporaryStorageAddress)
	If IsBlankString(TextTemporaryStorageAddress) Then
		Return "";
 	EndIf;

	TemporaryFileName = GetTempFileName();
	GetFromTempStorage(TextTemporaryStorageAddress).Write(TemporaryFileName);

	TextFile = New TextReader(TemporaryFileName, TextEncoding.Utf8);
	Text = TextFile.Read();
	TextFile.Close();
	DeleteFiles(TemporaryFileName);
	Return Text;
EndFunction

// Creates File dossier in DB together with version
Function CreateFileWithVersion(FileOwner,
							   BaseName,
							   ExtensionWithoutDot,
							   ModificationTime,
							   ModificationDateUniversal,
							   Size,
							   FileTemporaryStorageAddress,
							   TextTemporaryStorageAddress,
							   ThisIsWebClient,
							   User    = Undefined,
							   Comment = "") Export

	BeginTransaction();
	Try

		// Create Files catalog item in infobase
		Doc = CreateFile(
			FileOwner,
			Comment,
			BaseName,
			ExtensionWithoutDot,
			True,
			TextTemporaryStorageAddress,
			User);
		
		// Create version of the file being saved in Files catalog item
		Version = CreateFileVersion(
			ModificationTime,
			ModificationDateUniversal,
			Doc,
			BaseName,
			Size,
			ExtensionWithoutDot,
			FileTemporaryStorageAddress,
			TextTemporaryStorageAddress,
			ThisIsWebClient,
			Undefined, // RefToVersionSource
			Undefined, // NewVersionCreationDate
			User);

		// Insert reference to the version to Files catalog item
		UpdateFileCurrentVersion(Doc, Version, TextTemporaryStorageAddress);

		CommitTransaction();
	Except
	    RollbackTransaction();
	    Raise;
	EndTry;

	Return Doc;
EndFunction

// Gets file data and locks it(checkout) - to minimize calls
//client server placed GetFileData and LockFile into one function
Function GetFileDataAndLockFile(FileRef, FileData, ErrorString, UUID = Undefined) Export

	FileData = GetFileData(FileRef);

	ErrorString = "";
	If Not FileOperationsClientServer.CanLockFile(FileData, ErrorString) Then
		Return False;
	EndIf;	
	
	If FileData.LockedBy.IsEmpty() Then
		
		ErrorString = "";
		If Not LockFile(FileData, ErrorString, UUID) Then 
			Return False;
		EndIf;
	EndIf;
	
	Return True;
EndFunction // GetFileDataAndLockFile()


// gets FileData and locks files from array. On error continue operation
//  and returns only successfully locked files into ArrayFileData
Procedure GetDataAndLockFilesArray(ArrayOfMarkedSubordinate, ArrayFileData, UUID = Undefined) Export
	
	For Each StructureOfSubordinate In ArrayOfMarkedSubordinate Do
		FileData = GetFileData(StructureOfSubordinate.SubordinateFile, Undefined);

		ErrorString = "";
		If FileOperationsClientServer.CanLockFile(FileData, ErrorString) Then
			
			If FileData.LockedBy.IsEmpty() Then
				If LockFile(FileData, ErrorString, UUID) Then 
					ArrayFileData.Add(FileData);
				EndIf;	
			EndIf;
			
		EndIf;	
	EndDo;
	
EndProcedure	

// gets FileData for subordinate files and places into ArrayFileData
Procedure GetDataOfFilesArray(ArrayOfMarkedSubordinate, ArrayFileData) Export
	
	For Each StructureOfSubordinate In ArrayOfMarkedSubordinate Do
		FileData = GetFileData(StructureOfSubordinate.SubordinateFile, Undefined);
		ArrayFileData.Add(FileData);
	EndDo;
	
EndProcedure

// gets FileData for the files and places into ArrayFileData
Procedure GetDataForFilesArray(Val FilesArray, ArrayFileData) Export
	
	For Each File In FilesArray Do
		FileData = GetFileData(File, Undefined);
		ArrayFileData.Add(FileData);
	EndDo;
	
EndProcedure	


// Gets file data for opening and locks it(checkout) - for minimizing calls
//client server placed GetFileDataForOpening and LockFile in one function
Function GetFileDataForOpeningAndLockFile(FileRef, FileData, ErrorString, 
	UUID = Undefined, OwnerWorkingDirectory = Undefined) Export

	FileData = GetFileDataForOpening(FileRef, Undefined, UUID, OwnerWorkingDirectory);

	ErrorString = "";
	If Not FileOperationsClientServer.CanLockFile(FileData, ErrorString) Then
		Return False;
	EndIf;	
	
	If FileData.LockedBy.IsEmpty() Then
		
		ErrorString = "";
		If Not LockFile(FileData, ErrorString, UUID) Then 
			Return False;
		EndIf;	
	EndIf;
	
	Return True;
EndFunction // GetFileDataAndLockFile()

// executes PutToTempStorage (if file is stored on disk) and returns required ref
Function GetURLForOpening(VersionRef, FormID = Undefined) Export
	Address = "";
	
	FileStorageType = VersionRef.FileStorageType;
	
	If FileStorageType = Enums.FileStorageTypes.VolumesOnHardDisk Then
		If Not VersionRef.Volume.IsEmpty() Then
			FullPath = VolumeFullPath(VersionRef.Volume) + VersionRef.FilePath; 
			Try
				BinaryData = New BinaryData(FullPath);
				Address = PutToTempStorage(BinaryData, FormID);
			Except
				// record to eventlog
				ErrorMessage = GenerateFileFromVolumeObtainingErrorTextForAdministrator(ErrorInfo(), VersionRef.Owner);
				WriteLogEvent("File opening", EventLogLevel.Error, Metadata.Catalogs.Files, VersionRef.Owner, ErrorMessage);
				
				Raise StringFunctionsClientServer.SubstitureParametersInString(
					NStr("en = 'File opening error: file not found at server. File might have been deleted by an antivirus software. Contact system administrator. 
                          |File: %1.%2'"),
					VersionRef.Details,
					VersionRef.Extension);
			EndTry;
		EndIf;
	Else
		Address = GetURL(VersionRef, "FileStorage");
	EndIf;
	
	Return Address;
EndFunction // GetURLForOpening()

// Returns name with extesion - if extension is empty - just name
Function GetNameWithExtention(Details, Extension) 
	NameWithExtention = Details;
	
	If Extension <> "" Then
		NameWithExtention = NameWithExtention + "." + Extension;
	EndIf;
	
	Return NameWithExtention;
EndFunction

// execute GetFileData and calculate OwnerWorkingDirectory
Function GetFileDataAndWorkingDirectory(FileRef, VersionRef = Undefined, 
	OwnerWorkingDirectory = Undefined) Export
	
	FileData = GetFileData(FileRef, VersionRef);
	
	If OwnerWorkingDirectory = Undefined Then
		OwnerWorkingDirectory = GetWorkingDirectory(FileData.Owner);
	EndIf;
	FileData.Insert("OwnerWorkingDirectory", OwnerWorkingDirectory);
	
	If FileData.OwnerWorkingDirectory <> "" Then
		
		FileNameWithPathInWorkingDirectory = "";
		DirectoryPath = ""; // path to local cache is not used here
		ReadonlyInWorkingDirectory = True; // is not used
		InOwnerWorkingDirectory = True;
		
		If VersionRef <> Undefined Then
			FileNameWithPathInWorkingDirectory = GetFileNameWithPathFromRegister(VersionRef, DirectoryPath, ReadonlyInWorkingDirectory, InOwnerWorkingDirectory);
		Else
			FileNameWithPathInWorkingDirectory = GetFileNameWithPathFromRegister(FileRef.CurrentVersion, DirectoryPath, ReadonlyInWorkingDirectory, InOwnerWorkingDirectory);
		EndIf;	
		
		FileData.Insert("FileNameWithPathInWorkingDirectory", FileNameWithPathInWorkingDirectory);
	EndIf;
	
	Return FileData;
EndFunction // GetFileDataAndWorkingDirectory()


// execute GetFileData and calculate number of file versions
Function GetFileDataAndVersionsCount(FileRef) Export
	
	FileData = GetFileData(FileRef);
	VersionsCount = GetVersionsCount(FileRef);
	FileData.Insert("VersionsCount", VersionsCount);
	Return FileData;
EndFunction // GetFileDataAndWorkingDirectory()

// Generates error text for writing into eventlog
Function GenerateFileFromVolumeObtainingErrorTextForAdministrator(ErrorInfoOfFunction, FileRef) Export
	ErrorMessage = DetailErrorDescription(ErrorInfoOfFunction);
	ErrorMessage = ErrorMessage + Chars.LF + NStr("en = 'File reference: '");
	If FileRef <> Undefined Then
		ErrorMessage = ErrorMessage + GetURL(FileRef);
	EndIf;
	Return ErrorMessage;
EndFunction // GetFileDataAndWorkingDirectory()

// execute GetFileData + PutToTempStorage (if file is stored on disk)
Function GetFileDataForOpening(FileRef, VersionRef = Undefined, 
	FormID = Undefined, OwnerWorkingDirectory = Undefined) Export
	
	FileData = GetFileData(FileRef, VersionRef);
	
	If OwnerWorkingDirectory = Undefined Then
		OwnerWorkingDirectory = GetWorkingDirectory(FileData.Owner);
	EndIf;
	FileData.Insert("OwnerWorkingDirectory", OwnerWorkingDirectory);
	
	If FileData.OwnerWorkingDirectory <> "" Then
		FileName = GetNameWithExtention(FileData.VersionDetails, FileData.Extension);
		FileNameWithPathInWorkingDirectory = OwnerWorkingDirectory + FileName;
		FileData.Insert("FileNameWithPathInWorkingDirectory", FileNameWithPathInWorkingDirectory);
	EndIf;
	
	FileStorageType = FileData.Version.FileStorageType;
	
	If FileStorageType = Enums.FileStorageTypes.VolumesOnHardDisk And FileData.Version <> Undefined Then
		
		SetPrivilegedMode(True);
		
		Query = New Query;
		
		Query.Text = "SELECT
		             |	FileVersions.FilePath AS FilePath,
		             |	FileVersions.Volume AS Volume
		             |FROM
		             |	Catalog.FileVersions AS FileVersions
		             |WHERE
		             |	FileVersions.Ref = &Version";
					   
		Query.Parameters.Insert("Version", FileData.Version);
		
		FileDataVolume   = Catalogs.FileStorageVolumes.EmptyRef();
		FileDataFilePath = ""; 
		
		Selection = Query.Execute().Choose();
		If Selection.Next() Then
			FileDataVolume   = Selection.Volume;
			FileDataFilePath = Selection.FilePath;
		EndIf;
		
		If Not FileDataVolume.IsEmpty() Then
			FullPath = VolumeFullPath(FileDataVolume) + FileDataFilePath; 
			Try
				BinaryData = New BinaryData(FullPath);
				// work only with only with current version - for not-current version get ref in GetURLForOpening
				FileData.CurrentVersionURL = PutToTempStorage(BinaryData, FormID);
			Except
				// record to eventlog
				ErrorMessage = GenerateFileFromVolumeObtainingErrorTextForAdministrator(ErrorInfo(), FileRef);
				WriteLogEvent("File opening", EventLogLevel.Error, Metadata.Catalogs.Files, FileRef, ErrorMessage);
				
				Raise StringFunctionsClientServer.SubstitureParametersInString(
					NStr("en = 'File opening error: file not found on server. File might have been deleted by antivirus software. Contact system administrator.
                          |File: ""%1.%2""'"),
					FileData.VersionDetails,
					FileData.Extension);
			EndTry;
		EndIf;
	EndIf;
	
	Return FileData;
EndFunction // GetFileDataForOpening()


// Release the File with obtaining the data
Procedure GetFileDataAndUnlockFile(FileRef, FileData, UUID = Undefined) Export
	
	FileData = GetFileData(
		FileRef);
		
	UnlockFile(FileData, UUID);	
EndProcedure	

// gets FileData and releases files array. Continue operation on error,
//  only successfully released files are returned into ArrayFileData
Procedure GetDataAndUnlockFilesArray(ArrayOfMarkedSubordinate, ArrayFileData, UUID = Undefined) Export
	
	For Each StructureOfSubordinate In ArrayOfMarkedSubordinate Do
		
		FileData = GetFileData(StructureOfSubordinate.SubordinateFile, Undefined);

		If Not FileData.LockedBy.IsEmpty() Then
			UnlockFile(FileData, UUID);	
			ArrayFileData.Add(FileData);
		EndIf;
		
	EndDo;
	
EndProcedure	


// Procedure publishes file without releasing it
Procedure GetFileDataAndSaveFile(File, 
								 FileData,
								 CreateVersion, 
								 FileTemporaryStorageAddress, 
								 Comment, 
								 ModificationTime, 
								 ModificationDateUniversal,
								 Size, 
								 BaseName, 
								 Extension, 
								 RelativeFilePath, 
								 FullFilePath,
								 TextTemporaryStorageAddress,
								 ThisIsWebClient,
								 TextNotExtractedAtClient,
								 InOwnerWorkingDirectory,
								 UUID = Undefined) Export

	FileData = GetFileData(File);
		
	If Not FileData.LockedByCurrentUser Then
		Raise NStr("en = 'File is not locked by the current user'");
	EndIf;	
		
	DoNotChangeRecordInWorkingDirectory = False;

	SaveFile(
		File, 
		CreateVersion,
		FileTemporaryStorageAddress,
		Comment,
		ModificationTime,
		ModificationDateUniversal,
		Size,
		BaseName,
		Extension,
		RelativeFilePath,
		FullFilePath,
		TextTemporaryStorageAddress,
		ThisIsWebClient,
		TextNotExtractedAtClient,
		InOwnerWorkingDirectory,
		DoNotChangeRecordInWorkingDirectory,
		UUID);
EndProcedure	

// Gets synthetic working directory of the folder on disk (it can derive from parent folder)
Function GetWorkingDirectory(RefFolders) Export
	If TypeOf(RefFolders) <> Type("CatalogRef.FileFolders") Then
		Return "";
	EndIf;	
	
	SetPrivilegedMode(True);
	
	WorkingDirectory = "";
	
	// Prepare dimensions filter structure
	FilterStructure = New Structure;
	FilterStructure.Insert("Folder", RefFolders);
	FilterStructure.Insert("User", CommonUse.CurrentUser());
	   
	// Get structure with the record resources data
	ResourcesStructure = InformationRegisters.WorkingFileFolders.Get(FilterStructure);
	   
	// Get path from register
	WorkingDirectory = ResourcesStructure.Path;
	
	If Not IsBlankString(WorkingDirectory) Then
		FileFunctionsClientServer.AddLastPathSeparatorIfMissing(WorkingDirectory);
	EndIf;
	
	Return WorkingDirectory;
EndFunction	

// Saves folder working directory in information register
Procedure SaveWorkingDirectory(RefFolders, OwnerWorkingDirectory) Export
	SetPrivilegedMode(True);
	
	RecordSet = InformationRegisters.WorkingFileFolders.CreateRecordSet();
	
	RecordSet.Filter.Folder.Set(RefFolders);
	RecordSet.Filter.User.Set(CommonUse.CurrentUser());

	NewRecord 		 = RecordSet.Add();
	NewRecord.Folder = RefFolders;
	NewRecord.User 	 = CommonUse.CurrentUser();
	NewRecord.Path 	 = OwnerWorkingDirectory;

	RecordSet.Write();
EndProcedure


// Clears folder working directory in information register
Procedure ClearWorkingDirectory(RefFolders) Export
	SetPrivilegedMode(True);
	
	RecordSet = InformationRegisters.WorkingFileFolders.CreateRecordSet();
	
	RecordSet.Filter.Folder.Set(RefFolders);
	RecordSet.Filter.User.Set(CommonUse.CurrentUser());
	
	// adding no records to the set to delete all records
	RecordSet.Write();
	
	
	// clear working directories for child folders
	Query = New Query;
	Query.Text = 
		"SELECT
		|	FileFolders.Ref AS Ref
		|FROM
		|	Catalog.FileFolders AS FileFolders
		|WHERE
		|	FileFolders.Parent = &Ref";
	
	Query.SetParameter("Ref", RefFolders);
	
	Result = Query.Execute();
	Selection = Result.Choose();
	While Selection.Next() Do
		ClearWorkingDirectory(Selection.Ref);
	EndDo;
	
EndProcedure

// Finds record in information register FilesInWorkingDirectory using file path (relative) on disk
Function FindInRegisterByPath(FileName, Version, PlacementDate, Owner, VersionNo, ReadOnly, FileCode, FileFolder) Export
	
	SetPrivilegedMode(True);
	
	Version = New ("CatalogRef.FileVersions");
	
	// For each file find record in information register by path - get field from there
	// Version and Size and WorkingDirectoryPlacementDate
	Query = New Query;
	Query.SetParameter("FileName", FileName);
	Query.SetParameter("User", CommonUse.CurrentUser());
	Query.Text = 
		"SELECT
       	|	FilesInWorkingDirectory.Version AS Version,
       	|	FilesInWorkingDirectory.WorkingDirectoryPlacementDate AS WorkingDirectoryPlacementDate,
       	|	FilesInWorkingDirectory.ForRead AS ForRead
       	|FROM
       	|	InformationRegister.FilesInWorkingDirectory AS FilesInWorkingDirectory
       	|WHERE
       	|	FilesInWorkingDirectory.Path = &FileName
       	|	AND FilesInWorkingDirectory.User = &User";
	
	QueryResult = Query.Execute(); 
	
	If Not QueryResult.IsEmpty() Then
		Selection = QueryResult.Choose();
		Selection.Next();
		
		Version 	  = Selection.Version;
		PlacementDate = Selection.WorkingDirectoryPlacementDate;
		
		Owner 		= Version.Owner;
		VersionNo 	= Version.VersionNo;
		ReadOnly 	= Selection.ForRead;
		FileCode 	= Version.Owner.Code;
		FileFolder	= Owner.FileOwner;
		Return True;
	EndIf;
	
	Return False;
EndFunction

// Returns current user ID from server to client
Function SessionParametersCurrentUserID() Export
	Return CommonUse.CurrentUser().UUID();
EndFunction

// Passes array of settings from client to server for write
//(array of structures with the fields Object Options Value)
// and session parameter UserWorkingDirectoryPath
Procedure CommonSettingsStorageSaveArrayAndSessionParameterWorkingDirectory(StructuresArray, LocalFilesCachePath) Export
	CommonUse.CommonSettingsStorageSaveArray(StructuresArray);
	SetSessionParameterUserWorkingDirectoryPath(LocalFilesCachePath);
EndProcedure

// Finds in information register FilesInWorkingDirectory info about FileVersion (path to version file in working dir, and status - for read or write)
Function GetFileNameWithPathFromRegister(Version, DirectoryPath, ReadonlyInWorkingDirectory, InOwnerWorkingDirectory) Export
	
	SetPrivilegedMode(True);
	
	FileNameWithPath = "";
	
	// Prepare dimensions filter structure
	FilterStructure = New Structure;
	FilterStructure.Insert("Version", Version.Ref);
	FilterStructure.Insert("User", CommonUse.CurrentUser());
	   
	// Get structure with the record resources data
	ResourcesStructure = InformationRegisters.FilesInWorkingDirectory.Get(FilterStructure);
	   
	// Get path from register
	FileNameWithPath 			= ResourcesStructure.Path;
	ReadonlyInWorkingDirectory 	= ResourcesStructure.ForRead;
	InOwnerWorkingDirectory 	= ResourcesStructure.InOwnerWorkingDirectory;
	If FileNameWithPath <> "" And InOwnerWorkingDirectory = False Then
		FileNameWithPath = DirectoryPath + FileNameWithPath;
	EndIf;
	
	Return FileNameWithPath;
EndFunction

// Finds in information register FilesInWorkingDirectory info about FileVersion (path to version file in working dir)
Function GetFileNameFromRegister(Ref) Export
	
	SetPrivilegedMode(True);
	
	FileNameWithPath = "";
	
	// Prepare dimensions filter structure
	FilterStructure = New Structure;
	FilterStructure.Insert("Version", Ref);
	FilterStructure.Insert("User", CommonUse.CurrentUser());
	   
	// Get structure with the record resources data
	ResourcesStructure = InformationRegisters.FilesInWorkingDirectory.Get(FilterStructure);
	   
	// Get path from register
	FileNameWithPath = ResourcesStructure.Path;
	
	Return FileNameWithPath;
EndFunction

Procedure WriteFileNameWithPathToRegister(CurrentVersion, FileNameWithPath, ForRead, InOwnerWorkingDirectory) Export
	
	SetPrivilegedMode(True);
	
	// Create recordset
	RecordSet = InformationRegisters.FilesInWorkingDirectory.CreateRecordSet();
	
	RecordSet.Filter.Version.Set(CurrentVersion.Ref);
	RecordSet.Filter.User.Set(CommonUse.CurrentUser());

	NewRecord = RecordSet.Add();
	NewRecord.Version 						= CurrentVersion.Ref;
	NewRecord.Path 							= FileNameWithPath;
	NewRecord.Size 							= CurrentVersion.Size;
	NewRecord.WorkingDirectoryPlacementDate = CurrentDate();
	NewRecord.User 							= CommonUse.CurrentUser();

	NewRecord.ForRead 					= ForRead;
	NewRecord.InOwnerWorkingDirectory 	= InOwnerWorkingDirectory;
	
	RecordSet.Write();
EndProcedure

Procedure DeleteFromRegister(Version) Export
	
	SetPrivilegedMode(True);
	
	RecordSet = InformationRegisters.FilesInWorkingDirectory.CreateRecordSet();
	
	RecordSet.Filter.Version.Set(Version);
	RecordSet.Filter.User.Set(CommonUse.CurrentUser());
	
	RecordSet.Write();
EndProcedure

Procedure DeleteUnusedRecordsFromFilesInWorkingDirectoryRegister() Export
	// Filter all in information register. Go over - find those, that are not locked by the current user -
	//  and delete all - consider, that they are already deleted from disk
	
	SetPrivilegedMode(True);
	
	ListDelete = New Array;
	CurrentUser = CommonUse.CurrentUser();

	// for each record find record in information register - take fields Version and LockedBy from there
	QueryInRegister = New Query;
	QueryInRegister.SetParameter("User", CurrentUser);
	QueryInRegister.Text = "SELECT
	                       |	FilesInWorkingDirectory.Version AS Version,
	                       |	FilesInWorkingDirectory.Version.Owner.LockedBy AS LockedBy
	                       |FROM
	                       |	InformationRegister.FilesInWorkingDirectory AS FilesInWorkingDirectory
	                       |WHERE
	                       |	FilesInWorkingDirectory.User = &User
	                       |	AND FilesInWorkingDirectory.InOwnerWorkingDirectory = FALSE";
	
	QueryResult = QueryInRegister.Execute(); 
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Choose();
		While Selection.Next() Do
				
			If Selection.LockedBy <> CurrentUser Then
				ListDelete.Add(Selection.Version);
			EndIf;
			
		EndDo;
	EndIf;
	
	SetPrivilegedMode(True);
	For Each Version in ListDelete Do
		// Create recordset
		RecordSet = InformationRegisters.FilesInWorkingDirectory.CreateRecordSet();
		
		RecordSet.Filter.Version.Set(Version);
		RecordSet.Filter.User.Set(CurrentUser);
		
		RecordSet.Write();
	EndDo;
EndProcedure

Procedure DeleteVersionAndAddFilesInWorkingDirectoryRegisterRecord(OldVersion, NewVersion, FullFileName, DirectoryPath, InOwnerWorkingDirectory)
	DeleteFromRegister(OldVersion);
	ForRead = True;
	AddFilesInWorkingDirectoryRegisterRecord(NewVersion, FullFileName, DirectoryPath, ForRead, 0, InOwnerWorkingDirectory);
EndProcedure

Procedure AddFilesInWorkingDirectoryRegisterRecord(Version, FullPath, DirectoryPath, ForRead, FileSize, InOwnerWorkingDirectory)  Export
	FileNameWithPath = FullPath;
	
	If InOwnerWorkingDirectory = False Then
		If Find(FullPath, DirectoryPath) = 1 Then
			FileNameWithPath = Mid(FullPath, StrLen(DirectoryPath) + 1);
		EndIf;
	EndIf;
	
	SetPrivilegedMode(True);
	
	// Create recordset
	RecordSet = InformationRegisters.FilesInWorkingDirectory.CreateRecordSet();
	
	RecordSet.Filter.Version.Set(Version.Ref);
	RecordSet.Filter.User.Set(CommonUse.CurrentUser());

	NewRecord = RecordSet.Add();
	NewRecord.Version = Version.Ref;
	NewRecord.Path = FileNameWithPath;

	If FileSize <> 0 Then
		NewRecord.Size = FileSize;
	Else 
		NewRecord.Size = Version.Size;
	EndIf;

	NewRecord.WorkingDirectoryPlacementDate = CurrentDate();
	NewRecord.User = CommonUse.CurrentUser();
	NewRecord.ForRead = ForRead;
	NewRecord.InOwnerWorkingDirectory = InOwnerWorkingDirectory;

	RecordSet.Write();
EndProcedure

// Returns array of files in information register FilesInWorkingDirectory
Function ListOfFilesInRegister() Export
	
	SetPrivilegedMode(True);
	
	FileList = New Array;
	CurrentUser = CommonUse.CurrentUser();
	
	// for each record find record in information register - take fields Version and LockedBy from there
	QueryInRegister = New Query;
	QueryInRegister.SetParameter("User", CurrentUser);
	
	QueryInRegister.Text = 
		"SELECT
		|	FilesInWorkingDirectory.Version AS Version,
		|	FilesInWorkingDirectory.ForRead AS ForRead,
		|	FilesInWorkingDirectory.Size AS Size,
		|	FilesInWorkingDirectory.Path AS Path
		|FROM
		|	InformationRegister.FilesInWorkingDirectory AS FilesInWorkingDirectory
		|WHERE
		|	FilesInWorkingDirectory.User = &User
		|	AND FilesInWorkingDirectory.InOwnerWorkingDirectory = FALSE";
	
	QueryResult = QueryInRegister.Execute(); 
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Choose();
		While Selection.Next() Do
			Version = Selection.Version;
			
			Record = New Structure;
			Record.Insert("ModificationDateUniversal", 	Version.ModificationDateUniversal);

			Record.Insert("Description",  Version.Description);
			Record.Insert("PictureIndex", Version.PictureIndex);
			Record.Insert("Size", 		  Selection.Size);
			Record.Insert("Ref", 		  Version.Ref);
			Record.Insert("LockedBy", 	  Version.Owner.LockedBy);
			Record.Insert("ForRead", 	  Selection.ForRead);
			Record.Insert("PartialPath",  Selection.Path);
			
			FileList.Add(Record);
		EndDo;
	EndIf;
	
	Return FileList;
EndFunction	

Function CatalogsFoldersCreateItem(Name, Parent, User = Undefined) Export
	Folder = Catalogs.FileFolders.CreateItem();
	Folder.Description = Name;
	Folder.Parent = Parent;
	Folder.CreationDate = CurrentDate();
	
	If User = Undefined Then
		Folder.Responsible = CommonUse.CurrentUser();
	Else	
		Folder.Responsible = User;
	EndIf;	
	
	Folder.Write();
	Return Folder.Ref;
EndFunction

// Generates report for files with errors
Function ImportFilesGenerateReport(FileNamesWithErrorsArray) Export
	Spreadsheet = New SpreadsheetDocument;
	TabTemplate = Catalogs.Files.GetTemplate("ReportTemplate");
	
	AreaTitle = TabTemplate.GetArea("Title");
	AreaTitle.Parameters.Details = NStr("en = 'Files with errors:'");
	Spreadsheet.Put(AreaTitle);
	
	AreaRow = TabTemplate.GetArea("String");

	For Each Selection In FileNamesWithErrorsArray Do
		AreaRow.Parameters.FName = Selection.FileName;
		AreaRow.Parameters.Error = Selection.Error;
		Spreadsheet.Put(AreaRow);
	EndDo; 	
	
	Report = New SpreadsheetDocument;
	Report.Put(Spreadsheet);

	Return Report;
EndFunction

// Sorts array of structures by the field Date - at server, i.e. there is no ValueTable at thin client
Procedure SortStructuresArray(StructuresArray) Export
	
	FileTable = New ValueTable;
	FileTable.Columns.Add("Path");
	FileTable.Columns.Add("Version");
	FileTable.Columns.Add("Size");
	
	FileTable.Columns.Add("WorkingDirectoryPlacementDate", New TypeDescription("Date"));
	
	For Each String in StructuresArray Do
		NewRow = FileTable.Add();
		FillPropertyValues(NewRow, String, "Path, Size, Version, WorkingDirectoryPlacementDate");
	EndDo;
	
	// Sort by date - the oldest files will be in the beginning
	FileTable.Sort("WorkingDirectoryPlacementDate Asc");  
	
	StructuresArrayReturn = New Array;
	
	For Each String in FileTable Do
		Record = New Structure;
		Record.Insert("Path", 									String.Path);
		Record.Insert("Size", 									String.Size);
		Record.Insert("Version", 								String.Version);
		Record.Insert("WorkingDirectoryPlacementDate", 	String.WorkingDirectoryPlacementDate);
		StructuresArrayReturn.Add(Record);
	EndDo;			
	
	StructuresArray = StructuresArrayReturn;	
EndProcedure // SortStructuresArray()

// Returns setting - Ask edit mode on file open
Function AskEditModeOnFileOpening()
	AskEditModeOnFileOpening = 
		CommonSettingsStorage.Load("FilesOpenSettings", "AskEditModeOnFileOpening");
	If AskEditModeOnFileOpening = Undefined Then
		AskEditModeOnFileOpening = True;
		CommonSettingsStorage.Save("FilesOpenSettings", "AskEditModeOnFileOpening", AskEditModeOnFileOpening);
	EndIf;
	
	Return AskEditModeOnFileOpening;
EndFunction	
	
// Read OnDoubleClickAction - if first time - assign proper value
Function OnDoubleClickAction()
	HowToOpen = CommonUse.CommonSettingsStorageLoad("FilesOpenSettings", "OnDoubleClickAction");
	
	If HowToOpen = Undefined Or HowToOpen = Enums.FileDoubleClickActions.EmptyRef() Then
		HowToOpen = Enums.FileDoubleClickActions.OpenFile;
		CommonUse.CommonSettingsStorageSave("FilesOpenSettings", "OnDoubleClickAction", HowToOpen);
	EndIf;
	
	If HowToOpen = Enums.FileDoubleClickActions.OpenFile Then
		Return "OpenFile";
	Else
		Return "OpenCard";
	EndIf;
EndFunction

// Read FileVersionsCompareMethod from settings
Function FileVersionsCompareMethod()
	CompareMethod = CommonUse.CommonSettingsStorageLoad("FilesComparisonSettings", "FileVersionsCompareMethod");
	
	If CompareMethod = Enums.FileVersionComparisonMethods.MicrosoftOfficeWord Then
		Return "MicrosoftOfficeWord";
	ElsIf CompareMethod = Enums.FileVersionComparisonMethods.OpenOfficeOrgWriter Then
		Return "OpenOfficeOrgWriter";
	Else
		Return Undefined;
	EndIf;
EndFunction

// Function returns array of Files, locked by the current user
// by owner
Function GetLockedFilesCount(FileOwner) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	COUNT(*) AS Count
		|FROM
		|	Catalog.Files AS Files
		|WHERE
		|	Files.LockedBy = &LockedBy
		|	AND Files.FileOwner = &Owner";

	Query.SetParameter("LockedBy", CommonUse.CurrentUser());
	Query.SetParameter("Owner", FileOwner);
	Selection = Query.Execute().Choose();
	Selection.Next();
	
	Result = Selection.Count;
	
	Return Result;
EndFunction

// Gets value of setting ShowColumnSize
Function GetShowColumnSize() Export
	ShowColumnSize = CommonUse.CommonSettingsStorageLoad("ApplicationSettings", "ShowColumnSize");
	If ShowColumnSize = Undefined Then
		ShowColumnSize = False;
		CommonUse.CommonSettingsStorageSave("ApplicationSettings", "ShowColumnSize", ShowColumnSize);
	EndIf;
	
	Return ShowColumnSize;
EndFunction	
	
// Returns structure, containing distinct personal settings
// for operations with files
Function GetFileOperationsPersonalSettingsServer() Export
	Settings = New Structure;
	
	SetPrivilegedMode(True);
	
	Settings.Insert("OnDoubleClickAction", OnDoubleClickAction());
	
	Settings.Insert("AskEditModeOnFileOpening", AskEditModeOnFileOpening());
	
	Settings.Insert("FileVersionsCompareMethod", FileVersionsCompareMethod());
	
	LocalFilesCacheMaximumSize = CommonUse.CommonSettingsStorageLoad("LocalFilesCache", "LocalFilesCacheMaximumSize");
	If LocalFilesCacheMaximumSize = Undefined Then
		LocalFilesCacheMaximumSize = 100*1024*1024; // 100 MB
		CommonUse.CommonSettingsStorageSave("LocalFilesCache", "LocalFilesCacheMaximumSize", LocalFilesCacheMaximumSize);
	EndIf;
	Settings.Insert("LocalFilesCacheMaximumSize", LocalFilesCacheMaximumSize);

	LocalFilesCachePath = CommonUse.CommonSettingsStorageLoad("LocalFilesCache", "LocalFilesCachePath");
	Settings.Insert("LocalFilesCachePath", LocalFilesCachePath);
	
	DeleteFileFromFilesLocalCacheOnEditEnd = CommonUse.CommonSettingsStorageLoad("LocalFilesCache", "DeleteFileFromFilesLocalCacheOnEditEnd");
	Settings.Insert("DeleteFileFromFilesLocalCacheOnEditEnd", DeleteFileFromFilesLocalCacheOnEditEnd);
	
	ConfirmWhenDeletingFromLocalFilesCache = CommonUse.CommonSettingsStorageLoad("LocalFilesCache", "ConfirmWhenDeletingFromLocalFilesCache");
	If ConfirmWhenDeletingFromLocalFilesCache = Undefined Then
		ConfirmWhenDeletingFromLocalFilesCache = False;
	EndIf;
	Settings.Insert("ConfirmWhenDeletingFromLocalFilesCache", ConfirmWhenDeletingFromLocalFilesCache);
	
	Settings.Insert("CurrentUserHaveFullAccess", Users.CurrentUserHaveFullAccess());
	
	ExtractFileTextsAtServer = Constants.ExtractFileTextsAtServer.Get();
	
	Settings.Insert("ExtractFileTextsAtServer", ExtractFileTextsAtServer);
	
	MaximumFileSize = Constants.MaximumFileSize.Get();
	If MaximumFileSize = Undefined OR MaximumFileSize = 0 Then
		MaximumFileSize = 50*1024*1024; // 50 mb
		Constants.MaximumFileSize.Set(MaximumFileSize);
	EndIf;
	Settings.Insert("MaximumFileSize", MaximumFileSize);
	
	ProhibitFileLoadByExtension = Constants.ProhibitFileLoadByExtension.Get();
	If ProhibitFileLoadByExtension = Undefined Then
		ProhibitFileLoadByExtension = False;
		Constants.ProhibitFileLoadByExtension.Set(ProhibitFileLoadByExtension);
	EndIf;
	Settings.Insert("ProhibitFileLoadByExtension", ProhibitFileLoadByExtension);
	
	ProhibitedExtensionsList = Constants.ProhibitedExtensionsList.Get();
	If ProhibitedExtensionsList = Undefined OR ProhibitedExtensionsList = "" Then
		ProhibitedExtensionsList = "COM EXE BAT CMD VBS VBE JS JSE WSF WSH SCR";
		Constants.ProhibitedExtensionsList.Set(ProhibitedExtensionsList);
	EndIf;
	Settings.Insert("ProhibitedExtensionsList", ProhibitedExtensionsList);
	
	FileStorageType = Constants.FileStorageType.Get();
	If FileStorageType = Enums.FileStorageTypes.EmptyRef() Then
		FileStorageType = Enums.FileStorageTypes.Infobase;
		Constants.FileStorageType.Set(FileStorageType);
	EndIf;
	FilesStoredOnDrive = False;
	If FileStorageType = Enums.FileStorageTypes.VolumesOnHardDisk Then
		FilesStoredOnDrive = True;
	EndIf;
	Settings.Insert("FilesStoredOnDrive", FilesStoredOnDrive);
	
	OpenOperationBegin = CommonUse.CommonSettingsStorageLoad("ApplicationSettings", "OpenOperationBeginOnStartup");
    If OpenOperationBegin = Undefined Then
		OpenOperationBegin = True;
 	EndIf;
	Settings.Insert("OpenOperationBegin", OpenOperationBegin);
	
	Settings.Insert("CurrentUser", CommonUse.CurrentUser());	
	
	Settings.Insert("ConfigurationName", Metadata.Name);

	ShowTipsOnEditFiles = CommonUse.CommonSettingsStorageLoad("ApplicationSettings", "ShowTipsOnEditFiles");
	If ShowTipsOnEditFiles = Undefined Then
		ShowTipsOnEditFiles = True;
		CommonUse.CommonSettingsStorageSave("ApplicationSettings", "ShowTipsOnEditFiles", ShowTipsOnEditFiles);
	EndIf;
	Settings.Insert("ShowTipsOnEditFiles", ShowTipsOnEditFiles);

	ShowLockedFilesOnExit = CommonUse.CommonSettingsStorageLoad("ApplicationSettings", "ShowLockedFilesOnExit");
	If ShowLockedFilesOnExit = Undefined Then
		ShowLockedFilesOnExit = True;
		CommonUse.CommonSettingsStorageSave("ApplicationSettings", "ShowLockedFilesOnExit", ShowLockedFilesOnExit);
	EndIf;	
	Settings.Insert("ShowLockedFilesOnExit", ShowLockedFilesOnExit);
	
	Return Settings; 
EndFunction

// Function changes FileOwner for objects of type Catalog.File, return True on success
Function SetFileOwner(FileRefsArray, NewFileOwner) Export
	If FileRefsArray.Count() = 0 Or Not ValueIsFilled(NewFileOwner) Then
		Return False;
	EndIf;
	
	// the same parent - do nothing
	If FileRefsArray.Count() > 0 And (FileRefsArray[0].FileOwner = NewFileOwner) Then
		Return False;
	EndIf;
	
	BeginTransaction();
	Try
	
		For Each FileAccepted In FileRefsArray Do
			FileObject = FileAccepted.GetObject();
			FileObject.Lock();
			FileObject.FileOwner = NewFileOwner;
			FileObject.Write();
		EndDo;
	
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	Return True;
EndFunction


// return True if there is looping (if we are moving one of the folders inside its child folder)
Function ParentInHierarchyRefsArray(Val FileRefsArray, NewParent)
	
	If FileRefsArray.Find(NewParent) <> Undefined Then
		Return True; // found looping
	EndIf;
	
	Parent = NewParent.Parent;
	If Parent.IsEmpty() Then // reached root
		Return False;
	EndIf;
	
	// found looping
	Return ParentInHierarchyRefsArray(FileRefsArray, Parent);
	
EndFunction

// Function changes property Parent for the objects of type Catalog.FileFolders, return True on success,
// in variable LoopingFound return True, if we are moving one of the folders inside its child folder
Function ChangeParentOfFolders(FileRefsArray, NewParent, LoopingFound) Export
	LoopingFound = False;
	
	If FileRefsArray.Count() = 0 Then
		Return False;
	EndIf;
	
	// the same parent - do nothing
	If FileRefsArray.Count() = 1 And (FileRefsArray[0].Parent = NewParent) Then
		Return False;
	EndIf;
	
	If ParentInHierarchyRefsArray(FileRefsArray, NewParent) Then
		LoopingFound = True;
		Return False;
	EndIf;
	
	BeginTransaction();
	Try
	
		For Each FileAccepted In FileRefsArray Do
			FileObject 			= FileAccepted.GetObject();
			FileObject.Lock();
			FileObject.Parent 	= NewParent;
			FileObject.Write();
		EndDo;
	
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	Return True;
EndFunction

// return True, if there is child item with the same name in specified item of the catalog FileFolders
Function FolderExists(FileName, Parent, FirstFolderWithThisName) Export
	
	FirstFolderWithThisName = Catalogs.FileFolders.EmptyRef();
	
	QueryInFolders = New Query;
	QueryInFolders.SetParameter("Description", FileName);
	QueryInFolders.SetParameter("Parent", Parent);
	QueryInFolders.Text = "SELECT ALLOWED TOP 1
	                      |	FileFolders.Ref AS Ref
	                      |FROM
	                      |	Catalog.FileFolders AS FileFolders
	                      |WHERE
	                      |	FileFolders.Description = &Description
	                      |	AND FileFolders.Parent = &Parent";
	
	QueryResult = QueryInFolders.Execute(); 
	
	If Not QueryResult.IsEmpty() Then
		QuerySelection = QueryResult.Unload();
		FirstFolderWithThisName = QuerySelection[0].Ref;
		Return True;
	EndIf;
	
	
	Return False;
EndFunction

// return True, if there is file with the same name in specified item of the catalog FileFolders
Function FileExists(FileName, Parent) Export
	
	QueryInFolders = New Query;
	QueryInFolders.SetParameter("Description", FileName);
	QueryInFolders.SetParameter("Parent", Parent);
	QueryInFolders.Text = "SELECT ALLOWED TOP 1
	                      |	Files.Ref AS Ref
	                      |FROM
	                      |	Catalog.Files AS Files
	                      |WHERE
	                      |	Files.FileName = &Description
	                      |	AND Files.FileOwner = &Parent";
	
	QueryResult = QueryInFolders.Execute(); 
	
	If NOT QueryResult.IsEmpty() Then
		Return True;
	EndIf;
	
	
	Return False;
EndFunction

// in catalog FileVersions from data in Code(String) fills VersionNo(Number)
Procedure FillVersionNoFromCatalogCode() Export
	SetPrivilegedMode(True);
	BeginTransaction();
	Try
		Selection = Catalogs.FileVersions.Select();
		While Selection.Next() Do
			Object = Selection.GetObject();
			
			// fix situation allowed previously but unaccepted now - active version marked for deletion, but owner - not
			If Object.DeletionMark = True 
			   And Object.Owner.DeletionMark = False 
			   And Object.Owner.CurrentVersion = Object.Ref Then
				Object.DeletionMark = False;
			EndIf;
			
			Try
				Object.VersionNo = Number(Object.Code);
				Object.Write();
			Except // don't use code with db perfix. This is not an error due to only in older versions of the configuration
			EndTry;
		EndDo;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
EndProcedure	

// in catalog FileVersions fills FileStorageType with value InBase
Procedure FillFileStorageTypeInBase() Export
	SetPrivilegedMode(True);
	BeginTransaction();
	Try
		Selection = Catalogs.FileVersions.Select();
		While Selection.Next() Do
			Object = Selection.GetObject();
			Object.FileStorageType = Enums.FileStorageTypes.Infobase;
			Object.Write();
		EndDo;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
EndProcedure	

// for the catalog FileVersions renames file on disk, if FileStorageType = VolumesOnHardDisk
Procedure RenameFileVersionFromDisk(Version, FormerDescription, NewDescription) Export
	
	If Not Version.Volume.IsEmpty() Then
		Try
			VersionObject = Version.GetObject();
			VersionObject.Lock();
			
			FormerFullPath = VolumeFullPath(Version.Volume) + Version.FilePath; 
			
			FileOnDisk				= New File(FormerFullPath);
			FullPath   				= FileOnDisk.Path;
			BaseName   				= FileOnDisk.BaseName;
			Extension   			= FileOnDisk.Extension;
			NewNameWithoutExpansion = StrReplace(BaseName, FormerDescription, NewDescription);
			
			NewFullPath 	= FullPath + NewNameWithoutExpansion + Extension;
			NewPartialPath  = Right(NewFullPath, StrLen(NewFullPath) - VolumeFullPath(Version.Volume));
		
			MoveFile(FormerFullPath,   NewFullPath);
			VersionObject.FilePath = NewPartialPath;
			VersionObject.Write();
			VersionObject.Unlock();
		Except
		EndTry;
	EndIf;
EndProcedure	

// in catalog FileVersions and Files PictureIndex scales up 2 times
Procedure ChangePictogramIndex() Export
	SetPrivilegedMode(True);
	BeginTransaction();
	Try
		Selection  = Catalogs.FileVersions.Select();
		While Selection.Next() Do
			Object = Selection.GetObject();
			Object.DataExchange.Load = True;
			Object.PictureIndex = FileOperationsClientServer.GetFilePictogramIndex(Object.Extension);
			Object.Write();
		EndDo;
		
		Selection  = Catalogs.Files.Select();
		While Selection.Next() Do
			Object = Selection.GetObject();
			Object.DataExchange.Load = True;
			Object.PictureIndex = Object.CurrentVersion.PictureIndex;
			Object.Write();
		EndDo;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
EndProcedure	

// returns list of locked files
Function GetLockedFiles(FileOwner = Undefined, LockedBy = Undefined) Export
	
	List = New ValueList;
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	Files.Ref AS Ref,
	|	Files.Presentation AS Presentation
	|FROM
	|	Catalog.Files AS Files
	|WHERE
	|	Files.LockedBy <> VALUE(Catalog.Users.EmptyRef)";
	
	If LockedBy <> Undefined Then 
		Query.Text = Query.Text + " And Files.LockedBy = &LockedBy ";
		Query.SetParameter("LockedBy", LockedBy);
	EndIf;
	
	If FileOwner <> Undefined Then 
		Query.Text = Query.Text + " And Files.FileOwner = &FileOwner ";
		Query.SetParameter("FileOwner", FileOwner);
	EndIf;	
	
	Selection = Query.Execute().Choose();
	While Selection.Next() Do
		List.Add(Selection.Ref, Selection.Presentation);
	EndDo;	
	
	Return List;
	
EndFunction

// marks \ unmarks for deletion attached files
Procedure MarkAttachedFilesForDeletion(FileOwner, DeletionMark) Export 
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	Files.Ref AS Ref,
	|	Files.LockedBy AS LockedBy
	|FROM
	|	Catalog.Files AS Files
	|WHERE
	|	Files.FileOwner = &FileOwner";
	
	Query.SetParameter("FileOwner", FileOwner);
	
	Result = Query.Execute();
	Selection = Result.Choose();
	While Selection.Next() Do
		If DeletionMark And Not Selection.LockedBy.IsEmpty() Then
			Raise StringFunctionsClientServer.SubstitureParametersInString(
				NStr("en = '%1 cannot be deleted it contains %2 file which is locked for editing'"),
				String(FileOwner),
				String(Selection.Ref));
		EndIf;
		FileObject = Selection.Ref.GetObject();
		FileObject.Lock();
		FileObject.SetDeletionMark(DeletionMark);
	EndDo;
	
EndProcedure	

// gets data for moving file from one list of attached files to another
Function GetDataForTransferToAttachedFiles(FileArray, FileOwner) Export

	If TypeOf(FileArray) = Type("Array") Then 
		FilesArray = FileArray;
	Else
		FilesArray = New Array;
		FilesArray.Add(FileArray);
	EndIf;	
	
	Query = New Query;
	Query.Text = 
		"SELECT ALLOWED
		|	Files.Ref AS Ref,
		|	Files.FileName AS Details
		|FROM
		|	Catalog.Files AS Files
		|WHERE
		|	Files.FileOwner = &FileOwner";
	Query.SetParameter("FileOwner", FileOwner);
	TablResult = Query.Execute().Unload();
	
	Result = New Map;
	For Each FileRef In FilesArray Do
		
		If TablResult.Find(FileRef, "Ref") <> Undefined Then 
			Result.Insert(FileRef, "Ignore");
		ElsIf TablResult.Find(FileRef.Details, "Details") <> Undefined Then 
			Result.Insert(FileRef, "Refresh");
		Else 	
			Result.Insert(FileRef, "Copy");
		EndIf;	
		
	EndDo;	
	
	Return Result;
	
EndFunction	

// copies files from one list of attached files to another
Function CopyFileInAttached(FileArray, FileOwner) Export
	
	If TypeOf(FileArray) = Type("Array") Then 
		FilesArray = FileArray;
	Else
		FilesArray = New Array;
		FilesArray.Add(FileArray);
	EndIf;
	
	For Each FileRef In FilesArray Do
		
		Source 		 = FileRef;
		SourceObject = Source.GetObject();
		
		ReceiverObject 			 = SourceObject.Copy();
		ReceiverObject.FileOwner = FileOwner;
		ReceiverObject.Write();
		
		Receiver = ReceiverObject.Ref;
		
		If Not Source.CurrentVersion.IsEmpty() Then
			Version = FileOperations.CreateFileVersion(
			CurrentDate(),
			ToUniversalTime(CurrentDate()),
			Receiver,
			Receiver.Description,
			Source.CurrentVersion.Size,
			Source.CurrentVersion.Extension,
			Source.CurrentVersion.FileStorage,
			Source.CurrentVersion.TextStorage,
			False,
			Source.CurrentVersion);
			
			FileOperations.UpdateFileCurrentVersion(Receiver, Version, Source.CurrentVersion.TextStorage);
		EndIf;
		
	EndDo;
	
	Return Receiver;
	
EndFunction

// updates versions of the files with the same name while moving from one list to another
Function RefreshFileInAttachedFiles(FileArray, FileOwner) Export
	
	If TypeOf(FileArray) = Type("Array") Then 
		FilesArray = FileArray;
	Else
		FilesArray = New Array;
		FilesArray.Add(FileArray);
	EndIf;
	
	Query = New Query;
	Query.Text = 
		"SELECT ALLOWED
		|	Files.Ref AS Ref,
		|	Files.FileName AS Details
		|FROM
		|	Catalog.Files AS Files
		|WHERE
		|	Files.FileOwner = &FileOwner";
	Query.SetParameter("FileOwner", FileOwner);
	
	TablResult = Query.Execute().Unload();
	For Each FileRef In FilesArray Do
		
		RowFound = TablResult.Find(FileRef.Details, "Details");
		
		Source = FileRef;
		Receiver = RowFound.Ref;
		
		If Not Source.CurrentVersion.IsEmpty() Then
			Version = FileOperations.CreateFileVersion(
				CurrentDate(),
				ToUniversalTime(CurrentDate()),
				Receiver,
				Receiver.Description,
				Source.CurrentVersion.Size,
				Source.CurrentVersion.Extension,
				Source.CurrentVersion.FileStorage,
				Source.CurrentVersion.TextStorage,
				False,
				Source.CurrentVersion);
			
			FileOperations.UpdateFileCurrentVersion(Receiver, Version, Source.CurrentVersion.TextStorage);
		EndIf;
		
	EndDo;	
	
	Return Receiver;
	
EndFunction

// fills conditional appearance of the file list
Procedure FillFileListConditionalAppearance(List) Export
	Item 	 	= List.ConditionalAppearance.Items.Add();
	Item.Use	= True;
	Item.Appearance.SetParameterValue("TextColor", StyleColors.FileLockedByAnotherUserColor);
	Filter	   	= Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	Filter.Use 	= True;
	Filter.ComparisonType = DataCompositionComparisonType.NotEqual;
	Filter.LeftValue 	  = New DataCompositionField("LockedBy");
	Filter.RightValue	  = PredefinedValue("Catalog.Users.EmptyRef");
	
	Item 	 = List.ConditionalAppearance.Items.Add();
	Item.Use = True;
	Item.Appearance.SetParameterValue("TextColor", StyleColors.FileLockedByCurrentUserColor);
	Filter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	Filter.Use 				= True;
	Filter.ComparisonType	= DataCompositionComparisonType.Equal;
	Filter.LeftValue 		= New DataCompositionField("LockedBy");
	Filter.RightValue 		= CommonUse.CurrentUser();
EndProcedure	

// Returns current user ID from server to client
Function SessionParametersUserWorkingDirectoryPath() Export
	SetPrivilegedMode(True);   
	Return SessionParameters.UserWorkingDirectoryPath;
EndFunction

// Saves path to the user working directory in settings and session parameters
Procedure SetSessionParameterUserWorkingDirectoryPath(Path) Export
	SetPrivilegedMode(True);   
	SessionParameters.UserWorkingDirectoryPath = Path;
EndProcedure	

// Saves path to the user working directory in settings and session parameters
Procedure SaveUserWorkingDirectoryPath(DirectoryPath) Export
	CommonUse.CommonSettingsStorageSave("LocalFilesCache", "LocalFilesCachePath", DirectoryPath);	
	SetSessionParameterUserWorkingDirectoryPath(DirectoryPath);
EndProcedure	

// Assignes session parameter "UserWorkingDirectoryPath" on system start
//
// Parameters:
//  ParameterName  			- String - name of the parameter being initialized
//  InitializedParameters   - Array  - array, where names of initialized
//                 session parameters are collected
//
Procedure SessionParametersInitialization(ParameterName, InitializedParameters) Export

	If ParameterName <> "UserWorkingDirectoryPath" Then
		Return;
	EndIf;
	
	SetPrivilegedMode(True);   
	
	If ParameterName = "UserWorkingDirectoryPath" Then
		SessionParameters.UserWorkingDirectoryPath = "";
		InitializedParameters.Add(ParameterName);
	EndIf;
	
EndProcedure // ()

// Returns object, for which access right is being checked - for File this is FileFolders (attribute FileOwner)
Function GetAccessObject(Object) Export
	If TypeOf(Object) <> Type("CatalogRef.Files") Then
		Return Undefined;
	EndIf;	
	
	If TypeOf(Object.FileOwner) = Type("CatalogRef.FileFolders") Then
		Return Object.FileOwner;
	EndIf;	
	
	Return Undefined;
EndFunction	

// Returns ascending number. Previous value is taken from the information register ScannedFileNumbers
Function GetNewScanNumber(Owner) Export
	
	// Prepare dimensions filter structure
	FilterStructure = New Structure;
	FilterStructure.Insert("Owner", Owner);
	
	BeginTransaction();
	Try
		Block 	 		= New DataLock;
		LockItem 		= Block.Add("InformationRegister.ScannedFileNumbers");
		LockItem.Mode 	= DataLockMode.Exclusive;
		LockItem.SetValue("Owner", Owner);
		Block.Lock();   		
	
		// Get structure with the record resources data
		ResourcesStructure = InformationRegisters.ScannedFileNumbers.Get(FilterStructure);
		   
		// Get maximum number from the register
		Number = ResourcesStructure.Number;
		Number = Number + 1; // next one
		
		
		// write new number to register
		RecordSet = InformationRegisters.ScannedFileNumbers.CreateRecordSet();
		
		RecordSet.Filter.Owner.Set(Owner);

		NewRecord 		 = RecordSet.Add();
		NewRecord.Owner  = Owner;
		NewRecord.Number = Number;

		RecordSet.Write();
		
		CommitTransaction();
		
		Return Number;
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	
	Return 0;
EndFunction	

// Clears forms settings NewItemForm
Procedure DeleteNewFileFormSettings() Export
	
	SetPrivilegedMode(True);
	// Clear settings of the window NewItemForm
	SystemSettingsStorage.Delete("Catalog.Files.Form.NewItemForm/WindowSettings", "", Undefined);
	
EndProcedure	

// Returns total size of files on volume - in bytes
Function CalculateFilesSizeOnVolume(RefOfVolume) Export
	Query = New Query;
	Query.Text = "SELECT
	             |	ISNULL(SUM(Versions.Size), 0) AS FilesSize
	             |FROM
	             |	Catalog.FileVersions AS Versions
	             |WHERE
	             |	Versions.Volume = &Volume";
	
	Query.Parameters.Insert("Volume", RefOfVolume);
		
	Selection = Query.Execute().Choose();
	If Selection.Next() Then
		Return Number(Selection.FilesSize);
	EndIf;
	
	Return 0;
EndFunction	

// Converts scanner parameters from numbers to enums
Procedure ConvertScannerParametersToEnums(ResolutionNumber, ChromaticityNumber, RotationNumber, PaperSizeNumber, 
	Resolution, Chromaticity, Rotation, PaperSize) Export
	
	If ResolutionNumber = 200 Then
		Resolution = Enums.ScannedImageResolutions.dpi200;
	ElsIf ResolutionNumber = 300 Then
		Resolution = Enums.ScannedImageResolutions.dpi300;
	ElsIf ResolutionNumber = 600 Then
		Resolution = Enums.ScannedImageResolutions.dpi600;
	ElsIf ResolutionNumber = 1200 Then
		Resolution = Enums.ScannedImageResolutions.dpi1200;
	EndIf;
	
	If ChromaticityNumber = 0 Then
		Chromaticity = Enums.ImageChromaticities.Monochrome;
	ElsIf ChromaticityNumber = 1 Then
		Chromaticity = Enums.ImageChromaticities.GrayGradations;
	ElsIf ChromaticityNumber = 2 Then
		Chromaticity = Enums.ImageChromaticities.Coloured;
	EndIf;
	
	If RotationNumber = 0 Then
		Rotation = Enums.ImageRotation.NoRotation;
	ElsIf RotationNumber = 90 Then
		Rotation = Enums.ImageRotation.ToTheRightAt90;
	ElsIf RotationNumber = 180 Then
		Rotation = Enums.ImageRotation.ToTheRightAt180;
	ElsIf RotationNumber = 270 Then
		Rotation = Enums.ImageRotation.ToTheLeftAt90;
	EndIf;
	
	If PaperSizeNumber = 0 Then
		PaperSize = Enums.PaperSizes.NotDefined;
	ElsIf PaperSizeNumber = 11 Then
		PaperSize = Enums.PaperSizes.A3;
	ElsIf PaperSizeNumber = 1 Then
		PaperSize = Enums.PaperSizes.A4;
	ElsIf PaperSizeNumber = 5 Then
		PaperSize = Enums.PaperSizes.A5;
	ElsIf PaperSizeNumber = 6 Then
		PaperSize = Enums.PaperSizes.B4;
	ElsIf PaperSizeNumber = 2 Then
		PaperSize = Enums.PaperSizes.B5;
	ElsIf PaperSizeNumber = 7 Then
		PaperSize = Enums.PaperSizes.B6;
	ElsIf PaperSizeNumber = 14 Then
		PaperSize = Enums.PaperSizes.C4;
	ElsIf PaperSizeNumber = 15 Then
		PaperSize = Enums.PaperSizes.C5;
	ElsIf PaperSizeNumber = 16 Then
		PaperSize = Enums.PaperSizes.C6;
	ElsIf PaperSizeNumber = 3 Then
		PaperSize = Enums.PaperSizes.USLetter;
	ElsIf PaperSizeNumber = 4 Then
		PaperSize = Enums.PaperSizes.USLegal;
	ElsIf PaperSizeNumber = 10 Then
		PaperSize = Enums.PaperSizes.USExecutive;
	EndIf;
	
EndProcedure

// Converts number to enum and saves it in settings
Procedure ConvertAndSaveScannerParameters(ResolutionNumber, ChromaticityNumber, RotationNumber, 
		PaperSizeNumber, ClientID) Export
	Var Resolution;
	Var Chromaticity;
	Var Rotation;
	Var PaperSize;
	
	ConvertScannerParametersToEnums(ResolutionNumber, ChromaticityNumber, RotationNumber, PaperSizeNumber, 
		Resolution, Chromaticity, Rotation, PaperSize);
	CommonSettingsStorage.Save("ScanSettings/Resolution", ClientID, Resolution);
	CommonSettingsStorage.Save("ScanSettings/Chromaticity", ClientID, Chromaticity);
EndProcedure	

// Being called on update for 1.0.6.3 - fills paths FileStorageVolumes
Procedure FillVolumePaths() Export
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		Selection = Catalogs.FileStorageVolumes.Select();
		While Selection.Next() Do
			Object = Selection.GetObject();
			Object.FullPathLinux = Object.FullPathWindows;
			Object.Write();
		EndDo;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure	

// Moves setting (copies to a new location, deletes in old location)
Procedure MoveSetting(Object, Options, CurrentName, NewName) 
	
	Value = CommonSettingsStorage.Load(Object, Options, , CurrentName);
	
	If Value <> Undefined Then
		CommonSettingsStorage.Save(Object, Options, Value, , NewName);
		CommonSettingsStorage.Delete(Object, Options, CurrentName);
	EndIf;
EndProcedure
	
// On user rename, moves user settings - WorkingDirectory, OnDoubleClickAction and other
Procedure MoveSettingsOnChangeOfUserName(Val CurrentName, Val NameBeingAssigned) Export
	
	MoveSetting("LocalFilesCache", "LocalFilesCachePath", 					 CurrentName, NameBeingAssigned); // move path to the working directory too - so that files would not be lost
	MoveSetting("LocalFilesCache", "LocalFilesCacheMaximumSize", 			 CurrentName, NameBeingAssigned);
	MoveSetting("LocalFilesCache", "DeleteFileFromFilesLocalCacheOnEditEnd", CurrentName, NameBeingAssigned);
	MoveSetting("LocalFilesCache", "ConfirmWhenDeletingFromLocalFilesCache", CurrentName, NameBeingAssigned);
	
	MoveSetting("ApplicationSettings", "ShowColumnSize", 			  CurrentName, NameBeingAssigned);
	MoveSetting("ApplicationSettings", "OpenOperationBeginOnStartup", CurrentName, NameBeingAssigned);
	MoveSetting("ApplicationSettings", "ShowTipsOnEditFiles", 		  CurrentName, NameBeingAssigned);
	MoveSetting("ApplicationSettings", "ShowLockedFilesOnExit", 	  CurrentName, NameBeingAssigned);
	MoveSetting("ApplicationSettings", "FolderForSaveAs", 			  CurrentName, NameBeingAssigned);
	MoveSetting("ApplicationSettings", "FolderForUpdateFromFile", 	  CurrentName, NameBeingAssigned);
	
	MoveSetting("FilesComparisonSettings", "FileVersionsCompareMethod",	CurrentName, NameBeingAssigned);
	MoveSetting("UnloadFolderName", 	   "UnloadFolderName", 			CurrentName, NameBeingAssigned);
	
	MoveSetting("FilesOpenSettings", "OnDoubleClickAction",		 CurrentName, NameBeingAssigned);
	MoveSetting("FilesOpenSettings", "AskEditModeOnFileOpening", CurrentName, NameBeingAssigned);
	
EndProcedure

// Handler of event OnWrite. Defined for the objects (except Document), File owners.
Procedure SetDeletionMarkOfFilesBeforeWrite(Source, Cancellation) Export
	If Source.DeletionMark <> Source.Ref.DeletionMark Then 
		MarkAttachedFilesForDeletion(Source.Ref, Source.DeletionMark);
	EndIf;
EndProcedure

// Handler of event OnWrite. Defined for the objects of type Document, File owners.
Procedure SetDeletionMarkOfDocumentFilesBeforeWrite(Source, Cancellation, WriteMode, PostingMode) Export
	If Source.DeletionMark <> Source.Ref.DeletionMark Then 
		MarkAttachedFilesForDeletion(Source.Ref, Source.DeletionMark);
	EndIf;
EndProcedure

// gets top 100 file versions, having not extracted yet text
Function GetVersionsArrayForTextExtraction() Export
	
	VersionsArray = New Array;
	
	Query = New Query;
	
	Query.Text = 			
	 "SELECT TOP 100
	 |	FileVersions.Ref AS Ref,
	 |	FileVersions.TextExtractionStatus AS TextExtractionStatus
	 |FROM
	 |	Catalog.FileVersions AS FileVersions
	 |WHERE
	 |	(FileVersions.TextExtractionStatus = &Status
	 |			OR FileVersions.TextExtractionStatus = VALUE(Enum.FileTextExtractionStatuses.EmptyRef))";
	
	Query.SetParameter("Status", Enums.FileTextExtractionStatuses.NotExtracted);
	
	Result 	    = Query.Execute();
	UnloadTable = Result.Unload();
	
	For Each String In UnloadTable Do
		VersionRef = String.Ref;
		VersionsArray.Add(VersionRef);
	EndDo;
	
	Return VersionsArray;
	
EndFunction

// Writes text extraction result at server - extracted text and TextExtractionStatus
Procedure WriteTextExtractionResult(VersionRef, ExtractionResult, TextTemporaryStorageAddress) Export
	
	FileIsLocked = False;
	File = VersionRef.Owner;
	
	If File.CurrentVersion = VersionRef Then
		
		Try
			LockDataForEdit(File);
			FileIsLocked = True;
		Except
			Return; // output nothing
		EndTry;
		
	EndIf;
	
	Text = "";
	
	VersionObject = VersionRef.GetObject();
	
	If Not IsBlankString(TextTemporaryStorageAddress) Then
		Text = GetStringFromTemporaryStorage(TextTemporaryStorageAddress);
		VersionObject.TextStorage = New ValueStorage(Text);
		VersionObject.TextExtractionStatus = Enums.FileTextExtractionStatuses.Extracted;
	EndIf;
	
	If ExtractionResult = "NotExtracted" Then
		VersionObject.TextExtractionStatus = Enums.FileTextExtractionStatuses.NotExtracted;
	ElsIf ExtractionResult = "Extracted" Then
		VersionObject.TextExtractionStatus = Enums.FileTextExtractionStatuses.Extracted;
	ElsIf ExtractionResult = "ExtractFailed" Then
		VersionObject.TextExtractionStatus = Enums.FileTextExtractionStatuses.ExtractFailed;
	EndIf;	
	
	BeginTransaction();
	Try

		VersionObject.Write();

		If File.CurrentVersion = VersionRef Then
			FileObject 				= File.GetObject();
			FileObject.TextStorage  = VersionObject.TextStorage;
			FileObject.Write();
		EndIf;
		
		CommitTransaction();
		
		If FileIsLocked Then
			UnlockDataForEdit(File);
		EndIf;
		
	Except
		RollbackTransaction();
		If FileIsLocked Then
			UnlockDataForEdit(File);
		EndIf;
		
		Raise;
	EndTry;
	
EndProcedure

// gets array of refs of all files in a directory (if Recursively, then and in subdirectories too)
Function GetAllFilesInFolder(Folder, Recursively) Export
	
	FilesArray = New Array;
	
	GetAllFilesInFolderToParam(Folder, FilesArray);
	
	If Recursively Then
		
		FolderArray = New Array;
		
		Query = New Query;
		Query.SetParameter("Parent", Folder);
		Query.Text = 
			"SELECT ALLOWED
			|	FileFolders.Ref AS Ref
			|FROM
			|	Catalog.FileFolders AS FileFolders
			|WHERE
			|	FileFolders.Parent IN HIERARCHY(&Parent)";
		
		Result = Query.Execute();
		Selection = Result.Choose();
		While Selection.Next() Do
			FolderArray.Add(Selection.Ref);
		EndDo;
		
		For Each Subfolder In FolderArray Do
			GetAllFilesInFolderToParam(Subfolder, FilesArray);
		EndDo;	
		
	EndIf;	
	
	Return FilesArray;
EndFunction	

// gets array of refs of all files in a directory
Procedure GetAllFilesInFolderToParam(Folder, FilesArray) Export
	
	QueryInFolders = New Query;
	QueryInFolders.SetParameter("Parent", Folder);
	QueryInFolders.Text = 
		"SELECT ALLOWED
		|	Files.Ref AS Ref
		|FROM
		|	Catalog.Files AS Files
		|WHERE
		|	Files.FileOwner = &Parent";
	
	Result = QueryInFolders.Execute();
	Selection = Result.Choose();
	While Selection.Next() Do
		FilesArray.Add(Selection.Ref);
	EndDo;
	
EndProcedure


// gets FileData and VersionURL
Function GetFileDataAndVersionURL(FileRef, VersionRef, FormID) Export
	
	FileData = FileOperations.GetFileData(FileRef, VersionRef);
	If VersionRef = Undefined Then
		VersionRef = FileRef.CurrentVersion;
	EndIf;	
	VersionURL = FileOperations.GetURLForOpening(VersionRef, FormID);

	ReturnStructure = New Structure("FileData, VersionURL", FileData, VersionURL);
	
	Return ReturnStructure;
EndFunction

// Gets file data for opening and reads them Common settings FolderForSaveAs
Function GetFileDataForSaving(FileRef, VersionRef = Undefined, 
	FormID = Undefined, OwnerWorkingDirectory = Undefined) Export

	FileData = GetFileDataForOpening(FileRef, VersionRef, FormID, OwnerWorkingDirectory);
	
	FolderForSaveAs = CommonUse.CommonSettingsStorageLoad("ApplicationSettings", "FolderForSaveAs");
	FileData.Insert("FolderForSaveAs", FolderForSaveAs);

	Return FileData;
EndFunction // GetFileDataAndLockFile()

// in catalog Files overwrites all items
Procedure OverwriteAllFiles() Export
	SetPrivilegedMode(True);
	BeginTransaction();
	Try
		Selection = Catalogs.Files.Select();
		While Selection.Next() Do
			Object = Selection.GetObject();
			
			If Not ValueIsFilled(Object.FileOwner) Then
				Object.FileOwner = Catalogs.FileFolders.FileTemplates;
			EndIf;
			
			Object.Write();
		EndDo;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
EndProcedure	

// gets FileData and VersionURL of all subordinate files for Incom Outg Inter
Function GetFileDataAndVersionURLOfFilesByOwner(FileOwner, FormID) Export
	
	Query = New Query;
	Query.Text = 
		"SELECT ALLOWED
		|	Files.Ref AS Ref
		|FROM
		|	Catalog.Files AS Files
		|WHERE
		|	Files.FileOwner = &FileOwner";
	
	Query.SetParameter("FileOwner", FileOwner);
	Result 		= Query.Execute();
	Selection 	= Result.Choose();
	
	ReturnArray = New Array;
	While Selection.Next() Do
		
		FileRef 	= Selection.Ref;
		VersionRef 	= FileRef.CurrentVersion;
		FileData 	= FileOperations.GetFileData(FileRef, VersionRef);
		VersionURL 	= FileOperations.GetURLForOpening(VersionRef, FormID);

		ReturnStructure = New Structure("FileData, VersionURL", FileData, VersionURL);
		ReturnArray.Add(ReturnStructure);
	EndDo;
	
	Return ReturnArray;
EndFunction

// gets all subordinate files for Incom Outg Inter
Function GetAllSubordinateFiles(FileOwner) Export
	
	Query = New Query;
	Query.Text = 
		"SELECT ALLOWED
		|	Files.Ref AS Ref
		|FROM
		|	Catalog.Files AS Files
		|WHERE
		|	Files.FileOwner = &FileOwner";
	
	Query.SetParameter("FileOwner", FileOwner);
	Result 		= Query.Execute();
	Selection 	= Result.Choose();
	
	ReturnArray = New Array;
	While Selection.Next() Do
		ReturnArray.Add(Selection.Ref);
	EndDo;
	
	Return ReturnArray;
EndFunction

// Gets quantity of file versions
Function GetVersionsCount(FileRef) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = "SELECT
	             |	COUNT(*) AS Quantity
	             |FROM
	             |	Catalog.FileVersions AS FileVersions
	             |WHERE
	             |	FileVersions.Owner = &FileRef";
				  
	Query.SetParameter("FileRef", FileRef);
	Selection = Query.Execute().Choose();
	Selection.Next();
	
	Return Number(Selection.Quantity);
	
EndFunction	

// gets FileData and VersionURL of all subordinate files for Incom Outg Inter
Function GetFileDataAndURLOfAllFileVersions(FileRef, FormID) Export
	
	Query = New Query;
	Query.Text = 
		"SELECT ALLOWED
		|	FileVersions.Ref AS Ref
		|FROM
		|	Catalog.FileVersions AS FileVersions
		|WHERE
		|	FileVersions.Owner = &FileRef";
	
	Query.SetParameter("FileRef", FileRef);
	Result 		= Query.Execute();
	Selection 	= Result.Choose();
	
	ReturnArray = New Array;
	While Selection.Next() Do
		
		VersionRef	= Selection.Ref;
		FileData 	= FileOperations.GetFileData(FileRef, VersionRef);
		VersionURL	= FileOperations.GetURLToTemporaryStorage(VersionRef, FormID);
		
		ReturnStructure = New Structure("FileData, VersionURL, VersionRef", 
			FileData, VersionURL, VersionRef);
		ReturnArray.Add(ReturnStructure);
	EndDo;
	
	Return ReturnArray;
EndFunction

// puts encrypted files into database and assignes flag Encrypted to the file and all versions
Procedure BookmarkInformationAboutEncryption(FileRef, Encrypt, DataForWritingArray, UUID, 
	WorkingDirectoryPath, FilesInWorkingDirectoryToDeleteArray, ImprintsArray, AddressArray) Export
	
	BeginTransaction();
	Try
		
		FileObject 						= FileRef.GetObject();
		FileObject.Encrypted 			= Encrypt;
		FileObject.TextStorage 			= New ValueStorage(""); // clear extracted text
		FileObject.SignedObjectRecord 	= True;
		
		If Encrypt Then
			For Each ImprintStructure In ImprintsArray Do
				NewRow 				= FileObject.EncryptionCertificates.Add();
				NewRow.Imprint 		= ImprintStructure.Imprint;
				NewRow.Presentation = ImprintStructure.Presentation;
			EndDo;
		Else
			FileObject.EncryptionCertificates.Clear();
		EndIf;	
		
		FileObject.Write();
		
		For Each DataForRecordingAtServer In DataForWritingArray Do
			TemporaryStorageAddress = DataForRecordingAtServer.TemporaryStorageAddress;
			VersionRef 				= DataForRecordingAtServer.VersionRef;
			
			FileNameWithPathInWorkingDirectory = "";
			ReadonlyInWorkingDirectory 			= True; // is not used
			InOwnerWorkingDirectory 			= True;
			FileNameWithPathInWorkingDirectory  = GetFileNameWithPathFromRegister(VersionRef, WorkingDirectoryPath, ReadonlyInWorkingDirectory, InOwnerWorkingDirectory);
			If Not IsBlankString(FileNameWithPathInWorkingDirectory) Then
				FilesInWorkingDirectoryToDeleteArray.Add(FileNameWithPathInWorkingDirectory);
			EndIf;	
			
			DeleteFromRegister(VersionRef);
			
			TextExtractionStatus = Undefined;
			If Encrypt = False Then
				TextExtractionStatus = Enums.FileTextExtractionStatuses.NotExtracted;
			EndIf;	
			
			Version = UpdateVersion(
				FileRef, 
				False, //CreateVersion,
				TemporaryStorageAddress, 
				VersionRef.Comment, 
				VersionRef.CreationDate, 
				VersionRef.ModificationDateUniversal,
				VersionRef.Size, 
				VersionRef.Details, 
				VersionRef.Extension, 
				"", //FullFilePath,
				"", //TextTemporaryStorageAddress,
				False, //ThisIsWebClient,
				False, //TextNotExtractedAtClient,
				UUID,
				Encrypt, // Encrypted
				VersionRef,
				TextExtractionStatus);
				
		EndDo;	
		
		CommitTransaction();
	Except
	     RollbackTransaction();
	     Raise;
	EndTry;
	
	For Each FileAddress In AddressArray Do
		// for the variant when files are located on disk (at server) - delete file from temporary storage after getting it
		If IsTempStorageURL(FileAddress) Then
			DeleteFromTempStorage(FileAddress);
		EndIf;
	EndDo;	
	
EndProcedure	

// executes PutToTempStorage (if file is stored on disk) and returns required ref
Function GetURLToTemporaryStorage(VersionRef, FormID = Undefined) Export
	Address = "";
	
	FileStorageType = VersionRef.FileStorageType;
	
	If FileStorageType = Enums.FileStorageTypes.VolumesOnHardDisk Then
		If NOT VersionRef.Volume.IsEmpty() Then
			FullPath = VolumeFullPath(VersionRef.Volume) + VersionRef.FilePath; 
			Try
				BinaryData = New BinaryData(FullPath);
				Address = PutToTempStorage(BinaryData, FormID);
			Except
				// record to eventlog
				ErrorMessage = GenerateFileFromVolumeObtainingErrorTextForAdministrator(ErrorInfo(), VersionRef.Owner);
				WriteLogEvent("File opening", EventLogLevel.Error, Metadata.Catalogs.Files, VersionRef.Owner, ErrorMessage);
				
				Raise StringFunctionsClientServer.SubstitureParametersInString(
					NStr("en = 'File opening error: file not found at server. File could be deleted by antivirus software. Contact system administrator.
                          |File: %1.%2'"),
					VersionRef.Details,
					VersionRef.Extension);
			EndTry;
		EndIf;
	Else
		BinaryData = VersionRef.FileStorage.Get();
		Address = PutToTempStorage(BinaryData, FormID);
	EndIf;
	
	Return Address;
EndFunction // GetURLForOpening()

// puts version file into temp storage and gets FileData and VersionURL
Function GetFileDataAndVersionURLToTemporaryStorage(FileRef, VersionRef, FormID) Export
	
	FileData = FileOperations.GetFileData(FileRef, VersionRef);
	If VersionRef = Undefined Then
		VersionRef = FileRef.CurrentVersion;
	EndIf;	
	VersionURL = GetURLToTemporaryStorage(VersionRef, FormID);

	ReturnStructure = New Structure("FileData, VersionURL", FileData, VersionURL);
	
	Return ReturnStructure;
EndFunction

// Gets array of encryption certificates
Function GetEncryptionCertificatesArray(Ref) Export
	
	SetPrivilegedMode(True);
	Query = New Query;
	Query.Text = "SELECT
	             |	EncryptionCertificates.Presentation AS Presentation,
	             |	EncryptionCertificates.Imprint AS Imprint
	             |FROM
	             |	Catalog.Files.EncryptionCertificates AS EncryptionCertificates
	             |WHERE
	             |	EncryptionCertificates.Ref = &ObjectRef";
				   
	Query.Parameters.Insert("ObjectRef", Ref);
	QuerySelection = Query.Execute().Choose();
	
	EncryptionCertificatesArray = New Array;
	While QuerySelection.Next() Do
		ImprintStructure = New Structure("Imprint, Presentation",
			QuerySelection.Imprint, QuerySelection.Presentation);
		EncryptionCertificatesArray.Add(ImprintStructure);
	EndDo;
	
	SetPrivilegedMode(False);
	
	Return EncryptionCertificatesArray;

EndFunction			

// gets FileData and file itself as BinaryData
Function GetFileDataAndBinaryData(FileRef, VersionRef = Undefined, 
	SignatureAddress = Undefined) Export
	
	FileData = FileOperations.GetFileData(FileRef, VersionRef);
	If VersionRef = Undefined Then
		VersionRef = FileRef.CurrentVersion;
	EndIf;	
	
	BinaryData = Undefined;
	
	FileStorageType = VersionRef.FileStorageType;
	If FileStorageType = Enums.FileStorageTypes.VolumesOnHardDisk Then
		If Not VersionRef.Volume.IsEmpty() Then
			FullPath = VolumeFullPath(VersionRef.Volume) + VersionRef.FilePath; 
			Try
				BinaryData = New BinaryData(FullPath);
			Except
				// writing to event log
				ErrorMessage = GenerateFileFromVolumeObtainingErrorTextForAdministrator(ErrorInfo(), VersionRef.Owner);
				WriteLogEvent("File opening", EventLogLevel.Error, Metadata.Catalogs.Files, VersionRef.Owner, ErrorMessage);
				
				Raise StringFunctionsClientServer.SubstitureParametersInString(
					NStr("en = 'File opening error: file not found on server. File could be deleted by antivirus software. Contact system administrator.
                          |File: %1.%2'"),
					VersionRef.Details,
					VersionRef.Extension);
			EndTry;
		EndIf;
	Else
		BinaryData = VersionRef.FileStorage.Get();
	EndIf;

	BinaryDataSignatures = Undefined;
	If SignatureAddress <> Undefined Then
		BinaryDataSignatures = GetFromTempStorage(SignatureAddress);
	EndIf;	
	
	ReturnStructure = New Structure("FileData, BinaryData, BinaryDataSignatures", 
		FileData, BinaryData, BinaryDataSignatures);
	
	Return ReturnStructure;
EndFunction
