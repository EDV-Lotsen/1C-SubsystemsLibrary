////////////////////////////////////////////////////////////////////////////////
// Properties subsystem
// 
////////////////////////////////////////////////////////////////////////////////

#Region InternalInterface

// See the definition of this procedure in the StandardSubsystemsServer module.
Procedure InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers) Export
	
	// SERVER HANDLERS.
	
	ServerHandlers["StandardSubsystems.InfobaseVersionUpdate\OnAddUpdateHandlers"].Add(
		"PropertyManagementInternal");
		
	ServerHandlers["StandardSubsystems.BaseFunctionality\OnAddReferenceSearchException"].Add(
		"PropertyManagementInternal");
	
	ServerHandlers["StandardSubsystems.BaseFunctionality\OnGetMandatoryExchangePlanObjects"].Add(
		"PropertyManagementInternal");
	
	ServerHandlers["StandardSubsystems.BaseFunctionality\OnGetExchangePlanInitialImageObjects"].Add(
		"PropertyManagementInternal");
	
	If CommonUse.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ServerHandlers["StandardSubsystems.AccessManagement\OnFillMetadataObjectAccessRestrictionKinds"].Add(
			"PropertyManagementInternal");
		
		ServerHandlers["StandardSubsystems.AccessManagement\OnFillAccessKinds"].Add(
			"PropertyManagementInternal");
	EndIf;
	
EndProcedure

// Adds update handlers required by the subsystem.
//
// Parameters:
//  Handlers - ValueTable - see the definition of NewUpdateHadlerTable() function of the InfobaseUpdate common module.
// 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.SharedData = True;
	Handler.HandlerManagement = True;
	Handler.Version = "*";
	Handler.ExecutionMode = "Nonexclusive";
	Handler.Procedure = "PropertyManagementInternal.FillSeparatedDataHandlers";
	
	Handler = Handlers.Add();
	Handler.Version = "*";
	Handler.ExecutionMode = "Nonexclusive";
	Handler.Procedure = "PropertyManagement.RefreshPropertyAndSetDescriptions";
	
    //PARTIALLY_DELETED
	//Handler = Handlers.Add();
	//Handler.Version = "1.0.6.7";
	//Handler.Procedure = "PropertyManagementInternal.UpdateAdditionalPropertiesList_1_0_6";
	
	//Handler = Handlers.Add();
	//Handler.ExecuteInMandatoryGroup = True;
	//Handler.Version = "2.1.5.3";
	//Handler.Priority = 1;
	//Handler.Procedure = "PropertyManagementInternal.FillNewData_2_1_5";
	
	//Handler = Handlers.Add();
	//Handler.Version = "2.1.5.18";
	//Handler.ExecutionMode = "Deferred";
	//Handler.Comment = NStr("en = 'Additional attributes and data restructuring'");
	//Handler.Procedure = "PropertyManagementInternal.UpdateAllSetGroupPropertyContent";
	
EndProcedure

// Returns the list of all metadata object properties.
//
// Parameters:
//  ObjectKind - String - metadata object's full name;
//  PropertyKind  - String - "AdditionalAttributes" or "AdditionalData".
//
// Returns:
//  ValueTable - Property, Description, ValueType.
//  Undefined - The provided object kind has no property set.
//
Function ObjectPropertyList(ObjectKind, Val PropertyKind) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	PropertySets.Ref AS Ref,
	|	PropertySets.PredefinedDataName AS PredefinedDataName
	|FROM
	|	Catalog.AdditionalDataAndAttributeSets AS PropertySets
	|WHERE
	|	PropertySets.Predefined";
	Selection = Query.Execute().Select();
	
	PredefinedDataName = StrReplace(ObjectKind, ".", "_");
	SetRef = Undefined;
	
	While Selection.Next() Do
		If Selection.PredefinedDataName = PredefinedDataName Then
			SetRef = Selection.Ref;
			Break;
		EndIf;
	EndDo;
	
	If SetRef = Undefined Then
		Return Undefined;
	EndIf;
	
	QueryText = 
	"SELECT
	|	PropertyTable.Property AS Property,
	|	PropertyTable.Property.Description AS Description,
	|	PropertyTable.Property.ValueType AS ValueType
	|FROM
	|	&PropertyTable AS PropertyTable
	|WHERE
	|	PropertyTable.Ref IN HIERARCHY(&Ref)";
	
	FullTableName = "Catalog.AdditionalDataAndAttributeSets." + PropertyKind;
	QueryText = StrReplace(QueryText, "PropertyTable", FullTableName);
	
	Query = New Query(QueryText);
	Query.SetParameter("Ref", SetRef);
	
	Result = Query.Execute().Unload();
	Result.GroupBy("Property,Description,ValueType");
	Result.Sort("Description Asc");
	
	Return Result;
	
EndFunction

#EndRegion

#Region InternalProceduresAndFunctions

// Returns the table of property sets of the owner.
//
// Parameters:
//  PropertyOwner - Reference to the owner of properties.
//                  Property owner object.
//                  FormStructureData (by type of the property owner object).
//  PurposeUseKey - use specified destination key  
//                  to add PurposeUseKey to property value form.
//
Function GetObjectPropertySets(Val PropertyOwner, PurposeUseKey = Undefined) Export
	
	If TypeOf(PropertyOwner) = Type("FormDataStructure") Then
		RefType = TypeOf(PropertyOwner.Ref)
		
	ElsIf CommonUse.IsReference(TypeOf(PropertyOwner)) Then
		RefType = TypeOf(PropertyOwner);
	Else
		RefType = TypeOf(PropertyOwner.Ref)
	EndIf;
	
	GetDefaultSet = True;
	
	PropertySets = New ValueTable;
	PropertySets.Columns.Add("Set");
	PropertySets.Columns.Add("Height");
	PropertySets.Columns.Add("Title");
	PropertySets.Columns.Add("ToolTip");
	PropertySets.Columns.Add("VerticalStretch");
	PropertySets.Columns.Add("HorizontalStretch");
	PropertySets.Columns.Add("ReadOnly");
	PropertySets.Columns.Add("TitleTextColor");
	PropertySets.Columns.Add("Width");
	PropertySets.Columns.Add("TitleFont");
	PropertySets.Columns.Add("Grouping");
	PropertySets.Columns.Add("Representation");
	PropertySets.Columns.Add("ChildItemsWidth");
	PropertySets.Columns.Add("Picture");
	PropertySets.Columns.Add("ShowTitle");
	
	PropertyManagementOverridable.FillObjectPropertySets(
		PropertyOwner, RefType, PropertySets, GetDefaultSet, PurposeUseKey);
	
	If PropertySets.Count() = 0
	   And GetDefaultSet = True Then
		
		DefaultSet = GetDefaultObjectPropertySet(PropertyOwner);
		
		If ValueIsFilled(DefaultSet) Then
			PropertySets.Add().Set = DefaultSet;
		EndIf;
	EndIf;
	
	Return PropertySets;
	
EndFunction

// Returns the filled table of object property values.
Function GetPropertyValueTable(ObjectAdditionalProperties, Sets, IsAdditionalData) Export
	
	If ObjectAdditionalProperties.Count() = 0 Then
		// Preprocessing fast check of additional properties usage.
		Query = New Query;
		Query.SetParameter("PropertySets", Sets.UnloadValues());
		Query.Text =
		"SELECT TOP 1
		|	TRUE AS TrueValue
		|FROM
		|	Catalog.AdditionalDataAndAttributeSets.AdditionalAttributes AS SetProperties
		|WHERE
		|	SetProperties.Ref IN(&PropertySets)
		|	AND NOT SetProperties.DeletionMark";
		
		If IsAdditionalData Then
			Query.Text = StrReplace(
				Query.Text,
				"Catalog.AdditionalDataAndAttributeSets.AdditionalAttributes",
				"Catalog.AdditionalDataAndAttributeSets.AdditionalData");
		EndIf;
		
		SetPrivilegedMode(True);
		PropertiesNotFound = Query.Execute().IsEmpty();
		SetPrivilegedMode(False);
		If PropertiesNotFound Then
			PropertyDetailTable = New ValueTable;
			PropertyDetailTable.Columns.Add("Set");
			PropertyDetailTable.Columns.Add("Property");
			PropertyDetailTable.Columns.Add("AdditionalValueOwner");
			PropertyDetailTable.Columns.Add("RequiredToFill");
			PropertyDetailTable.Columns.Add("Description");
			PropertyDetailTable.Columns.Add("ValueType");
			PropertyDetailTable.Columns.Add("FormatProperties");
			PropertyDetailTable.Columns.Add("MultilineInputField");
			PropertyDetailTable.Columns.Add("Deleted");
			PropertyDetailTable.Columns.Add("Value");
			Return PropertyDetailTable;
		EndIf;
	EndIf;
	
	Properties = ObjectAdditionalProperties.UnloadColumn("Property");
	
	PropertySets = New ValueTable;
	
	PropertySets.Columns.Add(
		"Set", New TypeDescription("CatalogRef.AdditionalDataAndAttributeSets"));
	
	PropertySets.Columns.Add(
		"SetOrder", New TypeDescription("Number"));
	
	For Each ListItem In Sets Do
		NewRow = PropertySets.Add();
		NewRow.Set = ListItem.Value;
		NewRow.SetOrder = Sets.IndexOf(ListItem);
	EndDo;
	
	Query = New Query;
	Query.SetParameter("Properties", Properties);
	Query.SetParameter("PropertySets", PropertySets);
	Query.Text =
	"SELECT
	|	PropertySets.Set,
	|	PropertySets.SetOrder
	|INTO PropertySets
	|FROM
	|	&PropertySets AS PropertySets
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	PropertySets.Set,
	|	PropertySets.SetOrder,
	|	SetProperties.Property,
	|	SetProperties.DeletionMark,
	|	SetProperties.LineNumber AS PropertyOrder
	|INTO SetProperties
	|FROM
	|	PropertySets AS PropertySets
	|		INNER JOIN Catalog.AdditionalDataAndAttributeSets.AdditionalAttributes AS SetProperties
	|		ON (SetProperties.Ref = PropertySets.Set)
	|		INNER JOIN ChartOfCharacteristicTypes.AdditionalDataAndAttributes AS Properties
	|		ON (SetProperties.Property = Properties.Ref)
	|WHERE
	|	NOT SetProperties.DeletionMark
	|	AND NOT Properties.DeletionMark
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	Properties.Ref AS Property
	|INTO CompletedProperties
	|FROM
	|	ChartOfCharacteristicTypes.AdditionalDataAndAttributes AS Properties
	|WHERE
	|	Properties.Ref IN(&Properties)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SetProperties.Set,
	|	SetProperties.SetOrder,
	|	SetProperties.Property,
	|	SetProperties.PropertyOrder,
	|	SetProperties.DeletionMark AS Deleted
	|INTO AllProperties
	|FROM
	|	SetProperties AS SetProperties
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(Catalog.AdditionalDataAndAttributeSets.EmptyRef),
	|	0,
	|	CompletedProperties.Property,
	|	0,
	|	TRUE
	|FROM
	|	CompletedProperties AS CompletedProperties
	|		LEFT JOIN SetProperties AS SetProperties
	|		ON CompletedProperties.Property = SetProperties.Property
	|WHERE
	|	SetProperties.Property IS NULL 
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	AllProperties.Set,
	|	AllProperties.Property,
	|	AdditionalDataAndAttributes.AdditionalValueOwner,
	|	AdditionalDataAndAttributes.RequiredToFill,
	|	AdditionalDataAndAttributes.Title AS Description,
	|	AdditionalDataAndAttributes.ValueType,
	|	AdditionalDataAndAttributes.FormatProperties,
	|	AdditionalDataAndAttributes.MultilineInputField,
	|	AllProperties.Deleted AS Deleted
	|FROM
	|	AllProperties AS AllProperties
	|		INNER JOIN ChartOfCharacteristicTypes.AdditionalDataAndAttributes AS AdditionalDataAndAttributes
	|		ON AllProperties.Property = AdditionalDataAndAttributes.Ref
	|
	|ORDER BY
	|	Deleted,
	|	AllProperties.SetOrder,
	|	AllProperties.PropertyOrder";
	
	If IsAdditionalData Then
		Query.Text = StrReplace(
			Query.Text,
			"Catalog.AdditionalDataAndAttributeSets.AdditionalAttributes",
			"Catalog.AdditionalDataAndAttributeSets.AdditionalData");
	EndIf;
	
	PropertyDetailTable = Query.Execute().Unload();
	PropertyDetailTable.Indexes.Add("Property");
	PropertyDetailTable.Columns.Add("Value");
	
	// Deleting duplicates of properties in the following property sets.
	Index = PropertyDetailTable.Count()-1;
	
	While Index >= 0 Do
		Row = PropertyDetailTable[Index];
		FoundRow = PropertyDetailTable.Find(Row.Property);
		
		If FoundRow <> Undefined
		   And FoundRow <> Row Then
			
			PropertyDetailTable.Delete(Index);
		EndIf;
		
		Index = Index-1;
	EndDo;
	
	// Property value filling.
	For Each Row In ObjectAdditionalProperties Do
		PropertyDetails = PropertyDetailTable.Find(Row.Property, "Property");
		If PropertyDetails <> Undefined Then
			// Supporting strings of unlimited length.
			If Not IsAdditionalData
			   And UseUnlimitedString(
			         PropertyDetails.ValueType, PropertyDetails.MultilineInputField)
			   And Not IsBlankString(Row.TextString) Then 
				
				PropertyDetails.Value = Row.TextString;
			Else
				PropertyDetails.Value = Row.Value;
			EndIf;
		EndIf;
	EndDo;
	
	Return PropertyDetailTable;
	
EndFunction

// Returns additional data values.
Function ReadPropertyValuesInInformationRegister(PropertyOwner) Export
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	AdditionalData.Property,
	|	AdditionalData.Value
	|FROM
	|	InformationRegister.AdditionalData AS AdditionalData
	|WHERE
	|	AdditionalData.Object = &Object";
	Query.SetParameter("Object", PropertyOwner);
	
	Return Query.Execute().Unload();
	
EndFunction

// Returns the metadata object that is the owner of property values of additional 
// attributes and data.
// 
Function PropertySetValueOwnerMetadata(Ref, ConsiderDeletionMark = True, RefType = Undefined) Export
	
	If Not ValueIsFilled(Ref) Then
		Return Undefined;
	EndIf;
	
	RefProperties = CommonUse.ObjectAttributeValues(
		Ref, "DeletionMark, IsFolder, Predefined, Parent");
	
	If ConsiderDeletionMark And RefProperties.DeletionMark Then
		Return Undefined;
	EndIf;
	
	If RefProperties.IsFolder Then
		PredefinedRef = Ref;
		
	ElsIf RefProperties.Predefined
	      And RefProperties.Parent = Catalogs.AdditionalDataAndAttributeSets.EmptyRef() Then
		
		PredefinedRef = Ref;
	Else
		PredefinedRef = Ref.Parent;
	EndIf;
	
	PredefinedName = CommonUse.PredefinedName(PredefinedRef);
	
	Position = Find(PredefinedName, "_");
	
	FirstNamePart = Left(PredefinedName, Position - 1);
	SecondNamePart = Right(PredefinedName, StrLen(PredefinedName) - Position);
	
	OwnerMetadata = Metadata.FindByFullName(FirstNamePart + "." + SecondNamePart);
	
	If OwnerMetadata <> Undefined Then
		RefType = Type(FirstNamePart + "Ref." + SecondNamePart);
	EndIf;
	
	Return OwnerMetadata;
	
EndFunction

// Returns the usage of additional attributes and data set.
Function SetPropertyTypes(Ref, ConsiderDeletionMark = True) Export
	
	SetPropertyTypes = New Structure;
	SetPropertyTypes.Insert("AdditionalAttributes", False);
	SetPropertyTypes.Insert("AdditionalData",  False);
	
	RefType = Undefined;
	OwnerMetadata = PropertySetValueOwnerMetadata(Ref, ConsiderDeletionMark, RefType);
	
	If OwnerMetadata = Undefined Then
		Return SetPropertyTypes;
	EndIf;
	
	// Checking the usage of additional attributes.
	SetPropertyTypes.Insert(
		"AdditionalAttributes",
		OwnerMetadata <> Undefined
		And OwnerMetadata.TabularSections.Find("AdditionalAttributes") <> Undefined );
	
	// Checking the usage of additional data.
	SetPropertyTypes.Insert(
		"AdditionalData",
		      Metadata.CommonCommands.Find("AdditionalDataCommandBar") <> Undefined
		    And Metadata.CommonCommands.AdditionalDataCommandBar.CommandParameterType.ContainsType(RefType)
		Or   Metadata.CommonCommands.Find("AdditionalDataNavigationPanel") <> Undefined
		    And Metadata.CommonCommands.AdditionalDataNavigationPanel.CommandParameterType.ContainsType(RefType) );
	
	Return SetPropertyTypes;
	
EndFunction

// Defines, if the value type includes the type of additional values properties.
Function ValueTypeContainsPropertyValues(ValueType) Export
	
	Return ValueType.ContainsType(Type("CatalogRef.ObjectPropertyValues"))
	    Or ValueType.ContainsType(Type("CatalogRef.ObjectPropertyValueHierarchy"));
	
EndFunction

// Checks the possibility of usage of unlimited length string for the property.
Function UseUnlimitedString(ValueTypeProperties, MultilineInputField) Export
	
	If ValueTypeProperties.ContainsType(Type("String"))
	   And ValueTypeProperties.Types().Count() = 1
	   And MultilineInputField > 1 Then
		Return True;
	Else
		Return False;
	EndIf;
	
EndFunction

// Checks that there are objects using the property.
// 
// Parameters:
//  Property - ChartOfCharacteristicTypesRef.AdditionalDataAndAttributes
// 
// Returns:
//  Boolean. True, if at least one object is found.
//
Function AdditionalPropertyUsed(Property) Export
	
	Query = New Query;
	Query.SetParameter("Property", Property);
	Query.Text =
	"SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	InformationRegister.AdditionalData AS AdditionalData
	|WHERE
	|	AdditionalData.Property = &Property";
	
	If Not Query.Execute().IsEmpty() Then
		Return True;
	EndIf;
	
	MetadataObjectKinds = New Array;
	MetadataObjectKinds.Add("ExchangePlans");
	MetadataObjectKinds.Add("Catalogs");
	MetadataObjectKinds.Add("Documents");
	MetadataObjectKinds.Add("ChartsOfCharacteristicTypes");
	MetadataObjectKinds.Add("ChartsOfAccounts");
	MetadataObjectKinds.Add("ChartsOfCalculationTypes");
	MetadataObjectKinds.Add("BusinessProcesses");
	MetadataObjectKinds.Add("Tasks");
	
	ObjectTables = New Array;
	For Each MetadataObjectKind In MetadataObjectKinds Do
		For Each MetadataObject In Metadata[MetadataObjectKind] Do
			
			If IsMetadataObjectWithAdditionalAttributes(MetadataObject) Then
				ObjectTables.Add(MetadataObject.FullName());
			EndIf;
			
		EndDo;
	EndDo;
	
	QueryText =
	"SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	TableName AS CurrentTable
	|WHERE
	|	CurrentTable.Property = &Property";
	
	For Each Table In ObjectTables Do
		Query.Text = StrReplace(QueryText, "TableName", Table + ".AdditionalAttributes");
		If Not Query.Execute().IsEmpty() Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

// Checks if the metadata object is using additional attributes.
// The check is made for the references integrity, so the embedding check is skipped.
//
Function IsMetadataObjectWithAdditionalAttributes(MetadataObject) Export
	
	If MetadataObject = Metadata.Catalogs.AdditionalDataAndAttributeSets Then
		Return False;
	EndIf;
	
	TabularSection = MetadataObject.TabularSections.Find("AdditionalAttributes");
	If TabularSection = Undefined Then
		Return False;
	EndIf;
	
	Attribute = TabularSection.Attributes.Find("Property");
	If Attribute = Undefined Then
		Return False;
	EndIf;
	
	If Not Attribute.Type.ContainsType(Type("ChartOfCharacteristicTypesRef.AdditionalDataAndAttributes")) Then
		Return False;
	EndIf;
	
	Attribute = TabularSection.Attributes.Find("Value");
	If Attribute = Undefined Then
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

// Returns the name of the predefined set that is got from the metadata object 
// found by predefined set name.
// 
// Parameters:
//  Set - CatalogRef.AdditionalDataAndAttributeSets,
//      - String - full name of the predefined element.
//
Function PredefinedSetDescription(Set) Export
	
	If TypeOf(Set) = Type("String") Then
		PredefinedName = Set;
	Else
		PredefinedName = CommonUse.PredefinedName(Set);
	EndIf;
	
	Position = Find(PredefinedName, "_");
	FirstNamePart = Left(PredefinedName, Position - 1);
	SecondNamePart = Right(PredefinedName, StrLen(PredefinedName) - Position);
	
	FullName = FirstNamePart + "." + SecondNamePart;
	
	MetadataObject = Metadata.FindByFullName(FullName);
	If MetadataObject = Undefined Then
		If TypeOf(Set) = Type("String") Then
			Return "";
		Else
			Return CommonUse.ObjectAttributeValue(Set, "Description");
		EndIf;
	EndIf;
	
	If ValueIsFilled(MetadataObject.ObjectPresentation) Then
		Description = MetadataObject.ObjectPresentation;
		
	ElsIf ValueIsFilled(MetadataObject.Synonym) Then
		Description = MetadataObject.Synonym;
	Else
		If TypeOf(Set) = Type("String") Then
			Description = "";
		Else
			Description = CommonUse.ObjectAttributeValue(Set, "Description");
		EndIf;
	EndIf;
	
	Return Description;
	
EndFunction

// Updates the content of the top group to use during the customisation
// of the dynamic list fields content and its settings (filters, ...).
//
// Parameters:
//  Group        - CatalogRef.AdditionalDataAndAttributeSets, with IsGroup = True.
//
Procedure CheckRefreshGroupPropertyContent(Group) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.SetParameter("Group", Group);
	Query.Text =
	"SELECT DISTINCT
	|	AdditionalAttributes.Property AS Property
	|FROM
	|	Catalog.AdditionalDataAndAttributeSets.AdditionalAttributes AS AdditionalAttributes
	|WHERE
	|	AdditionalAttributes.Ref.Parent = &Group
	|
	|ORDER BY
	|	Property
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	AdditionalData.Property AS Property
	|FROM
	|	Catalog.AdditionalDataAndAttributeSets.AdditionalData AS AdditionalData
	|WHERE
	|	AdditionalData.Ref.Parent = &Group
	|
	|ORDER BY
	|	Property";
	
	QueryResult = Query.ExecuteBatch();
	GroupAdditionalAttributes = QueryResult[0].Unload();
	GroupAdditionalData  = QueryResult[1].Unload();
	
	ObjectGroup = Group.GetObject();
	
	Refresh = False;
	
	If ObjectGroup.AdditionalAttributes.Count() <> GroupAdditionalAttributes.Count() Then
		Refresh = True;
	EndIf;
	
	If ObjectGroup.AdditionalData.Count() <> GroupAdditionalData.Count() Then
		Refresh = True;
	EndIf;
	
	If Not Refresh Then
		Index = 0;
		For Each Row In ObjectGroup.AdditionalAttributes Do
			If Row.Property <> GroupAdditionalAttributes[Index].Property Then
				Refresh = True;
			EndIf;
			Index = Index + 1;
		EndDo;
	EndIf;
	
	If Not Refresh Then
		Index = 0;
		For Each Row In ObjectGroup.AdditionalData Do
			If Row.Property <> GroupAdditionalData[Index].Property Then
				Refresh = True;
			EndIf;
			Index = Index + 1;
		EndDo;
		Return;
	EndIf;
	
	ObjectGroup.AdditionalAttributes.Load(GroupAdditionalAttributes);
	ObjectGroup.AdditionalData.Load(GroupAdditionalData);
	ObjectGroup.Write();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// SL event handlers

// Fills the array with the list of metadata object names that might include
// references to different metadata objects with these references ignored
// in the business-specific application logic.
//
// Parameters:
//  Array       - Array of String, for example, "InformationRegister.ObjectVersions".
//
Procedure OnAddReferenceSearchException(Array) Export
	
	Array.Add("InformationRegister.AdditionalData");
	Array.Add("Catalog.AdditionalDataAndAttributeSets");
	
EndProcedure

// Fills the content of access kinds used in metadata objects rights limitation.
// If the access kinds content is not filled, the Access rights report will show 
// incorrect data.
//
// Only the access kinds, evidently used in the access limitation patterns, are to be filled, 
// while the access kinds, used in access values sets may be got from the current state 
// of the AccessValueSets information register.
//
// To prepare the procedure content automatically the developer tools for the Access Management 
// subsystem are to be used.
//
// Parameters:
//  Details     - String, multi-line row of <Table>.<Right>.<AccessKind>[.Object table] format.
//                 For example, Document.ReceivingReport.Read.Companies 
//                           Document.ReceivingReport.Read.Counterparties 
//                           Document.ReceivingReport.Update.Companies 
//                           Document.ReceivingReport.Update.Counterparties 
//                           Document.EmailMessages.Read.Object.Document.EmailMassages 
//                           Document.EmailMessages.Update.Object.Document.EmailMassages 
//                           Document.Files.Read.Object.Catalog.FileFolders 
//                           Document.Files.Read.Object.Document.EmailMassage 
//                           Document.Files.Update.Object.Catalog.FileFolders
//                           Document.Files.Update.Object.Document.EmailMessage 
//                 Access kind Object is predefined as a literal. This access kind is used 
//                 in access limitation patterns as a reference to another object, restricting
//                 the current object of the table.
//                 When the Object access kind is assigned, it is also needed to assign 
//                 types of tables used for this access kind. This means list the types, 
//                 corresponding to the field used in the access limits pattern together 
//                 with the Object access kind. While listing of types according the 
//                 Object access kind only types that are used in 
//                 InformationRegisters.AccessValueSets.Object field, the other types 
//                 are unnecessary.
// 
Procedure OnFillMetadataObjectAccessRestrictionKinds(Details) Export
	
	If Not CommonUse.SubsystemExists("StandardSubsystems.AccessManagement") Then
		Return;
	EndIf;
	
	AccessManagementInternalModule = CommonUse.CommonModule("AccessManagementInternal");
	
	If AccessManagementInternalModule.AccessKindExists("AdditionalData") Then
		
		Details = Details + 
		"
		|Catalog.ObjectPropertyValues.Read.AdditionalData
		|Catalog.ObjectPropertyValueHierarchy.Read.AdditionalData
		|ChartOfCharacteristicTypes.AdditionalDataAndAttributes.Read.AdditionalData
		|InformationRegister.AdditionalData.Read.AdditionalData
		|InformationRegister.AdditionalData.Update.AdditionalData
		|";
	EndIf;
	
EndProcedure

// Fills access kinds, used in access restrictions.
// Users and ExternalUsers access kinds are already filled.
// They can be deleted if they are not used in access restrictions.
//
// Parameters:
//  AccessKinds - ValueTable with the following fields:
//  - Name                - String - A name used in description of access groups 
//                          supplied profiles and ODD texts.
//  - Presentation        - String - introduces an access kind in profiles and access groups.
//  - ValueType           - Type - Access values reference type.       
//                          For example, Type("CatalogRef.ProductsAndServices").
//  - ValueGroupType      - Type - Reference type of access values' groups. 
//                          For example, Type("CatalogRef.ProductsAndServicesAccessGroups").
//  - MultipleValueGroups - Boolean - If True selecting several value groups (Items access
//                          groups) is available for a single access value (Items).
//
Procedure OnFillAccessKinds(AccessKinds) Export
	
	AccessKind = AccessKinds.Add();
	AccessKind.Name = "AdditionalData";
	AccessKind.Presentation = NStr("en = 'Custom data'");
	AccessKind.ValueType   = Type("ChartOfCharacteristicTypesRef.AdditionalDataAndAttributes");
	
EndProcedure

// The procedure is used when getting metadata objects that must not be included in the exchange plan content.
// If there are objects in the subsystem, mandatory to be included in the exchange plan
// content, add these metadata objects to the Objects parameter.
//
// Parameters:
// Objects - Array. The array of the configuration's metadata objects needed to be included 
//         in the exchange plan content.
// DistributedInfobase (read only) - Boolean. Attribute of getting objects for a DIB 
//         exchange plan.
//         True - list for a DIB is required;
//         False - list for an infobase that is not a DIB is required.
//
Procedure OnGetMandatoryExchangePlanObjects(Objects, Val DistributedInfobase) Export
	
	If DistributedInfobase Then
		Objects.Add(Metadata.Constants.AdditionalDataAndAttributeParameters);
	EndIf;
	
EndProcedure

// Is used for retrieving metadata objects to be included in the exchange plan content 
// but NOT included in the change record event subscription content of this exchange plan.
// These metadata objects are used only when creating initial image of a subordinate node 
// and do not migrate when exchanging.
// If there are objects in the subsystem, used only for creating initial image of a 
// subordinate node, add these metadata objects to the Objects parameter.
//
// Parameters:
// Objects - Array. Configuration metadata objects' array.
//
Procedure OnGetExchangePlanInitialImageObjects(Objects) Export
	
	Objects.Add(Metadata.Constants.AdditionalDataAndAttributeParameters);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions

// Returns the default set of owner properties.
//
// Parameters:
//  PropertyOwner - Ref or Object of properties owner.
//
// Returns:
//  CatalogRef.AdditionalDataAndAttributeSets -
//   when the attribute name of the object type for the properties owner type is 
//        not assigned in OverridablePropertyManagement.GetObjectTypeAttributeName(), 
//   then returns a predefined element having a name in the format the metadata object 
//        full name with "." symbol is replaced with "_", 
//   otherwise the value of the PropertySet attribute included in the attribute of 
//        properties owner with the name assigned in the predefined procedure is returned.
//
//  Undefined - when properties owner is a group of catalog items or a group of items 
//              of type of characteristic types.
//  
Function GetDefaultObjectPropertySet(PropertyOwner)
	
	ObjectTransferred = False;
	If CommonUse.ReferenceTypeValue(PropertyOwner) Then
		Ref = PropertyOwner;
	Else
		ObjectTransferred = True;
		Ref = PropertyOwner.Ref;
	EndIf;
	
	ObjectMetadata = Ref.Metadata();
	MetadataObjectName = ObjectMetadata.Name;
	
	MetadataObjectKind = CommonUse.ObjectKindByRef(Ref);
	PropertyOwnerTypeAttributeName = PropertyManagementOverridable.GetObjectTypeAttributeName(Ref);
	
	If PropertyOwnerTypeAttributeName = "" Then
		If MetadataObjectKind = "Catalog" or MetadataObjectKind = "ChartOfCharacteristicTypes" Then
			If CommonUse.ObjectIsFolder(PropertyOwner) Then
				Return Undefined;
			EndIf;
		EndIf;
		ItemName = MetadataObjectKind + "_" + MetadataObjectName;
		Return Catalogs.AdditionalDataAndAttributeSets[ItemName];
	Else
		If ObjectTransferred = True Then
			
			Return CommonUse.ObjectAttributeValue(
				PropertyOwner[PropertyOwnerTypeAttributeName], "PropertySet");
		Else
			Query = New Query;
			Query.Text =
			"SELECT
			|	ObjectPropertyOwner." + PropertyOwnerTypeAttributeName + ".PropertySet AS Set 
			|FROM
			|" + MetadataObjectKind + "." + MetadataObjectName + " AS PropertyOwnerObject 
			|WHERE
			|	PropertyOwnerObject.Ref = &Ref";
			
			Query.SetParameter("Ref", Ref);
			Result = Query.Execute();
			
			If NOT Result.IsEmpty() Then
				
				Selection = Result.Select();
				Selection.Next();
				
				If ValueIsFilled(Selection.Set) Then
					Return Selection.Set;
				Else
					Return Catalogs.AdditionalDataAndAttributeSets.EmptyRef();
				EndIf;
			Else
				Return Catalogs.AdditionalDataAndAttributeSets.EmptyRef();
			EndIf;
		EndIf;
	EndIf;
	
EndFunction

// The procedure is used during infobase update.
Function HasMetadataObjectWithPropertiesPresentationChanges()
	
	SetPrivilegedMode(True);
	
	Catalogs.AdditionalDataAndAttributeSets
     .RefreshPredefinedSetDescriptionContents();
	
	Parameters = StandardSubsystemsServer.ApplicationParameters(
		"AdditionalDataAndAttributeParameters");
	
	LastChanges = StandardSubsystemsServer.ApplicationParameterChanges(
		Parameters, "AdditionalDataAndAttributePredefinedSets");
		
	If LastChanges = Undefined
	 Or LastChanges.Count() > 0 Then
		
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Infobase update

// Fills the separated data handler, dependent on the change in unseparated data.
//
// Parameters:
//   Handlers - ValueTable, Undefined - see details on the NewUpdateHandlerTable() 
//    function of the InfobaseUpdate common module.
//    In case of a direct call(beside the procedure of the infobase version updating) 
//    is passed as Undefined.
// 
Procedure FillSeparatedDataHandlers(Parameters = Undefined) Export
	
	If Parameters <> Undefined And HasMetadataObjectWithPropertiesPresentationChanges() Then
		Handlers = Parameters.SeparatedHandlers;
		Handler = Handlers.Add();
		Handler.Version = "*";
		Handler.ExecutionMode = "RealTime";
		Handler.Procedure = "PropertyManagement.RefreshPropertyAndSetDescriptions";
	EndIf;
	
EndProcedure

// Updates additional attribute and data sets in the infobase.
// Is used to choose a new storage format.
//
Procedure UpdateAdditionalPropertyList_1_0_6() Export
	
	AdditionalDataAndAttributeSets = Catalogs.AdditionalDataAndAttributeSets.Select();
	
	While AdditionalDataAndAttributeSets.Next() Do
		
		AdditionalData = New Array;
		
		PropertySetObject = AdditionalDataAndAttributeSets.Ref.GetObject();
		
		For Each Write In PropertySetObject.AdditionalAttributes Do
			If Write.Property.IsAdditionalData Then
				AdditionalData.Add(Write);
			EndIf;
		EndDo;
		
		If AdditionalData.Count() > 0 Then
			
			For Each AddData In AdditionalData Do
				NewRow = PropertySetObject.AdditionalData.Add();
				NewRow.Property = AddData.Property;
				PropertySetObject.AdditionalAttributes.Delete(
					PropertySetObject.AdditionalAttributes.IndexOf(AddData));
				
			EndDo;
			InfobaseUpdate.WriteData(PropertySetObject);
		EndIf;
		
	EndDo;
	
EndProcedure

// 1. Fills new data:
// Catalog.AdditionalDataAndAttributeSets
// - AttributeNumber
// - MetadataObject
// – DataNumber
// ChartOfCharacteristicTypes.AdditionalDataAndAttributes
// - Title
// - PropertySet
// - AdditionalValuesUsed
// - AdditionalValuesWithWeight
// - ValueFormTitle
// - ValueChoiceFormTitle
// Constant.UseCommonAdditionalDataAndAttributes
// Constant.UseCommonAdditionalValues
//
// 2. Updates existing data:
// Catalog.AdditionalDataAndAttributeSets
// - Description
// - AdditionalAttributes (clears if embedding is changed)
// - AdditionalData (clears if embedding is changed)
// ChartOfCharacteristicTypes.AdditionalDataAndAttributes
// - Description
// 
Procedure FillNewData_2_1_5() Export
	
	PropertyQuery = New Query;
	PropertyQuery.Text =
	"SELECT
	|	Properties.Ref AS Ref
	|FROM
	|	ChartOfCharacteristicTypes.AdditionalDataAndAttributes AS Properties
	|WHERE
	|	Properties.Description <> """"
	|	AND Properties.Title = """"";
	
	PropertySelection = PropertyQuery.Execute().Select();
	
	If PropertySelection.Count() = 0 Then
		Return;
	EndIf;
	
	SetQuery = New Query;
	SetQuery.Text =
	"SELECT
	|	Sets.Ref AS Ref,
	|	Sets.IsFolder AS IsFolder,
	|	Sets.Description AS Description,
	|	Sets.AttributeNumber,
	|	Sets.DataNumber,
	|	Sets.AdditionalAttributes.(
	|		DeletionMark
	|	),
	|	Sets.AdditionalData.(
	|		DeletionMark
	|	)
	|FROM
	|	Catalog.AdditionalDataAndAttributeSets AS Sets";
	
	SelectionSets = SetQuery.Execute().Select();
	While SelectionSets.Next() Do
		
		Description = PredefinedSetDescription(SelectionSets.Ref);
		
		// Calculating number of properties not marked for deletion.
		SetPropertyTypes = SetPropertyTypes(SelectionSets.Ref);
		
		AdditionalAttributes = SelectionSets.AdditionalAttributes.Unload();
		If SetPropertyTypes.AdditionalAttributes Then
			AttributeNumber = AdditionalAttributes.Count();
			AttributeNumberString = Format(AdditionalAttributes.FindRows(
				New Structure("DeletionMark", False)).Count(), "NG=");
		Else
			AttributeNumber = 0;
			AttributeNumberString = "";
		EndIf;
		
		AdditionalData = SelectionSets.AdditionalData.Unload();
		If SetPropertyTypes.AdditionalData Then
			DataNumber = AdditionalData.Count();
			DataNumberString = Format(AdditionalData.FindRows(
				New Structure("DeletionMark", False)).Count(), "NG=");
		Else
			DataNumber = 0;
			DataNumberString = "";
		EndIf;
		
		If SelectionSets.Description <> Description
		 Or Not SelectionSets.IsFolder
		   And ( AdditionalAttributes.Count() <> AttributeNumber
		      Or AdditionalData.Count() <> DataNumber
		      Or SelectionSets.AttributeNumber <> AttributeNumberString
		      Or SelectionSets.DataNumber <> DataNumberString ) Then
			
			Object = SelectionSets.Ref.GetObject();
			Object.Description = Description;
			If Not SelectionSets.IsFolder Then
				Object.AttributeNumber = AttributeNumberString;
				Object.DataNumber = DataNumberString;
				If Not SetPropertyTypes.AdditionalAttributes Then
					Object.AdditionalAttributes.Clear();
				EndIf;
				If Not SetPropertyTypes.AdditionalData Then
					Object.AdditionalData.Clear();
				EndIf;
			EndIf;
			InfobaseUpdate.WriteData(Object);
		EndIf;
	EndDo;
	
	UniquenessCheckQuery = New Query;
	UniquenessCheckQuery.Text =
	"SELECT TOP 2
	|	Sets.Ref AS Ref,
	|	FALSE AS IsAdditionalData
	|FROM
	|	Catalog.AdditionalDataAndAttributeSets.AdditionalAttributes AS Sets
	|WHERE
	|	Sets.Property = &Property
	|	AND Sets.Ref.IsFolder = FALSE
	|
	|UNION ALL
	|
	|SELECT TOP 2
	|	Sets.Ref,
	|	TRUE
	|FROM
	|	Catalog.AdditionalDataAndAttributeSets.AdditionalData AS Sets
	|WHERE
	|	Sets.Property = &Property
	|	AND Sets.Ref.IsFolder = FALSE";
	
	WeightCheckQuery = New Query;
	WeightCheckQuery.Text =
	"SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	Catalog.ObjectPropertyValues AS Values
	|WHERE
	|	Values.Owner = &Property
	|	AND NOT Values.IsFolder
	|	AND Values.Weight <> 0
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	TRUE
	|FROM
	|	Catalog.ObjectPropertyValueHierarchy AS Values
	|WHERE
	|	Values.Owner = &Property
	|	AND Values.Weight <> 0";
	
	While PropertySelection.Next() Do
		
		Object = PropertySelection.Ref.GetObject();
		UniquenessCheckQuery.SetParameter("Property", PropertySelection.Ref);
		Data = UniquenessCheckQuery.Execute().Unload();
		
		If Data.Count() = 1
		   And Data[0].IsAdditionalData = Object.IsAdditionalData Then
			
			Object.PropertySet =  Data[0].Ref;
		EndIf;
		
		Object.Title = Object.Description;
		If ValueIsFilled(Object.PropertySet) Then
			Object.Description = Object.Title + " (" + String(Object.PropertySet) + ")";
		EndIf;
		
		If ValueTypeContainsPropertyValues(Object.ValueType) Then
			Object.AdditionalValuesUsed = True;
		EndIf;
		
		WeightCheckQuery.SetParameter("Property", PropertySelection.Ref);
		If Not WeightCheckQuery.Execute().IsEmpty() Then
			Object.AdditionalValuesWithWeight = True;
		EndIf;
		
		InfobaseUpdate.WriteData(Object);
	EndDo;
	
	// Filling constants.
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	ChartOfCharacteristicTypes.AdditionalDataAndAttributes AS AdditionalDataAndAttributes
	|WHERE
	|	AdditionalDataAndAttributes.PropertySet = VALUE(Catalog.AdditionalDataAndAttributeSets.EmptyRef)
	|	AND AdditionalDataAndAttributes.DeletionMark = FALSE";
	
	If Not Query.Execute().IsEmpty() Then
		If Constants.UseCommonAdditionalDataAndAttributes.Get() = False Then
			Constants.UseCommonAdditionalDataAndAttributes.Set(True);
		EndIf;
		If Constants.UseCommonAdditionalValues.Get() = False Then
			Constants.UseCommonAdditionalValues.Set(True);
		EndIf;
	EndIf;
	
EndProcedure

// Updates property content for all set groups while updating the subsystem.
Procedure UpdateAllSetGroupPropertyContent(Parameters = Undefined) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	PropertySets.Ref
	|FROM
	|	Catalog.AdditionalDataAndAttributeSets AS PropertySets
	|WHERE
	|	PropertySets.IsFolder = TRUE";
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		CheckRefreshGroupPropertyContent(Selection.Ref);
	EndDo;
	
EndProcedure

#EndRegion
