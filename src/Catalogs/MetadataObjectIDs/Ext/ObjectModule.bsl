
// BeforeWrite event handler prevents metadata object identifiers editing 
// in case of this identifiers can be updated only 
// by means of the special procedure based on 
// configuration metadata:
//
// Catalogs.MetadataObjectIDs.UpdateCatalogData()
//
Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Not AdditionalProperties.Property("ExecutingAutomaticCatalogDataUpdate") Then
		
		Raise(NStr("en = 'Error working with Metadata object IDs catalog.
		 |
		 |Metadata object identifiers can be edited
		 |- automatically by means of the special procedure
		 | Catalogs.MetadataObjectIDs.UpdateCatalogData(),
		 |- manually in Designer mode (predefined items adding/deleting).
		 |
		 |One could delete marked for deletion unused items.'"));
	EndIf;
	
EndProcedure



// BeforeDelete event handler prevents metadata object identifiers deletion
// in case of Used value is True
// or DeletionMark value is False.
//
Procedure BeforeDelete(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Used Then
		Raise(NStr("en = 'Error working with Metadata object IDs catalog.
		 |
		 |Deletion of metadata object identifiers with Used attribute set to True 
		 |is not allowed.'"));
	ElsIf Not DeletionMark Then
		Raise(NStr("en = 'Error working with Metadata object IDs catalog.
		 |
		 |Deletion of metadata оbject identifiers with DeletionMark attribute set to False 
		 | is not allowed.'"));
	EndIf;
	
EndProcedure
