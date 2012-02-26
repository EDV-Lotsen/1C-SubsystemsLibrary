

////////////////////////////////////////////////////////////////////////////////
// EXPORT PROCEDURES AND FUNCTIONS

// Handler of command "Move up" of a list form
Procedure ShiftItemUp(ListAttribute, ListItem) Export
	
	ShiftItem(ListAttribute, ListItem, True);
	
EndProcedure

// Handler of command "Move down" of a list form
Procedure ShiftItemDown(ListAttribute, ListItem) Export
	
	ShiftItem(ListAttribute, ListItem, False);
	
EndProcedure



////////////////////////////////////////////////////////////////////////////////
// AUXILIARY PROCEDURES AND FUNCTIONS

// Execute move operation or order restore operation
Procedure ShiftItem(ListAttribute, ListItem, Up)
	
	AppliedFilters = New Structure;
	
	If Not CheckListBeforeOperation(ListAttribute, ListItem, AppliedFilters) Then
		Return;
	EndIf;
	
	Ref = ListItem.CurrentRow;
	RepresentationListView = (ListItem.Representation = TableRepresentation.List);
	
	StrError = ItemOrderSetup.ChangeItemsOrder(Ref, AppliedFilters, RepresentationListView, Up);
		
	If StrError = "" Then
		ListItem.Refresh();
	Else
		DoMessageBox(StrError);
	EndIf;
	
EndProcedure

// Check list settings before executing the operation
Function CheckListBeforeOperation(ListAttribute, ListItem, AppliedFilters)
	
	// Check if current data is assigned
	If ListItem.CurrentData = Undefined Then
		Return False;
	EndIf;
	
	// Check applied sort order
	If Not ListSortingIsSetProperly(ListAttribute) Then
		DoMessageBox(NStr("en = 'Prior to change items order it is necessary to set the additional ordering filter ascending'"));
		Return False;
	EndIf;
	
	// Check applied filters
	If Not CheckFiltersSetInList(ListAttribute, AppliedFilters) Then
		DoMessageBox(NStr("en = 'The filter in list is not set properly.'"));
		Return False;
	EndIf;
	
	For Each GroupingItem In ListAttribute.Group.Items Do
		If GroupingItem.Use Then
			DoMessageBox(NStr("en = 'The current grouping does not allow to change items order.'"));
			Return False;
		EndIf;
	EndDo;
	
	Return True;
	
EndFunction

// Check, is sort order is applied correctly in the list
Function ListSortingIsSetProperly(ListAttribute)
	
	OrderItems = ListAttribute.Order.Items;
	
	// Find first used order item
	Item = Undefined;
	For Each OrderingItem In OrderItems Do
		If OrderingItem.Use Then
			Item = OrderingItem;
			Break;
		EndIf;
	EndDo;
	
	If Item = Undefined Then
		// No ordering is applied
		Return False;
	EndIf;
	
	If TypeOf(Item) = Type("DataCompositionOrderItem") Then
		If Item.OrderType = DataCompositionSortDirection.Asc Then
			AttributeField = New DataCompositionField("AdditionalOrderingAttribute");
			If Item.Field = AttributeField Then
				Return True;
			EndIf;
		EndIf;
	EndIf;
	
	Return False;
	
EndFunction

// Get information about applied filters and partially check them
Function CheckFiltersSetInList(ListAttribute, AppliedFilters)
	
	AppliedFilters.Insert("IsFilterByParent",  False);
	AppliedFilters.Insert("IsFilterByOwner", False);
	
	FieldParent1 = New DataCompositionField("Parent");
	FieldParent2 = New DataCompositionField("Parent");
	FieldOwner1  = New DataCompositionField("Owner");
	FieldOwner2  = New DataCompositionField("Owner");
	
	For Each Filter In ListAttribute.Filter.Items Do
		
		If Not Filter.Use Then
			// Filter is not applied
			Continue;
		ElsIf TypeOf(Filter) <> Type("DataCompositionFilterItem") Then
			// Item filter group is not valid
			Return False;
		ElsIf Filter.ComparisonType <> DataCompositionComparisonType.Equal Then
			// Just comparison for equation is valid
			Return False;
		EndIf;
		
		If (Filter.LeftValue = FieldParent1) Or (Filter.LeftValue = FieldParent2) Then
			// Parent filter is applied
			AppliedFilters.IsFilterByParent = True;
		ElsIf (Filter.LeftValue = FieldOwner1) Or (Filter.LeftValue = FieldOwner2) Then
			// Owner filter is applied
			AppliedFilters.IsFilterByOwner = True;
		Else
			// Filter is applied by the attribute, for which it cannot be applied
			Return False;
		EndIf;
		
	EndDo;
	
	Return True;
	
EndFunction
