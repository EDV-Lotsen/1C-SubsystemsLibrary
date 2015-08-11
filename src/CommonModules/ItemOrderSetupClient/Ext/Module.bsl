////////////////////////////////////////////////////////////////////////////////
// Item order setup subsystem.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// The handler of the Move up command of the list form.
//
// Parameters:
//  ListFormAttribute - DynamicList - form attribute that contains a list;
//  ListFormItem - FormTable - form item that contains a list.
//
Procedure MoveItemUpExecute(ListFormAttribute, ListFormItem) Export
	
	MoveItemExecute(ListFormAttribute, ListFormItem, True);
	
EndProcedure

// The handler of the Move down command of the list form.
//
// Parameters:
//  ListFormAttribute - DynamicList - form attribute that contains a list;
//  ListFormItem - FormTable - form item that contains a list.
//
Procedure MoveItemDownExecute(ListFormAttribute, ListFormItem) Export
	
	MoveItemExecute(ListFormAttribute, ListFormItem, False);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

Procedure MoveItemExecute(ListAttribute, ListItem, Up)
	
	AdjustedFilters = New Structure;
	
	If Not CheckListBeforeAction(ListAttribute, ListItem, AdjustedFilters) Then
		Return;
	EndIf;
	
	ListView = (ListItem.Representation = TableRepresentation.List);
	
	ErrorText = ItemOrderSetup.ChangeItemOrder(
								ListItem.CurrentData.Ref,
								AdjustedFilters,
								ListView,
								Up);
		
	If IsBlankString(ErrorText) Then
		ListItem.Refresh();
	Else
		ShowMessageBox(, ErrorText);
	EndIf;
	
EndProcedure

Function CheckListBeforeAction(ListAttribute, ListItem, AdjustedFilters)
	
	// Checking whether the current data is defined
	If ListItem.CurrentData = Undefined Then
		Return False;
	EndIf;
	
	// Checking whether an order is set
	If Not IsListSortingCorrect(ListAttribute) Then
		ShowMessageBox(, NStr("en = 'If you want to change the item order, you have to configure
								 |the list order in the following way: the Order field with order kind   
								 |set to Ascending must be the first row of the order table.'"));
		Return False;
	EndIf;
	
	// Checking whether filters are set
	If Not CheckFiltersSetInList(ListAttribute, AdjustedFilters) Then
		ShowMessageBox(, NStr("en = 'If you want to change the item order, you have to clear all 
								 |filters, except filters by owner and by folder.'"));
		Return False;
	EndIf;
	
	For Each GroupItem In ListAttribute.Group.Items Do
		If GroupItem.Use Then
			ShowMessageBox(, NStr("en = 'If you want to change the item order, you have to clear using groups.'"));
			Return False;
		EndIf;
	EndDo;
	
	Return True;
	
EndFunction

Function IsListSortingCorrect(ListAttribute)
	
	OrderItems = ListAttribute.Order.Items;
	
	// Finding the first order item that is used
	Item = Undefined;
	For Each OrderingItem In OrderItems Do
		If OrderingItem.Use Then
			Item = OrderingItem;
			Break;
		EndIf;
	EndDo;
	
	If Item = Undefined Then
		// The order is not set
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

Function CheckFiltersSetInList(ListAttribute, AdjustedFilters)
	
	AdjustedFilters.Insert("HasFilterByParent", False);
	AdjustedFilters.Insert("HasFilterByOwner", False);
	
	ParentField1 = New DataCompositionField("Parent");
	OwnerField1 = New DataCompositionField("Owner");
	
	For Each Filter In ListAttribute.Filter.Items Do
		
		If Not Filter.Use Then
			// The filter is not set
			Continue;
		ElsIf TypeOf(Filter) <> Type("DataCompositionFilterItem") Then
			// Incorrect filter item type
			Return False;
		ElsIf Filter.ComparisonType <> DataCompositionComparisonType.Equal Then
			// Equal is the only one allowed comparison type
			Return False;
		EndIf;
		
		If Filter.LeftValue = ParentField1 Then
			// The filter by parent is set
			AdjustedFilters.HasFilterByParent = True;
		ElsIf Filter.LeftValue = OwnerField1 Then
			// The filter by owner is set
			AdjustedFilters.HasFilterByOwner = True;
		Else
			// Filters by all other attributes are prohibited while the item order is being changed
			Return False;
		EndIf;
		
	EndDo;
	
	Return True;
	
EndFunction
