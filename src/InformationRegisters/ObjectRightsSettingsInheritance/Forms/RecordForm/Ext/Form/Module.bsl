
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	ReadOnly = True;
	
EndProcedure

&AtClient
Procedure EnableEditing(Command)
	
	ReadOnly = False;
	
EndProcedure



