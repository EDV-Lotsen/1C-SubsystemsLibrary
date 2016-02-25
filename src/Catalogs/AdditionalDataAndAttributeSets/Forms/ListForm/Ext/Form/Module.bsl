#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the autotest parameter is passed.
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;

	If Parameters.PurposeUseKey = "AdditionalAttributeSets" Then
		WindowOptionsKey = PurposeUseKey;
		Items.IsAdditionalDataSets.Visible = False;
		
	ElsIf Parameters.PurposeUseKey = "AdditionalDataSets" Then
		WindowOptionsKey = PurposeUseKey;
		Items.IsAdditionalDataSets.Visible = False;
		IsAdditionalDataSets = True;
	EndIf;
	
	FormColor = Items.Properties.BackColor;
	
	ApplySetsAndPropertiesAppearance();
	
	UpdateCommandUsage();
	
	UpdateSetAppearance();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Write_AdditionalDataAndAttributes"
	 Or EventName = "Write_ObjectPropertyValues"
	 Or EventName = "Write_ObjectPropertyValueHierarchy" Then
		
		// When writing a property, you must move the property to the appropriate group.
		// When writing a value, you must update the list of the top three values.
		OnCurrentSetChangeAtServer();
		
	ElsIf EventName = "Go_AdditionalDataAndAttributeSets" Then
		// When opening the form for editing a certain metadata object property set, 
		// you must go to the set or the group of sets of this metadata object.
		If TypeOf(Parameter) = Type("Structure") Then
			SelectSpecifiedRows(Parameter);
		EndIf;
		
	ElsIf EventName = "Write_ConstantsSet" Then
		
		If Source = "UseCommonAdditionalValues"
		 Or Source = "UseCommonAdditionalDataAndAttributes" Then
			UpdateCommandUsage();
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure IsAdditionalDataSetsOnChange(Item)
	
	UpdateSetAppearance();
	
EndProcedure

#EndRegion

#Region PropertySetFormTableItemEventHandlers

&AtClient
Procedure PropertySetsOnActivateRow(Item)
	
	AttachIdleHandler("OnCurrentSetChange", 0.1, True);
	
EndProcedure

&AtClient
Procedure PropertySetsBeforeRowChange(Item, Cancel)
	
	Cancel = True;
	
EndProcedure

#EndRegion

#Region PropertyFormTableItemEventHandlers

&AtClient
Procedure PropertiesOnActivateRow(Item)
	
	PropertiesSetCommandAvailability(ThisObject);
	
EndProcedure

&AtClient
Procedure PropertiesBeforeAddRow(Item, Cancel, Clone, Parent, Group)
	
	If Clone Then
		Copy();
	Else
		Create();
	EndIf;
	
	Cancel = True;
	
EndProcedure

&AtClient
Procedure PropertiesBeforeRowChange(Item, Cancel)
	
	Change();
	
	Cancel = True;
	
EndProcedure

&AtClient
Procedure PropertiesBeforeDelete(Item, Cancel)
	
	ChangeDeletionMark();
	
	Cancel = True;
	
EndProcedure

&AtClient
Procedure PropertiesChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	StandardProcessing = False;
	
	If TypeOf(SelectedValue) = Type("Structure") Then
		If SelectedValue.Property("AdditionalValueOwner") Then
			
			FormParameters = New Structure;
			FormParameters.Insert("IsAdditionalData", IsAdditionalDataSets);
			FormParameters.Insert("CurrentPropertySet", CurrentSet);
			FormParameters.Insert("AdditionalValueOwner", SelectedValue.AdditionalValueOwner);
			
			OpenForm("ChartOfCharacteristicTypes.AdditionalDataAndAttributes.ObjectForm",
				FormParameters, Items.Properties);
			
		ElsIf SelectedValue.Property("CommonProperty") Then
			
			ExecuteCommandAtServer("AddCommonProperty", SelectedValue.CommonProperty);
			
			Notify("Write_AdditionalDataAndAttributeSets",
				New Structure("Ref", CurrentSet), CurrentSet);
		Else
			SelectSpecifiedRows(SelectedValue);
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Create(Command = Undefined)
	
	FormParameters = New Structure;
	FormParameters.Insert("PropertySet", CurrentSet);
	FormParameters.Insert("IsAdditionalData", IsAdditionalDataSets);
	FormParameters.Insert("CurrentPropertySet", CurrentSet);
	
	OpenForm("ChartOfCharacteristicTypes.AdditionalDataAndAttributes.ObjectForm",
		FormParameters, Items.Properties);
	
EndProcedure

&AtClient
Procedure CreateBySample(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("ChoiceMode", True);
	FormParameters.Insert("IsAdditionalData", IsAdditionalDataSets);
	FormParameters.Insert("AdditionalValueOwnerSelection", True);
	FormParameters.Insert("CurrentPropertySet", CurrentSet);
	
	OpenForm("ChartOfCharacteristicTypes.AdditionalDataAndAttributes.ChoiceForm",
		FormParameters, Items.Properties);
	
EndProcedure

&AtClient
Procedure CreateCommon(Command)
	
	SelectedValues = New Array;
	FoundRows = Properties.FindRows(New Structure("Common", True));
	For Each Row In FoundRows Do
		SelectedValues.Add(Row.Property);
	EndDo;
	
	FormParameters = New Structure;
	FormParameters.Insert("ChoiceMode", True);
	FormParameters.Insert("IsAdditionalData", IsAdditionalDataSets);
	FormParameters.Insert("CommonPropertySelection", True);
	FormParameters.Insert("CurrentPropertySet", CurrentSet);
	FormParameters.Insert("SelectedValues", SelectedValues);
	
	OpenForm("ChartOfCharacteristicTypes.AdditionalDataAndAttributes.ChoiceForm",
		FormParameters, Items.Properties);
	
EndProcedure

&AtClient
Procedure Change(Command = Undefined)
	
	If Items.Properties.CurrentData <> Undefined Then
		// Open property form.
		FormParameters = New Structure;
		FormParameters.Insert("Key", Items.Properties.CurrentData.Property);
		FormParameters.Insert("CurrentPropertySet", CurrentSet);
		
		OpenForm("ChartOfCharacteristicTypes.AdditionalDataAndAttributes.ObjectForm",
			FormParameters, Items.Properties);
	EndIf;
	
EndProcedure

&AtClient
Procedure Copy(Command = Undefined)
	
	FormParameters = New Structure;
	FormParameters.Insert("CurrentPropertySet", CurrentSet);
	FormParameters.Insert("CopyingValue", Items.Properties.CurrentData.Property);
	
	OpenForm("ChartOfCharacteristicTypes.AdditionalDataAndAttributes.ObjectForm", FormParameters);
	
EndProcedure

&AtClient
Procedure MarkToDelete(Command)
	
	ChangeDeletionMark();
	
EndProcedure

&AtClient
Procedure MoveUp(Command)
	
	ExecuteCommandAtServer("MoveUp");
	
EndProcedure

&AtClient
Procedure MoveDown(Command)
	
	ExecuteCommandAtServer("MoveDown");
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure ApplySetsAndPropertiesAppearance()
	
	// The appearance of the sets root.
	ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
	
	AppearanceColorItem = ConditionalAppearanceItem.Appearance.Items.Find("Text");
	AppearanceColorItem.Value = NStr("en = 'Sets'");
	AppearanceColorItem.Use = True;
	
	DataFilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue = New DataCompositionField("PropertySets.Ref");
	DataFilterItem.ComparisonType = DataCompositionComparisonType.NotFilled;
	DataFilterItem.Use = True;
	
	FieldAppearanceItem = ConditionalAppearanceItem.Fields.Items.Add();
	FieldAppearanceItem.Field = New DataCompositionField("Presentation");
	FieldAppearanceItem.Use = True;
	
	// Appearance of inaccessible set groups that by default are displayed by 
	// the platform as a part of group tree.
	ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
	
	AppearanceColorItem = ConditionalAppearanceItem.Appearance.Items.Find("TextColor");
	AppearanceColorItem.Value = Metadata.StyleItems.InaccessibleDataColor.Value;
	AppearanceColorItem.Use = True;
	
	DataSelectionElementGroup = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	DataSelectionElementGroup.GroupType = DataCompositionFilterItemsGroupType.AndGroup;
	DataSelectionElementGroup.Use = True;
	
	DataFilterItem = DataSelectionElementGroup.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue = New DataCompositionField("PropertySets.Ref");
	DataFilterItem.ComparisonType = DataCompositionComparisonType.NotInList;
	DataFilterItem.RightValue = AvailableSetsList;
	DataFilterItem.Use = True;
	
	DataFilterItem = DataSelectionElementGroup.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue = New DataCompositionField("PropertySets.Parent");
	DataFilterItem.ComparisonType = DataCompositionComparisonType.NotInList;
	DataFilterItem.RightValue = AvailableSetsList;
	DataFilterItem.Use = True;
	
	DataFilterItem = DataSelectionElementGroup.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue = New DataCompositionField("PropertySets.Ref");
	DataFilterItem.ComparisonType = DataCompositionComparisonType.Filled;
	DataFilterItem.Use = True;
	
	FieldAppearanceItem = ConditionalAppearanceItem.Fields.Items.Add();
	FieldAppearanceItem.Field = New DataCompositionField("Presentation");
	FieldAppearanceItem.Use = True;
	
	// Applying appearance to the properties required to fill.
	ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
	
	AppearanceColorItem = ConditionalAppearanceItem.Appearance.Items.Find("Font");
	AppearanceColorItem.Value = New Font(, , True);
	AppearanceColorItem.Use = True;
	
	DataFilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue = New DataCompositionField("Properties.RequiredToFill");
	DataFilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue = True;
	DataFilterItem.Use = True;
	
	FieldAppearanceItem = ConditionalAppearanceItem.Fields.Items.Add();
	FieldAppearanceItem.Field = New DataCompositionField("PropertiesTitle");
	FieldAppearanceItem.Use = True;
	
EndProcedure

&AtClient
Procedure SelectSpecifiedRows(Details)
	
	If Details.Property("Set") Then
		
		If TypeOf(Details.Set) = Type("String") Then
			ConvertStringsToReferences(Details);
		EndIf;
		
		If Details.IsAdditionalData <> IsAdditionalDataSets Then
			IsAdditionalDataSets = Details.IsAdditionalData;
			UpdateSetAppearance();
		EndIf;
		
		Items.PropertySets.CurrentRow = Details.Set;
		CurrentSet = Undefined;
		OnCurrentSetChange();
		FoundRows = Properties.FindRows(New Structure("Property", Details.Property));
		If FoundRows.Count() > 0 Then
			Items.Properties.CurrentRow = FoundRows[0].GetID();
		Else
			Items.Properties.CurrentRow = Undefined;
		EndIf;
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure ConvertStringsToReferences(Details)
	
	Details.Insert("Set", Catalogs.AdditionalDataAndAttributeSets.GetRef(
		New UUID(Details.Set)));
	
	Details.Insert("Property", ChartsOfCharacteristicTypes.AdditionalDataAndAttributes.GetRef(
		New UUID(Details.Property)));
	
EndProcedure

&AtServer
Procedure UpdateCommandUsage()
	
	If GetFunctionalOption("UseCommonAdditionalValues")
	 Or GetFunctionalOption("UseCommonAdditionalDataAndAttributes") Then
		
		Items.PropertiesOnlyCreate.Visible = False;
		Items.PropertiesAddSubmenu.Visible = True;
		
		Items.PropertiesContextMenuOnlyCreate.Visible = False;
		Items.PropertiesContextMenuSubmenuAdd.Visible = True
	Else
		Items.PropertiesOnlyCreate.Visible = True;
		Items.PropertiesAddSubmenu.Visible = False;
		
		Items.PropertiesContextMenuOnlyCreate.Visible = True;
		Items.PropertiesContextMenuSubmenuAdd.Visible = False
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdateSetAppearance()
	
	CreateCommand = Commands.Find("Create");
	CreateBySampleCommand = Commands.Find("CreateBySample");
	CreateCommonCommand = Commands.Find("CreateCommon");
	CopyCommand = Commands.Find("Copy");
	ChangeCommand = Commands.Find("Change");
	MarkToDeleteCommand = Commands.Find("MarkToDelete");
	MoveUpCommand = Commands.Find("MoveUp");
	MoveDownCommand = Commands.Find("MoveDown");
	
	If IsAdditionalDataSets Then
		Title = NStr("en = 'Additional data'");
		
		CreateCommand.ToolTip = NStr("en = 'Create a unique data'");
		CreateCommand.Title = NStr("en = 'New'");
		CreateCommand.ToolTip = NStr("en = 'Create a unique data'");
		CreateBySampleCommand.Title = NStr("en = 'By sample'");
		CreateBySampleCommand.ToolTip = NStr("en = 'Create a data by sample (common list of values)'");
		CreateCommonCommand.Title = NStr("en = 'Common...'");
		CreateCommonCommand.ToolTip = NStr("en = 'Select a common data from the existing ones'");
		
		CopyCommand.ToolTip = NStr("en = 'Create a new data by copying the current ones'");
		ChangeCommand.ToolTip = NStr("en = 'Change (or open) the current data'");
		MarkToDeleteCommand.ToolTip = NStr("en = 'Mark the current data for deletion (Del)'");
		MoveUpCommand.ToolTip = NStr("en = 'Move the current data up'");
		MoveDownCommand.ToolTip = NStr("en = 'Move the current data down'");
		
		MetadataTabularSection =
			Metadata.Catalogs.AdditionalDataAndAttributeSets.TabularSections.AdditionalData;
		
		Items.PropertiesTitle.Title = MetadataTabularSection.Attributes.Property.Synonym;
		Items.PropertiesTitle.ToolTip = MetadataTabularSection.Attributes.Property.ToolTip;
		
		Items.PropertiesRequiredToFill.Visible = False;
		
		Items.PropertiesValueType.ToolTip =
			NStr("en = 'Value types that can be entered when filling the data.'");
		
		Items.PropertiesCommonValues.ToolTip =
			NStr("en = 'The data uses the data-sample value list.'");
		
		Items.PropertiesCommon.Title = NStr("en = 'Common'");
		Items.PropertiesCommon.ToolTip = NStr("en = 'Common additional data used in several additional data sets.'");
	Else
		Title = NStr("en = 'Additional attributes'");
		CreateCommand.Title = NStr("en = 'New'");
		CreateCommand.ToolTip = NStr("en = 'Create a unique attribute'");
		CreateBySampleCommand.Title = NStr("en = 'By sample'");
		CreateBySampleCommand.ToolTip = NStr("en = 'Create an attribute by sample (common list of values)'");
		CreateCommonCommand.Title = NStr("en = 'Common...'");
		CreateCommonCommand.ToolTip = NStr("en = 'Select a common attribute from the existing ones'");
		
		CopyCommand.ToolTip = NStr("en = 'Create a new attribute by copying the current one'");
		ChangeCommand.ToolTip = NStr("en = 'Edit (or open) the current attribute'");
		MarkToDeleteCommand.ToolTip = NStr("en = 'Mark the current attribute for deletion (Del)'");
		MoveUpCommand.ToolTip = NStr("en = 'Move the current attribute up'");
		MoveDownCommand.ToolTip = NStr("en = 'Move the current attribute down'");
		
		MetadataTabularSection =
			Metadata.Catalogs.AdditionalDataAndAttributeSets.TabularSections.AdditionalAttributes;
		
		Items.PropertiesTitle.Title = MetadataTabularSection.Attributes.Property.Synonym;
		Items.PropertiesTitle.ToolTip = MetadataTabularSection.Attributes.Property.ToolTip;
		
		Items.PropertiesRequiredToFill.Visible = True;
		Items.PropertiesRequiredToFill.ToolTip =
			Metadata.ChartsOfCharacteristicTypes.AdditionalDataAndAttributes.Attributes.RequiredToFill.ToolTip;
		
		Items.PropertiesValueType.ToolTip =
			NStr("en = 'Value types that can be entered when filling the attribute.'");
		
		Items.PropertiesCommonValues.ToolTip =
			NStr("en = 'The attribute uses the attribute-sample value list.'");
		
		Items.PropertiesCommon.Title = NStr("en = 'Common'");
		Items.PropertiesCommon.ToolTip = NStr("en = 'The common additional attribute used in several additional attribute sets.'");
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Sets.Ref AS Ref
	|FROM
	|	Catalog.AdditionalDataAndAttributeSets AS Sets
	|WHERE
	|	Sets.Parent = VALUE(Catalog.AdditionalDataAndAttributeSets.EmptyRef)";
	
	Sets = Query.Execute().Unload().UnloadColumn("Ref");
	AvailableSets = New Array;
	AvailableSetsList.Clear();
	
	For Each Ref In Sets Do
		SetPropertyTypes = PropertyManagementInternal.SetPropertyTypes(Ref, False);
		
		If IsAdditionalDataSets
		   And SetPropertyTypes.AdditionalData
		 Or Not IsAdditionalDataSets
		   And SetPropertyTypes.AdditionalAttributes Then
			
			AvailableSets.Add(Ref);
			AvailableSetsList.Add(Ref);
		EndIf;
	EndDo;
	
	CommonUseClientServer.SetDynamicListParameter(
		PropertySets, "IsAdditionalDataSets", IsAdditionalDataSets, True);
	
	CommonUseClientServer.SetDynamicListParameter(
		PropertySets, "Sets", AvailableSets, True);
		
	If Not Items.IsAdditionalDataSets.Visible Then
		// Hide marked for deletion.
		CommonUseClientServer.SetDynamicListFilterItem(
			PropertySets, "DeletionMark", False, , , True,
			DataCompositionSettingsItemViewMode.Normal);
	EndIf;
	
	OnCurrentSetChangeAtServer();
	
EndProcedure

&AtClient
Procedure OnCurrentSetChange()
	
	If Items.PropertySets.CurrentData = Undefined Then
		If ValueIsFilled(CurrentSet) Then
			CurrentSet = Undefined;
			OnCurrentSetChangeAtServer();
		EndIf;
		
	ElsIf Items.PropertySets.CurrentData.Ref <> CurrentSet Then
		CurrentSet = Items.PropertySets.CurrentData.Ref;
		CurrentSetIsGroup = Items.PropertySets.CurrentData.IsFolder;
		OnCurrentSetChangeAtServer();
	EndIf;
	
EndProcedure

&AtClient
Procedure ChangeDeletionMark()
	
	If Items.Properties.CurrentData <> Undefined Then
		
		If IsAdditionalDataSets Then
			If Items.Properties.CurrentData.Common Then
				QuestionText = NStr("en ='Do you want to delete the current common additional data from the set?'");
				
			ElsIf Items.Properties.CurrentData.DeletionMark Then
				QuestionText = NStr("en ='Do you want to remove the deletion mark from the current data?'");
			Else
				QuestionText = NStr("en ='Do you want to mark the current data for deletion?'");
			EndIf;
		Else
			If Items.Properties.CurrentData.Common Then
				QuestionText = NStr("en ='Do you want to delete the current common attribute from the set?'");
				
			ElsIf Items.Properties.CurrentData.DeletionMark Then
				QuestionText = NStr("en ='Do you want to remove the deletion mark from the current attribute?'");
			Else
				QuestionText = NStr("en ='Do you want to mark the current attribute for deletion?'");
			EndIf;
		EndIf;
		
		ShowQueryBox(
			New NotifyDescription("ChangeDeletionMarkEnd", ThisObject, CurrentSet),
			QuestionText, QuestionDialogMode.YesNo);
	EndIf;
	
EndProcedure

&AtClient
Procedure ChangeDeletionMarkEnd(Answer, CurrentSet) Export
	
	If Answer <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	ExecuteCommandAtServer("ChangeDeletionMark");
	
	Notify("Write_AdditionalDataAndAttributeSets",
		New Structure("Ref", CurrentSet), CurrentSet);
	
EndProcedure

&AtServer
Procedure OnCurrentSetChangeAtServer()
	
	If ValueIsFilled(CurrentSet)
	   And Not CurrentSetIsGroup Then
		
		CurrentEnable = True;
		If Items.Properties.BackColor <> Items.PropertySets.BackColor Then
			Items.Properties.BackColor = Items.PropertySets.BackColor;
		EndIf;
		UpdateCurrentSetPropertyList(CurrentEnable);
	Else
		CurrentEnable = False;
		If Items.Properties.BackColor <> FormColor Then
			Items.Properties.BackColor = FormColor;
		EndIf;
		Properties.Clear();
	EndIf;
	
	If Items.Properties.ReadOnly = CurrentEnable Then
		Items.Properties.ReadOnly = Not CurrentEnable;
	EndIf;
	
	PropertiesSetCommandAvailability(ThisObject);
	
	Items.PropertySets.Refresh();
	
EndProcedure

&AtClientAtServerNoContext
Procedure PropertiesSetCommandAvailability(Context)
	
	Items = Context.Items;
	
	CommonAvailability = Not Items.Properties.ReadOnly;
	
	AvailabilityForRow = CommonAvailability
		And Context.Items.Properties.CurrentRow <> Undefined;
	
	// Setting of the commands on the command bar.
	Items.PropertiesCreate.Enabled = CommonAvailability;
	Items.PropertiesOnlyCreate.Enabled = CommonAvailability;
	Items.PropertiesCreateBySample.Enabled = CommonAvailability;
	Items.PropertiesCreateCommon.Enabled = CommonAvailability;
	
	Items.PropertiesCopy.Enabled = AvailabilityForRow;
	Items.PropertiesChange.Enabled = AvailabilityForRow;
	Items.PropertiesMarkToDelete.Enabled = AvailabilityForRow;
	
	Items.PropertiesMoveUp.Enabled = AvailabilityForRow;
	Items.PropertiesMoveDown.Enabled = AvailabilityForRow;
	
	// Setting of the commands on the context menu.
	Items.PropertiesContextMenuCreate.Enabled = CommonAvailability;
	Items.PropertiesContextMenuOnlyCreate.Enabled = CommonAvailability;
	Items.PropertiesContextMenuCreateBySample.Enabled = CommonAvailability;
	Items.PropertiesContextMenuCreateCommon.Enabled = CommonAvailability;
	
	Items.PropertiesContextMenuCopy.Enabled = AvailabilityForRow;
	Items.PropertiesContextMenuChange.Enabled = AvailabilityForRow;
	Items.PropertiesContextMenuMarkToDelete.Enabled = AvailabilityForRow;
	
EndProcedure

&AtServer
Procedure UpdateCurrentSetPropertyList(CurrentEnable)
	
	Query = New Query;
	Query.SetParameter("Set", CurrentSet);
	
	Query.Text =
	"SELECT
	|	SetProperties.LineNumber,
	|	SetProperties.Property,
	|	SetProperties.DeletionMark,
	|	ISNULL(Properties.Title, PRESENTATION(SetProperties.Property)) AS Title,
	|	Properties.AdditionalValueOwner,
	|	Properties.RequiredToFill,
	|	Properties.ValueType AS ValueType,
	|	CASE
	|		WHEN Properties.Ref IS NULL 
	|			THEN TRUE
	|		WHEN Properties.PropertySet = VALUE(Catalog.AdditionalDataAndAttributeSets.EmptyRef)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS Common,
	|	CASE
	|		WHEN SetProperties.DeletionMark = TRUE
	|			THEN 4
	|		ELSE 3
	|	END AS PictureNumber
	|FROM
	|	Catalog.AdditionalDataAndAttributeSets.AdditionalAttributes AS SetProperties
	|		LEFT JOIN ChartOfCharacteristicTypes.AdditionalDataAndAttributes AS Properties
	|		ON SetProperties.Property = Properties.Ref
	|WHERE
	|	SetProperties.Ref = &Set
	|
	|ORDER BY
	|	SetProperties.LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Sets.DataVersion AS DataVersion
	|FROM
	|	Catalog.AdditionalDataAndAttributeSets AS Sets
	|WHERE
	|	Sets.Ref = &Set";
	
	If IsAdditionalDataSets Then
		Query.Text = StrReplace(
			Query.Text,
			"Catalog.AdditionalDataAndAttributeSets.AdditionalAttributes",
			"Catalog.AdditionalDataAndAttributeSets.AdditionalData");
	EndIf;
	
	BeginTransaction();
	Try
		QueryResults = Query.ExecuteBatch();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	If Items.Properties.CurrentRow = Undefined Then
		Row = Undefined;
	Else
		Row = Properties.FindByID(Items.Properties.CurrentRow);
	EndIf;
	CurrentPropery = ?(Row = Undefined, Undefined, Row.Property);
	
	Properties.Clear();
	
	If QueryResults[1].IsEmpty() Then
		CurrentEnable = False;
		Return;
	EndIf;
	
	CurrentSetDataVersion = QueryResults[1].Unload()[0].DataVersion;
	
	Selection = QueryResults[0].Select();
	While Selection.Next() Do
		
		NewRow = Properties.Add();
		FillPropertyValues(NewRow, Selection);
		
		NewRow.CommonValues = ValueIsFilled(Selection.AdditionalValueOwner);
		
		If Selection.ValueType <> NULL
		   And PropertyManagementInternal.ValueTypeContainsPropertyValues(Selection.ValueType) Then
			
			NewRow.ValueType = String(New TypeDescription(
				Selection.ValueType,
				,
				"CatalogRef.ObjectPropertyValueHierarchy, 
				|CatalogRef.ObjectPropertyValues"));
			
			Query = New Query;
			If ValueIsFilled(Selection.AdditionalValueOwner) Then
				Query.SetParameter("Owner", Selection.AdditionalValueOwner);
			Else
				Query.SetParameter("Owner", Selection.Property);
			EndIf;
			Query.Text =
			"SELECT TOP 4
			|	ObjectPropertyValues.Description AS Description
			|FROM
			|	Catalog.ObjectPropertyValues AS ObjectPropertyValues
			|WHERE
			|	ObjectPropertyValues.Owner = &Owner
			|	AND NOT ObjectPropertyValues.IsFolder
			|	AND NOT ObjectPropertyValues.DeletionMark
			|
			|UNION
			|
			|SELECT TOP 4
			|	ObjectPropertyValueHierarchy.Description
			|FROM
			|	Catalog.ObjectPropertyValueHierarchy AS ObjectPropertyValueHierarchy
			|WHERE
			|	ObjectPropertyValueHierarchy.Owner = &Owner
			|	AND NOT ObjectPropertyValueHierarchy.DeletionMark
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT TOP 1
			|	TRUE AS TrueValue
			|FROM
			|	Catalog.ObjectPropertyValues AS ObjectPropertyValues
			|WHERE
			|	ObjectPropertyValues.Owner = &Owner
			|	AND NOT ObjectPropertyValues.IsFolder
			|
			|UNION ALL
			|
			|SELECT TOP 1
			|	TRUE
			|FROM
			|	Catalog.ObjectPropertyValueHierarchy AS ObjectPropertyValueHierarchy
			|WHERE
			|	ObjectPropertyValueHierarchy.Owner = &Owner";
			QueryResults = Query.ExecuteBatch();
			
			TopValues = QueryResults[0].Unload().UnloadColumn("Description");
			
			If TopValues.Count() = 0 Then
				If QueryResults[1].IsEmpty() Then
					ValuePresentation = NStr("en = 'Values are not input'");
				Else
					ValuePresentation = NStr("en = 'Values are marked for deletion'");
				EndIf;
			Else
				ValuePresentation = "";
				Number = 0;
				For Each Value In TopValues Do
					Number = Number + 1;
					If Number = 4 Then
						ValuePresentation = ValuePresentation + ",...";
						Break;
					EndIf;
					ValuePresentation = ValuePresentation + ?(Number > 1, ",", "") + Value;
				EndDo;
			EndIf;
			ValuePresentation = "<" + ValuePresentation + ">";
			If ValueIsFilled(NewRow.ValueType) Then
				ValuePresentation = ValuePresentation + ", ";
			EndIf;
			NewRow.ValueType = ValuePresentation + NewRow.ValueType;
		EndIf;
		
		If Selection.Property = CurrentPropery Then
			Items.Properties.CurrentRow =
				Properties[Properties.Count()-1].GetID();
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure ExecuteCommandAtServer(Command, Parameter = Undefined)
	
	DataLock = New DataLock;
	
	If Command = "ChangeDeletionMark" Then
		LockItem = DataLock.Add("Catalog.AdditionalDataAndAttributeSets");
		LockItem.Mode = DataLockMode.Exclusive;
		
		LockItem = DataLock.Add("ChartOfCharacteristicTypes.AdditionalDataAndAttributes");
		LockItem.Mode = DataLockMode.Exclusive;
		
		LockItem = DataLock.Add("Catalog.ObjectPropertyValues");
		LockItem.Mode = DataLockMode.Exclusive;
		
		LockItem = DataLock.Add("Catalog.ObjectPropertyValueHierarchy");
		LockItem.Mode = DataLockMode.Exclusive;
	Else
		LockItem = DataLock.Add("Catalog.AdditionalDataAndAttributeSets");
		LockItem.Mode = DataLockMode.Exclusive;
		LockItem.SetValue("Ref", CurrentSet);
	EndIf;
	
	Try
		LockDataForEdit(CurrentSet);
		BeginTransaction();
		Try
			DataLock.Lock();
			LockDataForEdit(CurrentSet);
			
			CurrentObjectSet = CurrentSet.GetObject();
			If CurrentObjectSet.DataVersion <> CurrentSetDataVersion Then
				OnCurrentSetChangeAtServer();
				If IsAdditionalDataSets Then
					Raise
						NStr("en = 'The action is not executed as the additional data set has been changed by another user.
						           |The new list of additional data is read.
						           |
						           |Repeat the action if required.'");
				Else
					Raise
						NStr("en = 'The action is not executed as the additional attribute set has been changed by another user.
						           |The new list of additional attributes is read.
						           |
						           |Repeat the action if required.'");
				EndIf;
			EndIf;
			
			TabularSection = CurrentObjectSet[?(IsAdditionalDataSets,
				"AdditionalData", "AdditionalAttributes")];
			
			If Command = "AddCommonProperty" Then
				FoundRow = TabularSection.Find(Parameter, "Property");
				
				If FoundRow = Undefined Then
					NewRow = TabularSection.Add();
					NewRow.Property = Parameter;
					CurrentObjectSet.Write();
					
				ElsIf FoundRow.DeletionMark Then
					FoundRow.DeletionMark = False;
					CurrentObjectSet.Write();
				EndIf;
			Else
				Row = Properties.FindByID(Items.Properties.CurrentRow);
				
				If Row <> Undefined Then
					Index = Row.LineNumber-1;
					
					If Command = "MoveUp" Then
						TopRowIndex = Properties.IndexOf(Row)-1;
						If TopRowIndex >= 0 Then
							Move = Properties[TopRowIndex].LineNumber - Row.LineNumber;
							TabularSection.Move(Index, Move);
						EndIf;
						CurrentObjectSet.Write();
						
					ElsIf Command = "MoveDown" Then
						BottomRowIndex = Properties.IndexOf(Row)+1;
						If BottomRowIndex < Properties.Count() Then
							Move = Properties[BottomRowIndex].LineNumber - Row.LineNumber;
							TabularSection.Move(Index, Move);
						EndIf;
						CurrentObjectSet.Write();
						
					ElsIf Command = "ChangeDeletionMark" Then
						Row = Properties.FindByID(Items.Properties.CurrentRow);
						
						If Row.Common Then
							TabularSection.Delete(Index);
							CurrentObjectSet.Write();
							Properties.Delete(Row);
							If TabularSection.Count() > Index Then
								Items.Properties.CurrentRow = Properties[Index].GetID();
							ElsIf TabularSection.Count() > 0 Then
								Items.Properties.CurrentRow = Properties[Properties.Count()-1].GetID();
							EndIf;
						Else
							TabularSection[Index].DeletionMark = Not TabularSection[Index].DeletionMark;
							CurrentObjectSet.Write();
							
							ChangeDeletionMarkAndValueOwner(
								CurrentObjectSet.Ref,
								TabularSection[Index].Property,
								TabularSection[Index].DeletionMark);
						EndIf;
					EndIf;
				EndIf;
			EndIf;
			
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
	Except
		UnlockDataForEdit(CurrentSet);
		Raise;
	EndTry;
	
	OnCurrentSetChangeAtServer();
	
EndProcedure

&AtServer
Procedure ChangeDeletionMarkAndValueOwner(CurrentSet, CurrentPropery, PropertyDeletionMark)
	
	OldPropertyOwner = CurrentPropery;
	
	NewValuesMark   = Undefined;
	NewValueOwner  = Undefined;
	
	PropertyObject = CurrentPropery.GetObject();
	
	If ValueIsFilled(PropertyObject.PropertySet) Then
		
		If PropertyDeletionMark Then
			// When marking unique properties:
			// - mark the property,
     // - if there are ones created by sample and not marked for deletion, 
     // then set the values new owner and specify a new sample for all the properties, 
     // otherwise mark all the values for deletion.
			PropertyObject.DeletionMark = True;
			
			If Not ValueIsFilled(PropertyObject.AdditionalValueOwner) Then
				Query = New Query;
				Query.SetParameter("Property", PropertyObject.Ref);
				Query.Text =
				"SELECT
				|	Properties.Ref,
				|	Properties.DeletionMark
				|FROM
				|	ChartOfCharacteristicTypes.AdditionalDataAndAttributes AS Properties
				|WHERE
				|	Properties.AdditionalValueOwner = &Property";
				Data = Query.Execute().Unload();
				FoundRow = Data.Find(False, "DeletionMark");
				If FoundRow <> Undefined Then
					NewValueOwner  = FoundRow.Ref;
					PropertyObject.AdditionalValueOwner = NewValueOwner;
					For Each Row In Data Do
						CurrentObject = Row.Ref.GetObject();
						If CurrentObject.Ref = NewValueOwner Then
							CurrentObject.AdditionalValueOwner = Undefined;
						Else
							CurrentObject.AdditionalValueOwner = NewValueOwner;
						EndIf;
						CurrentObject.Write();
					EndDo;
				Else
					NewValuesMark = True;
				EndIf;
			EndIf;
			PropertyObject.Write();
		Else
			If PropertyObject.DeletionMark Then
				PropertyObject.DeletionMark = False;
				PropertyObject.Write();
			EndIf;
			// When removing marks from a unique property:
			// - remove the mark from the property,
     // if the property is created by sample, then if the sample is marked 
     // for deletion, then set the values new owner current for all properties 
     // and remove the deletion mark from the values.
			//   Otherwise remove the deletion mark from the values.
			If Not ValueIsFilled(PropertyObject.AdditionalValueOwner) Then
				NewValuesMark = False;
				
			ElsIf CommonUse.ObjectAttributeValue(
			            PropertyObject.AdditionalValueOwner, "DeletionMark") Then
				
				Query = New Query;
				Query.SetParameter("Property", PropertyObject.AdditionalValueOwner);
				Query.Text =
				"SELECT
				|	Properties.Ref AS Ref
				|FROM
				|	ChartOfCharacteristicTypes.AdditionalDataAndAttributes AS Properties
				|WHERE
				|	Properties.AdditionalValueOwner = &Property";
				Array = Query.Execute().Unload().UnloadColumn("Ref");
				Array.Add(PropertyObject.AdditionalValueOwner);
				NewValueOwner = PropertyObject.Ref;
				For Each CurrentRef In Array Do
					If CurrentRef = NewValueOwner Then
						Continue;
					EndIf;
					CurrentObject = CurrentRef.GetObject();
					CurrentObject.AdditionalValueOwner = NewValueOwner;
					CurrentObject.Write();
				EndDo;
				OldPropertyOwner = PropertyObject.AdditionalValueOwner;
				PropertyObject.AdditionalValueOwner = Undefined;
				PropertyObject.Write();
				NewValuesMark = False;
			EndIf;
		EndIf;
	EndIf;
	
	If NewValuesMark  = Undefined
	   And NewValueOwner = Undefined Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("Owner", OldPropertyOwner);
	Query.Text =
	"SELECT
	|	ObjectPropertyValues.Ref AS Ref,
	|	ObjectPropertyValues.DeletionMark AS DeletionMark
	|FROM
	|	Catalog.ObjectPropertyValues AS ObjectPropertyValues
	|WHERE
	|	ObjectPropertyValues.Owner = &Owner
	|
	|UNION ALL
	|
	|SELECT
	|	ObjectPropertyValueHierarchy.Ref,
	|	ObjectPropertyValueHierarchy.DeletionMark
	|FROM
	|	Catalog.ObjectPropertyValueHierarchy AS ObjectPropertyValueHierarchy
	|WHERE
	|	ObjectPropertyValueHierarchy.Owner = &Owner";
	
	Data = Query.Execute().Unload();
	
	If NewValueOwner <> Undefined Then
		For Each Row In Data Do
			CurrentObject = Row.Ref.GetObject();
			
			If CurrentObject.Owner <> NewValueOwner Then
				CurrentObject.Owner = NewValueOwner;
			EndIf;
			
			If CurrentObject.Modified() Then
				CurrentObject.DataExchange.Load = True;
				CurrentObject.Write();
			EndIf;
		EndDo;
	EndIf;
	
	If NewValuesMark <> Undefined Then
		For Each Row In Data Do
			CurrentObject = Row.Ref.GetObject();
			
			If CurrentObject.DeletionMark <> NewValuesMark Then
				CurrentObject.DeletionMark = NewValuesMark;
			EndIf;
			
			If CurrentObject.Modified() Then
				CurrentObject.Write();
			EndIf;
		EndDo;
	EndIf;
	
EndProcedure

#EndRegion