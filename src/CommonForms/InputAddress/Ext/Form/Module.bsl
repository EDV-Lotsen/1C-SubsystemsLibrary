
////////////////////////////////////////////////////////////////////////////////
// PROCEDURES - FORM EVENTS HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	ClassifiersUsed = ContactInformationManagementClassifiers.ClassifiersUsed();
	
	If Not ClassifiersUsed Then
		Items.Classifier.Visible = False;
	EndIf;
	
	ReadParameterValues();
	
	PresentationWithView = KindDescription1 + ": " + Presentation;
	Title = KindDescription1;
	
	HomeCountry = Catalogs.WorldCountries.HomeCountry;
	
	If Parameters.AlwaysUseAddressClassifier Then
		Country = HomeCountry;
		Items.Country.Enabled = False;
		
	Else
		
		If Not IsBlankString(CountryCode) OR Not IsBlankString(CountryDescription) Then
			// if country code or description is specified, then find the country
			FindCountryByCodeOrName();
		Else
			Country = HomeCountry;
		EndIf;
	EndIf;
	
	If NOT IsBlankString(Parameters.Title) Then
		AutoTitle = False;
		Title = Parameters.Title;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancellation)
	
	CheckFieldTypes();
	CheckChoiceButtons();
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancellation, StandardProcessing)
	
	If Modified And Not WerePressedClosingButtons Then
		
		QuestionText = NStr("en = 'Data has been changed. Discard the changes?'");
		
		Response = DoQueryBox(QuestionText,  QuestionDialogMode.OKCancel);
		
		If Response = DialogReturnCode.Cancel Then
			Cancellation = True;
		EndIf;
		
	EndIf;
	
EndProcedure



////////////////////////////////////////////////////////////////////////////////
// COUNTRY

&AtClient
Procedure CountryOnChange(Item)
	
	If Not ValueIsFilled(Country) Then
		Country = HomeCountry;
	EndIf;
	
	FillCodeAndDescriptionCountry();
	
	GeneratePresentation();
	CheckChoiceButtons();
	
EndProcedure



////////////////////////////////////////////////////////////////////////////////
// POSTAL CODE

&AtClient
Procedure PostalCodeOnChange(Item)
	
	If (Country = HomeCountry) And ClassifiersUsed Then
		If Not IsBlankString(PostalCode) And (StrLen(PostalCode) = 6) And IsBlankString(Region) And IsBlankString(District) And IsBlankString(City) And IsBlankString(HumanSettlement) And IsBlankString(Street) Then
			FindDataByPostalCode();
		EndIf;
	EndIf;
	
	GeneratePresentation();

EndProcedure

&AtClient
Procedure FindDataByPostalCode()
	
	Result = ContactInformationManagementClassifiers.FindInAddressClassifierRecordsByPostalCode(PostalCode);
	
	Found = Result.Quantity;
	
	If Found = 0 Then
		Return;
		
	ElsIf Found > 1 Then
		// open choice form
		
		SearchFormParameters = New Structure;
		SearchFormParameters.Insert("RegionFound", 		Result.RegionFound);
		SearchFormParameters.Insert("AreaFound",  		Result.AreaFound);
		SearchFormParameters.Insert("AddressInStorage", Result.AddressInStorage);
		
		AddressItemCode = OpenFormModal("CommonForm.FindByPostalCode", SearchFormParameters);
		If AddressItemCode = Undefined Then
			Return;
		EndIf;
		
		Result = New Structure;
		ContactInformationManagementClassifiers.GetItemComponentsByAddressItemCodeToStructure(AddressItemCode, Result);
		
	EndIf;
	
	Region = Result.Region;
	District  = Result.District;
	City  = Result.City;
	HumanSettlement = Result.HumanSettlement;
	Street  = Result.Street;
	
	#If Not WebClient Then
	If Not IsBlankString(Street) Then
		CurrentItem = Items.Street;
	ElsIf Not IsBlankString(HumanSettlement) Then
		CurrentItem = Items.HumanSettlement;
	ElsIf Not IsBlankString(City) Then
		CurrentItem = Items.City;
	ElsIf Not IsBlankString(District) Then
		CurrentItem = Items.District;
	ElsIf Not IsBlankString(Region) Then
		CurrentItem = Items.Region;
	EndIf;
	#EndIf
	
EndProcedure



////////////////////////////////////////////////////////////////////////////////
// BUTTONS OK AND CLOSE

&AtClient
Procedure CommandCancelExecute()
	
	WerePressedClosingButtons = True;
	Close();
	
EndProcedure

&AtClient
Procedure CommandOKExecute()
	
	WerePressedClosingButtons = True;
	Close(GetEditResult());
	
EndProcedure

&AtClient
Procedure ClassifierExecute()
	
	ContactInformationManagementClassifiersClient.LoadAddressClassifier();
	
EndProcedure

&AtClient
Procedure CommandClearExecute()
	
	Modified = True;
	
	Country = HomeCountry;
	CountryOnChange(Items.Country);
	
	PostalCode 		= "";
	Region 			= "";
	District 		= "";
	City 			= "";
	HumanSettlement = "";
	Street 			= "";
	Building 		= "";
	Apartment 		= "";
	BuildingType    = Items.BuildingType.ChoiceList[0].Value;
	CorpusType  	= Items.CorpusType.ChoiceList[0].Value;
	ApartmentType 	= Items.ApartmentType.ChoiceList[0].Value;
	
	GeneratePresentation();
	
EndProcedure



////////////////////////////////////////////////////////////////////////////////
// COMMON EVENTS OF THE INPUT FIELDS

&AtClient
Procedure FieldOnChange(Item)
	
	CheckFieldTypes();
	If ClassifiersUsed And (Country = HomeCountry) And IsBlankString(PostalCode) Then
		PostalCode = ContactInformationManagementClassifiers.GetPostalCode(Region, District, City, HumanSettlement, Street, Building, Corpus);
	EndIf;
	
	GeneratePresentation();
	
EndProcedure

&AtClient
Procedure FieldStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	If (Not ClassifiersUsed) OR (Country <> HomeCountry) Then
		Return;
	EndIf;
	
	Par = New Structure("Region,District,City,HumanSettlement,Street,Level", Region, District, City, HumanSettlement, Street, GetItemLevel(Item));
	
	Result = OpenFormModal("InformationRegister.AddressClassifier.Form.ChoiceForm", Par);
	If Result = Undefined Then
		Return;
	EndIf;
	
	ThisForm[Item.Name] = TrimAll(Result.Description + " " + Result.Abbreviation);
	FieldOnChange(Item);
	Modified = True;
	
EndProcedure

&AtClient
Procedure FieldAutoComplete(Item, Text, ChoiceData, Wait, StandardProcessing)
	
	AutoFillAndInputEndProcessing(Item, Text, ChoiceData, StandardProcessing);
	
EndProcedure

&AtClient
Procedure FieldTextEditEnd(Item, Text, ChoiceData, StandardProcessing)
	
	AutoFillAndInputEndProcessing(Item, Text, ChoiceData, StandardProcessing);
	
EndProcedure

&AtClient
Procedure AutoFillAndInputEndProcessing(Item, Text, ChoiceData, StandardProcessing)
	
	If (Not ClassifiersUsed) OR (IsBlankString(Text)) OR (Country <> HomeCountry) Then
		Return;
	EndIf;
	
	ItemLevel = GetItemLevel(Item);
	Result = ContactInformationManagementClassifiers.AutoCompleteTextInAddressFormItem(Text, Region, District, City, HumanSettlement, ItemLevel);
	
	If Result <> Undefined Then
		StandardProcessing = False;
		ChoiceData = Result;
	EndIf;
	
EndProcedure



////////////////////////////////////////////////////////////////////////////////
// AUXILIARY FUNCTIONS AND PROCEDURES

&AtClient
Function GetItemLevel(Item)
	
	If Item = Items.Region Then
		Return 1;
		
	ElsIf Item = Items.District Then
		Return 2;
		
	ElsIf Item = Items.City Then
		Return 3;
		
	ElsIf Item = Items.HumanSettlement Then
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
	
	If Country <> HomeCountry Then
		SupplementAddressPresentation(CountryDescription, 	", ");
	EndIf;
	SupplementAddressPresentation(TrimAll(PostalCode),      ", ");
	SupplementAddressPresentation(TrimAll(Region),          ", ");
	SupplementAddressPresentation(TrimAll(District),        ", ");
	SupplementAddressPresentation(TrimAll(City),            ", ");
	SupplementAddressPresentation(TrimAll(HumanSettlement), ", ");
	SupplementAddressPresentation(TrimAll(Street),          ", ");
	SupplementAddressPresentation(TrimAll(Building),        ", " + BuildingType    + " # ");
	SupplementAddressPresentation(TrimAll(Corpus),          ", " + CorpusType + " ");
	SupplementAddressPresentation(TrimAll(Apartment),       ", " + ApartmentType + " ");
	
	If StrLen(Presentation) > 2 Then
		Presentation = Mid(Presentation, 3);
	EndIf;
	
	PresentationWithView = KindDescription1 + ": " + Presentation;
	
EndProcedure

&AtServer
Procedure ReadParameterValues()
	
	Presentation    = Parameters.Presentation;
	KindDescription1 = String(Parameters.Kind);
	
	For Each ItemOfAddress In Parameters.FieldValues Do
		ThisForm[ItemOfAddress.Presentation] = ItemOfAddress.Value;
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
	AddFieldValue(PostalCode,			"PostalCode");
	AddFieldValue(Region,              	"Region");
	AddFieldValue(District,             "District");
	AddFieldValue(City,               	"City");
	AddFieldValue(HumanSettlement,     	"HumanSettlement");
	AddFieldValue(Street,               "Street");
	AddFieldValue(Building,             "Building");
	AddFieldValue(Corpus,              	"Corpus");
	AddFieldValue(Apartment,            "Apartment");
	AddFieldValue(CountryDescription,  	"Country");
	AddFieldValue(CountryCode,          "CountryCode");
	
	If Not IsBlankString(Building) Then
		AddFieldValue(BuildingType,     "BuildingType");
	EndIf;
	If Not IsBlankString(Corpus) Then
		AddFieldValue(CorpusType,      	"CorpusType");
	EndIf;
	If Not IsBlankString(Apartment) Then
		AddFieldValue(ApartmentType,   	"ApartmentType");
	EndIf;
	
	Result = New Structure;
	Result.Insert("FieldValues", FieldValues);
	Result.Insert("Presentation", Presentation);
	
	Return Result;

EndFunction

//Procedure supplements address presentation with string
&AtClient
Procedure SupplementAddressPresentation(Addition, ConcatenationString)
	
	If Addition <> "" Then
		Presentation = Presentation + ConcatenationString + Addition;
	EndIf;
	
EndProcedure

&AtClient
Procedure CheckFieldTypes()
	
	BuildingType	= ?(ValueIsFilled(BuildingType),    BuildingType,   Items.BuildingType.ChoiceList[0].Value);
	CorpusType  	= ?(ValueIsFilled(CorpusType),  	CorpusType,  	Items.CorpusType.ChoiceList[0].Value);
	ApartmentType 	= ?(ValueIsFilled(ApartmentType), 	ApartmentType, 	Items.ApartmentType.ChoiceList[0].Value);
	
EndProcedure

&AtClient
Procedure CheckChoiceButtons()
	
	AreButtons = ClassifiersUsed And (Country = HomeCountry);
	
	Items.Region.ChoiceButton          	= AreButtons;
	Items.District.ChoiceButton        	= AreButtons;
	Items.City.ChoiceButton           	= AreButtons;
	Items.HumanSettlement.ChoiceButton 	= AreButtons;
	Items.Street.ChoiceButton           = AreButtons;
	
EndProcedure

&AtServer
Procedure FillCodeAndDescriptionCountry()
	
	AttributeValues = CommonUse.GetAttributeValues(Country, "Code, Description");
	CountryCode = AttributeValues.Code;
	CountryDescription = AttributeValues.Description;
	
EndProcedure

&AtServer
Procedure FindCountryByCodeOrName()
	
	Query = New Query;
	Query.SetParameter("CountryCode", CountryCode);
	Query.SetParameter("CountryDescription", CountryDescription);
	
	If IsBlankString(CountryCode) OR IsBlankString(CountryDescription) Then
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
		|	Countries.Ref AS Country
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
		|		WorldCountries.Description = &CountryDescription) AS Countries
		|
		|ORDER BY
		|	Countries.Order";
		
	EndIf;
	
	Selection = Query.Execute().Choose();
	Country = ?(Selection.Next(), Selection.Country, Catalogs.WorldCountries.EmptyRef());
	
EndProcedure
