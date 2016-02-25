#If Server OR ThickClientOrdinaryApplication OR ExternalConnection Then

#Region InternalProceduresAndFunctions

Function AbsoluteDataExchangeDirectory(Val Correspondent) Export
	
	QueryText =
	"SELECT
	|	DataAreaExchangeTransportSettings.DataExchangeDirectory AS RelativeDataExchangeDirectory,
	|	ISNULL(DataAreasExchangeTransportSettings.FILEDataExchangeDirectory, """") AS CommonDataExchangeDirectory
	|FROM
	|	InformationRegister.DataAreaExchangeTransportSettings AS DataAreaExchangeTransportSettings
	|		LEFT JOIN InformationRegister.DataAreasExchangeTransportSettings AS DataAreasExchangeTransportSettings
	|		ON (DataAreasExchangeTransportSettings.CorrespondentEndpoint = DataAreaExchangeTransportSettings.CorrespondentEndpoint)
	|WHERE
	|	DataAreaExchangeTransportSettings.Correspondent = &Correspondent";
	
	Query = New Query;
	Query.SetParameter("Correspondent", Correspondent);
	Query.Text = QueryText;
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Connection settings for correspondent %1 are not set.'"), String(Correspondent));
	EndIf;
	
	Selection = QueryResult.Select();
	Selection.Next();
	
	CommonDataExchangeDirectory = Selection.CommonDataExchangeDirectory;
	RelativeDataExchangeDirectory = Selection.RelativeDataExchangeDirectory;
	
	If IsBlankString(CommonDataExchangeDirectory)
		Or IsBlankString(RelativeDataExchangeDirectory) Then
		
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Connection settings for correspondent %1 are not set.'"), String(Correspondent));
	EndIf;
	
	Return CommonUseClientServer.GetFullFileName(CommonDataExchangeDirectory, RelativeDataExchangeDirectory);
EndFunction

Function TransportKind(Val Correspondent) Export
	
	QueryText =
	"SELECT
	|	ISNULL(DataAreasExchangeTransportSettings.DefaultExchangeMessageTransportKind, UNDEFINED) AS TransportKind
	|FROM
	|	InformationRegister.DataAreaExchangeTransportSettings AS DataAreaExchangeTransportSettings
	|		LEFT JOIN InformationRegister.DataAreasExchangeTransportSettings AS DataAreasExchangeTransportSettings
	|		ON (DataAreasExchangeTransportSettings.CorrespondentEndpoint = DataAreaExchangeTransportSettings.CorrespondentEndpoint)
	|WHERE
	|	DataAreaExchangeTransportSettings.Correspondent = &Correspondent";
	
	Query = New Query;
	Query.SetParameter("Correspondent", Correspondent);
	Query.Text = QueryText;
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return Undefined;
	EndIf;
	
	Selection = QueryResult.Select();
	Selection.Next();
	
	Return Selection.TransportKind;
EndFunction

Function TransportSettings(Val Correspondent) Export
	
	QueryText =
	"SELECT
	|	"""" AS FILEDataExchangeDirectory,
	|	"""" AS FTPConnectionPath,
	|	
	|	DataAreaExchangeTransportSettings.DataExchangeDirectory AS RelativeDataExchangeDirectory,
	|	
	|	DataAreasExchangeTransportSettings.FILEDataExchangeDirectory AS FILECommonDataExchangeDirectory,
	|	DataAreasExchangeTransportSettings.FILECompressOutgoingMessageFile,
	|	
	|	DataAreasExchangeTransportSettings.FTPConnectionPath AS FTPCommonDataExchangeDirectory,
	|	DataAreasExchangeTransportSettings.FTPCompressOutgoingMessageFile,
	|	DataAreasExchangeTransportSettings.FTPConnectionMaxMessageSize,
	|	DataAreasExchangeTransportSettings.FTPConnectionPassword,
	|	DataAreasExchangeTransportSettings.FTPConnectionPassiveConnection,
	|	DataAreasExchangeTransportSettings.FTPConnectionUser,
	|	DataAreasExchangeTransportSettings.FTPConnectionPort,
	|	
	|	DataAreasExchangeTransportSettings.DefaultExchangeMessageTransportKind,
	|	DataAreasExchangeTransportSettings.ExchangeMessageArchivePassword,
	|	
	|	ExchangeTransportSettings.WSURL,
	|	ExchangeTransportSettings.WSUserName,
	|	ExchangeTransportSettings.WSPassword
	|	
	|FROM
	|	InformationRegister.DataAreaExchangeTransportSettings AS DataAreaExchangeTransportSettings
	|		LEFT JOIN InformationRegister.DataAreasExchangeTransportSettings AS DataAreasExchangeTransportSettings
	|		ON (DataAreasExchangeTransportSettings.CorrespondentEndpoint = DataAreaExchangeTransportSettings.CorrespondentEndpoint)
	|		
	|		LEFT JOIN InformationRegister.ExchangeTransportSettings AS ExchangeTransportSettings
	|		ON (ExchangeTransportSettings.Node = DataAreaExchangeTransportSettings.CorrespondentEndpoint)
	|WHERE
	|	DataAreaExchangeTransportSettings.Correspondent = &Correspondent";
	
	Query = New Query;
	Query.SetParameter("Correspondent", Correspondent);
	Query.Text = QueryText;
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return Undefined;
	EndIf;
	
	Result = DataExchangeServer.QueryResultToStructure(QueryResult);
	
	Result.FILEDataExchangeDirectory = CommonUseClientServer.GetFullFileName(
		Result.FILECommonDataExchangeDirectory,
		Result.RelativeDataExchangeDirectory);
	
	Result.FTPConnectionPath = CommonUseClientServer.GetFullFileName(
		Result.FTPCommonDataExchangeDirectory,
		Result.RelativeDataExchangeDirectory);
	
	Result.Insert("UseTempDirectoryForSendingAndReceivingMessages", True);
	
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

Function TransportSettingsWS(Val Correspondent) Export
	
	QueryText =
	"SELECT
	|	ExchangeTransportSettings.WSURL,
	|	ExchangeTransportSettings.WSUserName,
	|	ExchangeTransportSettings.WSPassword
	|FROM
	|	InformationRegister.DataAreaExchangeTransportSettings AS DataAreaExchangeTransportSettings
	|		LEFT JOIN InformationRegister.ExchangeTransportSettings AS ExchangeTransportSettings
	|		ON (ExchangeTransportSettings.Node = DataAreaExchangeTransportSettings.CorrespondentEndpoint)
	|WHERE
	|	DataAreaExchangeTransportSettings.Correspondent = &Correspondent";
	
	Query = New Query;
	Query.SetParameter("Correspondent", Correspondent);
	Query.Text = QueryText;
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Web service connection settings for correspondent %1 are not set.'"),
			String(Correspondent));
	EndIf;
	
	Return DataExchangeServer.QueryResultToStructure(QueryResult);
EndFunction
 

// Updates a register record based on the passed structure values
//
Procedure UpdateRecord(RecordStructure) Export
	
	DataExchangeServer.UpdateInformationRegisterRecord(RecordStructure, "DataAreaExchangeTransportSettings");
	
EndProcedure

// Adds a register record based on the passed structure values
//
Procedure AddRecord(RecordStructure) Export
	
	DataExchangeServer.AddRecordToInformationRegister(RecordStructure, "DataAreaExchangeTransportSettings");
	
EndProcedure

#EndRegion

#EndIf
