
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
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
	Else
		Items.List.ChoiceMode = False;
	EndIf;
	
	SetTitle();
	
	OnPropertyChange();
	
	CommonUseClientServer.MoveFiltersToDynamicList(ThisObject);
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Write_AdditionalDataAndAttributes"
	   And Source = Property Then
		
		AttachIdleHandler("IdleHandlerOnPropertyChange", 0.1, True);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure PropertyOnChange(Item)
	
	OnPropertyChange();
	
EndProcedure

#EndRegion

#Region ListFormTableItemEventHandlers

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Clone, Parent, Group)
	
	If Not Clone
	   And Items.List.Representation = TableRepresentation.List Then
		
		Parent = Undefined;
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
				TitleString = NStr("en = '%1 property values'");
			Else
				TitleString = NStr("en = 'Select %1 property value'");
			EndIf;
			
			TitleString = StringFunctionsClientServer.SubstituteParametersInString(
				TitleString, String(Property));
		
		ElsIf Parameters.ChoiceMode Then
			TitleString = NStr("en = 'Select the property value'");
		EndIf;
	EndIf;
	
	If Not IsBlankString(TitleString) Then
		AutoTitle = False;
		Title = TitleString;
	EndIf;
	
EndProcedure

&AtClient
Procedure IdleHandlerOnPropertyChange()
	
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
