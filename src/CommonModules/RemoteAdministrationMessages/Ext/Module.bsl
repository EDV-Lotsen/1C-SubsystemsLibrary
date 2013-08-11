///////////////////////////////////////////////////////////////////////////////////
// Remote administration messages.
//
///////////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// Returns a new remote administration message for sending to the service manager.
//
// Parameters:
//  MessageType - XDTOObjectType - type of messages to be generated.
//
// Returns:
//  XDTODataObject - Object of the required type.
//
Function NewMessage(Val MessageType) Export
	
	Return XDTOFactory.Create(MessageType);
	
EndFunction

// Sends the remote administration message. 
//
// Parameters:
// Content - XDTODataObject - message content;
// Recipient - ExchangePlanRef.MessageExchange - message recipient;
// Immediately - Boolean - flag that shows whether the message must be sent with the instant message mechanism.
//
Procedure SendMessage(Val Content, Val Recipient = Undefined, Val Immediately = False) Export
	
	Writer = New XMLWriter;
	Writer.SetString();
	
	XDTOFactory.WriteXML(Writer, Content, , , , XMLTypeAssignment.Explicit);
	
	MessageChannel = ChannelNameByMessageType(Content.Type());
	
	If Immediately Then
		MessageExchange.SendMessageImmediately(MessageChannel, Writer.Close(), Recipient);
	Else
		MessageExchange.SendMessage(MessageChannel, Writer.Close(), Recipient);
	EndIf;
	
EndProcedure

// Received the remote administration message content from the message body.
//
// Parameters:
// Body - ValueStorage - messages body. 
//
// Returns:
// XDTODataObject - remote administration message content.
//
Function GetMessageContent(Val Body) Export
	
	Reader = New XMLReader;
	Reader.SetString(Body);
	
	Content = XDTOFactory.ReadXML(Reader);
	
	Reader.Close();
	
	Return Content;
	
EndFunction

// Returns remote administration message channel name that corresponds
// to the message type.
//
// Parameters:
// MessageType - XDTOObjectType - remote administration message type.
//
// Returns:
// String - message channel name.
//
Function ChannelNameByMessageType(Val MessageType) Export
	
	Return XDTOSerializer.XMLString(New XMLExpandedName(MessageType.NamespaceURI, MessageType.Name));
	
EndFunction

// Returns remote administration message type that corresponds
// to the message channel name. 
//
// Parameters:
// ChannelName - String - message channel name.
//
// Returns:
// XDTOObjectType - remote administration message type.
//
Function MessageTypeByChannelName(Val ChannelName) Export
	
	Return XDTOFactory.Type(XDTOSerializer.XMLValue(Type("XMLExpandedName"), ChannelName));
	
EndFunction

// Raises an exception if the message channel is unknown.
//
// Parameters:
// MessageChannel - String - unknown message channel name.
//
Procedure UnknownChannelNameError(Val MessageChannel) Export
	
	MessagePattern = NStr("en = 'Message channel name %1 is unknown.'");
	MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, MessageChannel);
	Raise(MessageText);
	
EndProcedure
