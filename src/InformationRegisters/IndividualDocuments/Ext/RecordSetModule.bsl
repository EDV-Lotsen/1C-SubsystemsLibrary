
///////////////////////////////////////////////////////////////////////////////
// PROCEDURES - EVENT HANDLERS

Procedure BeforeWrite(Cancellation, Replacing)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	TextSeries				= NStr("en = ', series: %1'");
	TextNumber				= NStr("en = ', # %1'");
	TextIssueDate			= NStr("en = ', issued: year %1'");
	TexValidityPeriod		= NStr("en = ', valid till: year %1'");
	
	For Each Record In ThisObject Do
		If Record.DocumentKind.IsEmpty() Then
			Record.Presentation = "";
			
		Else
			Record.Presentation = ""
				+ Record.DocumentKind
				+ ?(ValueIsFilled(Record.Series), 			StringFunctionsClientServer.SubstitureParametersInString(TextSeries, Record.Series), "")
				+ ?(ValueIsFilled(Record.Number), 			StringFunctionsClientServer.SubstitureParametersInString(TextNumber, Record.Number), "")
				+ ?(ValueIsFilled(Record.IssueDate), 		StringFunctionsClientServer.SubstitureParametersInString(TextIssueDate, Format(Record.IssueDate,"DF='dd MMMM yyyy'")), "")
				+ ?(ValueIsFilled(Record.ValidityPeriod), 	StringFunctionsClientServer.SubstitureParametersInString(TexValidityPeriod, Format(Record.ValidityPeriod,"DF='dd MMMM yyyy'")), "")
				+ ?(ValueIsFilled(Record.Issuer), ", " + Record.Issuer, "");
			
		EndIf;
	EndDo;
	
EndProcedure

Procedure OnWrite(Cancellation, Replacing)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("DocumentsTable", Unload(, "Individual, Period, IsIdentityDocument"));
	
	Query.Text =
	"SELECT
	|	DocumentsTable.Individual AS Individual,
	|	DocumentsTable.Period AS Period
	|INTO TT_Documents
	|FROM
	|	&DocumentsTable AS DocumentsTable
	|WHERE
	|	DocumentsTable.IsIdentityDocument
	|
	|INDEX BY
	|	Individual,
	|	Period
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	IndividualDocuments.Individual AS Individual,
	|	IndividualDocuments.Period AS Period,
	|	COUNT(IndividualDocuments.Individual) AS NumberOfDocuments
	|FROM
	|	InformationRegister.IndividualDocuments AS IndividualDocuments
	|		INNER JOIN TT_Documents AS DocumentsSlice
	|		ON IndividualDocuments.Period = DocumentsSlice.Period
	|			AND IndividualDocuments.Individual = DocumentsSlice.Individual
	|			AND (IndividualDocuments.IsIdentityDocument)
	|
	|GROUP BY
	|	IndividualDocuments.Individual,
	|	IndividualDocuments.Period
	|
	|HAVING
	|	COUNT(IndividualDocuments.Individual) > 1";
	Selection = Query.Execute().Choose();
	
	MessageText = NStr("en = 'The %1 ID document for individual %2 already entered.'");
	
	While Selection.Next() Do
		Cancellation = True;
		
		CommonUseClientServer.MessageToUser(StringFunctionsClientServer.SubstitureParametersInString(MessageText, Format(Selection.Period, "DLF=D"), Selection.Individual));
	EndDo;
	
EndProcedure

