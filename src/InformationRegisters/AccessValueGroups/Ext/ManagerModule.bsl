#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region InternalInterface

// Updates user groups to check the allowed values
// for the Users and ExternalUsers access types.
// 
// The procedure must be called:
// 1) When you add a new user (or an external user),
//    when you add a new user group (or an external user group),
//    when you change the user group (or external user groups) content.
//    Parameters = Structure with one or both properties:
//    - Users:      single user or an array.
//    - UserGroups: single user group or an array.
//
// 2) When changing performer groups.
//    Parameters = Structure with one property:
//    - PerformerGroups: Undefined, single performer group or an array.
//
// 3) When changing external user authorization objects.
//    Parameters = Structure with one property:
//    - AuthorizationObjects: Undefined, single authorization object or an array.
//
// Types used in the parameters:
//
//  User         - CatalogRef.Users,
//                         CatalogRef.ExternalUsers.
//
//  Users group - CatalogRef.UserGroups,
//                         CatalogRef.ExternalUserGroups.
//
//  Performer            - CatalogRef.Users,
//                         CatalogRef.ExternalUsers.
// 
//  Performer group      - for example, CatalogRef.TaskPerformerGroups.
//
//  Authorization object - for example, CatalogRef.Individuals.
//
// Parameters:
//  Parameters     - Undefined - update all data, without filters.
//                   Structure - see options above.
//
//  HasChanges      - Boolean (return value) - True if
//                  data is changed; not set otherwise.
//
Procedure UpdateUserGrouping(Parameters = Undefined, HasChanges = Undefined) Export
	
	UpdateKind = "";
	
	If Parameters = Undefined Then
		UpdateKind = "All";
	
	ElsIf Parameters.Count() = 2
	        And Parameters.Property("Users")
	        And Parameters.Property("UserGroups") Then
		
		UpdateKind = "UsersAndUserGroups";
		
	ElsIf Parameters.Count() = 1
	        And Parameters.Property("Users") Then
		
		UpdateKind = "UsersAndUserGroups";
		
	ElsIf Parameters.Count() = 1
	        And Parameters.Property("UserGroups") Then
		
		UpdateKind = "UsersAndUserGroups";
		
	ElsIf Parameters.Count() = 1
	        And Parameters.Property("PerformerGroups") Then
		
		UpdateKind = "PerformerGroups";
		
	ElsIf Parameters.Count() = 1
	        And Parameters.Property("AuthorizationObjects") Then
		
		UpdateKind = "AuthorizationObjects";
	Else
		Raise
			NStr("en = 'Error in UpdateUserGrouping procedure 
			           |of ""Access value groups"" information register manager module .
			           |
			           |Invalid parameters specified.'");
	EndIf;
	
	BeginTransaction();
	Try
		If InfobaseUpdate.ExecutingInfobaseUpdate() Then
			DeleteUnnecessaryRecords(HasChanges);
		EndIf;
		
		If UpdateKind = "UsersAndUserGroups" Then
			
			If Parameters.Property("Users") Then
				UpdateUsers     (   Parameters.Users, HasChanges);
				UpdatePerformerGroups( , Parameters.Users, HasChanges);
			EndIf;
			
			If Parameters.Property("UserGroups") Then
				UpdateUserGroups(Parameters.UserGroups, HasChanges);
			EndIf;
			
		ElsIf UpdateKind = "PerformerGroups" Then
			UpdatePerformerGroups(Parameters.PerformerGroups, , HasChanges);
			
		ElsIf UpdateKind = "AuthorizationObjects" Then
			UpdateAuthorizationObjects(Parameters.AuthorizationObjects, HasChanges);
		Else
			UpdateUsers               ( ,   HasChanges);
			UpdateUserGroups          ( ,   HasChanges);
			UpdatePerformerGroups     ( , , HasChanges);
			UpdateAuthorizationObjects ( ,   HasChanges);
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Removes excessive data after changing content of
// value types and access value groups.
//
Procedure UpdateConfigurationChangesAuxiliaryRegisterData() Export
	
	SetPrivilegedMode(True);
	
	Parameters = AccessManagementInternalCached.Parameters();
	
	LastChanges = StandardSubsystemsServer.ApplicationParameterChanges(
		Parameters, "GroupAndAccessValueTypes");
	
	If LastChanges = Undefined
	 Or LastChanges.Count() > 0 Then
		
		AccessManagementInternal.SetDataFillingForAccessRestrictions(True);
		UpdateEmptyAccessValueGroups();
		DeleteUnnecessaryRecords();
	EndIf;
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

// Updates the register data after changing access values.
// 
// Parameters:
//  HasChanges - Boolean (return value) - True if
//                  data is changed; not set otherwise.
//
Procedure UpdateRegisterData(HasChanges = Undefined) Export
	
	DeleteUnnecessaryRecords(HasChanges);
	
	UpdateUserGrouping( , HasChanges);
	
	UpdateAccessValueGroups( , HasChanges);
	
EndProcedure

// Updates the access value groups to InformationRegister.AccessValueGroups.
//
// Parameters:
//  AccessValues - CatalogObject,
//               - CatalogRef.
//               - Array of values of the types specified above.
//               - Undefined - not filtered.
//                 Value type must be included in measure types
//                 of the register Value of AccessValueGroups information.
//                 If the Object is transferred, it will update only on change.
//
//  HasChanges   - Boolean (return value) - True if
//                 data is changed; not set otherwise.
//
Procedure UpdateAccessValueGroups(AccessValues = Undefined,
                                  HasChanges   = Undefined) Export
	
	If AccessValues = Undefined Then
		
		AccessValuesWithGroups = AccessManagementInternalCached.Parameters(
			).AccessKindsProperties.AccessValuesWithGroups;
		
		Query = New Query;
		QueryText =
		"SELECT
		|	CurrentTable.Ref
		|FROM
		|	&CurrentTable AS CurrentTable";
		
		For Each TableName In AccessValuesWithGroups.TableNames Do
			
			Query.Text = StrReplace(QueryText, "&CurrentTable", TableName);
			Selection = Query.Execute().Select();
			
			ObjectManager = CommonUse.ObjectManagerByFullName(TableName);
			UpdateAccessSingleValueGroups(ObjectManager.EmptyRef(), HasChanges);
			
			While Selection.Next() Do
				UpdateAccessSingleValueGroups(Selection.Ref, HasChanges);
			EndDo;
		EndDo;
		
	ElsIf TypeOf(AccessValues) = Type("Array") Then
		
		For Each AccessValue In AccessValues Do
			UpdateAccessSingleValueGroups(AccessValue, HasChanges);
		EndDo;
	Else
		UpdateAccessSingleValueGroups(AccessValues, HasChanges);
	EndIf;
	
EndProcedure

// Fills groups for empty references to the access value types in use.
Procedure UpdateEmptyAccessValueGroups() Export
	
	AccessValuesWithGroups = AccessManagementInternalCached.Parameters(
		).AccessKindsProperties.AccessValuesWithGroups;
	
	For Each TableName In AccessValuesWithGroups.TableNames Do
		ObjectManager = CommonUse.ObjectManagerByFullName(TableName);
		UpdateAccessSingleValueGroups(ObjectManager.EmptyRef(), Undefined);
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions

// Deletes unnecessary records if any are found.
Function DeleteUnnecessaryRecords(HasChanges = Undefined)
	
	GroupAndAccessValueTypes = AccessManagementInternalCached.Parameters(
		).AccessKindsProperties.AccessValuesWithGroups.ValueGroupTypes;
	
	TableGroupTypesAndValues = New ValueTable;
	TableGroupTypesAndValues.Columns.Add("ValueType",      Metadata.DefinedTypes.AccessValue.Type);
	TableGroupTypesAndValues.Columns.Add("ValueGroupType", Metadata.DefinedTypes.AccessValue.Type);
	
	For Each KeyAndValue In GroupAndAccessValueTypes Do
		If TypeOf(KeyAndValue.Key) = Type("Type") Then
			Continue;
		EndIf;
		Row = TableGroupTypesAndValues.Add();
		Row.ValueType      = KeyAndValue.Key;
		Row.ValueGroupType = KeyAndValue.Value;
	EndDo;
	
	Query = New Query;
	Query.SetParameter("TableGroupTypesAndValues", TableGroupTypesAndValues);
	Query.Text =
	"SELECT
	|	TableTypes.ValueType,
	|	TableTypes.ValueGroupType
	|INTO TableGroupTypesAndValues
	|FROM
	|	&TableGroupTypesAndValues AS TableTypes
	|
	|INDEX BY
	|	TableTypes.ValueType,
	|	TableTypes.ValueGroupType
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	AccessValueGroups.AccessValue,
	|	AccessValueGroups.AccessValueGroup,
	|	AccessValueGroups.DataGroup
	|FROM
	|	InformationRegister.AccessValueGroups AS AccessValueGroups
	|WHERE
	|	CASE
	|			WHEN AccessValueGroups.AccessValue = UNDEFINED
	|				THEN TRUE
	|			WHEN AccessValueGroups.DataGroup = 0
	|				THEN Not TRUE IN
	|							(SELECT TOP 1
	|								TRUE
	|							FROM
	|								TableGroupTypesAndValues AS TableGroupTypesAndValues
	|							WHERE
	|								VALUETYPE(TableGroupTypesAndValues.ValueType) = VALUETYPE(AccessValueGroups.AccessValue)
	|								AND VALUETYPE(TableGroupTypesAndValues.ValueGroupType) = VALUETYPE(AccessValueGroups.AccessValueGroup))
	|			WHEN AccessValueGroups.DataGroup = 1
	|				THEN CASE
	|						WHEN VALUETYPE(AccessValueGroups.AccessValue) = TYPE(Catalog.Users)
	|							THEN VALUETYPE(AccessValueGroups.AccessValueGroup) <> TYPE(Catalog.Users)
	|									AND VALUETYPE(AccessValueGroups.AccessValueGroup) <> TYPE(Catalog.UserGroups)
	|						WHEN VALUETYPE(AccessValueGroups.AccessValue) = TYPE(Catalog.ExternalUsers)
	|							THEN VALUETYPE(AccessValueGroups.AccessValueGroup) <> TYPE(Catalog.ExternalUsers)
	|									AND VALUETYPE(AccessValueGroups.AccessValueGroup) <> TYPE(Catalog.ExternalUserGroups)
	|						ELSE TRUE
	|					END
	|			WHEN AccessValueGroups.DataGroup = 2
	|				THEN CASE
	|						WHEN VALUETYPE(AccessValueGroups.AccessValue) = TYPE(Catalog.UserGroups)
	|							THEN VALUETYPE(AccessValueGroups.AccessValueGroup) <> TYPE(Catalog.Users)
	|									AND VALUETYPE(AccessValueGroups.AccessValueGroup) <> TYPE(Catalog.UserGroups)
	|						WHEN VALUETYPE(AccessValueGroups.AccessValue) = TYPE(Catalog.ExternalUserGroups)
	|							THEN VALUETYPE(AccessValueGroups.AccessValueGroup) <> TYPE(Catalog.ExternalUsers)
	|									AND VALUETYPE(AccessValueGroups.AccessValueGroup) <> TYPE(Catalog.ExternalUserGroups)
	|						ELSE TRUE
	|					END
	|			WHEN AccessValueGroups.DataGroup = 3
	|				THEN CASE
	|						WHEN VALUETYPE(AccessValueGroups.AccessValue) = TYPE(Catalog.Users)
	|								OR VALUETYPE(AccessValueGroups.AccessValue) = TYPE(Catalog.UserGroups)
	|								OR VALUETYPE(AccessValueGroups.AccessValue) = TYPE(Catalog.ExternalUsers)
	|								OR VALUETYPE(AccessValueGroups.AccessValue) = TYPE(Catalog.ExternalUserGroups)
	|							THEN TRUE
	|						WHEN VALUETYPE(AccessValueGroups.AccessValueGroup) <> TYPE(Catalog.Users)
	|								AND VALUETYPE(AccessValueGroups.AccessValueGroup) <> TYPE(Catalog.UserGroups)
	|								AND VALUETYPE(AccessValueGroups.AccessValueGroup) <> TYPE(Catalog.ExternalUsers)
	|								AND VALUETYPE(AccessValueGroups.AccessValueGroup) <> TYPE(Catalog.ExternalUserGroups)
	|							THEN TRUE
	|						ELSE FALSE
	|					END
	|			WHEN AccessValueGroups.DataGroup = 4
	|				THEN CASE
	|						WHEN VALUETYPE(AccessValueGroups.AccessValue) = TYPE(Catalog.Users)
	|								OR VALUETYPE(AccessValueGroups.AccessValue) = TYPE(Catalog.UserGroups)
	|								OR VALUETYPE(AccessValueGroups.AccessValue) = TYPE(Catalog.ExternalUsers)
	|								OR VALUETYPE(AccessValueGroups.AccessValue) = TYPE(Catalog.ExternalUserGroups)
	|							THEN TRUE
	|						WHEN VALUETYPE(AccessValueGroups.AccessValueGroup) <> TYPE(Catalog.ExternalUsers)
	|								AND VALUETYPE(AccessValueGroups.AccessValueGroup) <> TYPE(Catalog.ExternalUserGroups)
	|							THEN TRUE
	|						ELSE FALSE
	|					END
	|			ELSE TRUE
	|		END";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		Selection = QueryResult.Select();
		While Selection.Next() Do
			RecordSet = InformationRegisters.AccessValueGroups.CreateRecordSet();
			RecordSet.Filter.AccessValue.Set(Selection.AccessValue);
			RecordSet.Filter.AccessValueGroup.Set(Selection.AccessValueGroup);
			RecordSet.Filter.DataGroup.Set(Selection.DataGroup);
			RecordSet.Write();
			HasChanges = True;
		EndDo;
	EndIf;
	
EndFunction

// Updates the access value groups in InformationRegister.AccessValueGroups.
//
// Parameters:
//  AccessValue - CatalogRef.
//                CatalogObject.
//                If Object is passed, the update is performed only when it is changed.
//
//  HasChanges   - Boolean (return value) - True if
//                    data is changed; not set otherwise.
//
Procedure UpdateAccessSingleValueGroups(AccessValue, HasChanges)
	
	SetPrivilegedMode(True);
	
	AccessValueType = TypeOf(AccessValue);
	
	AccessValueswithGroups = AccessManagementInternalCached.Parameters(
		).AccessKindsProperties.AccessValuesWithGroups;
	
	AccessKindProperties = AccessValuesWithGroups.ByTypes.Get(AccessValueType);
	
	ErrorTitle =
		NStr("en = 'Error when updating access value groups.
		           |
		           |'");
	
	If AccessKindProperties = Undefined Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			ErrorTitle +
			NStr("en = 'For %1 type,
			           |access value group use is not set up.'"),
			String(AccessValueType));
	EndIf;
	
	If AccessValuesWithGroups.ByRefTypes.Get(AccessValueType) = Undefined Then
		Ref = AccessManagementInternal.ObjectRef(AccessValue);
		Object = AccessValue;
	Else
		Ref = AccessValue;
		Object = Undefined;
	EndIf;
	
	// Preparing old field values
	AttributeName      = "AccessGroup";
	TabularSectionName = "AccessGroups";
	If AccessKindProperties.MultipleValueGroups Then
		FieldForQuery = TabularSectionName;
	Else
		FieldForQuery = AttributeName;
	EndIf;
	
	Try
		OldValues = CommonUse.ObjectAttributeValues(Ref, FieldForQuery);
	Except
		Error = ErrorInfo();
		TypeMetadata = Metadata.FindByType(AccessValueType);
		If AccessKindProperties.MultipleValueGroups Then
			TabularSectionMetadata = TypeMetadata.TabularSections.Find("AccessGroups");
			If TabularSectionMetadata = Undefined
			 Or TabularSectionMetadata.Attributes.Find("AccessGroup") = Undefined Then
				Raise StringFunctionsClientServer.SubstituteParametersInString(
					ErrorTitle +
					NStr("en = 'Access value type %1
					           |has no AccessGroups tabular section
					           |with AccessGroup attribute.'"),
					String(AccessValueType));
			Else
				Raise StringFunctionsClientServer.SubstituteParametersInString(
					ErrorTitle +
					NStr("en = 'Cannot read AccessGroup tabular section
					           |with AccessGroup attribute
					           |for access value %1
					           |of type %2.
					           |Error:
                               |%3.'"),
					String(AccessValue),
					String(AccessValueType),
					BriefErrorDescription(Error));
			EndIf;
		Else
			If TypeMetadata.Attributes.Find("AccessGroup") = Undefined Then
				Raise StringFunctionsClientServer.SubstituteParametersInString(
					ErrorTitle +
					NStr("en = 'Access value type %1
					           |has no AccessGroup attribute.'"),
					String(AccessValueType));
			Else
				Raise StringFunctionsClientServer.SubstituteParametersInString(
					ErrorTitle +
					NStr("en = 'Cannot read AccessGroup attribute
					           |for access value %1
					           |of type %2.
					           |Error:
                               |%3.'"),
					String(AccessValue),
					String(AccessValueType),
					BriefErrorDescription(Error));
			EndIf;
		EndIf;
	EndTry;
	
	// Checking the object for changes
	UpdateRequired = False;
	If Object <> Undefined Then
		If Object.IsNew() Then
			UpdateRequired = True;
		Else
			If AccessKindProperties.MultipleValueGroups Then
				Value = Object[TabularSectionName].Unload();
				Value.Sort(AttributeName);
				OldValues[TabularSectionName].Sort(AttributeName);
			Else
				Value = Object[AttributeName];
			EndIf;
			
			If Not CommonUse.IsEqualData(Value, OldValues[FieldForQuery]) Then
				UpdateRequired = True;
			EndIf;
		EndIf;
		NewValues = Object;
	Else
		UpdateRequired = True;
		NewValues = OldValues;
	EndIf;
	
	If Not UpdateRequired Then
		Return;
	EndIf;
	
	// Preparing new records for update
	NewRecords = InformationRegisters.AccessValueGroups.CreateRecordSet().Unload();
	
	If AccessManagement.UseRecordLevelSecurity() Then
		
		ValueGroupTypes = AccessManagementInternalCached.Parameters(
			).AccessKindsProperties.AccessValuesWithGroups.ValueGroupTypes;
		
		EmptyAccessValuesGroupReference = ValueGroupTypes.Get(TypeOf(Ref));
		
		// Adding value groups
		If AccessKindProperties.MultipleValueGroups Then
			For Each Row In NewValues[TabularSectionName] Do
				Write = NewRecords.Add();
				Write.AccessValue      = Ref;
				Write.AccessValueGroup = Row[AttributeName];
				If TypeOf(Write.AccessValueGroup) <> TypeOf(EmptyAccessValuesGroupReference) Then
					Write.AccessValueGroup = EmptyAccessValuesGroupReference;
				EndIf;
			EndDo;
		Else
			Write = NewRecords.Add();
			Write.AccessValue      = Ref;
			Write.AccessValueGroup = NewValues[AttributeName];
			If TypeOf(Write.AccessValueGroup) <> TypeOf(EmptyAccessValuesGroupReference) Then
				Write.AccessValueGroup = EmptyAccessValuesGroupReference;
			EndIf;
		EndIf;
		
	EndIf;
	
	If Object = Undefined Then
		AdditionalProperties = Undefined;
	Else
		AdditionalProperties = New Structure("LeadingObjectBeforeWrite", Object);
	EndIf;
	
	FixedFilter = New Structure;
	FixedFilter.Insert("AccessValue", Ref);
	FixedFilter.Insert("DataGroup", 0);
	
	BeginTransaction();
	Try
		AccessManagementInternal.UpdateRecordSets(
			InformationRegisters.AccessValueGroups,
			NewRecords, , , , , , , , ,
			FixedFilter,
			HasChanges, ,
			AdditionalProperties);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Updates user groups to check the
// allowed values for the Users and ExternalUsers access kinds.
//
// <AccessValue field content> <AccessValueGroup field content>
//                             <Field content DataGroup>
// a) for Users
// access kind
// {comparison with T.<field>} {Comparison with AccessGroupValues.AccessValue} 
//                            {Comparison with &CurrentExternalUser}
//
// User                          1 - The same User.
//
//                               1 - User group
//                                   of the same user.
//
// b) for External users
// access kind
// {comparison with T.<field>} {Comparison with AccessGroupValues.AccessValue}
//                            {Comparison with &CurrentExternalUser}
//
// External  user                1 - The same External user.
//
//                               1 - External user group
//                                   of the same external user.
//
Procedure UpdateUsers(Users1 = Undefined,
                                HasChanges = Undefined)
	
	SetPrivilegedMode(True);
	
	QueryText =
	"SELECT
	|	UserGroupContents.User AS AccessValue,
	|	UserGroupContents.UserGroup AS AccessValueGroup,
	|	1 AS DataGroup,
	|	&RowChangeKindFieldSubstitution
	|FROM
	|	InformationRegister.UserGroupContents AS UserGroupContents
	|WHERE
	|	VALUETYPE(UserGroupContents.User) = TYPE(Catalog.Users)
	|	AND &UserFilterCondition1
	|
	|UNION ALL
	|
	|SELECT
	|	UserGroupContents.User,
	|	UserGroupContents.UserGroup,
	|	1,
	|	&RowChangeKindFieldSubstitution
	|FROM
	|	InformationRegister.UserGroupContents AS UserGroupContents
	|WHERE
	|	VALUETYPE(UserGroupContents.User) = TYPE(Catalog.ExternalUsers)
	|	AND &UserFilterCondition1";
	
	// Preparing selected fields with optional filtering
	Fields = New Array; 
	Fields.Add(New Structure("AccessValue",       "&UserFilterCondition2"));
	Fields.Add(New Structure("AccessValueGroup"));
	Fields.Add(New Structure("DataGroup",          "&UpdatedDataGroupsFilterCondition"));
	
	Query = New Query;
	Query.Text = AccessManagementInternal.ChangeSelectionQueryText(
		QueryText, Fields, "InformationRegister.AccessValueGroups");
	
	AccessManagementInternal.SetFilterCriterionInQuery(Query, Users1, "Users",
		"&UserFilterCondition1:UserGroupContents.User
		|&UserFilterCondition2:OldData.AccessValue");
	
	AccessManagementInternal.SetFilterCriterionInQuery(Query, 1, "DataGroup",
		"&UpdatedDataGroupsFilterCondition:OldData.DataGroup");
	
	Changes = Query.Execute().Unload();
	
	FixedFilter = New Structure;
	FixedFilter.Insert("DataGroup", 1);
	
	AccessManagementInternal.UpdateInformationRegister(
		InformationRegisters.AccessValueGroups, Changes, HasChanges, FixedFilter);
	
EndProcedure

// Updates user groups to check the
// allowed values for the Users and ExternalUsers access kinds.
//
// <AccessValue field content> <AccessValueGroup field content>
//                             <DataGroup field content>
// a) for Users
// access kind
// {comparison with T.<field>} {Comparison with AccessGroupValues.AccessValue} 
//                             {Comparison with &CurrentExternalUser}
//
// User group                    2 - The same User group.
//
//                               2 - User
//                                   from the same user group.
//
// b) for External user
// access kind
// {comparison with T.<field>} {Comparison with AccessGroupValues.AccessValue}
//                             {Comparison with &CurrentExternalUser}
//
// External user group           2 - The same external user group.
//
//                               2 - External user
//                                   from the same external user group.
//
//
Procedure UpdateUserGroups(UserGroups = Undefined,
                                      HasChanges       = Undefined)
	
	SetPrivilegedMode(True);
	
	QueryText =
	"SELECT DISTINCT
	|	UserGroupContents.UserGroup AS AccessValue,
	|	UserGroupContents.UserGroup AS AccessValueGroup,
	|	2 AS DataGroup,
	|	&RowChangeKindFieldSubstitution
	|FROM
	|	InformationRegister.UserGroupContents AS UserGroupContents
	|WHERE
	|	VALUETYPE(UserGroupContents.UserGroup) = TYPE(Catalog.UserGroups)
	|	AND &FilterConditionOfUserGroups1
	|
	|UNION ALL
	|
	|SELECT
	|	UserGroupContents.UserGroup,
	|	UserGroupContents.User,
	|	2,
	|	&RowChangeKindFieldSubstitution
	|FROM
	|	InformationRegister.UserGroupContents AS UserGroupContents
	|WHERE
	|	VALUETYPE(UserGroupContents.UserGroup) = TYPE(Catalog.UserGroups)
	|	AND VALUETYPE(UserGroupContents.User) = TYPE(Catalog.Users)
	|	AND &FilterConditionOfUserGroups1
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	UserGroupContents.UserGroup,
	|	UserGroupContents.UserGroup,
	|	2,
	|	&RowChangeKindFieldSubstitution
	|FROM
	|	InformationRegister.UserGroupContents AS UserGroupContents
	|WHERE
	|	VALUETYPE(UserGroupContents.UserGroup) = TYPE(Catalog.ExternalUserGroups)
	|	AND &FilterConditionOfUserGroups1
	|
	|UNION ALL
	|
	|SELECT
	|	UserGroupContents.UserGroup,
	|	UserGroupContents.User,
	|	2,
	|	&RowChangeKindFieldSubstitution
	|FROM
	|	InformationRegister.UserGroupContents AS UserGroupContents
	|WHERE
	|	VALUETYPE(UserGroupContents.UserGroup) = TYPE(Catalog.ExternalUserGroups)
	|	AND VALUETYPE(UserGroupContents.User) = TYPE(Catalog.ExternalUsers)
	|	AND &FilterConditionOfUserGroups1";
	
	// Preparing selected fields with optional filtering
	Fields = New Array; 
	Fields.Add(New Structure("AccessValue",         "&FilterConditionOfUserGroups2"));
	Fields.Add(New Structure("AccessValueGroup"));
	Fields.Add(New Structure("DataGroup",            "&UpdatedDataGroupsFilterCondition"));
	
	Query = New Query;
	Query.Text = AccessManagementInternal.ChangeSelectionQueryText(
		QueryText, Fields, "InformationRegister.AccessValueGroups");
	
	AccessManagementInternal.SetFilterCriterionInQuery(Query, UserGroups, "UserGroups",
		"&FilterConditionOfUserGroups1:UserGroupContents.UserGroup
		|&FilterConditionOfUserGroups2:OldData.AccessValue");
	
	AccessManagementInternal.SetFilterCriterionInQuery(Query, 2, "DataGroup",
		"&UpdatedDataGroupsFilterCondition:OldData.DataGroup");
	
	Changes = Query.Execute().Unload();
	
	FixedFilter = New Structure;
	FixedFilter.Insert("DataGroup", 2);
	
	AccessManagementInternal.UpdateInformationRegister(
		InformationRegisters.AccessValueGroups, Changes, HasChanges, FixedFilter);
	
EndProcedure

// Updates user groups to check the
// allowed values for the Users and ExternalUsers access kinds.
//
// <AccessValue field content> <AccessValueGroup field content>
//                             <DataGroup field content> 
// a) for Users
// access kind
// {comparison with T.<field>} {Comparison with AccessGroupValues.AccessValue} 
//                             {Comparison with &CurrentExternalUser}
//
// Performer group               3 - User
//                                   from the same performer group.
//
//                               3 - A user group
//                                   from the same performer group user.
//
// b) for External user
// access kind
// {comparison with T.<field>} {Comparison with AccessGroupValues.AccessValue}
//                             {Comparison with &CurrentExternalUser}
//
// Performer  group              3 - External user
//                                   from the same performer group.
//
//                               3 - External user group
//                                   of an external user
//                                   of the same performer group.
//
Procedure UpdatePerformerGroups(PerformerGroups = Undefined,
                                     Performers = Undefined,
                                     HasChanges = Undefined)
	
	SetPrivilegedMode(True);
	
	// Preparing table of additional user groups,
	// performer groups (for example, tasks).
	
	Query = New Query;
	Query.TempTablesManager = New TempTablesManager;
	
	If PerformerGroups = Undefined
	   And Performers        = Undefined Then
	
		ParameterContent = Undefined;
		ParameterValue   = Undefined;
	
	ElsIf PerformerGroups <> Undefined Then
		ParameterContent = "PerformerGroups";
		ParameterValue   = PerformerGroups;
		
	ElsIf Performers <> Undefined Then
		ParameterContent = "Performers";
		ParameterValue   = Performers;
	Else
		Raise
			NStr("en = 'Error in
			           |Error in UpdatePerformerGroups procedure of AccessValueGroups information register manager module.
			           |
			           |Invalid parameters specified.'");
	EndIf;
	
	NoPerformerGroups = True;
	AccessManagementInternal.OnDefinePerformerGroups(
		Query.TempTablesManager,
		ParameterContent,
		ParameterValue,
		NoPerformerGroups);
	
	If NoPerformerGroups Then
		RecordSet = InformationRegisters.AccessValueGroups.CreateRecordSet();
		RecordSet.Filter.DataGroup.Set(3);
		RecordSet.Read();
		If RecordSet.Count() > 0 Then
			RecordSet.Clear();
			RecordSet.Write();
			HasChanges = True;
		EndIf;
		Return;
	EndIf;
	
	// Preparing selected links for performers and performer groups
	Query.SetParameter("EmptyValueGroupsReferences",
		AccessManagementInternalCached.EmptyRefTableOfSpecifiedTypes(
			"InformationRegister.AccessValueGroups.Dimension.AccessValueGroup"));
	
	TemporaryTableQueryText =
	"SELECT
	|	EmptyValueGroupsReferences.EmptyRef
	|INTO EmptyValueGroupsReferences
	|FROM
	|	&EmptyValueGroupsReferences AS EmptyValueGroupsReferences
	|
	|INDEX BY
	|	EmptyValueGroupsReferences.EmptyRef
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	PerformerGroupTable.PerformerGroup,
	|	PerformerGroupTable.User
	|INTO PerformerGroupsUsers
	|FROM
	|	PerformerGroupTable AS PerformerGroupTable
	|		INNER JOIN EmptyValueGroupsReferences AS EmptyValueGroupsReferences
	|		ON (VALUETYPE(PerformerGroupTable.PerformerGroup) = VALUETYPE(EmptyValueGroupsReferences.EmptyRef))
	|			AND PerformerGroupTable.PerformerGroup <> EmptyValueGroupsReferences.EmptyRef
	|WHERE
	|	VALUETYPE(PerformerGroupTable.PerformerGroup) <> TYPE(Catalog.UserGroups)
	|	AND VALUETYPE(PerformerGroupTable.PerformerGroup) <> TYPE(Catalog.Users)
	|	AND VALUETYPE(PerformerGroupTable.PerformerGroup) <> TYPE(Catalog.ExternalUserGroups)
	|	AND VALUETYPE(PerformerGroupTable.PerformerGroup) <> TYPE(Catalog.ExternalUsers)
	|	AND VALUETYPE(PerformerGroupTable.User) = TYPE(Catalog.Users)
	|	AND PerformerGroupTable.User <> VALUE(Catalog.Users.EmptyRef)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	PerformerGroupTable.PerformerGroup,
	|	PerformerGroupTable.User AS ExternalUser
	|INTO ExternalPerformerGroupUsers
	|FROM
	|	PerformerGroupTable AS PerformerGroupTable
	|		INNER JOIN EmptyValueGroupsReferences AS EmptyValueGroupsReferences
	|		ON (VALUETYPE(PerformerGroupTable.PerformerGroup) = VALUETYPE(EmptyValueGroupsReferences.EmptyRef))
	|			AND PerformerGroupTable.PerformerGroup <> EmptyValueGroupsReferences.EmptyRef
	|WHERE
	|	VALUETYPE(PerformerGroupTable.PerformerGroup) <> TYPE(Catalog.UserGroups)
	|	AND VALUETYPE(PerformerGroupTable.PerformerGroup) <> TYPE(Catalog.Users)
	|	AND VALUETYPE(PerformerGroupTable.PerformerGroup) <> TYPE(Catalog.ExternalUserGroups)
	|	AND VALUETYPE(PerformerGroupTable.PerformerGroup) <> TYPE(Catalog.ExternalUsers)
	|	AND VALUETYPE(PerformerGroupTable.User) = TYPE(Catalog.ExternalUsers)
	|	AND PerformerGroupTable.User <> VALUE(Catalog.ExternalUsers.EmptyRef)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP PerformerGroupTable";
	
	If PerformerGroups = Undefined
	   And Performers <> Undefined Then
		
		Query.Text = TemporaryTableQueryText + "
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|" +
		"SELECT
		|	PerformerGroupsUsers.PerformerGroup
		|FROM
		|	PerformerGroupsUsers AS PerformerGroupsUsers
		|
		|UNION
		|
		|SELECT
		|	ExternalPerformerGroupUsers.PerformerGroup
		|FROM
		|	ExternalPerformerGroupUsers AS ExternalPerformerGroupUsers";
		
		QueryResults = Query.ExecuteBatch();
		Quantity = QueryResults.Count();
		
		PerformerGroups = QueryResults[Quantity-1].Unload().UnloadColumn("PerformerGroup");
		TemporaryTableQueryText = Undefined;
	EndIf;
	
	QueryText =
	"SELECT
	|	PerformerGroupsUsers.PerformerGroup AS AccessValue,
	|	PerformerGroupsUsers.User AS AccessValueGroup,
	|	3 AS DataGroup,
	|	&RowChangeKindFieldSubstitution
	|FROM
	|	PerformerGroupsUsers AS PerformerGroupsUsers
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	PerformerGroupsUsers.PerformerGroup,
	|	UserGroupContents.UserGroup,
	|	3,
	|	&RowChangeKindFieldSubstitution
	|FROM
	|	PerformerGroupsUsers AS PerformerGroupsUsers
	|		INNER JOIN InformationRegister.UserGroupContents AS UserGroupContents
	|		ON PerformerGroupsUsers.User = UserGroupContents.User
	|			AND (VALUETYPE(UserGroupContents.UserGroup) = TYPE(Catalog.UserGroups))
	|
	|UNION ALL
	|
	|SELECT
	|	ExternalPerformerGroupUsers.PerformerGroup,
	|	ExternalPerformerGroupUsers.ExternalUser,
	|	3,
	|	&RowChangeKindFieldSubstitution
	|FROM
	|	ExternalPerformerGroupUsers AS ExternalPerformerGroupUsers
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	ExternalPerformerGroupUsers.PerformerGroup,
	|	UserGroupContents.UserGroup,
	|	3,
	|	&RowChangeKindFieldSubstitution
	|FROM
	|	ExternalPerformerGroupUsers AS ExternalPerformerGroupUsers
	|		INNER JOIN InformationRegister.UserGroupContents AS UserGroupContents
	|		ON ExternalPerformerGroupUsers.ExternalUser = UserGroupContents.User
	|			AND (VALUETYPE(UserGroupContents.UserGroup) = TYPE(Catalog.ExternalUserGroups))";
	
	// Preparing selected fields with optional filtering
	Fields = New Array; 
	Fields.Add(New Structure("AccessValue",  "&FilterConditionOfPerformerGroups"));
	Fields.Add(New Structure("AccessValueGroup"));
	Fields.Add(New Structure("DataGroup",     "&UpdatedDataGroupsFilterCondition"));
	
	Query.Text = AccessManagementInternal.ChangeSelectionQueryText(
		QueryText, Fields, "InformationRegister.AccessValueGroups", TemporaryTableQueryText);
	
	AccessManagementInternal.SetFilterCriterionInQuery(Query, PerformerGroups, "PerformerGroups",
		"&FilterConditionOfPerformerGroups:OldData.AccessValue");
	
	AccessManagementInternal.SetFilterCriterionInQuery(Query, 3, "DataGroup",
		"&UpdatedDataGroupsFilterCondition:OldData.DataGroup");
	
	Changes = Query.Execute().Unload();
	
	FixedFilter = New Structure;
	FixedFilter.Insert("DataGroup", 3);
	
	AccessManagementInternal.UpdateInformationRegister(
		InformationRegisters.AccessValueGroups, Changes, HasChanges, FixedFilter);
	
EndProcedure

// Updates user groups to check the
// allowed values for the Users and ExternalUsers access kinds.
//
// <AccessValue field content> <AccessValueGroup field content>
//                             <DataGroup field content> 
// b) for External users
// access kind
// {comparison with T.<field>} {Comparison with AccessGroupValues.AccessValue}
//                             {Comparison with &CurrentExternalUser}
//
// Authorization  object         4 - External user
//                                   of the same authorization object.
//
//                               4 - External user group
//                                   
//                                   of an external user 
//                                   of the same authorization object.
//
Procedure UpdateAuthorizationObjects(AuthorizationObjects = Undefined, HasChanges = Undefined)
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.SetParameter("EmptyValueReferences",
		AccessManagementInternalCached.EmptyRefTableOfSpecifiedTypes(
			"InformationRegister.AccessValueGroups.Dimension.AccessValue"));
	
	TemporaryTableQueryText =
	"SELECT
	|	EmptyValueReferences.EmptyRef
	|INTO EmptyValueReferences
	|FROM
	|	&EmptyValueReferences AS EmptyValueReferences
	|
	|INDEX BY
	|	EmptyValueReferences.EmptyRef";
	
	QueryText =
	"SELECT
	|	CAST(UserGroupContents.User AS Catalog.ExternalUsers).AuthorizationObject AS AccessValue,
	|	UserGroupContents.UserGroup AS AccessValueGroup,
	|	4 AS DataGroup,
	|	&RowChangeKindFieldSubstitution
	|FROM
	|	InformationRegister.UserGroupContents AS UserGroupContents
	|		INNER JOIN Catalog.ExternalUsers AS ExternalUsers
	|		ON (VALUETYPE(UserGroupContents.User) = TYPE(Catalog.ExternalUsers))
	|			AND UserGroupContents.User = ExternalUsers.Ref
	|		INNER JOIN EmptyValueReferences AS EmptyValueReferences
	|		ON (VALUETYPE(ExternalUsers.AuthorizationObject) = VALUETYPE(EmptyValueReferences.EmptyRef))
	|			AND (ExternalUsers.AuthorizationObject <> EmptyValueReferences.EmptyRef)
	|WHERE
	|	&FilterConditionOfAuthorizationObjects1";
	
	// Preparing selected fields with optional filtering
	Fields = New Array; 
	Fields.Add(New Structure("AccessValue",         "&FilterConditionOfAuthorizationObjects2"));
	Fields.Add(New Structure("AccessValueGroup"));
	Fields.Add(New Structure("DataGroup",            "&UpdatedDataGroupsFilterCondition"));
	
	Query.Text = AccessManagementInternal.ChangeSelectionQueryText(
		QueryText, Fields, "InformationRegister.AccessValueGroups", TemporaryTableQueryText);
	
	AccessManagementInternal.SetFilterCriterionInQuery(Query, AuthorizationObjects, "AuthorizationObjects",
		"&FilterConditionOfAuthorizationObjects1:ExternalUsers.AuthorizationObject &FilterConditionOfAuthorizationObjects2:OldData.AccessValue");
	
	AccessManagementInternal.SetFilterCriterionInQuery(Query, 4, "DataGroup",
		"&UpdatedDataGroupsFilterCondition:OldData.DataGroup");
	
	Changes = Query.Execute().Unload();
	
	FixedFilter = New Structure;
	FixedFilter.Insert("DataGroup", 4);
	
	AccessManagementInternal.UpdateInformationRegister(
		InformationRegisters.AccessValueGroups, Changes, HasChanges, FixedFilter);
	
EndProcedure

#EndRegion

#EndIf