
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	ReadOnly = True;
	
	SetPropertyTypes = PropertyManagementInternal.SetPropertyTypes(Object.Ref);
	UseAdditionalAttributes = SetPropertyTypes.AdditionalAttributes;
	UseAdditionalData  = SetPropertyTypes.AdditionalData;
	
	If UseAdditionalAttributes And UseAdditionalData Then
		Title = Object.Description + " " + NStr("en = '(Custom field and data set)'")
		
	ElsIf UseAdditionalAttributes Then
		Title = Object.Description + " " + NStr("en = '(Custom field set)'")
		
	ElsIf UseAdditionalData Then
		Title = Object.Description + " " + NStr("en = '(Custom data set)'")
	EndIf;
	
	If Not UseAdditionalAttributes And Object.AdditionalAttributes.Count() = 0 Then
		Items.AdditionalAttributes.Visible = False;
	EndIf;
	
	If Not UseAdditionalData And Object.AdditionalData.Count() = 0 Then
		Items.AdditionalData.Visible = False;
	EndIf;
	
EndProcedure

#EndRegion
