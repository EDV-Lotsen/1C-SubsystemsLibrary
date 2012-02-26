
////////////////////////////////////////////////////////////////////////////////
// INFOBASE UPDATE

// Procedure fills catalog IndividualDocuments using MIA classifier
//
Procedure FillIndividualDocumentsByClassifier() Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	IdentityDocumentKinds.Description
	|FROM
	|	Catalog.IdentityDocumentKinds AS IdentityDocumentKinds
	|WHERE
	|	(NOT IdentityDocumentKinds.Predefined)";
	InfobaseDocumentsList = Query.Execute().Unload().UnloadColumn("Description");
	
	DocumentsList = New Array;
	DocumentsList.Add("Birth Certificate");
	DocumentsList.Add("Department of Defense Identification Card");
	DocumentsList.Add("Driver's license");
	DocumentsList.Add("Passport");
	DocumentsList.Add("Social Security Card");
	DocumentsList.Add("Certificate of U.S. Citizenship");
	DocumentsList.Add("Certificate of Naturalization");
	DocumentsList.Add("Passport Card");
	DocumentsList.Add("NEXUS Card");
	DocumentsList.Add("SENTRI Card");
	DocumentsList.Add("Transportation Worker Identification Credential");
	DocumentsList.Add("Merchant Mariner's Document");
	
	For Each Doc In DocumentsList Do
		If InfobaseDocumentsList.Find(Doc) = Undefined Then
			DocObject = Catalogs.IdentityDocumentKinds.CreateItem();
			DocObject.Description = Doc;
			DocObject.Write();
		EndIf;
	EndDo;
	
EndProcedure

// Procedure fills dimension DocumentKind by resource DocumentKind,
// and also fills attribute IsIdentityDocument for existing records
//
Procedure ConvertPersonalIDsToDocuments() Export
	
	Query = New Query;
	Query.Text =
		"SELECT DISTINCT
		|	IndividualDocuments.Individual AS Individual
		|INTO TTIndividuals
		|FROM
		|	InformationRegister.IndividualDocuments AS IndividualDocuments
		|WHERE
		|	NOT IndividualDocuments.DocumentKind = VALUE(Catalog.IdentityDocumentKinds.EmptyRef)
		|
		|INDEX BY
		|	Individual
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	IndividualDocuments.Period AS Period,
		|	IndividualDocuments.Individual AS Individual,
		|	IndividualDocuments.DocumentKind AS DocumentKind,
		|	IndividualDocuments.Series,
		|	IndividualDocuments.Number,
		|	IndividualDocuments.IssueDate,
		|	IndividualDocuments.ValidityPeriod,
		|	IndividualDocuments.Issuer,
		|	CASE
		|		WHEN IndividualDocuments.DocumentKind = VALUE(Catalog.IdentityDocumentKinds.EmptyRef)
		|			THEN FALSE
		|		ELSE TRUE
		|	END AS IsIdentityDocument,
		|	IndividualDocuments.Presentation
		|FROM
		|	InformationRegister.IndividualDocuments AS IndividualDocuments
		|WHERE
		|	IndividualDocuments.Individual IN
		|			(SELECT
		|				Inds.Individual
		|			FROM
		|				TTIndividuals AS Inds)
		|
		|ORDER BY
		|	Individual,
		|	Period";
	Selection = Query.Execute().Choose();
	
	RecordSet = InformationRegisters.IndividualDocuments.CreateRecordSet();
	RecordSet.DataExchange.Load = True;
	
	TextSeries				= NStr("en = ', series: %1'");
	TextNumber				= NStr("en = ', # %1'");
	TextIssueDate			= NStr("en = ', issued in %1'");
	TexValidityPeriod		= NStr("en = ', valid till %1'");
	
	While Selection.NextByFieldValue("Individual") Do
		RecordSet.Filter.Individual.Set(Selection.Individual);
		
		While Selection.Next() Do
			Record = RecordSet.Add();
			FillPropertyValues(Record, Selection);
			
			If IsBlankString(Record.Presentation) And Not Record.DocumentKind.IsEmpty() Then
				Record.Presentation = ""
					+ Record.DocumentKind
					+ ?(ValueIsFilled(Record.Series), 			StringFunctionsClientServer.SubstitureParametersInString(TextSeries, Record.Series), "")
					+ ?(ValueIsFilled(Record.Number), 	 		StringFunctionsClientServer.SubstitureParametersInString(TextNumber, Record.Number), "")
					+ ?(ValueIsFilled(Record.IssueDate), 		StringFunctionsClientServer.SubstitureParametersInString(TextIssueDate, Format(Record.IssueDate,"DF='dd MMMM yyyy'")), "")
					+ ?(ValueIsFilled(Record.ValidityPeriod), 	StringFunctionsClientServer.SubstitureParametersInString(TexValidityPeriod, Format(Record.ValidityPeriod,"DF='dd MMMM yyyy'")), "")
					+ ?(ValueIsFilled(Record.Issuer), ", " + Record.Issuer, "");
			EndIf;
		EndDo;
		
		RecordSet.Write();
		RecordSet.Clear();
	EndDo;
	
EndProcedure
