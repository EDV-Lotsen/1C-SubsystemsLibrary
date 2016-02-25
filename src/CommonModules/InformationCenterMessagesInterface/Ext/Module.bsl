////////////////////////////////////////////////////////////////////////////////
// INFORMATION CENTER MESSAGE INTERFACE HANDLER
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// Retrieves the namespace of the current (used by the script) message interface version.
Function Package() Export
	
	Return "http://www.1c.ru/SaaS/1.0/XMLSchema/ManageInfoCenter/Messages/" + Version();
	
EndFunction

// Retrieves the current (used by the script) message interface version.
Function Version() Export
	
	Return "1.0.1.1";
	
EndFunction

// Retrieves the name of the message interface.
Function Interface() Export
	
	Return "MessageInfoCenter";
	
EndFunction

// Records message handlers as handlers of message exchange channels.
//
// Parameters:
//  HandlerArray - Array.
//
Procedure MessageChannelHandlers(Val HandlerArray) Export
	
	HandlerArray.Add(InformationCenterMessagesMessageHandler_1_0_1_1);
	
EndProcedure

// Retrieves the {http://www.1c.ru/SaaS/1.0/XMLSchema/ManageInfoCenter/Messages/a.b.c.d}notificateSuggestion
// message type.
//
// Parameters:
//  PackageUsed - String - namespace of the message interface version, for which
//    the type is retrieved.
//
// Returns:
//  XDTOType.
//
Function SuggestionNotificationsMessage(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "notificateSuggestion");
	
EndFunction


////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

Function GenerateMessageType(Val PackageUsed = Undefined, Val Type)
	
	If PackageUsed = Undefined Then
		PackageUsed = Package();
	EndIf;
	
	Return XDTOFactory.Type(PackageUsed, Type);
	
EndFunction