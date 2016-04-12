
#Region Interface

// Returns a new message.
//
// Parameters:
//  MessageBodyType - XDTODataObjectType - body type for the message to be created.
//
// Returns:
//  XDTODataObject - object of the specified type.
Function NewMessage(Val MessageBodyType) Export
	
	Message = XDTOFactory.Create(MessagesSaaSCached.MessageType());
	
	Message.Header = XDTOFactory.Create(MessagesSaaSCached.MessageTitleType());
	Message.Header.Id = New UUID;
	Message.Header.Created = CurrentUniversalDate();
	
	Message.Body = XDTOFactory.Create(MessageBodyType);
	
	Return Message;
	
EndFunction

// Sends a message.
//
// Parameters:
//  Message   - XDTODataObject - message to be sent.
//  Recipient - ExchangePlanRef.MessageExchange - message recipient.
//  Now       - Boolean - flag specifying whether the message will be sent through the quick message delivery.
//
Procedure SendMessage(Val Message, Val Recipient = Undefined, Val Now = False) Export
	
	Message.Header.Sender = MessageExchangeNodeDescription(ExchangePlans.MessageExchange.ThisNode());
	
	If ValueIsFilled(Recipient) Then
		Message.Header.Recipient = MessageExchangeNodeDescription(Recipient);
	EndIf;
	
	SettingsStructure = InformationRegisters.ExchangeTransportSettings.TransportSettingsWS(Recipient);
	ConnectionParameters = New Structure;
	ConnectionParameters.Insert("URL",      SettingsStructure.WSURL);
	ConnectionParameters.Insert("UserName", SettingsStructure.WSUserName);
	ConnectionParameters.Insert("Password", SettingsStructure.WSPassword);

	TranslateMessageToCorrespondentVersionIfNecessary(
		Message, 
		ConnectionParameters,
		String(Recipient));
	
	UntypedBody = WriteMessageToUntypedBody(Message);
	
	MessageChannel = ChannelNameByMessageType(Message.Body.Type());
	
	If Now Then
		MessageExchange.SendMessageImmediately(MessageChannel, UntypedBody, Recipient);
	Else
		MessageExchange.SendMessage(MessageChannel, UntypedBody, Recipient);
	EndIf;
	
EndProcedure

// Gets a list of message handlers by namespace.
// 
// Parameters:
//  Handlers     - ValueTable - for the field structure, see MessageExchange.NewMessageHandlerTable.
//  Namespace    - String - URL of a namespace that has message body types defined. 
//  CommonModule - common module containing message handlers.
// 
Procedure GetMessageChannelHandlers(Val Handlers, Val Namespace, Val CommonModule) Export
	
	ChannelNames = MessagesSaaSCached.GetPackageChannels(Namespace);
	
	For Each ChannelName In ChannelNames Do
		Handler = Handlers.Add();
		Handler.Channel = ChannelName;
		Handler.Handler = CommonModule;
	EndDo;
	
EndProcedure

// Returns a name of message channel matching the message type.
//
// Parameters:
//  MessageType - XDTODataObjectType - remote administration message type.
//
// Returns:
//  String - name of a message channel matching the sent message type.
//
Function ChannelNameByMessageType(Val MessageType) Export
	
	Return XDTOSerializer.XMLString(New XMLExpandedName(MessageType.NamespaceURI, MessageType.Name));
	
EndFunction

// Returns remote administration message type by the message channel name.
//
// Parameters:
//  ChannelName - String - name of a message channel matching the sent message type.
//
// Returns:
//  XDTODataObjectType - remote administration message type.
//
Function MessageTypeByChannelName(Val ChannelName) Export
	
	Return XDTOFactory.Type(XDTOSerializer.XMLValue(Type("XMLExpandedName"), ChannelName));
	
EndFunction

// Raises an exception when a message is received in an unknown channel.
//
// Parameters:
//  MessageChannel - String - unknown message channel name.
//
Procedure UnknownChannelNameError(Val MessageChannel) Export
	
	MessagePattern = NStr("en = 'Unknown message channel name %1'");
	MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, MessageChannel);
	Raise(MessageText);
	
EndProcedure

// Reads a message from the untyped message body.
//
// Parameters:
//  UntypedBody - String - untyped message body.
//
// Returns:
//  {http://www.1c.ru/SaaS/Messages}Message - message.
//
Function ReadMessageFromUntypedBody(Val UntypedBody) Export
	
	Read = New XMLReader;
	Read.SetString(UntypedBody);
	
	Message = XDTOFactory.ReadXML(Read, MessagesSaaSCached.MessageType());
	
	Read.Close();
	
	Return Message;
	
EndFunction

// Writes a message to the untyped message body.
//
// Parameters:
//  Message - {http://www.1c.ru/SaaS/Messages}Message - message.
//
// Returns:
//  String - untyped message body.
//
Function WriteMessageToUntypedBody(Val Message) Export
	
	Write = New XMLWriter;
	Write.SetString();
	XDTOFactory.WriteXML(Write, Message, , , , XMLTypeAssignment.Explicit);
	
	Return Write.Close();
	
EndFunction

// Writes a message processing start event to the event log.
//
// Parameters:
//  Message - {http://www.1c.ru/SaaS/Messages}Message - message.
//
Procedure WriteProcessingStartEvent(Val Message) Export
	
	WriteLogEvent(NStr("en = 'Messages SaaS.Start processing'",
		CommonUseClientServer.DefaultLanguageCode()),
		EventLogLevel.Information,
		,
		,
		MessagePresentationForLog(Message));
	
EndProcedure

// Writes a message processing end event to the event log.
//
// Parameters:
//  Message - {http://www.1c.ru/SaaS/Messages}Message - message.
//
Procedure WriteProcessingEndEvent(Val Message) Export
	
	WriteLogEvent(NStr("en = 'Messages SaaS.End processing'",
		CommonUseClientServer.DefaultLanguageCode()),
		EventLogLevel.Information,
		,
		,
		MessagePresentationForLog(Message));
	
	EndProcedure

// Performs quick message delivery.
//
Procedure DeliverQuickMessages() Export
	
	If TransactionActive() Then
		Raise(NStr("en = 'Quick message delivery is not available during transaction'"));
	EndIf;
	
	JobMethodName = "MessageExchange.DeliverMessages";
	JobKey = 1;
	
	SetPrivilegedMode(True);
	
	JobFilter = New Structure;
	JobFilter.Insert("MethodName", JobMethodName);
	JobFilter.Insert("Key", JobKey);
	JobFilter.Insert("State", BackgroundJobState.Active);
	
	Jobs = BackgroundJobs.GetBackgroundJobs(JobFilter);
	If Jobs.Count() > 0 Then
		Try
			Jobs[0].WaitForCompletion(3);
		Except
			
			Job = BackgroundJobs.FindByUUID(Jobs[0].UUID);
			If Job.State = BackgroundJobState.Failed
				And Job.ErrorInfo <> Undefined Then
				
				Raise(DetailErrorDescription(Job.ErrorInfo));
			EndIf;
			
			Return;
		EndTry;
	EndIf;
		
	Try
		BackgroundJobs.Execute(JobMethodName, , JobKey, NStr("en = 'Quick message delivery'"))
	Except
		// No additional exception processing is required.
		// The only expected exception is duplicating a job with identical key.
		WriteLogEvent(NStr("en = 'Quick message delivery'",
			CommonUseClientServer.DefaultLanguageCode()), EventLogLevel.Error, , ,
			DetailErrorDescription(ErrorInfo()));
	EndTry;
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

// "Before send message" event handler.
// This event handler is called before writing a message to be sent.
// The handler is called separately for each message.
//
// Parameters:
//  MessageChannel - String    - ID of the message channel that delivered the message.
//  Body           - Arbitrary - body of the message to be written.
//
Procedure MessagesBeforeSend(Val MessageChannel, Val Body) Export
	
	If Not CommonUse.UseSessionSeparator() Then
		Return;
	EndIf;
	
	Message = Undefined;
	If BodyContainsTypedMessage(Body, Message) Then
		If MessagesSaaSCached.AreaBodyType().IsDescendant(Message.Body.Type()) Then
			If CommonUse.SessionSeparatorValue() <> Message.Body.Zone Then
				WriteLogEvent(NStr("en = 'Messages SaaS.Sending message'",
					CommonUseClientServer.DefaultLanguageCode()),
					EventLogLevel.Error,
					,
					,
					MessagePresentationForLog(Message));
					
				ErrorPattern = NStr("en = 'Message sending error. Data area %1 does not match the current data area (%2).'");
				ErrorText = StringFunctionsClientServer.SubstituteParametersInString(ErrorPattern, 
					Message.Body.Zone, CommonUse.SessionSeparatorValue());
					
				Raise(ErrorText);
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

// "On send message" event handler.
// This event handler is called before a message is sent to an XML data stream.
// The handler is called separately for each message to be sent.
//
// Parameters:
//  MessageChannel - String    - ID of a message channel used to send the message.
//  Body           - Arbitrary - body of the message to be sent. In this event handler,
//                               message body can be modified (for example, new data added).
//
Procedure OnSendMessage(MessageChannel, Body, MessageObject) Export
	
	Message = Undefined;
	If BodyContainsTypedMessage(Body, Message) Then
		
		Message.Header.Sent = CurrentUniversalDate();
		Body = WriteMessageToUntypedBody(Message);
		
		WriteLogEvent(NStr("en = 'Messages SaaS.Sending'",
			CommonUseClientServer.DefaultLanguageCode()),
			EventLogLevel.Information,
			,
			,
			MessagePresentationForLog(Message));
		
	EndIf;
	
	If CommonUseCached.IsSeparatedConfiguration() Then
		
		MessagesSaaSDataSeparationModule = CommonUse.CommonModule("MessagesSaaSDataSeparation");
		MessagesSaaSDataSeparationModule.OnSendMessage(MessageChannel, Body, MessageObject);
		
	EndIf;
	
	MessagesSaaSOverridable.OnSendMessage(MessageChannel, Body, MessageObject);
	
EndProcedure

// "On receive message" event handler.
// This event handler is called after a message is received from an XML data stream.
// The handler is called separately for each received message.
//
// Parameters:
//  MessageChannel - String    - ID of a message channel used to receive the message.
//  MessageBody    - Arbitrary - body of the received message. In this event handler,
//                               message body can be modified (for example, new data added).
//
Procedure OnReceiveMessage(MessageChannel, Body, MessageObject) Export
	
	Message = Undefined;
	If BodyContainsTypedMessage(Body, Message) Then
		
		Message.Header.Delivered = CurrentUniversalDate();
		
		Body = WriteMessageToUntypedBody(Message);
		
		WriteLogEvent(NStr("en = 'Messages SaaS.Receiving'",
			CommonUseClientServer.DefaultLanguageCode()),
			EventLogLevel.Information,
			,
			,
			MessagePresentationForLog(Message));
		
	EndIf;
	
	If CommonUseCached.IsSeparatedConfiguration() Then
		
		MessagesSaaSDataSeparationModule = CommonUse.CommonModule("MessagesSaaSDataSeparation");
		MessagesSaaSDataSeparationModule.OnReceiveMessage(MessageChannel, Body, MessageObject);
		
	EndIf;
	
	MessagesSaaSOverridable.OnReceiveMessage(MessageChannel, Body, MessageObject);
	
EndProcedure

Function MessageExchangeNodeDescription(Val Node)
	
	Attributes = CommonUse.ObjectAttributeValues(
		Node,
		New Structure("Code, Description"));
	
	Description = XDTOFactory.Create(MessagesSaaSCached.MessageExchangeNodeType());
	Description.Code = Attributes.Code;
	Description.Presentation = Attributes.Description;
	
	Return Description;
	
EndFunction

// For internal use
//
Function BodyContainsTypedMessage(Val UntypedBody, Message) Export
	
	If TypeOf(UntypedBody) <> Type("String") Then
		Return False;
	EndIf;
	
	If Left(UntypedBody, 1) <> "<" Or Right(UntypedBody, 1) <> ">" Then
		Return False;
	EndIf;
	
	Try
		Read = New XMLReader;
		Read.SetString(UntypedBody);
		
		Message = XDTOFactory.ReadXML(Read);
		
		Read.Close();
		
	Except
		Return False;
	EndTry;
	
	Return Message.Type() = MessagesSaaSCached.MessageType();
	
EndFunction

Function MessagePresentationForLog(Val Message)
	
	Template = NStr("en = 'Channel: %1'", CommonUseClientServer.DefaultLanguageCode());
	Presentation = StringFunctionsClientServer.SubstituteParametersInString(Template, 
		ChannelNameByMessageType(Message.Body.Type()));
		
	Write = New XMLWriter;
	Write.SetString();
	XDTOFactory.WriteXML(Write, Message.Header, , , , XMLTypeAssignment.Explicit);
		
	Template = NStr("en = 'Title: %1'", CommonUseClientServer.DefaultLanguageCode());
	Presentation = Presentation + Chars.LF + StringFunctionsClientServer.SubstituteParametersInString(Template, 
		Write.Close());
		
	If MessagesSaaSCached.AreaBodyType().IsDescendant(Message.Body.Type()) Then
		Template = NStr("en = 'Data area: %1'", CommonUseClientServer.DefaultLanguageCode());
		Presentation = Presentation + Chars.LF + StringFunctionsClientServer.SubstituteParametersInString(Template, 
			Format(Message.Body.Zone, "NZ=0;NG="));
	EndIf;
		
	Return Presentation;
	
EndFunction

// Translates the message to be sent to a version supported by the correspondent infobase.
//
// Parameters:
//  Message               - XDTODataObject - message to be sent.
//  ConnectionInformation - Structure      - correspondent infobase connection parameters.
//  RecipientPresentation - String         - recipient infobase presentation.
//
// Returns:
//  XDTODataObject - message translated to the recipient infobase version.
//
Procedure TranslateMessageToCorrespondentVersionIfNecessary(Message, Val ConnectionInformation, Val RecipientPresentation) Export
	
	MessageInterface = XDTOTranslationInternal.GetMessageInterface(Message);
	If MessageInterface = Undefined Then
		Raise NStr("en = 'Cannot determine the sent message interface: no interface handlers are registered for any of the types used in the message.'");
	EndIf;
		
	If Not ConnectionInformation.Property("URL") 
			Or Not ValueIsFilled(ConnectionInformation.URL) Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'URL for service performing message exchange with infobase %1 is not specified'"), RecipientPresentation);
	EndIf;
	
	CorrespondentVersion = MessageInterfacesSaaS.CorrespondentInterfaceVersion(
			MessageInterface.Interface, ConnectionInformation, RecipientPresentation);
			
	If CorrespondentVersion = Undefined Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Correspondent %1 does not support receiving interface %2 message versions supported by the current infobase.'"),
			RecipientPresentation, MessageInterface.Interface);
	EndIf;
	
	VersionToSend = MessageInterfacesSaaS.GetOutgoingMessageVersions().Get(MessageInterface.Interface);
	If VersionToSend = CorrespondentVersion Then
		Return;
	EndIf;
	
	Message = XDTOTranslation.TranslateToVersion(Message, CorrespondentVersion, MessageInterface.Namespace);
	
EndProcedure

#EndRegion
