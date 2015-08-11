//////////////////////////////////////////////////////////////
// Full-text search management routines

// scheduled job FullTextSearchIndexUpdate
Procedure FullTextSearchIndexUpdate() Export
	FullTextSearch.UpdateIndex(False, True);
EndProcedure

// scheduled job JoinFullTextSearchIndex
Procedure JoinFullTextSearchIndex() Export
	FullTextSearch.UpdateIndex(True);
EndProcedure

// Full Full Text Search Index Update
Procedure FullFullTextSearchIndexUpdate() Export
	FullTextSearch.UpdateIndex();
EndProcedure
