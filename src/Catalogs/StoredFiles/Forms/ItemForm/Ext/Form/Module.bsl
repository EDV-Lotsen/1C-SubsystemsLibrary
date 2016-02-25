 
//////////////////////////////////////////////////////////////////////////////// 
// EVENT HANDLERS 
// 

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Key.IsEmpty() And Not Parameters.CopyingValue.IsEmpty() Then
		// Clearing the file name when you copying not to make an illusion that the file content will be copied too
		Object.FileName = "";
	EndIf;
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	If Object.FileName = "" Then
		ShowMessageBox(, "No file selected");
		Cancel = True;
	EndIf;
EndProcedure

&AtClient
Procedure ChooseFileFromDiskAndWrite()
	NewObject = Object.Ref.IsEmpty();
	Notification = New NotifyDescription("ChooseFileFromDiskAndSaveCompletion", ThisObject, NewObject);
	BeginPutFile(Notification, , "", True);
EndProcedure

&AtClient
Procedure ChooseFileFromDiskAndSaveCompletion(Result,  TempStorageAddress, SelectedName, NewObject) Export
	If Result Then
		Object.FileName = SelectedName;

		If Not ValueIsFilled(Object.Description) Then
			FileDetails = New File(SelectedName);
			Object.Description = FileDetails.Name;
		EndIf;

		PutObjectFile(TempStorageAddress);
		If NewObject Then
			RepresentDataChange(Object.Ref, DataChangeType.Create);
		Else
			RepresentDataChange(Object.Ref, DataChangeType.Update);
		EndIf;
	EndIf;
EndProcedure

&AtClient
Procedure ReadFileAndSaveToDisk()
	
	If Object.Ref.IsEmpty() Then
		ShowMessageBox(,NStr("en = 'Data is not saved'"));
		Return;
	EndIf;
	
	If IsBlankString(Object.FileName) Then
		ShowMessageBox(,NStr("en = 'Name is not specified'"));
		Return;
	EndIf;
	
	Address = GetURL(Object.Ref, "FileData");
	GetFile(Address, Object.FileName, True);
EndProcedure

//////////////////////////////////////////////////////////////////////////////// 
// Cryptography command HANDLERS
// 

&AtClient
Procedure Sign(Command)
	// Gets to the client
	// Signs
	// Places to the server the file and the signature
	If Not AttachCryptoExtension() Then
		Message(NStr("en = 'Install the cryptography operations extension for this operation'"));
		Return;
		EndIf;
		Data = GetFileData();
		If Data.Count() = 0 Then
			ShowMessageBox(, NStr("en = 'No file data.'"), 10);
			Return;
		EndIf;
		FileBinaryData = Data[0];
		Data.Delete(0);
		FormParameters = New ValueList;
		FormParameters.Add(CryptoCertificateStoreType.PersonalCertificates);
		Context = New Structure("Data, FileBinaryData", Data, FileBinaryData);

		GetCertificatesList(FormParameters, False,  "SignCompletion1",  Context);
	EndProcedure

&AtClient
Procedure SignCompletion1(Result, Context) Export
	If Result =  DialogReturnCode.Cancel Then  
		Return;
	EndIf;
	CryptoManager =  New CryptoManager("Microsoft Enhanced Cryptographic Provider v1.0", "", 1); 	
	// Checking that this certificate have not been used to sign this file

	For Each DigitalSignaturesBinaryData In Context.Data Do
		SignatureCertificates = CryptoManager.GetCertificatesFromSignature(DigitalSignaturesBinaryData);
		For Each SignatureCertificate In SignatureCertificates Do
			If Result = SignatureCertificate Then  
				ShowMessageBox(,
					NStr("en = 'The file is already signed with this certificate'"), 10);
				Return;
			EndIf;
		EndDo;
	EndDo;
	// Signing
	Context2 = New Structure(
		"CryptoManager, FileBinaryData, Certificate, Data",  
		CryptoManager, Context.FileBinaryData,  Result,  Context.Data);
	EnterPassword(CryptoManager,  "SignCompletion2",  Context2);
EndProcedure

&AtClient
Procedure SignCompletion2(Result,  Context)  Export
	If  Result =  DialogReturnCode.OK  Then
		NewSignature =  Context.CryptoManager.Sign(
			Context.FileBinaryData,  Context.Certificate);

		Context.Data.Add(NewSignature);
		// Saving on the server, if the empty string is used it allows not to send
		// the file back to the server due to it have not been changed
		WriteFileData("", Context.Data);
		RepresentDataChange(Object.Ref, DataChangeType.Update);
	EndIf
EndProcedure

&AtClient
Procedure VerifySignature(Command)
	// Checking signatures at the server
	If VerifySignatureAtServer() Then 
		Message = NStr("en = 'Digital signature verified'");
		ShowMessageBox(, Message, 3);
	EndIf;
EndProcedure

&AtClient
Procedure PutEncryptedOnServer(Command)
	If Not AttachCryptoExtension() Then
		Message(NStr("en = 'Install the cryptography operations extension for this operation'"));
		Return;
	EndIf;

	// Choosing a file on disk, which is required to be encrypted and saved on the server
	NewObject = Object.Ref.IsEmpty();
	CryptoManager = New CryptoManager("Microsoft Enhanced Cryptographic Provider v1.0", "", 1);
	FileForEncryptionAddress = Undefined;
	// if the file operations extension is not attached, the operation is performed
	// not optimal, the traffic to the server increases and security decreases
	If AttachFileSystemExtension() Then
		Dialog = New FileDialog(FileDialogMode.Open);
		If Not Dialog.Choose() Then
			Return;
		EndIf;
		FileForEncryptionAddress = Dialog.SelectedFiles[0];
		FileForEncryption = New File(FileForEncryptionAddress);
		Object.FileName = FileForEncryption.Name;
		SourceDataForEncryption = FileForEncryptionAddress;


		// Creating the list of certificates that could be used to decrypt the file
		FormParameters =  New ValueList;

		FormParameters.Add(CryptoCertificateStoreType.RecipientCertificates);
		FormParameters.Add(CryptoCertificateStoreType.PersonalCertificates);
		
		Context = New Structure("CryptoManager, SourceDataForEncryption, NewObject",
			CryptoManager, SourceDataForEncryption, NewObject);
		GetCertificatesList(FormParameters, True, "PutEncryptedOnServerCompletion", Context);
		
	Else
		Context =  New Structure("CryptoManager, NewObject",
			CryptoManager, NewObject);
		Notification = New NotifyDescription(
			"PutEncryptedOnServerCompletion2",
			ThisObject, Context);
		BeginPutFile(Notification, FileForEncryptionAddress, "", True);
		Return;
	EndIf;

EndProcedure

&AtClient
Procedure PutEncryptedOnServerCompletion2(Result, FileForEncryptionAddress, SelectedName, Context)  Export
	// Copy-paste from PutEncryptedOnServer
	If  Not Result Then
			Return;
	EndIf;	
	FileForEncryption = New  File(SelectedName);
	Object.FileName  = FileForEncryption.Name;
	SourceDataForEncryption = GetFromTempStorage(FileForEncryptionAddress);
	
	// Creating the list of certificates that could be used to decrypt the file
	FormParameters = New  ValueList;
	FormParameters.Add(CryptoCertificateStoreType.RecipientCertificates);
	FormParameters.Add(CryptoCertificateStoreType.PersonalCertificates);
	
	// Adding to the context
	Context.Insert("SourceDataForEncryption",  SourceDataForEncryption);
	GetCertificatesList(FormParameters, True, "PutEncryptedOnServerCompletion",  Context);
EndProcedure

&AtClient
Procedure PutEncryptedOnServerCompletion(Result, Context) Export
	If  Result =  DialogReturnCode.Cancel  Then 
		Return;
	EndIf;


	Certificates =  Result;


	If Certificates = Undefined Or Certificates.Count() = 0 Then 
		Return;
	EndIf;
	
	// Encrypting for selected certificates
	EncryptedBinaryData = Context.CryptoManager.Encrypt(

		Context.SourceDataForEncryption, Certificates);
	Object.Encrypted = True;
	
	// Saving on the server
	WriteFileData(EncryptedBinaryData, New Array);
	If Context.NewObject Then
		RepresentDataChange(Object.Ref, DataChangeType.Create);
	Else
		RepresentDataChange(Object.Ref, DataChangeType.Update);
	EndIf;
EndProcedure

&AtServer
Function EncryptAtServer(CertificatesData, ErrorText)
	Certificates = New Array();
	For Each CertificateData In CertificatesData Do
		Certificates.Add(New CryptoCertificate(CertificateData));
	EndDo;
	
	CryptoManager = New CryptoManager("Microsoft Enhanced Cryptographic Provider v1.0", "", 1);
	Data = GetFileData();
	If Data.Count() = 0 Then
		ErrorText = NStr("en = 'No file data.'");
		Return False;
	EndIf;
	FileBinaryData = Data[0];
	Data.Delete(0);
	
	// Encrypting
	EncryptedBinaryData = CryptoManager.Encrypt(FileBinaryData, Certificates);

	// Saving on the server
	Object.Encrypted = True;
	WriteFileData(EncryptedBinaryData, Data);
	Return True;
EndFunction

&AtClient
Procedure Encrypt(Command)
	Var ErrorText;
	If Not AttachCryptoExtension() Then
		Message(NStr("en = 'Install the cryptography operations extension for this operation'"));
		Return;
	EndIf;
	
	If Object.Encrypted Then
		Message(NStr("en = 'File already encrypted'"));
		Return;
	EndIf;
	
	If Object.Signed Then
		Message(NStr("en = 'The file is signed, the encryption operation is prohibited'"));
		Return;
	EndIf;
	
	// Creating the list of certificates that could be used to decrypt the file
	FormParameters = New ValueList;
	FormParameters.Add(CryptoCertificateStoreType.RecipientCertificates);
	FormParameters.Add(CryptoCertificateStoreType.PersonalCertificates);
	GetCertificatesList(FormParameters, True, "EncryptCompletion");

EndProcedure

&AtClient
Procedure EncryptCompletion(Result, Context) Export
	Var  ErrorText;
	If  Result =  DialogReturnCode.Cancel  Then 
		Return;
	EndIf;
	
	Certificates =  Result;
	If Certificates = Undefined Or Certificates.Count() = 0 Then 
		Return;
	EndIf;
	
	NewObject = Object.Ref.IsEmpty();
	
	CertificatesData = New Array();
	For Each Certificate In Certificates Do
		CertificatesData.Add(Certificate.Unload());
	EndDo;
	
	Result = EncryptAtServer(CertificatesData, ErrorText);
	
	If Not Result Then
		Message(ErrorText);
		Return;
	EndIf;
	
	If NewObject Then
		RepresentDataChange(Object.Ref, DataChangeType.Create);
	Else
		RepresentDataChange(Object.Ref, DataChangeType.Update);
	EndIf;
EndProcedure

&AtClient
Procedure GetWithDetails(Command)
	// Get on the client
	// Decrypt
	// If binary data, then send to the server
	// Place into a file
	If Not TypeOf(Object.Owner) = Type("CatalogRef.Counterparties") Then 
		Message = NStr("en = 'It is possible to decrypt only files of counterparties'");
		Message(Message);
		Return;
	EndIf;
	If Not AttachCryptoExtension() Then
		Message(NStr("en = 'Install the cryptography operations extension for this operation'"));
		Cancel = True;
		Return;
	EndIf;
	Data = GetFileData();
	If Data.Count() = 0 Then
		Message(NStr("en = 'No file data'"));
		Return;
	EndIf;
	FileBinaryData = Data[0];
	Data.Delete(0);
	CryptoManager = New CryptoManager("Microsoft Enhanced Cryptographic Provider v1.0", "", 1);
	Context = New Structure(

		"CryptoManager  FileBinaryData",
		CryptoManager, FileBinaryData);
	
	EnterPassword(CryptoManager, "GetWithDetailsCompletion",  Context);
EndProcedure

&AtClient
Procedure  GetWithDetailsCompletion(Result,  Context)  Export
	If  Not Result =  DialogReturnCode.OK  Then
		Return;
	EndIf;
	// Saving the decrypted in the client's file system
	If AttachFileSystemExtension() Then
		Dialog = New FileDialog(FileDialogMode.Save);
		Dialog.FullFileName = Object.FileName;
		If Not Dialog.Choose() Then
			Return;
		EndIf;

		Context.CryptoManager.Decrypt(Context.FileBinaryData, Dialog.SelectedFiles[0]);

	Else
		DecryptedBinaryData = Context.CryptoManager.Decrypt(Context.FileBinaryData);
		
		TemporaryStorageAddress = PutToTempStorage(DecryptedBinaryData, Uuid);
		FileName = Object.FileName;
		GetFile(TemporaryStorageAddress, FileName, True);
	EndIf;
EndProcedure

//////////////////////////////////////////////////////////////////////////////// 
// PROCEDURES AND FUNCTIONS 
// 

// This procedure verifies signatures
// - returns True if all signatures passed checking
&AtServer
Function VerifySignatureAtServer()
	Data = GetFileData();
	If Data.Count() = 0 Then
		Message(NStr("en = 'No file data'"));
		Return False;
	EndIf;
	FileBinaryData = Data[0];
	Data.Delete(0);
	If Data.Count() = 0 Then
		Message = NStr("en = 'The file is not signed'");
		Message(Message);
		Return False;
	EndIf;
	CryptoManager = New CryptoManager("Microsoft Enhanced Cryptographic Provider v1.0", "", 1);
	For Each EDSBinaryData In Data Do
		CryptoManager.VerifySignature(FileBinaryData, EDSBinaryData);
	EndDo;
	Return True;
EndFunction

// This procedure saves the file on the server, and, if any, EDS files
&AtServer
Procedure WriteFileData(FileBinaryData, EDSBinaryData)
	CatalogItem = FormAttributeToValue("Object");
	// Changing the FileData only If the binary data passed
	If TypeOf(FileBinaryData) = Type("BinaryData") Then
		CatalogItem.FileData = New ValueStorage(FileBinaryData, New Deflation());
	EndIf;

	CatalogItem.Signature = New ValueStorage(EDSBinaryData, New Deflation());
	
	CatalogItem.Write();
	Modified = False;
	ValueToFormAttribute(CatalogItem, "Object");     
	
EndProcedure	

// This procedure receives the following data from the server as an array of the binary data:
// first goes the file, if any, EDS files
&AtServer
Function GetFileData()
	Data = New Array;
	CatalogItem = FormAttributeToValue("Object");
	FileBinaryData = CatalogItem.FileData.Get();
	If TypeOf(FileBinaryData) = Type("BinaryData") Then
		Data.Add(FileBinaryData);
		EDSFiles = CatalogItem.Signature.Get();
		If TypeOf(EDSFiles) = Type("Array") Then
			For Each EDSFile In EDSFiles Do
				If TypeOf(EDSFile) = Type("BinaryData") Then
					Data.Add(EDSFile);
				EndIf;
			EndDo;
		EndIf;
	EndIf;
	
	Return Data;
EndFunction
	
// The generation (interactive) of the cryptographic certificates list
// ChoiceParameters - the list of storage types, certificates from which can be used in choice
// Multiselect
&AtClient
Procedure GetCertificatesList(ChoiceParameters, Multiselect, CompletionProcedureName,  Context = Undefined)
	FormParameters = New Structure;
	FormParameters.Insert("Multiselect", Multiselect);
	CertificatesListForm = GetForm("Catalog.StoredFiles.Form.CertificatesList", FormParameters);
	CertificatesListForm.Set(ChoiceParameters);
	CertificatesListForm.OnCloseNotifyDescription = 
		New NotifyDescription(CompletionProcedureName, ThisObject,  Context);
	CertificatesListForm.Open();
EndProcedure

// This procedure retrieves the object data from the temporary storage, 
// performs a catalog item modification and writes it.
// 
// Parameters: 
//  TemporaryStorageAddress-Row-Address temporary storage. 
// 
&AtServer
Procedure PutObjectFile(TemporaryStorageAddress)
	CatalogItem = FormAttributeToValue("Object");
	BinaryData = GetFromTempStorage(TemporaryStorageAddress);
	CatalogItem.FileData = New ValueStorage(BinaryData, New Deflation());
	File = New File(CatalogItem.FileName);
	CatalogItem.FileName = File.Name;
	CatalogItem.Signature = New ValueStorage(Undefined, New Deflation());
	CatalogItem.Encrypted = False;
	CatalogItem.Signed = False;
	CatalogItem.Write();
	Modified = False;
	DeleteFromTempStorage(TemporaryStorageAddress);
	ValueToFormAttribute(CatalogItem, "Object");     
EndProcedure

// Access to the certificate's cryptography private key interactive password input
// returns the entered password in the call parameter Password
// Returns true if the password have been entered
&AtClient
Procedure EnterPassword(CertificateManager, CompletionProcedureName, Context =  Undefined)

	ReturnValue =  False;
	PasswordForm = GetForm("Catalog.StoredFiles.Form.PasswordForm");
	PasswordForm.CertificateManager =  CertificateManager;
	PasswordForm.OnCloseNotifyDescription = 
		New NotifyDescription(CompletionProcedureName, ThisObject,  Context);
	PasswordForm.Open();
EndProcedure