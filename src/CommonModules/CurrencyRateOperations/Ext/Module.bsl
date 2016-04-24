////////////////////////////////////////////////////////////////////////////////
// Currency subsystem
// 
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// Adds currencies from the classifier to the currency catalog.
//
// Parameters:
//   Codes - Array - added currency numeric codes.
//
// Returns:
//   Array, CatalogRef.Currencies - references to established currencies.
//
Function AddCurrenciesByCode(Val Codes) Export
	Var XMLClassifier, ClassifierTable, CCRecord, NewRow, Result;
	XMLClassifier = Catalogs.Currencies.GetTemplate("CurrencyClassifier").GetText();
	
	ClassifierTable = CommonUse.ReadXMLToTable(XMLClassifier).Data;
	
	Result = New Array();
	
	For Each Code In Codes Do
		CCRecord = ClassifierTable.Find(Code, "Code"); 
		If CCRecord = Undefined Then
			Continue;
		EndIf;
		
		CurrencyRef = Catalogs.Currencies.FindByCode(CCRecord.Code);
		If CurrencyRef.IsEmpty() Then
			NewRow = Catalogs.Currencies.CreateItem();
			NewRow.Code            = CCRecord.Code;
			NewRow.Description     = CCRecord.CodeSymbol;
			NewRow.LongDescription = CCRecord.Name;
			If CCRecord.RBCLoading Then
				NewRow.RateSettingMethod = Enums.CurrencyRateSettingMethods.ImportFromInternet;
			Else
				NewRow.RateSettingMethod = Enums.CurrencyRateSettingMethods.ManualInput;
			EndIf;
			NewRow.InWordParametersInHomeLanguage = CCRecord.NumerationItemOptions;
			NewRow.Write();
			Result.Add(NewRow.Ref);
		Else
			Result.Add(CurrencyRef);
		EndIf
	EndDo; 
	
	Return	Result;
	
EndFunction

// Returns currency rate for the date.
//
// Parameters:
//   Currency    - CatalogRef.Currencies - The currency for which the rate is acquired.
//   RateDate    - Date                  - The date for which the rate is acquired.
//
// Returns: 
//   Structure - Rate parameters.
//       * Rate                 - Number                - Currency rate for the specified date.
//       * UnitConversionFactor - Number                - Currency unit conversion factor for
//                                                        the specified date.
//       * Currency             - CatalogRef.Currencies - Currency ref.
//       * RateDate             - Date                  - Rate acquisition date.
//
Function GetCurrencyRate(Currency, RateDate) Export
	
	Result = InformationRegisters.CurrencyRates.GetLast(RateDate, New Structure("Currency", Currency));
	
	Result.Insert("Currency", Currency);
	Result.Insert("RateDate", RateDate);
	
	Return Result;
	
EndFunction

// Generates the amount in words in the specified currency.
//
// Parameters:
//   AmountAsNumber            - Number                - the amount to be submitted in words.
//   Currency                  - CatalogRef.Currencies - the currency in which the amount 
//                                                       should be provided.
//   DisplayAmountWithoutCents - Boolean               - a flag that shows that the amount is 
//                                                       submitted without cents.
//
// Returns:
//   String - amount in words.
//
Function GenerateAmountInWords(AmountAsNumber, Currency, DisplayAmountWithoutCents = False) Export
	
	Amount = ?(AmountAsNumber < 0, -AmountAsNumber, AmountAsNumber);
	ObjectParameters = CommonUse.ObjectAttributeValues(Currency, "InWordParametersInHomeLanguage");
	
	Result = NumberInWords(Amount, " L=en_EN;FS=False", ObjectParameters.InWordParametersInHomeLanguage);
	
	If DisplayAmountWithoutCents And Int(Amount) = Amount Then
		Result = Left(Result, Find(Result, "0") - 1);
	EndIf;
	
	Return Result;
	
EndFunction

// Converts the amount from one currency to another.
//
// Parameters:
//  Amount           - Number                - the amount to be converted;
//  OriginalCurrency - CatalogRef.Currencies - currency to be converted;
//  NewCurrency      - CatalogRef.Currencies - currency into which to convert;
//  Date             - Date                  - currency rate date.
//
// Returns:
//  Number - converted amount.
//
Function ConvertToCurrency(Amount, OriginalCurrency, NewCurrency, Date) Export
	
	Return CurrencyRateOperationsClientServer.ConvertAtRate(Amount,
		GetCurrencyRate(OriginalCurrency, Date),
		GetCurrencyRate(NewCurrency, Date));
		
EndFunction

// Imports currency rates for the current date.
//
// Parameters:
//  ImportParameters - Structure - import details:
//   * BeginOfPeriod     - Date       - import period start;
//   * EndOfPeriod       - Date       - import period end;
//   * CurrencyList      - ValueTable - currencies to be imported:
//     ** Currency     - CatalogRef.Currencies;
//     ** CurrencyCode - String.
//  ResultAddress      - String    - a temporary storage address to store import results.
//
Procedure ImportActualRate(ImportParameters = Undefined, ResultAddress = Undefined) Export
	
	If CommonUseCached.DataSeparationEnabled() Then
		Raise NStr("en = 'Invalid procedure call ImportActualRate'");
	EndIf;
	
	CommonUse.ScheduledJobOnStart();
	
	EventName = NStr("en = 'Currencies.Currency rate import'",
		CommonUseClientServer.DefaultLanguageCode());
	
	WriteLogEvent(EventName, EventLogLevel.Information, , ,
		NStr("en = 'The scheduled currency rate import is started'"));
	
	CurrentDate = CurrentSessionDate();
	
	ImportState = Undefined;
	ErrorsOccurredOnImport = Undefined;
	
	If ImportParameters = Undefined Then
		ImportParameters = New Structure;
		ImportParameters.Insert("BeginOfPeriod", CurrentDate);
		ImportParameters.Insert("EndOfPeriod", CurrentDate);
		ImportParameters.Insert("CurrencyList", CurrenciesImportedFromInternet());
	EndIf;
		
	Result = CurrencyRateOperationsClientServer.ImportCurrencyRatesByParameters(ImportParameters.CurrencyList,
		ImportParameters.BeginOfPeriod, ImportParameters.EndOfPeriod, ErrorsOccurredOnImport);
		
	If ResultAddress <> Undefined Then
		PutToTempStorage(Result, ResultAddress);
	EndIf;

	If ErrorsOccurredOnImport Then
		WriteLogEvent(
			EventName,
			EventLogLevel.Error,
			, 
			,
			NStr("en = 'Errors occured during the scheduled currency rate import'"));
	Else
		WriteLogEvent(
			EventName,
			EventLogLevel.Information,
			,
			,
			NStr("en = 'The scheduled currency rate import is completed.'"));
	EndIf;
	
EndProcedure

#EndRegion

#Region InternalInterface

// See the description of this procedure in the StandardSubsystemsServer module.
Procedure InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers) Export
	
	// CLIENT HANDLERS.
	
	ClientHandlers["StandardSubsystems.BaseFunctionality\AfterStart"].Add(
		"CurrencyRateOperationsClient");
	
	// SERVER HANDLERS
	
	ServerHandlers["StandardSubsystems.InfobaseVersionUpdate\OnAddUpdateHandlers"].Add(
		"CurrencyRateOperations");
	
	ServerHandlers["StandardSubsystems.BaseFunctionality\OnAddReferenceSearchException"].Add(
		"CurrencyRateOperations");
	
	ServerHandlers["StandardSubsystems.BaseFunctionality\OnAddClientParametersOnStart"].Add(
		"CurrencyRateOperations");
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaSOperations.JobQueue") Then
		ServerHandlers["StandardSubsystems.SaaSOperations.JobQueue\OnDetermineScheduledJobsUsed"].Add(
			"CurrencyRateOperations");
	EndIf;
	
	ServerHandlers["StandardSubsystems.BaseFunctionality\OnFillPermissionsToAccessExternalResources"].Add(
		"CurrencyRateOperations");
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Internal event handlers of SL subsystems

// Fills the parameters that are used by the client code on configuration start.
//
// Parameters:
//   Parameters - Structure - Start parameters.
//
Procedure OnAddClientParametersOnStart(Parameters) Export
	
	If CommonUseCached.DataSeparationEnabled() Then
		RatesAreUpdatedByResponsible = False; // SaaS are updated automatically.
	ElsIf Not AccessRight("Update", Metadata.InformationRegisters.CurrencyRates) Then
		RatesAreUpdatedByResponsible = False; // Users can not update currency rates.
	Else
		RatesAreUpdatedByResponsible = RatesAreImportedFromInternet(); // There are currencies whose rates can be imported.
	EndIf;
	
	CurrencyRateOperationsOverridable.OnDetermineWhetherToDisplayObsoleteCurrencyRateWarnings(RatesAreUpdatedByResponsible);
	
	Parameters.Insert("Currencies", New FixedStructure("RatesAreUpdatedByResponsible", RatesAreUpdatedByResponsible));
	
EndProcedure

// Fills the array with the list of names of metadata objects that might include references to
// other metadata objects, but these references are ignored in the business logic of the
// application.
//
// Parameters:
//  Array - array of strings, for example, "InformationRegister.ObjectVersions".
//
Procedure OnAddReferenceSearchException(Array) Export
	
	Array.Add(Metadata.InformationRegisters.CurrencyRates.FullName());
	
EndProcedure

// Adds scheduled SaaS subsystem jobs to the data table.
//
// Parameters:
//   UsageTable - ValueTable - Scheduled job table.
//      * ScheduledJob - String  - The name of a predefined scheduled job.
//      * Use          - Boolean - True if the scheduled job
//                                 must be executed in SaaS mode.
//
Procedure OnDetermineScheduledJobsUsed(UsageTable) Export
	
	NewRow = UsageTable.Add();
	NewRow.ScheduledJob = "CurrencyRateImport";
	NewRow.Use = False;
	
EndProcedure

// Fills a list of requests for external permissions that must be granted when an infobase is created or an application is updated.
//
// Parameters:
//  PermissionRequests - Array - list of values returned by
//                      SafeMode.RequestToUseExternalResources().
//
Procedure OnFillPermissionsToAccessExternalResources(PermissionRequests) Export
	
	If CommonUseCached.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	PermissionRequests.Add(
		SafeMode.RequestToUseExternalResources(Permissions()));
	
EndProcedure

// Returns a list of permissions to import currency rates from the Internet.
//
// Returns:
//  Array.
//
Function Permissions()
	
	Protocol = "HTTP";
	//PARTIALLY_DELETED
	//Address = "cbrates.rbc.ru";
	Address = "";
	Port = Undefined;
	Description = NStr("en = 'Import currency rates from the Internet.'");
	
	Permissions = New Array;
	Permissions.Add( 
		SafeMode.PermissionToUseInternetResource(Protocol, Address, Port, Description)
	);
	
	Return Permissions;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Export internal procedures and functions

// Copies all the data from the base currency data register
// to the subordinate currency data register (period, rate unit conversion factor).
//
// Parameters
//  SourceCurrency   - Catalogs.Currencies - reference to the base currency,
//                     from whose data register data is to be copied
//  TargetCurrency - Catalogs.Currencies - a reference to the currency dependent on 
//                     the base currency to whose data register is to be copied
//
Procedure WriteInfoForSubordinateRegister(SourceCurrency, TargetCurrency) Export
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	CurrencyRates.Period,
	|	CurrencyRates.Currency,
	|	CurrencyRates.Rate,
	|	CurrencyRates.UnitConversionFactor
	|FROM
	|	InformationRegister.CurrencyRates AS CurrencyRates
	|WHERE
	|	CurrencyRates.Currency = &SourceCurrency";
	Query.SetParameter("SourceCurrency", SourceCurrency);
	
	Selection = Query.Execute().Select();
	
	RecordSet = InformationRegisters.CurrencyRates.CreateRecordSet();
	RecordSet.Filter.Currency.Set(TargetCurrency, True);
	
	Margin = TargetCurrency.Margin;
	
	While Selection.Next() Do
		
		NewRateSetRecord = RecordSet.Add();
		NewRateSetRecord.Currency  = TargetCurrency;
		NewRateSetRecord.UnitConversionFactor = Selection.UnitConversionFactor;
		NewRateSetRecord.Rate      = Selection.Rate + Selection.Rate * Margin / 100;
		NewRateSetRecord.Period    = Selection.Period;
		
	EndDo;
	
	RecordSet.AdditionalProperties.Insert("DisableDependentCurrencyControl", True);
	RecordSet.Write();
	
EndProcedure

// Checks the existence of the specified currency rate and currency unit conversion factor 
// for January 1, 1980.
// If currency rate and currency unit conversion factor are not specified they are set to one.
//
// Parameters:
//  Currency - a reference to a Currency catalog item
//
Procedure CheckCurrencyRateFor01_01_1980(Currency) Export
	
	RateDate = Date("19800101");
	RateStructure = InformationRegisters.CurrencyRates.GetLast(RateDate, New Structure("Currency", Currency));
	
	If (RateStructure.Rate = 0) Or (RateStructure.UnitConversionFactor = 0) Then
		RecordSet = InformationRegisters.CurrencyRates.CreateRecordSet();
		RecordSet.Filter.Currency.Set(Currency);
		Write = RecordSet.Add();
		Write.Currency = Currency;
		Write.Period = RateDate;
		Write.Rate = 1;
		Write.UnitConversionFactor = 1;
		RecordSet.AdditionalProperties.Insert("IgnoreChangeProhibitionCheck");
		RecordSet.Write();
	EndIf;
	
EndProcedure

// Imports currency rate data Currency from the PathToFile file 
// to the currency rate data register. The rate file is parsed and
// the data that meet the period are recorded (ImportPeriodBegin, ImportPeriodEnd).
//
Function ImportCurrencyRateFromFile(Val Currency, Val PathToFile, Val ImportPeriodBegin, Val ImportPeriodEnd) Export
	
	ImportStatus = 1;
	
	ImportedDaysNumberTotal = 1 + (ImportPeriodEnd - ImportPeriodBegin) / ( 24 * 60 * 60);
	
	ImportedDaysNumber = 0;
	
	If IsTempStorageURL(PathToFile) Then
		FileName = GetTempFileName();
		BinaryData = GetFromTempStorage(PathToFile);
		BinaryData.Write(FileName);
	Else
		FileName = PathToFile;
	EndIf;
	
	Text = New TextDocument();
	
	RegisterCurrencyRates = InformationRegisters.CurrencyRates;
	
	Text.Read(FileName, TextEncoding.ANSI);
	LineCount = Text.LineCount();
	
	For Ind = 1 To LineCount Do
		
		Str = Text.GetLine(Ind);
		If (Str = "") Or (Find(Str,Chars.Tab) = 0) Then
			Continue;
		EndIf;
		
		If ImportPeriodBegin = ImportPeriodEnd Then
			RateDate = ImportPeriodEnd;
		Else
			RateDateStr = ExtractSubstring(Str);
			RateDate    = Date(Left(RateDateStr,4), Mid(RateDateStr,5,2), Mid(RateDateStr,7,2));
		EndIf;
		
		UnitConversionFactor = Number(ExtractSubstring(Str));
		Rate                 = Number(ExtractSubstring(Str));
		
		If RateDate > ImportPeriodEnd Then
			Break;
		EndIf;
		
		If RateDate < ImportPeriodBegin Then 
			Continue;
		EndIf;
		
		WriteCurrencyRate = RegisterCurrencyRates.CreateRecordManager();
		
		WriteCurrencyRate.Currency  = Currency;
		WriteCurrencyRate.Period    = RateDate;
		WriteCurrencyRate.Rate      = Rate;
		WriteCurrencyRate.UnitConversionFactor = UnitConversionFactor;
		WriteCurrencyRate.Write();
		
		ImportedDaysNumber = ImportedDaysNumber + 1;
	EndDo;
	
	If IsTempStorageURL(PathToFile) Then
		DeleteFiles(FileName);
		DeleteFromTempStorage(PathToFile);
	EndIf;
	
	If ImportedDaysNumberTotal = ImportedDaysNumber Then
		ImportDescription = "";
	ElsIf ImportedDaysNumber = 0 Then
		ImportDescription = NStr("en = 'Currency rates %1 - %2 are not imported. No data.'");
	Else
		ImportDescription = NStr("en = 'Not all currency rates %1 - %2 are imported.'");
	EndIf;
	
	ImportDescription = StringFunctionsClientServer.SubstituteParametersInString(
									ImportDescription,
									Currency.Code,
									Currency.Description);
	
	UserMessages = GetUserMessages(True);
	ErrorList = New Array;
	For Each UserMessage In UserMessages Do
		ErrorList.Add(UserMessage.Text);
	EndDo;
	ErrorList = CommonUseClientServer.CollapseArray(ErrorList);
	ImportDescription = ?(IsBlankString(ImportDescription), "", Chars.LF) + StringFunctionsClientServer.StringFromSubstringArray(ErrorList, Chars.LF);
	
	Return ImportDescription;
	
EndFunction

// Returns a currency array whose rates are imported from the Internet
//
Function GetCurrenciesToBeImportedArray() Export
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	Currencies.Ref AS Ref
	|FROM
	|	Catalog.Currencies AS Currencies
	|WHERE
	|	Currencies.RateSettingMethod = VALUE(Enum.CurrencyRateSettingMethods.ImportFromInternet)
	|	AND Not Currencies.DeletionMark
	|
	|ORDER BY
	|	Currencies.LongDescription";

	Return Query.Execute().Unload().UnloadColumn("Ref");
	
EndFunction

// Returns currency rate data on the basis of a currency reference.
// Data is returned as a structure.
//
// Parameters:
// SelectedCurrency - Catalog.Currencies / Ref - a reference
//                    to the currency whose rate data is acquired
//
// Returns:
// RateData   - the structure that contains the latest available rate data
//
Function FillCurrencyRateData(SelectedCurrency) Export
	
	RateData = New Structure("RateDate, Rate, UnitConversionFactor");
	
	Query = New Query;
	
	Query.Text = "SELECT RegRates.Period, RegRates.Rate, RegRates.UnitConversionFactor
	              | FROM InformationRegister.CurrencyRates.SliceLast(&ImportPeriodEnd, Currency = &SelectedCurrency) AS RegRates";
	Query.SetParameter("SelectedCurrency", SelectedCurrency);
	Query.SetParameter("ImportPeriodEnd", CurrentSessionDate());
	
	SelectionRate = Query.Execute().Select();
	SelectionRate.Next();
	
	RateData.RateDate = SelectionRate.Period;
	RateData.Rate     = SelectionRate.Rate;
	RateData.UnitConversionFactor = SelectionRate.UnitConversionFactor;
	
	Return RateData;
	
EndFunction

// Returns a value table - currencies that depend on the passed currency as a parameter.
//
// Returns
// ValueTable
// the Link column - CatalogRef.Currencies
// the Margin column - Number
//
Function GetDependentCurrencyList(BaseCurrency, AdditionalProperties = Undefined) Export
	Cache = (TypeOf(AdditionalProperties) = Type("Structure"));
	
	If Cache Then
		
		DependentCurrencies = AdditionalProperties.DependentCurrencies.Get(BaseCurrency);
		
		If TypeOf(DependentCurrencies) = Type("ValueTable") Then
			Return DependentCurrencies;
		EndIf;
		
	EndIf;
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	CurrencyCatalog.Ref,
	|	CurrencyCatalog.Margin,
	|	CurrencyCatalog.RateSettingMethod,
	|	CurrencyCatalog.RateCalculationFormula
	|FROM
	|	Catalog.Currencies AS CurrencyCatalog
	|WHERE
	|	(CurrencyCatalog.MainCurrency = &BaseCurrency
	|			OR CurrencyCatalog.RateCalculationFormula LIKE &AlphabeticCode)";
	
	Query.SetParameter("BaseCurrency", BaseCurrency);
	Query.SetParameter("AlphabeticCode", "%" + CommonUse.ObjectAttributeValue(BaseCurrency, "Description") + "%");
	
	DependentCurrencies = Query.Execute().Unload();
	
	If Cache Then
		
		AdditionalProperties.DependentCurrencies.Insert(BaseCurrency, DependentCurrencies);
		
	EndIf;
	
	Return DependentCurrencies;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Infobase update

// Adds update handlers that are required by the subsystem.
//
// Parameters:
//  Handlers - ValueTable - see the description of NewUpdateHandlerTable function in the InfobaseUpdate common module.
// 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version = "1.0.5.9";
	Handler.Procedure = "CurrencyRateOperations.UpdateInWordsInHomeLanguageStorageFormat";
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.4.4";
	Handler.Procedure = "CurrencyRateOperations.Update937CurrencyData";
	Handler.ExecutionMode = "Exclusive";
	
	Handler = Handlers.Add();
	Handler.Version = "2.2.3.10";
	Handler.Procedure = "CurrencyRateOperations.FillCurrencyRateSettingMethod";
	Handler.ExecutionMode = "Exclusive";
	
EndProcedure

// In words storage format refresh handler on transition to a more modern SL version
//
Procedure UpdateInWordsInHomeLanguageStorageFormat() Export
	
	CurrencySelection = Catalogs.Currencies.Select();
	
	While CurrencySelection.Next() Do
		Object = CurrencySelection.GetObject();
		ParameterString = StrReplace(Object.InWordParametersInHomeLanguage, ",", Chars.LF);
		Sort1 = Lower(Left(TrimAll(StrGetLine(ParameterString, 4)), 1));
		Sort2 = Lower(Left(TrimAll(StrGetLine(ParameterString, 8)), 1));
		Object.InWordParametersInHomeLanguage = 
					  TrimAll(StrGetLine(ParameterString, 1)) + ", "
					+ TrimAll(StrGetLine(ParameterString, 2)) + ", "
					+ TrimAll(StrGetLine(ParameterString, 3)) + ", "
					+ Sort1 + ", "
					+ TrimAll(StrGetLine(ParameterString, 5)) + ", "
					+ TrimAll(StrGetLine(ParameterString, 6)) + ", "
					+ TrimAll(StrGetLine(ParameterString, 7)) + ", "
					+ Sort2 + ", "
					+ TrimAll(StrGetLine(ParameterString, 9));
		InfobaseUpdate.WriteData(Object);
	EndDo;
	
EndProcedure

// Updates additional currency data according to the latest Currency classifier.
//
Procedure Update937CurrencyData() Export
	Currency = Catalogs.Currencies.FindByCode("937");
	If Not Currency.IsEmpty() Then
		Currency = Currency.GetObject();
		Currency.Description = "VEF";
		Currency.LongDescription = NStr("en = 'Bolivar'");
		InfobaseUpdate.WriteData(Currency);
	EndIf;
EndProcedure

// Fills the RateSettingMethod attribute in Currency catalog items.
Procedure FillCurrencyRateSettingMethod() Export
	Selection = Catalogs.Currencies.Select();
	While Selection.Next() Do
		Currency = Selection.Ref.GetObject();
		If Currency.ImportFromInternet Then
			Currency.RateSettingMethod = Enums.CurrencyRateSettingMethods.ImportFromInternet;
		ElsIf Not Currency.MainCurrency.IsEmpty() Then
			Currency.RateSettingMethod = Enums.CurrencyRateSettingMethods.AnotherCurrencyMargin;
		Else
			Currency.RateSettingMethod = Enums.CurrencyRateSettingMethods.ManualInput;
		EndIf;
		Currency.Write();
	EndDo;
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Update currency rates

// Verifies that all currency rates are current.
//
Function RatesRelevant() Export
	QueryText =
	"SELECT
	|	Currencies.Ref AS Ref
	|INTO TTCurrencies
	|FROM
	|	Catalog.Currencies AS Currencies
	|WHERE
	|	Currencies.RateSettingMethod = VALUE(Enum.CurrencyRateSettingMethods.ImportFromInternet)
	|	AND Currencies.DeletionMark = FALSE
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	1 AS Field1
	|FROM
	|	TTCurrencies AS Currencies
	|		LEFT JOIN InformationRegister.CurrencyRates AS CurrencyRates
	|		ON Currencies.Ref = CurrencyRates.Currency
	|			AND (CurrencyRates.Period = &CurrentDate)
	|WHERE
	|	CurrencyRates.Currency IS NULL ";
	
	Query = New Query;
	Query.SetParameter("CurrentDate", BegOfDay(CurrentSessionDate()));
	Query.Text = QueryText;
	
	Return Query.Execute().IsEmpty();
EndFunction

// Determines whether there is at least one currency whose rate can be imported from the Internet.
//
Function RatesAreImportedFromInternet()
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	1 AS Field1
	|FROM
	|	Catalog.Currencies AS Currencies
	|WHERE
	|	Currencies.RateSettingMethod = VALUE(Enum.CurrencyRateSettingMethods.ImportFromInternet)
	|	AND Currencies.DeletionMark = FALSE";
	Return Not Query.Execute().IsEmpty();
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Local internal procedures and functions

// Highlights the value before
//  the TAB character from the passed row
//
// Parameters: 
//  SourceString - String - parsing string
//
// Returns:
//  substring to the TAB character
//
Function ExtractSubstring(SourceString)
	
	Var Subrow;
	
	Pos = Find(SourceString,Chars.Tab);
	If Pos > 0 Then
		Subrow = Left(SourceString,Pos-1);
		SourceString = Mid(SourceString,Pos + 1);
	Else
		Subrow = SourceString;
		SourceString = "";
	EndIf;
	
	Return Subrow;
	
EndFunction

// Returns a list of currencies whose rates are to be imported from the Internet.
Function CurrenciesImportedFromInternet() Export
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	Currencies.Ref AS Currency,
	|	Currencies.Code AS CurrencyCode
	|FROM
	|	Catalog.Currencies AS Currencies
	|WHERE
	|	Currencies.RateSettingMethod = VALUE(Enum.CurrencyRateSettingMethods.ImportFromInternet)
	|	AND Not Currencies.DeletionMark
	|
	|ORDER BY
	|	Currencies.LongDescription";

	Return Query.Execute().Unload();
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Handlers of conditional calls of other subsystems

// Updates links between the currency catalog and the supplied rate
// file depending on the currency rate setting method.
//
// Parameters:
//   Currency - CatalogObject.Currencies
//
Function OnRefreshCurrencyRateSaaS(Currency) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaSOperations.CurrenciesSaaS") Then
		CurrencyRatesInternalSaaSModule = CommonUse.CommonModule("CurrencyRatesInternalSaaS");
		CurrencyRatesInternalSaaSModule.ScheduleCopyCurrencyRates(Currency);
	EndIf;
	
EndFunction

#EndRegion
