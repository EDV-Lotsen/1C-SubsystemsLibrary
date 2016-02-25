////////////////////////////////////////////////////////////////////////////////
// Currency SaaS subsystem
//  
////////////////////////////////////////////////////////////////////////////////

#Region InternalInterface

// See the description of this procedure in the StandardSubsystemsServer module.
Procedure InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers) Export
	
	// SERVER HANDLERS
	
	ServerHandlers[
		"StandardSubsystems.InfobaseVersionUpdate\OnAddUpdateHandlers"].Add(
			"CurrencyRatesInternalSaaS");
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaSOperations.SuppliedData") Then
		ServerHandlers[
			"StandardSubsystems.SaaSOperations.SuppliedData\OnDefineSuppliedDataHandlers"].Add(
			"CurrencyRatesInternalSaaS");
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaSOperations.JobQueue") Then
		ServerHandlers[
			"StandardSubsystems.SaaSOperations.JobQueue\OnDefineHandlerAliases"].Add(
			"CurrencyRatesInternalSaaS");
	EndIf;
	
	If CommonUse.SubsystemExists("CloudTechnology.DataImportExport") Then
		ServerHandlers[
			"CloudTechnology.DataImportExport\AfterDataImportFromOtherMode"].Add(
				"CurrencyRatesInternalSaaS");
	EndIf;
	
EndProcedure

// Import a complete rate list of all time
//
Procedure ImportRates() Export
	
	Descriptors = SuppliedData.SuppliedDataDescriptorsFromManager("CurrencyRates");
	
	If Descriptors.Descriptor.Count() < 1 Then
		Raise(NStr("en = 'The service manager has no CurrencyRates data type'"));
	EndIf;
	
	Rates = SuppliedData.SuppliedDataReferencesFromCache("OneCurrencyRates");
	For Each Rate In Rates Do
		SuppliedData.DeleteSuppliedDataFromCache(Rate);
	EndDo; 
	
	SuppliedData.ImportAndProcessData(Descriptors.Descriptor[0]);
	
EndProcedure

// Is called after the data import
// Update currency rates from the supplied data
//
Procedure UpdateCurrencyRates() Export
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	Currencies.Code
	|FROM
	|	Catalog.Currencies AS Currencies
	|WHERE
	|	Currencies.RateSettingMethod = VALUE(Enum.CurrencyRateSettingMethods.ImportFromInternet)";
	Selection = Query.Execute().Select();
	
	//Copy rates. It needs to be done synchronously, for after the call UpdateCurrencyRates 
	//the infobase is updated, there is an attempt at locking the infobase. Copy rates is
	//a long process that can begin at an arbitrary moment in an asynchronous transfer mode
	//to prevent the infobase from locking.
	While Selection.Next() Do
		CopyCurrencyRates(Selection.Code);
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// SUPPLIED DATA GETTING HANDLERS

// Registers supplied data handlers, both daily and total.
//
Procedure RegisterSuppliedDataHandlers(Val Handlers) Export
	
	Handler = Handlers.Add();
	Handler.DataKind = "CurrencyRatesForDay";
	Handler.HandlerCode = "CurrencyRatesForDay";
	Handler.Handler = CurrencyRatesInternalSaaS;
	
	Handler = Handlers.Add();
	Handler.DataKind = "CurrencyRates";
	Handler.HandlerCode = "CurrencyRates";
	Handler.Handler = CurrencyRatesInternalSaaS;
	
EndProcedure

// The procedure is called when a new data notification is received.
// In the procedure body, check whether the application requires this data. 
// If it does, - set the Import flag.
// 
// Parameters:
//   Descriptor   - XDTODataObject Descriptor.
//   Import       - Boolean - return value
//
Procedure NewDataAvailable(Val Descriptor, Import) Export
	
	// When getting CurrencyRatesForDay the data from the file are appended to all the stored rates
	// and are recorded in all data fields for currencies mentioned in the fields. Is written only
	// for the current date.
	//
	If Descriptor.DataType = "CurrencyRatesForDay" Then
		Import = True;
	// Data CurrencyRates come to us in 3 cases - 
	// when you connect the infobase to MS
	// during infobase update period, when after the update the infobase requires currency that was not needed 
	// during the manual import of the rate file to MS.
	// In both cases it is necessary to dump the cache to overwrite all rates in all data areas
	ElsIf Descriptor.DataType = "CurrencyRates" Then
		Import = True;
	EndIf;
	
EndProcedure

// The procedure is called after calling NewDataAvailable, it parses the data.
//
// Parameters:
//   Descriptor   - XDTODataObject Descriptor.
//   PathToFile   - String or Undefined. Extracted file full name. The file is automatically
//                  deleted once the procedure is executed. If the file is not specified in Service Manager, - the parameter value is Undefined.
//
Procedure ProcessNewData(Val Descriptor, Val PathToFile) Export
	
	If Descriptor.DataType = "CurrencyRatesForDay" Then
		HandleSuppliedRatesPerDay(Descriptor, PathToFile);
	ElsIf Descriptor.DataType = "CurrencyRates" Then
		HandleSuppliedRates(Descriptor, PathToFile);
	EndIf;
	
EndProcedure

// The procedure is called if data processing is canceled due to an error
//
Procedure DataProcessingCanceled(Val Descriptor) Export 
	
	SuppliedData.AreaProcessed(Descriptor.FileGUID, "CurrencyRatesForDay", Undefined);
	
EndProcedure	

////////////////////////////////////////////////////////////////////////////////
// INFOBASE UPDATE HANDLERS

// Adds update handlers that are required by the subsystem.
//
// Parameters:
//  Handlers - ValueTable - see the description of NewUpdateHandlerTable function in the InfobaseUpdate common module.
// 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.1.7";
	Handler.Procedure = "CurrencyRatesInternalSaaS.ConvertCurrencyLinks";
	
EndProcedure

// Is called on update from previous versions where the ImportFromInternet check box 
// is not selected 

//
Procedure ConvertCurrencyLinks() Export
	Var Query, Selection, RecordSet, Write;
	Var XMLClassifier, ClassifierTable, Currency, FoundRow;
	
	XMLClassifier = Catalogs.Currencies.GetTemplate("CurrencyClassifier").GetText();
	ClassifierTable = CommonUse.ReadXMLToTable(XMLClassifier).Data;
	ClassifierTable.Indexes.Add("Code");
	
	Selection = Catalogs.Currencies.Select();
	While Selection.Next()  Do
		Currency = Selection.GetObject();
		FoundRow = ClassifierTable.Find(Currency.Code, "Code");
		If FoundRow <> Undefined And FoundRow.RBCLoading = "true" Then
			Currency.RateSettingMethod = Enums.CurrencyRateSettingMethods.ImportFromInternet;
			InfobaseUpdate.WriteData(Currency);
		EndIf;
	EndDo;	

EndProcedure	

#EndRegion

#Region InternalProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// SL event handlers

// Fills a map of method names and their aliases for calling from a job queue
//
// Parameters:
//  NameAndAliasMap - Map
//   Key - method alias, example: ClearDataArea.
//   Value - method name, example: SaaSOperations.ClearDataArea. You can pass Undefined if the
//           name is identical to the alias
//
Procedure OnDefineHandlerAliases(NameAndAliasMap) Export
	
	NameAndAliasMap.Insert("CurrencyRatesInternalSaaS.CopyCurrencyRates");
	
EndProcedure

// Registers supplied data handlers
//
// When a new shared data notification is received, NewDataAvailable procedures 
// from modules registered with GetSuppliedDataHandlers are called.
// The descriptor passed to the procedure is XDTODataObject Descriptor.
// 
// If NewDataAvailable sets Import to True, the data is imported, and the descriptor 
// and the path to the data file are passed to ProcessNewData() procedure. 
// The file is automatically deleted once the procedure is executed.
// If the file is not specified in the Service manager, the parameter value is Undefined.
//
// Parameters: 
//   Handlers, ValueTable - table for adding handlers. 
//       Columns:
//        DataKind                - String - code of the data kind processed by the handler.
//        HandlerCode - Sting(20) - used for recovery after a data processing error.
//        Handler, CommonModule   - module that contains the following procedures:
//          NewDataAvailable(Descriptor, Import) Export 
//          ProcessNewData(Descriptor, Import) Export 
//          DataProcessingCanceled(Descriptor) Export
//
Procedure OnDefineSuppliedDataHandlers(Handlers) Export
	
	RegisterSuppliedDataHandlers(Handlers);
	
EndProcedure

// This procedure is called after data import from a local version to service data area (or vice versa) is completed.
//
Procedure AfterDataImportFromOtherMode() Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaSOperations.SuppliedData") Then
		//Creating links between separated and shared currencies, copying rates
		UpdateCurrencyRates();
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Rate file serialization/deserialization

// Writes files in the supplied data format
//
// Parameters:
//  RateTable - ValueTable with the following columns Code, Date, UnitConversionFactor, Rate 
//  File - String or TextWriter
//
Procedure SaveRateTable(Val RateTable, Val File)
	
	If TypeOf(File) = Type("String") Then
		TextWriter = New TextWriter(File);
	Else
		TextWriter = File;
	EndIf;
	
	For Each TableRow In RateTable Do
			
		XMLRate = StrReplace(
		StrReplace(
		StrReplace(
			StrReplace("<Rate Code=""%1"" Date=""%2"" Factor=""%3"" Rate=""%4""/>", 
			"%1", TableRow.Code),
			"%2", Left(XDTOSerializer.XMLString(TableRow.Date), 10)),
			"%3", XDTOSerializer.XMLString(TableRow.UnitConversionFactor)),
			"%4", XDTOSerializer.XMLString(TableRow.Rate));
		
		TextWriter.WriteLine(XMLRate);
	EndDo; 
	
	If TypeOf(File) = Type("String") Then
		TextWriter.Close();
	EndIf;
	
EndProcedure

// Reads files in the supplied data format
//
// Parameters:
//  PathToFile          - String, file name
//  SearchForDuplicates - Boolean, collapses entries with the same date
//
// Returns
// ValueTable with the following columns Code, Date, UnitConversionFactor, Rate
//
Function ReadRateTable(Val PathToFile, Val SearchForDuplicates = False)
	
	RateDataType = XDTOFactory.Type("http://www.1c.ru/SaaS/SuppliedData/CurrencyRates", "Rate");
	RateTable = New ValueTable();
	RateTable.Columns.Add("Code", New TypeDescription("String", , New StringQualifiers(200)));
	RateTable.Columns.Add("Date", New TypeDescription("Date", , , New DateQualifiers(DateFractions.Date)));
	RateTable.Columns.Add("UnitConversionFactor", New TypeDescription("Number", New NumberQualifiers(9, 0)));
	RateTable.Columns.Add("Rate", New TypeDescription("Number", New NumberQualifiers(20, 4)));
	
	Read = New TextReader(PathToFile);
	CurrentRow = Read.ReadLine();
	While CurrentRow <> Undefined Do
		
		XMLReader = New XMLReader();
		XMLReader.SetString(CurrentRow);
		Rate = XDTOFactory.ReadXML(XMLReader, RateDataType);
		
		If SearchForDuplicates Then
			For Each Duplicate In RateTable.FindRows(New Structure("Date", Rate.Date)) Do
				RateTable.Delete(Duplicate);
			EndDo;
		EndIf;
		
		WriteCurrencyRate = RateTable.Add();
		WriteCurrencyRate.Code = Rate.Code;
		WriteCurrencyRate.Date = Rate.Date;
		WriteCurrencyRate.UnitConversionFactor = Rate.Factor;
		WriteCurrencyRate.Rate = Rate.Rate;

		CurrentRow = Read.ReadLine();
	EndDo;
	Read.Close();
	
	RateTable.Indexes.Add("Code");
	Return RateTable;
		
EndFunction

// Is called when CurrencyRates data type is received
//
// Parameters:
//   Descriptor   - XDTODataObject Descriptor.
//   PathToFile   - string. Extracted file full name.
//
Procedure HandleSuppliedRates(Val Descriptor, Val PathToFile)
	
	RateTable = ReadRateTable(PathToFile);
	RateTable.Indexes.Add("Code");
	
	// Split the files by currency and write them to the database
	CodeTable = RateTable.Copy( , "Code");
	CodeTable.Collapse("Code");
	For Each CodeString In CodeTable Do
		
		TempFileName = GetTempFileName();
		SaveRateTable(RateTable.FindRows(New Structure("Code", CodeString.Code)), TempFileName);
		
		Descriptor = New Structure("DataKind, AddedAt, FileID, Characteristics",
			"OneCurrencyRates", CurrentUniversalDate(), New UUID, New Array);
		Descriptor.Characteristics.Add(New Structure("Code, Value, Key", "Currency", CodeString.Code, True));
		
		SuppliedData.SaveSuppliedDataInCache(Descriptor, TempFileName);
		Try
			DeleteFiles(TempFileName);
		Except
		EndTry;
	
	EndDo; 
	
	AreasForUpdate = SuppliedData.AreasRequireProcessing(
		Descriptor.FileID, "CurrencyRates");
	
	DistributeRatesByDataAreas(, RateTable, AreasForUpdate, 
		Descriptor.FileID, "CurrencyRates");

EndProcedure

// Is called after getting new CurrencyRatesForDay data type
//
// Parameters:
//   Descriptor   - XDTODataObject Descriptor.
//   PathToFile   - string. Extracted file full name.
//
Procedure HandleSuppliedRatesPerDay(Val Descriptor, Val PathToFile)
		
	RateTable = ReadRateTable(PathToFile);
	
	RateDate = "";
	For Each Characteristic In Descriptor.Properties.Property Do
		If Characteristic.Code = "Date" Then
			RateDate = Date(Characteristic.Value); 		
		EndIf;
	EndDo; 
	
	If RateDate = "" Then
		Raise NStr("en = 'CurrencyRatesForDay data type does not contain Date characteristics. Unable to update currency rates.'"); 
	EndIf;
	
	AreasForUpdate = SuppliedData.AreasRequireProcessing(Descriptor.FileGUID, "CurrencyRatesForDay", True);
	
	CommonRateIndex = AreasForUpdate.Find(-1);
	If CommonRateIndex <> Undefined Then
		
		RateCache = SuppliedData.SuppliedDataFromCacheDescriptors("OneCurrencyRates", , False);
		If RateCache.Count() > 0 Then
			For Each RateString In RateTable Do
				
				CurrentCache = Undefined;
				For	Each CacheDescriptor In RateCache Do
					If CacheDescriptor.Characteristics.Count() > 0 
						And CacheDescriptor.Characteristics[0].Code = "Currency"
						And CacheDescriptor.Characteristics[0].Value = RateString.Code Then
						CurrentCache = CacheDescriptor;
						Break;
					EndIf;
				EndDo;
				
				TempFileName = GetTempFileName();
				If CurrentCache <> Undefined Then
					Data = SuppliedData.SuppliedDataFromCache(CurrentCache.FileID);
					Data.Write(TempFileName);
				Else
					CurrentCache = New Structure("DataKind, AddedAt, FileID, Characteristics",
						"OneCurrencyRates", CurrentUniversalDate(), New UUID, New Array);
					CurrentCache.Characteristics.Add(New Structure("Code, Value, Key", "Currency", RateString.Code, True));
				EndIf;
				
				TextWriter = New TextWriter(TempFileName, TextEncoding.UTF8, Chars.LF, True);
				
				RecordTable = New Array;
				RecordTable.Add(RateString);
				SaveRateTable(RecordTable, TextWriter);
				TextWriter.Close();
				
				SuppliedData.SaveSuppliedDataInCache(CurrentCache, TempFileName);
				Try
					DeleteFiles(TempFileName);
				Except
				EndTry;

			EndDo; 
			
		EndIf;
		
		AreasForUpdate.Delete(CommonRateIndex);
	EndIf;
	
	DistributeRatesByDataAreas(RateDate, RateTable, AreasForUpdate, 
		Descriptor.FileGUID, "CurrencyRatesForDay");

EndProcedure

// Copies rates in all data areas
//
// Parameters
//  RateDate       - Date or Undefined. The rates are added for the specified date or for all time
//  RateTable      - ValueTable containing rates
//  AreasForUpdate - Array of area codes.
//  FileID         - processed rate file UUID.
//  HandlerCode    - String - handler code.
//
Procedure DistributeRatesByDataAreas(Val RateDate, Val RateTable, 
	Val AreasForUpdate, Val FileID, Val HandlerCode)
	
	For Each DataArea In AreasForUpdate Do
	
		CommonUse.SetSessionSeparation(True, DataArea);
		
		CurrencyQuery = New Query;
		CurrencyQuery.Text = 
		"SELECT
		|	Currencies.Ref,
		|	Currencies.Code
		|FROM
		|	Catalog.Currencies AS Currencies
		|WHERE
		|	Currencies.RateSettingMethod = VALUE(Enum.CurrencyRateSettingMethods.ImportFromInternet)";
		
		CurrencySelection = CurrencyQuery.Execute().Select();
		BeginTransaction();
		While CurrencySelection.Next() Do
		
			Rates = RateTable.FindRows(New Structure("Code", CurrencySelection.Code));
			If Rates.Count() = 0 Then
				Continue;
			EndIf;
		
			RecordSet = InformationRegisters.CurrencyRates.CreateRecordSet();
			RecordSet.Filter.Currency.Set(CurrencySelection.Ref);
			If RateDate <> Undefined Then
				RecordSet.Filter.Period.Set(RateDate);
			Else 
				//Block the ineffective associated currency update
				RecordSet.DataExchange.Load = True;
			EndIf;
			
			For Each RateString In Rates Do
				Write = RecordSet.Add();
				Write.Currency = CurrencySelection.Ref;
				Write.Period = RateString.Date;
				Write.UnitConversionFactor = RateString.UnitConversionFactor;
				Write.Rate = RateString.Rate;
			EndDo; 
			RecordSet.Write();
			
		EndDo;
		SuppliedData.AreaProcessed(FileID, HandlerCode, DataArea);
		CommitTransaction();
	EndDo;
	
EndProcedure

// Is called when the currency rate setting method is changed.
//
// Currency - CatalogRef.Currencies
//
Procedure ScheduleCopyCurrencyRates(Val Currency) Export
	
	If Currency.RateSettingMethod <> Enums.CurrencyRateSettingMethods.ImportFromInternet Then
		Return;
	EndIf;
	
	MethodParameters = New Array;
	MethodParameters.Add(Currency.Code);

	JobParameters = New Structure;
	JobParameters.Insert("MethodName", "CurrencyRatesInternalSaaS.CopyCurrencyRates");
	JobParameters.Insert("Parameters", MethodParameters);
	
	SetPrivilegedMode(True);
	JobQueue.AddJob(JobParameters);

EndProcedure

// Is called after the data import to the region or when the currency rate setting method
// is changed. Copies one currency rates for all dates from a separated xml file to 
// the shared register
// 
// Parameters
//  CurrencyCode - String
//
Procedure CopyCurrencyRates(Val CurrencyCode) Export
	
	CurrencyRef = Catalogs.Currencies.FindByCode(CurrencyCode);
	If CurrencyRef.IsEmpty() Then
		Return;
	EndIf;
	
	RateDataType = XDTOFactory.Type("http://www.1c.ru/SaaS/SuppliedData/CurrencyRates", "Rate");
	
	Filter = New Array;
	Filter.Add(New Structure("Code, Value", "Currency", CurrencyCode));
	Rates = SuppliedData.SuppliedDataReferencesFromCache("OneCurrencyRates", Filter);
	If Rates.Count() = 0 Then
		Return;
	EndIf;
	
	PathToFile = GetTempFileName();
	SuppliedData.SuppliedDataFromCache(Rates[0]).Write(PathToFile);
	RateTable = ReadRateTable(PathToFile, True);
	Try
		DeleteFiles(PathToFile);
	Except
	EndTry;
	
	RateTable.Columns.Date.Name = "Period";
	RateTable.Columns.Add("Currency");
	RateTable.FillValues(CurrencyRef, "Currency");
	
	RecordSet = InformationRegisters.CurrencyRates.CreateRecordSet();
	RecordSet.Filter.Currency.Set(CurrencyRef);
	RecordSet.Load(RateTable);
	RecordSet.DataExchange.Load = True;
	RecordSet.Write();

EndProcedure

#EndRegion
