////////////////////////////////////////////////////////////////////////////////
// Properties subsystem
// 
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// Opens a form to edit sets of additional attributes.
//
// Parameters:
//  Form        - ManagedForm pre-customized in
//                PropertyManagement.OnCreateAtServer()
//

Procedure EditPropertyContent(Form, Ref = Undefined) Export
	
	Sets = Form.Properties_ObjectAdditionalAttributeSets;
	
	If Sets.Count() = 0
	 Or Not ValueIsFilled(Sets[0].Value) Then
		
		ShowMessageBox(,
			NStr("en = 'Failure to get custom field sets of the object.
			           |
			           |Perhaps the necessary object fields are not filled.'"));
	
	Else
		FormParameters = New Structure;
		FormParameters.Insert("PurposeUseKey", "AdditionalAttributeSets");
		
		OpenForm("Catalog.AdditionalDataAndAttributeSets.ListForm", FormParameters);
		
		GoParameters = New Structure;
		GoParameters.Insert("Set", Sets[0].Value);
		GoParameters.Insert("Property", Undefined);
		GoParameters.Insert("IsAdditionalData", False);
		
		BeginningLength = StrLen("AddAttributeValue_");
		If Upper(Left(Form.CurrentItem.Name, BeginningLength)) = Upper("AddAttributeValue_") Then
			
			SetID      = StrReplace(Mid(Form.CurrentItem.Name, BeginningLength +  1, 36), "x","-");
			PropertyID = StrReplace(Mid(Form.CurrentItem.Name, BeginningLength + 38, 36), "x","-");
			
			If StringFunctionsClientServer.IsUUID(Lower(SetID)) Then
				GoParameters.Insert("Set", SetID);
			EndIf;
			
			If StringFunctionsClientServer.IsUUID(Lower(PropertyID)) Then
				GoParameters.Insert("Property", PropertyID);
			EndIf;
		EndIf;
		
		Notify("Go_AdditionalDataAndAttributeSets", GoParameters);
	EndIf;
	
EndProcedure

// Defines that the specified event is an event that changes a property set.
// 
// Returns:
//  Boolean - If True then this is a notification about change in the property 
//            set and it must be handled in the form.
//
Function ProcessNofifications(Form, EventName, Parameter) Export
	
	If Not Form.Properties_UseProperties
	 Or Not Form.Properties_UseAdditionalAttributes Then
		
		Return False;
	EndIf;
	
	If EventName = "Write_AdditionalDataAndAttributeSets" Then
		Return Form.Properties_ObjectAdditionalAttributeSets.FindByValue(Parameter.Ref) <> Undefined;
		
	ElsIf EventName = "Write_AdditionalDataAndAttributes" Then
		Filter = New Structure("Property", Parameter.Ref);
		Return Form.Properties_AdditionalAttributeDetails.FindRows(Filter).Count() > 0;
		
	EndIf;
	
	Return False;
	
EndFunction

#EndRegion
