
#Region InternalProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Web service operation handlers.

// Matches the GetExchangePlans web service operation.
Function GetConfigurationExchangePlans()
	
	Return StringFunctionsClientServer.StringFromSubstringArray(
		DataExchangeSaaSCached.DataSynchronizationExchangePlans());
EndFunction

// Matches the PrepareExchangeExecution web service operation.
Function ScheduleDataExchangeExecution(AreasForDataExchangeString)
	
	AreasForDataExchange = ValueFromStringInternal(AreasForDataExchangeString);
	
	SetPrivilegedMode(True);
	
	For Each Item In AreasForDataExchange Do
		
		SeparatorValue       = Item.Key;
		DataExchangeScenario = Item.Value;
		
		Parameters = New Array;
		Parameters.Add(DataExchangeScenario);
		
		JobParameters = New Structure;
		JobParameters.Insert("MethodName", "DataExchangeSaaS.ExecuteDataExchange");
		JobParameters.Insert("Parameters", Parameters);
		JobParameters.Insert("Key",        "1");
		JobParameters.Insert("DataArea",   SeparatorValue);
		
		Try
			JobQueue.AddJob(JobParameters);
		Except
			If ErrorInfo().Details <> JobQueue.GetJobsWithSameKeyDuplicationErrorMessage() Then
				Raise;
			EndIf;
		EndTry;
		
	EndDo;
	
	Return "";
EndFunction

// Matches the StartExchangeExecutionInFirstDataBase web service operation.
Function ExecuteDataExchangeScenarioActionInFirstInfobase(ScenarioRowIndex, DataExchangeScenarioString)
	
	DataExchangeScenario = ValueFromStringInternal(DataExchangeScenarioString);
	
	ScenarioString = DataExchangeScenario[ScenarioRowIndex];
	
	_Key = ScenarioString.ExchangePlanName + ScenarioString.InfobaseNodeCode + ScenarioString.ThisNodeCode;
	
	Parameters = New Array;
	Parameters.Add(ScenarioRowIndex);
	Parameters.Add(DataExchangeScenario);
	
	JobParameters = New Structure;
	JobParameters.Insert("MethodName", "DataExchangeSaaS.ExecuteDataExchangeScenarioActionInFirstInfobase");
	JobParameters.Insert("Parameters", Parameters);
	JobParameters.Insert("Key",        _Key);
	JobParameters.Insert("DataArea",   ScenarioString.FirstInfobaseSeparatorValue);
	
	Try
		SetPrivilegedMode(True);
		JobQueue.AddJob(JobParameters);
	Except
		If ErrorInfo().Details <> JobQueue.GetJobsWithSameKeyDuplicationErrorMessage() Then
			Raise;
		EndIf;
	EndTry;
	
	Return "";
EndFunction

// Matches the StartExchangeExecutionInSecondDataBase web service operation.
Function ExecuteDataExchangeScenarioActionInSecondInfobase(ScenarioRowIndex, DataExchangeScenarioString)
	
	DataExchangeScenario = ValueFromStringInternal(DataExchangeScenarioString);
	
	ScenarioString = DataExchangeScenario[ScenarioRowIndex];
	
	_Key = ScenarioString.ExchangePlanName + ScenarioString.InfobaseNodeCode + ScenarioString.ThisNodeCode;
	
	Parameters = New Array;
	Parameters.Add(ScenarioRowIndex);
	Parameters.Add(DataExchangeScenario);
	
	JobParameters = New Structure;
	JobParameters.Insert("MethodName", "DataExchangeSaaS.ExecuteDataExchangeScenarioActionInSecondInfobase");
	JobParameters.Insert("Parameters", Parameters);
	JobParameters.Insert("Key",        _Key);
	JobParameters.Insert("DataArea",   ScenarioString.SecondInfobaseSeparatorValue);
	
	Try
		SetPrivilegedMode(True);
		JobQueue.AddJob(JobParameters);
	Except
		If ErrorInfo().Details <> JobQueue.GetJobsWithSameKeyDuplicationErrorMessage() Then
			Raise;
		EndIf;
	EndTry;
	
	Return "";
	
EndFunction

// Matches the TestConnection web service operation.
Function TestConnection(SettingsStructureString, TransportKindString, ErrorMessage)
	
	Cancel = False;
	
	// Testing exchange message transport data processor connection
	DataExchangeServer.TestExchangeMessageTransportDataProcessorConnection(Cancel,
			MessageExchangeInternal.ConvertTransportSettingsStructure(ValueFromStringInternal(SettingsStructureString)),
			Enums.ExchangeMessageTransportKinds[TransportKindString],
			ErrorMessage);
	
	If Cancel Then
		Return False;
	EndIf;
	
	// Checking the connection to the manager application through the web service
	Try
		DataExchangeSaaSCached.GetExchangeServiceWSProxy();
	Except
		ErrorMessage = BriefErrorDescription(ErrorInfo());
		Return False;
	EndTry;
	
	Return True;
EndFunction

#EndRegion
