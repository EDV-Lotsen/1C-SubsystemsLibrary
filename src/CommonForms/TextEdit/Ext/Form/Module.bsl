

&AtServer
// Procedure - handler of event OnCreateAtServer.
//
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	If Parameters.Property("Text") Then
		Text = Parameters.Text;
	EndIf;
	
	If Parameters.Property("Title") Then
		ThisForm.Title = Parameters.Title;
	EndIf;
	
EndProcedure

&AtClient
// Procedure - handler of command Ok.
//
Procedure Ok(Command)
	
	Close(Text);
	
EndProcedure

