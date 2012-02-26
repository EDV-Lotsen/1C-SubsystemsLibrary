
////////////////////////////////////////////////////////////////////////////////
// EXPORT EXTERNAL PROCEDURES AND FUNCTIONS

// process one item on exchange  - send
Procedure OnSendFileData(DataItem, ItemSend, InitialImageCreating = False) Export
	
	If ItemSend = DataItemSend.Delete Then
		Return;
	EndIf;
	
	If TypeOf(DataItem) = Type("CatalogObject.FileVersions") Then
		
		If DataItem.FileStorageType = Enums.FileStorageTypes.VolumesOnHardDisk Then
			
			If InitialImageCreating = True Then
		
				If Not DataItem.Volume.IsEmpty() Then
					
					FilesDirectoryName = CommonSettingsStorage.Load("FileExchange", "TemporaryDirectory");
					
					FullPath = FileOperations.VolumeFullPath(DataItem.Volume) + DataItem.FilePath; 
					UUID = DataItem.Ref.UUID();
					
					NewFilePath = FilesDirectoryName + "/" + UUID;
					
					Try
						// if file is in volume - copy it to temporary directory (on initial image creation)
						FileCopy(FullPath, NewFilePath);
						TempFile = New File(NewFilePath);
						TempFile.SetReadOnly(False);
					Except
					EndTry;
					
				EndIf;	
				
			Else // normal exchange - InitialImageCreating = False
				
				If Not DataItem.Volume.IsEmpty() Then
					// if file is in volume - put it to FileStorage, and change DataItem.FileStorageType to Infobase
					
					FullPath = FileOperations.VolumeFullPath(DataItem.Volume) + DataItem.FilePath; 
					UUID 	 = DataItem.Ref.UUID();
				
					BinaryData = New BinaryData(FullPath);
					DataItem.FileStorage = New ValueStorage(BinaryData);
					
					DataItem.FileStorageType = Enums.FileStorageTypes.Infobase;
					DataItem.FilePath = "";
					DataItem.Volume = Catalogs.FileStorageVolumes.EmptyRef();
				EndIf;	
				
			EndIf;
			
		EndIf;
		
	EndIf;	
	
EndProcedure

// process one item on excgange  - receive
Procedure OnGetFileData(DataItem) Export
	
	If TypeOf(DataItem) = Type("CatalogObject.FileVersions") Then
		
		FileStorageType = GetFileStorageType();
		
		FormerPathOnVolume = "";
		
		If Not DataItem.IsNew() Then // existing item has been modified
			
			// file was on volume - delete it - because new one will arrive on exchange
			If DataItem.Ref.FileStorageType = Enums.FileStorageTypes.VolumesOnHardDisk Then
				FormerPathOnVolume = FileOperations.VolumeFullPath(DataItem.Ref.Volume) + DataItem.Ref.FilePath; 
				
				TempFile = New File(FormerPathOnVolume);
				TempFile.SetReadOnly(False);
				DeleteFiles(FormerPathOnVolume);
				
				PathWithSubdirectory  = TempFile.Path;
				FilesArrayInDirectory = FindFiles(PathWithSubdirectory, "*.*");
				If FilesArrayInDirectory.Count() = 0 Then
					DeleteFiles(PathWithSubdirectory);
				EndIf;
				
			EndIf;
		EndIf;
		
		// do nothing if DataItem.FileStorageType = Enums.FileStorageTypes.Infobase (receiver infobase
		// stores files in infobase) but if receiver base stores files on volumes placing it on a hard disk
		If FileStorageType = Enums.FileStorageTypes.VolumesOnHardDisk Then
			// if type differs from default type for current infobase changing it
			
			// on exchange item with storage in db has arrived - but in receiver base storage is done in volumes
			// - from FileStorage place on volume and change FileStorageType to VolumesOnHardDisk
			
			BinaryData = DataItem.FileStorage.Get();
			
			ModificationTime = DataItem.ModificationDateUniversal;
			FileSize  = DataItem.Size;
			BaseName  = DataItem.Description;
			Extension = DataItem.Extension;

			FilePathOnVolume = "";
			VolumeRef = Undefined;
			// add to one of the volumes (where is enough of space)
			FileOperations.AddToDisk(BinaryData, FilePathOnVolume, VolumeRef, ModificationTime, DataItem.VersionNo, BaseName, Extension, FileSize);
			DataItem.FilePath  	 = FilePathOnVolume;
			DataItem.Volume 		 = VolumeRef.Ref;
			DataItem.FileStorageType = Enums.FileStorageTypes.VolumesOnHardDisk;
			
			DataItem.FileStorage = New ValueStorage(""); // clear FileStorage
			
		EndIf;
			
	EndIf;	
	
EndProcedure


// Create file initial image at server
Function CreateFileModeInfobaseInitialImageAtServer(Node, FormUUID, Language, WindowsFileInfobaseFullName, LinuxFileInfobaseFullName, WindowsVolumeFilesArchivePath, LinuxVolumeFilesArchivePath) Export
	
	VolumeFilesArchivePath = "";
	FileInfobaseFullName = "";
	
	ServerPlatformType = FileOperationsSecondUse.ServerPlatformType();
	If ServerPlatformType = PlatformType.Windows_x86 Or ServerPlatformType = PlatformType.Windows_x86_64 Then
		VolumeFilesArchivePath = WindowsVolumeFilesArchivePath;
		FileInfobaseFullName = WindowsFileInfobaseFullName;
		
		If Not IsBlankString(VolumeFilesArchivePath) And (Left(VolumeFilesArchivePath, 2) <> "\\" OR Find(VolumeFilesArchivePath, ":") <> 0) Then
			ErrorText = NStr("en = 'Path to file base must be in the UNC format (\\servername\resource)'");
			CommonUseClientServer.MessageToUser(ErrorText, , "WindowsVolumeFilesArchivePath");
			Return False;
		EndIf;	
		
		If Not IsBlankString(FileInfobaseFullName) And (Left(FileInfobaseFullName, 2) <> "\\" OR Find(FileInfobaseFullName, ":") <> 0) Then
			ErrorText = NStr("en = 'Path to archive volume files must be in the UNC format (\\servername\resource)'");
			CommonUseClientServer.MessageToUser(ErrorText, , "WindowsFileInfobaseFullName");
			Return False;
		EndIf;	
		
	Else	
		VolumeFilesArchivePath = LinuxVolumeFilesArchivePath;
		FileInfobaseFullName = LinuxFileInfobaseFullName;
	EndIf;
	
	If IsBlankString(FileInfobaseFullName) Then
		
		Text = NStr("en = 'Specify full path of the infobase in File Mode (1cv8.1cd)'");
		CommonUseClientServer.MessageToUser(Text, , "WindowsFileInfobaseFullName");
		Return False;
	EndIf;	
	BaseFile = New File(FileInfobaseFullName);
	If BaseFile.Exist() Then
		Text = StringFunctionsClientServer.SubstitureParametersInString(
					NStr("en = 'The %1 file already exists. Specify a different file name.'"), FileInfobaseFullName);
		CommonUseClientServer.MessageToUser(Text, , "WindowsFileInfobaseFullName");
		Return False;
	EndIf;	
	
	If IsBlankString(VolumeFilesArchivePath) Then
		Text = NStr("en = 'Specify the full file path to the volume files archive (ZipWriter file)'");
		CommonUseClientServer.MessageToUser(Text, , "WindowsVolumeFilesArchivePath");
		Return False;
	EndIf;	
	
	FilePath = VolumeFilesArchivePath;
	File = New File(FilePath);
	If File.Exist() Then
		Text = StringFunctionsClientServer.SubstitureParametersInString(
					NStr("en = 'The %1 file already exists. Specify a different file name.'"), FilePath);
		CommonUseClientServer.MessageToUser(Text, , "WindowsVolumeFilesArchivePath");
		Return False;
	EndIf;	
	
	
	// create temporary directory
	DirectoryName = GetTempFileName();
	CreateDirectory(DirectoryName);
	
	// create temporary directory for files
	FilesDirectoryName = GetTempFileName();
	CreateDirectory(FilesDirectoryName);
	
	CommonSettingsStorage.Save("FileExchange", "TemporaryDirectory", FilesDirectoryName);
	
	ZipWriter = Undefined;
	Record = Undefined;
	
	Try
		
		ConnectionString = "File=""" + DirectoryName + """;" 
						 + "Locale=""" + Language + """;";
		ExchangePlans.CreateInitialImage(Node, ConnectionString);  // creating initial image
		
		ZipWriter = New ZipFileWriter;
		ZipFilePath = FilePath;
		ZipWriter.Open(ZipFilePath);
		
		TemporaryFiles = New Array;
		TemporaryFiles = FindFiles(FilesDirectoryName, "*.*");
		
		For Each TemporaryFile In TemporaryFiles Do
			If TemporaryFile.IsFile() Then
				TemporaryFilePath = TemporaryFile.FullName;
				ZipWriter.Add(TemporaryFilePath);
			EndIf;
		EndDo;
		
		ZipWriter.Write();
		
		DeleteFiles(FilesDirectoryName); // delete together with files inside
		
	Except
		
		DeleteFiles(DirectoryName);
		Raise;
		
	EndTry;
	
	BaseTemporaryFilePath = DirectoryName + "\1Cv8.1cd";
	MoveFile(BaseTemporaryFilePath, FileInfobaseFullName);
	
	// clearing
	DeleteFiles(DirectoryName);
	
	Return True;
EndFunction

// Create server initial image at server
Function CreateClientServerModeInfobaseInitialImageAtServer(Node, ConnectionString, WindowsVolumeFilesArchivePath, LinuxVolumeFilesArchivePath) Export
	
	VolumeFilesArchivePath = "";
	ServerPlatformType = FileOperationsSecondUse.ServerPlatformType();
	If ServerPlatformType = PlatformType.Windows_x86 Or ServerPlatformType = PlatformType.Windows_x86_64 Then
	   VolumeFilesArchivePath = WindowsVolumeFilesArchivePath;
		
		If Not IsBlankString(VolumeFilesArchivePath) And (Left(VolumeFilesArchivePath, 2) <> "\\" OR Find(VolumeFilesArchivePath, ":") <> 0) Then
			ErrorText = NStr("en = 'Path to File Mode infobase must be in the UNC format (\\servername\resource)'");
			CommonUseClientServer.MessageToUser(ErrorText, , "WindowsVolumeFilesArchivePath");
			Return False;
		EndIf;	
		
	Else	
		VolumeFilesArchivePath = LinuxVolumeFilesArchivePath;
	EndIf;
	
	If IsBlankString(VolumeFilesArchivePath) Then
		Text = NStr("en = 'Specify the full name of the volume files archive (ZIP file)'");
		CommonUseClientServer.MessageToUser(Text, , "WindowsVolumeFilesArchivePath");
		Return False;
	EndIf;	
	
	FilePath = VolumeFilesArchivePath;
	File = New File(FilePath);
	If File.Exist() Then
		Text = StringFunctionsClientServer.SubstitureParametersInString(
					NStr("en = 'The %1 file already exists. Specify a different file name.'"), FilePath);
		CommonUseClientServer.MessageToUser(Text);
		Return False;
	EndIf;	
	
	// create temporary directory
	DirectoryName = GetTempFileName();
	CreateDirectory(DirectoryName);
	
	// create temporary directory for files
	FilesDirectoryName = GetTempFileName();
	CreateDirectory(FilesDirectoryName);
	
	CommonSettingsStorage.Save("FileExchange", "TemporaryDirectory", FilesDirectoryName);
	
	ZipWriter = Undefined;
	Record = Undefined;
	
	Try
		
		ExchangePlans.CreateInitialImage(Node, ConnectionString);
		
		ZipWriter = New ZipFileWriter;
		ZipFilePath = FilePath;
		ZipWriter.Open(ZipFilePath);
		
		TemporaryFiles = New Array;
		TemporaryFiles = FindFiles(FilesDirectoryName, "*.*");
		
		For Each TemporaryFile In TemporaryFiles Do
			If TemporaryFile.IsFile() Then
				TemporaryFilePath = TemporaryFile.FullName;
				ZipWriter.Add(TemporaryFilePath);
			EndIf;
		EndDo;
		
		ZipWriter.Write();
		DeleteFiles(FilesDirectoryName); // delete together with files inside
		
	Except
		
		DeleteFiles(DirectoryName);
		Raise;
		
	EndTry;
	
	// clearing
	DeleteFiles(DirectoryName);
	
	Return True;
EndFunction

//If there is at least one files storage volume
Function AreFileStorageVolumes() Export
	
	FileStorageType = GetFileStorageType();
	
	If FileStorageType = Enums.FileStorageTypes.Infobase Then
		Return True; // don't check volumes availability here
	EndIf;		
	
	Selection = Catalogs.FileStorageVolumes.Select(,,, "FillSequence Asc");
	If Selection.Next() Then
		Return True;
	EndIf;	
	
	Return False;
EndFunction

// gets FileStorageType for the infobase
Function GetFileStorageType()
	SetPrivilegedMode(True);
	FileStorageType = Constants.FileStorageType.Get();
	Return FileStorageType;
EndFunction	

// Places files on volumes, writing refs in FileVersions
Function AddFilesToVolumes(PathToWindowsArchive, PathToLinuxArchive) Export
	
	FullZipFileName = "";
	ServerPlatformType = FileOperationsSecondUse.ServerPlatformType();
	If ServerPlatformType = PlatformType.Windows_x86 Or ServerPlatformType = PlatformType.Windows_x86_64 Then
		FullZipFileName = PathToWindowsArchive;
	Else
		FullZipFileName = PathToLinuxArchive;
	EndIf;	
	
	DirectoryName = GetTempFileName();
	CreateDirectory(DirectoryName);
	
	ZipWriter = New ZipFileReader(FullZipFileName);
	ZipWriter.ExtractAll(DirectoryName, ZIPRestoreFilePathsMode.DontRestore);
	
	FilePathMap = New Map;
	
	For Each ZipFile In ZipWriter.Items Do
		FullPathOfFile = DirectoryName + "/" + ZipFile.Name;
		UUID = ZipFile.BaseName;
		
		FilePathMap.Insert(UUID, FullPathOfFile);
	EndDo;
	
	FileStorageType = GetFileStorageType();
	
	BeginTransaction();
	Try
		Selection = Catalogs.FileVersions.Select();
		While Selection.Next() Do
			Object = Selection.GetObject();
			If Object.FileStorageType = Enums.FileStorageTypes.VolumesOnHardDisk Then
				
				UUID = String(Object.Ref.UUID());
				
				FileOnHardDiskFullPath = FilePathMap.Get(UUID);
				If FileOnHardDiskFullPath <> Undefined Then
					
					// in receiver-base files should be stored in infobase - thus, place them in this location (even if in source base they were stored on volumes)
					If FileStorageType = Enums.FileStorageTypes.Infobase Then
						
						Object.FileStorageType = Enums.FileStorageTypes.Infobase;
						Object.FilePath = "";
						Object.Volume = Catalogs.FileStorageVolumes.EmptyRef();
						
						BinaryData = New BinaryData(FileOnHardDiskFullPath);
						Object.FileStorage = New ValueStorage(BinaryData);
						
					Else // in receiver base files should be stored on volumes - move extracted file to the volume
						
						FileSrc = New File(FileOnHardDiskFullPath);
						FileSize = FileSrc.Size();
						
						ModificationTime = Object.ModificationDateUniversal;
						BaseName = Object.Description;
						Extension = Object.Extension;

						FullPathNew = FileSrc.Path + BaseName + "." + Object.Extension;
						MoveFile(FileOnHardDiskFullPath, FullPathNew);
						
						FilePathOnVolume = "";
						VolumeRef = Undefined;
						// add to one of the volumes (where is enough of space)
						FileOperations.AddToDisk(FullPathNew, FilePathOnVolume, VolumeRef, ModificationTime, Object.VersionNo, BaseName, Extension, FileSize);
						Object.FilePath = FilePathOnVolume;
						Object.Volume = VolumeRef.Ref;
						
					EndIf;	
					
					Object.Write();
					DeleteFiles(FullPathNew);
					
				EndIf;
				
			EndIf;	
		EndDo;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	// clear changes registration FileVersions, that we have just performed
	For Each ExchangePlan in Metadata.ExchangePlans Do
	    ExchangePlanName = ExchangePlan.Name;
	    ExchangePlanManager = ExchangePlans[ExchangePlanName];
		
		ThisNode  = ExchangePlanManager.ThisNode();	
		Selection = ExchangePlanManager.Choose();
		
		While Selection.Next() Do
			ExchangePlanObject = Selection.GetObject();
			If ExchangePlanObject.Ref <> ThisNode Then
				ExchangePlans.DeleteChangeRecords(ExchangePlanObject.Ref, Metadata.Catalogs.FileVersions);
			EndIf;	
		EndDo;
		
	EndDo;
	
EndFunction
