////////////////////////////////////////////////////////////////////////////////
// REMOTE ADMINISTRATION CONTROL MESSAGE INTERFACE HANDLER
//
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// Returns the namespace of the current message interface version (it is the version used in the caller script).
Function Package() Export
	
	Return "http://www.1c.ru/1cFresh/RemoteAdministration/Control/" + Version();
	
EndFunction

// Returns the current message interface version (it is the version used in the caller script).
Function Version() Export
	
	Return "1.0.2.5";
	
EndFunction

// Returns the name of the message API.
Function Interface() Export
	
	Return "RemoteAdministrationControl";
	
EndFunction

// Registers message handlers as message exchange channel handlers.
//
// Parameters:
//  HandlerArray - array.
//
Procedure MessageChannelHandlers(Val HandlerArray) Export
	
EndProcedure

// Registers message translation handlers.
//
// Parameters:
//  HandlerArray - array.
//
Procedure MessageTranslationHandlers(Val HandlerArray) Export
	
	HandlerArray.Add(MessagesRemoteAdministrationControlTranslationHandler_1_0_2_3);
	HandlerArray.Add(MessagesRemoteAdministrationControlTranslationHandler_1_0_2_4);
	
EndProcedure

// Returns the {http://www.1c.ru/SaaS/RemoteAdministration/Control/a.b.c.d}ApplicationPrepared message type
//
// Parameters:
//  PackageUsed - String – namespace of the message interface version
//    whose message type is retrieved.
//
// Returns:
//  XDTOType
//
Function MessageDataAreaPrepared(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "ApplicationPrepared");
	
EndFunction

// Returns the {http://www.1c.ru/SaaS/RemoteAdministration/Control/a.b.c.d}ApplicationDeleted message type
//
// Parameters:
//  PackageUsed - String – namespace of the message interface version
//    whose message type is retrieved.
//
// Returns:
//  XDTOType
//
Function MessageDataAreaDeleted(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "ApplicationDeleted");
	
EndFunction

// Returns the {http://www.1c.ru/SaaS/RemoteAdministration/Control/a.b.c.d}ApplicationPrepareFailed message type
//
// Parameters:
//  PackageUsed - String – namespace of the message interface version
//    whose message type is retrieved.
//
// Returns:
//  XDTOType
//
Function MessageErrorPreparingDataArea(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "ApplicationPrepareFailed");
	
EndFunction

// Returns the {http://www.1c.ru/SaaS/RemoteAdministration/Control/a.b.c.d}ApplicationPrepareFailedConversionRequired message type
//
// Parameters:
//  PackageUsed - String – namespace of the message interface version
//    whose message type is retrieved.
//
// Returns:
//  XDTOType
//
Function MessageErrorPreparingDataAreaConversionRequired(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "ApplicationPrepareFailedConversionRequired");
	
EndFunction

// Returns the {http://www.1c.ru/SaaS/RemoteAdministration/Control/a.b.c.d}ApplicationDeleteFailed message type
//
// Parameters:
//  PackageUsed - String – namespace of the message interface version
//    whose message type is retrieved.
//
// Returns:
//  XDTOType
//
Function MessageErrorDeletingDataArea(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "ApplicationDeleteFailed");
	
EndFunction

// Returns the {http://www.1c.ru/SaaS/RemoteAdministration/Control/a.b.c.d}ApplicationReady message type
//
// Parameters:
//  PackageUsed - String – namespace of the message interface version
//    whose message type is retrieved.
//
// Returns:
//  XDTOType
//
Function MessageDataAreaIsReadyForUse(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "ApplicationReady");
	
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
