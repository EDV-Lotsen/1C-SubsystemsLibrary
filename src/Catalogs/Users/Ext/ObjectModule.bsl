
// A flag that shows whether the first administrator is
// being recorded. It can be set when an infobase user is processed.
// FirstAdministratorRecord is used in the OnWrite event handler.
Var FirstAdministratorRecord; 

////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// The object interface is implemented with the following AdditionalProperties:
//
//  InfoBaseAccessAllowed     - flag that shows whether there is an infobase user
//                              associated to this item.
//
//  InfoBaseUserInfoStructure - infobase user properties, they are used only
//                              if InfoBaseAccessAllowed is True.
//                              See Users.NewInfoBaseUserInfo for property contents.

////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If StandardSubsystemsOverridable.IsSharedInfoBaseUser(InfoBaseUserID) Then
		Return;
	EndIf;
	
	FirstAdministratorRecord = False;
	
	StandardSubsystemsOverridable.BeforeWriteUser(ThisObject);
	
	If AdditionalProperties.Property("InfoBaseAccessAllowed") Then
		ProcessInfoBaseUser(Cancel);
	EndIf;
	
	If Cancel Then
		Return;
	EndIf;
	
	If InfoBaseUserID <> New UUID("00000000-0000-0000-0000-000000000000")
		And Users.UserByIDExists(InfoBaseUserID, Ref) Then
		
		Raise(NStr("en = 'Every infobase user can correspond to a single user or single external user only.'"));
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If StandardSubsystemsOverridable.IsSharedInfoBaseUser(InfoBaseUserID) Then
		Return;
	EndIf;
	
	If AdditionalProperties.Property("NewUserGroup")
		And ValueIsFilled(AdditionalProperties.NewUserGroup) Then
		
		GroupObject = AdditionalProperties.NewUserGroup.GetObject();
		GroupObject.Content.Add().User = Ref;
		GroupObject.Write();
		Users.UpdateUserGroupContent(GroupObject.Ref);
	EndIf;
	
	Users.UpdateUserGroupContent(Catalogs.UserGroups.AllUsers);
	
	If FirstAdministratorRecord Then
		SetPrivilegedMode(True);
		
		UsersOverridable.OnWriteFirstAdministrator(Ref);
		
		SetPrivilegedMode(False);
	EndIf;
	
EndProcedure

Procedure BeforeDelete(Cancel)
	
	If StandardSubsystemsOverridable.IsSharedInfoBaseUser(InfoBaseUserID) Then
		Return;
	EndIf;
	
	// The infobase user must be deleted because otherwise this user will be included 
	// into the error list of the InfoBaseUsers form, in addition, starting the infobase  
	// on behalf of this user will raise an error.
	If Users.InfoBaseUserExists(InfoBaseUserID) Then
		ErrorDescription = "";
		If Not Users.DeleteInfoBaseUser(InfoBaseUserID, ErrorDescription) Then
			Raise(ErrorDescription);
		EndIf;
	EndIf;
	
	// The DataExchange.Load check must be placed here.
	
EndProcedure

Procedure OnCopy(CopiedObject)
	
	InfoBaseUserID = Undefined;
	ServiceUserID = Undefined;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

Procedure ProcessInfoBaseUser(Cancel)
	
	AccessLevel = Users.GetEditInfoBaseUserPropertiesAccessLevel();
	
	If AccessLevel = "AccessDenied" Then
		MessageText = NStr("en = 'Insufficient rights to change infobase users.'");
		CommonUseClientServer.MessageToUser(MessageText, , , , Cancel);
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	AdditionalProperties.Insert("InfoBaseUserExists", 
		InfoBaseUsers.FindByUUID(InfoBaseUserID) <> Undefined);
		
	If AccessLevel <> "FullAccess" And AccessLevel <> "ListManagement"
		And AdditionalProperties.InfoBaseUserExists <> AdditionalProperties.InfoBaseAccessAllowed Then
		
		MessageText = NStr("en = 'Insufficient rights to change infobase users.");
		CommonUseClientServer.MessageToUser(MessageText, , , , Cancel);
		Return;
	EndIf;
	
	If AdditionalProperties.InfoBaseAccessAllowed Then
		// Checking whether the user has rights to change properties.
		InfoBaseUserInfoStructure = AdditionalProperties.InfoBaseUserInfoStructure;
		
		If AccessLevel = "ListManagement" Then
			If InfoBaseUserInfoStructure.Property("InfoBaseUserRoles") Then
				MessageText = NStr("en = 'Insufficient rights to change infobase user roles.");
				CommonUseClientServer.MessageToUser(MessageText, , , , Cancel);
				Return;
			EndIf;
		ElsIf AccessLevel = "ChangeCurrent" Then
			ValidProperties = New Array;
			ValidProperties.Add("InfoBaseUserName");
			ValidProperties.Add("InfoBaseUserPassword");
			ValidProperties.Add("InfoBaseUserLanguage");
			ValidProperties.Add("PasswordConfirmation");
			For Each KeyAndValue In InfoBaseUserInfoStructure Do
				If ValidProperties.Find(KeyAndValue.Key) = Undefined Then
					MessageText = NStr("en = 'Insufficient rights to change infobase users.'");
					CommonUseClientServer.MessageToUser(MessageText, , , , Cancel);
					Return;
				EndIf;
			EndDo;
		EndIf;
		
		WriteIBUser(Cancel);
	Else
		If AdditionalProperties.InfoBaseUserExists Then
			DeleteInfoBaseUser(Cancel);
		EndIf;
	EndIf;
	
EndProcedure

Procedure WriteIBUser(Cancel)
	
	InfoBaseUserInfoStructure = AdditionalProperties.InfoBaseUserInfoStructure;
	If InfoBaseUserInfoStructure.Count() = 0 Then
		Return;
	EndIf;
	
	If InfoBaseUserInfoStructure.Property("InfoBaseUserRoles") Then
		Roles = InfoBaseUserInfoStructure.InfoBaseUserRoles;
	Else
		Roles = Undefined;
	EndIf;
	
	If Users.CreateFirstAdministratorRequired(InfoBaseUserInfoStructure) Then
		FirstAdministratorRecord = True;
		Roles = New Array;
		Roles.Add("FullAccess");
		
		FullAdministratorRoleName = Users.FullAdministratorRole().Name;
		If Roles.Find(FullAdministratorRoleName) = Undefined Then
			Roles.Add(FullAdministratorRoleName);
		EndIf;
	EndIf;
	
	// Attempting to record the infobase user.
	NewInfoBaseUserCreated = False;
	ErrorDescription = "";
	If Users.WriteIBUser(InfoBaseUserID,
		InfoBaseUserInfoStructure, Roles, Not AdditionalProperties.InfoBaseUserExists, ErrorDescription) Then
		
		If Not AdditionalProperties.InfoBaseUserExists Then
			NewInfoBaseUserCreated = True;
			InfoBaseUserID = InfoBaseUserInfoStructure.InfoBaseUserUUID;
			AdditionalProperties.InfoBaseUserExists = True;
		EndIf;
	Else
		Cancel = True;
		CommonUseClientServer.MessageToUser(ErrorDescription);
	EndIf;
	
	If Not Cancel Then
		If NewInfoBaseUserCreated Then
			AdditionalProperties.Insert("InfoBaseUserAdded", InfoBaseUserID);
		Else
			AdditionalProperties.Insert("InfoBaseUserChanged", InfoBaseUserID);
		EndIf
	EndIf;
	
EndProcedure

Function DeleteInfoBaseUser(Cancel)
	
	SetPrivilegedMode(True);
	
	ErrorDescription = "";
	If Users.DeleteInfoBaseUser(InfoBaseUserID, ErrorDescription) Then
		AdditionalProperties.Insert("InfoBaseUserDeleted", InfoBaseUserID);
		AdditionalProperties.InfoBaseUserExists = False;
		InfoBaseUserID = Undefined;
	Else
		CommonUseClientServer.MessageToUser(ErrorDescription, , , , Cancel);
	EndIf;
	
EndFunction

