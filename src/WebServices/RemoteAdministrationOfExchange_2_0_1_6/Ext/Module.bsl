
#Region InternalProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Web service operation handlers

// Matches the GetExchangePlans web service operation.
Function GetConfigurationExchangePlans()
	
	Return StringFunctionsClientServer.StringFromSubstringArray(
		DataExchangeSaaSCached.DataSynchronizationExchangePlans());
EndFunction

// Matches the PrepareExchangeExecution web service operation.
Function ScheduleDataExchangeExecution(DataExchangeAreasXDTO)
	
	AreasForDataExchange = XDTOSerializer.ReadXDTO(DataExchangeAreasXDTO);
	
	SetPrivilegedMode(True);
	
	For Each Item In AreasForDataExchange Do
		
		SeparatorValue = Item.Key;
		DataExchangeScenario = Item.Value;
		
		Parameters = New Array;
		Parameters.Add(DataExchangeScenario);
		
		JobParameters = New Structure;
		JobParameters.Insert("MethodName"    , "DataExchangeSaaS.ExecuteDataExchange");
		JobParameters.Insert("Parameters"    , Parameters);
		JobParameters.Insert("Key"         , "1");
		JobParameters.Insert("DataArea", SeparatorValue);
		
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
Function ExecuteDataExchangeScenarioActionInFirstInfobase(ScenarioRowIndex, DataExchangeScenarioXDTO)
	
	DataExchangeScenario = XDTOSerializer.ReadXDTO(DataExchangeScenarioXDTO);
	
	ScenarioString = DataExchangeScenario[ScenarioRowIndex];
	
	Key = ScenarioString.ExchangePlanName + ScenarioString.InfobaseNodeCode + ScenarioString.ThisNodeCode;
	
	ExchangeMode = DataExchangeMode(DataExchangeScenario);
	
	If ExchangeMode = "Manual" Then
		
		Parameters = New Array;
		Parameters.Add(ScenarioRowIndex);
		Parameters.Add(DataExchangeScenario);
		Parameters.Add(ScenarioString.FirstInfobaseSeparatorValue);
		
		BackgroundJobs.Execute("DataExchangeSaaS.ExecuteDataExchangeScenarioActionInFirstInfobaseFromSharedSession",
			Parameters,
			Key
		);
	ElsIf ExchangeMode = "Automatic" Then
		
		Try
			Parameters = New Array;
			Parameters.Add(ScenarioRowIndex);
			Parameters.Add(DataExchangeScenario);
			
			JobParameters = New Structure;
			JobParameters.Insert("DataArea", ScenarioString.FirstInfobaseSeparatorValue);
			JobParameters.Insert("MethodName", "DataExchangeSaaS.ExecuteDataExchangeScenarioActionInFirstInfobase");
			JobParameters.Insert("Parameters", Parameters);
			JobParameters.Insert("Key", Key);
			JobParameters.Insert("Use", True);
			
			SetPrivilegedMode(True);
			JobQueue.AddJob(JobParameters);
		Except
			If ErrorInfo().Details <> JobQueue.GetJobsWithSameKeyDuplicationErrorMessage() Then
				Raise;
			EndIf;
		EndTry;
		
	Else
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Unknown data exchange mode: %1'"), String(ExchangeMode)
		);
	EndIf;
	
	Return "";
EndFunction

// Matches the StartExchangeExecutionInSecondDataBase web service operation.
Function ExecuteDataExchangeScenarioActionInSecondInfobase(ScenarioRowIndex, DataExchangeScenarioXDTO)
	
	DataExchangeScenario = XDTOSerializer.ReadXDTO(DataExchangeScenarioXDTO);
	
	ScenarioString = DataExchangeScenario[ScenarioRowIndex];
	
	Key = ScenarioString.ExchangePlanName + ScenarioString.InfobaseNodeCode + ScenarioString.ThisNodeCode;
	
	ExchangeMode = DataExchangeMode(DataExchangeScenario);
	
	If ExchangeMode = "Manual" Then
		
		Parameters = New Array;
		Parameters.Add(ScenarioRowIndex);
		Parameters.Add(DataExchangeScenario);
		Parameters.Add(ScenarioString.SecondInfobaseSeparatorValue);
		
		BackgroundJobs.Execute("DataExchangeSaaS.ExecuteDataExchangeScenarioActionInSecondInfobaseFromSharedSession",
			Parameters,
			Key
		);
		
	ElsIf ExchangeMode = "Automatic" Then
		
		Try
			Parameters = New Array;
			Parameters.Add(ScenarioRowIndex);
			Parameters.Add(DataExchangeScenario);
			
			JobParameters = New Structure;
			JobParameters.Insert("DataArea", ScenarioString.SecondInfobaseSeparatorValue);
			JobParameters.Insert("MethodName", "DataExchangeSaaS.ExecuteDataExchangeScenarioActionInSecondInfobase");
			JobParameters.Insert("Parameters", Parameters);
			JobParameters.Insert("Key", Key);
			JobParameters.Insert("Use", True);
			
			SetPrivilegedMode(True);
			JobQueue.AddJob(JobParameters);
		Except
			If ErrorInfo().Details <> JobQueue.GetJobsWithSameKeyDuplicationErrorMessage() Then
				Raise;
			EndIf;
		EndTry;
		
	Else
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Unknown data exchange mode: %1'"), String(ExchangeMode)
		);
	EndIf;
	
	Return "";
EndFunction

// Matches the TestConnection web service operation.
Function TestConnection(SettingsStructureXTDO, TransportKindString, ErrorMessage)
	
	Cancel = False;
	
	// Testing the exchange message transport data processor connection
	DataExchangeServer.TestExchangeMessageTransportDataProcessorConnection(Cancel,
			XDTOSerializer.ReadXDTO(SettingsStructureXTDO),
			Enums.ExchangeMessageTransportKinds[TransportKindString],
			ErrorMessage);
	
	If Cancel Then
		Return False;
	EndIf;
	
	Return True;
EndFunction

// Matches the Ping web service operation.
Function Ping()
	
	// A stub used to prevent a configuration check error.
	Return Undefined;
	
EndFunction


Function DataExchangeMode(DataExchangeScenario)
	
	Result = "Manual";
	
	If DataExchangeScenario.Columns.Find("Mode") <> Undefined Then
		Result = DataExchangeScenario[0].Mode;
	EndIf;
	
	Return Result;
EndFunction

#EndRegion
