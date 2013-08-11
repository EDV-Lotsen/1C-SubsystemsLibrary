////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If ValueIsFilled(Record.Recipient) Then
		
		Items.Recipient.Visible = False;
		
	EndIf;
	
EndProcedure
