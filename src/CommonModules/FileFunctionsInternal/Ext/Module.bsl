////////////////////////////////////////////////////////////////////////////////
// File functions subsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region InternalInterface

// Declares internal events of the FileFunctions subsystem.
//
// Server events:
//   OnAddFilesToVolumesOnPut,
//   OnDeleteChangeRecords,
//   OnDefineQueryTextForTextExtraction,
//   OnDetermineCountOfVersionsWithUnextractedText,
//   OnWriteExtractedText,
//   OnDetermineFilesInVolumesCount,
//   OnDetermineStoredFilesPresence,
//   OnGetStoredFiles,
//   OnDefineFileURL,
//   OnDetermineFileNameWithPathToBinaryData,
//   OnDetermineFileAndSignatureBinaryData.
//
// See the description of this procedure in the StandardSubsystemsServer module.
Procedure OnAddInternalEvent(ClientEvents, ServerEvents) Export
	
	// SERVER EVENTS
	
	// Adds a file to a volume when the "Store initial image files" event occurs
	//
	// Syntax:
	// Procedure OnAddFilesToVolumesOnPut (FilePathMapping, StoreFilesInVolumesOnHardDisk, FilesToAttach) Export
	//
	ServerEvents.Add("StandardSubsystems.FileFunctions\OnAddFilesToVolumesOnPut");
	
	// Deletes change records after the "Store initial image files" event.
	//
	// Syntax:
	// Procedure OnDeleteChangeRecords (ExchangePlanRef, FilesToAttach) Export
	//
	ServerEvents.Add("StandardSubsystems.FileFunctions\OnDeleteChangeRecords");
	
	// Fills the query text for getting files with unextracted text.
	// The procedure can get another query as a parameter, then both queries should be united.
	//
	// Parameters:
	//  QueryText  - String (return value), one of the following:
	//                   Empty string    - the query text is returned.
	//                   Nonempty string - the query texts are combined by means of 
	//                                     UNION ALL, the resulting query text is returned.
	// 
	//  GetAllFiles - Boolean - the initial value is False. If True, disables 
//                  individual file selection.
	//
	// Syntax:
	// Procedure OnDefineQueryTextForTextExtraction(QueryText, GetAllFiles = False) Expot
	//
	ServerEvents.Add("StandardSubsystems.FileFunctions\OnDefineQueryTextForTextExtraction");
	
	// Returns the number of files with unextracted text.
	//
	// Syntax:
	// Procedure OnDetermineCountOfVersionsWithUnextractedText(VersionCount) Export
	//
	ServerEvents.Add("StandardSubsystems.FileFunctions\OnDetermineCountOfVersionsWithUnextractedText");
	
	// Writes the extracted text.
	//
	// Syntax:
	// Procedure OnWriteExtractedText(FileObject) Export
	//
	ServerEvents.Add("StandardSubsystems.FileFunctions\OnWriteExtractedText");
	
	// Returns the number of files in volumes in the CountOfFilesInVolumes parameter.
	//
	// Syntax:
	// Procedure OnDetermineFilesInVolumesCount(CountOfFilesInVolumes) Export
	//
	ServerEvents.Add("StandardSubsystems.FileFunctions\OnDetermineFilesInVolumesCount");
	
	// Returns True in the HasStoredFiles parameter if there are stored files related to ExternalObject object.
	//
	// Syntax:
	// Procedure OnDetermineStoredFilesPresence(ExternalObject, HasStoredFiles) Export
	//
	ServerEvents.Add("StandardSubsystems.FileFunctions\OnDetermineStoredFilesPresence");
	
	// Returns the array of stored files related to ExternalObject object in the StoredFiles parameter.
	//
	// Syntax:
	// Procedure OnGetStoredFiles(ExternalObject, StoredFiles) Export
	//
	ServerEvents.Add("StandardSubsystems.FileFunctions\OnGetStoredFiles");
	
	// Returns the file URL (a reference to a file attribute or a temporary storage).
	//
	// Syntax:
	// Procedure OnDefineFileURL(FileRef, UUID, URL) Export
	//
	ServerEvents.Add("StandardSubsystems.FileFunctions\OnDefineFileURL");
	
	// Gets a full path to a file on the hard disk.
	//
	// Syntax:
	// Procedure OnDetermineFileNameWithPathToBinaryData(FileRef, PathToFile) Export
	//
	ServerEvents.Add("StandardSubsystems.FileFunctions\OnDetermineFileNameWithPathToBinaryData");
	
	// Returns a structure with file and signature binary data.
	//
	// Syntax:
	// Procedure OnDetermineFileAndSignatureBinaryData(RowData, FileAndSignatureData) Export
	//
	ServerEvents.Add("StandardSubsystems.FileFunctions\OnDetermineFileAndSignatureBinaryData");
	
EndProcedure

// See the description of this procedure in the StandardSubsystemsServer module.
Procedure InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers) Export
	
	// SERVER HANDLERS
	
	ServerHandlers[
		"StandardSubsystems.InfobaseVersionUpdate\OnAddUpdateHandlers"].Add(
			"FileFunctionsInternal");
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaSOperations.JobQueue") Then
		ServerHandlers[
			"StandardSubsystems.SaaSOperations.JobQueue\OnDetermineScheduledJobsUsed"].Add(
				"FileFunctionsInternal");
	EndIf;
	
	ServerHandlers[
		"StandardSubsystems.BaseFunctionality\StandardSubsystemClientLogicParametersOnAdd"].Add(
			"FileFunctionsInternal");
	
	ServerHandlers[
		"StandardSubsystems.BaseFunctionality\ExchangePlanObjectsToExcludeOnGet"].Add(
			"FileFunctionsInternal");
	
	ServerHandlers[
		"StandardSubsystems.BaseFunctionality\OnFillPermissionsToAccessExternalResources"].Add(
			"FileFunctionsInternal");
	
	If CommonUse.SubsystemExists("CloudTechnology.DataImportExport") Then
		ServerHandlers[
			"CloudTechnology.DataImportExport\OnFillCommonDataTypesDoNotRequireMappingRefsOnImport"].Add(
				"FileFunctionsInternal");
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Standard application programming interface

// Fills the parameter structures required by the client configuration code. 
//
// Parameters:
//   Parameters - Structure - parameter structure.
//
Procedure AddClientParameters(Parameters) Export
	
	If Not CommonUseCached.CanUseSeparatedData() Then
		Return;
	EndIf;
	
	FileOperationSettings = FileFunctionsInternalCached.FileOperationSettings();
	
	Parameters.Insert("PersonalFileOperationSettings", New FixedStructure(
		FileOperationSettings.PersonalSettings));
	
	Parameters.Insert("CommonFileOperationSettings", New FixedStructure(
		FileOperationSettings.CommonSettings));
		
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// File exchange support

// For internal use. Deletes files from the server.
// 
Procedure DeleteFilesAtServer(OldPathToVolume) Export
	
	// Deleting file
	TemporaryFile = New File(OldPathToVolume);
	If TemporaryFile.Exist() Then
		
		Try
			TemporaryFile.SetReadOnly(False);
			DeleteFiles(OldPathToVolume);
		Except
			WriteLogEvent(
				NStr("en = 'Files.Delete files from a volume during the exchange'",
				     CommonUseClientServer.DefaultLanguageCode()),
				EventLogLevel.Error,
				,
				,
				ErrorInfo());
		EndTry;
		
	EndIf;
	
	// Deleting the file directory if the directory is empty after the file deletion
	Try
		FileArrayInDirectory = FindFiles(TemporaryFile.Path, "*.*");
		If FileArrayInDirectory.Count() = 0 Then
			DeleteFiles(TemporaryFile.Path);
		EndIf;
	Except
		WriteLogEvent(
			NStr("en = 'Files.Delete files from a volume during the exchange'",
			     CommonUseClientServer.DefaultLanguageCode()),
			EventLogLevel.Error,
			,
			,
			ErrorInfo() );
	EndTry;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Managing file volumes

// Returns the file storage type.
// 
// Returns:
//  Boolean. If True, files are stored in volumes on the hard disk.
//
Function StoreFilesInVolumesOnHardDisk() Export
	
	SetPrivilegedMode(True);
	
	StoreFilesInVolumesOnHardDisk = Constants.StoreFilesInVolumesOnHardDisk.Get();
	
	Return StoreFilesInVolumesOnHardDisk;
	
EndFunction

// Returns the file storage type, which shows whether the files are stored in volumes.
// If there are no file storage volumes, files are stored in the infobase.
//
// Returns:
//  EnumRef.FileStorageTypes.
//
Function FileStorageType() Export
	
	SetPrivilegedMode(True);
	
	StoreFilesInVolumesOnHardDisk = Constants.StoreFilesInVolumesOnHardDisk.Get();
	
	If StoreFilesInVolumesOnHardDisk Then
		
		If FileFunctions.HasFileStorageVolumes() Then
			Return Enums.FileStorageTypes.InVolumesOnHardDisk;
		Else
			Return Enums.FileStorageTypes.InInfobase;
		EndIf;
		
	Else
		Return Enums.FileStorageTypes.InInfobase;
	EndIf;

EndFunction

// Checks whether there is at least one file in one of the volumes.
//
// Returns:
//  Boolean.
//
Function HasFilesInVolumes() Export
	
	If CountOfFilesInVolumes() <> 0 Then
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

// Returns the full volume path, OS-dependent
Function VolumeFullPath(VolumeRef) Export
	
	ServerPlatformType = CommonUseCached.ServerPlatformType();
	
	If ServerPlatformType = PlatformType.Windows_x86
	 Or ServerPlatformType = PlatformType.Windows_x86_64 Then
		
		Return VolumeRef.WindowsFullPath;
	Else
		Return VolumeRef.LinuxFullPath;
	EndIf;
	
EndFunction

// Adds a file to one of the volumes (that has free space).
Procedure AddOnHardDisk(
		BinaryData,
		PathToFileInVolume,
		VolumeRef,
		ModifiedUniversalTime,
		VersionNumber,
		BaseName,
		Extension,
		FileSize = 0,
		Encrypted = False,
		PutInVolumeDate = Undefined) Export
	
	SetPrivilegedMode(True);
	
	VolumeRef = Catalogs.FileStorageVolumes.EmptyRef();
	
	BriefDescriptionOfAllErrors   = ""; // Errors from all volumes
	DetailedDescriptionOfAllErrors = ""; // For the event log
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	FileStorageVolumes.Ref
		|FROM
		|	Catalog.FileStorageVolumes AS FileStorageVolumes
		|WHERE
		|	FileStorageVolumes.DeletionMark = FALSE
		|
		|ORDER BY
		|	FileStorageVolumes.FillOrder";

	Selection = Query.Execute().Select();
	
	If Selection.Count() = 0 Then
		Raise NStr("en = 'There is no volume available for storing the file.'");
	EndIf;
	
	While Selection.Next() Do
		
		VolumeRef = Selection.Ref;
		
		PathToVolume = VolumeFullPath(VolumeRef);
		// Adding a trailing slash if it is not there
		PathToVolume = CommonUseClientServer.AddFinalPathSeparator(PathToVolume);
		
		// Generating the name of the file to be stored on the hard disk as follows:
		// file name.version number.file extension
		If IsBlankString(VersionNumber) Then
			FileName = BaseName + "." + Extension;
		Else
			FileName = BaseName + "." + VersionNumber + "." + Extension;
		EndIf;
		
		If Encrypted Then
			FileName = FileName + "." + "p7m";
		EndIf;
		
		Try
			
			// If MaxSize = 0, the size of files stored in a volume is not limited.
			If VolumeRef.MaxSize <> 0 Then
				
				CurrentSizeInBytes = 0;
				
				VolumeFilesSizeOnDefine(VolumeRef.Ref, CurrentSizeInBytes);
				
				NewSizeInBytes = CurrentSizeInBytes + FileSize;
				NewSize = NewSizeInBytes / (1024 * 1024);
				
				If NewSize > VolumeRef.MaxSize Then
					
					Raise StringFunctionsClientServer.SubstituteParametersInString(
						NStr("en = 'The maximum volume size (%1 MB) is exceeded.'"),
						VolumeRef.MaxSize);
				EndIf;
			EndIf;
			
			Date = CurrentSessionDate();
			If PutInVolumeDate <> Undefined Then
				Date = PutInVolumeDate;
			EndIf;
			
			// The use of the absolute date format "DF" in the next line is correct, 
     // as the date is not meant for user view.
			DayPath = Format(Date, "DF=yyyyMMdd") + CommonUseClientServer.PathSeparator();
			
			PathToVolume = PathToVolume + DayPath;
			
			FileNameWithPath = FileFunctionsInternalClientServer.GetUniqueNameWithPath(PathToVolume, FileName);
			FullFileNameWithPath = PathToVolume + FileNameWithPath;
			
			If TypeOf(BinaryData) = Type("BinaryData") Then
				BinaryData.Write(FullFileNameWithPath);
			ElsIf TypeOf(BinaryData) = Type("String") Then // Otherwise this is a path to a file on the hard disk
				FileCopy(BinaryData, FullFileNameWithPath);
			Else
				ExceptionString = NStr("en = 'Invalid data type to add to the volume'");
				Raise(ExceptionString);
			EndIf;
			
			// Setting file change time equal to the change time of current version
			FileOnHardDisk = New File(FullFileNameWithPath);
			FileOnHardDisk.SetModificationUniversalTime(ModifiedUniversalTime);
			FileOnHardDisk.SetReadOnly(True);
			
			PathToFileInVolume = DayPath + FileNameWithPath;
			Return; // Finished, exiting the procedure
			
		Except
			ErrorInfo = ErrorInfo();
			
			If DetailedDescriptionOfAllErrors <> "" Then
				DetailedDescriptionOfAllErrors = DetailedDescriptionOfAllErrors + Chars.LF + Chars.LF;
				BriefDescriptionOfAllErrors   = BriefDescriptionOfAllErrors   + Chars.LF + Chars.LF;
			EndIf;
			
			ErrorDescriptionTemplate =
				NStr("en = 'Error when adding file %1
				           |to volume %2 (%3):
				           |%4.'");
			
			DetailedDescriptionOfAllErrors = DetailedDescriptionOfAllErrors
				+ StringFunctionsClientServer.SubstituteParametersInString(
					ErrorDescriptionTemplate,
					FileName,
					String(VolumeRef),
					PathToVolume,
					DetailErrorDescription(ErrorInfo));
			
			BriefDescriptionOfAllErrors = BriefDescriptionOfAllErrors
				+ StringFunctionsClientServer.SubstituteParametersInString(
					ErrorDescriptionTemplate,
					FileName,
					String(VolumeRef),
					PathToVolume,
					BriefErrorDescription(ErrorInfo));
			
			// Should move to the next volume
			Continue;
		EndTry;
		
	EndDo;
	
	SetPrivilegedMode(False);
	
	// Writing an event log record for the administrator,
	// it includes the errors from all volumes
	ErrorMessageTemplate =
		NStr("en = 'Cannot add the file to any of the volumes.
		           |Errors:
		           |
		           |%1'");
	
	WriteLogEvent(
		NStr("en = 'Files.Add file'",
		     CommonUseClientServer.DefaultLanguageCode()),
		EventLogLevel.Error,
		,
		,
		StringFunctionsClientServer.SubstituteParametersInString(
			ErrorMessageTemplate,
			DetailedDescriptionOfAllErrors));
	
	If Users.InfobaseUserWithFullAccess() Then
		ExceptionString = StringFunctionsClientServer.SubstituteParametersInString(
			ErrorMessageTemplate,
			BriefDescriptionOfAllErrors);
	Else
		// Message to end user
		ExceptionString = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Cannot add the file:
			           |%1.%2.
			           |
			           |Contact the application administrator.'"),
			BaseName, Extension);
	EndIf;
	
	Raise ExceptionString;

EndProcedure

// Returns the number of files stored in volumes.
Function CountOfFilesInVolumes() Export
	
	CountOfFilesInVolumes = 0;
	
	EventHandlers = CommonUse.InternalEventHandlers(
		"StandardSubsystems.FileFunctions\OnDetermineFilesInVolumesCount");
	
	For Each Handler In EventHandlers Do
		Handler.Module.OnDetermineFilesInVolumesCount(CountOfFilesInVolumes);
	EndDo;
	
	Return CountOfFilesInVolumes;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Digital signatures for files

// Verifies signatures in collection rows.
//
// Parameters:
//  RowCollection - Array, FormDataCollection, or similar type
//                  with elements containing the following properties:
//                     Object           - file or attached file.
//                     Status           - String.
//                     Incorrect        - Boolean.
//                     SignatureAddress - String - signature address 
//                                        in temporary storage.
//
Procedure VerifySignaturesInCollectionRows(RowCollection) Export
	
	SetPrivilegedMode(True);
	//PARTIALLY_DELETED
	//CryptoManager = DigitalSignature.GetCryptoManager();
	CryptoManager = Undefined;
	SetPrivilegedMode(False);
	
	If CryptoManager = Undefined Then
		Return;
	EndIf;
	
	For Each Row In RowCollection Do
		
		If Row.Object <> Undefined
		   And Not Row.Object.IsEmpty() Then
			
			VerifySingleSignatureAtServer(Row, CryptoManager);
		EndIf;
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Other functions

// Returns True if the file text is extracted on the server (not on the client).
//
// Returns:
//  Boolean. If False, the text is not extracted on the server,
//                   in other words, it can and should be extracted on the client.
//
Function ExtractFileTextsAtServer() Export
	
	SetPrivilegedMode(True);
	
	Return Constants.ExtractFileTextsAtServer.Get();
	
EndFunction

// Returns True if the server is running on Windows.
Function IsWindowsPlatform() Export
	
	ServerPlatformType = CommonUseCached.ServerPlatformType();
	
	If ServerPlatformType = PlatformType.Windows_x86
	 Or ServerPlatformType = PlatformType.Windows_x86_64 Then
		Return True;
	Else
		Return False;
	EndIf;
	
EndFunction

// Gets a string from a temporary storage (data transfer from client to server
// through a temporary storage).
//
Function GetRowFromTemporaryStorage(TempTextStorageAddress) Export
	
	If IsBlankString(TempTextStorageAddress) Then
		Return "";
	EndIf;
	
	TempFileName = GetTempFileName();
	GetFromTempStorage(TempTextStorageAddress).Write(TempFileName);
	
	TextFile = New TextReader(TempFileName, TextEncoding.UTF8);
	Text = TextFile.Read();
	TextFile.Close();
	DeleteFiles(TempFileName);
	
	Return Text;
	
EndFunction

// For internal use. Stores file binary data contained in a volume to a value storage.
//
Function PutBinaryDataInStorage(Volume, PathToFile, UUID) Export
	
	FullPath = VolumeFullPath(Volume) + PathToFile;
	UUID = UUID;
	
	BinaryData = New BinaryData(FullPath);
	Return New ValueStorage(BinaryData);
	
EndFunction

// For internal use. The procedure is used during the creation of initial images.
// It is always executed on the server.
//
Procedure CopyFileOnCreateInitialImage(FullPath, NewFilePath) Export
	
	Try
		// If the file is in a volume, copying it to the temporary directory (during the creation of an initial image)
		FileCopy(FullPath, NewFilePath);
		TemporaryFile = New File(NewFilePath);
		TemporaryFile.SetReadOnly(False);
	Except
		// Cannot register, possibly the file is not found
	EndTry;
	
EndProcedure

// Records text extraction result, which includes extracted text and TextExtractionStatus, to the server.
Procedure RecordTextExtractionResult(FileOrVersionRef,
                                            ExtractionResult,
                                            TempTextStorageAddress) Export
	
	FileOrVersionObject = FileOrVersionRef.GetObject();
	FileOrVersionObject.Lock();
	
	If IsBlankString(TempTextStorageAddress) Then
		Text = "";
	Else
		Text = GetRowFromTemporaryStorage(TempTextStorageAddress);
		FileOrVersionObject.TextStorage = New ValueStorage(Text);
		DeleteFromTempStorage(TempTextStorageAddress);
	EndIf;
	
	If ExtractionResult = "NotExtracted" Then
		FileOrVersionObject.TextExtractionStatus = Enums.FileTextExtractionStatuses.NotExtracted;
	ElsIf ExtractionResult = "Extracted" Then
		FileOrVersionObject.TextExtractionStatus = Enums.FileTextExtractionStatuses.Extracted;
	ElsIf ExtractionResult = "FailedExtraction" Then
		FileOrVersionObject.TextExtractionStatus = Enums.FileTextExtractionStatuses.FailedExtraction;
	EndIf;
	
	EventHandlers = CommonUse.InternalEventHandlers(
		"StandardSubsystems.FileFunctions\OnWriteExtractedText");
	
	For Each Handler In EventHandlers Do
		Handler.Module.OnWriteExtractedText(FileOrVersionObject);
	EndDo;
	
EndProcedure

// Returns True if there are stored files related to ExternalObject object.
Function HasStoredFiles(ExternalObject) Export
	
	Result = False;
	
	EventHandlers = CommonUse.InternalEventHandlers(
		"StandardSubsystems.FileFunctions\OnDetermineStoredFilesPresence");
	
	For Each Handler In EventHandlers Do
		Handler.Module.OnDetermineStoredFilesPresence(ExternalObject, Result);
	EndDo;
	
	Return Result;
	
EndFunction

// Returns the stored files related to ExternalObject object.
//
Function GetStoredFiles(ExternalObject) Export
	
	DataArray = New Array;
	
	EventHandlers = CommonUse.InternalEventHandlers(
		"StandardSubsystems.FileFunctions\OnGetStoredFiles");
	
	For Each Handler In EventHandlers Do
		Handler.Module.OnGetStoredFiles(ExternalObject, DataArray);
	EndDo;
	
	Return DataArray;
	
EndFunction

// Gets the text file encoding specified by the user (if possible).
//
// Parameters:
//  FileVersion - reference to a file version.
//
// Returns:
//  String - text encoding ID, or an empty string.
//
Function GetFileVersionEncoding(FileVersion) Export
	
	Encoding = "";
	OnDetermineFileVersionEncoding(FileVersion, Encoding);
	
	Return Encoding;
	
EndFunction

#EndRegion

#Region InternalProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Internal event handlers of SL subsystems

// Adds update handlers that are required by the subsystem.
//
// Parameters:
//  Handlers - ValueTable - see the description of NewUpdateHandlerTable function in the InfobaseUpdate common module.
// 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.1.6";
	Handler.Procedure = "FileFunctionsInternal.MoveExtensionConstants";
	
EndProcedure	

// Generates a scheduled job table with flags that show whether a job is used in SaaS mode.
//
// Parameters:
// UsageTable    - ValueTable - table to be filled with scheduled jobs with usage flags. 
// It contains the following columns:
//  ScheduledJob - String     - predefined scheduled job name.
//  Use          - Boolean    - True if the scheduled job must be executed in SaaS mode. False otherwise.
//
Procedure OnDetermineScheduledJobsUsed(UsageTable) Export
	
	NewRow = UsageTable.Add();
	NewRow.ScheduledJob = "TextExtraction";
	NewRow.Use       = False;
	
EndProcedure

// Fills the parameter structures required by the client configuration code.
//
// Parameters:
//   Parameters - Structure - parameter structure.
//
Procedure StandardSubsystemClientLogicParametersOnAdd(Parameters) Export
	
	AddClientParameters(Parameters);
	
EndProcedure

// The procedure is used when getting metadata objects that must not be included in the exchange plan content.
// If the subsystem includes metadata objects that must not be included in the exchange plan content,
// add these metadata objects to the Objects parameter.
//
// Parameters:
// Objects - Array. The array of configuration metadata objects that should not be included in the exchange plan content.
// DistributedInfobase (read only) - Boolean. Flag that shows whether DIB exchange plan objects are retrieved.
// True    - the list of objects to be excluded from a DIB exchange plan is retrieved.
// False   - the list of non-DIB exchange plan objects is retrieved.
//
Procedure ExchangePlanObjectsToExcludeOnGet(Objects, Val DistributedInfobase) Export
	
	Objects.Add(Metadata.Constants.ExtractFileTextsAtServer);
	Objects.Add(Metadata.Constants.StoreFilesInVolumesOnHardDisk);
	
	Objects.Add(Metadata.Catalogs.FileStorageVolumes);
	
EndProcedure

// Fills a list of requests for external permissions that must be granted when an infobase is created or an application is updated.
//
// Parameters:
//  PermissionRequests - Array - list of values returned by
//                       SafeMode.RequestToUseExternalResources() method.
//
Procedure OnFillPermissionsToAccessExternalResources(PermissionRequests) Export
	
	If GetFunctionalOption("StoreFilesInVolumesOnHardDisk") Then
		Catalogs.FileStorageVolumes.AddRequestsToUseAllVolumesExternalResources(PermissionRequests);
	EndIf;
	
EndProcedure

// Fills the array of shared data types that do not require reference mapping
// during data import to another infobase, as the correct reference mapping
// is provided by other algorithms.
//
// Parameters:
//  Types - Array (MetadataObject).
//
Procedure OnFillCommonDataTypesDoNotRequireMappingRefsOnImport(Types) Export
	
	// During data export the references to the FileStorageVolumes catalog are cleared,
	// and during data import the import is performed according to the volume settings of the infobase
	// to which the data is imported (not according to the volume settings of the infobase from which
	// the data is exported).
	Types.Add(Metadata.Catalogs.FileStorageVolumes);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// File exchange

// Creates an initial image of a file infobase on the server.
//
Function CreateFileInitialImageAtServer(Node, FormUUID, Language, WindowsFullFileInfobaseName, LinuxFullFileInfobaseName, WindowsPathToVolumeFilesArchive, LinuxPathToVolumeFilesArchive) Export
	
	// Checking exchange plan content
	StandardSubsystemsServer.ValidateExchangePlanContent(Node);
	
	PathToVolumeFilesArchive = "";
	FullFileInfobaseName = "";
	
	HasFilesInVolumes = False;
	
	If FileFunctions.HasFileStorageVolumes() Then
		HasFilesInVolumes = HasFilesInVolumes();
	EndIf;
	
	ServerPlatformType = CommonUseCached.ServerPlatformType();
	
	If ServerPlatformType = PlatformType.Windows_x86 Or ServerPlatformType = PlatformType.Windows_x86_64 Then
		
		PathToVolumeFilesArchive = WindowsPathToVolumeFilesArchive;
		FullFileInfobaseName = WindowsFullFileInfobaseName;
		
		ClientParameters = StandardSubsystemsServerCall.ClientParameters();
		If Not ClientParameters.FileInfobase Then
			If HasFilesInVolumes Then
				
				If Not IsBlankString(PathToVolumeFilesArchive)
				   And (Left(PathToVolumeFilesArchive, 2) <> "\\"
				 Or Find(PathToVolumeFilesArchive, ":") <> 0) Then
					
					CommonUseClientServer.MessageToUser(
						NStr("en = 'The path to the archive of volume files
						           |should have the UNC format (\\servername\resource)'"),
						,
						"WindowsPathToVolumeFilesArchive");
					Return False;
				EndIf;
			EndIf;
		EndIf;
		
		If Not ClientParameters.FileInfobase Then
			If Not IsBlankString(FullFileInfobaseName) And (Left(FullFileInfobaseName, 2) <> "\\" Or Find(FullFileInfobaseName, ":") <> 0) Then
				
				CommonUseClientServer.MessageToUser(
					NStr("en = 'The path to the file infobase
					           |should have the UNC format (\\servername\resource)'"),
					,
					"WindowsFullFileInfobaseName");
				Return False;
			EndIf;
		EndIf;
		
	Else
		PathToVolumeFilesArchive = LinuxPathToVolumeFilesArchive;
		FullFileInfobaseName = LinuxFullFileInfobaseName;
	EndIf;
	
	If IsBlankString(FullFileInfobaseName) Then
		
		CommonUseClientServer.MessageToUser(
			NStr("en = 'Specify the full name of the file infobase (1cv8.1cd file)'"),
			,
			"WindowsFullFileInfobaseName");
		
		Return False;
		
	EndIf;
	
	InfobaseFile = New File(FullFileInfobaseName);
	
	If InfobaseFile.Exist() Then
		CommonUseClientServer.MessageToUser(
			StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'File name %1 is not unique.
				           |Enter another file name.'"),
				FullFileInfobaseName),
			,
			"WindowsFullFileInfobaseFullName");
		Return False;
	EndIf;
	
	If HasFilesInVolumes Then
		
		If IsBlankString(PathToVolumeFilesArchive) Then
			CommonUseClientServer.MessageToUser(
				NStr("en = 'Specify the full name of the archive with volume files (it is a *.zip file)'"),
				,
				"WindowsPathToVolumeFilesArchive");
			Return False;
		EndIf;
		
		File = New File(PathToVolumeFilesArchive);
		
		If File.Exist() Then
			CommonUseClientServer.MessageToUser(
				StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'File name %1 is not unique.
					           |Enter another file name.'"),
					PathToVolumeFilesArchive),
				,
				"WindowsPathToVolumeFilesArchive");
			Return False;
		EndIf;
		
	EndIf;
	
	// Creating a temporary directory
	DirectoryName = GetTempFileName();
	CreateDirectory(DirectoryName);
	
	// Creating a temporary file directory
	FileDirectoryName = GetTempFileName();
	CreateDirectory(FileDirectoryName);
	
	// This is intentional, for passing the file directory path to OnSendFileData handler.
	CommonSettingsStorageSaveInPrivilegedMode("FileExchange", "TemporaryDirectory", FileDirectoryName);
	
	ZIP = Undefined;
	Write = Undefined;
	
	Try
		
		ConnectionString = "File=""" + DirectoryName + """;"
						 + "Locale=""" + Language + """;";
		ExchangePlans.CreateInitialImage(Node, ConnectionString);  // Actual creation of the initial image
		
		If HasFilesInVolumes Then
			ZIP = New ZipFileWriter;
			ZIP.Open(PathToVolumeFilesArchive);
			
			TemporaryFiles = New Array;
			TemporaryFiles = FindFiles(FileDirectoryName, "*.*");
			
			For Each TempFile In TemporaryFiles Do
				If TempFile.IsFile() Then
					TemporaryFilePath = TempFile.FullName;
					ZIP.Add(TemporaryFilePath);
				EndIf;
			EndDo;
			
			ZIP.Write();
			
			DeleteFiles(FileDirectoryName); // Deleting along with all the files inside
		EndIf;
		
	Except
		
		DeleteFiles(DirectoryName);
		Raise;
		
	EndTry;
	
	TemporaryInfobaseFilePath = DirectoryName + "\1Cv8.1CD";
	MoveFile(TemporaryInfobaseFilePath, FullFileInfobaseName);
	
	// Clearing
	DeleteFiles(DirectoryName);
	
	Return True;
	
EndFunction

// Creates an initial image of a client/server infobase on the server.
//
Function CreateServerInitialImageAtServer(Node, ConnectionString, WindowsPathToVolumeFilesArchive, LinuxPathToVolumeFilesArchive) Export
	
	// Checking exchange plan content
	StandardSubsystemsServer.ValidateExchangePlanContent(Node);
	
	PathToVolumeFilesArchive = "";
	FullFileInfobaseName = "";
	
	HasFilesInVolumes = False;
	
	If FileFunctions.HasFileStorageVolumes() Then
		HasFilesInVolumes = HasFilesInVolumes();
	EndIf;
	
	ServerPlatformType = CommonUseCached.ServerPlatformType();
	
	If ServerPlatformType = PlatformType.Windows_x86 Or ServerPlatformType = PlatformType.Windows_x86_64 Then
		
		PathToVolumeFilesArchive = WindowsPathToVolumeFilesArchive;
		
		If HasFilesInVolumes Then
			If Not IsBlankString(PathToVolumeFilesArchive)
			   And (Left(PathToVolumeFilesArchive, 2) <> "\\"
			 Or Find(PathToVolumeFilesArchive, ":") <> 0) Then
				
				CommonUseClientServer.MessageToUser(
					NStr("en = 'The path to the archive of volume files
					           |should have the UNC format (\\servername\resource).'"),
					,
					"WindowsPathToVolumeFilesArchive");
				Return False;
			EndIf;
		EndIf;
		
	Else
		PathToVolumeFilesArchive = LinuxPathToVolumeFilesArchive;
	EndIf;
	
	If HasFilesInVolumes Then
		If IsBlankString(PathToVolumeFilesArchive) Then
			CommonUseClientServer.MessageToUser(
				NStr("en = 'Specify the full name of the archive with volume files (it is a *.zip file)'"),
				,
				"WindowsPathToVolumeFilesArchive");
			Return False;
		EndIf;
		
		FilePath = PathToVolumeFilesArchive;
		File = New File(FilePath);
		If File.Exist() Then
			CommonUseClientServer.MessageToUser(
				StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'File name %1 is not unique.
					           |Enter another file name.'"),
					FilePath));
			Return False;
		EndIf;
	EndIf;
	
	// Creating a temporary directory
	DirectoryName = GetTempFileName();
	CreateDirectory(DirectoryName);
	
	// Creating a temporary file directory
	FileDirectoryName = GetTempFileName();
	CreateDirectory(FileDirectoryName);
	
	// This is intentional, for passing the file directory path to OnSendFileData handler
	CommonSettingsStorageSaveInPrivilegedMode("FileExchange", "TemporaryDirectory", FileDirectoryName);
	
	ZIP = Undefined;
	Write = Undefined;
	
	Try
		
		ExchangePlans.CreateInitialImage(Node, ConnectionString);
		
		If HasFilesInVolumes Then
			ZIP = New ZipFileWriter;
			ZIPPath = FilePath;
			ZIP.Open(ZIPPath);
			
			TemporaryFiles = New Array;
			TemporaryFiles = FindFiles(FileDirectoryName, "*.*");
			
			For Each TempFile In TemporaryFiles Do
				If TempFile.IsFile() Then
					TemporaryFilePath = TempFile.FullName;
					ZIP.Add(TemporaryFilePath);
				EndIf;
			EndDo;
			
			ZIP.Write();
			DeleteFiles(FileDirectoryName); // Deleting along with all the files inside
		EndIf;
		
	Except
		
		DeleteFiles(DirectoryName);
		Raise;
		
	EndTry;
	
	// Clearing
	DeleteFiles(DirectoryName);
	
	Return True;
	
EndFunction

// Adds files to volumes and sets references in FileVersions
//
Function AddFilesToVolumes(PathToArchiveWindows, PathToArchiveLinux) Export
	
	FullFileNameZip = "";
	ServerPlatformType = CommonUseCached.ServerPlatformType();
	
	If ServerPlatformType = PlatformType.Windows_x86 Or ServerPlatformType = PlatformType.Windows_x86_64 Then
		FullFileNameZip = PathToArchiveWindows;
	Else
		FullFileNameZip = PathToArchiveLinux;
	EndIf;
	
	DirectoryName = GetTempFileName();
	CreateDirectory(DirectoryName);
	
	ZIP = New ZipFileReader(FullFileNameZip);
	ZIP.ExtractAll(DirectoryName, ZIPRestoreFilePathsMode.DontRestore);
	
	FilePathMapping = New Map;
	
	For Each ZIPItem In ZIP.Items Do
		FullFilePath = DirectoryName + "\" + ZIPItem.Name;
		UUID = ZIPItem.BaseName;
		
		FilePathMapping.Insert(UUID, FullFilePath);
	EndDo;
	
	FileStorageType = FileStorageType();
	FilesToAttach = New Array;
	BeginTransaction();
	Try
		
		EventHandlers = CommonUse.InternalEventHandlers(
			"StandardSubsystems.FileFunctions\OnAddFilesToVolumesOnPut");
		
		For Each Handler In EventHandlers Do
			Handler.Module.OnAddFilesToVolumesOnPut(
				FilePathMapping, FileStorageType, FilesToAttach);
		EndDo;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
		
	// Deleting recent change records
	For Each ExchangePlan In Metadata.ExchangePlans Do
		ExchangePlanName      = ExchangePlan.Name;
		ExchangePlanManager = ExchangePlans[ExchangePlanName];
		
		ThisNode = ExchangePlanManager.ThisNode();
		Selection = ExchangePlanManager.Select();
		
		While Selection.Next() Do
			
			ExchangePlanObject = Selection.GetObject();
			If ExchangePlanObject.Ref <> ThisNode Then
				
				EventHandlers = CommonUse.InternalEventHandlers(
					"StandardSubsystems.FileFunctions\OnDeleteChangeRecords");
				
				For Each Handler In EventHandlers Do
					Handler.Module.OnDeleteChangeRecords(
						ExchangePlanObject.Ref, FilesToAttach);
				EndDo;
				
			EndIf;
		EndDo;
		
	EndDo;
	
EndFunction

// Passes a setting from the client to the server and writes it on the server in privileged mode.
Procedure CommonSettingsStorageSaveInPrivilegedMode(
	ObjectKey, 
	SettingsKey = Undefined, 
	Settings,
	SettingsDescription = Undefined,
	UserName = Undefined) 
		
	SetPrivilegedMode(True);
	CommonSettingsStorage.Save(ObjectKey, SettingsKey, Settings, SettingsDescription, UserName);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Scheduled job handlers

// TextExtraction scheduled job handler.
// Extracts text from files on the hard disk.
//
Procedure ExtractTextFromFilesAtServer() Export
	
	CommonUse.ScheduledJobOnStart();
	
	SetPrivilegedMode(True);
	
	ServerPlatformType = CommonUseCached.ServerPlatformType();
	
	If Not IsWindowsPlatform() Then
		Return; // Text extraction works only on Windows.
	EndIf;
	
	NameWithFileExtension = "";
	
	WriteLogEvent(
		NStr("en = 'Files.Text extraction'",
		     CommonUseClientServer.DefaultLanguageCode()),
		EventLogLevel.Information,
		,
		,
		NStr("en = 'Scheduled text extraction started'"));
		
	ResultingQueryText = "";
	
	EventHandlers = CommonUse.InternalEventHandlers(
		"StandardSubsystems.FileFunctions\OnDefineQueryTextForTextExtraction");
	
	For Each Handler In EventHandlers Do
		CurrentQueryText = "";
		Handler.Module.OnDefineQueryTextForTextExtraction(CurrentQueryText);
		If Not IsBlankString(CurrentQueryText) Then
			If IsBlankString(ResultingQueryText) Then
				ResultingQueryText = CurrentQueryText;
			Else
				ResultingQueryText = ResultingQueryText +
				"
				|
				|UNION ALL
				|
				|" + CurrentQueryText;
			EndIf;
		EndIf;
	EndDo;
	
	If IsBlankString(ResultingQueryText) Then
		Return;
	EndIf;
	
	Query = New Query(ResultingQueryText);
	Result = Query.Execute();
	
	ExportedTable = Result.Unload();
	
	For Each Row In ExportedTable Do
		
		FileObject = Row.Ref.GetObject();
		Try
			FileObject.Lock();
		Except
			// The locked files will be processed next time
			Continue;
		EndTry;
		
		NameWithFileExtension = FileObject.Description + "." + FileObject.Extension;
		FileNameWithPath = "";
		
		EventHandlers = CommonUse.InternalEventHandlers(
			"StandardSubsystems.FileFunctions\OnDetermineFileNameWithPathToBinaryData");
		
		For Each Handler In EventHandlers Do
			Handler.Module.OnDetermineFileNameWithPathToBinaryData(
				FileObject.Ref, FileNameWithPath, True);
		EndDo;
		
		Encoding = GetFileVersionEncoding(Row.Ref);
		
		Cancel = False;
		If IsBlankString(FileNameWithPath) Then
			Cancel = True;
			Text = "";
		Else
			Text = FileFunctionsInternalClientServer.ExtractText(FileNameWithPath, Cancel, Encoding);
		EndIf;
		
		If Cancel = False Then
			FileObject.TextExtractionStatus = Enums.FileTextExtractionStatuses.Extracted;
		Else
			// If there is no handler to extract the text, it is not an error
			FileObject.TextExtractionStatus = Enums.FileTextExtractionStatuses.FailedExtraction;
		EndIf;
			
		If Row.FileStorageType = Enums.FileStorageTypes.InInfobase
		   And Not IsBlankString(FileNameWithPath) Then
			
			DeleteFiles(FileNameWithPath);
		EndIf;
		
		FileObject.TextStorage = New ValueStorage(Text, New Deflation);
		
		Try
			EventHandlers = CommonUse.InternalEventHandlers(
				"StandardSubsystems.FileFunctions\OnWriteExtractedText");
			
			For Each Handler In EventHandlers Do
				Handler.Module.OnWriteExtractedText(FileObject);
			EndDo;
		Except
			WriteLogEvent(
				NStr("en = 'Files.Text extraction'",
				     CommonUseClientServer.DefaultLanguageCode()),
				EventLogLevel.Error,
				,
				,
				StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'The following error occured during
					           |scheduled text extraction from file
					           |%1:
                   |%2.'"),
					NameWithFileExtension,
					DetailErrorDescription(ErrorInfo()) ));
		EndTry;
		
	EndDo;
	
	WriteLogEvent(
		NStr("en = 'Files.Text extraction'",
		     CommonUseClientServer.DefaultLanguageCode()),
		EventLogLevel.Information,
		,
		,
		NStr("en = 'Scheduled text extraction completed'"));
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Infobase update

// Moves ProhibitedFileExtensionList and OpenDocumentFileExtensionList constants
Procedure MoveExtensionConstants() Export
	
	SetPrivilegedMode(True);
	
	If Not CommonUseCached.DataSeparationEnabled() Then
		
		ProhibitedFileExtensionList = Constants.ProhibitedFileExtensionList.Get();
		Constants.ProhibitedDataAreaFileExtensionList.Set(ProhibitedFileExtensionList);
		
		OpenDocumentFileExtensionList = Constants.OpenDocumentFileExtensionList.Get();
		Constants.DataAreaOpenDocumentFileExtensionList.Set(OpenDocumentFileExtensionList);
		
	EndIf;	
	
EndProcedure	

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions

Procedure VerifySingleSignatureAtServer(RowData, CryptoManager)
	
	ReturnStructure = Undefined;
	
	EventHandlers = CommonUse.InternalEventHandlers(
		"StandardSubsystems.FileFunctions\OnDetermineFileAndSignatureBinaryData");
	
	For Each Handler In EventHandlers Do
		Handler.Module.OnDetermineFileAndSignatureBinaryData(RowData, ReturnStructure);
	EndDo;
	
	FileBinaryData   = ReturnStructure.BinaryData;
	SignatureBinaryData = ReturnStructure.SignatureBinaryData;
	
	Try
		//PARTIALLY_DELETED
		//DigitalSignature.VerifySignature(
		//	CryptoManager, FileBinaryData, SignatureBinaryData);
		
		RowData.Status  = NStr("en = 'Correct'");
		RowData.Incorrect = False;
	Except
		ErrorInfo = ErrorInfo();
		
		RowData.Status  = NStr("en = 'Incorrect'");
		RowData.Incorrect = True;
		
		If ErrorInfo.Reason <> Undefined Then
			RowData.Status = RowData.Status + ". " + ErrorInfo.Reason.Description;
		EndIf;
		
	EndTry;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Handlers of conditional calls of other subsystems

// Completes the structure that contains general and personal file operation settings.
Procedure OnAddFileOperationSettings(CommonSettings, PersonalSettings) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.FileOperations") Then
		FileOperationsInternalServerCallModule = CommonUse.CommonModule("FileOperationsInternalServerCall");
		FileOperationsInternalServerCallModule.AddFileOperationSettings(CommonSettings, PersonalSettings);
	EndIf;
	
EndProcedure

// Calculates the size of volume files in bytes and returns the result to FilesSize parameter.
Procedure VolumeFilesSizeOnDefine(VolumeRef, FilesSize) Export
	
	FilesSize = 0;
	
	If CommonUse.SubsystemExists("StandardSubsystems.FileOperations") Then
		FileOperationsInternalServerCallModule = CommonUse.CommonModule("FileOperationsInternalServerCall");
		FilesSize = FilesSize + FileOperationsInternalServerCallModule.CalculateFileSizeInVolume(VolumeRef);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.AttachedFiles") Then
		AttachedFilesInternalModule = CommonUse.CommonModule("AttachedFilesInternal");
		FilesSize = FilesSize + AttachedFilesInternalModule.CalculateFileSizeInVolume(VolumeRef);
	EndIf;
	
EndProcedure

// Reads file version encoding.
//
// Parameters
// VersionRef - reference to a file version.
//
// Returns:
//   Encoding string.
Procedure OnDetermineFileVersionEncoding(VersionRef, Encoding) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.FileOperations") Then
		FileOperationsInternalServerCallModule = CommonUse.CommonModule("FileOperationsInternalServerCall");
		Encoding = FileOperationsInternalServerCallModule.GetFileVersionEncoding(VersionRef);
	EndIf;
	
EndProcedure

#EndRegion