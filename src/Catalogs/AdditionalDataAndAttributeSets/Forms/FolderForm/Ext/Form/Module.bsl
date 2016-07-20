
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardDataProcessor)
	
	// Skipping the initialization to guarantee that the form will be received if the autotest parameter is passed.
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	ReadOnly = True;
	
	SetPropertyTypes = PropertyManagementInternal.SetPropertyTypes(Object.Ref);
	UseAdditionalAttributes = SetPropertyTypes.AdditionalAttributes;
	UseAdditionalData  = SetPropertyTypes.AdditionalData;
	
	If UseAdditionalAttributes AND UseAdditionalData Then
		Title = Object.Description + " " + NStr("en = '(Group of custom field and data sets)'")
		
	ElsIf UseAdditionalAttributes Then
		Title = Object.Description + " " + NStr("en = '(Group of custom field sets)'")
		
	ElsIf UseAdditionalData Then
		Title = Object.Description + " " + NStr("en = '(Group of custom data sets)'")
	EndIf;
	
EndProcedure

#EndRegion
