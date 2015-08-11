////////////////////////////////////////////////////////////////////////////////
// Base functionality subsystem.
//
//////////////////////////////////////////////////////////////////////////////// 

////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// Gets the document number to print.
//
// Parameters:
// ObjectNumber - String - object code or number; 
// StandardProcessing - Boolean - if the procedure returns False then ObjectNumber 
// output parameter value will be taken 
// 
Procedure GetNumberForPrinting(ObjectNumber, StandardProcessing) Export
	
	// StandardSubsystems.ObjectPrefixation
	//ObjectNumber = ObjectPrefixationClientServer.GetNumberForPrinting(ObjectNumber);
	//StandardProcessing = False;
	// End StandardSubsystems.ObjectPrefixation
	
EndProcedure