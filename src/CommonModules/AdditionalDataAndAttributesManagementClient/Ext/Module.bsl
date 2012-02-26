
////////////////////////////////////////////////////////////////////////////////
// COMMON USE PROCEDURES

// Edit set of properties
//
Procedure EditContentOfProperties(Form, Ref) Export
	
	Sets = Form.__AddDataNAttrs_MainSet;
	// If CatalogRef.AdditionalDataAndAttributesSettings was returned, then this is the object with a single set of properties
	If TypeOf(Sets) = Type("CatalogRef.AdditionalDataAndAttributesSettings") Then
		If ValueIsFilled(Sets) Then
			SetPropertiesFormParameters = New Structure("Key", Form.__AddDataNAttrs_MainSet);
			OpenForm("Catalog.AdditionalDataAndAttributesSettings.Form.ItemForm", SetPropertiesFormParameters);
		Else
			DoMessageBox(NStr("en = 'Set of object properties is not available. Some fields are not filled.'"));
		EndIf;
		
	// ...Else - this is the object that may have several sets of properties
	// and some set has to be selected
	Else
		If Sets.Count() = 1 Then
			Item = Sets.Get(0);
		Else
			Item = Sets.ChooseItem();
			If Item = Undefined Then
				Return;
			EndIf;
			
		EndIf;
		SetPropertiesFormParameters = New Structure("Key", Item.Value);
		OpenForm("Catalog.AdditionalDataAndAttributesSettings.Form.ItemForm", SetPropertiesFormParameters);
		
	EndIf;
	
EndProcedure

// Check, if alert is related to the modification of a set of properties and
// if it has to be processed in the current form
Function ProcessAlerts(Form, EventName, Parameter) Export
	
	If (EventName <> "PropertiesSetChanged") OR Not Form.__AddDataNAttrs_UseAdditionalData Then
		Return False;
		
	ElsIf Form.__AddDataNAttrs_MainSet = Parameter Then
		Return True;
		
	ElsIf (TypeOf(Form.__AddDataNAttrs_MainSet) = Type("ValueList"))
		And (Form.__AddDataNAttrs_MainSet.FindByValue(Parameter) <> Undefined) Then
		Return True;
		
	Else
		
		Return False;
		
	EndIf;
	
EndFunction
