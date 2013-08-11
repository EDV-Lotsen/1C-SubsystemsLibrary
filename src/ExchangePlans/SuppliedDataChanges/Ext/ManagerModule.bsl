
////////////////////////////////////////////////////////////////////////////////
// INTERFACE

Function DataExchangeVersion() Export
	
	Return Undefined;
	
EndFunction

Function ExchangePlanUsedInServiceMode() Export
	
	Return False;
	
EndFunction

// Determines whether the object registration mechanism is used.
//
// Return:
//  Boolean - True if the object registration mechanism is used for the current 
//            exchange plan, otherwise is False.
//
Function UseObjectChangeRecordMechanism() Export
	
	Return True;
	
EndFunction







