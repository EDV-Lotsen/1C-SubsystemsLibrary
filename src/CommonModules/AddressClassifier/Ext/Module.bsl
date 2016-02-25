////////////////////////////////////////////////////////////////////////////////
// Address classifier subsystem.
// 
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// Returns address object versions saved during the previous update.
// If no records are found for an address object, returns an empty date.
// 
// Returns:
//    ValueList - presentation is address object number, value is version release date (UTC).
//
Function AddressObjectVersions() Export
	
	Query = New Query("
		|SELECT
		|	Versions.AddressObject      AS AddressObject,
		|	Versions.VersionReleaseDate AS VersionDate
		|FROM
		|	InformationRegister.AddressClassifierObjectVersions AS Versions
		|;
		|////////////////////////////////////////////////////////////////////////////////
		|
		|SELECT
		|	State.AddressObjectCodeInCode AS StateCode
		|FROM
		|	InformationRegister.AddressClassifier AS State
		|WHERE
		|	State.AddressItemType = 1
		|	AND 1 IN (
		|		               SELECT TOP 1 1 FROM InformationRegister.AddressClassifier WHERE AddressObjectCodeInCode=State.AddressObjectCodeInCode AND AddressItemType = 2
		|		UNION ALL SELECT TOP 1 1 FROM InformationRegister.AddressClassifier WHERE AddressObjectCodeInCode=State.AddressObjectCodeInCode AND AddressItemType = 3
		|		UNION ALL SELECT TOP 1 1 FROM InformationRegister.AddressClassifier WHERE AddressObjectCodeInCode=State.AddressObjectCodeInCode AND AddressItemType = 4
		|		UNION ALL SELECT TOP 1 1 FROM InformationRegister.AddressClassifier WHERE AddressObjectCodeInCode=State.AddressObjectCodeInCode AND AddressItemType = 5
		|		UNION ALL SELECT TOP 1 1 FROM InformationRegister.AddressClassifier WHERE AddressObjectCodeInCode=State.AddressObjectCodeInCode AND AddressItemType = 6
		|	)
		|");
	
	QueryResult= Query.ExecuteBatch();
	
	CurrentVersions = QueryResult[0].Unload();
	CurrentVersions.Indexes.Add("AddressObject");
	
	VersionDate = '00000000';
	Result      = New ValueList;
	
	For Each StateCode In QueryResult[1].Unload().UnloadColumn("StateCode") Do
		CodeString = Format(StateCode, "ND=2; NZ=; NLZ=");
		VersionString = CurrentVersions.Find(CodeString, "AddressObject");
		Result.Add( ?(VersionString = Undefined, VersionDate, VersionString.VersionDate), CodeString);
	EndDo;
	
	If Result.Count() > 0 Then
		Result.Add("AL", VersionDate);
		Result.Add("SO", VersionDate);
	EndIf;
	
	Return Result;
EndFunction

// Procedure for importing data to address classifier.
//
// Parameters:
//    AddressObjectCode - String  - Address object code in NN format.
//    PathToServerData  - String  - Path to server directory where AC files are stored.
//    ImportFromWeb     - Boolean - If True, data is downloaded from a 1C web server 
//                                  (using a different file naming convention).
//    Version           - Date    - Date and time of the imported version.
//
Procedure ImportClassifierForAddressObject(Val AddressObjectCode, Val PathToServerData, Val ImportFromWeb, Val Version) Export
	
	AddressObjectCode = Left(AddressObjectCode, 2);
	
	AlternateNames = New ValueTable;
	AlternateNames.Columns.Add("Code");
	AlternateNames.Columns.Add("Description");
	AlternateNames.Columns.Add("Abbr");
	AlternateNames.Columns.Add("PostalCode");
	
	AddressInformation = New ValueTable;
	AddressInformation.Columns.Add("Code");
	AddressInformation.Columns.Add("AddressObjectCodeInCode");
	AddressInformation.Columns.Add("Description");
	AddressInformation.Columns.Add("AlternateNames");
	AddressInformation.Columns.Add("Abbr");
	AddressInformation.Columns.Add("PostalCode");
	AddressInformation.Columns.Add("AddressItemType");
	AddressInformation.Columns.Add("CountyCodeInCode");
	AddressInformation.Columns.Add("CityCodeInCode");
	AddressInformation.Columns.Add("SettlementCodeInCode");
	AddressInformation.Columns.Add("StreetCodeInCode");
	AddressInformation.Columns.Add("DataIsCurrentFlag");
	
	IndexByCode = AddressInformation.Indexes.Add("Code");
	
	// File names are converted to uppercase
	
	AlternateNamesFileName = ? (ImportFromWeb, "ALTN", "ALTNAMES");
	//Postfix                = ? (ImportFromWeb, AddressObjectCode, "");
	Postfix                = "";
	
	EventLogMessageText = EventLogMessageText() + "." + NStr("en = 'Importing from files'");
	
	WriteLogEvent(EventLogMessageText, EventLogLevel.Information, , , 
		StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Importing address classifier for state %1 from directory %2'"), 
			AddressObjectCode, PathToServerData
	));
	
	ImportAddressData(AddressObjectCode, 
		PathToServerData + "CLASSF45" + Postfix, AddressInformation, AlternateNames);
	
	ImportAddressData(AddressObjectCode,
		PathToServerData + "STREET45" + Postfix, AddressInformation, AlternateNames, 5);
	
	ImportAddressData(AddressObjectCode,
		PathToServerData + "BUILD45" + Postfix, AddressInformation, AlternateNames, 6);
	
	FillAlternateNames(PathToServerData + AlternateNamesFileName + Postfix, 
		AddressInformation, AlternateNames, ImportFromWeb);
	
	// Aligning code to ensure compatibility
	AddressInformation.Indexes.Delete(IndexByCode);
	For Each Item In AddressInformation Do
		Item.Code = Left(String(Item.Code) + "000000000000000000000", 21);
	EndDo;
	
	// Setting version, executing transaction, writing to log
	BeginTransaction();
	Try
		AddressDataSet = InformationRegisters.AddressClassifier.CreateRecordSet();
		AddressDataSet.Filter.AddressObjectCodeInCode.Set( Number(AddressObjectCode) );
		AddressDataSet.Load(AddressInformation);
		AddressDataSet.Write();
		
		SetClassifierVersion(AddressObjectCode, Version);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
		
	WriteLogEvent(EventLogMessageText, EventLogLevel.Information, , , 
		StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Address classifier for state %1 is imported (%2 records).'"), 
			AddressObjectCode, AddressInformation.Count()
	));
EndProcedure

// Clears address data for the passed address objects.
// 
// Parameters:
//    AddressObjectArray - Array - Each element is a string containing an address object number in NN format.
//
Procedure DeleteAddressData(Val AddressObjectArray) Export
	
	For Each AddressObjectCode In AddressObjectArray Do
		
		BeginTransaction();
		Try
			AddressDataSet = InformationRegisters.AddressClassifier.CreateRecordSet();
			AddressDataSet.Filter.AddressObjectCodeInCode.Set( Number(AddressObjectCode) );
			AddressDataSet.Write();
			
			SetClassifierVersion(AddressObjectCode);
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
			
	EndDo;
	
EndProcedure

// Returns the number of address objects with filled address data.
//
// Returns:
//    Number - Number of filled address objects.
//
Function FilledAddressObjectCount() Export
	
	Query = New Query("
		|SELECT
		|	COUNT(State.AddressObjectCodeInCode) AS ImportedCount
		|FROM
		|	InformationRegister.AddressClassifier AS State
		|WHERE
		|	State.AddressItemType = 1
		|	AND 1 IN (
		|		SELECT TOP 1 
		|			1 
		|		FROM 
		|			InformationRegister.AddressClassifier AS Level2
		|		WHERE 
		|			Level2.AddressObjectCodeInCode = State.AddressObjectCodeInCode AND AddressItemType = 2
		|
		|		UNION ALL 
		|		SELECT TOP 1 
		|			1 
		|		FROM 
		|			InformationRegister.AddressClassifier AS Level3
		|		WHERE 
		|			Level3.AddressObjectCodeInCode = State.AddressObjectCodeInCode AND AddressItemType = 3
		|
		|		UNION ALL 
		|		SELECT TOP 1 
		|			1 
		|		FROM 
		|			InformationRegister.AddressClassifier AS Level4
		|		WHERE 
		|			Level4.AddressObjectCodeInCode = State.AddressObjectCodeInCode AND AddressItemType = 4
		|
		|		UNION ALL 
		|		SELECT TOP 1 
		|			1 
		|		FROM 
		|			InformationRegister.AddressClassifier AS Level5
		|		WHERE 
		|			Level5.AddressObjectCodeInCode = State.AddressObjectCodeInCode AND AddressItemType = 5
		|
		|		UNION ALL 
		|		SELECT TOP 1 
		|			1 
		|		FROM 
		|			InformationRegister.AddressClassifier AS Level6
		|		WHERE 
		|			Level6.AddressObjectCodeInCode = State.AddressObjectCodeInCode AND AddressItemType = 6
		|	)
		|");
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Return Selection.ImportedCount;
	EndIf;
	
	Return 0;
	
EndFunction

// Returns a structure containing address object data.
// 
// Parameters
//    AddressObjectCode - String - address object number, 1 to 89 + 99 in NN format.
//
// Returns:
//    Structure - address object description containing keys:
//        * AddressObjectCode - String - address object code.
//        * Description       - String - address object description.
//        * Abbr              - String - address object abbreviation.
//        * PostalCode        - String - postal code.
//
Function AddressObjectInformation(Val AddressObjectCode) Export
	
	Result = New Structure("AddressObjectCode, Description, Abbr, PostalCode");
	
	If AddressObjectCode = "AL" Then
		Result.AddressObjectCode = "AL";
		Result.Description       = NStr("en = 'Alternate names'");
		Result.Abbr              = "";
		Result.PostalCode        = "";
		
	ElsIf AddressObjectCode = "SO" Then
		Result.AddressObjectCode = "SO";
		Result.Description       = NStr("en = 'Address abbreviations'");
		Result.Abbr              = "";
		Result.PostalCode        = "";
		
	Else
		Classifier = InformationRegisters.AddressClassifier.RegionClassifier();
		If TypeOf(AddressObjectCode) = Type("String") Then
			NumberType = New TypeDescription("Number");
			AddressObjectCode = NumberType.AdjustValue(AddressObjectCode);
		EndIf;
		
		AddressObject = Classifier.Find(AddressObjectCode, "RegionCode");
		If AddressObject <> Undefined Then
			Result.AddressObjectCode = Format(AddressObject.RegionCode, "ND=2; NZ=; NLZ=");
			Result.Description       = AddressObject.Description;
			Result.Abbr              = AddressObject.Abbr;
			Result.PostalCode        = AddressObject.PostalCode;
		EndIf;
		
	EndIf;
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////

// Searches for address classifier records by postal code.
//
// Parameters:
//    PostalCode - String - postal code used for searching.
//
// Returns:
//    Structure - found record description. Contains fields:
//        * Count             - Number - number of found records.
//        * FoundState        - String - if only one state is found.
//        * FoundCounty       - String - if only one county is found.
//        * DataIsCurrentFlag - Number - data-is-current flag if only one record is found.
//        * AddressInStorage  - String - ID of the table of found records saved to a storage.
//
Function FindRecordsByPostalCode(PostalCode) Export
	
	Result = New Structure;
	Result.Insert("DataIsCurrentFlag", 0);
	Result.Insert("FoundState",        "");
	Result.Insert("FoundCounty",       "");
	Result.Insert("Quantity",          0);
	
	// Validating postal code
	If StrLen(PostalCode) <> 6 Then
		Return Result;
	EndIf;
	
	// 1. Finding records (and parent item records) by postal code, saving results to temporary tables 
	TempTablesManager = New TempTablesManager;
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.Text = "
		|SELECT
		|	AddressClassifier.AddressItemType AS AddressItemType,
		|	AddressClassifier.Code                  AS Code,
		|
		|	AddressClassifier.Description + "" "" + AddressClassifier.Abbr AS Description,
		|
		|	AddressClassifier.DataIsCurrentFlag       AS DataIsCurrentFlag,
		|	AddressClassifier.AddressObjectCodeInCode AS AddressObjectCodeInCode,
		|	AddressClassifier.CountyCodeInCode        AS CountyCodeInCode,
		|	AddressClassifier.CityCodeInCode          AS CityCodeInCode,
		|	AddressClassifier.SettlementCodeInCode    AS SettlementCodeInCode,
		|	AddressClassifier.StreetCodeInCode        AS StreetCodeInCode
		|INTO 
		|	Addresses
		|FROM
		|	InformationRegister.AddressClassifier AS AddressClassifier
		|WHERE
		|	AddressClassifier.PostalCode = &PostalCode
		|INDEX BY
		|	AddressObjectCodeInCode, CountyCodeInCode, CityCodeInCode, SettlementCodeInCode, StreetCodeInCode
		|";
	Query.SetParameter("PostalCode", PostalCode);
	Query.Execute();
	SplitAddressItemsToTempTables(TempTablesManager);
	
	// 2. Getting state lists and county lists
	StateQuery = New Query;
	StateQuery.TempTablesManager = TempTablesManager;
	StateQuery.Text = "
		|SELECT DISTINCT
		|	States.StateCode         AS StateCode,
		|	States.Description       AS Description,
		|	States.DataIsCurrentFlag AS DataIsCurrentFlag
		|FROM
		|	States AS States
		|";
	StateSelection = StateQuery.Execute().Select();
	
	CountyQuery = New Query;
	CountyQuery.TempTablesManager = TempTablesManager;
	CountyQuery.Text = "
		|SELECT DISTINCT
		|	Counties.CountyCode        AS CountyCode,
		|	Counties.Description       AS Description,
		|	Counties.DataIsCurrentFlag AS DataIsCurrentFlag
		|FROM
		|	Counties AS Counties
		|";
	CountiesSelection = CountyQuery.Execute().Select();
	
	// 3. Making decision based on the number of found states and counties.
	//    If no states or counties are found, no addresses match the postal code, ending the search.
	If StateSelection.Count() = 0 Then
		Return Result;
		// If multiple states are found, user will need to specify state and county
	ElsIf StateSelection.Count() > 1 Then
		DetailsTillLevel = 1;
		Result.FoundState = "";
		Result.FoundCounty = "";
		// If multiple counties are found, user will need to specify county
	ElsIf CountiesSelection.Count() <> 1 Then // StateSelection.Count() = 1
		DetailsTillLevel = 2;
		StateSelection.Next();
		Result.FoundState = StateSelection.Description;
		Result.FoundCounty = "";
		// If only one state and one county are found, user will not need to specify any more data
	ElsIf CountiesSelection.Count() = 1 Then
		DetailsTillLevel = 3;
		StateSelection.Next();
		Result.FoundState = StateSelection.Description;
		CountiesSelection.Next();
		Result.FoundCounty = CountiesSelection.Description;
	EndIf;
	
	// 4. Generating the list of found addresses with appropriate detail level
	AddressQuery = New Query;
	AddressQuery.TempTablesManager = TempTablesManager;
	AddressQuery.Text = "
		|SELECT
		|	Addresses.AddressItemType   AS AddressItemType,
		|	Addresses.Code              AS Code,
		|	Addresses.DataIsCurrentFlag AS DataIsCurrentFlag,
		|
		|	ISNULL(Streets.Description, """")     AS Street,
		|	ISNULL(Cities.Description, """")      AS City,
		|	ISNULL(Settlements.Description, """") AS Settlement,
		|	ISNULL(Counties.Description, """")    AS County,
		|	ISNULL(States.Description, """")      AS State,
		|	""""                                  AS Description
		|FROM
		|	Addresses AS Addresses
		|
		|LEFT JOIN 
		|	Settlements AS Settlements
		|ON 
		|	Addresses.Code = Settlements.Code
		|
		|LEFT JOIN 
		|	Cities AS Cities
		|ON 
		|	Addresses.Code = Cities.Code
		|
		|LEFT JOIN
		|	Counties AS Counties
		|ON 
		|	Addresses.Code = Counties.Code
		|
		|LEFT JOIN 
		|	States AS States
		|ON 
		|	Addresses.Code = States.Code
		|
		|LEFT JOIN 
		|	Streets AS Streets
		|ON 
		|	Addresses.Code = Streets.Code
		|
		|ORDER BY
		|	Street,
		|	Code
		|";
	AddressSelection = AddressQuery.Execute().Select();
	
	// 5. If only one address is found, the result contains address components.
	// If multiple addresses are found, an address table with detailed address descriptions
	// (based on the detail level) is created.
	Quantity = AddressSelection.Count();
	Result.Insert("Quantity", Quantity);
	If Quantity = 1 Then
		AddressSelection.Next();
		Result.Insert("State",      AddressSelection.State);
		Result.Insert("County",     AddressSelection.County);
		Result.Insert("City",       AddressSelection.City);
		Result.Insert("Settlement", AddressSelection.Settlement);
		Result.Insert("Street",     AddressSelection.Street);
		Result.Insert("DataIsCurrentFlag", AddressSelection.DataIsCurrentFlag);
		
	ElsIf Quantity > 1 Then
		FoundByPostalCodeRecords = New ValueTable;
		FoundByPostalCodeRecords.Columns.Add("Street",      New TypeDescription("String"));
		FoundByPostalCodeRecords.Columns.Add("Description", New TypeDescription("String"));
		FoundByPostalCodeRecords.Columns.Add("Code",        New TypeDescription("Number"));
		FoundByPostalCodeRecords.Columns.Add("DataIsCurrentFlag", New TypeDescription("Number"));
		FoundByPostalCodeRecords.Columns.Add("AddressItemType",   New TypeDescription("Number"));
		
		While AddressSelection.Next() Do
			// Skipping repeatedly found streets
			If AddressSelection.AddressItemType = 6 
			     And FoundByPostalCodeRecords.Find(AddressSelection.Street, "Street")<>Undefined
			Then
				Continue;
			EndIf;
			
			NewRow = FoundByPostalCodeRecords.Add();
			NewRow.Code = AddressSelection.Code;
			NewRow.DataIsCurrentFlag = AddressSelection.DataIsCurrentFlag;
			NewRow.AddressItemType = AddressSelection.AddressItemType;
			NewRow.Street = ?(AddressSelection.AddressItemType > 4, AddressSelection.Street, NStr("en='< No street >'"));
	
			NewRow.Description = GetDetailsByAddressItems(DetailsTillLevel,
				AddressSelection.State, AddressSelection.County, AddressSelection.City, AddressSelection.Settlement);
		EndDo;
		
		AddressInStorage = PutToTempStorage(FoundByPostalCodeRecords, New UUID);
		Result.Insert("AddressInStorage", AddressInStorage);
	EndIf;
	
	Return Result;
EndFunction

// Gets address item components by its code.
//
// Parameters:
//    AddressItemCode - Number    - address item code used to search for address components.
//    Result          - Structure - contains search results. Fields:
//        DataIsCurrentFlag - Number - data-is-current flag for the found address.
//        State             - String - found state name.
//        County            - String - found county name. 
//        City              - String - found city name.
//        Settlement        - String - found settlement name.
//        Street            - String - found street name.
//
Procedure GetComponentsToStructureByAddressItemCode(AddressItemCode, Result) Export
	
	// 1. Placing address and address items into temporary tables
	TempTablesManager = New TempTablesManager;
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.Text = "
		|SELECT
		|	AddressClassifier.AddressItemType AS AddressItemType,
		|	AddressClassifier.Code            AS Code,
		|
		|	AddressClassifier.Description + "" "" + AddressClassifier.Abbr AS Description,
		|
		|	AddressClassifier.DataIsCurrentFlag       AS DataIsCurrentFlag,
		|	AddressClassifier.AddressObjectCodeInCode AS AddressObjectCodeInCode,
		|	AddressClassifier.CountyCodeInCode        AS CountyCodeInCode,
		|	AddressClassifier.CityCodeInCode          AS CityCodeInCode,
		|	AddressClassifier.SettlementCodeInCode    AS SettlementCodeInCode,
		|	AddressClassifier.StreetCodeInCode        AS StreetCodeInCode
		|INTO 
		|	Addresses
		|FROM
		|	InformationRegister.AddressClassifier AS AddressClassifier
		|WHERE
		|	AddressClassifier.Code = &AddressItemCode
		|";
	Query.SetParameter("AddressItemCode", AddressItemCode);
	Query.Execute();
	SplitAddressItemsToTempTables(TempTablesManager);
	
	// 2. Getting address item names from the temporary tables
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.Text = "
		|SELECT
		|	Addresses.Code                        AS Code,
		|	ISNULL(States.Description, """")      AS State,
		|	ISNULL(Counties.Description, """")    AS County,
		|	ISNULL(Cities.Description, """")      AS City,
		|	ISNULL(Settlements.Description, """") AS Settlement,
		|	ISNULL(Streets.Description, """")     AS Street,
		|	Addresses.DataIsCurrentFlag           AS DataIsCurrentFlag
		|FROM
		|	Addresses AS Addresses
		|
		|LEFT JOIN
		|	States AS States
		|ON 
		|	Addresses.AddressObjectCodeInCode = States.AddressObjectCodeInCode
		|
		|LEFT JOIN
		|	Counties AS Counties
		|ON 
		|	Addresses.CountyCodeInCode = Counties.CountyCodeInCode
		|
		|LEFT JOIN
		|	Cities AS Cities
		|ON 
		|	Addresses.CityCodeInCode = Cities.CityCodeInCode
		|
		|LEFT JOIN
		|	Settlements AS Settlements
		|ON 
		|	Addresses.SettlementCodeInCode = Settlements.SettlementCodeInCode
		|
		|LEFT JOIN 
		|	Streets AS Streets
		|ON 
		|	Addresses.StreetCodeInCode = Streets.StreetCodeInCode
		|";
	QueryResult = Query.Execute();
	
	// 3. Displaying this data as result
	If QueryResult.IsEmpty() Then
		Result.Insert("State", "");
		Result.Insert("County", "");
		Result.Insert("City", "");
		Result.Insert("Settlement", "");
		Result.Insert("Street", "");
		Result.Insert("DataIsCurrentFlag", 0);
	Else
		Selection = QueryResult.Select();
		Selection.Next();
		Result.Insert("State", Selection.State);
		Result.Insert("County", Selection.County);
		Result.Insert("City", Selection.City);
		Result.Insert("Settlement", Selection.Settlement);
		Result.Insert("Street", Selection.Street);
		Result.Insert("DataIsCurrentFlag", Selection.DataIsCurrentFlag);
	EndIf;
	
EndProcedure

// Analyzing the passed address items, determining whether address classifier is available for these items. 
//
// Parameters: 
//    AddressItemCode - Number - address item code used to search for address components.
//    Building        - String - building number (if required).
//    Unit            - String - unit number (if required).
//    Apartment       - String - apartment number (if required).
//
// Returns:
//    Structure - result description, including the following fields:
//      * PostalCode - String - address postal code based on the passed parameters.
//      * State      - String - state (based on the passed code).
//      * County     - String - county (based on the passed code).
//      * City       - String - city (based on the passed code).
//      * Settlement - String - settlement (based on the passed code).
//      * Street     - String - street (based on the passed code).
//      * Building   - String - passed building number.
//      * Unit       - String - passed unit number.
//      * Apartment  - String - passed apartment number.
//
Function AddressStructure(AddressItemCode, Building = "", Unit = "", Apartment = "") Export
	
	AddressStructure = New Structure();
	GetComponentsToStructureByAddressItemCode(AddressItemCode, AddressStructure);
	
	// Determining postal code based on code
	Query = New Query;
	Query.Text = "
		|SELECT
		|	AddressClassifier.PostalCode AS PostalCode
		|FROM
		|	InformationRegister.AddressClassifier AS AddressClassifier
		|WHERE
		|	AddressClassifier.Code = &Code
		|";
	Query.SetParameter("Code", AddressItemCode);
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		PostalCode = AddressPostalCode(AddressStructure.State, 
			AddressStructure.County, AddressStructure.City, AddressStructure.Settlement, AddressStructure.Street, 
			Building, Unit);
	Else
		Selection = QueryResult.Select();
		Selection.Next();
		PostalCode = Selection.PostalCode;
	EndIf;
	AddressStructure.Insert("PostalCode", PostalCode);
	
	AddressStructure.Insert("Building", Building);
	AddressStructure.Insert("Unit", Unit);
	AddressStructure.Insert("Apartment", Apartment);
	Return AddressStructure;
	
EndFunction

// Determines postal code based on the passed values for state, county, city, settlement, street, building, and unit.
//
// Parameters: 
//    StateName        - String    - state name, including name and abbreviation.
//    CountyName       - String    - county name, including name and abbreviation. 
//    CityName         - String    - city name, including name and abbreviation. 
//    SettlementName   - String    - settlement name, including name and abbreviation.
//    StreetName       - String    - street name, including name and abbreviation.
//    BuildingNumber   - String    - building number.
//    UnitNumber       - String    - unit number.
//    PostalCodeParent - Structure - filled by the found address item data.
//
// Returns:
//    String - six-digit postal code.
//
Function AddressPostalCode(Val StateName, Val CountyName, Val CityName, Val SettlementName, Val StreetName, Val BuildingNumber, Val UnitNumber, PostalCodeParent = Undefined) Export

	PostalCodeParent = AddressClassifierClientServer.EmptyAddressStructure();
	
	AddressObj = New Structure;
	AddressObj.Insert("PostalCode",     "-");	// Intentionally invalid postal code, used for search purposes
	AddressObj.Insert("State",          StateName);
	AddressObj.Insert("County",         CountyName);
	AddressObj.Insert("City",           CityName);
	AddressObj.Insert("Settlement",     SettlementName);
	AddressObj.Insert("Street",         StreetName);
	AddressObj.Insert("BuildingNumber", BuildingNumber);
	AddressObj.Insert("UnitNumber",     UnitNumber);

	AnalysisResult = AddressComplianceToClassifierAnalysis(AddressObj);
	
	If AnalysisResult.Options.Count() = 0 Then
		// Nothing found
		Return "";
	EndIf;
	Option = AnalysisResult.Options[0];
	
	// Restoring data based on the ID code in PostalCodeParent
	Query = New Query( " 
		|SELECT TOP 1
		|	AddressClassifier.Code                     AS Code,
		|	AddressClassifier.AddressObjectCodeInCode  AS AddressObjectCodeInCode,
		|	AddressClassifier.Description              AS Description,
		|	AddressClassifier.Abbr                     AS Abbr,
		|	AddressClassifier.PostalCode               AS PostalCode,
		|	AddressClassifier.AddressItemType          AS AddressItemType,
		|	AddressClassifier.CountyCodeInCode         AS CountyCodeInCode,
		|	AddressClassifier.CityCodeInCode           AS CityCodeInCode,
		|	AddressClassifier.SettlementCodeInCode     AS SettlementCodeInCode,
		|	AddressClassifier.StreetCodeInCode         AS StreetCodeInCode,
		|	AddressClassifier.DataIsCurrentFlag        AS DataIsCurrentFlag
		|FROM
		|	InformationRegister.AddressClassifier AS AddressClassifier
		|WHERE
		|	AddressClassifier.Code = &Code
		|");
	Query.SetParameter("Code", Option.Code);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		FillPropertyValues(PostalCodeParent, Selection);
	EndIf;
	
	Return Option.PostalCode;
EndFunction

// Autocompletion handler for address input field.
//
// Parameters:
//    Text       - String - text entered by user into the address input field.
//    State      - String - previously entered state name.
//    County     - String - previously entered county name. 
//    City       - String - previously entered city name.
//    Settlement - String - previously entered settlement name.
//    ItemLevel  - Number - address input item ID:
//                          1 - state, 2 - county, 3 - city, 4 - settlement, 5 - street, 0 - other.
//    DataIsCurrentFlag - Number - item's data-is-current flag.
//
// Returns:
//    ValueList - autocompletion data.
//    Undefined - used when no data is available.
//
Function AddressItemTextAutoComplete(Text, State, County, City, Settlement, ItemLevel, DataIsCurrentFlag = 0) Export
	
	RestrictionStructure = GetRestrictionStructureByAddress(
		State, County, City, Settlement, "", ItemLevel);
	QueryResult = GetAutoCompleteQueryResultForRegister(Text, RestrictionStructure, 51);
	
	Quantity = QueryResult.Count();
	If (Quantity = 0) Then
		Return Undefined;
	EndIf;
	
	Result = New ValueList;
	For Each ResultRow In QueryResult Do
		FullDescr = TrimAll(ResultRow.Description) + " " + TrimAll(ResultRow.Abbr);
		ResultStructure = New Structure;
		ResultStructure.Insert("Value", FullDescr);
		ResultStructure.Insert("DeletionMark", (ResultRow.DataIsCurrentFlag <> 0));
		If ResultStructure.DeletionMark Then
			WarningText = NStr("en='""%FullDescr%"" is obsolete.'");
			WarningText = StrReplace(WarningText, "%FullDescr%", FullDescr);
			ResultStructure.Insert("Warning", WarningText);
		EndIf;
		Result.Add(ResultStructure);
	EndDo;
	
	Return Result;
	
EndFunction

// Obsolete. Use AddressComplianceToClassifierAnalysis instead.
//
// Checks the passed postal code, state, county, city, settlement, street, building,
// and unit for compliance with the address classifier; displays all fields for each found address item.
//
// Parameters: 
//    PostalCode     - String - postal code.
//    StateName      - String - state name, including name and abbreviation.
//    CountyName     - String - county name, including name and abbreviation.
//    CityName       - String - city name, including name and abbreviation.
//    SettlementName - String - settlement name, including name and abbreviation. 
//    StreetName     - String - street name, including name and abbreviation.
//    BuildingNumber - String - number of building (household, and so on).
//    UnitNumber     - String - unit number.
//
// Returns:
//    Structure - description of check results:
//        PostalCode     - Structure - found postal code field structure.
//        State          - Structure - found state field structure.
//        County         - Structure - found county field structure.
//        City           - Structure - found city field structure.
//        Settlement     - Structure - found settlement field structure.
//        Street         - Structure - found street field structure.
//        Building       - Structure - found building field structure.
//        HasErrors      - Boolean   - this flag specifies if any errors occurred during the check.
//        ErrorStructure - Structure - structure where the key is item name 
//                                     and the value is detailed error text.
//
Function CheckAddressByAC(Val PostalCode = "", Val StateName = "", Val CountyName = "", Val CityName = "", Val SettlementName = "", Val StreetName = "", Val BuildingNumber = "", Val UnitNumber = "") Export
	
	AddressObj = New Structure;
	
	AddressObj.Insert("PostalCode",     PostalCode);
	AddressObj.Insert("State",          StateName);
	AddressObj.Insert("County",         CountyName);
	AddressObj.Insert("City",           CityName);
	AddressObj.Insert("Settlement",     SettlementName);
	AddressObj.Insert("Street",         StreetName);
	AddressObj.Insert("BuildingNumber", BuildingNumber);
	AddressObj.Insert("UnitNumber",     UnitNumber);

	AnalysisResult = AddressComplianceToClassifierAnalysis(AddressObj);
	
	HasErrors = AnalysisResult.Errors.Count() > 0;
	Result = New Structure;
	Result.Insert("HasErrors",       HasErrors);
	Result.Insert("ErrorsStructure", AnalysisResult.Errors);
	
	Result.Insert("PostalCode", "");
	Result.Insert("State",      AddressClassifierClientServer.EmptyAddressStructure() );
	Result.Insert("County",     AddressClassifierClientServer.EmptyAddressStructure() );
	Result.Insert("City",       AddressClassifierClientServer.EmptyAddressStructure() );
	Result.Insert("Settlement", AddressClassifierClientServer.EmptyAddressStructure() );
	Result.Insert("Street",     AddressClassifierClientServer.EmptyAddressStructure() );
	Result.Insert("Building",   AddressClassifierClientServer.EmptyAddressStructure() );
	
	If AnalysisResult.Options.Count() = 0 Then
		// Nothing found
		Return Result;
	EndIf;
	
	// Looking up data by ID code
	Option = AnalysisResult.Options.Find(PostalCode, "PostalCode");
	If Option = Undefined Then
		// No exact matches, returning the first inexact match
		Option = AnalysisResult.Options[0];
		Result.Insert("PostalCode", Option.PostalCode);
	Else
		// Exact match
		Result.Insert("PostalCode", PostalCode);
	EndIf;
	
	Query = New Query("
		|SELECT TOP 1
		|	Address.Code                    AS Code,
		|	Address.Description             AS Description,
		|	Address.Abbr                    AS Abbr,
		|	Address.PostalCode              AS PostalCode,
		|	Address.AddressObjectCodeInCode AS AddressObjectCodeInCode,
		|	Address.CountyCodeInCode        AS CountyCodeInCode,
		|	Address.CityCodeInCode          AS CityCodeInCode,
		|	Address.SettlementCodeInCode    AS SettlementCodeInCode,
		|	Address.StreetCodeInCode        AS StreetCodeInCode,
		|	Address.DataIsCurrentFlag       AS DataIsCurrentFlag,
		|	Address.AddressItemType         AS AddressItemType,
		|
		|	Street.Code                     AS StreetCode,
		|	Street.Description              AS StreetDescription,
		|	Street.Abbr                     AS StreetAbbr,
		|	Street.PostalCode               AS StreetPostalCode,
		|	Street.AddressObjectCodeInCode  AS StreetAddressObjectCodeInCode,
		|	Street.CountyCodeInCode         AS StreetCountyCodeInCode,
		|	Street.CityCodeInCode           AS StreetCityCodeInCode,
		|	Street.SettlementCodeInCode     AS StreetSettlementCodeInCode,
		|	Street.StreetCodeInCode         AS StreetStreetCodeInCode,
		|	Street.DataIsCurrentFlag        AS StreetDataIsCurrentFlag,
		|	Street.AddressItemType          AS StreetAddressItemType,
		|
		|	Settlement.Code                     AS SettlementCode,
		|	Settlement.Description              AS SettlementDescription,
		|	Settlement.Abbr                     AS SettlementAbbr,
		|	Settlement.PostalCode               AS SettlementPostalCode,
		|	Settlement.AddressObjectCodeInCode  AS SettlementAddressObjectCodeInCode,
		|	Settlement.CountyCodeInCode         AS SettlementCountyCodeInCode,
		|	Settlement.CityCodeInCode           AS SettlementCityCodeInCode,
		|	Settlement.SettlementCodeInCode     AS SettlementSettlementCodeInCode,
		|	Settlement.StreetCodeInCode         AS SettlementStreetCodeInCode,
		|	Settlement.DataIsCurrentFlag        AS SettlementDataIsCurrentFlag,
		|	Settlement.AddressItemType          AS SettlementAddressItemType,
		|
		|	City.Code                     AS CityCode,
		|	City.Description              AS CityDescription,
		|	City.Abbr                     AS CityAbbr,
		|	City.PostalCode               AS CityPostalCode,
		|	City.AddressObjectCodeInCode  AS CityAddressObjectCodeInCode,
		|	City.CountyCodeInCode         AS CityCountyCodeInCode,
		|	City.CityCodeInCode           AS CityCityCodeInCode,
		|	City.SettlementCodeInCode     AS CitySettlementCodeInCode,
		|	City.StreetCodeInCode         AS CityStreetCodeInCode,
		|	City.DataIsCurrentFlag        AS CityDataIsCurrentFlag,
		|	City.AddressItemType          AS CityAddressItemType,
		|
		|	County.Code                     AS CountyCode,
		|	County.Description              AS CountyDescription,
		|	County.Abbr                     AS CountyAbbr,
		|	County.PostalCode               AS CountyPostalCode,
		|	County.AddressObjectCodeInCode  AS CountyAddressObjectCodeInCode,
		|	County.CountyCodeInCode         AS CountyCountyCodeInCode,
		|	County.CityCodeInCode           AS CountyCityCodeInCode,
		|	County.SettlementCodeInCode     AS CountySettlementCodeInCode,
		|	County.StreetCodeInCode         AS CountyStreetCodeInCode,
		|	County.DataIsCurrentFlag        AS CountyDataIsCurrentFlag,
		|	County.AddressItemType          AS CountyAddressItemType,
		|
		|	State.Code                     AS StateCode,
		|	State.Description              AS StateDescription,
		|	State.Abbr                     AS StateAbbr,
		|	State.PostalCode               AS StatePostalCode,
		|	State.AddressObjectCodeInCode  AS StateAddressObjectCodeInCode,
		|	State.CountyCodeInCode         AS StateCountyCodeInCode,
		|	State.CityCodeInCode           AS StateCityCodeInCode,
		|	State.SettlementCodeInCode     AS StateSettlementCodeInCode,
		|	State.StreetCodeInCode         AS StateStreetCodeInCode,
		|	State.DataIsCurrentFlag        AS StateDataIsCurrentFlag,
		|	State.AddressItemType          AS StateAddressItemType
		|
		|FROM
		|	InformationRegister.AddressClassifier AS Address
		|
		|LEFT JOIN
		|	InformationRegister.AddressClassifier AS Street
		|ON
		|	  Street.AddressItemType            = 5
		|	AND Street.AddressObjectCodeInCode  = Address.AddressObjectCodeInCode
		|	AND Street.CountyCodeInCode         = Address.CountyCodeInCode
		|	AND Street.CityCodeInCode           = Address.CityCodeInCode
		|	AND Street.SettlementCodeInCode     = Address.SettlementCodeInCode
		|	AND Street.StreetCodeInCode         = Address.StreetCodeInCode
		|
		|LEFT JOIN
		|	InformationRegister.AddressClassifier AS Settlement
		|ON
		|	  Settlement.AddressItemType            = 4
		|	AND Settlement.AddressObjectCodeInCode  = Address.AddressObjectCodeInCode
		|	AND Settlement.CountyCodeInCode         = Address.CountyCodeInCode
		|	AND Settlement.CityCodeInCode           = Address.CityCodeInCode
		|	AND Settlement.SettlementCodeInCode     = Address.SettlementCodeInCode
		|	AND Settlement.StreetCodeInCode         = 0
		|
		|LEFT JOIN
		|	InformationRegister.AddressClassifier AS City
		|ON
		|	  City.AddressItemType            = 3
		|	AND City.AddressObjectCodeInCode  = Address.AddressObjectCodeInCode
		|	AND City.CountyCodeInCode         = Address.CountyCodeInCode
		|	AND City.CityCodeInCode           = Address.CityCodeInCode
		|	AND City.SettlementCodeInCode     = 0
		|	AND City.StreetCodeInCode         = 0
		|
		|LEFT JOIN
		|	InformationRegister.AddressClassifier AS County
		|ON
		|	  County.AddressItemType            = 2
		|	AND County.AddressObjectCodeInCode  = Address.AddressObjectCodeInCode
		|	AND County.CountyCodeInCode         = Address.CountyCodeInCode
		|	AND County.CityCodeInCode           = 0
		|	AND County.SettlementCodeInCode     = 0
		|	AND County.StreetCodeInCode         = 0
		|
		|LEFT JOIN
		|	InformationRegister.AddressClassifier AS State
		|ON
		|	  State.AddressItemType            = 1
		|	AND State.AddressObjectCodeInCode  = Address.AddressObjectCodeInCode
		|	AND State.CountyCodeInCode         = 0
		|	AND State.CityCodeInCode           = 0
		|	AND State.SettlementCodeInCode     = 0
		|	AND State.StreetCodeInCode         = 0
		|
		|WHERE
		|	Address.Code = &Code
		|");
	Query.SetParameter("Code", Option.Code);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		FillAddressStructureBySelection(Result.State,      Selection, "State");
		FillAddressStructureBySelection(Result.County,     Selection, "County");
		FillAddressStructureBySelection(Result.City,       Selection, "City");
		FillAddressStructureBySelection(Result.Settlement, Selection, "Settlement");
		FillAddressStructureBySelection(Result.Street,     Selection, "Street");
		FillAddressStructureBySelection(Result.Building,   Selection);
	EndIf;
	
	Return Result;
EndFunction

// Validating address that may include non-unique fields.
//
// Parameters:
//    AddressObj - Structure - Contains address fields:
//      * Index          - String - address part, including name and abbreviation.
//      * State          - String - address part, including name and abbreviation.
//      * County         - String - address part, including name and abbreviation. 
//      * City           - String - address part, including name and abbreviation. 
//      * Settlement     - String - address part, including name and abbreviation. 
//      * Street         - String - address part, including name and abbreviation.
//      * BuildingNumber - String - building number (compatible with address classifier).
//      * UnitNumber     - String - building unit number (compatible with address classifier).
//
// Returns:
//     Structure - Analysis results. Contains fields:
//       * Errors  - Structure  - Error description, key is address part ID 
//                                (field name from AddressObject), value is error text. 
//                                If no errors are found, the function returns an empty structure.
//       * Options - ValueTable - Description of found options. Contains columns:
//           ** Code       - Number - Classifier code of the object option.
//           ** PostalCode - String - Postal code of the object option.
//
Function AddressComplianceToClassifierAnalysis(Val AddressObj) Export
	Result = New Structure("Options, Errors", New ValueTable, New Structure);
	
	AddressOptions = Result.Options;
	AddressOptions.Columns.Add("Code",       New TypeDescription("Number"));
	AddressOptions.Columns.Add("PostalCode", New TypeDescription("String"));
	AddressOptions.Indexes.Add("Code");
	AddressOptions.Indexes.Add("PostalCode");
	
	Errors = Result.Errors;
	
	// State is mandatory; if not specified, cancel validation
	If IsBlankString(AddressObj.State) Then
		Errors.Insert("State", NStr("en = 'The address does not contain state.'"));
		Return Result;
	EndIf;
	
	// 1. Checking the object (up to street name) for compliance with address classifier
	
	Query = New Query;
	
	// State
	NameParts = DescriptionAndAbbreviation(AddressObj.State);
	Query.SetParameter("StateName", NameParts.Description);
	Query.SetParameter("StateAbbr", NameParts.Abbr);
	SortingLine = "";
	
	// County
	CountySpecified = Not IsBlankString(AddressObj.County);
	If CountySpecified Then
		NameParts = DescriptionAndAbbreviation(AddressObj.County);
		Query.SetParameter("CountyName", NameParts.Description);
		Query.SetParameter("CountyAbbr", NameParts.Abbr);
		
		TableCounty = "
			|LEFT
			|	JOIN InformationRegister.AddressClassifier AS
			|County
			|	ON County.Description
			|	 = &CountyName AND
			|	County.Abbr = &CountyAbbr AND
			|	County.AddressItemType = 2 AND County.AddressObjectCodeInCode =
			|	State.AddressObjectCodeInCode AND County.CityCodeInCode = 0 AND County.SettlementCodeInCode
			|	= 0 AND
			|	County.StreetCodeInCode = 0
			|";
			
		SortingLine = SortingLine + ", County.Description DESC, County.Abbr DESC";
	Else
		TableCounty = "";
	EndIf;
	
	// City
	CitySpecified = Not IsBlankString(AddressObj.City);
	If CitySpecified Then
		NameParts = DescriptionAndAbbreviation(AddressObj.City);
		Query.SetParameter("CityName", NameParts.Description);
		Query.SetParameter("CityAbbr", NameParts.Abbr);
		
		TableCity = "
			|LEFT
			|	JOIN InformationRegister.AddressClassifier
			|AS
			|	City ON City.Description
			|	 = &CityName
			|	AND City.Abbr = &CityAbbr
			|	AND City.AddressItemType = 3 AND City.AddressObjectCodeInCode
			|	= State.AddressObjectCodeInCode AND City.CountyCodeInCode = " + ?(CountySpecified, "County.CountyCodeInCode", "0") + "
			|	AND City.SettlementCodeInCode =
			|	0 AND City.StreetCodeInCode = 0
			|";
			
		SortingLine = SortingLine + ", City.Description DESC, City.Abbr DESC";
	Else
		TableCity = "";
	EndIf;
	
	// Settlement
	SettlementSpecified = Not IsBlankString(AddressObj.Settlement);
	If SettlementSpecified Then
		NameParts = DescriptionAndAbbreviation(AddressObj.Settlement);
		Query.SetParameter("SettlementName", NameParts.Description);
		Query.SetParameter("SettlementAbbr", NameParts.Abbr);
		
		TableSettlement = "
			|LEFT
			|	JOIN InformationRegister.AddressClassifier
			|AS
			|	Settlement ON Settlement.Description
			|	= &SettlementName AND Settlement.Abbr
			|	= &SettlementAbbr AND Settlement.AddressItemType
			|	= 4 AND Settlement.AddressObjectCodeInCode = State.AddressObjectCodeInCode
			|	AND Settlement.CountyCodeInCode = " + ?(CountySpecified, "County.CountyCodeInCode", "0") + "
			|	AND Settlement.CityCodeInCode   = " + ?(CitySpecified, "City.CityCodeInCode", "0") + "
			|	AND Settlement.StreetCodeInCode = 0
			|";
			
		SortingLine = SortingLine + ", Settlement.Description DESC, Settlement.Abbr DESC";
	Else
		TableSettlement = "";
	EndIf;
	
	// Street
	StreetSpecified = Not IsBlankString(AddressObj.Street);
	If StreetSpecified Then
		NameParts = DescriptionAndAbbreviation(AddressObj.Street);
		Query.SetParameter("StreetName", NameParts.Description);
		Query.SetParameter("StreetAbbr",   NameParts.Abbr);
		
		TableStreet = "
			|LEFT
			|	JOIN InformationRegister.AddressClassifier AS
			|Street
			|	ON Street.Description =
			|	&StreetName AND Street.Abbr =
			|	&StreetAbbr AND Street.AddressItemType =
			|	5 AND Street.AddressObjectCodeInCode = State.AddressObjectCodeInCode AND
			|	Street.CountyCodeInCode = " + ?(CountySpecified, "County.CountyCodeInCode", "0") + "
			|	AND Street.CityCodeInCode = " + ?(CitySpecified, "City.CityCodeInCode", "0") + "
			|	AND Street.SettlementCodeInCode = " + ?(SettlementSpecified, "Settlement.SettlementCodeInCode", "0") + "
			|";
			
		SortingLine = SortingLine + ", Street.Description DESC, Street.Abbr DESC";
	Else
		TableStreet = "";
	EndIf;
	
	Query.Text = "
		|SELECT
		|	"""" AS PostalCode,
		|
		|	State.Description AS StateName, State.Abbr AS StateAbbr,	// For validation only
		|	State.AddressObjectCodeInCode AS AddressObjectCodeInCode,
		|	State.PostalCode              AS StatePostalCode
		|
		|" + ?(CountySpecified, "
		|		, County.Description AS CountyName, County.Abbr AS CountyAbbr	// For validation only
		|		, County.PostalCode       AS CountyPostalCode
		|		, County.CountyCodeInCode AS CountyCodeInCode
		|		, CASE WHEN County.Description IS NULL THEN TRUE ELSE FALSE END AS CountyNotFound
		|	", "
		|		, """" AS CountyPostalCode
		|		, 0    AS CountyCodeInCode
		|		, FALSE AS CountyNotFound
		|") + "
		|" + ?(CitySpecified, "
		|		, City.Description AS CityName, City.Abbr AS CityAbbr	// For validation only
		|		, City.PostalCode     AS CityPostalCode
		|		, City.CityCodeInCode AS CityCodeInCode
		|		, CASE WHEN City.Description IS NULL THEN TRUE ELSE FALSE END AS CityNotFound
		|	", "
		|		, """" AS CityPostalCode
		|		, 0    AS CityCodeInCode
		|		, FALSE AS CityNotFound
		|") + "
		|" + ?(SettlementSpecified, "
		|		, Settlement.Description AS SettlementName, Settlement.Abbr AS SettlementAbbr	// For validation only
		|		, Settlement.PostalCode           AS SettlementPostalCode
		|		, Settlement.SettlementCodeInCode AS SettlementCodeInCode
		|		, CASE WHEN Settlement.Description IS NULL THEN TRUE ELSE FALSE END AS SettlementNotFound
		|	", "
		|		, """"  AS SettlementPostalCode
		|		, 0     AS SettlementCodeInCode
		|		, FALSE AS SettlementNotFound
		|") + "
		|" + ?(StreetSpecified, "
		|		, Street.Description AS StreetName, Street.Abbr AS StreetAbbr	// For validation only
		|		, Street.PostalCode       AS StreetPostalCode
		|		, Street.StreetCodeInCode AS StreetCodeInCode
		|		, CASE WHEN Street.Description IS NULL THEN TRUE ELSE FALSE END AS StreetNotFound
		|	", "
		|		, """" AS StreetPostalCode
		|		, 0    AS StreetCodeInCode
		|		, FALSE AS StreetNotFound
		|") + "
		|
		|," + ?(StreetSpecified, "Street.Code",
				?(SettlementSpecified, "Settlement.Code",
					?(CitySpecified, "City.Code",
						?(CountySpecified, "County.Code",
							"State.Code")))) + "
		| AS ClassifierCode
		|
		|FROM	
		|	InformationRegister.AddressClassifier AS State
		|" + TableCounty + "
		|" + TableCity + "
		|" + TableSettlement + "
		|" + TableStreet + "
		|WHERE
		|	State.Description
		|	= &StateName AND State.Abbr
		|= &StateAbbr
		|	ORDER BY State.Description DESC, State.Abbr DESC
		|" + SortingLine + "
		|";
		
	Selection = Query.Execute().Select();
	
	// Returning multiple records is a valid response. Within a hierarchy level, non-unique names are allowed.
	HasRecords = Selection.Next();
	If Not HasRecords Then
		// Region not specified, cancel search
		Errors.Insert("State", ClassifierHierarchySearchErrorText(AddressObj, "State") );
		Return Result;
	EndIf;
	
	// When performing search result analysis you only need to check the first record, 
	// as they are ordered by conformity degree
	If CountySpecified And Selection.CountyNotFound Then
		Errors.Insert("County", ClassifierHierarchySearchErrorText(AddressObj, "County") );
	EndIf;
	
	If CitySpecified And Selection.CityNotFound Then
		Errors.Insert("City", ClassifierHierarchySearchErrorText(AddressObj, "City") );
	EndIf;
	
	If SettlementSpecified And Selection.SettlementNotFound Then
		Errors.Insert("Settlement", ClassifierHierarchySearchErrorText(AddressObj, "Settlement") );
	EndIf;
	
	If StreetSpecified And Selection.StreetNotFound Then
		Errors.Insert("Street", ClassifierHierarchySearchErrorText(AddressObj, "Street") );
	EndIf;
	
	If Errors.Count() > 0 Then
		// Address object not specified, nothing found
		Return Result;
	EndIf;
	
 // 2. Checking buildings for each found record. 
 //    If a building is found for any record, the address is considered to be valid.
	
	// Aggregated table for validation
	PostalCodeColumnRow = "StatePostalCode, CountyPostalCode, CityPostalCode, SettlementPostalCode, StreetPostalCode";
	CodeColumnRow    = "AddressObjectCodeInCode, CountyCodeInCode, CityCodeInCode, SettlementCodeInCode, StreetCodeInCode";
	AllColumnsRow      = PostalCodeColumnRow + ", " + CodeColumnRow;
	
	CodeTable   = New ValueTable;
	NumberType  = New TypeDescription("Number");
	StringType  = New TypeDescription("String");
	For Each KeyValue In New Structure(CodeColumnRow) Do
		CodeTable.Columns.Add(KeyValue.Key, NumberType);
	EndDo;
	For Each KeyValue In New Structure(PostalCodeColumnRow) Do
		CodeTable.Columns.Add(KeyValue.Key, StringType);
	EndDo;
	
	While HasRecords Do
		FillPropertyValues(CodeTable.Add(), Selection, AllColumnsRow);
		ClassifierCode = Selection.ClassifierCode;
		If ValueIsFilled(ClassifierCode) Then
			Option            = AddressOptions.Add();
			Option.Code       = ClassifierCode;
			Option.PostalCode = PostalCodeByHierarchy(Selection);
		EndIf;
		HasRecords = Selection.Next();
	EndDo;
	
	If IsBlankString(AddressObj.BuildingNumber) And IsBlankString(AddressObj.UnitNumber) Then
		// Building and unit number are not specified, returning options that do not include buildings
		Return Result;
	EndIf;
	
	Query = New Query("
		|SELECT
		|	" + AllColumnsRow + " 
		|INTO
		|	CodeTable
		|FROM
		|	&CodeTable AS ParameterTable
		|INDEX BY
		|	" + CodeColumnRow + "
		|;
		|SELECT 
		|	Buildings.Code                 AS ClassifierCode,
		|	Buildings.Description          AS Description,
		|	Buildings.PostalCode           AS PostalCode,
		|	CodeTable.StatePostalCode      AS StatePostalCode,
		|	CodeTable.CountyPostalCode     AS CountyPostalCode,
		|	CodeTable.CityPostalCode       AS CityPostalCode,
		|	CodeTable.SettlementPostalCode AS SettlementPostalCode,
		|	CodeTable.StreetPostalCode     AS StreetPostalCode
		|FROM
		|	CodeTable
		|LEFT JOIN
		|	InformationRegister.AddressClassifier AS Buildings
		|ON	
		|	  Buildings.AddressItemType            = 6
		|	AND Buildings.AddressObjectCodeInCode  = CodeTable.AddressObjectCodeInCode 
		|	AND Buildings.CountyCodeInCode         = CodeTable.CountyCodeInCode
		|	AND Buildings.CityCodeInCode           = CodeTable.CityCodeInCode
		|	AND Buildings.SettlementCodeInCode     = CodeTable.SettlementCodeInCode
		|	AND Buildings.StreetCodeInCode         = CodeTable.StreetCodeInCode
		|	
		|WHERE
		|	Not Buildings.AddressItemType IS NULL
		|");
	Query.SetParameter("CodeTable", CodeTable);
	
	FilterResult = Query.Execute();
	If FilterResult.IsEmpty() Then
		// No building information is not an error, keep using options from the superior object
		Return Result;
	EndIf;
	
	// 2.1 Getting all available building descriptions from packed strings
	
	AllBuildingOptions = New ValueTable;
	AllBuildingOptions.Columns.Add("ClassifierCode", NumberType);
	AllBuildingOptions.Columns.Add("Description",    StringType);
	AllBuildingOptions.Columns.Add("PostalCode",     StringType);

	AllBuildingOptions.Columns.Add("IsRange", New TypeDescription("Boolean") );
	
	Selection = FilterResult.Select();
	While Selection.Next() Do
		
		// Using the nearest postal code in the hierarchy
		PostalCode = PostalCodeByHierarchy(Selection);
		
		// Record ID
		ClassifierCode = Selection.ClassifierCode;
		
		// Breaking into separate detailed descriptions
		DescriptionOptions = Upper(StrReplace( TrimAll(StrReplace(Selection.Description, ",", Chars.LF)), " ", ""));
		For LineNumber = 1 To StrLineCount(DescriptionOptions) Do
			Description = Upper( TrimAll( StrGetLine(DescriptionOptions, LineNumber) ));
			If Not IsBlankString(Description) Then
				NewRow = AllBuildingOptions.Add();
				NewRow.ClassifierCode = ClassifierCode;
				NewRow.Description    = Description;
				NewRow.PostalCode     = PostalCode;
				NewRow.IsRange        = IsRange(Description);
			EndIf;
		EndDo;
		
	EndDo;
	
	// 2.2 Keeping only strings that match our building number (for all options)
	
	BuildingNumberString    = Upper(TrimAll(StrReplace(AddressObj.BuildingNumber, " ", "")));
	UnitNumberString = Upper(TrimAll(StrReplace(AddressObj.UnitNumber, " ", "")));
	
	BuildingSpecified    = Not IsBlankString(BuildingNumberString);
	UnitSpecified = Not IsBlankString(UnitNumberString);
	
	If (Not BuildingSpecified) And (Not UnitSpecified) Then
		// Buildings available for validation are not specified 
		Return Result;
	EndIf;
	
	// Compatibility options
	BuildingOptions = New Structure("Building");
	UnitOptions     = New Structure("Unit");
	
	BuildingDescriptionsCache = New Map;
	BuildingPartTypes = BuildingPartTypes();
	
	Position = AllBuildingOptions.Count() - 1;
	While Position >= 0 Do
		Option = AllBuildingOptions[Position];
		
		If BuildingSpecified Then
			
			// Checking all building options and all unit options
			For Each KeyValueBuilding In BuildingOptions Do
				OptionFits = False;
				
				If UnitSpecified Then
					// Checking all options for the second part
					For Each KeyValueUnit In UnitOptions Do
						Structure = New Structure;
						Structure.Insert(KeyValueBuilding.Key, BuildingNumberString);
						Structure.Insert(KeyValueUnit.Key, UnitNumberString);
						If BuildingUnitOptionFits(Structure, Option, BuildingPartTypes, BuildingDescriptionsCache) Then
							OptionFits = True;
							Break;
						EndIf;
					EndDo;
				Else
					// Checking only building
					Structure = New Structure;
					Structure.Insert(KeyValueBuilding.Key, BuildingNumberString);
					If BuildingUnitOptionFits(Structure, Option, BuildingPartTypes, BuildingDescriptionsCache) Then
						OptionFits = True;
					EndIf;
				EndIf;
				
				If OptionFits Then
					Break;
				EndIf;
			EndDo;
			
		Else
			// Checking only unit options
			OptionFits = False;
			For Each KeyValueUnit In UnitOptions Do
				Structure = New Structure;
				Structure.Insert(KeyValueUnit.Key, UnitNumberString);
				If BuildingUnitOptionFits(Structure, Option, BuildingPartTypes, BuildingDescriptionsCache) Then
					OptionFits = True;
					Break;
				EndIf;
			EndDo;

		EndIf;
		
		If Not OptionFits Then
			AllBuildingOptions.Delete(Option);
		EndIf;
		
		Position = Position - 1;
	EndDo;
	
	If AllBuildingOptions.Count() = 0 Then
		// No building options found
		If UnitSpecified Then
			Errors.Insert("Unit", ClassifierHierarchySearchErrorText(AddressObj, "Unit") );
			
		ElsIf BuildingSpecified Then
			Errors.Insert("Building", ClassifierHierarchySearchErrorText(AddressObj, "Building") );
			
		EndIf;
		
		Return Result;
	EndIf;
	
	// 3. Checking postal code
	If IsBlankString(AddressObj.PostalCode) Then
		// No data to check
		Return Result;
	EndIf;
		
	// Code options will be filled again, for each building
	AddressOptions.Clear();
	
	// For all remaining options, searching first for the exact building description, then searching in range
	AllBuildingOptions.Sort("IsRange, Description");
	PostalCodesExist = False;
	PostalCodeFound      = False;
	For Each Option In AllBuildingOptions Do
		If Not IsBlankString(Option.PostalCode) Then
			PostalCodesExist = True;
		EndIf;
		
		If AddressObj.PostalCode = Option.PostalCode Then
			// Exact postal code match found
			PostalCodeFound = True;
		EndIf;
		
		If ValueIsFilled(Option.ClassifierCode) Then
			ResultOption            = AddressOptions.Add();
			ResultOption.PostalCode = Option.PostalCode;
			ResultOption.Code       = Option.ClassifierCode;
		EndIf;
	EndDo;
	
	If PostalCodesExist And (Not PostalCodeFound) Then
		// No postal code matches found, generating error
		Errors.Insert("PostalCode", ClassifierHierarchySearchErrorText(AddressObj, "PostalCode") );
	EndIf;
	
	Return Result;
EndFunction

// Checks whether the address item is imported.
//
// Parameters: 
//    StateName      - String - state name, including name and abbreviation.
//    CountyName     - String - county name, including name and abbreviation.
//    CityName       - String - city name, including name and abbreviation.
//    SettlementName - String - settlement name, including name and abbreviation.
//    StreetName     - String - street name, including name and abbreviation.
//    Level          - Number - level to be checked for availability.
//
// Returns:
//    Boolean - True if the address item is imported, False otherwise.
//
Function AddressItemImported(Val StateName, Val CountyName = "", Val CityName = "", Val SettlementName = "", Val StreetName = "", Level = 1) Export
	
	Parent = AddressClassifierClientServer.EmptyAddressStructure();
	State = GetAddressItem(StateName, 1,  Parent);
	
	If Level > 1 Then
		If State.Code > 0 Then
			Parent = State;
		EndIf;
		County = GetAddressItem(CountyName, 2, Parent);
		
		If Level > 2 Then
			If County.Code > 0 Then
				Parent = County;
			EndIf;
			City = GetAddressItem(CityName, 3, Parent);
			
			If Level > 3 Then
				If City.Code > 0 Then
					Parent = City;
				EndIf;
				Settlement = GetAddressItem(SettlementName, 4, Parent);
				
				If Level > 4 Then
					If Settlement.Code > 0 Then
						Parent = Settlement;
					EndIf;
					Street = GetAddressItem(StreetName, 5, Parent);
					
				EndIf;
			EndIf;
		EndIf;
	EndIf;
	
	Query = New Query;
	
	// If no level is specified or level 1 is specified, checking all levels for availability
	If Level=1 Then
		Query.Text = "
			|               SELECT TOP 1 Code FROM InformationRegister.AddressClassifier WHERE AddressItemType=2 AND AddressObjectCodeInCode=&AddressObjectCodeInCode
			|UNION ALL SELECT TOP 1 Code FROM InformationRegister.AddressClassifier WHERE AddressItemType=3 AND AddressObjectCodeInCode=&AddressObjectCodeInCode
			|UNION ALL SELECT TOP 1 Code FROM InformationRegister.AddressClassifier WHERE AddressItemType=4 AND AddressObjectCodeInCode=&AddressObjectCodeInCode
			|UNION ALL SELECT TOP 1 Code FROM InformationRegister.AddressClassifier WHERE AddressItemType=5 AND AddressObjectCodeInCode=&AddressObjectCodeInCode
			|UNION ALL SELECT TOP 1 Code FROM InformationRegister.AddressClassifier WHERE AddressItemType=6 AND AddressObjectCodeInCode=&AddressObjectCodeInCode
			|";
		Query.SetParameter("AddressObjectCodeInCode", State.AddressObjectCodeInCode);
		
	// If level 2 is specified, checking whether counties exist in the state
	ElsIf Level = 2 Then
		Query.Text = "
			|SELECT TOP 1
			|	Code
			|FROM
			|	InformationRegister.AddressClassifier
			|WHERE
			|	AddressItemType = 2
			|	AND AddressObjectCodeInCode = &AddressObjectCodeInCode
			|";
		Query.SetParameter("AddressObjectCodeInCode", State.AddressObjectCodeInCode);
		
	// If level 3 is specified, checking whether cities exist in the county
	ElsIf Level = 3 Then
		Query.Text = "
		|SELECT TOP 1
		|	Code
		|FROM
		|	InformationRegister.AddressClassifier
		|WHERE
		|	AddressItemType = 3
		|	AND AddressObjectCodeInCode = &AddressObjectCodeInCode
		|	AND CountyCodeInCode        = &CountyCodeInCode
		|";
		Query.SetParameter("AddressObjectCodeInCode", State.AddressObjectCodeInCode);
		Query.SetParameter("CountyCodeInCode",           County.CountyCodeInCode);
		
	// If level 4 is specified, checking whether settlements exist in the city
	ElsIf Level = 4 Then
		Query.Text = "
			|SELECT TOP 1
			|	Code
			|FROM
			|	InformationRegister.AddressClassifier
			|WHERE
			|	AddressItemType = 4
			|	AND AddressObjectCodeInCode = &AddressObjectCodeInCode
			|	AND CountyCodeInCode        = &CountyCodeInCode
			|	AND CityCodeInCode          = &CityCodeInCode
			|";
		Query.SetParameter("AddressObjectCodeInCode", State.AddressObjectCodeInCode);
		Query.SetParameter("CountyCodeInCode",        County.CountyCodeInCode);
		Query.SetParameter("CityCodeInCode",          City.CityCodeInCode);
		
	// If level 5 is specified, checking whether streets exist in the settlement
	ElsIf Level = 5 Then
		Query.Text = "
			|SELECT TOP 1
			|	Code
			|FROM
			|	InformationRegister.AddressClassifier
			|WHERE
			|	AddressItemType = 5
			|	AND AddressObjectCodeInCode  = &AddressObjectCodeInCode
			|	AND CountyCodeInCode         = &CountyCodeInCode
			|	AND CityCodeInCode           = &CityCodeInCode
			|	AND SettlementCodeInCode     = &SettlementCodeInCode
			|";
		Query.SetParameter("AddressObjectCodeInCode", State.AddressObjectCodeInCode);
		Query.SetParameter("CountyCodeInCode",        County.CountyCodeInCode);
		Query.SetParameter("CityCodeInCode",          City.CityCodeInCode);
		Query.SetParameter("SettlementCodeInCode",    Settlement.SettlementCodeInCode);
		
	// If level 6 is specified, checking whether buildings exist on the street
	ElsIf Level = 6 Then
		Query.Text = "
			|SELECT TOP 1
			|	Code
			|FROM
			|	InformationRegister.AddressClassifier
			|WHERE
			|	AddressItemType = 6
			|	AND AddressObjectCodeInCode  = &AddressObjectCodeInCode
			|	AND CountyCodeInCode         = &CountyCodeInCode
			|	AND CityCodeInCode           = &CityCodeInCode
			|	AND SettlementCodeInCode     = &SettlementCodeInCode
			|	AND StreetCodeInCode         = &StreetCodeInCode
			|";
		Query.SetParameter("AddressObjectCodeInCode", State.AddressObjectCodeInCode);
		Query.SetParameter("CountyCodeInCode",        County.CountyCodeInCode);
		Query.SetParameter("CityCodeInCode",          City.CityCodeInCode);
		Query.SetParameter("SettlementCodeInCode",    Settlement.SettlementCodeInCode);
		Query.SetParameter("StreetCodeInCode",        Street.StreetCodeInCode);
	EndIf;
	
	Result = Query.Execute();
	Return Not Result.IsEmpty();
	
EndFunction

// Returns (separately) address item name and address abbreviation  
// by the full description of the address item.
//
// Parameters:
//    ItemString          - String - item string.
//    AddressAbbreviation - String - address abbreviation.
//
// Returns:
//    String - name and address abbreviation.
//
Function NameAndAddressAbbreviation(Val ItemString, AddressAbbreviation) Export
	
	Buffer = TrimR(ItemString);
	LastSpacePosition = Find(Buffer, " ");
	
	If LastSpacePosition = 0 Then
		Return ItemString;
	EndIf;
	
	While StrOccurrenceCount(Buffer, " ") > 1 Do
		Buffer = Left(Buffer, LastSpacePosition - 1) + "_" + Mid(Buffer, LastSpacePosition + 1);
		LastSpacePosition = Find(Buffer, " ");
	EndDo;
	
	Query = New Query("
		|SELECT
		|	COUNT(AllAbbreviations.Abbr)                        AS AbbreviationCount,
		|	ISNULL(SUM(AbbreviationSearch.AbbreviationFlag), 0) AS AbbreviationFlag
		|FROM 
		|	InformationRegister.AddressAbbreviations AS AllAbbreviations
		|LEFT JOIN (
		|	SELECT TOP 1
		|		1 AS AbbreviationFlag
		|	FROM
		|		InformationRegister.AddressAbbreviations
		|) AS AbbreviationSearch
		|ON 
		|	Abbr = &Abbr
		|");
	Query.SetParameter("Abbr", Mid(ItemString, LastSpacePosition + 1));
	
	Result = Query.Execute().Unload()[0];
	If Result.AbbreviationCount > 0 And Result.AbbreviationFlag = 0 Then
		// Abbreviations are imported, but a matching abbreviation is not found
		Return ItemString;
	EndIf;
	
	If IsBlankString(TrimAll(Left(ItemString, LastSpacePosition - 1))) Then
		Return ItemString;
	EndIf;

	AddressAbbreviation = Mid(ItemString, LastSpacePosition + 1);
	Return Left(ItemString, LastSpacePosition - 1);
EndFunction

// Analyzes the passed address items and determines whether address classifier is available for these items. 
//
// Parameters: 
//    StateName      - String - state name, including name and abbreviation.
//    CountyName     - String - county name, including name and abbreviation.
//    CityName       - String - city name, including name and abbreviation.
//    SettlementName - String - settlement name, including name and abbreviation.
//    StreetName     - String - street name, including name and abbreviation.
//
// Returns:
//    Structure with the following fields:
//         State      - Boolean - state imported.
//         County     - Boolean - county imported. 
//         City       - Boolean - city imported.
//         Settlement - Boolean - settlement imported.
//         Street     - Boolean - street imported.
//
Function ImportedAddressItemStructure(Val StateName, Val CountyName, Val CityName,
	Val SettlementName, Val StreetName) Export

	ImportedStructure = New Structure("State, County, City, Settlement, Street, Building",
		AddressItemImported(StateName, , , , , 1),
		AddressItemImported(StateName, , , , , 2),
		AddressItemImported(StateName, CountyName, , , , 3),
		AddressItemImported(StateName, CountyName, CityName, , , 4),
		AddressItemImported(StateName, CountyName, CityName, SettlementName, , 5),
		AddressItemImported(StateName, CountyName, CityName, SettlementName, StreetName, 6));
	
	Return ImportedStructure;
EndFunction

// Returns state name by state code.
//
// Parameters:
//    StateCode - Number - state code.
//
// Returns:
//    String - state name.
//
Function StateDescriptionByCode(StateCode) Export
	
	Query = New Query;
	Query.SetParameter("AddressItemType",     1);
	Query.SetParameter("AddressObjectCodeInCode", StateCode);
	Query.Text = "
		|SELECT
		|	AddressClassifier.Description AS Description,
		|	AddressClassifier.Abbr   AS Abbr
		|FROM
		|	InformationRegister.AddressClassifier AS AddressClassifier
		|WHERE
		|	AddressClassifier.AddressItemType = &AddressItemType
		|	AND AddressClassifier.AddressObjectCodeInCode = &AddressObjectCodeInCode
		|";
	Result = Query.Execute();
	
	If Result.IsEmpty() Then 
		Return "";
	EndIf;

	Selection = Result.Select();
	Selection.Next();
	ItemName = TrimAll(Selection.Description + " " + Selection.Abbr);
	Return ItemName;
	
EndFunction

// Returns state code by its name.
//
// Parameters:
//    State - String - state name.
//
// Returns:
//    Number - state code.
//
Function StateCodeByDescription(State) Export
	
	Query = New Query("
		|SELECT
		|	AddressClassifier.AddressObjectCodeInCode AS Code
		|FROM
		|	InformationRegister.AddressClassifier AS AddressClassifier
		|WHERE
		|	AddressClassifier.AddressItemType = &AddressItemType
		|	AND AddressClassifier.Description = &Description
		|");
	Query.SetParameter("AddressItemType", 1);
	Query.SetParameter("Description",         State);
	
	Result = Query.Execute();
	If Result.IsEmpty() Then 
		Return "";
	EndIf;

	Selection = Result.Select();
	Selection.Next();
	Return Selection.Code;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Export functions called from the address classifier selection form.

// Returns a restriction structure with address field values, which is based on passed parameters.
//
// Parameters: 
//    StateName      - String - state name, including name and abbreviation.
//    CountyName     - String - county name, including name and abbreviation.
//    CityName       - String - city name, including name and abbreviation. 
//    SettlementName - String - settlement name, including name and abbreviation.
//    StreetName     - String - street name, including name and abbreviation.
//    ParentCode     - Number - parent item code.
//    Level          - Number - current item level.
//
// Returns:
//    Structure - description of restrictions, including these fields:
//        AddressObjectCodeInCode - String - restriction state code.
//        CountyCodeInCode        - String - restriction county code.
//        CityCodeInCode          - String - restriction city code.
//        SettlementCodeInCode    - String - restriction settlement code.
//        StreetCodeInCode        - String - restriction street code.
//        AddressItemType         - Number - current item level.
//
Function ReturnRestrictionStructureByParent(Val StateName, Val CountyName, Val CityName, Val SettlementName, Val StreetName, ParentCode, Level) Export
	
	RestrictionStructure = New Structure();
	
	ParentItem = ReturnAddressClassifierStructureByAddressItem(
		StateName, CountyName, CityName, SettlementName, StreetName);
	
	ParentLevel = ParentItem.AddressItemType;
	ParentCode     = ParentItem.Code;
	
	RestrictionStructure.Insert("AddressItemType", Level);
	
	AddCodeToStructure(Level, ParentLevel, RestrictionStructure,
		"AddressObjectCodeInCode", 1, ParentItem.AddressObjectCodeInCode);
	
	AddCodeToStructure(Level, ParentLevel, RestrictionStructure,
		"CountyCodeInCode", 2, ParentItem.CountyCodeInCode);
	
	AddCodeToStructure(Level, ParentLevel, RestrictionStructure,
		"CityCodeInCode", 3, ParentItem.CityCodeInCode);
	
	AddCodeToStructure(Level, ParentLevel, RestrictionStructure,
		"SettlementCodeInCode", 4, ParentItem.SettlementCodeInCode);
	
	AddCodeToStructure(Level, ParentLevel, RestrictionStructure,
		"StreetCodeInCode", 5, ?(Level<5, 0, ParentItem.StreetCodeInCode));
	
	Return RestrictionStructure;
EndFunction

// Returns address classifier string (or structure) based on address item values.
//
// Parameters: 
//    StateName      - String - state name, including name and abbreviation.
//    CountyName     - String - county name, including name and abbreviation.
//    CityName       - String - city name, including name and abbreviation.
//    SettlementName - String - settlement name, including name and abbreviation.
//    StreetName     - String - street name, including name and abbreviation.
//
// Returns:
//    Structure - field description based on found address item 
//                (see function AddressClassifierClientServer.EmptyAddressStructure())
//
Function ReturnAddressClassifierStructureByAddressItem(Val StateName, Val CountyName, Val CityName, Val SettlementName, Val StreetName) Export
	
	ParentItem = AddressClassifierClientServer.EmptyAddressStructure();
	
	State = GetAddressItem(StateName, 1, ParentItem);
	If State.Code > 0 Then
		ParentItem = State;
	EndIf;
	
	County = GetAddressItem(CountyName, 2, ParentItem);
	If County.Code > 0 Then
		ParentItem = County;
	EndIf;
	
	City = GetAddressItem(CityName, 3, ParentItem);
	If City.Code > 0 Then
		ParentItem = City;
	EndIf;
	
	Settlement = GetAddressItem(SettlementName, 4, ParentItem);
	If Settlement.Code > 0 Then
		ParentItem = Settlement;
	EndIf;
	
	Street = GetAddressItem(StreetName, 5, ParentItem);
	If Street.Code > 0 Then
		ParentItem = Street;
	EndIf;
	
	If ParentItem = Undefined Then
		Return AddressClassifierClientServer.EmptyAddressStructure()
	Else
		Return ParentItem;
	EndIf;
	
EndFunction

// Clears subordinate items of a specified address item.
//
// Parameters:
//    State      - String - string for storing string presentation of the parent state.
//    County     - String - string for storing string presentation of the parent county.
//    City       - String - string for storing string presentation of the parent city.
//    Settlement - String - string for storing string presentation of the parent settlement.
//    Street     - String - string for storing string presentation of the parent street.
//    Building   - String - string for storing string presentation of the parent building number.
//    Unit       - String - string for storing string presentation of the parent unit number.
//    Apartment  - String - string for storing string presentation of the parent apartment number.
//    Level      - Number - address item level.
//
Procedure ClearChildsByAddressItemLevel(State, County, City, Settlement, Street, Building, Unit, Apartment, Level) Export
	
	// Clearing the specified address item and all hierarchically subordinate items
	If Level     = 1 Then
		County     = "";
		City       = "";
		Settlement = "";
		Street     = "";
		Building   = "";
		Unit       = "";
		Apartment  = "";
	
	ElsIf Level  = 2 Then
		City       = "";
		Settlement = "";
		Street     = "";
		Building   = "";
		Unit       = "";
		Apartment  = "";
	
	ElsIf Level  = 3 Then
		Settlement = "";
		Street     = "";
		Building   = "";
		Unit       = "";
		Apartment  = "";
		
	ElsIf Level = 4 Then
		Street    = "";
		Building  = "";
		Unit      = "";
		Apartment = "";
	EndIf;
	
EndProcedure

#EndRegion

#Region InternalInterface

// See the description of this procedure in the StandardSubsystemsServer module.
//
Procedure InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers) Export
	
	// SERVER HANDLERS
	ServerHandlers["StandardSubsystems.InfobaseVersionUpdate\OnAddUpdateHandlers"].Add(
		"AddressClassifier");
		
	ServerHandlers["StandardSubsystems.BaseFunctionality\OnFillPermissionsToAccessExternalResources"].Add(
		"AddressClassifier");
		
EndProcedure

// Fills a list of requests for external permissions that must be granted when an infobase is created or an application is updated.
//
// Parameters:
//  PermissionRequests - Array - list of values returned by SafeMode.RequestToUseExternalResources().
//
Procedure OnFillPermissionsToAccessExternalResources(PermissionRequests) Export
	
	If CommonUseCached.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	// Checking for updates
	PermissionRequests.Add(
		SafeMode.RequestToUseExternalResources(UpdateCheckSecurityPermissions()));
	
EndProcedure

// Basic event name used for event log recording.
//
// Returns:
//     String - name.
//
Function EventLogMessageText() Export
	Return NStr("en='Address classifier'", 
		CommonUseClientServer.DefaultLanguageCode() );
EndFunction

// Set of security profile permissions used to check for address classifier updates at 1C website.
//
// Returns:
//     Array - required permissions.
// 
Function UpdateCheckSecurityPermissions() Export
	
	VersionFileAddress = CommonUseClientServer.URIStructure(
		AddressClassifierClientServer.PathToACDataDescriptionFile()
	);
	
	Protocol = Upper(VersionFileAddress.Schema);
	Address    = VersionFileAddress.Domain;
	Port     = VersionFileAddress.Port;
	Description = NStr("en = 'Check for address classifier updates.'");
	
	Permissions = New Array;
	Permissions.Add( 
		SafeMode.PermissionToUseInternetResource(Protocol, Address, Port, Description)
	);
	
	Return Permissions;
EndFunction

#EndRegion

#Region InternalProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Internal event handlers of SL subsystems

////////////////////////////////////////////////////////////////////////////////
// Initial infobase filling and updating

// Adds update handlers that are required by the subsystem.
//
// Parameters:
//    Handlers - ValueTable - see the description of NewUpdateHandlerTable function in the InfobaseUpdate common module.
// 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	If CommonUseCached.DataSeparationEnabled() Then
		Return;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Utility functions related to address classifier import

// Imports address abbreviations to AddressAbbreviations register.
//
// Parameters:
//    PathToServerData - String - path to directory containing file ABBRBASE.DBF.
//    Version          - Date   - UTC data version.
//
// Returns:
//    Boolean - True if data is saved successfully, False if error occurred 
//              when preparing to save data to the register.
//
Function ImportAddressAbbreviations(Val PathToServerData, Val Version) Export
	
	AddressAbbreviationsFile = PathToServerData + "ABBRBASE.DBF";
	
	AddressAbbreviationsTable = New ValueTable;
	AddressAbbreviationsTable.Columns.Add("Code");
	AddressAbbreviationsTable.Columns.Add("Level");
	AddressAbbreviationsTable.Columns.Add("Description");
	AddressAbbreviationsTable.Columns.Add("Abbr");
	
	AddressAbbreviations = InformationRegisters.AddressAbbreviations;
	
	RecordSet = AddressAbbreviations.CreateRecordSet();
	
	xB = New XBase(AddressAbbreviationsFile);
	xB.Encoding = XBaseEncoding.OEM;
	
	// Checking codes in the classifier file for uniqueness
	Control = New Map;
	HasErrors = False;
	If xB.IsOpen() Then
		While Not xB.EOF() Do
			UniquenessCode = Number(xB.level) * 10000 + Number(xB.code);
			If Control[UniquenessCode] = Undefined Then
				Control[UniquenessCode] = 0;
				NewRecord = RecordSet.Add();
				NewRecord.Code        = xB.code;
				NewRecord.Level       = xB.level;
				NewRecord.Description = xB.title;
				NewRecord.Abbr        = xB.abbr;
			Else
				HasErrors = True;
			EndIf;
			xB.Next();
			
		EndDo;
		xB.CloseFile();
	Else
		Return False;
	EndIf;
	
	If HasErrors Then
		ErrorString = NStr("en = 'Code uniqueness errors in address classifier file %1'");
		ParametersInString = StringFunctionsClientServer.SubstituteParametersInString(ErrorString, "abbrbase.dbf");
		WriteLogEvent(EventLogMessageText(), EventLogLevel.Error, , , ParametersInString);
	EndIf;
	
	BeginTransaction();
	Try
		RecordSet.Write();
		SetClassifierVersion("SO", Version);
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	Return True;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Other internal procedures and functions.

// This procedure imports address object data from address classifier files to the information register.
//
// Parameters:
//    ImportParameters - Structure - import parameters.
//    StorageAddress   - String    - internal storage address.
//
Procedure ImportAddressDataFromClassifierFilesToInformationRegister(ImportParameters, StorageAddress) Export
	
	ReturnStructure = New Structure;
	
	ReturnStructure.Insert("PathToServerData",  ImportParameters.PathToServerData);
	ReturnStructure.Insert("ExecutionStatus",      True);
	ReturnStructure.Insert("UserMessage", "");
	ReturnStructure.Insert("DataPath");
	
	AvailableVersions = New Map;
	
	// Flag used to import special files with specific names
	SpecialFileImport = ImportParameters.ImportDataSource = 1;
	
	If SpecialFileImport Then
		For Each KeyValue In ImportParameters.AvailableVersions Do
			AddressObject = KeyValue.Key;
			CodeString = ?(TypeOf(AddressObject) = Type("Number"), Format(AddressObject, "ND=2; NZ=; NLZ="), AddressObject);
			AvailableVersions[CodeString] = KeyValue.Key
		EndDo;
	Else
		For Each AddressObject In ImportParameters.AddressObjects Do
			CodeString = ?(TypeOf(AddressObject) = Type("Number"), Format(AddressObject, "ND=2; NZ=; NLZ="), AddressObject);
			AvailableVersions[CodeString] = ImportParameters.VersionOfAddressClassifierToImport;
		EndDo;
	EndIf;
	
	CurrentVersions = New Map;
	For Each ListItem In AddressObjectVersions() Do
		CurrentVersions.Insert(ListItem.Presentation, ListItem.Value);
	EndDo;
	
	ImportVersionToday = CurrentUniversalDate();
	
	// Always forced import
	AvailableVersions.Clear();
	
	Try
		
		For Each AddressObject In ImportParameters.AddressObjects Do
			
			If AddressObject = "AL" Or AddressObject = "SO" Then
				// Alternate names and address abbreviations are imported separately
				Continue;
			EndIf;
			
			// Canceling import if the latest address data is already available
			AvailableVersion = AvailableVersions[AddressObject];
			If AvailableVersion = Undefined Then
				// Version not specified. Using the current version, always importing
				AvailableVersion = ImportVersionToday;
				CurrentVersion   = '00000000';
			Else
				CurrentVersion = CurrentVersions[AddressObject];
				If CurrentVersion = Undefined Then
					CurrentVersion = '00000000';
				EndIf;
			EndIf;
			
			If AvailableVersion > CurrentVersion Then
				
				LongActions.RegisterProgress( , StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'Importing state ""%1 - %2"" (%3 remaining)...'"), 
					AddressObject, InformationRegisters.AddressClassifier.StateDescriptionByCode(AddressObject),
					Format(ImportParameters.AddressObjects.UBound() - ImportParameters.AddressObjects.Find(AddressObject), "NZ=")
				));
				
				ImportClassifierForAddressObject(AddressObject, ImportParameters.PathToServerData, SpecialFileImport, AvailableVersion);
			Else
				
				LongActions.RegisterProgress( , StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'The latest data is already imported for state ""%1 - %2"" (%3 remaining)...'"), 
					AddressObject, InformationRegisters.AddressClassifier.StateDescriptionByCode(AddressObject),
					Format(ImportParameters.AddressObjects.UBound() - ImportParameters.AddressObjects.Find(AddressObject), "NZ=")
				));
				
			EndIf;
			
		EndDo;
		
		// Abbreviations
		AvailableVersion = AvailableVersions["SO"];
		If AvailableVersion <> Undefined Then
			CurrentVersion = CurrentVersions["SO"];
			If CurrentVersion = Undefined And AvailableVersion > CurrentVersion Then
				ImportAddressAbbreviations(ImportParameters.PathToServerData, AvailableVersion);
			EndIf;
		EndIf;
		
	Except
		Information = ErrorInfo();
		
		WriteLogEvent( EventLogMessageText(), EventLogLevel.Error,,, DetailErrorDescription(Information) );
		
		ReturnStructure.ExecutionStatus = False;
		ReturnStructure.UserMessage = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Error while importing address data: 
				       |%1'"),
			BriefErrorDescription(Information)
		);
	EndTry;
	
	PutToTempStorage(ReturnStructure, StorageAddress);
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Operations with address object data versions

// Sets address object version in the register.
//
// Parameters:
//    StateCode   - String, Number - Address object code.
//    Version     - Date           - Address object version.
//
Procedure SetClassifierVersion(Val StateCode, Val Version = '00000000') Export
	
	CodeString = ?(TypeOf(StateCode) = Type("Number"), Format(StateCode, ""), StateCode);
	
	Set = InformationRegisters.AddressClassifierObjectVersions.CreateRecordSet();
	Set.Filter.AddressObject.Set(CodeString);
	
	If Version <> '00000000' Then
		Data = Set.Add();
		Data.AddressObject    = CodeString;
		Data.VersionReleaseDate = Version;
		Data.Description      = InformationRegisters.AddressClassifier.StateDescriptionByCode(CodeString);
	EndIf;
	
	Set.Write(True);
EndProcedure

// Reads the address object version file and returns address object data versions.
//
// Parameters:
//    XMLText - String - string containing text in XML format.
//
// Returns:
//    Map - address data description. Key is address object string, value is address object expiration date.
//
Function GetAddressDataVersions(Val XMLText) Export
	
	XMLReader = New XMLReader;
	XMLReader.SetString(XMLText);
	
	XMLReader.Read();
	
	Result = New Map;
	
	While XMLReader.Read() Do
		If XMLReader.NodeType = XMLNodeType.StartElement Then
			AttributeName = Lower(XMLReader.AttributeName(0));
			If AttributeName = "code" Or AttributeName = "name" Then
				ReleaseDate = GetAttribute(XMLReader, "date");
				Result.Insert( Upper(XMLReader.AttributeValue(0)), ReleaseDate);
			EndIf;
		EndIf;
	EndDo;
	
	XMLReader.Close();
	Return Result;
	
EndFunction

// Saves an archive file (based on binary data on the server) with a passed name to a passed directory, and extracts the archive contents.
//
// Parameters:
//    BinaryData            - BinaryData - file data.
//    ArchiveFileName       - String     - file name.
//    PathToServerDirectory - String     - path to the directory for storing the extracted file.
//
Procedure SaveFileOnServerAndExtract(Val BinaryData, ArchiveFileName, PathToServerDirectory) Export
	
	If PathToServerDirectory = Undefined Then
		PathToServerDirectory = CommonUseClientServer.AddFinalPathSeparator(GetTempFileName());
		CreateDirectory(PathToServerDirectory);
	EndIf;
	
	BinaryData.Write(PathToServerDirectory + ArchiveFileName);
	
	ZIPReader = New ZipFileReader(PathToServerDirectory + ArchiveFileName);
	ZIPReader.ExtractAll(PathToServerDirectory, ZIPRestoreFilePathsMode.DontRestore);
	ZIPReader.Close();
	DeleteFiles(PathToServerDirectory, ArchiveFileName);
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// 1C user support website authentification

// Gets and saves user authentication parameters (login and password) for 1C user support website.
// 
// Parameters:
//     ParametersToSave - Structure - parameters to save (if not specified, nothing is saved).
//         * Login    - String - authorization parameter.
//         * Password - String - authorization parameter.
// 
// Returns:
//     Structure - current values:
//         * Filled   - Boolean - flag specifying that parameters are filled.
//         * Login    - String  - authorization parameter.
//         * Password - String  - authorization parameter.
//
Function WebsiteAuthenticationParameters(Val ParametersToSave = Undefined) Export
	
	If ParametersToSave = Undefined Then
		// Read
		Login  = CommonUse.CommonSettingsStorageLoad("AuthenticationOnSupportSite", "UserCode", "");
		Password = CommonUse.CommonSettingsStorageLoad("AuthenticationOnSupportSite", "Password", "");
	Else
		// Write
		Login  = ParametersToSave.Login;
		Password = ParametersToSave.Password;
		
		CommonUse.CommonSettingsStorageSave("AuthenticationOnSupportSite", "UserCode", Login);
		CommonUse.CommonSettingsStorageSave("AuthenticationOnSupportSite", "Password", Password);
			
	EndIf;
	
	Result = New Structure;
	Result.Insert("Login",  Login);
	Result.Insert("Password", Password);
	Result.Insert("Filled", Not IsBlankString(Login) And Not IsBlankString(Password) );
	
	Return Result;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Local internal procedures and functions

// Returns the nearest postal code in the hierarchy from the selection with known fields.
//
Function PostalCodeByHierarchy(Val Selection)
	
	PostalCode = TrimAll(Selection.PostalCode);
	If IsBlankString(PostalCode) Then
		PostalCode = TrimAll(Selection.StreetPostalCode);
		If IsBlankString(PostalCode) Then
			PostalCode = TrimAll(Selection.SettlementPostalCode);
			If IsBlankString(PostalCode) Then
				PostalCode = TrimAll(Selection.CityPostalCode);
				If IsBlankString(PostalCode) Then
					PostalCode = TrimAll(Selection.CountyPostalCode);
					If IsBlankString(PostalCode) Then
						PostalCode = TrimAll(Selection.StatePostalCode);
					EndIf;
				EndIf;
			EndIf;
		EndIf;
	EndIf;
	
	Return PostalCode;
EndFunction

// Function used to fill in data for classification levels 2-6:
// 2:   state counties,
// 3:   cities and towns,
// 4:   smaller settlements within the city limits,
// 5    city streets,
// 6:   buildings located in level-3 cities or towns, including buildings not related to any street.
//
// Parameters:
//    AddressObjectCode - String - string presentation of address object number.
//    PathToServerData  - String - path to server directory where the address classifier files are stored. 
//                                 The path must end with a slash mark or backslash.
//    AddressData       - ValueTable - table to be filled with imported items.
//    AlternateNames    - ValueTable.
//    AddressItemType   - Number - address object level.
//
// Returns:
//    Boolean - True if address data is imported, False otherwise.
//
Function ImportAddressData(AddressObjectCode, PathToServerData, AddressInformation, AlternateNames, Val AddressItemType=Undefined)
	// Address classifier file names are already in uppercase
	
	AddressClassifierFile = PathToServerData +  ".DBF";
	ClassifierIndexFile   = PathToServerData +  ".CDX";
	
	// To import an address data group, CODE field indexing is needed
	IndexingNeeded = True;
	IndexFile = New File(ClassifierIndexFile);
	If IndexFile.Exist() Then
		DataFile = New XBase(AddressClassifierFile, ClassifierIndexFile, True);
		If Not DataFile.IsOpen() Then
			Return False;
		EndIf;
		
		If DataFile.Indexes.Find("IDXCODE") <> Undefined Then
			IndexingNeeded = False;
		EndIf;
	EndIf;
	
	If IndexingNeeded Then
		DataFile = New XBase(AddressClassifierFile);
		If Not DataFile.IsOpen() Then
			Return False;
		EndIf;
		
		// Generating index by unique codes (ignoring duplicate codes)
		DataFile.Indexes.Add("IDXCODE", "CODE", True);
		DataFile.CreateIndex(ClassifierIndexFile);
		DataFile.CloseFile();
	EndIf;
	
	DataFile = New XBase(AddressClassifierFile, ClassifierIndexFile, True);
	DataFile.Encoding = XBaseEncoding.OEM;
	If Not DataFile.IsOpen() Then
		Return False;
	EndIf;
	
	// When importing street or building data, address item type is Undefined
	If AddressItemType <> Undefined Then
		AddressItemTypeSet = True;
	Else
		AddressItemTypeSet = False;
	EndIf;
	
	// Starting from the first index record; ignoring duplicate records with non-unique indexes
	DataFile.CurrentIndex = DataFile.Indexes.Find("IDXCODE");
	DataFile.Find(AddressObjectCode, "=");
	
	HasDuplicateFileCodes = False;
	
	While Not DataFile.EOF() Do
		Code = DataFile.CODE;
		
		If Left(Code, 2) <> AddressObjectCode Then
			Break;
		EndIf;
		
		If AddressItemTypeSet Then
			DataIsCurrentFlag = Mid(Code, 16, 2);
		Else
			AddressItemType = GetAddressItemTypeByCode(Code);
			DataIsCurrentFlag = Mid(Code, 12, 2);
		EndIf;
		
 		// If this is an alternate name, saving data to a separate table dedicated to alternate names (building numbers cannot have alternate names)
		If (AddressItemType <> 6)
		     And (DataIsCurrentFlag <> "00")
		     And (DataIsCurrentFlag <> "99")
		Then
			
			AlternateNameString             = AlternateNames.Add();
			AlternateNameString.Code        = Code;
			AlternateNameString.Description = TrimAll(DataFile.NAME);
			AlternateNameString.Abbr        = TrimAll(DataFile.ABBR);
			AlternateNameString.PostalCode  = TrimAll(DataFile.PCODE);
			
		Else
			NewRow = AddressInformation.Add();
			NewRow.Code = Code;
			
			NewRow.AddressItemType          = AddressItemType;
			NewRow.AddressObjectCodeInCode  = Number(Mid(Code, 1, 2));
			NewRow.CountyCodeInCode         = Number(Mid(Code, 3, 3));
			NewRow.CityCodeInCode           = Number(Mid(Code, 6, 3));
			NewRow.SettlementCodeInCode     = Number(Mid(Code, 9, 3));
			
			If AddressItemType <= 4 Then
				NewRow.StreetCodeInCode  = 0;
				NewRow.DataIsCurrentFlag = Number(Mid(Code, 12, 2));
				
			ElsIf AddressItemType = 5 Then
				NewRow.StreetCodeInCode  = Number(Mid(Code, 12, 4));
				NewRow.DataIsCurrentFlag = Number(Mid(Code, 16, 2));
				
			Else
				NewRow.StreetCodeInCode  = Number(Mid(Code, 12, 4));
				NewRow.DataIsCurrentFlag = 0;
				
			EndIf;
			
			NewRow.Description = TrimAll(DataFile.NAME);
			NewRow.PostalCode  = DataFile.PCODE;
			NewRow.Abbr        = TrimAll(DataFile.ABBR);
		EndIf;
		
		DataFile.Next();
	EndDo;
	
	DataFile.CloseFile();
	Return True;
EndFunction

// Complements address data with alternate names.
//
// Parameters:
//    PathToServerData  - String - path to server directory where address classifier files are stored. 
//                                 The path must end with a slash mark or backslash.
//    AddressData       - ValueTable - table to be filled with imported items.
//    AlternateNames    - ValueTable.
//    ImportFromWeb     - Boolean.
//
// Returns:
//    Boolean - True if alternate names are filled, False otherwise.
///
Function FillAlternateNames(PathToServerData, AddressInformation, AlternateNames, ImportFromWeb)
	// Address classifier file names are already in uppercase
	
	If AlternateNames.Count() = 0 Then
		Return True;
	EndIf;
	
	InfobaseOpen = False;
	
	For Each AlternateObject In AlternateNames Do
		
		DataIsCurrentFlag = Right(AlternateObject.Code, 2);
		
		ActualNameCode = Left(AlternateObject.Code, StrLen(AlternateObject.Code) - 2) + "00";
		
		If DataIsCurrentFlag = "51" Then
			
			If Not InfobaseOpen Then
				PathToAlternateNameFile      = PathToServerData + ".DBF";
				PathToAlternateNameFileIndex	= PathToServerData + ".CDX";
				
				IndexFile = New File (PathToAlternateNameFileIndex);
				If IndexFile.Exist() Then
					xB = New XBase(PathToAlternateNameFile, PathToAlternateNameFileIndex, True);
				Else
					xB = New XBase(PathToAlternateNameFile);
					xB.Indexes.Add("IDXCODE", "OLDCODE", True);
					xB.CreateIndex(PathToAlternateNameFileIndex);
				EndIf;
				
				xB.Encoding = XBaseEncoding.OEM;
				If Not xB.IsOpen() Then
					Return False;
				EndIf;
				
				xB.CurrentIndex = xB.Indexes.Find("IDXCODE");
				InfobaseOpen = True;
			EndIf;
			
			// searching altnames.dbf for address data
			OLDCODE = ActualNameCode;
			If xB.Find (OLDCODE, "=") Then 
				NewCode = TrimAll(xB.NewCode);
				// searching address data for the actual object
				TableRow = AddressInformation.Find(NewCode, "Code");
			Else
				TableRow = Undefined;
			EndIf;
			
			If TableRow = Undefined Then
				
				DeletedSettlementCode = Left(AlternateObject.Code, StrLen(AlternateObject.Code) - 2) + "99";
				
				Code = Left(AlternateObject.Code, StrLen(AlternateObject.Code) - 2) + "00";
				
				// Skipping if an item with this code already exists
				If AddressInformation.Find(Code, "Code") <> Undefined Then
					Continue;
				EndIf;
				
				NewRow = AddressInformation.Add();
				
				AddressItemType = GetAddressItemTypeByCode(Code);
				
				NewRow.Code = Code;
				
				NewRow.AddressItemType          = AddressItemType;
				NewRow.AddressObjectCodeInCode  = Number(Mid(Code, 1, 2));
				NewRow.CountyCodeInCode         = Number(Mid(Code, 3, 3));
				NewRow.CityCodeInCode           = Number(Mid(Code, 6, 3));
				NewRow.SettlementCodeInCode     = Number(Mid(Code, 9, 3));
				
				If AddressItemType <= 4 Then
					NewRow.StreetCodeInCode        = 0;
					NewRow.DataIsCurrentFlag       = Number(Mid(Code, 12, 2));
				ElsIf AddressItemType = 5 Then
					NewRow.StreetCodeInCode        = Number(Mid(Code, 12, 4));
					NewRow.DataIsCurrentFlag       = Number(Mid(Code, 16, 2));
				Else
					NewRow.StreetCodeInCode        = Number(Mid(Code, 12, 4));
					NewRow.DataIsCurrentFlag       = Number(Right(Code, 2));
				EndIf;
				
				NewRow.Description = TrimAll(AlternateObject.Description);
				NewRow.PostalCode  = TrimAll(AlternateObject.PostalCode);
				NewRow.Abbr        = TrimAll(AlternateObject.Abbr);
				
				Continue;
			EndIf;
			
		Else
			
			TableRow = AddressInformation.Find(ActualNameCode, "Code");
			
		EndIf;
		
		If TableRow <> Undefined Then
			If ValueIsFilled(TrimAll(AlternateObject.PostalCode)) Then 
				AlternateObjectPostalCode = " : " + AlternateObject.PostalCode;
			Else
				AlternateObjectPostalCode = "";
			EndIf;
			
			AlternateName = AlternateObject.Description + " " + AlternateObject.Abbr + AlternateObjectPostalCode;
			
			If TableRow.AlternateNames = Undefined Then
				TableRow.AlternateNames = AlternateName;
			Else
				TableRow.AlternateNames = TableRow.AlternateNames + ", " + AlternateName;
			EndIf;
		EndIf;
		
		TableRow = Undefined;
		
	EndDo;
	
	If InfobaseOpen Then
		xB.CloseFile();
	EndIf;
	
	Return True;
	
EndFunction

// This function returns address item level (1 to 6) according to hierarchical classification, based
// on address item code in the following format:
// _2__3___3___3___4____4____
// |SS|CCC|CCC|SSS|SSSS|BBBB|
// 
// The deeper hierarchy level, the more digits are filled.
// 
// Parameters:
//    Code - String - code retrieved from data file CODE record field.
// 
// Returns:
//    Number - level 1 to 6.
//
Function GetAddressItemTypeByCode(Val Code)
	
	Dimensions = StrLen(Code);
	
	// For codes with length 13 or 17, the code must be shortened by 2 digits 
	// (address object relevance characters)
	If Dimensions = 13 Or Dimensions = 17 Then
		Dimensions = Dimensions - 2;
		CodeNumber = Number(Mid(Code, 1, StrLen(Code)-2));
	ElsIf Dimensions = 19 Then
		CodeNumber = Number(Mid(Code, 1, StrLen(Code)));
	EndIf;
	
	// Checking whether BBBB (building) substring is filled
	If Dimensions = 19 Then
		
		Balance = CodeNumber % 10000;
		If Balance <> 0 Then
			Return 6;
		EndIf;
		
		CodeNumber = CodeNumber / 10000;
		
	EndIf;
	
	// Checking whether SSSS (street) substring is filled
	If Dimensions = 15 Then
		
		Balance = CodeNumber % 10000;
		If Balance <> 0 Then
			Return 5;
		EndIf;
		
		CodeNumber = CodeNumber / 10000;
		
	EndIf;
	
	// Checking whether SSS (settlement) substring is filled
	Balance = CodeNumber % 1000;
	If Balance <> 0 Then
		Return 4;
	EndIf;
	
	// Checking whether CCC (city) substring is filled
	Balance = CodeNumber % 1000000;
	If Balance <> 0 Then
		Return 3;
	EndIf;
	
	// Checking whether CCC (county) substring is filled
	Balance = CodeNumber % 1000000000;
	If Balance <> 0 Then
		Return 2;
	EndIf;
	
	// Top hierarchy level: one
	
	Return 1;
	
EndFunction

// Reads the attribute value by the name from the specified object, converts the value to the specified primitive type.
//
// Parameters:
//    XMLReader - XMLReader - object positioned to the beginning of the item
//                            whose value we need to retrieve.
//    Type      - Type      - attribute type.
//    Name      - String    - attribute name.
//
// Returns:
//    String - attribute value based on the name and converted to the specified type.
//
Function GetAttribute(Val XMLReader, Val Name)
	
	ValueString = TrimAll(XMLReader.GetAttribute(Name));
	
	If Name = "date" Then
		Return Date(Mid(ValueString, 7, 4) + Mid(ValueString, 4, 2) + Left(ValueString, 2));
	ElsIf Name = "code" Then
		Return Left(ValueString, 2);
	EndIf;
	
EndFunction

// Gets address item part codes based on the address item code and type.
//
// Parameters:
//    AddressItemCode - String, Number - address object code.
//    AddressItemType - Number         - address object level.
//
// Returns:
//    Structure - found item description:
//        * AddressObjectCodeInCode - Number - state item code. 
//        * CountyCodeInCode        - Number - county item code. 
//        * CityCodeInCode          - Number - city item code. 
//        * SettlementCodeInCode    - Number - settlement item code. 
//        * StreetCodeInCode        - Number - street item code. 
//        * RelevanceFlag           - Number - relevance flag item code.
//
Function SplitAddressObjectIntoItems(AddressItemCode, AddressItemType)
	
	If TypeOf(AddressItemCode) = Type("Number") Then
		CodeString = Format(AddressItemCode, "NG=0");
	Else
		CodeString = AddressItemCode;
	EndIf;
	
	AddressStructure = New Structure;
	AddressStructure.Insert("AddressObjectCodeInCode", Number(Left(CodeString, 2)));
	
	If AddressItemType > 1 Then
		AddressStructure.Insert("CountyCodeInCode", Number(Mid(CodeString, 3, 3)));
	Else
		AddressStructure.Insert("CountyCodeInCode", 0);
	EndIf;
	
	If AddressItemType > 2 Then
		AddressStructure.Insert("CityCodeInCode", Number(Mid(CodeString, 6, 3)));
	Else
		AddressStructure.Insert("CityCodeInCode", 0);
	EndIf;
	
	If AddressItemType > 3 Then
		AddressStructure.Insert("SettlementCodeInCode", Number(Mid(CodeString, 9, 3)));
	Else
		AddressStructure.Insert("SettlementCodeInCode", 0);
	EndIf;
	
	If AddressItemType > 4 Then
		AddressStructure.Insert("StreetCodeInCode", Number(Mid(CodeString, 12, 4)));
		AddressStructure.Insert("DataIsCurrentFlag", Number(Mid(CodeString, 16, 2)));
	Else
		AddressStructure.Insert("StreetCodeInCode", 0);
		AddressStructure.Insert("DataIsCurrentFlag", Number(Mid(CodeString, 12, 2)));
	EndIf;
	
	Return AddressStructure;
	
EndFunction

// Puts data into temporary tables States, Counties, Cities, Settlements, and Streets.
// The resulting tables correspond to the addresses retrieved from the Addresses temporary table 
// in the temporary table manager.
//
// Parameters:
//    TempTablesManager - TempTablesManager - temporary table manager that should already contain 
//                        the Addresses temporary table.
//
Procedure SplitAddressItemsToTempTables(TempTablesManager)
	
	Query = New Query("
		|SELECT
		|	Addresses.Code AS Code,
		|	AddressClassifier.Code AS StateCode,
		|	AddressClassifier.Description + "" "" + AddressClassifier.Abbr AS Description,
		|	AddressClassifier.DataIsCurrentFlag AS DataIsCurrentFlag,
		|	Addresses.AddressObjectCodeInCode AS AddressObjectCodeInCode
		|INTO 
		|	States
		|FROM
		|	Addresses AS Addresses
		|LEFT JOIN 
		|	InformationRegister.AddressClassifier AS AddressClassifier
		|ON 
		|	Addresses.AddressObjectCodeInCode = AddressClassifier.AddressObjectCodeInCode
		|WHERE
		|	AddressClassifier.AddressItemType = 1
		|;////////////////////////////////////////////////////////////////////////////////
		|
		|SELECT
		|	Addresses.Code AS Code,
		|	AddressClassifier.Code AS CountyCode,
		|	AddressClassifier.Description + "" "" + AddressClassifier.Abbr AS Description,
		|	AddressClassifier.DataIsCurrentFlag AS DataIsCurrentFlag,
		|	Addresses.CountyCodeInCode AS CountyCodeInCode,
		|	Addresses.AddressObjectCodeInCode AS AddressObjectCodeInCode
		|INTO 
		|	Counties
		|FROM
		|	Addresses AS Addresses
		|LEFT JOIN 
		|	InformationRegister.AddressClassifier AS AddressClassifier
		|ON 
		|	Addresses.AddressObjectCodeInCode = AddressClassifier.AddressObjectCodeInCode
		|	AND Addresses.CountyCodeInCode = AddressClassifier.CountyCodeInCode
		|WHERE
		|	AddressClassifier.AddressItemType = 2
		|;////////////////////////////////////////////////////////////////////////////////
		|
		|SELECT
		|	Addresses.Code AS Code,
		|	AddressClassifier.Code AS AreaCode,
		|	AddressClassifier.Description + "" "" + AddressClassifier.Abbr AS Description,
		|	AddressClassifier.DataIsCurrentFlag AS DataIsCurrentFlag,
		|	Addresses.CityCodeInCode AS CityCodeInCode,
		|	Addresses.CountyCodeInCode AS CountyCodeInCode,
		|	Addresses.AddressObjectCodeInCode AS AddressObjectCodeInCode
		|INTO 
		|	Cities
		|FROM
		|	Addresses AS Addresses
		|LEFT JOIN 
		|	InformationRegister.AddressClassifier AS AddressClassifier
		|ON 
		|	Addresses.AddressObjectCodeInCode = AddressClassifier.AddressObjectCodeInCode
		|	AND Addresses.CountyCodeInCode = AddressClassifier.CountyCodeInCode
		|	AND Addresses.CityCodeInCode = AddressClassifier.CityCodeInCode
		|WHERE
		|	AddressClassifier.AddressItemType = 3
		|;////////////////////////////////////////////////////////////////////////////////
		|
		|SELECT
		|	Addresses.Code AS Code,
		|	AddressClassifier.Code AS SettlementCode,
		|	AddressClassifier.Description + "" "" + AddressClassifier.Abbr AS Description,
		|	AddressClassifier.DataIsCurrentFlag AS DataIsCurrentFlag,
		|	Addresses.SettlementCodeInCode AS SettlementCodeInCode,
		|	Addresses.CityCodeInCode AS CityCodeInCode,
		|	Addresses.CountyCodeInCode AS CountyCodeInCode,
		|	Addresses.AddressObjectCodeInCode AS AddressObjectCodeInCode
		|INTO 
		|	Settlements
		|FROM
		|	Addresses AS Addresses
		|LEFT JOIN 
		|	InformationRegister.AddressClassifier AS AddressClassifier
		|ON 
		|	Addresses.AddressObjectCodeInCode = AddressClassifier.AddressObjectCodeInCode
		|	AND Addresses.CountyCodeInCode = AddressClassifier.CountyCodeInCode
		|	AND Addresses.CityCodeInCode = AddressClassifier.CityCodeInCode
		|	AND Addresses.SettlementCodeInCode = AddressClassifier.SettlementCodeInCode
		|WHERE
		|	AddressClassifier.AddressItemType = 4
		|;////////////////////////////////////////////////////////////////////////////////
		|
		|SELECT
		|	Addresses.Code AS Code,
		|	AddressClassifier.Code AS StreetCode,
		|	AddressClassifier.Description + "" "" + AddressClassifier.Abbr AS Description,
		|	AddressClassifier.DataIsCurrentFlag AS DataIsCurrentFlag,
		|	Addresses.StreetCodeInCode AS StreetCodeInCode,
		|	Addresses.SettlementCodeInCode AS SettlementCodeInCode,
		|	Addresses.CityCodeInCode AS CityCodeInCode,
		|	Addresses.CountyCodeInCode AS CountyCodeInCode,
		|	Addresses.AddressObjectCodeInCode AS AddressObjectCodeInCode
		|INTO 
		|	Streets
		|FROM
		|	Addresses AS Addresses
		|LEFT JOIN 
		|	InformationRegister.AddressClassifier AS AddressClassifier
		|ON 
		|	Addresses.AddressObjectCodeInCode = AddressClassifier.AddressObjectCodeInCode
		|	AND Addresses.CountyCodeInCode = AddressClassifier.CountyCodeInCode
		|	AND Addresses.CityCodeInCode = AddressClassifier.CityCodeInCode
		|	AND Addresses.SettlementCodeInCode = AddressClassifier.SettlementCodeInCode
		|	AND Addresses.StreetCodeInCode = AddressClassifier.StreetCodeInCode
		|WHERE
		|	AddressClassifier.AddressItemType = 5
		|");

	Query.TempTablesManager = TempTablesManager;
	Query.Execute();
EndProcedure

// Seaches for a specified address item by name and type, and returns the first match. 
// Additionally, a parent item can be specified.
//
// Parameters:
//    ItemName   - String    - address item name, including name and abbreviation.
//    ItemType   - Number    - type of the specified address item (1 - state, 2 - county, and so on).
//    ParentItem - Structure - parent item description.
//
// Returns:
//    Structure - address item details.
//
Function GetAddressItem(Val ItemName, ItemType, ParentItem)
	
	If (TrimAll(ItemName) = "") Or (ItemType = 0) Then
		Return AddressClassifierClientServer.EmptyAddressStructure();
	EndIf;
	
	// Checking if the name contains an address abbreviation of the specified level.
	// If it does, initiating search by name and address abbreviation.
	AddressAbbreviation = "";
	ItemName = NameAndAddressAbbreviation(ItemName, AddressAbbreviation);
	
	Query = New Query();
	
	RestrictionByCode = "";
	If ParentItem.Code > 0 Then // Checking for parent hierarchy compliance
		
		If ParentItem.AddressItemType <= 5 Then
			
			If ParentItem.AddressObjectCodeInCode <> 0 Then
				RestrictionByCode = RestrictionByCode + Chars.LF
				+ " AND (AddressClassifier.AddressObjectCodeInCode = &AddressObjectCodeInCode)";
				Query.SetParameter("AddressObjectCodeInCode", ParentItem.AddressObjectCodeInCode);
			EndIf;
			
			If ParentItem.CountyCodeInCode <> 0 Then
				RestrictionByCode = RestrictionByCode + Chars.LF 
				+ "  AND (AddressClassifier.CountyCodeInCode = &CountyCodeInCode)";
				Query.SetParameter("CountyCodeInCode", ParentItem.CountyCodeInCode);
			EndIf;
			
			If ParentItem.CityCodeInCode <> 0 Then
				RestrictionByCode = RestrictionByCode + Chars.LF 
				+ "  AND (AddressClassifier.CityCodeInCode = &CityCodeInCode)";
				Query.SetParameter("CityCodeInCode", ParentItem.CityCodeInCode);
			EndIf;
			
			If ParentItem.SettlementCodeInCode <> 0 Then
				RestrictionByCode = RestrictionByCode + Chars.LF 
				+ "  AND (AddressClassifier.SettlementCodeInCode = &SettlementCodeInCode)";
				Query.SetParameter("SettlementCodeInCode", ParentItem.SettlementCodeInCode);
			EndIf;
			
			If ParentItem.StreetCodeInCode <> 0 Then
				RestrictionByCode = RestrictionByCode + Chars.LF 
				+ "  AND (AddressClassifier.StreetCodeInCode = &StreetCodeInCode)";
				Query.SetParameter("StreetCodeInCode", ParentItem.StreetCodeInCode);
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// Address abbreviation restriction
	If AddressAbbreviation <> "" Then
		RestrictionByCode = RestrictionByCode + Chars.LF + "  AND (AddressClassifier.Abbr = &AddressAbbreviation)";
		Query.SetParameter("AddressAbbreviation", AddressAbbreviation);
	EndIf;
	
	Query.Text = " 
		|SELECT TOP 1
		|	AddressClassifier.Code AS Code,
		|	AddressClassifier.AddressObjectCodeInCode AS AddressObjectCodeInCode,
		|	AddressClassifier.Description AS Description,
		|	AddressClassifier.Abbr AS Abbr,
		|	AddressClassifier.PostalCode AS PostalCode,
		|	AddressClassifier.AddressItemType AS AddressItemType,
		|	AddressClassifier.CountyCodeInCode AS CountyCodeInCode,
		|	AddressClassifier.CityCodeInCode AS CityCodeInCode,
		|	AddressClassifier.SettlementCodeInCode AS SettlementCodeInCode,
		|	AddressClassifier.StreetCodeInCode AS StreetCodeInCode,
		|	AddressClassifier.DataIsCurrentFlag AS DataIsCurrentFlag
		|FROM
		|	InformationRegister.AddressClassifier AS AddressClassifier
		|
		|WHERE
		|	AddressClassifier.AddressItemType = &AddressItemType
		|	AND AddressClassifier.Description = &Description "
		+ RestrictionByCode;
	
	Query.SetParameter("AddressItemType", ItemType);
	Query.SetParameter("Description", ItemName);
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return AddressClassifierClientServer.EmptyAddressStructure();
	EndIf;
		
	Selection = QueryResult.Select();
	Selection.Next();
	ResultStructure = New Structure;
	For Each Column In QueryResult.Columns Do
		ResultStructure.Insert(Column.Name, Selection[Column.Name]);
	EndDo;
	
	Return ResultStructure;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// String management procedures

// Generates autocompletion query for the information register.
//
// Parameters:
//    Text                - String    - query string.
//    ParametersStructure - Structure - parameter structure.
//    ItemCount           - Number    - number of first items.
//
// Returns:
//    ValueTable - query result.
//
Function GetAutoCompleteQueryResultForRegister(Val Text, ParametersStructure, ItemCount)
	
	Object = Metadata.InformationRegisters.AddressClassifier;
	
	FilterStringByStructure = "";
	
	Query = CreateQueryForAutoCompleteList(Text, FilterStringByStructure, ParametersStructure, "RegisterTable");
	
	FieldRow = "SELECT ALLOWED TOP " + String(ItemCount) + " RegisterTable.* ";
	
	Query.Text = FieldRow + " FROM InformationRegister.AddressClassifier AS RegisterTable WHERE ";
	
	// Setting search field restrictions
	RestrictionByField = " (RegisterTable.Description LIKE &AutoCompleteText ESCAPE ""~"") ";
	
	Query.Text = Query.Text + " ( " + RestrictionByField + " ) " + FilterStringByStructure;
	
	Return Query.Execute().Unload();
EndFunction

// Creates a query object, sets AutoCompleteText parameter for this object, 
// and removes unnecessary characters from the search string.
//
// Parameters:
//    SearchString            - String    - search string in query
//    FilterStringByStructure - String    - structure filter string.
//    ParametersStructure     - Structure - query parameter structure.
//    RestrictionsTableName   - String    - restrictions table name.
//
// Returns:
//    String - query text.
//
Function CreateQueryForAutoCompleteList(SearchString, FilterStringByStructure, ParametersStructure, RestrictionsTableName)
	
	Query = New Query;
	SearchString = CommonUse.GenerateSearchQueryString(SearchString);
	Query.SetParameter("AutoCompleteText", (SearchString + "%"));
	
	// Setting restrictions
	FilterStringByStructure = "";
	For Each StructureItem In ParametersStructure Do
		Key 	 = StructureItem.Key;
		Value = StructureItem.Value;

		Query.SetParameter(Key, Value);
		FilterStringByStructure = FilterStringByStructure + " And " + RestrictionsTableName + "." + Key + " IN (&"+ Key + ")";
	EndDo; 
	
	Return Query;
EndFunction

// Generates an address description string based on the passed address items.
//
// Parameters:
//    DetailsTillLevel - Number - address object detail level.
//    State            - String - state.
//    County           - String - county.
//    City             - String - city.
//    Settlement       - String - settlement.
//    Street           - String - street name.
//
// Returns:
//    String - description.
//
Function GetDetailsByAddressItems(DetailsTillLevel, State = "", County = "", City = "", 
	Settlement = "", Street = "")
	
	Description = Street;
	
	If DetailsTillLevel <= 4 Then // Street, Settlement
		
		If IsBlankString(Description) And IsBlankString(Settlement) Then
			Description = "";
		ElsIf IsBlankString(Description) Then
			Description = Settlement;
		ElsIf IsBlankString(Settlement) Then
			Description = Description;
		Else
			Description = Description + ", " + Settlement;
		EndIf;
		
	EndIf;
	
	If DetailsTillLevel <= 3 Then // Street, Settlement, City
		
		If IsBlankString(Description) And IsBlankString(City) Then
			Description = "";
		ElsIf IsBlankString(Description) Then
			Description = City;
		ElsIf IsBlankString(City) Then
			Description = Description;
		Else
			Description = Description + ", " + City;
		EndIf;
		
	EndIf;
	
	If DetailsTillLevel <= 2 Then // Street, Settlement, City, County
		
		If IsBlankString(Description) And IsBlankString(County) Then
			Description = "";
		ElsIf IsBlankString(Description) Then
			Description = County;
		ElsIf IsBlankString(County) Then
			Description = Description;
		Else
			Description = Description + ", " + County;
		EndIf;
		
	EndIf;
	
	If DetailsTillLevel = 1 Then // Street, Settlement, City, County, State
		
		If IsBlankString(Description) And IsBlankString(State) Then
			Description = "";
		ElsIf IsBlankString(Description) Then
			Description = State;
		ElsIf IsBlankString(State) Then
			Description = Description;
		Else
			Description = Description + ", " + State;
		EndIf;
		
	EndIf;
	
	Return Description;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Address code management procedures and functions

// Returns a restriction structure by address.
//
// Parameters:
//    StateField      - String - state.
//    CountyField     - String - county.
//    CityField       - String - city.
//    SettlementField - String - settlement.
//    StreetName      - String - street.
//    ItemLevel       - Number - address item level.
//
// Returns:
//    Structure - restriction structure.
//
Function GetRestrictionStructureByAddress(StateField, CountyField, CityField, SettlementField, StreetName, ItemLevel) 
	
	If ItemLevel > 1 Then
		
		ParentCode = Undefined;
		RestrictionStructure = ReturnRestrictionStructureByParent(
			StateField, CountyField, CityField, SettlementField, StreetName, 
			ParentCode, ItemLevel);
		
	Else
		RestrictionStructure = New Structure();
		RestrictionStructure.Insert("AddressItemType", ItemLevel);
	EndIf;
	
	Return RestrictionStructure;
EndFunction

// Adds a non-zero code value to the structure.
// 
// Parameters:
//    ParentLevel   - Number - parent level.
//    StructureData - Structure - structure used to add data.
//    ItemName      - String - item name.
//    ItemLevel     - Number - item level.
//    ItemCode      - Number - item code.
//
Procedure AddCodeToStructure(MaximumLevel, ParentLevel, StructureData, ItemName, ItemLevel, ItemCode)
	
	If ItemCode<>0 Or ParentLevel>=ItemLevel Then
		// Adding is mandatory
		StructureData.Insert(ItemName, ItemCode);
	ElsIf ItemCode=0 And MaximumLevel>ItemLevel Then
		StructureData.Insert(ItemName, ItemCode);
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Address classifier data import background job
// 

// Background import handler
//
Procedure AddressClassifierImportBackgroundJob(Val Parameters, Val ResultAddress) Export
	
	StateCodes      = Parameters[0];	// Array of state codes to be used for import
	FileDescription = Parameters[1];	// Array of transferred file description structures
	
	// Flag specifying that files are broken down by state (a separate set of files assigned for each state)
	SeparateFilesForStates = Parameters.Count() > 2 And (Parameters[2] = "ACWebsite"); 
	
	// Extracting files, all file names are in uppercase
	WorkingDirectory = CommonUseClientServer.AddFinalPathSeparator(GetTempFileName());
	CreateDirectory(WorkingDirectory);
	
	FileVersions = New Map;
	For Each Description In FileDescription Do
		// File names always must be in uppercase
		File = New File(Description.Name);
		FileName = WorkingDirectory + Upper(File.Name);
		
		Data = ?(TypeOf(Description.Location) = Type("String"), GetFromTempStorage(Description.Location), Description.Location);
		Data.Write(FileName);
		
		File = New File(FileName);
		File.SetModificationUniversalTime(Description.ModificationTime);
		
		If Upper(Right(FileName, 4)) = ".ZIP" Then
			// Extracting files, the original compressed file will be deleted together with the used directory
			ZIPReader = New ZipFileReader(FileName);
			ZIPReader.ExtractAll(WorkingDirectory, ZIPRestoreFilePathsMode.DontRestore);
		EndIf;
		
		FileVersions.Insert(FileName, Description.ModificationTime); 
	EndDo;
	
	// Determining dates (versions), creating an array for import purposes
	AddressObjects = New Array;
	AvailableVersions = New Map;
	
	// Abbreviations
	AddressObjects.Add("SO");
	
	VersionBeingImported = CurrentUniversalDate();
	
	If SeparateFilesForStates Then
		
		For Each StateCode In StateCodes Do
			AddressObject = Format(StateCode, "ND=2; NZ=; NLZ=; NG=");
			AddressObjects.Add(AddressObject);
			
			FileName = WorkingDirectory + "BASE" + AddressObject + ".ZIP";
			VersionToImport  = FileVersions[FileName];
			If VersionToImport  = Undefined Then
				VersionToImport = VersionBeingImported;
			EndIf;
			
			AvailableVersions.Insert(AddressObject, VersionToImport);
		EndDo;
		
	Else
		// For CLASSF.DBF file 
		//FileName = WorkingDirectory + "CLASSF.DBF";
		FileName = WorkingDirectory + "CLASSF45.DBF";
		VersionToImport  = FileVersions[FileName];
		If VersionToImport  = Undefined Then
			VersionToImport = VersionBeingImported;
		EndIf;
		
		For Each StateCode In StateCodes Do
			AddressObject = Format(StateCode, "ND=2; NZ=; NLZ=; NG=");
			AddressObjects.Add(AddressObject);
			
			AvailableVersions.Insert(AddressObject, VersionToImport);
		EndDo;
	EndIf;
	
	ImportParameters = New Structure;
	ImportParameters.Insert("AddressObjects",                   AddressObjects);
	ImportParameters.Insert("PathToServerData",                 WorkingDirectory);
	ImportParameters.Insert("VersionOfAddressClassifierToImport", VersionToImport);
	ImportParameters.Insert("ImportDataSource",                 ?(SeparateFilesForStates, 1, 2));
	ImportParameters.Insert("AvailableVersions",                AvailableVersions);
	
	// Data import
	ImportAddressDataFromClassifierFilesToInformationRegister(ImportParameters, Undefined);
	
	// Cleanup
	Try
		DeleteFiles(WorkingDirectory);
	Except
		// No processing required, files will be deleted later
	EndTry;
	
	// Updating state content
	InformationRegisters.AddressClassifier.UpdateRegionContentByClassifier();
EndProcedure

// Background clearing handler
//
Procedure AddressClassifierClearingBackgroundJob(Val Parameters, Val ResultAddress) Export
	
	StateCodes = Parameters[0];	// Array of state codes used for import purposes
	
	ToDeleteCount = StateCodes.Count();
	Position             = 0;
	
	ToDelete = New Array(1);
	
	While Position < ToDeleteCount Do
		StateCode = StateCodes[Position];
		
		StateCodeString = Format(StateCode, "ND=2; NZ=; NLZ=");
		
		LongActions.RegisterProgress( , StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Clearing state ""%1 - %2"" (%3 remaining)...'"), 
			StateCodeString, InformationRegisters.AddressClassifier.StateDescriptionByCode(StateCode),
			Format(ToDeleteCount - Position - 1, "NZ=")
		));
		
		// Deleting and updating version simultaneously
		ToDelete[0] = StateCodeString;
		DeleteAddressData(ToDelete);
		
		Position = Position + 1;
	EndDo;
	
	// Updating state content
	InformationRegisters.AddressClassifier.UpdateRegionContentByClassifier();
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// Reflecting address classifier changes in building lists
// 

// Checks a building option.
//
Function BuildingUnitOptionFits(Val Structure, Val Option, Val BuildingPartTypes, BuildingDescriptionCache)
	
	If Option.IsRange Then 
		If BuildingInRange(Structure, Option.Description) Then
			Return True;
		EndIf;
	Else
		If BuildingInDescription(Structure, Option.Description, False, BuildingPartTypes, BuildingDescriptionCache) Then
			Return True;
		EndIf;
	EndIf;
	
	Return False;
EndFunction

// Generates error text considering the specified hierarchy. The state is always specified.
//
Function ClassifierHierarchySearchErrorText(Val AddressObject, Val ErrorField)
	ErrorText = "";
	
	If ErrorField = "State" Then
		ErrorText = NStr("en = 'State ""%1"" is not found in the address classifier.'");
	
	ElsIf ErrorField = "County" Then
		ErrorText = NStr("en = 'County ""%2"" is not found in state ""%1"" of the address classifier.'") 
		
	ElsIf ErrorField = "City" Then
		CountySpecified = Not IsBlankString(AddressObject.County);
		If CountySpecified Then
			ErrorText = NStr("en = 'City ""%3"" is not found in county ""%2"", state ""%1"" of the address classifier.'");
			
		Else
			ErrorText = NStr("en = 'City ""%3"" is not found in state ""%1"" of the address classifier.'");
			
		EndIf;
		
	ElsIf ErrorField = "Settlement" Then
		CountySpecified = Not IsBlankString(AddressObject.County);
		CitySpecified = Not IsBlankString(AddressObject.City);
		
		If CountySpecified And CitySpecified Then
			ErrorText = NStr("en = 'Settlement ""%4"" is not found in city ""%3"", county ""%2"", state ""%1"" of the address classifier.'");
			
		ElsIf CountySpecified And Not CitySpecified Then
			ErrorText = NStr("en = 'Settlement ""%4"" is not found in county ""%2"", state ""%1"" of the address classifier.'");
			
		ElsIf Not CountySpecified And CitySpecified Then
			ErrorText = NStr("en = 'Settlement ""%4"" is not found in city ""%3"", state ""%1"" of the address classifier.'");
			
		ElsIf Not CountySpecified And Not CitySpecified Then
			ErrorText = NStr("en = 'Settlement ""%4"" is not found in state ""%1"" of the address classifier.'");
			
		EndIf;
		
	ElsIf ErrorField = "Street" Then
		CountySpecified = Not IsBlankString(AddressObject.County);
		CitySpecified = Not IsBlankString(AddressObject.City);
		SettlementSpecified = Not IsBlankString(AddressObject.Settlement);
		
		If CountySpecified And CitySpecified And SettlementSpecified Then
			ErrorText = NStr("en = 'Street ""%5"" is not found in settlement ""%4"", city ""%3"", county ""%2"", state ""%1"" of the address classifier.'");
			
		ElsIf CountySpecified And CitySpecified And Not SettlementSpecified Then
			ErrorText = NStr("en = 'Street ""%5"" is not found in city ""%3"", county ""%2"", state ""%1"" of the address classifier.'");
			
		ElsIf CountySpecified And Not CitySpecified And SettlementSpecified Then
			ErrorText = NStr("en = 'Street ""%5"" is not found in settlement ""%4"", county ""%2"", state ""%1"" of the address classifier.'");
			
		ElsIf CountySpecified And Not CitySpecified And Not SettlementSpecified Then
			ErrorText = NStr("en = 'Street ""%5"" is not found in county ""%2"", state ""%1"" of the address classifier.'");
			
		ElsIf Not CountySpecified And CitySpecified And SettlementSpecified Then
			ErrorText = NStr("en = 'Street ""%5"" is not found in settlement ""%4"", city ""%3"", state ""%1"" of the address classifier.'");
			
		ElsIf Not CountySpecified And CitySpecified And Not SettlementSpecified Then
			ErrorText = NStr("en = 'Street ""%5"" is not found in city ""%3"", state ""%1"" of the address classifier.'");
			
		ElsIf Not CountySpecified And Not CitySpecified And SettlementSpecified Then
			ErrorText = NStr("en = 'Street ""%5"" is not found in settlement ""%4"", state ""%1"" of the address classifier.'");
			
		ElsIf Not CountySpecified And Not CitySpecified And Not SettlementSpecified Then
			ErrorText = NStr("en = 'Street ""%5"" is not found in state ""%1"" of the address classifier.'");
			
		EndIf;
		
	ElsIf ErrorField = "Building" Then
		ErrorText = NStr("en = 'Building ""%6"" is not found in the address classifier.'");
		
	ElsIf ErrorField = "Unit" Then
		ErrorText = NStr("en = 'Unit ""%7"" of building ""%6"" is not found in the address classifier.'");
		
	ElsIf ErrorField = "PostalCode" Then
		ErrorText = NStr("en = 'Postal code ""%8"" does not match the address.'");
		
	EndIf;
	
	Return StringFunctionsClientServer.SubstituteParametersInString(
		ErrorText, 
		AddressObject.State, AddressObject.County, AddressObject.City, AddressObject.Settlement, AddressObject.Street,
		AddressObject.BuildingNumber, AddressObject.UnitNumber, AddressObject.PostalCode
	);
	
EndFunction

// Separates the initial name into description and abbreviation.
// Abbreviation always goes after the final space.
//
// Parameters:
//     Name - String - Full name (for example, Main st.).
//
// Returns:
//     Structure - contains fields 
//       * Description  - String - Description (for example, Main). If no abbreviation is found, 
//                                 the description is identical to the initial name.
//       * Abbreviation - String - Abbreviation (for example, st.) If no abbreviation is found, 
//                                 returns an empty string.
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

// Returns flag specifying whether the passed description is a building number range.
//
// Parameters:
//     Description - String - range description. Range can be specified as "E" or "O", 
//                            meaning all even (odd) building numbers, 
//                            or as a hyphen-separated numerical range.
//
// Returns:
//     Boolean - True if the passed string can be interpreted as a range of building numbers.
///
Function IsRange(Val Description)
	Return Description="O" 
	    Or Description="E"
		Or Find(Description, "-") > 0
EndFunction

// Checks whether a building number is within the specified range.
// 
// Parameters:
//     Building    - Structure - building description, containing fields describing building and unit.
//     Description - String    - range description.
//
// Returns:
//     Boolean - flag specifying whether the building number is within the range.
//
Function BuildingInRange(Val Structure, Val Description)
	
	HyphenPosition = Find(Description, "-");
	If HyphenPosition = 0 And Description <> "O" And Description <> "E" Then
		// Not a range
		Return False;
	EndIf;
	
	NumberType = New TypeDescription("Number");
	
	// Parsing numerical part of the building number
	BuildingNumber = NumericalPartOfNumber( BasicBuildingNumber(Structure) );
	If BuildingNumber = 0 Then
		// No basic building number
		Return False;
	EndIf;
	
	DescriptionLength = StrLen(Description);
	CurrentChar = Left(Description, 1);
	If CurrentChar = "O" Then
		// Odd
		If BuildingNumber % 2 = 0 Then
			// Odd range cannot contain even numbers
			Return False;
		ElsIf DescriptionLength = 1 Then
			// All odd numbers
			Return True;
		EndIf;
		Position = 2;
		
	ElsIf CurrentChar = "E" Then
		// Even
		If BuildingNumber % 2 = 1 Then
			// Even range cannot contain odd numbers
			Return False;
		ElsIf DescriptionLength = 1 Then
			// All even numbers
			Return True;
		EndIf;
		Position = 2;
		
	ElsIf IsDigit(CurrentChar) Then
		// Normal
		Position = 1;
		
	Else
		// Not a range
		Return False;
	EndIf;
	
	// Looking for range beginning
	RangeBeginning = 0;
	While Position < HyphenPosition Do
		CurrentChar = Mid(Description, Position, 1);
		Position = Position + 1;
		If CurrentChar = "(" Then
			// Possible range beginning
			Continue;
			
		ElsIf Not IsDigit(CurrentChar) Then
			// Invalid range
			Return False;
			
		EndIf;
		RangeBeginning = RangeBeginning * 10 + NumberType.AdjustValue(CurrentChar);
	EndDo;
	
	Position = Position + 1;
	// Looking for range end
	RangeEnd = 0;
	While Position<=DescriptionLength Do
		CurrentChar = Mid(Description, Position, 1);
		Position = Position + 1;
		If CurrentChar = ")" Then
			// Possible range end
			Break;
			
		ElsIf Not IsDigit(CurrentChar) Then
			// Invalid range
			Return False;
			
		EndIf;
		RangeEnd = RangeEnd * 10 + NumberType.AdjustValue(CurrentChar);
	EndDo;
		
	If RangeBeginning > RangeEnd Then
		// Invalid range
		Return False;
	EndIf;
	
	Return BuildingNumber >= RangeBeginning And BuildingNumber <= RangeEnd;
EndFunction

// Checks a building for compliance with a description.
//
// Parameters:
//     Structure                - Structure  - building description, contains Building and Unit attributes.
//     Description              - String     - separate building description.
//     ExactMatch - Boolean                  - exact match search flag. If False, will only search through 
//                                             the filled fields of Building attribute. Example: both 
//                                             "Building 2 unit 1" and "Building 2" will be found 
//                                             by description "Building 2 unit 1".
//     BuildingPartTypes        - ValueTable - building abbreviation IDs, result of BuildingPartTypes function.
//                                             If Undefined, BuildingPartTypes is calculated.
//     BuildingDescriptionCache - Map        - building description cache (managed automatically).
//
// Returns:
//    Boolean - flag specifying whether the building matches the description.
//
Function BuildingInDescription(Val Structure, Val Description, Val ExactMatch = True, BuildingPartTypes = Undefined, BuildingDescriptionCache = Undefined)
	
	// Parsing to structure
	If BuildingDescriptionCache = Undefined Then
		BuildingDescriptionCache = New Map;
	EndIf;
	
	DescriptionParts = BuildingDescriptionCache[Description];
	If DescriptionParts = Undefined Then
		DescriptionParts = BuildingDescriptionStructure(Description, BuildingPartTypes);
		BuildingDescriptionCache[Description] = DescriptionParts;
	EndIf;
	
	// Comparing each part 
	Result = True;
	
	// Passed values must be always present in the search results
	For Each KeyValue In Structure Do
		_Key     = KeyValue.Key;
		Value = KeyValue.Value;
		
		If Not DescriptionParts.Property(_Key) Then
			Result = False;
			Break;
			
		ElsIf Not IsBlankString(Value) And DescriptionParts[_Key] <> Value Then
			Result = False;
			Break;
			
		EndIf;
		
	EndDo;
		
	If Result And ExactMatch Then
		// Search results must exactly match the passed values
		For Each KeyValue In DescriptionParts Do
			Value = KeyValue.Value;
			_Key     = KeyValue.Key;
			If Not IsBlankString(Value) Then
				If Not Structure.Property(_Key) Or Structure[_Key] <> Value Then
					Result = False;
					Break;
				EndIf;
			EndIf;
		EndDo;
	EndIf;

	Return Result;
EndFunction

// Parses the numerical part of a building number.
//
// Parameters:
//     Number - String, Number - full building number.
//
// Returns:
//     Number  - Numerical part of the number. If a numerical part is not found, returns zero.
//
Function NumericalPartOfNumber(Val Number)
	NumberType = New TypeDescription("Number");
	
	If NumberType.ContainsType(TypeOf(Number)) Then
		Return Number;
	EndIf;
	
	BuildingNumber = 0;
	For Position = 1 To StrLen(Number) Do
		CurrentChar = Mid(Number, Position, 1);
		If Not IsDigit(CurrentChar) Then
			Break;
		EndIf;
		BuildingNumber = BuildingNumber * 10 + NumberType.AdjustValue(CurrentChar);
	EndDo;
	
	Return BuildingNumber;
EndFunction

// Determines character type.
//
// Parameters:
//     Char - String - analyzed character.
//
// Returns:
//     Boolean - True if the passed character is a digit.
//
Function IsDigit(Val Char)
	
	Return Find("0123456789", Char) > 0;
	
EndFunction

// Calculates the basic building number based on the filled building data.
//
// Parameters:
//     Structure - Structure - analyzed building, with the following field:
//                 * Building  - String - corresponding numerical value.
//
// Returns:
//     String - basic building number.
//
Function BasicBuildingNumber(Val Structure)
	Result = "";
	
	If Structure.Property("Building") Then
		Result = Structure.Building;
	EndIf;
	
	Return Result;
EndFunction

// Parses a building description string retrieved from the address classifier.
//
// Parameters:
//     Description       - String     - building description from the address classifier.
//     BuildingPartTypes - ValueTable - used to parse abbreviations. If the BuildingPartTypes function 
//                                      result is Undefined, it is calculated.
//
// Returns:
//     Structure    - Key - ID, value - building number.
//                    The ID set is determined based on the data found in BuildingPartTypes result table.
//     Undefined    - if description parsing failed.
//
Function BuildingDescriptionStructure(Val Description, BuildingPartTypes = Undefined)
	
	Text = Description;
	Result = New Structure;
	
	// All additional building parts
	If BuildingPartTypes = Undefined Then
		BuildingPartTypes = BuildingPartTypes();
		For Each PartType In BuildingPartTypes Do
			Result.Insert(PartType.ID);
		EndDo;
	EndIf;
	
	// Default ID for the (possibly empty) first key
	ID = "Building";
	Result.Insert(ID);
	
	MorePartsAvailable = True;
	
	While MorePartsAvailable Do
		// Current part type
		Position = 1;
		For Each PartType In BuildingPartTypes Do
			If Left(Text, PartType.Length) = PartType.Prefix Then
				ID = PartType.ID;
				Position       = 1 + PartType.Length;
				Break;
			EndIf;
		EndDo;
		Text = Mid(Text, Position);
		
		// Part value
		Position = 0;
		For Each PartType In BuildingPartTypes Do
			// Looking for the next (closest) type expected to be followed by value
			PositionTest = Find(Text, PartType.Prefix);
			If PositionTest > 0                                                  // Found
				And (Position = 0 Or PositionTest<Position)                         // Closest
				And Not IsBlankString(Mid(Text, PositionTest + PartType.Length, 1)) // Containing value
			Then
				Position = PositionTest;
			EndIf;
		EndDo;
		
		MorePartsAvailable = Position > 0;
		If MorePartsAvailable Then
			Value = Left(Text, Position-1);
			Text = Mid(Text, Position);
		Else
			Value = Text;
		EndIf;
		
		Result.Insert(ID, StrReplace(Value, "_", "-"));
	EndDo; 
	
	Return Result;
EndFunction

// Generates a table of prefixes used as separators for address classifier data and building types. 
// Has implicit logical relation to ContactInformationClientServerCached.AddressingObjectTypesNationalAddresses().
//
// Returns - ValueTable - Available options. Contains columns:
//     * Prefix - String - separator prefix.
//     * ID     - String - structure ID.
//     * Length - Number - prefix length.
//
Function BuildingPartTypes()
	
	Result = 
		NewTableRow("UNIT",     "Unit",
		NewTableRow("U",          "Unit",
		"Prefix, ID, Length"));
		
	Result.Sort("Length DESC, Prefix");
	
	Return Result;
EndFunction

Function NewTableRow(Val Prefix, Val ID, Val Table)
	
	If TypeOf(Table) = Type("String") Then
		// List of columns to be created
		Result = New ValueTable;
		For Each KeyValue In New Structure(Table) Do
			ColumnName = KeyValue.Key;
			Result.Columns.Add(ColumnName);
			Result.Indexes.Add(ColumnName);
		EndDo;
	Else 
		Result = Table;
	EndIf; 
	
	Row = Result.Add();
	Row.Prefix  = Prefix;
	Row.ID      = ID;
	Row.Length  = StrLen(Prefix);
	
	Return Result;
EndFunction

Procedure FillAddressStructureBySelection(Val Target, Val Source, Val Prefix = "")
	TypeArray = New Array(1);
	
	For Each KeyValue In Target Do
		
		Name = KeyValue.Key;
		Type = TypeOf(Target[Name]);
		If Type = Undefined Then
			Target[Name] = Source[Prefix + Name];
		Else
			TypeArray[0] = Type;
			NewType = New TypeDescription(TypeArray);
			Target[Name] = NewType.AdjustValue(Source[Prefix + Name]);
		EndIf;
		
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Data for ContactInformation subsystem, breaking subsystem interrelations
//

// Returns a string to be used for LIKE search.
Function EscapeSpecialCharacters(Text)
	Result = Text;
	SpecialCharacter = "\";
	Service = "%_[]^" + SpecialCharacter;
	For Index = 1 To StrLen(Service) Do
		Char = Mid(Service, Index, 1);
		Result = StrReplace(Result, Char, SpecialCharacter + Char);
	EndDo;
	Return Result;
EndFunction

Function QueryAddressDeserializationByACPresentation(Val WorldCountriesSource = Undefined) Export
	
	Query = New Query("
		|SELECT 
		|	AddressData.Position0   AS Position0,
		|	AddressData.Position    AS Position,
		|	AddressData.Value       AS Value,
		|	AddressData.Description AS Description,
		|	AddressData.Abbr        AS Abbr,
		|	AddressData.Beginning   AS Beginning,
		|	AddressData.Length      AS Length
		|INTO 
		|	AddressData
		|FROM
		|	&AddressData AS AddressData
		|INDEX BY
		|	Position0, Position, Description, Abbr
		|;//////////////////////////////////////////////////////////////////////////////
		|
		|SELECT 
		|	RecognizedData.Position    AS Position,
		|	RecognizedData.Value       AS Value,
		|	RecognizedData.Description AS Description,
		|	RecognizedData.Abbr        AS Abbr,
		|	RecognizedData.Beginning   AS Beginning,
		|	RecognizedData.Length      AS Length,
		|	FALSE                      AS Processed,
		|
		|	RecognizedData.LevelByClassifier AS LevelByClassifier,
		|	CASE 
		|		WHEN RecognizedData.LevelByClassifier IS NULL THEN FALSE 
		|		ELSE TRUE 
		|	END AS FoundInClassifier,
		|
		|	RecognizedData.LevelByAbbreviations AS LevelByAbbreviations,
		|	CASE 
		|		WHEN RecognizedData.LevelByAbbreviations IS NULL THEN FALSE 
		|		ELSE TRUE 
		|	END AS FoundInAbbreviations,
		|
		|	CASE
		|		WHEN Not RecognizedData.MinimumWorldCountries IS NULL THEN TRUE
		|		WHEN RecognizedData.Value IN (&ClassifierCountries) THEN TRUE
		|		ELSE FALSE
		|	END AS FoundInWorldCountries,
		|
		|	CASE 
		|		WHEN RecognizedData.Value = &USAName THEN TRUE
		|		ELSE FALSE
		|	END AS IsUSA,
		|	
		|	CASE
		|		WHEN RecognizedData.Description LIKE ""[0-9][0-9][0-9][0-9][0-9][0-9]"" THEN TRUE
		|		ELSE FALSE
		|	END AS FoundByPostalCode
		|
		|FROM (
		|	SELECT 
		|		AddressData.Position    AS Position,
		|		AddressData.Value       AS Value,
		|		AddressData.Description AS Description,
		|		AddressData.Abbr        AS Abbr,
		|
		|		AddressData.Beginning     AS Beginning,
		|		AddressData.Length        AS Length,
		|
		|		MIN(AddressClassifier.AddressItemType) AS LevelByClassifier,
		|		MIN(AddressAbbreviations.Level)        AS LevelByAbbreviations,
		|	
		|		MIN(WorldCountries.Description) AS MinimumWorldCountries
		|
		|	FROM 
		|		AddressData AS AddressData
		|	LEFT JOIN
		|		InformationRegister.AddressClassifier AS AddressClassifier
		|	ON
		|		AddressClassifier.Description = AddressData.Description
		|		AND AddressClassifier.Abbr = AddressData.Abbr
		|		AND AddressClassifier.AddressItemType <= 5
		|		AND AddressClassifier.AddressItemType >= AddressData.Position0
		|	LEFT JOIN
		|		InformationRegister.AddressAbbreviations AS AddressAbbreviations
		|	ON
		|		AddressAbbreviations.Abbr = AddressData.Abbr
		|		AND AddressAbbreviations.Level <= 5
		|	LEFT JOIN
		|		" + ?(WorldCountriesSource = Undefined, "( SELECT &USAName AS Description )", WorldCountriesSource) + " AS
		|	WorldCountries
		|	ON WorldCountries.Description
		|	= AddressData.Value GROUP
		|	BY
		|	AddressData.Position,
		|	AddressData.Value,
		|	AddressData.Description,
		|	AddressData.Abbr,
		|	AddressData.Beginning,
		|AddressData.Length ) AS
		|RecognizedData
		|ORDER BY
		|	RecognizedData.Position DESC
		|");
		
	Return Query;
EndFunction

Function QuerySettlementAutoCompleteResultsAC(Val NumberOfRowsToSelect, Val HideObsoleteAddresses) Export
	
	RelevanceRestriction = ?(HideObsoleteAddresses, "AND Addresses.RelevanceFlag = 0", "");
	LimitOfRowsToSelect  = Format(NumberOfRowsToSelect, "NZ=; NG=");
	
	Query = New Query("
		|SELECT 
		|	AddressObjectCodeInCode AS AddressObjectCodeInCode
		|INTO
		|	AllImportedStates
		|FROM
		|	InformationRegister.AddressClassifier AS ImportedStatesInternal
		|WHERE
		|	AddressItemType = 1
		|	AND 1 IN (
		|		               SELECT TOP 1 1 FROM InformationRegister.AddressClassifier WHERE AddressObjectCodeInCode = ImportedStatesInternal.AddressObjectCodeInCode AND AddressItemType = 2
		|		UNION ALL SELECT TOP 1 1 FROM InformationRegister.AddressClassifier WHERE AddressObjectCodeInCode = ImportedStatesInternal.AddressObjectCodeInCode AND AddressItemType = 3
		|		UNION ALL SELECT TOP 1 1 FROM InformationRegister.AddressClassifier WHERE AddressObjectCodeInCode = ImportedStatesInternal.AddressObjectCodeInCode AND AddressItemType = 4
		|		UNION ALL SELECT TOP 1 1 FROM InformationRegister.AddressClassifier WHERE AddressObjectCodeInCode = ImportedStatesInternal.AddressObjectCodeInCode AND AddressItemType = 5
		|		UNION ALL SELECT TOP 1 1 FROM InformationRegister.AddressClassifier WHERE AddressObjectCodeInCode = ImportedStatesInternal.AddressObjectCodeInCode AND AddressItemType = 6
		|	)
		|INDEX BY
		|	AddressObjectCodeInCode
		|;//////////////////////////////////////////////////////////////////////////////////////////
		|
		|SELECT TOP " + LimitOfRowsToSelect + " 
		|	SimilarAddresses.Code           AS Code,
		|	SimilarAddresses.PostalCode     AS PostalCode, 
		|	SimilarAddresses.AlternateNames AS AlternateNames,
		|	
		|	SimilarAddresses.Description        AS AddressesDescription,
		|	SimilarAddresses.Abbr               AS AddressesAbbreviation,
		|	
		|	CASE 
		|		WHEN ImportedStates.AddressObjectCodeInCode IS NULL THEN TRUE ELSE FALSE
		|	END AS CanImportState,
		|	
		|	CASE 
		|		WHEN SimilarAddresses.DataIsCurrentFlag <> 0 THEN TRUE
		|		ELSE FALSE
		|	END AS Obsolete,
		|	
		|	Settlements.Abbr          AS SettlementsAbbreviation,
		|	Settlements.Description   AS SettlementsDescription,
		|	
		|	Cities.Abbr               AS CitiesAbbreviation,
		|	Cities.Description        AS CitiesDescription,
		|	
		|	Counties.Abbr             AS CountiesAbbreviation,
		|	Counties.Description      AS CountiesDescription,
		|	
		|	States.Abbr               AS StatesAbbreviation,
		|	States.Description        AS StatesDescription
		|	
		|FROM
		|	InformationRegister.AddressClassifier AS SimilarAddresses
		|	
		|LEFT JOIN 
		|	InformationRegister.AddressClassifier AS States
		|ON
		|	States.AddressItemType = 1
		|	AND States.AddressObjectCodeInCode  = SimilarAddresses.AddressObjectCodeInCode
		|	AND States.CountyCodeInCode            = 0
		|	AND States.CityCodeInCode            = 0
		|	AND States.SettlementCodeInCode = 0
		|	AND States.StreetCodeInCode             = 0
		|	 
		|LEFT JOIN 
		|	InformationRegister.AddressClassifier AS Counties
		|ON
		|	Counties.AddressItemType = 2
		|	AND Counties.AddressObjectCodeInCode  = SimilarAddresses.AddressObjectCodeInCode
		|	AND Counties.CountyCodeInCode         = SimilarAddresses.CountyCodeInCode
		|	AND Counties.CityCodeInCode           = 0
		|	AND Counties.SettlementCodeInCode     = 0
		|	AND Counties.StreetCodeInCode         = 0
		|	
		|LEFT JOIN 
		|	InformationRegister.AddressClassifier AS Cities
		|ON
		|	Cities.AddressItemType = 3
		|	AND Cities.AddressObjectCodeInCode  = SimilarAddresses.AddressObjectCodeInCode
		|	AND Cities.CountyCodeInCode         = SimilarAddresses.CountyCodeInCode
		|	AND Cities.CityCodeInCode           = SimilarAddresses.CityCodeInCode
		|	AND Cities.SettlementCodeInCode     = 0
		|	AND Cities.StreetCodeInCode         = 0
		|	
		|LEFT JOIN 
		|	InformationRegister.AddressClassifier AS Settlements
		|ON
		|	Settlements.AddressItemType = 4
		|	AND Settlements.AddressObjectCodeInCode = SimilarAddresses.AddressObjectCodeInCode
		|	AND Settlements.CountyCodeInCode        = SimilarAddresses.CountyCodeInCode
		|	AND Settlements.CityCodeInCode          = SimilarAddresses.CityCodeInCode
		|	AND Settlements.SettlementCodeInCode    = SimilarAddresses.SettlementCodeInCode
		|	AND Settlements.StreetCodeInCode        = 0
		|	
		|LEFT JOIN 
		|	AllImportedStates AS ImportedStates
		|ON
		|	ImportedStates.AddressObjectCodeInCode  = SimilarAddresses.AddressObjectCodeInCode
		|	
		|WHERE
		|	SimilarAddresses.AddressItemType <= 4
		|	AND SimilarAddresses.Description LIKE &TextBeginning ESCAPE ""\""
		|	" + RelevanceRestriction + "
		|
		|ORDER BY SimilarAddresses.Description, SimilarAddresses.AddressItemType, States.Description, States.Abbr, Counties.Description, Counties.Abbr, Cities.Description, Cities.Abbr, Settlements.Description, Settlements.Abbr
		|
		|");
		
	Return Query;
EndFunction

Function QueryStreetAutoCompleteResultsAC(Val NumberOfRowsToSelect, Val HideObsoleteAddresses) Export
	
	Query = New Query("
		|SELECT ALLOWED TOP " + Format(NumberOfRowsToSelect, "NZ=; NG=") + "
		|	Streets.PostalCode     AS PostalCode,
		|	Streets.AlternateNames AS AlternateNames,
		|	
		|	Streets.Code AS Code,
		|	
		|	CASE 
		|		WHEN Streets.DataIsCurrentFlag <> 0 THEN TRUE
		|		ELSE FALSE
		|	END AS Obsolete,
		|	
		|	Streets.Description AS Description,
		|	Streets.Abbr        AS Abbr
		|	
		|FROM
		|	InformationRegister.AddressClassifier AS Settlement
		|LEFT JOIN
		|	InformationRegister.AddressClassifier AS Streets
		|ON
		|	Streets.AddressItemType = 5
		|	AND Streets.AddressObjectCodeInCode  = Settlement.AddressObjectCodeInCode
		|	AND Streets.CountyCodeInCode         = Settlement.CountyCodeInCode 
		|	AND Streets.CityCodeInCode           = Settlement.CityCodeInCode 
		|	AND Streets.SettlementCodeInCode     = Settlement.SettlementCodeInCode
		|   " + ?(HideObsoleteAddresses, "AND Streets.RelevanceFlag = 0","") + "
		|
		|WHERE
		|	Settlement.Code =
		|	&Code
		|	AND ( Streets.Description LIKE &StringBeginning
		|	ESCAPE ""\""
		|	OR Streets.Description LIKE &WordBeginning ESCAPE
		|	""\""
		|
		|) ORDER
		|	BY
		|	Obsolete, ISNULL(Streets.Description, """") + ISNULL(Streets.Abbreviation, """")
		|");
		
	Return Query;
EndFunction

// Parses a text string.
Function QuerySettlementsByPresentationAC(Val AddressParts, Val NumberOfRowsToSelect, Val HideObsoleteAddresses) Export
	
	AdditionalSearchStrings = AddressParts.UBound();
	
	Query = New Query;
	TopLimiter = "zzzzz";
	
	Description = AddressParts[0].Description;
	Abbr   = AddressParts[0].Abbr;
	If AdditionalSearchStrings = 0 And IsBlankString(Abbr) Then
		DescriptionCondition = "(Addresses.Description >= &SearchDescription0 AND Addresses.Description < &SearchLimiter0)";
	Else
		DescriptionCondition = "(Addresses.Description = &SearchDescription0 AND Addresses.Abbr = &SearchAbbreviation0)";
	EndIf;
	Query.SetParameter("SearchDescription0", Description);
	Query.SetParameter("SearchLimiter0", Description + TopLimiter);
	Query.SetParameter("SearchAbbreviation0",   Abbr);
	
	For Position = 1 To AdditionalSearchStrings Do
		PositionNumber = Format(Position, "NZ=; NG=");
		ParameterNameDescription = "SearchDescription" + PositionNumber;
		ParameterNameAbbreviation   = "SearchAbbreviation"   + PositionNumber;
		ParameterNameLimiter = "SearchLimiter" + PositionNumber;
		
		Description = AddressParts[Position].Description;
		Abbr   = AddressParts[Position].Abbr;
		If IsBlankString(Abbr) Then
			DescriptionCondition = DescriptionCondition + StringFunctionsClientServer.SubstituteParametersInString("
				| AND ( 
				|     (Settlements.Description >= &%1 AND Settlements.Description < &%2) 
				| OR  (Cities.Description >= &%1 AND Cities.Description < &%2) 
				| OR  (Counties.Description >= &%1 AND Counties.Description < &%2) 
				| OR  (States.Description >= &%1 AND States.Description < &%2) 
				| )",
				ParameterNameDescription, ParameterNameLimiter);
		Else
			DescriptionCondition = DescriptionCondition + StringFunctionsClientServer.SubstituteParametersInString("
				| AND ( 
				|     (Settlements.Description = &%1 AND Settlements.Abbr = &%2) 
				| OR  (Cities.Description = &%1 AND Cities.Abbr = &%2) 
				| OR  (Counties.Description = &%1 AND Counties.Abbr = &%2) 
				| OR  (States.Description = &%1 AND States.Abbr = &%2) 
				| )",
				ParameterNameDescription, ParameterNameAbbreviation);
		EndIf;
		Query.SetParameter(ParameterNameDescription, Description);
		Query.SetParameter(ParameterNameLimiter, Description + TopLimiter);
		Query.SetParameter(ParameterNameAbbreviation,   Abbr);
	EndDo;
	
	Query.Text = "
		|SELECT ALLOWED TOP " + Format(NumberOfRowsToSelect, "NZ=; NG=") + "
		|	Addresses.Code AS Code,
		|	
		|	CASE 
		|		WHEN Addresses.DataIsCurrentFlag <> 0 THEN TRUE
		|		WHEN States.DataIsCurrentFlag <> 0 THEN TRUE
		|		WHEN Counties.DataIsCurrentFlag <> 0 THEN TRUE
		|		WHEN Cities.DataIsCurrentFlag <> 0 THEN TRUE
		|		WHEN Settlements.DataIsCurrentFlag <> 0 THEN TRUE
		|		ELSE FALSE
		|	END AS Obsolete,
		|	
		|	States.Code        AS StatesCode,
		|	States.Abbr        AS StatesAbbreviation,
		|	States.Description AS StatesDescription,
		|	
		|	Counties.Code        AS CountiesCode,
		|	Counties.Abbr        AS CountiesAbbreviation,
		|	Counties.Description AS CountiesDescription,
		|	
		|	Cities.Code        AS CitiesCode,
		|	Cities.Abbr        AS CitiesAbbreviation,
		|	Cities.Description AS CitiesDescription,
		|	
		|	Settlements.Code        AS SettlementsCode,
		|	Settlements.Abbr        AS SettlementsAbbreviation,
		|	Settlements.Description AS SettlementsDescription
		|FROM
		|	InformationRegister.AddressClassifier AS Addresses
		|	
		|LEFT JOIN 
		|	InformationRegister.AddressClassifier AS States
		|ON
		|	States.AddressItemType = 1
		|	AND States.AddressObjectCodeInCode  = Addresses.AddressObjectCodeInCode
		|	AND States.CountyCodeInCode         = 0
		|	AND States.CityCodeInCode           = 0
		|	AND States.SettlementCodeInCode     = 0
		|	AND States.StreetCodeInCode         = 0
		|	" + ?(HideObsoleteAddresses, "AND States.RelevanceFlag = 0","") + "
		|	 
		|LEFT JOIN
		|  InformationRegister.AddressClassifier AS Counties
		|ON
		|  Counties.AddressItemType = 2
		|  AND Counties.AddressObjectCodeInCode = Addresses.AddressObjectCodeInCode
		|  AND Counties.CountyCodeInCode        = Addresses.CountyCodeInCode
		|  AND Counties.CityCodeInCode          = 0 
		|  AND Counties.SettlementCodeInCode    = 0
		|  AND Counties.StreetCodeInCode        = 0
		|	" + ?(HideObsoleteAddresses, "AND Counties.RelevanceFlag = 0","") + "
		|
		|LEFT JOIN
		|  InformationRegister.AddressClassifier AS Cities
		|ON
		|  Cities.AddressItemType = 3
		|  AND Cities.AddressObjectCodeInCode = Addresses.AddressObjectCodeInCode
		|  AND Cities.CountyCodeInCode        = Addresses.CountyCodeInCode
		|  AND Cities.CityCodeInCode          = Addresses.CityCodeInCode
		|  AND Cities.SettlementCodeInCode    = 0
		|  AND Cities.StreetCodeInCode        = 0
		|	" + ?(HideObsoleteAddresses, "AND Cities.RelevanceFlag = 0","") + "
		|
		|LEFT JOIN
		|  InformationRegister.AddressClassifier AS Settlements	
		|ON Settlements.AddressItemType = 4
		|  AND Settlements.AddressObjectCodeInCode = Addresses.AddressObjectCodeInCode
		|  AND Settlements.CountyCodeInCode        = Addresses.CountyCodeInCode
		|  AND Settlements.CityCodeInCode          = Addresses.CityCodeInCode
		|  AND Settlements.SettlementCodeInCode    = Addresses.SettlementCodeInCode
		|  AND Settlements.StreetCodeInCode        = 0
		|	" + ?(HideObsoleteAddresses, "AND Settlements.RelevanceFlag = 0","") + "
		|
		|WHERE
		|	Addresses.AddressItemType <=4
		|	" + ?(HideObsoleteAddresses, "AND Addresses.RelevanceFlag = 0","") + "
		|	AND (" + DescriptionCondition + ")
		|
		|ORDER BY 
		|	Addresses.DataIsCurrentFlag,  // Relevant ones go first
		|
		|	  ISNULL(Addresses.Description, """")   + ISNULL(Addresses.Abbr, """")
		|	+ ISNULL(Settlements.Description, """") + ISNULL(Settlements.Abbr, """")
		|	+ ISNULL(Cities.Description, """")      + ISNULL(Cities.Abbr, """")
		|	+ ISNULL(Counties.Description, """")    + ISNULL(Counties.Abbr, """")
		|	+ ISNULL(States.Description, """")      + ISNULL(States.Abbr, """")
		|";

	Return Query;
EndFunction

// Parses a text string.
Function QueryStreetsByPresentationAddressClassifier(Val AddressParts, Val NumberOfRowsToSelect, Val HideObsoleteAddresses) Export
	
	SearchDescription = AddressParts[0].Description;
	SearchAbbreviation   = AddressParts[0].Abbr;
	If IsBlankString(SearchAbbreviation) Then
		DescriptionCondition = "Streets.Description LIKE &BeginningOfTheLine ESCAPE ""\"" OR Streets.Description LIKE &WordStart ESCAPE ""\"" ";
	Else
		DescriptionCondition = "Streets.Description = &SearchDescription AND Streets.Abbr = &SearchAbbreviation"
	EndIf;
	
	Query = New Query("
		|SELECT ALLOWED TOP " + Format(NumberOfRowsToSelect, "NZ=; NG=") + "
		|	Streets.Code AS Code,
		|
		|	CASE 
		|		WHEN Streets.DataIsCurrentFlag <> 0 THEN TRUE
		|		ELSE FALSE
		|	END AS Obsolete,
		|
		|	Streets.Description AS Description,
		|	Streets.Abbr   AS Abbr
		|FROM
		|	InformationRegister.AddressClassifier AS Settlement
		|LEFT JOIN
		|	InformationRegister.AddressClassifier AS Streets
		|ON
		|	Streets.AddressItemType = 5
		|	AND Streets.AddressObjectCodeInCode  = Settlement.AddressObjectCodeInCode
		|	AND Streets.CountyCodeInCode         = Settlement.CountyCodeInCode
		|	AND Streets.CityCodeInCode           = Settlement.CityCodeInCode 
		|	AND Streets.SettlementCodeInCode     = Settlement.SettlementCodeInCode
		|
		|WHERE
		|	Settlement.Code = &SettlementCode
		|	" + ?(HideObsoleteAddresses, "AND Streets.RelevanceFlag = 0","") + "
		|	AND (" + DescriptionCondition + ")
		|
		|ORDER BY 
		|	Streets.DataIsCurrentFlag,
		|
		|	ISNULL(Streets.Description, """") + ISNULL(Streets.Abbr, """")
		|");
		
	// Partially known parameters
	Query.SetParameter("SearchDescription", SearchDescription);
	Query.SetParameter("SearchAbbreviation",   SearchAbbreviation);
		
	Return Query;
EndFunction

Function QueryAttributeListSettlementAC() Export
	
	Query = New Query("
		|SELECT
		|	Settlements.Code        AS SettlementsCode,
		|	Settlements.Description AS SettlementsDescription,
		|	Settlements.Abbr        AS SettlementsAbbreviation,
		|	Cities.Code             AS CitiesCode,
		|	Cities.Description      AS CitiesDescription,
		|	Cities.Abbr             AS CitiesAbbreviation,
		|	Counties.Code           AS CountiesCode,
		|	Counties.Description    AS CountiesDescription,
		|	Counties.Abbr           AS CountiesAbbreviation,
		|	States.Code             AS StatesCode,
		|	States.Description      AS StatesDescription,
		|	States.Abbr             AS StatesAbbreviation
		|FROM
		|	InformationRegister.AddressClassifier AS Addresses
		|	
		|LEFT JOIN 
		|	InformationRegister.AddressClassifier AS States
		|ON
		|	States.AddressItemType = 1
		|	AND States.AddressObjectCodeInCode  = Addresses.AddressObjectCodeInCode
		|	AND States.CountyCodeInCode         = 0
		|	AND States.CityCodeInCode           = 0
		|	AND States.SettlementCodeInCode     = 0
		|	AND States.StreetCodeInCode         = 0
		|	 
		|LEFT JOIN 
		|	InformationRegister.AddressClassifier AS Counties
		|ON
		|	Counties.AddressItemType = 2
		|	AND Counties.AddressObjectCodeInCode  = Addresses.AddressObjectCodeInCode
		|	AND Counties.CountyCodeInCode         = Addresses.CountyCodeInCode
		|	AND Counties.CityCodeInCode           = 0
		|	AND Counties.SettlementCodeInCode     = 0
		|	AND Counties.StreetCodeInCode         = 0
		|
		|LEFT JOIN 
		|	InformationRegister.AddressClassifier AS Cities
		|ON
		|	Cities.AddressItemType = 3
		|	AND Cities.AddressObjectCodeInCode  = Addresses.AddressObjectCodeInCode
		|	AND Cities.CountyCodeInCode         = Addresses.CountyCodeInCode
		|	AND Cities.CityCodeInCode           = Addresses.CityCodeInCode
		|	AND Cities.SettlementCodeInCode     = 0
		|	AND Cities.StreetCodeInCode         = 0
		|
		|LEFT JOIN 
		|	InformationRegister.AddressClassifier AS Settlements
		|ON
		|	Settlements.AddressItemType = 4
		|	AND Settlements.AddressObjectCodeInCode  = Addresses.AddressObjectCodeInCode
		|	AND Settlements.CountyCodeInCode         = Addresses.CountyCodeInCode
		|	AND Settlements.CityCodeInCode           = Addresses.CityCodeInCode
		|	AND Settlements.SettlementCodeInCode     = Addresses.SettlementCodeInCode
		|	AND Settlements.StreetCodeInCode         = 0
		|
		|WHERE
		|	Addresses.Code = &Code
		|");
		
	Return Query;
EndFunction

Function QueryAttributeListStreetAC() Export
	
	Query = New Query("
		|SELECT
		|	Streets.Code        AS StreetsCode,
		|	Streets.Description AS StreetsDescription,
		|	Streets.Abbr        AS StreetsAbbreviation
		|FROM
		|	InformationRegister.AddressClassifier AS Streets
		|WHERE
		|	Streets.Code = &Code
		|");
		
	Return Query;
EndFunction

Function QueryAddressItemAnalysisListAddressClassifier(Val AddressParts, Val Level, Val Description, Val Abbr, Val SearchBySimilarity, Val NumberOfRowsToSelect) Export
	
	Query = New Query("
		|SELECT ALLOWED DISTINCT TOP " + Format(NumberOfRowsToSelect, "NZ=; NG=") + "
		|
		|	Addresses.Code               AS Code,
		|	Addresses.PostalCode         AS PostalCode,
		|	Addresses.AlternateNames     AS AlternateNames,
		|	Addresses.DataIsCurrentFlag  AS DataIsCurrentFlag,
		|	Addresses.Description        AS AddressesDescription,
		|	Addresses.Abbr               AS AddressesAbbreviation,
		|
		|	CASE 
		|		WHEN Addresses.DataIsCurrentFlag > 0 THEN TRUE 
		|		ELSE FALSE 
		|	END AS Obsolete,
		|
		|	" + ?(Level = 1, "
		|	CASE WHEN StateImported.Code IS NULL THEN TRUE ELSE FALSE END
		|	", "
		|	FALSE
		|	") + " AS CanImportState
		|
		|FROM
		|	InformationRegister.AddressClassifier AS Addresses
		|");
	
	// Adding state import status information
	If Level = 1 Then
		Query.Text = Query.Text + "
			|LEFT JOIN
			|	InformationRegister.AddressClassifier AS StateImported
			|ON
			|	StateImported.AddressObjectCodeInCode = Addresses.AddressObjectCodeInCode
			|	AND StateImported.AddressItemType = 1
			|	AND 1 IN (
			|		               SELECT TOP 1 1 FROM InformationRegister.AddressClassifier WHERE AddressObjectCodeInCode = StateImported.AddressObjectCodeInCode AND AddressItemType = 2
			|		UNION ALL SELECT TOP 1 1 FROM InformationRegister.AddressClassifier WHERE AddressObjectCodeInCode = StateImported.AddressObjectCodeInCode AND AddressItemType = 3
			|		UNION ALL SELECT TOP 1 1 FROM InformationRegister.AddressClassifier WHERE AddressObjectCodeInCode = StateImported.AddressObjectCodeInCode AND AddressItemType = 4
			|		UNION ALL SELECT TOP 1 1 FROM InformationRegister.AddressClassifier WHERE AddressObjectCodeInCode = StateImported.AddressObjectCodeInCode AND AddressItemType = 5
			|		UNION ALL SELECT TOP 1 1 FROM InformationRegister.AddressClassifier WHERE AddressObjectCodeInCode = StateImported.AddressObjectCodeInCode AND AddressItemType = 6
			|   )
			|";
	EndIf;
	If Level > 1 Then
		// County, based on state
		Query.Text = Query.Text + "
			|INNER JOIN
			|  InformationRegister.AddressClassifier AS States
			|BY
			|  States.AddressItemType = 1
			|  AND States.AddressObjectCodeInCode = Addresses.AddressObjectCodeInCode
			|  AND States.CountyCodeInCode        = 0 
			|  AND States.CityCodeInCode          = 0
			|  AND States.SettlementCodeInCode    = 0
			|  AND States.StreetCodeInCode        = 0 
			|  AND States.Description             = &State
			|  AND States.Abbreviation            = &StateAbbreviation
			|";
		Query.SetParameter("State",     AddressParts.State.Description);
		Query.SetParameter("StateAbbr", AddressParts.State.Abbr);
		
		If AddressParts.State.Property("ClassifierCode") And Not IsBlankString(AddressParts.State.ClassifierCode) Then
			Query.SetParameter("StateClassifierCode", AddressParts.State.ClassifierCode);
			Query.Text = Query.Text + "AND States.Code = &StateClassifierCode
				|";
		EndIf;
			
	EndIf;
	If Level > 2 And (Not IsBlankString(AddressParts.County.Description)) Then
		// City, based on county and state (county may be empty)
		Query.Text = Query.Text + "
			|INNER JOIN
			|  InformationRegister.AddressClassifier AS Counties
			|BY
			|  Counties.AddressItemType = 2
			|  AND Counties.AddressObjectCodeInCode = Addresses.AddressObjectCodeInCode
			|  AND Counties.CountyCodeInCode        = Addresses.CountyCodeInCode
			|  AND Counties.CityCodeInCode          = 0 
			|  AND Counties.SettlementCodeInCode    = 0 
			|  AND Counties.StreetCodeInCode        = 0 
			|  AND Counties.Description             = &County
			|  AND Counties.Abbreviation            = &CountyAbbreviation
			|";
		Query.SetParameter("County",            AddressParts.County.Description);
		Query.SetParameter("CountyAbbr",  AddressParts.County.Abbr);
		
		If AddressParts.County.Property("ClassifierCode") And Not IsBlankString(AddressParts.County.ClassifierCode) Then
			Query.SetParameter("CountyClassifierCode", AddressParts.County.ClassifierCode);
			Query.Text = Query.Text + "AND Counties.Code = &CountyClassifierCode
				|";
		EndIf;
		
	EndIf;
	If Level > 3 And (Not IsBlankString(AddressParts.City.Description)) Then
		// Settlement, based on state, county and city (county may be empty, city may be empty)
		Query.Text = Query.Text + "
			|INNER JOIN
			|  InformationRegister.AddressClassifier AS Cities
			|BY
			|  Cities.AddressItemType = 3
			|  AND Cities.AddressObjectCodeInCode = Addresses.AddressObjectCodeInCode
			|  AND Cities.CountyCodeInCode        = Addresses.CountyCodeInCode
			|  AND Cities.CityCodeInCode          = Addresses.CityCodeInCode
			|  AND Cities.SettlementCodeInCode    = 0
			|  AND Cities.StreetCodeInCode        = 0 
			|  AND AND Cities.Description         = &City
			|  AND Cities.Abbreviation            = &CityAbbreviation
			|";
		Query.SetParameter("City",     AddressParts.City.Description);
		Query.SetParameter("CityAbbr", AddressParts.City.Abbr);
		
		If AddressParts.City.Property("ClassifierCode") And Not IsBlankString(AddressParts.City.ClassifierCode) Then
			Query.SetParameter("CityClassifierCode", AddressParts.City.ClassifierCode);
			Query.Text = Query.Text + "AND Cities.Code = &CityClassifierCode
				|";
		EndIf;
		
	EndIf;
	If Level > 4 And (Not IsBlankString(AddressParts.Settlement.Description)) Then
		// Street, based on on state + county + city + settlement item, possibly empty
		Query.Text = Query.Text + "
			|INNER JOIN
			|  InformationRegister.AddressClassifier AS Settlements
			|BY 
			|  Settlements.AddressItemType = 4
			|  AND Settlements.AddressObjectCodeInCode = Addresses.AddressObjectCodeInCode
			|  AND Settlements.CountyCodeInCode        = Addresses.CountyCodeInCode
			|  AND Settlements.CityCodeInCode          = Addresses.CityCodeInCode
			|  AND Settlements.SettlementCodeInCode    = Addresses.SettlementCodeInCode
			|  AND Settlements.StreetCodeInCode        = 0 
			|  AND Settlements.Description             = &Settlement 
			|  AND Settlements.Abbreviation            = &SettlementAbbreviation
			|";
		Query.SetParameter("Settlement",     AddressParts.Settlement.Description);
		Query.SetParameter("SettlementAbbr", AddressParts.Settlement.Abbr);
		
		If AddressParts.Settlement.Property("ClassifierCode") And Not IsBlankString(AddressParts.Settlement.ClassifierCode) Then
			Query.SetParameter("SettlementClassifierCode", AddressParts.Settlement.ClassifierCode);
			Query.Text = Query.Text + "AND Settlements.Code = &SettlementClassifierCode
				|";
		EndIf;
		
	EndIf;
	
	If IsBlankString(Abbr) Then
		AbbreviationCondition = "";
	Else
		If SearchBySimilarity Then
			AbbreviationCondition = "AND Addresses.Abbreviation LIKE &Abbreviation ESCAPE ""\"" ";
			Query.SetParameter("Abbr", EscapeSpecialCharacters(Abbr) + "%");
		Else
			AbbreviationCondition = "AND Addresses.Abbreviation = &Abbreviation";
			Query.SetParameter("Abbr", Abbr);
		EndIf;
	EndIf;
	
	If SearchBySimilarity Then
		DescriptionCondition = "AND Addresses.Description LIKE &Description ESCAPE ""\"" ";
		Query.SetParameter("Description", EscapeSpecialCharacters(Description) + "%");
	Else
		DescriptionCondition = "AND Addresses.Description = &Description";
		Query.SetParameter("Description", Description);
	EndIf;
	
	Query.Text = Query.Text + "
		|WHERE
		|	Addresses.AddressItemType = &Level
		|	" + DescriptionCondition + "
		|	" + AbbreviationCondition + "
		|ORDER
		|
		|	BY Addresses.DataIsCurrentFlag, Addresses.Description
		|";
		
	Return Query;
EndFunction

Function QueryAddressByPostalCodeAddressClassifier(Val NumberOfRowsToSelect, Val HideObsolete) Export
	FragmentFirst = ?(NumberOfRowsToSelect > 0, "TOP " + Format(NumberOfRowsToSelect, "NZ=; NG="), "");
	
	Query = New Query("
		|SELECT ALLOWED DISTINCT " + FragmentFirst + "
		|	
		|	CASE 
		|		WHEN PostalCodes.DataIsCurrentFlag <> 0 THEN TRUE
		|		ELSE FALSE
		|	END AS Obsolete,
		|	
		|	PostalCodes.PostalCode AS PostalCode,
		|	
		|	// Synthetic code of object (in SS CCC CCC SSS SSSS BBBB format) linked to PostalCode
		|	1000000 * CAST( PostalCodes.Code /1000000 - 0.5 AS NUMBER(21,0)) AS Code,
		|	
		|	// Other columns are auxuliary, they will be removed from the results
		|	
		|	Streets.Description AS StreetName,
		|	Streets.Abbr        AS StreetAbbr,
		|	Streets.Description + "" "" + Streets.Abbr AS PresentationStreet,
		|	
		|	Settlements.Description AS SettlementName,
		|	Settlements.Abbr        AS SettlementAbbr,
		|	Settlements.Description + "" "" + Settlements.Abbr AS PresentationSettlement,
		|	
		|	Cities.Description AS CityName,
		|	Cities.Abbr        AS CityAbbr,
		|	Cities.Description + "" "" + Cities.Abbr AS PresentationCity,
		|	
		|	Counties.Description AS CountyName,
		|	Counties.Abbr        AS CountyAbbr,
		|	Counties.Description + "" "" + Counties.Abbr AS PresentationCounty,
		|	
		|	States.Description AS StateName,
		|	States.Abbr        AS StateAbbr,
		|	States.Description + "" "" + States.Abbr AS PresentationState
		|	
		|INTO 
		|	AddressesByPostalCodes
		|	
		|FROM	
		|	InformationRegister.AddressClassifier AS PostalCodes
		|	
		|LEFT JOIN
		|	InformationRegister.AddressClassifier AS Streets
		|ON	
		|	Streets.AddressItemType = 5
		|	" + ?(HideObsolete, "AND Streets.RelevanceFlag = 0","") + "
		|	AND Streets.AddressObjectCodeInCode = PostalCodes.AddressObjectCodeInCode 
		|	AND Streets.CountyCodeInCode        = PostalCodes.CountyCodeInCode 
		|	AND Streets.CityCodeInCode          = PostalCodes.CityCodeInCode 
		|	AND Streets.SettlementCodeInCode    = PostalCodes.SettlementCodeInCode
		|	AND Streets.StreetCodeInCode        = PostalCodes.StreetCodeInCode
		|LEFT JOIN
		|	InformationRegister.AddressClassifier AS Settlements
		|ON	
		|	Settlements.AddressItemType = 4
		|	" + ?(HideObsolete, "AND Settlements.RelevanceFlag = 0","") + "
		|	AND Settlements.AddressObjectCodeInCode = PostalCodes.AddressObjectCodeInCode 
		|	AND Settlements.CountyCodeInCode        = PostalCodes.CountyCodeInCode 
		|	AND Settlements.CityCodeInCode          = PostalCodes.CityCodeInCode 
		|	AND Settlements.SettlementCodeInCode    = PostalCodes.SettlementCodeInCode
		|	AND Settlements.StreetCodeInCode        = 0 
		|LEFT JOIN 
		|  InformationRegister.AddressClassifier AS Cities 
		|ON 
		|  Cities.AddressItemType = 3
		|	" + ?(HideObsolete, "AND Cities.RelevanceFlag = 0","") + "
		|	AND Cities.AddressObjectCodeInCode = PostalCodes.AddressObjectCodeInCode 
		|	AND Cities.CountyCodeInCode        = PostalCodes.CountyCodeInCode 
		|	AND Cities.CityCodeInCode          = PostalCodes.CityCodeInCode 
		|	AND Cities.SettlementCodeInCode    = 0
		|	AND Cities.StreetCodeInCode        = 0 
		|LEFT JOIN 
		|  InformationRegister.AddressClassifier AS Counties 
		|ON
		|  Counties.AddressItemType = 2
		|	" + ?(HideObsolete, "AND Counties.RelevanceFlag = 0","") + "
		|	AND Counties.AddressObjectCodeInCode = PostalCodes.AddressObjectCodeInCode 
		|	AND Counties.CountyCodeInCode        = PostalCodes.CountyCodeInCode 
		|	AND Counties.CityCodeInCode          = 0 
		|	AND Counties.SettlementCodeInCode    = 0 
		|	AND Counties.StreetCodeInCode        = 0 
		|LEFT JOIN 
		|  InformationRegister.AddressClassifier AS States 
		|ON	
		|	States.AddressItemType = 1
		|	" + ?(HideObsolete, "AND States.RelevanceFlag = 0","") + "
		|	AND States.AddressObjectCodeInCode = PostalCodes.AddressObjectCodeInCode 
		|	AND States.CountyCodeInCode        = 0 
		|	AND States.CityCodeInCode          = 0 
		|	AND States.SettlementCodeInCode    = 0 
		|	AND States.StreetCodeInCode        = 0 
		|WHERE 
		|  PostalCodes.PostalCode = &PostalCode
		|	" + ?(HideObsolete, "AND PostalCodes.RelevanceFlag = 0","") + "
		|
		|" + ?(IsBlankString(FragmentFirst), "", "
		|ORDER BY
		|	PostalCode,
		|	StreetDescription,
		|	StreetAbbreviation, SettlementDescription,
		|	SettlementAbbreviation, CityDescription,
		|	CityAbbreviation, CountyDescription,
		|	CountyAbbreviation, StateDescription, StateAbbreviation
		|") + "
		|
		|;///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		|
		|// Primary result
		|SELECT 
		|	Obsolete, PostalCode, Code,
		|	StreetName, StreetAbbr, PresentationStreet,
		|	SettlementName, SettlementAbbr, PresentationSettlement,
		|	CityName, CityAbbr, PresentationCity,
		|	CountyName, CountyAbbr, PresentationCounty,
		|	StateName, StateAbbr, PresentationState
		|FROM 
		|	AddressesByPostalCodes
		|ORDER BY
		|PostalCode, 
		|	StreetName, StreetAbbr,
		|	SettlementName, SettlementAbbr,
		|	CityName, CityAbbr,
		|	CountyName, CountyAbbr,
		|	StateName, StateAbbr
		|;///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		|
		|// Secondary result
		|SELECT
		|	CASE WHEN CountStreet = 1 THEN MinimumDescriptionStreet ELSE """" END AS StreetName,
		|	CASE WHEN CountStreet = 1 THEN MinimumAbbreviationStreet   ELSE """" END AS StreetAbbr,
		|
		|	CASE WHEN CountSettlement = 1 THEN MinimumDescriptionSettlement ELSE """" END AS SettlementName,
		|	CASE WHEN CountSettlement = 1 THEN MinimumAbbreviationSettlement   ELSE """" END AS SettlementAbbr,
		|
		|	CASE WHEN CountCity = 1 THEN MinimumDescriptionCity ELSE """" END AS CityName,
		|	CASE WHEN CountCity = 1 THEN MinimumAbbreviationCity   ELSE """" END AS CityAbbr,
		|
		|	CASE WHEN CountCounty = 1 THEN MinimumDescriptionCounty ELSE """" END AS CountyName,
		|	CASE WHEN CountCounty = 1 THEN MinimumAbbreviationCounty   ELSE """" END AS CountyAbbr,
		|
		|	CASE WHEN CountState = 1 THEN MinimumDescriptionState ELSE """" END AS StateName,
		|	CASE WHEN CountState = 1 THEN MinimumAbbreviationState   ELSE """" END AS StateAbbr
		|
		|FROM (
		|	SELECT 
		|		COUNT(DISTINCT ISNULL(PresentationStreet, """")) AS CountStreet,
		|		MIN(StreetName)                                  AS MinimumDescriptionStreet,
		|		MIN(StreetAbbr)                                  AS MinimumAbbreviationStreet,
		|
		|		COUNT(DISTINCT ISNULL(PresentationSettlement, """")) AS CountSettlement,
		|		MIN(SettlementName)                                  AS MinimumDescriptionSettlement,
		|		MIN(SettlementAbbr)                                  AS MinimumAbbreviationSettlement,
		|
		|		COUNT(DISTINCT ISNULL(PresentationCity, """")) AS CountCity,
		|		MIN(CityName)                                  AS MinimumDescriptionCity,
		|		MIN(CityAbbr)                                  AS MinimumAbbreviationCity,
		|
		|		COUNT(DISTINCT ISNULL(PresentationCounty, """")) AS CountCounty,
		|		MIN(CountyName)                                  AS MinimumDescriptionCounty,
		|		MIN(CountyAbbr)                                  AS MinimumAbbreviationCounty,
		|
		|		COUNT(DISTINCT ISNULL(PresentationState, """")) AS CountState,
		|		MIN(StateName)                                  AS MinimumDescriptionState,
		|		MIN(StateAbbr)                                  AS MinimumAbbreviationState
		|	FROM
		|		AddressesByPostalCodes
		|) Subquery
		|");
	
	Return Query;
EndFunction

Function QueryStateCodeAddressClassifier() Export
	
	Query = New Query("
		|SELECT TOP 1
		|	AddressObjectCodeInCode AS Code
		|FROM
		|	InformationRegister.AddressClassifier
		|WHERE
		|	AddressItemType          = 1
		|	AND CountyCodeInCode     = 0
		|	AND CityCodeInCode       = 0
		|	AND SettlementCodeInCode = 0
		|	AND StreetCodeInCode     = 0
		|
		|	AND Description = &Description
		|	AND Abbr        = &Abbr
		|");

	Return Query;
EndFunction

Function QueryCodeStateAddressClassifier() Export
	
	Query = New Query("
		|SELECT TOP 1
		|	Description + "" "" + Abbr AS State
		|FROM
		|	InformationRegister.AddressClassifier
		|WHERE
		|	AddressItemType              = 1
		|	AND AddressObjectCodeInCode  = &Code
		|	AND CountyCodeInCode         = 0
		|	AND CityCodeInCode           = 0
		|	AND SettlementCodeInCode     = 0
		|	AND StreetCodeInCode         = 0
		|");
		
	Return Query;
EndFunction

Function QueryAllStatesAddressClassifier() Export
	Query = New Query("
		|SELECT 
		|	AddressObjectCodeInCode     AS Code,
		|	Description                 AS Description,
		|	Abbr                        AS Abbr,
		|	Description + "" "" + Abbr  AS Presentation
		|FROM
		|	InformationRegister.AddressClassifier
		|WHERE
		|	AddressItemType = 1
		|	AND CountyCodeInCode     = 0
		|	AND CityCodeInCode       = 0
		|	AND SettlementCodeInCode = 0
		|	AND StreetCodeInCode     = 0
		|");
	
	Return Query;
EndFunction

#EndRegion