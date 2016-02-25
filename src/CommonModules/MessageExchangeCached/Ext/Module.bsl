////////////////////////////////////////////////////////////////////////////////
// MessageExchangeCached: message exchange mechanism.
//
////////////////////////////////////////////////////////////////////////////////

#Region InternalProceduresAndFunctions

// Returns the WSProxy object reference for the specified exchange node.
//
// Parameters:
// Endpoint - ExchangePlanRef.
//
Function WSEndpointProxy(Endpoint, Timeout) Export
	
	SettingsStructure = InformationRegisters.ExchangeTransportSettings.TransportSettingsWS(Endpoint);
	
	ErrorMessageString = "";
	
	Result = MessageExchangeInternal.GetWSProxy(SettingsStructure, ErrorMessageString, Timeout);
	
	If Result = Undefined Then
		Raise ErrorMessageString;
	EndIf;
	
	Return Result;
EndFunction

// Returns the manager array of the catalogs which can be used
// for massage keeping.
//
Function GetMessageCatalogs() Export
	
	CatalogArray = New Array();
	
	If CommonUseCached.IsSeparatedConfiguration() Then
		MessagesSaaSDataSeparationModule = CommonUse.CommonModule("MessagesSaaSDataSeparation");
		MessagesSaaSDataSeparationModule.OnFillMessageCatalogs(CatalogArray);
	EndIf;
	
	CatalogArray.Add(Catalogs.SystemMessages);
	
	Return CatalogArray;
	
EndFunction

#EndRegion
