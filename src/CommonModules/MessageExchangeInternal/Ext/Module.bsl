////////////////////////////////////////////////////////////////////////////////
// MessageExchangeInternal.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// INTERNAL INTERFACE

////////////////////////////////////////////////////////////////////////////////
// Data exchange subsystem event handlers.

// Data exchange subsystem BeforeSendData event handler.
// See CommonModule.DataExchangeOverridable.BeforeSendData() for details.
//
Procedure BeforeSendData(StandardProcessing,
								Recipient,
								MessageFileName,
								MessageData,
								TransactionItemCount,
								EventLogEventName,
								SentObjectCount) Export
	
	If TypeOf(Recipient) <> Type("ExchangePlanRef.MessageExchange") Then
		Return;
	EndIf;
	
	StandardProcessing = False;
	
	DataSelectionTable = New ValueTable;
	DataSelectionTable.Columns.Add("Data");
	DataSelectionTable.Columns.Add("Order", New TypeDescription("Number"));
	
	WriteToFile = Not IsBlankString(MessageFileName);
	
	XMLWriter = New XMLWriter;
	
	If WriteToFile Then
		XMLWriter.OpenFile(MessageFileName);
	Else
		XMLWriter.SetString();
	EndIf;
	
	XMLWriter.WriteXMLDeclaration();
	
	// Creating a new message
	WriteMessage = ExchangePlans.CreateMessageWriter();
	
	WriteMessage.BeginWrite(XMLWriter, Recipient);
	
	// Counting written objects
	WrittenObjectCount = 0;
	SentObjectCount = 0;
	
	UseTransactions = TransactionItemCount <> 1;
	
	If UseTransactions Then
		BeginTransaction();
	EndIf;
	
	Try
		
		// Retrieving a selection of changed data
		ChangeSelection = ExchangePlans.SelectChanges(WriteMessage.Recipient, WriteMessage.MessageNo);
		
		While ChangeSelection.Next() Do
			
			TableRow = DataSelectionTable.Add();
			TableRow.Data = ChangeSelection.Get();
			TableRow.Order = ?(TypeOf(TableRow.Data) = Type("CatalogObject.SystemMessages"), TableRow.Data.Code, 0);
			
		EndDo;
		
		DataSelectionTable.Sort("Order Asc");
		
		For Each TableRow In DataSelectionTable Do
			
			If TypeOf(TableRow.Data) = Type("CatalogObject.SystemMessages") Then
				TableRow.Data.Code = 0;
			EndIf;
			
			// Writing data to the message
			WriteXML(XMLWriter, TableRow.Data);
			
			WrittenObjectCount = WrittenObjectCount + 1;
			SentObjectCount = SentObjectCount + 1;
			
			If UseTransactions
				And TransactionItemCount > 0
				And WrittenObjectCount = TransactionItemCount Then
				
				// Committing the transaction and beginning a new one
				CommitTransaction();
				BeginTransaction();
				
				WrittenObjectCount = 0;
			EndIf;
			
		EndDo;
		
		If UseTransactions Then
			CommitTransaction();
		EndIf;
		
		// Finishing writing the message
		WriteMessage.EndWrite();
		
		MessageData = XMLWriter.Close();
		
	Except
		
		If UseTransactions Then
			RollbackTransaction();
		EndIf;
		
		WriteMessage.CancelWrite();
		XMLWriter.Close();
		Raise DetailErrorDescription(ErrorInfo());
	EndTry;
	
EndProcedure

// Data exchange subsystem BeforeReceiveData event handler.
// See CommonModule.DataExchangeOverridable.BeforeReceiveData() for details.
//
Procedure BeforeReceiveData(StandardProcessing,
								Sender,
								MessageFileName,
								MessageData,
								TransactionItemCount,
								EventLogEventName,
								ReceivedObjectCount) Export
	
	If TypeOf(Sender) <> Type("ExchangePlanRef.MessageExchange") Then
		Return;
	EndIf;
	
	StandardProcessing = False;
	
	XMLReader = New XMLReader;
	
	If Not IsBlankString(MessageData) Then
		XMLReader.SetString(MessageData);
	Else
		XMLReader.OpenFile(MessageFileName);
	EndIf;
	
	MessageReader = ExchangePlans.CreateMessageReader();
	MessageReader.BeginRead(XMLReader, AllowedMessageNo.Greater);
	
	// Deleting change records of the message sender node
	ExchangePlans.DeleteChangeRecords(MessageReader.Sender, MessageReader.ReceivedNo);
	
	// Counting read objects
	WrittenObjectCount = 0;
	ReceivedObjectCount = 0;
	
	UseTransactions = TransactionItemCount <> 1;
	
	If UseTransactions Then
		BeginTransaction();
	EndIf;
	
	Try
		
		// Reading message data
		While CanReadXML(XMLReader) Do
			
			// Reading the next value
			Data = ReadXML(XMLReader);
			
			ReceivedObjectCount = ReceivedObjectCount + 1;
			
			// If the same data was changed in both infobases, the current one has higher priority.
			If ExchangePlans.IsChangeRecorded(MessageReader.Sender, Data) Then
				Continue;
			EndIf;
			
			Data.DataExchange.Sender = MessageReader.Sender;
			Data.DataExchange.Load = True;
			
			If TypeOf(Data) = Type("CatalogObject.SystemMessages") Then
				
				Data.SetNewCode();
				Data.Sender = MessageReader.Sender;
				Data.Recipient = ThisNode();
				Data.AdditionalProperties.Insert("DontCheckEditProhibitionDates");
				
			ElsIf TypeOf(Data) = Type("InformationRegisterRecordSet.RecipientSubscriptions") Then
				
				Data.Filter["Recipient"].Value = MessageReader.Sender;
				
				For Each RecordSetRow In Data Do
					
					RecordSetRow.Recipient = MessageReader.Sender;
					
				EndDo;
				
			EndIf;
			
			Data.Write();
			
			WrittenObjectCount = WrittenObjectCount + 1;
			
			If UseTransactions
				And TransactionItemCount > 0
				And WrittenObjectCount = TransactionItemCount Then
				
				// Committing the transaction and beginning a new one
				CommitTransaction();
				BeginTransaction();
				
				WrittenObjectCount = 0;
			EndIf;
			
		EndDo;
		
		MessageReader.EndRead();
		XMLReader.Close();
		
		If UseTransactions Then
			CommitTransaction();
		EndIf;
		
	Except
		If UseTransactions Then
			RollbackTransaction();
		EndIf;
		MessageReader.CancelRead();
		Raise;
	EndTry;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Infobase update.

// Adds update handlers required by this subsystem to the Handlers list. 
// 
// Parameters:
//  Handlers - ValueTable - see InfoBaseUpdate.NewUpdateHandlerTable function for details.
// 
Procedure RegisterUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version = "*";
	Handler.SharedData = True;
	Handler.Procedure = "MessageExchangeInternal.SetThisEndPointCode";
	
EndProcedure

// Sets a code for this end point if the code is not specified yet.
//
Procedure SetThisEndPointCode() Export
	
	If IsBlankString(ThisNodeCode()) Then
		
		ThisEndPoint = ThisNode().GetObject();
		ThisEndPoint.Code = String(New UUID());
		ThisEndPoint.Write();
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

////////////////////////////////////////////////////////////////////////////////
// Export internal procedures and functions.

// The handler of the scheduled job that sends and receives system messages.
//
Procedure SendReceiveMessagesByScheduledJob() Export
	
	If IsBlankString(UserName()) Then
		SetPrivilegedMode(True);
	EndIf;
	
	SendAndReceiveMessages(False);
	
EndProcedure

// Sends and receives system messages.
//
// Parameters:
//  Cancel – Boolean. Cancel flag. It will be set to True if an error occurs during the procedure execution.
//
Procedure SendAndReceiveMessages(Cancel) Export
	
	SetPrivilegedMode(True);
	
	SendReceiveMessagesViaWebServiceExecute(Cancel);
	
	SendReceiveMessagesViaStandardCommunicationLines(Cancel);
	
	ProcessSystemMessageQueue();
	
EndProcedure

// For internal use only
//
Procedure ProcessSystemMessageQueue(Filter = Undefined) Export
	
	SetPrivilegedMode(True);
	
	MessageHandlers = MessageHandlers();
	
	QueryText =
	"SELECT TOP 100
	|	SystemMessages.Ref AS Ref
	|FROM
	|	Catalog.SystemMessages AS SystemMessages
	|WHERE
	|	SystemMessages.Recipient = &Recipient
	|	AND (NOT SystemMessages.Locked)
	|	[Filter]
	|
	|ORDER BY
	|	SystemMessages.Code";
	
	FilterString = ?(Filter = Undefined, "", "AND SystemMessages.Ref In(&Filter)");
	
	QueryText = StrReplace(QueryText, "[Filter]", FilterString);
	
	Query = New Query;
	Query.SetParameter("Recipient", ThisNode());
	Query.SetParameter("Filter", Filter);
	Query.Text = QueryText;
	
	QueryResult = GetQueryResult(Query);
	
	Selection = QueryResult.Choose();
	
	While Selection.Next() Do
		
		MessageObject = Selection.Ref.GetObject();
		
		Try
			MessageObject.Lock();
		Except
			WriteLogEvent(ThisSubsystemEventLogMessageText(),
				EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
			Continue;
		EndTry;
		
		Try
			
			MessageTitle = New Structure("MessageChannel, Sender", MessageObject.Description, MessageObject.Sender);
			
			FoundRows = MessageHandlers.FindRows(New Structure("Channel", MessageTitle.MessageChannel));
			
			MessageHandled = True;
			
			// Handling message
			Try
				
				If FoundRows.Count() = 0 Then
					MessageObject.Locked = True;
					Raise NStr("en = 'The message handler is not defined.'");
				EndIf;
				
				For Each TableRow In FoundRows Do
					
					TableRow.Handler.ProcessMessage(MessageTitle.MessageChannel, MessageObject.Body.Get(), MessageTitle.Sender);
					
				EndDo;
			Except
				
				While TransactionActive() Do
					RollbackTransaction();
				EndDo;
				
				MessageHandled = False;
				
				DetailErrorDescription = DetailErrorDescription(ErrorInfo());
				WriteLogEvent(ThisSubsystemEventLogMessageText(),
						EventLogLevel.Error,,,
						StringFunctionsClientServer.SubstituteParametersInString(
							NStr("en = 'Error handling the message %1: %2'"),
							MessageTitle.MessageChannel, DetailErrorDescription));
			EndTry;
			
			If MessageHandled Then
				
				// Deleting the message
				If ValueIsFilled(MessageObject.Sender)
					And MessageObject.Sender <> ThisNode() Then
					
					MessageObject.DataExchange.Recipients.Add(MessageObject.Sender);
					MessageObject.DataExchange.Recipients.AutoFill = False;
					
				EndIf;
				// Existence of catalog references should not interfere with catalog item deletion
				MessageObject.DataExchange.Load = True; 
				MessageObject.Delete();
				
			Else
				
				
				MessageObject.ProcessMessageRetryCount = MessageObject.ProcessMessageRetryCount + 1;
				MessageObject.DetailErrorDescription = DetailErrorDescription;
				
				If MessageObject.ProcessMessageRetryCount >= 3 Then
					MessageObject.Locked = True;
				EndIf;
				
				MessageObject.Write();
				
			EndIf;
			
		Except
			WriteLogEvent(ThisSubsystemEventLogMessageText(),
					EventLogLevel.Error,,,
					DetailErrorDescription(ErrorInfo()));
		EndTry;
		
	EndDo;
	
EndProcedure

// For internal use only.
//
Procedure SetLeadingEndpointAtSender(Cancel, SenderConnectionSettings, EndPoint) Export
	
	SetPrivilegedMode(True);
	
	ErrorMessageString = "";
	
	WSProxy = GetWSProxy(SenderConnectionSettings, ErrorMessageString);
	
	If WSProxy = Undefined Then
		Cancel = True;
		WriteLogEvent(LeadingEndPointSettingEventLogMessageText(), EventLogLevel.Error,,, ErrorMessageString);
		Return;
	EndIf;
	
	BeginTransaction();
	Try
		
		EndPointObject = EndPoint.GetObject();
		EndPointObject.Leading = False;
		EndPointObject.Write();
		
		// Updating connection settings
		RecordStructure = New Structure;
		RecordStructure.Insert("Node", EndPoint);
		RecordStructure.Insert("DefaultExchangeMessageTransportKind", Enums.ExchangeMessageTransportKinds.WS);
		
		RecordStructure.Insert("WSURL", SenderConnectionSettings.WSURL);
		RecordStructure.Insert("WSUserName", SenderConnectionSettings.WSUserName);
		RecordStructure.Insert("WSPassword", SenderConnectionSettings.WSPassword);
		
		// Adding the record to the information register
		InformationRegisters.ExchangeTransportSettings.AddRecord(RecordStructure);
		
		// Setting the recipient leading end point
		WSProxy.SetLeadingEndPoint(EndPointObject.Code, ThisNodeCode());
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Cancel = True;
		WriteLogEvent(LeadingEndPointSettingEventLogMessageText(), EventLogLevel.Error,,,
				DetailErrorDescription(ErrorInfo()));
		Return;
	EndTry;
	
EndProcedure

// For internal use only.
//
Procedure SetLeadingEndPointAtRecipient(ThisEndPointCode, LeadingEndPointCode) Export
	
	SetPrivilegedMode(True);
	
	If ExchangePlans.MessageExchange.FindByCode(ThisEndPointCode) <> ThisNode() Then
		ErrorMessageString = NStr("en = 'End point connection parameters are specified incorrectly. Connection parameters belong to a different end point.'");
		WriteLogEvent(LeadingEndPointSettingEventLogMessageText(),
				EventLogLevel.Error,,, ErrorMessageString);
		Raise ErrorMessageString;
	EndIf;
	
	BeginTransaction();
	Try
		
		EndPointNode = ExchangePlans.MessageExchange.FindByCode(LeadingEndPointCode);
		
		If EndPointNode.IsEmpty() Then
			
			Raise NStr("en = 'The end point is not found in the correspondent infobase.'");
			
		EndIf;
		EndPointNodeObject = EndPointNode.GetObject();
		EndPointNodeObject.Leading = True;
		EndPointNodeObject.Write();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteLogEvent(LeadingEndPointSettingEventLogMessageText(), EventLogLevel.Error,,,
				DetailErrorDescription(ErrorInfo()));
		Raise DetailErrorDescription(ErrorInfo());
	EndTry;
	
EndProcedure

// For internal use only.
//
Procedure ConnectEndPointAtReceiver(Cancel, Code, Description, RecipientConnectionSettings) Export
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		
		// Creating / Updating the exchange plan node that corresponds to the connected end point
		EndPointNode = ExchangePlans.MessageExchange.FindByCode(Code);
		If EndPointNode.IsEmpty() Then
			EndPointNodeObject = ExchangePlans.MessageExchange.CreateNode();
			EndPointNodeObject.Code = Code;
		Else
			EndPointNodeObject = EndPointNode.GetObject();
			EndPointNodeObject.ReceivedNo = 0;
		EndIf;
		EndPointNodeObject.Description = Description;
		EndPointNodeObject.Leading = True;
		EndPointNodeObject.Write();
		
		// Updating connection settings
		RecordStructure = New Structure;
		RecordStructure.Insert("Node", EndPointNodeObject.Ref);
		RecordStructure.Insert("DefaultExchangeMessageTransportKind", Enums.ExchangeMessageTransportKinds.WS);
		
		RecordStructure.Insert("DataExportTransactionItemCount", 0);
		RecordStructure.Insert("DataImportTransactionItemCount", 0);
		
		RecordStructure.Insert("WSURL", RecipientConnectionSettings.WSURL);
		RecordStructure.Insert("WSUserName", RecipientConnectionSettings.WSUserName);
		RecordStructure.Insert("WSPassword", RecipientConnectionSettings.WSPassword);
		
		// Adding the record to the information register
		InformationRegisters.ExchangeTransportSettings.AddRecord(RecordStructure);
		
		If GetFunctionalOption("UseDataExchange") = False Then
			Constants.UseDataExchange.Set(True);
		EndIf;
		
		// Setting the scheduled job usage attribute
		ScheduledJob = ScheduledJobs.FindPredefined(Metadata.ScheduledJobs.SendReceiveSystemMessages);
		If Not ScheduledJob.Use Then
			ScheduledJobsServer.SetScheduledJobUse(String(ScheduledJob.UUID), True);
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Cancel = True;
		WriteLogEvent(EndPointConnectionEventLogMessageText(), EventLogLevel.Error,,,
				DetailErrorDescription(ErrorInfo()));
		Raise DetailErrorDescription(ErrorInfo());
	EndTry;
	
EndProcedure

// For internal use only.
//
Procedure UpdateEndPointConnectionSettings(Cancel, EndPoint, SenderConnectionSettings, RecipientConnectionSettings) Export
	
	SetPrivilegedMode(True);
	
	ErrorMessageString = "";
	
	CorrespondentVersions = CorrespondentVersions(SenderConnectionSettings);
	CorrespondentVersion_2_0_1_6 = (CorrespondentVersions.Find("2.0.1.6") <> Undefined);
	
	If CorrespondentVersion_2_0_1_6 Then
		WSProxy = GetWSProxy_2_0_1_6(SenderConnectionSettings, ErrorMessageString);
	Else
		WSProxy = GetWSProxy(SenderConnectionSettings, ErrorMessageString);
	EndIf;
	
	If WSProxy = Undefined Then
		Cancel = True;
		WriteLogEvent(EndPointConnectionEventLogMessageText(), EventLogLevel.Error,,, ErrorMessageString);
		Return;
	EndIf;
	
	Try
		If CorrespondentVersion_2_0_1_6 Then
			WSProxy.CheckConnectionAtRecipient(XDTOSerializer.WriteXDTO(RecipientConnectionSettings), ThisNodeCode());
		Else
			WSProxy.CheckConnectionAtRecipient(ValueToStringInternal(RecipientConnectionSettings), ThisNodeCode());
		EndIf;
	Except
		Cancel = True;
		WriteLogEvent(EndPointConnectionEventLogMessageText(), EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		Return;
	EndTry;
	
	BeginTransaction();
	Try
		
		// Updating connection settings
		RecordStructure = New Structure;
		RecordStructure.Insert("Node", EndPoint);
		RecordStructure.Insert("DefaultExchangeMessageTransportKind", Enums.ExchangeMessageTransportKinds.WS);
		
		RecordStructure.Insert("WSURL", SenderConnectionSettings.WSURL);
		RecordStructure.Insert("WSUserName", SenderConnectionSettings.WSUserName);
		RecordStructure.Insert("WSPassword", SenderConnectionSettings.WSPassword);
		
		// Adding the record to the information register
		InformationRegisters.ExchangeTransportSettings.UpdateRecord(RecordStructure);
		
		If CorrespondentVersion_2_0_1_6 Then
			WSProxy.UpdateConnectionSettings(ThisNodeCode(), XDTOSerializer.WriteXDTO(RecipientConnectionSettings));
		Else
			WSProxy.UpdateConnectionSettings(ThisNodeCode(), ValueToStringInternal(RecipientConnectionSettings));
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Cancel = True;
		WriteLogEvent(EndPointConnectionEventLogMessageText(), EventLogLevel.Error,,,
				DetailErrorDescription(ErrorInfo())
		);
		Return;
	EndTry;
	
EndProcedure

// For internal use only.
//
Procedure AddMessageChannelHandler(Channel, ChannelHandler, Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Channel = Channel;
	Handler.Handler = ChannelHandler;
	
EndProcedure

// For internal use only.
//
Function ThisNodeCode() Export
	
	Return CommonUse.GetAttributeValue(ThisNode(), "Code");
	
EndFunction

// For internal use only.
//
Function ThisNodeDescription() Export
	
	Return CommonUse.GetAttributeValue(ThisNode(), "Description");
	
EndFunction

// For internal use only.
//
Function ThisNode() Export
	
	Return ExchangePlans.MessageExchange.ThisNode();
	
EndFunction

// For internal use only.
//
Function AllRecipients() Export
	
	QueryText =
	"SELECT
	|	MessageExchange.Ref AS Recipient
	|FROM
	|	ExchangePlan.MessageExchange AS MessageExchange
	|WHERE
	|	MessageExchange.Ref <> &ThisNode";
	
	Query = New Query;
	Query.SetParameter("ThisNode", ThisNode());
	Query.Text = QueryText;
	
	Return Query.Execute().Unload().UnloadColumn("Recipient");
EndFunction

// For internal use only.
//
Function GetQueryResult(Query) Export
	
	// The return value
	Result = Undefined;
	
	AttemptCount = 0;
	While AttemptCount < 5 Do
		Try
			Result = Query.Execute();
			Break;
		Except
			AttemptCount = AttemptCount + 1;
			
			If AttemptCount = 5 Then
				
				DetailErrorDescription = DetailErrorDescription(ErrorInfo());
				
				WriteLogEvent(ThisSubsystemEventLogMessageText(),
					EventLogLevel.Error,,, DetailErrorDescription
				);
				Raise DetailErrorDescription;
			EndIf;
			
		EndTry;
	EndDo;
	
	If Result = Undefined Then
		
		Raise(NStr("en = 'Error retrieving messages from the queue.'"));
		
	EndIf;
	
	Return Result;
EndFunction

// For internal use only.
//
Procedure SerializeDataToStream(DataSelection, Stream) Export
	
	XMLWriter = New XMLWriter;
	XMLWriter.SetString();
	XMLWriter.WriteXMLDeclaration();
	XMLWriter.WriteStartElement("Root");
	
	For Each Ref In DataSelection Do
		
		Data = Ref.GetObject();
		Data.Code = 0;
		
		WriteXML(XMLWriter, Data);
		
	EndDo;
	XMLWriter.WriteEndElement();
	
	Stream = XMLWriter.Close();
	
EndProcedure

// For internal use only.
//
Procedure SerializeDataFromStream(Sender, Stream, ImportedObjects = Undefined) Export
	
	ImportedObjects = New Array;
	
	BeginTransaction();
	Try
		
		XMLReader = New XMLReader;
		XMLReader.SetString(Stream);
		XMLReader.Read(); // the Root node
		XMLReader.Read(); // the object node
		
		While CanReadXML(XMLReader) Do
			
			Data = ReadXML(XMLReader);
			
			// If the same data was changed in both infobases, the current one has higher priority.
			If ExchangePlans.IsChangeRecorded(Sender, Data) Then
				Continue;
			EndIf;
			
			Data.DataExchange.Sender = Sender;
			Data.DataExchange.Load = True;
			
			If TypeOf(Data) <> Type("ObjectDeletion") Then
				
				Data.SetNewCode();
				Data.Sender = Sender;
				Data.Recipient = ThisNode();
				Data.AdditionalProperties.Insert("DontCheckEditProhibitionDates");
			EndIf;
			
			Data.Write();
			
			ImportedObjects.Add(Data.Ref);
			
		EndDo;
		
		XMLReader.Close();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure


// For internal use only.
//
Function GetWSProxy(SettingsStructure, ErrorMessageString = "") Export
	
	SettingsStructure.Insert("NamespaceWebServiceURL", "http://1c-dn.com/SL/MessageExchange");
	SettingsStructure.Insert("WSServiceName", "MessageExchange");
	
	Return DataExchangeServer.GetWSProxyByConnectionParameters(SettingsStructure, ErrorMessageString);
EndFunction

// For internal use only.
//
Function GetWSProxy_2_0_1_6(SettingsStructure, ErrorMessageString = "") Export
	
	SettingsStructure.Insert("NamespaceWebServiceURL", "http://1c-dn.com/SL/MessageExchange_2_0_1_6");
	SettingsStructure.Insert("WSServiceName", "MessageExchange_2_0_1_6");
	
	Return DataExchangeServer.GetWSProxyByConnectionParameters(SettingsStructure, ErrorMessageString);
EndFunction

// Returns an array of version numbers supported by correspondent API for the MessageExchange subsystem.
//
// Parameters:
// Correspondent – Structure or ExchangePlanRef - exchange plan note that matches the correspondent infobase.
//
// Returns:
// Array of version numbers that are supported by correspondent API.
//
Function CorrespondentVersions(Val Correspondent) Export
	
	If TypeOf(Correspondent) = Type("Structure") Then
		SettingsStructure = Correspondent;
	Else
		SettingsStructure = InformationRegisters.ExchangeTransportSettings.GetWSTransportSettings(Correspondent);
	EndIf;
	
	ConnectionParameters = New Structure;
	ConnectionParameters.Insert("URL", SettingsStructure.WSURL);
	ConnectionParameters.Insert("UserName", SettingsStructure.WSUserName);
	ConnectionParameters.Insert("Password", SettingsStructure.WSPassword);
	
	Return CommonUse.GetInterfaceVersions(ConnectionParameters, "MessageExchange");
EndFunction


// For internal use only.
//
Function EndPointConnectionEventLogMessageText() Export
	
	Return NStr("en = 'Message exchange. Connecting the end point.'");
	
EndFunction

// For internal use only.
//
Function LeadingEndPointSettingEventLogMessageText() Export
	
	Return NStr("en = 'Message exchange. Setting the leading end point.'");
	
EndFunction

// For internal use only.
//
Function ThisSubsystemEventLogMessageText() Export
	
	Return NStr("en = 'Message exchange.'");
	
EndFunction

// For internal use only.
//
Function ThisNodeDefaultDescription() Export
	
	Return ?(CommonUseCached.DataSeparationEnabled(), Metadata.Synonym, DataExchangeCached.ThisInfoBaseName());
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Local internal procedures and functions.

// For internal use only.
//
Procedure SendReceiveMessagesViaWebServiceExecute(Cancel)
	
	QueryText =
	"SELECT DISTINCT
	|	MessageExchange.Ref AS Ref
	|FROM
	|	ExchangePlan.MessageExchange AS MessageExchange
	|		LEFT JOIN InformationRegister.ExchangeTransportSettings AS ExchangeTransportSettings
	|			ON MessageExchange.Ref = ExchangeTransportSettings.Node
	|WHERE
	|	MessageExchange.Ref <> &ThisNode
	|	AND (NOT MessageExchange.Leading)
	|	AND (NOT MessageExchange.DeletionMark)
	|	AND ExchangeTransportSettings.DefaultExchangeMessageTransportKind = VALUE(Enum.ExchangeMessageTransportKinds.WS)";
	
	Query = New Query;
	Query.SetParameter("ThisNode", ThisNode());
	Query.Text = QueryText;
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	NodeArray = QueryResult.Unload().UnloadColumn("Ref");
	
	// Importing data from all end points
	For Each Recipient In NodeArray Do
		
		Cancel1 = False;
		
		DataExchangeServer.ExecuteDataExchangeForInfoBaseNode(Cancel1, Recipient, True, False, Enums.ExchangeMessageTransportKinds.WS);
		
		Cancel = Cancel Or Cancel1;
		
	EndDo;
	
	// Exporting data to all end points
	For Each Recipient In NodeArray Do
		
		Cancel1 = False;
		
		DataExchangeServer.ExecuteDataExchangeForInfoBaseNode(Cancel1, Recipient, False, True, Enums.ExchangeMessageTransportKinds.WS);
		
		Cancel = Cancel Or Cancel1;
		
	EndDo;
	
EndProcedure

// For internal use only.
//
Procedure SendReceiveMessagesViaStandardCommunicationLines(Cancel)
	
	QueryText =
	"SELECT DISTINCT
	|	MessageExchange.Ref AS Ref
	|FROM
	|	ExchangePlan.MessageExchange AS MessageExchange
	|		LEFT JOIN InformationRegister.ExchangeTransportSettings AS ExchangeTransportSettings
	|			ON MessageExchange.Ref = ExchangeTransportSettings.Node
	|WHERE
	|	MessageExchange.Ref <> &ThisNode
	|	AND (NOT MessageExchange.DeletionMark)
	|	AND ExchangeTransportSettings.DefaultExchangeMessageTransportKind <> VALUE(Enum.ExchangeMessageTransportKinds.WS)";
	
	Query = New Query;
	Query.SetParameter("ThisNode", ThisNode());
	Query.Text = QueryText;
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	NodeArray = QueryResult.Unload().UnloadColumn("Ref");
	
	// Importing data from all end points
	For Each Recipient In NodeArray Do
		
		Cancel1 = False;
		
		DataExchangeServer.ExecuteDataExchangeForInfoBaseNode(Cancel1, Recipient, True, False);
		
		Cancel = Cancel Or Cancel1;
		
	EndDo;
	
	// Exporting data to all end points
	For Each Recipient In NodeArray Do
		
		Cancel1 = False;
		
		DataExchangeServer.ExecuteDataExchangeForInfoBaseNode(Cancel1, Recipient, False, True);
		
		Cancel = Cancel Or Cancel1;
		
	EndDo;
	
EndProcedure

// For internal use only.
//
Procedure ConnectEndPointAtSender(Cancel,
														SenderConnectionSettings,
														RecipientConnectionSettings,
														EndPoint,
														RecipientEndPointDescription,
														SenderEndPointDescription) Export
	
	ErrorMessageString = "";
	
	SetPrivilegedMode(True);
	
	CorrespondentVersions = CorrespondentVersions(SenderConnectionSettings);
	CorrespondentVersion_2_0_1_6 = (CorrespondentVersions.Find("2.0.1.6") <> Undefined);
	
	If CorrespondentVersion_2_0_1_6 Then
		WSProxy = GetWSProxy_2_0_1_6(SenderConnectionSettings, ErrorMessageString);
	Else
		WSProxy = GetWSProxy(SenderConnectionSettings, ErrorMessageString);
	EndIf;
	
	If WSProxy = Undefined Then
		Cancel = True;
		WriteLogEvent(EndPointConnectionEventLogMessageText(), EventLogLevel.Error,,, ErrorMessageString);
		Return;
	EndIf;
	
	Try
		
		If CorrespondentVersion_2_0_1_6 Then
			WSProxy.CheckConnectionAtRecipient(XDTOSerializer.WriteXDTO(RecipientConnectionSettings), ThisNodeCode());
		Else
			WSProxy.CheckConnectionAtRecipient(ValueToStringInternal(RecipientConnectionSettings), ThisNodeCode());
		EndIf;
		
	Except
		Cancel = True;
		WriteLogEvent(EndPointConnectionEventLogMessageText(), EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		Return;
	EndTry;
	
	If CorrespondentVersion_2_0_1_6 Then
		EndPointParameters = XDTOSerializer.ReadXDTO(WSProxy.GetInfoBaseParameters(RecipientEndPointDescription));
	Else
		EndPointParameters = ValueFromStringInternal(WSProxy.GetInfoBaseParameters(RecipientEndPointDescription));
	EndIf;
	
	EndPointNode = ExchangePlans.MessageExchange.FindByCode(EndPointParameters.Code);
	
	If Not EndPointNode.IsEmpty() Then
		Cancel = True;
		ErrorMessageString = NStr("en = 'The end point is already connected to the infobase. The point description is %1.'");
		ErrorMessageString = StringFunctionsClientServer.SubstituteParametersInString(ErrorMessageString, CommonUse.GetAttributeValue(EndPointNode, "Description"));
		WriteLogEvent(EndPointConnectionEventLogMessageText(), EventLogLevel.Error,,, ErrorMessageString);
		Return;
	EndIf;
	
	BeginTransaction();
	Try
		
		// Setting this node description, if necessary
		If IsBlankString(ThisNodeDescription()) Then
			
			ThisNodeObject = ThisNode().GetObject();
			ThisNodeObject.Description = ?(IsBlankString(SenderEndPointDescription), ThisNodeDefaultDescription(), SenderEndPointDescription);
			ThisNodeObject.Write();
			
		EndIf;
		
		// Creating the exchange plan node that corresponds to the connected end point
		EndPointNodeObject = ExchangePlans.MessageExchange.CreateNode();
		EndPointNodeObject.Code = EndPointParameters.Code;
		EndPointNodeObject.Description = EndPointParameters.Description;
		EndPointNodeObject.Write();
		
		// Updating connection settings
		RecordStructure = New Structure;
		RecordStructure.Insert("Node", EndPointNodeObject.Ref);
		RecordStructure.Insert("DefaultExchangeMessageTransportKind", Enums.ExchangeMessageTransportKinds.WS);
		
		RecordStructure.Insert("DataExportTransactionItemCount", 0);
		RecordStructure.Insert("DataImportTransactionItemCount", 0);
		
		RecordStructure.Insert("WSURL", SenderConnectionSettings.WSURL);
		RecordStructure.Insert("WSUserName", SenderConnectionSettings.WSUserName);
		RecordStructure.Insert("WSPassword", SenderConnectionSettings.WSPassword);
		
		// Adding the record to the information register
		InformationRegisters.ExchangeTransportSettings.AddRecord(RecordStructure);
		
		ThisPointParameters = CommonUse.GetAttributeValues(ThisNode(), "Code, Description");
		
		// Connecting the recipient end point
		If CorrespondentVersion_2_0_1_6 Then
			WSProxy.ConnectEndPoint(ThisPointParameters.Code, ThisPointParameters.Description, XDTOSerializer.WriteXDTO(RecipientConnectionSettings));
		Else
			WSProxy.ConnectEndPoint(ThisPointParameters.Code, ThisPointParameters.Description, ValueToStringInternal(RecipientConnectionSettings));
		EndIf;
		
		If GetFunctionalOption("UseDataExchange") = False Then
			Constants.UseDataExchange.Set(True);
		EndIf;
		
		// Setting the scheduled job usage attribute
		ScheduledJob = ScheduledJobs.FindPredefined(Metadata.ScheduledJobs.SendReceiveSystemMessages);
		If Not ScheduledJob.Use Then
			ScheduledJobsServer.SetScheduledJobUse(String(ScheduledJob.UUID), True);
		EndIf;
		
		EndPoint = EndPointNodeObject.Ref;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Cancel = True;
		EndPoint = Undefined;
		WriteLogEvent(EndPointConnectionEventLogMessageText(), EventLogLevel.Error,,,
				DetailErrorDescription(ErrorInfo()));
		Return;
	EndTry;
	
EndProcedure

// For internal use only.
//
Function MessageHandlers()
	
	Result = NewMessageHandlerTable();
	
	MessageExchangeOverridable.GetMessageChannelHandlers(Result);
	
	Return Result;
EndFunction


// For internal use only.
//
Function NewMessageHandlerTable()
	
	Handlers = New ValueTable;
	Handlers.Columns.Add("Channel");
	Handlers.Columns.Add("Handler");
	
	Return Handlers;
EndFunction
