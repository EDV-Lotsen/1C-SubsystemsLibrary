////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Parameters.Filter.Insert("Recipient", MessageExchangeInternal.ThisNode());
	
EndProcedure
