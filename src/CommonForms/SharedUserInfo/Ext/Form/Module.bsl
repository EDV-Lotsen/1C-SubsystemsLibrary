
////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("Autotest") Then // Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
		Return;
	EndIf;
	
	MessagePattern = NStr("en = 'Cannot view user account %1. This is an internal account used by service administrators.'");
	Items.SharedUser.Title = 
		StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, Parameters.Key.Description);
	
EndProcedure
