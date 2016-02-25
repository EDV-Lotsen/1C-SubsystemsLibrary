#If Server OR ThickClientOrdinaryApplication OR ExternalConnection Then

#Region InternalProceduresAndFunctions

Procedure RecordDocumentCheckError(Ref, InfobaseNode, Reason, ProblemType) Export
	
	ConflictRecordSet = InformationRegisters.DataExchangeResults.CreateRecordSet();
	ConflictRecordSet.Filter.ProblematicObjects.Set(Ref);
	ConflictRecordSet.Filter.ProblemType.Set(ProblemType);
	
	ConflictRecordSet.Read();
	ConflictRecordSet.Clear();
	
	ConflictRecord = ConflictRecordSet.Add();
	ConflictRecord.ProblematicObjects = Ref;
	ConflictRecord.ProblemType = ProblemType;
	ConflictRecord.InfobaseNode = InfobaseNode;
	ConflictRecord.OccurrenceDate = CurrentSessionDate();
	ConflictRecord.Reason = TrimAll(Reason);
	ConflictRecord.Skipped = False;
	ConflictRecord.DeletionMark = CommonUse.ObjectAttributeValue(Ref, "DeletionMark");
	
	If ProblemType = Enums.DataExchangeProblemTypes.UnpostedDocument Then
		
		ConflictRecord.DocumentNumber = CommonUse.ObjectAttributeValue(Ref, "Number");
		ConflictRecord.DocumentDate = CommonUse.ObjectAttributeValue(Ref, "Date");
		
	EndIf;
	
	ConflictRecordSet.Write();
	
EndProcedure

Procedure Ignore(Ref, ProblemType, Ignore) Export
	
	ConflictRecordSet = InformationRegisters.DataExchangeResults.CreateRecordSet();
	ConflictRecordSet.Filter.ProblematicObjects.Set(Ref);
	ConflictRecordSet.Filter.ProblemType.Set(ProblemType);
	ConflictRecordSet.Read();
	ConflictRecordSet[0].Skipped = Ignore;
	ConflictRecordSet.Write();
	
EndProcedure

Function IssueCount(ExchangeNodes = Undefined, ProblemType = Undefined, IncludingIgnored = False, Period = Undefined, SearchString = "") Export
	
	Count = 0;
	
	QueryText = "SELECT
	|	COUNT(DataExchangeResults.ProblematicObjects) AS IssueCount
	|FROM
	|	InformationRegister.DataExchangeResults AS DataExchangeResults
	|WHERE
	|	DataExchangeResults.Skipped <> &FilterBySkipped
	|	[FilterByNode]
	|	[FilterByType]
	|	[FilterByPeriod]
	|	[FilterByReason]";
	
	Query = New Query;
	
	FilterBySkipped = ?(IncludingIgnored, Undefined, True);
	Query.SetParameter("FilterBySkipped", FilterBySkipped);
	
	If ProblemType = Undefined Then
		FilterRow = "";
	Else
		FilterRow = "And DataExchangeResults.ProblemType = &ProblemType";
		Query.SetParameter("ProblemType", ProblemType);
	EndIf;
	QueryText = StrReplace(QueryText, "[FilterByType]", FilterRow);
	
	If ExchangeNodes = Undefined Then
		FilterRow = "";
	ElsIf ExchangePlans.AllRefsType().ContainsType(TypeOf(ExchangeNodes)) Then
		FilterRow = "And DataExchangeResults.InfobaseNode = &InfobaseNode";
		Query.SetParameter("InfobaseNode", ExchangeNodes);
	Else
		FilterRow = "And DataExchangeResults.InfobaseNode IN (&ExchangeNodes)";
		Query.SetParameter("ExchangeNodes", ExchangeNodes);
	EndIf;
	
	QueryText = StrReplace(QueryText, "[FilterByNode]", FilterRow);
	
	If ValueIsFilled(Period) Then
		
		FilterRow = "And (DataExchangeResults.OccurrenceDate >= &StartDate And DataExchangeResults.OccurrenceDate <= &EndDate)";
		Query.SetParameter("StartDate", Period.StartDate);
		Query.SetParameter("EndDate", Period.EndDate);
		
	Else
		
		FilterRow = "";
		
	EndIf;
	QueryText = StrReplace(QueryText, "[FilterByPeriod]", FilterRow);
	
	If ValueIsFilled(SearchString) Then
		
		FilterRow = "And DataExchangeResults.Reason LIKE &Reason";
		Query.SetParameter("Reason", "%" + SearchString + "%");
		
	Else
		
		FilterRow = "";
		
	EndIf;
	QueryText = StrReplace(QueryText, "[FilterByReason]", FilterRow);
	
	Query.Text = QueryText;
	Result = Query.Execute();
	
	If Not Result.IsEmpty() Then
		
		Selection = Result.Select();
		Selection.Next();
		Count = Selection.IssueCount;
		
	EndIf;
	
	Return Count;
	
EndFunction

Procedure RecordIssueSolving(Source, ProblemType) Export
	
	If Source.DataExchange.Load Then
		Return;
	EndIf;
	
	If Source.IsNew() Then
		Return;
	EndIf;
	
	If CommonUseCached.CanUseSeparatedData() Then
		
		SourceRef = Source.Ref;
		
		DeletionMarkNewValue = Source.DeletionMark;
		
		DataExchangeServerCall.RecordIssueSolving(SourceRef, ProblemType, DeletionMarkNewValue);
		
	EndIf;
	
EndProcedure

Procedure ClearReferencesToInfobaseNode(Val InfobaseNode) Export
	
	If Not CommonUseCached.CanUseSeparatedData() Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text = "SELECT
	|	DataExchangeResults.ProblematicObjects,
	|	DataExchangeResults.ProblemType,
	|	UNDEFINED AS InfobaseNode,
	|	DataExchangeResults.OccurrenceDate,
	|	DataExchangeResults.Reason,
	|	DataExchangeResults.Skipped,
	|	DataExchangeResults.DeletionMark,
	|	DataExchangeResults.DocumentNumber,
	|	DataExchangeResults.DocumentDate
	|FROM
	|	InformationRegister.DataExchangeResults AS DataExchangeResults
	|WHERE
	|	DataExchangeResults.InfobaseNode = &InfobaseNode";
	
	Query.SetParameter("InfobaseNode", InfobaseNode);
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		RecordSet = InformationRegisters.DataExchangeResults.CreateRecordSet();
		
		RecordSet.Filter["ProblematicObjects"].Set(Selection["ProblematicObjects"]);
		RecordSet.Filter["ProblemType"].Set(Selection["ProblemType"]);
		
		FillPropertyValues(RecordSet.Add(), Selection);
		
		RecordSet.Write();
		
	EndDo;
	
EndProcedure

#EndRegion

#EndIf