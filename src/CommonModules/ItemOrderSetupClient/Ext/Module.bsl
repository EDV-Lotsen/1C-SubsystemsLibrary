////////////////////////////////////////////////////////////////////////////////
// Item order setup subsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// "Move up" сommand handler of the list form.
//
// Parameters:
//  ListFormAttribute - DynamicList - form attribute that contains a list.
//  ListFormItem      - FormTable   - form item that contains a list.
//
Procedure MoveItemUpExecute(ListFormAttribute, ListFormItem) Export
	
	MoveItem(ListFormAttribute, ListFormItem, "Up");
	
EndProcedure

// "Move down" command handler of the list form.
//
// Parameters:
//  ListFormAttribute - DynamicList - form attribute that contains a list.
//  ListFormItem      - FormTable   - form item that contains a list.
//
Procedure MoveItemDownExecute(ListFormAttribute, ListFormItem) Export
	
	MoveItem(ListFormAttribute, ListFormItem, "Down");
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

Procedure MoveItem(ListAttribute, ListItem, Direction)
	
If ListItem.CurrentData = Undefined Then
		Return;
	EndIf;
	
	Parameters = New Structure;
	Parameters.Insert("ListAttribute", ListAttribute);
	Parameters.Insert("ListItem", ListItem);
	Parameters.Insert("Direction", Direction);
	
	NotifyDescription = New NotifyDescription("MoveItemCheckingDone", ThisObject, Parameters);
	
	CheckListBeforeAction(NotifyDescription, ListAttribute);
	
EndProcedure

Procedure MoveItemCheckingDone(CheckResult, AdditionalParameters) Export
	
	If CheckResult <> True Then
		Return;
	EndIf;
	

  ListItem = AdditionalParameters.ListItem;
	ListAttribute = AdditionalParameters.ListAttribute;
	Direction = AdditionalParameters.Direction;
	
	ListView = (ListItem.Representation = TableRepresentation.List);
	
	ErrorText = ItemOrderSetupInternalServerCall.ChangeItemOrder(
	ListItem.CurrentData.Ref, ListAttribute, ListView, Direction);
		
	If Not IsBlankString(ErrorText) Then
		ShowMessageBox(, ErrorText);
	EndIf;
	
	ListItem.Refresh();
	
EndProcedure

Procedure CheckListBeforeAction(ResultHandler, ListAttribute)
	
	Parameters = New Structure;
	Parameters.Insert("ResultHandler", ResultHandler);
	Parameters.Insert("ListAttribute", ListAttribute);
	
	If Not IsListSortingCorrect(ListAttribute) Then
		QuestionText = NStr("en = 'To change the item order, you have
								|to configure the list order using the ""Order"" field. Do you want to configure the order?'");
		NotifyDescription = New NotifyDescription("CheckListBeforeActionAnswerToSortReceived", ThisObject, Parameters);
		Buttons = New ValueList;
		Buttons.Add(DialogReturnCode.Yes, NStr("en = 'Configure'"));
		Buttons.Add(DialogReturnCode.No, NStr("en = 'Skip'"));
		ShowQueryBox(NotifyDescription, QuestionText, Buttons, , DialogReturnCode.Yes);
		Return;
	EndIf;
	
	MoveItemCheckingDone(True, ResultHandler.AdditionalParameters);
	
EndProcedure

Procedure CheckListBeforeActionAnswerToSortReceived(ResponseResult, AdditionalParameters) Export
	
	If ResponseResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	ListAttribute = AdditionalParameters.ListAttribute;
	
	UserOrderSettings = Undefined;
	For Each Item In ListAttribute.SettingsComposer.UserSettings.Items Do
		If TypeOf(Item) = Type("DataCompositionOrder") Then
			UserOrderSettings = Item;
			Break;
		EndIf;
	EndDo;
	
	CommonUseClientServer.Validate(UserOrderSettings <> Undefined, NStr("en = 'The user setting for the order is not found.'"));
	
	UserOrderSettings.Items.Clear();
	Item = UserOrderSettings.Items.Add(Type("DataCompositionOrderItem"));
	Item.Use = True;
	Item.Field = New DataCompositionField("AdditionalOrderingAttribute");
	Item.OrderType = DataCompositionSortDirection.Asc;
	
EndProcedure

Function IsListSortingCorrect(List)
	
	UserOrderSettings = Undefined;
	For Each Item In List.SettingsComposer.UserSettings.Items Do
		If TypeOf(Item) = Type("DataCompositionOrder") Then
			UserOrderSettings = Item;
			Break;
		EndIf;
	EndDo;
	
	If UserOrderSettings = Undefined Then
		Return True;
	EndIf;
	
	OrderItems = UserOrderSettings.Items;
	
	// Find the first used order item
	Item = Undefined;
	For Each OrderItem In OrderItems Do
		If OrderItem.Use Then
			Item = OrderItem;
			Break;
		EndIf;
	EndDo;
	
	If Item = Undefined Then
		// No sorting set
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

#EndRegion
