////////////////////////////////////////////////////////////////////////////////
// Attached files subsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region InternalInterface

// Declares events of the AttachedFiles subsystem:
//
// Server events:
//   OnDefineFileStorageCatalogs.
//
// See the description of this procedure in the StandardSubsystemsServer module.
Procedure OnAddInternalEvent(ClientEvents, ServerEvents) Export
	
	// SERVER EVENTS
	
	// Overrides the list of catalogs that store files for a specific owner type.
	// 
	// Parameters:
	//  FileOwnerType  - type of reference to the object where files are added.
	//
	//  CatalogNames   - Map containing catalog names as keys.
	//                   When called, contains a single default catalog name.
	//                   If only one map value is set to True, then, 
	//                   when a single catalog is requested, the catalog marked as True is selected.
	//                   If none of the values are set to True or multiple values are set to True, 
	//                   returns an error.
	//
	// Syntax:
	// Procedure OnDefineFileStorageCatalogs (FileOwnerType, CatalogNames) Export
	//
	ServerEvents.Add("StandardSubsystems.AttachedFiles\OnDefineFileStoringCatalogs");
	
EndProcedure

// See the description of this procedure in the StandardSubsystemsServer module.
Procedure InternalEventHandlersOnAdd(ClientHandlers, 
ServerHandlers) Export
	
	// SERVER HANDLERS
	
	ServerHandlers["StandardSubsystems.InfobaseVersionUpdate\OnAddUpdateHandlers"].Add(
		"AttachedFilesInternal");
	
	ServerHandlers["StandardSubsystems.BaseFunctionality\OnAddReferenceSearchException"].Add(
		"AttachedFilesInternal");
	
	ServerHandlers["StandardSubsystems.BaseFunctionality\OnSendDataToSlave"].Add(
		"AttachedFilesInternal");
	
	ServerHandlers["StandardSubsystems.BaseFunctionality\OnSendDataToMaster"].Add(
		"AttachedFilesInternal");
		
	ServerHandlers["StandardSubsystems.BaseFunctionality\OnReceiveDataFromSlave"].Add(
		"AttachedFilesInternal");
		
	ServerHandlers["StandardSubsystems.BaseFunctionality\OnReceiveDataFromMaster"].Add(
		"AttachedFilesInternal");
	
	If CommonUse.SubsystemExists("StandardSubsystems.FileFunctions") Then
		ServerHandlers["StandardSubsystems.FileFunctions\OnAddFilesToVolumesOnPut"].Add(
			"AttachedFilesInternal");
		
		ServerHandlers["StandardSubsystems.FileFunctions\OnDeleteChangeRecords"].Add(
			"AttachedFilesInternal");
		
		ServerHandlers["StandardSubsystems.FileFunctions\OnDefineQueryTextForTextExtraction"].Add(
			"AttachedFilesInternal");
		
		ServerHandlers["StandardSubsystems.FileFunctions\OnDetermineCountOfVersionsWithUnextractedText"].Add(
			"AttachedFilesInternal");
		
		ServerHandlers["StandardSubsystems.FileFunctions\OnWriteExtractedText"].Add(
			"AttachedFilesInternal");
		
		ServerHandlers["StandardSubsystems.FileFunctions\OnDetermineFilesInVolumesCount"].Add(
			"AttachedFilesInternal");
		
		ServerHandlers["StandardSubsystems.FileFunctions\OnDetermineStoredFilesPresence"].Add(
			"AttachedFilesInternal");
		
		ServerHandlers["StandardSubsystems.FileFunctions\OnGetStoredFiles"].Add(
			"AttachedFilesInternal");
		
		ServerHandlers["StandardSubsystems.FileFunctions\OnDefineFileURL"].Add(
			"AttachedFilesInternal");
		
		ServerHandlers["StandardSubsystems.FileFunctions\OnDetermineFileNameWithPathToBinaryData"].Add(
			"AttachedFilesInternal");
		
		ServerHandlers["StandardSubsystems.FileFunctions\OnDetermineFileAndSignatureBinaryData"].Add(
			"AttachedFilesInternal");
	EndIf;
	
	ServerHandlers["StandardSubsystems.BaseFunctionality\OnGetExchangePlanInitialImageObjects"].Add(
		"AttachedFilesInternal");
	
	If CommonUse.SubsystemExists("CloudTechnology.SaaSOperations.FileFunctionsSaaS") Then
		
		ServerHandlers["CloudTechnology.SaaSOperations.FileFunctionsSaaS\OnFillFileFunctionIntegrationHandlersInSaaS"].Add(
			"AttachedFilesInternal");
		
	EndIf;
	
EndProcedure

// Stores the files from the generated image.
Procedure AddFilesToVolumesWhenPlacing(Val FilePathMapping,
                                       Val FileStorageType,
                                       Val Files) Export
	
	For Each MapItem In FilePathMapping Do
		
		Position = Find(MapItem.Key, "CatalogRef");
		
		If Position = 0 Then
			Continue;
		EndIf;
		
		FileFullPathOnHardDisk = FilePathMapping.Get(MapItem.Key);
		
		If FileFullPathOnHardDisk = Undefined Then
			Continue;
		EndIf;
		
		UUID = New UUID(Left(MapItem.Key, Position - 1));
		
		CatalogName = Right(MapItem.Key, StrLen(MapItem.Key) -
 Position -10);
		Ref = Catalogs[CatalogName].GetRef(UUID);
		
		If Ref.IsEmpty() Then
			Continue;
		EndIf;
		
		Object = Ref.GetObject();
		
		If Object.FileStorageType <> Enums.FileStorageTypes.InVolumesOnHardDisk Then
			Continue;
		EndIf;
		
		If Files.Find(TypeOf(Object)) = Undefined Then
			Files.Add(TypeOf(Object));
		EndIf;
		
		// Storing files in the target infobase within an infobase, regardless of their storage type in the source infobase
		If FileStorageType = Enums.FileStorageTypes.InInfobase Then
			
			Object.FileStorageType = Enums.FileStorageTypes.InInfobase;
			Object.PathToFile = "";
			Object.Volume = Catalogs.FileStorageVolumes.EmptyRef();
			
			BinaryData = New BinaryData(FileFullPathOnHardDisk);
			
			UpdateBinaryFileDataAtServer(Object, PutToTempStorage(BinaryData));
			
		Else // Storing files in the target infobase within a volume, regardless of their storage type in the source infobase
			
			OutgoingFile = New File(FileFullPathOnHardDisk);
			FileSize = OutgoingFile.Size();
			
			ModifiedUniversalTime = Object.ModificationDateUniversal;
			BaseName = Object.Description;
			Extension = Object.Extension;
			Encrypted = Object.Encrypted;
			
			FullPathIsNew = OutgoingFile.Path + BaseName + "." + Object.Extension;
			MoveFile(FileFullPathOnHardDisk, FullPathIsNew);
			
			PathToFileOnVolume = "";
			VolumeRef = Undefined;
			
			// Adding file to a volume with sufficient free space
			
			FileFunctionsInternal.AddOnHardDisk(
				FullPathIsNew,
				PathToFileOnVolume,
				VolumeRef,
				ModifiedUniversalTime,
				"",
				BaseName,
				Extension,
				FileSize,
				Encrypted);
			
			Object.PathToFile = PathToFileOnVolume;
			Object.Volume = VolumeRef.Ref;
			
		EndIf;
		
		Object.Write();
		
		If Not IsBlankString(FullPathIsNew) Then
			DeleteFiles(FullPathIsNew);
		EndIf;
		
	EndDo;
	
EndProcedure

// Removes registration in the exchange plan when exchanging files.
//
// Parameters:
//  ExchangePlanRef - reference to the exchange plan.
//  FileTypes       - array of catalog types (for catalogs that have attached files).
//
Procedure DeleteChangeRecords(ExchangePlanRef, FileTypes) Export
	
	For Each Type In FileTypes Do
		ExchangePlans.DeleteChangeRecords(ExchangePlanRef, Metadata.FindByType(Type));
	EndDo;
	
EndProcedure

// Checks whether the passed data item is an object of the attached file.
Function ThisItemAttachedFiles(DataItem) Export
	
	If TypeOf(DataItem) = Type("ObjectDeletion") Then
		Return False;
	EndIf;
	
	ItemMetadata = DataItem.Metadata();
	
	Return CommonUse.IsCatalog(ItemMetadata)
	      And Upper(Right(ItemMetadata.Name, StrLen("AttachedFiles"))) = Upper("AttachedFiles");
	
EndFunction

// Returns attached file properties: binary data and signature.
//
// Parameters:
//  AttachedFile     - reference to the attached file.
//  SignatureAddress - String - signature address in a temporary storage.
//
// Returns:
//  Structure with the following properties:
//    BinaryData          - BinaryData of the attached file.
//    SignatureBinaryData - signature BinaryData.
//
Function GetBinaryFileDataAndSignatures(Val AttachedFile, Val SignatureAddress) Export
	
	Properties = New Structure;
	
	Properties.Insert("BinaryData", AttachedFiles.GetBinaryFileData(
		AttachedFile));
	
	Properties.Insert("SignatureBinaryData", GetFromTempStorage(SignatureAddress));
	
	Return Properties;
	
EndFunction

// Returns the number of versions where text is not extracted.
Function GetUnextractedTextVersionNumber() Export
	
	FileNumber = 0;
	
	OwnerTypes = Metadata.InformationRegisters.AttachmentExistence.Dimensions.ObjectWithFiles.Type.Types();
	TotalCatalogNames = New Map;
	
	For Each Type In OwnerTypes Do
		
		CatalogNames = FileStorageCatalogNames(Type);
		
		For Each KeyAndValue In CatalogNames Do
			If TotalCatalogNames[KeyAndValue.Key] <> Undefined Then
				Continue;
			EndIf;
			AttachedFilesCatalogName = KeyAndValue.Key;
			TotalCatalogNames.Insert(KeyAndValue.Key, True);
			
			Query = New Query;
			Query.Text = QueryTextForFileNumberWithUnextractedText(AttachedFilesCatalogName);
			
			Selection = Query.Execute().Select();
			If Selection.Next() Then
				FileNumber = FileNumber + Selection.FileNumber;
			EndIf
		EndDo;
	EndDo;
	
	Return FileNumber;
	
EndFunction

// Returns the path to a file on the hard disk. If the file is stored
// in the infobase, saves the file before returning the path.
//
// Parameters:
//  AttachedFile - reference to the attached file.
//
// Returns:
//  String - full path to the file on the hard disk.
//
Function GetFileNameWithPathToBinaryData(Val AttachedFile, 
IsEmptyPathForEmptyData = False) Export
	
	FileNameWithPath = GetTempFileName(AttachedFile.Extension);
	
	If AttachedFile.FileStorageType = Enums.FileStorageTypes.InInfobase Then
		Query = New Query;
		Query.Text = 
		"SELECT
		|	AttachedFiles.AttachedFile,
		|	AttachedFiles.StoredFile
		|FROM
		|	InformationRegister.AttachedFiles AS AttachedFiles
		|WHERE
		|	AttachedFiles.AttachedFile = &AttachedFile";
		
		Query.SetParameter("AttachedFile", AttachedFile.Ref);
		Selection = Query.Execute().Select();
		
		If Selection.Next() Then
			BinaryData = Selection.StoredFile.Get();
			
			If IsEmptyPathForEmptyData And TypeOf(BinaryData) <> Type("BinaryData") Then
				Return "";
			EndIf;
			
			BinaryData.Write(FileNameWithPath);
			
		ElsIf IsEmptyPathForEmptyData Then
			Return "";
		Else
			Raise 
FileFunctionsInternalClientServer.ErrorFileNotFoundInFileStorage(
				AttachedFile.Description + "." + AttachedFile.Extension);
		EndIf;
	Else
		If Not AttachedFile.Volume.IsEmpty() Then
			FileNameWithPath = FileFunctionsInternal.VolumeFullPath(AttachedFile.Volume) + AttachedFile.PathToFile;
		EndIf;
	EndIf;
	
	Return FileNameWithPath;
	
EndFunction

// Fills the FilesInVolumesCount parameter.
Procedure DetermineFilesInVolumesCount(FilesInVolumesCount) Export
	
	OwnerTypes = Metadata.InformationRegisters.AttachmentExistence.Dimensions.ObjectWithFiles.Type.Types
();
	TotalCatalogNames = New Map;
	
	Query = New Query;
	
	For Each Type In OwnerTypes Do
		
		CatalogNames = FileStorageCatalogNames(Type);
		
		For Each KeyAndValue In CatalogNames Do
			If TotalCatalogNames[KeyAndValue.Key] <> Undefined Then
				Continue;
			EndIf;
			AttachedFilesCatalogName = KeyAndValue.Key;
			TotalCatalogNames.Insert(KeyAndValue.Key, True);
		
			Query.Text =
			"SELECT
			|	ISNULL(COUNT(AttachedFiles.Ref), 0) AS FileNumber
			|FROM
			|	&CatalogName AS AttachedFiles
			|WHERE
			|	AttachedFiles.FileStorageType = VALUE
			|(Enum.FileStorageTypes.InVolumesOnHardDisk)";
			Query.Text = StrReplace(Query.Text, "&CatalogName",
				"Catalog." + AttachedFilesCatalogName);
			
			Selection = Query.Execute().Select();
			If Selection.Next() Then
				CountOfFilesInVolumes = CountOfFilesInVolumes + Selection.FileNumber;
			EndIf
		EndDo;
	EndDo;
	
EndProcedure

// Returns the total size of files in a volume (in bytes).
Function CalculateFileSizeInVolume(VolumeRef) Export
	
	OwnerTypes = Metadata.InformationRegisters.AttachmentExistence.Dimensions.ObjectWithFiles.Type.Types
();
	TotalCatalogNames = New Map;
	
	Query = New Query;
	Query.Parameters.Insert("Volume", VolumeRef);
	
	FileSizeInVolume = 0;
	
	For Each Type In OwnerTypes Do
		
		CatalogNames = FileStorageCatalogNames(Type);
		
		For Each KeyAndValue In CatalogNames Do
			If TotalCatalogNames[KeyAndValue.Key] <> Undefined Then
				Continue;
			EndIf;
			AttachedFilesCatalogName = KeyAndValue.Key;
			TotalCatalogNames.Insert(KeyAndValue.Key, True);
		
			Query.Text =
			"SELECT
			|	ISNULL(SUM(AttachedFiles.Size), 0) AS FilesSize
			|FROM
			|	&CatalogName AS AttachedFiles
			|WHERE
			|	AttachedFiles.Volume = &Volume";
			Query.Text = StrReplace(Query.Text, "&CatalogName",
				"Catalog." + AttachedFilesCatalogName);
			
			Selection = Query.Execute().Select();
			If Selection.Next() Then
				FileSizeInVolume = FileSizeInVolume + Selection.FilesSize;
			EndIf
		EndDo;
	EndDo;
	
	Return FileSizeInVolume;
	
EndFunction

// Returns True in the HasStoredFiles parameter if there are stored files related to ExternalObject object.
// Determines whether an external object has any stored files.
// 
// Parameters:
//  ExternalObject - reference to external object.
//  HasStoredFiles - Boolean (return value), can have the following values:
//                        True  - if the object has stored files.
//                        False - if the object has no stored files.
//
Procedure CheckExistenceOfStoredFiles(Val ExternalObject, HasStoredFiles) Export
	
	If HasStoredFiles = True Then
		Return;
	EndIf;
	
	OwnerTypes = Metadata.InformationRegisters.AttachmentExistence.Dimensions.ObjectWithFiles.Type.Types
();
	If OwnerTypes.Find(TypeOf(ExternalObject)) <> Undefined Then
		HasStoredFiles = ObjectHasFiles(ExternalObject);
	EndIf;
	
EndProcedure

// Fills ExternalObject array with stored file data from the StoredFiles object.
Procedure GetStoredFiles(Val ExternalObject, Val StoredFiles) Export
	
	OwnerTypes = Metadata.InformationRegisters.AttachmentExistence.Dimensions.ObjectWithFiles.Type.Types
();
	If OwnerTypes.Find(TypeOf(ExternalObject)) = Undefined Then
		Return;
	EndIf;
		
	FileArray = GetAllSubordinateFiles(ExternalObject);
	For Each File In FileArray Do
		
		FileData = New Structure;
		FileData.Insert("ModificationDateUniversal", 
File.ModificationDateUniversal);
		FileData.Insert("Size",                       File.Size);
		FileData.Insert("Description",                File.Description);
		FileData.Insert("Extension",                  File.Extension);
		
		FileData.Insert("FileBinaryData",          
AttachedFiles.GetFileData(
			File, Undefined).FileBinaryDataRef);
		
		FileData.Insert("Text",                       File.TextStorage.Get());
		
		StoredFiles.Add(FileData);
	EndDo;
		
EndProcedure

// Adds update handlers that are required by the subsystem.
//
// Parameters:
//  Handlers - ValueTable - see the description of NewUpdateHandlerTable function in the InfobaseUpdate common module.
// 
Procedure OnAddUpdateHandlers(Handlers) Export
	//PARTIALLY_DELETED
	//Handler = Handlers.Add();
	//Handler.Version = "2.2.1.5";
	//Handler.Procedure = "AttachedFilesInternal.ClearInformationRegisterIncorrectRecordsAttachmentExistence";
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures used during data exchange, data import, and data export

// Returns the array of catalogs that are file owners.
//
// Returns: Array (MetadataObject).
//
Function FileCatalogs() Export
	
	Result = New Array();
	
	MetadataCollection = New Array();
	MetadataCollection.Add(Metadata.Catalogs);
	MetadataCollection.Add(Metadata.Documents);
	MetadataCollection.Add(Metadata.BusinessProcesses);
	MetadataCollection.Add(Metadata.Tasks);
	MetadataCollection.Add(Metadata.ChartsOfAccounts);
	MetadataCollection.Add(Metadata.ExchangePlans);
	MetadataCollection.Add(Metadata.ChartsOfCharacteristicTypes);
	MetadataCollection.Add(Metadata.ChartsOfCalculationTypes);
	
	For Each MetadataCollection In MetadataCollection Do
		
		For Each MetadataObject In MetadataCollection Do
			
			ObjectManager = CommonUse.ObjectManagerByFullName
(MetadataObject.FullName());
			EmptyRef = ObjectManager.EmptyRef();
			FileStorageCatalogNames = FileStorageCatalogNames(EmptyRef, 
True);
			
			For Each FileStoringCatalogName In FileStorageCatalogNames Do
				
				Result.Add(Metadata.Catalogs[FileStoringCatalogName.Key]);
				
			EndDo;
			
		EndDo;
		
	EndDo;
	
	Return Result;
	
EndFunction

// Returns object array of metadata objects used for storing binary file data in the infobase.
//
// Returns: Array (MetadataObject).
//
Function InfobaseFileStoredObjects() Export
	
	Result = New Array();
	Result.Add(Metadata.InformationRegisters.AttachedFiles);
	Return Result;
	
EndFunction

// Returns a file extension.
//
// Parameters:
//  Object - CatalogObject.
//
Function FileExtention(Object) Export
	
	Return Object.Extension;
	
EndFunction

// For internal use.
Procedure WhenSendingFile(DataItem,
                          ItemSend,
                          Val InitialImageCreating = False,
                          Recipient = Undefined) Export
	
	If ItemSend = DataItemSend.Delete
		Or ItemSend = DataItemSend.Ignore Then
		
		// No overriding for standard processing
		
	ElsIf ThisItemAttachedFiles(DataItem) Then
		
		If InitialImageCreating Then
			
			If DataItem.FileStorageType = Enums.FileStorageTypes.InVolumesOnHardDisk
Then
				
				If Recipient <> Undefined
					And Recipient.AdditionalProperties.Property("AllocateFilesToInitialImage") 
Then
					
					// Storing the file data from a hard-disk volume to an internal catalog attribute
					PutFileIntoCatalogAttribute(DataItem);
					
				Else
					
					// Copying the file from a hard-disk volume to the directory used for initial image creation
					FileDirectoryName = CommonSettingsStorage.Load("FileExchange", "TemporaryDirectory");
					
					FullPath = FileFunctionsInternal.VolumeFullPath(DataItem.Volume) + DataItem.PathToFile;
					UUID = DataItem.Ref.UUID();
					
					NewFilePath = CommonUseClientServer.GetFullFileName(
							FileDirectoryName,
							String(UUID) + "CatalogRef_" + DataItem.Metadata().Name);
					
					FileFunctionsInternal.CopyFileOnCreateInitialImage(FullPath, NewFilePath);
					
				EndIf;
				
			Else
				
				// If the file is stored in the infobase, it will be exported as a part of<BR>				// AttachedFiles information register during the initial image creation.<BR>				
			EndIf;
			
		Else
			
			If DataItem.FileStorageType = Enums.FileStorageTypes.InVolumesOnHardDisk Then
				
				// Storing the file data from a hard-disk volume to an internal catalog attribute
				PutFileIntoCatalogAttribute(DataItem);
				
			Else // Enums.FileStorageTypes.InInfobase
				
				Try
					// Storing the file data from the infobase to an internal catalog attribute
					AddressInTempStorage = AttachedFiles.GetFileData(DataItem.Ref).FileBinaryDataRef;
					DataItem.StorageFile = New ValueStorage(GetFromTempStorage(AddressInTempStorage), New Deflation(9));
				Except
					// Probably the file is not found. Do not interrupt data sending.
					WriteLogEvent(
						NStr("en = 'Files.Cannot send file during data exchange'",
						     CommonUseClientServer.DefaultLanguageCode()),
						EventLogLevel.Error,
						,
						,
						DetailErrorDescription(ErrorInfo()) );
					
					DataItem.StorageFile = New ValueStorage(Undefined);
				EndTry;
				
				DataItem.FileStorageType = Enums.FileStorageTypes.InInfobase;
				DataItem.PathToFile = "";
				DataItem.Volume = Catalogs.FileStorageVolumes.EmptyRef();
				
			EndIf;
			
		EndIf;
		
	ElsIf TypeOf(DataItem) = Type("InformationRegisterRecordSet.AttachmentExistence") Then
		
		// Every node uses its own object IDs. Clearing them before sending.
		For Each Write In DataItem Do
			Write.ObjectIdentifier = "";
		EndDo;
		
	ElsIf TypeOf(DataItem) = Type("InformationRegisterRecordSet.AttachedFiles")
		And Not InitialImageCreating Then
		
		// Exporting the register during the initial image creation only
		ItemSend = DataItemSend.Ignore;
		
	EndIf;
	
EndProcedure

// For internal use only
//
Procedure UnloadFile(Val FileObject, Val NewFileName) Export
	
	If FileObject.FileStorageType = Enums.FileStorageTypes.InVolumesOnHardDisk Then
		
		FullPath = FileFunctionsInternal.VolumeFullPath(FileObject.Volume) + FileObject.PathToFile;
		FileCopy(FullPath, NewFileName);
		
	Else // Enums.FileStorageTypes.InInfobase
		
		AddressInTempStorage = AttachedFiles.GetFileData
(FileObject.Ref).FileBinaryDataRef;
		GetFromTempStorage(AddressInTempStorage).Write(NewFileName);
		
	EndIf;
	
EndProcedure

// For internal use.
Procedure WhenReceivingFile(DataItem, ItemReceive) Export
	
	If ItemReceive = DataItemReceive.Ignore Then
		
		// No overriding for standard processing
		
	ElsIf ThisItemAttachedFiles(DataItem) Then
		
		If GetFileIsProhibited(DataItem) Then
			
			ItemReceive = DataItemReceive.Ignore;
			Return;
		EndIf;
		
	// Deleting existing files from volumes, because once a file is received,
  // it is stored to a volume or an infobase even if its earlier version is already stored there.
		If Not DataItem.IsNew() Then
			
			FileVersion = CommonUse.ObjectAttributeValues(DataItem.Ref, 
"FileStorageType, Volume, PathToFile");
			
			If FileVersion.FileStorageType = Enums.FileStorageTypes.InVolumesOnHardDisk 
Then
				
				OldPathToVolume = FileFunctionsInternal.VolumeFullPath(FileVersion.Volume) + FileVersion.PathToFile;
				
				FileFunctionsInternal.DeleteFilesAtServer(OldPathToVolume);
				
			EndIf;
			
		EndIf;
		
		If FileFunctionsInternal.FileStorageType() = 
Enums.FileStorageTypes.InVolumesOnHardDisk Then
			
			// An item stored in the infobase is received during the exchange, 
			// but the default target infobase storage method is in volumes.
			// Storing the file to a volume and setting FileStorageType = InVolumesOnHardDisk.
			
			PathToFileOnVolume = "";
			VolumeRef = Undefined;
			
			// Adding the file to a volume with sufficient free space
			FileFunctionsInternal.AddOnHardDisk(
				DataItem.StorageFile.Get(),
				PathToFileOnVolume,
				VolumeRef,
				DataItem.ModificationDateUniversal,
				"",
				DataItem.Description,
				DataItem.Extension,
				DataItem.Size,
				DataItem.Encrypted);
			
			DataItem.PathToFile = PathToFileOnVolume;
			DataItem.Volume        = VolumeRef;
			DataItem.FileStorageType = Enums.FileStorageTypes.InVolumesOnHardDisk;
			
			DataItem.StorageFile = New ValueStorage(Undefined);
			
		Else
			
			BinaryData = DataItem.StorageFile.Get();
			
			If TypeOf(BinaryData) = Type("BinaryData") Then
				DataItem.AdditionalProperties.Insert("FileBinaryData", 
BinaryData);
			EndIf;
			
			DataItem.StorageFile = New ValueStorage(Undefined);
			DataItem.Volume = Catalogs.FileStorageVolumes.EmptyRef();
			DataItem.PathToFile = "";
			DataItem.FileStorageType = Enums.FileStorageTypes.InInfobase;
			
		EndIf;
		
	ElsIf TypeOf(DataItem) = Type("InformationRegisterRecordSet.AttachmentExistence") Then
		
		Set = InformationRegisters.AttachmentExistence.CreateRecordSet();
		If DataItem.Filter.ObjectWithFiles.Use Then
			Set.Filter.ObjectWithFiles.Set(DataItem.Filter.ObjectWithFiles.Value);
		EndIf;
		Set.Read();
		
		OldData = Set.Unload();
		OldData.Indexes.Add("ObjectWithFiles");
		
		// Every node uses its own object IDs. Restoring them before importing.
		For Each Write In DataItem Do
			Row = OldData.Find(Write.ObjectWithFiles, "ObjectWithFiles");
			If Row <> Undefined Then
				Write.ObjectIdentifier = Row.ObjectIdentifier;
			EndIf;
		EndDo;
		
	EndIf;
	
EndProcedure

// For internal use only
//
Procedure LoadFile(Val FileObject, Val PathToFile) Export
	
	BinaryData = New BinaryData(PathToFile);
	
	If FileFunctionsInternal.FileStorageType() = 
Enums.FileStorageTypes.InVolumesOnHardDisk Then
		
		PathToFileOnVolume = "";
		VolumeRef = Undefined;
		
		// Adding the file to a volume with sufficient free space
		FileFunctionsInternal.AddOnHardDisk(
			BinaryData,
			PathToFileOnVolume,
			VolumeRef,
			FileObject.ModificationDateUniversal,
			FileObject.VersionNumber,
			FileObject.Description,
			FileObject.Extension,
			FileObject.Size,
			FileObject.Encrypted);
		
		FileObject.PathToFile = PathToFileOnVolume;
		FileObject.Volume        = VolumeRef;
		FileObject.FileStorageType = Enums.FileStorageTypes.InVolumesOnHardDisk;
		
		FileObject.StorageFile = New ValueStorage(Undefined);
		
	Else
		
		FileObject.AdditionalProperties.Insert("FileBinaryData", BinaryData);
		FileObject.StorageFile = New ValueStorage(Undefined);
		FileObject.Volume = Catalogs.FileStorageVolumes.EmptyRef();
		FileObject.PathToFile = "";
		FileObject.FileStorageType = Enums.FileStorageTypes.InInfobase;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

// Updates the file properties once the file editing is completed.
//
// Parameters:
//  AttachedFile - reference to the attached file.
//  FileInfo     - structure with the following properties:
//                 <mandatory>
//                   FileAddressInTempStorage    - String - address of new binary file data.
//                   TempTextStorageAddress      - String - address of new binary data 
//                                                          of the text extracted from the file.
//                                            
//                 <optional>
//                   ModificationDateIsUniversal - Date   - last file modification date. If
//                                                          the property is not specified or is blank,
//                                                          the current session date is set.
//                   Extension                   - String - new file extension.
//
Procedure PutFileToStorageAndUnlock(Val AttachedFile, Val 
FileInfo) Export
	
	FileInfo.Insert("Edits", Catalogs.Users.EmptyRef());
	
	AttachedFiles.UpdateAttachedFile(AttachedFile, FileInfo)
	
EndProcedure

// Cancels file editing.
//
// Parameters:
//  AttachedFile - Ref or Object of the attached file to be released.
//
Procedure UnlockFile(Val AttachedFile) Export
	
	If Catalogs.AllRefsType().ContainsType(TypeOf(AttachedFile)) Then
		FileObject = AttachedFile.GetObject();
		FileObject.Lock();
	Else
		FileObject = AttachedFile;
	EndIf;
	
	If Not FileObject.Edits.IsEmpty() Then
		FileObject.Edits = Catalogs.Users.EmptyRef();
		FileObject.Write();
	EndIf;
	
EndProcedure

// Marks a file as editable.
//
// Parameters:
//  AttachedFile - Ref or Object of the attached file to be marked.
//
Procedure LockFileForEditingServer(Val AttachedFile) Export
	
	If Catalogs.AllRefsType().ContainsType(TypeOf(AttachedFile)) Then
		FileObject = AttachedFile.GetObject();
		FileObject.Lock();
	Else
		FileObject = AttachedFile;
	EndIf;
	
	FileObject.Edits = Users.CurrentUser();
	FileObject.Write();
	
EndProcedure

// Stores encrypted file data to a storage and sets the Encrypted flag for the file.
//
// Parameters:
//  AttachedFile    - reference to the attached file.
//  EncryptedData   - structure with the following property:
//                          TempStorageAddress - String - address of the encrypted binary data.
//  ThumbprintArray - Array of Structures containing certificate thumbprints.
// 
Procedure Encrypt(Val AttachedFile, Val EncryptedData, Val 
ThumbprintArray) Export
	
	If Catalogs.AllRefsType().ContainsType(TypeOf(AttachedFile)) Then
		AttachedFileObject = AttachedFile.GetObject();
		AttachedFileObject.Lock();
	Else
		AttachedFileObject = AttachedFile;
	EndIf;
	
	For Each ThumbprintStructure In ThumbprintArray Do
		NewRow = AttachedFileObject.EncryptionCertificates.Add();
		NewRow.Thumbprint = ThumbprintStructure.Thumbprint;
		NewRow.Presentation = ThumbprintStructure.Presentation;
		NewRow.Certificate = New ValueStorage(ThumbprintStructure.Certificate);
	EndDo;
	
	AttributesValues = New Structure;
	AttributesValues.Insert("Encrypted", True);
	AttributesValues.Insert("TextStorage", New ValueStorage(""));
	UpdateBinaryFileDataAtServer(AttachedFileObject, 
EncryptedData.TempStorageAddress, AttributesValues);
	
	If Catalogs.AllRefsType().ContainsType(TypeOf(AttachedFile)) Then
		AttachedFileObject.Write();
		AttachedFileObject.Unlock();
	EndIf;
	
EndProcedure

// Stores decrypted file data to a storage and removes the Encrypted flag from the file.
// 
// Parameters:
//  AttachedFile  - reference to the attached file.
//  EncryptedData - structure with the following property:
//                          TempStorageAddress - String - address of the decrypted binary data.
//
Procedure Decrypt(Val AttachedFile, Val DecryptedData) Export
	
	Var Cancel;
	
	If Catalogs.AllRefsType().ContainsType(TypeOf(AttachedFile)) Then
		AttachedFileObject = AttachedFile.GetObject();
		AttachedFileObject.Lock();
	Else
		AttachedFileObject = AttachedFile;
	EndIf;
	
	AttachedFileObject.EncryptionCertificates.Clear();
	
	AttributesValues = New Structure;
	AttributesValues.Insert("Encrypted", False);
	
	BinaryData = GetFromTempStorage
(DecryptedData.TempStorageAddress);
	TextExtractionStatus = Enums.FileTextExtractionStatuses.NotExtracted;
	ExtractedText = "";
	
	If IsTempStorageURL(DecryptedData.TempTextStorageAddress) 
Then
		ExtractedText = FileFunctionsInternal.GetRowFromTemporaryStorage(DecryptedData.TempTextStorageAddress);
		TextExtractionStatus = Enums.FileTextExtractionStatuses.Extracted;
		
	ElsIf Not FileFunctionsInternal.ExtractFileTextsAtServer() Then
		// Extracting texts directly (not in a background job)
		TextExtractionStatus = ExtractText(BinaryData, AttachedFile.Extension, 
ExtractedText);
	EndIf;
	
	AttachedFileObject.TextExtractionStatus = TextExtractionStatus;
	
	AttributesValues.Insert("TextStorage", New ValueStorage(ExtractedText, 
New Deflation(9)));
	
	UpdateBinaryFileDataAtServer(AttachedFileObject, BinaryData, 
AttributesValues);
	
	If Catalogs.AllRefsType().ContainsType(TypeOf(AttachedFile)) Then
		AttachedFileObject.Write();
		AttachedFileObject.Unlock();
	EndIf;
	
EndProcedure

// Replaces the binary data of an infobase file with data in a temporary storage.
Procedure UpdateBinaryFileDataAtServer(Val AttachedFile,
                                       Val FileAddressInBinaryDataTempStorage,
                                       Val AttributesValues = Undefined) 
Export
	
	SetPrivilegedMode(True);
	
	If Catalogs.AllRefsType().ContainsType(TypeOf(AttachedFile)) Then
		FileObject = AttachedFile.GetObject();
		FileObject.Lock();
		FileRef = AttachedFile;
	Else
		FileObject = AttachedFile;
		FileRef = FileObject.Ref;
	EndIf;
	
	If TypeOf(FileAddressInBinaryDataTempStorage) = Type("BinaryData") Then
		BinaryData = FileAddressInBinaryDataTempStorage;
	Else
		BinaryData = GetFromTempStorage
(FileAddressInBinaryDataTempStorage);
	EndIf;
	
	FileObject.Changed = Users.CurrentUser();
	
	If TypeOf(AttributesValues) = Type("Structure") Then
		FillPropertyValues(FileObject, AttributesValues);
	EndIf;
	
	TransactionActive = False;
	
	Try
		If FileObject.FileStorageType = Enums.FileStorageTypes.InInfobase 
Then
			BeginTransaction();
			TransactionActive = True;
			RecordManager = InformationRegisters.AttachedFiles.CreateRecordManager();
			RecordManager.AttachedFile = FileRef;
			RecordManager.Read();
			RecordManager.AttachedFile = FileRef;
			RecordManager.StoredFile = New ValueStorage(BinaryData, New 
Deflation(9));
			RecordManager.Write();
		Else
			FullPath = FileFunctionsInternal.VolumeFullPath(FileObject.Volume) + FileObject.PathToFile;
			
			Try
				FileOnHardDisk = New File(FullPath);
				FileOnHardDisk.SetReadOnly(False);
				DeleteFiles(FullPath);
				
				FileFunctionsInternal.AddOnHardDisk(
					BinaryData,
					FileObject.PathToFile,
					FileObject.Volume,
					FileObject.ModificationDateUniversal,
					"",
					FileObject.Description,
					FileObject.Extension,
					BinaryData.Size(),
					FileObject.Encrypted);
			Except
				ErrorInfo = ErrorInfo();
				WriteLogEvent(
					NStr("en = 'Files.Writing file to the hard disk'",
					     CommonUseClientServer.DefaultLanguageCode()),
					EventLogLevel.Error,
					Metadata.Catalogs[FileRef.Metadata().Name],
					FileRef,
					ErrorTextWhenSavingFileInVolume(
						DetailErrorDescription(ErrorInfo), FileRef));
				
				Raise ErrorTextWhenSavingFileInVolume(BriefErrorDescription
(ErrorInfo), FileRef);
			EndTry;
			
		EndIf;
		
		FileObject.Size = BinaryData.Size();
		
		FileObject.Write();
		
		If Catalogs.AllRefsType().ContainsType(TypeOf(AttachedFile)) Then
			FileObject.Unlock();
		EndIf;
		
		If TransactionActive Then
			CommitTransaction();
		EndIf;
		
	Except
		If TransactionActive Then
			RollbackTransaction();
		EndIf;
		WriteLogEvent(
			NStr("en = 'Files.Updating attached file data in the file storage'",
			     CommonUseClientServer.DefaultLanguageCode()),
			EventLogLevel.Error,
			,
			,
			DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
EndProcedure

// Writes binary file data to the infobase.
//
// Parameters:
//  AttachedFile - reference to the attached file.
//  BinaryData   - BinaryData to be written.
//
Procedure WriteFileToInfobase(Val AttachedFile, Val BinaryData) 
Export
	
	SetPrivilegedMode(True);
	
	RecordManager = InformationRegisters.AttachedFiles.CreateRecordManager();
	RecordManager.AttachedFile = AttachedFile;
	RecordManager.StoredFile = New ValueStorage(BinaryData, New Deflation(9));
	RecordManager.Write(True);
	
EndProcedure

// Determines whether any files are attached to the object.
Function ObjectHasFiles(Val FilesOwner, Val ExceptionFile = Undefined) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Parameters.Insert("FilesOwner", FilesOwner);
	
	QueryText =
	"SELECT
	|	AttachedFiles.Ref
	|FROM
	|	&CatalogName AS AttachedFiles
	|WHERE
	|	AttachedFiles.FileOwner = &FilesOwner";
	
	If ExceptionFile <> Undefined Then
		QueryText =  QueryText +
		"
		|	And AttachedFiles.Ref <> &Ref";
		
		Query.Parameters.Insert("Ref", ExceptionFile);
	EndIf;
	
	CatalogNames = FileStorageCatalogNames(FilesOwner);
	
	For Each KeyAndValue In CatalogNames Do
		Query.Text = StrReplace(
			QueryText, "&CatalogName", "Catalog." + KeyAndValue.Key);
		
		If Not Query.Execute().IsEmpty() Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

// Returns array of attached files for the specified owner.
//
// Parameters:
//  FilesOwner - reference to the owner of the attached files.
//
// Returns:
//  Array of references to the attached files.
//
Function GetAllSubordinateFiles(Val FilesOwner) Export
	
	SetPrivilegedMode(True);
	
	CatalogNames = FileStorageCatalogNames(FilesOwner);
	QueryText = "";
	
	For Each KeyAndValue In CatalogNames Do
		If ValueIsFilled(QueryText) Then
			QueryText = QueryText + 
			"
			|UNION ALL
			|
			|";
		EndIf;
		QueryText =
		"SELECT
		|	AttachedFiles.Ref
		|FROM
		|	&CatalogName AS AttachedFiles
		|WHERE
		|	AttachedFiles.FileOwner = &FilesOwner";
		QueryText = StrReplace(QueryText, "&CatalogName", "Catalog." + 
KeyAndValue.Key);
		QueryText = QueryText + QueryText;
	EndDo;
	
	Query = New Query(QueryText);
	Query.SetParameter("FilesOwner", FilesOwner);
	
	Return Query.Execute().Unload().UnloadColumn("Ref");
	
EndFunction

// Subscription handler of the "before delete attached file" event.
Procedure BeforeDeleteAttachedFileServer(Val Ref,
                                         Val FilesOwner,
                                         Val Volume,
                                         Val FileStorageType,
                                         Val PathToFile) Export
	
	SetPrivilegedMode(True);
	
	If Not ObjectHasFiles(FilesOwner, Ref) Then
		RecordManager = InformationRegisters.AttachmentExistence.CreateRecordManager();
		RecordManager.ObjectWithFiles = FilesOwner;
		RecordManager.Read();
		If RecordManager.Selected() Then
			RecordManager.HasFiles = False;
			RecordManager.Write();
		EndIf;
	EndIf;
	
	If FileStorageType = Enums.FileStorageTypes.InVolumesOnHardDisk Then
		If Not Volume.IsEmpty() Then
			FullPath = FileFunctionsInternal.VolumeFullPath(Volume) + PathToFile;
			Try
				File = New File(FullPath);
				File.SetReadOnly(False);
				DeleteFiles(FullPath);
				PathWithSubdirectory = File.Path;
				FileArrayInDirectory = FindFiles(PathWithSubdirectory, "*.*");
				If FileArrayInDirectory.Count() = 0 Then
					DeleteFiles(PathWithSubdirectory);
				EndIf;
			Except
				// If the file is not deleted, there was no error.
			EndTry;
		EndIf;
	EndIf;
	
EndProcedure

// Subscription handler of the "on write attached file" event.
//
Procedure OnWriteAttachedFileServer(FilesOwner) Export
	
	SetPrivilegedMode(True);
	
	RecordChanged = False;
	
	RecordManager = InformationRegisters.AttachmentExistence.CreateRecordManager();
	RecordManager.ObjectWithFiles = FilesOwner;
	RecordManager.Read();
	
	If Not ValueIsFilled(RecordManager.ObjectWithFiles) Then
		RecordManager.ObjectWithFiles = FilesOwner;
		RecordChanged = True;
	EndIf;
	
	If Not RecordManager.HasFiles Then
		RecordManager.HasFiles = True;
		RecordChanged = True;
	EndIf;
	
	If IsBlankString(RecordManager.ObjectIdentifier) Then
		RecordManager.ObjectIdentifier = GetNextObjectIdentifier();
		RecordChanged = True;
	EndIf;
	
	If RecordChanged Then
		RecordManager.Write();
	EndIf;
	
EndProcedure

// Creates copies of all attached files of the Source for the Recipient.
// Source and Recipient must be objects of the same type.
//
// Parameters:
//  Source    - Ref - source object with attached files.
//  Recipient - Ref - target object for copying the attached files.
//
Procedure CopyAttachedFiles(Val Source, Val Recipient) Export
	
	CopiedFiles = GetAllSubordinateFiles(Source.Ref);
	For Each CopiedFile In CopiedFiles Do
		If CopiedFile.DeletionMark Then
			Continue;
		EndIf;
		ObjectManager = CommonUse.ObjectManagerByRef(CopiedFile);
		FileCopy = CopiedFile.Copy();
		FileCopyRef = ObjectManager.GetRef();
		FileCopy.SetNewObjectRef(FileCopyRef);
		FileCopy.FileOwner = Recipient.Ref;
		FileCopy.Edits = Catalogs.Users.EmptyRef();
		
		FileCopy.TextStorage = New ValueStorage
(CopiedFile.TextStorage.Get());
		FileCopy.StorageFile = New ValueStorage
(CopiedFile.StorageFile.Get());
		
		FileCopy.DigitalSignatures.Clear();
		For Each CopiedTableRow In CopiedFile.DigitalSignatures Do
			TableRowCopy = FileCopy.DigitalSignatures.Add();
			FillPropertyValues(TableRowCopy, CopiedTableRow);
			TableRowCopy.Signature = CopiedTableRow.Signature;
			TableRowCopy.Certificate = CopiedTableRow.Certificate;
		EndDo;
		
		FileCopy.EncryptionCertificates.Clear();
		For Each CopiedTableRow In CopiedFile.EncryptionCertificates Do
			TableRowCopy = FileCopy.EncryptionCertificates.Add();
			FillPropertyValues(TableRowCopy, CopiedTableRow);
			TableRowCopy.Certificate = CopiedTableRow.Certificate;
		EndDo;
		
		BinaryData = AttachedFiles.GetBinaryFileData(CopiedFile);
		FileCopy.FileStorageType = FileFunctionsInternal.FileStorageType();
		If FileFunctionsInternal.FileStorageType() = 
Enums.FileStorageTypes.InInfobase Then
			WriteFileToInfobase(FileCopyRef, BinaryData);
		Else
			// Adding the file to a volume with sufficient free space
			FileFunctionsInternal.AddOnHardDisk(
				BinaryData,
				FileCopy.PathToFile,
				FileCopy.Volume,
				FileCopy.ModificationDateUniversal,
				"",
				FileCopy.Description,
				FileCopy.Extension,
				FileCopy.Size);
		EndIf;
		FileCopy.Write();
	EndDo;
	
EndProcedure

// Extracts text from binary data, returns extraction status.
Function ExtractText(Val BinaryData, Val Extension, ExtractedText) Export
	
	If FileFunctionsInternal.IsWindowsPlatform()
	   And FileFunctionsInternal.ExtractFileTextsAtServer() Then
		
		TempFileName = GetTempFileName(Extension);
		BinaryData.Write(TempFileName);
		
		Cancel = False;
		ExtractedText = FileFunctionsInternalClientServer.ExtractTextToTempStorage(TempFileName, , Cancel);
		
		Try
			DeleteFiles(TempFileName);
		Except
			WriteLogEvent(
				NStr("en = 'Files.Text extraction'",
				     CommonUseClientServer.DefaultLanguageCode()),
				EventLogLevel.Error,
				,
				,
				DetailErrorDescription(ErrorInfo()));
		EndTry;
		
		If Cancel Then
			Return Enums.FileTextExtractionStatuses.FailedExtraction;
		Else
			Return Enums.FileTextExtractionStatuses.Extracted;
		EndIf;
	Else
		ExtractedText = "";
		Return Enums.FileTextExtractionStatuses.NotExtracted;
	EndIf;
	
EndFunction

// Clears ObjectID attribute if it contains invalid characters.
Procedure ClearInformationRegisteIncorrectRecordsrAttachmentExistence() Export
	
	QueryText = 
	"SELECT
	|	AttachmentExistence.ObjectWithFiles,
	|	AttachmentExistence.ObjectIdentifier
	|FROM
	|	InformationRegister.AttachmentExistence AS AttachmentExistence";
	
	Query = New Query(QueryText);
	Selection = Query.Execute().Select();
	
	RecordSet = InformationRegisters.AttachmentExistence.CreateRecordSet();
	While Selection.Next() Do
		If ThereAreExtraneousCharsInID(Selection.ObjectIdentifier) Then
			RecordSet.Filter.ObjectWithFiles.Set(Selection.ObjectWithFiles);
			RecordSet.Read();
			For Each Write In RecordSet Do
				Write.ObjectIdentifier = "";
			EndDo;
			InfobaseUpdate.WriteData(RecordSet);
		EndIf;
	EndDo;
	
EndProcedure

// Returns the map of catalog names and Boolean values for the specified owner.
// 
// Parameters:
//  FilesOwner - Ref - object with attached files.
// 
Function FileStorageCatalogNames(FilesOwner, DoNotRaiseException = False) 
Export
	
	If TypeOf(FilesOwner) = Type("Type") Then
		FileOwnerType = FilesOwner;
	Else
		FileOwnerType = TypeOf(FilesOwner);
	EndIf;
	
	OwnerMetadata = Metadata.FindByType(FileOwnerType);
	
	CatalogNames = New Map;
	StandardMainCatalogName = OwnerMetadata.Name + "AttachedFiles";
	If Metadata.Catalogs.Find(StandardMainCatalogName) <> Undefined 
Then
		CatalogNames.Insert(StandardMainCatalogName, True);
	EndIf;
	
	// Redefining the default catalog for attached file storage.
	EventHandlers = CommonUse.InternalEventHandlers(
		"StandardSubsystems.AttachedFiles\OnDefineFileStoringCatalogs");
	
	For Each Handler In EventHandlers Do
		Handler.Module.OnDefineFileStoringCatalogs(
			FileOwnerType, CatalogNames);
	EndDo;
	
	AttachedFilesOverridable.OnDefineFileStoringCatalogs(
		FileOwnerType, CatalogNames);
	
	DefaultCatalogIsSpecified = False;
	
	For Each KeyAndValue In CatalogNames Do
		
		If Metadata.Catalogs.Find(KeyAndValue.Key) = Undefined Then
			
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Cannot determine names of file storage catalogs.
				           |The file owner of %1 type
				           |has catalog name specified : ""%2"".'"),
				String(FileOwnerType),
				String(KeyAndValue.Key));
				
		ElsIf Right(KeyAndValue.Key, StrLen("AttachedFiles"))<> 
"AttachedFiles" Then
			
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Cannot determine names of file storage catalogs.
				           |The file owner of %1 type
				           |has catalog name %2 specified 
				           |without ""AttachedFiles"" suffix.'"),
				String(FileOwnerType),
				String(KeyAndValue.Key));
			
		ElsIf KeyAndValue.Value = Undefined Then
			CatalogNames.Insert(KeyAndValue.Key, False);
			
		ElsIf KeyAndValue.Value = True Then
			If DefaultCatalogIsSpecified Then
				Raise StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'Cannot determine names of file storage catalogs.
					           |The file owner of %1 type
					           |has multiple main catalogs specified.'"),
					String(FileOwnerType),
					String(KeyAndValue.Key));
			EndIf;
			DefaultCatalogIsSpecified = True;
		EndIf;
	EndDo;
	
	If CatalogNames.Count() = 0 Then
		
		If DoNotRaiseException Then
			Return CatalogNames;
		EndIf;
		
		Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Cannot determine names of file storage catalogs.
					         |The file owner of %1 type
					         |has no file storage catalogs.'"),
			String(FileOwnerType));
	EndIf;
	
	Return CatalogNames;
	
EndFunction

// Returns the catalog name for the specified owner or raises an exception if 
// multiple catalogs are found.
// 
// Parameters:
//  FilesOwner        - Ref - object with attached files.
//  CatalogName       - String - If this parameter is filled, looks for the catalog 
//                      among the file owner storage catalogs.
//                      If it is not filled, returns the name of the main catalog.
//  ErrorTitle        - String - error title.
//                    - Undefined - do not raise an exception, return an empty string.
//  ParameterName     - String - name of the parameter used to determine the catalog name.
//  ErrorEnd          - String - the last block of the error text (only if ParameterName = Undefined).
// 
Function FileStoringCatalogName(FilesOwner,
                                CatalogName = "",
                                ExceptionTitle = Undefined,
                                ParameterName = "CatalogName",
                                ErrorEnd = Undefined) Export
	
	DoNotRaiseException = (ExceptionTitle = Undefined);
	CatalogNames = FileStorageCatalogNames(FilesOwner, 
DoNotRaiseException);
	
	If CatalogNames.Count() = 0 Then
		If DoNotRaiseException Then
			Return "";
		EndIf;
		
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			ExceptionTitle + Chars.LF +
			NStr("en = '%1, file owner of %2 type,
			           |has no file storage catalogs.'"),
			String(FilesOwner),
			String(TypeOf(FilesOwner)),
			String(CatalogName));
	EndIf;
	
	If ValueIsFilled(CatalogName) Then
		If CatalogNames[CatalogName] <> Undefined Then
			Return CatalogName;
		EndIf;
	
		If DoNotRaiseException Then
			Return "";
		EndIf;
		
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			ExceptionTitle + Chars.LF +
			NStr("en = '%1, file owner of %2 type,
			           |does not have %3 file storage catalog.'"),
			String(FilesOwner),
			String(TypeOf(FilesOwner)),
			String(CatalogName));
	EndIf;
	
	DefaultCatalog = "";
	For Each KeyAndValue In CatalogNames Do
		If KeyAndValue.Value = True Then
			DefaultCatalog = KeyAndValue.Key;
			Break;
		EndIf;
	EndDo;
	
	If ValueIsFilled(DefaultCatalog) Then
		Return DefaultCatalog;
	EndIf;
		
	If DoNotRaiseException Then
		Return "";
	EndIf;
	
	Raise StringFunctionsClientServer.SubstituteParametersInString(
		ExceptionTitle + Chars.LF +
			NStr("en = '%1, file owner of %2 type,
		           |has no main file storage catalog specified.'") +
		Chars.LF + ?(ParameterName = Undefined, ErrorEnd,
		NStr("en = 'In this case the %3 parameter must be specified.'")),
		String(FilesOwner),
		String(TypeOf(FilesOwner)),
		String(ParameterName));
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// SL event handlers

// Handler for the event of the same name that occurs during data exchange in a distributed infobase.
//
// Parameters:
//  see OnSendDataToSlave() event handler description in the Syntax Assistant.
// 
Procedure OnSendDataToSlave(DataItem, ItemSend, 
InitialImageCreating, Recipient) Export
	
	WhenSendingFile(DataItem, ItemSend, InitialImageCreating, Recipient);
	
EndProcedure

// Handler for the event of the same name that occurs during data exchange in a distributed infobase.
//
// Parameters:
//  see OnSendDataToMaster() event handler description in the Syntax Assistant.
// 
Procedure OnSendDataToMaster(DataItem, ItemSend, Recipient) Export
	
	WhenSendingFile(DataItem, ItemSend);
	
EndProcedure

// Handler for the event of the same name that occurs during data exchange in a distributed infobase.
//
// Parameters:
//  see the OnReceiveDataFromSlave() event handler description in the Syntax Assistant.
// 
Procedure OnReceiveDataFromSlave(DataItem, ItemReceive, 
SendBack, From) Export
	
	WhenReceivingFile(DataItem, ItemReceive);
	
EndProcedure

// Handler for the event of the same name that occurs during data exchange in a distributed infobase.
//
// Parameters:
//  see OnReceiveDataFromMaster() event handler description in the Syntax Assistant.
// 
Procedure OnReceiveDataFromMaster(DataItem, ItemReceive, SendBack, 
From) Export
	
	WhenReceivingFile(DataItem, ItemReceive);
	
EndProcedure

// Fills an array with metadata object names that might include references to
// other metadata objects, but these references are ignored in the application business logic.
//
// Parameters:
//  Array       - array of strings, for example, "InformationRegister.ObjectVersions".
//
Procedure OnAddReferenceSearchException(Array) Export
	
	Array.Add(Metadata.InformationRegisters.AttachmentExistence.FullName());
	
EndProcedure

// Adds a file to a volume when the "Store initial image files" event occurs
//
Procedure OnAddFilesToVolumesOnPut(FilePathMapping, StoreFilesInVolumesOnHardDisk, FilesToAttach) Export
	
	AddFilesToVolumesWhenPlacing(FilePathMapping, StoreFilesInVolumesOnHardDisk, FilesToAttach);
	
EndProcedure

// Deletes change records after the "Store initial image files" event
//
Procedure OnDeleteChangeRecords(ExchangePlanRef, FilesToAttach) Export
	
	DeleteChangeRecords(ExchangePlanRef, FilesToAttach);
	
EndProcedure

// Generates text for a query used to get files with unextracted text.
// The procedure can have another query as a parameter; in this case, the generated query text is appended to it.
// 
// Parameters:
//  QueryText - String (return value):
//                   empty string  - returns the generated query text.
//                   filled string - returns the generated query text appended to this string by UNION ALL.
// 
//  GetAllFiles - Boolean - the initial value is False. 
//                          If True, disables individual file selection.
//
Procedure OnDefineQueryTextForTextExtraction(QueryText, GetAllFiles = 
False) Export
	
	// Generating the query text for all attached file catalogs
	
	OwnerTypes = Metadata.InformationRegisters.AttachmentExistence.Dimensions.ObjectWithFiles.Type.Types
();
	
	TypeCount = OwnerTypes.Count();
	If TypeCount = 0 Then
		Return;
	EndIf;
	
	TotalCatalogNames = New Map;
	
	For Each Type In OwnerTypes Do
		CatalogNames = FileStorageCatalogNames(Type);
		
		For Each KeyAndValue In CatalogNames Do
			If TotalCatalogNames[KeyAndValue.Key] <> Undefined Then
				Continue;
			EndIf;
			TotalCatalogNames.Insert(KeyAndValue.Key, True);
		EndDo;
	EndDo;
	
	FileNumberInSelection = Int(100 / TotalCatalogNames.Count());
	FileNumberInSelection = ?(FileNumberInSelection < 10, 10, FileNumberInSelection);
	
	For Each KeyAndValue In TotalCatalogNames Do
	
		If Not IsBlankString(QueryText) Then
			QueryText = QueryText +
			"
			|
			|UNION ALL
			|
			|";
		EndIf;
		
		QueryText = QueryText + QueryTextForFilesWithUnextractedText(
			KeyAndValue.Key,
			FileNumberInSelection,
			GetAllFiles);
	EndDo;
	
EndProcedure

// Returns the number of files with unextracted text.
//
Procedure OnDetermineCountOfVersionsWithUnextractedText(NumberOfVersions) Export
	
	NumberOfVersions = 0;
	NumberOfVersions = NumberOfVersions + GetUnextractedTextVersionNumber();
	
EndProcedure

// Writes the extracted text.
//
Procedure OnWriteExtractedText(FileObject) Export
	
	If Not ThisItemAttachedFiles(FileObject) Then
		Return;
	EndIf;
	
	Try
		FileObject.DataExchange.Load = True;
		FileObject.Write();
	Except
		Raise;
	EndTry;
	
EndProcedure

// Returns the number of files stored in volumes as the CountOfFilesInVolumes parameter.
//
Procedure OnDetermineFilesInVolumesCount(CountOfFilesInVolumes) Export
	
	DetermineFilesInVolumesCount(CountOfFilesInVolumes);
	
EndProcedure

// Returns HasStoredFiles = True if there are any stored files related to ExternalObject object.
//
Procedure OnDetermineStoredFilesPresence(ExternalObject, HasStoredFiles) Export
	
	CheckExistenceOfStoredFiles(ExternalObject, HasStoredFiles);
	
EndProcedure

// Returns the array of stored files related to ExternalObject object in the StoredFiles parameter.
//
Procedure OnGetStoredFiles(ExternalObject, StoredFiles) Export
	
	GetStoredFiles(ExternalObject, StoredFiles);
	
EndProcedure

// Returns the file URL (reference to an attribute or a temporary storage).
//
Procedure OnDefineFileURL(FileRef, UUID,
URL) Export
	
	If ThisItemAttachedFiles(FileRef) Then
		URL = AttachedFiles.GetFileData(FileRef, 
UUID).FileBinaryDataRef;
	EndIf;
	
EndProcedure

// Gets a full path to a file on the hard disk.
//
Procedure OnDetermineFileNameWithPathToBinaryData(FileRef, PathToFile, IsEmptyPathForEmptyData = False) Export
	
	If ThisItemAttachedFiles(FileRef) Then
		PathToFile = GetFileNameWithPathToBinaryData(FileRef, 
IsEmptyPathForEmptyData);
	EndIf;
	
EndProcedure

// Returns a structure with file binary data and signature binary data.
//
Procedure OnDetermineFileAndSignatureBinaryData(RowData, FileDataAndSignatures) 
Export
	
	If ThisItemAttachedFiles(RowData.Object) Then
		FileDataAndSignatures = GetBinaryFileDataAndSignatures(
			RowData.Object, RowData.SignatureAddress);
	EndIf;
	
EndProcedure

// The procedure is used for getting metadata objects that must be included in the exchange plan content
//  but NOT included in the change record event subscriptions of this exchange plan.
// These metadata objects are used only when creating the initial image of a subordinate node
//  and are not transferred during the exchange.
// If the subsystem includes metadata objects used only for creating the initial image of a subordinate node,
// add these metadata objects to the Objects parameter.
//
// Parameters:
//  Objects - Array - metadata object array.
//
Procedure OnGetExchangePlanInitialImageObjects(Objects) Export
	
	Objects.Add(Metadata.InformationRegisters.AttachedFiles);
	
EndProcedure

// Fills a list of CloudTechnology.SaaSOperations.FileFunctionsSaaS subsystem integration handlers.

//
// Parameters:
//  Handlers - Array (String) - name of the common module of the handler.
//
Procedure OnFillFileFunctionIntegrationHandlersInSaaS(Handlers) 
Export
	
	Handlers.Add("AttachedFilesInternal");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Handlers of conditional calls of other subsystems

// Adds and deletes records to or from the TextExtractionQueue information register <BR>// when the file version text extraction state is changed.

//
// Parameters:
// TextSource - CatalogRef.FileVersions, CatalogRef.*AttachedFiles,
// 	 file with changed text extraction state.
// TextExtractionState - EnumRef.FileTextExtractionStatus, new file text extraction status.
//
Procedure OnUpdatingTextExtractionQueueState(TextSource, 
TextExtractionState) Export
	
	If CommonUse.SubsystemExists
("StandardSubsystems.SaaSOperations.FileFunctionsSaaS") Then
		
		If CommonUse.UseSessionSeparator() Then
			FileFunctionsInternalSaaSModule = CommonUse.CommonModule("FileFunctionsInternalSaaS");
			FileFunctionsInternalSaaSModule.RefreshTextExtractionQueueState
(TextSource, TextExtractionState);
		EndIf;
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions

Function GetFileIsProhibited(DataItem)
	
	Return DataItem.IsNew()
	   And Not FileFunctionsInternalClientServer.CheckExtentionOfFileToDownload(
	          DataItem.Extension, False);
	
EndFunction

Procedure PutFileIntoCatalogAttribute(DataItem)
	
	Try
		// Storing the file data from a hard-disk volume to an internal catalog attribute
		DataItem.StorageFile = FileFunctionsInternal.PutBinaryDataInStorage(DataItem.Volume, DataItem.PathToFile, DataItem.Ref.UUID());
	Except
		// Probably the file is not found. Do not interrupt data sending.
		WriteLogEvent(
			NStr("en = 'Files.Cannot send file during data exchange'",
			     CommonUseClientServer.DefaultLanguageCode()),
			EventLogLevel.Error,
			,
			,
			DetailErrorDescription(ErrorInfo()) );
		
		DataItem.StorageFile = New ValueStorage(Undefined);
	EndTry;
	
	DataItem.FileStorageType = Enums.FileStorageTypes.InInfobase;
	DataItem.PathToFile = "";
	DataItem.Volume = Catalogs.FileStorageVolumes.EmptyRef();
	
EndProcedure

// Returns new object ID.
//  To get the new ID, selects the last object ID from the AttachmentExistence register,
// increments it by one, and returns the result.
//
// Returns:
//  String (10) - new object ID.
//
Function GetNextObjectIdentifier()
	
	// Calculating new object ID
	Result = "0000000000"; // Matching the length of ObjectID resource
	
	QueryText =
	"SELECT TOP 1
	|	AttachmentExistence.ObjectIdentifier AS ObjectIdentifier
	|FROM
	|	InformationRegister.AttachmentExistence AS AttachmentExistence
	|
	|ORDER BY
	|	ObjectIdentifier DESC";
	
	Query = New Query;
	Query.Text = QueryText;
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		ID = Selection.ObjectIdentifier;
		
		If IsBlankString(ID) Then
			Return Result;
		EndIf;
		
		// The calculation rules used are similar to regular addition:
		// when the current digit is filled, the next digit is incremented by one  
   // and the current digit is reset to zero. Valid digit values are
		// [0..9] and [a..z] (in total, 36 values per digit).
		
		Position = 10; // 9 is the index of the 10th character
		While Position > 0 Do
			
			Char = Mid(ID, Position, 1);
			
			If Char = "z" Then
				ID = Left(ID, Position-1) + "0" + Right(ID, 10 - 
Position);
				Position = Position - 1;
				Continue;
				
			ElsIf Char = "9" Then
				NewChar = "a";
			Else
				NewChar = Char(CharCode(Char)+1);
			EndIf;
			
			ID = Left(ID, Position-1) + NewChar + Right(ID, 10 - 
Position);
			Break;
		EndDo;
		
		Result = ID;
	EndIf;
	
	Return Result;
	
EndFunction

Function QueryTextForFilesWithUnextractedText(Val CatalogName, Val 
FileNumberInSelection, Val GetAllFiles = False)
	
	QueryText = 
	"SELECT TOP 1
	|	AttachedFiles.Ref AS Ref,
	|	AttachedFiles.TextExtractionStatus AS TextExtractionStatus,
	|	AttachedFiles.FileStorageType AS FileStorageType,
	|	AttachedFiles.Extension AS Extension,
	|	AttachedFiles.Description AS Description
	|FROM
	|	&CatalogName AS AttachedFiles
	|WHERE
	|	(AttachedFiles.TextExtractionStatus = VALUE(Enum.FileTextExtractionStatuses.NotExtracted)
	|			OR AttachedFiles.TextExtractionStatus = VALUE(Enum.FileTextExtractionStatuses.EmptyRef))
	|	AND Not AttachedFiles.Encrypted";
	
	QueryText = StrReplace(QueryText, "TOP 1", ?(
		GetAllFiles,
		"",
		"TOP " + Format(FileNumberInSelection, "NG=; NZ=")) );
	
	QueryText = StrReplace(QueryText, "&CatalogName", "Catalog." + 
CatalogName);
	
	Return QueryText;
	
EndFunction

Function QueryTextForFileNumberWithUnextractedText(Val CatalogName)
	
	QueryText = 
	"SELECT
	|	ISNULL(COUNT(AttachedFiles.Ref), 0) AS FileNumber
	|FROM
	|	&CatalogName AS AttachedFiles
	|WHERE
	|	(AttachedFiles.TextExtractionStatus = VALUE(Enum.FileTextExtractionStatuses.NotExtracted)
	|			OR AttachedFiles.TextExtractionStatus = VALUE(Enum.FileTextExtractionStatuses.EmptyRef))
	|	AND Not AttachedFiles.Encrypted";
	
	QueryText = StrReplace(QueryText, "&CatalogName", "Catalog." + 
CatalogName);
	
	Return QueryText;
	
EndFunction

// Returns error message text containing a reference to the item of a file storage catalog.
//
Function ErrorTextWhenSavingFileInVolume(Val ErrorMessage, Val File)
	
	Return StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = 'Cannot save the file to a volume:
		           |""%1"".
		           |
		           |Reference to file: %2.'"),
		ErrorMessage,
		GetURL(File) );
	
EndFunction

Function ThereAreExtraneousCharsInID(ID)
	
	For Position = 1 To StrLen(ID) Do
		Char = Mid(ID, Position, 1);
		If (CharCode(Char) < CharCode("a") Or CharCode(Char) > CharCode("z"))
			And (CharCode(Char) < CharCode("0") Or CharCode(Char) > CharCode("9")) 
Then
				Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

#EndRegion