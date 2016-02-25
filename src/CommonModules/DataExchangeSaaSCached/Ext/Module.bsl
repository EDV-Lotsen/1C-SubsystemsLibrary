////////////////////////////////////////////////////////////////////////////////
// DataExchangeSaaSCached: data exchange mechanism.
//
////////////////////////////////////////////////////////////////////////////////

#Region InternalProceduresAndFunctions

// Returns a reference to the WSProxy object (version 1.0.6.5) of the synchronization service.
//
// Returns:
// WSProxy.
//
Function GetExchangeServiceWSProxy() Export
	
	TransportSettings = InformationRegisters.ExchangeTransportSettings.TransportSettingsWS(
		SaaSOperationsCached.ServiceManagerEndpoint());
	
	SettingsStructure = New Structure;
	SettingsStructure.Insert("WSURL",                  TransportSettings.WSURL);
	SettingsStructure.Insert("WSUserName",             TransportSettings.WSUserName);
	SettingsStructure.Insert("WSPassword",             TransportSettings.WSPassword);
	SettingsStructure.Insert("WSServiceName",          "ManagementApplicationExchange_1_0_6_5");
	SettingsStructure.Insert("NamespaceWebServiceURL", "http://www.1c.ru/SaaS/1.0/WS/ManagementApplicationExchange_1_0_6_5");
	SettingsStructure.Insert("WSTimeout",              20);
	
	Result = DataExchangeServer.GetWSProxyByConnectionParameters(SettingsStructure);
	
	If Result = Undefined Then
		Raise NStr("en = 'Error getting the synchronization web service of the managed application.'");
	EndIf;
	
	Return Result;
EndFunction

// Returns a reference to the WSProxy object of the correspondent specified in the exchange plan node.
//
// Parameters:
// InfobaseNode       - ExchangePlanRef.
// ErrorMessageString - String - error message text.
//
// Returns:
// WSProxy.
//
Function GetCorrespondentWSProxy(InfobaseNode, ErrorMessageString = "") Export
	
	SettingsStructure = InformationRegisters.DataAreaExchangeTransportSettings.TransportSettingsWS(InfobaseNode);
	SettingsStructure.Insert("WSServiceName",          "RemoteAdministrationOfExchange");
	SettingsStructure.Insert("NamespaceWebServiceURL", "http://www.1c.ru/SaaS/1.0/WS/RemoteAdministrationOfExchange");
	SettingsStructure.Insert("WSTimeout",              20);
	
	Return DataExchangeServer.GetWSProxyByConnectionParameters(SettingsStructure, ErrorMessageString);
	
EndFunction

// Returns a reference to the WSProxy object (version 2.0.1.6) of the correspondent specified in the exchange plan node.
//
// Parameters:
// InfobaseNode       - ExchangePlanRef.
// ErrorMessageString - String - error message text.
//
// Returns:
// WSProxy.
//
Function GetCorrespondentWSProxy_2_0_1_6(InfobaseNode, ErrorMessageString = "") Export
	
	SettingsStructure = InformationRegisters.DataAreaExchangeTransportSettings.TransportSettingsWS(InfobaseNode);
	SettingsStructure.Insert("WSServiceName", "RemoteAdministrationOfExchange_2_0_1_6");
	SettingsStructure.Insert("NamespaceWebServiceURL", "http://www.1c.ru/SaaS/1.0/WS/RemoteAdministrationOfExchange_2_0_1_6");
	SettingsStructure.Insert("WSTimeout", 20);
	
	Return DataExchangeServer.GetWSProxyByConnectionParameters(SettingsStructure, ErrorMessageString);
EndFunction

// Returns True if the synchronization is supported in SaaS mode.
//
Function DataSynchronizationSupported() Export
	
	Return DataSynchronizationExchangePlans().Count() > 0;
	
EndFunction

// A SaaS synchronization exchange plan must match the following conditions:
//   It is included in the SL data exchange subsystem.
//   It is separated.
//   It is not a DIB exchange plan.
//   It is intended for exchange in SaaS mode (ExchangePlanUsedInSaaS = True).
//
Function DataSynchronizationExchangePlans() Export
	
	Result = New Array;
	
	For Each ExchangePlan In Metadata.ExchangePlans Do
		
		If Not ExchangePlan.DistributedInfobase
			And DataExchangeCached.ExchangePlanUsedInSaaS(ExchangePlan.Name)
			And DataExchangeServer.IsSLSeparatedExchangePlan(ExchangePlan.Name) Then
			
			Result.Add(ExchangePlan.Name);
			
		EndIf;
		
	EndDo;
	
	Return Result;
EndFunction

// Returns True if the exchange plan is used for synchronization in SaaS mode.
//
Function IsDataSynchronizationExchangePlan(Val ExchangePlanName) Export
	
	Return DataSynchronizationExchangePlans().Find(ExchangePlanName) <> Undefined;
	
EndFunction

#EndRegion
