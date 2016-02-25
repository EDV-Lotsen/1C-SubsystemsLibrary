////////////////////////////////////////////////////////////////////////////////
// MESSAGE INTERFACE HANDLER MODULE FOR MONITORING DATA EXCHANGE ADMINISTRATION
//
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// Returns the namespace of the current message interface version (it is
// the version used in the caller script).
Function Package() Export
	
	Return "http://www.1c.ru/SaaS/ExchangeAdministration/Control";
	
EndFunction

// Returns the current message interface version (it is the version used in
// the caller script).
Function Version() Export
	
	Return "2.1.2.1";
	
EndFunction

// Returns the name of the message API.
Function Interface() Export
	
	Return "ExchangeControlAdministration";
	
EndFunction

// Registers message handlers as message exchange channel handlers.
//
// Parameters:
//  HandlerArray - Array.
//
Procedure MessageChannelHandlers(Val HandlerArray) Export
	
	HandlerArray.Add(MessagesDataExchangeAdministrationControlMessageHandler_2_1_2_1);
	
EndProcedure

// Registers message translation handlers.
//
// Parameters:
//  HandlerArray - Array.
//
Procedure MessageTranslationHandlers(Val HandlerArray) Export
	
EndProcedure

// Returns {http://www.1c.ru/SaaS/ExchangeAdministration/Control/a.b.c.d}CorrespondentConnectionCompleted 
// message type.
//
// Parameters:
//  PackageUsed - String – namespace of the message interface version
//                     whose message type is retrieved.
//
// Returns:
//  XDTOType
//
Function CorrespondentConnectionCompletedMessage(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "CorrespondentConnectionCompleted");
	
EndFunction

// Returns {http://www.1c.ru/SaaS/ExchangeAdministration/Control/a.b.c.d}CorrespondentConnectionFailed 
// message type.
//
// Parameters:
//  PackageUsed - String – namespace of the message interface version
//                     whose message type is retrieved.
//
// Returns:
//  XDTOType
//
Function CorrespondentConnectionErrorMessage(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "CorrespondentConnectionFailed");
	
EndFunction

// Returns {http://www.1c.ru/SaaS/ExchangeAdministration/Control/a.b.c.d}GettingSyncSettingsCompleted 
// message type.
//
// Parameters:
//  PackageUsed - String – namespace of the message interface version
//                     whose message type is retrieved.
//
// Returns:
//  XDTOType
//
Function DataSynchronizationSettingsReceivedMessage(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "GettingSyncSettingsCompleted");
	
EndFunction

// Returns {http://www.1c.ru/SaaS/ExchangeAdministration/Control/a.b.c.d}GettingSyncSettingsFailed 
// message type.
//
// Parameters:
//  PackageUsed - String – namespace of the message interface version
//                     whose message type is retrieved.
//
// Returns:
//  XDTOType
//
Function DataSynchronizationSettingsReceivingErrorMessage(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "GettingSyncParametersFailed");
	
EndFunction

// Returns {http://www.1c.ru/SaaS/ExchangeAdministration/Control/a.b.c.d}EnableSyncCompleted 
// message type.
//
// Parameters:
//  PackageUsed - String – namespace of the message interface version
//                     whose message type is retrieved.
//
// Returns:
//  XDTOType
//
Function SynchronizationEnabledSuccessfullyMessage(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "EnableSyncCompleted");
	
EndFunction

// Returns {http://www.1c.ru/SaaS/ExchangeAdministration/Control/a.b.c.d}DisableSyncCompleted 
// message type.
//
// Parameters:
//  PackageUsed - String – namespace of the message interface version
//                     whose message type is retrieved.
//
// Returns:
//  XDTOType
//
Function SynchronizationDisabledMessage(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "DisableSyncCompleted");
	
EndFunction

// Returns {http://www.1c.ru/SaaS/ExchangeAdministration/Control/a.b.c.d}EnableSyncFailed 
// message type.
//
// Parameters:
//  PackageUsed - String – namespace of the message interface version
//                     whose message type is retrieved.
//
// Returns:
//  XDTOType
//
Function SynchronizationEnablingErrorMessage(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "EnableSyncFailed");
	
EndFunction

// Returns {http://www.1c.ru/SaaS/ExchangeAdministration/Control/a.b.c.d}DisableSyncFailed 
// message type.
//
// Parameters:
//  PackageUsed - String – namespace of the message interface version
//                     whose message type is retrieved.
//
// Returns:
//  XDTOType
//
Function SynchronizationDisablingErrorMessage(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "DisableSyncFailed");
	
EndFunction

// Returns {http://www.1c.ru/SaaS/ExchangeAdministration/Control/a.b.c.d}SyncCompleted 
// message type.
//
// Parameters:
//  PackageUsed - String – namespace of the message interface version
//                     whose message type is retrieved.
//
// Returns:
//  XDTOType
//
Function SynchronizationDoneMessage(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "SyncCompleted");
	
EndFunction

#EndRegion

#Region InternalProceduresAndFunctions

// For internal use
//
Function GenerateMessageType(Val PackageUsed, Val Type)
	
	If PackageUsed = Undefined Then
		PackageUsed = Package();
	EndIf;
	
	Return XDTOFactory.Type(PackageUsed, Type);
	
EndFunction

#EndRegion
