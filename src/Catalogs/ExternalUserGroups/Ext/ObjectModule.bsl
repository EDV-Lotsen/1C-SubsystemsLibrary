// The group parent value to use it in the OnWrite event handler
Var OldParent; 


// A flag that shows whether a role composition is changed.
// IsExternalUserGroupRoleContentChanged is used in the OnWrite
// event handler.
Var IsExternalUserGroupRoleContentChanged; 

////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS

// Prevents invalid actions with the AllExternalUsers predefined group.
//
Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Ref = Catalogs.ExternalUserGroups.AllExternalUsers Then
		
		AuthorizationObjectType = Undefined;
		AllAuthorizationObjects = False;
		
		If Not Parent.IsEmpty() Then
			CommonUseClientServer.MessageToUser(
				NStr("en = 'The All external users predefined group can be placed only in the root.'"),
				, , , Cancel);
			Return;
		EndIf;
		If Content.Count() > 0 Then
			CommonUseClientServer.MessageToUser(
				NStr("en = 'Users cannot be added to the All external users predefined group.'"),
				, , , Cancel);
			Return;
		EndIf;
	Else
		If Parent = Catalogs.ExternalUserGroups.AllExternalUsers Then
			CommonUseClientServer.MessageToUser(
				NStr("en = 'The All external users predefined group cannot have subgroups.'"),
				, , , Cancel);
			Return;
		EndIf;
		OldParent = ?(Ref.IsEmpty(), Undefined, CommonUse.GetAttributeValue(Ref, "Parent"));
		
		If AuthorizationObjectType = Undefined Then
			AllAuthorizationObjects = False;
		ElsIf AllAuthorizationObjects And ValueIsFilled(Parent) Then
			CommonUseClientServer.MessageToUser(
				NStr("en = 'A group of all infobase authorization objects of the specified type cannot have parent groups.'"),
				, , , Cancel);
			Return;
		EndIf;
		
		// Checking whether the group of all authorization objects of the specified type is unique
		If AllAuthorizationObjects Then
			Query = New Query(
			"SELECT
			|	PRESENTATION(ExternalUserGroups.Ref) AS RefPresentation
			|FROM
			|	Catalog.ExternalUserGroups AS ExternalUserGroups
			|WHERE
			|	ExternalUserGroups.Ref <> &Ref
			|	AND ExternalUserGroups.AuthorizationObjectType = &AuthorizationObjectType
			|	AND ExternalUserGroups.AllAuthorizationObjects");
			Query.SetParameter("Ref", Ref);
			Query.SetParameter("AuthorizationObjectType", AuthorizationObjectType);
			Selection = Query.Execute().Select();
			If Selection.Next() Then
				CommonUseClientServer.MessageToUser(
					StringFunctionsClientServer.SubstituteParametersInString(
						NStr("en = 'There is existed group %1 for all infobase object of the %2 type.'"),
						Selection.RefPresentation,
						AuthorizationObjectType.Metadata().Synonym),
					, , , Cancel);
				Return;
			EndIf;
		EndIf;
		
		// Checking whether the authorization object type match a parent type (parent type can be not defined)
		If ValueIsFilled(Parent) Then
			ParentAuthorizationObjectType = CommonUse.GetAttributeValue(Parent, "AuthorizationObjectType");
			If ParentAuthorizationObjectType <> Undefined And
			 ParentAuthorizationObjectType <> AuthorizationObjectType Then
				
				CommonUseClientServer.MessageToUser(
					StringFunctionsClientServer.SubstituteParametersInString(
						NStr("en = 'The infobase object type must be equal to the parent type (%1). The parent is %2. '"),
						ParentAuthorizationObjectType.Metadata().Synonym, Parent),
					, , , Cancel);
				Return;
			EndIf;
		EndIf;
		
		// Checking that the authorization object with a changed type does not have child items with a different type (type can be cleared).
		If AuthorizationObjectType <> Undefined And ValueIsFilled(Ref) Then
			Query = New Query(
			"SELECT
			|	PRESENTATION(ExternalUserGroups.Ref) AS RefPresentation,
			|	ExternalUserGroups.AuthorizationObjectType
			|FROM
			|	Catalog.ExternalUserGroups AS ExternalUserGroups
			|WHERE
			|	ExternalUserGroups.Parent = &Ref
			|	AND ExternalUserGroups.AuthorizationObjectType <> &AuthorizationObjectType");
			Query.SetParameter("Ref", Ref);
			Query.SetParameter("AuthorizationObjectType", AuthorizationObjectType);
			Selection = Query.Execute().Select();
			If Selection.Next() Then
				If Selection.AuthorizationObjectType = Undefined Then
					OtherAuthorizationObjectTypePresentation = NStr("en = '<Any type>'");
				Else
					OtherAuthorizationObjectTypePresentation = Selection.AuthorizationObjectType.Metadata().Synonym;
				EndIf;
				CommonUseClientServer.MessageToUser(
					StringFunctionsClientServer.SubstituteParametersInString(
						NStr("en = 'There is subgroup %1 with a different type of infobase objects (%2).'"),
						Selection.RefPresentation,
						OtherAuthorizationObjectTypePresentation),
					, , , Cancel);
				Return;
			EndIf;
		EndIf;
		
		// Checking whether the role composition has been changed
		If ValueIsFilled(Ref) Then
			Query = New Query(
			"SELECT
			|	NewRoles.Role
			|INTO NewRoles
			|FROM
			|	&NewRoles AS NewRoles
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT TOP 1
			|	TRUE AS Value
			|FROM
			|	NewRoles AS NewRoles
			|		LEFT JOIN Catalog.ExternalUserGroups.Roles AS OldRoles
			|			ON (OldRoles.Ref = &ExternalUserGroup)
			|			AND (OldRoles.Role = NewRoles.Role)
			|WHERE
			|	OldRoles.Role IS NULL 
			|
			|UNION ALL
			|
			|SELECT TOP 1
			|	TRUE
			|FROM
			|	(SELECT
			|		TRUE AS TrueValue) AS TrueValue
			|		INNER JOIN Catalog.ExternalUserGroups.Roles AS OldRoles
			|			ON (OldRoles.Ref = &ExternalUserGroup)
			|		LEFT JOIN NewRoles AS NewRoles
			|			ON (OldRoles.Role = NewRoles.Role)
			|WHERE
			|	NewRoles.Role IS NULL ");
			Query.SetParameter("ExternalUserGroup", Ref);
			Query.SetParameter("NewRoles", Roles.Unload());
			IsExternalUserGroupRoleContentChanged = Not Query.Execute().IsEmpty();
		Else
			IsExternalUserGroupRoleContentChanged = True;
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	ModifiedExternalUsers = Undefined;
	ExternalUsers.UpdateExternalUserGroupContent(Ref, ModifiedExternalUsers);
	
	If Ref = Catalogs.ExternalUserGroups.AllExternalUsers Then
		
		Query = New Query(
		"SELECT
		|	UserGroupContent.User
		|FROM
		|	InformationRegister.UserGroupContent AS UserGroupContent
		|WHERE
		|	UserGroupContent.UserGroup = VALUE(Catalog.ExternalUserGroups.AllExternalUsers)");
		ModifiedExternalUsers = Query.Execute().Unload().UnloadColumn("User");
		
	ElsIf IsExternalUserGroupRoleContentChanged Then
		
		Query = New Query(
		"SELECT
		|	UserGroupContent.User
		|FROM
		|	InformationRegister.UserGroupContent AS UserGroupContent
		|WHERE
		|	UserGroupContent.User IN(&ModifiedExternalUsers)
		|
		|UNION
		|
		|SELECT
		|	ExternalUserGroupContent.ExternalUser
		|FROM
		|	Catalog.ExternalUserGroups.Content AS ExternalUserGroupContent
		|WHERE
		|	ExternalUserGroupContent.Ref = &ExternalUserGroup
		|	AND (NOT ExternalUserGroupContent.ExternalUser.SetRolesDirectly)");
		Query.SetParameter("ExternalUserGroup", Ref);
		Query.SetParameter("ModifiedExternalUsers", ModifiedExternalUsers);
		ModifiedExternalUsers = Query.Execute().Unload().UnloadColumn("User");
	EndIf;
		
	ExternalUsers.UpdateExternalUserRoles(ModifiedExternalUsers);
	
	If ValueIsFilled(OldParent) And OldParent <> Parent Then
		
		ExternalUsers.UpdateExternalUserGroupContent(OldParent, ModifiedExternalUsers);
		ExternalUsers.UpdateExternalUserRoles(ModifiedExternalUsers);
	EndIf;
	
EndProcedure

Procedure FillCheckProcessing(Cancel, AttributesToCheck)
	
	CheckedObjectAttributes = New Array;
	Errors = Undefined;
	
	// Checking whether AllUsers has subgroups
	If Parent = Catalogs.ExternalUserGroups.AllExternalUsers Then
		CommonUseClientServer.AddUserError(Errors,
			"Object.Parent",
			NStr("en = 'The All users predefined group cannot have subgroups.'"));
	EndIf;
	
	// Checking whether there are empty or repeated external users
	CheckedObjectAttributes.Add("Content.ExternalUser");
	
	For Each CurrentRow In Content Do
		LineNumber = Content.IndexOf(CurrentRow);
		
		// Checking whether the value is filled
		If Not ValueIsFilled(CurrentRow.ExternalUser) Then
			CommonUseClientServer.AddUserError(Errors,
				"Object.Content[%1].ExternalUser",
				NStr("en = 'External user is not selected.'"),
				"Object.Content",
				LineNumber,
				NStr("en = 'External user in the row #%1 is not selected.'"));
			Continue;
		EndIf;
		
		// Checking whether there are repeated values
		FoundValues = Content.FindRows(New Structure("ExternalUser", CurrentRow.ExternalUser));
		If FoundValues.Count() > 1 Then
			CommonUseClientServer.AddUserError(Errors,
				"Object.Content[%1].ExternalUser",
				NStr("en = 'Repeated external user.'"),
				"Object.Content",
				LineNumber,
				NStr("en = 'There is a repeated external user in the row #%1.'"));
		EndIf;
	EndDo;
	
	CommonUseClientServer.ShowErrorsToUser(Errors, Cancel);
	
	CommonUse.DeleteNoncheckableAttributesFromArray(AttributesToCheck, CheckedObjectAttributes);
	
EndProcedure







