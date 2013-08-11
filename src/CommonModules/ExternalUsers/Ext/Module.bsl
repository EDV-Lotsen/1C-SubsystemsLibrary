////////////////////////////////////////////////////////////////////////////////
// Users subsystem.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// Returns a flag that shows whether external users are used in the application 
// (an UseExternalUsers functional option value).
//
// Returns:
//  Boolean.
//
Function UseExternalUsers() Export
	
	Return GetFunctionalOption("UseExternalUsers");
	
EndFunction

// Returns the current external user that corresponds to the authorized infobase user.
//
// If an ordinary user corresponds to the authorized infobase user, an empty reference
// is returned.
//
// Returns:
//  CatalogRef.ExternalUsers
//
Function CurrentExternalUser() Export
	
	SetPrivilegedMode(True);
	
	Return SessionParameters.CurrentExternalUser;
	
EndFunction

// Retrieves a reference to the external user authorization object from the infobase.
// Authorization object is a reference to an infobase object that is used
// for connecting with an external user, like counterparty, individual and so on.
//
// Parameters:
//  ExternalUser - CatalogRef.ExternalUsers
//
// Returns:
//  Metadata.Catalogs.ExternalUsers.Attributes.AuthorizationObjects.Type
//
Function GetExternalUserAuthorizationObject(ExternalUser) Export
	
	AuthorizationObject = CommonUse.GetAttributeValues(ExternalUser, "AuthorizationObject").AuthorizationObject;
	
	If ValueIsFilled(AuthorizationObject) Then
		If AuthorizationObjectUsed(AuthorizationObject, ExternalUser) Then
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Database error:
				 |The %1 authorization object (%2)
				 |is set for several external users.'"),
				AuthorizationObject,
				TypeOf(AuthorizationObject));
		EndIf;
	Else
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Database error:
			 |An authorization object is not set for the %1 external user .'"),
			ExternalUser);
	EndIf;
	
	Return AuthorizationObject;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

// Updates a map of external user groups to external users
// according to the external user group hierarchy (parent groups includes
// subgroup users).
// This data is used in the list form and in the external user choice form.
// This data can be used for improving performance,
// as there is no need for using queries to process the group hierarchy.
//
// Parameters:
// ExternalUserGroup - CatalogRef.ExternalUserGroups
//
Procedure UpdateExternalUserGroupContent(Val ExternalUserGroup, ModifiedExternalUsers = Undefined) Export
	
	If Not ValueIsFilled(ExternalUserGroup) Then
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	
	// Preparing parent groups.
	Query = New Query(
	"SELECT
	|	ParentGroupTable.Parent,
	|	ParentGroupTable.Ref
	|INTO ParentGroupTable
	|FROM
	|	&ParentGroupTable AS ParentGroupTable");
	Query.SetParameter("ParentGroupTable", Users.ParentGroupTable("Catalog.ExternalUserGroups"));
	Query.TempTablesManager = New TempTablesManager;
	Query.Execute();
	
	ModifiedExternalUsers = New ValueTable;
	ModifiedExternalUsers.Columns.Add("ExternalUser", New TypeDescription("CatalogRef.ExternalUsers"));
	
	// Processing the current group and each parent group.
	While Not ExternalUserGroup.IsEmpty() Do
		
		Query.SetParameter("ExternalUserGroup", ExternalUserGroup);
		GroupProperties = CommonUse.GetAttributeValues(ExternalUserGroup, "AuthorizationObjectType, AllAuthorizationObjects");
		AuthorizationObjectType = ?(GroupProperties.AllAuthorizationObjects, GroupProperties.AuthorizationObjectType, Undefined);
		
		If ExternalUserGroup <> Catalogs.ExternalUserGroups.AllExternalUsers And
		 AuthorizationObjectType = Undefined Then
			
			// Deleting relations of deleted users.
			Query.Text =
			"SELECT DISTINCT
			|	UserGroupContent.User AS ExternalUser
			|FROM
			|	InformationRegister.UserGroupContent AS UserGroupContent
			|		LEFT JOIN Catalog.ExternalUserGroups.Content AS ExternalUserGroupContent
			|			INNER JOIN ParentGroupTable AS ParentGroupTable
			|				ON (ParentGroupTable.Ref = ExternalUserGroupContent.Ref)
			|				AND (ParentGroupTable.Parent = &ExternalUserGroup)
			|			ON (UserGroupContent.UserGroup = &ExternalUserGroup)
			|			AND UserGroupContent.User = ExternalUserGroupContent.ExternalUser
			|WHERE
			|	UserGroupContent.UserGroup = &ExternalUserGroup
			|	AND ExternalUserGroupContent.Ref IS NULL ";
			DeletedFromGroupExternalUsers = Query.Execute().Choose();
			RecordManager = InformationRegisters.UserGroupContent.CreateRecordManager();
			While DeletedFromGroupExternalUsers.Next() Do
				RecordManager.UserGroup = ExternalUserGroup;
				RecordManager.User = DeletedFromGroupExternalUsers.ExternalUser;
				RecordManager.Delete();
				ModifiedExternalUsers.Add().ExternalUser = DeletedFromGroupExternalUsers.ExternalUser;
			EndDo;
		EndIf;
		
		// Adding relations of added external users.
		If ExternalUserGroup = Catalogs.ExternalUserGroups.AllExternalUsers Then
			Query.Text =
			"SELECT
			|	VALUE(Catalog.ExternalUserGroups.AllExternalUsers) AS UserGroup,
			|	ExternalUsers.Ref AS User
			|FROM
			|	Catalog.ExternalUsers AS ExternalUsers
			|		LEFT JOIN InformationRegister.UserGroupContent AS UserGroupContent
			|			ON (UserGroupContent.UserGroup = VALUE(Catalog.ExternalUserGroups.AllExternalUsers))
			|			AND (UserGroupContent.User = ExternalUsers.Ref)
			|WHERE
			|	UserGroupContent.User IS NULL 
			|
			|UNION
			|
			|SELECT
			|	ExternalUsers.Ref,
			|	ExternalUsers.Ref
			|FROM
			|	Catalog.ExternalUsers AS ExternalUsers
			|		LEFT JOIN InformationRegister.UserGroupContent AS UserGroupContent
			|			ON (UserGroupContent.UserGroup = ExternalUsers.Ref)
			|			AND (UserGroupContent.User = ExternalUsers.Ref)
			|WHERE
			|	UserGroupContent.User IS NULL ";
			
		ElsIf AuthorizationObjectType <> Undefined Then
			Query.SetParameter("AuthorizationObjectType", TypeOf(AuthorizationObjectType));
			Query.Text =
			"SELECT
			|	&ExternalUserGroup AS UserGroup,
			|	ExternalUsers.Ref AS User
			|FROM
			|	Catalog.ExternalUsers AS ExternalUsers
			|		LEFT JOIN InformationRegister.UserGroupContent AS UserGroupContent
			|			ON (UserGroupContent.UserGroup = &ExternalUserGroup)
			|			AND (UserGroupContent.User = ExternalUsers.Ref)
			|WHERE
			|	UserGroupContent.User IS NULL 
			|	AND VALUETYPE(ExternalUsers.AuthorizationObject) = &AuthorizationObjectType";
		Else
			Query.Text =
			"SELECT DISTINCT
			|	&ExternalUserGroup AS UserGroup,
			|	ExternalUserGroupContent.ExternalUser AS User
			|FROM
			|	Catalog.ExternalUserGroups.Content AS ExternalUserGroupContent
			|		INNER JOIN ParentGroupTable AS ParentGroupTable
			|			ON (ParentGroupTable.Ref = ExternalUserGroupContent.Ref)
			|			AND (ParentGroupTable.Parent = &ExternalUserGroup)
			|		LEFT JOIN InformationRegister.UserGroupContent AS UserGroupContent
			|			ON (UserGroupContent.UserGroup = &ExternalUserGroup)
			|			AND (UserGroupContent.User = ExternalUserGroupContent.ExternalUser)
			|WHERE
			|	UserGroupContent.User IS NULL ";
		EndIf;
		
		ExternalUsersAddedToGroup = Query.Execute().Unload();
		
		If ExternalUsersAddedToGroup.Count() > 0 Then
		
			RecordSet = InformationRegisters.UserGroupContent.CreateRecordSet();
			RecordSet.Load(ExternalUsersAddedToGroup);
			RecordSet.Write(False); // Adding missed relationship records.
			
			For Each ExternalUserInfo In ExternalUsersAddedToGroup Do
				ModifiedExternalUsers.Add().ExternalUser = ExternalUserInfo.User;
			EndDo;
		EndIf;
		
		ExternalUserGroup = CommonUse.GetAttributeValue(ExternalUserGroup, "Parent");
	EndDo;
	
	ModifiedExternalUsers.GroupBy("ExternalUser");
	ModifiedExternalUsers = ModifiedExternalUsers.UnloadColumn("ExternalUser");
	
EndProcedure

// Updates the role list of infobase users that correspond to external users.
// Role content is determined based on the external user list, except users whose roles 
// are specified directly.
// Is required only if editing roles is allowed, for example, if the AccessManagement 
// subsystem has been embedded, execution of this procedure is not required.
// 
// Parameters:
// ExternalUserArray - Array of CatalogRef.ExternalUsers
//
Procedure UpdateExternalUserRoles(Val ExternalUserArray) Export
	
	If UsersOverridable.RoleEditProhibition() Then
		// Roles are set with another mechanism, for example, with the AccessManagement subsystem mechanism.
		Return;
	EndIf;
	
	If ExternalUserArray.Count() = 0 Then
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	
	Users.FindAmbiguousInfoBaseUsers();
	
	InfoBaseUserIDs = New Map;
	Query = New Query(
		"SELECT
		|	ExternalUsers.Ref AS ExternalUser,
		|	ExternalUsers.InfoBaseUserID
		|FROM
		|	Catalog.ExternalUsers AS ExternalUsers
		|WHERE
		|	ExternalUsers.Ref IN(&ExternalUsers)
		|	AND (NOT ExternalUsers.SetRolesDirectly)");
	Query.SetParameter("ExternalUsers", ExternalUserArray);
	Selection = Query.Execute().Choose();
	While Selection.Next() Do
		InfoBaseUserIDs.Insert(Selection.ExternalUser, Selection.InfoBaseUserID);
	EndDo;
	
	// Preparing a table of old external user roles.
	OldExternalUserRoles = New ValueTable;
	OldExternalUserRoles.Columns.Add("ExternalUser", New TypeDescription("CatalogRef.ExternalUsers"));
	OldExternalUserRoles.Columns.Add("Role", New TypeDescription("String", , New StringQualifiers(200)));
	
	CurrentNumber = ExternalUserArray.Count() - 1;
	While CurrentNumber >= 0 Do
		// Checking whether the user must be processed.
		InfoBaseUser = Undefined;
		InfoBaseUserID = InfoBaseUserIDs[ExternalUserArray[CurrentNumber]];
		If InfoBaseUserID <> Undefined Then
			InfoBaseUser = InfoBaseUsers.FindByUUID(InfoBaseUserID);
		EndIf;
		If InfoBaseUser = Undefined Or IsBlankString(InfoBaseUser.Name) Then
			ExternalUserArray.Delete(CurrentNumber);
		Else
			For Each Role In InfoBaseUser.Roles Do
				OldExternalUserRole = OldExternalUserRoles.Add();
				OldExternalUserRole.ExternalUser = ExternalUserArray[CurrentNumber];
				OldExternalUserRole.Role = Role.Name;
			EndDo;
		EndIf;
		CurrentNumber = CurrentNumber - 1;
	EndDo;
	
	// Preparing a list of roles that are missed in metadata and must be set again.
	Query.Text =
		"SELECT
		|	OldExternalUserRoles.ExternalUser,
		|	OldExternalUserRoles.Role
		|INTO OldExternalUserRoles
		|FROM
		|	&OldExternalUserRoles AS  OldExternalUserRoles
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	AllAvailableRoles.Name
		|INTO AllAvailableRoles
		|FROM
		|	&AllAvailableRoles AS  AllAvailableRoles
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT DISTINCT
		|	UserGroupContent.UserGroup AS ExternalUserGroup,
		|	UserGroupContent.User AS ExternalUser,
		|	Roles.Role
		|INTO AllNewExternalUserRoles
		|FROM
		|	Catalog.ExternalUserGroups.Roles AS  Roles
		|		INNER JOIN InformationRegister.UserGroupContent AS  UserGroupContent
		|			ON (UserGroupContent.User IN (&ExternalUsers))
		|			AND (UserGroupContent.UserGroup = Roles.Ref)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT DISTINCT
		|	AllNewExternalUserRoles.ExternalUser,
		|	AllNewExternalUserRoles.Role
		|INTO NewExternalUserRoles
		|FROM
		|	AllNewExternalUserRoles AS  AllNewExternalUserRoles
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	OldExternalUserRoles.ExternalUser
		|INTO ModifiedExternalUsers
		|FROM
		|	OldExternalUserRoles AS  OldExternalUserRoles
		|		LEFT JOIN NewExternalUserRoles AS  NewExternalUserRoles
		|			ON (NewExternalUserRoles.ExternalUser =  OldExternalUserRoles.ExternalUser)
		|			AND (NewExternalUserRoles.Role  = OldExternalUserRoles.Role)
		|WHERE
		|	NewExternalUserRoles.Role IS NULL 
		|
		|UNION
		|
		|SELECT
		|	NewExternalUserRoles.ExternalUser
		|FROM
		|	NewExternalUserRoles AS  NewExternalUserRoles
		|		LEFT JOIN OldExternalUserRoles AS  OldExternalUserRoles
		|			ON  NewExternalUserRoles.ExternalUser = OldExternalUserRoles.ExternalUser
		|			AND  NewExternalUserRoles.Role = OldExternalUserRoles.Role
		|WHERE
		|	OldExternalUserRoles.Role IS NULL 
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	AllNewExternalUserRoles.ExternalUserGroup,
		|	AllNewExternalUserRoles.ExternalUser,
		|	AllNewExternalUserRoles.Role
		|FROM
		|	AllNewExternalUserRoles AS  AllNewExternalUserRoles
		|WHERE
		|	(NOT TRUE IN
		|				(SELECT TOP 1
		|					TRUE AS  TrueValue
		|				FROM
		|					AllAvailableRoles AS AllAvailableRoles
		|				WHERE
		|					AllAvailableRoles.Name = AllNewExternalUserRoles.Role))";	
	Query.TempTablesManager = New TempTablesManager;
	Query.SetParameter("AllAvailableRoles", UsersServerCached.AllRoles());
	Query.SetParameter("OldExternalUserRoles", OldExternalUserRoles);
	
	// Logging role names errors in access group profiles.
	Selection = Query.Execute().Choose();
	While Selection.Next() Do
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en= 'Error updating roles of the external user <%1>. The role <%2> of the external user group <%3> is not found in metadata.'"),
			TrimAll(Selection.ExternalUser.Description),
			Selection.Role,
			String(Selection.ExternalUserGroup));
		WriteLogEvent(NStr("en = 'External users. Role not found in metadata'"),
			EventLogLevel.Error,,, MessageText, EventLogEntryTransactionMode.Transactional);
	EndDo;
	
	// Updating infobase user roles.
	Query.Text =
		"SELECT
		|	ChangedExternalUsersAndRoles.ExternalUser,
		|	ChangedExternalUsersAndRoles.Role
		|FROM
		|	(SELECT
		|		NewExternalUserRoles.ExternalUser AS ExternalUser,
		|		NewExternalUserRoles.Role AS Role
		|	FROM
		|		NewExternalUserRoles AS NewExternalUserRoles
		|	WHERE
		|		NewExternalUserRoles.ExternalUser IN
		|				(SELECT
		|					ModifiedExternalUsers.ExternalUser
		|				FROM
		|					ModifiedExternalUsers AS ModifiedExternalUsers)
		|	
		|	UNION
		|	
		|	SELECT
		|		ExternalUsers.Ref,
		|		""""
		|	FROM
		|		Catalog.ExternalUsers AS ExternalUsers
		|	WHERE
		|		ExternalUsers.Ref IN
		|				(SELECT
		|					ModifiedExternalUsers.ExternalUser
		|				FROM
		|					ModifiedExternalUsers AS ModifiedExternalUsers)) AS ChangedExternalUsersAndRoles
		|
		|ORDER BY
		|	ChangedExternalUsersAndRoles.ExternalUser,
		|	ChangedExternalUsersAndRoles.Role";
	Selection = Query.Execute().Choose();
	
	InfoBaseUser = Undefined;
	While Selection.Next() Do
		If ValueIsFilled(Selection.Role) Then
			InfoBaseUser.Roles.Add(Metadata.Roles[Selection.Role]);
			Continue;
		EndIf;
		If InfoBaseUser <> Undefined Then
			InfoBaseUser.Write();
		EndIf;
		InfoBaseUser = InfoBaseUsers.FindByUUID(InfoBaseUserIDs[Selection.ExternalUser]);
		InfoBaseUser.Roles.Clear();
	EndDo;
	If InfoBaseUser <> Undefined Then
		InfoBaseUser.Write();
	EndIf;
	
EndProcedure

// Checks whether the infobase object is used as an authorization object of
// any external user, except the specified one (if it is set).
//
Function AuthorizationObjectUsed(Val AuthorizationObjectRef,
Val CurrentExternalUserRef = Undefined,
FoundExternalUser = Undefined,
CanAddExternalUser = False) Export
	
	CanAddExternalUser = AccessRight("Insert", Metadata.Catalogs.ExternalUsers);
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = "SELECT Top 1
	 |	ExternalUsers.Ref
	 |FROM
	 |	Catalog.ExternalUsers AS ExternalUsers
	 |WHERE
	 |	ExternalUsers.AuthorizationObject = &AuthorizationObjectRef
	 |	AND ExternalUsers.Ref <> &CurrentExternalUserRef";
	Query.SetParameter("CurrentExternalUserRef", CurrentExternalUserRef);
	Query.SetParameter("AuthorizationObjectRef", AuthorizationObjectRef);
	
	Table = Query.Execute().Unload();
	If Table.Count() > 0 Then
		FoundExternalUser = Table[0].Ref;
	EndIf;
	
	Return Table.Count() > 0;
	
EndFunction

// Updates an external user presentation when changing a presentation of its authorization object.
//
Procedure UpdateExternalUserPresentation(AuthorizationObjectRef) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query(
	"SELECT TOP 1
	|	ExternalUsers.Ref
	|FROM
	|	Catalog.ExternalUsers AS ExternalUsers
	|WHERE
	|	ExternalUsers.AuthorizationObject = &AuthorizationObjectRef
	|	AND ExternalUsers.Description <> &NewAuthorizationObjectPresentation");
	Query.SetParameter("AuthorizationObjectRef", AuthorizationObjectRef);
	Query.SetParameter("NewAuthorizationObjectPresentation", String(AuthorizationObjectRef));
	Selection = Query.Execute().Choose();
	
	If Selection.Next() Then
		
		ExternalUserObject = Selection.Ref.GetObject();
		ExternalUserObject.Description = String(AuthorizationObjectRef);
		ExternalUserObject.Write();
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and function for updating the infobase.

// The update handler that is used when the configuration version is changed to 1.0.6.5,
// to update UserGroupContent information register records.
//
Procedure FillExternalUserGroupContent() Export
	
	UpdateExternalUserGroupContent(Catalogs.ExternalUserGroups.AllExternalUsers);
	
EndProcedure

// The update handler that is used when the configuration version is changed to 1.0.6.5;
// Creates infobase users by data from Catalog.ExternalUsers
//
Procedure ForExternalUsersCreateInfoBaseUsers() Export
	
	SetPrivilegedMode(True);
	
	Selection = Catalogs.ExternalUsers.Select();
	
	While Selection.Next() Do
		
		If Not ValueIsFilled(Selection.InfoBaseUserID) And
		 ValueIsFilled(Selection.AuthorizationObject) And
		 ValueIsFilled(Selection.Code) Then
			
			ExternalUserObject = Selection.Ref.GetObject();
			Try
				InfoBaseUser = InfoBaseUsers.CreateUser();
				InfoBaseUser.Name = Selection.Code;
				InfoBaseUser.Password = Selection.DeletePassword;
				InfoBaseUser.FullName = String(Selection.AuthorizationObject);
				InfoBaseUser.Write();
				ExternalUserObject.InfoBaseUserID = InfoBaseUser.UUID;
				ExternalUserObject.Write();
			Except
				WriteLogEvent(NStr("en = 'External users. Error updating infobase'"),
				 EventLogLevel.Error,
				 ,
				 ,
				 StringFunctionsClientServer.SubstituteParametersInString(
				 NStr("en= 'The following error occurred when creating the infobase user named %1 for the %2 external user :
				 |%3'"),
				 Selection.Code,
				 Selection.Description,
				 ErrorDescription()),
				 EventLogEntryTransactionMode.Independent);
			EndTry;
		EndIf;
	EndDo;
	
EndProcedure
