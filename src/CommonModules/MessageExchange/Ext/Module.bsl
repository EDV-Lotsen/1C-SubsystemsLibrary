////////////////////////////////////////////////////////////////////////////////
// MessageExchange: message exchange mechanism.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// Sends the message to the address message channel.
// Corresponds to the End point/End point send type.
//
// Parameters:
//  MessageChannel – String - address message channel ID.
//  Body (Optional) – Arbitrary - body of the system message to be sent.
//  Recipient (Optional) – Undefined, ExchangePlanRef.MessageExchange, or Array:
//   Undefined is passed if the message recipient is not specified. The message will be sent
//    to end points that is defined by MessageExchangeOverridable.MessageRecipients handler 
//    (programmatically) or in the SenderSettings information register (system settings).
//   ExchangePlanRef.MessageExchange - exchange plan node that corresponds to the end 
//    point. The message will be sent to this end point only.
//   Array of ExchangePlanRef.MessageExchange - array of message recipients. The message 
//    will be sent to all end points that are specified in this array.
//   The default value is Undefined.
//
Procedure SendMessage(MessageChannel, Body = Undefined, Recipient = Undefined) Export
	
	SendMessageToMessageChannel(MessageChannel, Body, Recipient);
	
EndProcedure

// Sends the instant message to the address message channel.
// Corresponds to the End point/End point send type.
//
// Parameters:
//  MessageChannel – String - address message channel ID.
//  Body (Optional) – Arbitrary - body of the system message to be sent.
//  Recipient (Optional) – Undefined, ExchangePlanRef.MessageExchange, or Array:
//   Undefined is passed if the message recipient is not specified. The message will be sent
//    to end points that is defined by MessageExchangeOverridable.MessageRecipients handler 
//    (programmatically) or in the SenderSettings information register (system settings).
//   ExchangePlanRef.MessageExchange - exchange plan node that corresponds to the end 
//    point. The message will be sent to this end point only.
//   Array of ExchangePlanRef.MessageExchange - array of message recipients. The message 
//    will be sent to all end points that are specified in this array.
//   The default value is Undefined.
//
Procedure SendMessageImmediately(MessageChannel, Body = Undefined, Recipient = Undefined) Export
	
	SendMessageToMessageChannel(MessageChannel, Body, Recipient, True);
	
EndProcedure

// Sends the message to the broadcast message channel.
// Corresponds to the Publication/Subscription send type.
// The message will be delivered to end points that are subscribed to the broadcast channel.
// You can set up broadcast channel subscriptions in the RecipientSubscriptions
// information register.
//
// Parameters:
//  MessageChannel – String - broadcast message channel ID.
//  Body (Optional) – Arbitrary - body of the system message to be sent.
//
Procedure SendMessageToSubscribers(MessageChannel, Body = Undefined) Export
	
	SendMessageToSubscribersInMessageChannel(MessageChannel, Body);
	
EndProcedure

// Sends the instant message to the broadcast message channel.
// Corresponds to the Publication/Subscription send type.
// The message will be delivered to the end points that are subscribed to the broadcast channel.
// You can set up broadcast channel subscriptions in the RecipientSubscriptions
// information register.
//
// Parameters:
//  MessageChannel – String - broadcast message channel ID.
//  Body (Optional) – Arbitrary - body of the system message to be sent.
//
Procedure SendMessageToSubscribersImmediately(MessageChannel, Body = Undefined) Export
	
	SendMessageToSubscribersInMessageChannel(MessageChannel, Body, True);
	
EndProcedure

// Performs immediate sending the instant message from the common message queue.
// Sending messages is performed in a loop until all instant messages from the queue are sent.
// Other sessions are locked for sending instant messages while sending these messages.
//
Procedure DeliverMessages() Export
	
	If TransactionActive() Then
		Raise NStr("en = 'Delivery of instant system messages cannot be performed in the active transaction.'");
	EndIf;
	
	SetPrivilegedMode(True);
	
	If Not StartSendingInstantMessages() Then
		Return;
	EndIf;
	
	QueryText =
	"SELECT
	|	SystemMessagesChanges.Node AS EndPoint,
	|	SystemMessagesChanges.Ref AS Message
	|FROM
	|	Catalog.SystemMessages.Changes AS SystemMessagesChanges
	|WHERE
	|	SystemMessagesChanges.Ref.IsInstantMessage
	|	AND SystemMessagesChanges.MessageNo IS NULL 
	|	AND NOT SystemMessagesChanges.Node IN (&UnavailableEndPoints)
	|
	|ORDER BY
	|	SystemMessagesChanges.Ref.Code
	|TOTALS BY
	|	EndPoint";
	
	Query = New Query;
	Query.Text = QueryText;
	
	UnavailableEndPoints = New Array;
	
	Try
		
		While True Do
			
			Query.SetParameter("UnavailableEndPoints", UnavailableEndPoints);
			
			QueryResult = MessageExchangeInternal.GetQueryResult(Query);
			
			If QueryResult.IsEmpty() Then
				Break;
			EndIf;
			
			Folders = QueryResult.Unload(QueryResultIteration.ByGroupsWithHierarchy);
			
			For Each Folder In Folders.Rows Do
				
				Messages = Folder.Rows.UnloadColumn("Message");
				
				Try
					
					DeliverMessagesToRecipient(Folder.EndPoint, Messages);
					
					DeleteChangeRecords(Folder.EndPoint, Messages);
					
				Except
					
					UnavailableEndPoints.Add(Folder.EndPoint);
					
					WriteLogEvent(MessageExchangeInternal.ThisSubsystemEventLogMessageText(),
											EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo())
					);
				EndTry;
				
			EndDo;
			
		EndDo;
		
	Except
		CancelSendingInstantMessages();
		Raise;
	EndTry;
	
	FinishSendingInstantMessages();
	
EndProcedure

// Connects the end point.
// Before connecting the end point, the procedure checks sender and recipient
// connection settings and whether recipient connection settings correspond to
// the current sender. 
//
// Parameters:
//  Cancel - Boolean - flag that shows whether errors occur while connecting the end point.
//  RecipientWebServiceURL - String - URL of the end point to be connected.
//  RecipientUserName - String - user name that will be used for authentication in 
//   the end point when working with the exchange subsystem web server. 
//  RecipientPassword - String - user password that will be used for authentication in the end point.
//  SenderWebServiceURL - String - URL of this infobase for the end point to be connected.
//  SenderUserName - String - user name that will be used for authentication in this infobase when working with the exchange subsystem web server.
//  SenderPassword - String - user password that will be used for authentication in this infobase.
//  EndPoint (Optional) - ExchangePlanRef.MessageExchange or Undefined. If the end point
//   connection is established successfully, the exchange plan node reference that
//   corresponds to the end point to be connected is returned to this parameter.
//   If the end point connection failed, Undefined is returned.
//  RecipientEndPointDescription (Optional) - String (150) - description of the end point
//   to be connected. If this value is not passed, the configuration synonym of the end 
//   point to be connected is used.
//  SenderEndPointDescription (Optional) - String (150) - end point description.
//   It corresponds to this infobase. If this value is not passed, the configuration 
//   synonym of this infobase is used.
//
Procedure ConnectEndPoint(Cancel,
									RecipientWebServiceURL,
									RecipientUserName,
									RecipientPassword,
									SenderWebServiceURL,
									SenderUserName,
									SenderPassword,
									EndPoint = Undefined,
									RecipientEndPointDescription = "",
									SenderEndPointDescription = "") Export
	
	SenderConnectionSettings = DataExchangeServer.WSParameterStructure();
	SenderConnectionSettings.WSURL = RecipientWebServiceURL;
	SenderConnectionSettings.WSUserName = RecipientUserName;
	SenderConnectionSettings.WSPassword = RecipientPassword;
	
	RecipientConnectionSettings = DataExchangeServer.WSParameterStructure();
	RecipientConnectionSettings.WSURL = SenderWebServiceURL;
	RecipientConnectionSettings.WSUserName = SenderUserName;
	RecipientConnectionSettings.WSPassword = SenderPassword;
	
	MessageExchangeInternal.ConnectEndPointAtSender(Cancel, 
														SenderConnectionSettings,
														RecipientConnectionSettings,
														EndPoint,
														RecipientEndPointDescription,
														SenderEndPointDescription);
	
EndProcedure

// Updates connection settings of the end point.
// Updates settings of the infobase connection to the end point and settings of the end point connection to this infobase.
// Before settings are applied, the procedure checks whether settings are correct and
// whether recipient connection settings correspond to the current sender. 
//
// Parameters:
//  Cancel - Boolean - flag that shows whether errors occur while updating connection settings.
//  EndPoint - ExchangePlanRef.MessageExchange - reference to the exchange plan node
//   that corresponds to the end point.
//  RecipientWebServiceURL - String - recipient web service URL.
//  RecipientUserName - String - user name that will be used for authentication in the end point when working with the exchange subsystem web server. 
//  RecipientPassword - String - user password that will be used for authentication in the end point.
//  SenderWebServiceURL - String - web service URL of this infobase.
//  SenderUserName - String - user name that will be used for authentication in this
//   infobase when working with the exchange subsystem web server.
//  SenderPassword - String - user password that will be used for authentication in this infobase.
//
Procedure UpdateEndPointConnectionSettings(Cancel,
									EndPoint,
									RecipientWebServiceURL,
									RecipientUserName,
									RecipientPassword,
									SenderWebServiceURL,
									SenderUserName,
									SenderPassword) Export
	
	SenderConnectionSettings = DataExchangeServer.WSParameterStructure();
	SenderConnectionSettings.WSURL = RecipientWebServiceURL;
	SenderConnectionSettings.WSUserName = RecipientUserName;
	SenderConnectionSettings.WSPassword = RecipientPassword;
	
	RecipientConnectionSettings = DataExchangeServer.WSParameterStructure();
	RecipientConnectionSettings.WSURL = SenderWebServiceURL;
	RecipientConnectionSettings.WSUserName = SenderUserName;
	RecipientConnectionSettings.WSPassword = SenderPassword;
	
	MessageExchangeInternal.UpdateEndPointConnectionSettings(Cancel, EndPoint, SenderConnectionSettings, RecipientConnectionSettings);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

Procedure SendMessageToMessageChannel(MessageChannel, Body, Recipient, IsInstantMessage = False)
	
	If TypeOf(Recipient) = Type("ExchangePlanRef.MessageExchange") Then
		
		SendMessageToRecipient(MessageChannel, Body, Recipient, IsInstantMessage);
		
	ElsIf TypeOf(Recipient) = Type("Array") Then
		
		For Each Element In Recipient Do
			
			If TypeOf(Element) <> Type("ExchangePlanRef.MessageExchange") Then
				
				Raise NStr("en = 'The recipient for the MessageExchange.SendMessage method is not valid.'");
				
			EndIf;
			
			SendMessageToRecipient(MessageChannel, Body, Element, IsInstantMessage);
			
		EndDo;
		
	ElsIf Recipient = Undefined Then
		
		SendMessageToRecipients(MessageChannel, Body, IsInstantMessage);
		
	Else
		
		Raise NStr("en = 'The recipient for the MessageExchange.SendMessage method is not valid.'");
		
	EndIf;
	
EndProcedure

Procedure SendMessageToSubscribersInMessageChannel(MessageChannel, Body, IsInstantMessage = False)
	
	SetPrivilegedMode(True);
	
	Recipients = InformationRegisters.RecipientSubscriptions.MessageChannelSubscribers(MessageChannel);
	
	// Sending the message to recipients (end points)
	For Each Recipient In Recipients Do
		
		SendMessageToRecipient(MessageChannel, Body, Recipient, IsInstantMessage);
		
	EndDo;
	
EndProcedure

Procedure SendMessageToRecipients(MessageChannel, Body, IsInstantMessage)
	Var DynamicallyAddedRecipients;
	
	SetPrivilegedMode(True);
	
	// Recipients from the register
	Recipients = InformationRegisters.SenderSettings.MessageChannelSubscribers(MessageChannel);
	
	// Recipients from the script
	MessageExchangeOverridable.MessageRecipients(MessageChannel, DynamicallyAddedRecipients);
	
	// Assembling an array of unique recipients from two arrays
	// with a temporary value table.
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
	
	// Sending the message to recipients (end points)
	For Each Recipient In Recipients Do
		
		SendMessageToRecipient(MessageChannel, Body, Recipient, IsInstantMessage);
		
	EndDo;
	
EndProcedure

Procedure SendMessageToRecipient(MessageChannel, Body, Recipient, IsInstantMessage)
	
	If Not TransactionActive() Then
		
		Raise NStr("en = 'Messages can be sent only in a transaction.'");
		
	EndIf;
	
	If Not ValueIsFilled(MessageChannel) Then
		
		Raise NStr("en = 'The MessageChannel parameter value for the MessageExchange.SendMessage method is not specified.'");
		
	ElsIf StrLen(MessageChannel) > 150 Then
		
		Raise NStr("en = 'The message channel name cannot be more than 150 characters in length.'");
		
	ElsIf Not ValueIsFilled(Recipient) Then
		
		Raise NStr("en = 'The Recipient parameter value for the MessageExchange.SendMessage method is not specified.'");
		
	EndIf;
	
	SetPrivilegedMode(True);
	
	NewMessage = Catalogs.SystemMessages.CreateItem();
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
	
	NewMessage.Write();
	
EndProcedure

Function StartSendingInstantMessages()
	
	BeginTransaction();
	Try
		Lock = New DataLock;
		LockItem = Lock.Add("Constant.InstantMessageSendingLocked");
		LockItem.Mode = DataLockMode.Exclusive;
		Lock.Lock();
		
		InstantMessageSendingLocked = Constants.InstantMessageSendingLocked.Get();
		
		// The CurrentSessionDate method cannot be used.
		// In this case, the current server date is used as a key of uniqueness.
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
		Lock = New DataLock;
		LockItem = Lock.Add("Constant.InstantMessageSendingLocked");
		LockItem.Mode = DataLockMode.Exclusive;
		Lock.Lock();
		
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

Procedure DeleteChangeRecords(EndPoint, Val Messages)
	
	For Each Message In Messages Do
		
		ExchangePlans.DeleteChangeRecords(EndPoint, Message);
		
	EndDo;
	
EndProcedure

Procedure DeliverMessagesToRecipient(EndPoint, Val Messages)
	
	Stream = "";
	
	MessageExchangeInternal.SerializeDataToStream(Messages, Stream);
	
	MessageExchangeCached.WSEndPointProxy(EndPoint).DeliverMessages(MessageExchangeInternal.ThisNodeCode(), New ValueStorage(Stream, New Deflation(9)));
	
EndProcedure

