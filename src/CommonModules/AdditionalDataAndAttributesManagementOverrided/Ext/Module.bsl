

////////////////////////////////////////////////////////////////////////////////
// OVERRIDED FUNCTIONS OF THE SUBSYSTEM PROPERTIES

// Get available sets of properties for the object
//
// Returned values:
//  Value list (also empty), if object may contain several sets of properties
//  Undefined if object cannot contain several sets of properties
//
Function GetAvailablePropertiesSetsByObject(Object) Export
	
	Return Undefined;
	
EndFunction

// Get available sets of properties for the object for which mechanism of properties
//  is not defined.
//
// Returned values:
//  Set of properties or List of sets of properties if mechanism is overrided.
//  Undefined if mechanism of properties is not defined for the object.
//
Function GetAvailablePropertiesSetsByRef(Ref) Export
	
	If (Catalogs.AllRefsType().ContainsType(TypeOf(Ref)))
		OR (ChartsOfCharacteristicTypes.AllRefsType().ContainsType(TypeOf(Ref))) Then
		
		If Ref.IsFolder Then
			Return Undefined;
		EndIf;
	EndIf;
	
	MetadataName = Ref.Metadata().FullName();
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	PropertiesSets.Ref
	|FROM
	|	Catalog.AdditionalDataAndAttributesSettings AS PropertiesSets
	|WHERE
	|	PropertiesSets.Predefined
	|	AND PropertiesSets.Description = &Description";
	Query.SetParameter("Description", MetadataName);
	Selection = Query.Execute().Choose();
	
	Return ?(Selection.Next(), Selection.Ref, Undefined);
	
EndFunction // GetAvailablePropertiesSetsByRef()

// Returns name of the attribute of the object-owner of properties where object kind is stored
Function GetObjectKindAttributeName(Ref) Export
	
	Return "";
	
EndFunction	

// Generate tree of values of properties for edit in object form.
//
Function GetTreeForEditPropertiesValues(lstOfSets, propertiesTab, ForAddAttributes)
	
	lstChosen = New ValueList;
	For Each Str In propertiesTab Do
		If lstOfSets.FindByValue(Str.Property) = Undefined Then
			lstChosen.Add(Str.Property);
		EndIf;
	EndDo;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	AdditionalDataAndAttributes.Ref AS Property,
	|	AdditionalDataAndAttributes.ValueType AS PropertyValueType,
	|	AdditionalDataAndAttributes.IsFolder AS IsFolder,
	|	Properties.LineNumber AS LineNumber,
	|	CASE
	|		WHEN AdditionalDataAndAttributes.IsFolder
	|			THEN 0
	|		WHEN Properties.Error
	|			THEN 1
	|		ELSE -1
	|	END AS PictureNo
	|FROM
	|	ChartOfCharacteristicTypes.AdditionalDataAndAttributes AS AdditionalDataAndAttributes
	|		INNER JOIN (SELECT DISTINCT
	|			PropertiesSetsContent.Property AS Property,
	|			FALSE AS Error,
	|			PropertiesSetsContent.LineNumber AS LineNumber
	|		FROM
	|			Catalog.AdditionalDataAndAttributesSettings.AdditionalAttributes AS PropertiesSetsContent
	|		WHERE
	|			PropertiesSetsContent.Ref IN(&lstOfSets)
	|			AND PropertiesSetsContent.Property.IsAdditionalData = &IsAdditionalData
	|		
	|		UNION
	|		
	|		SELECT
	|			AdditionalDataAndAttributes.Ref,
	|			TRUE,
	|			PropertiesSetsContent.LineNumber
	|		FROM
	|			ChartOfCharacteristicTypes.AdditionalDataAndAttributes AS AdditionalDataAndAttributes
	|				LEFT JOIN Catalog.AdditionalDataAndAttributesSettings.AdditionalAttributes AS PropertiesSetsContent
	|				ON (PropertiesSetsContent.Property = AdditionalDataAndAttributes.Ref)
	|					AND (PropertiesSetsContent.Ref IN (&lstOfSets))
	|		WHERE
	|			AdditionalDataAndAttributes.Ref IN(&lstChosen)
	|			AND (PropertiesSetsContent.Ref IS NULL 
	|					OR AdditionalDataAndAttributes.IsAdditionalData <> &IsAdditionalData)) AS Properties
	|		ON AdditionalDataAndAttributes.Ref = Properties.Property
	|
	|ORDER BY
	|	Properties.LineNumber
	|TOTALS BY
	|	Property ONLY HIERARCHY";
	
	Query.SetParameter("IsAdditionalData", Not	ForAddAttributes);
	Query.SetParameter("lstOfSets", 						lstOfSets);
	Query.SetParameter("lstChosen",							lstChosen);
	
	Tree = Query.Execute().Unload(QueryResultIteration.ByGroupsWithHierarchy);
	Tree.Columns.Insert(2, "Value", Metadata.ChartsOfCharacteristicTypes.AdditionalDataAndAttributes.Type);

	
	newTree = New ValueTree;
	For Each Column In Tree.Columns Do
		newTree.Columns.Add(Column.Name, Column.ValueType);
	EndDo;
	
	CopyStringValuesTree(newTree.Rows, Tree.Rows, ChartsOfCharacteristicTypes.AdditionalDataAndAttributes.EmptyRef());
	
	For Each Str In propertiesTab Do
		StrD = newTree.Rows.Find(Str.Property, "Property", True);
		If StrD <> Undefined Then
			StrD.Value = Str.Value;
		EndIf;
	EndDo;
	
	Return newTree;
	
EndFunction // GetTreeForEditPropertiesValues()

// Copy required rows from the generated tree of values of properties to another tree.
//
Procedure CopyStringValuesTree(RowsWhere, RowsFromWhere, Parent)

	For Each Str In RowsFromWhere Do
		If Str.Property = Parent Then
			CopyStringValuesTree(RowsWhere, Str.Rows, Str.Property);
		Else
			NewRow = RowsWhere.Add();
			FillPropertyValues(NewRow, Str);
			CopyStringValuesTree(NewRow.Rows, Str.Rows, Str.Property);
		EndIf;

		RowsWhere.Sort("IsFolder DESC");
	EndDo;

EndProcedure // CopyStringValuesTree()

// Fill tree of values of properties on the object form.
//
Function FillValuesPropertiesTree(Ref, AdditionalData, ForAdditionalDataAndAttributes, Sets) Export
	
	If TypeOf(Sets) = Type("ValueList") Then
		lstOfSets = Sets;
	Else
		lstOfSets = New ValueList;
		If Sets <> Undefined Then
			lstOfSets.Add(Sets);
		EndIf;
	EndIf;
	
	Tree = GetTreeForEditPropertiesValues(lstOfSets, AdditionalData, ForAdditionalDataAndAttributes);
	
	Return Tree;
	
EndFunction // FillValuesPropertiesTree()

// Fill tabular section of the object of properties values from the tree of values of properties.
//
Procedure MovePropertiesValues(AdditionalData, PropertiesTree) Export
	
	Values = New Map;
	FillPropertyValuesFromTree(PropertiesTree.Rows, Values);
	
	AdditionalData.Clear();
	For Each Row In Values Do
		NewRow 			= AdditionalData.Add();
		NewRow.Property = Row.Key;
		NewRow.Value 	= Row.Value;
	EndDo;
	
EndProcedure // MovePropertiesValues()

// Fill map with not empty values based on the rows of tree of values of properties
//
Procedure FillPropertyValuesFromTree(TreeRows, Values)

	For Each Str In TreeRows Do
		If Str.IsFolder Then
			FillPropertyValuesFromTree(Str.Rows, Values);
		ElsIf ValueIsFilled(Str.Value) Then
			Values.Insert(Str.Property, Str.Value);
		EndIf;
	EndDo;

EndProcedure // FillPropertyValuesFromTree()


