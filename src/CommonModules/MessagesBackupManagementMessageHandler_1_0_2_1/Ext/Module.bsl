////////////////////////////////////////////////////////////////////////////////
// MESSAGE CHANNEL HANDLER FOR VERSION 1.0.3.4
//  OF REMOTE ADMINISTRATION MESSAGE INTERFACE
//
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// Returns the namespace of the message interface version.
Function Package() Export
	
	Return "http://www.1c.ru/SaaS/ManageZonesBackup/" + Version();
	
EndFunction

// Returns the message interface version that is supported by the handler.
Function Version() Export
	
	Return "1.0.2.1";
	
EndFunction

// Returns the default message type in a message interface version.
Function BaseType() Export
	
	Return MessagesSaaSCached.TypeBody();
	
EndFunction

// Processes incoming messages in SaaS mode
//
// Parameters:
//  Message - XDTODataObject - incoming message,
//  Sender  - ExchangePlanRef.MessageExchange - exchange plan node that matches the message sender.
// MessageProcessed - Boolean - True if processing is successful. This parameter value 
// must be set to True if the message is successfully read in this handler.
//
Procedure ProcessSaaSMessage(Val Message, Val From, MessageProcessed) Export
	
	MessageProcessed = True;
	
	Dictionary = MessagesBackupManagementInterface;
	MessageType = Message.Body.Type();
	
	If MessageType = Dictionary.MessageScheduleAreaBackup(Package()) Then
		ScheduleAreaBackup(Message, From);
	ElsIf MessageType = Dictionary.MessageCancelAreaBackup(Package()) Then
		CancelAreaBackup(Message, From);
	Else
		MessageProcessed = False;
	EndIf;
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

Procedure ScheduleAreaBackup(Val Message, Val From)
	
	Body = Message.Body;
 
	MessagesBackupManagementImplementation.ScheduleAreaBackingUp
(
		Body.Zone,
		Body.BackupId,
		Body.Date,
		Body.Forced);
	
EndProcedure

Procedure CancelAreaBackup(Val Message, Val From)
	
	Body = Message.Body;
	MessagesBackupManagementImplementation.CancelAreaBackingUp(
		Body.Zone,
		Body.BackupId);
	
EndProcedure

#EndRegion
