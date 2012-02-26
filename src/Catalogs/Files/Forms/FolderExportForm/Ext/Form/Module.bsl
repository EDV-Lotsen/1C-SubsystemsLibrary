
&AtClient
Procedure UnloadRun()
	#If NOT WebClient Then
		// Check - if dump directory exists. if not - create it
		UnloadDirectory = New File(FolderForExport);
		
		If not UnloadDirectory.Exist() Then
			
			Try
				
				CreateDirectory(FolderForExport);
				
			Except
				
				InfoError = ErrorInfo();
				DoMessageBox(NStr("en = 'Failed to create the dump folder'") + Chars.CR + NStr("en = 'Cause:'") + InfoError.Details);
				Return;
				
			EndTry;
			
		EndIf;
		
		Status(StringFunctionsClientServer.SubstitureParametersInString(
		            NStr("en = 'Exporting folder ""%1""...Please wait.'"),
		            String(WhatWeSave) ));
		// Get list of files being dumped
		GenerateFileTree(WhatWeSave);
		
		// Create form in advance, to avoid spending time after
		QuestionForm = GetForm("Catalog.Files.Form.FileExists");
		
		// Begin dump now
		UnloadedFolderHaventBeenMetYet = True;
		Success = BypassFileTree(QuestionForm, FileTree, FolderForExport, False, "", UnloadedFolderHaventBeenMetYet, WhatWeSave);
		
		QuestionForm = Undefined;
		
		If Success Then
			PathBeingSaved = FolderForExport;
			
			FolderName = String(WhatWeSave) + "\";
			EndOfPath = Right(FolderForExport, StrLen(FolderName));
			
			If EndOfPath = FolderName Then
				PathBeingSaved = Left(FolderForExport, StrLen(FolderForExport) - StrLen(FolderName));
			EndIf;
			
			CommonUse.CommonSettingsStorageSave("UnloadFolderName", "UnloadFolderName",  PathBeingSaved);
			
			Status(StringFunctionsClientServer.SubstitureParametersInString(
			             NStr("en = 'Export folder ""% 1"" to folder ""% 2"" has been successfully completed!'"),
			             String(WhatWeSave), String(FolderForExport) ) );
			
			Close();
			
		EndIf;
	#EndIf
EndProcedure

&AtClient
Procedure FolderForExportOnChange(Item)
	FolderForExport = FileFunctionsClient.NormalizeDirectory(FolderForExport);
EndProcedure

&AtClient
Procedure FolderForExportStartChoice(Item, ChoiceData, StandardProcessing)
	#If NOT WebClient Then
		// Open saving folder choice window
		StandardProcessing = False;
		FileChoice = New FileDialog(FileDialogMode.ChooseDirectory);
		FileChoice.Multiselect = False;
		FileChoice.Directory = FolderForExport;
		If FileChoice.Choose() Then
			FolderForExport = FileFunctionsClient.NormalizeDirectory(FileChoice.Directory);
		EndIf;
	#EndIf
EndProcedure

&AtServer
Procedure OnCreate(Cancellation, StandardProcessing)
	
	If Parameters.ExportFolder <> Undefined Then
		WhatWeSave = Parameters.ExportFolder;
	EndIf;
	
EndProcedure

&AtServer
Procedure GenerateFileTree(FolderParent) Export
	Query = New Query;
	Query.Text = "SELECT ALLOWED
	               |	Files.FileOwner AS Folder,
	               |	Files.FileOwner.Description AS FolderDescription,
	               |	Files.CurrentVersion,
	               |	Files.FileName AS Details,
	               |	Files.CurrentVersion.Extension AS Extension,
	               |	Files.CurrentVersion.Size AS Size,
	               |	Files.CurrentVersion.DateModifiedUniversal AS DateModifiedUniversal,
	               |	Files.Ref,
	               |	Files.DeletionMark,
	               |	Files.Encrypted
	               |FROM
	               |	Catalog.Files AS Files
	               |WHERE
	               |	Files.FileOwner In HIERARCHY(&Ref)
	               |	And Files.CurrentVersion <> VALUE(Catalog.FileVersions.EmptyRef)
	               |	And Files.DeletionMark = FALSE
	               |TOTALS BY
	               |	Folder HIERARCHY";
	Query.Parameters.Insert("Ref", FolderParent);
	Result = Query.Execute();
	UnloadTable = Result.Unload(QueryResultIteration.ByGroupsWithHierarchy);
	ValueToFormAttribute(UnloadTable, "FileTree");
EndProcedure

// Recursive function, which performs files dump to the local drive
//
// Parameters:
//  QuestionForm - object of type "ManagedForm", that contains ref
//                 to the created in memory question form about overwrite of file with flag
//                 "For all". Form is created, to save time on
//                 regular form creation inside the recursive loop.
//  FileTable 	 - value tree with the files being dumped.
//  BaseSaveDirectory - string with directory name, where files being saved.
//                 Folder structure is recreated inside (as in file tree)
//                 if required.
//  ForAllFiles - type Boolean
//                 True: user picked action on file overwrite and
//                 raised flag "For all". Do not ask more questions.
//                 False: in each case when file with the name same as in infobase
//                 exists on drive, question will be asked.
//  BasicAction - type DialogReturnCode
//                 on executing one action for all conflicts on file
//                 write (parameter ForAllFiles = True) action,
//                 specified by this parameter, is executed).
//                 .Yes - overwrite
//                 .Ignore - ignore file
//                 .Abort - abort dump
//
// Value returned:
//  True       - can continue dump / dump completed successfully
//  False      - action completed with errors / dump completed with errors
&AtClient
Function BypassFileTree(QuestionForm, FileTable, Val BaseSaveDirectory, ForAllFiles = False, BasicAction = "", UnloadedFolderHaventBeenMetYet, ParentFolder)
	#If NOT WebClient Then
	
		If BasicAction = "" Then
			// By default do the less harmful action
			BasicAction = DialogReturnCode.Ignore;
		EndIf;
		
		For Each FileWrite in FileTable.GetItems() Do
			
			If UnloadedFolderHaventBeenMetYet = True Then
				If FileWrite.Folder = WhatWeSave Then
					UnloadedFolderHaventBeenMetYet = False;
				EndIf;
			EndIf;
			
			If UnloadedFolderHaventBeenMetYet = True Then
				If Not BypassFileTree(QuestionForm, FileWrite, BaseSaveDirectory, ForAllFiles, BasicAction, UnloadedFolderHaventBeenMetYet, FileWrite.Folder) Then
					Return False;
				EndIf;
				
				Continue;
			EndIf;
			
			// Generate directory path and go further. Directories will be created
			BaseSaveDirectoryFile = BaseSaveDirectory;
			If (FileWrite.Folder <> WhatWeSave) And FileWrite.CurrentVersion.IsEmpty() Then
				If ParentFolder <> FileWrite.Folder Then
					BaseSaveDirectoryFile = BaseSaveDirectoryFile + FileWrite.FolderDescription + "\";
				EndIf;
			EndIf;
			
			// Check presence of the base directory: if not - create
			Folder = New File(BaseSaveDirectoryFile);
			If Not Folder.Exist() Then
				While True Do
					Try
						CreateDirectory(BaseSaveDirectoryFile);
						Break;
					Except
						//Why directory has not been created...
						infoError = ErrorInfo();
						
						strText =
						StringFunctionsClientServer.SubstitureParametersInString(
						     NStr("en = 'An error occured when creating folder: %1.
                                   |Cause: %2'"),
						     BaseSaveDirectoryFile,
						     ?(infoError.Cause = Undefined, "Undefined", infoError.Cause.Details) );
						
						Result = DoQueryBox(strText, QuestionDialogMode.AbortRetryIgnore, , DialogReturnCode.Retry);
						If Result = DialogReturnCode.Abort Then
							// Just exit with error
							Return False;
						ElsIf Result = DialogReturnCode.Ignore Then
							// Skip this tree branch and continue further
							Return True;
						Else
							// Try to repeat folder creation
							Continue;
						EndIf;
					EndTry;
				EndDo;
			EndIf;
			
			
			// only in case, when there is at least one file in this folder
			ChildElements = FileWrite.GetItems();
			If ChildElements.Count() <> 0 Then
				groupName = BaseSaveDirectoryFile;
				If Not BypassFileTree(QuestionForm, FileWrite, groupName, ForAllFiles, BasicAction, UnloadedFolderHaventBeenMetYet, FileWrite.Folder) Then
					Return False;
				EndIf;
			EndIf;
			
			If FileWrite.CurrentVersion <> NULL And FileWrite.CurrentVersion.IsEmpty() Then
				// This is item of catalog Files without file - skip
				Continue;
			EndIf;
			
			// Write file to the base directory
			FileNameWithExtension = FileFunctionsClient.GetNameWithExtention(FileWrite.Details, FileWrite.Extension);
			If FileWrite.Encrypted Then
				FileNameWithExtension = FileNameWithExtension + "." + ExtensionForEncryptedFiles; 
			EndIf;	
			FullFileName = BaseSaveDirectoryFile + FileNameWithExtension;
			
			// Check if we can write the file
			Result = DialogReturnCode.Cancel;
			While True Do
				FileOnDrive = New File(FullFileName);
				If FileOnDrive.Exist() And FileOnDrive.IsDirectory() Then
					QuestionText =
					StringFunctionsClientServer.SubstitureParametersInString(
					  NStr("en = 'Cannot export the file %1 because there is a folder with the same name. Retry exporting?'"),
					  FullFileName );
					
					Result = DoQueryBox(QuestionText, QuestionDialogMode.RetryCancel, ,DialogReturnCode.Cancel);
					If Result = DialogReturnCode.Retry Then
						
						// Ignore current file
						Continue;
					EndIf;
				Else
					
					// No file - go further
					Result = DialogReturnCode.Retry;
				EndIf;
				Break;
			EndDo;
			If Result = DialogReturnCode.Cancel Then
				
				// Ignore file with the same name as folder name
				Continue;
			EndIf;
			Result = DialogReturnCode.No;
			
			// Ask, what to do with the current file
			If FileOnDrive.Exist() Then
				
				// If file has R | O and modification time is less, than in infobase - simply overwrite it
				If FileOnDrive.GetReadOnly() And FileOnDrive.GetModificationTime() <= FileWrite.DateModifiedUniversal Then
					Result = DialogReturnCode.Yes;
				Else
					If Not ForAllFiles Then
						Text = 
						StringFunctionsClientServer.SubstitureParametersInString(
						      NStr("en = 'The folder %1 contains the file %2 (size = %3 bytes, modified on %4). The file being saved has size %5 bytes, modified on %6. Overwrite the existing file?'"),
						      BaseSaveDirectoryFile,
						      FileNameWithExtension,
						      FileOnDrive.Size(),
						      FileOnDrive.GetModificationTime(),
						      FileWrite.Size,
						      FileWrite.DateModifiedUniversal );
						
						QuestionForm.TextOfMessage = Text;
						QuestionForm.ApplyForAll = ForAllFiles;
						QuestionForm.SetDefaultsButton(BasicAction);
						
						// Yes 		- overwrite
						// Ignore 	- ignore file
						// Abort 	- abort dump
						Result 		= QuestionForm.DoModal();
						ForAllFiles = QuestionForm.ApplyForAll;
						BasicAction = Result;
					Else
						Result = BasicAction;
					EndIf;
					If Result = DialogReturnCode.Abort Then
						
						// Abort dump
						Return False;
					ElsIf Result = DialogReturnCode.Ignore Then
						
						// Skip this file
						Continue;
					EndIf;
				EndIf;
			Else
				
				// No file, no questions
				Result = DialogReturnCode.Yes;
			EndIf;
			
			// If possible - write file to a hard drive
			If Result = DialogReturnCode.Yes Then
				While True Do
					Try
						FileOnDrive = New File(FullFileName);
						If FileOnDrive.Exist() Then
							
							// Remove R | O flag to be able to delete it
							FileOnDrive.SetReadOnly(False);
						EndIf;
						
						// Always delete first and then recreate
						DeleteFiles(FullFileName);
						
						SizeInMb = FileWrite.Size / (1024 * 1024);
						
						// Update progress indicator
						LabelMoreDetailed =
						StringFunctionsClientServer.SubstitureParametersInString(
							NStr("en = 'Saving file %1 (%2 MB)...'"),
							FileOnDrive.Name,
							?(SizeInMb >= 1, Format(SizeInMb, "NFD=0"), Format(SizeInMb, "NFD=1; NZ=0")) );
						
						Status(
							StringFunctionsClientServer.SubstitureParametersInString(
						    	NStr("en = 'Exporting folder %1'"), FileWrite.FolderDescription),
							,
							LabelMoreDetailed, 
							PictureLib.Information32);
						
						// Write file over again
						strAddress = FileOperations.GetURLForOpening(FileWrite.CurrentVersion, Uuid);
						GetFile(strAddress, FullFileName, False);
						
						// for the variant when files are located on disk (at server) - delete file from temporary storage after getting it
						If IsTempStorageURL(strAddress) Then
							DeleteFromTempStorage(strAddress);
						EndIf;
						
						FileOnDrive = New File(FullFileName);
						
						// Make file read only
						FileOnDrive.SetReadOnly(True);
						
						FileToBeCreatedOnDriveDate = FileWrite.DateModifiedUniversal;
						CommonUseClient.ConvertSummerTimeToCurrentTime(FileToBeCreatedOnDriveDate);
						
						// Assign modification time - as in infobase
						FileOnDrive.SetModificationTime(FileToBeCreatedOnDriveDate);
						Break;
					Except
						
						// For some reason file error has occured on file write and modification of file attributes ...
						infoError = ErrorInfo();
						strText =
						StringFunctionsClientServer.SubstitureParametersInString(
						  NStr("en = 'Error writing file %1.
                                |
                                |Cause: %2'"),
						  FullFileName,
						  ?(infoError.Cause = Undefined, "Undefined", infoError.Cause.Details) );
						
						Result = DoQueryBox(strText, QuestionDialogMode.AbortRetryIgnore, , DialogReturnCode.Retry);
						If Result = DialogReturnCode.Abort Then
							
							// Just exit with error
							Return False;
						ElsIf Result = DialogReturnCode.Ignore Then
							
							// Skip this file and go further
							Break;
						Else
							
							// Try to repeat folder creation
							Continue;
						EndIf;
					EndTry;
				EndDo;
			EndIf;
		EndDo;
		
		Return True;
		
	#EndIf
EndFunction // BypassFileTree()

&AtClient
Procedure FolderForExportOpen(Item, StandardProcessing)
	#If NOT WebClient Then
	
		// Open folder for preview here - in case we will need to do something
		StandardProcessing = False;
		If Not IsBlankString(FolderForExport) Then
			File = New File(FolderForExport);
			If File.Exist() Then
				RunApp(FolderForExport);
			Else
				DoMessageBox(NStr("en = 'It is impossible to open the dump folder. The folder might have not been created yet'"));
			EndIf;
		EndIf;
	
	#EndIf
EndProcedure

&AtClient
Procedure OnOpen(Cancellation)
	
	#If WebClient Then
		DoMessageBox(NStr("en = 'Catalogs export are not supported at web-client.'"));
		Cancellation = True;
		Return;
	#EndIf
	
	// Assign as dump folder My Documents folder
	// or the folder, where files have been dumped last time
	FolderForExport = FileFunctionsClient.LatestUnloadDirectory() + String(WhatWeSave) + "\";
EndProcedure
