////////////////////////////////////////////////////////////////////////////////
// Attached files subsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// Returns binary data of the attached file.
//
// Parameters:
//  AttachedFile - CatalogRef - reference to the catalog named *AttachedFiles.
//
// Returns:
//  BinaryData - binary data of attached file.
//
Function GetBinaryFileData(Val AttachedFile) Export
	
	FileObject = AttachedFile.GetObject();
	
	If FileObject = Undefined Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Attached file %1 is not found.'"),
			String(AttachedFile));
	EndIf;
	
	SetPrivilegedMode(True);
	
	If FileObject.FileStorageType = Enums.FileStorageTypes.InInfobase Then
		Query = New Query;
		Query.Text = 
		"SELECT
		|	AttachedFiles.AttachedFile,
		|	AttachedFiles.StoredFile
		|FROM
		|	InformationRegister.AttachedFiles AS AttachedFiles
		|WHERE
		|	AttachedFiles.AttachedFile = &AttachedFile";
		
		Query.SetParameter("AttachedFile", AttachedFile);
		Selection = Query.Execute().Select();
		
		If Selection.Next() Then
			Return Selection.StoredFile.Get();
		Else
			Raise FileFunctionsInternalClientServer.ErrorFileNotFoundInFileStorage(
				FileObject.Description + "." + FileObject.Extension, False);
		EndIf;
	Else
		FullPath = FileFunctionsInternal.VolumeFullPath(FileObject.Volume) + FileObject.PathToFile;
		
		Try
			Return New BinaryData(FullPath)
		Except
			// Writing into the registration log
			ErrorMessage = ErrorTextWhenYouReceiveFile(ErrorInfo(), AttachedFile);
			WriteLogEvent(
				NStr("en = 'Files.Receive the file from the volume'",
				     CommonUseClientServer.DefaultLanguageCode()),
				EventLogLevel.Error,
				Metadata.Catalogs[AttachedFile.Metadata().Name],
				AttachedFile,
				ErrorMessage);
			
			Raise FileFunctionsInternalClientServer.ErrorFileNotFoundInFileStorage(
				FileObject.Description + "." + FileObject.Extension);
		EndTry;
	EndIf;
	
EndFunction

// Returns file data structure. It is used in variety of file operation commands
// and as FileData parameter value in other procedures and functions.
//
// Parameters:
//  AttachedFile     - CatalogRef - reference to the catalog named *AttachedFiles.
//
//  FormID   - UUID - form ID that is used when getting a binary data 
//                            of the file.
//
//  GetBinaryDataRef - Boolean - if False, reference to the binary data is not received 
//                               that significantly speed up execution for large binary data.
//
// Returns:
//  Structure with the following properties:
//    FileBinaryDataRef          - String - address in the temporary storage.
//    RelativePath               - String.
//    ModificationDateUniversal  - Date.
//    FileName                   - String.
//    Description                - String.
//    Extension                  - String.
//    Size                       - Number.
//    Edits                      - CatalogRef.Users.
//    SignedWithDigitalSignature - Boolean.
//    Encrypted                  - Boolean.
//    FileBeingEdited            - Boolean.
//    FileEditedByCurrentUser    - Boolean.
//
Function GetFileData(Val AttachedFile,
                     Val FormID = Undefined,
                     Val GetBinaryDataRef = True) Export
	
	FileObject = AttachedFile.GetObject();
	
	If FileObject = Undefined Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Attached file %1 is not found.'"),
			String(AttachedFile));
	EndIf;
	
	SetPrivilegedMode(True);
	
	FileBinaryDataRef = Undefined;
	
	If GetBinaryDataRef Then
		
		If FileObject.FileStorageType = Enums.FileStorageTypes.InInfobase Then
			QueryText = 
			"SELECT
			|	AttachedFiles.StoredFile
			|FROM
			|	InformationRegister.AttachedFiles AS AttachedFiles
			|WHERE
			|	AttachedFiles.AttachedFile = &AttachedFile";
			
			Query = New Query(QueryText);
			Query.SetParameter("AttachedFile", AttachedFile);
			
			Selection = Query.Execute().Select();
			BinaryData = Undefined;
			If Selection.Next() Then
				BinaryData = Selection.StoredFile.Get();
			EndIf;
		 
			If TypeOf(FormID) = Type("UUID") Then
				FileBinaryDataRef = PutToTempStorage(BinaryData, FormID);
			Else
				FileBinaryDataRef = PutToTempStorage(BinaryData);
			EndIf;
		Else
			FullPath = FileFunctionsInternal.VolumeFullPath(FileObject.Volume) + FileObject.PathToFile;
			
			Try
				BinaryData = New BinaryData(FullPath);
				If TypeOf(FormID) = Type("UUID") Then
					FileBinaryDataRef = PutToTempStorage(BinaryData, FormID);
				Else
					FileBinaryDataRef = PutToTempStorage(BinaryData);
				EndIf;
			Except
				ErrorMessage = ErrorTextWhenYouReceiveFile(ErrorInfo(), AttachedFile);
				WriteLogEvent(
					NStr("en = 'Files.File opens'",
					     CommonUseClientServer.DefaultLanguageCode()),
					EventLogLevel.Error,
					Metadata.Catalogs[AttachedFile.Metadata().Name],
					AttachedFile,
					ErrorMessage);
				
			Raise FileFunctionsInternalClientServer.ErrorFileNotFoundInFileStorage(
				FileObject.Description + "." + FileObject.Extension);
			EndTry;
		EndIf;
		
	EndIf;
	
	AdditionalInfo = New Structure;
	AdditionalInfo.Insert("FileBinaryDataRef",         FileBinaryDataRef);
	AdditionalInfo.Insert("RelativePath",              GetObjectID(FileObject.FileOwner) + "\");
	AdditionalInfo.Insert("ModificationDateUniversal", FileObject.ModificationDateUniversal);
	AdditionalInfo.Insert("FileName",                  FileObject.Description + "." + FileObject.Extension);
	AdditionalInfo.Insert("Description",               FileObject.Description);
	AdditionalInfo.Insert("Extension",                 FileObject.Extension);
	AdditionalInfo.Insert("Size",                      FileObject.Size);
	AdditionalInfo.Insert("Edits",                     FileObject.Edits);
	AdditionalInfo.Insert("SignedWithDS",              FileObject.SignedWithDS);
	AdditionalInfo.Insert("Encrypted",                 FileObject.Encrypted);
	AdditionalInfo.Insert("FileBeingEdited",           FileObject.Edits <> Catalogs.Users.EmptyRef() );
	AdditionalInfo.Insert("FileEditedByCurrentUser",
		?(AdditionalInfo.FileBeingEdited, FileObject.Edits = Users.CurrentUser(), False) );
	
	If FileObject.Encrypted Then
		EncryptionCertificateArray = New Array;
		For Each TSRow In FileObject.EncryptionCertificates Do
			EncryptionCertificateArray.Add(New Structure("Thumbprint, Presentation", TSRow.Thumbprint, TSRow.Presentation));
		EndDo;
		AdditionalInfo.Insert("EncryptionCertificateArray", EncryptionCertificateArray);
	EndIf;
	
	Return AdditionalInfo;
	
EndFunction

// Fills the array with references to object files.
//
// Parameters:
//  Object    - Ref - reference to the object that can contain attached files.
//  FileArray - Array - array where references to objects are added:
//                      CatalogRef - (return value) reference to the attached file.
//
Procedure GetAttachedToObjectFiles(Val Object, Val FileArray) Export
	
	OwnerTypes = Metadata.InformationRegisters.AttachmentExistence.Dimensions.ObjectWithFiles.Type.Types();
	If OwnerTypes.Find(TypeOf(Object)) <> Undefined Then
		
		LocalFileArray = AttachedFilesInternal.GetAllSubordinateFiles(Object);
		For Each RefToFile In LocalFileArray Do
			FileArray.Add(RefToFile);
		EndDo;
		
	EndIf;
	
EndProcedure

// Creates an object in the catalog to storage the file and fills attributes with passed properties.
//
// Parameters:
//  FilesOwner               - Ref - object for adding file.
//  BaseName                 - String - file name without extension.
//  ExtensionWithoutDot      - String - file extension (without dot in the beginning).
//  Modified                 - Date   - (not used) file change date and time (local time).
//  ModifiedUniversalTime    - Date   - file modification date and time (UTC +0:00).
//                                      If it is not specified, use CurrentUniversalDate().
//  FileAddressInTempStorage - String - binary data address in the temporary storage.
//  TempTextStorageAddress   - String - address of extracted from file text in the temporary storage.
//  Description              - String - text file description.
//  NewRefToFile             - Undefined - create a new reference to the file in the standard 
//                                          catalog or in unique nonstandard catalog. 
//                                          If file owner have more than one 
//                                         directories, reference to the file must be passed to avoid an exception.
//                           - Ref - reference to the file storage catalog item that must be used 
//                                   to add the file.
//                                   Should correspond to one of catalog types, where owner files are stored.
//
// Returns:
//  CatalogRef - a reference to created attached file.
//
Function AppendFile(Val FilesOwner,
                     Val BaseName,
                     Val ExtensionWithoutDot = Undefined,
                     Val Modified = Undefined,
                     Val ModifiedUniversalTime = Undefined,
                     Val FileAddressInTempStorage,
                     Val TempTextStorageAddress = "",
                     Val Description = "",
                     Val NewRefToFile = Undefined) Export
	
	// If the extension is not specified explicitly, select it from the file name
	If ExtensionWithoutDot = Undefined Then
		FileNameParts = StringFunctionsClientServer.SplitStringIntoSubstringArray(BaseName, ".", False);
		If FileNameParts.Count() > 1 Then
			ExtensionWithoutDot = FileNameParts[FileNameParts.Count()-1];
			BaseName = Left(BaseName, StrLen(BaseName) - (StrLen(ExtensionWithoutDot)+1));
		EndIf;
	EndIf;
	
	If Not ValueIsFilled(ModifiedUniversalTime)
	 Or ModifiedUniversalTime > CurrentUniversalDate() Then
		ModifiedUniversalTime = CurrentUniversalDate();
	EndIf;
	
	BinaryData = GetFromTempStorage(FileAddressInTempStorage);
	
	ErrorTitle = NStr("en = 'Error when adding attached file.'");
	
	If NewRefToFile = Undefined Then
		CatalogName = AttachedFilesInternal.FileStoringCatalogName(
			FilesOwner, "", ErrorTitle, "NewRefToFile");
		
		NewRefToFile = Catalogs[CatalogName].GetRef();
	Else
		If Not Catalogs.AllRefsType().ContainsType(TypeOf(NewRefToFile))
		 Or Not ValueIsFilled(NewRefToFile) Then
			
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Error when adding attached file.
				           |Reference to the new file is required.'"));
		EndIf;
		
		CatalogName = AttachedFilesInternal.FileStoringCatalogName(
			FilesOwner, NewRefToFile.Metadata().Name, ErrorTitle);
	EndIf;
	
	AttachedFile = Catalogs[CatalogName].CreateItem();
	AttachedFile.SetNewObjectRef(NewRefToFile);
	
	AttachedFile.FileOwner                = FilesOwner;
	AttachedFile.ModificationDateUniversal = ModifiedUniversalTime;
	AttachedFile.CreationDate                 = CurrentSessionDate();
	AttachedFile.Description                     = Description;
	AttachedFile.SignedWithDS                  = False;
	AttachedFile.Description                 = BaseName;
	AttachedFile.Extension                   = ExtensionWithoutDot;
	AttachedFile.FileStorageType             = FileFunctionsInternal.FileStorageType();
	AttachedFile.Size                       = BinaryData.Size();
	
	OwnTransactionOpen = False;
	
	Try
		If AttachedFile.FileStorageType = Enums.FileStorageTypes.InInfobase Then
			BeginTransaction();
			OwnTransactionOpen = True;
			AttachedFilesInternal.WriteFileToInfobase(NewRefToFile, BinaryData);
			AttachedFile.Volume = Catalogs.FileStorageVolumes.EmptyRef();
			AttachedFile.PathToFile = "";
		Else
			// Add to one of the volumes (that has enough space).
			FileFunctionsInternal.AddOnHardDisk(
				BinaryData,
				AttachedFile.PathToFile,
				AttachedFile.Volume,
				ModifiedUniversalTime,
				"",
				BaseName,
				ExtensionWithoutDot,
				AttachedFile.Size,
				AttachedFile.Encrypted);
		EndIf;
		
		TextExtractionStatus = Enums.FileTextExtractionStatuses.NotExtracted;
		ExtractedText = "";
		
		If IsTempStorageURL(TempTextStorageAddress) Then
			ExtractedText = FileFunctionsInternal.GetRowFromTemporaryStorage(TempTextStorageAddress);
			TextExtractionStatus = Enums.FileTextExtractionStatuses.Extracted;
			
		ElsIf Not FileFunctionsInternal.ExtractFileTextsAtServer() Then
			// Texts are extracted directly and not in the background job.
			TextExtractionStatus = AttachedFilesInternal.ExtractText(
				BinaryData, AttachedFile.Extension, ExtractedText);
		EndIf;
		
		AttachedFile.TextExtractionStatus = TextExtractionStatus;
		AttachedFile.TextStorage = New ValueStorage(ExtractedText);
		
		AttachedFile.Write();
		
		If OwnTransactionOpen Then
			CommitTransaction();
		EndIf;
	
	Except
		ErrorInfo = ErrorInfo();
		
		If OwnTransactionOpen Then
			RollbackTransaction();
		EndIf;
		
		MessagePattern = NStr("en = 'Error during adding attached
		                             |file %1: %2'");
		EventLogComment = StringFunctionsClientServer.SubstituteParametersInString(
			MessagePattern,
			BaseName + "." + ExtensionWithoutDot,
			DetailErrorDescription(ErrorInfo));
		
		WriteLogEvent(
			NStr("en = 'Files.Adding attached file'",
			     CommonUseClientServer.DefaultLanguageCode()),
			EventLogLevel.Error,
			,
			,
			EventLogComment);
		
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			MessagePattern,
			BaseName + "." + ExtensionWithoutDot,
			BriefErrorDescription(ErrorInfo));
	EndTry;
	
	Return AttachedFile.Ref;
	
EndFunction

// Returns a new reference to
// the file for the specified owner, that can be passed to the AppendFile function.
//  
// Parameters:
//  FilesOwner - Ref - reference to the object for adding file.
//  
//  CatalogName - Undefined - find catalog by
//                   the owner(valid if catalog is unique otherwise exception is thrown).
//  
//                 - String - catalog name *AttachedFiles
//                            that is different from the default <OwnerName>AttachedFiles.
//  
// Returns:
//  CatalogRef - reference to new attached file.
//
Function NewRefToFile(FilesOwner, CatalogName = Undefined) Export
	
	ErrorTitle = NStr("en = 'Error when getting new references to the attached file.'");
	
	CatalogName = AttachedFilesInternal.FileStoringCatalogName(
		FilesOwner, CatalogName, ErrorTitle);
	
	Return Catalogs[CatalogName].GetRef();
	
EndFunction

// Updates file properties - binary data, text, modification
// date, and also other optional properties.
//
// Parameters:
//  AttachedFile - CatalogRef - reference to the catalog named *AttachedFiles.
//  FileInfo - Structure - with the following properties:
//     <mandatory>
//     FileAddressInTempStorage - String - address of new binary file data.
//     TempTextStorageAddress - String - address of new
//                                                 binary text data that is extracted from the file.
//     <Optional>
//     BaseName               - String - If property is not specified
//                                                 or is blank, it will not changed.
//     ModificationDateUniversal   - Date   - date the file was
//                                                 last modified. If property is not specified or
//                                                 is blank, current session date is set.
//     * Extension                     - String - new file extension.
//     Edits                    - Ref - new user that edits file.
//
Procedure UpdateAttachedFile(Val AttachedFile, Val FileInfo) Export
	
	Var Cancel;
	
	AttributesValues = New Structure;
	
	If FileInfo.Property("BaseName") And ValueIsFilled(FileInfo.BaseName) Then
		AttributesValues.Insert("Description", FileInfo.BaseName);
	EndIf;
	
	If Not FileInfo.Property("ModificationDateUniversal")
	 Or Not ValueIsFilled(FileInfo.ModificationDateUniversal)
	 Or FileInfo.ModificationDateUniversal > CurrentUniversalDate() Then
		
		// Filling current date in the universal time format.
		AttributesValues.Insert("ModificationDateUniversal", CurrentUniversalDate());
	Else
		AttributesValues.Insert("ModificationDateUniversal", FileInfo.ModificationDateUniversal);
	EndIf;
	
	If FileInfo.Property("Edits") Then
		AttributesValues.Insert("Edits", FileInfo.Edits);
	EndIf;
	
	If FileInfo.Property("Extension") Then
		AttributesValues.Insert("Extension", FileInfo.Extension);
	EndIf;
	
	BinaryData = GetFromTempStorage(FileInfo.FileAddressInTempStorage);
	
	AttributesValues.Insert("TextExtractionStatus", Enums.FileTextExtractionStatuses.NotExtracted);
	ExtractedText = "";
	
	If IsTempStorageURL(FileInfo.TempTextStorageAddress) Then
		
		ExtractedText = FileFunctionsInternal.GetRowFromTemporaryStorage(
			FileInfo.TempTextStorageAddress);
		
		AttributesValues.TextExtractionStatus = Enums.FileTextExtractionStatuses.Extracted;
		
	ElsIf Not FileFunctionsInternal.ExtractFileTextsAtServer() Then
		// Texts are extracted directly and not in the background job
		AttributesValues.TextExtractionStatus = AttachedFilesInternal.ExtractText(
			BinaryData, AttachedFile.Extension, ExtractedText);
	EndIf;
	
	AttributesValues.Insert("TextStorage", New ValueStorage(ExtractedText));
	
	AttachedFilesInternal.UpdateBinaryFileDataAtServer(
		AttachedFile, BinaryData, AttributesValues);
	
EndProcedure

// Returns attached file form name by owner.
//
// Parameters:
//  FilesOwner - Ref - reference to the object that is used to find form name.
//
// Returns:
//  String - attached file form name by owner.
//
Function GetAttachedFileObjectFormNameByOwner(Val FilesOwner) Export
	
	ErrorTitle = NStr("en = 'Error when getting attached file form name.'");
	ErrorEnd = NStr("en = 'Cannot receive form.'");
	
	CatalogName = AttachedFilesInternal.FileStoringCatalogName(
		FilesOwner, "", ErrorTitle, Undefined, ErrorEnd);
	
	FullMOName = "Catalog." + CatalogName;
	
	AttachedFileMetadata = Metadata.FindByFullName(FullMOName);
	
	If AttachedFileMetadata.DefaultObjectForm = Undefined Then
		FormName = FullMOName + ".ObjectForm";
	Else
		FormName = AttachedFileMetadata.DefaultObjectForm.FullName();
	EndIf;
	
	Return FormName;
	
EndFunction

// Defines the existence of object attached files storage 
// and "Adding file to the storage" right (attached file catalog).
//
// Parameters:
//  FilesOwner  - Ref - reference to checked object.
//  CatalogName - String - if check adding to the specified storage is required.
//
// Returns:
//  Boolean - if True, file can be attached to the object.
//
Function YouCanAttachFilesToObject(FilesOwner, CatalogName = "") Export
	
	CatalogName = AttachedFilesInternal.FileStoringCatalogName(
		FilesOwner, CatalogName);
		
	CatalogAttachedFiles = Metadata.Catalogs.Find(CatalogName);
	
	StoredFileTypes =
		Metadata.InformationRegisters.AttachedFiles.Dimensions.AttachedFile.Type;
	
	Return CatalogAttachedFiles <> Undefined
	      And AccessRight("Insert", CatalogAttachedFiles)
	      And StoredFileTypes.ContainsType(Type("CatalogRef." + CatalogName));
	
EndFunction

// Converts files from the File operations subsystem to the Attached files subsystem.
// Requires File operations subsystem.
//
// The procedure is used in the infobase update procedures, if any file owner object 
// is transfered from using one subsystem to another.
// The procudure is executed sequentially for each item of the file owner object
// (catalog, CCT, document item etc.).
//
// Parameters:
//   FilesOwner  - Ref - reference to object for conversion.
//   CatalogName - String - if conversion to the specified storage is required.
//
Procedure ConvertFilesToAttachedFiles(Val FilesOwner, CatalogName = Undefined) Export
	
	If Not CommonUse.SubsystemExists("StandardSubsystems.FileOperations") Then
		Return;
	EndIf;
	
	FileOperationsInternalServerCallModule = CommonUse.CommonModule("FileOperationsInternalServerCall");
	FileOperationsInternalModule = CommonUse.CommonModule("FileOperationsInternal");
	
	ErrorTitle = NStr("en = 'Error converting attached files of File operations subsystem
	                         |to attached files of Attached files subsystem.'");
	
	CatalogName = AttachedFilesInternal.FileStoringCatalogName(
		FilesOwner, CatalogName, ErrorTitle);
		
	SetPrivilegedMode(True);
	
	SourceFiles = FileOperationsInternalServerCallModule.GetAllSubordinateFiles(FilesOwner);
	
	AttachedFileManager = Catalogs[CatalogName];
	
	BeginTransaction();
	
	Try
		
		For Each SourceFile In SourceFiles Do
			SourceFileObject = SourceFile.GetObject();
			CurrentVersionObject = SourceFileObject.CurrentVersion.GetObject();
			
			RefNew = AttachedFileManager.GetRef();
			AttachedFile = AttachedFileManager.CreateItem();
			AttachedFile.SetNewObjectRef(RefNew);
			
			AttachedFile.FileOwner                 = FilesOwner;
			AttachedFile.Description               = SourceFileObject.Description;
			AttachedFile.Author                    = SourceFileObject.Author;
			AttachedFile.ModificationDateUniversal = CurrentVersionObject.ModificationDateUniversal;
			AttachedFile.CreationDate              = SourceFileObject.CreationDate;
			
			AttachedFile.Encrypted                 = SourceFileObject.Encrypted;
			AttachedFile.Changed                   = CurrentVersionObject.Author;
			AttachedFile.Description               = SourceFileObject.Description;
			AttachedFile.SignedWithDS              = SourceFileObject.SignedWithDS;
			AttachedFile.Size                      = CurrentVersionObject.Size;
			
			AttachedFile.Extension                 = CurrentVersionObject.Extension;
			AttachedFile.Edits                     = SourceFileObject.Edits;
			AttachedFile.TextStorage               = SourceFileObject.TextStorage;
			AttachedFile.FileStorageType           = CurrentVersionObject.FileStorageType;
			AttachedFile.DeletionMark              = SourceFileObject.DeletionMark;
			
			// If the file is stored on a volume, reference to an existing file is created.
			AttachedFile.Volume                    = CurrentVersionObject.Volume;
			AttachedFile.PathToFile                = CurrentVersionObject.PathToFile;
			
			For Each EncryptionCertificateRow In SourceFileObject.EncryptionCertificates Do
				NewRow = AttachedFile.EncryptionCertificates.Add();
				FillPropertyValues(NewRow, EncryptionCertificateRow);
			EndDo;
			
			For Each DigitalSignatureString In CurrentVersionObject.DigitalSignatures Do
				NewRow = AttachedFile.DigitalSignatures.Add();
				FillPropertyValues(NewRow, DigitalSignatureString);
			EndDo;
			
			AttachedFile.Write();
			
			If AttachedFile.FileStorageType = Enums.FileStorageTypes.InInfobase Then
				FileStorage = FileOperationsInternalServerCallModule.GetFileStorageOfInfobase(CurrentVersionObject.Ref);
				BinaryData = FileStorage.Get();
				
				RecordManager = InformationRegisters.AttachedFiles.CreateRecordManager();
				RecordManager.AttachedFile = RefNew;
				RecordManager.Read();
				RecordManager.AttachedFile = RefNew;
				RecordManager.StoredFile = New ValueStorage(BinaryData, New Deflation(9));
				RecordManager.Write();
			EndIf;
			
			CurrentVersionObject.DeletionMark = True;
			SourceFileObject.DeletionMark = True;
			
			// Delete references to the volume in the old file, to prevent file deleting.
			If CurrentVersionObject.FileStorageType = Enums.FileStorageTypes.InVolumesOnHardDisk Then
				CurrentVersionObject.PathToFile = "";
				CurrentVersionObject.Volume = Catalogs.FileStorageVolumes.EmptyRef();
				SourceFileObject.CurrentVersionFilePath = "";
				SourceFileObject.CurrentVersionVolume = "";
				FileOperationsInternalModule.MarkForDeletionFileVersions(SourceFileObject.Ref, CurrentVersionObject.Ref);
			EndIf;
			
			CurrentVersionObject.AdditionalProperties.Insert("FileConversion", True);
			CurrentVersionObject.Write();
			
			SourceFileObject.AdditionalProperties.Insert("FileConversion", True);
			SourceFileObject.Write();
			
		EndDo;
		
	Except
		ErrorInfo = ErrorInfo();
		RollbackTransaction();
		Raise DetailErrorDescription(ErrorInfo);
	EndTry;
	
	CommitTransaction();
	
EndProcedure

// Returns references to the objects with files from the File operations subsystem.
// Requires File operations subsystem.
//
// Use with ConvertFilesToAttachedFiles function.
//
// Parameters:
//  FileOwnerTable - String - full name of the metadata that can own attached files.                           
//
// Returns:
//  Array - with values:
//    Ref - reference to the object that has at least one attached file.
//
Function ReferencesToObjectsWithFiles(Val FileOwnerTable) Export
	
	If Not CommonUse.SubsystemExists("StandardSubsystems.FileOperations") Then
		Return New Array;
	EndIf;
	
	FileOperationsInternalModule = CommonUse.CommonModule("FileOperationsInternal");
	
	Return FileOperationsInternalModule.ReferencesToObjectsWithFiles(FileOwnerTable);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures that are attachable to managed form events

// Handler of the OnWriteAtServer event of the attached file owner form.
//
// Parameters:
//  Cancel          - Boolean - standard parameter of OnWriteAtServer managed form event.
//  CurrentObject   - Object - standard parameter of OnWriteAtServer managed form event.
//  WriteParameters - Structure - standard parameter of OnWriteAtServer managed form event.
//  Parameters      - FormDataStructure - property Managed form parameters.
//
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters, Parameters) Export
	
	If ValueIsFilled(Parameters.CopyingValue) Then
		
		AttachedFilesInternal.CopyAttachedFiles(
			Parameters.CopyingValue, CurrentObject);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures that are called from the manager module of catalogs with attached files.

// Returns the list of attributes that can be edited
// using the Batch object modification data processor.
//
// Returns:
//  Array - values:
//   String - attached file attribute name, that
//            can be edited in group processing.
//
Function BatchProcessingEditableAttributes() Export
	
	EditableAttributes = New Array;
	EditableAttributes.Add("Description");
	EditableAttributes.Add("Edits");
	
	Return EditableAttributes;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Operations with digital signatures.

// Logs information about one digital signature.
//
// Parameters:
//  AttachedFile  - CatalogRef - reference to the catalog named *AttachedFiles.
//  SignatureData - Structure - data of the digital signatures to fill in the DigitalSignatures table.
//
Procedure RecordSingleSignatureDetails(Val AttachedFile, Val SignatureData) Export
	
	If CommonUse.IsReference(TypeOf(AttachedFile)) Then
		AttributeStructure = CommonUse.ObjectAttributeValues(AttachedFile, "Edits, Encrypted");
		AttachedFileRef = AttachedFile;
	Else
		AttributeStructure = New Structure("Edits, Encrypted");
		AttributeStructure.Edits = AttachedFile.Edits;
		AttributeStructure.Encrypted  = AttachedFile.Encrypted;
		AttachedFileRef = AttachedFile.Ref;
	EndIf;
	
	If Not AttributeStructure.Edits.IsEmpty() Then
		Raise FileFunctionsInternalClientServer.FileUsedByAnotherProcessCannotBeSignedMessageString(AttachedFileRef);
	EndIf;
	
	If AttributeStructure.Encrypted Then
		Raise FileFunctionsInternalClientServer.EncryptedFileCannotBeSignedMessageString(AttachedFileRef);
	EndIf;

	//DigitalSignature.LogInformationAboutSignature(
	//	AttachedFile,
	//	SignatureData.NewSignatureBinaryData,
	//	SignatureData.Thumbprint,
	//	SignatureData.SignatureDate,
	//	SignatureData.Comment,
	//	SignatureData.SignatureFileName,
	//	SignatureData.CertificateOwner,
	//	SignatureData.CertificateBinaryData);
	
EndProcedure

// Logs information about digital signature array.
//
// Parameters:
//  AttachedFile      - CatalogRef - reference to the catalog named *AttachedFiles.
//  ArrayOfSignatures - Array with values:
//                      Structure - data of the digital signatures to fill in the DigitalSignatures table.
//
Procedure RecordMultipleSignatureDetails(Val AttachedFile,
                                     Val ArrayOfSignatures) Export
	
	If CommonUse.IsReference(TypeOf(AttachedFile)) Then
		FileObject = AttachedFile.GetObject();
		FileObject.Lock();
		FileRef = AttachedFile;
	Else
		FileObject = AttachedFile;
		FileRef = AttachedFile.Ref;
	EndIf;
	
	Edits = FileObject.Edits;
	Encrypted  = FileObject.Encrypted;

	If Not Edits.IsEmpty() Then
		Raise
			FileFunctionsInternalClientServer.FileUsedByAnotherProcessCannotBeSignedMessageString(
				FileRef);
	EndIf;
	
	If Encrypted Then
		Raise
			FileFunctionsInternalClientServer.EncryptedFileCannotBeSignedMessageString(
				FileRef);
	EndIf;
		
	For Each SignatureData In ArrayOfSignatures Do
		//PARTIALLY_DELETED
		//DigitalSignature.LogInformationAboutSignature(
		//	FileObject,
		//	SignatureData.NewSignatureBinaryData,
		//	SignatureData.Thumbprint,
		//	SignatureData.SignatureDate,
		//	SignatureData.Comment,
		//	SignatureData.SignatureFileName,
		//	SignatureData.CertificateOwner,
		//	SignatureData.CertificateBinaryData);
	EndDo;
	
	FileObject.Write();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Event subscription handlers.

// Handler of the BeforeWrite event for filling attached file attributes.
//
// Parameters:
//  Source - CatalogObject - AttachedFiles catalog object.
//  Cancel - Boolean - parameter passed to the BeforeWrite event subscription.
//
Procedure ExecuteActionsBeforeWriteAttachedFile(Source, Cancel) Export
	
	If Source.DataExchange.Load Then
		Return;
	EndIf;
	
	If Not ValueIsFilled(Source.FileOwner) Then
		
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Owner of the file
			           |""%1"" is required.'"),
			Source.Description);
		
		If InfobaseUpdate.ExecutingInfobaseUpdate() Then
			
			WriteLogEvent(
				NStr("en = 'Files.Error writing file during infobase updating'",
				     CommonUseClientServer.DefaultLanguageCode()),
				EventLogLevel.Error,
				,
				Source.Ref,
				ErrorDescription);
		Else
			Raise ErrorDescription;
		EndIf;
		
	EndIf;
	
	Source.PictureIndex = FileFunctionsInternalClientServer.GetFileIconIndex(Source.Extension);
	
	If Source.IsNew() Then
		Source.Author = Users.CurrentUser();
	EndIf;
	
EndProcedure

// Handler of the BeforeDelete event for deletion data associated with the attached file.
//
// Parameters:
//  Source - CatalogObject - AttachedFiles catalog object.
//  Cancel - Boolean - parameter passed to the BeforeWrite event subscription.
//
Procedure ExecuteActionsBeforeDeleteAttachedFile(Source, Cancel) Export
	
	If Source.DataExchange.Load Then
		Return;
	EndIf;
	
	AttachedFilesInternal.BeforeDeleteAttachedFileServer(
		Source.Ref,
		Source.FileOwner,
		Source.Volume,
		Source.FileStorageType,
		Source.PathToFile);
	
EndProcedure

// Handler of the OnWrite event for updating data associated with the attached file.
//
// Parameters:
//  Source - CatalogObject - AttachedFiles catalog object.
//  Cancel - Boolean - parameter passed to the BeforeWrite event subscription.
//
Procedure ExecuteActionsOnWriteAttachedFile(Source, Cancel) Export
	
	If Source.DataExchange.Load Then
		WriteFileDataToRegisterDuringExchange(Source);
		Return;
	EndIf;
	
	AttachedFilesInternal.OnWriteAttachedFileServer(
		Source.FileOwner);
		
	AttachedFilesInternal.OnUpdatingTextExtractionQueueState(
		Source.Ref, Source.TextExtractionStatus);
	
EndProcedure

// Handler of the FormGetProcessing event for overriding attached file form.
//
// Parameters:
//  Source             - CatalogManager - AttachedFiles catalog manager.
//  FormType           - String - name of standard forms.
//  Parameters         - Structure - form parameters.
//  SelectedForm       - String - name or metadata object of opened form.
//  AdditionalInfo     - Structure - additional information about opening form.
//  StandardProcessing - Boolean - flag that shows whether the standard processing is used.
//
Procedure OverrideAttachedFileForm(Source, FormType, Parameters,
			SelectedForm, AdditionalInfo, StandardProcessing) Export
	
	If FormType = "ObjectForm" Then
		SelectedForm = "CommonForm.AttachedFile";
		StandardProcessing = False;
		
	ElsIf FormType = "ListForm" Then
		SelectedForm = "CommonForm.AttachedFiles";
		StandardProcessing = False;
	EndIf;
	
EndProcedure

// Handler of the BeforeWrite event of attached file owner.
// Marks for deletion related files.
//
// Parameters:
//  Source - Object - owner of the attached file, except DocumentObject.
//  Cancel - Boolean - Cancellation flag.
// 
Procedure SetAttachedFileDeletionMarks(Source, Cancel) Export
	
	If Source.DataExchange.Load Then
		Return;
	EndIf;
	
	MarkForDeletionAttachedFiles(Source);
	
EndProcedure

// Handler of the BeforeWrite event of attached file owner.
// Marks for deletion related files.
//
// Parameters:
//  Source      - DocumentObject - attached file owner.
//  Cancel      - Boolean - parameter passed to the BeforeWrite event subscription.
//  WriteMode   - Boolean - parameter passed to the BeforeWrite event subscription.
//  PostingMode - Boolean - parameter passed to the BeforeWrite event subscription.
// 
Procedure SetDocumentAttachedFileDeletionMark(Source, Cancel, WriteMode, PostingMode) Export
	
	If Source.DataExchange.Load Then
		Return;
	EndIf;
	
	MarkForDeletionAttachedFiles(Source);
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions

// Returns error message text with reference
// to the stored file catalog item.
//
Function ErrorTextWhenYouReceiveFile(Val ErrorInfo, Val File)
	
	ErrorMessage = BriefErrorDescription(ErrorInfo);
	
	If File <> Undefined Then
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = '%1
			           |
			           |File reference: %2.'"),
			ErrorMessage,
			GetURL(File) );
	EndIf;
	
	Return ErrorMessage;
	
EndFunction

// Returns attached file owner ID.
Function GetObjectID(Val FilesOwner)
	
	QueryText =
	"SELECT
	|	AttachmentExistence.ObjectIdentifier
	|FROM
	|	InformationRegister.AttachmentExistence AS AttachmentExistence
	|WHERE
	|	AttachmentExistence.ObjectWithFiles = &ObjectWithFiles";
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("ObjectWithFiles", FilesOwner);
	ExecutionResult = Query.Execute();
	
	If ExecutionResult.IsEmpty() Then
		Return "";
	EndIf;
	
	Selection = ExecutionResult.Select();
	Selection.Next();
	
	Return Selection.ObjectIdentifier;
	
EndFunction

Procedure MarkForDeletionAttachedFiles(Val Source, CatalogName = Undefined)
	
	If Source.IsNew() Then
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	
	SourceRefDeletionMark = CommonUse.ObjectAttributeValue(Source.Ref, "DeletionMark");
	
	If Source.DeletionMark = SourceRefDeletionMark Then
		Return;
	EndIf;
	
	Try
		CatalogNames = AttachedFilesInternal.FileStorageCatalogNames(
			TypeOf(Source.Ref));
	Except
		ErrorPresentation = BriefErrorDescription(ErrorInfo());
		Raise NStr("en = 'Error when marking attached files for deletion.'")
			+ Chars.LF
			+ ErrorPresentation;
	EndTry;
	
	Query = New Query;
	Query.SetParameter("FileOwner", Source.Ref);
	
	QueryText =
	"SELECT
	|	Files.Ref AS Ref,
	|	Files.Edits AS Edits
	|FROM
	|	&CatalogName AS Files
	|WHERE
	|	Files.FileOwner = &FileOwner";
	
	For Each CatalogNameDescription In CatalogNames Do
		
		FullCatalogName = "Catalog." + CatalogNameDescription.Key;
		Query.Text = StrReplace(QueryText, "&CatalogName", FullCatalogName);
		
		Selection = Query.Execute().Select();
		
		While Selection.Next() Do
			If Source.DeletionMark And Not Selection.Edits.IsEmpty() Then
				Raise StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = '""%1"" object can not be deleted
					           |because contains
					           |the edited attached file %2.'"),
					String(Source.Ref),
					String(Selection.Ref));
			EndIf;
			FileObject = Selection.Ref.GetObject();
			FileObject.Lock();
			FileObject.SetDeletionMark(Source.DeletionMark);
		EndDo;
	EndDo;
	
EndProcedure

Procedure WriteFileDataToRegisterDuringExchange(Val Source)
	
	Var FileBinaryData;
	
	If Source.AdditionalProperties.Property("FileBinaryData", FileBinaryData) Then
		RecordSet = InformationRegisters.AttachedFiles.CreateRecordSet();
		RecordSet.Filter.AttachedFile.Use = True;
		RecordSet.Filter.AttachedFile.Value = Source.Ref;
		
		Write = RecordSet.Add();
		Write.AttachedFile = Source.Ref;
		Write.StoredFile = New ValueStorage(FileBinaryData, New Deflation(9));
		
		RecordSet.DataExchange.Load = True;
		RecordSet.Write();
		
		Source.AdditionalProperties.Delete("FileBinaryData");
	EndIf;
	
EndProcedure

#EndRegion