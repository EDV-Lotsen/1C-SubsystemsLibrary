
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	 
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	If Not ValueIsFilled(Object.Ref)
	   And Parameters.FillingValues.Property("Description") Then
		
		Object.Description = Parameters.FillingValues.Description;
	EndIf;
	
	If Not Parameters.HideOwner Then
		Items.Owner.Visible = True;
	EndIf;
	
	If TypeOf(Parameters.ShowWeight) = Type("Boolean") Then
		ShowWeight = Parameters.ShowWeight;
	Else
		ShowWeight = CommonUse.ObjectAttributeValue(Object.Owner, "AdditionalValuesWithWeight");
	EndIf;
	
	If ShowWeight = True Then
		Items.Weight.Visible = True;
	Else
		Items.Weight.Visible = False;
		Object.Weight = 0;
	EndIf;
	
	SetTitle();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Change_ValueIsCharacterizedByWeightCoefficient"
	   And Source = Object.Owner Then
		
		If Parameter = True Then
			Items.Weight.Visible = True;
		Else
			Items.Weight.Visible = False;
			Object.Weight = 0;
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	SetTitle();
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("Write_ObjectPropertyValueHierarchy",
		New Structure("Ref", Object.Ref), Object.Ref);
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

Procedure SetTitle()
	
	AttributeValues = CommonUse.ObjectAttributeValues(
		Object.Owner, "Title, ValueFormTitle");
	
	PropertyName = TrimAll(AttributeValues.ValueFormTitle);
	
	If NOT IsBlankString(PropertyName) Then
		If ValueIsFilled(Object.Ref) Then
			Title = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = '%1 (%2)'"),
				Object.Description,
				PropertyName);
		Else
			Title = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = '%1 (Create)'"), PropertyName);
		EndIf;
	Else
		PropertyName = String(AttributeValues.Title);
		
		If ValueIsFilled(Object.Ref) Then
			Title = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = '%1 (The %2 property value)'"),
				Object.Description,
				PropertyName);
		Else
			Title = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'The %1 property value (Create)'"), PropertyName);
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion
