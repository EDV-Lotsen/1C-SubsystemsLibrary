////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("SelfTest") Then
		Return;
	EndIf;
	
	ClassifiersUsed = ContactInformationManagementClassifiers.ClassifiersUsed();
	
	If Not ClassifiersUsed Then
		Items.Classifier.Visible = False;
	EndIf;
	
	ReadParameterValues();
	
	PresentationWithKind = KindDescription + ": " + Presentation;
	Title = KindDescription;
	
	HomeCountry = Catalogs.WorldCountries.USA;
	
	If Parameters.HomeCountryAddressOnly Then
		
		Country = HomeCountry;
		Items.Country.Enabled = False;
		Items.Country.ChoiceButton = False;
		
	Else
		
		If Not IsBlankString(CountryCode) Or Not IsBlankString(CountryDescription) Then
			// The country can be found if its code or description are specified
			FindCountryByCodeOrDescription(CountryCode, CountryDescription);
		Else
			Country = HomeCountry;
		EndIf;
		
	EndIf;
	
	If ValueIsFilled(Country) Then
		FillCountryCodeAndDescription();
	EndIf;
	
	If Not IsBlankString(Parameters.Title) Then
		AutoTitle = False;
		Title = Parameters.Title;
	EndIf;
	
	// StandardSubsystems.AddressClassifier
	
	// Restoring a value of the Hide obsolete addresses flag
	Value = CommonUse.CommonSettingsStorageLoad("AddressInput", "HideObsoleteAddresses");
	If Value = Undefined Then
		HideObsoleteAddresses = False;
	Else
		HideObsoleteAddresses = Value;
	EndIf;
	
	If ClassifiersUsed And (Country = HomeCountry) And Not IsBlankString(State) Then
		AddressStructure = GetAddressStructureAtServer();
		ImportedStructure = ImportedFieldsByState(AddressStructure);
		WriteAddressStructureAtServer(AddressStructure);
	EndIf;
	
	// End StandardSubsystems.AddressClassifier
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	CheckFieldTypes();
	CheckChoiceButtons();
	
	// StandardSubsystems.AddressClassifier
	If ClassifiersUsed And (Country = HomeCountry) And Not IsBlankString(State) Then
		SetFieldEnabledByState(ImportedStructure);
	EndIf;
	Items.HideObsoleteAddresses.Check = HideObsoleteAddresses;
	// End StandardSubsystems.AddressClassifier
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	CommonUseClient.RequestCloseFormConfirmation(Cancel, Modified, CloseButtonPressed); 
	
EndProcedure

// StandardSubsystems.AddressClassifier

&AtClient
Procedure OnClose()
	
	CommonUse.CommonSettingsStorageSave("AddressInput", "HideObsoleteAddresses", HideObsoleteAddresses);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
		
	If Upper(EventName) = Upper("Write_AddressClassifier") Then
		
		AddressStructure = GetAddressStructure();
		ImportedStructure = ImportedFieldsByState(AddressStructure);
		WriteAddressStructure(AddressStructure);
		SetFieldEnabledByState(ImportedStructure);
		
	EndIf;
	
EndProcedure

// End StandardSubsystems.AddressClassifier


////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS

&AtClient
Procedure CountryOnChange(Item)
	
	If Not ValueIsFilled(Country) Then
		Country = HomeCountry;
	EndIf;
	
	FillCountryCodeAndDescription();
	
	GeneratePresentation();
	CheckChoiceButtons();
	
	If Country <> HomeCountry Then
		// Enabling manual input of address fields
		Items.County.Enabled 				= True;
		Items.City.Enabled 				= True;
		Items.Settlement.Enabled 	= True;
		Items.Street.Enabled 				= True;
	EndIf;
	
	// StandardSubsystems.AddressClassifier
	If ClassifiersUsed And (Country = HomeCountry) And Not IsBlankString(State) Then
		LoadState();
		AddressStructure = GetAddressStructure();
		ImportedStructure = ImportedFieldsByState(AddressStructure);
		WriteAddressStructure(AddressStructure);
		SetFieldEnabledByState(ImportedStructure);
	EndIf;
	// End StandardSubsystems.AddressClassifier
	
EndProcedure

&AtClient
Procedure PostalCodeOnChange(Item)
	
	// StandardSubsystems.AddressClassifier
	If (Country = HomeCountry) And ClassifiersUsed
	And Not IsBlankString(PostalCode) And (StrLen(PostalCode) = 5) Then

		SearchParameters = New Structure;
		SearchParameters.Insert("PostalCode", PostalCode);
		SearchParameters.Insert("HideObsoleteAddresses", HideObsoleteAddresses);
		
		Result = OpenFormModal("CommonForm.FindByPostalCode", SearchParameters);
		
		If Result = Undefined Then
			Return;
		EndIf;
		
		Items.HideObsoleteAddresses.Check = Result.HideObsoleteAddresses;
		WriteAddressStructure(Result.AddressStructure);
		SetFieldEnabledByState(Result.ImportedStructure);
		
		#If Not WebClient Then
		If Not IsBlankString(Street) Then
			CurrentItem = Items.Street;
		ElsIf Not IsBlankString(Settlement) Then
			CurrentItem = Items.Settlement;
		ElsIf Not IsBlankString(City) Then
			CurrentItem = Items.City;
		ElsIf Not IsBlankString(County) Then
			CurrentItem = Items.County;
		ElsIf Not IsBlankString(State) Then
			CurrentItem = Items.State;
		EndIf;
		#EndIf
			
	EndIf;
	// End StandardSubsystems.AddressClassifier
	
	GeneratePresentation();

EndProcedure

&AtClient
Procedure FieldOnChange(Item)
	
	CheckFieldTypes();
	
	// StandardSubsystems.AddressClassifier
	If ClassifiersUsed And (Country = HomeCountry) Then
		
		// Handling fields and preparing data on the server to process it later on the client.
		AddressStructure = GetAddressStructure();
		ResultStructure = ProcessFieldAtServer(AddressStructure, GetItemLevel(Item));
		WriteAddressStructure(AddressStructure);
		
		SetFieldEnabledByState(ResultStructure.ImportedStructure);
		
		For Each Error In ResultStructure.ErrorsStructure Do
			ClearMessages();
			CommonUseClientServer.MessageToUser(Error.Value, , Error.Key);
		EndDo;
		
		If Item.Name = "State" Then
			LoadState(ResultStructure.CanImportState);
		EndIf;
		
	EndIf;
	// End StandardSubsystems.AddressClassifier
	
	GeneratePresentation();
	
EndProcedure

&AtClient
Procedure FieldStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	If (Not ClassifiersUsed) Or (Country <> HomeCountry) Then
		Return;
	EndIf;
	
	Level = GetItemLevel(Item);
	AddressStructure = GetAddressStructure();
	AddressStructure.Insert("Level", Level);
	
	GeneratePresentation();
	
EndProcedure

&AtServerNoContext
Function AddressItemBeforeChoice(State, HideObsoleteAddresses, CheckingState)
		
	If Not CheckingState And Not IsBlankString(State) Then
			
		StateImported = ContactInformationManagementClassifiers.AddressItemImported(State);
		If Not StateImported Then
			Return True;				
		EndIf;
		
	EndIf;
		
	CommonUse.CommonSettingsStorageSave("AddressInput", "HideObsoleteAddresses", HideObsoleteAddresses);
Return False;
	
EndFunction

///////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure CancelCommandExecute()
	
	CloseButtonPressed = True;
	Close();
	
EndProcedure

&AtClient
Procedure OKCommandExecute()
	
	CloseButtonPressed = True;
	Close(GetEditResult());
	
EndProcedure

&AtClient
Procedure ClearCommandExecute()
	
	Modified = True;
	
	Country = HomeCountry;
	CountryOnChange(Items.Country);
	
	PostalCode = "";
	State = "";
	County = "";
	City = "";
	Settlement = "";
	Street = "";
	Building = "";
	Appartment = "";
	AppartmentType = Items.AppartmentType.ChoiceList[0].Value;
	
	GeneratePresentation();
	
EndProcedure

// StandardSubsystems.AddressClassifier

&AtClient
Procedure ClassifierExecute()
	
	ContactInformationManagementClassifiersClient.ImportAddressClassifier();
	
EndProcedure

&AtClient
Procedure CheckFillingCorrectness(Command)
	
	CheckStructure = ContactInformationManagementClassifiers.CheckAddressByAC(PostalCode, State, County, City, Settlement, Street, Building);
	
	If CheckStructure.HasErrors Then
		
		ClearMessages();
		For Each Item In CheckStructure.ErrorsStructure Do
			
			CommonUseClientServer.MessageToUser(Item.Value, , Item.Key);
			
		EndDo;	
		
	Else
		
		DoMessageBox(NStr("en = 'The address format is correct.'"));
		
	EndIf;	
		
EndProcedure

&AtClient
Procedure HideObsoleteAddresses(Command)

	HideObsoleteAddresses = Not HideObsoleteAddresses;
	Items.HideObsoleteAddresses.Check = HideObsoleteAddresses;
	
EndProcedure

// End StandardSubsystems.AddressClassifier


////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

&AtClient
Function GetItemLevel(Item)
	
	If Item = Items.State Then
		Return 1;
		
	ElsIf Item = Items.County Then
		Return 2;
		
	ElsIf Item = Items.City Then
		Return 3;
		
	ElsIf Item = Items.Settlement Then
		Return 4;
		
	ElsIf Item = Items.Street Then
		Return 5;
		
	Else
		Return 0;
	EndIf;
		
EndFunction

&AtClient
Procedure GeneratePresentation()
	
	Presentation = "";
	
	AddressStructure = GetAddressStructure();
	AddressStructure.Insert("Country", ?(Country <> HomeCountry, Country, Undefined));
	AddressStructure.Insert("CountryDescription", ?(Country <> HomeCountry, CountryDescription, ""));
	AddressStructure.Insert("AppartmentType",	AppartmentType);
	AddressStructure.Insert("KindDescription", KindDescription);
	AddressStructure.Insert("Presentation", Presentation);
	
	PresentationWithKind = ContactInformationManagementClientServer.GenerateAddressPresentation(AddressStructure
	, Presentation, KindDescription);
	
EndProcedure

&AtServer
Procedure ReadParameterValues()
	
	Presentation = Parameters.Presentation;
	KindDescription = String(Parameters.Kind);
	
	For Each AddressItem In Parameters.FieldValues Do
		// There is a special handler for handling Country because Country is a reference
		If AddressItem.Presentation = "Country" Then
			Country = Catalogs.WorldCountries.FindByDescription(AddressItem.Value);
		Else
			ThisForm[AddressItem.Presentation] = AddressItem.Value;
		EndIf;
	EndDo;
	
EndProcedure

&AtClient
Procedure AddFieldValue(Value, FieldName)
	
	If ValueIsFilled(Value) Then
		FieldValues.Add(Value, FieldName);
	EndIf;
	
EndProcedure

&AtClient
Function GetEditResult()

	FieldValues.Clear();
	AddFieldValue(PostalCode, "PostalCode");
	AddFieldValue(StateCode, "StateCode");
	AddFieldValue(State, "State");
	AddFieldValue(County, "County");
	AddFieldValue(City, "City");
	AddFieldValue(Settlement, "Settlement");
	AddFieldValue(Street, "Street");
	AddFieldValue(Building, "Building");
	AddFieldValue(Appartment, "Appartment");
	AddFieldValue(CountryDescription, "Country");
	AddFieldValue(CountryCode, "CountryCode");
	
	If Not IsBlankString(Appartment) Then
		AddFieldValue(AppartmentType, "AppartmentType");
	EndIf;
	
	Result = New Structure;
	Result.Insert("FieldValues", FieldValues);
	Result.Insert("Presentation", Presentation);
	
	Return Result;

EndFunction

&AtClient
Procedure CheckFieldTypes()
	
	AppartmentType = ?(ValueIsFilled(AppartmentType), AppartmentType, Items.AppartmentType.ChoiceList[0].Value);
	
EndProcedure

&AtClient
Procedure CheckChoiceButtons()
	
	HasButtons = ClassifiersUsed And (Country = HomeCountry);
	
	Items.State.ChoiceButton = HasButtons;
	Items.County.ChoiceButton = HasButtons;
	Items.City.ChoiceButton = HasButtons;
	Items.Settlement.ChoiceButton = HasButtons;
	Items.Street.ChoiceButton = HasButtons;
	
EndProcedure

&AtServer
Procedure FillCountryCodeAndDescription()
	
	AttributeValues = CommonUse.GetAttributeValues(Country, "Code, Description");
	CountryCode = AttributeValues.Code;
	CountryDescription = AttributeValues.Description;
	
EndProcedure

&AtServerNoContext
Procedure FindCountryByCodeOrDescription(CountryCode, CountryDescription)
	
	Query = New Query;
	Query.SetParameter("CountryCode", CountryCode);
	Query.SetParameter("CountryDescription", CountryDescription);
	
	If IsBlankString(CountryCode) Or IsBlankString(CountryDescription) Then
		Query.Text =
		"SELECT
		|	WorldCountries.Ref AS Country
		|FROM
		|	Catalog.WorldCountries AS WorldCountries
		|WHERE
		|	WorldCountries.Code = &CountryCode";
		If IsBlankString(CountryCode) Then
			Query.Text = StrReplace(Query.Text, "Code", "Description");
		EndIf;
		
	Else
		Query.Text =
		"SELECT TOP 1
		|	Страны.Ref AS Country
		|FROM
		|	(SELECT TOP 1
		|		WorldCountries.Ref AS Ref,
		|		1 AS Order
		|	FROM
		|		Catalog.WorldCountries AS WorldCountries
		|	WHERE
		|		WorldCountries.Code = &CountryCode
		|	
		|	UNION
		|	
		|	SELECT TOP 1
		|		WorldCountries.Ref,
		|		2
		|	FROM
		|		Catalog.WorldCountries AS WorldCountries
		|	WHERE
		|		WorldCountries.Description = &CountryDescription) AS Страны
		|
		|ORDER BY
		|	Страны.Order";
		
	EndIf;
	
	Selection = Query.Execute().Choose();
	Country = ?(Selection.Next(), Selection.Country, Catalogs.WorldCountries.EmptyRef());
	
EndProcedure

&AtClient
Function GetAddressStructure()
	
	AddressStructure = New Structure();
	AddressStructure.Insert("PostalCode", PostalCode);
	AddressStructure.Insert("State", State);
	AddressStructure.Insert("County", County);
	AddressStructure.Insert("City", City);
	AddressStructure.Insert("Settlement", Settlement);
	AddressStructure.Insert("Street", Street);
	AddressStructure.Insert("Building", Building);
	AddressStructure.Insert("Appartment", Appartment);
	Return AddressStructure;
	
EndFunction

&AtClient
Procedure WriteAddressStructure(AddressStructure)
	
	If PostalCode <> AddressStructure.PostalCode Then
		PostalCode = AddressStructure.PostalCode;
	EndIf;
	If State <> AddressStructure.State Then
		State = AddressStructure.State;
	EndIf;
	If County <> AddressStructure.County Then
		County = AddressStructure.County;
	EndIf;
	If City <> AddressStructure.City Then
		City = AddressStructure.City;
	EndIf;
	If Settlement <> AddressStructure.Settlement Then
		Settlement = AddressStructure.Settlement;
	EndIf;
	If Street <> AddressStructure.Street Then
		Street = AddressStructure.Street;
	EndIf;
	If Building <> AddressStructure.Building Then
		Building = AddressStructure.Building;
	EndIf;

	If Appartment <> AddressStructure.Appartment Then
		Appartment = AddressStructure.Appartment;
	EndIf;
	
EndProcedure

&AtServer
Procedure WriteAddressStructureAtServer(AddressStructure)
	
	If PostalCode <> AddressStructure.PostalCode Then
		PostalCode = AddressStructure.PostalCode;
	EndIf;
	If State <> AddressStructure.State Then
		State = AddressStructure.State;
	EndIf;
	If County <> AddressStructure.County Then
		County = AddressStructure.County;
	EndIf;
	If City <> AddressStructure.City Then
		City = AddressStructure.City;
	EndIf;
	If Settlement <> AddressStructure.Settlement Then
		Settlement = AddressStructure.Settlement;
	EndIf;
	If Street <> AddressStructure.Street Then
		Street = AddressStructure.Street;
	EndIf;
	If Building <> AddressStructure.Building Then
		Building = AddressStructure.Building;
	EndIf;

	If Appartment <> AddressStructure.Appartment Then
		Appartment = AddressStructure.Appartment;
	EndIf;
	
EndProcedure

&AtServer
Function GetAddressStructureAtServer()
	
	AddressStructure = New Structure();
	AddressStructure.Insert("PostalCode", PostalCode);
	AddressStructure.Insert("State", State);
	AddressStructure.Insert("County", County);
	AddressStructure.Insert("City", City);
	AddressStructure.Insert("Settlement", Settlement);
	AddressStructure.Insert("Street", Street);
	AddressStructure.Insert("Building", Building);
	AddressStructure.Insert("Appartment", Appartment);
	Return AddressStructure;
	
EndFunction

// StandardSubsystems.AddressClassifier

&AtClient
Procedure SetFieldEnabledByState(ImportedStructure)
	
	If ImportedStructure.State Then
		
		// Disabling fields that the address classifier does not have items for
		Items.County.Enabled 				= ImportedStructure.County;
		Items.City.Enabled 				= ImportedStructure.City;
		Items.Settlement.Enabled	= ImportedStructure.Settlement;
		Items.Street.Enabled 				= ImportedStructure.Street;
		
		// Removing choice buttons of these fields
		Items.County.ChoiceButton				= ImportedStructure.County;
		Items.City.ChoiceButton 			= ImportedStructure.City;
		Items.Settlement.ChoiceButton	= ImportedStructure.Settlement;
		Items.Street.ChoiceButton 			= ImportedStructure.Street;

	Else
		
		// Enabling manual input of address fields
		Items.County.Enabled 				= True;
		Items.City.Enabled 				= True;
		Items.Settlement.Enabled 	= True;
		Items.Street.Enabled 				= True;
		
		// Removing choice buttons
		Items.County.ChoiceButton				= False;
		Items.City.ChoiceButton 			= False;
		Items.Settlement.ChoiceButton	= False;
		Items.Street.ChoiceButton 			= False;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure LoadState(CanImportState = Undefined)
	
	If CanImportState = Undefined Then
		CanImportState = ImportState(State);	
	EndIf;
	
	If Not IsBlankString(State) And CanImportState Then
		
		// Asking the user whether they want to import state addresses from the address classifier
		ImportStateQuestion = NStr("en = 'The address classifier for %State% is not imported.
		| Do you want to import it?'"); 
		ImportStateQuestion = StrReplace(ImportStateQuestion, "%State%", State);
		ButtonList = New ValueList;
		ButtonList.Add("Import");
		ButtonList.Add("Cancel");
		Response = DoQueryBox(ImportStateQuestion, ButtonList);
		If Response = "Import" Then
			PrepareStateAddressClassifierImport(State);
			ContactInformationManagementClassifiersClient.ImportAddressClassifier();
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function ImportState(State)
	
	// Only administrators or users that have the right to add/edit the base referential information can import a state
	If Not Users.RolesAvailable("AddEditBaseReferentialInformation") Then
		Return False;
	EndIf;
	
	// Splitting the state to the description and the abbreviation
	AddressAbbreviation = "";
	StateDescription = ContactInformationManagementClassifiers.GetNameAndAddressAbbreviation(State, AddressAbbreviation);
	
Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	AddressClassifier.Code
	|FROM
	|	InformationRegister.AddressClassifier AS AddressClassifier
	|WHERE
	|	AddressClassifier.AddressItemType = 1
	|	AND AddressClassifier.Description = &StateDescription";
	Query.SetParameter("StateDescription", StateDescription);
	
	If Query.Execute().IsEmpty() Then
		Return False; // Only states from the state list are imported
	Else
		StateImported = ContactInformationManagementClassifiers.AddressItemImported(State);
		Return Not StateImported; // Importing the state if it is not yet imported
	EndIf;
	
EndFunction

&AtServerNoContext
Function FixFields(AddressStructure, Level)
	
	// Retrieving field values from the address structure
	PostalCode = AddressStructure.PostalCode;
	State = AddressStructure.State;
	County = AddressStructure.County;
	City = AddressStructure.City;
	Settlement = AddressStructure.Settlement;
	Street = AddressStructure.Street;
	Building = AddressStructure.Building;
	Appartment = AddressStructure.Appartment;
	
	If Not ContactInformationManagementClassifiers.AddressItemImported(State) Then
		FieldsStructure = New Structure("ErrorsStructure,AddressStructure", New Structure, AddressStructure);
		Return FieldsStructure;
	EndIf;
	
	CheckStructure = ContactInformationManagementClassifiers.CheckAddressByAC(""
	, State, County, City, Settlement, Street, Building);
	
	// Clearing fields that does not meet the address classifier
	If CheckStructure.HasErrors Then
		
		ContactInformationManagementClassifiers.ClearChildsByAddressItemLevel(State, County
		, City, Settlement, Street, Building, Appartment, Level); 
		
	EndIf;	
	
	// Filling or fixing a county, a city, and a settlement
	If Level > 2 And (IsBlankString(County) Or CheckStructure.ErrorsStructure.Property("County")) Then
		County = TrimAll(CheckStructure.County.Description + " " + CheckStructure.County.Abbreviation);	
	EndIf;
	
	If Level > 3 And (IsBlankString(City) Or CheckStructure.ErrorsStructure.Property("City")) Then
		City = TrimAll(CheckStructure.City.Description + " " + CheckStructure.City.Abbreviation);	
	EndIf;
	
	If Level > 4 And (IsBlankString(Settlement) Or CheckStructure.ErrorsStructure.Property("Settlement")) Then
		Settlement = TrimAll(CheckStructure.Settlement.Description + " " 
		+ CheckStructure.Settlement.Abbreviation);	
	EndIf;
	
	// Fixing the postal code
	NewPostalCode = ContactInformationManagementClassifiers.GetPostalCode(State
	, County, City, Settlement, Street, Building);
	
	If Not IsBlankString(NewPostalCode) Then
		PostalCode = NewPostalCode;
	EndIf;
	
	// Updating address structure
	AddressStructure.PostalCode = PostalCode;
	AddressStructure.State = State;
	AddressStructure.County = County;
	AddressStructure.City = City;
	AddressStructure.Settlement = Settlement;
	AddressStructure.Street = Street;
	AddressStructure.Building = Building;
	AddressStructure.Appartment = Appartment;
	
	// Checking one more time and returning the error structure
	CheckStructure = ContactInformationManagementClassifiers.CheckAddressByAC(""
	, State, County, City, Settlement, Street, Building);
	
	CheckStructure.Insert("AddressStructure", AddressStructure);
	
	Return CheckStructure;
	
EndFunction

&AtServerNoContext
Function ImportedFieldsByState(AddressStructure)
	
	If ContactInformationManagementClassifiers.AddressItemImported(AddressStructure.State) Then
		
		ImportedStructure = ContactInformationManagementClassifiers.ImportedAddressItemStructure(
		AddressStructure.State, AddressStructure.County, AddressStructure.City, AddressStructure.Settlement, AddressStructure.Street);
		
		Return ImportedStructure;
		
	Else
		
		Return New Structure("State", False);
		
	EndIf;
	
EndFunction

&AtServerNoContext
Procedure PrepareStateAddressClassifierImport(State)
	
	FieldsStructure = ContactInformationManagementClassifiers.GetAddressClassifierRowByAddressItems(
		State, "", "", "", "");
	AddressObjectArrayToImport = New Array;
	AddressObjectArrayToImport.Add(Format(FieldsStructure.AddressObjectCodeInCode, "ND=2; NLZ="));
	CommonUse.CommonSettingsStorageSave("AddressClassifierDownloadParameters", "StatesToImport"
	, AddressObjectArrayToImport);
	
EndProcedure

&AtServerNoContext
Function AutoCompleteResult(Text, AddressStructure, Level)
	
	ItemImported = ContactInformationManagementClassifiers.AddressItemImported(AddressStructure.State
	, AddressStructure.County, AddressStructure.City, AddressStructure.Settlement, AddressStructure.Street, Level);
	
	If ItemImported Or Level = 1 Then
		Result = ContactInformationManagementClassifiers.AddressItemTextAutoComplete(Text
		, ?(Level > 1, AddressStructure.State, ""), ?(Level > 2, AddressStructure.County, "")
		, ?(Level > 3, AddressStructure.City, ""), ?(Level > 4, AddressStructure.Settlement, ""), Level);
	Else
		Result = Undefined;
	EndIf;
	
	Return Result;
	
EndFunction

&AtServerNoContext
Function ProcessFieldAtServer(AddressStructure, Level)

	FieldsStructure = FixFields(AddressStructure, Level);
	AddressStructure = FieldsStructure.AddressStructure;
	ErrorsStructure = FieldsStructure.ErrorsStructure;
	ImportedStructure = ImportedFieldsByState(AddressStructure);
	CanImportState = ImportState(AddressStructure.State);
	
	ResultStructure = New Structure("ErrorsStructure,ImportedStructure,CanImportState"
	, ErrorsStructure, ImportedStructure, CanImportState);
	
	Return ResultStructure;
	
EndFunction

// End StandardSubsystems.AddressClassifier