////////////////////////////////////////////////////////////////////////////////
// Item order setup subsystem.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

// Moves the object up or down in list.
//
// Parameters:
//  Ref - Ref - reference to the item to be moved;
//  AdjustedFilters - Structure with the following fields:
//  HasFilterByParent - Boolean - flag that shows whether the filter by parent is set in the list;
//  HasFilterByOwner - Boolean - flag that shows whether the filter by owner is set in the list;
//  RepresentedAsList - Boolean - flag that shows whether the Representation property of the form item is set to TableRepresentation.List;
//  Up - Boolean - flag that shows whether the item must be moved up. If it is set
//   to False, the item must be moved down.
//
// Returns:
//  String - errors details.
//
Function ChangeItemOrder(Ref, AdjustedFilters, RepresentedAsList, MoveUp) Export
	
	AccessParameters = AccessParameters("Editing", Ref.Metadata(), "Ref");
	If Not AccessParameters.Accessibility Or AccessParameters.RestrictionByCondition Then
		Return NStr("en = 'Insufficient rights to change the item order.'");
	EndIf;
	
	Information = GetMetadataToMoveInfo(Ref);
	
	// Changing the item order is possible for hierarchical catalogs if the filter by
	// patent is set or the view mode is set to Tree or to Hierarchical list.
	If Information.HasParent And RepresentedAsList And Not AdjustedFilters.HasFilterByParent Then
		Return NStr("en = 'Changing the item order require the list view mode to be set to Tree or Hierarchical list.'");
	EndIf;
	
	// For child catalogs, the filter by owner must be set. 
	If Information.HasOwner And Not AdjustedFilters.HasFilterByOwner Then
		Return NStr("en = 'Changing the item order require a filter by owner'");
	EndIf;
	
	// Checking whether the selected item has the additional ordering attribute
	If Information.HasFolders Then
		IsFolder = CommonUse.GetAttributeValue(Ref, "IsFolder");
		If IsFolder And Not Information.ForFolders Then
			// Order cannot be set for a folder
			Return "";
		ElsIf Not IsFolder And Not Information.ForItems Then
			// Order cannot be set for an item
			Return "";
		EndIf;
	EndIf;
	
	Query = New Query;
	QueryConditions = New Array;
	
	// Adding a query condition by parent
	If Information.HasParent Then
		QueryConditions.Add("Table.Parent = &Parent");
		Query.SetParameter("Parent", CommonUse.GetAttributeValue(Ref, "Parent"));
	EndIf;
	
	// Adding a query condition by owner
	If Information.HasOwner Then
		QueryConditions.Add("Table.Owner = &Owner");
		Query.SetParameter("Owner", CommonUse.GetAttributeValue(Ref, "Owner"));
	EndIf;
	
	// Adding a query condition by folder
	If Information.HasFolders Then
		If Information.ForFolders And Not Information.ForItems Then
			QueryConditions.Add("Table.IsFolder");
		ElsIf Not Information.ForFolders And Information.ForItems Then
			QueryConditions.Add("NOT Table.IsFolder");
		EndIf;
	EndIf;
	
	// Preparing the condition string
	AdditionalConditions = "TRUE";
	For Each Condition In QueryConditions Do
		AdditionalConditions = AdditionalConditions + " AND " + Condition;
	EndDo;
	
	QueryText = 
	"SELECT
	|	Table.Ref,
	|	Table.AdditionalOrderingAttribute AS OrderOld,
	|	Table.AdditionalOrderingAttribute AS OrderNew
	|FROM
	|	&Table AS Table
	|WHERE
	|	&AdditionalConditions
	|
	|ORDER BY
	|	Table.AdditionalOrderingAttribute";
	
	QueryText = StrReplace(QueryText, "&Table", Ref.Metadata().FullName());
	QueryText = StrReplace(QueryText, "&AdditionalConditions", AdditionalConditions);
	
	Query.Text = QueryText;
	OrderingTable = Query.Execute().Unload();
	
	RowToMove = OrderingTable.Find(Ref, "Ref");
	If RowToMove = Undefined Then
		Return "";
	EndIf;
	
	Offset = ?(MoveUp, -1, 1);
	
	NeighborRowIndex = OrderingTable.IndexOf(RowToMove) + Offset;
	If Not((0 <= NeighborRowIndex) And (NeighborRowIndex < OrderingTable.Count())) Then
		Return "";
	EndIf;
	
	NeighborRow = OrderingTable[NeighborRowIndex];
	
	RowToMove.OrderNew = NeighborRow.OrderOld;
	NeighborRow.OrderNew = RowToMove.OrderOld;
	
	OrderingTable.Move(RowToMove, Offset);
	
	PreviousOrder = 0;
	
	BeginTransaction();
	
	Try
		
		For Each CurrentRow In OrderingTable Do
			
			If PreviousOrder >= CurrentRow.OrderNew Then
				CurrentRow.OrderNew = PreviousOrder + 1;
			EndIf;
			
			PreviousOrder = CurrentRow.OrderNew;
			
			If CurrentRow.OrderNew <> CurrentRow.OrderOld Then
				Object = CurrentRow.Ref.GetObject();
				LockDataForEdit(Object.Ref);
				Object.AdditionalOrderingAttribute = CurrentRow.OrderNew;
				Object.Write();
			EndIf;
			
		EndDo;
		
		CommitTransaction();
		
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	Return "";
	
EndFunction

// Returns structure that contains metadata object details.
//
// Parameters:
//  Ref - object reference.
//
// Returns:
//  Structure - metadata object details.
//
Function GetMetadataToMoveInfo(Ref) Export
	
	Information = New Structure;
	
	ObjectMetadata = Ref.Metadata();
	AttributeMetadata = ObjectMetadata.Attributes.AdditionalOrderingAttribute;
	
	Information.Insert("FullName", ObjectMetadata.FullName());
	
	IsCatalog = Metadata.Catalogs.Contains(ObjectMetadata);
	IsCCT = Metadata.ChartsOfCharacteristicTypes.Contains(ObjectMetadata);
	
	If IsCatalog Or IsCCT Then
		
		Information.Insert("HasFolders",
					ObjectMetadata.Hierarchical And 
							?(IsCCT, True, ObjectMetadata.HierarchyType = Metadata.ObjectProperties.HierarchyType.HierarchyFoldersAndItems));
		
		Information.Insert("ForFolders", (AttributeMetadata.Use <> Metadata.ObjectProperties.AttributeUse.ForItem));
		Information.Insert("ForItems", (AttributeMetadata.Use <> Metadata.ObjectProperties.AttributeUse.ForFolder));
		Information.Insert("HasParent", ObjectMetadata.Hierarchical);
		Information.Insert("FoldersOnTop", ?(Not Information.HasParent, False, ObjectMetadata.FoldersOnTop));
		Information.Insert("HasOwner", ?(IsCCT, False, (ObjectMetadata.Owners.Count() <> 0)));
		
	Else
		
		Information.Insert("HasFolders", False);
		Information.Insert("ForFolders", False);
		Information.Insert("ForItems", True);
		Information.Insert("HasParent", False);
		Information.Insert("HasOwner", False);
		Information.Insert("FoldersOnTop", False);
		
	EndIf;
	
	Return Information;
	
EndFunction

// Retrieves additional ordering attribute for a new object.
//
// Parameters:
//  Information - Structure - metadata object details;
//  Parent - Ref - parent object reference;
//  Owner - Ref - owner object reference.
//
// Returns:
// Number - additional ordering attribute.
//
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
		AdditionalConditions = AdditionalConditions + " AND " + Condition;
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
	
	Selection = Query.Execute().Choose();
	Selection.Next();
	
	Return ?(Not ValueIsFilled(Selection.AdditionalOrderingAttribute), 1, Selection.AdditionalOrderingAttribute + 1);
	
EndFunction
