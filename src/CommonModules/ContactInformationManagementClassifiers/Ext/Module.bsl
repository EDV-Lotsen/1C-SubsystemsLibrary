////////////////////////////////////////////////////////////////////////////////
// Contact information subsystem.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// Shows whether classifiers are used in the configuration.
//
// Returns:
// Boolean - True if classifiers are used, otherwise is False.
//
Function ClassifiersUsed() Export
	
	Return False;	
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Export functions that are called from the Address input form.

// Finds address classifier records by postal code.
//
// Parameters:
// PostalCode - String - postal code to be used in the search. 
//
// Returns:
// Structure with the following fields:
// Count - Number - number of found variants;
// FoundState - String - is filled if one state is found;
// FoundCounty - String - is filled if one county is found;
// ActualityFlag - Number - actuality flag, is filled if one variant is found;
// AddressInStorage - String - ID of the saved in storage table with found variants.
//
Function FindACRecordsByPostalCode(PostalCode) Export
	
		Return New Structure("Count,FoundState,FoundCounty,ActualityFlag", 0, "", "", 0);
	
EndFunction

// Retrieves components of the address item by item code.
//
// Parameters:
// AddressItemCode - Number - code of an address item whose components will be retrieved. 
// Result - structure with the following fields:
// State - String - description of a found state;
// County - String - description of a found county;
// City - String - description of a found city;
// Settlement - String - description of a found settlement;
// Street - String - description of a found street;
// ActualityFlag - Number - actuality flag of a found address.
//
Procedure GetComponentsToStructureByAddressItemCode(AddressItemCode, Result) Export
		
EndProcedure

// Clears child items of the specified address item.
//
// Parameters:
// State - string - string where a string presentation of the parent state will be passed.
// County - string - string where a string presentation of the parent county will be passed.
// City - string - string where a string presentation of the parent city will be passed.
// Settlement - string - string where a string presentation of the parent settlement will be passed.
// Street - string - string where a string presentation of the parent street will be passed.
// Building - string - string where a string presentation of the parent building will be passed.
// Appartment - string - string where a string presentation of the parent apartment will be passed.
// Level - Number - address item level.
//
Procedure ClearChildsByAddressItemLevel(State, County, City, Settlement, Street, 
	Building, Appartment, Level) Export
	
	If Level = 1 Then
		// Clearing the item and all child items
		County = "";	
		City = "";
		Settlement = "";
		Street = "";
		Building = "";
		Appartment = "";
		Return;
	EndIf;

	If Level = 2 Then
		// Clearing the item and all child items
		City = "";
		Settlement = "";
		Street = "";
		Building = "";
		Appartment = "";
		Return;	
	EndIf;
	
	If Level = 3 Then
		// Clearing the item and all child items
		Settlement = "";
		Street = "";
		Building = "";
		Appartment = "";
		Return;	
	EndIf;
	
	If Level = 4 Then
		// Clearing the item and all child items
		Street = "";
		Building = "";
		Appartment = "";
	EndIf;
	
EndProcedure

// Defines a postal code by passed state, county, city, settlement, 
// street, and building.
//
// Parameters: 
// StateName - state name (with an abbreviation);
// CountyName - county name (with an abbreviation);
// CityName - city name (with an abbreviation);
// SettlementName - settlement name (with an abbreviation);
// Street - street name (with an abbreviation);
// BuildingNumber - building number whose postal code will be retrieved;
// PostalCodeParent - variable where found address item structure will be passed back.
//
// Returns:
// String - postal code.
//
Function GetPostalCode(Val StateName, Val CountyName, Val CityName, Val SettlementName, 
	Val StreetName, Val BuildingNumber, PostalCodeParent = Undefined) Export

	Return "";

EndFunction

// Auto complete handler for the address input item.
//
// Parameters: 
// Text - String - text that the user typed in the address input item; 
// State - String - previously entered state name;
// County - String - previously entered county name;
// City - String - previously entered city name;
// Settlement - String - previously entered settlement name;
// ItemLevel - Number - address input item ID:
// 1 - state, 2 - county, 3 - city, 4 - settlement , 5 - street, 0 - other;
// ActualityFlag - Number - item actuality flag.
//
// Returns:
// ValueList or Undefined.
//
Function AddressItemTextAutoComplete(Text, State, County, City, Settlement, ItemLevel,
	ActualityFlag = 0) Export
		
	Return New ValueList;
	
EndFunction

// Checks whether the address matches the address classifier by specified postal code, 
// state, county, city, settlement, street, and building. Returns a structure with found
// address items.
//
// Parameters: 
// SelectedPostalCode - String - postal code;
// StateName - state name (with an abbreviation);
// CountyName - county name (with an abbreviation);
// CityName - city name (with an abbreviation);
// SettlementName - settlement name (with an abbreviation);
// StreetName - street name (with an abbreviation);
// BuildingNumber - building number whose postal code will be retrieved.
//
// Returns:
// Structure with the following fields:
// State - Structure - field structure of the found state; 
// County - Structure - field structure of the found county;
// City - Structure - field structure of the found city;
// Settlement - Structure - field structure of the found settlement;
// Street - Structure - field structure of the found street;
// Building - Structure - field structure of the found building;
// HasErrors - Boolean - flag that shows whether one or more errors occurred during the check. 
// ErrorsStructure - Structure - structure where item names are keys
// 		and detailed error texts are values.
//
Function CheckAddressByAC(Val SelectedPostalCode = "", Val StateName = "", Val CountyName = "", 
	Val CityName = "", Val SettlementName = "", Val StreetName = "", Val BuildingNumber = "") Export

	Return False;
	
EndFunction

// Checks whether the address item has been imported to the infobase.
//
// Parameters: 
// StateName - String - state name (with an abbreviation);
// CountyName - String - county name (with an abbreviation);
// CityName - String - city name (with an abbreviation);
// SettlementName - String - settlement name (with an abbreviation);
// StreetName - String - street name (with an abbreviation);
// Level - Number - level to be checked.
//
// Returns:
// Boolean - True if the address item has been imported, otherwise is False.
//
Function AddressItemImported(Val StateName, Val CountyName = "", Val CityName = "", 
	Val SettlementName = "", Val StreetName = "", Level = 1) Export
	
	Return False;
	
EndFunction

// Retrieves the name and the abbreviation of the address item by item long description.
//
// Parameters:
// ItemString - String - item string;
// AddressAbbreviation - String - address abbreviation will be returned to this parameter.
//
// Returns:
// String - address item name.
//
Function GetNameAndAddressAbbreviation(Val ItemString, AddressAbbreviation) Export

	Return ItemString;

EndFunction

// Shows whether the specified address items was imported. 
//
// Parameters: 
// StateName - String - state name (with an abbreviation);
// CountyName - String - county name (with an abbreviation);
// CityName - String - city name (with an abbreviation);
// SettlementName - String - settlement name (with an abbreviation);
// StreetName - String - street name (with an abbreviation).
//
// Returns:
// Structure with the following fields:
// State - Boolean - flag that shows whether the state was imported;
// County - Boolean - flag that shows whether the county was imported;
// City - Boolean - flag that shows whether the city was imported;
// Settlement - Village flag that shows whether the settlement was imported;
// Street - Boolean - flag that shows whether the street was imported.
//
Function ImportedAddressItemStructure(Val StateName, Val CountyName, Val CityName,
	Val SettlementName, Val StreetName) Export

	Return New Structure("State,County,City,Settlement,Street,Building", False, False, False, False, False, False);
		
EndFunction

// Retrieves a structure of address by the address item code. 
//
// Parameters: 
// AddressItemCode - Number - address item code;
// Building - String - building number, if necessary;
// Appartment - String - apartment number, if necessary.
//
// Returns:
// Structure with the following fields:
// PostalCode - String - postal code;
// State - String - state;
// County - String - county;
// City - String - city;
// Settlement - String - settlement;
// Street - String - street;
// Building - String - building;
// Appartment - String - apartment.
//
Function GetAddressStructureAtServer(AddressItemCode, Building = "", Appartment = "") Export
	
	AddressStructure = New Structure();
	GetComponentsToStructureByAddressItemCode(AddressItemCode, AddressStructure);
	
	// Retrieving a postal code by the item code
	Query = New Query;
	Query.Text =
	"SELECT
	|	AddressClassifier.PostalCode
	|FROM
	|	InformationRegister.AddressClassifier AS AddressClassifier
	|WHERE
	|	AddressClassifier.Code = &Code";
	Query.SetParameter("Code", AddressItemCode);
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		PostalCode = GetPostalCode(AddressStructure.State, AddressStructure.County,
		  AddressStructure.City, AddressStructure.Settlement, AddressStructure.Street, Building);
	Else
		Selection = QueryResult.Choose();
		Selection.Next();
		PostalCode = Selection.PostalCode;
	EndIf;	
	AddressStructure.Insert("PostalCode", PostalCode);
	
	AddressStructure.Insert("Building", Building);
	AddressStructure.Insert("Appartment", Appartment);
	Return AddressStructure;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

////////////////////////////////////////////////////////////////////////////////
// Export functions that are called form the address classifier choice form.

// Returns a restriction structure by passed parameters
// that contain address field values.
//
// Parameters: 
// StateName - String - state name (with an abbreviation);
// CountyName - String - county name (with an abbreviation);
// CityName - String - city name (with an abbreviation);
// SettlementName - String - settlement name (with an abbreviation);
// StreetName - String - street name (with an abbreviation);
// ParentCode - Number - code of the parent item;
// Level - Number - current item level.
//
// Returns:
// Structure with the following fields:
// AddressObjectCodeInCode - String - state code for the restriction;
// CountyCodeInCode - String - county code for the restriction;	
// 	CityCodeInCode - String - city code for the restriction;	
// 	SettlementCodeInCode - String - settlement code for the restriction;	
// 	StreetCodeInCode - String - street code for the restriction;
// AddressItemType - Number - current item level.
//
Function ReturnRestrictionStructureByParent(Val StateName, Val CountyName, Val CityName, 
											Val SettlementName, Val StreetName, ParentCode, Level) Export
	
	RestrictionStructure = New Structure();
	ParentItem = GetAddressClassifierRowByAddressItems(StateName, CountyName,
	  CityName, SettlementName, StreetName);
	
	ParentCode = ParentItem.Code;
	
	// Determining the item level
	AddCodeToStructure(RestrictionStructure, "AddressObjectCodeInCode",
	  ParentItem.AddressObjectCodeInCode, ParentItem.AddressItemType, 1);
	AddCodeToStructure(RestrictionStructure, "CountyCodeInCode",
	  ParentItem.CountyCodeInCode, ParentItem.AddressItemType, 2);
	AddCodeToStructure(RestrictionStructure, "CityCodeInCode",
	  ParentItem.CityCodeInCode, ParentItem.AddressItemType, 3);
	AddCodeToStructure(RestrictionStructure, "SettlementCodeInCode",
	  ParentItem.SettlementCodeInCode, ParentItem.AddressItemType, 4);
	
	If Level < 5 Then 
		AddCodeToStructure(RestrictionStructure, "StreetCodeInCode", 0, ParentItem.AddressItemType, 5);
	Else
		AddCodeToStructure(RestrictionStructure, "StreetCodeInCode",
		  ParentItem.StreetCodeInCode, ParentItem.AddressItemType, 5);
	EndIf;
	
	RestrictionStructure.Insert("AddressItemType", Level);
	
	Return RestrictionStructure;
	
EndFunction

// Returns an address classifier row (structure) by address item values.
//
// Parameters: 
// StateName - String - state name (with an abbreviation);
// CountyName - String - county name (with an abbreviation);
// CityName - String - city name (with an abbreviation);
// SettlementName - String - settlement name (with an abbreviation);
// StreetName - String - street name (with an abbreviation);
//
// Returns:
// Field structure of the found address item.
//
Function GetAddressClassifierRowByAddressItems(Val StateName, Val CountyName,
	Val CityName, Val SettlementName, Val StreetName) Export
											
	ParentItem = GetEmptyAddressStructure();

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
		Return GetEmptyAddressStructure()
	Else
		Return ParentItem;
	EndIf;
										
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures for working with strings.

// Creates a query object, sets the AutoCompleteText query parameter and
// deletes prohibited symbols from the search string.
//
// Parameters:
// SearchString - String - query search string;
// FilterStringByStructure - String - query filter will be assembled in this parameter;
// ParametersStructure - Structure - query parameter structure;
// RestrictionsTableName - String - restriction table name.
//
// Returns:
// Query object.
//
Function CreateQueryForAutoCompleteList(SearchString, FilterStringByStructure, ParametersStructure, RestrictionsTableName)
	
	Query = New Query;
	SearchString = CommonUse.GenerateSearchQueryString(SearchString);
	Query.SetParameter("AutoCompleteText" , (SearchString + "%"));
	
	// Setting restrictions
	FilterStringByStructure = "";
	For Each StructureItem In ParametersStructure Do
		Key 	 = StructureItem.Key;
		Value = StructureItem.Value;

		Query.SetParameter(Key, Value);
		FilterStringByStructure = FilterStringByStructure + "
		|		And
		|		" + RestrictionsTableName + "." + Key + " In (&"+ Key + ")";
	EndDo; 
	
	Return Query;
	
EndFunction

// Generates an address detail string by passed address items.
//
// Parameters:
// DetailsTillLevel - Number - required level of details;
// State - String - state;
// County - String - county;
// City - String - city;
// Settlement - String - settlement;
// Street - String - street.
//
// Returns:
// String - details.
//
Function GetDetailsByAddressItems(DetailsTillLevel, State = "", County = "", City = "", 
	Settlement = "", Street = "")
	
	Details = Street;
	
	If DetailsTillLevel <= 4 Then // Street, Settlement
			
		If IsBlankString(Details) And IsBlankString(Settlement) Then
			Details = "";
		ElsIf IsBlankString(Details) Then
			Details = Settlement;
		ElsIf IsBlankString(Settlement) Then
			Details = Details;
		Else
			Details = Details + ", " + Settlement;
		EndIf;
		
	EndIf;
	
	If DetailsTillLevel <= 3 Then // Street, Settlement, City
			
		If IsBlankString(Details) And IsBlankString(City) Then
			Details = "";
		ElsIf IsBlankString(Details) Then
			Details = City;
		ElsIf IsBlankString(City) Then
			Details = Details;
		Else
			Details = Details + ", " + City;
		EndIf;
		
	EndIf;
	
	If DetailsTillLevel <= 2 Then // Street, Settlement, City, County
		
		If IsBlankString(Details) And IsBlankString(County) Then
			Details = "";
		ElsIf IsBlankString(Details) Then
			Details = County;
		ElsIf IsBlankString(County) Then
			Details = Details;
		Else
			Details = Details + ", " + County;
		EndIf;
		
	EndIf;
	
	If DetailsTillLevel = 1 Then // Street, Settlement, City, County, State
		
		If IsBlankString(Details) And IsBlankString(State) Then
			Details = "";
		ElsIf IsBlankString(Details) Then
			Details = State;
		ElsIf IsBlankString(State) Then
			Details = Details;
		Else
			Details = Details + ", " + State;
		EndIf;
		
	EndIf;
	
	Return Details;
	
EndFunction


////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for working with address codes.

// Splits data to States, Counties, Cities, Settlements and Streets temporary tables
// that matches addresses received from the Addresses temporary table. You must place
// data to the Addresses temporary table before you call this procedure:
//  TempTablesManager = New TempTablesManager;
//  Query = New Query;
//  Query.TempTablesManager = TempTablesManager;
//  Query.Text = 	
//  "SELECT
//  |	AddressClassifier.AddressItemType,
//  |	AddressClassifier.Code,
//  |	AddressClassifier.Description + "" "" + AddressClassifier.Abbreviation AS Description,
//  |	AddressClassifier.ActualityFlag,
//  |	AddressClassifier.AddressObjectCodeInCode AS State,
//  |	AddressClassifier.CountyCodeInCode AS County,
//  |	AddressClassifier.CityCodeInCode AS City,
//  |	AddressClassifier.SettlementCodeInCode AS Settlement,
//  |	AddressClassifier.StreetCodeInCode AS Street
//  |INTO Addresses
//  |FROM
//  |	InformationRegister.AddressClassifier AS AddressClassifier
//  |WHERE
//  |	AddressClassifier.PostalCode = &PostalCode
//  |	And AddressClassifier.AddressItemType < 6";
//  Query.Execute();
//  SplitAddressItemsToTempTables(TempTablesManager);
//
// Parameters:
// TempTablesManager - temporary table manager that must already contain the Addresses
// temporary table.
//
Procedure SplitAddressItemsToTempTables(TempTablesManager)
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.Text = 	
	"SELECT
	|	Addresses.Code AS Code,
	|	AddressClassifier.Code AS StateCode,
	|	AddressClassifier.Description + "" "" + AddressClassifier.Abbreviation AS Description,
	|	AddressClassifier.ActualityFlag,
	|	Addresses.AddressObjectCodeInCode
	|INTO States
	|FROM
	|	Addresses AS Addresses
	|		LEFT JOIN InformationRegister.AddressClassifier AS AddressClassifier
	|		ON Addresses.AddressObjectCodeInCode = AddressClassifier.AddressObjectCodeInCode
	|WHERE
	|	AddressClassifier.AddressItemType = 1
	|";
	Query.Execute();
	
	Query.Text = " 	
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Addresses.Code,
	|	AddressClassifier.Code AS CountyCode,
	|	AddressClassifier.Description + "" "" + AddressClassifier.Abbreviation AS Description,
	|	AddressClassifier.ActualityFlag,
	|	Addresses.CountyCodeInCode,
	|	Addresses.AddressObjectCodeInCode
	|INTO Counties
	|FROM
	|	Addresses AS Addresses
	|		LEFT JOIN InformationRegister.AddressClassifier AS AddressClassifier
	|		ON Addresses.AddressObjectCodeInCode = AddressClassifier.AddressObjectCodeInCode
	|			AND Addresses.CountyCodeInCode = AddressClassifier.CountyCodeInCode
	|WHERE
	|	AddressClassifier.AddressItemType = 2
	|";
	Query.Execute();

	Query.Text = " 	
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Addresses.Code,
	|	AddressClassifier.Code AS CityCode,
	|	AddressClassifier.Description + "" "" + AddressClassifier.Abbreviation AS Description,
	|	AddressClassifier.ActualityFlag,
	|	Addresses.CityCodeInCode,
	|	Addresses.CountyCodeInCode,
	|	Addresses.AddressObjectCodeInCode
	|INTO Cities
	|FROM
	|	Addresses AS Addresses
	|		LEFT JOIN InformationRegister.AddressClassifier AS AddressClassifier
	|		ON Addresses.AddressObjectCodeInCode = AddressClassifier.AddressObjectCodeInCode
	|			AND Addresses.CountyCodeInCode = AddressClassifier.CountyCodeInCode
	|			ND Addresses.CityCodeInCode = AddressClassifier.CityCodeInCode
	|WHERE
	|	AddressClassifier.AddressItemType = 3
	|";
	Query.Execute();

	Query.Text = " 	
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Addresses.Code,
	|	AddressClassifier.Code AS SettlementCode,
	|	AddressClassifier.Description + "" "" + AddressClassifier.Abbreviation AS Description,
	|	AddressClassifier.ActualityFlag,
	|	Addresses.SettlementCodeInCode,
	|	Addresses.CityCodeInCode,
	|	Addresses.CountyCodeInCode,
	|	Addresses.AddressObjectCodeInCode
	|INTO Settlements
	|FROM
	|	Addresses AS Addresses
	|		LEFT JOIN InformationRegister.AddressClassifier AS AddressClassifier
	|		ON Addresses.AddressObjectCodeInCode = AddressClassifier.AddressObjectCodeInCode
	|			AND Addresses.CountyCodeInCode = AddressClassifier.CountyCodeInCode
	|			AND Addresses.CityCodeInCode = AddressClassifier.CityCodeInCode
	|			AND Addresses.SettlementCodeInCode = AddressClassifier.SettlementCodeInCode
	|WHERE
	|	AddressClassifier.AddressItemType = 4
	|";
	Query.Execute();

	Query.Text = " 	
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Addresses.Code,
	|	AddressClassifier.Code AS StreetCode,
	|	AddressClassifier.Description + "" "" + AddressClassifier.Abbreviation AS Description,
	|	AddressClassifier.ActualityFlag,
	|	Addresses.StreetCodeInCode,
	|	Addresses.SettlementCodeInCode,
	|	Addresses.CityCodeInCode,
	|	Addresses.CountyCodeInCode,
	|	Addresses.AddressObjectCodeInCode
	|INTO Streets
	|FROM
	|	Addresses AS Addresses
	|		LEFT JOIN InformationRegister.AddressClassifier AS AddressClassifier
	|		ON Addresses.AddressObjectCodeInCode = AddressClassifier.AddressObjectCodeInCode
	|			AND Addresses.CountyCodeInCode = AddressClassifier.CountyCodeInCode
	|			AND Addresses.CityCodeInCode = AddressClassifier.CityCodeInCode
	|			AND Addresses.SettlementCodeInCode = AddressClassifier.SettlementCodeInCode
	|			AND Addresses.StreetCodeInCode = AddressClassifier.StreetCodeInCode
	|WHERE
	|	AddressClassifier.AddressItemType = 5
	|";
	Query.Execute();	
	
EndProcedure

// Creates a structure with fields that match AddressClassifier information 
// register record fields. 
//
// Returns:
// Structure - structure with empty values.
//
Function GetEmptyAddressStructure()
	
	Return New Structure("Code,Name,Abbreviation,AddressItemType,PostalCode,
	|AddressObjectCodeInCode,CountyCodеInCode,CityCodeInCode,SettlementCodeInCode,StreetCodeInCode,
	|ActualityFlag", 0, "", "", 0, "", 0, 0, 0, 0, 0, 0);
	
EndFunction


// Determines whether the interval includes the building number.
// See the NumberInInterval function to learn how to specify the interval.
//
// Parameters: 
// Number - Number or String - building number;
// Interval - String - building number interval.
//
// Returns:
// True if the interval includes the building number, otherwise is False.
//
Function IsInInterval(Val Number, Interval)

	If IsBlankString("" + Number) Then
		Return False;
	EndIf;

	If Not StringFunctionsClientServer.OnlyDigitsInString(Number, False) Then
		// Checking whether the interval includes the specified building number
		NumberInInterval = (Upper(StrReplace("" + Number, " ", "")) = Upper(StrReplace("" + Interval, " ", "")));
		If NumberInInterval Then
			Return True;
		// If the building number is Number and it is not found in the interval, the interval
		// does not include the building number.
		ElsIf TypeOf(Number) = Type("Number") Then
			Return False;
		// If the building number is String and it is not found in the interval, attempting 
		// to delete every character except digits and checking whether
		// the interval includes the digital part of the number. 
		Else
			Number = KeepOnlyDigitsInString(Number);
		EndIf;
	EndIf;

	Number = Number(Number);

	NumbersOnlyInterval = StringFunctionsClientServer.OnlyDigitsInString(Interval, False);
	
	If NumbersOnlyInterval Then
		If Number = Number(Interval) Then
			Return True;
		EndIf;
	EndIf;

	If Find(Interval,"E") > 0 Then // interval of even numbers
		Interval = StrReplace(Interval, "E", "");
		Parity = 2;
		
	ElsIf Find(Interval,"O") > 0 Then // interval of odd numbers
		Interval = StrReplace(Interval, "O", "");
		Parity = 1;
		
	ElsIf (Find(Interval, "-") = 0) And NumbersOnlyInterval Then 
		// The interval includes only one building
		Return False;
		
	Else
		Parity = 0;
		
	EndIf;
	
	Interval = StrReplace(Interval, ")", ""); 
	Interval = StrReplace(Interval, "(", "");
	Position = Find(Interval, "-");
	Matched = 0;
	
	If Position <> 0 Then
		LeftPart = Left(Interval, Position - 1);
		RightPart = Mid(Interval, Position + 1);
		MinValue = Number(KeepOnlyDigitsInString(LeftPart));
		MaxValue = Number(KeepOnlyDigitsInString(RightPart));
		If (Number >= MinValue) And (Number <= MaxValue) Then
			Matched = 1;
		EndIf;
		
	ElsIf IsBlankString(Interval) Then
		// If the interval was equal E or O
		Matched = 1;
		
	Else
		If StringFunctionsClientServer.OnlyDigitsInString(Interval, False) Then
			If Number = Number(KeepOnlyDigitsInString(Interval)) Then
				Matched = 1;
			EndIf;
		EndIf;

	EndIf;
	
	If (Matched = 1) And (
	((Parity = 2) And (Number % 2 = 0)) Or 
	((Parity = 1) And (Number % 2 = 1)) Or 
	 (Parity = 0)) Then
		Return True;
		
	EndIf;
	
	Return False;
	
EndFunction

// Determines whether the interval includes:
// 1. the building number passed as String.
// Example: 58A, 32/1, 50A8
// 2. the building number passed as Number.
//
// The interval must be set as: 
// <Interval>[,<Interval>]
// where Interval is String in the following format:
// [Prefix]<Number>[-<Number>]
// Prefix (E or O) is a flag that shows whether the interval includes only even numbers (E)
// or only odd numbers (O).
// Example: The interval E12-14,O1-5,20-29 includes the following numbers:
// 1,3,5,12,14,20,21,22,23,24,25,26,27,28,29.
//
// Parameters: 
// Number - Number or String - building number;
// Interval - String - building number interval.
//
// True if the interval includes the building number, otherwise is False.
//
Function BuildingNumberInInterval(Number, Val Interval)
	
	While Not IsBlankString(Interval) Do

		Position = Find(Interval, ",");
		If Position = 0 Then
			Return IsInInterval(Number, Interval);
		Else
			If IsInInterval(Number, TrimAll(Left(Interval, Position - 1))) Then
				Return True;
			Else
				Interval = Mid(Interval, Position + 1);
			EndIf;
		EndIf;

	EndDo;

	Return False;

EndFunction // BuildingNumberInInterval()

// Retrieves a postal code by passed street and building.
//
// Parameters: 
// Street - address classifier catalog item that contains the required street;
// BuildingNumber - building number whose postal code will be retrieved.
//
// Returns:
// String - postal code.
//
Function GetPostalCodeByStreetBuilding(Street, BuildingNumber)

	Query = New Query;
	Query.Text =
	"SELECT
	|	AddressClassifier.Description,
	|	AddressClassifier.PostalCode
	|FROM
	|	InformationRegister.AddressClassifier AS AddressClassifier
	|WHERE
	|	AddressClassifier.AddressItemType = 6
	|	AND AddressClassifier.AddressObjectCodeInCode = &AddressObjectCodeInCode
	|	AND AddressClassifier.CountyCodeInCode = &CountyCodeInCode
	|	AND AddressClassifier.CityCodeInCode = &CityCodeInCode
	|	AND AddressClassifier.SettlementCodeInCode = &SettlementCodeInCode
	|	AND AddressClassifier.StreetCodeInCode = &StreetCodeInCode";
	Query.SetParameter("AddressObjectCodeInCode", Street.AddressObjectCodeInCode);
	Query.SetParameter("CountyCodeInCode", Street.CountyCodeInCode);
	Query.SetParameter("CityCodeInCode", Street.CityCodeInCode);
	Query.SetParameter("SettlementCodeInCode", Street.SettlementCodeInCode);
	Query.SetParameter("StreetCodeInCode", Street.StreetCodeInCode);
	
	Selection = Query.Execute().Choose();
	BuildingPostalCode = "";
	
	While Selection.Next() Do

		If Not IsBlankString(Selection.PostalCode) Then
			Interval = Upper(TrimAll(Selection.Description));
			
			If BuildingNumberInInterval(TrimAll(BuildingNumber), Interval) Then
				BuildingPostalCode = Selection.PostalCode;
							
			EndIf;
			
		EndIf;
		
	EndDo;
	
	If IsBlankString(BuildingPostalCode) Then
		Return Street.PostalCode;
	Else
		Return BuildingPostalCode;
	EndIf;
	
EndFunction

// Returns a restriction structure by address
//
// Parameters:
// StateField - String - state;
// CountyField - String - county;
// CityField - String - city;
// SettlementField - String - settlement;
// StreetName - String - street;
// ItemLevel - Number - address item level.
//
// Returns:
// Structure - restriction structure.
//
Function GetRestrictionStructureByAddress(StateField, CountyField, CityField, SettlementField, StreetName, ItemLevel) 
	
	If ItemLevel > 1 Then
		
		ParentCode = Undefined;
		RestrictionStructure = ReturnRestrictionStructureByParent(StateField, CountyField, CityField,
		  SettlementField, StreetName, ParentCode, ItemLevel);
		
	Else
		RestrictionStructure = New Structure();
		RestrictionStructure.Insert("AddressItemType", ItemLevel);
	EndIf;
	
	Return RestrictionStructure;
	
EndFunction

// Searches for the required address item by its name, type, and parent item. 
// Returns the first found item.
//
// Parameters:
// ItemName - address item name (with abbreviation);
// ItemType - address item type;
// ParentItem - parent item.
//
// Returns:
// Found Address classifier catalog item or an empty reference.
//
Function GetAddressItem(ItemName, ItemType, ParentItem)

	If (TrimAll(ItemName) = "") Or (ItemType = 0) Then
		Return GetEmptyAddressStructure();
	EndIf;
	
	// Checking whether the name contains the address abbreviation of the current level.
	// If the name contains this abbreviation, searching by name and address abbreviation.
	AddressAbbreviation = "";
	ItemName = GetNameAndAddressAbbreviation(ItemName, AddressAbbreviation);

	Query = New Query();
	
	RestrictionByCode = "";
	If ParentItem.Code > 0 Then // adding a filter by parent to the query
		
		If ParentItem.AddressItemType <= 5 Then
			
			If ParentItem.AddressObjectCodeInCode <> 0 Then
				RestrictionByCode = RestrictionByCode + Chars.LF 
				+ " AND (AddressClassifier.AddressObjectCodeInCode = &AddressObjectCodeInCode)";
				Query.SetParameter("AddressObjectCodeInCode", ParentItem.AddressObjectCodeInCode);
			EndIf;
			
			If ParentItem.CountyCodeInCode <> 0 Then
				RestrictionByCode = RestrictionByCode + Chars.LF 
				+ " AND (AddressClassifier.CountyCodeInCode = &CountyCodeInCode)";
				Query.SetParameter("CountyCodeInCode", ParentItem.CountyCodeInCode);
			EndIf;
			
			If ParentItem.CityCodeInCode <> 0 Then
				RestrictionByCode = RestrictionByCode + Chars.LF 
				+ " AND (AddressClassifier.CityCodeInCode = &CityCodeInCode)";
				Query.SetParameter("CityCodeInCode", ParentItem.CityCodeInCode);
			EndIf;
			
			If ParentItem.SettlementCodeInCode <> 0 Then
				RestrictionByCode = RestrictionByCode + Chars.LF 
				+ " AND (AddressClassifier.SettlementCodeInCode = &SettlementCodeInCode)";
				Query.SetParameter("SettlementCodeInCode", ParentItem.SettlementCodeInCode);
			EndIf;
			
			If ParentItem.StreetCodeInCode <> 0 Then
				RestrictionByCode = RestrictionByCode + Chars.LF 
				+ " AND (AddressClassifier.StreetCodeInCode = &StreetCodeInCode)";
				Query.SetParameter("StreetCodeInCode", ParentItem.StreetCodeInCode);
			EndIf;
		
		EndIf;
		
	EndIf;
	
	// Adding a filter by address abbreviation
	If AddressAbbreviation <> "" Then
		RestrictionByCode = RestrictionByCode + Chars.LF + " AND (AddressClassifier.Abbreviation = &AddressAbbreviation)";
		Query.SetParameter("AddressAbbreviation", AddressAbbreviation);
	EndIf;
	
	Query.Text = 
	"SELECT TOP 1
	|	AddressClassifier.Code,
	|	AddressClassifier.AddressObjectCodeInCode,
	|	AddressClassifier.Description,
	|	AddressClassifier.Abbreviation,
	|	AddressClassifier.PostalCode,
	|	AddressClassifier.AddressItemType,
	|	AddressClassifier.CountyCodeInCode,
	|	AddressClassifier.CityCodeInCode,
	|	AddressClassifier.SettlementCodeInCode,
	|	AddressClassifier.StreetCodeInCode,
	|	AddressClassifier.ActualityFlag
	|FROM
	|	InformationRegister.AddressClassifier AS AddressClassifier
	|
	|WHERE
	|	AddressClassifier.AddressItemType = &AddressItemType
	|	AND AddressClassifier.Description = &Description " +
	RestrictionByCode;
	
	Query.SetParameter("AddressItemType", ItemType);
	Query.SetParameter("Description", ItemName);
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return GetEmptyAddressStructure();
	Else
		
		Selection = QueryResult.Choose();
		Selection.Next();
		ResultStructure = New Structure;
		For Each Column In QueryResult.Columns Do
			ResultStructure.Insert(Column.Name, Selection[Column.Name]);
		EndDo;
		Return ResultStructure;
		
	EndIf;
	
EndFunction

// Adds the nonzero code value to the structure.
// 
// Parameters:
// StructureData - Structure - structure where data will be added;
// ItemName - String - item name;
// ItemCode - Number - item code;
// ParentLevel - Number - parent level;
// ItemLevel - Number - item level.
//
Procedure AddCodeToStructure(StructureData, ItemName, ItemCode, ParentLevel, ItemLevel)
	
	If (ItemCode <> 0) Or (ParentLevel >= ItemLevel) Then
		StructureData.Insert(ItemName, ItemCode);
EndIf;
	
EndProcedure

// Deletes letters and all other characters except digits from the passed string. 
// 
// Parameters:
// StringToParse - String - string where all characters except digits will be deleted.
// 
// Returns:
// String - string that contains digits only.
//
Function KeepOnlyDigitsInString(StringToParse)

	Digits = "1234567890";
	NumericPart = "";
	For CharacterNumber = 1 to StrLen(StringToParse) Do
		CurrentChar = Mid(StringToParse, CharacterNumber, 1);
		If Find(Digits, CurrentChar) Then
			NumericPart = NumericPart + CurrentChar;
		Else
			Break;
		EndIf;
	EndDo;
	Return NumericPart;
	
EndFunction

// End StandardSubsystems.AddressClassifier