

// Handle form event OnOpen
&AtClient
Procedure OnOpen(Cancellation)
	
	DirectoriesChoice = True;
	StoreVersions 	  = True;
	
EndProcedure

// Handle click on button Import
//
&AtClient
Procedure ImportExecute()
	
	If IsBlankString(Directory) Then
		
		CommonUseClientServer.MessageToUser(NStr("en = 'Directory for import has not been selected!'"), , "Directory");
		Return;
		
	EndIf;
	
	If FolderForAdd.IsEmpty() Then
		CommonUseClientServer.MessageToUser(NStr("en = 'Select folder!'"), , "FolderForAdd");
		Return;
	EndIf;
	
	SelectedFiles = New ValueList;
	SelectedFiles.Add(Directory);
	
	PseudoFileSystem = New Map; // map directory path - files and dirs inside
	AddedFiles = New Array;
	
	FolderForAddCurrent = FileFunctionsClient.ImportFilesExecute(
		FolderForAdd, 
		SelectedFiles, 
		Details, 
		StoreVersions, 
		DeleteFilesAfterAdd, 
		True,
		Uuid,
		PseudoFileSystem,
		AddedFiles);
		
	Close();
	
	Notify("CatalogImportDenied", FolderForAddCurrent);
	
EndProcedure

// Handle event StartChoice of field Folder
//
&AtClient
Procedure SelectedFolderStartChoice(Item, ChoiceData, StandardProcessing)
	#If NOT WebClient Then
		Mode = FileDialogMode.ChooseDirectory;
		
		FileOpenDialog = New FileDialog(Mode);
		
		FileOpenDialog.Directory 	= Directory;
		FileOpenDialog.FullFileName = "";
		Filter 						= NStr("en = 'All files(*.*)|*.*'");
		FileOpenDialog.Filter 		= Filter;
		FileOpenDialog.Multiselect 	= False;
		FileOpenDialog.Title 		= NStr("en = 'Select the directory'");
		If FileOpenDialog.Choose() Then
			
			If DirectoriesChoice = True Then 
				
				Directory = FileOpenDialog.Directory;
				
			EndIf;
			
		EndIf;
			
		StandardProcessing = False;
	#EndIf
EndProcedure


&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	If NOT Parameters.Property("DirectoryOnDrive") Then 	
		CommonUseClientServer.MessageToUser(NStr("en = 'Specified data processor is called from the other configuration procedures. Manual request prohibited.'")); 
		Cancellation = True;
		Return;
	EndIf;
	
	If Parameters.DirectoryOnDrive <> Undefined Then
		Directory = Parameters.DirectoryOnDrive;
	EndIf;
	
	If Parameters.FolderForAdd <> Undefined Then
		FolderForAdd = Parameters.FolderForAdd;
	EndIf;
EndProcedure

