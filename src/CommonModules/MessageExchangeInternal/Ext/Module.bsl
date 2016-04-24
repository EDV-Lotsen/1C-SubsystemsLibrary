////////////////////////////////////////////////////////////////////////////////
// MessageExchangeInternal.
//
////////////////////////////////////////////////////////////////////////////////

#Region InternalInterface

////////////////////////////////////////////////////////////////////////////////
// Data exchange subsystem event handlers

// OnDataExport event handler for Data exchange subsystem. 
// For handler description, see CommonModule.DataExchangeOverridable.OnDataExport().
//
Procedure OnDataExport(StandardProcessing,
								Recipient,
								MessageFileName,
								MessageData,
								TransactionItemCount,
								EventLogEventName,
								SentObjectCount
	) Export
	
	If TypeOf(Recipient) <> Type("ExchangePlanRef.MessageExchange") Then
		Return;
	EndIf;
	
	MessageCatalogs = MessageExchangeCached.GetMessageCatalogs();
	
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
	
	// Counting the number of written objects
	SentObjectCount = 0;
	
	// Getting a changed data selection
	ChangeSelection = DataExchangeServer.SelectChanges(WriteMessage.Recipient, WriteMessage.MessageNo);
	
	Try
		
		While ChangeSelection.Next() Do
			
			TableRow = DataSelectionTable.Add();
			TableRow.Data = ChangeSelection.Get();
			
			TableRow.Order = 0;
			For Each MessageCatalog In MessageCatalogs Do
				If TypeOf(TableRow.Data) = TypeOf(MessageCatalog.EmptyRef()) Then
					TableRow.Order = TableRow.Data.Code;
					Break;
				EndIf;
			EndDo;
			
		EndDo;
		
		DataSelectionTable.Sort("Order Asc");
		
		For Each TableRow In DataSelectionTable Do
			
			SendingMessageNow = False;
			
			For Each MessageCatalog In MessageCatalogs Do
				
				If TypeOf(TableRow.Data) = TypeOf(MessageCatalog.CreateItem()) Then
					SendingMessageNow = True;
					Break;
				EndIf;
				
			EndDo;
			
			If SendingMessageNow Then
				
				TableRow.Data.Code = 0;
				
				// {Event handler: OnSendMessage} Beginning
				Body = TableRow.Data.Body.Get();
				
				OnSendMessageSL(TableRow.Data.Description, Body, TableRow.Data);
				
				OnSendMessage(TableRow.Data.Description, Body);
				
				TableRow.Data.Body = New ValueStorage(Body);
				// {Event handler: OnSendMessage} End
				
			EndIf;
			
			If TypeOf(TableRow.Data) = Type("ObjectDeletion") Then
				
				If TypeOf(TableRow.Data.Ref) <> Type("CatalogRef.SystemMessages") Then
					
					TableRow.Data = New ObjectDeletion(Catalogs.SystemMessages.GetRef(
						TableRow.Data.Ref.UUID()));
					
				EndIf;
				
			EndIf;
			
			// Writing data to the message
			WriteXML(XMLWriter, TableRow.Data);
			
			SentObjectCount = SentObjectCount + 1;
			
		EndDo;
		
		// Finalizing the message
		WriteMessage.EndWrite();
		
		MessageData = XMLWriter.Close();
		
	Except
		
		WriteMessage.CancelWrite();
		XMLWriter.Close();
		Raise DetailErrorDescription(ErrorInfo());
		
	EndTry;
	
EndProcedure

// OnDataImport event handler for Data exchange subsystem. 
// For handler description, see CommonModule.DataExchangeOverridable.OnDataImport().
//
Procedure OnDataImport(StandardProcessing,
								Sender,
								MessageFileName,
								MessageData,
								TransactionItemCount,
								EventLogEventName,
								ReceivedObjectCount
	) Export
	
	If TypeOf(Sender) <> Type("ExchangePlanRef.MessageExchange") Then
		Return;
	EndIf;
	
	SaasOperationsModule = Undefined;
	If CommonUseCached.IsSeparatedConfiguration() Then
		SaasOperationsModule = CommonUse.CommonModule("SaaSOperations");
	EndIf;
	
	MessageCatalogs = MessageExchangeCached.GetMessageCatalogs();
	
	StandardProcessing = False;
	
	XMLReader = New XMLReader;
	
	If Not IsBlankString(MessageData) Then
		XMLReader.SetString(MessageData);
	Else
		XMLReader.OpenFile(MessageFileName);
	EndIf;
	
	MessageReader = ExchangePlans.CreateMessageReader();
	MessageReader.BeginRead(XMLReader, AllowedMessageNo.Greater);
	
	BackupCopyParameters = DataExchangeServer.BackupCopyParameters(MessageReader.Sender, MessageReader.ReceivedNo);
	
	DeleteChangeRecords = Not BackupCopyParameters.BackupRestored;
	
	If DeleteChangeRecords Then
		
		// Deleting change records for the message sender node
		ExchangePlans.DeleteChangeRecords(MessageReader.Sender, MessageReader.ReceivedNo);
		
	EndIf;
	
	// Counting the number of read objects
	ReceivedObjectCount = 0;
	
	Try
		
		ExchangeMessageCanBePartiallyReceived = CorrespondentSupportsPartiallyReceivingExchangeMessages(Sender);
		ExchangeMessagePartiallyReceived = False;
		
		// Reading data from the message
		While CanReadXML(XMLReader) Do
			
			// Reading the next value
			Data = ReadXML(XMLReader);
			
			ReceivedObjectCount = ReceivedObjectCount + 1;
			
			ReceivingMessageNow = False;
			For Each MessageCatalog In MessageCatalogs Do
				If TypeOf(Data) = TypeOf(MessageCatalog.CreateItem()) Then
					ReceivingMessageNow = True;
					Break;
				EndIf;
			EndDo;
			
			If ReceivingMessageNow Then
				
				If Not Data.IsNew() Then
					Continue; // Importing new messages only
				EndIf;
				
				// {Event handler: OnReceiveMessage} Beginning
				Body = Data.Body.Get();
				
				OnReceiveMessageSL(Data.Description, Body, Data);
				
				OnReceiveMessage(Data.Description, Body);
				
				Data.Body = New ValueStorage(Body);
				// {Event handler: OnReceiveMessage} End
				
				If Not Data.IsNew() Then
					Continue; // Importing new messages only
				EndIf;
				
				Data.SetNewCode();
				Data.Sender = MessageReader.Sender;
				Data.Recipient = ThisNode();
				Data.AdditionalProperties.Insert("IgnoreChangeProhibitionCheck");
				
			ElsIf TypeOf(Data) = Type("InformationRegisterRecordSet.RecipientSubscriptions") Then
				
				Data.Filter["Recipient"].Value = MessageReader.Sender;
				
				For Each RecordSetRow In Data Do
					
					RecordSetRow.Recipient = MessageReader.Sender;
					
				EndDo;
				
			ElsIf TypeOf(Data) = Type("ObjectDeletion") Then
				
				If TypeOf(Data.Ref) = Type("CatalogRef.SystemMessages") Then
					
					For Each MessageCatalog In MessageCatalogs Do
						
						RefSubstitution = MessageCatalog.GetRef(Data.Ref.UUID());
						If CommonUse.RefExists(RefSubstitution) Then
							
							Data = New ObjectDeletion(RefSubstitution);
							Break;
							
						EndIf;
						
					EndDo;
					
				EndIf;
				
			EndIf;
			
			DataArea = -1;
			If TypeOf(Data) = Type("ObjectDeletion") Then
				
				Ref = Data.Ref;
				If Not CommonUse.RefExists(Ref) Then
					Continue;
				EndIf;
				If CommonUseCached.IsSeparatedConfiguration() And CommonUse.IsSeparatedMetadataObject(Ref.Metadata(), CommonUseCached.AuxiliaryDataSeparator()) Then
					DataArea = CommonUse.ObjectAttributeValue(Data.Ref, CommonUseCached.AuxiliaryDataSeparator());
				EndIf;
				
			Else
				
				If CommonUseCached.IsSeparatedConfiguration() And CommonUse.IsSeparatedMetadataObject(Data.Metadata(), CommonUseCached.AuxiliaryDataSeparator()) Then
					DataArea = Data[CommonUseCached.AuxiliaryDataSeparator()];
				EndIf;
				
			EndIf;
			
			MustRestoreSeparation = False;
			If DataArea <> -1 Then
				
				If SaasOperationsModule.DataAreaLocked(DataArea) Then
					// Messages for a locked area cannot be accepted
					If ExchangeMessageCanBePartiallyReceived Then
						ExchangeMessagePartiallyReceived = True;
						Continue;
					Else
						Raise StringFunctionsClientServer.SubstituteParametersInString(
							NStr("en = 'Cannot execute message exchange: data area %1 is locked.'"),
							DataArea);
					EndIf;
				EndIf;
				
				MustRestoreSeparation = True;
				CommonUse.SetSessionSeparation(True, DataArea);
				
			EndIf;
			
			// In case of conflicting changes, the current infobase takes precedence (with the exception
			// of incoming ObjectDeletion data from messages sent to the correspondent infobase)
			If TypeOf(Data) <> Type("ObjectDeletion") And ExchangePlans.IsChangeRecorded(MessageReader.Sender, Data) Then
				If MustRestoreSeparation Then
					CommonUse.SetSessionSeparation(False);
				EndIf;
				Continue;
			EndIf;
			
			Data.DataExchange.Sender = MessageReader.Sender;
			Data.DataExchange.Load = True;
			Data.Write();
			
			If MustRestoreSeparation Then
				CommonUse.SetSessionSeparation(False);
			EndIf;
			
		EndDo;
		
		If ExchangeMessagePartiallyReceived Then
			// If the data exchange message contains any rejected messages, the sender 
			// must keep attempting to resend them whenever further exchange messages are generated
			MessageReader.CancelRead();
		Else
			MessageReader.EndRead();
		EndIf;
		
		DataExchangeServer.OnBackupRestore(BackupCopyParameters);
		
		XMLReader.Close();
		
	Except
		MessageReader.CancelRead();
		XMLReader.Close();
		Raise;
	EndTry;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Infobase update

// Adds update handlers that are required by the subsystem.
//
// Parameters:
//   Handlers - ValueTable - see the description of NewUpdateHandlerTable function in the InfobaseUpdate common module.
// 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version = "*";
	Handler.SharedData = True;
	Handler.ExclusiveMode = False;
	Handler.Procedure = "MessageExchangeInternal.SetThisEndpointCode";
	
EndProcedure

// Sets code for this setpoint if it is not yet set.
// 
Procedure SetThisEndpointCode() Export
	
	If IsBlankString(ThisNodeCode()) Then
		
		ThisEndpoint = ThisNode().GetObject();
		ThisEndpoint.Code = String(New UUID());
		ThisEndpoint.Write();
		
	EndIf;
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Export internal procedures and functions

// Handler of a scheduled job used to send and receive system messages.
//
Procedure SendReceiveMessagesByScheduledJob() Export
	
	CommonUse.ScheduledJobOnStart();
	
	SendAndReceiveMessages(False);
	
EndProcedure

// Sends and receives system messages.
//
// Parameters:
//   Cancel - Boolean - cancellation flag. Used on errors during operations.
//
Procedure SendAndReceiveMessages(Cancel) Export
	
	SetPrivilegedMode(True);
	
	SendReceiveMessagesViaWebServiceExecute(Cancel);
	
	SendReceiveMessagesViaStandardCommunicationLines(Cancel);
	
	ProcessSystemMessageQueue();
	
EndProcedure

// For internal use only
Procedure ProcessSystemMessageQueue(Filter = Undefined) Export
	
	SetPrivilegedMode(True);
	
	If CommonUseCached.DataSeparationEnabled() And CommonUseCached.CanUseSeparatedData() Then
		
		WriteLogEvent(ThisSubsystemEventLogMessageText(),
				EventLogLevel.Information,,,
				NStr("en = 'Message message queue processing is started
                      |from a session with separator values set. Processing will be performed
                      |only for messages saved in separated catalog items with
                      |separator values matching the session separator values.'")
		);
		
		ProcessMessagesInSharedData = False;
		
	Else
		
		ProcessMessagesInSharedData = True;
		
	EndIf;
	
	SaasOperationsModule = Undefined;
	If CommonUseCached.IsSeparatedConfiguration() Then
		SaasOperationsModule = CommonUse.CommonModule("SaaSOperations");
	EndIf;
	
	MessageHandlers = MessageHandlers();
	
	QueryText = "";
	MessageCatalogs = MessageExchangeCached.GetMessageCatalogs();
	For Each MessageCatalog In MessageCatalogs Do
		
		FullCatalogName = MessageCatalog.EmptyRef().Metadata().FullName();
		IsSharedCatalog = Not CommonUseCached.IsSeparatedConfiguration() Or
			Not CommonUse.IsSeparatedMetadataObject(FullCatalogName, CommonUseCached.AuxiliaryDataSeparator());
		
		If IsSharedCatalog And Not ProcessMessagesInSharedData Then
			Continue;
		EndIf;
		
		If Not IsBlankString(QueryText) Then
			
			QueryText = QueryText + "
			|
			|UNION ALL
			|"
			
		EndIf;
		
		Subquery =  StringFunctionsClientServer.SubstituteParametersInString(
			"SELECT
			|	MessageTable.DataAreaAuxiliaryData AS DataArea,
			|	MessageTable.Ref AS Ref,
			|	MessageTable.Code AS Code,
			|	MessageTable.Sender.Locked AS EndpointLocked
			|FROM
			|	%1 AS MessageTable
			|WHERE
			|	MessageTable.Recipient = &Recipient
			|	AND (Not MessageTable.Locked)
			|	[Filter]"
			, FullCatalogName);
		
		If IsSharedCatalog Then
			Subquery = StrReplace(Subquery, "MessageTable.DataAreaAuxiliaryData AS DataArea", "-1 AS DataArea");
		EndIf;
		
		QueryText = QueryText + Subquery;
		
	EndDo;
	
	FilterRow = ?(Filter = Undefined, "", "AND MessageTable.Ref IN(&Filter)");
	
	QueryText = StrReplace(QueryText, "[Filter]", FilterRow);
	
	QueryText = "SELECT TOP 100
	|	NestedQuery.DataArea,
	|	NestedQuery.Ref,
	|	NestedQuery.Code,
	|	NestedQuery.EndpointLocked
	|FROM
	|	(" +  QueryText + ") AS NestedQuery
	|
	|ORDER BY
	|	Code";
	
	Query = New Query;
	Query.SetParameter("Recipient", ThisNode());
	Query.SetParameter("Filter", Filter);
	Query.Text = QueryText;
	
	QueryResult = CommonUse.ExecuteQueryOutsideTransaction(Query);
	
	Selection = QueryResult.Select();
	
	While Selection.Next() Do
		
		Try
			LockDataForEdit(Selection.Ref);
		Except
			Continue; // moving on
		EndTry;
		
		// Checking for data area lock
		If SaasOperationsModule <> Undefined
				And Selection.DataArea <> -1
				And SaasOperationsModule.DataAreaLocked(Selection.DataArea) Then
			
			// The area is locked, proceeding to the next record
			Continue;
		EndIf;
		
		Try
			
			BeginTransaction();
			Try
				MessageObject = Selection.Ref.GetObject();
				CommitTransaction();
			Except
				RollbackTransaction();
				Raise;
			EndTry;
		
			MessageTitle = New Structure("MessageChannel, Sender", MessageObject.Description, MessageObject.Sender);
			
			FoundRows = MessageHandlers.FindRows(New Structure("Channel", MessageTitle.MessageChannel));
			
			MessageProcessed = True;
			
			// Processing message
			Try
				
				If Selection.EndpointLocked Then
					MessageObject.Locked = True;
					Raise NStr("en = 'Attempting to process a message received from a locked endpoint.'");
				EndIf;
				
				If FoundRows.Count() = 0 Then
					MessageObject.Locked = True;
					Raise NStr("en = 'No handlers are assigned for this message.'");
				EndIf;
				
				For Each TableRow In FoundRows Do
					
					TableRow.Handler.ProcessMessage(MessageTitle.MessageChannel, ConvertMessageBodyStructure(MessageObject.Body.Get()), MessageTitle.Sender);
					
					If TransactionActive() Then
						While TransactionActive() Do
							RollbackTransaction();
						EndDo;
						MessageObject.Locked = True;
						Raise NStr("en = 'No transactions are registered in the message handler.'");
					EndIf;
					
				EndDo;
			Except
				
				While TransactionActive() Do
					RollbackTransaction();
				EndDo;
				
				MessageProcessed = False;
				
				DetailErrorDescription = DetailErrorDescription(ErrorInfo());
				WriteLogEvent(ThisSubsystemEventLogMessageText(),
						EventLogLevel.Error,,,
						StringFunctionsClientServer.SubstituteParametersInString(
							NStr("en = 'Error while processing message %1: %2.'"),
							MessageTitle.MessageChannel, DetailErrorDescription));
			EndTry;
			
			If MessageProcessed Then
				
				// Deleting message
				If ValueIsFilled(MessageObject.Sender)
					And MessageObject.Sender <> ThisNode() Then
					
					MessageObject.DataExchange.Recipients.Add(MessageObject.Sender);
					MessageObject.DataExchange.Recipients.AutoFill = False;
					
				EndIf;
				
				MessageObject.DataExchange.Load = True; // Presence of catalog references should not impede or retard deletion of catalog items
				CommonUse.DeleteAuxiliaryData(MessageObject);
				
			Else
				
				MessageObject.ProcessMessageRetryCount = MessageObject.ProcessMessageRetryCount + 1;
				MessageObject.DetailErrorDescription = DetailErrorDescription;
				
				If MessageObject.ProcessMessageRetryCount >= 3 Then
					MessageObject.Locked = True;
				EndIf;
				
				CommonUse.WriteAuxiliaryData(MessageObject);
				
			EndIf;
			
			If ProcessMessagesInSharedData And CommonUseCached.DataSeparationEnabled() And CommonUseCached.CanUseSeparatedData() Then
				
				ErrorMessageText = StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'Session separation is not disabled after processing a message in channel %1.'"),
					MessageTitle.MessageChannel);
				
				WriteLogEvent(
					ThisSubsystemEventLogMessageText(),
					EventLogLevel.Error,
					,
					,
					ErrorMessageText);
				
				CommonUse.SetSessionSeparation(False);
				
			EndIf;
			
		Except
			WriteLogEvent(ThisSubsystemEventLogMessageText(),
					EventLogLevel.Error,,,
					DetailErrorDescription(ErrorInfo()));
		EndTry;
		
		UnlockDataForEdit(Selection.Ref);
		
	EndDo;
	
EndProcedure

// For internal use only
Procedure SetLeadingEndpointAtSender(Cancel, SenderConnectionSettings, Endpoint) Export
	
	SetPrivilegedMode(True);
	
	ErrorMessageString = "";
	
	WSProxy = GetWSProxy(SenderConnectionSettings, ErrorMessageString);
	
	If WSProxy = Undefined Then
		Cancel = True;
		WriteLogEvent(LeadingEndpointSettingEventLogMessageText(), EventLogLevel.Error,,, ErrorMessageString);
		Return;
	EndIf;
	
	BeginTransaction();
	Try
		
		EndpointObject = Endpoint.GetObject();
		EndpointObject.Leading = False;
		EndpointObject.Write();
		
		//updating connection settings
		RecordStructure = New Structure;
		RecordStructure.Insert("Node", Endpoint);
		RecordStructure.Insert("DefaultExchangeMessageTransportKind", Enums.ExchangeMessageTransportKinds.WS);
		
		RecordStructure.Insert("WSURL",      SenderConnectionSettings.WSURL);
		RecordStructure.Insert("WSUserName", SenderConnectionSettings.WSUserName);
		RecordStructure.Insert("WSPassword", SenderConnectionSettings.WSPassword);
		RecordStructure.Insert("WSRememberPassword", True);
		
		// Adding information register record
		InformationRegisters.ExchangeTransportSettings.AddRecord(RecordStructure);
		
		// Setting the leading endpoint at recipient side
		WSProxy.SetLeadingEndpoint(EndpointObject.Code, ThisNodeCode());
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Cancel = True;
		WriteLogEvent(LeadingEndpointSettingEventLogMessageText(), EventLogLevel.Error,,,
				DetailErrorDescription(ErrorInfo()));
		Return;
	EndTry;
	
EndProcedure

// For internal use only
Procedure SetLeadingEndpointAtRecipient(ThisEndpointCode, LeadingEndpointCode) Export
	
	SetPrivilegedMode(True);
	
	If ExchangePlans.MessageExchange.FindByCode(ThisEndpointCode) <> ThisNode() Then
		ErrorMessageString = NStr("en = 'The endpoint connection parameters are invalid. Connection parameters point to a different endpoint.'");
		ErrorMessageStringForEventLog = NStr("en = 'The endpoint connection parameters are invalid.
			|Connection parameters point to a different endpoint.'", CommonUseClientServer.DefaultLanguageCode());
		WriteLogEvent(LeadingEndpointSettingEventLogMessageText(),
				EventLogLevel.Error,,, ErrorMessageStringForEventLog);
		Raise ErrorMessageString;
	EndIf;
	
	BeginTransaction();
	Try
		
		EndpointNode = ExchangePlans.MessageExchange.FindByCode(LeadingEndpointCode);
		
		If EndpointNode.IsEmpty() Then
			
			Raise NStr("en = 'The endpoint is not found in the correspondent infobase.'");
			
		EndIf;
		EndpointNodeObject = EndpointNode.GetObject();
		EndpointNodeObject.Leading = True;
		EndpointNodeObject.Write();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteLogEvent(LeadingEndpointSettingEventLogMessageText(), EventLogLevel.Error,,,
				DetailErrorDescription(ErrorInfo()));
		Raise DetailErrorDescription(ErrorInfo());
	EndTry;
	
EndProcedure

// For internal use only
Procedure ConnectEndpointAtRecipient(Cancel, Code, Description, RecipientConnectionSettings) Export
	
	DataExchangeServer.CheckUseDataExchange();
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		
		// Creating/updating an exchange plan node matching the endpoint to be connected
		EndpointNode = ExchangePlans.MessageExchange.FindByCode(Code);
		If EndpointNode.IsEmpty() Then
			EndpointNodeObject = ExchangePlans.MessageExchange.CreateNode();
			EndpointNodeObject.Code = Code;
		Else
			EndpointNodeObject = EndpointNode.GetObject();
			EndpointNodeObject.ReceivedNo = 0;
		EndIf;
		EndpointNodeObject.Description = Description;
		EndpointNodeObject.Leading = True;
		EndpointNodeObject.Write();
		
		//updating connection settings
		RecordStructure = New Structure;
		RecordStructure.Insert("Node", EndpointNodeObject.Ref);
		RecordStructure.Insert("DefaultExchangeMessageTransportKind", Enums.ExchangeMessageTransportKinds.WS);
		
		RecordStructure.Insert("WSURL",   RecipientConnectionSettings.WSURL);
		RecordStructure.Insert("WSUserName", RecipientConnectionSettings.WSUserName);
		RecordStructure.Insert("WSPassword",          RecipientConnectionSettings.WSPassword);
		RecordStructure.Insert("WSRememberPassword", True);
		
		// Adding information register record
		InformationRegisters.ExchangeTransportSettings.AddRecord(RecordStructure);
		
		// Setting the scheduled job usage flag
		ScheduledJobsServer.SetUseScheduledJob(
			Metadata.ScheduledJobs.SendReceiveSystemMessages, True);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Cancel = True;
		WriteLogEvent(EndpointConnectionEventLogMessageText(), EventLogLevel.Error,,,
				DetailErrorDescription(ErrorInfo()));
		Raise DetailErrorDescription(ErrorInfo());
	EndTry;
	
EndProcedure

// For internal use only
Procedure UpdateEndpointConnectionSettings(Cancel, Endpoint, SenderConnectionSettings, RecipientConnectionSettings) Export
	
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
		WriteLogEvent(EndpointConnectionEventLogMessageText(), EventLogLevel.Error,,, ErrorMessageString);
		Return;
	EndIf;
	
	Try
		If CorrespondentVersion_2_0_1_6 Then
			WSProxy.TestConnectionRecipient(XDTOSerializer.WriteXDTO(RecipientConnectionSettings), ThisNodeCode());
		Else
			WSProxy.TestConnectionRecipient(ValueToStringInternal(RecipientConnectionSettings), ThisNodeCode());
		EndIf;
	Except
		Cancel = True;
		WriteLogEvent(EndpointConnectionEventLogMessageText(), EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		Return;
	EndTry;
	
	BeginTransaction();
	Try
		
		// Updating connection settings
		RecordStructure = New Structure;
		RecordStructure.Insert("Node", Endpoint);
		RecordStructure.Insert("DefaultExchangeMessageTransportKind", Enums.ExchangeMessageTransportKinds.WS);
		
		RecordStructure.Insert("WSURL",   SenderConnectionSettings.WSURL);
		RecordStructure.Insert("WSUserName", SenderConnectionSettings.WSUserName);
		RecordStructure.Insert("WSPassword",          SenderConnectionSettings.WSPassword);
		RecordStructure.Insert("WSRememberPassword", True);
		
		// Adding information register record
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
		WriteLogEvent(EndpointConnectionEventLogMessageText(), EventLogLevel.Error,,,
				DetailErrorDescription(ErrorInfo()));
		Return;
	EndTry;
	
EndProcedure

// For internal use only
Procedure AddMessageChannelHandler(Channel, ChannelHandler, Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Channel = Channel;
	Handler.Handler = ChannelHandler;
	
EndProcedure

// For internal use only
Function ThisNodeCode() Export
	
	Return CommonUse.ObjectAttributeValue(ThisNode(), "Code");
	
EndFunction

// For internal use only
Function ThisNodeDescription() Export
	
	Return CommonUse.ObjectAttributeValue(ThisNode(), "Description");
	
EndFunction

// For internal use only
Function ThisNode() Export
	
	Return ExchangePlans.MessageExchange.ThisNode();
	
EndFunction

// For internal use only
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

// For internal use only
Procedure SerializeDataToStream(DataSelection, Stream) Export
	
	XMLWriter = New XMLWriter;
	XMLWriter.SetString();
	XMLWriter.WriteXMLDeclaration();
	XMLWriter.WriteStartElement("Root");
	
	For Each Ref In DataSelection Do
		
		Data = Ref.GetObject();
		Data.Code = 0;
		
		// {Event handler: OnSendMessage} Beginning
		Body = Data.Body.Get();
		
		Body = MessageExchangeInternal.ConvertInstantMessageData(Body);
				
		OnSendMessageSL(Data.Description, Body, Data);
		
		OnSendMessage(Data.Description, Body);
		
		Data.Body = New ValueStorage(Body);
		// {Event handler: OnSendMessage} End
		
		WriteXML(XMLWriter, Data);
		
	EndDo;
	XMLWriter.WriteEndElement();
	
	Stream = XMLWriter.Close();
	
EndProcedure

// For internal use only
Procedure SerializeDataFromStream(Sender, Stream, ImportedObjects, DataReadPartially) Export
	
	SaasOperationsModule = Undefined;
	If CommonUseCached.IsSeparatedConfiguration() Then
		SaasOperationsModule = CommonUse.CommonModule("SaaSOperations");
	EndIf;
	
	DataCanBeReadPartially = CorrespondentSupportsPartiallyReceivingExchangeMessages(Sender);
	
	ImportedObjects = New Array;
	
	BeginTransaction();
	Try
		
		XMLReader = New XMLReader;
		XMLReader.SetString(Stream);
		XMLReader.Read(); // Root node
		XMLReader.Read(); // object node
		
		While CanReadXML(XMLReader) Do
			
			Data = ReadXML(XMLReader);
			
			If TypeOf(Data) = Type("ObjectDeletion") Then
				
				Raise NStr("en = 'Delivery via quick message mechanism is not supported for the ObjectDeletion object.'");
				
			Else
				
				If Not Data.IsNew() Then
					Continue; // Importing new messages only
				EndIf;
				
				// {Event handler: OnReceiveMessage} Beginning
				Body = Data.Body.Get();
				
				Body = MessageExchangeInternal.ConvertInstantMessageData(Body);
	
				OnReceiveMessageSL(Data.Description, Body, Data);
				
				OnReceiveMessage(Data.Description, Body);
				
				Data.Body = New ValueStorage(Body);
				// {Event handler: OnReceiveMessage} End
				
				If Not Data.IsNew() Then
					Continue; // Importing new messages only
				EndIf;
				
				Data.SetNewCode();
				Data.Sender = Sender;
				Data.Recipient = ThisNode();
				Data.AdditionalProperties.Insert("IgnoreChangeProhibitionCheck");
				
			EndIf;
			
			MustRestoreSeparation = False;
			If CommonUseCached.IsSeparatedConfiguration() And CommonUse.IsSeparatedMetadataObject(Data.Metadata(), CommonUseCached.AuxiliaryDataSeparator()) Then
				
				DataArea = Data[CommonUseCached.AuxiliaryDataSeparator()];
				
				If SaasOperationsModule.DataAreaLocked(DataArea) Then
					// Message for a locked area cannot be accepted.
					If DataCanBeReadPartially Then
						DataReadPartially = True;
						Continue;
					Else
						Raise StringFunctionsClientServer.SubstituteParametersInString(
							NStr("en = 'Cannot execute message exchange: data area %1 is locked.'"),
							DataArea);
					EndIf;
				EndIf;
				
				MustRestoreSeparation = True;
				CommonUse.SetSessionSeparation(True, DataArea);
				
			EndIf;
			
			// In case of conflicting changes, the current infobase takes precedence
			If ExchangePlans.IsChangeRecorded(Sender, Data) Then
				If MustRestoreSeparation Then
					CommonUse.SetSessionSeparation(False);
				EndIf;
				Continue;
			EndIf;
			
			Data.DataExchange.Sender = Sender;
			Data.DataExchange.Load = True;
			Data.Write();
			
			If MustRestoreSeparation Then
				CommonUse.SetSessionSeparation(False);
			EndIf;
			
			ImportedObjects.Add(Data.Ref);
			
		EndDo;
		
		XMLReader.Close();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// For internal use only
Function GetWSProxy(SettingsStructure, ErrorMessageString = "", Timeout = 60) Export
	
	SettingsStructure.Insert("NamespaceWebServiceURL", "http://www.1c.ru/SSL/MessageExchange");
	SettingsStructure.Insert("WSServiceName",                 "MessageExchange");
	SettingsStructure.Insert("WSTimeout", Timeout);
	
	Return DataExchangeServer.GetWSProxyByConnectionParameters(SettingsStructure, ErrorMessageString);
EndFunction

// For internal use only
Function GetWSProxy_2_0_1_6(SettingsStructure, ErrorMessageString = "", Timeout = 60) Export
	
	SettingsStructure.Insert("NamespaceWebServiceURL", "http://www.1c.ru/SSL/MessageExchange_2_0_1_6");
	SettingsStructure.Insert("WSServiceName",                 "MessageExchange_2_0_1_6");
	SettingsStructure.Insert("WSTimeout", Timeout);
	
	Return DataExchangeServer.GetWSProxyByConnectionParameters(SettingsStructure, ErrorMessageString);
EndFunction

// Validates correspondent infobase support for partial
//  delivery of data exchange messages during message exchange (if not supported - partial delivery
//  of exchange messages on the infobase side must not be used).
//
// Parameters:
//  Sender - ExchangePlanRef.MessageExchange,
//
// Return value: Boolean.
//
Function CorrespondentSupportsPartiallyReceivingExchangeMessages(Val Correspondent)
	
	CorrespondentVersions = CorrespondentVersions(Correspondent);
	Return (CorrespondentVersions.Find("2.1.1.8") <> Undefined);
	
EndFunction

// Returns an array containing numbers of versions supported by the MessageExchange subsystem correspondent interface.
// 
// Parameters:
//   Correspondent - Structure, ExchangePlanRef - exchange plan note that matches the correspondent infobase.
//
// Returns:
//   Array of version numbers that are supported by correspondent API.
//
Function CorrespondentVersions(Val Correspondent) Export
	
	If TypeOf(Correspondent) = Type("Structure") Then
		SettingsStructure = Correspondent;
	Else
		SettingsStructure = InformationRegisters.ExchangeTransportSettings.TransportSettingsWS(Correspondent);
	EndIf;
	
	ConnectionParameters = New Structure;
	ConnectionParameters.Insert("URL",      SettingsStructure.WSURL);
	ConnectionParameters.Insert("UserName", SettingsStructure.WSUserName);
	ConnectionParameters.Insert("Password", SettingsStructure.WSPassword);
	
	Return CommonUse.GetInterfaceVersions(ConnectionParameters, "MessageExchange");
EndFunction

// For internal use only
Function EndpointConnectionEventLogMessageText() Export
	
	Return NStr("en = 'Message exchange. Connecting the endpoint'", CommonUseClientServer.DefaultLanguageCode());
	
EndFunction

// For internal use only
Function LeadingEndpointSettingEventLogMessageText() Export
	
	Return NStr("en = 'Message exchange. Setting the leading endpoint'", CommonUseClientServer.DefaultLanguageCode());
	
EndFunction

// For internal use only
Function ThisSubsystemEventLogMessageText() Export
	
	Return NStr("en = 'Message exchange'", CommonUseClientServer.DefaultLanguageCode());
	
EndFunction

// For internal use only
Function ThisNodeDefaultDescription() Export
	
	Return ?(CommonUseCached.DataSeparationEnabled(), Metadata.Synonym, DataExchangeCached.ThisInfobaseName());
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Local internal procedures and functions

// For internal use only
Procedure SendReceiveMessagesViaWebServiceExecute(Cancel)
	
	QueryText =
	"SELECT DISTINCT
	|	MessageExchange.Ref AS Ref
	|FROM
	|	ExchangePlan.MessageExchange AS MessageExchange
	|		LEFT JOIN InformationRegister.ExchangeTransportSettings AS ExchangeTransportSettings
	|		ON MessageExchange.Ref = ExchangeTransportSettings.Node
	|WHERE
	|	MessageExchange.Ref <> &ThisNode
	|	AND (Not MessageExchange.Leading)
	|	AND (Not MessageExchange.DeletionMark)
	|	AND (Not MessageExchange.Locked)
	|	AND ExchangeTransportSettings.DefaultExchangeMessageTransportKind = VALUE(Enum.ExchangeMessageTransportKinds.WS)";
	
	Query = New Query;
	Query.SetParameter("ThisNode", ThisNode());
	Query.Text = QueryText;
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	NodeArray = QueryResult.Unload().UnloadColumn("Ref");
	
	// Importing data from all endpoints
	For Each Recipient In NodeArray Do
		
		Cancel1 = False;
		
		DataExchangeServer.ExecuteDataExchangeForInfobaseNode(Cancel1, Recipient, True, False, Enums.ExchangeMessageTransportKinds.WS);
		
		Cancel = Cancel Or Cancel1;
		
	EndDo;
	
	// Exporting data to all endpoints
	For Each Recipient In NodeArray Do
		
		Cancel1 = False;
		
		DataExchangeServer.ExecuteDataExchangeForInfobaseNode(Cancel1, Recipient, False, True, Enums.ExchangeMessageTransportKinds.WS);
		
		Cancel = Cancel Or Cancel1;
		
	EndDo;
	
EndProcedure

// For internal use only
Procedure SendReceiveMessagesViaStandardCommunicationLines(Cancel)
	
	QueryText =
	"SELECT DISTINCT
	|	MessageExchange.Ref AS Ref
	|FROM
	|	ExchangePlan.MessageExchange AS MessageExchange
	|		LEFT JOIN InformationRegister.ExchangeTransportSettings AS ExchangeTransportSettings
	|		ON MessageExchange.Ref = ExchangeTransportSettings.Node
	|WHERE
	|	MessageExchange.Ref <> &ThisNode
	|	AND (Not MessageExchange.DeletionMark)
	|	AND (Not MessageExchange.Locked)
	|	AND ExchangeTransportSettings.DefaultExchangeMessageTransportKind <> VALUE(Enum.ExchangeMessageTransportKinds.WS)";
	
	Query = New Query;
	Query.SetParameter("ThisNode", ThisNode());
	Query.Text = QueryText;
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	NodeArray = QueryResult.Unload().UnloadColumn("Ref");
	
	// Importing data from all endpoints
	For Each Recipient In NodeArray Do
		
		Cancel1 = False;
		
		DataExchangeServer.ExecuteDataExchangeForInfobaseNode(Cancel1, Recipient, True, False);
		
		Cancel = Cancel Or Cancel1;
		
	EndDo;
	
	// Exporting data to all endpoints
	For Each Recipient In NodeArray Do
		
		Cancel1 = False;
		
		DataExchangeServer.ExecuteDataExchangeForInfobaseNode(Cancel1, Recipient, False, True);
		
		Cancel = Cancel Or Cancel1;
		
	EndDo;
	
EndProcedure

// For internal use only
Procedure ConnectEndpointAtSender(Cancel,
														SenderConnectionSettings,
														RecipientConnectionSettings,
														Endpoint,
														RecipientEndpointDescription,
														SenderEndpointDescription
	) Export
	
	DataExchangeServer.CheckUseDataExchange();
	
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
		WriteLogEvent(EndpointConnectionEventLogMessageText(), EventLogLevel.Error,,, ErrorMessageString);
		Return;
	EndIf;
	
	Try
		
		If CorrespondentVersion_2_0_1_6 Then
			WSProxy.TestConnectionRecipient(XDTOSerializer.WriteXDTO(RecipientConnectionSettings), ThisNodeCode());
		Else
			WSProxy.TestConnectionRecipient(ValueToStringInternal(RecipientConnectionSettings), ThisNodeCode());
		EndIf;
		
	Except
		Cancel = True;
		WriteLogEvent(EndpointConnectionEventLogMessageText(), EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		Return;
	EndTry;
	
	If CorrespondentVersion_2_0_1_6 Then
		EndpointParameters = XDTOSerializer.ReadXDTO(WSProxy.GetIBParameters(RecipientEndpointDescription));
	Else
		EndpointParameters = ValueFromStringInternal(WSProxy.GetIBParameters(RecipientEndpointDescription));
	EndIf;
	
	EndpointNode = ExchangePlans.MessageExchange.FindByCode(EndpointParameters.Code);
	
	If Not EndpointNode.IsEmpty() Then
		Cancel = True;
		ErrorMessageString = NStr("en = 'The endpoint is already connected to the infobase. Endpoint name: %1'", CommonUseClientServer.DefaultLanguageCode());
		ErrorMessageString = StringFunctionsClientServer.SubstituteParametersInString(ErrorMessageString, CommonUse.ObjectAttributeValue(EndpointNode, "Description"));
		WriteLogEvent(EndpointConnectionEventLogMessageText(), EventLogLevel.Error,,, ErrorMessageString);
		Return;
	EndIf;
	
	BeginTransaction();
	Try
		
		// Assigning name to the endpoint if necessary
		If IsBlankString(ThisNodeDescription()) Then
			
			ThisNodeObject = ThisNode().GetObject();
			ThisNodeObject.Description = ?(IsBlankString(SenderEndpointDescription), ThisNodeDefaultDescription(), SenderEndpointDescription);
			ThisNodeObject.Write();
			
		EndIf;
		
		// Creating an exchange plan node matching the endpoint to be connected
		EndpointNodeObject = ExchangePlans.MessageExchange.CreateNode();
		EndpointNodeObject.Code = EndpointParameters.Code;
		EndpointNodeObject.Description = EndpointParameters.Description;
		EndpointNodeObject.Write();
		
		// Updating connection settings
		RecordStructure = New Structure;
		RecordStructure.Insert("Node", EndpointNodeObject.Ref);
		RecordStructure.Insert("DefaultExchangeMessageTransportKind", Enums.ExchangeMessageTransportKinds.WS);
		
		RecordStructure.Insert("WSURL",      SenderConnectionSettings.WSURL);
		RecordStructure.Insert("WSUserName", SenderConnectionSettings.WSUserName);
		RecordStructure.Insert("WSPassword", SenderConnectionSettings.WSPassword);
		RecordStructure.Insert("WSRememberPassword", True);
		
		// Adding information register record
		InformationRegisters.ExchangeTransportSettings.AddRecord(RecordStructure);
		
		ThisPointParameters = CommonUse.ObjectAttributeValues(ThisNode(), "Code, Description");
		
		// Establishing the endpoint connection on recipient side
		If CorrespondentVersion_2_0_1_6 Then
			WSProxy.ConnectEndPoint(ThisPointParameters.Code, ThisPointParameters.Description, XDTOSerializer.WriteXDTO(RecipientConnectionSettings));
		Else
			WSProxy.ConnectEndPoint(ThisPointParameters.Code, ThisPointParameters.Description, ValueToStringInternal(RecipientConnectionSettings));
		EndIf;
		
		// Setting the scheduled job usage flag
		ScheduledJobsServer.SetUseScheduledJob(
			Metadata.ScheduledJobs.SendReceiveSystemMessages, True);
		
		Endpoint = EndpointNodeObject.Ref;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Cancel = True;
		Endpoint = Undefined;
		WriteLogEvent(EndpointConnectionEventLogMessageText(), EventLogLevel.Error,,,
				DetailErrorDescription(ErrorInfo()));
		Return;
	EndTry;
	
EndProcedure

// For internal use only
Function MessageHandlers()
	
	Result = NewMessageHandlerTable();
	
	EventHandlers = CommonUse.InternalEventHandlers(
		"StandardSubsystems.SaaSOperations.MessageExchange\MessageChannelHandlersOnDefine");
	
	For Each Handler In EventHandlers Do
		Handler.Module.MessageChannelHandlersOnDefine(Result);
	EndDo;
	
	MessageExchangeOverridable.GetMessageChannelHandlers(Result);
	
	Return Result;
	
EndFunction

// For internal use only
Function NewMessageHandlerTable()
	
	Handlers = New ValueTable;
	Handlers.Columns.Add("Channel");
	Handlers.Columns.Add("Handler");
	
	Return Handlers;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Message sending/receiving event handlers

Procedure OnSendMessageSL(Val MessageChannel, Body, MessageObject)
	
	MessageExchange.OnSendMessage(MessageChannel, Body, MessageObject);
	
EndProcedure

Procedure OnSendMessage(Val MessageChannel, Body)
	
	EventHandlers = CommonUse.InternalEventHandlers(
		"StandardSubsystems.SaaSOperations.MessageExchange\OnSendMessage");
	For Each Handler In EventHandlers Do
		Handler.Module.OnSendMessage(MessageChannel, Body);
	EndDo;
	
	MessageExchangeOverridable.OnSendMessage(MessageChannel, Body);
	
EndProcedure

Procedure OnReceiveMessageSL(Val MessageChannel, Body, MessageObject)
	
	MessageExchange.OnReceiveMessage(MessageChannel, Body, MessageObject);
	
EndProcedure

Procedure OnReceiveMessage(Val MessageChannel, Body)
	
	EventHandlers = CommonUse.InternalEventHandlers(
		"StandardSubsystems.SaaSOperations.MessageExchange\OnReceiveMessage");
	For Each Handler In EventHandlers Do
		Handler.Module.OnReceiveMessage(MessageChannel, Body);
	EndDo;
	
	MessageExchangeOverridable.OnReceiveMessage(MessageChannel, Body);
	
EndProcedure

#EndRegion

// Internal use only
Function ConvertExchangePlanName(ExchangePlanName) Export

	Return StrReplace(ExchangePlanName, "ОбменСообщениями", "MessageExchange");

EndFunction

// Internal use only
Function ConvertBackExchangePlanMessageData(MessageData) Export

	Return StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(   
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(MessageData, 
		"<Body>", "<ТелоСообщения>"), 
		"<Sender>", "<Отправитель>"), 
		"<Recipient>", "<Получатель>"), 
		"<Locked>", "<Заблокировано>"), 
		"<ProcessMessageRetryCount>", "<КоличествоПопытокОбработкиСообщения>"), 
		"<DetailErrorDescription>", "<ПодробноеПредставлениеОшибки>"), 
		"<IsInstantMessage>", "<ЭтоБыстроеСообщение>"), 
		"</Body>", "</ТелоСообщения>"), 
		"</Sender>", "</Отправитель>"), 
		"</Recipient>", "</Получатель>"), 
		"</Locked>", "</Заблокировано>"), 
		"</ProcessMessageRetryCount>", "</КоличествоПопытокОбработкиСообщения>"), 
		"</DetailErrorDescription>", "</ПодробноеПредставлениеОшибки>"), 
		"</IsInstantMessage>", "</ЭтоБыстроеСообщение>"), 
		"<DetailErrorDescription/>", "<ПодробноеПредставлениеОшибки/>"), 
		"CatalogObject.SystemMessages>", "CatalogObject.СообщенияСистемы>"), 
		">MessageExchange<", ">ОбменСообщениями<"), 
		"""CatalogRef.SystemMessages""", """CatalogRef.СообщенияСистемы"""),
		"DataExchange\ManagementApplication\DataChangeFlag", "ОбменДанными\УправляющееПриложение\ПризнакИзмененияДанных"),
		"NodeCode", "КодУзла");

EndFunction

// Internal use only
Function ConvertInstantMessageData(MessageData) Export

	Return StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(   
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(MessageData, 
		"""ОбластьДанных""", "DataArea"), 
		"""Префикс""", """Prefix"""), 
		"""URLСервиса""", """ServiceURL"""), 
		"""ИмяСлужебногоПользователяСервиса""", """AuxiliaryServiceUserName"""), 
		"""ПарольСлужебногоПользователяСервиса""", """AuxiliaryServiceUserPassword"""), 
		"""РежимИспользованияИнформационнойБазы""", """InfobaseUsageMode"""), 
		"""КопироватьОбластиДанныхИзЭталонной""", """CopyDataAreasFromPrototype"""), 
		"""НезависимоеИспользованиеДополнительныхОтчетовИОбработокВМоделиСервиса""", """IndependentUseOfAdditionalReportsAndDataProcessorsInSaaSMode"""), 
		"""ИспользованиеКаталогаДополнительныхОтчетовИОбработокВМоделиСервиса""", """UseAdditionalReportsAndDataProcessorsFolderInSaaSMode"""), 
		"""РазрешитьВыполнениеДополнительныхОтчетовИОбработокРегламентнымиЗаданиямиВМоделиСервиса""", """AllowUseAdditionalReportsAndDataProcessorsByScheduledJobsInSaaSMode"""), 
		"""МинимальныйИнтервалРегламентныхЗаданийДополнительныхОтчетовИОбработокВМоделиСервиса""", """MinimumAdditionalReportsAndDataProcessorsScheduledJobIntervalInSaaSMode"""), 
		"""АдресУправленияКонференцией""", """ForumManagementURL"""), 
		"""ИмяПользователяКонференцииИнформационногоЦентра""", """InformationCenterForumUserName"""), 
		"""ПарольПользователяКонференцииИнформационногоЦентра""", """InformationCenterForumPassword"""), 
		"EnumRef.РежимыИспользованияИнформационнойБазы""", "EnumRef.InfobaseUsageModes"""), 
		">ru<", ">en<"), 
		">Рабочий<", ">Production<"), 
		">Демонстрационный<", ">Demo<"),
		">НомерИнформационнойБазы<", ">InfobaseNumber<"),
		">КодУзлаИнформационнойБазы<", ">InfobaseNodeCode<"),
		">КодЭтогоУзла<",">ThisNodeCode<"),
		">ВыполняемоеДействие<", ">CurrentAction<"),
		">ПорядковыйНомерВыполнения<", ">ExecutionOrderNumber<"),
		">ЗначениеРазделителяПервойИнформационнойБазы<", ">FirstInfobaseSeparatorValue<"),
		">ЗначениеРазделителяВторойИнформационнойБазы<", ">SecondInfobaseSeparatorValue<"),
		">ДатаАктуальностиБлокировки<", ">DataLockUpdateDate<"),
		">Приложение1Код<",">Application1Code<"),
		">Приложение2Код<", ">Application2Code<"),
		">ИмяПланаОбмена<", ">ExchangePlanName<"),
		">Режим<",">Mode<"),
		">ВыгрузкаДанных<", ">DataExport<"),
		">ЗагрузкаДанных<", ">DataImport<"),
		">Ручной<", ">Manual<"),
		">Автоматический<",">Automatic<");

EndFunction

// Internal use only
Function ConvertExchangePlanMessageData(MessageData) Export

	Return StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		MessageData, 
		"ОбменДанными\ПрикладноеПриложение\УстановитьПрефиксОбластиДанных", "DataExchange\Application\SetDataAreaPrefix"), 
		"ОбменДанными\ПрикладноеПриложение\УдалениеОбмена", "DataExchange\Application\ExchangeDeletion"), 
		"ОбменДанными\ПрикладноеПриложение\СозданиеОбмена", "DataExchange\Application\ExchangeCreation"), 
		"ОбменСообщениями", "MessageExchange"), 
		"СообщенияСистемы", "SystemMessages"), 
		"ТелоСообщения", "Body"), 
		"Отправитель", "Sender"), 
		"Получатель", "Recipient"), 
		"Заблокировано", "Locked"), 
		"КоличествоПопытокОбработкиСообщения", "ProcessMessageRetryCount"), 
		"ПодробноеПредставлениеОшибки", "DetailErrorDescription"), 
		"ЭтоБыстроеСообщение", "IsInstantMessage");

EndFunction
	
// Internal use only
Function ConvertRecipientConnectionSettings(Val SettingsStructure) Export

	If SettingsStructure.Property("WSИмяПользователя") Then
		SettingsStructure.Insert("WSUserName", SettingsStructure.WSИмяПользователя);
	EndIf;
	If SettingsStructure.Property("WSПароль") Then
		SettingsStructure.Insert("WSPassword", SettingsStructure.WSПароль);
	EndIf;
	If SettingsStructure.Property("WSURLВебСервиса") Then
		SettingsStructure.Insert("WSURL", SettingsStructure.WSURLВебСервиса);
	EndIf;
	
	Return SettingsStructure;

EndFunction

// Internal use only
Function ConvertTransportSettingsStructure(Val SettingsStructure) Export

	If SettingsStructure.Property("FILEКаталогОбменаИнформацией") Then
		SettingsStructure.Insert("FILEDataExchangeDirectory", SettingsStructure.FILEКаталогОбменаИнформацией);	
	EndIf;
	
	If SettingsStructure.Property("FTPСоединениеПароль") Then
		SettingsStructure.Insert("FTPConnectionPassword", SettingsStructure.FTPСоединениеПароль);	
	EndIf;
	
	If SettingsStructure.Property("FTPСоединениеПассивноеСоединение") Then
		SettingsStructure.Insert("FTPConnectionPassiveConnection", SettingsStructure.FTPСоединениеПассивноеСоединение);	
	EndIf;
	
	If SettingsStructure.Property("FTPСоединениеПользователь") Then
		SettingsStructure.Insert("FTPConnectionUser", SettingsStructure.FTPСоединениеПользователь);	
	EndIf;
	
	If SettingsStructure.Property("FTPСоединениеПорт") Then
		SettingsStructure.Insert("FTPConnectionPort", SettingsStructure.FTPСоединениеПорт);	
	EndIf;
	
	If SettingsStructure.Property("FTPСоединениеПуть") Then
		SettingsStructure.Insert("FTPConnectionPath", SettingsStructure.FTPСоединениеПуть);	
	EndIf;
	
	Return SettingsStructure;

EndFunction // ()

// Internal use only
Function ConvertSynchronizationSettingsTable(Val SynchronizationSettingsTable) Export

	If SynchronizationSettingsTable.Columns.Find("ПланОбмена") <> Undefined Then
		SynchronizationSettingsTable.Columns.ПланОбмена.Name = "ExchangePlan";	
	EndIf;
	
	If SynchronizationSettingsTable.Columns.Find("ОбластьДанных") <> Undefined Then
		SynchronizationSettingsTable.Columns.ОбластьДанных.Name = "DataArea";	
	EndIf;
	
	If SynchronizationSettingsTable.Columns.Find("НаименованиеПриложения") <> Undefined Then
		SynchronizationSettingsTable.Columns.НаименованиеПриложения.Name = "ApplicationDescription";	
	EndIf;
	
	If SynchronizationSettingsTable.Columns.Find("СинхронизацияНастроена") <> Undefined Then
		SynchronizationSettingsTable.Columns.СинхронизацияНастроена.Name = "SynchronizationConfigured";	
	EndIf;
	
	If SynchronizationSettingsTable.Columns.Find("НастройкаСинхронизацииВМенеджереСервиса") <> Undefined Then
		SynchronizationSettingsTable.Columns.НастройкаСинхронизацииВМенеджереСервиса.Name = "SynchronizationSetupInServiceManager";	
	EndIf;
	
	If SynchronizationSettingsTable.Columns.Find("КонечнаяТочкаКорреспондента") <> Undefined Then
		SynchronizationSettingsTable.Columns.КонечнаяТочкаКорреспондента.Name = "CorrespondentEndpoint";	
	EndIf;
	
	If SynchronizationSettingsTable.Columns.Find("Префикс") <> Undefined Then
		SynchronizationSettingsTable.Columns.Префикс.Name = "Prefix";	
	EndIf;
	
	If SynchronizationSettingsTable.Columns.Find("ПрефиксКорреспондента") <> Undefined Then
		SynchronizationSettingsTable.Columns.ПрефиксКорреспондента.Name = "CorrespondentPrefix";	
	EndIf;
	
	If SynchronizationSettingsTable.Columns.Find("ВерсияКорреспондента") <> Undefined Then
		SynchronizationSettingsTable.Columns.ВерсияКорреспондента.Name = "CorrespondentVersion";	
	EndIf;
	
	Return SynchronizationSettingsTable;

EndFunction // ConvertSynchronizationSettingsTable()

// Internal use only
Function ConvertBackDataExchangeScenarioValueTable(Val DataExchangeScenarioValueTable) Export
	
	For Each Column In DataExchangeScenarioValueTable.Columns Do
		
		If Column.Name = "InfobaseNumber" Then
			Column.Name = "НомерИнформационнойБазы";
		ElsIf Column.Name = "InfobaseNodeCode" Then
			Column.Name = "КодУзлаИнформационнойБазы";
		ElsIf Column.Name = "ThisNodeCode" Then
			Column.Name = "КодЭтогоУзла";
		ElsIf Column.Name = "CurrentAction" Then
			Column.Name = "ВыполняемоеДействие";
		ElsIf Column.Name = "ExecutionOrderNumber" Then
			Column.Name = "ПорядковыйНомерВыполнения";
		ElsIf Column.Name = "FirstInfobaseSeparatorValue" Then
			Column.Name = "ЗначениеРазделителяПервойИнформационнойБазы";
		ElsIf Column.Name = "SecondInfobaseSeparatorValue" Then
			Column.Name = "ЗначениеРазделителяВторойИнформационнойБазы";
		ElsIf Column.Name = "DataLockUpdateDate" Then
			Column.Name = "ДатаАктуальностиБлокировки";
		ElsIf Column.Name = "Application1Code" Then
			Column.Name = "Приложение1Код";
		ElsIf Column.Name = "Application2Code" Then
			Column.Name = "Приложение2Код";
		ElsIf Column.Name = "ExchangePlanName" Then
			Column.Name = "ИмяПланаОбмена";
		ElsIf Column.Name = "Mode" Then
			Column.Name = "Режим";
		EndIf;
		
	EndDo;
	
	For Each TableRow In DataExchangeScenarioValueTable Do
		
		For Each Column In DataExchangeScenarioValueTable.Columns Do
			
			If TableRow[Column.Name] = "DataExport" Then				
				TableRow[Column.Name] = "ВыгрузкаДанных";
			ElsIf TableRow[Column.Name] = "DataImport" Then
				TableRow[Column.Name] = "ЗагрузкаДанных";
			ElsIf TableRow[Column.Name] = "Manual" Then
				TableRow[Column.Name] = "Ручной";
			ElsIf TableRow[Column.Name] = "Automatic" Then
				TableRow[Column.Name] = "Автоматический";
			EndIf;
			
		EndDo;
		
	EndDo;
	
	Return DataExchangeScenarioValueTable;	

EndFunction // ConvertBackE()

Function ConvertMessageBodyStructure(Val MessageBodyStructure) Export

	If TypeOf(MessageBodyStructure) = Type("Structure") Then
		
		If MessageBodyStructure.Property("ОбластьДанных") Then
			MessageBodyStructure.Insert("DataArea", MessageBodyStructure.ОбластьДанных);	
		EndIf;
		
		If MessageBodyStructure.Property("Префикс") Then
			MessageBodyStructure.Insert("Prefix", MessageBodyStructure.Префикс);	
		EndIf;
		
		If MessageBodyStructure.Property("ИмяПланаОбмена") Then
			MessageBodyStructure.Insert("ExchangePlanName", MessageBodyStructure.ИмяПланаОбмена);
		EndIf;
		
		If MessageBodyStructure.Property("КодУзла") Then
			MessageBodyStructure.Insert("NodeCode", MessageBodyStructure.КодУзла);
		EndIf;
		
	EndIf;
	
	Return MessageBodyStructure;

EndFunction // ConvertMessageBodyStructure()

   

 