////////////////////////////////////////////////////////////////////////////////
// MESSAGE CHANNEL HANDLER MODULE FOR VERSION
// 2.1.2.1 OF MESSAGE INTERFACE FOR MANAGEMENT DATA EXCHANGE ADMINISTRATION
//
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// Returns the namespace of the message interface version.
Function Package() Export
	
	Return "http://www.1c.ru/SaaS/ExchangeAdministration/Manage";
	
EndFunction

// Returns the message interface version that is supported by the handler.
Function Version() Export
	
	Return "2.1.2.1";
	
EndFunction

// Returns the default message type in a message interface version.
Function BaseType() Export
	
	Return MessagesSaaSCached.TypeBody();
	
EndFunction

// Processes incoming messages in SaaS mode.
//
// Parameters:
//  Message          - XDTODataObject, incoming message. 
//  Sender           - ExchangePlanRef.MessageExchange, exchange plan node 
//                     that matches the message sender. 
//  MessageProcessed - Boolean, True if processing is successful.
//                     This parameter value must be True if message was
//                     successfully read in the handler.
//
Procedure ProcessSaaSMessage(Val Message, Val From, MessageProcessed) Export
	
	MessageProcessed = True;
	
	Dictionary = MessagesDataExchangeAdministrationManagementInterface;
	MessageType = Message.Body.Type();
	
	If MessageType = Dictionary.ConnectCorrespondentMessage(Package()) Then
		ConnectCorrespondent(Message, From);
	ElsIf MessageType = Dictionary.SetTransportSettingsMessage(Package()) Then
		SetTransportSettings(Message, From);
	ElsIf MessageType = Dictionary.DeleteSynchronizationSettingsMessage(Package()) Then
		DeleteSynchronizationSettings(Message, From);
	ElsIf MessageType = Dictionary.PerformDataSynchronizationMessage(Package()) Then
		PerformSynchronization(Message, From);
	Else
		MessageProcessed = False;
	EndIf;
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

Procedure ConnectCorrespondent(Message, From)
	
	Body = Message.Body;
	
	// Checking the passed endpoint
	ThisEndpoint = ExchangePlans.MessageExchange.FindByCode(Body.SenderId);
	
	If ThisEndpoint.IsEmpty()
		OR ThisEndpoint <> MessageExchangeInternal.ThisNode() Then
		
		// Sending the error message to the SaaS manager
		ErrorPresentation = NStr("en = 'Unexpected endpoint. Expected endpoint code: %1. Current endpoint code: %2.'");
		ErrorPresentation = StringFunctionsClientServer.SubstituteParametersInString(ErrorPresentation,
			Body.SenderId,
			MessageExchangeInternal.ThisNodeCode());
		
		WriteLogEvent(EventLogMessageTextCorrespondentConnection(),
			EventLogLevel.Error,,, ErrorPresentation);
		
		ResponseMessage = MessagesSaaS.NewMessage(
			MessagesDataExchangeAdministrationControlInterface.CorrespondentConnectionErrorMessage());
		ResponseMessage.Body.RecipientId      = Body.RecipientId;
		ResponseMessage.Body.SenderId         = Body.SenderId;
		ResponseMessage.Body.ErrorDescription = ErrorPresentation;
		
		BeginTransaction();
		MessagesSaaS.SendMessage(ResponseMessage, From);
		CommitTransaction();
		Return;
	EndIf;
	
	// Checking whether correspondent is connected
	Correspondent = ExchangePlans.MessageExchange.FindByCode(Body.RecipientId);
	
	If Correspondent.IsEmpty() Then // Connecting correspondent endpoint
		
		Cancel = False;
		ConnectedCorrespondent = Undefined;
		
		MessageExchange.ConnectEndpoint(
									Cancel,
									Body.RecipientURL,
									Body.RecipientUser,
									Body.RecipientPassword,
									Body.SenderURL,
									Body.SenderUser,
									Body.SenderPassword,
									ConnectedCorrespondent,
									Body.RecipientName,
									Body.SenderName);
		
		If Cancel Then // Sending the error message to the SaaS manager
			
			ErrorPresentation = NStr("en = 'An error occurred when connecting exchange correspondent endpoint. Exchange correspondent endpoint code: %1.'");
			ErrorPresentation = StringFunctionsClientServer.SubstituteParametersInString(ErrorPresentation,
				Body.RecipientId);
			
			WriteLogEvent(EventLogMessageTextCorrespondentConnection(),
				EventLogLevel.Error,,, ErrorPresentation);
			
			ResponseMessage = MessagesSaaS.NewMessage(
				MessagesDataExchangeAdministrationControlInterface.CorrespondentConnectionErrorMessage());
			ResponseMessage.Body.RecipientId      = Body.RecipientId;
			ResponseMessage.Body.SenderId         = Body.SenderId;
			ResponseMessage.Body.ErrorDescription = ErrorPresentation;
			
			BeginTransaction();
			MessagesSaaS.SendMessage(ResponseMessage, From);
			CommitTransaction();
			Return;
		EndIf;
		
		ConnectedCorrespondentCode = CommonUse.ObjectAttributeValue(ConnectedCorrespondent, "Code");
		
		If ConnectedCorrespondentCode <> Body.RecipientId Then
			
			// The connected correspondent does not match the expected one.
			// Sending the error message to the SaaS manager.
			ErrorPresentation = NStr("en = 'An error occurred when connecting exchange correspondent endpoint.
				|Unexpected web service connection settings.
				|Expected exchange correspondent endpoint code: %1.
				|Connected exchange correspondent endpoint code: %2.'");
			ErrorPresentation = StringFunctionsClientServer.SubstituteParametersInString(ErrorPresentation,
				Body.RecipientId,
				ConnectedCorrespondentCode);
			
			WriteLogEvent(EventLogMessageTextCorrespondentConnection(),
				EventLogLevel.Error,,, ErrorPresentation);
			
			ResponseMessage = MessagesSaaS.NewMessage(
				MessagesDataExchangeAdministrationControlInterface.CorrespondentConnectionErrorMessage());
			ResponseMessage.Body.RecipientId      = Body.RecipientId;
			ResponseMessage.Body.SenderId         = Body.SenderId;
			ResponseMessage.Body.ErrorDescription = ErrorPresentation;
			
			BeginTransaction();
			MessagesSaaS.SendMessage(ResponseMessage, From);
			CommitTransaction();
			Return;
		EndIf;
		
		CorrespondentObject = ConnectedCorrespondent.GetObject();
		CorrespondentObject.Locked = True;
		CorrespondentObject.Write();
		
	Else // Updating the correspondent and the endpoint connection settings
		
		Cancel = False;
		
		MessageExchange.UpdateEndpointConnectionSettings(
									Cancel,
									Correspondent,
									Body.RecipientURL,
									Body.RecipientUser,
									Body.RecipientPassword,
									Body.SenderURL,
									Body.SenderUser,
									Body.SenderPassword);
		
		If Cancel Then // Sending the error message to the SaaS manager
			
			ErrorPresentation = NStr("en = 'An error occurred when updating the current endpoint connection settings and the correspondent endpoint connection settings.
				|Current endpoint code: %1.
				|Exchange correspondent endpoint code: %2.'");
			ErrorPresentation = StringFunctionsClientServer.SubstituteParametersInString(ErrorPresentation,
				MessageExchangeInternal.ThisNodeCode(),
				Body.RecipientId);
			
			WriteLogEvent(EventLogMessageTextCorrespondentConnection(),
				EventLogLevel.Error,,, ErrorPresentation);
			
			ResponseMessage = MessagesSaaS.NewMessage(
				MessagesDataExchangeAdministrationControlInterface.CorrespondentConnectionErrorMessage());
			ResponseMessage.Body.RecipientId      = Body.RecipientId;
			ResponseMessage.Body.SenderId         = Body.SenderId;
			ResponseMessage.Body.ErrorDescription = ErrorPresentation;
			
			BeginTransaction();
			MessagesSaaS.SendMessage(ResponseMessage, From);
			CommitTransaction();
			Return;
		EndIf;
		
		CorrespondentObject = Correspondent.GetObject();
		CorrespondentObject.Locked = True;
		CorrespondentObject.Write();
		
	EndIf;
	
	// Sending message to the SaaS manager about successful correspondent connection.
	BeginTransaction();
	ResponseMessage = MessagesSaaS.NewMessage(
		MessagesDataExchangeAdministrationControlInterface.CorrespondentConnectionCompletedMessage());
	ResponseMessage.Body.RecipientId = Body.RecipientId;
	ResponseMessage.Body.SenderId    = Body.SenderId;
	MessagesSaaS.SendMessage(ResponseMessage, From);
	CommitTransaction();
	
EndProcedure

Procedure SetTransportSettings(Message, From)
	
	Body = Message.Body;
	
	Correspondent = ExchangePlans.MessageExchange.FindByCode(Body.RecipientId);
	
	If Correspondent.IsEmpty() Then
		MessageString = NStr("en = 'Correspondent endpoint with code ""%1"" not found.'");
		MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, Body.RecipientId);
		Raise MessageString;
	EndIf;
	
	DataExchangeServer.SetDataImportTransactionItemNumber(Body.ImportTransactionQuantity);
	
	RecordStructure = New Structure;
	RecordStructure.Insert("CorrespondentEndpoint", Correspondent);
	
	RecordStructure.Insert("FILEDataExchangeDirectory",       Body.FILE_ExchangeFolder);
	RecordStructure.Insert("FILECompressOutgoingMessageFile", Body.FILE_CompressExchangeMessage);
	
	RecordStructure.Insert("FTPCompressOutgoingMessageFile",  Body.FTP_CompressExchangeMessage);
	RecordStructure.Insert("FTPConnectionMaxMessageSize",     Body.FTP_MaxExchangeMessageSize);
	RecordStructure.Insert("FTPConnectionPassword",           Body.FTP_Password);
	RecordStructure.Insert("FTPConnectionPassiveConnection",  Body.FTP_PassiveMode);
	RecordStructure.Insert("FTPConnectionUser",               Body.FTP_User);
	RecordStructure.Insert("FTPConnectionPort",               Body.FTP_Port);
	RecordStructure.Insert("FTPConnectionPath",               Body.FTP_ExchangeFolder);
	
	RecordStructure.Insert("DefaultExchangeMessageTransportKind", Enums.ExchangeMessageTransportKinds[Body.ExchangeTransport]);
	RecordStructure.Insert("ExchangeMessageArchivePassword",      Body.ExchangeMessagePassword);
	
	InformationRegisters.DataAreasExchangeTransportSettings.UpdateRecord(RecordStructure);
	
EndProcedure

Procedure DeleteSynchronizationSettings(Message, From)
	
	Body = Message.Body;
	
	// Searching for node by code in S00000123 format
	Correspondent = ExchangePlans[Body.ExchangePlan].FindByCode(
		DataExchangeSaaS.ExchangePlanNodeCodeInService(Body.CorrespondentZone));
	If Correspondent.IsEmpty() Then
		
		// Searching for node by code in old 0000123 format
		Correspondent = ExchangePlans[Body.ExchangePlan].FindByCode(
			Format(Body.CorrespondentZone,"ND=7; NLZ=; NG=0"));
	EndIf;
	
	If Correspondent.IsEmpty() Then
		Return; // Exchange settings not found (probably deleted)
	EndIf;
	
	TransportSettings = InformationRegisters.DataAreaExchangeTransportSettings.TransportSettings(Correspondent);
	
	If TransportSettings <> Undefined Then
		
		If TransportSettings.DefaultExchangeMessageTransportKind = Enums.ExchangeMessageTransportKinds.FILE Then
			
			If Not IsBlankString(TransportSettings.FILECommonInformationExchangeDirectory)
				And Not IsBlankString(TransportSettings.RelativeInformationExchangeDirectory) Then
				
				AbsoluteDataExchangeDirectory = CommonUseClientServer.GetFullFileName(
					TransportSettings.FILECommonInformationExchangeDirectory,
					TransportSettings.RelativeInformationExchangeDirectory);
				
				AbsoluteDirectory = New File(AbsoluteDataExchangeDirectory);
				
				Try
					DeleteFiles(AbsoluteDirectory.FullName);
				Except
					WriteLogEvent(DataExchangeSaaS.EventLogMessageTextDataSynchronizationSetup(),
						EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
				EndTry;
				
			EndIf;
			
		ElsIf TransportSettings.DefaultExchangeMessageTransportKind = Enums.ExchangeMessageTransportKinds.FTP Then
			
			Try
				
				FTPSettings = DataExchangeServer.FTPConnectionSettings();
				FTPSettings.Server              = TransportSettings.FTPServer;
				FTPSettings.Port                = TransportSettings.FTPConnectionPort;
				FTPSettings.UserName     = TransportSettings.FTPConnectionUser;
				FTPSettings.UserPassword  = TransportSettings.FTPConnectionPassword;
				FTPSettings.PassiveConnection = TransportSettings.FTPConnectionPassiveConnection;
				
				FTPConnection = DataExchangeServer.FTPConnection(FTPSettings);
				
				If DataExchangeServer.FTPDirectoryExists(TransportSettings.FTPPath, TransportSettings.RelativeInformationExchangeDirectory, FTPConnection) Then
					FTPConnection.Delete(TransportSettings.FTPPath);
				EndIf;
				
			Except
				WriteLogEvent(DataExchangeSaaS.EventLogMessageTextDataSynchronizationSetup(),
					EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
			EndTry;
			
		EndIf;
		
	EndIf;
	
	// Deleting correspondent node
	Correspondent.GetObject().Delete();
	
EndProcedure

Procedure PerformSynchronization(Message, From)
	
	DataExchangeScenario = XDTOSerializer.ReadXDTO(Message.Body.Scenario);
	
	If DataExchangeScenario.Count() > 0 Then
		
		// Running the scenario
		DataExchangeSaaS.ExecuteDataExchangeScenarioActionInFirstInfobase(0, DataExchangeScenario);
		
	EndIf;
	
EndProcedure

Function EventLogMessageTextCorrespondentConnection()
	
	Return NStr("en = 'Data exchange.Exchange correspondent connection'", CommonUseClientServer.DefaultLanguageCode());
	
EndFunction

#EndRegion