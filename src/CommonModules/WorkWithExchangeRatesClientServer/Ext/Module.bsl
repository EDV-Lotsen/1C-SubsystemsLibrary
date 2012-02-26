
// Procedure for loading currency rates  for the specified period.
//
// Parameters
// Currencies		- Any collection - with the following fields:
//					CurrencyCode - currency numeric code
//					Currency 	 - currency ref
// LoadPeriodBegin	- Date  	 - begin of the period of currency rates load
// LoadPeriodEnding	- Date  	 - ending of the period of currency rates load
// ExplainingMessage			 - string - in case of error
//							(exceptions) in function, contains text presentation of error description
//
// Value returned:
// True			- currencies has been successfully loaded
// False		- at least one currency has not been loaded
//
Function LoadCurrencyRatesByParameters(	Val Currencies,
										Val LoadPeriodBegin,
										Val LoadPeriodEnding,
										ExplainingMessage = "") Export
	
	OperationStatus = True;
	
	ServerSource = "cbrates.rbc.ru";
	If LoadPeriodBegin = LoadPeriodEnding Then
		Address = "tsv/";
		TMP   	= "/"+Format(Year(LoadPeriodEnding),"NGS=; NG=0")+"/"+Format(Month(LoadPeriodEnding),"ND1=2;NFD=0;NLZ=")+"/"+Format(Day(LoadPeriodEnding),"ND1=2;NFD=0;NLZ=");
	Else
		Address = "tsv/cb/";
		TMP   	= "";
	EndIf;
	
	For Each Currency in Currencies Do
		FileOnWebServer = "http://" + ServerSource + "/" + Address + Right(Currency.CurrencyCode, 3) + TMP + ".tsv";
		
#If AtClient Then
		Result = GetFilesFromInternetClient.DownloadFileAtClient(FileOnWebServer);
#Else
		Result = GetFilesFromInternet.DownloadFileAtServer(FileOnWebServer);
#EndIf
		
		If Result.Status Then
#If AtClient Then
			BinaryData = New BinaryData (Result.Path);
			AddressInTemporaryStorage = PutToTempStorage(BinaryData);
			ExplainingMessage = ExplainingMessage + WorkWithExchangeRates.LoadCurrencyRateFromFile(Currency.Currency, AddressInTemporaryStorage, LoadPeriodBegin, LoadPeriodEnding) + Chars.LF;
#Else
			ExplainingMessage = ExplainingMessage + WorkWithExchangeRates.LoadCurrencyRateFromFile(Currency.Currency, Result.Path, LoadPeriodBegin, LoadPeriodEnding) + Chars.LF;
#EndIf
			DeleteFiles(Result.Path);
		Else
			OperationStatus = False;
			ExplainingMessage= NStr("en = 'Impossible to get file with exchange currency rate (%1 - %2):""%3""Access to site might be denied, or specified currency does not exist.'");
			ExplainingMessage = 
				StringFunctionsClientServer.SubstitureParametersInString(
								ExplainingMessage,
								Currency.CurrencyCode,
								Currency.Currency,
								Result.ErrorMessage);
		EndIf;
	EndDo;
	
	If OperationStatus Then
		ExplainingMessage = Left(ExplainingMessage, StrLen(ExplainingMessage) - 2);
	EndIf;
	
	Return OperationStatus;
	
EndFunction
