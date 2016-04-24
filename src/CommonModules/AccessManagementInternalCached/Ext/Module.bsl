////////////////////////////////////////////////////////////////////////////////
// Access management subsystem
// 
////////////////////////////////////////////////////////////////////////////////

#Region InternalProceduresAndFunctions

// Contains saved parameters used by the subsystem
Function Parameters() Export
	
	SetPrivilegedMode(True);
	SavedParameters = StandardSubsystemsServer.ApplicationParameters(
		"AccessRestrictionParameters");
	SetPrivilegedMode(False);
	
	StandardSubsystemsServer.CheckIfApplicationParametersUpdated(
		"AccessRestrictionParameters",
		"AvailableRightsForObjectRightsSettings,
		|SuppliedAccessGroupProfiles,
		|AccessGroupPredefinedProfiles,
		|AccessKindsProperties");
	
	ParameterPresentation = "";
	
	If Not SavedParameters.Property("AvailableRightsForObjectRightsSettings") Then
		ParameterPresentation = NStr("en = 'Available rights for object rights settings'");
		
	ElsIf Not SavedParameters.Property("SuppliedAccessGroupProfiles") Then
		ParameterPresentation = NStr("en = 'Supplied access group profiles'");
		
	ElsIf Not SavedParameters.Property("AccessGroupPredefinedProfiles") Then
		ParameterPresentation = NStr("en = 'Access group predefined profiles'");
		
	ElsIf Not SavedParameters.Property("AccessKindsProperties") Then
		ParameterPresentation = NStr("en = 'Access kind properties'");
	EndIf;
	
	If ValueIsFilled(ParameterPresentation) Then
		
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Infobase update error.
			           |""%1"" 
                |access restriction parameter is not filled.'")
			+ StandardSubsystemsServer.ApplicationRunParameterErrorClarificationForDeveloper(),
			ParameterPresentation);
	EndIf;
	
	Return SavedParameters;
	
EndFunction

// Returns the value table containing an access restriction kind
// for each metadata object right.
//  If no record is available for a right, no restrictions are set for this right.
//  The table contains only the access kinds specified by the developer,
//  based on their usage in restriction texts.
//  To get all access kinds including the ones 
//  used in access value sets,
// the current state of AccessValueSets information register can be used.
//
// Returns:
//  ValueTable:
//    Table          - String - Metadata object table name,
//                              for example, Catalog.Files.  
//    Right          - String - Read, Change
//    AccessKind     - Ref - an empty reference of main value type of access kind,
//                          an empty reference of right settings owner.
//                   - Undefined - for the Object access kind.
//    ObjectTable    - Ref - an empty reference to metadata object used to set 
//                     access restrictions via access value sets, for example, Catalog.FileFolders.
//                   - Undefined - if AccessKind <> Undefined.
//
Function PermanentRightRestrictionKindsOfMetadataObjects() Export
	
	SetPrivilegedMode(True);
	
	KindsOfAccessRight = New ValueTable;
	KindsOfAccessRight.Columns.Add("Table",        New TypeDescription("CatalogRef.MetadataObjectIDs"));
	KindsOfAccessRight.Columns.Add("Right",        New TypeDescription("String", , New StringQualifiers(20)));
	KindsOfAccessRight.Columns.Add("AccessKind",   DescriptionOfAccessValueTypesAndRightsSettingsOwners());
	KindsOfAccessRight.Columns.Add("ObjectTable", Metadata.InformationRegisters.AccessValueSets.Dimensions.Object.Type);
	
	RightRestrictions = "";
	
	EventHandlers = CommonUse.InternalEventHandlers(
		"StandardSubsystems.AccessManagement\OnFillMetadataObjectAccessRestrictionKinds");
	
	For Each Handler In EventHandlers Do
		Handler.Module.OnFillMetadataObjectAccessRestrictionKinds(RightRestrictions);
	EndDo;
	
	AccessManagementOverridable.OnFillMetadataObjectAccessRestrictionKinds(RightRestrictions);
	
	AccessKindsByNames = AccessManagementInternalCached.Parameters().AccessKindsProperties.ByNames;
	
	For LineNumber = 1 To StrLineCount(RightRestrictions) Do
		CurrentRow = StrGetLine(RightRestrictions, LineNumber);
		If ValueIsFilled(CurrentRow) Then
			ErrorComment = "";
			If StrOccurrenceCount(CurrentRow, ".") <> 3 And StrOccurrenceCount(CurrentRow, ".") <> 5 Then
				ErrorComment = NStr("en = 'String must be in format: ""<Table full name>.<Right name>.<Access kind name>[.Object table]"".'");
			Else
				RightPosition = Find(CurrentRow, ".");
				RightPosition = Find(Mid(CurrentRow, RightPosition + 1), ".") + RightPosition;
				Table = Left(CurrentRow, RightPosition - 1);
				AccessKindPosition = Find(Mid(CurrentRow, RightPosition + 1), ".") + RightPosition;
				Right = Mid(CurrentRow, RightPosition + 1, AccessKindPosition - RightPosition - 1);
				If StrOccurrenceCount(CurrentRow, ".") = 3 Then
					AccessKind = Mid(CurrentRow, AccessKindPosition + 1);
					ObjectTable = "";
				Else
					ObjectTablePosition = Find(Mid(CurrentRow, AccessKindPosition + 1), ".") + AccessKindPosition;
					AccessKind = Mid(CurrentRow, AccessKindPosition + 1, ObjectTablePosition - AccessKindPosition - 1);
					ObjectTable = Mid(CurrentRow, ObjectTablePosition + 1);
				EndIf;
				
				If Metadata.FindByFullName(Table) = Undefined Then
					ErrorComment = StringFunctionsClientServer.SubstituteParametersInString(
						NStr("en = '""%1"" table is not found.'"),
						Table);
				
				ElsIf Right <> "Read" And Right <> "Update" Then
					ErrorComment = StringFunctionsClientServer.SubstituteParametersInString(
						NStr("en = '""%1"" right is not found.'"),
						Right);
				
				ElsIf Upper(AccessKind) = Upper("Object") Then
					If Metadata.FindByFullName(ObjectTable) = Undefined Then
						ErrorComment = StringFunctionsClientServer.SubstituteParametersInString(
							NStr("en = '""%1"" object table is not found.'"),
							ObjectTable);
					Else
						AccessKindRef = Undefined;
						ObjectTableRef = AccessManagementInternal.MetadataObjectEmptyRef(
							ObjectTable);
					EndIf;
					
				ElsIf Upper(AccessKind) = Upper("RightsSettings") Then
					If Metadata.FindByFullName(ObjectTable) = Undefined Then
						ErrorComment = StringFunctionsClientServer.SubstituteParametersInString(
							NStr("en = '""%1"" right settings owner table is not found.'"),
							ObjectTable);
					Else
						AccessKindRef = AccessManagementInternal.MetadataObjectEmptyRef(
							ObjectTable);
						ObjectTableRef = Undefined;
					EndIf;
				
				ElsIf AccessKindsByNames.Get(AccessKind) = Undefined Then
					ErrorComment = StringFunctionsClientServer.SubstituteParametersInString(
						NStr("en = '""%1"" access kind is not found.'"),
						AccessKind);
				Else
					AccessKindRef = AccessKindsByNames.Get(AccessKind).Ref;
					ObjectTableRef = Undefined;
				EndIf;
			EndIf;
			
			If ValueIsFilled(ErrorComment) Then
				Raise(StringFunctionsClientServer.SubstituteParametersInString(
						NStr("en = 'Error in the row of kind description of metadata object right restrictions:
						           | ""%1"" 
						           |
						           |'"), CurrentRow) + ErrorComment);
			Else
				AccessKindProperties = AccessKindsByNames.Get(AccessKind);
				NewDetails = KindsOfAccessRight.Add();
				NewDetails.Table       = CommonUse.MetadataObjectID(Table);
				NewDetails.Right       = Right;
				NewDetails.AccessKind  = AccessKindRef;
				NewDetails.ObjectTable = ObjectTableRef;
			EndIf;
		EndIf;
	EndDo;
	
	// Adding the object access kinds that are defined both by access value sets
 // and by other means
	Query = New Query;
	Query.Text =
	"SELECT
	|	AccessRightDependencies.SubordinateTable,
	|	AccessRightDependencies.LeadingTableType
	|FROM
	|	InformationRegister.AccessRightDependencies AS AccessRightDependencies";
	RightDependencies = Query.Execute().Unload();
	
	StopAttempts = False;
	While Not StopAttempts Do
		StopAttempts = True;
		Filter = New Structure("AccessKind", Undefined);
		AccessKindsObject = KindsOfAccessRight.FindRows(Filter);
		For Each Row In AccessKindsObject Do
			TableID = CommonUse.MetadataObjectID(
				TypeOf(Row.ObjectTable));
			
			Filter = New Structure;
			Filter.Insert("SubordinateTable", Row.Table);
			Filter.Insert("LeadingTableType", Row.ObjectTable);
			If RightDependencies.FindRows(Filter).Count() = 0 Then
				MasterRight = Row.Right;
			Else
				MasterRight = "Read";
			EndIf;
			Filter = New Structure("Table, Right", TableID, MasterRight);
			LeadingTableAccessKinds = KindsOfAccessRight.FindRows(Filter);
			For Each AccessKindDescription In LeadingTableAccessKinds Do
				If AccessKindDescription.AccessKind = Undefined Then
					// Object access kind cannot be added
					Continue;
				EndIf;
				Filter = New Structure;
				Filter.Insert("Table",    Row.Table);
				Filter.Insert("Right",      Row.Right);
				Filter.Insert("AccessKind", AccessKindDescription.AccessKind);
				If KindsOfAccessRight.FindRows(Filter).Count() = 0 Then
					FillPropertyValues(KindsOfAccessRight.Add(), Filter);
					StopAttempts = False;
				EndIf;
			EndDo;
		EndDo;
	EndDo;
	
	Return KindsOfAccessRight;
	
EndFunction

// For internal use only
Function RecordKeyDescription(TypeORFullName) Export
	
	KeyDescription = New Structure("FieldArray, FieldRow", New Array, "");
	
	If TypeOf(TypeORFullName) = Type("Type") Then
		MetadataObject = Metadata.FindByType(TypeORFullName);
	Else
		MetadataObject = Metadata.FindByFullName(TypeORFullName);
	EndIf;
	Manager = CommonUse.ObjectManagerByFullName(MetadataObject.FullName());
	
	For Each Column In Manager.CreateRecordSet().Unload().Columns Do
		
		If MetadataObject.Resources.Find(Column.Name) = Undefined
		   And MetadataObject.Attributes.Find(Column.Name) = Undefined Then
			// If a field is not found in resources or attributes, this field is a dimension
			KeyDescription.FieldArray.Add(Column.Name);
			KeyDescription.FieldRow = KeyDescription.FieldRow + Column.Name + ",";
		EndIf;
	EndDo;
	
	KeyDescription.FieldRow = Left(KeyDescription.FieldRow, StrLen(KeyDescription.FieldRow)-1);
	
	Return CommonUse.FixedData(KeyDescription);
	
EndFunction

// For internal use only
Function TableFieldTypes(FullFieldName) Export
	
	MetadataObject = Metadata.FindByFullName(FullFieldName);
	
	TypeArray = MetadataObject.Type.Types();
	
	TypesOfFields = New Map;
	For Each Type In TypeArray Do
		TypesOfFields.Insert(Type, True);
	EndDo;
	
	Return TypesOfFields;
	
EndFunction

// Returns the types of objects and references used in the specified event subscriptions.
// 
// Parameters:
//  SubscriptionNames - String - a multiline string containing
//                   rows of the subscription name beginning.
//
Function ObjectTypesInEventSubscriptions(SubscriptionNames, EmptyLinkArray = False) Export
	
	ObjectTypes = New Map;
	
	For Each Subscription In Metadata.EventSubscriptions Do
		
		For LineNumber = 1 To StrLineCount(SubscriptionNames) Do
			
			NameBeginning = StrGetLine(SubscriptionNames, LineNumber);
			SubscriptionName = Subscription.Name;
			// _Demo example begin
			If Left(SubscriptionName, 5) = "_Demo" Then
				SubscriptionName = Mid(SubscriptionName, 6);
			EndIf;
			// _Demo example end
			If Upper(Left(SubscriptionName, StrLen(NameBeginning))) = Upper(NameBeginning) Then
				
				For Each Type In Subscription.Source.Types() Do
					ObjectTypes.Insert(Type, True);
				EndDo;
			EndIf;
			
		EndDo;
		
	EndDo;
	
	If Not EmptyLinkArray Then
		Return New FixedMap(ObjectTypes);
	EndIf;
	
	Array = New Array;
	For Each KeyAndValue In ObjectTypes Do
		Array.Add(AccessManagementInternal.MetadataObjectEmptyRef(
			KeyAndValue.Key));
	EndDo;
	
	Return New FixedArray(Array);
	
EndFunction

// For internal use only
Function EmptyRecordSetTable(RegisterFullName) Export
	
	Manager = CommonUse.ObjectManagerByFullName(RegisterFullName);
	
	Return Manager.CreateRecordSet().Unload();
	
EndFunction

// For internal use only
Function EmptyRefTableOfSpecifiedTypes(AttributeFullName) Export
	
	TypeDescription = Metadata.FindByFullName(AttributeFullName).Type;
	
	EmptyReferences = New ValueTable;
	EmptyReferences.Columns.Add("EmptyRef", TypeDescription);
	
	For Each ValueType In TypeDescription.Types() Do
		If CommonUse.IsReference(ValueType) Then
			EmptyReferences.Add().EmptyRef = CommonUse.ObjectManagerByFullName(
				Metadata.FindByType(ValueType).FullName()).EmptyRef();
		EndIf;
	EndDo;
	
	Return EmptyReferences;
	
EndFunction

// For internal use only
Function EmptyRefMappingToSpecifiedRefTypes(AttributeFullName) Export
	
	TypeDescription = Metadata.FindByFullName(AttributeFullName).Type;
	
	EmptyReferences = New Map;
	
	For Each ValueType In TypeDescription.Types() Do
		If CommonUse.IsReference(ValueType) Then
			EmptyReferences.Insert(ValueType, CommonUse.ObjectManagerByFullName(
				Metadata.FindByType(ValueType).FullName()).EmptyRef() );
		EndIf;
	EndDo;
	
	Return New FixedMap(EmptyReferences);
	
EndFunction

// For internal use only
Function LinkTypeCodes(AttributeFullName) Export
	
	TypeDescription = Metadata.FindByFullName(AttributeFullName).Type;
	
	NumericCodesOfTypes = New Map;
	CurrentCode = 0;
	
	For Each ValueType In TypeDescription.Types() Do
		If CommonUse.IsReference(ValueType) Then
			NumericCodesOfTypes.Insert(ValueType, CurrentCode);
		EndIf;
		CurrentCode = CurrentCode + 1;
	EndDo;
	
	StringCodesOfTypes = New Map;
	
	StringCodeLength = StrLen(Format(CurrentCode-1, "NZ=0;NG="));
	FormatCodeString = "ND=" + Format(StringCodeLength, "NZ=0;NG=") + "; NZ=0; NLZ=; NG=";
	
	For Each KeyAndValue In NumericCodesOfTypes Do
		StringCodesOfTypes.Insert(
			KeyAndValue.Key,
			Format(KeyAndValue.Value, FormatCodeString));
	EndDo;
	
	Return StringCodesOfTypes;
	
EndFunction

// For internal use only
Function EnumerationCodes() Export
	
	EnumerationCodes = New Map;
	
	For Each AccessValueType In Metadata.DefinedTypes.AccessValue.Type.Types() Do
		TypeMetadata = Metadata.FindByType(AccessValueType);
		If TypeMetadata = Undefined Or Not Metadata.Enums.Contains(TypeMetadata) Then
			Continue;
		EndIf;
		For Each EnumValue In TypeMetadata.EnumValues Do
			EnumValueName = EnumValue.Name;
			EnumerationCodes.Insert(Enums[TypeMetadata.Name][EnumValueName], EnumValueName);
		EndDo;
	EndDo;
	
	Return New FixedMap(EnumerationCodes);;
	
EndFunction

// For internal use only
Function AccessKindValueTypes() Export
	
	AccessKindsProperties = AccessManagementInternalCached.Parameters().AccessKindsProperties;
	
	AccessKindValueTypes = New ValueTable;
	AccessKindValueTypes.Columns.Add("AccessKind",  Metadata.DefinedTypes.AccessValue.Type);
	AccessKindValueTypes.Columns.Add("ValueType", Metadata.DefinedTypes.AccessValue.Type);
	
	For Each KeyAndValue In AccessKindsProperties.ByValueTypes Do
		Row = AccessKindValueTypes.Add();
		Row.AccessKind = KeyAndValue.Value.Ref;
		
		Types = New Array;
		Types.Add(KeyAndValue.Key);
		TypeDescription = New TypeDescription(Types);
		
		Row.ValueType = TypeDescription.AdjustValue(Undefined);
	EndDo;
	
	Return AccessKindValueTypes;
	
EndFunction

// For internal use only
Function AccessKindGroupAndValueTypes() Export
	
	AccessKindsProperties = AccessManagementInternalCached.Parameters().AccessKindsProperties;
	
	AccessKindGroupAndValueTypes = New ValueTable;
	AccessKindGroupAndValueTypes.Columns.Add("AccessKind",        Metadata.DefinedTypes.AccessValue.Type);
	AccessKindGroupAndValueTypes.Columns.Add("GroupAndValueType", Metadata.DefinedTypes.AccessValue.Type);
	
	For Each KeyAndValue In AccessKindsProperties.ByGroupTypesAndValues Do
		Row = AccessKindGroupAndValueTypes.Add();
		Row.AccessKind = KeyAndValue.Value.Ref;
		
		Types = New Array;
		Types.Add(KeyAndValue.Key);
		TypeDescription = New TypeDescription(Types);
		
		Row.GroupAndValueType = TypeDescription.AdjustValue(Undefined);
	EndDo;
	
	Return AccessKindGroupAndValueTypes;
	
EndFunction

// For internal use only
Function DescriptionOfAccessValueTypesAndRightsSettingsOwners() Export
	
	Types = New Array;
	For Each Type In Metadata.DefinedTypes.AccessValue.Type.Types() Do
		Types.Add(Type);
	EndDo;
	
	For Each Type In Metadata.DefinedTypes.RightsSettingsOwner.Type.Types() Do
		Types.Add(Type);
	EndDo;
	
	Return New TypeDescription(Types);
	
EndFunction

// For internal use only
Function ValueTypesOfAccessKindsAndRightsSettingsOwners() Export
	
	ValueTypesOfAccessKindsAndRightsSettingsOwners = New ValueTable;
	
	ValueTypesOfAccessKindsAndRightsSettingsOwners.Columns.Add("AccessKind",
		AccessManagementInternalCached.DescriptionOfAccessValueTypesAndRightsSettingsOwners());
	
	ValueTypesOfAccessKindsAndRightsSettingsOwners.Columns.Add("ValueType",
		AccessManagementInternalCached.DescriptionOfAccessValueTypesAndRightsSettingsOwners());
	
	AccessKindValueTypes = AccessManagementInternalCached.AccessKindValueTypes();
	
	For Each Row In AccessKindValueTypes Do
		FillPropertyValues(ValueTypesOfAccessKindsAndRightsSettingsOwners.Add(), Row);
	EndDo;
	
	RightOwners = AccessManagementInternalCached.Parameters(
		).AvailableRightsForObjectRightsSettings.ByRefTypes;
	
	For Each KeyAndValue In RightOwners Do
		
		Types = New Array;
		Types.Add(KeyAndValue.Key);
		TypeDescription = New TypeDescription(Types);
		
		String = ValueTypesOfAccessKindsAndRightsSettingsOwners.Add();
		Row.AccessKind  = TypeDescription.AdjustValue(Undefined);
		Row.ValueType = TypeDescription.AdjustValue(Undefined);
	EndDo;
	
	Return ValueTypesOfAccessKindsAndRightsSettingsOwners;
	
EndFunction

// For internal use only
Function RightRestrictionKindsOfMetadataObjects() Export
	
	Return New Structure("UpdateDate, Table", '00010101');
	
EndFunction

#EndRegion
