#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
 
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	InfobaseUserFull = Users.InfobaseUserWithFullAccess();
	AccessFlag = Parameters.User = Users.AuthorizedUser();
	
	InfobaseUserResponsible =
		Not InfobaseUserFull
		And AccessRight("Edit", Metadata.Catalogs.AccessGroups);
	
	Items.AccessGroupsContextMenuChangeGroup.Visible =
		InfobaseUserFull
		Or InfobaseUserResponsible;
	
	Items.FormAccessRightsReport.Visible =
		InfobaseUserFull
		Or Parameters.User = Users.AuthorizedUser();
	
	// Setting commands for a regular user
	Items.FormAddToGroup.Visible   = InfobaseUserResponsible;
	Items.FormRemoveFromGroup.Visible = InfobaseUserResponsible;
	Items.FormChangeGroup.Visible    = InfobaseUserResponsible;
	
	// Setting commands for a full user
	Items.AccessGroupsIncludeInGroup.Visible   = InfobaseUserFull;
	Items.AccessGroupsExcludedFromGroup.Visible = InfobaseUserFull;
	Items.AccessGroupsChangeGroup.Visible    = InfobaseUserFull;
	
	// Setting the page tab view
	Items.AccessGroupsAndRoles.PagesRepresentation =
		?(InfobaseUserFull,
		  FormPagesRepresentation.TabsOnTop,
		  FormPagesRepresentation.None);
	
	// Setting the command panel view for a full user
	Items.AccessGroups.CommandBarLocation =
		?(InfobaseUserFull,
		  FormItemCommandBarLabelLocation.Top,
		  FormItemCommandBarLabelLocation.None);
	
	// Setting the role view for a full user
	Items.RoleRepresentation.Visible = InfobaseUserFull;
	
	If InfobaseUserFull
	 Or InfobaseUserResponsible
	 Or AccessFlag Then
		
		OutputAccessGroups();
	Else
		// Regular users cannot view other users' access settings
		Items.AccessGroupsIncludeInGroup.Visible   = False;
		Items.AccessGroupsExcludedFromGroup.Visible = False;
		
		Items.AccessGroupsAndRoles.Visible         = False;
		Items.InsufficientViewRight.Visible = True;
	EndIf;
	
	ProcessRolesInterface("SetUpRoleInterfaceOnFormCreate");
	ProcessRolesInterface("SetRolesReadOnly", True);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If Upper(EventName) = Upper("Write_AccessGroups")
	 Or Upper(EventName) = Upper("Write_AccessGroupProfiles")
	 Or Upper(EventName) = Upper("Write_UserGroups")
	 Or Upper(EventName) = Upper("Write_ExternalUserGroups") Then
		
		OutputAccessGroups();
		UsersInternalClient.ExpandRoleSubsystems(ThisObject);
	EndIf;
	
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	ProcessRolesInterface("SetUpRoleInterfaceOnLoadSettings", Settings);
	
EndProcedure

#EndRegion

#Region AccessGroupsFormTableItemEventHandlers

&AtClient
Procedure AccessGroupsOnActivateRow(Item)
	
	CurrentData   = Items.AccessGroups.CurrentData;
	CurrentParent = Items.AccessGroups.CurrentParent;
	
	If CurrentData = Undefined Then
		
		AccessGroupChanged = ValueIsFilled(CurrentAccessGroup);
		CurrentAccessGroup  = Undefined;
	Else
		NewAccessGroup    = ?(CurrentParent = Undefined, CurrentData.AccessGroup, CurrentParent.AccessGroup);
		AccessGroupChanged = CurrentAccessGroup <> NewAccessGroup;
		CurrentAccessGroup  = NewAccessGroup;
	EndIf;
	
EndProcedure

&AtClient
Procedure AccessGroupsChoice(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	If AccessGroups.FindByID(SelectedRow) <> Undefined Then
		
		If Items.FormChangeGroup.Visible
		 Or Items.AccessGroupsChangeGroup.Visible Then
			
			ChangeGroup(Items.FormChangeGroup);
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure IncludeInGroup(Command)
	
	FormParameters = New Structure;
	Selected = New Array;
	
	For Each AccessGroupDescription In AccessGroups Do
		Selected.Add(AccessGroupDescription.AccessGroup);
	EndDo;
	
	FormParameters.Insert("Selected",         Selected);
	FormParameters.Insert("GroupUser", Parameters.User);
	
	OpenForm("Catalog.AccessGroups.Form.SelectionByResponsible", FormParameters, ThisObject,
		,,, New NotifyDescription("IncludeExcludeFromGroup", ThisObject, True));
	
EndProcedure

&AtClient
Procedure DeleteFromGroup(Command)
	
	If Not ValueIsFilled(CurrentAccessGroup) Then
		ShowMessageBox(, NStr("en = 'No access group is selected.'"));
		Return;
	EndIf;
	
	IncludeExcludeFromGroup(CurrentAccessGroup, False);
	
EndProcedure

&AtClient
Procedure ChangeGroup(Command)
	
	FormParameters = New Structure;
	
	If Not ValueIsFilled(CurrentAccessGroup) Then
		ShowMessageBox(, NStr("en = 'No access group is selected.'"));
		Return;
		
	ElsIf InfobaseUserFull
	      Or InfobaseUserResponsible
	          And GroupUserContentChangeIsAllowed(CurrentAccessGroup) Then
		
		FormParameters.Insert("Key", CurrentAccessGroup);
		OpenForm("Catalog.AccessGroups.ObjectForm", FormParameters);
	Else
		ShowMessageBox(,
			NStr("en = 'Insufficient permissions to edit access groups.
			           |Only the user responsible for access group members and the administrator can edit the access group.'"));
		Return;
	EndIf;
	
EndProcedure

&AtClient
Procedure Refresh(Command)
	
	OutputAccessGroups();
	UsersInternalClient.ExpandRoleSubsystems(ThisObject);
	
EndProcedure

&AtClient
Procedure AccessRightReport(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("User", Parameters.User);
	
	OpenForm("Report.AccessRights.Form", FormParameters);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Role interface procedures and functions

&AtClient
Procedure RoleGroupingBySubsystems(Command)
	
	ProcessRolesInterface("GroupBySubsystems");
	UsersInternalClient.ExpandRoleSubsystems(ThisObject);
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtClient
Procedure IncludeExcludeFromGroup(AccessGroup, IncludeInAccessGroup) Export
	
	If TypeOf(AccessGroup) <> Type("CatalogRef.AccessGroups")
	  Or Not ValueIsFilled(AccessGroup) Then
		
		Return;
	EndIf;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("AccessGroup", AccessGroup);
	AdditionalParameters.Insert("IncludeInAccessGroup", IncludeInAccessGroup);
	
	If StandardSubsystemsClientCached.ClientParameters().DataSeparationEnabled
	   And AccessGroup = PredefinedValue("Catalog.AccessGroups.Administrators") Then
		
		StandardSubsystemsClient.PasswordForAuthenticationInServiceOnRequest(
			New NotifyDescription(
				"IncludeExcludFromGroupCompletion", ThisObject, AdditionalParameters),
			ThisObject,
			ServiceUserPassword);
		Return;
	Else
		IncludeExcludFromGroupCompletion("", AdditionalParameters);
	EndIf;
	
EndProcedure

&AtClient
Procedure IncludeExcludFromGroupCompletion(SaaSUserNewPassword, AdditionalParameters) Export
	
	If SaaSUserNewPassword = Undefined Then
		Return;
	EndIf;
	
	ServiceUserPassword = SaaSUserNewPassword;
	
	ErrorDescription = "";
	
	ChangeGroupContent(
		AdditionalParameters.AccessGroup,
		AdditionalParameters.IncludeInAccessGroup,
		ErrorDescription);
	
	If ValueIsFilled(ErrorDescription) Then
		ShowMessageBox(, ErrorDescription);
	Else
		NotifyChanged(AdditionalParameters.AccessGroup);
		Notify("Write_AccessGroups", New Structure, AdditionalParameters.AccessGroup);
	EndIf;
	
EndProcedure

&AtServer
Procedure OutputAccessGroups()
	
	Query = New Query;
	Query.TempTablesManager = New TempTablesManager;
	
	If InfobaseUserFull Or AccessFlag Then
		SetPrivilegedMode(True);
	EndIf;
	
	Query.Text =
	"SELECT ALLOWED
	|	AccessGroups.Ref
	|INTO AllowedAccessGroups
	|FROM
	|	Catalog.AccessGroups AS AccessGroups";
	Query.Execute();
	
	SetPrivilegedMode(True);
	
	Query.Text =
	"SELECT
	|	AllowedAccessGroups.Ref
	|FROM
	|	AllowedAccessGroups AS AllowedAccessGroups
	|WHERE
	|	(Not AllowedAccessGroups.Ref.DeletionMark)
	|	AND (Not AllowedAccessGroups.Ref.Profile.DeletionMark)";
	AllowedAccessGroups = Query.Execute().Unload();
	AllowedAccessGroups.Indexes.Add("Ref");
	
	Query.SetParameter("User", Parameters.User);
	Query.Text =
	"SELECT
	|	AccessGroups.Ref AS AccessGroup,
	|	AccessGroups.Ref.Description AS Description,
	|	AccessGroups.Ref.Profile.Description AS ProfileDescription,
	|	AccessGroups.Ref.Details AS Details,
	|	AccessGroups.Ref.Responsible AS Responsible
	|FROM
	|	(SELECT DISTINCT
	|		AccessGroups.Ref AS Ref
	|	FROM
	|		Catalog.AccessGroups AS AccessGroups
	|			INNER JOIN Catalog.AccessGroups.Users AS AccessGroupUsers
	|			ON (AccessGroupUsers.User IN
	|					(SELECT
	|						&User
	|				
	|					UNION ALL
	|				
	|					SELECT
	|						UserGroupContents.UserGroup
	|					FROM
	|						InformationRegister.UserGroupContents AS UserGroupContents
	|					WHERE
	|						UserGroupContents.User = &User))
	|				AND AccessGroups.Ref = AccessGroupUsers.Ref
	|				AND (Not AccessGroups.DeletionMark)
	|				AND (Not AccessGroups.Profile.DeletionMark)) AS AccessGroups
	|
	|ORDER BY
	|	AccessGroups.Ref.Description";
	
	AllAccessGroups = Query.Execute().Unload();
	
	// Setting the access group presentation
	// Removing the current user from the access group if they have direct membership only
	HasProhibitedGroups = False;
	Index = AllAccessGroups.Count()-1;
	
	While Index >= 0 Do
		Row = AllAccessGroups[Index];
		
		If AllowedAccessGroups.Find(Row.AccessGroup, "Ref") = Undefined Then
			AllAccessGroups.Delete(Index);
			HasProhibitedGroups = True;
		EndIf;
		Index = Index - 1;
	EndDo;
	
	ValueToFormAttribute(AllAccessGroups, "AccessGroups");
	Items.WarningHasHiddenAccessGroups.Visible = HasProhibitedGroups;
	
	If Not ValueIsFilled(CurrentAccessGroup) Then
		
		If AccessGroups.Count() > 0 Then
			CurrentAccessGroup = AccessGroups[0].AccessGroup;
		EndIf;
	EndIf;
	
	For Each AccessGroupDescription In AccessGroups Do
		
		If AccessGroupDescription.AccessGroup = CurrentAccessGroup Then
			Items.AccessGroups.CurrentRow = AccessGroupDescription.GetID();
			Break;
		EndIf;
	EndDo;
	
	If InfobaseUserFull Then
		FillRoles();
	EndIf;
	
EndProcedure

&AtServer
Procedure ChangeGroupContent(Val AccessGroup, Val Add, ErrorDescription = "")
	
	If Not GroupUserContentChangeIsAllowed(AccessGroup) Then
		If Add Then
			ErrorDescription = NStr("en = 'It is impossible to add the user to the access group
                                 |as the current user is 
                                 |neither the access group member manager 
                                 |nor a full administrator.'");
		Else
			ErrorDescription = NStr("en = 'It is impossible to remove the user form the access group
                                 |as the current user is 
                                 |neither the access group memeber manager
                                 |nor a full administrator.'");
		EndIf;
		Return;
	EndIf;
	
	If Not Add And Not UserIsIncludedInAccessGroup(CurrentAccessGroup) Then
		ErrorDescription =  NStr("en = 'It is impossible to remove the user 
                             |access group because their membership is indirect.'");
		Return;
	EndIf;
	
	If CommonUseCached.DataSeparationEnabled()
		And AccessGroup = Catalogs.AccessGroups.Administrators Then
		
		ActionsWithSaaSUser = Undefined;
		AccessManagementInternal.OnReceiveActionsWithSaaSUser(ActionsWithSaaSUser);
		
		If Not ActionsWithSaaSUser.ChangeAdmininstrativeAccess Then
			Raise
				NStr("en = 'Insufficient permissions to change the administrator content.'");
		EndIf;
	EndIf;
	
	SetPrivilegedMode(True);
	
	AccessGroupObject = AccessGroup.GetObject();
	LockDataForEdit(AccessGroupObject.Ref, AccessGroupObject.DataVersion);
	If Add Then
		If AccessGroupObject.Users.Find(Parameters.User, "User") = Undefined Then
			AccessGroupObject.Users.Add().User = Parameters.User;
		EndIf;
	Else
		TSRow = AccessGroupObject.Users.Find(Parameters.User, "User");
		If TSRow <> Undefined Then
			AccessGroupObject.Users.Delete(TSRow);
		EndIf;
	EndIf;
	
	If AccessGroupObject.Ref = Catalogs.AccessGroups.Administrators Then
		
		If CommonUseCached.DataSeparationEnabled() Then
			AccessGroupObject.AdditionalProperties.Insert(
				"ServiceUserPassword", ServiceUserPassword);
		Else
			AccessManagementInternal.CheckAdministratorsAccessGroupForInfobaseUser(
				AccessGroupObject.Users, ErrorDescription);
			
			If ValueIsFilled(ErrorDescription) Then
				Return;
			EndIf;
		EndIf;
	EndIf;
	
	Try
		AccessGroupObject.Write();
	Except
		ServiceUserPassword = Undefined;
		Raise;
	EndTry;
	
	UnlockDataForEdit(AccessGroupObject.Ref);
	
	CurrentAccessGroup = AccessGroupObject.Ref;
	
EndProcedure

&AtServer
Function GroupUserContentChangeIsAllowed(AccessGroup)
	
	If InfobaseUserFull Then
		Return True;
	EndIf;
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.SetParameter("AccessGroup", AccessGroup);
	Query.SetParameter("AuthorizedUser", Users.AuthorizedUser());
	Query.Text =
	"SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	Catalog.AccessGroups AS AccessGroups
	|		INNER JOIN InformationRegister.UserGroupContents AS UserGroupContents
	|		ON (UserGroupContents.User = &AuthorizedUser)
	|			AND (UserGroupContents.UserGroup = AccessGroups.Responsible)
	|			AND (AccessGroups.Ref = &AccessGroup)";
	
	Return Not Query.Execute().IsEmpty();
	
EndFunction

&AtServer
Function UserIsIncludedInAccessGroup(AccessGroup)
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.SetParameter("AccessGroup", AccessGroup);
	Query.SetParameter("User", Parameters.User);
	Query.Text =
	"SELECT
	|	TRUE AS TrueValue
	|FROM
	|	Catalog.AccessGroups.Users AS AccessGroupsUsers
	|WHERE
	|	AccessGroupsUsers.Ref = &AccessGroup
	|	AND AccessGroupsUsers.User = &User";
	
	Return Not Query.Execute().IsEmpty();
	
EndFunction

&AtServer
Procedure FillRoles()
	
	Query = New Query;
	Query.SetParameter("User", Parameters.User);
	
	If TypeOf(Parameters.User) = Type("CatalogRef.Users")
	 Or TypeOf(Parameters.User) = Type("CatalogRef.ExternalUsers") Then
		
		Query.Text =
		"SELECT DISTINCT 
		|	Roles.Role.Name AS Role
		|FROM
		|	Catalog.AccessGroupProfiles.Roles AS Roles
		|		INNER JOIN Catalog.AccessGroups.Users AS AccessGroupsUsers
		|			INNER JOIN InformationRegister.UserGroupContents AS UserGroupContents
		|			ON (UserGroupContents.User = &User)
		|				AND (UserGroupContents.UserGroup = AccessGroupsUsers.User)
		|				AND (Not AccessGroupsUsers.Ref.DeletionMark)
		|		ON Roles.Ref = AccessGroupsUsers.Ref.Profile
		|			AND (Not Roles.Ref.DeletionMark)";
	Else
		// User group or External user group.
		Query.Text =
		"SELECT DISTINCT
		|	Roles.Role.Name AS Role
		|FROM
		|	Catalog.AccessGroupProfiles.Roles AS Roles
		|		INNER JOIN Catalog.AccessGroups.Users AS AccessGroupsUsers
		|		ON (AccessGroupsUsers.User = &User)
		|			AND (Not AccessGroupsUsers.Ref.DeletionMark)
		|			AND Roles.Ref = AccessGroupsUsers.Ref.Profile
		|			AND (Not Roles.Ref.DeletionMark)";
	EndIf;
	ValueToFormAttribute(Query.Execute().Unload(), "ReadRoles");
	
	Filter = New Structure("Role", "FullAccess");
	If ReadRoles.FindRows(Filter).Count() > 0 Then
		
		Filter = New Structure("Role", "FullAdministrator");
		If ReadRoles.FindRows(Filter).Count() > 0 Then
			
			ReadRoles.Clear();
			ReadRoles.Add().Role = "FullAccess";
			ReadRoles.Add().Role = "FullAdministrator";
		Else
			ReadRoles.Clear();
			ReadRoles.Add().Role = "FullAccess";
		EndIf;
	EndIf;
	
	ProcessRolesInterface("RefreshRoleTree");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Role interface procedures and functions

&AtServer
Procedure ProcessRolesInterface(Action, MainParameter = Undefined)
	
	ActionParameters = New Structure;
	ActionParameters.Insert("MainParameter", MainParameter);
	ActionParameters.Insert("Form",            ThisObject);
	ActionParameters.Insert("RoleCollection",   ReadRoles);
	
	UserType = ?(CommonUseCached.DataSeparationEnabled(), 
		Enums.UserTypes.DataAreaUser, 
		Enums.UserTypes.LocalApplicationUser);
	ActionParameters.Insert("UserType", UserType);
	
	UsersInternal.ProcessRolesInterface(Action, ActionParameters);
	
EndProcedure

#EndRegion
