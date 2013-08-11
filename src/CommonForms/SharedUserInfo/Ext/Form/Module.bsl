
////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the SelfTest parameter is passed.
	If Parameters.Property("SelfTest") Then
		Return;
	EndIf;
	
	MessagePattern = NStr("en = 'Details of the user %1 are not available, because %1 is the
		|service account, which is used by service administrators.'");
	Items.SharedUser.Title = 
		StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, Parameters.Key.Description);
	
EndProcedure
