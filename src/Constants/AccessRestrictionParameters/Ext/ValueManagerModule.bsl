#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region InternalInterface

// Updates the description of access kind properties in
// access restriction options when changing configuration.
// 
// Parameters:
//  HasChanges - Boolean (return value) - True if
//               data is changed; not set otherwise.
//
Procedure UpdateAccessKindPropertyDescription(HasChanges = Undefined, CheckOnly = False) Export
	
	SetPrivilegedMode(True);
	
	If CheckOnly Or ExclusiveMode() Then
		DisableExclusiveMode = False;
	Else
		DisableExclusiveMode = True;
		SetExclusiveMode(True);
	EndIf;
	
	AccessKindsProperties = AccessKindsProperties();
	
	DataLock = New DataLock;
	LockItem = DataLock.Add("Constant.AccessRestrictionParameters");
	LockItem.Mode = DataLockMode.Exclusive;
	
	BeginTransaction();
	Try
		DataLock.Lock();
		
		Parameters = StandardSubsystemsServer.ApplicationParameters(
			"AccessRestrictionParameters");
		
		Saved = Undefined;
		
		If Parameters.Property("AccessKindsProperties") Then
			Saved = Parameters.AccessKindsProperties;
			
			If Not CommonUse.IsEqualData(AccessKindsProperties, Saved) Then
				AreChangesOfGroupTypesAndAccessValues =
					AreChangesOfGroupTypesAndAccessValues(AccessKindsProperties, Saved);
				Saved = Undefined;
			EndIf;
		EndIf;
		
		If Saved = Undefined Then
			HasChanges = True;
			If CheckOnly Then
				CommitTransaction();
				Return;
			EndIf;
			StandardSubsystemsServer.SetApplicationParameter(
				"AccessRestrictionParameters",
				"AccessKindsProperties",
				AccessKindsProperties);
		EndIf;
		
		StandardSubsystemsServer.ConfirmApplicationParametersUpdate(
			"AccessRestrictionParameters",
			"AccessKindsProperties");
		
		If Not CheckOnly Then
			StandardSubsystemsServer.AddApplicationParameterChanges(
				"AccessRestrictionParameters",
				"GroupAndAccessValueTypes",
				?(AreChangesOfGroupTypesAndAccessValues = True,
				  New FixedStructure("HasChanges", True),
				  New FixedStructure()) );
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

#EndRegion

#Region InternalProceduresAndFunctions

// Returns the properties of access kinds that are filled
// when embedding data in the procedure OnFillAccessKinds of
// the AccessManagementOverridable common module
// and other procedures with the same name for internal events.
//
Function AccessKindsProperties()
	
	// 1. Filling the data specified when embedding
	
	AccessKinds = New ValueTable;
	AccessKinds.Columns.Add("Name",                    New TypeDescription("String"));
	AccessKinds.Columns.Add("Presentation",        New TypeDescription("String")); 
	AccessKinds.Columns.Add("ValueType",           New TypeDescription("Type"));
	AccessKinds.Columns.Add("ValueGroupType",      New TypeDescription("Type"));
	AccessKinds.Columns.Add("MultipleValueGroups", New TypeDescription("Boolean"));
	AccessKinds.Columns.Add("ExtrasTypes",         New TypeDescription("ValueTable"));
	
	AccessKindUsers = AccessKinds.Add();
	AccessKindExternalUsers = AccessKinds.Add();
	
	FillUnchangedPropertiesOfAccessKindsUsersAndExternalUsers(
		AccessKindUsers, AccessKindExternalUsers);
	
	EventHandlers = CommonUse.InternalEventHandlers(
		"StandardSubsystems.AccessManagement\OnFillAccessKinds");
	
	For Each Handler In EventHandlers Do
		Handler.Module.OnFillAccessKinds(AccessKinds);
	EndDo;
	
	AccessManagementOverridable.OnFillAccessKinds(AccessKinds);
	
	FillUnchangedPropertiesOfAccessKindsUsersAndExternalUsers(
		AccessKindUsers, AccessKindExternalUsers);
	
	// Checking the following conditions:
	// - access value type is not specified for 2 access kinds
	// - access value type Users, UserGroups is used only for Users access type.
	// - ExternalUsers, ExternalUserGroups access value type is used only for ExternalUsers access kind.
	// - the following names of access kinds - Object, Condition, RightsSettings, ReadRight, EditRight - are not specified.
	// - value group type does not match the value type.
	
	// 2. Preparing various collections of access type properties used when working with the program.
	PropertyArray         = New Array;
	ByLinks               = New Map;
	ByNames               = New Map;
	ByValueTypes          = New Map;
	ByGroupTypesAndValues = New Map;
	
	AccessValuesWithGroups = New Structure;
	AccessValuesWithGroups.Insert("ByTypes",         New Map);
	AccessValuesWithGroups.Insert("ByRefTypes",      New Map);
	AccessValuesWithGroups.Insert("TableNames",      New Array);
	AccessValuesWithGroups.Insert("ValueGroupTypes", New Map);
	
	Parameters = New Structure;
	Parameters.Insert("AccessValueDefinedTypes",
		AccessManagementInternalCached.TableFieldTypes("DefinedType.AccessValue"));
	
	ErrorTitle =
		NStr("en = 'Error in FillAccessKindProperties procedure of
		           |AccessManagementOverridable common module.
		           |
		           |'");
	
	Parameters.Insert("ErrorTitle", ErrorTitle);
	
	Parameters.Insert("SubscriptionTypesRefreshAccessValuesGroups",
		AccessManagementInternalCached.ObjectTypesInEventSubscriptions(
			"UpdateAccessValueGroups"));
	
	AllAccessKindNames = New Map;
	AllAccessKindNames.Insert(Upper("Object"),         True);
	AllAccessKindNames.Insert(Upper("Condition"),      True);
	AllAccessKindNames.Insert(Upper("RightsSettings"), True);
	AllAccessKindNames.Insert(Upper("ReadRight"),      True);
	AllAccessKindNames.Insert(Upper("EditRight"),      True);
	
	AllValueTypes      = New Map;
	AllValueGroupTypes = New Map;
	
	For Each AccessKind In AccessKinds Do
		
		If AllAccessKindNames[Upper(AccessKind.Name)] <> Undefined Then
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				ErrorTitle +
				NStr("en = 'Access type name %1 is already specified.'"),
				AccessKind.Name);
		EndIf;
		
		// Checking for duplicate value types and group types
		CheckType(AccessKind, AccessKind.ValueType,      AllValueTypes,      Parameters);
		CheckType(AccessKind, AccessKind.ValueGroupType, AllValueGroupTypes, Parameters, True);
		// Checking for intersecting value types and group types
		CheckType(AccessKind, AccessKind.ValueType,      AllValueGroupTypes, Parameters,       , True);
		CheckType(AccessKind, AccessKind.ValueGroupType, AllValueTypes,      Parameters, True, True);
		
		For Each Row In AccessKind.ExtrasTypes Do
			// Checking for duplicate value types and group types
			CheckType(AccessKind, Row.ValueType,      AllValueTypes,      Parameters);
			CheckType(AccessKind, Row.ValueGroupType, AllValueGroupTypes, Parameters, True);
			// Checking for intersecting value types and group types
			CheckType(AccessKind, Row.ValueType,      AllValueGroupTypes, Parameters,       , True);
			CheckType(AccessKind, Row.ValueGroupType, AllValueTypes,      Parameters, True, True);
		EndDo;
		
		ValueTypeEmptyRef = CommonUse.ObjectManagerByFullName(
			Metadata.FindByType(AccessKind.ValueType).FullName()).EmptyRef();
		
		Properties = New Structure;
		Properties.Insert("Name",                  AccessKind.Name);
		Properties.Insert("Ref",                   ValueTypeEmptyRef);
		Properties.Insert("Presentation",          AccessKind.Presentation);
		Properties.Insert("ValueType",             AccessKind.ValueType);
		Properties.Insert("ValueGroupType",        AccessKind.ValueGroupType);
		Properties.Insert("MultipleValueGroups",   AccessKind.MultipleValueGroups);
		Properties.Insert("ExtrasTypes",           New Array);
		Properties.Insert("TypesOfValuesToSelect", New Array);
		
		PropertyArray.Add(Properties);
		ByNames.Insert(Properties.Name, Properties);
		ByLinks.Insert(ValueTypeEmptyRef, Properties);
		ByValueTypes.Insert(Properties.ValueType, Properties);
		ByGroupTypesAndValues.Insert(Properties.ValueType, Properties);
		If Properties.ValueGroupType <> Type("Undefined") Then
			ByGroupTypesAndValues.Insert(Properties.ValueGroupType, Properties);
		EndIf;
		FillInAccessValueToGroups(Properties, AccessValuesWithGroups, Properties, Parameters);
		
		For Each Row In AccessKind.ExtrasTypes Do
			Item = New Structure;
			Item.Insert("ValueType",            Row.ValueType);
			Item.Insert("ValueGroupType",       Row.ValueGroupType);
			Item.Insert("MultipleValueGroups",  Row.MultipleValueGroups);
			Properties.ExtrasTypes.Add(Item);
			ByValueTypes.Insert(Row.ValueType, Properties);
			ByGroupTypesAndValues.Insert(Row.ValueType, Properties);
			If Row.ValueGroupType <> Type("Undefined") Then
				ByGroupTypesAndValues.Insert(Row.ValueGroupType, Properties);
			EndIf;
			FillInAccessValueToGroups(Row, AccessValuesWithGroups, Properties, Parameters);
		EndDo;
		
	EndDo;
	
	WithoutGroupsForAccessValues = New Array;
	WithOneGroupForAccessValue   = New Array;
	AccessValueTypesWithGroups   = New Map;
	
	AccessKindsWithGroups = New Map;
	
	For Each KeyAndValue In AccessValuesWithGroups.ByRefTypes Do
		AccessKindName = KeyAndValue.Value.Name;
		AccessKindsWithGroups.Insert(AccessKindName, True);
		
		EmptyRef = AccessManagementInternal.MetadataObjectEmptyRef(KeyAndValue.Key);
		AccessValueTypesWithGroups.Insert(TypeOf(EmptyRef), EmptyRef);
		
		If Not KeyAndValue.Value.MultipleValueGroups
		   And WithOneGroupForAccessValue.Find(AccessKindName) = Undefined Then
		   
			WithOneGroupForAccessValue.Add(AccessKindName);
		EndIf;
	EndDo;
	
	AccessValueTypesWithGroups.Insert(Type("CatalogRef.Users"),
		Catalogs.Users.EmptyRef());
	
	AccessValueTypesWithGroups.Insert(Type("CatalogRef.UserGroups"),
		Catalogs.UserGroups.EmptyRef());
	
	AccessValueTypesWithGroups.Insert(Type("CatalogRef.ExternalUsers"),
		Catalogs.ExternalUsers.EmptyRef());
	
	AccessValueTypesWithGroups.Insert(Type("CatalogRef.ExternalUserGroups"),
		Catalogs.ExternalUserGroups.EmptyRef());
	
	For Each AccessKindProperties In PropertyArray Do
		If AccessKindsWithGroups.Get(AccessKindProperties.Name) <> Undefined Then
			Continue;
		EndIf;
		If AccessKindProperties.Name = "Users"
		 Or AccessKindProperties.Name = "ExternalUsers" Then
			Continue;
		EndIf;
		WithoutGroupsForAccessValues.Add(AccessKindProperties.Name);
	EndDo;
	
	AccessKindsProperties = New Structure;
	AccessKindsProperties.Insert("Array",                       PropertyArray);
	AccessKindsProperties.Insert("ByNames",                     ByNames);
	AccessKindsProperties.Insert("ByLinks",                     ByLinks);
	AccessKindsProperties.Insert("ByValueTypes",                ByValueTypes);
	AccessKindsProperties.Insert("ByGroupTypesAndValues",       ByGroupTypesAndValues);
	AccessKindsProperties.Insert("AccessValuesWithGroups",      AccessValuesWithGroups);
	AccessKindsProperties.Insert("WithoutGroupsForAccessValues",WithoutGroupsForAccessValues);
	AccessKindsProperties.Insert("WithOneGroupForAccessValue", WithOneGroupForAccessValue);
	AccessKindsProperties.Insert("AccessValueTypesWithGroups", AccessValueTypesWithGroups);
	
	Return CommonUse.FixedData(AccessKindsProperties);
	
EndFunction

Procedure FillInAccessValueToGroups(Row, AccessValuesWithGroups, Properties, Parameters)
	
	If Properties.Name = "Users" Then
		AddToArray(Properties.TypesOfValuesToSelect, Type("CatalogRef.Users"));
		AddToArray(Properties.TypesOfValuesToSelect, Type("CatalogRef.UserGroups"));
		Return;
	EndIf;
	
	If Properties.Name = "ExternalUsers" Then
		AddToArray(Properties.TypesOfValuesToSelect, Type("CatalogRef.ExternalUsers"));
		AddToArray(Properties.TypesOfValuesToSelect, Type("CatalogRef.ExternalUserGroups"));
		Return;
	EndIf;
	
	If Row.ValueGroupType = Type("Undefined") Then
		AddToArray(Properties.TypesOfValuesToSelect, Row.ValueType);
		Return;
	EndIf;
	
	RefType = Row.ValueType;
	
	ValueTypeMetadata = Metadata.FindByType(Row.ValueType);
	If CommonUse.IsEnum(ValueTypeMetadata) Then
		ObjectType = RefType;
	Else
		ObjectType = StandardSubsystemsServer.MetadataObjectOrMetadataObjectRecordSetType(
			ValueTypeMetadata);
	EndIf;
	
	If Row.ValueGroupType <> Type("Undefined") Then
		AddToArray(Properties.TypesOfValuesToSelect, Row.ValueGroupType);
	EndIf;
	
	AccessValuesWithGroups.ByTypes.Insert(RefType,  Properties);
	AccessValuesWithGroups.ByTypes.Insert(ObjectType, Properties);
	AccessValuesWithGroups.ByRefTypes.Insert(RefType, Properties);
	AccessValuesWithGroups.TableNames.Add(ValueTypeMetadata.FullName());
	
	MetadataOfValueGroupType = Metadata.FindByType(Row.ValueGroupType);
	EmptyValueGroupTypeRef =
		AccessManagementInternal.MetadataObjectEmptyRef(MetadataOfValueGroupType);
	
	AccessValuesWithGroups.ValueGroupTypes.Insert(RefType, EmptyValueGroupTypeRef);
	AccessValuesWithGroups.ValueGroupTypes.Insert(
		AccessManagementInternal.MetadataObjectEmptyRef(ValueTypeMetadata),
		EmptyValueGroupTypeRef);
	
	// Checking whether reference type exists in the corresponding metadata objects
	If Parameters.SubscriptionTypesRefreshAccessValuesGroups.Get(ObjectType) = Undefined
	   And Not CommonUse.IsEnum(ValueTypeMetadata) Then
		
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			Parameters.ErrorTitle +
			NStr("en = 'Access value type %1 that uses value groups,
			           | is not specified in the subscription for ""Update access value groups"" event.'"),
			String(ObjectType));
	EndIf;
	
EndProcedure

Procedure FillUnchangedPropertiesOfAccessKindsUsersAndExternalUsers(
		AccessKindUsers, AccessKindExternalUsers)
	
	AccessKindUsers.Name                = "Users";
	AccessKindUsers.Presentation        = NStr("en = 'Users'");
	AccessKindUsers.ValueType           = Type("CatalogRef.Users");
	AccessKindUsers.ValueGroupType      = Type("CatalogRef.UserGroups");
	AccessKindUsers.MultipleValueGroups = True;
	
	AccessKindExternalUsers.Name                = "ExternalUsers";
	AccessKindExternalUsers.Presentation        = NStr("en = 'External users'");
	AccessKindExternalUsers.ValueType           = Type("CatalogRef.ExternalUsers");
	AccessKindExternalUsers.ValueGroupType      = Type("CatalogRef.ExternalUserGroups");
	AccessKindExternalUsers.MultipleValueGroups = True;
	
EndProcedure

Procedure CheckType(AccessKind, Type, AllTypes, Parameters, CheckingGroupTypes = False, IntersectionCheck = False)
	
	If Type = Type("Undefined") Then
		If CheckingGroupTypes Then
			Return;
		EndIf;
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			Parameters.ErrorTitle +
			NStr("en = 'Access value type is not specified for %1 access kind.'"),
			AccessKind.Name);
	EndIf;
	
	// Check whether the reference type is specified
	If Not CommonUse.IsReference(Type) Then
		If CheckingGroupTypes Then
			ErrorDescription =
				NStr("en = 'Type %1 is specified as a value group type for access kind %2.
				           |However it is not a reference type.'");
		Else
			ErrorDescription =
				NStr("en = '""%1"" type is specified as a value type for a ""%2"" access type.
				           |However this is not the reference type.'");
		EndIf;
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			Parameters.ErrorTitle + ErrorDescription, Type, AccessKind.Name);
	EndIf;
	
	// Checking for duplicate and intersecting value types and value groups
	ForSameTypeOfAccessNoErrors = False;
	
	If CheckingGroupTypes Then
		If IntersectionCheck Then
			ErrorDescription =
				NStr("en = 'Type %1 is specified as a value type for access type %2.
				           |It cannot be specified as a value group type for access type %3.'");
		Else
			ForSameTypeOfAccessNoErrors = True;
			ErrorDescription =
				NStr("en = 'Value type %1 is already specified for an access type %2.
				           |It cannot be specified for access kind %3.'");
		EndIf;
	Else
		If IntersectionCheck Then
			ErrorDescription =
				NStr("en = 'Type %1 is specified as a value type for access type %2.
				           |It cannot be specified as a value group type for access type %3.'");
		Else
			ErrorDescription =
				NStr("en = 'Value type %1 is already specified for an access type %2.
				           |It cannot be specified for access kind %3.'");
		EndIf;
	EndIf;
	
	If AllTypes.Get(Type) <> Undefined Then
		If Not (ForSameTypeOfAccessNoErrors And AccessKind.Name = AllTypes.Get(Type)) Then
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				Parameters.ErrorTitle + ErrorDescription, Type, AllTypes.Get(Type), AccessKind.Name);
		EndIf;
	ElsIf Not IntersectionCheck Then
		AllTypes.Insert(Type, AccessKind.Name);
	EndIf;
	
	// Checking the defined types content
	ErrorDescription = "";
	If Parameters.AccessValueDefinedTypes.Get(Type) = Undefined Then
		If CheckingGroupTypes Then
			ErrorDescription =
				NStr("en = 'Access value group type %1 of access kind %2
				           |is not specified in ""Access value"" type.'");
		Else
			ErrorDescription =
				NStr("en = 'Access value type %1 of access kind %2
				           |is not specified in ""Access value"" type.'");
		EndIf;
	EndIf;
	
	If ValueIsFilled(ErrorDescription) Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			Parameters.ErrorTitle + ErrorDescription,
			Type,
			AccessKind.Name);
	EndIf;
	
EndProcedure

Procedure AddToArray(Array, Value)
	
	If Array.Find(Value) = Undefined Then
		Array.Add(Value);
	EndIf;
	
EndProcedure

// Checks whether there are changes in group types and access values
Function AreChangesOfGroupTypesAndAccessValues(AccessKindsProperties, Saved)
	
	If Not TypeOf(Saved) = Type("FixedStructure")
	 Or Not Saved.Property("ByValueTypes")
	 Or Not Saved.Property("AccessValueTypesWithGroups")
	 Or Not TypeOf(Saved.ByValueTypes)               = Type("FixedMap")
	 Or Not TypeOf(Saved.AccessValueTypesWithGroups) = Type("FixedMap")
	 Or Not AccessKindsProperties.Property("ByValueTypes")
	 Or Not AccessKindsProperties.Property("AccessValueTypesWithGroups")
	 Or Not TypeOf(AccessKindsProperties.ByValueTypes)               = Type("FixedMap")
	 Or Not TypeOf(AccessKindsProperties.AccessValueTypesWithGroups) = Type("FixedMap") Then
	
		Return True;
	EndIf;
	
	If MapKeysDiffer(AccessKindsProperties.ByValueTypes, Saved.ByValueTypes) Then
		Return True;
	EndIf;
	
	If MapKeysDiffer(AccessKindsProperties.AccessValueTypesWithGroups,
			Saved.AccessValueTypesWithGroups) Then
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

Function MapKeysDiffer(NewCollection, OldCollection)
	
	If NewCollection.Count() <> OldCollection.Count() Then
		Return True;
	EndIf;
	
	For Each KeyAndValue In NewCollection Do
		If OldCollection.Get(KeyAndValue.Key) = Undefined Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

#EndRegion

#EndIf
