
////////////////////////////////////////////////////////////////////////////////
// Users subsystem.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// Returns the current user or current external user that corresponds 
// to the authorized infobase user.
// 
// Returns:
// CatalogRef.Users, CatalogRef.ExternalUsers.
//
Function AuthorizedUser() Export
	
	SetPrivilegedMode(True);
	
	Return ?(ValueIsFilled(SessionParameters.CurrentUser), SessionParameters.CurrentUser, SessionParameters.CurrentExternalUser);
	
EndFunction

// Returns the current ordinary user that corresponds to the authorized infobase user.
//
// If an external user corresponds to the authorized infobase user, an empty reference
// is returned.
//
// Returns:
//  CatalogRef.Users
//
Function CurrentUser() Export
	
	SetPrivilegedMode(True);
	
	Return SessionParameters.CurrentUser;
	
EndFunction

// Checks whether the current or specified user is a full access user.

// A user is a full access user if
//  a) the infobase user list is not empty and:
//   - in the local mode (without data separation), the user has the FullAccess role 
//   and the infobase administrator role,
//   - in the service mode (with data separation), the user has the FullAccess role.
//  b) the infobase user list is empty and the main configuration role is not specified 
//   or specified as FullAccess.
//
// Parameters: 
//  User                            - Undefined - if the current infobase user will be
//                                    checked.
//                                  - CatalogRef.Users, CatalogRef.ExternalUsers - if
//                                    the user that will be checked must be found by
//                                    UUID.
//                                    Note: if the infobase user is not found, False 
//                                    will be returned.
//                                  - InfoBaseUser - if the specified infobase user 
//                                    will be checked.
//  CheckSystemAdministrationRights - Boolean - flag that shows whether an  
//                                    administrative role existence will be checked. 
//                                    The default value is False.
//  ForPrivilegedMode               - Boolean - if it is set to True, the function 
//                                    returns True when the privileged mode is on.
//                                    The default value is True.
//
// Returns:
//  Boolean.
//
Function InfoBaseUserWithFullAccess(User = Undefined,
                                    CheckSystemAdministrationRights = False,
                                    ForPrivilegedMode = True) Export
	
	If ForPrivilegedMode And PrivilegedMode() Then
		Return True;
	EndIf;
	
	SetPrivilegedMode(True);
	
	If User = Undefined Or User = AuthorizedUser() Then
		InfoBaseUser = InfoBaseUsers.CurrentUser();
		
	ElsIf TypeOf(User) = Type("InfoBaseUser") Then
		InfoBaseUser = User;
		
	Else
		// The specified user is not the current one
		InfoBaseUser = InfoBaseUsers.FindByUUID(
			CommonUse.GetAttributeValue(User, "InfoBaseUserID"));
		
		If InfoBaseUser = Undefined Then
			Return False;
		EndIf;
	EndIf;
	
	If InfoBaseUser.UUID <> InfoBaseUsers.CurrentUser().UUID Then
		
		// Checking roles of the written infobase user if this user is not the current one.
		If CheckSystemAdministrationRights Then
			Return InfoBaseUser.Roles.Contains(FullAdministratorRole())
		Else
			Return InfoBaseUser.Roles.Contains(Metadata.Roles.FullAccess)
		EndIf;
	Else
		If ValueIsFilled(InfoBaseUser.Name) Then
			
			// Checking roles in the current session but not in the written infobase user
			// if the current user is specified.
			If CheckSystemAdministrationRights Then
				Return IsInRole(FullAdministratorRole())
			Else
				Return IsInRole(Metadata.Roles.FullAccess)
			EndIf;
		Else
			// Checking the main configuration role if the infobase user is not specified: 
			// it must be set to FullAccess or Undefined.
			If Metadata.DefaultRoles.Count() = 0 
			   Or Metadata.DefaultRoles.Contains(Metadata.Roles.FullAccess) Then
				Return True;
			Else
				Return False;
			EndIf;
		EndIf;
	EndIf;
	
EndFunction

// Shows whether even one of the specified roles is available or the user (current or  
// specified) has full access.
//
// Parameters:
//  RoleNames - String - names of roles, separated by comma, whose availability will be
//              checked.
//  User      - Undefined - if the current infobase user will be checked.
//            - CatalogRef.Users, CatalogRef.ExternalUsers - if the user that will be 
//              chacked must be found by UUID.
//              Note: if the infobase user is not found, False will be returned.
//            - InfoBaseUser - if the specified infobase user will be checked.
//
// Returns:
//  Boolean - True if even one of the roles is available or the 
//            InfoBaseUserWithFullAccess function returns true.
//
Function RolesAvailable(Val RoleNames, User = Undefined) Export
	
	If InfoBaseUserWithFullAccess(User) Then
		Return True;
	EndIf;
	
	SetPrivilegedMode(True);
	
	If User = Undefined Or User = AuthorizedUser() Then
		InfoBaseUser = InfoBaseUsers.CurrentUser();
		
	ElsIf TypeOf(User) = Type("InfoBaseUser") Then
		InfoBaseUser = User;
		
	Else
		// The specified user is not the current one
		InfoBaseUser = InfoBaseUsers.FindByUUID(
			CommonUse.GetAttributeValue(User, "InfoBaseUserID"));
		
		If InfoBaseUser = Undefined Then
			Return False;
		EndIf;
	EndIf;
	
	IsCurrentInfoBaseUser = InfoBaseUser.UUID = InfoBaseUsers.CurrentUser().UUID;
	
	RoleNameArray = StringFunctionsClientServer.SplitStringIntoSubstringArray(RoleNames);
	For Each RoleName In RoleNameArray Do
		
		If IsCurrentInfoBaseUser Then
			If IsInRole(TrimAll(RoleName)) Then
				Return True;
			EndIf;
		Else
			If InfoBaseUser.Roles.Contains(Metadata.Roles.Find(TrimAll(RoleName))) Then
				Return True;
			EndIf;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

// Is used when updating and initial filling of the infobase.
// 1) Creates the first administrator and sets a correspondence between them and a 
//    new or existent user from the User catalog.
// 2) Sets a correspondence between the administrator that is specified in the Account  
//    parameter and a new or existent user from the User catalog.
//
// Parameters:
//  Account          - InfoBaseUser, Optional - is used to set a correspondence between 
//                     the existent administrator and a new or existent user from the
//                     User catalog. 
//
// Returns:
//  Undefined        - if the user that corresponds to the infobase user with 
//                     administrative rights already exists. 
//  CatalogRef.Users - User that corresponds to the first administrator or the
//                     administrator that is specified in the Account parameter.
//
Function CreateFirstAdministrator(Account = Undefined) Export
	
	// Adding the administrator (administrator has full rights).
	If Account = Undefined Then
		
		If CommonUseCached.DataSeparationEnabled() Then
			Return Undefined;
		EndIf;
		
		// If the user with administrative rights is already exists, 
		// there is no need to create the administrator again.
		Account = Undefined;
	
		SetPrivilegedMode(True);
		AllInfoBaseUsers = InfoBaseUsers.GetUsers();
		SetPrivilegedMode(False);
		For Each InfoBaseUser In AllInfoBaseUsers Do
			If InfoBaseUserWithFullAccess(InfoBaseUser) Then
				Return Undefined;
			EndIf;
		EndDo;
		If Account = Undefined Then
			SetPrivilegedMode(True);
			Account = InfoBaseUsers.CreateUser();
			Account.Name     = "Administrator";
			Account.FullName = Account.Name;
			Account.Roles.Clear();
			Account.Roles.Add(Metadata.Roles.FullAccess);
			If Not CommonUseCached.DataSeparationEnabled() Then
				FullAdministratorRole = FullAdministratorRole();
				If Not Account.Roles.Contains(FullAdministratorRole) Then
					Account.Roles.Add(FullAdministratorRole);
				EndIf;
			EndIf;
			Account.Write();
			SetPrivilegedMode(False);
		EndIf;
	Else
		FindAmbiguousInfoBaseUsers(, Account.UUID);
	EndIf;
	
	If UserByIDExists(Account.UUID) Then
		User = Catalogs.Users.FindByAttribute("InfoBaseUserID", Account.UUID);
		// The administrator cannot correspond to an external user. Clearing this correspondence.
		If Not ValueIsFilled(User) Then
			ExternalUser = Catalogs.ExternalUsers.FindByAttribute("InfoBaseUserID", Account.UUID);
			ExternalUserObject = ExternalUser.GetObject();
			ExternalUserObject.DataExchange.Load = True;
			ExternalUserObject.Write();
		EndIf;
	EndIf;
	
	If Not ValueIsFilled(User) Then
		User = Catalogs.Users.FindByDescription(Account.FullName);
		If ValueIsFilled(User)
		   And ValueIsFilled(User.InfoBaseUserID)
		   And User.InfoBaseUserID <> Account.UUID
		   And InfoBaseUsers.FindByUUID(User.InfoBaseUserID) <> Undefined Then
			User = Undefined;
		EndIf;
	EndIf;
	
	If Not ValueIsFilled(User) Then
		User = Catalogs.Users.CreateItem();
		UserCreated = True;
	Else
		User = User.GetObject();
		UserCreated = False;
	EndIf;
	User.InfoBaseUserID = Account.UUID;
	User.Description = Account.FullName;
	User.DataExchange.Load = True;
	User.Write();
	If UserCreated Then
		UpdateUserGroupContent(Catalogs.UserGroups.AllUsers);
	EndIf;
	
	UsersOverridable.OnWriteFirstAdministrator(User.Ref);
	
	Return User.Ref;
	
EndFunction

// Returns a role that provides system administrative rights.
//
// Returns:
//  MetadataObject: Role.
//
Function FullAdministratorRole() Export
	
	FullAdministratorRole = Metadata.Roles.FullAdministrator;
	
	If StandardSubsystemsOverridable.IsBaseConfigurationVersion() Then
		FullAdministratorRole = Metadata.Roles.FullAccess;
	EndIf;
	
	UsersOverridable.ChangeFullAdministratorRole(FullAdministratorRole);
	
	Return FullAdministratorRole;
	
EndFunction

// Returns a Users catalog user that corresponds to the infobase user with the 
// specified name.
// Administrative rights are required for this search. If the current user does not 
// have administrative rights, it is allowed to search a user for the current infobase
// user only.
// 
// Parameters:
//  UserName - String - infobase user name.
//
// Returns:
//  CatalogRef.Users          - if the user is found.
//  Catalogs.Users.EmptyRef() - if the infobase user is found.
//  Undefined                 - if the user is not found.
//
Function FindByName(Val IBUserName) Export
	
	InfoBaseUser = InfoBaseUsers.FindByName(IBUserName);
	
	If InfoBaseUser = Undefined Then
		Return Undefined;
	Else
		FindAmbiguousInfoBaseUsers(, InfoBaseUser.UUID);
		Return Catalogs.Users.FindByAttribute("InfoBaseUserID", InfoBaseUser.UUID);
	EndIf;
	
EndFunction

// Returns a list of users, user groups, external users, and external user groups that
// are not marked for deletion.
// Is used in TextEditEnd and AutoComplete event handlers.
//
// Parameters:
//  Text                   - String - text typed by user.
//  IcludingGroups         - Boolean - flag that shows whether user groups and   
//                           external user groups will be included. If the   
//                           UseUserGroups functional option is disabled, the function 
//                           ignores this parameter.
//  IncludingExternalUsers - Undefined or Boolean - if it is Undefined, the return 
//                           value of the ExternalUsers.UseExternalUsers function is
//                           used.
//  NoUsers                - Boolean - flag that shows whether the Users catalog items 
//                           will be excluded from the result.
//
Function GenerateUserChoiceData(Val Text, Val IcludingGroups = True, Val IncludingExternalUsers = Undefined, NoUsers = False) Export
	
	IcludingGroups = IcludingGroups And GetFunctionalOption("UseUserGroups");
	
	Query = New Query;
	Query.SetParameter("Text", Text + "%");
	Query.SetParameter("IcludingGroups", IcludingGroups);
	Query.SetParameter("EmptyUUID", New UUID("00000000-0000-0000-0000-000000000000"));
	Query.Text = 
	"SELECT ALLOWED
	|	VALUE(Catalog.Users.EmptyRef) AS Ref,
	|	"""" AS Description,
	|	-1 AS PictureNumber
	|WHERE
	|	FALSE";
	
	If Not NoUsers Then
		Query.Text = Query.Text + " UNION ALL" +
		"SELECT
		|	Users.Ref,
		|	Users.Description,
		|	CASE
		|		WHEN Users.InfoBaseUserID = &EmptyUUID
		|			THEN 4
		|		ELSE 1
		|	END AS PictureNumber
		|FROM
		|	Catalog.Users AS Users
		|WHERE
		|	(NOT Users.DeletionMark)
		|	AND Users.Description LIKE &Text
		|	AND Users.NotValid = FALSE
		|
		|UNION ALL
		|
		|SELECT
		|	UserGroups.Ref,
		|	UserGroups.Description,
		|	3
		|FROM
		|	Catalog.UserGroups AS UserGroups
		|WHERE
		|	&IcludingGroups
		|	AND (NOT UserGroups.DeletionMark)
		|	AND UserGroups.Description LIKE &Text";
	EndIf;
	
	If TypeOf(IncludingExternalUsers) <> Type("Boolean") Then
		IncludingExternalUsers = ExternalUsers.UseExternalUsers();
	EndIf;
	IncludingExternalUsers = IncludingExternalUsers And AccessRight("Read", Metadata.Catalogs.ExternalUsers);
	
	If IncludingExternalUsers Then
		Query.Text = Query.Text + " UNION ALL" +
		"SELECT
		|	ExternalUsers.Ref,
		|	ExternalUsers.Description,
		|	CASE
		|		WHEN ExternalUsers.InfoBaseUserID = &EmptyUUID
		|			THEN 10
		|		ELSE 7
		|	END AS PictureNumber
		|FROM
		|	Catalog.ExternalUsers AS ExternalUsers
		|WHERE
		|	(NOT ExternalUsers.DeletionMark)
		|	AND ExternalUsers.Description LIKE &Text
		|	AND ExternalUsers.NotValid = FALSE
		|
		|UNION ALL
		|
		|SELECT
		|	ExternalUserGroups.Ref,
		|	ExternalUserGroups.Description,
		|	9
		|FROM
		|	Catalog.ExternalUserGroups AS ExternalUserGroups
		|WHERE
		|	&IcludingGroups
		|	AND (NOT ExternalUserGroups.DeletionMark)
		|	AND ExternalUserGroups.Description LIKE &Text";
	EndIf;
	
	Selection = Query.Execute().Select();
	
	ChoiceData = New ValueList;
	
	While Selection.Next() Do
		ChoiceData.Add(Selection.Ref, Selection.Description, , PictureLib["UserState" + Format(Selection.PictureNumber + 1, "ND=2; NLZ=; NG=")]);
	EndDo;
	
	Return ChoiceData;
	
EndFunction

// Fills picture numbers of users, user groups, external users, and external user groups.
//
// Parameters:
//  Table                               - FormDataCollection or FormDataTree.
//  UserFieldName                       - String - name of a field that contains
//                                        a reference to a user, user group, external
//                                        user, or external user group.
//  PictureNumberFieldName              - String - name of a field that contains the
//                                        picture number to be set.
//  RowID                               - Undefined or Number - string ID (not a serial
//                                        number). If it is Undefined, picture numbers
//                                        for all rows will be filled.
//  ProcessSecondAndThirdLevelHierarchy - Boolean - flag that shows whether second and
//                                        third levels of hierarchy will be processed.
//
Procedure FillUserPictureNumbers(Val Table, Val UserFieldName, Val PictureNumberFieldName, Val RowID = Undefined, Val ProcessSecondAndThirdLevelHierarchy = False) Export
	
	SetPrivilegedMode(True);
	
	If RowID = Undefined Then
		RowArray = Undefined;
	Else
		SelectedRow = Table.FindByID(RowID);
		RowArray = New Array;
		RowArray.Add(SelectedRow);
	EndIf;
	
	If TypeOf(Table) = Type("FormDataTree") Then
		If RowArray = Undefined Then
			RowArray = Table.GetItems();
		EndIf;
		UserTable = New ValueTable;
		UserTable.Columns.Add(UserFieldName, Metadata.InformationRegisters.UserGroupContent.Dimensions.UserGroup.Type);
		For Each Row In RowArray Do
			UserTable.Add()[UserFieldName] = Row[UserFieldName];
			If ProcessSecondAndThirdLevelHierarchy Then
				For Each Row2 In Row.GetItems() Do
					UserTable.Add()[UserFieldName] = Row2[UserFieldName];
					For Each Row3 In Row2.GetItems() Do
						UserTable.Add()[UserFieldName] = Row3[UserFieldName];
					EndDo;
				EndDo;
			EndIf;
		EndDo;
	Else
		UserTable = Table.Unload(RowArray, UserFieldName);
		RowArray = Table;
	EndIf;
	
	Query = New Query(StrReplace(
	"SELECT DISTINCT
	|	Users.UserFieldName AS User
	|INTO Users
	|FROM
	|	&Users AS Users
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Users.User,
	|	CASE
	|		WHEN Users.User = UNDEFINED
	|			THEN -1
	|		WHEN VALUETYPE(Users.User) = TYPE(Catalog.Users)
	|			THEN CASE
	|					WHEN CAST(Users.User AS Catalog.Users).DeletionMark
	|						THEN 0
	|					ELSE CASE
	|							WHEN CAST(Users.User AS Catalog.Users).InfoBaseUserID = &EmptyUUID
	|								THEN 4
	|							ELSE 1
	|						END
	|				END
	|		WHEN VALUETYPE(Users.User) = TYPE(Catalog.UserGroups)
	|			THEN CASE
	|					WHEN CAST(Users.User AS Catalog.UserGroups).DeletionMark
	|						THEN 2
	|					ELSE 3
	|				END
	|		WHEN VALUETYPE(Users.User) = TYPE(Catalog.ExternalUsers)
	|			THEN CASE
	|					WHEN CAST(Users.User AS Catalog.ExternalUsers).DeletionMark
	|						THEN 6
	|					ELSE CASE
	|							WHEN CAST(Users.User AS Catalog.ExternalUsers).InfoBaseUserID = &EmptyUUID
	|								THEN 10
	|							ELSE 7
	|						END
	|				END
	|		WHEN VALUETYPE(Users.User) = TYPE(Catalog.ExternalUserGroups)
	|			THEN CASE
	|					WHEN CAST(Users.User AS Catalog.ExternalUserGroups).DeletionMark
	|						THEN 8
	|					ELSE 9
	|				END
	|		ELSE -2
	|	END AS PictureNumber
	|FROM
	|	Users AS Users", "UserFieldName", UserFieldName));
	Query.SetParameter("Users", UserTable);
	Query.SetParameter("EmptyUUID", New UUID("00000000-0000-0000-0000-000000000000"));
	PictureNumbers = Query.Execute().Unload();
	
	If RowID = Undefined Then
		For Each Row In RowArray Do
			Row[PictureNumberFieldName] = PictureNumbers.Find(Row[UserFieldName], "User").PictureNumber;
			If ProcessSecondAndThirdLevelHierarchy Then
				For Each Row2 In Row.GetItems() Do
					Row2[PictureNumberFieldName] = PictureNumbers.Find(Row2[UserFieldName], "User").PictureNumber;
					For Each Row3 In Row2.GetItems() Do
						Row3[PictureNumberFieldName] = PictureNumbers.Find(Row3[UserFieldName], "User").PictureNumber;
					EndDo;
				EndDo;
			EndIf;
		EndDo;
	Else
		SelectedRow[PictureNumberFieldName] = PictureNumbers.Find(SelectedRow[UserFieldName], "User").PictureNumber;
		If ProcessSecondAndThirdLevelHierarchy Then
			For Each Row2 In SelectedRow.GetItems() Do
				Row2[PictureNumberFieldName] = PictureNumbers.Find(Row2[UserFieldName], "User").PictureNumber;
				For Each Row3 In Row2.GetItems() Do
					Row3[PictureNumberFieldName] = PictureNumbers.Find(Row3[UserFieldName], "User").PictureNumber;
				EndDo;
			EndDo;
		EndIf;
	EndIf;
	
EndProcedure

// Sets the UseUserGroups constant value to True
// if there are one or more user groups in the catalog.
//
// Is used when updating the infobase.
//
Procedure IfUserGroupsExistSetUse() Export
	
	SetPrivilegedMode(True);
	
	Query = New Query(
	"SELECT
	|	TRUE AS TrueValue
	|FROM
	|	Catalog.UserGroups AS UserGroups
	|WHERE
	|	UserGroups.Ref <> VALUE(Catalog.UserGroups.AllUsers)
	|
	|UNION ALL
	|
	|SELECT
	|	TRUE
	|FROM
	|	Catalog.ExternalUserGroups AS ExternalUserGroups
	|WHERE
	|	ExternalUserGroups.Ref <> VALUE(Catalog.ExternalUserGroups.AllExternalUsers)");
	
	If Not Query.Execute().IsEmpty() Then
		Constants.UseUserGroups.Set(True);
	EndIf;
	
EndProcedure

// Returns an empty structure of infobase user details.
//
// Returns:
//  Structure with the following fields:
//   InfoBaseUserUUID                   - UUID.
//   InfoBaseUserName                   - String.
//   InfoBaseUserFullName               - String.
//
//   InfoBaseUserStandardAuthentication - Boolean.
//   InfoBaseUserShowInList             - Boolean.
//   InfoBaseUserPassword               - Undefined.
//   InfoBaseUserStoredPasswordValue    - Undefined.
//   InfoBaseUserPasswordIsSet          - Boolean.
//   InfoBaseUserCannotChangePassword   - Boolean.
//   InfoBaseUserOSAuthentication       - Boolean.
//   InfoBaseUserOSUser                 - String.
//   InfoBaseUserDefaultInterface       - String - name of an interface from the
//                                        Metadata.Interfaces collection.
//   InfoBaseUserRunMode                - String - possible values: "Auto",
//                                        "OrdinaryApplication",
//                                        "ManagedApplication".
//   InfoBaseUserLanguage               - String - name of a language from
//                                        the Metadata.Languages collection.
//
Function NewInfoBaseUserInfo() Export
	
	// Preparing the return structure
	Properties = New Structure;
	Properties.Insert("InfoBaseUserUUID",   New UUID("00000000-0000-0000-0000-000000000000"));
	Properties.Insert("InfoBaseUserName",                   "");
	Properties.Insert("InfoBaseUserFullName",               "");
	Properties.Insert("InfoBaseUserStandardAuthentication", False);
	Properties.Insert("InfoBaseUserShowInList",             False);
	Properties.Insert("InfoBaseUserPassword",               Undefined);
	Properties.Insert("InfoBaseUserStoredPasswordValue",    Undefined);
	Properties.Insert("InfoBaseUserPasswordIsSet",          False);
	Properties.Insert("InfoBaseUserCannotChangePassword",   False);
	Properties.Insert("InfoBaseUserOSAuthentication",       False);
	Properties.Insert("InfoBaseUserOSUser",                 "");
	Properties.Insert("InfoBaseUserDefaultInterface",       ?(Metadata.DefaultInterface = Undefined, "", Metadata.DefaultInterface.Name));
	Properties.Insert("InfoBaseUserRunMode",                "Auto");
	Properties.Insert("InfoBaseUserLanguage",               ?(Metadata.DefaultLanguage = Undefined, "", Metadata.DefaultLanguage.Name));
	
	Return Properties;
	
EndFunction

// Searches for infobase user IDs that are used more than once and
// raises an exception or returns found IDs for arbitrary processing.
//
// Parameters:
//  User           - Undefined - all users and external users will be checked.
//                 - CatalogRef.Users Or CatalogRef.ExternalUsers - only the specified
//                   user will be checked.
//  InfoBaseUserID - Undefined - all infobase user IDs will be checked.
//                 - UUID - only the specified ID will be checked.
//  FoundIDs       - Undefined - exception is raised if errors are found.
//                 - Map - the passed map is filled if errors are found. The map
//                   contains the following key and value:
//                    Key - ambiguous infobase user ID.
//                    Value - array of users and external users.
//
Procedure FindAmbiguousInfoBaseUsers(Val User = Undefined, Val InfoBaseUserID = Undefined, Val FoundIDs = Undefined) Export
	
	SetPrivilegedMode(True);
	
	If TypeOf(InfoBaseUserID) <> Type("UUID") Then
		InfoBaseUserID = New UUID("00000000-0000-0000-0000-000000000000");
	EndIf;
	
	Query = New Query;
	Query.SetParameter("User", User);
	Query.SetParameter("InfoBaseUserID", InfoBaseUserID);
	Query.SetParameter("EmptyUUID",  New UUID("00000000-0000-0000-0000-000000000000"));
	Query.Text =
	"SELECT
	|	UserIDs.InfoBaseUserID,
	|	UserIDs.User
	|FROM
	|	(SELECT
	|		Users.InfoBaseUserID AS InfoBaseUserID,
	|		Users.Ref AS User
	|	FROM
	|		Catalog.Users AS Users
	|	
	|	UNION
	|	
	|	SELECT
	|		ExternalUsers.InfoBaseUserID,
	|		ExternalUsers.Ref
	|	FROM
	|		Catalog.ExternalUsers AS ExternalUsers) AS UserIDs
	|WHERE
	|	UserIDs.InfoBaseUserID IN
	|			(SELECT
	|				UserIDs.InfoBaseUserID
	|			FROM
	|				(SELECT
	|					Users.InfoBaseUserID AS InfoBaseUserID,
	|					Users.Ref AS User
	|				FROM
	|					Catalog.Users AS Users
	|				WHERE
	|					Users.InfoBaseUserID <> &EmptyUUID
	|					AND NOT(&User <> UNDEFINED
	|							AND Users.Ref <> &User)
	|					AND NOT(&InfoBaseUserID <> &EmptyUUID
	|							AND Users.InfoBaseUserID <> &InfoBaseUserID)
	|		
	|				UNION ALL
	|		
	|				SELECT
	|					ExternalUsers.InfoBaseUserID,
	|					ExternalUsers.Ref
	|				FROM
	|					Catalog.ExternalUsers AS ExternalUsers
	|				WHERE
	|					ExternalUsers.InfoBaseUserID <> &EmptyUUID
	|					AND NOT(&User <> UNDEFINED
	|							AND ExternalUsers.Ref <> &User)
	|					AND NOT(&InfoBaseUserID <> &EmptyUUID
	|							AND ExternalUsers.InfoBaseUserID <> &InfoBaseUserID)
	|				) AS UserIDs
	|			GROUP BY
	|						UserIDs.InfoBaseUserID
	|			HAVING
	|				КОЛИЧЕСТВО(UserIDs.User) > 1)
	|
	|ORDER BY
	|	UserIDs.InfoBaseUserID";
	
	Data = Query.Execute().Unload();
	
	If Data.Count() = 0 Then
		Return;
	EndIf;
	
	ErrorDescription = NStr("en = 'Database error:'") + Chars.LF;
	CurrentAmbiguousID = Undefined;
	
	For Each Row In Data Do
		NewInfoBaseUserID = False;
		If Row.InfoBaseUserID <> CurrentAmbiguousID Then
			NewInfoBaseUserID = True;
			CurrentAmbiguousID = Row.InfoBaseUserID;
			If TypeOf(FoundIDs) = Type("Map") Then
				CurrentUsers = New Array;
				FoundIDs.Insert(CurrentAmbiguousID, CurrentUsers);
			Else
				CurrentInfoBaseUser = InfoBaseUsers.FindByUUID(CurrentAmbiguousID);
				If CurrentInfoBaseUser = Undefined Then
					IBUserName = NStr("en = '<not found>'");
				Else
					IBUserName = CurrentInfoBaseUser.Name;
				EndIf;
				ErrorDescription = ErrorDescription
					+ StringFunctionsClientServer.SubstituteParametersInString(
						NStr("en = 'More then one database users correspond
						          |to the infobase user %1 with ID %2:'"),
						IBUserName,
						CurrentAmbiguousID);
			EndIf;
		EndIf;
		If TypeOf(FoundIDs) = Type("Map") Then
			CurrentUsers.Add(Row.User);
		Else
			If Not NewInfoBaseUserID Then
				ErrorDescription = ErrorDescription + ",";
			EndIf;
			ErrorDescription = ErrorDescription
				+ StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = '
					           |	%1 with reference ID %2'"),
					Row.User,
					Row.User.UUID());
		EndIf;
	EndDo;
	
	If TypeOf(FoundIDs) <> Type("Map") Then
		ErrorDescription = ErrorDescription + "." + Chars.LF;
		Raise ErrorDescription;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL INTERFACE

// Fills the CurrentUser Or CurrentExternalUser session parameter with a user value 
// that is found by the infobase user on behalf of which the session is run.
// If the user is not found and the current user is a user with full access, 
// a new user will be created in the catalog. If the user is not found and the current
// user is not a user with full access, an exception will be raised.
//
Procedure SetSessionParameters(Val ParameterName, AssignedParameters) Export
	
	SetPrivilegedMode(True);
	
	UserNotFound = False;
	CreateUser  = False;
	RefNew = Undefined;
	
	If IsBlankString(InfoBaseUsers.CurrentUser().Name) Then
		
		SessionParameters.CurrentExternalUser = Catalogs.ExternalUsers.EmptyRef();
		
		UnspecifiedUserProperties = UnspecifiedUserProperties();
		
		UserName       = UnspecifiedUserProperties.FullName;
		UserFullName = UnspecifiedUserProperties.FullName;
		RefNew          = UnspecifiedUserProperties.StandardRef;
		
		If UnspecifiedUserProperties.Ref = Undefined Then
			UserNotFound = True;
			CreateUser  = True;
			InfoBaseUserID = "";
		Else
			SessionParameters.CurrentUser = UnspecifiedUserProperties.Ref;
		EndIf;
	Else
		InfoBaseUserID = InfoBaseUsers.CurrentUser().UUID;
		
		FindAmbiguousInfoBaseUsers(, InfoBaseUserID);
		
		Query = New Query;
		Query.Parameters.Insert("InfoBaseUserID", InfoBaseUserID);
		
		Query.Text =
		"SELECT TOP 1
		|	Users.Ref AS Ref
		|FROM
		|	Catalog.Users AS Users
		|WHERE
		|	Users.InfoBaseUserID = &InfoBaseUserID";
		UsersResult = Query.Execute();
		
		Query.Text =
		"SELECT TOP 1
		|	ExternalUsers.Ref AS Ref
		|FROM
		|	Catalog.ExternalUsers AS ExternalUsers
		|WHERE
		|	ExternalUsers.InfoBaseUserID = &InfoBaseUserID";
		ResultExternalUsers = Query.Execute();
		
		If Not ResultExternalUsers.IsEmpty() Then
			
			Selection = ResultExternalUsers.Select();
			Selection.Next();
			SessionParameters.CurrentUser         = Catalogs.Users.EmptyRef();
			SessionParameters.CurrentExternalUser = Selection.Ref;
			
			If Not ExternalUsers.UseExternalUsers() Then
			
				ErrorMessageText = NStr("en = 'External users are disabled.'");
				Raise ErrorMessageText;
			EndIf;
		Else
			SessionParameters.CurrentExternalUser = Catalogs.ExternalUsers.EmptyRef();
			
			If UsersResult.IsEmpty() Then
				If InfoBaseUserWithFullAccess(,,False) Then
					
					CurrentUser        = InfoBaseUsers.CurrentUser();
					UserName           = CurrentUser.Name;
					UserFullName       = CurrentUser.FullName;
					InfoBaseUserID     = CurrentUser.UUID;
					UserByDescription  = UserRefByFullDescription(UserFullName);
					
					If UserByDescription = Undefined Then
						UserNotFound = True;
						CreateUser  = True;
					Else
						SessionParameters.CurrentUser = UserByDescription;
					EndIf;
				Else
					UserNotFound = True;
				EndIf;
			Else
				Selection = UsersResult.Select();
				Selection.Next();
				SessionParameters.CurrentUser = Selection.Ref;
			EndIf;
		EndIf;
	EndIf;
	
	If CreateUser Then
		
		BeginTransaction();
		
		StandardSubsystemsOverridable.RegisterSharedUser();
		
		If RefNew = Undefined Then
			RefNew = Catalogs.Users.GetRef();
		EndIf;
		SessionParameters.CurrentUser = RefNew;
		
		NewUser = Catalogs.Users.CreateItem();
		NewUser.InfoBaseUserID = InfoBaseUserID;
		NewUser.Description    = UserFullName;
		NewUser.SetNewObjectRef(RefNew);
		
		Try
			NewUser.Write();
		Except
			ErrorMessageText = StringFunctionsClientServer.SubstituteParametersInString(
			                           NStr("en = 'Authorization failed.
                                        |The user %1 is not found in the Users catalog.
                                        |
                                        |Please contact your infobase administrator.
                                        |Error adding a user to the catalog.
                                        |%2'"),
			                           UserName,
			                           BriefErrorDescription(ErrorInfo()) );
			Raise ErrorMessageText;
		EndTry;
		
		CommitTransaction();
	
	ElsIf UserNotFound Then
		Raise UserNotFoundInCatalogMessageText(UserName);
	EndIf;
	
	AssignedParameters.Add(ParameterName);
	
EndProcedure

// Is called when starting the application to check whether authorization can be
// performed. Calls filling the CurrentUser and CurrentExternalUser session parameters.
//
// Returns:
// String - error message text, if it is not empty, the application must be closed.
//
Function AuthenticateCurrentUser() Export
	
	SetPrivilegedMode(True);
	
	CurrentUser = InfoBaseUsers.CurrentUser();
	CheckUserRights(CurrentUser);
	
	StandardSubsystemsOverridable.RegisterSharedUser();
	
	If IsBlankString(CurrentUser.Name)
	 Or UserByIDExists(CurrentUser.UUID) Then
		// The default user is authorizing 
		// or InfoBaseUser is not found in the catalog.
		Return "";
	EndIf;
	
	If CommonUseCached.DataSeparationEnabled()
		And CurrentUser.DataSeparation.Count() = 0 Then
		
		
		BeginTransaction();
		
		// The user is a shared one, an item in the current data area must be created
		UserObject = Catalogs.Users.CreateItem();
		UserObject.Description = CurrentUser.Name;
		UserObject.InfoBaseUserID = CurrentUser.UUID;
		UserObject.Write();
		
		CommitTransaction();
		SetPrivilegedMode(False);
		
		Return "";
	EndIf;
	
	// Creating an administrator or preparing an error message text
	ErrorMessageText = "";
	CreateAdministratorRequired = False;
	
	AllInfoBaseUsers = InfoBaseUsers.GetUsers();
	
	If AllInfoBaseUsers.Count() = 1 Or InfoBaseUserWithFullAccess(, True, False) Then
		// The administrator that was created in the designer mode is authorizing
		CreateAdministratorRequired = True;
	Else
		// The ordinary user that was created in the designer mode is authorizing
		ErrorMessageText = UserNotFoundInCatalogMessageText(CurrentUser.Name);
	EndIf;
	
	If CreateAdministratorRequired Then
		//
		If IsInRole(Metadata.Roles.FullAccess)
			And IsInRole(FullAdministratorRole()) Then
			//
			User = CreateFirstAdministrator(CurrentUser);
			//
			Comment = NStr("en = 'The application is being started on behalf of the user with
				                 |the Full access role that was not registered in the user list.
				                 |The user has been registered in the user list automatically.
				                 |
				                 |It is recommended that you do not use the designer mode to
				                 |customize user profiles. Use the Users list instead.'");
			UsersOverridable.AfterWriteAdministratorOnAuthorization(Comment);
			WriteLogEvent(
					NStr("en = 'Users. Administrator registered in Users catalog'", Metadata.DefaultLanguage.LanguageCode),
					EventLogLevel.Warning,
					Metadata.Catalogs.Users,
					User,
					Comment);
		Else
			ErrorMessageText = NStr("en = 'The application cannot be started on behalf of the
				                     |user with administrative rights because this user is not
				                     |registered in the user list.
				                     |
				                     |It is recommended that you do not use the designer mode to
				                     |customize user profiles. Use the Users list instead.'");
		EndIf;
	EndIf;
	
	Return ErrorMessageText;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Infobase update.

// Adds update handlers required to this subsystem to the Handlers list. 
// 
// Parameters:
// Handlers - ValueTable - see InfoBaseUpdate.NewUpdateHandlerTable function for details.
// 
Procedure RegisterUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version = "1.0.5.2";
	Handler.Procedure = "Users.FillUserIDs";
	
	Handler = Handlers.Add();
	Handler.Version = "1.0.5.15";
	Handler.Procedure = "Users.FillUserGroupContentRegister";
	
	Handler = Handlers.Add();
	Handler.Version = "1.0.6.5";
	Handler.Procedure = "ExternalUsers.FillExternalUserGroupContent";
	
	Handler = Handlers.Add();
	Handler.Version = "1.0.6.5";
	Handler.Procedure = "ExternalUsers.ForExternalUsersCreateInfoBaseUsers";
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

Function CreateFirstAdministratorRequired(Val InfoBaseUserInfoStructure, QuestionText = Undefined) Export
	
	If CommonUseCached.DataSeparationEnabled()
		And CommonUseCached.CanUseSeparatedData() Then
		
		Return False;
	EndIf;
	
	SetPrivilegedMode(True);
	
	If InfoBaseUsers.GetUsers().Count() = 0 Then
		
		If InfoBaseUserInfoStructure.Property("InfoBaseUserRoles") Then
			Roles = InfoBaseUserInfoStructure.InfoBaseUserRoles;
		Else
			Roles = New Array;
		EndIf;
		
		If UsersOverridable.RoleEditProhibition()
			Or Roles.Find("FullAccess") = Undefined
			Or Roles.Find(FullAdministratorRole().Name) = Undefined Then
			
			// Preparing a question text that will be used when writing the first administrator
			QuestionText  = NStr("en='The user you want to add is the first infobase user. "
"This user will be automatically included into the"
"Administrators access group. '");
			UsersOverridable.QuestionTextBeforeWriteFirstAdministrator(QuestionText);
			Return True;
		EndIf;
	EndIf;
	
	Return False;
	
EndFunction

// Returns the access level for editing the current user property.
//
// Returns: 
// String.
//  It can take one of the following values:
//   "FullAccess"     - any user properties can be changed.
//   "ListManagement" - user list but not user rights can be changed.
//   "ChangeCurrent"  - following properties of the current user can be changed:  
//                       "Name", "Password", and "Language".
//   "AccessDenied"   - no user properties can be changed.
//
Function GetEditInfoBaseUserPropertiesAccessLevel() Export
	
	If InfoBaseUserWithFullAccess() Then
		Return "FullAccess";
		
	ElsIf IsInRole(Metadata.Roles.AddEditUsers) Then
		Return "ListManagement";
		
	ElsIf IsInRole(Metadata.Roles.ChangingCurrentUser) Then
		Return "ChangeCurrent";
	Else
		Return "AccessDenied";
	EndIf;
	
EndFunction

// For internal use only.
//
Function UnspecifiedUserFullName() Export
	
	Return NStr("en='<Not specified>'");
	
EndFunction

// For internal use only.
//
Function UnspecifiedUserProperties() Export
	
	SetPrivilegedMode(True);
	
	Properties = New Structure;
	
	// A reference to the found catalog item that corresponds to an unspecified user.
	Properties.Insert("Ref", Undefined);
	
	// A reference that is used for searching and creating an unspecified user in
	// the Users catalog.
	Properties.Insert("StandardRef", Catalogs.Users.GetRef(
		New UUID("aa00559e-ad84-4494-88fd-f0826edc46f0")));
	
	// A full name that is set to a Users catalog item when creating a non-existent
	// unspecified user.
	Properties.Insert("FullName", UnspecifiedUserFullName());
	
	// A full name that is used to provide the old way of unspecified user search 
	// (supporting old versions). There is no need to change this name.
	Properties.Insert("FullNameForSearch", NStr("en = '<Not specified>'"));
	
	// Search by UUID
	Query = New Query;
	Query.SetParameter("Ref", Properties.StandardRef);
	Query.Text =
	"SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	Catalog.Users AS Users
	|WHERE
	|	Users.Ref = &Ref";
	
	If Query.Execute().IsEmpty() Then
		Query.SetParameter("FullName", Properties.FullNameForSearch);
		Query.Text =
		"SELECT TOP 1
		|	Users.Ref
		|FROM
		|	Catalog.Users AS Users
		|WHERE
		|	Users.Description = &FullName";
		Result = Query.Execute();
		
		If Not Result.IsEmpty() Then
			Selection = Result.Select();
			Selection.Next();
			Properties.Ref = Selection.Ref;
		EndIf;
	Else
		Properties.Ref = Properties.StandardRef;
	EndIf;
	
	Return Properties;
	
EndFunction

// Reads infobase user properties by string ID or UUID.
//
// Parameters:
//  ID              - Undefined, String, UUID.
//  Properties      - Structure with the following fields:
//                     InfoBaseUserUUID                   - UUID.
//                     InfoBaseUserName                   - String.
//                     InfoBaseUserFullName               - String.
//                     InfoBaseUserStandardAuthentication - Boolean.
//                     InfoBaseUserShowInList             - Boolean.
//                     InfoBaseUserPassword               - Undefined.
//                     InfoBaseUserStoredPasswordValue    - String.
//                     InfoBaseUserPasswordIsSet          - Boolean.
//                     InfoBaseUserCannotChangePassword   - Boolean.
//                     InfoBaseUserOSAuthentication       - Boolean.
//                     InfoBaseUserOSUser                 - String.
//                     InfoBaseUserDefaultInterface       - String - interface 
//                                                          name from the 
//                                                          Metadata.Interfaces
//                                                          collection.
//                     InfoBaseUserRunMode                - String - possible 
//                                                          values are: "Auto",
//                                                          "OrdinaryApplication",
//                                                          "ManagedApplication".
//                     InfoBaseUserLanguage               - String - language name
//                                                          from the 
//                                                          Metadata.Languages
//                                                          collection.
//  Roles            - Array of String - role names from the Metadata.Roles collection.
//  
//  ErrorDescription - String -  contains error details if reading failed.
//
// Returns:
//  Boolean          - True if reading finished successfully, otherwise is False.
//
Function ReadInfoBaseUser(Val ID, Properties = Undefined, Roles = Undefined, ErrorDescription = "", InfoBaseUser = Undefined) Export
	
	Properties = NewInfoBaseUserInfo();
	
	Roles = New Array;
	
	If TypeOf(ID) = Type("UUID") Then
		InfoBaseUser = InfoBaseUsers.FindByUUID(ID);
	ElsIf TypeOf(ID) = Type("String") Then
		InfoBaseUser = InfoBaseUsers.FindByName(ID);
	Else
		InfoBaseUser = Undefined;
	EndIf;
	
	If InfoBaseUser = Undefined Then
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(NStr("en = 'The infobase user with %1 ID is not found.'"), ID);
		Return False;
	EndIf;
	
	Properties.InfoBaseUserUUID                   = InfoBaseUser.UUID;
	Properties.InfoBaseUserName                   = InfoBaseUser.Name;
	Properties.InfoBaseUserFullName               = InfoBaseUser.FullName;
	Properties.InfoBaseUserStandardAuthentication = InfoBaseUser.StandardAuthentication;
	Properties.InfoBaseUserShowInList             = InfoBaseUser.ShowInList;
	Properties.InfoBaseUserStoredPasswordValue    = InfoBaseUser.StoredPasswordValue;
	Properties.InfoBaseUserPasswordIsSet          = InfoBaseUser.PasswordIsSet;
	Properties.InfoBaseUserCannotChangePassword   = InfoBaseUser.CannotChangePassword;
	Properties.InfoBaseUserOSAuthentication       = InfoBaseUser.OSAuthentication;
	Properties.InfoBaseUserOSUser                 = InfoBaseUser.OSUser;
	Properties.InfoBaseUserDefaultInterface       = ?(InfoBaseUser.DefaultInterface = Undefined, "", InfoBaseUser.DefaultInterface.Name);
	ValueFullNameRunMode                          = GetPredefinedValueFullName(InfoBaseUser.RunMode);
	Properties.InfoBaseUserRunMode                = Mid(ValueFullNameRunMode, Find(ValueFullNameRunMode, ".") + 1);
	Properties.InfoBaseUserLanguage               = ?(InfoBaseUser.Language = Undefined, "", InfoBaseUser.Language.Name);
	
	For Each Role In InfoBaseUser.Roles Do
		Roles.Add(Role.Name);
	EndDo;
	
	Return True;
	
EndFunction

// Checks whether infobase user detail structure is filled correctly. 
// Sets the Cancel parameter to True if an error is found.
// Sends error messages.
//
// Parameters:
//  InfoBaseUserInfoStructure - Structure - infobase user details to be checked. 
//  Cancel                    - Boolean - flag that shows whether execution must be
//                                        canceled. 
//
// Returns:
//  Boolean - flag that shows that no errors were found.
//
Function CheckInfoBaseUserInfoStructureFilling(Val InfoBaseUserInfoStructure, Cancel) Export
	
	If InfoBaseUserInfoStructure.Property("InfoBaseUserName") Then
	
		If IsBlankString(InfoBaseUserInfoStructure.InfoBaseUserName) Then
			
			CommonUseClientServer.MessageToUser(
				NStr("en = 'The infobase user name is not specified.'"),
				,
				"InfoBaseUserName",
				,
				Cancel);
		EndIf;
		
	EndIf;
	
	If InfoBaseUserInfoStructure.Property("InfoBaseUserPassword") Then
		
		If InfoBaseUserInfoStructure.InfoBaseUserPassword <> Undefined
			And InfoBaseUserInfoStructure.InfoBaseUserPassword <> InfoBaseUserInfoStructure.PasswordConfirmation Then
			
			CommonUseClientServer.MessageToUser(
				NStr("en = 'The password and password confirmation do not match.'"),
				,
				"Password",
				,
				Cancel);
		EndIf;
		
	EndIf;
	
	If InfoBaseUserInfoStructure.Property("InfoBaseUserOSUser") Then
		
		If Not IsBlankString(InfoBaseUserInfoStructure.InfoBaseUserOSUser) Then
			
			SetPrivilegedMode(True);
			Try
				InfoBaseUser = InfoBaseUsers.CreateUser();
				InfoBaseUser.OSUser = InfoBaseUserInfoStructure.InfoBaseUserOSUser;
			Except
				CommonUseClientServer.MessageToUser(
					NStr("en = 'The OS user must be specified in the following format:
					           |""\\DomainName\UserName"".'"),
					,
					"InfoBaseUserOSUser",
					,
					Cancel);
			EndTry;
			SetPrivilegedMode(False);
		EndIf;
		
	EndIf;
	
	Return Not Cancel;
	
EndFunction

// Overwrites properties of the infobase user that is found by string ID or UUID
// or creates a new infobase user (if user already exists creating a new one will
// raise an error).
//
// Parameters:
// ID                - String, UUID.
// ChangedProperties - Structure - if this parameter is not set, the default or read 
//                     value will be used. The structure contains the following
//                     parameters:
//                      InfoBaseUserUUID                   - Undefined - the return
//                                                           value, it is set after
//                                                           writing the infobase
//                                                           user). 
//                      InfoBaseUserName                   - Undefined, String.
//                      InfoBaseUserFullName               - Undefined, String.
//                      InfoBaseUserStandardAuthentication - Undefined, Boolean.
//                      InfoBaseUserShowInList             - Undefined, Boolean
//                      InfoBaseUserPassword               - Undefined, String.
//                      InfoBaseUserStoredPasswordValue    - Undefined, String.
//                      InfoBaseUserPasswordIsSet          - Undefined, Boolean.
//                      InfoBaseUserCannotChangePassword   - Undefined, Boolean
//                      InfoBaseUserOSAuthentication       - Undefined, Boolean.
//                      InfoBaseUserOSUser                 - Undefined, String.
//                      InfoBaseUserDefaultInterface       - Undefined, String -
//                                                           interface name from the
//                                                           Metadata.Interfaces
//                                                           collection.
//                      InfoBaseUserRunMode                - Undefined, String - it can
//                                                           take one of the following
//                                                           values: "Auto",
//                                                           "OrdinaryApplication",
//                                                           "ManagedApplication".
//                      InfoBaseUserLanguage               - Undefined, String -
//                                                           language name from the
//                                                           Metadata.Languages
//                                                           collection.
//  NewRoles         - Undefined, Array of String - role names from the Metadata.Roles
//                     collection.
//  ErrorDescription - String - contains error details if overwriting failed.
//
// Returns:
//  Boolean          - True if overwriting finished successfully, otherwise is False.
//
Function WriteIBUser(Val ID, Val ChangedProperties, Val NewRoles, Val CreateNew = False, ErrorDescription = "") Export
	
	InfoBaseUser = Undefined;
	OldProperties = Undefined;
	
	PreliminaryRead = ReadInfoBaseUser(ID, OldProperties, , ErrorDescription, InfoBaseUser);
	
	If Not PreliminaryRead Then
		
		If CreateNew = Undefined Or CreateNew = True Then
			InfoBaseUser = InfoBaseUsers.CreateUser();
		Else
			Return False;
		EndIf;
	ElsIf CreateNew = True Then
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'The infobase user %1 cannot be created because this user is already exists.'"),
				ID);
		Return False;
	EndIf;
	
	// Preparing new property values
	NewProperties = CommonUseClientServer.CopyStructure(OldProperties);
	
	For Each KeyAndValue In NewProperties Do
		If ChangedProperties.Property(KeyAndValue.Key) And ChangedProperties[KeyAndValue.Key] <> Undefined Then
			NewProperties[KeyAndValue.Key] = ChangedProperties[KeyAndValue.Key];
		EndIf;
	EndDo;
	
	If NewRoles <> Undefined Then
		Roles = NewRoles;
	EndIf;
	
	// Setting new property values
	InfoBaseUser.Name                   = NewProperties.InfoBaseUserName;
	InfoBaseUser.FullName               = NewProperties.InfoBaseUserFullName;
	InfoBaseUser.StandardAuthentication = NewProperties.InfoBaseUserStandardAuthentication;
	
	If CommonUseCached.DataSeparationEnabled() Then
		InfoBaseUser.ShowInList = False;
	Else
		InfoBaseUser.ShowInList = NewProperties.InfoBaseUserShowInList;
	EndIf;
	
	If NewProperties.InfoBaseUserPassword <> Undefined Then
		InfoBaseUser.Password            = NewProperties.InfoBaseUserPassword;
	ElsIf NewProperties.InfoBaseUserStoredPasswordValue <> Undefined Then
		InfoBaseUser.StoredPasswordValue = NewProperties.InfoBaseUserStoredPasswordValue
	EndIf;
	
	InfoBaseUser.CannotChangePassword = NewProperties.InfoBaseUserCannotChangePassword;
	InfoBaseUser.OSAuthentication     = NewProperties.InfoBaseUserOSAuthentication;
	InfoBaseUser.OSUser               = NewProperties.InfoBaseUserOSUser;
	
	If ValueIsFilled(NewProperties.InfoBaseUserDefaultInterface) Then
		InfoBaseUser.DefaultInterface = Metadata.Interfaces[NewProperties.InfoBaseUserDefaultInterface];
	Else
		InfoBaseUser.DefaultInterface = Undefined;
	EndIf;
	
	If ValueIsFilled(NewProperties.InfoBaseUserRunMode) Then
		InfoBaseUser.RunMode = ClientRunMode[NewProperties.InfoBaseUserRunMode];
	EndIf;
	
	If ValueIsFilled(NewProperties.InfoBaseUserLanguage) Then
		InfoBaseUser.Language = Metadata.Languages[NewProperties.InfoBaseUserLanguage];
	Else
		InfoBaseUser.Language = Undefined;
	EndIf;
	
	If NewRoles <> Undefined Then
		InfoBaseUser.Roles.Clear();
		For Each Role In NewRoles Do
			InfoBaseUser.Roles.Add(Metadata.Roles[Role]);
		EndDo;
	EndIf;
	
	// Adding the FullAccess role if there is a first user with the empty role list
	If Not CommonUseCached.DataSeparationEnabled()
		And InfoBaseUsers.GetUsers().Count() = 0 Then
		
		If Not InfoBaseUser.Roles.Contains(Metadata.Roles.FullAccess) Then
		
			InfoBaseUser.Roles.Add(Metadata.Roles.FullAccess);
		EndIf;
		
		If Not InfoBaseUser.Roles.Contains(FullAdministratorRole()) Then
		
			InfoBaseUser.Roles.Add(FullAdministratorRole());
		EndIf;
	EndIf;
	
	// Attempting to write the new or changed infobase user
	Try
		WriteInfoBaseUser(InfoBaseUser);
	Except
		ErrorInfo = ErrorInfo();
		If ErrorInfo.Cause = Undefined Then
			ErrorDescription = ErrorInfo.Description;
		Else
			ErrorDescription = ErrorInfo.Cause.Description;
		EndIf;
		ErrorDescription = NStr("en = 'Error writing the infobase user:'") + Chars.LF + ErrorDescription;
		
		WriteLogEvent(NStr("en = 'Users'", Metadata.DefaultLanguage.LanguageCode), EventLogLevel.Error, , ,
			DetailErrorDescription(ErrorInfo));
		
		Return False;
	EndTry;
	
	UsersOverridable.OnWriteInfoBaseUser(OldProperties, NewProperties);
	
	ChangedProperties.Insert("InfoBaseUserUUID", InfoBaseUser.UUID);
	Return True;
	
EndFunction

// Writes the specified infobase user taking into account the data separation mode.
// If data separation is enabled, rights of the user to be written is checked before writing.
//
// Parameters:
// InfoBaseUser - InfoBaseUser - object to be written.
//
Procedure WriteInfoBaseUser(InfoBaseUser) Export
	
	If CommonUseCached.DataSeparationEnabled() Then
		
		If StandardSubsystemsOverridable.IsSharedInfoBaseUser(InfoBaseUser.UUID) Then
			Raise(NStr("en = 'Shared users cannot be written when data separation is enabled.'"))
		EndIf;
		
	EndIf;
	
	CheckUserRights(InfoBaseUser);
	
	InfoBaseUser.Write();

EndProcedure

// Verifying rights of the specified infobase user in data separation mode.
// Parameters:
//  InfoBaseUser - InfoBaseUser.
//
Procedure CheckUserRights(InfoBaseUser) Export
	
	If CommonUseCached.DataSeparationEnabled() Then
		
		If InfoBaseUser.DataSeparation.Count() > 0 Then
			
			InaccessibleRights = UsersServerCached.InaccessibleRightsByUserType(
				Enums.UserTypes.DataAreaUser);
				
			InaccessibleRole = Undefined;
			
			For Each Role In InfoBaseUser.Roles Do
				
				AvailableForChangesSharedData = UsersServerCached.SharedDataAvailableForChanges(Role.Name);
				
				If AvailableForChangesSharedData.Count() > 0 Then
					InaccessibleRole = Role;
					
					Writer = New XMLWriter;
					Writer.SetString();
					XDTOSerializer.WriteXML(Writer, AvailableForChangesSharedData);
					TableAsString = Writer.Close();
					
					WriteLogEvent(
						NStr("en = 'Users.Writing'", Metadata.DefaultLanguage.LanguageCode),
						EventLogLevel.Error,
						,
						InfoBaseUser,
						NStr("en = 'The role that provides common data editing is set for the separated user:'") + TableAsString);
				EndIf;
					
				For Each Right In InaccessibleRights Do
					
					If AccessRight(Right, Metadata, Role) Then
						InaccessibleRole = Role;
						
						MessagePattern = NStr("en = 'The role that provides the %1 right is set for the separated user.'");
						MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, Right);
						
						WriteLogEvent(
							NStr("en = 'Users.Writing'", Metadata.DefaultLanguage.LanguageCode),
							EventLogLevel.Error,
							,
							InfoBaseUser,
							MessageText);
					EndIf;
				EndDo;
			EndDo;
			
			If InaccessibleRole <> Undefined Then
				MessagePattern = NStr("en = 'The %1 role cannot be set for separated users.'");
				Raise StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, InaccessibleRole.Presentation());
			EndIf;
			
		EndIf;
	EndIf;
	
EndProcedure

// Deletes the specified infobase user.
//
// Parameters:
//  ID - String or UUID - infobase user name or UUID.
//  ErrorDescription    - String - contains error details if deletion failed.
//
// Returns:
//  Boolean              - True if deletion completed successfully, otherwise is False.
//
Function DeleteInfoBaseUser(Val ID, ErrorDescription = "") Export
	
	If CommonUseCached.DataSeparationEnabled()
		And StandardSubsystemsOverridable.IsSharedInfoBaseUser(ID) Then
		
		Raise(NStr("en = 'Shared users cannot be deleted when data separation is enabled.'"));
	EndIf;
	
	InfoBaseUser = Undefined;
	Properties   = Undefined;
	Roles        = Undefined;
	
	If Not ReadInfoBaseUser(ID, Properties, Roles, ErrorDescription, InfoBaseUser) Then
		Return False;
	Else
		Try
			InfoBaseUser.Delete();
		Except
			ErrorDescription = NStr("en = 'Error deleting the infobase user:'") + Chars.LF + ErrorInfo().Cause.Details;
			Return False;
		EndTry;
	EndIf;
	
	UsersOverridable.AfterInfoBaseUserDelete(Properties);
	
	Return True;
	
EndFunction

// Checks whether the infobase user exists.
//
// Parameters:
//  ID - String or UUID - infobase user name or UUID.
//
// Returns:
//  Boolean.
//
Function InfoBaseUserExists(Val ID) Export
	
	SetPrivilegedMode(True);
	
	If TypeOf(ID) = Type("UUID") Then
		InfoBaseUser = InfoBaseUsers.FindByUUID(ID);
	Else
		InfoBaseUser = InfoBaseUsers.FindByName(ID);
	EndIf;
	
	If InfoBaseUser = Undefined Then
		Return False;
	Else
		Return True;
	EndIf;
	
EndFunction

// Checks whether the item exists in the Users catalog or the ExternalUsers catalog
// by infobase user UUID.
// Does not check how many users or external users correspond to the infobase user.
//
// Parameters:
//  UUID         - infobase user UUID.
//  RefToCurrent - CatalogRef.Users, CatalogRef.ExternalUsers - reference to be
//                 excluded from the search. 
//                 Undefined - searching among all catalog items.
//
// Returns:
//  Boolean.
//
Function UserByIDExists(UUID, RefToCurrent = Undefined) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	TRUE AS TrueValue
	|FROM
	|	Catalog.Users AS Users
	|WHERE
	|	Users.InfoBaseUserID = &UUID
	|	AND Users.Ref <> &RefToCurrent
	|
	|UNION ALL
	|
	|SELECT
	|	TRUE
	|FROM
	|	Catalog.ExternalUsers AS ExternalUsers
	|WHERE
	|	ExternalUsers.InfoBaseUserID = &UUID
	|	AND ExternalUsers.Ref <> &RefToCurrent";
	Query.SetParameter("RefToCurrent", RefToCurrent);
	Query.SetParameter("UUID", UUID);
	
	If Not Query.Execute().IsEmpty() Then
		FindAmbiguousInfoBaseUsers(, UUID);
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

// Checks whether InfoBaseUser corresponds to the item of the Users catalog or
// the ExternalUsers catalog.
// 
// Parameters:
//  UserName - String - infobase user name.
//
// Returns:
//  Boolean.
//
Function InfoBaseUserAssigned(Val UserName) Export
	
	SetPrivilegedMode(True);
	
	InfoBaseUser = InfoBaseUsers.FindByName(UserName);
	
	If InfoBaseUser = Undefined Then
		Return True;
	EndIf;
	
	If UserByIDExists(InfoBaseUser.UUID) Then
		Return False;
	Else
		Return True;
	EndIf
	
EndFunction

// Is used in UpdateUserGroupContent and UpdateExternalUserGroupContent procedures.
//
// Parameters:
//  Table - metadata object full name.
//
// Returns:
//  ValueTable with Ref and Parent fields.
//
Function ParentGroupTable(Table) Export
	
	// Preparing the parent group table
	Query = New Query(
	"SELECT
	|	TableGroups.Ref,
	|	TableGroups.Parent
	|FROM
	|	" + Table + " AS TableGroups");
	ItemTable = Query.Execute().Unload();
	ItemTable.Indexes.Add("Parent");
	ParentGroupTable = ItemTable.Copy(New Array);
	
	For Each ItemDetails In ItemTable Do
		ParentGroupDetails = ParentGroupTable.Add();
		ParentGroupDetails.Parent = ItemDetails.Ref;
		ParentGroupDetails.Ref    = ItemDetails.Ref;
		FillParentGroups(ItemDetails.Ref, ItemDetails.Ref, ItemTable, ParentGroupTable);
	EndDo;
	
	Return ParentGroupTable;
	
EndFunction

// Updates the user group content taking the UserGroupContent information register
// hierarchy into account.
// Register data is used in the user list form and in the user choice form.
// Register data can be used for improving query performance, as there is no need to
// process the hierarchy.
// 
// Parameters:
//  UserGroup - CatalogRef.UserGroups.
//
Procedure UpdateUserGroupContent(Val UserGroup) Export
	
	If Not ValueIsFilled(UserGroup) Then
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	
	// Preparing parent groups
	Query = New Query(
	"SELECT
	|	ParentGroupTable.Parent,
	|	ParentGroupTable.Ref
	|INTO ParentGroupTable
	|FROM
	|	&ParentGroupTable AS ParentGroupTable");
	Query.SetParameter("ParentGroupTable", ParentGroupTable("Catalog.UserGroups"));
	Query.TempTablesManager = New TempTablesManager;
	Query.Execute();
	
	// Processing the current group and each parent group
	While Not UserGroup.IsEmpty() Do
		
		Query.SetParameter("UserGroup", UserGroup);
		
		If UserGroup <> Catalogs.UserGroups.AllUsers Then
			// Deleting relations of deleted users.
			Query.Text =
			"SELECT DISTINCT
			|	UserGroupContent.User
			|FROM
			|	InformationRegister.UserGroupContent AS UserGroupContent
			|		LEFT JOIN Catalog.UserGroups.Content AS UserGroupContent2
			|			INNER JOIN ParentGroupTable AS ParentGroupTable
			|			ON (ParentGroupTable.Ref = UserGroupContent2.Ref)
			|				AND (ParentGroupTable.Parent = &UserGroup)
			|		ON (UserGroupContent.UserGroup = &UserGroup)
			|			AND (UserGroupContent2.User = UserGroupContent.User)
			|WHERE
			|	UserGroupContent.UserGroup = &UserGroup
			|	AND UserGroupContent2.Ref IS NULL ";
			DeletedFromGroupUsers = Query.Execute().Select();
			RecordManager = InformationRegisters.UserGroupContent.CreateRecordManager();
			While DeletedFromGroupUsers.Next() Do
				RecordManager.UserGroup = UserGroup;
				RecordManager.User      = DeletedFromGroupUsers.User;
				RecordManager.Delete();
			EndDo;
		EndIf;
		
		// Adding relations of added users.
		If UserGroup = Catalogs.UserGroups.AllUsers Then
			Query.Text =
			"SELECT
			|	VALUE(Catalog.UserGroups.AllUsers) AS UserGroup,
			|	Users.Ref AS User
			|FROM
			|	Catalog.Users AS Users
			|		LEFT JOIN InformationRegister.UserGroupContent AS UserGroupContent
			|			ON (UserGroupContent.UserGroup = VALUE(Catalog.UserGroups.AllUsers))
			|			AND (UserGroupContent.User = Users.Ref)
			|WHERE
			|	UserGroupContent.User IS NULL 
			|
			|UNION
			|
			|SELECT
			|	Users.Ref,
			|	Users.Ref
			|FROM
			|	Catalog.Users AS Users
			|		LEFT JOIN InformationRegister.UserGroupContent AS UserGroupContent
			|			ON (UserGroupContent.UserGroup = Users.Ref)
			|			AND (UserGroupContent.User = Users.Ref)
			|WHERE
			|	UserGroupContent.User IS NULL ";
		Else
			Query.Text =
			"SELECT DISTINCT
			|	&UserGroup AS UserGroup,
			|	UserGroupContent.User
			|FROM
			|	Catalog.UserGroups.Content AS UserGroupContent
			|		INNER JOIN ParentGroupTable AS ParentGroupTable
			|		ON (ParentGroupTable.Ref = UserGroupContent.Ref)
			|			AND (ParentGroupTable.Parent = &UserGroup)
			|		LEFT JOIN InformationRegister.UserGroupContent AS UserGroupContent2
			|		ON (UserGroupContent2.UserGroup = &UserGroup)
			|			AND (UserGroupContent2.User = UserGroupContent.User)
			|WHERE
			|	UserGroupContent.User IS NULL ";
		EndIf;
		UsersAddedToGroup = Query.Execute().Unload();
		If UsersAddedToGroup.Count() > 0 Then
			RecordSet = InformationRegisters.UserGroupContent.CreateRecordSet();
			RecordSet.Load(UsersAddedToGroup);
			RecordSet.Write(False); // Adding missing relation records
		EndIf;
		
		UserGroup = CommonUse.GetAttributeValue(UserGroup, "Parent");
	EndDo;
	
EndProcedure

// For internal use only.
//
Function GetStoredPasswordValueByPassword(Val Password) Export
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	TempInfobaseUser = InfoBaseUsers.CreateUser();
	TempInfobaseUser.StandardAuthentication = True;
	TempInfobaseUser.Name = New UUID;
	TempInfobaseUser.Password = Password;
	TempInfobaseUser.Write();
	
	TempInfobaseUser = InfoBaseUsers.FindByUUID(TempInfobaseUser.UUID);
	
	StoredPasswordValue = TempInfobaseUser.StoredPasswordValue;
	RollbackTransaction();
	
	Return StoredPasswordValue;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions

Function UserNotFoundInCatalogMessageText(UserName)
	
	If ExternalUsers.UseExternalUsers() Then
		ErrorMessageText = NStr("en = 'Authorization failed. The application will be closed.
		                              |The user %1 is not found in the Users and External
		                              |users catalogs.
		                              |Please contact your infobase administrator.'");
	Else
		ErrorMessageText = NStr("en = 'Authorization failed. The application will be closed.
		                              |The user %1 is not found in the Users catalog.
		                              |Please contact your infobase administrator.'");
	EndIf;
	
	ErrorMessageText = StringFunctionsClientServer.SubstituteParametersInString(ErrorMessageText, UserName);
	
	Return ErrorMessageText;
	
EndFunction

Procedure FillParentGroups(Val Parent, Val CurrentParent, Val ItemTable, Val ParentTable)
	
	ParentGroupDetails = ItemTable.FindRows(New Structure("Parent", CurrentParent));
	For Each GroupDetails In ParentGroupDetails Do
		ParentGroupDetails = ParentTable.Add();
		ParentGroupDetails.Parent = Parent;
		ParentGroupDetails.Ref   = GroupDetails.Ref;
		FillParentGroups(Parent, GroupDetails.Ref, ItemTable, ParentTable);
	EndDo;
	
EndProcedure

Function UserRefByFullDescription(FullName)
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = "SELECT Ref AS Ref
					|FROM
					|	Catalog.Users AS Users
					|WHERE
					|	Users.Description = &FullName";
	Query.SetParameter("FullName", FullName);
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return Undefined;
	EndIf;
	
	Selection = QueryResult.Select();
	Selection.Next();
	
	User = Selection.Ref;
	
	If InfoBaseUserAssigned(User.InfoBaseUserID) Then
		Return User;
	EndIf;
	
	Return Undefined;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Infobase update

// Is called when updating the configuration to the version 1.0.5.2
// Attempts to fill InfoBaseUserID property of each User catalog item.
//
Procedure FillUserIDs() Export
	
	SetPrivilegedMode(True);
	
	FindAmbiguousInfoBaseUsers();
	
	UserList = Catalogs.Users.Select();
	
	AllInfoBaseUsers = InfoBaseUsers.GetUsers();
	UnspecifiedUserProperties = UnspecifiedUserProperties();
	
	While UserList.Next() Do
		User = UserList.Ref;
		
		If Not ValueIsFilled(User.InfoBaseUserID)
		   And User <> UnspecifiedUserProperties.Ref Then
			
			UserFullName = TrimAll(User.Description);
			For Each InfoBaseUser In AllInfoBaseUsers Do
				If UserFullName = TrimAll(Left(InfoBaseUser.FullName, Metadata.Catalogs.Users.DescriptionLength))
				   And Not UserByIDExists(InfoBaseUser.UUID) Then
					UserObject = User.GetObject();
					UserObject.InfoBaseUserID = InfoBaseUser.UUID;
					UserObject.Write();
					Continue;
				EndIf;
			EndDo;
		EndIf;
	EndDo;
	
EndProcedure

// Is called when updating the configuration to the version 1.0.5.15
// Overwrites all users.
// Can be called for the version 1.0.5.15 and later.
//
Procedure FillUserGroupContentRegister() Export
	
	SetPrivilegedMode(True);
	
	Selection = Catalogs.Users.Select();
	While Selection.Next() Do
		
		Object = Selection.GetObject();
		Object.Write();
		
	EndDo;
	
EndProcedure
