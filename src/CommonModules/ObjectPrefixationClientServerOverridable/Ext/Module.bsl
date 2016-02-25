////////////////////////////////////////////////////////////////////////////////
// Object prefixation subsystem
//
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// On get number for printing event handler.
// The event occurs before the standard processing of getting a number.
// The handler can override the default behavior of the system when getting a number for printing.
// 
// Parameters:
//  ObjectNumber         - String  - object number or object code under processing
//  StandardProcessing   - Boolean - standard processing flag; if the flag value is set to false,
//                       then number generation standard processing will not be executed
// 
// Handler code implementation example:
// 
// ObjectNumber       = ObjectPrefixationClientServer.DeleteCustomPrefixesFromObjectNumber (ObjectNumber);
// StandardProcessing = False;
// 
Procedure OnGetNumberForPrinting(ObjectNumber, StandardProcessing) Export
	
EndProcedure

#EndRegion
