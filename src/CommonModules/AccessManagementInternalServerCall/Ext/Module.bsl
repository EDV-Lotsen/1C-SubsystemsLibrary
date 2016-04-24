////////////////////////////////////////////////////////////////////////////////
// Access management subsystem
 
////////////////////////////////////////////////////////////////////////////////

#Region InternalInterface

////////////////////////////////////////////////////////////////////////////////
// Management of AccessKinds and AccessValues tables in the forms used for editing

// For internal use only
Function GenerateUserSelectionData(Val Text,
                                   Val IncludeGroups = True,
                                   Val IncludingExternalUsers = Undefined,
                                   Val NoUsers = False) Export
	
	Return Users.GenerateUserSelectionData(
		Text,
		IncludeGroups,
		IncludingExternalUsers,
		NoUsers);
	
EndFunction

// Returns the list of access values that are not marked for deletion.
// The function is used in TextEditEnd and AutoComplete event handlers.
// Parameters:
// Text          - String  - characters entered by the user.
// IncludeGroups - Boolean - if True, include user groups and external user groups in the function result.
// AccessKind    - Ref     - an empty reference of the main access value type.
//               - String  - name of the access type whose access values are selected.

Function GenerateAccessValueChoiceData(Val Text, Val AccessKind, IncludeGroups = True) Export
	
	AccessKindProperties = AccessManagementInternal.AccessKindProperties(AccessKind);
	If AccessKindProperties = Undefined Then
		Return New ValueList;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("Text", Text + "%");
	Query.SetParameter("IncludeGroups", IncludeGroups);
	Query.Text =
	"SELECT
	|	EnumPresentations.Ref,
	|	EnumPresentations.Description AS Description
	|INTO EnumPresentations
	|FROM
	|	&EnumPresentations AS EnumPresentations
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	UNDEFINED AS Ref,
	|	"""" AS Description
	|WHERE
	|	FALSE";
	
	EnumPresentationQuery = New Query;
	EnumPresentationQuery.Text =
	"SELECT
	|	"""" AS Ref,
	|	"""" AS Description
	|WHERE
	|	FALSE";
	
	For Each Type In AccessKindProperties.TypesOfValuesToSelect Do
		
		TypeMetadata = Metadata.FindByType(Type);
		
		FullTableName = TypeMetadata.FullName();
		
		If (     Metadata.Catalogs.Contains(TypeMetadata)
		       Or Metadata.ChartsOfCharacteristicTypes.Contains(TypeMetadata) )
		   And TypeMetadata.Hierarchical
		   And TypeMetadata.HierarchyType = Metadata.ObjectProperties.HierarchyType.HierarchyFoldersAndItems
		   And Not IncludeGroups Then
			
			ConditionForFolder = "NOT Table.IsFolder";
		Else
			ConditionForFolder = "True";
		EndIf;
		
		If Metadata.Enums.Contains(TypeMetadata) Then
			
			EnumPresentationQuery.Text = EnumPresentationQuery.Text + Chars.LF + Chars.LF + " UNION ALL "  + Chars.LF + Chars.LF;
			EnumPresentationQuery.Text = EnumPresentationQuery.Text + StrReplace(
			"SELECT
			|	Table.Ref,
			|	PRESENTATION(Table.Ref) AS Description
			|FROM
			|	&FullTableName AS Table", "&FullTableName", FullTableName);
		Else
			Query.Text = Query.Text + Chars.LF + Chars.LF + " UNION ALL "  + Chars.LF + Chars.LF;
			Query.Text = Query.Text + StrReplace(StrReplace(
			"SELECT
			|	Table.Ref,
			|	Table.Description
			|FROM
			|	&FullTableName AS Table
			|WHERE
			|	(NOT Table.DeletionMark)
			|	AND Table.Description LIKE &Text
			|	AND &ConditionForFolder", "&FullTableName", FullTableName), "&ConditionForFolder", ConditionForFolder);
		EndIf;
	EndDo;
	
	Query.SetParameter("EnumPresentations", EnumPresentationQuery.Execute().Unload());
	Query.Text = Query.Text + Chars.LF + Chars.LF + " UNION ALL "  + Chars.LF + Chars.LF;
	Query.Text = Query.Text +
	"SELECT
	|	EnumPresentations.Ref,
	|	EnumPresentations.Description
	|FROM
	|	EnumPresentations AS EnumPresentations
	|WHERE
	|	EnumPresentations.Description LIKE &Text";
	
	ChoiceData = New ValueList;
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		ChoiceData.Add(Selection.Ref, Selection.Description);
	EndDo;
	
	Return ChoiceData;
	
EndFunction

#EndRegion
