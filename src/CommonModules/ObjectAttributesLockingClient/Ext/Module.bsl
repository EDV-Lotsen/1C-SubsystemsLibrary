
// Module contains export function AuthorizeObjectDetailsEditing,
// which can authorize editing of form items, linked with attributes
// locked by subsystem, and also generate record in form attribute
// __ParametersBanEdit which allows to write objects with modified
// attributes.
//
//  __ParametersBanEdit is a map, where key
//  is object attribute description. Value is a structure
//  with keys:
//    LockableItems - Array - array, of strings - names of locked form items
//    Presentation - string - presentation of field oin form (field title or another presentation)
//    AllowChange - boolean - modification of object attribute is allowed
//

// Function implementing interaction with user
//
Function AuthorizeObjectDetailsEditing(Form) Export
	
	SynonymsOfAttributes = New Array;
	
	For Each DescriptionOfBlockedAttribute In Form.__ParametersBanEdit Do
		SynonymsOfAttributes.Add(DescriptionOfBlockedAttribute.Presentation);
	EndDo;
	
	RefsArray = New Array;
	
	RefsArray.Add(Form.Object.Ref);
	
	Result = CheckReferencesToObject(RefsArray, SynonymsOfAttributes);
	
	If Result Then
		For Each DescriptionOfBlockedAttribute In Form.__ParametersBanEdit Do
			DescriptionOfBlockedAttribute.AllowChange = True;
		EndDo;
	EndIf;
		
	Return Result;
	
EndFunction

// Requests user confirmation forto allow edit of attributes
// and checks if there are references to object in infobase
//
Function CheckReferencesToObject(RefsArray, SynonymsOfAttributes) Export
	
	Result = False;
	
	DialogTitle = NStr("en = 'Edit object details'");
	
	AttributesPresentation = "";
	
	For Each AttributeSynonym In SynonymsOfAttributes Do
		AttributesPresentation = AttributesPresentation + """" + AttributeSynonym + """, ";
	EndDo;
	
	AttributesPresentation = Left(AttributesPresentation, StrLen(AttributesPresentation)-2);
	
	If SynonymsOfAttributes.Count() > 1 Then
		QuestionText = NStr("en = 'Attention!!! You are going to edit attributes %1.
                             |Modifying these attributes will result in Infobase data mismatch.'");
	Else
		QuestionText = NStr("en = 'Attention!!! You are going to edit attribute %1.
                             |Modifying this attribute will result in Infobase data mismatch.'");
	EndIf;
	
	If RefsArray.Count() = 1 Then
		QuestionText = QuestionText + NStr( "en = 'It is strongly recommended to check all references to the object and to assess the impact of changes. 
                                             |Do you want to proceed with references to the object?'");
	Else
		Number_OfObjects = String(RefsArray.Count());
		Declension = ? (Right(Number_OfObjects,1) = "1", NStr("en = 'object'"), NStr("en = 'objects'"));
		QuestionText = QuestionText + 
				StringFunctionsClientServer.SubstitureParametersInString(
							NStr("en = 'Do you want to allow editing details for %1 %2?'"), 
								Number_OfObjects, Declension);
	EndIf;
	
	QuestionText = StringFunctionsClientServer.SubstitureParametersInString(QuestionText, AttributesPresentation);
	
	ChoiceResult = DoQueryBox(QuestionText, QuestionDialogMode.YesNo, , DialogReturnCode.Yes, DialogTitle);
	
	If ChoiceResult = DialogReturnCode.Yes Then
		
		If RefsArray.Count() = 1 Then
			If ObjectAttributesLocking.CheckThereAreRefsToObjectsInIB(RefsArray) Then
				MessageText = NStr("en = 'There are references to this object, are you sure you want to change it''s attributes?'");
				
				ChoiceResultAfterSearch = DoQueryBox(MessageText,
													QuestionDialogMode.YesNo, ,
													DialogReturnCode.Yes,
													DialogTitle);
				If ChoiceResultAfterSearch = DialogReturnCode.Yes Then
					Result = True;
				EndIf;
				
			Else
				MessageText = NStr("en = 'Infobase does not have references to the edited object. Objects requisites editing prohibited!'");
				DoMessageBox(MessageText,, DialogTitle);
				Result = True;
			EndIf;
			
		Else
			Result = True;
		EndIf;
		
	EndIf;
	
	Return Result;
	
EndFunction

// Sets accessibility of form items corresponding to the object attributes.
// If all attributes of object can be edited, then
// edit prohibition button is being disabled.
// Parameters:
//   Form         	- ManagedForm - form, where edit of object attributes
//                 has to be allowed
//   Attributes 	- Array - attributes, that can be edited
//
Procedure SetAccessibilityOfFormItems(Form, Val Attributes = Undefined) Export
	
	If Attributes <> Undefined Then
		For Each Attribute In Attributes Do
			Form.__ParametersBanEdit.FindRows(New Structure("AttributeName", Attribute))[0].AllowChange = True;
		EndDo;
	EndIf;
	
	For Each DescriptionOfBlockedAttribute In Form.__ParametersBanEdit Do
		If DescriptionOfBlockedAttribute.AllowChange Then
			For Each LockableFormItem In DescriptionOfBlockedAttribute.LockableItems Do
				FormItem = Form.Items.Find(LockableFormItem.Value);
				If FormItem <> Undefined Then
					If TypeOf(FormItem) = Type("FormField")
					 OR TypeOf(FormItem)  = Type("FormTable") Then
						FormItem.ReadOnly = False;
					Else
						FormItem.Enabled = True;
					EndIf;
				EndIf;
			EndDo;
		EndIf;
	EndDo;
	
EndProcedure
