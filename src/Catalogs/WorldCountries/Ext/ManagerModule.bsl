#Region InternalInterface

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Looks up country data in country catalog or world country classifier.
//
// Parameters
//    CountryCode - String, Number - country code by country classifier. 
//                                   If not specified, search by code is not performed.
//    Description - String         - country description.
//                                   If not specified, search by country description is not performed.
//
// Returns:
//    Structure - fields:
//          * Code            - String - country attribute.
//          * Description     - String - country attribute.
//          * LongDescription - String - country attribute.
//          * AlphaCode2      - String - country attribute.
//          * AlphaCode3      - String - country attribute.
//          * Ref             - CatalogRef.WorldCountries - country attribute.
//    Undefined - country not found.
//
Function WorldCountryData(Val CountryCode = Undefined, Val Description = Undefined) Export
	If CountryCode=Undefined And Description=Undefined Then
		Return Undefined;
	EndIf;
	
	NormalizedCode = WorldCountryCode(CountryCode);
	If CountryCode=Undefined Then
		SearchCondition = "TRUE";
		ClassifierFilter = New Structure;
	Else
		SearchCondition = "Code=" + PutStringInQuotes(NormalizedCode);
		ClassifierFilter = New Structure("Code", NormalizedCode);
	EndIf;
	
	If Description<>Undefined Then
		SearchCondition = SearchCondition + " AND Description=" + PutStringInQuotes(Description);
		ClassifierFilter.Insert("Description", Description);
	EndIf;
	
	Result = New Structure("Ref, Code, Description, LongDescription, AlphaCode2, AlphaCode3");
	
	Query = New Query("
		|SELECT TOP 1
		|	Ref, Code, Description, LongDescription, AlphaCode2, AlphaCode3
		|FROM
		|	Catalog.WorldCountries
		|WHERE
		|	" + SearchCondition + "
		|ORDER
		|	BY Description
		|");
		
	Selection = Query.Execute().Select();
	If Selection.Next() Then 
		FillPropertyValues(Result, Selection);
		
	Else
		ClassifierData = ClassifierTable();
		DataRows = ClassifierData.FindRows(ClassifierFilter);
		If DataRows.Count()=0 Then
			Result = Undefined
		Else
			FillPropertyValues(Result, DataRows[0]);
		EndIf;
		
	EndIf;
	
	Return Result;
EndFunction

// Determines country data using country classifier.
//
// Parameters:
//    CountryCode - String, Number - country code by country classifier.
//
// Returns:
//    Structure - fields:
//          * Code            - String - country attribute.
//          * Description     - String - country attribute.
//          * LongDescription - String - country attribute.
//          * AlphaCode2      - String - country attribute.
//          * AlphaCode3      - String - country attribute.
//    Undefined - country not found.
//
Function WorldCountryClassifierDataByCode(Val CountryCode) Export
	
	ClassifierData = ClassifierTable();
	DataRow = ClassifierData.Find(WorldCountryCode(CountryCode), "Code");
	If DataRow=Undefined Then
		Result = Undefined;
	Else
		Result = New Structure("Code, Description, LongDescription, AlphaCode2, AlphaCode3");
		FillPropertyValues(Result, DataRow);
	EndIf;
	
	Return Result;
EndFunction

// Determines country data using country classifier.
//
// Parameters:
//    Description - String - country description.
//
// Returns:
//    Structure - fields:
//          * Code            - String - country attribute.
//          * Description     - String - country attribute.
//          * LongDescription - String - country attribute.
//          * AlphaCode2      - String - country attribute.
//          * AlphaCode3      - String - country attribute.
//    Undefined - country not found.
//
Function WorldCountryClassifierDataByDescription(Val Description) Export
	ClassifierData = ClassifierTable();
	DataRow = ClassifierData.Find(Description, "Description");
	If DataRow=Undefined Then
		Result = Undefined;
	Else
		Result = New Structure("Code, Description, LongDescription, AlphaCode2, AlphaCode3");
		FillPropertyValues(Result, DataRow);
	EndIf;
	
	Return Result;
EndFunction

// Updates the country catalog based on country classifier template data.
// Catalog items are identified by the Code field.
//
// Parameters:
//    Add - Boolean - if True, add countries present in the country classifier 
//                     but not in the country catalog.
//
Procedure UpdateWorldCountriesByClassifier(Val Add = False) Export
	AllErrors = "";
	
	Filter = New Structure("Code");
	
	// Cannot perform comparison in the query due to possible database case-insensitivity
	For Each ClassifierString In ClassifierTable() Do
		Filter.Code = ClassifierString.Code;
		Selection = Catalogs.WorldCountries.Select(,,Filter);
		CountryFound = Selection.Next();
		If Not CountryFound And Add Then
			// Adding country
			Country = Catalogs.WorldCountries.CreateItem();
		ElsIf CountryFound And (
			      Selection.Description<>ClassifierString.Description
			  Or Selection.AlphaCode2<>ClassifierString.AlphaCode2
			  Or Selection.AlphaCode3<>ClassifierString.AlphaCode3
			  Or Selection.LongDescription<>ClassifierString.LongDescription
			) Then
			// Editing country
			Country = Selection.GetObject();
		Else
			Continue;
		EndIf;
		
		BeginTransaction();
		Try
			If Not Country.IsNew() Then
				LockDataForEdit(Country.Ref);
			EndIf;
			FillPropertyValues(Country, ClassifierString, "Code, Description, AlphaCode2, AlphaCode3, LongDescription");		
			Country.AdditionalProperties.Insert("DontCheckUniqueness");
			Country.Write();
			CommitTransaction();
		Except
			Info = ErrorInfo();
			ErrorText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='Error writing world country %1 (code %2) while updating classifier, %3'"),
				Selection.Code, Selection.Description, BriefErrorDescription(Info));
			WriteLogEvent(InfobaseUpdate.EventLogMessageText(), 
				EventLogLevel.Error,,,
				ErrorText + Chars.LF + DetailErrorDescription(Info));
			AllErrors = AllErrors + Chars.LF + ErrorText;
			RollbackTransaction();
		EndTry;
		
	EndDo;
	
	If Not IsBlankString(AllErrors) Then
		Raise TrimAll(AllErrors);
	EndIf;
EndProcedure

// Creates a new reference or returns an existing reference, based on the classifier data.
//
// Parameters:
//    Filter - Structure - contains field:
//           * Code - String - used to search the classifier for the specified country.
//    Data   - Structure - used to fill the remaining fields of the created object
//                         that have the same names as address classifier fields.
//
// Returns:
//     CatalogRef.WorldCountries - reference to the created item.
//
Function RefByClassifier(Val Filter, Val AdditionalData = Undefined) Export
	
	// Checking whether the specified country is listed in the classifier
	SearchData = WorldCountryClassifierDataByCode(Filter.Code);
	If SearchData=Undefined Then
		Raise NStr("en='Invalid world country classifier code'");
	EndIf;
	
	// Checking whether the specified country is listed in the catalog, based on classifier data
	SearchData = WorldCountryData(SearchData.Code, SearchData.Description);
	Result = SearchData.Ref;
	If Not ValueIsFilled(Result) Then
		CountryObject = Catalogs.WorldCountries.CreateItem();
		FillPropertyValues(CountryObject, SearchData);
		If AdditionalData<>Undefined Then
			FillPropertyValues(CountryObject, AdditionalData);
		EndIf;
		CountryObject.Write();
		Result = CountryObject.Ref;
	EndIf;
	
	Return Result;
EndFunction

#EndIf

// Returns the flag specifying whether items can be added or edited.
//
Function HasRightToAdd() Export
	
	Return AccessRight("Insert", Metadata.Catalogs.WorldCountries);
	
EndFunction

// Returns search fields in preferred order for world country catalog.
//
// Returns:
//    Array - contains structures with fields:
//      * Name                - String - search attribute name.
//      * PresentationPattern - String - template used to generate presentation value 
//                                       based on attribute names. Example: 
//                                       "%1.Description (%1.Code)", where Description and Code are 
//                                       attribute names and "%1" is a variable used to pass the table alias.
//
Function SearchFields() Export
	Result = New Array;
	FieldList = Catalogs.WorldCountries.EmptyRef().Metadata().InputByString;
	FieldBorder = FieldList.Count() - 1;
	AllNamesString = "";
	
	SeparatorPresentation = ", ";
	PresentationSeparator = " + """ + SeparatorPresentation + """ + ";
	
	For Index=0 To FieldBorder Do
		FieldName = FieldList[Index].Name;
		AllNamesString = AllNamesString + "," + FieldName;
		
		PresentationPattern = "%1." + FieldName;
		
		OtherFields = "";
		For Position=0 To FieldBorder Do
			If Position<>Index Then
				OtherFields = OtherFields + PresentationSeparator + FieldList[Position].Name;
			EndIf;
		EndDo;
		If Not IsBlankString(OtherFields) Then
			PresentationPattern = PresentationPattern
				+ " + "" ("" + " 
				+ "%1." + Mid(OtherFields, StrLen(PresentationSeparator) + 1) 
				+ " + "")""";
		EndIf;
		
		Result.Add(
			New Structure("Name, PresentationPattern", FieldName, PresentationPattern)
		);
	EndDo;
	
	Return New Structure("FieldList, FieldNamesString", Result, Mid(AllNamesString, 2));
EndFunction

// Returns full data from the country classifier.
//
// Returns:
//     ValueTable - classifier data with the following columns:
//         * Code            - String - country data.
//         * Description     - String - country data.
//         * LongDescription - String - country data.
//         * AlphaCode2      - String - country data.
//         * AlphaCode3      - String - country data.
//
//     The value table is indexed by Code and Description fields.
//
Function ClassifierTable() Export
	Template = Catalogs.WorldCountries.GetTemplate("Classifier");
	
	Read = New XMLReader;
	Read.SetString(Template.GetText());
	
	Return XDTOSerializer.ReadXML(Read);
EndFunction

#EndRegion

#Region InternalProceduresAndFunctions

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Converts a country code to the standard format (a string of three characters).
//
Function WorldCountryCode(Val CountryCode)
	
	If TypeOf(CountryCode)=Type("Number") Then
		Return Format(CountryCode, "ND=3; NZ=; NLZ=; NG=");
	EndIf;
	
	Return Right("000" + CountryCode, 3);
EndFunction

// Returns a string enclosed in quotes.
//
Function PutStringInQuotes(Val String)
	Return """" + StrReplace(String, """", """""") + """";
EndFunction

#EndIf

// Escapes characters used in LIKE query function.
//
Function EscapeLikeCharacters(Val Text, Val SpecialCharacter = "\")
	Result = Text;
	LikeCharacters = "%_[]^" + SpecialCharacter;
	
	For Position=1 To StrLen(LikeCharacters) Do
		CurrentChar = Mid(LikeCharacters, Position, 1);
		Result = StrReplace(Result, CurrentChar, SpecialCharacter + CurrentChar);
	EndDo;
	
	Return Result;
EndFunction

#EndRegion

#Region EventHandlers

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	If Not StandardProcessing Then 
		// Processed elsewhere
		Return;
		
	ElsIf Not Parameters.Property("AllowClassifierData") Then
		// Default behavior, catalog picking only
		Return;
		
	ElsIf True<>Parameters.AllowClassifierData Then
		// Picking from classifier disabled, default behavior
		Return;
		
	ElsIf Not HasRightToAdd() Then
		// No rights to add a new world country, default behavior
		Return;
		
	EndIf;
	
	// Imitating platform behavior: searching by all available search fields, generating a detailed list.
	
	// It is assumed that catalog and classifier field lists are identical, 
	// with the only exception of Ref field being not available in the classifier.
	Query = New Query;
	Query.TempTablesManager = New TempTablesManager;
	
	FilterParameterPrefix = "FilterParameters";
	
	// General filter by parameters
	FilterTemplate = "TRUE";
	For Each KeyValue In Parameters.Filter Do
		AttributeValue = KeyValue.Value;
		FieldName      = KeyValue.Key;
		ParameterName = FilterParameterPrefix + FieldName;
		
		If TypeOf(AttributeValue)=Type("Array") Then
			FilterTemplate = FilterTemplate + " AND %1." + FieldName + " IN (&" + ParameterName + ")";
		Else
			FilterTemplate = FilterTemplate + " AND %1." + FieldName + " = &" + ParameterName;
		EndIf;
		
		Query.SetParameter(ParameterName, KeyValue.Value);
	EndDo;
	
	// Additional filters
	If Parameters.Property("ChoiceFoldersAndItems") Then
		If Parameters.ChoiceFoldersAndItems = FoldersAndItemsUse.Folders Then
			FilterTemplate = FilterTemplate + " AND %1.IsGroup";
			
		ElsIf Parameters.ChoiceFoldersAndItems = FoldersAndItemsUse.Items Then
			FilterTemplate = FilterTemplate + " AND (NOT %1.IsGroup)";
			
		EndIf;
	EndIf;
	
	// Data sources
	If (Parameters.Property("OnlyClassifierData") And Parameters.OnlyClassifierData) Then
		// Classifier query only
		QueryPattern = "
			|SELECT TOP 50
			|	NULL                   AS Ref,
			|	Classifier.Code        AS Code,
			|	Classifier.Description AS Description,
			|	FALSE                  AS DeletionMark,
			|	%2                     AS Presentation
			|FROM
			|	Classifier AS Classifier
			|WHERE
			|	Classifier.%1 LIKE &SearchString
			|	AND (
			|		" + StringFunctionsClientServer.SubstituteParametersInString(FilterTemplate, "Classifier") + "
			|	)
			|ORDER BY
			|Classifier.%1
			|";
	Else
		// Both classifier and catalog query
		QueryPattern = "
			|SELECT TOP 50 
			|	WorldCountries.Ref                                         AS Ref,
			|	ISNULL(WorldCountries.Code, Classifier.Code)               AS Code,
			|	ISNULL(WorldCountries.Description, Classifier.Description) AS Description,
			|	ISNULL(WorldCountries.DeletionMark, FALSE)                 AS DeletionMark,
			|
			|	CASE WHEN WorldCountries.Ref IS NULL THEN 
			|		%2 
			|	ELSE 
			|		%3
			|	END AS Presentation
			|
			|FROM
			|	Catalog.WorldCountries AS WorldCountries
			|FULL JOIN
			|	Classifier
			|ON
			|	Classifier.Code = WorldCountries.Code
			|	AND Classifier.Description = WorldCountries.Description
			|WHERE 
			|	(WorldCountries.%1 LIKE &SearchString OR Classifier.%1 LIKE &SearchString)
			|	AND (" + StringFunctionsClientServer.SubstituteParametersInString(FilterTemplate, "Classifier") + ") AND (" + StringFunctionsClientServer.SubstituteParametersInString(FilterTemplate, "WorldCountries") + ") ORDER BY ISNULL(WorldCountries.%1, Classifier.%1)
			|";
	EndIf;
	
	FieldNames = SearchFields();
	
	// Code + Description are key catalog/classifier mapping fields.
	// Processing these fields is mandatory.
	FieldNamesString = "," + StrReplace(FieldNames.FieldNamesString, " ", "");
	FieldNamesString = StrReplace(FieldNamesString, ",Code", "");
	FieldNamesString = StrReplace(FieldNamesString, ",Description", "");
	
	Query.Text = "
		|SELECT
		|	Code, Description " + FieldNamesString + "
		|INTO
		|	Classifier
		|FROM
		|	&Classifier AS Classifier
		|INDEX BY
		|	Code, Description
		|	" + FieldNamesString + "
		|";
	Query.SetParameter("Classifier", ClassifierTable());
	Query.Execute();
	Query.SetParameter("SearchString", EscapeLikeCharacters(Parameters.SearchString) + "%");
	
	For Each FieldData In FieldNames.FieldList Do
		Query.Text = StringFunctionsClientServer.SubstituteParametersInString(QueryPattern, 
			FieldData.Name,
			StringFunctionsClientServer.SubstituteParametersInString(FieldData.PresentationPattern, "Classifier"),
			StringFunctionsClientServer.SubstituteParametersInString(FieldData.PresentationPattern, "WorldCountries"),
		);
		
		Result = Query.Execute();
		If Not Result.IsEmpty() Then
			ChoiceData = New ValueList;
			StandardProcessing = False;
			
			Selection = Result.Select();
			While Selection.Next() Do
				If ValueIsFilled(Selection.Ref) Then
					// Catalog data
					ChoiceItem = Selection.Ref;
				Else
					// Classifier data
					ChoiceResult = New Structure("Code, Description", 
						Selection.Code, Selection.Description
					);
					
					ChoiceItem = New Structure("Value, DeletionMark, Warning",
						ChoiceResult, Selection.DeletionMark, Undefined,
					);
				EndIf;
				
				ChoiceData.Add(ChoiceItem, Selection.Presentation);
			EndDo;
		
			Break;
		EndIf;
	EndDo;
	
EndProcedure

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

////////////////////////////////////////////////////////////////////////////////
// Batch object modification

// Returns a list of attributes excluded from the batch object modification.
//
Function AttributesToSkipOnGroupProcessing() Export
	
	Result = New Array;
	Result.Add("*");
	Return Result;
	
EndFunction


////////////////////////////////////////////////////////////////////////////////
// Import data from file

// Prohibits catalog data import from the "Import data from file" subsystem. 
// A separate template data import method is implemented for this catalog.
// 
Function UseDataImportFromFile() Export
	Return False;
EndFunction


#EndIf

#EndRegion
