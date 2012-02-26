
// Extracts text from files on disk
Procedure TextExtraction() Export
	
	ServerPlatformType = FileOperationsSecondUse.ServerPlatformType();
	If ServerPlatformType <> PlatformType.Windows_x86 And ServerPlatformType <> PlatformType.Windows_x86_64 Then
		Return;  // text extraction works only in Windows
	EndIf;	
	
	NameWithFileExtention = "";	
	
	Try	
		WriteLogEvent("Text extraction", 
			EventLogLevel.Information, , ,
			NStr("en = 'Scheduled texts extraction started'"));
			
		Query = New Query;
		
		Query.Text = 			
		 "SELECT TOP 100
		 |	FileVersions.Ref AS Ref,
		 |	FileVersions.TextExtractionStatus AS TextExtractionStatus,
		 |	FileVersions.FileStorageType AS FileStorageType
		 |FROM
		 |	Catalog.FileVersions AS FileVersions
		 |WHERE
		 |	(FileVersions.TextExtractionStatus = &Status
		 |			OR FileVersions.TextExtractionStatus = VALUE(Enum.FileTextExtractionStatuses.EmptyRef))
		 |	AND FileVersions.Encrypted = &Encrypted";
		
		Query.SetParameter("Status", Enums.FileTextExtractionStatuses.NotExtracted);
		Query.SetParameter("Encrypted", False);
		
		Result = Query.Execute();
		UnloadTable = Result.Unload();
		
		For Each String In UnloadTable Do
			CurrentVersion = String.Ref.GetObject();
			
			NameWithFileExtention = CurrentVersion.Details  + "." + CurrentVersion.Extension;
			
			FileNameWithPath = "";
			FileStorageType = String.FileStorageType;
			
			Try
			
				If FileStorageType = Enums.FileStorageTypes.Infobase Then
					FileBinaryData = CurrentVersion.FileStorage.Get();
					
					FileNameWithPath = GetTempFileName(CurrentVersion.Extension);
					// Save file from infobase to a disk
					FileBinaryData.Write(FileNameWithPath);
				Else // here file on disk
					
					If Not CurrentVersion.Volume.IsEmpty() Then
						FileNameWithPath = FileOperations.VolumeFullPath(CurrentVersion.Volume) + CurrentVersion.FilePath; 
					EndIf;
					
				EndIf;
				
				
				Text = "";
				
				If FileNameWithPath <> "" Then
					// Extracting text from file
					Extraction = New TextExtraction(FileNameWithPath);
					Text = Extraction.GetText();
					CurrentVersion.TextExtractionStatus = Enums.FileTextExtractionStatuses.Extracted;
				EndIf;
			
			Except // Write nothing - it's normal - when nobody can extract Text
				CurrentVersion.TextExtractionStatus = Enums.FileTextExtractionStatuses.ExtractFailed;
			EndTry;
			
			If FileStorageType = Enums.FileStorageTypes.Infobase Then
				DeleteFiles(FileNameWithPath);
			EndIf;

			CurrentVersion.TextStorage = New ValueStorage(Text, New Deflation);

			FileIsLocked = False;
			
			File = CurrentVersion.Owner;
			If File.CurrentVersion = String.Ref Then
				Try
					LockDataForEdit(File);
					FileIsLocked = True;
				Except
					Continue; // output nothing to a user, process next object FileVersions
				EndTry;
			EndIf;
			
			SetPrivilegedMode(True);
			BeginTransaction();
			Try
				CurrentVersion.Write();

				If File.CurrentVersion = String.Ref Then
					FileObject 				= File.GetObject();
					FileObject.TextStorage 	= CurrentVersion.TextStorage;
					FileObject.Write();
				EndIf;
				
				CommitTransaction();
				SetPrivilegedMode(False);
				
				If FileIsLocked Then
					UnlockDataForEdit(File);
				EndIf;
				
			Except
				RollbackTransaction();
				SetPrivilegedMode(False);
				
				If FileIsLocked Then
					UnlockDataForEdit(File);
				EndIf;
				
				Raise;
			EndTry;
			
		EndDo;
		
		WriteLogEvent("Text extraction", 
			EventLogLevel.Information, , ,
			NStr("en = 'Scheduled texts extraction completed'"));
	Except

		ErrorDescriptionInfo = ErrorDescription();
		MessageText = StringFunctionsClientServer.SubstitureParametersInString(
								 NStr("en = 'Unknown error occurred during scheduled texts extraction from file %1'"), 
								 NameWithFileExtention);
		MessageText = MessageText + String(ErrorDescriptionInfo);
		
		WriteLogEvent("Text extraction", 
			EventLogLevel.Error, , ,
			MessageText);
			
	EndTry;
EndProcedure

