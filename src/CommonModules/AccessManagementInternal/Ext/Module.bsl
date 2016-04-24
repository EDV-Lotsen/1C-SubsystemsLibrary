////////////////////////////////////////////////////////////////////////////////
// Access management subsystem
// 
////////////////////////////////////////////////////////////////////////////////

#Region InternalInterface

////////////////////////////////////////////////////////////////////////////////
// Declaring internal events to which handlers can be added.

// Declares events of the AccessManagement subsystem:
//
// Server events:
//   OnFillAvailableRightsForObjectRightsSettings,
//   OnFillAccessRightDependencies,
//   OnFillMetadataObjectAccessRestrictionKinds,
//   OnFillAccessKinds,
//   OnFillSuppliedAccessGroupProfiles,
//   OnFillAccessKindUse,
//   OnChangeAccessValueSets,
//
// See the description of this procedure in the StandardSubsystemsServer module.
Procedure OnAddInternalEvent(ClientEvents, ServerEvents) Export
	
	// SERVER EVENTS
	
	// Fills the description of available rights assigned to the objects of specified types.
	// 
	// Parameters:
	//  AvailableRights - ValueTable - for description of ValueTable fields,
 //                     see the comments to function
 //                    InformationRegisters.ObjectRightsSettings.AvailableRights().
	//
	// Syntax:
	// Procedure OnFillAvailableRightsForObjectRightsSettings(Val AvailableRights) Export
	//
	// (Identical to AccessManagementOverridable.OnFillAvailableRightsForObjectRightsSettings).
	//
	ServerEvents.Add("StandardSubsystems.AccessManagement\OnFillAvailableRightsForObjectRightsSettings");
	
	// Fills the non-standard access right dependencies between the
	// subordinate object and the main object. For example, fills access right dependencies between PerformerTask task and Job business process.
	//
	// The access right dependencies are used in the standard access restriction template for Object access kind:
	// 1) By default, when reading a subordinate object, a check is
	//    made whether the user has the right to read the head object and has no restrictions to read it;
	// 2) When adding, changing, or deleting a subordinate object,
	//    the following standard checks are performed:
	//    whether the user has the right to edit the head object and whether the user has no restrictions for editing the main object.
	//
	// A single variation of this procedure is allowed:
	// in paragraph 2 above, checking the right to edit the
	// head object can be replaced by checking the right to read the head object.
	//
	// Parameters:
	//  RightDependencies - ValueTable with the following columns:
	//                    - LeadingTable     - String, for example, "BusinessProcess.Task".
	//                    - SubordinateTable - String, for example, "Task.PerformerTask".
	//
	// Syntax:
	// Procedure OnFillAccessRightDependencies(RightDependencies) Export
	//
	// (Identical to AccessManagementOverridable.OnFillAccessRightDependencies).
	//
	ServerEvents.Add("StandardSubsystems.AccessManagement\OnFillAccessRightDependencies");
	
	// Fills the list of access kinds that are used to set metadata object right restrictions.
	// If the list of access kinds is not filled, the Access rights report displays incorrect data.
	//
	// Only access kinds that are explicitly
	// used in access restriction templates must be filled, while
	// access kinds used in access value sets can alternately be
	// obtained from the current state of the AccessValueSets information register.
	//
	// To generate the procedure content automatically,
	// it is recommended that you use the developer tools from the 
	// Access management subsystem.
	//
	// Parameters:
	//  Description  - Row, multiline row in format                     <Table>.<Right>.<AccessKind>[.Object table]
	//                 Examples: Document.GoodsReceipt.Read.Companies
	//                           Document.GoodsReceipt.Read.Counterparties
	//                           Document.GoodsReceipt.Change.Companies
	//                           Document.GoodsReceipt.Change.Counterparties
	//                           Document.Emails.Read.Object.Document.Emails
	//                           Document.Emails.Change.Object.Document.Emails
	//                           Document.Files.Read.Object.Catalog.FileFolders
	//                           Document.Files.Read.Object.Document.EmailMassage
	//                           Document.Files.Change.Object.Catalog.FileFolders
	//                           Document.Files.Change.Object.Document.EmailMessage
	//                 Access kind Object is predefined as a literal. This access kind is
	//                 used in access restriction templates as a reference to another
	//                 object that is used for applying restrictions to the current table item.
	//                 When access kind is set to Object, you must
	//                 also set table types used for this access kind.
 //                  To enumerate the types corresponding to the field
	//                 used in the access restriction template together with
	//                 the "Object" access kind. The list of types for the
	//                 Object access kinds should only include the field types available
	//                 for InformationRegisters.AccessValueSets.Object, the other types are excessive.
	//
	// Syntax:
	// Procedure OnFillMetadataObjectAccessRestrictionKinds(Description) Export
	//
	// (Identical to AccessManagementOverridable.OnFillMetadataObjectAccessRestrictionKinds).
	//
	ServerEvents.Add("StandardSubsystems.AccessManagement\OnFillMetadataObjectAccessRestrictionKinds");
	
	// Fills access kinds used in access restrictions.
	// Users and ExternalUsers access kinds are already filled.
	// They can be deleted if they are not used in access restrictions.
	//
	// Parameters:
	//  AccessKinds - ValueTable with the following fields:
	//  - Name                - String - name used in the descriptions of supplied
	//                           access group profiles and in RLS texts.
	//  - Presentation        - String - access kind presentation in profiles and access groups.
	//  - ValueType           - Type - access value reference type.       Example: Type("CatalogRef.ProductsAndServices").
	//  - ValueGroupType      - Type - access value group reference type. Example: Type("CatalogRef.ProductAndServiceAccessGroups").
	//  - MultipleValueGroups - Boolean - if True, multiple value groups (product
	//                             and service access groups) can be selected for a single access value (ProductsAndServices).
	//
	// Syntax:
	// Procedure OnFillAccessKinds(AccessKinds) Export
	//
	// (Identical to AccessManagementOverridable.OnFillAccessKinds).
	//
	ServerEvents.Add("StandardSubsystems.AccessManagement\OnFillAccessKinds");
	
	// Fills descriptions of supplied access group
	// profiles and overrides update parameters of profiles and access groups.
	//
	// To generate the procedure content automatically, it is recommended that
	// you use the developer tools from the Access management subsystem.
	//
	// Parameters:
	//  ProfileDescriptions    - Array to which descriptions must be added.
	//                        An empty structure must be generated using
	//                        AccessManagement.NewAccessGroupProfileDescription().
	//
	//  UpdateParameters - Structure with the following properties:
	//
	//                        UpdateModifiedProfiles - Boolean (the initial value is True).
	//                        DenyProfileChange - Boolean (the initial value is True).
	//                        If set to False, the supplied profiles will be opened in ReadOnly mode.                        
	//                        
	//                        UpdateAccessGroups - Boolean (the initial value is True).
	//
	//                        UpdateAccessGroupsWithObsoleteSettings - Boolean
	//                        (the initial value is False). If set to True, the
	//                        value settings made by administrator according to an
	//                        access kind which is deleted from the profile, will be deleted from the access group.
	//
	// Syntax:
	// Procedure OnFillSuppliedAccessGroupProfiles(ProfileDescriptions, UpdateParameters) Export
	//
	// (Identical to AccessManagementOverridable.FillAccessGroupsSuppliedProfiles).
	//
	ServerEvents.Add("StandardSubsystems.AccessManagement\OnFillSuppliedAccessGroupProfiles");
	
	// Fills the usage of access kinds depending on the configuration
	// functional options, for example, UseProductAndServiceAccessGroups.
	//
	// Parameters:
	//  AccessKind    - String. Access kind name specified in the OnFillAccessKinds procedure.
	//  Use - Boolean (return value). Initial value is True.
	// 
	// Syntax:
	// Procedure OnFillAccessKindUse(AccessKindName, Use) Export
	//
	// (Identical to AccessManagementOverridable.OnFillAccessKindUse).
	//
	ServerEvents.Add("StandardSubsystems.AccessManagement\OnFillAccessKindUse");
	
	// Allows to overwrite the dependent access value sets of other objects.
	//
	//  Called from procedures:
	// AccessManagementInternal.WriteAccessValueSets(),
	// AccessManagementInternal.WriteDependentAccessValueSets().
	//
	// Parameters:
	//  Ref       - CatalogRef, DocumentRef, ... - reference to an object for which
	//                  the access value sets are written.
	//
	//  RefsToDependentObjects - Array with items of type CatalogRef, DocumentRef, ...
	//                 Contains references to objects with the dependent access value sets.
	//                  Initial value - empty array.
	//
	// Syntax:
	// Procedure OnChangeAccessValueSets(Val Reference, RefsToDependentObjects) Export
	//
	// (Identical to AccessManagementOverridable.OnChangeAccessValueSets).
	//
	ServerEvents.Add("StandardSubsystems.AccessManagement\OnChangeAccessValueSets");
	
	// This procedure is called when updating the infobase user roles.
	//
	// Parameters:
	//  InfobaseUserID - UUID,
	//  Cancel - Boolean. If this parameter is set to False in the event handler,
	//     roles are not updated for this infobase user.
	//
	// Syntax:
	// Procedure OnInfobaseUserRoleUpdate( InfobaseUserID, Cancel) Export.
	ServerEvents.Add("StandardSubsystems.AccessManagement\OnInfobaseUserRoleUpdate");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Adding the event handlers.

// See the description of this procedure in the StandardSubsystemsServer module.
Procedure InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers) Export
	
	// SERVER HANDLERS
	
	ServerHandlers["StandardSubsystems.InfobaseVersionUpdate\OnAddUpdateHandlers"].Add(
		"AccessManagementInternal");
	
	ServerHandlers["StandardSubsystems.BaseFunctionality\SessionParameterSettingHandlersOnAdd"].Add(
		"AccessManagementInternal");
	
	ServerHandlers["StandardSubsystems.BaseFunctionality\StandardSubsystemClientLogicParametersOnAdd"].Add(
		"AccessManagementInternal");
	
	ServerHandlers["StandardSubsystems.BaseFunctionality\OnAddReferenceSearchException"].Add(
		"AccessManagementInternal");
	
	ServerHandlers["StandardSubsystems.BaseFunctionality\NotUniquePredefinedItemFound"].Add(
		"AccessManagementInternal");
	
	ServerHandlers["StandardSubsystems.BaseFunctionality\OnReceiveDataFromMaster"].Add(
		"AccessManagementInternal");
	
	ServerHandlers["StandardSubsystems.BaseFunctionality\OnReceiveDataFromSlave"].Add(
		"AccessManagementInternal");
	
	ServerHandlers["StandardSubsystems.BaseFunctionality\DataFromSubordinateAfterReceive"].Add(
		"AccessManagementInternal");
	
	ServerHandlers["StandardSubsystems.BaseFunctionality\DataFromMasterAfterReceive"].Add(
		"AccessManagementInternal");
	
	ServerHandlers["StandardSubsystems.BaseFunctionality\OnGetMandatoryExchangePlanObjects"].Add(
		"AccessManagementInternal");
	
	ServerHandlers["StandardSubsystems.BaseFunctionality\OnGetExchangePlanInitialImageObjects"].Add(
		"AccessManagementInternal");
	
	ServerHandlers["StandardSubsystems.Users\OnDefineRoleEditProhibition"].Add(
		"AccessManagementInternal");
		
	ServerHandlers["StandardSubsystems.Users\OnDefineActionsInForm"].Add(
		"AccessManagementInternal");
	
	ServerHandlers["StandardSubsystems.Users\OnDefineQuestionTextBeforeWriteFirstAdministrator"].Add(
		"AccessManagementInternal");
	
	ServerHandlers["StandardSubsystems.Users\OnWriteAdministrator"].Add(
		"AccessManagementInternal");
	
	If CommonUse.SubsystemExists("StandardSubsystems.ReportOptions") Then
		ServerHandlers["StandardSubsystems.ReportOptions\ReportOptionsOnSetup"].Add(
			"AccessManagementInternal");
	EndIf;
	
	If CommonUse.SubsystemExists("CloudTechnology.DataImportExport") Then
		ServerHandlers[
			"CloudTechnology.DataImportExport\OnFillCommonDataTypesDoNotRequireMappingRefsOnImport"].Add(
				"AccessManagementInternal");
		ServerHandlers[
			"CloudTechnology.DataImportExport\OnFillExcludedFromImportExportTypes"].Add(
				"AccessManagementInternal");
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.ToDoList") Then
		ServerHandlers["StandardSubsystems.ToDoList\OnFillToDoList"].Add(
			"Catalogs.AccessGroupProfiles");
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Main procedures and functions.

// Adds a user to an access group of the supplied profile.
// The access group is determined by the ID reference of a supplied profile.
// If an access group is not found it will be created.
// 
// Parameters:
//  User                - CatalogRef.Users,
//                        CatalogRef.ExternalUsers,
//                        CatalogRef.UserGroups,
//                        CatalogRef.ExternalUserGroups
//                        - participant to be included in the access group.
// 
//  SuppliedProfile - String - ID string of the supplied profile or
//                  - CatalogRef.AccessGroupProfiles - reference to
//                    the profile which is created by description
//                    in the AccessManagementOverridable module in FillAccessGroupsSuppliedProfiles procedure.
//                    Profiles with a non-empty list of access types are not supported.
//                    Administrator access group profile is not supported.
// 
Procedure AddUserToAccessGroup(User, SuppliedProfile) Export
	
	ProcessUserLinkWithAccessGroup(User, SuppliedProfile, True);
	
EndProcedure

// Deletes a user from the access group which corresponds to a supplied profile.
// The access group is determined by the ID reference of a supplied profile.
// Unless an access group is found no actions will be executed.
// 
// Parameters:
//  User                - CatalogRef.Users,
//                        CatalogRef.ExternalUsers,
//                        CatalogRef.UserGroups,
//                        CatalogRef.ExternalUserGroups
//                        - participant to be excluded from the access group.
// 
//  SuppliedProfile - String - ID string of the supplied profile or
//                  - CatalogRef.AccessGroupProfiles - reference to
//                    the profile which is created by description
//                    in the AccessManagementOverridable module in FillAccessGroupsSuppliedProfiles procedure.
//                    Profiles with a non-empty list of access types are not supported.
//                    Administrator access group profile is not supported.
// 
Procedure DeleteUserFromAccessGroup(User, SuppliedProfile) Export
	
	ProcessUserLinkWithAccessGroup(User, SuppliedProfile, False);
	
EndProcedure

// Finds a user in the access group corresponding to a supplied profile.
// The access group is determined by the ID reference of a supplied profile.
// Unless an access group is found no actions will be executed.
// 
// Parameters:
//  User            - CatalogRef.Users,
//                    CatalogRef.ExternalUsers,
//                    CatalogRef.UserGroups,
//                    CatalogRef.ExternalUserGroups
//                  - participant to be found in the access group.
// 
//  SuppliedProfile - String - ID string of the supplied profile or
//                  - CatalogRef.AccessGroupProfiles - reference to
//                    the profile which is created by description
//                    in the AccessManagementOverridable module in FillAccessGroupsSuppliedProfiles procedure.
//                        Profiles with a non-empty list of access types are not supported.
//                        Administrator access group profile is not supported.
// 
Function FindUserInAccessGroup(User, SuppliedProfile) Export
	
	Return ProcessUserLinkWithAccessGroup(User, SuppliedProfile);
	
EndFunction

// Sets session parameters for the current constants settings
// and user access group settings.
//  Called OnStart.
//
Procedure SessionParametersSetting(ParameterName, SpecifiedParameters) Export
	
	SetPrivilegedMode(True);
	
	If Not Constants.UseRecordLevelSecurity.Get() Then
		// For the preprocessor to work correctly when the access is restricted, you must
		// initialize all session parameters that could be required by the preprocessor.
		SessionParameters.AllAccessKindsExceptSpecial              = "";
		SessionParameters.DisabledAccessKinds                      = "";
		SessionParameters.AccessKindsWithoutGroupsForAccessValues  = "";
		SessionParameters.AccessKindsWithSingleGroupForAccessValue = "";
		
		SessionParameters.AccessValueTypesWithGroups
			= New FixedArray(New Array);
		
		SessionParameters.TablesWithIndividualRightSettings        = "";
		
		SessionParameters.IDsOfTablesWithSpecificRightSettings
			= New FixedArray(New Array);
		
		SessionParameters.RightsSettingsOwnerTypes
			= New FixedArray(New Array);
		
		SpecifiedParameters.Add("AllAccessKindsExceptSpecial");
		SpecifiedParameters.Add("DisabledAccessKinds");
		SpecifiedParameters.Add("AccessKindsWithoutGroupsForAccessValues");
		SpecifiedParameters.Add("AccessKindsWithSingleGroupForAccessValue");
		SpecifiedParameters.Add("AccessValueTypesWithGroups");
		SpecifiedParameters.Add("TablesWithIndividualRightSettings");
		SpecifiedParameters.Add("IDsOfTablesWithSpecificRightSettings");
		SpecifiedParameters.Add("RightsSettingsOwnerTypes");
		Return;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("CurrentUser", Users.AuthorizedUser());
	Query.Text =
	"SELECT DISTINCT
	|	DefaultValues.AccessValueType AS ValueType,
	|	DefaultValues.NoSettings AS NoSettings
	|INTO DefaultValuesForUser
	|FROM
	|	InformationRegister.DefaultAccessGroupValues AS DefaultValues
	|WHERE
	|	TRUE IN
	|			(SELECT TOP 1
	|				TRUE
	|			FROM
	|				Catalog.AccessGroups.Users AS AccessGroupsUsers
	|					INNER JOIN InformationRegister.UserGroupContent AS UserGroupContent
	|					ON
	|						AccessGroupsUsers.Ref = DefaultValues.AccessGroup
	|							AND AccessGroupsUsers.User = UserGroupContent.UserGroup
	|							AND UserGroupContent.User = &CurrentUser)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	DefaultValues.ValueType
	|FROM
	|	DefaultValuesForUser AS DefaultValues
	|
	|GROUP BY
	|	DefaultValues.ValueType
	|
	|HAVING
	|	MIN(DefaultValues.NoSettings) = TRUE";
	
	ValueTypesWithoutSettings = Query.Execute().Unload().UnloadColumn("ValueType");
	
	// Setting AllAccessKindsExceptSpecial, DisabledAccessKinds parameters
	AllAccessKindsExceptSpecial = New Array;
	DisabledAccessKinds         = New Array;
	
	Parameters = AccessManagementInternalCached.Parameters();
	
	For Each AccessKindProperties In Parameters.AccessKindsProperties.Array Do
		AllAccessKindsExceptSpecial.Add(AccessKindProperties.Name);
		
		If Not AccessKindUsed(AccessKindProperties.Ref)
		 Or ValueTypesWithoutSettings.Find(AccessKindProperties.Ref) <> Undefined Then
			
			DisabledAccessKinds.Add(AccessKindProperties.Name);
		EndIf;
	EndDo;
	
	SessionParameters.AllAccessKindsExceptSpecial = AllAccessKindCombinations(AllAccessKindsExceptSpecial);
	
	SpecifiedParameters.Add("AllAccessKindsExceptSpecial");
	
	AllAccessKindsExceptSpecialDisabled = (AllAccessKindsExceptSpecial.Count()
		= DisabledAccessKinds.Count());
	
	If AllAccessKindsExceptSpecialDisabled Then
		SessionParameters.DisabledAccessKinds = "All";
	Else
		SessionParameters.DisabledAccessKinds
			= AllAccessKindCombinations(DisabledAccessKinds);
	EndIf;
	
	SpecifiedParameters.Add("DisabledAccessKinds");
	
	// Setting AccessKindsWithoutGroupsForAccessValues,
	// AccessKindsWithSingleGroupForAccessValue, AccessValueTypesWithGroups parameters
	SessionParameters.AccessKindsWithoutGroupsForAccessValues =
		AllAccessKindCombinations(Parameters.AccessKindsProperties.WithoutGroupsForAccessValues);
	SessionParameters.AccessKindsWithSingleGroupForAccessValue =
		AllAccessKindCombinations(Parameters.AccessKindsProperties.WithOneGroupForAccessValue);
	
	AccessValueTypesWithGroups = New Array;
	For Each KeyAndValue In Parameters.AccessKindsProperties.AccessValueTypesWithGroups Do
		AccessValueTypesWithGroups.Add(KeyAndValue.Value);
	EndDo;
	SessionParameters.AccessValueTypesWithGroups = New FixedArray(AccessValueTypesWithGroups);
	
	SpecifiedParameters.Add("AccessKindsWithoutGroupsForAccessValues");
	SpecifiedParameters.Add("AccessKindsWithSingleGroupForAccessValue");
	SpecifiedParameters.Add("AccessValueTypesWithGroups");
	
	// Setting TablesWithIndividualRightSettings,
	// IDsOfTablesWithSpecificRightSettings RightsSettingsOwnerTypes parameters 
	SeparateTables = Parameters.AvailableRightsForObjectRightsSettings.SeparateTables;
	TablesWithIndividualRightSettings = "";
	IDsOfTablesWithSpecificRightSettings = New Array;
	For Each KeyAndValue In SeparateTables Do
		TablesWithIndividualRightSettings = TablesWithIndividualRightSettings
			+ "|" + KeyAndValue.Value + ";" + Chars.LF;
		IDsOfTablesWithSpecificRightSettings.Add(KeyAndValue.Key);
	EndDo;
	
	SessionParameters.TablesWithIndividualRightSettings = TablesWithIndividualRightSettings;
	
	SessionParameters.IDsOfTablesWithSpecificRightSettings =
		New FixedArray(IDsOfTablesWithSpecificRightSettings);
	
	SessionParameters.RightsSettingsOwnerTypes = Parameters.AvailableRightsForObjectRightsSettings.OwnerTypes;
	
	SpecifiedParameters.Add("TablesWithIndividualRightSettings");
	SpecifiedParameters.Add("IDsOfTablesWithSpecificRightSettings");
	SpecifiedParameters.Add("RightsSettingsOwnerTypes");
	
EndProcedure

// Overrides behavior after receiving data in a distributed infobase.
Procedure DataAfterReceive(Sender, Cancel, FromSubordinate) Export
	
	AccessManagement.UpdateUserRoles();
	
EndProcedure

// Fills the parameter structures required for the client configuration  
// code.
//
// Parameters:
//   Parameters   - Structure - parameter structure.
//
Procedure AddClientParameters(Parameters) Export
	
	Parameters.Insert("SimplifiedAccessRightSetupInterface",
		SimplifiedAccessRightSetupInterface());
	
EndProcedure

// Updates the user content of performer groups.
// 
// This procedure must be called when the user content of a user group
// (for example, task performer groups) is changed.
//
// Performer groups with changed content are passed as parameter values.
//
// Parameters:
//  PerformerGroups - for example, CatalogRef.TaskPerformerGroups.
//                  - Array of values of the types specified above.
//                  - Undefined - not filtered.
//
Procedure UpdatePerformerGroupUsers(PerformerGroups = Undefined) Export
	
	If TypeOf(PerformerGroups) = Type("Array") And PerformerGroups.Count() = 0 Then
		Return;
	EndIf;
	
	Parameters = New Structure;
	Parameters.Insert("PerformerGroups", PerformerGroups);
	
	InformationRegisters.AccessValueGroups.UpdateUserGrouping(Parameters);
	
EndProcedure

// Checks whether an access type with the specified name exists.
// It is used for automation of conditional subsystem incorporation.
// 
Function AccessKindExists(AccessKindName) Export
	
	Return AccessKindProperties(AccessKindName) <> Undefined;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Handlers of the conditional subsystem calls

// Overrides comment text during the authorization of the infobase user 
// that is created in Designer and has administrative rights.
//  The procedure is called from Users.AuthenticateCurrentUser().
//  The comment is written to the event log.
// 
// Parameters:
//  Comment  - String - initial value is specified.
//
Procedure AfterWriteAdministratorOnAuthorization(Comment) Export
	
	Comment = NStr("en = 'It is detected that the infobase user 
	                         |with role ""Full rights"" was created in Designer:
	                         |- user is not found in the Users catalog, 
	                         |- user is registered in the Users catalog,
                           |- user is added to Administrators access group.
	                         |
	                         |Infobase users must be created in 1C:Enterprise mode.'");
	
EndProcedure

// Overrides the action that is performed during the authorization of
// local infobase administrator or data area administrator.
//
Procedure OnAuthorizeAdministratorOnStart(Administrator) Export
	
	// The administrator is automatically added to the Administrators access group during authorization.
	If Not Users.InfobaseUserWithFullAccess(, Not CommonUseCached.DataSeparationEnabled()) Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'You do not have sufficient rights to add user ""%1"" 
			           |to the Administrators access group.'"),
			String(Administrator));
	EndIf;
	
	Query = New Query;
	Query.SetParameter("User", Administrator);
	Query.Text =
	"SELECT
	|	TRUE AS TrueValue
	|FROM
	|	Catalog.AccessGroups.Users AS AccessGroupsUsers
	|WHERE
	|	AccessGroupsUsers.Ref = VALUE(Catalog.AccessGroups.Administrators)
	|	AND AccessGroupsUsers.User = &User";
	
	If Query.Execute().IsEmpty() Then
		Object = Catalogs.AccessGroups.Administrators.GetObject();
		Object.Users.Add().User = Administrator;
		InfobaseUpdate.WriteData(Object);
	EndIf;
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

// Updates the role list of infobase users by their current access groups.
// Users with the FullAccess role are skipped.
// 
// Parameters:
//  Users - CatalogRef.Users,
//          CatalogRef.ExternalUsers
//          Array of values of the types specified above.
//          - Undefined - update all user roles.
//          - Type used for metadata object search:
//          if Catalog.ExternalUsers is found,
//          all external user roles are updated,
//          otherwise all user roles are updated.
//
//  ServiceUserPassword - String - Password for authorization in service manager.
//  HasChanges - Boolean (return value) - Set to True if changes were saved, otherwise not set.
//
Procedure UpdateUserRoles(Val Users1 = Undefined,
                                    Val ServiceUserPassword = Undefined,
                                    HasChanges = False) Export
	
	If Not UsersInternal.RoleEditProhibition() Then
		// Roles are set by the mechanisms of Users and ExternalUsers subsystems.
		Return;
	EndIf;
	
	If Users1 = Undefined Then
		UserArray = Undefined;
		Users.FindAmbiguousInfobaseUsers();
		
	ElsIf TypeOf(Users1) = Type("Array") Then
		UserArray = Users1;
		If UserArray.Count() = 0 Then
			Return;
		EndIf;
		Users.FindAmbiguousInfobaseUsers();
		
	ElsIf TypeOf(Users1) = Type("Type") Then
		UserArray = Users1;
	Else
		UserArray = New Array;
		UserArray.Add(Users1);
		Users.FindAmbiguousInfobaseUsers(Users1);
	EndIf;
	
	SetPrivilegedMode(True);
	
	CurrentUserProperties = CurrentUserProperties(UserArray);
	
	// Checking parameters in the loop
	AllRoles        = UsersInternal.AllRoles().Map;
	InfobaseUserIDs = CurrentUserProperties.InfobaseUserIDs;
	NewUserRoles    = CurrentUserProperties.UsersRoles;
	Administrators  = CurrentUserProperties.Administrators;
	
	FullAdministratorRoleName = Users.FullAdministratorRole().Name;
	AdministratorRoles = New Map;
	AdministratorRoles.Insert("FullAccess", True);
	If Not CommonUseCached.DataSeparationEnabled() Then
		If FullAdministratorRoleName <> "FullAccess" Then
			AdministratorRoles.Insert(FullAdministratorRoleName, True);
		EndIf;
	EndIf;
	
	// Expected result after the loop ends
	NewInfobaseAdministrators  = New Map;
	UpdatedInfobaseUsers       = New Map;
	
	For Each UserDetails In InfobaseUserIDs Do
		
		CurrentUser              = UserDetails.User;
		InfobaseUserID           = UserDetails.InfobaseUserID;
		NewInfobaseAdministrator = False;
		
		Cancel = False;
		Handlers = CommonUse.InternalEventHandlers("StandardSubsystems.AccessManagement\OnInfobaseUserRoleUpdate");
		For Each Handler In Handlers Do
			Handler.Module.OnInfobaseUserRoleUpdate(InfobaseUserID, Cancel);
		EndDo;
		If Cancel Then
			Continue;
		EndIf;
		
		// Searching for an infobase user<?xml:namespace prefix = o ns = "urn:schemas-microsoft-com:office:office" /><o:p></o:p>
		If TypeOf(InfobaseUserID) = Type("UUID") Then
			IBUser = InfobaseUsers.FindByUUID(
				InfobaseUserID);
		Else
			IBUser = Undefined;
		EndIf;
		
		OldRoles = Undefined;
		
		If IBUser <> Undefined And ValueIsFilled(IBUser.Name) Then
			
			NewRoles = NewUserRoles.Copy(NewUserRoles.FindRows(
				New Structure("User", CurrentUser)), "Role");
			
			NewRoles.Indexes.Add("Role");
			
			// Checking old roles
			OldRoles          = New Map;
			RolesForAdding    = New Map;
			RolesForDeletion  = New Map;
			
			If Administrators[CurrentUser] = Undefined Then
				For Each Role In IBUser.Roles Do
					RoleName = Role.Name;
					OldRoles.Insert(RoleName, True);
					If NewRoles.Find(RoleName, "Role") = Undefined Then
						RolesForDeletion.Insert(RoleName, True);
					EndIf;
				EndDo;
			Else // Administrator
				For Each Role In IBUser.Roles Do
					RoleName = Role.Name;
					OldRoles.Insert(RoleName, True);
					If AdministratorRoles[RoleName] = Undefined Then
						RolesForDeletion.Insert(RoleName, True);
					EndIf;
				EndDo;
				
				For Each KeyAndValue In AdministratorRoles Do
					
					If OldRoles[KeyAndValue.Key] = Undefined Then
						RolesForAdding.Insert(KeyAndValue.Key, True);
						
						If KeyAndValue.Key = FullAdministratorRoleName Then
							NewInfobaseAdministrator = True;
						EndIf;
					EndIf;
				EndDo;
			EndIf;
			
			// Checking new roles
			For Each Row In NewRoles Do
				
				If OldRoles = Undefined
				 Or Administrators[CurrentUser] <> Undefined Then
					Continue;
				EndIf;
				
				If OldRoles[Row.Role] = Undefined Then
					If AllRoles.Get(Row.Role) <> Undefined Then
					
						RolesForAdding.Insert(Row.Role, True);
						
						If Row.Role = FullAdministratorRoleName Then
							NewInfobaseAdministrator = True;
						EndIf;
					Else
						// New roles (roles not found in the metadata)
						Profiles = UserWithRoleProfiles(CurrentUser, Row.Role);
						For Each Profile In Profiles Do
							WriteLogEvent(
								NStr("en = 'Access management.A role is not found in the metadata'",
								     CommonUseClientServer.DefaultLanguageCode()),
								EventLogLevel.Error,
								,
								,
								StringFunctionsClientServer.SubstituteParametersInString(
									NStr("en= 'When updating the user ""%1"",
									          |role ""%2""
									          |of access group profile ""%3"" 
									          |is not found in the metadata.'"),
									String(CurrentUser),
									Row.Role,
									String(Profile)),
								EventLogEntryTransactionMode.Transactional);
						EndDo;
					EndIf;
				EndIf;
			EndDo;
			
		EndIf;
		
		// Completing the current user processing
		If OldRoles <> Undefined
		   And (  RolesForAdding.Count() <> 0
			  Or RolesForDeletion.Count() <> 0) Then
			
			RoleChanges = New Structure;
			RoleChanges.Insert("UserRef", CurrentUser);
			RoleChanges.Insert("IBUser",     IBUser);
			RoleChanges.Insert("RolesForAdding",  RolesForAdding);
			RoleChanges.Insert("RolesForDeletion",    RolesForDeletion);
			
			If NewInfobaseAdministrator Then
				NewInfobaseAdministrators.Insert(CurrentUser, RoleChanges);
			Else
				UpdatedInfobaseUsers.Insert(CurrentUser, RoleChanges);
			EndIf;
			
			HasChanges = True;
		EndIf;
	EndDo;
	
	// Adding new administrators
	UpdateInfobaseUserRoles(NewInfobaseAdministrators, ServiceUserPassword);
	
	// Deleting old administrators, updating other users
	UpdateInfobaseUserRoles(UpdatedInfobaseUsers, ServiceUserPassword);
	
EndProcedure

// Checking the Administrators access group before writing
Procedure CheckAdministratorsAccessGroupForInfobaseUser(GroupUsers, ErrorDescription) Export
	
	Users.FindAmbiguousInfobaseUsers();
	
	// Checking the empty list of infobase users in the Administrators access group
	SetPrivilegedMode(True);
	ValidAdministratorFound = False;
	
	For Each UserDetails In GroupUsers Do
		
		If ValueIsFilled(UserDetails.User) Then
			
			IBUser = InfobaseUsers.FindByUUID(
				UserDetails.User.InfobaseUserID);
			
			If IBUser <> Undefined
			   And Users.CanLogOnToApplication(IBUser) Then
				
				ValidAdministratorFound = True;
				Break;
			EndIf;
		EndIf;
	EndDo;
	
	If Not ValidAdministratorFound Then
		ErrorDescription =
			NStr("en = 'Administrators access group must include at least
			           |one user allowed to log on to the application.'");
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// SL event handlers

// Adds update handlers that are required by the subsystem.
//
// Parameters:
//  Handlers - ValueTable - see the description of NewUpdateHandlerTable function
//                          in the InfobaseUpdate common module.
// 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	// Shared data update handlers.
	Handler = Handlers.Add();
	Handler.SharedData = True;
	Handler.HandlerManagement = True;
	Handler.Priority = 1;
	Handler.Version = "*";
	Handler.ExclusiveMode = True;
	Handler.Procedure = "AccessManagementInternal.FillSeparatedDataHandlers";
	
	// Separated data update handlers.
	Handler = Handlers.Add();
	Handler.Version = "*";
	Handler.ExclusiveMode = True;
	Handler.Procedure = "AccessManagementInternal.UpdateAuxiliaryRegisterDataByConfigurationChanges";
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.2.8";
	Handler.Procedure = "InformationRegisters.DELETE.MoveDataToNewRegister";
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.2.8";
	Handler.Procedure = "AccessManagementInternal.ConvertRoleNamesToIDs";
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.2.8";
	Handler.Procedure = "InformationRegisters.AccessValueGroups.RefreshUserGrouping";
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.2.16";
	Handler.Procedure = "InformationRegisters.AccessGroupTables.UpdateRegisterData";
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.2.16";
	Handler.Procedure = "AccessManagement.UpdateUserRoles";
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.3.5";
	Handler.Procedure = "InformationRegisters.AccessValueGroups.RefreshUserGrouping";
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.4.15";
	Handler.Procedure = "Catalogs.AccessGroupProfiles.FillSuppliedDataIDs";
	Handler.ExecuteInMandatoryGroup = True;
	Handler.Priority = 1;
	
	// Must be executed after the FillSuppliedDataIDs handler
	Handler = Handlers.Add();
	Handler.InitialFilling = True;
	Handler.Procedure = "Catalogs.AccessGroups.FillAccessGroupProfileAdministrators";
	Handler.ExecutionMode = "Exclusive";
	Handler.ExecuteInMandatoryGroup = True;
	Handler.Priority = 1;
	
	Handler = Handlers.Add();
	Handler.Version = "2.2.1.15";
	Handler.Procedure = "Catalogs.AccessGroupProfiles.ConvertAccessKindsIDs";
	Handler.ExecutionMode = "Exclusive";
	Handler.ExecuteInMandatoryGroup = True;
	Handler.Priority = 1;
	
	Handler = Handlers.Add();
	Handler.Version = "2.2.1.15";
	Handler.Procedure = "InformationRegisters.AccessValueGroups.RefreshUserGrouping";
	Handler.ExecutionMode = "Exclusive";
	
	Handler = Handlers.Add();
	Handler.Version = "2.2.1.15";
	Handler.Procedure = "InformationRegisters.AccessGroupValues.UpdateRegisterData";
	Handler.ExecutionMode = "Exclusive";
	
	Handler = Handlers.Add();
	Handler.Version = "2.2.1.15";
	Handler.Procedure = "InformationRegisters.DELETE.MoveDataToNewRegister";
	Handler.ExecutionMode = "Exclusive";
	
	Handler = Handlers.Add();
	Handler.Version = "2.2.1.15";
	Handler.Procedure = "InformationRegisters.ObjectRightsSettingsInheritance.UpdateRegisterData";
	Handler.ExecutionMode = "Exclusive";
	
	Handler = Handlers.Add();
	Handler.Version = "2.2.1.15";
	Handler.Procedure = "InformationRegisters.ObjectRightsSettings.UpdateAuxiliaryRegisterData";
	Handler.ExecutionMode = "Exclusive";
	
	Handler = Handlers.Add();
	Handler.Version = "2.2.1.15";
	Handler.Procedure = "AccessManagementInternal.EnableDataFillingForAccessRestriction";
	Handler.ExecutionMode = "Exclusive";
	
	Handler = Handlers.Add();
	Handler.Version = "2.2.1.35";
	Handler.Procedure = "InformationRegisters.AccessValueGroups.RefreshAccessValueEmptyGroups";
	Handler.ExecutionMode = "Nonexclusive";
	
EndProcedure

// Returns the mapping between session parameter names and their initialization handlers.
//
Procedure SessionParameterSettingHandlersOnAdd(Handlers) Export
	
	Handlers.Insert("AccessKinds*",
		"AccessManagementInternal.SessionParametersSetting");
	
	Handlers.Insert("AllAccessKindsExceptSpecial",
		"AccessManagementInternal.SessionParametersSetting");
	
	Handlers.Insert("TablesWithIndividualRightSettings",
		"AccessManagementInternal.SessionParametersSetting");
	
	Handlers.Insert("AccessValueTypesWithGroups",
		"AccessManagementInternal.SessionParametersSetting");
	
	Handlers.Insert("RightsSettingsOwnerTypes",
		"AccessManagementInternal.SessionParametersSetting");
	
	Handlers.Insert("IDsOfTablesWithSpecificRightSettings",
		"AccessManagementInternal.SessionParametersSetting");
	
EndProcedure

// Fills the parameter structures required by the configuration client code.
//
// Parameters:
//   Parameters   - Structure - parameter structure.
//
Procedure StandardSubsystemClientLogicParametersOnAdd(Parameters) Export
	
	AddClientParameters(Parameters);
	
EndProcedure

// Fills an array with metadata object names that might include references to other
// metadata objects, but these references are ignored in the application business logic.
//
// Parameters:
//  Array       - array of strings, for example, "InformationRegister.ObjectVersions".
//
Procedure OnAddReferenceSearchException(Array) Export
	
	Array.Add(Metadata.InformationRegisters.AccessValueGroups.FullName());
	Array.Add(Metadata.InformationRegisters.AccessRightDependencies.FullName());
	Array.Add(Metadata.InformationRegisters.AccessGroupValues.FullName());
	Array.Add(Metadata.InformationRegisters.DefaultAccessGroupValues.FullName());
	Array.Add(Metadata.InformationRegisters.AccessValueSets.FullName());
	Array.Add(Metadata.InformationRegisters.RoleRights.FullName());
	Array.Add(Metadata.InformationRegisters.ObjectRightsSettingsInheritance.FullName());
	Array.Add(Metadata.InformationRegisters.ObjectRightsSettings.FullName());
	Array.Add(Metadata.InformationRegisters.AccessGroupTables.FullName());
	
EndProcedure

// This procedure is called when importing predefined item references while importing important data.
// Allows executing actions to fix or register details on
// non-unique predefined items. Also allows you to cancel the import if the uniqueness problem cannot be solved.
//
// Parameters:
//   Object          - CatalogObject, ChartOfCharacteristicTypesObject, ChartOfAccountsObject, ChartOfCalculationTypesObject -
//                     written predefined item object that led to a uniqueness conflict.
//   WriteToLog - Boolean - return value. Set to False to add the uniqueness conflict
//                     details to the event log in a common message.
//                     Set to False if the uniqueness conflict has been fixed automatically.
//   Cancel           - Boolean - return value. Set to True to raise an
//                     exception with cancellation details.
//   CancellationDetails  - String - return value. If Cancel is set to True, the description
//                     is added to the list of the reasons prohibiting further import.
//
Procedure NotUniquePredefinedItemFound(Object, WriteToLog, Cancel, CancellationDetails) Export
	
	If TypeOf(Object) = Type("CatalogObject.AccessGroupProfiles")
	   And Object.PredefinedDataName = "Administrator" Then
		
		WriteToLog = False;
		
		Query = New Query;
		Query.SetParameter("Ref", Object.Ref);
		Query.SetParameter("PredefinedDataName", "Administrator");
		Query.Text =
		"SELECT
		|	AccessGroupProfiles.Ref AS Ref
		|FROM
		|	Catalog.AccessGroupProfiles AS AccessGroupProfiles
		|WHERE
		|	AccessGroupProfiles.Ref <> &Ref
		|	AND AccessGroupProfiles.PredefinedDataName = &PredefinedDataName";
		
		Selection = Query.Execute().Select();
		While Selection.Next() Do
			CurrentObject = Selection.Ref.GetObject();
			CurrentObject.PredefinedDataName = "";
			CurrentObject.SuppliedDataID = "";
			InfobaseUpdate.WriteData(CurrentObject);
		EndDo;
		
	ElsIf TypeOf(Object) = Type("CatalogObject.AccessGroups")
	        And Object.PredefinedDataName = "Administrators" Then
		
		WriteToLog = False;
		
		Query = New Query;
		Query.SetParameter("PredefinedDataName", "Administrators");
		Query.Text =
		"SELECT DISTINCT
		|	AccessGroupsUsers.User
		|FROM
		|	Catalog.AccessGroups.Users AS AccessGroupsUsers
		|WHERE
		|	AccessGroupsUsers.Ref.PredefinedDataName = &PredefinedDataName";
		AllUsers = Query.Execute().Unload().UnloadColumn("User");
		
		Write = False;
		For Each User In AllUsers Do
			If Object.Users.Find(User, "User") = Undefined Then
				Object.Users.Add().User = User;
				Write = True;
			EndIf;
		EndDo;
		
		If Write Then
			InfobaseUpdate.WriteData(Object);
		EndIf;
		
		Query.SetParameter("Ref", Object.Ref);
		Query.Text =
		"SELECT
		|	AccessGroups.Ref AS Ref
		|FROM
		|	Catalog.AccessGroups AS AccessGroups
		|WHERE
		|	AccessGroups.Ref <> &Ref
		|	AND AccessGroups.PredefinedDataName = &PredefinedDataName";
		
		Selection = Query.Execute().Select();
		While Selection.Next() Do
			CurrentObject = Selection.Ref.GetObject();
			CurrentObject.PredefinedDataName = "";
			InfobaseUpdate.WriteData(CurrentObject);
		EndDo;
	EndIf;
	
EndProcedure

// Handler for the event of the same name that occurs during data exchange in a distributed infobase.
//
// Parameters:
// see the description of OnReceiveDataFromMaster() event handler in the Syntax Assistant.
// 
Procedure OnReceiveDataFromMaster(DataItem, ItemReceive, SendBack, Sender) Export
	
	If ItemReceive = DataItemReceive.Ignore Then
		// Standard processing cannot be overridden
	Else
		// Administrators are set in all subordinate DIB nodes independently
		If TypeOf(DataItem) = Type("CatalogObject.AccessGroups") Then
			Catalogs.AccessGroups.RestoreParticipantCompositionOfAdministratorsAccessGroup(DataItem, SendBack);
		EndIf;
	EndIf;
	
EndProcedure

// Handler for the event of the same name that occurs during data exchange in a distributed infobase.
//
// Parameters:
// see the description of OnReceiveDataFromSlave() event handler in the Syntax Assistant.
// 
Procedure OnReceiveDataFromSlave(DataItem, ItemReceive, SendBack, Sender) Export
	
	If ItemReceive = DataItemReceive.Ignore Then
		// Standard processing cannot be overridden
		
	ElsIf Not CommonUseCached.DataSeparationEnabled() Then
		
		// Administrators are set in all subordinate DIB nodes independently
		If TypeOf(DataItem) = Type("CatalogObject.AccessGroups") Then
			Catalogs.AccessGroups.RestoreParticipantCompositionOfAdministratorsAccessGroup(DataItem, SendBack);
		EndIf;
		
	ElsIf TypeOf(DataItem) = Type("ConstantValueManager.UseRecordLevelSecurity")
	      Or TypeOf(DataItem) = Type("CatalogObject.AccessGroups")
	      Or TypeOf(DataItem) = Type("CatalogObject.AccessGroupProfiles")
	      Or TypeOf(DataItem) = Type("InformationRegisterRecordSet.AccessValueGroups")
	      Or TypeOf(DataItem) = Type("InformationRegisterRecordSet.AccessGroupValues")
	      Or TypeOf(DataItem) = Type("InformationRegisterRecordSet.AccessValueSets")
	      Or TypeOf(DataItem) = Type("InformationRegisterRecordSet.ObjectRightsSettings")
	      Or TypeOf(DataItem) = Type("InformationRegisterRecordSet.AccessGroupTables") Then
		
		// Getting data from a standalone workstation is skipped.
		// Data is sent back to the standalone workstation to establish data mapping between the nodes.
		ItemReceive = DataItemReceive.Ignore;
		SendBack = True;
	EndIf;
	
EndProcedure

// Handler of the event that occurs in the master mode after receiving data from a subordinate DIB node.
// The procedure is called after the exchange message is read, when all data from the exchange message is read and written to the infobase.
// 
//  Parameters:
// Sender - ExchangePlanObject. Exchange plan node object that sent the data.
// Cancel - Boolean. Cancellation flag. if True, the message
// is not considered to be received. Also the data import transaction
// is rolled back (if all data was imported in a single transaction), or the
// last data import transaction is rolled back (if the data was imported in portions).
//
Procedure DataFromSubordinateAfterReceive(Sender, Cancel) Export
	
	DataAfterReceive(Sender, Cancel, True);
	
EndProcedure

// Handler of the event that occurs in the subordinate node after receiving data from the master DIB node.
// The procedure is called after the exchange message is read, when all data from the exchange message is read and written to the infobase.
// 
//  Parameters:
// Sender - ExchangePlanObject. Exchange plan node object that sent the data.
// Cancel - Boolean. Cancellation flag. if True, the message
// is not considered to be received. Also the data import transaction
// is rolled back (if all data was imported in a single transaction), or the
// last data import transaction is rolled back (if the data was imported in portions).
//
Procedure DataFromMasterAfterReceive(Sender, Cancel) Export
	
	DataAfterReceive(Sender, Cancel, False);
	
EndProcedure

// The procedure is used when getting metadata objects that are mandatory for the exchange plan.
// If the subsystem includes metadata objects that must be included in
// the exchange plan content, add these metadata objects to the Objects parameter.
//
// Parameters:
// Objects - Array. The array of configuration metadata objects that must be included in the exchange plan content.
// DistributedInfobase (read only) - Boolean - flag that shows whether DIB exchange plan objects are retrieved.
// True if a list of DIB exchange plan objects is retrieved;
// False if a list of non-DIB exchange plan objects is retrieved.
//
Procedure OnGetMandatoryExchangePlanObjects(Objects, Val DistributedInfobase) Export
	
	If DistributedInfobase Then
		
		Objects.Add(Metadata.Constants.AccessRestrictionParameters);
		Objects.Add(Metadata.InformationRegisters.RoleRights);
		Objects.Add(Metadata.InformationRegisters.AccessRightDependencies);
		
	EndIf;
	
EndProcedure

// The procedure is used for getting metadata objects that must be
// included in the exchange plan content but NOT included in the change record event subscriptions of this exchange plan.
// These metadata objects are used only when creating the initial image
// of a subordinate node and are not transferred during the exchange.
// If the subsystem includes metadata objects used only for creating the initial image
// of a subordinate node, add these metadata objects to the Objects parameter.
//
// Parameters:
// Objects - Array. metadata object array.
//
Procedure OnGetExchangePlanInitialImageObjects(Objects) Export
	
	Objects.Add(Metadata.Constants.AccessRestrictionParameters);
	Objects.Add(Metadata.InformationRegisters.AccessRightDependencies);
	Objects.Add(Metadata.InformationRegisters.RoleRights);
	
EndProcedure

// Events handlers of the Users subsystem.

// Overrides the standard method of assigning roles to infobase users.
//
// Parameters:
//  Prohibition - Boolean. If True, prohibits role
//           modification by any user (including administrator).
//
Procedure OnDefineRoleEditProhibition(Prohibition) Export
	
	// Roles are set automatically by linking the access group data this way:
	// AccessGroupUsers -> Profile -> ProfileRoles.
	Prohibition = True;
	
EndProcedure

// Overrides the behavior of user form,
// external user form, and external user group form.
//
// Parameters:
//  Ref - CatalogRef.Users,
//           CatalogRef.ExternalUsers,
//           CatalogRef.ExternalUserGroups
//           - reference to the user, external user,
//           or external user group during form creation.
//
//  ActionsOnForm - Structure of String values.:
//           Role                   = "", "View", "Edit".
//           ContactInformation     = "", "View", "Edit".
//           InfobaseUserProperties = "", "ViewAll", "EditAll", "EditOwn".
//           ItemProperties         = "", "View", "Edit".
//           
//           ContactInformation and InfobaseUserProperties do not exist for external user groups.
//
Procedure OnDefineActionsInForm(Ref, ActionsOnForm) Export
	
	ActionsOnForm.Roles = "";
	
EndProcedure

// Overrides the text of the question that is asked before writing the first administrator.
//  The procedure is called from the BeforeWrite handler in the user form.
//  The procedure is called if
// RoleEditProhibition() is set and the number of infobase users is zero.
// 
Procedure OnDefineQuestionTextBeforeWriteFirstAdministrator(QuestionText) Export
	
	QuestionText = NStr("en = 'The first user to be added to the application user list<o:p></o:p>
		|will automatically be added to the Administrators access group. 
		|Do you want to continue?'")
	
EndProcedure

// Redefines actions performed when
// a user is written together with an infobase user with FullAccess role.
// 
// Parameters:
//  User - CatalogRef.Users (prohibite to change an object).
//
Procedure OnWriteAdministrator(User) Export
	
	// Administrators are automatically added to Administrators access group.
	If PrivilegedMode() Then
		Object = Catalogs.AccessGroups.Administrators.GetObject();
		If Object.Users.Find(User, "User") = Undefined Then
			Object.Users.Add().User = User;
			InfobaseUpdate.WriteData(Object);
		EndIf;
	EndIf;
	
EndProcedure

// Event handlers of ReportOptions subsystem.

// Contains the settings of report option placement in the report panel.
//   
// Parameters:
//   Settings - Collection - used to describe report settings and
//       report options. See the description of ReportOptions.ConfigurationReportOptionSettingsTree().
//   
// Description:
//   This procedure specifies how predefined report options
//   are registered and displayed in the report panel.
//   
// Auxiliary methods:
//   ReportSettings   = ReportOptions.ReportDetails(Settings, Metadata.Reports.<ReportName>);
//   OptionSettings = ReportOptions.OptionDetails(Settings, ReportSettings, "<OptionName>");
//   
//   The functions get report settings and report option settings that have the following structure:
//       * Enabled - Boolean -
//           If False, the report option is not registered in the subsystem.
//           It is used for deletion of auxiliary and context-dependent report options from all interfaces.
//           These report options can still be opened in the report form, provided
//           that it is opened with parameters from 1C:Enterprise script (see Help for "Managed form extension for reports.VariantKey").
//       DefaultVisibility - Boolean -
//           If False, the report option is hidden from the report panel by default.
//           The user can enable it in the report
//           panel settings or open it from the All reports form.
//       * Details - String - Additional information on the report option.
//           It is displayed as a tooltip in the report panel.
//           It explains the report option purpose
//           to the user and should not duplicate the name of the report option.
//       * Location - Map - Settings that describe report option availability in sections.
//           ** Key   - MetadataObject: Subsystem - Subsystem where a report or
//                      a report option is available.
//           ** Value - String - Optional. Position in the subsystem interface.
//               ""          - Shows report in its group in regular font.
//               "Important" - Shows report in its group in bold.
//               "SeeAlso"   - Shows report in the See also group.
//       * FunctionalOptions - Array with elements of the String type -
//            Names of report option functional options.
//   
// For example:
//   
//  (1) Add report option to a subsystem.
// Option = ReportOptions.OptionDetails(Settings, Metadata.Reports.ReportName, "OptionName1");
// Option.Location.Insert(Metadata.Subsystems.SectionName.Subsystems.SubsystemName);
//   
//  (2) Disable report option.
// Option = ReportOptions.OptionDetails(Settings, Metadata.Reports.ReportName, "OptionName1");
// Option.Enabled = False;
//   
//  (3) Disable all report options except the specified report option.
// Report = ReportOptions.ReportDetails(Settings, Metadata.Reports.ReportName);
// Report.Enabled = False;
// Option = ReportOptions.OptionDetails(Settings, Report, "OptionName");
// Option.Enabled = True;
//   
//  (4) 4.1 and 4.2 have the same result:
//  (4.1)
// Report = ReportOptions.ReportDetails(Settings, Metadata.Reports.ReportName);
// Option = ReportOptions.OptionDetails(Settings, Report, "OptionName1");
// Option.Location.Delete(Metadata.Subsystems.SectionName.Subsystems.SubsystemName);
// Option = ReportOptions.OptionDetails(Settings, Report, "OptionName2");
// Option.Location.Delete(Metadata.Subsystems.SectionName.Subsystems.SubsystemName);
// Option = ReportOptions.OptionDetails(Settings, Report, "OptionName3");
// Option.Location.Delete(Metadata.Subsystems.SectionName.Subsystems.SubsystemName);
//   
//  (4.2)
// Report = ReportOptions.ReportDetails(Settings, Metadata.Reports.ReportName);
// Report.Location.Delete(Metadata.Subsystems.SectionName.Subsystems.SubsystemName);
// ReportOptions.OptionDetails(Settings, Report, "OptionName1");
// ReportOptions.OptionDetails(Settings, Report, "OptionName2");
// ReportOptions.OptionDetails(Settings, Report, "OptionName3");
// Report.Location.Insert(Metadata.Subsystems.SectionName.Subsystems.SubsystemName);
//   
// Important:
//   A report serves as a container for report options.
//     You can change the settings of all report options by modifying the report settings.
//     If report option settings are retrieved explicitly, they
//     become independent (meaning that they no longer inherit settings changes from the report). See examples 3 and 4.
//   
//   Initial report availability in the subsystems is read
//     from the metadata, duplicating this in the script is not required.
//   
//   Report option functional options are combined with report functional options
//   according to the following rules:
//     (ReportFunctionalOption1 OR ReportFunctionalOption2) AND
//      OptionFunctionalOption3 OR OptionFunctionalOption4).
//   Report functional options are not retrieved from the metadata,
//     they are applied when a user accesses a subsystem.
//   Functional options can be added from ReportDetails. Such functional options
//     are also combined according to the rules described above, but they only have
//     effect for the report predefined report options.
//   Only report functional options are in effect for user report options.
//     They can be disabled only by disabling the entire report.
//
Procedure ReportOptionsOnSetup(Settings) Export
	ReportOptionsModule = CommonUse.CommonModule("ReportOptions");
	ReportOptionsModule.SetupReportInManagerModule(Settings, Metadata.Reports.AccessRights);
EndProcedure

// Events handlers of CloudTechnology library.

// Fills the array of shared data types that do not
// require reference mapping during data import to another infobase, as the
// correct reference mapping is provided by other algorithms.
//
// Parameters:
//  Types - Array of MetadataObject
//
Procedure OnFillCommonDataTypesDoNotRequireMappingRefsOnImport(Types) Export
	
EndProcedure

// Fills the array of types excluded from data import and export.
//
// Parameters:
//  Types - Array(Types).
//
Procedure OnFillExcludedFromImportExportTypes(Types) Export
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Event subscription handlers

// UpdateAccessValueGroups subscription handler reacts to the BeforeWrite event by calling:
// - a method for recording the access value groups to InformationRegister.AccessValueGroups for required metadata objects;
// - a method for recording the object right settings owner hierarchy to InformationRegister.ObjectRightsSettingsInheritance for required metadata objects.
//
Procedure UpdateAccessValueGroups(Val Object, Cancel) Export
	
	If Object.DataExchange.Load Then
		Return;
	EndIf;
	
	Parameters = AccessManagementInternalCached.Parameters();
	AccessValuesWithGroups = Parameters.AccessKindsProperties.AccessValuesWithGroups;
	AvailableRightsByTypes    = Parameters.AvailableRightsForObjectRightsSettings.ByTypes;
	
	If AccessValuesWithGroups.ByTypes.Get(TypeOf(Object)) <> Undefined Then
		InformationRegisters.AccessValueGroups.UpdateAccessValueGroups(Object);
	EndIf;
	
	If AvailableRightsByTypes.Get(TypeOf(Object)) <> Undefined Then
		InformationRegisters.ObjectRightsSettingsInheritance.UpdateRegisterData(Object);
	EndIf;
	
EndProcedure

// The WriteAccessValueSets subscription handler reacts to
// the OnWrite event by calling the method used for recording object access value to InformationRegister.AccessValueSets.
//  "AccessManagement" subsystem can be
// used when the specified subscription does not exist if the access value sets are not applied.
//
Procedure WriteAccessValueSetsOnWrite(Val Object, Cancel) Export

	If Object.DataExchange.Load
	   And Not Object.AdditionalProperties.Property("WriteAccessValueSets") Then
		
		Return;
	EndIf;
	
	WriteAccessValueSets(Object);
	
EndProcedure

// WriteDependentAccessValueSets subscription handler
// reacts to the OnWrite event by overwriting the dependent access value sets in the AccessValueSets information register.
//
//  "AccessManagement" subsystem can be
// used when the specified subscription does not exist if the dependent access value sets are not applied.
//
Procedure WriteDependentAccessValueSetsOnWrite(Val Object, Cancel) Export
	
	If Object.DataExchange.Load
	   And Not Object.AdditionalProperties.Property("WriteDependentAccessValueSets") Then
		
		Return;
	EndIf;
	
	WriteDependentAccessValueSets(Object);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Scheduled job handlers

// DataFillingForAccessRestrictions scheduled job handler.
Procedure DataFillingForAccessRestrictionsJobHandler() Export
	
	CommonUse.ScheduledJobOnStart();
	
	DataFillingForAccessRestrictions();
	
EndProcedure

// Executes consecutive filling and updating of data
// required for AccessManagements subsystem operation in the access restriction mode at a record level.
// 
//  When the access restriction mode is enabled at
// record level, access value sets are filled. A portion of access value sets is filled on each
// startup, until all access value sets are filled.
//  When the restriction access mode is disabled at record
// level, the access value sets filled earlier are removed only when overwriting objects, not immediately.
//  The procedure updates the cache attributes on the record level regardless of the access restriction mode.
//  Once all data filling and data update operations are completed, the procedure disables the scheduled job.
//
//  Procedure progress information is written to the event log.
//
//  The procedure can be called from 1C:Enterprise script, for example, during infobase update.
// For data update purposes, the Catalog.AccessGroups.UpdateDataRestrictionAccess form is also available. This form can be used for interactive

// update of access restriction data when updating infobase.
//
Procedure DataFillingForAccessRestrictions(DataVolume = 0, OnlyCacheAttributes = False, HasChanges = Undefined) Export
	
	SetPrivilegedMode(True);
	
	Parameters = AccessManagementInternalCached.Parameters();
	AccessValuesWithGroups = Parameters.AccessKindsProperties.AccessValuesWithGroups;
	
	If AccessManagement.UseRecordLevelSecurity() And Not OnlyCacheAttributes Then
		
		// Filling the access value groups in the AccessValueGroups information register
		For Each TableName In AccessValuesWithGroups.TableNames Do
			
			If DataVolume < 10000 Then
				
				Query = New Query;
				Query.Text =
				"SELECT TOP 10000
				|	CurrentTable.Ref AS Ref
				|FROM
				|	&CurrentTable AS CurrentTable
				|		LEFT JOIN InformationRegister.AccessValueGroups AS AccessValueGroups
				|		ON CurrentTable.Ref = AccessValueGroups.AccessValue
				|			AND (AccessValueGroups.DataGroup = 0)
				|WHERE
				|	AccessValueGroups.AccessValue IS NULL ";
				
				Query.Text = StrReplace(Query.Text, "&CurrentTable", TableName);
				Values = Query.Execute().Unload().UnloadColumn("Ref");
				
				InformationRegisters.AccessValueGroups.UpdateAccessValueGroups(Values, HasChanges);
				
				DataVolume = DataVolume + Values.Count();
			EndIf;
			
		EndDo;
		
		If DataVolume < 10000 Then
			
			// Filling the AccessValueSets information register
			ObjectTypes = AccessManagementInternalCached.ObjectTypesInEventSubscriptions(
				"WriteAccessValueSets");
			
			For Each TypeDescription In ObjectTypes Do
				Type = TypeDescription.Key;
				
				If DataVolume < 10000 And Type <> Type("String") Then
				
					Query = New Query;
					Query.Text =
					"SELECT TOP 10000
					|	CurrentTable.Ref AS Ref
					|FROM
					|	&CurrentTable AS CurrentTable
					|		LEFT JOIN InformationRegister.AccessValueSets AS InformationRegisterAccessValueSets
					|		ON CurrentTable.Ref = InformationRegisterAccessValueSets.Object
					|WHERE
					|	InformationRegisterAccessValueSets.Object IS NULL ";
					Query.Text = StrReplace(Query.Text, "&CurrentTable", Metadata.FindByType(Type).FullName());
					Selection = Query.Execute().Select();
					DataVolume = DataVolume + Selection.Count();
					
					While Selection.Next() Do
						UpdateAccessValueSets(Selection.Ref, HasChanges);
					EndDo;
				EndIf;
			EndDo;
		EndIf;
	EndIf;
	
	// Updating cache attributes in the access value sets
	If DataVolume < 10000 Then
		
		AccessValueTypes          = Parameters.AccessKindsProperties.ByValueTypes;
		AccessValueTypesWithGroups = Parameters.AccessKindsProperties.AccessValueTypesWithGroups;
		
		ValueTypeTable = New ValueTable;
		ValueTypeTable.Columns.Add("ValueType", Metadata.DefinedTypes.AccessValue.Type);
		For Each KeyAndValue In AccessValueTypes Do
			ValueTypeTable.Add().ValueType = MetadataObjectEmptyRef(KeyAndValue.Key);
		EndDo;
		
		TableOfValueTypesWithGroups = New ValueTable;
		TableOfValueTypesWithGroups.Columns.Add("ValueType", Metadata.DefinedTypes.AccessValue.Type);
		For Each KeyAndValue In AccessValueTypesWithGroups Do
			TableOfValueTypesWithGroups.Add().ValueType = MetadataObjectEmptyRef(KeyAndValue.Key);
		EndDo;
		
		Query = New Query;
		Query.SetParameter("ValueTypeTable", ValueTypeTable);
		Query.SetParameter("TableOfValueTypesWithGroups", TableOfValueTypesWithGroups);
		Query.Text =
		"SELECT
		|	TableTypes.ValueType
		|INTO ValueTypeTable
		|FROM
		|	&ValueTypeTable AS TableTypes
		|
		|INDEX BY
		|	TableTypes.ValueType
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TableTypes.ValueType
		|INTO TableOfValueTypesWithGroups
		|FROM
		|	&TableOfValueTypesWithGroups AS TableTypes
		|
		|INDEX BY
		|	TableTypes.ValueType
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT TOP 10000
		|	AccessValueSets.Object,
		|	AccessValueSets.SetNumber,
		|	AccessValueSets.AccessValue,
		|	AccessValueSets.Adjustment,
		|	AccessValueSets.Read,
		|	AccessValueSets.Update
		|FROM
		|	InformationRegister.AccessValueSets AS AccessValueSets
		|WHERE
		|	CASE
		|			WHEN AccessValueSets.StandardValue <> TRUE IN
		|					(SELECT TOP 1
		|						TRUE
		|					FROM
		|						ValueTypeTable AS ValueTypeTable
		|					WHERE
		|						VALUETYPE(ValueTypeTable.ValueType) = VALUETYPE(AccessValueSets.AccessValue))
		|				THEN TRUE
		|			WHEN AccessValueSets.StandardValue = TRUE
		|				THEN AccessValueSets.ValueWithoutGroups = TRUE IN
		|						(SELECT TOP 1
		|							TRUE
		|						FROM
		|							TableOfValueTypesWithGroups AS TableOfValueTypesWithGroups
		|						WHERE
		|							VALUETYPE(TableOfValueTypesWithGroups.ValueType) = VALUETYPE(AccessValueSets.AccessValue))
		|			ELSE AccessValueSets.ValueWithoutGroups = TRUE
		|		END";
		Selection = Query.Execute().Select();
		DataVolume = DataVolume + Selection.Count();
		
		While Selection.Next() Do
			RecordManager = InformationRegisters.AccessValueSets.CreateRecordManager();
			FillPropertyValues(RecordManager, Selection);
			
			AccessValueType = TypeOf(Selection.AccessValue);
			
			If AccessValueTypes.Get(AccessValueType) <> Undefined Then
				RecordManager.StandardValue = True;
				If AccessValueTypesWithGroups.Get(AccessValueType) = Undefined Then
					RecordManager.ValueWithoutGroups = True;
				EndIf;
			EndIf;
			
			RecordManager.Write();
			HasChanges = True;
		EndDo;
	EndIf;
	
	If DataVolume < 10000 Then
		WriteLogEvent(
			NStr("en = 'Access management.Data filling for access restriction'",
				 CommonUseClientServer.DefaultLanguageCode()),
			EventLogLevel.Information,
			,
			,
			NStr("en = 'Data filling for access restriction is completed.'"),
			EventLogEntryTransactionMode.Transactional);
			
		SetDataFillingForAccessRestrictions(False);
	Else
		WriteLogEvent(
			NStr("en = 'Access management.Data filling for access restriction'",
				 CommonUseClientServer.DefaultLanguageCode()),
			EventLogLevel.Information,
			,
			,
			NStr("en = 'A part of data was recorded for access restrictions.'"),
			EventLogEntryTransactionMode.Transactional);
	EndIf;
	
EndProcedure

// Determines usage of a scheduled job intended to fill access management data.
//
// Parameters:
// Use - Boolean - True if the job must be enabled, False otherwise.
//
Procedure SetDataFillingForAccessRestrictions(Val Use) Export
	
	If CommonUseCached.DataSeparationEnabled() Then
		If CommonUse.SubsystemExists("StandardSubsystems.SaaSOperations.AccessManagementSaaS") Then
			AccessManagementInternalSaaSModule = CommonUse.CommonModule("AccessManagementInternalSaaS");
			AccessManagementInternalSaaSModule.SetDataFillingForAccessRestrictions(Use);
		EndIf;
	Else
		Job = ScheduledJobs.FindPredefined(
			Metadata.ScheduledJobs.DataFillingForAccessRestrictions);
		
		If Job.Use <> Use Then
			Job.Use = Use;
			Job.Write();
		EndIf;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions intended for user and user group management

// Updates user groups after updating
// user group content used to check allowed users.
//
// Parameters:
//  ItemsToChange - Array of values of the following types:
//                       - CatalogRef.Users.
//                       - CatalogRef.ExternalUsers.
//                       Users that are included in group content change.
//
//  ModifiedGroups   - Array of values of the following types:
//                       - CatalogRef.UserGroups.
//                       - CatalogRef.ExternalUserGroups.
//                       Groups whose content is changed.
//
Procedure AfterUserGroupContentUpdate(ItemsToChange, ModifiedGroups) Export
	
	Parameters = New Structure;
	Parameters.Insert("Users",      ItemsToChange);
	Parameters.Insert("UserGroups", ModifiedGroups);
	
	InformationRegisters.AccessValueGroups.UpdateUserGrouping(Parameters);
	
EndProcedure

// Updates reference for a new user group (external user group).
//
// Parameters:
//  Ref     - CatalogRef.Users.
//             - CatalogRef.UserGroups.
//             - CatalogRef.ExternalUsers.
//             - CatalogRef.ExternalUserGroups.
//
//  IsNew   - Boolean - if True, the object is added, otherwise the object is changed.
//
Procedure AfterAddUserOrGroupChange(Ref, IsNew) Export
	
	If IsNew Then
		If TypeOf(Ref) = Type("CatalogRef.UserGroups")
		 Or TypeOf(Ref) = Type("CatalogRef.ExternalUserGroups") Then
		
			Parameters = New Structure;
			Parameters.Insert("UserGroups", Ref);
			InformationRegisters.AccessValueGroups.UpdateUserGrouping(Parameters);
		EndIf;
	EndIf;
	
EndProcedure

// Updates external user groups by the authorization object.
//
// Parameters:
//  ExternalUser     - CatalogRef.ExternalUsers.
//  OldAuthorizationObject - NULL - used when adding an external user.
//                            For example, CatalogRef.Individuals.
//  NewAuthorizationObject  - For example, CatalogRef.Individuals.
//
Procedure AfterChangeExternalUserAuthorizationObject(ExternalUser,
                                              OldAuthorizationObject = Undefined,
                                              NewAuthorizationObject) Export
	
	AuthorizationObjects = New Array;
	If OldAuthorizationObject <> NULL Then
		AuthorizationObjects.Add(OldAuthorizationObject);
	EndIf;
	AuthorizationObjects.Add(NewAuthorizationObject);
	
	Parameters = New Structure;
	Parameters.Insert("AuthorizationObjects", AuthorizationObjects);
	
	InformationRegisters.AccessValueGroups.UpdateUserGrouping(Parameters);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions intended for access kind management

// Returns a flag specifying whether an access kind is in use.
// Parameters:
//  AccessKind   - Row, access kind name.
//
// Returns:
//  Boolean.
//
Function AccessKindUsed(Val AccessKind) Export
	
	Used = False;
	
	AccessKindProperties = AccessKindProperties(AccessKind);
	If AccessKindProperties = Undefined Then
		Return Used;
	EndIf;
	
	OMDValueType = Metadata.FindByType(AccessKindProperties.ValueType);
	
	If CommonUse.MetadataObjectEnabledByFunctionalOptions(OMDValueType) Then
		Used = True;
	EndIf;
	
	EventHandlers = CommonUse.InternalEventHandlers(
		"StandardSubsystems.AccessManagement\OnFillAccessKindUse");
	
	For Each Handler In EventHandlers Do
		Handler.Module.OnFillAccessKindUse(AccessKindProperties.Name, Used);
	EndDo;
	
	AccessManagementOverridable.OnFillAccessKindUse(AccessKindProperties.Name, Used);
	
	Return Used;
	
EndFunction

// Returns the properties of an access kind or properties of all access kinds.
//
// Parameters:
//  AccessKind - Ref - an empty main type reference,
//             - String - access kind name,
//             - Undefined - return an array with properties of all access kinds.
//
// Returns:
//  Undefined - when no properties are found for an access kind,
//  is not found,
//  Structure - properties of the found access kind,
//  Array of Structures. For description of properties of these structures, 
//        see the comments to the AccessKindsProperties function
//        in the AccessRestrictionParameters constants manager module.
//
Function AccessKindProperties(Val AccessKind = Undefined) Export
	
	Properties = AccessManagementInternalCached.Parameters().AccessKindsProperties;
	
	If AccessKind = Undefined Then
		Return Properties.Array;
	EndIf;
	
	AccessKindProperties = Properties.ByNames.Get(AccessKind);
	
	If AccessKindProperties = Undefined Then
		AccessKindProperties = Properties.ByLinks.Get(AccessKind);
	EndIf;
	
	Return AccessKindProperties;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions intended for access value set management

// Returns new sets to be used to fill a tabular section.
Function GetAccessValueSetsOfTabularSection(Object) Export
	
	ObjectRef = Object.Ref;
	ValueTypeObject = TypeOf(Object);
	
	If Object.Metadata().TabularSections.Find("AccessValueSets") = Undefined Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Invalid options.
			           |""Access value
			           |sets"" tabular section is not found in the object of type ""%1"".'"),
			ValueTypeObject);
	EndIf;
	
	Table = AccessManagement.AccessValueSetTable();
	
	If Not AccessManagement.UseRecordLevelSecurity() Then
		Return Table;
	EndIf;
	
	AccessManagement.FillAccessValueSets(Object, Table);
	
	AccessManagement.AddAccessValueSets(
		Table, AccessManagement.AccessValueSetTable(), False, True);
	
	Return Table;
	
EndFunction

// Overwrites the access value
// sets of an object in InformationRegister.AccessValueSets,
// using the AccessManagement.FillAccessValueSets() procedure.
//
//  The procedure is called from the AccessManagementInternal.WriteAccessValueSets()
// but it can be called from anywhere,
// for example, when you enable access restrictions at record level.
// applied developer procedure<?xml:namespace prefix = o ns = "urn:schemas-microsoft-com:office:office" /><o:p></o:p>
// Calls the AccessManagementOverridable.OnChangeAccessValueSets(),
// applied developer procedure<o:p></o:p>
// that is used to overwrite the dependent access value sets.
//
// Parameters:
//  Object       - CatalogObject, DocumentObject, ..., or CatalogRef, DocumentRef, ...
//                 The client call can pass only a reference, while an object is required.
//                 The object can be obtained by reference.
//
Procedure WriteAccessValueSets(Val Object, HasChanges = Undefined) Export
	
	SetPrivilegedMode(True);
	
	// If the Object parameter was passed from client
	// to server, then a reference was passed and the object must be obtained by reference.
	Object = ?(Object = Object.Ref, Object.GetObject(), Object);
	ObjectRef = Object.Ref;
	ValueTypeObject = TypeOf(Object);
	
	SetsAreRecorded = AccessManagementInternalCached.ObjectTypesInEventSubscriptions(
		"WriteAccessValueSets").Get(ValueTypeObject) <> Undefined;
	
	If Not SetsAreRecorded Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Incorrect options.
				           |Object type ""%1"" 
				           |is not found in the subscriptions to 
				           |""Write access value sets"" event.'"),
				ValueTypeObject);
	EndIf;
	
	PossibleObjectTypes = AccessManagementInternalCached.TableFieldTypes(
		"InformationRegister.AccessValueSets.Dimension.Object");
	
	If PossibleObjectTypes.Get(TypeOf(ObjectRef)) = Undefined Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Error when recording access value sets:
				           |in AccessValueSets information register,
				           |type ""%1"" is not set in the Object dimension.'"),
				ObjectRef.Metadata().FullName());
	EndIf;
	
	If AccessManagement.UseRecordLevelSecurity() Then
		
		If Metadata.FindByType(ValueTypeObject).TabularSections.Find("AccessValueSets") = Undefined Then
			
			Table = AccessManagement.AccessValueSetTable();
			AccessManagement.FillAccessValueSets(Object, Table);
			
			AccessManagement.AddAccessValueSets(
				Table, AccessManagement.AccessValueSetTable(), False, True);
		Else
			TabularSectionIsFilled = AccessManagementInternalCached.ObjectTypesInEventSubscriptions(
				"FillAccessValueSetsOfTabularSections").Get(ValueTypeObject) <> Undefined;
			
			If Not TabularSectionIsFilled Then
				Raise StringFunctionsClientServer.SubstituteParametersInString(
						NStr("en = 'Incorrect options.
						           |Object type ""%1""
						           |is not found in subscriptions to						                     |""Fill the access values sets of tabular sections"" events.'"),
						ValueTypeObject);
			EndIf;
			// The object with already filled AccessValueSets tabular section is written
			Table = Object.AccessValueSets.Unload();
		EndIf;
		
		PrepareAccessValueSetsForRecord(ObjectRef, Table, True);
		
		FixedFilter = New Structure;
		FixedFilter.Insert("Object", ObjectRef);
		
		BeginTransaction();
		Try
			UpdateRecordSets(
				InformationRegisters.AccessValueSets,
				Table, , , , , , , , ,
				FixedFilter,
				HasChanges);
			
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
		
		If HasChanges = True Then
			OnChangeAccessValueSets(ObjectRef);
		EndIf;
	Else
		Query = New Query(
		"SELECT TOP 1
		|	TRUE AS TrueValue
		|FROM
		|	InformationRegister.AccessValueSets AS AccessValueSets
		|WHERE
		|	AccessValueSets.Object = &ObjectRef");
		
		Query.SetParameter("ObjectRef", ObjectRef);
		
		If Not Query.Execute().IsEmpty() Then
			// Clearing an obsolete set.
			// A new set will be recorded
			// using a scheduled job, after enabling restriction at a record level.
			RecordSet = InformationRegisters.AccessValueSets.CreateRecordSet();
			RecordSet.Filter.Object.Set(ObjectRef);
			RecordSet.Write();
			HasChanges = True;
			
			// Clearing obsolete dependent sets
			OnChangeAccessValueSets(ObjectRef);
		EndIf;
	EndIf;
	
EndProcedure

// Overwrites access value sets of dependent objects.
//
//  The procedure is called from the AccessManagementInternal.WriteDependentAccessValueSets().
// The subscription type content complements (without
// overlapping) the WriteAccessValueSets subscription type content with types that do not require recording sets to the AccessValueSets information register
// but the sets themselves belong in other sets. Example:
// a set of files from the Files catalog may belong in several "Job" business
// processes created on the basis of files; however, recording the file set to the register is not necessary.
//
// Calls the AccessManagementOverridable.OnChangeAccessValueSets(),
// applied developer procedure that is used for
// overwriting the dependent value sets, thus creating recursion.
//
// Parameters:
//  Object       - CatalogObject, DocumentObject, ..., or CatalogRef, DocumentRef, ...
//                 The client call can pass only a reference, while an object is required.
//                 The object can be obtained by reference.
//
Procedure WriteDependentAccessValueSets(Val Object) Export
	
	SetPrivilegedMode(True);
	
	// If the Object parameter was passed from client
	// to server, then a reference was passed and the object must be obtained by reference.
	Object = ?(Object = Object.Ref, Object.GetObject(), Object);
	ObjectRef = Object.Ref;
	ValueTypeObject = TypeOf(Object);
	
	ThisLeadingObject = AccessManagementInternalCached.ObjectTypesInEventSubscriptions(
		"WriteDependentAccessValueSets").Get(ValueTypeObject) <> Undefined;
	
	If Not ThisLeadingObject Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Invalid options.
			           |Object type ""%1"" <?xml:namespace prefix = o ns = ""urn:schemas-microsoft-com:office:office"" /><o:p></o:p>
			           |is not found in subscription to
			           |""Write dependent sets of access values"" event.'"),
			ValueTypeObject);
	EndIf;
	
	OnChangeAccessValueSets(ObjectRef);
	
EndProcedure

// Updates object access values sets if they have been changed.
//  Sets are updated in the tabular section
// (if used) and in the AccessValueSets register information.
//
// Parameters:
//  ObjectRef - CatalogRef, DocumentRef, ...
//
Procedure UpdateAccessValueSets(ObjectRef, HasChanges = Undefined) Export
	
	SetPrivilegedMode(True);
	
	// If the Object parameter was passed from client
	// to server, then a reference was passed and the object must be obtained by reference.
	Object = ObjectRef.GetObject();
	ValueTypeObject = TypeOf(Object);
	
	SetsAreRecorded = AccessManagementInternalCached.ObjectTypesInEventSubscriptions(
		"WriteAccessValueSets").Get(ValueTypeObject) <> Undefined;
	
	If Not SetsAreRecorded Then
		Raise(
			StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Invalid options.
				           |Object type ""%1""
				           |is not found in the subscription to
				           |""Write access value sets"" event.'"),
				ValueTypeObject));
	EndIf;
	
	If Metadata.InformationRegisters.AccessValueSets.Dimensions.Object.Type.Types().Find(TypeOf(ObjectRef)) = Undefined Then
		Raise(
			StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Error when recording access value sets:
				           |in the AccessValueSets information register,
				           |type %1 is not set in the Object dimension'"),
				ObjectRef.Metadata().FullName()));
	EndIf;
	
	If ObjectRef.Metadata().TabularSections.Find("AccessValueSets") <> Undefined Then
		// Object update is required
		Table = GetAccessValueSetsOfTabularSection(Object);
		
		If AccessValueSetsOfTabularSectionChanged(ObjectRef, Table) Then
			PrepareAccessValueSetsForRecord(Undefined, Table, False);
			
			Object.DataExchange.Load = True;
			Object.AdditionalProperties.Insert("WriteAccessValueSets");
			Object.AdditionalProperties.Insert("WriteDependentAccessValueSets");
			Object.AdditionalProperties.Insert("AccessValueSetsOfTabularSectionAreFilled");
			Object.AccessValueSets.Load(Table);
			Object.Write();
			HasChanges = True;
		EndIf;
	EndIf;
	
	// Object update is not required, or it has already been updated
	WriteAccessValueSets(Object, HasChanges);
	
EndProcedure

// Fills auxiliary data that speeds up the access restriction template operations.
//  It is executed before writing to AccessValueSets register.
//
// Parameters:
//  ObjectRef - CatalogRef.*, DocumentRef.*, ...
//  Table        - ValueTable.
//
Procedure PrepareAccessValueSetsForRecord(ObjectRef, Table, AddCacheAttributes = False) Export
	
	If AddCacheAttributes Then
		
		Table.Columns.Add("Object", Metadata.InformationRegisters.AccessValueSets.Dimensions.Object.Type);
		Table.Columns.Add("StandardValue", New TypeDescription("Boolean"));
		Table.Columns.Add("ValueWithoutGroups", New TypeDescription("Boolean"));
		
		Parameters = AccessManagementInternalCached.Parameters();
		
		AccessValueTypesWithGroups = Parameters.AccessKindsProperties.AccessValueTypesWithGroups;
		AccessValueTypes           = Parameters.AccessKindsProperties.ByValueTypes;
		SeparateTables             = Parameters.AvailableRightsForObjectRightsSettings.SeparateTables;
		RightsSettingsOwnerTypes   = Parameters.AvailableRightsForObjectRightsSettings.ByRefTypes;
	EndIf;
	
	// Normalizing Read, Change resources
	SetNumber = -1;
	For Each Row In Table Do
		
		If AddCacheAttributes Then
			// Setting the Object dimension values
			Row.Object = ObjectRef;
			
			AccessValueType = TypeOf(Row.AccessValue);
			
			If AccessValueTypes.Get(AccessValueType) <> Undefined Then
				Row.StandardValue = True;
				If AccessValueTypesWithGroups.Get(AccessValueType) = Undefined Then
					Row.ValueWithoutGroups = True;
				EndIf;
			EndIf;
			
		EndIf;
		
		// Clearing rights and relating secondary data
		// for all rows of each set except the first row
		If SetNumber = Row.SetNumber Then
			Row.Read    = False;
			Row.Update = False;
		Else
			SetNumber = Row.SetNumber;
		EndIf;
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for actions performed on changing subsystem settings

// Enables access restriction data filling and updates<?xml:namespace prefix = o ns = "urn:schemas-microsoft-com:office:office" /><o:p></o:p>
// some data immediately (if necessary).

//
// The procedure is called from the OnWrite handler of the UseRecordLevelSecurity constant.
//
Procedure OnChangeRecordLevelSecurity(RecordLevelSecurityEnabled) Export
	
	SetPrivilegedMode(True);
	
	If RecordLevelSecurityEnabled Then
		
		WriteLogEvent(
			NStr("en = 'Access management.Data filling for access restriction'",
			     CommonUseClientServer.DefaultLanguageCode()),
			EventLogLevel.Information,
			,
			,
			NStr("en = 'Data filling for access restriction is started.'"),
			EventLogEntryTransactionMode.Transactional);
		
		SetDataFillingForAccessRestrictions(True);
	EndIf;
	
	// Updating session parameters.
	// It is required so that the administrator don't have to restart.
	SpecifiedParameters = New Array;
	SessionParametersSetting("", SpecifiedParameters);
	
EndProcedure

// Returns the user interface type for access setup.
Function SimplifiedAccessRightSetupInterface() Export
	
	SimplifiedInterface = False;
	AccessManagementOverridable.OnDefineAccessSettingsInterface(SimplifiedInterface);
	
	Return SimplifiedInterface = True;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions intended for user interface operations

// Returns a metadata object name with properties specified in order:
//  - ExtendedObjectPresentation,
//  - ObjectPresentation,
//  - Synonym,
//  - Name.
//
// Parameters:
//  ObjectMetadata - MetadataObject.
//
// Returns:
//  String.
//
Function ObjectNameFromMetadata(ObjectMetadata) Export
	
	If ValueIsFilled(ObjectMetadata.ExtendedObjectPresentation) Then
		ObjectName = ObjectMetadata.ExtendedObjectPresentation;
	ElsIf ValueIsFilled(ObjectMetadata.ObjectPresentation) Then
		ObjectName = ObjectMetadata.ObjectPresentation;
	ElsIf ValueIsFilled(ObjectMetadata.Synonym) Then
		ObjectName = ObjectMetadata.Synonym;
	Else
		ObjectName = ObjectMetadata.Name;
	EndIf;
	
	Return ObjectName;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Management of AccessKinds and AccessValues tables in the forms used for editing

// Fills the auxiliary data required for
// the form operation that do not depend on the object content or are filled for a new object.
//
// The form should contain the attributes listed below.
// Attributes marked with * are filled automatically, but they must be created in the form.
// Attributes marked with # character must be created in
// the form if the CurrentAccessGroup attribute is to be created in the form (see below).
// Attributes marked with @ are created automatically.
//
//  CurrentAccessGroup - Optional
//                         attribute. It is only used when it was  created in the form.
//
//  AccessKinds - Table with the following fields:
//    #AccessGroup             - CatalogRef.AccessGroups,
//    AccessKind               - DefinedType.AccessValue,
//    Preset                   - Boolean (only for profile),
//    AllAllowed               - Boolean,
//    *AccessKindPresentation  - String - settings presentation,
//    *AllAllowedPresentation  - String - presentation settings,
//    @Used                    - Boolean.
//
//  AccessValues       - Table with the following fields:
//    #AccessGroup     - CatalogRef.AccessGroups,
//    *AccessKind      - DefinedType.AccessValue,
//    AccessValue      - DefinedType.AccessValue,
//    *RowNumberByKind - Number.
//
//  *UseExternalUsers            - Boolean - attribute will be created if it is not present in the form.
//  *AccessKindLabel             - String - presentation of current access kind in the form.
//  @IsAccessGroupProfile        - Boolean.
//  @CurrentAccessKind           - DefinedType.AccessValue.
//  @SelectedValueCurrentTypes   - ValueList.
//  @SelectedValueCurrentType    - DefinedType.AccessValue.
//  @TableStorageAttributeName   - String.
//  @UsersAccessKind             - DefinedType.AccessValue.
//  @ExternalUserAccessKind      - DefinedType.AccessValue.
//  
//  @AllAccessKinds - Table with the following fields:
//    @Ref          - DefinedType.AccessValue,
//    @Presentation - Row,
//    @Used         - Boolean.
//
//  @PresentationsAllAllowed - Table with the following fields:
//    @Name           - Row,
//    @Presentation   - String.
//
//  @AllTypesOfValuesToSelect - Table with the following fields:
//    @AccessKind       - DefinedType.AccessValue,
//    @ValueType        - DefinedType.AccessValue,
//    @TypePresentation - Row,
//    @TableName        - String.
//
// Parameters:
//  Form      - ManagedForm that
//               must be set to edit allowed values.
//
//  ThisProfile - Boolean - it specifies that access kinds an be set up<o:p></o:p>
//                and that settings presentation contains 4 values instead of 2.
//  TableStorageAttributeName - A row containing, for example,
//               the Object row that contains the AccessKinds and AccessValues tables (see below).
//               If the row is empty 
//               the tables are considered to be stored in the form attributes.
//
Procedure OnCreateAtServerAllowedValueEditingForm(Form, ThisProfile = False, TableStorageAttributeName = "Object") Export
	
	AddAuxiliaryDataAttributesToForm(Form, TableStorageAttributeName);
	
	Form.TableStorageAttributeName = TableStorageAttributeName;
	Form.IsAccessGroupProfile = ThisProfile;
	
	// Filling the access value types of all access kinds
	For Each AccessKindProperties In AccessKindProperties() Do
		For Each Type In AccessKindProperties.TypesOfValuesToSelect Do
			TypeArray = New Array;
			TypeArray.Add(Type);
			TypeDescription = New TypeDescription(TypeArray);
			
			TypeMetadata = Metadata.FindByType(Type);
			If Metadata.Enums.Find(TypeMetadata.Name) = TypeMetadata Then
				TypePresentation = TypeMetadata.Presentation();
			Else
				TypePresentation = ?(ValueIsFilled(TypeMetadata.ObjectPresentation),
					TypeMetadata.ObjectPresentation,
					TypeMetadata.Presentation());
			EndIf;
			
			NewRow = Form.AllTypesOfValuesToSelect.Add();
			NewRow.AccessKind       = AccessKindProperties.Ref;
			NewRow.ValueType        = TypeDescription.AdjustValue(Undefined);
			NewRow.TypePresentation = TypePresentation;
			NewRow.TableName        = TypeMetadata.FullName();
		EndDo;
	EndDo;
	
	Form.AccessKindUsers            = Catalogs.Users.EmptyRef();
	Form.AccessKindExternalUsers    = Catalogs.ExternalUsers.EmptyRef();
	Form.UseExternalUsers = ExternalUsers.UseExternalUsers();
	
	FillTableAllAccessKindsInForm(Form);
	
	FillPresentationTableAllAllowedInForm(Form, ThisProfile);
	
	ApplyTableAccessKindsInForm(Form);
	
	DeleteNotExistingKindsAndAccessValues(Form);
	AccessManagementInternalClientServer.FillPropertiesOfAccessKindsInForm(Form);
	
	RefreshNotUsedAccessKindRepresentation(Form, True);
	
	StandardSubsystemsServer.SetGroupTitleRepresentation(
		Form, "AccessValuesByAccessKind");
	
EndProcedure

// When rereading data, fills or updates auxiliary data that is<o:p></o:p>
// required for form functioning and depends on the content of the object.<o:p></o:p>

Procedure OnRereadAtServerAllowedValueEditingForm(Form, CurrentObject) Export
	
	DeleteNotExistingKindsAndAccessValues(Form, CurrentObject);
	DeleteNotExistingKindsAndAccessValues(Form);
	
	AccessManagementInternalClientServer.FillPropertiesOfAccessKindsInForm(Form);
	
	AccessManagementInternalClientServer.OnChangeCurrentAccessKind(Form);
	
EndProcedure

// Deletes irrelevant access values before write.
// Irrelevant access values are sometimes created when you replace or delete<o:p></o:p>
// an access kind with filled access values.<o:p></o:p>

//
Procedure BeforeWriteAtServerAllowedValueEditingForm(Form, CurrentObject) Export
	
	DeleteExcessAccessValues(Form, CurrentObject);
	DeleteExcessAccessValues(Form);
	
EndProcedure

// Updates access kind properties.
Procedure AfterWriteAtServerAllowedValueEditingForm(Form, CurrentObject, WriteParameters) Export
	
	AccessManagementInternalClientServer.FillPropertiesOfAccessKindsInForm(Form);
	
EndProcedure

// Hides or shows the unused access types.
Procedure RefreshNotUsedAccessKindRepresentation(Form, OnCreateAtServer = False) Export
	
	Items = Form.Items;
	
	If Not OnCreateAtServer Then
		Items.ShowNotUsedAccessKinds.Check =
			Not Items.ShowNotUsedAccessKinds.Check;
	EndIf;
	
	Filter = AccessManagementInternalClientServer.FilterInAllowedValuesEditingFormTables(
		Form);
	
	If Not Items.ShowUnusedAccessKinds.Check Then
		Filter.Insert("Used", True);
	EndIf;
	
	Items.AccessKinds.RowFilter = New FixedStructure(Filter);
	
	Items.AccessKindsAccessKindPresentation.ChoiceList.Clear();
	
	For Each Row In Form.AllAccessKinds Do
		
		If Not Items.ShowUnusedAccessKinds.Check
		   And Not Row.Used Then
			
			Continue;
		EndIf;
		
		Items.AccessKindsAccessKindPresentation.ChoiceList.Add(Row.Presentation);
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Universal procedures and functions

// Returns a reference to an old (or new) object
//
// Parameters:
//  Object    - CatalogObject, ...
//  IsNew     - Boolean (Return value).
//
Function ObjectRef(Val Object, IsNew = Undefined) Export
	
	Ref = Object.Ref;
	IsNew = Not ValueIsFilled(Ref);
	
	If IsNew Then
		Ref = Object.GetNewObjectRef();
		
		If Not ValueIsFilled(Ref) Then
			
			Manager = CommonUse.ObjectManagerByRef(Object.Ref);
			Ref = Manager.GetRef();
			Object.SetNewObjectRef(Ref);
		EndIf;
	EndIf;
	
	Return Ref;
	
EndFunction

// For internal use only
Procedure SetFilterCriterionInQuery(Val Query, Val Values, Val ValueParameterName, Val ParameterNameFilterConditionsFieldName) Export
	
	If Values = Undefined Then
		
	ElsIf TypeOf(Values) <> Type("Array")
	        And TypeOf(Values) <> Type("FixedArray") Then
		
		Query.SetParameter(ValueParameterName, Values);
		
	ElsIf Values.Count() = 1 Then
		Query.SetParameter(ValueParameterName, Values[0]);
	Else
		Query.SetParameter(ValueParameterName, Values);
	EndIf;
	
	For LineNumber = 1 To StrLineCount(ParameterNameFilterConditionsFieldName) Do
		CurrentRow = StrGetLine(ParameterNameFilterConditionsFieldName, LineNumber);
		If Not ValueIsFilled(CurrentRow) Then
			Continue;
		EndIf;
		SeparatorIndex = Find(CurrentRow, ":");
		If SeparatorIndex = 0 Then
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Error when executing the AccessManagement.SetFilterCriterionInQuery() procedure.
				           |
				           |In the ParameterNameFilterConditionsFieldName parameter,
				           |no separator (colon character) is found in a row
				           |in format ""<Condition parameter name>:<FieldName>"" :
                  |""1"".'"),
				CurrentRow);
		EndIf;
		FilterConditionParameterName = Left(CurrentRow, SeparatorIndex-1);
		FieldName = Mid(CurrentRow, SeparatorIndex+1);
		If Values = Undefined Then
			FilterCriterion = "True";
			
		ElsIf TypeOf(Values) <> Type("Array")
		        And TypeOf(Values) <> Type("FixedArray") Then
			
			FilterCriterion = FieldName + " = &" + ValueParameterName;
			
		ElsIf Values.Count() = 1 Then
			FilterCriterion = FieldName + " = &" + ValueParameterName;
		Else
			FilterCriterion = FieldName + " IN (&" + ValueParameterName + ")";
		EndIf;
		Query.Text = StrReplace(Query.Text, FilterConditionParameterName, FilterCriterion);
	EndDo;
	
EndProcedure

// Updates the record set in the database
// if the set records do not match database records.
//
// Parameters:
//  RecordSet           - Empty or read RecordSet, with or without filter.
//                        Register manager used to create the record set.
//
//  NewRecords           - ValueTable in register format.
//
//  ComparisonFields    - String - contains the list of fields which
//                        values are used to calculate record set differences.
//                        For example "Dimension1, Dimension2, Resource1"
//                        (DimensionData attribute is not included)
//
//  ChoiceField         - Undefined - the entire registry is to be written,
//                        or the filter is already applied to record set.
//                        String       - name of field to which the filter must be applied.
//  SelectValue         - a filter value to be used, provided that a filter field is set.
//
//  ModifiedRecords     - Undefined - no actions. Otherwise,
//                        returns a value table in the register format
//                        with the RowChangeKind field of Number type
//                        (-1 if the record is deleted, 1 if the record is added).
//
//  TransactionIsOpen   - Undefined       - do not open a transaction.
//                        True            - transaction is already open. 
//                        any other value - open a transaction
//                                          and set TransactionIsOpen to True.
//
//  RecordSetIsRead     - Boolean, if True, the unspecified record set
//                        already contains the read records, data lock is set for
//                        these records, and transaction is open.
//
//  HasChanges          - Boolean (return value) - set to True if
//                        data is changed; not set otherwise.
//
//  CheckOnly           - Boolean - if True, do not
//                        write, only find the necessary records and
//                        set HasChanges property.
//
// AdditionalProperties - Undefined, Structure. If Structure, then
//                        all structure parameters will
//                        be added to the AdditionalProperties 
//                        of the <Register*>RecordSet objects.
Procedure UpdateRecordSet(Val RecordSet,
                          Val NewRecords,
                          Val ComparisonFields     = Undefined,
                          Val FilterField          = Undefined,
                          Val FilterValue          = Undefined,
                          HasChanges               = Undefined,
                          ModifiedRecords          = Undefined,
                          TransactionIsOpen        = Undefined,
                          Val RecordSetIsRead      = False,
                          Val WithoutOverwriting   = False,
                          Val CheckOnly            = False,
                          Val AdditionalProperties = Undefined) Export
	
	RegisterFullName = Metadata.FindByType(TypeOf(RecordSet)).FullName();
	RegisterManager = CommonUse.ObjectManagerByFullName(RegisterFullName);
	If RecordSet = RegisterManager Then
		RecordSet = RegisterManager.CreateRecordSet();
	EndIf;
	
	If ValueIsFilled(FilterField) Then
		SetFilter(RecordSet.Filter[FilterField], FilterValue);
	EndIf;
	
	If Not RecordSetIsRead Then
		LockRecordSetArea(RecordSet, RegisterFullName);
		RecordSet.Read();
	EndIf;
	
	ComparisonFields = ?(ComparisonFields = Undefined, RecordSetFields(RecordSet), ComparisonFields);
	
	If WithoutOverwriting Then
		RecordSet = RegisterManager.CreateRecordSet();
		RecordKeyDescription = AccessManagementInternalCached.RecordKeyDescription(RegisterFullName);
		FilterRecords = New Structure(RecordKeyDescription.FieldRow);
		OtherDimensionFields = New Array;
		For Each Field In RecordKeyDescription.FieldArray Do
			If Field <> FilterField Then
				OtherDimensionFields.Add(Field);
			EndIf;
		EndDo;
		RecordsToDelete = New ValueTable;
		For Each Field In OtherDimensionFields Do
			RecordsToDelete.Columns.Add(Field);
		EndDo;
		NewRecords = NewRecords.Copy();
	EndIf;
	
	HasCurrentChanges = False;
	If ModifiedRecords = Undefined Then
		If RecordSet.Count() = NewRecords.Count() Or WithoutOverwriting Then
			Filter = New Structure(ComparisonFields);
			NewRecords.Indexes.Add(ComparisonFields);
			For Each Write In RecordSet Do
				FillPropertyValues(Filter, Write);
				FoundRows = NewRecords.FindRows(Filter);
				If FoundRows.Count() = 0 Then
					HasCurrentChanges = True;
					HasChanges = True;
					If WithoutOverwriting Then
						FillPropertyValues(FilterRecords, Write);
						If NewRecords.FindRows(FilterRecords).Count() = 0 Then
							FillPropertyValues(RecordsToDelete.Add(), FilterRecords);
						EndIf;
					Else
						Break;
					EndIf;
				ElsIf WithoutOverwriting Then
					NewRecords.Delete(FoundRows[0]);
				EndIf;
			EndDo;
			If WithoutOverwriting And NewRecords.Count() > 0 Then
				HasCurrentChanges = True;
				HasChanges = True;
			EndIf;
		Else
			HasCurrentChanges = True;
			HasChanges = True;
		EndIf;
	Else
		If RecordSet.Count() <> NewRecords.Count() Then
			HasCurrentChanges = True;
			HasChanges = True;
		EndIf;
		If RecordSet.Count() > NewRecords.Count() Then
			ModifiedRecords = RecordSet.Unload();
			RequredRecords   = NewRecords;
			RowChangeKind = -1;
		Else
			ModifiedRecords = NewRecords.Copy();
			RequredRecords   = RecordSet.Unload();
			RowChangeKind = 1;
		EndIf;
		ModifiedRecords.Columns.Add("RowChangeKind", New TypeDescription("Number"));
		ModifiedRecords.FillValues(RowChangeKind, "RowChangeKind");
		RowChangeKind = ?(RowChangeKind = 1, -1, 1);
		Filter = New Structure(ComparisonFields);
		
		For Each Row In RequredRecords Do
			FillPropertyValues(Filter, Row);
			Rows = ModifiedRecords.FindRows(Filter);
			If Rows.Count() = 0 Then
				NewRow = ModifiedRecords.Add();
				FillPropertyValues(NewRow, Filter);
				NewRow.RowChangeKind = RowChangeKind;
				HasCurrentChanges = True;
				HasChanges = True;
			Else
				ModifiedRecords.Delete(Rows[0]);
			EndIf;
		EndDo;
	EndIf;
	
	If HasCurrentChanges Then
		If CheckOnly Then
			Return;
		EndIf;
		If TransactionIsOpen <> Undefined // You must use external transaction
		   And TransactionIsOpen <> True Then // External transaction is
			// not open yet. Opening an external transaction
			BeginTransaction();
			TransactionIsOpen = True;
		EndIf;
		If WithoutOverwriting Then
			SetAdditionalProperties(RecordSet, AdditionalProperties);
			For Each Row In RecordsToDelete Do
				If ValueIsFilled(FilterField) Then
					SetFilter(RecordSet.Filter[FilterField], FilterValue);
				EndIf;
				For Each Field In OtherDimensionFields Do
					SetFilter(RecordSet.Filter[Field], Row[Field]);
				EndDo;
				RecordSet.Write();
			EndDo;
			RecordSet.Add();
			For Each Row In NewRecords Do
				If ValueIsFilled(FilterField) Then
					SetFilter(RecordSet.Filter[FilterField], FilterValue);
				EndIf;
				For Each Field In OtherDimensionFields Do
					SetFilter(RecordSet.Filter[Field], Row[Field]);
				EndDo;
				FillPropertyValues(RecordSet[0], Row);
				RecordSet.Write();
			EndDo;
		Else
			SetAdditionalProperties(RecordSet, AdditionalProperties);
			RecordSet.Load(NewRecords);
			RecordSet.Write();
		EndIf;
	EndIf;
	
EndProcedure

// Updates register rows with a multiple-value filter 
// for one or two register dimensions. Checks for changes;
// if no changes are found, no data is overwritten.
//
// Parameters:
//  RegisterManager          - Register manager used to create the type <Register*>RecordSet.
//
//  NewRecords               - ValueTable in register format.
//
//  ComparisonFields         - String - contains the list of fields
//                              which values are used to calculate
//                              record set differences. For example,
//                             "Dimension1, Dimension2, Resource1"
//                             (ChangeDate attribute is not included).
//
//  FirstDimensionName       - Undefined - there is no filter by dimension.
//                              String    - contains name of the first dimension
//                                          with multiple values.
//
//  FirstDimensionValues  -     Undefined - no filter by dimension,
//                                          (FirstDimensionName = Undefined).
//                              AnyRef    - contains one register filter
//                                          value for records to be updated.
//                              Array     - contains a register filter value array
//                                          for records to be updated. 
//                                          If the array is empty, no action is required.
//
//  SecondDimensionName       - see FirstDimensionName.
//  SecondDimensionValues     - see FirstDimensionValues.
//  ThirdDimensionName        - see FirstDimensionName.
//  ThirdDimensionValues      - see FirstDimensionValues.
//
//  HasChanges                - Boolean (return value) - set to True if
//                              data is changed; not set otherwise.
//
//  CheckOnly                 - Boolean - if True, do not
//                              write, only find the necessary records and
//                              set HasChanges property.
//
// AdditionalProperties       - Undefined, Structure. If Structure, then
//                              all structure parameters will
//                              be added to the AdditionalProperties 
//                              of the <Register*>RecordSet objects.
//
Procedure UpdateRecordSets(Val RegisterManager,
                           Val NewRecords,
                           Val ComparisonFields                 = Undefined,
                           Val FirstDimensionName               = Undefined,
                           Val FirstDimensionValues             = Undefined,
                           Val SecondDimensionName              = Undefined,
                           Val SecondDimensionValues            = Undefined,
                           Val ThirdDimensionName               = Undefined,
                           Val ThirdDimensionValues             = Undefined,
                           Val NewRecordsContainOnlyDifferences = False,
                           Val FixedFilter                      = Undefined,
                           HasChanges                           = Undefined,
                           Val CheckOnly                        = False,
                           Val AdditionalProperties             = Undefined) Export
	
	// Preprocessing parameters
	
	If Not DimensionParameterGroupIsProcessed(FirstDimensionName, FirstDimensionValues) Then
		HasChanges = True;
		Return;
	EndIf;
	If Not DimensionParameterGroupIsProcessed(SecondDimensionName, SecondDimensionValues) Then
		HasChanges = True;
		Return;
	EndIf;
	If Not DimensionParameterGroupIsProcessed(ThirdDimensionName, ThirdDimensionValues) Then
		HasChanges = True;
		Return;
	EndIf;
	
	OrderDimensionParameterGroups(
		FirstDimensionName,
		FirstDimensionValues,
		SecondDimensionName,
		SecondDimensionValues,
		ThirdDimensionName,
		ThirdDimensionValues);
	
	// Checking and updating data
	Parameters = New Structure;
	Parameters.Insert("NewRecords",        NewRecords);
	Parameters.Insert("ComparisonFields",  ComparisonFields);
	Parameters.Insert("FixedFilter",       FixedFilter);
	Parameters.Insert("TransactionIsOpen", ?(TransactionActive(), Undefined, False));
	Parameters.Insert("RecordSet",          RegisterManager.CreateRecordSet());
	Parameters.Insert("RegisterMetadata",  Metadata.FindByType(TypeOf(Parameters.RecordSet)));
	Parameters.Insert("RegisterFullName",  Parameters.RegisterMetadata.FullName());
	
	If NewRecordsContainOnlyDifferences Then
		Parameters.Insert("SetForSingleRecord",  RegisterManager.CreateRecordSet());
	EndIf;
	
	If Parameters.FixedFilter <> Undefined Then
		For Each KeyAndValue In Parameters.FixedFilter Do
			SetFilter(Parameters.RecordSet.Filter[KeyAndValue.Key], KeyAndValue.Value);
		EndDo;
	EndIf;
	
	Try
		If NewRecordsContainOnlyDifferences Then
			
			If FirstDimensionName = Undefined Then
				Raise
					NStr("en = 'Invalid UpdateRecordSets procedure parameters.'");
			Else
				If SecondDimensionName = Undefined Then
					RecordByMultipleSets = False;
				Else
					RecordByMultipleSets = RecordByMultipleSets(
						Parameters, New Structure, FirstDimensionName, FirstDimensionValues);
				EndIf;
				
				If RecordByMultipleSets Then
					FieldList = FirstDimensionName + ", " + SecondDimensionName;
					NewRecords.Indexes.Add(FieldList);
					
					CountByFirstDimensionValues = Parameters.CountByValues;
					
					For Each FirstValue In FirstDimensionValues Do
						Filter = New Structure(FirstDimensionName, FirstValue);
						SetFilter(Parameters.RecordSet.Filter[FirstDimensionName], FirstValue);
						
						If ThirdDimensionName = Undefined Then
							RecordByMultipleSets = False;
						Else
							RecordByMultipleSets = RecordByMultipleSets(
								Parameters, Filter, SecondDimensionName, SecondDimensionValues);
						EndIf;
						
						If RecordByMultipleSets Then
							For Each SecondValue In SecondDimensionValues Do
								Filter.Insert(SecondDimensionName, SecondValue);
								SetFilter(Parameters.RecordSet.Filter[SecondDimensionName], SecondValue);
								
								// Updating by three dimensions
								RefreshNewSetRecordsByDistinctNewRecords(
									Parameters, Filter, HasChanges, CheckOnly, AdditionalProperties);
							EndDo;
							Parameters.RecordSet.Filter[SecondDimensionName].Use = False;
						Else
							// Updating by two dimensions
							Parameters.Insert("CountByValues", CountByFirstDimensionValues);
							RefreshNewSetRecordsByDistinctNewRecords(
								Parameters, Filter, HasChanges, CheckOnly, AdditionalProperties);
						EndIf;
					EndDo;
				Else
					// Updating by one dimension
					ReadCountForReading(Parameters);
					RefreshNewSetRecordsByDistinctNewRecords(
						Parameters, New Structure, HasChanges, CheckOnly, AdditionalProperties);
				EndIf;
			EndIf;
		Else
			If FirstDimensionName = Undefined Then
				// Updating all records
				UpdateRecordSet(
					Parameters.RecordSet,
					NewRecords,
					ComparisonFields,
					,
					,
					HasChanges,
					,
					Parameters.TransactionIsOpen,
					,
					,
					CheckOnly,
					AdditionalProperties);
				
			ElsIf SecondDimensionName = Undefined Then
				// Updating by one dimension
				Filter = New Structure(FirstDimensionName);
				For Each Value In FirstDimensionValues Do
					
					SetFilter(Parameters.RecordSet.Filter[FirstDimensionName], Value);
					Filter[FirstDimensionName] = Value;
					
					If FirstDimensionValues.Count() = 1 Then
						NewRecordSets = NewRecords;
					Else
						NewRecordSets = NewRecords.Copy(Filter);
					EndIf;
					
					UpdateRecordSet(
						Parameters.RecordSet,
						NewRecordSets,
						ComparisonFields,
						,
						,
						HasChanges,
						,
						Parameters.TransactionIsOpen,
						,
						,
						CheckOnly,
						AdditionalProperties);
				EndDo;
				
			ElsIf ThirdDimensionName = Undefined Then
				// Updating by two dimensions
				FieldList = FirstDimensionName + ", " + SecondDimensionName;
				NewRecords.Indexes.Add(FieldList);
				Filter = New Structure(FieldList);
				
				For Each FirstValue In FirstDimensionValues Do
					SetFilter(Parameters.RecordSet.Filter[FirstDimensionName], FirstValue);
					Filter[FirstDimensionName] = FirstValue;
					
					RefreshNewSetRecordsForAllNewAccounts(
						Parameters,
						Filter,
						FieldList,
						SecondDimensionName,
						SecondDimensionValues,
						HasChanges,
						CheckOnly,
						AdditionalProperties);
				EndDo;
			Else
				// Updating by three dimensions
				FieldList = FirstDimensionName + ", " + SecondDimensionName + ", " + ThirdDimensionName;
				NewRecords.Indexes.Add(FieldList);
				Filter = New Structure(FieldList);
				
				For Each FirstValue In FirstDimensionValues Do
					SetFilter(Parameters.RecordSet.Filter[FirstDimensionName], FirstValue);
					Filter[FirstDimensionName] = FirstValue;
					
					For Each SecondValue In SecondDimensionValues Do
						SetFilter(Parameters.RecordSet.Filter[SecondDimensionName], SecondValue);
						Filter[SecondDimensionName] = SecondValue;
						
						RefreshNewSetRecordsForAllNewAccounts(
							Parameters,
							Filter,
							FieldList,
							SecondDimensionName,
							SecondDimensionValues,
							HasChanges,
							CheckOnly,
							AdditionalProperties);
					EndDo;
				EndDo;
			EndIf;
		EndIf;
		
		If Parameters.TransactionIsOpen = True Then
			CommitTransaction();
		EndIf;
	Except
		If Parameters.TransactionIsOpen = True Then
			RollbackTransaction();
		EndIf;
		Raise;
	EndTry;
	
EndProcedure

// Updates the information register rows by data in the DistinctRows value table.
//
// Parameters:
//  RegisterManager    - Register manager used to create the type <Register*>RecordSet.
//
//  DistinctRows       - ValueTable containing the register fields
//                       and the RowChangeKind field (Number):
//                           1 if a row must be added
//                          -1 if a row must be deleted.
//
//  HasChanges          - Boolean (return value) - True if
//                        data is changed; not set otherwise.
//
//  FixedFilter         - Structure, containing the dimension name in
//                        the key and the value filter in the value.
//                        Can be used when there are more than 3 dimensions
//                        and it is known in advance
//                        that dimensions above 3 will have a single value.
//                        Dimensions specified in a fixed filter are
//                        not used when generating record sets for updating.
//
//  FilterDimensions    - String of dimensions (comma-separated)
//                        that must be used when generating
//                        record sets for updating (no more than 3). Any
//                        unspecified dimensions will be converted to
//                        a fixed filter, if all their values match.
//
//  CheckOnly           - Boolean - If True, do not
//                        write, only find the necessary records and
//                        set HasChanges property.
//
// AdditionalProperties - Undefined, Structure. If Structure, then
//                        all structure parameters will
//                        be added to the AdditionalProperties property
//                        of the <Register*>RecordSet objects.
//
Procedure UpdateInformationRegister(Val RegisterManager,
                                    Val UpdatingRows,
                                    HasChanges               = Undefined,
                                    Val FixedFilter          = Undefined,
                                    Val FilterDimensions     = Undefined,
                                    Val CheckOnly            = False,
                                    Val AdditionalProperties = Undefined) Export
	
	If UpdatingRows.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterMetadata = Metadata.FindByType(TypeOf(RegisterManager.EmptyKey()));
	
	If FixedFilter = Undefined Then
		FixedFilter = New Structure;
	EndIf;
	
	RecordKeyDescription = AccessManagementInternalCached.RecordKeyDescription(
		RegisterMetadata.FullName());
	
	If FilterDimensions = Undefined Then
		RecordKeyFilter = New Structure(RecordKeyDescription.FieldRow);
	Else
		FilterDimensions = New Structure(FilterDimensions);
	EndIf;
	
	FilterDimensionsArray   = New Array;
	FilterDimensionValues = New Structure;
	
	For Each Field In RecordKeyDescription.FieldArray Do
		If Not FixedFilter.Property(Field) Then
			Values = TableColumnValues(UpdatingRows, Field);
			
			If FilterDimensions = Undefined
			 Or FilterDimensions.Property(Field) Then
				
				FilterDimensionsArray.Add(Field);
				FilterDimensionValues.Insert(Field, Values);
				
			ElsIf Values.Count() = 1 Then
				FixedFilter.Insert(Field, Values[0]);
			EndIf;
		EndIf;
	EndDo;
	
	FirstDimensionName   = FilterDimensionsArray[0];
	FirstDimensionValues = FilterDimensionValues[FirstDimensionName];
	
	If FilterDimensionsArray.Count() > 1 Then
		SecondDimensionName   = FilterDimensionsArray[1];
		SecondDimensionValues = FilterDimensionValues[SecondDimensionName];
	Else
		SecondDimensionName   = Undefined;
		SecondDimensionValues = Undefined;
	EndIf;
	
	If FilterDimensionsArray.Count() > 2 Then
		ThirdDimensionName   = FilterDimensionsArray[2];
		ThirdDimensionValues = FilterDimensionValues[ThirdDimensionName];
	Else
		ThirdDimensionName   = Undefined;
		ThirdDimensionValues = Undefined;
	EndIf;
	
	UpdateRecordSets(
		RegisterManager,
		UpdatingRows,
		RecordKeyDescription.FieldRow,
		FirstDimensionName,
		FirstDimensionValues,
		SecondDimensionName,
		SecondDimensionValues,
		ThirdDimensionName,
		ThirdDimensionValues,
		True,
		FixedFilter,
		HasChanges,
		CheckOnly,
		AdditionalProperties);
	
EndProcedure

// Returns an empty reference to a metadata object of reference type.
//
// Parameters:
//  MetadataObjectName - MetadataObject,
//                     - Type used to find the metadata object,
//                     - String - full metadata object name.
// Returns:
//  Ref.
//
Function MetadataObjectEmptyRef(MetadataObjectName) Export
	
	If TypeOf(MetadataObjectName) = Type("MetadataObject") Then
		MetadataObject = MetadataObjectName;
		
	ElsIf TypeOf(MetadataObjectName) = Type("Type") Then
		MetadataObject = Metadata.FindByType(MetadataObjectName);
	Else
		MetadataObject = Metadata.FindByFullName(MetadataObjectName);
	EndIf;
	
	If MetadataObject = Undefined Then
		Raise
			NStr("en = 'Error in the MetadataObjectEmptyRef function
			           |of the AccessManagementInternal common module.
			           |
			           |Invalid MetadataObjectName parameter.'");
	EndIf;
	
	EmptyRef = Undefined;
	Try
		ObjectManager = CommonUse.ObjectManagerByFullName(MetadataObject.FullName());
		EmptyRef = ObjectManager.EmptyRef();
	Except
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Error in the MetadataObjectEmptyRef function
			           |of the AccessManagementInternal common module.
			           |
			           |Failed to get an empty reference for metadata object
			           |""%1"".'"),
			MetadataObject.FullName());
	EndTry;
	
	Return EmptyRef;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Other procedures and functions

// Creates a query to find differences between the register rows<?xml:namespace prefix = o ns = "urn:schemas-microsoft-com:office:office" /><o:p></o:p>
// in the specified data area (based on filters in the FieldsAndFilter parameter).<o:p></o:p>

//
// Parameters:
//  NewChoiceQueryText - String.
//
//  FieldsAndFilter   - Item array of the Structure type ("Fieldname", FilterConditionParameterName).
//
//  RegisterFullName
//               - String    - query for old data is generated automatically.
//                 Undefined - query for old data is obtained from the next parameter.
//
//  OldChoiceQueryText
//               - String    - query for old data, with nonstandard filters.
//               - Undefined - used when full name is defined for the register.
//
// Returns:
//  String - query text optimized for PostgreSQL.
//
Function ChangeSelectionQueryText(NewChoiceQueryText,
                                  FieldsAndFilter,
                                  RegisterFullName        = Undefined,
                                  TemporaryTableQueryText = Undefined,
                                  OldChoiceQueryText      = Undefined) Export
	
	// Preparing the old data query text
	If RegisterFullName <> Undefined Then
		OldChoiceQueryText =
		"SELECT
		|	&SelectedFields,
		|	&RowChangeKindFieldSubstitution
		|FROM
		|	RegisterFullName AS OldData
		|WHERE
		|	&FilterConditions";
	EndIf;
	
	SelectedFields = "";
	FilterConditions = "True";
	For Each FieldDetails In FieldsAndFilter Do
		// Aggregating the selected fields<o:p></o:p>
		SelectedFields = SelectedFields + StrReplace(
			"
			|	OldData.Field,",
			"Field",
			KeyAndValue(FieldDetails).Key);
			
		// Aggregating the filter conditions
		If ValueIsFilled(KeyAndValue(FieldDetails).Value) Then
			FilterConditions = FilterConditions + StrReplace(
				"
				|	And &FilterConditionParameterName", "&FilterConditionParameterName",
				KeyAndValue(FieldDetails).Value);
		EndIf;
	EndDo;
	
	OldChoiceQueryText =
		StrReplace(OldChoiceQueryText, "&SelectedFields,",  SelectedFields);
	
	OldChoiceQueryText =
		StrReplace(OldChoiceQueryText, "&FilterConditions",    FilterConditions);
	
	OldChoiceQueryText =
		StrReplace(OldChoiceQueryText, "RegisterFullName", RegisterFullName);
	
	If Find(NewChoiceQueryText, "&RowChangeKindFieldSubstitution") = 0 Then
		Raise
			NStr("en = 'Error in OldChoiceQueryText parameter value 
			           |of the ChangeSelectionQueryText procedure
                |in the AccessManagementInternal module.
			           |
			           |""&RowChangeKindFieldSubstitution"" row is not found in the query text.'");
	EndIf;
	
	OldChoiceQueryText = StrReplace(
		OldChoiceQueryText, "&RowChangeKindFieldSubstitution", "-1 AS RowChangeKind");
	
	If Find(NewChoiceQueryText, "&RowChangeKindFieldSubstitution") = 0 Then
		Raise
			NStr("en = 'Error in the NewChoiceQueryText parameter value 
			           |of the ChangeSelectionQueryText procedure
			           |in the AccessManagementInternal module.
                |
			           |""&RowChangeKindFieldSubstitution"" row is not found in the query text.'");
	EndIf;
	
	NewChoiceQueryText = StrReplace(
		NewChoiceQueryText,  "&RowChangeKindFieldSubstitution", "1 AS RowChangeKind");
	
	// Preparing the change selection query text
	QueryText =
	"SELECT
	|	&SelectedFields,
	|	SUM(AllRows.RowChangeKind) AS RowChangeKind
	|FROM
	|	(NewChoiceQueryText
	|	
	|	UNION ALL
	|	
	|	OldChoiceQueryText) AS AllRows
	|	
	|GROUP BY
	|	&GroupFields
	|	
	|HAVING
	|	SUM(AllRows.RowChangeKind) <> 0";
	
	SelectedFields = "";
	GroupFields = "";
	For Each FieldDetails In FieldsAndFilter Do
		// Aggregating the selected fields
		SelectedFields = SelectedFields + StrReplace(
			"
			|	AllRows.Field,",
			"Field",
			KeyAndValue(FieldDetails).Key);
		
		// Aggregating the join fields
		GroupFields = GroupFields + StrReplace(
			"
			|	AllRows.Field,",
			"Field",
			KeyAndValue(FieldDetails).Key);
	EndDo;
	GroupFields = Left(GroupFields, StrLen(GroupFields)-1);
	QueryText = StrReplace(QueryText, "&SelectedFields,",  SelectedFields);
	QueryText = StrReplace(QueryText, "&GroupFields", GroupFields);
	
	QueryText = StrReplace(
		QueryText, "NewChoiceQueryText",  NewChoiceQueryText);
	
	QueryText = StrReplace(
		QueryText, "OldChoiceQueryText", OldChoiceQueryText);
	
	If ValueIsFilled(TemporaryTableQueryText) Then
		QueryText = TemporaryTableQueryText +
		"
		|;
		|" + QueryText;
	EndIf;
	
	Return QueryText;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Handlers of conditional calls of other subsystems

// Returns a temporary table manager that contains
// a temporary table of users included in
// some additional user groups, such as
// task performer group users that correspond to addressing key
// (PerformerRole + MainAddressingObject + AdditionalAddressingObject).
//
// When changing additional user group content, call
// the UpdatePerformerGroupUsers procedure from AccessManagement
// module to apply changes to the internal subsystem data.
//
// Parameters:
//  TempTablesManager - TempTablesManager that can store a table with the following fields:
//                      PerformersGroupTable with the fields:
//                              PerformerGroup - for example,
//                                               CatalogRef.TaskPerformerGroups.
//                              User           - CatalogRef.Users,
//                                                   CatalogRef.ExternalUsers.
//
//  ParameterContent     - Undefined - parameter is not specified, returns all data.
//                         String - if set to "PerformerGroups",
//                                  only returns the contents of the specified performer groups.
//                                  If set to "Performers", only returns the
//                                  contents of performer groups that include the specified performers.
//
//  ParameterValue       - Undefined when ParameterContent = Undefined,
//                       - For example,
//                         CatalogRef.TaskPerformerGroups, when ParameterContent = "PerformerGroups".
//                       - CatalogRef.Users,
//                         CatalogRef.ExternalUsers
//                         when ParameterContent = "Performers".
//                         Array of the types specified above.
//
//  NoPerformerGroups    - Boolean - if False, TempTablesManager contains a temporary table, otherwise it does not.
//
Procedure OnDefinePerformerGroups(TempTablesManager, ParameterContent, ParameterValue, NoPerformerGroups) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.BusinessProcessesAndTasks") Then
		BusinessProcessesAndTasksServerModule = CommonUse.CommonModule("BusinessProcessesAndTasksServer");
		BusinessProcessesAndTasksServerModule.OnDefinePerformerGroups(TempTablesManager, ParameterContent, ParameterValue);
		NoPerformerGroups = False;
	Else
		NoPerformerGroups = True;
	EndIf;
	
EndProcedure

// Creates and/or updates the service user record.
// 
// Parameters:
//  User - CatalogRef.Users/CatalogObject.Users
//  CreateServiceUser - Boolean - if True, creates a SaaS user,
//                                if False, updates an existing user.
//  ServiceUserPassword - String - user password for Service Manager.
//
Procedure ServiceUserOnWrite(Val User, Val CreateServiceUser, Val ServiceUserPassword) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaSOperations.UsersSaaS") Then
		UsersInternalSaaSModule = CommonUse.CommonModule("UsersInternalSaaS");
		UsersInternalSaaSModule.WriteSaaSUser(User, CreateServiceUser, ServiceUserPassword);
	EndIf;
	
EndProcedure

// Returns the actions related to the specified SaaS user available to the current user.
//
// Parameters:
//  User - CatalogRef.Users - user for whom the list of available actions is retrieved.
//   If this parameter is not specified, available actions for the current user are retrieved.
//  ServiceUserPassword - String - SaaS password of the current user.
//  
Procedure OnReceiveActionsWithSaaSUser(AvailableAction, Val User = Undefined) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaSOperations.UsersSaaS") Then
		UsersInternalSaaSModule = CommonUse.CommonModule("UsersInternalSaaS");
		AvailableAction = UsersInternalSaaSModule.GetActionsWithSaaSUser(User);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Infobase update

// Fills the separated data handler that depends on shared data changes.
//
// Parameters:
//   Handlers - ValueTable, Undefined - see the description of
//              NewUpdateHandlerTable function in the InfobaseUpdate common module.
//   Undefined is passed in the event
//   of direct call (without using the infobase version update functionality).
// 
Procedure FillSeparatedDataHandlers(Parameters = Undefined) Export
	
	If Parameters <> Undefined And AreChangesOfAccessRestrictionsParameters() Then
		Handlers = Parameters.SeparatedHandlers;
		Handler = Handlers.Add();
		Handler.Version = "*";
		Handler.Procedure = "AccessManagementInternal.UpdateAuxiliaryRegisterDataByConfigurationChanges";
	EndIf;
	
EndProcedure

// Updates auxiliary data that depends on configuration only.
// Writes changes to this data (if any) by configuration version,
// so that these changes can be used when you
// update the other auxiliary data, for example, in the
// UpdateAuxiliaryRegisterDataByConfigurationChanges handler.
//
Procedure UpdateAccessRestrictionParameters(HasChanges = Undefined, CheckOnly = False) Export
	
	DataLock = New DataLock;
	LockItem = DataLock.Add("Constant.AccessRestrictionParameters");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem = DataLock.Add("InformationRegister.RoleRights");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem = DataLock.Add("InformationRegister.AccessRightDependencies");
	LockItem.Mode = DataLockMode.Exclusive;
	
	If CheckOnly Or ExclusiveMode() Then
		DisableExclusiveMode = False;
	Else
		DisableExclusiveMode = True;
		SetExclusiveMode(True);
	EndIf;
	
	BeginTransaction();
	Try
		DataLock.Lock();
		
		InformationRegisters.RoleRights.UpdateRegisterData(
			HasChanges, CheckOnly);
		
		If Not (CheckOnly And HasChanges) Then
			InformationRegisters.AccessRightDependencies.UpdateRegisterData(
				HasChanges, CheckOnly);
		EndIf;
		
		If Not (CheckOnly And HasChanges) Then
			Constants["AccessRestrictionParameters"].CreateValueManager(
				).UpdateAccessKindPropertyDescription(HasChanges, CheckOnly);
		EndIf;
		
		If Not (CheckOnly And HasChanges) Then
			Catalogs.AccessGroupProfiles.UpdateSuppliedProfilesDescription(
				HasChanges, CheckOnly);
		EndIf;
		
		If Not (CheckOnly And HasChanges) Then
			Catalogs.AccessGroupProfiles.UpdatePredefinedProfileContent(
				HasChanges, CheckOnly);
		EndIf;
		
		If Not (CheckOnly And HasChanges) Then
			InformationRegisters.ObjectRightsSettings.UpdateAvailableRightsForObjectRightSetup(
				HasChanges, CheckOnly);
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		If DisableExclusiveMode Then
			SetExclusiveMode(False);
		EndIf;
		Raise;
	EndTry;
	
	If DisableExclusiveMode Then
		SetExclusiveMode(False);
	EndIf;
	
EndProcedure

// Clears the auxiliary data that depend on configuration only.
// It is used as a cleaning handler for auxiliary data that depend on the
// configuration, in order to check and update
// the remaining auxiliary data when updating the infobase,
// for example, in the UpdateAuxiliaryDataOnInfobaseUpdate handler.
//
Procedure ClearAccessRestrictionParameters() Export
	
	DataLock = New DataLock;
	LockItem = DataLock.Add("Constant.AccessRestrictionParameters");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem = DataLock.Add("InformationRegister.RoleRights");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem = DataLock.Add("InformationRegister.AccessRightDependencies");
	LockItem.Mode = DataLockMode.Exclusive;
	
	If ExclusiveMode() Then
		DisableExclusiveMode = False;
	Else
		DisableExclusiveMode = True;
		SetExclusiveMode(True);
	EndIf;
	
	BeginTransaction();
	Try
		DataLock.Lock();
		
		// Clearing role rights
		RecordSet = InformationRegisters.RoleRights.CreateRecordSet();
		RecordSet.Write();
		
		// Clearing right dependencies
		RecordSet = InformationRegisters.AccessRightDependencies.CreateRecordSet();
		RecordSet.Write();
		
		// Clearing the remaining data generated using metadata, and their changes
		Constants.AccessRestrictionParameters.Set(New ValueStorage(Undefined));
		
		CommitTransaction();
	Except
		RollbackTransaction();
		If DisableExclusiveMode Then
			SetExclusiveMode(False);
		EndIf;
		Raise;
	EndTry;
	
	If DisableExclusiveMode Then
		SetExclusiveMode(False);
	EndIf;
	
EndProcedure

// Checks whether there were shared data changes for any data area.
Function AreChangesOfAccessRestrictionsParameters() Export
	
	SetPrivilegedMode(True);
	
	ParametersToCheck = New Array;
	ParametersToCheck.Add("RoleRightMetadataObjects");
	ParametersToCheck.Add("AvailableRightsForObjectRightsSettings");
	ParametersToCheck.Add("SuppliedAccessGroupProfiles");
	ParametersToCheck.Add("AccessGroupPredefinedProfiles");
	ParametersToCheck.Add("GroupAndAccessValueTypes");
	
	Parameters = AccessManagementInternalCached.Parameters();
	
	For Each ParameterToBeChecked In ParametersToCheck Do
		
		LastChanges = StandardSubsystemsServer.ApplicationParameterChanges(
			Parameters, ParameterToBeChecked);
		
		If LastChanges = Undefined
		 Or LastChanges.Count() > 0 Then
			
			Return True;
		EndIf;
		
	EndDo;
	
	Return False;
	
EndFunction

// Updates auxiliary data that partially depend on the configuration.
//
// Updated when there are configuration changes
// recorded in access restriction parameters when you update infobase to the current version of configuration.
//
Procedure UpdateAuxiliaryRegisterDataByConfigurationChanges(Parameters = Undefined) Export
	
	If Parameters <> Undefined
	   And Not Parameters.ExclusiveMode
	   And AreChangesOfAccessRestrictionsParameters() Then
		
		Parameters.ExclusiveMode = True;
		Return;
	EndIf;
	
	DataLock = New DataLock;
	LockItem = DataLock.Add("InformationRegister.AccessGroupTables");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem = DataLock.Add("InformationRegister.ObjectRightsSettings");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem = DataLock.Add("Catalog.AccessGroupProfiles");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem = DataLock.Add("Catalog.AccessGroups");
	LockItem.Mode = DataLockMode.Exclusive;
	
	BeginTransaction();
	Try
		DataLock.Lock();
		
		InformationRegisters.AccessGroupTables.UpdateRegisterDataByConfigurationChanges();
		InformationRegisters.AccessValueGroups.UpdateConfigurationChangesAuxiliaryRegisterData();
		InformationRegisters.ObjectRightsSettings.UpdateConfigurationChangesAuxiliaryRegisterData();
		Catalogs.AccessGroupProfiles.RefreshSuppliedProfilesOnConfigurationChanges();
		Catalogs.AccessGroups.MarkForDeletionSelectedProfilesAccessGroups();
		InformationRegisters.AccessValueSets.UpdateConfigurationChangesAuxiliaryRegisterData();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Converts the DELETE attribute to the Role attribute in
// the Roles tabular section of the Profiles catalog of access groups.
//
Procedure ConvertRoleNamesToIDs() Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Roles.Ref AS Ref
	|FROM
	|	Catalog.AccessGroupProfiles.Roles AS Roles
	|WHERE
	|	Not(Roles.Role <> VALUE(Catalog.MetadataObjectIDs.EmptyRef)
	|				AND Roles.DELETE = """")";
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		Object = Selection.Ref.GetObject();
		Index = Object.Roles.Count()-1;
		While Index >= 0 Do
			Row = Object.Roles[Index];
			If ValueIsFilled(Row.Role) Then
				Row.DELETE = "";
			ElsIf ValueIsFilled(Row.DELETE) Then
				MetadataRoles = Metadata.Roles.Find(Row.DELETE);
				If MetadataRoles <> Undefined Then
					Row.DELETE = "";
					Row.Role = CommonUse.MetadataObjectID(
						MetadataRoles);
				Else
					Object.Roles.Delete(Index);
				EndIf;
			Else
				Object.Roles.Delete(Index);
			EndIf;
			Index = Index-1;
		EndDo;
		InfobaseUpdate.WriteData(Object);
	EndDo;
	
EndProcedure

// Updates settings and enables a scheduled job.
Procedure EnableDataFillingForAccessRestriction() Export
	
	MetadataJob = Metadata.ScheduledJobs.DataFillingForAccessRestrictions;
	
	If CommonUseCached.DataSeparationEnabled() Then
		If CommonUse.SubsystemExists("StandardSubsystems.SaaSOperations.AccessManagementSaaS") Then
			AccessManagementInternalSaaSModule = CommonUse.CommonModule("AccessManagementInternalSaaS");
			AccessManagementInternalSaaSModule.SetDataFillingForAccessRestrictions(True);
		EndIf;
	Else
		Schedule = New JobSchedule;
		Schedule.WeeksPeriod = 1;
		Schedule.DaysRepeatPeriod = 1;
		Schedule.RepeatPeriodInDay = 300;
		Schedule.RepeatPause = 90;
		
		Job = ScheduledJobs.FindPredefined(MetadataJob);
		Job.Use = True;
		Job.Schedule = Schedule;
		
		Job.RestartIntervalOnFailure
			= MetadataJob.RestartIntervalOnFailure;
		
		Job.RestartCountOnFailure
			= MetadataJob.RestartCountOnFailure;
		
		Job.Write();
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions

Procedure OnChangeAccessValueSets(Val ObjectRef)
	
	RefsToDependentObjects = New Array;
	
	EventHandlers = CommonUse.InternalEventHandlers(
		"StandardSubsystems.AccessManagement\OnChangeAccessValueSets");
	For Each Handler In EventHandlers Do
		Handler.Module.OnChangeAccessValueSets(ObjectRef, RefsToDependentObjects);
	EndDo;
	
	AccessManagementOverridable.OnChangeAccessValueSets(
		ObjectRef, RefsToDependentObjects);
	
	For Each DependentObjectRef In RefsToDependentObjects Do
		
		If DependentObjectRef.Metadata().TabularSections.Find("AccessValueSets") = Undefined Then
			// No object change is required
			WriteAccessValueSets(DependentObjectRef);
		Else
			// Object change is required
			Object = DependentObjectRef.GetObject();
			Table = GetAccessValueSetsOfTabularSection(Object);
			If Not AccessValueSetsOfTabularSectionChanged(DependentObjectRef, Table) Then
				Continue;
			EndIf;
			PrepareAccessValueSetsForRecord(Undefined, Table, False);
			Try
				LockDataForEdit(DependentObjectRef, Object.DataVersion);
				Object.DataExchange.Load = True;
				Object.AdditionalProperties.Insert("WriteAccessValueSets");
				Object.AdditionalProperties.Insert("WriteDependentAccessValueSets");
				Object.AdditionalProperties.Insert("AccessValueSetsOfTabularSectionAreFilled");
				Object.AccessValueSets.Load(Table);
				Object.Write();
				UnlockDataForEdit(DependentObjectRef);
			Except
				BriefErrorDescription = BriefErrorDescription(ErrorInfo());
				Raise StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'When updating the dependent set of access values for object
					           |""%1"", an error has occurred: <?xml:namespace prefix = o ns = ""urn:schemas-microsoft-com:office:office"" /><o:p></o:p>
					           |
					           |%2'"),
					String(DependentObjectRef),
					BriefErrorDescription);
			EndTry;
		EndIf;
	EndDo;
	
EndProcedure

// For AddUserToAccessGroup procedure,
// DeleteUserFromAccessGroup procedure, and FindUserInAccessGroup function

Function ProcessUserLinkWithAccessGroup(User, SuppliedProfile, PrivilegedModeOn = Undefined)
	
	If     TypeOf(User) <> Type("CatalogRef.Users")
	   And TypeOf(User) <> Type("CatalogRef.UserGroups")
	   And TypeOf(User) <> Type("CatalogRef.ExternalUsers")
	   And TypeOf(User) <> Type("CatalogRef.ExternalUserGroups") Then
		
		Return False;
	EndIf;
	
	SuppliedProfileID = Undefined;
	
	If TypeOf(SuppliedProfile) = Type("String") Then
		If StringFunctionsClientServer.IsUUID(SuppliedProfile) Then
			
			SuppliedProfileID = SuppliedProfile;
			
			SuppliedProfile = Catalogs.AccessGroupProfiles.SuppliedProfileById(
				SuppliedProfileID);
		Else
			Return False;
		EndIf;
	EndIf;
	
	If TypeOf(SuppliedProfile) <> Type("CatalogRef.AccessGroupProfiles") Then
		Return False;
	EndIf;
	
	If SuppliedProfileID = Undefined Then
		SuppliedProfileID =
			Catalogs.AccessGroupProfiles.SuppliedProfileID(SuppliedProfile);
	EndIf;
	
	If SuppliedProfileID = Catalogs.AccessGroupProfiles.AdministratorProfileID() Then
		Return False;
	EndIf;
	
	ProfileProperties = AccessManagementInternalCached.Parameters(
		).SuppliedAccessGroupProfiles.ProfileDescriptions.Get(SuppliedProfileID);
	
	If ProfileProperties = Undefined
	 Or ProfileProperties.AccessKinds.Count() <> 0 Then
		
		Return False;
	EndIf;
	
	AccessGroup = Undefined;
	
	If SimplifiedAccessRightSetupInterface() Then
		
		If     TypeOf(User) <> Type("CatalogRef.Users")
		   And TypeOf(User) <> Type("CatalogRef.ExternalUsers") Then
			
			Return False;
		EndIf;
		
		Query = New Query;
		Query.SetParameter("Profile", SuppliedProfile);
		Query.SetParameter("User", User);
		Query.Text =
		"SELECT
		|	AccessGroups.Ref AS Ref
		|FROM
		|	Catalog.AccessGroups AS AccessGroups
		|WHERE
		|	AccessGroups.Profile = &Profile
		|	AND AccessGroups.User = &User";
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			AccessGroup = Selection.Ref;
		EndIf;
		
		If AccessGroup = Undefined Then
			If PrivilegedModeOn <> True Then
				Return False;
			Else
				AccessGroup = Catalogs.AccessGroups.CreateItem();
				AccessGroup.Description      = ProfileProperties.Description;
				AccessGroup.Profile          = SuppliedProfile;
				AccessGroup.User             = User;
				AccessGroup.Users.Add().User = User;
				AccessGroup.Write();
				Return True;
			EndIf;
		EndIf;
	Else
		Query = New Query;
		Query.SetParameter("SuppliedProfile", SuppliedProfile);
		Query.Text =
		"SELECT
		|	AccessGroups.Ref AS Ref,
		|	AccessGroups.MainSuppliedProfileAccessGroup
		|FROM
		|	Catalog.AccessGroups AS AccessGroups
		|WHERE
		|	AccessGroups.Profile = &SuppliedProfile
		|
		|ORDER BY
		|	AccessGroups.MainSuppliedProfileAccessGroup DESC";
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			AccessGroup = Selection.Ref;
		EndIf;
		
		If AccessGroup = Undefined Then
			If PrivilegedModeOn <> True Then
				Return False;
			Else
				AccessGroup = Catalogs.AccessGroups.CreateItem();
				AccessGroup.MainSuppliedProfileAccessGroup = True;
				AccessGroup.Description = ProfileProperties.Description;
				AccessGroup.Profile = SuppliedProfile;
				AccessGroup.Users.Add().User = User;
				AccessGroup.Write();
				Return True;
			EndIf;
		EndIf;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("Ref", AccessGroup);
	Query.SetParameter("User", User);
	Query.Text =
	"SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	Catalog.AccessGroups.Users AS GroupMembers
	|WHERE
	|	GroupMembers.Ref = &Ref
	|	AND GroupMembers.User = &User";
	UserFound = Not Query.Execute().IsEmpty();
	
	If PrivilegedModeOn = Undefined Then
		Return UserFound;
	EndIf;
	
	If PrivilegedModeOn And UserFound Then
		Return True;
	EndIf;
	
	If Not PrivilegedModeOn And Not UserFound Then
		Return True;
	EndIf;
	
	AccessGroup = AccessGroup.GetObject();
	
	If Not SimplifiedAccessRightSetupInterface()
	   And Not AccessGroup.MainSuppliedProfileAccessGroup Then
		
		AccessGroup.MainSuppliedProfileAccessGroup = True;
	EndIf;
	
	If PrivilegedModeOn Then
		AccessGroup.Users.Add().User = User;
	Else
		Filter = New Structure("User", User);
		Rows = AccessGroup.Users.FindRows(Filter);
		For Each Row In Rows Do
			AccessGroup.Users.Delete(Row);
		EndDo;
	EndIf;
	
	AccessGroup.Write();
	
	Return True;
	
EndFunction

// For the UpdateUserRoles procedure

Function CurrentUserProperties(UserArray)
	
	Query = New Query;
	
	Query.SetParameter("EmptyID",
		New UUID("00000000-0000-0000-0000-000000000000"));
	
	If UserArray = Undefined Then
		Query.Text =
		"SELECT
		|	Users.Ref AS User,
		|	Users.InfobaseUserID
		|INTO UsersToCheck
		|FROM
		|	Catalog.Users AS Users
		|WHERE
		|	Users.Internal = FALSE
		|	AND Users.InfobaseUserID <> &EmptyID
		|
		|UNION ALL
		|
		|SELECT
		|	ExternalUsers.Ref,
		|	ExternalUsers.InfobaseUserID
		|FROM
		|	Catalog.ExternalUsers AS ExternalUsers
		|WHERE
		|	ExternalUsers.InfobaseUserID <> &EmptyID";
		
	ElsIf TypeOf(UserArray) = Type("Type") Then
		If Metadata.FindByType(UserArray) = Metadata.Catalogs.ExternalUsers Then
			Query.Text =
			"SELECT
			|	ExternalUsers.Ref AS User,
			|	ExternalUsers.InfobaseUserID
			|INTO UsersToCheck
			|FROM
			|	Catalog.ExternalUsers AS ExternalUsers
			|WHERE
			|	ExternalUsers.InfobaseUserID <> &EmptyID";
		Else
			Query.Text =
			"SELECT
			|	Users.Ref AS User,
			|	Users.InfobaseUserID
			|INTO UsersToCheck
			|FROM
			|	Catalog.Users AS Users
			|WHERE
			|	Users.Internal = FALSE
			|	AND Users.InfobaseUserID <> &EmptyID";
		EndIf;
	Else
		InitialUsers = New ValueTable;
		InitialUsers.Columns.Add("User", New TypeDescription(
			"CatalogRef.Users, CatalogRef.ExternalUsers"));
		
		For Each User In UserArray Do
			InitialUsers.Add().User = User;
		EndDo;
		
		Query.SetParameter("InitialUsers", InitialUsers);
		Query.Text =
		"SELECT DISTINCT
		|	InitialUsers.User
		|INTO InitialUsers
		|FROM
		|	&InitialUsers AS InitialUsers
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	Users.Ref AS User,
		|	Users.InfobaseUserID
		|INTO UsersToCheck
		|FROM
		|	Catalog.Users AS Users
		|		INNER JOIN InitialUsers AS InitialUsers
		|		ON Users.Ref = InitialUsers.User
		|			AND (Users.Internal = FALSE)
		|			AND (Users.InfobaseUserID <> &EmptyID)
		|
		|UNION ALL
		|
		|SELECT
		|	ExternalUsers.Ref,
		|	ExternalUsers.InfobaseUserID
		|FROM
		|	Catalog.ExternalUsers AS ExternalUsers
		|		INNER JOIN InitialUsers AS InitialUsers
		|		ON ExternalUsers.Ref = InitialUsers.User
		|			AND (ExternalUsers.InfobaseUserID <> &EmptyID)";
	EndIf;
	
	Query.Text = Query.Text + "
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|" +
	"SELECT
	|	Users.Ref AS Ref,
	|	Users.InfobaseUserID
	|FROM
	|	Catalog.AccessGroups.Users AS AccessGroupsUsers
	|		INNER JOIN Catalog.Users AS Users
	|		ON (AccessGroupsUsers.Ref = VALUE(Catalog.AccessGroups.Administrators))
	|			AND AccessGroupsUsers.User = Users.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	UsersToCheck.User,
	|	UsersToCheck.InfobaseUserID
	|FROM
	|	UsersToCheck AS UsersToCheck
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	UsersToCheck.User AS User,
	|	AccessGroupsUsers.Ref.Profile AS Profile
	|INTO UsersProfiles
	|FROM
	|	UsersToCheck AS UsersToCheck
	|		INNER JOIN InformationRegister.UserGroupContent AS UserGroupContent
	|		ON UsersToCheck.User = UserGroupContent.User
	|			AND (UserGroupContent.Used)
	|			AND (&ExcludeExternalUsers)
	|		INNER JOIN Catalog.AccessGroups.Users AS AccessGroupsUsers
	|		ON (UserGroupContent.UserGroup = AccessGroupsUsers.User)
	|			AND (Not AccessGroupsUsers.Ref.DeletionMark)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	UsersProfiles.User,
	|	Roles.Role.Name AS Role
	|FROM
	|	UsersProfiles AS UsersProfiles
	|		INNER JOIN Catalog.AccessGroupProfiles.Roles AS Roles
	|		ON (Roles.Ref = UsersProfiles.Profile)
	|			AND (Not Roles.Ref.DeletionMark)";
	
	If GetFunctionalOption("UseExternalUsers") Then
		Query.Text = StrReplace(Query.Text, "&ExcludeExternalUsers", "True");
	Else
		Query.Text = StrReplace(Query.Text, "&ExcludeExternalUsers",
			"VALUETYPE(UsersToCheck.User) = TYPE(Catalog.Users)");
	EndIf;
	
	QueryResults = Query.ExecuteBatch();
	LastResult = QueryResults.Count()-1;
	Total = New Structure;
	
	Total.Insert("Administrators", New Map);
	
	For Each Row In QueryResults[LastResult-3].Unload() Do
		Total.Administrators.Insert(Row.Ref, True);
	EndDo;
	
	Total.Insert("InfobaseUserIDs", QueryResults[LastResult-2].Unload());
	Total.InfobaseUserIDs.Indexes.Add("User");
	
	Total.Insert("UsersRoles", QueryResults[LastResult].Unload());
	Total.UsersRoles.Indexes.Add("User");
	
	Return Total;
	
EndFunction

Function UserWithRoleProfiles(CurrentUser, Role)
	
	Query = New Query;
	Query.SetParameter("CurrentUser", CurrentUser);
	Query.SetParameter("Role", Role);
	
	Query.SetParameter("EmptyID",
		New UUID("00000000-0000-0000-0000-000000000000"));
	
	Query.Text =
	"SELECT DISTINCT
	|	Roles.Ref AS Profile
	|FROM
	|	InformationRegister.UserGroupContent AS UserGroupContent
	|		INNER JOIN Catalog.AccessGroups.Users AS AccessGroupsUsers
	|		ON (UserGroupContent.User = &CurrentUser)
	|			AND UserGroupContent.UserGroup = AccessGroupsUsers.User
	|			AND (UserGroupContent.Used)
	|			AND (Not AccessGroupsUsers.Ref.DeletionMark)
	|		INNER JOIN Catalog.AccessGroupProfiles.Roles AS Roles
	|		ON (Roles.Ref = AccessGroupsUsers.Ref.Profile)
	|			AND (Not Roles.Ref.DeletionMark)
	|			AND (Roles.Role.Name = &Role)";
	
	Return Query.Execute().Unload().UnloadColumn("Profile");
	
EndFunction

Procedure UpdateInfobaseUserRoles(UpdatedInfobaseUsers, ServiceUserPassword)
	
	For Each KeyAndValue In UpdatedInfobaseUsers Do
		RolesForAdding  = KeyAndValue.Value.RolesForAdding;
		RolesForDeletion    = KeyAndValue.Value.RolesForDeletion;
		IBUser     = KeyAndValue.Value.IBUser;
		UserRef = KeyAndValue.Value.UserRef;
		
		WereFullRights = IBUser.Roles.Contains(Metadata.Roles.FullAccess);
		
		For Each KeyAndValue In RolesForAdding Do
			IBUser.Roles.Add(Metadata.Roles[KeyAndValue.Key]);
		EndDo;
		
		For Each KeyAndValue In RolesForDeletion Do
			IBUser.Roles.Delete(Metadata.Roles[KeyAndValue.Key]);
		EndDo;
		
		WriteUserOnRolesUpdate(UserRef, IBUser, WereFullRights, ServiceUserPassword);
	EndDo;
	
EndProcedure

Procedure WriteUserOnRolesUpdate(UserRef, IBUser, WereFullRights, ServiceUserPassword)
	
	BeginTransaction();
	
	Try
		UsersInternal.WriteInfobaseUser(IBUser);
		
		If Not CommonUseCached.DataSeparationEnabled() Then
			CommitTransaction();
			Return;
		EndIf;
		
		ThereAreFullRights = IBUser.Roles.Contains(Metadata.Roles.FullAccess);
		If ThereAreFullRights = WereFullRights Then
			CommitTransaction();
			Return;
		EndIf;
		
		If ServiceUserPassword = Undefined Then
			
			If CommonUseCached.SessionWithoutSeparators() Then
				CommitTransaction();
				Return;
			EndIf;
			
			Raise
				NStr("en = 'To modify the administrative access,<o:p></o:p>
				           |service user password is required.<o:p></o:p>
				           |
				           |The operation can only be executed in interactive mode.'");
		EndIf;
		
		ServiceUserOnWrite(UserRef, False, ServiceUserPassword);
		
		CommitTransaction();
		
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// For the ChangeSelectionQueryText procedure

Function KeyAndValue(Structure)
	
	For Each KeyAndValue In Structure Do
		Return KeyAndValue;
	EndDo;
	
EndFunction

// For the UpdateRecordSet and UpdateRecordSets procedures

Function DimensionParameterGroupIsProcessed(DimensionName, DimensionValues)
	
	If DimensionName  = Undefined Then
		DimensionValues = Undefined;
		
	ElsIf DimensionValues = Undefined Then
		DimensionName = Undefined;
		
	ElsIf TypeOf(DimensionValues) <> Type("Array")
	        And TypeOf(DimensionValues) <> Type("FixedArray") Then
		
		DimensionValue  = DimensionValues;
		DimensionValues = New Array;
		DimensionValues.Add(DimensionValue);
		
	ElsIf DimensionValues.Count() = 0 Then
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

Procedure OrderDimensionParameterGroups(FirstDimensionName,
                                        FirstDimensionValues,
                                        SecondDimensionName,
                                        SecondDimensionValues,
                                        ThirdDimensionName,
                                        ThirdDimensionValues)
	
	If SecondDimensionName  = Undefined Then
		SecondDimensionName   = ThirdDimensionName;
		SecondDimensionValues = ThirdDimensionValues;
		ThirdDimensionName    = Undefined;
		ThirdDimensionValues  = Undefined;
	EndIf;
	
	If FirstDimensionName   = Undefined Then
		FirstDimensionName    = SecondDimensionName;
		FirstDimensionValues  = SecondDimensionValues;
		SecondDimensionName   = ThirdDimensionName;
		SecondDimensionValues = ThirdDimensionValues;
		ThirdDimensionName    = Undefined;
		ThirdDimensionValues  = Undefined;
	EndIf;
	
	If SecondDimensionValues  <> Undefined
	   And ThirdDimensionValues <> Undefined
	   And SecondDimensionValues.Count()
	   > ThirdDimensionValues.Count() Then
		
		DimensionName   = SecondDimensionName;
		DimensionValues = SecondDimensionValues;
		
		SecondDimensionName   = ThirdDimensionName;
		SecondDimensionValues = ThirdDimensionValues;
		ThirdDimensionName    = DimensionName;
		ThirdDimensionValues  = DimensionValues;
	EndIf;
	
	If FirstDimensionValues <> Undefined
	   And SecondDimensionValues <> Undefined
	   And FirstDimensionValues.Count()
	   > SecondDimensionValues.Count() Then
		
		DimensionName   = FirstDimensionName;
		DimensionValues = FirstDimensionValues;
		
		FirstDimensionName    = SecondDimensionName;
		FirstDimensionValues  = SecondDimensionValues;
		SecondDimensionName   = DimensionName;
		SecondDimensionValues = DimensionValues;
	EndIf;
	
EndProcedure

Function RecordSetFields(RecordSet)
	
	ComparisonFields = "";
	Table = RecordSet.Unload(New Array);
	For Each Column In Table.Columns Do
		ComparisonFields = ComparisonFields + "," + Column.Name;
	EndDo;
	ComparisonFields = Mid(ComparisonFields, 2);
	
	Return ComparisonFields;
	
EndFunction

Function RefreshNewSetRecordsForAllNewAccounts(Val Parameters,
                                               Val Filter,
                                               Val FieldList,
                                               Val DimensionName,
                                               Val DimensionValues,
                                               HasChanges,
                                               Val CheckOnly,
                                               Val AdditionalProperties)
	
	// Opening a transaction if it does not
	// exist or is not opened yet, in order to set a managed lock for the read record set.
	// In some situations (if the locked data match), a transaction may
	// be committed without any data changes.
	If Parameters.TransactionIsOpen = False Then
		Parameters.TransactionIsOpen = True;
		BeginTransaction();
	EndIf;
	
	LockRecordSetArea(Parameters.RecordSet, Parameters.RegisterFullName);
	
	Parameters.RecordSet.Read();
	NewRecordSets = Parameters.RecordSet.Unload();
	NewRecordSets.Indexes.Add(FieldList);
	
	For Each Value In DimensionValues Do
		Filter[DimensionName] = Value;
		FoundRecords = NewRecordSets.FindRows(Filter);
		For Each FoundRecord In NewRecordSets.FindRows(Filter) Do
			NewRecordSets.Delete(FoundRecord);
		EndDo;
		For Each FoundRecord In Parameters.NewRecords.FindRows(Filter) Do
			FillPropertyValues(NewRecordSets.Add(), FoundRecord);
		EndDo;
	EndDo;
	
	UpdateRecordSet(
		Parameters.RecordSet,
		NewRecordSets,
		Parameters.ComparisonFields,
		,
		,
		HasChanges,
		,
		Parameters.TransactionIsOpen,
		True,
		,
		CheckOnly,
		AdditionalProperties);
	
EndFunction

Procedure RefreshNewSetRecordsByDistinctNewRecords(Val Parameters,
                                                   Val Filter,
                                                   HasChanges,
                                                   Val CheckOnly,
                                                   Val AdditionalProperties)
	
	If Parameters.TransactionIsOpen = False Then
		Parameters.TransactionIsOpen = True;
		BeginTransaction();
	EndIf;
	
	// Getting the number of records to be read
	
	If Filter.Count() = 0 Then
		CurrentNewRecords = Parameters.NewRecords.Copy();
		CountForReading = Parameters.CountForReading;
	Else
		CurrentNewRecords = Parameters.NewRecords.Copy(Filter);
		
		FieldName = Parameters.CountByValues.Columns[0].Name;
		NumberRow = Parameters.CountByValues.Find(Filter[FieldName], FieldName);
		CountForReading = ?(NumberRow = Undefined, 0, NumberRow.Quantity);
	EndIf;
	
	NewRecordFilter = New Structure("RowChangeKind, " + Parameters.ComparisonFields, 1);
	CurrentNewRecords.Indexes.Add("RowChangeKind, " + Parameters.ComparisonFields);

	RecordsKeys = CurrentNewRecords.Copy(, "RowChangeKind, " + Parameters.ComparisonFields);
	RecordsKeys.GroupBy("RowChangeKind, " + Parameters.ComparisonFields);
	RecordsKeys.GroupBy(Parameters.ComparisonFields, "RowChangeKind");
	
	FilterByRecordKey = New Structure(Parameters.ComparisonFields);
	
	If CountForReading < 1000
	 Or (  CountForReading < 100000
	      And RecordsKeys.Count() * 50 > CountForReading) Then
		// Performing block update
		LockRecordSetArea(Parameters.RecordSet, Parameters.RegisterFullName);
		Parameters.RecordSet.Read();
		NewRecordSets = Parameters.RecordSet.Unload();
		NewRecordSets.Indexes.Add(Parameters.ComparisonFields);
		
		For Each Row In RecordsKeys Do
			FillPropertyValues(FilterByRecordKey, Row);
			FoundRows = NewRecordSets.FindRows(FilterByRecordKey);
			If Row.RowChangeKind = -1 Then
				If FoundRows.Count() > 0 Then
					// Deleting the old row
					NewRecordSets.Delete(FoundRows[0]);
				EndIf;
			Else
				// Adding a new row, or updating an existing row
				If FoundRows.Count() = 0 Then
					FillingRow = NewRecordSets.Add();
				Else
					FillingRow = FoundRows[0];
				EndIf;
				FillPropertyValues(NewRecordFilter, FilterByRecordKey);
				FoundRecords = CurrentNewRecords.FindRows(NewRecordFilter);
				If FoundRecords.Count() = 1 Then
					NewRecord = FoundRecords[0];
				Else // Error in the NewRecords parameter
					ExceptOnRecordSearchError(Parameters);
				EndIf;
				FillPropertyValues(FillingRow, NewRecord);
			EndIf;
		EndDo;
		// Changing the record set to make it different from the new records
		If Parameters.RecordSet.Count() = NewRecordSets.Count() Then
			Parameters.RecordSet.Add();
		EndIf;
		UpdateRecordSet(
			Parameters.RecordSet,
			NewRecordSets,
			Parameters.ComparisonFields,
			,
			,
			HasChanges,
			,
			Parameters.TransactionIsOpen,
			True,
			,
			CheckOnly,
			AdditionalProperties);
	Else
		// Updating by row
		SetAdditionalProperties(Parameters.SetForSingleRecord, AdditionalProperties);
		For Each Row In RecordsKeys Do
			Parameters.SetForSingleRecord.Clear();
			FillPropertyValues(FilterByRecordKey, Row);
			For Each KeyAndValue In FilterByRecordKey Do
				SetFilter(
					Parameters.SetForSingleRecord.Filter[KeyAndValue.Key], KeyAndValue.Value);
			EndDo;
			LockRecordSetArea(Parameters.SetForSingleRecord, Parameters.RegisterFullName);
			If Row.RowChangeKind > -1 Then
				// Adding a new row, or updating an existing row
				FillPropertyValues(NewRecordFilter, FilterByRecordKey);
				FoundRecords = CurrentNewRecords.FindRows(NewRecordFilter);
				If FoundRecords.Count() = 1 Then
					NewRecord = FoundRecords[0];
				Else // Error in the NewRecords parameter
					ExceptOnRecordSearchError(Parameters);
				EndIf;
				FillPropertyValues(Parameters.SetForSingleRecord.Add(), NewRecord);
			EndIf;
			HasChanges = True;
			If CheckOnly Then
				Return;
			EndIf;
			Parameters.SetForSingleRecord.Write();
		EndDo;
	EndIf;
	
EndProcedure

Procedure ExceptOnRecordSearchError(Parameters)
	
	For Each ChangeString In Parameters.NewRecords Do
		If ChangeString.RowChangeKind <>  1
		   And ChangeString.RowChangeKind <> -1 Then
			
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Error in the UpdateRecordSets procedure
				           |of the AccessManagementInternal common module.
				           |
				           |Invalid value of NewRecords parameter -
				           |RowChangeKind column contains a prohibited value ""%1"".
				           |
				           |Only 2 values are allowed: ""1"" and ""-1"".'"),
				String(ChangeString.RowChangeKind));
		EndIf;
	EndDo;
	
	Raise
		NStr("en = 'Error in the UpdateRecordSets procedure
		           |of the AccessManagementInternal common module.
		           |
		           |Failed to find the required string
		           |in NewRecords parameter value.'");
	
EndProcedure

Procedure LockRecordSetArea(RecordSet, RegisterFullName = Undefined)
	
	If Not TransactionActive() Then
		Return;
	EndIf;
	
	If RegisterFullName = Undefined Then
		RegisterFullName = Metadata.FindByType(TypeOf(RecordSet)).FullName();
	EndIf;
	
	DataLock = New DataLock;
	LockItem = DataLock.Add(RegisterFullName);
	LockItem.Mode = DataLockMode.Shared;
	For Each FilterItem In RecordSet.Filter Do
		If FilterItem.Use Then
			LockItem.SetValue(FilterItem.DataPath, FilterItem.Value);
		EndIf;
	EndDo;
	DataLock.Lock();
	
EndProcedure

Procedure SetFilter(FilterItem, FilterValue)
	
	FilterItem.Value = FilterValue;
	FilterItem.Use = True;
	
EndProcedure

Function RecordByMultipleSets(Parameters, Filter, FieldName, FieldValues)
	
	Query = New Query;
	Query.SetParameter("FieldValues", FieldValues);
	Query.Text =
	"SELECT
	|	COUNT(*) AS Quantity
	|FROM
	|	&CurrentTable AS CurrentTable
	|WHERE
	|	&FilterCriterion
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	COUNT(*) AS Quantity
	|FROM
	|	&CurrentTable AS CurrentTable
	|WHERE
	|	CurrentTable.FieldName IN(&FieldValues)
	|	AND &FilterCriterion
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CurrentTable.FieldName AS FieldName,
	|	COUNT(*) AS Quantity
	|FROM
	|	&CurrentTable AS CurrentTable
	|WHERE
	|	CurrentTable.FieldName IN(&FieldValues)
	|	AND &FilterCriterion
	|
	|GROUP BY
	|	CurrentTable.FieldName";
	
	FilterCriterion = "True";
	If Parameters.FixedFilter <> Undefined Then
		For Each KeyAndValue In Parameters.FixedFilter Do
			FilterCriterion = FilterCriterion + "
			|	And CurrentTable." + KeyAndValue.Key + " = &" + KeyAndValue.Key;
			Query.SetParameter(KeyAndValue.Key, KeyAndValue.Value);
		EndDo;
	EndIf;
	
	FilterAdded = New Structure;
	FilterAdded.Insert("RowChangeKind", 1);
	FilterOfRemoved = New Structure;
	FilterOfRemoved.Insert("RowChangeKind", -1);
	
	For Each KeyAndValue In Filter Do
		FilterCriterion = FilterCriterion + "
		|	And CurrentTable." + KeyAndValue.Key + " = &" + KeyAndValue.Key;
		Query.SetParameter(KeyAndValue.Key, KeyAndValue.Value);
		FilterAdded.Insert(KeyAndValue.Key, KeyAndValue.Value);
		FilterOfRemoved.Insert(KeyAndValue.Key, KeyAndValue.Value);
	EndDo;
	
	Query.Text = StrReplace(Query.Text, "FieldName", FieldName);
	Query.Text = StrReplace(Query.Text, "&CurrentTable", Parameters.RegisterFullName);
	Query.Text = StrReplace(Query.Text, "&FilterCriterion", FilterCriterion);
	
	QueryResults = Query.ExecuteBatch();
	
	// Total number of items without filter
	QuantityOfAll = QueryResults[0].Unload()[0].Quantity;
	Parameters.Insert("CountForReading", QuantityOfAll);
	
	// Number of items with filter to be updated
	UpdatedCount = QueryResults[1].Unload()[0].Quantity;
	
	ItemsToAddCount = Parameters.NewRecords.FindRows(FilterAdded).Count();
	If ItemsToAddCount > UpdatedCount Then
		UpdatedCount = ItemsToAddCount;
	EndIf;
	
	ToDeleteCount = Parameters.NewRecords.FindRows(FilterOfRemoved).Count();
	If ToDeleteCount > UpdatedCount Then
		UpdatedCount = ToDeleteCount;
	EndIf;
	
	// Number of items to be read by the filter values
	CountByValues = QueryResults[2].Unload();
	CountByValues.Indexes.Add(FieldName);
	Parameters.Insert("CountByValues", CountByValues);
	
	Return QuantityOfAll * 0.7 > UpdatedCount;
	
EndFunction

Procedure ReadCountForReading(Parameters)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	COUNT(*) AS Quantity
	|FROM
	|	&CurrentTable AS CurrentTable
	|WHERE
	|	&FilterCriterion";
	
	FilterCriterion = "True";
	If Parameters.FixedFilter <> Undefined Then
		For Each KeyAndValue In Parameters.FixedFilter Do
			FilterCriterion = FilterCriterion + "
			|	And CurrentTable." + KeyAndValue.Key + " = &" + KeyAndValue.Key;
			Query.SetParameter(KeyAndValue.Key, KeyAndValue.Value);
		EndDo;
	EndIf;
	
	Query.Text = StrReplace(Query.Text, "&CurrentTable", Parameters.RegisterFullName);
	Query.Text = StrReplace(Query.Text, "&FilterCriterion", FilterCriterion);
	
	QueryResults = Query.ExecuteBatch();
	
	Parameters.Insert("CountForReading", Query.Execute().Unload()[0].Quantity);
	
EndProcedure

Procedure SetAdditionalProperties(RecordSet, AdditionalProperties)
	
	If TypeOf(AdditionalProperties) = Type("Structure") Then
		For Each KeyAndValue In AdditionalProperties Do
			RecordSet.AdditionalProperties.Insert(KeyAndValue.Key, KeyAndValue.Value);
		EndDo;
	EndIf;
	
EndProcedure

// For the UpdateInformationRegister procedure

Function TableColumnValues(Table, ColumnName)
	
	NewTable = Table.Copy(, ColumnName);
	
	NewTable.GroupBy(ColumnName);
	
	Return NewTable.UnloadColumn(ColumnName);
	
EndFunction

// Management of AccessKinds and AccessValues tables used in the edit forms

Procedure AddAuxiliaryDataAttributesToForm(Form, TableStorageAttributeName)
	
	AttributesToBeAdded = New Array;
	AccessValueTypeDescription = Metadata.DefinedTypes.AccessValue.Type;
	
	PathToObject = ?(ValueIsFilled(TableStorageAttributeName), TableStorageAttributeName + ".", "");
	
	// Adding attributes to the AccessKinds table
	AttributesToBeAdded.Add(New FormAttribute(
		"Used", New TypeDescription("Boolean"), PathToObject + "AccessKinds"));
	
	// Adding individual attributes
	AttributesToBeAdded.Add(New FormAttribute(
		"CurrentAccessKind", AccessValueTypeDescription));
	
	AttributesToBeAdded.Add(New FormAttribute(
		"CurrentTypesOfValuesToSelect", New TypeDescription("ValueList")));
	
	AttributesToBeAdded.Add(New FormAttribute(
		"CurrentTypeOfValuesToSelect", AccessValueTypeDescription));
	
	If Not FormAttributeExists(Form, "UseExternalUsers") Then
		AttributesToBeAdded.Add(New FormAttribute(
			"UseExternalUsers", New TypeDescription("Boolean")));
	EndIf;
	
	AttributesToBeAdded.Add(New FormAttribute(
		"TableStorageAttributeName", New TypeDescription("String")));
	
	AttributesToBeAdded.Add(New FormAttribute(
		"IsAccessGroupProfile", New TypeDescription("Boolean")));
	
	AttributesToBeAdded.Add(New FormAttribute(
		"AccessKindUsers", AccessValueTypeDescription));
	
	AttributesToBeAdded.Add(New FormAttribute(
		"AccessKindExternalUsers", AccessValueTypeDescription));
	
	// Adding the AllAccessKinds table
	AttributesToBeAdded.Add(New FormAttribute(
		"AllAccessKinds", New TypeDescription("ValueTable")));
	
	AttributesToBeAdded.Add(New FormAttribute(
		"Ref", AccessValueTypeDescription, "AllAccessKinds"));
	
	AttributesToBeAdded.Add(New FormAttribute(
		"Presentation", New TypeDescription("String"), "AllAccessKinds"));
	
	AttributesToBeAdded.Add(New FormAttribute(
		"Used", New TypeDescription("Boolean"), "AllAccessKinds"));
	
	// Adding the PresentationsAllAllowed table
	AttributesToBeAdded.Add(New FormAttribute(
		"PresentationsAllAllowed", New TypeDescription("ValueTable")));
	
	AttributesToBeAdded.Add(New FormAttribute(
		"Name", New TypeDescription("String"), "PresentationsAllAllowed"));
	
	AttributesToBeAdded.Add(New FormAttribute(
		"Presentation", New TypeDescription("String"), "PresentationsAllAllowed"));
	
	// Adding the AllTypesOfValuesToSelect table
	AttributesToBeAdded.Add(New FormAttribute(
		"AllTypesOfValuesToSelect", New TypeDescription("ValueTable")));
	
	AttributesToBeAdded.Add(New FormAttribute(
		"AccessKind", AccessValueTypeDescription, "AllTypesOfValuesToSelect"));
	
	AttributesToBeAdded.Add(New FormAttribute(
		"ValueType", AccessValueTypeDescription, "AllTypesOfValuesToSelect"));
	
	AttributesToBeAdded.Add(New FormAttribute(
		"TypePresentation", New TypeDescription("String"), "AllTypesOfValuesToSelect"));
	
	AttributesToBeAdded.Add(New FormAttribute(
		"TableName", New TypeDescription("String"), "AllTypesOfValuesToSelect"));
	
	Form.ChangeAttributes(AttributesToBeAdded);
	
EndProcedure

Procedure FillTableAllAccessKindsInForm(Form)
	
	For Each AccessKindProperties In AccessKindProperties() Do
		Row = Form.AllAccessKinds.Add();
		Row.Ref        = AccessKindProperties.Ref;
		Row.Used  = AccessKindUsed(Row.Ref);
		// Making sure the presentations are unique
		Presentation = AccessKindProperties.Presentation;
		Filter = New Structure("Presentation", Presentation);
		While Form.AllAccessKinds.FindRows(Filter).Count() > 0 Do
			Filter.Presentation = Filter.Presentation + " ";
		EndDo;
		Row.Presentation = Presentation;
	EndDo;
	
EndProcedure

Procedure FillPresentationTableAllAllowedInForm(Form, ThisProfile)
	
	If ThisProfile Then
		Row = Form.PresentationsAllAllowed.Add();
		Row.Name = "InitiallyAllProhibited";
		Row.Presentation = NStr("en = 'All prohibited, exceptions are set in access groups'");
		
		Row = Form.PresentationsAllAllowed.Add();
		Row.Name = "InitiallyAllAllowed";
		Row.Presentation = NStr("en = 'All allowed, exceptions are set in access groups'");
		
		Row = Form.PresentationsAllAllowed.Add();
		Row.Name = "AllProhibited";
		Row.Presentation = NStr("en = 'All prohibited, exceptions are set in a profile'");
		
		Row = Form.PresentationsAllAllowed.Add();
		Row.Name = "AllAllowed";
		Row.Presentation = NStr("en = 'All allowed, exceptions are set in a profile'");
	Else
		Row = Form.PresentationsAllAllowed.Add();
		Row.Name = "AllProhibited";
		Row.Presentation = NStr("en = 'All prohibited'");
		
		Row = Form.PresentationsAllAllowed.Add();
		Row.Name = "AllAllowed";
		Row.Presentation = NStr("en = 'All allowed'");
	EndIf;
	
	ChoiceList = Form.Items.AccessKindsAllAllowedPresentation.ChoiceList;
	
	For Each Row In Form.PresentationsAllAllowed Do
		ChoiceList.Add(Row.Presentation);
	EndDo;
	
EndProcedure

Procedure ApplyTableAccessKindsInForm(Form)
	
	Parameters = AllowedValuesEditingFormParameters(Form);
	
	// Managing the appearance of unused access types
	ConditionalAppearanceItem = Form.ConditionalAppearance.Items.Add();
	
	AppearanceColorItem = ConditionalAppearanceItem.Appearance.Items.Find("TextColor");
	AppearanceColorItem.Value = WebColors.Gray;
	AppearanceColorItem.Use = True;
	
	DataSelectionElementGroup = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	DataSelectionElementGroup.GroupType = DataCompositionFilterItemsGroupType.AndGroup;
	DataSelectionElementGroup.Use = True;
	
	DataFilterItem = DataSelectionElementGroup.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue  = New DataCompositionField(Parameters.PathToTables + "AccessKinds.AccessKind");
	DataFilterItem.ComparisonType   = DataCompositionComparisonType.NotEqual;
	DataFilterItem.RightValue = Undefined;
	DataFilterItem.Use  = True;
	
	DataFilterItem = DataSelectionElementGroup.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue  = New DataCompositionField(Parameters.PathToTables + "AccessKinds.Used");
	DataFilterItem.ComparisonType   = DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue = False;
	DataFilterItem.Use  = True;
	
	FieldAppearanceItem = ConditionalAppearanceItem.Fields.Items.Add();
	FieldAppearanceItem.Field = New DataCompositionField("AccessKinds");
	FieldAppearanceItem.Use = True;
	
EndProcedure

Procedure DeleteExcessAccessValues(Form, CurrentObject = Undefined)
	
	Parameters = AllowedValuesEditingFormParameters(Form, CurrentObject);
	
	ByGroupTypesAndValues = AccessManagementInternalCached.Parameters(
		).AccessKindsProperties.ByGroupTypesAndValues;
	
	Filter = AccessManagementInternalClientServer.FilterInAllowedValuesEditingFormTables(
		Form, "");
	
	Index = Parameters.AccessValues.Count()-1;
	While Index >= 0 Do
		AccessValue = Parameters.AccessValues[Index].AccessValue;
		
		AccessKindProperties = ByGroupTypesAndValues.Get(TypeOf(AccessValue));
		If AccessKindProperties <> Undefined Then
			FillPropertyValues(Filter, Parameters.AccessValues[Index]);
			Filter.Insert("AccessKind", AccessKindProperties.Ref);
		EndIf;
		
		If AccessKindProperties = Undefined
		 Or Parameters.AccessValues[Index].AccessKind <> Filter.AccessKind
		 Or Parameters.AccessKinds.FindRows(Filter).Count() = 0 Then
			
			Parameters.AccessValues.Delete(Index);
		EndIf;
		Index = Index - 1;
	EndDo;
	
EndProcedure

Procedure DeleteNotExistingKindsAndAccessValues(Form, CurrentObject = Undefined)
	
	Parameters = AllowedValuesEditingFormParameters(Form, CurrentObject);
	
	Index = Parameters.AccessKinds.Count()-1;
	While Index >= 0 Do
		AccessKind = Parameters.AccessKinds[Index].AccessKind;
		If AccessKindProperties(AccessKind) = Undefined Then
			Parameters.AccessKinds.Delete(Index);
		EndIf;
		Index = Index - 1;
	EndDo;
	
	DeleteExcessAccessValues(Form, CurrentObject);
	
EndProcedure

Function AllowedValuesEditingFormParameters(Form, CurrentObject = Undefined)
	
	Return AccessManagementInternalClientServer.AllowedValuesEditingFormParameters(
		Form, CurrentObject);
	
EndFunction

Function FormAttributeExists(Form, AttributeName)
	
	Structure = New Structure(AttributeName, Null);
	
	FillPropertyValues(Structure, Form);
	
	Return Structure[AttributeName] <> Null;
	
EndFunction

// For the SessionParametersSetting procedure

Function AllAccessKindCombinations(UnorderedNameArray) Export
	
	// Maximum combination length limit,
	// to prevent overloading of the session parameters and RLS template preprocessor.
	MaximumCombinationLength = 4;
	
	List = New ValueList;
	If TypeOf(UnorderedNameArray) = Type("FixedArray") Then
		List.LoadValues(New Array(UnorderedNameArray));
	Else
		List.LoadValues(UnorderedNameArray);
	EndIf;
	List.SortByValue();
	NameArray = List.UnloadValues();
	
	Total = "";
	
	// Full list is always supported
	For Each Name In NameArray Do
		Total = Total + "," + Name;
	EndDo;
	
	Total = Total + "," + Chars.LF;
	
	If NameArray.Count() < 3 Then
		Return Total;
	EndIf;
	
	FirstName = NameArray[0];
	NameArray.Delete(0);
	
	LastName = NameArray[NameArray.Count()-1];
	NameArray.Delete(NameArray.Count()-1);
	
	CountOfNamesInCombination = NameArray.Count();
	
	If CountOfNamesInCombination > 1 Then
		
		If (CountOfNamesInCombination-1) <= MaximumCombinationLength Then
			CombinationLength = CountOfNamesInCombination-1;
		Else
			CombinationLength = MaximumCombinationLength;
		EndIf;
		
		NamePositionsInCombination = New Array;
		For Counter = 1 To CombinationLength Do
			NamePositionsInCombination.Add(Counter);
		EndDo;
		
		While CombinationLength > 0 Do
			While True Do
				// Adding the combination from current positions
				Total = Total + "," + FirstName;
				For Index = 0 To CombinationLength-1 Do
					Total = Total + "," + NameArray[NamePositionsInCombination[Index]-1];
				EndDo;
				Total = Total + "," + LastName + "," + Chars.LF;
				// Increasing position in combination<o:p></o:p>
				Index = CombinationLength-1;
				While Index >= 0 Do
					If NamePositionsInCombination[Index] < CountOfNamesInCombination - (CombinationLength - (Index+1)) Then
						NamePositionsInCombination[Index] = NamePositionsInCombination[Index] + 1;
						// Filling the senior positions with initial values
						For SeniorPositionIndex = Index+1 To CombinationLength-1 Do
							NamePositionsInCombination[SeniorPositionIndex] =
								NamePositionsInCombination[Index] + SeniorPositionIndex - Index;
						EndDo;
						Break;
					Else
						Index = Index - 1;
					EndIf;
				EndDo;
				If Index < 0 Then
					Break;
				EndIf;
			EndDo;
			CombinationLength = CombinationLength - 1;
			For Index = 0 To CombinationLength - 1 Do
				NamePositionsInCombination[Index] = Index + 1;
			EndDo;
		EndDo;
	EndIf;
	
	Total = Total + "," + FirstName+ "," + LastName + "," + Chars.LF;
	
	Return Total;
	
EndFunction

// For the UpdateAccessValueSets, OnChangeAccessValueSets procedures

// Checks whether sets in tabular section differ from the new sets.
Function AccessValueSetsOfTabularSectionChanged(ObjectRef, NewSets)
	
	OldSets = CommonUse.ObjectAttributeValue(
		ObjectRef, "AccessValueSets").Unload();
	
	If OldSets.Count() <> NewSets.Count() Then
		Return True;
	EndIf;
	
	OldSets.Columns.Add("AccessKind", New TypeDescription("String"));
	AccessManagement.AddAccessValueSets(
		OldSets, AccessManagement.AccessValueSetTable(), False, True);
	
	SearchFields = "SetNumber, AccessValue, Adjustment, Read, Update";
	
	NewSets.Indexes.Add(SearchFields);
	Filter = New Structure(SearchFields);
	
	For Each Row In OldSets Do
		FillPropertyValues(Filter, Row);
		If NewSets.FindRows(Filter).Count() <> 1 Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

#EndRegion