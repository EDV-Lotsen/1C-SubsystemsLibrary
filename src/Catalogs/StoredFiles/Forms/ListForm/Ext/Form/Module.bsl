//////////////////////////////////////////////////////////////////////////////// 
// PROCEDURES AND FUNCTIONS 
// 

// Retrieves the Owner item value from the list form filter.
// 
// Returns: 
// CatalogRef.Products or Undefined if the owner is not found.
//
&AtClient
Function GetOwnerValue()
	
	For Each Item In List.Filter.Items Do
		
		If TypeOf(Item) = Type("DataCompositionFilterItem")
			 And (String(Item.LeftValue) = "Owner"
				Or String(Item.LeftValue) = "Owner")
			 And Item.ComparisonType = DataCompositionComparisonType.Equal Then
			 
			Return Item.RightValue;
			
		EndIf;
		
	EndDo;
	
	Return Undefined;
	
EndFunction

// Retrieves the files list to be sent to the server and creates the corresponding catalog items.
//
&AtServer
Procedure CreateCatalogItems(ImportedFiles, Owner)
	
	For Each LoadedFile In ImportedFiles Do
		
		File = New File(LoadedFile.Value.Name);
		StoredFile = Catalogs.StoredFiles.CreateItem();
		StoredFile.Owner = Owner;
		StoredFile.Description = File.Name;
		StoredFile.FileName = File.Name;
		BinaryData = GetFromTempStorage(LoadedFile.Value.Location);
		StoredFile.FileData = New ValueStorage(BinaryData, New Deflation());
		StoredFile.Write();
		
	EndDo;
	
EndProcedure

// Generates an array of descriptions of passed files by the marked list rows.
//
&AtClient
Function SelectedFilesDescription(GetThroughFilesOperationsExtension)
	
	FilesToTransmit = New Array;
	For Each Row In Items.List.SelectedRows Do
		
		RowData = Items.List.RowData(Row);
		Ref = GetURL(Row, "FileData");
		If GetThroughFilesOperationsExtension Then
			PathToFilee = RowData.Code + "\" + RowData.FileName;
		Else
			PathToFilee = RowData.FileName;
		EndIf;
		Details = New TransferableFileDescription(PathToFilee, Ref);
		FilesToTransmit.Add(Details);
		
	EndDo;
	
	Return FilesToTransmit;
	
EndFunction

//////////////////////////////////////////////////////////////////////////////// 
// Command handlers
//

&AtClient
Procedure ImportFiles()
	
	If AttachFileSystemExtension() Then
	
		Form = GetForm("Catalog.StoredFiles.Form.ImportFilesForm");
		Form.Owner = GetOwnerValue();
		Form.OnCloseNotifyDescription = New NotifyDescription("ImportFilesCompletion", ThisObject);
		Form.Open();		
	Else
		
		ShowMessageBox( ,NStr("en = 'This option is not available due to the file system extension is not attached.'"));
		
	EndIf;

EndProcedure

&AtClient
Procedure ImportFilesCompletion(Result,  Parameters)  Export
	If  Not Result =  Undefined Then
		CreateCatalogItems(Result.ImportedFiles,  Result.Owner);
		Items.List.Refresh();
	EndIf;
EndProcedure
 
&AtClient
Procedure OpenFile()
	
	ExtensionAttached = AttachFileSystemExtension();
	FilesToTransfer = SelectedFilesDescription(ExtensionAttached);
	If FilesToTransfer.Count() > 0 Then
		If ExtensionAttached Then
			
			Directory = HandlingCommonSettingsStorage.GetWorkingDirectory();
			If Directory = Undefined Or Directory = "" Then
				Dialog = New FileDialog(FileDialogMode.ChooseDirectory);
				Dialog.Title = NStr("en = 'Select the temporary file storage directory.'");
				If Dialog.Choose() = False Then
					Return;
				EndIf;
				Directory = Dialog.Directory;
				HandlingCommonSettingsStorage.SaveWorkingDirectory(Directory);
			EndIf;
			
			TransferredFiles = New Array;
			
			Calls = New Array;
			CallGetFiles =  New Array;
			CallGetFiles.Add("GetFiles");
			CallGetFiles.Add(FilesToTransfer);
			CallGetFiles.Add(TransferredFiles);
			CallGetFiles.Add("");
			CallGetFiles.Add(False);
			Calls.Add(CallGetFiles);
			For Each Details In FilesToTransfer Do
				Details.Name = Directory + "\" + Details.Name;
				CallRunApplication =  New Array;
				CallRunApplication.Add("RunApp");
				CallRunApplication.Add(Details.Name);
				Calls.Add(CallRunApplication);
			EndDo;
			
			If RequestUserPermission(Calls) Then
				If GetFiles(FilesToTransfer, TransferredFiles, "", False) Then
					
					For Each Details In TransferredFiles Do
						RunApp(Details.Name);
					EndDo;
					
				EndIf;
			EndIf;
		Else
			
			For Each Details In FilesToTransfer Do
				GetFile(Details.Location, Details.Name);
			EndDo;
			
		EndIf;
	EndIf;
EndProcedure
