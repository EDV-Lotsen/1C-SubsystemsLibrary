// This procedure updates the full-text search index
&AtServer
Procedure UpdateIndex()
	If Not AccessRight("Administration", Metadata) And CommonUse.FileInfoBase() Then
		SetPrivilegedMode(True);	
	EndIf;
	FullTextSearch.UpdateIndex();
	RefreshStateExecute();
EndProcedure

// UpdateIndex command handler
&AtClient
Procedure UpdateIndexExecute()
	Status(NStr("en='Please wait...'") 
		+ Chars.CR 
		+ NStr("en='Updating the full-text search index...'"));
	UpdateIndex();
	Status(NStr("en='Full-text search index update completed'"));
EndProcedure
        

// This procedure clears the full-text search index
&AtServer
Procedure ClearIndexServer() Export
	FullTextSearch.ClearIndex(); 
	RefreshStateExecute();
EndProcedure	

// ClearIndex command handler
&AtClient
Procedure ClearIndexExecute()
	ClearIndexServer();	
EndProcedure

// This procedure updates the information about the index and manages the buttons enabled state
&AtServer
Procedure RefreshStateExecute()
	ThisForm.Items.UpdateIndex.Enabled = False;
	ThisForm.Items.ClearIndex.Enabled = False;
	
	EnableFullTextSearch = FullTextSearch.GetFullTextSearchMode() = FullTextSearchMode.Enable;
	IndexRelevanceDate = '00010101';
	IndexState = "";
	
	If FullTextSearch.GetFullTextSearchMode() = FullTextSearchMode.Enable Then
		IndexRelevanceDate = FullTextSearch.UpdateDate();
		
		If FullTextSearch.IndexTrue() Then
			IndexState = NStr("en='The index update is not required'");
		Else                                                 
			IndexState = NStr("en='The index update is required'");
		EndIf;
		
		If AccessRight("Administration", Metadata) Or CommonUse.FileInfoBase() Then
			ThisForm.Items.ClearIndex.Enabled = True;
			ThisForm.Items.UpdateIndex.Enabled = True;
		EndIf;
	EndIf;
EndProcedure


// This procedure sets the full-text search mode
&AtServer
Procedure SetFullTextSearchEnable(Enabled) Export
	If Enabled Then
		FullTextSearch.SetFullTextSearchMode(FullTextSearchMode.Enable);
	Else
		FullTextSearch.SetFullTextSearchMode(FullTextSearchMode.Disable);
	EndIf;
	RefreshStateExecute();
EndProcedure

&AtClient
Procedure AllowFullTextSearchOnChange(Element)
	Try
		SetFullTextSearchEnable(EnableFullTextSearch);
	Except
		EnableFullTextSearch = Not EnableFullTextSearch;
		Info = ErrorInfo();
		ExceptionString = Info.Description 
		+ "." 
		+ Chars.CR 
		+ NStr("en='It is probably the index update scheduled job is running. Try again later.'");
		Raise ExceptionString;
	EndTry;
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	RefreshStateExecute();
EndProcedure

