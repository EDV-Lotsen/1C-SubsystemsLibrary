////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

////////////////////////////////////////////////////////////////////////////////
// Operation handlers.

// Corresponds to the GetConfigurationExchangePlans operation.
//
Function GetConfigurationExchangePlans()
	
	Array = New Array;
	
	For Each ExchangePlan In Metadata.ExchangePlans Do
		
		If DataExchangeServiceModeCached.ExchangePlanUsedInServiceMode(ExchangePlan.Name) Then
			
			Array.Add(ExchangePlan.Name);
			
		EndIf;
		
	EndDo;
	
	Return StringFunctionsClientServer.GetStringFromSubstringArray(Array);
	
EndFunction

// Corresponds to the ScheduleDataExchangeExecution operation.
//
Function ScheduleDataExchangeExecution(AreasForDataExchangeString)
	
	AreasForDataExchange = ValueFromStringInternal(AreasForDataExchangeString);
	
	For Each Item In AreasForDataExchange Do
		
		SeparatorValue = Item.Key;
		DataExchangeScenario = Item.Value;
		
		Parameters = New Array;
		Parameters.Add(DataExchangeScenario);
		
		Try
			JobQueue.ScheduleJobExecution(
			"DataExchangeServiceMode.ExecuteDataExchange", Parameters, "1",, SeparatorValue);
		Except
			If ErrorInfo().Description <> JobQueue.GetJobsWithSameKeyDuplicationErrorMessage() Then
				Raise;
			EndIf;
		EndTry;
		
	EndDo;
	
	Return "";
EndFunction

// Corresponds to the ExecuteDataExchangeScenarioActionInFirstInfoBase operation.
//
Function ExecuteDataExchangeScenarioActionInFirstInfoBase(ScenarioRowIndex, DataExchangeScenarioString)
	
	DataExchangeScenario = ValueFromStringInternal(DataExchangeScenarioString);
	
	ScenarioRow = DataExchangeScenario[ScenarioRowIndex];
	
	Key = ScenarioRow.ExchangePlanName + ScenarioRow.InfoBaseNodeCode;
	
	Parameters = New Array;
	Parameters.Add(ScenarioRowIndex);
	Parameters.Add(DataExchangeScenario);
	
	Try
		JobQueue.ScheduleJobExecution(
			"DataExchangeServiceMode.ExecuteDataExchangeScenarioActionInFirstInfoBase", 
			Parameters, Key,, ScenarioRow.FirstInfoBaseSeparatorValue);
	Except
		If ErrorInfo().Description <> JobQueue.GetJobsWithSameKeyDuplicationErrorMessage() Then
			Raise;
		EndIf;
	EndTry;
	
	Return "";
EndFunction

// Corresponds to the ExecuteDataExchangeScenarioActionInSecondInfoBase operation.
//
Function ExecuteDataExchangeScenarioActionInSecondInfoBase(ScenarioRowIndex, DataExchangeScenarioString)
	
	DataExchangeScenario = ValueFromStringInternal(DataExchangeScenarioString);
	
	ScenarioRow = DataExchangeScenario[ScenarioRowIndex];
	
	Key = ScenarioRow.ExchangePlanName + ScenarioRow.InfoBaseNodeCode;
	
	Parameters = New Array;
	Parameters.Add(ScenarioRowIndex);
	Parameters.Add(DataExchangeScenario);
	
	Try
		JobQueue.ScheduleJobExecution(
			"DataExchangeServiceMode.ExecuteDataExchangeScenarioActionInSecondInfoBase", 
			Parameters, Key,, ScenarioRow.SecondInfoBaseSeparatorValue);
	Except
		If ErrorInfo().Description <> JobQueue.GetJobsWithSameKeyDuplicationErrorMessage() Then
			Raise;
		EndIf;
	EndTry;
	
	Return "";
EndFunction

// Corresponds to the CheckConnection operation.
//
Function CheckConnection(SettingsStructureString, TransportKindString, ErrorMessage)
	
	Cancel = False;
	
	// Checking the exchange message transport data processor connection    
	DataExchangeServer.CheckExchangeMessageTransportDataProcessorConnection(Cancel,
			ValueFromStringInternal(SettingsStructureString),
			Enums.ExchangeMessageTransportKinds[TransportKindString],
			ErrorMessage
	);
	
	If Cancel Then
		Return False;
	EndIf;
	
	// Checking the connection to the application manager through the web service
	Try
		DataExchangeServiceModeCached.GetExchangeServiceWSProxy();
	Except
		ErrorMessage = BriefErrorDescription(ErrorInfo());
		Return False;
	EndTry;
	
	Return True;
EndFunction







