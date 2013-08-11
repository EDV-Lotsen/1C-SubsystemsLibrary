////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

// Adds the record to the register by the passed structure values.
Procedure AddRecord(RecordStructure) Export
	
	DataExchangeServer.AddRecordToInformationRegister(RecordStructure, "DataExchangeStates");
	
EndProcedure

// Returns a structure that contains data of the last exchange with the specified infobase node.
// 
// Returns:
//  DataExchangeStates - Structure - structure with data of the last exchange with the
//                       specified infobase node.
//
Function ExchangeNodeDataExchangeStates(Val InfoBaseNode) Export
	
	// Return value
	DataExchangeStates = New Structure;
	DataExchangeStates.Insert("InfoBaseNode");
	DataExchangeStates.Insert("DataImportResult", "Undefined");
	DataExchangeStates.Insert("DataExportResult", "Undefined");
	
	QueryText = "
	|// {QUERY #0}
	|////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CASE
	|	WHEN DataExchangeStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.Completed)
	|	THEN ""Success""
	|	
	|	WHEN DataExchangeStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.CompletedWithWarnings)
	|	THEN ""CompletedWithWarnings""
	|	
	|	WHEN DataExchangeStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.Warning_ExchangeMessageReceivedPreviously)
	|	THEN ""Warning_ExchangeMessageReceivedPreviously""
	|	
	|	WHEN DataExchangeStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.Error_MessageTransport)
	|	THEN ""Error_MessageTransport""
	|	
	|	ELSE ""Error""
	|	
	|	END AS ExchangeExecutionResult
	|FROM
	|	InformationRegister.DataExchangeStates AS DataExchangeStates
	|WHERE
	|	  DataExchangeStates.InfoBaseNode = &InfoBaseNode
	|	And DataExchangeStates.ActionOnExchange = VALUE(Enum.ActionsOnExchange.DataImport)
	|;
	|// {QUERY #1}
	|////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CASE
	|	WHEN DataExchangeStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.Completed)
	|	THEN ""Success""
	|	
	|	WHEN DataExchangeStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.CompletedWithWarnings)
	|	THEN ""CompletedWithWarnings""
	|	
	|	WHEN DataExchangeStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.Warning_ExchangeMessageReceivedPreviously)
	|	THEN ""Warning_ExchangeMessageReceivedPreviously""
	|	
	|	WHEN DataExchangeStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.Error_MessageTransport)
	|	THEN ""Error_MessageTransport""
	|	
	|	ELSE ""Error""
	|	END AS ExchangeExecutionResult
	|	
	|FROM
	|	InformationRegister.DataExchangeStates AS DataExchangeStates
	|WHERE
	|	  DataExchangeStates.InfoBaseNode = &InfoBaseNode
	|	And DataExchangeStates.ActionOnExchange = VALUE(Enum.ActionsOnExchange.DataExport)
	|;
	|";
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("InfoBaseNode", InfoBaseNode);
	
	QueryResultArray = Query.ExecuteBatch();
	
	DataImportResultSelection = QueryResultArray[0].Choose();
	DataExportResultSelection = QueryResultArray[1].Choose();
	
	If DataImportResultSelection.Next() Then
		
		DataExchangeStates.DataImportResult = DataImportResultSelection.ExchangeExecutionResult;
		
	EndIf;
	
	If DataExportResultSelection.Next() Then
		
		DataExchangeStates.DataExportResult = DataExportResultSelection.ExchangeExecutionResult;
		
	EndIf;
	
	DataExchangeStates.InfoBaseNode = InfoBaseNode;
	
	Return DataExchangeStates;
EndFunction

// Returns a structure that contains data of the last exchange with the specified
// infobase node and actions that took place during the exchange.
// 
// Returns:
//  DataExchangeStates - Structure - structure with data of the last exchange with the
//                       specified infobase node.
//
Function DataExchangeStates(Val InfoBaseNode, ActionOnExchange) Export
	
	// Return value
	DataExchangeStates = New Structure;
	DataExchangeStates.Insert("StartDate", Date('00010101'));
	DataExchangeStates.Insert("EndDate",   Date('00010101'));
	
	QueryText = "
	|SELECT
	|	StartDate,
	|	EndDate
	|FROM
	|	InformationRegister.DataExchangeStates AS DataExchangeStates
	|WHERE
	|	  DataExchangeStates.InfoBaseNode = &InfoBaseNode
	|	AND DataExchangeStates.ActionOnExchange = &ActionOnExchange
	|";
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("InfoBaseNode",     InfoBaseNode);
	Query.SetParameter("ActionOnExchange", ActionOnExchange);
	
	Selection = Query.Execute().Choose();
	
	If Selection.Next() Then
		
		FillPropertyValues(DataExchangeStates, Selection);
		
	EndIf;
	
	Return DataExchangeStates;
	
EndFunction







