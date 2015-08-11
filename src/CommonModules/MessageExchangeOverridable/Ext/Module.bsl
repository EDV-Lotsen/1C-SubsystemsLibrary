////////////////////////////////////////////////////////////////////////////////
// MessageExchangeOverridable: message exchange engine.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// SOFTWARE INTERFACE

// Retrieves a handler list of messages that the current infobase handles.
// 
// Parameters:
// Handlers - ValueTable - see MessageExchange.NewMessageHandlerTable
// for details.
// 
Procedure GetMessageChannelHandlers(Handlers) Export
	
	// StandardSubsystems.ServiceMode.DataExchangeServiceMode
	DataExchangeMessageChannelHandlerServiceMode.GetMessageChannelHandlers(Handlers);
	// End StandardSubsystems.ServiceMode.DataExchangeServiceMode
	
	//// _Demo Start Example
	//Handler = Handlers.Add();
	//Handler.Channel = "ProjectManagement\CreatingProject";
	//Handler.Handler = _DemoMessagesProjectManagement;
	//
	//Handler = Handlers.Add();
	//Handler.Channel = "ProjectManagement\ProjectList";
	//Handler.Handler = _DemoMessagesProjectManagement;
	//
	//Handler = Handlers.Add();
	//Handler.Channel = "ProjectManagement\Response\ProjectList";
	//Handler.Handler = _DemoMessagesProjectManagement;
	//
	//Handler = Handlers.Add();
	//Handler.Channel = "ProjectManagement\Test";
	//Handler.Handler = _DemoMessagesProjectManagement;
	//
	//Handler = Handlers.Add();
	//Handler.Channel = "ProjectManagement\Response\Test";
	//Handler.Handler = _DemoMessagesProjectManagement;
	//
	//Handler = Handlers.Add();
	//Handler.Channel = "CommonMessages\TextMessages";
	//Handler.Handler = _DemoMessagesBroadcastChannel;
	//// _Demo End Example
	
	// StandardSubsystems.ServiceMode.RemoteAdministration
	RemoteAdministrationMessageChannelHandler.GetMessageChannelHandlers(Handlers);
	// End StandardSubsystems.ServiceMode.RemoteAdministration
	
EndProcedure

// Retrieves message end point dynamic list. 
//
// Parameters:
// MessageChannel – String - ID of the message channel whose end points will be
// identified;
// Recipients – Array of ExchangePlanRef.MessageExchange - array of end points where
// a message will be sent; 
// This parameter must be defined in a body of a caller.
//
Procedure MessageRecipients(Val MessageChannel, Recipients) Export
	
	// _Demo Start Example
	If MessageChannel = "CommonMessages\TextMessages" Then
		
		QueryText =
		"SELECT
		|	MessageExchange.Ref AS Ref
		|FROM
		|	ExchangePlan.MessageExchange AS MessageExchange
		|WHERE
		|	(NOT MessageExchange.DeletionMark)";
		
		Query = New Query;
		Query.Text = QueryText;
		
		Recipients = Query.Execute().Unload().UnloadColumn("Ref");
		
	EndIf;
	// _Demo End Example
	
EndProcedure