
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("Autotest") Then
		Return;
	EndIf;
	
	Raise NStr("en='The data processor cannot be opened manually.'");
	
EndProcedure
