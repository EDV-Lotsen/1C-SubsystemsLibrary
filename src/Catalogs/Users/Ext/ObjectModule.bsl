

Procedure BeforeWrite(Cancellation)
	
	If IBUserID <> New UUID("00000000-0000-0000-0000-000000000000") And
	     Users.UserByIDExists(IBUserID, Ref) Then
	
		Raise(NStr("en = 'One information base user can be connected only with one user of external user!'"));
	EndIf;
	
//If DataExchange.Load Then
//	Return;
//EndIf;
	
EndProcedure

Procedure OnWrite(Cancellation)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	
	RecordManager = InformationRegisters.UserGroupMembers.CreateRecordManager();
	RecordManager.UsersGroup = Ref;
	RecordManager.User       = Ref;
	RecordManager.Read();
	If NOT RecordManager.Selected() Then
		RecordManager.UsersGroup = Ref;
		RecordManager.User       = Ref;
		RecordManager.Write();
		// Update content of the automatic folder "All users".
		Users.RefreshUserGroupsContent(Catalogs.UserGroups.AllUsers);
		
		If AdditionalProperties.Property("GroupNewUser") And
		     ValueIsFilled(AdditionalProperties.GroupNewUser) Then
			
			GroupObject = AdditionalProperties.GroupNewUser.GetObject();
			GroupObject.Content.Add().User = Ref;
			GroupObject.Write();
			Users.RefreshUserGroupsContent(GroupObject.Ref);
		EndIf;
	EndIf;
	
	
EndProcedure

Procedure BeforeDelete(Cancellation)
	
	If Users.IBUserExists(IBUserID) Then
		ErrorDescription = "";
		If NOT Users.DeleteIBUsers(IBUserID, ErrorDescription) Then
			Raise(ErrorDescription);
		EndIf;
	EndIf;
	
EndProcedure
