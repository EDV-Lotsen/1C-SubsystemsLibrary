////////////////////////////////////////////////////////////////////////////////
// MESSAGE CHANNEL HANDLER MODULE FOR VERSION 2.1.2.1
// OF MESSAGE INTERFACE FOR MONITORING DATA EXCHANGE ADMINISTRATION
//
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// Returns the namespace of the message interface version.
Function Package() Export
	
	Return "http://www.1c.ru/SaaS/ExchangeAdministration/Control";
	
EndFunction

// Returns the message interface version that is supported by the handler.
Function Version() Export
	
	Return "2.1.2.1";
	
EndFunction

// Returns the default message type in a message interface version.
Function BaseType() Export
	
	Return MessagesSaaSCached.TypeBody();
	
EndFunction

// Processes incoming messages in SaaS mode.
//
// Parameters:
//  Message          - XDTODataObject - incoming message. 
//  Sender           - ExchangePlanRef.MessageExchange - exchange plan node 
//                     that matches the message sender. 
//  MessageProcessed - Boolean - True if message processing is successful.
//                     This parameter value must be set to True if the message
//                     is successfully read in this handler.
//
Procedure ProcessSaaSMessage(Val Message, Val From, MessageProcessed) Export
	
	MessageProcessed = True;
	
	Dictionary = MessagesDataExchangeAdministrationControlInterface;
	MessageType = Message.Body.Type();
	
	If MessageType = Dictionary.DataSynchronizationSettingsReceivedMessage(Package()) Then
		DataExchangeSaaS.SaveSessionData(Message, SettingsReceiveActionPresentation());
	ElsIf MessageType = Dictionary.DataSynchronizationSettingsReceivingErrorMessage(Package()) Then
		DataExchangeSaaS.CommitUnsuccessfulSession(Message, SettingsReceiveActionPresentation());
	ElsIf MessageType = Dictionary.SynchronizationEnabledSuccessfullyMessage(Package()) Then
		DataExchangeSaaS.CommitSuccessfulSession(Message, SynchronizationEnablingPresentation());
	ElsIf MessageType = Dictionary.SynchronizationDisabledMessage(Package()) Then
		DataExchangeSaaS.CommitSuccessfulSession(Message, SynchronizationDisablingPresentation());
	ElsIf MessageType = Dictionary.SynchronizationEnablingErrorMessage(Package()) Then
		DataExchangeSaaS.CommitUnsuccessfulSession(Message, SynchronizationEnablingPresentation());
	ElsIf MessageType = Dictionary.SynchronizationDisablingErrorMessage(Package()) Then
		DataExchangeSaaS.CommitUnsuccessfulSession(Message, SynchronizationDisablingPresentation());
	ElsIf MessageType = Dictionary.SynchronizationDoneMessage(Package()) Then
		DataExchangeSaaS.CommitSuccessfulSession(Message, SynchronizationPerformingPresentation());
	Else
		MessageProcessed = False;
	EndIf;
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

Function SettingsReceiveActionPresentation()
	
	Return NStr("en = 'Getting data synchronization settings from SaaS manager.'");
	
EndFunction

Function SynchronizationEnablingPresentation()
	
	Return NStr("en = 'Enabling data synchronization in SaaS manager.'");
	
EndFunction

Function SynchronizationDisablingPresentation()
	
	Return NStr("en = 'Disabling data synchronization in SaaS manager.'");
	
EndFunction

Function SynchronizationPerformingPresentation()
	
	Return NStr("en = 'Running data synchronization by user request.'");
	
EndFunction

#EndRegion
