#If Server OR ThickClientOrdinaryApplication OR ExternalConnection Then


// Updates a register record based on the passed structure values
//
Procedure UpdateRecord(RecordStructure) Export
	
	DataExchangeServer.UpdateInformationRegisterRecord(RecordStructure, "DataAreasExchangeTransportSettings");
	
EndProcedure


Function TransportSettings(Val CorrespondentEndpoint) Export
	
	QueryText =
	"SELECT
	|	DataAreasExchangeTransportSettings.FILEDataExchangeDirectory,
	|	DataAreasExchangeTransportSettings.FILECompressOutgoingMessageFile,
	|	DataAreasExchangeTransportSettings.FTPCompressOutgoingMessageFile,
	|	DataAreasExchangeTransportSettings.FTPConnectionMaxMessageSize,
	|	DataAreasExchangeTransportSettings.FTPConnectionPassword,
	|	DataAreasExchangeTransportSettings.FTPConnectionPassiveConnection,
	|	DataAreasExchangeTransportSettings.FTPConnectionUser,
	|	DataAreasExchangeTransportSettings.FTPConnectionPort,
	|	DataAreasExchangeTransportSettings.FTPConnectionPath,
	|	DataAreasExchangeTransportSettings.DefaultExchangeMessageTransportKind,
	|	DataAreasExchangeTransportSettings.ExchangeMessageArchivePassword
	|FROM
	|	InformationRegister.DataAreasExchangeTransportSettings AS DataAreasExchangeTransportSettings
	|WHERE
	|	DataAreasExchangeTransportSettings.CorrespondentEndpoint = &CorrespondentEndpoint";
	
	Query = New Query;
	Query.SetParameter("CorrespondentEndpoint", CorrespondentEndpoint);
	Query.Text = QueryText;
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Connection settings for the endpoint %1 are not set.'"),
			String(CorrespondentEndpoint));
	EndIf;
	
	Result = DataExchangeServer.QueryResultToStructure(QueryResult);
	
	If Result.DefaultExchangeMessageTransportKind = Enums.ExchangeMessageTransportKinds.FTP Then
		
		FTPParameters = DataExchangeServer.FTPServerNameAndPath(Result.FTPConnectionPath);
		
		Result.Insert("FTPServer", FTPParameters.Server);
		Result.Insert("FTPPath",   FTPParameters.Path);
	Else
		Result.Insert("FTPServer", "");
		Result.Insert("FTPPath",   "");
	EndIf;
	
	DataExchangeServer.AddTransactionItemCountToTransportSettings(Result);
	
	Return Result;
	
EndFunction

#EndIf