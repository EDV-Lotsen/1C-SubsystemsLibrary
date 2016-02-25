////////////////////////////////////////////////////////////////////////////////
// Currency subsystem
// 
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// Converts the amount from the Current currency into the New currency by their rate parameters.
//   Use the function to get currency rate parameters
//   CurrencyRateOperations.GetCurrencyRate(Currency, RateDate).
//
// Parameters:
//   Amount                - Number    - The amount that should be converted.
//   CurrentRateParameters - Structure - The rate parameters of the currency from which 
//                                       to convert.
//       * Currency             - CatalogRef.Currencies - Converted currency ref.
//       * Rate                 - Number - Converted currency rate.
//       * UnitConversionFactor - Number - Converted currency unit conversion factor.
//   NewRateParameters     - Structure - The rate parameters of the currency into which 
//                                       to convert.
//       * Currency             - CatalogRef.Currencies - The reference to the currency into 
//                                which another currency is being converted.
//       * Rate                 - Number - The rate of the currency into which another 
//                                currency is being converted.
//       * UnitConversionFactor - Number - The unit conversion factor of the currency into
//                                which another currency is being converted.
//
// Returns: 
//   Number - The amount converted by a new rate.
//
Function ConvertAtRate(Amount, CurrentRateParameters, NewRateParameters) Export
	If CurrentRateParameters.Currency = NewRateParameters.Currency
		Or (
			CurrentRateParameters.Rate = NewRateParameters.Rate 
			And CurrentRateParameters.UnitConversionFactor = NewRateParameters.UnitConversionFactor
		) Then
		
		Return Amount;
		
	EndIf;
	
	If CurrentRateParameters.Rate = 0
		Or CurrentRateParameters.UnitConversionFactor = 0
		Or NewRateParameters.Rate = 0
		Or NewRateParameters.UnitConversionFactor = 0 Then
		
		CommonUseClientServer.MessageToUser(
			StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'On conversion into the %1 currency the %2 amount is set to zero, because the currency rate is not set.'"), 
				NewRateParameters.Currency, 
				Format(Amount, "NFD=2; NZ=0")));
		
		Return 0;
		
	EndIf;
	
	Return Round((Amount * CurrentRateParameters.Rate * NewRateParameters.UnitConversionFactor) / (NewRateParameters.Rate * CurrentRateParameters.UnitConversionFactor), 2);
EndFunction

// Obsolete: Use the function ConvertAtRate
//
// Converts the amount from the CurrencySrc currency at the AtRateSrc rate into 
// the CurrencyTrg currency at the AtRateTrg rate.
//
// Parameters:
//   Amount                      - Number                - The amount to be converted
//   CurrencySrc                 - CatalogRef.Currencies - The currency from which to convert
//   CurrencyTrg                 - CatalogRef.Currencies - The currency into which to convert
//   AtRateSrc                   - Number                - The rate from which to convert
//   AtRateTrg                   - Number                - The rate into which to convert
//   ByUnitConversionFactorSrc   - Number                - The unit conversion factor from
//                                                         which to convert (by default = 1)
//   ByUnitConversionFactorTrg   - Number                - The unit conversion factor into
//                                                         which to convert (by default = 1)
//
// Returns: 
//   Number - The amount converted into another currency
//
Function ConvertCurrencies(Amount, CurrencySrc, CurrencyTrg, AtRateSrc, AtRateTrg, 
	ByUnitConversionFactorSrc = 1, ByUnitConversionFactorTrg = 1) Export
	
	Return ConvertAtRate(
		Amount, 
		New Structure("Currency, Rate, UnitConversionFactor", CurrencySrc, AtRateSrc, ByUnitConversionFactorSrc),
		New Structure("Currency, Rate, UnitConversionFactor", CurrencyTrg, AtRateTrg, ByUnitConversionFactorTrg));
	
EndFunction

#EndRegion

#Region InternalProceduresAndFunctions

// Currency rate import procedure for a particular period.
//
// Parameters
// Currencies        - Arbitrary collection  - with the following fields:
// 			    	CurrencyCode - numeric currency code
// 				    Currency     - currency ref 
// ImportPeriodBegin - Date                  - the beginning of a rate import period 
// ImportPeriodEnd   - Date                  - rate import period end
//
// Returns:
// Import state array  - Each element is a structure with the following fields:
// 	Currency          - currency to be imported
// 	OperationStatus   - whether the import is successfully completed
// 	Message           - import description (error message or explanatory text)
//
Function ImportCurrencyRatesByParameters(Val Currencies, Val ImportPeriodBegin, Val ImportPeriodEnd, 
	ErrorsOccurredOnImport = False) Export
	
	ImportState = New Array;
	
	ErrorsOccurredOnImport = False;
	//PARTIALLY_DELETED
	//ServerSource = "cbrates.rbc.ru";
	ServerSource = "";
	
	If ImportPeriodBegin = ImportPeriodEnd Then
		Address = "tsv/";
		TMP   = Format(ImportPeriodEnd, "DF=/yyyy/MM/dd"); // Do not localize this parameter - filepath on server
	Else
		Address = "tsv/cb/";
		TMP   = "";
	EndIf;
	
	For Each Currency In Currencies Do
		FileOnWebServer = "http://" + ServerSource + "/" + Address + Right(Currency.CurrencyCode, 3) + TMP + ".tsv";
		
		#If Client Then
			Result = GetFilesFromInternetClient.DownloadFileAtClient(FileOnWebServer);
		#Else
			Result = GetFilesFromInternet.DownloadFileAtServer(FileOnWebServer);
		#EndIf
		
		If Result.Status Then
			#If Client Then
				BinaryData = New BinaryData(Result.Path);
				AddressInTempStorage = PutToTempStorage(BinaryData);
				ExplanatoryMessage = CurrencyRateOperationsServerCall.ImportCurrencyRateFromFile(Currency.Currency, AddressInTempStorage, ImportPeriodBegin, ImportPeriodEnd) + Chars.LF;
			#Else
				ExplanatoryMessage = CurrencyRateOperations.ImportCurrencyRateFromFile(Currency.Currency, Result.Path, ImportPeriodBegin, ImportPeriodEnd) + Chars.LF;
			#EndIf
			DeleteFiles(Result.Path);
			OperationStatus = IsBlankString(ExplanatoryMessage);
		Else
			ExplanatoryMessage = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Currency rate data file (%1 - %2) cannot be accessed:
	   |%3
	   | There is no access to the currency rate website, or a nonexistent currency is specified.'"),
				Currency.CurrencyCode,
				Currency.Currency,
				Result.ErrorMessage);
			OperationStatus = False;
			ErrorsOccurredOnImport = True;
		EndIf;
		
		ImportState.Add(New Structure("Currency,OperationStatus,Message", Currency.Currency, OperationStatus, ExplanatoryMessage));
		
	EndDo;
	
	Return ImportState;
	
EndFunction

#EndRegion
