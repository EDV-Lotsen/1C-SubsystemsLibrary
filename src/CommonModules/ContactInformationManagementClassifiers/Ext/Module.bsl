

// Check if classifiers are used in configuration
Function ClassifiersUsed() Export
	
	Return True;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// EXPORT FUNCTIONS, CALLED FROM ADDRESS INPUT FORM

// function generates string for data search in query from a source string
Function GenerateStringForSearchInQuery(Val SearchString) Export
	
	// AddressClassifier
	TotalsStringForSearch = SearchString;
	TotalsStringForSearch = StrReplace(TotalsStringForSearch, "~", "~~");
	TotalsStringForSearch = StrReplace(TotalsStringForSearch, "%", "~%");
	TotalsStringForSearch = StrReplace(TotalsStringForSearch, "_", "~_");
	TotalsStringForSearch = StrReplace(TotalsStringForSearch, "[", "~[");
	TotalsStringForSearch = StrReplace(TotalsStringForSearch, "-", "~-");

	Return TotalsStringForSearch;
// End AddressClassifier
	
EndFunction

// Find records in address classifier using postal code
Function FindInAddressClassifierRecordsByPostalCode(PostalCode) Export
	
	// AddressClassifier
	Result = New Structure;
	Result.Insert("Quantity",      0);
	Result.Insert("StateFound",    "");
	Result.Insert("ProvinceFound", "");
	
	// Check postal code input correctness
	If StrLen(PostalCode) <> 6 Then
		Return Result;
	EndIf;
	
	// Find records by postal code
	Query = New Query;
	Query.Text = "SELECT
	             |	AddressClassifier.AddressItemType,
	             |	AddressClassifier.Code,
	             |	AddressClassifier.Description + "" "" + AddressClassifier.Abbreviation AS Description
	             |FROM
	             |	InformationRegister.AddressClassifier AS AddressClassifier
	             |WHERE
	             |	AddressClassifier.PostalCode = &PostalCode";
	Query.SetParameter("PostalCode", PostalCode);
	Selection = Query.Execute().Choose();
	
	// If nothing was found
	If Selection.Count() = 0 Then
		Return Result;
	EndIf;
	
	// Save descriptions of the records found
	TypeByCode = New Map;
	NameByCode = New Map;
	
	While Selection.Next() Do
		AddressItemType = Selection.AddressItemType;
		Code = Selection.Code;
		
		If AddressItemType < 6 Then
			// not building
			NameByCode.Insert(Code, TrimR(Selection.Description));
		EndIf;
		
		TypeByCode.Insert(Code, AddressItemType);
	EndDo;
	
	// Determine object codes, whose descriptions we need to find
	CodesToSearch = New Array;
	SearchCodeTypes = New Map;
	
	For Each Found In TypeByCode Do
		AddressItemType = Found.Value;
		Code = Found.Key;
		
		While AddressItemType > 1 Do
			AddressItemType = AddressItemType - 1;
			Mask = GetMaskByType(AddressItemType);
			Code = Code - (Code % Mask);
			
			If (TypeByCode.Get(Code) = Undefined) And (SearchCodeTypes.Get(Code) = Undefined) Then
				SearchCodeTypes.Insert(Code, AddressItemType);
				CodesToSearch.Add(Code);
			EndIf;
		EndDo;
	EndDo;
	
	// Get missing descriptions
	If CodesToSearch.Count() <> 0 Then
		Query = New Query;
		Query.Text = "SELECT
		             |	AddressClassifier.AddressItemType,
		             |	AddressClassifier.Code,
		             |	AddressClassifier.Description + "" "" + AddressClassifier.Abbreviation AS Description
		             |FROM
		             |	InformationRegister.AddressClassifier AS AddressClassifier
		             |WHERE
		             |	AddressClassifier.Code IN(&Codes)";
		Query.SetParameter("Codes", CodesToSearch);
		Selection = Query.Execute().Choose();
		
		While Selection.Next() Do
			NameByCode.Insert(Selection.Code, TrimR(Selection.Description));
			TypeByCode.Insert(Selection.Code, Selection.AddressItemType);
		EndDo;
	EndIf;
	
	// Determine which records we do not need to output and which distinct regions and areas exist
	AllRegions = New Map;
	AllAreas  = New Map;
	NotIncludeInTable = New Map;

	For Each Item In TypeByCode Do
		AddressItemType = Item.Value;
		Code = Item.Key;
		
		If AddressItemType = 1 Then
			AllRegions.Insert(Code, True);
			StateFound = Code;
			
		ElsIf AddressItemType = 2 Then
			AllAreas.Insert(Code, True);
			ProvinceFound = Code;
		EndIf;
		
		If AddressItemType = 6 Then
			Continue;
		EndIf;
		
		While AddressItemType > 1 Do
			AddressItemType = AddressItemType - 1;
			Mask = GetMaskByType(AddressItemType);
			Code = Code - (Code % Mask);
			NotIncludeInTable.Insert(Code, True);
		EndDo;
	EndDo;
	
	Result.StateFound = ?(AllRegions.Count() = 1, NameByCode.Get(StateFound), "");
	Result.ProvinceFound   = ?(AllAreas.Count()   = 1, NameByCode.Get(ProvinceFound),  "");
	
	// Determine details level of output information about city / territory
	If AllRegions.Count() > 1 Then
		DetailsTillLevel = 1;
	ElsIf AllAreas.Count() > 1 Then
		DetailsTillLevel = 2;
	Else
		DetailsTillLevel = 3;
	EndIf;
	
	
	// Clear table
	RecordsFoundByIndex = New ValueTable;
	RecordsFoundByIndex.Columns.Add("Street",  New TypeDescription("String"));
	RecordsFoundByIndex.Columns.Add("Details", New TypeDescription("String"));
	RecordsFoundByIndex.Columns.Add("Code",    New TypeDescription("String"));
	
	// Fill table with found records
	For Each Item In TypeByCode Do
		AddressItemType = Item.Value;
		Code = Item.Key;
		
		If (AddressItemType = 6) Or (NotIncludeInTable.Get(Code) <> Undefined) Then
			Continue;
		EndIf;
		
		NewRow 		   = RecordsFoundByIndex.Add();
		NewRow.Street  = ?(AddressItemType = 5, NameByCode.Get(Code), "< Without street >");
		NewRow.Code    = Format(Code, "NG=");
		NewRow.Details = "";
		
		// Get description
		AddressItemType = ?(AddressItemType = 5, 4, AddressItemType);
		While AddressItemType >= DetailsTillLevel Do
			Code = Code - (Code % GetMaskByType(AddressItemType));
			If GetAddressItemType(Code) = AddressItemType Then
				NewRow.Details = NewRow.Details + ?(NewRow.Details = "", "", ", ") + NameByCode.Get(Code);
			EndIf;
			
			AddressItemType = AddressItemType - 1;
		EndDo;
	EndDo;
	
	RecordsFoundByIndex.Sort("Street, Code");
	
	Quantity = RecordsFoundByIndex.Count();
	Result.Insert("Quantity", Quantity);
	
	If Quantity = 1 Then
		
		AddressItemCode = Number(RecordsFoundByIndex[0].Code);
		GetItemComponentsByAddressItemCodeToStructure(AddressItemCode, Result);
		
	ElsIf Quantity > 1 Then
		
		AddressInStorage = PutToTempStorage(RecordsFoundByIndex, New UUID);
		Result.Insert("AddressInStorage", AddressInStorage);
		
	EndIf;
	
	Return Result;
	// End AddressClassifier
	
EndFunction

// Get components of address item by item code
Procedure GetItemComponentsByAddressItemCodeToStructure(AddressItemCode, Result) Export
	
	// AddressClassifier
	State 	 = "";
	Province = "";
	City  	 = "";
	District = "";
	Street   = "";
	
	GetAddressItemComponentsByCode(AddressItemCode, State, Province, City, District, Street, "");
	
	Result.Insert("State", 	  State);
	Result.Insert("Province", Province);
	Result.Insert("City",  	  City);
	Result.Insert("District", District);
	Result.Insert("Street",   Street);
	// End AddressClassifier
	
EndProcedure

// Function determines postal code using region, area, city, locality,
// street, building and corpus
//
// Parameters:
//  RegionName 		- region name (with abbreviation)
//  AreaName 		- area name (with abbreviation)
//  CityName 		- city name (with abbreviation)
//  DistrictName 	- locality name (with abbreviation)
//  Street 			- street name (with abbreviation)
//  BuildingNumber 	- buiding number, whose postal code has to be obtained
//  SubbuildingNo 		- corpus number
//
// Value returned:
//  String - 6 char postal code
//
Function GetPostalCode(Val RegionName, Val ProvinceName, Val CityName, Val DistrictName, Val StreetName, Val BuildingNumber, Val SubbuildingNo) Export

	// AddressClassifier
	PostalCodeParent = GetEmptyAddressStructure();
	PostalCode = "";
	
	State = GetAddressItem(RegionName, 1);
	If State.Code > 0 Then
		PostalCodeParent = State;
		If Not IsBlankString(State.PostalCode) Then
			PostalCode = State.PostalCode;
		EndIf;
	EndIf;
	
	Province = GetAddressItem(ProvinceName, 2, PostalCodeParent.Code);
	If Province.Code > 0 Then
		PostalCodeParent = Province;
		If Not IsBlankString(Province.PostalCode) Then
			PostalCode = Province.PostalCode;
		EndIf;
	EndIf;
	
	City = GetAddressItem(CityName, 3, PostalCodeParent.Code);
	If City.Code > 0 Then
		PostalCodeParent = City;
		If Not IsBlankString(City.PostalCode) Then
			PostalCode = City.PostalCode;
		EndIf;
	EndIf;
	
	District = GetAddressItem(DistrictName, 4, PostalCodeParent.Code);
	If District.Code > 0 Then
		PostalCodeParent = District;
		If Not IsBlankString(District.PostalCode) Then
			PostalCode = District.PostalCode;
		EndIf;
	EndIf;
	
	Street = GetAddressItem(StreetName, 5, PostalCodeParent.Code);
	If Street.Code > 0 Then
		StreetPostalCode = GetPostalCodeByStreetBuildingSubbuilding(Street, BuildingNumber, SubbuildingNo);
		If Not IsBlankString(StreetPostalCode) Then
			PostalCode = StreetPostalCode;
		EndIf;
	EndIf;

	Return PostalCode;
	// End AddressClassifier

EndFunction

// Handler of autopickup in address item
Function AutoCompleteTextInAddressFormItem(Text, State, Province, City, District, ItemLevel) Export
	
	// AddressClassifier
	ConditionsStructure = GetConditionsStructureByAddress(State, Province, City, District, "", ItemLevel);
	QueryResult = GetAutoCompleteQueryResultForRegister(Text, ConditionsStructure, 51);
	
	Quantity = QueryResult.Count();
	If (Quantity = 0) Then
		Return Undefined;
	EndIf;
	
	Result = New ValueList;
	For Each Str In QueryResult Do
		Result.Add(TrimAll(Str.Description) + " " + TrimAll(Str.Abbreviation));
	EndDo;
	
	Return Result;
    // End AddressClassifier
	
EndFunction

// AddressClassifier

////////////////////////////////////////////////////////////////////////////////
// EXPORT FUNCTIONS, CALLED FROM ADDRESS CLASSIFIER CHOICE FORM

// Function returns structure of restrictions using passed parameters
// already filled address fields
//
// Parameters:
//  RegionName 	 - region name (with abbreviation)
//  AreaName 	 - area name (with abbreviation)
//  CityName 	 - city name (with abbreviation)
//  DistrictName - locality name (with abbreviation)
//
Function ReturnConditionsStructureByParent(Val RegionName,  Val ProvinceName, Val CityName, 
										   Val DistrictName, Val StreetName, ParentCode) Export
	
	ConditionsStructure = New Structure();
	ParentItem = ReturnAddressClassifierStringByAddressItem(RegionName, ProvinceName, CityName, 
											                DistrictName, StreetName);
	
	ParentCode = ParentItem.Code;
	
	// determine item level by code
	ItemType = GetAddressItemType(ParentCode);
	AddCodeToStructure(ConditionsStructure, "AddressClassifierUnitCodeInCode", Int(ParentCode / StateMask()), ItemType, 1);
    AddCodeToStructure(ConditionsStructure, "ProvinceCodeInCode", 			   Int(ParentCode / ProvinceMask()) % 1000, ItemType, 2);
	AddCodeToStructure(ConditionsStructure, "CityCodeInCode", 				   Int(ParentCode / CityMask()) % 1000, ItemType, 3);
	AddCodeToStructure(ConditionsStructure, "DistrictCodeInCode", 			   Int(ParentCode / DistrictMask()) % 1000, ItemType, 4);
	AddCodeToStructure(ConditionsStructure, "StreetCodeInCode", 			   Int(ParentCode / StreetMask())% 10000, ItemType, 5);
	
	Return ConditionsStructure;
	
EndFunction

// Function returns address classifier string using values of address items
Function ReturnAddressClassifierStringByAddressItem(Val RegionName, Val ProvinceName, Val CityName, 
											        Val DistrictName, Val StreetName) Export
											
	ParentItem = Undefined;
	ParentItemCode = 0;

	State = GetAddressItem(RegionName, 1);
	If State.Code > 0 Then
		ParentItem = State;
		ParentItemCode = State.Code;
	EndIf;
	
	Province = GetAddressItem(ProvinceName, 2, ParentItemCode);
	If Province.Code > 0 Then
		ParentItem = Province;
		ParentItemCode = Province.Code;
	EndIf;
	
	City = GetAddressItem(CityName, 3, ParentItemCode);
    If City.Code > 0 Then
		ParentItem = City;
		ParentItemCode = City.Code;
	EndIf;
	
	District = GetAddressItem(DistrictName, 4, ParentItemCode);
	If District.Code > 0 Then
		ParentItem = District;
		ParentItemCode = District.Code;
	EndIf;
	
	Street = GetAddressItem(StreetName, 5, ParentItemCode);
	If Street.Code > 0 Then
		ParentItem = Street;
		ParentItemCode = Street.Code;
	EndIf;
	
	If ParentItem = Undefined Then
		Return GetEmptyAddressStructure()
	Else
		Return ParentItem;
	EndIf;
										
EndFunction

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES OF SEARCH BY STRING

//Function Builds autopickup query for a register
Function GetAutoCompleteQueryResultForRegister(Val Text, ParametersStructure, ItemCount)
	
	Object = Metadata.InformationRegisters.AddressClassifier;
    	
	FiltersStructureString = "";
	
	Query = CreateQueryForAutoCompleteList(Text, FiltersStructureString, ParametersStructure, "RegisterTable");
	
	FieldRow = "SELECT ALLOWED TOP " + String(ItemCount) + "
			   |	RegisterTable.* ";
	
	Query.Text = FieldRow + "
		|FROM
		|	InformationRegister.AddressClassifier AS RegisterTable
		|WHERE ";

	
	// generate restrictions by search fields
	RestrictionByField = "(RegisterTable.Description LIKE &AutoCompleteText ESCAPE ""~"") ";
	
	Query.Text = Query.Text +"
		|	(" + RestrictionByField + ") " + FiltersStructureString;

	Return Query.Execute().Unload();
 	
EndFunction

// Function creates object query and assignes its parameters AutoCompleteText and AutoCompleteTextNumber
// removes unneeded chars in search string
Function CreateQueryForAutoCompleteList(SearchString, FiltersStructureString, ParametersStructure, RestrictionsTableName)
	
	Query = New Query;
	
	SearchString = GenerateStringForSearchInQuery(SearchString);
		
	Query.SetParameter("AutoCompleteText"     , (SearchString + "%"));
	Try
		Query.SetParameter("AutoCompleteTextNumber", Number(SearchString));
	Except
		Query.SetParameter("AutoCompleteTextNumber", Undefined);
	EndTry;
	
	// Sets restrictions
	FiltersStructureString = "";
	For Each StructureItem In ParametersStructure Do
		KeyData = StructureItem.Key;
        Value   = StructureItem.Value;

		Query.SetParameter(KeyData, Value);
		FiltersStructureString = FiltersStructureString + "
		|		And
		|		" + RestrictionsTableName + "." + KeyData + " In (&"+ KeyData + ")";
	EndDo; 
	
	Return Query;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS OF WORK WITH ADDRESS CODE

// Function returns mask to determine item number in code structure
//
// Parameters:
// Not
//
// Value returned:
//  Number - mask with digit 'one' in leftmost position and zeros in other positions
//
Function StateMask()
	Return 10000000000000000000;
EndFunction

// Function returns mask to determine item number in code structure
//
// Parameters:
// Not
//
// Value returned:
//  Number - mask with digit 'one' in leftmost position and zeros in other positions
//
Function ProvinceMask()
	Return 10000000000000000;
EndFunction

// Function returns mask to determine item number in code structure
//
// Parameters:
// Not
//
// Value returned:
//  Number - mask with digit 'one' in leftmost position and zeros in other positions
//
Function CityMask()
	Return 10000000000000;
EndFunction

// Function returns mask to determine item number in code structure
//
// Parameters:
// Not
//
// Value returned:
//  Number - mask with digit 'one' in leftmost position and zeros in other positions
//
Function DistrictMask()
	Return 10000000000;
EndFunction

// Function returns mask to determine item number in code structure
//
// Parameters:
// Not
//
// Value returned:
//  Number - mask with digit 'one' in leftmost position and zeros in other positions
//
Function StreetMask()
	Return 1000000;
EndFunction

// Function returns mask to determine item number in code structure
//
// Parameters:
// Not
//
// Value returned:
//  Number - mask with digit 'one' in leftmost position and zeros in other positions
//
Function BuildingMask()
	Return 100;
EndFunction

// Function returns mask to determine item number in code structure
//
// Parameters:
// Not
//
// Value returned:
//  Number - mask with digit 'one' in leftmost position and zeros in other positions
//
Function ApartmentMask()
	Return 100;
EndFunction

// Function sets mask in correspondence to address item type,
// using this mask item important code is being extracted
//
// Parameters:
//  AddressItemType -  number - type of address item.
//
// Value returned:
// Number - mask, used to extract important code via dividing on this mask
// address item
//
Function GetMaskByType(AddressItemType)

	If AddressItemType = 1 Then
		Return StateMask();

	ElsIf AddressItemType = 2 Then
		Return ProvinceMask();

	ElsIf AddressItemType = 3 Then
		Return CityMask();

	ElsIf AddressItemType = 4 Then
		Return DistrictMask();

	ElsIf AddressItemType = 5 Then
		Return StreetMask();

	ElsIf AddressItemType = 6 Then
		Return BuildingMask();

	Else
		Return ApartmentMask();

	EndIf;

EndFunction

// Function sets mask in correspondence to address item type,
// using this mask item important code is being extracted
//
// Parameters:
//  AddressItemType -  number - type of address item.
//
// Value returned:
// Number - mask, used to extract important code via dividing on this mask
// address item
//
Function GetAddressItemType(ItemCode)
	
	If ItemCode = 0 Then
		Return 0;
	EndIf;
	
	If ItemCode % StateMask()       < 100 Then // state 21 zero and AA
		Return 1;
		
	ElsIf ItemCode % ProvinceMask() < 100 Then // province 18 zero and AA
		Return 2;
		
	ElsIf ItemCode % CityMask()     < 100 Then // city 15 zero and AA
		Return 3;
		
	ElsIf ItemCode % DistrictMask() < 100 Then // district 12 zero and AA
		Return 4;
		
	ElsIf ItemCode % StreetMask()   < 100 Then // street 8 zero and AA
		Return 5;
		
	ElsIf ItemCode % BuildingMask() < 100 Then // building 4 zero and AA
		Return 6;
		
	Else // apartment
		Return 7;
		
	EndIf;
	
EndFunction

// Procedure returns address string presenations of item hierarchy by its code
Function GetAddressItemComponentsByCode(AddressItemCode, State, Province, City, District, Street, Building)
	
	Item = GetAddressItemStructure(AddressItemCode);
	
	If Item.AddressItemType >= 6 Then
		Building = GetAddressItemPresentationByCode(AddressItemCode - AddressItemCode%BuildingMask(), 6);
	EndIf;
	
	If Item.AddressItemType >= 5 Then
		Street = GetAddressItemPresentationByCode(AddressItemCode - AddressItemCode%StreetMask(), 5);
	EndIf;
	
	If Item.AddressItemType >= 4 Then
		District = GetAddressItemPresentationByCode(AddressItemCode - AddressItemCode%DistrictMask(), 4);
	EndIf;

	If Item.AddressItemType >= 3 Then
		City = GetAddressItemPresentationByCode(AddressItemCode - AddressItemCode%CityMask(), 3);
	EndIf;

	If Item.AddressItemType >= 2 Then    
		Province = GetAddressItemPresentationByCode(AddressItemCode - AddressItemCode%ProvinceMask(), 2);
	EndIf;

	If Item.AddressItemType >= 1 Then
		State = GetAddressItemPresentationByCode(AddressItemCode - AddressItemCode%StateMask(), 1);
	EndIf;

	Return Item;
	
EndFunction

Function GetAddressItemStructure(ItemCode)
	
	ParsingCode = ItemCode;
	AddressItemType = GetAddressItemType(ParsingCode);
	
	AddressClassifierUnitCode = Int(ParsingCode / StateMask());
	ParsingCode = ParsingCode % StateMask();

	AreaCode = Int(ParsingCode / ProvinceMask());
	ParsingCode = ParsingCode % ProvinceMask();

	CityCode = Int(ParsingCode / CityMask());
	ParsingCode = ParsingCode % CityMask();

	PlaceCode = Int(ParsingCode / DistrictMask());
	ParsingCode = ParsingCode % DistrictMask();

	StreetCode = Int(ParsingCode / StreetMask());
	
	QueryText = "SELECT
	           |	AddressClassifier.Code,
	           |	AddressClassifier.AddressClassifierUnitCodeInCode,
	           |	AddressClassifier.Description,
	           |	AddressClassifier.Abbreviation,
	           |	AddressClassifier.PostalCode,
	           |	AddressClassifier.AddressItemType,
	           |	AddressClassifier.ProvinceCodeInCode,
	           |	AddressClassifier.CityCodeInCode,
	           |	AddressClassifier.DistrictCodeInCode,
	           |	AddressClassifier.StreetCodeInCode
	           |FROM
	           |	InformationRegister.AddressClassifier AS AddressClassifier
	           |WHERE
	           |	AddressClassifier.AddressItemType = &AddressItemType
	           |	AND AddressClassifier.AddressClassifierUnitCodeInCode = &AddressClassifierUnitCode
	           |	AND AddressClassifier.ProvinceCodeInCode = &AreaCode
	           |	AND AddressClassifier.CityCodeInCode = &CityCode
	           |	AND AddressClassifier.DistrictCodeInCode = &PlaceCode
	           |	AND AddressClassifier.StreetCodeInCode = &StreetCode
	           |	AND AddressClassifier.Code = &ItemCode";
	
	Query = New Query(QueryText);
	Query.SetParameter("AddressItemType", 			AddressItemType);
	Query.SetParameter("AddressClassifierUnitCode", AddressClassifierUnitCode);
	Query.SetParameter("AreaCode", 					AreaCode);
	Query.SetParameter("CityCode", 					CityCode);
	Query.SetParameter("PlaceCode", 				PlaceCode);
	Query.SetParameter("StreetCode", 				StreetCode);
	Query.SetParameter("ItemCode", 					Number(ItemCode));
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return GetEmptyAddressStructure();
	EndIf;
	
	Selection = QueryResult.Choose();
	
	Selection.Next();
	
	Return New Structure("Code,Description,Abbreviation,AddressItemType,PostalCode,AddressClassifierUnitCodeInCode,ProvinceCodeInCode,CityCodeInCode,DistrictCodeInCode,StreetCodeInCode",
						 Selection.Code,
						 Selection.Description,
						 Selection.Abbreviation,
						 Selection.AddressItemType,
						 Selection.PostalCode,
						 Selection.AddressClassifierUnitCodeInCode,
						 Selection.ProvinceCodeInCode,
						 Selection.CityCodeInCode,
						 Selection.DistrictCodeInCode,
						 Selection.StreetCodeInCode);

EndFunction

// Function returns name of address item of specific level by code
Function GetAddressItemPresentationByCode(ItemCode, AddressItemType)
	
	AddressItemName = "";
	// first, determine item level by code, if it does not match the required code, then do not access DB
	ItemType = GetAddressItemType(ItemCode);
	If  ItemType <> AddressItemType Then
		Return AddressItemName;
	EndIf;
	
	AddressItem = GetAddressItemStructure(ItemCode);
	If AddressItem.AddressItemType = AddressItemType Then
		AddressItemName = GetAddressItemPresentation(AddressItem);
	EndIf;
	
	Return AddressItemName;
	
EndFunction

// Function returns structure with the same set of fields as information register record set of fields
//  AddressClassifier with empty set of values
//
// Parameters:
// Not.
//
// Value returned:
// Structure - structure with the same set of fields as information register record set of fields
//  AddressClassifier with empty set of values
//
Function GetEmptyAddressStructure()
	
	Return New Structure("Code,Description,Abbreviation,AddressItemType,PostalCode,AddressClassifierUnitCodeInCode,ProvinceCodeInCode,CityCodeInCode,DistrictCodeInCode,StreetCodeInCode", 0, "", "", 0, "", 0, 0, 0, 0, 0);
	
EndFunction

// Function generates string with the name of address item,
// consisting of description and abbreviation
//
// Parameters:
//  AddressItem - item of catalog Address classifier.
//
// Value returned:
//  Name of address item
//
Function GetAddressItemPresentation(AddressItem)

	If AddressItem.Code = 0 Then
		Return "";
	Else
		Return TrimAll(AddressItem.Description) + " " + TrimAll(AddressItem.Abbreviation)
	EndIf;

EndFunction

// Procedure transfers string from query to Structure
Procedure FillStructureWithSelectionRow(QueryResult, SelectionRow, ItemStructure) 
	
	If ItemStructure = Undefined 
		Or QueryResult = Undefined 
		Or SelectionRow = Undefined Then
		Return;
	EndIf;
	
	ItemStructure.Clear();
	For Each Column In QueryResult.Columns Do
		ItemStructure.Insert(Column.Name, SelectionRow[Column.Name]);
	EndDo;
	
EndProcedure // FillStructureWithSelectionRow()

// Function creates structure based on selection row
Function CreateStructureBySelectionString(QueryResult, SelectionRow)
	
	ResultantStructure = New Structure;
	FillStructureWithSelectionRow(QueryResult, SelectionRow, ResultantStructure);
	Return ResultantStructure; 
	
EndFunction

// Function returns separately name and address abbreviation of address item using its full description
Function SplitAddressItemStringIntoTitleAndAbbreviation(Val ItemString, AddressAbbr)

	Buffer = TrimR(ItemString);
	SpacePosition = Find(Buffer, " ");

	If SpacePosition = 0 Then
		Return ItemString;
	EndIf;
	
	While StrOccurrenceCount(Buffer, " ") > 1 Do
		Buffer = Left(Buffer, SpacePosition - 1) + "_" + Mid(Buffer, SpacePosition + 1);
		SpacePosition = Find(Buffer, " ");
	EndDo;
	
	QueryText = 
		"SELECT TOP 1
		|	AddressAbbreviations.Abbreviation
		|FROM
		|	InformationRegister.AddressAbbreviations AS AddressAbbreviations
		|WHERE
		|	AddressAbbreviations.Abbreviation = &Abbreviation";
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("Abbreviation", Mid(ItemString, SpacePosition + 1));
	
	If Query.Execute().IsEmpty() Then
		Return ItemString;
	EndIf;
	
	If IsBlankString(TrimAll(Left(ItemString, SpacePosition - 1))) Then
		Return ItemString;
	Else
		AddressAbbr = Mid(ItemString, SpacePosition + 1);
		Return Left(ItemString, SpacePosition - 1);
	EndIf;
	
EndFunction

// Procedure apportions address item code to parts:
// State code, area code, city code, locality code, street code, and buiding code
Procedure DecomposeAddressItemCodeToComponents(Val Code, AddressClassifierUnitCode, AreaCode, CityCode, PlaceCode, StreetCode, BuildingCode)
	
	ItemCode = Code;
	
	AddressClassifierUnitCode = Int(ItemCode / StateMask());
	ItemCode   = ItemCode % StateMask();
               
	AreaCode   = Int(ItemCode / ProvinceMask());
	ItemCode   = ItemCode % ProvinceMask();
               
	CityCode   = Int(ItemCode / CityMask());
	ItemCode   = ItemCode % CityMask();
               
	PlaceCode  = Int(ItemCode / DistrictMask());
	ItemCode   = ItemCode % DistrictMask();

	StreetCode = Int(ItemCode / StreetMask());
	ItemCode   = ItemCode % StreetMask();

	BuildingCode = Int(ItemCode / BuildingMask());

EndProcedure // DecomposeAddressItemCodeToComponents()

// Function searches required address item by name and type
// and returns first found item. Item "parent" can be defined
// as an addition
//
// Parameters:
//  ItemName   - name of address item (with abbreviation)
//  ItemType   - type of sought address item
//  ParentItem - item "parent"
//
// Value returned:
//  Found item of catalog Address classifier or empty ref in case of error
//
Function GetAddressItem(ItemTitle, ItemType, ParentItemCode = 0)

	Var AddressClassifierUnitCode, AreaCode, CityCode, PlaceCode, StreetCode, BuildingCode;
	
	If (TrimAll(ItemTitle) = "") Or (ItemType = 0) Then
		Return GetEmptyAddressStructure();
	EndIf;
	
	// look if there is address abbreviation of current level in the name
	// if there is, then search using description and address abbreviation
	AddressAbbr = "";
	ItemTitle = SplitAddressItemStringIntoTitleAndAbbreviation(ItemTitle, AddressAbbr);

	Query = New Query();
	
	CodeCondition = "";
	If ParentItemCode > 0 Then // check for correspondence subordination to a parent
		AddressItemType = GetAddressItemType(ParentItemCode);
		ParentMask = GetMaskByType(AddressItemType);
		
		If AddressItemType <= 5 Then
			
			ItemCode = ParentItemCode;
			
			DecomposeAddressItemCodeToComponents(ItemCode, AddressClassifierUnitCode, AreaCode, CityCode, PlaceCode, StreetCode, BuildingCode);

			If AddressClassifierUnitCode <> 0 Then
				CodeCondition = CodeCondition + Chars.LF + "  And (AddressClassifier.AddressClassifierUnitCodeInCode = &AddressClassifierUnitCodeInCode)";
				Query.SetParameter("AddressClassifierUnitCodeInCode", AddressClassifierUnitCode);
			EndIf;
			
			If AreaCode <> 0 Then
				CodeCondition = CodeCondition + Chars.LF + "  And (AddressClassifier.ProvinceCodeInCode = &ProvinceCodeInCode)";
				Query.SetParameter("ProvinceCodeInCode", AreaCode);
			EndIf;
			
			If CityCode <> 0 Then
				CodeCondition = CodeCondition + Chars.LF + "  And (AddressClassifier.CityCodeInCode = &CityCodeInCode)";
				Query.SetParameter("CityCodeInCode", CityCode);
			EndIf;
			
			If PlaceCode <> 0 Then
				CodeCondition = CodeCondition + Chars.LF + "  And (AddressClassifier.DistrictCodeInCode = &DistrictCodeInCode)";
				Query.SetParameter("DistrictCodeInCode", PlaceCode);
			EndIf;
			
			If StreetCode <> 0 Then
				CodeCondition = CodeCondition + Chars.LF + "  And (AddressClassifier.StreetCodeInCode = &StreetCodeInCode)";
				Query.SetParameter("StreetCodeInCode", StreetCode);
			EndIf;
		
		Else
			// restrict by item code
			CodeEndValue = ParentItemCode + ParentMask - 1; 
			
			CodeCondition = Chars.LF + "  And (AddressClassifier.Code Between &InitialCodeValue And &CodeEndValue)";
			Query.SetParameter("InitialCodeValue", ParentItemCode);
			Query.SetParameter("CodeEndValue", CodeEndValue);
		EndIf;
		
	EndIf;
	
	// restriction on address abbreviation
	If AddressAbbr <> "" Then
		CodeCondition = CodeCondition + Chars.LF + "  And (AddressClassifier.Abbreviation = &AddressAbbr)";
		Query.SetParameter("AddressAbbr", AddressAbbr);
	EndIf;
	
	Query.Text = "SELECT TOP 1
	             |	AddressClassifier.Code,
	             |	AddressClassifier.AddressClassifierUnitCodeInCode,
	             |	AddressClassifier.Description,
	             |	AddressClassifier.Abbreviation,
	             |	AddressClassifier.PostalCode,
	             |	AddressClassifier.AddressItemType,
	             |	AddressClassifier.ProvinceCodeInCode,
	             |	AddressClassifier.CityCodeInCode,
	             |	AddressClassifier.DistrictCodeInCode,
	             |	AddressClassifier.StreetCodeInCode
	             |FROM
	             |	InformationRegister.AddressClassifier AS AddressClassifier
	             |WHERE
	             |	AddressClassifier.Description = &Description
	             |	AND AddressClassifier.AddressItemType = &AddressItemType" +
					CodeCondition;
	
	Query.SetParameter("Description", 	  ItemTitle);
	Query.SetParameter("AddressItemType", ItemType);
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return GetEmptyAddressStructure();
	EndIf;
	
	Selection = QueryResult.Choose();
	Selection.Next();
	
	Return CreateStructureBySelectionString(QueryResult, Selection);
	
EndFunction

// Procedure adds not zero code value to structure
Procedure AddCodeToStructure(DataStructure, TagName, ItemCode, ParentLevel, ItemLevel)
	
	If (ItemCode <> 0) Or (ParentLevel >= ItemLevel) Then
		DataStructure.Insert(TagName, ItemCode);
    EndIf;
	
EndProcedure

//Function returns structure of restrictions using address
Function GetConditionsStructureByAddress(State, Province, City, District, Street, ItemLevel) 
	
	If ItemLevel > 1 Then
		
		ParentCode = Undefined;
		ConditionsStructure = ReturnConditionsStructureByParent(State, Province, City, District, Street, ParentCode);
		
	Else
		ConditionsStructure = New Structure();
	EndIf;
	ConditionsStructure.Insert("AddressItemType", ItemLevel);
	
	Return ConditionsStructure;
	
EndFunction

// Function determines if number belongs to specified range
//  Range is specified as described in comments of function NumberInRange
//
// Parameters:
//  Number 		- (number, string) building number with corpus
//  Interval 	- (string), range of numbers (buildings)
//
// Value returned:
//  True 		- if specified number is in range,
//  False   	- if not in range
//
Function InInterval(Val Number, Interval)

	If IsBlankString("" + Number) Then
		Return False;
	EndIf;

	If Not StringFunctionsClientServer.StringContainsOnlyDigits(Number, False) Then
		Return Upper(StrReplace("" + Number, " ", "")) = Upper(StrReplace("" + Interval, " ", ""));
	EndIf;

	Number = Number(Number);

	OnlyNumberInterval = StringFunctionsClientServer.StringContainsOnlyDigits(Interval, False);
	
	If OnlyNumberInterval Then
		If Number = Number(Interval) Then
			Return True;
		EndIf;
	EndIf;

	If Find(Interval, "E") > 0 Then // range of even numbers
		Interval      = StrReplace(Interval, "E", "");
		Parity = 2;
	ElsIf Find(Interval, "O") > 0 Then // range of odd numbers
		Interval      = StrReplace(Interval, "O", "");
		Parity = 1;
	ElsIf (Find(Interval, "-") = 0) And OnlyNumberInterval Then 
		// interval this is a building represented as string, 
		// never occurs due to checked previously
		Return False;
	Else
		Parity=0;
	EndIf;
	
	Interval 		= StrReplace(Interval, ")", ""); // remove brackets just in case
	Interval 		= StrReplace(Interval, "(", "");
	SeparatorPosition = Find(Interval, "-");
	Hit 			= 0;
	
	If SeparatorPosition <> 0 Then
		MinValue  	= Number(Left(Interval, SeparatorPosition - 1));
		MaxValue 	= Number(Mid(Interval, SeparatorPosition + 1));
		If (Number >= MinValue) And (Number <= MaxValue) Then
			Hit = 1;
		EndIf;
	ElsIf IsBlankString(Interval) Then
		// case when interval was equal to E or O
		Hit = 1;
	Else
		If StringFunctionsClientServer.StringContainsOnlyDigits(Interval, False) Then
			If Number = Number(Interval) Then
				Hit = 1;
			EndIf;
		EndIf;
	EndIf;
	
	If (Hit = 1) 
	   And ( ((Parity = 2) And (Number % 2 = 0)) 
	         Or ((Parity = 1) And (Number % 2 = 1)) 
			 Or (Parity = 0)) Then
		Return True;
	EndIf;
	
	Return False;
	
EndFunction // InInterval()

// Function determines if parameter is in range, parameter:
//  1. Building number (represented as string)
//     where building Number is a string:
//     <StringBuilding> example: 58A, 32/1, 50A/8
//
//  2. Building number and corpus number, as string:
//     <StringBuilding>c<StringSubbuilding>, example: 32c1   this is building 32 corpus 1,
//     <StringBuilding>/<StringSubbuilding>, example: 32/1   this is building 32 corpus 1,
//     <StringBuilding>str<StringSubbuilding>, example: 32str1   this is building 32 corpus 1,
//
//  3. Number (building number) is in specified range of numbers
//     Interval is specified as a String:
//     <Range>[,<Range>]
//     where Range, this is a string:
//     [E/O]<Number>[-<Number>]
//     Prefix E or O means if number which belongs to this range even or odd
//     Example: In the interval E12-14,O1-5,20-29 enter numbers 1,3,5,12,14 and all numbers starting 20 to 29
//
// Parameters:
//  Number - (number, string) building number with corpus
//  Interval - (string), range of numbers (buildings)
//
//  True - if specified number is in range,
//  False   - if not in range
//
Function BuildingNumberInInterval(Number, Val Interval)
	
	While Not IsBlankString(Interval) Do

		CharPosition = Find(Interval, ",");
		If CharPosition = 0 Then
			Return InInterval(Number, Interval);
		Else
			If InInterval(Number, TrimAll(Left(Interval, CharPosition - 1))) Then
				Return True;
			Else
				Interval = Mid(Interval, CharPosition + 1);
			EndIf;
		EndIf;

	EndDo;

	Return False;

EndFunction // BuildingNumberInInterval()

// Function determines postal code by passed street, building and corpus
//
// Parameters:
//  Street - item of catalog address classifier with required street
//  BuildingNumber - buiding number, whose postal code has to be obtained
//  SubbuildingNo - corpus number
//
// Value returned:
//  String - 6 char postal code
//
Function GetPostalCodeByStreetBuildingSubbuilding(Street, BuildingNumber, SubbuildingNo)

	Query = New Query;
	Query.SetParameter("Level", 6);
	Query.SetParameter("BottomCode", Int(Street.Code / 1000000)    * 1000000);
	Query.SetParameter("TopCode", 	 Int(Street.Code / 1000000+ 1) * 1000000);

	Query.Text =
		"SELECT
		|	AddressClassifier.Description,
		|	AddressClassifier.PostalCode
		|FROM
		|	InformationRegister.AddressClassifier AS AddressClassifier
		|WHERE
		|	AddressClassifier.AddressItemType = &Level
		|	AND AddressClassifier.Code BETWEEN &BottomCode AND &TopCode";

	
	Selection = Query.Execute().Choose();
	BuildingPostalCode = "";
	
	While Selection.Next() Do

		If Not IsBlankString(Selection.PostalCode) Then
			Interval = Upper(TrimAll(Selection.Description));
			
			If BuildingNumberInInterval(TrimAll(BuildingNumber), Interval) Then
				BuildingPostalCode = Selection.PostalCode;
				
			ElsIf (BuildingNumberInInterval(TrimAll(BuildingNumber) + ?(Not IsBlankString(SubbuildingNo), "/", "") + TrimAll(SubbuildingNo), Interval)) Then
				Return Selection.PostalCode;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	If IsBlankString(BuildingPostalCode) Then
		Return Street.PostalCode;
	Else
		Return BuildingPostalCode;
	EndIf;
	
EndFunction

// End AddressClassifier

