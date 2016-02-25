////////////////////////////////////////////////////////////////////////////////
// BACKUP CONTROL MESSAGE INTERFACE HANDLER
//
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// Returns the namespace of the current message interface version (it is the version used in the caller script).
Function Package() Export
	
	Return "http://www.1c.ru/SaaS/ControlZonesBackup/" + Version();
	
EndFunction

// Returns the current message interface version (it is the version used in the caller script).
Function Version() Export
	
	Return "1.0.3.1";
	
EndFunction

// Returns the name of the message API.
Function Interface() Export
	
	Return "ControlZonesBackup";
	
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
	
	HandlerArray.Add(MessagesBackupControlTranslationHandler_1_0_2_1);
	
EndProcedure

// Returns {http://www.1c.ru/SaaS/ControlZonesBackup/a.b.c.d}ZoneBackupSuccessfull message type. 
//
// Parameters:
//  PackageUsed - String – namespace of the message interface
//    version whose message type is retrieved.
//
// Returns:
//  XDTOType.
//
Function AreaBackupCreatedMessage(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "ZoneBackupSuccessfull");
	
EndFunction

// Returns {http://www.1c.ru/SaaS/ControlZonesBackup/a.b.c.d}ZoneBackupFailed message type.
//
// Parameters:
//  PackageUsed - String – namespace of the message interface
//    version whose message type is retrieved.
//
// Returns:
//  XDTOType.
//
Function AreaBackupErrorMessage(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "ZoneBackupFailed");
	
EndFunction

// Returns {http://www.1c.ru/SaaS/ControlZonesBackup/a.b.c.d}ZoneBackupSkipped message type.
//
// Parameters:
//  PackageUsed - String – namespace of the message interface
//    version which message type is retrieved.
//
// Returns:
//  XDTOType.
//
Function AreaBackupSkippedMessage(Val PackageUsed = Undefined) Export
	
	If PackageUsed = Undefined Then
		PackageUsed = "http://www.1c.ru/SaaS/ControlZonesBackup/1.0.2.1";
	EndIf;
	
	Return GenerateMessageType(PackageUsed, "ZoneBackupSkipped");
	
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
