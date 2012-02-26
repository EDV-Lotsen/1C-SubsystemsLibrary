

&AtClient
Procedure OnOpen(Cancellation)
	StoreVersions = True;
EndProcedure

&AtClient
Procedure AddRun()
	
	ClearMessages();
	
	FieldsNotFilled = False;
	
	If SelectedFiles.Count() = 0 Then
		CommonUseClientServer.MessageToUser(NStr("en = 'No files to add!'"), , "SelectedFiles");
		FieldsNotFilled = True;
	EndIf;
	
	FilesOwnerForAdd = FilesOwner;
	If TypeOf(FilesOwner) = Type("CatalogRef.FileFolders") Then
		FilesOwnerForAdd = FolderForAdd;
	EndIf;	

	If FilesOwnerForAdd.IsEmpty() Then
		CommonUseClientServer.MessageToUser(NStr("en = 'Select folder!'"), , "FolderForAdd");
		FieldsNotFilled = True;
	EndIf;
	
	If FieldsNotFilled = True Then
		Return;
	EndIf;
	
	PseudoFileSystem = New Map; // map directory path - files and dirs inside
	
	SelectedFilesValueList = New ValueList;
	For Each ListRow In SelectedFiles Do
		SelectedFilesValueList.Add(ListRow.Path);
	EndDo;
	
	AddedFiles = New Array;
	
	FileFunctionsClient.ImportFilesExecute(
		FilesOwnerForAdd, 
		SelectedFilesValueList, 
		Comment, 
		StoreVersions, 
		DeleteFilesAfterAdd, 
		False, // False - not recursively
		Uuid,
		PseudoFileSystem,
		AddedFiles); 
		
	Close();
	
	CommandParameter = Undefined;
	If AddedFiles.Count() > 0 Then
		IndexOf = AddedFiles.Count() - 1;
		CommandParameter = AddedFiles[IndexOf].FileRef;
	EndIf;
	
	Notify("FilesImportCompleted", CommandParameter,);
	
EndProcedure

&AtClient
Procedure ChooseFilesRun()
	#If NOT WebClient Then
		Mode = FileDialogMode.Open;
		
		FileOpenDialog 					= New FileDialog(Mode);
		FileOpenDialog.FullFileName 	= "";
		Filter 							= NStr("en = 'All files(*.*)|*.*'");
		FileOpenDialog.Filter 			= Filter;
		FileOpenDialog.Multiselect		= True;
		FileOpenDialog.Title 			= NStr("en = 'Select files'");
		If FileOpenDialog.Choose() Then
			SelectedFiles.Clear();
			
			FilesArray = FileOpenDialog.SelectedFiles;
			For Each FileName In FilesArray Do
				FileMigrated 			= New File(FileName);
				NewItem 				= SelectedFiles.Add();
				NewItem.Path 			= FileName;
				NewItem.PictureIndex 	= FileOperationsClientServer.GetFilePictogramIndex(FileMigrated.Extension);
			EndDo;
		EndIf;
	#EndIf
EndProcedure

&AtClient
Procedure SelectedFilesBeforeAddRow(Item, Cancellation, Clone)
	Cancellation = True;
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	If NOT Parameters.Property("FolderForAdd") Then 	
		CommonUseClientServer.MessageToUser(NStr("en = 'Specified data processor is called from the other configuration procedures. Manual request prohibited.'")); 
		Cancellation = True;
		Return;
	EndIf;
	
	If Parameters.FolderForAdd <> Undefined Then
		FilesOwner = Parameters.FolderForAdd;
		If TypeOf(FilesOwner) = Type("CatalogRef.FileFolders") Then
			FolderForAdd = FilesOwner;
		Else
			Items.FolderForAdd.Visible = False;
		EndIf;	
	EndIf;
	
	If Parameters.FilenamesArray <> Undefined Then
		For Each FilePath In Parameters.FilenamesArray Do
			FileMigrated 			= New File(FilePath);
			NewItem 				= SelectedFiles.Add();
			NewItem.Path 			= FilePath;
			NewItem.PictureIndex 	= FileOperationsClientServer.GetFilePictogramIndex(FileMigrated.Extension);
		EndDo;
	EndIf;
EndProcedure
