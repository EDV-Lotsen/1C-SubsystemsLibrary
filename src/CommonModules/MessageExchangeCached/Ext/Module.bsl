////////////////////////////////////////////////////////////////////////////////
// MessageExchangeCached: message exchange engine.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

// Returns a WSProxy object reference for the specified exchange node.
//
// Parameters:
// EndPoint - ExchangePlanRef.
//
Function WSEndPointProxy(EndPoint) Export
	
	SettingsStructure = InformationRegisters.ExchangeTransportSettings.GetWSTransportSettings(EndPoint);
	
	ErrorMessageString = "";
	
	Result = MessageExchangeInternal.GetWSProxy(SettingsStructure, ErrorMessageString);
	
	If Result = Undefined Then
		Raise ErrorMessageString;
	EndIf;
	
	Return Result;
EndFunction
