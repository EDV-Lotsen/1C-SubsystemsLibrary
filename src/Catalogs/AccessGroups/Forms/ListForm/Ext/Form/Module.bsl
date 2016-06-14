
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	If Parameters.ChoiceMode Then
		PurposeUseKey = "SelectionPick";
	EndIf;
	
	Items.List.ChoiceMode = Parameters.ChoiceMode;
	
	PersonalAccessGroupParent = Catalogs.AccessGroups.PersonalAccessGroupParent(True);
	
	SimplifiedAccessRightSetupInterface = AccessManagementInternal.SimplifiedAccessRightSetupInterface();
	
	If SimplifiedAccessRightSetupInterface Then
		Items.FormCreate.Visible = False;
		Items.FormCopy.Visible = False;
		Items.ListContextMenuCreate.Visible = False;
		Items.ListContextMenuCopy.Visible = False;
	EndIf;
	
	List.Parameters.SetParameterValue("Profile", Parameters.Profile);
	If ValueIsFilled(Parameters.Profile) Then
		Items.Profile.Visible = False;
		Items.List.Representation = TableRepresentation.List;
		AutoTitle = False;
		
		Title = NStr("en = 'Access groups'");
		
		Items.FormCreateFolder.Visible = False;
		Items.ListContextMenuCreateGroup.Visible = False;
	EndIf;
	
	If Not AccessRight("Read", Metadata.Catalogs.AccessGroupProfiles) Then
		Items.Profile.Visible = False;
	EndIf;
	
	If AccessRight("View", Metadata.Catalogs.ExternalUsers) Then
		List.QueryText = StrReplace(
			List.QueryText,
			"&ErrorObjectNotFound",
			"IsNULL(CAST(AccessGroups.User AS Catalog.ExternalUsers).Description, &ErrorObjectNotFound)");
	EndIf;
	
	InaccessibleGroupList = New ValueList;
	
	If Not Users.InfobaseUserWithFullAccess() Then
		// Hiding Administrators access group 
CommonUseClientServer.SetDynamicListFilterItem(
			List, "Ref", Catalogs.AccessGroups.Administrators,
			DataCompositionComparisonType.NotEqual, , True);
	EndIf;
	
	ChoiceMode = Parameters.ChoiceMode;
	
	List.Parameters.SetParameterValue(
		"ErrorObjectNotFound",
		NStr("en = '<Object not found>'"));
	
	If Parameters.ChoiceMode Then
		
		WindowOpeningMode = FormWindowOpeningMode.LockOwnerWindow;
		
		// Applying a filter that excludes items marked for deletion
CommonUseClientServer.SetDynamicListFilterItem(
			List, "DeletionMark", False, , , True,
			DataCompositionSettingsItemViewMode.Normal);
		
		Items.List.ChoiceMode = True;
		Items.List.ChoiceFoldersAndItems = Parameters.ChoiceFoldersAndItems;
		
		AutoTitle = False;
		If Parameters.CloseOnChoice = False Then
			// Picking groups
			Items.List.MultipleChoice = True;
			Items.List.SelectionMode = TableSelectionMode.MultiRow;
			
			Title = NStr("en = 'Pick access groups'");
		Else
			Title = NStr("en = 'Select access group'");
			Items.FormChoose.DefaultButton = False;
		EndIf;
	EndIf;
	
	CommonUseClientServer.MoveFiltersToDynamicList(ThisObject);
EndProcedure

#EndRegion

#Region ListFormTableItemEventHandlers

&AtClient
Procedure ListOnActivateRow(Item)
	
	If Items.List.CurrentData <> Undefined
		And Items.List.CurrentData.Property("User")
		And Items.List.CurrentData.Property("Ref") Then
		
		TransferAvailable = Not ValueIsFilled(Items.List.CurrentData.User)
		                  And Items.List.CurrentData.Ref <> PersonalAccessGroupParent;
		
		If Items.Find("FormMoveItem") <> Undefined Then
			Items.FormMoveItem.Enabled = TransferAvailable;
		EndIf;
		
		If Items.Find("ListContextMenuMoveItem") <> Undefined Then
			Items.ListContextMenuMoveItem.Enabled = TransferAvailable;
		EndIf;
		
		If Items.Find("ListMoveItem") <> Undefined Then
			Items.ListMoveItem.Enabled = TransferAvailable;
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure ListValueChoice(Item, Value, StandardProcessing)
	
	If Value = PersonalAccessGroupParent Then
		StandardProcessing = False;
		ShowMessageBox(, NStr("en = 'This group can store only personal access groups.'"));
	EndIf;
	
EndProcedure

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Clone, Parent, Group)
	
	If Parent = PersonalAccessGroupParent Then
		
		Cancel = True;
		
		If Group Then
			ShowMessageBox(, NStr("en = 'Subgroups are not used in this group.'"));
			
		ElsIf SimplifiedAccessRightSetupInterface Then
			ShowMessageBox(,
				NStr("en = 'Personal access groups can be created only in the ""Access rights"" form.'"));
		Else
			ShowMessageBox(, NStr("en = 'Personal access groups are not used.'"));
		EndIf;
		
	ElsIf Not Group
	        And SimplifiedAccessRightSetupInterface Then
		
		Cancel = True;
		
		ShowMessageBox(,
			NStr("en = 'Only personal access groups are used. They can be created only in the ""Access rights"" form.'"));
	EndIf;
	
EndProcedure

&AtClient
Procedure ListDrag(Item, DragParameters, StandardProcessing, String, Field)
	
	If String = PersonalAccessGroupParent Then
		StandardProcessing = False;
		ShowMessageBox(, NStr("en = 'This folder is intended for personal access groups.'"));
		
	ElsIf DragParameters.Value = PersonalAccessGroupParent Then
		StandardProcessing = False;
		ShowMessageBox(, NStr("en = 'The personal access group folder cannot be moved.'"));
	EndIf;
	
EndProcedure

#EndRegion
