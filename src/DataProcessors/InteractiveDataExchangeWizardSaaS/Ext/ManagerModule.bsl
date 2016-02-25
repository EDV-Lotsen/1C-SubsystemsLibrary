#If Server OR ThickClientOrdinaryApplication OR ExternalConnection Then

#Region InternalInterface

// The procedure is used as the background job handler, which performs
// additional data registration and exchange.
//
// Parameters:
//         ExportDataProcessor - DataProcessorObject.InteractiveExportModification - initialized object.
//         StorageAddress      - String, UUID - Storage address, used to get the procedure result.
// 
Procedure ExchangeOnDemand(Val ExportDataProcessor, Val StorageAddress = Undefined) Export
	
	RecordExportAdditionData(ExportDataProcessor);
	
	Session = StartExchangeOnDemand(ExportDataProcessor.InfobaseNode);
	
	If StorageAddress <> Undefined Then
		PutToTempStorage(New Structure("Session", Session), StorageAddress);
	EndIf;
	
EndProcedure

// Registers additional data according to the settings.
//
// Parameters:
//         ExportDataProcessor - Structure, DataProcessorObject.InteractiveExportModification - initialized object.
//
Procedure RecordExportAdditionData(Val ExportDataProcessor)
	
	If TypeOf(ExportDataProcessor) = Type("Structure") Then
		DataProcessor = DataProcessors.InteractiveExportModification.Create();
		FillPropertyValues(DataProcessor, ExportDataProcessor, , "AdditionalRegistration, AdditionalNodeScenarioRegistration");
		DataExchangeServer.FillValueTable(DataProcessor.AdditionalRegistration, ExportDataProcessor.AdditionalRegistration);
		DataExchangeServer.FillValueTable(DataProcessor.AdditionalNodeScenarioRegistration, ExportDataProcessor.AdditionalNodeScenarioRegistration);
	Else
		DataProcessor = ExportDataProcessor;
	EndIf;
	
	If DataProcessor.ExportVariant <= 0 Then
		// No adding
		Return;
		
	ElsIf DataProcessor.ExportVariant = 1 Then
		// Period with filter, clearing additional registration
		DataProcessor.AdditionalRegistration.Clear();
		
	ElsIf DataProcessor.ExportVariant = 2 Then
		// Detailed settings, clearing general parameters
		DataProcessor.AllDocumentsFilterComposer = Undefined;
		DataProcessor.AllDocumentsFilterPeriod   = Undefined;
		
	EndIf;
	
	DataProcessor.RecordAdditionalChanges();
EndProcedure

// Starts exchange on demand.
//
// Parameters:
//         InfobaseNode - ExchangePlanRef - Reference to correspondent.
//
Function StartExchangeOnDemand(Val InfobaseNode) Export
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		Message = MessagesSaaS.NewMessage(
			MessagesDataExchangeAdministrationManagementInterface.PushSynchronizationMessage()
		);
		
		Session = InformationRegisters.SystemMessageExchangeSessions.NewSession();
		
		Message.Body.Zone      = CommonUse.SessionSeparatorValue();
		Message.Body.SessionId = Session;
		
		MessagesSaaS.SendMessage(Message, SaaSOperationsCached.ServiceManagerEndpoint(), True);
		CommitTransaction();
	Except
		RollbackTransaction();
		
		WriteLogEvent(DataExchangeSaaS.DataSyncronizationLogEvent(),,,,
			DetailErrorDescription(ErrorInfo()) 
		);
			
		Session = Undefined;
	EndTry;
	
	If Session<>Undefined Then
		MessagesSaaS.DeliverQuickMessages();
	EndIf;
	
	Return Session;
EndFunction

#EndRegion

#EndIf