
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	FileCreated = Parameters.IsNew;
	
	ColumnArray = New Array;
	For Each ColumnDetails In FormAttributeToValue("SignatureTable").Columns Do
		ColumnArray.Add(ColumnDetails.Name);
	EndDo;
	SignatureTableColumnDetails = New FixedArray(ColumnArray);
	
	CurrentUser = Users.CurrentUser();
	UserEmptyRef = Catalogs.Users.EmptyRef();
	
	If ValueIsFilled(Parameters.CopyingValue) Then
		ObjectToCopy = Parameters.CopyingValue.GetObject();
		CopyingValue = Parameters.CopyingValue;
		
		ObjectValue = Catalogs[ObjectToCopy.Metadata().Name].CreateItem();
		FillPropertyValues(
			ObjectValue,
			ObjectToCopy,
			"ModificationDateUniversal,
			|CreationDate,
			|Encrypted,
			|Details,
			|SignedWithDS,
			|Size,
			|Extension,
			|TextStorage,
			|FileOwner,
			|DeletionMark");
		
		For Each DigitalSignatureItem In ObjectToCopy.DigitalSignatures Do
			NewRow = ObjectValue.DigitalSignatures.Add();
			FillPropertyValues(NewRow, DigitalSignatureItem);
		EndDo;
		
		For Each EncryptionElement In ObjectToCopy.EncryptionCertificates Do
			NewRow = ObjectValue.EncryptionCertificates.Add();
			FillPropertyValues(NewRow, EncryptionElement);
		EndDo;
		
		ObjectValue.Author = Users.CurrentUser();
	Else
		If Parameters.Property("AttachedFile") Then
			ObjectValue = Parameters.AttachedFile.GetObject();
		Else
			ObjectValue = Parameters.Key.GetObject();
		EndIf;
	EndIf;
	
	CatalogName = ObjectValue.Metadata().Name;
	
	SetUpFormObject(ObjectValue);
	
	FillSignatureList();
	FillEncryptionList();
	
	If ReadOnly
	 Or Not AccessRight("Update", ThisObject.Object.FileOwner.Metadata()) Then
		
		SetChangeButtonsInvisible(Items);
	EndIf;
	
	If Not ReadOnly
	   And Not ThisObject.Object.Ref.IsEmpty() Then
		
		LockDataForEdit(ThisObject.Object.Ref, , UUID);
	EndIf;
	
	SetButtonsEnabled(ThisObject, Items, CurrentUser);
	
	RefreshTitle();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	ModificationDate = ToLocalTime(ThisObject.Object.ModificationDateUniversal);
	
	ReadDigitalSignature();
	
EndProcedure

&AtClient
Procedure OnClose()
	
	UnlockObject(ThisObject.Object.Ref, UUID);
	
EndProcedure

#EndRegion

#Region SignatureTableFormTableItemEventHandlers

&AtClient
Procedure SignatureTableChoice(Item, SelectedRow, Field, StandardProcessing)
	
	//PARTIALLY_DELETED
	//DigitalSignatureClient.OpenSignature(Items.SignatureTable.CurrentData);
	
EndProcedure

#EndRegion

#Region EncryptionCertificatesFormTableItemEventHandlers

&AtClient
Procedure EncryptionCertificatesSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenEncryptionCertificate(Undefined);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

///////////////////////////////////////////////////////////////////////////////////
// File command handlers

&AtClient
Procedure UpdateFromFileOnHardDisk(Command)
	
	If IsNew() Or ThisObject.Object.Encrypted Or ThisObject.Object.SignedWithDS Or Not ThisObject.Object.Edits.IsEmpty() Then
		Return;
	EndIf;
	
	FileData = GetFileData(ThisObject.Object.Ref, , False);
	
	NotifyDescription = New NotifyDescription("UpdateFromFileOnHardDiskCompletion", ThisObject);
	AttachedFilesInternalClient.SelectFileOnHardDiskAndPutToStorage(NotifyDescription, FileData, UUID);
	
EndProcedure

&AtClient
Procedure StandardWriteAndClose(Command)
	
	If HandleFileRecordCommand() Then
		Close();
	EndIf;
	
EndProcedure

&AtClient
Procedure StandardWrite(Command)
	
	HandleFileRecordCommand();
	
EndProcedure

&AtClient
Procedure StandardSetDeletionMark(Command)
	
	If IsNew() Then
		Return;
	EndIf;
	
	If Modified Then
		If ThisObject.Object.DeletionMark Then
			QuestionText = NStr(
				"en = 'Write the changes to the file to continue the operation.
				      |Do you want to write the changes and remove the deletion mark 
				      |from file %1?'");
		Else
			QuestionText = NStr(
				"en = 'Write the changes to the file to continue the operation.
				      |Do you want to write the changes and mark 
				      |the file %1 for deletion?'");
		EndIf;
	Else
		If ThisObject.Object.DeletionMark Then
			QuestionText = NStr("en = 'Do you want to remove the deletion mark 
                                |from file %1?'");
		Else
			QuestionText = NStr("en = 'Do you want to mark 
                                |the file %1 for deletion?'");
		EndIf;
	EndIf;
	
	QuestionText = StringFunctionsClientServer.SubstituteParametersInString(
		QuestionText, ThisObject.Object.Ref);
		
	NotifyDescription = New NotifyDescription("StandardSetDeletionMarkAnswerReceived", ThisObject);
	ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
EndProcedure

&AtClient
Procedure StandardSetDeletionMarkAnswerReceived(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult = DialogReturnCode.Yes Then
		ThisObject.Object.DeletionMark = Not ThisObject.Object.DeletionMark;
		HandleFileRecordCommand();
	EndIf;
	
EndProcedure

&AtClient
Procedure StandardReread(Command)
	
	If IsNew() Then
		Return;
	EndIf;
	
	If Not Modified Then
		Return;
	EndIf;
	
	QuestionText = NStr("en = 'The data is changed. Do you want to reread the data?'");
	
	NotifyDescription = New NotifyDescription("StandardRereadAnswerReceived", ThisObject);
	ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
	
EndProcedure

&AtClient
Procedure StandardRereadAnswerReceived(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult = DialogReturnCode.Yes Then
		RereadDataFromServer();
		Modified = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure StandardCopy(Command)
	
	If IsNew() Then
		Return;
	EndIf;
	
	FormParameters = New Structure("CopyingValue", ThisObject.Object.Ref);
	
	OpenForm("CommonForm.AttachedFile", FormParameters);
	
EndProcedure

///////////////////////////////////////////////////////////////////////////////////
// Digital signature and encryption command handlers.

&AtClient
Procedure SignFileWithDigitalSignature(Command)
	
	If IsNew() Or ValueIsFilled(ThisObject.Object.Edits) Or ThisObject.Object.Encrypted Then
		Return;
	EndIf;
	
	FileData = GetFileData(ThisObject.Object.Ref, UUID);
	NotifyDescription = New NotifyDescription("SignDSFileSignatureReceived", ThisObject);
	AttachedFilesInternalClient.SelectDigitalSignatureCertificatesAndGenerateSignatureData(
		NotifyDescription, ThisObject.Object.Ref, FileData);
	
EndProcedure

&AtClient
Procedure SignDSFileSignatureReceived(SignatureData, AdditionalParameters) Export
	
	If SignatureData = Undefined Then
		Return;
	EndIf;
		
	RecordSingleSignatureDetails(SignatureData);
	NotifyChanged(ThisObject.Object.Ref);
	Notify("Write_AttachedFile", New Structure, ThisObject.Object.Ref);
	
EndProcedure

&AtClient
Procedure AddDigitalSignatureFromFile(Command)
	
	#If WebClient Then
	If Not AttachCryptoExtension() Then
		FileFunctionsInternalClient.ShowCryptoExtensionRequiredMessageBox(Undefined);
		Return;
	EndIf;
	#EndIf

	If IsNew() Or ValueIsFilled(ThisObject.Object.Edits) Or ThisObject.Object.Encrypted Then
		Return;
	EndIf;
	
	NotifyDescription = New NotifyDescription("AddDigitalSignatureFromFileExtensionSuggested", ThisObject);
	CommonUseClient.ShowFileSystemExtensionInstallationQuestion(NotifyDescription);
	
EndProcedure

&AtClient
Procedure AddDigitalSignatureFromFileExtensionSuggested(FileSystemExtensionAttached, AdditionalParameters) Export
	
	If FileSystemExtensionAttached Then
		FileData = GetFileData(ThisObject.Object.Ref, UUID);
		
		NotifyDescription = New NotifyDescription("AddDigitalSignatureFromFileSignaturesReceived", ThisObject);
		AttachedFilesInternalClient.GetSignatureArray(NotifyDescription,
			ThisObject.Object.Ref, UUID);
	Else
#If WebClient Then
		FileFunctionsInternalClient.ShowFileSystemExtensionRequiredMessageBox(Undefined);
#EndIf
	EndIf;
	
EndProcedure

&AtClient
Procedure AddDigitalSignatureFromFileSignaturesReceived(ArrayOfSignatures, AdditionalParameters) Export
	If ArrayOfSignatures.Count() > 0 Then
		RecordMultipleSignatureDetails(ArrayOfSignatures);
		AttachedFilesInternalClient.NotifyAboutAddingSignaturesFromFile(
			ThisObject.Object.Ref, ArrayOfSignatures.Count());
	EndIf;
EndProcedure

&AtClient
Procedure SaveWithDigitalSignature(Command)
	
	If IsNew()
	 Or ValueIsFilled(ThisObject.Object.Edits)
	 Or ThisObject.Object.Encrypted Then
		Return;
	EndIf;
	
	FileData = GetFileData(ThisObject.Object.Ref, UUID);
	
	AttachedFilesClient.SaveWithDigitalSignature(
		ThisObject.Object.Ref,
		FileData,
		UUID);
	
EndProcedure

&AtClient
Procedure Encrypt(Command)
	
	If IsNew() Or ValueIsFilled(ThisObject.Object.Edits) Or ThisObject.Object.Encrypted Then
		Return;
	EndIf;
	
	FileData = GetFileData(ThisObject.Object.Ref, UUID);
	
	NotifyDescription = New NotifyDescription("EncryptDataReceived", ThisObject, FileData);
	AttachedFilesInternalClient.GetEncryptedData(NotifyDescription, ThisObject.Object.Ref, FileData, UUID);

EndProcedure

&AtClient
Procedure EncryptDataReceived(ReceivingResult, FileData) Export
	If ReceivingResult = Undefined Then
		Return;
	EndIf;
	
	EncryptedData = ReceivingResult.EncryptedData;
	ThumbprintArray = ReceivingResult.ThumbprintArray;
	
	EncryptServer(EncryptedData, ThumbprintArray);
	
	AttachedFilesInternalClient.NotifyChangedAndDeleteFileInWorkingDirectory(
		ThisObject.Object.Ref, FileData);
	
	FillEncryptionList();
	NotifyChanged(ThisObject.Object.Ref);
	Notify("Write_AttachedFile", New Structure, ThisObject.Object.Ref);
	
EndProcedure

&AtClient
Procedure Decrypt(Command)
	
	If IsNew() Or Not ThisObject.Object.Encrypted Then
		Return;
	EndIf;
	
	FileData = GetFileData(ThisObject.Object.Ref, UUID);
	NotifyDescription = New NotifyDescription("DecryptDataReceived", ThisObject);
	
	AttachedFilesInternalClient.GetDecryptedData(NotifyDescription,
		ThisObject.Object.Ref, FileData, UUID);
	
EndProcedure

&AtClient
Procedure DecryptDataReceived(DecryptedData, AdditionalParameters) Export
	
	If DecryptedData = Undefined Then
		Return;
	EndIf;
	
	DecryptServer(DecryptedData);
	AttachedFilesInternalClient.NotifyAboutDecryptingFile(ThisObject.Object.Ref);
	FillEncryptionList();
	
EndProcedure

&AtClient
Procedure DigitalSignatureCommandListOpenSignature(Command)
	//PARTIALLY_DELETED
	//DigitalSignatureClient.OpenSignature(Items.SignatureTable.CurrentData);
	
EndProcedure

&AtClient
Procedure VerifyDigitalSignature(Command)
	
	//PARTIALLY_DELETED
	//DigitalSignatureOperationCommonSettings = DigitalSignatureClientServer.CommonSettings();
	//
	//If DigitalSignatureOperationCommonSettings.VerifyDSOnServer Then
	//	
	//	SelectedRowData = New Array;
	//	ColumnNames = "";
	//	For Each ColumnName In SignatureTableColumnDetails Do
	//		ColumnNames = ColumnNames + ColumnName + ",";
	//	EndDo;
	//	ColumnNames = Left(ColumnNames, StrLen(ColumnNames)-1);
	//	
	//	For Each Item In Items.SignatureTable.SelectedRows Do
	//		RowData = New Structure(ColumnNames);
	//		FillPropertyValues(RowData, SignatureTable.FindByID(Item));
	//		SelectedRowData.Add(RowData);
	//	EndDo;
	//	
	//	VerifySignaturesAtServer(SelectedRowData);
	//	
	//	Index = 0;
	//	For Each Item In Items.SignatureTable.SelectedRows Do
	//		String = SignatureTable.FindByID(Item);
	//		Row.Status = SelectedRowData[Index].Status;
	//		Row.Incorrect = SelectedRowData[Index].Incorrect;
	//		Index = Index + 1;
	//	EndDo;
	//Else
	//	CryptoManager = DigitalSignatureClient.GetCryptoManager();
	//	
	//	BinaryData = GetFromTempStorage(
	//		GetFileData(ThisObject.Object.Ref).FileBinaryDataRef);
	//	
	//	For Each Item In Items.SignatureTable.SelectedRows Do
	//		RowData = Items.SignatureTable.RowData(Item);
	//		
	//		If RowData.Object <> Undefined And (Not RowData.Object.IsEmpty()) Then
	//			VerifyOneSignature(RowData, CryptoManager, BinaryData);
	//		EndIf;
	//	EndDo;
	//	
	//EndIf;
	
EndProcedure

&AtClient
Procedure CheckAll(Command)
	//PARTIALLY_DELETED
	//DigitalSignatureOperationCommonSettings = DigitalSignatureClientServer.CommonSettings();
	//
	//If DigitalSignatureOperationCommonSettings.VerifyDSOnServer Then
	//	
	//	RowData = New Array;
	//	ColumnNames = "";
	//	For Each ColumnName In SignatureTableColumnDetails Do
	//		ColumnNames = ColumnNames + ColumnName + ",";
	//	EndDo;
	//	ColumnNames = Left(ColumnNames, StrLen(ColumnNames)-1);
	//	
	//	For Each VTRow In SignatureTable Do
	//		RowData = New Structure(ColumnNames);
	//		FillPropertyValues(RowData, VTRow);
	//		RowData.Add(RowData);
	//	EndDo;
	//	
	//	VerifySignaturesAtServer(RowData);
	//	
	//	Index = 0;
	//	For Each VTRow In SignatureTable Do
	//		VTRow.Status = RowData[Index].Status;
	//		VTRow.Incorrect = RowData[Index].Incorrect;
	//		Index = Index + 1;
	//	EndDo;
	//Else
	//	BinaryData = GetFromTempStorage(
	//		GetFileData(ThisObject.Object.Ref).FileBinaryDataRef);
	//	
	//	CryptoManager = DigitalSignatureClient.GetCryptoManager();
	//	
	//	For Each Row In SignatureTable Do
	//		If Row.Object <> Undefined And (Not Row.Object.IsEmpty()) Then
	//			VerifyOneSignature(String, CryptoManager, BinaryData);
	//		EndIf;
	//	EndDo;
	//EndIf;
	
EndProcedure

&AtClient
Procedure SaveSignature(Command)
	
	If Items.SignatureTable.CurrentData = Undefined Then
		Return;
	EndIf;
	
	CurrentData = Items.SignatureTable.CurrentData;
	
	If CurrentData.Object <> Undefined And (Not CurrentData.Object.IsEmpty()) Then
		//PARTIALLY_DELETED
		//DigitalSignatureClient.SaveSignature(CurrentData.SignatureAddress);
	EndIf;
	
EndProcedure

&AtClient
Procedure DeleteDigitalSignature(Command)
	
	NotifyDescription = New NotifyDescription("DeleteDigitalSignatureAnswerReceived", ThisObject);
	ShowQueryBox(NotifyDescription, NStr("en = 'Do you want to delete the selected signatures?'"), QuestionDialogMode.YesNo);
	
EndProcedure

&AtClient
Procedure DeleteDigitalSignatureAnswerReceived(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult = DialogReturnCode.No Then
		Return;
	EndIf;
	
	DeleteFromSignatureListAndWriteFile();
	NotifyChanged(ThisObject.Object.Ref);
	Notify("Write_AttachedFile", New Structure, ThisObject.Object.Ref);
	
EndProcedure

&AtClient
Procedure OpenEncryptionCertificate(Command)
	
	CurrentData = Items.EncryptionCertificates.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	Thumbprint = CurrentData.Thumbprint;
	
	//PARTIALLY_DELETED
	//Certificate = Undefined;
	//CertificateStructure = Undefined;
	//If Not IsBlankString(CurrentData.CertificateAddress) Then
	//	CertificateBinaryData = GetFromTempStorage(CurrentData.CertificateAddress);
	//	
	//	Certificate = New CryptoCertificate(CertificateBinaryData);
	//	CertificateStructure = DigitalSignatureClientServer.FillCertificateStructure(Certificate);
	//Else
	//	CertificateStructure = DigitalSignatureClient.FillCertificateStructureByThumbprint(Thumbprint);
	//EndIf;
	//
	//If CertificateStructure <> Undefined Then
	//	
	//	DigitalSignatureClient.OpenCertificateWithStructure(
	//		CertificateStructure, Thumbprint, CurrentData.CertificateAddress);
	//EndIf;
	
EndProcedure

///////////////////////////////////////////////////////////////////////////////////
// Command handlers that support shared access to files.

&AtClient
Procedure Edit(Command)
	
	If IsNew()
		Or ThisObject.Object.SignedWithDS
		Or ThisObject.Object.Encrypted Then
		Return;
	EndIf;
	
	If ValueIsFilled(ThisObject.Object.Edits)
	   And ThisObject.Object.Edits <> CurrentUser Then
		Return;
	EndIf;
	
	FileData = GetFileData(ThisObject.Object.Ref, UUID);
	
	If ValueIsFilled(ThisObject.Object.Edits) Then
		AttachedFilesClient.OpenFile(FileData, True);
	Else
		AttachedFilesClient.OpenFile(FileData, True);
		LockFileForEditingServer();
		NotifyChanged(ThisObject.Object.Ref);
		Notify("Write_AttachedFile", New Structure, ThisObject.Object.Ref);
	EndIf;
	
EndProcedure

&AtClient
Procedure EndEdit(Command)
	
	If IsNew()
		Or Not ValueIsFilled(ThisObject.Object.Edits)
		Or ThisObject.Object.Edits <> CurrentUser Then
			Return;
	EndIf;
	
	FileData = GetFileData(ThisObject.Object.Ref, , False);
	
	NotifyDescription = New NotifyDescription("EndEditPuttingCompleted", ThisObject);
	AttachedFilesInternalClient.PutFileEditedOnHardDiskInStorage(NotifyDescription,FileData, UUID);
	
EndProcedure

&AtClient
Procedure EndEditPuttingCompleted(FileInfo, AdditionalParameters) Export
	
	If FileInfo <> Undefined Then
		PutFileToStorageAndUnlock(FileInfo);
		NotifyChanged(ThisObject.Object.Ref);
		Notify("Write_AttachedFile", New Structure, ThisObject.Object.Ref);
	EndIf;
	
	SetButtonsEnabled(ThisObject, Items, CurrentUser);
	
EndProcedure

&AtClient
Procedure Unlock(Command)
	
	If IsNew()
	 Or Not ValueIsFilled(ThisObject.Object.Edits)
	 Or ThisObject.Object.Edits <> CurrentUser Then
		Return;
	EndIf;
	
	UnlockFile();
	NotifyChanged(ThisObject.Object.Ref);
	Notify("Write_AttachedFile", New Structure, ThisObject.Object.Ref);
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure RefreshTitle()
	
	If ValueIsFilled(ThisObject.Object.Ref) Then
		Title = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = '%1 (Attached file)'"), String(ThisObject.Object.Ref));
	Else
		Title = NStr("en = 'Attached file (Create)'")
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure VerifySignaturesAtServer(RowCollection)
	
	FileFunctionsInternal.VerifySignaturesInCollectionRows(RowCollection);
	
EndProcedure

&AtServerNoContext
Function GetFileData(Val AttachedFile,
                     Val FormID = Undefined,
                     Val GetBinaryDataRef = True)
	
	Return AttachedFiles.GetFileData(
		AttachedFile, FormID, GetBinaryDataRef);
	
EndFunction

&AtClient
Procedure OpenFileForViewing()
	
	If IsNew()
	 Or ThisObject.Object.Encrypted Then
		Return;
	EndIf;
	
	FileData = GetFileData(ThisObject.Object.Ref, UUID);
	
	FileBeingEdited = ValueIsFilled(ThisObject.Object.Edits)
	                  And ThisObject.Object.Edits = CurrentUser;
	
	AttachedFilesClient.OpenFile(FileData, FileBeingEdited);
	
EndProcedure

&AtClient
Procedure OpenFileDirectory()
	
	If IsNew()
	 Or ThisObject.Object.Encrypted Then
		Return;
	EndIf;
	
	FileData = GetFileData(ThisObject.Object.Ref, UUID);
	
	AttachedFilesInternalClient.OpenDirectoryWithFile(FileData);
	
EndProcedure

&AtClient
Procedure SaveAs()
	
	If IsNew()
	 Or ThisObject.Object.Encrypted Then
		Return;
	EndIf;
	
	FileData = GetFileData(ThisObject.Object.Ref, UUID);
	
	AttachedFilesClient.SaveFileAs(FileData);
	
EndProcedure

&AtServer
Procedure UpdateBinaryFileDataAtServer(FileInfo)
	
	ObjectToWrite = FormAttributeToValue("Object");
	AttachedFiles.UpdateAttachedFile(ObjectToWrite, FileInfo);
	ValueToFormAttribute(ObjectToWrite, "Object");
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetChangeButtonsInvisible(Items)
	
	CommandNames = GetObjectChangeCommandNames();
	
	For Each FormItem In Items Do
	
		If TypeOf(FormItem) <> Type("FormButton") Then
			Continue;
		EndIf;
		
		If CommandNames.Find(FormItem.CommandName) <> Undefined Then
			FormItem.Visible = False;
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure FillEncryptionList()
	
	EncryptionCertificates.Clear();
	
	If ThisObject.Object.Encrypted Then
		For Each CertificateStructure In FormAttributeToValue("Object").EncryptionCertificates Do
			
			NewRow = EncryptionCertificates.Add();
			NewRow.Presentation = CertificateStructure.Presentation;
			NewRow.Thumbprint = CertificateStructure.Thumbprint;
			
			CertificateBinaryData = CertificateStructure.Certificate.Get();
			If CertificateBinaryData <> Undefined Then
				
				NewRow.CertificateAddress = PutToTempStorage(
					CertificateBinaryData, UUID);
			EndIf;
			
		EndDo;
	EndIf;
	
	TitleText = NStr("en = 'Decryption allowed'");
	
	If EncryptionCertificates.Count() <> 0 Then
		TitleText = TitleText + " (" + Format(EncryptionCertificates.Count(), "NG=") + ")";
	EndIf;
	
	Items.EncryptionGroup.Title = TitleText;
	
EndProcedure

&AtClient
Procedure VerifyOneSignature(RowData, CryptoManager, FileBinaryData)
	
	ReturnStructure = "";
	
	SignatureBinaryData = GetFromTempStorage(RowData.SignatureAddress);
	
	Try
		//PARTIALLY_DELETED
		//DigitalSignatureClient.VerifySignature(
		//	CryptoManager,
		//	FileBinaryData,
		//	SignatureBinaryData);
		//
		//RowData.Status = NStr("en = 'Correct'");
		//RowData.Incorrect = False;
	Except
		RowData.Status =
			NStr("en = 'Incorrect.'") + " " + BriefErrorDescription(ErrorInfo());
		
		RowData.Incorrect = True;
	EndTry;
	
EndProcedure

&AtServer
Procedure FillSignatureList()
	
	SignatureTable.Clear();
	
	If ThisObject.Object.SignedWithDS Then
		
		For Each DigitalSignatureItem In FormAttributeToValue("Object").DigitalSignatures Do
			
			NewRow = SignatureTable.Add();
			
			NewRow.CertificateOwner = DigitalSignatureItem.CertificateOwner;
			NewRow.SignatureDate    = DigitalSignatureItem.SignatureDate;
			NewRow.Comment          = DigitalSignatureItem.Comment;
			NewRow.Object           = ThisObject.Object.Ref;
			NewRow.Thumbprint       = DigitalSignatureItem.Thumbprint;
			NewRow.Signatory        = DigitalSignatureItem.Signatory;
			NewRow.Incorrect        = False;
			NewRow.SignatureAddress = PutToTempStorage(
				DigitalSignatureItem.Signature.Get(), UUID);
			
			CertificateBinaryData = DigitalSignatureItem.Certificate.Get();
			If CertificateBinaryData <> Undefined Then 
				
				NewRow.CertificateAddress = PutToTempStorage(
					CertificateBinaryData, UUID);
			EndIf;
			
		EndDo;
	EndIf;
	
	TitleText = NStr("en = 'Digital signatures'");
	
	If SignatureTable.Count() <> 0 Then
		TitleText = TitleText + " (" + String(SignatureTable.Count()) + ")";
	EndIf;
	
	Items.DigitalSignaturesGroup.Title = TitleText;
	
EndProcedure

&AtServer
Procedure DeleteFromSignatureListAndWriteFile()
	
	ObjectToWrite = FormAttributeToValue("Object");
	For Each SelectedRowNumber In Items.SignatureTable.SelectedRows Do
		RowToDelete = SignatureTable.FindByID(SelectedRowNumber);
		IndexOfRowToDelete = SignatureTable.IndexOf(RowToDelete);
		SignatureTable.Delete(IndexOfRowToDelete);
		ObjectToWrite.DigitalSignatures.Delete(IndexOfRowToDelete);
	EndDo;
	
	If ObjectToWrite.DigitalSignatures.Count() = 0 Then
		ObjectToWrite.SignedWithDS = False;
	EndIf;
	
	WriteFile(ObjectToWrite);
	ValueToFormAttribute(ObjectToWrite, "Object");
	FillSignatureList();
	
	SetButtonsEnabled(ThisObject, Items, CurrentUser);
	
EndProcedure

&AtServer
Procedure DecryptServer(DecryptedData)
	
	ObjectToWrite = FormAttributeToValue("Object");
	AttachedFilesInternal.Decrypt(ObjectToWrite, DecryptedData);
	ValueToFormAttribute(ObjectToWrite, "Object");
	
	SetButtonsEnabled(ThisObject, Items, CurrentUser);
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetButtonsEnabled(Form, Items, CurrentUser)
	
	FileBeingEdited = ValueIsFilled(Form.Object.Edits);
	FileEditedByCurrentUser = Form.Object.Edits = CurrentUser;
	
	AllCommandNames = GetFormCommandNames();
	CommandNames = GetAvailableCommands(
		FileBeingEdited,
		FileEditedByCurrentUser,
		Form.Object.SignedWithDS,
		Form.Object.Encrypted,
		Form.Object.Ref.IsEmpty());
		
	If Form.SignatureTable.Count() = 0 Then
		DeleteCommandFromArray(CommandNames, "OpenSignature");
	EndIf;
	
	For Each FormItem In Items Do
		If TypeOf(FormItem) <> Type("FormButton") Then
			Continue;
		EndIf;
		If AllCommandNames.Find(FormItem.CommandName) <> Undefined Then
			FormItem.Enabled = False;
		EndIf;
	EndDo;
	
	For Each FormItem In Items Do
		If TypeOf(FormItem) <> Type("FormButton") Then
			Continue;
		EndIf;
		If CommandNames.Find(FormItem.CommandName) <> Undefined Then
			FormItem.Enabled = True;
		EndIf;
	EndDo;
	
EndProcedure

&AtClientAtServerNoContext
Function GetFormCommandNames()
	
	CommandNames = GetObjectChangeCommandNames();
	
	For Each CommandName In GetSimpleObjectCommandNames() Do
		CommandNames.Add(CommandName);
	EndDo;
	
	Return CommandNames;
	
EndFunction

&AtClientAtServerNoContext
Function GetSimpleObjectCommandNames()
	
	CommandNames = New Array;
	
	// Simple commands that are available to any user that reads the files
	CommandNames.Add("SaveWithDigitalSignature");
	
	CommandNames.Add("OpenCertificate");
	CommandNames.Add("OpenSignature");
	CommandNames.Add("VerifyDigitalSignature");
	CommandNames.Add("CheckAll");
	CommandNames.Add("SaveSignature");
	
	CommandNames.Add("OpenFileDirectory");
	CommandNames.Add("OpenFileForViewing");
	CommandNames.Add("SaveAs");
	
	Return CommandNames;
	
EndFunction

&AtClientAtServerNoContext
Function GetObjectChangeCommandNames()
	
	CommandNames = New Array;
	
	CommandNames.Add("SignFileWithDigitalSignature");
	CommandNames.Add("AddDigitalSignatureFromFile");
	
	CommandNames.Add("DeleteDigitalSignature");
	
	CommandNames.Add("Edit");
	CommandNames.Add("EndEdit");
	CommandNames.Add("Unlock");
	
	CommandNames.Add("Encrypt");
	CommandNames.Add("Decrypt");
	
	CommandNames.Add("StandardCopy");
	CommandNames.Add("UpdateFromFileOnHardDisk");
	
	CommandNames.Add("StandardWrite");
	CommandNames.Add("StandardWriteAndClose");
	CommandNames.Add("StandardSetDeletionMark");
	
	Return CommandNames;
	
EndFunction

&AtClientAtServerNoContext
Function GetAvailableCommands(FileBeingEdited,
                                 FileEditedByCurrentUser,
                                 FileSigned,
                                 FileEncrypted,
                                 IsNewFile)
	
	If IsNewFile Then
		CommandNames = New Array;
		CommandNames.Add("StandardWrite");
		CommandNames.Add("StandardWriteAndClose");
		Return CommandNames;
	EndIf;
	
	CommandNames = GetFormCommandNames();
	
	If FileBeingEdited Then
		If FileEditedByCurrentUser Then
			DeleteCommandFromArray(CommandNames, "UpdateFromFileOnHardDisk");
		Else
			DeleteCommandFromArray(CommandNames, "EndEdit");
			DeleteCommandFromArray(CommandNames, "Unlock");
			DeleteCommandFromArray(CommandNames, "Edit");
		EndIf;
		DeleteDigitalSignatureCommands(CommandNames);
		
		DeleteCommandFromArray(CommandNames, "UpdateFromFileOnHardDisk");
		DeleteCommandFromArray(CommandNames, "SaveAs");
		
		DeleteCommandFromArray(CommandNames, "Encrypt");
		DeleteCommandFromArray(CommandNames, "Decrypt");
	Else
		DeleteCommandFromArray(CommandNames, "EndEdit");
		DeleteCommandFromArray(CommandNames, "Unlock");
	EndIf;
	
	If FileSigned Then
		DeleteCommandFromArray(CommandNames, "EndEdit");
		DeleteCommandFromArray(CommandNames, "Unlock");
		DeleteCommandFromArray(CommandNames, "Edit");
		DeleteCommandFromArray(CommandNames, "UpdateFromFileOnHardDisk");
	Else
		DeleteCommandFromArray(CommandNames, "OpenCertificate");
		DeleteCommandFromArray(CommandNames, "OpenSignature");
		DeleteCommandFromArray(CommandNames, "VerifyDigitalSignature");
		DeleteCommandFromArray(CommandNames, "CheckAll");
		DeleteCommandFromArray(CommandNames, "SaveSignature");
		DeleteCommandFromArray(CommandNames, "DeleteDigitalSignature");
		DeleteCommandFromArray(CommandNames, "SaveWithDigitalSignature");
	EndIf;
	
	If FileEncrypted Then
		DeleteDigitalSignatureCommands(CommandNames);
		DeleteCommandFromArray(CommandNames, "EndEdit");
		DeleteCommandFromArray(CommandNames, "Unlock");
		DeleteCommandFromArray(CommandNames, "Edit");
		
		DeleteCommandFromArray(CommandNames, "UpdateFromFileOnHardDisk");
		
		DeleteCommandFromArray(CommandNames, "Encrypt");
		
		DeleteCommandFromArray(CommandNames, "OpenFileDirectory");
		DeleteCommandFromArray(CommandNames, "OpenFileForViewing");
		DeleteCommandFromArray(CommandNames, "SaveAs");
		
		DeleteCommandFromArray(CommandNames, "SignFileWithDigitalSignature");
	Else
		DeleteCommandFromArray(CommandNames, "Decrypt");
	EndIf;
	
	Return CommandNames;
	
EndFunction

&AtClientAtServerNoContext
Procedure DeleteDigitalSignatureCommands(Val CommandNames)
	
	DeleteCommandFromArray(CommandNames, "SignFileWithDigitalSignature");
	DeleteCommandFromArray(CommandNames, "AddDigitalSignatureFromFile");
	DeleteCommandFromArray(CommandNames, "SaveWithDigitalSignature");
	
EndProcedure

&AtClientAtServerNoContext
Procedure DeleteCommandFromArray(Array, CommandName)
	
	Position = Array.Find(CommandName);
	
	If Position = Undefined Then
		Return;
	EndIf;
	
	Array.Delete(Position);
	
EndProcedure

&AtServer
Procedure EncryptServer(EncryptedData, ThumbprintArray)
	
	ObjectToWrite = FormAttributeToValue("Object");
	
	AttachedFilesInternal.Encrypt(ObjectToWrite, EncryptedData, ThumbprintArray);
	
	ValueToFormAttribute(ObjectToWrite, "Object");
	
	SetButtonsEnabled(ThisObject, Items, CurrentUser);
	
EndProcedure

&AtServer
Procedure RecordMultipleSignatureDetails(ArrayOfSignatures)
	
	ObjectToWrite = FormAttributeToValue("Object");
	
	AttachedFiles.RecordMultipleSignatureDetails(
		ObjectToWrite, ArrayOfSignatures);
	
	ValueToFormAttribute(ObjectToWrite, "Object");
	FillSignatureList();
	
	SetButtonsEnabled(ThisObject, Items, CurrentUser);
	
EndProcedure

&AtServer
Procedure RecordSingleSignatureDetails(SignatureData)
	
	ObjectToWrite = FormAttributeToValue("Object");
	AttachedFiles.RecordSingleSignatureDetails(ObjectToWrite, SignatureData);
	WriteFile(ObjectToWrite);
	ValueToFormAttribute(ObjectToWrite, "Object");
	FillSignatureList();
	
	SetButtonsEnabled(ThisObject, Items, CurrentUser);
	
EndProcedure

&AtServer
Procedure LockFileForEditingServer()
	
	ObjectToWrite = FormAttributeToValue("Object");
	AttachedFilesInternal.LockFileForEditingServer(ObjectToWrite);
	ValueToFormAttribute(ObjectToWrite, "Object");
	
	SetButtonsEnabled(ThisObject, Items, CurrentUser);
	
EndProcedure

&AtServer
Procedure PutFileToStorageAndUnlock(Val FileInfo)
	
	ObjectToWrite = FormAttributeToValue("Object");
	AttachedFilesInternal.PutFileToStorageAndUnlock(ObjectToWrite, FileInfo);
	ValueToFormAttribute(ObjectToWrite, "Object");
	
EndProcedure

&AtServer
Procedure UnlockFile()
	
	ObjectToWrite = FormAttributeToValue("Object");
	AttachedFilesInternal.UnlockFile(ObjectToWrite);
	ValueToFormAttribute(ObjectToWrite, "Object");
	
EndProcedure

&AtClient
Function HandleFileRecordCommand()
	
	If IsBlankString(ThisObject.Object.Description) Then
		CommonUseClientServer.MessageToUser(
			NStr("en = 'To continue, specify the file name.'"), , "Description", "Object");
		Return False;
	EndIf;
	
	Try
		FileFunctionsInternalClient.CorrectFileName(ThisObject.Object.Description);
	Except
		CommonUseClientServer.MessageToUser(
			BriefErrorDescription(ErrorInfo()), ,"Description", "Object");
		Return False;
	EndTry;
	
	If Not WriteFile() Then
		Return False;
	EndIf;
	
	Modified = False;
	RepresentDataChange(ThisObject.Object.Ref, DataChangeType.Update);
	NotifyChanged(ThisObject.Object.Ref);
	
	Notify("Write_AttachedFile",
	        New Structure("IsNew", FileCreated),
	        ThisObject.Object.Ref);
	
	Return True;
	
EndFunction

&AtServer
Procedure RereadDataFromServer()
	
	FileObject = ThisObject.Object.Ref.GetObject();
	ValueToFormAttribute(FileObject, "Object");
	
EndProcedure

&AtServer
Function WriteFile(Val ParameterObject = Undefined)
	
	If ParameterObject = Undefined Then
		ObjectToWrite = FormAttributeToValue("Object");
	Else
		ObjectToWrite = ParameterObject;
	EndIf;
	
	TransactionActive = False;
	Try
		If ValueIsFilled(CopyingValue) Then
			BinaryData = AttachedFiles.GetBinaryFileData(CopyingValue);
			
			If FileFunctionsInternal.FileStorageType()
			   = Enums.FileStorageTypes.InInfobase Then
				
				BeginTransaction();
				TransactionActive = True;
				RefNew = Catalogs[CatalogName].GetRef();
				ObjectToWrite.SetNewObjectRef(RefNew);
				AttachedFilesInternal.WriteFileToInfobase(RefNew, BinaryData);
				ObjectToWrite.FileStorageType = Enums.FileStorageTypes.InInfobase;
			Else
				// Adding file to one of the volumes (that has enough free space)
				FileFunctionsInternal.AddOnHardDisk(
					BinaryData,
					ObjectToWrite.PathToFile,
					ObjectToWrite.Volume, 
					ObjectToWrite.ModificationDateUniversal,
					"",
					ObjectToWrite.Description,
					ObjectToWrite.Extension,
					ObjectToWrite.Size);
				
				ObjectToWrite.FileStorageType = Enums.FileStorageTypes.InVolumesOnHardDisk;
			EndIf;
		EndIf;
		
		ObjectToWrite.Write();
		
		If TransactionActive Then
			CommitTransaction();
		EndIf;
	Except
		If TransactionActive Then
			RollbackTransaction();
			WriteLogEvent(
				NStr("en = 'Files.Error writing attached file'",
				     CommonUseClientServer.DefaultLanguageCode()),
				EventLogLevel.Error,
				,
				,
				DetailErrorDescription(ErrorInfo()) );
		EndIf;
		Raise;
	EndTry;
	
	If ParameterObject = Undefined Then
		ValueToFormAttribute(ObjectToWrite, "Object");
	EndIf;
	
	CopyingValue = Catalogs[CatalogName].EmptyRef();
	SetButtonsEnabled(ThisObject, Items, CurrentUser);
	
	RefreshTitle();
	
	Return True;
	
EndFunction

&AtServer
Procedure SetUpFormObject(Val NewObject)
	
	NewObjectType = New Array;
	NewObjectType.Add(TypeOf(NewObject));
	
	NewAttribute = New FormAttribute("Object", New TypeDescription(NewObjectType));
	NewAttribute.StoredData = True;
	
	AttributesToBeAdded = New Array;
	AttributesToBeAdded.Add(NewAttribute);
	
	ChangeAttributes(AttributesToBeAdded);
	
	ValueToFormAttribute(NewObject, "Object");
	
	For Each Item In Items Do
		If TypeOf(Item) = Type("FormField")
		   And Left(Item.DataPath, StrLen("PrototypeObject[0].")) = "PrototypeObject[0]."
		   And Right(Item.Name, 1) = "0" Then
			
			ItemName = Left(Item.Name, StrLen(Item.Name) -1);
			If Items.Find(ItemName) <> Undefined Then
				Continue;
			EndIf;
			
			NewItem = Items.Insert(ItemName, TypeOf(Item), Item.Parent, Item);
			NewItem.DataPath = "Object." + Mid(Item.DataPath, StrLen("PrototypeObject[0].") + 1);
			FillPropertyValues(NewItem, Item, ,
				"Name, DataPath, SelectedText, TypeLink");
			
			Item.Visible = False;
		EndIf;
	EndDo;
	
EndProcedure

&AtServerNoContext
Procedure UnlockObject(Val Ref, Val UUID)
	
	UnlockDataForEdit(Ref, UUID);
	
EndProcedure

&AtClient
Procedure ReadDigitalSignature()
	
	//PARTIALLY_DELETED
	Return;
	
	//If SignatureTable.Count() = 0 Then 
	//	Return;
	//EndIf;
	//
	//DigitalSignatureOperationCommonSettings = DigitalSignatureClientServer.CommonSettings();
	//
	//If DigitalSignatureOperationCommonSettings.VerifyDigitalSignatureAtServer Then
	//	Return;
	//EndIf;
	
	If Not AttachCryptoExtension() Then
		Return;
	EndIf;
	
	Try
		//PARTIALLY_DELETED
		//CryptoManager = DigitalSignatureClient.GetCryptoManager();
		CryptoManager = Undefined;
	Except
		Return;
	EndTry;
	
	If CryptoManager = Undefined Then
		Return;
	EndIf;
	
	For Each TableRow In SignatureTable Do
		
		If IsBlankString(TableRow.Thumbprint) Then // The signature was not read when writing the object
			Signature = GetFromTempStorage(TableRow.SignatureAddress);
			
			If ValueIsFilled(Signature) Then 
				Try
					Certificates = CryptoManager.GetCertificatesFromSignature(Signature);
				Except
					Return;
				EndTry;
				Certificate = Certificates[0];
				
				TableRow.Thumbprint = Base64String(Certificate.Thumbprint);
				
				//PARTIALLY_DELETED
				//TableRow.CertificateOwner = DigitalSignatureClientServer
				//	.GetUserPresentation(Certificate.Subject);
				
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

&AtClient
Function IsNew()
	
	Return ThisObject.Object.Ref.IsEmpty();
	
EndFunction

&AtClient
Procedure UpdateFromFileOnHardDiskCompletion(FileInfo, AdditionalParameters) Export
	
	If FileInfo = Undefined Then
		Return;
	EndIf;
		
	UpdateBinaryFileDataAtServer(FileInfo);
	NotifyChanged(ThisObject.Object.Ref);
	Notify("Write_AttachedFile", New Structure, ThisObject.Object.Ref);
	
EndProcedure

#EndRegion