////////////////////////////////////////////////////////////////////////////////
// MESSAGE CHANNEL HANDLER FOR VERSION 1.0.3.1 OF DATA AREA BACKUP MANAGEMENT 
//  MESSAGE INTERFACE
//
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// Returns the namespace of the message interface version.
Function Package() Export
	
	Return "http://www.1c.ru/SaaS/ManageZonesBackup/" + Version();
	
EndFunction

// Returns the message interface version that is supported by the handler.
Function Version() Export
	
	Return "1.0.3.1";
	
EndFunction

// Returns the default message type in a message interface version.
Function BaseType() Export
	
	Return MessagesSaaSCached.TypeBody();
	
EndFunction

// Processes incoming messages in SaaS mode.
//
// Parameters:
//  Message - XDTODataObject - incoming message. 
//  Sender  - ExchangePlanRef.MessageExchange - exchange plan node that matches the message sender. 
//  MessageProcessed - Boolean - True if processing is successful. This parameter 
// value must be set to True if the message is successfully read in this handler.
//
Procedure ProcessSaaSMessage(Val Message, Val Sender, MessageProcessed)
Export
	
	MessageProcessed = True;
	
	Dictionary = MessagesBackupManagementInterface;
	MessageType = Message.Body.Type();
	
	If MessageType = Dictionary.MessageScheduleAreaBackup(Package()) Then
		ScheduleAreaBackup(Message, Sender);
	ElsIf MessageType = 
Dictionary.MessageUpdatePeriodicBackupSettings(Package()) Then
   UpdatePeriodicBackupSettings(Message, Sender);
	ElsIf MessageType = Dictionary.MessageCancelPeriodicBackup(Package()) Then
		CancelPeriodicBackup(Message, Sender);
	Else
		MessageProcessed = False;
	EndIf;
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

Procedure ScheduleAreaBackup(Val Message, Val Sender)
	
	Body = Message.Body;
 
MessagesBackupManagementImplementation.ScheduleAreaBackingUp(
		Body.Zone,
		Body.BackupId,
		Body.Date,
		True);
	
EndProcedure

Procedure UpdatePeriodicBackupSettings(Val Message, Val Sender)
	
	Body = Message.Body;
	
	Settings = New Structure;
	Settings.Insert("CreateDaily", Body.CreateDailyBackup);
	Settings.Insert("CreateMonthly", Body.CreateMonthlyBackup);
	Settings.Insert("CreateYearly", Body.CreateYearlyBackup);
	Settings.Insert("OnlyWhenActiveUsers", Body.CreateBackupOnlyAfterUsersActivity);
	Settings.Insert("BackupCreationIntervalStart", Body.BackupCreationBeginTime);
	Settings.Insert("BackupCreationIntervalEnd", Body.BackupCreationEndTime);
	Settings.Insert("MonthlyCreationDate", Body.MonthlyBackupCreationDay);
	Settings.Insert("YearlyCreationMonth", Body.YearlyBackupCreationMonth);
	Settings.Insert("YearlyCreationDate", Body.YearlyBackupCreationDay);
	Settings.Insert("LastDailyCreationDate", Body.LastDailyBackupDate);
	Settings.Insert("LastMonthlyCreationDate", Body.LastMonthlyBackupDate);
	Settings.Insert("LastYearlyCreationDate", Body.LastYearlyBackupDate);
	
MessagesBackupManagementImplementation.UpdatePeriodicBackupSettings(
		Body.Zone,
		Settings);
	
EndProcedure

Procedure CancelPeriodicBackup(Val Message, Val Sender)
	
	Body = Message.Body;
	
MessagesBackupManagementImplementation.CancelPeriodicBackup(
		Body.Zone);
	
EndProcedure

#EndRegion
