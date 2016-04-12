////////////////////////////////////////////////////////////////////////////////
// MESSAGE CHANNEL HANDLER MODULE FOR VERSION 2.1.2.1 
// OF DATA EXCHANGE MANAGEMENT MESSAGE INTERFACE
//
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// Returns the namespace of the message interface version.
Function Package() Export
	
	Return "http://www.1c.ru/SaaS/Exchange/Manage";
	
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
//  Message          - XDTODataObject - incoming message.
//  Sender           - ExchangePlanRef.MessageExchange - exchange plan node
//                     that matches the message sender. 
//  MessageProcessed - Boolean - True if processing is successful. This
//                     parameter value must be set to True if the message is
//                     successfully read in this handler.
//
Procedure ProcessSaaSMessage(Val Message, Val From, MessageProcessed) Export
	
	MessageProcessed = True;
	
	Dictionary = DataExchangeMessagesManagementInterface;
	MessageType = Message.Body.Type();
	
	If MessageType = Dictionary.SetUpExchangeStep1Message(Package()) Then
		
		SetUpExchangeStep1(Message, From);
		
	ElsIf MessageType = Dictionary.SetUpExchangeStep2Message(Package()) Then
		
		SetUpExchangeStep2(Message, From);
		
	ElsIf MessageType = Dictionary.ImportExchangeMessageMessage(Package()) Then
		
		ImportExchangeMessage(Message, From);
		
	ElsIf MessageType = Dictionary.GetCorrespondentDataMessage(Package()) Then
		
		GetCorrespondentData(Message, From);
		
	ElsIf MessageType = Dictionary.GetCorrespondentNodeCommonDataMessage(Package()) Then
		
		GetCorrespondentNodeCommonData(Message, From);
		
	ElsIf MessageType = Dictionary.GetCorrespondentAccountParametersMessage(Package()) Then
		
		GetCorrespondentAccountingParameters(Message, From);
		
	Else
		
		MessageProcessed = False;
		Return;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

Procedure SetUpExchangeStep1(Message, From)
	
	Body = Message.Body;
	
	Correspondent = Undefined;
	
	BeginTransaction();
	Try
		
		ThisNodeCode = CommonUse.ObjectAttributeValue(ExchangePlans[Body.ExchangePlan].ThisNode(), "Code");
		
		If Not IsBlankString(ThisNodeCode)
			And ThisNodeCode <> Body.Code Then
			MessageString = NStr("en = Predefined node code %1 does not match expected code %2. Exchange plan: %3'");
			MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, ThisNodeCode, Body.Code, Body.ExchangePlan);
			Raise MessageString;
		EndIf;
		
		CorrespondentEndpoint = ExchangePlans.MessageExchange.FindByCode(Body.Endpoint);
		
		If CorrespondentEndpoint.IsEmpty() Then
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Correspondent endpoint with code %1 is not found.'"),
				Body.Endpoint);
		EndIf;
		
		Prefix = "";
		If Message.IsSet("AdditionalInfo") Then
			Prefix = XDTOSerializer.ReadXDTO(Message.AdditionalInfo).Prefix;
		EndIf;
		
		NodeFilterStructure = XDTOSerializer.ReadXDTO(Body.FilterSettings);
		
		// {Handler: OnGetSenderData} Beginning
		ExchangePlans[Body.ExchangePlan].OnGetSenderData(NodeFilterStructure, False);
		// {Handler: OnGetSenderData} End
		
		// Creating exchange settings
		DataExchangeSaaS.CreateExchangeSettings(
			Body.ExchangePlan,
			Body.CorrespondentCode,
			Body.CorrespondentName,
			CorrespondentEndpoint,
			NodeFilterStructure,
			Correspondent,
			True,
			,
			Prefix);
		
		// Registering catalogs to export
		DataExchangeServer.RegisterOnlyCatalogsForInitialExport(Correspondent);
		
		CommitTransaction();
		
		// Performing data export
		Cancel = False;
		DataExchangeSaaS.ExecuteDataExport(Cancel, Correspondent);
		If Cancel Then
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Errors occurred when exporting catalogs for correspondent %1.'"),
				String(Correspondent));
		EndIf;
		
		// Sending response message that notifies about successful setup
		ResponseMessage = MessagesSaaS.NewMessage(
			DataExchangeMessagesMonitoringInterface.ExchangeSetupStep1CompletedMessage());
		ResponseMessage.Body.Zone = CommonUse.SessionSeparatorValue();
		ResponseMessage.Body.CorrespondentZone = Body.CorrespondentZone;
		ResponseMessage.Body.SessionId = Body.SessionId;
		
		BeginTransaction();
		MessagesSaaS.SendMessage(ResponseMessage, From, True);
		CommitTransaction();
	Except
		While TransactionActive() Do
			RollbackTransaction();
		EndDo;
		
		DeleteSynchronizationSettings(Correspondent);
		
		ErrorPresentation = DetailErrorDescription(ErrorInfo());
		
		WriteLogEvent(DataExchangeSaaS.EventLogMessageTextDataSynchronizationSetup(),
			EventLogLevel.Error,,, ErrorPresentation);
		
		// Sending response error message
		ResponseMessage = MessagesSaaS.NewMessage(
			DataExchangeMessagesMonitoringInterface.ExchangeSetupErrorStep1Message());
		ResponseMessage.Body.Zone = CommonUse.SessionSeparatorValue();
		ResponseMessage.Body.CorrespondentZone = Body.CorrespondentZone;
		ResponseMessage.Body.SessionId = Body.SessionId;
		
		ResponseMessage.Body.ErrorDescription = ErrorPresentation;
		
		BeginTransaction();
		MessagesSaaS.SendMessage(ResponseMessage, From, True);
		CommitTransaction();
	EndTry;
	
	MessagesSaaS.DeliverQuickMessages();
	
EndProcedure

Procedure SetUpExchangeStep2(Message, From)
	
	Body = Message.Body;
	
	BeginTransaction();
	Try
		
		Correspondent = ExchangeCorrespondent(Body.ExchangePlan, Body.CorrespondentCode);
		
		// Updating exchange settings
		DataExchangeSaaS.UpdateExchangeSettings(Correspondent,
			DataExchangeServer.GetFilterSettingsValues(XDTOSerializer.ReadXDTO(Body.AdditionalSettings)));
		
		// Registering all infobase data for exporting, except catalogs
		DataExchangeServer.RegisterAllDataExceptCatalogsForInitialExport(Correspondent);
		
		// Sending response message that notifies about successful setup
		ResponseMessage = MessagesSaaS.NewMessage(
			DataExchangeMessagesMonitoringInterface.ExchangeSetupStep2CompletedMessage());
		ResponseMessage.Body.Zone = CommonUse.SessionSeparatorValue();
		ResponseMessage.Body.CorrespondentZone = Body.CorrespondentZone;
		ResponseMessage.Body.SessionId = Body.SessionId;
		
		MessagesSaaS.SendMessage(ResponseMessage, From, True);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		
		ErrorPresentation = DetailErrorDescription(ErrorInfo());
		
		WriteLogEvent(DataExchangeSaaS.EventLogMessageTextDataSynchronizationSetup(),
			EventLogLevel.Error,,, ErrorPresentation);
		
		// Sending response error message
		ResponseMessage = MessagesSaaS.NewMessage(
			DataExchangeMessagesMonitoringInterface.ExchangeSetupErrorStep2Message());
		ResponseMessage.Body.Zone = CommonUse.SessionSeparatorValue();
		ResponseMessage.Body.CorrespondentZone = Body.CorrespondentZone;
		ResponseMessage.Body.SessionId = Body.SessionId;
		
		ResponseMessage.Body.ErrorDescription = ErrorPresentation;
		
		BeginTransaction();
		MessagesSaaS.SendMessage(ResponseMessage, From, True);
		CommitTransaction();
	EndTry;
	
	MessagesSaaS.DeliverQuickMessages();
	
EndProcedure

Procedure ImportExchangeMessage(Message, From)
	
	Body = Message.Body;
	
	Try
		
		Correspondent = ExchangeCorrespondent(Body.ExchangePlan, Body.CorrespondentCode);
		
		// Importing exchange message
		Cancel = False;
		DataExchangeSaaS.ExecuteDataImport(Cancel, Correspondent);
		If Cancel Then
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Errors occurred when importing catalogs from correspondent %1.'"),
				String(Correspondent));
		EndIf;
		
		// Sending response message that notifies about successful setup
		ResponseMessage = MessagesSaaS.NewMessage(
			DataExchangeMessagesMonitoringInterface.ExchangeMessageImportCompletedMessage());
		ResponseMessage.Body.Zone = CommonUse.SessionSeparatorValue();
		ResponseMessage.Body.CorrespondentZone = Body.CorrespondentZone;
		ResponseMessage.Body.SessionId = Body.SessionId;
		
		BeginTransaction();
		MessagesSaaS.SendMessage(ResponseMessage, From, True);
		CommitTransaction();
	Except
		
		ErrorPresentation = DetailErrorDescription(ErrorInfo());
		
		WriteLogEvent(DataExchangeSaaS.EventLogMessageTextDataSynchronizationSetup(),
			EventLogLevel.Error,,, ErrorPresentation);
		
		// Sending response error message
		ResponseMessage = MessagesSaaS.NewMessage(
			DataExchangeMessagesMonitoringInterface.ExchangeMessageImportErrorMessage());
		ResponseMessage.Body.Zone = CommonUse.SessionSeparatorValue();
		ResponseMessage.Body.CorrespondentZone = Body.CorrespondentZone;
		ResponseMessage.Body.SessionId = Body.SessionId;
		
		ResponseMessage.Body.ErrorDescription = ErrorPresentation;
		
		BeginTransaction();
		MessagesSaaS.SendMessage(ResponseMessage, From, True);
		CommitTransaction();
	EndTry;
	
	MessagesSaaS.DeliverQuickMessages();
	
EndProcedure

Procedure GetCorrespondentData(Message, From)
	
	Body = Message.Body;
	
	BeginTransaction();
	Try
		
		CorrespondentData = DataExchangeServer.CorrespondentTableData(
			XDTOSerializer.ReadXDTO(Body.Tables), Body.ExchangePlan);
		
		// Sending response message that notifies about successful setup
		ResponseMessage = MessagesSaaS.NewMessage(
			DataExchangeMessagesMonitoringInterface.CorrespondentDataGettingCompletedMessage());
		ResponseMessage.Body.Zone = CommonUse.SessionSeparatorValue();
		ResponseMessage.Body.CorrespondentZone = Body.CorrespondentZone;
		ResponseMessage.Body.SessionId = Body.SessionId;
		
		ResponseMessage.Body.Data = New ValueStorage(CorrespondentData);
		MessagesSaaS.SendMessage(ResponseMessage, From, True);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		
		ErrorPresentation = DetailErrorDescription(ErrorInfo());
		
		WriteLogEvent(DataExchangeSaaS.EventLogMessageTextDataSynchronizationSetup(),
			EventLogLevel.Error,,, ErrorPresentation);
		
		// Sending response error message
		ResponseMessage = MessagesSaaS.NewMessage(
			DataExchangeMessagesMonitoringInterface.CorrespondentDataGettingErrorMessage());
		ResponseMessage.Body.Zone = CommonUse.SessionSeparatorValue();
		ResponseMessage.Body.CorrespondentZone = Body.CorrespondentZone;
		ResponseMessage.Body.SessionId = Body.SessionId;
		
		ResponseMessage.Body.ErrorDescription = ErrorPresentation;
		
		BeginTransaction();
		MessagesSaaS.SendMessage(ResponseMessage, From, True);
		CommitTransaction();
	EndTry;
	
	MessagesSaaS.DeliverQuickMessages();
	
EndProcedure

Procedure GetCorrespondentNodeCommonData(Message, From)
	
	Body = Message.Body;
	
	BeginTransaction();
	Try
		
		CorrespondentData = DataExchangeServer.DataForThisInfobaseNodeTabularSections(Body.ExchangePlan);
		
		// Sending response message that notifies about successful getting of node data
		ResponseMessage = MessagesSaaS.NewMessage(
			DataExchangeMessagesMonitoringInterface.GettingCorrespondentNodeCommonDataCompletedMessage());
		ResponseMessage.Body.Zone = CommonUse.SessionSeparatorValue();
		ResponseMessage.Body.CorrespondentZone = Body.CorrespondentZone;
		ResponseMessage.Body.SessionId = Body.SessionId;
		
		ResponseMessage.Body.Data = New ValueStorage(CorrespondentData);
		MessagesSaaS.SendMessage(ResponseMessage, From, True);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		
		ErrorPresentation = DetailErrorDescription(ErrorInfo());
		
		WriteLogEvent(DataExchangeSaaS.EventLogMessageTextDataSynchronizationSetup(),
			EventLogLevel.Error,,, ErrorPresentation);
		
		// Sending response error message
		ResponseMessage = MessagesSaaS.NewMessage(
			DataExchangeMessagesMonitoringInterface.CorrespondentNodeCommonDataGettingErrorMessage());
		ResponseMessage.Body.Zone = CommonUse.SessionSeparatorValue();
		ResponseMessage.Body.CorrespondentZone = Body.CorrespondentZone;
		ResponseMessage.Body.SessionId = Body.SessionId;
		
		ResponseMessage.Body.ErrorDescription = ErrorPresentation;
		
		BeginTransaction();
		MessagesSaaS.SendMessage(ResponseMessage, From, True);
		CommitTransaction();
	EndTry;
	
	MessagesSaaS.DeliverQuickMessages();
	
EndProcedure

Procedure GetCorrespondentAccountingParameters(Message, From)
	
	Body = Message.Body;
	
	BeginTransaction();
	Try
		
		Correspondent = ExchangeCorrespondent(Body.ExchangePlan, Body.CorrespondentCode);
		
		Cancel = False;
		ErrorPresentation = "";
		
		ExchangePlans[Body.ExchangePlan].AccountingSettingsCheckHandler(Cancel, Correspondent, ErrorPresentation);
		
		CorrespondentData = New Structure("AccountingParametersSpecified, ErrorPresentation", Not Cancel, ErrorPresentation);
		
		// Sending response message that notifies about successful getting of accounting parameters
		ResponseMessage = MessagesSaaS.NewMessage(
			DataExchangeMessagesMonitoringInterface.GettingCorrespondentAccountingParametersCompletedMessage());
		ResponseMessage.Body.Zone = CommonUse.SessionSeparatorValue();
		ResponseMessage.Body.CorrespondentZone = Body.CorrespondentZone;
		ResponseMessage.Body.SessionId = Body.SessionId;
		
		ResponseMessage.Body.Data = New ValueStorage(CorrespondentData);
		MessagesSaaS.SendMessage(ResponseMessage, From, True);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		
		ErrorPresentation = DetailErrorDescription(ErrorInfo());
		
		WriteLogEvent(DataExchangeSaaS.EventLogMessageTextDataSynchronizationSetup(),
			EventLogLevel.Error,,, ErrorPresentation);
		
		// Sending response error message
		ResponseMessage = MessagesSaaS.NewMessage(
			DataExchangeMessagesMonitoringInterface.CorrespondentAccountingParameterGettingErrorMessage());
		ResponseMessage.Body.Zone = CommonUse.SessionSeparatorValue();
		ResponseMessage.Body.CorrespondentZone = Body.CorrespondentZone;
		ResponseMessage.Body.SessionId = Body.SessionId;
		
		ResponseMessage.Body.ErrorDescription = ErrorPresentation;
		
		BeginTransaction();
		MessagesSaaS.SendMessage(ResponseMessage, From, True);
		CommitTransaction();
	EndTry;
	
	MessagesSaaS.DeliverQuickMessages();
	
EndProcedure

 
Function ExchangeCorrespondent(Val ExchangePlanName, Val Code)
	
	Result = ExchangePlans[ExchangePlanName].FindByCode(Code);
	
	If Not ValueIsFilled(Result) Then
		MessageString = NStr("en = 'Exchange plan node not found. Node name: %1, node code: %2.'");
		MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, ExchangePlanName, Code);
		Raise MessageString;
	EndIf;
	
	Return Result;
EndFunction

Procedure DeleteSynchronizationSettings(Val Correspondent)
	
	SetPrivilegedMode(True);
	
	Try
		If Correspondent <> Undefined Then
			
			CorrespondentObject = Correspondent.GetObject();
			
			If CorrespondentObject <> Undefined Then
				
				CorrespondentObject.Delete();
				
			EndIf;
			
		EndIf;
	Except
		WriteLogEvent(DataExchangeSaaS.EventLogMessageTextDataSynchronizationSetup(),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo())
		);
	EndTry;
	
EndProcedure

#EndRegion
