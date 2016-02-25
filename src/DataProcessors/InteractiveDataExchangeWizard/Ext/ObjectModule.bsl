#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region InternalProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Export internal procedures and functions.

// Gets object mapping statistics for the Statistics table rows.
//
// Parameters:
//      Cancel     - Boolean - cancellation flag. It is set to True if errors occur during the
//                   procedure execution. 
//      RowIndexes - Array - indexes of Statistics table rows. Mapping 
//                   statistics data is retrieved for these rows.
//                   If the parameter is not specified, statistics data is retrieved for all table rows.
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
	
	InfobaseObjectMapping = DataProcessors.InfobaseObjectMapping.Create();
	
	// Getting mapping digest data separately for each table
	For Each LineIndex In RowIndexes Do
		
		TableRow = Statistics[LineIndex];
		
		If Not TableRow.SynchronizeByID Then
			Continue;
		EndIf;
		
		// Initializing data processor properties
		InfobaseObjectMapping.TargetTableName           = TableRow.TargetTableName;
		InfobaseObjectMapping.SourceTableObjectTypeName = TableRow.ObjectTypeString;
		InfobaseObjectMapping.InfobaseNode              = InfobaseNode;
		InfobaseObjectMapping.ExchangeMessageFileName   = ExchangeMessageFileName;
		
		InfobaseObjectMapping.SourceTypeString = TableRow.SourceTypeString;
		InfobaseObjectMapping.TargetTypeString = TableRow.TargetTypeString;
		
		// constructor
		InfobaseObjectMapping.Constructor();
		
		// Getting mapping digest data
		InfobaseObjectMapping.GetObjectMappingDigestInfo(Cancel);
		
		// Mapping digest information
		TableRow.ObjectCountInSource = InfobaseObjectMapping.ObjectCountInSource();
		TableRow.ObjectCountInTarget = InfobaseObjectMapping.ObjectCountInTarget();
		TableRow.MappedObjectCount   = InfobaseObjectMapping.MappedObjectCount();
		TableRow.UnmappedObjectCount = InfobaseObjectMapping.UnmappedObjectCount();
		TableRow.MappedObjectPercent = InfobaseObjectMapping.MappedObjectPercent();
		TableRow.PictureIndex        = DataExchangeServer.StatisticsTablePictureIndex(TableRow.UnmappedObjectCount, TableRow.DataImportedSuccessfully);
		
	EndDo;
	
EndProcedure

// Automatically maps infobase objects with the specified default values and then
// retrieves object mapping statistics.
//
// Parameters:
//      Cancel     - Boolean - cancellation flag. It is set to True if errors occur during the
//                   procedure execution. 
//      RowIndexes - Array - indexes of Statistics table rows. Mapping statistics data is retrieved for these rows.
//                   If the parameter is not specified, statictics data is retrieved for all table rows.
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
	
	InfobaseObjectMapping = DataProcessors.InfobaseObjectMapping.Create();
	
	// Performing automatic mapping.
	// Getting mapping digest data.
	For Each LineIndex In RowIndexes Do
		
		TableRow = Statistics[LineIndex];
		
		If Not TableRow.SynchronizeByID Then
			Continue;
		EndIf;
		
		// Initializing data processor properties
		InfobaseObjectMapping.TargetTableName           = TableRow.TargetTableName;
		InfobaseObjectMapping.SourceTableObjectTypeName = TableRow.ObjectTypeString;
		InfobaseObjectMapping.TargetTableFields         = TableRow.TableFields;
		InfobaseObjectMapping.TargetTableSearchFields   = TableRow.SearchFields;
		InfobaseObjectMapping.InfobaseNode              = InfobaseNode;
		InfobaseObjectMapping.ExchangeMessageFileName   = ExchangeMessageFileName;
		
		InfobaseObjectMapping.SourceTypeString = TableRow.SourceTypeString;
		InfobaseObjectMapping.TargetTypeString = TableRow.TargetTypeString;
		
		// Constructor
		InfobaseObjectMapping.Constructor();
		
		// Performing default automatic object mapping
		InfobaseObjectMapping.ExecuteDefaultAutomaticMapping(Cancel);
		
		// Getting mapping digest data
		InfobaseObjectMapping.GetObjectMappingDigestInfo(Cancel);
		
		// Mapping digest data
		TableRow.ObjectCountInSource = InfobaseObjectMapping.ObjectCountInSource();
		TableRow.ObjectCountInTarget = InfobaseObjectMapping.ObjectCountInTarget();
		TableRow.MappedObjectCount   = InfobaseObjectMapping.MappedObjectCount();
		TableRow.UnmappedObjectCount = InfobaseObjectMapping.UnmappedObjectCount();
		TableRow.MappedObjectPercent = InfobaseObjectMapping.MappedObjectPercent();
		TableRow.PictureIndex        = DataExchangeServer.StatisticsTablePictureIndex(TableRow.UnmappedObjectCount, TableRow.DataImportedSuccessfully);
		
	EndDo;
	
EndProcedure

// Imports data into the infobase for Statistics table rows.
//  If all exchange message data is imported, the incoming exchange message number is 
//  stored in the exchange node.
//  It implies that all data is imported to the infobase.
//  The repeat import of this message will be canceled.
//
// Parameters:
//       Cancel     - Boolean - cancellation flag. It is set to True if errors occur during the 
//                    procedure execution. 
//       RowIndexes - Array - indexes of Statistics table rows. Data is imported to these rows.
//                    If the parameter is not specified, statistics data is retrieved for all table rows
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
	
	For Each LineIndex In RowIndexes Do
		
		TableRow = Statistics[LineIndex];
		
		DataTableKey = DataExchangeServer.DataTableKey(TableRow.SourceTypeString, TableRow.TargetTypeString, TableRow.IsObjectDeletion);
		
		TableToImport.Add(DataTableKey);
		
	EndDo;
	
	// Initializing data processor properties
	InfobaseObjectMapping = DataProcessors.InfobaseObjectMapping.Create();
	InfobaseObjectMapping.ExchangeMessageFileName = ExchangeMessageFileName;
	InfobaseObjectMapping.InfobaseNode  = InfobaseNode;
	
	// Importing data
	InfobaseObjectMapping.ExecuteDataImportForInfobase(Cancel, TableToImport);
	
	DataImportedSuccessfully = Not Cancel;
	
	For Each LineIndex In RowIndexes Do
		
		TableRow = Statistics[LineIndex];
		
		TableRow.DataImportedSuccessfully = DataImportedSuccessfully;
		TableRow.PictureIndex = DataExchangeServer.StatisticsTablePictureIndex(TableRow.UnmappedObjectCount, TableRow.DataImportedSuccessfully);
	
	EndDo;
	
EndProcedure

// Downloads the exchange message from an external source 
// (FTP, email, or network directory) into the temporary operating system user directory.
//
// Parameters:
//      Cancel            - Boolean - cancellation flag. It is set to True if errors occur during
//                          the procedure execution.
//      DataPackageFileID - Date - exchange message change date. It is used as a file ID for the data exchange subsystem.
// 
Procedure GetExchangeMessageToTemporaryDirectory(
		Cancel,
		DataPackageFileID = Undefined,
		FileID = "",
		LongAction = False,
		ActionID = "",
		Password = ""
	) Export
	
	SetPrivilegedMode(True);
	
	// Deleting previous temporary exchange message directory with all nested files
	DeleteTempExchangeMessageDirectory(TempExchangeMessageDirectory);
	
	If ExchangeMessageTransportKind = Enums.ExchangeMessageTransportKinds.COM Then
		
		DataStructure = DataExchangeServer.GetExchangeMessageFromCorrespondentInfobaseToTempDirectory(Cancel, InfobaseNode, False);
		
	ElsIf ExchangeMessageTransportKind = Enums.ExchangeMessageTransportKinds.WS Then
		
		DataStructure = DataExchangeServer.GetExchangeMessageToTempDirectoryFromCorrespondentInfobaseOverWebService(
				Cancel,
				InfobaseNode,
				FileID,
				LongAction,
				ActionID,
				Password);
		
	Else // FILE, FTP, EMAIL
		
		DataStructure = DataExchangeServer.GetExchangeMessageToTemporaryDirectory(Cancel, InfobaseNode, ExchangeMessageTransportKind, False);
		
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
			FileID,
			Val Password = ""
	) Export
	
	SetPrivilegedMode(True);
	
	// Deleting previous temporary exchange message directory with all nested files
	DeleteTempExchangeMessageDirectory(TempExchangeMessageDirectory);
	
	DataStructure = DataExchangeServer.GetExchangeMessageToTempDirectoryFromCorrespondentInfobaseOverWebServiceFinishLongAction(
		Cancel,
		InfobaseNode,
		FileID,
		Password);
	
	TempExchangeMessageDirectory = DataStructure.TempExchangeMessageDirectory;
	DataPackageFileID            = DataStructure.DataPackageFileID;
	ExchangeMessageFileName      = DataStructure.ExchangeMessageFileName;
	
EndProcedure

// Analyses the incoming exchange message. Fills the Statistics table.
//
// Parameters:
//      Cancel - Boolean - cancellation flag. It is set to True if errors occur during
//               the procedure execution.
//
Procedure ExecuteExchangeMessagAnalysis(Cancel) Export
	
	If IsBlankString(TempExchangeMessageDirectory) Then
		// Data from the correspondent infobase cannot be received
		Cancel = True;
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	
	DataExchangeDataProcessor = DataExchangeServer.DataImportDataProcessor(Cancel, InfobaseNode, ExchangeMessageFileName);
	
	If Cancel Then
		Return;
	EndIf;
	
	DataExchangeDataProcessor.ExecuteExchangeMessagAnalysis();
	
	If DataExchangeDataProcessor.ErrorFlag() Then
		Cancel = True;
		Return;
	EndIf;
	
	Statistics.Load(DataExchangeDataProcessor.PackageHeaderDataTable());
	
	// Supplying the statistic table with utility data
	SupplementStatisticTable(Cancel);
	
	// Determining table strings with the OneToMany flag
	TempStatistics = Statistics.Unload(, "TargetTableName, IsObjectDeletion");
	
	AddColumnWithValueToTable(TempStatistics, 1, "Iterator");
	
	TempStatistics.Collapse("TargetTableName, IsObjectDeletion", "Iterator");
	
	For Each TableRow In TempStatistics Do
		
		If TableRow.Iterator > 1 And Not TableRow.IsObjectDeletion Then
			
			Rows = Statistics.FindRows(New Structure("TargetTableName, IsObjectDeletion",
				TableRow.TargetTableName, TableRow.IsObjectDeletion));
			
			For Each Row In Rows Do
				
				Row["OneToMany"] = True;
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
EndProcedure

///////////////////////////////////////////////////////////////////////////////
// Local internal procedures and functions

// Imports data tables from the exchange message into the cache.
// Only tables that were not imported previously is imported.
// The DataExchangeDataProcessor variable contains (caches) previously imported tables.
//
// Parameters:
//       Cancel     - Boolean - cancellation flag. It is set to True if errors occur during
//                    the procedure execution. 
//       RowIndexes - Array - indexes of Statistics table rows. Data is imported to these rows.
//                    If the parameter is not specified, statictics data is retrieved for all table rows. 
// 
Procedure ExecuteDataImportFromExchangeMessagesIntoCache(Cancel, RowIndexes)
	
	DataExchangeDataProcessor = DataExchangeServer.DataImportDataProcessor(Cancel, InfobaseNode, ExchangeMessageFileName);
	
	If Cancel Then
		Return;
	EndIf;
	
	// Getting the array of tables to be batchly imported into the platform cache
	TableToImport = New Array;
	
	For Each LineIndex In RowIndexes Do
		
		TableRow = Statistics[LineIndex];
		
		If Not TableRow.SynchronizeByID Then
			Continue;
		EndIf;
		
		DataTableKey = DataExchangeServer.DataTableKey(TableRow.SourceTypeString, TableRow.TargetTypeString, TableRow.IsObjectDeletion);
		
		// Perhaps the data table is already imported and is placed 
   // in the DataExchangeDataProcessor data processor cache.
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
		
		ObjectMetadata = Metadata.FindByType(Type);
		
		TableRow.TargetTableName = ObjectMetadata.FullName();
		TableRow.Presentation       = ObjectMetadata.Presentation();
		
		TableRow.Key = String(New UUID());
		
	EndDo;
	
EndProcedure

Procedure AddColumnWithValueToTable(Table, IteratorValue, IteratorFieldName)
	
	Table.Columns.Add(IteratorFieldName);
	
	Table.FillValues(IteratorValue, IteratorFieldName);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Functions for retrieving properties.

// Retrieves Statistics tabular section data.
//
// Returns:
//  ValueTable - Statistics tabular section data.
//
Function StatisticsTable() Export
	
	Return Statistics.Unload();
	
EndFunction

#EndRegion

#EndIf
