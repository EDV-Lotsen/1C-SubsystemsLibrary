////////////////////////////////////////////////////////////////////////////////
// Data area backup subsystem.
//  
////////////////////////////////////////////////////////////////////////////////

#Region InternalProceduresAndFunctions

Function GetSettingsFormParameters(Val DataArea) Export
	
	ErrorInfo = Undefined;
	Parameters = Proxy().GetSettingsFormParameters(
		DataArea,
		AreaKey(),
		ErrorInfo);
	HandleWebServiceErrorInfo(ErrorInfo, 
"GetSettingsFormParameters"); // Do not localize the operation name
	
	Return XDTOSerializer.ReadXDTO(Parameters);
	
EndFunction

Function GetAreaSettings(Val DataArea) Export
	
	ErrorInfo = Undefined;
	Parameters = Proxy().GetZoneSettings(
		DataArea,
		AreaKey(),
		ErrorInfo);
	HandleWebServiceErrorInfo(ErrorInfo, "GetZoneSettings"); // Do not localize the operation name
	
	Return XDTOSerializer.ReadXDTO(Parameters);
	
EndFunction

Procedure SetAreaSettings(Val DataArea, Val NewSettings, Val InitialSettings) Export
	
	ErrorInfo = Undefined;
	Proxy().SetZoneSettings(
		DataArea,
		AreaKey(),
		XDTOSerializer.WriteXDTO(NewSettings),
		XDTOSerializer.WriteXDTO(InitialSettings),
		ErrorInfo);
	HandleWebServiceErrorInfo(ErrorInfo, "SetZoneSettings"); // Do not localize the operation name
	
EndProcedure

Function GetStandardSettings() Export
	
	ErrorInfo = Undefined;
	Parameters = Proxy().GetDefaultSettings(
		ErrorInfo);
	HandleWebServiceErrorInfo(ErrorInfo, "GetDefaultSettings"); // Do not localize the operation name
	
	Return XDTOSerializer.ReadXDTO(Parameters);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// AUXILIARY PROCEDURES AND FUNCTIONS

Function AreaKey()
	
	SetPrivilegedMode(True);
	Return Constants.DataAreaKey.Get();
	
EndFunction

Function Proxy()
	
	SetPrivilegedMode(True);
	ServiceManagerURL = Constants.InternalServiceManagerURL.Get();
	If Not ValueIsFilled(ServiceManagerURL) Then
		Raise(NStr("en = 'Service manager connection parameters are not specified.'"));
	EndIf;
	
	ServiceURL = ServiceManagerURL + "/ws/ZoneBackupControl_1_0_2_1?wsdl";
	UserName = Constants.AuxiliaryServiceManagerUserName.Get();
	UserPassword = Constants.AuxiliaryServiceManagerUserPassword.Get();
	
	Proxy = CommonUse.WSProxy(ServiceURL, "http://www.1c.ru/1cFresh/ZoneBackupControl/1.0.2.1",
		"ZoneBackupControl_1_0_2_1", , UserName, UserPassword, 10);
		
	Return Proxy;
	
EndFunction

// Handles web service errors. If the passed error info is not empty,
// writes the error details to the event log and raises an exception with the brief 
// error description.
//
Procedure HandleWebServiceErrorInfo(Val ErrorInfo, Val OperationName)
	
	SaaSOperations.HandleWebServiceErrorInfo(
		ErrorInfo,
		DataAreaBackupCached.SubsystemNameForEventLogEvents(),
		"ZoneBackupControl", // Do not localize this parameter
		OperationName);
	
EndProcedure

#EndRegion
