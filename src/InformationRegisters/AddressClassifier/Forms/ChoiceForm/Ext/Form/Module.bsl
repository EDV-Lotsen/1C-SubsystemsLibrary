#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetConditionalAppearance();
	
	If Parameters.Property("Autotest") Then // Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
		Return;
	EndIf;
	
	// Analyzing additional parameters
	If ValueIsFilled(Parameters.SettlementClassifierCode) Then
		ParametersStructure = New Structure;
		AddressClassifier.GetComponentsToStructureByAddressItemCode(Parameters.SettlementClassifierCode, ParametersStructure);
		FillPropertyValues(Parameters, ParametersStructure, , "Street");
	EndIf;
	
	If IsBlankString(Parameters.State) And Parameters.Level > 1 Then 
		Parameters.Level = 0;
	EndIf;
	Level = Parameters.Level;
	
	SetFormTitle(Parameters.Level);
	
	// The passed "hide addresses" parameter has priority over general settings. This variable also determines operating mode
	UseSavedSettings = TypeOf(Parameters.HideObsoleteAddresses)<>Type("Boolean");
	
	If UseSavedSettings Then
		// Restoring the Hide obsolete addresses flag value from settings; granting control
		HideObsoleteAddresses = CommonUse.CommonSettingsStorageLoad("ContactInformation.AddressInput", "HideObsoleteAddresses", False);
	Else
		HideObsoleteAddresses = Parameters.HideObsoleteAddresses;
	EndIf;
	
	// Switching command
	Items.HideObsoleteAddresses.Visible = UseSavedSettings;
	Items.HideObsoleteAddresses.Check = HideObsoleteAddresses;
	
	// Obsolete picture column
	Items.DataIsCurrent.Visible = Not UseSavedSettings;
	
	// Alternate name columns
	SetAlternateNameVisibility(Items, DisplayAlternateNames);
	
	// Filtering by input parameters
	For Each KeyValue In GetRestrictionsForLevel(Parameters.Level) Do
		CommonUseClientServer.SetDynamicListFilterItem(List, KeyValue.Key, KeyValue.Value);
	EndDo;
	CommonUseClientServer.SetDynamicListFilterItem(List, "Description", "", DataCompositionComparisonType.NotEqual);
	
	// Setting the current row
	Fields = GetFieldCodeByLevel(Parameters.Level + 1);
	FilterStructure = AddressClassifier.ReturnAddressClassifierStructureByAddressItem(
		Fields.State, Fields.County, Fields.City, Fields.Settlement, Fields.Street
	);
	
	// Determining by code
	CurrentRowCode = Undefined;
	If Level = 1 And Parameters.Property("StateClassifierCode") Then
		CurrentRowCode = Parameters.StateClassifierCode;
		
	ElsIf Level = 2 And Parameters.Property("CountyClassifierCode") Then
		CurrentRowCode = Parameters.CountyClassifierCode;
		
	ElsIf Level = 3 And Parameters.Property("CityClassifierCode") Then
		CurrentRowCode = Parameters.CityClassifierCode;
		
	ElsIf Level = 4 And Parameters.Property("SettlementClassifierCode") Then
		CurrentRowCode = Parameters.SettlementClassifierCode;
		
	ElsIf Level = 5 And Parameters.Property("StreetClassifierCode") Then
		CurrentRowCode = Parameters.StreetClassifierCode;
		
	EndIf;
	
	If FilterStructure.AddressItemType = Parameters.Level Then
		If CurrentRowCode = Undefined Then
			Parameters.CurrentRow = InformationRegisters.AddressClassifier.CreateRecordKey(FilterStructure)
		Else
			Parameters.CurrentRow = RecordKeyByClassifierCode(CurrentRowCode);
		EndIf;
	EndIf;
	
	// Autosave settings
	SavedInSettingsDataModified = True;
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If Level = 0 Then
		// Parent - selection level not defined, nothing to select
		Cancel = True;
		Return;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormsItemEventHandlers

&AtClient
Procedure ListChoice(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	ExecuteChoice();
	
EndProcedure

&AtClient
Procedure ListValueChoice(Item, Value, StandardProcessing)
	
	StandardProcessing = False;
	ExecuteChoice();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure HideObsoleteAddresses(Command)
	If UseSavedSettings Then
		HideObsoleteAddresses = Not HideObsoleteAddresses;
		Items.HideObsoleteAddresses.Check = HideObsoleteAddresses;
		
		CommonUseClientServer.SetDynamicListFilterItem(List, 
			"DataIsCurrentFlag", 0, DataCompositionComparisonType.Equal, NStr("en = 'Data-is-current flag'"), HideObsoleteAddresses);
		ThisObject.RefreshDataRepresentation();
	EndIf;
EndProcedure

&AtClient
Procedure DisplayAlternateNames(Command)
	
	DisplayAlternateNames = Not DisplayAlternateNames;
	SetAlternateNameVisibility(Items, DisplayAlternateNames);
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtClientAtServerNoContext
Procedure SetAlternateNameVisibility(Val FormItems, DisplayAlternateNames)
	
	FormItems.ListDisplayAlternateNames.Check = DisplayAlternateNames;
	FormItems.Advanced.Visible                = DisplayAlternateNames;
	
	// Header visibility depending on column content
	FormItems.List.Header = FormItems.Advanced.Visible And FormItems.GroupAddress.Visible;
EndProcedure

&AtClient
Procedure ExecuteChoice()
	
	CurrentData = Items.List.CurrentData;
	If CurrentData = Undefined Then
		Return;
		
	ElsIf CurrentData.DataIsCurrentFlag<>0 Then
		QuestionText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='%1 %2 is irrelevant.
			     |Do you want to continue?'"), 
			CurrentData.Description, CurrentData.Abbr);
			
		AdditionalParameters = New Structure("CurrentData", CurrentData);
		Notification = New NotifyDescription("MakeChoiceEnd", ThisObject, AdditionalParameters);
		ShowQueryBox(Notification, QuestionText, QuestionDialogMode.YesNo);
		
		Return;
	EndIf;
	
	EndChoice(CurrentData);
EndProcedure

&AtClient
Procedure MakeChoiceEnd(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult<>DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	EndChoice(AdditionalParameters.CurrentData);
EndProcedure

&AtClient
Procedure EndChoice(Val CurrentData)
	Result = GenerateChoiceResultServer(CurrentData, HideObsoleteAddresses, Level, UseSavedSettings);
	
#If WebClient Then
	CloseFlag = CloseOnChoice;
	CloseOnChoice = False;
	NotifyChoice(Result);
	CloseOnChoice = CloseFlag;
#Else
	NotifyChoice(Result);
#EndIf
	
	If (ModalMode Or CloseOnChoice) And IsOpen() Then        
		Close(Result);
	EndIf;
EndProcedure

&AtServer
Function GetFieldCodeByLevel(Level)
	
	Fields = New Structure;
	Fields.Insert("State",       ?(Level <= 1, "", Parameters.State));
	Fields.Insert("County",      ?(Level <= 2, "", Parameters.County));
	Fields.Insert("City",        ?(Level <= 3, "", Parameters.City));
	Fields.Insert("Settlement",  ?(Level <= 4, "", Parameters.Settlement));
	Fields.Insert("Street",      ?(Level <= 5, "", Parameters.Street));
	
	Return Fields;
	
EndFunction

&AtServer
Function GetRestrictionsForLevel(ObjectLevel, Val SettlementClassifierCode = Undefined)
	
	If SettlementClassifierCode = Undefined Then
		SettlementClassifierCode = Parameters.SettlementClassifierCode;
	EndIf;
	
	If ValueIsFilled(SettlementClassifierCode) Then
		// Selecting street
		Restrictions = SettlementDimensions(SettlementClassifierCode);
		Restrictions.Insert("AddressItemType", 5);
	Else
		// Utilizing the parameters that are available globally - address part names and level
		Fields = GetFieldCodeByLevel(ObjectLevel);
		Restrictions = AddressClassifier.ReturnRestrictionStructureByParent(
			Fields.State, Fields.County, Fields.City, Fields.Settlement, Fields.Street, 0, ObjectLevel
		);
		
		// Determine codes by parameters
		CurrentCode = Undefined;
		If Restrictions.Property("AddressObjectCodeInCode") And Parameters.Property("StateClassifierCode", CurrentCode) And ValueIsFilled(CurrentCode) Then
			Restrictions.AddressObjectCodeInCode = SettlementDimensions(CurrentCode).AddressObjectCodeInCode;
		EndIf;
		CurrentCode = Undefined;
		If Restrictions.Property("CountyCodeInCode") And Parameters.Property("CountyClassifierCode", CurrentCode) And ValueIsFilled(CurrentCode) Then
			Restrictions.CountyCodeInCode = SettlementDimensions(CurrentCode).CountyCodeInCode;
		EndIf;
		CurrentCode = Undefined;
		If Restrictions.Property("CityCodeInCode") And Parameters.Property("CityClassifierCode", CurrentCode) And ValueIsFilled(CurrentCode) Then
			Restrictions.CityCodeInCode = SettlementDimensions(CurrentCode).CityCodeInCode;
		EndIf;
		CurrentCode = Undefined;
		If Restrictions.Property("SettlementCodeInCode") And Parameters.Property("SettlementClassifierCode", CurrentCode) And CurrentCode <> Undefined Then
			Restrictions.SettlementCodeInCode = SettlementDimensions(CurrentCode).SettlementCodeInCode;
		EndIf;
		
	EndIf;

	If HideObsoleteAddresses Then
		Restrictions.Insert("DataIsCurrentFlag", 0);
	EndIf;
	
	Return Restrictions;

EndFunction

&AtServerNoContext
Function SettlementDimensions(Val ObjectCode)
	Result = New Structure;
	
	// skipping House, Data-is-current flag, Street
	FullCode  = Int(ObjectCode/(10000 * 100 * 10000));
	
	// Settlement
	Result.Insert("SettlementCodeInCode", FullCode % 1000);
	FullCode = Int(FullCode/1000);
	
	// City
	Result.Insert("CityCodeInCode", FullCode % 1000);
	FullCode = Int(FullCode/1000);
	
	// County
	Result.Insert("CountyCodeInCode", FullCode % 1000);
	FullCode = Int(FullCode/1000);
	
	// State
	Result.Insert("AddressObjectCodeInCode", FullCode);
	
	Return Result;
EndFunction

&AtServer
Procedure SetFormTitle(Level)
	If Level = 1 Then
		Title = NStr("en = 'Select state'");
	ElsIf Level = 2 Then
		Title = NStr("en = 'Select county'");
	ElsIf Level = 3 Then
		Title = NStr("en = 'Select city'");
	ElsIf Level = 4 Then
		Title = NStr("en = 'Select settlement'");
	ElsIf Level = 5 Then
		Title = NStr("en = 'Select street'");
	EndIf;
EndProcedure

&AtServerNoContext
Function GenerateChoiceResultServer(CurrentData, HideObsoleteAddresses, Level, UseSavedSettings)
	
	// Data from the current list row passed via parameters    
	Result = New Structure("Description, Abbr, DataIsCurrentFlag, Code");
	FillPropertyValues(Result, CurrentData);
	Result.Insert("StateCode", CurrentData.AddressObjectCodeInCode);
	
	// Form attributes passed via parameters
	Result.Insert("HideObsoleteAddresses", HideObsoleteAddresses);
	Result.Insert("Level", Level);
	
	// Calculated
	Result.Insert("Presentation", TrimAll( 
		?(IsBlankString(Result.Description), "", TrimAll(Result.Description) + " " + TrimAll(Result.Abbr))));
	Result.Insert("FullDescr", Result.Presentation);
	
	// Address structure
	AddressStructure = AddressClassifier.AddressStructure(Result.Code);
	
	If UseSavedSettings Then
		AddressStructure.Insert("HideObsoleteAddresses", 
			CommonUse.CommonSettingsStorageLoad("ContactInformation.AddressInput", "HideObsoleteAddresses", False));
	EndIf;
	
	FieldStructure = FixFields(AddressStructure, Level);
	
	AddressStructure.Insert("ErrorsStructure",      FieldStructure.ErrorsStructure);
	AddressStructure.Insert("ImportedStructure", ImportedFieldsByState(AddressStructure));
	AddressStructure.Insert("CanImportState", LoadState(AddressStructure.State));
	
	Result.Insert("AddressStructure", AddressStructure);
	Return Result;
EndFunction

&AtServerNoContext
Function FixFields(AddressStructure, Level)
	
	// Getting fields from the address structure
	PostalCode = AddressStructure.PostalCode;
	State = AddressStructure.State;
	County = AddressStructure.County;
	City = AddressStructure.City;
	Settlement = AddressStructure.Settlement;
	Street = AddressStructure.Street;
	Building = AddressStructure.Building;
	Unit = AddressStructure.Unit;
	Apartment = AddressStructure.Apartment;
	
	If Not AddressClassifier.AddressItemImported(State) Then
		FieldStructure = New Structure("ErrorsStructure,AddressStructure", New Structure, AddressStructure);
		Return FieldStructure;
	EndIf;
	
	CheckStructure = AddressClassifier.CheckAddressByAC(
		"", State, County, City, Settlement, Street, Building, Unit);
	
	// Clearing inappropriate fields
	If CheckStructure.HasErrors Then
		AddressClassifier.ClearChildsByAddressItemLevel(
			State, County, City, Settlement, Street, Building, Unit, Apartment, Level);
	EndIf;
	
	// Filling or editing the interim fields
	If Level > 2 And (IsBlankString(County) Or CheckStructure.ErrorsStructure.Property("County")) Then
		County = TrimAll(CheckStructure.County.Description + " " + CheckStructure.County.Abbr);	
	EndIf;
	
	If Level > 3 And (IsBlankString(City) Or CheckStructure.ErrorsStructure.Property("City")) Then
		City = TrimAll(CheckStructure.City.Description + " " + CheckStructure.City.Abbr);	
	EndIf;
	
	If Level > 4 And (IsBlankString(Settlement) Or CheckStructure.ErrorsStructure.Property("Settlement")) Then
		Settlement = TrimAll(CheckStructure.Settlement.Description + " " 
		                 + CheckStructure.Settlement.Abbr);
	EndIf;
	
	// Editing index
	NewPostalCode = AddressClassifier.AddressPostalCode(State, 
		County, City, Settlement, Street, Building, Unit);
	
	If Not IsBlankString(NewPostalCode) Then
		PostalCode = NewPostalCode;
	EndIf;
	
	// Updating the address structure
	AddressStructure.PostalCode = PostalCode;
	AddressStructure.State = State;
	AddressStructure.County = County;
	AddressStructure.City = City;
	AddressStructure.Settlement = Settlement;
	AddressStructure.Street = Street;
	AddressStructure.Building = Building;
	AddressStructure.Unit = Unit;
	AddressStructure.Apartment = Apartment;
	
	// Rechecking and returning the error structure
	CheckStructure = AddressClassifier.CheckAddressByAC(
		"", State, County, City, Settlement, Street, Building, Unit);
	
	CheckStructure.Insert("AddressStructure", AddressStructure);
	Return CheckStructure;
	
EndFunction

&AtServerNoContext
Function LoadState(State)
	
	// State data can only be imported by administrators, or by users permitted to create/edit basic regulatory data
	If Not Users.RolesAvailable("AddEditCommonBasicRegulatoryData") Then
		Return False;
	EndIf;
	
	// Breaking the state name into description and abbreviation
	AddressAbbreviation = "";
	StateDescription = AddressClassifier.NameAndAddressAbbreviation(State, AddressAbbreviation);
	
	Query = New Query;
	Query.Text = "SELECT TOP 1
	|	AddressClassifier.Code AS Code
	|FROM
	|	InformationRegister.AddressClassifier AS AddressClassifier
	|WHERE
	|	AddressClassifier.AddressItemType = 1
	|	AND AddressClassifier.Description = &StateDescription";
	Query.SetParameter("StateDescription", StateDescription);
	
	If Query.Execute().IsEmpty() Then
		Return False; // Only states present in the state list are imported.
	Else
		StateImported = AddressClassifier.AddressItemImported(State);
		Return Not StateImported; // Importing state if it was not imported yet.
	EndIf;
	
EndFunction

&AtServerNoContext
Function ImportedFieldsByState(AddressStructure)
	
	If AddressClassifier.AddressItemImported(AddressStructure.State) Then
		ImportedStructure = AddressClassifier.ImportedAddressItemStructure(
		AddressStructure.State, AddressStructure.County, AddressStructure.City, AddressStructure.Settlement, AddressStructure.Street);
		Return ImportedStructure;
		
	Else
		Return New Structure("State", False);
		
	EndIf;
	
EndFunction

&AtServerNoContext
Function RecordKeyByClassifierCode(Val Code)
	
	DimensionString = "AddressItemType, AddressObjectCodeInCode, CountyCodeInCode, CityCodeInCode, SettlementCodeInCode, StreetCodeInCode, Code";
	
	Query = New Query("
		|SELECT TOP 1 
		|	" + DimensionString + "
		|FROM
		|	InformationRegister.AddressClassifier
		|WHERE
		|	Code = &Code
		|");
		
	Query.SetParameter("Code", Code);
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		DimensionValues = New Structure(DimensionString);
		FillPropertyValues(DimensionValues, Selection);
		Return InformationRegisters.AddressClassifier.CreateRecordKey(DimensionValues);
	EndIf;
	
	Return Undefined;
EndFunction

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearanceItems = List.ConditionalAppearance.Items;
	
	ConditionalAppearanceItems.Clear();
	
	Item = ConditionalAppearanceItems.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField("Advanced");

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Advanced");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Filled;

	Item.Appearance.SetParameterValue("TextColor", New Color(128,128,128));
	
EndProcedure

#EndRegion