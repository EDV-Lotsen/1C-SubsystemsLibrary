

Var FormerParent;
Var ChangedContentOfRolesOfExternalUserGroups;

// Handler BeforeWrite locks invalid actions with the predefined
// group "All external users".
//
Procedure BeforeWrite(Cancellation)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Ref = Catalogs.ExternalUserGroups.AllExternalUsers Then
		
		AuthorizationObjectType = Undefined;
		AllAuthorizationObjects  = False;
		
		If NOT Parent.IsEmpty() Then
			CommonUseClientServer.MessageToUser(NStr("en = 'Predefined folder ""All external users"" can be only at the root!'"), , , , Cancellation);
			Return;
		EndIf;
		If Content.Count() > 0 Then
			CommonUseClientServer.MessageToUser(NStr("en = 'Adding external users to the folder ""All external users"" is not supported.'"), , , , Cancellation);
			Return;
		EndIf;
	Else
		If Parent = Catalogs.ExternalUserGroups.AllExternalUsers Then
			CommonUseClientServer.MessageToUser(NStr("en = 'Predefined folder ""All external users"" cannot be parent!'"), , , , Cancellation);
			Return;
		EndIf;
		FormerParent = ?(Ref.IsEmpty(), Undefined, CommonUse.GetAttributeValue(Ref, "Parent"));
		
		If AuthorizationObjectType = Undefined Then
			AllAuthorizationObjects = False;
		ElsIf AllAuthorizationObjects And ValueIsFilled(Parent) Then
			CommonUseClientServer.MessageToUser(NStr("en = 'Invalid parent for the specified folder of all objects of the information base!'"), , , , Cancellation);
			Return;
		EndIf;
		
		// Check uniqueness of the group of all authorization objects of the specified type
		If AllAuthorizationObjects Then
			Query = New Query(
			"SELECT
			|	PRESENTATION(ExternalUserGroups.Ref) AS Ref_Presentation
			|FROM
			|	Catalog.ExternalUserGroups AS ExternalUserGroups
			|WHERE
			|	ExternalUserGroups.Ref <> &Ref
			|	And ExternalUserGroups.AuthorizationObjectType = &AuthorizationObjectType
			|	And ExternalUserGroups.AllAuthorizationObjects");
			Query.SetParameter("Ref", Ref);
			Query.SetParameter("AuthorizationObjectType", AuthorizationObjectType);
			Selection = Query.Execute().Choose();
			If Selection.Next() Then
				CommonUseClientServer.MessageToUser(StringFunctionsClientServer.SubstitureParametersInString(NStr("en = 'There is already a folder ""%1"" for all objects of the information base type ""%2""'"), Selection.Ref_Presentation, Metadata.FindByType(TypeOf(AuthorizationObjectType)).Synonym), , , , Cancellation);
				Return;
			EndIf;
		EndIf;
		
		// Check match of the authorization objects type with the parent (valid if parent type is not specified)
		If ValueIsFilled(Parent) Then
			TypeOfParentAuthorizationObjects = CommonUse.GetAttributeValue(Parent, "AuthorizationObjectType");
			If TypeOfParentAuthorizationObjects <> Undefined And
			     TypeOfParentAuthorizationObjects <> AuthorizationObjectType Then
				
				CommonUseClientServer.MessageToUser(StringFunctionsClientServer.SubstitureParametersInString(NStr("en = 'Type of objects of the information base should be ""%1"" like the parent has ""%2""!'"), Metadata.FindByType(TypeOf(TypeOfParentAuthorizationObjects)).Synonym, Parent), , , , Cancellation);
				Return;
			EndIf;
		EndIf;
		
		// Check, that on change of type of the authorization objects there are no subordinate items of another type (type clearing is not allowed)
		If AuthorizationObjectType <> Undefined And ValueIsFilled(Ref) Then
			Query = New Query(
			"SELECT
			|	PRESENTATION(ExternalUserGroups.Ref) AS Ref_Presentation,
			|	ExternalUserGroups.AuthorizationObjectType
			|FROM
			|	Catalog.ExternalUserGroups AS ExternalUserGroups
			|WHERE
			|	ExternalUserGroups.Parent = &Ref
			|	And ExternalUserGroups.AuthorizationObjectType <> &AuthorizationObjectType");
			Query.SetParameter("Ref", Ref);
			Query.SetParameter("AuthorizationObjectType", AuthorizationObjectType);
			Selection = Query.Execute().Choose();
			If Selection.Next() Then
				If Selection.AuthorizationObjectType = Undefined Then
					PresentationOfAnotherTypeOfAuthorizationObject = NStr("en = '<Any type>'");
				Else
					PresentationOfAnotherTypeOfAuthorizationObject = Metadata.FindByType(TypeOf(Selection.AuthorizationObjectType)).Synonym;
				EndIf;
				CommonUseClientServer.MessageToUser(StringFunctionsClientServer.SubstitureParametersInString(NStr("en = 'There is a child folder ""%1"" with another object types of the information base ""%2""'"), Selection.Ref_Presentation, PresentationOfAnotherTypeOfAuthorizationObject), , , , Cancellation);
				Return;
			EndIf;
		EndIf;
		
		//Check if set of roles has been changed.
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
			|		ON (OldRoles.Ref = &GroupExternalUsers)
			|			And (OldRoles.Role = NewRoles.Role)
			|WHERE
			|	OldRoles.Role IS NULL 
			|
			|UNION ALL
			|
			|SELECT TOP 1
			|	TRUE
			|FROM
			|	(SELECT
			|		TRUE AS ValueTrue) AS ValueTrue
			|		INNER JOIN Catalog.ExternalUserGroups.Roles AS OldRoles
			|		ON (OldRoles.Ref = &GroupExternalUsers)
			|		LEFT JOIN NewRoles AS NewRoles
			|		ON (OldRoles.Role = NewRoles.Role)
			|WHERE
			|	NewRoles.Role IS NULL ");
			Query.SetParameter("GroupExternalUsers", Ref);
			Query.SetParameter("NewRoles", Roles.Unload());
			ChangedContentOfRolesOfExternalUserGroups = NOT Query.Execute().IsEmpty();
		Else
			ChangedContentOfRolesOfExternalUserGroups = True;
		EndIf;
		
	EndIf;
	
EndProcedure

// Handler OnWrite calls update of the group set of the external users.
//
Procedure OnWrite(Cancellation)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	ModifiedExternalUsers = Undefined;
	ExternalUsers.RefreshExternalUserGroupsContent(Ref, ModifiedExternalUsers);
	
	If Ref = Catalogs.ExternalUserGroups.AllExternalUsers Then
		
		Query = New Query(
		"SELECT
		|	UserGroupMembers.User
		|FROM
		|	InformationRegister.UserGroupMembers AS UserGroupMembers
		|WHERE
		|	UserGroupMembers.UsersGroup = VALUE(Catalog.ExternalUserGroups.AllExternalUsers)");
		ModifiedExternalUsers = Query.Execute().Unload().UnloadColumn("User");
		
	ElsIf ChangedContentOfRolesOfExternalUserGroups Then
		
		Query = New Query(
		"SELECT
		|	UserGroupMembers.User
		|FROM
		|	InformationRegister.UserGroupMembers AS UserGroupMembers
		|WHERE
		|	UserGroupMembers.User In(&ModifiedExternalUsers)
		|
		|UNION
		|
		|SELECT
		|	ExternalUserGroupsContent.ExternalUser
		|FROM
		|	Catalog.ExternalUserGroups.Content AS ExternalUserGroupsContent
		|WHERE
		|	ExternalUserGroupsContent.Ref = &GroupExternalUsers
		|	And (NOT ExternalUserGroupsContent.ExternalUser.SetRolesDirectly)");
		Query.SetParameter("GroupExternalUsers",    Ref);
		Query.SetParameter("ModifiedExternalUsers", ModifiedExternalUsers);
		ModifiedExternalUsers = Query.Execute().Unload().UnloadColumn("User");
	EndIf;
		
	AreErrors = False;
	ExternalUsers.RefreshExternalUserRoles(ModifiedExternalUsers, AreErrors);
	
	If ValueIsFilled(FormerParent) And FormerParent <> Parent Then
		
		ExternalUsers.RefreshExternalUserGroupsContent(FormerParent, ModifiedExternalUsers);
		ExternalUsers.RefreshExternalUserRoles(ModifiedExternalUsers, AreErrors);
	EndIf;
	
	If AreErrors And NOT AdditionalProperties.Property("AreErrors") Then
		AdditionalProperties.Insert("AreErrors");
	EndIf;
	
EndProcedure

// Handler FillCheckProcessing locks interactive choice of the group "All external users" as a parent group.
//
Procedure FillCheckProcessing(Cancellation, CheckedAttributes)
	
	If Parent = Catalogs.ExternalUserGroups.AllExternalUsers Then
		CommonUseClientServer.MessageToUser(NStr("en = 'Predefined folder ""All external users"" cannot be parent!'"), , "Object.Parent", , Cancellation);
	EndIf;
	
EndProcedure

