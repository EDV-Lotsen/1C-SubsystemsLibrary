////////////////////////////////////////////////////////////////////////////////
// DATA EXCHANGE MANAGEMENT MESSAGE INTERFACE HANDLER MODULE
//
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// Returns the namespace of the current message interface version (it is
// the version used in the caller script).
Function Package() Export
	
	Return "http://www.1c.ru/SaaS/Exchange/Manage";
	
EndFunction

// Returns the current message interface version (it is the version used in
// the caller script).
Function Version() Export
	
	Return "2.1.2.1";
	
EndFunction

// Returns the name of the message API.
Function Interface() Export
	
	Return "ExchangeManage";
	
EndFunction

// Registers message handlers as message exchange channel handlers.
//
// Parameters:
//  HandlerArray - Array.
//
Procedure MessageChannelHandlers(Val HandlerArray) Export
	
	HandlerArray.Add(DataExchangeMessagesManagementMessageHandler_2_1_2_1);
	
EndProcedure

// Registers message translation handlers.
//
// Parameters:
//  HandlerArray - Array.
//
Procedure MessageTranslationHandlers(Val HandlerArray) Export
	
EndProcedure

// Returns {http://www.1c.ru/SaaS/Exchange/Manage/a.b.c.d}SetupExchangeStep1 
// message type.
//
// Parameters:
//  PackageUsed - String – namespace of the message interface version
//                     whose message type is retrieved.
//
// Returns:
//  XDTOType
//
Function SetUpExchangeStep1Message(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "SetupExchangeStep1");
	
EndFunction

// Returns {http://www.1c.ru/SaaS/Exchange/Manage/a.b.c.d}SetupExchangeStep2 
// message type.
//
// Parameters:
//  PackageUsed - String – namespace of the message interface version
//                     whose message type is retrieved.
//
// Returns:
//  XDTOType
//
Function SetUpExchangeStep2Message(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "SetupExchangeStep2");
	
EndFunction

// Returns {http://www.1c.ru/SaaS/Exchange/Manage/a.b.c.d}DownloadMessage
// messages type.
//
// Parameters:
//  PackageUsed - String – namespace of the message interface version
//                     whose message type is retrieved.
//
// Returns:
//  XDTOType
//
Function ImportExchangeMessageMessage(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "DownloadMessage");
	
EndFunction

// Returns {http://www.1c.ru/SaaS/Exchange/Manage/a.b.c.d}GetData 
// messages type.
//
// Parameters:
//  PackageUsed - String – namespace of the message interface version
//                     whose message type is retrieved.
//
// Returns:
//  XDTOType
//
Function GetCorrespondentDataMessage(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "GetData");
	
EndFunction

// Returns {http://www.1c.ru/SaaS/Exchange/Manage/a.b.c.d}GetCommonNodeData  
// message type.
//
// Parameters:
//  PackageUsed - String – namespace of the message interface version
//                     whose message type is retrieved.
//
// Returns:
//  XDTOType
//
Function GetCorrespondentNodeCommonDataMessage(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "GetCommonNodeData");
	
EndFunction

// Returns {http://www.1c.ru/SaaS/Exchange/Manage/a.b.c.d}GetCorrespondentParams 
// message type.
//
// Parameters:
//  PackageUsed - String – namespace of the message interface version
//                     whose message type is retrieved.
//
// Returns:
//  XDTOType
//
Function GetCorrespondentAccountParametersMessage(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "GetCorrespondentParams");
	
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
