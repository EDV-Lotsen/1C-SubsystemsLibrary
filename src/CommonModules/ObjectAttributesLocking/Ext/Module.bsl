
///////////////////////////////////////////////////////////////////////////////////////////////////
// For subsystems operation, attribute __ParametersBanEdit, with type FixedMap is being added
// to object form in interactive mode, where
//		key - string - name of attribute
//		value - structure:
//				LockableItems - Array - array, of strings - names of form items being locked
//				Presentation - string - presentation of attribute for a user
//				AllowChange - boolean - change of attribute is permitted
///////////////////////////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////////////////////////
// EXPORT FUNCTIONS

// Procedure accepts form as parameter and for all attributes,
// for which mechanism is defined, locks their edit option.
// Parameters:
//  Form - managed form 				    - form of object, for which mechanism 
//  GroupForBanButtonDescription is used    - if button of edit possibility has to placed
//                       to a special place - form group is being passed
Procedure LockAttributes(Form,
								 GroupForBanButtonDescription = Undefined) Export
	
	// Check, that form is prepared (created required attributes and form items)
	FormIsPrepared = False;
	FormAttributes = Form.GetAttributes();
	For Each FormAttribute In FormAttributes Do
		If FormAttribute.Name = "__ParametersBanEdit" Then
			FormIsPrepared = True;
			Break;
		EndIf;
	EndDo;
	
	If Not FormIsPrepared Then
		PrepareForm(Form, Form.Object.Ref, GroupForBanButtonDescription);
	EndIf;
	
	If Form.Object.Ref.IsEmpty() Then
		AllowChange = True;
	Else
		AllowChange = False;
	EndIf;
	
	// Lock editing of attributes
	For Each DescriptionOfBlockedAttribute In Form.__ParametersBanEdit Do
		For Each FormItemDetails In DescriptionOfBlockedAttribute.LockableItems Do
			FormItem = Form.Items.Find(FormItemDetails.Value);
			If FormItem <> Undefined Then
				If TypeOf(FormItem) = Type("FormField")
				 OR TypeOf(FormItem) = Type("FormTable") Then
					FormItem.ReadOnly = NOT AllowChange;
				Else
					FormItem.Enabled = AllowChange;
				EndIf;
			EndIf;
		EndDo;
		DescriptionOfBlockedAttribute.AllowChange = AllowChange;
	EndDo;
	
EndProcedure

// Checks, that object with ref Ref has refs to existing infobase objects.
//
Function CheckThereAreRefsToObjectsInIB(Val RefOrRefsArray) Export
	
	If TypeOf(RefOrRefsArray) = Type("Array") Then
		RefsArray = RefOrRefsArray;
	Else
		RefsArray = New Array;
		RefsArray.Add(RefOrRefsArray);
	EndIf;
	
	RefsTable = FindByRef(RefsArray);
	
	ServiceObjects = CommonUseOverrided.GetRefSearchExclusions();
	
	Exceptions = New Array;
	
	For Each RefDetails In RefsTable Do
		If ServiceObjects.Find(RefDetails.Metadata.FullName()) <> Undefined Then
			Exceptions.Add(RefDetails);
		EndIf;
	EndDo;
	
	For Each StringException In Exceptions Do
		RefsTable.Delete(StringException);
	EndDo;
	
	If RefsTable.Count() > 0 Then
		Return True;
	Else
		Return False;
	EndIf;
	
EndFunction

///////////////////////////////////////////////////////////////////////////////////////////////////
// AUXILIARY FUNCTIONS

// Prepares a form for subsystem.
// Attribute __ParametersBanEdit type FixedMap (see above) is being added
//
Procedure PrepareForm(Form, Ref, GroupForBanButtonDescription = Undefined)
	
	TypeDescriptionString100 = New TypeDescription("String",,New StringQualifiers(100));
	TypeDescriptionBoolean = New TypeDescription("Boolean");
	TypeDescriptionArray = New TypeDescription("ValueList");
	
	// Add attribute to a form
	AttributesBeingAdded = New Array;
	AttributesBeingAdded.Add(New FormAttribute("__ParametersBanEdit", New TypeDescription("ValueTable")));
	AttributesBeingAdded.Add(New FormAttribute("AttributeName" 	,TypeDescriptionString100, "__ParametersBanEdit"));
	AttributesBeingAdded.Add(New FormAttribute("Presentation"		,TypeDescriptionString100, "__ParametersBanEdit"));
	AttributesBeingAdded.Add(New FormAttribute("AllowChange"		,TypeDescriptionBoolean, "__ParametersBanEdit"));
	AttributesBeingAdded.Add(New FormAttribute("LockableItems"		,TypeDescriptionArray, "__ParametersBanEdit"));
	
	Form.ChangeAttributes(AttributesBeingAdded);
	
	LockableAttributes = CommonUse.ObjectManagerByRef(Ref).GetObjectLockableAttributes();
	
	For Each LockableAttribute In LockableAttributes Do
		
		AttributeDetails = Form.__ParametersBanEdit.Add();
		
		InformationAboutBA = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(LockableAttribute, ";");
		AttributeDetails.AttributeName = InformationAboutBA[0];
		
		If InformationAboutBA.Count() > 1 Then
			LockableItems = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(InformationAboutBA[1], ",");
			For Each LockableItem In LockableItems Do
				AttributeDetails.LockableItems.Add(TrimAll(LockableItem));
			EndDo;
		EndIf;
		
		FillRelatedItems(AttributeDetails.LockableItems, Form, AttributeDetails.AttributeName);
		
		If Ref.Metadata().Attributes.Find(AttributeDetails.AttributeName) <> Undefined Then
			If ValueIsFilled(Ref.Metadata().Attributes[AttributeDetails.AttributeName].Synonym) Then
				Presentation = Ref.Metadata().Attributes[AttributeDetails.AttributeName].Synonym;
			Else
				Presentation = Ref.Metadata().Attributes[AttributeDetails.AttributeName].Name;
			EndIf;
		ElsIf ThisIsStandardAttribute(Ref, AttributeDetails.AttributeName) Then
			If ValueIsFilled(Ref.Metadata().StandardAttributes[AttributeDetails.AttributeName].Synonym) Then
				Presentation = Ref.Metadata().StandardAttributes[AttributeDetails.AttributeName].Synonym;
			Else
				Presentation = Ref.Metadata().StandardAttributes[AttributeDetails.AttributeName].Name;
			EndIf;
		ElsIf Ref.Metadata().TabularSections.Find(AttributeDetails.AttributeName) <> Undefined Then
			If ValueIsFilled(Ref.Metadata().TabularSections[AttributeDetails.AttributeName].Synonym) Then
				Presentation = Ref.Metadata().TabularSections[AttributeDetails.AttributeName].Synonym;
			Else
				Presentation = Ref.Metadata().TabularSections[AttributeDetails.AttributeName].Name;
			EndIf;
		EndIf;
		
		AttributeDetails.Presentation = Presentation;
		
		AttributeDetails.AllowChange = False;
		
	EndDo;
	
	// Add form command only if role "EditObjectDetails" is enabled
	If (IsInRole(Metadata.Roles.EditObjectDetails)
	 OR Users.CurrentUserHaveFullAccess())
	   And AccessRight("Edit", Ref.Metadata()) Then
		// Add command
		Command = Form.Commands.Add("AuthorizeObjectDetailsEditing");
		Command.Title = NStr("en = 'Allow Editing Object Attributes'");
		Command.Action = "Pluggable_AuthorizeObjectAttributesEditing";
		Command.Picture = PictureLib.AuthorizeObjectDetailsEditing;
		Command.ModifiesStoredData = False;
		
		// Add button on the form
		If GroupForBanButtonDescription <> Undefined Then
			ParentGroup = GroupForBanButtonDescription;
		Else
			ParentGroup = Form.CommandBar;
		EndIf;
		
		Button = Form.Items.Add("AuthorizeObjectDetailsEditing", Type("FormButton"), ParentGroup);
		Button.OnlyInAllActions = True;
		Button.CommandName = "AuthorizeObjectDetailsEditing";
	EndIf;
	
EndProcedure

// Checks, that current attribute is a standard object attribute
//
Function ThisIsStandardAttribute(Ref, Description)
	
	For Each StandardAttributeDescription In Ref.Metadata().StandardAttributes Do
		If StandardAttributeDescription.Name = Description Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

// Returns form item name, having refs to object, using passed
// object attribute name
//
Procedure FillRelatedItems(ArrayOfLinkedItems, Form, AttributeName)
	
	For Each FormItem In Form.Items Do
		If (TypeOf(FormItem) = Type("FormField") And FormItem.Type <> FormFieldType.LabelField)
			OR TypeOf(FormItem) = Type("FormTable") Then
			DecomposedPathToData = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(FormItem.DataPath, ".");
			If DecomposedPathToData.Count() = 2 And DecomposedPathToData[1] = AttributeName Then
				ArrayOfLinkedItems.Add(FormItem.Name);
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure
