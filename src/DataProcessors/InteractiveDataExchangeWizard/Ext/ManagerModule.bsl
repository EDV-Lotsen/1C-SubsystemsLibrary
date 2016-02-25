#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

Procedure ExecuteAutomaticDataMapping(Parameters, TempStorageAddress) Export
	
	PutToTempStorage(
		AutomaticDataMappingResult(Parameters.InfobaseNode, Parameters.ExchangeMessageFileName, Parameters.TempExchangeMessageDirectory,
		Parameters.CheckVersionDifference), TempStorageAddress);
		
EndProcedure

Function AutomaticDataMappingResult(Val Correspondent, Val ExchangeMessageFileName,
	Val TempExchangeMessageDirectory, CheckVersionDifference) Export
	
 // Mapping data received from a correspondent.
 // Getting mapping statistics.
	
	SetPrivilegedMode(True);
	
	DataExchangeServer.InitializeVersionDifferenceCheckParameters(CheckVersionDifference);
	
	InteractiveDataExchangeWizard = DataProcessors.InteractiveDataExchangeWizard.Create();
	InteractiveDataExchangeWizard.InfobaseNode = Correspondent;
	InteractiveDataExchangeWizard.ExchangeMessageFileName = ExchangeMessageFileName;
	InteractiveDataExchangeWizard.TempExchangeMessageDirectory = TempExchangeMessageDirectory;
	InteractiveDataExchangeWizard.ExchangePlanName = DataExchangeCached.GetExchangePlanName(Correspondent);
	InteractiveDataExchangeWizard.ExchangeMessageTransportKind = Undefined;
	
	// Analyzing exchange messages
	Cancel = False;
	InteractiveDataExchangeWizard.ExecuteExchangeMessagAnalysis(Cancel);
	If Cancel Then
		If SessionParameters.VersionDifferenceErrorOnGetData.HasError Then
			Return SessionParameters.VersionDifferenceErrorOnGetData;
		Else
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Errors occurred when analyzing exchange message for correspondent %1.'"),
				String(Correspondent));
		EndIf;
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
	
	Result = New Structure;
	Result.Insert("Statistics",      StatisticsTable);
	Result.Insert("AllDataMapped",   AllDataMapped(StatisticsTable));
	Result.Insert("StatisticsEmpty", StatisticsTable.Count() = 0);
	
	Return Result;
EndFunction

Procedure ExecuteDataImport(Parameters, TempStorageAddress) Export
	
	DataExchangeServer.ExecuteDataExchangeForInfobaseNodeOverFileOrString(
		Parameters.InfobaseNode,
		Parameters.ExchangeMessageFileName,
		Enums.ActionsOnExchange.DataImport
	);
EndProcedure

Function AllDataMapped(Statistics) Export
	
	Return (Statistics.FindRows(New Structure("PictureIndex", 1)).Count() = 0);
	
EndFunction

#EndIf
