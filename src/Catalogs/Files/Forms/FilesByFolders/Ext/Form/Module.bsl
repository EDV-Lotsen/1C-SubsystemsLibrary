
&AtClient
Var FirstActivization;


&AtClient
Procedure ImportFilesExecute()
	#If Not WebClient Then
		
		// select files in advance (before open of import dialog)
		Mode = FileDialogMode.Open;
		
		FileOpenDialog = New FileDialog(Mode);
		FileOpenDialog.FullFileName = "";
		Filter = NStr("en = 'All files(*.*)|*.*'");
		FileOpenDialog.Filter = Filter;
		FileOpenDialog.Multiselect = True;
		FileOpenDialog.Title = NStr("en = 'Select files'");
		If FileOpenDialog.Choose() Then
			FilenamesArray = New Array;
			
			FilesArray = FileOpenDialog.SelectedFiles;
			For Each FileName In FilesArray Do
				FilenamesArray.Add(FileName);
			EndDo;
			
			ImportParameters = New Structure("FolderForAdd, FilenamesArray", Items.Folders.CurrentRow, FilenamesArray);
			OpenForm("Catalog.Files.Form.FileImportForm", ImportParameters);
		EndIf;
	#Else	
		DoMessageBox(NStr("en = 'Web client cannot perform files import. Use command ""Create"" in the file list.'"));
	#EndIf
EndProcedure

&AtClient
Procedure FolderImport(Command)
	#If Not WebClient Then
	
		// select directory on drive in advance (before open import dialog)
		Directory = "";
		Mode = FileDialogMode.ChooseDirectory;
		
		FileOpenDialog 					= New FileDialog(Mode);
		FileOpenDialog.FullFileName 	= "";
		Filter 							= NStr("en = 'All files(*.*)|*.*'");
		FileOpenDialog.Filter 			= Filter;
		FileOpenDialog.Multiselect 		= False;
		FileOpenDialog.Title 			= NStr("en = 'Select the directory'");
		If FileOpenDialog.Choose() Then
			DirectoryOnDrive = FileOpenDialog.Directory;
			ImportParameters = New Structure("FolderForAdd, DirectoryOnDrive", Items.Folders.CurrentRow, DirectoryOnDrive);
			OpenForm("Catalog.Files.Form.FolderImportForm", ImportParameters);
		EndIf;
	#Else	
		DoMessageBox(NStr("en = 'Web client cannot perform folders import. Use command ""Create"" in the file list.'"));
	#EndIf
EndProcedure

// Handle event "Selection" of field "List"
//
&AtClient
Procedure ListSelection(Item, RowSelected, Field, StandardProcessing)
	
	If TypeOf(RowSelected) = Type("DynamicalListGroupRow") Then
		Return;
	EndIf;	
	
	
	StandardProcessing = False;
	
	HowToOpen = FileOperationsSecondUseClient.GetFileOperationsPersonalSettings().OnDoubleClickAction;
	
	If HowToOpen = "ToOpenCard" Then
		OpenValue(RowSelected);
		Return;
	EndIf;
	
	FileOperationsClient.InitializeWorkingDirectoryPath();
	DirectoryName = FileOperationsSecondUseClient.GetFileOperationsPersonalSettings().LocalFilesCachePath;
	If DirectoryName = Undefined OR IsBlankString(DirectoryName) Then
		Return;
	EndIf;
	
	FileData = FileOperations.GetFileDataForOpening(RowSelected, Undefined, Uuid);
	
	// If it is already locked for edit, then do not ask - open right away
	If FileData.LockedBy.IsEmpty() Then
		AskEditModeOnFileOpening = FileOperationsSecondUseClient.GetFileOperationsPersonalSettings().AskEditModeOnFileOpening;
		If AskEditModeOnFileOpening = True Then
			
			Result = OpenFormModal("Catalog.Files.Form.OpenModeChoiceForm");
			If TypeOf(Result) <> Type("Structure") Then
				Return;
			EndIf;
			
			DoNotAskAnyMore = Result.DoNotAskAnyMore;
			If DoNotAskAnyMore = True Then
				CommonUse.CommonSettingsStorageSave("FilesOpenSettings", "AskEditModeOnFileOpening", False);
				RefreshReusableValues();
			EndIf;
			
			HowToOpen = Result.HowToOpen;
			If HowToOpen = 1 Then
				FileOperationsClient.EditFile(FileData, Uuid);
				NotifyChanged(FileData.Ref);
				SetAccessibilityOfFileCommands();
				Return;
			EndIf;
			
		EndIf;
	EndIf;
	
	FileOperationsClient.OpenFile(FileData, Uuid); 
	
EndProcedure

// Handle event "BeforeAddRow" of field "List"
//
&AtClient
Procedure ListBeforeAddRow(Item, Cancellation, Clone, Parent, Folder)
	
	If Items.Folders.CurrentRow = Undefined Then
		Cancellation = True;
		Return;
	EndIf; 
	
	If Items.Folders.CurrentRow.IsEmpty() Then
		Cancellation = True;
		Return;
	EndIf; 
	
	FileOwner = Items.Folders.CurrentRow;
	FileBasis = Items.List.CurrentRow;
	
	Cancellation = True;
	
	If Not Clone Then
		
		Try
			FileOperationsClient.CreateNewFile(FileOwner, ThisForm);
		Except
			InfoInfo = ErrorInfo();
			DoMessageBox(StringFunctionsClientServer.SubstitureParametersInString(
			                 NStr("en = 'Error while creating new file:""%1""'"),
			                 InfoInfo.Description));
		EndTry;
		
	Else
		
		FileOperationsClient.CopyFile(FileOwner, FileBasis);
		
	EndIf;
	
EndProcedure

// Handle event "OnActivateRow" of field "Folders"
&AtClient
Procedure FoldersOnActivateRow(Item)
	
	If Items.Folders.CurrentRow = Undefined Or Items.Folders.CurrentRow.IsEmpty() Then
		Items.CreateFile.Enabled = False;
		Items.ContextMenuListCreate.Enabled = False;
	Else
		Items.CreateFile.Enabled = True;
		Items.ContextMenuListCreate.Enabled = True;
	EndIf;
	
	If FirstActivization = True OR FirstActivization = Undefined Then
		FirstActivization = False;
		Return;
	EndIf;		
	
	If Items.Folders.CurrentRow <> Undefined Then
		AttachIdleHandler("IdleProcessing", 0.2, True);
	EndIf; 
	
EndProcedure

// Procedure updates right list
&AtClient
Procedure IdleProcessing()
	If Items.Folders.CurrentRow <> List.Parameters.Items.Find("Owner").Value Then
		List.Parameters.SetParameterValue(
			"Owner", Items.Folders.CurrentRow);
	EndIf;
EndProcedure

// Procedure calls the code that exports folder to the file system
&AtClient
Procedure ExportFoldersExecute()
	
	FormParameters = New Structure;
	FormParameters.Insert("ExportFolder", Items.Folders.CurrentRow);
	OpenForm("Catalog.Files.Form.FolderExportForm", FormParameters);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	If EventName = "FilesImportCompleted" Then
		Items.List.Refresh();
		
		If Parameter <> Undefined Then
			Items.List.CurrentRow = Parameter;
		EndIf;
	EndIf;
	
	If EventName = "CatalogImportDenied" Then
		Items.Folders.Refresh();
		Items.List.Refresh();
		
		If Parameter <> Undefined Then
			Items.Folders.CurrentRow = Parameter;
		EndIf;
	EndIf;

	If EventName = "FileCreated" Then
		
		If Parameter <> Undefined Then
			FileOwner = Undefined;
			If Parameter.Property("Owner", FileOwner) Then
				If FileOwner = Items.Folders.CurrentRow Then
					Items.List.Refresh();
					
					CreatedFile = Undefined;
					If Parameter.Property("File", CreatedFile) Then
						Items.List.CurrentRow = CreatedFile;
					EndIf;
				EndIf;
			EndIf;
		EndIf;
		
	EndIf;
	
	If EventName = "FileDataModified" Then
		SetAccessibilityOfFileCommands();
	EndIf;	
EndProcedure

&AtClient
Procedure FindExecute()
	If SearchString = "" Then
		CommonUseClientServer.MessageToUser(NStr("en = 'Search text not specified.'"), , "SearchString");
		Return;
	EndIf;
	
	FindFilesOrFolders();
EndProcedure

&AtClient
Procedure SearchOnChange(Item)
	FindFilesOrFolders();
EndProcedure

&AtClient
Procedure FindFilesOrFolders()
	
	If SearchString = "" Then
		Return;
	EndIf;
	
	Result = FindFilesOrFoldersServer();
	If Result = "NothingFound" Then
		DoMessageBox(StringFunctionsClientServer.SubstitureParametersInString(
		                 NStr("en = 'File or folder, name or code of which contains ""%1"" cannot be found. '"),
		                 SearchString ));
	Else 
		If Result = "FileFound" Then
			CurrentItem = Items.List;
		Else 
			If Result = "FolderFound" Then
				CurrentItem = Items.Folders;
			EndIf;
		EndIf;
	EndIf;
	
	Items.Folders.Refresh();
	Items.List.Refresh();
EndProcedure

&AtServer
Function StrReplaceBySpecialChar(String, Char, Escape)
	RowNew = StrReplace(String, Char, Escape + Char);
	Return RowNew;
EndFunction	

&AtServer
Function FindFilesOrFoldersServer()
	
	Var FileThatFound;
	Var FolderThatFound;
	
	Found = False;
	
	Query = New Query;
	
	SearchStringNew = SearchString;
	
	Escape = "|";
	SearchStringNew = StrReplaceBySpecialChar(SearchStringNew, "[", Escape);
	SearchStringNew = StrReplaceBySpecialChar(SearchStringNew, "]", Escape);
	
	Query.Parameters.Insert("String", "%" + SearchStringNew + "%");
	
	Query.Text = "SELECT ALLOWED TOP 1
				   |	Files.Ref
				   |FROM
				   |	Catalog.Files AS Files
				   |WHERE
				   |	Files.FileName LIKE &String ESCAPE ""|""";
	
	Selection = Query.Execute().Choose();
	If Selection.Next() Then
		FileThatFound = Selection.Ref;
		Found = True;
	EndIf;
	
	If Not Found Then
		Query.Text = "SELECT ALLOWED TOP 1
					   |	Files.Ref
					   |FROM
					   |	Catalog.Files AS Files
					   |WHERE
					   |	Files.Code LIKE &String";
						
		Selection = Query.Execute().Choose();
		If Selection.Next() Then
			FileThatFound = Selection.Ref;
			Found = True;
		EndIf;	
	EndIf;	
	
	If Not Found Then
		Query.Text = "SELECT ALLOWED TOP 1
					   |	FileFolders.Ref
					   |FROM
					   |	Catalog.FileFolders AS FileFolders
					   |WHERE
					   |	FileFolders.Description LIKE &String";
						
		Selection = Query.Execute().Choose();
		If Selection.Next() Then
			FolderThatFound = Selection.Ref;
			Found = True;
		EndIf;	
	EndIf;	
	
	If Not Found Then
		Query.Text = "SELECT ALLOWED TOP 1
					   |	FileFolders.Ref
					   |FROM
					   |	Catalog.FileFolders AS FileFolders
					   |WHERE
					   |	FileFolders.Code LIKE &String";
						
		Selection = Query.Execute().Choose();
		If Selection.Next() Then
			FolderThatFound = Selection.Ref;
			Found = True;
		EndIf;	
	EndIf;	
	
	If FileThatFound <> Undefined Then 
		Items.Folders.CurrentRow = FileThatFound.FileOwner;
		List.Parameters.SetParameterValue("Owner", Items.Folders.CurrentRow);
		Items.List.CurrentRow = FileThatFound.Ref;
		Return "FileFound";
	EndIf;
	
	If FolderThatFound <> Undefined Then
		Items.Folders.CurrentRow = FolderThatFound;
		Return "FolderFound";
	EndIf;	
	
	Return "NothingFound";
EndFunction

&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	FolderOnOpen = FormDataSettingsStorage.Load("FilesByFolders", "CurrentFolder");
	
	If FolderOnOpen = Catalogs.FileFolders.EmptyRef() Then
		FolderOnOpen = PredefinedValue("Catalog.FileFolders.FileTemplates");
	Else
		FolderOnOpenObject = Undefined;
		Try
			FolderOnOpenObject = FolderOnOpen.GetObject();
		Except
		EndTry;
		
		If FolderOnOpenObject = Undefined Then
			FolderOnOpen = PredefinedValue("Catalog.FileFolders.FileTemplates");
		EndIf;
	EndIf;
	
	Items.Folders.CurrentRow = FolderOnOpen;

	List.Parameters.SetParameterValue(
		"Owner", FolderOnOpen);
	List.Parameters.SetParameterValue(
		"CurrentUser", CommonUse.CurrentUser());

	FileOperations.FillFileListConditionalAppearance(List);
	
	ShowColumnSize = FileOperations.GetShowColumnSize();
	If ShowColumnSize = False Then
		Items.CurrentVersionSize.Visible = False;
	EndIf;
	
	UseHierarchy = True;
	SetHierarchy(UseHierarchy);
	
EndProcedure

&AtClient
Procedure OnClose()
	If FolderOnOpen <> Items.Folders.CurrentRow Then
		OnCloseAtServer();
	EndIf;
EndProcedure

&AtServer
Procedure OnCloseAtServer()
	FormDataSettingsStorage.Save(
		"FilesByFolders", 
		"CurrentFolder", 
		Items.Folders.CurrentRow);
EndProcedure

&AtClient
Procedure CreateFileExecute()
	
	Try
		FileOperationsClient.CreateNewFile(Items.Folders.CurrentRow, ThisForm);
	Except
		InfoInfo = ErrorInfo();
	DoMessageBox(StringFunctionsClientServer.SubstitureParametersInString(
		                 NStr("en = 'Error while creating new file:""%1""'"),
		                 InfoInfo.Description));
	EndTry;
					 
EndProcedure

&AtClient
Procedure CreateFolderExecute()
	
	FolderCreateParameters = New Structure("Parent", Items.Folders.CurrentRow);
	OpenForm("Catalog.FileFolders.ObjectForm", FolderCreateParameters, Items.Folders);
	
EndProcedure

&AtClient
Procedure ListDragCheck(Item, DragParameters, StandardProcessing, String, Field)
	StandardProcessing = False;
EndProcedure

&AtClient
Procedure ListDrag(Item, DragParameters, StandardProcessing, String, Field)
	StandardProcessing = False;
	
	If Items.Folders.CurrentRow = Undefined Then
		Cancellation = True;
		Return;
	EndIf; 
	
	If Items.Folders.CurrentRow.IsEmpty() Then
		Return;
	EndIf;
	
	FilenamesArray = New Array;
	ThisIsDragAndDropOfFilesFromOutside = False;
	
	If TypeOf(DragParameters.Value) = Type("File") And DragParameters.Value.IsFile() = True Then
		FileOperationsClient.CreateDocumentBasedOnFile(DragParameters.Value.FullName, Items.Folders.CurrentRow, ThisForm);
	ElsIf TypeOf(DragParameters.Value) = Type("File") Then	
		ThisIsDragAndDropOfFilesFromOutside = True;
		FilenamesArray.Add(DragParameters.Value.FullName);
	ElsIf TypeOf(DragParameters.Value) = Type("Array") Then
		
		If DragParameters.Value.Count() >= 1 And TypeOf(DragParameters.Value[0]) = Type("File") Then
			ThisIsDragAndDropOfFilesFromOutside = True;
			For Each FileAccepted In DragParameters.Value Do
				FilenamesArray.Add(FileAccepted.FullName);
			EndDo;
		EndIf;
			
	EndIf;
	
	If ThisIsDragAndDropOfFilesFromOutside = True Then
		ImportParameters = New Structure("FolderForAdd, FilenamesArray", Items.Folders.CurrentRow, FilenamesArray);
		OpenForm("Catalog.Files.Form.DragForm", ImportParameters);
	EndIf;
EndProcedure

&AtClient
Procedure FoldersDragCheck(Item, DragParameters, StandardProcessing, String, Field)
	StandardProcessing = False;
EndProcedure

&AtClient
Procedure FoldersDrag(Item, DragParameters, StandardProcessing, String, Field)
	StandardProcessing = False;
	
	FilenamesArray = New Array;
	ThisIsDragAndDropOfFilesFromOutside = False;
	
	If TypeOf(DragParameters.Value) = Type("File") And DragParameters.Value.IsFile() = True Then
		FileOperationsClient.CreateDocumentBasedOnFile(DragParameters.Value.FullName, Items.Folders.CurrentRow, ThisForm);
	ElsIf TypeOf(DragParameters.Value) = Type("File") Then	
		ThisIsDragAndDropOfFilesFromOutside = True;
		FilenamesArray.Add(DragParameters.Value.FullName);
	ElsIf TypeOf(DragParameters.Value) = Type("Array") Then
		
		If DragParameters.Value.Count() >= 1 And TypeOf(DragParameters.Value[0]) = Type("File") Then
			ThisIsDragAndDropOfFilesFromOutside = True;
			For Each FileAccepted In DragParameters.Value Do
				FilenamesArray.Add(FileAccepted.FullName);
			EndDo;
		EndIf;
		
		If DragParameters.Value.Count() >= 1 And TypeOf(DragParameters.Value[0]) = Type("CatalogRef.Files") Then
			If FileOperations.SetFileOwner(DragParameters.Value, String) = True Then
				Items.Folders.Refresh();
				Items.List.Refresh();
				
				If DragParameters.Value.Count() = 1 Then
					FullDetails = StringFunctionsClientServer.SubstitureParametersInString(
						NStr("en = 'The file ""%1"" was moved to the folder ""%2""'"), DragParameters.Value[0], String);
					
					ShowUserNotification(
						NStr("en = 'File moved.'"),
						,
						FullDetails,
						PictureLib.Information32);
				Else
					FullDetails = StringFunctionsClientServer.SubstitureParametersInString(
						NStr("en = 'Files (%1) moved to folder %2'"), DragParameters.Value.Count(), String);
					
					ShowUserNotification(
						NStr("en = 'Files are transferred.'"),
						,
						FullDetails,
						PictureLib.Information32);
				EndIf;
			EndIf;
			Return;
		EndIf;
		
		If DragParameters.Value.Count() >= 1 And TypeOf(DragParameters.Value[0]) = Type("CatalogRef.FileFolders") Then
			LoopingFound = False;
			If FileOperations.ChangeParentOfFolders(DragParameters.Value, String, LoopingFound) = True Then
				Items.Folders.Refresh();
				Items.List.Refresh();
				
				If DragParameters.Value.Count() = 1 Then
					Items.Folders.CurrentRow = DragParameters.Value[0];
					
					FullDetails = StringFunctionsClientServer.SubstitureParametersInString(
						NStr("en = 'Folder ""%1"" moved to ""%2""'"), DragParameters.Value[0], String);
					
					ShowUserNotification(
						NStr("en = 'Folder moved.'"),
						,
						FullDetails,
						PictureLib.Information32);
				Else
					FullDetails = StringFunctionsClientServer.SubstitureParametersInString(
						NStr("en = 'Folders (%1 item)  moved to folder ""%2""'"), DragParameters.Value.Count(), String);
					
					ShowUserNotification(
						NStr("en = 'Folders moved.'"),
						,
						FullDetails,
						PictureLib.Information32);
				EndIf;
				
			Else
				If LoopingFound = True Then
					DoMessageBox(NStr("en = 'Looping levels!'"));
				EndIf;
			EndIf;
			Return;
		EndIf;
		
	EndIf;
	
	If ThisIsDragAndDropOfFilesFromOutside = True Then
		ImportParameters = New Structure("FolderForAdd, FilenamesArray", String, FilenamesArray);
		OpenForm("Catalog.Files.Form.DragForm", ImportParameters);
	EndIf;
EndProcedure

&AtClient
Procedure SetAccessibilityOfFileCommands()
	
	If Items.List.CurrentData <> Undefined Then
		
		If TypeOf(Items.List.CurrentRow) <> Type("DynamicalListGroupRow") Then
			
			SetAccessibilityOfCommands(Items.List.CurrentData.LockedByCurrentUser,
				Items.List.CurrentData.LockedBy, Items.List.CurrentData.Signed,
				Items.List.CurrentData.Encrypted);
					
		EndIf;	
			
	EndIf;	
	
EndProcedure

&AtClient
Procedure SetAccessibilityOfCommands(LockedByCurrentUser, LockedBy, Signed, Encrypted)
	
	Items.EndEdit.Enabled = LockedByCurrentUser;
	Items.ListContextMenu.ChildItems.ContextMenuListEndEdit.Enabled = LockedByCurrentUser;
	
	Items.SaveChanges.Enabled = LockedByCurrentUser;
	Items.ListContextMenu.ChildItems.ContextMenuListSaveChanges.Enabled = LockedByCurrentUser;
	
	Items.Release.Enabled = Not LockedBy.IsEmpty();
	Items.ListContextMenu.ChildItems.ContextMenuListRelease.Enabled = Not LockedBy.IsEmpty();
	
	Items.Take.Enabled = LockedBy.IsEmpty() And NOT Signed;
	Items.ListContextMenu.ChildItems.ContextMenuListTake.Enabled = LockedBy.IsEmpty() And NOT Signed;
	
	Items.Edit.Enabled = NOT Signed;
	Items.ListContextMenu.ChildItems.ContextMenuListEdit.Enabled = NOT Signed;
	
EndProcedure

&AtClient
Procedure ListOnActivateRow(Item)
	SetAccessibilityOfFileCommands();
EndProcedure

&AtClient
Procedure UseHierarchy(Command)
	
	UseHierarchy = Not UseHierarchy;
	If UseHierarchy And (Items.List.CurrentData <> Undefined) Then 
		
		If Items.List.CurrentData.Property("FileOwner") Then 
			Items.Folders.CurrentRow = Items.List.CurrentData.FileOwner;
		Else
			Items.Folders.CurrentRow = Undefined;
		EndIf;	
		
		List.Parameters.SetParameterValue("Owner", Items.Folders.CurrentRow);
	EndIf;	
	SetHierarchy(UseHierarchy);
	
EndProcedure

&AtServer
Procedure SetHierarchy(CheckMark)
	
	If CheckMark = Undefined Then 
		Return;
	EndIf;
	
	Items.UseHierarchy.Check = CheckMark;
	If CheckMark = True Then 
		Items.Folders.Visible = True;
	Else
		Items.Folders.Visible = False;
	EndIf;
	List.Parameters.SetParameterValue("UseHierarchy", CheckMark);
	
EndProcedure	

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	SetHierarchy(Settings["UseHierarchy"]);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES - HANDLERS OF THE COMMANDS OF WORK WITH FILES

&AtClient
Procedure OpenFileExecute()
	
	If Not FileCommandsAvailable() Then 
		Return;
	EndIf;
	
	FileData = FileOperations.GetFileDataForOpening(Items.List.CurrentRow, Undefined, Uuid);
	FileOperationsCommands.Open(FileData);
	
EndProcedure

&AtClient
Procedure Edit(Command)
	
	If Not FileCommandsAvailable() Then 
		Return;
	EndIf;
	
	FileOperationsCommands.Edit(Items.List.CurrentRow);
	SetAccessibilityOfFileCommands();
	
EndProcedure


// File commands are accessible - there is at least one line in the list and not group is selected
&AtClient
Function FileCommandsAvailable()
	
	If Items.List.CurrentRow = Undefined Then 
		Return False;
	EndIf;
	
	If TypeOf(Items.List.CurrentRow) = Type("DynamicalListGroupRow") Then
		Return False;
	EndIf;	
	
	Return True;
	
EndFunction

&AtClient
Procedure EndEdit(Command)
	
	If Not FileCommandsAvailable() Then 
		Return;
	EndIf;
	
	FileOperationsCommands.EndEdit(
		Items.List.CurrentRow,
		Uuid,
		Items.List.CurrentData.StoreVersions,
		Items.List.CurrentData.LockedByCurrentUser,
		Items.List.CurrentData.LockedBy,
		Items.List.CurrentData.Author);
	
	SetAccessibilityOfFileCommands();
		
EndProcedure

&AtClient
Procedure Take(Command)
	
	If Not FileCommandsAvailable() Then 
		Return;
	EndIf;

	FileOperationsCommands.Lock(Items.List.CurrentRow);
	
	SetAccessibilityOfFileCommands();
	
EndProcedure

&AtClient
Procedure Release(Command)
	
	If Not FileCommandsAvailable() Then 
		Return;
	EndIf;
	
	FileOperationsCommands.UnlockFile(
		Items.List.CurrentRow,
		Items.List.CurrentData.StoreVersions,
		Items.List.CurrentData.LockedByCurrentUser,
		Items.List.CurrentData.LockedBy);
	
	SetAccessibilityOfFileCommands();
		
EndProcedure

&AtClient
Procedure SaveChanges(Command)
	
	If Not FileCommandsAvailable() Then 
		Return;
	EndIf;
	
	FileOperationsCommands.SaveAs(
		Items.List.CurrentRow);
	
EndProcedure

&AtClient
Procedure OpenFileDirectory(Command)
	
	If Not FileCommandsAvailable() Then 
		Return;
	EndIf;
	
	FileData = FileOperations.GetFileDataForOpening(Items.List.CurrentRow, Undefined, Uuid);
	FileOperationsCommands.OpenFileDirectory(FileData);
	
EndProcedure

&AtClient
Procedure SaveAs(Command)
	
	If Not FileCommandsAvailable() Then 
		Return;
	EndIf;
	
	FileData = FileOperations.GetFileDataForSaving(Items.List.CurrentRow, Undefined, Uuid);
	FileOperationsCommands.SaveAs(FileData);
	
EndProcedure

&AtClient
Procedure UpdateFromFileOnDisk(Command)
	If Not FileCommandsAvailable() Then 
		Return;
	EndIf;
	
	FileData = FileOperations.GetFileDataAndWorkingDirectory(Items.List.CurrentRow);
	FileOperationsCommands.UpdateFromFileOnDisk(FileData, Uuid);
EndProcedure

&AtClient
Procedure ListBeforeRowChange(Item, Cancellation)
	Cancellation = True;
	
	FormOpenParameters = New Structure("Key", Item.CurrentRow);
	OpenForm("Catalog.Files.ObjectForm", FormOpenParameters);
EndProcedure

&AtClient
Procedure MoveToFolder(Command)
	
	If Not FileCommandsAvailable() Then 
		Return;
	EndIf;
	
	FormOpenParameters = New Structure("Title, CurrentFolder", NStr("en = 'Select the folder'"), Items.Folders.CurrentRow);
	Result = OpenFormModal("Catalog.FileFolders.ChoiceForm", FormOpenParameters);
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	SelectedRows = Items.List.SelectedRows;
	FileOperationsClient.MoveFilesToFolder(SelectedRows, Result);
	For Each SelectedRow In SelectedRows Do
		Notify("FileDataModified", SelectedRow);
	EndDo;
	Items.List.Refresh();
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// END OF PROCEDURES - HANDLERS OF THE COMMANDS OF WORK WITH FILES
