////////////////////////////////////////////////////////////////////////////////
// Properties subsystem
// 
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface 

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for standard processing of additional attributes.

// Creates necessary for work basic attributes and fields on the form.
// Fills additional attributes if used.
// Is called from the OnCreateAtServer handler of the form of the object with properties.
// 
// Parameters:
//   Form        - ManagedForm - in which additional attributes will display.
//
//   Object      - Undefined - the object will be received from the Object attribute of the form.
//               - FormDataStructure - by object type.
//
//   ItemForPlacementName - String - name of the form group in which properties will be placed.
//
//   ArbitraryObject - Boolean - if True then a table with description of additional attributes is created on the form
//                               The Object parameter is ignored, additional attributes are not created or filled.
//
//                               It is required when a single form is used sequentially to view or edit
//                               additional attributes of items in the container (including different types).
//
//                               After performing OnCreateAtServer, FillAdditionalAttributesInForm() 
//                               should be called to add and fill additional attributes.
//                               To save changes, CopyValuesFromFormAttributesToObject should be called
//                               and UpdateAdditionalAttributeItems should be called to update the content.
//
//   CommandPanelItemName - String - is the form item group name in which an 
//                               EditAdditionalAttributeContent button will be added. If the item 
//                               name is not specified, a standard group "Form.CommandBar" will be used.
//
Procedure OnCreateAtServer(Form, Object = Undefined, ItemForPlacementName = "",
			ArbitraryObject = False, CommandPanelItemName = "") Export
	
	If ArbitraryObject Then
		CreateAdditionalAttributeDetails = True;
	Else
		If Object = Undefined Then
			ObjectDescription = Form.Object;
		Else
			ObjectDescription = Object;
		EndIf;
		CreateAdditionalAttributeDetails = UseAdditionalAttributes(ObjectDescription.Ref);
	EndIf;
	
	CreateBasicFormObjects(Form, ItemForPlacementName,
		CreateAdditionalAttributeDetails, CommandPanelItemName);
	
	If Not ArbitraryObject Then
		FillAdditionalAttributesInForm(Form, ObjectDescription);
	EndIf;
	
EndProcedure

// Fills an object from attributes created on the form.
// Is called from the BeforeWriteAtServer handler of an object form with properties.
//
// Parameters:
//   Form          - ManagedForm - already configured in the OnCreateAtServer procedure.
//   CurrentObject - Object - <MetadataObjectKind>Object.<MetadataObjectName>.
//
Procedure OnReadAtServer(Form, CurrentObject) Export
	
	Structure = New Structure("Properties_UseProperties");
	FillPropertyValues(Structure, Form);
	
	If TypeOf(Structure.Properties_UseProperties) = Type("Boolean") Then
		FillAdditionalAttributesInForm(Form, CurrentObject);
	EndIf;
	
EndProcedure

// Fills an object from attributes created on the form.
// Is called from the BeforeWriteAtServer handler of an object form with properties.
//
// Parameters:
//   Form          - ManagedForm - already configured in the OnCreateAtServer procedure.
//   CurrentObject - Object - <MetadataObjectKind>Object.<MetadataObjectName>.
//
Procedure BeforeWriteAtServer(Form, CurrentObject) Export
	
	CopyValuesFromFormAttributesToObject(Form, CurrentObject);
	
EndProcedure

// Checks the filling of attributes that are mandatory.
// 
// Parameters:
//   Form                - ManagedForm - already configured in the OnCreateAtServer procedure.
//   Cancel              - Boolean - FillCheckProcessingAtServer parameter data processor.
//   AttributesToCheck   - Array - FillCheckProcessorAtServer parameter data processor.
//
Procedure FillCheckProcessing(Form, Cancel, AttributesToCheck) Export
	
	If Not Form.Properties_UseProperties
	 Or Not Form.Properties_UseAdditionalAttributes Then
		
		Return;
	EndIf;
	
	Errors = Undefined;
	
	For Each Row In Form.Properties_AdditionalAttributeDetails Do
		If Row.RequiredToFill And Not Row.Deleted Then
			If Not ValueIsFilled(Form[Row.ValueAttributeName]) Then
				
				CommonUseClientServer.AddUserError(Errors,
					Row.ValueAttributeName,
					StringFunctionsClientServer.SubstituteParametersInString(
						NStr("en = 'The %1 field is required.'"), Row.Description));
			EndIf;
		EndIf;
	EndDo;
	
	CommonUseClientServer.ShowErrorsToUser(Errors, Cancel);
	
EndProcedure

// Updates additional data and attribute sets for kinds of objects that have properties.
//   Used when writing items of catalogs, which are kinds of objects that have properties.
//   For example, if there is a catalog named ProductsAndServices, to which the Properties subsystem 
//   applies, a ProductAndServiceTypes catalog is created for it, and then when writing the  
//   ProductOrServiceType item you must call this procedure.
//
// Parameters:
//   ObjectKind               - Object - for example, an item kind before write.
//   ObjectWithPropertiesName - String - for example, ProductOrService.
//   PropertySetAttributeName - String - used when there are several property sets or main set
//                                       name differs from "PropertySet".
// 
Procedure ObjectKindBeforeWrite(ObjectKind,
                                ObjectWithPropertiesName,
                                PropertySetAttributeName = "PropertySet") Export
	
	SetPrivilegedMode(True);
	
	PropertySet = ObjectKind[PropertySetAttributeName];
	SetParent = Catalogs.AdditionalDataAndAttributeSets[ObjectWithPropertiesName];
	
	If ValueIsFilled(PropertySet) Then
		
		OldSetProperties = CommonUse.ObjectAttributeValues(
			PropertySet, "Description, Parent, DeletionMark");
		
		If OldSetProperties.Description = ObjectKind.Description
		   And OldSetProperties.DeletionMark = ObjectKind.DeletionMark
		   And OldSetProperties.Parent = SetParent Then
			
			Return;
		EndIf;
		
		If OldSetProperties.Parent = SetParent Then
			LockDataForEdit(PropertySet);
			ObjectPropertySet = PropertySet.GetObject();
		Else
			ObjectPropertySet = PropertySet.Copy();
		EndIf;
	Else
		ObjectPropertySet = Catalogs.AdditionalDataAndAttributeSets.CreateItem();
	EndIf;
	
	ObjectPropertySet.Description  = ObjectKind.Description;
	ObjectPropertySet.DeletionMark = ObjectKind.DeletionMark;
	ObjectPropertySet.Parent       = SetParent;
	ObjectPropertySet.Write();
	
	ObjectKind[PropertySetAttributeName] = ObjectPropertySet.Ref;
	
EndProcedure

// Updates viewed data in the form of an object with properties.
// 
// Parameters:
//   Form        - ManagedForm - already configured in the OnCreateAtServer procedure.
//   Object      - Undefined - get the object from the "Object" form attribute.
//               - Object - CatalogObject, DocumentObject, ..., FormDataStructure (by object type).
//
Procedure UpdateAdditionalAttributeItems(Form, Object = Undefined) Export
	
	CopyValuesFromFormAttributesToObject(Form, Object);
	
	FillAdditionalAttributesInForm(Form, Object);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for non-standard processing of additional properties.

// Creates/re-creates additional attributes and items on form of the property owner.
//
// Parameters:
//   Form        - ManagedForm - already configured in the OnCreateAtServer procedure.
//   Object      - Undefined - get the object from the Object attribute of the form.
//               - Object - CatalogObject, DocumentObject, ..., FormDataStructure (by object type).
//   LabelFields - Boolean - if True is specified then label fields will be created 
//                           on the form, instead of input fields.
//
Procedure FillAdditionalAttributesInForm(Form, Object = Undefined, LabelFields = False) Export
	
	If Not Form.Properties_UseProperties
	 Or Not Form.Properties_UseAdditionalAttributes Then
		Return;
	EndIf;
	
	If Object = Undefined Then
		ObjectDescription = Form.Object;
	Else
		ObjectDescription = Object;
	EndIf;
	
	Form.Properties_ObjectAdditionalAttributeSets = New ValueList;
	
	PurposeUseKey = Undefined;
	ObjectPropertySets = PropertyManagementInternal.GetObjectPropertySets(
		ObjectDescription, PurposeUseKey);
	
	For Each Row In ObjectPropertySets Do
		If PropertyManagementInternal.SetPropertyTypes(Row.Set).AdditionalAttributes Then
			
			Form.Properties_ObjectAdditionalAttributeSets.Add(
				Row.Set, Row.Title);
		EndIf;
	EndDo;
	
	RefreshPurposeUseKey(Form, PurposeUseKey);
	
	PropertyDetailTable = PropertyManagementInternal.GetPropertyValueTable(
		ObjectDescription.AdditionalAttributes.Unload(),
		Form.Properties_ObjectAdditionalAttributeSets,
		False);
	
	PropertyDetailTable.Columns.Add("ValueAttributeName");
	PropertyDetailTable.Columns.Add("NameUniquePart");
	PropertyDetailTable.Columns.Add("AdditionalValue");
	PropertyDetailTable.Columns.Add("Boolean");
	
	DeleteOldAttributesAndItems(Form);
	
	// Creating attributes.
	AttributesToBeAdded = New Array();
	For Each PropertyDetails In PropertyDetailTable Do
		
		ValueTypeProperties = New TypeDescription(PropertyDetails.ValueType,
			,,, New StringQualifiers(1024));
		
		// Supporting strings of unlimited length.
		UseUnlimitedString = PropertyManagementInternal.UseUnlimitedString(
			ValueTypeProperties, PropertyDetails.MultilineInputField);
		
		If UseUnlimitedString Then
			ValueTypeProperties = New TypeDescription("String");
		EndIf;
		
		PropertyDetails.NameUniquePart = 
			StrReplace(Upper(String(PropertyDetails.Set.UUID())), "-", "x")
			+ "_"
			+ StrReplace(Upper(String(PropertyDetails.Property.UUID())), "-", "x");
		
		PropertyDetails.ValueAttributeName =
			"AdditionalAttributeValue_" + PropertyDetails.NameUniquePart;
		
		If PropertyDetails.Deleted Then
			ValueTypeProperties = New TypeDescription("String");
		EndIf;
		
		Attribute = New FormAttribute(PropertyDetails.ValueAttributeName, ValueTypeProperties, , PropertyDetails.Description, True);
		AttributesToBeAdded.Add(Attribute);
		
		PropertyDetails.AdditionalValue =
			PropertyManagementInternal.ValueTypeContainsPropertyValues(ValueTypeProperties);
		
		PropertyDetails.Boolean = CommonUse.TypeDescriptionContainsType(ValueTypeProperties, Type("Boolean"));
	EndDo;
	Form.ChangeAttributes(AttributesToBeAdded);
	
	// Creating form items.
	ItemForPlacementName = Form.Properties_ItemForPlacementName;
	PlacementItem = ?(ItemForPlacementName = "", Undefined, Form.Items[ItemForPlacementName]);
	
	For Each PropertyDetails In PropertyDetailTable Do
		
		FillPropertyValues(
			Form.Properties_AdditionalAttributeDetails.Add(), PropertyDetails);
		
		Form[PropertyDetails.ValueAttributeName] = PropertyDetails.Value;
		
		If ObjectPropertySets.Count() > 1 Then
			
			ListItem = Form.Properties_AdditionalAttributeGroupItems.FindByValue(
				PropertyDetails.Set);
			
			If ListItem <> Undefined Then
				Parent = Form.Items[ListItem.Presentation];
			Else
				SetDescription = ObjectPropertySets.Find(PropertyDetails.Set, "Set");
				
				If SetDescription = Undefined Then
					SetDescription = ObjectPropertySets.Add();
					SetDescription.Set = PropertyDetails.Set;
					SetDescription.Title = NStr("en = 'Deleted attributes'")
				EndIf;
				
				If Not ValueIsFilled(SetDescription.Title) Then
					SetDescription.Title = String(PropertyDetails.Set);
				EndIf;
				
				ItemNameSet = "SetAdditionalDetails" + PropertyDetails.NameUniquePart;
				
				Parent = Form.Items.Add(ItemNameSet, Type("FormGroup"), PlacementItem);
				
				Form.Properties_AdditionalAttributeGroupItems.Add(
					PropertyDetails.Set, Parent.Name);
				
				If TypeOf(PlacementItem) = Type("FormGroup")
				   And PlacementItem.Type = FormGroupType.Pages Then
					
					Parent.Type = FormGroupType.Page;
				Else
					Parent.Type = FormGroupType.UsualGroup;
					Parent.Representation = UsualGroupRepresentation.None;
				EndIf;
				Parent.ShowTitle = False;
				
				FilledGroupProperties = New Structure;
				For Each Column In ObjectPropertySets.Columns Do
					If SetDescription[Column.Name] <> Undefined Then
						FilledGroupProperties.Insert(Column.Name, SetDescription[Column.Name]);
					EndIf;
				EndDo;
				FillPropertyValues(Parent, FilledGroupProperties);
			EndIf;
		Else
			Parent = PlacementItem;
		EndIf;
		
		Item = Form.Items.Add(PropertyDetails.ValueAttributeName, Type("FormField"), Parent);
		
		If PropertyDetails.Boolean And IsBlankString(PropertyDetails.FormatProperties) Then
			Item.Type = FormFieldType.CheckBoxField;
		Else
			If LabelFields Then
				Item.Type = FormFieldType.LabelField;
				Item.Border = New Border(ControlBorderType.Single);
			Else
				Item.Type = FormFieldType.InputField;
				Item.AutoMarkIncomplete = PropertyDetails.RequiredToFill And Not PropertyDetails.Deleted;
			EndIf;
		EndIf;
		
		Item.DataPath = PropertyDetails.ValueAttributeName;
		Item.ToolTip = PropertyDetails.Property.ToolTip;
		
		If PropertyDetails.Property.MultilineInputField > 0 Then
			If Not LabelFields Then
				Item.MultiLine = True;
			EndIf;
			Item.Height = PropertyDetails.Property.MultilineInputField;
		EndIf;
		
		If Not IsBlankString(PropertyDetails.FormatProperties) Then
			If LabelFields Then
				Item.Format = PropertyDetails.FormatProperties;
			Else
				FormatString = "";
				Array = StringFunctionsClientServer.SplitStringIntoSubstringArray(
					PropertyDetails.FormatProperties, ";");
				
				For Each Substring In Array Do
					If Find(Substring, "DE=") > 0 Then
						Continue;
					EndIf;
					If Find(Substring, "NZ=") > 0 Then
						Continue;
					EndIf;
					If Find(Substring, "DF=") > 0 Then
						If Find(Substring, "ddd") > 0 Then
							Substring = StrReplace(Substring, "ddd", "dd");
						EndIf;
						If Find(Substring, "dddd") > 0 Then
							Substring = StrReplace(Substring, "dddd", "dd");
						EndIf;
						If Find(Substring, "MMMM") > 0 Then
							Substring = StrReplace(Substring, "MMMM", "MM");
						EndIf;
					EndIf;
					If Find(Substring, "DLF=") > 0 Then
						If Find(Substring, "DD") > 0 Then
							Substring = StrReplace(Substring, "DD", "D");
						EndIf;
					EndIf;
					FormatString = FormatString + ?(FormatString = "", "", ";") + Substring;
				EndDo;
				
				Item.Format = FormatString;
				Item.EditFormat = FormatString;
			EndIf;
		EndIf;
		
		If PropertyDetails.Deleted Then
			Item.TitleTextColor = StyleColors.InaccessibleDataColor;
			Item.TitleFont = StyleFonts.DeletedAdditionalAttributeFont;
			If Item.Type = FormFieldType.InputField Then
				Item.ClearButton = True;
				Item.ChoiceButton = False;
				Item.OpenButton = False;
				Item.DropListButton = False;
				Item.TextEdit = False;
			EndIf;
			
		ElsIf Not LabelFields Then
			
			AdditionalValueTypes = New Map;
			AdditionalValueTypes.Insert(Type("CatalogRef.ObjectPropertyValues"), True);
			AdditionalValueTypes.Insert(Type("CatalogRef.ObjectPropertyValueHierarchy"), True);
			
			UsedTypeAdditionalValues = True;
			For Each Type In PropertyDetails.ValueType.Types() Do
				If AdditionalValueTypes.Get(Type) = Undefined Then
					UsedTypeAdditionalValues = False;
					Break;
				EndIf;
			EndDo;
			If UsedTypeAdditionalValues Then
				Item.OpenButton = False;
			EndIf;
		EndIf;
		
		If Not LabelFields And PropertyDetails.AdditionalValue Then
			ChoiceParameters = New Array;
			ChoiceParameters.Add(New ChoiceParameter("Filter.Owner",
				?(ValueIsFilled(PropertyDetails.AdditionalValueOwner),
					PropertyDetails.AdditionalValueOwner, PropertyDetails.Property)));
			Item.ChoiceParameters = New FixedArray(ChoiceParameters);
		EndIf;
		
	EndDo;
	
EndProcedure

//Copies property values from the form attributes into the tabular section of the object.
// 
// Parameters:
//   Form     - ManagedForm - already configured in the OnCreateAtServer procedure.
//   Object   - Undefined - the object will be received from the Object attribute of the form.
//            - Object - CatalogObject, DocumentObject, ..., FormDataStructure (by object type).
//
Procedure CopyValuesFromFormAttributesToObject(Form, Object = Undefined) Export
	
	If Not Form.Properties_UseProperties
	 Or Not Form.Properties_UseAdditionalAttributes Then
		
		Return;
	EndIf;
	
	If Object = Undefined Then
		ObjectDescription = Form.Object;
	Else
		ObjectDescription = Object;
	EndIf;
	
	OldValues = ObjectDescription.AdditionalAttributes.Unload();
	ObjectDescription.AdditionalAttributes.Clear();
	
	For Each Row In Form.Properties_AdditionalAttributeDetails Do
		
		Value = Form[Row.ValueAttributeName];
		
		If Value = Undefined Then
			Continue;
		EndIf;
		
		If Row.ValueType.Types().Count() = 1
		   And (Not ValueIsFilled(Value) Or Value = False) Then
			
			Continue;
		EndIf;
		
		If Row.Deleted Then
			If ValueIsFilled(Value) Then
				FillPropertyValues(
					ObjectDescription.AdditionalAttributes.Add(),
					OldValues.Find(Row.Property, "Property"));
			EndIf;
			Continue;
		EndIf;
		
		NewRow = ObjectDescription.AdditionalAttributes.Add();
		NewRow.Property = Row.Property;
		NewRow.Value = Value;
		
		// Supporting strings of unlimited length.
		UseUnlimitedString = PropertyManagementInternal.UseUnlimitedString(
			Row.ValueType, Row.MultilineInputField);
		
		If UseUnlimitedString Then
			NewRow.TextString = Value;
		EndIf;
	EndDo;
	
EndProcedure

// Removes old attributes and form items.
// 
// Parameters:
//   Form        - ManagedForm - already configured in the OnCreateAtServer procedure.
//  
Procedure DeleteOldAttributesAndItems(Form) Export
	
	AttributesToBeDeleted = New Array;
	For Each PropertyDetails In Form.Properties_AdditionalAttributeDetails Do
		AttributesToBeDeleted.Add(PropertyDetails.ValueAttributeName);
		Form.Items.Delete(Form.Items[PropertyDetails.ValueAttributeName]);
	EndDo;
	
	If AttributesToBeDeleted.Count() > 0 Then
		Form.ChangeAttributes(, AttributesToBeDeleted);
	EndIf;
	
	For Each ListItem In Form.Properties_AdditionalAttributeGroupItems Do
		Form.Items.Delete(Form.Items[ListItem.Presentation]);
	EndDo;
	
	Form.Properties_AdditionalAttributeDetails.Clear();
	Form.Properties_AdditionalAttributeGroupItems.Clear();
	
EndProcedure

// Returns owner properties.
//
// Parameters:
//   PropertyOwner           - Ref - for example, CatalogRef.ProductsAndServices 
//                             DocumentRef.CustomerOrder, ...
//   GetAdditionalAttributes - Boolean - include additional attributes in the result.
//   GetAdditionalData       - Boolean - include additional data in the result.
//
// Returns:
//   Array - values 
//       * ChartOfCharacteristicTypesRef.AdditionalDataAndAttributes - if is.
//
Function GetPropertyList(PropertyOwner, GetAdditionalAttributes = True, GetAdditionalData = True) Export
	
	If Not (GetAdditionalAttributes Or GetAdditionalData) Then
		Return New Array;
	EndIf;
	
	ObjectPropertySets = PropertyManagementInternal.GetObjectPropertySets(
		PropertyOwner);
	
	ObjectPropertySetArray = ObjectPropertySets.UnloadColumn("Set");
	
	QueryTextAdditionalAttributes = 
		"SELECT
		|	PropertyTable.Property AS Property
		|FROM
		|	Catalog.AdditionalDataAndAttributeSets.AdditionalAttributes AS PropertyTable
		|WHERE
		|	PropertyTable.Ref IN (&ObjectPropertySetArray)";
	
	QueryTextAdditionalData = 
		"SELECT ALLOWED
		|	PropertyTable.Property AS Property
		|FROM
		|	Catalog.AdditionalDataAndAttributeSets.AdditionalData AS PropertyTable
		|WHERE
		|	PropertyTable.Ref IN (&ObjectPropertySetArray)";
	
	Query = New Query;
	
	If GetAdditionalAttributes And GetAdditionalData Then
		Query.Text = QueryTextAdditionalData +
		"UNION ALL" + QueryTextAdditionalAttributes;
		
	ElsIf GetAdditionalAttributes Then
		Query.Text = QueryTextAdditionalAttributes;
		
	ElsIf GetAdditionalData Then
		Query.Text = QueryTextAdditionalData;
	EndIf;
	
	Query.Parameters.Insert("ObjectPropertySetArray", ObjectPropertySetArray);
	
	Result = Query.Execute().Unload().UnloadColumn("Property");
	
	Return Result;
	
EndFunction

// Returns values of additional properties of an object.
//
// Parameters:
//   PropertyOwner           - Ref - for example, CatalogRef.ProductsAndServices, 
//                             DocumentRef.CustomerOrder ...
//   GetAdditionalAttributes - Boolean - include additional attributes in the result.
//   GetAdditionalData       - Boolean - include additional data in the result.
//   PropertyArray           - Array - properties:
//                             * ChartOfCharacteristicTypesRef.AdditionalDataAndAttributes -
//                                 values to get.
//                           - Undefined - get values of all owner properties.
// Returns:
//   ValueTable - columns:
//       * Property - ChartOfCharacteristicTypesRef.AdditionalDataAndAttributes - owner property.
//       * Value - Arbitrary - values of any type from description of property types of the 
//            Metadata.ChartOfCharacteristicTypes.AdditionalDataAndAttributes.Type metadata object.
//                 
Function GetPropertyValues(PropertyOwner,
                           GetAdditionalAttributes = True,
                           GetAdditionalData = True,
                           PropertyArray = Undefined) Export
	
	If PropertyArray = Undefined Then
		PropertyArray = GetPropertyList(PropertyOwner, GetAdditionalAttributes, GetAdditionalData);
	EndIf;
	
	ObjectWithPropertiesName = CommonUse.TableNameByRef(PropertyOwner);
	
	QueryTextAdditionalAttributes =
		"SELECT [ALLOWED]
		|	PropertyTable.Property AS Property,
		|	PropertyTable.Value AS Value,
		|	CASE
		|		WHEN AdditionalDataAndAttributes.MultilineInputField > 0
		|			THEN PropertyTable.TextString
		|		ELSE """"
		|	END AS TextString
		|FROM
		|	[ObjectWithPropertiesName].AdditionalAttributes AS PropertyTable
		|		LEFT JOIN ChartOfCharacteristicTypes.AdditionalDataAndAttributes AS AdditionalDataAndAttributes
		|		ON PropertyTable.Property = AdditionalDataAndAttributes.Ref
		|WHERE
		|	PropertyTable.Ref = &PropertyOwner
		|	AND PropertyTable.Property In (&PropertyArray)";
	
	QueryTextAdditionalData =
		"SELECT [ALLOWED]
		|	PropertyTable.Property AS Property,
		|	PropertyTable.Value AS Value,
		|	"""" AS TextString
		|FROM
		|	InformationRegister.AdditionalData AS PropertyTable
		|WHERE
		|	PropertyTable.Object = &PropertyOwner
		|	AND PropertyTable.Property IN (&PropertyArray)";
	
	Query = New Query;
	
	If GetAdditionalAttributes And GetAdditionalData Then
		QueryText = StrReplace(QueryTextAdditionalAttributes, "[ALLOWED]", "ALLOWED") +
			"
			| UNION ALL
			|" + StrReplace(QueryTextAdditionalData, "[ALLOWED]", "");
		
	ElsIf GetAdditionalAttributes Then
		QueryText = StrReplace(QueryTextAdditionalAttributes, "[ALLOWED]", "ALLOWED");
		
	ElsIf GetAdditionalData Then
		QueryText = StrReplace(QueryTextAdditionalData, "[ALLOWED]", "ALLOWED");
	EndIf;
	
	QueryText = StrReplace(QueryText, "ObjectWithPropertiesName", ObjectWithPropertiesName);
	
	Query.Parameters.Insert("PropertyOwner", PropertyOwner);
	Query.Parameters.Insert("PropertyArray", PropertyArray);
	Query.Text = QueryText;
	
	Result = Query.Execute().Unload();
	ResultWithTextStrings = Undefined;
	RowIndex = 0;
	For Each PropertyValue In Result Do
		TextString = PropertyValue.TextString;
		If Not IsBlankString(TextString) Then
			If ResultWithTextStrings = Undefined Then
				ResultWithTextStrings = Result.Copy(,"Property");
				ResultWithTextStrings.Columns.Add("Value");
				ResultWithTextStrings.LoadColumn(Result.UnloadColumn("Value"), "Value");
			EndIf;
			ResultWithTextStrings[RowIndex].Value = TextString;
		EndIf;
		RowIndex = RowIndex + 1;
	EndDo;
	
	Return ?(ResultWithTextStrings <> Undefined, ResultWithTextStrings, Result);
	
EndFunction

// Checks if the object has properties.
//
// Parameters:
//   PropertyOwner - Ref - for example, CatalogRef.ProductsAndServices, 
//                   DocumentRef.CustomerOrder, ...
//   Property      - ChartOfCharacteristicTypesRef.AdditionalDataAndAttributes - 
//                   the property to check.
//
// Returns:
//   Boolean - if True the owner has a property.
//
Function ValidateObjectProperty(PropertyOwner, Property) Export
	
	PropertyArray = GetPropertyList(PropertyOwner);
	
	If PropertyArray.Find(Property) = Undefined Then
		Return False;
	Else
		Return True;
	EndIf;
	
EndFunction

// Returns the listed values of the specified property.
// 
// Parameters:
//   Property - ChartOfCharacteristicTypesRef.AdditionalDataAndAttributes - property for 
//                         which you need to get the listed values.
// 
// Returns:
//   Array - values:
//       * CatalogRef.ObjectPropertyValues, CatalogRef.ObjectPropertyValueHierarchy -
//         property values, if any.
//
Function GetPropertyValueList(Property) Export
	
	ValueType = CommonUse.ObjectAttributeValue(Property, "ValueType");
	
	If ValueType.ContainsType(Type("CatalogRef.ObjectPropertyValueHierarchy")) Then
		QueryText =
		"SELECT
		|	Ref AS Ref
		|FROM
		|	Catalog.ObjectPropertyValueHierarchy AS ObjectPropertyValues
		|WHERE
		|	ObjectPropertyValues.Owner = &Property";
	Else
		QueryText =
		"SELECT
		|	Ref AS Ref
		|FROM
		|	Catalog.ObjectPropertyValues AS ObjectPropertyValues
		|WHERE
		|	ObjectPropertyValues.Owner = &Property";
	EndIf;
	
	Query = New Query;
	Query.Text = QueryText;
	Query.Parameters.Insert("Property", Property);
	Result = Query.Execute().Unload().UnloadColumn("Ref");
	
	Return Result;
	
EndFunction

// Writes additional attributes and additional data to the property owner.
// Changes occur in the transaction.
// 
// Parameters:
//   PropertyOwner         - Ref - for example, CatalogRef.ProductsAndServices, 
//                           DocumentRef.CustomerOrder, ...
//   PropertyAndValueTable - ValueTable - with columns:
//       * Property - ChartOfCharacteristicTypesRef.AdditionalDataAndAttributes - the property of the owner.
//       * Value - Arbitrary - any value allowed for properties specified in the property item.
//
Procedure WriteObjectProperties(PropertyOwner, PropertyAndValueTable) Export
	
	AddAttributeTable = New ValueTable;
	AddAttributeTable.Columns.Add("Property", New TypeDescription("ChartOfCharacteristicTypesRef.AdditionalDataAndAttributes"));
	AddAttributeTable.Columns.Add("Value");
	
	AddDataTable = AddAttributeTable.CopyColumns();
	
	For Each PropertyTableString In PropertyAndValueTable Do
		If PropertyTableString.Property.HasAdditionalData Then
			NewRow = AddDataTable.Add();
		Else
			NewRow = AddAttributeTable.Add();
		EndIf;
		FillPropertyValues(NewRow, PropertyTableString, "Property,Value");
	EndDo;
	
	HasAdditionalAttributes = AddAttributeTable.Count() > 0;
	HasAdditionalData  = AddDataTable.Count() > 0;
	
	PropertyArray = GetPropertyList(PropertyOwner);
	
	AdditionalAttributeArray = New Array;
	AdditionalDataArray = New Array;
	
	For Each AdditionalProperty In PropertyArray Do
		If AdditionalProperty.HasAdditionalData Then
			AdditionalDataArray.Add(AdditionalProperty);
		Else
			AdditionalAttributeArray.Add(AdditionalProperty);
		EndIf;
	EndDo;
	
	BeginTransaction(DataLockControlMode.Managed);
	
	If HasAdditionalAttributes Then
		PropertyOwnerObject = PropertyOwner.GetObject();
		LockDataForEdit(PropertyOwnerObject.Ref);
		For Each AdditionalAttribute In AddAttributeTable Do
			If AdditionalAttributeArray.Find(AdditionalAttribute.Property) = Undefined Then
				Continue;
			EndIf;
			RowArray = PropertyOwnerObject.AdditionalAttributes.FindRows(New Structure("Property", AdditionalAttribute.Property));
			If RowArray.Count() Then
				PropertyString = RowArray[0];
			Else
				PropertyString = PropertyOwnerObject.AdditionalAttributes.Add();
			EndIf;
			FillPropertyValues(PropertyString, AdditionalAttribute, "Property,Value");
		EndDo;
		PropertyOwnerObject.Write();
	EndIf;
	
	If HasAdditionalData Then
		For Each AddData In AddDataTable Do
			If AdditionalDataArray.Find(AddData.Property) = Undefined Then
				Continue;
			EndIf;
			
			RecordManager = InformationRegisters.AdditionalData.CreateRecordManager();
			
			RecordManager.Object = PropertyOwner;
			RecordManager.Property = AddData.Property;
			RecordManager.Value = AddData.Value;
			
			RecordManager.Write(True);
		EndDo;
		
	EndIf;
	
	CommitTransaction();
	
EndProcedure

// checks if additional attributes are used with the object.
//
// Parameters:
//   PropertyOwner - Ref - for example, CatalogRef.ProductsAndServices,
//                   DocumentRef.CustomerOrder, ...
//
// Returns:
//   Boolean - if True then additional attributes are used.
//
Function UseAdditionalAttributes(PropertyOwner) Export
	
	OwnerMetadata = PropertyOwner.Metadata();
	Return OwnerMetadata.TabularSections.Find("AdditionalAttributes") <> Undefined
	      And OwnerMetadata <> Metadata.Catalogs.AdditionalDataAndAttributeSets;
	
EndFunction

// Checks if an object uses additional data.
//
// Parameters:
//   PropertyOwner - Ref - for example, CatalogRef.ProductsAndServices,
//                   DocumentRef.CustomerOrder, ...
//
// Returns:
//   Boolean - if True then additional data are used.
//
Function UseAdditionalData(PropertyOwner) Export
	
	Return Metadata.FindByFullName("CommonCommand.AdditionalDataCommandBar") <> Undefined
	      And Metadata.CommonCommands.AdditionalDataCommandBar.CommandParameterType.Types().Find(TypeOf(PropertyOwner)) <> Undefined
	    Or Metadata.FindByFullName("CommonCommand.AdditionalDataNavigationPanel") <> Undefined
	      And Metadata.CommonCommands.AdditionalDataNavigationPanel.CommandParameterType.Types().Find(TypeOf(PropertyOwner)) <> Undefined;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Infobase update

// 1. Updates the names of predefined property sets if they differ from current 
// data presentation of relevant metadata objects with properties.
// 2. Updates the names of not common properties if their clarification differs 
// from the name of their set.
// 3. Sets a deletion mark for not common properties if a deletion mark is set 
// for their sets.
//
Procedure RefreshPropertyAndSetDescriptions() Export
	
	SetQuery = New Query;
	SetQuery.Text =
	"SELECT
	|	Sets.Ref AS Ref,
	|	Sets.Description AS Description
	|FROM
	|	Catalog.AdditionalDataAndAttributeSets AS Sets
	|WHERE
	|	Sets.Predefined
	|	AND Sets.Parent = VALUE(Catalog.AdditionalDataAndAttributeSets.EmptyRef)";
	
	SelectionSets = SetQuery.Execute().Select();
	While SelectionSets.Next() Do
		
		Description = PropertyManagementInternal.PredefinedSetDescription(
			SelectionSets.Ref);
		
		If SelectionSets.Description <> Description Then
			Object = SelectionSets.Ref.GetObject();
			Object.Description = Description;
			InfobaseUpdate.WriteData(Object);
		EndIf;
	EndDo;
	
	PropertyQuery = New Query;
	PropertyQuery.Text =
	"SELECT
	|	Properties.Ref AS Ref,
	|	Properties.PropertySet.Description AS PropertySetDescription,
	|	Properties.PropertySet.DeletionMark AS PropertySetDeletionMark
	|FROM
	|	ChartOfCharacteristicTypes.AdditionalDataAndAttributes AS Properties
	|WHERE
	|	CASE
	|			WHEN Properties.PropertySet = VALUE(Catalog.AdditionalDataAndAttributeSets.EmptyRef)
	|				THEN FALSE
	|			ELSE CASE
	|					WHEN Properties.Description <> Properties.Title + "" ("" + Properties.PropertySet.Description + "")""
	|						THEN TRUE
	|					WHEN Properties.DeletionMark <> Properties.PropertySet.DeletionMark
	|						THEN TRUE
	|					ELSE FALSE
	|				END
	|		END";
	
	PropertySelection = PropertyQuery.Execute().Select();
	While PropertySelection.Next() Do
		
		Object = PropertySelection.Ref.GetObject();
		Object.Description = Object.Title + " " + String(PropertySelection.PropertySetDescription) + "";
		Object.DeletionMark = PropertySelection.PropertySetDeletionMark;
		InfobaseUpdate.WriteData(Object);
	EndDo;
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions

// Creates basic attributes, commands, and items in the form of the property owner.
Procedure CreateBasicFormObjects(Form, ItemForPlacementName,
		CreateAdditionalAttributeDetails, CommandPanelItemName)
	
	Attributes = New Array;
	
	// Checking the value of the Use properties functional option.
	UsePropertiesOption = Form.GetFormFunctionalOption("UseAdditionalDataAndAttributes");
	UsePropertiesAttribute = New FormAttribute("Properties_UseProperties", New TypeDescription("Boolean"));
	Attributes.Add(UsePropertiesAttribute);
	
	If UsePropertiesOption Then
		
		UseAdditionalAttributesAttribute = New FormAttribute("Properties_UseAdditionalAttributes", New TypeDescription("Boolean"));
		Attributes.Add(UseAdditionalAttributesAttribute);
		
		If CreateAdditionalAttributeDetails Then
			
			// Creating an attribute containing used sets of additional attributes.
			Attributes.Add(New FormAttribute(
				"Properties_ObjectAdditionalAttributeSets", New TypeDescription("ValueList")));
			
			// Creating a property attribute for created attributes and form items.
			DescriptionName = "Properties_AdditionalAttributeDetails";
			
			Attributes.Add(New FormAttribute(
				DescriptionName, New TypeDescription("ValueTable")));
			
			Attributes.Add(New FormAttribute(
				"ValueAttributeName", New TypeDescription("String"), DescriptionName));
			
			Attributes.Add(New FormAttribute(
				"Property", New TypeDescription("ChartOfCharacteristicTypesRef.AdditionalDataAndAttributes"),
					DescriptionName));
			
			Attributes.Add(New FormAttribute(
				"ValueType", New TypeDescription("TypeDescription"), DescriptionName));
			
			Attributes.Add(New FormAttribute(
				"MultilineInputField", New TypeDescription("Number"), DescriptionName));
			
			Attributes.Add(New FormAttribute(
				"Deleted", New TypeDescription("Boolean"), DescriptionName));
			
			Attributes.Add(New FormAttribute(
				"RequiredToFill", New TypeDescription("Boolean"), DescriptionName));
			
			Attributes.Add(New FormAttribute(
				"Description", New TypeDescription("String"), DescriptionName));
			
			// Adding an attribute containing items of created groups of additional attributes.
			Attributes.Add(New FormAttribute(
				"Properties_AdditionalAttributeGroupItems", New TypeDescription("ValueList")));
			
			// Adding an attribute with an item name in which input fields will be placed.
			Attributes.Add(New FormAttribute(
				"Properties_ItemForPlacementName", New TypeDescription("String")));
			
			// Adding a form command if the AddEditBasicRegulatoryData role is set or this is a user with full access.
			If Users.RolesAvailable("AddEditBasicRegulatoryData") Then
				// Add a command.
				Command = Form.Commands.Add("EditAdditionalAttributeContent");
				Command.Title = NStr("en = 'Change content of custom fields'");
				Command.Action = "Attachable_EditPropertyContent";
				Command.ToolTip = NStr("en = 'Change content of custom fields'");
				Command.Picture = PictureLib.ListSettings;
				
				Button = Form.Items.Add(
					"EditAdditionalAttributeContent",
					Type("FormButton"),
					?(CommandPanelItemName = "",
						Form.CommandBar,
						Form.Items[CommandPanelItemName]));
				
				Button.OnlyInAllActions = True;
				Button.CommandName = "EditAdditionalAttributeContent";
			EndIf;
		EndIf;
	EndIf;
	
	Form.ChangeAttributes(Attributes);
	
	Form.Properties_UseProperties = UsePropertiesOption;
	
	If UsePropertiesOption Then
		Form.Properties_UseAdditionalAttributes = CreateAdditionalAttributeDetails;
	EndIf;
	
	If UsePropertiesOption And CreateAdditionalAttributeDetails Then
		Form.Properties_ItemForPlacementName = ItemForPlacementName;
	EndIf;
	
EndProcedure

Procedure RefreshPurposeUseKey(Form, PurposeUseKey)
	
	If PurposeUseKey = Undefined Then
		PurposeUseKey = PropertySetKey(Form.Properties_ObjectAdditionalAttributeSets);
	EndIf;
	
	If IsBlankString(PurposeUseKey) Then
		Return;
	EndIf;
	
	KeyBeginning = "PropertySetKey";
	PropertySetKey = KeyBeginning + Left(PurposeUseKey + "00000000000000000000000000000000", 32);
	
	Position = Find(Form.PurposeUseKey, KeyBeginning);
	
	If Position = 0 Then
		Form.PurposeUseKey = Form.PurposeUseKey + PropertySetKey;
	
	ElsIf Find(Form.PurposeUseKey, PropertySetKey) = 0 Then
		Form.PurposeUseKey =
			Left(Form.PurposeUseKey, Position - 1) + PropertySetKey
			+ Mid(Form.PurposeUseKey, Position + StrLen(KeyBeginning) + 32);
	EndIf;
	
EndProcedure

Function PropertySetKey(Sets)
	
	SetIDs = New ValueList;
	
	For Each ListItem In Sets Do
		SetIDs.Add(String(ListItem.Value.UUID()));
	EndDo;
	
	SetIDs.SortByValue();
	IDString = "";
	
	For Each ListItem In SetIDs Do
		IDString = IDString + StrReplace(ListItem.Value, "-", "");
	EndDo;
	
	DataHashing = New DataHashing(HashFunction.MD5);
	DataHashing.Append(IDString);
	
	Return StrReplace(DataHashing.HashSum, " ", "");
	
EndFunction

#EndRegion