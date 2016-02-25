////////////////////////////////////////////////////////////////////////////////
// MessageExchange: message exchange mechanism.
//
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// Sends a message to a targeted message channel.
// Corresponds to the "endpoint/endpoint" delivery type.
//
// Parameters:
//  MessageChannel         - String - targeted message channel ID.
//  MessageBody (optional) - Arbitrary - body of the system message to be delivered.
//  Recipient (optional)   - Undefined; ExchangePlanRef.MessageExchange; Array.
//    Undefined - message recipient is not specified. The message will be sent to endpoints 
//      determined by the current information system settings:
//      both the MessageExchangeOverridable.MessageRecipients handler (on application level) 
//      and the SenderSettings information register (on system settings level).
//    ExchangePlanRef.MessageExchange - exchange plan node matching the
//      message recipient endpoint. The message is delivered to the specified endpoint.
//    Array - array of message recipient names; all array items must conform 
//      to ExchangePlanRef.MessageExchange type.
//      The message is delivered to all endpoints listed in the array.
//      Default value: Undefined.
//
Procedure SendMessage(MessageChannel, Body = Undefined, Recipient = Undefined) Export
	
	SendMessageToMessageChannel(MessageChannel, Body, Recipient);
	
EndProcedure

// Sends a quick message to a targeted message channel.
// Corresponds to the "endpoint/endpoint" delivery type.
//
// Parameters:
//  MessageChannel         - String - targeted message channel ID.
//  MessageBody (optional) - Arbitrary - body of the system message to be delivered.
//  Recipient (optional)   - Undefined; ExchangePlanRef.MessageExchange; Array.
//    Undefined - message recipient is not specified. The message will be sent
//      to endpoints determined by the current information system settings:
//      both the MessageExchangeOverridable.MessageRecipients handler (on application level) 
//      and the SenderSettings information register (on system settings level).
//    ExchangePlanRef.MessageExchange - exchange plan node matching the
//      message recipient endpoint. The message is delivered to the specified endpoint.
//    Array - array of message recipient names; all array items must conform 
//      to ExchangePlanRef.MessageExchange type.
//      The message is delivered to all endpoints listed in the array.
//      Default value: Undefined.
//
Procedure SendMessageImmediately(MessageChannel, Body = Undefined, Recipient = Undefined) Export
	
	SendMessageToMessageChannel(MessageChannel, Body, Recipient, True);
	
EndProcedure

// Sends a message to a broadcast message channel.
// Corresponds to the "publication/subscription" delivery type.
// The message is delivered to all endpoints that subscribe to the broadcast channel.
// RecipientSubscriptions information register is used for broadcast channel subscription management.
//
// Parameters:
//  MessageChannel         - String - message broadcast channel ID.
//  MessageBody (optional) - Arbitrary - body of the system message to be delivered.
//
Procedure SendMessageToSubscribers(MessageChannel, Body = Undefined) Export
	
	SendMessageToSubscribersInMessageChannel(MessageChannel, Body);
	
EndProcedure

// Sends a quick message to a broadcast message channel.
// Corresponds to the "publication/subscription" delivery type.
// The message is delivered to all endpoints that subscribe to the broadcast channel.
// RecipientSubscriptions information register is used for broadcast channel subscription management.
//
// Parameters:
//  MessageChannel         - String - message broadcast channel ID.
//  MessageBody (optional) - Arbitrary - body of the system message to be delivered.
//
Procedure SendMessageToSubscribersImmediately(MessageChannel, Body = Undefined) Export
	
	SendMessageToSubscribersInMessageChannel(MessageChannel, Body, True);
	
EndProcedure

// Immediately sends quick messages from the common message queue.
// Message delivery cycle continues until all quick messages in the message queue are delivered.
// Immediate message delivery for other sessions is blocked until this message delivery is completed.
//
Procedure DeliverMessages() Export
	
	If TransactionActive() Then
		Raise NStr("en = 'Quick system message delivery is not available in active transactions.'");
	EndIf;
	
	SetPrivilegedMode(True);
	
	If Not StartSendingInstantMessages() Then
		Return;
	EndIf;
	
	QueryText = "";
	MessageCatalogs = MessageExchangeCached.GetMessageCatalogs();
	For Each MessageCatalog In MessageCatalogs Do
		
		IsFirstFragment = IsBlankString(QueryText);
		
		If Not IsFirstFragment Then
			
			QueryText = QueryText + "
			|
			|UNION ALL
			|"
			
		EndIf;
		
		QueryText = QueryText +
			"SELECT
			|	ChangeTable.Node AS Endpoint,
			|	ChangeTable.Ref AS Message
			|[INTO]
			|FROM
			|	[MessageCatalog].Changes AS ChangeTable
			|WHERE
			|	ChangeTable.Ref.IsInstantMessage
			|	AND ChangeTable.MessageNo IS NULL
			|	AND Not ChangeTable.Node IN (&UnavailableEndpoints)";
		
		QueryText = StrReplace(QueryText, "[MessageCatalog]", MessageCatalog.EmptyRef().Metadata().FullName());
		If IsFirstFragment Then
			QueryText = StrReplace(QueryText, "[INTO]", "INTO TT_Changes");
		Else
			QueryText = StrReplace(QueryText, "[INTO]", "");
		EndIf;		
	EndDo;
	
	QueryText = QueryText + "
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Changes.Endpoint AS Endpoint,
	|	TT_Changes.Message
	|FROM
	|	TT_Changes AS TT_Changes
	|
	|ORDER BY
	|	TT_Changes.Message.Code
	|TOTALS BY
	|	Endpoint";
	
	Query = New Query;
	Query.Text = QueryText;
	
	UnavailableEndpoints = New Array;
	
	Try
		
		While True Do
			
			Query.SetParameter("UnavailableEndpoints", UnavailableEndpoints);
			
			QueryResult = CommonUse.ExecuteQueryOutsideTransaction(Query);
			
			If QueryResult.IsEmpty() Then
				Break;
			EndIf;
			
			Groups = QueryResult.Unload(QueryResultIteration.ByGroupsWithHierarchy);
			
			For Each Group In Groups.Rows Do
				
				Messages = Group.Rows.UnloadColumn("Message");
				
				Try
					
					DeliverMessagesToRecipient(Group.Endpoint, Messages);
					
					DeleteChangeRecords(Group.Endpoint, Messages);
					
				Except
					
					UnavailableEndpoints.Add(Group.Endpoint);
					
					WriteLogEvent(MessageExchangeInternal.ThisSubsystemEventLogMessageText(),
											EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
				EndTry;
				
			EndDo;
			
		EndDo;
		
	Except
		CancelSendingInstantMessages();
		Raise;
	EndTry;
	
	FinishSendingInstantMessages();
	
EndProcedure

// Establishes endpoint connection.
// Prior to establishing endpoint connection, 
// both sender-to-recipient and recipient-to-sender connections are checked. 
// It is also verified whether the current sender is correctly specified in the recipient connection settings.
//
// Parameters:
//  Cancel - Boolean - flag specifying whether any errors occur during endpoint connection.
//  RecipientWebServiceURL - String - URL of the endpoint to be connected.
//  RecipientUserName      - String - name of the user to be authenticated at the endpoint 
//                                    when working via the message exchange subsystem web service.
//  RecipientPassword      - String - user password for the endpoint.
//  SenderWebServiceURL    - String - URL of the infobase (relative to the endpoint).
//  SenderUserName         - String - name of the user to be authenticated at the infobase 
//                                    when working via the message exchange subsystem web service.
//  SenderPassword         - String - user password for this infobase.
//  Endpoint - ExchangePlanRef.MessageExchange, Undefined - If endpoint connection is successful,
//                                        returns a reference to the exchange plan node matching
//                                        the connected endpoint.
//                                        If endpoint connection is unsuccessful, returns Undefined.
//  RecipientEndpointDescription - String - name of the endpoint to be connected. If not specified,
//                                        the endpoint configuration synonym is used.
//  SenderEndpointDescription    - String - name of the endpoint corresponding to this infobase. 
//                                        If not specified, the infobase configuration synonym is used.
//
Procedure ConnectEndpoint(Cancel,
									RecipientWebServiceURL,
									RecipientUserName,
									RecipientPassword,
									SenderWebServiceURL,
									SenderUserName,
									SenderPassword,
									Endpoint = Undefined,
									RecipientEndpointDescription = "",
									SenderEndpointDescription = ""
	) Export
	
	SenderConnectionSettings = DataExchangeServer.WSParameterStructure();
	SenderConnectionSettings.WSURL              = RecipientWebServiceURL;
	SenderConnectionSettings.WSUserName            = RecipientUserName;
	SenderConnectionSettings.WSPassword                     = RecipientPassword;
	
	RecipientConnectionSettings = DataExchangeServer.WSParameterStructure();
	RecipientConnectionSettings.WSURL              = SenderWebServiceURL;
	RecipientConnectionSettings.WSUserName            = SenderUserName;
	RecipientConnectionSettings.WSPassword                     = SenderPassword;
	
	MessageExchangeInternal.ConnectEndpointAtSender(Cancel, 
														SenderConnectionSettings,
														RecipientConnectionSettings,
														Endpoint,
														RecipientEndpointDescription,
														SenderEndpointDescription);
	
EndProcedure

// Updates connection parameters for an endpoint.
// Both infobase-to-endpoint and endpoint-to-infobase connection settings are updated.
// Before applying the connection settings, they are validated.
// It is also verified whether the current sender is correctly specified in the recipient connection settings.
//
// Parameters:
//  Cancel   - Boolean - flag specifying whether any errors have occurred.
//  Endpoint - ExchangePlanRef.MessageExchange - reference to an exchange plan node corresponding to the endpoint.
//  RecipientWebServiceURL - String - URL of the endpoint.
//  RecipientUserName      - String - name of the user to be authenticated at the endpoint 
//                                    when working via the message exchange subsystem web service.
//  RecipientPassword      - String - user password for the endpoint.
//  SenderWebServiceURL    - String - URL of the infobase (relative to the endpoint).
//  SenderUserName         - String - name of the user to be authenticated at the infobase 
//                                    when working via the message exchange subsystem web service.
//  SenderPassword         - String - user password for this infobase.
//
Procedure UpdateEndpointConnectionSettings(Cancel,
									Endpoint,
									RecipientWebServiceURL,
									RecipientUserName,
									RecipientPassword,
									SenderWebServiceURL,
									SenderUserName,
									SenderPassword
	) Export
	
	SenderConnectionSettings = DataExchangeServer.WSParameterStructure();
	SenderConnectionSettings.WSURL              = RecipientWebServiceURL;
	SenderConnectionSettings.WSUserName            = RecipientUserName;
	SenderConnectionSettings.WSPassword                     = RecipientPassword;
	
	RecipientConnectionSettings = DataExchangeServer.WSParameterStructure();
	RecipientConnectionSettings.WSURL              = SenderWebServiceURL;
	RecipientConnectionSettings.WSUserName            = SenderUserName;
	RecipientConnectionSettings.WSPassword                     = SenderPassword;
	
	MessageExchangeInternal.UpdateEndpointConnectionSettings(Cancel, Endpoint, SenderConnectionSettings, RecipientConnectionSettings);
	
EndProcedure

#EndRegion

#Region InternalInterface

// Declares SaaSOperations.MessageExchange subsystem events.
//
// Server events:
//
//   MessageChannelHandlersOnDefine,
//   OnDetermineMessageRecipients,
//   OnSendMessage,
//   OnReceiveMessage.
//
// See the description of this procedure in the StandardSubsystemsServer module.
Procedure OnAddInternalEvent(ClientEvents, ServerEvents) Export
	
	// SERVER EVENTS
	
	// Gets the list of message handlers that are processed by the library subsystems.
	// 
	// Parameters:
	//  Handlers - ValueTable - see the field structure in MessageExchange.NewMessageHandlerTable
	//
	// Syntax:
	// Procedure MessageChannelHandlersOnDefine(Handlers) Export
	//
	// For use in other libraries.
	//
	// (Identical to MessageExchangeOverridable.GetMessageChannelHandlers).
	//
	ServerEvents.Add(
		"StandardSubsystems.SaaSOperations.MessageExchange\MessageChannelHandlersOnDefine");
	
	// Gets a dynamic list of message endpoints.
	//
	// Parameters:
	//  MessageChannel - String - message channel ID.
	//  Recipients     - Array - array of endpoints to receive the message.
	//                   All array items must conform to the ExchangePlanRef.MessageExchange type.
	//                   This parameter must be defined in the handler body.
	//
	// Syntax:
	// Procedure OnDetermineMessageRecipients(Val MessageChannel, Recipients) Export
	//
	// (Identical to MessageExchangeOverridable.MessageRecipients).
	//
	ServerEvents.Add(
		"StandardSubsystems.SaaSOperations.MessageExchange\OnDetermineMessageRecipients");
	
	// "On send message" event handler.
	// This event handler is called before a message is sent to an XML data stream.
	// The handler is called separately for each message to be sent.
	//
	// Parameters:
	//  MessageChannel - String - ID of the message channel used to send the message.
	//  Body           - Arbitrary - body of the message to be sent.
	//   In this event handler, message body can be modified (for example, new data added).
	//
	// Syntax:
	// Procedure OnSendMessage(MessageChannel, MessageBody) Export
	//
	// (Identical to MessageExchangeOverridable.OnSendMessage).
	//
	ServerEvents.Add(
		"StandardSubsystems.SaaSOperations.MessageExchange\OnSendMessage");
	
	// "On receive message" event handler.
	// This event handler is called after a message is received from an XML data stream.
	// The handler is called separately for each received message.
	//
	// Parameters:
	//  MessageChannel - String - ID of the message channel that delivered a message.
	//  Body           - Arbitrary - body of the received message.
	//   In this event handler, message body can be modified (for example, new data added).
	//
	// Syntax:
	// Procedure OnReceiveMessage(MessageChannel, MessageBody) Export
	//
	// (Identical to MessageExchangeOverridable.OnReceiveMessage).
	//
	ServerEvents.Add(
		"StandardSubsystems.SaaSOperations.MessageExchange\OnReceiveMessage");
	
EndProcedure

// See the description of this procedure in the StandardSubsystemsServer module.
Procedure InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers) Export
	
	// SERVER HANDLERS
	
	ServerHandlers["StandardSubsystems.InfobaseVersionUpdate\OnAddUpdateHandlers"].Add(
		"MessageExchangeInternal");
	
	If CommonUse.SubsystemExists("StandardSubsystems.DataExchange") Then
		ServerHandlers["StandardSubsystems.DataExchange\OnDataExportInternal"].Add(
			"MessageExchange");
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.DataExchange") Then
		ServerHandlers["StandardSubsystems.DataExchange\OnDataImportInternal"].Add(
			"MessageExchange");
	EndIf;
	
	ServerHandlers["StandardSubsystems.BaseFunctionality\SupportedInterfaceVersionsOnDefine"].Add(
		"MessageExchange");
	
	If CommonUse.SubsystemExists("CloudTechnology.DataImportExport") Then
		ServerHandlers["CloudTechnology.DataImportExport\OnFillExcludedFromImportExportTypes"].Add(
			"MessageExchange");
	EndIf;
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

Procedure SendMessageToMessageChannel(MessageChannel, Body, Recipient, IsInstantMessage = False)
	
	If TypeOf(Recipient) = Type("ExchangePlanRef.MessageExchange") Then
		
		SendMessageToRecipient(MessageChannel, Body, Recipient, IsInstantMessage);
		
	ElsIf TypeOf(Recipient) = Type("Array") Then
		
		For Each Item In Recipient Do
			
			If TypeOf(Item) <> Type("ExchangePlanRef.MessageExchange") Then
				
				Raise NStr("en = 'Invalid recipient is specified for MessageExchange.SendMessage() method.'");
				
			EndIf;
			
			SendMessageToRecipient(MessageChannel, Body, Item, IsInstantMessage);
			
		EndDo;
		
	ElsIf Recipient = Undefined Then
		
		SendMessageToRecipients(MessageChannel, Body, IsInstantMessage);
		
	Else
		
		Raise NStr("en = 'Invalid recipient is specified for MessageExchange.SendMessage() method.'");
		
	EndIf;
	
EndProcedure

Procedure SendMessageToSubscribersInMessageChannel(MessageChannel, Body, IsInstantMessage = False)
	
	SetPrivilegedMode(True);
	
	Recipients = InformationRegisters.RecipientSubscriptions.MessageChannelSubscribers(MessageChannel);
	
	// Sending message to a recipient endpoint
	For Each Recipient In Recipients Do
		
		SendMessageToRecipient(MessageChannel, Body, Recipient, IsInstantMessage);
		
	EndDo;
	
EndProcedure

Procedure SendMessageToRecipients(MessageChannel, Body, IsInstantMessage)
	Var DynamicallyAddedRecipients;
	
	SetPrivilegedMode(True);
	
	// List of message recipients obtained from information register
	Recipients = InformationRegisters.SenderSettings.MessageChannelSubscribers(MessageChannel);
	
	// List of message recipients obtained from code
	
	EventHandlers = CommonUse.InternalEventHandlers(
		"StandardSubsystems.SaaSOperations.MessageExchange\OnDetermineMessageRecipients");
	For Each Handler In EventHandlers Do
		Handler.Module.OnDetermineMessageRecipients(MessageChannel, DynamicallyAddedRecipients);
	EndDo;
	
	MessageExchangeOverridable.MessageRecipients(MessageChannel, DynamicallyAddedRecipients);
	
	// Combining two arrays to create an array of unique recipients. 
	// Using a temporary value table for this purpose.
	RecipientTable = New ValueTable;
	RecipientTable.Columns.Add("Recipient");
	For Each Recipient In Recipients Do
		RecipientTable.Add().Recipient = Recipient;
	EndDo;
	
	If TypeOf(DynamicallyAddedRecipients) = Type("Array") Then
		
		For Each Recipient In DynamicallyAddedRecipients Do
			RecipientTable.Add().Recipient = Recipient;
		EndDo;
		
	EndIf;
	
	RecipientTable.GroupBy("Recipient");
	
	Recipients = RecipientTable.UnloadColumn("Recipient");
	
	// Sending message to a recipient endpoint
	For Each Recipient In Recipients Do
		
		SendMessageToRecipient(MessageChannel, Body, Recipient, IsInstantMessage);
		
	EndDo;
	
EndProcedure

Procedure SendMessageToRecipient(MessageChannel, Body, Recipient, IsInstantMessage)
	
	SetPrivilegedMode(True);
	
	If Not TransactionActive() Then
		
		Raise NStr("en = 'Message delivery is only available in transactions.'");
		
	EndIf;
	
	If Not ValueIsFilled(MessageChannel) Then
		
		Raise NStr("en = 'MessageChannel parameter value is not set for MessageExchange method.SendMessage.'");
		
	ElsIf StrLen(MessageChannel) > 150 Then
		
		Raise NStr("en = 'The length of message channel name cannot exceed 150 characters.'");
		
	ElsIf Not ValueIsFilled(Recipient) Then
		
		Raise NStr("en = 'Recipient parameter value is not set for MessageExchange method.SendMessage.'");
		
	ElsIf CommonUse.ObjectAttributeValue(Recipient, "Locked") Then
		
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Attempting to send message to locked endpoint %1.'"),
			String(Recipient));
	EndIf;
	
	CatalogForMessage = Catalogs.SystemMessages;
	StandardProcessing = True;
	
	If CommonUseCached.IsSeparatedConfiguration() Then
		MessagesSaaSDataSeparationModule = CommonUse.CommonModule("MessagesSaaSDataSeparation");
		OverriddenCatalog = MessagesSaaSDataSeparationModule.OnSelectCatalogForMessage(Body);
		If OverriddenCatalog <> Undefined Then
			CatalogForMessage = OverriddenCatalog;
		EndIf;
	EndIf;
	
	NewMessage = CatalogForMessage.CreateItem();
	NewMessage.Description = MessageChannel;
	NewMessage.Code = 0;
	NewMessage.ProcessMessageRetryCount = 0;
	NewMessage.Locked = False;
	NewMessage.Body = New ValueStorage(Body);
	NewMessage.Sender = MessageExchangeInternal.ThisNode();
	NewMessage.IsInstantMessage = IsInstantMessage;
	
	If Recipient = MessageExchangeInternal.ThisNode() Then
		
		NewMessage.Recipient = MessageExchangeInternal.ThisNode();
		
	Else
		
		NewMessage.DataExchange.Recipients.Add(Recipient);
		NewMessage.DataExchange.Recipients.AutoFill = False;
		
		NewMessage.Recipient = Recipient;
		
	EndIf;
	
	StandardWriteProcessing = True;
	If CommonUseCached.IsSeparatedConfiguration() Then
		MessagesSaaSDataSeparationModule = CommonUse.CommonModule("MessagesSaaSDataSeparation");
		MessagesSaaSDataSeparationModule.BeforeWriteMessage(NewMessage, StandardWriteProcessing);
	EndIf;
	
	If StandardWriteProcessing Then
		NewMessage.Write();
	EndIf;
	
EndProcedure

Function StartSendingInstantMessages()
	
	BeginTransaction();
	Try
		DataLock = New DataLock;
		LockItem = DataLock.Add("Constant.InstantMessageSendingLocked");
		LockItem.Mode = DataLockMode.Exclusive;
		DataLock.Lock();
		
		InstantMessageSendingLocked = Constants.InstantMessageSendingLocked.Get();
		
		// CurrentSessionDate() method cannot be used.
		// In this case, the current server date is used an a unique key.
		If InstantMessageSendingLocked >= CurrentDate() Then
			CommitTransaction();
			Return False;
		EndIf;
		
		Constants.InstantMessageSendingLocked.Set(CurrentDate() + 60 * 5);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	Return True;
EndFunction

Procedure FinishSendingInstantMessages()
	
	BeginTransaction();
	Try
		DataLock = New DataLock;
		LockItem = DataLock.Add("Constant.InstantMessageSendingLocked");
		LockItem.Mode = DataLockMode.Exclusive;
		DataLock.Lock();
		
		Constants.InstantMessageSendingLocked.Set(Date('00010101'));
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

Procedure CancelSendingInstantMessages()
	
	FinishSendingInstantMessages();
	
EndProcedure

Procedure DeleteChangeRecords(Endpoint, Val Messages)
	
	For Each Message In Messages Do
		
		ExchangePlans.DeleteChangeRecords(Endpoint, Message);
		
	EndDo;
	
EndProcedure

Procedure DeliverMessagesToRecipient(Endpoint, Val Messages)
	
	Stream = "";
	
	MessageExchangeInternal.SerializeDataToStream(Messages, Stream);
	
	MessageExchangeCached.WSEndpointProxy(Endpoint, 10).DeliverMessages(MessageExchangeInternal.ThisNodeCode(), New ValueStorage(Stream, New Deflation(9)));
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Internal event handlers of SL subsystems

// This procedure is called on data export.
// It is used for overriding the standard data export handler.
// The following operations must be implemented into this handler:
// selecting data to be exported, serializing data into a message file or into a stream.
// After the handler ends execution, exported data is sent to the data exchange subsystem recipient.
// Messages to be exported can have arbitrary format.
// If errors occur during sending data, the handler execution
// must be stopped using the Raise method with an error description.
//
// Parameters:
//
// StandardProcessing - Boolean -
//  this parameter contains a flag that shows whether the standard processing is used.
//  You can set this parameter value to False to cancel the standard processing.
//  Canceling standard processing does not cancel the operation.
//  The default value is True.
//
// Recipient - ExchangePlanRef -
//  exchange plan node for which data is exported.
//
// MessageFileName - String -
//  name of the file where the data is to be exported. If this parameter is filled, the platform expects 
//  that data will be exported to the file. After exporting, the platform sends data from this file.
//  If this parameter is  empty, the system expects that data is exported to the MessageData parameter.
//
// MessageData - Arbitrary -
//  if the MessageFileName parameter is empty, the platform expects that data is exported to this parameter.
//
// TransactionItemCount - Number -
//  defines the maximum number of data items that can be put into a message during one database transaction.
//  You can implement the algorithms of transaction locks for exported data in this handler.
//  A value of this parameter is set in the data exchange subsystem settings.
//
// EventLogEventName - String -
//  event log event name of the current data exchange session. This parameter is used to
//  determine the event name (errors, warnings, information) when writing error details to the event log.
//  It matches the EventName parameter of the WriteLogEvent method of the global context.
//
// SentObjectCount - Number -
//  sent object counter. It is used to store the number of exported objects in the exchange protocol.
//
Procedure OnDataExportInternal(StandardProcessing,
								Recipient,
								MessageFileName,
								MessageData,
								TransactionItemCount,
								EventLogEventName,
								SentObjectCount
	) Export
	
	MessageExchangeInternal.OnDataExport(StandardProcessing,
								Recipient,
								MessageFileName,
								MessageData,
								TransactionItemCount,
								EventLogEventName,
								SentObjectCount);
	
EndProcedure

// This procedure is called on data import.
// It is used for overriding the standard data import handler.
// The following operations must be implemented into this handler:
// necessary checking before importing data, serializing data from a message file or from a stream.
// Messages to be imported can have arbitrary format.
// If errors occur during receiving data, the handler execution
// must be stopped using the Raise method with an error description.
//
// Parameters:
//
//  StandardProcessing - Boolean -  this parameter contains a flag
//                                  that shows whether the standard processing is used. You can
//                                  set this parameter value to False to cancel the standard processing.
//                                  Canceling standard processing does not cancel the operation.
//                                  The default value is True.
//  Sender - ExchangePlanRef -      name of the exchange plan node sending the data.
//  MessageFileName - String -      name of the file where the data is to be imported.
//                                  If this parameter is empty, data to
//                                  be imported is passed in the MessageData parameter.
//  MessageData - Arbitrary -       this parameter may contain data to be imported.
//                                  If the MessageFileName parameter is empty, 
//                                  the data are to be imported through this parameter.
//  TransactionItemCount - Number - defines the maximum number of data items that can be read from a message 
//                                  and recorded to the infobase during one database transaction.
//                                  If it is necessary, you can implement algorithms 
//                                  of data recording in transaction.
//                                  A value of this parameter is set in the data exchange subsystem settings.
//  EventLogEventName - String -    event log event name of the current data exchange session.
//                                  This parameter is used to determine the event name 
//                                  (errors, warnings, information) when writing error details to the event log.
//                                  It matches the EventName parameter of the WriteLogEvent method of the global context.
// ReceivedObjectCount - Number -   received object counter. It is used to store 
//                                  the number of imported objects in the exchange protocol.
//
Procedure OnDataImportInternal(StandardProcessing,
								Sender,
								MessageFileName,
								MessageData,
								TransactionItemCount,
								EventLogEventName,
								ReceivedObjectCount
	) Export
	
	MessageExchangeInternal.OnDataImport(StandardProcessing,
								Sender,
								MessageFileName,
								MessageData,
								TransactionItemCount,
								EventLogEventName,
								ReceivedObjectCount);
	
EndProcedure

// Fills the structure with arrays of supported versions of the subsystems that can have versions.
// Subsystem names are used as structure keys.
// Implements the InterfaceVersion web service functionality.
// This procedure must return current version sets, therefore its body must be changed accordingly before use
// (see the example below).
//
// Parameters:
// SupportedVersionStructure - Structure: 
// - Keys = subsystem names. 
// - Values = arrays of supported version names.
//
// Example:
//
// // FileTransferService
// VersionArray = New Array;
// VersionArray.Add("1.0.1.1");	
// VersionArray.Add("1.0.2.1"); 
// SupportedVersionStructure.Insert("FileTransferService", VersionArray);
// // End FileTransferService
//
Procedure SupportedInterfaceVersionsOnDefine(Val SupportedVersionStructure) Export
	
	VersionArray = New Array;
	VersionArray.Add("2.0.1.6");
	VersionArray.Add("2.1.1.7");
	VersionArray.Add("2.1.1.8");
	SupportedVersionStructure.Insert("MessageExchange", VersionArray);
	
EndProcedure

// Fills the array of types excluded from data import and export.
//
// Parameters:
//  Types - Array(Types).
//
Procedure OnFillExcludedFromImportExportTypes(Types) Export
	
	CatalogArray = MessageExchangeCached.GetMessageCatalogs();
	For Each MessageCatalog In CatalogArray Do
		Types.Add(MessageCatalog.EmptyRef().Metadata());
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Handlers of conditional calls of other subsystems

// "On send message" event handler.
// This event handler is called before a message is sent to an XML data stream.
// The handler is called separately for each message to be sent.
//
// Parameters:
//  MessageChannel - String -    ID of the message channel that delivered a message.
//  Body           - Arbitrary - body of the received message. In this event handler,
//                               message body can be modified (for example, new data added).
//
Procedure OnSendMessage(MessageChannel, Body, MessageObject) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaSOperations") Then
		
		MessageModuleSaaS = CommonUse.CommonModule("MessagesSaaS");
		MessageModuleSaaS.OnSendMessage(MessageChannel, Body, MessageObject);
		
	EndIf;
	
EndProcedure

// "On receive message" event handler.
// This event handler is called after a message is received from an XML data stream.
// The handler is called separately for each received message.
//
// Parameters:
//  MessageChannel - String -    ID of the message channel that delivered a message.
//  Body           - Arbitrary - body of the received message. In this event handler, 
//                               message body can be modified (for example, new data added).
//
Procedure OnReceiveMessage(MessageChannel, Body, MessageObject) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaSOperations") Then
		MessageModuleSaaS = CommonUse.CommonModule("MessagesSaaS");
		MessageModuleSaaS.OnReceiveMessage(MessageChannel, Body, MessageObject);
	EndIf;
	
EndProcedure

#EndRegion