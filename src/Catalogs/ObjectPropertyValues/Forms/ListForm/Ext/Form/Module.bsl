
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	If Parameters.ChoiceMode Then
		PurposeUseKey = "SelectionPick";
		WindowOptionsKey = "SelectionPick";
		WindowOpeningMode = FormWindowOpeningMode.LockOwnerWindow;
	EndIf;
	
	If Parameters.Filter.Property("Owner") Then
		Property = Parameters.Filter.Owner; 
		Parameters.Filter.Delete("Owner");
	EndIf;
	
	If Not ValueIsFilled(Property) Then 
		Items.Property.Visible = True;
		SetValueOrderByProperties(List);
	EndIf;
	
	If Parameters.ChoiceMode Then
		
		CommonUseClientServer.SetDynamicListFilterItem(
			List, "DeletionMark", False, , , True,
			DataCompositionSettingsItemViewMode.Normal);
		
		If Parameters.Property("ChoiceFoldersAndItems")
		   And Parameters.ChoiceFoldersAndItems = FoldersAndItemsUse.Folders Then
			
			GroupChoice = True;
 
			CommonUseClientServer.SetDynamicListFilterItem(List, "IsFolder", True);
		Else
			Parameters.ChoiceFoldersAndItems = FoldersAndItemsUse.Items;
		EndIf;
	Else
		Items.List.ChoiceMode = False;
	EndIf;
	
	SetTitle();
	
	If GroupChoice Then
		If Items.Find("FormCreate") <> Undefined Then
			Items.FormCreate.Visible = False;
			Items.ListContextMenuCreate.Visible = False;
		EndIf;
	EndIf;
	
	OnPropertyChange();
	
	CommonUseClientServer.MoveFiltersToDynamicList(ThisObject);
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Write_AdditionalDataAndAttributes"
	   And (   Source = Property
	        Or Source = AdditionalValueOwner) Then
		
		AttachIdleHandler("OnPropertyChangeIdleHandler", 0.1, True);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure PropertyOnChange(Item)
	
	OnPropertyChange();
	
EndProcedure

#EndRegion

#Region FormTableListItemEventHandlers

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Clone, Parent, Group)
	
	If Not Clone
	   And Items.List.Representation = TableRepresentation.List Then
		
		Parent = Undefined;
	EndIf;
	
	If GroupChoice
	   And Not Group Then
		
		Cancel = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure ListBeforeRowChange(Item, Cancel)
	
	Cancel = True;
	
	If Items.List.CurrentRow <> Undefined Then
		// Opening value or value set form.
		FormParameters = New Structure;
		FormParameters.Insert("HideOwner", True);
		FormParameters.Insert("ShowWeight", AdditionalValuesWithWeight);
		FormParameters.Insert("Key", Items.List.CurrentRow);
		
		OpenForm("Catalog.ObjectPropertyValues.ObjectForm", FormParameters, Items.List);
	EndIf;
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure SetValueOrderByProperties(List)
	
	Var Order;
	
	// Order.
	Order = List.SettingsComposer.Settings.Order;
	Order.UserSettingID = "DefaultOrder";
	
	Order.Items.Clear();
	
	OrderItem = Order.Items.Add(Type("DataCompositionOrderItem"));
	OrderItem.Field = New DataCompositionField("Owner");
	OrderItem.OrderType = DataCompositionSortDirection.Asc;
	OrderItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	OrderItem.Use = True;
	
	OrderItem = Order.Items.Add(Type("DataCompositionOrderItem"));
	OrderItem.Field = New DataCompositionField("IsFolder");
	OrderItem.OrderType = DataCompositionSortDirection.Desc;
	OrderItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	OrderItem.Use = True;
	
	OrderItem = Order.Items.Add(Type("DataCompositionOrderItem"));
	OrderItem.Field = New DataCompositionField("Description");
	OrderItem.OrderType = DataCompositionSortDirection.Asc;
	OrderItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	OrderItem.Use = True;
	
EndProcedure

&AtServer
Procedure SetTitle()
	
	TitleString = "";
	
	If ValueIsFilled(Property) Then
		TitleString = CommonUse.ObjectAttributeValue(
			Property, "ValueChoiceFormTitle");
	EndIf;
	
	If IsBlankString(TitleString) Then
		
		If ValueIsFilled(Property) Then
			If Not Parameters.ChoiceMode Then
				TitleString = NStr("en = 'Property values %1'");
			ElsIf GroupChoice Then
				TitleString = NStr("en = 'Select the value group of the %1 property'");
			Else
				TitleString = NStr("en = 'Select the value of the %1 property'");
			EndIf;
			
			TitleString = StringFunctionsClientServer.SubstituteParametersInString(
				TitleString, String(CommonUse.ObjectAttributeValue(
					Property, "Title")));
		
		ElsIf Parameters.ChoiceMode Then
			
			If GroupChoice Then
				TitleString = NStr("en = 'Select the property value group'");
			Else
				TitleString = NStr("en = 'Select the property value'");
			EndIf;
		EndIf;
	EndIf;
	
	If Not IsBlankString(TitleString) Then
		AutoTitle = False;
		Title = TitleString;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnPropertyChangeIdleHandler()
	
	OnPropertyChange();
	
EndProcedure

&AtServer
Procedure OnPropertyChange()
	
	If ValueIsFilled(Property) Then
		
		AdditionalValueOwner = CommonUse.ObjectAttributeValue(
			Property, "AdditionalValueOwner");
		
		If ValueIsFilled(AdditionalValueOwner) Then
			ReadOnly = True;
			
			ValueType = CommonUse.ObjectAttributeValue(
				AdditionalValueOwner, "ValueType");
			
			CommonUseClientServer.SetDynamicListFilterItem(
				List, "Owner", AdditionalValueOwner);
			
			AdditionalValuesWithWeight = CommonUse.ObjectAttributeValue(
				AdditionalValueOwner, "AdditionalValuesWithWeight");
		Else
			ReadOnly = False;
			ValueType = CommonUse.ObjectAttributeValue(Property, "ValueType");
			
			CommonUseClientServer.SetDynamicListFilterItem(
				List, "Owner", Property);
			
			AdditionalValuesWithWeight = CommonUse.ObjectAttributeValue(
				Property, "AdditionalValuesWithWeight");
		EndIf;
		
		If TypeOf(ValueType) = Type("TypeDescription")
		   And ValueType.ContainsType(Type("CatalogRef.ObjectPropertyValues")) Then
			
			Items.List.ChangeRowSet = True;
		Else
			Items.List.ChangeRowSet = False;
		EndIf;
		
		Items.List.Representation = TableRepresentation.HierarchicalList;
		Items.Owner.Visible = False;
		Items.Weight.Visible = AdditionalValuesWithWeight;
	Else
		CommonUseClientServer.DeleteDynamicListFilterCroupItems(
			List, "Owner");
		
		Items.List.Representation = TableRepresentation.List;
		Items.List.ChangeRowSet = False;
		Items.Owner.Visible = True;
		Items.Weight.Visible = False;
	EndIf;
	
	Items.List.Header = Items.Owner.Visible Or Items.Weight.Visible;
	
EndProcedure

#EndRegion
