
// Saves edited file in IB and removes lock from it
Procedure EndEdit(
	CommandParameter, 
	FormID, 
	Val StoreVersions 		 = Undefined,
	Val LockedByCurrentUser  = Undefined, 
	Val LockedBy 			 = Undefined,
	Val CurrentVersionAuthor = Undefined) Export
	
	If CommandParameter = Undefined Then
		Return;
	EndIf;	
	
	If TypeOf(CommandParameter) = Type("Array") Then
		
		ProcessedFilesArray = FileOperationsClient.EndEditByRefs(
			CommandParameter, 
			FormID); 
		
		For Each FileRef In ProcessedFilesArray Do
			NotifyChanged(FileRef);
			Notify("FileDataModified", FileRef);
			Notify("VersionSaved", FileRef);
		EndDo;	
		
	Else	
		
		EditingCompleted = False;
		
		EditingCompleted = FileOperationsClient.EndEdit(
			CommandParameter, 
			FormID,
			StoreVersions,
			LockedByCurrentUser,
			LockedBy,
			CurrentVersionAuthor,
			""); 
		
		If EditingCompleted Then 
			Notify("EditCompleted",    CommandParameter);
			NotifyChanged(			   CommandParameter);
			Notify("FileDataModified", CommandParameter);
			Notify("VersionSaved", 	   CommandParameter);
		EndIf;	
		
	EndIf;
	
EndProcedure

// Blocks file for edit and opens it
Procedure Edit(ObjectRef, UUID = Undefined, OwnerWorkingDirectory = Undefined) Export
	
	If ObjectRef = Undefined Then
		Return;
	EndIf;	
		
	FileOperationsClient.EditFileByRef(ObjectRef, UUID, OwnerWorkingDirectory);
	NotifyChanged(ObjectRef);
	Notify("FileDataModified", ObjectRef);
	Notify("FileWasEdited", ObjectRef);
	
EndProcedure

// Locks file or several files
// CommandParameter - ref to a file, or array of file refs
Procedure Lock(CommandParameter, UUID = Undefined) Export
	
	If CommandParameter = Undefined Then
		Return;
	EndIf;
	
	If TypeOf(CommandParameter) = Type("Array") Then
		
		FileOperationsClient.LockFilesByRefs(CommandParameter);
		
		For Each FileRef In CommandParameter Do
			NotifyChanged(FileRef);
			Notify("FileDataModified", FileRef);
		EndDo;	
		
	Else	
		
		FileOperationsClient.LockFileByRef(CommandParameter, UUID); 
		NotifyChanged(CommandParameter);
		Notify("FileDataModified", CommandParameter);
		
	EndIf;
	
EndProcedure

// Releases file taken before
Procedure UnlockFile(CommandParameter,
					 Val StoreVersions = Undefined,
					 Val LockedByCurrentUser = Undefined, 
					 Val LockedBy = Undefined,
					 UUID = Undefined) Export

	If CommandParameter = Undefined Then
		Return;
	EndIf;
	
	If TypeOf(CommandParameter) = Type("Array") Then
		
		FileOperationsClient.UnlockFilesByRefs(CommandParameter); 
		
		For Each FileRef In CommandParameter Do
			NotifyChanged(FileRef);
			Notify("FileDataModified", FileRef);
		EndDo;	
			
	Else	
		
		FileOperationsClient.UnlockFile(
			CommandParameter, 
			StoreVersions,
			LockedByCurrentUser,
			LockedBy,
			UUID); 
			
		NotifyChanged(CommandParameter);
		Notify("FileDataModified", CommandParameter);
		
	EndIf;
	
EndProcedure

// Opens file for preview
Procedure Open(FileData) Export
	
	FileOperationsClient.OpenFile(FileData);
	Notify("FileIsOpen", FileData.Ref);	
	
EndProcedure

// Saves file in infobase, but does not release it
Procedure SaveFile(CommandParameter, FormID) Export
	
	If CommandParameter = Undefined Then
		Return;
	EndIf;
	
	If TypeOf(CommandParameter) = Type("Array") Then
		
		FileOperationsClient.SaveFileByRefs(CommandParameter, FormID);
		
		For Each FileRef In CommandParameter Do
			Notify("FileDataModified", FileRef);				
			Notify("VersionSaved", FileRef);
		EndDo;	
			
	Else	
		
		FileOperationsClient.SaveFile(CommandParameter, FormID);
		
		Notify("FileDataModified", CommandParameter);				
		Notify("VersionSaved", CommandParameter);
		
	EndIf;
	
EndProcedure

// Opens directory on local computer where this file is located
Procedure OpenFileDirectory(FileData) Export
	
	FileOperationsClient.FileDir(FileData);
	
EndProcedure

// Saves file current version into selected directory on hard disk or network disk
Procedure SaveAs(FileData) Export
	
	FileOperationsClient.SaveAs(FileData);	
	
EndProcedure

// Choses file on disk and creates new version from it
Procedure UpdateFromFileOnDisk(FileData, FormID) Export
	
	IsExtensionAttached = AttachFileSystemExtension();
	If IsExtensionAttached Then
		
		FileOperationsClient.UpdateFromFileOnDisk(FileData, FormID);	
		NotifyChanged(FileData.Ref);
		Notify("FileDataModified", FileData.Ref);
		Notify("VersionSaved", FileData.Ref);
	
	Else
		DoMessageBox(NStr("en = 'To perform this operation it is necessary to install the Work With Files extension.'"));
	EndIf;
	
EndProcedure

