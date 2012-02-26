
&AtClient
Procedure FillFileList(FilePath, Val TreeItems, TopLevelItem)
	FileMigrated = New File(FilePath);
	
	NewItem 		 = TreeItems.Add();
	NewItem.FullPath = FileMigrated.FullName;
	NewItem.FileName = FileMigrated.Name;
	NewItem.Check 	 = True;
	
	If FileMigrated.Extension = "" Then
		NewItem.PictureIndex = 2; // folder
	Else
		NewItem.PictureIndex = FileOperationsClientServer.GetFilePictogramIndex(FileMigrated.Extension);
	EndIf;
			
	If FileMigrated.IsDirectory() Then
		
		Path = FileMigrated.FullName + "\";
		
		If TopLevelItem = True Then
			Status(StringFunctionsClientServer.SubstitureParametersInString(
				   NStr("en = 'Collecting ""%1"" folder information.""Please wait.'"), Path ));
		EndIf;	   
		
		FilesFound = FindFiles(Path, "*.*");
		
		FileSortedOnes = New Array;
		
		// folders first
		For Each NestedFile In FilesFound Do
			If NestedFile.IsDirectory() Then
				FileSortedOnes.Add(NestedFile.FullName);
			EndIf;
		EndDo;
		
		// files after
		For Each NestedFile In FilesFound Do
			If NOT NestedFile.IsDirectory() Then
				FileSortedOnes.Add(NestedFile.FullName);
			EndIf;
		EndDo;
		
		For Each NestedFile In FileSortedOnes Do
			FillFileList(NestedFile, NewItem.GetItems(), False);
		EndDo;
	
	EndIf;
EndProcedure

&AtClient
Procedure OnOpen(Cancellation)
	#If WebClient Then
		DoMessageBox(NStr("en = 'Web client cannot perform files import. Use command ""Create"" in the file list.'"));
		Cancellation = True;
		Return;
	#EndIf
	
	StoreVersions = True;
	
	For Each FilePath In ListOfFileNames Do
		FillFileList(FilePath, FileTree.GetItems(), True);
	EndDo;
	
	Status();
	
EndProcedure

&AtClient
Procedure FillFileSystem(PseudoFileSystem, TreeItem)
	If TreeItem.Check = True Then
		ChildElements = TreeItem.GetItems();
		If ChildElements.Count() <> 0 Then
			
			FilesAndSubfolders = New Array;
			For Each NestedFile In ChildElements Do
				FillFileSystem(PseudoFileSystem, NestedFile);
				
				If NestedFile.Check = True Then
					FilesAndSubfolders.Add(NestedFile.FullPath);
				EndIf;
			EndDo;
			
			PseudoFileSystem.Insert(TreeItem.FullPath, FilesAndSubfolders);
		EndIf;
	EndIf;
EndProcedure

&AtClient
Procedure AddRun()
	
	ClearMessages();
	
	FieldsNotFilled = False;
	
	PseudoFileSystem = New Map; // map directory path - files and dirs inside
	
	SelectedFiles = New ValueList;
	For Each nestedFile In FileTree.GetItems() Do
		If nestedFile.Check = True Then
			SelectedFiles.Add(nestedFile.FullPath);
		EndIf;
	EndDo;
	
	For Each nestedFile In FileTree.GetItems() Do
		FillFileSystem(PseudoFileSystem, nestedFile);
	EndDo;
	
	If SelectedFiles.Count() = 0 Then
		CommonUseClientServer.MessageToUser(NStr("en = 'No files to add!'"), , "SelectedFiles");
		FieldsNotFilled = True;
	EndIf;
	
	If FolderForAdd.IsEmpty() Then
		CommonUseClientServer.MessageToUser(NStr("en = 'Select folder!'"), , "FolderForAdd");
		FieldsNotFilled = True;
	EndIf;
	
	If FieldsNotFilled = True Then
		Return;
	EndIf;
	
	AddedFiles = New Array;
	
	FileFunctionsClient.ImportFilesExecute(
		FolderForAdd, 
		SelectedFiles, 
		Comment, 
		StoreVersions, 
		DeleteFilesAfterAdd, 
		True, // True - recursively
		Uuid,
		PseudoFileSystem,
		AddedFiles); 
		
	Close();
	
	Notify("CatalogImportDenied",,);
	
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	FolderForAdd = Parameters.FolderForAdd;
	
	For Each filePath In Parameters.FilenamesArray Do
		ListOfFileNames.Add(filePath);
	EndDo;
	
EndProcedure

// recursively marks for deletion all child items
&AtClient
Procedure SetMark(TreeItem, Check)
	ChildElements = TreeItem.GetItems();
	
	For Each NestedFile In ChildElements Do
		NestedFile.Check = Check;
		SetMark(NestedFile, Check);
	EndDo;
EndProcedure

&AtClient
Procedure FileTreeCheckOnChange(Item)
	DataItem = FileTree.FindByID(Items.FileTree.CurrentRow);
	SetMark(DataItem, DataItem.Check);
EndProcedure
