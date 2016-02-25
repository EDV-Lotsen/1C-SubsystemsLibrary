#Region InternalInterface

// Updates region data in the address objects
//
// The records are compared based on region (state) codes
//
Procedure UpdateRegionContentByClassifier() Export
	
	Classifier = RegionClassifier();
	
	// Selecting only records missing from the register
	Query = New Query("
		|SELECT
		|	Parameter.RegionCode AS RegionCode
		|INTO
		|	Classifier
		|FROM
		|	&Classifier AS Parameter
		|INDEX BY
		|	RegionCode
		|;
		|
		|SELECT
		|	Classifier.RegionCode AS RegionCode
		|FROM
		|	Classifier AS Classifier
		|LEFT JOIN
		|	InformationRegister.AddressClassifier AS AddressClassifier
		|ON
		|	  AddressClassifier.AddressItemType            = 1
		|	AND AddressClassifier.AddressObjectCodeInCode  = Classifier.RegionCode
		|	AND AddressClassifier.CountyCodeInCode         = 0
		|	AND AddressClassifier.CityCodeInCode           = 0
		|	AND AddressClassifier.SettlementCodeInCode     = 0
		|	AND AddressClassifier.StreetCodeInCode         = 0
		|WHERE
		|	AddressClassifier.Code IS NULL
		|");
	Query.SetParameter("Classifier", Classifier);
	NewRegions = Query.Execute().Unload();
	
	// Updating only the missing records
	Set = InformationRegisters.AddressClassifier.CreateRecordSet();
	Filter = Set.Filter;
	
	Filter.AddressItemType.Set(1);
	Filter.CountyCodeInCode.Set(0);
	Filter.CityCodeInCode.Set(0);
	Filter.SettlementCodeInCode.Set(0);
	Filter.StreetCodeInCode.Set(0);
	
	For Each Region In NewRegions Do
		
		InitialData = Classifier.Find(Region.RegionCode, "RegionCode");
		
		Filter.AddressObjectCodeInCode.Set(Region.RegionCode);
		Set.Clear();
		
		NewRegion = Set.Add();
		NewRegion.AddressItemType         = 1;
		NewRegion.AddressObjectCodeInCode = Region.RegionCode;
		NewRegion.Code                    = Region.RegionCode * 10000000000000000000;
		
		NewRegion.Description             = InitialData.Description;
		NewRegion.Abbr                    = InitialData.Abbr;
		NewRegion.PostalCode              = InitialData.PostalCode;
		
		Set.Write();
	EndDo;
	
EndProcedure

// Returns data from the region classifier
//
// Returns:
//     ValueTable - supplied data. Contains columns:
//       * RegionCode   - Number - state code by classifier (i.e. 45 for Alabama) 
//       * Description  - String - region name by classifier. (i.e. Alabama)
//       * Abbr         - String - region name by classifier. (i.e. AL)
//       * PostalCode   - Number - regional postal code. If 0 - then undefined 
//       * ID           - UUID   - address classifier ID
//
Function RegionClassifier() Export
	Template = InformationRegisters.AddressClassifier.GetTemplate("Regions");
	
	Read = New XMLReader;
	Read.SetString(Template.GetText());
	Result = XDTOSerializer.ReadXML(Read);
	
	Return Result;
EndFunction

// Returns classifier data import status by state
//
// Returns:
//    ValueTable - status description. Contains columns 
//      * RegionCode   - Number  - State code
//      * Presentation - String  - State name and abbreviation 
//      * Imported     - Boolean - True if classifier for this state is already imported
// 
Function RegionImportInformation() Export
	
	Classifier = InformationRegisters.AddressClassifier.RegionClassifier();
	
	// Selecting all available data, both from register and classifier
	Query = New Query("
		|SELECT
		|	Parameter.Description  AS Description,
		|	Parameter.Abbr    AS Abbr,
		|	Parameter.RegionCode AS RegionCode
		|INTO
		|	Classifier
		|FROM
		|	&Classifier AS Parameter
		|;
		|
		|SELECT 
		|	AllStates.Description + "" "" + AllStates.Abbr AS Presentation,
		|	AllStates.RegionCode                                AS RegionCode,
		|
		|	CASE
		|		WHEN 1 IN (SELECT TOP 1 1 FROM InformationRegister.AddressClassifier WHERE AddressObjectCodeInCode = AllStates.RegionCode AND AddressItemType = 2) THEN TRUE
		|		WHEN 1 IN (SELECT TOP 1 1 FROM InformationRegister.AddressClassifier WHERE AddressObjectCodeInCode = AllStates.RegionCode AND AddressItemType = 3) THEN TRUE
		|		WHEN 1 IN (SELECT TOP 1 1 FROM InformationRegister.AddressClassifier WHERE AddressObjectCodeInCode = AllStates.RegionCode AND AddressItemType = 4) THEN TRUE
		|		WHEN 1 IN (SELECT TOP 1 1 FROM InformationRegister.AddressClassifier WHERE AddressObjectCodeInCode = AllStates.RegionCode AND AddressItemType = 5) THEN TRUE
		|		WHEN 1 IN (SELECT TOP 1 1 FROM InformationRegister.AddressClassifier WHERE AddressObjectCodeInCode = AllStates.RegionCode AND AddressItemType = 6) THEN TRUE
		|		ELSE FALSE
		|	END AS Downloaded
		|FROM (
		|
		|	SELECT DISTINCT
		|		AddressClassifier.Description             AS Description,
		|		AddressClassifier.Abbr               AS Abbr,
		|		AddressClassifier.AddressObjectCodeInCode AS RegionCode
		|	FROM
		|		InformationRegister.AddressClassifier AS AddressClassifier
		|	WHERE
		|		AddressClassifier.AddressItemType          = 1
		|		AND AddressClassifier.CountyCodeInCode     = 0
		|		AND AddressClassifier.CityCodeInCode       = 0
		|		AND AddressClassifier.SettlementCodeInCode = 0
		|		AND AddressClassifier.StreetCodeInCode     = 0
		|	
		|	UNION SELECT
		|		Classifier.Description,
		|		Classifier.Abbr,
		|		Classifier.RegionCode
		|	FROM
		|		Classifier AS Classifier
		|
		|) AS AllStates
		|
		|ORDER BY
		|	AllStates.RegionCode,
		|	AllStates.Description + "" "" + AllStates.Abbr
		|");
	Query.SetParameter("Classifier", Classifier);
	
	ImportedData = Query.Execute().Unload();
	ImportedData.Indexes.Add("RegionCode");
	ImportedData.Indexes.Add("Downloaded");
	
	Return ImportedData;
EndFunction

// Returns state name and abbreviation by its code
//
// Parameters:
//    RegionCode - String, Number - state code.
//
// Returns:
//    String, Undefined - state name and abbreviation. 
//    If no state is found, Undefined will be returned
//
Function StateDescriptionByCode(Val RegionCode) Export
	
	Query = New Query("
		|SELECT TOP 1
		|	Description + "" "" + Abbr AS Description
		|FROM
		|	InformationRegister.AddressClassifier
		|WHERE
		|	AddressItemType = 1
		|	AND AddressObjectCodeInCode = &RegionCode
		|");
		
	If TypeOf(RegionCode) = Type("String") Then
		NumberType = New TypeDescription("Number");
		RegionCode = NumberType.AdjustValue(RegionCode);
	EndIf;
	
	Query.SetParameter("RegionCode", RegionCode);
	Selection = Query.Execute().Select();
	If Selection.Next() Then 
		Return Selection.Description;
	EndIf;
	
	// If nothing is found, look up the classifier template 
	Classifier = InformationRegisters.AddressClassifier.RegionClassifier();
	Option = Classifier.Find(RegionCode, "RegionCode");
	If Option = Undefined Then
		// Not found
		Return Undefined;
	EndIf;
	
	Return Option.Description + " " + Option.Abbr;
EndFunction

// Returns state code by its name.
//
// Parameters:
//    Name - String - full or abbreviated state name.
//
// Returns:
//    Number, Undefined - state code, or Undefined if not found
//
Function StateCodeByName(Val Name) Export
	
	Query = New Query("
		|SELECT 
		|	Options.RegionCode
		|FROM (
		|	SELECT TOP 1
		|		1                        AS Order,
		|		AddressObjectCodeInCode AS RegionCode
		|	FROM
		|		InformationRegister.AddressClassifier
		|	WHERE
		|		AddressItemType = 1 
		|		AND Description = &Name
		|
		|	UNION ALL
		|
		|	SELECT TOP 1
		|		2                        AS Order,
		|		AddressObjectCodeInCode AS RegionCode
		|	FROM
		|		InformationRegister.AddressClassifier
		|	WHERE
		|		AddressItemType = 1 
		|		AND Description = &Description
		|		AND Abbr   = &Abbr
		|) AS Options
		|
		|ORDER BY
		|	Options.Order
		|");
		
	WordParts = DescriptionAndAbbreviation(Name);
	Query.SetParameter("Description", WordParts.Description);
	Query.SetParameter("Abbr",   WordParts.Abbr);
	Query.SetParameter("Name",     Name);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then 
		Return Selection.RegionCode;
	EndIf;

	// If nothing is found, look up the classifier - template 
	Classifier = InformationRegisters.AddressClassifier.RegionClassifier();
	
	Filter = New Structure("Description", Name);
	Options = Classifier.FindRows(Filter);
	If Options.Count() = 0 Then
		Filter.Insert("Description", WordParts.Description);
		Filter.Insert("Abbr",   WordParts.Abbr);
		Options = Classifier.FindRows(Filter);
	EndIf;
	
	If Options.Count() > 0 Then
		Return Options[0].RegionCode;
	EndIf;
	
	Return Undefined;
EndFunction

// Separates the initial name into description and abbreviation.
// Abbreviation always goes after the final space
//
// Parameters:
//     Name - String - Full name (for example, Main st.)
//
// Returns:
//     Structure - contains fields 
//       * Description - String - Description (for example, Main). If no abbreviation 
//         was found, the description is identical to the initial name 
//       * Abbr        - String - Abbr (for example, st.) If no abbreviation 
//         was found, empty string will be returned
//
Function DescriptionAndAbbreviation(Val Name)
	SearchText = TrimR(Name);
	
	Position = StrLen(SearchText);
	While Position > 0 Do
		If IsBlankString(Mid(SearchText, Position, 1)) Then
			Break;
		EndIf;
		Position = Position - 1;
	EndDo;
	
	Result = New Structure("Description, Abbr");
	If Position = 0 Then
		Result.Description = SearchText;
		Result.Abbr   = "";
	Else
		Result.Description = TrimR(Left(SearchText, Position));
		Result.Abbr   = Mid(SearchText, Position + 1);
	EndIf;
	
	Return Result;
EndFunction

#EndRegion