////////////////////////////////////////////////////////////////////////////////
// DataExchangeMessageChannelHandlerSaaS.
//
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// Generates the list of handlers that are supported by the current subsystem.
// 
// Parameters:
//  Handlers - ValueTable - see the field structure in
//             MessageExchange.NewMessageHandlerTable.
// 
Procedure GetMessageChannelHandlers(Handlers) Export
	
	AddMessageChannelHandler("DataExchange\Application\ExchangeCreation",  DataExchangeMessagesMessageHandler, Handlers);
	AddMessageChannelHandler("DataExchange\Application\ExchangeDeletion",  DataExchangeMessagesMessageHandler, Handlers);
	AddMessageChannelHandler("DataExchange\Application\SetDataAreaPrefix", DataExchangeMessagesMessageHandler, Handlers);
	
EndProcedure

// Processes a message body according to the current message channel algorithm.
//
// Parameters:
//  MessageChannel (mandatory) - String - ID of the message channel that 
//                               delivered a message.
//  MessageBody (mandatory)    - Arbitrary - message body to be processed,
//                               which was received over the channel.
//  Sender (mandatory)         - ExchangePlanRef.MessageExchange - endpoint 
//                               that is the message sender.
//
Procedure ProcessMessage(MessageChannel, Body, From) Export
	
	SetDataArea(Body.DataArea);
	Try
		
		If MessageChannel = "DataExchange\Application\ExchangeCreation" Then
			
			CreateDataExchangeInInfobase(
									From,
									Body.Settings,
									Body.NodeFilterStructure,
									Body.NodeDefaultValues,
									Body.ThisNodeCode,
									Body.NewNodeCode);
			
		ElsIf MessageChannel = "DataExchange\Application\ExchangeDeletion" Then
			
			DeleteDataExchangeFromInfobase(From, Body.ExchangePlanName, Body.NodeCode);
			
		ElsIf MessageChannel = "DataExchange\Application\SetDataAreaPrefix" Then
			
			SetDataAreaPrefix(Body.Prefix);
			
		EndIf;
		
	Except
		CancelDataAreaSetup();
		Raise;
	EndTry;
	
	CancelDataAreaSetup();
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

// For compatibility if correspondent SL version is earlier than 2.1.2
//
Procedure CreateDataExchangeInInfobase(From, Settings, NodeFilterStructure, NodeDefaultValues, ThisNodeCode, NewNodeCode)
	
	// Creating message exchange directory (if necessary)
	Directory = New File(Settings.FILEDataExchangeDirectory);
	
	If Not Directory.Exist() Then
		
		Try
			CreateDirectory(Directory.FullName);
		Except
			
			// Sending error message to the manager application
			SendErrorCreatingExchangeMessage(Number(ThisNodeCode), Number(NewNodeCode), DetailErrorDescription(ErrorInfo()), From);
			
			WriteLogEvent(DataExchangeServer.EventLogMessageTextDataExchange(),
				EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
			Return;
		EndTry;
	EndIf;
	
	BeginTransaction();
	Try
		
		CorrespondentDataArea = Number(NewNodeCode);
		ExchangePlanName           = Settings.ExchangePlanName;
		CorrespondentCode          = DataExchangeSaaS.ExchangePlanNodeCodeInService(CorrespondentDataArea);
		CorrespondentDescription   = Settings.SecondInfobaseDescription;
		NodeFilterStructure        = New Structure;
		ThisApplicationCode        = DataExchangeCached.GetThisNodeCodeForExchangePlan(ExchangePlanName);
		ThisApplicationDescription = DataExchangeSaaS.GeneratePredefinedNodeDescription();
		
		CorrespondentEndpoint = ExchangePlans.MessageExchange.FindByCode(Settings.CorrespondentEndpoint);
		
		If CorrespondentEndpoint.IsEmpty() Then
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Correspondent endpoint with code ""%1"" is not found.'"),
				Settings.CorrespondentEndpoint);
		EndIf;
		
		Correspondent = Undefined;
		
		// Creating exchange settings in the current infobase
		DataExchangeSaaS.CreateExchangeSettings(
			ExchangePlanName,
			CorrespondentCode,
			CorrespondentDescription,
			CorrespondentEndpoint,
			NodeFilterStructure,
			Correspondent,
			,
			True);
		
		// Saving exchange message transfer settings for the current data area
		RecordStructure = New Structure;
		RecordStructure.Insert("Correspondent", Correspondent);
		RecordStructure.Insert("CorrespondentEndpoint", CorrespondentEndpoint);
		RecordStructure.Insert("DataExchangeDirectory", Settings.FILERelativeInformationExchangeDirectory);
		
		InformationRegisters.DataAreaExchangeTransportSettings.UpdateRecord(RecordStructure);
		
		// Registering all infobase data for exporting
		DataExchangeServer.RegisterDataForInitialExport(Correspondent);
		
		// Sending success message to the manager application 
		SendMessageActionSuccessful(Number(ThisNodeCode), Number(NewNodeCode), From);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		
		// Sending error message to the manager application
		SendErrorCreatingExchangeMessage(Number(ThisNodeCode), Number(NewNodeCode), DetailErrorDescription(ErrorInfo()), From);
		
		WriteLogEvent(DataExchangeServer.EventLogMessageTextDataExchange(),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		Return;
	EndTry;
	
EndProcedure

// For compatibility if correspondent SL version is earlier than 2.1.2
//
Procedure DeleteDataExchangeFromInfobase(From, ExchangePlanName, NodeCode)
	
	// Searching for node using S00000123 code format
	InfobaseNode = ExchangePlans[ExchangePlanName].FindByCode(DataExchangeSaaS.ExchangePlanNodeCodeInService(Number(NodeCode)));
	
	If InfobaseNode.IsEmpty() Then
		
		// Searching for node using 0000123 (old) code format
		InfobaseNode = ExchangePlans[ExchangePlanName].FindByCode(NodeCode);
		
	EndIf;
	
	ThisNodeCode = DataExchangeCached.GetThisNodeCodeForExchangePlan(ExchangePlanName);
	ThisNodeCode = DataExchangeServer.DataAreaNumberByExchangePlanNodeCode(ThisNodeCode);
	
	If InfobaseNode.IsEmpty() Then
		
		// Sending success message to the manager application 
		SendMessageActionSuccessful(ThisNodeCode, Number(NodeCode), From);
		
		Return; // Exchange settings not found (probably deleted)
	EndIf;
	
	// Deleting data exchange directory
	TransportSettings = InformationRegisters.DataAreaExchangeTransportSettings.TransportSettings(InfobaseNode);
	
	If TransportSettings <> Undefined
		And TransportSettings.DefaultExchangeMessageTransportKind = Enums.ExchangeMessageTransportKinds.FILE Then
		
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
		
	EndIf;
	
	// Deleting node
	Try
		InfobaseNode.GetObject().Delete();
	Except
		
		ErrorMessageString = DetailErrorDescription(ErrorInfo());
		
		// Sending error message to the manager application
		SendErrorDeletingExchangeMessage(ThisNodeCode, Number(NodeCode), ErrorMessageString, From);
		
		WriteLogEvent(DataExchangeServer.EventLogMessageTextDataExchange(),
			EventLogLevel.Error,,, ErrorMessageString);
		Return;
	EndTry;
	
	// Sending success message to the manager application 
	SendMessageActionSuccessful(ThisNodeCode, Number(NodeCode), From);
	
EndProcedure

Procedure SetDataAreaPrefix(Val Prefix)
	
	SetPrivilegedMode(True);
	
	If IsBlankString(Constants.DistributedInfobaseNodePrefix.Get()) Then
		
		Constants.DistributedInfobaseNodePrefix.Set(Format(Prefix, "ND=2; NLZ=; NG=0"));
		
	EndIf;
	
EndProcedure

Procedure SetDataArea(Val DataArea)
	
	SetPrivilegedMode(True);
	
	CommonUse.SetSessionSeparation(True, DataArea);
	
EndProcedure

Procedure CancelDataAreaSetup()
	
	SetPrivilegedMode(True);
	
	CommonUse.SetSessionSeparation(False);
	
EndProcedure

Procedure SendMessageActionSuccessful(Code1, Code2, Endpoint)
	
	BeginTransaction();
	Try
		
		Body = New Structure("Code1, Code2", Code1, Code2);
		
		MessageExchange.SendMessage("DataExchange\Application\Answer\ActionSuccessful", Body, Endpoint);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteLogEvent(EventLogMessageTextMessageSending(),
			EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
EndProcedure

Procedure SendErrorCreatingExchangeMessage(Code1, Code2, ErrorString, Endpoint)
	
	BeginTransaction();
	Try
		
		Body = New Structure("Code1, Code2, ErrorString", Code1, Code2, ErrorString);
		
		MessageExchange.SendMessage("DataExchange\Application\Answer\ErrorCreatingExchange", Body, Endpoint);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteLogEvent(EventLogMessageTextMessageSending(),
			EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
EndProcedure

Procedure SendErrorDeletingExchangeMessage(Code1, Code2, ErrorString, Endpoint)
	
	BeginTransaction();
	Try
		
		Body = New Structure("Code1, Code2, ErrorString", Code1, Code2, ErrorString);
		
		MessageExchange.SendMessage("DataExchange\Application\Answer\ErrorDeletingExchange", Body, Endpoint);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteLogEvent(EventLogMessageTextMessageSending(),
			EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
EndProcedure

Procedure AddMessageChannelHandler(Channel, ChannelHandler, Handlers)
	
	Handler = Handlers.Add();
	Handler.Channel = Channel;
	Handler.Handler = ChannelHandler;
	
EndProcedure

Function EventLogMessageTextMessageSending()
	
	Return NStr("en = 'Send messages'", CommonUseClientServer.DefaultLanguageCode());
	
EndFunction

#EndRegion
