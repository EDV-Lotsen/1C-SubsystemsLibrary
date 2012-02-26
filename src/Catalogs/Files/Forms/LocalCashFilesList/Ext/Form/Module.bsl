
&AtClient
Procedure FillFileListInForm()
	FileOperationsClient.InitializeWorkingDirectoryPath();
	LocalFilesCachePath = FileOperationsSecondUseClient.GetFileOperationsPersonalSettings().LocalFilesCachePath;
	
	FileList.Clear();
	
	For Each Row In ListOfFileValuesInRegister Do
		
		FullPath = LocalFilesCachePath + Row.Value.PartialPath;
		File = New File(FullPath);
		If File.Exist() Then
			NewRow = FileList.Add();
			
			FileInCacheDate = Row.Value.DateModifiedUniversal;
			CommonUseClient.ConvertSummerTimeToCurrentTime(FileInCacheDate);
			NewRow.FileModificationDate = FileInCacheDate;
			
			NewRow.FileName 		= Row.Value.Description;
			NewRow.PictureIndex  	= Row.Value.PictureIndex;
			NewRow.Size 			= Row.Value.Size;
			NewRow.Version 			= Row.Value.Ref;
			NewRow.LockedBy 		= Row.Value.LockedBy;
			NewRow.ForEdit 			= Not Row.Value.ForRead;
		EndIf;
	
	EndDo; 	
	
EndProcedure

&AtClient
Procedure OnOpen(Cancellation)
	FillFileListInForm();
EndProcedure

&AtClient
Procedure DeleteByRef(RefForDelete)
	ItemCount = FileList.Count();
	
	For Number = 0 To ItemCount - 1 Do
		String 	= FileList[Number];
		Ref 	= String.Version;
		If Ref = RefForDelete Then
			FileList.Delete(Number);
			Return;
		EndIf;
	EndDo;
EndProcedure

&AtClient
Procedure ReleaseExecute()
	RefsArray = New Array;
	For Each Item In Items.FileList.SelectedRows Do
		RowData = Items.FileList.RowData(Item);
		Ref = RowData.Version;
		RefsArray.Add(Ref);
	EndDo;
	
	For Each Ref In RefsArray Do
		FileData = FileOperations.GetFileData(Undefined, Ref);
		
		// Check possibility to release the file
		ErrorString = "";
		If Not FileOperationsClient.CanUnlockFile(FileData.Ref, FileData.LockedByCurrentUser, FileData.LockedBy, ErrorString) Then
			DoMessageBox(ErrorString);
			Continue;
		EndIf;
		
		FileOperationsClient.UnlockFile(FileData.Ref);
	EndDo;
	
	FillFileList();
	FillFileListInForm();
EndProcedure

&AtServer
Procedure FillFileList()
	
	ListOfFilesInRegister = FileOperations.ListOfFilesInRegister();
	ListOfFileValuesInRegister.Clear();
	
	For Each Row In ListOfFilesInRegister Do
		ListOfFileValuesInRegister.Add(Row);
	EndDo; 	

EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	FillFileList();
EndProcedure

&AtClient
Procedure OpenFileDirectoryExecute()
	If Items.FileList.CurrentData <> Undefined Then
		Ref = Items.FileList.CurrentData.Version;
		FileData = FileOperations.GetFileData(Undefined, Ref);
		FileOperationsClient.FileDir(FileData);
	EndIf;
EndProcedure

&AtClient
Procedure DeleteFromFilesLocalCache(Command)
	RefsArray = New Array;
	For Each CycleNumber In Items.FileList.SelectedRows Do
		RowData = Items.FileList.RowData(CycleNumber);
		Ref = RowData.Version;
		If RowData.ForEdit = False Then // If is not locked by current user
			RefsArray.Add(Ref);
		EndIf;
	EndDo;
	
	For Each Ref In RefsArray Do
		FileFunctionsClient.DeleteFileFromWorkingDirectory(Ref);
		DeleteByRef(Ref);
	EndDo;
	
	Items.FileList.Refresh();
EndProcedure

&AtClient
Procedure EndEdit(Command)
	If Items.FileList.CurrentData <> Undefined Then
		Ref = Items.FileList.CurrentData.Version;
		FileData = FileOperations.GetFileData(Undefined, Ref);
		FileOperationsCommands.EndEdit(FileData.Ref, Uuid);
		FillFileList();
		FillFileListInForm();
	EndIf;
EndProcedure
