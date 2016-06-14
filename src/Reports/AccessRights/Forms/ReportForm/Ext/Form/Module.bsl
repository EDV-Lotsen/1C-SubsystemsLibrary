
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("Autotest") Then // Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
		Return;
	EndIf;
	
	If Not ValueIsFilled(Parameters.User) Then
		If AccessManagementInternal.SimplifiedAccessRightSetupInterface() Then
			Raise
				NStr("en = 'To view the report, open the user card,
				           |click the Access rights hyperlink and then click Access rights report.'");
		Else
			Raise
				NStr("en = 'To view the report, open the user (user group) card,
				           |click the Access right hyperlink and then click Access rights report.'");
		EndIf;
	EndIf;
	
	If Parameters.User <> Users.AuthorizedUser()
	   And Not Users.InfobaseUserWithFullAccess() Then
		
		Raise NStr("en = 'Insufficient rights to view a report.'");
	EndIf;
	
	Items.AccessRightsDetails.Visible =
		Not AccessManagementInternal.SimplifiedAccessRightSetupInterface();
	
	OutputReport(Parameters.User);
	
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure DocumentDetailProcessing(Item, Details, StandardProcessing)
	
	If TypeOf(Details) = Type("String")
	   And Left(Details, StrLen("OpenListForm: ")) = "OpenListForm: " Then
		
		StandardProcessing = False;
		OpenForm(Mid(Details, StrLen("OpenListForm: ") + 1) + ".ListForm");
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Generate(Command)
	
	OutputReport(Parameters.User);
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure OutputReport(Ref)
	
	OutputGroupRights = TypeOf(Parameters.User) = Type("CatalogRef.UserGroups")
	              Or TypeOf(Parameters.User) = Type("CatalogRef.ExternalUserGroups");
	
	SimplifiedInterface = AccessManagementInternal.SimplifiedAccessRightSetupInterface();
	
	Document = New SpreadsheetDocument;
	
	Template = FormAttributeToValue("Report").GetTemplate("Template");
	IndentArea = Template.GetArea("Indent");
	Properties = New Structure;
	Properties.Insert("Ref", Ref);
	
	If TypeOf(Ref) = Type("CatalogRef.Users") Then
		Properties.Insert("ReportHeader",              NStr("en = 'User rights report'"));
		Properties.Insert("RolesByProfilesGrouping",   NStr("en = 'User roles by profile'"));
		Properties.Insert("ObjectPresentation",        NStr("en = 'User: %1'"));
		
	ElsIf TypeOf(Ref) = Type("CatalogRef.ExternalUsers") Then
		Properties.Insert("ReportHeader",              NStr("en = 'External user rights report'"));
		Properties.Insert("RolesByProfilesGrouping",   NStr("en = 'External user roles by profile'"));
		Properties.Insert("ObjectPresentation",        NStr("en = 'External user: %1'"));
		
	ElsIf TypeOf(Ref) = Type("CatalogRef.UserGroups") Then
		Properties.Insert("ReportHeader",              NStr("en = 'User group rights report'"));
		Properties.Insert("RolesByProfilesGrouping",   NStr("en = 'User group roles by profile'"));
		Properties.Insert("ObjectPresentation",        NStr("en = 'User group: %1'"));
	Else
		Properties.Insert("ReportHeader",              NStr("en = 'External user group rights report'"));
		Properties.Insert("RolesByProfilesGrouping",   NStr("en = 'External user group roles by profile'"));
		Properties.Insert("ObjectPresentation",        NStr("en = 'External user group: %1'"));
	EndIf;
	
	Properties.ObjectPresentation = StringFunctionsClientServer.SubstituteParametersInString(
		Properties.ObjectPresentation, String(Ref));
	
	// Displaying title
	Region = Template.GetArea("Title");
	Region.Parameters.Fill(Properties);
	Document.Put(Region);
	
	// Displaying the infobase user properties for user and external user
	If Not OutputGroupRights Then
		
		Document.StartRowAutoGrouping();
		Document.Put(Template.GetArea("InfobaseUserPropertiesGrouping"), 1,, True);
		Region = Template.GetArea("InfobaseUserPropertiesDetails1");
		
		InfobaseUserProperties = Undefined;
		
		SetPrivilegedMode(True);
		
		IBUserRead = Users.ReadInfobaseUser(
			CommonUse.ObjectAttributeValue(Ref, "InfobaseUserID"),
			InfobaseUserProperties);
		
		SetPrivilegedMode(False);
		
		If IBUserRead Then
			Region.Parameters.CanLogOnToApplication = Users.CanLogOnToApplication(
				InfobaseUserProperties);
			
			Document.Put(Region, 2);
			
			Region = Template.GetArea("InfobaseUserPropertiesDetails2");
			Region.Parameters.Fill(InfobaseUserProperties);
			
			Region.Parameters.PresentationLanguage =
				LanguagePresentation(InfobaseUserProperties.Language);
			
			Region.Parameters.RunModePresentation =
				RunModePresentation(InfobaseUserProperties.RunMode);
			
			If Not ValueIsFilled(InfobaseUserProperties.OSUser) Then
				Region.Parameters.OSUser = NStr("en = 'Not specified'");
			EndIf;
			Document.Put(Region, 2);
		Else
			Region.Parameters.CanLogOnToApplication = False;
			Document.Put(Region, 2);
		EndIf;
		Document.EndRowAutoGrouping();
	EndIf;
	
	If TypeOf(Ref) = Type("CatalogRef.Users")
		Or TypeOf(Ref) = Type("CatalogRef.ExternalUsers") Then
		
		SetPrivilegedMode(True);
		IBUser = InfobaseUsers.FindByUUID(
			CommonUse.ObjectAttributeValue(Ref, "InfobaseUserID"));
		SetPrivilegedMode(False);
		
		If Users.InfobaseUserWithFullAccess(IBUser, True) Then
			
			Region = Template.GetArea("FullUser");
			Document.Put(Region, 1);
			Return;
		EndIf;
	EndIf;
	
	// Displaying access groups
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.SetParameter("User",                   Ref);
	Query.SetParameter("OutputGroupRights",      OutputGroupRights);
	Query.SetParameter("AccessRestrictionKinds", RightRestrictionKindsOfMetadataObjects());
	
	Query.SetParameter("RightsSettingsOwnerTypes", AccessManagementInternalCached.Parameters(
		).AvailableRightsForObjectRightsSettings.OwnerTypes);
	
	Query.Text =
	"SELECT DISTINCT
	|	AccessGroups.Ref AS AccessGroup,
	|	AccessGroups.Profile,
	|	AccessGroupsUsers.User,
	|	CASE
	|		WHEN VALUETYPE(AccessGroupsUsers.User) <> TYPE(Catalog.Users)
	|				AND VALUETYPE(AccessGroupsUsers.User) <> TYPE(Catalog.ExternalUsers)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS GroupParticipation
	|INTO UserAccessGroups
	|FROM
	|	Catalog.AccessGroups AS AccessGroups
	|		INNER JOIN Catalog.AccessGroups.Users AS AccessGroupsUsers
	|		ON AccessGroups.Ref = AccessGroupsUsers.Ref
	|			AND (NOT AccessGroups.DeletionMark)
	|			AND (NOT AccessGroups.Profile.DeletionMark)
	|			AND (CASE
	|				WHEN &OutputGroupRights
	|					THEN AccessGroupsUsers.User = &User
	|				ELSE TRUE IN
	|						(SELECT TOP 1
	|							TRUE
	|						FROM
	|							InformationRegister.UserGroupContents AS UserGroupContents
	|						WHERE
	|							UserGroupContents.UserGroup = AccessGroupsUsers.User
	|							AND UserGroupContents.User = &User)
	|			END)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	UserAccessGroups.AccessGroup AS AccessGroup,
	|	PRESENTATION(UserAccessGroups.AccessGroup) AS PresentationAccessGroups,
	|	UserAccessGroups.User AS Party,
	|	UserAccessGroups.User.Description AS PartyPresentation,
	|	UserAccessGroups.GroupParticipation,
	|	UserAccessGroups.AccessGroup.Responsible AS Responsible,
	|	UserAccessGroups.AccessGroup.Responsible.Description AS PresentationOfResponsible,
	|	UserAccessGroups.AccessGroup.Description AS Description,
	|	UserAccessGroups.AccessGroup.Profile AS Profile,
	|	PRESENTATION(UserAccessGroups.AccessGroup.Profile) AS ProfilePresentation
	|FROM
	|	UserAccessGroups AS UserAccessGroups
	|TOTALS
	|	MAX(Party)
	|BY
	|	AccessGroup
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	UserAccessGroups.Profile
	|INTO UserProfiles
	|FROM
	|	UserAccessGroups AS UserAccessGroups
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	UserProfiles.Profile AS Profile,
	|	PRESENTATION(UserProfiles.Profile) AS ProfilePresentation,
	|	ProfileRoles.Role.Name AS Role,
	|	ProfileRoles.Role.Synonym AS PresentationRoles
	|FROM
	|	UserProfiles AS UserProfiles
	|		INNER JOIN Catalog.AccessGroupProfiles.Roles AS ProfileRoles
	|		ON UserProfiles.Profile = ProfileRoles.Ref
	|TOTALS
	|	MAX(Profile),
	|	MAX(ProfilePresentation),
	|	MAX(Role),
	|	MAX(PresentationRoles)
	|BY
	|	Profile,
	|	Role
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	VALUETYPE(ObjectRightsSettings.Object) AS ObjectsType,
	|	ObjectRightsSettings.Object AS Object,
	|	ISNULL(SettingsInheritance.Inherit, TRUE) AS Inherit,
	|	CASE
	|		WHEN VALUETYPE(ObjectRightsSettings.User) <> TYPE(Catalog.Users)
	|				AND VALUETYPE(ObjectRightsSettings.User) <> TYPE(Catalog.ExternalUsers)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS GroupParticipation,
	|	ObjectRightsSettings.User AS User,
	|	ObjectRightsSettings.User.Description AS UserDescription,
	|	ObjectRightsSettings.Right,
	|	ObjectRightsSettings.RightIsProhibited AS RightIsProhibited,
	|	ObjectRightsSettings.InheritanceIsAllowed AS InheritanceIsAllowed
	|FROM
	|	InformationRegister.ObjectRightsSettings AS ObjectRightsSettings
	|		LEFT JOIN InformationRegister.ObjectRightsSettingsInheritance AS SettingsInheritance
	|		ON (SettingsInheritance.Object = ObjectRightsSettings.Object)
	|			AND (SettingsInheritance.Parent = ObjectRightsSettings.Object)
	|WHERE
	|	CASE
	|			WHEN &OutputGroupRights
	|				THEN ObjectRightsSettings.User = &User
	|			ELSE TRUE IN
	|					(SELECT TOP 1
	|						TRUE
	|					FROM
	|						InformationRegister.UserGroupContents AS UserGroupContents
	|					WHERE
	|						UserGroupContents.UserGroup = ObjectRightsSettings.User
	|						AND UserGroupContents.User = &User)
	|		END
	|
	|UNION ALL
	|
	|SELECT
	|	VALUETYPE(SettingsInheritance.Object),
	|	SettingsInheritance.Object,
	|	SettingsInheritance.Inherit,
	|	FALSE,
	|	UNDEFINED,
	|	"""",
	|	"""",
	|	UNDEFINED,
	|	UNDEFINED
	|FROM
	|	InformationRegister.ObjectRightsSettingsInheritance AS SettingsInheritance
	|		LEFT JOIN InformationRegister.ObjectRightsSettings AS ObjectRightsSettings
	|		ON (ObjectRightsSettings.Object = SettingsInheritance.Object)
	|			AND (ObjectRightsSettings.Object = SettingsInheritance.Parent)
	|WHERE
	|	SettingsInheritance.Object = SettingsInheritance.Parent
	|	AND SettingsInheritance.Inherit = FALSE
	|	AND ObjectRightsSettings.Object IS NULL 
	|TOTALS
	|	MAX(Inherit),
	|	MAX(GroupParticipation),
	|	MAX(User),
	|	MAX(UserDescription),
	|	MAX(InheritanceIsAllowed)
	|BY
	|	ObjectsType,
	|	Object,
	|	User
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccessRestrictionKinds.Table,
	|	AccessRestrictionKinds.Right,
	|	AccessRestrictionKinds.AccessKind,
	|	AccessRestrictionKinds.Presentation AS AccessKindPresentation
	|INTO AccessRestrictionKinds
	|FROM
	|	&AccessRestrictionKinds AS AccessRestrictionKinds
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	UserAccessGroups.Profile AS Profile,
	|	UserAccessGroups.AccessGroup AS AccessGroup,
	|	ISNULL(AccessGroupsAccessKinds.AccessKind, UNDEFINED) AS AccessKind,
	|	ISNULL(AccessGroupsAccessKinds.AllAllowed, FALSE) AS AllAllowed,
	|	ISNULL(AccessGroupsAccessValues.AccessValue, UNDEFINED) AS AccessValue
	|INTO AccessKindsAndValues
	|FROM
	|	UserAccessGroups AS UserAccessGroups
	|		LEFT JOIN Catalog.AccessGroups.AccessKinds AS AccessGroupsAccessKinds
	|		ON (AccessGroupsAccessKinds.Ref = UserAccessGroups.AccessGroup)
	|		LEFT JOIN Catalog.AccessGroups.AccessValues AS AccessGroupsAccessValues
	|		ON (AccessGroupsAccessValues.Ref = AccessGroupsAccessKinds.Ref)
	|			AND (AccessGroupsAccessValues.AccessKind = AccessGroupsAccessKinds.AccessKind)
	|
	|UNION
	|
	|SELECT
	|	UserAccessGroups.Profile,
	|	UserAccessGroups.AccessGroup,
	|	AccessGroupProfilesAccessKinds.AccessKind,
	|	AccessGroupProfilesAccessKinds.AllAllowed,
	|	ISNULL(AccessGroupProfilesAccessValues.AccessValue, UNDEFINED)
	|FROM
	|	UserAccessGroups AS UserAccessGroups
	|		INNER JOIN Catalog.AccessGroupProfiles.AccessKinds AS AccessGroupProfilesAccessKinds
	|		ON (AccessGroupProfilesAccessKinds.Ref = UserAccessGroups.Profile)
	|		LEFT JOIN Catalog.AccessGroupProfiles.AccessValues AS AccessGroupProfilesAccessValues
	|		ON (AccessGroupProfilesAccessValues.Ref = AccessGroupProfilesAccessKinds.Ref)
	|			AND (AccessGroupProfilesAccessValues.AccessKind = AccessGroupProfilesAccessKinds.AccessKind)
	|WHERE
	|	AccessGroupProfilesAccessKinds.Preset
	|
	|UNION
	|
	|SELECT
	|	UserAccessGroups.Profile,
	|	UserAccessGroups.AccessGroup,
	|	AccessKindsRightsSettings.EmptyRefValue,
	|	FALSE,
	|	UNDEFINED
	|FROM
	|	UserAccessGroups AS UserAccessGroups
	|		INNER JOIN Catalog.MetadataObjectIDs AS AccessKindsRightsSettings
	|		ON (AccessKindsRightsSettings.EmptyRefValue IN (&RightsSettingsOwnerTypes))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProfileRolesRights.Table.Parent.Name AS ObjectKind,
	|	ProfileRolesRights.Table.Parent.Synonym AS ObjectsKindPresentation,
	|	ProfileRolesRights.Table.Parent.CollectionOrder AS ObjectKindOrder,
	|	ProfileRolesRights.Table.FullName AS Table,
	|	ProfileRolesRights.Table.Name AS Object,
	|	ProfileRolesRights.Table.Synonym AS ObjectPresentation,
	|	ProfileRolesRights.Profile AS Profile,
	|	ProfileRolesRights.Profile.Description AS ProfilePresentation,
	|	ProfileRolesRights.Role.Name AS Role,
	|	ProfileRolesRights.Role.Synonym AS PresentationRoles,
	|	ProfileRolesRights.RoleKind AS RoleKind,
	|	ProfileRolesRights.ReadWithoutRestriction AS ReadWithoutRestriction,
	|	ProfileRolesRights.View AS View,
	|	ProfileRolesRights.AccessGroup AS AccessGroup,
	|	ProfileRolesRights.AccessGroup.Description AS PresentationAccessGroups,
	|	ProfileRolesRights.AccessKind AS AccessKind,
	|	ProfileRolesRights.AccessKindPresentation AS AccessKindPresentation,
	|	ProfileRolesRights.AllAllowed AS AllAllowed,
	|	ProfileRolesRights.AccessValue AS AccessValue,
	|	PRESENTATION(ProfileRolesRights.AccessValue) AS AccessValuePresentation
	|FROM
	|	(SELECT
	|		RoleRights.MetadataObject AS Table,
	|		ProfileRoles.Ref AS Profile,
	|		CASE
	|			WHEN RoleRights.View
	|					AND RoleRights.ReadWithoutRestriction
	|				THEN 0
	|			WHEN NOT RoleRights.View
	|					AND RoleRights.ReadWithoutRestriction
	|				THEN 1
	|			WHEN RoleRights.View
	|					AND NOT RoleRights.ReadWithoutRestriction
	|				THEN 2
	|			ELSE 3
	|		END AS RoleKind,
	|		RoleRights.Role AS Role,
	|		RoleRights.ReadWithoutRestriction AS ReadWithoutRestriction,
	|		RoleRights.View AS View,
	|		UNDEFINED AS AccessGroup,
	|		UNDEFINED AS AccessKind,
	|		"""" AS AccessKindPresentation,
	|		UNDEFINED AS AllAllowed,
	|		UNDEFINED AS AccessValue
	|	FROM
	|		InformationRegister.RoleRights AS RoleRights
	|			INNER JOIN Catalog.AccessGroupProfiles.Roles AS ProfileRoles
	|				INNER JOIN UserProfiles AS UserProfiles
	|				ON ProfileRoles.Ref = UserProfiles.Profile
	|			ON RoleRights.Role = ProfileRoles.Role
	|	
	|	UNION
	|	
	|	SELECT
	|		RoleRights.MetadataObject,
	|		UserProfiles.Profile,
	|		1000,
	|		"""",
	|		FALSE,
	|		FALSE,
	|		AccessKindsAndValues.AccessGroup,
	|		ISNULL(AccessRestrictionKinds.AccessKind, UNDEFINED),
	|		ISNULL(AccessRestrictionKinds.AccessKindPresentation, """"),
	|		AccessKindsAndValues.AllAllowed,
	|		AccessKindsAndValues.AccessValue
	|	FROM
	|		InformationRegister.RoleRights AS RoleRights
	|			INNER JOIN Catalog.AccessGroupProfiles.Roles AS ProfileRoles
	|				INNER JOIN UserProfiles AS UserProfiles
	|				ON ProfileRoles.Ref = UserProfiles.Profile
	|			ON RoleRights.Role = ProfileRoles.Role
	|			INNER JOIN AccessKindsAndValues AS AccessKindsAndValues
	|			ON (UserProfiles.Profile = AccessKindsAndValues.Profile)
	|			LEFT JOIN AccessRestrictionKinds AS AccessRestrictionKinds
	|			ON (AccessRestrictionKinds.Table = RoleRights.MetadataObject)
	|				AND (AccessRestrictionKinds.Right = ""Read"")
	|				AND (AccessRestrictionKinds.AccessKind = AccessKindsAndValues.AccessKind)) AS ProfileRolesRights
	|TOTALS
	|	MAX(ObjectsKindPresentation),
	|	MAX(ObjectKindOrder),
	|	MAX(Table),
	|	MAX(ObjectPresentation),
	|	MAX(ProfilePresentation),
	|	MAX(PresentationRoles),
	|	MAX(ReadWithoutRestriction),
	|	MAX(View),
	|	MAX(PresentationAccessGroups),
	|	MAX(AccessKindPresentation),
	|	MAX(AllAllowed)
	|BY
	|	ObjectKind,
	|	Object,
	|	Profile,
	|	RoleKind,
	|	Role,
	|	AccessGroup,
	|	AccessKind
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProfileRolesRights.Table.Parent.Name AS ObjectKind,
	|	ProfileRolesRights.Table.Parent.Synonym AS ObjectsKindPresentation,
	|	ProfileRolesRights.Table.Parent.CollectionOrder AS ObjectKindOrder,
	|	ProfileRolesRights.Table.FullName AS Table,
	|	ProfileRolesRights.Table.Name AS Object,
	|	ProfileRolesRights.Table.Synonym AS ObjectPresentation,
	|	ProfileRolesRights.Profile AS Profile,
	|	ProfileRolesRights.Profile.Description AS ProfilePresentation,
	|	ProfileRolesRights.Role.Name AS Role,
	|	ProfileRolesRights.Role.Synonym AS PresentationRoles,
	|	ProfileRolesRights.RoleKind AS RoleKind,
	|	ProfileRolesRights.Insert AS Insert,
	|	ProfileRolesRights.UpdateRight AS UpdateRight,
	|	ProfileRolesRights.InsertWithoutRestriction AS InsertWithoutRestriction,
	|	ProfileRolesRights.UpdateWithoutRestriction AS UpdateWithoutRestriction,
	|	ProfileRolesRights.InteractiveInsert AS InteractiveInsert,
	|	ProfileRolesRights.Edit AS Edit,
	|	ProfileRolesRights.AccessGroup AS AccessGroup,
	|	ProfileRolesRights.AccessGroup.Description AS PresentationAccessGroups,
	|	ProfileRolesRights.AccessKind AS AccessKind,
	|	ProfileRolesRights.AccessKindPresentation AS AccessKindPresentation,
	|	ProfileRolesRights.AllAllowed AS AllAllowed,
	|	ProfileRolesRights.AccessValue AS AccessValue,
	|	PRESENTATION(ProfileRolesRights.AccessValue) AS AccessValuePresentation
	|FROM
	|	(SELECT
	|		RoleRights.MetadataObject AS Table,
	|		ProfileRoles.Ref AS Profile,
	|		CASE
	|			WHEN RoleRights.InsertWithoutRestriction
	|					AND RoleRights.UpdateWithoutRestriction
	|				THEN 0
	|			WHEN NOT RoleRights.InsertWithoutRestriction
	|					AND RoleRights.UpdateWithoutRestriction
	|				THEN 100
	|			WHEN RoleRights.InsertWithoutRestriction
	|					AND NOT RoleRights.UpdateWithoutRestriction
	|				THEN 200
	|			ELSE 300
	|		END + CASE
	|			WHEN RoleRights.Insert
	|					AND RoleRights.Update
	|				THEN 0
	|			WHEN NOT RoleRights.Insert
	|					AND RoleRights.Update
	|				THEN 10
	|			WHEN RoleRights.Insert
	|					AND NOT RoleRights.Update
	|				THEN 20
	|			ELSE 30
	|		END + CASE
	|			WHEN RoleRights.InteractiveInsert
	|					AND RoleRights.Edit
	|				THEN 0
	|			WHEN NOT RoleRights.InteractiveInsert
	|					AND RoleRights.Edit
	|				THEN 1
	|			WHEN RoleRights.InteractiveInsert
	|					AND NOT RoleRights.Edit
	|				THEN 2
	|			ELSE 3
	|		END AS RoleKind,
	|		RoleRights.Role AS Role,
	|		RoleRights.Insert AS Insert,
	|		RoleRights.Update AS UpdateRight,
	|		RoleRights.InsertWithoutRestriction AS InsertWithoutRestriction,
	|		RoleRights.UpdateWithoutRestriction AS UpdateWithoutRestriction,
	|		RoleRights.InteractiveInsert AS InteractiveInsert,
	|		RoleRights.Edit AS Edit,
	|		UNDEFINED AS AccessGroup,
	|		UNDEFINED AS AccessKind,
	|		"""" AS AccessKindPresentation,
	|		UNDEFINED AS AllAllowed,
	|		UNDEFINED AS AccessValue
	|	FROM
	|		InformationRegister.RoleRights AS RoleRights
	|			INNER JOIN Catalog.AccessGroupProfiles.Roles AS ProfileRoles
	|				INNER JOIN UserProfiles AS UserProfiles
	|				ON ProfileRoles.Ref = UserProfiles.Profile
	|			ON RoleRights.Role = ProfileRoles.Role
	|				AND (RoleRights.Insert
	|					OR RoleRights.Update)
	|	
	|	UNION
	|	
	|	SELECT
	|		RoleRights.MetadataObject,
	|		UserProfiles.Profile,
	|		1000,
	|		"""",
	|		FALSE,
	|		FALSE,
	|		FALSE,
	|		FALSE,
	|		FALSE,
	|		FALSE,
	|		AccessKindsAndValues.AccessGroup,
	|		ISNULL(AccessRestrictionKinds.AccessKind, UNDEFINED),
	|		ISNULL(AccessRestrictionKinds.AccessKindPresentation, """"),
	|		AccessKindsAndValues.AllAllowed,
	|		AccessKindsAndValues.AccessValue
	|	FROM
	|		InformationRegister.RoleRights AS RoleRights
	|			INNER JOIN Catalog.AccessGroupProfiles.Roles AS ProfileRoles
	|				INNER JOIN UserProfiles AS UserProfiles
	|				ON ProfileRoles.Ref = UserProfiles.Profile
	|			ON RoleRights.Role = ProfileRoles.Role
	|				AND (RoleRights.Insert)
	|			INNER JOIN AccessKindsAndValues AS AccessKindsAndValues
	|			ON (UserProfiles.Profile = AccessKindsAndValues.Profile)
	|			LEFT JOIN AccessRestrictionKinds AS AccessRestrictionKinds
	|			ON (AccessRestrictionKinds.Table = RoleRights.MetadataObject)
	|				AND (AccessRestrictionKinds.Right = ""Insert"")
	|				AND (AccessRestrictionKinds.AccessKind = AccessKindsAndValues.AccessKind)
	|	
	|	UNION
	|	
	|	SELECT
	|		RoleRights.MetadataObject,
	|		UserProfiles.Profile,
	|		1000,
	|		"""",
	|		FALSE,
	|		FALSE,
	|		FALSE,
	|		FALSE,
	|		FALSE,
	|		FALSE,
	|		AccessKindsAndValues.AccessGroup,
	|		ISNULL(AccessRestrictionKinds.AccessKind, UNDEFINED),
	|		ISNULL(AccessRestrictionKinds.AccessKindPresentation, """"),
	|		AccessKindsAndValues.AllAllowed,
	|		AccessKindsAndValues.AccessValue
	|	FROM
	|		InformationRegister.RoleRights AS RoleRights
	|			INNER JOIN Catalog.AccessGroupProfiles.Roles AS ProfileRoles
	|				INNER JOIN UserProfiles AS UserProfiles
	|				ON ProfileRoles.Ref = UserProfiles.Profile
	|			ON RoleRights.Role = ProfileRoles.Role
	|				AND (RoleRights.Update)
	|			INNER JOIN AccessKindsAndValues AS AccessKindsAndValues
	|			ON (UserProfiles.Profile = AccessKindsAndValues.Profile)
	|			LEFT JOIN AccessRestrictionKinds AS AccessRestrictionKinds
	|			ON (AccessRestrictionKinds.Table = RoleRights.MetadataObject)
	|				AND (AccessRestrictionKinds.Right = ""Update"")
	|				AND (AccessRestrictionKinds.AccessKind = AccessKindsAndValues.AccessKind)) AS ProfileRolesRights
	|TOTALS
	|	MAX(ObjectsKindPresentation),
	|	MAX(ObjectKindOrder),
	|	MAX(Table),
	|	MAX(ObjectPresentation),
	|	MAX(ProfilePresentation),
	|	MAX(PresentationRoles),
	|	MAX(Insert),
	|	MAX(InsertWithoutRestriction),
	|	MAX(UpdateWithoutRestriction),
	|	MAX(InteractiveInsert),
	|	MAX(Edit),
	|	MAX(PresentationAccessGroups),
	|	MAX(AccessKindPresentation),
	|	MAX(AllAllowed)
	|BY
	|	ObjectKind,
	|	Object,
	|	Profile,
	|	RoleKind,
	|	Role,
	|	AccessGroup,
	|	AccessKind,
	|	UpdateRight
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccessKindsAndValues.Profile,
	|	AccessKindsAndValues.AccessGroup,
	|	AccessKindsAndValues.AccessKind,
	|	AccessKindsAndValues.AllAllowed,
	|	AccessKindsAndValues.AccessValue
	|FROM
	|	AccessKindsAndValues AS AccessKindsAndValues";
	QueryResults = Query.ExecuteBatch();
	
	Document.StartRowAutoGrouping();
	
	If AccessRightsDetails Then
		// Displaying access groups
		AccessGroupsDescriptions = QueryResults[1].Unload(
			QueryResultIteration.ByGroups).Rows;
		
		OnePersonalGroup
			= AccessGroupsDescriptions.Count() = 1
			And ValueIsFilled(AccessGroupsDescriptions[0].Party);
		
		Region = Template.GetArea("AllAccessGroupsGrouping");
		Region.Parameters.Fill(Properties);
		
		If OnePersonalGroup Then
			If TypeOf(Ref) = Type("CatalogRef.Users") Then
				AccessPresentation = NStr("en = 'User access restrictions'");
				
			ElsIf TypeOf(Ref) = Type("CatalogRef.ExternalUsers") Then
				AccessPresentation = NStr("en = 'External user access restrictions'");
				
			ElsIf TypeOf(Ref) = Type("CatalogRef.UserGroups") Then
				AccessPresentation = NStr("en = 'User group access restrictions'");
			Else
				AccessPresentation = NStr("en = 'External user group access restrictions'");
			EndIf;
		Else
			If TypeOf(Ref) = Type("CatalogRef.Users") Then
				AccessPresentation = NStr("en = 'User access groups'");
				
			ElsIf TypeOf(Ref) = Type("CatalogRef.ExternalUsers") Then
				AccessPresentation = NStr("en = 'External user access groups'");
				
			ElsIf TypeOf(Ref) = Type("CatalogRef.UserGroups") Then
				AccessPresentation = NStr("en = 'User group access groups'");
			Else
				AccessPresentation = NStr("en = 'External user group access groups'");
			EndIf;
		EndIf;
		
		Region.Parameters.AccessPresentation = AccessPresentation;
		
		Document.Put(Region, 1);
		Document.Put(IndentArea, 2);
		
		For Each AccessGroupDescription In AccessGroupsDescriptions Do
			If Not OnePersonalGroup Then
				Region = Template.GetArea("AccessGroupGrouping");
				Region.Parameters.Fill(AccessGroupDescription);
				Document.Put(Region, 2);
			EndIf;
			// Displaying group memberships
			If AccessGroupDescription.Rows.Count() = 1
			   And AccessGroupDescription.Rows[0].Party = Ref Then
				// User is included in the access group explicitly,
				// nothing to display
			Else
				Region = Template.GetArea("AccessGroupDetailsUserIsInGroup");
				Document.Put(Region, 3);
				If AccessGroupDescription.Rows.Find(Ref, "Party") <> Undefined Then
					Region = Template.GetArea("AccessGroupDetailsUserIsInGroupClearly");
					Document.Put(Region, 3);
				EndIf;
				Filter = New Structure("GroupParticipation", True);
				UserGroupsDescriptions = AccessGroupDescription.Rows.FindRows(Filter);
				If UserGroupsDescriptions.Count() > 0 Then
					
					Region = Template.GetArea(
						"AccessGroupDetailsUserIsInGroupAsUserGroupParty");
					
					Document.Put(Region, 3);
					For Each UserGroupDescription In UserGroupsDescriptions Do
						
						Region = Template.GetArea(
							"AccessGroupDetailsUserIsInGroupAsPartyPresentation");
						
						Region.Parameters.Fill(UserGroupDescription);
						Document.Put(Region, 3);
					EndDo;
				EndIf;
			EndIf;
			
			If Not OnePersonalGroup Then
				// Displaying profiles
				Region = Template.GetArea("AccessGroupDetailsProfile");
				Region.Parameters.Fill(AccessGroupDescription);
				Document.Put(Region, 3);
			EndIf;
			
			// Displaying the user responsible for the group participant content
			If Not OnePersonalGroup And ValueIsFilled(AccessGroupDescription.Responsible) Then
				Region = Template.GetArea("AccessGroupDetailsResponsible");
				Region.Parameters.Fill(AccessGroupDescription);
				Document.Put(Region, 3);
			EndIf;
			
			// Displaying description
			If Not OnePersonalGroup And ValueIsFilled(AccessGroupDescription.Description) Then
				Region = Template.GetArea("AccessGroupDetailsDescription");
				Region.Parameters.Fill(AccessGroupDescription);
				Document.Put(Region, 3);
			EndIf;
			
			Document.Put(IndentArea, 3);
			Document.Put(IndentArea, 3);
		EndDo;
		
		// Displaying roles by profile
		RolesByProfiles = QueryResults[3].Unload(QueryResultIteration.ByGroups);
		RolesByProfiles.Rows.Sort("ProfilePresentation Asc, PresentationRoles Asc");
		
		If RolesByProfiles.Rows.Count() > 0 Then
			Region = Template.GetArea("RolesByProfilesGrouping");
			Region.Parameters.Fill(Properties);
			Document.Put(Region, 1);
			Document.Put(IndentArea, 2);
			
			For Each ProfileDescription In RolesByProfiles.Rows Do
				Region = Template.GetArea("RolesByProfilesProfilePresentation");
				Region.Parameters.Fill(ProfileDescription);
				Document.Put(Region, 2);
				For Each RoleDetails In ProfileDescription.Rows Do
					Region = Template.GetArea("RolesByProfilesRolePresentation");
					Region.Parameters.Fill(RoleDetails);
					Document.Put(Region, 3);
				EndDo;
			EndDo;
		EndIf;
		Document.Put(IndentArea, 2);
		Document.Put(IndentArea, 2);
	EndIf;
	
	// Displaying objects to be viewed
	RightsObjects = QueryResults[7].Unload(QueryResultIteration.ByGroups);
	
	RightsObjects.Rows.Sort(
		"ObjectKindOrder Asc,
		|ProfilePresentation Asc,
		|ObjectPresentation Asc,
		|RoleKind Asc,
		|PresentationAccessGroups Asc,
		|PresentationRoles Asc,
		|AccessKindPresentation Asc,
   |AccessValuePresentation Asc",
		True);
	
	Region = Template.GetArea("ObjectRightsGrouping");
	Region.Parameters.ObjectRightGroupingPresentation = NStr("en = 'View objects'");
	Document.Put(Region, 1);
	Region = Template.GetArea("ObjectViewLegend");
	Document.Put(Region, 2);
	
	RightsSettingsOwners = AccessManagementInternalCached.Parameters(
		).AvailableRightsForObjectRightsSettings.ByRefTypes;
	
	For Each ObjectKindDescription In RightsObjects.Rows Do
		Region = Template.GetArea("ObjectRightsTableTitle");
		If SimplifiedInterface Then
			Region.Parameters.PresentationProfilesORAccessGroups = NStr("en = 'Profiles'");
		Else
			Region.Parameters.PresentationProfilesORAccessGroups = NStr("en = 'Access groups'");
		EndIf;
		Region.Parameters.Fill(ObjectKindDescription);
		Document.Put(Region, 2);
		
		Region = Template.GetArea("ObjectRightsTableTitleAdditional");
		If AccessRightsDetails Then
			Region.Parameters.PresentationProfilesORAccessGroups = NStr("en = '(profile, roles)'");
		Else
			Region.Parameters.PresentationProfilesORAccessGroups = "";
		EndIf;
		Region.Parameters.Fill(ObjectKindDescription);
		Document.Put(Region, 3);
		
		For Each ObjectDescription In ObjectKindDescription.Rows Do
			ObjectAreaInitialString = Undefined;
			EndObjectAreaRow  = Undefined;
			Region = Template.GetArea("ObjectRightsTableString");
			
			Region.Parameters.OpenListForm = "OpenListForm: " + ObjectDescription.Table;
			
			If ObjectDescription.ReadWithoutRestriction Then
				If ObjectDescription.View Then
					ObjectPresentationAdjustment = NStr("en = '(view, not limited)'");
				Else
					ObjectPresentationAdjustment = NStr("en = '(view*, not limited)'");
				EndIf;
			Else
				If ObjectDescription.View Then
					ObjectPresentationAdjustment = NStr("en = '(view, limited)'");
				Else
					ObjectPresentationAdjustment = NStr("en = '(view*, limited)'");
				EndIf;
			EndIf;
			
			Region.Parameters.ObjectPresentation =
				ObjectDescription.ObjectPresentation + Chars.LF + ObjectPresentationAdjustment;
				
			For Each ProfileDescription In ObjectDescription.Rows Do
				ProfileRolesPresentation = "";
				RoleQuantity = 0;
				AllRolesWithRestriction = True;
				For Each RoleKindDescription In ProfileDescription.Rows Do
					If RoleKindDescription.RoleKind < 1000 Then
						// Role description, with or without restrictions
						For Each RoleDetails In RoleKindDescription.Rows Do
							
							If RoleKindDescription.ReadWithoutRestriction Then
								AllRolesWithRestriction = False;
							EndIf;
							
							If Not AccessRightsDetails Then
								Continue;
							EndIf;
							
							If RoleKindDescription.Rows.Count() > 1
							   And RoleKindDescription.Rows.IndexOf(RoleDetails)
							         < RoleKindDescription.Rows.Count()-1 Then
								
								ProfileRolesPresentation
									= ProfileRolesPresentation
									+ RoleDetails.PresentationRoles + ",";
								
								RoleQuantity = RoleQuantity + 1;
							EndIf;
							
							If RoleKindDescription.Rows.IndexOf(RoleDetails) =
							         RoleKindDescription.Rows.Count()-1 Then
								
								ProfileRolesPresentation
									= ProfileRolesPresentation
									+ RoleDetails.PresentationRoles
									+ ",";
								
								RoleQuantity = RoleQuantity + 1;
							EndIf;
							ProfileRolesPresentation = ProfileRolesPresentation + Chars.LF;
						EndDo;
					ElsIf RoleKindDescription.Rows[0].Rows.Count() > 0 Then
						// Description of access restrictions for roles with restrictions
						For Each AccessGroupDescription In RoleKindDescription.Rows[0].Rows Do
							Index = AccessGroupDescription.Rows.Count()-1;
							While Index >= 0 Do
								If AccessGroupDescription.Rows[Index].AccessKind = Undefined Then
									AccessGroupDescription.Rows.Delete(Index);
								EndIf;
								Index = Index - 1;
							EndDo;
							InitialAreaStringAccessGroups = Undefined;
							If Region = Undefined Then
								Region = Template.GetArea("ObjectRightsTableString");
							EndIf;
							If SimplifiedInterface Then
								Region.Parameters.ProfileOrAccessGroup = ProfileDescription.AccessGroup;
								
								Region.Parameters.ProfileORAccessGroupPresentation =
									ProfileDescription.PresentationAccessGroups;
							Else
								Region.Parameters.ProfileOrAccessGroup = AccessGroupDescription.AccessGroup;
								If AccessRightsDetails Then
									ProfileRolesPresentation = TrimAll(ProfileRolesPresentation);
									
									If ValueIsFilled(ProfileRolesPresentation)
									   And Right(ProfileRolesPresentation, 1) = "," Then
										
										ProfileRolesPresentation = Left(
											ProfileRolesPresentation,
											StrLen(ProfileRolesPresentation) - 1);
									EndIf;
									
									If RoleQuantity > 1 Then
										PresentationAdjustmentAccessGroups =
											NStr("en = '(profile:
											           |%1, roles: %2)'")
									Else
										PresentationAdjustmentAccessGroups =
											NStr("en = '(profile:
											           |%1, role: %2)'")
									EndIf;
									
									Region.Parameters.ProfileORAccessGroupPresentation =
										AccessGroupDescription.PresentationAccessGroups
										+ Chars.LF
										+ StringFunctionsClientServer.SubstituteParametersInString(
											PresentationAdjustmentAccessGroups,
											ProfileDescription.ProfilePresentation,
											TrimAll(ProfileRolesPresentation));
								Else
									Region.Parameters.ProfileORAccessGroupPresentation =
										AccessGroupDescription.PresentationAccessGroups;
								EndIf;
							EndIf;
							If AllRolesWithRestriction Then
								If GetFunctionalOption("UseRecordLevelSecurity") Then
									For Each AccessKindDescription In AccessGroupDescription.Rows Do
										Index = AccessKindDescription.Rows.Count()-1;
										While Index >= 0 Do
											If Not ValueIsFilled(AccessKindDescription.Rows[Index].AccessValue) Then
												AccessKindDescription.Rows.Delete(Index);
											EndIf;
											Index = Index - 1;
										EndDo;
										// Getting a new area if the access kind is not the first one
										If Region = Undefined Then
											Region = Template.GetArea("ObjectRightsTableString");
										EndIf;
										
										Region.Parameters.AccessKind = AccessKindDescription.AccessKind;
										
										Region.Parameters.AccessKindPresentation =
											StringFunctionsClientServer.SubstituteParametersInString(
												AccessKindPresentationTemplate(
													AccessKindDescription, RightsSettingsOwners),
												AccessKindDescription.AccessKindPresentation);
										
										PutArea(
											Document,
											Region,
											3,
											ObjectAreaInitialString,
											EndObjectAreaRow,
											InitialAreaStringAccessGroups);
										
										For Each AccessValueDetails In AccessKindDescription.Rows Do
											Region = Template.GetArea("ObjectRightsTableStringAccessValues");
											
											Region.Parameters.AccessValuePresentation =
												AccessValueDetails.AccessValuePresentation;
										
											Region.Parameters.AccessValue =
												AccessValueDetails.AccessValue;
											
											PutArea(
												Document,
												Region,
												3,
												ObjectAreaInitialString,
												EndObjectAreaRow,
												InitialAreaStringAccessGroups);
										EndDo;
									EndDo;
								EndIf;
							EndIf;
							If Region <> Undefined Then
								PutArea(
									Document,
									Region,
									3,
									ObjectAreaInitialString,
									EndObjectAreaRow,
									InitialAreaStringAccessGroups);
							EndIf;
							// Setting boundaries for access kinds for the current access group
							SetKindsAndAccessValuesBounds(
								Document,
								InitialAreaStringAccessGroups,
								EndObjectAreaRow);
							// Merging access group cells and setting boundaries
							MergeCellsSetBounds(
								Document,
								InitialAreaStringAccessGroups,
								EndObjectAreaRow,
								3);
						EndDo;
					EndIf;
				EndDo;
			EndDo;
			// Merging object cells and setting boundaries
			MergeCellsSetBounds(
				Document,
				ObjectAreaInitialString,
				EndObjectAreaRow,
				2);
		EndDo;
		Document.Put(IndentArea, 3);
		Document.Put(IndentArea, 3);
		Document.Put(IndentArea, 3);
		Document.Put(IndentArea, 3);
	EndDo;
	Document.Put(IndentArea, 2);
	Document.Put(IndentArea, 2);
	
	// Displaying objects to be edited
	RightsObjects = QueryResults[8].Unload(QueryResultIteration.ByGroups);
	RightsObjects.Rows.Sort(
		"ObjectKindOrder Asc,
		|ProfilePresentation Asc,
		|ObjectPresentation Asc,
   |RoleKind Asc,
		|PresentationAccessGroups Asc,
		|PresentationRoles Asc,
		|AccessKindPresentation Asc,
   |AccessValuePresentation Asc", 
		True);
	
	Region = Template.GetArea("ObjectRightsGrouping");
	Region.Parameters.ObjectRightGroupingPresentation = NStr("en = 'Object editing'");
	Document.Put(Region, 1);
	Region = Template.GetArea("ObjectsEditLegend");
	Document.Put(Region, 2);
	
	For Each ObjectKindDescription In RightsObjects.Rows Do
		Region = Template.GetArea("ObjectRightsTableTitle");
		If SimplifiedInterface Then
			Region.Parameters.PresentationProfilesORAccessGroups = NStr("en = 'Profiles'");
		Else
			Region.Parameters.PresentationProfilesORAccessGroups = NStr("en = 'Access groups'");
		EndIf;
		Region.Parameters.Fill(ObjectKindDescription);
		Document.Put(Region, 2);
		
		Region = Template.GetArea("ObjectRightsTableTitleAdditional");
		If AccessRightsDetails Then
			Region.Parameters.PresentationProfilesORAccessGroups = NStr("en = '(profile, roles)'");
		Else
			Region.Parameters.PresentationProfilesORAccessGroups = "";
		EndIf;
		Region.Parameters.Fill(ObjectKindDescription);
		Document.Put(Region, 3);

		InsertIsUsed =
			Upper(Left(ObjectKindDescription.ObjectKind, StrLen("Register"))) <> Upper("Register");
		
		For Each ObjectDescription In ObjectKindDescription.Rows Do
			ObjectAreaInitialString = Undefined;
			EndObjectAreaRow  = Undefined;
			Region = Template.GetArea("ObjectRightsTableString");
			
			Region.Parameters.OpenListForm = "OpenListForm: " + ObjectDescription.Table;
			
			If InsertIsUsed Then
				If ObjectDescription.Insert And ObjectDescription.Update Then
					If ObjectDescription.InsertWithoutRestriction And ObjectDescription.UpdateWithoutRestriction Then
						If ObjectDescription.InteractiveInsert And ObjectDescription.Edit Then
							ObjectPresentationAdjustment = NStr("en = '(add, not limited 
							                                           |change, not limited)'");
						ElsIf Not ObjectDescription.InteractiveInsert And ObjectDescription.Edit Then
							ObjectPresentationAdjustment = NStr("en = '(add*, not limited
							                                           |change, not limited)'");
						ElsIf ObjectDescription.InteractiveInsert And Not ObjectDescription.Edit Then
							ObjectPresentationAdjustment = NStr("en = '(add, not limited
							                                           |change*, not limited)'");
						Else // NOT ObjectDescription.InteractiveInsert AND NOT ObjectDescription.Edit
							ObjectPresentationAdjustment = NStr("en = '(add*, not limited
							                                           |change*, not limited)'");
						EndIf;
					ElsIf Not ObjectDescription.InsertWithoutRestriction And ObjectDescription.UpdateWithoutRestriction Then
						If ObjectDescription.InteractiveInsert And ObjectDescription.Edit Then
							ObjectPresentationAdjustment = NStr("en = '(add, limited
							                                           |change, not limited)'");
						ElsIf Not ObjectDescription.InteractiveInsert And ObjectDescription.Edit Then
							ObjectPresentationAdjustment = NStr("en = '(add*, limited
							                                           |change, not limited)'");
						ElsIf ObjectDescription.InteractiveInsert And Not ObjectDescription.Edit Then
							ObjectPresentationAdjustment = NStr("en = '(add, limited
							                                           |change*, not limited)'");
						Else // NOT ObjectDescription.InteractiveInsert AND NOT ObjectDescription.Edit
							ObjectPresentationAdjustment = NStr("en = '(add*, limited
							                                           |change*, not limited)'");
						EndIf;
					ElsIf ObjectDescription.InsertWithoutRestriction And Not ObjectDescription.UpdateWithoutRestriction Then
						If ObjectDescription.InteractiveInsert And ObjectDescription.Edit Then
							ObjectPresentationAdjustment = NStr("en = '(add, not limited
							                                           |change, limited)'");
						ElsIf Not ObjectDescription.InteractiveInsert And ObjectDescription.Edit Then
							ObjectPresentationAdjustment = NStr("en = '(add*, not limited
							                                           |change, limited)'");
						ElsIf ObjectDescription.InteractiveInsert And Not ObjectDescription.Edit Then
							ObjectPresentationAdjustment = NStr("en = '(add, not limited
							                                           |change*, limited)'");
						Else // NOT ObjectDescription.InteractiveInsert AND NOT ObjectDescription.Edit
							ObjectPresentationAdjustment = NStr("en = '(add*, not limited
							                                           |change*, limited)'");
						EndIf;
					Else // NOT ObjectDescription.InsertWithoutRestriction AND NOT ObjectDescription.UpdateWithoutRestriction
						If ObjectDescription.InteractiveInsert And ObjectDescription.Edit Then
							ObjectPresentationAdjustment = NStr("en = '(add, limited change, limited)'");
						ElsIf Not ObjectDescription.InteractiveInsert And ObjectDescription.Edit Then
							ObjectPresentationAdjustment = NStr("en = '(add*, limited 
							                                           |change, limited)'");
						ElsIf ObjectDescription.InteractiveInsert And Not ObjectDescription.Edit Then
							ObjectPresentationAdjustment = NStr("en = '(add, limited
							                                           |change*, limited)'");
						Else // NOT ObjectDescription.InteractiveInsert AND NOT ObjectDescription.Edit
							ObjectPresentationAdjustment = NStr("en = '(add*, limited
                                                      |change*, limited)'");
						EndIf;
					EndIf;
					
				ElsIf Not ObjectDescription.Insert And ObjectDescription.Update Then
					
					If ObjectDescription.UpdateWithoutRestriction Then
						If ObjectDescription.Edit Then
							ObjectPresentationAdjustment = NStr("en = '(add not available
							                                           |change, not limited)'");
						Else // NOT ObjectDescription.Edit
							ObjectPresentationAdjustment = NStr("en = '(add not available
							                                           |change*, not limited)'");
						EndIf;
					Else // NOT ObjectDescription.UpdateWithoutRestriction
						If ObjectDescription.Edit Then
							ObjectPresentationAdjustment = NStr("en = '(add not available
							                                           |change, limited)'");
						Else // NOT ObjectDescription.Edit
							ObjectPresentationAdjustment = NStr("en = '(add not available
							                                           |change*, limited)'");
						EndIf;
					EndIf;
					
				Else // NOT ObjectDescription.Insert AND NOT ObjectDescription.Change
					ObjectPresentationAdjustment = NStr("en = '(add not available
					                                           |change not available)'");
				EndIf;
			Else
				If ObjectDescription.Update Then
					If ObjectDescription.UpdateWithoutRestriction Then
						If ObjectDescription.Edit Then
							ObjectPresentationAdjustment = NStr("en = '(change, not limited)'");
						Else // NOT ObjectDescription.Edit
							ObjectPresentationAdjustment = NStr("en = '(change*, not limited)'");
						EndIf;
					Else
						If ObjectDescription.Edit Then
							ObjectPresentationAdjustment = NStr("en = '(change, limited)'");
						Else // NOT ObjectDescription.Edit
							ObjectPresentationAdjustment = NStr("en = '(change*, limited)'");
						EndIf;
					EndIf;
				Else // NOT ObjectDescription.Change
					ObjectPresentationAdjustment = NStr("en = '(change not available)'");
				EndIf;
			EndIf;
			
			Region.Parameters.ObjectPresentation =
				ObjectDescription.ObjectPresentation + Chars.LF + ObjectPresentationAdjustment;
				
			For Each ProfileDescription In ObjectDescription.Rows Do
				ProfileRolesPresentation = "";
				RoleQuantity = 0;
				AllRolesWithRestriction = True;
				For Each RoleKindDescription In ProfileDescription.Rows Do
					If RoleKindDescription.RoleKind < 1000 Then
						// Description of role with or without restrictions
						For Each RoleDetails In RoleKindDescription.Rows Do
							
							If RoleKindDescription.InsertWithoutRestriction
							   And RoleKindDescription.UpdateWithoutRestriction Then
								
								AllRolesWithRestriction = False;
							EndIf;
							
							If Not AccessRightsDetails Then
								Continue;
							EndIf;
							
							If RoleKindDescription.Rows.Count() > 1
							   And RoleKindDescription.Rows.IndexOf(RoleDetails)
							         < RoleKindDescription.Rows.Count()-1 Then
								
								ProfileRolesPresentation =
									ProfileRolesPresentation + RoleDetails.PresentationRoles + ",";
								
								RoleQuantity = RoleQuantity + 1;
							EndIf;
							
							If RoleKindDescription.Rows.IndexOf(RoleDetails) =
							         RoleKindDescription.Rows.Count()-1 Then
								
								ProfileRolesPresentation =
									ProfileRolesPresentation + RoleDetails.PresentationRoles + ",";
								
								RoleQuantity = RoleQuantity + 1;
							EndIf;
							ProfileRolesPresentation = ProfileRolesPresentation + Chars.LF;
						EndDo;
					ElsIf RoleKindDescription.Rows[0].Rows.Count() > 0 Then
						// Description of access restrictions for roles with restrictions
						For Each AccessGroupDescription In RoleKindDescription.Rows[0].Rows Do
							Index = AccessGroupDescription.Rows.Count()-1;
							While Index >= 0 Do
								If AccessGroupDescription.Rows[Index].AccessKind = Undefined Then
									AccessGroupDescription.Rows.Delete(Index);
								EndIf;
								Index = Index - 1;
							EndDo;
							InitialAreaStringAccessGroups = Undefined;
							If Region = Undefined Then
								Region = Template.GetArea("ObjectRightsTableString");
							EndIf;
							If SimplifiedInterface Then
								Region.Parameters.ProfileOrAccessGroup = ProfileDescription.AccessGroup;
								Region.Parameters.ProfileORAccessGroupPresentation = ProfileDescription.PresentationAccessGroups;
							Else
								Region.Parameters.ProfileOrAccessGroup = AccessGroupDescription.AccessGroup;
								If AccessRightsDetails Then
									ProfileRolesPresentation = TrimAll(ProfileRolesPresentation);
									
									If ValueIsFilled(ProfileRolesPresentation)
									   And Right(ProfileRolesPresentation, 1) = "," Then
										
										ProfileRolesPresentation = Left(
											ProfileRolesPresentation,
											StrLen(ProfileRolesPresentation)-1);
									EndIf;
									If RoleQuantity > 1 Then
										PresentationAdjustmentAccessGroups =
											NStr("en = '(profile:
											           |%1, roles: %2)'")
									Else
										PresentationAdjustmentAccessGroups =
											NStr("en = '(profile:
											           |%1, role: %2)'")
									EndIf;
									
									Region.Parameters.ProfileORAccessGroupPresentation =
										AccessGroupDescription.PresentationAccessGroups
										+ Chars.LF
										+ StringFunctionsClientServer.SubstituteParametersInString(
											PresentationAdjustmentAccessGroups,
											ProfileDescription.ProfilePresentation,
											TrimAll(ProfileRolesPresentation));
								Else
									Region.Parameters.ProfileORAccessGroupPresentation =
										AccessGroupDescription.PresentationAccessGroups;
								EndIf;
							EndIf;
							If AllRolesWithRestriction Then
								If GetFunctionalOption("UseRecordLevelSecurity") Then
									For Each AccessKindDescription In AccessGroupDescription.Rows Do
										Index = AccessKindDescription.Rows.Count()-1;
										While Index >= 0 Do
											If Not ValueIsFilled(AccessKindDescription.Rows[Index].AccessValue) Then
												AccessKindDescription.Rows.Delete(Index);
											EndIf;
											Index = Index - 1;
										EndDo;
										Index = AccessKindDescription.Rows.Count()-1;
										While Index >= 0 Do
											If Not ValueIsFilled(AccessKindDescription.Rows[Index].AccessValue) Then
												AccessKindDescription.Rows.Delete(Index);
											EndIf;
											Index = Index - 1;
										EndDo;
										// Getting a new area if the access kind is not the first one
										If Region = Undefined Then
											Region = Template.GetArea("ObjectRightsTableString");
										EndIf;
									
										Region.Parameters.AccessKind = AccessKindDescription.AccessKind;
										
										Region.Parameters.AccessKindPresentation =
											StringFunctionsClientServer.SubstituteParametersInString(
												AccessKindPresentationTemplate(
													AccessKindDescription, RightsSettingsOwners),
												AccessKindDescription.AccessKindPresentation);
										
										PutArea(
											Document,
											Region,
											3,
											ObjectAreaInitialString,
											EndObjectAreaRow,
											InitialAreaStringAccessGroups);
										
										For Each AccessValueDetails In AccessKindDescription.Rows Do
											Region = Template.GetArea("ObjectRightsTableStringAccessValues");
											
											Region.Parameters.AccessValuePresentation =
												AccessValueDetails.AccessValuePresentation;
											
											Region.Parameters.AccessValue =
												AccessValueDetails.AccessValue;
												
											PutArea(
												Document,
												Region,
												3,
												ObjectAreaInitialString,
												EndObjectAreaRow,
												InitialAreaStringAccessGroups);
										EndDo;
									EndDo;
								EndIf;
							EndIf;
							If Region <> Undefined Then
								PutArea(
									Document,
									Region,
									3,
									ObjectAreaInitialString,
									EndObjectAreaRow,
									InitialAreaStringAccessGroups);
							EndIf;
							// Setting boundaries for access kinds of the current access group
							SetKindsAndAccessValuesBounds(
								Document,
								InitialAreaStringAccessGroups,
								EndObjectAreaRow);
							
							// Merging access group cells and setting boundaries
							MergeCellsSetBounds(
								Document,
								InitialAreaStringAccessGroups,
								EndObjectAreaRow,
								3);
						EndDo;
					EndIf;
				EndDo;
			EndDo;
			// Merging object cells and setting the boundaries
			MergeCellsSetBounds(
				Document,
				ObjectAreaInitialString,
				EndObjectAreaRow,
				2);
		EndDo;
		Document.Put(IndentArea, 3);
		Document.Put(IndentArea, 3);
		Document.Put(IndentArea, 3);
		Document.Put(IndentArea, 3);
	EndDo;
	Document.Put(IndentArea, 2);
	Document.Put(IndentArea, 2);
	
	// Displaying rights for objects
	RightsSettings = QueryResults[4].Unload(QueryResultIteration.ByGroups);
	RightsSettings.Columns.Add("FullNameObjectsType");
	RightsSettings.Columns.Add("ObjectsKindPresentation");
	RightsSettings.Columns.Add("FullDescr");
	
	For Each ObjectTypeDescription In RightsSettings.Rows Do
		TypeMetadata = Metadata.FindByType(ObjectTypeDescription.ObjectsType);
		ObjectTypeDescription.FullNameObjectsType     = TypeMetadata.FullName();
		ObjectTypeDescription.ObjectsKindPresentation = TypeMetadata.Presentation();
	EndDo;
	RightsSettings.Rows.Sort("ObjectsKindPresentation Asc");
	
	AvailableRights = AccessManagementInternalCached.Parameters().AvailableRightsForObjectRightsSettings;
	
	For Each ObjectTypeDescription In RightsSettings.Rows Do
		
		RightDescription = AvailableRights.ByRefTypes.Get(ObjectTypeDescription.ObjectsType);
		
		If AvailableRights.HierarchicalTables.Get(ObjectTypeDescription.ObjectsType) = Undefined Then
			ObjectTypeRootItems = Undefined;
		Else
			ObjectTypeRootItems = ObjectTypeRootItems(ObjectTypeDescription.ObjectsType);
		EndIf;
		
		For Each ObjectDescription In ObjectTypeDescription.Rows Do
			ObjectDescription.FullDescr = ObjectDescription.Object.FullDescr();
		EndDo;
		ObjectTypeDescription.Rows.Sort("FullDescription Asc");
		
		Region = Template.GetArea("RightSettingsGrouping");
		Region.Parameters.Fill(ObjectTypeDescription);
		Document.Put(Region, 1);
		
		// Legend output
		Region = Template.GetArea("RightSettingsLegendHeader");
		Document.Put(Region, 2);
		For Each RightDetails In RightDescription Do
			Region = Template.GetArea("RightSettingsLegendString");
			Region.Parameters.Title = StrReplace(RightDetails.Title, Chars.LF, " ");
			Region.Parameters.Tooltip = StrReplace(RightDetails.Tooltip, Chars.LF, " ");
			Document.Put(Region, 2);
		EndDo;
		
		TitleForSubfolders =
			NStr("en = 'For subfolders'");
		TooltipForSubfolders = NStr("en = 'Rights both for the current folder and its subfolders'");
		
		Region = Template.GetArea("RightSettingsLegendString");
		Region.Parameters.Title = StrReplace(TitleForSubfolders, Chars.LF, " ");
		Region.Parameters.Tooltip = StrReplace(TooltipForSubfolders, Chars.LF, " ");
		Document.Put(Region, 2);
		
		TitleSettingsReceivedFromGroup = NStr("en = 'Rights setting is received from a group'");
		
		Region = Template.GetArea("RightSettingsLegendStringInheritance");
		Region.Parameters.Tooltip = NStr("en = 'Right inheritance from parent folders'");
		Document.Put(Region, 2);
		
		Document.Put(IndentArea, 2);
		
		// Preparation of the row template
		HeaderTemplate  = New SpreadsheetDocument;
		TemplateRows = New SpreadsheetDocument;
		OutputUserGroups = ObjectTypeDescription.GroupParticipation And Not OutputGroupRights;
		ColumnsNumber = RightDescription.Count() + ?(OutputUserGroups, 2, 1);
		
		For ColumnNumber = 1 To ColumnsNumber Do
			NewHeaderCell  = Template.GetArea("RightSettingsDetailsCellHeader");
			HeaderCell = HeaderTemplate.Join(NewHeaderCell);
			HeaderCell.HorizontalAlign = HorizontalAlign.Center;
			NewRowCell = Template.GetArea("RightSettingsDetailsCellRows");
			RowCell = TemplateRows.Join(NewRowCell);
			RowCell.HorizontalAlign = HorizontalAlign.Center;
		EndDo;
		
		If OutputUserGroups Then
			HeaderCell.HorizontalAlign  = HorizontalAlign.Left;
			RowCell.HorizontalAlign = HorizontalAlign.Left;
		EndIf;
		
		// Header table output
		CellNumberForSubfolders = "R1C" + Format(RightDescription.Count()+1, "NG=");
		
		HeaderTemplate.Area(CellNumberForSubfolders).Text = TitleForSubfolders;
		HeaderTemplate.Area(CellNumberForSubfolders).ColumnWidth =
			MaxStringLength(HeaderTemplate.Area(CellNumberForSubfolders).Text);
		
		BeforeAfter = 1;
		
		CurrentAreaNumber = BeforeAfter;
		For Each RightDetails In RightDescription Do
			CellNumber = "R1C" + Format(CurrentAreaNumber, "NG=");
			HeaderTemplate.Area(CellNumber).Text = RightDetails.Title;
			HeaderTemplate.Area(CellNumber).ColumnWidth = MaxStringLength(RightDetails.Title);
			CurrentAreaNumber = CurrentAreaNumber + 1;
			
			TemplateRows.Area(CellNumber).ColumnWidth = HeaderTemplate.Area(CellNumber).ColumnWidth;
		EndDo;
		
		If OutputUserGroups Then
			CellNumberForGroup = "R1C" + Format(ColumnsNumber, "NG=");
			HeaderTemplate.Area(CellNumberForGroup).Text = TitleSettingsReceivedFromGroup;
			HeaderTemplate.Area(CellNumberForGroup).ColumnWidth = 35;
		EndIf;
		Document.Put(HeaderTemplate, 2);
		
		TextYes  = NStr("en = 'Yes'");
		TextNo = NStr("en = 'None'");
		
		// Table rows output
		For Each ObjectDescription In ObjectTypeDescription.Rows Do
			
			If ObjectTypeRootItems = Undefined
			 Or ObjectTypeRootItems.Get(ObjectDescription.Object) <> Undefined Then
				Region = Template.GetArea("RightSettingsDetailsObject");
				
			ElsIf ObjectDescription.Inherit Then
				Region = Template.GetArea("RightSettingsDetailsObjectInheritYes");
			Else
				Region = Template.GetArea("RightSettingsDetailsObjectInheritNo");
			EndIf;
			
			Region.Parameters.Fill(ObjectDescription);
			Document.Put(Region, 2);
			For Each UserDetails In ObjectDescription.Rows Do
				
				For RightAreaNumber = 1 To ColumnsNumber Do
					CellNumber = "R1C" + Format(RightAreaNumber, "NG=");
					TemplateRows.Area(CellNumber).Text = "";
				EndDo;
				
				If TypeOf(UserDetails.InheritanceIsAllowed) = Type("Boolean") Then
					TemplateRows.Area(CellNumberForSubfolders).Text = ?(
						UserDetails.InheritanceIsAllowed, TextYes, TextNo);
				EndIf;
				
				OwnerRights = AvailableRights.ByTypes.Get(ObjectTypeDescription.ObjectsType);
				For Each CurrentRightDescription In UserDetails.Rows Do
					OwnerRight = OwnerRights.Get(CurrentRightDescription.Right);
					If OwnerRight <> Undefined Then
						RightAreaNumber = OwnerRight.RightIndex + BeforeAfter;
						CellNumber = "R1C" + Format(RightAreaNumber, "NG=");
						TemplateRows.Area(CellNumber).Text = ?(
							CurrentRightDescription.RightIsProhibited, TextNo, TextYes);
					EndIf;
				EndDo;
				If OutputUserGroups Then
					If UserDetails.GroupParticipation Then
						TemplateRows.Area(CellNumberForGroup).Text =
							UserDetails.UserDescription;
						TemplateRows.Area(CellNumberForGroup).DetailsParameter = "User";
						TemplateRows.Parameters.User = UserDetails.User;
					EndIf;
				EndIf;
				TemplateRows.Area(CellNumberForGroup).ColumnWidth = 35;
				Document.Put(TemplateRows, 2);
			EndDo;
		EndDo;
	EndDo;
	
	Document.EndRowAutoGrouping();
	
EndProcedure

&AtServer
Function AccessKindPresentationTemplate(AccessKindDescription, RightsSettingsOwners)
	
	If AccessKindDescription.Rows.Count() = 0 Then
		If RightsSettingsOwners.Get(TypeOf(AccessKindDescription.AccessKind)) <> Undefined Then
			AccessKindPresentationTemplate = "%1";
		ElsIf AccessKindDescription.AllAllowed Then
			If AccessKindDescription.AccessKind = Catalogs.Users.EmptyRef() Then
				AccessKindPresentationTemplate =
					NStr("en = '%1 (nothing is prohibited, current user is always allowed)'");
				
			ElsIf AccessKindDescription.AccessKind = Catalogs.ExternalUsers.EmptyRef() Then
				AccessKindPresentationTemplate =
					NStr("en = '%1 (nothing is prohibited, current external user is always allowed)'");
			Else
				AccessKindPresentationTemplate = NStr("en = '%1 (nothing is prohibited)'");
			EndIf;
		Else
			If AccessKindDescription.AccessKind = Catalogs.Users.EmptyRef() Then
				AccessKindPresentationTemplate =
					NStr("en = '%1 (nothing is allowed, current user is always allowed)'");
				
			ElsIf AccessKindDescription.AccessKind = Catalogs.ExternalUsers.EmptyRef() Then
				AccessKindPresentationTemplate =
					NStr("en = '%1 (nothing is allowed, current external user is always allowed)'");
			Else
				AccessKindPresentationTemplate = NStr("en = '%1 (nothing is allowed)'");
			EndIf;
		EndIf;
	Else
		If AccessKindDescription.AllAllowed Then
			If AccessKindDescription.AccessKind = Catalogs.Users.EmptyRef() Then
				AccessKindPresentationTemplate =
					NStr("en = '%1 (prohibited, current user is always allowed):'");
				
			ElsIf AccessKindDescription.AccessKind = Catalogs.ExternalUsers.EmptyRef() Then
				AccessKindPresentationTemplate =
					NStr("en = '%1 (prohibited, current external user is always allowed):'");
			Else
				AccessKindPresentationTemplate = NStr("en = '%1 (prohibited):'");
			EndIf;
		Else
			If AccessKindDescription.AccessKind = Catalogs.Users.EmptyRef() Then
				AccessKindPresentationTemplate =
					NStr("en = '%1 (allowed, current user is always allowed):'");
				
			ElsIf AccessKindDescription.AccessKind = Catalogs.ExternalUsers.EmptyRef() Then
				AccessKindPresentationTemplate =
					NStr("en = '%1 (allowed, current external user is always allowed):'");
			Else
				AccessKindPresentationTemplate = NStr("en = '%1 (allowed):'");
			EndIf;
		EndIf;
	EndIf;
	
	Return AccessKindPresentationTemplate;
	
EndFunction

&AtServer
Procedure PutArea(Val Document,
                         Region,
                         Level,
                         ObjectAreaInitialString,
                         EndObjectAreaRow,
                         InitialAreaStringAccessGroups)
	
	If ObjectAreaInitialString = Undefined Then
		ObjectAreaInitialString = Document.Put(Region, Level);
		EndObjectAreaRow        = ObjectAreaInitialString;
	Else
		EndObjectAreaRow = Document.Put(Region);
	EndIf;
	
	If InitialAreaStringAccessGroups = Undefined Then
		InitialAreaStringAccessGroups = EndObjectAreaRow;
	EndIf;
	
	Region = Undefined;
	
EndProcedure

&AtServer
Procedure MergeCellsSetBounds(Val Document,
                                            Val InitialAreaString,
                                            Val EndAreaRow,
                                            Val ColumnNumber)
	
	Region = Document.Area(
		InitialAreaString.Top,
		ColumnNumber,
		EndAreaRow.Bottom,
		ColumnNumber);
	
	Region.Merge();
	
	BoundaryLine = New Line(SpreadsheetDocumentCellLineType.Dotted);
	
	Region.TopBorder = BoundaryLine;
	Region.BottomBorder  = BoundaryLine;
	
EndProcedure
	
&AtServer
Procedure SetKindsAndAccessValuesBounds(Val Document,
                                                 Val InitialAreaStringAccessGroups,
                                                 Val EndObjectAreaRow)
	
	BoundaryLine = New Line(SpreadsheetDocumentCellLineType.Dotted);
	
	Region = Document.Area(
		InitialAreaStringAccessGroups.Top,
		4,
		InitialAreaStringAccessGroups.Top,
		5);
	
	Region.TopBorder = BoundaryLine;
	
	Region = Document.Area(
		EndObjectAreaRow.Bottom,
		4,
		EndObjectAreaRow.Bottom,
		5);
	
	Region.BottomBorder = BoundaryLine;
	
EndProcedure

&AtServer
Function RunModePresentation(RunMode)
	
	If RunMode = "Auto" Then
		RunModePresentation = NStr("en = 'Auto'");
		
	ElsIf RunMode = "OrdinaryApplication" Then
		RunModePresentation = NStr("en = 'Standard application'");
		
	ElsIf RunMode = "ManagedApplication" Then
		RunModePresentation = NStr("en = 'Managed application'");
	Else
		RunModePresentation = "";
	EndIf;
	
	Return RunModePresentation;
	
EndFunction

&AtServer
Function LanguagePresentation(Language)
	
	LanguagePresentation = "";
	
	For Each LanguageMetadata In Metadata.Languages Do
	
		If LanguageMetadata.Name = Language Then
			LanguagePresentation = LanguageMetadata.Synonym;
			Break;
		EndIf;
	EndDo;
	
	Return LanguagePresentation;
	
EndFunction

// RightRestrictionKindsOfMetadataObjects
// function returns the value table containing
// access restriction kind by each metadata object right.
//  If no record is returned for a right, no restrictions exist for this right.
//
// Returns:
//  ValueTable:
//    AccessKind   - Ref - an empty reference to main access kind value type.
//    Presentation - String - access kind presentation.
//    Table        - CatalogRef.MetadataObjectIDs,
//                    for example, CatalogRef.Counterparties.
//    Right        - String: "Read", "Change".
//
&AtServer
Function RightRestrictionKindsOfMetadataObjects()
	
	Cache = AccessManagementInternalCached.RightRestrictionKindsOfMetadataObjects();
	
	If CurrentSessionDate() < Cache.UpdateDate + 60*30 Then
		Return Cache.Table;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("PermanentRestrictionKinds",
		AccessManagementInternalCached.PermanentRightRestrictionKindsOfMetadataObjects());
	
	Query.SetParameter("AccessKindValueTypes",
		AccessManagementInternalCached.ValueTypesOfAccessKindsAndRightsSettingsOwners());
	
	AccessKindsToUse = AccessManagementInternalCached.ValueTypesOfAccessKindsAndRightsSettingsOwners(
		).Copy(, "AccessKind");
	
	AccessKindsToUse.GroupBy("AccessKind");
	AccessKindsToUse.Columns.Add("Presentation", New TypeDescription("String", ,,, New StringQualifiers(150)));
	
	Index = AccessKindsToUse.Count()-1;
	While Index >= 0 Do
		Row = AccessKindsToUse[Index];
		AccessKindProperties = AccessManagementInternal.AccessKindProperties(Row.AccessKind);
		
		If AccessKindProperties = Undefined Then
			RightsSettingsOwnerMetadata = Metadata.FindByType(TypeOf(Row.AccessKind));
			If RightsSettingsOwnerMetadata = Undefined Then
				Row.Presentation = NStr("en = 'Unknown access kind'");
			Else
				Row.Presentation = StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'Rights settings for %1'"), RightsSettingsOwnerMetadata.Presentation());
			EndIf;
		ElsIf AccessManagementInternal.AccessKindUsed(Row.AccessKind) Then
			Row.Presentation = AccessKindProperties.Presentation;
		Else
			AccessKindsToUse.Delete(Row);
		EndIf;
		Index = Index - 1;
	EndDo;
	
	Query.SetParameter("AccessKindsToUse", AccessKindsToUse);
	
	Query.Text =
	"SELECT
	|	PermanentRestrictionKinds.Table,
	|	PermanentRestrictionKinds.Right,
	|	PermanentRestrictionKinds.AccessKind,
	|	PermanentRestrictionKinds.ObjectTable
	|INTO PermanentRestrictionKinds
	|FROM
	|	&PermanentRestrictionKinds AS PermanentRestrictionKinds
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccessKindValueTypes.AccessKind,
	|	AccessKindValueTypes.ValueType
	|INTO AccessKindValueTypes
	|FROM
	|	&AccessKindValueTypes AS AccessKindValueTypes
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccessKindsToUse.AccessKind,
	|	AccessKindsToUse.Presentation
	|INTO AccessKindsToUse
	|FROM
	|	&AccessKindsToUse AS AccessKindsToUse
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	PermanentRestrictionKinds.Table,
	|	""Read"" AS Right,
	|	VALUETYPE(RowsSets.AccessValue) AS ValueType
	|INTO VariableRestrictionKinds
	|FROM
	|	InformationRegister.AccessValueSets AS SetNumbers
	|		INNER JOIN PermanentRestrictionKinds AS PermanentRestrictionKinds
	|		ON (PermanentRestrictionKinds.Right = ""Read"")
	|			AND (PermanentRestrictionKinds.AccessKind = UNDEFINED)
	|			AND (VALUETYPE(SetNumbers.Object) = VALUETYPE(PermanentRestrictionKinds.ObjectTable))
	|			AND (SetNumbers.Read)
	|		INNER JOIN InformationRegister.AccessValueSets AS RowsSets
	|		ON (RowsSets.Object = SetNumbers.Object)
	|			AND (RowsSets.SetNumber = SetNumbers.SetNumber)
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	PermanentRestrictionKinds.Table,
	|	""Update"",
	|	VALUETYPE(RowsSets.AccessValue)
	|FROM
	|	InformationRegister.AccessValueSets AS SetNumbers
	|		INNER JOIN PermanentRestrictionKinds AS PermanentRestrictionKinds
	|		ON (PermanentRestrictionKinds.Right = ""Update"")
	|			AND (PermanentRestrictionKinds.AccessKind = UNDEFINED)
	|			AND (VALUETYPE(SetNumbers.Object) = VALUETYPE(PermanentRestrictionKinds.ObjectTable))
	|			AND (SetNumbers.Update)
	|		INNER JOIN InformationRegister.AccessValueSets AS RowsSets
	|		ON (RowsSets.Object = SetNumbers.Object)
	|			AND (RowsSets.SetNumber = SetNumbers.SetNumber)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PermanentRestrictionKinds.Table,
	|	PermanentRestrictionKinds.Right,
	|	AccessKindValueTypes.AccessKind
	|INTO AllRightRestrictionsKinds
	|FROM
	|	PermanentRestrictionKinds AS PermanentRestrictionKinds
	|		INNER JOIN AccessKindValueTypes AS AccessKindValueTypes
	|		ON PermanentRestrictionKinds.AccessKind = AccessKindValueTypes.AccessKind
	|			AND (PermanentRestrictionKinds.AccessKind <> UNDEFINED)
	|
	|UNION
	|
	|SELECT
	|	VariableRestrictionKinds.Table,
	|	VariableRestrictionKinds.Right,
	|	AccessKindValueTypes.AccessKind
	|FROM
	|	VariableRestrictionKinds AS VariableRestrictionKinds
	|		INNER JOIN AccessKindValueTypes AS AccessKindValueTypes
	|		ON (VariableRestrictionKinds.ValueType = VALUETYPE(AccessKindValueTypes.ValueType))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AllRightRestrictionsKinds.Table,
	|	AllRightRestrictionsKinds.Right,
	|	AllRightRestrictionsKinds.AccessKind,
	|	AccessKindsToUse.Presentation
	|FROM
	|	AllRightRestrictionsKinds AS AllRightRestrictionsKinds
	|		INNER JOIN AccessKindsToUse AS AccessKindsToUse
	|		ON AllRightRestrictionsKinds.AccessKind = AccessKindsToUse.AccessKind";
	
	Data = Query.Execute().Unload();
	
	Cache.Table = Data;
	Cache.UpdateDate = CurrentSessionDate();
	
	Return Data;
	
EndFunction

&AtServer
Function MaxStringLength(MultilineString, InitialLength = 5)
	
	For LineNumber = 1 To StrLineCount(MultilineString) Do
		SubstringLength = StrLen(StrGetLine(MultilineString, LineNumber));
		If InitialLength < SubstringLength Then
			InitialLength = SubstringLength;
		EndIf;
	EndDo;
	
	Return InitialLength + 1;
	
EndFunction

&AtServer
Function ObjectTypeRootItems(ObjectsType)
	
	TableName = Metadata.FindByType(ObjectsType).FullName();
	
	Query = New Query;
	Query.SetParameter("EmptyRef",
		CommonUse.ObjectManagerByFullName(TableName).EmptyRef());
	
	Query.Text =
	"SELECT
	|	CurrentTable.Ref AS Ref
	|FROM
	|	&CurrentTable AS CurrentTable
	|WHERE
	|	CurrentTable.Parent = &EmptyRef";
	
	Query.Text = StrReplace(Query.Text, "&CurrentTable", TableName);
	Selection = Query.Execute().Select();
	
	RootItems = New Map;
	While Selection.Next() Do
		RootItems.Insert(Selection.Ref, True);
	EndDo;
	
	Return RootItems;
	
EndFunction

#EndRegion
