#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Interface

// Returns a list of attributes that are excluded from the scope of the batch
// object modification data processor.
//

Function AttributesToSkipOnGroupProcessing() Export
	
	AttributesToSkip = New Array;
	AttributesToSkip.Add("UserType");
	AttributesToSkip.Add("User");
	AttributesToSkip.Add("MainSuppliedProfileAccessGroup");
	AttributesToSkip.Add("AccessKinds.*");
	AttributesToSkip.Add("AccessValues.*");
	
	Return AttributesToSkip;
	
EndFunction

#EndRegion

#Region InternalProceduresAndFunctions

// Sets a deletion mark on access groups if the deletion mark is set on the
// access group profile. It is required, for example, when deleting the access
// group predefined profiles, since the platform does not call object handlers
// when setting the deletion mark on former predefined items during the update of
// data infobase configuration.
//
 
// Parameters:
//  HasChanges - Boolean (return value) - True if data is changed; not set otherwise.
//

Procedure MarkForDeletionSelectedProfilesAccessGroups(HasChanges = Undefined) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	AccessGroups.Ref
	|FROM
	|	Catalog.AccessGroups AS AccessGroups
	|WHERE
	|	AccessGroups.Profile.DeletionMark
	|	AND NOT AccessGroups.DeletionMark
	|	AND NOT AccessGroups.Predefined";
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		AccessGroupObject = Selection.Ref.GetObject();
		AccessGroupObject.DeletionMark = True;
		AccessGroupObject.Write();
		HasChanges = True;
	EndDo;
	
EndProcedure

// Executes update of the access kinds of access groups for the specified profile.
// In this case, it is possible not to delete access kinds from the access group
// that are deleted in this access group profile, when access values in the
// access group are assigned for the access kind marked for deletion.
//
// Parameters:
//  Profile - CatalogRef.AccessGroupProfiles.
//  UpdateAccessGroupsWithObsoleteSettings - Boolean.
//
// Returns:
//  Boolean - If True, access group is changed, if False - nothing is changed.
//
 
Function UpdateProfileAccessGroups(Profile, UpdateAccessGroupsWithObsoleteSettings = False) Export
	
	AccessGroupUpdated = False;
	
	ProfileAccessKinds = CommonUse.ObjectAttributeValue(Profile, "AccessKinds").Unload();
	Index = ProfileAccessKinds.Count() - 1;
	While Index >= 0 Do
		Row = ProfileAccessKinds[Index];
		
		Filter = New Structure("AccessKind", Row.AccessKind);
		AccessKindProperties = AccessManagementInternal.AccessKindProperties(Row.AccessKind);
		
		If AccessKindProperties = Undefined Then
			ProfileAccessKinds.Delete(Row);
		EndIf;
		Index = Index - 1;
	EndDo;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	AccessGroups.Ref
	|FROM
	|	Catalog.AccessGroups AS AccessGroups
	|WHERE
	|	(AccessGroups.Profile = &Profile
	|			OR &Profile = VALUE(Catalog.AccessGroupProfiles.Administrator)
	|				AND AccessGroups.Ref = VALUE(Catalog.AccessGroups.Administrators))";
	
	Query.SetParameter("Profile", Profile.Ref);
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		// Checking if access group must/can be updated
		AccessGroup = Selection.Ref.GetObject();
		
		If AccessGroup.Ref = Catalogs.AccessGroups.Administrators
		   And AccessGroup.Profile <> Catalogs.AccessGroupProfiles.Administrator Then
		// Setting the Administrator profile if it is not set
			AccessGroup.Profile = Catalogs.AccessGroupProfiles.Administrator;
		EndIf;
		
		// Checking access kind content
		AccessKindContentChanged = False;
		HasAccessKindsToDeleteWithSpecifiedAccessValues = False;
		If AccessGroup.AccessKinds.Count() <> ProfileAccessKinds.FindRows(New Structure("Preset", False)).Count() Then
			AccessKindContentChanged = True;
		Else
			For Each AccessKindRow In AccessGroup.AccessKinds Do
				If ProfileAccessKinds.FindRows(New Structure("AccessKind, Preset", AccessKindRow.AccessKind, False)).Count() = 0 Then
					AccessKindContentChanged = True;
					If AccessGroup.AccessValues.Find(AccessKindRow.AccessKind, "AccessKind") <> Undefined Then
						HasAccessKindsToDeleteWithSpecifiedAccessValues = True;
					EndIf;
				EndIf;
			EndDo;
		EndIf;
		
		If AccessKindContentChanged
		   And ( UpdateAccessGroupsWithObsoleteSettings
		       Or Not HasAccessKindsToDeleteWithSpecifiedAccessValues ) Then
			// Updating access group 
		 // 1. Deleting unnecessary access kinds and access values (if any)
			CurrentLineNumber = AccessGroup.AccessKinds.Count()-1;
			While CurrentLineNumber >= 0 Do
				CurrentAccessKind = AccessGroup.AccessKinds[CurrentLineNumber].AccessKind;
				If ProfileAccessKinds.FindRows(New Structure("AccessKind, Preset", CurrentAccessKind, False)).Count() = 0 Then
					AccessKindValueRows = AccessGroup.AccessValues.FindRows(New Structure("AccessKind", CurrentAccessKind));
					For Each ValueRow In AccessKindValueRows Do
						AccessGroup.AccessValues.Delete(ValueRow);
					EndDo;
					AccessGroup.AccessKinds.Delete(CurrentLineNumber);
				EndIf;
				CurrentLineNumber = CurrentLineNumber - 1;
			EndDo;
		 // 2. Adding new access kinds (if any)
			For Each AccessKindRow In ProfileAccessKinds Do
				If Not AccessKindRow.Preset 
				   And AccessGroup.AccessKinds.Find(AccessKindRow.AccessKind, "AccessKind") = Undefined Then
					
					NewRow = AccessGroup.AccessKinds.Add();
					NewRow.AccessKind = AccessKindRow.AccessKind;
					NewRow.AllAllowed = AccessKindRow.AllAllowed;
				EndIf;
			EndDo;
		EndIf;
		
		If AccessGroup.Modified() Then
			LockDataForEdit(AccessGroup.Ref, AccessGroup.DataVersion);
			AccessGroup.AdditionalProperties.Insert("DoNotUpdateUserRoles");
			AccessGroup.Write();
			AccessGroupUpdated = True;
			UnlockDataForEdit(AccessGroup.Ref);
		EndIf;
	EndDo;
	
	Return AccessGroupUpdated;
	
EndFunction

// Returns reference to a parent group of personal access group.
// If the parent group is not found it will be created.
//
// Parameters:
//  DoNotCreate  - Boolean. If True, the parent group is not automatically
//                 created and the function returns Undefined if the parent group
//                 is not found.
//
// Returns:
//  CatalogRef.AccessGroups.
 
Function PersonalAccessGroupParent(Val DoNotCreate = False, ItemGroupDescription = Undefined) Export
	
	SetPrivilegedMode(True);
	
	ItemGroupDescription = NStr("en = 'Personal access groups'");
	
	Query = New Query;
	Query.SetParameter("ItemGroupDescription", ItemGroupDescription);
	Query.Text =
	"SELECT
	|	AccessGroups.Ref
	|FROM
	|	Catalog.AccessGroups AS AccessGroups
	|WHERE
	|	AccessGroups.Description LIKE &ItemGroupDescription
	|	AND AccessGroups.IsFolder";
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		ItemGroup = Selection.Ref;
	ElsIf DoNotCreate Then
		ItemGroup = Undefined;
	Else
		ItemGroupObject = Catalogs.AccessGroups.CreateFolder();
		ItemGroupObject.Description = ItemGroupDescription;
		ItemGroupObject.Write();
		ItemGroup = ItemGroupObject.Ref;
	EndIf;
	
	Return ItemGroup;
	
EndFunction

// For internal use only
Procedure RestoreParticipantCompositionOfAdministratorsAccessGroup(DataItem, SendBack) Export
	
	If DataItem.PredefinedDataName <> "Administrators" Then
		Return;
	EndIf;
	
	DataItem.Users.Clear();
	
	Query = New Query;
	Query.SetParameter("PredefinedDataName", "Administrators");
	Query.Text =
	"SELECT DISTINCT
	|	AccessGroupsUsers.User
	|FROM
	|	Catalog.AccessGroups.Users AS AccessGroupsUsers
	|WHERE
	|	AccessGroupsUsers.Ref.PredefinedDataName = &PredefinedDataName";
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		If DataItem.Users.Find(Selection.User, "User") = Undefined Then
			DataItem.Users.Add().User = Selection.User;
		EndIf;
	EndDo;
	
EndProcedure

 
// Updating infobase

Procedure FillAccessGroupProfileAdministrators() Export
	
	Object = Administrators.GetObject();
	Object.Profile = Catalogs.AccessGroupProfiles.Administrator;
	InfobaseUpdate.WriteData(Object);
	
EndProcedure

#EndRegion

#EndIf