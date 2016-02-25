//Filling the documents kinds list
Procedure FillList() Export
	// Creating a list of documents
	For Each MetadataDocument In Metadata.Documents Do
		
		If MetadataDocument.Posting = Metadata.ObjectProperties.Posting.Allow Then
			DocumentsList.Add(MetadataDocument.Name, MetadataDocument.Presentation());
		EndIf;	
		
	EndDo;	
	DocumentsList.SortByPresentation();
	
	Posted = "Posted";
	
EndProcedure	

//Posting documents from the existing list
Procedure Post(StartDate, EndDate, CurrentPostedCount) Export
	
	For Each ListDocument In SelectedDocuments Do
		
		Selection = Documents[ListDocument.Value].Select(StartDate, EndDate);
		
		While Selection.Next() Do
			
			If Posted = "Posted" And Not Selection.Posted Then
				Continue;
			EndIf;
			
			If Posted = "NotPosted" And Selection.Posted Then
				Continue;
			EndIf;
			
			Object = Selection.GetObject();
			Object.Write(DocumentWriteMode.Posting);
			CurrentPostedCount = CurrentPostedCount + 1;
		EndDo;	
		
	EndDo;	
	
EndProcedure
