

Procedure BeforeWrite(Cancellation, Replacing)
	
	If Count() = 1 Then
		Folder = Get(0).Folder;
		Path = Get(0).Path;
		
		If IsBlankString(Path) Then
			Return;
		EndIf;						
		
		Query = New Query;
		Query.Text = 
			"SELECT
			|	FileFolders.Ref,
			|	FileFolders.Description
			|FROM
			|	Catalog.FileFolders AS FileFolders
			|WHERE
			|	FileFolders.Parent = &Ref";
		
		Query.SetParameter("Ref", Folder);
		
		Result = Query.Execute();
		Selection = Result.Choose();
		While Selection.Next() Do
			
			WorkingDirectory = Path;
			// Add closing slash, if it is missing
			If Right(WorkingDirectory,1) <> "\" Then
				WorkingDirectory = WorkingDirectory + "\";
			EndIf;
			
			WorkingDirectory = WorkingDirectory + Selection.Description + "\";
			
			FileOperations.SaveWorkingDirectory(Selection.Ref, WorkingDirectory);
		EndDo;
		
	EndIf;
	
EndProcedure
