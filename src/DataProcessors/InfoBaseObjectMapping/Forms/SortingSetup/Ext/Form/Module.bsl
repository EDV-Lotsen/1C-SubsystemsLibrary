////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the SelfTest parameter is passed.
	If Parameters.Property("SelfTest") Then
		Return;
	EndIf;
	
	SortTable.Load(Parameters.SortTable.Unload());
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure Apply(Command)
	
	ThisForm.Close(SortTable);
	
EndProcedure

&AtClient
Procedure Cancel(Command)
	
	ThisForm.Close(Undefined);
	
EndProcedure
