////////////////////////////////////////////////////////////////////////////////
// Object prefixation subsystem. 
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// "Getting a number for printing" event handler.
// The event occurs before standard processing of number retrieval.
// You can override standard processing of getting the number for printing in this procedure.
// 
// Parameters:
//  ObjectNumber       - String - object number or code to be processed.
//  StandardProcessing – Boolean – flag that shows whether standard number processing
//                       will be executed.
// 
// Example:
// 
// ObjectNumber = ObjectPrefixationClientServer.DeleteCustomPrefixesFromObjectNumber(ObjectNumber);
// StandardProcessing = False;
// 
Procedure OnGetNumberForPrinting(ObjectNumber, StandardProcessing) Export
	
	
EndProcedure
