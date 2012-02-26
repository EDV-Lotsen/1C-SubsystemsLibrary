

////////////////////////////////////////////////////////////////////////////////
// EXPORT FUNCTIONS AND PROCEDURES

// Called from handler OnCreateAtServer of form of object with properties
//
Procedure OnCreateAtServer(Form, Object, ItemNameForPlacement = Undefined) Export
	
	UseAdditionalAttributes = UseAdditionalAttributes(Object.Ref);
	
	If ValueIsFilled(Object.Ref) Then
		ObjectPropertiesSet = GetAvailablePropertiesSets(Object.Ref);
	Else
		TypeName 			= CommonUse.ObjectClassByRef(Object.Ref) + "Object." + Object.Ref.Metadata().Name;
		ObjectValue 		= FormDataToValue(Object, Type(TypeName));
		ObjectPropertiesSet = GetAvailablePropertiesSets(ObjectValue);
	EndIf;
	
	// Create main objects on the form
	CreateMainFormObjects(Form, ItemNameForPlacement, ObjectPropertiesSet, UseAdditionalAttributes);
	
	// If additional attributes usage is disabled via functional option then do nothing more
	If Not Form.__AddDataNAttrs_UseAdditionalData Then
		Return;
	EndIf;
	
	Form.__AddDataNAttrs_MainSet = ObjectPropertiesSet;
	
	If UseAdditionalAttributes Then
		// Create other attributes and place them on the form
		CreateAdditionalAttributeFieldsOnForm(Form, Object, ObjectPropertiesSet);
	EndIf;
	
EndProcedure

// Called from handler BeforeWriteAtServer of form of object with properties
//
Procedure BeforeWriteAtServer(Form, CurrentObject) Export
	
	If Form.__AddDataNAttrs_UseAdditionalData And Form.__AddDataNAttrs_UseAdditionalAttributes Then
		// Get values of additional attributes from form attributes into the object
		GetObjectAttributeValuesFromForm(Form, CurrentObject);
	EndIf;
	
EndProcedure

// Refresh data displayed on the object form with properties
//
Procedure UpdateAdditionalDataAndAttributesItems(Form, Object) Export
	
	If Not Form.__AddDataNAttrs_UseAdditionalData
	   Or Not Form.__AddDataNAttrs_UseAdditionalAttributes Then
		Return;
	EndIf;
	
	ObjectPropertiesSet = GetAvailablePropertiesSets(Object);
	Form.__AddDataNAttrs_MainSet = ObjectPropertiesSet;
	
	// get values of additional attributes from form attributes into the object
	GetObjectAttributeValuesFromForm(Form, Object);
	
	// Create attributes and place them on the form
	CreateAdditionalAttributeFieldsOnForm(Form, Object, ObjectPropertiesSet)
	
EndProcedure

// Used on write of the items of catalogs, which are the object kinds with properties
// If there is catalog Entities with the applied subsystem Properties, and catalog
// KindsOfEntities is created for it, then on writing the item of KindsOfEntities we have to call this procedure
//
// Parameters:
//	ObjectRef 				 - Object, whose writing is in process
//	ObjectWithPropertiesName - Name of the object with properties whose kind is being written
//
Procedure BeforeObjectKindWrite(ObjectRef, ObjectWithPropertiesName) Export
	
	If Not ValueIsFilled(ObjectRef.AttributeSettings) Then
		SettingsObject = Catalogs.AdditionalDataAndAttributesSettings.CreateItem();
	Else
		If Not PropertiesSetMustBeModified(ObjectRef) Then
			Return;
		EndIf;
		
		SettingsObject = ObjectRef.AttributeSettings.GetObject();
		LockDataForEdit(SettingsObject.Ref);
	EndIf;
	
	SettingsObject.Description   = ObjectRef.Description;
	SettingsObject.Parent        = Catalogs.AdditionalDataAndAttributesSettings[ObjectWithPropertiesName];
	SettingsObject.DeletionMark  = ObjectRef.DeletionMark;
	SettingsObject.Write();
	ObjectRef.AttributeSettings = SettingsObject.Ref;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// EXPORT FUNCTIONS FOR GETTING AND EDITING OF SET OF PROPERTIES

// Gets property properties with values using property's owner (ref)
// Parameters:
// PropertiesOwner  - ref	 	- ref to infobase object - owner of the properties
// ReceiveAdditionalDataAndAttributes 		- boolean - include addit. attributes in result
// ReceiveAdditionalInfo - boolean 	- include addit. info in result
//
Function GetPropertiesList(PropertiesOwner, ReceiveAdditionalDataAndAttributes = True, ReceiveAdditionalInfo = True) Export
	
	If Not (ReceiveAdditionalDataAndAttributes Or ReceiveAdditionalInfo) Then
		Return New Array;
	EndIf;
	
	AttributeSettings = GetAvailablePropertiesSets(PropertiesOwner);
	
	If TypeOf(AttributeSettings) = Type("ValueList") Then
		PropertiesArray = AttributeSettings.UnloadValues();
	Else // item catalog
		PropertiesArray = New Array;
		PropertiesArray.Add(AttributeSettings);
	EndIf;
	
	QueryTextAdditionalAttributes = 
		"SELECT
		|	AdditionalAttributes.Property AS Property
		|FROM
		|	Catalog.AdditionalDataAndAttributesSettings.AdditionalAttributes AS AdditionalAttributes
		|WHERE
		|	AdditionalAttributes.Ref IN (&PropertiesArray)";
	
	QueryTextAdditInfo = 
		"SELECT ALLOWED
		|	AdditionalData.Property AS Property
		|FROM
		|	Catalog.AdditionalDataAndAttributesSettings.AdditionalData AS AdditionalData
		|WHERE
		|	AdditionalData.Ref IN(&PropertiesArray)";
	
	Query = New Query;
	
	If ReceiveAdditionalDataAndAttributes And ReceiveAdditionalInfo Then
		Query.Text = QueryTextAdditInfo
					 + "
					 | UNION ALL
					 |"
					 + QueryTextAdditionalAttributes;
	ElsIf ReceiveAdditionalDataAndAttributes Then
		Query.Text = QueryTextAdditionalAttributes;
	ElsIf ReceiveAdditionalInfo Then
		Query.Text = QueryTextAdditInfo;
	EndIf;
	
	Query.Parameters.Insert("PropertiesArray", PropertiesArray);
	
	Result = Query.Execute().Unload().UnloadColumn("Property");
	
	Return Result;
	
EndFunction

// Returns values of object additional properties
// Parameters:
// PropertiesOwner  - ref 			- ref to infobase object - owner of the properties
// ReceiveAdditionalDataAndAttributes 			- boolean - get values of addit. attributes
// ReceiveAdditionalInfo - boolean 		- get values of addit. information
// PropertiesArray  - Array 		- array of properties, whose values we need to get, if is not passed,
//										being filled based on the object own properties
// Returned value 	- value table 	- columns "Property" and "Value"
//
Function GetPropertiesValues(PropertiesOwner, ReceiveAdditionalDataAndAttributes = True, ReceiveAdditionalInfo = True, PropertiesArray = Undefined) Export
	
	If PropertiesArray = Undefined Then
		PropertiesArray = GetPropertiesList(PropertiesOwner, ReceiveAdditionalDataAndAttributes, ReceiveAdditionalInfo);
	EndIf;
	
	ObjectWithPropertiesName = CommonUse.FullMetadataObjectNameByRef(PropertiesOwner);
	
	QueryTextAdditionalAttributes =
		"SELECT [ALLOWED]
		|	PropertiesTable.Property AS Property,
		|	PropertiesTable.Value AS Value
		|FROM
		|	[ObjectWithPropertiesName].AdditionalAttributes AS PropertiesTable
		|WHERE
		|	PropertiesTable.Ref = &PropertiesOwner
		|	And PropertiesTable.Property In (&PropertiesArray)";
	
	QueryTextAdditInfo =
		"SELECT [ALLOWED]
		|	PropertiesTable.Property AS Property,
		|	PropertiesTable.Value AS Value
		|FROM
		|	InformationRegister.AdditionalProperties AS PropertiesTable
		|WHERE
		|	PropertiesTable.Object = &PropertiesOwner
		|	And PropertiesTable.Property In (&PropertiesArray)";
	
	Query = New Query;
	
	If ReceiveAdditionalDataAndAttributes And ReceiveAdditionalInfo Then
		QueryText = StrReplace(QueryTextAdditionalAttributes, "[ALLOWED]", "ALLOWED")
					+ "
					| UNION ALL
					|"
					+ StrReplace(QueryTextAdditInfo, "[ALLOWED]", "");
		
	ElsIf ReceiveAdditionalDataAndAttributes Then
		QueryText = StrReplace(QueryTextAdditionalAttributes, "[ALLOWED]", "ALLOWED");
	ElsIf ReceiveAdditionalInfo Then
		QueryText = StrReplace(QueryTextAdditInfo, "[ALLOWED]", "ALLOWED");
	EndIf;
	
	QueryText = StrReplace(QueryText, "[ObjectWithPropertiesName]", ObjectWithPropertiesName);
	
	Query.Parameters.Insert("PropertiesOwner", PropertiesOwner);
	Query.Parameters.Insert("PropertiesArray", PropertiesArray);
	Query.Text = QueryText;
	
	Result = Query.Execute().Unload();
	
	Return Result;
	
EndFunction

// Check if object has property
// Parameters:
// PropertiesOwner - ref - ref to infobase object - owner of the properties
// Property - CCK.AdditionalDataAndAttributes
//
Function ObjectPropertyExists(Object, PropertyName) Export
	
	PropertiesArray = GetPropertiesList(Object);
	
	If PropertiesArray.Find(PropertyName) = Undefined Then
		Return False;
	Else
		Return True;
	EndIf;
	
EndFunction

// Returns array of refs to items of the catalog ObjectPropertyValues,
// whose owner is 	- passed property
// Parameter:
// Property 		- CCK AdditionalDataAndAttributes - owner of the properties
//
Function GetPropertyValuesList(Property) Export
	
	QueryTex =
	"SELECT
	|	ObjectPropertyValues.Ref AS Ref
	|FROM
	|	Catalog.ObjectPropertyValues AS ObjectPropertyValues
	|WHERE
	|	ObjectPropertyValues.Owner = &Property";
	
	Query 		= New Query;
	Query.Text 	= QueryTex;
	Query.Parameters.Insert("Property", Property);
	Result 		= Query.Execute().Unload().UnloadColumn("Ref");
	
	Return Result;
	
EndFunction

// Writes additional attributes and data to the owner of the properties
// Changes are done in transaction.
// Parameters
// PropertiesOwner - ref/object 		- ref to property owner
// PropertiesTableAndValues 			- valueTable - with columns
//							Property 	- CCK.AdditionalDataAndAttributes
//							Value 		- any value, valid for the property
//
Procedure WriteObjectProperties(PropertiesOwner, PropertiesTableAndValues) Export
	
	AdditionalAttributesTable = New ValueTable;
	AdditionalAttributesTable.Columns.Add("Property", New TypeDescription("ChartOfCharacteristicTypesRef.AdditionalDataAndAttributes"));
	AdditionalAttributesTable.Columns.Add("Value");
	
	AdditionalDataTable = AdditionalAttributesTable.CopyColumns();
	
	For Each PropertiesTableRow In PropertiesTableAndValues Do
		If PropertiesTableRow.Property.IsAdditionalData Then
			NewRow = AdditionalDataTable.Add();
		Else
			NewRow = AdditionalAttributesTable.Add();
		EndIf;
		FillPropertyValues(NewRow, PropertiesTableRow, "Property,Value");
	EndDo;
	
	HaveAdditionalAttributes = AdditionalAttributesTable.Count() > 0;
	HaveAdditionalData  	 = AdditionalDataTable.Count() > 0;
	
	PropertiesArray = GetPropertiesList(PropertiesOwner);
	
	AdditionalAttributesArray = New Array;
	AdditionalDataArray 	  = New Array;
	
	For Each AdditProperty In PropertiesArray Do
		If AdditProperty.IsAdditionalData Then
			AdditionalDataArray.Add(AdditProperty);
		Else
			AdditionalAttributesArray.Add(AdditProperty);
		EndIf;
	EndDo;
	
	BeginTransaction(DataLockControlMode.Managed);
	
	If HaveAdditionalAttributes Then
		PropertiesOwnerObject = PropertiesOwner.GetObject();
		LockDataForEdit(PropertiesOwnerObject.Ref);
		For Each AdditAttribute In AdditionalAttributesTable Do
			If AdditionalAttributesArray.Find(AdditAttribute.Property) = Undefined Then
				Continue;
			EndIf;
			RowsArray = PropertiesOwnerObject.AdditionalAttributes.FindRows(New Structure("Property", AdditAttribute.Property));
			If RowsArray.Count() Then
				PropertyRow = RowsArray[0];
			Else
				PropertyRow = PropertiesOwnerObject.AdditionalAttributes.Add();
			EndIf;
			FillPropertyValues(PropertyRow, AdditAttribute, "Property,Value");
		EndDo;
		PropertiesOwnerObject.Write();
	EndIf;
	
	If HaveAdditionalData Then
		For Each AdditionalDataRow In AdditionalDataTable Do
			If AdditionalDataArray.Find(AdditionalDataRow.Property) = Undefined Then
				Continue;
			EndIf;
			
			RecordManager = InformationRegisters.AdditionalData.CreateRecordManager();
			
			RecordManager.Object 	= PropertiesOwner;
			RecordManager.Property 	= AdditionalDataRow.Property;
			RecordManager.Value 	= AdditionalDataRow.Value;
			
			RecordManager.Write(True);
		EndDo;
		
	EndIf;
	
	CommitTransaction();
	
EndProcedure

// Checks, if additional attributes are used with the object
//
Function UseAdditionalAttributes(PropertiesOwner) Export
	
	Return PropertiesOwner.Metadata().TabularSections.Find("AdditionalAttributes") <> Undefined;
	
EndFunction

// Checks, if additional info are used with the object
//
Function UseAdditionalData(PropertiesOwner) Export
	
	Return Metadata.FindByFullName("CommonCommand.AdditionalData") <> Undefined And
			Metadata.CommonCommands.AdditionalData.CommandParameterType.Types().Find(TypeOf(PropertiesOwner)) <> Undefined;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// SERVICE EXPORT FUNCTIONS AND PROCEDURES

// Get a set or a list of sets of properties available for the object using object or object ref
// Parameters:
//	PropertiesOwner - ref to the object or object itself
Function GetAvailablePropertiesSets(PropertiesOwner) Export
	
	AvailableSets = AdditionalDataAndAttributesManagementOverrided.GetAvailablePropertiesSetsByObject(PropertiesOwner);
	
	If AvailableSets = Undefined Then
		Return GetMainPropertiesSetForObject(PropertiesOwner);
	Else
		Return AvailableSets;
	EndIf;
		
EndFunction

// Get filled value table of object properties
//
Function GetPropertyValuesTable(AdditionalObjectProperties, Set, IsAdditionalData) Export
	
	PropertiesArray = AdditionalObjectProperties.UnloadColumn("Property");
	
	QueryText =
		"SELECT ALLOWED
		|	PropertiesSetsAdditionalAttributes.Property AS Property,
		|	MIN(PropertiesSetsAdditionalAttributes.LineNumber) AS Order
		|INTO AllAssignedProperties
		|FROM
		|	Catalog.AdditionalDataAndAttributesSettings.AdditionalAttributes AS PropertiesSetsAdditionalAttributes
		|WHERE
		|	PropertiesSetsAdditionalAttributes.Ref IN (&Set)
		|	AND NOT PropertiesSetsAdditionalAttributes.Ref.DeletionMark
		|	AND NOT PropertiesSetsAdditionalAttributes.Ref.IsFolder
		|	AND NOT &IsAdditionalData
		|
		|GROUP BY
		|	PropertiesSetsAdditionalAttributes.Property
		|
		|UNION ALL
		|
		|SELECT
		|	PropertiesSetsAdditionalData.Property,
		|	MIN(PropertiesSetsAdditionalData.LineNumber)
		|FROM
		|	Catalog.AdditionalDataAndAttributesSettings.AdditionalData AS PropertiesSetsAdditionalData
		|WHERE
		|	PropertiesSetsAdditionalData.Ref IN (&Set)
		|	AND NOT PropertiesSetsAdditionalData.Ref.DeletionMark
		|	AND NOT PropertiesSetsAdditionalData.Ref.IsFolder
		|	AND &IsAdditionalData
		|
		|GROUP BY
		|	PropertiesSetsAdditionalData.Property
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED DISTINCT
		|	AdditionalDataAndAttributes.Ref AS Property
		|INTO FilledProperties
		|FROM
		|	ChartOfCharacteristicTypes.AdditionalDataAndAttributes AS AdditionalDataAndAttributes
		|WHERE
		|	AdditionalDataAndAttributes.Ref IN(&PropertiesArray)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	AllAssignedProperties.Property,
		|	AllAssignedProperties.Order,
		|	FALSE AS Filled
		|INTO AllProperties
		|FROM
		|	AllAssignedProperties AS AllAssignedProperties
		|
		|UNION ALL
		|
		|SELECT
		|	FilledProperties.Property,
		|	0,
		|	TRUE
		|FROM
		|	FilledProperties AS FilledProperties
		|		LEFT JOIN AllAssignedProperties AS AllAssignedProperties
		|		ON FilledProperties.Property = AllAssignedProperties.Property
		|WHERE
		|	AllAssignedProperties.Property IS NULL 
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	AllProperties.Property,
		|	AdditionalDataAndAttributes.Description,
		|	AdditionalDataAndAttributes.ValueType,
		|	AdditionalDataAndAttributes.FormatProperties,
		|	AdditionalDataAndAttributes.MultilineTextBox,
		|	AllProperties.Filled AS Filled
		|FROM
		|	AllProperties AS AllProperties
		|		INNER JOIN ChartOfCharacteristicTypes.AdditionalDataAndAttributes AS AdditionalDataAndAttributes
		|		ON AllProperties.Property = AdditionalDataAndAttributes.Ref
		|
		|ORDER BY
		|	Filled,
		|	AllProperties.Order";
	
	Query = New Query;
	Query.Text = QueryText;
	Query.TempTablesManager = New TempTablesManager;
	Query.SetParameter("IsAdditionalData", IsAdditionalData);
	Query.SetParameter("PropertiesArray", PropertiesArray);
	Query.SetParameter("Set", Set);
	
	TabProperties = Query.Execute().Unload();
	TabProperties.Indexes.Add("Property");
	TabProperties.Columns.Add("Value");
	
	For Each Row In AdditionalObjectProperties Do
		PropertiesRow = TabProperties.Find(Row.Property, "Property");
		If PropertiesRow <> Undefined Then
			///////////////////////////////////////////////////////////////
			// Open-ended strings support
			If Not IsAdditionalData
			   And UseOpenEndedString(PropertiesRow.ValueType, PropertiesRow.MultilineTextBox)
			   And Not IsBlankString(Row.TextString) Then 
				PropertiesRow.Value = Row.TextString;
			//
			///////////////////////////////////////////////////////////////
			Else
				PropertiesRow.Value = Row.Value;
			EndIf;
		EndIf;
	EndDo;
	
	Return TabProperties;
	
EndFunction

// Reads and returns values of addit. information
//
Function ReadAdditionalDataValuesFromInformationRegister(AdditionalDataOwner) Export
	
	Query = New Query;
	Query.Text =
		"SELECT ALLOWED
		|	AdditionalData.Property,
		|	AdditionalData.Value
		|FROM
		|	InformationRegister.AdditionalData AS AdditionalData
		|WHERE
		|	AdditionalData.Object = &Object";
	Query.SetParameter("Object", AdditionalDataOwner);
	
	Return Query.Execute().Unload();
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// SERVICE FUNCTIONS AND PROCEDURES

// Gets main set of properties using
// object or object ref and attribute name, containing object kind.
// For the ref to catalog "Entities" function will return
// predefined item of the catalog AdditionalDataAndAttributesSettings "Catalog_Entities".
// If parameter ObjectKindAttributeName is passed, then function will return ref
// to a set of properties, that is stored in Ref.<ObjectKindAttributeName>
//
Function GetMainPropertiesSetForObject(PropertiesOwner)
	
	ObjectMetadata = PropertiesOwner.Metadata();
	ObjectName = ObjectMetadata.Name;
	
	ObjectPassed = False;
	If CommonUse.IsReferentialTypeValue(PropertiesOwner) Then
		Ref = PropertiesOwner;
	Else
		ObjectPassed = True;
		Ref = PropertiesOwner.Ref;
	EndIf;
	
	ObjectRef = CommonUse.ObjectClassByRef(Ref);
	ObjectKindAttributeName = AdditionalDataAndAttributesManagementOverrided.GetObjectKindAttributeName(Ref);
	If ObjectKindAttributeName = "" Then
		If ObjectRef = "Catalog" or ObjectRef = "ChartOfCharacteristicTypes" Then
			If CommonUse.ObjectIsFolder(PropertiesOwner) Then
				Return Undefined;
			EndIf;
		EndIf;
		TagName = ObjectRef + "_" + ObjectName;
		Return Catalogs.AdditionalDataAndAttributesSettings[TagName];
		
	Else
		If ObjectPassed = True Then
			Return CommonUse.GetAttributeValue(PropertiesOwner[ObjectKindAttributeName], "AttributeSettings");
			
		Else
			Query = New Query;
			Query.Text =
			"SELECT
			|	ObjectPropertiesOwner." + ObjectKindAttributeName + ".AttributeSettings AS Set
			|FROM
			|	" + ObjectRef + "." + ObjectName + " AS ObjectPropertiesOwner
			|WHERE
			|	ObjectPropertiesOwner.Ref = &Ref";

			Query.SetParameter("Ref", Ref);
			Result = Query.Execute();
			
			If Not Result.IsEmpty() Then
				Selection = Result.Choose();
				Selection.Next();
				If ValueIsFilled(Selection.Set) Then
					Return Selection.Set;
				Else
					Return Catalogs.AdditionalDataAndAttributesSettings.EmptyRef();
				EndIf;
			Else
				Return Catalogs.AdditionalDataAndAttributesSettings.EmptyRef();
			EndIf;
			
		EndIf;
			
	EndIf;
	
EndFunction

// Create main objects (attributes, commands, items) on the form of object with properties
Procedure CreateMainFormObjects(Form, ItemNameForPlacement, ObjectPropertiesSet, UseAdditionalAttributes)
	
	AttributesArray = New Array;
	
	// Check value of functional "Use of properties"
	OptionUseProperties = Form.GetFormFunctionalOption("UseAdditionalAttributes");
	AttributeUseProperties = New FormAttribute("__AddDataNAttrs_UseAdditionalData", New TypeDescription("Boolean"));
	AttributesArray.Add(AttributeUseProperties);
	
	If OptionUseProperties Then
		
		AttributeUseAdditionalAttributes = New FormAttribute("__AddDataNAttrs_UseAdditionalAttributes", New TypeDescription("Boolean"));
		AttributesArray.Add(AttributeUseAdditionalAttributes);
		
		// Add attribute "MainSet"
		TypeName = ?(TypeOf(ObjectPropertiesSet) = Type("ValueList"), "ValueList", "CatalogRef.AdditionalDataAndAttributesSettings");
		AttributeMainSet = New FormAttribute("__AddDataNAttrs_MainSet", New TypeDescription(TypeName));
		AttributesArray.Add(AttributeMainSet);
			
		If UseAdditionalAttributes Then
			// Add attribute value table "DescriptionOfAdditionalDataAndAttributes" with columns
			DetailsName = "__AddDataNAttrs_AdditionalAttributesDescription";
			AttributeDescription_0 = New FormAttribute(DetailsName,            New TypeDescription("ValueTable"));
			AttributeDescription_1 = New FormAttribute("AttributeNameValue", 	New TypeDescription("String"), DetailsName);
			AttributeDescription_2 = New FormAttribute("AttributeNameProperty", New TypeDescription("String"), DetailsName);
			AttributeDescription_3 = New FormAttribute("Property",             	New TypeDescription("ChartOfCharacteristicTypesRef.AdditionalDataAndAttributes"), DetailsName);
			AttributesArray.Add(AttributeDescription_0);
			AttributesArray.Add(AttributeDescription_1);
			AttributesArray.Add(AttributeDescription_2);
			AttributesArray.Add(AttributeDescription_3);
			
			// Add attribute with the item name where input fields will be placed
			AttributeItemName = New FormAttribute("__AddDataNAttrs_ItemNameForPlacement", New TypeDescription("String"));
			AttributesArray.Add(AttributeItemName);
		EndIf;
		
		// Add form command only if role "AddChangeBasicReferenceInformation" is enabled or
		// this user has full rights
		If IsInRole(Metadata.Roles.AddChangeBasicReferenceInformation)
		 Or Users.CurrentUserHaveFullAccess() Then
			// Add command
			Command = Form.Commands.Add("EditContentOfProperties");
			Command.Title = NStr("en = 'Change Additional Data and Attributes'");
			Command.Action = "Pluggable_EditContentOfProperties";
			Command.ToolTip = NStr("en = 'Change additional data and attributes'");
			Command.Picture = PictureLib.ListSettings;
			
			Button = Form.Items.Add("EditContentOfProperties", Type("FormButton"), Form.CommandBar);
			Button.OnlyInAllActions = True;
			Button.CommandName = "EditContentOfProperties";
		EndIf;
	EndIf;
	
	Form.ChangeAttributes(AttributesArray);
	
	Form.__AddDataNAttrs_UseAdditionalData = OptionUseProperties;
	
	If OptionUseProperties Then
		Form.__AddDataNAttrs_UseAdditionalAttributes = UseAdditionalAttributes;
	EndIf;
	
	If OptionUseProperties And UseAdditionalAttributes Then
		Form.__AddDataNAttrs_ItemNameForPlacement = ItemNameForPlacement;
	EndIf;
	
EndProcedure

///////////////////////////////////////////////////////////////
// multiline input field support
Function UseOpenEndedString(PropertyValueType, MultilineTextBox) Export
	
	If PropertyValueType.ContainsType(Type("String"))
	   And PropertyValueType.Types().Count() = 1
	   And MultilineTextBox > 1 Then
		Return True;
	Else
		Return False;
	EndIf;
	
EndFunction
//
///////////////////////////////////////////////////////////////

// Create attributes with values of properties and place them on the form
Procedure CreateAdditionalAttributeFieldsOnForm(Form, Object, ObjectPropertiesSet)
	
	If ObjectPropertiesSet = Undefined Then
		Set = Form.__AddDataNAttrs_MainSet;
	Else
		Set = ObjectPropertiesSet;
	EndIf;
	
	Table = GetPropertyValuesTable(Object.AdditionalAttributes.Unload(), Set, False);
	Table.Columns.Add("AttributeNameValue");
	Table.Columns.Add("AttributeNameProperty");
	Table.Columns.Add("Boolean");
	
	DeleteOldAttributes(Form);
	Form.__AddDataNAttrs_AdditionalAttributesDescription.Clear();
	
	// Create attributes
	Number = 0;
	AttributesBeingAdded = New Array();
	For Each AttributeRow In Table Do
		
		Number = Number + 1;
		PropertyValueType = AttributeRow.ValueType;
		
		///////////////////////////////////////////////////////////////
		// Open-ended strings support
		If UseOpenEndedString(PropertyValueType, AttributeRow.MultilineTextBox) Then
			PropertyValueType = New TypeDescription("String");
		EndIf;
		//
		///////////////////////////////////////////////////////////////
		
		AttributeRow.AttributeNameValue = "AdditionalAttributeValue" + Format(Number, "NG=0");
		Attribute = New FormAttribute(AttributeRow.AttributeNameValue, PropertyValueType, , AttributeRow.Description, True);
		AttributesBeingAdded.Add(Attribute);
		
		AttributeRow.AttributeNameProperty = "";
		If ValueTypeContainsPropertiesValues(PropertyValueType) Then
			AttributeRow.AttributeNameProperty = "AdditionalAttributeProperty" + Format(Number, "NG=0");
			Attribute = New FormAttribute(AttributeRow.AttributeNameProperty, New TypeDescription("ChartOfCharacteristicTypesRef.AdditionalDataAndAttributes"), , , True);
			AttributesBeingAdded.Add(Attribute);
		EndIf;
		
		AttributeRow.Boolean = CommonUse.TypeDetailsConsistsOfType(PropertyValueType, Type("Boolean"));
		
	EndDo;
	Form.ChangeAttributes(AttributesBeingAdded);
	
	// Create form items
	For Each AttributeRow In Table Do
		
		NewRow = Form.__AddDataNAttrs_AdditionalAttributesDescription.Add();
		NewRow.AttributeNameValue = AttributeRow.AttributeNameValue;
		NewRow.AttributeNameProperty = AttributeRow.AttributeNameProperty;
		NewRow.Property             = AttributeRow.Property;
		
		Form[AttributeRow.AttributeNameValue] = AttributeRow.Value;
		
		ItemNameForPlacement = Form.__AddDataNAttrs_ItemNameForPlacement;
		Parent = ?(ItemNameForPlacement = "", Undefined, Form.Items[ItemNameForPlacement]);
		Item = Form.Items.Add(AttributeRow.AttributeNameValue, Type("FormField"), Parent);
		
		If AttributeRow.Boolean And IsBlankString(AttributeRow.FormatProperties) Then
			Item.Type = FormFieldType.CheckBoxField
		Else
			Item.Type = FormFieldType.InputField;
		EndIf;
		
		Item.DataPath = AttributeRow.AttributeNameValue;
		Item.ToolTip  = AttributeRow.Property.ToolTip;
		
		If AttributeRow.Property.MultilineTextBox > 0 Then
			Item.MultiLine = True;
			Item.Height= AttributeRow.Property.MultilineTextBox;
		EndIf;
		
		If NOT IsBlankString(AttributeRow.FormatProperties) Then
			Item.Format				 = AttributeRow.FormatProperties;
			Item.EditFormat			 = AttributeRow.FormatProperties;
		EndIf;
		
		If AttributeRow.Filled Then
			Item.TitleTextColor = StyleColors.DeletedAdditionalAttributeColor;
			Item.TitleFont = StyleFonts.DeletedAdditionalAttributeFont;
		EndIf;
		
		If AttributeRow.AttributeNameProperty <> "" Then
			Link = New ChoiceParameterLink("Filter.Owner", AttributeRow.AttributeNameProperty);
			arrConnections = New Array;
			arrConnections.Add(Link);
			Item.ChoiceParameterLinks = New FixedArray(arrConnections);
			Form[AttributeRow.AttributeNameProperty] = AttributeRow.Property;
		EndIf;
		
	EndDo;
	
EndProcedure

// Transfer values of properties from the form attributes into tabular section of the object
Procedure GetObjectAttributeValuesFromForm(Form, Object)
	
	Object.AdditionalAttributes.Clear();
	
	For Each Row In Form.__AddDataNAttrs_AdditionalAttributesDescription Do
		Value = Form[Row.AttributeNameValue];
		If ValueIsFilled(Value) Then
			If TypeOf(Value) = Type("Boolean") And Value = False Then
				Continue;
			EndIf;
			
			NewRow = Object.AdditionalAttributes.Add();
			NewRow.Property = Row.Property;
			NewRow.Value = Value;
			
			///////////////////////////////////////////////////////////////
			// Open-ended strings support
			Property = Row.Property.GetObject();
			If UseOpenEndedString(Property.ValueType, Property.MultilineTextBox) Then
				NewRow.TextString = Value;
			EndIf;
		//
		///////////////////////////////////////////////////////////////
		EndIf;
	EndDo;
	
EndProcedure

// Delete old attributes and form items
Procedure DeleteOldAttributes(Form)
	
	// Delete old attributes and items
	arrDelete = New Array;
	For Each AttributeRow In Form.__AddDataNAttrs_AdditionalAttributesDescription Do
		
		arrDelete.Add(AttributeRow.AttributeNameValue);
		If Not IsBlankString(AttributeRow.AttributeNameProperty) Then
			arrDelete.Add(AttributeRow.AttributeNameProperty);
		EndIf;
		
		Form.Items.Delete(Form.Items[AttributeRow.AttributeNameValue]);
		
	EndDo;
	
	If arrDelete.Count() Then
		Form.ChangeAttributes(, arrDelete);
	EndIf;
	
EndProcedure

// Check, that property value type contains ref to the catalog ObjectPropertyValues
Function ValueTypeContainsPropertiesValues(ValueType)
	
	Return ValueType.Types().Find(Type("CatalogRef.ObjectPropertyValues")) <> Undefined;
	
EndFunction

// check, if item of the set of properties has to be modified because of the changes in the object kind
Function PropertiesSetMustBeModified(ObjectRef)
	
	Result = CommonUse.GetAttributeValues(ObjectRef.AttributeSettings, "Description,DeletionMark");
	Return (Result.Description <> ObjectRef.Description) Or (Result.DeletionMark <> ObjectRef.DeletionMark);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// HANDLERS OF INFOBASE UPDATE

Procedure RefreshListOfAdditionalProperties() Export
	
	AdditionalDataAndAttributesSettings = Catalogs.AdditionalDataAndAttributesSettings.Select();
	
	While AdditionalDataAndAttributesSettings.Next() Do
		
		AdditionalData = New Array;
		
		AdditionalDataAndAttributesSettingsObject = 
			AdditionalDataAndAttributesSettings.Ref.GetObject();
		
		For Each Record In AdditionalDataAndAttributesSettingsObject.AdditionalAttributes Do
			If Record.Property.IsAdditionalData Then
				AdditionalData.Add(Record);
			EndIf;
		EndDo;
		
		If AdditionalData.Count() > 0 Then
			
			For Each AdditionalDataRow In AdditionalData Do
				NewRow = AdditionalDataAndAttributesSettingsObject.AdditionalData.Add();
				NewRow.Property = AdditionalDataRow.Property;
				AdditionalDataAndAttributesSettingsObject.AdditionalAttributes.Delete(
					AdditionalDataAndAttributesSettingsObject.AdditionalAttributes.IndexOf(AdditionalDataRow));
				
			EndDo;
			AdditionalDataAndAttributesSettingsObject.Write();
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure RefreshRenamedRoles_SSL_1_0_7_1() Export
	
	If Metadata.FindByFullName("CommonModule.AccessManagement") <> Undefined Then
		
		AccessManagementModule = Eval("AccessManagement");
	
		RenamedRoles = New ValueTable;
		RenamedRoles.Columns.Add("OldNameOfRole");
		RenamedRoles.Columns.Add("RoleNewName");
		
		RenamedRole = RenamedRoles.Add();
		RenamedRole.OldNameOfRole 	 = "AddChangeOfAdditionalInformation";
		RenamedRole.RoleNewName 	 = "ChangeAdditionalData";
		
		AccessManagementModule.RefreshRenamedRoles(RenamedRoles);
		
	EndIf;
	
EndProcedure
