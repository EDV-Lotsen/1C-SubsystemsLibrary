////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Filter.Property("Recipient") Then
		Items.Recipient.Visible = False;
	EndIf;
	
EndProcedure
