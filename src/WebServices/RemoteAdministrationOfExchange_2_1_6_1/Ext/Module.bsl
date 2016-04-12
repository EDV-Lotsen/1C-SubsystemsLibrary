
#Region InternalProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Web service operation handlers

// Matches the GetExchangeFeatures web service operation.
Function GetConfigurationExchangePlans()
	
	Result = XDTOFactory.Create(XDTOFactory.Type("http://www.1c.ru/SaaS/ExchangeAdministration/Common", "ExchangeFeatures"));
	ExchangeFeatureType = XDTOFactory.Type("http://www.1c.ru/SaaS/ExchangeAdministration/Common", "ExchangeFeature");
	
	For Each ExchangePlanName In DataExchangeSaaSCached.DataSynchronizationExchangePlans() Do
		
		ExchangeFeature = XDTOFactory.Create(ExchangeFeatureType);
		ExchangeFeature.ExchangePlan = ExchangePlanName;
		ExchangeFeature.ExchangeRole = TrimAll(ExchangePlans[ExchangePlanName].SourceConfigurationName());
		
		If IsBlankString(ExchangeFeature.ExchangeRole) Then
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Return value of the SourceConfigurationName() function is not specified. This function is located in the manager module of the %1 exchange plan.'"),
				ExchangePlanName
			);
		EndIf;
		
		Result.Feature.Add(ExchangeFeature);
		
	EndDo;
	
	Return Result;
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
Function ExecuteDataExchangeScenarioActionInFirstInfobase(ScenarioRowIndex, DataExchangeScenarioXDTO)
	
	DataExchangeScenario = XDTOSerializer.ReadXDTO(DataExchangeScenarioXDTO);
	
	ScenarioString = DataExchangeScenario[ScenarioRowIndex];
	
	_Key = ScenarioString.ExchangePlanName + ScenarioString.InfobaseNodeCode + ScenarioString.ThisNodeCode;
	
	ExchangeMode = DataExchangeMode(DataExchangeScenario);
	
	If ExchangeMode = "Manual" Then
		
		Parameters = New Array;
		Parameters.Add(ScenarioRowIndex);
		Parameters.Add(DataExchangeScenario);
		Parameters.Add(ScenarioString.FirstInfobaseSeparatorValue);
		
		BackgroundJobs.Execute("DataExchangeSaaS.ExecuteDataExchangeScenarioActionInFirstInfobaseFromSharedSession",
			Parameters,
			_Key
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
			JobParameters.Insert("Key", _Key);
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
	
	_Key = ScenarioString.ExchangePlanName + ScenarioString.InfobaseNodeCode + ScenarioString.ThisNodeCode;
	
	ExchangeMode = DataExchangeMode(DataExchangeScenario);
	
	If ExchangeMode = "Manual" Then
		
		Parameters = New Array;
		Parameters.Add(ScenarioRowIndex);
		Parameters.Add(DataExchangeScenario);
		Parameters.Add(ScenarioString.SecondInfobaseSeparatorValue);
		
		BackgroundJobs.Execute("DataExchangeSaaS.ExecuteDataExchangeScenarioActionInSecondInfobaseFromSharedSession",
			Parameters,
			_Key
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
			JobParameters.Insert("Key", _Key);
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
	
	// Stub. A stub used to prevent a configuration check error.
	Stub = True;
	
EndFunction

//

Function DataExchangeMode(DataExchangeScenario)
	
	Result = "Manual";
	
	If DataExchangeScenario.Columns.Find("Mode") <> Undefined Then
		Result = DataExchangeScenario[0].Mode;
	EndIf;
	
	Return Result;
EndFunction

#EndRegion
