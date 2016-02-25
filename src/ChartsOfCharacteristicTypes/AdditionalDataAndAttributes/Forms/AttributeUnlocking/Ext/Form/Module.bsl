
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardDataProcessor)
	
	// Skipping the initialization to guarantee that the form will be received if the autotest parameter is passed.
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	If PropertyManagementInternal.AdditionalPropertyUsed(Parameters.Ref) Then
		
		Items.UserDialogs.CurrentPage = Items.ObjectUsed;
		Items.AllowEdit.DefaultButton = True;
		
		If Parameters.IsAdditionalAttribute = True Then
			Items.Warnings.CurrentPage = Items.AdditionalAttributeWarning;
		Else
			Items.Warnings.CurrentPage = Items.AdditionalDataWarning;
		EndIf;
	Else
		Items.UserDialogs.CurrentPage = Items.ObjectNotUsed;
		Items.OK.DefaultButton = True;
		
		If Parameters.IsAdditionalAttribute = True Then
			Items.Comments.CurrentPage = Items.AdditionalAttributeNote;
		Else
			Items.Comments.CurrentPage = Items.AdditionalDataNote;
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure AllowEdit(Command)
	
	UnlockableAttributes = New Array;
	UnlockableAttributes.Add("ValueType");
	
	Close();
	
	ObjectAttributeEditProhibitionClient.SetFormItemEnabled(
		FormOwner, UnlockableAttributes);
	
EndProcedure

#EndRegion
