////////////////////////////////////////////////////////////////////////////////
// Object attribute edit prohibition subsystem.
// 
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// Allows the editing of locked form items linked to the specified attributes.
//
// Parameters:
//  Form          - ManagedForm - form that contains the items linked to the specified attributes.
//
//  ContinuationHandler  - Undefined - no actions after procedure execution.
//                       - NotifyDescription - notification that is called after the procedure execution.
//                         A Boolean parameter is passed to the notification handler:
//                           True - no references are found, or the user decided to allow editing.
//                           False   - no visible attributes are locked, or
//                                     references are found and the user decided to cancel the operation.
//
Procedure AllowObjectAttributeEdit(Val Form, ContinuationHandler = Undefined) Export
	
	LockedAttributes = Attributes(Form);
	
	If LockedAttributes.Count() = 0 Then
		ShowAllVisibleAttributesAreUnlockedMessageBox(
			New NotifyDescription
("AllowObjectAttributeEditAfterWarning",
				ObjectAttributeEditProhibitionInternalClient, ContinuationHandler));
		Return;
	EndIf;
	
	AttributeSynonyms = New Array;
	
	For Each AttributeDetails In Form.AttributeEditProhibitionParameters Do
		If LockedAttributes.Find(AttributeDetails.AttributeName) <> Undefined 
Then
			AttributeSynonyms.Add(AttributeDetails.Presentation);
		EndIf;
	EndDo;
	
	RefArray = New Array;
	RefArray.Add(Form.Object.Ref);
	
	Parameters = New Structure;
	Parameters.Insert("Form", Form);
	Parameters.Insert("LockedAttributes", LockedAttributes);
	Parameters.Insert("ContinuationHandler", ContinuationHandler);
	
	CheckObjectRefs(
		New NotifyDescription("AllowObjectAttributeEditAfterCheckRefs",
			ObjectAttributeEditProhibitionInternalClient, Parameters),
		RefArray,
		AttributeSynonyms);
	
EndProcedure

// Sets the availability of form items associated with the specified attributes whose editing is allowed. 
// Passing an attribute array to the procedure expands the set of attributes whose editing is allowed.
// If unlocking form items linked to the specified attributes is denied for all of the attributes,
// the button that allows editing becomes unavailable.
//  
// Parameters:
//  Form          - ManagedForm - form that contains the items linked to the specified attributes.
//  
//  Attributes    - Array - values:
//                  * String - names of attributes to be allowed for editing.
//                    It is used when the AllowObjectAttributeEdit function is not used.
//                - Undefined - the set of attributes available for editing is not changed,
//                    and the form items linked to the attributes whose editing is allowed become available.
//
Procedure SetFormItemEnabled(Val Form, Val Attributes = Undefined) Export
	
	SetAttributeEditEnabling(Form, Attributes);
	
	For Each DescriptionOfAttributeToLock In Form.AttributeEditProhibitionParameters Do
		If DescriptionOfAttributeToLock.EditAllowed Then
			For Each FormItemToLock In DescriptionOfAttributeToLock.BlockableItems Do
				FormItem = Form.Items.Find(FormItemToLock.Value);
				If FormItem <> Undefined Then
					If TypeOf(FormItem) = Type("FormField")
					 Or TypeOf(FormItem) = Type("FormTable") Then
						FormItem.ReadOnly = False;
					Else
						FormItem.Enabled = True;
					EndIf;
				EndIf;
			EndDo;
		EndIf;
	EndDo;
	
EndProcedure

// Prompts a user to confirm that they want to allow attribute editing 
// and checks if there are any references to the object in the infobase.
//
// Parameters:
//  ContinuationHandler - NotifyDescription - notification that is called after the check.
//                        A parameter of Boolean type is passed to alert handling:
//                           True - no references are found or the user decided to allow editing.
//                           False - no visible attributes are locked, 
//                                   or references are found and the user decided to cancel the operation.
//  RefArray         - Array - values:
//                           * Ref - references in various objects. 
//                                   The procedure searches for these references.
//  AttributeSynonyms   - Array - values:
//                           * String - attribute synonyms displayed to the user.
//
Procedure CheckObjectRefs(Val ContinuationHandler, Val RefArray, Val AttributeSynonyms) Export
	
	DialogTitle = NStr("en = 'Allow attribute editing'");
	
	AttributesPresentation = "";
	For Each AttributeSynonym In AttributeSynonyms Do
		AttributesPresentation = AttributesPresentation + AttributeSynonym + "," + Chars.LF;
	EndDo;
	AttributesPresentation = Left(AttributesPresentation, StrLen(AttributesPresentation) - 2);
	
	If AttributeSynonyms.Count() > 1 Then
		QuestionText = NStr("en = 'To avoid application data mismatch, the following attributes are not available for editing: 
     |%1.
			|
			|Before you allow editing these attributes, it is recommended that you evaluate the expected consequences	
			|by checking all attribute usage instances in the application.
			|The search for usage instances can take a long time.'");
								  
	Else
		QuestionText = NStr("en = 'To avoid application data mismatch, the %1 attribute is not available for editing.
			|
			|Before you allow editing this attribute, it is recommended that you evaluate the expected consequences	
			|by checking all %2 usage instances in the application.
			|The search for usage instances can take a long time.'");
	EndIf;
	
	If RefArray.Count() = 1 Then
		ObjectsPresentation = RefArray[0];
	Else
		ObjectsPresentation = StringFunctionsClientServer.SubstituteParametersInString( 
			NStr("en = 'the selected items (%1)'"), RefArray.Number());
	EndIf;
	
	QuestionText = StringFunctionsClientServer.SubstituteParametersInString(QuestionText, AttributesPresentation, ObjectsPresentation);
	
	Parameters = New Structure;
	Parameters.Insert("RefArray", RefArray);
	Parameters.Insert("AttributeSynonyms", AttributeSynonyms);
	Parameters.Insert("DialogTitle", DialogTitle);
	Parameters.Insert("ContinuationHandler", ContinuationHandler);
	
	Buttons = New ValueList;
	Buttons.Add(DialogReturnCode.Yes, NStr("en = 'Check and allow'"));
	Buttons.Add(DialogReturnCode.No, NStr("en = 'Cancel'"));
	
	ShowQueryBox(
		New NotifyDescription("CheckObjectReferenceAfterValidationConfirm",
			ObjectAttributeEditProhibitionInternalClient, Parameters),
		QuestionText, Buttons, , DialogReturnCode.Yes, DialogTitle);
	
EndProcedure

// Allows editing the attributes whose descriptions are given in the form.
// Use this procedure when you need to explicitly set form item availability without using the 
// SetFormItemEnabled function.
// 
// Parameters:
//  Form          - ManagedForm - form where you want to allow editing object attributes.
//  
//  Attributes    - Array - values:
//                  * String - attribute names. Editing these attributes will be allowed.
//  
//  EditAllowed             - Boolean - flag that shows whether you want to allow attribute editing.
//                            Can only be set to True if the edit right is granted.
//                          - Undefined - do not change the attribute editing status.
// 
//  RightToEdit - Boolean - flag used to override the availability of unlocking attributes 
//                          that is determined automatically using the AccessRight method.
//               - Undefined - do not change the RightToEdit property.
// 
Procedure SetAttributeEditEnabling(Val Form, Val Attributes,
			Val EditAllowed = True, Val RightToEdit = Undefined) Export
	
	If TypeOf(Attributes) = Type("Array") Then
		
		For Each Attribute In Attributes Do
			AttributeDetails = Form.AttributeEditProhibitionParameters.FindRows(New Structure("AttributeName", Attribute))[0];
			If TypeOf(RightToEdit) = Type("Boolean") Then
				AttributeDetails.RightToEdit = RightToEdit;
			EndIf;
			If TypeOf(EditAllowed) = Type("Boolean") Then
				AttributeDetails.EditAllowed = AttributeDetails.RightToEdit And EditAllowed;
			EndIf;
		EndDo;
	EndIf;
	
	// Updating the availability of AllowObjectAttributeEdit command
	AllAttributesUnlocked = True;
	
	For Each DescriptionOfAttributeToLock In 
Form.AttributeEditProhibitionParameters Do
		If DescriptionOfAttributeToLock.RightToEdit
		And Not DescriptionOfAttributeToLock.EditAllowed Then
			AllAttributesUnlocked = False;
			Break;
		EndIf;
	EndDo;
	
	If AllAttributesUnlocked Then
		Form.Items.AllowObjectAttributeEdit.Enabled = False;
	EndIf;
	
EndProcedure

// Returns the array of attribute names specified in the AttributeEditingBanParameters form property. 
// The function result is based on the attribute names specified in the object manager module, 
// excluding the attributes with RightToEdit = False.

//
// Parameters:
//  Form        - ManagedForm - object form with a mandatory standard Object attribute.
//  OnlyLocked  - Boolean - you can set this parameter to False for debug purposes, 
//                          to get a list of all visible attributes that can be unlocked..
//  OnlyVisible - Boolean - set this parameter to False to get and unlock all object attributes.
//
// Returns:
//  Array - values:
//   * String - attribute names.
//
Function Attributes(Val Form, Val OnlyLocked = True, OnlyVisible = True) Export
	
	Attributes = New Array;
	
	For Each DescriptionOfAttributeToLock In Form.AttributeEditProhibitionParameters Do
		
		If DescriptionOfAttributeToLock.RightToEdit
		   And (    DescriptionOfAttributeToLock.EditAllowed = False
		      Or OnlyLocked = False) Then
			
			AddAttribute = False;
			For Each FormItemToLock In DescriptionOfAttributeToLock.BlockableItems Do
				FormItem = Form.Items.Find(FormItemToLock.Value);
				If FormItem <> Undefined And (FormItem.Visible Or Not OnlyVisible) Then
					AddAttribute = True;
					Break;
				EndIf;
			EndDo;
			If AddAttribute Then
				Attributes.Add(DescriptionOfAttributeToLock.AttributeName);
			EndIf;
		EndIf;
	EndDo;
	
	Return Attributes;
	
EndFunction

// Displays a warning that all visible attributes are unlocked.
// The warning is required when the unlock command remains enabled because of invisible locked attributes.
//
// Parameters:
//  ContinuationHandler - Undefined - no action after the procedure execution.
//                      - NotifyDescription - notification that is called after the procedure execution.
//
Procedure ShowAllVisibleAttributesAreUnlockedMessageBox(ContinuationHandler = Undefined) Export
	
	ShowMessageBox(ContinuationHandler,
		NStr("en = 'Editing all visible object attributes is already allowed.'"));
	
EndProcedure

// Obsolete. You should use Attributes function.
Function AttributesExceptInvisible(Val Form, Val OnlyLocked = True) Export
	
	Return Attributes(Form, OnlyLocked);
	
EndFunction

#EndRegion
