////////////////////////////////////////////////////////////////////////////////
// InformationCenterMessageHandler.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// Retrieves the message interface version namespace.
//
Function Package() Export
	
	Return "http://www.1c.ru/SaaS/1.0/XMLSchema/ManageInfoCenter/Messages/" + Version();
	
EndFunction

// Retrieves the message interface version that the handler supports.
//
Function Version() Export
	
	Return "1.0.1.1";
	
EndFunction

// Returns the default message type in a message interface version.
//
Function BaseType() Export
	
	Return CTLAndSLIntegration.TypeBody();
	
EndFunction

// Handles incoming SaaS messages.
//
// Parameters:
//  Message          - XDTODataObject - incoming message.
//  From             - ExchangePlanRef.MessageExchange - exchange plan node 
//                     corresponded to the message sender.
//  MessageProcessed - Boolean - flag that shows whether the message has been handled
//                     successfully. You must return True to this parameter if the
//                     message is read in the handler.
//
Procedure ProcessSaaSMessage(Val Message, Val From, MessageProcessed) Export
	
	MessageProcessed = True;
	
	Dictionary = InformationCenterMessagesInterface;
	MessageType = Message.Body.Type();
	
	If MessageType = Dictionary.SuggestionNotificationsMessage() Then
		AddSuggestionNotification(Message);
	Else
		MessageProcessed = False;
	EndIf;
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

Procedure AddSuggestionNotification(Message)
	
	Body = Message.Body;
	InformationCenterMessagesImplementation.AddSuggestionNotification(Body);
	
EndProcedure
