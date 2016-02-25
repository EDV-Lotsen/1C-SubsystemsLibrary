////////////////////////////////////////////////////////////////////////////////
// APPLICATION MANAGEMENT MESSAGE INTERFACE HANDLER
//
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// Returns the namespace of the current message interface version (it is
// the version used in the caller script).
Function Package() Export
	
	Return "http://www.1c.ru/1cFresh/ManageApplication/Messages/1.0";
	
EndFunction

// Returns the current message interface version (it is the version used in 
// the caller script).
Function Version() Export
	
	Return "1.0.0.1";
	
EndFunction

// Returns the name of the message API.
Function Interface() Export
	
	Return "ManageApplicationMessages";
	
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
	
EndProcedure

// Returns the {http://www.1c.ru/1cFresh/ManageApplication/Messages/a.b.c.d}RevokeUserAccess message type
//
// Parameters:
//  PackageUsed - String – namespace of the message interface version
//    whose message type is retrieved.
//
// Returns:
//  XDTOType
//
Function MessageCancelUserAccess(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "RevokeUserAccess");
	
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
