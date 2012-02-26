
// Copies all the information to the information register of the subordinate currency
// from the information register of the basic currency (period, exchangerate, Multiplicity).
//
// Parameters
//  CurrencySource 	 – Catalogs.Currencies – ref to the basic currency, from whose information register,
//                 data will be copied
//  CurrencyReceiver – Catalogs.Currencies – ref to the currency depending on the basic currency,
//                 to whose information register data will be copied
//
Procedure WriteInfoForSubordinateRegister(CurrencySource, CurrencyReceiver) Export
	
	Query = New Query;
	Query.Text = "SELECT
	             |	CurrencyRates.Period,
	             |	CurrencyRates.Currency,
	             |	CurrencyRates.ExchangeRate,
	             |	CurrencyRates.Multiplicity
	             |FROM
	             |	InformationRegister.CurrencyRates AS CurrencyRates
	             |WHERE
	             |	CurrencyRates.Currency = &CurrencySource";
	Query.SetParameter("CurrencySource", CurrencySource);
	
	Selection = Query.Execute().Choose();
	
	RegisterCurrencyRates = InformationRegisters.CurrencyRates;
	RatesSet = RegisterCurrencyRates.CreateRecordSet();
	
	RatesSet.Filter.Currency.ComparisonType  = ComparisonType.Equal;
	RatesSet.Filter.Currency.Value      	 = CurrencyReceiver;
	RatesSet.Filter.Currency.Use 			 = True;
	
	SubordinateExchangeRateFactor = CurrencyReceiver.SubordinateExchangeRateFactor;
	
	While Selection.Next() Do
		
		NewCurrencySetRecord 				= RatesSet.Add();
		NewCurrencySetRecord.Currency   	= CurrencyReceiver;
		NewCurrencySetRecord.Multiplicity 	= Selection.Multiplicity;
		NewCurrencySetRecord.ExchangeRate   = Selection.ExchangeRate + Selection.ExchangeRate*SubordinateExchangeRateFactor/100;
		NewCurrencySetRecord.Period    		= Selection.Period;
		
	EndDo;
	
	RatesSet.Write();
	
EndProcedure

// Checks availability of the currency rate and Multiplicity on Jan 01, 1980.
// If there is no rate and Multiplicity assigns them equal to 1.
//
// Parameters:
//  Currency - ref to the catalog Currencies item
//
Procedure CheckThatCourseIsCorrectOn01_01_1980(Currency) Export
	
	RateDate = Date("19800101");
	RateStructure = InformationRegisters.CurrencyRates.GetLast(RateDate, New Structure("Currency", Currency));
	
	If (RateStructure.ExchangeRate = 0) Or (RateStructure.Multiplicity = 0) Then
		
		RegisterCurrencyRates = InformationRegisters.CurrencyRates.CreateRecordManager();
		
		RegisterCurrencyRates.Period    	= RateDate;
		RegisterCurrencyRates.Currency   	= Currency;
		RegisterCurrencyRates.ExchangeRate  = 1;
		RegisterCurrencyRates.Multiplicity 	= 1;
		RegisterCurrencyRates.Write();
	EndIf;
	
EndProcedure // CheckRateCorrectnessOn01_01_1980()

// Function, loads curerncy rate information from file to the information register
// of currency rates. Only the data within the period
// is being recorded.
//
Function LoadCurrencyRateFromFile(	Val Currency,
                                   	Val FileReference,
                                   	Val LoadPeriodBegin,
                                   	Val LoadPeriodEnding) Export
	
	LoadStatus = 1;
	
	NumberOfLoadedDaysTotal = 1 + (LoadPeriodEnding - LoadPeriodBegin) / ( 24 * 60 * 60);
	
	NumberOfLoadedDays = 0;
	
	If IsTempStorageURL(FileReference) Then
		FileName 	= GetTempFileName();
		BinaryData 	= GetFromTempStorage(FileReference);
		BinaryData.Write(FileName);
	Else
		FileName 	= FileReference;
	EndIf;
	
	Text = New TextDocument();
	
	RegisterCurrencyRates = InformationRegisters.CurrencyRates;
	
	Text.Read(FileName, TextEncoding.ANSI);
	StringsQty = Text.LineCount();
	
	For Indd = 1 To StringsQty Do
		
		Str = Text.GetLine(Indd);
		If (Str = "") OR (Find(Str,Chars.Tab) = 0) Then
			Continue;
		EndIf;
		
		If LoadPeriodBegin = LoadPeriodEnding Then
			RateDate = LoadPeriodEnding;
		Else
			RateDateStr = SelectSubString(Str);
			RateDate    = Date(Left(RateDateStr,4), Mid(RateDateStr,5,2), Mid(RateDateStr,7,2));
		EndIf;
		
		Multiplicity 			= Number(SelectSubString(Str));
		ExchangeRate      	= Number(SelectSubString(Str));
		
		If RateDate > LoadPeriodEnding Then
			Break;
		EndIf;
		
		If RateDate < LoadPeriodBegin Then 
			Continue;
		EndIf;
		
		WriteCurrencyRates = RegisterCurrencyRates.CreateRecordManager();
		
		WriteCurrencyRates.Currency    		 = Currency;
		WriteCurrencyRates.Period    		 = RateDate;
		WriteCurrencyRates.ExchangeRate      = ExchangeRate;
		WriteCurrencyRates.Multiplicity 		 = Multiplicity;
		WriteCurrencyRates.Write();
		
		NumberOfLoadedDays = NumberOfLoadedDays + 1;
	EndDo;
	
	If IsTempStorageURL(FileReference) Then
		DeleteFiles(FileName);
		DeleteFromTempStorage(FileReference);
	EndIf;
	
	If NumberOfLoadedDaysTotal = NumberOfLoadedDays Then
		ExplanationAboutLoad = "";
	ElsIf NumberOfLoadedDays = 0 Then
		ExplanationAboutLoad = NStr("en = 'Currency rate %1-%2 have not been loaded. Data not available'");
	Else
		ExplanationAboutLoad = NStr("en = 'Not all currency exchange rates have been downloaded'");
	EndIf;
	
	ExplanationAboutLoad = StringFunctionsClientServer.SubstitureParametersInString(
									ExplanationAboutLoad,
									Currency.Code,
									Currency.Description);
	
	Return ExplanationAboutLoad;
	
EndFunction

// Gets first value till the "TAB" symbol
//  from the passed string
//
// Parameters:
//  SourceLine - String - string for parsing
//
// Value returned:
//  substring till the "TAB" symbol
//
Function SelectSubString(SourceLine)
	
	Var Substring;
	
	Pos = Find(SourceLine,Chars.Tab);
	If Pos > 0 Then
		Substring  = Left(SourceLine,Pos-1);
		SourceLine = Mid(SourceLine,Pos + 1);
	Else
		Substring  = SourceLine;
		SourceLine = "";
	EndIf;
	
	Return Substring;
	
EndFunction

Function GetLoadCurrenciesArray() Export
	
	Query = New Query;
	Query.Text = "SELECT
	             |	Currencies.Ref AS Ref
	             |FROM
	             |	Catalog.Currencies AS Currencies
	             |WHERE
	             |	Currencies.DownloadRatesPeriodically";
	
	Return Query.Execute().Unload().UnloadColumn("Ref");
	
EndFunction

// Function returns information about currency rate based on the currency ref.
// Data is returned as structure.
//
// Parameters:
// SelectedCurrency - Catalog.Currencies / Ref - ref to currency, whose information
//                  about rate needs to be obtained
//
// Value returned:
// RateData   		- Structure, containing information about the latest available
//                 rate record
//
Function FillRateDataForCurrencies(SelectedCurrency) Export
	
	RateData = New Structure("RateDate, ExchangeRate, Multiplicity");
	
	Query = New Query;
	
	Query.Text = "SELECT
	             |	RegRates.Period,
	             |	RegRates.ExchangeRate,
	             |	RegRates.Multiplicity
	             |FROM
	             |	InformationRegister.CurrencyRates.SliceLast(&LoadPeriodEnding, Currency = &SelectedCurrency) AS RegRates";
	Query.SetParameter("SelectedCurrency", SelectedCurrency);
	Query.SetParameter("LoadPeriodEnding", CurrentDate());
	
	SelectionRate = Query.Execute().Choose();
	SelectionRate.Next();
	
	RateData.RateDate = SelectionRate.Period;
	RateData.ExchangeRate      = SelectionRate.ExchangeRate;
	RateData.Multiplicity = SelectionRate.Multiplicity;
	
	Return RateData;
	
EndFunction

// Returns value table - Currencies, depending on the one passed
// as parameter.
// Value to return:
// ValueTable
// column "Ref" 	   - CatalogRef.Currencies
// column "SubordinateExchangeRateFactor" - number
//
Function GetDependentCurrenciesList(Val CurrencyBasic) Export
	
	Query	= New Query;
	Query.Text = "SELECT
	             |	CatCurrencies.Ref,
	             |	CatCurrencies.SubordinateExchangeRateFactor
	             |FROM
	             |	Catalog.Currencies AS CatCurrencies
	             |WHERE
	             |	CatCurrencies.SubordinateRateFrom = &CurrencyBasic";
	
	Query.SetParameter("CurrencyBasic", CurrencyBasic);
	
	Return Query.Execute().Unload();
	
EndFunction

Procedure UpdateHandwritingStorageFormat() Export
	
	CurrenciesSelection = Catalogs.Currencies.Select();
	
	While CurrenciesSelection.Next() Do
		Object  = CurrenciesSelection.GetObject();
		StringOfParameters = StrReplace(Object.WritingParameters, ",", Chars.LF);
		Gender1 = Lower(Left(TrimAll(StrGetLine(StringOfParameters, 4)), 1));
		Gender2 = Lower(Left(TrimAll(StrGetLine(StringOfParameters, 8)), 1));
		Object.WritingParameters = 
					  TrimAll(StrGetLine(StringOfParameters, 1)) + ", "
					+ TrimAll(StrGetLine(StringOfParameters, 2)) + ", "
					+ TrimAll(StrGetLine(StringOfParameters, 3)) + ", "
					+ Gender1 + ", "
					+ TrimAll(StrGetLine(StringOfParameters, 5)) + ", "
					+ TrimAll(StrGetLine(StringOfParameters, 6)) + ", "
					+ TrimAll(StrGetLine(StringOfParameters, 7)) + ", "
					+ Gender2 + ", "
					+ TrimAll(StrGetLine(StringOfParameters, 9));
		Object.Write();
	EndDo;
	
EndProcedure
