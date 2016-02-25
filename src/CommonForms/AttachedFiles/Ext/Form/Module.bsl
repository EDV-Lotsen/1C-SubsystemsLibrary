
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetConditionalAppearance();
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	If Parameters.FileOwner = Undefined Then
		Raise NStr("en = 'The list of attached files 
		                  |is only available in the owner object form.'");
	EndIf;
	
	If Parameters.ChoiceMode Then
		PurposeUseKey = "SelectionPick";
		WindowOpeningMode = FormWindowOpeningMode.LockOwnerWindow;
		
		Title = NStr("en = 'Select attached file'");
		
		// Applying a filter that excludes items marked for deletion
		CommonUseClientServer.SetDynamicListFilterItem(
			List, "DeletionMark", False, , , True,
			DataCompositionSettingsItemViewMode.Normal);
	Else
		Items.List.ChoiceMode = False;
	EndIf;
	
	FileStorageCatalogName = Undefined;
	SetUpDynamicList(FileStorageCatalogName);
	
	TypeOfCatalogWithFiles = Type("CatalogRef." + FileStorageCatalogName);
	
	MetadataOfCatalogWithFiles = Metadata.FindByType(TypeOfCatalogWithFiles);
	
	If Not AccessRight("InteractiveInsert", MetadataOfCatalogWithFiles) Then
		HideAddButtons();
	EndIf;
	
	If Not AccessRight("Edit", MetadataOfCatalogWithFiles)
	 Or Not AccessRight("Edit", Parameters.FileOwner.Metadata())
	 Or Parameters.ReadOnly = True Then
		
		HideChangeButtons();
	EndIf;
	
	AllFormCommandNames = GetFormCommandNames();
	ItemNames = New Array;
	
	For Each FormItem In Items Do
		
		If TypeOf(FormItem) <> Type("FormButton") Then
			Continue;
		EndIf;
		
		If AllFormCommandNames.Find(FormItem.CommandName) <> Undefined Then
			ItemNames.Add(FormItem.Name);
		EndIf;
	EndDo;
	
	FormButtonItemNames = New FixedArray(ItemNames);
	
	SetPrivilegedMode(True);
	If Not CommonUse.SubsystemExists("StandardSubsystems.DigitalSignature")
	 Or Constants["UseDigitalSignatures"].Get() <> True Then
		
		Items.ListSignedEncryptedPictureNumber.Visible = False;
	EndIf;
	SetPrivilegedMode(False);
	
	If ClientApplicationInterfaceCurrentVariant() = ClientApplicationInterfaceVariant.Version8_2 Then
		Items.FormChange.Visible = False;
		Items.FormChange82.Visible = True;
		Items.FormCopy.OnlyInAllActions = False;
		Items.FormSetDeletionMark.OnlyInAllActions = False;
	EndIf;
	
	CommonUseClientServer.MoveFiltersToDynamicList(ThisObject);
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SetButtonsEnabled();
	
	// CurrentDate is received not for saving to the database.
	// It is used only for calculating the difference between the local time
	// and the universal time in the dynamic list.
	// Therefore, conversion to CurrentSessionDate is not required.
	CurrentClientDate = CurrentDate();
	
	List.Parameters.SetParameterValue(
		"SecondsToLocalTime",
		CurrentClientDate - ToUniversalTime(CurrentClientDate));
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName <> "Write_AttachedFile" Then
		Return;
	EndIf;
		
	RefToFile = ?(TypeOf(Source) = Type("Array"), Source[0], Source);
	
	If Parameter.Property("IsNew") And Parameter.IsNew Then
		
		Items.List.CurrentRow = RefToFile;
		SetButtonsEnabled();
	Else
		If Not CheckActionAllowed() Then
			Return;
		EndIf;
		
		If RefToFile = Items.List.CurrentData.Ref Then
			SetButtonsEnabled();
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region ListFormTableItemEventHandlers

&AtClient
Procedure ListChoice(Item, SelectedRow, Field, StandardProcessing)
	
	If Items.List.ChoiceMode Then
		Return;
	EndIf;
	
	StandardProcessing = False;
	
	OpenFile();
	
EndProcedure

&AtClient
Procedure ListOnActivateRow(Item)
	
	SetButtonsEnabled();
	
EndProcedure

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Clone, Parent, Group)
	
	Cancel = True;
	
	If Clone Then
		
		If Not CheckActionAllowed() Then
			Return;
		EndIf;
		
		FormParameters = New Structure("CopyingValue", Item.CurrentData.Ref);
		
		OpenForm("CommonForm.AttachedFile", FormParameters);
		
	Else
		AttachedFilesClient.AddFiles(Parameters.FileOwner, UUID);
	EndIf;
	
EndProcedure

&AtClient
Procedure ListBeforeRowChange(Item, Cancel)
	
	Cancel = True;
	
	If Not CheckActionAllowed() Then
		Return;
	EndIf;
	
	CurrentData = Items.List.CurrentData;
	
	FormParameters = New Structure;
	FormParameters.Insert("Key",      CurrentData.Ref);
	FormParameters.Insert("ReadOnly", ReadOnly);
	
	OpenForm("CommonForm.AttachedFile", FormParameters, , False);
	
EndProcedure

&AtClient
Procedure ListDragCheck(Item, DragParameters, StandardProcessing, String, Field)
	
	StandardProcessing = False;
	
EndProcedure

&AtClient
Procedure ListDrag(Item, DragParameters, StandardProcessing, String, Field)
	
	StandardProcessing = False;
	
	FileNameArray = New Array;
	
	If TypeOf(DragParameters.Value) = Type("File")
	   And DragParameters.Value.IsFile() = True Then
		
		FileNameArray.Add(DragParameters.Value.FullName);
		
	ElsIf TypeOf(DragParameters.Value) = Type("Array") Then
		
		If DragParameters.Value.Count() >= 1
		   And TypeOf(DragParameters.Value[0]) = Type("File") Then
			
			For Each Value In DragParameters.Value Do
				
				If TypeOf(Value) = Type("File") And Value.IsFile() Then
					FileNameArray.Add(Value.FullName);
				EndIf;
			EndDo;
		EndIf;
			
	EndIf;
	
	If FileNameArray.Count() > 0 Then
		
		AttachedFilesInternalClient.AddFilesWithDrag(
			Parameters.FileOwner, UUID, FileNameArray);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

///////////////////////////////////////////////////////////////////////////////////
// File event handlers

&AtClient
Procedure Create(Command)
	
	Items.List.AddRow();
	
EndProcedure

&AtClient
Procedure OpenFileForViewing(Command)
	
	OpenFile();
	
EndProcedure

&AtClient
Procedure OpenFileDirectory(Command)
	
	If Not CheckActionAllowed() Then
		Return;
	EndIf;
	
	CurrentData = Items.List.CurrentData;
	
	If CurrentData.Encrypted Then
		Return;
	EndIf;
	
	FileData = GetFileData(CurrentData.Ref, UUID);
	
	If CurrentData.Encrypted Then
		// The file might be changed in another session
		NotifyChanged(CurrentData.Ref);
		Return;
	EndIf;
	
	AttachedFilesInternalClient.OpenDirectoryWithFile(FileData);
	
EndProcedure

&AtClient
Procedure UpdateFromFileOnHardDisk(Command)
	
	If Not CheckActionAllowed() Then
		Return;
	EndIf;
	
	CurrentData = Items.List.CurrentData;
	If CurrentData.Encrypted Or CurrentData.SignedWithDS Or CurrentData.FileBeingEdited Then
		Return;
	EndIf;
	
	FileData = GetFileData(CurrentData.Ref, , False);
	If FileData.Encrypted Or FileData.SignedWithDS Or FileData.FileBeingEdited Then
		// The file might be changed in another session
		NotifyChanged(CurrentData.Ref);
		Return;
	EndIf;
	
	AttachedFilesInternalClient.UpdateAttachedFile(CurrentData.Ref, FileData, UUID);
	
EndProcedure

&AtClient
Procedure SaveAs(Command)
	
	If Not CheckActionAllowed() Then
		Return;
	EndIf;
	
	CurrentData = Items.List.CurrentData;
	
	If CurrentData.Encrypted
	 Or (CurrentData.FileBeingEdited And CurrentData.FileEditedByCurrentUser) Then
		Return;
	EndIf;
	
	FileData = GetFileData(CurrentData.Ref, UUID);
	
	If FileData.Encrypted
	 Or (FileData.FileBeingEdited And FileData.FileEditedByCurrentUser) Then
		// The file might be changed in another session
		NotifyChanged(CurrentData.Ref);
		Return;
	EndIf;
	
	AttachedFilesClient.SaveFileAs(FileData);
	
EndProcedure

&AtClient
Procedure Copy(Command)
	
	Items.List.CopyRow();
	
EndProcedure

&AtClient
Procedure OpenFileProperties(Command)
	
	If Items.List.CurrentData = Undefined Then
		Return
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("AttachedFile", Items.List.CurrentData.Ref);
	
	OpenForm("CommonForm.AttachedFile", FormParameters);
	
EndProcedure

&AtClient
Procedure SetDeletionMarkCommand(Command)
	
	If Not CheckActionAllowed("DeletionMark") Then
		Return;
	EndIf;
	
	CurrentData = Items.List.CurrentData;
	
	If CurrentData.DeletionMark Then
		QuestionText = NStr("en = 'Do you want to remove the deletion mark from file %1?'");
	Else
		QuestionText = NStr("en = 'Do you want to mark the file %1 for deletion?'");
	EndIf;
	
	QuestionText = StringFunctionsClientServer.SubstituteParametersInString(QuestionText, CurrentData.Ref);
	
	NotifyDescription = New NotifyDescription("SetDeletionMarkAnswerReceived", ThisObject, CurrentData);
	ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
	
EndProcedure

&AtClient
Procedure SetDeletionMarkAnswerReceived(QuestionResult, CurrentData) Export
	If QuestionResult = DialogReturnCode.Yes Then
		SetDeletionMark(CurrentData.Ref, Not CurrentData.DeletionMark);
		Items.List.Refresh();
	EndIf;
EndProcedure

///////////////////////////////////////////////////////////////////////////////////
// Digital signature and encryption command handlers.

&AtClient
Procedure DigitalSignatureSign(Command)
	
	If Not CheckActionAllowed() Then
		Return;
	EndIf;
	
	CurrentData = Items.List.CurrentData;
	
	If CurrentData.FileBeingEdited
	 Or CurrentData.Encrypted Then
		Return;
	EndIf;
	
	FileData = GetFileData(CurrentData.Ref, UUID);
	
	If FileData.FileBeingEdited
	 Or FileData.Encrypted Then
		// The file might be changed in another session
		NotifyChanged(CurrentData.Ref);
		Return;
	EndIf;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("AttachedFile", CurrentData.Ref);
	AdditionalParameters.Insert("FileData", FileData);
	AdditionalParameters.Insert("UserNotification");
	AdditionalParameters.Insert("ResultHandler",
		New NotifyDescription("DigitalSignatureSignSignatureGenerated", ThisObject));
	
	AttachedFilesInternalClient.GenerateFileSignature(AdditionalParameters);
	
EndProcedure

&AtClient
Procedure DigitalSignatureSignSignatureGenerated(Result, NotDefined) Export
	
	If Result.SignatureGenerated Then
		SetButtonsEnabled();
	EndIf;
	
EndProcedure

&AtClient
Procedure SaveWithDigitalSignature(Command)
	
	If Not CheckActionAllowed() Then
		Return;
	EndIf;
	
	CurrentData = Items.List.CurrentData;
	
	If CurrentData.Encrypted Then
		Return;
	EndIf;
	
	FileData = GetFileData(CurrentData.Ref, UUID);
	
	If FileData.Encrypted Then
		// The file might be changed in another session
		NotifyChanged(CurrentData.Ref);
		Return;
	EndIf;
	
	AttachedFilesClient.SaveWithDigitalSignature(CurrentData.Ref, FileData, UUID);
	
EndProcedure

&AtClient
Procedure AddDigitalSignatureFromFile(Command)
	
	If Not CheckActionAllowed() Then
		Return;
	EndIf;
	
	CurrentData = Items.List.CurrentData;
	
	If CurrentData.FileBeingEdited
	 Or CurrentData.Encrypted Then
		Return;
	EndIf;
	
	AttachedFilesInternalClient.AddDigitalSignatureFromFile(
		CurrentData.Ref, UUID);
	
EndProcedure

&AtClient
Procedure Encrypt(Command)
	
	If Not CheckActionAllowed() Then
		Return;
	EndIf;
	
	CurrentData = Items.List.CurrentData;
	
	If CurrentData.FileBeingEdited
	 Or CurrentData.Encrypted Then
		Return;
	EndIf;
	
	FileData = GetFileData(CurrentData.Ref, UUID);
	
	If FileData.FileBeingEdited
	 Or FileData.Encrypted Then
		// The file might be changed in another session
		NotifyChanged(CurrentData.Ref);
		Return;
	EndIf;
	
	AttachedFilesInternalClient.Encrypt(
		CurrentData.Ref, FileData, UUID);
	
	SetButtonsEnabled();
	
EndProcedure

&AtClient
Procedure Decrypt(Command)
	
	If Not CheckActionAllowed() Then
		Return;
	EndIf;
	
	CurrentData = Items.List.CurrentData;
	
	If Not CurrentData.Encrypted Then
		Return;
	EndIf;
	
	FileData = GetFileData(CurrentData.Ref, UUID);
	
	If Not FileData.Encrypted Then
		// The file might be changed in another session
		NotifyChanged(CurrentData.Ref);
		Return;
	EndIf;
	
	AttachedFilesInternalClient.Decrypt(
		CurrentData.Ref, FileData, UUID);
	
	SetButtonsEnabled();
	
EndProcedure

///////////////////////////////////////////////////////////////////////////////////
// Command handlers that support shared access to files.

&AtClient
Procedure Edit(Command)
	
	If Not CheckActionAllowed() Then
		Return;
	EndIf;
	
	CurrentData = Items.List.CurrentData;
	
	If (CurrentData.FileBeingEdited And Not CurrentData.FileEditedByCurrentUser)
	 Or CurrentData.Encrypted
	 Or CurrentData.SignedWithDS Then
		Return;
	EndIf;
	
	FileData = GetFileData(CurrentData.Ref, UUID);
	
	If (  FileData.FileBeingEdited
	      And Not FileData.FileEditedByCurrentUser)
	 Or FileData.Encrypted
	 Or FileData.SignedWithDS Then
		// The file might be changed in another session
		NotifyChanged(CurrentData.Ref);
		Return;
	EndIf;
	
	AttachedFilesClient.OpenFile(FileData, True);
	
	If Not CurrentData.FileBeingEdited Then
		
		LockFileForEditingServer(CurrentData.Ref);
		
		NotifyChanged(CurrentData.Ref);
		SetButtonsEnabled();
	EndIf;
	
EndProcedure

&AtClient
Procedure EndEdit(Command)
	
	If Not CheckActionAllowed() Then
		Return;
	EndIf;
	
	CurrentData = Items.List.CurrentData;
	
	If Not CurrentData.FileBeingEdited
	 Or Not CurrentData.FileEditedByCurrentUser Then
		Return;
	EndIf;
	
	FileData = GetFileData(CurrentData.Ref, , False);
	
	If Not FileData.FileBeingEdited
	 Or Not FileData.FileEditedByCurrentUser Then
		Return;
	EndIf;
	
	NotifyDescription = New NotifyDescription("EndEditPuttingCompleted", ThisObject, CurrentData);
	AttachedFilesInternalClient.PutFileEditedOnHardDiskInStorage(NotifyDescription, FileData, UUID);
	
EndProcedure

&AtClient
Procedure EndEditPuttingCompleted(FileInfo, CurrentData) Export
	
	If FileInfo <> Undefined Then
		PutFileToStorageAndUnlock(CurrentData.Ref, FileInfo);
		NotifyChanged(CurrentData.Ref);
		SetButtonsEnabled();
	EndIf;
	
EndProcedure

&AtClient
Procedure Unlock(Command)
	
	If Not CheckActionAllowed() Then
		Return;
	EndIf;
	
	CurrentData = Items.List.CurrentData;
	
	If Not CurrentData.FileBeingEdited
	 Or Not CurrentData.FileEditedByCurrentUser Then
		Return;
	EndIf;
	
	UnlockFile(CurrentData.Ref);
	NotifyChanged(CurrentData.Ref);
	SetButtonsEnabled();
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	// Appearance of the file that is being edited by another user
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.List.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue      = New DataCompositionField("List.FileEditedByAnotherUser");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue     = True;
	
	Item.Appearance.SetParameterValue("TextColor", StyleColors.LockedByAnotherUserFile);
	
	// Appearance of the file that is being edited by the current user
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.List.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue      = New DataCompositionField("List.FileEditedByCurrentUser");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue     = True;
	
	Item.Appearance.SetParameterValue("TextColor", StyleColors.FileLockedByCurrentUser);
	
EndProcedure

&AtClient
Procedure OpenFile()
	
	If Not CheckActionAllowed() Then
		Return;
	EndIf;
	
	CurrentData = Items.List.CurrentData;
	
	If CurrentData.Encrypted Then
		Return;
	EndIf;
	
	FileBeingEdited = CurrentData.FileBeingEdited And CurrentData.FileEditedByCurrentUser;
	
	FileData = GetFileData(CurrentData.Ref, UUID);
	
	If FileData.Encrypted Then
		// The file might be changed in another session
		NotifyChanged(CurrentData.Ref);
		Return;
	EndIf;
	
	AttachedFilesClient.OpenFile(FileData, FileBeingEdited);
	
EndProcedure

&AtClient
Function CheckActionAllowed(Val CurrentAction = "")
	
	If Items.List.CurrentData = Undefined Then
		Return False;
	EndIf;
	
	CurrentData = Items.List.CurrentData;
	
	If CurrentAction = "DeletionMark" And CurrentData.FileBeingEdited Then
		
		If CurrentData.FileEditedByCurrentUser Then
			WarningText = NStr("en = 'The action cannot be performed because the file is locked for editing.'");
		Else
			WarningText = NStr("en = 'The action cannot be performed because the 
			                          |file is locked for editing by another user.'");
		EndIf;
		
		ShowMessageBox(, WarningText);
		Return False;
	EndIf;
	
	If TypeOf(Items.List.CurrentRow) = TypeOfCatalogWithFiles Then
		Return True;
	Else
		ShowMessageBox(, NStr("en = 'The action cannot be performed for a list group row.'"));
		Return False;
	EndIf;
	
	If Not Items.FormCopy.Visible
	 Or Not Items.FormCopy.Enabled Then
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

&AtServer
Procedure HideAddButtons()
	
	Items.FormCreate.Visible = False;
	Items.ListContextMenuCreate.Visible = False;
	
	Items.FormCopy.Visible = False;
	Items.ListContextMenuCopy.Visible = False;
	
EndProcedure

&AtServer
Procedure HideChangeButtons()
	
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

&AtClient
Procedure SetButtonsEnabled()
	
#If WebClient Then
	Return;
#EndIf
	
	CurrentData = Items.List.CurrentData;
	
	If CurrentData = Undefined Then
		CommandNames = New Array;
		CommandNames.Add("Create");
		
	ElsIf TypeOf(Items.List.CurrentRow) <> TypeOfCatalogWithFiles Then
		CommandNames = New Array;
	Else
		CommandNames = GetAvailableCommands(
			CurrentData.FileBeingEdited,
			CurrentData.FileEditedByCurrentUser,
			CurrentData.SignedWithDS,
			CurrentData.Encrypted);
	EndIf;
	
	For Each FormItemName In FormButtonItemNames Do
		
		FormItem = Items.Find(FormItemName);
		
		If CommandNames.Find(FormItem.CommandName) <> Undefined Then
			If Not FormItem.Enabled Then
				FormItem.Enabled = True;
			EndIf;
			
		ElsIf FormItem.Enabled Then
			FormItem.Enabled = False;
		EndIf;
	EndDo;
	
EndProcedure

&AtServerNoContext
Function GetFileData(Val AttachedFile,
                     Val FormID = Undefined,
                     Val GetBinaryDataRef = True)
	
	Return AttachedFiles.GetFileData(
		AttachedFile, FormID, GetBinaryDataRef);
	
EndFunction

&AtServerNoContext
Procedure LockFileForEditingServer(Val AttachedFile)
	
	AttachedFilesInternal.LockFileForEditingServer(AttachedFile);
	
EndProcedure

&AtServerNoContext
Procedure UnlockFile(Val AttachedFile)
	
	AttachedFilesInternal.UnlockFile(AttachedFile);
	
EndProcedure

&AtServerNoContext
Procedure PutFileToStorageAndUnlock(Val AttachedFile,
                                             Val FileInfo)
	
	AttachedFilesInternal.PutFileToStorageAndUnlock(
		AttachedFile, FileInfo);
	
EndProcedure

&AtServerNoContext
Procedure SetDeletionMark(Val AttachedFile, Val DeletionMark)
	
	AttachedFileObject = AttachedFile.GetObject();
	AttachedFileObject.DeletionMark = DeletionMark;
	AttachedFileObject.Write();
	
EndProcedure

&AtServer
Procedure SetUpDynamicList(FileStorageCatalogName)
	
	QueryText = 
	"SELECT
	|	Files.Ref AS Ref,
	|	Files.DeletionMark,
	|	CASE
	|		WHEN Files.DeletionMark = TRUE
	|			THEN Files.PictureIndex + 1
	|		ELSE Files.PictureIndex
	|	END AS PictureIndex,
	|	Files.Description AS Description,
	|	CAST(Files.Details AS STRING(500)) AS Details,
	|	Files.Author,
	|	Files.CreationDate,
	|	Files.Changed AS Edited,
	|	DATEADD(Files.ModificationDateUniversal, SECOND, &SecondsToLocalTime) AS ChangeDate,
	|	CAST(Files.Size / 1024 AS NUMBER(10, 0)) AS Size,
	|	Files.SignedWithDS,
	|	Files.Encrypted,
	|	CASE
	|		WHEN Files.SignedWithDS
	|				AND Files.Encrypted
	|			THEN 2
	|		WHEN Files.Encrypted
	|			THEN 1
	|		WHEN Files.SignedWithDS
	|			THEN 0
	|		ELSE -1
	|	END AS SignedEncryptedPictureNumber,
	|	CASE
	|		WHEN Files.Edits <> VALUE(Catalog.Users.EmptyRef)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS FileBeingEdited,
	|	CASE
	|		WHEN Files.Edits = &CurrentUser
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS FileEditedByCurrentUser,
	|	CASE
	|		WHEN Files.Edits <> VALUE(Catalog.Users.EmptyRef)
	|				AND Files.Edits <> &CurrentUser
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS FileEditedByAnotherUser,
	|	Files.Edits AS Edits
	|FROM
	|	&CatalogName AS Files
	|WHERE
	|	Files.FileOwner = &FilesOwner";
	
	ErrorTitle = NStr("en = 'Error setting up the dynamic list of attached files.'");
	ErrorEnd = NStr("en = 'Cannot set up the dynamic list.'");
	
	FileStorageCatalogName = AttachedFilesInternal.FileStoringCatalogName(
		Parameters.FileOwner, "", ErrorTitle, Undefined, ErrorEnd);
	
	FullCatalogName = "Catalog." + FileStorageCatalogName;
	List.QueryText = StrReplace(QueryText, "&CatalogName", FullCatalogName);
	
	List.Parameters.SetParameterValue("FilesOwner",         Parameters.FileOwner);
	List.Parameters.SetParameterValue("CurrentUser",        Users.CurrentUser());
	List.Parameters.SetParameterValue("SecondsToLocalTime", '00010101'); // This is set on the client
	List.MainTable = FullCatalogName;
	List.DynamicDataRead = True;
	
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
Function GetObjectChangeCommandNames()
	
	CommandNames = New Array;
	
	// Commands that depend on object states
	CommandNames.Add("EndEdit");
	CommandNames.Add("Unlock");
	CommandNames.Add("Edit");
	CommandNames.Add("SetDeletionMark");
	
	CommandNames.Add("DigitalSignatureSign");
	CommandNames.Add("AddDigitalSignatureFromFile");
	CommandNames.Add("SaveWithDigitalSignature");
	
	CommandNames.Add("Encrypt");
	CommandNames.Add("Decrypt");
	
	CommandNames.Add("UpdateFromFileOnHardDisk");
	
	// Commands that do not depend on object states
	CommandNames.Add("Create");
	CommandNames.Add("OpenFileProperties");
	CommandNames.Add("Copy");
	
	Return CommandNames;
	
EndFunction

&AtClientAtServerNoContext
Function GetSimpleObjectCommandNames()
	
	CommandNames = New Array;
	
	// Simple commands that are available to any user that reads the files
	CommandNames.Add("OpenFileDirectory");
	CommandNames.Add("OpenFileForViewing");
	CommandNames.Add("SaveAs");
	
	Return CommandNames;
	
EndFunction

&AtClientAtServerNoContext
Function GetAvailableCommands(FileBeingEdited,
                              FileEditedByCurrentUser,
                              FileSigned,
                              FileEncrypted)
	
	CommandNames = GetFormCommandNames();
	
	If FileBeingEdited Then
		If FileEditedByCurrentUser Then
			DeleteCommandFromArray(CommandNames, "UpdateFromFileOnHardDisk");
		Else
			DeleteCommandFromArray(CommandNames, "EndEdit");
			DeleteCommandFromArray(CommandNames, "Unlock");
			DeleteCommandFromArray(CommandNames, "Edit");
		EndIf;
		DeleteCommandFromArray(CommandNames, "SetDeletionMark");
		
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
	Else
		DeleteCommandFromArray(CommandNames, "Decrypt");
	EndIf;
	
	Return CommandNames;
	
EndFunction

&AtClientAtServerNoContext
Procedure DeleteDigitalSignatureCommands(CommandNames)
	
	DeleteCommandFromArray(CommandNames, "DigitalSignatureSign");
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

#EndRegion
