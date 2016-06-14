////////////////////////////////////////////////////////////////////////////////
// DATA EXCHANGE ADMINISTRATION MANAGEMENT MESSAGE INTERFACE HANDLER
//
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// Returns the namespace of the current message interface version (it is
// the version used in the caller script).
Function Package() Export
	
	Return "http://www.1c.ru/SaaS/ExchangeAdministration/Manage";
	
EndFunction

// Returns the current message interface version (it is the version used in
// the caller script).
Function Version() Export
	
	Return "2.1.2.1";
	
EndFunction

// Returns the name of the message API.
Function Interface() Export
	
	Return "ExchangeAdministrationManage";
	
EndFunction

// Registers message handlers as message exchange channel handlers.
//
// Parameters:
//  HandlerArray - Array.
//
Procedure MessageChannelHandlers(Val HandlerArray) Export
	
	HandlerArray.Add(MessagesDataExchangeAdministrationManagementMessageHandler_2_1_2_1);
	
EndProcedure

// Registers message translation handlers.
//
// Parameters:
//  HandlerArray - Array.
//
Procedure MessageTranslationHandlers(Val HandlerArray) Export
	
EndProcedure

// Returns {http://www.1c.ru/SaaS/ExchangeAdministration/Manage/a.b.c.d}ConnectCorrespondent 
// message type.
//
// Parameters:
//  PackageUsed - String – namespace of the message interface version
//                     whose message type is retrieved.
//
// Returns:
//  XDTOType
//
Function ConnectCorrespondentMessage(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "ConnectCorrespondent");
	
EndFunction

// Returns {http://www.1c.ru/SaaS/ExchangeAdministration/Manage/a.b.c.d}SetTransportParams 
// message type.
//
// Parameters:
//  PackageUsed - String – namespace of the message interface version
//                     whose message type is retrieved.
//
// Returns:
//  XDTOType
//
Function SetTransportSettingsMessage(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "SetTransportParams");
	
EndFunction

// Returns {http://www.1c.ru/SaaS/ExchangeAdministration/Manage/a.b.c.d}GetSyncSettings 
// message type.
//
// Parameters:
//  PackageUsed - String – namespace of the message interface version
//                     whose message type is retrieved.
//
// Returns:
//  XDTOType
//
Function GetDataSynchronizationSettingsMessage(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "GetSyncSettings");
	
EndFunction

// Returns {http://www.1c.ru/SaaS/ExchangeAdministration/Manage/a.b.c.d}DeleteSync 
// message type.
//
// Parameters:
//  PackageUsed - String – namespace of the message interface version
//                     whose message type is retrieved.
//
// Returns:
//  XDTOType
//
Function DeleteSynchronizationSettingsMessage(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "DeleteSync");
	
EndFunction

// Returns {http://www.1c.ru/SaaS/ExchangeAdministration/Manage/a.b.c.d}EnableSync 
// message type.
//
// Parameters:
//  PackageUsed - String – namespace of the message interface version
//                     whose message type is retrieved.
//
// Returns:
//  XDTOType
//
Function EnableSynchronizationMessage(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "EnableSync");
	
EndFunction

// Returns {http://www.1c.ru/SaaS/ExchangeAdministration/Manage/a.b.c.d}DisableSync 
// message type.
//
// Parameters:
//  PackageUsed - String – namespace of the message interface version
//                     whose message type is retrieved.
//
// Returns:
//  XDTOType
//
Function DisableDataSynchronizationMessage(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "DisableSync");
	
EndFunction

// Returns {http://www.1c.ru/SaaS/ExchangeAdministration/Manage/a.b.c.d}PushSync 
// messages type.
//
// Parameters:
//  PackageUsed - String – namespace of the message interface version
//                     whose message type is retrieved.
//
// Returns:
//  XDTOType
//
Function PushSynchronizationMessage(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "PushSync");
	
EndFunction

// Returns {http://www.1c.ru/SaaS/ExchangeAdministration/Manage/a.b.c.d}PushTwoApplicationSync 
// message type.
//
// Parameters:
//  PackageUsed - String – namespace of the message interface version
//                     whose message type is retrieved.
//
// Returns:
//  XDTOType
//
Function PushSynchronizationBetweenTwoApplicationsMessage(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "PushTwoApplicationSync");
	
EndFunction

// Returns {http://www.1c.ru/SaaS/ExchangeAdministration/Manage/a.b.c.d}ExecuteSync 
// message type.
//
// Parameters:
//  PackageUsed - String – namespace of the message interface version
//                     whose message type is retrieved.
//
// Returns:
//  XDTOType
//
Function PerformDataSynchronizationMessage(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "ExecuteSync");
	
EndFunction

#EndRegion

#Region InternalProceduresAndFunctions

Function GenerateMessageType(Val PackageUsed, Val Type)
	
	If PackageUsed = Undefined Then
		PackageUsed = Package();
	EndIf;
	
	Return XDTOFactory.Type(PackageUsed, Type);
	
EndFunction

#EndRegion
