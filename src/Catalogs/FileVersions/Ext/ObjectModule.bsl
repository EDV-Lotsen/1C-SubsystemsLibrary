

Var SignedObjectRecord Export;

Procedure BeforeWrite(Cancellation)
	
	If DataExchange.Load Then 
		Return;
	EndIf;
	
	If IsNew() Then
		ParentalVersion = Owner.CurrentVersion;
	EndIf;	
	
	// Update pictogramm index on object write
	PictureIndex = FileOperationsClientServer.GetFilePictogramIndex(Extension);
	
	If TextExtractionStatus.IsEmpty() Then
		TextExtractionStatus = Enums.FileTextExtractionStatuses.NotExtracted;
	EndIf;	
	
	If TypeOf(Owner) = Type("CatalogRef.Files") Then
		Description = TrimAll(FileName);
	EndIf;	
	
	If Owner.CurrentVersion = Ref Then
		If DeletionMark = True And Owner.DeletionMark <> True Then
			Cancellation = True;
			CommonUseClientServer.MessageToUser(NStr("en = 'Active version cannot be deleted!'"));
		EndIf;
	ElsIf ParentalVersion.IsEmpty() Then
		If DeletionMark = True And Owner.DeletionMark <> True Then
			Cancellation = True;
			CommonUseClientServer.MessageToUser(NStr("en = 'The first version cannot be deleted!'"));
		EndIf;
	ElsIf DeletionMark = True And Owner.DeletionMark <> True Then
		// Clear ref to the parent - for the versions, that are childs relatively to the marked version -
		// change to the parent version of the version being deleted
		Query = New Query;
		Query.Text = 
			"SELECT
			|	FileVersions.Ref AS Ref
			|FROM
			|	Catalog.FileVersions AS FileVersions
			|WHERE
			|	FileVersions.ParentalVersion = &ParentalVersion";

		Query.SetParameter("ParentalVersion", Ref);

		Result = Query.Execute();

		If Not Result.IsEmpty() Then
			Selection = Result.Choose();
			Selection.Next();
			
			Object = Selection.Ref.GetObject();
			LockDataForEdit(Object.Ref);
			Object.ParentalVersion = ParentalVersion;
			Object.Write();
		EndIf;
	EndIf;
	
EndProcedure

Procedure BeforeDelete(Cancellation)
	If FileStorageType = Enums.FileStorageTypes.VolumesOnHardDisk Then
		If NOT Volume.IsEmpty() Then
			FullPath = FileOperations.VolumeFullPath(Volume) + FilePath; 
			Try
				File = New File(FullPath);
				File.SetReadOnly(False);
				DeleteFiles(FullPath);
				
				PathWithSubdirectory = File.Path;
				FilesArrayInDirectory = FindFiles(PathWithSubdirectory, "*.*");
				If FilesArrayInDirectory.Count() = 0 Then
					DeleteFiles(PathWithSubdirectory);
				EndIf;
				
			Except
			EndTry;
		EndIf;
	EndIf;
EndProcedure
