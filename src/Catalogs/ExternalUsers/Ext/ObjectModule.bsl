

Procedure BeforeWrite(Cancellation)
	
	If IBUserID <> New UUID("00000000-0000-0000-0000-000000000000") And
	     Users.UserByIDExists(IBUserID, Ref) Then
	     
		CommonUseClientServer.MessageToUser(NStr("en = 'One Information base user can be connected only with one user of external user!'"), , , , Cancellation);
		Return;
	EndIf;
	
	If NOT ValueIsFilled(AuthorizationObject) Then
		CommonUseClientServer.MessageToUser(NStr("en = 'The authorization object is not to set for external user!'"), , , , Cancellation);
		Return;
	Else
		If ExternalUsers.AuthorizationObjectLinkedToExternalUser(AuthorizationObject, Ref) Then
			CommonUseClientServer.MessageToUser(NStr("en = 'The authorization object is already in use already by another external user.'"), , , , Cancellation);
			Return;
		EndIf;
	EndIf;
	
	// Check that authorization object has not been modified
	If NOT IsNew() Then
		OldAuthorizationObject = CommonUse.GetAttributeValue(Ref, "AuthorizationObject");
		If ValueIsFilled(OldAuthorizationObject) And OldAuthorizationObject <> AuthorizationObject Then
			CommonUseClientServer.MessageToUser(NStr("en = 'Object of the Information base cannot be changed!'"), , , , Cancellation);
			Return;
		EndIf;
	EndIf;
	
	// Autoupdate description based on the authorization object presentation.
	SetPrivilegedMode(True);
	Description = String(AuthorizationObject);
	SetPrivilegedMode(False);
	
	//If DataExchange.Load Then
	//	Return;
	//EndIf;
	
EndProcedure

Procedure OnWrite(Cancellation)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	
	AreErrors = False;
	
	RecordManager 			 = InformationRegisters.UserGroupMembers.CreateRecordManager();
	RecordManager.UsersGroup = Ref;
	RecordManager.User       = Ref;
	RecordManager.Read();
	If NOT RecordManager.Selected() Then
		RecordManager.UsersGroup  = Ref;
		RecordManager.User        = Ref;
		RecordManager.Write();
		// Update content of the automatic group "All external users".
		ModifiedExternalUsers = Undefined;
		ExternalUsers.RefreshExternalUserGroupsContent(Catalogs.ExternalUserGroups.AllExternalUsers, ModifiedExternalUsers);
		ExternalUsers.RefreshExternalUserRoles(ModifiedExternalUsers, AreErrors);
		
		// Update content of the automatic group <all authorization objects of the same type> (if exist).
		If ValueIsFilled(AuthorizationObject) Then
			Query = New Query(
			"SELECT
			|	ExternalUserGroups.Ref
			|FROM
			|	Catalog.ExternalUserGroups AS ExternalUserGroups
			|WHERE
			|	ExternalUserGroups.AllAuthorizationObjects
			|	And VALUETYPE(ExternalUserGroups.AuthorizationObjectType) = &AuthorizationObjectType");
			Query.SetParameter("AuthorizationObjectType", TypeOf(AuthorizationObject));
			Selection = Query.Execute().Choose();
			
			If Selection.Next() Then
				ExternalUsers.RefreshExternalUserGroupsContent(Selection.Ref, ModifiedExternalUsers);
				ExternalUsers.RefreshExternalUserRoles(ModifiedExternalUsers, AreErrors);
			EndIf;
		EndIf;
		
		// Update group content of the new external user (if specified).
		If AdditionalProperties.Property("GroupNewExternalUser") And
		     ValueIsFilled(AdditionalProperties.GroupNewExternalUser) Then
			
			GroupObject = AdditionalProperties.GroupNewExternalUser.GetObject();
			GroupObject.Content.Add().ExternalUser = Ref;
			GroupObject.Write();
			ExternalUsers.RefreshExternalUserGroupsContent(GroupObject.Ref, ModifiedExternalUsers);
			ExternalUsers.RefreshExternalUserRoles(ModifiedExternalUsers, AreErrors);
		EndIf;
	Else
		ModifiedExternalUsers = New Array;
		ModifiedExternalUsers.Add(Ref);
		ExternalUsers.RefreshExternalUserRoles(ModifiedExternalUsers, AreErrors);
	EndIf;
	
	If AreErrors And NOT AdditionalProperties.Property("AreErrors") Then
		AdditionalProperties.Insert("AreErrors");
	EndIf;
	
EndProcedure

Procedure BeforeDelete(Cancellation)
	
	If Users.IBUserExists(IBUserID) Then
		
		Cancellation = NOT Users.DeleteIBUsers(IBUserID);
	EndIf;
	
EndProcedure

