////////////////////////////////////////////////////////////////////////////////
// "Item order setup" subsystem
//
////////////////////////////////////////////////////////////////////////////////

#Region InternalProceduresAndFunctions

// Moves a list item up or down.
//
// Parameters:
//  Ref               - Ref - reference to the list item;
//  List              - DynamicList - The list that contains the item;
//  ListView - Boolean - True is the view mode of the form item linked to the list is "List";
//  Direction         - String - move direction: "Up" or "Down".
//
// Returns:
//  String - error description.
Function ChangeItemOrder(Ref, List, ListView, Direction) Export
	
	Result = CheckCanMove(Ref, List, ListView);
	
	If IsBlankString(Result) Then
		MoveItem(Ref, List, Direction);
	EndIf;
	
	Return Result;
	
EndFunction

// Returns a structure with object metadata details.
// 
// Parameters:
//  Ref - Object reference.
//
// Returns:
//  Structure - metadata object details.
Function GetInformationForMoving(Ref) Export
	
	Information = New Structure;
	
	ObjectMetadata = Ref.Metadata();
	AttributeMetadata = ObjectMetadata.Attributes.AdditionalOrderingAttribute;
	
	Information.Insert("FullName",    ObjectMetadata.FullName());
	
	IsCatalog = Metadata.Catalogs.Contains(ObjectMetadata);
	IsCCT        = Metadata.ChartsOfCharacteristicTypes.Contains(ObjectMetadata);
	
	If IsCatalog Or IsCCT Then
		
		Information.Insert("HasFolders",
					ObjectMetadata.Hierarchical And 
							?(IsCCT, True, ObjectMetadata.HierarchyType = Metadata.ObjectProperties.HierarchyType.HierarchyFoldersAndItems));
		
		Information.Insert("ForFolders",     (AttributeMetadata.Use <> Metadata.ObjectProperties.AttributeUse.ForItem));
		Information.Insert("ForItems", (AttributeMetadata.Use <> Metadata.ObjectProperties.AttributeUse.ForFolder));
		Information.Insert("HasParent",  ObjectMetadata.Hierarchical);
		Information.Insert("FoldersOnTop", ?(Not Information.HasParent, False, ObjectMetadata.FoldersOnTop));
		Information.Insert("HasOwner", ?(IsCCT, False, (ObjectMetadata.Owners.Count() <> 0)));
		
	Else
		
		Information.Insert("HasFolders",   False);
		Information.Insert("ForFolders",     False);
		Information.Insert("ForItems", True);
		Information.Insert("HasParent", False);
		Information.Insert("HasOwner", False);
		Information.Insert("FoldersOnTop", False);
		
	EndIf;
	
	Return Information;
	
EndFunction

// Returns the value of the additional order attribute for a new object.
//
// Parameters:
//  Information - Structure - object metadata;
//  Parent      - Ref - parent object reference;
//  Owner       - Ref - object owner reference.
//
// Returns:
//  Number - additional ordering attribute  value.
Function GetNewAdditionalOrderingAttributeValue(Information, Parent, Owner) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query();
	
	QueryConditions = New Array;
	
	If Information.HasParent Then
		QueryConditions.Add("Table.Parent = &Parent");
		Query.SetParameter("Parent", Parent);
	EndIf;
	
	If Information.HasOwner Then
		QueryConditions.Add("Table.Owner = &Owner");
		Query.SetParameter("Owner", Owner);
	EndIf;
	
	AdditionalConditions = "TRUE";
	For Each Condition In QueryConditions Do
		AdditionalConditions = AdditionalConditions + " And " + Condition;
	EndDo;
	
	QueryText =
	"SELECT TOP 1
	|	Table.AdditionalOrderingAttribute AS AdditionalOrderingAttribute
	|FROM
	|	&Table AS Table
	|WHERE
	|	&AdditionalConditions
	|
	|ORDER BY
	|	AdditionalOrderingAttribute DESC";
	
	QueryText = StrReplace(QueryText, "&Table", Information.FullName);
	QueryText = StrReplace(QueryText, "&AdditionalConditions", AdditionalConditions);
	
	Query.Text = QueryText;
	
	Selection = Query.Execute().Select();
	Selection.Next();
	
	Return ?(Not ValueIsFilled(Selection.AdditionalOrderingAttribute), 1, Selection.AdditionalOrderingAttribute + 1);
	
EndFunction

// Swaps the selected list item with an adjacent item.
Procedure MoveItem(ObjectRef, List, Val Direction)
	
	Information = GetInformationForMoving(ObjectRef);
	
	QueryText = 
	"SELECT ALLOWED TOP 1
	|	*
	|FROM
	|	&Table AS Table
	|WHERE
	|	Table.AdditionalOrderingAttribute > &AdditionalOrderingAttribute
	|ORDER BY
	|	Table.AdditionalOrderingAttribute";
	
	QueryText = StrReplace(QueryText, "&Table", List.MainTable);
	If Direction = "Up" Then
		QueryText = StrReplace(QueryText, ">", "<");
		QueryText = QueryText + " DESC";
	EndIf;
	
	QueryBuilder = New QueryBuilder(QueryText);
	QueryBuilder.FillSettings();
	
	If Information.HasParent Then
		AddSimpleFilterToQueryBuilder(QueryBuilder, "Parent", CommonUse.ObjectAttributeValue(ObjectRef, "Parent"));
	EndIf;
	
	If Information.HasOwner Then
		AddSimpleFilterToQueryBuilder(QueryBuilder, "Owner", CommonUse.ObjectAttributeValue(ObjectRef, "Owner"));
	EndIf;
	
	If Information.HasFolders Then
		If Information.ForFolders And Not Information.ForItems Then
			AddSimpleFilterToQueryBuilder(QueryBuilder, "IsFolder", True);
		ElsIf Not Information.ForFolders And Information.ForItems Then
			AddSimpleFilterToQueryBuilder(QueryBuilder, "IsFolder", False);
		EndIf;
	EndIf;
	
	CopyFilters(QueryBuilder, List);
	QueryBuilder.Parameters.Insert("AdditionalOrderingAttribute", CommonUse.ObjectAttributeValue(ObjectRef, "AdditionalOrderingAttribute"));
	
	QueryBuilder.Execute();
	
	Selection = QueryBuilder.Result.Select();
	If Selection.Count() <> 1 Then
		Return;
	EndIf;
	
	Selection.Next();
	
	BeginTransaction();

	Try
		LockDataForEdit(ObjectRef);
		LockDataForEdit(Selection.Ref);
		
		ItemToMove = ObjectRef.GetObject();
		NextItem = Selection.Ref.GetObject();
		
		ItemToMove.AdditionalOrderingAttribute = ItemToMove.AdditionalOrderingAttribute + NextItem.AdditionalOrderingAttribute;
		NextItem.AdditionalOrderingAttribute     = ItemToMove.AdditionalOrderingAttribute - NextItem.AdditionalOrderingAttribute;
		ItemToMove.AdditionalOrderingAttribute = ItemToMove.AdditionalOrderingAttribute - NextItem.AdditionalOrderingAttribute;
	
		ItemToMove.Write();
		NextItem.Write();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

Function ComparisonType(DataCompositionComparisonTypeCollectionValue)
	
	If DataCompositionComparisonTypeCollectionValue = DataCompositionComparisonType.Greater Then
		Return ComparisonType.Greater;
	ElsIf DataCompositionComparisonTypeCollectionValue = DataCompositionComparisonType.GreaterOrEqual Then
		Return ComparisonType.GreaterOrEqual;
	ElsIf DataCompositionComparisonTypeCollectionValue = DataCompositionComparisonType.InHierarchy Then
		Return ComparisonType.InHierarchy;
	ElsIf DataCompositionComparisonTypeCollectionValue = DataCompositionComparisonType.InList Then
		Return ComparisonType.InList;
	ElsIf DataCompositionComparisonTypeCollectionValue = DataCompositionComparisonType.InListByHierarchy Then
		Return ComparisonType.InListByHierarchy;
	ElsIf DataCompositionComparisonTypeCollectionValue = DataCompositionComparisonType.Less Then
		Return ComparisonType.Less;
	ElsIf DataCompositionComparisonTypeCollectionValue = DataCompositionComparisonType.LessOrEqual Then
		Return ComparisonType.LessOrEqual;
	ElsIf DataCompositionComparisonTypeCollectionValue = DataCompositionComparisonType.NotInHierarchy Then
		Return ComparisonType.NotInHierarchy;
	ElsIf DataCompositionComparisonTypeCollectionValue = DataCompositionComparisonType.NotInList Then
		Return ComparisonType.NotInList;
	ElsIf DataCompositionComparisonTypeCollectionValue = DataCompositionComparisonType.NotInListByHierarchy Then
		Return ComparisonType.NotInListByHierarchy;
	ElsIf DataCompositionComparisonTypeCollectionValue = DataCompositionComparisonType.NotEqual Then
		Return ComparisonType.NotEqual;
	ElsIf DataCompositionComparisonTypeCollectionValue = DataCompositionComparisonType.NotContains Then
		Return ComparisonType.NotContains;
	ElsIf DataCompositionComparisonTypeCollectionValue = DataCompositionComparisonType.Equal Then
		Return ComparisonType.Equal;
	ElsIf DataCompositionComparisonTypeCollectionValue = DataCompositionComparisonType.Contains Then
		Return ComparisonType.Contains;
	Else
		Return Undefined;
	EndIf;
	
EndFunction

// Copies the dynamic list filters to the query builder. Fields that are not available in the query builder are ignored.
Procedure CopyFilters(QueryBuilder, DynamicList)
	Filter = QueryBuilder.Filter;
	For Each DynamicListFilterItem In DynamicList.SettingsComposer.GetSettings().Filter.Items Do
		
		FieldName = DynamicListFilterItem.LeftValue;
		NameParts = StringFunctionsClientServer.SplitStringIntoSubstringArray(FieldName, ".", False);
		
		If QueryBuilder.AvailableFields.Find(NameParts[0]) = Undefined Then
			Continue;
		EndIf;
		
		RightValue = DynamicListFilterItem.RightValue;
		BuilderComparisonType = ComparisonType(DynamicListFilterItem.ComparisonType);
		If BuilderComparisonType = Undefined Then
			AttributeMetadata = Metadata.FindByFullName(DynamicList.MainTable).Attributes.Find(FieldName);
			If AttributeMetadata = Undefined Then
				// Searching in the standart attributes
				For Each StandardAttribute In Metadata.FindByFullName(DynamicList.MainTable).StandardAttributes Do
					If StandardAttribute.Name = FieldName Then
						AttributeMetadata = StandardAttribute;
						Break;
					EndIf;
				EndDo;
			EndIf;
			
			If AttributeMetadata <> Undefined Then
				If AttributeMetadata.Type = New TypeDescription("Boolean") Then
					Continue;
				EndIf;
				RightValue = New Array;
				RightValue.Add(Undefined);
				RightValue.Add("");
				RightValue.Add(0);
				RightValue.Add();
				For Each Type In AttributeMetadata.Type.Types() Do
					If Type <> Type("Boolean") Then
						Types = New Array;
						Types.Add(Type);
						TypeDescription = New TypeDescription(Types);
						RightValue.Add(TypeDescription.AdjustValue());
					EndIf;
				EndDo;
			Else
				Continue;
			EndIf;
			
			If DynamicListFilterItem.ComparisonType = DataCompositionComparisonType.Filled Then
				BuilderComparisonType = ComparisonType.NotInList;
			ElsIf DynamicListFilterItem.ComparisonType = DataCompositionComparisonType.NotFilled Then
				BuilderComparisonType = ComparisonType.InList;
			Else // Unknown comparison kind
				Continue;
			EndIf;
		EndIf;
		
		QueryBuilderFilterItem = Filter.Add(FieldName);
		QueryBuilderFilterItem.ComparisonType = BuilderComparisonType;
		QueryBuilderFilterItem.Value = RightValue;
		QueryBuilderFilterItem.Use = DynamicListFilterItem.Use;
	EndDo;
	
EndProcedure

Procedure AddSimpleFilterToQueryBuilder(QueryBuilder, FieldName, Value)
	Filter = QueryBuilder.Filter;
	QueryBuilderFilterItem = Filter.Add(FieldName);
	QueryBuilderFilterItem.ComparisonType = ComparisonType.Equal;
	QueryBuilderFilterItem.Value = Value;
	QueryBuilderFilterItem.Use = True;
EndProcedure

Function ListContainsFilterByOwner(List)
	
	RequiredFilters = New Array;
	RequiredFilters.Add(New DataCompositionField("Owner"));
	RequiredFilters.Add(New DataCompositionField("Owner"));
	
	For Each Filter In List.SettingsComposer.GetSettings().Filter.Items Do
		If RequiredFilters.Find(Filter.LeftValue) <> Undefined Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

Function ListContainsFilterByParent(List)
	
	RequiredFilters = New Array;
	RequiredFilters.Add(New DataCompositionField("Parent"));
	RequiredFilters.Add(New DataCompositionField("Parent"));
	
	For Each Filter In List.SettingsComposer.GetSettings().Filter.Items Do
		If RequiredFilters.Find(Filter.LeftValue) <> Undefined Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

Function CheckCanMove(Ref, List, ListView)
	
	AccessParameters = AccessParameters("Update", Ref.Metadata(), "Ref");
	If Not AccessParameters.Accessibility Then
		Return NStr("en = 'Insufficient rights for changing item order.'");
	EndIf;
	
	For Each GroupItem In List.SettingsComposer.GetSettings().Structure Do
		If GroupItem.Use Then
			Return NStr("en = 'To be able to change the item order, disable all groupings.'");
		EndIf;
	EndDo;
	
	Information = GetInformationForMoving(Ref);
	
  // Hierarchical catalogs can be filtered by parent. If this filter is not set,
  // the list must have "Hierarchical list" or "Tree" view.
	If Information.HasParent And ListView And Not ListContainsFilterByParent(List) Then
		Return NStr("en = 'To be able to change the item order, set the view mode to ""Tree"" or ""Hierarchical list"".'");
	EndIf;
	
	// Subordinate catalogs should be filtered by owner
	If Information.HasOwner And Not ListContainsFilterByOwner(List) Then
		Return NStr("en = 'For changing the order of items you have to set the filter by field ""Owner"".'");
	EndIf;
	
	// Checking the "Use" flag of the AdditionalOrderingAttribute attribute for the item to be moved
	If Information.HasFolders Then
		IsFolder = CommonUse.ObjectAttributeValue(Ref, "IsFolder");
		If IsFolder And Not Information.ForFolders Or Not IsFolder And Not Information.ForItems Then
			Return NStr("en = 'Cannot move the selected item.'");
		EndIf;
	EndIf;
	
	Return "";
	
EndFunction

#EndRegion
