////////////////////////////////////////////////////////////////////////////////
// REMOTE ADMINISTRATION MESSAGE INTERFACE HANDLER
//
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// Returns the namespace of the current message interface version (it is the version used in the caller script).
Function Package() Export
	
	Return "http://www.1c.ru/1cFresh/RemoteAdministration/App/" + Version();
	
EndFunction

// Returns the current message interface version (it is the version used in the caller script).
Function Version() Export
	
	Return "1.0.3.4";
	
EndFunction

// Returns the name of the message API.
Function Interface() Export
	
	Return "RemoteAdministrationApp";
	
EndFunction

// Registers message handlers as message exchange channel handlers.
//
// Parameters:
//  HandlerArray - array.
//
Procedure MessageChannelHandlers(Val HandlerArray) Export
	
	HandlerArray.Add(RemoteAdministrationMessagesMessageHandler_1_0_3_1);
	HandlerArray.Add(RemoteAdministrationMessagesMessageHandler_1_0_3_2);
	HandlerArray.Add(RemoteAdministrationMessagesMessageHandler_1_0_3_3);
	HandlerArray.Add(RemoteAdministrationMessagesMessageHandler_1_0_3_4);
	HandlerArray.Add(RemoteAdministrationMessagesMessageHandler_1_0_3_5);
	
EndProcedure

// Registers message translation handlers.
//
// Parameters:
//  HandlerArray - array.
//
Procedure MessageTranslationHandlers(Val HandlerArray) Export
	
EndProcedure

// Returns the {http://www.1c.ru/1cfresh/RemoteAdministration/App/a.b.c.d}UpdateUser message type
//
// Parameters:
//  PackageUsed - String – namespace of the message interface version
//    whose message type is retrieved.
//
// Returns:
//  XDTOType
//
Function MessageUpdateUser(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "UpdateUser");
	
EndFunction

// Returns the {http://www.1c.ru/1cfresh/RemoteAdministration/App/a.b.c.d}SetFullControl message type
//
// Parameters:
//  PackageUsed - String – namespace of the message interface version
//    whose message type is retrieved.
//
// Returns:
//  XDTOType
//
Function MessageSetDataAreaFullAccess(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "SetFullControl");
	
EndFunction

// Returns the {http://www.1c.ru/1cfresh/RemoteAdministration/App/a.b.c.d}SetApplicationAccess message type
//
// Parameters:
//  PackageUsed - String – namespace of the message interface version
//    whose message type is retrieved.
//
// Returns:
//  XDTOType
//
Function MessageSetAccessToDataArea(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "SetApplicationAccess");
	
EndFunction

// Returns the {http://www.1c.ru/1cfresh/RemoteAdministration/App/a.b.c.d}SetDefaultUserRights message type
//
// Parameters:
//  PackageUsed - String – namespace of the message interface version
//    whose message type is retrieved.
//
// Returns:
//  XDTOType
//
Function MessageSetDefaultUserRights(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "SetDefaultUserRights");
	
EndFunction

// Returns the {http://www.1c.ru/1cfresh/RemoteAdministration/App/a.b.c.d}PrepareApplication message type
//
// Parameters:
//  PackageUsed - String – namespace of the message interface version
//    whose message type is retrieved.
//
// Returns:
//  XDTOType
//
Function MessagePrepareDataArea(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "PrepareApplication");
	
EndFunction

// Returns the {http://www.1c.ru/1cfresh/RemoteAdministration/App/a.b.c.d}BindApplication message type
//
// Parameters:
//  PackageUsed - String – namespace of the message interface version
//    whose message type is retrieved.
//
// Returns:
//  XDTOType
//
Function MessageAttachDataArea(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "BindApplication");
	
EndFunction

// Returns the {http://www.1c.ru/1cfresh/RemoteAdministration/App/a.b.c.d}UsersList message type
//
// Parameters:
//  PackageUsed - String – namespace of the message interface version
//    whose message type is retrieved.
//
// Returns:
//  XDTOType
//
Function MessageUserList(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "UsersList");
	
EndFunction

// Returns the {http://www.1c.ru/1cfresh/RemoteAdministration/App/a.b.c.d}PrepareCustomApplication message type
//
// Parameters:
//  PackageUsed - String – namespace of the message interface version
//    whose message type is retrieved.
//
// Returns:
//  XDTOType
//
Function MessagePrepareDataAreaFromExport(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "PrepareCustomApplication");
	
EndFunction

// Returns the {http://www.1c.ru/1cfresh/RemoteAdministration/App/a.b.c.d}DeleteApplication message type
//
// Parameters:
//  PackageUsed - String – namespace of the message interface version
//    whose message type is retrieved.
//
// Returns:
//  XDTOType
//
Function MessageDeleteDataArea(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "DeleteApplication");
	
EndFunction

// Returns the {http://www.1c.ru/1cfresh/RemoteAdministration/App/a.b.c.d}SetApplicationParams message type
//
// Parameters:
//  PackageUsed - String – namespace of the message interface version
//    whose message type is retrieved.
//
// Returns:
//  XDTOType
//
Function MessageSetDataAreaParameters(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "SetApplicationParams");
	
EndFunction

// Returns the {http://www.1c.ru/1cfresh/RemoteAdministration/App/a.b.c.d}SetIBParams message type
//
// Parameters:
//  PackageUsed - String – namespace of the message interface version
//    whose message type is retrieved.
//
// Returns:
//  XDTOType
//
Function MessageSetInfobaseParameters(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "SetIBParams");
	
EndFunction

// Returns the {http://www.1c.ru/1cfresh/RemoteAdministration/App/a.b.c.d}SetServiceManagerEndpoint message type
//
// Parameters:
//  PackageUsed - String – namespace of the message interface version
//    whose message type is retrieved.
//
// Returns:
//  XDTOType
//
Function MessageSetServiceManagerEndpoint(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "SetServiceManagerEndpoint");
	
EndFunction

// Returns the {http://www.1c.ru/1cfresh/RemoteAdministration/App/a.b.c.d}ApplicationsRating message type
//
// Parameters:
//  PackageUsed - String – namespace of the message interface version
//    whose message type is retrieved.
//
// Returns:
//  XDTOType
//
Function TypeDataAreaRating(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "ApplicationRating");
	
EndFunction

// Returns the {http://www.1c.ru/1cfresh/RemoteAdministration/App/a.b.c.d}SetApplicationsRating message type
//
// Parameters:
//  PackageUsed - String – namespace of the message interface version
//    whose message type is retrieved.
//
// Returns:
//  XDTOType
//
Function MessageSetDataAreaRating(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "SetApplicationsRating");
	
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
