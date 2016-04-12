////////////////////////////////////////////////////////////////////////////////
// HANDLER MODULE OF MESSAGE INTERFACE FOR MONITORING DATA EXCHANGE
//
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// Returns the namespace of the current message interface version (it is
// the version used in the caller script).
Function Package() Export
	
	Return "http://www.1c.ru/SaaS/Exchange/Control";
	
EndFunction

// Returns the current message interface version (it is the version used in 
// the caller script).
Function Version() Export
	
	Return "2.1.2.1";
	
EndFunction

// Returns the name of the message API.
Function Interface() Export
	
	Return "ExchangeControl";
	
EndFunction

// Registers message handlers as message exchange channel handlers.
//
// Parameters:
//  HandlerArray - Array.
//
Procedure MessageChannelHandlers(Val HandlerArray) Export
	
	HandlerArray.Add(DataExchangeMessagesControlMessageHandler_2_1_2_1);
	
EndProcedure

// Registers message translation handlers.
//
// Parameters:
//  HandlerArray - Array.
//
Procedure MessageTranslationHandlers(Val HandlerArray) Export
	
EndProcedure

// Returns {http://www.1c.ru/SaaS/Exchange/Control/a.b.c.d}SetupExchangeStep1Completed message type
//
// Parameters:
//  PackageUsed - String – namespace of the message interface version
//                     whose message type is retrieved.
//
// Returns:
//  XDTOType
//
Function ExchangeSetupStep1CompletedMessage(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "SetupExchangeStep1Completed");
	
EndFunction

// Returns {http://www.1c.ru/SaaS/Exchange/Control/a.b.c.d}SetupExchangeStep2Completed message type
//
// Parameters:
//  PackageUsed - String – namespace of the message interface version
//                     whose message type is retrieved.
//
// Returns:
//  XDTOType
//
Function ExchangeSetupStep2CompletedMessage(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "SetupExchangeStep2Completed");
	
EndFunction

// Returns {http://www.1c.ru/SaaS/Exchange/Control/a.b.c.d}SetupExchangeStep1Failed message type
//
// Parameters:
//  PackageUsed - String – namespace of the message interface version
//                     whose message type is retrieved.
//
// Returns:
//  XDTOType
//
Function ExchangeSetupErrorStep1Message(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "SetupExchangeStep1Failed");
	
EndFunction

// Returns {http://www.1c.ru/SaaS/Exchange/Control/a.b.c.d}SetupExchangeStep2Failed message type
//
// Parameters:
//  PackageUsed - String – namespace of the message interface version
//                     whose message type is retrieved.
//
// Returns:
//  XDTOType
//
Function ExchangeSetupErrorStep2Message(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "SetupExchangeStep2Failed");
	
EndFunction

// Returns {http://www.1c.ru/SaaS/Exchange/Control/a.b.c.d}DownloadMessageCompleted message type
//
// Parameters:
//  PackageUsed - String – namespace of the message interface version
//                     whose message type is retrieved.
//
// Returns:
//  XDTOType
//
Function ExchangeMessageImportCompletedMessage(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "DownloadMessageCompleted");
	
EndFunction

// Returns {http://www.1c.ru/SaaS/Exchange/Control/a.b.c.d}DownloadMessageFailed message type
//
// Parameters:
//  PackageUsed - String – namespace of the message interface version
//                     whose message type is retrieved.
//
// Returns:
//  XDTOType
//
Function ExchangeMessageImportErrorMessage(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "DownloadMessageFailed");
	
EndFunction

// Returns {http://www.1c.ru/SaaS/Exchange/Control/a.b.c.d}GettingDataCompleted message type
//
// Parameters:
//  PackageUsed - String – namespace of the message interface version
//                     whose message type is retrieved.
//
// Returns:
//  XDTOType
//
Function CorrespondentDataGettingCompletedMessage(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "GettingDataCompleted");
	
EndFunction

// Returns {http://www.1c.ru/SaaS/Exchange/Control/a.b.c.d}GettingCommonNodsDataCompleted message type
//
// Parameters:
//  PackageUsed - String – namespace of the message interface version
//                     whose message type is retrieved.
//
// Returns:
//  XDTOType
//
Function GettingCorrespondentNodeCommonDataCompletedMessage(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "GettingCommonNodsDataCompleted");
	
EndFunction

// Returns {http://www.1c.ru/SaaS/Exchange/Control/a.b.c.d}GettingDataFailed message type
//
// Parameters:
//  PackageUsed - String – namespace of the message interface version
//                     whose message type is retrieved.
//
// Returns:
//  XDTOType
//
Function CorrespondentDataGettingErrorMessage(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "GettingDataFailed");
	
EndFunction

// Returns {http://www.1c.ru/SaaS/Exchange/Control/a.b.c.d}GettingCommonNodsDataFailed message type
//
// Parameters:
//  PackageUsed - String – namespace of the message interface version
//                     whose message type is retrieved.
//
// Returns:
//  XDTOType
//
Function CorrespondentNodeCommonDataGettingErrorMessage(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "GettingCommonNodsDataFailed");
	
EndFunction

// Returns {http://www.1c.ru/SaaS/Exchange/Control/a.b.c.d}GettingCorrespondentParamsCompleted message type
//
// Parameters:
//  PackageUsed - String – namespace of the message interface version
//                     whose message type is retrieved.
//
// Returns:
//  XDTOType
//
Function GettingCorrespondentAccountingParametersCompletedMessage(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "GettingCorrespondentParamsCompleted");
	
EndFunction

// Returns {http://www.1c.ru/SaaS/Exchange/Control/a.b.c.d}GettingCorrespondentParamsFailed message type
//
// Parameters:
//  PackageUsed - String – namespace of the message interface version
//                     whose message type is retrieved.
//
// Returns:
//  XDTOType
//
Function CorrespondentAccountingParameterGettingErrorMessage(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "GettingCorrespondentParamsFailed");
	
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
