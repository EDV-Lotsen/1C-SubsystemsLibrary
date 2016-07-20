
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	If Parameters.IsAdditionalData <> Undefined Then
		IsAdditionalData = Parameters.IsAdditionalData;
		
		CommonUseClientServer.SetDynamicListFilterItem(
			List, "IsAdditionalData", IsAdditionalData, , , True);
	EndIf;
	
	// Applying a filter that excludes items marked for deletion.
	CommonUseClientServer.SetDynamicListFilterItem(
		List, "DeletionMark", False, , , True,
		DataCompositionSettingsItemViewMode.Normal);
	
	If Parameters.CommonPropertySelection Then
		
		SelectionKind = "CommonPropertySelection";
		
		CommonUseClientServer.SetDynamicListFilterItem(
			List, "PropertySet", , DataCompositionComparisonType.NotFilled, , True);
		
		If IsAdditionalData = True Then
			AutoTitle = False;
			Title = NStr("en = 'Common custom data selection'");
		ElsIf IsAdditionalData = False Then
			AutoTitle = False;
			Title = NStr("en = 'Common custom field selection'");
		EndIf;
		
	ElsIf Parameters.AdditionalValueOwnerSelection Then
		
		SelectionKind = "AdditionalValueOwnerSelection";
		
		CommonUseClientServer.SetDynamicListFilterItem(
			List, "PropertySet", , DataCompositionComparisonType.Filled, , True);
		
		CommonUseClientServer.SetDynamicListFilterItem(
			List, "AdditionalValuesUsed", True, , , True);
		
		CommonUseClientServer.SetDynamicListFilterItem(
			List, "AdditionalValueOwner", ,
			DataCompositionComparisonType.NotFilled, , True);
		
		AutoTitle = False;
		Title = NStr("en = 'Sample selection'");
		
		Items.FormCreate.Visible = False;
		Items.FormCopy.Visible = False;
		Items.FormChange.Visible = False;
		Items.FormSetDeletionMark.Visible = False;
		
		Items.ListContextMenuCreate.Visible = False;
		Items.ListContextMenuCopy.Visible = False;
		Items.ListContextMenuChange.Visible = False;
		Items.ListContextMenuSetDeletionMark.Visible = False;
	EndIf;
	FillSelectedValues();
	
	CommonUseClientServer.SetDynamicListParameter(
		List,
		"CommonPropertyGroupingPresentation",
		NStr("en = 'Common (for several sets)'"),
		True);
	
	// Grouping properties to sets.
	DataGroup = List.SettingsComposer.Settings.Structure.Add(Type("DataCompositionGroup"));
	DataGroup.UserSettingID = "PropertiesBySetsGroup";
	DataGroup.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	
	GroupFields = DataGroup.GroupFields;
	
	DataGroupItem = GroupFields.Items.Add(Type("DataCompositionGroupField"));
	DataGroupItem.Field = New DataCompositionField("PropertySetGrouping");
	DataGroupItem.Use = True;
	
	CommonUseClientServer.MoveFiltersToDynamicList(ThisObject);
EndProcedure

#EndRegion

#Region ListFormTableItemEventHandlers

&AtClient
Procedure ListValueChoice(Item, Value, StandardProcessing)
	
	If SelectionKind = "CommonPropertySelection" Then
		StandardProcessing = False;
		NotifyChoice(New Structure("CommonProperty", Value));
		
	ElsIf SelectionKind = "AdditionalValueOwnerSelection" Then
		StandardProcessing = False;
		NotifyChoice(New Structure("AdditionalValueOwner", Value));
	EndIf;
	
EndProcedure

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Clone)
	
	Cancel = True;
	
	If Not Items.FormCreate.Visible Then
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("IsAdditionalData", IsAdditionalData);
	
	If Clone Then
		FormParameters.Insert("CopyingValue", Item.CurrentRow);
	Else
		FillingValues = New Structure;
		FormParameters.Insert("FillingValues", FillingValues);
	EndIf;
	
	OpenForm("ChartOfCharacteristicTypes.AdditionalDataAndAttributes.ObjectForm", FormParameters);
	
EndProcedure

&AtClient
Procedure ListBeforeRowChange(Item, Cancel)
	
	Cancel = True;
	
	If Not Items.FormCreate.Visible Then
		Return;
	EndIf;
	
	If Item.CurrentData <> Undefined Then
		
		FormParameters = New Structure;
		FormParameters.Insert("Key", Item.CurrentRow);
		FormParameters.Insert("IsAdditionalData", IsAdditionalData);
		
		OpenForm("ChartOfCharacteristicTypes.AdditionalDataAndAttributes.ObjectForm", FormParameters);
	EndIf;
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure FillSelectedValues()
	
	If Parameters.Property("SelectedValues")
	   And TypeOf(Parameters.SelectedValues) = Type("Array") Then
		
		SelectedItemList.LoadValues(Parameters.SelectedValues);
	EndIf;
	
	ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
	
	AppearanceColorItem = ConditionalAppearanceItem.Appearance.Items.Find("Font");
	AppearanceColorItem.Value = New Font(, , True);
	AppearanceColorItem.Use = True;
	
	DataFilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue  = New DataCompositionField("List.Ref");
	DataFilterItem.ComparisonType   = DataCompositionComparisonType.InList;
	DataFilterItem.RightValue = SelectedItemList;
	DataFilterItem.Use  = True;
	
	FieldAppearanceItem = ConditionalAppearanceItem.Fields.Items.Add();
	FieldAppearanceItem.Field = New DataCompositionField("Presentation");
	FieldAppearanceItem.Use = True;
	
EndProcedure

#EndRegion