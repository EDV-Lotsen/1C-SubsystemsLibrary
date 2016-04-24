////////////////////////////////////////////////////////////////////////////////
// Access management subsystem
// 
////////////////////////////////////////////////////////////////////////////////

#Region Interface

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions that are used to check rights

// Checks whether the user has a role in one of the profiles of the access groups where they participate.
// For example, ViewEventLog role, UnpostedDocumentPrint role.
//
// If an object (or access value set) is specified, then an additional check is made
// whether the access group provides Read right for the specified object (or the specified access value set is allowed).
// whether the access group provides Read right for the specified object (or the specified access value set is allowed).
//
// Parameters:
//  Role           - String - Role name.
//
//  ObjectRef      - Ref    - reference to the object for which the access values
//                   sets are filled to check Read right.
//                 - ValueTable - table of arbitrary access value sets with columns:
//                     * SetNumber   - Number  - number grouping multiple rows in a separate set.
//                     * AccessKind  - String  - name of an access kind specified in the overridable module.
//                     * AccessValue - Ref  - reference to the access value type specified in the overridable module.
//                       To generate an empty table,  
//                       use the AccessValueSetTable function
//                       of the AccessManagement common module (do not fill Read or Change columns).
//
//  User           - CatalogRef.Users, CatalogRef.ExternalUsers, Undefined - if
//                   this parameter is not specified, right of the current user is checked.
//
// Returns:
//  Boolean - If True, the user has a role with restrictions.
//
Function RoleExists(Val Role, Val ObjectRef = Undefined, Val User = Undefined) Export
	
	User = ?(ValueIsFilled(User), User, Users.AuthorizedUser());
	If Users.InfobaseUserWithFullAccess(User) Then
		Return True;
	EndIf;
	
	SetPrivilegedMode(True);
	
	If ObjectRef = Undefined Or Not UseRecordLevelSecurity() Then
		// Checking that the role is assigned to the user through access group profile
		Query = New Query;
		Query.SetParameter("AuthorizedUser", User);
		Query.SetParameter("Role", Role);
		Query.Text =
		"SELECT TOP 1
		|	TRUE AS TrueValue
		|FROM
		|	Catalog.AccessGroups.Users AS AccessGroupsUsers
		|		INNER JOIN InformationRegister.UserGroupContent AS UserGroupContent
		|		ON (UserGroupContent.User = &AuthorizedUser)
		|			AND (UserGroupContent.UserGroup = AccessGroupsUsers.User)
		|			AND (UserGroupContent.Used)
		|			AND (Not AccessGroupsUsers.Ref.DeletionMark)
		|		INNER JOIN Catalog.AccessGroupProfiles.Roles AS AccessGroupProfilesRoles
		|		ON AccessGroupsUsers.Ref.Profile = AccessGroupProfilesRoles.Ref
		|			AND (AccessGroupProfilesRoles.Role.Name = &Role)
		|			AND (Not AccessGroupProfilesRoles.Ref.DeletionMark)";
		Return Not Query.Execute().IsEmpty();
	EndIf;
		
	If TypeOf(ObjectRef) = Type("ValueTable") Then
		AccessValueSets = ObjectRef.Copy();
	Else
		AccessValueSets = AccessValueSetTable();
		ObjectRef.GetObject().FillAccessValueSets(AccessValueSets);
		// Selecting the access value sets used to check Read right
		ReadingSetRows = AccessValueSets.FindRows(New Structure("Read", True));
		SetNumbers = New Map;
		For Each Row In ReadingSetRows Do
			SetNumbers.Insert(Row.SetNumber, True);
		EndDo;
		Index = AccessValueSets.Count()-1;
		While Index > 0 Do
			If SetNumbers[AccessValueSets[Index].SetNumber] = Undefined Then
				AccessValueSets.Delete(Index);
			EndIf;
			Index = Index - 1;
		EndDo;
		AccessValueSets.FillValues(False, "Read, Change");
	EndIf;
	
	// Adjusting the access value sets
	AccessKindNames = AccessManagementInternalCached.Parameters().AccessKindsProperties.ByNames;
	
	For Each Row In AccessValueSets Do
		
		If Row.AccessKind = "" Then
			Continue;
		EndIf;
		
		If Upper(Row.AccessKind) = Upper("ReadRight")
		 Or Upper(Row.AccessKind) = Upper("EditRight") Then
			
			If TypeOf(Row.AccessValue) <> Type("CatalogRef.MetadataObjectIDs") Then
				If CommonUse.IsReference(TypeOf(Row.AccessValue)) Then
					Row.AccessValue = CommonUse.MetadataObjectID(TypeOf(Row.AccessValue));
				Else
					Row.AccessValue = Undefined;
				EndIf;
			EndIf;
			
			If Upper(Row.AccessKind) = Upper("EditRight") Then
				Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Error in the RoleExists function of AccessManagement module.
				           |Access kind EditRight is specified in the access value set for table with identifier %1.
				           |Checking the role (as an additional right)
				           |can be restricted only by Read right.'"),
					Row.AccessValue);
			EndIf;
		ElsIf AccessKindNames.Get(Row.AccessKind) <> Undefined
		      Or Row.AccessKind = "RightsSettings" Then
			
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Error in the RoleExists function of AccessManagement module.
				           |An access value set contains a known access kind ""%2
				           |which does not have to be specified.
				           |
				           |You need to specify only ReadRight and EditRight access types
				           |if they are used.'"),
				TypeOf(ObjectRef),
				Row.AccessKind);
		Else
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Error in the RoleExists function of AccessManagement module.
				           |Access value set contains unknown access kind %2.'"),
				TypeOf(ObjectRef),
				Row.AccessKind);
		EndIf;
		
		Row.AccessKind = "";
	EndDo;
	
	// Adding internal fields to an access value set
	AccessManagementInternal.PrepareAccessValueSetsForRecord(Undefined, AccessValueSets, True);
	
	// Checking that the role is assigned to the user through access group by using 
 // a profile with allowed access value sets
	
	Query = New Query;
	Query.SetParameter("AuthorizedUser", User);
	Query.SetParameter("Role", Role);
	Query.SetParameter("AccessValueSets", AccessValueSets);
	Query.SetParameter("RightsSettingsOwnerTypes", SessionParameters.RightsSettingsOwnerTypes);
	Query.Text =
	"SELECT DISTINCT
	|	AccessValueSets.SetNumber,
	|	AccessValueSets.AccessValue,
	|	AccessValueSets.ValueWithoutGroups,
	|	AccessValueSets.StandardValue
	|INTO AccessValueSets
	|FROM
	|	&AccessValueSets AS AccessValueSets
	|
	|INDEX BY
	|	AccessValueSets.SetNumber,
	|	AccessValueSets.AccessValue
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	AccessGroupsUsers.Ref AS Ref
	|INTO AccessGroups
	|FROM
	|	Catalog.AccessGroups.Users AS AccessGroupsUsers
	|		INNER JOIN InformationRegister.UserGroupContent AS UserGroupContent
	|		ON (UserGroupContent.User = &AuthorizedUser)
	|			AND (UserGroupContent.UserGroup = AccessGroupsUsers.User)
	|			AND (UserGroupContent.Used)
	|			AND (Not AccessGroupsUsers.Ref.DeletionMark)
	|		INNER JOIN Catalog.AccessGroupProfiles.Roles AS AccessGroupProfilesRoles
	|		ON AccessGroupsUsers.Ref.Profile = AccessGroupProfilesRoles.Ref
	|			AND (AccessGroupProfilesRoles.Role.Name = &Role)
	|			AND (Not AccessGroupProfilesRoles.Ref.DeletionMark)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	Sets.SetNumber
	|INTO SetNumbers
	|FROM
	|	AccessValueSets AS Sets
	|
	|INDEX BY
	|	Sets.SetNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	AccessGroups AS AccessGroups
	|WHERE
	|	Not(TRUE IN
	|					(SELECT TOP 1
	|						TRUE
	|					FROM
	|						SetNumbers AS SetNumbers
	|					WHERE
	|						TRUE IN
	|							(SELECT TOP 1
	|								TRUE
	|							FROM
	|								AccessValueSets AS ValueSets
	|							WHERE
	|								ValueSets.SetNumber = SetNumbers.SetNumber
	|								AND Not TRUE IN
	|										(SELECT TOP 1
	|											TRUE
	|										FROM
	|											InformationRegister.DefaultAccessGroupValues AS DefaultValues
	|										WHERE
	|											DefaultValues.AccessGroup = AccessGroups.Ref
	|											AND VALUETYPE(DefaultValues.AccessValueType) = VALUETYPE(ValueSets.AccessValue)
	|											AND DefaultValues.NoSettings = TRUE)))
	|				AND Not TRUE IN
	|						(SELECT TOP 1
	|							TRUE
	|						FROM
	|							SetNumbers AS SetNumbers
	|						WHERE
	|							TRUE IN
	|								(SELECT TOP 1
	|									TRUE
	|								FROM
	|									AccessValueSets AS ValueSets
	|								WHERE
	|									ValueSets.SetNumber = SetNumbers.SetNumber
	|									AND Not TRUE IN
	|											(SELECT TOP 1
	|												TRUE
	|											FROM
	|												InformationRegister.DefaultAccessGroupValues AS DefaultValues
	|											WHERE
	|												DefaultValues.AccessGroup = AccessGroups.Ref
	|												AND VALUETYPE(DefaultValues.AccessValueType) = VALUETYPE(ValueSets.AccessValue)
	|												AND DefaultValues.NoSettings = TRUE))
	|							AND Not FALSE IN
	|									(SELECT TOP 1
	|										FALSE
	|									FROM
	|										AccessValueSets AS ValueSets
	|									WHERE
	|										ValueSets.SetNumber = SetNumbers.SetNumber
	|										AND Not CASE
	|												WHEN ValueSets.ValueWithoutGroups
	|													THEN TRUE IN
	|															(SELECT TOP 1
	|																TRUE
	|															FROM
	|																InformationRegister.DefaultAccessGroupValues AS DefaultValues
	|																	LEFT JOIN InformationRegister.AccessGroupValues AS Values
	|																	ON
	|																		Values.AccessGroup = AccessGroups.Ref
	|																			AND Values.AccessValue = ValueSets.AccessValue
	|															WHERE
	|																DefaultValues.AccessGroup = AccessGroups.Ref
	|																AND VALUETYPE(DefaultValues.AccessValueType) = VALUETYPE(ValueSets.AccessValue)
	|																AND ISNULL(Values.ValueIsAllowed, DefaultValues.AllAllowed))
	|												WHEN ValueSets.StandardValue
	|													THEN CASE
	|															WHEN TRUE IN
	|																	(SELECT TOP 1
	|																		TRUE
	|																	FROM
	|																		InformationRegister.AccessValueGroups AS AccessValueGroups
	|																	WHERE
	|																		AccessValueGroups.AccessValue = ValueSets.AccessValue
	|																		AND AccessValueGroups.AccessValueGroup = &AuthorizedUser)
	|																THEN TRUE
	|															ELSE TRUE IN
	|																	(SELECT TOP 1
	|																		TRUE
	|																	FROM
	|																		InformationRegister.DefaultAccessGroupValues AS DefaultValues
	|																			INNER JOIN InformationRegister.AccessValueGroups AS ValueGroups
	|																			ON
	|																				ValueGroups.AccessValue = ValueSets.AccessValue
	|																					AND DefaultValues.AccessGroup = AccessGroups.Ref
	|																					AND VALUETYPE(DefaultValues.AccessValueType) = VALUETYPE(ValueSets.AccessValue)
	|																			LEFT JOIN InformationRegister.AccessGroupValues AS Values
	|																			ON
	|																				Values.AccessGroup = AccessGroups.Ref
	|																					AND Values.AccessValue = ValueGroups.AccessValueGroup
	|																	WHERE
	|																		ISNULL(Values.ValueIsAllowed, DefaultValues.AllAllowed))
	|														END
	|												WHEN ValueSets.AccessValue = VALUE(Enum.AdditionalAccessValues.AccessAllowed)
	|													THEN TRUE
	|												WHEN ValueSets.AccessValue = VALUE(Enum.AdditionalAccessValues.AccessDenied)
	|													THEN FALSE
	|												WHEN VALUETYPE(ValueSets.AccessValue) = TYPE(Catalog.MetadataObjectIDs)
	|													THEN TRUE IN
	|															(SELECT TOP 1
	|																TRUE
	|															FROM
	|																InformationRegister.AccessGroupTables AS AccessGroupTablesObjectRightCheck
	|															WHERE
	|																AccessGroupTablesObjectRightCheck.AccessGroup = AccessGroups.Ref
	|																AND AccessGroupTablesObjectRightCheck.Table = ValueSets.AccessValue)
	|												ELSE TRUE IN
	|															(SELECT TOP 1
	|																TRUE
	|															FROM
	|																InformationRegister.ObjectRightsSettings AS RightsSettings
	|																	INNER JOIN InformationRegister.ObjectRightsSettingsInheritance AS SettingsInheritance
	|																	ON
	|																		SettingsInheritance.Object = ValueSets.AccessValue
	|																			AND RightsSettings.Object = SettingsInheritance.Parent
	|																			AND SettingsInheritance.UsageLevel < RightsSettings.ReadingPermissionLevel
	|																	INNER JOIN InformationRegister.UserGroupContent AS UserGroupContent
	|																	ON
	|																		UserGroupContent.User = &AuthorizedUser
	|																			AND UserGroupContent.UserGroup = RightsSettings.User)
	|														AND Not FALSE IN
	|																(SELECT TOP 1
	|																	FALSE
	|																FROM
	|																	InformationRegister.ObjectRightsSettings AS RightsSettings
	|																		INNER JOIN InformationRegister.ObjectRightsSettingsInheritance AS SettingsInheritance
	|																		ON
	|																			SettingsInheritance.Object = ValueSets.AccessValue
	|																				AND RightsSettings.Object = SettingsInheritance.Parent
	|																				AND SettingsInheritance.UsageLevel < RightsSettings.ReadingProhibitionLevel
	|																		INNER JOIN InformationRegister.UserGroupContent AS UserGroupContent
	|																		ON
	|																			UserGroupContent.User = &AuthorizedUser
	|																				AND UserGroupContent.UserGroup = RightsSettings.User)
	|											END)))";
	
	Return Not Query.Execute().IsEmpty();
	
EndFunction

// Checks whether object right permissions are set up for the user.
//  For example, RightsManagement, Read and FolderChange rights can be set up
//  for a file directory; 
//  the Read right applies both to the directory and the files.
//
// Parameters:
//  Right          - String - name of the right as it is specified in
//                   the OnFillAvailableRightsForObjectRightsSettings procedure
//                   of the AccessManagementOverridable common module.
//
//  ObjectRef - CatalogRef, ChartOfCharacteristicTypesRef - reference to one
//                   of the right owners specified
//                   in the OnFillAvailableRightsForObjectRightsSettings
//                   procedure of the AccessManagementOverridable common module;
//                   for example, a reference to file directory.
//
//  User   - CatalogRef.Users, CatalogRef.ExternalUsers, Undefined - if
//                   the parameter is not specified, right of the current user is checked.
//
// Returns:
//  Boolean - if True, right permission is set up in accordance with
//            all allowed and prohibited settings in the hierarchy.
//
Function HasRight(Right, ObjectRef, User = Undefined) Export
	
	User = ?(ValueIsFilled(User), User, Users.AuthorizedUser());
	If Users.InfobaseUserWithFullAccess(User) Then
		Return True;
	EndIf;
	
	If Not UseRecordLevelSecurity() Then
		Return True;
	EndIf;
	
	SetPrivilegedMode(True);
	RightDescription = AccessManagementInternalCached.Parameters(
		).AvailableRightsForObjectRightsSettings.ByTypes.Get(TypeOf(ObjectRef));
	
	If RightDescription = Undefined Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Description of available rights for table %1 is not found.'"),
			ObjectRef.Metadata().FullName());
	EndIf;
	
	RightDetails = RightDescription.Get(Right);
	
	If RightDetails = Undefined Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Description of right %1 for table %2 is not found'"),
			Right,
			ObjectRef.Metadata().FullName());
	EndIf;
	
	If Not ValueIsFilled(ObjectRef) Then
		Return False;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("ObjectRef", ObjectRef);
	Query.SetParameter("User", User);
	Query.SetParameter("Right", Right);
	
	Query.Text =
	"SELECT TOP 1
	|	TRUE AS TrueValue
	|WHERE
	|	TRUE IN
	|			(SELECT TOP 1
	|				TRUE
	|			FROM
	|				InformationRegister.ObjectRightsSettings AS RightsSettings
	|					INNER JOIN InformationRegister.ObjectRightsSettingsInheritance AS SettingsInheritance
	|					ON
	|						SettingsInheritance.Object = &ObjectRef
	|							AND RightsSettings.Right = &Right
	|							AND SettingsInheritance.UsageLevel < RightsSettings.RightPermissionLevel
	|							AND RightsSettings.Object = SettingsInheritance.Parent
	|					INNER JOIN InformationRegister.UserGroupContent AS UserGroupContent
	|					ON
	|						UserGroupContent.User = &User
	|							AND UserGroupContent.UserGroup = RightsSettings.User)
	|	AND Not FALSE IN
	|				(SELECT TOP 1
	|					FALSE
	|				FROM
	|					InformationRegister.ObjectRightsSettings AS RightsSettings
	|						INNER JOIN InformationRegister.ObjectRightsSettingsInheritance AS SettingsInheritance
	|						ON
	|							SettingsInheritance.Object = &ObjectRef
	|								AND RightsSettings.Right = &Right
	|								AND SettingsInheritance.UsageLevel < RightsSettings.RightProhibitionLevel
	|								AND RightsSettings.Object = SettingsInheritance.Parent
	|						INNER JOIN InformationRegister.UserGroupContent AS UserGroupContent
	|						ON
	|							UserGroupContent.User = &User
	|								AND UserGroupContent.UserGroup = RightsSettings.User)";
	
	Return Not Query.Execute().IsEmpty();
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions used to get common subsystem settings

// Checks whether access restriction is used at the record level.
//
// Returns:
//  Boolean - if True, access is restricted at the record level.
//
Function UseRecordLevelSecurity() Export
	
	SetPrivilegedMode(True);
	
	Return GetFunctionalOption("UseRecordLevelSecurity");
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions that are used for managed form interface settings

// Configures a form of access value which uses
// access value groups to select allowed values in the user access groups.
//
// Supported only in cases when only a single access value group is selected,
// for an access value.
//
// For the AccessGroup form item associated with the AccessGroup attribute,
// it sets the access value group list to the selection parameter providing access to change access values.
//
// When creating new access values, if the number of access value groups
// that provide access to change an access value is zero, an exception will be raised.
//
// If database already contains an access value group that does not provide
// access to change an access value, or the number of access value groups that
// provide access to change the access values is zero, the ReadOnly form
// parameter is set to True.
//
// If neither a restriction at the record level or restriction by access kind
// is used, the form item is hidden.
//
// Parameters:
//  Form        - ManagedForm - a form of an
//                   access value that uses groups to select allowed values.
//
//  Attribute   - Undefined - name of the form attribute is Object.AccessGroup.
//              - String - name of form attribute containing the access group.
//                     
//  Items       - Undefined - name of the form item is AccessGroup.
//              - String - form item name.
//              - Array - form item names.
//
//  ValueType   - Undefined - getting type from the Object.Ref form attribute.
//              - Type - access value reference type.
//
//  CreatingNew - Undefined - getting value "NOT ValueIsFilled (Form.Object.Ref)"
//                            to determine whether a new value is created.
//              - Boolean - the specified value is used.
//
Procedure AccessValueFormOnCreate(Form,
                                          Attribute   = Undefined,
                                          Items       = Undefined,
                                          ValueType   = Undefined,
                                          CreatingNew = Undefined) Export
	
	If TypeOf(CreatingNew) <> Type("Boolean") Then
		CreatingNew = Not ValueIsFilled(Form.Object.Ref);
	EndIf;
	
	If TypeOf(ValueType) <> Type("Type") Then
		AccessValueType = TypeOf(Form.Object.Ref);
	Else
		AccessValueType = ValueType;
	EndIf;
	
	If Items = Undefined Then
		FormItems = New Array;
		FormItems.Add("AccessGroup");
		
	ElsIf TypeOf(Items) <> Type("Array") Then
		FormItems = New Array;
		FormItems.Add(Items);
	EndIf;
	
	ErrorTitle =
		NStr("en = 'Error in AccessValueFormOnCreate procedure
		           |of AccessManagement common module.'");
	
	GroupsProperties = AccessValueGroupsProperties(AccessValueType, ErrorTitle);
	
	If Attribute = Undefined Then
		AccessValueGroup = Form.Object.AccessGroup;
	Else
		AccessValueGroup = Form[Attribute];
	EndIf;
	
	If TypeOf(AccessValueGroup) <> GroupsProperties.Type Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			ErrorTitle + Chars.LF + Chars.LF +
			NStr("en = 'For access values of type %1
					  |access kind %2 is used with value type %3 
					  |specified in the overridable module.
					  |However, this type does not match type %4 in
					  |the access value form of AccessGroup attribute.'"),
			String(AccessValueType),
			String(GroupsProperties.AccessKind),
			String(GroupsProperties.Type),
			String(TypeOf(AccessValueGroup)));
	EndIf;
	
	If Not UseRecordLevelSecurity()
	 Or Not AccessManagementInternal.AccessKindUsed(GroupsProperties.AccessKind) Then
		
		For Each Item In FormItems Do
			Form.Items[Item].Visibility = False;
		EndDo;
		Return;
	EndIf;
	
	If Users.InfobaseUserWithFullAccess( , , False) Then
		Return;
	EndIf;
	
	ValueGroupsForChange =
		AccessValuesGroupsAllowingAccessValuesChange(AccessValueType);
	
	If ValueGroupsForChange.Count() = 0
	   And CreatingNew Then
		
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = '%1 must be allowed to add items.'"),
			Metadata.FindByType(GroupsProperties.Type).Presentation());
	EndIf;
	
	If ValueGroupsForChange.Count() = 0
	 Or Not CreatingNew
	   And ValueGroupsForChange.Find(AccessValueGroup) = Undefined Then
		
		Form.ReadOnly = True;
		Return;
	EndIf;
	
	If CreatingNew
	   And Not ValueIsFilled(AccessValueGroup)
	   And ValueGroupsForChange.Count() = 1 Then
		
		If Attribute = Undefined Then
			Form.Object.AccessGroup = ValueGroupsForChange[0];
		Else
			Form[Attribute] = ValueGroupsForChange[0];
		EndIf;
	EndIf;
	
	NewChoiceParameter = New ChoiceParameter(
		"Filter.Ref", New FixedArray(ValueGroupsForChange));

	ChoiceParameters = New Array;
	ChoiceParameters.Add(NewChoiceParameter);
	
	For Each Item In FormItems Do
		Form.Items[Item].ChoiceParameters = New FixedArray(ChoiceParameters);
	EndDo;
	
EndProcedure

// Returns an array of access value groups where access values can be changed.
//
// Supported only in cases when only a single access value group is selected.
//
// Parameters:
//  AccessValueType - Type - access value reference type.
//  ReturnAll       - Boolean - if True, when no restrictions are set,
//                    array of all groups will be returned instead of Undefined.
//
// Returns:
//  Undefined - access values can be changed in all access value groups.
//  Array     - array of found access value groups.
//
Function AccessValuesGroupsAllowingAccessValuesChange(AccessValueType, ReturnAll = False) Export
	
	ErrorTitle =
		NStr("en = 'Error in the AccessValuesGroupsAllowingAccessValuesChange procedure
		           |of the AccessManagement common module.'");
	
	GroupsProperties = AccessValueGroupsProperties(AccessValueType, ErrorTitle);
	
	If Not UseRecordLevelSecurity()
	 Or Not AccessManagementInternal.AccessKindUsed(GroupsProperties.AccessKind)
	 Or Users.InfobaseUserWithFullAccess( , , False) Then
		
		If ReturnAll Then
			Query = New Query;
			Query.Text =
			"SELECT ALLOWED
			|	AccessValueGroups.Ref AS Ref
			|FROM
			|	&AccessValueGroupTable AS AccessValueGroups";
			Query.Text = StrReplace(
				Query.Text, "&AccessValueGroupTable", GroupsProperties.Table);
			
			Return Query.Execute().Unload().UnloadColumn("Ref");
		EndIf;
		
		Return Undefined;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("AccessKind", GroupsProperties.AccessKind);
	Query.SetParameter("CurrentUser", Users.AuthorizedUser());
	Query.SetParameter("AccessValueType",  GroupsProperties.ValueTypeEmptyRef);
	
	Query.SetParameter("AccessValuesID",
		CommonUse.MetadataObjectID(AccessValueType));
	
	Query.Text =
	"SELECT
	|	AccessGroups.Ref
	|INTO UserAccessGroups
	|FROM
	|	Catalog.AccessGroups AS AccessGroups
	|WHERE
	|	TRUE IN
	|			(SELECT TOP 1
	|				TRUE
	|			FROM
	|				InformationRegister.AccessGroupTables AS AccessGroupTables
	|			WHERE
	|				AccessGroupTables.Table = &AccessValuesID
	|				AND AccessGroupTables.AccessGroup = AccessGroups.Ref
	|				AND AccessGroupTables.Update = TRUE)
	|	AND TRUE IN
	|			(SELECT TOP 1
	|				TRUE
	|			FROM
	|				InformationRegister.UserGroupContent AS UserGroupContent
	|					INNER JOIN Catalog.AccessGroups.Users AS AccessGroupsUsers
	|					ON
	|						UserGroupContent.Used
	|							AND UserGroupContent.User = &CurrentUser
	|							AND AccessGroupsUsers.User = UserGroupContent.UserGroup
	|							AND AccessGroupsUsers.Ref = AccessGroups.Ref)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	AccessValueGroups.Ref AS Ref
	|INTO ValueGroups
	|FROM
	|	&AccessValueGroupTable AS AccessValueGroups
	|WHERE
	|	TRUE IN
	|			(SELECT TOP 1
	|				TRUE
	|			FROM
	|				UserAccessGroups AS UserAccessGroups
	|					INNER JOIN InformationRegister.DefaultAccessGroupValues AS DefaultValues
	|					ON
	|						DefaultValues.AccessGroup = UserAccessGroups.Ref
	|							AND DefaultValues.AccessValueType = &AccessValueType
	|					LEFT JOIN InformationRegister.AccessGroupValues AS Values
	|					ON
	|						Values.AccessGroup = UserAccessGroups.Ref
	|							AND Values.AccessValue = AccessValueGroups.Ref
	|			WHERE
	|				ISNULL(Values.ValueIsAllowed, DefaultValues.AllAllowed))";
	Query.Text = StrReplace(Query.Text, "&AccessValueGroupTable", GroupsProperties.Table);
	Query.TempTablesManager = New TempTablesManager;
	
	SetPrivilegedMode(True);
	Query.Execute();
	SetPrivilegedMode(False);
	
	Query.Text =
	"SELECT ALLOWED
	|	AccessValueGroups.Ref AS Ref
	|FROM
	|	&AccessValueGroupTable AS AccessValueGroups
	|		INNER JOIN ValueGroups AS ValueGroups
	|		ON AccessValueGroups.Ref = ValueGroups.Ref";
	
	Query.Text = StrReplace(
		Query.Text, "&AccessValueGroupTable", GroupsProperties.Table);
	
	Return Query.Execute().Unload().UnloadColumn("Ref");
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions used to work with access value sets

// Checks whether an access value set filling procedure is available for a metadata object.
// 
// Parameters:
//  Ref - AnyRef - reference to any object.
//
// Returns:
//  Boolean - if True, the access value sets can be filled.
//
Function CanFillAccessValueSets(Ref) Export
	
	ObjectType = Type(CommonUse.ObjectKindByRef(Ref) + "Object." + Ref.Metadata().Name);
	
	SetsAreFilled = AccessManagementInternalCached.ObjectTypesInEventSubscriptions(
		"WriteAccessValueSets
		|WriteDependentAccessValueSets").Get(ObjectType) <> Undefined;
	
	Return SetsAreFilled;
	
EndFunction

// Returns an empty table to be filled and passed to RoleExists function and
// to FillAccessValueSets(Table) procedures defined by applied developer.
//
// Returns:
//  ValueTable - with columns:
//    * SetNumber   - Number  - optional if a single set is used.
//    * AccessKind  - String  - optional except for special ReadRight, EditRight.
//    * AccessValue - Undefined, CatalogRef - or other (mandatory). 
//    * Read        - Boolean - optional if a set is used for all rights. Set for a single row in the set.
//     * Update     - Boolean - optional if a set is used for all rights. Set for a single row in the set.
//
Function AccessValueSetTable() Export
	
	SetPrivilegedMode(True);
	
	Table = New ValueTable;
	Table.Columns.Add("SetNumber",   New TypeDescription("Number", New NumberQualifiers(4, 0, AllowedSign.Nonnegative)));
	Table.Columns.Add("AccessKind",  New TypeDescription("String", New StringQualifiers(20)));
	Table.Columns.Add("AccessValue", Metadata.DefinedTypes.AccessValue.Type);
	Table.Columns.Add("Read",        New TypeDescription("Boolean"));
	Table.Columns.Add("Update",      New TypeDescription("Boolean"));
	// Internal field. It is filled automatically, and cannot be filled or changed manually
	Table.Columns.Add("Adjustment",  New TypeDescription("CatalogRef.MetadataObjectIDs"));
	
	Return Table;
	
EndFunction

// FillAccessValueSets(Table) procedure is created by the applied developer
// in object modules of type specified in
// a subscription to the WriteAccessValueSets or WriteDependentAccessValueSets event.
// The procedure fills access value sets by object properties.
//
// Parameter:
//  Table - ValueTable - returned by AccessValueSetTable function.
//
// Current procedure of the same name fills the object access value sets
// using the FillAccessValueSets(Table) procedure created by the applied developer (see description above).
// 
// Parameters:
//  Object  - Object, Ref - CatalogObject, DocumentObject, ... CatalogRef, DocumentRef,..
//            Object is received when reference is passed.
//
//  Table - ValueTable - returned by AccessValueSetTable function of AccessManagement module.
//          - Undefined - a new value table is created.
//
//  SubordinateObjectRef - AnyRef - used when you need to fill
//            access value sets of owner object for a subordinate object.
//
Procedure FillAccessValueSets(Val Object, Table, Val SubordinateObjectRef = Undefined) Export
	
	SetPrivilegedMode(True);
	
	// If a reference is passed, an object is received.
	// The object is not changed. It is used to call the FillAccessValueSets() method.
	Object = ?(Object = Object.Ref, Object.GetObject(), Object);
	ObjectRef = Object.Ref;
	ValueTypeObject = TypeOf(Object);
	
	SetsAreFilled = AccessManagementInternalCached.ObjectTypesInEventSubscriptions(
		"WriteAccessValueSets
		|WriteDependentAccessValueSets").Get(ValueTypeObject) <> Undefined;
	
	If Not SetsAreFilled Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Invalid parameters.
			           |Object type %1
			           |is not found in any of the subscriptions
			           |to events ""Write access value sets"",
			           |""Write dependent sets of access values"".'"),
			ValueTypeObject);
	EndIf;
	
	Table = ?(TypeOf(Table) = Type("ValueTable"), Table, AccessValueSetTable());
	Object.FillAccessValueSets(Table);
	
	If Table.Count() = 0 Then
		// If you disable this condition, the scheduled job 
		// that fills data for access restriction purposes will loop.
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Object %1 generated an empty access value set.'"),
			ValueTypeObject);
	EndIf;
	
	SpecifyAccessValuesSets(ObjectRef, Table);
	
	If SubordinateObjectRef = Undefined Then
		Return;
	EndIf;
	
	// Adding sets for checking Read and Change
	// rights of "leading" owner object when generating the
	// dependent value sets in procedures prepared by the applied developer.
	//
	// No action is required when filling the final set
	// (even if it includes dependent sets), as the rights check is embedded in the
 // logic of the Object access kind in standard templates.
	
	// Adding an empty set to set all rights check flags and organize row sets
	AddAccessValueSets(Table, AccessValueSetTable());
	
	// Preparing object sets for individual rights
	ReadingSets = AccessValueSetTable();
	ChangeSets  = AccessValueSetTable();
	For Each Row In Table Do
		If Row.Read Then
			NewRow = ReadingSets.Add();
			NewRow.SetNumber   = Row.SetNumber + 1;
			NewRow.AccessKind  = Row.AccessKind;
			NewRow.AccessValue = Row.AccessValue;
			NewRow.Adjustment  = Row.Adjustment;
		EndIf;
		If Row.Update Then
			NewRow = ChangeSets.Add();
			NewRow.SetNumber   = (Row.SetNumber + 1)*2;
			NewRow.AccessKind  = Row.AccessKind;
			NewRow.AccessValue = Row.AccessValue;
			NewRow.Adjustment  = Row.Adjustment;
		EndIf;
	EndDo;
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	InformationRegister.AccessRightDependencies AS AccessRightDependencies
	|WHERE
	|	AccessRightDependencies.SubordinateTable = &SubordinateTable
	|	AND AccessRightDependencies.LeadingTableType = &LeadingTableType";
	
	Query.SetParameter("SubordinateTable",
		SubordinateObjectRef.Metadata().FullName());
	
	TypeArray = New Array;
	TypeArray.Add(TypeOf(ObjectRef));
	TypeDescription = New TypeDescription(TypeArray);
	Query.SetParameter("LeadingTableType", TypeDescription.AdjustValue(Undefined));
	
	RightDependencies = Query.Execute().Unload();
	Table.Clear();
	
	ID = CommonUse.MetadataObjectID(TypeOf(ObjectRef));
	
	If RightDependencies.Count() = 0 Then
		
		// Adding sets by standard rule.
		
		// Checking Read right of
		// the leading set-owner object when checking Read right of the subordinate object
		String = Table.Add();
		Row.SetNumber   = 1;
		Row.AccessKind  = "ReadRight";
		Row.AccessValue = ID;
		Row.Read        = True;
		
		// Checking Change right of
		// the leading set-owner object while checking Add, Change, Delete
   // rights of the subordinate object
		String = Table.Add();
		Row.SetNumber   = 2;
		Row.AccessKind  = "EditRight";
		Row.AccessValue = ID;
		Row.Update      = True;
		
		// Marking the rights that require checking the read right restriction sets for the leading owner object
		ReadingSets.FillValues(True, "Read");
		// Marking the rights that require checking the change right restriction sets for the leading owner object
		ChangeSets.FillValues(True, "Update");
		
		AddAccessValueSets(ReadingSets, ChangeSets);
		AddAccessValueSets(Table, ReadingSets, True);
	Else
		// Adding sets by nonstandard rule: check read rights instead of change rights.
		
		// Checking Read right of
		// the leading set-owner object when checking Read right of the subordinate object
		String = Table.Add();
		Row.SetNumber   = 1;
		Row.AccessKind  = "ReadRight";
		Row.AccessValue = ID;
		Row.Read        = True;
		Row.Update      = True;
		
		// Marking the rights that require checking the read right restriction sets for the leading owner object
		ReadingSets.FillValues(True, "Read");
		ReadingSets.FillValues(True, "Update");
		AddAccessValueSets(Table, ReadingSets, True);
	EndIf;
	
EndProcedure

// Adds an access value set table to another access value set table,
// either by logical addition or by logical multiplication.
//
// The result is returned in the Target parameter.
//
// Parameters:
//  Target - ValueTable - with columns identical to the table returned by AccessValueSetTable function.
//  Source - ValueTable - with columns identical to the table returned by AccessValueSetTable function.
//
//  Multiplication - Boolean - determines the method to be used to join tables.
//  Simplify - Boolean - determines whether the resulting table must be simplified.
//
Procedure AddAccessValueSets(Target, Val Source, Val Multiplication = False, Val Simplify = False) Export
	
	If Source.Count() = 0 And Target.Count() = 0 Then
		Return;
		
	ElsIf Multiplication And ( Source.Count() = 0 Or  Target.Count() = 0 ) Then
		Target.Clear();
		Source.Clear();
		Return;
	EndIf;
	
	If Target.Count() = 0 Then
		Value = Target;
		Target = Source;
		Source = Value;
	EndIf;
	
	If Simplify Then
		
		// Identifying duplicate sets and duplicate rows in sets
   // for a specific right that may occur during table joining.

		//
		// Duplicates occur due to unbracketing rules implemented in logical expressions:
		//  Both for sets for a specific right and sets for different rights:
		//     X  AND  X = X,
		//     X OR X = X, where X - a set of rows used as arguments.
		//  Only for sets for a specific right:
		//     (a AND b AND c) OR (a AND b) = (a AND b), where a,b,c - set rows used as arguments.
		// Based on these rules, the duplicate set rows and sets can be deleted.
		
		If Multiplication Then
			MultiplySetsAndSimplify(Target, Source);
		Else // Insert
			AddSetsAndSimplify(Target, Source);
		EndIf;
	Else
		
		If Multiplication Then
			MultiplySets(Target, Source);
		Else // Adding
			AddSets(Target, Source);
		EndIf;
	EndIf;
	
EndProcedure

// Updates object access value sets if they have been changed.
// The sets are updated both in the tabular section
// (if used) and in the AccessValueSets register information.
//
// Parameters:
//  ObjectRef - CatalogRef, DocumentRef and other reference
//                   types of metadata objects for which the access value sets are filled.
//
Procedure UpdateAccessValueSets(ObjectRef) Export
	
	AccessManagementInternal.UpdateAccessValueSets(ObjectRef);
	
EndProcedure

// FillAccessValueSetsOfTabularSections* subscription handler for
// the BeforeWrite event fills access values of the
// AccessValueSets object tabular section in cases when the #ByValueSets template
// is used to restrict access to the object.
//  The Access management subsystem can be used
// in some cases when the specified subscription does not exist, provided that
// the sets are not used for the purpose.
//
// Parameters:
//  Source        - CatalogObject,
//                    DocumentObject,
//                    ChartOfCharacteristicTypesObject,
//                    ChartOfAccountsObject,
//                    ChartOfCalculationTypesObject,
//                    BusinessProcessObject,
//                    TaskObject,
//                    ExchangePlanObject - data object passed to the BeforeWrite event subscription.
//
//  Cancel          - Boolean - parameter passed to the BeforeWrite event subscription.
//
//  WriteMode       - Boolean - parameter passed to the BeforeWrite
//                    event subscription when the type of Source parameter is DocumentObject.
//
//  PostingMode     - Boolean - parameter passed to the BeforeWrite
//                    event subscription when the type of Source parameter is DocumentObject.
//
Procedure FillAccessValueSetsOfTabularSections(Source, Cancel = Undefined, WriteMode = Undefined, PostingMode = Undefined) Export
	
	If Source.DataExchange.Load
	   And Not Source.AdditionalProperties.Property("WriteAccessValueSets") Then
		
		Return;
	EndIf;
	
	If Not (  PrivilegedMode()
	         And Source.AdditionalProperties.Property(
	             "AccessValueSetsOfTabularSectionAreFilled")) Then
		
		Table = AccessManagementInternal.GetAccessValueSetsOfTabularSection(Source);
		AccessManagementInternal.PrepareAccessValueSetsForRecord(Undefined, Table, False);
		Source.AccessValueSets.Load(Table);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions used in the overridable module

// Returns a structure used for easier description of supplied profiles.
// 
//  To specify a preset access
// kind, you need to set the Preset string in presentation.
// 
//  To add an access value, you need to specify
// the full name of a predefined item, for example, "Catalog.UserGroups.AllUsers".
// 
// ID must be extracted from the actual item in the catalog.
// IDs obtained by arbitrary methods must not be used.
// 
// Example:
// 
// // "User" profile
// ProfileDescription = AccessManagement.NewAccessGroupProfileDescription();
// ProfileDescription.Name        = "User";
// ProfileDescription.ID          = "09e56dbf-90a0-11de-862c-001d600d9ad2";
// ProfileDescription.Description = NStr("en = 'User'");
// ProfileDescription.Description =
// 	NStr("en = 'Common actions allowed for most users.
// 	           |As a rule these are the rights to view infobase data.'");
// // Using 1C: Enterprise
// ProfileDescription.Roles.Add("StartThinClient");
// ProfileDescription.Roles.Add("OutputToPrinterFileClipboard");
// ProfileDescription.Roles.Add("SaveUserData");
// // ...
//  Using the application
// ProfileDescription.Roles.Add("BasicRights");
// ProfileDescription.Roles.Add("ViewApplicationChangeLog");
// ProfileDescription.Roles.Add("EditCurrentUser");
// // ...
//  Using RegulatoryData
// ProfileDescription.Roles.Add("ReadBasicRegulatoryData");
// ProfileDescription.Roles.Add("ReadCommonBasicRegulatoryData");
// // ...
//  General functionality
// ProfileDescription.Roles.Add("UseReportOptions");
// ProfileDescription.Roles.Add("UseDependencies");
// // ...
//  Basic profile features
// ProfileDescription.Roles.Add("UseNotes");
// ProfileDescription.Roles.Add("UseReminders");
// ProfileDescription.Roles.Add("AddEditJobs");
// ProfileDescription.Roles.Add("EditCompleteTask");
// // ...
//  Profile access restriction kinds
// ProfileDescription.AccessKinds.Add("Companies");
// ProfileDescription.AccessKinds.Add("Users", "Preset");
// ProfileDescription.AccessKinds.Add("BusinessOperation", "Preset");
// ProfileDescription.AccessValues.Add("BusinessOperations",
// 	"Enum.BusinessOperations.AccountableCashOutToSubreporter");
// // ...
// ProfileDescriptions.Add(ProfileDescription);
//
Function NewAccessGroupProfileDescription() Export
	
	NewDetails = New Structure;
	NewDetails.Insert("Name",         ""); // PredefinedDataName
	                                       // is used to link the supplied data to a predefined item
	NewDetails.Insert("ID",           ""); // SuppliedDataID
	NewDetails.Insert("Description",  "");
	NewDetails.Insert("Details",  "");
	NewDetails.Insert("Roles",        New Array);
	NewDetails.Insert("AccessKinds",  New ValueList);
	NewDetails.Insert("AccessValues", New ValueList);
	
	Return NewDetails;
	
EndFunction

// Adds additional types to
// the OnFillAccessKinds procedure of the AccessManagementOverridable common module.
//
// Parameters:
//  AccessKind           - ValueTableRow - added to the AccessKinds parameter.
//  ValueType            - Type - additional access value type.
//  ValueGroupType       - Type - additional access value group
//                         type can match the type of the previously specified value groups for the same access type.
//  MultipleValueGroups  - Boolean - True if you can specify multiple value groups
//                           for an additional access value type (in other words,
//                           AccessGroups tabular section exists).

// 
Procedure AddExtraTypesOfAccessKind(AccessKind, ValueType,
		ValueGroupType = Undefined, MultipleValueGroups = False) Export
	
	ExtrasTypes = AccessKind.ExtrasTypes;
	
	If ExtrasTypes.Columns.Count() = 0 Then
		ExtrasTypes.Columns.Add("ValueType",           New TypeDescription("Type"));
		ExtrasTypes.Columns.Add("ValueGroupType",      New TypeDescription("Type"));
		ExtrasTypes.Columns.Add("MultipleValueGroups", New TypeDescription("Boolean"));
	EndIf;
	
	NewRow = ExtrasTypes.Add();
	NewRow.ValueType           = ValueType;
	NewRow.ValueGroupType      = ValueGroupType;
	NewRow.MultipleValueGroups = MultipleValueGroups;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions used for infobase update

// Returns a reference to supplied profile by ID.
//
// Parameters:
//  ID - String - name or unique ID of a
//                  supplied profile as specified in the OnFillAccessKinds procedure of the AccessManagementOverridable common module.
//
// Returns:
//  CatalogRef.AccessGroupProfiles - if the supplied profile is found in the catalog.
//  Undefined - if the supplied profile is not found in the catalog.
//
Function SuppliedProfileById(ID) Export
	
	Return Catalogs.AccessGroupProfiles.SuppliedProfileById(ID);
	
EndFunction

// Returns an empty table to be filled and passed
// to the ReplaceRightsInObjectRightsSettings procedure.
//
// Returns:
//  ValueTable - with columns:
//    * OwnersType - Ref - the empty reference to rights owner type from
//                      the RightsSettingsOwner type description, for example, an empty reference to FileFolders catalog.
//    * OldName    - String - old right name.
//    * NewName    - String - new right name.
//
Function TableOfRightsReplacementInObjectRightsSettings() Export
	
	Dimensions = Metadata.InformationRegisters.ObjectRightsSettings.Dimensions;
	
	Table = New ValueTable;
	Table.Columns.Add("OwnersType", Dimensions.Object.Type);
	Table.Columns.Add("OldName",    Dimensions.Right.Type);
	Table.Columns.Add("NewName",    Dimensions.Right.Type);
	
	Return Table;
	
EndFunction

// Replaces rights used in the object rights settings.
// After the replacement, auxiliary data in
// the ObjectRightsSettings information register is
// updated, so the procedure should be called only once to avoid performance drops.
// 
// Parameters:
//  RenamedTable - ValueTable - with columns:
//    * OwnersType - Ref - the empty reference to rights owner type from
//                      the RightsSettingsOwner type description, for example, an empty reference to FileFolders catalog.

//    * OldName     - String - an old right name related to the specified owner type.
//    * NewName     - String - a new right name related to specified owner type.
//                      If an empty string is specified, the old right setting will be deleted.
//                      If two new names are mapped to the old name,
//                      the old right setting will be duplicated.
//  
Procedure ReplaceRightsInObjectRightsSettings(RenamedTable) Export
	
	Query = New Query;
	Query.Parameters.Insert("RenamedTable", RenamedTable);
	Query.Text =
	"SELECT
	|	RenamedTable.OwnersType,
	|	RenamedTable.OldName,
	|	RenamedTable.NewName
	|INTO RenamedTable
	|FROM
	|	&RenamedTable AS RenamedTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	RightsSettings.Object,
	|	RightsSettings.User,
	|	RightsSettings.Right,
	|	MAX(RightsSettings.RightIsProhibited) AS RightIsProhibited,
	|	MAX(RightsSettings.InheritanceIsAllowed) AS InheritanceIsAllowed,
	|	MAX(RightsSettings.SettingsOrder) AS SettingsOrder
	|INTO OldRightsSettings
	|FROM
	|	InformationRegister.ObjectRightsSettings AS RightsSettings
	|
	|GROUP BY
	|	RightsSettings.Object,
	|	RightsSettings.User,
	|	RightsSettings.Right
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	OldRightsSettings.Object,
	|	OldRightsSettings.User,
	|	RenamedTable.OldName,
	|	RenamedTable.NewName,
	|	OldRightsSettings.RightIsProhibited,
	|	OldRightsSettings.InheritanceIsAllowed,
	|	OldRightsSettings.SettingsOrder
	|INTO RightsSettings
	|FROM
	|	OldRightsSettings AS OldRightsSettings
	|		INNER JOIN RenamedTable AS RenamedTable
	|		ON (VALUETYPE(OldRightsSettings.Object) = VALUETYPE(RenamedTable.OwnersType))
	|			AND OldRightsSettings.Right = RenamedTable.OldName
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	RightsSettings.NewName
	|FROM
	|	RightsSettings AS RightsSettings
	|
	|GROUP BY
	|	RightsSettings.Object,
	|	RightsSettings.User,
	|	RightsSettings.NewName
	|
	|HAVING
	|	RightsSettings.NewName <> """" AND
	|	COUNT(RightsSettings.NewName) > 1
	|
	|UNION
	|
	|SELECT
	|	RightsSettings.NewName
	|FROM
	|	RightsSettings AS RightsSettings
	|		LEFT JOIN OldRightsSettings AS OldRightsSettings
	|		ON RightsSettings.Object = OldRightsSettings.Object
	|			AND RightsSettings.User = OldRightsSettings.User
	|			AND RightsSettings.NewName = OldRightsSettings.Right
	|WHERE
	|	Not OldRightsSettings.Right IS NULL 
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	RightsSettings.Object,
	|	RightsSettings.User,
	|	RightsSettings.OldName,
	|	RightsSettings.NewName,
	|	RightsSettings.RightIsProhibited,
	|	RightsSettings.InheritanceIsAllowed,
	|	RightsSettings.SettingsOrder
	|FROM
	|	RightsSettings AS RightsSettings";
	
	DataLock = New DataLock;
	LockItem = DataLock.Add("InformationRegister.ObjectRightsSettings");
	LockItem.Mode = DataLockMode.Exclusive;
	
	BeginTransaction();
	Try
		DataLock.Lock();
		QueryResults = Query.ExecuteBatch();
		
		RepeatingNewNames = QueryResults[QueryResults.Count()-2].Unload();
		
		If RepeatingNewNames.Count() > 0 Then
			RepeatingNewRightNames = "";
			For Each Row In RepeatingNewNames Do
				RepeatingNewRightNames = RepeatingNewRightNames
					+ ?(ValueIsFilled(RepeatingNewRightNames), "," + Chars.LF, "")
					+ Row.NewName;
			EndDo;
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Invalid parameters of the
				           |RenameRightInObjectRightsSettings procedure
				           |of the AccessManagement common module.
                 |
				           |After the update, settings for the following new rights names
                  |will be repeated: %1.'"),
				RepeatingNewRightNames);
		EndIf;
		
		ReplacementTable = QueryResults[QueryResults.Count()-1].Unload();
		
		RecordSet = InformationRegisters.ObjectRightsSettings.CreateRecordSet();
		
		For Each Row In ReplacementTable Do
			RecordSet.Filter.Object.Set(Row.Object);
			RecordSet.Filter.User.Set(Row.User);
			RecordSet.Filter.Right.Set(Row.OldName);
			RecordSet.Read();
			If RecordSet.Count() > 0 Then
				RecordSet.Clear();
				RecordSet.Write();
			EndIf;
		EndDo;
		
		NewRecord = RecordSet.Add();
		For Each Row In ReplacementTable Do
			If Row.NewName = "" Then
				Continue;
			EndIf;
			RecordSet.Filter.Object.Set(Row.Object);
			RecordSet.Filter.User.Set(Row.User);
			RecordSet.Filter.Right.Set(Row.NewName);
			FillPropertyValues(NewRecord, Row);
			NewRecord.Right = Row.NewName;
			RecordSet.Write();
		EndDo;
		
		InformationRegisters.ObjectRightsSettings.UpdateAuxiliaryRegisterData();
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions that are used to update internal data

// Updates the infobase user role list by
// their current access groups. Infobase users with the FullAccess role are skipped.
// 
// Parameters:
//  UserArray - Array, Undefined, Type - array of items of
//     CatalogRef.Users or CatalogRef.ExternalUsers.
//     If Undefined, all user roles are updated.
//     If Type = Catalog.ExternalUsers, all external user
//     roles are updated, otherwise all user roles are updated.
//
//  ServiceUserPassword - String - Password for authorization in Service manager.
//
Procedure UpdateUserRoles(Val UserArray = Undefined, Val ServiceUserPassword = Undefined) Export
	
	AccessManagementInternal.UpdateUserRoles(UserArray, ServiceUserPassword);
	
EndProcedure

// Updates the content of the
// AccessGroupValues and DefaultAccessGroupValues registers that are filled on the basis of the access group settings and access kind use.
//
Procedure RefreshAllowedValuesIfAccessKindsUseOnChange() Export
	
	InformationRegisters.AccessGroupValues.UpdateRegisterData();
	
EndProcedure

// Executes consequent filling and partial update of data
// required by AccessManagement subsystem in the access restriction mode at record level.
// 
//  Fill access value sets when the access restriction mode is enabled at
// record level. The sets are filled in portions, during each
// start, until all access value sets are filled.
//  When the restriction access mode at record
// level is disabled, the access value sets filled previously are removed whenever the related objects are overwritten, not immediately.
//  Updates secondary data (access value groups and additional fields in the
// existing access value sets) regardless of the access restriction mode at
// record level.
//  Disables the scheduled job after all updates are completed and data is filled.
//
//  The progress information is written to the event log.
//
//  The procedure can be called from 1C:Enterprise script,
// for example, when updating infobase.
//
// Parameters:
//  DataVolume - Number - (return value)
//                     the number of data objects that were filled.
//
Procedure DataFillingForAccessRestrictions(DataVolume = 0) Export
	
	AccessManagementInternal.DataFillingForAccessRestrictions(DataVolume);
	
EndProcedure

#EndRegion

#Region InternalInterface

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions

// Addition to the FillAccessValueSets procedure

// Casts the value set table to the tabular section or record set format.
//  It is executed before writing to
// the AccessValueSets register, or before writing an object with the AccessValueSets tabular section.
//
// Parameters:
//  ObjectRef - CatalogRef.*, DocumentRef.*, ...
//  Table        - InformationRegisterRecordSet.AccessValueSets.
//
Procedure SpecifyAccessValuesSets(ObjectRef, Table)
	
	AccessKindNames = AccessManagementInternalCached.Parameters().AccessKindsProperties.ByNames;
	
	RightsSettingsOwnerTypes = AccessManagementInternalCached.Parameters(
		).AvailableRightsForObjectRightsSettings.ByRefTypes;
	
	For Each Row In Table Do
		
		If RightsSettingsOwnerTypes.Get(TypeOf(Row.AccessValue)) <> Undefined
		   And Not ValueIsFilled(Row.Adjustment) Then
			
			Row.Adjustment = CommonUse.MetadataObjectID(TypeOf(ObjectRef));
		EndIf;
		
		If Row.AccessKind = "" Then
			Continue;
		EndIf;
		
		If Row.AccessKind = "ReadRight"
		 Or Row.AccessKind = "EditRight" Then
			
			If TypeOf(Row.AccessValue) <> Type("CatalogRef.MetadataObjectIDs") Then
				Row.AccessValue =
					CommonUse.MetadataObjectID(TypeOf(Row.AccessValue));
			EndIf;
			
			If Row.AccessKind = "ReadRight" Then
				Row.Adjustment = Catalogs.MetadataObjectIDs.EmptyRef();
			Else
				Row.Adjustment = Row.AccessValue;
			EndIf;
		
		ElsIf AccessKindNames.Get(Row.AccessKind) <> Undefined
		      Or Row.AccessKind = "RightsSettings" Then
			
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Object %1 has generated an access value set
				           |containing the known access kind %2
                 |which does not have to be specified.
				           |
				           |Only the special access types ReadRight, EditRight
				           |must be specified when they are used.'"),
				TypeOf(ObjectRef),
				Row.AccessKind);
		Else
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Object %1 has generated an access value set
				           |containing unknown access kind %2.'"),
				TypeOf(ObjectRef),
				Row.AccessKind);
		EndIf;
		
		Row.AccessKind = "";
	EndDo;
	
EndProcedure

// Addition to the AddAccessValueSets procedure

Function TableSets(Table, RightNormalization = False)
	
	TableSets = New Map;
	
	For Each Row In Table Do
		Set = TableSets.Get(Row.SetNumber);
		If Set = Undefined Then
			Set = New Structure;
			Set.Insert("Read", False);
			Set.Insert("Update", False);
			Set.Insert("Rows", New Array);
			TableSets.Insert(Row.SetNumber, Set);
		EndIf;
		If Row.Read Then
			Set.Read = True;
		EndIf;
		If Row.Update Then
			Set.Update = True;
		EndIf;
		Set.Rows.Add(Row);
	EndDo;
	
	If RightNormalization Then
		For Each SetDescription In TableSets Do
			Set = SetDescription.Value;
			
			If Not Set.Read And Not Set.Update Then
				Set.Read    = True;
				Set.Update = True;
			EndIf;
		EndDo;
	EndIf;
	
	Return TableSets;
	
EndFunction

Procedure AddSets(Target, Source)
	
	TargetSets = TableSets(Target);
	SourceSets = TableSets(Source);
	
	MaximumSetNumber = -1;
	
	For Each TargetSetDescription In TargetSets Do
		TargetSet = TargetSetDescription.Value;
		
		If Not TargetSet.Read And Not TargetSet.Update Then
			TargetSet.Read   = True;
			TargetSet.Update = True;
		EndIf;
		
		For Each Row In TargetSet.Rows Do
			Row.Read   = TargetSet.Read;
			Row.Update = TargetSet.Update;
		EndDo;
		
		If TargetSetDescription.Key > MaximumSetNumber Then
			MaximumSetNumber = TargetSetDescription.Key;
		EndIf;
	EndDo;
	
	NewSetNumber = MaximumSetNumber + 1;
	
	For Each SourceSetDescription In SourceSets Do
		SourceSet = SourceSetDescription.Value;
		
		If Not SourceSet.Read And Not SourceSet.Update Then
			SourceSet.Read   = True;
			SourceSet.Update = True;
		EndIf;
		
		For Each SourceRow In SourceSet.Rows Do
			NewRow = Target.Add();
			FillPropertyValues(NewRow, SourceRow);
			NewRow.SetNumber = NewSetNumber;
			NewRow.Read      = SourceSet.Read;
			NewRow.Update    = SourceSet.Update;
		EndDo;
		
		NewSetNumber = NewSetNumber + 1;
	EndDo;
	
EndProcedure

Procedure MultiplySets(Target, Source)
	
	TargetSets = TableSets(Target);
	SourceSets = TableSets(Source, True);
	Table = AccessValueSetTable();
	
	CurrentSetNumber = 1;
	For Each TargetSetDescription In TargetSets Do
			TargetSet = TargetSetDescription.Value;
		
		If Not TargetSet.Read And Not TargetSet.Update Then
			TargetSet.Read    = True;
			TargetSet.Update = True;
		EndIf;
		
		For Each SourceSetDescription In SourceSets Do
			SourceSet = SourceSetDescription.Value;
			
			ReadingMultiplication    = TargetSet.Read    And SourceSet.Read;
			ChangeMultiplication = TargetSet.Update And SourceSet.Update;
			If Not ReadingMultiplication And Not ChangeMultiplication Then
				Continue;
			EndIf;
			For Each TargetRow In TargetSet.Rows Do
				Row = Table.Add();
				FillPropertyValues(Row, TargetRow);
				Row.SetNumber = CurrentSetNumber;
				Row.Read      = ReadingMultiplication;
				Row.Update   = ChangeMultiplication;
			EndDo;
			For Each SourceRow In SourceSet.Rows Do
				Row = Table.Add();
				FillPropertyValues(Row, SourceRow);
				Row.SetNumber = CurrentSetNumber;
				Row.Read      = ReadingMultiplication;
				Row.Update   = ChangeMultiplication;
			EndDo;
			CurrentSetNumber = CurrentSetNumber + 1;
		EndDo;
	EndDo;
	
	Target = Table;
	
EndProcedure

Procedure AddSetsAndSimplify(Target, Source)
	
	TargetSets = TableSets(Target);
	SourceSets = TableSets(Source);
	
	ResultSets       = New Map;
	TypeCodes        = New Map;
	EnumerationCodes = New Map;
	SetRowTable      = New ValueTable;
	
	FillTypeCodesAndSetStringsTable(TypeCodes, EnumerationCodes, SetRowTable);
	
	CurrentSetNumber = 1;
	
	AddSimplifiedSetsToResult(
		ResultSets, TargetSets, CurrentSetNumber, TypeCodes, EnumerationCodes, SetRowTable);
	
	AddSimplifiedSetsToResult(
		ResultSets, SourceSets, CurrentSetNumber, TypeCodes, EnumerationCodes, SetRowTable);
	
	FillInTargetByResultSets(Target, ResultSets);
	
EndProcedure

Procedure MultiplySetsAndSimplify(Target, Source)
	
	TargetSets = TableSets(Target);
	SourceSets = TableSets(Source, True);
	
	ResultSets       = New Map;
	TypeCodes        = New Map;
	EnumerationCodes = New Map;
	SetRowTable      = New ValueTable;
	
	FillTypeCodesAndSetStringsTable(TypeCodes, EnumerationCodes, SetRowTable);
	
	CurrentSetNumber = 1;
	
	For Each TargetSetDescription In TargetSets Do
		TargetSet = TargetSetDescription.Value;
		
		If Not TargetSet.Read And Not TargetSet.Update Then
			TargetSet.Read   = True;
			TargetSet.Update = True;
		EndIf;
		
		For Each SourceSetDescription In SourceSets Do
			SourceSet = SourceSetDescription.Value;
			
			ReadingMultiplication = TargetSet.Read    And SourceSet.Read;
			ChangeMultiplication  = TargetSet.Update And SourceSet.Update;
			If Not ReadingMultiplication And Not ChangeMultiplication Then
				Continue;
			EndIf;
			
			SetStrings = SetRowTable.Copy();
			
			For Each TargetRow In TargetSet.Rows Do
				Row = SetStrings.Add();
				Row.AccessKind  = TargetRow.AccessKind;
				Row.AccessValue = TargetRow.AccessValue;
				Row.Adjustment  = TargetRow.Adjustment;
				FillRowID(Row, TypeCodes, EnumerationCodes);
			EndDo;
			For Each SourceRow In SourceSet.Rows Do
				Row = SetStrings.Add();
				Row.AccessKind  = SourceRow.AccessKind;
				Row.AccessValue = SourceRow.AccessValue;
				Row.Adjustment  = SourceRow.Adjustment;
				FillRowID(Row, TypeCodes, EnumerationCodes);
			EndDo;
			
			SetStrings.GroupBy("RowID, AccessKind, AccessValue, Adjustment");
			SetStrings.Sort("RowID");
			
			IDSet = "";
			For Each Row In SetStrings Do
				IDSet = IDSet + Row.RowID + Chars.LF;
			EndDo;
			
			ExistingSet = ResultSets.Get(IDSet);
			If ExistingSet = Undefined Then
				
				SetProperties = New Structure;
				SetProperties.Insert("Read",      ReadingMultiplication);
				SetProperties.Insert("Update",    ChangeMultiplication);
				SetProperties.Insert("Rows",      SetStrings);
				SetProperties.Insert("SetNumber", CurrentSetNumber);
				ResultSets.Insert(IDSet, SetProperties);
				CurrentSetNumber = CurrentSetNumber + 1;
			Else
				If ReadingMultiplication Then
					ExistingSet.Read = True;
				EndIf;
				If ChangeMultiplication Then
					ExistingSet.Update = True;
				EndIf;
			EndIf;
		EndDo;
	EndDo;
	
	FillInTargetByResultSets(Target, ResultSets);
	
EndProcedure

Procedure FillTypeCodesAndSetStringsTable(TypeCodes, EnumerationCodes, SetRowTable)
	
	EnumerationCodes = AccessManagementInternalCached.EnumerationCodes();
	
	TypeCodes = AccessManagementInternalCached.LinkTypeCodes("DefinedType.AccessValue");
	
	TypeCodeLength = 0;
	For Each KeyAndValue In TypeCodes Do
		TypeCodeLength = StrLen(KeyAndValue.Value);
		Break;
	EndDo;
	
	RowIDIdentifier =
		20 // String of the access type name
		+ TypeCodeLength
		+ 36 // Length of the string representation of a unique ID (access value)
		+ 36 // Length of the string representation of the unique ID (clarification)
		+ 6; // Space for separators
	
	SetRowTable = New ValueTable;
	SetRowTable.Columns.Add("RowID",       New TypeDescription("String", New StringQualifiers(RowIDIdentifier)));
	SetRowTable.Columns.Add("AccessKind",  New TypeDescription("String", New StringQualifiers(20)));
	SetRowTable.Columns.Add("AccessValue", Metadata.DefinedTypes.AccessValue.Type);
	SetRowTable.Columns.Add("Adjustment",  New TypeDescription("CatalogRef.MetadataObjectIDs"));
	
EndProcedure

Procedure FillRowID(Row, TypeCodes, EnumerationCodes)
	
	If Row.AccessValue = Undefined Then
		AccessValueID = "";
	Else
		AccessValueID = EnumerationCodes.Get(Row.AccessValue);
		If AccessValueID = Undefined Then
			AccessValueID = String(Row.AccessValue.UUID());
		EndIf;
	EndIf;
	
	Row.RowID = Row.AccessKind + ";"
		+ TypeCodes.Get(TypeOf(Row.AccessValue)) + ";"
		+ AccessValueID + ";"
		+ Row.Adjustment.UUID() + ";";
	
EndProcedure

Procedure AddSimplifiedSetsToResult(ResultSets, AddedSets, CurrentSetNumber, TypeCodes, EnumerationCodes, SetRowTable)
	
	For Each AddedSetDescription In AddedSets Do
		AddedSet = AddedSetDescription.Value;
		
		If Not AddedSet.Read And Not AddedSet.Update Then
			AddedSet.Read   = True;
			AddedSet.Update = True;
		EndIf;
		
		SetStrings = SetRowTable.Copy();
		
		For Each AddedSetString In AddedSet.Rows Do
			Row = SetStrings.Add();
			Row.AccessKind  = AddedSetString.AccessKind;
			Row.AccessValue = AddedSetString.AccessValue;
			Row.Adjustment  = AddedSetString.Adjustment;
			FillRowID(Row, TypeCodes, EnumerationCodes);
		EndDo;
		
		SetStrings.GroupBy("RowID, AccessKind, AccessValue, Adjustment");
		SetStrings.Sort("RowID");
		
		IDSet = "";
		For Each Row In SetStrings Do
			IDSet = IDSet + Row.RowID + Chars.LF;
		EndDo;
		
		ExistingSet = ResultSets.Get(IDSet);
		If ExistingSet = Undefined Then
			
			SetProperties = New Structure;
			SetProperties.Insert("Read",      AddedSet.Read);
			SetProperties.Insert("Update",    AddedSet.Update);
			SetProperties.Insert("Rows",      SetStrings);
			SetProperties.Insert("SetNumber", CurrentSetNumber);
			ResultSets.Insert(IDSet, SetProperties);
			
			CurrentSetNumber = CurrentSetNumber + 1;
		Else
			If AddedSet.Read Then
				ExistingSet.Read = True;
			EndIf;
			If AddedSet.Update Then
				ExistingSet.Update = True;
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

Function FillInTargetByResultSets(Target, ResultSets)
	
	Target = AccessValueSetTable();
	
	For Each SetDescription In ResultSets Do
		SetProperties = SetDescription.Value;
		For Each Row In SetProperties.Rows Do
			NewRow = Target.Add();
			NewRow.SetNumber   = SetProperties.SetNumber;
			NewRow.AccessKind  = Row.AccessKind;
			NewRow.AccessValue = Row.AccessValue;
			NewRow.Adjustment  = Row.Adjustment;
			NewRow.Read        = SetProperties.Read;
			NewRow.Update      = SetProperties.Update;
		EndDo;
	EndDo;
	
EndFunction

// Addition to the procedures:
// - AccessValueFormOnCreate
// - AccessValuesGroupsAllowingAccessValuesChange

Function AccessValueGroupsProperties(AccessValueType, ErrorTitle)
	
	SetPrivilegedMode(True);
	
	GroupsProperties = New Structure;
	
	AccessKindProperties = AccessManagementInternalCached.Parameters(
		).AccessKindsProperties.AccessValuesWithGroups.ByTypes.Get(AccessValueType);
	
	If AccessKindProperties = Undefined Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			ErrorTitle + Chars.LF + Chars.LF +
			NStr("en = 'For an access value type %1,
			           |access value groups are not used.'"),
			String(AccessValueType));
	EndIf;
	
	GroupsProperties.Insert("AccessKind", AccessKindProperties.Name);
	GroupsProperties.Insert("Type",       AccessKindProperties.ValueGroupType);
	
	GroupsProperties.Insert("Table",      Metadata.FindByType(
		AccessKindProperties.ValueGroupType).FullName());
	
	GroupsProperties.Insert("ValueTypeEmptyRef",
		AccessManagementInternal.MetadataObjectEmptyRef(AccessValueType));
	
	Return GroupsProperties;
	
EndFunction

#EndRegion
