////////////////////////////////////////////////////////////////////////////////
// Message channel handler for SaaS messages, overridable procedures and functions
//
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// "On receive message" event handler.
// This event handler is called after a message is received from an XML data stream.
// The handler is called separately for each received message.
//
// Parameters:
//  MessageChannel - String - ID of the message channel that delivered the message.
//  Body - Arbitrary - body of the received message. In this event handler, message
//                     body can be modified (for example, new data added).
//
Procedure OnReceiveMessage(MessageChannel, Body, MessageObject) Export
	
EndProcedure

// "On send message" event handler.
// This event handler is called before a message is sent to an XML data stream.
// The handler is called separately for each message to be sent.
//
// Parameters:
//  MessageChannel - String - ID of a message channel used to send the message.
//  Body - Arbitrary - body of the message to be sent. In this event handler,
//                     message body can be modified (for example, new data added).
//
Procedure OnSendMessage(MessageChannel, Body, MessageObject) Export
	
EndProcedure

// This procedure is called when an incoming message processing starts.
//
// Parameters:
//  Message - XDTODataObject - incoming message.
//  Sender - ExchangePlanRef.MessageExchange - exchange plan node matching the infobase 
//                                             used to send the message.
//
Procedure OnMessageProcessingStart(Val Message, Val Sender) Export
	
EndProcedure

// This procedure is called after an incoming message processing ends.
//
// Parameters:
//  Message - XDTODataObject - incoming message.
//  Sender - ExchangePlanRef.MessageExchange - exchange plan node matching the infobase
//                                             used to send the message.
//  MessageProcessed - Boolean - flag specifying whether the message was processed successfully. 
//                             If set to False - an exception is raised after this procedure is complete.
//                             In this procedure, value of this parameter can be modified.
//
Procedure AfterMessageProcessing(Val Message, Val Sender, MessageProcessed) Export
	
EndProcedure

// This procedure is called when a message processing error occurs.
//
// Parameters:
//  Message - XDTODataObject - incoming message.
//  Sender - ExchangePlanRef.MessageExchange - exchange plan node matching the infobase 
//                                             used to send the message.
//
Procedure OnMessageProcessingError(Val Message, Val Sender) Export
	
EndProcedure

#EndRegion
