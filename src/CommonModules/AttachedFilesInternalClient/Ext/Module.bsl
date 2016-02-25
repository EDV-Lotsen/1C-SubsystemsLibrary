////////////////////////////////////////////////////////////////////////////////
// Attached files subsystem.
//
////////////////////////////////////////////////////////////////////////////////
#Region InternalProceduresAndFunctions
// Adds files to the list by dragging.
//
// Parameters:
//  FileOwner       - Ref - file owner.
//  FormID          - form UUID.
//  FileNameArray   - Array of Strings - file paths.
//
Procedure AddFilesWithDrag(Val FileOwner, Val FormID, Val FileNameArray) Export
	
	AttachedFilesArray = New Array;
	PutSelectedFilesInStorage(
		FileNameArray,
		FileOwner,
		AttachedFilesArray,
		FormID);
	
	If AttachedFilesArray.Count() = 1 Then
		AttachedFile = AttachedFilesArray[0];
		
		ShowUserNotification(
			NStr("en = 'Creating attached file'"),
			GetURL(AttachedFile),
			AttachedFile,
			PictureLib.Information32);
		
		FormParameters = New Structure("AttachedFile, IsNew", AttachedFile,
True);
		OpenForm("CommonForm.AttachedFile", FormParameters, , AttachedFile);
	EndIf;
	
	If AttachedFilesArray.Count() > 0 Then
		NotifyChanged(AttachedFilesArray[0]);
		Notify("Write_AttachedFile", New Structure("IsNew", True),
AttachedFilesArray);
	EndIf;
	
EndProcedure
// Puts a file from the hard disk into the storage of attached files (web client).
//
// Parameters:
//  ResultHandler          - NotifyDescription - procedure that gets the control after the execution.
//                             Parameters of that procedure:
//                               AttachedFile         - Ref, Undefined - reference to a newly added file, or
//                                                      Undefined if the file is not in storage.
//                               AdditionalParameters - Arbitrary - value that was specified when creating the notification object.
//  FileOwner             - reference to the file owner.
//  FileOperationSettings - Structure.
//  FormID                - form UUID.
//
Procedure PutSelectedFilesInWebStorage(ResultHandler, Val FileOwner, Val FormID)
	
	Parameters = New Structure;
	Parameters.Insert("FileOwner", FileOwner);
	Parameters.Insert("ResultHandler", ResultHandler);
	
	NotifyDescription = New NotifyDescription
("PutSelectedFilesInWebStorageEnd", ThisObject, Parameters);
	BeginPutFile(NotifyDescription, , ,True, FormID);
	
EndProcedure
// Continues PutSelectedFilesInWebStorage procedure execution.
Procedure PutSelectedFilesInWebStorageEnd(Result, Address, SelectedFileName, AdditionalParameters) Export
	
	If Not Result Then
		ExecuteNotifyProcessing(AdditionalParameters.ResultHandler,
Undefined);
		Return;
	EndIf;
	
	TempFileStorageAddress = Address;
	FileName = SelectedFileName;
	FileOwner = AdditionalParameters.FileOwner;
	
	PathStrings = CommonUseClientServer.ParseStringByDotsAndSlashes(FileName);
	
	If PathStrings.Count() >= 2 Then
		Extension = PathStrings[PathStrings.Count()-1];
		BaseName = PathStrings[PathStrings.Count()-2];
	Else
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Cannot put file
			           |%1
			           |in a temporary storage.'"),
			FileName);
	EndIf;
	
	FileFunctionsInternalClientServer.CheckExtentionOfFileToDownload(Extension);
	
	// Creating file cards in the infobase
	AttachedFile = AttachedFilesInternalServerCall.AppendFile(
		FileOwner,
		BaseName,
		Extension,
		,
		,
		TempFileStorageAddress,
		"");
		
	ExecuteNotifyProcessing(AdditionalParameters.ResultHandler,
AttachedFile);
	
EndProcedure
// Puts the edited files in the storage.
// This procedure is used as a handler of the command that ends the file editing.
//
// Parameters
//  ResultHandler - NotifyDescription - procedure that gets the control after the execution.
//                    Parameters of that procedure:
//                      FileInfo - Structure, Undefined - information about the stored file.
//                                 If the file is not stored, returns Undefined.
//                      AdditionalParameters - Arbitrary - value that was specified
//                                 when creating the notification object.
//  FileData      - Structure with file data.
//  FormID        - form UUID.
//
Procedure PutFileEditedOnHardDiskInStorage(ResultHandler, Val FileData, Val FormID) Export
	
	Parameters = New Structure;
	Parameters.Insert("ResultHandler", ResultHandler);
	Parameters.Insert("FileData", FileData);
	Parameters.Insert("FormID", FormID);
	
	NotifyDescription = New NotifyDescription("PutFileEditedOnHardDiskInStorageExtensionSuggested", ThisObject, Parameters);
	CommonUseClient.ShowFileSystemExtensionInstallationQuestion(NotifyDescription);
	
EndProcedure
// Continues PutFileEditedOnHardDiskInStorage procedure execution.
Procedure PutFileEditedOnHardDiskInStorageExtensionSuggested(FileSystemExtensionAttached, AdditionalParameters) Export
	
	FileData = AdditionalParameters.FileData;
	FormID= AdditionalParameters.FormID;
	
	If FileSystemExtensionAttached Then
		UserWorkingDirectory = FileFunctionsInternalClient.UserWorkingDirectory();
		FullFileNameAtClient = UserWorkingDirectory + FileData.RelativePath + FileData.FileName;
		
		FileInfo = Undefined;
		File = New File(FullFileNameAtClient);
		If File.Exist() Then
			FileInfo = AttachedFilesClient.PutFileToStorage(FullFileNameAtClient, FormID);
		Else
			CommonUseClientServer.MessageToUser(
				NStr("en = 'The file is not found in the working directory.'"));
		EndIf;
		
		ExecuteNotifyProcessing(AdditionalParameters.ResultHandler, FileInfo);
	Else
		NotifyDescription = New NotifyDescription("PutFileEditedOnHardDiskInStoragePuttingCompleted", ThisObject, AdditionalParameters);
		PutFileOnHardDiskInWebStorage(NotifyDescription, FileData, FormID);
	EndIf;
	
EndProcedure
// Continues PutFileEditedOnHardDiskInStorage procedure execution.
Procedure PutFileEditedOnHardDiskInStoragePuttingCompleted(FileInfo, AdditionalParameters) Export
	FileData = AdditionalParameters.FileData;
	If FileInfo = Undefined Or FileData.FileName = FileInfo.FileName Then
		ExecuteNotifyProcessing(AdditionalParameters.ResultHandler, FileInfo);
		Return;
	EndIf;
	
	QuestionText = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = 'The selected file name
		           |1%
		           |differs from the file name in the storage
		           |2%.
		           |
		           |Do you want to continue?'"),
		FileInfo.FileName,
		FileData.FileName);
		
	AdditionalParameters.Insert("FileInfo", FileInfo);
	NotifyDescription = New NotifyDescription("PutFileEditedOnHardDiskInStorageAnswerReceived", ThisObject, AdditionalParameters);
	ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.OKCancel);
EndProcedure
// Continues PutFileEditedOnHardDiskInStorage procedure execution.
Procedure PutFileEditedOnHardDiskInStorageAnswerReceived(QuestionResult, AdditionalParameters) Export
	Result = Undefined;
	If QuestionResult = DialogReturnCode.OK Then
		Result = AdditionalParameters.FileInfo;
	EndIf;
	ExecuteNotifyProcessing(AdditionalParameters.ResultHandler, Result);
EndProcedure
// Selects a file on the hard disk and puts it in a temporary storage on the server.
//
// Parameters:
//  ResultHandler - NotifyDescription - procedure that gets the control after the execution.
//                    Parameters of that procedure:
//                      FileInfo - Structure, Undefined - information about the stored file. 
//                                 If the file is not stored, returns Undefined.
//                      AdditionalParameters - Arbitrary - value that was specified 
//                                 when creating the notification object.
//  FileData      - Structure with file data.
//  FileInfo      - Structure (return value) - file information.
//  FormID        - form UUID.
//
Procedure SelectFileOnHardDiskAndPutToStorage(ResultHandler, Val FileData,
Val FormID) Export
	
	Parameters = New Structure;
	Parameters.Insert("ResultHandler", ResultHandler);
	Parameters.Insert("FileData", FileData);
	Parameters.Insert("FormID", FormID);
	
	NotifyDescription = New NotifyDescription("SelectFileOnHardDiskAndPutToStorageExtensionSuggested", ThisObject, Parameters);
	CommonUseClient.ShowFileSystemExtensionInstallationQuestion(NotifyDescription);
	
EndProcedure
// Continues SelectFileOnHardDiskAndPutToStorage procedure execution.
Procedure SelectFileOnHardDiskAndPutToStorageExtensionSuggested(FileSystemExtensionAttached, AdditionalParameters) Export
	
	FileData = AdditionalParameters.FileData;
	FormID = AdditionalParameters.FormID;
	
	If FileSystemExtensionAttached Then
		SelectFile = New FileDialog(FileDialogMode.Open);
		SelectFile.Multiselect = False;
		SelectFile.FullFileName = FileData.Description + "." + FileData.Extension;
		SelectFile.DefaultExt = FileData.Extension;
		SelectFile.Filter = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'All files  (*.%1)|*.%1'"), FileData.Extension);
		
		FileInfo = Undefined;
		If SelectFile.Choose() Then
			FileInfo = AttachedFilesClient.PutFileToStorage(SelectFile.FullFileName, FormID);
		EndIf;
		
		ExecuteNotifyProcessing(AdditionalParameters.ResultHandler, FileInfo);
	Else
		NotifyDescription = New NotifyDescription("SelectFileOnHardDiskAndPutToStoragePlacementCompleted", ThisObject);
		PutFileOnHardDiskInWebStorage(NotifyDescription, FileData, FormID);
	EndIf;
	
EndProcedure
// Continues SelectFileOnHardDiskAndPutToStorage procedure execution.
Procedure SelectFileOnHardDiskAndPutToStoragePuttingCompleted(FileInfo, AdditionalParameters) Export
	
	ExecuteNotifyProcessing(AdditionalParameters.ResultHandler,
FileInfo);
	
EndProcedure
// Puts a file on the client disk in a temporary storage.
// Identical to PutFileOnHardDiskInWebStorage() 
// but intended for the web client without file system extension.
//
// Parameters:
//  ResultHandler - NotifyDescription - procedure that gets the control after the execution.
//                    Parameters of that procedure:
//                      FileInfo - Structure, Undefined - information about the stored file. 
//                                 If the file is not stored, returns Undefined.
//                      AdditionalParameters - Arbitrary - value that was specified when creating the notification object.
//  FileData      - Structure with file data.
//  FileInfo      - Structure (return value) with file information.
//  FormID        - form UUID.
//
Procedure PutFileOnHardDiskInWebStorage(ResultHandler, Val FileData, Val
FormID)
	
	Parameters = New Structure;
	Parameters.Insert("ResultHandler", ResultHandler);
	
	NotifyDescription = New NotifyDescription("PutFileOnHardDiskIntoWebStoragePlacementCompleted", ThisObject, Parameters);
	BeginPutFile(NotifyDescription, , FileData.FileName, True,
FormID);
	
EndProcedure
// Continues PutFileOnHardDiskInWebStorage procedure execution.
Procedure PutFileOnHardDiskInWebStoragePuttingCompleted(Result, TempFileStorageAddress, SelectedFileName, AdditionalParameters) Export
	
	If Not Result Then
		ExecuteNotifyProcessing(AdditionalParameters.ResultHandler,
Undefined);
		Return;
	EndIf;
	
	PathStrings = CommonUseClientServer.ParseStringByDotsAndSlashes
(SelectedFileName);
	
	If PathStrings.Count() >= 2 Then
		NewName = PathStrings[PathStrings.Count()-2];
		NewExtension = PathStrings[PathStrings.Count()-1];
		FileName = NewName + "." + NewExtension;
	ElsIf PathStrings.Count() = 1 Then
		NewName = PathStrings[0];
		NewExtension = "";
		FileName = NewName;
	EndIf;
	
	FileFunctionsInternalClientServer.CheckExtentionOfFileToDownload
(NewExtension);
	
	FileInfo = New Structure;
	FileInfo.Insert("ModificationDateUniversal",   Undefined);
	FileInfo.Insert("FileAddressInTempStorage",    TempFileStorageAddress);
	FileInfo.Insert("TempTextStorageAddress", "");
	FileInfo.Insert("FileName",                    FileName);
	FileInfo.Insert("Extension",                   NewExtension);
	
	ExecuteNotifyProcessing(AdditionalParameters.ResultHandler, FileInfo);
	
EndProcedure
// Opens the directory with the file (gets the file from the storage if needed).
// This procedure is used as a handler of the command that opens the file directory.
//
// Parameters:
//  FileData - Structure with file data.
//
Procedure OpenDirectoryWithFile(Val FileData) Export
	
	Parameters = New Structure;
	Parameters.Insert("FileData", FileData);
	
	NotifyDescription = New NotifyDescription
("OpenDirectoryWithFileExtensionSuggested", ThisObject, Parameters);
	CommonUseClient.ShowFileSystemExtensionInstallationQuestion
(NotifyDescription);
	
EndProcedure
// Continues OpenDirectoryWithFile procedure execution.
Procedure OpenDirectoryWithFileExtensionSuggested(FileSystemExtensionAttached, AdditionalParameters) Export
	Var FullFileName;
	
	FileData = AdditionalParameters.FileData;
	If FileSystemExtensionAttached Then
		UserWorkingDirectory = FileFunctionsInternalClient.UserWorkingDirectory
();
		If IsBlankString(UserWorkingDirectory) Then
			ShowMessageBox(, NStr("en = 'Working directory is not set'"));
			Return;
		EndIf;
		
		FullPath = UserWorkingDirectory + FileData.RelativePath + FileData.FileName;
		File = New File(FullPath);
		If Not File.Exist() Then
			QuestionText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'File 1%
				           |is missing from the working directory.
				           |
				           |Get the file from the storage?'"),
				File.Name);
			AdditionalParameters.Insert("UserWorkingDirectory",
UserWorkingDirectory);
			AdditionalParameters.Insert("FullPath", FullPath);
			NotifyDescription = New NotifyDescription("OpenDirectoryWithFileAnswerReceived", ThisObject, AdditionalParameters);
			ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo);
		EndIf;
		
		FileFunctionsInternalClient.OpenExplorerWithFile(FullPath);
	Else
		FileFunctionsInternalClient.ShowFileSystemExtensionRequiredMessageBox
(Undefined);
	EndIf;
	
EndProcedure
// Continues OpenDirectoryWithFile procedure execution.
Procedure OpenDirectoryWithFileAnswerReceived(QuestionResult, AdditionalParameters)
Export
	
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	FileData = AdditionalParameters.FileData;
	UserWorkingDirectory = AdditionalParameters.UserWorkingDirectory;
	FullPath = AdditionalParameters.FullPath;
	
	FullFileNameAtClient = "";
	AttachedFilesClient.GetFileToWorkingDirectory(
		FileData.FileBinaryDataRef,
		FileData.RelativePath,
		FileData.ModificationDateUniversal,
		FileData.FileName,
		UserWorkingDirectory,
		FullFileNameAtClient);
		
	FileFunctionsInternalClient.OpenExplorerWithFile(FullPath);
	
EndProcedure
////////////////////////////////////////////////////////////////////////////////
// DIGITAL SIGNATURES
// Signs the attached file:
// - prompts a user to choose a digital signature for signing the file and gets signature data,
// - writes a file with a digital signature to the storage.
// This procedure is used in the handler of Sign command of the list form.
//
// Parameters:
//  ExecutionParameters - Structure - contains the following parameters:
//   * AttachedFile          - CatalogRef.AttachedFiles - reference to the file.
//   * FileData              - Structure - file data.
//   * UserNotification      - Structure - parameters of the notification displayed to the user
//                             when the file is signed:
//                               Text, URL, Explanation, Picture.
//                           - Undefined - do not display the notification.
//                               If this parameter is not set, the standard notification is used.
//   * ResultProcessing      - NotifyDescription - Boolean - if True, the file is successfully signed.
//
Procedure GenerateFileSignature(ExecutionParameters) Export
	
	SelectDigitalSignatureCertificatesAndGenerateSignatureData(
		New NotifyDescription(
			"GenerateFileSignatureSignatureReceived", ThisObject, ExecutionParameters),
		ExecutionParameters.AttachedFile,
		ExecutionParameters.FileData);
	
EndProcedure
// Continues GenerateFileSignature procedure execution.
Procedure GenerateFileSignatureSignatureReceived(SignatureData, ExecutionParameters) Export
	
	SignatureGenerated = SignatureData <> Undefined;
	
	If SignatureGenerated Then
		AttachedFile = ExecutionParameters.AttachedFile;
		
		AttachedFilesInternalServerCall.RecordSingleSignatureDetails(
			AttachedFile, SignatureData);
		
		NotifyChanged(AttachedFile);
		Notify("Write_AttachedFile", New Structure, AttachedFile);
		
		If ExecutionParameters.Property("UserNotification") Then
			Notification = ExecutionParameters.UserNotification;
			If Notification = Undefined Then
				//PARTIALLY_DELETED
				//DigitalSignatureClient.ObjectSigningInfo(AttachedFile);
			Else
				ShowUserNotification(
					Notification.Text,
					Notification.URL,
					Notification.Explanation,
					Notification.Picture);
			EndIf;
		EndIf;
	EndIf;
	
	If ExecutionParameters.Property("ResultProcessing") Then
		ExecuteNotifyProcessing(ExecutionParameters.ResultProcessing,
SignatureGenerated);
	EndIf;
	
EndProcedure
// Generates a signature for a binary data file:
// - displays the digital signature selection dialog to a user,
// - signs the binary data of the attached file to get the signature.
//
// Parameters:
//  ResultHandler - NotifyDescription - procedure that gets the control after the execution.
//                    Parameters of that procedure:
//                      SignatureData - Structure, Undefined - generated signature, or Undefined 
//                                      if the signature is not generated.
//                      AdditionalParameters - Arbitrary - value that was specified 
//                                      when creating the notification object.
//  AttachedFile  - reference to the file.
//  FileData      - structure with file data.
//
Procedure SelectDigitalSignatureCertificatesAndGenerateSignatureData(ResultHandler, Val AttachedFile, Val FileData) Export
	
	If Not AttachCryptoExtension() Then
		FileFunctionsInternalClient.ShowCryptoExtensionRequiredMessageBox
(Undefined);
		ExecuteNotifyProcessing(ResultHandler, Undefined);
		Return;
	EndIf;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ResultHandler", ResultHandler);
	AdditionalParameters.Insert("AttachedFile", AttachedFile);
	AdditionalParameters.Insert("FileData", FileData);
	NotifyDescription = New NotifyDescription("SelectDigitalSignatureCertificatesAndGenerateSignatureDataSignatureSelected", ThisObject, AdditionalParameters);
	
	//PARTIALLY_DELETED
	//CertificateStructureArray = DigitalSignatureClient.GetCertificateStructureArray(True);
	CertificateStructureArray = New Array;
	FormParameters = New Structure("CertificateStructureArray, ObjectRef", CertificateStructureArray, AttachedFile);
	//PARTIALLY_DELETED
	//OpenForm("CommonForm.DigitalSignatureSetup", FormParameters, , , , , NotifyDescription);
	
EndProcedure
// Continues SelectDigitalSignatureCertificatesAndGenerateSignatureData procedure execution.
Procedure SelectDigitalSignatureCertificatesAndGenerateSignatureDataSignatureSelected(SignatureParameterStructure, AdditionalParameters) Export
	
	AttachedFile = AdditionalParameters.AttachedFile;
	FileData = AdditionalParameters.FileData;
	
	If TypeOf(SignatureParameterStructure) <> Type("Structure") Then
		ExecuteNotifyProcessing(AdditionalParameters.ResultHandler,
Undefined);
		Return;
	EndIf;
	
	BinaryData = GetFromTempStorage(FileData.FileBinaryDataRef);
	
	//PARTIALLY_DELETED
	//Cancel = False;
	//CryptoManager = DigitalSignatureClient.GetCryptoManager(Cancel);
	Cancel = True;
	CryptoManager = Undefined;
	If Cancel Then
		ExecuteNotifyProcessing(AdditionalParameters.ResultHandler, Undefined);
		Return;
	EndIf;
	
	//PARTIALLY_DELETED
//	SignatureData = DigitalSignatureClient.GenerateSignatureData(
//		CryptoManager,
//		AttachedFile,
//		BinaryData,
//		SignatureParameterStructure);
//	
//	ExecuteNotifyProcessing(AdditionalParameters.ResultHandler,
//SignatureData);
	
EndProcedure
// Adds a digital signature from file(s) on the hard disk.
//
// Parameters:
//  AttachedFile   - reference to the file to be signed.
//  FormID         - form UUID.
//
Procedure AddDigitalSignatureFromFile(Val AttachedFile, Val FormID=
Undefined) Export
	
	If Not AttachCryptoExtension() Then
		FileFunctionsInternalClient.ShowCryptoExtensionRequiredMessageBox
(Undefined);
		Return;
	EndIf;
	
	Parameters = New Structure;
	Parameters.Insert("AttachedFile", AttachedFile);
	Parameters.Insert("FormID", FormID);
	
	NotifyDescription = New NotifyDescription("AddDigitalSignatureFromFileExtensionSuggested", ThisObject, Parameters);
	CommonUseClient.ShowFileSystemExtensionInstallationQuestion
(NotifyDescription);
	
EndProcedure
// Continues AddDigitalSignatureFromFile procedure execution.
Procedure AddDigitalSignatureFromFileExtensionSuggested(FileSystemExtensionAttached, AdditionalParameters) Export
	
	AttachedFile = AdditionalParameters.AttachedFile;
	FormID = AdditionalParameters.FormID;
	
	If FileSystemExtensionAttached Then
		NotifyDescription = New NotifyDescription("AddDigitalSignatureFromFileSignaturesReceived", ThisObject, AttachedFile);
		GetSignatureArray(NotifyDescription, AttachedFile, FormID);
		Return;
	Else
		FileFunctionsInternalClient.ShowFileSystemExtensionRequiredMessageBox
(Undefined);
	EndIf;
	
EndProcedure
// Continues AddDigitalSignatureFromFile procedure execution.
Procedure AddDigitalSignatureFromFileSignaturesReceived(ArrayOfSignatures, AttachedFile) Export
	
	If ArrayOfSignatures.Count() > 0 Then
		AttachedFilesInternalServerCall.RecordMultipleSignatureDetails(AttachedFile, ArrayOfSignatures);
		NotifyAboutAddingSignaturesFromFile(AttachedFile, ArrayOfSignatures.Count());
	EndIf;
	
EndProcedure
// Calls the dialog for adding signatures and returns the signatures.
//
// SPECIAL CONDITIONS
// Requires the file system extension and cryptoprotection extension attached.
//
// Parameters:
//  ResultHandler - NotifyDescription - procedure that gets the control after the execution.
//                    Parameters of that procedure:
//                      Signatures - Array - array of signature structures.
//                      AdditionalParameters - Arbitrary - value that was specified 
//                                             when creating the notification object.
//  AttachedFile   - reference to the file.
//  FormID         - form UUID.
//
Procedure GetSignatureArray(ResultHandler, Val AttachedFile, Val FormID = Undefined) Export
	
	Parameters = New Structure;
	Parameters.Insert("ResultHandler", ResultHandler);
	Parameters.Insert("AttachedFile", AttachedFile);
	Parameters.Insert("FormID", FormID);
	
	NotifyDescription = New NotifyDescription("GetSignatureArraySignaturesAdded", ThisObject, Parameters);
	OpenForm("CommonForm.AddSignatureFromFile", , , , , , NotifyDescription);
	
EndProcedure
// Continues GetSignatureArray procedure execution.
Procedure GetSignatureArraySignaturesAdded(SignatureFileArray, AdditionalParameters) Export
	
	Result = New Array;
	//PARTIALLY_DELETED
	//If TypeOf(SignatureFileArray) = Type("Array") And SignatureFileArray.Count() > 0 Then
	//	Result = DigitalSignatureClient.GenerateSignaturesToAddToDatabase(AdditionalParameters.AttachedFile,
	//		SignatureFileArray, AdditionalParameters.FormID);
	//EndIf;
	
	ExecuteNotifyProcessing(AdditionalParameters.ResultHandler, Result);
	
EndProcedure
// Internal procedure used to notify the system about the object change 
// and also to display a user notification about adding the signatures.
// Parameters
//  AttachedFile    - reference to the file with signatures added.
//  SignatureNumber - number of added signatures.
//
Procedure NotifyAboutAddingSignaturesFromFile(AttachedFile, SignatureCount)
Export
	
	NotifyChanged(AttachedFile);
	
	If SignatureCount = 1 Then
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'A signature from file is added to ""%1"".'"),
			AttachedFile);
	Else
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Signatures from files are added to ""%1"".'"),
			AttachedFile);
	EndIf;
	
	Status(MessageText);
	
EndProcedure
////////////////////////////////////////////////////////////////////////////////
// Encryption.
// Encrypts file in the storage:
// - prompts the user to select encryption certificates,
// - encrypts the file,
// - writes the encrypted data with thumbprints to the storage,
// - notifies the user and the system about the changes made.
// The procedure is used in the file encryption command handler.
//
// Parameters:
//  AttachedFile  - reference to the file to be encrypted.
//  FileData      - structure with file data.
//  FormID        - form UUID.
//
Procedure Encrypt(Val AttachedFile, Val FileData, Val FormID)
Export
	
	Parameters = New Structure;
	Parameters.Insert("AttachedFile", AttachedFile);
	Parameters.Insert("FileData", FileData);
	NotifyDescription = New NotifyDescription("EncryptDataReceived", ThisObject, Parameters);
	GetEncryptedData(NotifyDescription, AttachedFile, FileData, FormID);
	
EndProcedure
// Continues Encrypt procedure execution.
Procedure EncryptDataReceived(ReceivingResult, AdditionalParameters) Export
	
	If ReceivingResult = Undefined Then
		Return;
	EndIf;
	
	EncryptedData = ReceivingResult.EncryptedData;
	ThumbprintArray = ReceivingResult.ThumbprintArray;
	FileData = AdditionalParameters.FileData;
	AttachedFile = AdditionalParameters.AttachedFile;
	
	AttachedFilesInternalServerCall.Encrypt(AttachedFile, EncryptedData, ThumbprintArray);
	NotifyChangedAndDeleteFileInWorkingDirectory(AttachedFile, FileData);
	
EndProcedure
// Encrypts file binary data using the certificates selected by the user.
//
// Parameters:
//  ResultHandler - NotifyDescription - procedure that gets the control after the execution.
//                    Parameters of that procedure:
//                      Result - Structure, Undefined - if data is not encrypted, it is set to Undefined,
//                                                      otherwise it is a structure with the following fields:
//                         EncryptedData   - Structure  - contains encrypted file data (for writing).
//                         ThumbprintArray - Array      - contains thumbprints.
//                      AdditionalParameters - Arbitrary - value that was specified when creating the notification object.
//  AttachedFile   - reference to the file.
//  FileData       - structure with file data.
//  FormID         - form UUID.
//
Procedure GetEncryptedData(ResultHandler, Val AttachedFile, Val FileData, Val FormID) Export
	
	If Not AttachCryptoExtension() Then
		FileFunctionsInternalClient.ShowCryptoExtensionRequiredMessageBox
(Undefined);
		ExecuteNotifyProcessing(ResultHandler, Undefined);
		Return;
	EndIf;
	
	If FileData.Encrypted Then
		ShowMessageBox(, StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'File 1%
			           |is already encrypted.'"), String(AttachedFile)));
		ExecuteNotifyProcessing(ResultHandler, Undefined);
		Return;
	EndIf;
	
	If Not FileData.Edits.IsEmpty() Then
		ShowMessageBox(, NStr("en = The file is locked and cannot be encrypted.'"));
		ExecuteNotifyProcessing(ResultHandler, Undefined);
		Return;
	EndIf;
	
	//PARTIALLY_DELETED
	//CertificateStructureArray = DigitalSignatureClient.GetCertificateStructureArray(False);
	CertificateStructureArray = New Array;
	PersonalCertificateThumbprintForEncryption = FileFunctionsInternalClientServer.PersonalFileOperationSettings().PersonalCertificateThumbprintForEncryption;
	
	// The thumbprint stored in SettingsStorage can be out of date because the certificate might be deleted.
	If PersonalCertificateThumbprintForEncryption <> Undefined And Not IsBlankString(PersonalCertificateThumbprintForEncryption) Then
		//PARTIALLY_DELETED
		//Certificate = DigitalSignatureClient.GetCertificateByThumbprint(PersonalCertificateThumbprintForEncryption, True); // OnlyPersonal
		Certificate = Undefined;
		If Certificate = Undefined Then
			PersonalCertificateThumbprintForEncryption = "";
		EndIf;
	EndIf;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ResultHandler", ResultHandler);
	AdditionalParameters.Insert("CertificateStructureArray", CertificateStructureArray);
	AdditionalParameters.Insert("AttachedFile", AttachedFile);
	AdditionalParameters.Insert("PersonalCertificateThumbprintForEncryption", PersonalCertificateThumbprintForEncryption);
	AdditionalParameters.Insert("FileData", FileData);
	AdditionalParameters.Insert("FormID", FormID);
	
	If PersonalCertificateThumbprintForEncryption = Undefined
	 Or IsBlankString(PersonalCertificateThumbprintForEncryption) Then
	 	//PARTIALLY_DELETED
		//PersonalCertificateStructureArray = DigitalSignatureClient.GetCertificateStructureArray(True); // OnlyPersonal
		//FormParameters = New Structure("CertificateStructureArray", PersonalCertificateStructureArray);
		//NotifyDescription = New NotifyDescription("GetEncryptedDataCertificateSelected", ThisObject, AdditionalParameters);
		//OpenForm("CommonForm.PersonalEncryptionCertificates", FormParameters, , , , , NotifyDescription);
	Else
		GetEncryptedDataCertificateSelection(AdditionalParameters);
	EndIf;
	
EndProcedure
// Continues GetEncryptedData procedure execution.
Procedure GetEncryptedDataCertificateSelected(SelectedCertificate,
AdditionalParameters) Export
	
	If TypeOf(SelectedCertificate) = Type("Structure") Then
		AdditionalParameters.Insert("PersonalCertificateThumbprintForEncryption", SelectedCertificate.Thumbprint);
		GetEncryptedDataCertificateSelection(AdditionalParameters);
	Else
		ShowMessageBox(, NStr("en = 'Personal encryption certificate is not selected.'"));
		ExecuteNotifyProcessing(AdditionalParameters.ResultHandler,
Undefined);
		Return;
	EndIf;
	
EndProcedure
// Continues GetEncryptedData procedure execution.
Procedure GetEncryptedDataCertificateSelection(AdditionalParameters) Export
	
	FormParameters = New Structure;
	FormParameters.Insert("CertificateStructureArray", AdditionalParameters.CertificateStructureArray);
	FormParameters.Insert("FileRef", AdditionalParameters.AttachedFile);
	FormParameters.Insert("PersonalCertificateThumbprintForEncryption", AdditionalParameters.PersonalCertificateThumbprintForEncryption);
	
	NotifyDescription = New NotifyDescription
("GetEncryptedDataCertificatesSelected", ThisObject, AdditionalParameters);
	//PARTIALLY_DELETED
	//OpenForm("CommonForm.SelectEncryptionCertificates", FormParameters, , , , , NotifyDescription);
	
EndProcedure
// Continues GetEncryptedData procedure execution.
Procedure GetEncryptedDataCertificatesSelected(CertificateArray,
AdditionalParameters) Export
	Var EncryptedData, ThumbprintArray;
	
	Result = Undefined;
	
	If TypeOf(CertificateArray) = Type("Array") Then
		FileData = AdditionalParameters.FileData;
		FormID = AdditionalParameters.FormID;
		If ExecuteEncryptionByParameters(CertificateArray, FileData,
FormID, EncryptedData, ThumbprintArray) Then
			Result = New Structure;
			Result.Insert("EncryptedData", EncryptedData);
			Result.Insert("ThumbprintArray", ThumbprintArray);
		EndIf;
	EndIf;
	
	ExecuteNotifyProcessing(AdditionalParameters.ResultHandler, Result);
	
EndProcedure
// Encrypts binary file data according to the specified array of certificates.
//
// Parameters:
//  CertificateArray  - array of certificates for encryption.
//  FileData          - file data structure.
//  FormID            - form UUID.
//  EncryptedData     - Structure (return value) - contains the encrypted file data.
//  ThumbprintArray   - Array    (return value) - contains thumbprints.
//
// Returns:
//  True - encryption is completed, otherwise False.
//
Function ExecuteEncryptionByParameters(Val CertificateArray,
                                       Val FileData,
                                       Val FormID,
                                       EncryptedData,
                                       ThumbprintArray)
	
	ThumbprintArray = New Array;
	
	For Each Certificate In CertificateArray Do
		Thumbprint = Base64String(Certificate.Thumbprint);
		//PARTIALLY_DELETED
		//Presentation = DigitalSignatureClientServer.GetUserPresentation(Certificate.Subject);
		Presentation = "";
		CertificateBinaryData = Certificate.Unload();
		
		ThumbprintStructure = New Structure("Thumbprint, Presentation, Certificate", Thumbprint, Presentation, CertificateBinaryData);
		ThumbprintArray.Add(ThumbprintStructure);
	EndDo;
	
	Status(NStr("en = 'Encrypting file...'"));
	
	//PARTIALLY_DELETED
	//Cancel = False;
	//CryptoManager = DigitalSignatureClient.GetCryptoManager(Cancel);
	Cancel = True;
	CryptoManager = Undefined;
	If Cancel Then
		Return False;
	EndIf;
	
	BinaryData = GetFromTempStorage(FileData.FileBinaryDataRef);
	BinaryDataEncryptedFile = CryptoManager.Encrypt(BinaryData, CertificateArray);
	TempStorageAddress = PutToTempStorage(BinaryDataEncryptedFile, FormID);
	
	EncryptedData = New Structure;
	EncryptedData.Insert("TempStorageAddress", TempStorageAddress);
	
	Status(NStr("en = 'Encryption completed.'"));
	
	Return True;
	
EndFunction
// Removes a file from the working directory and notifies the open forms.
Procedure NotifyChangedAndDeleteFileInWorkingDirectory(Val AttachedFile, Val
FileData) Export
	
	NotifyChanged(AttachedFile);
	Notify("Write_AttachedFile", New Structure, AttachedFile);
	
	Status(StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = 'File 1%
		           |is encrypted.'"),
		AttachedFile) );
		
	Parameters = New Structure;
	Parameters.Insert("AttachedFile", AttachedFile);
	Parameters.Insert("FileData", FileData);
	
	NotifyDescription = New NotifyDescription("NotifyChangedAndDeleteFileInWorkingDirectoryExtensionSuggested", ThisObject, Parameters);
	CommonUseClient.ShowFileSystemExtensionInstallationQuestion
(NotifyDescription);
	
EndProcedure
Procedure NotifyChangedAndDeleteFileInWorkingDirectoryExtensionSuggested(FileSystemExtensionAttached, AdditionalParameters) Export
	
	AttachedFile = AdditionalParameters.AttachedFile;
	FileData = AdditionalParameters.FileData;
	
	If FileSystemExtensionAttached Then
		UserWorkingDirectory = FileFunctionsInternalClient.UserWorkingDirectory
();
		FullPathToFile = UserWorkingDirectory + FileData.FileName;
		
		File = New File(FullPathToFile);
		If File.Exist() Then
			Try
				File.SetReadOnly(False);
				DeleteFiles(FullPathToFile);
			Except
				// Attempting to delete the file from the disk
			EndTry;
		EndIf;
	EndIf;
	
EndProcedure
// Decrypts a file in a storage:
// - displays a dialog prompting the user to decrypt the file,
// - gets the binary data and the array of thumbprints,
// - decrypts the file,
// - writes the decrypted file data to the storage.
// The procedure is used as a handler of the file decryption command.
//
// Parameters:
//  AttachedFile - reference to the file.
//  FileData     - structure with file data.
//  FormID       - form UUID.
//
Procedure Decrypt(Val AttachedFile, Val FileData, Val FormID)
Export
	
	NotifyDescription = New NotifyDescription("DecryptDataReceived", ThisObject, AttachedFile);
	GetDecryptedData(NotifyDescription, AttachedFile, FileData, FormID);
	
EndProcedure
// Continues Decrypt procedure execution.
Procedure DecryptDataReceived(DecryptedData, AttachedFile) Export
	If DecryptedData = Undefined Then
		Return;
	EndIf;
	
	AttachedFilesInternalServerCall.Decrypt(AttachedFile,
DecryptedData);
	NotifyAboutDecryptingFile(AttachedFile);
EndProcedure
// Gets decrypted file data.
//
// Parameters:
//  ResultHandler - NotifyDescription - procedure that gets the control after the execution.
//                    Parameters of that procedure:
//                      DecryptedData - Structure, Undefined - contains the decrypted data, 
//                                      or Undefined if the data is not decrypted.
//                      AdditionalParameters - Arbitrary - value that was specified 
//                                      when creating the notification object.
//  AttachedFile  - reference to the file.
//  FileData      - structure with file data.
//  FormID        - form UUID.
//
Procedure GetDecryptedData(ResultHandler, Val AttachedFile, Val
FileData, Val FormID) Export
	
	If Not AttachCryptoExtension() Then
		FileFunctionsInternalClient.ShowCryptoExtensionRequiredMessageBox
(Undefined);
		ExecuteNotifyProcessing(ResultHandler, Undefined);
		Return;
	EndIf;
	
	CertificatePresentations = "";
	EncryptionCertificateArray = FileData.EncryptionCertificateArray;
	For Each CertificateStructure In EncryptionCertificateArray Do
		Thumbprint = CertificateStructure.Thumbprint;
		//PARTIALLY_DELETED
		//Certificate = DigitalSignatureClient.GetCertificateByThumbprint(Thumbprint, True);
		Certificate = Undefined;
		If Certificate <> Undefined Then
			If Not IsBlankString(CertificatePresentations) Then
				CertificatePresentations = CertificatePresentations + Chars.LF;
			EndIf;
			CertificatePresentations = CertificatePresentations + CertificateStructure.Presentation;
		EndIf;
	EndDo;
	
	FormParameters = New Structure;
	FormParameters.Insert("Title",                 NStr("en = 'Enter password for decryption'"));
	FormParameters.Insert("CertificatePresentations", CertificatePresentations);
	FormParameters.Insert("File",                      AttachedFile);
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ResultHandler", ResultHandler);
	AdditionalParameters.Insert("FileData", FileData);
	AdditionalParameters.Insert("FormID", FormID);
	
	NotifyDescription = New NotifyDescription("GetDecryptedDataPasswordEntered", ThisObject, AdditionalParameters);
	OpenForm("CommonForm.EnterPasswordWithDetails", FormParameters, , , , , NotifyDescription);
	
EndProcedure
// Continues GetDecryptedData procedure execution.
Procedure GetDecryptedDataPasswordEntered(Password, AdditionalParameters)
Export
	
	If TypeOf(Password) <> Type("String") Then
		ExecuteNotifyProcessing(AdditionalParameters.ResultHandler,
Undefined);
		Return;
	EndIf;
	
	Status(NStr("en = Decrypting file...'"));
	
	FileData = AdditionalParameters.FileData;
	FormID = AdditionalParameters.FormID;
	
	BinaryData = GetFromTempStorage(FileData.FileBinaryDataRef);
	
	//PARTIALLY_DELETED
	//Cancel = False;
	//CryptoManager = DigitalSignatureClient.GetCryptoManager(Cancel);
	Cancel = True;
	CryptoManager = Undefined;
	If Cancel Then
		ExecuteNotifyProcessing(AdditionalParameters.ResultHandler, Undefined);
		Return;
	EndIf;
	
	CryptoManager.PrivateKeyAccessPassword = Password;
	DecodedBinaryData = CryptoManager.Decrypt(BinaryData);
	
	EncryptedDataTempStorageAddress = PutToTempStorage(
		DecodedBinaryData, FormID);
	
#If WebClient Then
	TempTextStorageAddress = "";
#Else
	ExtractFileTextsAtServer = FileFunctionsInternalClientServer.CommonFileOperationSettings(
		).ExtractFileTextsAtServer;
	
	If Not ExtractFileTextsAtServer Then
		
		FullPathToFile = GetTempFileName(FileData.Extension);
		DecodedBinaryData.Write(FullPathToFile);
		
		TempTextStorageAddress =
			FileFunctionsInternalClientServer.ExtractTextToTempStorage(
				FullPathToFile, FormID);
		
		DeleteFiles(FullPathToFile);
	Else
		TempTextStorageAddress = "";
	EndIf;
#EndIf
	
	DecryptedData = New Structure;
	DecryptedData.Insert("TempStorageAddress",      
EncryptedDataTempStorageAddress);
	DecryptedData.Insert("TempTextStorageAddress",
TempTextStorageAddress);
	
	Status(NStr("en = 'Decryption completed.'"));
	
	ExecuteNotifyProcessing(AdditionalParameters.ResultHandler,
DecryptedData);
	
EndProcedure
// Notifies the system and the user about file decryption.
//
// Parameters:
//  AttachedFile - reference to the file.
//
Procedure NotifyAboutDecryptingFile(Val AttachedFile) Export
	
	NotifyChanged(AttachedFile);
	Notify("Write_AttachedFile", New Structure, AttachedFile);
	
	Status(StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = 'File %1
		           |is decrypted.'"),
		AttachedFile) );
	
EndProcedure
// Puts files from the hard disk in the storage of attached files.
//
// Parameters:
//  SelectedFiles           - Array - paths to files on the disk.
//  FileOwner               - reference to the file owner.
//  FileOperationSettings   - Structure.
//  AttachedFilesArray      - Array (return value) - filled with references to the added files.
//  FormID                  - form UUID.
//
Procedure PutSelectedFilesInStorage(Val SelectedFiles,
                                    Val FileOwner,
                                    AttachedFilesArray,
                                    Val FormID) Export
	
	CommonSettings = FileFunctionsInternalClientServer.CommonFileOperationSettings();
	
	CurrentPosition = 0;
	
	LastSavedFile = Undefined;
	
	For Each FullFileName In SelectedFiles Do
		
		CurrentPosition = CurrentPosition + 1;
		
		File = New File(FullFileName);
		
		FileFunctionsInternalClientServer.CheckCanImportFile(File);
		
		If CommonSettings.ExtractFileTextsAtServer Then
			TempTextStorageAddress = "";
		Else
			TempTextStorageAddress =
				FileFunctionsInternalClientServer.ExtractTextToTempStorage(
					FullFileName, FormID);
		EndIf;
	
		ModifiedUniversalTime = File.GetModificationUniversalTime();
		
		UpdateFileSavingState(SelectedFiles, File, CurrentPosition);
		LastSavedFile = File;
		
		FilesToBePlaced = New Array;
		Description = New TransferableFileDescription(File.FullName, "");
		FilesToBePlaced.Add(Description);
		
		PlacedFiles = New Array;
		
		If Not PutFiles(FilesToBePlaced, PlacedFiles, , False, FormID)
Then
			CommonUseClientServer.MessageToUser(
				StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'Cannot put file
					           |1%
					           |in a temporary storage.'"),
					File.FullName) );
			Continue;
		EndIf;
		
		TempFileStorageAddress = PlacedFiles[0].Location;
		
		// Creating file cards in the infobase
		AttachedFile = AttachedFilesInternalServerCall.AppendFile(
			FileOwner,
			File.BaseName,
			CommonUseClientServer.ExtensionWithoutDot(File.Extension),
			,
			ModifiedUniversalTime,
			TempFileStorageAddress,
			TempTextStorageAddress);
		
		If AttachedFile = Undefined Then
			Continue;
		EndIf;
		
		AttachedFilesArray.Add(AttachedFile);
		
	EndDo;
	
	UpdateFileSavingState(SelectedFiles, LastSavedFile);
	
EndProcedure
////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions
Procedure UpdateFileSavingState(Val SelectedFiles, Val File, Val
CurrentPosition = Undefined);
	
	If File = Undefined Then
		Return;
	EndIf;
	
	SizeInMB = FileFunctionsInternalClientServer.GetStringWithFileSize(File.Size
() / (1024 * 1024));
	
	If SelectedFiles.Count() > 1 Then
		
		If CurrentPosition = Undefined Then
			Status(NStr("en = 'Saving files is completed.'"));
		Else
			IndicatorPercent = CurrentPosition * 100 / SelectedFiles.Count();
			
			LabelMore = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Saving file %1 (%2 MB) ...'"), File.Name, SizeInMB);
				
			StateText = NStr("en = Saving files.'");
			
			Status(StateText, IndicatorPercent, LabelMore,
PictureLib.Information32);
		EndIf;
	Else
		If CurrentPosition = Undefined Then
			ExplanationText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Saving file %1 (%2 MB) is completed.'"), File.Name, SizeInMB);
		Else
			ExplanationText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Saving file %1 (%2 MB).
				           |Please wait...'"), File.Name, SizeInMB);
		EndIf;
		Status(ExplanationText);
	EndIf;
	
EndProcedure
////////////////////////////////////////////////////////////////////////////////
// Procedures that continue asynchronous procedures
// Continues AttachedFilesClient.OpenFile procedure execution.
Procedure OpenFileAddInSuggested(FileSystemExtensionAttached,
AdditionalParameters) Export
	
	FileData = AdditionalParameters.FileData;
	ForEditing = AdditionalParameters.ForEditing;
	
	If FileSystemExtensionAttached Then
		UserWorkingDirectory = FileFunctionsInternalClient.UserWorkingDirectory
();
		FullFileNameAtClient = UserWorkingDirectory + FileData.RelativePath + FileData.FileName;
		FileOnHardDisk = New File(FullFileNameAtClient);
		
		AdditionalParameters.Insert("ForEditing", ForEditing);
		AdditionalParameters.Insert("UserWorkingDirectory",
UserWorkingDirectory);
		AdditionalParameters.Insert("FileOnHardDisk", FileOnHardDisk);
		AdditionalParameters.Insert("FullFileNameAtClient", FullFileNameAtClient);
		
		If ValueIsFilled(FileData.Edits) And ForEditing And
FileOnHardDisk.Exist() Then
			FileOnHardDisk.SetReadOnly(False);
			GetFile = False;
		ElsIf FileOnHardDisk.Exist() Then
			NotifyDescription = New NotifyDescription("OpenFileDialogShown", ThisObject, AdditionalParameters);
			ShowDialogNeedToGetFileFromServer(NotifyDescription, FullFileNameAtClient, FileData, ForEditing);
			Return;
		Else
			GetFile = True;
		EndIf;
		
		OpenFileDialogShown(GetFile, AdditionalParameters);
	Else
		If FileData.FileBeingEdited And FileData.FileEditedByCurrentUser
Then
			NotifyDescription = New NotifyDescription("OpenFileReminderShown",
ThisObject, AdditionalParameters);
			FileFunctionsInternalClient.ShowReminderOnEdit
(NotifyDescription);
		EndIf;
		
		GetFile(FileData.FileBinaryDataRef, FileData.FileName, True);
	EndIf;
	
EndProcedure
// Continues AttachedFilesClient.OpenFile procedure execution.
Procedure OpenFileDialogShown(GetFile, AdditionalParameters) Export
	If GetFile = Undefined Then
		Return;
	EndIf;
	
	FileData = AdditionalParameters.FileData;
	ForEditing = AdditionalParameters.ForEditing;
	UserWorkingDirectory = AdditionalParameters.UserWorkingDirectory;
	FileOnHardDisk = AdditionalParameters.FileOnHardDisk;
	FullFileNameAtClient = AdditionalParameters.FullFileNameAtClient;
	
	CanOpenFile = True;
	If GetFile Then
		FullFileNameAtClient = "";
		CanOpenFile = AttachedFilesClient.GetFileToWorkingDirectory(
			FileData.FileBinaryDataRef,
			FileData.RelativePath,
			FileData.ModificationDateUniversal,
			FileData.FileName,
			UserWorkingDirectory,
			FullFileNameAtClient);
	EndIf;
		
	If CanOpenFile Then
		If ForEditing Then
			FileOnHardDisk.SetReadOnly(False);
		Else
			FileOnHardDisk.SetReadOnly(True);
		EndIf;
		OpenFileWithApplication(FullFileNameAtClient, FileData);
	EndIf;
		
EndProcedure
// Continues AttachedFilesClient.OpenFile procedure execution.
Procedure OpenFileReminderShown(ReminderResult, AdditionalParameters)
Export
	
	FileData = AdditionalParameters.FileData;
	GetFile(FileData.FileBinaryDataRef, FileData.FileName, True);
	
EndProcedure
// Continues AttachedFilesClient.AddFiles procedure execution.
Procedure AddFilesAddInSuggested(FileSystemExtensionAttached,
AdditionalParameters) Export
	
	FileOwner = AdditionalParameters.FileOwner;
	FormID = AdditionalParameters.FormID;
	Filter = AdditionalParameters.Filter;
	
	If FileSystemExtensionAttached Then
		
		SelectFile = New FileDialog(FileDialogMode.Open);
		SelectFile.Multiselect = True;
		SelectFile.Title = NStr("en = 'Select file'");
		SelectFile.Filter = ?(ValueIsFilled(Filter), Filter, NStr("en = 'All files'") +
" (*.*)|*.*");
		
		If SelectFile.Choose() Then
			AttachedFilesArray = New Array;
			PutSelectedFilesInStorage(
				SelectFile.SelectedFiles,
				FileOwner,
				AttachedFilesArray,
				FormID);
			
			If AttachedFilesArray.Count() = 1 Then
				AttachedFile = AttachedFilesArray[0];
				
				ShowUserNotification(
					NStr("en = 'Creating:'"),
					GetURL(AttachedFile),
					AttachedFile,
					PictureLib.Information32);
				
				FormParameters = New Structure("AttachedFile, IsNew", AttachedFile,
True);
				OpenForm("CommonForm.AttachedFile", FormParameters, , AttachedFile);
			EndIf;
			
			If AttachedFilesArray.Count() > 0 Then
				NotifyChanged(AttachedFilesArray[0]);
				Notify("Write_AttachedFile", New Structure("IsNew", True),
AttachedFilesArray);
			EndIf;
		
		EndIf;
		
	Else // If the web client has no extension attached.
		NotifyDescription = New NotifyDescription("AddFilesCompletion", ThisObject);
		PutSelectedFilesInWebStorage(NotifyDescription, FileOwner,
FormID);
	EndIf;
	
EndProcedure
// Continues AttachedFilesClient.AddFiles procedure execution.
Procedure AddFilesCompletion(AttachedFile, AdditionalParameters) Export
	
	If AttachedFile = Undefined Then
		Return;
	EndIf;
	
	ShowUserNotification(
		NStr("en = 'Creating:'"),
		GetURL(AttachedFile),
		AttachedFile,
		PictureLib.Information32);
		
	NotifyChanged(AttachedFile);
		
	FormParameters = New Structure("AttachedFile", AttachedFile);
	OpenForm("CommonForm.AttachedFile", FormParameters, , AttachedFile);
	
EndProcedure
// Continues AttachedFilesClient.SaveWithDigitalSignature procedure execution.
Procedure SaveWithDigitalSignatureExtensionSuggested(FileSystemExtensionAttached, AdditionalParameters) Export
	
	If FileSystemExtensionAttached Then
		NotifyDescription = New NotifyDescription("SaveWithDigitalSignatureFileNameReceived", ThisObject, AdditionalParameters);
		AdditionalParameters.Insert("CompletionHandler", NotifyDescription);
		SaveFileAsExtensionSuggested(FileSystemExtensionAttached,
AdditionalParameters);
	Else
		FileFunctionsInternalClient.ShowFileSystemExtensionRequiredMessageBox
(Undefined);
	EndIf;
	
EndProcedure
// Continues AttachedFilesClient.SaveWithDigitalSignature procedure execution.
Procedure SaveWithDigitalSignatureFileNameReceived(FullFileName, AdditionalParameters) Export
	
	If FullFileName = "" Then
		Return; // Either the user clicked Cancel, or this web client has no extensions.
	EndIf;
	
	AttachedFile = AdditionalParameters.AttachedFile;
	FileData = AdditionalParameters.FileData;
	FormID = AdditionalParameters.FormID;
	//PARTIALLY_DELETED	
	//Settings = DigitalSignatureClientServer.PersonalSettings().ActionsOnSavingWithDS;
	Settings = "Prompt";
	If Settings = "Prompt" Then
		FormParameters = New Structure;
		FormParameters.Insert("Object", AttachedFile);
		FormParameters.Insert("UUID", FormID);
		
		AdditionalParameters.Insert("FullFileName", FullFileName);
		NotifyDescription = New NotifyDescription("SaveWithDigitalSignatureSignaturesSelected", ThisObject, AdditionalParameters);
		OpenForm("CommonForm.SelectSignatures", FormParameters, , , , , NotifyDescription);
		Return;
	ElsIf Settings = "SaveAllSignatures" Then
		SignatureStructureArray = AttachedFilesInternalServerCall.GetAllSignatures(AttachedFile, FormID);
	EndIf;
	
	If TypeOf(SignatureStructureArray) = Type("Array") And SignatureStructureArray.Count() > 0 Then
		//PARTIALLY_DELETED
		//DigitalSignatureClient.SaveSignatures(
		//	AttachedFile,
		//	FullFileName,
		//	FormID,
		//	SignatureStructureArray);
	EndIf;
	
EndProcedure
// Continues AttachedFilesClient.SaveWithDigitalSignature procedure execution.
Procedure SaveWithDigitalSignatureSignaturesSelected(SignatureStructureArray, AdditionalParameters) Export
	If TypeOf(SignatureStructureArray) = Type("Array") And SignatureStructureArray.Count() > 0 Then
		//PARTIALLY_DELETED
		//DigitalSignatureClient.SaveSignatures(
		//	AdditionalParameters.AttachedFile,
		//	AdditionalParameters.FullFileName,
		//	AdditionalParameters.FormID,
		//	SignatureStructureArray);
	EndIf;
EndProcedure
// Continues AttachedFilesClient.SaveFileAs procedure execution.
Procedure SaveFileAsExtensionSuggested(FileSystemExtensionAttached,
AdditionalParameters) Export
	
	FileData = AdditionalParameters.FileData;
	FullFileName = "";
	If FileSystemExtensionAttached Then
		
		SelectFile = New FileDialog(FileDialogMode.Save);
		SelectFile.Multiselect = False;
		SelectFile.FullFileName = FileData.FileName;
		SelectFile.DefaultExt = FileData.Extension;
		SelectFile.Filter = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'All files  (*.%1)|*.%1'"), FileData.Extension);
		
		If Not SelectFile.Choose() Then
			Return;
		EndIf;
		
		SizeInMB = FileData.Size / (1024 * 1024);
		
		ExplanationText =
			StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Saving file %1 (%2 MB).
				           |Please wait...'"),
				FileData.FileName,
				FileFunctionsInternalClientServer.GetStringWithFileSize(SizeInMB) );
		
		Status(ExplanationText);
		
		FileToReceive = New TransferableFileDescription(SelectFile.FullFileName, FileData.FileBinaryDataRef);
		FilesToBeObtained = New Array;
		FilesToBeObtained.Add(FileToReceive);
		
		ObtainedFiles = New Array;
		
		If GetFiles(FilesToBeObtained, ObtainedFiles, , False) Then
			Status(NStr("en = 'File saved.'"), , SelectFile.FullFileName);
		EndIf;
		FullFileName = SelectFile.FullFileName;
	Else
		GetFile(FileData.FileBinaryDataRef, FileData.FileName, True);
	EndIf;
	
	If AdditionalParameters.Property("CompletionHandler") Then
		ExecuteNotifyProcessing(AdditionalParameters.CompletionHandler,
FullFileName);
	EndIf;
	
EndProcedure
////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions
Procedure ShowDialogNeedToGetFileFromServer(ResultHandler, Val FileNameWithPath, Val FileData, Val ForEditing)
	
	StandardFileData= New Structure;
	StandardFileData.Insert("ModificationDateUniversal",     FileData.ModificationDateUniversal);
	StandardFileData.Insert("Size",                          FileData.Size);
	StandardFileData.Insert("InWorkingDirectoryForRead",     Not ForEditing);
	StandardFileData.Insert("Edits",                         FileData.Edits);
	
	// The file is found in the working directory.
	// Checking the modification date and deciding what to do next.
	
	Parameters = New Structure;
	Parameters.Insert("ResultHandler", ResultHandler);
	Parameters.Insert("FileNameWithPath", FileNameWithPath);
	NotifyDescription = New NotifyDescription("ShowDialogNeedToGetFileFromServerActionDefined", ThisObject, Parameters);
	FileFunctionsInternalClient.ActionOnOpenFileInWorkingDirectory(
		NotifyDescription, FileNameWithPath, StandardFileData);
EndProcedure
// Continues ShowDialogNeedToGetFileFromServer procedure execution.
Procedure ShowDialogNeedToGetFileFromServerActionDefined(Action, AdditionalParameters) Export
	FileNameWithPath = AdditionalParameters.FileNameWithPath;
	
	If Action = "TakeFromStorageAndOpen" Then
		File = New File(FileNameWithPath);
		File.SetReadOnly(False);
		DeleteFiles(FileNameWithPath);
		Result = True;
	ElsIf Action = "OpenExistingFile" Then
		Result = False;
	Else // Action = "Cancel"
		Result = Undefined;
	EndIf;
	
	ExecuteNotifyProcessing(AdditionalParameters.ResultHandler, Result);
	
EndProcedure
Procedure OpenFileWithApplication(Val FileNameToOpen, FileData)
	
	ExtensionAttached = AttachFileSystemExtension();
	
	If ExtensionAttached Then
		TitleString = CommonUseClientServer.GetNameWithExtension(
			FileData.Description, FileData.Extension);
		
		If Lower(FileData.Extension) = Lower("grs") Then
			Schema = New GraphicalSchema;
			Schema.Read(FileNameToOpen);
			Schema.Show(TitleString, FileNameToOpen);
			Return;
		EndIf;
		
		If Lower(FileData.Extension) = Lower("mxl") Then
			BinaryData = New BinaryData(FileNameToOpen);
			Address = PutToTempStorage(BinaryData);
			SpreadsheetDocument = FileFunctionsInternalServerCall.SpreadsheetDocumentFromTemporaryStorage(Address);
			
			OpenParameters = New Structure;
			OpenParameters.Insert("DocumentName", TitleString);
			OpenParameters.Insert("PathToFile", FileNameToOpen);
			OpenParameters.Insert("SpreadsheetDocument", SpreadsheetDocument);
			
			OpenForm("CommonForm.SpreadsheetDocumentEditing", OpenParameters);
			Return;
		EndIf;
		
		// Opening file
		Try
			RunApp(FileNameToOpen);
		Except
			ErrorInfo = ErrorInfo();
			ShowMessageBox(, StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Error occurred when opening file
				           |%1:
				           | ""%2"".'"),
				FileNameToOpen,
				ErrorInfo.Description));
		EndTry;
	EndIf;
EndProcedure
// Updates file data from a file selected by user.
// This procedure is used as handler of the command that updates an attached file from another file.
//
// Parameters:
//  AttachedFile   - reference to the file.
//  FileData       - Structure - file data.
//  FormID         - form UUID.
//
Procedure UpdateAttachedFile(Val AttachedFile, Val FileData, Val
FormID) Export
	
	NotifyDescription = New NotifyDescription
("UpdateAttachedFilePuttingCompleted", ThisObject, AttachedFile);
	SelectFileOnHardDiskAndPutToStorage(NotifyDescription, FileData,
FormID);
	
EndProcedure
// Continues UpdateAttachedFile procedure execution.
Procedure UpdateAttachedFilePuttingCompleted(FileInfo,
AttachedFile) Export
	
	If FileInfo = Undefined Then
		Return;
	EndIf;
	
	AttachedFilesInternalServerCall.UpdateAttachedFile(AttachedFile,
FileInfo);
	NotifyChanged(AttachedFile);
	
EndProcedure
#EndRegion