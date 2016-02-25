
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	If Parameters.Filter.Property("Recipient") Then
		Items.Recipient.Visible = False;
	EndIf;
	
EndProcedure

#EndRegion
