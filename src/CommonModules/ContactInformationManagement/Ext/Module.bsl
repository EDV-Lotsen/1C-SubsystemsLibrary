////////////////////////////////////////////////////////////////////////////////
// Contact information subsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region Interface

////////////////////////////////////////////////////////////////////////////////
// Form event handlers, object module handlers.

// OnCreateAtServer form event handler. 
// It is called from the owner object form module when Contact information subsystem is embedded.
//
// Parameters:
//    Form                            - ManagedForm - owner object form used for contact information output. 
//    Object                          - Arbitrary   - contact information owner object. 
//    ContactInformationTitleLocation - FormItemTitleLocation - can take on the following values: 
//                                      FormItemTitleLocation.Left and FormItemTitleLocation.Top (default value).
//
Procedure OnCreateAtServer(Form, Object, ItemForPlacementName = "", TitleLocationContactInformation = "") Export
	
	String500 = New TypeDescription("String", , New StringQualifiers(500));
	
	BooleanTypeDescription = New TypeDescription("Boolean");
	AttributesToAddArray = New Array;
	
	// Creating a value table
	DescriptionName = "ContactInformationAdditionalAttributeInfo";
	AttributesToAddArray.Add(New FormAttribute(DescriptionName, New TypeDescription("ValueTable")));
	AttributesToAddArray.Add(New FormAttribute("AttributeName", String500, DescriptionName));
	AttributesToAddArray.Add(New FormAttribute("Kind", New TypeDescription("CatalogRef.ContactInformationKinds"), DescriptionName));
	AttributesToAddArray.Add(New FormAttribute("Type", New TypeDescription("EnumRef.ContactInformationTypes"), DescriptionName));
	AttributesToAddArray.Add(New FormAttribute("FieldValues", New TypeDescription("ValueList, String"), DescriptionName));
	AttributesToAddArray.Add(New FormAttribute("Presentation", String500, DescriptionName));
	AttributesToAddArray.Add(New FormAttribute("Comment", New TypeDescription("String"), DescriptionName));
	AttributesToAddArray.Add(New FormAttribute("IsTabularSectionAttribute", BooleanTypeDescription, DescriptionName));
	
	AddedItemsTableName = "AddedContactInformationItems";
	AttributesToAddArray.Add(New FormAttribute(AddedItemsTableName, New TypeDescription("ValueTable")));
	AttributesToAddArray.Add(New FormAttribute("ItemName", String500, AddedItemsTableName));
	AttributesToAddArray.Add(New FormAttribute("Priority", New TypeDescription("Number"), AddedItemsTableName));
	AttributesToAddArray.Add(New FormAttribute("IsCommand", BooleanTypeDescription, AddedItemsTableName));
	AttributesToAddArray.Add(New FormAttribute("IsTabularSectionAttribute", BooleanTypeDescription, AddedItemsTableName));
	
	AttributesToAddArray.Add(New FormAttribute("AddedContactInformationItemList", New TypeDescription("ValueList")));
	
	AttributesToAddArray.Add(New FormAttribute("ContactInformationTitleLocation", String500));
	AttributesToAddArray.Add(New FormAttribute("ContactInformationGroupForPlacement", String500));
	
	// Getting contact information kind list
	
	ObjectRef = Object.Ref;
	ObjectMetadata = ObjectRef.Metadata();
	MetadataObjectFullName = ObjectMetadata.FullName();
	CIKindGroupName = StrReplace(MetadataObjectFullName, ".", "");
	CIKindsGroup = Catalogs.ContactInformationKinds[CIKindGroupName];
	ObjectName = ObjectMetadata.Name;
	
	If ObjectMetadata.TabularSections.ContactInformation.Attributes.Find("TabularSectionRowID") = Undefined Then
		TabularSectionRowIDData = "0";
	Else
		TabularSectionRowIDData = "ISNULL(ContactInformation.TabularSectionRowID, 0)";
	EndIf;
	
	Query = New Query;
	If ValueIsFilled(ObjectRef) Then
		Query.Text ="
			|SELECT
			|	ContactInformationKinds.Ref                         AS Kind,
			|	ContactInformationKinds.PredefinedDataName          AS PredefinedDataName,
			|	ContactInformationKinds.Type                        AS Type,
			|	ContactInformationKinds.Mandatory                   AS Mandatory,
			|	ContactInformationKinds.ToolTip                     AS ToolTip,
			|	ContactInformationKinds.Description                 AS Description,
			|	ContactInformationKinds.Description                 AS Title,
			|	ContactInformationKinds.EditInDialogOnly            AS EditInDialogOnly,
			|	ContactInformationKinds.IsFolder                    AS IsTabularSectionAttribute,
			|	ContactInformationKinds.AdditionalOrderingAttribute AS AdditionalOrderingAttribute,
			|	ISNULL(ContactInformation.Presentation, """")       AS Presentation,
			|	ISNULL(ContactInformation.FieldValues, """")        AS FieldValues,
			|	ISNULL(ContactInformation.LineNumber, 0)            AS LineNumber,
			|	" + TabularSectionRowIDData + "                     AS RowID,
			|	CAST("""""""" AS STRING(200))                       AS AttributeName,
			|	CAST("""" AS STRING)                                AS Comment
			|FROM
			|	Catalog.ContactInformationKinds AS ContactInformationKinds
			|LEFT JOIN 
			|	" +  MetadataObjectFullName + ".ContactInformation
			|AS ContactInformation
			|ON ContactInformation.Ref
			|= &Owner AND
			|ContactInformationKinds.Ref
			|= ContactInformation.Kind
			|WHERE NOT
			|ContactInformationKinds.DeletionMark AND ( ContactInformationKinds.Parent
			|= &CIKindsGroup OR
			|ContactInformationKinds.Parent.Parent
			|= &CIKindsGroup
			|) ORDER BY ContactInformationKinds.Ref HIERARCHY
			|";
	Else 
		Query.Text ="
			|SELECT
			|	ContactInformation.Presentation  AS Presentation,
			|	ContactInformation.FieldValues   AS FieldValues,
			|	ContactInformation.LineNumber    AS LineNumber,
			|	ContactInformation.Kind          AS Kind,
			|	" + TabularSectionRowIDData + "  AS TabularSectionRowID
			|INTO 
			|	ContactInformation
			|FROM
			|	&ContactInformationTable AS ContactInformation
			|INDEX BY
			|	Kind
			|;////////////////////////////////////////////////////////////////////////////////
			|
			|SELECT
			|	ContactInformationKinds.Ref                         AS Kind,
			|	ContactInformationKinds.PredefinedDataName          AS PredefinedDataName,
			|	ContactInformationKinds.Type                        AS Type,
			|	ContactInformationKinds.Mandatory                   AS Mandatory,
			|	ContactInformationKinds.ToolTip                     AS ToolTip,
			|	ContactInformationKinds.Description                 AS Description,
			|	ContactInformationKinds.Description                 AS Title,
			|	ContactInformationKinds.EditInDialogOnly            AS EditInDialogOnly,
			|	ContactInformationKinds.IsFolder                    AS IsTabularSectionAttribute,
			|	ContactInformationKinds.AdditionalOrderingAttribute AS AdditionalOrderingAttribute,
			|	ISNULL(ContactInformation.Presentation, """")       AS Presentation,
			|	ISNULL(ContactInformation.FieldValues, """")        AS FieldValues,
			|	ISNULL(ContactInformation.LineNumber, 0)            AS LineNumber,
			|	" + TabularSectionRowIDData + "                     AS RowID,
			|	CAST("""""""" AS STRING(200))                       AS AttributeName,
			|	CAST("""" AS STRING)                                AS Comment
			|FROM
			|	Catalog.ContactInformationKinds AS ContactInformationKinds
			|LEFT JOIN 
			|	ContactInformation AS ContactInformation
			|ON 
			|	ContactInformationKinds.Ref = ContactInformation.Kind
			|WHERE
			|	Not ContactInformationKinds.DeletionMark
			|	AND (
			|		ContactInformationKinds.Parent = &CIKindsGroup 
			|		OR ContactInformationKinds.Parent.Parent = &CIKindsGroup
			|	)
			|ORDER BY
			|	ContactInformationKinds.Ref HIERARCHY
			|";
			
		Query.SetParameter("ContactInformationTable", Object.ContactInformation.Unload());
	EndIf;
	
	Query.SetParameter("CIKindsGroup", CIKindsGroup);
	Query.SetParameter("Owner", ObjectRef);
	
	SetPrivilegedMode(True);
	ContactInformation = Query.Execute().Unload(QueryResultIteration.ByGroupsWithHierarchy).Rows;
	SetPrivilegedMode(False);
	
	ContactInformation.Sort("AdditionalOrderingAttribute, LineNumber");
	
	For Each ContactInformationObject In ContactInformation Do
		
		If ContactInformationObject.IsTabularSectionAttribute Then
			
			CIKindName = ContactInformationObject.PredefinedDataName;
			Pos = Find(CIKindName, ObjectName);
			
			TabularSectionName = Mid(CIKindName, Pos + StrLen(ObjectName));
			
			PreviousKind = Undefined;
			AttributeName = "";
			
			ContactInformationObject.Rows.Sort("AdditionalOrderingAttribute");
			
			For Each CIRow In ContactInformationObject.Rows Do
				
				ContactInformationObject.Rows.Sort("AdditionalOrderingAttribute");
				
				CurrentKind = CIRow.Kind;
				
				If CurrentKind <> PreviousKind Then
					
					AttributeName = "ContactInformationField" + TabularSectionName + ContactInformationObject.Rows.IndexOf(CIRow);
					
					AttributesPath = "Object." + TabularSectionName;
					
					AttributesToAddArray.Add(New FormAttribute(AttributeName, String500, AttributesPath, CIRow.Title, True));
					AttributesToAddArray.Add(New FormAttribute(AttributeName + "FieldValues", New TypeDescription("ValueList, String"), AttributesPath,, True));
					PreviousKind = CurrentKind;
					
				EndIf;
				
				CIRow.AttributeName = AttributeName;
				
			EndDo;
			
		Else
			ContactInformationObject.AttributeName = "ContactInformationField" + ContactInformation.IndexOf(ContactInformationObject);
			
			AttributesToAddArray.Add(New FormAttribute(ContactInformationObject.AttributeName, String500, , ContactInformationObject.Title, True));
			
			// Proceeding regardless of any recognition errors
			Try
				ContactInformationObject.Comment = ContactInformationInternal.ContactInformationComment(ContactInformationObject.FieldValues);
			Except
				WriteLogEvent(ContactInformationInternalCached.EventLogMessageText(),
					EventLogLevel.Error, , ContactInformationObject.FieldValues, DetailErrorDescription(ErrorInfo())
				);
				CommonUseClientServer.MessageToUser(
					NStr("en = 'Contact information analysis error, possibly due to invalid field value format.'"), ,
					ContactInformationObject.AttributeName);
			EndTry;
		EndIf;
		
	EndDo;
	
	// Adding new attributes
	Form.ChangeAttributes(AttributesToAddArray);
	
	Form.ContactInformationTitleLocation = TitleLocationContactInformation;
	Form.ContactInformationGroupForPlacement = ItemForPlacementName;
	
	PreviousKind = Undefined;
	
	Filter = New Structure("Type", Enums.ContactInformationTypes.Address);
	AddressCount = ContactInformation.FindRows(Filter).Count();
	
	// Creating form items, filling in the attribute values
	Parent = ?(IsBlankString(ItemForPlacementName), Form, Form.Items[ItemForPlacementName]);
	
	// Creating groups for contact information
	CompositionGroup = Group("ContactInformationCompositionGroup",
	Form, Parent, ChildFormItemsGroup.Horizontal, 5);
	HeaderGroup = Group("ContactInformationTitleGroup",
	Form, CompositionGroup, ChildFormItemsGroup.Vertical, 4);
	InputFieldGroup = Group("ContactInformationInputFieldGroup",
	Form, CompositionGroup, ChildFormItemsGroup.Vertical, 4);
	ActionGroup = Group("ContactInformationActionGroup",
	Form, CompositionGroup, ChildFormItemsGroup.Vertical, 4);
	
	TitleLeft = TitleLeft(Form, TitleLocationContactInformation);
	
	For Each CIRow In ContactInformation Do
		
		If CIRow.IsTabularSectionAttribute Then
			
			CIKindName = CommonUse.PredefinedName(CIRow.Kind);
			Pos = Find(CIKindName, ObjectName);
			
			TabularSectionName = Mid(CIKindName, Pos + StrLen(ObjectName));
			
			PreviousTabularSectionKind = Undefined;
			
			For Each ContactInformationTabularSectionRow In CIRow.Rows Do
				
				TabularSectionKind = ContactInformationTabularSectionRow.Kind;
				
				If TabularSectionKind <> PreviousTabularSectionKind Then
					
					TabularSectionGroup = Form.Items[TabularSectionName + "ContactInformationGroup"];
					
					Item = Form.Items.Add(ContactInformationTabularSectionRow.AttributeName, Type("FormField"), TabularSectionGroup);
					Item.Type = FormFieldType.InputField;
					Item.DataPath = "Object." + TabularSectionName + "." + ContactInformationTabularSectionRow.AttributeName;
					
					If CanEditContactInformationTypeInDialog(ContactInformationTabularSectionRow.Type) Then
						Item.ChoiceButton = True;
						If TabularSectionKind.EditInDialogOnly Then
							Item.TextEdit = False;
						EndIf;
						
						Item.SetAction("StartChoice", "Attachable_ContactInformationStartChoice");
					EndIf;
					Item.SetAction("OnChange", "Attachable_ContactInformationOnChange");
					
					If TabularSectionKind.Mandatory Then
						Item.AutoMarkIncomplete = True;
					EndIf;
					
					AddItemDetails(Form, ContactInformationTabularSectionRow.AttributeName, 2, , True);
					AddAttributeToDetails(Form, ContactInformationTabularSectionRow, False, True);
					PreviousTabularSectionKind = TabularSectionKind;
					
				EndIf;
				
				Filter = New Structure;
				Filter.Insert("TabularSectionRowID", ContactInformationTabularSectionRow.RowID);
				
				TableRows = Form.Object[TabularSectionName].FindRows(Filter);
				
				If TableRows.Count() = 1 Then
					
					TableRow = TableRows[0];
					TableRow[ContactInformationTabularSectionRow.AttributeName] = ContactInformationTabularSectionRow.Presentation;
					TableRow[ContactInformationTabularSectionRow.AttributeName + "FieldValues"] = ContactInformationTabularSectionRow.FieldValues;
					
				EndIf;
				
			EndDo;
			
			Continue;
			
		EndIf;
		
		HasComment = ValueIsFilled(CIRow.Comment);
		AttributeName = CIRow.AttributeName;
		
		IsNewCIKind = (CIRow.Kind <> PreviousKind);
		
		// Adding the title
		If TitleLeft Then
			
			ItemTitle(Form, CIRow.Type, AttributeName, HeaderGroup, CIRow.Description, IsNewCIKind, HasComment);
			
		EndIf;
		
		TextBox(Form, CIRow.EditInDialogOnly, CIRow.Type, AttributeName, CIRow.ToolTip, IsNewCIKind, CIRow.Mandatory);
		
		// Displaying the comment
		If HasComment Then
			
			CommentName = "Comment" + AttributeName;
			Comment(Form, CIRow.Comment, CommentName, InputFieldGroup);
			
		EndIf;
		
		// Using a placeholder if the field title is located at the top
		If Not TitleLeft And IsNewCIKind Then
			
			DecorationName = "DecorationTop" + AttributeName;
			Decoration = Form.Items.Add(DecorationName, Type("FormDecoration"), ActionGroup);
			AddItemDetails(Form, DecorationName, 2);
			
		EndIf;
		
		Action(Form, CIRow.Type, AttributeName, ActionGroup, AddressCount, HasComment);
		AddAttributeToDetails(Form, CIRow, IsNewCIKind);
		
		PreviousKind = CIRow.Kind;
		
	EndDo;
	
	If Form.AddedContactInformationItemList.Count() > 0 Then
		
		CommandGroup = Group("ContactInformationGroupAddInputField",
		Form, Parent, ChildFormItemsGroup.Horizontal, 5);
		CommandGroup.Representation = UsualGroupRepresentation.NormalSeparation;
		
		CommandName = "ContactInformationAddInputField";
		Command = Form.Commands.Add(CommandName);
		Command.ToolTip = NStr("en = 'Add an additional contact information field'");
		Command.Representation = ButtonRepresentation.PictureAndText;
		Command.Picture = PictureLib.AddListItem;
		Command.Action = "Attachable_ContactInformationExecuteCommand";
		
		AddItemDetails(Form, CommandName, 9, True);
		
		Button = Form.Items.Add(CommandName,Type("FormButton"), CommandGroup);
		Button.Title = NStr("en = 'Add'");
		Button.CommandName = CommandName;
		AddItemDetails(Form, CommandName, 2);
		
	EndIf;
	
EndProcedure

// OnReadAtServer form event handler. 
// It is called from the owner object form module when Contact information subsystem is embedded.
//
// Parameters:
//    Form   - ManagedForm - owner object form used for contact information output. 
//    Object - Arbitrary   - contact information owner object.
//
Procedure OnReadAtServer(Form, Object) Export
	
	FormAttributeList = Form.GetAttributes();
	
	Restart = False;
	For Each Attribute In FormAttributeList Do
		If Attribute.Name = "ContactInformationAdditionalAttributeInfo" Then
			Restart = True;
			Break;
		EndIf;
	EndDo;
	
	If Restart Then
		
		TitleLocationContactInformation = Form.ContactInformationTitleLocation;
		TitleLocationContactInformation = ?(ValueIsFilled(TitleLocationContactInformation), FormItemTitleLocation[TitleLocationContactInformation], FormItemTitleLocation.Top);
		
		ItemForPlacementName = Form.ContactInformationGroupForPlacement;
		
		DeleteCommandsAndFormItems(Form);
		
		AttributesToDeleteArray = New Array;
		
		ObjectName = Object.Ref.Metadata().Name;
		
		For Each FormAttribute In Form.ContactInformationAdditionalAttributeInfo Do
			If Not FormAttribute.IsTabularSectionAttribute Then
				AttributesToDeleteArray.Add(FormAttribute.AttributeName);
			Else
				AttributesToDeleteArray.Add("Object." + TabularSectionNameByCIKind(FormAttribute.Kind, ObjectName) + "." + FormAttribute.AttributeName);
				AttributesToDeleteArray.Add("Object." + TabularSectionNameByCIKind(FormAttribute.Kind, ObjectName) + "." + FormAttribute.AttributeName + "FieldValues");
			EndIf;
		EndDo;
		
		AttributesToDeleteArray.Add("AddedContactInformationItems");
		AttributesToDeleteArray.Add("AddedContactInformationItemList");
		AttributesToDeleteArray.Add("ContactInformationTitleLocation");
		AttributesToDeleteArray.Add("ContactInformationGroupForPlacement");
		AttributesToDeleteArray.Add("ContactInformationAdditionalAttributeInfo");
		
		Form.ChangeAttributes(, AttributesToDeleteArray);
		
		OnCreateAtServer(Form, Object, ItemForPlacementName, TitleLocationContactInformation);
		
	EndIf;
	
EndProcedure

// AfterWriteAtServer form event handler. 
// It is called from the owner object form module when Contact information subsystem is embedded.
//
// Parameters:
//    Form   - ManagedForm - owner object form used for contact information output. 
//    Object - Arbitrary   - contact information owner object.
//
Procedure AfterWriteAtServer(Form, Object) Export
	
	ObjectName = Object.Ref.Metadata().Name;
	
	For Each TableRow In Form.ContactInformationAdditionalAttributeInfo Do
		
		If TableRow.IsTabularSectionAttribute Then
			
			InformationKind = TableRow.Kind;
			AttributeName = TableRow.AttributeName;
			TabularSectionName = TabularSectionNameByCIKind(InformationKind, ObjectName);
			FormTabularSection = Form.Object[TabularSectionName];
			
			For Each FormTabularSectionRow In FormTabularSection Do
				
				Filter = New Structure;
				Filter.Insert("Kind", InformationKind);
				Filter.Insert("TabularSectionRowID", FormTabularSectionRow.TabularSectionRowID);
				FoundRows = Object.ContactInformation.FindRows(Filter);
				
				If FoundRows.Count() = 1 Then
					
					CIRow = FoundRows[0];
					FormTabularSectionRow[AttributeName] = CIRow.Presentation;
					FormTabularSectionRow[AttributeName + "FieldValues"] = CIRow.FieldValues;
					
				EndIf;
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
EndProcedure

// FillCheckProcessingAtServer form event handler. 
// It is called from the owner object form module when Contact information subsystem is embedded.
//
// Parameters:
//    Form   - ManagedForm - owner object form used for contact information output. 
//    Object - Arbitrary   - contact information owner object.
//
Procedure FillCheckProcessingAtServer(Form, Object, Cancel) Export
	
	ObjectName = Object.Ref.Metadata().Name;
	ErrorLevel = 0;
	PreviousKind = Undefined;
	
	For Each TableRow In Form.ContactInformationAdditionalAttributeInfo Do
		
		InformationKind = TableRow.Kind;
		InformationType = TableRow.Type;
		Comment         = TableRow.Comment;
		AttributeName   = TableRow.AttributeName;
		
		Mandatory = InformationKind.Mandatory;
		
		If TableRow.IsTabularSectionAttribute Then
			
			TabularSectionName = TabularSectionNameByCIKind(InformationKind, ObjectName);
			FormTabularSection = Form.Object[TabularSectionName];
			
			For Each FormTabularSectionRow In FormTabularSection Do
				
				Presentation = FormTabularSectionRow[AttributeName];
				Field = "Object." + TabularSectionName + "[" + (FormTabularSectionRow.LineNumber - 1) + "]." + AttributeName;
				
				If Mandatory And IsBlankString(Presentation) Then
					
					MessageText = NStr("en = 'The %1 field is required.'");
					MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessageText, InformationKind.Description);
					CommonUseClientServer.MessageToUser(MessageText,,Field);
					CurrentErrorLevel = 2;
					
				Else
					
					FieldValues = FormTabularSectionRow[AttributeName + "FieldValues"];
					
					CurrentErrorLevel = ValidateContactInformation(Presentation, FieldValues, InformationKind,
					InformationType, AttributeName, , Field);
					
					FormTabularSectionRow[AttributeName] = Presentation;
					FormTabularSectionRow[AttributeName + "FieldValues"] = FieldValues;
					
				EndIf;
				
				ErrorLevel = ?(CurrentErrorLevel > ErrorLevel, CurrentErrorLevel, ErrorLevel);
				
			EndDo;
			
		Else
			
			Presentation = Form[AttributeName];
			
			If InformationKind <> PreviousKind And Mandatory And IsBlankString(Presentation) 
				// And no other strings containing data for contact information kinds with multiple values
				And Not HasOtherStringsFilledWithThisContactInformationKind(
					Form, TableRow, InformationKind
				)
			Then
				
				MessageText = NStr("en = 'The %1 field is required.'");
				MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessageText, InformationKind.Description);
				CommonUseClientServer.MessageToUser(MessageText,,,AttributeName);
				CurrentErrorLevel = 2;
				
			Else
				
				CurrentErrorLevel = ValidateContactInformation(Presentation, TableRow.FieldValues,
				InformationKind, InformationType, AttributeName, Comment);
				
			EndIf;
			
			ErrorLevel = ?(CurrentErrorLevel > ErrorLevel, CurrentErrorLevel, ErrorLevel);
			
		EndIf;
		
		PreviousKind = InformationKind;
		
	EndDo;
	
	If ErrorLevel <> 0 Then
		Cancel = True;
	EndIf;
	
EndProcedure

// BeforeWriteAtServer form event handler. 
// It is called from the owner object form module when Contact information subsystem is embedded.
//
// Parameters:
//    Form   - ManagedForm - owner object form used for contact information output. 
//    Object - Arbitrary   - contact information owner object.
//
Procedure BeforeWriteAtServer(Form, Object, Cancel = False) Export
	
	Object.ContactInformation.Clear();
	ObjectName = Object.Ref.Metadata().Name;
	PreviousKind = Undefined;
	
	For Each TableRow In Form.ContactInformationAdditionalAttributeInfo Do
		
		InformationKind = TableRow.Kind;
		InformationType = TableRow.Type;
		AttributeName   = TableRow.AttributeName;
		Mandatory       = InformationKind.Mandatory;
		
		If TableRow.IsTabularSectionAttribute Then
			
			TabularSectionName = TabularSectionNameByCIKind(InformationKind, ObjectName);
			FormTabularSection = Form.Object[TabularSectionName];
			For Each FormTabularSectionRow In FormTabularSection Do
				
				RowID = FormTabularSectionRow.GetID();
				FormTabularSectionRow.TabularSectionRowID = RowID;
				
				TabularSectionRow = Object[TabularSectionName][FormTabularSectionRow.LineNumber - 1];
				TabularSectionRow.TabularSectionRowID = RowID;
				
				FieldValues = FormTabularSectionRow[AttributeName + "FieldValues"];
				
				WriteContactInformation(Object, FieldValues, InformationKind, InformationType, RowID);
				
			EndDo;
			
		Else
			
			WriteContactInformation(Object, TableRow.FieldValues, InformationKind, InformationType);
			
		EndIf;
		
		PreviousKind = InformationKind;
		
	EndDo;
	
EndProcedure

// Adds (or deletes) an input field or comment for the form, and updates form data. 
// It is called from the owner object form module when Contact information subsystem is embedded.
//
// Parameters:
//    Form   - ManagedForm - owner object form used for contact information output. 
//    Object - Arbitrary   - contact information owner object.
//    Result - Arbitrary   - optional internal attribute provided by the previous event handler.
//
// Returns:
//    Undefined.
//
Function UpdateContactInformation(Form, Object, Result = Undefined) Export
	
	If Result = Undefined Then
		Return Undefined;
		
	ElsIf Result.Property("IsAddComment") Then
		ModifyComment(Form, Result.AttributeName, Result.IsAddComment);
		
	ElsIf Result.Property("AddedKind") Then
		AddContactInformationString(Form, Result);
		
	EndIf;
	
	Return Undefined;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Contact information accessibility for other subsystems.

// Checks a domestic address for compliance with address information requirements.
//
// Parameters:
//    AddressFieldStructure - Structure, ValueList, String - address information fields.
//                             Structure and ValueList contain address field names and values,
//                             String contains a single contact information XML string,
//                             or multiple strings with field names and values.
//
//    ContactInformationKind - CatalogRef.ContactInformationKinds - contact information kind matching the address to be validated.
//
// Returns:
//    Array - contains a structure with the following fields:
//        * ErrorType - String - Error ID. Available values:
//                "PresentationNotMatchingFieldSet"
//                "MandatoryFieldsNotFilled"
//                "FieldAbbreviationsNotSpecified"
//                "InvalidFieldCharacters"
//                "FieldLengthsNotMatching"
//                "ClassifierErrors"
//        * Message - String - Detailed error text.
//        * Fields - Array - contains structures with the following fields:
//                ** FieldName - String - address structure item name.
//                ** Message   - String - detailed error text for the field.
//
Function ValidateAddress(Val AddressFieldStructure, ContactInformationKind = Undefined) Export
	Return ContactInformationInternal.AddressFillErrors(AddressFieldStructure, ContactInformationKind, True);
EndFunction

// Converts all incoming contact information formats to XML.
//
// Parameters:
//    FieldValues  - String, Structure, Map, ValueList - description of the contact information fields.
//    Presentation - String - presentation. Used if unable to determine presentation based on the
//                            FieldValues parameter (the Presentation field is not available).
//    ExpectedKind - CatalogRef.ContactInformationKinds, EnumRef.ContactInformationTypes - Used if unable 
//                            to determine type by the FieldValues field.
//
// Returns:
//     String  - contact information XML string.
//
Function ContactInformationToXML(Val FieldValues, Val Presentation = "", Val ExpectedKind = Undefined) Export
	
	Result = ContactInformationXML.TransformContactInformationXML(New Structure(
		"FieldValues, Presentation, ContactInformationKind",
		FieldValues, Presentation, ExpectedKind));
	
	Return Result.XMLData;
EndFunction

// Returns ContactInformationTypes enumeration value by XML string.
//
// Parameters:
//    XMLString - String - contact information.
//
// Returns:
//    EnumRef.ContactInformationTypes - type matching the XML string.
//
Function ContactInformationType(Val XMLString) Export
	Return ContactInformationXML.ContactInformationType(XMLString);
EndFunction

// Reads or sets the contact information presentation.
//
// Parameters:
//    XMLString - String - contact information XML string.
//    NewValue  - String - value to be set.
//
// Returns:
//    String - new value.
//
Function ContactInformationPresentation(XMLString, Val NewValue = Undefined) Export
	Return ContactInformationInternal.ContactInformationPresentation(XMLString, NewValue);
EndFunction

// Generates contact information presentation based on internal field values.
//
// Parameters:
//    XMLString              - String - contact information XML string.
//    ContactInformationKind - CatalogRef.ContactInformationKinds, Structure - a set of flags
//                             specifying presentation generation parameters.
//
// Returns:
//    String - generated presentation.
//
Function ContactInformationPresentationByFieldValues(Val XMLString, Val ContactInformationKind = Undefined) Export
	
	If ContactInformationKind = Undefined Then
		Kind = ContactInformationKindStructure();
		Kind.Type = ContactInformationXML.ContactInformationType(XMLString);
	Else
		Kind = ContactInformationKind;
	EndIf;
	
	Return ContactInformationInternal.GenerateContactInformationPresentation(XMLString, Kind);
EndFunction

// Reads or sets a contact information comment.
//
// Parameters:
//    XMLString - String - contact information XML string.
//    NewValue  - String - value to be set.
//
// Returns:
//    String - new value.
//
Function ContactInformationComment(XMLString, Val NewValue = Undefined) Export
	Return ContactInformationInternal.ContactInformationComment(XMLString, NewValue);
EndFunction

// Reads or sets an address by document (for domestic addresses only). 
// If the passed string does not contain domestic address information, raises an exception.
//
// Parameters:
//    XMLString - String - contact information XML string.
//    NewValue  - String - value to be set.
//
// Returns:
//    String - new value.
//
Function AddressByContactInformationDocument(XMLString, Val NewValue = Undefined) Export
	If IsBlankString(XMLString) Then
		Return "";
	EndIf;
	
	Namespace = ContactInformationClientServerCached.Namespace();
	Read = New XMLReader;
	Read.SetString(XMLString);
	XDTOAddress = XDTOFactory.ReadXML(Read, XDTOFactory.Type(Namespace, "ContactInformation"));
	AddressUS = ContactInformationInternal.HomeCountryAddress(XDTOAddress.Content);
	If AddressUS = Undefined Then
		Raise NStr("en = 'Cannot determine the address by document, expecting a domestic address'");
	EndIf;
	
	If NewValue <> Undefined Then
		AddressUS.Address_to_document = NewValue;
		XMLString = ContactInformationInternal.ContactInformationSerialization(XDTOAddress);
	EndIf;
	
	Return String(AddressUS.Address_to_document);
EndFunction

// Returns the address country information.
// If the passed string does not contain address information, raises an exception.
//
// Parameters:
//    XMLString - String - contact information XML string.
//
// Returns:
//    Structure - address country description. Contains the following fields:
//        * Ref             - CatalogRef.WorldCountries, Undefined - world country item. 
//        * Description     - String - a part of country description. 
//        * Code            - String - a part of country description. 
//        * LongDescription - String - a part of country description. 
//        * AlphaCode2      - String - a part of country description. 
//        * AlphaCode3      - String - a part of country description.
//
// If an empty string is passed, returns an empty structure.
// If the country is found in the classifier but not found in the country catalog, 
// the Ref field of the resulting structure is not filled. 
// If the country is found neither in the classifier nor in the country catalog, 
// only the Description field is filled.
//
Function ContactInformationAddressCountry(Val XMLString) Export
	
	Result = New Structure("Ref, Code, Description, LongDescription, AlphaCode2, AlphaCode3");
	If IsBlankString(XMLString) Then
		Return Result;
	EndIf;
	
	// Reading the country description
	Namespace = ContactInformationClientServerCached.Namespace();
	Read = New XMLReader;
	Read.SetString(XMLString);
	XDTOAddress = XDTOFactory.ReadXML(Read, XDTOFactory.Type(Namespace, "ContactInformation"));
	Address = XDTOAddress.Content;
	If Address = Undefined Or Address.Type() <> XDTOFactory.Type(Namespace, "Address") Then
		Raise NStr("en = 'Cannot determine country, expecting an address.'");
	EndIf;
	
	Result.Description = TrimAll(Address.Country);
	CountryData = Catalogs.WorldCountries.WorldCountryData(, Result.Description);
	Return ?(CountryData = Undefined, Result, CountryData);
EndFunction

// Returns address state name or an empty string (if the state is undefined). 
// If the passed string does not contain address information, raises an exception.
//
// Parameters:
//    XMLString - String - contact information XML string.
//
// Returns:
//    String - name.
//
Function ContactInformationAddressState(Val XMLString) Export
	If IsBlankString(XMLString) Then
		Return "";
	EndIf;
	
	Namespace = ContactInformationClientServerCached.Namespace();
	Read = New XMLReader;
	Read.SetString(XMLString);
	XDTOAddress = XDTOFactory.ReadXML(Read, XDTOFactory.Type(Namespace, "ContactInformation"));
	Address = XDTOAddress.Content;
	If Address = Undefined Or Address.Type() <> XDTOFactory.Type(Namespace, "Address") Then
		Raise NStr("en = 'Cannot determine state, expecting an address.'");
	EndIf;
	
	AddressUS = ContactInformationInternal.HomeCountryAddress(Address);
	Return ?(AddressUS = Undefined, "", TrimAll(AddressUS.Region));
EndFunction

// Returns address city name or an empty string (for foreign addresses).
// If the passed string does not contain address information, raises an exception.
//
// Parameters:
//    XMLString - String - contact information XML string.
//
// Returns:
//    String - name.
//
Function ContactInformationAddressCity(Val XMLString) Export
	If IsBlankString(XMLString) Then
		Return "";
	EndIf;
	
	Namespace = ContactInformationClientServerCached.Namespace();
	Read = New XMLReader;
	Read.SetString(XMLString);
	XDTOAddress = XDTOFactory.ReadXML(Read, XDTOFactory.Type(Namespace, "ContactInformation"));
	Address = XDTOAddress.Content;
	If Address = Undefined Or Address.Type() <> XDTOFactory.Type(Namespace, "Address") Then
		Raise NStr("en = 'Cannot determine city, expecting an address.'");
	EndIf;
	
	AddressUS = ContactInformationInternal.HomeCountryAddress(Address);
	Return ?(AddressUS = Undefined, "", TrimAll(AddressUS.City));
EndFunction

// Returns a network address domain for URLs or email addresses.
//
// Parameters:
//    XMLString - String - contact information XML string.
//
// Returns:
//    String - network address domain.
//
Function ContactInformationAddressDomain(Val XMLString) Export
	If IsBlankString(XMLString) Then
		Return "";
	EndIf;
	
	Namespace = ContactInformationClientServerCached.Namespace();
	Read = New XMLReader;
	Read.SetString(XMLString);
	XDTOAddress = XDTOFactory.ReadXML(Read, XDTOFactory.Type(Namespace, "ContactInformation"));
	Content = XDTOAddress.Content;
	If Content <> Undefined Then
		Type = Content.Type();
		If Type = XDTOFactory.Type(Namespace, "Website") Then
			AddressDomain = TrimAll(Content.Value);
			Position = Find(AddressDomain, "://");
			If Position > 0 Then
				AddressDomain = Mid(AddressDomain, Position + 3);
			EndIf;
			Position = Find(AddressDomain, "/");
			Return ?(Position = 0, AddressDomain, Left(AddressDomain, Position - 1));
			
		ElsIf Type = XDTOFactory.Type(Namespace, "Email") Then
			AddressDomain = TrimAll(Content.Value);
			Position = Find(AddressDomain, "@");
			Return ?(Position = 0, AddressDomain, Mid(AddressDomain, Position + 1));
			
		EndIf;
	EndIf;
	
	Raise NStr("en = 'Cannot determine domain, expecting an email address or URL.'");	
EndFunction

// Returns a string containing a phone number without country code or extension.
//
// Parameters:
//    XMLString - String - contact information XML string.
//
// Returns:
//    String - phone number.
//
Function ContactInformationPhoneNumber(Val XMLString) Export
	If IsBlankString(XMLString) Then
		Return "";
	EndIf;
	
	Namespace = ContactInformationClientServerCached.Namespace();
	Read = New XMLReader;
	Read.SetString(XMLString);
	XDTOAddress = XDTOFactory.ReadXML(Read, XDTOFactory.Type(Namespace, "ContactInformation"));
	Content = XDTOAddress.Content;
	If Content <> Undefined Then
		Type = Content.Type();
		If Type = XDTOFactory.Type(Namespace, "PhoneNumber") Then
			Return TrimAll(Content.Number);
			
		ElsIf Type = XDTOFactory.Type(Namespace, "FaxNumber") Then
			Return TrimAll(Content.Number);
			
		EndIf;
	EndIf;
	
	Raise NStr("en = 'Cannot determine number, expecting a phone or fax number.'");
EndFunction

// Compares two sets of contact information.
//
// Parameters:
//    Data1 - XTDOObject - object containing contact information.
//          - String     - contact information in XML format.
//          - Structure  - contact information description. The following fields are expected:
//                 * FieldValues  - String, Structure, ValueList, Map - contact information fields.
//                 * Presentation - String  - Presentation. Used when presentation cannot be extracted 
//                                           from FieldValues (the Presentation field is not available).
//                 * Comment      - String  - comment. Used when comment cannot be extracted from FieldValues.
//                 * ContactInformationKind - CatalogRef.ContactInformationKinds,
//                                            EnumRef.ContactInformationTypes, Structure.
//                                            Used when type cannot be extracted from FieldValues.
//    Data2 - XTDOObject, String, Structure - similar to Data1.
//
// Returns:
//     ValueTable - table of differing fields, with the following columns:
//        * Path    - String - XPath identifying the value difference. ContactInformationType value
//                             specifies that the passed contact information sets have different types.
//        * Details - String - description of the differing attribute in terms of application business logic.
//        * Value1  - String - value matching the object passed in Data1 parameter.
//        * Value2  - String - value matching the object passed in Data2 parameter.
//
Function ContactInformationDifferences(Val Data1, Val Data2) Export
	Return ContactInformationXML.ContactInformationDifferences(Data1, Data2);
EndFunction

//  Transforms data from the new contact information XML format to the old format.
//
//  Parameters:
//      Data            - String  - contact information XML string. 
//      OldFieldContent - Boolean - optional flag specifying whether fields not available in SL versions 
//                                  earlier than 2.1.3 should be excluded from the field content.
//
//  Returns:
//      String - set of key-value pairs separated by line breaks.
//
Function PreviousContactInformationXMLFormat(Val Data, Val OldFieldContent = False) Export
	
	If ContactInformationClientServer.IsXMLContactInformation(Data) Then
		OldFormat = ContactInformationInternal.ContactInformationToOldStructure(Data, OldFieldContent);
		Return ContactInformationManagementClientServer.ConvertFieldListToString(
			OldFormat.FieldValues, False);
	EndIf;
	
	Return Data;
EndFunction

//  Transforms data from the new contact information XML format to the old format structure.
//
//  Parameters:
//      Data                   - String - contact information XML string, or a set of key-value pairs.
//      ContactInformationKind - CatalogRef.ContactInformationKinds, Structure - description of contact information parameters.
//
//  Returns:
//      Structure - set of key-value pairs.
//
Function PreviousContactInformationXMLStructure(Val Data, Val ContactInformationKind = Undefined) Export
	
	If ContactInformationClientServer.IsXMLContactInformation(Data) Then
		// New contact information format
		Return ContactInformationManagementClientServer.FieldValueStructure(
			PreviousContactInformationXMLFormat(Data));
		
	ElsIf IsBlankString(Data) And ContactInformationKind <> Undefined Then
		// Generating contact information by kind
		Return ContactInformationManagementClientServer.ContactInformationStructureByType(
			ContactInformationKind.Type);
		
	EndIf;
	
	// Returning full structure for the selected kind, with filled fields
	Return ContactInformationManagementClientServer.FieldValueStructure(Data, ContactInformationKind);
EndFunction

////////////////////////////////////////////////////////////////////////////////////////////////////

// Looks up country data in country catalog or world country classifier.
//
// Parameters:
//    CountryCode - String, Number - country code by country classifier. 
//                                   If not specified, search by code is not performed.
//    Description - String         - country description. If not specified, search by description is not performed.
//
// Returns:
//    Structure - country description. Contains the following fields:
//        * Ref             - CatalogRef.WorldCountries, Undefined - world country item. 
//        * Description     - String - a part of country description.
//        * Code            - String - a part of country description.
//        * LongDescription - String - a part of country description.
//        * AlphaCode2      - String - a part of country description.
//        * AlphaCode3      - String - a part of country description.
//    Undefined - the country is found neither in the catalog nor in the classifier.
//
Function WorldCountryData(Val CountryCode = Undefined, Val Description = Undefined) Export
	Return Catalogs.WorldCountries.WorldCountryData(CountryCode, Description);
EndFunction

// Determines country data using country classifier.
//
// Parameters:
//    CountryCode - String, Number - country code.
//
// Returns:
//    Structure - country description. Contains the following fields:
//        * Description     - String - a part of country description.
//        * Code            - String - a part of country description.
//        * LongDescription - String - a part of country description.
//        * AlphaCode2      - String - a part of country description.
//        * AlphaCode3      - String - a part of country description.
//    Undefined - the country is not found in the classifier.
//
Function WorldCountryClassifierDataByCode(Val CountryCode) Export
	Return Catalogs.WorldCountries.WorldCountryClassifierDataByCode(CountryCode);
EndFunction

// Determines country data using country classifier.
//
// Parameters:
//    Description - String - country description.
//
// Returns:
//    Structure - country description. Contains the following fields:
//        * Description     - String - a part of country description.
//        * Code            - String - a part of country description.
//        * LongDescription - String - a part of country description.
//        * AlphaCode2      - String - a part of country description.
//        * AlphaCode3      - String - a part of country description.
//    Undefined - the country is not found in the classifier.
//
Function WorldCountryClassifierDataByDescription(Val Description) Export
	Return Catalogs.WorldCountries.WorldCountryClassifierDataByDescription(Description);
EndFunction

////////////////////////////////////////////////////////////////////////////////////////////////////

// Obsolete. Use ObjectContactInformation instead.
//
Function GetObjectContactInformation(Ref, ContactInformationKind) Export
	Return ObjectContactInformation(Ref, ContactInformationKind);
EndFunction

// Gets a value of a specified contact information kind from an object.
//
// Parameters
//     Ref                    - AnyRef - reference to the contact information owner object 
//                              (company, counterparty, partner, and so on). 
//     ContactInformationKind - CatalogRef.ContactInformationKinds - contact information kind to be processed.
//
// Returns:
//     String - value represented as a string.
//
Function ObjectContactInformation(Ref, ContactInformationKind) Export
	
	ObjectArray = New Array;
	ObjectArray.Add(Ref);
	
	ObjectContactInformation = ObjectsContactInformation(ObjectArray,, ContactInformationKind);
	
	If ObjectContactInformation.Count() > 0 Then
		Return ObjectContactInformation[0].Presentation;
	EndIf;
	
	Return "";
	
EndFunction

//  Gets all values for a specified contact information kind from the owner object.
//
//  Parameters:
//     Ref                    - AnyRef - reference to the contact information owner object 
//                                      (company, counterparty, partner, and so on). 
//     ContactInformationKind - CatalogRef.ContactInformationKinds - contact information kind to be processed.
//
//  Returns:
//      Value table, with the following columns: 
//          * LineNumber     - Number    - row number of the additional tabular section of the owner object.
//          * Presentation   - String    - contact information presentation entered by user. 
//          * FieldStructure - Structure - key-value information pairs.
//
Function ObjectContactInformationTable(Ref, ContactInformationKind) Export
	
	Query = New Query(StringFunctionsClientServer.SubstituteParametersInString("
		|SELECT 
		|	Data.TabularSectionRowID AS LineNumber,
		|	Data.Presentation                    AS Presentation,
		|	Data.FieldValues                     AS FieldValues
		|FROM
		|	%1.ContactInformation AS Data
		|WHERE
		|	Data.Ref = &Ref
		|	AND Data.Kind = &Kind
		|ORDER BY
		|	Data.TabularSectionRowID
		|", Ref.Metadata().FullName()));
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("Kind", ContactInformationKind);
	
	Result = New ValueTable;
	Result.Columns.Add("LineNumber");
	Result.Columns.Add("Presentation");
	Result.Columns.Add("FieldStructure");
	Result.Indexes.Add("LineNumber");
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		DataRow = Result.Add();
		FillPropertyValues(DataRow, Selection, "LineNumber, Presentation");
		DataRow.FieldStructure = ContactInformationInternal.PreviousContactInformationXMLStructure(
			Selection.FieldValues, ContactInformationKind);
	EndDo;
	
	Return  Result;
EndFunction

// Creates a temporary table containing contact information for multiple objects
//
// Parameters:
//    TempTablesManager       - TempTablesManager - for generation purposes. 
//    ObjectArray             - Array - contact information owners (all items must have the same type). 
//    ContactInformationTypes - Array - optional, used if some of the types are undefined.
//    ContactInformationKinds - Array -  optional, used if some of the kinds are undefined.
//
// ContactInformationTemporaryTable is created in the temporary table manager. The table contains the following fields:
//    * Object       - Ref - contact information owner.
//    * Kind         - CatalogRef.ContactInformationKinds.
//    * Type         - EnumRef.ContactInformationTypes.
//    * FieldValues  - String - field value data. 
//    * Presentation - String - contact information presentation.
//
Procedure CreateContactInformationTemporaryTable(TempTablesManager, ObjectArray, ContactInfoTypes = Undefined, CIKinds = Undefined) Export
	
	If TypeOf(ObjectArray) = Type("Array") And ObjectArray.Count() > 0 Then
		Ref = ObjectArray.Get(0);
	Else
		Raise NStr("en = 'Invalid value in the contact information owner data array.'");
	EndIf;
	
	Query = New Query("
		|SELECT ALLOWED
		|	ContactInformation.Ref  AS Object,
		|	ContactInformation.Kind AS Kind,
		|	ContactInformation.Type AS Type,
		|	ContactInformation.FieldValues AS FieldValues,
		|	ContactInformation.Presentation AS Presentation
		|INTO ContactInformationTemporaryTable
		|FROM
		|	" + Ref.Metadata().FullName() + ".ContactInformation
		|AS
		|ContactInformation WHERE ContactInformation.Ref IN (&ObjectArray)
		|	" + ?(ContactInfoTypes = Undefined, "", "AND ContactInformation.Type IN (&ContactInfoTypes)") + "
		|	" + ?(CIKinds = Undefined, "", "AND ContactInformation.Kind IN (&CIKinds)") + "
		|");
	
	Query.TempTablesManager = TempTablesManager;
	
	Query.SetParameter("ObjectArray", ObjectArray);
	Query.SetParameter("ContactInfoTypes", ContactInfoTypes);
	Query.SetParameter("CIKinds", CIKinds);
	
	Query.Execute();
EndProcedure

// Gets contact information for multiple objects.
//
// Parameters:
//    ObjectArray             - Array - contact information owners (all items must have the same type).
//    ContactInformationTypes - Array - optional, used if some of the types are undefined. 
//    ContactInformationKinds - Array - optional, used if some of the kinds are undefined.
//
// Returns
//    Value table - result. Columns:
//        * Object       - Ref - contact information owner.
//        * Kind         - CatalogRef.ContactInformationKinds.
//        * Type         - EnumRef.ContactInformationTypes.
//        * FieldValues  - String - field value data.
//        * Presentation - String - contact information presentation.
//
Function ObjectsContactInformation(ObjectArray, ContactInfoTypes = Undefined, CIKinds = Undefined) Export
	
	Query = New Query;
	Query.TempTablesManager = New TempTablesManager;
	
	CreateContactInformationTemporaryTable(Query.TempTablesManager, ObjectArray, ContactInfoTypes, CIKinds);
	
	Query.Text =
	"SELECT
	|	ContactInformation.Object AS Object,
	|	ContactInformation.Kind   AS Kind,
	|	ContactInformation.Type   AS Type,
	|	ContactInformation.FieldValues  AS FieldValues,
	|	ContactInformation.Presentation AS Presentation
	|FROM
	|	ContactInformationTemporaryTable AS ContactInformation";
	
	Return Query.Execute().Unload();
	
EndFunction

// Fills in contact information for multiple objects.
//
// Parameters:
//    FillingData - ValueTable - describes objects to be filled in. Contains the following columns:
//        * Target      - Arbitrary - reference or object whose contact information must be filled in.
//        * CIKind      - CatalogRef.ContactInformationKinds  - contact information kind filled in the target.
//        * CIStructure - ValueList, String, Structure - contact information field value data.
//        * RowKey      - Structure - filter used to search the tabular section for a row
//                        where Key is the name of a tabular section column, and Value is the filter value.
//
Procedure FillObjectsContactInformation(FillingData) Export
	
	PreviousTarget = Undefined;
	FillingData.Sort("Target, CIKind");
	
	For Each FillString In FillingData Do
		
		Target = FillString.Target;
		If CommonUse.IsReference(TypeOf(Target)) Then
			Target = Target.GetObject();
		EndIf;
		
		If PreviousTarget <> Undefined And PreviousTarget <> Target Then
			If PreviousTarget.Ref = Target.Ref Then
				Target = PreviousTarget;
			Else
				PreviousTarget.Write();
			EndIf;
		EndIf;
		
		CIKind = FillString.CIKind;
		TargetObjectName = Target.Metadata().Name;
		TabularSectionName = TabularSectionNameByCIKind(CIKind, TargetObjectName);
		
		If IsBlankString(TabularSectionName) Then
			FillTabularSectionContactInformation(Target, CIKind, FillString.CIStructure);
		Else
			If TypeOf(FillString.RowKey) <> Type("Structure") Then
				Continue;
			EndIf;
			
			If FillString.RowKey.Property("LineNumber") Then
				TabularSectionLineCount = Target[TabularSectionName].Count();
				LineNumber = FillString.RowKey.LineNumber;
				If LineNumber > 0 And LineNumber <= TabularSectionLineCount Then
					TabularSectionRow = Target[TabularSectionName][LineNumber - 1];
					FillTabularSectionContactInformation(Target, CIKind, FillString.CIStructure, TabularSectionRow);
				EndIf;
			Else
				TabularSectionRows = Target[TabularSectionName].FindRows(FillString.RowKey);
				For Each TabularSectionRow In TabularSectionRows Do
					FillTabularSectionContactInformation(Target, CIKind, FillString.CIStructure, TabularSectionRow);
				EndDo;
			EndIf;
		EndIf;
		
		PreviousTarget = Target;
		
	EndDo;
	
	If PreviousTarget <> Undefined Then
		PreviousTarget.Write();
	EndIf;
	
EndProcedure

// Fills in contact information for a single object.
//
// Parameters:
//    Target      - Arbitrary - reference or object whose contact information must be filled in.
//    CIKind      - CatalogRef.ContactInformationKinds - contact information kind filled in the target.
//    CIStructure - Structure - filled contact information structure.
//    RowKey      - Structure - filter used to search the tabular section for a row
//                              where Key is the name of a tabular section column, and Value is filter value.
//
Procedure FillObjectContactInformation(Target, CIKind, CIStructure, RowKey = Undefined) Export
	
	FillingData = New ValueTable;
	FillingData.Columns.Add("Target");
	FillingData.Columns.Add("CIKind");
	FillingData.Columns.Add("CIStructure");
	FillingData.Columns.Add("RowKey");
	
	FillString = FillingData.Add();
	FillString.Target = Target;
	FillString.CIKind = CIKind;
	FillString.CIStructure = CIStructure;
	FillString.RowKey = RowKey;
	
	FillObjectsContactInformation(FillingData);
	
EndProcedure

#EndRegion

#Region InternalInterface

// See the description of this procedure in the StandardSubsystemsServer module.
Procedure InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers) Export
	
	// SERVER HANDLERS
	
	ServerHandlers[
		"StandardSubsystems.InfobaseVersionUpdate\OnAddUpdateHandlers"
	].Add("ContactInformationManagement");
	
EndProcedure

//  Returns enumeration value of contact information kind type.
//
//  Parameters:
//    InformationKind - CatalogRef.ContactInformationKinds, Structure - data source.
//
Function ContactInformationKindType(Val InformationKind) Export
	Result = Undefined;
	
	Type = TypeOf(InformationKind);
	If Type = Type("EnumRef.ContactInformationTypes") Then
		Result = InformationKind;
	ElsIf Type = Type("CatalogRef.ContactInformationKinds") Then
		Result = InformationKind.Type;
	ElsIf InformationKind <> Undefined Then
		Data = New Structure("Type");
		FillPropertyValues(Data, InformationKind);
		Result = Data.Type;
	EndIf;
	
	Return Result;
EndFunction

#EndRegion

#Region InternalProceduresAndFunctions

// Filling event subscription handler.
//
Procedure FillContactInformationProcessing(Source, FillingData, FillingText, StandardProcessing) Export
	
	ObjectContactInformationFilling(Source, FillingData);
	
EndProcedure

// Filling event subscription handler for documents.
//
Procedure DocumentContactInformationFilling(Source, FillingData, StandardProcessing) Export
	
	ObjectContactInformationFilling(Source, FillingData);
	
EndProcedure

Procedure ObjectContactInformationFilling(Object, Val FillingData)
	
	If TypeOf(FillingData) <> Type("Structure") Then
		Return;
	EndIf;
	
	// Description, if available in the target object
	Description = Undefined;
	If FillingData.Property("Description", Description) 
		And HasObjectAttribute("Description", Object) 
	Then
		Object.Description = Description;
	EndIf;
	
	// Contact information table. It is only filled if the contact information cannot be found in any other tabular section.
	ContactInformation = Undefined;
	If FillingData.Property("ContactInformation", ContactInformation) 
		And HasObjectAttribute("ContactInformation", Object) 
	Then
	
		If TypeOf(ContactInformation) = Type("ValueTable") Then
			TableColumns = ContactInformation.Columns;
		Else
			TableColumns = ContactInformation.UnloadColumns().Columns;
		EndIf;
		
		If TableColumns.Find("TabularSectionRowID") = Undefined Then
			
			For Each CIRow In ContactInformation Do
				NewCIRow = Object.ContactInformation.Add();
				FillPropertyValues(NewCIRow, CIRow, , "FieldValues");
				NewCIRow.FieldValues = ContactInformationToXML(CIRow.FieldValues, CIRow.Presentation, CIRow.Kind);
			EndDo;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Checks the form for strings filled with contact information of the same kind (excluding the current string).
//
Function HasOtherStringsFilledWithThisContactInformationKind(Val Form, Val StringToValidate, Val ContactInformationKind)
	
	AllRowsOfThisKind = Form.ContactInformationAdditionalAttributeInfo.FindRows(
		New Structure("Kind", ContactInformationKind)
	);
	
	For Each RowOfThisKind In AllRowsOfThisKind Do
		
		If RowOfThisKind <> StringToValidate Then
			Presentation = Form[RowOfThisKind.AttributeName];
			If Not IsBlankString(Presentation) Then 
				Return True;
			EndIf;
		EndIf;
		
	EndDo;
	
	Return False;
EndFunction

// Checks whether an object has an attribute with the specified name.
//
// Parameters:
//     AttributeName - String    - name of the attribute to be checked.
//     Object        - Arbitrary - object to be checked.
//
// Returns:
//     Boolean - check result.
//
Function HasObjectAttribute(Val AttributeName, Val Object)
	AttributeCheck = New Structure(AttributeName, Undefined);
	FillPropertyValues(AttributeCheck, Object);
	If AttributeCheck[AttributeName] <> Undefined Then
		Return True;
	EndIf;
	
	AttributeCheck[AttributeName] = "";
	FillPropertyValues(AttributeCheck, Object);
	Return AttributeCheck.Description = Undefined;
EndFunction

// Updates contact information fields based on ValueTable of an object of different kind (such as catalog).
//
// Parameters:
//    Source - ValueTable  - value table containing contact information.
//    Target - ManagedForm - object form used to receive the contact information.
//
Procedure FillContactInformation(Source, Target) Export
	ContactInformationFieldCollection = Target.ContactInformationAdditionalAttributeInfo;
	
	For Each ContactInformationFieldCollectionItem In ContactInformationFieldCollection Do
		
		RowInCI = Source.Find(ContactInformationFieldCollectionItem.Kind, "Kind");
		If RowInCI <> Undefined Then
			Target[ContactInformationFieldCollectionItem.AttributeName] = RowInCI.Presentation;
			ContactInformationFieldCollectionItem.FieldValues          = ContactInformationManagementClientServer.ConvertStringToFieldList(RowInCI.FieldValues);
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure AddItemDetails(Form, ItemName, Priority, IsCommand = False, IsTabularSectionAttribute = False)
	
	NewRow = Form.AddedContactInformationItems.Add();
	NewRow.ItemName = ItemName;
	NewRow.Priority = Priority;
	NewRow.IsCommand = IsCommand;
	NewRow.IsTabularSectionAttribute = IsTabularSectionAttribute;
	
EndProcedure

Procedure DeleteItemDescription(Form, ItemName)
	
	AddedItems = Form.AddedContactInformationItems;
	Filter = New Structure("ItemName", ItemName);
	FoundRow = AddedItems.FindRows(Filter)[0];
	AddedItems.Delete(FoundRow);
	
EndProcedure

Function TitleLeft(Form, Val TitleLocationContactInformation = Undefined)
	
	If Not ValueIsFilled(TitleLocationContactInformation) Then
		
		SavedTitlePosition = Form.ContactInformationTitleLocation;
		If ValueIsFilled(SavedTitlePosition) Then
			TitleLocationContactInformation = FormItemTitleLocation[SavedTitlePosition];
		Else
			TitleLocationContactInformation = FormItemTitleLocation.Top;
		EndIf;
		
	EndIf;
	
	Return (TitleLocationContactInformation = FormItemTitleLocation.Left);
	
EndFunction

Procedure ModifyComment(Form, AttributeName, IsAddComment)
	
	ContactInformationDescription = Form.ContactInformationAdditionalAttributeInfo;
	
	Filter = New Structure("AttributeName", AttributeName);
	FoundRow = ContactInformationDescription.FindRows(Filter)[0];
	
	// Title and input field
	ItemTitle = Form.Items.Find("Title" + AttributeName);
	CommentName = "Comment" + AttributeName;
	
	TitleLeft = TitleLeft(Form);
	
	If IsAddComment Then
		
		TextBox = Form.Items.Find(AttributeName);
		InputFieldGroup = Form.Items.ContactInformationInputFieldGroup;
		
		CurrentItem = ?(InputFieldGroup.ChildItems.Find(TextBox.Name) = Undefined, TextBox.Parent, TextBox);
		CurrentItemIndex = InputFieldGroup.ChildItems.IndexOf(CurrentItem);
		NextItem = InputFieldGroup.ChildItems.Get(CurrentItemIndex + 1);
		
		Comment = Comment(Form, FoundRow.Comment, CommentName, InputFieldGroup);
		Form.Items.Move(Comment, InputFieldGroup, NextItem);
		
		If TitleLeft Then
			
			HeaderGroup = Form.Items.ContactInformationTitleGroup;
			TitleIndex = HeaderGroup.ChildItems.IndexOf(ItemTitle);
			NextTitle = HeaderGroup.ChildItems.Get(TitleIndex + 1);
			
			PlaceholderName = "TitlePlaceholder" + AttributeName;
			Placeholder = Form.Items.Add(PlaceholderName, Type("FormDecoration"), HeaderGroup);
			Form.Items.Move(Placeholder, HeaderGroup, NextTitle);
			AddItemDetails(Form, PlaceholderName, 2);
			
		EndIf;
		
	Else
		
		Comment = Form.Items[CommentName];
		Form.Items.Delete(Comment);
		DeleteItemDescription(Form, CommentName);
		
		If TitleLeft Then
			
			ItemTitle.Height = 1;
			
			PlaceholderName = "TitlePlaceholder" + AttributeName;
			TitlePlaceholder = Form.Items[PlaceholderName];
			Form.Items.Delete(TitlePlaceholder);
			DeleteItemDescription(Form, PlaceholderName);
			
		EndIf;
		
	EndIf;
	
	// Action
	ActionGroup = Form.Items.ContactInformationActionGroup;
	ActionPlaceholderName = "ActionPlaceholder" + AttributeName;
	ActionPlaceholder = Form.Items.Find(ActionPlaceholderName);
	
	If IsAddComment Then
		
		If ActionPlaceholder = Undefined Then
			
			ActionPlaceholder = Form.Items.Add(ActionPlaceholderName, Type("FormDecoration"), ActionGroup);
			ActionPlaceholder.Height = 1;
			Action = Form.Items["Command" + AttributeName];
			CommandIndex = ActionGroup.ChildItems.IndexOf(Action);
			NextItem = ActionGroup.ChildItems.Get(CommandIndex + 1);
			If ActionPlaceholder <> NextItem Then
				Form.Items.Move(ActionPlaceholder, ActionGroup, NextItem);
			EndIf;
			AddItemDetails(Form, ActionPlaceholderName, 2);
			
		Else
			
			ActionPlaceholder.Height = 2;
			
		EndIf;
		
	Else
		
		If ActionPlaceholder.Height = 1 Then
			
			Form.Items.Delete(ActionPlaceholder);
			DeleteItemDescription(Form, ActionPlaceholderName);
			
		Else
			
			ActionPlaceholder.Height = 1;
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure AddContactInformationString(Form, Result)
	
	AddedKind = Result.AddedKind;
	If TypeOf(AddedKind)= Type("CatalogRef.ContactInformationKinds") Then
		CIKindInformation = CommonUse.ObjectAttributeValues(AddedKind, "Type, Description, EditInDialogOnly, Tooltip");
	Else
		CIKindInformation = AddedKind;
		AddedKind    = AddedKind.Ref;
	EndIf;
	
	ContactInformationTable = Form.ContactInformationAdditionalAttributeInfo;
	
	Filter = New Structure("Kind", AddedKind);
	FoundRows = ContactInformationTable.FindRows(Filter);
	ItemCount = FoundRows.Count();
	
	LastRow = FoundRows.Get(ItemCount-1);
	AddedRowIndex = ContactInformationTable.IndexOf(LastRow) + 1;
	IsLastRow = False;
	If AddedRowIndex = ContactInformationTable.Count() Then
		IsLastRow = True;
	Else
		NextAttributeName = ContactInformationTable[AddedRowIndex].AttributeName;
	EndIf;
	
	NewRow = ContactInformationTable.Insert(AddedRowIndex);
	AttributeName = "ContactInformationField" + NewRow.GetID();
	NewRow.AttributeName = AttributeName;
	NewRow.Kind = AddedKind;
	NewRow.Type = CIKindInformation.Type;
	NewRow.IsTabularSectionAttribute = False;
	
	AttributesToAddArray = New Array;
	AttributesToAddArray.Add(New FormAttribute(AttributeName, New TypeDescription("String", , New StringQualifiers(500)), , CIKindInformation.Description, True));
	
	Form.ChangeAttributes(AttributesToAddArray);
	
	TitleLeft = TitleLeft(Form);
	
	//Displaying form items
	If TitleLeft Then
		HeaderGroup = Form.Items.ContactInformationTitleGroup;
		Title = ItemTitle(Form, CIKindInformation.Type, AttributeName, HeaderGroup, CIKindInformation.Description);
		
		If Not IsLastRow Then
			NextTitle = Form.Items["Title" + NextAttributeName];
			Form.Items.Move(Title, HeaderGroup, NextTitle);
		EndIf;
	EndIf;
	
	InputFieldGroup = Form.Items.ContactInformationInputFieldGroup;
	TextBox = TextBox(Form, CIKindInformation.EditInDialogOnly, CIKindInformation.Type, AttributeName, CIKindInformation.ToolTip);
	
	If Not IsLastRow Then
		
		NextItemName = LastRow.AttributeName;
		
		If ValueIsFilled(LastRow.Comment) Then
			NextItemName = "Comment" + NextItemName;
		EndIf;
		
		NextItemIndex = InputFieldGroup.ChildItems.IndexOf(Form.Items[NextItemName]) + 1;
		NextItem = InputFieldGroup.ChildItems.Get(NextItemIndex);
		
		Form.Items.Move(TextBox, InputFieldGroup, NextItem);
		
	EndIf;
	
	ActionGroup = Form.Items.ContactInformationActionGroup;
	Filter = New Structure("Type", Enums.ContactInformationTypes.Address);
	AddressCount = ContactInformationTable.FindRows(Filter).Count();
	
	ActionName = "Command" + NextAttributeName;
	PlaceholderName = "DecorationTop" + NextAttributeName;
	
	If Form.Items.Find(PlaceholderName) <> Undefined Then
		NextActionName = PlaceholderName;
	ElsIf Form.Items.Find(ActionName) <> Undefined Then
		NextActionName = ActionName;
	Else
		NextActionName = "ActionPlaceholder" + NextAttributeName;
	EndIf;
	
	Action = Action(Form, CIKindInformation.Type, AttributeName, ActionGroup, AddressCount);
	If Not IsLastRow Then
		NextAction = Form.Items[NextActionName];
		Form.Items.Move(Action, ActionGroup, NextAction);
	EndIf;
	
	Form.CurrentItem = Form.Items[AttributeName];
	
	If CIKindInformation.Type = Enums.ContactInformationTypes.Address
		And CIKindInformation.EditInDialogOnly Then
		
		Result.Insert("AddressFormItem", AttributeName);
		
	EndIf;
	
EndProcedure

Function ItemTitle(Form, Type, AttributeName, HeaderGroup, Description, IsNewCIKind = False, HasComment = False)
	
	TitleName = "Title" + AttributeName;
	Item = Form.Items.Add(TitleName, Type("FormDecoration"), HeaderGroup);
	Item.Title = ?(IsNewCIKind, Description + ":", "");
	
	If Type = Enums.ContactInformationTypes.Other Then
		Item.Height = 5;
		Item.VerticalAlign = ItemVerticalAlign.Top;
	Else
		Item.VerticalAlign = ItemVerticalAlign.Center;
	EndIf;
	
	AddItemDetails(Form, TitleName, 2);
	
	If HasComment Then
		
		PlaceholderName = "TitlePlaceholder" + AttributeName;
		Placeholder = Form.Items.Add(PlaceholderName, Type("FormDecoration"), HeaderGroup);
		AddItemDetails(Form, PlaceholderName, 2);
		
	EndIf;
	
	Return Item;
	
EndFunction

Function TextBox(Form, EditInDialogOnly, Type, AttributeName, ToolTip, IsNewCIKind = False, Mandatory = False)
	
	TitleLeft = TitleLeft(Form);
	
	Item = Form.Items.Add(AttributeName, Type("FormField"), Form.Items.ContactInformationInputFieldGroup);
	Item.Type = FormFieldType.InputField;
	Item.ToolTip = ToolTip;
	Item.DataPath = AttributeName;
	Item.HorizontalStretch = True;
	Item.TitleLocation = ?(TitleLeft Or Not IsNewCIKind, FormItemTitleLocation.None, FormItemTitleLocation.Top);
	Item.SetAction("Clearing", "Attachable_ContactInformationClear");
	
	AddItemDetails(Form, AttributeName, 2);
	
	// Setting input field properties
	If Type = Enums.ContactInformationTypes.Other Then
		Item.Height = 5;
		Item.MultiLine = True;
		Item.VerticalStretch = False;
	Else
		
		// Entering comment via context menu
		CommandName = "ContextMenu" + AttributeName;
		Command = Form.Commands.Add(CommandName);
		Button = Form.Items.Add(CommandName,Type("FormButton"), Item.ContextMenu);
		Command.ToolTip = NStr("en = 'Enter comment'");
		Command.Action = "Attachable_ContactInformationExecuteCommand";
		Button.Title = NStr("en = 'Enter comment'");
		Button.CommandName = CommandName;
		Command.ModifiesStoredData = True;
		
		AddItemDetails(Form, CommandName, 1);
		AddItemDetails(Form, CommandName, 9, True);
	EndIf;
	
	If Mandatory And IsNewCIKind Then
		Item.AutoMarkIncomplete = True;
	EndIf;
	
	// Editing in dialog
	If CanEditContactInformationTypeInDialog(Type) Then
		
		Item.ChoiceButton = True;
		
		If EditInDialogOnly Then
			Item.TextEdit = False;
			Item.BackColor = StyleColors.ContactInformationEditedInDialogColor;
		EndIf;
		Item.SetAction("StartChoice", "Attachable_ContactInformationStartChoice");
		
	EndIf;
	Item.SetAction("OnChange", "Attachable_ContactInformationOnChange");
	
	Return Item;
	
EndFunction

Function Action(Form, Type, AttributeName, ActionGroup, AddressCount, HasComment = False)
	
	If (Type = Enums.ContactInformationTypes.WebPage
		Or Type = Enums.ContactInformationTypes.EmailAddress)
		Or (Type = Enums.ContactInformationTypes.Address And AddressCount > 1) Then
		
		// Action is available
		CommandName = "Command" + AttributeName;
		Command = Form.Commands.Add(CommandName);
		AddItemDetails(Form, CommandName, 9, True);
		Command.Representation = ButtonRepresentation.Picture;
		Command.Action = "Attachable_ContactInformationExecuteCommand";
		
		Item = Form.Items.Add(CommandName,Type("FormButton"), ActionGroup);
		AddItemDetails(Form, CommandName, 2);
		Item.CommandName = CommandName;
		
		If Type = Enums.ContactInformationTypes.Address Then
			
			Item.Title = NStr("en = 'Fill'");
			Command.ToolTip = NStr("en = 'Fill in address'");
			Command.Picture = PictureLib.MoveLeft;
			Command.ModifiesStoredData = True;
			
		ElsIf Type = Enums.ContactInformationTypes.WebPage Then
			
			Item.Title = NStr("en = 'GoTo'");
			Command.ToolTip = NStr("en = 'Go to URL'");
			Command.Picture = PictureLib.ContactInformationGotoURL;
			
		ElsIf Type = Enums.ContactInformationTypes.EmailAddress Then
			
			Item.Title = NStr("en = 'Create email message'");
			Command.ToolTip = NStr("en = 'Create an email message'");
			Command.Picture = PictureLib.SendEmail;
			
		EndIf;
		
		If HasComment Then
			
			ActionPlaceholderName = "ActionPlaceholder" + AttributeName;
			ActionPlaceholder = Form.Items.Add(ActionPlaceholderName, Type("FormDecoration"), ActionGroup);
			ActionPlaceholder.Height = 1;
			AddItemDetails(Form, ActionPlaceholderName, 2);
			
		EndIf;
		
	Else
		
		// Action is not available, using placeholder
		ActionPlaceholderName = "ActionPlaceholder" + AttributeName;
		Item = Form.Items.Add(ActionPlaceholderName, Type("FormDecoration"), ActionGroup);
		AddItemDetails(Form, ActionPlaceholderName, 2);
		If HasComment Then
			Item.Height = 2;
		ElsIf Type = Enums.ContactInformationTypes.Other Then
			Item.Height = 5;
		EndIf;
		
	EndIf;
	
	Return Item;
	
EndFunction

Function Comment(Form, Comment, CommentName, GroupForPlacement)
	
	Item = Form.Items.Add(CommentName, Type("FormDecoration"), GroupForPlacement);
	Item.Title = Comment;
	
	Item.TextColor = StyleColors.InformationText;
	
	Item.HorizontalStretch = True;
	Item.VerticalStretch  = False;
	Item.VerticalAlign  = ItemVerticalAlign.Top;
	
	Item.Height = 1;
	
	AddItemDetails(Form, CommentName, 2);
	
	Return Item;
	
EndFunction

Function Group(GroupName, Form, Parent, Grouping, DeletionOrder)
	
	NewFolder = Form.Items.Add(GroupName, Type("FormGroup"), Parent);
	NewFolder.Type = FormGroupType.UsualGroup;
	NewFolder.ShowTitle = False;
	NewFolder.Representation = UsualGroupRepresentation.None;
	NewFolder.Group = Grouping;
	AddItemDetails(Form, GroupName, DeletionOrder);
	
	Return NewFolder;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// SL event handlers.

////////////////////////////////////////////////////////////////////////////////
// Filling additional attributes of Contact information tabular section.

// Fills the additional attributes of Contact information tabular section for an address.
//
// Parameters:
//    TabularSectionRow - TabularSectionRow - contact information tabular section row to be filled.
//    Source            - XDTODataObject    - contact information.
//
Procedure FillTabularSectionAttributesForAddress(TabularSectionRow, Source)
	
	// Default preferences
	TabularSectionRow.Country = "";
	TabularSectionRow.Region = "";
	TabularSectionRow.City  = "";
	
	Address = Source.Content;
	
	Namespace = ContactInformationClientServerCached.Namespace();
	IsAddress = TypeOf(Address) = Type("XDTODataObject") And Address.Type() = XDTOFactory.Type(Namespace, "Address");
	If IsAddress And Address.Content <> Undefined Then 
		TabularSectionRow.Country = Address.Country;
		AddressUS = ContactInformationInternal.HomeCountryAddress(Address);
		If AddressUS <> Undefined Then
			// Domestic address
			TabularSectionRow.Region = AddressUS.Region;
			TabularSectionRow.City   = AddressUS.City;
		EndIf;
	EndIf;
	
EndProcedure

// Fills the additional attributes of Contact information tabular section for an email address.
//
// Parameters:
//    TabularSectionRow - TabularSectionRow - contact information tabular section row to be filled.
//    Source            - XDTODataObject    - contact information.
//
Procedure FillTabularSectionAttributesForEmailAddress(TabularSectionRow, Source)
	
	Result = CommonUseClientServer.SplitStringWithEmailAddresses(TabularSectionRow.Presentation, False);
	
	If Result.Count() > 0 Then
		TabularSectionRow.EmailAddress = Result[0].Address;
		
		Pos = Find(TabularSectionRow.EmailAddress, "@");
		If Pos <> 0 Then
			TabularSectionRow.ServerDomainName = Mid(TabularSectionRow.EmailAddress, Pos+1);
		EndIf;
	EndIf;
	
EndProcedure

// Fills the additional attributes of Contact information tabular section for phone and fax numbers.
//
// Parameters:
//    TabularSectionRow - TabularSectionRow - contact information tabular section row to be filled.
//    Source            - XDTODataObject    - contact information.
//
Procedure FillTabularSectionAttributesForPhone(TabularSectionRow, Source)
	
	// Default preferences
	TabularSectionRow.PhoneNumberWithoutCodes = "";
	TabularSectionRow.PhoneNumber         = "";
	
	Phone = Source.Content;
	Namespace = ContactInformationClientServerCached.Namespace();
	If Phone <> Undefined And Phone.Type() = XDTOFactory.Type(Namespace, "PhoneNumber") Then
		CountryCode     = Phone.CountryCode;
		AreaCode     = Phone.AreaCode;
		PhoneNumber = Phone.Number;
		
		If Left(CountryCode, 1) = "+" Then
			CountryCode = Mid(CountryCode, 2);
		EndIf;
		
		Pos = Find(PhoneNumber, ",");
		If Pos <> 0 Then
			PhoneNumber = Left(PhoneNumber, Pos-1);
		EndIf;
		
		Pos = Find(PhoneNumber, Chars.LF);
		If Pos <> 0 Then
			PhoneNumber = Left(PhoneNumber, Pos-1);
		EndIf;
		
		TabularSectionRow.PhoneNumberWithoutCodes = RemoveSeparatorsFromPhoneNumber(PhoneNumber);
		TabularSectionRow.PhoneNumber         = RemoveSeparatorsFromPhoneNumber(String(CountryCode) + AreaCode + PhoneNumber);
	EndIf;
	
EndProcedure

// Fills the additional attributes of Contact information tabular section for phone and fax numbers.
//
// Parameters:
//    TabularSectionRow - TabularSectionRow - contact information tabular section row to be filled.
//    Source            - XDTODataObject    - contact information.
//
Procedure FillTabularSectionAttributesForWebPage(TabularSectionRow, Source)
	
	// Default preferences
	TabularSectionRow.ServerDomainName = "";
	
	PageAddress = Source.Content;
	Namespace = ContactInformationClientServerCached.Namespace();
	If PageAddress <> Undefined And PageAddress.Type() = XDTOFactory.Type(Namespace, "Website") Then
		AddressAsString = PageAddress.Value;
		
		// Deleting the protocol
		ServerAddress = Right(AddressAsString, StrLen(AddressAsString) - Find(AddressAsString, "://") );
		Pos = Find(ServerAddress, "/");
		// Deleting the path
		ServerAddress = ?(Pos = 0, ServerAddress, Left(ServerAddress,  Pos-1));
		
		TabularSectionRow.ServerDomainName = ServerAddress;
		
	EndIf;
	
EndProcedure

// Fills the contact information in Contact information tabular section of the target.
//
// Parameters:
//     * Target            - Arbitrary - object whose contact information is to be filled.
//     * CIKind            - CatalogRef.ContactInformationKinds - contact information kind filled in the target.
//     * CIStructure       - ValueList, String, Structure - values of contact information fields.
//     * TabularSectionRow - TabularSectionRow, Undefined - target data if contact information is filled
//                                                          for a row. Undefined if contact information is 
//                                                          filled for the target.
//
Procedure FillTabularSectionContactInformation(Target, CIKind, CIStructure, TabularSectionRow = Undefined)
	
	FilterParameters = New Structure;
	If TabularSectionRow = Undefined Then
		FillingData = Target;
	Else
		FillingData = TabularSectionRow;
		FilterParameters.Insert("TabularSectionRowID", TabularSectionRow.TabularSectionRowID);
	EndIf;
	
	FilterParameters.Insert("Kind", CIKind);
	FoundCIRows  = Target.ContactInformation.FindRows(FilterParameters);
	If FoundCIRows.Count() = 0 Then
		CIRow = Target.ContactInformation.Add();
		If TabularSectionRow <> Undefined Then
			CIRow.TabularSectionRowID = TabularSectionRow.TabularSectionRowID;
		EndIf;
	Else
		CIRow = FoundCIRows[0];
	EndIf;
	
	// Converting from any readable format to XML
	FieldValues = ContactInformationToXML(CIStructure, , CIKind);
	Presentation = ContactInformationPresentation(FieldValues);
	
	CIRow.Type           = CIKind.Type;
	CIRow.Kind           = CIKind;
	CIRow.Presentation = Presentation;
	CIRow.FieldValues = FieldValues;
	
	FillContactInformationAdditionalAttributes(CIRow, Presentation, FieldValues);
EndProcedure

// Validates an email contact information and reports any errors. 
//
// Parameters:
//     Source          - XDTODataObject - contact information.
//     InformationKind - CatalogRef.ContactInformationKinds - contact information kind 
//                                                            with validation settings. 
//     AttributeName   - String - name of the attribute used to link the error message (optional).
//
// Returns:
//     Number - error level (0 - none, 1 - noncritical, 2 - critical).
//
Function EmailFIllingErrors(Source, InformationKind, Val AttributeName = "", AttributeField = "")
	
	If Not InformationKind.CheckValidity Then
		Return 0;
	EndIf;
	
	ErrorString = "";
	
	EmailAddress = Source.Content;
	Namespace = ContactInformationClientServerCached.Namespace();
	If EmailAddress <> Undefined And EmailAddress.Type() = XDTOFactory.Type(Namespace, "Email") Then
		Try
			Result = CommonUseClientServer.SplitStringWithEmailAddresses(EmailAddress.Value);
			If Result.Count() > 1 Then
				
				ErrorString = NStr("en = 'Only one email address is allowed'");
				
			EndIf;
		Except
			ErrorString = BriefErrorDescription(ErrorInfo());
		EndTry;
	EndIf;
	
	If Not IsBlankString(ErrorString) Then
		DisplayUserMessage(ErrorString, AttributeName, AttributeField);
		ErrorLevel = ?(InformationKind.ProhibitInvalidEntry, 2, 1);
	Else
		ErrorLevel = 0;
	EndIf;
	
	Return ErrorLevel;
	
EndFunction

// Validates an address contact information and reports any errors. Returns the error flag.
//
// Parameters:
//     Source          - XDTODataObject - contact information.
//     InformationKind - CatalogRef.ContactInformationKinds - contact information kind 
//                                                            with validation settings.
//     AttributeName   - String - name of the attribute used to link the error message (optional).
//
// Returns:
//     Number - error level (0 - none, 1 - noncritical, 2 - critical).
//
Function AddressFillErrors(Source, InformationKind, AttributeName = "", AttributeField = "")
	If Not InformationKind.CheckValidity Then
		Return 0;
	EndIf;
	HasErrors = False;
	
	Address = Source.Content;
	Namespace = ContactInformationClientServerCached.Namespace();
	If Address <> Undefined And Address.Type() = XDTOFactory.Type(Namespace, "Address") Then
		ErrorList = ContactInformationInternal.AddressFillErrors(Address, InformationKind);
		For Each Item In ErrorList Do
			DisplayUserMessage(Item.Presentation, AttributeName, AttributeField);
			HasErrors = True;
		EndDo;
	EndIf;
	
	If HasErrors And InformationKind.ProhibitInvalidEntry Then
		Return 2;
	ElsIf HasErrors Then
		Return 1;
	EndIf;
	
	Return 0;
EndFunction    

// Validates a phone contact information and reports any errors. Returns the error flag.
//
//     Source          - XDTODataObject - contact information.
//     InformationKind - CatalogRef.ContactInformationKinds - contact information kind
//                                                            with validation settings.
//     AttributeName   - String - name of the attribute used to link the error message (optional).
//
// Returns:
//     Number - error level (0 - none, 1 - noncritical, 2 - critical).
//
Function PhoneFillingErrors(Source, InformationKind, AttributeName = "")
	Return 0;
EndFunction

// Validates a webpage contact information and reports any errors. Returns the error flag.
//
// Parameters:
//     Source          - XDTODataObject - contact information.
//     InformationKind - CatalogRef.ContactInformationKinds - contact information kind
//                                                            with validation settings.
//     AttributeName   - String - name of the attribute used to link the error message (optional).
//
// Returns:
//     Number - error level (0 - none, 1 - noncritical, 2 - critical).
//
Function WebpageFillingErrors(Source, InformationKind, AttributeName = "")
	Return 0;
EndFunction

// Removes separators from a phone number.
//
// Parameters:
//    PhoneNumber - String - phone or fax number.
//
// Returns:
//     String - phone or fax number with separators removed.
//
Function RemoveSeparatorsFromPhoneNumber(Val PhoneNumber)
	
	Pos = Find(PhoneNumber, ",");
	If Pos <> 0 Then
		PhoneNumber = Left(PhoneNumber, Pos-1);
	EndIf;
	
	PhoneNumber = StrReplace(PhoneNumber, "-", "");
	PhoneNumber = StrReplace(PhoneNumber, " ", "");
	PhoneNumber = StrReplace(PhoneNumber, "+", "");
	
	Return PhoneNumber;
	
EndFunction

// Validates contact information and writes it to a value table.
//
Function ValidateContactInformation(Presentation, FieldValues, InformationKind, InformationType,
	AttributeName, Comment = Undefined, AttributePath = "")
	
	SerializationText = ?(IsBlankString(FieldValues), Presentation, FieldValues);
	
	CIObject = ContactInformationInternal.ContactInformationDeserialization(SerializationText, InformationKind);
	If Comment <> Undefined Then
		ContactInformationInternal.ContactInformationComment(CIObject, Comment);
	EndIf;
	
	ContactInformationInternal.ContactInformationPresentation(CIObject, Presentation);
	FieldValues = ContactInformationInternal.ContactInformationSerialization(CIObject);
	
	If IsBlankString(Presentation) And IsBlankString(CIObject.Comment) Then
		Return 0;
	EndIf;
	
	// Checking
	If InformationType = Enums.ContactInformationTypes.EmailAddress Then
		ErrorLevel = EmailFIllingErrors(CIObject, InformationKind, AttributeName, AttributePath);
	ElsIf InformationType = Enums.ContactInformationTypes.Address Then
		ErrorLevel = AddressFillErrors(CIObject, InformationKind, AttributeName);
	ElsIf InformationType = Enums.ContactInformationTypes.Phone Then
		ErrorLevel = PhoneFillingErrors(CIObject, InformationKind, AttributeName);
	ElsIf InformationType = Enums.ContactInformationTypes.Fax Then
		ErrorLevel = PhoneFillingErrors(CIObject, InformationKind, AttributeName);
	ElsIf InformationType = Enums.ContactInformationTypes.WebPage Then
		ErrorLevel = WebpageFillingErrors(CIObject, InformationKind, AttributeName);
	Else
		// No validation is performed for other information types
		ErrorLevel = 0;
	EndIf;
	
	Return ErrorLevel;
	
EndFunction

Procedure WriteContactInformation(Object, FieldValues, InformationKind, InformationType, RowID = 0)
	
	CIObject = ContactInformationInternal.ContactInformationDeserialization(FieldValues, InformationKind);
	
	If Not ContactInformationInternal.XDTOContactInformationFilled(CIObject) Then
		Return;
	EndIf;
	
	NewRow = Object.ContactInformation.Add();
	NewRow.Presentation   = CIObject.Presentation;
	NewRow.FieldValues    = ContactInformationInternal.ContactInformationSerialization(CIObject);
	NewRow.Kind           = InformationKind;
	NewRow.Type           = InformationType;
	
	If ValueIsFilled(RowID) Then
		NewRow.TabularSectionRowID = RowID;
	EndIf;
	
	// Filling additional attributes of the tabular section
	If InformationType = Enums.ContactInformationTypes.EmailAddress Then
		FillTabularSectionAttributesForEmailAddress(NewRow, CIObject);
		
	ElsIf InformationType = Enums.ContactInformationTypes.Address Then
		FillTabularSectionAttributesForAddress(NewRow, CIObject);
		
	ElsIf InformationType = Enums.ContactInformationTypes.Phone Then
		FillTabularSectionAttributesForPhone(NewRow, CIObject);
		
	ElsIf InformationType = Enums.ContactInformationTypes.Fax Then
		FillTabularSectionAttributesForPhone(NewRow, CIObject);
		
	ElsIf InformationType = Enums.ContactInformationTypes.WebPage Then
		FillTabularSectionAttributesForWebPage(NewRow, CIObject);
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Internal procedures.

// Fills the additional attributes of Contact information tabular section row.
//
// Parameters:
//    CIRow        - TabularSectionRow     - contact information row.
//    Presentation - String                - value presentation.
//    FieldValues  - ValueList, XTDOObject - field values.
//
Procedure FillContactInformationAdditionalAttributes(CIRow, Presentation, FieldValues)
	
	If TypeOf(FieldValues) = Type("XDTODataObject") Then
		CIObject = FieldValues;
	Else
		CIObject = ContactInformationInternal.ContactInformationDeserialization(FieldValues, CIRow.Kind);
	EndIf;
	
	InformationType = CIRow.Type;

	If InformationType = Enums.ContactInformationTypes.EmailAddress Then
		FillTabularSectionAttributesForEmailAddress(CIRow, CIObject);
		
	ElsIf InformationType = Enums.ContactInformationTypes.Address Then
		FillTabularSectionAttributesForAddress(CIRow, CIObject);
		
	ElsIf InformationType = Enums.ContactInformationTypes.Phone Then
		FillTabularSectionAttributesForPhone(CIRow, CIObject);
		
	ElsIf InformationType = Enums.ContactInformationTypes.Fax Then
		FillTabularSectionAttributesForPhone(CIRow, CIObject);
		
	ElsIf InformationType = Enums.ContactInformationTypes.WebPage Then
		FillTabularSectionAttributesForWebPage(CIRow, CIObject);
		
	EndIf;
	
EndProcedure

// Returns an empty address structure.
//
// Returns:
//    Structure - address description containing field names (keys) and field values.
//
Function GetEmptyAddressStructure() Export
	
	Return ContactInformationManagementClientServer.AddressFieldStructure();
	
EndFunction

// Returns the flag specifying whether contact information can be edited in a dialog.
//
// Parameters:
//    Type - EnumRef.ContactInformationTypes - contact information type.
//
// Returns:
//    Boolean - dialog information edit flag.
//
Function CanEditContactInformationTypeInDialog(Type)
	
	If Type = Enums.ContactInformationTypes.Address Then
		Return True;
	ElsIf Type = Enums.ContactInformationTypes.Phone Then
		Return True;
	ElsIf Type = Enums.ContactInformationTypes.Fax Then
		Return True;
	Else
		Return False;
	EndIf;
	
EndFunction

// Returns the name of a document tabular section by contact information kind.
//
// Parameters:
//    CIKind     - CatalogRef.ContactInformationKinds - contact information kind.
//    ObjectName - String                             - full name of a metadata object.
//
// Returns:
//    String - tabular section name, or an empty string if the tabular section is not available.
//
Function TabularSectionNameByCIKind(CIKind, ObjectName) Export
	
	CIKindGroup = CommonUse.ObjectAttributeValue(CIKind, "Parent");
	CIKindName = CommonUse.PredefinedName(CIKindGroup);
	Pos = Find(CIKindName, ObjectName);
	
	Return Mid(CIKindName, Pos + StrLen(ObjectName));
	
EndFunction

Procedure SetValidationAttributeValues(Object, ValidationSettings = Undefined)
	
	Object.CheckValidity = ?(ValidationSettings = Undefined, False, ValidationSettings.CheckValidity);
	Object.DomesticAddressOnly = False;
	Object.IncludeCountryInPresentation = False;
	Object.ProhibitInvalidEntry = ?(ValidationSettings = Undefined, False, ValidationSettings.ProhibitInvalidEntry);
	Object.HideObsoleteAddresses = False;
	
EndProcedure

Procedure AddAttributeToDetails(Form, CIRow, IsNewCIKind, IsTabularSectionAttribute = False)
	
	NewRow = Form.ContactInformationAdditionalAttributeInfo.Add();
	NewRow.AttributeName  = CIRow.AttributeName;
	NewRow.Kind           = CIRow.Kind;
	NewRow.Type           = CIRow.Type;
	NewRow.IsTabularSectionAttribute = IsTabularSectionAttribute;
	
	If IsBlankString(CIRow.FieldValues) Then
		NewRow.FieldValues = "";
	Else
		NewRow.FieldValues = ContactInformationManagementClientServer.ConvertStringToFieldList(CIRow.FieldValues);
	EndIf;
	
	NewRow.Presentation = CIRow.Presentation;
	NewRow.Comment      = CIRow.Comment;
	
	If Not IsTabularSectionAttribute Then
		
		Form[CIRow.AttributeName] = CIRow.Presentation;
		
	EndIf;
	
	CIKindStructure = ContactInformationKindStructure(CIRow.Kind);
	CIKindStructure.Insert("Ref", CIRow.Kind);
	
	If IsNewCIKind And CIKindStructure.AllowMultipleValueInput And Not IsTabularSectionAttribute Then
		
		Form.AddedContactInformationItemList.Add(CIKindStructure, CIRow.Kind.Description);
		
	EndIf;
	
EndProcedure

Procedure DeleteCommandsAndFormItems(Form)
	
	AddedItems = Form.AddedContactInformationItems;
	AddedItems.Sort("Priority");
	
	For Each ElementToDelete In AddedItems Do
		
		If ElementToDelete.IsCommand Then
			Form.Commands.Delete(Form.Commands[ElementToDelete.ItemName]);
		Else
			Form.Items.Delete(Form.Items[ElementToDelete.ItemName]);
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure DisplayUserMessage(MessageText, AttributeName, AttributeField)
	
	AttributeName = ?(IsBlankString(AttributeField), AttributeName, "");
	CommonUseClientServer.MessageToUser(MessageText,,AttributeField, AttributeName);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Infobase update.

// Adds update handlers that are required by the subsystem.

//
// Parameters:
//  Handlers - ValueTable - see the description of the NewUpdateHandlerTable function 
//                          in the InfobaseUpdate common module.
// 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	// World country data separation
	If CommonUseCached.DataSeparationEnabled() Then
		Handler = Handlers.Add();
		Handler.Version   = "2.1.4.8";
		Handler.Procedure = "ContactInformationManagement.SeparatedWorldCountryPrototypePreparation";
		Handler.ExclusiveMode = True;
		Handler.SharedData    = True;
		
		Handler = Handlers.Add();
		Handler.Version   = "2.1.4.8";
		Handler.Procedure = "ContactInformationManagement.SeparatedWorldCountryUpdateByPrototype";
		Handler.ExclusiveMode = True;
		Handler.SharedData    = False;
	EndIf;
	
	// Performing routine classifier update (no countries are added)
	Handler = Handlers.Add();
	Handler.Version   = "2.2.2.13";
	Handler.Procedure = "ContactInformationManagement.ExistingWorldCountriesUpdateHandler";
	Handler.ExecutionMode = "Exclusive";
	Handler.SharedData    = False;
	
EndProcedure

// Unseparated exclusive handler used to copy world country data from the zero area.
// Keeps the prototype and the recipient data area list.
//
Procedure SeparatedWorldCountryPrototypePreparation() Export
	
	//PARTIALLY_DELETED
	Return;
	
	//SaasOperationsModule = CommonUseClientServer.CommonModule("SaaSOperations");
	//If SaasOperationsModule = Undefined Then
	//	Return;
	//EndIf;
	//
	//SetPrivilegedMode(True);
	//
	//// Requesting data from the zero area, creating the prototype with reference accuracy
	//CommonUse.SetSessionSeparation(True, 0);
	//Query = New Query("
	//	|SELECT 
	//	|	Catalog.Ref             AS Ref,
	//	|	Catalog.Code            AS Code,
	//	|	Catalog.Description     AS Description,
	//	|	Catalog.AlphaCode2      AS AlphaCode2,
	//	|	Catalog.AlphaCode3      AS AlphaCode3, 
	//	|	Catalog.LongDescription AS LongDescription
	//	|FROM
	//	|	Catalog.WorldCountries AS Catalog
	//	|");
	//Prototype = Query.Execute().Unload();
	//
	//CommonUse.SetSessionSeparation(False);
	//
	//// Saving the prototype
	////PARTIALLY_DELETED
	////Set = InformationRegisters[PrototypeRegisterName].CreateRecordSet();
	//Set = Undefined;
	//Set.Add().Value = New ValueStorage(Prototype, New Deflation(9));
	//InfobaseUpdate.WriteData(Set);
	//
	//// Saving the update recipients
	//UsedAreas = SaasOperationsModule.DataAreasInUse();
	//Selection = UsedAreas.Select();
	//While Selection.Next() Do
	//	
	//	Set.Filter.DataArea.Set(Selection.DataArea);
	//	Set.Clear();
	//	Set.Add().DataArea = Selection.DataArea;
	//	
	//	InfobaseUpdate.WriteData(Set);
	//EndDo;
	
EndProcedure

// Separated handler used to copy world country data from the zero area.
// The prototype prepared during the previous step is used here.
//
Procedure SeparatedWorldCountryUpdateByPrototype() Export
	
	// Locating a prototype for the current data area
	Query = New Query("
		|SELECT
		|	Prototype.Value
		|FROM
		|	InformationRegister.DELETE AS Recipients
		|LEFT JOIN
		|	InformationRegister.DELETE AS Prototype
		|ON
		|	Prototype.DataArea = 0
		|WHERE
		|	Recipients.DataArea = &DataArea
		|");
	Query.SetParameter("DataArea", SessionParameters["DataAreaValue"]);
	Result = Query.Execute();
	If Result.IsEmpty() Then
		// Updating the current data area is not necessary
		Return;
	EndIf;
	
	Prototype = Result.Unload()[0].Value.Get();
	Query = New Query("
		|SELECT
		|	Data.Ref             AS Ref,
		|	Data.Code            AS Code,
		|	Data.Description     AS Description,
		|	Data.AlphaCode2      AS AlphaCode2,
		|	Data.AlphaCode3      AS AlphaCode3, 
		|	Data.LongDescription AS LongDescription
		|INTO
		|	Prototype
		|FROM
		|	&Data AS Data
		|INDEX BY
		|	Ref
		|;///////////////////////////////////////////////////////////////////
		|SELECT 
		|	Prototype.Ref             AS Ref,
		|	Prototype.Code            AS Code,
		|	Prototype.Description     AS Description,
		|	Prototype.AlphaCode2      AS AlphaCode2,
		|	Prototype.AlphaCode3      AS AlphaCode3, 
		|	Prototype.LongDescription AS LongDescription
		|FROM
		|	Prototype AS Prototype
		|LEFT JOIN
		|	Catalog.WorldCountries AS WorldCountries
		|ON
		|	WorldCountries.Ref = Prototype.Ref
		|WHERE
		|	WorldCountries.Ref IS NULL
		|");
	Query.SetParameter("Data", Prototype);
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		Country = Catalogs.WorldCountries.CreateItem();
		Country.SetNewObjectRef(Selection.Ref);
		FillPropertyValues(Country, Selection, , "Ref");
		InfobaseUpdate.WriteData(Country);
	EndDo;
	
EndProcedure

// Updates a specified contact information kind.
//
// Parameters:
//     Kind - CatalogRef.ContactInformationKinds, String - Reference to a contact information kind
//                                                           or a predefined item ID. 
//     Type - EnumRef.ContactInformationTypes, String - Contact information type or its ID.
//     ToolTip - String                               - Tooltip for the contact information kind.
//     CanChangeEditMode - Boolean                    - True if kind settings can be modified, False otherwise.
//     EditInDialogOnly  - Boolean                    - True if data can only be edited in a dialog, False otherwise.
//     Mandatory         - Boolean                    - True if the field is mandatory, False otherwise.
//     Order - Number, Undefined                      - Contact information kind order (relative position in the list): 
//                                                          Undefined   - do not reassign,
//                                                          0           - assign automatically,
//                                                          Number > 0  - assign the specified position.
//    AllowMultipleValueInput - Boolean               - flag specifying whether additional input fields are used for this kind.
//    ValidationSettings - Structure, Undefined       - validation settings for a contact information kind.
//        For the Address type, a structure containing the following fields:
//            * DomesticAddressOnly   - Boolean - True if only domestic addresses are used, False otherwise.
//            * CheckValidity         - Boolean - True if address validation by classifier is performed (provided that DomesticAddressOnly = True), False otherwise.
//            * ProhibitInvalidEntry  - Boolean - True if user must be prohibited from entering invalid addresses (provided that CheckValidity = True), False otherwise.
//            * HideObsoleteAddresses - Boolean - True if obsolete addresses must not be displayed during input (provided that DomesticAddressOnly = True), False otherwise.
//            * IncludeCountryInPresentation - Boolean - True if the country description must be included in the address presentation, False otherwise.
//        For the EmailAddress type, a structure containing the following fields:
//            * CheckValidity       - Boolean  - True if email address validation is necessary, False otherwise.
//            * ProhibitInvalidEntry - Boolean - True if user must be prohibited from entering invalid addresses (provided that CheckValidity = True), False otherwise.
//        For any other types, as well as for the default settings, Undefined is used.
//
// Comment:
//     To set CheckValidity to True, you first need to set ProhibitInvalidEntry to True.
//
// When using the Order parameter, make sure that the assigned order value is unique. 
// If any non-unique order values are identified in this same group after update, users cannot 
// further edit order values.
// Generally, we recommend that you either refrain from using this parameter to reassign 
// the default item order, or that you set it to 0 (in this case, the order will be assigned 
// automatically by the Item order setup subsystem during procedure execution).
// To reassign several contact information kinds in a given relative order without moving them 
// to the beginning of the list, you only need to call the procedure in sequence 
// for each required contact information kind (with order value set to 0).
// If a predefined contact information kind is added to the infobase, we recommend 
// that you do not assign its order explicitly.
//
Procedure RefreshContactInformationKind(Kind, Type, ToolTip, CanChangeEditMode, EditInDialogOnly, Mandatory, Order = Undefined, AllowMultipleValueInput = False, ValidationSettings = Undefined) Export
	
	If TypeOf(Kind) = Type("String") Then
		Object = Catalogs.ContactInformationKinds[Kind].GetObject();
	Else
		Object = Kind.GetObject();
	EndIf;
	
	If TypeOf(Type) = Type("String") Then
		TypeToSet = Enums.ContactInformationTypes[Type];
	Else
		TypeToSet = Type;
	EndIf;
	
	Object.Type                      = TypeToSet;
	Object.ToolTip                   = ToolTip;
	Object.CanChangeEditMode         = CanChangeEditMode;
	Object.EditInDialogOnly          = EditInDialogOnly;
	Object.Mandatory                 = Mandatory;
	Object.AllowMultipleValueInput   = AllowMultipleValueInput;
	
	ValidateSettings = TypeOf(ValidationSettings) = Type("Structure");
	ParameterError   = NStr("en = 'Invalid address validation settings'");
	
	If ValidateSettings And TypeToSet = Enums.ContactInformationTypes.Address Then
		If ValidationSettings.DomesticAddressOnly Then
			If Not ValidationSettings.CheckValidity Then
				If ValidationSettings.ProhibitInvalidEntry Then
					Raise ParameterError;
				EndIf;
			Else
				// See comment above
				If Not ValidationSettings.ProhibitInvalidEntry Then
					Raise ParameterError;
				EndIf;
			EndIf;
			
		Else
			If ValidationSettings.CheckValidity Or ValidationSettings.ProhibitInvalidEntry Or ValidationSettings.HideObsoleteAddresses Then
				Raise ParameterError;
			EndIf;
			
		EndIf;
		
		FillPropertyValues(Object, ValidationSettings);
		
	ElsIf ValidateSettings And TypeToSet = Enums.ContactInformationTypes.EmailAddress Then
		If Not ValidationSettings.CheckValidity Then
			If ValidationSettings.ProhibitInvalidEntry Then
				Raise ParameterError;
			EndIf;
		Else
			// See comment above
			If Not ValidationSettings.ProhibitInvalidEntry Then
				Raise ParameterError;
			EndIf;
		EndIf;
		SetValidationAttributeValues(Object, ValidationSettings);
		
	Else
		SetValidationAttributeValues(Object);
		
	EndIf;
	
	If Order <> Undefined Then
		Object.AdditionalOrderingAttribute = Order;
	EndIf;
	
	InfobaseUpdate.WriteData(Object);
EndProcedure

// Force importing all world countries from the classifier
//
Procedure ImportWorldCountries() Export
	Catalogs.WorldCountries.UpdateWorldCountriesByClassifier(True);
EndProcedure

// Updating only the existing world country items by classifier
Procedure UpdateExistingWorldCountries() Export
	Catalogs.WorldCountries.UpdateWorldCountriesByClassifier();
EndProcedure

// Updating only the existing world country items by classifier (processing the exclusions as well)
Procedure ExistingWorldCountriesUpdateHandler() Export
	
	Catalogs.WorldCountries.UpdateWorldCountriesByClassifier();
	
EndProcedure

// Gets values for a specified contact information type from an object.
//
// Parameters
//    Ref                    - AnyRef - reference to the contact information owner object 
//                                      (company, counterparty, partner, and so on). 
//    ContactInformationType - EnumRef.ContactInformationTypes.
//
// Returns:
//    ValueTable - with the following columns:
//        * Value - String - value represented as a string. 
//        * Kind  - String - contact information kind presentation.
//
Function ObjectContactInformationValues(Ref, ContactInformationType) Export
	
	ObjectArray = New Array;
	ObjectArray.Add(Ref);
	
	ObjectContactInformation = ObjectsContactInformation(ObjectArray, ContactInformationType);
	
	Query = New Query;
	
	Query.SetParameter("ObjectContactInformation", ObjectContactInformation);
	
	Query.Text =
	"SELECT
	|	ObjectContactInformation.Presentation,
	|	ObjectContactInformation.Kind
	|INTO ObjectContactInformationTemporaryTable
	|FROM
	|	&ObjectContactInformation AS ObjectContactInformation
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ObjectContactInformation.Presentation AS Value,
	|	PRESENTATION(ObjectContactInformation.Kind) AS Kind
	|FROM
	|	ObjectContactInformationTemporaryTable AS ObjectContactInformation";
	
	Return Query.Execute().Unload();
	
EndFunction

// Gets the address field values.
// 
// Parameters:
//    FieldValueString - String - address field values.
//    FieldName        - String - field name. Example: County.
// 
// Returns:
//  String - field value.
//
Function GetAddressFieldValue(FieldValueString, FieldName) Export
	
	FieldPosition = Find(FieldValueString, FieldName);
	Value = "";
	If FieldPosition <> 0 Then
		FieldValues = Right(FieldValueString, StrLen(FieldValueString) - FieldPosition - StrLen(FieldName));
		LFPosition = Find(FieldValues, Chars.LF);
		Value = Mid(FieldValues, 0 ,LFPosition - 1);
	EndIf;
	Return Value;
	
EndFunction

// Gets the contact information value.
//
// Parameters:
//    FieldValueString - String - field value string.
//    FieldName        - String - field name.
//
// Returns - String - contact information value.
//
Function GetContactInformationValue(FieldValueString, FieldName) Export
	
	FieldPosition = Find(FieldValueString, FieldName);
	Value = "";
	If FieldPosition <> 0 Then
		FieldValues = Right(FieldValueString, StrLen(FieldValueString) - FieldPosition - StrLen(FieldName));
		LFPosition   = Find(FieldValues, Chars.LF);
		Value    = Mid(FieldValues, 0 , LFPosition - 1);
	EndIf;
	
	Return Value;
	
EndFunction

// Constructor used to create a structure containing fields compatible 
//  with the contact information kind catalog.
//
// Parameters:
//     Source - CatalogRef.ContactInformationKinds - data source (optional).
//
// Returns:
//     Structure - containing fields compatible with the contact information kind catalog.
//
Function ContactInformationKindStructure(Val Source = Undefined) Export
	
	MetaAttributes = Metadata.Catalogs.ContactInformationKinds.Attributes;
	
	If TypeOf(Source) = Type("CatalogRef.ContactInformationKinds") Then
		Attributes = "Description";
		For Each Meta In MetaAttributes Do
			Attributes = Attributes + "," + Meta.Name;
		EndDo;
		
		Return CommonUse.ObjectAttributeValues(Source, Attributes);
	EndIf;
	
	Result = New Structure("Description", "");
	For Each Meta In MetaAttributes Do
		Result.Insert(Meta.Name, Meta.Type.AdjustValue());
	EndDo;
	
	Return Result;
EndFunction

// Returns a value list.
Function AddressesAvailableForCopying(Val FieldValuesForAnalysis, Val AddressKind) Export
	
	CurrentDomesticOnly = AddressKind.DomesticAddressOnly;
	
	Result = New ValueList;
	
	For Each Address In FieldValuesForAnalysis Do
		AllowedSource = True;
		
		Presentation = Address.Presentation;
		If IsBlankString(Presentation) Then
			// Non-empty presentation
			AllowedSource = False;
		Else
			If CurrentDomesticOnly Then
				// Cannot copy foreign address data to a domestic address
				XMLAddress = ContactInformationToXML(Address.FieldValues, Presentation, AddressKind);
				XDTOAddress = ContactInformationInternal.ContactInformationDeserialization(XMLAddress, AddressKind);
				If Not ContactInformationInternal.IsDomesticAddress(XDTOAddress) Then
					AllowedSource = False;
				EndIf;
			EndIf;
		EndIf;
		
		If AllowedSource Then
			Result.Add(Address.ID, String(Address.AddressKind) + ": " + Presentation);
		EndIf;
	EndDo;
	
	Return Result;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Handlers of conditional calls of other subsystems

// Determines whether any classifiers are used by the application.
//
// Parameters:
//   Used - Boolean - True if used, False otherwise.
//
Procedure OnDetermineClassifierUsage(Used) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		Used = True;
	EndIf;
	
EndProcedure

// Searches for the address classifier records by index.
//
// Parameters:
//    Index - String - index used to search for records.
//    AddressObjects - Undefined, Structure - with the following fields:
//        * Count             - Number - number of found records.
//        * FoundState        - String - if only one state is found.
//        * FoundCounty       - String - if only one county is found.
//        * DataIsCurrentFlag - Number - data-is-current flag if only one record is found.
//        * AddressInStorage  - String - ID of the table of found records, which is saved to a storage.
//
Procedure OnDetermineRecordsByIndex(Index, AddressObjects) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		AddressClassifierModule = CommonUse.CommonModule("AddressClassifier");
		AddressObjects = AddressClassifierModule.FindRecordsByPostalCode(Index);
	EndIf;
	
EndProcedure

// Gets address item components by its code.
//
// Parameters:
//    AddressItemCode - Number - address item code used to search for address components.
//    Result - Structure - search result:
//        * State - String - name of the found state.
//        * County - String - name of the found county.
//        * City - String - name of the found city.
//        * Settlement - String - name of the found settlement.
//        * Street - String - name of the found street.
//        * DataIsCurrentFlag - Number - flag specifying that the found address is not obsolete.
//
Procedure GetComponentsToStructureByAddressItemCode(AddressItemCode, Result) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		AddressClassifierModule = CommonUse.CommonModule("AddressClassifier");
		AddressClassifierModule.GetComponentsToStructureByAddressItemCode(AddressItemCode, Result);
	EndIf;
	
EndProcedure

// Determines the address structure.
//
// Parameters:
//    AddressStructure - Structure - with the following fields:
//       * PostalCode - String - address postal code based on the passed parameters.
//       * State - String - state (based on the passed code).
//       * County - String - county (based on the passed code).
//       * City - String - city (based on the passed code).
//       * Settlement - String - settlement (based on the passed code).
//       * Street - String - street (based on the passed code).
//       * Building - String - passed building number.
//       * Unit - String - passed unit number.
//       * Apartment - String - passed apartment number.
//       * AddressItemCode - Number - address item code used to search for the address items.
//    Building - String - building number, if necessary.
//    Unit - String - unit number, if necessary.
//    Apartment - String - apartment number, if necessary.
//
Procedure OnDetermineAddressStructure(AddressStructure, AddressItemCode, Building = "", Unit = "", Apartment = "") Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		AddressClassifierModule = CommonUse.CommonModule("AddressClassifier");
		AddressClassifierModule.AddressStructure(AddressItemCode, Building, Unit, Apartment);
	EndIf;
	
EndProcedure

// Determines the postal code by the state, county, city, settlement, street, building, and unit data provided.
//
// Parameters: 
//    PostalCode - String - postal code.
//    StateName - String - state name (including abbreviation).
//    CountyName - String - county name (including abbreviation).
//    CityName - String - city name (including abbreviation).
//    SettlementName - String - settlement name (including abbreviation).
//    Street - String - street name (including abbreviation).
//    BuildingNumber - String - building number.
//    UnitNumber - String - unit number.
//    PostalCodeParent - Structure - target for the found address item structure.
//
Procedure OnDeterminePostalCode(Index, StateName, CountyName, CityName, SettlementName,
	StreetName, BuildingNumber, UnitNumber, PostalCodeParent = Undefined) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		AddressClassifierModule = CommonUse.CommonModule("AddressClassifier");
		Index = AddressClassifierModule.AddressPostalCode(StateName, CountyName, CityName,
		SettlementName, StreetName, BuildingNumber, UnitNumber, PostalCodeParent);
	EndIf;
	
EndProcedure

// Autocompletion handler for address input field.
//
// Parameters:
//    AutoCompleteList - ValueList - autocompletion list.
//    Text       - String - text entered by user into the address input field.
//    State      - String - previously entered state name.
//    County     - String - previously entered county name.
//    City       - String - previously entered city name.
//    Settlement - String - previously entered settlement name.
//    ItemLevel  - Number - address item ID.
//                          1 - state, 2 - county, 3 - city, 4 - settlement, 5 - street, 0 - other.
//    DataIsCurrentFlag - Number - data-is-current item flag.
//
// Returns:
//    ValueList - autocompletion data.
//    Undefined - no data.
//
Procedure OnDetermineAutoCompleteListForAddressItemText(AutoCompleteList, Text, State, County, City,
	Settlement, ItemLevel, DataIsCurrentFlag = 0) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		AddressClassifierModule = CommonUse.CommonModule("AddressClassifier");
		AutoCompleteList = AddressClassifierModule.AddressItemTextAutoComplete(Text, State, County, City,
		Settlement, ItemLevel, DataIsCurrentFlag);
	EndIf;
	
EndProcedure

// Checks an address for compliance with the address classifier, based on
// the state, county, city, settlement, street, building, and unit data provided.
//
// Parameters:
//    CheckStructure - Structure with the following fields:
//        State - Structure - found state field structure.
//        County - Structure - found county field structure.
//        City - Structure - found city field structure.
//        Settlement - Structure - found settlement field structure.
//        Street - Structure - found street field structure.
//        Building - Structure - found building field structure.
//        HasErrors - Boolean - this flag specifies if any errors occurred during the check.
//        ErrorStructure - Structure - structure where the key is item name and the value is detailed error text.
//                          
//    PostalCode - String - postal code.
//    StateName - String - state name (including abbreviation).
//    CountyName - String - county name (including abbreviation).
//    CityName - String - city name (including abbreviation).
//    SettlementName - String - settlement name (including abbreviation).
//    StreetName - String - street name (including abbreviation).
//    BuildingNumber - String - building number.
//    UnitNumber - String - unit number.
//
Procedure OnDetermineAddressComplianceWithClassifier(CheckStructure, PostalCode = "", StateName = "", CountyName = "",
	CityName = "", SettlementName = "", StreetName = "", BuildingNumber = "", UnitNumber = "") Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		AddressClassifierModule = CommonUse.CommonModule("AddressClassifier");
		CheckStructure = AddressClassifierModule.CheckAddressByAC(PostalCode, StateName,CountyName,
		CityName, SettlementName, StreetName, BuildingNumber , UnitNumber);
	EndIf;
	
EndProcedure

// Checks whether the address item is imported to the infobase.
//
// Parameters: 
//    AddressItemImported - Boolean - flag specifying whether an address item is imported.
//    StateName - String - state name (including abbreviation).
//    CountyName - String - county name (including abbreviation).
//    CityName - String - city name (including abbreviation).
//    SettlementName - String - settlement name (including abbreviation).
//    StreetName - String - street name (including abbreviation).
//    Level - Number - level to be checked for availability.
//
// Returns:
//    Boolean - True if address item is loaded, False otherwise.
//
Procedure OnDetermineAddressItemImport(AddressItemImported, StateName, CountyName = "", CityName = "",
	SettlementName = "", StreetName = "", Level = 1) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		AddressClassifierModule = CommonUse.CommonModule("AddressClassifier");
		AddressItemImported = AddressClassifierModule.AddressItemImported(StateName, CountyName, CityName,
		SettlementName, StreetName, Level);
	EndIf;
	
EndProcedure

// Separately determines address item name and address abbreviation, based on the full address item name.
//
// Parameters:
//    NameAndAddressAbbreviation - String - name and address abbreviation.
//    ItemString - String - item string.
//    AddressAbbreviation - String - address abbreviation.
//
Procedure OnDetermineNameAndAddressAbbreviation(NameAndAddressAbbreviation, ItemString, AddressAbbreviation) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		AddressClassifierModule = CommonUse.CommonModule("AddressClassifier");
		NameAndAddressAbbreviation = AddressClassifierModule.NameAndAddressAbbreviation(ItemString, AddressAbbreviation);
	EndIf;
	
EndProcedure

// Determines whether the address classifier is imported for the specified address items. 
//
// Parameters:
//    ImportedAddressItemStructure - Structure - fields:
//        * State - Boolean - state data is imported.
//        * County - Boolean - county data is imported.
//        * City - Boolean - city data is imported.
//        * Settlement - settlement data is imported.
//        * Street - Boolean - street data is imported.
//        * Building - Boolean - building data is imported.
//   StateName - String - state name (including abbreviation).
//   CountyName - String - county name (including abbreviation).
//   CityName - String - city name (including abbreviation).
//   SettlementName - String - settlement name (including abbreviation).
//   StreetName - String - street name (including abbreviation).
//
Procedure OnDetermineImportedAddressItemStructure(ImportedAddressItemStructure, StateName,
	CountyName, CityName, SettlementName, StreetName) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		AddressClassifierModule = CommonUse.CommonModule("AddressClassifier");
		ImportedAddressItemStructure = AddressClassifierModule.ImportedAddressItemStructure(StateName,
		CountyName, CityName, SettlementName, StreetName);
	EndIf;
	
EndProcedure

// Determines the state name by state code.
//
// Parameters:
//    StateDescription - String - state name.
//    StateCode        - Number - state code.
//
Procedure OnDetermineStateNameByCode(StateDescription, StateCode) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		AddressClassifierModule = CommonUse.CommonModule("AddressClassifier");
		StateDescription = AddressClassifierModule.StateDescriptionByCode(StateCode);
	EndIf;
	
EndProcedure

// Determines the state code by state name.
//
// Parameters:
//    StateCode - Number - state code.
//    State     - String - state name.
//
Procedure OnDetermineStateCodeByName(StateCode, State) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		AddressClassifierModule = CommonUse.CommonModule("AddressClassifier");
		StateCode = AddressClassifierModule.StateCodeByDescription(State);
	EndIf;
	
EndProcedure

// Returns address classifier string (or structure) based on address item values.
//
// Parameters:
//    AddressClassifierStructure - Undefined or Structure - Field structure for the found address item
//    (see the AddressClassifierClientServer.EmptyAddressStructure() function). 
//    StateName - String - state name (including abbreviation).
//    CountyName - String - county name (including abbreviation).
//    CityName - String - city name (including abbreviation).
//    SettlementName - String - settlement name (including abbreviation).
//    StreetName - String - street name (including abbreviation).
//
Procedure OnDetermineAddressClassifierStringByAddressItems(AddressClassifierStructure, StateName, CountyName, CityName, SettlementName, StreetName) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		AddressClassifierModule = CommonUse.CommonModule("AddressClassifier");
		AddressClassifierStructure = AddressClassifierModule.ReturnAddressClassifierStructureByAddressItem(
		StateName, CountyName, CityName, SettlementName, StreetName);
	EndIf;
	
EndProcedure

// Clears subordinate items of a specified address item.
//
// Parameters:
//    State - String - string for storing string presentation of the parent state.
//    County - String - string for storing string presentation of the parent county.
//    City - String - string for storing string presentation of the parent city.
//    Settlement - string - string for storing string presentation of the parent settlement.
//    Street - String - string for storing string presentation of the parent street.
//    Building - String - string for storing string presentation of the parent building number.
//    Unit - String - string for storing string presentation of the parent unit number.
//    Apartment - String - string for storing string presentation of the parent apartment number.
//    Level - Number - address item level.
//
Procedure OnClearChildrenByAddressItemLevel(State, County, City, Settlement, Street, Building, Unit, Apartment, Level) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		AddressClassifierModule = CommonUse.CommonModule("AddressClassifier");
		AddressClassifierModule.ClearChildsByAddressItemLevel(State, County, City,
			Settlement, Street, Building, Unit, Apartment, Level);
	EndIf;
	
EndProcedure

#EndRegion