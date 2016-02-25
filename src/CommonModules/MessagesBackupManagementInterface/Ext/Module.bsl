////////////////////////////////////////////////////////////////////////////////
// BACKUP MANAGEMENT MESSAGE INTERFACE HANDLER
//
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// Returns the namespace of the current message interface version (it is the version used in the caller script).
Function Package() Export
	
	Return "http://www.1c.ru/SaaS/ManageZonesBackup/" + Version();
	
EndFunction

// Returns the current message interface version (it is the version used in the caller script).
Function Version() Export
	
	Return "1.0.3.1";
	
EndFunction

// Returns the name of the message API.
Function Interface() Export
	
	Return "ManageZonesBackup";
	
EndFunction

// Registers message handlers as message exchange channel handlers.
//
// Parameters:
//  HandlerArray - array.
//
Procedure MessageChannelHandlers(Val HandlerArray) Export
	
	HandlerArray.Add(MessagesBackupManagementMessageHandler_1_0_2_1);
	HandlerArray.Add(MessagesBackupManagementMessageHandler_1_0_3_1);
	
EndProcedure

// Registers message translation handlers.
//
// Parameters:
//  HandlerArray - array.
//
Procedure MessageTranslationHandlers(Val HandlerArray) Export
	
EndProcedure

// Returns {http://www.1c.ru/SaaS/ManageZonesBackup/a.b.c.d}PlanZoneBackup message type.
//
// Parameters:
//  PackageBeingUsed - String – namespace of the message interface
//    version whose message type is retrieved.
//
// Returns:
//  XDTOType.
//
Function MessageScheduleAreaBackup(Val PackageBeingUsed = Undefined) 
Export
	
	Return GenerateMessageType(PackageBeingUsed, "PlanZoneBackup");
	
EndFunction

// Returns {http://www.1c.ru/SaaS/ManageZonesBackup/a.b.c.d}CancelZoneBackup message type.
//
// Parameters:
//  PackageBeingUsed - String – namespace of the message interface
//    version whose message type is retrieved.
//
// Returns:
//  XDTOType.
//
Function MessageCancelAreaBackup(Val PackageBeingUsed = Undefined) Export
	
	If PackageBeingUsed = Undefined Then
		PackageBeingUsed = "http://www.1c.ru/SaaS/ManageZonesBackup/1.0.2.1";
	EndIf;
	
	Return GenerateMessageType(PackageBeingUsed, "CancelBackupZone");
	
EndFunction

// Returns {http://www.1c.ru/SaaS/ManageZonesBackup/a.b.c.d}UpdateScheduledBackupZoneSettings message type.
//
// Parameters:
//  PackageBeingUsed - String – namespace of the message interface
//    version which message type is retrieved.
//
// Returns:
//  XDTOType.
//
Function MessageUpdatePeriodicBackupSettings(Val 
PackageBeingUsed = Undefined) Export
	
	Return GenerateMessageType(PackageBeingUsed, "UpdateScheduledBackupZoneSettings");
	
EndFunction

// Returns {http://www.1c.ru/SaaS/ManageZonesBackup/a.b.c.d}CancelScheduledZoneBackup message type.
//
// Parameters:
//  PackageBeingUsed - String – namespace of the message interface
//    version whose message type is retrieved.
//
// Returns:
//  XDTOType.
//
Function MessageCancelPeriodicBackup(Val PackageBeingUsed = Undefined) Export
	
	Return GenerateMessageType(PackageBeingUsed, "CancelScheduledZoneBackup");
	
EndFunction

#EndRegion

#Region InternalProceduresAndFunctions

Function GenerateMessageType(Val PackageBeingUsed, Val Type)
	
	If PackageBeingUsed = Undefined Then
		PackageBeingUsed = Package();
	EndIf;
	
	Return XDTOFactory.Type(PackageBeingUsed, Type);
	
EndFunction

#EndRegion
