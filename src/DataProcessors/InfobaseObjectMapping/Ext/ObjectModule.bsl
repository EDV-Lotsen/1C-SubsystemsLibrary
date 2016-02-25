#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

Var MappingTableField;
Var ObjectMappingStatisticsField;
Var MappingDigestField;
Var UnlimitedLengthStringTypeField;

#Region InternalProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Export internal procedures and functions.

// Maps objects from the current infobase to objects from the source Infobase.
// Generates a mapping table to be displayed to the user.
// Detects the following types of object mapping:
// - objects mapped using references
// - objects mapped using InfobaseObjectMaps information register data.
// - objects mapped using unapproved mapping. Unapproved mapping items are
//   mapping items that are not written to the infobase (current changes).
// - unmapped source objects.
// - unmapped target objects (objects of the current infobase).

//
// Parameters:
//  Cancel – Boolean – cancellation flag. It is set to True if errors occur during the 
//           procedure execution.

// 
Procedure ExecuteObjectMapping(Cancel) Export
	
	SetPrivilegedMode(True);
	
	// Executing infobase object mapping
	ExecuteInfobaseObjectMapping(Cancel);
	
EndProcedure

// Maps objects automatically using the mapping fields specified by the user (search fields).
// Compares mapping fields using strict equality.
// Generates a table of automatic mapping to be displayed to the user.
//
// Parameters:
//  Cancel           – Boolean – cancellation flag. It is set to True if errors occur during 
//                     the procedure execution.
//  MappingFieldList – ValueList – value list whose fields will be used for mapping objects.

// 
Procedure ExecuteAutomaticObjectMapping(Cancel, MappingFieldList) Export
	
	SetPrivilegedMode(True);
	
	ExecuteAutomaticInfobaseObjectMapping(Cancel, MappingFieldList);
	
EndProcedure

// Maps objects automatically using the default search fields.
// The list of mapping fields is equal to the list of used fields.

//
//  Cancel - Boolean - cancellation flag. It is set to True if errors occur during 
//           the procedure execution.

// 
Procedure ExecuteDefaultAutomaticMapping(Cancel) Export
	
	SetPrivilegedMode(True);
	
	// If automatic mapping using the default fields is performed, the list of fields to be mapped is equal to the list
	// of used fields.

	MappingFieldList = UsedFieldList.Copy();
	
	ExecuteDefaultAutomaticInfobaseObjectMapping(Cancel, MappingFieldList);
	
	// Applying the automatic mapping result
	ApplyUnapprovedRecordTable(Cancel);
	
EndProcedure

// Writes unapproved mapping references (current changes) into the infobase.
// Records are stored in the InfobaseObjectMaps information register.
//
// Parameters:
//  Cancel - Boolean - cancellation flag. It is set to True if errors occur during 
//           the procedure execution.
// 
Procedure ApplyUnapprovedRecordTable(Cancel) Export
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	
	Try
		
		For Each TableRow In UnapprovedMappingTable Do
			
			RecordStructure = New Structure("SourceUUID, TargetUUID, SourceType, TargetType");
			
			RecordStructure.Insert("InfobaseNode", InfobaseNode);
			
			FillPropertyValues(RecordStructure, TableRow);
			
			InformationRegisters.InfobaseObjectMappings.AddRecord(RecordStructure);
			
		EndDo;
		
		CommitTransaction();
	Except
		WriteLogEvent(NStr("en = 'Data exchange'", CommonUseClientServer.DefaultLanguageCode()),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo())
		);
		Cancel = True;
		RollbackTransaction();
		Return;
	EndTry;
	
	UnapprovedMappingTable.Clear();
	
EndProcedure

// Retrieves object mapping statistic data.
// Initializes the MappingDigest property.
//
// Parameters:
//  Cancel - Boolean - cancellation flag. It is set to True if errors occur during the 
//           procedure execution.
// 
Procedure GetObjectMappingDigestInfo(Cancel) Export
	
	SetPrivilegedMode(True);
	
	SourceTable = GetSourceInfobaseTable(Cancel);
	
	If Cancel Then
		Return;
	EndIf;
	
	// Specifying a blank array of user fields because there is no need to select fields
	UserFields = New Array;
	
	TempTablesManager = New TempTablesManager;
	
	// Getting object mapping tables (mapped, unmapped)
	GetObjectMappingTables(SourceTable, UserFields, TempTablesManager);
	
	// Getting object mapping digest data
	GetMappingDigest(TempTablesManager);
	
	TempTablesManager.Close();
	
EndProcedure

// Imports data from the exchange message file into the infobase for the specified 
// object types only.
//
// Parameters:
//  Cancel        - Boolean - cancellation flag. It is set to True if errors occur during the 
//                  procedure execution.
//  TableToImport - Array of String - array of types to be imported from the exchange
//                  message.
// 
Procedure ExecuteDataImportForInfobase(Cancel, TableToImport) Export
	
	SetPrivilegedMode(True);
	
	DataImportedSuccessfully = False;
	
	DataExchangeDataProcessor = DataExchangeServer.DataImportDataProcessor(Cancel, InfobaseNode, ExchangeMessageFileName);
	
	If Cancel Then
		Return;
	EndIf;
	
	DataExchangeDataProcessor.ExecuteDataImportForInfobase(TableToImport);
	
	// Deleting tables imported to the infobase from the data processor cache, because they are obsolete
	For Each Item In TableToImport Do
		DataExchangeDataProcessor.ExchangeMessageDataTable().Delete(Item);
	EndDo;
	
	If DataExchangeDataProcessor.ErrorFlag() Then
		NString = NStr("en = 'Error importing the exchange message: %1'");
		NString = StringFunctionsClientServer.SubstituteParametersInString(NString, DataExchangeDataProcessor.ErrorMessageString());
		CommonUseClientServer.MessageToUser(NString,,,, Cancel);
		Return;
	EndIf;
	
	DataImportedSuccessfully = Not DataExchangeDataProcessor.ErrorFlag();
	
EndProcedure

// Data processor constructor.
//
Procedure Constructor() Export
	
	// Filling table field list. Fields from this list can be mapped and displayed (search fields).
	TableFieldList.LoadValues(StringFunctionsClientServer.SplitStringIntoSubstringArray(TargetTableFields));
	
	SearchFieldArray = StringFunctionsClientServer.SplitStringIntoSubstringArray(TargetTableSearchFields);
	
	// Selecting search fields if they are not specified
	If SearchFieldArray.Count() = 0 Then
		
		// For catalogs
		AddSearchField(SearchFieldArray, "Description");
		AddSearchField(SearchFieldArray, "Code");
		AddSearchField(SearchFieldArray, "Owner");
		AddSearchField(SearchFieldArray, "Parent");
		
		// For documents and business processes
		AddSearchField(SearchFieldArray, "Date");
		AddSearchField(SearchFieldArray, "Number");
		
		// Popular search fields
		AddSearchField(SearchFieldArray, "Company");
		AddSearchField(SearchFieldArray, "TIN");
		AddSearchField(SearchFieldArray, "TRRC");
		
		If SearchFieldArray.Count() = 0 Then
			
			If TableFieldList.Count() > 0 Then
				
				SearchFieldArray.Add(TableFieldList[0].Value);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// Deleting fields with indexes exceeding the specified limit from the search array
	CheckMappingFieldCountInArray(SearchFieldArray);
	
	// Selecting search fields in TableFieldList
	For Each Item In TableFieldList Do
		
		If SearchFieldArray.Find(Item.Value) <> Undefined Then
			
			Item.Check = True;
			
		EndIf;
		
	EndDo;
	
	FillListWithAdditionalParameters(TableFieldList);
	
	// Filling UsedFieldList with selected items of TableFieldList
	FillListWithSelectedItems(TableFieldList, UsedFieldList);
	
	// Generating the sorting table
	FillSortTable(UsedFieldList);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Functions for retrieving properties.

// Retrieves object mapping table.
//
// Returns:
//      ValueTable - object mapping table.
//
Function MappingTable() Export
	
	If TypeOf(MappingTableField) <> Type("ValueTable") Then
		
		MappingTableField = New ValueTable;
		
	EndIf;
	
	Return MappingTableField;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Functions for retrieving properties of the mapping digest.

// Retrieves the number of objects of the current data type in the exchange message file.
//
// Returns:
//     Number - number of objects of the current data type in the exchange message file.
//
Function ObjectCountInSource() Export
	
	Return MappingDigest().ObjectCountInSource;
	
EndFunction

// Retrieves the number of objects of the current data type in this infobase.
//
// Returns:
//     Number - number of objects of the current data type in this infobase.
//
Function ObjectCountInTarget() Export
	
	Return MappingDigest().ObjectCountInTarget;
	
EndFunction

// Retrieves the number of objects that are mapped for the current data type.
//
// Returns:
//     Number - number of objects that are mapped for the current data type.
//
Function MappedObjectCount() Export
	
	Return MappingDigest().MappedObjectCount;
	
EndFunction

// Retrieves the number of objects that are not mapped for the current data type.
//
// Returns:
//     Number - number of objects that are not mapped for the current data type.
//
Function UnmappedObjectCount() Export
	
	Return MappingDigest().UnmappedObjectCount;
	
EndFunction

// Retrieves object mapping percentage for the current data type.
//
// Returns:
//     Number - object mapping percentage for the current data type.
//
Function MappedObjectPercent() Export
	
	Return MappingDigest().MappedObjectPercent;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Functions for retrieving local properties.

Function MappingDigest()
	
	If TypeOf(MappingDigestField) <> Type("Structure") Then
		
		// Initializing object mapping digest structure
		MappingDigestField = New Structure;
		MappingDigestField.Insert("ObjectCountInSource", 0);
		MappingDigestField.Insert("ObjectCountInTarget", 0);
		MappingDigestField.Insert("MappedObjectCount",   0);
		MappingDigestField.Insert("UnmappedObjectCount", 0);
		MappingDigestField.Insert("MappedObjectPercent", 0);
		
	EndIf;
	
	Return MappingDigestField;
	
EndFunction

Function ObjectMappingStatistics()
	
	If TypeOf(ObjectMappingStatisticsField) <> Type("Structure") Then
		
		// Initializing statistic data structure
		ObjectMappingStatisticsField = New Structure;
		ObjectMappingStatisticsField.Insert("MappedByRegisterSourceObjectCount",      0);
		ObjectMappingStatisticsField.Insert("MappedByRegisterTargetObjectCount",      0);
		ObjectMappingStatisticsField.Insert("MappedByUnapprovedRelationsObjectCount", 0);
		
	EndIf;
	
	Return ObjectMappingStatisticsField;
	
EndFunction

Function UnlimitedLengthStringType()
	
	If TypeOf(UnlimitedLengthStringTypeField) <> Type("TypeDescription") Then
		
		UnlimitedLengthStringTypeField = New TypeDescription("String",, New StringQualifiers(0));
		
	EndIf;
	
	Return UnlimitedLengthStringTypeField;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Getting the mapping table.

Procedure ExecuteInfobaseObjectMapping(Cancel)
	
	SourceTable = GetSourceInfobaseTable(Cancel);
	
	If Cancel Then
		Return;
	EndIf;
	
	// Getting an array of fields that were selected by the user
	UserFields = UsedFieldList.UnloadValues();
	
	// The IsFolder field is always present for hierarchical catalogs
	If UserFields.Find("IsFolder") = Undefined Then
		
		AddSearchField(UserFields, "IsFolder");
		
	EndIf;
	
	TempTablesManager = New TempTablesManager;
	
	// Getting object mapping tables (mapped, unmapped)
	GetObjectMappingTables(SourceTable, UserFields, TempTablesManager);
	
	// Getting object mapping digest data
	GetMappingDigest(TempTablesManager);
	
	// Getting the mapping table
	MappingTableField = GetMappingTable(SourceTable, UserFields, TempTablesManager);
	
	TempTablesManager.Close();
	
	// Sorting the table
	ExecuteTableSortingAtServer();
	
	// Adding the SerialNumber field and filling it
	AddNumberFieldToMappingTable();
	
EndProcedure

Procedure ExecuteAutomaticInfobaseObjectMapping(Cancel, MappingFieldList)
	
	SourceTable = GetSourceInfobaseTable(Cancel);
	
	If Cancel Then
		Return;
	EndIf;
	
	// User fields are filled according to the following algorithm:
	//  - adding fields selected by user to be displayed;
	//  - adding all other table fields.
	// Field order is important when automatic mapping result table is being displayed.

	UserFields = New Array;
	
	For Each Item In UsedFieldList Do
		
		UserFields.Add(Item.Value);
		
	EndDo;
	
	For Each Item In TableFieldList Do
		
		If UserFields.Find(Item.Value) = Undefined Then
			
			UserFields.Add(Item.Value);
			
		EndIf;
		
	EndDo;
	
	// The mapping field list is filled according to the order of elements in the UserFields array
	MappingFieldListNew = New ValueList;
	
	For Each Item In UserFields Do
		
		ListItem = MappingFieldList.FindByValue(Item);
		
		MappingFieldListNew.Add(Item, ListItem.Presentation, ListItem.Check);
		
	EndDo;
	
	TempTablesManager = New TempTablesManager;
	
	// Getting object mapping tables (mapped, unmapped)
	GetObjectMappingTables(SourceTable, UserFields, TempTablesManager);
	
	// Getting the table of automatic mapping
	GetAutomaticMappingTable(SourceTable, MappingFieldListNew, UserFields, TempTablesManager);
	
	// Loading the table of automatically mapped objects into the form attribute
	AutomaticallyMappedObjectTable.Load(AutomaticallyMappedObjectTableGet(TempTablesManager, UserFields));
	
	TempTablesManager.Close();
	
EndProcedure

Procedure ExecuteDefaultAutomaticInfobaseObjectMapping(Cancel, MappingFieldList)
	
	SourceTable = GetSourceInfobaseTable(Cancel);
	
	If Cancel Then
		Return;
	EndIf;
	
	// Getting an array of fields that were selected by the user
	UserFields = UsedFieldList.UnloadValues();
	
	TempTablesManager = New TempTablesManager;
	
	// Getting object mapping tables (mapped, unmapped)
	GetObjectMappingTables(SourceTable, UserFields, TempTablesManager);
	
	// Getting the table of automatic mapping
	GetAutomaticMappingTable(SourceTable, MappingFieldList, UserFields, TempTablesManager);
	
	// Loading updated unapproved mapping table into the object attribute
	UnapprovedMappingTable.Load(MergeUnapprovedMappingTableAndAutomaticMappingTable(TempTablesManager));
	
	TempTablesManager.Close();
	
EndProcedure

Procedure GetObjectMappingTables(SourceTable, UserFields, TempTablesManager)
	
	// Retrieving the following tables:
	//
	// SourceTable
	// UnapprovedMappingTable
	// InfobaseObjectMappingRegisterTable
	//
	// MappedSourceObjectTableByRegister
	// MappedTargetObjectTableByRegister
	// MappedObjectTableByUnapprovedMapping
	//
	// MappedObjectTable
	//
	// UnmappedSourceObjectTable
	// UnmappedTargetObjectTable
	//
	//
	
	QueryText = "
	|//////////////////////////////////////////////////////////////////////////////// {SourceTable}
	|SELECT
	|	
	|	#CUSTOM_FIELDS_SourceTable#
	|	
	|	SourceTableParameter.Ref  AS Ref,
	|	SourceTableParameter.UUID AS UUID,
	|	&SourceType               AS ObjectType
	|INTO SourceTable
	|FROM
	|	&SourceTableParameter AS SourceTableParameter
	|INDEX BY
	|	Ref,
	|	UUID
	|;
	|
	|//////////////////////////////////////////////////////////////////////////////// {InfobaseObjectMappingRegisterTable}
	|SELECT
	|	SourceUUID,
	|	TargetUUID,
	|	TargetType,
	|	SourceType
	|INTO InfobaseObjectMappingRegisterTable
	|FROM
	|	InformationRegister.InfobaseObjectMappings AS InfobaseObjectMappings
	|WHERE
	|	  InfobaseObjectMappings.InfobaseNode = &InfobaseNode
	|	AND InfobaseObjectMappings.TargetType = &SourceType
	|	AND InfobaseObjectMappings.SourceType = &TargetType
	|INDEX BY
	|	TargetUUID,
	|	TargetType,
	|	SourceType
	|;
	|
	|//////////////////////////////////////////////////////////////////////////////// {UnapprovedMappingTable}
	|SELECT
	|	
	|	SourceUUID,
	|	TargetUUID,
	|	TargetType,
	|	SourceType
	|	
	|INTO UnapprovedMappingTable
	|FROM
	|	&UnapprovedMappingTable AS UnapprovedMappingTable
	|INDEX BY
	|	TargetUUID,
	|	TargetType
	|;
	|
	|//////////////////////////////////////////////////////////////////////////////// {MappedSourceObjectTableByRegister}
	|SELECT
	|	
	|	#CUSTOM_FIELDS_MappingTable#
	|	
	|	#FIELD_ORDER_Receiver#
	|	
	|	Ref,
	|	0 AS MappingStatus,           // mapped objects (0)
	|	0 AS MappingStatusAdditional, // mapped objects (0)
	|	
	|	IsFolderSource,
	|	IsFolderTarget,
	|	
	|	// {MAPPING REGISTER DATA}
	|	SourceUUID,
	|	TargetUUID,
	|	SourceType,
	|	TargetType
	|INTO MappedSourceObjectTableByRegister
	|FROM
	|	(SELECT
	|	
	|		#CUSTOM_FIELDS_MappedSourceObjectTableByRegister_NestedQuery#
	|		
	|		InfobaseObjectMappings.SourceUUID AS Ref,
	|		
	|		#SourceTableIsFolder#             AS IsFolderSource,
	|		#InfobaseObjectMappingsIsFolder#  AS IsFolderTarget,
	|	
	|		// {MAPPING REGISTER DATA}
	|		InfobaseObjectMappings.SourceUUID AS TargetUUID,
	|		InfobaseObjectMappings.TargetUUID AS SourceUUID,
	|		InfobaseObjectMappings.TargetType AS SourceType,
	|		InfobaseObjectMappings.SourceType AS TargetType
	|	FROM
	|		SourceTable AS SourceTable
	|	LEFT JOIN
	|		InfobaseObjectMappingRegisterTable AS InfobaseObjectMappings
	|	ON
	|		  InfobaseObjectMappings.TargetUUID   = SourceTable.UUID
	|		AND InfobaseObjectMappings.TargetType = SourceTable.ObjectType
	|	WHERE
	|		Not InfobaseObjectMappings.SourceUUID IS NULL
	|	) AS NestedQuery
	|;
	|
	|//////////////////////////////////////////////////////////////////////////////// {MappedTargetObjectTableByRegister}
	|SELECT
	|	
	|	#CUSTOM_FIELDS_MappingTable#
	|	
	|	#FIELD_ORDER_Receiver#
	|	
	|	Ref,
	|	0 AS MappingStatus,           // mapped objects (0)
	|	0 AS MappingStatusAdditional, // mapped objects (0)
	|	
	|	IsFolderSource,
	|	IsFolderTarget,
	|	
	|	// {MAPPING REGISTER DATA}
	|	SourceUUID,
	|	TargetUUID,
	|	SourceType,
	|	TargetType
	|INTO MappedTargetObjectTableByRegister
	|FROM
	|	(SELECT
	|	
	|		#CUSTOM_FIELDS_MappedTargetObjectTableByRegister_NestedQuery#
	|		
	|		TargetTable.Ref AS Ref,
	|	
	|		#TargetTableIsFolder# AS IsFolderSource,
	|		#TargetTableIsFolder# AS IsFolderTarget,
	|	
	|		// {MAPPING REGISTER DATA}
	|		InfobaseObjectMappings.SourceUUID AS TargetUUID,
	|		InfobaseObjectMappings.TargetUUID AS SourceUUID,
	|		InfobaseObjectMappings.TargetType AS SourceType,
	|		InfobaseObjectMappings.SourceType AS TargetType
	|	FROM
	|		#TargetTable# AS TargetTable
	|	LEFT JOIN
	|		InfobaseObjectMappingRegisterTable AS InfobaseObjectMappings
	|	ON
	|		  InfobaseObjectMappings.SourceUUID   = TargetTable.Ref
	|		AND InfobaseObjectMappings.SourceType = &TargetType
	|	LEFT JOIN
	|		MappedSourceObjectTableByRegister AS MappedSourceObjectTableByRegister
	|	ON
	|		MappedSourceObjectTableByRegister.Ref = TargetTable.Ref
	|	
	|	WHERE
	|		Not InfobaseObjectMappings.SourceUUID IS NULL
	|		AND MappedSourceObjectTableByRegister.Ref IS NULL
	|	) AS NestedQuery
	|;
	|
	|//////////////////////////////////////////////////////////////////////////////// {MappedObjectTableByUnapprovedMapping}
	|SELECT
	|	
	|	#CUSTOM_FIELDS_MappingTable#
	|	
	|	#FIELD_ORDER_Receiver#
	|	
	|	Ref,
	|	3 AS MappingStatus,           // unapproved mappings (3)
	|	0 AS MappingStatusAdditional, // mapped objects (0)
	|	
	|	IsFolderSource,
	|	IsFolderTarget,
	|	
	|	// {MAPPING REGISTER DATA}
	|	SourceUUID,
	|	TargetUUID,
	|	SourceType,
	|	TargetType
	|INTO MappedObjectTableByUnapprovedMapping
	|FROM
	|	(SELECT
	|	
	|		#CUSTOM_FIELDS_MappedObjectTableByUnapprovedMapping_NestedQuery#
	|		
	|		UnapprovedMappingTable.SourceUUID AS Ref,
	|	
	|		#SourceTableIsFolder#             AS IsFolderSource,
	|		#UnapprovedMappingTableIsFolder#  AS IsFolderTarget,
	|	
	|		// {MAPPING REGISTER DATA}
	|		UnapprovedMappingTable.SourceUUID AS TargetUUID,
	|		UnapprovedMappingTable.TargetUUID AS SourceUUID,
	|		UnapprovedMappingTable.TargetType AS SourceType,
	|		UnapprovedMappingTable.SourceType AS TargetType
	|	FROM
	|		SourceTable AS SourceTable
	|	LEFT JOIN
	|		UnapprovedMappingTable AS UnapprovedMappingTable
	|	ON
	|		  UnapprovedMappingTable.TargetUUID   = SourceTable.UUID
	|		AND UnapprovedMappingTable.TargetType = SourceTable.ObjectType
	|		
	|	WHERE
	|		Not UnapprovedMappingTable.SourceUUID IS NULL
	|	) AS NestedQuery
	|;
	|
	|//////////////////////////////////////////////////////////////////////////////// {MappedObjectTable}
	|SELECT
	|	
	|	#CUSTOM_FIELDS_MappingTable#
	|	
	|	#FIELDS_ORDER#
	|	
	|	Ref,
	|	MappingStatus,
	|	MappingStatusAdditional,
	|	
	|	// {PICTURE INDEX}
	|	CASE WHEN IsFolderSource IS NULL
	|	THEN 0
	|	ELSE
	|		CASE WHEN IsFolderSource = True
	|		THEN 1
	|		ELSE 2
	|		END
	|	END AS SourcePictureIndex,
	|	
	|	CASE WHEN IsFolderTarget IS NULL
	|	THEN 0
	|	ELSE
	|		CASE WHEN IsFolderTarget = True
	|		THEN 1
	|		ELSE 2
	|		END
	|	END AS TargetPictureIndex,
	|	
	|	// {MAPPING REGISTER DATA}
	|	SourceUUID,
	|	TargetUUID,
	|	SourceType,
	|	TargetType
	|INTO MappedObjectTable
	|FROM
	|	(
	|	SELECT
	|	
	|		#CUSTOM_FIELDS_MappingTable#
	|	
	|		#FIELDS_ORDER#
	|	
	|		Ref,
	|		MappingStatus,
	|		MappingStatusAdditional,
	|	
	|		IsFolderSource,
	|		IsFolderTarget,
	|	
	|		// {MAPPING REGISTER DATA}
	|		SourceUUID,
	|		TargetUUID,
	|		SourceType,
	|		TargetType
	|	FROM
	|		MappedSourceObjectTableByRegister
	|	
	|	UNION ALL
	|	
	|	SELECT
	|	
	|		#CUSTOM_FIELDS_MappingTable#
	|	
	|		#FIELDS_ORDER#
	|	
	|		Ref,
	|		MappingStatus,
	|		MappingStatusAdditional,
	|	
	|		IsFolderSource,
	|		IsFolderTarget,
	|	
	|		// {MAPPING REGISTER DATA}
	|		SourceUUID,
	|		TargetUUID,
	|		SourceType,
	|		TargetType
	|	FROM
	|		MappedTargetObjectTableByRegister
	|	
	|	UNION ALL
	|	
	|	SELECT
	|	
	|		#CUSTOM_FIELDS_MappingTable#
	|	
	|		#FIELDS_ORDER#
	|	
	|		Ref,
	|		MappingStatus,
	|		MappingStatusAdditional,
	|	
	|		IsFolderSource,
	|		IsFolderTarget,
	|	
	|		// {MAPPING REGISTER DATA}
	|		SourceUUID,
	|		TargetUUID,
	|		SourceType,
	|		TargetType
	|	FROM
	|		MappedObjectTableByUnapprovedMapping
	|	
	|	) AS NestedQuery
	|	
	|INDEX BY
	|	Ref
	|;
	|
	|//////////////////////////////////////////////////////////////////////////////// {UnmappedSourceObjectTable}
	|SELECT
	|	
	|	Ref,
	|	
	|	#CUSTOM_FIELDS_MappingTable#
	|	
	|	#FIELD_ORDER_Source#
	|	
	|	-1 AS MappingStatus,           // unmapped source objects (-1)
	|	 1 AS MappingStatusAdditional, // unmapped objects (1)
	|	
	|	// {PICTURE INDEX}
	|	CASE WHEN IsFolderSource IS NULL
	|	THEN 0
	|	ELSE
	|		CASE WHEN IsFolderSource = True
	|		THEN 1
	|		ELSE 2
	|		END
	|	END AS SourcePictureIndex,
	|	
	|	CASE WHEN IsFolderTarget IS NULL
	|	THEN 0
	|	ELSE
	|		CASE WHEN IsFolderTarget = True
	|		THEN 1
	|		ELSE 2
	|		END
	|	END AS TargetPictureIndex,
	|	
	|	// {MAPPING REGISTER DATA}
	|	SourceUUID,
	|	TargetUUID,
	|	SourceType,
	|	TargetType
	|INTO UnmappedSourceObjectTable
	|FROM
	|	(SELECT
	|	
	|		#SourceTableIsFolder# AS IsFolderSource,
	|		NULL                  AS IsFolderTarget,
	|		
	|		SourceTable.Ref AS Ref,
	|		
	|		#CUSTOM_FIELDS_UnmappedSourceObjectTable_NestedQuery#
	|		
	|		// {MAPPING REGISTER DATA}
	|		NULL                                   AS TargetUUID,
	|		SourceTable.UUID AS SourceUUID,
	|		&SourceType                            AS SourceType,
	|		&TargetType                            AS TargetType
	|	FROM
	|		SourceTable AS SourceTable
	|	LEFT JOIN
	|		MappedObjectTable AS MappedObjectTable
	|	ON
	|		    SourceTable.Ref = MappedObjectTable.Ref
	|		OR SourceTable.UUID = MappedObjectTable.SourceUUID
	|	WHERE
	|		MappedObjectTable.Ref IS NULL
	|	) AS NestedQuery
	|;
	|
	|//////////////////////////////////////////////////////////////////////////////// {UnmappedTargetObjectTable}
	|SELECT
	|	
	|	Ref,
	|	
	|	#CUSTOM_FIELDS_MappingTable#
	|	
	|	#FIELD_ORDER_Receiver#
	|	
	|	1 AS MappingStatus,           // unmapped target objects (1)
	|	1 AS MappingStatusAdditional, // unmapped objects (1)
	|	
	|	// {PICTURE INDEX}
	|	CASE WHEN IsFolderSource IS NULL
	|	THEN 0
	|	ELSE
	|		CASE WHEN IsFolderSource = True
	|		THEN 1
	|		ELSE 2
	|		END
	|	END AS SourcePictureIndex,
	|	
	|	CASE WHEN IsFolderTarget IS NULL
	|	THEN 0
	|	ELSE
	|		CASE WHEN IsFolderTarget = True
	|		THEN 1
	|		ELSE 2
	|		END
	|	END AS TargetPictureIndex,
	|	
	|	// {MAPPING REGISTER DATA}
	|	SourceUUID,
	|	TargetUUID,
	|	SourceType,
	|	TargetType
	|INTO UnmappedTargetObjectTable
	|FROM
	|	(SELECT
	|	
	|		TargetTable.Ref AS Ref,
	|	
	|		#CUSTOM_FIELDS_UnmappedTargetObjectTable_NestedQuery#
	|		
	|		NULL                  AS IsFolderSource,
	|		#TargetTableIsFolder# AS IsFolderTarget,
	|		
	|		// {MAPPING REGISTER DATA}
	|		TargetTable.Ref       AS TargetUUID,
	|		Undefined             AS SourceUUID,
	|		Undefined             AS SourceType,
	|		&TargetType           AS TargetType
	|	FROM
	|		#TargetTable# AS TargetTable
	|	LEFT JOIN
	|		MappedObjectTable AS MappedObjectTable
	|	ON
	|		TargetTable.Ref = MappedObjectTable.Ref
	|	WHERE
	|		MappedObjectTable.Ref IS NULL
	|	) AS NestedQuery
	|;
	|
	|		TargetTable.Ref AS TargetUUID,
	|		Undefined       AS SourceUUID,
	|		Undefined       AS SourceType,
	|		&TargetType     AS TargetType
	|	FROM
	|		#TargetTable# AS TargetTable
	|	LEFT JOIN
	|		MappedObjectTable AS MappedObjectTable
	|	ON
	|		TargetTable.Ref = MappedObjectTable.Ref
	|	WHERE
	|		MappedObjectTable.Ref IS NULL
	|	) AS NestedQuery
	|;
	|
	|";
	
	QueryText = StrReplace(QueryText, "#CUSTOM_FIELDS_SourceTable#", GetUserFields(UserFields, "SourceTableParameter.# AS #,"));
	QueryText = StrReplace(QueryText, "#CUSTOM_FIELDS_MappingTable#", GetUserFields(UserFields, "SourceFieldNN, TargetFieldNN,"));
	QueryText = StrReplace(QueryText, "#CUSTOM_FIELDS_MappedByRefObjectTable_NestedQuery#", GetUserFields(UserFields, "TargetTable.# AS TargetFieldNN, SourceTable.# AS SourceFieldNN,"));
	QueryText = StrReplace(QueryText, "#CUSTOM_FIELDS_MappedSourceObjectTableByRegister_NestedQuery#", GetUserFields(UserFields, "CAST(InfobaseObjectMappings.SourceUUID AS [TargetTableName]).# AS TargetFieldNN, SourceTable.# AS SourceFieldNN,"));
	QueryText = StrReplace(QueryText, "#CUSTOM_FIELDS_MappedTargetObjectTableByRegister_NestedQuery#", GetUserFields(UserFields, "TargetTable.# AS TargetFieldNN, NULL AS SourceFieldNN,"));
	QueryText = StrReplace(QueryText, "#CUSTOM_FIELDS_MappedObjectTableByUnapprovedMapping_NestedQuery#", GetUserFields(UserFields, "CAST(UnapprovedMappingTable.SourceUUID AS [TargetTableName]).# AS TargetFieldNN, SourceTable.# AS SourceFieldNN,"));
	QueryText = StrReplace(QueryText, "#CUSTOM_FIELDS_UnmappedSourceObjectTable_NestedQuery#", GetUserFields(UserFields, "SourceTable.# AS SourceFieldNN, NULL AS TargetFieldNN,"));
	QueryText = StrReplace(QueryText, "#CUSTOM_FIELDS_UnmappedTargetObjectTableByFields_NestedQuery#", GetUserFields(UserFields, "NULL AS SourceFieldNN, TargetTable.Ref.# AS TargetFieldNN,"));
	
	QueryText = StrReplace(QueryText, "#ORDER_FIELD_Source#", GetUserFields(UserFields, "SourceFieldNN AS OrderFieldNN,"));
	QueryText = StrReplace(QueryText, "#ORDER_FIELD_Target#", GetUserFields(UserFields, "TargetFieldNN AS OrderFieldNN,"));
	
	QueryText = StrReplace(QueryText, "#FIELDS_ORDER#", GetUserFields(UserFields, "OrderFieldNN,"));
	QueryText = StrReplace(QueryText, "#TargetTable#", TargetTableName);
	
	If UserFields.Find("IsFolder") <> Undefined Then
		
		QueryText = StrReplace(QueryText, "#SourceTableIsFolder#",            "SourceTable.IsFolder");
		QueryText = StrReplace(QueryText, "#TargetTableIsFolder#",            "TargetTable.IsFolder");
		QueryText = StrReplace(QueryText, "#UnapprovedMappingTableIsFolder#", "CAST(UnapprovedMappingTable.SourceUUID AS [TargetTableName]).IsFolder");
		QueryText = StrReplace(QueryText, "#InfobaseObjectMapsIsFolder#",     "CAST(InfobaseObjectMappings.SourceUUID AS [TargetTableName]).IsFolder");
		
	Else
		
		QueryText = StrReplace(QueryText, "#SourceTableIsFolder#",            "NULL");
		QueryText = StrReplace(QueryText, "#TargetTableIsFolder#",            "NULL");
		QueryText = StrReplace(QueryText, "#UnapprovedMappingTableIsFolder#", "NULL");
		QueryText = StrReplace(QueryText, "#InfobaseObjectMapsIsFolder#",     "NULL");
		
	EndIf;
	
	QueryText = StrReplace(QueryText, "[TargetTableName]", TargetTableName);
	
	Query = New Query;
	
	Query.Text = QueryText;
	Query.TempTablesManager = TempTablesManager;
	
	Query.SetParameter("SourceTableParameter",   SourceTable);
	Query.SetParameter("UnapprovedMappingTable", UnapprovedMappingTable.Unload());
	Query.SetParameter("SourceType",             SourceTypeString);
	Query.SetParameter("TargetType",             TargetTypeString);
	Query.SetParameter("InfobaseNode",           InfobaseNode);
	
	Query.Execute();
	
EndProcedure

Procedure GetAutomaticMappingTable(SourceTable, MappingFieldList, UserFields, TempTablesManager)
	
	MarkedListItemArray = CommonUseClientServer.GetMarkedListItemArray(MappingFieldList);
	
	If MarkedListItemArray.Count() = 0 Then
		
		GetAutomaticMappingByGUIDTable(UserFields, TempTablesManager);
		
	Else
		
		GetAutomaticMappingByGUIDAndSearchFieldTable(SourceTable, MappingFieldList, UserFields, TempTablesManager);
		
	EndIf;
	
EndProcedure

Procedure GetAutomaticMappingByGUIDTable(UserFields, TempTablesManager)
	
	// Retrieving the following tables:
	//
	// AutomaticallyMappedObjectTable
	
	QueryText = "
	|//////////////////////////////////////////////////////////////////////////////// {AutomaticallyMappedObjectTable}
	|SELECT
	|	
	|	Ref,
	|	
	|	#CUSTOM_FIELDS_MappingTable#
	|	
	|	TargetPictureIndex,
	|	SourcePictureIndex,
	|	
	|	// {MAPPING REGISTER DATA}
	|	SourceUUID,
	|	TargetUUID,
	|	SourceType,
	|	TargetType
	|INTO AutomaticallyMappedObjectTable
	|FROM
	|	(SELECT
	|		
	|		UnmappedTargetObjectTable.Ref AS Ref,
	|		
	|		UnmappedTargetObjectTable.TargetPictureIndex,
	|		UnmappedSourceObjectTable.SourcePictureIndex,
	|		
	|		#CUSTOM_FIELDS_AutomaticallyMappedObjectTableByGUID_NestedQuery#
	|		
	|		// {MAPPING REGISTER DATA}
	|		UnmappedSourceObjectTable.SourceUUID AS SourceUUID,
	|		UnmappedSourceObjectTable.SourceType AS SourceType,
	|		UnmappedTargetObjectTable.TargetUUID AS TargetUUID,
	|		UnmappedTargetObjectTable.TargetType AS TargetType
	|	FROM
	|		UnmappedTargetObjectTable AS UnmappedTargetObjectTable
	|	LEFT JOIN
	|		UnmappedSourceObjectTable AS UnmappedSourceObjectTable
	|	ON
	|		UnmappedTargetObjectTable.Ref = UnmappedSourceObjectTable.Ref
	|	
	|	WHERE
	|		Not UnmappedSourceObjectTable.Ref IS NULL
	|	
	|	) AS NestedQuery
	|;
	|";
	
	QueryText = StrReplace(QueryText, "#CUSTOM_FIELDS_MappingTable#", GetUserFields(UserFields, "SourceFieldNN, TargetFieldNN,"));
	QueryText = StrReplace(QueryText, "#CUSTOM_FIELDS_AutomaticallyMappedObjectTableByGUID_NestedQuery#", GetUserFields(UserFields, "UnmappedSourceObjectTable.SourceFieldNN AS SourceFieldNN, UnmappedTargetObjectTable.TargetFieldNN AS TargetFieldNN,"));
	
	Query = New Query;
	Query.Text = QueryText;
	Query.TempTablesManager = TempTablesManager;
	
	Query.Execute();
	
EndProcedure

Procedure GetAutomaticMappingByGUIDAndSearchFieldTable(SourceTable, MappingFieldList, UserFields, TempTablesManager)
	
	// Retrieving the following tables:
	//
	// AutomaticallyMappedObjectTableFull
	// UnmappedTargetObjectTableByFields
	// UnmappedSourceObjectTableByFields
	// WrongMappedTargetObjectTable
	// WrongMappedSourceObjectTable
	//
	// AutomaticallyMappedObjectTableByGUID
	// AutomaticallyMappedObjectTableByFields
	// AutomaticallyMappedObjectTable
	
	// Tables are retrieved by the following algorithm
	//
	// UnmappedTargetObjectTableByFields = UnmappedTargetObjectTable - AutomaticallyMappedObjectTableByGUID
	// UnmappedSourceObjectTableByFields = UnmappedSourceObjectTable - AutomaticallyMappedObjectTableByGUID
	//
	// AutomaticallyMappedObjectTable = AutomaticallyMappedObjectTableByFields + AutomaticallyMappedObjectTableByGUID
	
	QueryText = "
	|//////////////////////////////////////////////////////////////////////////////// {AutomaticallyMappedObjectTableByGUID}
	|SELECT
	|	
	|	Ref,
	|	
	|	#CUSTOM_FIELDS_MappingTable#
	|	
	|	TargetPictureIndex,
	|	SourcePictureIndex,
	|		
	|	// {MAPPING REGISTER DATA}
	|	SourceUUID,
	|	TargetUUID,
	|	SourceType,
	|	TargetType
	|INTO AutomaticallyMappedObjectTableByGUID
	|FROM
	|	(SELECT
	|		
	|		UnmappedTargetObjectTable.Ref AS Ref,
	|		
	|		#CUSTOM_FIELDS_AutomaticallyMappedObjectTableByGUID_NestedQuery#
	|		
	|		UnmappedTargetObjectTable.TargetPictureIndex,
	|		UnmappedSourceObjectTable.SourcePictureIndex,
	|		
	|		// {MAPPING REGISTER DATA}
	|		UnmappedSourceObjectTable.SourceUUID AS SourceUU
	|		UnmappedSourceObjectTable.SourceType AS SourceType,
	|		UnmappedTargetObjectTable.TargetUUID AS TargetUUID,
	|		UnmappedTargetObjectTable.TargetType AS TargetType
	|	FROM
	|		UnmappedTargetObjectTable AS UnmappedTargetObjectTable
	|	LEFT JOIN
	|		UnmappedSourceObjectTable AS UnmappedSourceObjectTable
	|	ON
	|		UnmappedTargetObjectTable.Ref = UnmappedSourceObjectTable.Ref
	|	
	|	WHERE
	|		Not UnmappedSourceObjectTable.Ref IS NULL
	|	
	|	) AS NestedQuery
	|;
	|
	|//////////////////////////////////////////////////////////////////////////////// {UnmappedTargetObjectTableByFields}
	|SELECT
	|	
	|	#CUSTOM_FIELDS_UnmappedObjectTable#
	|	
	|	UnmappedObjectTable.TargetPictureIndex,
	|	
	|	// {MAPPING REGISTER DATA}
	|	UnmappedObjectTable.SourceUUID,
	|	UnmappedObjectTable.TargetUUID,
	|	UnmappedObjectTable.SourceType,
	|	UnmappedObjectTable.TargetType
	|INTO UnmappedTargetObjectTableByFields
	|FROM
	|	UnmappedTargetObjectTable AS UnmappedObjectTable
	|	LEFT JOIN
	|		AutomaticallyMappedObjectTableByGUID AS AutomaticallyMappedObjectTableByGUID
	|	ON
	|		UnmappedObjectTable.Ref = AutomaticallyMappedObjectTableByGUID.Ref
	|WHERE
	|	AutomaticallyMappedObjectTableByGUID.Ref IS NULL
	|;
	|
	|//////////////////////////////////////////////////////////////////////////////// {UnmappedSourceObjectTableByFields}
	|SELECT
	|	
	|	#CUSTOM_FIELDS_UnmappedObjectTable#
	|	
	|	UnmappedObjectTable.SourcePictureIndex,
	|	
	|	// {MAPPING REGISTER DATA}
	|	UnmappedObjectTable.SourceUUID,
	|	UnmappedObjectTable.TargetUUID,
	|	UnmappedObjectTable.SourceType,
	|	UnmappedObjectTable.TargetType
	|INTO UnmappedSourceObjectTableByFields
	|FROM
	|	UnmappedSourceObjectTable AS UnmappedObjectTable
	|	LEFT JOIN
	|		AutomaticallyMappedObjectTableByGUID AS AutomaticallyMappedObjectTableByGUID
	|	ON
	|		UnmappedObjectTable.Ref = AutomaticallyMappedObjectTableByGUID.Ref
	|WHERE
	|	AutomaticallyMappedObjectTableByGUID.Ref IS NULL
	|;
	|
	|//////////////////////////////////////////////////////////////////////////////// {AutomaticallyMappedObjectTableFull}  // Contains duplicate records (present both in the source and in the target)
	|SELECT
	|	
	|	#CUSTOM_FIELDS_MappingTable#
	|	
	|	TargetPictureIndex,
	|	SourcePictureIndex,
	|		
	|	// {MAPPING REGISTER DATA}
	|	SourceUUID,
	|	TargetUUID,
	|	SourceType,
	|	TargetType
	|INTO AutomaticallyMappedObjectTableFull
	|FROM
	|	(SELECT
	|		
	|		#CUSTOM_FIELDS_AutomaticallyMappedObjectTableFull_NestedQuery#
	|		
	|		UnmappedTargetObjectTableByFields.TargetPictureIndex,
	|		UnmappedSourceObjectTableByFields.SourcePictureIndex,
	|		
	|		// {MAPPING REGISTER DATA}
	|		UnmappedSourceObjectTableByFields.SourceUUID AS SourceUUID,
	|		UnmappedSourceObjectTableByFields.SourceType AS SourceType,
	|		UnmappedTargetObjectTableByFields.TargetUUID AS TargetUUID,
	|		UnmappedTargetObjectTableByFields.TargetType AS TargetType
	|	FROM
	|		UnmappedTargetObjectTableByFields AS UnmappedTargetObjectTableByFields
	|	LEFT JOIN
	|		UnmappedSourceObjectTableByFields AS UnmappedSourceObjectTableByFields
	|	ON
	|		#CONDITION_MAPPING_ON_FIELDS#
	|	
	|	WHERE
	|		Not UnmappedSourceObjectTableByFields.SourceUUID IS NULL
	|	
	|	) AS NestedQuery
	|;
	|
	|//////////////////////////////////////////////////////////////////////////////// {WrongMappedSourceObjectTable}
	|SELECT
	|	
	|	// {MAPPING REGISTER DATA}
	|	SourceUUID
	|	
	|INTO WrongMappedSourceObjectTable
	|FROM
	|	(SELECT
	|	
	|		// {MAPPING REGISTER DATA}
	|		SourceUUID
	|	FROM
	|		AutomaticallyMappedObjectTableFull
	|	GROUP BY
	|		SourceUUID
	|	HAVING
	|		SUM(1) > 1
	|	
	|	) AS NestedQuery
	|;
	|
	|
	|//////////////////////////////////////////////////////////////////////////////// {WrongMappedTargetObjectTable}
	|SELECT
	|	
	|	// {MAPPING REGISTER DATA}
	|	TargetUUID
	|	
	|INTO WrongMappedTargetObjectTable
	|FROM
	|	(SELECT
	|	
	|		// {MAPPING REGISTER DATA}
	|		TargetUUID
	|	FROM
	|		AutomaticallyMappedObjectTableFull
	|	GROUP BY
	|		TargetUUID
	|	HAVING
	|		SUM(1) > 1
	|	
	|	) AS NestedQuery
	|;
	|
	|//////////////////////////////////////////////////////////////////////////////// {AutomaticallyMappedObjectTableByFields}
	|SELECT
	|	
	|	#CUSTOM_FIELDS_MappingTable#
	|	
	|	TargetPictureIndex,
	|	SourcePictureIndex,
	|	
	|	// {MAPPING REGISTER DATA}
	|	SourceUUID,
	|	TargetUUID,
	|	SourceType,
	|	TargetType
	|INTO AutomaticallyMappedObjectTableByFields
	|FROM
	|	(SELECT
	|	
	|		#CUSTOM_FIELDS_MappingTable#
	|	
	|		AutomaticallyMappedObjectTableFull.TargetPictureIndex,
	|		AutomaticallyMappedObjectTableFull.SourcePictureIndex,
	|	
	|		// {MAPPING REGISTER DATA}
	|		AutomaticallyMappedObjectTableFull.SourceUUID,
	|		AutomaticallyMappedObjectTableFull.TargetUUID,
	|		AutomaticallyMappedObjectTableFull.SourceType,
	|		AutomaticallyMappedObjectTableFull.TargetType
	|	FROM
	|		AutomaticallyMappedObjectTableFull AS AutomaticallyMappedObjectTableFull
	|	
	|	LEFT JOIN
	|		WrongMappedSourceObjectTable AS WrongMappedSourceObjectTable
	|	ON
	|		AutomaticallyMappedObjectTableFull.SourceUUID = WrongMappedSourceObjectTable.SourceUUID
	|	
	|	LEFT JOIN
	|		WrongMappedTargetObjectTable AS WrongMappedTargetObjectTable
	|	ON
	|		AutomaticallyMappedObjectTableFull.TargetUUID = WrongMappedTargetObjectTable.TargetUUID
	|	
	|	WHERE
	|		  WrongMappedSourceObjectTable.SourceUUID IS NULL
	|		AND WrongMappedTargetObjectTable.TargetUUID IS NULL
	|	
	|	) AS NestedQuery
	|;
	|
	|//////////////////////////////////////////////////////////////////////////////// {AutomaticallyMappedObjectTable}
	|SELECT
	|	
	|	#CUSTOM_FIELDS_MappingTable#
	|	
	|	TargetPictureIndex,
	|	SourcePictureIndex,
	|	
	|	// {MAPPING REGISTER DATA}
	|	SourceUUID,
	|	TargetUUID,
	|	SourceType,
	|	TargetType
	|INTO AutomaticallyMappedObjectTable
	|FROM
	|	(
	|	SELECT
	|
	|		#CUSTOM_FIELDS_MappingTable#
	|		
	|		TargetPictureIndex,
	|		SourcePictureIndex,
	|		
	|		// {MAPPING REGISTER DATA}
	|		SourceUUID,
	|		TargetUUID,
	|		SourceType,
	|		TargetType
	|	FROM
	|		AutomaticallyMappedObjectTableByFields
	|
	|	UNION ALL
	|
	|	SELECT
	|
	|		#CUSTOM_FIELDS_MappingTable#
	|		
	|		TargetPictureIndex,
	|		SourcePictureIndex,
	|		
	|		// {MAPPING REGISTER DATA}
	|		SourceUUID,
	|		TargetUUID,
	|		SourceType,
	|		TargetType
	|	FROM
	|		AutomaticallyMappedObjectTableByGUID
	|
	|	) AS NestedQuery
	|;
	|";
	
	QueryText = StrReplace(QueryText, "#MAPPING_BY_FIELDS_CONDITION#", GetMappingByFieldsCondition(MappingFieldList));
	QueryText = StrReplace(QueryText, "#CUSTOM_FIELDS_MappingTable#", GetUserFields(UserFields, "SourceFieldNN, TargetFieldNN,"));
	QueryText = StrReplace(QueryText, "#CUSTOM_FIELDS_UnmappedObjectTable#", GetUserFields(UserFields, "UnmappedObjectTable.SourceFieldNN AS SourceFieldNN, UnmappedObjectTable.TargetFieldNN AS TargetFieldNN,"));
	QueryText = StrReplace(QueryText, "#CUSTOM_FIELDS_AutomaticallyMappedObjectTableFull_NestedQuery#", GetUserFields(UserFields, "UnmappedSourceObjectTableByFields.SourceFieldNN AS SourceFieldNN, UnmappedTargetObjectTableByFields.TargetFieldNN AS TargetFieldNN,"));
	QueryText = StrReplace(QueryText, "#CUSTOM_FIELDS_AutomaticallyMappedObjectTableByGUID_NestedQuery#", GetUserFields(UserFields, "UnmappedSourceObjectTable.SourceFieldNN AS SourceFieldNN, UnmappedTargetObjectTable.TargetFieldNN AS TargetFieldNN,"));
	
	Query = New Query;
	Query.Text = QueryText;
	Query.TempTablesManager = TempTablesManager;
	
	Query.Execute();
	
EndProcedure

Procedure ExecuteTableSortingAtServer()
	
	SortingFields = GetSortingFieldsAtServer();
	
	If Not IsBlankString(SortingFields) Then
		
		MappingTable().Sort(SortingFields);
		
	EndIf;
	
EndProcedure

Procedure GetMappingDigest(TempTablesManager)
	
	// Getting the number of mapped objects
	GetMappedObjectCount(TempTablesManager);
	
	MappingDigest().ObjectCountInSource = DataExchangeServer.TempInfobaseTableRecordCount("SourceTable", TempTablesManager);
	MappingDigest().ObjectCountInTarget = DataExchangeServer.RecordCountInInfobaseTable(TargetTableName);
	
	MappedSourceObjectCount =   ObjectMappingStatistics().MappedByRegisterSourceObjectCount
												+ ObjectMappingStatistics().MappedByUnapprovedRelationsObjectCount;
 
	MappedTargetObjectCount =   ObjectMappingStatistics().MappedByRegisterSourceObjectCount
												+ ObjectMappingStatistics().MappedByRegisterTargetObjectCount
												+ ObjectMappingStatistics().MappedByUnapprovedRelationsObjectCount;
	
	UnmappedSourceObjectCount = Max(0, MappingDigest().ObjectCountInSource - MappedSourceObjectCount);
	UnmappedTargetObjectCount = Max(0, MappingDigest().ObjectCountInTarget - MappedTargetObjectCount);
	
	SourceObjectMappingPercent = ?(MappingDigest().ObjectCountInSource = 0, 0, 100 - Int(100 * UnmappedSourceObjectCount / MappingDigest().ObjectCountInSource));
	TargetObjectMappingPercent = ?(MappingDigest().ObjectCountInTarget = 0, 0, 100 - Int(100 * UnmappedTargetObjectCount / MappingDigest().ObjectCountInTarget));
	
	MappingDigest().MappedObjectPercent = Max(SourceObjectMappingPercent, TargetObjectMappingPercent);
	
	MappingDigest().UnmappedObjectCount = Min(UnmappedSourceObjectCount, UnmappedTargetObjectCount);
	
	MappingDigest().MappedObjectCount = MappedTargetObjectCount;
	
EndProcedure

Procedure GetMappedObjectCount(TempTablesManager)
	
	// Getting the number of mapped objects
	QueryText = "
	|SELECT
	|	Count(*) AS Quantity
	|FROM
	|	MappedSourceObjectTableByRegister
	|;
	|/////////////////////////////////////////////////////////////////////////////
	|
	|SELECT
	|	Count(*) AS Quantity
	|FROM
	|	MappedTargetObjectTableByRegister
	|;
	|/////////////////////////////////////////////////////////////////////////////
	|
	|SELECT
	|	Count(*) AS Quantity
	|FROM
	|	MappedObjectTableByUnapprovedMapping
	|;
	|/////////////////////////////////////////////////////////////////////////////
	|";
	
	Query = New Query;
	Query.Text              = QueryText;
	Query.TempTablesManager = TempTablesManager;
	
	ResultArray = Query.ExecuteBatch();
	
	ObjectMappingStatistics().MappedByRegisterSourceObjectCount      = ResultArray[0].Unload()[0]["Quantity"];
	ObjectMappingStatistics().MappedByRegisterTargetObjectCount      = ResultArray[1].Unload()[0]["Quantity"];
	ObjectMappingStatistics().MappedByUnapprovedRelationsObjectCount = ResultArray[2].Unload()[0]["Quantity"];
	
EndProcedure

Procedure AddNumberFieldToMappingTable()
	
	MappingTable().Columns.Add("SerialNumber", New TypeDescription("Number"));
	
	For Each TableRow In MappingTable() Do
		
		TableRow.SerialNumber = MappingTable().IndexOf(TableRow);
		
	EndDo;
	
EndProcedure

Function MergeUnapprovedMappingTableAndAutomaticMappingTable(TempTablesManager)
	
	QueryText = "
	|SELECT
	|
	|	// {MAPPING REGISTER DATA}
	|	SourceUUID,
	|	TargetUUID,
	|	SourceType,
	|	TargetType
	|FROM
	|	(
	|	SELECT
	|
	|		// {MAPPING REGISTER DATA}
	|		SourceUUID,
	|		TargetUUID,
	|		SourceType,
	|		TargetType
	|	FROM 
	|		UnapprovedMappingTable
	|
	|	UNION
	|
	|	SELECT
	|
	|		// {MAPPING REGISTER DATA}
	|		TargetUUID AS SourceUUID,
	|		SourceUUID AS TargetUUID,
	|		TargetType AS SourceType,
	|		SourceType AS TargetType
	|	FROM 
	|		AutomaticallyMappedObjectTable
	|
	|	) AS NestedQuery
	|
	|		TargetUUID AS SourceUUID,
	|		SourceUUID AS TargetUUID,
	|		TargetType AS SourceType,
	|		SourceType AS TargetType
	|	FROM 
	|		AutomaticallyMappedObjectTable
	|
	|	) AS NestedQuery
	|
	|";
	
	Query = New Query;
	Query.Text = QueryText;
	Query.TempTablesManager = TempTablesManager;
	
	Return Query.Execute().Unload();
	
EndFunction

Function AutomaticallyMappedObjectTableGet(TempTablesManager, UserFields)
	
	QueryText = "
	|SELECT
	|	
	|	#CUSTOM_FIELDS_MappingTable#
	|	
	|	True AS Check,
	|	
	|	TargetPictureIndex,
	|	SourcePictureIndex,
	|	
	|	// {MAPPING REGISTER DATA}
	|	TargetUUID AS SourceUUID,
	|	SourceUUID AS TargetUUID,
	|	TargetType                     AS SourceType,
	|	SourceType                     AS TargetType
	|FROM
	|	AutomaticallyMappedObjectTable
	|";
	
	QueryText = StrReplace(QueryText, "#CUSTOM_FIELDS_MappingTable#", GetUserFields(UserFields, "SourceFieldNN, TargetFieldNN,"));
	
	Query = New Query;
	Query.Text = QueryText;
	Query.TempTablesManager = TempTablesManager;
	
	Return Query.Execute().Unload();
	
EndFunction

Function GetMappingTable(SourceTable, UserFields, TempTablesManager)
	
	QueryText = "
	|////////////////////////////////////////////////////////////////////////////////
	|
	|SELECT
	|
	|	#CUSTOM_FIELDS_MappingTable#
	|
	|	#FIELDS_ORDER#
	|
	|	MappingStatus,
	|	MappingStatusAdditional,
	|
	|	SourcePictureIndex AS PictureIndex,
	|
	|	TargetPictureIndex,
	|	SourcePictureIndex,
	|
	|	// {MAPPING REGISTER DATA}
	|	SourceUUID,
	|	TargetUUID,
	|	SourceType,
	|	TargetType
	|FROM
	|	UnmappedSourceObjectTable
	|
	|UNION ALL
	|
	|SELECT
	|
	|	#CUSTOM_FIELDS_MappingTable#
	|
	|	#FIELDS_ORDER#
	|
	|	MappingStatus,
	|	MappingStatusAdditional,
	|
	|	TargetPictureIndex AS PictureIndex,
	|
	|	TargetPictureIndex,
	|	SourcePictureIndex,
	|
	|	// {MAPPING REGISTER DATA}
	|	SourceUUID,
	|	TargetUUID,
	|	SourceType,
	|	TargetType
	|FROM
	|	UnmappedTargetObjectTable
	|
	|UNION ALL
	|
	|SELECT
	|
	|	#CUSTOM_FIELDS_MappingTable#
	|
	|	#FIELDS_ORDER#
	|
	|	MappingStatus,
	|	MappingStatusAdditional,
	|
	|	TargetPictureIndex AS PictureIndex,
	|
	|	TargetPictureIndex,
	|	SourcePictureIndex,
	|
	|	// {MAPPING REGISTER DATA}
	|	SourceUUID,
	|	TargetUUID,
	|	SourceType,
	|	TargetType
	|FROM
	|	MappedObjectTable
	|";
	
	QueryText = StrReplace(QueryText, "#CUSTOM_FIELDS_MappingTable#", GetUserFields(UserFields, "SourceFieldNN, TargetFieldNN,"));
	QueryText = StrReplace(QueryText, "#FIELDS_ORDER#", GetUserFields(UserFields, "OrderFieldNN,"));
	
	Query = New Query;
	Query.Text = QueryText;
	Query.TempTablesManager = TempTablesManager;
	
	Return Query.Execute().Unload();
	
EndFunction

Function GetSourceInfobaseTable(Cancel)
	
	// Return value
	DataTable = Undefined;
	
	DataExchangeDataProcessor = DataExchangeServer.DataImportDataProcessor(Cancel, InfobaseNode, ExchangeMessageFileName);
	
	If Cancel Then
		Return Undefined;
	EndIf;
	
	DataTableKey = DataExchangeServer.DataTableKey(SourceTypeString, TargetTypeString, IsObjectDeletion);
	
	// Perhaps the data table is already imported and is placed in the DataExchangeDataProcessor data processor cache
	DataTable = DataExchangeDataProcessor.ExchangeMessageDataTable().Get(DataTableKey);
	
	// Importing the data table if it was not imported earlier
	If DataTable = Undefined Then
		
		TableToImport = New Array;
		TableToImport.Add(DataTableKey);
		
		// IMPORTING DATA IN THE MAPPING MODE (importing data into the value table)
		DataExchangeDataProcessor.ExecuteDataImportIntoValueTable(TableToImport);
		
		If DataExchangeDataProcessor.ErrorFlag() Then
			
			NString = NStr("en = 'Error importing the exchange message: %1'");
			NString = StringFunctionsClientServer.SubstituteParametersInString(NString, DataExchangeDataProcessor.ErrorMessageString());
			CommonUseClientServer.MessageToUser(NString,,,, Cancel);
			Return Undefined;
		EndIf;
		
		DataTable = DataExchangeDataProcessor.ExchangeMessageDataTable().Get(DataTableKey);
		
	EndIf;
	
	If DataTable = Undefined Then
		
		Cancel = True;
		
	EndIf;
	
	Return DataTable;
EndFunction

Function GetUserFields(UserFields, FieldPattern)
	
	// Return value
	Result = "";
	
	For Each Field In UserFields Do
		
		FieldNumber = UserFields.Find(Field) + 1;
		
		CurrentField = StrReplace(FieldPattern, "#", Field);
		
		CurrentField = StrReplace(CurrentField, "NN", String(FieldNumber));
		
		Result = Result + Chars.LF + CurrentField;
		
	EndDo;
	
	Return Result;
	
EndFunction

Function GetSortingFieldsAtServer()
	
	// Return value
	SortingFields = "";
	
	FieldPattern = "OrderFieldNN #SortDirection";
	
	For Each TableRow In SortTable Do
		
		If TableRow.Use Then
			
			Separator = ?(IsBlankString(SortingFields), "", ", ");
			
			SortDirectionStr = ?(TableRow.SortDirection, "Asc", "Desc");
			
			ListItem = UsedFieldList.FindByValue(TableRow.FieldName);
			
			FieldIndex = UsedFieldList.IndexOf(ListItem) + 1;
			
			FieldName = StrReplace(FieldPattern, "NN", String(FieldIndex));
			FieldName = StrReplace(FieldName, "#SortDirection", SortDirectionStr);
			
			SortingFields = SortingFields + Separator + FieldName;
			
		EndIf;
		
	EndDo;
	
	Return SortingFields;
	
EndFunction

Function GetMappingByFieldsCondition(MappingFieldList)
	
	// Return value
	Result = "";
	
	For Each Item In MappingFieldList Do
		
		If Item.Check Then
			
			If Find(Item.Presentation, DataExchangeServer.UnlimitedLengthString()) > 0 Then
				
				FieldPattern = "SUBSTRING(UnmappedTargetObjectTableByFields.TargetFieldNN 0, 1024) = SUBSTRING(UnmappedSourceObjectTableByFields.SourceFieldNN 0, 1024)";
				
			Else
				
				FieldPattern = "UnmappedTargetObjectTableByFields.TargetFieldNN = UnmappedSourceObjectTableByFields.SourceFieldNN";
				
			EndIf;
			
			FieldNumber = MappingFieldList.IndexOf(Item) + 1;
			
			CurrentField = StrReplace(FieldPattern, "NN", String(FieldNumber));
			
			OperationLiteral = ?(IsBlankString(Result), "", "And");
			
			Result = Result + Chars.LF + OperationLiteral + " " + CurrentField;
			
		EndIf;
		
	EndDo;
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Auxiliary internal procedures and functions.

Procedure FillListWithSelectedItems(SourceList, TargetList)
	
	TargetList.Clear();
	
	For Each Item In SourceList Do
		
		If Item.Check Then
			
			TargetList.Add(Item.Value, Item.Presentation, True);
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure FillSortTable(SourceValueList)
	
	SortTable.Clear();
	
	For Each Item In SourceValueList Do
		
		IsFirstField = SourceValueList.IndexOf(Item) = 0;
		
		TableRow = SortTable.Add();
		
		TableRow.FieldName     = Item.Value;
		TableRow.Use           = IsFirstField; // Default sorting by the first field
		TableRow.SortDirection = True; // Ascending
		
	EndDo;
	
EndProcedure

Procedure FillListWithAdditionalParameters(TableFieldList)
	
	MetadataObject = Metadata.FindByType(Type(SourceTableObjectTypeName));
	
	FieldListToDelete = New Array;
	ValueStorageType  = New TypeDescription("ValueStorage");
	
	For Each Item In TableFieldList Do
		
		Attribute = MetadataObject.Attributes.Find(Item.Value);
		
		If  Attribute = Undefined
			And DataExchangeServer.IsStandardAttribute(MetadataObject.StandardAttributes, Item.Value) Then
			
			Attribute = MetadataObject.StandardAttributes[Item.Value];
			
		EndIf;
		
		If Attribute = Undefined Then
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'The %2 attribute is not defined for the %1 metadata object.'"),
				MetadataObject.FullName(),
				String(Item.Value));
		EndIf;
			
		If Attribute.Type = ValueStorageType Then
			
			FieldListToDelete.Add(Item);
			Continue;
			
		EndIf;
		
		Presentation = "";
		
		If IsUnlimitedLengthString(Attribute) Then
			
			Presentation = StringFunctionsClientServer.SubstituteParametersInString("%1 %2",
				?(IsBlankString(Attribute.Synonym), Attribute.Name, TrimAll(Attribute.Synonym)),
				DataExchangeServer.UnlimitedLengthString());
		Else
			
			Presentation = TrimAll(Attribute.Synonym);
			
		EndIf;
		
		If IsBlankString(Presentation) Then
			
			Presentation = Attribute.Name;
			
		EndIf;
		
		Item.Presentation = Presentation;
		
	EndDo;
	
	For Each ElementToDelete In FieldListToDelete Do
		
		TableFieldList.Delete(ElementToDelete);
		
	EndDo;
	
EndProcedure

Procedure CheckMappingFieldCountInArray(Array)
	
	If Array.Count() > DataExchangeServer.MaxObjectMappingFieldCount() Then
		
		Array.Delete(Array.UBound());
		
		CheckMappingFieldCountInArray(Array);
		
	EndIf;
	
EndProcedure

Procedure AddSearchField(Array, Value)
	
	Item = TableFieldList.FindByValue(Value);
	
	If Item <> Undefined Then
		
		Array.Add(Item.Value);
		
	EndIf;
	
EndProcedure

Function IsUnlimitedLengthString(Attribute)
	
	Return Attribute.Type = UnlimitedLengthStringType();
	
EndFunction

#EndRegion

#EndIf
