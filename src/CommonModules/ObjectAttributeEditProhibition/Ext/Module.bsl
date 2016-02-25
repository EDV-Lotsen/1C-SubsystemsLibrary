////////////////////////////////////////////////////////////////////////////////
// Object attribute edit prohibition subsystem.
// 
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// Prohibits editing specified attributes of an object form, and
// adds the Allow editing attributes command to All actions.
//
// Parameters:
//  Form                    - ManagedForm - object form.
//  ProhibitionButtonGroup  - FormGroup - used to modify the default placement 
//                                        of the edit prohibition button in the object form.
//  ProhibitionButtonTitle  - String - button title. The default value is Allow editing attributes.
//  Object                  - Undefined - gets object from the Object form attribute.
//                          - FormDataStructure - by object type.
//
Procedure LockAttributes(Form, ProhibitionButtonGroup = Undefined, ProhibitionButtonTitle = "",
		Object = Undefined) Export
	
	ObjectDescription = ?(Object = Undefined, Form.Object, Object);
	
	// Determining whether the form is already prepared during an earlier call
	FormPrepared = False;
	FormAttributes = Form.GetAttributes();
	For Each FormAttribute In FormAttributes Do
		If FormAttribute.Name = "AttributeEditProhibitionParameters" Then
			FormPrepared = True;
			Break;
		EndIf;
	EndDo;
	
	If Not FormPrepared Then
		PrepareForm(Form, ObjectDescription.Ref, ProhibitionButtonGroup, ProhibitionButtonTitle);
	EndIf;
	
	IsNewObject = ObjectDescription.Ref.IsEmpty();
	
	// Enabling edit prohibition for form items related to the specified attributes
	For Each DescriptionOfAttributeToBlock In Form.AttributeEditProhibitionParameters Do
		For Each FormItemDescription In DescriptionOfAttributeToBlock.BlockableItems Do
			
			DescriptionOfAttributeToBlock.EditAllowed =
				DescriptionOfAttributeToBlock.RightToEdit And IsNewObject;
			
			FormItem = Form.Items.Find(FormItemDescription.Value);
			If FormItem <> Undefined Then
				If TypeOf(FormItem) = Type("FormField")
				 Or TypeOf(FormItem) = Type("FormTable") Then
					FormItem.ReadOnly = Not DescriptionOfAttributeToBlock.EditAllowed;
				Else
					FormItem.Enabled = DescriptionOfAttributeToBlock.EditAllowed;
				EndIf;
			EndIf;
		EndDo;
	EndDo;
	
	If Form.Items.Find("AllowObjectAttributeEdit") <> Undefined Then
		Form.Items.AllowObjectAttributeEdit.Enabled = True;
	EndIf;
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

// Sets up the object form for subsystem operations:
// - adds the AttributeEditProhibitionParameters attribute that can be used to store internal data
// - adds the AllowObjectAttributeEdit command and button (if sufficient rights are available)
//
Procedure PrepareForm(Form, Ref, ProhibitionButtonGroup, ProhibitionButtonTitle)
	
	String100TypeDescription = New TypeDescription("String",,New StringQualifiers(100));
	BooleanTypeDescription = New TypeDescription("Boolean");
	ArrayTypeDescription = New TypeDescription("ValueList");
	
	FormAttributes = New Map;
	For Each FormAttribute In Form.GetAttributes() Do
		FormAttributes.Insert(FormAttribute.Name, FormAttribute.Title);
	EndDo;
	
	// Adding attributes to form
	AttributesToBeAdded = New Array;
	AttributesToBeAdded.Add(New FormAttribute("AttributeEditProhibitionParameters", New TypeDescription("ValueTable")));
	AttributesToBeAdded.Add(New FormAttribute("AttributeName",            String100TypeDescription, "AttributeEditProhibitionParameters"));
	AttributesToBeAdded.Add(New FormAttribute("Presentation",           String100TypeDescription, "AttributeEditProhibitionParameters"));
	AttributesToBeAdded.Add(New FormAttribute("EditAllowed", BooleanTypeDescription,    "AttributeEditProhibitionParameters"));
	AttributesToBeAdded.Add(New FormAttribute("BlockableItems",     ArrayTypeDescription,    "AttributeEditProhibitionParameters"));
	AttributesToBeAdded.Add(New FormAttribute("RightToEdit",     BooleanTypeDescription,    "AttributeEditProhibitionParameters"));
	
	Form.ChangeAttributes(AttributesToBeAdded);
	
	AttributesToLock = CommonUse.ObjectManagerByRef(Ref).GetObjectAttributesToLock();
	AllAttributesEditProhibited = True;
	
	For Each AttributeToLock In AttributesToLock Do
		
		AttributeDetails = Form.AttributeEditProhibitionParameters.Add();
		
		InformationOnAttributeToLock = StringFunctionsClientServer.SplitStringIntoSubstringArray(AttributeToLock, ";");
		AttributeDetails.AttributeName = InformationOnAttributeToLock[0];
		
		If InformationOnAttributeToLock.Count() > 1 Then
			BlockableItems = StringFunctionsClientServer.SplitStringIntoSubstringArray(InformationOnAttributeToLock[1], ",");
			For Each ItemToLock In BlockableItems Do
				AttributeDetails.BlockableItems.Add(TrimAll(ItemToLock));
			EndDo;
		EndIf;
		
		FillRelatedItems(AttributeDetails.BlockableItems, Form, AttributeDetails.AttributeName);
		
		ObjectMetadata = Ref.Metadata();
		AttributeOrTabularSectionMetadata = ObjectMetadata.Attributes.Find(AttributeDetails.AttributeName);
		StandardAttributeOrTabularSection = False;
		If AttributeOrTabularSectionMetadata = Undefined Then
			AttributeOrTabularSectionMetadata = ObjectMetadata.TabularSections.Find(AttributeDetails.AttributeName);
			If AttributeOrTabularSectionMetadata = Undefined Then
				If CommonUse.IsStandardAttribute(ObjectMetadata.StandardAttributes, AttributeDetails.AttributeName) Then
					AttributeOrTabularSectionMetadata = ObjectMetadata.StandardAttributes[AttributeDetails.AttributeName];
					StandardAttributeOrTabularSection = True;
				EndIf;
			EndIf;
		EndIf;
		
		If AttributeOrTabularSectionMetadata = Undefined Then
			AttributeDetails.Presentation = FormAttributes[AttributeDetails.AttributeName];
			
			AttributeDetails.RightToEdit = True;
			AllAttributesEditProhibited = False;
		Else
			AttributeDetails.Presentation = ?(
				ValueIsFilled(AttributeOrTabularSectionMetadata.Synonym),
				AttributeOrTabularSectionMetadata.Synonym,
				AttributeOrTabularSectionMetadata.Name);
			
			If StandardAttributeOrTabularSection Then
				RightToEdit = AccessRight("Edit", ObjectMetadata, , AttributeOrTabularSectionMetadata.Name);
			Else
				RightToEdit = AccessRight("Edit", AttributeOrTabularSectionMetadata);
			EndIf;
			If RightToEdit Then
				AttributeDetails.RightToEdit = True;
				AllAttributesEditProhibited = False;
			EndIf;
		EndIf;
	EndDo;
	
	// Adding command and button (if sufficient rights are available)
	If Users.RolesAvailable("EditObjectAttributes")
	   And AccessRight("Edit", Ref.Metadata())
	   And Not AllAttributesEditProhibited Then
		
		// Adding command
		Command = Form.Commands.Add("AllowObjectAttributeEdit");
		Command.Title = ?(IsBlankString(ProhibitionButtonTitle), NStr("en = 'Allow editing attributes'"), ProhibitionButtonTitle);
		Command.Action = "Attachable_AllowObjectAttributeEdit";
		Command.Picture = PictureLib.AllowObjectAttributeEdit;
		Command.ModifiesStoredData = True;
		
		// Adding button
		ParentGroup = ?(ProhibitionButtonGroup <> Undefined, ProhibitionButtonGroup, Form.CommandBar);
		Button = Form.Items.Add("AllowObjectAttributeEdit", Type("FormButton"), ParentGroup);
		Button.OnlyInAllActions = True;
		Button.CommandName = "AllowObjectAttributeEdit";
	EndIf;
	
EndProcedure

// Returns a form item name by the name of an object attribute referencing the form item
Procedure FillRelatedItems(RelatedItemArray, Form, AttributeName)
	
	For Each FormItem In Form.Items Do
		If (TypeOf(FormItem) = Type("FormField") And FormItem.Type <> FormFieldType.LabelField)
			Or TypeOf(FormItem) = Type("FormTable") Then
			ParsedDataPath = StringFunctionsClientServer.SplitStringIntoSubstringArray(FormItem.DataPath, ".");
			If ParsedDataPath.Count() = 2 And ParsedDataPath[1] = AttributeName Then
				RelatedItemArray.Add(FormItem.Name);
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion
