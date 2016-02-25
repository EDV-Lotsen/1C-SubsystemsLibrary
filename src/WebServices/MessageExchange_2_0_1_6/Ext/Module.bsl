
#Region InternalProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Web service operation handlers

// Similar to the DeliverMessages web service operation.
Function DeliverMessages(SenderCode, StreamStorage)
	
	SetPrivilegedMode(True);
	
	// Getting the sender link
	Sender = ExchangePlans.MessageExchange.FindByCode(SenderCode);
	
	If Sender.IsEmpty() Then
		
		Raise NStr("en = 'Invalid endpoint connection settings.'");
		
	EndIf;
	
	ImportedMessages = Undefined;
	DataReadPartially = False;
	
	// Importing messages to the infobase
	MessageExchangeInternal.SerializeDataFromStream(
		Sender,
		StreamStorage.Get(),
		ImportedMessages,
		DataReadPartially);
	
	// Processing message queue
	If CommonUse.FileInfobase() Then
		
		MessageExchangeInternal.ProcessSystemMessageQueue(ImportedMessages);
		
	Else
		
		BackgroundJobParameters = New Array;
		BackgroundJobParameters.Add(ImportedMessages);
		
		BackgroundJobs.Execute("MessageExchangeInternal.ProcessSystemMessageQueue", BackgroundJobParameters);
		
	EndIf;
	
	If DataReadPartially Then
		
		Raise NStr("en = 'Cannot deliver quick messages. 
                                |Some quick messages are not delivered because of locked data areas.
                                |
                                |These messages will be processed within the system message queue.'");
		
	EndIf;
	
EndFunction

// Similar to the GetInfobaseParameters web service operation.
Function GetInfobaseParameters(ThisEndpointDescription)
	
	SetPrivilegedMode(True);
	
	If IsBlankString(MessageExchangeInternal.ThisNodeCode()) Then
		
		ThisNodeObject = MessageExchangeInternal.ThisNode().GetObject();
		ThisNodeObject.Code = String(New UUID());
		ThisNodeObject.Description = ?(IsBlankString(ThisEndpointDescription),
									MessageExchangeInternal.ThisNodeDefaultDescription(),
									ThisEndpointDescription);
		ThisNodeObject.Write();
		
	ElsIf IsBlankString(MessageExchangeInternal.ThisNodeDescription()) Then
		
		ThisNodeObject = MessageExchangeInternal.ThisNode().GetObject();
		ThisNodeObject.Description = ?(IsBlankString(ThisEndpointDescription),
									MessageExchangeInternal.ThisNodeDefaultDescription(),
									ThisEndpointDescription);
		ThisNodeObject.Write();
		
	EndIf;
	
	ThisPointParameters = CommonUse.ObjectAttributeValues(MessageExchangeInternal.ThisNode(), "Code, Description");
	
	Result = New Structure;
	Result.Insert("Code",         ThisPointParameters.Code);
	Result.Insert("Description",  ThisPointParameters.Description);
	Result.Insert("Код",          ThisPointParameters.Code);
	Result.Insert("Наименование", ThisPointParameters.Description);
	
	Return XDTOSerializer.WriteXDTO(Result);
EndFunction

// Similar to the ConnectEndpoint web service operation.
Function ConnectEndpoint(Code, Description, RecipientConnectionSettingsXDTO)
	
	Cancel = False;
	
	MessageExchangeInternal.ConnectEndpointAtRecipient(
				Cancel,
				Code,
				Description,
				MessageExchangeInternal.ConvertRecipientConnectionSettings(XDTOSerializer.ReadXDTO(RecipientConnectionSettingsXDTO)));
	
	Return Not Cancel;
EndFunction

// Similar to the UpdateConnectionSettings web service operation.
Function RefreshConnectionSettings(Code, ConnectionSettingsXDTO)
	
	ConnectionSettings = MessageExchangeInternal.ConvertRecipientConnectionSettings(XDTOSerializer.ReadXDTO(ConnectionSettingsXDTO));
	
	SetPrivilegedMode(True);
	
	Endpoint = ExchangePlans.MessageExchange.FindByCode(Code);
	If Endpoint.IsEmpty() Then
		Raise NStr("en = 'Invalid endpoint connection settings.'");
	EndIf;
	
	BeginTransaction();
	Try
		
		// Updating connection settings
		RecordStructure = New Structure;
		RecordStructure.Insert("Node", Endpoint);
		RecordStructure.Insert("DefaultExchangeMessageTransportKind", Enums.ExchangeMessageTransportKinds.WS);
		
		If Not ConnectionSettings.Property("WSURL") Then
			RecordStructure.Insert("WSURL", ConnectionSettings.WSURLВебСервиса);
		Else
			RecordStructure.Insert("WSURL", ConnectionSettings.WSURL);
		EndIf;
		If Not ConnectionSettings.Property("WSUserName") Then
			RecordStructure.Insert("WSUserName", ConnectionSettings.WSИмяПользователя);
		Else
			RecordStructure.Insert("WSUserName", ConnectionSettings.WSUserName);
		EndIf;
		If Not ConnectionSettings.Property("WSPassword") Then
			RecordStructure.Insert("WSPassword", ConnectionSettings.WSПароль);
		Else
			RecordStructure.Insert("WSPassword", ConnectionSettings.WSPassword);
		EndIf;
		RecordStructure.Insert("WSRememberPassword", True);
		
		// Adding information register record
		InformationRegisters.ExchangeTransportSettings.UpdateRecord(RecordStructure);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndFunction

// Similar to the SetLeadingEndpoint web service operation.
Function SetLeadingEndpoint(ThisEndpointCode, LeadingEndpointCode)
	
	MessageExchangeInternal.SetLeadingEndpointAtRecipient(ThisEndpointCode, LeadingEndpointCode);
	
EndFunction

// Similar to the TestConnectionAtRecipient web service operation.
Function TestConnectionAtRecipient(ConnectionSettingsXDTO, SenderCode)
	
	SetPrivilegedMode(True);
	
	ErrorMessageString = "";
	
	ConnectionSettingsStructure = XDTOSerializer.ReadXDTO(ConnectionSettingsXDTO);
	If Not ConnectionSettingsStructure.Property("WSURL") Then
		ConnectionSettingsStructure.Insert("WSURL", ConnectionSettingsStructure.WSURLВебСервиса);
	EndIf;
	If Not ConnectionSettingsStructure.Property("WSUserName") Then
		ConnectionSettingsStructure.Insert("WSUserName", ConnectionSettingsStructure.WSИмяПользователя);
	EndIf;
	If Not ConnectionSettingsStructure.Property("WSPassword") Then
		ConnectionSettingsStructure.Insert("WSPassword", ConnectionSettingsStructure.WSПароль);
	EndIf;
	WSProxy = MessageExchangeInternal.GetWSProxy(ConnectionSettingsStructure, ErrorMessageString);
	
	If WSProxy = Undefined Then
		Raise ErrorMessageString;
	EndIf;
	
	WSProxy.TestConnectionAtSender(SenderCode);
	
EndFunction

// Matches the TestConnectionAtSender web service operation
Function TestConnectionAtSender(SenderCode)
	
	SetPrivilegedMode(True);
	
	If MessageExchangeInternal.ThisNodeCode() <> SenderCode Then
		
		Raise NStr("en = 'Sender infobase connection settings indicate another recipient.'");
		
	EndIf;
	
EndFunction

// Similar to the Ping web service operation.
Function Ping()
	
	// Stub used to prevent a configuration check error
	Return Undefined;
	
EndFunction

#EndRegion
