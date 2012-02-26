
// Function returns id document effective on the specified date
//
// Parameters
//	Individual				- individual, for whom document should be obtained
//	Date			- date, on which we need to get the document
//
// Value to return:
//	Presentation	- string - id document presentation
//
Function DocumentCertifyingPersonalityOfInd(Individual, Date = Undefined) Export
	
	Query = New Query;
	Query.SetParameter("Individual",	Individual);
	Query.SetParameter("SliceDate",	Date);
	
	Query.Text =
	"SELECT TOP 1
	|	IndividualDocuments.Presentation
	|FROM
	|	InformationRegister.IndividualDocuments AS IndividualDocuments
	|		INNER JOIN (SELECT
	|			MAX(IndividualDocuments.Period) AS Period,
	|			IndividualDocuments.Individual AS Individual
	|		FROM
	|			InformationRegister.IndividualDocuments AS IndividualDocuments
	|		WHERE
	|			IndividualDocuments.IsIdentityDocument
	|			And IndividualDocuments.Individual = &Individual
	|			" + ?(Date <> Undefined, "And IndividualDocuments.Period <= &SliceDate", "") + "
	|		
	|		GROUP BY
	|			IndividualDocuments.Individual) AS DocumentsSlice
	|		ON IndividualDocuments.Period = DocumentsSlice.Period
	|			And IndividualDocuments.Individual = DocumentsSlice.Individual
	|			And (IndividualDocuments.IsIdentityDocument)";
	Selection = Query.Execute().Choose();
	
	PersonIdentity = New Structure("Presentation, IsIdentity");
	
	If Selection.Next() Then
		Return Selection.Presentation;
	EndIf;
	
	Return "";
	
EndFunction

// Function checks, if specified document type is an id dicument
//
// Parameters
//	Individual				- individual, for whom document should be obtained
//	DocumentKind	- document type, certifying person identity
//	Date			- date, on which we need to get the document
//
// Value to return:
//	IsIDDocument	- boolean - if specified document type is an id dicument
//
Function IsPersonID(Individual, DocumentKind, Date) Export
	
	If Individual.IsEmpty() Or DocumentKind.IsEmpty() Or Not ValueIsFilled(Date) Then
		Return False;
	EndIf;
	
	If DocumentKind = Catalogs.IdentityDocumentKinds.PassportRF Then
		Return True;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("Individual",			Individual);
	Query.SetParameter("DocumentKind",	DocumentKind);
	Query.SetParameter("SliceDate",		Date);
	
	Query.Text =
	"SELECT
	|	IndividualDocuments.DocumentKind
	|FROM
	|	InformationRegister.IndividualDocuments AS IndividualDocuments
	|		INNER JOIN (SELECT
	|			MAX(IndividualDocuments.Period) AS Period,
	|			IndividualDocuments.Individual AS Individual
	|		FROM
	|			InformationRegister.IndividualDocuments AS IndividualDocuments
	|		WHERE
	|			IndividualDocuments.Individual = &Individual
	|			AND IndividualDocuments.Period < &SliceDate
	|			AND IndividualDocuments.IsIdentityDocument
	|		
	|		GROUP BY
	|			IndividualDocuments.Individual) AS DocumentsSlice
	|		ON IndividualDocuments.Individual = DocumentsSlice.Individual
	|			AND IndividualDocuments.Period = DocumentsSlice.Period
	|			AND (IndividualDocuments.DocumentKind = &DocumentKind)";
	Return Not Query.Execute().IsEmpty();
	
EndFunction
