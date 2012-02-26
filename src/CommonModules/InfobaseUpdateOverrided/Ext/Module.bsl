
///////////////////////////////////////////////////////////////////////////////
// INTERFACE PART OF THE OVERRIDED MODULE

// Returns list of IB update handler-procedures for all supported IB versions.
//
// Example of adding of handler-procedure to the list:
//    Handler			 = Handlers.Add();
//    Handler.Version	 = "1.0.0.0";
//    Handler.Procedure  = "IBUpdate.GoToVersion_1_0_0_0";
//
// Called before IB data update start.
//
Function UpdateHandlers() Export
	
	Handlers = InfobaseUpdate.NewUpdateHandlersTable();
	
	// Connecting procedures-handlers of configuration update
	Handler			 	= Handlers.Add();
	Handler.Version 	= "1.0.0.1";
	Handler.Procedure 	= "InfobaseUpdateOverrided.FirstLaunch";
	
	Handler 			= Handlers.Add();
	Handler.Version 	= "1.0.7.5";
	Handler.Procedure 	= "InfobaseUpdateOverrided.Update_1_0_7_5";
	
	Return Handlers;
	
EndFunction // UpdateHandlers()

// Called after completion of infobase data update.
//
// Parameters:
//   PreviousInfobaseVersion     	 - String 	 - IB version before update. "0.0.0.0" for "empty" IB.
//   CurrentInfobaseVersion        - String  	 - IB version after update.
//   ExecutedHandlers 		 - ValueTree - list of executed update handler-procedures,
//                                             grouped by version number.
//  Iteration over the executed handlers:
//		For Each Version In ExecutedHandlers.Rows Do
//
//			If Version.Version = "*" Then
//				group of handlers, that are always executed
//			Else
//				group of handlers, executed for the specific version
//			EndIf;
//
//			For Each Handler In Version.Rows Do
//				...
//			EndDo;
//
//		EndDo;
//
//   OutputUpdatesDetails - Boolean -	if True, then show form with description
//											of the updates.
//
Procedure AfterUpdate(Val PreviousInfobaseVersion, Val CurrentInfobaseVersion, 
	Val ExecutedHandlers, OutputUpdatesDetails) Export
	
EndProcedure

// Called when spreadsheet document with the description of changes is being prepared.
//
// Parameters:
//   Template - SpreadsheetDocument - description of changes.
//
// See. also common template UpdateDetails.
//
Procedure OnPrepareUpdateDescriptionTemplate(Val Template) Export
// Procedure code.
EndProcedure	

///////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS OF INFOBASE UPDATE

// Procedure fills empty IB.
//
Procedure FirstLaunch() Export
	
	BeginTransaction();
	
	// 1. Fill currencies.
	NationalCurrencyRef 						= Catalogs.Currencies.NationalCurrency;
	CurrencyNationalCurrency 					= NationalCurrencyRef.GetObject();
	CurrencyNationalCurrency.Description 		= "USD";
	CurrencyNationalCurrency.Details 			= "US Dollar";
	CurrencyNationalCurrency.WritingParameters 	= "dollar, dollar, dollars, m, cent, cent, cents, m, 2";
	
	CurrencyEUR 					= Catalogs.Currencies.CreateItem();
	CurrencyEUR.Code 				= "392";
	CurrencyEUR.Description 		= "EUR";
	CurrencyEUR.Details 			= "Euro";
	CurrencyEUR.WritingParameters 	= "euro, euro, euros, m, cent, cents, cents, m, 2";

	CurrencyYEN 					= Catalogs.Currencies.CreateItem();
	CurrencyYEN.Code 				= "392";
	CurrencyYEN.Description 		= "YEN";
	CurrencyYEN.Details 			= "Yen";
	CurrencyYEN.WritingParameters 	= "yen, yen, yen, m, sen, sen, sen, m, 2";

	CurrencyCNY 					= Catalogs.Currencies.CreateItem();
	CurrencyCNY.Code 				= "156";
	CurrencyCNY.Description 		= "CNY";
	CurrencyCNY.Details 			= "Yuan";
	CurrencyCNY.WritingParameters 	= "yuan, yuan, yuan, m, fen, fen, fen, m, 2";
	
	CurrencyNationalCurrency.Write();
	FillCurrencyRatesFor_11_01_2011(NationalCurrencyRef);
	
	// 2. Fill companies.
	OurCompanyRef = Catalogs.Companies.MainCompany;
	OurCompany = OurCompanyRef.GetObject();
	OurCompany.PrintedName	  		= "Our Company, LLC";
	OurCompany.Prefix				= "OC-";
	OurCompany.BusinessIndividual	= Enums.BusinessIndividual.Business;
	OurCompany.Write();
	
	// 3. Fill constants.
	Constants.ExtractFileTextsAtServer.Set(true);
	
	CommitTransaction();
	
EndProcedure // FirstLaunch()

// Procedure fills currency rates on 11/01/2011.
//
Procedure FillCurrencyRatesFor_11_01_2011(Currency) Export

	RateDate = Date(2011, 11, 1);
	
	RegisterCurrencyRates = InformationRegisters.CurrencyRates.CreateRecordManager();

	RegisterCurrencyRates.Period   = RateDate;
	RegisterCurrencyRates.Currency = Currency;
        
	If RegisterCurrencyRates.Currency.Code 		= "978" Then
		RegisterCurrencyRates.ExchangeRate 		= 42.1833;
		RegisterCurrencyRates.Multiplicity = 1;
    ElsIf RegisterCurrencyRates.Currency.Code 	= "840" Then
        RegisterCurrencyRates.ExchangeRate 		= 30.1245;
		RegisterCurrencyRates.Multiplicity = 1;
	ElsIf RegisterCurrencyRates.Currency.Code	= "392" Then
		RegisterCurrencyRates.ExchangeRate		= 38.1468;
		RegisterCurrencyRates.Multiplicity = 100;
	ElsIf RegisterCurrencyRates.Currency.Code	= "156" Then
		RegisterCurrencyRates.ExchangeRate		= 47.4066;
		RegisterCurrencyRates.Multiplicity = 10;
	EndIf;
	
	RegisterCurrencyRates.Write();

EndProcedure // FillCurrencyRatesFor_11_01_2011()

// Procedure of updates 1.0.7.5.
//
Procedure Update_1_0_7_5() Export

	// insert your handler here
	
EndProcedure // Update_1_0_7_5()
