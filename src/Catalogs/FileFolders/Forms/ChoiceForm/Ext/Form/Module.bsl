

&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	If Parameters.Property("CurrentFolder") Then
		Items.List.CurrentRow = Parameters.CurrentFolder;
	EndIf;	
EndProcedure
