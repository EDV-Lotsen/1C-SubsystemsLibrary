#If Server OR ThickClientOrdinaryApplication OR ExternalConnection Then


Procedure SetUpExchangeStep1(Parameters, TempStorageAddress) Export
	
	ExchangePlanName         = Parameters.ExchangePlanName;
	CorrespondentCode        = Parameters.CorrespondentCode;
	CorrespondentDescription = Parameters.CorrespondentDescription;
	CorrespondentDataArea    = Parameters.CorrespondentDataArea;
	CorrespondentEndpoint    = Parameters.CorrespondentEndpoint;
	NodeFilterStructure      = Parameters.NodeFilterStructure;
	Prefix                   = Parameters.Prefix;
	CorrespondentPrefix      = Parameters.CorrespondentPrefix;
	
	SetPrivilegedMode(True);
	
	ThisApplicationCode = DataExchangeCached.GetThisNodeCodeForExchangePlan(ExchangePlanName);
	ThisApplicationDescription = DataExchangeSaaS.GeneratePredefinedNodeDescription();
	
	BeginTransaction();
	Try
		
		Correspondent = Undefined;
		
		// Creating exchange settings in the current infobase
		DataExchangeSaaS.CreateExchangeSettings(
			ExchangePlanName,
			CorrespondentCode,
			CorrespondentDescription,
			CorrespondentEndpoint,
			NodeFilterStructure.NodeFilterStructure,
			Correspondent,
			,
			,
			Prefix);
		
		// Registering catalogs to be exported from this infobase
		DataExchangeServer.RegisterOnlyCatalogsForInitialExport(Correspondent);
		
		// {Handler: OnSendSenderData} Beginning
		ExchangePlans[ExchangePlanName].OnSendSenderData(NodeFilterStructure.NodeFilterStructure, False);
		// {Handler: OnSendSenderData} End
		
		// Sending message to a correspondent
		Message = MessagesSaaS.NewMessage(
			DataExchangeMessagesManagementInterface.SetUpExchangeStep1Message());
		Message.Body.CorrespondentZone = CorrespondentDataArea;
		
		Message.Body.ExchangePlan = ExchangePlanName;
		Message.Body.CorrespondentCode = ThisApplicationCode;
		Message.Body.CorrespondentName = ThisApplicationDescription;
		Message.Body.FilterSettings = XDTOSerializer.WriteXDTO(NodeFilterStructure.CorrespondentInfobaseNodeFilterSetup);
		Message.Body.Code = CommonUse.ObjectAttributeValue(Correspondent, "Code");
		Message.Body.Endpoint = MessageExchangeInternal.ThisNodeCode();
		Message.AdditionalInfo = XDTOSerializer.WriteXDTO(New Structure("Prefix", CorrespondentPrefix));
		
		Session = DataExchangeSaaS.SendMessage(Message);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	MessagesSaaS.DeliverQuickMessages();
	
	IncomingParameters = New Structure("Correspondent, Session", Correspondent, Session);
	PutToTempStorage(IncomingParameters, TempStorageAddress);
	
EndProcedure

Procedure SetUpExchangeStep2(Parameters, TempStorageAddress) Export
	
	Correspondent = Parameters.Correspondent;
	CorrespondentDataArea = Parameters.CorrespondentDataArea;
	NodeDefaultValues = Parameters.NodeDefaultValues;
	CorrespondentInfobaseNodeDefaultValues = Parameters.CorrespondentInfobaseNodeDefaultValues;
	
	SetPrivilegedMode(True);
	
	ExchangePlanName = DataExchangeCached.GetExchangePlanName(Correspondent);
	ThisApplicationCode = DataExchangeCached.GetThisNodeCodeForExchangePlan(ExchangePlanName);
	
	BeginTransaction();
	Try
		
		// Saving settings specified by user
		DataExchangeSaaS.UpdateExchangeSettings(Correspondent, NodeDefaultValues);
		
		// Registering all infobase data for exporting, except catalogs
		DataExchangeServer.RegisterAllDataExceptCatalogsForInitialExport(Correspondent);
		
		// Sending message to a correspondent
		Message = MessagesSaaS.NewMessage(
			DataExchangeMessagesManagementInterface.SetUpExchangeStep2Message());
		Message.Body.CorrespondentZone = CorrespondentDataArea;
		
		Message.Body.ExchangePlan = ExchangePlanName;
		Message.Body.CorrespondentCode = ThisApplicationCode;
		Message.Body.AdditionalSettings = XDTOSerializer.WriteXDTO(CorrespondentInfobaseNodeDefaultValues);
		
		Session = DataExchangeSaaS.SendMessage(Message);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	MessagesSaaS.DeliverQuickMessages();
	
	IncomingParameters = New Structure("Session", Session);
	PutToTempStorage(IncomingParameters, TempStorageAddress);
	
EndProcedure

Procedure ExecuteAutomaticDataMapping(Parameters, TempStorageAddress) Export
	
	// Mapping data received from a correspondent
	// Getting mapping statistics
	Correspondent = Parameters.Correspondent;
	
	SetPrivilegedMode(True);
	
	// Storing exchange message to a temporary directory
	Cancel = False;
	MessageParameters = DataExchangeServer.GetExchangeMessageToTemporaryDirectory(
		Cancel, Correspondent, Undefined);
	If Cancel Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Errors occurred when getting exchange message for correspondent %1 from an external resource.'"),
			String(Correspondent));
	EndIf;
	
	InteractiveDataExchangeWizard = DataProcessors.InteractiveDataExchangeWizard.Create();
	InteractiveDataExchangeWizard.InfobaseNode = Correspondent;
	InteractiveDataExchangeWizard.ExchangeMessageFileName = MessageParameters.ExchangeMessageFileName;
	InteractiveDataExchangeWizard.TempExchangeMessageDirectory = MessageParameters.TempExchangeMessageDirectory;
	InteractiveDataExchangeWizard.ExchangePlanName = DataExchangeCached.GetExchangePlanName(Correspondent);
	InteractiveDataExchangeWizard.ExchangeMessageTransportKind = Undefined;
	
	// Analyzing exchange messages
	Cancel = False;
	InteractiveDataExchangeWizard.ExecuteExchangeMessagAnalysis(Cancel);
	If Cancel Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Errors occurred when analyzing exchange message for correspondent %1.'"),
			String(Correspondent));
	EndIf;
	
	// Mapping data and getting statistics
	Cancel = False;
	InteractiveDataExchangeWizard.ExecuteDefaultAutomaticMappingAndGetMappingStatistics(Cancel);
	If Cancel Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Errors occurred when mapping data received from correspondent %1.'"),
			String(Correspondent));
	EndIf;
	
	StatisticsTable = InteractiveDataExchangeWizard.StatisticsTable();
	
  // Deleting rows that do not have a mapping to the current infobase or to
  // the correspondent infobase from a statistics table.
	// Also deleting rows where data synchronization by reference IDs is not supported.
	DeleteEmptyDataFromStatistics(StatisticsTable);
	
	AllDataMapped = (StatisticsTable.FindRows(New Structure("PictureIndex", 1)).Count() = 0);
	
	IncomingParameters = New Structure("Statistics, AllDataMapped, ExchangeMessageFileName, StatisticsEmpty",
		StatisticsTable, AllDataMapped, MessageParameters.ExchangeMessageFileName, StatisticsTable.Count() = 0);
	PutToTempStorage(IncomingParameters, TempStorageAddress);
	
EndProcedure

Procedure PerformCatalogSynchronization(Parameters, TempStorageAddress) Export
	
	Correspondent = Parameters.Correspondent;
	CorrespondentDataArea = Parameters.CorrespondentDataArea;
	
	SetPrivilegedMode(True);
	
	ExchangePlanName = DataExchangeCached.GetExchangePlanName(Correspondent);
	ThisApplicationCode = DataExchangeCached.GetThisNodeCodeForExchangePlan(ExchangePlanName);
	
	// Importing correspondent exchange message
	Cancel = False;
	DataExchangeSaaS.ExecuteDataImport(Cancel, Correspondent);
	If Cancel Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = Errors occurred when importing catalogs from correspondent %1.'"),
			String(Correspondent));
	EndIf;
	
	// Exporting data exchange message for correspondent (catalogs only)
	Cancel = False;
	DataExchangeSaaS.ExecuteDataExport(Cancel, Correspondent);
	If Cancel Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Errors occurred when exporting catalogs for correspondent %1.'"),
			String(Correspondent));
	EndIf;
	
	// Sending message to a correspondent
	Message = MessagesSaaS.NewMessage(
		DataExchangeMessagesManagementInterface.ImportExchangeMessageMessage());
	Message.Body.CorrespondentZone = CorrespondentDataArea;
	
	Message.Body.ExchangePlan = ExchangePlanName;
	Message.Body.CorrespondentCode = ThisApplicationCode;
	
	BeginTransaction();
	Session = DataExchangeSaaS.SendMessage(Message);
	CommitTransaction();
	
	MessagesSaaS.DeliverQuickMessages();
	
	IncomingParameters = New Structure("Session", Session);
	PutToTempStorage(IncomingParameters, TempStorageAddress);
	
EndProcedure

Procedure GetMappingStatistics(Parameters, TempStorageAddress) Export
	
	// Parameters.Correspondent
	// Parameters.ExchangeMessageFileName
	// Parameters.Statistics
	// Parameters.RowIndexes
	
	// Getting mapping statistics for the specified data types
	SetPrivilegedMode(True);
	
	InteractiveDataExchangeWizard = DataProcessors.InteractiveDataExchangeWizard.Create();
	InteractiveDataExchangeWizard.InfobaseNode = Parameters.Correspondent;
	InteractiveDataExchangeWizard.ExchangeMessageFileName = Parameters.ExchangeMessageFileName;
	InteractiveDataExchangeWizard.TempExchangeMessageDirectory = "";
	InteractiveDataExchangeWizard.ExchangePlanName = DataExchangeCached.GetExchangePlanName(Parameters.Correspondent);
	InteractiveDataExchangeWizard.ExchangeMessageTransportKind = Undefined;
	
	InteractiveDataExchangeWizard.Statistics.Load(Parameters.Statistics);
	
	Cancel = False;
	InteractiveDataExchangeWizard.GetObjectMappingByRowStats(Cancel, Parameters.RowIndexes);
	If Cancel Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Errors occurred when getting statistics for correspondent %1.'"),
			String(Parameters.Correspondent));
	EndIf;
	
	AllDataMapped = (InteractiveDataExchangeWizard.StatisticsTable().FindRows(New Structure("PictureIndex", 1)).Count() = 0);
	
	IncomingParameters = New Structure("Statistics, AllDataMapped",
		InteractiveDataExchangeWizard.StatisticsTable(), AllDataMapped);
	PutToTempStorage(IncomingParameters, TempStorageAddress);
	
EndProcedure

Procedure DeleteEmptyDataFromStatistics(StatisticsTable)
	
	ReverseIndex = StatisticsTable.Count() - 1;
	
	While ReverseIndex >= 0 Do
		
		Statistics = StatisticsTable[ReverseIndex];
		
		If Statistics.ObjectCountInSource = 0
			OR Statistics.ObjectCountInTarget = 0
			OR Not Statistics.SynchronizeByID Then
			
			StatisticsTable.Delete(Statistics);
			
		EndIf;
		
		ReverseIndex = ReverseIndex - 1;
	EndDo;
	
EndProcedure

#EndIf
