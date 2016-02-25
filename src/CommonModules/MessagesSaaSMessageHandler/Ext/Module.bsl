////////////////////////////////////////////////////////////////////////////////
// Message channel handler for SaaS messages
//
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// Processes a message body according to the current message channel algorithm.
//
// Parameters:
//  MessageChannel - String - ID of the message channel that delivered the message.
//  Body - Arbitrary - message body to be processed.
//  Sender - ExchangePlanRef.MessageExchange - message sender endpoint.
//
Procedure ProcessMessage(Val MessageChannel, Val Body, Val Sender) Export
	
	SetPrivilegedMode(True);
	
	If CommonUseCached.IsSeparatedConfiguration() Then
		SeparatedModule = CommonUse.CommonModule("MessagesSaaSDataSeparation");
	EndIf;
	
	// Reading message
	MessageType = MessagesSaaS.MessageTypeByChannelName(MessageChannel);
	Message = MessagesSaaS.ReadMessageFromUntypedBody(Body);
	
	MessagesSaaS.WriteProcessingStartEvent(Message);
	
	Try
		
		If CommonUseCached.IsSeparatedConfiguration() Then
			SeparatedModule.OnMessageProcessingStart(Message, Sender);
		EndIf;
		
		MessagesSaaSOverridable.OnMessageProcessingStart(Message, Sender);
		
		// Getting and executing the message interface handler
		Handler = GetMessageChannelHandlerSaaS(MessageChannel);
		If Handler <> Undefined Then
			
			MessageProcessed = False;
			Handler.ProcessSaaSMessage(Message, Sender, MessageProcessed);
			
		Else
			
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Cannot determine the message channel handler for SaaS messages %1'"), MessageChannel);
			
		EndIf;
		
		If CommonUseCached.IsSeparatedConfiguration() Then
			SeparatedModule.AfterMessageProcessing(Message, Sender, MessageProcessed);
		EndIf;
		
		MessagesSaaSOverridable.AfterMessageProcessing(Message, Sender, MessageProcessed);
		
	Except
		
		If CommonUseCached.IsSeparatedConfiguration() Then
			SeparatedModule.OnMessageProcessingError(Message, Sender);
		EndIf;
		
		MessagesSaaSOverridable.OnMessageProcessingError(Message, Sender);
		
		Raise;
		
	EndTry;
	
	MessagesSaaS.WriteProcessingEndEvent(Message);
	
	If Not MessageProcessed Then
		
		MessagesSaaS.UnknownChannelNameError(MessageChannel);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

Function GetMessageChannelHandlerSaaS(MessageChannel)
	
	InterfaceHandlers = MessageInterfacesSaaS.GetIncomingMessageInterfaceHandlers();
	
	For Each InterfaceHandler In InterfaceHandlers Do
		
		InterfaceChannelHandlers  = New Array();
		InterfaceHandler.MessageChannelHandlers(InterfaceChannelHandlers);
		
		For Each InterfaceChannelHandler In InterfaceChannelHandlers Do
			
			Package = InterfaceChannelHandler.Package();
			BaseType = InterfaceChannelHandler.BaseType();
			
			ChannelNames = MessageInterfacesSaaS.GetPackageChannels(Package, BaseType);
			
			For Each ChannelName In ChannelNames Do
				If ChannelName = MessageChannel Then
					
					Return InterfaceChannelHandler;
					
				EndIf;
			EndDo;
			
		EndDo;
		
	EndDo;
	
EndFunction

#EndRegion
