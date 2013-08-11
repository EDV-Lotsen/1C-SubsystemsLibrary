////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

////////////////////////////////////////////////////////////////////////////////
// Export internal procedures and functions.

// Gets object mapping statistics for the Statistics table rows.
//
// Parameters:
//  Cancel     – Boolean – cancel flag. It is set to True if errors occur during the
//               procedure execution.
//  RowIndexes – Array (optional) – indexes of Statistics table rows for which mapping
//               statistic data will be retrieved.
//               If the parameter is not specified, starictic data for all table rows 
//               will be retrieved.
// 
Procedure GetObjectMappingByRowStats(Cancel, RowIndexes = Undefined) Export
	
	SetPrivilegedMode(True);
	
	If RowIndexes = Undefined Then
		
		RowIndexes = New Array;
		
		For Each TableRow In Statistics Do
			
			RowIndexes.Add(Statistics.IndexOf(TableRow));
			
		EndDo;
		
	EndIf;
	
	// Importing data from the exchange message into the cache for several tables at the same time
	ExecuteDataImportFromExchangeMessagesIntoCache(Cancel, RowIndexes);
	
	If Cancel Then
		Return;
	EndIf;
	
	InfoBaseObjectMapping = DataProcessors.InfoBaseObjectMapping.Create();
	
	// Getting mapping digest data separately for each table
	For Each RowIndex In RowIndexes Do
		
		TableRow = Statistics[RowIndex];
		
		If Not TableRow.SynchronizeByID Then
			Continue;
		EndIf;
		
		// Initializing data processor properties
		InfoBaseObjectMapping.TargetTableName           = TableRow.TargetTableName;
		InfoBaseObjectMapping.SourceTableObjectTypeName = TableRow.ObjectTypeString;
		InfoBaseObjectMapping.InfoBaseNode              = InfoBaseNode;
		InfoBaseObjectMapping.ExchangeMessageFileName   = ExchangeMessageFileName;
		
		InfoBaseObjectMapping.SourceTypeString = TableRow.SourceTypeString;
		InfoBaseObjectMapping.TargetTypeString = TableRow.TargetTypeString;
		
		// Constructor
		InfoBaseObjectMapping.Constructor();
		
		// Getting mapping digest data
		InfoBaseObjectMapping.GetObjectMappingDigestInfo(Cancel);
		
		// Mapping digest information 
		TableRow.ObjectCountInSource = InfoBaseObjectMapping.ObjectCountInSource();
		TableRow.ObjectCountInTarget = InfoBaseObjectMapping.ObjectCountInTarget();
		TableRow.MappedObjectCount   = InfoBaseObjectMapping.MappedObjectCount();
		TableRow.UnmappedObjectCount = InfoBaseObjectMapping.UnmappedObjectCount();
		TableRow.MappedObjectPercent = InfoBaseObjectMapping.MappedObjectPercent();
		TableRow.PictureIndex        = DataExchangeServer.StatisticsTablePictureIndex(TableRow.UnmappedObjectCount, TableRow.DataImportedSuccessfully);
		
	EndDo;
	
EndProcedure

// Automatically maps infobase objects with the specified default values and then
// retrieves object mapping statistics.
//
// Parameters:
//  Cancel     – Boolean – cancel flag. It is set to True if errors occur during the
//               procedure execution.
//  RowIndexes – Array (optional) – indexes of Statistics table rows for which mapping
//               statistic data will be retrieved.
//               If the parameter is not specified, starictic data for all table rows 
//               will be retrieved.
// 
Procedure ExecuteDefaultAutomaticMappingAndGetMappingStatistics(Cancel, RowIndexes = Undefined) Export
	
	SetPrivilegedMode(True);
	
	If RowIndexes = Undefined Then
		
		RowIndexes = New Array;
		
		For Each TableRow In Statistics Do
			
			RowIndexes.Add(Statistics.IndexOf(TableRow));
			
		EndDo;
		
	EndIf;
	
	// Importing data from the exchange message into the cache for several tables at the same time
	ExecuteDataImportFromExchangeMessagesIntoCache(Cancel, RowIndexes);
	
	If Cancel Then
		Return;
	EndIf;
	
	InfoBaseObjectMapping = DataProcessors.InfoBaseObjectMapping.Create();
	
	// Performing automatic mapping.
	// Getting mapping digest data.
	For Each RowIndex In RowIndexes Do
		
		TableRow = Statistics[RowIndex];
		
		If Not TableRow.SynchronizeByID Then
			Continue;
		EndIf;
		
		// Initializing data processor properties
		InfoBaseObjectMapping.TargetTableName           = TableRow.TargetTableName;
		InfoBaseObjectMapping.SourceTableObjectTypeName = TableRow.ObjectTypeString;
		InfoBaseObjectMapping.TargetTableFields         = TableRow.TableFields;
		InfoBaseObjectMapping.TargetTableSearchFields   = TableRow.SearchFields;
		InfoBaseObjectMapping.InfoBaseNode              = InfoBaseNode;
		InfoBaseObjectMapping.ExchangeMessageFileName   = ExchangeMessageFileName;
		
		InfoBaseObjectMapping.SourceTypeString = TableRow.SourceTypeString;
		InfoBaseObjectMapping.TargetTypeString = TableRow.TargetTypeString;
		
		// Constructor
		InfoBaseObjectMapping.Constructor();
		
		// Performing default automatic object mapping  
		InfoBaseObjectMapping.ExecuteDefaultAutomaticMapping(Cancel);
		
		// Getting mapping digest data
		InfoBaseObjectMapping.GetObjectMappingDigestInfo(Cancel);
		
		// Mapping digest data
		TableRow.ObjectCountInSource = InfoBaseObjectMapping.ObjectCountInSource();
		TableRow.ObjectCountInTarget = InfoBaseObjectMapping.ObjectCountInTarget();
		TableRow.MappedObjectCount   = InfoBaseObjectMapping.MappedObjectCount();
		TableRow.UnmappedObjectCount = InfoBaseObjectMapping.UnmappedObjectCount();
		TableRow.MappedObjectPercent = InfoBaseObjectMapping.MappedObjectPercent();
		TableRow.PictureIndex        = DataExchangeServer.StatisticsTablePictureIndex(TableRow.UnmappedObjectCount, TableRow.DataImportedSuccessfully);
		
	EndDo;
	
EndProcedure

// Imports data into the infobase for Statistics table rows.
// If all exchange message data is imported, the incoming exchange message number is 
// stored in the exchange node.
// The repeat import of this message will be canceled.
//
// Parameters:
//  Cancel     – Boolean – cancel flag. It is set to True if errors occur during the
//               procedure execution.
//  RowIndexes – Array (optional) – indexes of Statistics table rows for which mapping
//               statistic information will be retrieved.

//               If the parameter is not specified, starictic data for all table rows 
//               will be retrieved.
// 
Procedure ExecuteDataImport(Cancel, RowIndexes = Undefined) Export
	
	SetPrivilegedMode(True);
	
	If RowIndexes = Undefined Then
		
		RowIndexes = New Array;
		
		For Each TableRow In Statistics Do
			
			RowIndexes.Add(Statistics.IndexOf(TableRow));
			
		EndDo;
		
	EndIf;
	
	TableToImport = New Array;
	
	For Each RowIndex In RowIndexes Do
		
		TableRow = Statistics[RowIndex];
		
		DataTableKey = DataExchangeServer.DataTableKey(TableRow.SourceTypeString, TableRow.TargetTypeString, TableRow.IsObjectDeletion);
		
		TableToImport.Add(DataTableKey);
		
	EndDo;
	
	// Initializing data processor properties
	InfoBaseObjectMapping = DataProcessors.InfoBaseObjectMapping.Create();
	InfoBaseObjectMapping.ExchangeMessageFileName = ExchangeMessageFileName;
	InfoBaseObjectMapping.InfoBaseNode = InfoBaseNode;
	
	// Importing data
	InfoBaseObjectMapping.ExecuteDataImportForInfoBase(Cancel, TableToImport);
	
	DataImportedSuccessfully = Not Cancel;
	
	For Each RowIndex In RowIndexes Do
		
		TableRow = Statistics[RowIndex];
		
		TableRow.DataImportedSuccessfully = DataImportedSuccessfully;
		TableRow.PictureIndex = DataExchangeServer.StatisticsTablePictureIndex(TableRow.UnmappedObjectCount, TableRow.DataImportedSuccessfully);
	
	EndDo;
	
	// If all exchange message data is imported, the incoming exchange message number is 
	// stored in the exchange node.
	If DataPackageFullyImported() Then
		
		SetIncomingInfoBaseNodeMessageNumber(Cancel);
		
	EndIf;
	
EndProcedure

// Downloads the exchange message from an external source (FTP, email, or network directory) into the temporary operating system user directory.
//
// Parameters: 
//  Cancel            – Boolean – cancel flag. It is set to True if errors occur during 
//                      the procedure execution.
//  DataPackageFileID – DateTime – exchange message change date. Is used as a file ID
//                      for the data exchange subsystem.
// 
Procedure GetExchangeMessageToTemporaryDirectory(
	Cancel,
	DataPackageFileID = Undefined,
	FileID = "",
	LongAction = False,
	ActionID = ""
	) Export
	
	SetPrivilegedMode(True);
	
	// Deleting previous temporary exchange message directory with all nested files
	DeleteTempExchangeMessageDirectory(TempExchangeMessageDirectory);
	
	If ExchangeMessageTransportKind = Enums.ExchangeMessageTransportKinds.COM Then
		
		DataStructure = DataExchangeServer.GetExchangeMessageFromCorrespondentInfoBaseToTempDirectory(Cancel, InfoBaseNode);
		
	ElsIf ExchangeMessageTransportKind = Enums.ExchangeMessageTransportKinds.WS Then
		
		DataStructure = DataExchangeServer.GetExchangeMessageToTempDirectoryFromCorrespondentInfoBaseOverWebService(
		Cancel,
		InfoBaseNode,
		FileID,
		LongAction,
		ActionID
		);
		
	Else // file, FTP, email
		
		DataStructure = DataExchangeServer.GetExchangeMessageToTemporaryDirectory(Cancel, InfoBaseNode, ExchangeMessageTransportKind);
		
	EndIf;
	
	TempExchangeMessageDirectory = DataStructure.TempExchangeMessageDirectory;
	DataPackageFileID            = DataStructure.DataPackageFileID;
	ExchangeMessageFileName      = DataStructure.ExchangeMessageFileName;
	
EndProcedure

// Downloads the exchange message from the file transfer service into the temporary 
// operating system user directory.
//
Procedure GetExchangeMessageToTempDirectoryLongActionEnd(
	Cancel,
	DataPackageFileID,
	FileID
	) Export
	
	SetPrivilegedMode(True);
	
	// Deleting previous temporary exchange message directory with all nested files
	DeleteTempExchangeMessageDirectory(TempExchangeMessageDirectory);
	
	DataStructure = DataExchangeServer.GetExchangeMessageToTempDirectoryFromCorrespondentInfoBaseOverWebServiceFinishLongAction(
	Cancel,
	InfoBaseNode,
	FileID
	);
	
	TempExchangeMessageDirectory = DataStructure.TempExchangeMessageDirectory;
	DataPackageFileID            = DataStructure.DataPackageFileID;
	ExchangeMessageFileName      = DataStructure.ExchangeMessageFileName;
	
EndProcedure

// Analyses the incoming exchange message. Fills the Statistics table. 
//
// Parameters:
//  Cancel         – Boolean – cancel flag. It is set to True if errors occur during 
//                   the procedure execution.
//  ReceiveMessage - Boolean - exchange message is considered as received if all message
//                   data was imported.
//                   If it is True, the incoming exchange message number is stored in
//                   the exchange, otherwise the message number is not stored even if 
//                   all message data was successfully imported.
//
Procedure ExecuteExchangeMessagAnalysis(Cancel, ReceiveMessage = True) Export
	
	If IsBlankString(TempExchangeMessageDirectory) Then
		
		NString = NStr("en = 'Data cannot be read because the exchange message transport error occurs.'");
		CommonUseClientServer.MessageToUser(NString,,,, Cancel);
		
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	
	DataExchangeDataProcessor = DataExchangeCached.DataImportDataProcessor(Cancel, InfoBaseNode, ExchangeMessageFileName);
	
	If Cancel Then
		Return;
	EndIf;
	
	DataExchangeDataProcessor.ExecuteExchangeMessagAnalysis();
	
	If DataExchangeDataProcessor.ErrorFlag() Then
		
		NString = NStr("en = 'Error: %1'");
		NString = StringFunctionsClientServer.SubstituteParametersInString(NString, DataExchangeDataProcessor.ErrorMessageString());
		CommonUseClientServer.MessageToUser(NString,,,, Cancel);
		Return;
	EndIf;
	
	IncomingMessageNumber = DataExchangeDataProcessor.MessageNumber();
	
	Statistics.Load(DataExchangeDataProcessor.PackageHeaderDataTable());
	
	// Supplying the statistic table with utility data
	SupplementStatisticTable(Cancel);
	
	// Determining table strings with the OneToMany flag
	TempStatistics = Statistics.Unload(, "TargetTableName, IsObjectDeletion");
	
	AddColumnWithValueToTable(TempStatistics, 1, "Iterator");
	
	TempStatistics.GroupBy("TargetTableName, IsObjectDeletion", "Iterator");
	
	For Each TableRow In TempStatistics Do
		
		If TableRow.Iterator > 1 And Not TableRow.IsObjectDeletion Then
			
			Rows = Statistics.FindRows(New Structure("TargetTableName, IsObjectDeletion",
				TableRow.TargetTableName, TableRow.IsObjectDeletion));
			
			For Each Row In Rows Do
				
				Row["OneToMany"] = True;
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
	// If all exchange message data was imported, the incoming exchange message number is 
	// stored in the exchange node.
	If ReceiveMessage And DataPackageFullyImported() Then
		
		SetIncomingInfoBaseNodeMessageNumber(Cancel);
		
	EndIf;
	
EndProcedure

///////////////////////////////////////////////////////////////////////////////
// Local internal procedures and functions.

// Imports data tables from the exchange message into the cache.
// Only tables that were not imported previously is imported.
// The DataExchangeDataProcessor variable contains (caches) previously imported tables.

// 

Procedure ExecuteDataImportFromExchangeMessagesIntoCache(Cancel, RowIndexes)
	
	DataExchangeDataProcessor = DataExchangeCached.DataImportDataProcessor(Cancel, InfoBaseNode, ExchangeMessageFileName);
	
	If Cancel Then
		Return;
	EndIf;
	
	// Getting the array of tables to be batchly imported into the platform cache
	TableToImport = New Array;
	
	For Each RowIndex In RowIndexes Do
		
		TableRow = Statistics[RowIndex];
		
		If Not TableRow.SynchronizeByID Then
			Continue;
		EndIf;
		
		DataTableKey = DataExchangeServer.DataTableKey(TableRow.SourceTypeString, TableRow.TargetTypeString, TableRow.IsObjectDeletion);
		
		// Perhaps, the data table is already imported and is placed in the
   // DataExchangeDataProcessor data processor cache. 
		DataTable = DataExchangeDataProcessor.ExchangeMessageDataTable().Get(DataTableKey);
		
		If DataTable = Undefined Then
			
			TableToImport.Add(DataTableKey);
			
		EndIf;
		
	EndDo;
	
	// Importing tables into the cache batchly
	If TableToImport.Count() > 0 Then
		
		DataExchangeDataProcessor.ExecuteDataImportIntoValueTable(TableToImport);
		
		If DataExchangeDataProcessor.ErrorFlag() Then
			
			NString = NStr("en = 'Error importing the exchange message: %1'");
			NString = StringFunctionsClientServer.SubstituteParametersInString(NString, DataExchangeDataProcessor.ErrorMessageString());
			CommonUseClientServer.MessageToUser(NString,,,, Cancel);
			Return;
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure SetIncomingInfoBaseNodeMessageNumber(Cancel)
	
	InfoBaseNodeObject = InfoBaseNode.GetObject();
	InfoBaseNodeObject.ReceivedNo = IncomingMessageNumber;
	InfoBaseNodeObject.AdditionalProperties.Insert("GettingExchangeMessage");
	
	Try
		InfoBaseNodeObject.Write();
	Except
		CommonUseClientServer.MessageToUser(BriefErrorDescription(ErrorInfo()),,,, Cancel);
	EndTry;
	
EndProcedure

Procedure DeleteTempExchangeMessageDirectory(TempDirectoryName)
	
	If Not IsBlankString(TempDirectoryName) Then
		
		Try
			DeleteFiles(TempDirectoryName);
			TempDirectoryName = "";
		Except
		EndTry;
		
	EndIf;
	
EndProcedure

Procedure SupplementStatisticTable(Cancel)
	
	For Each TableRow In Statistics Do
		
		Try
			Type = Type(TableRow.ObjectTypeString);
		Except
			
			MessageString = NStr("en = 'Error: the %1 type is not defined.'");
			MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, TableRow.ObjectTypeString);
			CommonUseClientServer.MessageToUser(MessageString,,,, Cancel);
			Continue;
			
		EndTry;
		
		TableRow.TargetTableName = GetTableNameByType(Type);
		TableRow.Key = String(New UUID());
		
	EndDo;
	
EndProcedure

Procedure AddColumnWithValueToTable(Table, IteratorValue, IteratorFieldName)
	
	Table.Columns.Add(IteratorFieldName);
	
	Table.FillValues(IteratorValue, IteratorFieldName);
	
EndProcedure

Function GetTableNameByType(Type)
	
	Return Metadata.FindByType(Type).FullName();
	
EndFunction

Function DataPackageFullyImported()
	
	SuccessfulImportTable = Statistics.Unload(New Structure("DataImportedSuccessfully", True) ,"DataImportedSuccessfully");
	
	Return SuccessfulImportTable.Count() = Statistics.Count();
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Functions for retrieving properties.

// Retrieves Statistics tabular section data.
//
// Returns:
//  ValueTable.
//
Function StatisticsTable() Export
	
	Return Statistics.Unload();
	
EndFunction
