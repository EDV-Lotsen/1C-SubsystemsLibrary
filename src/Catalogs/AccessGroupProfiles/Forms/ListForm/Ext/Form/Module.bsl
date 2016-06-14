
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
	
	If Parameters.ChoiceMode Then
		WindowOpeningMode = FormWindowOpeningMode.LockOwnerWindow;
		
		// Hiding Administrator profile.
		CommonUseClientServer.SetDynamicListFilterItem(
			List, "Ref", Catalogs.AccessGroupProfiles.Administrator,
			DataCompositionComparisonType.NotEqual, , True);
		
		// Applying a filter that excludes items marked for deletion.
		CommonUseClientServer.SetDynamicListFilterItem(
			List, "DeletionMark", False, , , True,
			DataCompositionSettingsItemViewMode.Normal);
		
		Items.List.ChoiceMode = True;
		Items.List.ChoiceFoldersAndItems = Parameters.ChoiceFoldersAndItems;
		
		AutoTitle = False;
		If Parameters.CloseOnChoice = False Then
			// Switching to pick mode
		Items.List.MultipleChoice = True;
		Items.List.SelectionMode = TableSelectionMode.MultiRow;
			
			Title = NStr("en = 'Pick access group profiles'");
		Else
			Title = NStr("en = 'Select access group profile'");
		EndIf;
	EndIf;
	
	If Parameters.Property("ProfilesWithRolesMarkedForDeletion") Then
		ShowProfiles = "Obsolete";
	Else
		ShowProfiles = "AllProfiles";
	EndIf;
	
	If Not Parameters.ChoiceMode Then
		SetFilter();
	Else
		Items.ShowProfiles.Visible = False;
	EndIf;
	
	CommonUseClientServer.MoveFiltersToDynamicList(ThisObject);
EndProcedure

#EndRegion

#Region FormControlItemEventHandlers

&AtClient
Procedure ShowProfilesOnChange(Item)
	SetFilter();
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure SetFilter()
	
	CommonUseClientServer.SetDynamicListFilterItem(
		List,
		"Ref.Roles.Role.DeletionMark",
		True,
		DataCompositionComparisonType.Equal,, False);
	
	CommonUseClientServer.SetDynamicListFilterItem(
		List,
		"Ref.SuppliedDataID",
		New UUID("00000000-0000-0000-0000-000000000000"),
		DataCompositionComparisonType.Equal,, False);
	
	If ShowProfiles = "Obsolete" Then
		CommonUseClientServer.SetDynamicListFilterItem(
			List,
			"Ref.Roles.Role.DeletionMark",
			True,
			DataCompositionComparisonType.Equal,, True);
		
	ElsIf ShowProfiles = "Supplied" Then
		CommonUseClientServer.SetDynamicListFilterItem(
			List,
			"Ref.SuppliedDataID",
			New UUID("00000000-0000-0000-0000-000000000000"),
			DataCompositionComparisonType.NotEqual,, True);
		
	ElsIf ShowProfiles = "NotSupplied" Then
		CommonUseClientServer.SetDynamicListFilterItem(
			List,
			"Ref.SuppliedDataID",
			New UUID("00000000-0000-0000-0000-000000000000"),
			DataCompositionComparisonType.Equal,, True);
	EndIf;
	
EndProcedure

#EndRegion