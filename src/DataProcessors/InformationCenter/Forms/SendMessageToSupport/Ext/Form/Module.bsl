////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
// Skipping the initialization to guarantee that the form will be received if the AutoTest parameter is passed.
	If Parameters.Property("AutoTest") Then 
		Return;
	EndIf;
	
	If Parameters.Property("FromWhom") Then 
		FromWhom = Parameters.FromWhom;
	EndIf;
	
	If Parameters.Property("Text") Then 
		Text = Parameters.Text;
		PointerPositionString = NStr("en = 'PointerPosition'");
		PointerLine = GetPositionNumberForPointer(Text, PointerPositionString) - 9;
		Text = StrReplace(Text, PointerPositionString, "");
		Content.SetHTML(Text, New Structure);
	EndIf;
	
	If Parameters.Property("Attachments") Then 
		If TypeOf(Parameters.Attachments) = Type("ValueList") Then 
			For Each ListRow In Parameters.Attachments Do 
				Attachments.Add(ListRow.Value, ListRow.Presentation);
			EndDo;
		EndIf;
	EndIf;
	
	If Parameters.Property("ShowTopic") Then 
		Items.Subject.Visibility = Parameters.ShowTopic;
	EndIf;
	
	TechParameterFileName = InformationCenterServer.GetTechParameterFileNameForMessagesToSupport();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	MaxFilesSize = InformationCenterClient.MaxAttachmentSizeForOutgoingMessagesToServiceSupport();;
	
	SetPointerInTextPattern();
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS

&AtClient
Procedure AttachFile(Item)
	
#If WebClient Then
	ExtensionAttached = AttachFileSystemExtension();
#Else
	ExtensionAttached = True;
#EndIf
	
	AddExternalFiles(ExtensionAttached);
	
EndProcedure

&AtClient
Procedure DeleteFile(Item)
	
	For Iteration = 0 to FilesToSelect.Count() - 1 Do 
		
		If FilesToSelect.Get(Iteration).DeletionButtonName = Item.Name Then 
			NameIndex = GetFormItemIndex(Item.Name);
			DeleteAllChildItems(NameIndex);
			DeleteFromTempStorage(FilesToSelect.Get(Iteration).StorageAddress);
			ListItem = Attachments.FindByID(FilesToSelect.Get(Iteration).IDInValueList);
			If ListItem <> Undefined Then 
				Attachments.Delete(ListItem);
			EndIf;
			FilesToSelect.Get(Iteration).Size = 0;
			Return;
		EndIf;
		
	EndDo;
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure Send(Command)
	
	If Not CheckAttributeFilling() Then 
		Return;
	EndIf;
	
	SendingResult = SendMessageServer();
	If SendingResult Then 
		ShowUserNotification(NStr("en = 'Message sent.'"));
		Close();
	Else
		ClearMessages();
		ShowUserMessage(NStr("en = 'Message cannot be sent.
			|Please try again later.'"));
	EndIf;
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

&AtServer
Procedure DeleteAllChildItems(ItemIndex)
	
	FoundItem = Items.Find("FileGroup" + String(ItemIndex));
	If FoundItem <> Undefined Then 
		Items.Delete(FoundItem);
	EndIf;
	
	FoundItem = Items.Find("FileNameText" + String(ItemIndex));
	If FoundItem <> Undefined Then 
		Items.Delete(FoundItem);
	EndIf;
	
	FoundItem = Items.Find("FileDeletionButton" + String(ItemIndex));
	If FoundItem <> Undefined Then 
		Items.Delete(FoundItem);
	EndIf;
	
EndProcedure

&AtClient
Function GetFormItemIndex(TagName)
	
	StartPosition = StrLen("FileDeletionButton") + 1;
	Return Number(Mid(TagName, StartPosition));
	
EndFunction

&AtClient
Function CheckAttributeFilling()
	
	If Not ValueIsFilled(FromWhom) Then 
		ClearMessages();
		ShowUserMessage(NStr("en = 'The reply address is not filled.'"));
		Return False;
	EndIf;
	
	If Find(FromWhom, "@") = 0 Then 
		ClearMessages();
		ShowUserMessage(NStr("en = 'The reply address must contain the at sign (@).'"));
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

&AtClient
Procedure AddExternalFiles(ExtensionAttached)
	
	If ExtensionAttached Then 
		PutFilesWithExtension();
	Else
		PutFilesWithoutExtension();
	EndIf;
	
EndProcedure

&AtClient
Procedure PutFilesWithExtension()
	
	// Calling the file selection dialog
	Dialog = New FileDialog(FileDialogMode.Open);
	Dialog.Title = NStr("en = 'Select file'");
	Dialog.Multiselect = True;
	If Not Dialog.Choose() Then
		Return;
	EndIf;
	SelectedFiles = Dialog.SelectedFiles;
	
	// Verifying the file size
	If Not TotalFileSizeOptimalClient(MaxFilesSize, SelectedFiles) Then 
		MessageText = NStr("en = 'Size of the selected files exceeds the %1-MB limit.'");
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessageText, MaxFilesSize);
		ClearMessages();
		ShowUserMessage(MessageText);
		Return;
	EndIf;
	
	Status(NStr("en = 'Please wait. The selected files are being attached to the message.'"));
	
	// Adding the files to the table.
	AddFilesTeSelectedFileTable(SelectedFiles);
	
	AddFilesToForm();
	
	Status();
	
EndProcedure

&AtServer
Procedure AddFilesToForm()
	
	// Creating items for the attached files.
	CreateFormItemsForAttachedFile();
	
	// Adding the files to the value list.
	AddFilesToListToSend();
	
EndProcedure

&AtClient
Procedure PutFilesWithoutExtension()
	
	StorageAddress   = "";
	SelectedFileName = "";
	
	If Not PutFile(StorageAddress, , SelectedFileName, True, UUID) Then
		Return;
	EndIf;
	
	FileName = GetFileName(SelectedFileName);
	PutFilesWithoutExtensionAtServer(StorageAddress, FileName);
	
EndProcedure

&AtClient
Function GetFileName(SelectedFileName)
	
	FileName = SelectedFileName;
	
	While Find(FileName, "/") <> 0 Or
		Find(FileName, "\") <> 0 Do
		
		ItemPosition = Find(SelectedFileName, "/");
		FileName = Mid(FileName, ItemPosition + 1);
		
		ItemPosition = Find(SelectedFileName, "\");
		FileName = Mid(FileName, ItemPosition + 1);
		
	EndDo;
	
	Return FileName;
	
EndFunction

&AtServer
Procedure PutFilesWithoutExtensionAtServer(StorageAddress, FileName)
	
	NewFile = GetFromTempStorage(StorageAddress);
	
	// Verifying total size of the files
	If Not TotalFileSizeOptimalServer(MaxFilesSize, NewFile) Then 
		MessageText = NStr("en = 'Size of the selected files exceeds the %1-MB limit.'");
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessageText, MaxFilesSize);
		ShowUserMessage(MessageText);
		DeleteFromTempStorage(StorageAddress);
		Return;
	EndIf;
	
	// Deleting the TechnicalParameters.xml file if it exists
	If Upper(FileName) = Upper(TechParameterFileName) Then 
		MessageText = NStr("en = 'The file named ''%1'' cannot be attached to the message.
									|Rename the file.'");
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessageText, FileName);
		ShowUserMessage(MessageText);
		DeleteFromTempStorage(StorageAddress);
		Return;
	EndIf;
	
	TableRow          = FilesToSelect.Add();
	TableRow.FileName = FileName;
	TableRow.Size     = NewFile.Size() / 1024;
	TableRow.StorageAddress = StorageAddress;
	
	CreateFormItemsForAttachedFile();
	
	AddFilesToListToSend();
	
EndProcedure

&AtClient
Function TotalFileSizeOptimalClient(MaxSize, SelectedFiles)
	
	If GetTotalSelectedFileSize(SelectedFiles) > MaxSize Then 
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

&AtServer
Function TotalFileSizeOptimalServer(MaxFilesSize, NewFile)
	
	Size = NewFile.Size() / 1024 / 1024 ;
	
	// Counting total size of the files attached to the email message (whose check boxes are selected)
	For Iteration = 0 to FilesToSelect.Count() - 1 Do
		Size	= Size + (FilesToSelect.Get(Iteration).Size / 1024);
	EndDo;
	
	If Size > MaxFilesSize Then 
		Return False;
	Else
		Return True;
	EndIf;
	
EndFunction

&AtClient
Function GetTotalSelectedFileSize(SelectedFiles)
	
	Size = 0;
	
	For Iteration = 0 to SelectedFiles.Count() -1 Do 
		CurrentFile		= New File(SelectedFiles.Get(Iteration));
		Size			= Size + CurrentFile.Size();
	EndDo;
	
	// Counting total size of the files attached to the email message (whose check boxes are selected)
	For Iteration = 0 to FilesToSelect.Count() - 1 Do
		Size	= Size + (FilesToSelect.Get(Iteration).Size / 1024);
	EndDo;
	
	SizeInMegabytes = Size / 1024 / 1024;
	
	Return SizeInMegabytes;
	
EndFunction

&AtClient
Procedure AddFilesTeSelectedFileTable(SelectedFiles)
	
#If WebClient Then
	OperationArray = New Array;
	For Iteration = 0 to SelectedFiles.Count() - 1 Do
		CallDetails = New Array;
		CallDetails.Add("PutFiles");
		
		FilesToBePlaced = New Array;
		Details = New TransferableFileDescription(SelectedFiles.Get(Iteration));
		FilesToBePlaced.Add(Details);
		CallDetails.Add(FilesToBePlaced);
		
		CallDetails.Add(Undefined);
		CallDetails.Add(Undefined);
		CallDetails.Add(False);
		
		OperationArray.Add(CallDetails);
	EndDo;
	
	If Not RequestUserPermission(OperationArray) Then 
		Return;
	EndIf;
#EndIf

	For Iteration = 0 to SelectedFiles.Count() - 1 Do 
		
		SelectedFile = New File(SelectedFiles.Get(Iteration));
		// Deleting the TechnicalParameters.xml file if it exists
		If Upper(SelectedFile.Name) = Upper(TechParameterFileName) Then 
			MessageText = NStr("en = 'The file named ''%1'' cannot be attached to the message.
									|Rename the file.'");
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessageText, SelectedFile.Name);
			ClearMessages();
			ShowUserMessage(MessageText);
			Continue;
		EndIf;
		
		// Filling the value table
		TableRow          = FilesToSelect.Add();
		TableRow.FileName = SelectedFile.Name;
		TableRow.Size     = SelectedFile.Size() / 1024;
		
		FilesToBePlaced = New Array;
		Details = New TransferableFileDescription(SelectedFile.FullName);
		FilesToBePlaced.Add(Details);
		PlacedFiles = New Array;
		
		Try
			Result = PutFiles(FilesToBePlaced, PlacedFiles, , False, UUID);
		Except
			Result = False;
		EndTry;
		
		If Not Result Then
			
			ErrorMessage = StringFunctionsClientServer.SubstituteParametersInString(NStr("en = 'Cannot load the file: %1'"), SelectedFile.Name);
			ClearMessages();
			ShowUserMessage(ErrorMessage);
			FilesToSelect.Delete(FilesToSelect.IndexOf(TableRow));
			Continue;
			
		EndIf;
		
		TableRow.StorageAddress = PlacedFiles.Get(0).Location;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure AddFilesToListToSend()
	
	For Each CurrentFile In FilesToSelect Do 
		
		If CurrentFile.IDInValueList <> 0 Then 
			Continue;
		EndIf;
		
		FileName = CurrentFile.FileName;
		StorageAddress = CurrentFile.StorageAddress;
		NewAttachmentFile = Attachments.Add(GetFromTempStorage(StorageAddress), FileName);
		CurrentFile.IDInValueList = NewAttachmentFile.GetID();
		
	EndDo;
	
EndProcedure

&AtServer
Function SendMessageServer()
	
	Text = "";
	HTMLAttachments = Undefined;
	Content.GetHTML(Text, HTMLAttachments);
	
	MessageParameters = New Structure();
	MessageParameters.Insert("FromWhom",    FromWhom);
	MessageParameters.Insert("Subject",     GetTopicName());
	MessageParameters.Insert("Text",        Text);
	MessageParameters.Insert("Attachments", Attachments);
	MessageParameters.Insert("TextType", "HTML");
	
	Result = True;
	InformationCenterServer.UserMessageToSupportOnSend(MessageParameters, Result);
	
	Return Result;
	
EndFunction

&AtServer
Function GetTopicName()
	
	If Not IsBlankString(Subject) Then 
		Return Subject;
	EndIf;
	
	MessageText = Content.GetText();
	MessageText = StrReplace(MessageText, "Hello!", "");
	
	Return TrimAll(MessageText);
	
EndFunction

&AtClient
Procedure SetPointerInTextPattern()
	
	AttachIdleHandler("PlacePointerInTextPatternHandler", 0.5, True);
	
EndProcedure

&AtServer
Function GetPositionNumberForPointer(TextParameter, PointerPositionString)
	
	Return Find(TextParameter, PointerPositionString);
	
EndFunction

&AtClient
Procedure PlacePointerInTextPatternHandler()
	
	CurrentItem = Items.Content;
	Bookmark = Content.GetPositionBookmark(PointerLine);
	Items.Content.SetTextSelectionBounds(Bookmark, Bookmark);
	
EndProcedure

&AtServer
Function CreateFormItemsForAttachedFile()
	
	For Iteration = 0 to FilesToSelect.Count() - 1 Do
		
		If Not IsBlankString(FilesToSelect.Get(Iteration).DeletionButtonName) Then 
			Continue;
		EndIf;
		
		FileGroup                = Items.Add("FileGroup" + String(Iteration), Type("FormGroup"), Items.AttachedFileGroup);
		FileGroup.Kind           = FormGroupType.UsualGroup;
		FileGroup.ShowTitle      = False;
		FileGroup.Grouping       = ChildFormItemsGroup.Horizontal;
		FileGroup.Representation = UsualGroupRepresentation.None;
		
		FileNameText       = Items.Add("FileNameText" + String(Iteration), Type("FormDecoration"), FileGroup);
		FileNameText.Kind  = FormDecorationType.Label;
		FileNameText.Title = FilesToSelect.Get(Iteration).FileName + " (" + FilesToSelect.Get(Iteration).Size + " KB)";
		
		FileDeletionButton             = Items.Add("FileDeletionButton" + String(Iteration), Type("FormDecoration"), FileGroup);
		FileDeletionButton.Kind        = FormDecorationType.Picture;
		FileDeletionButton.Picture     = PictureLib.DeleteDirectly;
		FileDeletionButton.ToolTip     = NStr("en = 'Delete file'");
		FileDeletionButton.Width       = 2;
		FileDeletionButton.Height      = 1;
		FileDeletionButton.PictureSize = PictureSize.Stretch;
		FileDeletionButton.Hyperlink   = True;
		FileDeletionButton.SetAction("Click", "DeleteFile");
		
		FilesToSelect.Get(Iteration).DeletionButtonName = FileDeletionButton.Name;
		
	EndDo;
	
	// Attaching the idle handler of file adding.
	AddFilesToListToSend();
	
EndFunction

&AtServer
Function ShowUserMessage(Text)
	
	Message = New UserMessage;
	Message.Text = Text;
	Message.Message();
	
EndFunction