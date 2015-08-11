////////////////////////////////////////////////////////////////////////////////
// DataExchangeServiceModeCached: data exchange mechanism.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

// Returns a reference to the WSProxy object of the exchange service.
//
// Returns:
//  WSProxy.
//
Function GetExchangeServiceWSProxy() Export
	
	UserName = Constants.AuxiliaryServiceManagerUserName.Get();
	UserPassword = Constants.AuxiliaryServiceManagerUserPassword.Get();
	ServiceAddress = Constants.DataExchangeWebServiceURL.Get();
	
	SettingsStructure = New Structure;
	SettingsStructure.Insert("WSURL",                  ServiceAddress);
	SettingsStructure.Insert("WSUserName",             UserName);
	SettingsStructure.Insert("WSPassword",             UserPassword);
	SettingsStructure.Insert("WSServiceName",          "ManagementApplicationExchange");
	SettingsStructure.Insert("ServiceNamespaceWSURL", "http://1c-dn.com/SaaS/1.0/WS/ManagementApplicationExchange");
	
	Result = DataExchangeServer.GetWSProxyByConnectionParameters(SettingsStructure);
	
	If Result = Undefined Then
		Raise NStr("en = 'Error getting the data exchange web service of the management application.'");
	EndIf;
	
	Return Result;
EndFunction

// Returns a reference to the 1.0.6.5 version WSProxy object of the exchange service.
//
// Returns:
//  WSProxy.
//
Function GetExchangeServiceWSProxy_1_0_6_5() Export
	
	UserName = Constants.AuxiliaryServiceManagerUserName.Get();
	UserPassword = Constants.AuxiliaryServiceManagerUserPassword.Get();
	ServiceAddress = Constants.DataExchangeWebServiceURL.Get();
	
	SettingsStructure = New Structure;
	SettingsStructure.Insert("WSURL",                  ServiceAddress);
	SettingsStructure.Insert("WSUserName",             UserName);
	SettingsStructure.Insert("WSPassword",             UserPassword);
	SettingsStructure.Insert("WSServiceName",           "ManagementApplicationExchange_1_0_6_5");
	SettingsStructure.Insert("ServiceNamespaceWSURL", "http://1c-dn.com/SaaS/1.0/WS/ManagementApplicationExchange_1_0_6_5");
	
	Result = DataExchangeServer.GetWSProxyByConnectionParameters(SettingsStructure);
	
	If Result = Undefined Then
		Raise NStr("en = 'Error getting the data exchange web service of the management application.'");
	EndIf;
	
	Return Result;
EndFunction

// Returns a reference to the WSProxy object of the correspondent that the exchange
// plan node identifies.
//
// Parameters:
//  InfoBaseNode - ExchangePlanRef.
//  ErrorMessageString - String - error messages text.
//
// Returns:
//  WSProxy.
//
Function GetCorrespondentWSProxy(InfoBaseNode, ErrorMessageString = "") Export
	
	SettingsStructure = InformationRegisters.ExchangeTransportSettings.GetWSTransportSettings(InfoBaseNode);
	SettingsStructure.Insert("WSServiceName", "RemoteExchangeAdministration");
	SettingsStructure.Insert("ServiceNamespaceWSURL", "http://www.1c-dc.com/SaaS/1.0/WS/ExchangeRemoteAdministration");
	
	Return DataExchangeServer.GetWSProxyByConnectionParameters(SettingsStructure, ErrorMessageString);
	
EndFunction

// Returns a reference to the 2.0.1.6 version WSProxy object of the correspondent that
// the exchange plan node identifies.
//
// Parameters:
//  InfoBaseNode - ExchangePlanRef.
//  ErrorMessageString - String - error messages text.
//
// Returns:
//  WSProxy.
//
Function GetCorrespondentWSProxy_2_0_1_6(InfoBaseNode, ErrorMessageString = "") Export
	
	SettingsStructure = InformationRegisters.ExchangeTransportSettings.GetWSTransportSettings(InfoBaseNode);
	SettingsStructure.Insert("WSServiceName", "RemoteExchangeAdministration_2_0_1_6");
	SettingsStructure.Insert("ServiceNamespaceWSURL", "http://1c-dn.com/SaaS/1.0/WS/ExchangeRemoteAdministration_2_0_1_6");
	
	Return DataExchangeServer.GetWSProxyByConnectionParameters(SettingsStructure, ErrorMessageString);
EndFunction

// Determines whether the exchange plan that is identified by name is used in the service mode.
// To provide this check, all exchange plans must have the
// ExchangePlanUsedInServiceMode function in module managers. This function must
// returns True or False.
//
// Parameters:
//  ExchangePlanName - String.
//
// Returns:
//  Boolean.
//
Function ExchangePlanUsedInServiceMode(Val ExchangePlanName) Export
	
	Try
		Result = ExchangePlans[ExchangePlanName].ExchangePlanUsedInServiceMode();
	Except
		Result = False;
	EndTry;
	
	Return Result;
EndFunction















