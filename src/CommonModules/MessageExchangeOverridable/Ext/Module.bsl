////////////////////////////////////////////////////////////////////////////////
// MessageExchangeOverridable: message exchange mechanism.
//
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// Retrieves a list of handlers used for messages processed by the current infobase.
// 
// Parameters:
//  Handlers - ValueTable - see the field structure in MessageExchange.NewMessageHandlerTable.
// 
Procedure GetMessageChannelHandlers(Handlers) Export
	
	// _Demo begin example
	//Handler = Handlers.Add();
	//Handler.Channel = "ProjectManagement\CreatingProject";
	//Handler.Handler = _DemoMessagesProjectManagement;
	//
	//Handler = Handlers.Add();
	//Handler.Channel = "ProjectManagement\ProjectList";
	//Handler.Handler = _DemoMessagesProjectManagement;
	//
	//Handler = Handlers.Add();
	//Handler.Channel = "ProjectManagement\Answer\ProjectList";
	//Handler.Handler = _DemoMessagesProjectManagement;
	//
	//Handler = Handlers.Add();
	//Handler.Channel = "ProjectManagement\Test";
	//Handler.Handler = _DemoMessagesProjectManagement;
	//
	//Handler = Handlers.Add();
	//Handler.Channel = "ProjectManagement\Answer\Test";
	//Handler.Handler = _DemoMessagesProjectManagement;
	//
	//Handler = Handlers.Add();
	//Handler.Channel = "CommonMessages\TextMessages";
	//Handler.Handler = _DemoMessagesBroadcastChannel;
	// _Demo end example
	
EndProcedure

// Gets a dynamic list of message endpoints.
//
// Parameters:
//  MessageChannel - String - message channel ID.
//  Recipients     - Array  - array of endpoints assigned as message recipients.
//                            Contains items of ExchangePlanRef.MessageExchange type.
//                            This parameter must be defined in the handler body.
//
Procedure MessageRecipients(Val MessageChannel, Recipients) Export
	
	// _Demo begin example
	If MessageChannel = "CommonMessages\TextMessages" Then
		
		QueryText =
		"SELECT
		|	MessageExchange.Ref AS Ref
		|FROM
		|	ExchangePlan.MessageExchange AS MessageExchange
		|WHERE
		|	(Not MessageExchange.DeletionMark)";
		
		Query = New Query;
		Query.Text = QueryText;
		
		Recipients = Query.Execute().Unload().UnloadColumn("Ref");
		
	EndIf;
	// _Demo end example
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Message sending/receiving event handlers

// "On send message" event handler.
// This event handler is called before a message is sent to an XML data stream.
// The handler is called separately for each message to be sent.
//
// Parameters:
//  MessageChannel - String    - ID of the message channel used to send the message.
//  Body           - Arbitrary - body of the message to be sent. In this event handler,
//                               message body can be modified (for example, new data added).
//
Procedure OnSendMessage(MessageChannel, Body) Export
	
EndProcedure

// "On receive message" event handler.
// This event handler is called after a message is received from an XML data stream.
// The handler is called separately for each received message.
//
// Parameters:
//  MessageChannel - String    - ID of the message channel that delivered a message.
//  Body           - Arbitrary - body of the received message. In this event handler,
//                               message body can be modified (for example, new data added).
//
Procedure OnReceiveMessage(MessageChannel, Body) Export
	
EndProcedure

#EndRegion