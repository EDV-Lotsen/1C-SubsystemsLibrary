////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

////////////////////////////////////////////////////////////////////////////////
// Operation handlers.

// Corresponds to the DeliverMessages operation.
//
Function DeliverMessages(SenderCode, StreamStorage)
	
	SetPrivilegedMode(True);
	
	// Retrieving the reference to the sender 
	Sender = ExchangePlans.MessageExchange.FindByCode(SenderCode);
	
	If Sender.IsEmpty() Then
		
		Raise NStr("en = 'End point connection settings are incorrect.'");
		
	EndIf;
	
	ImportedMessages = Undefined;
	
	// Importing messages to the infobase
	MessageExchangeInternal.SerializeDataFromStream(Sender, StreamStorage.Get(), ImportedMessages);
	
	// Handling the message queue
	If CommonUse.FileInfoBase() Then
		
		MessageExchangeInternal.HandleSystemMessageQueue();
		
	Else
		
		BackgroundJobParameters = New Array;
		BackgroundJobParameters.Add(ImportedMessages);
		
		BackgroundJobs.Execute("MessageExchangeInternal.HandleSystemMessageQueue", BackgroundJobParameters);
		
	EndIf;
	
EndFunction

// Corresponds to the GetInfoBaseParameters operation.
//
Function GetInfoBaseParameters(ThisEndPointDescription)
	
	SetPrivilegedMode(True);
	
	If IsBlankString(MessageExchangeInternal.ThisNodeCode()) Then
		
		ThisNodeObject = MessageExchangeInternal.ThisNode().GetObject();
		ThisNodeObject.Code = String(New UUID());
		ThisNodeObject.Description = ?(IsBlankString(ThisEndPointDescription),
									MessageExchangeInternal.ThisNodeDefaultDescription(),
									ThisEndPointDescription);
		ThisNodeObject.Write();
		
	ElsIf IsBlankString(MessageExchangeInternal.ThisNodeDescription()) Then
		
		ThisNodeObject = MessageExchangeInternal.ThisNode().GetObject();
		ThisNodeObject.Description = ?(IsBlankString(ThisEndPointDescription),
									MessageExchangeInternal.ThisNodeDefaultDescription(),
									ThisEndPointDescription);
		ThisNodeObject.Write();
		
	EndIf;
	
	ThisPointParameters = CommonUse.GetAttributeValues(MessageExchangeInternal.ThisNode(), "Code, Description");
	
	Result = New Structure;
	Result.Insert("Code", ThisPointParameters.Code);
	Result.Insert("Description", ThisPointParameters.Description);
	
	Return ValueToStringInternal(Result);
EndFunction

// Corresponds to the ConnectEndPoint operation.
//
Function ConnectEndPoint(Code, Description, RecipientConnectionSettingsString)
	
	Cancel = False;
	
	MessageExchangeInternal.ConnectEndPointAtReceiver(Cancel, Code, Description, ValueFromStringInternal(RecipientConnectionSettingsString));
	
	Return Not Cancel;
EndFunction

// Corresponds to the UpdateConnectionSettings operation.
//
Function RefreshConnectionSettings(Code, ConnectionSettingsString)
	
	ConnectionSettings = ValueFromStringInternal(ConnectionSettingsString);
	
	SetPrivilegedMode(True);
	
	EndPoint = ExchangePlans.MessageExchange.FindByCode(Code);
	If EndPoint.IsEmpty() Then
		Raise NStr("en = 'End point connection settings are incorrect'");
	EndIf;
	
	BeginTransaction();
	Try
		
		//Updating connection settings
		RecordStructure = New Structure;
		RecordStructure.Insert("Node", EndPoint);
		RecordStructure.Insert("DefaultExchangeMessageTransportKind", Enums.ExchangeMessageTransportKinds.WS);
		
		RecordStructure.Insert("WSURL", ConnectionSettings.WSURL);
		RecordStructure.Insert("WSUserName", ConnectionSettings.WSUserName);
		RecordStructure.Insert("WSPassword", ConnectionSettings.WSPassword);
		
		// Adding the record to the information register
		InformationRegisters.ExchangeTransportSettings.UpdateRecord(RecordStructure);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndFunction

// Corresponds to the SetLeadingEndPoint operation.
//
Function SetLeadingEndPoint(ThisEndPointCode, LeadingEndPointCode)
	
	//MessageExchangeInternal.SetLeadingEndPointAtRecipient(ThisEndPointCode, LeadingEndPointCode);
	
EndFunction

// Corresponds to the CheckConnectionAtRecipient operation.
//
Function CheckConnectionAtRecipient(ConnectionSettingsString, SenderCode)
	
	SetPrivilegedMode(True);
	
	ErrorMessageString = "";
	
	WSProxy = MessageExchangeInternal.GetWSProxy(ValueFromStringInternal(ConnectionSettingsString), ErrorMessageString);
	
	If WSProxy = Undefined Then
		Raise ErrorMessageString;
	EndIf;
	
	WSProxy.CheckConnectionAtSender(SenderCode);
	
EndFunction

// Corresponds to the CheckConnectionAtSender operation.
//
Function CheckConnectionAtSender(SenderCode)
	
	SetPrivilegedMode(True);
	
	If MessageExchangeInternal.ThisNodeCode() <> SenderCode Then
		
		Raise NStr("en = 'Recipient infobase connection settings correspond with another sender.'");
		
	EndIf;           
	
EndFunction
