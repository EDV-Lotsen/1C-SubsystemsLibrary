
&AtServer
Procedure RefreshParametersAtServer()
	
	DeleteFileFromFilesLocalCacheOnEditEnd 	= CommonUse.CommonSettingsStorageLoad("LocalFilesCache", "DeleteFileFromFilesLocalCacheOnEditEnd");
	If DeleteFileFromFilesLocalCacheOnEditEnd = Undefined Then
		DeleteFileFromFilesLocalCacheOnEditEnd = False;
	EndIf;
	
	ConfirmWhenDeletingFromLocalFilesCache = CommonUse.CommonSettingsStorageLoad("LocalFilesCache", "ConfirmWhenDeletingFromLocalFilesCache");
	If ConfirmWhenDeletingFromLocalFilesCache = Undefined Then
		ConfirmWhenDeletingFromLocalFilesCache = False;
	EndIf;
	
	MaxSize = CommonUse.CommonSettingsStorageLoad("LocalFilesCache", "LocalFilesCacheMaximumSize");
	If MaxSize = Undefined Then
		MaxSize = 100*1024*1024; // 100 mb
		CommonUse.CommonSettingsStorageSave("LocalFilesCache", "LocalFilesCacheMaximumSize", MaxSize);
	EndIf;
	LocalFilesCacheMaximumSize = MaxSize / 1048576;

EndProcedure

&AtClient
Procedure RefreshParametersAtClient()
	FileOperationsClient.InitializeWorkingDirectoryPath();
	LocalFilesCachePath = FileOperationsSecondUseClient.GetFileOperationsPersonalSettings().LocalFilesCachePath;
	
	#If NOT WebClient Then
		FilesArray = FindFiles(LocalFilesCachePath, "*.*");
		FileSizesInWorkingDirectory = 0;
		QuantityTotal = 0;
		FileFunctionsClient.CalculateFilesSizeRecursive(LocalFilesCachePath, FilesArray, FileSizesInWorkingDirectory, QuantityTotal); 
		
		FileSizesInWorkingDirectory = FileSizesInWorkingDirectory / 1048576;
	#EndIf
EndProcedure

&AtClient
Procedure RefreshParameters()
	RefreshParametersAtServer();
	RefreshParametersAtClient();
EndProcedure

&AtClient
Procedure SaveExecute()
	StructuresArray = New Array;
	
	Item = New Structure;
	Item.Insert("Object",  	"LocalFilesCache");
	Item.Insert("Options", 	"LocalFilesCachePath");
	Item.Insert("Value", 	LocalFilesCachePath);
	StructuresArray.Add(Item);
	
	Item = New Structure;
	Item.Insert("Object", 	"LocalFilesCache");
	Item.Insert("Options", 	"LocalFilesCacheMaximumSize");
	Item.Insert("Value", 	LocalFilesCacheMaximumSize * 1048576);
	StructuresArray.Add(Item);
	
	Item = New Structure;
	Item.Insert("Object", 	"LocalFilesCache");
	Item.Insert("Options", 	"DeleteFileFromFilesLocalCacheOnEditEnd");
	Item.Insert("Value", 	DeleteFileFromFilesLocalCacheOnEditEnd);
	StructuresArray.Add(Item);
	
	Item = New Structure;
	Item.Insert("Object", 	"LocalFilesCache");
	Item.Insert("Options", 	"ConfirmWhenDeletingFromLocalFilesCache");
	Item.Insert("Value", 	ConfirmWhenDeletingFromLocalFilesCache);
	StructuresArray.Add(Item);
	
	FileOperations.CommonSettingsStorageSaveArrayAndSessionParameterWorkingDirectory(StructuresArray, LocalFilesCachePath);
	
	RefreshReusableValues();
	FileOperationsClient.InitializeWorkingDirectoryPath();
	
	Close();
EndProcedure

&AtClient
Procedure OnOpen(Cancellation)
	ExtensionConnected = AttachFileSystemExtension();
	If NOT ExtensionConnected Then
		DoMessageBox(NStr("en = 'Web client does not have file system extension allowing to set working directory'"));
		Cancellation = True;
		Return;
	EndIf;
	
	RefreshParametersAtClient();
EndProcedure

&AtClient
Procedure FileListExecute()
	OpenFormModal("Catalog.Files.Form.LocalCashFilesList");
	LocalFilesCachePathInForm = LocalFilesCachePath;
	RefreshParameters();
	LocalFilesCachePath = LocalFilesCachePathInForm;
EndProcedure

&AtClient
Procedure RefreshExecute()
	RefreshParameters();
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	RefreshParametersAtServer();
EndProcedure

&AtClient
Procedure ClearLocalFilesCache(Command)
	#If NOT WebClient Then
	
		QuestionText = NStr("en = 'All files except those you are editing, will be deleted form main directory. Do you want to continue? '");
		Response = DoQueryBox(QuestionText, QuestionDialogMode.YesNo);
		If Response = DialogReturnCode.No Then
		    Return;
		EndIf;
		
		Status(NStr("en = 'Clearing of the main working directory...Please wait.'"));
		DirectoryName = CommonUse.CommonSettingsStorageLoad("LocalFilesCache", "LocalFilesCachePath");
		
		FilesArray = FindFiles(DirectoryName, "*.*");
		
		FileSizesInWorkingDirectory = 0;
		QuantityTotal = 0;
		FileFunctionsClient.CheckFileSizesLimit(DirectoryName, FilesArray, FileSizesInWorkingDirectory, QuantityTotal);
		
		FileFunctionsClient.ClearWorkingDirectory(FileSizesInWorkingDirectory, 0, True); // ClearAll= True
		
		FileSizesInWorkingDirectory = FileSizesInWorkingDirectory / 1048576;
		
		LocalFilesCachePathInForm = LocalFilesCachePath;
		RefreshParameters();
		LocalFilesCachePath = LocalFilesCachePathInForm;
		Status(NStr("en = 'Clearing of the main working directory has been successfully completed'"));
	
	#EndIf
EndProcedure

// if there are files for edit in main working directory
&AtClient
Function AreFilesForEditInLocalCache()
	ListOfFilesInRegister = FileOperations.ListOfFilesInRegister();
	
	For Each String In ListOfFilesInRegister Do
		
		If Not String.ForRead Then
			FullPath = LocalFilesCachePath + String.PartialPath;
			File = New File(FullPath);
			If File.Exist() Then
				Return True;
			EndIf;	
		EndIf;	
	EndDo;		
	
	Return False;
EndFunction	

// return True, if we can continue (to change the path to working directory)
&AtClient
Function QuestionAboutFilesForEditInLocalCache()
	If AreFilesForEditInLocalCache() Then
		ReturnCode = DoQueryBox(NStr("en = 'Main working directory contains files that needs editing. Change of the path to the work directorty will result in loss of the changes made in the files. Do you want to continue?'"), QuestionDialogMode.YesNo);
		If ReturnCode = DialogReturnCode.No Then
			Return False;
		EndIf;	
	EndIf;	
	
	Return True;
EndFunction	

&AtClient
Procedure LocalFilesCachePathStartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	ExtensionConnected = AttachFileSystemExtension();
	If ExtensionConnected Then
		
		If Not QuestionAboutFilesForEditInLocalCache() Then
			Return;
		EndIf;	
		
		Mode 							= FileDialogMode.ChooseDirectory;
		FileOpenDialog 					= New FileDialog(Mode);
		FileOpenDialog.FullFileName 	= "";
		FileOpenDialog.Directory 		= LocalFilesCachePath;
		FileOpenDialog.Multiselect 		= False;
		FileOpenDialog.Title 			= NStr("en = 'Select path to main working directory'");
		If FileOpenDialog.Choose() Then
			
			DirectoryName = FileOpenDialog.Directory;
			FileFunctionsClientServer.AddLastPathSeparatorIfMissing(DirectoryName);
			
			// Create directory for the files
			Try
				CreateDirectory(DirectoryName);
				DirectoryNameIsTest = DirectoryName + "AccessVerification\";
				CreateDirectory(DirectoryNameIsTest);
				DeleteFiles(DirectoryNameIsTest);
			Except
				// no rights for directory creation, or this path is absent
				
				ErrorText 
					= StringFunctionsClientServer.SubstitureParametersInString(NStr("en = 'Incorrect path or no access of right for record in directory ""%1""'"),
					DirectoryName);
				
				CommonUseClientServer.MessageToUser(ErrorText, , "LocalFilesCachePath");
				Return;
			EndTry;
			
			LocalFilesCachePath = DirectoryName;
		EndIf;
	
	EndIf;		
EndProcedure

&AtClient
Procedure PathToWorkingDirectoryByDefault(Command)
	LocalFilesCachePathTemporary = FileFunctionsClient.GetPathToUserDataDirectory();
	
	If LocalFilesCachePath = LocalFilesCachePathTemporary Then
		Return;
	EndIf;	
	
	If Not QuestionAboutFilesForEditInLocalCache() Then
		Return;
	EndIf;	
	
	LocalFilesCachePath = LocalFilesCachePathTemporary;
EndProcedure
