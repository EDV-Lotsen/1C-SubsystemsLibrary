
////////////////////////////////////////////////////////////////////////////////
// Procedures and functions of the applied developer
//

// Function UseExternalUsers() returns
// Value of the functional option UseExternalUsers.
//
// Value returned:
//  Boolean.
//
Function UseExternalUsers() Export
	
	SetPrivilegedMode(True);
	
	Return Constants.UseExternalUsers.Get();
	
EndFunction

// Gets session parameter value "Current external user"
//
// Value returned:
// CatalogRef.ExternalUsers.
//
Function CurrentExternalUser() Export
	
	SetPrivilegedMode(True);
	
	Return SessionParameters.CurrentExternalUser;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Internal procedures and functions
//

//Gets attribute value for the external user
//
// Parameters:
//  Ref		 		- CatalogRef - ref to the catalog item for which attribute value should be obtained
//  AttributeName  - String - name of the attribute, whose value needs to be obtained
//
// Value returned:
//   Arbitrary   	- obtained attribute value
//
Function GetExternalUserAttributeValues(ExternalUser, AttributeNames, SearchInAuthorizationObject = True) Export
	
	If ExternalUser = Catalogs.ExternalUsers.EmptyRef() And SearchInAuthorizationObject Then
		Return Undefined;
	EndIf;
	
	If SearchInAuthorizationObject Then
		Return CommonUse.GetAttributeValues(ExternalUser.AuthorizationObject, AttributeNames);
	Else	
		Return CommonUse.GetAttributeValues(ExternalUser, AttributeNames);
	EndIf;
	
EndFunction

// Sets form attribute value
//
// Parameters
//  Form			- Managed form - action is executed for this form
//  AttributeName	- String - value is assigned for this attribute
//  ValueToBeSet  	- Arbitrary - assigned value
//
Procedure SetFormAttributeValue(Form, AttributeName, ValueToBeSet) Export
	
	AttributeNamesArray = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(AttributeName,".");
	
	Try
		If AttributeNamesArray.Count() > 0 Then
			StringAttributePath = "";
			For Each ArrayItem In AttributeNamesArray Do
				StringAttributePath = StringAttributePath + "[""" + ArrayItem + """]";
			EndDo;
			Execute("Form" + StringAttributePath + " = ValueToBeSet");
		Else
			Form[AttributeName] = ValueToBeSet;
		EndIf;
	
	Except
	EndTry;
	
EndProcedure

// Procedure RefreshExternalUserGroupsContent updates in information register
// "Content groups users" map of groups of external users and external users
// with hierarchy groups of external users (parent includes external users of child groups).
//  This data is required for the list form and for the choice form of external users.
//  Register data can be used for other purposes to improve efficiency,
// because it is not required to work with hierarchy in query language.
//
// Parameters:
//  ExternalUserGroups - CatalogRef.ExternalUserGroups
//
Procedure RefreshExternalUserGroupsContent(Val ExternalUserGroups, ModifiedExternalUsers = Undefined) Export
	
	If Not ValueIsFilled(ExternalUserGroups) Then
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	
	// Prepare parent groups.
	Query = New Query(
	"SELECT
	|	ParentGroupsTable.Parent,
	|	ParentGroupsTable.Ref
	|INTO ParentGroupsTable
	|FROM
	|	&ParentGroupsTable AS ParentGroupsTable");
	Query.SetParameter("ParentGroupsTable", Users.ParentGroupsTable("Catalog.ExternalUserGroups"));
	Query.TempTablesManager = New TempTablesManager;
	Query.Execute();
	
	ModifiedExternalUsers = New ValueTable;
	ModifiedExternalUsers.Columns.Add("ExternalUser", New TypeDescription("CatalogRef.ExternalUsers"));
	ModifiedExternalUserGroups = New ValueTable;
	ModifiedExternalUserGroups.Columns.Add("ExternalUserGroups", New TypeDescription("CatalogRef.ExternalUserGroups"));
	ModifiedExternalUserGroups.Indexes.Add("ExternalUserGroups");
	
	// Execute for current group and every parent-group.
	While Not ExternalUserGroups.IsEmpty() Do
		
		Query.SetParameter("ExternalUserGroups", ExternalUserGroups);
		GroupProperties = CommonUse.GetAttributeValues(ExternalUserGroups, "AuthorizationObjectType, AllAuthorizationObjects");
		AuthorizationObjectType = ?(GroupProperties.AllAuthorizationObjects, GroupProperties.AuthorizationObjectType, Undefined);
		
		If ExternalUserGroups <> Catalogs.ExternalUserGroups.AllExternalUsers And
		     AuthorizationObjectType = Undefined Then
			
			// Delete links for deleted users.
			Query.Text =
				"SELECT DISTINCT
				|	UserGroupMembers.User AS ExternalUser
				|FROM
				|	InformationRegister.UserGroupMembers AS UserGroupMembers
				|		LEFT JOIN Catalog.ExternalUserGroups.Content AS ExternalUserGroupsContent
				|			INNER JOIN ParentGroupsTable AS ParentGroupsTable
				|			ON (ParentGroupsTable.Ref = ExternalUserGroupsContent.Ref)
				|				AND (ParentGroupsTable.Parent = &ExternalUserGroups)
				|		ON (UserGroupMembers.UsersGroup = &ExternalUserGroups)
				|			AND UserGroupMembers.User = ExternalUserGroupsContent.ExternalUser
				|WHERE
				|	UserGroupMembers.UsersGroup = &ExternalUserGroups
				|	AND ExternalUserGroupsContent.Ref IS NULL ";
			ExternalUsersDeletedFromGroup = Query.Execute().Choose();
			RecordManager = InformationRegisters.UserGroupMembers.CreateRecordManager();
			While ExternalUsersDeletedFromGroup.Next() Do
				RecordManager.UsersGroup = ExternalUserGroups;
				RecordManager.User       = ExternalUsersDeletedFromGroup.ExternalUser;
				RecordManager.Delete();
				If ModifiedExternalUserGroups.Find(ExternalUserGroups, "ExternalUserGroups") = Undefined Then
					ModifiedExternalUserGroups.Add().ExternalUserGroups = ExternalUserGroups;
				EndIf;
				ModifiedExternalUsers.Add().ExternalUser = ExternalUsersDeletedFromGroup.ExternalUser;
			EndDo;
		EndIf;
		
		// Insert links for added external users.
		If ExternalUserGroups = Catalogs.ExternalUserGroups.AllExternalUsers Then
			Query.Text =
				"SELECT
				|	VALUE(Catalog.ExternalUserGroups.AllExternalUsers) AS UsersGroup,
				|	ExternalUsers.Ref AS User
				|FROM
				|	Catalog.ExternalUsers AS ExternalUsers
				|		LEFT JOIN InformationRegister.UserGroupMembers AS UserGroupMembers
				|		ON (UserGroupMembers.UsersGroup = VALUE(Catalog.ExternalUserGroups.AllExternalUsers))
				|			AND (UserGroupMembers.User = ExternalUsers.Ref)
				|WHERE
				|	UserGroupMembers.User IS NULL ";
			
		ElsIf AuthorizationObjectType <> Undefined Then
			Query.SetParameter("AuthorizationObjectType", TypeOf(AuthorizationObjectType));
			Query.Text =
				"SELECT
				|	&ExternalUserGroups AS UsersGroup,
				|	ExternalUsers.Ref AS User
				|FROM
				|	Catalog.ExternalUsers AS ExternalUsers
				|		LEFT JOIN InformationRegister.UserGroupMembers AS UserGroupMembers
				|		ON (UserGroupMembers.UsersGroup = &ExternalUserGroups)
				|			AND (UserGroupMembers.User = ExternalUsers.Ref)
				|WHERE
				|	UserGroupMembers.User IS NULL 
				|	AND VALUETYPE(ExternalUsers.AuthorizationObject) = &AuthorizationObjectType";
		Else
			Query.Text =
				"SELECT DISTINCT
				|	&ExternalUserGroups AS UsersGroup,
				|	ExternalUserGroupsContent.ExternalUser AS User
				|FROM
				|	Catalog.ExternalUserGroups.Content AS ExternalUserGroupsContent
				|		INNER JOIN ParentGroupsTable AS ParentGroupsTable
				|		ON (ParentGroupsTable.Ref = ExternalUserGroupsContent.Ref)
				|			AND (ParentGroupsTable.Parent = &ExternalUserGroups)
				|		LEFT JOIN InformationRegister.UserGroupMembers AS UserGroupMembers
				|		ON (UserGroupMembers.UsersGroup = &ExternalUserGroups)
				|			AND (UserGroupMembers.User = ExternalUserGroupsContent.ExternalUser)
				|WHERE
				|	UserGroupMembers.User IS NULL ";
		EndIf;
		
		ExternalUsersAddedToGroup = Query.Execute().Unload();
		
		If ExternalUsersAddedToGroup.Count() > 0 Then
		
			RecordSet = InformationRegisters.UserGroupMembers.CreateRecordSet();
			RecordSet.Load(ExternalUsersAddedToGroup);
			RecordSet.Write(False); // Insert missing link records.
			
			For Each ExternalUserDescription In ExternalUsersAddedToGroup Do
			
				If ModifiedExternalUserGroups.Find(ExternalUserGroups, "ExternalUserGroups") = Undefined Then
					ModifiedExternalUserGroups.Add().ExternalUserGroups = ExternalUserGroups;
				EndIf;
				ModifiedExternalUsers.Add().ExternalUser = ExternalUserDescription.User;
			EndDo;
		EndIf;
		
		ExternalUserGroups = CommonUse.GetAttributeValue(ExternalUserGroups, "Parent");
	EndDo;
	
EndProcedure

// Procedure RefreshExternalUserRoles updates the list of user roles
// based on their current belongings to the external user groups.
// 
// Parameters:
//  ExternalUsers - Array of items CatalogRef.ExternalUsers.
//  ErrorOccurred - Boolean. Returns true, when there occured some errors, logged into eventlog.
//
Procedure RefreshExternalUserRoles(Val ExternalUsers, ErrorOccurred = False) Export
	
	If UsersOverrided.RolesEditingProhibited() Then
		// Roles are assigned by another mechanism, for example, by mechanism of the subsystem AccessManagement.
		Return;
	EndIf;
	
	If ExternalUsers.Count() = 0 Then
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	
	IBUserIDs = New Map;
	Query = New Query(
	"SELECT
	|	ExternalUsers.Ref AS ExternalUser,
	|	ExternalUsers.IBUserID
	|FROM
	|	Catalog.ExternalUsers AS ExternalUsers
	|WHERE
	|	ExternalUsers.Ref IN(&ExternalUsers)
	|	AND (NOT ExternalUsers.SetRolesDirectly)");
	Query.SetParameter("ExternalUsers", ExternalUsers);
	Selection = Query.Execute().Choose();
	While Selection.Next() Do
		IBUserIDs.Insert(Selection.ExternalUser, Selection.IBUserID);
	EndDo;
	
	// Prepare table of old roles of external users.
	OldExternalUserRoles = New ValueTable;
	OldExternalUserRoles.Columns.Add("ExternalUser", New TypeDescription("CatalogRef.ExternalUsers"));
	OldExternalUserRoles.Columns.Add("Role", New TypeDescription("String", , New StringQualifiers(200)));
	
	CurrentNumber = ExternalUsers.Count()-1;
	While CurrentNumber >= 0 Do
	// Check necessity of user processing.
		If IBUserIDs[ExternalUsers[CurrentNumber]] = Undefined Then
			IBUser = Undefined;
		Else
			IBUser = InfobaseUsers.FindByUUID(IBUserIDs[ExternalUsers[CurrentNumber]]);
		EndIf;
		If IBUser = Undefined 
		   Or IsBlankString(IBUser.Name) Then
			ExternalUsers.Delete(CurrentNumber);
		Else
			For each Role In IBUser.Roles Do
				OldRoleOfExternalUser = OldExternalUserRoles.Add();
				OldRoleOfExternalUser.ExternalUser = ExternalUsers[CurrentNumber];
				OldRoleOfExternalUser.Role = Role.Name;
			EndDo;
		EndIf;
		CurrentNumber = CurrentNumber - 1;
	EndDo;
	
	// Prepare list of roles missing in metadata and which have to be reinstalled.
	Query.Text =
		"SELECT
		|	OldExternalUserRoles.ExternalUser,
		|	OldExternalUserRoles.Role
		|INTO OldExternalUserRoles
		|FROM
		|	&OldExternalUserRoles AS OldExternalUserRoles
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	AllAvailableRoles.Name
		|INTO AllAvailableRoles
		|FROM
		|	&AllAvailableRoles AS AllAvailableRoles
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT DISTINCT
		|	UserGroupMembers.UsersGroup AS ExternalUserGroups,
		|	UserGroupMembers.User AS ExternalUser,
		|	Roles.Role
		|INTO AllNewRolesOfExternalUsers
		|FROM
		|	Catalog.ExternalUserGroups.Roles AS Roles
		|		INNER JOIN InformationRegister.UserGroupMembers AS UserGroupMembers
		|		ON (UserGroupMembers.User IN (&ExternalUsers))
		|			AND (UserGroupMembers.UsersGroup = Roles.Ref)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT DISTINCT
		|	AllNewRolesOfExternalUsers.ExternalUser,
		|	AllNewRolesOfExternalUsers.Role
		|INTO NewRolesOfExternalUsers
		|FROM
		|	AllNewRolesOfExternalUsers AS AllNewRolesOfExternalUsers
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	OldExternalUserRoles.ExternalUser
		|INTO ModifiedExternalUsers
		|FROM
		|	OldExternalUserRoles AS OldExternalUserRoles
		|		LEFT JOIN NewRolesOfExternalUsers AS NewRolesOfExternalUsers
		|		ON (NewRolesOfExternalUsers.ExternalUser = OldExternalUserRoles.ExternalUser)
		|			AND (NewRolesOfExternalUsers.Role = OldExternalUserRoles.Role)
		|WHERE
		|	NewRolesOfExternalUsers.Role IS NULL 
		|
		|UNION
		|
		|SELECT
		|	NewRolesOfExternalUsers.ExternalUser
		|FROM
		|	NewRolesOfExternalUsers AS NewRolesOfExternalUsers
		|		LEFT JOIN OldExternalUserRoles AS OldExternalUserRoles
		|		ON NewRolesOfExternalUsers.ExternalUser = OldExternalUserRoles.ExternalUser
		|			AND NewRolesOfExternalUsers.Role = OldExternalUserRoles.Role
		|WHERE
		|	OldExternalUserRoles.Role IS NULL 
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	AllNewRolesOfExternalUsers.ExternalUserGroups,
		|	AllNewRolesOfExternalUsers.ExternalUser,
		|	AllNewRolesOfExternalUsers.Role
		|FROM
		|	AllNewRolesOfExternalUsers AS AllNewRolesOfExternalUsers
		|WHERE
		|	NOT TRUE IN
		|				(SELECT TOP 1
		|					TRUE AS ValueTrue
		|				FROM
		|					AllAvailableRoles AS AllAvailableRoles
		|				WHERE
		|					AllAvailableRoles.Name = AllNewRolesOfExternalUsers.Role)";
	Query.TempTablesManager = New TempTablesManager;
	Query.SetParameter("AllAvailableRoles", UsersServerSecondUse.AllRoles(True));
	Query.SetParameter("OldExternalUserRoles", OldExternalUserRoles);
	
	// Registration of errors of role names in access group profiles.
	Selection = Query.Execute().Choose();
	While Selection.Next() Do
		WriteLogEvent(NStr("en = 'External users. The role is not found in the metadata'"),
             EventLogLevel.Error,
             ,
             ,
             StringFunctionsClientServer.SubstitureParametersInString(
                  NStr("en = 'The <%2> role of <%3> external user group was not found in the metadata while updating roles of <%1> external user!'"),
                  TrimAll(Selection.ExternalUser.Description),
                  Selection.Role,
                  String(Selection.ExternalUserGroups)),
             EventLogEntryTransactionMode.Transactional);
		ErrorOccurred = True;
	EndDo;
	
	// Update roles of IB users.
	Query.Text =
		"SELECT
		|	ModifiedExternalUsersAndRoles.ExternalUser,
		|	ModifiedExternalUsersAndRoles.Role
		|FROM
		|	(SELECT
		|		NewRolesOfExternalUsers.ExternalUser AS ExternalUser,
		|		NewRolesOfExternalUsers.Role AS Role
		|	FROM
		|		NewRolesOfExternalUsers AS NewRolesOfExternalUsers
		|	WHERE
		|		NewRolesOfExternalUsers.ExternalUser IN
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
		|					ModifiedExternalUsers AS ModifiedExternalUsers)) AS ModifiedExternalUsersAndRoles
		|
		|ORDER BY
		|	ModifiedExternalUsersAndRoles.ExternalUser,
		|	ModifiedExternalUsersAndRoles.Role";
	Selection = Query.Execute().Choose();
	
	IBUser = Undefined;
	While Selection.Next() Do
		If NOT ValueIsFilled(Selection.Role) Then
			If IBUser <> Undefined Then
				IBUser.Write();
			EndIf;
			IBUser = InfobaseUsers.FindByUUID(IBUserIDs[Selection.ExternalUser]);
			IBUser.Roles.Clear();
		Else
			IBUser.Roles.Add(Metadata.Roles[Selection.Role]);
		EndIf;
	EndDo;
	If IBUser <> Undefined Then
		IBUser.Write();
	EndIf;
	
EndProcedure

// Function AuthorizationObjectLinkedToExternalUser checks, that infobase object,
// is used as an authorization object of external user, except current user (if specified).
//
Function AuthorizationObjectLinkedToExternalUser(Val AuthorizationObjectRef,
			                                     Val CurrentExternalUserRef  = Undefined,
			                                     FoundExternalUser 		     = Undefined,
			                                     ExternalUserCreationAllowed = False) Export
	
	ExternalUserCreationAllowed = AccessRight("Insert", Metadata.Catalogs.ExternalUsers);
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = "SELECT TOP 1
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

// Handler of the subscription for the event UpdateExternalUserPresentation
Procedure UpdateExternalUserPresentation(AuthorizationObjectRef) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query(
		"SELECT TOP 1
		|	ExternalUsers.Ref
		|FROM
		|	Catalog.ExternalUsers AS ExternalUsers
		|WHERE
		|	ExternalUsers.AuthorizationObject = &AuthorizationObjectRef
		|	AND ExternalUsers.Description <> &NewPresentationOfAuthorizationObject");
	Query.SetParameter("AuthorizationObjectRef", AuthorizationObjectRef);
	Query.SetParameter("NewPresentationOfAuthorizationObject", String(AuthorizationObjectRef));
	Selection = Query.Execute().Choose();
	
	If Selection.Next() Then
		ExternalUserObject = Selection.Ref.GetObject();
		// Description will be reassigned in handler OnWrite.
		ExternalUserObject.Write();
	EndIf;
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// Update handlers on transition to the new version of the SSL configuration
//

// Update handler on transition to the configuration version 1.0.6.5
// for updating the information register UserGroupMembers records.
//
Procedure FillContentOfGroupsOfExternalUsers() Export
	
	ExternalUsers.RefreshExternalUserGroupsContent(Catalogs.ExternalUserGroups.AllExternalUsers);
	
EndProcedure

// Update handler on transition to the configuration version 1.0.6.5
// creates IB users from the data of Catalog.ExternalUsers
//
Procedure CreateInfobaseUsersForExternalUsers() Export
	
	SetPrivilegedMode(True);
	
	Selection = Catalogs.ExternalUsers.Select();
	
	While Selection.Next() Do
		
		If Not ValueIsFilled(Selection.IBUserID)
		   And ValueIsFilled(Selection.AuthorizationObject)
		   And ValueIsFilled(Selection.Code) Then
			
			ExternalUserObject = Selection.Ref.GetObject();
			Try
				IBUser				 		 = InfobaseUsers.CreateUser();
				IBUser.Name       	 		 = Selection.Code;
				IBUser.Password    	 		 = Selection.DeletePassword;
				IBUser.FullName				 = String(Selection.AuthorizationObject);
				IBUser.Write();
				ExternalUserObject.IBUserID  = IBUser.UUID;
				ExternalUserObject.Write();
			Except
				WriteLogEvent(NStr("en = 'External users. Error occurred during the infobase update.'"),
                     EventLogLevel.Error,
                     ,
                     ,
                     StringFunctionsClientServer.SubstitureParametersInString(
                          NStr("en = 'An error occurred while creating %1 infobase user for %2 external user:
                                |%3'"),
                          Selection.Code,
                          Selection.Description,
                          ErrorDescription()),
                     EventLogEntryTransactionMode.Independent);
			EndTry;
		EndIf;
	EndDo;
	
EndProcedure

