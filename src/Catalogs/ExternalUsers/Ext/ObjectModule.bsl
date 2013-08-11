////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If InfoBaseUserID <> New UUID("00000000-0000-0000-0000-000000000000") And
	 Users.UserByIDExists(InfoBaseUserID, Ref) Then
		Raise NStr("en = 'Every infobase user can correspond to single user or single external user only.'");
	EndIf;
	
	If Not ValueIsFilled(AuthorizationObject) Then
		Raise NStr("en = 'The authorization object for the external user is not specified.'");
	Else
		If ExternalUsers.AuthorizationObjectUsed(AuthorizationObject, Ref) Then
			Raise NStr("en = 'The authorization object is used for another external user.'");
		EndIf;
	EndIf;
	
	// Checking whether the authorization object is not changed
	If Not IsNew() Then
		OldAuthorizationObject = CommonUse.GetAttributeValue(Ref, "AuthorizationObject");
		If ValueIsFilled(OldAuthorizationObject) And OldAuthorizationObject <> AuthorizationObject Then
			Raise NStr("en = 'The infobase object cannot be changed.'");
		EndIf;
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	// Updating the All external users group composition. This group is generated automatically
	ModifiedExternalUsers = Undefined;
	ExternalUsers.UpdateExternalUserGroupContent(Catalogs.ExternalUserGroups.AllExternalUsers, ModifiedExternalUsers);
	ModifiedExternalUsers.Add(Ref);
	ExternalUsers.UpdateExternalUserRoles(ModifiedExternalUsers);
	
	// Updating the <All authorization objects of the same type> group composition. 
	// This group is generated automatically.
	If ValueIsFilled(AuthorizationObject) Then
		Query = New Query(
		"SELECT
		|	ExternalUserGroups.Ref
		|FROM
		|	Catalog.ExternalUserGroups AS ExternalUserGroups
		|WHERE
		|	ExternalUserGroups.AllAuthorizationObjects
		|	AND VALUETYPE(ExternalUserGroups.AuthorizationObjectType) = &AuthorizationObjectType");
		Query.SetParameter("AuthorizationObjectType", TypeOf(AuthorizationObject));
		Selection = Query.Execute().Choose();
		
		If Selection.Next() Then
			ExternalUsers.UpdateExternalUserGroupContent(Selection.Ref, ModifiedExternalUsers);
			ExternalUsers.UpdateExternalUserRoles(ModifiedExternalUsers);
		EndIf;
	EndIf;
	
	// Updating the new external user group composition if the group is specified
	If AdditionalProperties.Property("NewExternalUserGroup") And
	 ValueIsFilled(AdditionalProperties.NewExternalUserGroup) Then
		
		GroupObject = AdditionalProperties.NewExternalUserGroup.GetObject();
		GroupObject.Content.Add().ExternalUser = Ref;
		GroupObject.Write();
		ExternalUsers.UpdateExternalUserGroupContent(GroupObject.Ref, ModifiedExternalUsers);
		ExternalUsers.UpdateExternalUserRoles(ModifiedExternalUsers);
	EndIf;
	
EndProcedure

Procedure BeforeDelete(Cancel)
	
	// The infobase user must be deleted because otherwise this user will be included into
	// the error list of the InfoBaseUsers form, in addition, starting the infobase on 
	// behalf of this user will raise an error.
	If Users.InfoBaseUserExists(InfoBaseUserID) Then
		
		Cancel = Not Users.DeleteInfoBaseUser(InfoBaseUserID);
	EndIf;
	
	// The DataExchange.Load check must be placed here.
	
EndProcedure
