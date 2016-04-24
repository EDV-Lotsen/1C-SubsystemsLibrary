////////////////////////////////////////////////////////////////////////////////
// Access management subsystem
// 
////////////////////////////////////////////////////////////////////////////////

#Region InternalInterface

////////////////////////////////////////////////////////////////////////////////
// Management of AccessKinds and AccessValues tables in the forms used for editing

////////////////////////////////////////////////////////////////////////////////
// Table events handlers of the AccessValues form

// For internal use only.
Procedure AccessValuesOnChange(Form, Item) Export
	
	Items = Form.Items;
	Parameters = AllowedValuesEditingFormParameters(Form);
	
	If Item.CurrentData <> Undefined
	   And Item.CurrentData.AccessKind = Undefined Then
		
		Filter = AccessManagementInternalClientServer.FilterInAllowedValuesEditingFormTables(
			Form, Form.CurrentAccessKind);
		
		FillPropertyValues(Item.CurrentData, Filter);
		
		Item.CurrentData.RowNumberByKind = Parameters.AccessValues.FindRows(Filter).Count();
	EndIf;
	
	AccessManagementInternalClientServer.FillAccessValueRowNumbersByKind(
		Form, Items.AccessKinds.CurrentData);
	
	AccessManagementInternalClientServer.FillAllAllowedPresentation(
		Form, Items.AccessKinds.CurrentData);
	
EndProcedure

// For internal use only.
Procedure AccessValuesOnStartEdit(Form, Item, NewRow, Clone) Export
	
	Items = Form.Items;
	
	If Item.CurrentData.AccessValue = Undefined Then
		Item.CurrentData.AccessValue = Form.CurrentTypesOfValuesToSelect[0].Value;
	EndIf;
	
	Items.AccessValuesAccessValue.ClearButton
		= Form.CurrentTypeOfValuesToSelect <> Undefined
		And Form.CurrentTypesOfValuesToSelect.Count() > 1;
	
EndProcedure

// For internal use only.
Procedure AccessValueStartChoice(Form, Item, ChoiceData, StandardProcessing) Export
	
	StandardProcessing = False;
	
	If Form.CurrentTypeOfValuesToSelect <> Undefined Then
		
		AccessValueStartChoiceCompletion(Form);
		Return;
		
	ElsIf Form.CurrentTypesOfValuesToSelect.Count() = 1 Then
		
		Form.CurrentTypeOfValuesToSelect = Form.CurrentTypesOfValuesToSelect[0].Value;
		
		AccessValueStartChoiceCompletion(Form);
		Return;
		
	ElsIf Form.CurrentTypesOfValuesToSelect.Count() > 0 Then
		
		If Form.CurrentTypesOfValuesToSelect.Count() = 2 Then
		
			If Form.CurrentTypesOfValuesToSelect.FindByValue(PredefinedValue(
			         "Catalog.Users.EmptyRef")) <> Undefined
			     
			   And Form.CurrentTypesOfValuesToSelect.FindByValue(PredefinedValue(
			         "Catalog.UserGroups.EmptyRef")) <> Undefined Then
				
				Form.CurrentTypeOfValuesToSelect = PredefinedValue(
					"Catalog.Users.EmptyRef");
				
				AccessValueStartChoiceCompletion(Form);
				Return;
			EndIf;
			
			If Form.CurrentTypesOfValuesToSelect.FindByValue(PredefinedValue(
			         "Catalog.ExternalUsers.EmptyRef")) <> Undefined
			     
			   And Form.CurrentTypesOfValuesToSelect.FindByValue(PredefinedValue(
			         "Catalog.ExternalUserGroups.EmptyRef")) <> Undefined Then
				
				Form.CurrentTypeOfValuesToSelect = PredefinedValue(
					"Catalog.ExternalUsers.EmptyRef");
				
				AccessValueStartChoiceCompletion(Form);
				Return;
			EndIf;
		EndIf;
		
		Form.CurrentTypesOfValuesToSelect.ShowChooseItem(
			New NotifyDescription("AccessValueStartChoiceСontinuation", ThisObject, Form),
			NStr("en = 'Select data type'"),
			Form.CurrentTypesOfValuesToSelect[0]);
	EndIf;
	
EndProcedure

// For internal use only.
Procedure AccessValueChoiceProcessing(Form, Item, SelectedValue, StandardProcessing) Export
	
	CurrentData = Form.Items.AccessValues.CurrentData;
	
	If SelectedValue = Type("CatalogRef.Users") Or
	     SelectedValue = Type("CatalogRef.UserGroups") Then
	
		StandardProcessing = False;
		
		FormParameters = New Structure;
		FormParameters.Insert("ChoiceMode", True);
		FormParameters.Insert("CurrentRow", CurrentData.AccessValue);
		FormParameters.Insert("UserGroupSelection", True);
		
		OpenForm("Catalog.Users.ChoiceForm", FormParameters, Item);
		
	ElsIf SelectedValue = Type("CatalogRef.ExternalUsers") Or
	          SelectedValue = Type("CatalogRef.ExternalUserGroups") Then
	
		StandardProcessing = False;
		
		FormParameters = New Structure;
		FormParameters.Insert("ChoiceMode", True);
		FormParameters.Insert("CurrentRow", CurrentData.AccessValue);
		FormParameters.Insert("ExternalUserGroupSelection", True);
		
		OpenForm("Catalog.ExternalUsers.ChoiceForm", FormParameters, Item);
	EndIf;
	
EndProcedure

// For internal use only.
Procedure AccessValuesOnEndEdit(Form, Item, NewRow, CancelEdit) Export
	
	If Form.CurrentAccessKind = Undefined Then
		Parameters = AllowedValuesEditingFormParameters(Form);
		
		Filter = New Structure("AccessKind", Undefined);
		
		FoundRows = Parameters.AccessValues.FindRows(Filter);
		
		For Each Row In FoundRows Do
			Parameters.AccessValues.Delete(Row);
		EndDo;
		
		CancelEdit = True;
	EndIf;
	
	If CancelEdit Then
		AccessManagementInternalClientServer.OnChangeCurrentAccessKind(Form);
	EndIf;
	
EndProcedure

// For internal use only.
Procedure AccessValueClearing(Form, Item, StandardProcessing) Export
	
	Items = Form.Items;
	
	StandardProcessing = False;
	CurrentTypeOfValuesToSelect = Undefined;
	
	Items.AccessValues.CurrentData.AccessValue = Form.CurrentTypesOfValuesToSelect[0].Value;
	Items.AccessValuesAccessValue.ClearButton = False;
	
EndProcedure

// For internal use only.
Procedure AccessValueAutoComplete(Form, Item, Text, ChoiceData, Waiting, StandardProcessing) Export
	
	GenerateAccessValueChoiceData(Form, Text, ChoiceData, StandardProcessing);
	
EndProcedure

// For internal use only.
Procedure AccessValueTextEditCompletion(Form, Item, Text, ChoiceData, StandardProcessing) Export
	
	GenerateAccessValueChoiceData(Form, Text, ChoiceData, StandardProcessing);
	
EndProcedure

// Continues the AccessValueStartChoice event handler.
Procedure AccessValueStartChoiceСontinuation(SelectedItem, Form) Export
	
	If SelectedItem <> Undefined Then
		Form.CurrentTypeOfValuesToSelect = SelectedItem.Value;
		AccessValueStartChoiceCompletion(Form);
	EndIf;
	
EndProcedure

// Completes the AccessValueStartChoice event handler.
Procedure AccessValueStartChoiceCompletion(Form) Export
	
	Items = Form.Items;
	Item  = Items.AccessValuesAccessValue;
	CurrentData = Items.AccessValues.CurrentData;
	
	If Not ValueIsFilled(CurrentData.AccessValue)
	   And CurrentData.AccessValue <> Form.CurrentTypeOfValuesToSelect Then
		
		CurrentData.AccessValue = Form.CurrentTypeOfValuesToSelect;
	EndIf;
	
	Items.AccessValuesAccessValue.ClearButton
		= Form.CurrentTypeOfValuesToSelect <> Undefined
		And Form.CurrentTypesOfValuesToSelect.Count() > 1;
	
	If Form.CurrentTypeOfValuesToSelect
	     = PredefinedValue("Catalog.Users.EmptyRef")
	 Or Form.CurrentTypeOfValuesToSelect
	     = PredefinedValue("Catalog.UserGroups.EmptyRef") Then
		
		FormParameters = New Structure;
		FormParameters.Insert("ChoiceMode", True);
		FormParameters.Insert("CurrentRow", CurrentData.AccessValue);
		FormParameters.Insert("UserGroupSelection", True);
		
		OpenForm("Catalog.Users.ChoiceForm", FormParameters, Item);
		Return;
		
	ElsIf Form.CurrentTypeOfValuesToSelect
	          = PredefinedValue("Catalog.ExternalUsers.EmptyRef")
	          
	      Or Form.CurrentTypeOfValuesToSelect
	          = PredefinedValue("Catalog.ExternalUserGroups.EmptyRef") Then
		
		FormParameters = New Structure;
		FormParameters.Insert("ChoiceMode", True);
		FormParameters.Insert("CurrentRow", CurrentData.AccessValue);
		FormParameters.Insert("ExternalUserGroupSelection", True);
		
		OpenForm("Catalog.ExternalUsers.ChoiceForm", FormParameters, Item);
		Return;
	EndIf;
	
	Filter = New Structure("ValueType", Form.CurrentTypeOfValuesToSelect);
	FoundRows = Form.AllTypesOfValuesToSelect.FindRows(Filter);
	
	If FoundRows.Count() = 0 Then
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("ChoiceMode", True);
	FormParameters.Insert("CurrentRow", CurrentData.AccessValue);
	
	OpenForm(FoundRows[0].TableName + ".ChoiceForm", FormParameters, Item);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Table events handlers of the AccessKinds form

// For internal use only.
Procedure AccessKindsOnActivateRow(Form, Item) Export
	
	AccessManagementInternalClientServer.OnChangeCurrentAccessKind(Form);
	
EndProcedure

// For internal use only.
Procedure AccessKindsOnActivateCell(Form, Item) Export
	
	If Form.IsAccessGroupProfile Then
		Return;
	EndIf;
	
	Items = Form.Items;
	
	If Items.AccessKinds.CurrentItem <> Items.AccessKindsAllAllowedPresentation Then
		Items.AccessKinds.CurrentItem = Items.AccessKindsAllAllowedPresentation;
	EndIf;
	
EndProcedure

// For internal use only.
Procedure AccessKindsBeforeAddRow(Form, Item, Cancel, Clone, Parent, Group) Export
	
	If Clone Then
		Cancel = True;
	EndIf;
	
EndProcedure

// For internal use only.
Procedure AccessKindsBeforeDelete(Form, Item, Cancel) Export
	
	CurrentAccessKind = Undefined;
	
EndProcedure

// For internal use only.
Procedure AccessKindsOnStartEdit(Form, Item, NewRow, Clone) Export
	
	CurrentData = Form.Items.AccessKinds.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If NewRow Then
		CurrentData.Used = True;
	EndIf;
	
	AccessManagementInternalClientServer.FillAllAllowedPresentation(Form, CurrentData, False);
	
EndProcedure

// For internal use only.
Procedure AccessKindsOnEndEdit(Form, Item, NewRow, CancelEdit) Export
	
	AccessManagementInternalClientServer.OnChangeCurrentAccessKind(Form);
	
EndProcedure

// For internal use only.
Procedure AccessKindsAccessKindPresentationOnChange(Form, Item) Export
	
	CurrentData = Form.Items.AccessKinds.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If CurrentData.AccessKindPresentation = "" Then
		CurrentData.AccessKind   = Undefined;
		CurrentData.Used = True;
	EndIf;
	
	AccessManagementInternalClientServer.FillPropertiesOfAccessKindsInForm(Form);
	AccessManagementInternalClientServer.OnChangeCurrentAccessKind(Form);
	
EndProcedure

// For internal use only.
Procedure AccessKindsAccessKindPresentationChoiceProcessing(Form, Item, SelectedValue, StandardProcessing) Export
	
	CurrentData = Form.Items.AccessKinds.CurrentData;
	If CurrentData = Undefined Then
		StandardProcessing = False;
		Return;
	EndIf;
	
	Parameters = AllowedValuesEditingFormParameters(Form);
	
	Filter = New Structure("AccessKindPresentation", SelectedValue);
	Rows = Parameters.AccessKinds.FindRows(Filter);
	
	If Rows.Count() > 0
	   And Rows[0].GetID() <> Form.Items.AccessKinds.CurrentRow Then
		
		ShowMessageBox(, StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'The access kind ""%1"" is already selected.
			           |Select another one.'"),
			SelectedValue));
		
		StandardProcessing = False;
		Return;
	EndIf;
	
	Filter = New Structure("Presentation", SelectedValue);
	CurrentData.AccessKind = Form.AllAccessKinds.FindRows(Filter)[0].Ref;
	
EndProcedure

// For internal use only.
Procedure AccessKindsAllAllowedPresentationOnChange(Form, Item) Export
	
	CurrentData = Form.Items.AccessKinds.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If CurrentData.AllAllowedPresentation = "" Then
		CurrentData.AllAllowed = False;
		If Form.IsAccessGroupProfile Then
			CurrentData.Preset = False;
		EndIf;
	EndIf;
	
	If Form.IsAccessGroupProfile Then
		AccessManagementInternalClientServer.OnChangeCurrentAccessKind(Form);
		AccessManagementInternalClientServer.FillAllAllowedPresentation(Form, CurrentData, False);
	Else
		Form.Items.AccessKinds.EndEditRow(False);
		AccessManagementInternalClientServer.FillAllAllowedPresentation(Form, CurrentData);
	EndIf;
	
EndProcedure

// For internal use only.
Procedure AccessKindsAllAllowedPresentationChoiceProcessing(Form, Item, SelectedValue, StandardProcessing) Export
	
	CurrentData = Form.Items.AccessKinds.CurrentData;
	If CurrentData = Undefined Then
		StandardProcessing = False;
		Return;
	EndIf;
	
	Filter = New Structure("Presentation", SelectedValue);
	Name = Form.PresentationsAllAllowed.FindRows(Filter)[0].Name;
	
	If Form.IsAccessGroupProfile Then
		CurrentData.Preset = (Name = "AllAllowed" Or Name = "AllProhibited");
	EndIf;
	
	CurrentData.AllAllowed = (Name = "InitiallyAllAllowed" Or Name = "AllAllowed");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions

// Management of AccessKinds and AccessValues tables in the forms used for editing.

Function AllowedValuesEditingFormParameters(Form, CurrentObject = Undefined)
	
	Return AccessManagementInternalClientServer.AllowedValuesEditingFormParameters(
		Form, CurrentObject);
	
EndFunction

Procedure GenerateAccessValueChoiceData(Form, Text, ChoiceData, StandardProcessing)
	
	If ValueIsFilled(Text) Then
		StandardProcessing = False;
		
		If Form.CurrentAccessKind = Form.AccessKindExternalUsers
		 Or Form.CurrentAccessKind = Form.AccessKindUsers Then
			
			ChoiceData = AccessManagementInternalServerCall.GenerateUserSelectionData(
				Text,
				,
				Form.CurrentAccessKind = Form.AccessKindExternalUsers,
				Form.CurrentAccessKind <> Form.AccessKindUsers);
		Else
			ChoiceData = AccessManagementInternalServerCall.GenerateAccessValueChoiceData(
				Text, Form.CurrentAccessKind, False);
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion
