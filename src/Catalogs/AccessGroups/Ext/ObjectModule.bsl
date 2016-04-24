#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

Var OldProfile;      // Access group profile before changing that can be
                     // used in the OnWrite event handler.

Var OldDeletionMark; // Access group deletion mark before changing that can be
                     // used in the OnWrite event handler.

Var OldParticipants; // Access group participants before changing that can be
                     // used in the OnWrite event handler.

#Region EventHandlers

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If IsFolder Then
		Return;
	EndIf;
	
	If Not AdditionalProperties.Property("DoNotUpdateUserRoles") Then
		If ValueIsFilled(Ref) Then
			OldUsersTable   = CommonUse.ObjectAttributeValue(Ref, "Users");
			OldParticipants = OldUsersTable.Unload().UnloadColumn("User");
		Else
			OldParticipants = New Array;
		EndIf;
	EndIf;
	
	OldValues       = CommonUse.ObjectAttributeValues(
		Ref, "Profile, DeletionMark");
	
	OldProfile      = OldValues.Profile;
	OldDeletionMark = OldValues.DeletionMark;
	
	If Ref = Catalogs.AccessGroups.Administrators Then
		
		// Administrator predefined profile is always used
		Profile = Catalogs.AccessGroupProfiles.Administrator;
		
		// Cannot be a personal access group
		User = Undefined;
		
		// Cannot have a regular manager (only full access users)
		Responsible = Undefined;
		
		// Only regular users
		UserType = Catalogs.Users.EmptyRef();
		
		// Only full access users are allowed to make changes
		If Not PrivilegedMode()
		And Not AccessManagement.RoleExists("FullAccess") Then
			
			Raise NStr("en = 'Administrators predefined access group can be changed either in the privileged mode or by users with Full access role.'");
		EndIf;
		
		// Checking whether the access group contains regular users only
		For Each CurrentRow In ThisObject.Users Do
			If TypeOf(CurrentRow.User) <> Type("CatalogRef.Users") Then
				
				Raise NStr("en = 'Administrators predefined access group can only contain regular users. User groups, external users, and external user groups are prohibited.'");
			EndIf;
		EndDo;
		
	  // Administrator predefined profile cannot be set for non-Administrators access groups
	ElsIf Profile = Catalogs.AccessGroupProfiles.Administrator Then
		Raise NStr("en = 'Only Administrators predefined access group can have Administrator predefined profile'");
	EndIf;
	
	If Not IsFolder Then
		
		// Automatically setting the attributes for the personal access group
		If ValueIsFilled(User) Then
			Parent   = Catalogs.AccessGroups.PersonalAccessGroupParent();
			UserType = Undefined;
		Else
			User     = Undefined;
			If Parent = Catalogs.AccessGroups.PersonalAccessGroupParent(True) Then
				 Parent = Undefined;
			EndIf;
		EndIf;
		
		// When clearing the deletion mark from an access group, the deletion mark is
   // also cleared from its profile.
		If Not DeletionMark
		   And OldDeletionMark = True
		   And CommonUse.ObjectAttributeValue(Profile, "DeletionMark") = True Then
			
			LockDataForEdit(Profile);
			ProfileObject = Profile.GetObject();
			ProfileObject.DeletionMark = False;
			ProfileObject.Write();
		EndIf;
	EndIf;
	
EndProcedure

// Updates:
// - roles of added, remaining and deleted users;
// - InformationRegister.AccessGroupTables;
// - InformationRegister.AccessGroupValues.
 
Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If IsFolder Then
		Return;
	EndIf;
	
	If Not AdditionalProperties.Property("DoNotUpdateUserRoles") Then
		
		If CommonUseCached.DataSeparationEnabled()
			And Ref = Catalogs.AccessGroups.Administrators
			And Not CommonUseCached.SessionWithoutSeparators()
			And AdditionalProperties.Property("ServiceUserPassword") Then
			
			ServiceUserPassword = AdditionalProperties.ServiceUserPassword;
		Else
			ServiceUserPassword = Undefined;
		EndIf;
		
		UpdateUserRolesOnChangeAccessGroup(ServiceUserPassword);
	EndIf;
	
	If Profile      <> OldProfile
  Or DeletionMark <> OldDeletionMark Then
		
		InformationRegisters.AccessGroupTables.UpdateRegisterData(Ref);
	EndIf;
	
	InformationRegisters.AccessGroupValues.UpdateRegisterData(Ref);
	
EndProcedure

Procedure FillCheckProcessing(Cancel, AttributesToCheck)
	
	If AdditionalProperties.Property("CheckedObjectAttributes") Then
		CommonUse.DeleteNoCheckAttributesFromArray(
			AttributesToCheck, AdditionalProperties.CheckedObjectAttributes);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions

Procedure UpdateUserRolesOnChangeAccessGroup(ServiceUserPassword)
	
	SetPrivilegedMode(True);
	
	// Updating roles for added, remaining and deleted users
	Query = New Query;
	Query.SetParameter("AccessGroup",   Ref);
	Query.SetParameter("OldParticipants", OldParticipants);
	
	If Profile       <> OldProfile
	 Or DeletionMark <> OldDeletionMark Then
		
		// Selecting all access group participants, both old and new
		Query.Text =
		"SELECT DISTINCT
		|	Data.User
		|FROM
		|	(SELECT DISTINCT
		|		UserGroupContent.User AS User
		|	FROM
		|		InformationRegister.UserGroupContent AS UserGroupContent
		|	WHERE
		|		UserGroupContent.UserGroup IN(&OldParticipants)
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		UserGroupContent.User
		|	FROM
		|		Catalog.AccessGroups.Users AS AccessGroupsUsers
		|			INNER JOIN InformationRegister.UserGroupContent AS UserGroupContent
		|			ON AccessGroupsUsers.User = UserGroupContent.UserGroup
		|				AND (AccessGroupsUsers.Ref = &AccessGroup)) AS Data";
	Else
		// Selecting only the access group participants that were modified
		Query.Text =
		"SELECT
		|	Data.User
		|FROM
		|	(SELECT DISTINCT
		|		UserGroupContent.User AS User,
		|		-1 AS RowChangeKind
		|	FROM
		|		InformationRegister.UserGroupContent AS UserGroupContent
		|	WHERE
		|		UserGroupContent.UserGroup IN(&OldParticipants)
		|	
		|	UNION ALL
		|	
		|	SELECT DISTINCT
		|		UserGroupContent.User,
		|		1
		|	FROM
		|		Catalog.AccessGroups.Users AS AccessGroupsUsers
		|			INNER JOIN InformationRegister.UserGroupContent AS UserGroupContent
		|			ON AccessGroupsUsers.User = UserGroupContent.UserGroup
		|				AND (AccessGroupsUsers.Ref = &AccessGroup)) AS Data
		|
		|GROUP BY
		|	Data.User
		|
		|HAVING
		|	SUM(Data.RowChangeKind) <> 0";
	EndIf;
	UsersForUpdate = Query.Execute().Unload().UnloadColumn("User");
	
	If Ref = Catalogs.AccessGroups.Administrators Then
		// Adding users associated with infobase users with the FullAccess role
		
		For Each IBUser In InfobaseUsers.GetUsers() Do
			If IBUser.Roles.Contains(Metadata.Roles.FullAccess) Then
				
				FoundUser = Catalogs.Users.FindByAttribute(
					"InfobaseUserID", IBUser.UUID);
				
				If Not ValueIsFilled(FoundUser) Then
					FoundUser = Catalogs.ExternalUsers.FindByAttribute(
						"InfobaseUserID", IBUser.UUID);
				EndIf;
				
				If ValueIsFilled(FoundUser)
				   And UsersForUpdate.Find(FoundUser) = Undefined Then
					
					UsersForUpdate.Add(FoundUser);
				EndIf;
				
			EndIf;
		EndDo;
	EndIf;
	
	AccessManagement.UpdateUserRoles(UsersForUpdate, ServiceUserPassword);
	
EndProcedure

#EndRegion

#EndIf