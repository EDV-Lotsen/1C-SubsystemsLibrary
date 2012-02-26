
////////////////////////////////////////////////////////////////////////////////
// COMMON PROCEDURES AND FUNCTIONS

&AtClient
Procedure OnOpen(Cancellation)
	SetAccessibilityOfFormItems();
	
	DescriptionBeforeRecord = Object.Description;
	
EndProcedure

// Function is used to copy last version
// from the file-source to the file-receiver
// Parameters:
//	Receiver - ref to the "File" where linked File being copied
//	Source 	 - ref to the "File" from where linked File being copied
&AtServer
Function CreateCopyOfVersion(Receiver, Source)
	
	If Not Source.CurrentVersion.IsEmpty() Then
		
		Version = FileOperations.CreateFileVersion(
			CurrentDate(),
			ToUniversalTime(CurrentDate()),
		    Receiver,
			Object.Description,
			Source.CurrentVersion.Size,
			Source.CurrentVersion.Extension,
			Source.CurrentVersion.FileStorage,
			Source.CurrentVersion.TextStorage,
			False,
			Source.CurrentVersion);

		// Refresh File form (as writing may occur not only on form closing)
		Object.CurrentVersion = Version.Ref;
		
		// Update record in the infobase
		FileOperations.UpdateFileCurrentVersion(Receiver, Version, Source.CurrentVersion.TextStorage, Uuid);
		
	EndIf;
	
EndFunction // CreateCopyOfVersion()

// Adjusts accessibility of form commands and items
&AtClient
Procedure SetAccessibilityOfFormItems()
	
	ActionsWithFileAreAvailable = Not Object.CurrentVersion.IsEmpty() And Not Object.Ref.IsEmpty();
	
	Items.StoreVersions.Enabled 		= ActionsWithFileAreAvailable And Not Object.DeletionMark;
	Items.CancelEdit.Enabled 			= Not Object.LockedBy.IsEmpty();
	Items.OpenFileDirectory.Enabled 	= ActionsWithFileAreAvailable;
	Items.SaveAs.Enabled 				= ActionsWithFileAreAvailable;
	
	Items.Edit.Enabled 			= NOT Object.Signed;
	Items.EndEdit.Enabled 		= Not Object.LockedBy.IsEmpty();
	Items.Details.ReadOnly 	= NOT Object.LockedBy.IsEmpty();
	Items.Take.Enabled 			= Object.LockedBy.IsEmpty() And (ActionsWithFileAreAvailable) And NOT Object.Signed;
	Items.SaveChanges.Enabled 	= Not Object.LockedBy.IsEmpty();
	
	Items.UpdateFromFileOnDisk.Enabled = ActionsWithFileAreAvailable And NOT Object.Signed;
	
EndProcedure

&AtClient
Procedure FullDescrOnChange(Item)
	Object.Details = TrimAll(Object.Details);
	Try
		FileFunctionsClient.CheckForInvalidCharactersInFileName(Object.Details, True);
	Except
		Information = ErrorInfo();
	    DoMessageBox(Information.Details);
	EndTry;
	
	Object.Description = TrimAll(Object.Details);
EndProcedure

&AtClient
Procedure WriteExecute()
	Write();
	Read();
EndProcedure

&AtClient
Procedure CopyExecute()
	
	FileOperationsClient.CopyFile(Object.FileOwner, Object.Ref);

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES - FORM EVENTS HANDLERS

// Procedure  - handler of the event "OnCreate".
//
&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	FileDataCorrect = False;
	
	If Parameters.Property("CreationMode") Then 
		CreationMode = Parameters.CreationMode;
	EndIf;
	
	If Parameters.Property("NewFile") Then 
		NewFile = Parameters.NewFile;
	EndIf;
	
	If Parameters.Key = Undefined Or Parameters.Key.IsEmpty() Then
		
		NewFile = True;
		
		If Parameters.CopyingValue.IsEmpty() Then
			Object.FileOwner = Parameters.FileOwner;
		Else
			Object.CurrentVersion = Catalogs.FileVersions.EmptyRef();
			Parameters.FileBasis = Parameters.CopyingValue;
		EndIf;
		
	EndIf;
	
	DocBasis = Parameters.FileBasis;
	If Not DocBasis.IsEmpty() Then
		
		Object.Details 		= DocBasis.Details;
		Object.Description 		= Object.Details;
		Object.StoreVersions 	= DocBasis.StoreVersions;
		
	EndIf;
	
	If Not Object.Ref.IsEmpty() Then
		FileData = FileOperations.GetFileData(Object.Ref);
		FileDataCorrect = True;
	EndIf;
	
	OwnerType = TypeOf(Object.FileOwner);
	Items.Owner.Title = OwnerType;
	
	NewFileRecorded = False;
	
	// Handler of the subsystem "Properties"
	AdditionalDataAndAttributesManagement.OnCreateAtServer(ThisForm, Object, "");
	
	If Parameters.Property("CardIsOpenAfterFileCreate") Then 
		If Parameters.CardIsOpenAfterFileCreate Then
			
			Try
				LockFormDataForEdit();
			Except
			EndTry;
					
		EndIf;
	EndIf;
	
	If TypeOf(Object.FileOwner) = Type("CatalogRef.FileFolders") Then
		RefreshFullPath();
	EndIf;	
	
	If Not Parameters.FileBasis.IsEmpty() Then
		FileBasisSigned = Parameters.FileBasis.Signed;
	EndIf;
	
	Items.GroupAdditionalDataPages.PagesRepresentation = FormPagesRepresentation.None;
	
EndProcedure

&AtServer
Procedure RefreshFullPath()
	
	If TypeOf(Object.FileOwner) = Type("CatalogRef.FileFolders") Then
		
		FolderParent = Object.FileOwner;
		
		FullPath = "";
		
		While Not FolderParent.IsEmpty() Do
			
			If Not IsBlankString(FullPath) Then
				FullPath = "\" + FullPath;
			EndIf;	
			
			FullPath = String(FolderParent) + FullPath;
			FolderParent = FolderParent.Parent;
			
		EndDo;

		Items.Owner.ToolTip = FullPath;
		
	EndIf;	
	
EndProcedure	

&AtClient
Procedure BeforeClose(Cancellation, StandardProcessing)
	
	If FileWasEdited And FileOperationsSecondUseClient.GetFileOperationsPersonalSettings().CurrentUser = Object.LockedBy Then 
		Response = DoQueryBox(NStr("en = 'File locked by you for edit. Do you want to close the card?'"), QuestionDialogMode.YesNo, ,DialogReturnCode.No);
		If Response = DialogReturnCode.No Then 
			Cancellation = True;
			Return;
		EndIf;	
	EndIf;

	If CreationMode = "FromTemplate" Then
		QuestionString = StringFunctionsClientServer.SubstitureParametersInString(
		  NStr("en = 'Open file ""%1"" for editing?'"),
		  TrimAll(Object.Details) );
		
		If NewFile And NewFileRecorded And (Not FileWasEdited) And DoQueryBox(QuestionString, QuestionDialogMode.YesNo, ,DialogReturnCode.Yes) = DialogReturnCode.Yes Then
			FileOperationsClient.EditFileByRef(Object.Ref, Uuid);
			NotifyChanged(Object.Ref);
			Notify("FileDataModified", Object.Ref);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "FileIsOpen" And Parameter = Object.Ref Then
		NewFile = False;
	EndIf;

	If EventName = "FileWasEdited" And Parameter = Object.Ref Then
		FileWasEdited = True;
	EndIf;

	If EventName = "FileWasEdited" And Parameter = Object.Ref Then
		FileWasEdited = True;
	EndIf;
	
	If EventName = "ObjectSigned" And Parameter = Object.Ref Then
		Read();
	EndIf;
	
	If EventName = "ActiveVersionChanged" And Parameter = Object.Ref Then
		Read();
	EndIf;
	
	// Handler of the subsystem "Properties"
	If AdditionalDataAndAttributesManagementClient.ProcessAlerts(ThisForm, EventName, Parameter) Then
		UpdateAdditionalDataAndAttributesItems();
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancellation)
	Object.Description = Object.Details;
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancellation, CurrentObject)
	
	// Handler of the subsystem "Properties"
	AdditionalDataAndAttributesManagement.BeforeWriteAtServer(ThisForm, CurrentObject);
	
	If DescriptionBeforeRecord <> CurrentObject.Description Then
		If CurrentObject.CurrentVersion.FileStorageType = Enums.FileStorageTypes.VolumesOnHardDisk Then
			FileOperations.RenameFileVersionFromDisk(CurrentObject.CurrentVersion, DescriptionBeforeRecord, CurrentObject.Description);
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject)
	If NewFile Then 
		FileData = FileOperations.GetFileData(Object.Ref);
		FileDataCorrect = True;
	EndIf;
	
	If Not Parameters.FileBasis.IsEmpty() And Object.CurrentVersion.IsEmpty() Then
		CreateCopyOfVersion(Object.Ref, Parameters.FileBasis);
		Modifed = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterWrite()
	If NewFile Then 
		NewFileRecorded = True;
		Read();
		
		AlertParameters = New Structure("Owner, File", Object.FileOwner, Object.Ref);
		Notify("FileCreated", AlertParameters);
		
	Else
		If DescriptionBeforeRecord <> Object.Description Then
			// in cache update file
			FileOperationsClient.UpdateInformationInWorkingDirectory(Object.CurrentVersion, Object.Description);
			DescriptionBeforeRecord = Object.Description;
		EndIf;
	EndIf;
	
	SetAccessibilityOfFormItems();
EndProcedure

&AtClient
Procedure OpenFileExecute()
	
	If Object.Ref.IsEmpty() Then
		Write();
	EndIf;	
	
	FileData = FileOperations.GetFileDataForOpening(Object.Ref, Undefined, 
		Uuid);

	FileOperationsCommands.Open(FileData);
	
EndProcedure

&AtClient
Procedure Edit(Command)
	
	If Object.Ref.IsEmpty() Then
		Write();
	EndIf;	
	
	If Modified Then
		Write();
	EndIf;	
	FileOperationsCommands.Edit(Object.Ref, Uuid);
	Read();
	SetAccessibilityOfFormItems();
	
EndProcedure

// get file data, if it is required
&AtClient
Procedure GetFileDataIfIncorrect()
	If FileData = Undefined OR NOT FileDataCorrect Then
		FileData = FileOperations.GetFileData(Object.Ref);
		FileDataCorrect = True;
	EndIf;
EndProcedure

&AtClient
Procedure EndEdit(Command)
	If Modified Then
		Write();
	EndIf;	
	
	GetFileDataIfIncorrect();
	
	FileOperationsCommands.EndEdit(
		FileData.Ref,
		Uuid,
		FileData.StoreVersions,
		FileData.LockedByCurrentUser,
		FileData.LockedBy);
		
	Read();
	SetAccessibilityOfFormItems();
EndProcedure

&AtClient
Procedure Take(Command)
	If Modified Then
		Write();
	EndIf;	
	FileOperationsCommands.Lock(Object.Ref, Uuid);
	Read();
	SetAccessibilityOfFormItems();
EndProcedure

&AtClient
Procedure CancelEdit(Command)
	If Modified Then
		Write();
	EndIf;	
	
	GetFileDataIfIncorrect();
	
	FileOperationsCommands.UnlockFile(
		FileData.Ref,
		FileData.StoreVersions,
		FileData.LockedByCurrentUser,
		FileData.LockedBy,
		Uuid);
		
	Read();
	SetAccessibilityOfFormItems();
EndProcedure

&AtClient
Procedure SaveChanges(Command)
	If Modified Then
		Write();
	EndIf;	
	
	FileOperationsCommands.SaveAs(Object.Ref);
	
	Read();
	SetAccessibilityOfFormItems();
EndProcedure

&AtClient
Procedure OpenFileDirectory(Command)
	FileData = FileOperations.GetFileDataForOpening(Object.Ref, Undefined, Uuid);
	FileOperationsCommands.OpenFileDirectory(FileData);
EndProcedure

&AtClient
Procedure SaveAs(Command)
	FileData = FileOperations.GetFileDataForSaving(Object.Ref, Undefined, Uuid);
	FileOperationsCommands.SaveAs(FileData);
EndProcedure

&AtClient
Procedure UpdateFromFileOnDisk(Command)
	If Modified Then
		Write();
	EndIf;	
	
	FileData = FileOperations.GetFileData(Object.Ref);
	FileOperationsCommands.UpdateFromFileOnDisk(FileData, Uuid);
	Read();
EndProcedure

&AtClient
Procedure Save(Command)
	
	If Items.TableOfSignatures.CurrentData = Undefined Then
		Return;
	EndIf;	
	
	If Items.TableOfSignatures.CurrentData.Object <> Undefined And (NOT Items.TableOfSignatures.CurrentData.Object.IsEmpty()) Then
		
		SignatureAddress = Items.TableOfSignatures.CurrentData.SignatureAddress;
		
		ExtensionConnected = AttachFileSystemExtension();
		If ExtensionConnected Then
			
			FileOpenDialog = New FileDialog(FileDialogMode.Save);
			Filter = NStr("en = 'All files(*.p7s)|*.p7s'");
			FileOpenDialog.Filter = Filter;
			FileOpenDialog.Multiselect = False;
			FileOpenDialog.Title = NStr("en = 'Select the file to save the signature'");
			
			If FileOpenDialog.Choose() Then
				
				FullPathOfSignature = FileOpenDialog.FullFileName;
				
				File = New File(FullPathOfSignature);
				FilesBeingTransmitted = New Array;
				Details = New TransferableFileDescription(FullPathOfSignature, SignatureAddress);
				FilesBeingTransmitted.Add(Details);
				
				PathToFile = File.Path;
				If Right(PathToFile,1) <> "\" Then
					PathToFile = PathToFile + "\";
				EndIf;
				
				// Save file from DB to a drive
				GetFiles(FilesBeingTransmitted,, PathToFile, False);
					
				Text = StringFunctionsClientServer.SubstitureParametersInString(
					NStr("en = 'The signature is saved in the file ""%1""'"),
					FileOpenDialog.FullFileName);
				Status(Text);
				
			EndIf;
			
		EndIf;		
		
	EndIf;	
	
EndProcedure

&AtClient
Procedure Delete(Command)
	
	If DoQueryBox(NStr("en = 'Delete selected signature?'"), QuestionDialogMode.YesNo) <> DialogReturnCode.Yes Then
		Return;
	EndIf;	
	
	AttributeSignedChanged = False;
	
	If AttributeSignedChanged Then
		NotifyChanged(Object.Ref);
		Read();
	EndIf;
	
	Notify("AttachedFileSigned", Object.FileOwner);
	
	SetAccessibilityOfFormItems();
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// PROCEDURES OF PROPERTIES SUBSYSTEM

&AtClient
Procedure Pluggable_EditContentOfProperties()
	
	AdditionalDataAndAttributesManagementClient.EditContentOfProperties(ThisForm, Object.Ref);
	
EndProcedure

&AtServer
Procedure UpdateAdditionalDataAndAttributesItems()
	
	AdditionalDataAndAttributesManagement.UpdateAdditionalDataAndAttributesItems(ThisForm, FormAttributeToValue("Object"));
	
EndProcedure

&AtClient
Procedure OwnerOnChange(Item)
	
	RefreshFullPath();
	
EndProcedure
