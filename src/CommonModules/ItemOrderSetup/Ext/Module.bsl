

////////////////////////////////////////////////////////////////////////////////
// EXPORT PROCEDURES AND FUNCTIONS

// Move object up or down
//
// Parameters:
//   Ref      		- Ref                		  - Ref to the item being moved
//   Direction   	- Number                 	  - Direction where the item is moved: -1 - up, +1 - down
//   Filter       	- DataCompositionFilter		  - Filter applied in dynamic list
//   Representation - TableRepresentation 		  - Assigned list of dynamic list representation
//   StrError   	- String                  	  - On error description is returned
//
//
Function ChangeItemsOrder(Ref, AppliedFilters, RepresentationListView, Up) Export
	
	Information = GetMetadataSummaryForOrdering(Ref);
	
	// Filter by parent may be applied for hierarchical catalogs, if not,
	// then representation mode should be equal to hierarchical or tree view
	If Information.HaveParent And RepresentationListView And Not AppliedFilters.IsFilterByParent Then
		Return NStr("en = 'Prior to change the order it is necessary to set the presentation to tree view or hierarchical list!'");
	EndIf;
	
	// Filter by owner should be applied for subordinate catalogs
	If Information.HaveOwner And Not AppliedFilters.IsFilterByOwner Then
		Return NStr("en = 'Prior to change the order it is necessary to set the filter by owner.'");
	EndIf;
	
	// Check, if selected object has addit. ordering attribute
	If Information.ContainsGroups Then
		IsFolder = CommonUse.GetAttributeValue(Ref, "IsFolder");
		If IsFolder And Not Information.ForGroups Then
			// This is a group, but for group ordering is not set
			Return "";
		ElsIf Not IsFolder And Not Information.ForItems Then
			// This is an item, but for items ordering is not set
			Return "";
		EndIf;
	EndIf;
	
	Query = New Query;
	ConditionsArray = New Array;
	
	// Add filter by parent
	If Information.HaveParent Then
		ConditionsArray.Add("Table.Parent = &Parent");
		Query.SetParameter("Parent", CommonUse.GetAttributeValue(Ref, "Parent"));
	EndIf;
	
	// Add filter by owner
	If Information.HaveOwner Then
		ConditionsArray.Add("Table.Owner = &Owner");
		Query.SetParameter("Owner", CommonUse.GetAttributeValue(Ref, "Owner"));
	EndIf;
	
	// Add filter by group
	If Information.ContainsGroups Then
		If Information.ForGroups And Not Information.ForItems Then
			ConditionsArray.Add("Table.IsFolder");
		ElsIf Not Information.ForGroups And Information.ForItems Then
			ConditionsArray.Add("NOT Table.IsFolder");
		EndIf;
	EndIf;
	
	// Compose string with all the filters
	StrConditions = "";
	StrAddition = "
	|WHERE
	|	";
	For Each Condition In ConditionsArray Do
		StrConditions = StrConditions + StrAddition + Condition;
		StrAddition   = "
		|	And ";
	EndDo;
	
	// Compose query text
	QueryText = 
	"SELECT
	|	Table.Ref,
	|	Table.AdditionalOrderingAttribute AS OrderOld,
	|	Table.AdditionalOrderingAttribute AS SequenceNew
	|FROM
	|	" + Ref.Metadata().FullName() + " AS Table
	|" + StrConditions + "
	|
	|ORDER BY
	|	AdditionalOrderingAttribute";
	
	
	Query.Text = QueryText;
	TabItems = Query.Execute().Unload();
	
	Row1 = TabItems.Find(Ref, "Ref");
	If Row1 = Undefined Then
		Return "";
	EndIf;
	
	BeforeAfter = ?(Up, -1, 1);
	Index1 		= TabItems.IndexOf(Row1);
	Index2 		= Index1 + BeforeAfter;
	If (Index2 < 0) OR (Index2 >= TabItems.Count()) Then
		Return "";
	EndIf;
	Row2 = TabItems[Index2];
	
	Row1.SequenceNew = Row2.OrderOld;
	Row2.SequenceNew = Row1.OrderOld;
	
	TabItems.Move(Row1, BeforeAfter);
	
	PrevOrder = 0;
	
	BeginTransaction();
	
	Try
		
		For Each Row In TabItems Do
			
			If PrevOrder >= Row.SequenceNew Then
				Row.SequenceNew = PrevOrder + 1;
			EndIf;
			
			PrevOrder = Row.SequenceNew;
			
			If Row.SequenceNew <> Row.OrderOld Then
				Object = Row.Ref.GetObject();
				LockDataForEdit(Object.Ref);
				Object.AdditionalOrderingAttribute = Row.SequenceNew;
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

// Get structure with information about object metadata
Function GetMetadataSummaryForOrdering(Ref) Export
	
	Information = New Structure;
	
	ObjectMetadata 	  = Ref.Metadata();
	AttributeMetadata = ObjectMetadata.Attributes.AdditionalOrderingAttribute;
	
	Information.Insert("FullName", ObjectMetadata.FullName());
	
	MetadataObjectIsCatalog = Metadata.Catalogs.Contains(ObjectMetadata);
	ThisIsCCT = Metadata.ChartsOfCharacteristicTypes.Contains(ObjectMetadata);
	
	If MetadataObjectIsCatalog Or ThisIsCCT Then
		
		Information.Insert("ContainsGroups",
			ObjectMetadata.Hierarchical
			And ?(ThisIsCCT, True, ObjectMetadata.HierarchyType = Metadata.ObjectProperties.HierarchyType.HierarchyFoldersAndItems));
		Information.Insert("ForGroups",     (AttributeMetadata.Use <> Metadata.ObjectProperties.AttributeUse.ForItem));
		Information.Insert("ForItems", 		(AttributeMetadata.Use <> Metadata.ObjectProperties.AttributeUse.ForFolder));
		Information.Insert("HaveParent",  	ObjectMetadata.Hierarchical);
		Information.Insert("FoldersOnTop",  ?(Not Information.HaveParent, False, ObjectMetadata.FoldersOnTop));
		Information.Insert("HaveOwner", 	?(ThisIsCCT, False, (ObjectMetadata.Owners.Count() <> 0)));
		
	Else
		
		Information.Insert("ContainsGroups", False);
		Information.Insert("ForGroups",      False);
		Information.Insert("ForItems", 	 	 True);
		Information.Insert("HaveParent", 	 False);
		Information.Insert("HaveOwner", 	 False);
		Information.Insert("FoldersOnTop",   False);
		
	EndIf;
	
	Return Information;
	
EndFunction

