﻿#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	
////////////////////////////////////////////////////////////////////////////////	
	// VARIABLE NAME ACRONYMS (ABBREVIATIONS)
	// OCR  - object conversion rule;	
	// PCR  - object property conversion rule;	
	// PGCR - object property group conversion rule;	
	// VCR  - object value conversion rule;	
	// DER  - data export rule;	
	// DCR  - data clearing rule.
	
	
	////////////////////////////////////////////////////////////////////////////////
	// EXPORT VARIABLES
	
	Var EventLogMessageKey Export; // message string for storing errors in the event log
	Var ExternalConnection Export; // contains external connection global context or Undefined
	Var Queries Export; // Structure that contains queries to used
	
	////////////////////////////////////////////////////////////////////////////////
	// AUXILIARY MODULE VARIABLES THAT ARE USED FOR CREATING ALGORITHMS (BOTH FOR IMPORT AND FOR EXPORT)
	
	Var Conversion;                        // Conversion property structure (Name, ID, 
										   // exchange event handlers).	
	Var Algorithms;                        // Structure that contains algorithms to be used.
	Var AdditionalDataProcessors;          // Structure that contains external data
										   // processors to be used.
	
	Var Rules;                             // Structure that contains OCR references.
	
	Var Managers;                          // Map with the following fields: Name, TypeName,
										   // RefTypeString, Manager, MDObject, OCR.
	Var ManagersForExchangePlans;
	
	Var AdditionalDataProcessorParameters; // Structure that contains external processor 
										   // parameters.
	
	Var ParametersInitialized;             // True if the required parameters have been
										   // initialized.
	
	Var DataLogFile;                       // Data exchange log file.
	Var CommentObjectProcessingFlag;
	
	////////////////////////////////////////////////////////////////////////////////
	// HANDLER DEBUGGING VARIABLES
	
	Var ExportDataProcessor;
	Var LoadProcessing;
	Var SL20CompatibilityModeField;
	////////////////////////////////////////////////////////////////////////////////
	// FLAGS THAT SHOW WHETHER GLOBAL EVENT HANDLERS EXIST
	
	Var HasBeforeExportObjectGlobalHandler;
	Var HasAfterExportObjectGlobalHandler;
	
	Var HasBeforeConvertObjectGlobalHandler;
	
	Var HasBeforeImportObjectGlobalHandler;
	Var HasAfterImportObjectGlobalHandler;
	
	////////////////////////////////////////////////////////////////////////////////
	// VARIABLES THAT ARE USED IN EXCHANGE HANDLERS (BOTH FOR IMPORT AND FOR EXPORT)
	
	Var StringType;                 // Type("String")
	Var BooleanType;                // Type("Boolean")
	Var NumberType;                 // Type("Number")
	Var DateType;                   // Type("Date")
	Var UUIDType;                   // Type("UUID")
	Var ValueStorageType;           // Type("ValueStorage")
	Var BinaryDataType;             // Type("BinaryData")
	Var AccumulationRecordTypeType; // Type("AccumulationRecordType")
	Var ObjectDeletionType;         // Type("ObjectDeletion")
	Var AccountTypeType;            // Type("AccountType")
	Var TypeType;                   // Type("Type")
	Var MapType;                    // Type("Map")
	Var String36Type;
	Var String255Type;
	
	Var MapRegisterType;
	
	Var XMLNodeTypeEndElement;
	Var XMLNodeTypeStartElement;
	Var XMLNodeTypeText;
	
	Var EmptyDateValue;
	
	Var ErrorMessages; // Map, where Key is an error code and Value is error details
	
	////////////////////////////////////////////////////////////////////////////////
	// VARIABLES MODULE PROCESSING UNLOADING
	
	Var SnCounter;   // Number  counter NBSp
	Var WrittenToFileSn;
	Var PropertyConversionRuleTable;      	// ValueTable  pattern for recreating structure table by copying
	Var XMLRules;                           // XMLString contains description rules exchange
	Var TypesForTargetString;
	Var DocumentsForDeferredPostingField; 	// Table values for the documents after importing data
	Var DocumentsForDeferredPostingMap; 	// Map for storage additional properties documents after download data
	Var ObjectsForDeferredPostingField; 	// Map for records Objects reference types after download data
	Var ExchangeFile;  						// Consistently writeable/readable file exchange
	
	////////////////////////////////////////////////////////////////////////////////
	// EXPORT PROCESSING MODULE VARIABLES 
	
	Var DeferredDocumentRegisterRecordCount;
	Var ExchangeFileAttributes;	// Structure. Once the file is opened, it contains
								// exchange file attributes according to the exchange
								// format.
	Var LastSearchByRefNumber;
	Var StoredExportedObjectCountByTypes;
	Var AdditionalSearchParameterMap;
	Var TypeAndObjectNameMap;
	Var EmptyTypeValueMap;
	Var TypeDescriptionMap;
	Var ConversionRulesMap; // Map that is used for determining object conversion rules by
							// the type of the object.
	Var MessageNumberField;
	Var ReceivedMessageNumberField;
	Var EnableDocumentPosting;
	Var DataExportCallStack;
	Var GlobalNotWrittenObjectStack;
	Var DataMapForExportedItemUpdate;
	Var DeferredDocumentActionExecutionStartDate;
	Var DeferredDocumentActionExecutionEndDate;
	Var EventsAfterParameterImport;
	Var ObjectMappingRegisterManager;
	Var CurrentNestingLevelExportByRule;
	Var VisualExchangeSetupMode;
	Var ExchangeRuleInfoImportMode;
	Var SearchFieldInfoImportResultTable;
	Var CustomSearchFieldInfoOnDataExport;
	Var CustomSearchFieldInfoOnDataImport;
	Var InfobaseObjectMappingQuery;
	Var HasObjectChangeRecordDataAdjustment;
	Var HasObjectChangeRecordData;
	
	Var DataImportDataProcessorField;
	
	////////////////////////////////////////////////////////////////////////////////
	// VARIABLES FOR PROPERTY VALUES
	
	Var ErrorFlagField;
	Var ExchangeResultField;
	Var DataExchangeStateField;
	
	Var ExchangeMessageDataTableField;	// Map that contains value tables with data
										// from the exchange message. 
										// Key  String  TypeName. Value  ValueTable
										// table with object data (ValueTable)
	Var PackageHeaderDataTableField;    // Value table with data from the exchange 
										// messages package header file.
	Var ErrorMessageStringField;        // String  error message string.
	Var DataForImportTypeMapField;
	Var ImportedObjectCounterField;     // Imported object counter.
	Var ExportedObjectCounterField;     // Exported object counter.
	
	Var ExchangeResultPrioritiesField;  // Array  data exchange result priorities in
										// descending order.
	
	Var ObjectPropertyDescriptionTableField;// Map where Key is MetadataObject and Value
											// is ValueTable  metadata object property
											// description table.
	
	Var ExportedByRefObjectsField;          // Array of unique exported by reference 
											// objects.
	Var CreatedOnExportObjectsField;        // Array of unique created during export objects.
	
	Var ExportedByRefMetadataObjectsField;  // (Cache) Map, where Key is MetadataObject and 
											// Value is a flag that shows whether the 
											// object must be exported by reference: True
											// to export by reference, otherwise is False.
	
	Var ObjectChangeRecordRulesField;       // (Cache) ValueTable  contains object
											// registration rules (rules of the AOF
											// (Allowed Object Filter) kind for the current
											// exchange plan only).
	
	Var ExchangePlanNameField;
	
	Var ExchangePlanNodePropertyField;
	
	Var IncomingExchangeMessageFormatVersionField;
	
	////////////////////////////////////////////////////////////////////////////////
	// EXPORT PROPERTIES
	
	// Retrieves the data exchange execution error flag.
	//
	// Returns:
	//  Boolean - flag that shows data exchange execution error.
	//
	Function ErrorFlag() Export
		
		If TypeOf(ErrorFlagField) <> Type("Boolean") Then
			
			ErrorFlagField = False;
			
		EndIf;
		
		Return ErrorFlagField;
		
	EndFunction
	
	// Retrieves the data exchange execution result.
	//
	// Returns:
	//  EnumRef.ExchangeExecutionResults - data exchange execution result.
	//
	Function ExchangeExecutionResult() Export
		
		If TypeOf(ExchangeResultField) <> Type("EnumRef.ExchangeExecutionResults") Then
			
			ExchangeResultField = Enums.ExchangeExecutionResults.Completed;
			
		EndIf;
		
		Return ExchangeResultField;
		
	EndFunction
	
	// Retrieves the data exchange execution result string.
	//
	// Returns:
	//  String - string presentation of the EnumRef.ExchangeExecutionResults enumeration value.
	//
	Function ExchangeExecutionResultString() Export
		
		Return CommonUse.EnumValueName(ExchangeExecutionResult());
		
	EndFunction
	
	// Retrieves the number of the received data exchange message.
	//
	// Returns:
	//  Number - number of the received data exchange message.
	//
	Function ReceivedMessageNumber() Export
		
		If TypeOf(ReceivedMessageNumberField) <> Type("Number") Then
			
			ReceivedMessageNumberField = 0;
			
		EndIf;
		
		Return ReceivedMessageNumberField;
		
	EndFunction
	
	// Retrieves a map with tables of incoming exchange messages data.
	//
	// Returns:
	//  Map - map with tables of incoming exchange messages data.
	//
	Function ExchangeMessageDataTable() Export
		
		If TypeOf(ExchangeMessageDataTableField) <> Type("Map") Then
			
			ExchangeMessageDataTableField = New Map;
			
		EndIf;
		
		Return ExchangeMessageDataTableField;
		
	EndFunction
	
	// Retrieves a value table with incoming exchange message statistics and extra information.
	//
	// Returns:
	//  ValueTable - value table with incoming exchange message statistics and extra information.
	//
	Function PackageHeaderDataTable() Export
		
		If TypeOf(PackageHeaderDataTableField) <> Type("ValueTable") Then
			
			PackageHeaderDataTableField = New ValueTable;
			
			Columns = PackageHeaderDataTableField.Columns;
			
			Columns.Add("ObjectTypeString",    deTypeDescription("String"));
			Columns.Add("ObjectCountInSource", deTypeDescription("Number"));
			Columns.Add("SearchFields",        deTypeDescription("String"));
			Columns.Add("TableFields",         deTypeDescription("String"));
			
			Columns.Add("SourceTypeString", deTypeDescription("String"));
			Columns.Add("TargetTypeString", deTypeDescription("String"));
			
			Columns.Add("SynchronizeByID",  deTypeDescription("Boolean"));
			Columns.Add("IsObjectDeletion", deTypeDescription("Boolean"));
			Columns.Add("IsClassifier",     deTypeDescription("Boolean"));
			Columns.Add("UsePreview",       deTypeDescription("Boolean"));
			
		EndIf;
		
		Return PackageHeaderDataTableField;
		
	EndFunction
	
	// Retrieves the data exchange error message string.
	//
	// Returns:
	//  String - data exchange error message string.
	//
	Function ErrorMessageString() Export
		
		If TypeOf(ErrorMessageStringField) <> Type("String") Then
			
			ErrorMessageStringField = "";
			
		EndIf;
		
		Return ErrorMessageStringField;
		
	EndFunction
	
	// Retrieves the number of imported objects.
	//
	// Returns:
	//  Number - number of imported objects.
	//
	Function ImportedObjectCounter() Export
		
		If TypeOf(ImportedObjectCounterField) <> Type("Number") Then
			
			ImportedObjectCounterField = 0;
			
		EndIf;
		
		Return ImportedObjectCounterField;
		
	EndFunction
	
	// Retrieves the number of exported objects.
	//
	// Returns:
	//  Number - number of exported objects.
	//
	Function ExportedObjectCounter() Export
		
		If TypeOf(ExportedObjectCounterField) <> Type("Number") Then
			
			ExportedObjectCounterField = 0;
			
		EndIf;
		
		Return ExportedObjectCounterField;
		
	EndFunction
	
	////////////////////////////////////////////////////////////////////////////////
	// INTERNAL PROPERTIES
	
	Function DataProcessorForDataImport()
		
		Return DataImportDataProcessorField;
		
	EndFunction
	
	Function IsExchangeOverExternalConnection()
		
		Return DataProcessorForDataImport() <> Undefined;
		
	EndFunction
	
	Function DataExchangeState()
		
		If TypeOf(DataExchangeStateField) <> Type("Structure") Then
			
			DataExchangeStateField = New Structure;
			DataExchangeStateField.Insert("InfobaseNode");
			DataExchangeStateField.Insert("ActionOnExchange");
			DataExchangeStateField.Insert("ExchangeExecutionResult");
			DataExchangeStateField.Insert("StartDate");
			DataExchangeStateField.Insert("EndDate");
			
		EndIf;
		
		Return DataExchangeStateField;
		
	EndFunction
	
	Function DataForImportTypeMap()
		
		If TypeOf(DataForImportTypeMapField) <> Type("Map") Then
			
			DataForImportTypeMapField = New Map;
			
		EndIf;
		
		Return DataForImportTypeMapField;
		
	EndFunction
	
	Function DataImportToValueTableMode()
		
		Return Not DataImportIntoInfobaseMode();
		
	EndFunction
	
	Function UUIDColumnName()
		
		Return "UUID";
		
	EndFunction
	
	Function TypeStringColumnName()
		
		Return "TypeString";
		
	EndFunction
	
	Function EventLogMessageKey()
		
		If TypeOf(EventLogMessageKey) <> Type("String")
			Or IsBlankString(EventLogMessageKey) Then
			
			EventLogMessageKey = DataExchangeServer.EventLogMessageTextDataExchange();
			
		EndIf;
		
		Return EventLogMessageKey;
	EndFunction
	
	Function ExchangeResultPriorities()
		
		If TypeOf(ExchangeResultPrioritiesField) <> Type("Array") Then
			
			ExchangeResultPrioritiesField = New Array;
			ExchangeResultPrioritiesField.Add(Enums.ExchangeExecutionResults.Error);
			ExchangeResultPrioritiesField.Add(Enums.ExchangeExecutionResults.Error_MessageTransport);
			ExchangeResultPrioritiesField.Add(Enums.ExchangeExecutionResults.Canceled);
			ExchangeResultPrioritiesField.Add(Enums.ExchangeExecutionResults.Warning_ExchangeMessageReceivedPreviously);
			ExchangeResultPrioritiesField.Add(Enums.ExchangeExecutionResults.CompletedWithWarnings);
			ExchangeResultPrioritiesField.Add(Enums.ExchangeExecutionResults.Completed);
			ExchangeResultPrioritiesField.Add(Undefined);
			
		EndIf;
		
		Return ExchangeResultPrioritiesField;
	EndFunction
	
	Function ObjectPropertyDescriptionTables()
		
		If TypeOf(ObjectPropertyDescriptionTableField) <> Type("Map") Then
			
			ObjectPropertyDescriptionTableField = New Map;
			
		EndIf;
		
		Return ObjectPropertyDescriptionTableField;
	EndFunction
	
	Function DocumentsForDeferredPosting()
		
		If TypeOf(DocumentsForDeferredPostingField) <> Type("ValueTable") Then
			
			// Initializing a table for deferred document posting
			DocumentsForDeferredPostingField = New ValueTable;
			DocumentsForDeferredPostingField.Columns.Add("DocumentRef");
			DocumentsForDeferredPostingField.Columns.Add("DocumentDate", deTypeDescription("Date"));
			
		EndIf;
		
		Return DocumentsForDeferredPostingField;
	EndFunction
	
	
	Function AdditionalPropertiesForDeferredPosting()
		
		If TypeOf(DocumentsForDeferredPostingMap) <> Type("Map") Then
			
			// Initialize document deferred posting map
			DocumentsForDeferredPostingMap = New Map;
			
		EndIf;
		
		Return DocumentsForDeferredPostingMap;
		
	EndFunction
	
	Function ObjectsForDeferredPosting()
		
		If TypeOf(ObjectsForDeferredPostingField) <> Type("Map") Then
			
			// Initialize object deferred posting map
			ObjectsForDeferredPostingField = New Map;
			
		EndIf;
		
		Return ObjectsForDeferredPostingField;
		
		
	EndFunction
	
	Function ExportedByRefObjects()
		
		If TypeOf(ExportedByRefObjectsField) <> Type("Array") Then
			
			ExportedByRefObjectsField = New Array;
			
		EndIf;
		
		Return ExportedByRefObjectsField;
	EndFunction
	Function CreatedOnExportObjects()
		
		If TypeOf(CreatedOnExportObjectsField) <> Type("Array") Then
			
			CreatedOnExportObjectsField = New Array;
			
		EndIf;
		
		Return CreatedOnExportObjectsField;
	EndFunction
	
	Function ExportedByRefMetadataObjects()
		
		If TypeOf(ExportedByRefMetadataObjectsField) <> Type("Map") Then
			
			ExportedByRefMetadataObjectsField = New Map;
			
		EndIf;
		
		Return ExportedByRefMetadataObjectsField;
	EndFunction
	
	Function ExportObjectByRef(Object, ExchangePlanNode)
		
		MetadataObject = Metadata.FindByType(TypeOf(Object));
		
		If MetadataObject = Undefined Then
			Return False;
		EndIf;
		
		// Getting the value from the cache
		Result = ExportedByRefMetadataObjects().Get(MetadataObject);
		
		If Result = Undefined Then
			
			Result = False;
			
			// Getting the export flag by reference
			Filter = New Structure("MetadataObjectName", MetadataObject.FullName());
			
			RuleArray = ObjectChangeRecordRules(ExchangePlanNode).FindRows(Filter);
			
			For Each Rule In RuleArray Do
				
				If Not IsBlankString(Rule.FlagAttributeName) Then
					
					FlagAttributeValue = Undefined;
					ExchangePlanNodeProperties(ExchangePlanNode).Property(Rule.FlagAttributeName, FlagAttributeValue);
					
					Result = Result Or ( FlagAttributeValue = Enums.ExchangeObjectExportModes.ExportIfNecessary
					Or FlagAttributeValue = Enums.ExchangeObjectExportModes.EmptyRef());
					
					If Result Then
						Break;
					EndIf;
					
				EndIf;
				
			EndDo;
			
			// Saving the received value in the cache
			ExportedByRefMetadataObjects().Insert(MetadataObject, Result);
			
		EndIf;
		
		Return Result;
	EndFunction
	
	Function ExchangePlanName()
		
		If TypeOf(ExchangePlanNameField) <> Type("String")
			Or IsBlankString(ExchangePlanNameField) Then
			
			If ValueIsFilled(NodeForExchange) Then
				
				ExchangePlanNameField = DataExchangeCached.GetExchangePlanName(NodeForExchange);
				
			ElsIf ValueIsFilled(ExchangeNodeDataImport) Then
				
				ExchangePlanNameField = DataExchangeCached.GetExchangePlanName(ExchangeNodeDataImport);
				
			ElsIf ValueIsFilled(ExchangePlanInDEName) Then
				
				ExchangePlanNameField = ExchangePlanInDEName;
				
			Else
				
				ExchangePlanNameField = "";
				
			EndIf;
			
		EndIf;
		
		Return ExchangePlanNameField;
	EndFunction
	
	Function ExchangePlanNodeProperties(Node)
		
		If TypeOf(ExchangePlanNodePropertyField) <> Type("Structure") Then
			
			ExchangePlanNodePropertyField = New Structure;
			
			// Getting attribute names
			AttributeNames = CommonUse.AttributeNamesByType(Node, Type("EnumRef.ExchangeObjectExportModes"));
			
			// Getting attribute values
			If Not IsBlankString(AttributeNames) Then
				
				ExchangePlanNodePropertyField = CommonUse.ObjectAttributeValues(Node, AttributeNames);
				
			EndIf;
			
		EndIf;
		
		Return ExchangePlanNodePropertyField;
	EndFunction
	
	Function IncomingExchangeMessageFormatVersion()
		
		If TypeOf(IncomingExchangeMessageFormatVersionField) <> Type("String") Then
			
			IncomingExchangeMessageFormatVersionField = "0.0.0.0";
			
		EndIf;
		
		// Adding zeroes to complete the incoming messages format version
		VersionDigits = StringFunctionsClientServer.SplitStringIntoSubstringArray(IncomingExchangeMessageFormatVersionField, ".");
		
		If VersionDigits.Count() < 4 Then
			
			DigitCountAdd = 4 - VersionDigits.Count();
			
			For A = 1 to DigitCountAdd Do
				
				VersionDigits.Add("0");
				
			EndDo;
			
			IncomingExchangeMessageFormatVersionField = StringFunctionsClientServer.StringFromSubstringArray(VersionDigits, ".");
			
		EndIf;
		
		Return IncomingExchangeMessageFormatVersionField;
	EndFunction
	
Function MessageNo()
		
	If TypeOf(MessageNumberField) <> Type("Number") Then
			
		MessageNumberField = 0;
			
	EndIf;
		
	Return MessageNumberField;
		
EndFunction
	
////////////////////////////////////////////////////////////////////////////////
// CACHE FUNCTION
	
Function ObjectPropertyInfoTable(MetadataObject)
		
	Result = ObjectPropertyDescriptionTables().Get(MetadataObject);
		
	If Result = Undefined Then
			
		Result = CommonUse.GetObjectPropertyInfoTable(MetadataObject, "Name");
			
		ObjectPropertyDescriptionTables().Insert(Result);
			
	EndIf;
		
	Return Result;
EndFunction
	
Function ObjectChangeRecordRules(ExchangePlanNode)
		
	If TypeOf(ObjectChangeRecordRulesField) <> Type("ValueTable") Then
			
		ObjectChangeRecordRules = DataExchangeServerCall.SessionParametersObjectChangeRecordRules().Get();
			
		Filter = New Structure;
		Filter.Insert("ExchangePlanName", DataExchangeCached.GetExchangePlanName(ExchangePlanNode));
			
		ObjectChangeRecordRulesField = ObjectChangeRecordRules.Copy(Filter, "MetadataObjectName, FlagAttributeName");
		ObjectChangeRecordRulesField.Indexes.Add("MetadataObjectName");
			
	EndIf;
		
	Return ObjectChangeRecordRulesField;
		
EndFunction
	
////////////////////////////////////////////////////////////////////////////////
// EXPORT PROCEDURES AND FUNCTIONS
	
// DATA EXPORT
	
// Exports data.
//  - all objects are written to a file.
//  - The following data is written to the file header:
//     - exchange rules.
//     - data type details.
//     - exchange details (exchange plan name, node codes, message numbers
//       (acknowledgment)).
// 
Procedure ExecuteDataExport(DataProcessorForDataImport = Undefined) Export
		
	SetErrorFlag(False);
		
		ErrorMessageStringField = "";
		DataExchangeStateField = Undefined;
		ExchangeResultField = Undefined;
		ExportedByRefObjectsField = Undefined;
		CreatedOnExportObjectsField = Undefined;
		ExportedByRefMetadataObjectsField = Undefined;
		ObjectChangeRecordRulesField = Undefined;
		ExchangePlanNodePropertyField = Undefined;
		SL20CompatibilityModeField = Undefined;
		DataImportDataProcessorField = DataProcessorForDataImport;
		
		EnableExchangeLog();
		
		// Opening the exchange file
		If IsExchangeOverExternalConnection() Then
			ExchangeFile = New TextWriter;
		Else
			OpenExportFile();
		EndIf;
		
		If ErrorFlag() Then
			ExchangeFile = Undefined;
			DisableExchangeProtocol();
			Return;
		EndIf;
		
		SecurityProfileName = InitializeDataProcessors();
		
		If SecurityProfileName <> Undefined Then
			SetSafeMode(SecurityProfileName);
		EndIf;
		
		If IsExchangeOverExternalConnection() Then
			
			DataProcessorForDataImport().ExternalConnectionBeforeDataImport();
			
			DataProcessorForDataImport().ImportExchangeRules(XMLRules, "String");
			
			If DataProcessorForDataImport().ErrorFlag() Then
				
				MessageString = NStr("en = 'EXTERNAL CONNECTION: %1'");
				MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, DataProcessorForDataImport().ErrorMessageString());
				WriteToExecutionLog(MessageString);
				DisableExchangeProtocol();
				Return;
				
			EndIf;
			
			Cancel = False;
			
			DataProcessorForDataImport().ExternalConnectionConversionHandlerBeforeDataImport(Cancel);
			
			If Cancel Then
				DisableExchangeProtocol();
				ExportDataProcessor = Undefined;
				Return;
			EndIf;
			
		Else
			
			// Writing the exchange rules to the file
			ExchangeFile.WriteLine(XMLRules);
			
		EndIf;
		
		// DATA EXPORT
		
		Try
			ExecuteExport();
		Except
			WriteToExecutionLog(DetailErrorDescription(ErrorInfo()));
			DisableExchangeProtocol();
			ExchangeFile = Undefined;
			ExportedByRefObjectsField = Undefined;
			CreatedOnExportObjectsField = Undefined;
			ExportedByRefMetadataObjectsField = Undefined;
			Return;
		EndTry;
		
		If IsExchangeOverExternalConnection() Then
			
			If Not ErrorFlag() Then
				
				DataProcessorForDataImport().ExternalConnectionAfterDataImport();
				
			EndIf;
			
		Else
			
			// Closing the exchange file
			CloseFile();
			
		EndIf;
		
		DisableExchangeProtocol();
		
		// Clearing modal variables before they will be put into the platform cache
		ExportedByRefObjectsField = Undefined; 
		CreatedOnExportObjectsField = Undefined;
		ExportedByRefMetadataObjectsField = Undefined;
		ExportDataProcessor = Undefined;
		ExchangeFile = Undefined;
		
	EndProcedure
	
// DATA IMPORT
	
// Imports data from the exchange messages file into the infobase.
// 
Procedure ExecuteDataImport() Export
		
	MessageReader = Undefined;
	Try
		DataImportMode = "ImportToInfobase";
			
		ErrorMessageStringField = "";
		DataExchangeStateField = Undefined;
		ExchangeResultField = Undefined;
		DataForImportTypeMapField = Undefined;
		ImportedObjectCounterField = Undefined;
		DocumentsForDeferredPostingField = Undefined;
		ObjectsForDeferredPostingField = Undefined;
		DocumentsForDeferredPostingMap = Undefined;
		ExchangePlanNodePropertyField = Undefined;
		IncomingExchangeMessageFormatVersionField = Undefined;
		SL20CompatibilityModeField = Undefined;
		HasObjectChangeRecordDataAdjustment = False;
		HasObjectChangeRecordData = False;
			
		GlobalNotWrittenObjectStack = New Map;
		LastSearchByRefNumber = 0;
			
		InitManagersAndMessages();
			
		SetErrorFlag(False);
			
		InitializeCommentsOnDataExportAndImport();
			
		EnableExchangeLog();
			
		CustomSearchFieldInfoOnDataImport = New Map;
			
		AdditionalSearchParameterMap = New Map;
		ConversionRulesMap = New Map;
			
		DeferredDocumentRegisterRecordCount = 0;
			
			
		If ContinueOnError Then
			UseTransactions = False;
		EndIf;
			
		If ProcessedObjectNumberToUpdateStatus = 0 Then
			ProcessedObjectNumberToUpdateStatus = 100;
		EndIf;
		NewSecurityProfileName = InitializeDataProcessors();
			
		If NewSecurityProfileName <> Undefined  Then
			SetSafeMode(NewSecurityProfileName);
		EndIf;
			
		StartReadMessage(MessageReader);
		If UseTransactions Then
			BeginTransaction();
		EndIf;
			
			
		Try
				
			ReadData(MessageReader);
				
			If ErrorFlag() Then
				Raise NStr("en = 'Errors occurred during data import.'");
			EndIf;
				
				
			// Deferred writing
			ExecuteWriteNotWrittenObjects();
				
				
			If ErrorFlag() Then
				Raise NStr("en = 'Errors occurred during data import.'");
			EndIf;
				
				
			FinishMessageReader(MessageReader);
				
			If UseTransactions Then
				CommitTransaction();
			EndIf;
		Except
			If UseTransactions Then
				RollbackTransaction();
			EndIf;
			BreakMessageReader(MessageReader);
				
			Raise;
		EndTry;
			
			
		// Posting documents in queue
		ExecuteDeferredDocumentPosting();
		ExecuteDeferredObjectWriting();
			
	Except
		If MessageReader <> Undefined
			And MessageReader.MessageReceivedEarlier Then
			WriteToExecutionLog(174,,,,,,
				
			Enums.ExchangeExecutionResults.Warning_ExchangeMessageReceivedPreviously
			);
		Else
			WriteToExecutionLog(DetailErrorDescription(ErrorInfo()));
		EndIf;
	EndTry;
		
	DisableExchangeProtocol();
		
		
	// Resetting modal variables before storing data processor to platform cache
	DocumentsForDeferredPostingField = Undefined;
	ObjectsForDeferredPostingField = Undefined;
	DocumentsForDeferredPostingMap = Undefined;
	DataForImportTypeMapField = Undefined;
	GlobalNotWrittenObjectStack = Undefined;
	ConversionRulesMap = Undefined;
	LoadProcessing = Undefined;
	ExchangeFile = Undefined;
		
EndProcedure
	
	
	// BATCH DATA IMPORT
	
	// Imports data of the specified object types from the exchange messages file into the infobase.
	// 
	// Parameters:
	//  TableToImport - Array of String  array of types to be imported from the exchange message.
	//  Example: How to import Counterparties catalog items only.
	//   TableToImport = New Array;
	//   TableToImport.Add("CatalogRef.Counterparties");
	// 
	//  Use the ExecuteExchangeMessagAnalysis procedure to get the list of types in the
	//  current exchange message.
	// 
	Procedure ExecuteDataImportForInfobase(TableToImport) Export
		
		DataImportMode = "ImportToInfobase";
		DataExchangeStateField = Undefined;
		ExchangeResultField = Undefined;
		DocumentsForDeferredPostingField = Undefined; 
		ObjectsForDeferredPostingField = Undefined;
		DocumentsForDeferredPostingMap = Undefined;
		ExchangePlanNodePropertyField = Undefined;
		IncomingExchangeMessageFormatVersionField = Undefined;
		SL20CompatibilityModeField = Undefined;
		HasObjectChangeRecordDataAdjustment = False;
		HasObjectChangeRecordData = False;
		GlobalNotWrittenObjectStack = New Map;
		ConversionRulesMap = New Map;
		
		// Import start date
		DataExchangeState().StartDate = CurrentSessionDate();
		
		// Writing a message to the event log
		MessageString = NStr("en = 'The data exchange process for the %1 node started.'", CommonUseClientServer.DefaultLanguageCode());
		MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, String(ExchangeNodeDataImport));
		WriteLogEventDataExchange(MessageString, EventLogLevel.Information);
		
		ExecuteSelectiveMessageReader(TableToImport);
		
		// Import end date
		DataExchangeState().EndDate = CurrentSessionDate();
		
		// Writing the data export report to the information register
		WriteDataImportEnd();
		
		// Event log message
		MessageString = NStr("en = '%1, %2; %3 objects was processed.'");
		MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString,
		ExchangeExecutionResult(),
		Enums.ActionsOnExchange.DataImport,
		Format(ImportedObjectCounter(), "NG=0"));
		
		WriteLogEventDataExchange(MessageString, EventLogLevel.Information);
		
		// Clearing modal variables before putting them into the platform cache
		DocumentsForDeferredPostingField = Undefined;
		
		ObjectsForDeferredPostingField = Undefined;
		DocumentsForDeferredPostingMap = Undefined;
		DataForImportTypeMapField = Undefined;
		GlobalNotWrittenObjectStack = Undefined;
		ConversionRulesMap = Undefined;
		ExchangeFile = Undefined;
		
	EndProcedure
	
	// Imports data of the specified type from the exchange message file into a value table.
	// 
	// Parameters:
	//  TableToImport - Array of String  array of types to be imported from the exchange message.
	//  Example: How to import Counterparties catalog items only.
	//   TableToImport = New Array;
	//   TableToImport.Add("CatalogRef.Counterparties");
	// 
	// Use the ExecuteExchangeMessagAnalysis procedure to get the list of types in the
	// current exchange message.
	// 
	Procedure ExecuteDataImportIntoValueTable(TableToImport) Export
		
		DataImportMode = "ImportToValueTable";
		DataExchangeStateField = Undefined;
		ExchangeResultField = Undefined;
		DocumentsForDeferredPostingField = Undefined;
		ObjectsForDeferredPostingField = Undefined;
		DocumentsForDeferredPostingMap = Undefined;
		ExchangePlanNodePropertyField = Undefined;
		IncomingExchangeMessageFormatVersionField = Undefined;
		SL20CompatibilityModeField = Undefined;
		HasObjectChangeRecordDataAdjustment = False;
		HasObjectChangeRecordData = False;
		GlobalNotWrittenObjectStack = New Map;
		ConversionRulesMap = New Map;
		
		UseTransactions = False;
		
		// Initializing the exchange message data table
		For Each DataTableKey In TableToImport Do
			
			SubstringArray = StringFunctionsClientServer.SplitStringIntoSubstringArray(DataTableKey, "#");
			
			ObjectType = SubstringArray[1];
			
			ExchangeMessageDataTable().Insert(DataTableKey, InitExchangeMessageDataTable(Type(ObjectType)));
			
		EndDo;
		
		ExecuteSelectiveMessageReader(TableToImport);
		
		// Clearing modal variables before putting them into the platform cache
		DocumentsForDeferredPostingField = Undefined;
		ObjectsForDeferredPostingField = Undefined;
		DocumentsForDeferredPostingMap = Undefined;
		DataForImportTypeMapField = Undefined;
		GlobalNotWrittenObjectStack = Undefined;
		ConversionRulesMap = Undefined;
		ExchangeFile = Undefined;
		
	EndProcedure
	
	// Consistently reads the exchange messages file to perform the following actions:
	//   deletes change records by the incoming message number,
	//   imports exchange rules,
	//   imports data type details,
	//   imports data mapping details and writes it to the infobase,
	//   collects object type and quantity details.
	// 
	Procedure ExecuteExchangeMessagAnalysis() Export
		
		MessageReader = Undefined;
		Try
			SetErrorFlag(False);
			
			UseTransactions = False;
			
			ErrorMessageStringField = "";
			DataExchangeStateField = Undefined;
			ExchangeResultField = Undefined;
			IncomingExchangeMessageFormatVersionField = Undefined;
			HasObjectChangeRecordDataAdjustment = False;
			HasObjectChangeRecordData = False;
			GlobalNotWrittenObjectStack = New Map;
			ConversionRulesMap = New Map;
			
			EnableExchangeLog(); 
			InitManagersAndMessages();
			
			// Analysis start date
			DataExchangeState().StartDate = CurrentSessionDate();
			
			// Clearing the modal variable value
			PackageHeaderDataTableField = Undefined;
			
			StartReadMessage(MessageReader, True);
			
			Try
				
				// Reading the exchange message data
				ReadDataInAnalysisMode(MessageReader);
				
				
				If ErrorFlag() Then
					Raise NStr("en = 'Errors occurred during data analyzing.'");
				EndIf;
				
				// Generating a temporary data table
				TemporaryPackageHeaderDataTable = PackageHeaderDataTable().Copy(, "SourceTypeString, TargetTypeString, SearchFields, TableFields");
				TemporaryPackageHeaderDataTable.GroupBy("SourceTypeString, TargetTypeString, SearchFields, TableFields");
				
				// Grouping the package header data table
				PackageHeaderDataTable().GroupBy("ObjectTypeString, SourceTypeString, TargetTypeString, SynchronizeByID, IsClassifier, IsObjectDeletion, UsePreview",
				"ObjectCountInSource");
				
				PackageHeaderDataTable().Columns.Add("SearchFields", deTypeDescription("String"));
				PackageHeaderDataTable().Columns.Add("TableFields", deTypeDescription("String"));
				
				For Each TableRow In PackageHeaderDataTable() Do
					
					Filter = New Structure;
					Filter.Insert("SourceTypeString", TableRow.SourceTypeString);
					Filter.Insert("TargetTypeString", TableRow.TargetTypeString);
					
					TemporaryTableRows = TemporaryPackageHeaderDataTable.FindRows(Filter);
					
					TableRow.SearchFields  = TemporaryTableRows[0].SearchFields;
					TableRow.TableFields   = TemporaryTableRows[0].TableFields;
					
				EndDo;
				
				FinishMessageReader(MessageReader);
				
			Except
				BreakMessageReader(MessageReader);
				Raise;
			EndTry;
			
			
		Except
			If MessageReader <> Undefined
				And MessageReader.MessageReceivedEarlier Then
				WriteToExecutionLog(174,,,,,,
				Enums.ExchangeExecutionResults.Warning_ExchangeMessageReceivedPreviously
				);
			Else
				WriteToExecutionLog(DetailErrorDescription(ErrorInfo()));
			EndIf;
			
		EndTry;
		
		DisableExchangeProtocol();
		
		// Analysis end date 
		DataExchangeState().EndDate = CurrentSessionDate();
		
		// Writing the analysis report to the information register
		WriteDataImportEnd();
		
		// Clearing modal variables before putting them into the platform cache
		DocumentsForDeferredPostingField 	= Undefined; 
		ObjectsForDeferredPostingField 		= Undefined;
		DocumentsForDeferredPostingMap 		= Undefined;
		DataForImportTypeMapField 			= Undefined;
		GlobalNotWrittenObjectStack 		= Undefined;
		ConversionRulesMap 					= Undefined;
		ExchangeFile 						= Undefined;
		
	EndProcedure
	
	////////////////////////////////////////////////////////////////////////////////
	// PROCEDURE FOR PROCESSING EXTERNAL CONNECTION EVENT
	
	// Imports data from an XML string.
	//
	Procedure ExternalConnectionImportDataFromXMLString(XMLLine) Export
		
		ExchangeFile.SetString(XMLLine);
		MessageReader = Undefined;
		
		Try
			
			ReadDataInExternalConnectionMode(MessageReader);
			
		Except
			
			
			If MessageReader <> Undefined
				And MessageReader.MessageReceivedEarlier Then
				WriteToExecutionLog(174,,,,,,
				Enums.ExchangeExecutionResults.Warning_ExchangeMessageReceivedPreviously
				);
			Else
				
				WriteToExecutionLog(DetailErrorDescription(ErrorInfo()));
			EndIf;
			
		EndTry;
		
	EndProcedure
	
	// Execute Before data import handler for external connection.
	//
	Procedure ExternalConnectionConversionHandlerBeforeDataImport(Cancel) Export
		
		// {Handler: Navigation start BeforeDataImport} page
		If Not IsBlankString(Conversion.BeforeDataImport) Then
			
			Try
				
				If SL20CompatibilityMode() Then
					
					Execute(Conversion.BeforeDataImport);
					
				Else
					
					ExecuteHandler_Conversion_BeforeDataImport(ExchangeFile, Cancel);
					
				EndIf;
			Except
				WriteErrorInfoConversionHandlers(22, ErrorDescription(), NStr("en = 'BeforeDataImport (conversion)'"));
				Cancel = True;
			EndTry;
			
		EndIf;
		
		If Cancel Then // Canceling data import
			Return;
		EndIf;
		// {Handler: BeforeDataImport} End 
		
	EndProcedure
	
	// Initializes settings before data import through the external connection
	//
	Procedure ExternalConnectionBeforeDataImport() Export
		
		DataImportMode = "ImportToInfobase";
		
		ErrorMessageStringField 			= "";
		DataExchangeStateField 				= Undefined;
		ExchangeResultField 				= Undefined;
		DataForImportTypeMapField 			= Undefined;
		ImportedObjectCounterField 			= Undefined;
		DocumentsForDeferredPostingField 	= Undefined;
		ObjectsForDeferredPostingField 		= Undefined;
		DocumentsForDeferredPostingMap 		= Undefined;
		ExchangePlanNodePropertyField 		= Undefined;
		IncomingExchangeMessageFormatVersionField = Undefined;
		SL20CompatibilityModeField 			= Undefined;
		
		GlobalNotWrittenObjectStack = New Map;
		LastSearchByRefNumber = 0;
		
		InitManagersAndMessages();
		
		SetErrorFlag(False);
		
		InitializeCommentsOnDataExportAndImport();
		
		EnableExchangeLog();
		
		CustomSearchFieldInfoOnDataImport = New Map;
		
		AdditionalSearchParameterMap = New Map;
		ConversionRulesMap = New Map;
		
		DeferredDocumentRegisterRecordCount = 0;
		
		If ProcessedObjectNumberToUpdateStatus = 0 Then
			ProcessedObjectNumberToUpdateStatus = 100;
		EndIf;
		
		// Clearing exchange rules
		Rules.Clear();
		ConversionRuleTable.Clear();
		
		ExchangeFile = New XMLReader;
		
		HasObjectChangeRecordData = False;
		HasObjectChangeRecordDataAdjustment = False;
	EndProcedure
	
// Executes After data import handler.
// Clears variables and executes a deferred document posting and object writing.
//
Procedure ExternalConnectionAfterDataImport() Export
		
	// Deferred object writing
	ExecuteWriteNotWrittenObjects();
		
	// AfterDataImport handler
	If Not ErrorFlag() Then
			
		If Not IsBlankString(Conversion.AfterDataImport) Then
				
			Try
					
				If SL20CompatibilityMode() Then
						
					Execute(Conversion.AfterDataImport);
						
				Else
						
					ExecuteHandler_Conversion_AfterDataImport();
						
				EndIf;
			Except
				WriteErrorInfoConversionHandlers(23, ErrorDescription(), NStr("en = 'AfterDataImport (conversion)'"));
			EndTry;
				
		EndIf;
			
	EndIf;
		
	If Not ErrorFlag() Then
			
		// Posting documents from the queue
		ExecuteDeferredDocumentPosting();
		ExecuteDeferredObjectWriting();
			
		// Writing the incoming message number
		NodeObject = ExchangeNodeDataImport.GetObject();
		NodeObject.ReceivedNo = MessageNo();
		NodeObject.AdditionalProperties.Insert("Import");
			
			
		Try
			NodeObject.Lock();
		Except
			WriteErrorInfoToLog(173, BriefErrorDescription(ErrorInfo()), NodeObject);
		EndTry;
			
	EndIf;
	If Not ErrorFlag() Then
		NodeObject.Write();
			
		If HasObjectChangeRecordDataAdjustment = True Then
				
			InformationRegisters.CommonInfobaseNodeSettings.CommitMappingInfoAdjustmentUnconditionally(ExchangeNodeDataImport);
				
		EndIf;
			
		If HasObjectChangeRecordData = True Then
				
			InformationRegisters.InfobaseObjectMappings.DeleteObsoleteExportByRefModeRecords(ExchangeNodeDataImport);
				
		EndIf;
			
	EndIf;
		
	DisableExchangeProtocol();
		
	// Clearing modal variables before putting them into the platform cache
	DocumentsForDeferredPostingField = Undefined;
		
	ObjectsForDeferredPostingField 	= Undefined;
	DocumentsForDeferredPostingMap 	= Undefined;
	DataForImportTypeMapField 		= Undefined;
	GlobalNotWrittenObjectStack 	= Undefined;
	ExchangeFile 					= Undefined;
		
EndProcedure
	
	// Opens a new transaction.
	//
	Procedure ExternalConnectionCheckTransactionStartAndCommitOnDataImport() Export
		
		If UseTransactions
			And ObjectCountPerTransaction > 0
			And ImportedObjectCounter() % ObjectCountPerTransaction = 0 Then
			
			CommitTransaction();
			BeginTransaction();
			
		EndIf;
		
	EndProcedure
	
	// Opens the transaction for exchange through the external connection.
	//
	Procedure ExternalConnectionBeginTransactionOnDataImport() Export
		
		If UseTransactions Then
			BeginTransaction();
		EndIf;
		
	EndProcedure
	
	// Commits the transaction of exchange through the external connection (if import is executed in transaction).
	//
	Procedure ExternalConnectionCommitTransactionOnDataImport() Export
		
		If UseTransactions Then
			
			If ErrorFlag() Then
				RollbackTransaction();
			Else
				CommitTransaction();
			EndIf;
			
		EndIf;
		
	EndProcedure
	
	// Rollback the transaction of exchange through external connection.
	//
	Procedure ExternalConnectionRollbackTransactionOnDataImport() Export
		
		While TransactionActive() Do
			RollbackTransaction();
		EndDo;
		
	EndProcedure
	////////////////////////////////////////////////////////////////////////////////
	// PROCEDURES AND FUNCTIONS USED IN EVENT HANDLERS
	
	// Creates a record about object deleting in exchange file.
	//
	// Parameters:
	// Ref - Object to delete reference.
	// TargetType - String - target type string presentation.
	// SourceType - String - source type string presentation.
	// 
	Procedure WriteToFileObjectDeletion(Ref, Val TargetType, Val SourceType) Export
		
		Target = CreateNode("ObjectDeletion");
		
		SetAttribute(Target, "TargetType", TargetType);
		SetAttribute(Target, "SourceType", SourceType);
		
		SetAttribute(Target, "UUID", Ref.UUID());
		
		Target.WriteEndElement(); // ObjectDeletion
		
		WriteToFile(Target);
		
		IncreaseExportedObjectCounter();
		
	EndProcedure
	
	// Registers an object that is created during data export.
	//
	// Parameters:
	// Ref - reference to registered object.
	// 
	Procedure RegisterObjectCreatedDuringExport(Ref) Export
		
		If CreatedOnExportObjects().Find(Ref) = Undefined Then
			
			CreatedOnExportObjects().Add(Ref);
			
		EndIf;
		
	EndProcedure
	
	// Logs a warning in the event log.
	// If during data exchange this procedure is executed, the data exchange is not stopped.
	// After exchange end the exchange status in the monitor have the value "Warning" 
	// if errors does not occur.
	//
	// Parameters:
	//  Warning - String - warning text that must be registered.
	// Information, warnings, and errors that occur during data exchange are recorded in the event log.
	// 
	Procedure RecordWarning(Warning) Export
		
		WriteToExecutionLog(Warning,,False,,,, Enums.ExchangeExecutionResults.CompletedWithWarnings);
		
	EndProcedure
	
	
	// Returns the flag that shows whether it is import to the infobase.
	// 
	// Returns:
	// Boolean - flag that shows whether it is import to the infobase.
	// 
	Function DataImportIntoInfobaseMode() Export
		
		Return IsBlankString(DataImportMode) Or Upper(DataImportMode) = Upper("ImportToInfobase");
		
	EndFunction
	
	// Writes an object to the infobase.
	//
	// Parameters:
	// Object - object to write.
	// Type - String  Object type as string.
	// 
	Procedure WriteObjectToInfobase(Object, Type, WriteObject = False, Val SendBack = False) Export
		
		// Do not write to VT in import mode
		If DataImportToValueTableMode() Then
			Return;
		EndIf;
		
		If CommonUseCached.DataSeparationEnabled()
			And CommonUseCached.CanUseSeparatedData()
			And Not CommonUseCached.IsSeparatedMetadataObject(Object.Metadata().FullName(), CommonUseCached.MainDataSeparator())
			And Not CommonUseCached.IsSeparatedMetadataObject(Object.Metadata().FullName(), CommonUseCached.AuxiliaryDataSeparator()) Then
			
			ErrorMessageString = NStr("en = 'Try changing the shared data (%1) in a split session.'");
			ErrorMessageString = StringFunctionsClientServer.SubstituteParametersInString(ErrorMessageString, Object.Metadata().FullName());
			
			WriteToExecutionLog(ErrorMessageString,, False,,,, Enums.ExchangeExecutionResults.CompletedWithWarnings);
			
			Return;
			
		EndIf;
		
		// Set data import mode for object
		SetDataExchangeLoad(Object,, SendBack);
		
		// Checking deletion mark of predefined item
		ClearPredefinedItemDeletionMark(Object, Type);
		
		
		BeginTransaction();
		Try
			
			// Writing an object to the transaction
			Object.Write();
			
			InfobaseObjectMappings = Undefined;
			If Object.AdditionalProperties.Property("InfobaseObjectMappings", InfobaseObjectMappings)
				And InfobaseObjectMappings <> Undefined Then
				
				InfobaseObjectMappings.SourceUUID = Object.Ref;
				
				InformationRegisters.InfobaseObjectMappings.AddRecord(InfobaseObjectMappings);
			EndIf;
			CommitTransaction();
		Except
			RollbackTransaction();
			
			WriteObject = False;
			
			ErrorMessageString = WriteErrorInfoToLog(26, DetailErrorDescription(ErrorInfo()), Object, Type);
			
			If Not ContinueOnError Then
				Raise ErrorMessageString;
			EndIf;
			
		EndTry;
		
	EndProcedure
	
	// Cancels infobase object posting.
	//
	// Parameters:
	// Object - object to cancel posting.
	// Type - String - Object type as string.
	//
	Procedure UndoObjectPostingInInfobase(Object, Type, WriteObject = False) Export
		
		If DataExchangeEvents.ImportProhibited(Object, ExchangeNodeDataImport) Then
			Return;
		EndIf;
		
		// Set data import mode for object
		SetDataExchangeLoad(Object);
		
		BeginTransaction();
		Try
			
			// Cancelling document posting
			Object.Posted = False;
			Object.Write();
			
			
			InfobaseObjectMappings = Undefined;
			If Object.AdditionalProperties.Property("InfobaseObjectMappings", InfobaseObjectMappings)
				And InfobaseObjectMappings <> Undefined Then
				
				InfobaseObjectMappings.SourceUUID = Object.Ref;
				
				InformationRegisters.InfobaseObjectMappings.AddRecord(InfobaseObjectMappings);
			EndIf;
			
			DeleteDocumentRegisterRecords(Object);
			
			CommitTransaction();
		Except
			RollbackTransaction();
			
			WriteObject = False;
			
			ErrorMessageString = WriteErrorInfoToLog(26, DetailErrorDescription(ErrorInfo()), Object, Type);
			
			
			If Not ContinueOnError Then
				Raise ErrorMessageString;
			EndIf;
			
		EndTry;
		
	EndProcedure
	
// Exports the object according to the specified conversion rule.
//
// Parameters:
//  Source       - arbitrary source data
//  Target       - xmlnode object target
//  IncomingData - arbitrary auxiliary data that is passed to the conversion rule.
//  OutgoingData - arbitrary auxiliary data that is passed to property 
//                 conversion rules.
//  OCRName      - name of the conversion rule used in the export.
//  RefNode      - target object reference XML node.
//  GetRefNodeOnly - if True, the object is not exported 
//                   but the reference XML node is generated.
//  OCR          - conversion rule reference.
// Returns:
//  Reference XML node or the target value.
//
Function ExportByRule(Source     
		= Undefined,
		Target     = Undefined,
		IncomingData   = Undefined,
		OutgoingData   = Undefined,
		OCRName     = "",
		RefNode    = Undefined,
		GetRefNodeOnly = False,
		OCR      = Undefined,
		ExportSubordinateObjectRefs = True,
		ExportRegisterRecordSetRow = False,
		ParentNode    = Undefined,
		ConstantNameForExport  = "",
		IsObjectExport = Undefined,
		IsRuleWithGlobalObjectExport = False,
		DontUseRuleWithGlobalExportAndDontRememberExported = False) Export
		//
		
	GetOCRByParameters(OCR, Source, OCRName);
		
	If OCR = Undefined Then
			
		LR = GetLogRecordStructure(45);
			
		LR.Object = Source;
		Try
			LR.ObjectType = TypeOf(Source);
		Except
		EndTry;
			
		WriteToExecutionLog(45, LR, True); // OCR is not found
		Return Undefined;
			
	EndIf;
		
		
	CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule + 1;
		
	If CommentObjectProcessingFlag Then
			
		Try
			SourceToString = String(Source);
		Except
			SourceToString = " ";
		EndTry;
		
		ActionName = ?(GetRefNodeOnly, NStr("en = 'Converting object reference.'"), NStr("en = 'Object conversion'"));
		
			
		MessageText = NStr("en = '[ActionName]: [Object]([ObjectType]), OCR: [OCR](OCRDescription)'");
		MessageText = StrReplace(MessageText, "[ActionName]", ActionName);
		MessageText = StrReplace(MessageText, "[Object]", SourceToString);  
		MessageText = StrReplace(MessageText, "[ObjectType]", TypeOf(Source));
		MessageText = StrReplace(MessageText, "[OCR]", TrimAll(OCRName));
		MessageText = StrReplace(MessageText, "[OCRDescription]", TrimAll(OCR.Description));
			
		WriteToExecutionLog(MessageText, , False, CurrentNestingLevelExportByRule + 1, 7);
			
		
	EndIf;
	
	IsRuleWithGlobalObjectExport = False;
		
	RememberExported       				= False;
	ExportedObjects          			= OCR.Exported;
	AllObjectsExported         			= OCR.AllObjectsExported;
	DontReplaceObjectOnImport 			= OCR.DontReplace;
	DontCreateIfNotFound     			= OCR.DontCreateIfNotFound;
	OnExchangeObjectByRefSetGIUDOnly	= OCR.OnExchangeObjectByRefSetGIUDOnly;
	DontReplaceCreatedInTargetObject	= OCR.DontReplaceCreatedInTargetObject;
	ExchangeObjectPriority 				= OCR.ExchangeObjectPriority;
		
	RecordObjectChangeAtSenderNode 		= False;
		
		
	AutonumerationPrefix = "";
	WriteMode       	 = "";
	PostingMode   		 = "";
	TempFileList 		 = Undefined;
		
	TypeName          		= "";
	ExportObjectProperties  = True;
		
	PropertyStructure = FindPropertyStructureByParameters(OCR, Source);
		
	If PropertyStructure <> Undefined Then
		TypeName = PropertyStructure.TypeName;
	EndIf;
		
	ExportedDataKey = OCRName;
		
	IsNotReferenceType = TypeName = "Constants"
	Or TypeName = "InformationRegister"
	Or TypeName = "AccumulationRegister"
	Or TypeName = "AccountingRegister"
	Or TypeName = "CalculationRegister"
	;
		
	If IsNotReferenceType 
		Or IsBlankString(TypeName) Then
			
		RememberExported = False;
			
	EndIf;
		
	SourceRef = Undefined;
	ExportingObject = IsObjectExport;
		
	If (Source <> Undefined) 
		And Not IsNotReferenceType Then
			
		If ExportingObject = Undefined Then
				
			// If nothing is specified than specify that object is exporting
			ExportingObject = True; 
		EndIf;
			
		SourceRef = GetRefByObjectOrRef(Source, ExportingObject);
		If RememberExported Then
			ExportedDataKey = GetInternalPresentationForSearch(SourceRef, PropertyStructure);
		EndIf;
			
	Else
			
		ExportingObject = False;
			
	EndIf;
		
		
	// Variable for storing the predefined item name
	PredefinedItemName = Undefined;
		
	// BeforeObjectConversion global handler
	Cancel = False; 
	If HasBeforeConvertObjectGlobalHandler Then
			
		Try
			
			If SL20CompatibilityMode() Then
				
				Execute(Conversion.BeforeObjectConversion);
					
			Else
					
				ExecuteHandler_Conversion_BeforeObjectConversion(ExchangeFile, Source, IncomingData, OutgoingData, OCRName, OCR,
				ExportedObjects, Cancel, ExportedDataKey, RememberExported,
				DontReplaceObjectOnImport, AllObjectsExported,GetRefNodeOnly,
				Target, WriteMode, PostingMode, DontCreateIfNotFound);
					
			EndIf;
				
				
				
				
		Except
			WriteErrorInfoOCRHandlerExport(64, ErrorDescription(), OCR, Source, NStr("en = 'BeforeObjectConversion (global)'"));
		EndTry;
	
		If Cancel Then // Canceling further rule processing
			CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule - 1;
			Return Target;
		EndIf;
			
	EndIf;
		
		
	// BeforeExport handler
	If OCR.HasBeforeExportHandler Then
			
		Try
				
			If SL20CompatibilityMode() Then
					
				Execute(OCR.BeforeExport);
					
			Else
					
				ExecuteHandler_OCR_BeforeExportObject(ExchangeFile, Source, IncomingData, OutgoingData, OCRName, OCR,
				ExportedObjects, Cancel, ExportedDataKey, RememberExported,
				DontReplaceObjectOnImport, AllObjectsExported, GetRefNodeOnly,
				Target, WriteMode, PostingMode, DontCreateIfNotFound);
					
			EndIf;
				
		Except
			WriteErrorInfoOCRHandlerExport(41, ErrorDescription(), OCR, Source, "BeforeExportObject");
		EndTry;
			
		If Cancel Then // Canceling further rule processing
			CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule - 1;
			Return Target;
		EndIf;
			
	EndIf;
		
	ExportStackRow = Undefined;
		
	MustUpdateLocalExportedObjectCache = False;
	RefsValueInAnotherInfobase = "";
		
		
	// Perhaps this data has already been exported
	If Not AllObjectsExported Then
			
		NBSp = 0;
			
		If RememberExported Then
				
			ExportedObjectRow = ExportedObjects.Find(ExportedDataKey, "Key");
			
			If ExportedObjectRow <> Undefined Then
					
					
				ExportedObjectRow.CallCount = ExportedObjectRow.CallCount + 1;
				ExportedObjectRow.LastCallNumber = SnCounter;
					
				If GetRefNodeOnly Then
					
					CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule - 1;
					If Find(ExportedObjectRow.RefNode, "<Ref") > 0
						And WrittenToFileSn >= ExportedObjectRow.RefSn Then
						Return ExportedObjectRow.RefSn;
					Else
						Return ExportedObjectRow.RefNode;
					EndIf;
					
				EndIf;
					
				ExportedRefNumber = ExportedObjectRow.RefSn;
					
					
				If Not ExportedObjectRow.OnlyRefExported Then
						
					CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule - 1;
					Return ExportedObjectRow.RefNode;
						
				Else
						
					ExportStackRow = DataExportCallStack.Find(ExportedDataKey, "Ref");
						
					If ExportStackRow <> Undefined Then
						CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule - 1;
						Return Undefined;
					EndIf;
					
						ExportStackRow = DataExportCallStack.Add();
						ExportStackRow.Ref = ExportedDataKey;
						
						NBSp = ExportedRefNumber;
						
					EndIf;
					
				EndIf;
				
			EndIf;
			
			If NBSp = 0 Then
				
				SnCounter = SnCounter + 1;
				NBSp        = SnCounter;
				
				
				
				// Preventing cyclic reference existence
				If RememberExported Then
					
					If ExportedObjectRow = Undefined Then
						
						If Not IsRuleWithGlobalObjectExport
							And Not MustUpdateLocalExportedObjectCache
							And ExportedObjects.Count() > StoredExportedObjectCountByTypes Then
							
							MustUpdateLocalExportedObjectCache = True;
							DataMapForExportedItemUpdate.Insert(OCR.Target, OCR);
							
						EndIf;
						
						
						ExportedObjectRow = ExportedObjects.Add();
						
					EndIf;
					
					ExportedObjectRow.Key 		= ExportedDataKey;
					ExportedObjectRow.RefNode 	= NBSp;
					ExportedObjectRow.RefSn 	= NBSp;
					ExportedObjectRow.LastCallNumber = NBSp;
					
					If GetRefNodeOnly Then
						
						ExportedObjectRow.OnlyRefExported = True; 
						
						
						
					Else
						
						ExportStackRow = DataExportCallStack.Add();
						ExportStackRow.Ref = ExportedDataKey;
						
					EndIf;
					
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
		
		ValueMap = OCR.PredefinedDataValues;
		ValueMapItemCount = ValueMap.Count(); 
		// Predefined item map processing
		If PredefinedItemName = Undefined Then
			
			If PropertyStructure <> Undefined
				And ValueMapItemCount > 0
				And PropertyStructure.SearchByPredefinedPossible Then
				
				Try
					PredefinedNameSource = CommonUse.PredefinedName(SourceRef);
				Except
					PredefinedNameSource = "";
				EndTry;
				
			Else
				
				PredefinedNameSource = "";
				
			EndIf;
			
			
			If Not IsBlankString(PredefinedNameSource)
				And ValueMapItemCount > 0 Then
				
				PredefinedItemName = ValueMap[SourceRef];
				
			Else
				PredefinedItemName = Undefined;    
			EndIf;
			
		EndIf;
		
		If PredefinedItemName <> Undefined Then
			ValueMapItemCount = 0;
		EndIf;   
		
		DontExportByValueMap = (ValueMapItemCount = 0);
		
		
		If Not DontExportByValueMap Then
			
			// If value mapping does not contain values, exporting mapping in the ordinary way
			RefNode = ValueMap[SourceRef];
			If RefNode = Undefined Then
				
				// Perhaps, this is a conversion from enumeration into enumeration and
				//required VCR is not found.  Exporting the empty reference.
				If PropertyStructure.TypeName = "Enum"
					And Find(OCR.Target, "EnumRef.") > 0 Then
					
					
					// Error writing to execution log
					LR = GetLogRecordStructure();
					LR.OCRName      	= OCRName;
					LR.Value            = Source;
					LR.ValueType        = PropertyStructure.RefTypeString;
					LR.PErrorMessages 	= 71;
					LR.Text             = NStr("en = 'In value conversion rule (VCR) source value must be maped target value.
					|Specify an empty value if no target values match.'");
					WriteToExecutionLog(71, LR);
					
					If ExportStackRow <> Undefined Then
						DataExportCallStack.Delete(ExportStackRow);    
					EndIf;
					
					
					CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule - 1;
					
					Return Undefined;
					
				Else
					
					DontExportByValueMap = True;
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
		
		DontExportSubordinateObjects = GetRefNodeOnly Or Not ExportSubordinateObjectRefs;
		
		MustRememberObject = RememberExported And (Not AllObjectsExported);
		
		If DontExportByValueMap Then
			
			If OCR.SearchProperties.Count() > 0 
				Or PredefinedItemName <> Undefined Then   
				
				// Creating reference node
				RefNode = CreateNode("Ref");
				
				If MustRememberObject Then
					
					If IsRuleWithGlobalObjectExport Then
						SetAttribute(RefNode, "GSn", NBSp);
					Else
						SetAttribute(RefNode, "Sn", NBSp);
					EndIf;
					
				EndIf;
				
				If DontCreateIfNotFound Then
					SetAttribute(RefNode, "DontCreateIfNotFound", DontCreateIfNotFound);
				EndIf;
				
				If OCR.SearchBySearchFieldsIfNotFoundByID Then
					SetAttribute(RefNode, "ContinueSearch", True);
				EndIf;
				
				If RecordObjectChangeAtSenderNode Then
					SetAttribute(RefNode, "RecordObjectChangeAtSenderNode", RecordObjectChangeAtSenderNode);
				EndIf;
				
				WriteExchangeObjectPriority(ExchangeObjectPriority, RefNode);
				
				If DontReplaceCreatedInTargetObject Then
					SetAttribute(RefNode, "DontReplaceCreatedInTargetObject", DontReplaceCreatedInTargetObject);    
				EndIf;
				
				ExportRefOnly = OCR.DontExportPropertyObjectsByRefs Or DontExportSubordinateObjects;
				
				If ExportObjectProperties = True Then
					
					ExportProperties(Source, Target, IncomingData, OutgoingData, OCR, OCR.SearchProperties, 
					RefNode, , PredefinedItemName, True, 
					True, ExportingObject, ExportedDataKey, , RefsValueInAnotherInfobase);
					
				EndIf;
				
				RefNode.WriteEndElement();
				RefNode = RefNode.Close();
				
				If MustRememberObject Then
					
					ExportedObjectRow.RefNode = RefNode;               
					
				EndIf;   
				
			Else
				RefNode = NBSp;
			EndIf;
			
		Else
			
			
			// Searching in the value map by VCR
			If RefNode = Undefined Then
				
				// Error writing to execution log
				LR = GetLogRecordStructure();
				LR.OCRName          = OCRName;
				LR.Value            = Source;
				LR.ValueType  		= TypeOf(Source);
				LR.PErrorMessages 	= 71;
				
				
				WriteToExecutionLog(71, LR);
				
				If ExportStackRow <> Undefined Then
					DataExportCallStack.Delete(ExportStackRow);    
				EndIf;
				
				CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule - 1;
				Return Undefined;
			EndIf;
			
			If RememberExported Then
				ExportedObjectRow.RefNode = RefNode;   
			EndIf;
			
			If ExportStackRow <> Undefined Then
				DataExportCallStack.Delete(ExportStackRow);    
			EndIf;
			
			CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule - 1;
			Return RefNode;
			
		EndIf;
		
		
		If GetRefNodeOnly
			Or AllObjectsExported Then
			
			If ExportStackRow <> Undefined Then
				DataExportCallStack.Delete(ExportStackRow);    
			EndIf;
			
			CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule - 1;
			Return RefNode;
			
		EndIf; 
		
		If Target = Undefined Then
			
			Target = CreateNode("Object");
			
			
			If Not ExportRegisterRecordSetRow Then
				
				If IsRuleWithGlobalObjectExport Then
					SetAttribute(Target, "GSn", NBSp);
				Else
					SetAttribute(Target, "Sn", NBSp);
				EndIf;
				
				SetAttribute(Target, "Type",   OCR.Target);
				SetAttribute(Target, "RuleName", OCR.Name);
				
				If Not IsBlankString(ConstantNameForExport) Then
					
					SetAttribute(Target, "ConstantName", ConstantNameForExport);
					
				EndIf;
				
				WriteExchangeObjectPriority(ExchangeObjectPriority, Target);
				
				If DontReplaceObjectOnImport Then
					SetAttribute(Target, "DontReplace", "true");
				EndIf;
				
				If Not IsBlankString(AutonumerationPrefix) Then
					SetAttribute(Target, "AutonumerationPrefix", AutonumerationPrefix);
				EndIf;
				
				If Not IsBlankString(WriteMode) Then
					
					SetAttribute(Target, "WriteMode", WriteMode);
					If Not IsBlankString(PostingMode) Then
						SetAttribute(Target, "PostingMode", PostingMode);
					EndIf;
					
				EndIf;
				
				If TypeOf(RefNode) <> NumberType Then
					AddSubordinateNode(Target, RefNode);
				EndIf;
				
			EndIf;
			
		EndIf;
		
		
		// OnExport handler
		StandardProcessing = True;
		Cancel = False;
		
		If OCR.HasOnExportHandler Then
			
			Try
				
				If SL20CompatibilityMode() Then
					
					Execute(OCR.OnExport);
					
				Else
					
					ExecuteHandler_OCR_OnExportObject(ExchangeFile, Source, IncomingData, OutgoingData, OCRName,
					OCR, ExportedObjects, ExportedDataKey, Cancel,
					StandardProcessing, Target, RefNode);
					
				EndIf;
				
			Except
				WriteErrorInfoOCRHandlerExport(42, ErrorDescription(), OCR, Source, "OnExportObject");
			EndTry;
			
			If Cancel Then // Canceling writing the object to a file
				
				If ExportStackRow <> Undefined Then
					DataExportCallStack.Delete(ExportStackRow);    
				EndIf;
				
				CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule - 1;
				Return RefNode;
			EndIf;
			
		EndIf;
		
		// Exporting properties
		If StandardProcessing Then
			
			If Not IsBlankString(ConstantNameForExport) Then
				
				PropertyForExportArray = New Array();
				
				TableRow = OCR.Properties.Find(ConstantNameForExport, "Source");
				
				If TableRow <> Undefined Then
					PropertyForExportArray.Add(TableRow);
				EndIf;
				
			Else
				
				PropertyForExportArray = OCR.Properties;
				
			EndIf;
			
			
			If ExportObjectProperties Then
				
				ExportProperties(
				Source,                 // Source
				Target,                 // Target
				IncomingData,           // IncomingData
				OutgoingData,          	// OutgoingData
				
				OCR,                    // OCR
				PropertyForExportArray,	// PCRCollection
				,                       // PropertyCollectionNode = Undefined
				,                       // CollectionObject = Undefined
				,                       // PredefinedItemName = Undefined
				True,                   // Val ExportRefOnly = True
				False,                  // Val IsRefExport = False
				ExportingObject,        // Val ExportingObject = False
				ExportedDataKey,    	// RefSearchKey = ""
				
				,                         	// DontUseRulesWithGlobalExportAndDontRememberExported = False
				RefsValueInAnotherInfobase, // RefsValueInAnotherInfobase
				TempFileList,    			// TempFileList = Undefined
				ExportRegisterRecordSetRow); // ExportRegisterRecordSetRow = False
				
			EndIf;
			
		EndIf;    
		
		// AfterExport handler
		
		If OCR.HasAfterExportHandler Then
			
			Try
				
				If SL20CompatibilityMode() Then
					
					Execute(OCR.AfterExport);
					
				Else
					
					ExecuteHandler_OCR_AfterExportObject(ExchangeFile, Source, IncomingData, OutgoingData, OCRName, OCR,
					ExportedObjects, ExportedDataKey, Cancel, Target, RefNode);
					
				EndIf;
				
				
			Except
				WriteErrorInfoOCRHandlerExport(43, ErrorDescription(), OCR, Source, "AfterExportObject");
			EndTry;
			
			If Cancel Then // Canceling writing the object to a file
				
				If ExportStackRow <> Undefined Then
					DataExportCallStack.Delete(ExportStackRow);    
				EndIf;
				
				CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule - 1;
				Return RefNode;
			EndIf;
		EndIf;
		
		
		
		// Writing the object to a file
		IncreaseExportedObjectCounter();
		
		CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule - 1;
		
		If ParentNode <> Undefined Then
			
			Target.WriteEndElement();
			
			ParentNode.WriteRaw(Target.Close());
			
		Else
			
			If TempFileList = Undefined Then
				
				Target.WriteEndElement();
				WriteToFile(Target);
				
				
			Else
				
				WriteToFile(Target);
				
				TempFile = New TextReader;
				For Each TempFileName In TempFileList Do
					
					Try
						TempFile.Open(TempFileName, TextEncoding.UTF8);
					Except
						Continue;
					EndTry;
					
					TempFileLine = TempFile.ReadLine();
					While TempFileLine <> Undefined Do
						WriteToFile(TempFileLine); 
						TempFileLine = TempFile.ReadLine();
					EndDo;
					
					TempFile.Close();
					
					
					// Deleting files
					Try
						DeleteFiles(TempFileName); 
						Except    
					EndTry;
					
				EndDo;
				
				WriteToFile("</Object>");
				
			EndIf;
			
			If MustRememberObject
				And IsRuleWithGlobalObjectExport Then
				
				ExportedObjectRow.RefNode = NBSp;  
				
				
				
			EndIf;
			
			If CurrentNestingLevelExportByRule = 0 Then
				
				SetExportedToFileObjectFlags();
				
			EndIf;
			
			UpdateDataInDataToExport();  
			
		EndIf;
		
		If ExportStackRow <> Undefined Then
			DataExportCallStack.Delete(ExportStackRow);    
		EndIf;
		
	// AfterExportToFile handler
	If OCR.HasAfterExportToFileHandler Then
		
		Try
			
			If SL20CompatibilityMode() Then
			
				Execute(OCR.AfterExportToFile);
				
			Else
				
				
				ExecuteHandler_OCR_AfterExportObjectToExchangeFile(ExchangeFile, Source, IncomingData, OutgoingData,
				OCRName, OCR, ExportedObjects, Target, RefNode);
				
			EndIf;
			
			
		Except
			WriteErrorInfoOCRHandlerExport(79, ErrorDescription(), OCR, Source, "HasAfterExportToFileHandler");
		EndTry;
		
	EndIf;
		
	Return RefNode;
		
EndFunction
	
// Export register by filter.
// 
// Parameters:
// RecordSetForExport - Structure or RecordSet  Filter
//
Procedure UnloadRegister(RecordSetForExport, 
	Rule 			= Undefined, 
	IncomingData 	= Undefined, 
	DontExportObjectsByRefs = False, 
	OCRName 		= "",
	DataExportRule 	= Undefined) Export
	
	OutgoingData 	= Undefined; 
	
	
	
	
	GetOCRByParameters(Rule, RecordSetForExport, OCRName);
	
	Cancel   = False;
	Properties = Undefined;
	ExchangeObjectPriority = Rule.ExchangeObjectPriority;
	
	If TypeOf(RecordSetForExport) = Type("Structure") Then
		
		RecordSetFilter  = RecordSetForExport.Filter;
		RecordSetRows = RecordSetForExport.Rows;
		
	Else // RecordSet
		
		RecordSetFilter  = RecordSetForExport.Filter;
		RecordSetRows = RecordSetForExport;
		
	EndIf;
	
	
	// Writing filter first then record set
	// Filter
	
	
	Target = CreateNode("RegisterRecordSet");
	
	RegisterRecordCount = RecordSetRows.Count();
	
	SnCounter = SnCounter + 1;
	Sn        = SnCounter;
	
	SetAttribute(Target, "Sn",   Sn);
	
	SetAttribute(Target, "Type",   StrReplace(Rule.Target, "InformationRegisterRecord.", "InformationRegisterRecordSet."));
	SetAttribute(Target, "RuleName", Rule.Name);
	
	WriteExchangeObjectPriority(ExchangeObjectPriority, Target);
	
	ExportingEmptySet = RegisterRecordCount = 0;
	If ExportingEmptySet Then
		SetAttribute(Target, "EmptySet", True);
	EndIf;
	
	
	Target.WriteStartElement("Filter");
	
	SourceStructure = New Structure;
	PCRForExportArray = New Array();
	
	For Each FilterRow In RecordSetFilter Do
		
		If FilterRow.Use = False Then
			Continue;
		EndIf;
		
		PCRRow = Rule.Properties.Find(FilterRow.Name, "Source");
		
		
		If PCRRow = Undefined Then
			
			PCRRow = Rule.Properties.Find(FilterRow.Name, "Target");
			
		EndIf;
		
		If PCRRow <> Undefined
			And  (PCRRow.TargetKind = "Property"
			Or PCRRow.TargetKind = "Dimension") Then
			
			PCRForExportArray.Add(PCRRow);
			
			Key = ?(IsBlankString(PCRRow.Source), PCRRow.Target, PCRRow.Source);
			
			
			SourceStructure.Insert(Key, FilterRow.Value);
			
		EndIf;
		
	EndDo;
	
	// Adding filter parameters
	For Each SearchPropertyRow In Rule.SearchProperties Do
		
		If IsBlankString(SearchPropertyRow.Target)
			And Not IsBlankString(SearchPropertyRow.ParameterForTransferName) Then
			
			PCRForExportArray.Add(SearchPropertyRow); 
			
		EndIf;
		
		
	EndDo;
	
	ExportProperties(SourceStructure, , IncomingData, OutgoingData, Rule, PCRForExportArray, Target, 
	, , True, , , , ExportingEmptySet);
	
	Target.WriteEndElement();
	
	Target.WriteStartElement("RecordSetRows");
	
	
	// Record set IncomingData = Undefined;
	For Each RegisterLine In RecordSetRows Do
		
		SelectionItemExport(RegisterLine, DataExportRule, , IncomingData, DontExportObjectsByRefs, True, 
		Target, , OCRName, FALSE);
		
	EndDo;
	
	Target.WriteEndElement();
	
	Target.WriteEndElement();
	
	WriteToFile(Target);
	
	UpdateDataInDataToExport();
	
	SetExportedToFileObjectFlags();
	
	
	Increment(ExportedObjectCounterField, 1 - RecordSetRows.Count());
	
EndProcedure

// Sets deletion mark.
//
// Parameters:
// Object - object to set deletion mark.
// DeletionMark - Boolean - deletion mark flag.
// ObjectTypeName - String - object type as string.
//
Procedure SetObjectDeletionMark(Object, DeletionMark, ObjectTypeName) Export
	
	If (DeletionMark = Undefined And Object.DeletionMark <> True)
		Or DataExchangeEvents.ImportProhibited(Object, ExchangeNodeDataImport) Then
		Return;
	EndIf;
	
	MarkToSet = ?(DeletionMark <> Undefined, DeletionMark, False);
	
	SetDataExchangeLoad(Object);
	
	
	// For hierarchical object the deletion mark is set only for the current object
	If ObjectTypeName = "Catalog"
		Or ObjectTypeName = "ChartOfCharacteristicTypes"
		Or ObjectTypeName = "ChartOfAccounts" Then
		
		If Not IsPredefinedItem(Object) Then
			
			Object.SetDeletionMark(MarkToSet, False);
			
		EndIf;
		
	Else
		
		Object.SetDeletionMark(MarkToSet);
		
	EndIf; 
	
EndProcedure

// Sets the Load parameter value for the DataExchange object property.
//
// Parameters:
//  Object - object whose property will be set.
//  Value  - value of the Load property to be set.
//
//
Procedure SetDataExchangeLoad(Object, Value = True, Val SendBack = False) Export
	
	// Objects those take part in the exchange might not have the DataExchange property
	Try
		Object.
		DataExchange.Load = Value;
	Except
	EndTry;
	
	If Not SendBack
		And ExchangeNodeDataImport <> Undefined
		And Not ExchangeNodeDataImport.IsEmpty() Then
		
		Try
			Object.DataExchange.Sender = ExchangeNodeDataImport;
		Except
		EndTry;
		
	EndIf;
	
EndProcedure

// Adds information about value types to xml file.
//
// Parameters:
// Target - target object XML node.
// Type - String - export type.
// Array - contains export string type list.
// AttributeList - Structure - key contains the attribute name.
//
Procedure ExportInformationAboutTypes(Target, Type, AttributeList = Undefined) Export
	
	TypeNode = CreateNode("Types");
	
	If AttributeList <> Undefined Then
		For Each CollectionItem In AttributeList Do
			SetAttribute(TypeNode, CollectionItem.Key, CollectionItem.Value);
		EndDo;
	EndIf;
	
	If TypeOf(Type) = Type("String") Then
		deWriteElement(TypeNode, "Type", Type);
	Else
		For Each TypeString In Type Do
			deWriteElement(TypeNode, "Type", TypeString);
		EndDo;
	EndIf;
	
	AddSubordinateNode(Target, TypeNode);
	
EndProcedure

Procedure GetPredefinedDataValues(Val OCR)
	
	OCR.PredefinedDataValues = New Map;
	
	For Each Item In OCR.PredefinedDataReadValues Do
		
		OCR.PredefinedDataValues.Insert(deGetValueByString(Item.Key, OCR.Source), Item.Value);
		
	EndDo;
	
EndProcedure
////////////////////////////////////////////////////////////////////////////////
// AUXILIARY PROCEDURE FOR WRITING ALGORITHMS

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS FOR WORKING WITH STRINGS

// Splits string in two parts: before the separator substring and after it.
//
// Parameters:
//  Str       - string to be split.
//  Separator - separator substring:
//  Mode      - 0  separator is not included in the return substrings.
//            - 1  separator is included in the first substring.
//            - 2  separator is included in the second substring.
//
// Returns:
//  Result - substrings.
// 
Function SplitWithSeparator(Str, Val Separator, Mode=0)
	
	RightPart       = "";
	SplitterPos     = Find(Str, Separator);
	SeparatorLength = StrLen(Separator);
	If SplitterPos > 0 Then
		RightPart = Mid(Str, SplitterPos + ?(Mode=2, 0, SeparatorLength));
		Str       = TrimAll(Left(Str, SplitterPos - ?(Mode=1, SeparatorLength + 1, 1)));
	EndIf;
	
	Return(RightPart);
	
EndFunction

// Casts values from String to Array using the specified separator.
//
// Parameters:
//  Str       - string to be split.
//  Separator - separator substring.
//
// Returns:
//  Array of values.
// 
Function ArrayFromString(Val Str, Separator=",")
	
	Array     = New Array;
	RightPart = SplitWithSeparator(Str, Separator);
	
	While Not IsBlankString(Str) Do
		Array.Add(TrimAll(Str));
		Str       = RightPart;
		RightPart = SplitWithSeparator(Str, Separator);
	EndDo; 
	
	Return(Array);
	
EndFunction 

Function GetStringNumberWithoutPrefixes(Number)
	
	NumberWithoutPrefixes = "";
	Cnt = StrLen(Number);
	
	While Cnt > 0 Do
		
		Char = Mid(Number, Cnt, 1);
		
		If (Char >= "0" And Char <= "9") Then
			
			NumberWithoutPrefixes = Char + NumberWithoutPrefixes;
			
		Else
			
			Return NumberWithoutPrefixes;
			
		EndIf;
		
		Cnt = Cnt - 1;
		
	EndDo;
	
	Return NumberWithoutPrefixes;
	
EndFunction

// Splits a string into a prefix and numerical part.
//
// Parameters:
// Str           - String - string to be split.
// NumericalPart - Number - variable where the numerical part will be returned.
// Mode          - String - pass "Number" if you want a numeric part to be returned,
//                 otherwise pass "Prefix".
//
// Returns:
//  String prefix.
//
Function GetNumberPrefixAndNumericalPart(Val Str, NumericalPart = "", Mode = "")
	
	NumericalPart = 0;
	Prefix = "";
	Str = TrimAll(Str);
	Length   = StrLen(Str);
	
	StringNumberWithoutPrefix = GetStringNumberWithoutPrefixes(Str);
	StringPartLength = StrLen(StringNumberWithoutPrefix);
	If StringPartLength > 0 Then
		NumericalPart = Number(StringNumberWithoutPrefix);
		Prefix = Mid(Str, 1, Length - StringPartLength);
	Else
		Prefix = Str; 
	EndIf;
	
	If Mode = "Number" Then
		Return(NumericalPart);
	Else
		Return(Prefix);
	EndIf;
	
EndFunction

// Casts the number (code) to the required length, splitting the number into a prefix and numeric part.
// The space between the prefix and number is filled with zeros.
// Can be used in the event handlers whose script is stored in data exchange rules.
// Is called with the Execute method.
// The "No links to function found" message during the configuration check is not an error.
//
// Parameters:
//  Str    - string to be casted.
//  Length - required string length.
//
// Returns:
//  String - result code or number.
// 
Function CastNumberToLength(Val Str, Length, AddZerosIfLengthNotLessCurrentNumberLength = True, Prefix = "")
	
	Str                  = TrimAll(Str);
	IncomingNumberLength = StrLen(Str);
	
	NumericalPart = "";
	Result        = GetNumberPrefixAndNumericalPart(Str, NumericalPart);
	
	Result = ?(IsBlankString(Prefix), Result, Prefix);
	
	NumericPartString = Format(NumericalPart, "NG=0");
	NumericPartLength = StrLen(NumericPartString);
	
	If (Length >= IncomingNumberLength And AddZerosIfLengthNotLessCurrentNumberLength)
		Or (Length < IncomingNumberLength) Then
		
		For TemporaryVariable = 1 To Length - StrLen(Result) - NumericPartLength Do
			
			Result = Result + "0";
			
		EndDo;
		
	EndIf;
	
	Result = Result + NumericPartString;
	
	Return(Result);
	
EndFunction


// Supplements string with the specified symbol to the specified length.
//
// Parameters: 
//  Str    - string to be supplemented.
//  Length - required string length.
//  Than   - substring to be added.
//
// Returns:
//  String that is supplemented with the specified symbol to the specified length.
//
Function odSupplementString(Str, Length, With = " ")
	
	Result = TrimAll(Str);
	While Length - StrLen(Result) > 0 Do
		Result = Result + With;
	EndDo;
	
	Return(Result);
	
EndFunction // odSupplementString() 

////////////////////////////////////////////////////////////////////////////////
// DATA PROCESSING

// Returns a string that contains the name of the passed enumeration value.
// Can be used in the event handlers whose script is stored in data exchange rules.
// Is called with the Execute method.
// The "No links to function found" message during the configuration check is not an error.
//
// Parameters:
//  Value - enumeration value.
//
// Returns:
//  String - name of the passed enumeration value.


Function deEnumValueName(Value) Export
	
	MDObject   = Value.Metadata();
	ValueIndex = Enums[MDObject.Name].IndexOf(Value);
	
	Return MDObject.EnumValues[ValueIndex].Name;
	
EndFunction

// Determines whether the passed value is empty.
//
// Parameters: 
// Value - value to be checked.
//
// Returns:
// True, if the value is empty, False otherwise.
//
Function deEmpty(Value, IsNULL = False)
	
	// Primitive types first
	If Value = Undefined Then
		Return True;
	ElsIf Value = NULL Then
		IsNULL   = True;
		Return True;
	EndIf;
	
	ValueType = TypeOf(Value);
	
	If ValueType = ValueStorageType Then
		
		Result = deEmpty(Value.Get());
		Return Result;  
		
	ElsIf ValueType = BinaryDataType Then
		
		Return False;
		
	Else
		
		// The value is considered empty if it is equal to the default value of its type
		Try
			Result = Not ValueIsFilled(Value);
			Return Result;
		Except
			Return False;
		EndTry;
		
	EndIf;
	
EndFunction

// Returns the TypeDescription object that contains the specified type.
// 
// Parameters:
//  TypeValue - String with a type name or Type.
// 
// Returns:
//  TypeDescription.
//
Function deTypeDescription(TypeValue)
	
	TypeDescription = TypeDescriptionMap[TypeValue];
	
	If TypeDescription = Undefined Then
		
		TypeArray = New Array;
		If TypeOf(TypeValue) = StringType Then
			TypeArray.Add(Type(TypeValue));
		Else
			TypeArray.Add(TypeValue);
		EndIf; 
		TypeDescription = New TypeDescription(TypeArray);
		
		TypeDescriptionMap.Insert(TypeValue, TypeDescription);
		
	EndIf; 
	
	Return TypeDescription;
	
EndFunction

// Returns an empty (default) value of the specified type.
//
// Parameters:
//  Type - String with a type name or Type.
//
// Returns:
//  Empty value of the specified type.
// 
Function deGetEmptyValue(Type)
	
	EmptyTypeValue = EmptyTypeValueMap[Type];
	
	If EmptyTypeValue = Undefined Then
		
		EmptyTypeValue = deTypeDescription(Type).AdjustValue(Undefined); 
		
		EmptyTypeValueMap.Insert(Type, EmptyTypeValue);
		
	EndIf;
	
	Return EmptyTypeValue;
	
EndFunction

Function CheckRefExists(Ref, Manager, FoundByUUIDObject, 
	MainObjectSearchMode, SearchByUUIDQueryString)
	
	Try
		
		If MainObjectSearchMode
			Or IsBlankString(SearchByUUIDQueryString) Then
			
			FoundByUUIDObject = Ref.GetObject();
			
			If FoundByUUIDObject = Undefined Then
				
				Return Manager.EmptyRef();
				
			EndIf;
			
		Else
			
			// "Search by reference" mode. It is enough to execute a query by the following pattern:
			// PropertyStructure.SearchString
			
			Query = New Query();
			Query.Text = SearchByUUIDQueryString + "  Ref = &Ref ";
			Query.SetParameter("Ref", Ref);
			
			QueryResult = Query.Execute();
			
			If QueryResult.IsEmpty() Then
				
				Return Manager.EmptyRef();
				
			EndIf;
			
		EndIf;
		
		Return Ref; 
		
	Except
		
		Return Manager.EmptyRef();
		
	EndTry;
	
EndFunction

// Performs a simple search for infobase object by the specified property.
//
// Parameters:
//  Manager  - manager of the object to be searched;
//  Property - property to implement the search: Name, Code, Description, or a name of
//             an indexed attribute.
//  Value    - value of a property to be used for searching the object.
//
// Returns:
// Found infobase object.
//
Function deFindObjectByProperty(Manager, Property, Value, 
	FoundByUUIDObject = Undefined, 
	CommonPropertyStructure = Undefined, CommonSearchProperties = Undefined,
	MainObjectSearchMode = True, SearchByUUIDQueryString = "")
	
	If Property = "Name" Then
		
		Return Manager[Value];
		
	ElsIf Property = "{UUID}" Then
		
		RefByUUID = Manager.GetRef(New UUID(Value));
		
		Ref =  CheckRefExists(RefByUUID, Manager, FoundByUUIDObject, 
		MainObjectSearchMode, SearchByUUIDQueryString);
		
		Return Ref;
		
	ElsIf Property = "{PredefinedItemName}" Then
		
		
		Ref = PredefinedManagerItem(Manager, Value);
		If Ref = Undefined Then
			Ref = Manager.FindByCode(Value);
			If Ref = Undefined Then
				Ref = Manager.EmptyRef();
			EndIf;
		EndIf;
		
		Return Ref;
		
	Else
		
		ObjectRef = FindItemUsingRequest(CommonPropertyStructure, CommonSearchProperties, , Manager);
		
		Return ObjectRef;
		
	EndIf;
	
EndFunction

// Returns predefined item value by the name.
// 
Function PredefinedManagerItem(Val Manager, Val PredefinedName)
	
	Query = New Query( StrReplace("
	|SELECT 
	| PredefinedDataName AS PredefinedDataName,
	| Ref                    AS Ref
	|FROM
	| {TableName}
	|WHERE
	| Predefined
	|",
	
	"{TableName}", Metadata.FindByType(TypeOf(Manager)).FullName()
	));
	
	Selection = Query.Execute().Select();
	If Selection.FindNext( New Structure("PredefinedDataName", PredefinedName) ) Then
		Return Selection.Ref;
	EndIf;
	
	Return Undefined;
EndFunction

// Performs a simple search for infobase object by the specified property.
//
// Parameters:
//  Str      - String  property value (search string).
//  Type     - object type.
//  Property - String  property name.
//
// Returns:
//  Found infobase object.
//
Function deGetValueByString(Str, Type, Property = "")
	
	If IsBlankString(Str) Then
		Return New(Type);
	EndIf; 
	
	Properties = Managers[Type];
	
	If Properties = Undefined Then
		
		TypeDescription = deTypeDescription(Type);
		Return TypeDescription.AdjustValue(Str);
		
	EndIf;
	
	If IsBlankString(Property) Then
		
		If Properties.TypeName = "Enum" Then
			Property = "Name";
		Else
			Property = "{PredefinedItemName}";
		EndIf;
		
	EndIf; 
	
	Return deFindObjectByProperty(Properties.Manager, Property, Str);
	
EndFunction

// Returns a string that contains a value type presentation.
//
// Parameters: 
//  ValueOrType - arbitrary value or Type.
//
// Returns:
//  String - string that contains the value type presentation.
//
Function deValueTypeString(ValueOrType)
	
	ValueType = TypeOf(ValueOrType);
	
	If ValueType = TypeType Then
		ValueType = ValueOrType;
	EndIf; 
	
	If (ValueType = Undefined) Or (ValueOrType = Undefined) Then
		Result = "";
	ElsIf ValueType = StringType Then
		Result = "String";
	ElsIf ValueType = NumberType Then
		Result = "Number";
	ElsIf ValueType = DateType Then
		Result = "Date";
	ElsIf ValueType = BooleanType Then
		Result = "Boolean";
	ElsIf ValueType = ValueStorageType Then
		Result = "ValueStorage";
	ElsIf ValueType = UUIDType Then
		Result = "UUID";
	ElsIf ValueType = AccumulationRecordTypeType Then
		Result = "AccumulationRecordType";
	Else
		Manager = Managers[ValueType];
		If Manager = Undefined Then
		Else
			Result = Manager.RefTypeString;
		EndIf; 
	EndIf; 
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS FOR WORKING WITH THE XMLWriter OBJECT

// Creates a new XML node.
//  Can be used in the event handlers whose script is stored in the data exchange rules.
//  Is called with the Execute method.
//
// Parameters: 
//  Name - node name.
//
// Returns:
//  Object of the new XML node.
//
Function CreateNode(Name)
	
	XMLWriter = New XMLWriter;
	XMLWriter.SetString();
	XMLWriter.WriteStartElement(Name);
	
	Return XMLWriter;
	
EndFunction

// Writes the element and its value to the specified object.
//
// Parameters:
//  Object - XMLWriter.
//  Name   - String - element name.
//  Value  - element value.
// 
Procedure deWriteElement(Object, Name, Value="") Export
	
	Object.WriteStartElement(Name);
	Str = XMLString(Value);
	
	Object.WriteText(Str);
	Object.WriteEndElement();
	
EndProcedure

// Subordinates the XML node to the specified parent node.
//
// Parameters: 
//  ParentNode - parent XML node.
//  Node       - node to be subordinated. 
//
Procedure AddSubordinateNode(ParentNode, Node)
	
	If TypeOf(Node) <> StringType Then
		Node.WriteEndElement();
		InformationToWriteToFile = Node.Close();
	Else
		InformationToWriteToFile = Node;
	EndIf;
	
	ParentNode.WriteRaw(InformationToWriteToFile);
	
EndProcedure

// Sets the attribute of the specified XML node.
//
// Parameters: 
//  Node  - XML node.
//  Name  - attribute name.
//  Value - value to be set.
//
Procedure SetAttribute(Node, Name, Value)
	
	XMLString = XMLString(Value);
	
	Node.WriteAttribute(Name, XMLString);
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS FOR WORKING WITH THE XMLReader OBJECT

// Reads the attribute value by name from the specified object, casts the value to
// the specified primitive type.
//
// Parameters:
//  Object - XMLReader  XMLReader object positioned at the beginning of the element 
//           whose attribute will be retrieved.
//  Type   - Type  attribute type.
//  Name   - String  attribute name.
//
// Returns:
//  The attribute value received by name and casted to the specified type.

Function deAttribute(Object, Type, Name)
	
	ValueStr = TrimR(Object.GetAttribute(Name));
	If Not IsBlankString(ValueStr) Then
		Return XMLValue(Type, ValueStr);  
	ElsIf      Type = StringType Then
		Return ""; 
	ElsIf Type = BooleanType Then
		Return False;
	ElsIf Type = NumberType Then
		Return 0;
	ElsIf Type = DateType Then
		Return EmptyDateValue;
	EndIf; 
	
EndFunction 

// Skips XML nodes till the end of the specified element (default value is the current one).
//
// Parameters:
//  Object - XMLReader.
//  Name   - name of the node whose elements will be skipped.
//
Procedure deSkip(Object, Name="")
	
	AttachmentCount = 0; // Number of attachments with the same name
	
	If Name = "" Then
		
		Name = Object.LocalName;
		
	EndIf; 
	
	While Object.Read() Do
		
		If Object.LocalName <> Name Then
			Continue;
		EndIf;
		
		NodeType = Object.NodeType;
		
		If NodeType = XMLNodeTypeEndElement Then
			
			If AttachmentCount = 0 Then
				
				Break;
				
			Else
				
				AttachmentCount = AttachmentCount - 1;
				
			EndIf;
			
		ElsIf NodeType = XMLNodeTypeStartElement Then
			
			AttachmentCount = AttachmentCount + 1;
			
		EndIf;
		
	EndDo;
	
EndProcedure 

// Reads the element text and casts the value to the specified primitive type.
//
// Parameters:
//  Object           - XMLReader  object whose data will be read. 
//  Type              type of the return value.
//  SearchByProperty - for reference types, a property for searching can be specified.
//                     It can be: Code, Description, <AttributeName>, Name (of a 
//                     predefined value).
//
// Returns:
//  XML element value casted to the specified type.
//
Function deElementValue(Object, Type, SearchByProperty = "", CutStringRight = True)
	
	Value = "";
	Name  = Object.LocalName;
	
	While Object.Read() Do
		
		NodeType = Object.NodeType;
		
		If NodeType = XMLNodeTypeText Then
			
			Value = Object.Value;
			
			If CutStringRight Then
				
				Value = TrimR(Value);
				
			EndIf;
			
		ElsIf (Object.LocalName = Name) And (NodeType = XMLNodeTypeEndElement) Then
			
			Break;
			
		Else
			
			Return Undefined;
			
		EndIf;
		
	EndDo;
	
	
	If (Type = StringType)
		Or (Type = BooleanType)
		Or (Type = NumberType)
		Or (Type = DateType)
		Or (Type = ValueStorageType)
		Or (Type = UUIDType)
		Or (Type = AccumulationRecordTypeType)
		Or (Type = AccountTypeType)
		Then
		
		Return XMLValue(Type, Value);
		
	Else
		
		Return deGetValueByString(Value, Type, SearchByProperty);
		
	EndIf; 
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS FOR WORKING WITH THE EXCHANGE FILE

// Saves the specified XML node to a file.
//
// Parameters:
// Node - XML node to be saved.
//
Procedure WriteToFile(Node)
	
	If TypeOf(Node) <> StringType Then
		InformationToWriteToFile = Node.Close();
	Else
		InformationToWriteToFile = Node;
	EndIf;
	
	If IsExchangeOverExternalConnection() Then
		
		// ============================ {Start: Data exchange through external connection}
		DataProcessorForDataImport().ExternalConnectionImportDataFromXMLString(InformationToWriteToFile);
		
		If DataProcessorForDataImport().ErrorFlag() Then
			
			MessageString = NStr("en = 'EXTERNAL CONNECTION: %1'");
			MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, DataProcessorForDataImport().ErrorMessageString());
			ExchangeExecutionResultExternalConnection = Enums.ExchangeExecutionResults[DataProcessorForDataImport().ExchangeExecutionResultString()];
			WriteToExecutionLog(MessageString,,,,,, ExchangeExecutionResultExternalConnection);
			Raise MessageString;
			
		EndIf;
		// ============================ {End: Data exchange through external connection}
		
	Else
		
		ExchangeFile.WriteLine(InformationToWriteToFile);
		
	EndIf;
	
EndProcedure

// Opens the exchange file, writes the file header according to the exchange format.
// 
Function OpenExportFile()
	
	ExchangeFile = New TextWriter;
	Try
		ExchangeFile.Open(ExchangeFileName, TextEncoding.UTF8);
	Except
		
		
		ErrorPresentation = StringFunctionsClientServer.SubstituteParametersInString(NStr("en = 'Error opening file for exchange message record.
		|Name file ""%1"".
		|Error
		|details: %2'"),
		String(ExchangeFileName),
		DetailErrorDescription(ErrorInfo())
		);
		WriteToExecutionLog(ErrorPresentation);
		Return "";
	EndTry;
	
XMLInfoString = "<?xml version=""1.0"" encoding=""UTF8""?>";

ExchangeFile.WriteLine(XMLInfoString);

TempXMLWriter = New XMLWriter();

TempXMLWriter.SetString();

TempXMLWriter.WriteStartElement("ExchangeFile");

SetAttribute(TempXMLWriter, "FormatVersion",         	 ExchangeMessageFormatVersion());
SetAttribute(TempXMLWriter, "ExportDate",            	 CurrentSessionDate());
SetAttribute(TempXMLWriter, "SourceConfigurationName", 	 Conversion.Source);
SetAttribute(TempXMLWriter, "SourceConfigurationVersion",Conversion.SourceConfigurationVersion);
SetAttribute(TempXMLWriter, "TargetConfigurationName", 	 Conversion.Target);
SetAttribute(TempXMLWriter, "ConversionRuleIDs",       	 Conversion.ID);

TempXMLWriter.WriteEndElement();

Str = TempXMLWriter.Close();

Str = StrReplace(Str, "/>", ">");

ExchangeFile.WriteLine(Str);

Return XMLInfoString + Chars.LF + Str;

EndFunction

// Closes the exchange file.
//
Procedure CloseFile()

ExchangeFile.WriteLine("</ExchangeFile>");
ExchangeFile.Close();

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS FOR WORKING WITH THE EXCHANGE PROTOCOL

// Returns a structure that contains all possible log record fields (error messages and so on).
//
// Returns:
//  Structure.
// 
Function GetLogRecordStructure(PErrorMessages = "", Val ErrorString = "")

ErrorStructure = New Structure("OCRName,DERName,Sn,GSn,Source,ObjectType,Property,Value,ValueType,OCR,PCR,PGCR,DER,DPR,Object,TargetProperty,ConvertedValue,Handler,ErrorDescription,ModulePosition,Text,PErrorMessages,ExchangePlanNode");

ModuleString     = SplitWithSeparator(ErrorString, "{");
ErrorDescription = SplitWithSeparator(ModuleString, "}: ");

If ErrorDescription <> "" Then
	
	ErrorStructure.ErrorDescription = ErrorDescription;
	ErrorStructure.ModulePosition   = ModuleString;
	
EndIf;

If ErrorStructure.PErrorMessages <> "" Then
	
	ErrorStructure.PErrorMessages = PErrorMessages;
	
EndIf;

Return ErrorStructure;

EndFunction 

Procedure EnableExchangeLog()

If IsBlankString(ExchangeLogFileName) Then
	
	DataLogFile = Undefined;
	CommentObjectProcessingFlag = OutputInfoMessagesToMessageWindow;  
	Return;
	
	Else 
	
	CommentObjectProcessingFlag = WriteInfoMessagesToLog Or OutputInfoMessagesToMessageWindow;  
	
EndIf;

// Attempting to write a message to the exchange protocol file
Try
	DataLogFile = New TextWriter(ExchangeLogFileName, TextEncoding.ANSI, , AppendDataToExchangeLog);
Except
	DataLogFile = Undefined;
	MessageString = NStr("en = 'Error attempting to write data to the log file: %1. Error details: %2'", 
	CommonUseClientServer.DefaultLanguageCode()); 
	MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, ExchangeLogFileName, ErrorDescription());
	WriteLogEventDataExchange(MessageString, EventLogLevel.Warning);
EndTry;

EndProcedure

Procedure DisableExchangeProtocol()

If DataLogFile <> Undefined Then
	
	DataLogFile.Close();
	
EndIf; 

DataLogFile = Undefined;

EndProcedure

Procedure SetExchangeResult(ExchangeExecutionResult)

CurrentResultIndex = ExchangeResultPriorities().Find(ExchangeExecutionResult());
NewResultIndex     = ExchangeResultPriorities().Find(ExchangeExecutionResult);

If CurrentResultIndex = Undefined Then
	CurrentResultIndex = 100
EndIf;

If NewResultIndex = Undefined Then
	NewResultIndex = 100
EndIf;

If NewResultIndex < CurrentResultIndex Then
	
	ExchangeResultField = ExchangeExecutionResult;
	
EndIf;

EndProcedure

Function ExchangeExecutionResultError(ExchangeExecutionResult)

Return ExchangeExecutionResult = Enums.ExchangeExecutionResults.Error
Or ExchangeExecutionResult = Enums.ExchangeExecutionResults.Error_MessageTransport;

EndFunction

Function ExchangeResultWarning(ExchangeExecutionResult)

Return ExchangeExecutionResult = Enums.ExchangeExecutionResults.CompletedWithWarnings
Or ExchangeExecutionResult = Enums.ExchangeExecutionResults.Warning_ExchangeMessageReceivedPreviously;

EndFunction

// Writes messages of the specified structure to the execution log (or displays these 
// messages to the screen).
//
// Parameters:
//  Code            - Number - message code.
//  RecordStructure - Structure - protocol writing structure.
//  SetErrorFlag    - pass True if an error message will be written to set ErrorFlag.
// 
Function WriteToExecutionLog(Code = "",
RecordStructure=Undefined,
SetErrorFlag=True,
Level=0,
Align=22,
ForceWritingToExchangeLog = False,
Val ExchangeExecutionResult = Undefined) Export

Indent = "";
For Cnt = 0 to Level - 1 Do
	Indent = Indent + Chars.Tab;
EndDo; 

If TypeOf(Code) = NumberType Then
	
	If ErrorMessages = Undefined Then
		InitMessages();
	EndIf;
	
	Str = ErrorMessages[Code];
	
Else
	
	Str = String(Code);
	
EndIf;

Str = Indent + Str;

If RecordStructure <> Undefined Then
	
	For Each Field In RecordStructure Do
		
		Value = Field.Value;
		If Value = Undefined Then
			Continue;
		EndIf; 
		FieldKey = Field.Key;
		Str  = Str + Chars.LF + Indent + Chars.Tab + odSupplementString(Field.Key, Align) + " =  " + String(Value);
		
	EndDo;
	
EndIf;

TranslationLiteral = ?(IsBlankString(ErrorMessageString()), "", Chars.LF);

ErrorMessageStringField = Str;

If SetErrorFlag Then
	
	SetErrorFlag();
	
	ExchangeExecutionResult = ?(ExchangeExecutionResult = Undefined,
	Enums.ExchangeExecutionResults.Error,
	ExchangeExecutionResult);
	
EndIf;

SetExchangeResult(ExchangeExecutionResult);

If DataLogFile <> Undefined Then
	
	If SetErrorFlag Then
		
		DataLogFile.WriteLine(Chars.LF + "Error.");
		
	EndIf;
	
	If SetErrorFlag Or ForceWritingToExchangeLog Or WriteInfoMessagesToLog Then
		
		DataLogFile.WriteLine(Chars.LF + ErrorMessageString());
		
	EndIf;
	
EndIf;

If ExchangeExecutionResultError(ExchangeExecutionResult) Then
	
	ELLevel = EventLogLevel.Error;
	
ElsIf ExchangeResultWarning(ExchangeExecutionResult) Then
	
	ELLevel = EventLogLevel.Warning;
	
Else
	
	ELLevel = EventLogLevel.Information;
	
EndIf;

// Writing the event message to the event log
WriteLogEventDataExchange(ErrorMessageString(), ELLevel);

Return ErrorMessageString();

EndFunction

Function WriteErrorInfoToLog(PErrorMessages, ErrorString, Object, ObjectType = Undefined)

LR         = GetLogRecordStructure(PErrorMessages, ErrorString);
LR.Object  = Object;

If ObjectType <> Undefined Then
	LR.ObjectType = ObjectType;
EndIf; 

ErrorString = WriteToExecutionLog(PErrorMessages, LR); 

Return ErrorString;

EndFunction

Procedure WriteDataClearingHandlerErrorInfo(PErrorMessages, ErrorString, DataClearingRuleName, Object = "", HandlerName = "")

LR     = GetLogRecordStructure(PErrorMessages, ErrorString);
LR.DPR = DataClearingRuleName;

If Object <> "" Then
	LR.Object = String(Object) + "  (" + TypeOf(Object) + ")";
EndIf;

If HandlerName <> "" Then
	LR.Handler = HandlerName;
EndIf;

ErrorMessageString = WriteToExecutionLog(PErrorMessages, LR);

If Not ContinueOnError Then
	Raise ErrorMessageString;
EndIf;

EndProcedure

Procedure WriteErrorInfoOCRHandlerImport(PErrorMessages, ErrorString, RuleName, Source = "", 
ObjectType, Object = Undefined, HandlerName)

LR            = GetLogRecordStructure(PErrorMessages, ErrorString);
LR.OCRName    = RuleName;
LR.ObjectType = ObjectType;
LR.Handler    = HandlerName;

If Not IsBlankString(Source) Then
	
	LR.Source = Source;
	
EndIf;

If Object <> Undefined Then
	
	LR.Object = String(Object);
	
EndIf;

ErrorMessageString = WriteToExecutionLog(PErrorMessages, LR);

If Not ContinueOnError Then
	Raise ErrorMessageString;
EndIf;

EndProcedure

Procedure WriteErrorInfoOCRHandlerExport(PErrorMessages, ErrorString, OCR, Source, HandlerName)

LR     = GetLogRecordStructure(PErrorMessages, ErrorString);
LR.OCR = OCR.Name + "  (" + OCR.Description + ")";

Try
	LR.Object = String(Source) + "  (" + TypeOf(Source) + ")";
Except
	LR.Object = "(" + TypeOf(Source) + ")";
EndTry;

LR.Handler = HandlerName;

ErrorMessageString = WriteToExecutionLog(PErrorMessages, LR);

If Not ContinueOnError Then
	Raise ErrorMessageString;
EndIf;

EndProcedure

Procedure WriteErrorInfoPCRHandlers(PErrorMessages, ErrorString, OCR, PCR, Source = "", 
HandlerName = "", Value = Undefined)

LR     = GetLogRecordStructure(PErrorMessages, ErrorString);
LR.OCR = OCR.Name + "  (" + OCR.Description + ")";
LR.PCR = PCR.Name + "  (" + PCR.Description + ")";

Try
	LR.Object = String(Source) + "  (" + TypeOf(Source) + ")";
Except
	LR.Object = "(" + TypeOf(Source) + ")";
EndTry;

LR.TargetProperty = PCR.Target + "  (" + PCR.TargetType + ")";

If HandlerName <> "" Then
	LR.Handler = HandlerName;
EndIf;

If Value <> Undefined Then
	LR.ConvertedValue = String(Value) + "  (" + TypeOf(Value) + ")";
EndIf;

ErrorMessageString = WriteToExecutionLog(PErrorMessages, LR);

If Not ContinueOnError Then
	Raise ErrorMessageString;
EndIf;

EndProcedure 

Procedure WriteErrorInfoDERHandlers(PErrorMessages, ErrorString, RuleName, HandlerName, Object = Undefined)
	
	LR     = GetLogRecordStructure(PErrorMessages, ErrorString);
	LR.DER = RuleName;
	
	If Object <> Undefined Then
		LR.Object = String(Object) + "  (" + TypeOf(Object) + ")";
	EndIf;
	
	LR.Handler = HandlerName;
	
	ErrorMessageString = WriteToExecutionLog(PErrorMessages, LR);
	
	If Not ContinueOnError Then
		Raise ErrorMessageString;
	EndIf;
	
EndProcedure

Function WriteErrorInfoConversionHandlers(PErrorMessages, ErrorString, HandlerName)
	
	LR         = GetLogRecordStructure(PErrorMessages, ErrorString);
	LR.Handler = HandlerName;
	ErrorMessageString = WriteToExecutionLog(PErrorMessages, LR);
	Return ErrorMessageString;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// EXCHANGE RULE IMPORT PROCEDURES

// Imports the property group conversion rule.
//
// Parameters:
//  ExchangeRules - XMLReader.
//  PropertyTable - value table that contains PCR.
// 
Procedure ImportPGCR(ExchangeRules, PropertyTable, DisabledProperties, SynchronizeByID, OCRName = "")
	
	IsDisabledField = deAttribute(ExchangeRules, BooleanType, "Disable");
	
	If IsDisabledField Then
		
		NewRow = DisabledProperties.Add();
		
	Else
		
		NewRow = PropertyTable.Add();
		
	EndIf;
	
	NewRow.IsFolder = True;
	
	NewRow.GroupRules         = PropertyConversionRuleTable.Copy();
	NewRow.DisabledGroupRules = PropertyConversionRuleTable.Copy();
	
	// Default values
	NewRow.DontReplace             = False;
	NewRow.GetFromIncomingData      = False;
	NewRow.SimplifiedPropertyExport = False;
	
	SearchFieldString = "";
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If NodeName = "Source" Then
			NewRow.Source     = deAttribute(ExchangeRules, StringType, "Name");
			NewRow.SourceKind = deAttribute(ExchangeRules, StringType, "Kind");
			NewRow.SourceType = deAttribute(ExchangeRules, StringType, "Type");
			deSkip(ExchangeRules);
			
		ElsIf NodeName = "Target" Then
			NewRow.Target     = deAttribute(ExchangeRules, StringType, "Name");
			NewRow.TargetKind = deAttribute(ExchangeRules, StringType, "Kind");
			NewRow.TargetType = deAttribute(ExchangeRules, StringType, "Type");
			deSkip(ExchangeRules);
			
		ElsIf NodeName = "Property" Then
			
			PCRParent = ?(ValueIsFilled(NewRow.Source), "_" + NewRow.Source, "_" + NewRow.Target);
			ImportPCR(ExchangeRules, NewRow.GroupRules,, NewRow.DisabledGroupRules, SearchFieldString, SynchronizeByID, OCRName, PCRParent);
		ElsIf NodeName = "BeforeProcessExport" Then
			NewRow.BeforeProcessExport = deElementValue(ExchangeRules, StringType);
			NewRow.HasBeforeProcessExportHandler = Not IsBlankString(NewRow.BeforeProcessExport);
			
		ElsIf NodeName = "AfterProcessExport" Then
			NewRow.AfterProcessExport = deElementValue(ExchangeRules, StringType);
			NewRow.HasAfterProcessExportHandler = Not IsBlankString(NewRow.AfterProcessExport);
			
		ElsIf NodeName = "Code" Then
			NewRow.Name = deElementValue(ExchangeRules, StringType);
			
		ElsIf NodeName = "Description" Then
			NewRow.Description = deElementValue(ExchangeRules, StringType);
			
		ElsIf NodeName = "Order" Then
			NewRow.order = deElementValue(ExchangeRules, NumberType);
			
		ElsIf NodeName = "DontReplace" Then
			NewRow.DontReplace = deElementValue(ExchangeRules, BooleanType);
			
		ElsIf NodeName = "ConversionRuleCode" Then
			NewRow.ConversionRule = deElementValue(ExchangeRules, StringType);
			
		ElsIf NodeName = "BeforeExport" Then
			NewRow.BeforeExport = deElementValue(ExchangeRules, StringType);
			NewRow.HasBeforeExportHandler = Not IsBlankString(NewRow.BeforeExport);
			
		ElsIf NodeName = "OnExport" Then
			NewRow.OnExport = deElementValue(ExchangeRules, StringType);
			NewRow.HasOnExportHandler    = Not IsBlankString(NewRow.OnExport);
			
		ElsIf NodeName = "AfterExport" Then
			NewRow.AfterExport = deElementValue(ExchangeRules, StringType);
			NewRow.HasAfterExportHandler  = Not IsBlankString(NewRow.AfterExport);
			
		ElsIf NodeName = "ExportGroupToFile" Then
			NewRow.ExportGroupToFile = deElementValue(ExchangeRules, BooleanType);
			
		ElsIf NodeName = "GetFromIncomingData" Then
			NewRow.GetFromIncomingData = deElementValue(ExchangeRules, BooleanType);
			
		ElsIf (NodeName = "Group") And (ExchangeRules.NodeType = XMLNodeTypeEndElement) Then
			Break;
		EndIf;
		
	EndDo;
	
	If NewRow.HasBeforeProcessExportHandler Then
		
		HandlerName = "PGCR_[OCRName][PCRPropertyName]_BeforeProcessExport_[PGCRName]_[OCRNameLength]";
		HandlerName = StrReplace(HandlerName, "[OCRName]", OCRName); 
		HandlerName = StrReplace(HandlerName, "[PCRPropertyName]", PCRPropertyName(NewRow));
		HandlerName = StrReplace(HandlerName, "[PGCRName]", NewRow.Name);
		HandlerName = StrReplace(HandlerName, "[OCRNameLength]", StrLen(OCRName));
		NewRow.BeforeExportProcessHandlerName = HandlerName;
		
	EndIf;
	
	If NewRow.HasAfterProcessExportHandler Then
		
		HandlerName = "PGCR_[OCRName][PCRPropertyName]_AfterProcessExport_[PGCRName]_[OCRNameLength]";
		HandlerName = StrReplace(HandlerName, "[OCRName]", OCRName);
		HandlerName = StrReplace(HandlerName, "[PCRPropertyName]", PCRPropertyName(NewRow));
		HandlerName = StrReplace(HandlerName, "[PGCRName]", NewRow.Name);
		HandlerName = StrReplace(HandlerName, "[OCRNameLength]", StrLen(OCRName));
		NewRow.AfterExportProcessHandlerName = HandlerName;
		
	EndIf;
	
	
	If NewRow.HasBeforeExportHandler Then
		
		HandlerName = "PGCR_[OCRName][PCRPropertyName]_BeforeExportProperty_[PGCRName]_[OCRNameLength]";
		HandlerName = StrReplace(HandlerName, "[OCRName]", OCRName);
		HandlerName = StrReplace(HandlerName, "[PCRPropertyName]", PCRPropertyName(NewRow));
		
		HandlerName = StrReplace(HandlerName, "[PGCRName]", NewRow.Name);
		HandlerName = StrReplace(HandlerName, "[OCRNameLength]", StrLen(OCRName));
		NewRow.BeforeExportHandlerName = HandlerName;
		
	EndIf;
	
	
	If NewRow.HasOnExportHandler Then
		
		HandlerName = "PGCR_[OCRName][PCRPropertyName]_OnExportProperty_[PGCRName]_[OCRNameLength]";
		HandlerName = StrReplace(HandlerName, "[OCRName]", OCRName);
		HandlerName = StrReplace(HandlerName, "[PCRPropertyName]", PCRPropertyName(NewRow));
		HandlerName = StrReplace(HandlerName, "[PGCRName]", NewRow.Name);
		HandlerName = StrReplace(HandlerName, "[OCRNameLength]", StrLen(OCRName));
		NewRow.OnExportHandlerName = HandlerName;
		
	EndIf;
	
	If NewRow.HasAfterExportHandler Then
		
		HandlerName = "PGCR_[OCRName][PCRPropertyName]_AfterExportProperty_[PGCRName]_[OCRNameLength]";
		HandlerName = StrReplace(HandlerName, "[OCRName]", OCRName);
		HandlerName = StrReplace(HandlerName, "[PCRPropertyName]", PCRPropertyName(NewRow));
		HandlerName = StrReplace(HandlerName, "[PGCRName]", NewRow.Name);
		HandlerName = StrReplace(HandlerName, "[OCRNameLength]", StrLen(OCRName));
		NewRow.AfterExportHandlerName = HandlerName;
		
	EndIf;
	
	NewRow.SearchFieldString = SearchFieldString;
	
	NewRow.XMLNodeRequiredOnExport = NewRow.HasOnExportHandler Or NewRow.HasAfterExportHandler;
	
	NewRow.XMLNodeRequiredOnExportGroup = NewRow.HasAfterProcessExportHandler; 
	
EndProcedure

Procedure AddFieldToSearchString(SearchFieldString, FieldName)
	
	If IsBlankString(FieldName) Then
		Return;
	EndIf;
	
	If Not IsBlankString(SearchFieldString) Then
		SearchFieldString = SearchFieldString + ",";
	EndIf;
	
	SearchFieldString = SearchFieldString + FieldName;
	
EndProcedure

// Imports the property conversion rule.
//
// Parameters:
//  ExchangeRules - XMLReader.
//  PropertyTable - value table that contains PCR.
//  SearchTable   - value table that contains PCR (to provide synchronization).
//
Procedure ImportPCR( ExchangeRules,
	PropertyTable,
	SearchTable = Undefined,
	DisabledProperties,
	SearchFieldString = "",
	SynchronizeByID = False,
	OCRName = "",
	ParentName = "")
	
	
	IsDisabledField    = deAttribute(ExchangeRules, BooleanType, "Disable");
	IsSearchField      = deAttribute(ExchangeRules, BooleanType, "Search");
	IsRequiredProperty = deAttribute(ExchangeRules, BooleanType, "Required");
	
	If IsDisabledField Then
		
		NewRow = DisabledProperties.Add();
		
	ElsIf IsRequiredProperty And SearchTable <> Undefined Then
		
		NewRow = SearchTable.Add();
		
	ElsIf IsSearchField And SearchTable <> Undefined Then
		
		NewRow = SearchTable.Add();
		
	Else
		
		NewRow = PropertyTable.Add();
		
	EndIf;
	
	// Default values
	NewRow.DontReplace         = False;
	NewRow.GetFromIncomingData = False;
	NewRow.IsRequiredProperty  = IsRequiredProperty;
	NewRow.IsSearchField       = IsSearchField;
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If NodeName = "Source" Then
			NewRow.Source     = deAttribute(ExchangeRules, StringType, "Name");
			NewRow.SourceKind = deAttribute(ExchangeRules, StringType, "Kind");
			NewRow.SourceType = deAttribute(ExchangeRules, StringType, "Type");
			deSkip(ExchangeRules);
			
		ElsIf NodeName = "Target" Then
			NewRow.Target     = deAttribute(ExchangeRules, StringType, "Name");
			NewRow.TargetKind = deAttribute(ExchangeRules, StringType, "Kind");
			NewRow.TargetType = deAttribute(ExchangeRules, StringType, "Type");
			
			If Not IsDisabledField Then
				
				// Filling the SearchFieldString variable to provide search by all tabular
				// section details that have PCR
				AddFieldToSearchString(SearchFieldString, NewRow.Target);
				
			EndIf;
			
			deSkip(ExchangeRules);
			
		ElsIf NodeName = "Code" Then
			NewRow.Name = deElementValue(ExchangeRules, StringType);
			
		ElsIf NodeName = "Description" Then
			NewRow.Description = deElementValue(ExchangeRules, StringType);
			
		ElsIf NodeName = "Order" Then
			NewRow.order = deElementValue(ExchangeRules, NumberType);
			
		ElsIf NodeName = "DontReplace" Then
			NewRow.DontReplace = deElementValue(ExchangeRules, BooleanType);
			
		ElsIf NodeName = "ConversionRuleCode" Then
			NewRow.ConversionRule = deElementValue(ExchangeRules, StringType);
			
		ElsIf NodeName = "BeforeExport" Then
			NewRow.BeforeExport = deElementValue(ExchangeRules, StringType);
			NewRow.HasBeforeExportHandler = Not IsBlankString(NewRow.BeforeExport);
			
		ElsIf NodeName = "OnExport" Then
			NewRow.OnExport = deElementValue(ExchangeRules, StringType);
			NewRow.HasOnExportHandler    = Not IsBlankString(NewRow.OnExport);
			
		ElsIf NodeName = "AfterExport" Then
			NewRow.AfterExport = deElementValue(ExchangeRules, StringType);
			NewRow.HasAfterExportHandler  = Not IsBlankString(NewRow.AfterExport);
			
		ElsIf NodeName = "GetFromIncomingData" Then
			NewRow.GetFromIncomingData = deElementValue(ExchangeRules, BooleanType);
			
		ElsIf NodeName = "CastToLength" Then
			NewRow.CastToLength = deElementValue(ExchangeRules, NumberType);
			
		ElsIf NodeName = "ParameterForTransferName" Then
			NewRow.ParameterForTransferName = deElementValue(ExchangeRules, StringType);
			
		ElsIf NodeName = "SearchByEqualDate" Then
			NewRow.SearchByEqualDate = deElementValue(ExchangeRules, BooleanType);
			
		ElsIf (NodeName = "Property") And (ExchangeRules.NodeType = XMLNodeTypeEndElement) Then
			Break;
		EndIf;
		
	EndDo;
	
	If NewRow.HasBeforeExportHandler Then
		
		HandlerName = "PCR_[OCRName][ParentName][PCRPropertyName]_BeforeExportProperty_[PCRName]_[OCRNameLength]";
		HandlerName = StrReplace(HandlerName, "[OCRName]", OCRName);
		HandlerName = StrReplace(HandlerName, "[ParentName]", ParentName);
		HandlerName = StrReplace(HandlerName, "[PCRPropertyName]", PCRPropertyName(NewRow));
		HandlerName = StrReplace(HandlerName, "[PCRName]", NewRow.Name);
		HandlerName = StrReplace(HandlerName, "[OCRNameLength]", StrLen(OCRName));
		
		NewRow.BeforeExportHandlerName = HandlerName;
		
	EndIf;
	
	If NewRow.HasOnExportHandler Then
		
		HandlerName = "PCR_[OCRName][ParentName][PCRPropertyName]_OnExportProperty_[PCRName]_[OCRNameLength]";
		HandlerName = StrReplace(HandlerName, "[OCRName]", OCRName);
		HandlerName = StrReplace(HandlerName, "[ParentName]", ParentName);
		HandlerName = StrReplace(HandlerName, "[PCRPropertyName]", PCRPropertyName(NewRow));
		HandlerName = StrReplace(HandlerName, "[PCRName]", NewRow.Name);
		HandlerName = StrReplace(HandlerName, "[OCRNameLength]", StrLen(OCRName));
		
		NewRow.OnExportHandlerName = HandlerName;
		
	EndIf;
	
	
	If NewRow.HasAfterExportHandler Then
		
		HandlerName = "PCR_[OCRName][ParentName][PCRPropertyName]_AfterExportProperty_[PCRName]_[OCRNameLength]";
		HandlerName = StrReplace(HandlerName, "[OCRName]", OCRName);
		HandlerName = StrReplace(HandlerName, "[ParentName]", ParentName);
		HandlerName = StrReplace(HandlerName, "[PCRPropertyName]", PCRPropertyName(NewRow));
		HandlerName = StrReplace(HandlerName, "[PCRName]", NewRow.Name);
		HandlerName = StrReplace(HandlerName, "[OCRNameLength]", StrLen(OCRName));
		
		NewRow.AfterExportHandlerName = HandlerName;
		
	EndIf;
	NewRow.SimplifiedPropertyExport = Not NewRow.GetFromIncomingData
	And Not NewRow.HasBeforeExportHandler
	And Not NewRow.HasOnExportHandler
	And Not NewRow.HasAfterExportHandler
	And IsBlankString(NewRow.ConversionRule)
	And NewRow.SourceType = NewRow.TargetType
	And (NewRow.SourceType = "String" Or NewRow.SourceType = "Number" Or NewRow.SourceType = "Boolean" Or NewRow.SourceType = "Date");
	
	NewRow.XMLNodeRequiredOnExport = NewRow.HasOnExportHandler Or NewRow.HasAfterExportHandler;
	
EndProcedure

// Imports property conversion rules.
//
// Parameters:
// ExchangeRules - XMLReader.
// PropertyTable - value table that contains PCR.
// SearchTable   - value table that contains PCR (to provide synchronization).
// 
Procedure ImportProperties(ExchangeRules,
	PropertyTable,
	SearchTable,
	DisabledProperties,
	Val SynchronizeByID = False,
	OCRName = "")
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If NodeName = "Property" Then
			
			ImportPCR(ExchangeRules, PropertyTable, SearchTable, DisabledProperties,, SynchronizeByID, OCRName);
			
		ElsIf NodeName = "Group" Then
			
			ImportPGCR(ExchangeRules, PropertyTable, DisabledProperties, SynchronizeByID, OCRName);
			
		ElsIf (NodeName = "Properties") And (ExchangeRules.NodeType = XMLNodeTypeEndElement) Then
			
			Break;
			
		EndIf;
		
	EndDo;
	
	PropertyTable.Sort("Order");
	SearchTable.Sort("Order");
	DisabledProperties.Sort("Order");
	
EndProcedure

// Imports the value conversion rule.
//
// Parameters:
// ExchangeRules - XMLReader.
// Values        - map source object values to target object presentation strings. 
// SourceType    - Type - source object type.
//
Procedure ImportVCR(ExchangeRules, Values, SourceType)
	
	Source = "";
	Target = "";
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If NodeName = "Source" Then
			Source = deElementValue(ExchangeRules, StringType);
		ElsIf NodeName = "Target" Then
			Target = deElementValue(ExchangeRules, StringType);
		ElsIf (NodeName = "Value") And (ExchangeRules.NodeType = XMLNodeTypeEndElement) Then
			Break;
		EndIf;
		
	EndDo;
	
	
	If Not IsBlankString(Source) Then
		Values.Insert(Source, Target);
	EndIf;
	
EndProcedure

// Imports value conversion rules.
//
// Parameters:
// ExchangeRules - XMLReader.
// Values        - map source object values to target object presentation strings. 
// SourceType    - Type - source object type.
// 
Procedure ImportValues(ExchangeRules, Values, SourceType);
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If NodeName = "Value" Then
			ImportVCR(ExchangeRules, Values, SourceType);
		ElsIf (NodeName = "Values") And (ExchangeRules.NodeType = XMLNodeTypeEndElement) Then
			Break;
		EndIf;
		
	EndDo;
	
EndProcedure

// Imports object conversion rules.
//
// Parameters:
//  ExchangeRules - XMLReader.
//  XMLWriter     - XMLWriter - rules to be saved to the exchange file to be used
//                  during the data import.
//
Procedure ImportConversionRule(ExchangeRules, XMLWriter)
	
	XMLWriter.WriteStartElement("Rule");
	
	NewRow = ConversionRuleTable.Add();
	
	// Default values
	
	NewRow.RememberExported       = True;
	NewRow.DontReplace           = False;
	NewRow.ExchangeObjectPriority = Enums.ExchangeObjectPriorities.ReceivedExchangeObjectPriorityHigher;
	
	SearchInTabularSections = New ValueTable;
	SearchInTabularSections.Columns.Add("ItemName");
	SearchInTabularSections.Columns.Add("KeySearchFieldArray");
	SearchInTabularSections.Columns.Add("KeySearchFields");
	SearchInTabularSections.Columns.Add("Valid", deTypeDescription("Boolean"));
	
	NewRow.SearchInTabularSections = SearchInTabularSections;  
	
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If NodeName = "Code" Then
			
			Value = deElementValue(ExchangeRules, StringType);
			deWriteElement(XMLWriter, NodeName, Value);
			NewRow.Name = Value;
			
		ElsIf NodeName = "Description" Then
			
			NewRow.Description = deElementValue(ExchangeRules, StringType);
			
		ElsIf NodeName = "SynchronizeByID" Then
			
			NewRow.SynchronizeByID = deElementValue(ExchangeRules, BooleanType);
			deWriteElement(XMLWriter, NodeName, NewRow.SynchronizeByID);
			
		ElsIf NodeName = "DontCreateIfNotFound" Then
			
			NewRow.DontCreateIfNotFound = deElementValue(ExchangeRules, BooleanType);   
			
		ElsIf NodeName = "RecordObjectChangeAtSenderNode" Then // not supported
			
			deSkip(ExchangeRules);
			
		ElsIf NodeName = "DontExportPropertyObjectsByRefs" Then
			
			NewRow.DontExportPropertyObjectsByRefs = deElementValue(ExchangeRules, BooleanType);
			
		ElsIf NodeName = "SearchBySearchFieldsIfNotFoundByID" Then
			
			NewRow.SearchBySearchFieldsIfNotFoundByID = deElementValue(ExchangeRules, BooleanType); 
			deWriteElement(XMLWriter, NodeName, NewRow.SearchBySearchFieldsIfNotFoundByID);
			
		ElsIf NodeName = "OnExchangeObjectByRefSetGIUDOnly" Then
			
			NewRow.OnExchangeObjectByRefSetGIUDOnly = deElementValue(ExchangeRules, BooleanType); 
			deWriteElement(XMLWriter, NodeName, NewRow.OnExchangeObjectByRefSetGIUDOnly);
			
		ElsIf NodeName = "DontReplaceCreatedInTargetObject" Then
			
			NewRow.DontReplaceCreatedInTargetObject = deElementValue(ExchangeRules, BooleanType); 
			deWriteElement(XMLWriter, NodeName, NewRow.DontReplaceCreatedInTargetObject);  
			
		ElsIf NodeName = "UseQuickSearchOnImport" Then
			
			NewRow.UseQuickSearchOnImport = deElementValue(ExchangeRules, BooleanType); 
			
		ElsIf NodeName = "GenerateNewNumberOrCodeIfNotSet" Then
			
			NewRow.GenerateNewNumberOrCodeIfNotSet = deElementValue(ExchangeRules, BooleanType);
			deWriteElement(XMLWriter, NodeName, NewRow.GenerateNewNumberOrCodeIfNotSet);
			
		ElsIf NodeName = "DontRememberExported" Then
			
			NewRow.RememberExported = Not deElementValue(ExchangeRules, BooleanType);
			
		ElsIf NodeName = "DontReplace" Then
			
			Value = deElementValue(ExchangeRules, BooleanType);
			deWriteElement(XMLWriter, NodeName, Value);
			NewRow.DontReplace = Value;
			
		ElsIf NodeName = "Target" Then
			
			Value = deElementValue(ExchangeRules, StringType);
			deWriteElement(XMLWriter, NodeName, Value);
			
			NewRow.Target     = Value;
			NewRow.TargetType = Value;
			
		ElsIf NodeName = "Source" Then
			
			Value = deElementValue(ExchangeRules, StringType);
			deWriteElement(XMLWriter, NodeName, Value);
			
			NewRow.SourceType = Value;
			
			If ExchangeMode = "Import" Then
				
				NewRow.Source = Value;
				
			Else
				
				If Not IsBlankString(Value) Then
					
					If Not ExchangeRuleInfoImportMode Then
						
						Try
							
							NewRow.Source = Type(Value);
							
							Managers[NewRow.Source].OCR = NewRow;
							
						Except
							
							WriteErrorInfoToLog(11, ErrorDescription(), String(NewRow.Source));
							
						EndTry;
						
					EndIf;
					
				EndIf;
				
			EndIf;
			
			// Properties
			
		ElsIf NodeName = "Properties" Then
			
			NewRow.Properties         = PropertyConversionRuleTable.Copy();
			NewRow.SearchProperties   = PropertyConversionRuleTable.Copy();
			NewRow.DisabledProperties = PropertyConversionRuleTable.Copy();
			
			If NewRow.SynchronizeByID = True Then
				
				SearchPropertyUUID = NewRow.SearchProperties.Add();
				SearchPropertyUUID.Name = "{UUID}";
				SearchPropertyUUID.Source = "{UUID}";
				SearchPropertyUUID.Target = "{UUID}";
				SearchPropertyUUID.IsRequiredProperty = True;
				
			EndIf;
			
			ImportProperties(ExchangeRules, NewRow.Properties, NewRow.SearchProperties, NewRow.DisabledProperties, NewRow.SynchronizeByID, NewRow.Name);
			
			// Values
		ElsIf NodeName = "Values" Then
			
			ImportValues(ExchangeRules, NewRow.PredefinedDataReadValues, NewRow.Source);
			
			
			// Event handlers
			
		ElsIf NodeName = "BeforeExport" Then
			
			NewRow.BeforeExport = deElementValue(ExchangeRules, StringType);
			
			HandlerName = "OCR_[OCRName]_BeforeExportObject";
			NewRow.BeforeExportHandlerName = StrReplace(HandlerName, "[OCRName]", NewRow.Name);
			
			NewRow.HasBeforeExportHandler = Not IsBlankString(NewRow.BeforeExport);
			
		ElsIf NodeName = "OnExport" Then
			
			NewRow.OnExport = deElementValue(ExchangeRules, StringType);
			HandlerName = "OCR_[OCRName]_OnExportObject";
			NewRow.OnExportHandlerName = StrReplace(HandlerName, "[OCRName]", NewRow.Name);
			NewRow.HasOnExportHandler = Not IsBlankString(NewRow.OnExport);
			
		ElsIf NodeName = "AfterExport" Then
			
			NewRow.AfterExport = deElementValue(ExchangeRules, StringType);
			HandlerName = "OCR_[OCRName]_AfterExportObject";
			NewRow.AfterExportHandlerName = StrReplace(HandlerName, "[OCRName]", NewRow.Name);
			NewRow.HasAfterExportHandler  = Not IsBlankString(NewRow.AfterExport);
			
		ElsIf NodeName = "AfterExportToFile" Then
			
			NewRow.AfterExportToFile = deElementValue(ExchangeRules, StringType);
			HandlerName = "OCR_[OCRName]_AfterExportObjectToExchangeFile";
			NewRow.AfterExportToFileHandlerName = StrReplace(HandlerName, "[OCRName]", NewRow.Name);
			NewRow.HasAfterExportToFileHandler  = Not IsBlankString(NewRow.AfterExportToFile);
			
			// For importing data
			
		ElsIf NodeName = "BeforeImport" Then
			
			Value = deElementValue(ExchangeRules, StringType);
			
			If ExchangeMode = "Import" Then
				
				NewRow.BeforeImport               = Value;
				HandlerName = "OCR_[OCRName]_BeforeImportObject";
				NewRow.BeforeImportHandlerName = StrReplace(HandlerName, "[OCRName]", NewRow.Name);
				NewRow.HasBeforeImportHandler = Not IsBlankString(Value);
				
			Else
				
				deWriteElement(XMLWriter, NodeName, Value);
				
			EndIf;
			
		ElsIf NodeName = "OnImport" Then
			
			Value = deElementValue(ExchangeRules, StringType);
			
			If ExchangeMode = "Import" Then
				
				NewRow.OnImport           = Value;
				HandlerName = "OCR_[OCRName]_OnImportObject";
				NewRow.OnImportHandlerName = StrReplace(HandlerName, "[OCRName]", NewRow.Name);
				NewRow.HasOnImportHandler = Not IsBlankString(Value);
				
			Else
				
				deWriteElement(XMLWriter, NodeName, Value);
				
			EndIf; 
			
		ElsIf NodeName = "AfterImport" Then
			
			Value = deElementValue(ExchangeRules, StringType);
			
			If ExchangeMode = "Import" Then
				
				NewRow.AfterImport           = Value;
				HandlerName = "OCR_[OCRName]_AfterImportObject";
				NewRow.AfterImportHandlerName = StrReplace(HandlerName, "[OCRName]", NewRow.Name);
				NewRow.HasAfterImportHandler = Not IsBlankString(Value);
				
			Else
				
				deWriteElement(XMLWriter, NodeName, Value);
				
			EndIf;
			
		ElsIf NodeName = "SearchFieldSequence" Then
			
			Value = deElementValue(ExchangeRules, StringType);
			NewRow.HasSearchFieldSequenceHandler = Not IsBlankString(Value);
			
			If ExchangeMode = "Import" Then
				
				NewRow.SearchFieldSequence = Value;
				HandlerName = "OCR_[OCRName]_SearchFieldSequence";
				NewRow.SearchFieldSequenceHandlerName = StrReplace(HandlerName, "[OCRName]", NewRow.Name);
				
			Else
				
				deWriteElement(XMLWriter, NodeName, Value);
				
			EndIf;
			
		ElsIf NodeName = "ExchangeObjectPriority" Then
			
			Value = deElementValue(ExchangeRules, StringType);
			
			If Value = "Lower" Then
				NewRow.ExchangeObjectPriority = Enums.ExchangeObjectPriorities.ReceivedExchangeObjectPriorityLower;
			ElsIf Value = "Matches" Then
				NewRow.ExchangeObjectPriority = Enums.ExchangeObjectPriorities.ObjectCameDuringExchangeHasSamePriority;
			EndIf;
			
			// Object search variants  
		ElsIf NodeName = "ObjectSearchVariantSetup" Then
			
			ImportSearchVariantSettings(ExchangeRules, NewRow);
			
		ElsIf NodeName = "SearchInTabularSections" Then
			
			// Importing data by key search fields in tabular sections
			Value = deElementValue(ExchangeRules, StringType);
			
			For Number = 1 to StrLineCount(Value) Do
				
				CurrentLine = StrGetLine(Value, Number);
				
				SearchString = SplitWithSeparator(CurrentLine, ":");
				
				TableRow = NewRow.SearchInTabularSections.Add();
				
				TableRow.ItemName            = CurrentLine;
				TableRow.KeySearchFields     = SearchString;
				TableRow.KeySearchFieldArray = GetArrayFromString(SearchString);
				TableRow.Valid               = TableRow.KeySearchFieldArray.Count() <> 0;
				
			EndDo;
			
		ElsIf NodeName = "SearchFields" Then
			
			NewRow.SearchFields = deElementValue(ExchangeRules, StringType);
			
		ElsIf NodeName = "TableFields" Then
			
			NewRow.TableFields = deElementValue(ExchangeRules, StringType);
			
		ElsIf (NodeName = "Rule") And (ExchangeRules.NodeType = XMLNodeTypeEndElement) Then
			
			Break;
			
		EndIf;
		
	EndDo;
	
	If ExchangeMode <> "Import" Then
		
		// GETTING TABULAR SECTION FIELD SEARCH PROPERTIES FOR DATA IMPORT RULES (XMLWriter)
		
		ResultingTSSearchString = "";
		
		// Tabular section search field details must be passed to the target infobase
		For Each PropertyString In NewRow.Properties Do
			
			If Not PropertyString.IsFolder
				Or IsBlankString(PropertyString.TargetKind)
				Or IsBlankString(PropertyString.Target) Then
				
				Continue;
				
			EndIf;
			
			If IsBlankString(PropertyString.SearchFieldString) Then
				Continue;
			EndIf;
			
			ResultingTSSearchString = ResultingTSSearchString + Chars.LF + PropertyString.TargetKind + "." + PropertyString.Target + ":" + PropertyString.SearchFieldString;
			
		EndDo;
		
		ResultingTSSearchString = TrimAll(ResultingTSSearchString);
		
		If Not IsBlankString(ResultingTSSearchString) Then
			
			deWriteElement(XMLWriter, "SearchInTabularSections", ResultingTSSearchString);
			
		EndIf;
		
		// GETTING TABLE FIELDS AND SEARCH FIELDS FOR DATA IMPORT RULES (XMLWriter)
		
		ArrayProperties = NewRow.Properties.Copy(New Structure("IsFolder, ParameterForTransferName", False, ""), "Target").UnloadColumn("Target");
		
		ArraySearchProperties         = NewRow.SearchProperties.Copy(New Structure("IsFolder, ParameterForTransferName", False, ""), "Target").UnloadColumn("Target");
		SearchPropertyAdditionalArray = NewRow.Properties.Copy(New Structure("IsSearchField, ParameterForTransferName", True, ""), "Target").UnloadColumn("Target");
		
		For Each Value In SearchPropertyAdditionalArray Do
			
			ArraySearchProperties.Add(Value);
			
		EndDo;
		
		// Deleting the value with the specified UUID from the search field array
		CommonUseClientServer.DeleteValueFromArray(ArraySearchProperties, "{UUID}");
		
		// Getting the ArrayProperties variable value
		TableFieldsTable = New ValueTable;
		TableFieldsTable.Columns.Add("Target");
		
		CommonUseClientServer.SupplementTableFromArray(TableFieldsTable, ArrayProperties, "Target");
		CommonUseClientServer.SupplementTableFromArray(TableFieldsTable, ArraySearchProperties, "Target");
		
		TableFieldsTable.GroupBy("Target");
		ArrayProperties = TableFieldsTable.UnloadColumn("Target");
		
		TableFields = StringFunctionsClientServer.StringFromSubstringArray(ArrayProperties);
		SearchFields = StringFunctionsClientServer.StringFromSubstringArray(ArraySearchProperties);
		
		If Not IsBlankString(TableFields) Then
			deWriteElement(XMLWriter, "TableFields", TableFields);
		EndIf;
		
		If Not IsBlankString(SearchFields) Then
			deWriteElement(XMLWriter, "SearchFields", SearchFields);
		EndIf;
		
	EndIf;
	
	// Closing the node
	XMLWriter.WriteEndElement(); // Rule
	
	// Quick access to OCR by name
	Rules.Insert(NewRow.Name, NewRow);
	
EndProcedure 

Procedure ImportSearchVariantSetting(ExchangeRules, NewRow)
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		NodeType = ExchangeRules.NodeType;
		
		If NodeName = "AlgorithmSettingName" Then
			
			Value = deElementValue(ExchangeRules, StringType);
			If ExchangeRuleInfoImportMode Then
				NewRow.AlgorithmSettingName = Value;
			EndIf;
			
		ElsIf NodeName = "UserSettingsName" Then
			
			Value = deElementValue(ExchangeRules, StringType);
			If ExchangeRuleInfoImportMode Then
				NewRow.UserSettingsName = Value;
			EndIf;
			
		ElsIf NodeName = "SettingDetailsForUser" Then
			
			Value = deElementValue(ExchangeRules, StringType);
			If ExchangeRuleInfoImportMode Then
				NewRow.SettingDetailsForUser = Value;
			EndIf;
			
		ElsIf (NodeName = "SearchVariant") And (NodeType = XMLNodeTypeEndElement) Then
			Break;
		Else
		EndIf;
		
	EndDo; 
	
EndProcedure

Procedure ImportSearchVariantSettings(ExchangeRules, BaseOCRString)
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		NodeType = ExchangeRules.NodeType;
		
		If NodeName = "SearchVariant" Then
			
			If ExchangeRuleInfoImportMode Then
				SettingRow = SearchFieldInfoImportResultTable.Add();
				SettingRow.ExchangeRuleCode = BaseOCRString.Name;
				SettingRow.ExchangeRuleDescription = BaseOCRString.Description;
			Else
				SettingRow = Undefined;
			EndIf;
			
			ImportSearchVariantSetting(ExchangeRules, SettingRow);
			
		ElsIf (NodeName = "ObjectSearchVariantSetup") And (NodeType = XMLNodeTypeEndElement) Then
			Break;
		Else
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Imports object conversion rules.
//
// Parameters:
//  ExchangeRules - XMLReader.
//  XMLWriter     - XMLWriter - rules to be saved to the exchange file to be used
//                  during the data import.
// 
Procedure ImportConversionRules(ExchangeRules, XMLWriter)
	
	ConversionRuleTable.Clear();
	
	XMLWriter.WriteStartElement("ObjectConversionRules");
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If NodeName = "Rule" Then
			
			ImportConversionRule(ExchangeRules, XMLWriter);
			
		ElsIf (NodeName = "ObjectConversionRules") And (ExchangeRules.NodeType = XMLNodeTypeEndElement) Then
			
			Break;
			
		EndIf;
		
	EndDo;
	ImportConversionRule_ExchangeObjectExportModes(XMLWriter);
	
	XMLWriter.WriteEndElement();
	
EndProcedure

// Imports the data clearing rule group according to the format of exchange rules.
//
// Parameters:
//  NewRow - value tree row that describes the data clearing rule group.
// 
Procedure ImportDCRGroup(ExchangeRules, NewRow)
	
	NewRow.IsFolder = True;
	NewRow.Enable = Number(Not deAttribute(ExchangeRules, BooleanType, "Disable"));
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		NodeType = ExchangeRules.NodeType;
		
		If NodeName = "Code" Then
			NewRow.Name = deElementValue(ExchangeRules, StringType);
			
		ElsIf NodeName = "Description" Then
			NewRow.Description = deElementValue(ExchangeRules, StringType);
			
		ElsIf NodeName = "Order" Then
			NewRow.order = deElementValue(ExchangeRules, NumberType);
			
		ElsIf NodeName = "Rule" Then
			VTRow = NewRow.Rows.Add();
			ImportDCR(ExchangeRules, VTRow);
			
		ElsIf (NodeName = "Group") And (NodeType = XMLNodeTypeStartElement) Then
			VTRow = NewRow.Rows.Add();
			ImportDCRGroup(ExchangeRules, VTRow);
			
		ElsIf (NodeName = "Group") And (NodeType = XMLNodeTypeEndElement) Then
			Break;
		EndIf;
		
	EndDo;
	
	
	If IsBlankString(NewRow.Description) Then
		NewRow.Description = NewRow.Name;
	EndIf; 
	
EndProcedure

// Imports the data clearing rule according to the format of exchange rules
//
// Parameters:
//  NewRow - value tree row that describes the data clearing rule.
//  
Procedure ImportDCR(ExchangeRules, NewRow)
	
	NewRow.Enable = Number(Not deAttribute(ExchangeRules, BooleanType, "Disable"));
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If NodeName = "Code" Then
			Value = deElementValue(ExchangeRules, StringType);
			NewRow.Name = Value;
			
		ElsIf NodeName = "Description" Then
			NewRow.Description = deElementValue(ExchangeRules, StringType);
			
		ElsIf NodeName = "Order" Then
			NewRow.order = deElementValue(ExchangeRules, NumberType);
			
		ElsIf NodeName = "DataSelectionVariant" Then
			NewRow.DataSelectionVariant = deElementValue(ExchangeRules, StringType);
			
		ElsIf NodeName = "SelectionObject" Then
			
			If Not ExchangeRuleInfoImportMode Then
				
				SelectionObject = deElementValue(ExchangeRules, StringType);
				If Not IsBlankString(SelectionObject) Then
					NewRow.SelectionObject = Type(SelectionObject);
				EndIf;
				
			EndIf;
			
		ElsIf NodeName = "DeleteForPeriod" Then
			NewRow.DeleteForPeriod = deElementValue(ExchangeRules, StringType);
			
		ElsIf NodeName = "Directly" Then
			NewRow.Directly = deElementValue(ExchangeRules, BooleanType);
			
			
			// Event handlers
			
		ElsIf NodeName = "BeforeProcessRule" Then
			NewRow.BeforeProcess = deElementValue(ExchangeRules, StringType);
			HandlerName = "DCP_[DERName]_BeforeProcessRule";
			NewRow.BeforeProcessHandlerName = StrReplace(HandlerName, "[DERName]", NewRow.Name);
			
		ElsIf NodeName = "AfterProcessRule" Then
			NewRow.AfterProcess = deElementValue(ExchangeRules, StringType);
			HandlerName = "DCP_[DERName]_AfterProcessRule";
			NewRow.AfterProcessHandlerName = StrReplace(HandlerName, "[DERName]", NewRow.Name);
			
		ElsIf NodeName = "BeforeDeleteObject" Then
			NewRow.BeforeDelete = deElementValue(ExchangeRules, StringType);
			HandlerName = "DCP_[DERName]_BeforeDeleteObject";
			NewRow.BeforeDeleteHandlerName = StrReplace(HandlerName, "[DERName]", NewRow.Name);
			
			// Exit
		ElsIf (NodeName = "Rule") And (ExchangeRules.NodeType = XMLNodeTypeEndElement) Then
			Break;
			
		EndIf;
		
	EndDo;
	
	
	If IsBlankString(NewRow.Description) Then
		NewRow.Description = NewRow.Name;
	EndIf; 
	
EndProcedure

// Imports data clearing rules.
//
// Parameters:
//  ExchangeRules - XMLReader.
//  XMLWriter     - XMLWriter - rules to be saved to the exchange file to be used
//                  during the data import.
// 
Procedure ImportClearingRules(ExchangeRules, XMLWriter)
	
	ClearingRuleTable.Rows.Clear();
	VTRows = ClearingRuleTable.Rows;
	
	XMLWriter.WriteStartElement("DataClearingRules");
	
	While ExchangeRules.Read() Do
		
		NodeType = ExchangeRules.NodeType;
		
		If NodeType = XMLNodeTypeStartElement Then
			NodeName = ExchangeRules.LocalName;
			If ExchangeMode <> "Import" Then
				XMLWriter.WriteStartElement(ExchangeRules.Name);
				While ExchangeRules.ReadAttribute() Do
					XMLWriter.WriteAttribute(ExchangeRules.Name, ExchangeRules.Value);
				EndDo;
			Else
				If NodeName = "Rule" Then
					VTRow = VTRows.Add();
					ImportDCR(ExchangeRules, VTRow);
				ElsIf NodeName = "Group" Then
					VTRow = VTRows.Add();
					ImportDCRGroup(ExchangeRules, VTRow);
				EndIf;
			EndIf;
		ElsIf NodeType = XMLNodeTypeEndElement Then
			NodeName = ExchangeRules.LocalName;
			If NodeName = "DataClearingRules" Then
				Break;
			Else
				If ExchangeMode <> "Import" Then
					XMLWriter.WriteEndElement();
				EndIf;
			EndIf;
		ElsIf NodeType = XMLNodeTypeText Then
			If ExchangeMode <> "Import" Then
				XMLWriter.WriteText(ExchangeRules.Value);
			EndIf;
		EndIf; 
	EndDo;
	
	VTRows.Sort("Order", True);
	
	XMLWriter.WriteEndElement();
	
EndProcedure

// Imports the algorithm according to the format of exchange rules.
//
// Parameters:
//  ExchangeRules - XMLReader.
//  XMLWriter     - XMLWriter - rules to be saved to the exchange file to be used
//                  during the data import.
// 
Procedure ImportAlgorithm(ExchangeRules, XMLWriter)
	
	UsedOnImport = deAttribute(ExchangeRules, BooleanType, "UsedOnImport");
	Name         = deAttribute(ExchangeRules, StringType, "Name");
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If NodeName = "Text" Then
			Text = deElementValue(ExchangeRules, StringType);
		ElsIf (NodeName = "Algorithm") And (ExchangeRules.NodeType = XMLNodeTypeEndElement) Then
			Break;
		Else
			deSkip(ExchangeRules);
		EndIf;
		
	EndDo;
	
	
	If UsedOnImport Then
		If ExchangeMode = "Import" Then
			Algorithms.Insert(Name, Text);
		Else
			XMLWriter.WriteStartElement("Algorithm");
			SetAttribute(XMLWriter, "UsedOnImport", True);
			SetAttribute(XMLWriter, "Name", Name);
			deWriteElement(XMLWriter, "Text", Text);
			XMLWriter.WriteEndElement();
		EndIf;
	Else
		If ExchangeMode <> "Import" Then
			Algorithms.Insert(Name, Text);
		EndIf;
	EndIf;
	
	
EndProcedure 

// Imports algorithms according to the format of exchange rules.
//
// Parameters:
//  ExchangeRules - XMLReader.
//  XMLWriter     - XMLWriter - rules to be saved to the exchange file to be used
//                  during the data import.
// 
Procedure ImportAlgorithms(ExchangeRules, XMLWriter)
	
	Algorithms.Clear();
	
	XMLWriter.WriteStartElement("Algorithms");
	
	While ExchangeRules.Read() Do
		NodeName = ExchangeRules.LocalName;
		If NodeName = "Algorithm" Then
			ImportAlgorithm(ExchangeRules, XMLWriter);
		ElsIf (NodeName = "Algorithms") And (ExchangeRules.NodeType = XMLNodeTypeEndElement) Then
			Break;
		EndIf;
		
	EndDo;
	
	XMLWriter.WriteEndElement();
	
EndProcedure 

// Imports the query according to the format of exchange rules.
//
// Parameters:
//  ExchangeRules - XMLReader.
//  XMLWriter     - XMLWriter - rules to be saved to the exchange file to be used
//                  during the data import.
// 
Procedure ImportQuery(ExchangeRules, XMLWriter)
	
	UsedOnImport = deAttribute(ExchangeRules, BooleanType, "UsedOnImport");
	Name         = deAttribute(ExchangeRules, StringType, "Name");
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If NodeName = "Text" Then
			Text = deElementValue(ExchangeRules, StringType);
		ElsIf (NodeName = "Query") And (ExchangeRules.NodeType = XMLNodeTypeEndElement) Then
			Break;
		Else
			deSkip(ExchangeRules);
		EndIf;
		
	EndDo;
	
	If UsedOnImport Then
		If ExchangeMode = "Import" Then
			Query = New Query(Text);
			Queries.Insert(Name, Query);
		Else
			XMLWriter.WriteStartElement("Query");
			SetAttribute(XMLWriter, "UsedOnImport", True);
			SetAttribute(XMLWriter, "Name", Name);
			deWriteElement(XMLWriter, "Text", Text);
			XMLWriter.WriteEndElement();
		EndIf;
	Else
		If ExchangeMode <> "Import" Then
			Query = New Query(Text);
			Queries.Insert(Name, Query);
		EndIf;
	EndIf;
	
EndProcedure 

// Imports queries according to the format of exchange rules.
//
// Parameters:
//  ExchangeRules - XMLReader.
//  XMLWriter     - XMLWriter - rules to be saved to the exchange file to be used 
//                  during the data import.
// 
Procedure ImportQueries(ExchangeRules, XMLWriter)
	
	Queries.Clear();
	
	XMLWriter.WriteStartElement("Queries");
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If NodeName = "Query" Then
			ImportQuery(ExchangeRules, XMLWriter);
		ElsIf (NodeName = "Queries") And (ExchangeRules.NodeType = XMLNodeTypeEndElement) Then
			Break;
		EndIf;
		
	EndDo;
	
	XMLWriter.WriteEndElement();
	
EndProcedure 

// Imports parameters according to the format of exchange rules.
//
// Parameters:
//  ExchangeRules - XMLReader.
// 
Procedure ImportParameters(ExchangeRules, XMLWriter)
	
	Parameters.Clear();
	EventsAfterParameterImport.Clear();
	ParameterSetupTable.Clear();
	
	XMLWriter.WriteStartElement("Parameters");
	
	While ExchangeRules.Read() Do
		NodeName = ExchangeRules.LocalName;
		NodeType = ExchangeRules.NodeType;
		
		If NodeName = "Parameter" And NodeType = XMLNodeTypeStartElement Then
			
			//Importing by the 2.01 rule version
			Name                          = deAttribute(ExchangeRules, StringType, "Name");
			Description                   = deAttribute(ExchangeRules, StringType, "Description");
			SetInDialog                   = deAttribute(ExchangeRules, BooleanType, "SetInDialog");
			ValueTypeString               = deAttribute(ExchangeRules, StringType, "ValueType");
			UsedOnImport                  = deAttribute(ExchangeRules, BooleanType, "UsedOnImport");
			PassParameterOnExport         = deAttribute(ExchangeRules, BooleanType, "PassParameterOnExport");
			ConversionRule                = deAttribute(ExchangeRules, StringType, "ConversionRule");
			AfterParameterImportAlgorithm = deAttribute(ExchangeRules, StringType, "AfterParameterImport");
			
			If Not IsBlankString(AfterParameterImportAlgorithm) Then
				
				EventsAfterParameterImport.Insert(Name, AfterParameterImportAlgorithm);
				
			EndIf;
			
			// Determining value types and setting initial values
			If Not IsBlankString(ValueTypeString) Then
				
				Try
					DataValueType = Type(ValueTypeString);
					TypeDefined = True;
				Except
					TypeDefined = False;
				EndTry;
				
			Else
				
				TypeDefined = False;
				
			EndIf;
			
			If TypeDefined Then
				ParameterValue = deGetEmptyValue(DataValueType);
				Parameters.Insert(Name, ParameterValue);
			Else
				ParameterValue = "";
				Parameters.Insert(Name);
			EndIf;
			
			If SetInDialog = True Then
				
				TableRow                       = ParameterSetupTable.Add();
				TableRow.Description           = Description;
				TableRow.Name                  = Name;
				TableRow.Value                 = ParameterValue;    
				TableRow.PassParameterOnExport = PassParameterOnExport;
				TableRow.ConversionRule        = ConversionRule;
				
			EndIf;
			
			If UsedOnImport
				And ExchangeMode = "Data" Then
				
				XMLWriter.WriteStartElement("Parameter");
				SetAttribute(XMLWriter, "Name", Name);
				SetAttribute(XMLWriter, "Description", Description);
				
				If Not IsBlankString(AfterParameterImportAlgorithm) Then
					SetAttribute(XMLWriter, "AfterParameterImport", XMLString(AfterParameterImportAlgorithm));
				EndIf;
				
				XMLWriter.WriteEndElement();
				
			EndIf;
			
		ElsIf (NodeType = XMLNodeTypeText) Then
			
			// Importing from the string to provide 2.0 compatibility
			ParameterString = ExchangeRules.Value;
			For Each Param In ArrayFromString(ParameterString) Do
				Parameters.Insert(Param);
			EndDo;
			
		ElsIf (NodeName = "Parameters") And (NodeType = XMLNodeTypeEndElement) Then
			Break;
		EndIf;
		
	EndDo;
	
	XMLWriter.WriteEndElement();
	
EndProcedure 

// Imports the data processor according to the format of exchange rules.
//
// Parameters:
// ExchangeRules - XMLReader.
// XMLWriter     - XMLWriter - rules to be saved to the exchange file to be used during
//                 the data import.
// 
Procedure ImportDataProcessor(ExchangeRules, XMLWriter)
	
	Name                   = deAttribute(ExchangeRules, StringType, "Name");
	Description            = deAttribute(ExchangeRules, StringType, "Description");
	IsSetupDataProcessor   = deAttribute(ExchangeRules, BooleanType, "IsSetupDataProcessor");
	
	UsedOnExport = deAttribute(ExchangeRules, BooleanType, "UsedOnExport");
	UsedOnImport = deAttribute(ExchangeRules, BooleanType, "UsedOnImport");
	
	ParameterString        = deAttribute(ExchangeRules, StringType, "Parameters");
	
	DataProcessorStorage   = deElementValue(ExchangeRules, ValueStorageType);
	
	AdditionalDataProcessorParameters.Insert(Name, ArrayFromString(ParameterString));
	
	
	If UsedOnImport Then
		If ExchangeMode <> "Import" Then
			XMLWriter.WriteStartElement("Data processor");
			SetAttribute(XMLWriter, "UsedOnImport", True);
			SetAttribute(XMLWriter, "Name",                   Name);
			SetAttribute(XMLWriter, "Description",            Description);
			SetAttribute(XMLWriter, "IsSetupDataProcessor",   IsSetupDataProcessor);
			XMLWriter.WriteText(XMLString(DataProcessorStorage));
			XMLWriter.WriteEndElement();
		EndIf;
	EndIf;
	
	If IsSetupDataProcessor Then
		If (ExchangeMode = "Import") And UsedOnImport Then
			ImportSetupDataProcessors.Add(Name, Description, , );
			
		ElsIf (ExchangeMode = "Data") And UsedOnExport Then
			ExportSetupDataProcessors.Add(Name, Description, , );
			
		EndIf; 
	EndIf; 
	
EndProcedure 

// Imports external data processors according to the format of exchange rules.
//
// Parameters:
// ExchangeRules - XMLReader.
// XMLWriter     - XMLWriter - rules to be saved to the exchange file to be used during
//                 the data import.
// 
Procedure ImportDataProcessors(ExchangeRules, XMLWriter)
	
	AdditionalDataProcessors.Clear();
	AdditionalDataProcessorParameters.Clear();
	
	ExportSetupDataProcessors.Clear();
	ImportSetupDataProcessors.Clear();
	
	XMLWriter.WriteStartElement("DataProcessors");
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If NodeName = "Data processor" Then
			ImportDataProcessor(ExchangeRules, XMLWriter);
		ElsIf (NodeName = "DataProcessors") And (ExchangeRules.NodeType = XMLNodeTypeEndElement) Then
			Break;
		EndIf;
		
	EndDo;
	
	XMLWriter.WriteEndElement();
	
EndProcedure 

// Imports the data export rule group according to the format of exchange rules.
//
// Parameters:
// ExchangeRules - XMLReader.
// NewRow        - value tree row that describes the data export rule group.
//
Procedure ImportDER(ExchangeRules)
	
	NewRow = ExportRuleTable.Add();
	
	NewRow.Enable = Not deAttribute(ExchangeRules, BooleanType, "Disable");
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		If NodeName = "Code" Then
			
			NewRow.Name = deElementValue(ExchangeRules, StringType);
			
		ElsIf NodeName = "Description" Then
			
			NewRow.Description = deElementValue(ExchangeRules, StringType);
			
		ElsIf NodeName = "Order" Then
			
			NewRow.order = deElementValue(ExchangeRules, NumberType);
			
		ElsIf NodeName = "DataSelectionVariant" Then
			
			NewRow.DataSelectionVariant = deElementValue(ExchangeRules, StringType);
			
		ElsIf NodeName = "SelectExportDataInSingleQuery" Then
			
			// Skipping the parameter during the online data exchange
			deSkip(ExchangeRules);
			
		ElsIf NodeName = "DontExportCreatedInTargetInfobaseObjects" Then
			
			NewRow.DontExportCreatedInTargetInfobaseObjects = deElementValue(ExchangeRules, BooleanType);
			
		ElsIf NodeName = "RecipientTypeName" Then
			
			NewRow.RecipientTypeName = deElementValue(ExchangeRules, StringType);
			
		ElsIf NodeName = "SelectionObject" Then
			
			SelectionObject = deElementValue(ExchangeRules, StringType);
			
			If Not ExchangeRuleInfoImportMode Then
				
				NewRow.SynchronizeByID = SynchronizeByDERID(NewRow.ConversionRule);
				
				If Not IsBlankString(SelectionObject) Then
					
					NewRow.SelectionObject        = Type(SelectionObject);
					
				EndIf;
				
				// For filtering using the query builder
				If Find(SelectionObject, "Ref.") Then
					NewRow.ObjectForQueryName = StrReplace(SelectionObject, "Ref.", ".");
				Else
					NewRow.ObjectNameForRegisterQuery = StrReplace(SelectionObject, "Record.", ".");
				EndIf;
				
			EndIf;
			
		ElsIf NodeName = "ConversionRuleCode" Then
			
			NewRow.ConversionRule = deElementValue(ExchangeRules, StringType);
			
			// Event handlers
			
		ElsIf NodeName = "BeforeProcessRule" Then
			NewRow.BeforeProcess = deElementValue(ExchangeRules, StringType);   
			HandlerName = "DER_[DERName]_BeforeProcessRule";
			NewRow.BeforeProcessHandlerName = StrReplace(HandlerName, "[DERName]", NewRow.Name);
			
		ElsIf NodeName = "AfterProcessRule" Then
			NewRow.AfterProcess = deElementValue(ExchangeRules, StringType);
			HandlerName = "DER_[DERName]_AfterProcessRule";
			NewRow.AfterProcessHandlerName = StrReplace(HandlerName, "[DERName]", NewRow.Name);
			
		ElsIf NodeName = "BeforeExportObject" Then
			NewRow.BeforeExport = deElementValue(ExchangeRules, StringType);
			HandlerName = "DER_[DERName]_BeforeExportObject";
			NewRow.BeforeExportHandlerName = StrReplace(HandlerName, "[DERName]", NewRow.Name);
			
		ElsIf NodeName = "AfterExportObject" Then
			NewRow.AfterExport = deElementValue(ExchangeRules, StringType);
			HandlerName = "DER_[DERName]_AfterExportObject";
			NewRow.AfterExportHandlerName = StrReplace(HandlerName, "[DERName]", NewRow.Name);
			
		ElsIf (NodeName = "Rule") And (ExchangeRules.NodeType = XMLNodeTypeEndElement) Then
			Break;
		EndIf;
		
	EndDo;
	
	If IsBlankString(NewRow.Description) Then
		NewRow.Description = NewRow.Name;
	EndIf;
	
EndProcedure

// Imports the data export rules according to the format of exchange rules.
//
// Parameters:
// ExchangeRules - XMLReader.
// 
Procedure ImportExportRules(ExchangeRules)
	
	ExportRuleTable.Clear();
	
	SettingRow = Undefined;
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If NodeName = "Rule" Then
			
			ImportDER(ExchangeRules);
			
		ElsIf (NodeName = "DataExportRules") And (ExchangeRules.NodeType = XMLNodeTypeEndElement) Then
			
			Break;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Function SynchronizeByDERID(Val OCRName)
	
	OCR = FindRule(Undefined, OCRName);
	
	If OCR <> Undefined Then
		
		Return (OCR.SynchronizeByID = True);
		
	EndIf;
	
	Return False;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE AND FUNCTION FOR WORKING WITH EXCHANGE RULES

// Implements a conversion rule search by name or according to the passed object type.
//
// Parameters:
//  Object   - source object whose conversion rule is searched.
//  RuleName - conversion rule name.
//
// Returns:
//  Conversion rule reference (rule table row).
//
Function FindRule(Object, RuleName="")
	
	If Not IsBlankString(RuleName) Then
		
		Rule = Rules[RuleName];
		
	Else
		
		Rule = Managers[TypeOf(Object)];
		If Rule <> Undefined Then
			Rule    = Rule.OCR;
			
			If Rule <> Undefined Then 
				RuleName = Rule.Name;
			EndIf;
			
		EndIf; 
		
	EndIf;
	
	Return Rule; 
	
EndFunction

// Restores rules from the internal format.
//
Procedure RestoreRulesFromInternalFormat() Export 
	
	
	If SavedSettings = Undefined Then
		Return;
	EndIf;
	
	RuleStructure = SavedSettings.Get();
	// Checking storage format version of exchange rules
	
	RuleStorageFormatVersion = Undefined;
	RuleStructure.Property("RuleStorageFormatVersion", RuleStorageFormatVersion);
	If RuleStorageFormatVersion <> ExchangeRuleStorageFormatVersion() Then
		Raise NStr("en = 'Storage format version of exchange rules does not match expected version.
		|Reload exchange rules.'"
		);
	EndIf;
	
	Conversion             = RuleStructure.Conversion;
	
	ExportRuleTable        = RuleStructure.ExportRuleTable;
	ConversionRuleTable    = RuleStructure.ConversionRuleTable;
	ParameterSetupTable     = RuleStructure.ParameterSetupTable;
	
	Algorithms             = RuleStructure.Algorithms;
	QueriesToRestore       = RuleStructure.Queries;
	Parameters             = RuleStructure.Parameters;
	
	XMLRules               = RuleStructure.XMLRules;
	TypesForTargetString   = RuleStructure.TypesForTargetString;
	
	HasBeforeExportObjectGlobalHandler  = Not IsBlankString(Conversion.BeforeExportObject);
	HasAfterExportObjectGlobalHandler   = Not IsBlankString(Conversion.AfterExportObject);
	HasBeforeImportObjectGlobalHandler  = Not IsBlankString(Conversion.BeforeImportObject);
	HasAfterImportObjectGlobalHandler   = Not IsBlankString(Conversion.AfterImportObject);
	HasBeforeConvertObjectGlobalHandler = Not IsBlankString(Conversion.BeforeObjectConversion);
	
	// Restoring queries
	Queries.Clear();
	For Each StructureItem In QueriesToRestore Do
		Query = New Query(StructureItem.Value);
		Queries.Insert(StructureItem.Key, Query);
	EndDo;
	
	InitManagersAndMessages();
	
	Rules.Clear();
	
	For Each TableRow In ConversionRuleTable Do
		
		If ExchangeMode = "Data" Then
			
			GetPredefinedDataValues(TableRow);
			
		EndIf;
		
		Rules.Insert(TableRow.Name, TableRow);
		
		If ExchangeMode = "Data" And TableRow.Source <> Undefined Then
			
			Try
				If TypeOf(TableRow.Source) = StringType Then
					Managers[Type(TableRow.Source)].OCR = TableRow;
				Else
					Managers[TableRow.Source].OCR = TableRow;
				EndIf;   
			Except
				WriteErrorInfoToLog(11, ErrorDescription(), String(TableRow.Source));
			EndTry;
			
		EndIf;
		
	EndDo;
	
	
EndProcedure

// Sets parameter values in the Parameters structure according to the ParameterSetupTable table.
//
Procedure SetParametersFromDialog() Export
	
	For Each TableRow In ParameterSetupTable Do
		Parameters.Insert(TableRow.Name, TableRow.Value);
	EndDo;
	
EndProcedure

Procedure SetParameterValueInTable(ParameterName, ParameterValue)
	
	TableRow = ParameterSetupTable.Find(ParameterName, "Name");
	
	If TableRow <> Undefined Then
		
		TableRow.Value = ParameterValue; 
		
	EndIf;
	
EndProcedure

Procedure InitializeInitialParameterValues()
	
	For Each CurParameter In Parameters Do
		
		SetParameterValueInTable(CurParameter.Key, CurParameter.Value);
		
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// CLEARING RULE PROCESSING

Procedure DeleteObject(Object, DeleteDirectly, TypeName = "")
	
	Try
		
		Predefined = Object.Predefined;
		
	Except
		
		Predefined = False;
		
	EndTry;
	
	If Predefined Then
		
		Return;
		
	EndIf;
	
	If DeleteDirectly Then
		
		Object.Delete();
		
	Else
		
		SetObjectDeletionMark(Object, True, TypeName);
		
	EndIf;
	
EndProcedure

Procedure ExecuteObjectDeletion(Object, Properties, DeleteDirectly)
	
	If Properties.TypeName = "InformationRegister" Then
		
		Object.Delete();
		
	Else
		
		DeleteObject(Object, DeleteDirectly, Properties.TypeName);  
		
	EndIf; 
	
EndProcedure

// Deletes (or sets the deletion mark) the selection object according to the specified rule.
//
// Parameters:
//  Object       - selection object to be deleted (or whose deletion mark will be set).
//  Rule         - data clearing rule reference.
//  Properties   - metadata object properties of the object to be deleted.
//  IncomingData - arbitrary auxiliary data.
// 
Procedure SelectionObjectDeletion(Object, Rule, Properties=Undefined, IncomingData=Undefined)
	
	Cancel       = False;
	DeleteDirectly = Rule.Directly;
	
	
	// BeforeSelectionObjectDeletion handler
	
	If Not IsBlankString(Rule.BeforeDelete) Then
		
		Try
			
			
			If SL20CompatibilityMode() Then
				
				Execute(Rule.BeforeDelete);
				
			Else
				
				ExecuteHandler_DCP_BeforeDeleteObject(Rule, Object, Cancel, DeleteDirectly, IncomingData);
				
			EndIf;
			
		Except
			
			WriteDataClearingHandlerErrorInfo(29, ErrorDescription(), Rule.Name, Object, "BeforeSelectionObjectDeletion");
			
		EndTry;
		
		If Cancel Then
			
			Return;
			
		EndIf;
		
	EndIf;
	
	Try
		
		ExecuteObjectDeletion(Object, Properties, DeleteDirectly);
		
	Except
		
		WriteDataClearingHandlerErrorInfo(24, ErrorDescription(), Rule.Name, Object, "");
		
	EndTry;
	
EndProcedure

// Clears data by the specified rule.
//
// Parameters:
//  Rule - data clearing rule reference.
// 
Procedure ClearDataByRule(Rule)
	
	// BeforeProcess handler
	
	Cancel   = False;
	DataSelection = Undefined;
	
	OutgoingData = Undefined;
	
	
	// BeforeProcessClearingRule handler
	If Not IsBlankString(Rule.BeforeProcess) Then
		
		Try
			
			
			If SL20CompatibilityMode() Then
				
				Execute(Rule.BeforeProcess);
				
			Else
				
				ExecuteHandler_DCP_BeforeProcessRule(Rule, Cancel, OutgoingData, DataSelection);
				
			EndIf;
			
		Except
			
			WriteDataClearingHandlerErrorInfo(27, ErrorDescription(), Rule.Name, "", "BeforeProcessClearingRule");
			
		EndTry;
		
		If Cancel Then
			
			Return;
			
		EndIf; 
		
	EndIf;
	
	
	// Standard selection
	
	Try
		Properties = Managers[Rule.SelectionObject];
	Except
		Properties = Undefined;
	EndTry;
	
	If Rule.DataSelectionVariant = "StandardSelection" Then
		
		TypeName  = Properties.TypeName;
		
		If TypeName = "AccountingRegister" 
			Or TypeName = "Constants" Then
			
			Return;
			
		EndIf;
		
		AllFieldsRequired  = Not IsBlankString(Rule.BeforeDelete);
		
		Selection = GetSelectionForDataClearingExport(Properties, TypeName, True, Rule.Directly, AllFieldsRequired);
		
		While Selection.Next() Do
			
			If TypeName =  "InformationRegister" Then
				
				RecordManager = Properties.Manager.CreateRecordManager(); 
				FillPropertyValues(RecordManager, Selection);
				
				SelectionObjectDeletion(RecordManager, Rule, Properties, OutgoingData);    
				
			Else
				
				SelectionObjectDeletion(Selection.Ref.GetObject(), Rule, Properties, OutgoingData);
				
			EndIf;
			
		EndDo;  
		
	ElsIf Rule.DataSelectionVariant = "ArbitraryAlgorithm" Then
		
		If DataSelection <> Undefined Then
			
			Selection = GetExportWithArbitraryAlgorithmSelection(DataSelection);
			
			If Selection <> Undefined Then
				
				While Selection.Next() Do
					
					If TypeName =  "InformationRegister" Then
						
						RecordManager = Properties.Manager.CreateRecordManager(); 
						FillPropertyValues(RecordManager, Selection);
						
						SelectionObjectDeletion(RecordManager, Rule, Properties, OutgoingData);    
						
					Else
						
						SelectionObjectDeletion(Selection.Ref.GetObject(), Rule, Properties, OutgoingData);
						
					EndIf;     
					
				EndDo; 
				
			Else
				
				For Each Object In DataSelection Do
					
					SelectionObjectDeletion(Object.GetObject(), Rule, Properties, OutgoingData);
					
				EndDo;
				
			EndIf;
			
		EndIf; 
		
	EndIf; 
	
	
	// AfterProcessClearingRule handler
	
	If Not IsBlankString(Rule.AfterProcess) Then
		
		Try
			
			
			If SL20CompatibilityMode() Then
				
				Execute(Rule.AfterProcess);
				
			Else
				
				ExecuteHandler_DCP_AfterProcessRule(Rule);
				
			EndIf;
			
		Except
			
			WriteDataClearingHandlerErrorInfo(28, ErrorDescription(), Rule.Name, "", "AfterProcessClearingRule");
			
		EndTry;
		
	EndIf; 
	
EndProcedure

// Goes over the data clearing rule tree and performs cleaning.
//
// Parameters:
//  Rows - value tree row collection.
// 
Procedure ProcessClearingRules(Rows)
	
	For Each ClearingRule In Rows Do
		
		If ClearingRule.Enable = 0 Then
			
			Continue;
			
		EndIf; 
		
		If ClearingRule.IsFolder Then
			
			ProcessClearingRules(ClearingRule.Rows);
			Continue;
			
		EndIf;
		
		ClearDataByRule(ClearingRule);
		
	EndDo; 
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// PROCEDURES FOR IMPORTING DATA

Procedure StartReadMessage(MessageReader, DataAnalysis = False)
	
	If IsBlankString(ExchangeFileName) Then
		Raise WriteToExecutionLog(15);
	EndIf;
	
	ExchangeFile = New XMLReader;
	
	ExchangeFile.OpenFile(ExchangeFileName);
	
	ExchangeFile.Read(); // ExchangeFile
	
	
	If ExchangeFile.NodeType <> XMLNodeType.StartElement Then
		Raise NStr("en = 'Exchange messages format error.'");
	EndIf;
	
	If ExchangeFile.LocalName <> "ExchangeFile" Then
		Raise NStr("en = 'Exchange messages format error.'");
		
	EndIf;
	
	IncomingExchangeMessageFormatVersionField = deAttribute(ExchangeFile, StringType, "FormatVersion");
	
	RecipientConfigurationVersion = "";
	Conversion.Property("RecipientConfigurationVersion", RecipientConfigurationVersion);
	SourceVersionFromRules = deAttribute(ExchangeFile, StringType, "SourceConfigurationVersion");
	MessageText = "";
	
	If DataExchangeServer.DifferentCorrespondentVersions(ExchangePlanName(), EventLogMessageKey(),
		RecipientConfigurationVersion, SourceVersionFromRules, MessageText) Then
		
		Raise MessageText;
		
		
	EndIf;
	
	ExchangeFile.Read(); // ExchangeRules
	
	
	If ExchangeFile.NodeType <> XMLNodeType.StartElement Then
		Raise NStr("en = 'Exchange messages format error.'");
	EndIf;
	
	If ExchangeFile.LocalName <> "ExchangeRules" Then
		Raise NStr("en = 'Exchange messages format error.'");
	EndIf;
	
	
	If ConversionRuleTable.Count() = 0 Then
		ImportExchangeRules(ExchangeFile, "XMLReader");
		If ErrorFlag() Then
			Raise NStr("en = 'Error during import of data exchange rules.'");
		EndIf;
	Else
		deSkip(ExchangeFile);
	EndIf;
	
	// {Handler: BeforeDataImport} Start
	
	If Not IsBlankString(Conversion.BeforeDataImport) Then
		
		Cancel = False;
		
		Try
			
			If SL20CompatibilityMode() Then
				
				Execute(Conversion.BeforeDataImport);
				
			Else
				
				ExecuteHandler_Conversion_BeforeDataImport(ExchangeFile, Cancel);
				
			EndIf;
			
		Except
			
			Raise WriteErrorInfoConversionHandlers(22, ErrorDescription(), NStr("en = 'BeforeDataImport (conversion)'"));
		EndTry;
		
		
		If Cancel Then
			Raise NStr("en = 'Canceling exchange message import in the BeforeDataImport handler (conversion).'");
		EndIf;
		
		
	EndIf;
	// {Handler: BeforeDataImport} End
	
	ExchangeFile.Read();
	
	If ExchangeFile.NodeType <> XMLNodeType.StartElement Then
		Raise NStr("en = 'Exchange messages format error.'");
	EndIf;
	
	
	// CustomSearchSetup (optional)
	If ExchangeFile.LocalName = "CustomSearchSetup" Then
		ImportCustomSearchFieldInfo();
		ExchangeFile.Read();
	EndIf;
	
	// DataTypeInfo (optional)
	If ExchangeFile.LocalName = "DataTypeInfo" Then
		
		If ExchangeFile.NodeType <> XMLNodeType.StartElement Then
			Raise NStr("en = 'Exchange messages format error.'");
		EndIf;
		
		
		If DataForImportTypeMap().Count() > 0 Then
			deSkip(ExchangeFile);
		Else
			
			ImportDataTypeInfo();
			If ErrorFlag() Then
				Raise NStr("en = 'Errors occurred during import information about the data types.'");
			EndIf;
		EndIf;
		ExchangeFile.Read();
	EndIf;
	
	// ParameterValue (optional) (several)
	If ExchangeFile.LocalName = "ParameterValue" Then
		
		If ExchangeFile.NodeType <> XMLNodeType.StartElement Then
			Raise NStr("en = 'Exchange messages format error.'");
		EndIf;
		
		
		ImportDataExchangeParameterValues();
		
		While ExchangeFile.Read() Do
			
			If ExchangeFile.LocalName = "ParameterValue" Then
				
				If ExchangeFile.NodeType <> XMLNodeType.StartElement Then
					Raise NStr("en = 'Exchange messages format error.'");
				EndIf;
				
				ImportDataExchangeParameterValues();
			Else
				Break;
			EndIf;
			
		EndDo;
		
	EndIf;
	
	
	// AfterParameterExportAlgorithm (optional)
	If ExchangeFile.LocalName = "AfterParameterExportAlgorithm" Then
		
		If ExchangeFile.NodeType <> XMLNodeType.StartElement Then
			Raise NStr("en = 'Exchange messages format error.'");
		EndIf;
		
		ExecuteAlgorithmAfterParameterImport(deElementValue(ExchangeFile, StringType));
		ExchangeFile.Read();
	EndIf;
	
	// ExchangeData (mandatory)
	If ExchangeFile.NodeType <> XMLNodeType.StartElement Then
		Raise NStr("en = 'Exchange messages format error.'");
	EndIf;
	
	
	If ExchangeFile.LocalName <> "ExchangeData" Then
		Raise NStr("en = 'Exchange messages format error.'");
	EndIf;
	
	ReadDataViaExchange(MessageReader, DataAnalysis);
	ExchangeFile.Read();
	
	If TransactionActive() Then
		
		Raise NStr("en = 'Data lock cannot be set in an active transaction.'");
	EndIf;
	
	// Setting the sender node lock
	Try
		LockDataForEdit(MessageReader.Sender);
	Except
		
		Raise StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = 'Error setting lock on data exchange.
		|Data exchange is executed in another session.
		|
		|Details:
		|%1'"),
		BriefErrorDescription(ErrorInfo())
		);
	EndTry;
	
EndProcedure

Procedure FinishMessageReader(Val MessageReader)
	
	// {Handler: AfterDataImport} Start
	If Not IsBlankString(Conversion.AfterDataImport) Then
		
		Try
			
			If SL20CompatibilityMode() Then
				
				Execute(Conversion.AfterDataImport);
				
			Else
				
				ExecuteHandler_Conversion_AfterDataImport();
				
			EndIf;
			
		Except
			Raise WriteErrorInfoConversionHandlers(23, ErrorDescription(), NStr("en = 'AfterDataImport (conversion)'"));
		EndTry;
		
	EndIf;
	// {Handler: AfterDataImport} End
	
	If ExchangeFile.NodeType <> XMLNodeType.EndElement Then
		Raise NStr("en = 'Exchange messages format error.'");
	EndIf;
	
	If ExchangeFile.LocalName <> "ExchangeFile" Then
		Raise NStr("en = 'Exchange messages format error.'");
	EndIf;
	
	
	ExchangeFile.Read(); // ExchangeFile
	ExchangeFile.Close();
	
	BeginTransaction();
	If Not MessageReader.DataAnalysis Then
		MessageReader.SenderObject.ReceivedNo = MessageReader.MessageNo;
		MessageReader.SenderObject.AdditionalProperties.Insert("Import");
		MessageReader.SenderObject.Write();
	EndIf;
	
	If HasObjectChangeRecordDataAdjustment = True Then
		InformationRegisters.CommonInfobaseNodeSettings.CommitMappingInfoAdjustmentUnconditionally(ExchangeNodeDataImport);
	EndIf;
	
	If HasObjectChangeRecordData = True Then
		InformationRegisters.InfobaseObjectMappings.DeleteObsoleteExportByRefModeRecords(ExchangeNodeDataImport);
	EndIf;
	CommitTransaction();
	
	UnlockDataForEdit(MessageReader.Sender);
	
EndProcedure

Procedure BreakMessageReader(Val MessageReader)
	
	ExchangeFile.Close();
	
	UnlockDataForEdit(MessageReader.Sender);
	
EndProcedure

Procedure ExecuteAlgorithmAfterParameterImport(Val AlgorithmText)
	
	If IsBlankString(AlgorithmText) Then
		Return;
	EndIf;
	
	Cancel = False;
	CancelReason = "";
	
	Try
		
		If SL20CompatibilityMode() Then
			
			Execute(AlgorithmText);
			
		Else
			
			ExecuteHandler_Conversion_AfterParameterImport(ExchangeFile, Cancel, CancelReason);
			
		EndIf;
		
		If Cancel = True Then
			
			If Not IsBlankString(CancelReason) Then
				
				MessageString = NStr("en = 'Canceling exchange message import in the AfterParameterImport handler (conversion) for the following reason: %1'");
				MessageString = 
				StringFunctionsClientServer.SubstituteParametersInString(MessageString, CancelReason);
				Raise MessageString;
			Else
				Raise NStr("en = 'Canceling exchange message import in the AfterParameterImport handler (conversion).'");
			EndIf;
			
		EndIf;
		
	Except
		
		LR = GetLogRecordStructure(78, ErrorDescription());
		LR.Handler     = "AfterParameterImport";
		ErrorMessageString = WriteToExecutionLog(78, LR);
		
		If Not ContinueOnError Then
			Raise ErrorMessageString;
		EndIf;
		
	EndTry;
	
EndProcedure

Function SetNewObjectRef(Object, Manager, SearchProperties)
	
	UI = SearchProperties["{UUID}"];
	
	If UI <> Undefined Then
		
		NewRef = Manager.GetRef(New UUID(UI));
		
		Object.SetNewObjectRef(NewRef);
		
		SearchProperties.Delete("{UUID}");
		
	Else
		
		NewRef = Undefined;
		
	EndIf;
	
	Return NewRef;
	
EndFunction


// Searches for the object by its number in the list of already imported objects.
//
// Parameters:
//  Sn - number in the exchange file of the object to be found.
//
// Returns:
//  Reference to the found object. If object is not found, Undefined is returned.
// 
Function FindObjectByNumber(Sn, ObjectType, MainObjectSearchMode = False)
	
	Return Undefined;
	
EndFunction

Function FindObjectByGlobalNumber(Sn, MainObjectSearchMode = False)
	
	Return Undefined;
	
EndFunction

Procedure ClearPredefinedItemDeletionMark(Object, ObjectType)
	
	Try
		DeletionMark = Object.DeletionMark;
	Except
		DeletionMark = False;
	EndTry;
	
	If DeletionMark Then
		
		Try
			Predefined = Object.Predefined;
		Except
			Predefined = False;
		EndTry;
		
		If Predefined Then
			
			Object.DeletionMark = False;
			
			// Writing the event message to the event log
			LR            = GetLogRecordStructure(80);
			LR.ObjectType = ObjectType;
			LR.Object     = String(Object);
			
			WriteToExecutionLog(80, LR, False,,,,Enums.ExchangeExecutionResults.CompletedWithWarnings);
			
		EndIf;
		
	EndIf;
	
EndProcedure

Function GetDocumentHasRegisterRecords(DocumentRef)
	QueryText = ""; 
	// Providing correct posting of documents that must be posted in more than 256 tables
	table_counter = 0;
	
	DocumentMetadata = DocumentRef.Metadata();
	
	If DocumentMetadata.RegisterRecords.Count() = 0 Then
		Return New ValueTable;
	EndIf;
	
	For Each RegisterRecord In DocumentMetadata.RegisterRecords Do
		// In query, getting the names of registers that have one or more record, 
		// for example:
		// SELECT TOP 1 "AccumulationRegister.ItemStock"
		// FROM AccumulationRegister.ItemStock
		// WHERE Recorder = &Recorder
		
		// Casting the register name to String(200), as below:
		QueryText = QueryText + "
		|" + ?(QueryText = "", "", " UNION ALL ") + "
		|SELECT TOP 1 CAST(""" + RegisterRecord.FullName() 
		+  """ AS String(200)) AS Name FROM " + RegisterRecord.FullName() 
		+ " WHERE Recorder = &Recorder";
		
		// If the query selection contains more than 256 tables, splitting it into two
		// parts. Documents posted in more than 512 tables are not supported.
		table_counter = table_counter + 1;
		If table_counter = 256 Then
			Break;
		EndIf;
		
	EndDo;
	
	Query = New Query(QueryText);
	Query.SetParameter("Recorder", DocumentRef);
	// The type is specified by the longest string from the query.
	// Casting the result to String(200) to prevent possible data loss.
	QueryTable = Query.Execute().Unload();
	
	// Returning table if the number of tables does not exceed 256.
	If table_counter = DocumentMetadata.RegisterRecords.Count() Then
		Return QueryTable;   
	EndIf;
	
	// Creating the extra query and supplementing table rows if the number of tables
	// exceeds 256.
	
	QueryText = "";
	For Each RegisterRecord In DocumentMetadata.RegisterRecords Do
		
		If table_counter > 0 Then
			table_counter = table_counter - 1;
			Continue;
		EndIf;
		
		QueryText = QueryText + "
		|" + ?(QueryText = "", "", "UNION ALL ") + "
		|SELECT TOP 1 """ + RegisterRecord.FullName() +  """ AS Name FROM " 
		+ RegisterRecord.FullName() + " WHERE Recorder = &Recorder"; 
		
		
	EndDo;
	Query.Text = QueryText;
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		TableRow = QueryTable.Add();
		FillPropertyValues(TableRow, Selection);
	EndDo;
	
	Return QueryTable;
	
EndFunction


// Deletes existed document register records during reposting (or during posting clearing).
//
Procedure DeleteDocumentRegisterRecords(DocumentObject)
	
	RecordTableRowToProcessArray = New Array();
	
	// Getting the list of registers that have records
	RegisterRecordTable = GetDocumentHasRegisterRecords(DocumentObject.Ref);
	RegisterRecordTable.Columns.Add("RecordSet");
	RegisterRecordTable.Columns.Add("ForceDelete", New TypeDescription("Boolean"));
	
	For Each RegisterRecordRow In RegisterRecordTable Do
		// passing the register name as a value retrieved with the FullName() function of
		// register metadata. 
		DotPosition = Find(RegisterRecordRow.Name, ".");
		TypeRegister = Left(RegisterRecordRow.Name, DotPosition - 1);
		RegisterName = TrimR(Mid(RegisterRecordRow.Name, DotPosition + 1));
		
		RecordTableRowToProcessArray.Add(RegisterRecordRow);
		
		If TypeRegister = "AccumulationRegister" Then
			SetMetadata = Metadata.AccumulationRegisters[RegisterName];
			Set = AccumulationRegisters[RegisterName].CreateRecordSet();
			
		ElsIf TypeRegister = "AccountingRegister" Then
			SetMetadata = Metadata.AccountingRegisters[RegisterName];
			Set = AccountingRegisters[RegisterName].CreateRecordSet();
			
		ElsIf TypeRegister = "InformationRegister" Then
			SetMetadata = Metadata.InformationRegisters[RegisterName];
			Set = InformationRegisters[RegisterName].CreateRecordSet();
			
		ElsIf TypeRegister = "CalculationRegister" Then
			SetMetadata = Metadata.CalculationRegisters[RegisterName];
			Set = CalculationRegisters[RegisterName].CreateRecordSet();
			
		EndIf;
		
		If Not AccessRight("Edit", Set.Metadata()) Then
			
			// Insufficient rights to edit the register table
			ErrorMessage = NStr("en = 'Access %1 right violation'");
			ErrorMessage = StringFunctionsClientServer.SubstituteParametersInString(ErrorMessage, RegisterRecordRow.Name);
			Raise ErrorMessage;
			Return;
		EndIf;
		
		Set.Filter.Recorder.Set(DocumentObject.Ref);
		
		// All sets will be written later, once the editing rights for all registers are checked
		RegisterRecordRow.RecordSet = Set;
		
	EndDo; 
	DataExchangeServer.IgnoreChangeProhibitionCheck();
	For Each RegisterRecordRow In RecordTableRowToProcessArray Do  
		Try
			RegisterRecordRow.RecordSet.Write();
		Except
			// Perhaps RLS or The change prohibition date subsystem applied 
			
			ErrorMessage = NStr("en = 'Operation %1 is not executed.
			|%2'");
			ErrorMessage = StringFunctionsClientServer.SubstituteParametersInString(ErrorMessage,
			RegisterRecordRow.Name, BriefErrorDescription(ErrorInfo()));
			Raise ErrorMessage;
		EndTry;
	EndDo;
	DataExchangeServer.IgnoreChangeProhibitionCheck(False);
	DocumentRegisterRecordCollectionClearing(DocumentObject);
	
	// Deleting change records from all sequences
	DeleteDocumentRecordFromSequences(DocumentObject, True);
	
EndProcedure

Procedure DeleteDocumentRecordFromSequences(DocumentObject, CheckRegisterRecords = False)
	// Getting the list of sequences where the document was registered
	If CheckRegisterRecords Then
		RecordChangeTable = GetRecordDocumentExistsInSequence(DocumentObject);
	EndIf;      
	SequenceCollection = DocumentObject.BelongingToSequences;
	For Each SequenceRecordRecordSet In SequenceCollection Do
		If (SequenceRecordRecordSet.Count() > 0)
			Or (CheckRegisterRecords And (Not RecordChangeTable.Find(SequenceRecordRecordSet.Metadata().Name,"Name") = Undefined)) Then
			SequenceRecordRecordSet.Clear();
		EndIf;
	EndDo;
EndProcedure

Function GetRecordDocumentExistsInSequence(DocumentObject)
	QueryText = ""; 
	
	For Each Sequence In DocumentObject.BelongingToSequences Do
		// In a query, getting the list of sequences where the document was registered
		QueryText = QueryText + "
		|" + ?(QueryText = "", "", "UNION ALL ") + "
		|SELECT """ + Sequence.Metadata().Name 
		+  """ AS Name FROM " + Sequence.Metadata().FullName()  
		+ " WHERE Recorder = &Recorder";
		
	EndDo;
	
	If QueryText = "" Then
		Return New ValueTable();
	Else
		Query = New Query(QueryText);
		Query.SetParameter("Recorder", DocumentObject.Ref);
		QueryTable = Query.Execute().Unload(); 
		Return QueryTable;
	EndIf;
	
EndFunction

// Clears the document register record collection.
//
Procedure DocumentRegisterRecordCollectionClearing(DocumentObject)
	
	For Each RegisterRecord In DocumentObject.RegisterRecords Do
		If RegisterRecord.Count() > 0 Then
			RegisterRecord.Clear();
		EndIf;
	EndDo;
	
EndProcedure

Procedure SetCurrentDateToAttribute(ObjectAttribute)
	
	ObjectAttribute = CurrentSessionDate();
	
EndProcedure

// Creates a new object of the specified type, sets attributes that are specified in the
// SearchProperties structure.
//
// Parameters:
//  Type             - type of the object to be generated.
//  SearchProperties - Structure - contains  object attributes to be set.
//
// Returns:
//  New infobase object.
// 
Function CreateNewObject(Type, SearchProperties, Object = Undefined, 
	WriteObjectImmediatelyAfterCreation = True, NewRef = Undefined, 
	Sn = 0, GSn = 0, Rule = Undefined, 
	ObjectParameters = Undefined, SetAllObjectSearchProperties = True)
	
	MDProperties = Managers[Type];
	TypeName     = MDProperties.TypeName;
	Manager      = MDProperties.Manager;
	DeletionMark = Undefined;
	
	If TypeName = "Catalog"
		Or TypeName = "ChartOfCharacteristicTypes" Then
		
		IsFolder = SearchProperties["IsFolder"];
		
		If IsFolder = True Then
			
			Object = Manager.CreateFolder();
			
		Else
			
			Object = Manager.CreateItem();
			
		EndIf;  
		
	ElsIf TypeName = "Document" Then
		
		Object = Manager.CreateDocument();
		
	ElsIf TypeName = "ChartOfAccounts" Then
		
		Object = Manager.CreateAccount();
		
	ElsIf TypeName = "ChartOfCalculationTypes" Then
		
		Object = Manager.CreateCalculationType();
		
	ElsIf TypeName = "InformationRegister" Then
		
		Object = Manager.CreateRecordManager();
		Return Object;
		
	ElsIf TypeName = "ExchangePlan" Then
		
		Object = Manager.CreateNode();
		
	ElsIf TypeName = "Task" Then
		
		Object = Manager.CreateTask();
		
	ElsIf TypeName = "BusinessProcess" Then
		
		Object = Manager.CreateBusinessProcess(); 
		
	ElsIf TypeName = "Enum" Then
		
		Object = MDProperties.EmptyRef; 
		Return Object;
		
	ElsIf TypeName = "BusinessProcessRoutePoint" Then
		
		Return Undefined;
		
	EndIf;
	
	NewRef = SetNewObjectRef(Object, Manager, SearchProperties);
	
	If SetAllObjectSearchProperties Then
		SetObjectSearchAttributes(Object, SearchProperties, , False, False);
	EndIf;
	
	// Checks
	If TypeName = "Document"
		Or TypeName = "Task"
		Or TypeName = "BusinessProcess" Then
		
		If Not ValueIsFilled(Object.Date) Then
			
			SetCurrentDateToAttribute(Object.Date);   
			
		EndIf;
		
	EndIf;
	
	If WriteObjectImmediatelyAfterCreation Then
		
		WriteObjectToInfobase(Object, Type);
		
	Else
		
		Return Undefined;
		
	EndIf;
	
	Return Object.Ref;
	
EndFunction

// Reads the node properties object from the file, sets the property value
//
// Parameters:
//  Type        - property value type.
//  ObjectFound - False returned to this parameter means, that the property object is
//                not found in the infobase and a new one has been created.
//
// Returns:
//  Property value.
// 
Function ReadProperty(Type, DontCreateObjectIfNotFound = False, PropertyNotFoundByRef = False, OCRName = "")
	
	Value = Undefined;
	PropertyExistence = False;
	
	While ExchangeFile.Read() Do
		
		NodeName = ExchangeFile.LocalName;
		
		If NodeName = "Value" Then
			
			SearchByProperty  = deAttribute(ExchangeFile, StringType, "Property");
			Value             = deElementValue(ExchangeFile, Type, SearchByProperty, False);
			PropertyExistence = True;
			
		ElsIf NodeName = "Ref" Then
			
			InfobaseObjectMaps = Undefined;
			CreatedObject = Undefined;
			ObjectFound = True;
			SearchBySearchFieldsIfNotFoundByID = False;
			
			Value = FindObjectByRef(Type,
			,
			, 
			ObjectFound, 
			CreatedObject, 
			DontCreateObjectIfNotFound, 
			, 
			, 
			, 
			, 
			, 
			, 
			, 
			, 
			, 
			, 
			, 
			OCRName, 
			InfobaseObjectMaps, 
			SearchBySearchFieldsIfNotFoundByID);
			
			If DontCreateObjectIfNotFound
				And Not ObjectFound Then
				
				PropertyNotFoundByRef = False;
				
			EndIf;
			
			PropertyExistence = True;
			
		ElsIf NodeName = "Sn" Then
			
			ExchangeFile.Read();
			Sn = Number(ExchangeFile.Value);
			If Sn <> 0 Then
				Value  = FindObjectByNumber(Sn, Type);
				PropertyExistence = True;
			EndIf;   
			ExchangeFile.Read();
			
		ElsIf NodeName = "GSn" Then
			
			ExchangeFile.Read();
			GSn = Number(ExchangeFile.Value);
			If GSn <> 0 Then
				Value  = FindObjectByGlobalNumber(GSn);
				PropertyExistence = True;
			EndIf;
			
			ExchangeFile.Read();
			
		ElsIf (NodeName = "Property" Or NodeName = "ParameterValue") And (ExchangeFile.NodeType = XMLNodeTypeEndElement) Then
			
			If Not PropertyExistence
				And ValueIsFilled(Type) Then
				
				Value = deGetEmptyValue(Type);
				
			EndIf;
			
			Break;
			
		ElsIf NodeName = "Expression" Then
			
			Value = Eval(deElementValue(ExchangeFile, StringType, , False));
			PropertyExistence = True;
			
		ElsIf NodeName = "Empty" Then
			
			Value = deGetEmptyValue(Type);
			PropertyExistence = True;  
			
		Else
			
			WriteToExecutionLog(9);
			Break;
			
		EndIf;
		
	EndDo;
	
	Return Value;
	
EndFunction

Procedure SetObjectSearchAttributes(FoundObject, SearchProperties, SearchPropertiesDontReplace, 
	ShouldCompareWithCurrentAttributes = True, DontReplacePropertiesNotToChange = True)
	
	For Each Property In SearchProperties Do
		
		Name  = Property.Key;
		Value = Property.Value;
		
		If DontReplacePropertiesNotToChange
			And SearchPropertiesDontReplace[Name] <> Undefined Then
			
			Continue;
			
		EndIf;
		
		If Name = "IsFolder" 
			Or Name = "{UUID}" 
			Or Name = "{PredefinedItemName}"
			Or Name = "{SourceInfobaseSearchKey}"
			Or Name = "{RecipientInfobaseSearchKey}"
			Or Name = "{TypeNameInSourceInfobase}"
			Or Name = "{TypeNameInTargetInfobase}" Then
			
			Continue;
			
		ElsIf Name = "DeletionMark" Then
			
			If Not ShouldCompareWithCurrentAttributes
				Or FoundObject.DeletionMark <> Value Then
				
				FoundObject.DeletionMark = Value;
				
			EndIf;
			
		Else
			
			// Setting attributes that are different
			
			If FoundObject[Name] <> NULL Then
				
				If Not ShouldCompareWithCurrentAttributes
					Or FoundObject[Name] <> Value Then
					
					FoundObject[Name] = Value;
					
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Function FindOrCreateObjectByProperty(PropertyStructure,
	ObjectType,
	SearchProperties,
	SearchPropertiesDontReplace,
	ObjectTypeName,
	SearchProperty,
	SearchPropertyValue,
	ObjectFound,
	CreateNewItemIfNotFound = True,
	FoundOrCreatedObject = Undefined,
	MainObjectSearchMode = False,
	NewUUIDRef = Undefined,
	Sn = 0,
	GSn = 0,
	ObjectParameters = Undefined,
	DontReplaceCreatedInTargetObject = False,
	ObjectCreatedInCurrentInfobase = Undefined)
	
	Object = deFindObjectByProperty(PropertyStructure.Manager, SearchProperty, SearchPropertyValue, 
	FoundOrCreatedObject, , , MainObjectSearchMode, PropertyStructure.SearchString);
	
	ObjectFound = Not (Object = Undefined
	Or Object.IsEmpty()); 
	
	If Not ObjectFound 
		And CreateNewItemIfNotFound Then
		
		Object = CreateNewObject(ObjectType, SearchProperties, FoundOrCreatedObject, 
		Not MainObjectSearchMode, NewUUIDRef, Sn, GSn, FindFirstRuleByPropertyStructure(PropertyStructure),
		ObjectParameters);
		
		Return Object;
		
	EndIf;
	
	
	If MainObjectSearchMode Then
		
		
		Try
			
			If Not ValueIsFilled(Object) Then
				Return Object;
			EndIf;
			
			If FoundOrCreatedObject = Undefined Then
				FoundOrCreatedObject = Object.GetObject();
			EndIf;
			
		Except
			Return Object;
		EndTry;
		
		SetObjectSearchAttributes(FoundOrCreatedObject, SearchProperties, SearchPropertiesDontReplace);
		
	EndIf;
	
	Return Object;
	
EndFunction

Function GetPropertyType()
	
	PropertyTypeString = deAttribute(ExchangeFile, StringType, "Type");
	If IsBlankString(PropertyTypeString) Then
		
		Return Undefined;
		
	EndIf;
	
	Return Type(PropertyTypeString);
	
EndFunction

Function GetPropertyTypeByAdditionalData(TypeInformation, PropertyName)
	
	PropertyType = GetPropertyType();
	
	If PropertyType = Undefined
		And TypeInformation <> Undefined Then
		
		PropertyType = TypeInformation[PropertyName];
		
	EndIf;
	
	Return PropertyType;
	
EndFunction

Procedure ReadSearchPropertiesFromFile(SearchProperties, SearchPropertiesDontReplace, TypeInformation, 
	SearchByEqualDate = False, ObjectParameters = Undefined, Val MainObjectSearchMode, ObjectMapFound, InfobaseObjectMaps)
	
	SearchByEqualDate = False;
	
	While ExchangeFile.Read() Do
		
		NodeName = ExchangeFile.LocalName;
		
		If NodeName = "Property"
			Or NodeName = "ParameterValue" Then
			
			IsParameter = (NodeName = "ParameterValue");
			
			Name = deAttribute(ExchangeFile, StringType, "Name");
			
			SourceTypeString = deAttribute(ExchangeFile, StringType, "TargetType");
			TargetTypeString = deAttribute(ExchangeFile, StringType, "SourceType");
			
			UUIDProperty = (Name = "{UUID}");
			
			If UUIDProperty Then
				
				PropertyType = StringType;
				
			ElsIf Name = "{PredefinedItemName}"
				Or Name = "{SourceInfobaseSearchKey}"
				Or Name = "{RecipientInfobaseSearchKey}"
				Or Name = "{TypeNameInSourceInfobase}"
				Or Name = "{TypeNameInTargetInfobase}" Then
				
				PropertyType = StringType;
				
			Else
				
				PropertyType = GetPropertyTypeByAdditionalData(TypeInformation, Name);
				
			EndIf;
			
			DontReplaceProperty = deAttribute(ExchangeFile, BooleanType, "DontReplace");
			
			SearchByEqualDate = SearchByEqualDate 
			Or deAttribute(ExchangeFile, BooleanType, "SearchByEqualDate");
			
			OCRName = deAttribute(ExchangeFile, StringType, "OCRName");
			
			PropertyValue = ReadProperty(PropertyType,,, OCRName);
			
			If UUIDProperty Then
				
				ReplaceUUIDIfNecessary(PropertyValue, SourceTypeString, TargetTypeString, MainObjectSearchMode, ObjectMapFound, InfobaseObjectMaps);
				
			EndIf;
			
			If (Name = "IsFolder") And (PropertyValue <> True) Then
				
				PropertyValue = False;
				
			EndIf; 
			
			If IsParameter Then
				
				
				AddParameterIfNecessary(ObjectParameters, Name, PropertyValue);
				
			Else
				
				SearchProperties[Name] = PropertyValue;
				
				If DontReplaceProperty Then
					
					SearchPropertiesDontReplace[Name] = True;
					
				EndIf;
				
			EndIf;
			
		ElsIf (NodeName = "Ref") And (ExchangeFile.NodeType = XMLNodeTypeEndElement) Then
			
			Break;
			
		Else
			
			WriteToExecutionLog(9);
			Break;
			
		EndIf;
		
	EndDo; 
	
EndProcedure

Procedure ReplaceUUIDIfNecessary(
	UUID,
	Val SourceTypeString,
	Val TargetTypeString,
	Val MainObjectSearchMode,
	ObjectMapFound = False,
	InfobaseObjectMaps = Undefined)
	
	// No replacement is performed in the mapping mode for main objects
	If MainObjectSearchMode And DataImportToValueTableMode() Then
		Return;
	EndIf;
	
	InfobaseObjectMappingQuery.SetParameter("InfobaseNode", ExchangeNodeDataImport);
	InfobaseObjectMappingQuery.SetParameter("TargetUUID", UUID);
	InfobaseObjectMappingQuery.SetParameter("TargetType", TargetTypeString);
	InfobaseObjectMappingQuery.SetParameter("SourceType", SourceTypeString);
	
	QueryResult = InfobaseObjectMappingQuery.Execute();
	
	If QueryResult.IsEmpty() Then
		
		InfobaseObjectMaps = New Structure;
		InfobaseObjectMaps.Insert("InfobaseNode", ExchangeNodeDataImport);
		InfobaseObjectMaps.Insert("TargetType", TargetTypeString);
		InfobaseObjectMaps.Insert("SourceType", SourceTypeString);
		InfobaseObjectMaps.Insert("TargetUUID", UUID);
		
		// The value is defined after the object is written.
		// Perhaps, the object will be mapped once the object is identified by search fields.
		InfobaseObjectMaps.Insert("SourceUUID", Undefined);
		
	Else
		
		Selection = QueryResult.Choose();
		Selection.Next();
		
		UUID = Selection.SourceUUIDString;
		
		ObjectMapFound = True;
		
	EndIf;
	
EndProcedure

Function UnlimitedLengthField(TypeManager, ParameterName)
	
	LongStrings = Undefined;
	If Not TypeManager.Property("LongStrings", LongStrings) Then
		
		LongStrings = New Map;
		For Each Attribute In TypeManager.MDObject.Attributes Do
			
			If Attribute.Type.ContainsType(StringType) 
				And (Attribute.Type.StringQualifiers.Length = 0) Then
				
				LongStrings.Insert(Attribute.Name, Attribute.Name); 
				
			EndIf;
			
		EndDo;
		
		TypeManager.Insert("LongStrings", LongStrings);
		
	EndIf;
	
	Return (LongStrings[ParameterName] <> Undefined);
	
EndFunction

Function IsUnlimitedLengthParameter(TypeManager, ParameterValue, ParameterName)
	
	Try
		
		If TypeOf(ParameterValue) = StringType Then
			UnlimitedLengthString = UnlimitedLengthField(TypeManager, ParameterName);
		Else
			UnlimitedLengthString = False;
		EndIf;  
		
	Except
		
		UnlimitedLengthString = False;
		
	EndTry;
	
	Return UnlimitedLengthString; 
	
EndFunction

Function FindItemUsingRequest(PropertyStructure, SearchProperties, ObjectType = Undefined, 
	TypeManager = Undefined, RealPropertyForSearchCount = Undefined)
	
	PropertyCountForSearch = ?(RealPropertyForSearchCount = Undefined, SearchProperties.Count(), RealPropertyForSearchCount);
	
	If PropertyCountForSearch = 0
		And PropertyStructure.TypeName = "Enum" Then
		
		Return PropertyStructure.EmptyRef;
		
	EndIf;
	
	QueryText = PropertyStructure.SearchString;
	
	If IsBlankString(QueryText) Then
		Return PropertyStructure.EmptyRef;
	EndIf;
	
	SearchQuery = New Query();
	
	PropertyUsedInSearchCount = 0;
	
	For Each Property In SearchProperties Do
		
		ParameterName = Property.Key;
		
		// The following parameters cannot be a search fields
		If ParameterName = "{UUID}"
			Or ParameterName = "{PredefinedItemName}" Then
			
			Continue;
			
		EndIf;
		
		ParameterValue = Property.Value;
		SearchQuery.SetParameter(ParameterName, ParameterValue);
		
		Try
			
			UnlimitedLengthString = IsUnlimitedLengthParameter(PropertyStructure, ParameterValue, ParameterName);
			
		Except
			
			UnlimitedLengthString = False;
			
		EndTry;
		
		PropertyUsedInSearchCount = PropertyUsedInSearchCount + 1;
		
		If UnlimitedLengthString Then
			
			QueryText = QueryText + ?(PropertyUsedInSearchCount > 1, " AND ", "") + ParameterName + " LIKE &" + ParameterName;
			
		Else
			
			QueryText = QueryText + ?(PropertyUsedInSearchCount > 1, " AND ", "") + ParameterName + " = &" + ParameterName;
			
		EndIf;
		
	EndDo;
	
	If PropertyUsedInSearchCount = 0 Then
		Return Undefined;
	EndIf;
	
	SearchQuery.Text = QueryText;
	Result = SearchQuery.Execute();
	
	If Result.IsEmpty() Then
		
		Return Undefined;
		
	Else
		
		// return first the found object
		Selection = Result.Select();
		Selection.Next();
		ObjectRef = Selection.Ref;
		
	EndIf;
	
	Return ObjectRef;
	
EndFunction

// Retrieves the object conversion rule (OCR) by the target object type. 
// 
// Parameters:
//  RefTypeString - String - object type string, for example, "CatalogRef.ProductsAndServices".
// 
// Returns:
//  MapValue - object conversion rule.
//
Function GetConversionRuleWithSearchAlgorithmByTargetObjectType(RefTypeString)
	
	MapValue = ConversionRulesMap.Get(RefTypeString);
	
	If MapValue <> Undefined Then
		Return MapValue;
	EndIf;
	
	Try
		
		For Each Item In Rules Do
			
			If Item.Value.Target = RefTypeString Then
				
				If Item.Value.HasSearchFieldSequenceHandler = True Then
					
					Rule = Item.Value;
					
					ConversionRulesMap.Insert(RefTypeString, Rule);
					
					Return Rule;
					
				EndIf;
				
			EndIf;
			
		EndDo;
		
		ConversionRulesMap.Insert(RefTypeString, Undefined);
		Return Undefined;
		
	Except
		
		ConversionRulesMap.Insert(RefTypeString, Undefined);
		Return Undefined;
		
	EndTry;
	
EndFunction

Function FindDocumentRef(SearchProperties, PropertyStructure, RealPropertyForSearchCount, SearchWithQuery, SearchByEqualDate)
	
	// Attempting to search for the document by the date and number
	SearchWithQuery = SearchByEqualDate Or (RealPropertyForSearchCount <> 2);
	
	If SearchWithQuery Then
		Return Undefined;
	EndIf;
	
	DocumentNumber = SearchProperties["Number"];
	DocumentDate  = SearchProperties["Date"];
	
	If (DocumentNumber <> Undefined) And (DocumentDate <> Undefined) Then
		
		ObjectRef = PropertyStructure.Manager.FindByNumber(DocumentNumber, DocumentDate);
		
	Else
		
		// Failed to find the document by the date and number, search with a query is necessary
		SearchWithQuery = True;
		ObjectRef = Undefined;
		
	EndIf;
	
	Return ObjectRef;
	
EndFunction

Function FindItemBySearchProperties(ObjectType, ObjectTypeName, SearchProperties, 
	PropertyStructure, SearchPropertyNameString, SearchByEqualDate)
	
	// Searching by predefined item name or by unique reference link is not required.
	// Searching by properties that are in the property name string. 
	// If this parameter is empty, searching by all available search properties.
	
	If IsBlankString(SearchPropertyNameString) Then
		
		TemporarySearchProperties = SearchProperties;
		
	Else
		
		ResultingStringForParsing = StrReplace(SearchPropertyNameString, "", "");
		StringLength = StrLen(ResultingStringForParsing);
		If Mid(ResultingStringForParsing, StringLength, 1) <> "," Then
			
			ResultingStringForParsing = ResultingStringForParsing + ",";
			
		EndIf;
		
		TemporarySearchProperties = New Map;
		For Each PropertyItem In SearchProperties Do
			
			ParameterName = PropertyItem.Key;
			If Find(ResultingStringForParsing, ParameterName + ",") > 0 Then
				
				TemporarySearchProperties.Insert(ParameterName, PropertyItem.Value);
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	UUIDProperty = TemporarySearchProperties["{UUID}"];
	PredefinedNameProperty = TemporarySearchProperties["{PredefinedItemName}"];
	
	RealPropertyForSearchCount = TemporarySearchProperties.Count();
	RealPropertyForSearchCount = RealPropertyForSearchCount - ?(UUIDProperty <> Undefined, 1, 0);
	RealPropertyForSearchCount = RealPropertyForSearchCount - ?(PredefinedNameProperty    <> Undefined, 1, 0);
	
	SearchWithQuery = False;
	
	If ObjectTypeName = "Document" Then
		
		ObjectRef = FindDocumentRef(TemporarySearchProperties, PropertyStructure, RealPropertyForSearchCount, SearchWithQuery, SearchByEqualDate);
		
	Else
		
		SearchWithQuery = True;
		
	EndIf;
	
	If SearchWithQuery Then
		
		ObjectRef = FindItemUsingRequest(PropertyStructure, TemporarySearchProperties, ObjectType, , RealPropertyForSearchCount);
		
	EndIf;
	
	Return ObjectRef;
EndFunction

Procedure ProcessObjectSearchPropertySetting(SetAllObjectSearchProperties, 
	ObjectType, 
	SearchProperties, 
	SearchPropertiesDontReplace, 
	ObjectRef, 
	CreatedObject, 
	WriteNewObjectToInfobase = True, 
	DontReplaceCreatedInTargetObject = False, 
	ObjectCreatedInCurrentInfobase = Undefined
	)
	
	If SetAllObjectSearchProperties <> True Then
		Return;
	EndIf;
	
	Try
		
		If Not ValueIsFilled(ObjectRef) Then
			Return;
		EndIf;
		
		If CreatedObject = Undefined Then
			CreatedObject = ObjectRef.GetObject();
		EndIf;
		
	Except
		Return;
	EndTry;
	
	SetObjectSearchAttributes(CreatedObject, SearchProperties, SearchPropertiesDontReplace);
	
EndProcedure

Procedure ReadSearchPropertyInfo(ObjectType, SearchProperties, SearchPropertiesDontReplace,
	SearchByEqualDate = False, ObjectParameters = Undefined, Val MainObjectSearchMode, ObjectMapFound, InfobaseObjectMaps)
	
	If SearchProperties = "" Then
		SearchProperties = New Map;  
	EndIf;
	
	If SearchPropertiesDontReplace = "" Then
		SearchPropertiesDontReplace = New Map;  
	EndIf; 
	
	TypeInformation = DataForImportTypeMap()[ObjectType];
	ReadSearchPropertiesFromFile(SearchProperties, SearchPropertiesDontReplace, TypeInformation, SearchByEqualDate, ObjectParameters, MainObjectSearchMode, ObjectMapFound, InfobaseObjectMaps);
	
EndProcedure

Procedure GetAdditionalObjectSearchParameters(SearchProperties, ObjectType, PropertyStructure, ObjectTypeName, IsDocumentObject)
	
	If ObjectType = Undefined Then
		
		// Attempting to determine the type by search properties
		RecipientTypeName = SearchProperties["{TypeNameInTargetInfobase}"];
		If RecipientTypeName = Undefined Then
			RecipientTypeName = SearchProperties["{TypeNameInSourceInfobase}"];
		EndIf;
		
		If RecipientTypeName <> Undefined Then
			
			ObjectType = Type(RecipientTypeName); 
			
		EndIf;  
		
	EndIf;
	
	PropertyStructure = Managers[ObjectType];
	ObjectTypeName    = PropertyStructure.TypeName; 
	
EndProcedure

Function FindFirstRuleByPropertyStructure(PropertyStructure)
	
	Try
		
		TargetRow = PropertyStructure.RefTypeString;
		
		If IsBlankString(TargetRow) Then
			Return Undefined;
		EndIf;
		
		For Each RuleRow In Rules Do
			
			If RuleRow.Value.Target = TargetRow Then
				Return RuleRow.Value;
			EndIf;
			
		EndDo;
		
	Except
		
	EndTry;
	
	Return Undefined;
	
EndFunction

// Searches for the infobase object. If it is not found, creates a new one.
//
// Parameters:
//  ObjectType       - type of the object to be found.
//  SearchProperties - structure with properties to be used for object searching.
//  ObjectFound      - False if object was not found and a new one was created.
//
// Returns:
//  New or found infobase object.
// 
Function FindObjectByRef(ObjectType, 
	SearchProperties = "", 
	SearchPropertiesDontReplace = "", 
	ObjectFound = True, 
	CreatedObject = Undefined, 
	DontCreateObjectIfNotFound = False,
	MainObjectSearchMode = False,
	GlobalRefSn = 0,
	RefSn = 0,
	ObjectFoundBySearchFields = False,
	KnownUUIDRef = Undefined,
	SearchingImportObject = False,
	ObjectParameters = Undefined,
	DontReplaceCreatedInTargetObject = False,
	ObjectCreatedInCurrentInfobase = Undefined,
	RecordObjectChangeAtSenderNode = False,
	UUIDString = "",
	OCRName = "",
	InfobaseObjectMaps = Undefined,
	SearchBySearchFieldsIfNotFoundByID = Undefined)
	
	// The object is identified consistently in five steps.
	// If nothing is found in the current step, going to the next one.
	//
	// Object identification (search) steps:
	// 1. Search by infobase object mapping register.
	// 2. Search by predefined item name.
	// 3. Search by reference UUID.
	// 4. Search by arbitrary search algorithm.
	// 5. Search by search fields.
	
	SearchByEqualDate 	= False;
	ObjectRef 			= Undefined;
	PropertyStructure 	= Undefined;
	ObjectTypeName 		= Undefined;
	IsDocumentObject 	= False;
	RefPropertyReadingCompleted = False;
	ObjectMapFound 		= False;
	
	GlobalRefSn = deAttribute(ExchangeFile, NumberType, "GSn");
	RefSn       = deAttribute(ExchangeFile, NumberType, "Sn");
	
	// Flag that shows whether the object must be registered to be exported in the sender node (return to sender)
	RecordObjectChangeAtSenderNode = deAttribute(ExchangeFile, BooleanType, "RecordObjectChangeAtSenderNode");
	
	FlagDontCreateObjectIfNotFound = deAttribute(ExchangeFile, BooleanType, "DontCreateIfNotFound");
	If Not ValueIsFilled(FlagDontCreateObjectIfNotFound) Then
		FlagDontCreateObjectIfNotFound = False;
	EndIf;
	
	If DontCreateObjectIfNotFound = Undefined Then
		DontCreateObjectIfNotFound = False;
	EndIf;
	
	OnExchangeObjectByRefSetGIUDOnly = Not MainObjectSearchMode;
	
	DontCreateObjectIfNotFound = DontCreateObjectIfNotFound Or FlagDontCreateObjectIfNotFound;
	
	DontReplaceCreatedInTargetObjectFlag = deAttribute(ExchangeFile, BooleanType, "DontReplaceCreatedInTargetObject");
	If Not ValueIsFilled(DontReplaceCreatedInTargetObjectFlag) Then
		DontReplaceCreatedInTargetObject = False;
	Else
		DontReplaceCreatedInTargetObject = DontReplaceCreatedInTargetObjectFlag; 
	EndIf;
	
	SearchBySearchFieldsIfNotFoundByID = deAttribute(ExchangeFile, BooleanType, "ContinueSearch"); 
	// 1. Searching the object by the infobase object mapping register
	ReadSearchPropertyInfo(ObjectType, SearchProperties, SearchPropertiesDontReplace, SearchByEqualDate, ObjectParameters, MainObjectSearchMode, ObjectMapFound, InfobaseObjectMaps);
	GetAdditionalObjectSearchParameters(SearchProperties, ObjectType, PropertyStructure, ObjectTypeName, IsDocumentObject);
	
	UUIDProperty = SearchProperties["{UUID}"];
	PredefinedNameProperty = SearchProperties["{PredefinedItemName}"];
	
	UUIDString = UUIDProperty;
	
	OnExchangeObjectByRefSetGIUDOnly = OnExchangeObjectByRefSetGIUDOnly
	And UUIDProperty <> Undefined
	;
	
	If ObjectMapFound Then
		
		// 1. The object has been found
		
		ObjectRef = PropertyStructure.Manager.GetRef(New UUID(UUIDProperty));
		
		If MainObjectSearchMode Then
			
			CreatedObject = ObjectRef.GetObject();
			
			If CreatedObject <> Undefined Then
				
				SetObjectSearchAttributes(CreatedObject, SearchProperties, SearchPropertiesDontReplace);
				
				ObjectFound = True;
				
				Return ObjectRef;
				
			EndIf;
			
		Else
			
			// If the object is not the main one, it is enough to retrieve a reference with the 
			// specified UUID.
			Return ObjectRef;
			
		EndIf;
		
	EndIf;
	
	// 2. Searching for the object by the name of the predefined item
	If PredefinedNameProperty <> Undefined Then
		
		CreateNewObjectAutomatically = False;
		
		ObjectRef = FindOrCreateObjectByProperty(PropertyStructure,
		ObjectType,
		SearchProperties,
		SearchPropertiesDontReplace,
		ObjectTypeName,
		"{PredefinedItemName}",
		PredefinedNameProperty,
		ObjectFound,
		CreateNewObjectAutomatically,
		CreatedObject,
		MainObjectSearchMode,
		,
		RefSn, GlobalRefSn,
		ObjectParameters,
		DontReplaceCreatedInTargetObject,
		ObjectCreatedInCurrentInfobase
		);
		
		If ObjectRef <> Undefined
			And ObjectRef.IsEmpty() Then
			
			ObjectFound = False;
			ObjectRef = Undefined;
			
		EndIf;
		
		If ObjectRef <> Undefined
			Or CreatedObject <> Undefined Then
			
			ObjectFound = True;
			
			// 2. The object has been found
			Return ObjectRef;
			
		EndIf;
		
	EndIf;
	
	// 3. Searching for the object by the reference UUID
	If UUIDProperty <> Undefined Then
		
		If MainObjectSearchMode Then
			
			CreateNewObjectAutomatically = Not DontCreateObjectIfNotFound And Not SearchBySearchFieldsIfNotFoundByID;
			
			ObjectRef = FindOrCreateObjectByProperty(PropertyStructure,
			ObjectType,
			SearchProperties,
			SearchPropertiesDontReplace,
			ObjectTypeName,
			"{UUID}",
			UUIDProperty,
			ObjectFound,
			CreateNewObjectAutomatically,
			CreatedObject,
			MainObjectSearchMode,
			KnownUUIDRef,
			RefSn,
			GlobalRefSn,
			ObjectParameters,
			DontReplaceCreatedInTargetObject,
			ObjectCreatedInCurrentInfobase
			);
			If Not SearchBySearchFieldsIfNotFoundByID Then
				
				Return ObjectRef;
				
			EndIf;
			
		ElsIf SearchBySearchFieldsIfNotFoundByID Then
			
			CreateNewObjectAutomatically = False;
			
			ObjectRef = FindOrCreateObjectByProperty(PropertyStructure,
			ObjectType,
			SearchProperties,
			SearchPropertiesDontReplace,
			ObjectTypeName,
			"{UUID}",
			UUIDProperty,
			ObjectFound,
			CreateNewObjectAutomatically,
			CreatedObject,
			MainObjectSearchMode,
			KnownUUIDRef,
			RefSn,
			GlobalRefSn,
			ObjectParameters,
			DontReplaceCreatedInTargetObject,
			ObjectCreatedInCurrentInfobase
			);
			
		Else
			
			/// If the object is not the main one, it is enough to retrieve a reference with the 
			// specified UUID.
			Return PropertyStructure.Manager.GetRef(New UUID(UUIDProperty));
			
		EndIf;
		
		If ObjectRef <> Undefined 
			And ObjectRef.IsEmpty() Then
			
			ObjectFound = False;
			ObjectRef = Undefined;
			
		EndIf;
		
		If ObjectRef <> Undefined
			Or CreatedObject <> Undefined Then
			
			ObjectFound = True;
			
			// 3. The object has been found
			Return ObjectRef;
			
		EndIf;
		
	EndIf;
	
	// 4. Searching for the object by the arbitrary search algorithm
	SearchVariantNumber = 1;
	SearchPropertyNameString = "";
	PreviousSearchString = Undefined;
	StopSearch = False;
	SetAllObjectSearchProperties = True;
	OCR = Undefined;
	SearchAlgorithm = "";
	
	If Not IsBlankString(OCRName) Then
		
		OCR = Rules[OCRName];
		
	EndIf;
	
	If OCR = Undefined Then
		
		OCR = GetConversionRuleWithSearchAlgorithmByTargetObjectType(PropertyStructure.RefTypeString);
		
	EndIf;
	
	If OCR <> Undefined Then
		
		SearchAlgorithm = OCR.SearchFieldSequence;
		
	EndIf;
	
	HasSearchAlgorithm = Not IsBlankString(SearchAlgorithm);
	
	While SearchVariantNumber <= 10
		And HasSearchAlgorithm Do
		
		Try
			
			
			If SL20CompatibilityMode() Then
				
				Execute(SearchAlgorithm);
				
			Else
				
				ExecuteHandler_OCR_SearchFieldSequence(SearchVariantNumber, SearchProperties, ObjectParameters, StopSearch,
				ObjectRef, SetAllObjectSearchProperties, SearchPropertyNameString,
				OCR.SearchFieldSequenceHandlerName);
				
			EndIf;
			
		Except
			
			WriteErrorInfoOCRHandlerImport(73, ErrorDescription(), "", "", 
			ObjectType, Undefined, NStr("en = 'Search field sequence'"));   
			
		EndTry;
		
		DontSearch = StopSearch = True 
		Or SearchPropertyNameString = PreviousSearchString
		Or ValueIsFilled(ObjectRef);    
		
		If Not DontSearch Then
			
			// The search
			ObjectRef = FindItemBySearchProperties(ObjectType, ObjectTypeName, SearchProperties, PropertyStructure, 
			SearchPropertyNameString, SearchByEqualDate);
			
			DontSearch = ValueIsFilled(ObjectRef); 
			
		EndIf;
		
		If DontSearch Then
			
			If MainObjectSearchMode Then
				
				ProcessObjectSearchPropertySetting(SetAllObjectSearchProperties, 
				ObjectType, 
				SearchProperties, 
				SearchPropertiesDontReplace, 
				ObjectRef, 
				CreatedObject, 
				Not MainObjectSearchMode, 
				DontReplaceCreatedInTargetObject, 
				ObjectCreatedInCurrentInfobase
				);
				
			EndIf;
			
			Break;
			
		EndIf; 
		
		SearchVariantNumber = SearchVariantNumber + 1;
		PreviousSearchString = SearchPropertyNameString;
		
	EndDo;
	
	If Not HasSearchAlgorithm Then
		
		// 5. Searching for the object by the search fields
		ObjectRef = FindItemBySearchProperties(ObjectType, ObjectTypeName, SearchProperties, PropertyStructure, 
		SearchPropertyNameString, SearchByEqualDate);
		
	EndIf;
	
	If MainObjectSearchMode
		And ValueIsFilled(ObjectRef)
		And (ObjectTypeName = "Document" 
		Or ObjectTypeName = "Task"
		Or ObjectTypeName = "BusinessProcess") Then
		
		// Setting the date if it is presented in the search properties
		EmptyDate = Not ValueIsFilled(SearchProperties["Date"]);
		CanReplace = (Not EmptyDate) 
		And (SearchPropertiesDontReplace["Date"] = Undefined);
		
		If CanReplace Then
			
			If CreatedObject = Undefined Then
				CreatedObject = ObjectRef.GetObject();
			EndIf;
			
			CreatedObject.Date = SearchProperties["Date"];
			
		EndIf;
		
	EndIf;  
	
	// New object creating is not always necessary
	If (ObjectRef = Undefined
		Or ObjectRef.IsEmpty())
		And CreatedObject = Undefined Then // The object is not found by the search fields
		
		If OnExchangeObjectByRefSetGIUDOnly Then
			
			ObjectRef = PropertyStructure.Manager.GetRef(New UUID(UUIDProperty)); 
			DummyObjectRef = True;
			
		ElsIf Not DontCreateObjectIfNotFound Then
			
			ObjectRef = CreateNewObject(ObjectType, SearchProperties, CreatedObject, 
			Not MainObjectSearchMode, KnownUUIDRef, RefSn, GlobalRefSn, 
			FindFirstRuleByPropertyStructure(PropertyStructure), ObjectParameters, SetAllObjectSearchProperties);  
			
		EndIf;
		
		ObjectFound = False;
		
	Else
		
		// The object is found
		ObjectFound = True;
		
	EndIf;
	
	If ObjectRef <> Undefined
		And ObjectRef.IsEmpty() Then
		
		ObjectRef = Undefined;
		
	EndIf;
	
	ObjectFoundBySearchFields = ObjectFound;
	
	Return ObjectRef;
	
EndFunction 

Procedure SetExchangeFileCollectionProperties(Object, ExchangeFileCollection, TypeInformation, ObjectParameters, RecNo, Val TabularSectionName, Val OrderFieldName)
	BranchName = TabularSectionName + "TabularSection";
	CollectionRow = ExchangeFileCollection.Add();
	CollectionRow[OrderFieldName] = RecNo;
	
	While ExchangeFile.Read() Do
		
		NodeName = ExchangeFile.LocalName;
		
		If NodeName = "Property" Or
			NodeName = "ParameterValue" Then
			
			IsParameter = (NodeName = "ParameterValue");
			
			Name    = deAttribute(ExchangeFile, StringType, "Name");
			OCRName = deAttribute(ExchangeFile, StringType, "OCRName");
			
			PropertyType = GetPropertyTypeByAdditionalData(TypeInformation, Name);
			
			PropertyValue = ReadProperty(PropertyType,,, OCRName);
			
			If IsParameter Then
				
				AddComplexParameterIfNecessary(ObjectParameters, BranchName, RecNo, Name, PropertyValue);
				
			Else
				
				Try
					
					CollectionRow[Name] = PropertyValue;
					
				Except
					
					LR = GetLogRecordStructure(26, ErrorDescription());
					LR.OCRName         = OCRName;
					LR.Object          = Object;
					LR.ObjectType      = TypeOf(Object);
					LR.Property        = "Object." + TabularSectionName + "." + Name;
					LR.Value           = PropertyValue;
					LR.ValueType       = TypeOf(PropertyValue);
					ErrorMessageString = WriteToExecutionLog(26, LR, True);
					
					If Not ContinueOnError Then
						Raise ErrorMessageString;
					EndIf;
					
				EndTry;
				
			EndIf;
			
		ElsIf NodeName = "ExtDimensionDr" Or NodeName = "ExtDimensionCr" Then
			
			deSkip(ExchangeFile);
			
		ElsIf (NodeName = "Record") And (ExchangeFile.NodeType = XMLNodeTypeEndElement) Then
			
			Break;
			
		Else
			
			WriteToExecutionLog(9);
			
			Break;
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Imports the object tabular section.
//
Procedure ImportTabularSection(Object, TabularSectionName, DocumentTypeCommonInformation, ObjectParameters, OCR)
	
	Var KeySearchFields;
	Var KeySearchFieldArray;
	
	Result = GetKeySearchFieldsByTabularSection(OCR, TabularSectionName, KeySearchFieldArray, KeySearchFields);
	
	If Not Result Then
		
		KeySearchFieldArray = New Array;
		
		MetadataObjectTabularSection = Object.Metadata().TabularSections[TabularSectionName];
		
		For Each Attribute In MetadataObjectTabularSection.Attributes Do
			
			KeySearchFieldArray.Add(Attribute.Name);
			
		EndDo;
		
		KeySearchFields = StringFunctionsClientServer.StringFromSubstringArray(KeySearchFieldArray);
		
	EndIf;
	
	UUID = StrReplace(String(New UUID), "-", "_");
	
	OrderFieldName = "OrderField_[UUID]";
	OrderFieldName = StrReplace(OrderFieldName, "[UUID]", UUID);
	
	IteratorColumnName = "IteratorField_[UUID]";
	IteratorColumnName = StrReplace(IteratorColumnName, "[UUID]", UUID);
	
	ObjectTabularSection = Object[TabularSectionName];
	
	ObjectCollection = ObjectTabularSection.Unload();
	
	ExchangeFileCollection = ObjectCollection.CopyColumns();	
	ExchangeFileCollection.Columns.Add(OrderFieldName);
	
	FillExchangeFileCollection(Object, ExchangeFileCollection, TabularSectionName, DocumentTypeCommonInformation, ObjectParameters, KeySearchFieldArray, OrderFieldName);
	
	AddColumnWithValueToTable(ExchangeFileCollection, +1, IteratorColumnName);
	AddColumnWithValueToTable(ObjectCollection,       1, IteratorColumnName);
	
	GroupCollection = InitTableByKeyFields(KeySearchFieldArray);
	GroupCollection.Columns.Add(IteratorColumnName);
	
	FillTablePropertyValues(ExchangeFileCollection, GroupCollection);
	FillTablePropertyValues(ObjectCollection,       GroupCollection);
	
	GroupCollection.GroupBy(KeySearchFields, IteratorColumnName);
	
	OrderCollection = ObjectTabularSection.UnloadColumns();
	OrderCollection.Columns.Add(OrderFieldName);
	
	For Each CollectionRow In GroupCollection Do
		
		// Getting the filter structure
		Filter = New Structure();
		
		For Each FieldName In KeySearchFieldArray Do
			
			Filter.Insert(FieldName, CollectionRow[FieldName]);
			
		EndDo;
		
		OrderFieldValues = Undefined;
		
		If CollectionRow[IteratorColumnName] = 0 Then
			
			// Filling the tabular section rows with data from the old object version
			ObjectCollectionRows = ObjectCollection.FindRows(Filter);
			
			OrderFieldValues = ExchangeFileCollection.FindRows(Filter);
			
		Else
			
			// Filling the tabular section rows with data from the exchange file collection
			ObjectCollectionRows = ExchangeFileCollection.FindRows(Filter);
			
		EndIf;
		
		// Adding rows to the object tabular section
		For Each CollectionRow In ObjectCollectionRows Do
			
			OrderCollectionRow = OrderCollection.Add();
			
			FillPropertyValues(OrderCollectionRow, CollectionRow);
			
			If OrderFieldValues <> Undefined Then
				
				OrderCollectionRow[OrderFieldName] = OrderFieldValues[ObjectCollectionRows.Find(CollectionRow)][OrderFieldName];
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
	OrderCollection.Sort(OrderFieldName);
	
	// Importing the result into the object tabular section
	Try
		ObjectTabularSection.Load(OrderCollection);
	Except
		
		Text = NStr("en = 'Tabular section name: %1'");
		
		LR = GetLogRecordStructure(83, ErrorDescription());
		LR.Object     = Object;
		LR.ObjectType = TypeOf(Object);
		LR.Text = StringFunctionsClientServer.SubstituteParametersInString(Text, TabularSectionName);
		WriteToExecutionLog(83, LR);
		
		deSkip(ExchangeFile);
		Return;
	EndTry;
	
EndProcedure

Procedure FillTablePropertyValues(SourceCollection, TargetCollection)
	
	For Each CollectionItem In SourceCollection Do
		
		FillPropertyValues(TargetCollection.Add(), CollectionItem);
		
	EndDo;
	
EndProcedure

Function InitTableByKeyFields(KeySearchFieldArray)
	
	Collection = New ValueTable;
	
	For Each FieldName In KeySearchFieldArray Do
		
		Collection.Columns.Add(FieldName);
		
	EndDo;
	
	Return Collection;
	
EndFunction

Procedure AddColumnWithValueToTable(Collection, Value, IteratorColumnName)
	
	Collection.Columns.Add(IteratorColumnName);
	Collection.FillValues(Value, IteratorColumnName);
	
EndProcedure

Function GetArrayFromString(Val ItemString)
	
	Result = New Array;
	
	ItemString = ItemString + ",";
	
	While True Do
		
		Pos = Find(ItemString, ",");
		
		If Pos = 0 Then
			Break;
		EndIf;
		
		Item = Left(ItemString, Pos - 1);
		
		Result.Add(TrimAll(Item));
		
		ItemString = Mid(ItemString, Pos + 1);
		
	EndDo;
	
	Return Result;
	
EndFunction

Procedure FillExchangeFileCollection(Object, ExchangeFileCollection, TabularSectionName, DocumentTypeCommonInformation, ObjectParameters, KeySearchFieldArray, OrderFieldName)
	
	BranchName = TabularSectionName + "TabularSection";
	
	If DocumentTypeCommonInformation <> Undefined Then
		TypeInformation = DocumentTypeCommonInformation[BranchName];
	Else
		TypeInformation = Undefined;
	EndIf;
	
	RecNo = 0;
	
	While ExchangeFile.Read() Do
		
		NodeName = ExchangeFile.LocalName;
		
		If NodeName = "Record" Then
			
			SetExchangeFileCollectionProperties(Object, ExchangeFileCollection, TypeInformation, ObjectParameters, RecNo, TabularSectionName, OrderFieldName);
			
			RecNo = RecNo + 1;
			
		ElsIf (NodeName = "TabularSection") And (ExchangeFile.NodeType = XMLNodeTypeEndElement) Then
			
			Break;
			
		Else
			
			WriteToExecutionLog(9);
			Break;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Function GetKeySearchFieldsByTabularSection(OCR, TabularSectionName, KeySearchFieldArray, KeySearchFields)
	
	If OCR = Undefined Then
		Return False;
	EndIf;
	
	SearchDataInTS = OCR.SearchInTabularSections.Find("TabularSection." + TabularSectionName, "ItemName");
	
	If SearchDataInTS = Undefined Then
		Return False;
	EndIf;
	
	If Not SearchDataInTS.Valid Then
		Return False;
	EndIf;
	
	KeySearchFieldArray = SearchDataInTS.KeySearchFieldArray;
	KeySearchFields     = SearchDataInTS.KeySearchFields;
	
	Return True;
	
EndFunction

// Imports object records.
//
// Parameters:
//  Object - object whose records are imported.
//  Name   - register name.
//  Clear  - pass True to clear the target records before import.
// 
Procedure ImportRegisterRecords(Object, Name, Clear, DocumentTypeCommonInformation, 
	ObjectParameters, Rule)
	
	RegisterRecordName = Name + "RecordSet";
	If DocumentTypeCommonInformation <> Undefined Then
		TypeInformation = DocumentTypeCommonInformation[RegisterRecordName];
	Else
		TypeInformation = Undefined;
	EndIf;
	
	SearchDataInTS = Undefined;
	
	TSCopyForSearch = Undefined;
	
	RegisterRecords = Object.RegisterRecords[Name];
	
	RegisterRecords.Read();
	
	If Clear
		And RegisterRecords.Count() <> 0 Then
		
		If SearchDataInTS <> Undefined Then 
			TSCopyForSearch = RegisterRecords.Unload();
		EndIf;
		
		RegisterRecords.Clear();
		
	ElsIf SearchDataInTS <> Undefined Then
		
		TSCopyForSearch = RegisterRecords.Unload(); 
		
	EndIf;
	
	RecNo = 0;
	While ExchangeFile.Read() Do
		
		NodeName = ExchangeFile.LocalName;
		
		If NodeName = "Record" Then
			
			Record = RegisterRecords.Add();
			SetRecordProperties(Record, TypeInformation, ObjectParameters, RegisterRecordName, RecNo, SearchDataInTS, TSCopyForSearch);
			
			RecNo = RecNo + 1;
			
		ElsIf (NodeName = "RecordSet") And (ExchangeFile.NodeType = XMLNodeTypeEndElement) Then
			
			Break;
			
		Else
			
			WriteToExecutionLog(9);
			Break;
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Sets object (record) properties. 
//
// Parameters:
//  Record - object whose properties are set, for example, a tabular section row or a 
//           record set.
//

Procedure SetRecordProperties(Record, TypeInformation, 
	ObjectParameters, BranchName, RecNo,
	SearchDataInTS = Undefined, TSCopyForSearch = Undefined)
	
	MustSearchInTS = (SearchDataInTS <> Undefined)
	And (TSCopyForSearch <> Undefined)
	And TSCopyForSearch.Count() <> 0;
	
	If MustSearchInTS Then
		
		PropertyReadingStructure = New Structure();
		ExtDimensionReadingStructure = New Structure();
		
	EndIf;
	
	While ExchangeFile.Read() Do
		
		NodeName = ExchangeFile.LocalName;
		
		If NodeName = "Property"
			Or NodeName = "ParameterValue" Then
			
			
			IsParameter = (NodeName = "ParameterValue");
			
			Name    = deAttribute(ExchangeFile, StringType, "Name");
			OCRName = deAttribute(ExchangeFile, StringType, "OCRName");
			
			If Name = "RecordType" And Find(Metadata.FindByType(TypeOf(Record)).FullName(), "AccumulationRegister") Then
				
				PropertyType = AccumulationRecordTypeType;
				
			Else
				
				PropertyType = GetPropertyTypeByAdditionalData(TypeInformation, Name);
				
			EndIf;
			
			PropertyValue = ReadProperty(PropertyType,,, OCRName);
			
			If IsParameter Then
				AddComplexParameterIfNecessary(ObjectParameters, BranchName, RecNo, Name, PropertyValue);   
			ElsIf MustSearchInTS Then 
				PropertyReadingStructure.Insert(Name, PropertyValue); 
			Else
				
				Try
					
					Record[Name] = PropertyValue;
					
				Except
					
					LR = GetLogRecordStructure(26, ErrorDescription());
					LR.OCRName         = OCRName;
					LR.Object          = Record;
					LR.ObjectType      = TypeOf(Record);
					LR.Property        = Name;
					LR.Value           = PropertyValue;
					LR.ValueType       = TypeOf(PropertyValue);
					ErrorMessageString = WriteToExecutionLog(26, LR, True);
					
					If Not ContinueOnError Then
						Raise ErrorMessageString;
					EndIf;
					
				EndTry;
				
			EndIf;
			
		ElsIf NodeName = "ExtDimensionDr" Or NodeName = "ExtDimensionCr" Then
			
			// Search by extra dimension is not supported
			
			CurKey = Undefined;
			Value = Undefined;
			
			While ExchangeFile.Read() Do
				
				NodeName = ExchangeFile.LocalName;
				
				If NodeName = "Property" Then
					
					Name    = deAttribute(ExchangeFile, StringType, "Name");
					OCRName = deAttribute(ExchangeFile, StringType, "OCRName");
					
					PropertyType = GetPropertyTypeByAdditionalData(TypeInformation, Name);
					
					If Name = "Key" Then
						
						CurKey = ReadProperty(PropertyType);
						
					ElsIf Name = "Value" Then
						
						Value = ReadProperty(PropertyType,,, OCRName);
						
					EndIf;
					
				ElsIf (NodeName = "ExtDimensionDr" Or NodeName = "ExtDimensionCr") And (ExchangeFile.NodeType = XMLNodeTypeEndElement) Then
					
					Break;
					
				Else
					
					WriteToExecutionLog(9);
					Break;
					
				EndIf;
				
			EndDo;
			
			If CurKey <> Undefined 
				And Value <> Undefined Then
				
				If Not MustSearchInTS Then
					
					Record[NodeName][CurKey] = Value;
					
				Else
					
					RecordMapping = Undefined;
					If Not ExtDimensionReadingStructure.Property(NodeName, RecordMapping) Then
						RecordMapping = New Map;
						ExtDimensionReadingStructure.Insert(NodeName, RecordMapping);
					EndIf;
					
					RecordMapping.Insert(CurKey, Value);
					
				EndIf;
				
			EndIf;
			
		ElsIf (NodeName = "Record") And (ExchangeFile.NodeType = XMLNodeTypeEndElement) Then
			
			Break;
			
		Else
			
			WriteToExecutionLog(9);
			Break;
			
		EndIf;
		
	EndDo;
	
	If MustSearchInTS Then
		
		SearchStructure = New Structure();
		
		For Each SearchItem In  SearchDataInTS.TSSearchFields Do
			
			ItemValue = Undefined;
			PropertyReadingStructure.Property(SearchItem, ItemValue);
			
			SearchStructure.Insert(SearchItem, ItemValue);  
			
		EndDo;  
		
		SearchResultArray = TSCopyForSearch.FindRows(SearchStructure);
		
		RecordFound = SearchResultArray.Count() > 0;
		If RecordFound Then
			FillPropertyValues(Record, SearchResultArray[0]);
		EndIf;
		
		// Filling with the extra dimension value and properties
		For Each Item In PropertyReadingStructure Do
			
			Record[Item.Key] = Item.Value;
			
		EndDo;
		
		For Each ItemName In ExtDimensionReadingStructure Do
			
			For Each ItemKey In ItemName.Value Do
				
				Record[ItemName.Key][ItemKey.Key] = ItemKey.Value;
				
			EndDo;
			
		EndDo;   
		
	EndIf;
	
EndProcedure

// Imports the object of the TypeDescription type from the specified source XML node.
//
// Parameters:
//  Source - source XML node.
// 
Function ImportObjectTypes(Source)
	
	// DateQualifiers
	
	DateContent =  deAttribute(Source, StringType,  "DateContent");
	
	
	// StringQualifiers
	
	Length        =  deAttribute(Source, NumberType, "Length");
	AllowedLength =  deAttribute(Source, StringType, "AllowedLength");
	
	
	// NumberQualifiers
	
	Digits         = deAttribute(Source, NumberType, "Digits");
	FractionDigits = deAttribute(Source, NumberType, "FractionDigits");
	AllowedFlag    = deAttribute(Source, StringType, "AllowedSign");
	
	
	// Reading the array of types
	
	TypeArray = New Array;
	
	While Source.Read() Do
		NodeName = Source.LocalName;
		
		If NodeName = "Type" Then
			TypeArray.Add(Type(deElementValue(Source, StringType)));
		ElsIf (NodeName = "Types") And ( Source.NodeType = XMLNodeTypeEndElement) Then
			Break;
		Else
			WriteToExecutionLog(9);
			Break;
		EndIf;
		
	EndDo;
	
	
	
	If TypeArray.Count() > 0 Then
		
		// DateQualifiers
		
		If DateContent = "Date" Then
			DateQualifiers   = New DateQualifiers(DateFractions.Date);
		ElsIf DateContent = "DateTime" Then
			DateQualifiers   = New DateQualifiers(DateFractions.DateTime);
		ElsIf DateContent = "Time" Then
			DateQualifiers   = New DateQualifiers(DateFractions.Time);
		Else
			DateQualifiers   = New DateQualifiers(DateFractions.DateTime);
		EndIf; 
		
		
		// NumberQualifiers
		
		If Digits > 0 Then
			If AllowedFlag = "Nonnegative" Then
				Mark = AllowedSign.Nonnegative;
			Else
				Mark = AllowedSign.Any;
			EndIf; 
			NumberQualifiers = New NumberQualifiers(Digits, FractionDigits, Mark);
		Else
			NumberQualifiers = New NumberQualifiers();
		EndIf; 
		
		
		// StringQualifiers
		
		If Length > 0 Then
			If AllowedLength = "Fixed" Then
				AllowedLength = AllowedLength.Fixed;
			Else
				AllowedLength = AllowedLength.Variable;
			EndIf;
			StringQualifiers = New StringQualifiers(Length, AllowedLength);
		Else
			StringQualifiers = New StringQualifiers();
		EndIf; 
		
		Return New TypeDescription(TypeArray, NumberQualifiers, StringQualifiers, DateQualifiers);
	EndIf;
	
	Return Undefined;
	
EndFunction

Procedure WriteDocumentInSafeMode(Document, ObjectType)
	
	If Document.Posted Then
		
		Document.Posted = False;
		
	EndIf;  
	
	WriteObjectToInfobase(Document, ObjectType); 
	
EndProcedure

Function GetObjectByRefAndAdditionalInformation(CreatedObject, Ref)
	
	// Getting the found object 
	If CreatedObject <> Undefined Then
		
		Object = CreatedObject;
		
	ElsIf Ref = Undefined Then
		
		Object = Undefined;
		
	ElsIf Ref.IsEmpty() Then
		
		Object = Undefined;
		
	Else
		
		Object = Ref.GetObject();
		
	EndIf;
	
	Return Object;
EndFunction

Procedure ObjectImportComments(Sn, RuleName, Source, ObjectType, GSn = 0)
	
	If CommentObjectProcessingFlag Then
		
		MessageString = NStr("en = 'Importing object #%1'");
		Number = ?(Sn <> 0, Sn, GSn);
		MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, Number);
		
		LR = GetLogRecordStructure();
		
		If Not IsBlankString(RuleName) Then
			
			LR.OCRName = RuleName;
			
		EndIf;
		
		If Not IsBlankString(Source) Then
			
			LR.Source = Source;
			
		EndIf;
		
		LR.ObjectType = ObjectType;
		WriteToExecutionLog(MessageString, LR, False);
		
	EndIf; 
	
EndProcedure

Procedure AddParameterIfNecessary(DataParameters, ParameterName, ParameterValue)
	
	If DataParameters = Undefined Then
		DataParameters = New Map;
	EndIf;
	
	DataParameters.Insert(ParameterName, ParameterValue);
	
EndProcedure

Procedure AddComplexParameterIfNecessary(DataParameters, ParameterBranchName, LineNumber, ParameterName, ParameterValue)
	
	If DataParameters = Undefined Then
		DataParameters = New Map;
	EndIf;
	
	CurrentParameterData = DataParameters[ParameterBranchName];
	
	If CurrentParameterData = Undefined Then
		
		CurrentParameterData = New ValueTable;
		CurrentParameterData.Columns.Add("LineNumber");
		CurrentParameterData.Columns.Add("ParameterName");
		CurrentParameterData.Indexes.Add("LineNumber");
		
		DataParameters.Insert(ParameterBranchName, CurrentParameterData); 
		
	EndIf;
	
	If CurrentParameterData.Columns.Find(ParameterName) = Undefined Then
		CurrentParameterData.Columns.Add(ParameterName);
	EndIf;  
	
	RowData = CurrentParameterData.Find(LineNumber, "LineNumber");
	If RowData = Undefined Then
		RowData = CurrentParameterData.Add();
		RowData.LineNumber = LineNumber;
	EndIf;  
	
	RowData[ParameterName] = ParameterValue;
	
EndProcedure

Function ReadObjectChangeRecordInfo()
	
	// Assigning CROSSWISE values to the variables, the information register is symmetrical
	TargetUUID = deAttribute(ExchangeFile, StringType,  "SourceUUID");
	SourceUUID = deAttribute(ExchangeFile, StringType,  "TargetUUID");
	TargetType = deAttribute(ExchangeFile, StringType,  "SourceType");
	SourceType = deAttribute(ExchangeFile, StringType,  "TargetType");
	EmptySet   = deAttribute(ExchangeFile, BooleanType, "EmptySet");
	
	Try
		SourceUUID = New UUID(SourceUUID);
	Except
		
		deSkip(ExchangeFile, "ObjectChangeRecordData");
		Return Undefined;
		
	EndTry;
	
	// Getting the source property structure by the source type
	PropertyStructure = Managers[Type(SourceType)];
	
	// Getting the source reference by the UUID
	SourceUUID = PropertyStructure.Manager.GetRef(SourceUUID);
	
	RecordSet = ObjectMappingRegisterManager.CreateRecordSet();
	
	// Filter for record set
	RecordSet.Filter.InfobaseNode.Set(ExchangeNodeDataImport);
	RecordSet.Filter.SourceUUID.Set(SourceUUID);
	RecordSet.Filter.TargetUUID.Set(TargetUUID);
	RecordSet.Filter.SourceType.Set(SourceType);
	RecordSet.Filter.TargetType.Set(TargetType);
	
	If Not EmptySet Then
		
		// Adding one record to the set
		SetRow = RecordSet.Add();
		
		SetRow.InfobaseNode = ExchangeNodeDataImport;
		SetRow.SourceUUID   = SourceUUID;
		SetRow.TargetUUID   = TargetUUID;
		SetRow.SourceType   = SourceType;
		SetRow.TargetType   = TargetType;
		
	EndIf;
	
	// Writing the record set
	WriteObjectToInfobase(RecordSet, "InformationRegisterRecordSet.InfobaseObjectMaps");
	
	deSkip(ExchangeFile, "ObjectChangeRecordData");
	
	Return RecordSet;
	
EndFunction

Procedure ExportMappingInfoAdjustment()
	
	ConversionRules = ConversionRuleTable.Copy(New Structure("SynchronizeByID", True), "SourceType, TargetType");
	ConversionRules.GroupBy("SourceType, TargetType");
	
	For Each Rule In ConversionRules Do
		
		Manager = Managers.Get(Type(Rule.SourceType)).Manager;
		
		If TypeOf(Manager) = Type("BusinessProcessRoutePoints") Then
			Continue;
		EndIf;
		
		If Manager <> Undefined Then
			
			Selection = Manager.Select();
			
			While Selection.Next() Do
				
				UUID = String(Selection.Ref.UUID());
				
				Target = CreateNode("ObjectChangeRecordDataAdjustment");
				
				SetAttribute(Target, "UUID",         UUID);
				SetAttribute(Target, "SourceType",   Rule.SourceType);
				SetAttribute(Target, "TargetType", Rule.TargetType);
				
				Target.WriteEndElement(); // ObjectChangeRecordDataAdjustment
				
				WriteToFile(Target);
				
				IncreaseExportedObjectCounter();
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure ReadMappingInfoAdjustment()
	
	// Assigning CROSSWISE values to the variables, the information register is symmetrical
	UUID       = deAttribute(ExchangeFile, StringType, "UUID");
	TargetType = deAttribute(ExchangeFile, StringType, "SourceType");
	SourceType = deAttribute(ExchangeFile, StringType, "TargetType");
	
	TargetUUID = UUID;
	SourceUUID = UUID;
	
	InfobaseObjectMappingQuery.SetParameter("InfobaseNode", ExchangeNodeDataImport);
	InfobaseObjectMappingQuery.SetParameter("TargetUUID", TargetUUID);
	InfobaseObjectMappingQuery.SetParameter("TargetType", TargetType);
	InfobaseObjectMappingQuery.SetParameter("SourceType",   SourceType);
	
	QueryResult = InfobaseObjectMappingQuery.Execute();
	
	If Not QueryResult.IsEmpty() Then
		Return; // Skipping the data, it is already presents in the register
	EndIf;
	
	Try
		UUID = SourceUUID;
		SourceUUID = New UUID(SourceUUID);
	Except
		Return;
	EndTry;
	
	// Getting the source property structure by the source type
	PropertyStructure = Managers[Type(SourceType)];
	
	// Getting the source reference by the UUID
	SourceUUID = PropertyStructure.Manager.GetRef(SourceUUID);
	
	Object = SourceUUID.GetObject();
	
	If Object = Undefined Then
		Return; // Skipping the data, the object is not presented in the infobase
	EndIf;
	
	// Adding the record to the mapping register
	RecordStructure = New Structure;
	RecordStructure.Insert("InfobaseNode", ExchangeNodeDataImport);
	RecordStructure.Insert("SourceUUID",   SourceUUID);
	RecordStructure.Insert("TargetUUID",   TargetUUID);
	RecordStructure.Insert("TargetType",   TargetType);
	RecordStructure.Insert("SourceType",   SourceType);
	
	InformationRegisters.InfobaseObjectMappings.AddRecord(RecordStructure);
	
	IncreaseExportedObjectCounter();
	
EndProcedure

Function ReadRegisterRecordSet()
	
	// Variables for supporting the event handler script debugging mechanism 
	Var Ref,ObjectFound, DontReplaceObject, WriteMode, PostingMode, GenerateNewNumberOrCodeIfNotSet, ObjectModified;
	
	Sn                     = deAttribute(ExchangeFile, NumberType,  "Sn");
	RuleName               = deAttribute(ExchangeFile, StringType, "RuleName");
	ObjectTypeString       = deAttribute(ExchangeFile, StringType, "Type");
	ExchangeObjectPriority = GetExchangeObjectPriority(ExchangeFile);
	
	IsEmptySet = deAttribute(ExchangeFile, BooleanType, "EmptySet");
	If Not ValueIsFilled(IsEmptySet) Then
		IsEmptySet = False;
	EndIf;
	
	ObjectType       = Type(ObjectTypeString);
	Source           = Undefined;
	SearchProperties = Undefined;
	
	ObjectImportComments(Sn, RuleName, Undefined, ObjectType);
	
	RegisterRowTypeName = StrReplace(ObjectTypeString, "InformationRegisterRecordSet.", "InformationRegisterRecord.");
	RegisterName = StrReplace(ObjectTypeString, "InformationRegisterRecordSet.", "");
	
	RegisterSetRowType = Type(RegisterRowTypeName);
	
	PropertyStructure = Managers[RegisterSetRowType];
	ObjectTypeName    = PropertyStructure.TypeName;
	
	TypeInformation = DataForImportTypeMap()[RegisterSetRowType];
	
	Object = Undefined;
	
	If Not IsBlankString(RuleName) Then
		
		Rule = Rules[RuleName];
		HasBeforeImportHandler = Rule.HasBeforeImportHandler;
		HasOnImportHandler     = Rule.HasOnImportHandler;
		HasAfterImportHandler  = Rule.HasAfterImportHandler;
		
	Else
		
		HasBeforeImportHandler = False;
		HasOnImportHandler     = False;
		HasAfterImportHandler  = False;
		
	EndIf;
	
	
	// BeforeImportObject global event handler
	
	If HasBeforeImportObjectGlobalHandler Then
		
		Cancel = False;
		
		Try
			
			
			If SL20CompatibilityMode() Then
				
				Execute(Conversion.BeforeImportObject);
				
			Else
				
				ExecuteHandler_Conversion_BeforeImportObject(ExchangeFile, Cancel, Sn, Source, RuleName, Rule,
				GenerateNewNumberOrCodeIfNotSet,ObjectTypeString,
				ObjectType, DontReplaceObject, WriteMode, PostingMode);
				
			EndIf;
			
		Except
			
			WriteErrorInfoOCRHandlerImport(53, ErrorDescription(), RuleName, Source, 
			ObjectType, Undefined, NStr("en = 'BeforeImportObject (global)'"));
			
		EndTry;   
		
		If Cancel Then // Canceling object import
			
			deSkip(ExchangeFile, "Object");
			Return Undefined;
			
		EndIf;
		
	EndIf;
	
	
	// BeforeImportObject event handler
	If HasBeforeImportHandler Then
		
		Cancel = False;
		
		Try
			
			
			If SL20CompatibilityMode() Then
				
				Execute(Rule.BeforeImport);
				
			Else
				
				ExecuteHandler_OCR_BeforeImportObject(ExchangeFile, Cancel, Sn, Source, RuleName, Rule,
				GenerateNewNumberOrCodeIfNotSet, ObjectTypeString,
				ObjectType, DontReplaceObject, WriteMode, PostingMode);
				
			EndIf;
			
		Except
			
			WriteErrorInfoOCRHandlerImport(19, ErrorDescription(), RuleName, Source, 
			ObjectType, Undefined, "BeforeImportObject");    
			
		EndTry;   
		
		
		If Cancel Then // Canceling object import
			
			deSkip(ExchangeFile, "Object");
			Return Undefined;
			
		EndIf;
		
	EndIf;
	
	FilterReadMode    = False;
	RecordReadingMode = False;
	
	RegisterFilter      = Undefined;
	CurrentRecordSetRow = Undefined;
	ObjectParameters    = Undefined;
	RecordSetParameters = Undefined;
	RecNo = 1;
	
	// Reading data from the register
	While ExchangeFile.Read() Do
		
		NodeName = ExchangeFile.LocalName;
		
		If NodeName = "Filter" Then
			
			If ExchangeFile.NodeType <> XMLNodeTypeEndElement Then
				
				Object = InformationRegisters[RegisterName].CreateRecordSet();
				RegisterFilter = Object.Filter;
				
				FilterReadMode = True;
				
			EndIf;   
			
		ElsIf NodeName = "Property"
			Or NodeName = "ParameterValue" Then
			
			IsParameterForObject = (NodeName = "ParameterValue");
			
			Name                 = deAttribute(ExchangeFile, StringType,  "Name");
			DontReplaceProperty  = deAttribute(ExchangeFile, BooleanType, "DontReplace");
			OCRName              = deAttribute(ExchangeFile, StringType,  "OCRName");
			
			// Reading and setting the property value
			PropertyType = GetPropertyTypeByAdditionalData(TypeInformation, Name);
			PropertyNotFoundByRef = False;
			
			// Creating is always necessary
			Value = ReadProperty(PropertyType, IsEmptySet, PropertyNotFoundByRef, OCRName);
			
			If IsParameterForObject Then
				
				If FilterReadMode Then
					AddParameterIfNecessary(RecordSetParameters, Name, Value);
				Else
					// Supplementing object parameter collection
					AddParameterIfNecessary(ObjectParameters, Name, Value);
					AddComplexParameterIfNecessary(RecordSetParameters, "Rows", RecNo, Name, Value);
				EndIf;
				
			Else
				
				Try
					
					If FilterReadMode Then
						RegisterFilter[Name].Set(Value);      
					ElsIf RecordReadingMode Then
						CurrentRecordSetRow[Name] = Value;
					EndIf;
					
				Except
					
					LR = GetLogRecordStructure(26, ErrorDescription());
					LR.OCRName         = RuleName;
					LR.Source          = Source;
					LR.Object          = Object;
					LR.ObjectType      = ObjectType;
					LR.Property        = Name;
					LR.Value           = Value;
					LR.ValueType       = TypeOf(Value);
					ErrorMessageString = WriteToExecutionLog(26, LR, True);
					
					If Not ContinueOnError Then
						Raise ErrorMessageString;
					EndIf;
					
				EndTry;
				
			EndIf;
			
		ElsIf NodeName = "RecordSetRows" Then
			
			If ExchangeFile.NodeType <> XMLNodeTypeEndElement Then
				
				// OnImportObject event handler.
				// Is called before before reading the first set record.
				If FilterReadMode = True
					And HasOnImportHandler Then
					
					Try
						
						
						If SL20CompatibilityMode() Then
							
							Execute(Rule.OnImport);
							
						Else
							
							ExecuteHandler_OCR_OnImportObject(ExchangeFile, ObjectFound, Object, DontReplaceObject, ObjectModified, Rule);
							
							
						EndIf;
						
					Except
						
						WriteErrorInfoOCRHandlerImport(20, ErrorDescription(), RuleName, Source, 
						ObjectType, Object, "OnImportObject");      
						
					EndTry;
					
				EndIf;
				
				FilterReadMode = False;
				RecordReadingMode = True;
				
			EndIf;
			
		ElsIf NodeName = "Object" Then
			
			If ExchangeFile.NodeType <> XMLNodeTypeEndElement Then
				
				CurrentRecordSetRow = Object.Add(); 
				RecNo = RecNo + 1;
				
			EndIf;
			
		ElsIf NodeName = "RegisterRecordSet" And ExchangeFile.NodeType = XMLNodeTypeEndElement Then
			
			Break;
			
		Else
			
			WriteToExecutionLog(9);
			Break;
			
		EndIf;
		
	EndDo;
	
	// After import
	If HasAfterImportHandler Then
		
		Try
			
			
			If SL20CompatibilityMode() Then
				
				Execute(Rule.AfterImport);
				
			Else
				
				ExecuteHandler_OCR_AfterImportObject(ExchangeFile, Cancel, Ref, Object, ObjectParameters,
				ObjectModified, ObjectTypeName, ObjectFound, Rule);
				
			EndIf;
			
		Except
			
			WriteErrorInfoOCRHandlerImport(21, ErrorDescription(), RuleName, Source, 
			ObjectType, Object, "AfterImportObject");    
			
		EndTry;
		
	EndIf;
	
	
	
	If Object <> Undefined Then
		
		ItemReceive = DataItemReceive.Auto;
		SendBack = False;
		
		Object.AdditionalProperties.Insert("DataExchange", New Structure("DataAnalysis", Not DataImportIntoInfobaseMode()));
		
		If ExchangeObjectPriority <> Enums.ExchangeObjectPriorities.ReceivedExchangeObjectPriorityHigher Then
			StandardSubsystemsServer.OnReceiveDataFromSlave(Object, ItemReceive, SendBack, ExchangeNodeDataImport);
		Else
			StandardSubsystemsServer.OnReceiveDataFromMaster(Object, ItemReceive, SendBack, ExchangeNodeDataImport);
		EndIf;
		
		If ItemReceive = DataItemReceive.Ignore Then
			Return Undefined;
		EndIf;
		
		WriteObjectToInfobase(Object, ObjectType);
		
		
	EndIf;
	
	Return Object; 
	
EndFunction


Procedure SupplementNotWrittenObjectStack(NumberForStack, Object, KnownRef, ObjectType, TypeName, GenerateCodeAutomatically = False, ObjectParameters = Undefined)
	
	
	StackString = GlobalNotWrittenObjectStack[NumberForStack];
	If StackString <> Undefined Then
		Return;
	EndIf;
	
	GlobalNotWrittenObjectStack.Insert(NumberForStack, New Structure("Object, KnownRef, ObjectType, TypeName, GenerateCodeAutomatically, ObjectParameters", 
	Object, KnownRef, ObjectType, TypeName, GenerateCodeAutomatically, ObjectParameters));
	
EndProcedure

Procedure DeleteFromNotWrittenObjectStack(Sn, GSn)
	
	NumberForStack = ?(Sn = 0, GSn, Sn);
	GlobalNotWrittenObjectStack.Delete(NumberForStack); 
	
EndProcedure

Procedure ExecuteWriteNotWrittenObjects()
	
	For Each DataRow In GlobalNotWrittenObjectStack Do
		
		// lazy record Objects
		Object = DataRow.Value.Object;
		RefSn = DataRow.Key;
		
		If DataRow.Value.GenerateCodeAutomatically = True Then
			
			GenerateNumberCodeIfNecessary(True, Object,
			DataRow.Value.TypeName, True);
			
		EndIf;
		
		WriteObjectToInfobase(Object, DataRow.Value.ObjectType);
		
	EndDo;
	
	GlobalNotWrittenObjectStack.Clear();
	
EndProcedure

Procedure GenerateNumberCodeIfNecessary(GenerateNewNumberOrCodeIfNotSet, Object, ObjectTypeName, 
	DataExchangeMode)
	
	If Not GenerateNewNumberOrCodeIfNotSet
		Or Not DataExchangeMode Then
		
		// No need to generate the number or it is generated automatically by the platform
		Return;
	EndIf;
	
	// Checking whether the code or number are filled (depends on the object type)
	If ObjectTypeName = "Document"
		Or ObjectTypeName = "BusinessProcess"
		Or ObjectTypeName = "Task" Then
		
		If Not ValueIsFilled(Object.Number) Then
			
			Object.SetNewNumber();
			
		EndIf;
		
	ElsIf ObjectTypeName = "Catalog"
		Or ObjectTypeName = "ChartOfCharacteristicTypes"
		Or ObjectTypeName = "ExchangePlan" Then
		
		If Not ValueIsFilled(Object.Code) Then
			
			Object.SetNewCode();
			
		EndIf; 
		
	EndIf;
	
EndProcedure

Function GetExchangeObjectPriority(ExchangeFile)
	
	PriorityString = deAttribute(ExchangeFile, StringType, "ExchangeObjectPriority");
	If IsBlankString(PriorityString) Then
		PriorityValue = Enums.ExchangeObjectPriorities.ReceivedExchangeObjectPriorityHigher;
	ElsIf PriorityString = "Higher" Then
		PriorityValue = Enums.ExchangeObjectPriorities.ReceivedExchangeObjectPriorityHigher;
	ElsIf PriorityString = "Lower" Then
		PriorityValue = Enums.ExchangeObjectPriorities.ReceivedExchangeObjectPriorityLower;
	ElsIf PriorityString = "Matches" Then
		PriorityValue = Enums.ExchangeObjectPriorities.ObjectCameDuringExchangeHasSamePriority;
	EndIf;
	
	Return PriorityValue;
	
EndFunction

// Reads the next object from the exchange file, imports it.
// 
Function ReadObject(UUIDString = "")
	
	Sn                     = deAttribute(ExchangeFile, NumberType,  "Sn");
	GSn                    = deAttribute(ExchangeFile, NumberType,  "GSn");
	Source                 = deAttribute(ExchangeFile, StringType, "Source");
	RuleName               = deAttribute(ExchangeFile, StringType, "RuleName");
	DontReplaceObject      = deAttribute(ExchangeFile, BooleanType, "DontReplace");
	AutonumerationPrefix   = deAttribute(ExchangeFile, StringType, "AutonumerationPrefix");
	ExchangeObjectPriority = GetExchangeObjectPriority(ExchangeFile);
	
	ObjectTypeString       = deAttribute(ExchangeFile, StringType, "Type");
	ObjectType             = Type(ObjectTypeString);
	TypeInformation        = DataForImportTypeMap()[ObjectType];
	
	
	ObjectImportComments(Sn, RuleName, Source, ObjectType, GSn);
	
	PropertyStructure = Managers[ObjectType];
	ObjectTypeName    = PropertyStructure.TypeName;
	
	
	If ObjectTypeName = "Document" Then
		
		WriteMode   = deAttribute(ExchangeFile, StringType, "WriteMode");
		PostingMode = deAttribute(ExchangeFile, StringType, "PostingMode");
		
	EndIf;
	
	Object                         = Undefined;
	ObjectFound                    = True;
	ObjectCreatedInCurrentInfobase = Undefined;
	
	SearchProperties = New Map;
	SearchPropertiesDontReplace = New Map;
	
	If Not IsBlankString(RuleName) Then
		
		Rule = Rules[RuleName];
		HasBeforeImportHandler = Rule.HasBeforeImportHandler;
		HasOnImportHandler     = Rule.HasOnImportHandler;
		HasAfterImportHandler  = Rule.HasAfterImportHandler;
		GenerateNewNumberOrCodeIfNotSet = Rule.GenerateNewNumberOrCodeIfNotSet;
		DontReplaceCreatedInTargetObject =  Rule.DontReplaceCreatedInTargetObject;
		
	Else
		
		HasBeforeImportHandler = False;
		HasOnImportHandler     = False;
		HasAfterImportHandler  = False;
		GenerateNewNumberOrCodeIfNotSet = False;
		DontReplaceCreatedInTargetObject = False;
		
	EndIf;
	
	
	// BeforeImportObject global event handler
	
	If HasBeforeImportObjectGlobalHandler Then
		
		Cancel = False;
		
		Try
			
			
			If SL20CompatibilityMode() Then
				
				Execute(Conversion.BeforeImportObject);
				
			Else
				
				ExecuteHandler_Conversion_BeforeImportObject(ExchangeFile, Cancel, Sn, Source, RuleName, Rule,
				GenerateNewNumberOrCodeIfNotSet,ObjectTypeString,
				ObjectType, DontReplaceObject, WriteMode, PostingMode);
				
			EndIf;
			
		Except
			
			WriteErrorInfoOCRHandlerImport(53, ErrorDescription(), RuleName, Source, 
			ObjectType, Undefined, NStr("en = 'BeforeImportObject (global)'"));    
			
		EndTry;
		
		If Cancel Then // Canceling object import
			
			deSkip(ExchangeFile, "Object");
			Return Undefined;
			
		EndIf;
		
	EndIf;
	
	
	// BeforeImportObject event handler
	If HasBeforeImportHandler Then
		
		Cancel = False;
		
		Try
			
			If SL20CompatibilityMode() Then
				
				Execute(Rule.BeforeImport);
				
			Else
				
				ExecuteHandler_OCR_BeforeImportObject(ExchangeFile, Cancel, Sn, Source, RuleName, Rule,
				GenerateNewNumberOrCodeIfNotSet, ObjectTypeString,
				ObjectType, DontReplaceObject, WriteMode, PostingMode);
				
			EndIf;
			
		Except
			
			WriteErrorInfoOCRHandlerImport(19, ErrorDescription(), RuleName, Source, 
			ObjectType, Undefined, "BeforeImportObject");    
			
		EndTry;
		
		If Cancel Then // Canceling object import
			
			deSkip(ExchangeFile, "Object");
			Return Undefined;
			
		EndIf;
		
	EndIf;
	
	ConstantOperatingMode = False;
	ConstantName = "";
	
	GlobalRefSn = 0;
	RefSn = 0;
	ObjectParameters = Undefined;
	WriteObject = True;
	// The flag is shows whether the object was found by search fields in the object 
	// mapping mode.
	// If the flag is set, source to target UUID mapping data is added to the mapping register.
	ObjectFoundBySearchFields = False;
	
	While ExchangeFile.Read() Do
		
		NodeName = ExchangeFile.LocalName;
		
		If NodeName = "Property"
			Or NodeName = "ParameterValue" Then
			
			IsParameterForObject = (NodeName = "ParameterValue");
			
			If Object = Undefined Then
				
				// The object was not found and was not created, attempting to do it now
				ObjectFound = False;
				
				// OnImportObject event handler
				If HasOnImportHandler Then
					
					ObjectModified = True;
					// Rewriting the object if OnImportHandler exists, because of possible changes
					Try
						
						If SL20CompatibilityMode() Then
							
							Execute(Rule.OnImport);
							
						Else
							
							ExecuteHandler_OCR_OnImportObject(ExchangeFile, ObjectFound, Object, DontReplaceObject, ObjectModified, Rule);
							
							
						EndIf;
						
					Except
						
						WriteErrorInfoOCRHandlerImport(20, ErrorDescription(), RuleName, Source, 
						ObjectType, Object, "OnImportObject");      
						
					EndTry;       
					
				EndIf;
				
				// Failed to create the object in the event, creating it now
				If Object = Undefined Then
					
					If ObjectTypeName = "Constants" Then
						
						Object = Undefined;
						ConstantOperatingMode = True;
						
					Else
						
						CreateNewObject(ObjectType, SearchProperties, Object, False, , RefSn, GlobalRefSn, Rule, ObjectParameters);
						
					EndIf;
					
				EndIf;
				
			EndIf; 
			
			
			Name                 = deAttribute(ExchangeFile, StringType,  "Name");
			DontReplaceProperty  = deAttribute(ExchangeFile, BooleanType, "DontReplace");
			OCRName              = deAttribute(ExchangeFile, StringType,  "OCRName");
			
			If ConstantOperatingMode Then
				
				Object = Constants[Name].CreateValueManager(); 
				ConstantName = Name;
				Name = "Value";
				
			ElsIf Not IsParameterForObject
				And ((ObjectFound And DontReplaceProperty) 
				Or (Name = "IsFolder") 
				Or (Object[Name] = NULL)) Then
				
				// Unknown property
				deSkip(ExchangeFile, NodeName);
				Continue;
				
			EndIf; 
			
			
			// Reading and setting the property value
			PropertyType = GetPropertyTypeByAdditionalData(TypeInformation, Name);
			Value = ReadProperty(PropertyType,,, OCRName);
			
			If IsParameterForObject Then
				
				// Supplementing the object parameter collection
				AddParameterIfNecessary(ObjectParameters, Name, Value);
				
			Else
				
				Try
					
					Object[Name] = Value;
					
				Except
					
					LR = GetLogRecordStructure(26, ErrorDescription());
					LR.OCRName         = RuleName;
					LR.Sn              = Sn;
					LR.GSn             = GSn;
					LR.Source          = Source;
					LR.Object          = Object;
					LR.ObjectType      = ObjectType;
					LR.Property        = Name;
					LR.Value           = Value;
					LR.ValueType       = TypeOf(Value);
					ErrorMessageString = WriteToExecutionLog(26, LR, True);
					
					If Not ContinueOnError Then
						Raise ErrorMessageString;
					EndIf;
					
				EndTry;
				
			EndIf;
			
		ElsIf NodeName = "Ref" Then
			
			// Item reference. Getting the object by reference and then setting properties
			InfobaseObjectMaps = Undefined;
			CreatedObject = Undefined;
			DontCreateObjectIfNotFound = Undefined;
			KnownUUIDRef = Undefined;
			DontReplaceCreatedInTargetObject = False;
			RecordObjectChangeAtSenderNode = False;
			
			Ref = FindObjectByRef(ObjectType,
			SearchProperties,
			SearchPropertiesDontReplace,
			ObjectFound,
			CreatedObject,
			DontCreateObjectIfNotFound,
			True,
			GlobalRefSn,
			RefSn,
			ObjectFoundBySearchFields,
			KnownUUIDRef,
			True,
			ObjectParameters,
			DontReplaceCreatedInTargetObject,
			ObjectCreatedInCurrentInfobase,
			RecordObjectChangeAtSenderNode,
			UUIDString,
			RuleName,
			InfobaseObjectMaps
			);
			
			If ObjectTypeName = "Enum" Then
				
				Object = Ref;
				
			Else
				
				Object = GetObjectByRefAndAdditionalInformation(CreatedObject, Ref);
				
				If Object = Undefined Then
					
					deSkip(ExchangeFile, "Object");
					Break; 
					
				EndIf;
				
				If ObjectFound And DontReplaceObject And (Not HasOnImportHandler) Then
					
					deSkip(ExchangeFile, "Object");
					Break;
					
				EndIf;
				
				If Ref = Undefined Then
					
					
					NumberForStack = ?(Sn = 0, GSn, Sn);
					SupplementNotWrittenObjectStack(NumberForStack, CreatedObject, KnownUUIDRef, ObjectType,
					ObjectTypeName, Rule.GenerateNewNumberOrCodeIfNotSet, ObjectParameters);
					
				EndIf;
				
			EndIf;
			
			// OnImportObject event handler
			If HasOnImportHandler Then
				
				Try
					
					If SL20CompatibilityMode() Then
						
						Execute(Rule.OnImport);
						
					Else
						
						ExecuteHandler_OCR_OnImportObject(ExchangeFile, ObjectFound, Object, DontReplaceObject, ObjectModified, Rule);
						
						
					EndIf;
					
				Except
					
					WriteErrorInfoOCRHandlerImport(20, ErrorDescription(), RuleName, Source,
					ObjectType, Object, "OnImportObject");
					
				EndTry;
				
				If ObjectFound And DontReplaceObject Then
					
					deSkip(ExchangeFile, "Object");
					Break;
					
				EndIf;
				
			EndIf;
			
			
			If RecordObjectChangeAtSenderNode = True Then
				Object.AdditionalProperties.Insert("RecordObjectChangeAtSenderNode");
			EndIf;
			
			
			Object.AdditionalProperties.Insert("InfobaseObjectMaps", InfobaseObjectMaps);
			
		ElsIf NodeName = "TabularSection"
			Or NodeName = "RecordSet" Then
			
			
			If DataImportToValueTableMode()
				And ObjectTypeName <> "ExchangePlan" Then
				deSkip(ExchangeFile, NodeName);
				Continue;
			EndIf;
			
			If Object = Undefined Then
				
				ObjectFound = False;
				
				// OnImportObject event handler
				
				If HasOnImportHandler Then
					
					Try
						
						
						If SL20CompatibilityMode() Then
							
							Execute(Rule.OnImport);
							
						Else
							
							ExecuteHandler_OCR_OnImportObject(ExchangeFile, ObjectFound, Object, DontReplaceObject, ObjectModified, Rule);
							
							
						EndIf;
						
					Except
						
						WriteErrorInfoOCRHandlerImport(20, ErrorDescription(), RuleName, Source, 
						ObjectType, Object, "OnImportObject");       
						
					EndTry;
					
				EndIf;
				
			EndIf;
			
			
			Name                = deAttribute(ExchangeFile, StringType, "Name");
			DontReplaceProperty = deAttribute(ExchangeFile, BooleanType, "DontReplace");
			DontClear           = deAttribute(ExchangeFile, BooleanType, "DontClear");
			
			If ObjectFound And DontReplaceProperty Then
				
				deSkip(ExchangeFile, NodeName);
				Continue;
				
			EndIf;
			
			If Object = Undefined Then
				
				CreateNewObject(ObjectType, SearchProperties, Object, False, , RefSn, GlobalRefSn, Rule, ObjectParameters);
				
			EndIf;
			
			If NodeName = "TabularSection" Then
				
				// Importing items from the tabular section
				ImportTabularSection(Object, Name, TypeInformation, ObjectParameters, Rule);
				
			ElsIf NodeName = "RecordSet" Then
				
				// Importing register records
				ImportRegisterRecords(Object, Name, Not DontClear, TypeInformation, ObjectParameters, Rule);
				
			EndIf;
			
		ElsIf (NodeName = "Object") And (ExchangeFile.NodeType = XMLNodeTypeEndElement) Then
			
			Cancel = False;
			
			// AfterImportObject global event handler
			If HasAfterImportObjectGlobalHandler Then
				
				
				ObjectModified = True;
				
				Try
					
					If SL20CompatibilityMode() Then
						
						Execute(Conversion.AfterImportObject);
						
					Else
						
						ExecuteHandler_Conversion_AfterImportObject(ExchangeFile, Cancel, Ref, Object, ObjectParameters,
						ObjectModified, ObjectTypeName, ObjectFound);
						
					EndIf;
					
				Except
					
					WriteErrorInfoOCRHandlerImport(54, ErrorDescription(), RuleName, Source, 
					ObjectType, Object, NStr("en = 'AfterImportObject (global)'"));     
					
				EndTry;
				
			EndIf;
			
			
			// AfterImportObject event handler
			If HasAfterImportHandler Then
				
				Try
					
					
					If SL20CompatibilityMode() Then
						
						Execute(Rule.AfterImport);
						
					Else
						
						ExecuteHandler_OCR_AfterImportObject(ExchangeFile, Cancel, Ref, Object, ObjectParameters,
						ObjectModified, ObjectTypeName, ObjectFound, Rule);
						
					EndIf;
					
				Except
					
					WriteErrorInfoOCRHandlerImport(21, ErrorDescription(), RuleName, Source, 
					ObjectType, Object, "AfterImportObject");    
					
				EndTry;
				
			EndIf;
			
			ItemReceive = DataItemReceive.Auto;
			SendBack = False;
			
			If ObjectTypeName <> "Enum" Then
				Object.AdditionalProperties.Insert("DataExchange", New Structure("DataAnalysis", Not DataImportIntoInfobaseMode()));
			EndIf;
			
			If ExchangeObjectPriority <> Enums.ExchangeObjectPriorities.ReceivedExchangeObjectPriorityHigher Then
				StandardSubsystemsServer.OnReceiveDataFromSlave(Object, ItemReceive, SendBack, ExchangeNodeDataImport);
			Else
				StandardSubsystemsServer.OnReceiveDataFromMaster(Object, ItemReceive, SendBack, ExchangeNodeDataImport);
			EndIf;
			
			If ItemReceive = DataItemReceive.Ignore Then
				Cancel = True;
			EndIf;
			If Cancel Then
				DeleteFromNotWrittenObjectStack(Sn, GSn);
				Return Undefined;
			EndIf;   
			
			If ObjectTypeName = "Document" Then
				
				If WriteMode = "Posting" Then
					
					WriteMode = DocumentWriteMode.Posting;
					
				ElsIf WriteMode = "UndoPosting" Then
					
					WriteMode = DocumentWriteMode.UndoPosting; 
					
				Else
					
					// Determining the writing mode
					If Object.Posted Then
						
						WriteMode = DocumentWriteMode.Posting;
						
					Else
						
						// a document in general can be conducted or no
						PostableDocument = (Object.Metadata().Posting = EnableDocumentPosting);
						
						If PostableDocument Then
							WriteMode = DocumentWriteMode.UndoPosting;
						Else
							WriteMode = DocumentWriteMode.Write;
						EndIf;
						
					EndIf;
					
				EndIf;    
				
				PostingMode = ?(PostingMode = "RealTime", DocumentPostingMode.RealTime, DocumentPostingMode.Regular);    
				
				// Clearing the deletion mark to post the marked for deletion object
				If Object.DeletionMark
					And (WriteMode = DocumentWriteMode.Posting) Then
					
					Object.DeletionMark = False;
					
				EndIf;
				
				GenerateNumberCodeIfNecessary(GenerateNewNumberOrCodeIfNotSet, Object, 
				ObjectTypeName, True);
				
				If DataImportIntoInfobaseMode() Then
					
					Try
						
						// Checking for conflicts and writing the document
						
						
						// Writing documents that no need to post
						If WriteMode = DocumentWriteMode.Write Then
							
							
							// Disabling the object registration mechanism when the document posting is cleared.
							// The registration mechanism will be executed
							// on a deferred document posting (for optimizing data import performance).
							Object.AdditionalProperties.Insert("DisableObjectChangeRecordMechanism");
							
							WriteObjectToInfobase(Object, ObjectType, WriteObject, SendBack);
							
							If WriteObject
								And Object <> Undefined
								And Object.Ref <> Undefined Then
								
								ObjectsForDeferredPosting().Insert(Object.Ref, Object.AdditionalProperties);
								
							EndIf;
							
						ElsIf WriteMode = DocumentWriteMode.UndoPosting Then
							
							UndoObjectPostingInInfobase(Object, ObjectType, WriteObject);
							
						ElsIf WriteMode = DocumentWriteMode.Posting Then
							
							// Disabling the object registration mechanism when  
							// the document posting is cleared.
							// The registration mechanism will be executed on a deferred document
							// posting (for optimizing data import performance).
							Object.AdditionalProperties.Insert("DisableObjectChangeRecordMechanism");
							
							UndoObjectPostingInInfobase(Object, ObjectType, WriteObject);
							
							// If the document has been successfully written and its reference exists,
							// putting the document into the posting queue.
							If WriteObject And Object <> Undefined
								And Object.Ref <> Undefined Then
								
								TableRow = DocumentsForDeferredPosting().Add();
								TableRow.DocumentRef    = Object.Ref;
								TableRow.DocumentDate   = Object.Date;
								
								AdditionalPropertiesForDeferredPosting().Insert(Object.Ref, Object.AdditionalProperties);
								
							EndIf;
							
						EndIf;
						
					Except
						
						ErrorDescriptionString = ErrorDescription();
						
						If WriteObject Then
							// Failed to perform necessary actions for the document
							WriteDocumentInSafeMode(Object, ObjectType);
						EndIf;
						
						LR         = GetLogRecordStructure(25, ErrorDescriptionString);
						LR.OCRName = RuleName;
						
						If Not IsBlankString(Source) Then
							
							LR.Source = Source;
							
						EndIf;
						
						LR.ObjectType = ObjectType;
						LR.Object     = String(Object);
						WriteToExecutionLog(25, LR);
						
						MessageString = NStr("en = 'Writing the %1 document failed with the following error: %2'");
						MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, String(Object), ErrorDescriptionString);
						
						// Failed to write the object in the ordinary mode, preparing an error message
						Raise MessageString;
						
					EndTry;
					
					DeleteFromNotWrittenObjectStack(Sn, GSn);
					
				EndIf;
				
			ElsIf ObjectTypeName <> "Enum" Then
				
				If ObjectTypeName = "InformationRegister" Then
					
					Periodical = PropertyStructure.Periodical;
					
					If Periodical Then
						
						If Not ValueIsFilled(Object.Period) Then
							SetCurrentDateToAttribute(Object.Period);
						EndIf;
						
					EndIf;
					
				EndIf;
				
				GenerateNumberCodeIfNecessary(GenerateNewNumberOrCodeIfNotSet, Object,
				ObjectTypeName, True);
				
				If DataImportIntoInfobaseMode() Then
					
					
					// Disabling the object registration mechanism when the document posting is cleared.
					// The registration mechanism will be executed on a deferred
					//  document posting (for optimizing data import performance).
					Object.AdditionalProperties.Insert("DisableObjectChangeRecordMechanism");
					
					
					WriteObjectToInfobase(Object, ObjectType, WriteObject, SendBack);
					
					
					// If the object is written successfully and
					// reference is created, put the object into the queue to write.
					
					If WriteObject
						And Object <> Undefined
						And Object.Ref <> Undefined Then
						
						ObjectsForDeferredPosting().Insert(Object.Ref, Object.AdditionalProperties);
						
					EndIf;
					
					
					If Not (ObjectTypeName = "InformationRegister"
						Or ObjectTypeName = "Constants") Then
						
						DeleteFromNotWrittenObjectStack(Sn, GSn);
						
					EndIf;
					
				EndIf;
				
			EndIf;
			
			IsReferenceTypeObject = Not(ObjectTypeName = "InformationRegister"
			Or ObjectTypeName = "Constants");
			
			Break;
			
		ElsIf NodeName = "SequenceRecordSet" Then
			
			deSkip(ExchangeFile);
			
		ElsIf NodeName = "Types" Then
			
			If Object = Undefined Then
				
				ObjectFound = False;
				Ref  = CreateNewObject(ObjectType, SearchProperties, Object, , , RefSn, GlobalRefSn, Rule, ObjectParameters);
				
			EndIf; 
			
			ObjectTypeDescription = ImportObjectTypes(ExchangeFile);
			
			If ObjectTypeDescription <> Undefined Then
				
				Object.ValueType = ObjectTypeDescription;
				
			EndIf; 
			
		Else
			
			WriteToExecutionLog(9);
			Break;
			
		EndIf;
		
	EndDo;
	
	Return Object;
	
EndFunction 

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS FOR EXPORTING DATA BY EXCHANGE RULES

Function GetDocumentRegisterRecordSet(DocumentRef, SourceKind, RegisterName)
	
	If SourceKind = "AccumulationRegisterRecordSet" Then
		
		DocumentRegisterRecordSet = AccumulationRegisters[RegisterName].CreateRecordSet();
		
	ElsIf SourceKind = "InformationRegisterRecordSet" Then
		
		DocumentRegisterRecordSet = InformationRegisters[RegisterName].CreateRecordSet();
		
	ElsIf SourceKind = "AccountingRegisterRecordSet" Then
		
		DocumentRegisterRecordSet = AccountingRegisters[RegisterName].CreateRecordSet();
		
	ElsIf SourceKind = "CalculationRegisterRecordSet" Then 
		
		DocumentRegisterRecordSet = CalculationRegisters[RegisterName].CreateRecordSet();
		
	Else
		
		Return Undefined;
		
	EndIf;
	
	DocumentRegisterRecordSet.Filter.Recorder.Set(DocumentRef.Ref);
	DocumentRegisterRecordSet.Read();
	
	Return DocumentRegisterRecordSet;
	
EndFunction

// Generates target object property nodes based on the specified property conversion
// rule collection.
//
// Parameters:
//  Source                 - arbitrary data source.
//  Target                 - target object XML node.
//  IncomingData           - arbitrary auxiliary data passed to the rule for performing 
//                           the conversion.
//  OutgoingData           - arbitrary auxiliary data, passed to the property object 
//                           conversion rules.
//  OCR                    - reference to the object conversion rule (property
//                           conversion rule collection parent).
//  PGCR                   - reference to the property group conversion rule.
//  PropertyCollectionNode - property collection XML node.
// 
Procedure ExportPropertyGroup(Source, Target, IncomingData, OutgoingData, OCR, PGCR, PropertyCollectionNode, 
	ExportRefOnly, TempFileList = Undefined, ExportRegisterRecordSetRow = False)
	
	
	ObjectCollection  = Undefined;
	DontReplace       = PGCR.DontReplace;
	DontClear         = False;
	ExportGroupToFile = PGCR.ExportGroupToFile;
	
	// BeforeProcessExport handler
	
	If PGCR.HasBeforeProcessExportHandler Then
		
		Cancel = False;
		Try
			
			
			If SL20CompatibilityMode() Then
				
				Execute(PGCR.BeforeProcessExport);
				
			Else
				
				ExecuteHandler_PGCR_BeforeProcessExport(ExchangeFile, Source, Target, IncomingData, OutgoingData, OCR,
				PGCR, Cancel, ObjectCollection, DontReplace, PropertyCollectionNode, DontClear);
				
			EndIf;
			
		Except
			
			LR = GetLogRecordStructure(48, ErrorDescription());
			LR.OCR   = OCR.Name + "  (" + OCR.Description + ")";
			LR.PGCR  = PGCR.Name + "  (" + PGCR.Description + ")";
			
			Try
				LR.Object = String(Source) + "  (" + TypeOf(Source) + ")";
			Except
				LR.Object = "(" + TypeOf(Source) + ")";
			EndTry;
			
			LR.Handler         = "BeforePropertyGroupExport";
			ErrorMessageString = WriteToExecutionLog(48, LR);
			
			If Not ContinueOnError Then
				Raise ErrorMessageString;
			EndIf;
			
		EndTry;
		
		If Cancel Then // Canceling property group processing   
			Return;
			
		EndIf;
		
	EndIf;
	
	
	TargetKind = PGCR.TargetKind;
	SourceKind = PGCR.SourceKind;
	
	
	// Creating a node of subordinate object collection
	PropertyNodeStructure = Undefined;
	ObjectCollectionNode = Undefined;
	MasterNodeName = "";
	
	If TargetKind = "TabularSection" Then
		
		MasterNodeName = "TabularSection";
		
		CreateObjectsForXMLWriter(PropertyNodeStructure, ObjectCollectionNode, TRUE, PGCR.Target, MasterNodeName);
		
		If DontReplace Then
			
			AddAttributeForXMLWriter(PropertyNodeStructure, ObjectCollectionNode, "DontReplace", "true");
			
		EndIf;
		
		If DontClear Then
			
			AddAttributeForXMLWriter(PropertyNodeStructure, ObjectCollectionNode, "DontClear", "true");
			
		EndIf;
		
	ElsIf TargetKind = "SubordinateCatalog" Then
		
		
	ElsIf TargetKind = "SequenceRecordSet" Then
		
		MasterNodeName = "RecordSet";
		
		CreateObjectsForXMLWriter(PropertyNodeStructure, ObjectCollectionNode, TRUE, PGCR.Target, MasterNodeName);
		
	ElsIf Find(TargetKind, "RegisterRecordSet") > 0 Then
		
		MasterNodeName = "RecordSet";
		
		CreateObjectsForXMLWriter(PropertyNodeStructure, ObjectCollectionNode, TRUE, PGCR.Target, MasterNodeName);
		
		If DontReplace Then
			
			AddAttributeForXMLWriter(PropertyNodeStructure, ObjectCollectionNode, "DontReplace", "true");
			
		EndIf;
		
		If DontClear Then
			
			AddAttributeForXMLWriter(PropertyNodeStructure, ObjectCollectionNode, "DontClear", "true");
			
		EndIf;
		
	Else  // Simple group
		
		ExportProperties(Source, Target, IncomingData, OutgoingData, OCR, PGCR.GroupRules, 
		PropertyCollectionNode, , , True, False);
		
		If PGCR.HasAfterProcessExportHandler Then
			
			Try
				
				
				If SL20CompatibilityMode() Then
					
					Execute(PGCR.AfterProcessExport);
					
				Else
					
					ExecuteHandler_PGCR_AfterProcessExport(ExchangeFile, Source, Target, IncomingData, OutgoingData,
					OCR, PGCR, Cancel, PropertyCollectionNode, ObjectCollectionNode);
					
				EndIf;
				
			Except
				
				LR = GetLogRecordStructure(49, ErrorDescription());
				LR.OCR  = OCR.Name + "  (" + OCR.Description + ")";
				LR.PGCR = PGCR.Name + "  (" + PGCR.Description + ")";
				
				Try
					LR.Object = String(Source) + "  (" + TypeOf(Source) + ")";
				Except
					LR.Object = "(" + TypeOf(Source) + ")";
				EndTry;
				
				LR.Handler         = "AfterProcessPropertyGroupExport";
				ErrorMessageString = WriteToExecutionLog(49, LR);
				
				If Not ContinueOnError Then
					Raise ErrorMessageString;
				EndIf;
				
			EndTry;
			
		EndIf;
		
		Return;
		
	EndIf;
	
	
	// Getting the collection of subordinate objects
	
	If ObjectCollection <> Undefined Then
		
		// The collection was initialized in the BeforeProcess handler
		
	ElsIf PGCR.GetFromIncomingData Then
		
		Try
			
			ObjectCollection = IncomingData[PGCR.Target];
			
			If TypeOf(ObjectCollection) = Type("QueryResult") Then
				
				ObjectCollection = ObjectCollection.Unload();
				
			EndIf;
			
		Except
			
			LR = GetLogRecordStructure(66, ErrorDescription());
			LR.OCR  = OCR.Name + "  (" + OCR.Description + ")";
			LR.PGCR = PGCR.Name + "  (" + PGCR.Description + ")";
			
			Try
				LR.Object = String(Source) + "  (" + TypeOf(Source) + ")";
			Except
				LR.Object = "(" + TypeOf(Source) + ")";
			EndTry;
			
			ErrorMessageString = WriteToExecutionLog(66, LR);
			
			If Not ContinueOnError Then
				Raise ErrorMessageString;
			EndIf;
			
			Return;
		EndTry;
		
	ElsIf SourceKind = "TabularSection" Then
		
		ObjectCollection = Source[PGCR.Source];
		
		If TypeOf(ObjectCollection) = Type("QueryResult") Then
			
			ObjectCollection = ObjectCollection.Unload();
			
		EndIf;
		
	ElsIf SourceKind = "SubordinateCatalog" Then
		
	ElsIf Find(SourceKind, "RegisterRecordSet") > 0 Then
		
		ObjectCollection = GetDocumentRegisterRecordSet(Source, SourceKind, PGCR.Source);
		
	ElsIf IsBlankString(PGCR.Source) Then
		
		ObjectCollection = Source[PGCR.Target];
		
		If TypeOf(ObjectCollection) = Type("QueryResult") Then
			
			ObjectCollection = ObjectCollection.Unload();
			
		EndIf;
		
	EndIf;
	
	ExportGroupToFile = ExportGroupToFile Or (ObjectCollection.Count() > 1000);
	ExportGroupToFile = ExportGroupToFile And Not ExportRegisterRecordSetRow;
	ExportGroupToFile = ExportGroupToFile And Not IsExchangeOverExternalConnection();
	
	If ExportGroupToFile Then
		PGCR.XMLNodeRequiredOnExport = False;
		If TempFileList = Undefined Then
			TempFileList = New ValueList();
		EndIf;
		
		RecordFileName = GetTempFileName();
		TempFileList.Add(RecordFileName);  
		
		TempRecordFile = New TextWriter;
		Try
			
			TempRecordFile.Open(RecordFileName, TextEncoding.UTF8);
			
		Except
			
			
			ErrorMessageString = StringFunctionsClientServer.SubstituteParametersInString(NStr("en = 'Error creating temporary file for data export.
			|Name file ""%1"".
			|Error details:
			|%2'"),
			String(RecordFileName),
			DetailErrorDescription(ErrorInfo()));
			
			WriteToExecutionLog(ErrorMessageString);
			
		EndTry; 
		
		InformationToWriteToFile = ObjectCollectionNode.Close();
		TempRecordFile.WriteLine(InformationToWriteToFile);  
		
	EndIf;
	
	For Each CollectionObject In ObjectCollection Do
		
		
		// BeforeExport handler
		If PGCR.HasBeforeExportHandler Then
			
			Cancel = False;
			
			Try
				
				
				If SL20CompatibilityMode() Then
					
					Execute(PGCR.BeforeExport);
					
				Else
					
					ExecuteHandler_PGCR_BeforeExportProperty(ExchangeFile, Source, Target, IncomingData, OutgoingData, OCR,
					PGCR, Cancel, CollectionObject, PropertyCollectionNode, ObjectCollectionNode);
					
				EndIf;
				
			Except
				
				ErrorMessageString = WriteToExecutionLog(50);
				If Not ContinueOnError Then
					Raise ErrorMessageString;
				EndIf;
				
				Break;
				
			EndTry;
			
			If Cancel Then // Canceling subordinate object export
				
				Continue;
				
			EndIf;
			
		EndIf; 
		
		
		// OnExport handler
		
		If PGCR.XMLNodeRequiredOnExport Or ExportGroupToFile Then
			CollectionObjectNode = CreateNode("Record");
		Else
			ObjectCollectionNode.WriteStartElement("Record");
			CollectionObjectNode = ObjectCollectionNode;
		EndIf;
		
		StandardProcessing = True;
		
		If PGCR.HasOnExportHandler Then
			
			Try
				
				
				If SL20CompatibilityMode() Then
					
					Execute(PGCR.OnExport);
					
				Else
					
					ExecuteHandler_PGCR_OnExportProperty(ExchangeFile, Source, Target, IncomingData, OutgoingData, OCR,
					PGCR, CollectionObject, ObjectCollectionNode, CollectionObjectNode,
					PropertyCollectionNode, StandardProcessing);
					
				EndIf;
				
			Except
				
				ErrorMessageString = WriteToExecutionLog(51);
				If Not ContinueOnError Then
					Raise ErrorMessageString;
				EndIf;
				
				Break;
				
			EndTry;
			
		EndIf;
		
		
		// Exporting the collection object properties
		If StandardProcessing Then
			
			If PGCR.GroupRules.Count() > 0 Then
				
				ExportProperties(Source, Target, IncomingData, OutgoingData, OCR, PGCR.GroupRules, 
				CollectionObjectNode, CollectionObject, , True, False);
				
			EndIf;
			
		EndIf;
		
		
		// AfterExport handler
		If PGCR.HasAfterExportHandler Then
			
			Cancel = False;
			
			Try
				
				
				If SL20CompatibilityMode() Then
					
					Execute(PGCR.AfterExport);
					
				Else
					
					ExecuteHandler_PGCR_AfterExportProperty(ExchangeFile, Source, Target, IncomingData, OutgoingData,
					OCR, PGCR, Cancel, CollectionObject, ObjectCollectionNode,
					PropertyCollectionNode, CollectionObjectNode);
					
				EndIf;
				
			Except
				
				ErrorMessageString = WriteToExecutionLog(52);
				If Not ContinueOnError Then
					Raise ErrorMessageString;
				EndIf;
				
				Break;
				
			EndTry; 
			
			If Cancel Then // Canceling subordinate object export
				
				Continue;
				
			EndIf;
			
		EndIf;
		
		If PGCR.XMLNodeRequiredOnExport Then
			AddSubordinateNode(ObjectCollectionNode, CollectionObjectNode);
		EndIf;
		
		// Filling the file with node objects
		If ExportGroupToFile Then
			
			CollectionObjectNode.WriteEndElement();
			InformationToWriteToFile = CollectionObjectNode.Close();
			TempRecordFile.WriteLine(InformationToWriteToFile);
			
		Else
			
			If Not PGCR.XMLNodeRequiredOnExport Then
				
				ObjectCollectionNode.WriteEndElement();
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	// AfterProcessExport handler
	If PGCR.HasAfterProcessExportHandler Then
		
		Cancel = False;
		
		Try
			
			
			If SL20CompatibilityMode() Then
				
				Execute(PGCR.AfterProcessExport);
				
			Else
				
				ExecuteHandler_PGCR_AfterProcessExport(ExchangeFile, Source, Target, IncomingData, OutgoingData,
				OCR, PGCR, Cancel, PropertyCollectionNode, ObjectCollectionNode);
				
			EndIf;
			
			
		Except
			
			LR = GetLogRecordStructure(49, ErrorDescription());
			LR.OCR  = OCR.Name + "  (" + OCR.Description + ")";
			LR.PGCR = PGCR.Name + "  (" + PGCR.Description + ")";
			
			Try
				LR.Object = String(Source) + "  (" + TypeOf(Source) + ")";
			Except
				LR.Object = "(" + TypeOf(Source) + ")";
			EndTry;
			
			LR.Handler         = "AfterProcessPropertyGroupExport";
			ErrorMessageString = WriteToExecutionLog(49, LR);
			
			If Not ContinueOnError Then
				Raise ErrorMessageString;
			EndIf;
			
		EndTry; 
		
		If Cancel Then // Cancel from records collection slave Objects
			
			Return;
			
		EndIf;
		
	EndIf;
	
	If ExportGroupToFile Then
		TempRecordFile.WriteLine("</" + MasterNodeName + ">"); // Closing the node
		TempRecordFile.Close(); // Closing the file
	Else
		WriteDataToMasterNode(PropertyCollectionNode, PropertyNodeStructure, ObjectCollectionNode);
	EndIf;
	
EndProcedure

Procedure GetPropertyValue(Value, CollectionObject, OCR, PCR, IncomingData, Source, DataSelection = Undefined)
	
	If Value <> Undefined Then
		Return;
	EndIf;
	
	If PCR.GetFromIncomingData Then
		
		ObjectForReceivingData = IncomingData;
		
		If Not IsBlankString(PCR.Target) Then
			
			PropertyName = PCR.Target;
			
		Else
			
			PropertyName = PCR.ParameterForTransferName;
			
		EndIf;
		
		ErrorCode = ?(CollectionObject <> Undefined, 67, 68);
		
	ElsIf CollectionObject <> Undefined Then
		
		ObjectForReceivingData = CollectionObject;
		
		If Not IsBlankString(PCR.Source) Then
			
			PropertyName = PCR.Source;
			ErrorCode = 16;
			
		Else
			
			PropertyName = PCR.Target;
			ErrorCode = 17;
			
		EndIf;
		
	ElsIf DataSelection <> Undefined Then
		
		ObjectForReceivingData = DataSelection; 
		
		If Not IsBlankString(PCR.Source) Then
			
			PropertyName = PCR.Source;
			ErrorCode = 13;
			
		Else
			
			Return;
			
		EndIf;
		
	Else
		
		ObjectForReceivingData = Source;
		
		If Not IsBlankString(PCR.Source) Then
			
			PropertyName = PCR.Source;
			ErrorCode = 13;
			
		Else
			
			PropertyName = PCR.Target;
			ErrorCode = 14;
			
		EndIf;
		
	EndIf;
	
	
	Try
		
		Value = ObjectForReceivingData[PropertyName];
		
	Except
		
		If ErrorCode <> 14 Then
			WriteErrorInfoPCRHandlers(ErrorCode, ErrorDescription(), OCR, PCR, Source, "");
		EndIf;
		
	EndTry;     
	
EndProcedure

Procedure ExportItemPropertyType(PropertyNode, PropertyType)
	
	SetAttribute(PropertyNode, "Type", PropertyType); 
	
EndProcedure

Procedure _ExportExtDimension(Source, Target, IncomingData, OutgoingData, OCR, PCR, 
	PropertyCollectionNode = Undefined, CollectionObject = Undefined, Val ExportRefOnly = False)
	// Variables for supporting the event handler script debugging mechanism
	Var TargetType, Empty, Expression, DontReplace, PropertyOCR, PropertyNode;
	
	// Initializing the value
	Value = Undefined;
	OCRName = "";
	ExtDimensionTypeOCRName = "";
	
	// BeforeExport handler
	If PCR.HasBeforeExportHandler Then
		
		Cancel = False;
		
		Try
			
			
			ExportObject = Not ExportRefOnly;
			
			If SL20CompatibilityMode() Then
				
				Execute(PCR.BeforeExport);
				
			Else
				
				ExecuteHandler_PCR_BeforeExportProperty(ExchangeFile, Source, Target, IncomingData, OutgoingData,
				PCR, OCR, CollectionObject, Cancel, Value, TargetType, OCRName,
				ExtDimensionTypeOCRName, Empty, Expression, PropertyCollectionNode, DontReplace,
				ExportObject);
				
			EndIf;
			
			ExportRefOnly = Not ExportObject;
			
		Except
			
			WriteErrorInfoPCRHandlers(55, ErrorDescription(), OCR, PCR, Source, 
			"BeforeExportProperty", Value);    
			
		EndTry;
		
		If Cancel Then // Canceling export
			
			Return;
			
		EndIf;
		
	EndIf;
	
	GetPropertyValue(Value, CollectionObject, OCR, PCR, IncomingData, Source);
	
	If PCR.CastToLength <> 0 Then
		
		CastValueToLength(Value, PCR);
		
	EndIf;
	
	For Each KeyAndValue In Value Do
		
		ExtDimensionType = KeyAndValue.Key;
		ExtDimensions = KeyAndValue.Value;
		OCRName = "";
		
		// OnExport handler
		If PCR.HasOnExportHandler Then
			
			Cancel = False;
			
			Try
				
				
				ExportObject = Not ExportRefOnly;
				
				If SL20CompatibilityMode() Then
					
					Execute(PCR.OnExport);
					
				Else
					
					ExecuteHandler_PCR_OnExportProperty(ExchangeFile, Source, Target, IncomingData, OutgoingData,
					PCR, OCR, CollectionObject, Cancel, Value, KeyAndValue, ExtDimensionType,
					ExtDimensions, Empty, OCRName, PropertyOCR,PropertyNode, PropertyCollectionNode,
					ExtDimensionTypeOCRName, ExportObject);
					
				EndIf;
				
				ExportRefOnly = Not ExportObject;
				
			Except
				
				WriteErrorInfoPCRHandlers(56, ErrorDescription(), OCR, PCR, Source, 
				"OnExportProperty", Value);    
				
			EndTry;
			
			If Cancel Then // Canceling extra dimension export
				
				Continue;
				
			EndIf;
			
		EndIf;
		
		If ExtDimensions = Undefined
			Or FindRule(ExtDimensions, OCRName) = Undefined Then
			
			Continue;
			
		EndIf;
		
		ExtDimensionNode = CreateNode(PCR.Target);
		
		// Key
		PropertyNode = CreateNode("Property");
		
		If ExtDimensionTypeOCRName = "" Then
			
			OCRKey = FindRule(ExtDimensionType);
			
		Else
			
			OCRKey = FindRule(, ExtDimensionTypeOCRName);
			
		EndIf;
		
		SetAttribute(PropertyNode, "Name", "Key");
		ExportItemPropertyType(PropertyNode, OCRKey.Target);
		
		RefNode = ExportByRule(ExtDimensionType,, OutgoingData,, ExtDimensionTypeOCRName,, TRUE, OCRKey, , , , , False);
		
		If RefNode <> Undefined Then
			
			AddSubordinateNode(PropertyNode, RefNode);
			
		EndIf;
		
		AddSubordinateNode(ExtDimensionNode, PropertyNode);
		
		
		
		// Value
		PropertyNode = CreateNode("Property");
		
		OCRValue = FindRule(ExtDimensions, OCRName);
		
		TargetType = OCRValue.Target;
		
		IsNULL = False;
		Empty = deEmpty(ExtDimensions, IsNULL);
		
		If Empty Then
			
			If IsNULL 
				Or Value = Undefined Then
				
				Continue;
				
			EndIf;
			
			If IsBlankString(TargetType) Then
				
				TargetType = GetDataTypeForTarget(ExtDimensions);
				
			EndIf;   
			
			SetAttribute(PropertyNode, "Name", "Value");
			
			If Not IsBlankString(TargetType) Then
				SetAttribute(PropertyNode, "Type", TargetType);
			EndIf;
			
			deWriteElement(PropertyNode, "Empty");
			AddSubordinateNode(ExtDimensionNode, PropertyNode);
			
		Else
			
			IsRuleWithGlobalExport = False;
			RefNode = ExportByRule(ExtDimensions,, OutgoingData, , OCRName, , TRUE, OCRValue, , , , , False, IsRuleWithGlobalExport);
			
			SetAttribute(PropertyNode, "Name", "Value");
			ExportItemPropertyType(PropertyNode, TargetType);
			
			
			RefNodeType = TypeOf(RefNode);
			
			If RefNode = Undefined Then
				
				Continue;
				
			EndIf;
			
			AddPropertiesForExport(RefNode, RefNodeType, PropertyNode, IsRuleWithGlobalExport);      
			
			AddSubordinateNode(ExtDimensionNode, PropertyNode);
			
		EndIf; 
		
		
		
		// AfterExport handler
		If PCR.HasAfterExportHandler Then
			
			Cancel = False;
			
			Try
				
				
				If SL20CompatibilityMode() Then
					
					Execute(PCR.AfterExport);
					
				Else
					
					ExecuteHandler_PCR_AfterExportProperty(ExchangeFile, Source, Target, IncomingData, OutgoingData,
					PCR, OCR, CollectionObject, Cancel, Value, KeyAndValue, ExtDimensionType,
					ExtDimensions, OCRName, ExtDimensionTypeOCRName, PropertyOCR, PropertyNode,
					RefNode, PropertyCollectionNode, ExtDimensionNode);
					
				EndIf;
				
			Except
				
				WriteErrorInfoPCRHandlers(57, ErrorDescription(), OCR, PCR, Source, 
				"AfterExportProperty", Value);     
				
			EndTry;
			
			If Cancel Then // Canceling export
				
				Continue;
				
			EndIf;
			
		EndIf;
		
		AddSubordinateNode(PropertyCollectionNode, ExtDimensionNode);
		
	EndDo;
	
EndProcedure

Procedure AddPropertiesForExport(RefNode, RefNodeType, PropertyNode, IsRuleWithGlobalExport)
	
	If RefNodeType = StringType Then
		
		If Find(RefNode, "<Ref") > 0 Then
			
			PropertyNode.WriteRaw(RefNode);
			
		Else
			
			deWriteElement(PropertyNode, "Value", RefNode);
			
		EndIf;
		
	ElsIf RefNodeType = NumberType Then
		
		If IsRuleWithGlobalExport Then
			
			deWriteElement(PropertyNode, "GSn", RefNode);
			
		Else      
			
			deWriteElement(PropertyNode, "Sn", RefNode);
			
		EndIf;
		
	Else
		
		AddSubordinateNode(PropertyNode, RefNode);
		
	EndIf; 
	
EndProcedure

Procedure GetValueSettingPossibility(Value, ValueType, TargetType, PropertySet, TypeRequired)
	
	PropertySet = True;
	
	If ValueType = StringType Then
		
		If TargetType = "String"  Then
		ElsIf TargetType = "Number"  Then
			
			Value = Number(Value);
			
		ElsIf TargetType = "Boolean"  Then
			
			Value = Boolean(Value);
			
		ElsIf TargetType = "Date"  Then
			
			Value = Date(Value);
			
		ElsIf TargetType = "ValueStorage"  Then
			
			Value = New ValueStorage(Value);
			
		ElsIf TargetType = "UUID" Then
			
			Value = New UUID(Value);
			
		ElsIf IsBlankString(TargetType) Then
			
			TargetType = "String";
			TypeRequired = True;
			
		EndIf;
		
	ElsIf ValueType = NumberType Then
		
		If TargetType = "Number"
			Or TargetType = "String" Then
		ElsIf TargetType = "Boolean"  Then
			
			Value = Boolean(Value);
			
		ElsIf IsBlankString(TargetType) Then
			
			TargetType = "Number";
			TypeRequired = True;
			
		Else
			
			PropertySet = False;
			
		EndIf;
		
	ElsIf ValueType = DateType Then
		
		If TargetType = "Date"  Then
		ElsIf TargetType = "String"  Then
			
			Value = Left(String(Value), 10);
			
		ElsIf IsBlankString(TargetType) Then
			
			TargetType = "Date";
			TypeRequired = True;
			
		Else
			
			PropertySet = False;
			
		EndIf;    
		
	ElsIf ValueType = BooleanType Then
		
		If TargetType = "Boolean"  Then
		ElsIf TargetType = "Number"  Then
			
			Value = Number(Value);
			
		ElsIf IsBlankString(TargetType) Then
			
			TargetType = "Boolean";
			TypeRequired = True;
			
		Else
			
			PropertySet = False;
			
		EndIf;    
		
	ElsIf ValueType = ValueStorageType Then
		
		If IsBlankString(TargetType) Then
			
			TargetType = "ValueStorage";
			TypeRequired = True;
			
		ElsIf TargetType <> "ValueStorage"  Then
			
			PropertySet = False;
			
		EndIf;    
		
	ElsIf ValueType = UUIDType Then
		
		If TargetType = "UUID" Then
		ElsIf TargetType = "String" Then
			
			Value = String(Value);
			
		ElsIf IsBlankString(TargetType) Then
			
			TargetType = "UUID";
			TypeRequired = True;
			
		Else
			
			PropertySet = False;
			
		EndIf;    
		
	ElsIf ValueType = AccumulationRecordTypeType Then
		
		Value = String(Value);  
		
		Else 
		
		PropertySet = False;
		
	EndIf; 
	
EndProcedure

Function GetDataTypeForTarget(Value)
	
	TargetType = deValueTypeString(Value);
	
	// Checking for any ORR with the TargetType target type.
	// If no rule is found, passing "" to TargetType, otherwise returning TargetType.
	TableRow = ConversionRuleTable.Find(TargetType, "Target");
	
	If TableRow = Undefined Then
		
		If Not (TargetType = "String"
			Or TargetType = "Number"
			Or TargetType = "Date"
			Or TargetType = "Boolean"
			Or TargetType = "ValueStorage") Then
			
			TargetType = "";
		EndIf;
		
	EndIf;
	
	Return TargetType;
	
EndFunction

Procedure CastValueToLength(Value, PCR)
	
	Value = CastNumberToLength(String(Value), PCR.CastToLength);
	
EndProcedure

Procedure WriteStructureToXML(DataStructure, PropertyCollectionNode, IsOrdinaryProperty = True)
	
	PropertyCollectionNode.WriteStartElement(?(IsOrdinaryProperty, "Property", "ParameterValue"));
	
	For Each CollectionItem In DataStructure Do
		
		If CollectionItem.Key = "Expression"
			Or CollectionItem.Key = "Value"
			Or CollectionItem.Key = "Sn"
			Or CollectionItem.Key = "GSn" Then
			
			deWriteElement(PropertyCollectionNode, CollectionItem.Key, CollectionItem.Value);
			
		ElsIf CollectionItem.Key = "Ref" Then
			
			PropertyCollectionNode.WriteRaw(CollectionItem.Value);
			
		Else
			
			SetAttribute(PropertyCollectionNode, CollectionItem.Key, CollectionItem.Value);
			
		EndIf;
		
	EndDo;
	
	PropertyCollectionNode.WriteEndElement();  
	
EndProcedure

Procedure CreateComplexInformationForXMLWriter(DataStructure, PropertyNode, XMLNodeRequired, TargetName, ParameterName)
	
	If IsBlankString(ParameterName) Then
		
		CreateObjectsForXMLWriter(DataStructure, PropertyNode, XMLNodeRequired, TargetName, "Property");
		
	Else
		
		CreateObjectsForXMLWriter(DataStructure, PropertyNode, XMLNodeRequired, ParameterName, "ParameterValue");
		
	EndIf;
	
EndProcedure

Procedure CreateObjectsForXMLWriter(DataStructure, PropertyNode, XMLNodeRequired, NodeName, XMLNodeDescription = "Property")
	
	If XMLNodeRequired Then
		
		PropertyNode = CreateNode(XMLNodeDescription);
		SetAttribute(PropertyNode, "Name", NodeName);
		
	Else
		
		DataStructure = New Structure("Name", NodeName); 
		
	EndIf;  
	
EndProcedure

Procedure AddAttributeForXMLWriter(PropertyNodeStructure, PropertyNode, AttributeName, AttributeValue)
	
	If PropertyNodeStructure <> Undefined Then
		PropertyNodeStructure.Insert(AttributeName, AttributeValue);
	Else
		SetAttribute(PropertyNode, AttributeName, AttributeValue);
	EndIf;
	
EndProcedure

Procedure AddValueForXMLWriter(PropertyNodeStructure, PropertyNode, AttributeName, AttributeValue)
	
	If PropertyNodeStructure <> Undefined Then
		PropertyNodeStructure.Insert(AttributeName, AttributeValue);
	Else
		deWriteElement(PropertyNode, AttributeName, AttributeValue);
	EndIf;
	
EndProcedure

Procedure AddArbitraryDataForXMLWriter(PropertyNodeStructure, PropertyNode, AttributeName, AttributeValue)
	
	If PropertyNodeStructure <> Undefined Then
		PropertyNodeStructure.Insert(AttributeName, AttributeValue);
	Else
		PropertyNode.WriteRaw(AttributeValue);
	EndIf;
	
EndProcedure

Procedure WriteDataToMasterNode(PropertyCollectionNode, PropertyNodeStructure, PropertyNode, IsOrdinaryProperty = True)
	
	If PropertyNodeStructure <> Undefined Then
		WriteStructureToXML(PropertyNodeStructure, PropertyCollectionNode, IsOrdinaryProperty);
	Else
		AddSubordinateNode(PropertyCollectionNode, PropertyNode);
	EndIf;
	
EndProcedure

// Generates target object property nodes based on the specified property conversion 
// rule collection.
//
// Parameters:
// Source                 - arbitrary data source.
// Target                 - target object XML node.
// IncomingData           - arbitrary auxiliary data passed to the rule for performing
//                          the conversion.
// OutgoingData           - arbitrary auxiliary data passed to the property object
//                          conversion rules.
// OCR                    - reference to the object conversion rule (property
//                          conversion rules collection parent).
// PCRCollection          - property conversion rule collection.
// PropertyCollectionNode - property collection XML node.
// CollectionObject       - if this parameter is specified, collection object properties
//                          are exported, otherwise source object properties are
//                          exported.
// PredefinedItemName     - if this parameter is specified, the predefined item name is
//                          written to the properties. 
// 
Procedure ExportProperties(Source, 
	Target, 
	IncomingData, 
	OutgoingData, 
	OCR, 
	PCRCollection, 
	PropertyCollectionNode = Undefined, 
	CollectionObject = Undefined, 
	PredefinedItemName = Undefined, 
	Val OCRExportRefOnly = True, 
	Val IsRefExport = False, 
	Val ExportingObject = False, 
	RefSearchKey = "", 
	DontUseRulesWithGlobalExportAndDontRememberExported = False,
	RefsValueInAnotherInfobase = "",
	TempFileList = Undefined, 
	ExportRegisterRecordSetRow = False)
	
	// Variables for supporting the event handler script debugging mechanism
	Var KeyAndValue, ExtDimensionType, ExtDimensions, ExtDimensionTypeOCRName, ExtDimensionNode;     
	If PropertyCollectionNode = Undefined Then
		
		PropertyCollectionNode = Target;
		
	EndIf;
	
	PropertySelection = Undefined;
	
	If IsRefExport Then
		
		// Exporting the predefined item name if it is specified
		If PredefinedItemName <> Undefined Then
			
			PropertyCollectionNode.WriteStartElement("Property");
			SetAttribute(PropertyCollectionNode, "Name", "{PredefinedItemName}");
			deWriteElement(PropertyCollectionNode, "Value", PredefinedItemName);
			PropertyCollectionNode.WriteEndElement();
			
		EndIf;
		
	EndIf;
	
	For Each PCR In PCRCollection Do
		
		ExportRefOnly = OCRExportRefOnly;
		
		If PCR.SimplifiedPropertyExport Then
			
			
			// Creating the property node
			PropertyCollectionNode.WriteStartElement("Property");
			SetAttribute(PropertyCollectionNode, "Name", PCR.Target);
			
			If Not IsBlankString(PCR.TargetType) Then
				
				SetAttribute(PropertyCollectionNode, "Type", PCR.TargetType);
				
			EndIf;
			
			If PCR.DontReplace Then
				
				SetAttribute(PropertyCollectionNode, "DontReplace", "true");
				
			EndIf;
			
			If PCR.SearchByEqualDate  Then
				
				SetAttribute(PropertyCollectionNode, "SearchByEqualDate", "true");
				
			EndIf;
			
			Value = Undefined;
			GetPropertyValue(Value, CollectionObject, OCR, PCR, IncomingData, Source, PropertySelection);
			
			If PCR.CastToLength <> 0 Then
				
				CastValueToLength(Value, PCR);
				
			EndIf;
			
			IsNULL = False;
			Empty = deEmpty(Value, IsNULL);
			
			If Empty Then
				
				PropertyCollectionNode.WriteEndElement();
				Continue;
				
			EndIf;
			
			deWriteElement(PropertyCollectionNode, "Value", Value);
			
			PropertyCollectionNode.WriteEndElement();
			Continue;     
			
		ElsIf PCR.TargetKind = "AccountExtDimensionTypes" Then
			
			_ExportExtDimension(Source, Target, IncomingData, OutgoingData, OCR, 
			PCR, PropertyCollectionNode, CollectionObject, ExportRefOnly);
			
			Continue;
			
		ElsIf PCR.Name = "{UUID}" Then
			
			SourceRef = GetRefByObjectOrRef(Source, ExportingObject);
			
			UUID = SourceRef.UUID();
			
			PropertyCollectionNode.WriteStartElement("Property");
			SetAttribute(PropertyCollectionNode, "Name", "{UUID}");
			SetAttribute(PropertyCollectionNode, "Type", "String");
			SetAttribute(PropertyCollectionNode, "SourceType", OCR.SourceType);
			SetAttribute(PropertyCollectionNode, "TargetType", OCR.TargetType);
			deWriteElement(PropertyCollectionNode, "Value", UUID);
			PropertyCollectionNode.WriteEndElement();
			
			Continue;
			
		ElsIf PCR.IsFolder Then
			
			ExportPropertyGroup(
			Source, Target, IncomingData, OutgoingData, OCR, PCR, PropertyCollectionNode, 
			ExportRefOnly, TempFileList, ExportRegisterRecordSetRow
			);
			
			Continue;
			
		EndIf;
		
		// Initializing the value to be converted
		Value       = Undefined;
		OCRName     = PCR.ConversionRule;
		DontReplace = PCR.DontReplace;
		
		Empty      = False;
		Expression = Undefined;
		TargetType = PCR.TargetType;
		
		IsNULL     = False;
		
		// BeforeExport handler
		If PCR.HasBeforeExportHandler Then
			
			Cancel = False;
			
			Try
				
				
				ExportObject = Not ExportRefOnly;
				
				If SL20CompatibilityMode() Then
					
					Execute(PCR.BeforeExport);
					
				Else
					
					ExecuteHandler_PCR_BeforeExportProperty(ExchangeFile, Source, Target, IncomingData, OutgoingData,
					PCR, OCR, CollectionObject, Cancel, Value, TargetType, OCRName,
					ExtDimensionTypeOCRName, Empty, Expression, PropertyCollectionNode, DontReplace,
					ExportObject);
					
				EndIf;
				
				ExportRefOnly = Not ExportObject;
				
			Except
				
				WriteErrorInfoPCRHandlers(55, ErrorDescription(), OCR, PCR, Source, 
				"BeforeExportProperty", Value);
				
			EndTry;
			
			If Cancel Then // Canceling property export
				
				Continue;
				
			EndIf;
			
		EndIf;
		
		
		// Creating the property node
		PropertyNodeStructure = Undefined;
		PropertyNode = Undefined;
		
		CreateComplexInformationForXMLWriter(PropertyNodeStructure, PropertyNode, PCR.XMLNodeRequiredOnExport, PCR.Target, PCR.ParameterForTransferName);
		
		If DontReplace Then
			
			AddAttributeForXMLWriter(PropertyNodeStructure, PropertyNode, "DontReplace", "true");   
			
		EndIf;
		
		If PCR.SearchByEqualDate  Then
			
			AddAttributeForXMLWriter(PropertyNodeStructure, PropertyNode, "SearchByEqualDate", "true");
			
		EndIf;
		
		// Perhaps, the conversion rule is already defined
		If Not IsBlankString(OCRName) Then
			
			PropertyOCR = Rules[OCRName];
			
		Else
			
			PropertyOCR = Undefined;
			
		EndIf;
		
		If Not IsBlankString(TargetType) Then
			
			AddAttributeForXMLWriter(PropertyNodeStructure, PropertyNode, "Type", TargetType);
			
		ElsIf PropertyOCR <> Undefined Then
			
			// Attempting to define the target property type
			TargetType = PropertyOCR.Target;
			
			AddAttributeForXMLWriter(PropertyNodeStructure, PropertyNode, "Type", TargetType);
			
		EndIf;
		
		If Not IsBlankString(OCRName)
			And PropertyOCR <> Undefined
			And PropertyOCR.HasSearchFieldSequenceHandler = True Then
			
			AddAttributeForXMLWriter(PropertyNodeStructure, PropertyNode, "OCRName", OCRName);
			
		EndIf;
		
		IsOrdinaryProperty = IsBlankString(PCR.ParameterForTransferName);
		
		// Defining the value to be converted
		If Expression <> Undefined Then
			
			AddValueForXMLWriter(PropertyNodeStructure, PropertyNode, "Expression", Expression);
			
			WriteDataToMasterNode(PropertyCollectionNode, PropertyNodeStructure, PropertyNode, IsOrdinaryProperty);
			Continue;
			
		ElsIf Empty Then
			
			WriteDataToMasterNode(PropertyCollectionNode, PropertyNodeStructure, PropertyNode, IsOrdinaryProperty);
			Continue;
			
		Else
			
			GetPropertyValue(Value, CollectionObject, OCR, PCR, IncomingData, Source, PropertySelection);
			
			If PCR.CastToLength <> 0 Then
				
				CastValueToLength(Value, PCR);
				
			EndIf;
			
		EndIf;
		
		OldValueBeforeOnExportHandler = Value;
		Empty = deEmpty(Value, IsNULL);
		
		// OnExport handler
		If PCR.HasOnExportHandler Then
			
			Cancel = False;
			
			Try
				
				
				ExportObject = Not ExportRefOnly;
				
				If SL20CompatibilityMode() Then
					
					Execute(PCR.OnExport);
					
				Else
					
					ExecuteHandler_PCR_OnExportProperty(ExchangeFile, Source, Target, IncomingData, OutgoingData,
					PCR, OCR, CollectionObject, Cancel, Value, KeyAndValue, ExtDimensionType,
					ExtDimensions, Empty, OCRName, PropertyOCR,PropertyNode, PropertyCollectionNode,
					ExtDimensionTypeOCRName, ExportObject);
					
				EndIf;
				
				ExportRefOnly = Not ExportObject;
				
			Except
				
				WriteErrorInfoPCRHandlers(56, ErrorDescription(), OCR, PCR, Source, 
				"OnExportProperty", Value);
				
			EndTry;
			
			If Cancel Then // Canceling property export
				
				Continue;
				
			EndIf;
			
		EndIf;
		
		
		// Initializing the Empty variable one more time, perhaps its value has been changed
		// in the OnExport handler.
		If OldValueBeforeOnExportHandler <> Value Then
			
			Empty = deEmpty(Value, IsNULL);
			
		EndIf;
		
		If Empty Then
			
			If IsNULL Then
				
				Value = Undefined;
				
			EndIf;
			
			If Value <> Undefined 
				And IsBlankString(TargetType) Then
				
				TargetType = GetDataTypeForTarget(Value);
				
				If Not IsBlankString(TargetType) Then
					
					AddAttributeForXMLWriter(PropertyNodeStructure, PropertyNode, "Type", TargetType);
					
				EndIf;
				
			EndIf;   
			
			WriteDataToMasterNode(PropertyCollectionNode, PropertyNodeStructure, PropertyNode, IsOrdinaryProperty);
			Continue;
			
		EndIf;
		
		RefNode = Undefined;
		
		If PropertyOCR = Undefined
			And IsBlankString(OCRName) Then
			
			PropertySet = False;
			ValueType = TypeOf(Value);
			TypeRequired = False;
			GetValueSettingPossibility(Value, ValueType, TargetType, PropertySet, TypeRequired);
			
			If PropertySet Then
				
				// Specifying the type, if necessary
				If TypeRequired Then
					
					AddAttributeForXMLWriter(PropertyNodeStructure, PropertyNode, "Type", TargetType);
					
				EndIf;
				
				AddValueForXMLWriter(PropertyNodeStructure, PropertyNode, "Value", Value);
				
			Else
				
				ValueManager = Managers[ValueType];
				
				If ValueManager = Undefined Then
					Continue;
				EndIf;
				
				PropertyOCR = ValueManager.OCR;
				
				If PropertyOCR = Undefined Then
					Continue;
				EndIf;
				
				OCRName = PropertyOCR.Name;
				
			EndIf;
			
		EndIf;
		
		If (PropertyOCR <> Undefined) 
			Or (Not IsBlankString(OCRName)) Then
			
			If ExportRefOnly Then
				
				If ExportObjectByRef(Value, NodeForExchange) Then
					
					If Not ObjectPassesAllowedObjectFilter(Value) Then
						
						// Setting the flag that shows whether the object must be exported entirety
						ExportRefOnly = False;
						
						// Adding a record to the mapping register
						RecordStructure = New Structure;
						RecordStructure.Insert("InfobaseNode", NodeForExchange);
						RecordStructure.Insert("SourceUUID", Value);
						RecordStructure.Insert("ObjectExportedByRef", True);
						
						InformationRegisters.InfobaseObjectMappings.AddRecord(RecordStructure, True);
						
						// Adding the object to the array of objects exported by reference
						// for further object registration in the current node 
						// and for assigning the number of the current sent exchange message.
						ExportedByRefObjectsAddValue(Value);
						
					EndIf;
					
				EndIf;
				
			EndIf;
			
			RuleWithGlobalExport = False;
			RefNode = ExportByRule(Value, , OutgoingData, , OCRName, , ExportRefOnly, PropertyOCR, , , , , False, 
			RuleWithGlobalExport, DontUseRulesWithGlobalExportAndDontRememberExported);
			
			If RefNode = Undefined Then
				
				Continue;
				
			EndIf;
			
			If IsBlankString(TargetType) Then
				
				TargetType  = PropertyOCR.Target;
				AddAttributeForXMLWriter(PropertyNodeStructure, PropertyNode, "Type", TargetType);
				
			EndIf;   
			
			RefNodeType = TypeOf(RefNode);
			
			If RefNodeType = StringType Then
				
				If Find(RefNode, "<Ref") > 0 Then
					
					AddArbitraryDataForXMLWriter(PropertyNodeStructure, PropertyNode, "Ref", RefNode);
					
				Else
					
					AddValueForXMLWriter(PropertyNodeStructure, PropertyNode, "Value", RefNode);
					
				EndIf;
				
			ElsIf RefNodeType = NumberType Then
				
				If RuleWithGlobalExport Then
					AddValueForXMLWriter(PropertyNodeStructure, PropertyNode, "GSn", RefNode);
				Else
					AddValueForXMLWriter(PropertyNodeStructure, PropertyNode, "Sn", RefNode);
				EndIf;
				
			Else
				
				RefNode.WriteEndElement();
				InformationToWriteToFile = RefNode.Close();
				
				AddArbitraryDataForXMLWriter(PropertyNodeStructure, PropertyNode, "Ref", InformationToWriteToFile);
				
			EndIf;
			
		EndIf;
		
		
		
		// AfterExport handler
		
		If PCR.HasAfterExportHandler Then
			
			Cancel = False;
			
			Try
				
				
				If SL20CompatibilityMode() Then
					
					Execute(PCR.AfterExport);
					
				Else
					
					ExecuteHandler_PCR_AfterExportProperty(ExchangeFile, Source, Target, IncomingData, OutgoingData,
					PCR, OCR, CollectionObject, Cancel, Value, KeyAndValue, ExtDimensionType,
					ExtDimensions, OCRName, ExtDimensionTypeOCRName, PropertyOCR, PropertyNode,
					RefNode, PropertyCollectionNode, ExtDimensionNode);
					
				EndIf;
				
			Except
				
				WriteErrorInfoPCRHandlers(57, ErrorDescription(), OCR, PCR, Source, 
				"AfterExportProperty", Value);     
				
			EndTry;
			
			If Cancel Then // Canceling property export
				
				Continue;
				
			EndIf;
			
		EndIf;
		
		WriteDataToMasterNode(PropertyCollectionNode, PropertyNodeStructure, PropertyNode, IsOrdinaryProperty);
		
	EndDo; // by PCR
	
EndProcedure

Procedure GetOCRByParameters(OCR, Source, OCRName)
	
	// Searching for OCR
	If OCR = Undefined Then
		
		OCR = FindRule(Source, OCRName);
		
	ElsIf (Not IsBlankString(OCRName))
		And OCR.Name <> OCRName Then
		
		OCR = FindRule(Source, OCRName);
		
	EndIf; 
	
EndProcedure

Function FindPropertyStructureByParameters(OCR, Source)
	
	PropertyStructure = Managers[OCR.Source];
	If PropertyStructure = Undefined Then
		PropertyStructure = Managers[TypeOf(Source)];
	EndIf; 
	
	Return PropertyStructure;
	
EndFunction

Function GetRefByObjectOrRef(Source, ExportingObject)
	
	If ExportingObject Then
		Return Source.Ref;
	Else
		Return Source;
	EndIf;
	
EndFunction

Function GetInternalPresentationForSearch(Source, PropertyStructure)
	
	If PropertyStructure.TypeName = "Enum" Then
		Return Source;
	Else
		Return ValueToStringInternal(Source);
	EndIf
	
EndFunction

Procedure UpdateDataInDataToExport()
	
	If DataMapForExportedItemUpdate.Count() > 0 Then
		
		DataMapForExportedItemUpdate.Clear();
		
	EndIf;
	
EndProcedure

Procedure SetExportedToFileObjectFlags()
	
	WrittenToFileSn = SnCounter;  
	
EndProcedure

Procedure WriteExchangeObjectPriority(ExchangeObjectPriority, Node)
	
	If ValueIsFilled(ExchangeObjectPriority)
		And ExchangeObjectPriority <> Enums.ExchangeObjectPriorities.ReceivedExchangeObjectPriorityHigher Then
		
		If ExchangeObjectPriority = Enums.ExchangeObjectPriorities.ReceivedExchangeObjectPriorityLower Then
			SetAttribute(Node, "ExchangeObjectPriority", "Lower");
		ElsIf ExchangeObjectPriority = Enums.ExchangeObjectPriorities.ObjectCameDuringExchangeHasSamePriority Then
			SetAttribute(Node, "ExchangeObjectPriority", "Matches");     
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure ExportChangeRecordedObjectData(RecordSetForExport)
	
	If RecordSetForExport.Count() = 0 Then // We Unload blank set information register
		
		Filter = New Structure;
		Filter.Insert("SourceUUID", RecordSetForExport.Filter.SourceUUID.Value);
		Filter.Insert("TargetUUID", RecordSetForExport.Filter.TargetUUID.Value);
		Filter.Insert("SourceType", RecordSetForExport.Filter.SourceType.Value);
		Filter.Insert("TargetType", RecordSetForExport.Filter.TargetType.Value);
		
		ExportInfobaseObjectMappingRecord(Filter, True);
		
	Else
		
		For Each SetRow In RecordSetForExport Do
			
			ExportInfobaseObjectMappingRecord(SetRow, False);
			
		EndDo;
		
	EndIf;
	
EndProcedure

Procedure ExportInfobaseObjectMappingRecord(SetRow, EmptySet)
	
	Target = CreateNode("ObjectChangeRecordData");
	
	SetAttribute(Target, "SourceUUID", String(SetRow.SourceUUID.UUID()));
	SetAttribute(Target, "TargetUUID",        SetRow.TargetUUID);
	SetAttribute(Target, "SourceType",                            SetRow.SourceType);
	SetAttribute(Target, "TargetType",                            SetRow.TargetType);
	
	SetAttribute(Target, "EmptySet", EmptySet);
	
	Target.WriteEndElement(); // ObjectChangeRecordData
	
	WriteToFile(Target);
	
	IncreaseExportedObjectCounter();
	
EndProcedure

Procedure FireEventsBeforeExportObject(Object, Rule, Properties=Undefined, IncomingData=Undefined, 
	DontExportPropertyObjectsByRefs = False, OCRName, Cancel, OutgoingData)
	
	
	If CommentObjectProcessingFlag Then
		
		Try
			ObjectPresentation   = String(Object) + "  (" + TypeOf(Object) + ")";   
		Except
			ObjectPresentation   = TypeOf(Object);
		EndTry;
		
		
		EventName = NStr("en = 'ObjectExport: %1'");
		EventName = StringFunctionsClientServer.SubstituteParametersInString(EventName, ObjectPresentation);
		
		WriteToExecutionLog(EventName, , False, 1, 7);
		
	EndIf;
	
	
	OCRName      = Rule.ConversionRule;
	Cancel       = False;
	OutgoingData = Undefined;
	
	
	// BeforeExportObject global handler 
	If HasBeforeExportObjectGlobalHandler Then
		
		Try
			
			If SL20CompatibilityMode() Then
				
				Execute(Conversion.BeforeExportObject);
				
			Else
				
				ExecuteHandler_Conversion_BeforeExportObject(ExchangeFile, Cancel, OCRName, Rule, IncomingData, OutgoingData, Object);
				
			EndIf;
		Except
			WriteErrorInfoDERHandlers(65, ErrorDescription(), Rule.Name, Object, NStr("en = 'BeforeExportSelectionObject (global)'"));
		EndTry;
		
		If Cancel Then
			Return;
		EndIf;
		
	EndIf; 
	
	// BeforeExport handler
	If Not IsBlankString(Rule.BeforeExport) Then
		
		Try
			
			If SL20CompatibilityMode() Then
				
				Execute(Rule.BeforeExport);
				
			Else
				
				ExecuteHandler_DER_BeforeExportObject(ExchangeFile, Cancel, OCRName, Rule, IncomingData, OutgoingData, Object);
				
			EndIf;
		Except
			WriteErrorInfoDERHandlers(33, ErrorDescription(), Rule.Name, "BeforeExportSelectionObject", Object);
		EndTry;
		
	EndIf;  
	
EndProcedure

Procedure FireEventsAfterExportObject(Object, Rule, Properties=Undefined, IncomingData=Undefined, 
	DontExportPropertyObjectsByRefs = False, OCRName, Cancel, OutgoingData)
	
	Var RefNode; // Stub
	// AfterExportObject global handler 
	If HasAfterExportObjectGlobalHandler Then
		Try
			If SL20CompatibilityMode() Then
				
				Execute(Conversion.AfterExportObject);
				
			Else
				
				ExecuteHandler_Conversion_AfterExportObject(ExchangeFile, Object, OCRName, IncomingData, OutgoingData, RefNode);
				
			EndIf;
		Except
			WriteErrorInfoDERHandlers(69, ErrorDescription(), Rule.Name, NStr("en = 'AfterExportSelectionObject (global)'"), Object);
		EndTry;
	EndIf;
	
	
	// AfterExport handler
	If Not IsBlankString(Rule.AfterExport) Then
		
		Try
			
			If SL20CompatibilityMode() Then
				
				Execute(Rule.AfterExport);
				
			Else
				
				ExecuteHandler_DER_AfterExportObject(ExchangeFile, Object, OCRName, IncomingData, OutgoingData, RefNode, Rule);
				
			EndIf;
		Except
			WriteErrorInfoDERHandlers(34, ErrorDescription(), Rule.Name, "AfterExportSelectionObject", Object);
		EndTry;
		
	EndIf;
	
EndProcedure

// Exports the selection object sample according to the specified rule.
//
// Parameters:
//  Object       - selection object to be exported.
//  Rule         - data export rule reference.
//  Properties   - metadata object properties of the object to be exported.
//  IncomingData - arbitrary auxiliary data.
// 
Function SelectionItemExport(Object, 
	ExportRule, 
	Properties                      = Undefined, 
	IncomingData                    = Undefined,
	DontExportPropertyObjectsByRefs = False, 
	ExportRecordSetRow              = False, 
	ParentNode                      = Undefined, 
	ConstantNameForExport           = "",
	OCRName                         = "",
	FireEvents                      = True)
	
	Cancel       = False;
	OutgoingData = Undefined;
	
	If FireEvents
		And ExportRule <> Undefined Then       
		
		OCRName = "";  
		
		FireEventsBeforeExportObject(Object, ExportRule, Properties, IncomingData, 
		DontExportPropertyObjectsByRefs, OCRName, Cancel, OutgoingData);
		
		If Cancel Then
			Return False;
		EndIf;
		
	EndIf;
	
	RefNode = Undefined;
	ExportByRule(Object, , IncomingData, OutgoingData, OCRName, RefNode, , , Not DontExportPropertyObjectsByRefs, 
	ExportRecordSetRow, ParentNode, ConstantNameForExport, True);
	
	
	If FireEvents
		And ExportRule <> Undefined Then
		
		FireEventsAfterExportObject(Object, ExportRule, Properties, IncomingData, 
		DontExportPropertyObjectsByRefs, OCRName, Cancel, OutgoingData); 
		
	EndIf;
	
	Return Not Cancel;
	
EndFunction

// Calls BeforeExport and AfterExport rules to export the register
//

Function RegisterExport( RecordSetForExport, 
	Rule = Undefined, 
	IncomingData = Undefined, 
	DontExportPropertyObjectsByRefs = False, 
	OCRName = "") Export
	
	OCRName      = "";
	Cancel       = False;
	OutgoingData = Undefined;
	
	FireEventsBeforeExportObject(RecordSetForExport, Rule, Undefined, IncomingData, 
	DontExportPropertyObjectsByRefs, OCRName, Cancel, OutgoingData);
	
	If Cancel Then
		Return False;
	EndIf; 
	
	
	UnloadRegister(RecordSetForExport, 
	Undefined, 
	OutgoingData, 
	DontExportPropertyObjectsByRefs, 
	OCRName,
	Rule);
	
	FireEventsAfterExportObject(RecordSetForExport, Rule, Undefined, IncomingData, 
	DontExportPropertyObjectsByRefs, OCRName, Cancel, OutgoingData); 
	
	Return Not Cancel;       
	
EndFunction

// Generates a query result for exporting the data clearing.
//
Function GetQueryResultForExportDataClearing(Properties, TypeName, 
	SelectionForDataClearing = False, DeleteObjectsDirectly = False, SelectAllFields = True) Export 
	
	AllowedString = ?(ExportAllowedOnly, " ALLOWED ", "");
	
	FieldSelectionString = ?(SelectAllFields, " * ", " ObjectForExport.Ref AS Ref ");
	
	If TypeName = "Catalog" 
		Or TypeName = "ChartOfCharacteristicTypes" 
		Or TypeName = "ChartOfAccounts" 
		Or TypeName = "ChartOfCalculationTypes" 
		Or TypeName = "AccountingRegister"
		Or TypeName = "ExchangePlan"
		Or TypeName = "Task"
		Or TypeName = "BusinessProcess" Then
		
		Query = New Query();
		
		If TypeName = "AccountingRegister" Then
			
			FieldSelectionString = "*"; 
			
		EndIf;
		
		Query.Text = "SELECT " + AllowedString + "
		| " + FieldSelectionString + "
		|FROM
		| " + TypeName + "." + Properties.Name + " AS ObjectForExport
		|
		|";
		
		If SelectionForDataClearing
			And DeleteObjectsDirectly Then
			
			If (TypeName = "Catalog"
				Or TypeName = "ChartOfCharacteristicTypes") Then
				
				Try
					If TypeName = "Catalog" Then
						HierarchyRequired = Metadata.Catalogs[Properties.Name].Hierarchical;
					Else
						HierarchyRequired = Metadata.ChartsOfCharacteristicTypes[Properties.Name].Hierarchical;
					EndIf
				Except
					HierarchyRequired = False
				EndTry;
				
				If HierarchyRequired Then
					
					Query.Text = Query.Text + "
					| WHERE ObjectForExport.Parent = &Parent
					|";
					
					Query.SetParameter("Parent", Properties.Manager.EmptyRef());
					
				EndIf;
				
			EndIf;
			
		EndIf;   
		
	ElsIf TypeName = "Document" Then
		
		Query = New Query();
		
		ResultingDateRestriction = "";
		
		Query.Text = "SELECT " + AllowedString + "
		| " + FieldSelectionString + "
		|FROM
		| " + TypeName + "." + Properties.Name + " AS ObjectForExport
		|
		|" + ResultingDateRestriction;
		
		
	ElsIf TypeName = "InformationRegister" Then
		
		Nonperiodical = Not Properties.Periodical;
		SubordinatedToRecorder = Properties.SubordinatedToRecorder;
		
		
		RestrictionByDateNotRequired = SelectionForDataClearing Or Nonperiodical;
		
		Query = New Query();
		
		ResultingDateRestriction = "";
		
		SelectionFieldSupplementionStringSubordinateToRegistrar = ?(Not SubordinatedToRecorder, ", NULL AS Active,
		| NULL AS Recorder,
		| NULL AS LineNumber", "");
		
		SelectionFieldSupplementionStringPeriodicity = ?(Nonperiodical, ", NULL AS Period", "");
		
		Query.Text = "SELECT " + AllowedString + "
		| *
		|
		| " + SelectionFieldSupplementionStringSubordinateToRegistrar + "
		| " + SelectionFieldSupplementionStringPeriodicity + "
		|
		|FROM
		| " + TypeName + "." + Properties.Name + " AS ObjectForExport
		|
		|" + ResultingDateRestriction;
		
	Else
		
		Return Undefined;
		
	EndIf;
	
	
	Return Query.Execute();
	
EndFunction

// Generates a selection for exporting the data clearing.
//
Function GetSelectionForDataClearingExport(Properties, TypeName, 
	SelectionForDataClearing = False, DeleteObjectsDirectly = False, SelectAllFields = True) Export
	
	QueryResult = GetQueryResultForExportDataClearing(Properties, TypeName, 
	SelectionForDataClearing, DeleteObjectsDirectly, SelectAllFields);
	
	If QueryResult = Undefined Then
		Return Undefined;
	EndIf;
	
	Selection = QueryResult.Choose();
	
	
	Return Selection;  
	
EndFunction

Function GetSelectionForExportWithRestrictions(Rule)
	
	MetadataName  = Rule.ObjectForQueryName;
	
	AllowedString = ?(ExportAllowedOnly, " ALLOWED ", "");
	
	ReportBuilder.Text = "SELECT " + AllowedString + " Object.Ref AS Ref FROM " + MetadataName + " AS Object "+ "{WHERE Object.Ref.* AS " + StrReplace(MetadataName, ".", "_") + "}";
	ReportBuilder.Filter.Reset();
	If Not Rule.BuilderSettings = Undefined Then
		ReportBuilder.SetSettings(Rule.BuilderSettings);
	EndIf;
	
	ReportBuilder.Execute();
	Selection = ReportBuilder.Result.Choose();
	
	Return Selection;
	
EndFunction

Function GetExportWithArbitraryAlgorithmSelection(DataSelection)
	
	Selection = Undefined;
	
	SelectionType = TypeOf(DataSelection);
	
	If SelectionType = Type("QueryResultSelection") Then
		
		Selection = DataSelection;
		
	ElsIf SelectionType = Type("QueryResult") Then
		
		Selection = DataSelection.Choose();
		
	ElsIf SelectionType = Type("Query") Then
		
		QueryResult = DataSelection.Execute();
		Selection   = QueryResult.Choose();
		
	EndIf;
	
	Return Selection; 
	
EndFunction

Function GetConstantSetRowForExport(ConstantDataTableForExport)
	
	ConstantSetString = "";
	
	For Each TableRow In ConstantDataTableForExport Do
		
		If Not IsBlankString(TableRow.Source) Then
			
			ConstantSetString = ConstantSetString + ", " + TableRow.Source;
			
		EndIf; 
		
	EndDo; 
	
	If Not IsBlankString(ConstantSetString) Then
		
		ConstantSetString = Mid(ConstantSetString, 3);
		
	EndIf;
	
	Return ConstantSetString;
	
EndFunction

Function ExportConstantsSet(Rule, Properties, OutgoingData, ConstantSetNameString = "")
	
	If ConstantSetNameString = "" Then
		ConstantSetNameString = GetConstantSetRowForExport(Properties.OCR.Properties);
	EndIf;
	
	ConstantSet = Constants.CreateSet(ConstantSetNameString);
	ConstantSet.Read();
	ExportResult = SelectionItemExport(ConstantSet, Rule, Properties, OutgoingData, , , , ConstantSetNameString); 
	Return ExportResult;
	
EndFunction

Function MustSelectAllFields(Rule)
	
	AllFieldsRequiredForSelection = Not IsBlankString(Conversion.BeforeExportObject)
	Or Not IsBlankString(Rule.BeforeExport)
	Or Not IsBlankString(Conversion.AfterExportObject)
	Or Not IsBlankString(Rule.AfterExport);  
	
	Return AllFieldsRequiredForSelection; 
	
EndFunction

// Exports data by the specified rule.
//
// Parameters:
//  Rule  data export rule reference.
// 
Procedure ExportDataByRule(Rule) Export
	
	OCRName = Rule.ConversionRule;
	
	If Not IsBlankString(OCRName) Then
		
		OCR = Rules[OCRName];
		
	EndIf;
	
	
	If CommentObjectProcessingFlag Then
		
		MessageString = NStr("en = 'DATA EXPORT RULE: %1 (%2)'");
		MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, TrimAll(Rule.Name), TrimAll(Rule.Description));
		WriteToExecutionLog(MessageString, , False, , 4);
		
	EndIf;
	
	
	// BeforeProcess handler
	Cancel        = False;
	OutgoingData  = Undefined;
	DataSelection = Undefined;
	
	
	If Not IsBlankString(Rule.BeforeProcess) Then
		
		Try
			
			
			
			If SL20CompatibilityMode() Then
				
				Execute(Rule.BeforeProcess);
				
			Else
				
				ExecuteHandler_DER_BeforeProcessRule(Cancel, OCRName, Rule, OutgoingData, DataSelection);
				
			EndIf;
			
		Except
			
			WriteErrorInfoDERHandlers(31, ErrorDescription(), Rule.Name, "BeforeProcessDataExport");
			
		EndTry;
		
		If Cancel Then
			
			Return;
			
		EndIf;
		
	EndIf;
	
	
	// Standard selection with filter
	If Rule.DataSelectionVariant = "StandardSelection" And Rule.UseFilter Then
		
		Selection = GetSelectionForExportWithRestrictions(Rule);
		
		While Selection.Next() Do
			SelectionItemExport(Selection.Ref, Rule, , OutgoingData);
		EndDo;
		
		// Standard selection without filter
	ElsIf (Rule.DataSelectionVariant = "StandardSelection") Then
		
		Properties = Managers[Rule.SelectionObject];
		TypeName  = Properties.TypeName;
		
		If TypeName = "Constants" Then
			
			ExportConstantsSet(Rule, Properties, OutgoingData);  
			
		Else
			
			IsNotReferenceType = TypeName =  "InformationRegister" 
			Or TypeName = "AccountingRegister";
			
			
			If IsNotReferenceType Then
				
				SelectAllFields = MustSelectAllFields(Rule);
				
			Else
				
				// Getting the reference only
				SelectAllFields = False; 
				
			EndIf; 
			
			
			Selection = GetSelectionForDataClearingExport(Properties, TypeName, , , SelectAllFields);
			
			If Selection = Undefined Then
				Return;
			EndIf;
			
			While Selection.Next() Do
				
				If IsNotReferenceType Then
					
					SelectionItemExport(Selection, Rule, Properties, OutgoingData);
					
				Else
					
					SelectionItemExport(Selection.Ref, Rule, Properties, OutgoingData);
					
				EndIf;
				
			EndDo;
			
		EndIf;
		
	ElsIf Rule.DataSelectionVariant = "ArbitraryAlgorithm" Then
		
		If DataSelection <> Undefined Then
			
			Selection = GetExportWithArbitraryAlgorithmSelection(DataSelection);
			
			If Selection <> Undefined Then
				
				While Selection.Next() Do
					
					SelectionItemExport(Selection, Rule, , OutgoingData);
					
				EndDo;
				
			Else
				
				For Each Object In DataSelection Do
					
					SelectionItemExport(Object, Rule, , OutgoingData);
					
				EndDo;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	
	// AfterProcess handler
	
	
	If Not IsBlankString(Rule.AfterProcess) Then
		
		Try
			
			
			If SL20CompatibilityMode() Then
				
				Execute(Rule.AfterProcess);
				
			Else
				
				ExecuteHandler_DER_AfterProcessRule(OCRName, Rule, OutgoingData);
				
			EndIf;
			
		Except
			
			WriteErrorInfoDERHandlers(32, ErrorDescription(), Rule.Name, "AfterProcessDataExport");
			
		EndTry;
		
	EndIf;
	
EndProcedure

Procedure ProcessObjectDeletion(ObjectDeletionData, ErrorMessageString = "")
	
	Ref = ObjectDeletionData.Ref;
	
	EventText = "";
	If Conversion.Property("BeforeSendDeletionInfo", EventText) Then
		
		If Not IsBlankString(EventText) Then

			Cancel = False;

			Try

				If SL20CompatibilityMode() Then

					Execute(EventText);

				Else 

					ExecuteHandler_Conversion_BeforeSendDeletionInfo(Ref, Cancel);

				EndIf;

			Except

				ErrorMessageString = WriteErrorInfoConversionHandlers(76, ErrorDescription(),  NStr("en = 'BeforeSendDeletionInfo (conversion)'"));


				If Not ContinueOnError Then
					Raise ErrorMessageString;
				EndIf;
				
				Cancel = True;
			EndTry;
			
			If Cancel Then
				Return;
			EndIf;
			
		EndIf;
	EndIf;
	
	Manager = Managers[TypeOf(Ref)];
	
	// Checking whether the manager and OCR exist
	If Manager = Undefined
		Or Manager.OCR = Undefined Then
		
		LR = GetLogRecordStructure(45);
		
		LR.Object = Ref;
		Try
			LR.ObjectType = TypeOf(Ref);
		Except
		EndTry;
		
		WriteToExecutionLog(45, LR, True);
		Return;
		
	EndIf;
	
	WriteToFileObjectDeletion(Ref, Manager.OCR.TargetType, Manager.OCR.SourceType);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS FOR COMPILING EXCHANGE RULES TO A STRUCTURE

// Returns the exchange rule structure.
//
Function GetStructureRulesExchange(Source) Export
	
	ImportExchangeRules(Source, "XMLFile");
	
	If ErrorFlag() Then
		Return Undefined;
	EndIf;
	
	If ExchangeMode = "Import" Then
		ObjectChangeRecordAttributeTable = Undefined;
	Else
		// Getting the table of registration attributes for the selective object 
		// registration mechanism
		ObjectChangeRecordAttributeTable = GetObjectChangeRecordAttributeTable();
	EndIf;
	
	// Saving queries
	QueriesToSave = New Structure;
	
	For Each StructureItem In Queries Do
		
		QueriesToSave.Insert(StructureItem.Key, StructureItem.Value.Text);
		
	EndDo;
	
	// Saving parameters
	ParametersToSave = New Structure;
	
	For Each StructureItem In Parameters Do
		
		ParametersToSave.Insert(StructureItem.Key, Undefined);
		
	EndDo;
	
	ExchangeRuleStructure = New Structure;
	ExchangeRuleStructure.Insert("RuleStorageFormatVersion", ExchangeRuleStorageFormatVersion());
	
	ExchangeRuleStructure.Insert("Conversion", Conversion);
	
	ExchangeRuleStructure.Insert("ParameterSetupTable", ParameterSetupTable);
	ExchangeRuleStructure.Insert("ExportRuleTable",     ExportRuleTable);
	ExchangeRuleStructure.Insert("ConversionRuleTable", ConversionRuleTable);
	
	ExchangeRuleStructure.Insert("Algorithms", Algorithms);
	ExchangeRuleStructure.Insert("Parameters", ParametersToSave);
	ExchangeRuleStructure.Insert("Queries",    QueriesToSave);
	
	ExchangeRuleStructure.Insert("XMLRules",             XMLRules);
	ExchangeRuleStructure.Insert("TypesForTargetString", TypesForTargetString);
	
	ExchangeRuleStructure.Insert("SelectiveObjectChangeRecordRules", ObjectChangeRecordAttributeTable);
	
	Return ExchangeRuleStructure;
	
EndFunction

Function GetObjectChangeRecordAttributeTable()
	
	ChangeRecordAttributeTable = InitChangeRecordAttributeTable();
	ResultTable                = InitChangeRecordAttributeTable();
	
	// Getting the preliminary table from the conversion rules
	For Each OCR In ConversionRuleTable Do
		
		FillObjectChangeRecordAttributeTableDetailsByRule(OCR, ResultTable);
		
	EndDo;
	
	ResultTableGroup = ResultTable.Copy();
	
	ResultTableGroup.GroupBy("ObjectName, TabularSectionName");
	
	// Getting the final table based on the grouped rows of the tentative table
	For Each TableRow In ResultTableGroup Do
		
		Filter = New Structure("ObjectName, TabularSectionName", TableRow.ObjectName, TableRow.TabularSectionName);
		
		ResultTableRowArray = ResultTable.FindRows(Filter);
		
		SupplementChangeRecordAttributeTable(ResultTableRowArray, ChangeRecordAttributeTable);
		
	EndDo;
	
	// Deleting rows that contain errors
	DeleteChangeRecordAttributeTableRowsWithErrors(ChangeRecordAttributeTable);
	
	// Checking for required header attributes and metadata object tabular section attributes
	CheckObjectChangeRecordAttributes(ChangeRecordAttributeTable);
	
	// Filling the table with the exchange plan name value
	ChangeRecordAttributeTable.FillValues(ExchangePlanInDEName, "ExchangePlanName");
	
	Return ChangeRecordAttributeTable;
	
EndFunction

Function InitChangeRecordAttributeTable()
	
	ResultTable = New ValueTable;
	
	ResultTable.Columns.Add("order",                          deTypeDescription("Number"));
	ResultTable.Columns.Add("ObjectName",                     deTypeDescription("String"));
	ResultTable.Columns.Add("ObjectTypeString",               deTypeDescription("String"));
	ResultTable.Columns.Add("ExchangePlanName",               deTypeDescription("String"));
	ResultTable.Columns.Add("TabularSectionName",             deTypeDescription("String"));
	ResultTable.Columns.Add("ChangeRecordAttributes",         deTypeDescription("String"));
	ResultTable.Columns.Add("ChangeRecordAttributeStructure", deTypeDescription("Structure"));
	
	Return ResultTable;
	
EndFunction

Function GetChangeRecordAttributeStructure(PCRTable)
	
	ChangeRecordAttributeStructure = New Structure;
	
	PCRRowArray = PCRTable.FindRows(New Structure("IsFolder", False));
	
	For Each PCR In PCRRowArray Do
		
		// Checking for prohibited characters in the string
		If IsBlankString(PCR.Source)
			Or Left(PCR.Source, 1) = "{" Then
			
			Continue;
		EndIf;
		
		Try
			ChangeRecordAttributeStructure.Insert(PCR.Source);
		Except
			WriteLogEvent(NStr("en = 'Data exchange. Importing conversion rules.'", CommonUseClientServer.DefaultLanguageCode()),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		EndTry;
		
	EndDo;
	
	Return ChangeRecordAttributeStructure;
	
EndFunction

Function GetChangeRecordAttributeStructureByStringArray(RowArray)
	
	ResultStructure = New Structure;
	
	For Each ResultTableRow In RowArray Do
		
		ChangeRecordAttributeStructure = ResultTableRow.ChangeRecordAttributeStructure;
		
		For Each ChangeRecordAttribute In ChangeRecordAttributeStructure Do
			
			ResultStructure.Insert(ChangeRecordAttribute.Key);
			
		EndDo;
		
	EndDo;
	
	Return ResultStructure;
	
EndFunction

Function GetChangeRecordAttributes(ChangeRecordAttributeStructure)
	
	ChangeRecordAttributes = "";
	
	For Each ChangeRecordAttribute In ChangeRecordAttributeStructure Do
		
		ChangeRecordAttributes = ChangeRecordAttributes + ChangeRecordAttribute.Key + ", ";
		
	EndDo;
	
	StringFunctionsClientServer.DeleteLastCharsInString(ChangeRecordAttributes, 2);
	
	Return ChangeRecordAttributes;
	
EndFunction

Procedure CheckObjectChangeRecordAttributes(ChangeRecordAttributeTable)
	
	For Each TableRow In ChangeRecordAttributeTable Do
		
		Try
			ObjectType = Type(TableRow.ObjectTypeString);
		Except
			
			MessageString = NStr("en = 'The object type is not defined: %1'");
			MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, TableRow.ObjectTypeString);
			WriteToExecutionLog(MessageString);
			Continue;
			
		EndTry;
		
		MDObject = Metadata.FindByType(ObjectType);
		
		// Checking reference types only
		If Not CommonUse.IsReferenceTypeObject(MDObject) Then
			Continue;
		EndIf;
		
		CommonAttributeTable = CommonAttributeTable();
		FillCommonAttributeTable(CommonAttributeTable);
		If IsBlankString(TableRow.TabularSectionName) Then // Header attributes
			
			For Each Attribute In TableRow.ChangeRecordAttributeStructure Do
				
				If CommonUse.IsTask(MDObject) Then
					
					If Not (MDObject.Attributes.Find(Attribute.Key) <> Undefined
						Or  MDObject.AddressingAttributes.Find(Attribute.Key) <> Undefined
						Or  DataExchangeServer.IsStandardAttribute(MDObject.StandardAttributes, Attribute.Key)
						Or  IsCommonAttribute(Attribute.Key, MDObject.FullName(), CommonAttributeTable)) Then
						
						MessageString = NStr("en = '%1 object header attributes are incorrectly specified. The %2 attribute does not exist.'");
						MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, String(MDObject), Attribute.Key);
						WriteToExecutionLog(MessageString);
						
					EndIf;
					
				Else
					
					If Not (MDObject.Attributes.Find(Attribute.Key) <> Undefined
						Or  DataExchangeServer.IsStandardAttribute(MDObject.StandardAttributes, Attribute.Key)
						Or  IsCommonAttribute(Attribute.Key, MDObject.FullName(), CommonAttributeTable)) Then
						
						MessageString = NStr("en = '%1 object header attributes are incorrectly specified. The %2 attribute does not exist.'");
						MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, String(MDObject), Attribute.Key);
						WriteToExecutionLog(MessageString);
						
					EndIf;
					
				EndIf;
				
			EndDo;
			
		Else // Tabular section attributes
			
			If MDObject.TabularSections.Find(TableRow.TabularSectionName) = Undefined Then
				MessageString = NStr("en = 'The %1 tabular section of the %2 object is incorrectly specified. The tabular section does not exist.'");
				MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, TableRow.TabularSectionName, String(MDObject));
				WriteToExecutionLog(MessageString);
				Continue;
			EndIf;
			
			For Each Attribute In TableRow.ChangeRecordAttributeStructure Do
				
				If Not (MDObject.TabularSections[TableRow.TabularSectionName].Attributes.Find(Attribute.Key) <> Undefined
					Or  DataExchangeServer.IsStandardAttribute(MDObject.TabularSections[TableRow.TabularSectionName].StandardAttributes, Attribute.Key)) Then
					
					MessageString = NStr("en = '%1 tabular section attributes of the %2 object are incorrectly specified. The %3 attribute does not exist.'");
					MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, TableRow.TabularSectionName, String(MDObject), Attribute.Key);
					WriteToExecutionLog(MessageString);
					
				EndIf;
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure FillObjectChangeRecordAttributeTableDetailsByRule(OCR, ResultTable)
	
	ObjectName       = StrReplace(OCR.SourceType, "Ref", "");
	ObjectTypeString = OCR.SourceType;
	
	// Filling the table with the header attributes (properties)
	FillObjectChangeRecordAttributeTableByTable(ObjectTypeString, ObjectName, "", 50, OCR.Properties, ResultTable);
	
	// Filling the table with the header attributes (search properties)
	FillObjectChangeRecordAttributeTableByTable(ObjectTypeString, ObjectName, "", 50, OCR.SearchProperties, ResultTable);
	
	// Filling the table with the header attributes (disabled properties)
	FillObjectChangeRecordAttributeTableByTable(ObjectTypeString, ObjectName, "", 50, OCR.DisabledProperties, ResultTable);
	
	PGCRArray = OCR.Properties.FindRows(New Structure("IsFolder", True));
	
	For Each PGCR In PGCRArray Do
		
		// Filling the table with the tabular section attributes
		FillObjectChangeRecordAttributeTableByTable(ObjectTypeString, ObjectName, PGCR.Source, PGCR.order, PGCR.GroupRules, ResultTable);
		
		// Filling the table with the tabular section attributes (disabled)
		FillObjectChangeRecordAttributeTableByTable(ObjectTypeString, ObjectName, PGCR.Source, PGCR.order, PGCR.DisabledGroupRules, ResultTable);
		
	EndDo;
	
	PGCRArray = OCR.DisabledProperties.FindRows(New Structure("IsFolder", True));
	
	For Each PGCR In PGCRArray Do
		
		// Filling the table with the tabular section attributes
		FillObjectChangeRecordAttributeTableByTable(ObjectTypeString, ObjectName, PGCR.Source, PGCR.order, PGCR.GroupRules, ResultTable);
		
		// Filling the table with the tabular section attributes (disabled)
		FillObjectChangeRecordAttributeTableByTable(ObjectTypeString, ObjectName, PGCR.Source, PGCR.order, PGCR.DisabledGroupRules, ResultTable);
		
	EndDo;
	
EndProcedure

Procedure FillObjectChangeRecordAttributeTableByTable(ObjectTypeString, ObjectName, TabularSectionName, order, PropertyTable, ResultTable)
	
	ResultTableRow = ResultTable.Add();
	
	ResultTableRow.Order                          = Order;
	ResultTableRow.ObjectName                     = ObjectName;
	ResultTableRow.ObjectTypeString               = ObjectTypeString;
	ResultTableRow.TabularSectionName             = TabularSectionName;
	ResultTableRow.ChangeRecordAttributeStructure = GetChangeRecordAttributeStructure(PropertyTable);
	
EndProcedure

Procedure SupplementChangeRecordAttributeTable(RowArray, ChangeRecordAttributeTable)
	
	TableRow = ChangeRecordAttributeTable.Add();
	
	TableRow.Order                          = RowArray[0].order;
	TableRow.ObjectName                     = RowArray[0].ObjectName;
	TableRow.ObjectTypeString               = RowArray[0].ObjectTypeString;
	TableRow.TabularSectionName             = RowArray[0].TabularSectionName;
	TableRow.ChangeRecordAttributeStructure = GetChangeRecordAttributeStructureByStringArray(RowArray);
	TableRow.ChangeRecordAttributes         = GetChangeRecordAttributes(TableRow.ChangeRecordAttributeStructure);
	
EndProcedure

Procedure DeleteChangeRecordAttributeTableRowsWithErrors(ChangeRecordAttributeTable)
	
	CollectionItemCount = ChangeRecordAttributeTable.Count();
	
	For ReverseIndex = 1 to CollectionItemCount Do
		
		TableRow = ChangeRecordAttributeTable[CollectionItemCount - ReverseIndex];
		
		// Deleting the row if it contains no registration attributes
		If IsBlankString(TableRow.ChangeRecordAttributes) Then
			
			ChangeRecordAttributeTable.Delete(TableRow);
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Returns flag that shows attribute is common one.
//
Function IsCommonAttribute(CommonAttribute, MDOName, CommonAttributeTable)
	
	
	SearchParameters = New Structure("CommonAttribute, MetadataObject", CommonAttribute, MDOName);
	FoundValues = CommonAttributeTable.FindRows(SearchParameters);
	
	If FoundValues.Count() > 0 Then
		
		Return True;
		
	EndIf;
	
	Return False;
	
EndFunction

Function CommonAttributeTable()
	
	
	CommonAttributeTable = New ValueTable;
	CommonAttributeTable.Columns.Add("CommonAttribute");
	CommonAttributeTable.Columns.Add("MetadataObject");
	
	CommonAttributeTable.Indexes.Add("CommonAttribute, MetadataObject");
	
	Return CommonAttributeTable;
	
EndFunction

Procedure FillCommonAttributeTable(CommonAttributeTable)
	
	If Metadata.CommonAttributes.Count() <> 0 Then
		
		CommonAttributeAutoUse = Metadata.ObjectProperties.CommonAttributeUse.Auto;
		CommonAttributeUse = Metadata.ObjectProperties.CommonAttributeUse.Use;
		
		
		For Each CommonAttribute In Metadata.CommonAttributes Do
			
			If CommonAttribute.DataSeparationUse = Undefined Then
				
				AutoUse = (CommonAttribute.AutoUse = Metadata.ObjectProperties.CommonAttributeAutoUse.Use);
				
				For Each Item In CommonAttribute.Content Do
					
					If Item.Use = CommonAttributeUse
						Or (Item.Use = CommonAttributeAutoUse And AutoUse) Then
						
						NewRow = CommonAttributeTable.Add();
						NewRow.CommonAttribute = CommonAttribute.Name;
						NewRow.MetadataObject = Item.Metadata.FullName();
						
					EndIf;
					
				EndDo;
				
			EndIf;
			
			
		EndDo;
		
	EndIf;
	
EndProcedure
////////////////////////////////////////////////////////////////////////////////
// EXPORT PROCEDURES AND FUNCTIONS

// Prepares a string that contains rule information based on data read from the XML file.
// 
// Returns:
//  InfoString - String - string with rule information.
//
Function GetRuleInformation(IsCorrespondentRules = False, CompatibilityMode = False) Export
	
	// Return value
	InfoString = "";
	
	If ErrorFlag() Then
		Return InfoString;
	EndIf;
	
	
	CompatibilityMode = (Conversion.CompatibilityMode = ""
	Or Conversion.CompatibilityMode = "SL20CompatibilityMode");
	
	If IsCorrespondentRules Then
		InfoString = NStr("en = 'Correspondent %1 conversion rules from %2'");
	Else
		InfoString = NStr("en = 'Current infobase %1 conversion rules from %2'");
	EndIf;
	
	SourceConfigurationPresentation = GetConfigurationPresentationFromExchangeRules("Source");
	TargetConfigurationPresentation = GetConfigurationPresentationFromExchangeRules("Target");
	
	Return StringFunctionsClientServer.SubstituteParametersInString(InfoString,
	
	
	SourceConfigurationPresentation,
	Format(Conversion.CreationDateTime, "DLF =dd"));
EndFunction

Function GetConfigurationPresentationFromExchangeRules(DefinitionName)
	
	ConfigurationName = "";
	Conversion.Property("ConfigurationSynonym" + DefinitionName, ConfigurationName);
	
	If Not ValueIsFilled(ConfigurationName) Then
		Return "";
	EndIf;
	
	AccurateVersion = "";
	Conversion.Property("ConfigurationVersion" + DefinitionName, AccurateVersion);
	
	If ValueIsFilled(AccurateVersion) Then
		
		AccurateVersion = CommonUseClientServer.ConfigurationVersionWithoutAssemblyNumber(AccurateVersion);
		
		ConfigurationName = ConfigurationName + " version " + AccurateVersion;  
	EndIf;
	
	Return ConfigurationName;
	
EndFunction

// Sets marks of subordinate value tree rows according to the current row mark.
//
// Parameters:
//  CurRow - value tree row.
// 
Procedure SetSubordinateMarks(CurRow, Attribute) Export
	
	Subordinate = CurRow.Rows;
	
	If Subordinate.Count() = 0 Then
		Return;
	EndIf;
	
	For Each Row In Subordinate Do
		
		If Row.BuilderSettings = Undefined 
			And Attribute = "UseFilter" Then
			
			Row[Attribute] = 0;
			
		Else
			
			Row[Attribute] = CurRow[Attribute];
			
		EndIf;
		
		SetSubordinateMarks(Row, Attribute);
		
	EndDo;
	
EndProcedure

Procedure FillPropertiesForSearch(DataStructure, PCR)
	
	For Each FieldRow In PCR Do
		
		If FieldRow.IsFolder Then
			
			If FieldRow.TargetKind = "TabularSection" 
				Or Find(FieldRow.TargetKind, "RegisterRecordSet") > 0 Then
				
				RecipientStructureName = FieldRow.Target + ?(FieldRow.TargetKind = "TabularSection", "TabularSection", "RecordSet");
				
				InternalStructure = DataStructure[RecipientStructureName];
				
				If InternalStructure = Undefined Then
					InternalStructure = New Map();
				EndIf;
				
				DataStructure[RecipientStructureName] = InternalStructure;
				
			Else
				
				InternalStructure = DataStructure; 
				
			EndIf;
			
			FillPropertiesForSearch(InternalStructure, FieldRow.GroupRules);
			
		Else
			
			If IsBlankString(FieldRow.TargetType) Then
				
				Continue;
				
			EndIf;
			
			DataStructure[FieldRow.Target] = FieldRow.TargetType;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure DeleteExcessiveItemsFromMap(DataStructure)
	
	For Each Item In DataStructure Do
		
		If TypeOf(Item.Value) = MapType Then
			
			DeleteExcessiveItemsFromMap(Item.Value);
			
			If Item.Value.Count() = 0 Then
				DataStructure.Delete(Item.Key);
			EndIf;
			
		EndIf;  
		
	EndDo;  
	
EndProcedure

Procedure FillInformationByTargetDataTypes(DataStructure, Rules)
	
	For Each Row In Rules Do
		
		If IsBlankString(Row.Target) Then
			Continue;
		EndIf;
		
		StructureData = DataStructure[Row.Target];
		If StructureData = Undefined Then
			
			StructureData = New Map();
			DataStructure[Row.Target] = StructureData;
			
		EndIf;
		
		// Reviewing search fields and other PCR and writing data types
		FillPropertiesForSearch(StructureData, Row.SearchProperties);
		
		// Properties
		FillPropertiesForSearch(StructureData, Row.Properties);
		
	EndDo;
	
	DeleteExcessiveItemsFromMap(DataStructure); 
	
EndProcedure

Procedure CreateStringWithPropertyTypes(XMLWriter, PropertyTypes)
	
	If TypeOf(PropertyTypes.Value) = MapType Then
		
		If PropertyTypes.Value.Count() = 0 Then
			Return;
		EndIf;
		
		XMLWriter.WriteStartElement(PropertyTypes.Key);
		
		For Each Item In PropertyTypes.Value Do
			CreateStringWithPropertyTypes(XMLWriter, Item);
		EndDo;
		
		XMLWriter.WriteEndElement();
		
		Else  
		
		deWriteElement(XMLWriter, PropertyTypes.Key, PropertyTypes.Value);
		
	EndIf;
	
EndProcedure

Function CreateTypeStringForTarget(DataStructure)
	
	XMLWriter = New XMLWriter;
	XMLWriter.SetString();
	XMLWriter.WriteStartElement("DataTypeInfo"); 
	
	For Each Row In DataStructure Do
		
		XMLWriter.WriteStartElement("DataType");
		SetAttribute(XMLWriter, "Name", Row.Key);
		
		For Each SubordinationRow In Row.Value Do
			
			CreateStringWithPropertyTypes(XMLWriter, SubordinationRow); 
			
		EndDo;
		
		XMLWriter.WriteEndElement();
		
	EndDo; 
	
	XMLWriter.WriteEndElement();
	
	ResultRow = XMLWriter.Close();
	Return ResultRow;
	
EndFunction

Procedure ImportSingleTypeData(ExchangeRules, TypeMap, LocalItemName)
	
	NodeName = LocalItemName; 
	
	ExchangeRules.Read();
	
	If (ExchangeRules.NodeType = XMLNodeTypeEndElement) Then
		
		ExchangeRules.Read();
		Return;
		
	ElsIf ExchangeRules.NodeType = XMLNodeTypeStartElement Then
		
		// New item
		NewMap = New Map;
		TypeMap.Insert(NodeName, NewMap);
		
		ImportSingleTypeData(ExchangeRules, NewMap, ExchangeRules.LocalName);   
		ExchangeRules.Read();
		
	Else
		TypeMap.Insert(NodeName, Type(ExchangeRules.Value));
		ExchangeRules.Read();
	EndIf; 
	
	ImportTypeMapForSingleType(ExchangeRules, TypeMap);
	
EndProcedure

Procedure ImportTypeMapForSingleType(ExchangeRules, TypeMap)
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If (ExchangeRules.NodeType = XMLNodeTypeEndElement) Then
			
			Break;
			
		EndIf;
		
		// Reading the element start 
		ExchangeRules.Read();
		
		If ExchangeRules.NodeType = XMLNodeTypeStartElement Then
			
			// New item
			NewMap = New Map;
			TypeMap.Insert(NodeName, NewMap);
			
			ImportSingleTypeData(ExchangeRules, NewMap, ExchangeRules.LocalName);   
			
		Else
			TypeMap.Insert(NodeName, Type(ExchangeRules.Value));
			ExchangeRules.Read();
		EndIf; 
		
	EndDo; 
	
EndProcedure

Procedure ImportDataTypeInfo()
	
	While ExchangeFile.Read() Do
		
		NodeName = ExchangeFile.LocalName;
		
		If NodeName = "DataType" Then
			
			TypeName = deAttribute(ExchangeFile, StringType, "Name");
			
			TypeMap = New Map;
			DataForImportTypeMap().Insert(Type(TypeName), TypeMap);
			
			ImportTypeMapForSingleType(ExchangeFile, TypeMap); 
			
		ElsIf (NodeName = "DataTypeInfo") And (ExchangeFile.NodeType = XMLNodeTypeEndElement) Then
			
			Break;
			
		EndIf;
		
	EndDo; 
	
EndProcedure

Procedure ImportDataExchangeParameterValues()
	
	Name = deAttribute(ExchangeFile, StringType, "Name");
	
	PropertyType = GetPropertyTypeByAdditionalData(Undefined, Name);
	
	Value = ReadProperty(PropertyType);
	
	Parameters.Insert(Name, Value); 
	
	AfterParameterImportAlgorithm = "";
	If EventsAfterParameterImport.Property(Name, AfterParameterImportAlgorithm)
		And Not IsBlankString(AfterParameterImportAlgorithm) Then
		
		
		If SL20CompatibilityMode() Then
			
			Execute(AfterParameterImportAlgorithm);
			
		Else
			
			ExecuteHandler_Parameters_AfterParameterImport(Name, Value);
			
		EndIf;
		
	EndIf; 
	
EndProcedure

Procedure ImportCustomSearchFieldInfo()
	
	RuleName = "";
	SearchSetup = "";
	
	While ExchangeFile.Read() Do
		
		NodeName = ExchangeFile.LocalName;
		
		If NodeName = "RuleName" Then
			
			RuleName = deElementValue(ExchangeFile, StringType);
			
		ElsIf NodeName = "SearchSetup" Then
			
			SearchSetup = deElementValue(ExchangeFile, StringType);
			CustomSearchFieldInfoOnDataImport.Insert(RuleName, SearchSetup); 
			
		ElsIf (NodeName = "CustomSearchSetup") And (ExchangeFile.NodeType = XMLNodeTypeEndElement) Then
			
			Break;
			
		EndIf;
		
	EndDo; 
	
EndProcedure

// Imports exchange rules according to the exchange format.
//
// Parameters:
// Source     - object where the exchange rules are imported from.
// SourceType - String - specifies the source type: "XMLFile", "XMLReader", "String".
// 
Procedure ImportExchangeRules(   Source = "",
	SourceType = "XMLFile",
	ErrorMessageString = "",
	ImportRuleHeaderOnly = False) Export
	
	InitManagersAndMessages();
	
	HasBeforeExportObjectGlobalHandler  = False;
	HasAfterExportObjectGlobalHandler   = False;
	
	HasBeforeConvertObjectGlobalHandler = False;
	
	HasBeforeImportObjectGlobalHandler  = False;
	HasAfterImportObjectGlobalHandler   = False;
	
	CreateConversionStructure();
	
	SL20CompatibilityModeField = Undefined;
	
	PropertyConversionRuleTable = New ValueTable;
	InitPropertyConversionRuleTable(PropertyConversionRuleTable);
	
	// Perhaps, embedded exchange rules are selected (one of templates)
	
	ExchangeRuleTempFileName = "";
	If IsBlankString(Source) Then
		
		Source = ExchangeRuleFileName;
		
	EndIf;
	
	If SourceType="XMLFile" Then
		
		If IsBlankString(Source) Then
			ErrorMessageString = WriteToExecutionLog(12);
			Return; 
		EndIf;
		
		File = New File(Source);
		If Not File.Exist() Then
			ErrorMessageString = WriteToExecutionLog(3);
			Return; 
		EndIf;
		
		ExchangeRules = New XMLReader();
		ExchangeRules.OpenFile(Source);
		ExchangeRules.Read();
		
	ElsIf SourceType="String" Then
		
		ExchangeRules = New XMLReader();
		ExchangeRules.SetString(Source);
		ExchangeRules.Read();
		
	ElsIf SourceType="XMLReader" Then
		
		ExchangeRules = Source;
		
	EndIf; 
	
	
	If Not ((ExchangeRules.LocalName = "ExchangeRules") And (ExchangeRules.NodeType = XMLNodeTypeStartElement)) Then
		ErrorMessageString = WriteToExecutionLog(7);
		Return;
	EndIf;
	
	
	XMLWriter = New XMLWriter;
	XMLWriter.SetString();
	XMLWriter.WriteStartElement("ExchangeRules");
	
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		// Conversion attributes
		If NodeName = "FormatVersion" Then
			Value = deElementValue(ExchangeRules, StringType);
			Conversion.Insert("FormatVersion", Value);
			
			XMLWriter.WriteStartElement("FormatVersion");
			Str = XMLString(Value);
			
			CompatibilityMode = ExchangeRules.GetAttribute ("CompatibilityMode");
			If CompatibilityMode <> Undefined Then
				Conversion.Insert("CompatibilityMode", CompatibilityMode);
				XMLWriter.WriteAttribute("CompatibilityMode", XMLString(CompatibilityMode));
			EndIf;
			
			XMLWriter.WriteText(Str);
			XMLWriter.WriteEndElement();
		ElsIf NodeName = "ID" Then
			Value = deElementValue(ExchangeRules, StringType);
			Conversion.Insert("ID", Value);
			deWriteElement(XMLWriter, NodeName, Value);
		ElsIf NodeName = "Description" Then
			Value = deElementValue(ExchangeRules, StringType);
			Conversion.Insert("Description", Value);
			deWriteElement(XMLWriter, NodeName, Value);
		ElsIf NodeName = "CreationDateTime" Then
			Value = deElementValue(ExchangeRules, DateType);
			Conversion.Insert("CreationDateTime", Value);
			deWriteElement(XMLWriter, NodeName, Value);
		ElsIf NodeName = "Source" Then
			
			SourcePlatformVersion = ExchangeRules.GetAttribute ("PlatformVersion");
			SourceConfigurationSynonym = ExchangeRules.GetAttribute ("ConfigurationSynonym");
			SourceConfigurationVersion = ExchangeRules.GetAttribute ("ConfigurationVersion");
			
			Conversion.Insert("SourcePlatformVersion", SourcePlatformVersion);
			Conversion.Insert("SourceConfigurationSynonym", SourceConfigurationSynonym);
			Conversion.Insert("SourceConfigurationVersion", SourceConfigurationVersion);
			
			Value = deElementValue(ExchangeRules, StringType);
			Conversion.Insert("Source", Value);
			deWriteElement(XMLWriter, NodeName, Value);
			
		ElsIf NodeName = "Target" Then
			
			TargetPlatformVersion = ExchangeRules.GetAttribute ("PlatformVersion");
			TargetConfigurationSynonym = ExchangeRules.GetAttribute ("ConfigurationSynonym");
			RecipientConfigurationVersion = ExchangeRules.GetAttribute ("ConfigurationVersion");
			
			Conversion.Insert("TargetPlatformVersion", TargetPlatformVersion);
			Conversion.Insert("TargetConfigurationSynonym", TargetConfigurationSynonym);
			Conversion.Insert("RecipientConfigurationVersion", RecipientConfigurationVersion);
			
			Value = deElementValue(ExchangeRules, StringType);
			Conversion.Insert("Target", Value);
			deWriteElement(XMLWriter, NodeName, Value);
			
			If ImportRuleHeaderOnly Then
				Return;
			EndIf;
			
		ElsIf NodeName = "CompatibilityMode" Then
			Value = deElementValue(ExchangeRules, StringType);
			Conversion.Insert("CompatibilityMode",         Value);
			deWriteElement(XMLWriter, NodeName, Value); 
			
		ElsIf NodeName = "Comment" Then
			deSkip(ExchangeRules);
			
		ElsIf NodeName = "MainExchangePlan" Then
			deSkip(ExchangeRules);
			
		ElsIf NodeName = "Parameters" Then
			ImportParameters(ExchangeRules, XMLWriter)
			
			// Conversion events
			
		ElsIf NodeName = "" Then
			
		ElsIf NodeName = "AfterExchangeRuleImport" Then
			Conversion.Insert("AfterExchangeRuleImport", deElementValue(ExchangeRules, StringType));
			
			Conversion.Insert("AfterExchangeRuleImportHandlerName","Conversion_AfterExchangeRuleImport");
			
			
		ElsIf NodeName = "BeforeDataExport" Then
			Conversion.Insert("BeforeDataExport", deElementValue(ExchangeRules, StringType));
			
			Conversion.Insert("BeforeDataExportHandlerName","Conversion_BeforeDataExport");
			
			
		ElsIf NodeName = "BeforeGetChangedObjects" Then
			Conversion.Insert("BeforeGetChangedObjects", deElementValue(ExchangeRules, StringType));   
			Conversion.Insert("BeforeGetChangedObjectsHandlerName","Conversion_BeforeGetChangedObjects");
			
		ElsIf NodeName = "AfterGetExchangeNodeDetails" Then
			
			Conversion.Insert("AfterGetExchangeNodeDetails", deElementValue(ExchangeRules, StringType)); 
			Conversion.Insert("AfterReceiveExchangeNodeDetailsHandlerName","Conversion_AfterGetExchangeNodeDetails");
			
			
			deWriteElement(XMLWriter, NodeName, Conversion.AfterReceiveExchangeNodeDetails);
			
			
		ElsIf NodeName = "AfterDataExport" Then
			Conversion.Insert("AfterDataExport",  deElementValue(ExchangeRules, StringType));
			Conversion.Insert("AfterDataExportHandlerName","Conversion_AfterDataExport");
			
		ElsIf NodeName = "BeforeSendDeletionInfo" Then
			Conversion.Insert("BeforeSendDeletionInfo",  deElementValue(ExchangeRules, StringType));
			Conversion.Insert("BeforeSendDeletionInfoHandlerName","Conversion_BeforeSendDeletionInfo");
			
		ElsIf NodeName = "BeforeExportObject" Then
			Conversion.Insert("BeforeExportObject", deElementValue(ExchangeRules, StringType));
			Conversion.Insert("BeforeObjectExportHandlerName","Conversion_BeforeExportObject");
			HasBeforeExportObjectGlobalHandler = Not IsBlankString(Conversion.BeforeExportObject);
			
			
		ElsIf NodeName = "AfterExportObject" Then
			Conversion.Insert("AfterExportObject", deElementValue(ExchangeRules, StringType));
			Conversion.Insert("AfterObjectExportHandlerName","Conversion_AfterExportObject");
			HasAfterExportObjectGlobalHandler = Not IsBlankString(Conversion.AfterExportObject);
			
		ElsIf NodeName = "BeforeImportObject" Then
			Conversion.Insert("BeforeImportObject", deElementValue(ExchangeRules, StringType));
			Conversion.Insert("BeforeObjectImportHandlerName","Conversion_BeforeImportObject");
			HasBeforeImportObjectGlobalHandler = Not IsBlankString(Conversion.BeforeImportObject);
			deWriteElement(XMLWriter, NodeName, Conversion.BeforeImportObject);
			
		ElsIf NodeName = "AfterImportObject" Then
			Conversion.Insert("AfterImportObject", deElementValue(ExchangeRules, StringType));
			Conversion.Insert("AfterObjectImportHandlerName","Conversion_AfterImportObject");
			HasAfterImportObjectGlobalHandler = Not IsBlankString(Conversion.AfterImportObject);
			deWriteElement(XMLWriter, NodeName, Conversion.AfterImportObject);
			
			
		ElsIf NodeName = "BeforeObjectConversion" Then
			Conversion.Insert("BeforeObjectConversion", deElementValue(ExchangeRules, StringType));
			Conversion.Insert("BeforeObjectConversionHandlerName","Conversion_BeforeObjectConversion");
			HasBeforeConvertObjectGlobalHandler = Not IsBlankString(Conversion.BeforeObjectConversion);
			
		ElsIf NodeName = "BeforeDataImport" Then
			Conversion.BeforeDataImport = deElementValue(ExchangeRules, StringType);
			Conversion.Insert("BeforeDataImportHandlerName","Conversion_BeforeDataImport");
			deWriteElement(XMLWriter, NodeName, Conversion.BeforeDataImport);
			
		ElsIf NodeName = "AfterDataImport" Then
			Conversion.AfterDataImport = deElementValue(ExchangeRules, StringType);
			Conversion.Insert("AfterDataImportHandlerName","Conversion_AfterDataImport");
			deWriteElement(XMLWriter, NodeName, Conversion.AfterDataImport);
			
		ElsIf NodeName = "AfterParameterImport" Then
			Conversion.Insert("AfterParameterImport", deElementValue(ExchangeRules, StringType));
			Conversion.Insert("AfterParameterImportHandlerName","Conversion_AfterParameterImport");
			deWriteElement(XMLWriter, NodeName, Conversion.AfterParameterImport);
			
			
		ElsIf NodeName = "OnGetDeletionInfo" Then
			Conversion.Insert("OnGetDeletionInfo", deElementValue(ExchangeRules, StringType));
			Conversion.Insert("OnGetDeletionInfoHandlerName","Conversion_OnGetDeletionInfo");
			deWriteElement(XMLWriter, NodeName, Conversion.OnGetDeletionInfo);
		ElsIf NodeName = "DeleteMappedObjectsFromTargetOnDeleteFromSource" Then
			Conversion.DeleteMappedObjectsFromTargetOnDeleteFromSource = deElementValue(ExchangeRules, BooleanType);
			
			// Rules
			
		ElsIf NodeName = "DataExportRules" Then
			If ExchangeMode = "Import" Then
				deSkip(ExchangeRules);
			Else
				ImportExportRules(ExchangeRules);
			EndIf; 
			
		ElsIf NodeName = "ObjectConversionRules" Then
			ImportConversionRules(ExchangeRules, XMLWriter);
			
		ElsIf NodeName = "DataClearingRules" Then
			ImportClearingRules(ExchangeRules, XMLWriter)
			
		ElsIf NodeName = "ObjectChangeRecordRules" Then
			deSkip(ExchangeRules);
			
			// Algorithms / Queries / DataProcessors
			
		ElsIf NodeName = "Algorithms" Then
			ImportAlgorithms(ExchangeRules, XMLWriter);
			
		ElsIf NodeName = "Queries" Then
			ImportQueries(ExchangeRules, XMLWriter);
			
		ElsIf NodeName = "DataProcessors" Then
			ImportDataProcessors(ExchangeRules, XMLWriter);
			
			
		ElsIf (NodeName = "ExchangeRules") And (ExchangeRules.NodeType = XMLNodeTypeEndElement) Then
			If ExchangeMode <> "Import" Then
				ExchangeRules.Close();
			EndIf;
			Break;
			
			
			// Format error
		Else
			ErrorMessageString = WriteToExecutionLog(7);
			Return;
		EndIf;
	EndDo;
	
	
	XMLWriter.WriteEndElement();
	XMLRules = XMLWriter.Close();
	
	// Deleting the temporary rule file
	If Not IsBlankString(ExchangeRuleTempFileName) Then
		Try
			DeleteFiles(ExchangeRuleTempFileName);
		Except 
		EndTry;
	EndIf;
	If ImportRuleHeaderOnly Then
		Return;
	EndIf;
	
	// Target type information required for quick data import
	DataStructure = New Map();
	FillInformationByTargetDataTypes(DataStructure, ConversionRuleTable);
	
	TypesForTargetString = CreateTypeStringForTarget(DataStructure);
	
	SecurityProfileName = InitializeDataProcessors();
	
	If SecurityProfileName <> Undefined Then
		SetSafeMode(SecurityProfileName);
	EndIf;
	// The AfterExchangeRuleImport event must be called 
	AfterExchangeRuleImportEventText = "";
	If Conversion.Property("AfterExchangeRuleImport", AfterExchangeRuleImportEventText)
		And Not IsBlankString(AfterExchangeRuleImportEventText) Then
		
		Try
			
			If SL20CompatibilityMode() Then
				
				Execute(AfterExchangeRuleImportEventText);
				
			Else
				
				ExecuteHandler_Conversion_AfterExchangeRuleImport();
				
			EndIf;
		Except
			ErrorMessageString = WriteErrorInfoConversionHandlers(75, ErrorDescription(), NStr("en = 'AfterExchangeRuleImport (conversion)'"));
			Cancel = True;
			
			If Not ContinueOnError Then
				Raise ErrorMessageString;
			EndIf;
			
		EndTry; 
		
	EndIf;
	
	InitializeInitialParameterValues();
	
EndProcedure

Procedure ProcessNewItemReadEnd(LastImportObject = Undefined)
	
	IncreaseImportedObjectCounter();
	
	If ImportedObjectCounter() % 100 = 0
		And GlobalNotWrittenObjectStack.Count() > 100 Then
		
		ExecuteWriteNotWrittenObjects();
		
	EndIf;
	
	// Transactions are managed from the management application during the import in the 
	// external connection mode.
	If Not ExecutingDataImportViaExternalConnection Then
		
		If UseTransactions
			And ObjectCountPerTransaction > 0 
			And ImportedObjectCounter() % ObjectCountPerTransaction = 0 Then
			
			CommitTransaction();
			BeginTransaction();
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure DeleteObjectByLink(Ref, ErrorMessageString)
	
	Object = Ref.GetObject();
	
	
	If Object = Undefined Then
		Return;
	EndIf;
	
	SetDataExchangeLoad(Object);
	
	If Not IsBlankString(Conversion.OnGetDeletionInfo) Then
		
		Cancel = False;
		
		Try
			
			If SL20CompatibilityMode() Then
				
				Execute(Conversion.OnGetDeletionInfo);
				
			Else
				
				ExecuteHandler_Conversion_OnGetDeletionInfo(Object, Cancel);
				
			EndIf;
		Except
			ErrorMessageString = WriteErrorInfoConversionHandlers(77, ErrorDescription(), NStr("en = 'OnGetDeletionInfo (conversion)'"));
			Cancel = True;  
			
			If Not ContinueOnError Then
				Raise ErrorMessageString;
			EndIf;
			
		EndTry;
		
		If Cancel Then
			Return;
		EndIf;
		
	EndIf;
	
	DeleteObject(Object, True); 
	
EndProcedure

Procedure ReadObjectDeletion(ErrorMessageString)
	
	SourceTypeString = deAttribute(ExchangeFile, StringType, "TargetType");
	TargetTypeString = deAttribute(ExchangeFile, StringType, "SourceType");
	
	UUIDString = deAttribute(ExchangeFile, StringType, "UUID");
	
	ReplaceUUIDIfNecessary(UUIDString, SourceTypeString, TargetTypeString, True);
	
	PropertyStructure = Managers[Type(SourceTypeString)];
	
	Ref = PropertyStructure.Manager.GetRef(New UUID(UUIDString));
	
	DeleteObjectByLink(Ref, ErrorMessageString);
	
EndProcedure


Procedure ExecuteSelectiveMessageReader(TableToImport)
	
	If TableToImport.Count() = 0 Then
		Return;
	EndIf;
	
	MessageReader = Undefined;
	Try
		SetErrorFlag(False);
		
		InitializeCommentsOnDataExportAndImport();
		
		CustomSearchFieldInfoOnDataImport = New Map;
		AdditionalSearchParameterMap = New Map;
		ConversionRulesMap = New Map;
		
		// Initializing the exchange log
		EnableExchangeLog();
		
		
		If ProcessedObjectNumberToUpdateStatus = 0 Then
			ProcessedObjectNumberToUpdateStatus = 100;
		EndIf;
		
		GlobalNotWrittenObjectStack = New Map;
		
		ImportedObjectCounterField = Undefined;
		LastSearchByRefNumber  = 0;
		
		InitManagersAndMessages();
		
		
		StartReadMessage(MessageReader, True);
		
		If UseTransactions Then
			BeginTransaction();
		EndIf;
		
		Try
			
			ReadDataForTables(TableToImport);
			
			If ErrorFlag() Then
				Raise NStr("en = 'Errors occurred during data import.'");
			EndIf;
			
			// Deferred writing
			ExecuteWriteNotWrittenObjects();
			
			
			If ErrorFlag() Then
				Raise NStr("en = 'Errors occurred during data import.'");
			EndIf;
			
			FinishMessageReader(MessageReader);
			
			If UseTransactions Then
				CommitTransaction();
			EndIf;
		Except
			If UseTransactions Then
				RollbackTransaction();
			EndIf;
			BreakMessageReader(MessageReader);
			Raise;
		EndTry;
		
		// Posting documents in queue
		ExecuteDeferredDocumentPosting();
		ExecuteDeferredObjectWriting();
		
	Except
		If MessageReader <> Undefined
			And MessageReader.MessageReceivedEarlier Then
			WriteToExecutionLog(174,,,,,,
			Enums.ExchangeExecutionResults.Warning_ExchangeMessageReceivedPreviously
			);
		Else
			WriteToExecutionLog(DetailErrorDescription(ErrorInfo()));
		EndIf;
	EndTry;
	
	DisableExchangeProtocol();
	
EndProcedure

Procedure ReadData(MessageReader)
	
	ErrorMessageString = "";
	
	While ExchangeFile.Read() Do
		
		NodeName = ExchangeFile.LocalName;
		
		If NodeName = "Object" Then
			
			LastImportObject = ReadObject();
			
			ProcessNewItemReadEnd(LastImportObject);
			
		ElsIf NodeName = "RegisterRecordSet" Then
			
			// Register record set
			LastImportObject = ReadRegisterRecordSet();
			
			ProcessNewItemReadEnd(LastImportObject);
			
		ElsIf NodeName = "ObjectDeletion" Then
			
			// Object deletion processing
			ReadObjectDeletion(ErrorMessageString);
			
			deSkip(ExchangeFile, "ObjectDeletion");
			
			ProcessNewItemReadEnd();
			
		ElsIf NodeName = "ObjectChangeRecordData" Then
			
			HasObjectChangeRecordData = True;
			
			LastImportObject = ReadObjectChangeRecordInfo();
			
			ProcessNewItemReadEnd(LastImportObject);
			
			
		ElsIf NodeName = "ObjectChangeRecordDataAdjustment" Then
			
			HasObjectChangeRecordDataAdjustment = True;
			
			ReadMappingInfoAdjustment();
			
			deSkip(ExchangeFile, NodeName);
			
		ElsIf NodeName = "CommonNodeData" Then
			
			ReadCommonNodeData(MessageReader);
			
			deSkip(ExchangeFile, NodeName);
			
		ElsIf (NodeName = "ExchangeFile") And (ExchangeFile.NodeType = XMLNodeTypeEndElement) Then
			
			Break; // exiting
			
		Else
			
			
			Raise NStr("en = 'Exchange messages format error.'");
			
		EndIf;
		
		// Interrupting file reading iteration in case of import error
		If ErrorFlag() Then
			Raise NStr("en = 'Errors occurred during data import.'");
		EndIf;
		
	EndDo;
	
	
EndProcedure

Procedure ReadDataForTables(TableToImport)
	
	While ExchangeFile.Read() Do
		
		NodeName = ExchangeFile.LocalName;
		
		If NodeName = "Object" Then
			
			ObjectTypeString = deAttribute(ExchangeFile, StringType, "Type");
			
			If ObjectTypeString = "ConstantsSet" Then
				
				ConstantName = deAttribute(ExchangeFile, StringType, "ConstantName");
				
				SourceTypeString = ConstantName;
				TargetTypeString = ConstantName;
				
			Else
				
				RuleName = deAttribute(ExchangeFile, StringType, "RuleName");
				
				OCR = Rules[RuleName];
				
				SourceTypeString = OCR.SourceType;
				TargetTypeString = OCR.TargetType;
				
			EndIf;
			
			DataTableKey = DataExchangeServer.DataTableKey(SourceTypeString, TargetTypeString, False);
			
			If TableToImport.Find(DataTableKey) <> Undefined Then
				
				If DataImportIntoInfobaseMode() Then // Importing data into the infobase
					
					ProcessNewItemReadEnd(ReadObject());
					
				Else // Importing data into the value table
					
					UUIDString = "";
					
					LastImportObject = ReadObject(UUIDString);
					
					If LastImportObject <> Undefined Then
						
						ExchangeMessageDataTable = ExchangeMessageDataTable().Get(DataTableKey);
						
						TableRow = ExchangeMessageDataTable.Find(UUIDString, UUIDColumnName());
						
						If TableRow = Undefined Then
							
							IncreaseImportedObjectCounter();
							
							TableRow = ExchangeMessageDataTable.Add();
							
							TableRow[TypeStringColumnName()] = TargetTypeString;
							TableRow["Ref"]                  = LastImportObject.Ref;
							TableRow[UUIDColumnName()]       = UUIDString;
							
						EndIf;
						
						// Filling object property values
						FillPropertyValues(TableRow, LastImportObject);
						
					EndIf;
					
				EndIf;
				
			Else
				
				deSkip(ExchangeFile, NodeName);
				
			EndIf;
			
			
		ElsIf NodeName = "RegisterRecordSet" Then
			
			If DataImportIntoInfobaseMode() Then
				
				RuleName = deAttribute(ExchangeFile, StringType, "RuleName");
				
				OCR = Rules[RuleName];
				
				SourceTypeString = OCR.SourceType;
				TargetTypeString = OCR.TargetType;
				
				DataTableKey = DataExchangeServer.DataTableKey(SourceTypeString, TargetTypeString, False);
				
				If TableToImport.Find(DataTableKey) <> Undefined Then
					
					ProcessNewItemReadEnd(ReadRegisterRecordSet());
					
				Else
					deSkip(ExchangeFile, NodeName);
					
				EndIf;
				
			Else
				
				deSkip(ExchangeFile, NodeName);
				
			EndIf;
			
		ElsIf NodeName = "ObjectDeletion" Then
			
			TargetTypeString = deAttribute(ExchangeFile, StringType, "TargetType");
			SourceTypeString = deAttribute(ExchangeFile, StringType, "SourceType");
			
			DataTableKey = DataExchangeServer.DataTableKey(SourceTypeString, TargetTypeString, True);
			
			If TableToImport.Find(DataTableKey) <> Undefined Then
				
				If DataImportIntoInfobaseMode() Then // Importing data into the infobase
					
					// Object deletion processing
					ReadObjectDeletion("");
					
					ProcessNewItemReadEnd();
					
				Else // Importing data into the value table
					
					UUIDString = deAttribute(ExchangeFile, StringType, "UUID");
					
					// Adding object deletion to the message data table
					ExchangeMessageDataTable = ExchangeMessageDataTable().Get(DataTableKey);
					
					TableRow = ExchangeMessageDataTable.Find(UUIDString, UUIDColumnName());
					
					If TableRow = Undefined Then
						
						IncreaseImportedObjectCounter();
						
						TableRow = ExchangeMessageDataTable.Add();
						
						// Filling values of all table fields with the default value
						For Each Column In ExchangeMessageDataTable.Columns Do
							
							// Filter
							If    Column.Name = TypeStringColumnName()
								Or Column.Name = UUIDColumnName()
								Or Column.Name = "Ref" Then
								Continue;
							EndIf;
							
							If Column.ValueType.ContainsType(StringType) Then
								
								TableRow[Column.Name] = NStr("en = 'Object deletion");
								
							EndIf;
							
						EndDo;
						
						PropertyStructure = Managers[Type(TargetTypeString)];
						
						ObjectToDeleteRef = PropertyStructure.Manager.GetRef(New UUID(UUIDString));
						
						TableRow[TypeStringColumnName()] = TargetTypeString;
						TableRow["Ref"]                  = ObjectToDeleteRef;
						TableRow[UUIDColumnName()] = UUIDString;
						
					EndIf;
					
				EndIf;
				
			EndIf;
			
			deSkip(ExchangeFile, NodeName);
			
			
		ElsIf NodeName = "ObjectChangeRecordData" Then
			
			deSkip(ExchangeFile, NodeName); // Skipping item in selective message read mode
			
		ElsIf NodeName = "ObjectChangeRecordDataAdjustment" Then
			
			
			deSkip(ExchangeFile, NodeName); // Skipping item in selective message read mode
			
			
		ElsIf NodeName = "CommonNodeData" Then
			
			deSkip(ExchangeFile, NodeName); // Skipping item in selective message read mode
			
		ElsIf (NodeName = "ExchangeFile") And (ExchangeFile.NodeType = XMLNodeTypeEndElement) Then
			
			Break;
			
		Else
			
			
			Raise NStr("en = 'Exchange messages format error.'");
			
		EndIf;
		
		// Skipping item in selective message read mode
		If ErrorFlag() Then
			
			Raise NStr("en = 'Errors occurred during data import.'");
		EndIf;
		
	EndDo;
	
	
EndProcedure


Procedure ReadDataInAnalysisMode(MessageReader)
	
	While ExchangeFile.Read() Do
		
		NodeName = ExchangeFile.LocalName;
		
		If    NodeName = "Object" Then
			
			ObjectTypeString = deAttribute(ExchangeFile, StringType, "Type");
			
			If ObjectTypeString <> "ConstantsSet" Then
				
				
				RuleName = deAttribute(ExchangeFile, StringType, "RuleName");
				
				OCR = Rules[RuleName];
				
				// Objects with automatic mapping during the exchange (classifiers)
				// do not display in the statistic information table.
				// Statistic information gathering for the objects is not required.
				// Objects that are identified by the search fields rather than by 
				// a unique ID References are not displayed.
				
				IsClassifier = OCR.SynchronizeByID And OCR.SearchBySearchFieldsIfNotFoundByID;
				
				If Not IsClassifier And OCR.SynchronizeByID Then
					
					
					TableRow = PackageHeaderDataTable().Add();
					
					TableRow.ObjectTypeString    = ObjectTypeString;
					TableRow.ObjectCountInSource = 1;
					
					TableRow.TargetTypeString = OCR.TargetType;
					TableRow.SourceTypeString = OCR.SourceType;
					
					
					TableRow.SearchFields = ObjectMappingMechanismSearchFields(OCR.SearchFields);
					TableRow.TableFields  = OCR.TableFields;
					
					TableRow.SynchronizeByID  = OCR.SynchronizeByID;
					TableRow.UsePreview       = OCR.SynchronizeByID;
					TableRow.IsClassifier     = False;
					TableRow.IsObjectDeletion = False;
					
				EndIf;
				
			EndIf;
			
			deSkip(ExchangeFile, NodeName);
			
		ElsIf NodeName = "RegisterRecordSet" Then
			
			deSkip(ExchangeFile, NodeName);
			
		ElsIf NodeName = "ObjectDeletion" Then
			
			
			TableRow = PackageHeaderDataTable().Add();
			
			TableRow.TargetTypeString = deAttribute(ExchangeFile, StringType, "TargetType");
			TableRow.SourceTypeString = deAttribute(ExchangeFile, StringType, "SourceType");
			
			TableRow.ObjectTypeString = TableRow.TargetTypeString;
			
			TableRow.ObjectCountInSource = 1;
			
			TableRow.SynchronizeByID  = False;
			TableRow.UsePreview       = True;
			TableRow.IsClassifier     = False;
			TableRow.IsObjectDeletion = True;
			
			TableRow.SearchFields = ""; // Search fields assignes in object mapping processing
			
			// Specifying values for TableFields column.
			// Getting description of all configuration metadata object fields
			ObjectType = Type(TableRow.ObjectTypeString);
			MetadataObject = Metadata.FindByType(ObjectType);
			
			SubstringArray = ObjectPropertyInfoTable(MetadataObject).UnloadColumn("Name");
			
			// Deleting field Reference from visible table fields
			CommonUseClientServer.DeleteValueFromArray(SubstringArray, "Ref");
			
			TableRow.TableFields = StringFunctionsClientServer.StringFromSubstringArray(SubstringArray);
			
			deSkip(ExchangeFile, NodeName);
			
		ElsIf NodeName = "ObjectChangeRecordData" Then
			
			HasObjectChangeRecordData = True;
			
			LastImportObject = ReadObjectChangeRecordInfo();
			
			ProcessNewItemReadEnd(LastImportObject);
			
		ElsIf NodeName = "ObjectChangeRecordDataAdjustment" Then
			
			HasObjectChangeRecordDataAdjustment = True;
			
			
			ReadMappingInfoAdjustment();
			
			deSkip(ExchangeFile, NodeName);
			
		ElsIf NodeName = "CommonNodeData" Then
			
			ReadCommonNodeData(MessageReader);
			
			deSkip(ExchangeFile, NodeName);
			
		ElsIf (NodeName = "ExchangeFile") And (ExchangeFile.NodeType = XMLNodeType.EndElement) Then
			
			Break; // exit
			
			
		Else
			
			Raise NStr("en = 'Exchange messages format error.'");
			
		EndIf;
		
		
		// Interrupting file reading iteration in case of import error
		If ErrorFlag() Then
			Raise NStr("en = 'Errors occurred during data analyzing.'");
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure ReadDataInExternalConnectionMode(MessageReader)
	
	ErrorMessageString = "";
	
	While ExchangeFile.Read() Do
		
		NodeName = ExchangeFile.LocalName;
		
		If NodeName = "Object" Then
			
			LastImportObject = ReadObject();
			
			ProcessNewItemReadEnd(LastImportObject);
			
		ElsIf NodeName = "RegisterRecordSet" Then
			
			// a set records register
			LastImportObject = ReadRegisterRecordSet();   
			
			ProcessNewItemReadEnd(LastImportObject); 
			
			
		ElsIf NodeName = "ObjectDeletion" Then
			
			// Processing of object deletion from infobase
			ReadObjectDeletion(ErrorMessageString);
			
			deSkip(ExchangeFile, "ObjectDeletion");
			
			ProcessNewItemReadEnd();
			
			
		ElsIf NodeName = "ObjectChangeRecordData" Then
			
			HasObjectChangeRecordData = True;
			
			LastImportObject = ReadObjectChangeRecordInfo();
			
			ProcessNewItemReadEnd(LastImportObject);
			
		ElsIf NodeName = "CustomSearchSetup" Then
			
			ImportCustomSearchFieldInfo();
			
		ElsIf NodeName = "DataTypeInfo" Then
			
			If DataForImportTypeMap().Count() > 0 Then
				
				deSkip(ExchangeFile, NodeName);
				
			Else
				ImportDataTypeInfo();
			EndIf;
			
		ElsIf NodeName = "ParameterValue" Then 
			
			ImportDataExchangeParameterValues();
			
		ElsIf NodeName = "AfterParameterExportAlgorithm" Then
			
			
			Cancel = False;
			CancelReason = "";
			
			
			AlgorithmText = deElementValue(ExchangeFile, StringType);
			
			If Not IsBlankString(AlgorithmText) Then
				
				Try
					
					If SL20CompatibilityMode() Then
						
						Execute(AlgorithmText);
						
					Else
						
						ExecuteHandler_Conversion_AfterParameterImport(ExchangeFile, Cancel, CancelReason);
						
					EndIf;
					
					If Cancel = True Then
						
						If Not IsBlankString(CancelReason) Then
							
							MessageString = NStr("en = 'Data import is canceled for the following reason: %1'");
							MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, CancelReason);
							Raise MessageString;
						Else
							Raise NStr("en = 'Data import has been canceled.'");
						EndIf;
						
					EndIf;
					
				Except
					
					LR = GetLogRecordStructure(78, ErrorDescription());
					LR.Handler     = "AfterParameterImport";
					ErrorMessageString = WriteToExecutionLog(78, LR, True);
					
					If Not ContinueOnError Then
						Raise ErrorMessageString;
					EndIf;
					
				EndTry;
				
			EndIf;
			
		ElsIf NodeName = "ExchangeData" Then
			
			ReadDataViaExchange(MessageReader, False);
			
			deSkip(ExchangeFile, NodeName);
			
			If ErrorFlag() Then
				Break;
			EndIf;
			
		ElsIf NodeName = "CommonNodeData" Then
			
			ReadCommonNodeData(Undefined);
			
			deSkip(ExchangeFile, NodeName);
			
			If ErrorFlag() Then
				Break;
			EndIf;
			
		ElsIf NodeName = "ObjectChangeRecordDataAdjustment" Then
			
			ReadMappingInfoAdjustment();
			
			HasObjectChangeRecordDataAdjustment = True;
			
			deSkip(ExchangeFile, NodeName);
			
		ElsIf (NodeName = "ExchangeFile") And (ExchangeFile.NodeType = XMLNodeTypeEndElement) Then
			
			Break; // exiting
			
		Else
			
			deSkip(ExchangeFile, NodeName);
			
		EndIf;
		
		// Interrupting file reading iteration in case of import error
		If ErrorFlag() Then
			Break;
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure ReadDataViaExchange(MessageReader, DataAnalysis)
	
	ExchangePlanNameField      = deAttribute(ExchangeFile, StringType, "ExchangePlan");
	FromWhomCode               = deAttribute(ExchangeFile, StringType, "FromWhom");
	MessageNumberField         = deAttribute(ExchangeFile, NumberType,  "OutgoingMessageNumber");
	ReceivedMessageNumberField = deAttribute(ExchangeFile, NumberType,  "IncomingMessageNumber");
	DeleteChangeRecords        = deAttribute(ExchangeFile, BooleanType, "DeleteChangeRecords");
	SenderVersion              = deAttribute(ExchangeFile, StringType, "SenderVersion");
	ExchangeNodeRecipient      = ExchangePlans[ExchangePlanName()].FindByCode(FromWhomCode);
	
	// Checking whether the target node exists.
	// Checking whether the target node is specified correctly in the exchange message.
	If Not ValueIsFilled(ExchangeNodeRecipient)
		Or ExchangeNodeRecipient <> ExchangeNodeDataImport Then
		
		MessageString = NStr("en = 'The exchange plan node for data import is not found. Exchange plan: %1, Code: %2'");
		MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, ExchangePlanName(), FromWhomCode);
		Raise MessageString;
		
	EndIf;
	
	
	MessageReader = New Structure("MessageNo, ReceivedNo, SenderObject, Sender, MessageReceivedEarlier, DataAnalysis");
	MessageReader.Sender       = ExchangeNodeRecipient;
	MessageReader.SenderObject = ExchangeNodeRecipient.GetObject();
	MessageReader.MessageNo    = MessageNumberField;
	MessageReader.ReceivedNo   = ReceivedMessageNumberField;
	MessageReader.MessageReceivedEarlier = False;
	MessageReader.DataAnalysis = DataAnalysis;
	MessageReader = New FixedStructure(MessageReader);
	
	
	BackupRestored = (MessageReader.ReceivedNo > CommonUse.ObjectAttributeValue(MessageReader.Sender, "SentNo"));
	
	If DataImportIntoInfobaseMode() Then
		
		BeginTransaction();
		ReceivedNo = CommonUse.ObjectAttributeValue(MessageReader.Sender, "ReceivedNo");
		CommitTransaction();
		
		If ReceivedNo >= MessageReader.MessageNo Then // The messages number is less or equal to the previously received one   
			
			MessageReaderTemporary = CommonUseClientServer.CopyStructure(MessageReader);
			MessageReaderTemporary.MessageReceivedEarlier = True;
			MessageReader = New FixedStructure(MessageReaderTemporary);
			
			Raise NStr("en = 'Exchange message was received earlier'");
		EndIf;
		
		DeleteChangeRecords = DeleteChangeRecords And Not BackupRestored;
		
		If DeleteChangeRecords Then // Deleting change records
			
			If TransactionActive() Then
				Raise NStr("en = 'Deletion of data change registration in an active transaction is not allowed.'");
			EndIf;
			
			ExchangePlans.DeleteChangeRecords(MessageReader.Sender, MessageReader.ReceivedNo);
			
			
			InformationRegisters.CommonNodeDataChanges.DeleteChangeRecords(MessageReader.Sender, MessageReader.ReceivedNo);
			
			If CommonUseClientServer.CompareVersions(IncomingExchangeMessageFormatVersion(), "3.1.0.0") >= 0 Then
				
				InformationRegisters.CommonInfobaseNodeSettings.CommitMappingInfoAdjustment(MessageReader.Sender, MessageReader.ReceivedNo);
				
			EndIf;
			
			InformationRegisters.CommonInfobaseNodeSettings.ClearInitialDataExportFlag(MessageReader.Sender, MessageReader.ReceivedNo);
			
		EndIf;
		
		If BackupRestored Then
			
			MessageReader.SenderObject.SentNo = MessageReader.ReceivedNo;
			MessageReader.SenderObject.AdditionalProperties.Insert("Import");
			MessageReader.SenderObject.Write();
			
			MessageReaderTemporary = CommonUseClientServer.CopyStructure(MessageReader);
			MessageReaderTemporary.SenderObject = MessageReader.Sender.GetObject();
			MessageReader = New FixedStructure(MessageReaderTemporary);
		EndIf;
		
		InformationRegisters.CommonInfobaseNodeSettings.SetCorrespondentVersion(MessageReader.Sender, SenderVersion);
		
		
	EndIf;
	
	// {Handler: AfterGetExchangeNodeDetails} Start
	If Not IsBlankString(Conversion.AfterReceiveExchangeNodeDetails) Then
		
		Try
			
			If SL20CompatibilityMode() Then
				
				Execute(Conversion.AfterReceiveExchangeNodeDetails);
				
			Else
				
				ExecuteHandler_Conversion_AfterReceiveExchangeNodeDetails(MessageReader.Sender);
				
			EndIf;
			
		Except
			Raise WriteErrorInfoConversionHandlers(176, ErrorDescription(), NStr("en = 'AfterGetExchangeNodeDetails (conversion)'"));
		EndTry;
		
	EndIf;
	// {Handler: AfterGetExchangeNodeDetails} End
	
EndProcedure

Procedure ReadCommonNodeData(MessageReader)
	
	ExchangeFile.Read();
	
	DataImportModePrevious = DataImportMode;
	
	DataImportMode = "ImportToValueTable";
	
	CommonNode = ReadObject();
	
	IncreaseImportedObjectCounter();
	
	DataImportMode = DataImportModePrevious;
	
	// {Handler: OnGetSenderData} Beginning
	Ignore = False;
	
	ExchangePlans[CommonNode.Metadata().Name].OnGetSenderData(CommonNode, Ignore);
	
	If Ignore = True Then
		Return;
	EndIf;
	// {Handler: OnGetSenderData} End
	
	If DataExchangeEvents.DataDifferent(CommonNode, CommonNode.Ref.GetObject()) Then
		
		BeginTransaction();
		Try
			
			CommonNode.AdditionalProperties.Insert("Import");
			CommonNode.Write();
			
			// Updating cached values of the mechanism
			DataExchangeServerCall.ResetObjectChangeRecordMechanismCache();
			
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
		
		OpenTransaction = False;
		If TransactionActive() Then
			CommitTransaction();
			OpenTransaction = True;
		EndIf;
		
		// Deleting change records to prevent conflicts if changes were registered previously.
		InformationRegisters.CommonNodeDataChanges.DeleteChangeRecords(CommonNode.Ref);
		
		If OpenTransaction Then
			BeginTransaction();
		EndIf;
		
		If MessageReader <> Undefined
			And CommonNode.Ref = MessageReader.Sender Then
			
			MessageReaderTemporary = CommonUseClientServer.CopyStructure(MessageReader);
			MessageReaderTemporary.SenderObject = MessageReader.Sender.GetObject();
			MessageReader = New FixedStructure(MessageReaderTemporary);
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure ExecuteDeferredDocumentPosting()
	
	If DocumentsForDeferredPosting().Count() = 0 Then
		Return // Queue is empty
	EndIf;
	
	// Grouping table by the unique fields
	DocumentsForDeferredPosting().GroupBy("DocumentRef, DocumentDate");
	
	// Sorting documents in ascending dates
	
	DocumentsForDeferredPosting().Sort("DocumentDate");
	
	
	For Each TableRow In DocumentsForDeferredPosting() Do
		
		DocumentRef = TableRow.DocumentRef;
		
		If DocumentRef.IsEmpty() Then
			Continue;
		EndIf;
		
		Object = DocumentRef.GetObject();
		
		If Object = Undefined Then
			Continue;
		EndIf;
		
		// Setting sender node to prevent object registration on the target node. 
		// Do not post document in import mode.
		
		SetDataExchangeLoad(Object, False);
		
		ErrorDescription = "";
		DocumentPostedSuccessfully = False;
		
		Try
			
			AdditionalProperties = AdditionalPropertiesForDeferredPosting().Get(DocumentRef);
			
			For Each Property In AdditionalProperties Do
				
				Object.AdditionalProperties.Insert(Property.Key, Property.Value);
				
			EndDo;
			
			Object.AdditionalProperties.Insert("DeferredPosting");
			
			If Object.CheckFilling() Then
				
				// Cancelling prohibition on PRO execution during document posting.  
				// PRO were ignored during document writing to optimize data import speeds.
				
				If Object.AdditionalProperties.Property("DisableObjectChangeRecordMechanism") Then
					Object.AdditionalProperties.Delete("DisableObjectChangeRecordMechanism");
				EndIf;
				
				DataExchangeServer.IgnoreChangeProhibitionCheck();
				Object.AdditionalProperties.Insert("IgnoreChangeProhibitionCheck");
				
				ObjectVersionDetails = New Structure;
				ObjectVersionDetails.Insert("DeferredProcessing", True);
				ObjectVersionDetails.Insert("ObjectVersionType", "ChangedByUser");
				ObjectVersionDetails.Insert("VersionAuthor", ExchangeNodeDataImport);
				Object.AdditionalProperties.Insert("ObjectVersionDetails", ObjectVersionDetails);
				
				// Try to post document
				
				Object.Write(DocumentWriteMode.Posting);
				
				DocumentPostedSuccessfully = Object.Posted;
				
			Else
				
				DocumentPostedSuccessfully = False;
				
			EndIf;
			
		Except
			
			ErrorDescription = BriefErrorDescription(ErrorInfo());
			
			DocumentPostedSuccessfully = False;
			
		EndTry;
		
		DataExchangeServer.IgnoreChangeProhibitionCheck(False);
		
		If Not DocumentPostedSuccessfully Then
			
			DataExchangeServer.RecordDocumentPostingError(Object, ExchangeNodeDataImport, ErrorDescription);
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure ExecuteDeferredObjectWriting()
	
	If ObjectsForDeferredPosting().Count() = 0 Then
		Return // There is no objects in the queue
	EndIf;
	
	For Each MapObject In ObjectsForDeferredPosting() Do
		
		If MapObject.Key.IsEmpty() Then
			Continue;
		EndIf;
		
		Object = MapObject.Key.GetObject();
		
		If Object = Undefined Then
			Continue;
		EndIf;
		
		// Setting sender node to prevent object registration on the
		// target node Do not post document in import mode
		SetDataExchangeLoad(Object, False);
		
		ErrorDescription = "";
		ObjectWrittenSuccessfully = False;
		
		Try
			
			AdditionalProperties = MapObject.Value;
			
			For Each Property In AdditionalProperties Do
				
				Object.AdditionalProperties.Insert(Property.Key, Property.Value);
				
			EndDo;
			
			Object.AdditionalProperties.Insert("DeferredWriting");
			
			If Object.CheckFilling() Then
				
				// ORR were ignored during
				// ordinary document writing, enabling them now
				If Object.AdditionalProperties.Property("DisableObjectChangeRecordMechanism") Then
					Object.AdditionalProperties.Delete("DisableObjectChangeRecordMechanism");
				EndIf;
				
				DataExchangeServer.IgnoreChangeProhibitionCheck();
				Object.AdditionalProperties.Insert("IgnoreChangeProhibitionCheck");
				
				ObjectVersionDetails = New Structure;
				ObjectVersionDetails.Insert("DeferredProcessing", True);
				ObjectVersionDetails.Insert("ObjectVersionType", "ChangedByUser");
				ObjectVersionDetails.Insert("VersionAuthor", ExchangeNodeDataImport);
				Object.AdditionalProperties.Insert("ObjectVersionDetails", ObjectVersionDetails);
				
				// Attempting to write the object
				Object.Write();
				
				ObjectWrittenSuccessfully = True;
				
			Else
				
				ObjectWrittenSuccessfully = False;
				
				ErrorDescription = NStr("en = 'Attribute filling check error'");
				
			EndIf;
			
		Except
			
			ErrorDescription = BriefErrorDescription(ErrorInfo());
			
			ObjectWrittenSuccessfully = False;
			
		EndTry;
		
		DataExchangeServer.IgnoreChangeProhibitionCheck(False);
		
		If Not ObjectWrittenSuccessfully Then
			
			DataExchangeServer.RecordObjectWriteError(Object, ExchangeNodeDataImport, ErrorDescription);
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure WriteInformationOnDataExchangeOverExchangePlans(Val SentNo)
	
	Target = CreateNode("ExchangeData");
	
	SetAttribute(Target, "ExchangePlan", ExchangePlanName());
	SetAttribute(Target, "Recipient",   NodeForExchange.Code);
	SetAttribute(Target, "FromWhom", ExchangePlans[ExchangePlanName()].ThisNode().Code); 
	
	// Exchange messages acknowledgment mechanism attributes
	SetAttribute(Target, "OutgoingMessageNumber", SentNo);
	SetAttribute(Target, "IncomingMessageNumber",  NodeForExchange.ReceivedNo);
	SetAttribute(Target, "DeleteChangeRecords", True);
	SetAttribute(Target, "SenderVersion", TrimAll(Metadata.Version));
	// Writing the object to the file
	Target.WriteEndElement();
	
	WriteToFile(Target);
	
EndProcedure

Procedure ExportCommonNodeData(Val SentNo)
	
	NodeChangesSelection = InformationRegisters.CommonNodeDataChanges.SelectChanges(NodeForExchange, SentNo);
	
	If NodeChangesSelection.Count() = 0 Then
		Return;
	EndIf;
	
	ExchangePlanName = DataExchangeCached.GetExchangePlanName(NodeForExchange);
	
	CommonNodeData = DataExchangeCached.CommonNodeData(NodeForExchange);
	
	If IsBlankString(CommonNodeData) Then
		Return;
	EndIf;
	
	PropertyConversionRules = New ValueTable;
	InitPropertyConversionRuleTable(PropertyConversionRules);
	
	Properties       = PropertyConversionRules.Copy();
	SearchProperties = PropertyConversionRules.Copy();
	
	CommonNodeMetadata = Metadata.ExchangePlans[ExchangePlanName];
	
	CommonNodeTabularSections = DataExchangeEvents.ObjectTabularSections(CommonNodeMetadata);
	
	CommonNodeProperties = StringFunctionsClientServer.SplitStringIntoSubstringArray(CommonNodeData);
	
	For Each Property In CommonNodeProperties Do
		
		If CommonNodeTabularSections.Find(Property) <> Undefined Then
			
			PCR = Properties.Add();
			PCR.IsFolder = True;
			PCR.SourceKind = "TabularSection";
			PCR.TargetKind = "TabularSection";
			PCR.Source = Property;
			PCR.Target = Property;
			PCR.GroupRules = PropertyConversionRules.Copy();
			
			For Each Attribute In CommonNodeMetadata.TabularSections[Property].Attributes Do
				
				PGCR = PCR.GroupRules.Add();
				PGCR.IsFolder = False;
				PGCR.SourceKind = "Attribute";
				PGCR.TargetKind = "Attribute";
				PGCR.Source = Attribute.Name;
				PGCR.Target = Attribute.Name;
				
			EndDo;
			
		Else
			
			PCR = Properties.Add();
			PCR.IsFolder = False;
			PCR.SourceKind = "Attribute";
			PCR.TargetKind = "Attribute";
			PCR.Source = Property;
			PCR.Target = Property;
			
		EndIf;
		
	EndDo;
	
	PCR = SearchProperties.Add();
	PCR.SourceKind = "Property";
	PCR.TargetKind = "Property";
	PCR.Source = "Code";
	PCR.Target = "Code";
	PCR.SourceType = "String";
	PCR.TargetType = "String";
	
	OCR = ConversionRuleTable.Add();
	OCR.SynchronizeByID = False;
	OCR.SearchBySearchFieldsIfNotFoundByID = False;
	OCR.DontExportPropertyObjectsByRefs = True;
	OCR.SourceType = "ExchangePlanRef." + ExchangePlanName;
	OCR.Source = Type(OCR.SourceType);
	OCR.TargetType = OCR.SourceType;
	OCR.Target     = OCR.SourceType;
	
	OCR.Properties = Properties;
	OCR.SearchProperties = SearchProperties;
	
	CommonNode = ExchangePlans[ExchangePlanName].CreateNode();
	DataExchangeEvents.FillObjectPropertyValues(CommonNode, NodeForExchange.GetObject(), CommonNodeData);
	// {Handler: OnSendSenderData} Start
	Ignore = False;
	
	ExchangePlans[CommonNode.Metadata().Name].OnSendSenderData(CommonNode, Ignore);
	
	If Ignore = True Then
		Return;
	EndIf;
	// {Handler: OnSendSenderData} End
	CommonNode.Code = DataExchangeCached.GetThisNodeCodeForExchangePlan(ExchangePlanName);
	
	XMLNode = CreateNode("CommonNodeData");
	
	ExportByRule(CommonNode,,,,,,, OCR,,, XMLNode);
	
	XMLNode.WriteEndElement();
	
	WriteToFile(XMLNode);
	
EndProcedure

Function ExportRefObjectData(Value, OutgoingData, OCRName, PropertyOCR, TargetType, PropertyNode, Val ExportRefOnly)
	
	IsRuleWithGlobalExport = False;
	RefNode = ExportByRule(Value, , OutgoingData, , OCRName, , ExportRefOnly, PropertyOCR, IsRuleWithGlobalExport, , , , False);
	RefNodeType = TypeOf(RefNode);
	
	If IsBlankString(TargetType) Then
		
		TargetType  = PropertyOCR.Target;
		SetAttribute(PropertyNode, "Type", TargetType);
		
	EndIf;
	
	If RefNode = Undefined Then
		
		Return Undefined;
		
	EndIf;
	
	AddPropertiesForExport(RefNode, RefNodeType, PropertyNode, IsRuleWithGlobalExport); 
	
	Return RefNode;
	
EndFunction

Procedure PassOneParameterToTarget(Name, InitialParameterValue, ConversionRule = "")
	
	If IsBlankString(ConversionRule) Then
		
		ParameterNode = CreateNode("ParameterValue");
		
		SetAttribute(ParameterNode, "Name", Name);
		SetAttribute(ParameterNode, "Type", String(TypeOf(InitialParameterValue)));
		
		IsNULL = False;
		Empty = deEmpty(InitialParameterValue, IsNULL);
		
		If Empty Then
			
			// Writing the empty value
			deWriteElement(ParameterNode, "Empty");
			
			ParameterNode.WriteEndElement();
			
			WriteToFile(ParameterNode);
			
			Return;
			
		EndIf;
		
		deWriteElement(ParameterNode, "Value", InitialParameterValue);
		
		ParameterNode.WriteEndElement();
		
		WriteToFile(ParameterNode);
		
	Else
		
		ParameterNode = CreateNode("ParameterValue");
		
		SetAttribute(ParameterNode, "Name", Name);
		
		IsNULL = False;
		Empty = deEmpty(InitialParameterValue, IsNULL);
		
		If Empty Then
			
			PropertyOCR = FindRule(InitialParameterValue, ConversionRule);
			TargetType  = PropertyOCR.Target;
			SetAttribute(ParameterNode, "Type", TargetType);
			
			// Writing the empty value
			deWriteElement(ParameterNode, "Empty");
			
			ParameterNode.WriteEndElement();
			
			WriteToFile(ParameterNode);
			
			Return;
			
		EndIf;
		
		ExportRefObjectData(InitialParameterValue, , ConversionRule, , , ParameterNode, True);
		
		ParameterNode.WriteEndElement();
		
		WriteToFile(ParameterNode);    
		
	EndIf; 
	
EndProcedure

Procedure PassExtendedParametersToTarget()
	
	For Each Parameter In ParameterSetupTable Do
		
		If Parameter.PassParameterOnExport = True Then
			
			PassOneParameterToTarget(Parameter.Name, Parameter.Value, Parameter.ConversionRule);
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure PassTypeDetailsToTarget()
	
	If Not IsBlankString(TypesForTargetString) Then
		WriteToFile(TypesForTargetString);
	EndIf;
	
EndProcedure

Procedure SendCustomSearchFieldInfoToTarget()
	
	For Each MapKeyAndValue In CustomSearchFieldInfoOnDataExport Do
		
		ParameterNode = CreateNode("CustomSearchSetup");
		
		deWriteElement(ParameterNode, "RuleName", MapKeyAndValue.Key);
		deWriteElement(ParameterNode, "SearchSetup", MapKeyAndValue.Value);
		
		ParameterNode.WriteEndElement();
		WriteToFile(ParameterNode);
		
	EndDo;
	
EndProcedure

Procedure InitializeCommentsOnDataExportAndImport()
	
	CommentOnDataExport = "";
	CommentOnDataImport = "";
	
EndProcedure

Procedure ExportedByRefObjectsAddValue(Value)
	
	If ExportedByRefObjects().Find(Value) = Undefined Then
		
		ExportedByRefObjects().Add(Value);
		
	EndIf;
	
EndProcedure

Function ObjectPassesAllowedObjectFilter(Value)
	
	Return InformationRegisters.InfobaseObjectMappings.ObjectIsInRegister(Value, NodeForExchange);
	
EndFunction

Function ObjectMappingMechanismSearchFields(Val SearchFields)
	
	SearchFieldsCollection = StringFunctionsClientServer.SplitStringIntoSubstringArray(SearchFields);
	
	CommonUseClientServer.DeleteValueFromArray(SearchFieldsCollection, "IsFolder");
	
	Return StringFunctionsClientServer.StringFromSubstringArray(SearchFieldsCollection);
EndFunction


Procedure ExecuteExport(ErrorMessageString = "")
	
	ExchangePlanNameField = DataExchangeCached.GetExchangePlanName(NodeForExchange);
	
	ExportMappingInformation = ExportObjectMappingInfo(NodeForExchange);
	
	InitializeCommentsOnDataExportAndImport();
	
	CurrentNestingLevelExportByRule = 0;
	
	DataExportCallStack = New ValueTable;
	DataExportCallStack.Columns.Add("Ref");
	DataExportCallStack.Indexes.Add("Ref");
	
	InitManagersAndMessages();
	
	ExportedObjectCounterField = Undefined;
	SnCounter    = 0;
	WrittenToFileSn = 0;
	
	For Each Rule In ConversionRuleTable Do
		
		Rule.Exported = CreateExportedObjectTable();
		
	EndDo;
	
	// Getting types of metadata objects that will take a part in data export
	UsedExportRuleTable = ExportRuleTable.Copy(New Structure("Enable", True));
	
	For Each TableRow In UsedExportRuleTable Do
		
		If Not TableRow.SelectionObject = Type("ConstantsSet") Then
			
			TableRow.SelectionObjectMetadata = Metadata.FindByType(TableRow.SelectionObject);
			
		EndIf;
		
	EndDo;
	
	DataMapForExportedItemUpdate = New Map;
	
	// {BeforeDataExport handler}
	Cancel = False;
	
	If Not IsBlankString(Conversion.BeforeDataExport) Then
		
		Try
			
			If SL20CompatibilityMode() Then
				
				Execute(Conversion.BeforeDataExport);
				
			Else
				
				ExecuteHandler_Conversion_BeforeDataExport(ExchangeFile, Cancel);
				
			EndIf;
		Except
			WriteErrorInfoConversionHandlers(62, ErrorDescription(), NStr("en = 'BeforeDataExport (conversion)'"));
			Cancel = True;
		EndTry; 
		
		If Cancel Then // Canceling data export
			DisableExchangeProtocol();
			Return;
		EndIf;
		
	EndIf;
	// {BeforeDataExport handler}
	
	SendCustomSearchFieldInfoToTarget();
	
	PassTypeDetailsToTarget();
	
	// Passing additional parameters to the target infobase
	PassExtendedParametersToTarget();
	
	EventTextAfterParameterImport = "";
	If Conversion.Property("AfterParameterImport", EventTextAfterParameterImport)
		And Not IsBlankString(EventTextAfterParameterImport) Then
		
		WritingEvent = New XMLWriter;
		WritingEvent.SetString();
		deWriteElement(WritingEvent, "AfterParameterExportAlgorithm", EventTextAfterParameterImport);
		
		WriteToFile(WritingEvent);
		
	EndIf;
	
	SentNo = CommonUse.ObjectAttributeValue(NodeForExchange, "SentNo") + ?(ExportMappingInformation, 2, 1);
	
	WriteInformationOnDataExchangeOverExchangePlans(SentNo);
	
	ExportCommonNodeData(SentNo);
	
	Cancel = False;
	
	// EXPORTING MAPPING REGISTER
	If ExportMappingInformation Then
		
		XMLWriter = New XMLWriter;
		XMLWriter.SetString();
		WriteMessage = ExchangePlans.CreateMessageWriter();
		WriteMessage.BeginWrite(XMLWriter, NodeForExchange);
		
		Try
			ExportObjectMappingRegister(WriteMessage, ErrorMessageString);
		Except
			Cancel = True;
		EndTry;
		
		If Cancel Then
			WriteMessage.CancelWrite();
		Else
			WriteMessage.EndWrite();
		EndIf;
		
		XMLWriter.Close();
		XMLWriter = Undefined;
		
		If Cancel Then
			Return;
		EndIf;
		
	EndIf;
	
	// EXPORTING MAPPING REGISTER ADJUSTMENTS
	If MustAdjustMappingInfo() Then
		
		ExportMappingInfoAdjustment();
		
	EndIf;
	
	// EXPORTING REGISTERED DATA
	XMLWriter = New XMLWriter;
	XMLWriter.SetString();
	WriteMessage = ExchangePlans.CreateMessageWriter();
	WriteMessage.BeginWrite(XMLWriter, NodeForExchange);
	
	Try
		ExportRecordedData(WriteMessage, ErrorMessageString, UsedExportRuleTable);
	Except
		Cancel = True;
		WriteToExecutionLog(DetailErrorDescription(ErrorInfo()));
		
		If IsExchangeOverExternalConnection() Then
			
			If DataImportExecutedInExternalConnection Then
				
				While ExternalConnection.TransactionActive() Do
					ExternalConnection.RollbackTransaction();
				EndDo;
				
			Else
				
				DataProcessorForDataImport().ExternalConnectionRollbackTransactionOnDataImport();
				
			EndIf;
			
		EndIf;
		
	EndTry;
	
	// Registering objects exported by reference in the current node
	For Each Item In ExportedByRefObjects() Do
		
		ExchangePlans.RecordChanges(WriteMessage.Recipient, Item);
		
	EndDo;
	
	// Setting the number of sent message for objects exported by reference
	If ExportedByRefObjects().Count() > 0 Then
		
		
		DataExchangeServer.SelectChanges(WriteMessage.Recipient, WriteMessage.MessageNo, ExportedByRefObjects());
		
	EndIf;
	
	// Setting the number of sent message for objects created in current session
	If CreatedOnExportObjects().Count() > 0 Then
		
		DataExchangeServer.SelectChanges(WriteMessage.Recipient, WriteMessage.MessageNo, CreatedOnExportObjects());
		
	EndIf;
	
	If Cancel Then
		WriteMessage.CancelWrite();
	Else
		WriteMessage.EndWrite();
	EndIf;
	
	XMLWriter.Close();
	XMLWriter = Undefined;
	
	// {AfterDataExport handler}
	If Not Cancel And Not IsBlankString(Conversion.AfterDataExport) Then
		
		Try
			
			If SL20CompatibilityMode() Then
				
				Execute(Conversion.AfterDataExport);
				
			Else
				
				ExecuteHandler_Conversion_AfterDataExport(ExchangeFile);
				
			EndIf;
		Except
			WriteErrorInfoConversionHandlers(63, ErrorDescription(), NStr("en = 'AfterDataExport (conversion)'"));
		EndTry;
		
	EndIf;
	// {AfterDataExport handler}
	
EndProcedure

Procedure ExportObjectMappingRegister(WriteMessage, ErrorMessageString)
	
	// Selecting changes for mapping register only 
	ChangeSelection = DataExchangeServer.SelectChanges(WriteMessage.Recipient, WriteMessage.MessageNo, Metadata.InformationRegisters.InfobaseObjectMaps);
	
	While ChangeSelection.Next() Do
		
		Data = ChangeSelection.Get();
		
		// Filtering data export
		If Data.Filter.InfobaseNode.Value <> NodeForExchange Then
			Continue;
		ElsIf IsBlankString(Data.Filter.TargetUUID.Value) Then
			Continue;
		EndIf;
		
		ExportObject = True;
		
		For Each Record In Data Do
			
			If ExportObject And Record.ObjectExportedByRef = True Then
				
				ExportObject = False;
				
			EndIf;
			
		EndDo;
		
		// Exporting registered data from the InfobaseObjectMaps information register.
		// Information register conversion rules are in the script of this handler.
		If ExportObject Then
			
			ExportChangeRecordedObjectData(Data);
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure ExportRecordedData(WriteMessage, ErrorMessageString, UsedExportRuleTable)
	
	// Variables for supporting the event handler script debugging mechanism 
	Var Cancel, OCRName, DataSelection, OutgoingData;
	// {BeforeGetChangedObjects handler}
	If Not IsBlankString(Conversion.BeforeGetChangedObjects) Then
		
		Try
			
			Recipient = NodeForExchange;
			
			If SL20CompatibilityMode() Then
				
				Execute(Conversion.BeforeGetChangedObjects);
				
			Else
				
				ExecuteHandler_Conversion_BeforeGetChangedObjects(Recipient, BackgroundExchangeNode);
				
			EndIf;
		Except
			WriteErrorInfoConversionHandlers(175, ErrorDescription(), NStr("en = 'BeforeGetChangedObjects (conversion)'"));   Return;
		EndTry;
		
	EndIf;
	// {BeforeGetChangedObjects handler}
	
	MetadataToExportArray = UsedExportRuleTable.UnloadColumn("SelectionObjectMetadata");
	
	// The "Undefined" value means that constants must be exported
	If MetadataToExportArray.Find(Undefined) <> Undefined Then
		
		SupplementMetadataToExportArrayWithConstants(MetadataToExportArray);
		
	EndIf;
	
	// Deleting items that contain the "Undefined" value from the array
	DeleteInvalidValuesFromMetadataToExportArray(MetadataToExportArray);
	
	// The InfobaseObjectMaps information register is exported separately, therefore, 
	// deleting it from the following selection.
	If MetadataToExportArray.Find(Metadata.InformationRegisters.InfobaseObjectMappings) <> Undefined Then
		
		CommonUseClientServer.DeleteValueFromArray(MetadataToExportArray, Metadata.InformationRegisters.InfobaseObjectMaps);
		
	EndIf;
	
	// Updating reusable object registration mechanism values
	DataExchangeServerCall.CheckObjectChangeRecordMechanismCache(); 
	InitialDataExport = DataExchangeServer.InitialDataExportFlagIsSet(WriteMessage.Recipient);
	
	// CHANGE SELECTION
	ChangeSelection = DataExchangeServer.SelectChanges(WriteMessage.Recipient, WriteMessage.MessageNo, MetadataToExportArray);
	
	PreviousMetadataObject = Undefined;
	PreviousDataExportRule = Undefined;
	DataExportRule         = Undefined;
	ExportFileNumber       = 0;
	FileString             = Undefined;
	ExportingRegister      = False;
	ExportingConstants     = False;
	
	IsExchangeOverExternalConnection = IsExchangeOverExternalConnection();
	
	If IsExchangeOverExternalConnection Then
		
		If DataImportExecutedInExternalConnection Then
			
			If DataProcessorForDataImport().UseTransactions Then
				
				ExternalConnection.BeginTransaction();
				
			EndIf;
			
		Else
			
			DataProcessorForDataImport().ExternalConnectionBeginTransactionOnDataImport();
			
		EndIf;
		
	EndIf;
	NodeForExchangeObject = NodeForExchange.GetObject();
	While ChangeSelection.Next() Do
		
		Data = ChangeSelection.Get();
		
		ExportDataType = TypeOf(Data);
		
		// Processing object deletion
		If ExportDataType = ObjectDeletionType Then
			
			ProcessObjectDeletion(Data);
			Continue;
			
		EndIf;
		
		CurrentMetadataObject = Data.Metadata();
		
		// Exporting the new metadata object type
		If PreviousMetadataObject <> CurrentMetadataObject Then
			
			If PreviousMetadataObject <> Undefined Then
				
				// {DER AfterProcess HANDLER}
				If PreviousDataExportRule <> Undefined
					And Not IsBlankString(PreviousDataExportRule.AfterProcess) Then
					
					Try
						
						If SL20CompatibilityMode() Then
							
							Execute(PreviousDataExportRule.AfterProcess);
							
						Else
							
							ExecuteHandler_DER_AfterProcessRule(OCRName, PreviousDataExportRule, OutgoingData);
							
						EndIf;
					Except
						WriteErrorInfoDERHandlers(32, ErrorDescription(), PreviousDataExportRule.Name, , "AfterProcessDataExport");
					EndTry;
					
				EndIf;
				// {DER AfterProcess HANDLER}
				
			EndIf;
			
			PreviousMetadataObject = CurrentMetadataObject;
			
			ExportingRegister = False;
			ExportingConstants = False;
			
			DataStructure = ManagersForExchangePlans[CurrentMetadataObject];
			
			If DataStructure = Undefined Then
				
				ExportingConstants = Metadata.Constants.Contains(CurrentMetadataObject);
				
			ElsIf DataStructure.IsRegister = True Then
				
				ExportingRegister = True;
				
			EndIf;
			
			If ExportingConstants Then
				
				DataExportRule = UsedExportRuleTable.Find(Type("ConstantsSet"), "SelectionObjectMetadata");
				
			Else
				
				DataExportRule = UsedExportRuleTable.Find(CurrentMetadataObject, "SelectionObjectMetadata");
				
			EndIf;
			
			PreviousDataExportRule = DataExportRule;
			
			// {DER BeforeProcess HANDLER}
			OutgoingData = Undefined;
			
			If DataExportRule <> Undefined
				And Not IsBlankString(DataExportRule.BeforeProcess) Then
				
				Try
					
					If SL20CompatibilityMode() Then
						
						Execute(DataExportRule.BeforeProcess);
						
					Else
						
						ExecuteHandler_DER_BeforeProcessRule(Cancel, OCRName, DataExportRule, OutgoingData, DataSelection);
						
					EndIf;
				Except
					WriteErrorInfoDERHandlers(31, ErrorDescription(), DataExportRule.Name, "BeforeProcessDataExport");
				EndTry;
				
			EndIf;
			// {DER BeforeProcess HANDLER}
			
		EndIf;
		
		If ExportDataType <> MapRegisterType Then
			
			// Defining the object sending kind
			ItemSend = DataItemSend.Auto;
			
			
			StandardSubsystemsServer.OnSendDataToSlave(Data, ItemSend, InitialDataExport, NodeForExchangeObject);
			
			If ItemSend = DataItemSend.Delete Then
				
				If ExportingRegister Then
					
					// Sending an empty record set as a register deletion
					
				Else
					
					// Sending data about deleting
					ProcessObjectDeletion(Data);
					Continue;
					
				EndIf;
				
			ElsIf ItemSend = DataItemSend.Ignore Then
				
				Continue;
				
			EndIf;
			
		EndIf;
		
		// EXPORTING THE OBJECT
		If ExportingRegister Then
			
			// Exporting the register
			RegisterExport(Data, DataExportRule, OutgoingData, DontExportObjectsByRefs);
			
		ElsIf ExportingConstants Then
			
			// Exporting the constant set
			Properties = Managers[Type("ConstantsSet")];
			
			ExportConstantsSet(DataExportRule, Properties, OutgoingData, CurrentMetadataObject.Name);
			
		Else
			
			// Exporting reference types
			SelectionItemExport(Data, DataExportRule, , OutgoingData, DontExportObjectsByRefs);
			
		EndIf;
		
		If IsExchangeOverExternalConnection Then
			
			If DataImportExecutedInExternalConnection Then
				
				If DataProcessorForDataImport().UseTransactions
					And DataProcessorForDataImport().ObjectCountPerTransaction > 0
					And DataProcessorForDataImport().ImportedObjectCounter() % DataProcessorForDataImport().ObjectCountPerTransaction = 0 Then
					
					ExternalConnection.CommitTransaction();
					ExternalConnection.BeginTransaction();
					
				EndIf;
				
				
			Else
				
				DataProcessorForDataImport().ExternalConnectionCheckTransactionStartAndCommitOnDataImport();
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	If PreviousMetadataObject <> Undefined Then
		
		// {DER AfterProcess HANDLER}
		If DataExportRule <> Undefined
			And Not IsBlankString(DataExportRule.AfterProcess) Then
			
			Try
				
				If SL20CompatibilityMode() Then
					
					Execute(DataExportRule.AfterProcess);
					
				Else
					
					ExecuteHandler_DER_AfterProcessRule(OCRName, DataExportRule, OutgoingData);
					
				EndIf;
			Except
				WriteErrorInfoDERHandlers(32, ErrorDescription(), DataExportRule.Name, "AfterProcessDataExport");
			EndTry;
			
		EndIf;
		// {DER AfterProcess HANDLER}
		
	EndIf;
	
	If IsExchangeOverExternalConnection Then
		
		If DataImportExecutedInExternalConnection Then
			
			If DataProcessorForDataImport().UseTransactions Then
				
				If DataProcessorForDataImport().ErrorFlag() Then
					
					ExternalConnection.RollbackTransaction();
					
				Else
					
					ExternalConnection.CommitTransaction();
					
				EndIf;
				
			EndIf;
			
		Else
			
			DataProcessorForDataImport().ExternalConnectionCommitTransactionOnDataImport();
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure WriteLogEventDataExchange(Comment, Level = Undefined)
	
	If Level = Undefined Then
		Level = EventLogLevel.Error;
	EndIf;
	
	MetadataObject = Undefined;
	
	If     ExchangeNodeDataImport <> Undefined
		And Not ExchangeNodeDataImport.IsEmpty() Then
		
		MetadataObject = ExchangeNodeDataImport.Metadata();
		
	EndIf;
	
	WriteLogEvent(EventLogMessageKey(), Level, MetadataObject,, Comment);
	
EndProcedure

Function ExportObjectMappingInfo(InfobaseNode)
	
	QueryText = "
	|SELECT TOP 1 1
	|FROM
	| InformationRegister.InfobaseObjectMappings.Changes AS InfobaseObjectMappingsChanges
	|WHERE
	| InfobaseObjectMappingsChanges.Node = &InfobaseNode
	|";	
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("InfobaseNode", InfobaseNode);
	
	Return Not Query.Execute().IsEmpty();
	
EndFunction

Function MustAdjustMappingInfo()
	
	Return InformationRegisters.CommonInfobaseNodeSettings.MustAdjustMappingInfo(NodeForExchange, NodeForExchange.SentNo + 1);
	
EndFunction

Procedure DeleteInvalidValuesFromMetadataToExportArray(MetadataToExportArray)
	
	If MetadataToExportArray.Find(Undefined) <> Undefined Then
		
		CommonUseClientServer.DeleteValueFromArray(MetadataToExportArray, Undefined);
		
		DeleteInvalidValuesFromMetadataToExportArray(MetadataToExportArray);
		
	EndIf;
	
EndProcedure

Procedure SupplementMetadataToExportArrayWithConstants(MetadataToExportArray)
	
	Content = Metadata.ExchangePlans[ExchangePlanName()].Content;
	
	For Each MetadataObjectConstant In Metadata.Constants Do
		
		If Content.Contains(MetadataObjectConstant) Then
			
			MetadataToExportArray.Add(MetadataObjectConstant);
			
		EndIf;
		
	EndDo;
	
EndProcedure

Function IsPredefinedItem(Object)
	
	Try
		Result = Object.Predefined;
	Except
		Result = False;
	EndTry;
	
	Return Result;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// PREDEFINED CONVERSION RULES

Procedure ImportConversionRule_ExchangeObjectExportModes(XMLWriter)
	
	
	
	SourceType = "EnumRef.ExchangeObjectExportModes";
	
	TargetType = "EnumRef.ExchangeObjectExportModes";
	
	
	
	Filter = New Structure;
	
	Filter.Insert("SourceType", SourceType);
	
	Filter.Insert("TargetType", TargetType);
	
	
	
	If ConversionRuleTable.FindRows(Filter).Count() <> 0 Then
		
		Return;
		
	EndIf;
	
	
	
	NewRow = ConversionRuleTable.Add();	
	
	NewRow.RememberExported = True;	
	NewRow.DontReplace            = False;	
	NewRow.ExchangeObjectPriority = Enums.ExchangeObjectPriorities.ReceivedExchangeObjectPriorityHigher;
	
	
	NewRow.Properties         = PropertyConversionRuleTable.Copy();	
	NewRow.SearchProperties   = PropertyConversionRuleTable.Copy();	
	NewRow.DisabledProperties = PropertyConversionRuleTable.Copy();	
	
	NewRow.Name = "ExchangeObjectExportModes";	
	NewRow.Source = Type(SourceType);	
	NewRow.Target = TargetType;
	
	NewRow.SourceType = SourceType;	
	NewRow.TargetType = TargetType;	
	
	Values = New Structure;	
	Values.Insert("UnloadAlways",      "UnloadAlways");	
	Values.Insert("ExportByCondition", "ExportByCondition");	
	Values.Insert("ExportIfNecessary", "ExportIfNecessary");	
	Values.Insert("ManualExport",      "ManualExport");	
	Values.Insert("NotExport",         "NotExport");	
	NewRow.PredefinedDataReadValues = Values;	
	
	SearchInTabularSections = New ValueTable;	
	SearchInTabularSections.Columns.Add("ItemName");	
	SearchInTabularSections.Columns.Add("KeySearchFieldArray");	
	SearchInTabularSections.Columns.Add("KeySearchFields");	
	SearchInTabularSections.Columns.Add("Valid", deTypeDescription("Boolean"));	
	NewRow.SearchInTabularSections = SearchInTabularSections;
	
	Managers[NewRow.Source].OCR = NewRow;
	
	Rules.Insert(NewRow.Name, NewRow);
	
	XMLWriter.WriteStartElement("Rule");	
	deWriteElement(XMLWriter, "Code", NewRow.Name);	
	deWriteElement(XMLWriter, "Source", NewRow.SourceType);
	
	deWriteElement(XMLWriter, "Target", NewRow.TargetType);	
	XMLWriter.WriteEndElement(); // Rule
	
	
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// EXCHANGE RULE TABLE INITIALIZATION

// Initializes object property conversion rule table columns.
//
// Parameters:
//  Tab  ValueTable  property conversion rule table to be initialized.
// 
Procedure InitPropertyConversionRuleTable(Tab)
	
	Columns = Tab.Columns;
	
	Columns.Add("Name");
	Columns.Add("Description");
	Columns.Add("Order");
	
	Columns.Add("IsFolder",      deTypeDescription("Boolean"));
	Columns.Add("IsSearchField", deTypeDescription("Boolean"));
	Columns.Add("GroupRules");
	Columns.Add("DisabledGroupRules");
	
	Columns.Add("SourceKind");
	Columns.Add("TargetKind");
	
	Columns.Add("SimplifiedPropertyExport",     deTypeDescription("Boolean"));
	Columns.Add("XMLNodeRequiredOnExport",      deTypeDescription("Boolean"));
	Columns.Add("XMLNodeRequiredOnExportGroup", deTypeDescription("Boolean"));
	
	Columns.Add("SourceType", deTypeDescription("String"));
	Columns.Add("TargetType", deTypeDescription("String"));
	
	Columns.Add("Source");
	Columns.Add("Target");
	
	Columns.Add("ConversionRule");
	
	Columns.Add("GetFromIncomingData", deTypeDescription("Boolean"));
	
	Columns.Add("DontReplace",         deTypeDescription("Boolean"));
	Columns.Add("IsRequiredProperty",  deTypeDescription("Boolean"));
	
	
	Columns.Add("BeforeExport");
	Columns.Add("BeforeExportHandlerName");
	Columns.Add("OnExport");
	Columns.Add("OnExportHandlerName");
	Columns.Add("AfterExport");
	Columns.Add("AfterExportHandlerName");
	
	Columns.Add("BeforeProcessExport");
	Columns.Add("BeforeExportProcessHandlerName");
	Columns.Add("AfterProcessExport");
	Columns.Add("AfterExportProcessHandlerName");
	
	Columns.Add("HasBeforeExportHandler", deTypeDescription("Boolean"));
	Columns.Add("HasOnExportHandler",     deTypeDescription("Boolean"));
	Columns.Add("HasAfterExportHandler",  deTypeDescription("Boolean"));
	
	Columns.Add("HasBeforeProcessExportHandler", deTypeDescription("Boolean"));
	Columns.Add("HasAfterProcessExportHandler",  deTypeDescription("Boolean"));
	
	Columns.Add("CastToLength",             deTypeDescription("Number"));
	Columns.Add("ParameterForTransferName", deTypeDescription("String"));
	Columns.Add("SearchByEqualDate",        deTypeDescription("Boolean"));
	Columns.Add("ExportGroupToFile",        deTypeDescription("Boolean"));
	
	Columns.Add("SearchFieldString");
	
EndProcedure

Function CreateExportedObjectTable()
	
	Table = New ValueTable();
	Table.Columns.Add("Key");
	Table.Columns.Add("RefNode");
	Table.Columns.Add("OnlyRefExported", New TypeDescription("Boolean"));
	Table.Columns.Add("RefSn",           New TypeDescription("Number"));
	Table.Columns.Add("CallCount",       New TypeDescription("Number"));
	Table.Columns.Add("LastCallNumber",  New TypeDescription("Number"));
	
	Table.Indexes.Add("Key");
	
	Return Table;
	
EndFunction

// Initializes object conversion rule table columns.
// 
Procedure InitConversionRuleTable()
	
	Columns = ConversionRuleTable.Columns;
	
	Columns.Add("Name");
	Columns.Add("Description");
	Columns.Add("Order");
	
	Columns.Add("SynchronizeByID",                    deTypeDescription("Boolean"));
	Columns.Add("DontCreateIfNotFound",               deTypeDescription("Boolean"));
	Columns.Add("DontExportPropertyObjectsByRefs",    deTypeDescription("Boolean"));
	Columns.Add("SearchBySearchFieldsIfNotFoundByID", deTypeDescription("Boolean"));
	Columns.Add("OnExchangeObjectByRefSetGIUDOnly",   deTypeDescription("Boolean"));
	Columns.Add("DontReplaceCreatedInTargetObject",   deTypeDescription("Boolean"));
	Columns.Add("UseQuickSearchOnImport",             deTypeDescription("Boolean"));
	Columns.Add("GenerateNewNumberOrCodeIfNotSet",    deTypeDescription("Boolean"));
	
	Columns.Add("TinyObjectCount",                    deTypeDescription("Boolean"));
	Columns.Add("RefExportReferenceCount",            deTypeDescription("Number"));
	Columns.Add("InfobaseItemCount",                  deTypeDescription("Number"));
	
	Columns.Add("ExportMethod");
	
	Columns.Add("Source");
	Columns.Add("Target");
	
	Columns.Add("SourceType", deTypeDescription("String"));
	Columns.Add("TargetType", deTypeDescription("String"));
	
	
	Columns.Add("BeforeExport");
	Columns.Add("BeforeExportHandlerName");
	
	Columns.Add("OnExport");
	Columns.Add("OnExportHandlerName");
	
	Columns.Add("AfterExport");
	Columns.Add("AfterExportHandlerName");
	
	Columns.Add("AfterExportToFile");
	Columns.Add("AfterExportToFileHandlerName");
	
	Columns.Add("HasBeforeExportHandler", deTypeDescription("Boolean"));
	Columns.Add("HasOnExportHandler",     deTypeDescription("Boolean"));
	Columns.Add("HasAfterExportHandler",  deTypeDescription("Boolean"));
	Columns.Add("HasAfterExportToFileHandler",deTypeDescription("Boolean"));
	
	Columns.Add("BeforeImport");
	Columns.Add("BeforeImportHandlerName");
	
	Columns.Add("OnImport");
	Columns.Add("OnImportHandlerName");
	
	Columns.Add("AfterImport");
	Columns.Add("AfterImportHandlerName");
	
	Columns.Add("SearchFieldSequence");
	Columns.Add("SearchFieldSequenceHandlerName");
	Columns.Add("SearchInTabularSections");
	
	Columns.Add("ExchangeObjectPriority");
	
	Columns.Add("HasBeforeImportHandler", deTypeDescription("Boolean"));
	Columns.Add("HasOnImportHandler",     deTypeDescription("Boolean"));
	Columns.Add("HasAfterImportHandler",  deTypeDescription("Boolean"));
	
	Columns.Add("HasSearchFieldSequenceHandler", deTypeDescription("Boolean"));
	
	Columns.Add("Properties",         deTypeDescription("ValueTable"));
	Columns.Add("SearchProperties",   deTypeDescription("ValueTable"));
	Columns.Add("DisabledProperties", deTypeDescription("ValueTable"));
	
	
	// Property "Values" not used
	// Columns.Add("Values", deTypeDescription("Map"));
	
	// Map.
	// Key   - predefined item value in the base.
	// Value - predefined value string presentation in the receiver.
	Columns.Add("PredefinedDataValues", deTypeDescription("Map"));
	
	// Structure.
	// Key   - predefined value string presentation in the base.
	// Value - predefined value string presentation in the receiver.
	Columns.Add("PredefinedDataReadValues", deTypeDescription("Structure"));
	
	Columns.Add("Exported",                 deTypeDescription("ValueTable"));
	Columns.Add("ExportSourcePresentation", deTypeDescription("Boolean"));
	
	Columns.Add("DontReplace", deTypeDescription("Boolean"));
	
	Columns.Add("RememberExported",   deTypeDescription("Boolean"));
	Columns.Add("AllObjectsExported", deTypeDescription("Boolean"));
	
	Columns.Add("SearchFields", deTypeDescription("String"));
	Columns.Add("TableFields",  deTypeDescription("String"));
	
EndProcedure

// Initializes data export rule table columns.
// 
Procedure InitExportRuleTable()
	
	Columns = ExportRuleTable.Columns;
	
	Columns.Add("Enable", deTypeDescription("Boolean"));
	
	Columns.Add("Name");
	Columns.Add("Description");
	Columns.Add("Order");
	
	Columns.Add("DataSelectionVariant");
	Columns.Add("SelectionObject");
	Columns.Add("SelectionObjectMetadata");
	
	Columns.Add("ConversionRule");
	
	
	Columns.Add("BeforeProcess");
	Columns.Add("BeforeProcessHandlerName");
	Columns.Add("AfterProcess");
	Columns.Add("AfterProcessHandlerName");
	
	Columns.Add("BeforeExport");
	Columns.Add("BeforeExportHandlerName");
	Columns.Add("AfterExport");
	Columns.Add("AfterExportHandlerName");
	
	// Columns for support filter c using builder
	Columns.Add("UseFilter", deTypeDescription("Boolean"));
	Columns.Add("BuilderSettings");
	Columns.Add("ObjectForQueryName");
	Columns.Add("ObjectNameForRegisterQuery");
	Columns.Add("RecipientTypeName");
	
	Columns.Add("DontExportCreatedInTargetInfobaseObjects", deTypeDescription("Boolean"));
	
	Columns.Add("ExchangeNodeRef");
	
	Columns.Add("SynchronizeByID", deTypeDescription("Boolean"));
	
EndProcedure

// Initializes data clearing rule table columns.
// 
Procedure CleaningRuleTableInitialization()
	
	Columns = ClearingRuleTable.Columns;
	
	Columns.Add("Enable",   deTypeDescription("Boolean"));
	Columns.Add("IsFolder", deTypeDescription("Boolean"));
	
	Columns.Add("Name");
	Columns.Add("Description");
	Columns.Add("Order", deTypeDescription("Number"));
	
	Columns.Add("DataSelectionVariant");
	Columns.Add("SelectionObject");
	
	Columns.Add("DeleteForPeriod");
	Columns.Add("Directly", deTypeDescription("Boolean"));
	
	Columns.Add("BeforeProcess");
	
	Columns.Add("BeforeProcessHandlerName");
	Columns.Add("AfterProcess");
	Columns.Add("AfterProcessHandlerName");
	Columns.Add("BeforeDelete");
	Columns.Add("BeforeDeleteHandlerName");
	
EndProcedure

// Initializes parameter settings table columns.
// 
Procedure InitializationParameterSetupTable()
	
	Columns = ParameterSetupTable.Columns;
	
	Columns.Add("Name");
	Columns.Add("Description");
	Columns.Add("Value");
	Columns.Add("PassParameterOnExport");
	Columns.Add("ConversionRule");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INITIALIZATION OF DETAILS AND MODULE VARIABLES

Function InitExchangeMessageDataTable(ObjectType)
	
	ExchangeMessageDataTable = New ValueTable;
	
	Columns = ExchangeMessageDataTable.Columns;
	
	// Mandatory fields
	Columns.Add(UUIDColumnName(),        String36Type);
	Columns.Add(TypeStringColumnName(),  String255Type);
	
	MetadataObject = Metadata.FindByType(ObjectType);
	
	// Getting a description of all metadata object fields from the configuration
	ObjectPropertyInfoTable = CommonUse.GetObjectPropertyInfoTable(MetadataObject, "Name, Type");
	
	For Each PropertyDetails In ObjectPropertyInfoTable Do
		
		
		ColumnType = New TypeDescription(PropertyDetails.Type, "NULL");
		Columns.Add(PropertyDetails.Name, ColumnType);
	EndDo;
	
	ExchangeMessageDataTable.Indexes.Add(UUIDColumnName());
	
	Return ExchangeMessageDataTable;
	
EndFunction

Function InitializeDataProcessors()
	
	ExchangePlanName = ExchangePlanName();
	ExchangePlanID = CommonUse.MetadataObjectID(Metadata.ExchangePlans[ExchangePlanName]);
	SecurityProfileName = SafeModeInternal.ExternalModuleAttachingMode(ExchangePlanID);
	
	If SL20CompatibilityMode() Then
		
		Return Undefined;
		
	EndIf;
	
	
	ExchangePlanManager = ExchangePlans[ExchangePlanName];
	
	If ExchangeMode = "Data" Or ExchangeMode = "" Then
		
		If ExportHandlerDebug Then
			
			If SecurityProfileName = Undefined Then
				ExportDataProcessor = ExternalDataProcessors.Create(ExportDebugExternalDataProcessorFileName);
			Else
				ExportDataProcessor = ExternalDataProcessors.Create(ExportDebugExternalDataProcessorFileName, SecurityProfileName);
			EndIf;
			
			
		Else
			
			ExportDataProcessorName = ExchangePlanManager.ExportDataProcessorName();
			
			Try
				
				ExportDataProcessor = DataProcessors[ExportDataProcessorName].Create();
				
			Except
				
				ErrorMessageString = WriteToExecutionLog(18);
				
			EndTry;
			
		EndIf;
		
		
		ExportDataProcessor.AttachDataProcessorToDebug(ThisObject);
		
	ElsIf ExchangeMode = "Import" Then
		
		If ImportHandlerDebug Then
			
			If SecurityProfileName = Undefined Then
				LoadProcessing = ExternalDataProcessors.Create(ImportDebugExternalDataProcessorFileName);
			Else
				LoadProcessing = ExternalDataProcessors.Create(ImportDebugExternalDataProcessorFileName, SecurityProfileName);
			EndIf;
			
		Else
			
			ImportDataProcessorName = ExchangePlanManager.ImportDataProcessorName();
			
			Try
				
				LoadProcessing = DataProcessors[ImportDataProcessorName].Create();
				
			Except
				
				ErrorMessageString = WriteToExecutionLog(18);
				
			EndTry;
			
		EndIf;
		
		LoadProcessing.AttachDataProcessorToDebug(ThisObject);
		
	EndIf;
	
	Return SecurityProfileName;
	
EndFunction
// Initializes the ErrorMessages variable, which contains mapping of message codes 
// to their description. 
// 
Procedure InitMessages()
	
	ErrorMessages = New  Map;
	
	ErrorMessages.Insert(2, "Error unpacking exchange file. The file is locked.");
	ErrorMessages.Insert(3, "The specified exchange rule file does not exist.");
	ErrorMessages.Insert(4, "Error creating Msxml2.DOMDocument COM object.");
	ErrorMessages.Insert(5, "Error opening exchange file.");
	ErrorMessages.Insert(6, "Error importing exchange rules.");
	ErrorMessages.Insert(7, "Exchange rule format error.");
	ErrorMessages.Insert(8, "Invalid data export file name.");// not used
	ErrorMessages.Insert(9, "Exchange file format error.");
	ErrorMessages.Insert(10, "Data export file name is not specified.");
	ErrorMessages.Insert(11, "Exchange rules contain a reference to a nonexistent metadata object.");
	ErrorMessages.Insert(12, "Exchange rule file name is not specified.");
	
	ErrorMessages.Insert(13, "Error retrieving object property value (by the source property name).");
	ErrorMessages.Insert(14, "Error retrieving object property value (by the target property name).");
	
	ErrorMessages.Insert(15, "Import file name is not specified.");
	
	ErrorMessages.Insert(16, "Error retrieving subordinate object property value (by source property name).");
	ErrorMessages.Insert(17, "Error retrieving subordinate object property value (by target property name).");
	ErrorMessages.Insert(18, NStr("en = 'Error creating processing with handler script'")); 
	ErrorMessages.Insert(19, "BeforeImportObject event handler error.");
	ErrorMessages.Insert(20, "OnImportObject event handler error.");
	ErrorMessages.Insert(21, "AfterImportObject event handler error.");
	ErrorMessages.Insert(22, "BeforeDataImport event handler error (data conversion).");
	ErrorMessages.Insert(23, "AfterDataImport event handler error (data conversion).");
	ErrorMessages.Insert(24, "Error deleting object.");
	ErrorMessages.Insert(25, "Error writing document.");
	ErrorMessages.Insert(26, "Error writing object.");
	ErrorMessages.Insert(27, "BeforeProcessClearingRule event handler error.");
	ErrorMessages.Insert(28, "AfterProcessClearingRule event handler error.");
	ErrorMessages.Insert(29, "BeforeDeleteObject event handler error.");
	
	ErrorMessages.Insert(31, "BeforeProcessExportRule event handler error.");
	ErrorMessages.Insert(32, "AfterProcessExportRule event handler error.");
	ErrorMessages.Insert(33, "BeforeExportObject event handler error.");
	ErrorMessages.Insert(34, "AfterExportObject event handler error.");
	
	ErrorMessages.Insert(41, "BeforeExportObject event handler error.");
	ErrorMessages.Insert(42, "OnExportObject event handler error.");
	ErrorMessages.Insert(43, "AfterExportObject event handler error.");
	
	ErrorMessages.Insert(45, "No conversion rule is found.");
	
	ErrorMessages.Insert(48, "BeforeProcessExport property group event handler error.");
	ErrorMessages.Insert(49, "AfterProcessExport property group event handler error.");
	ErrorMessages.Insert(50, "BeforeExport event handler error (collection object).");
	ErrorMessages.Insert(51, "OnExport event handler error (collection object).");
	ErrorMessages.Insert(52, "AfterExport event handler error (collection object).");
	ErrorMessages.Insert(53, "BeforeImportObject global event handler error (data conversion).");
	ErrorMessages.Insert(54, "AfterImportObject global event handler error (data conversion).");
	ErrorMessages.Insert(55, "BeforeExport event handler error (property).");
	ErrorMessages.Insert(56, "OnExport event handler error (property).");
	ErrorMessages.Insert(57, "AfterExport event handler error (property).");
	
	ErrorMessages.Insert(62, "BeforeDataExport event handler error (data conversion).");
	ErrorMessages.Insert(63, "AfterDataExport event handler error (data conversion).");
	ErrorMessages.Insert(64, "BeforeObjectConversion global event handler error (data conversion).");
	ErrorMessages.Insert(65, "BeforeExportObject global event handler error (data conversion).");
	ErrorMessages.Insert(66, "Error retrieving subordinate object collection from incoming data.");
	ErrorMessages.Insert(67, "Error retrieving subordinate object properties from incoming data.");
	ErrorMessages.Insert(68, "Error retrieving object properties from incoming data.");
	
	ErrorMessages.Insert(69, "AfterExportObject global event handler error (data conversion).");
	
	ErrorMessages.Insert(71, "The map of the Source value is not found.");
	
	ErrorMessages.Insert(72, "Error exporting data for exchange plan node.");
	
	ErrorMessages.Insert(73, "SearchFieldSequence event handler error.");
	
	ErrorMessages.Insert(74, "Exchange rules for data export must be reread.");
	
	ErrorMessages.Insert(75,  NStr("en = 'AfterExchangeRuleImport event handler error (data conversion).'"));
	ErrorMessages.Insert(76,  NStr("en = 'BeforeSendDeletionInfo event handler error (data conversion).'"));
	ErrorMessages.Insert(77,  NStr("en = 'OnGetDeletionInfo event handler error (data conversion).'"));
	
	ErrorMessages.Insert(78,  NStr("en = 'Error executing algorithm after parameter value import.'"));
	
	ErrorMessages.Insert(79,  NStr("en = 'AfterExportObjectToFile event handler error.'"));
	
	ErrorMessages.Insert(80,  NStr("en = 'Error setting predefined item property.
	|A predefined item cannot be marked for deletion. The deletion mark for the object is not set.'"));
	
	ErrorMessages.Insert(83,  NStr("en = 'Error accessing object tabular section. The object tabular section cannot be modified.'"));
	ErrorMessages.Insert(84,  NStr("en = 'Edit prohibition date conflict.'"));
	ErrorMessages.Insert(173, NStr("en = 'Error exchange node lock. Synchronization in progress.'"));
	ErrorMessages.Insert(174,  NStr("en = 'The exchange message was processed previously.'"));
	ErrorMessages.Insert(175,  NStr("en = 'BeforeGetChangedObjects event handler error (data conversion).'"));
	ErrorMessages.Insert(176,  NStr("en = 'AfterReceiveExchangeNodeDetails event handler error (data conversion).'"));
	
	ErrorMessages.Insert(1000,  NStr("en = 'Error creating temporary data export file.'"));
	
EndProcedure
Procedure SupplementManagerArrayWithReferenceType(Managers, ManagersForExchangePlans, MDObject, TypeName, Manager, TypeNamePrefix, SearchByPredefinedPossible = False)
	
	Name                  = MDObject.Name;
	RefTypeString   	  = TypeNamePrefix + "." + Name;
	SearchString          = "SELECT Ref FROM " + TypeName + "." + Name + " WHERE ";
	RefExportSearchString = "SELECT #SearchFields# FROM " + TypeName + "." + Name;
	RefType         	  = Type(RefTypeString);
	Structure             = New Structure("Name,TypeName,RefTypeString,Manager,MDObject,SearchString,RefExportSearchString,SearchByPredefinedPossible,OCR", Name, TypeName, RefTypeString, Manager, MDObject, SearchString, RefExportSearchString, SearchByPredefinedPossible);
	Managers.Insert(RefType, Structure);
	
	
	StructureForExchangePlan = New Structure("Name,RefType,IsReferenceType,IsRegister", Name, RefType, True, False);
	ManagersForExchangePlans.Insert(MDObject, StructureForExchangePlan);
	
EndProcedure

Procedure SupplementManagerArrayWithRegisterType(Managers, MDObject, TypeName, Manager, TypeNamePrefixRecord, SelectionTypeNamePrefix)
	
	Periodical = Undefined;
	
	Name          = MDObject.Name;
	RefTypeString = TypeNamePrefixRecord + "." + Name;
	RefType       = Type(RefTypeString);
	Structure     = New Structure("Name,TypeName,RefTypeString,Manager,MDObject,SearchByPredefinedPossible,OCR", Name, TypeName, RefTypeString, Manager, MDObject, False);
	
	If TypeName = "InformationRegister" Then
		
		Periodical = (MDObject.InformationRegisterPeriodicity <> Metadata.ObjectProperties.InformationRegisterPeriodicity.Nonperiodical);
		SubordinatedToRecorder = (MDObject.WriteMode = Metadata.ObjectProperties.RegisterWriteMode.RecorderSubordinate);
		
		Structure.Insert("Periodical", Periodical);
		Structure.Insert("SubordinatedToRecorder", SubordinatedToRecorder);
		
	EndIf; 
	
	Managers.Insert(RefType, Structure);
	
	
	StructureForExchangePlan = New Structure("Name,RefType,IsReferenceType,IsRegister", Name, RefType, False, True);
	ManagersForExchangePlans.Insert(MDObject, StructureForExchangePlan);
	
	
	RefTypeString = SelectionTypeNamePrefix + "." + Name;
	RefType       = Type(RefTypeString);
	Structure 	  = New Structure("Name,TypeName,RefTypeString,Manager,MDObject,SearchByPredefinedPossible,OCR", Name, TypeName, RefTypeString, Manager, MDObject, False);
	
	If Periodical <> Undefined Then
		
		Structure.Insert("Periodical", Periodical);
		Structure.Insert("SubordinatedToRecorder", SubordinatedToRecorder); 
		
	EndIf;
	
	Managers.Insert(RefType, Structure); 
	
EndProcedure

// Initializes the Managers variable, which contains a mapping of object types 
// to their properties. 
// 
Procedure ManagerInitialization()
	
	Managers = New Map;
	
	ManagersForExchangePlans = New Map;
	
	// REFERENCES
	
	For Each MDObject In Metadata.Catalogs Do
		
		SupplementManagerArrayWithReferenceType(Managers, ManagersForExchangePlans, MDObject, "Catalog", Catalogs[MDObject.Name], "CatalogRef", True);
		
	EndDo;
	
	For Each MDObject In Metadata.Documents Do
		
		SupplementManagerArrayWithReferenceType(Managers, ManagersForExchangePlans, MDObject, "Document", Documents[MDObject.Name], "DocumentRef");
		
	EndDo;
	
	For Each MDObject In Metadata.ChartsOfCharacteristicTypes Do
		
		SupplementManagerArrayWithReferenceType(Managers, ManagersForExchangePlans, MDObject, "ChartOfCharacteristicTypes", ChartsOfCharacteristicTypes[MDObject.Name], "ChartOfCharacteristicTypesRef", True);
		
	EndDo;
	
	For Each MDObject In Metadata.ChartsOfAccounts Do
		
		SupplementManagerArrayWithReferenceType(Managers, ManagersForExchangePlans, MDObject, "ChartOfAccounts", ChartsOfAccounts[MDObject.Name], "ChartOfAccountsRef", True);
		
	EndDo;
	
	For Each MDObject In Metadata.ChartsOfCalculationTypes Do
		
		SupplementManagerArrayWithReferenceType(Managers, ManagersForExchangePlans, MDObject, "ChartOfCalculationTypes", ChartsOfCalculationTypes[MDObject.Name], "ChartOfCalculationTypesRef", True);
		
	EndDo;
	
	For Each MDObject In Metadata.ExchangePlans Do
		
		SupplementManagerArrayWithReferenceType(Managers, ManagersForExchangePlans, MDObject, "ExchangePlan", ExchangePlans[MDObject.Name], "ExchangePlanRef");
		
	EndDo;
	
	For Each MDObject In Metadata.Tasks Do
		
		SupplementManagerArrayWithReferenceType(Managers, ManagersForExchangePlans, MDObject, "Task", Tasks[MDObject.Name], "TaskRef");
		
	EndDo;
	
	For Each MDObject In Metadata.BusinessProcesses Do
		
		SupplementManagerArrayWithReferenceType(Managers, ManagersForExchangePlans, MDObject, "BusinessProcess", BusinessProcesses[MDObject.Name], "BusinessProcessRef");
		
		TypeName = "BusinessProcessRoutePoint";
		// Route point references
		Name          = MDObject.Name;
		Manager       = BusinessProcesses[Name].RoutePoints;
		SearchString  = "";
		RefTypeString = "BusinessProcessRoutePointRef." + Name;
		RefType       = Type(RefTypeString);
		Structure     = New Structure("Name,TypeName,RefTypeString,Manager,MDObject,OCR,EmptyRef,SearchByPredefinedPossible,SearchString", Name, 
		TypeName, RefTypeString, Manager, MDObject, , Undefined, False, SearchString);  
		Managers.Insert(RefType, Structure);
		
	EndDo;
	
	// REGISTERS
	
	For Each MDObject In Metadata.InformationRegisters Do
		
		SupplementManagerArrayWithRegisterType(Managers, MDObject, "InformationRegister", InformationRegisters[MDObject.Name], "InformationRegisterRecord", "InformationRegisterSelection");
		
	EndDo;
	
	For Each MDObject In Metadata.AccountingRegisters Do
		
		SupplementManagerArrayWithRegisterType(Managers, MDObject, "AccountingRegister", AccountingRegisters[MDObject.Name], "AccountingRegisterRecord", "AccountingRegisterSelection");
		
	EndDo;
	
	For Each MDObject In Metadata.AccumulationRegisters Do
		
		SupplementManagerArrayWithRegisterType(Managers, MDObject, "AccumulationRegister", AccumulationRegisters[MDObject.Name], "AccumulationRegisterRecord", "AccumulationRegisterSelection");
		
	EndDo;
	
	For Each MDObject In Metadata.CalculationRegisters Do
		
		SupplementManagerArrayWithRegisterType(Managers, MDObject, "CalculationRegister", CalculationRegisters[MDObject.Name], "CalculationRegisterRecord", "CalculationRegisterSelection");
		
	EndDo;
	
	TypeName = "Enum";
	
	For Each MDObject In Metadata.Enums Do
		
		Name          = MDObject.Name;
		Manager       = Enums[Name];
		RefTypeString = "EnumRef." + Name;
		RefType       = Type(RefTypeString);
		Structure 	  = New Structure("Name,TypeName,RefTypeString,Manager,MDObject,OCR,EmptyRef,SearchByPredefinedPossible", Name, TypeName, RefTypeString, Manager, MDObject, , Enums[Name].EmptyRef(), False);
		Managers.Insert(RefType, Structure);
		
	EndDo;
	
	// Constants
	TypeName      = "Constants";
	MDObject      = Metadata.Constants;
	Name          = "Constants";
	Manager       = Constants;
	RefTypeString = "ConstantsSet";
	RefType       = Type(RefTypeString);
	Structure     = New Structure("Name,TypeName,RefTypeString,Manager,MDObject,SearchByPredefinedPossible,OCR", Name, TypeName, RefTypeString, Manager, MDObject, False);
	Managers.Insert(RefType, Structure);
	
EndProcedure

Procedure InitManagersAndMessages()
	
	If Managers = Undefined Then
		ManagerInitialization();
	EndIf; 
	
	If ErrorMessages = Undefined Then
		InitMessages();
	EndIf;
	
EndProcedure

Procedure CreateConversionStructure()
	
	Conversion  = New Structure("BeforeDataExport, AfterDataExport, BeforeGetChangedObjects, AfterReceiveExchangeNodeDetails, BeforeExportObject, AfterExportObject, BeforeObjectConversion, BeforeImportObject, AfterImportObject, BeforeDataImport, AfterDataImport, OnGetDeletionInfo, BeforeSendDeletionInfo");
	Conversion.Insert("DeleteMappedObjectsFromTargetOnDeleteFromSource", False);
	Conversion.Insert("CompatibilityMode", "");
	Conversion.Insert("FormatVersion");
	Conversion.Insert("CreationDateTime");
	
EndProcedure

// Initializes data processor attributes and module variables.
// 
Procedure InitAttributesAndModuleVariables()
	
	VisualExchangeSetupMode = False;
	ProcessedObjectNumberToUpdateStatus = 100;
	
	StoredExportedObjectCountByTypes = 2000;
	
	ParametersInitialized = False;
	
	PerformAdditionalWriteToXMLControl = False;
	
	Managers    = Undefined;
	ErrorMessages  = Undefined;
	
	SetErrorFlag(False);
	
	CreateConversionStructure();
	
	Rules                    = New Structure;
	Algorithms               = New Structure;
	AdditionalDataProcessors = New Structure;
	Queries                  = New Structure;
	
	Parameters                 = New Structure;
	EventsAfterParameterImport = New Structure;
	
	AdditionalDataProcessorParameters = New Structure;
	
	XMLRules  = Undefined;
	
	// Types
	
	StringType                 = Type("String");
	BooleanType                = Type("Boolean");
	NumberType                 = Type("Number");
	DateType                   = Type("Date");
	ValueStorageType           = Type("ValueStorage");
	UUIDType                   = Type("UUID");
	BinaryDataType             = Type("BinaryData");
	AccumulationRecordTypeType = Type("AccumulationRecordType");
	ObjectDeletionType         = Type("ObjectDeletion");
	AccountTypeType            = Type("AccountType");
	TypeType                   = Type("Type");
	MapType                    = Type("Map");
	
	String36Type  = New TypeDescription("String",, New StringQualifiers(36));
	String255Type = New TypeDescription("String",, New StringQualifiers(255));
	
	MapRegisterType = Type("InformationRegisterRecordSet.InfobaseObjectMappings");
	
	EmptyDateValue = Date('00010101');
	
	// XML node types
	
	XMLNodeTypeEndElement   = XMLNodeType.EndElement;
	XMLNodeTypeStartElement = XMLNodeType.StartElement;
	XMLNodeTypeText         = XMLNodeType.Text;
	
	DataLogFile = Undefined;
	
	TypeAndObjectNameMap = New Map();
	
	EmptyTypeValueMap = New Map;
	TypeDescriptionMap = New Map;
	
	EnableDocumentPosting = Metadata.ObjectProperties.Posting.Allow;
	
	ExchangeRuleInfoImportMode = False;
	
	ExchangeResultField = Undefined;
	
	CustomSearchFieldInfoOnDataExport = New Map();
	CustomSearchFieldInfoOnDataImport = New Map();
	
	ObjectMappingRegisterManager = InformationRegisters.InfobaseObjectMappings;
	
	// The following query is used to determine mapping data that is used to substitute 
	// the target reference for the source reference.
	InfobaseObjectMappingQuery = New Query;
	InfobaseObjectMappingQuery.Text = "
	|SELECT TOP 1
	| InfobaseObjectMappings.SourceUUIDString AS SourceUUIDString
	|FROM
	| InformationRegister.InfobaseObjectMappings AS InfobaseObjectMappings
	|WHERE
	|   InfobaseObjectMappings.InfobaseNode = &InfobaseNode
	| AND InfobaseObjectMappings.TargetUUID = &TargetUUID
	| AND InfobaseObjectMappings.TargetType = &TargetType
	| AND InfobaseObjectMappings.SourceType = &SourceType
	|";
	
	
EndProcedure

Procedure SetErrorFlag(Value = True)
	
	ErrorFlagField = Value;
	
EndProcedure

Procedure Increment(Value, Val Iterator = 1)
	
	If TypeOf(Value) <> Type("Number") Then
		
		Value = 0;
		
	EndIf;
	
	Value = Value + Iterator;
	
EndProcedure

Procedure WriteDataImportEnd()
	
	DataExchangeState().ExchangeExecutionResult = ExchangeExecutionResult();
	DataExchangeState().ActionOnExchange        = Enums.ActionsOnExchange.DataImport;
	DataExchangeState().InfobaseNode            = ExchangeNodeDataImport;
	
	InformationRegisters.DataExchangeStates.AddRecord(DataExchangeState());
	
	// Writing the successful exchange execution message to the formation register
	If ExchangeExecutionResult() = Enums.ExchangeExecutionResults.Completed Then
		
		// Creating and filling a structure for the new information register record
		RecordStructure = New Structure("InfobaseNode, ActionOnExchange, EndDate");
		FillPropertyValues(RecordStructure, DataExchangeState());
		
		InformationRegisters.SuccessfulDataExchangeStates.AddRecord(RecordStructure);
		
	EndIf;
	
EndProcedure

Procedure IncreaseExportedObjectCounter()
	
	Increment(ExportedObjectCounterField);
	
EndProcedure

Procedure IncreaseImportedObjectCounter()
	
	Increment(ImportedObjectCounterField);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE HANDLERS


Function PCRPropertyName(TabularSectionRow)
	
	If ValueIsFilled(TabularSectionRow.Source) Then
		Property = "_" + TrimAll(TabularSectionRow.Source);
	ElsIf ValueIsFilled(TabularSectionRow.Target) Then 
		Property = "_" + TrimAll(TabularSectionRow.Target);
	ElsIf ValueIsFilled(TabularSectionRow.ParameterForTransferName) Then
		Property = "_" + TrimAll(TabularSectionRow.ParameterForTransferName);
	Else
		Property = "";
	EndIf;
	
	Return Property;
	
EndFunction

// Returns compatibility mode flag.
//
Function SL20CompatibilityMode()
	
	If SL20CompatibilityModeField = Undefined Then
		
		IsSaaS = CommonUseCached.DataSeparationEnabled();
		
		SL20CompatibilityModeField = (Conversion.CompatibilityMode = ""
		Or Conversion.CompatibilityMode = "SL20CompatibilityMode")
		And Not IsSaaS;
		
	EndIf;
	
	Return SL20CompatibilityModeField;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Global handlers

Procedure ExecuteHandler_Conversion_AfterExchangeRuleImport()
	
	SafeMode.ExecuteObjectMethod(
	ExportDataProcessor, Conversion.AfterExchangeRuleImportHandlerName);
	
EndProcedure

Procedure ExecuteHandler_Conversion_BeforeDataExport(ExchangeFile, Cancel)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(ExchangeFile);
	HandlerParameters.Add(Cancel);
	
	SafeMode.ExecuteObjectMethod(
	ExportDataProcessor, Conversion.BeforeDataExportHandlerName, HandlerParameters);
	
	ExchangeFile = HandlerParameters[0];
	
	Cancel = HandlerParameters[1];
	
EndProcedure

Procedure ExecuteHandler_Conversion_BeforeGetChangedObjects(Recipient, BackgroundExchangeNode)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(Recipient);
	HandlerParameters.Add(BackgroundExchangeNode);
	
	SafeMode.ExecuteObjectMethod(
	ExportDataProcessor, Conversion.BeforeGetChangedObjectsHandlerName, HandlerParameters);
	
	Recipient = HandlerParameters[0];
	BackgroundExchangeNode = HandlerParameters[1];
	
EndProcedure

Procedure ExecuteHandler_Conversion_AfterDataExport(ExchangeFile)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(ExchangeFile);
	
	SafeMode.ExecuteObjectMethod(
	ExportDataProcessor, Conversion.AfterDataExportHandlerName, HandlerParameters);
	
	ExchangeFile = HandlerParameters[0];
	
EndProcedure

Procedure ExecuteHandler_Conversion_BeforeExportObject(ExchangeFile, Cancel, OCRName, Rule,
	IncomingData, OutgoingData, Object)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(ExchangeFile);
	HandlerParameters.Add(Cancel);
	HandlerParameters.Add(OCRName);
	HandlerParameters.Add(Rule);
	HandlerParameters.Add(IncomingData);
	HandlerParameters.Add(OutgoingData);
	HandlerParameters.Add(Object);
	
	SafeMode.ExecuteObjectMethod(
	ExportDataProcessor, Conversion.BeforeObjectExportHandlerName, HandlerParameters);
	
	ExchangeFile = HandlerParameters[0];
	Cancel = HandlerParameters[1];
	OCRName = HandlerParameters[2];
	Rule = HandlerParameters[3];
	IncomingData = HandlerParameters[4];
	OutgoingData = HandlerParameters[5];
	Object = HandlerParameters[6];
	
EndProcedure

Procedure ExecuteHandler_Conversion_AfterExportObject(ExchangeFile, Object, OCRName, IncomingData,
	OutgoingData, RefNode)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(ExchangeFile);
	HandlerParameters.Add(Object);
	HandlerParameters.Add(OCRName);
	HandlerParameters.Add(IncomingData);
	HandlerParameters.Add(OutgoingData);
	HandlerParameters.Add(RefNode);
	
	SafeMode.ExecuteObjectMethod(
	ExportDataProcessor, Conversion.AfterObjectExportHandlerName, HandlerParameters);
	
	ExchangeFile = HandlerParameters[0];
	Object = HandlerParameters[1];
	OCRName = HandlerParameters[2];
	IncomingData = HandlerParameters[3];
	OutgoingData = HandlerParameters[4];
	RefNode = HandlerParameters[5];
	
EndProcedure

Procedure ExecuteHandler_Conversion_BeforeObjectConversion(ExchangeFile, Source, IncomingData, OutgoingData,
	OCRName, OCR, ExportedObjects, Cancel, ExportedDataKey,
	RememberExported, DontReplaceObjectOnImport,
	AllObjectsExported,GetRefNodeOnly, Target,
	WriteMode, PostingMode, DontCreateIfNotFound)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(ExchangeFile);
	HandlerParameters.Add(Source);
	HandlerParameters.Add(IncomingData);
	HandlerParameters.Add(OutgoingData);
	HandlerParameters.Add(OCRName);
	HandlerParameters.Add(OCR);
	HandlerParameters.Add(ExportedObjects);
	HandlerParameters.Add(Cancel);
	HandlerParameters.Add(ExportedDataKey);
	HandlerParameters.Add(RememberExported);
	HandlerParameters.Add(DontReplaceObjectOnImport);
	HandlerParameters.Add(AllObjectsExported);
	HandlerParameters.Add(GetRefNodeOnly);
	HandlerParameters.Add(Target);
	HandlerParameters.Add(WriteMode);
	HandlerParameters.Add(PostingMode);
	HandlerParameters.Add(DontCreateIfNotFound);
	
	SafeMode.ExecuteObjectMethod(
	ExportDataProcessor, Conversion.BeforeObjectConversionHandlerName, HandlerParameters);
	
	ExchangeFile = HandlerParameters[0];
	Source = HandlerParameters[1];
	IncomingData = HandlerParameters[2];
	OutgoingData = HandlerParameters[3];
	OCRName = HandlerParameters[4];
	OCR = HandlerParameters[5];
	ExportedObjects = HandlerParameters[6];
	Cancel = HandlerParameters[7];
	ExportedDataKey = HandlerParameters[8];
	RememberExported = HandlerParameters[9];
	DontReplaceObjectOnImport = HandlerParameters[10];
	AllObjectsExported = HandlerParameters[11];
	GetRefNodeOnly = HandlerParameters[12];
	Target = HandlerParameters[13];
	WriteMode = HandlerParameters[14];
	PostingMode = HandlerParameters[15];
	DontCreateIfNotFound = HandlerParameters[16];
	
EndProcedure

Procedure ExecuteHandler_Conversion_BeforeSendDeletionInfo(Ref, Cancel)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(Ref);
	HandlerParameters.Add(Cancel);
	
	SafeMode.ExecuteObjectMethod(
	ExportDataProcessor, Conversion.BeforeSendDeletionInfoHandlerName, HandlerParameters);
	
	Ref = HandlerParameters[0];
	Cancel = HandlerParameters[1];
	
EndProcedure

Procedure ExecuteHandler_Conversion_BeforeDataImport(ExchangeFile, Cancel)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(ExchangeFile);
	HandlerParameters.Add(Cancel);
	
	SafeMode.ExecuteObjectMethod(
	LoadProcessing, Conversion.BeforeDataImportHandlerName, HandlerParameters);
	
	ExchangeFile = HandlerParameters[0];
	Cancel = HandlerParameters[1];
	
EndProcedure

Procedure ExecuteHandler_Conversion_AfterDataImport()
	
	SafeMode.ExecuteObjectMethod(
	LoadProcessing, Conversion.AfterDataImportHandlerName);
	
EndProcedure

Procedure ExecuteHandler_Conversion_BeforeImportObject(ExchangeFile, Cancel, Sn, Source, RuleName, Rule,
	GenerateNewNumberOrCodeIfNotSet,ObjectTypeString,
	ObjectType, DontReplaceObject, WriteMode, PostingMode)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(ExchangeFile);
	HandlerParameters.Add(Cancel);
	HandlerParameters.Add(Sn);
	HandlerParameters.Add(Source);
	HandlerParameters.Add(RuleName);
	HandlerParameters.Add(Rule);
	HandlerParameters.Add(GenerateNewNumberOrCodeIfNotSet);
	HandlerParameters.Add(ObjectTypeString);
	HandlerParameters.Add(ObjectType);
	HandlerParameters.Add(DontReplaceObject);
	HandlerParameters.Add(WriteMode);
	HandlerParameters.Add(PostingMode);
	
	SafeMode.ExecuteObjectMethod(
	LoadProcessing, Conversion.BeforeObjectImportHandlerName, HandlerParameters);
	
	ExchangeFile = HandlerParameters[0];
	Cancel = HandlerParameters[1];
	Sn = HandlerParameters[2];
	Source = HandlerParameters[3];
	RuleName = HandlerParameters[4];
	Rule = HandlerParameters[5];
	GenerateNewNumberOrCodeIfNotSet = HandlerParameters[6];
	ObjectTypeString = HandlerParameters[7];
	ObjectType = HandlerParameters[8];
	DontReplaceObject = HandlerParameters[9];
	WriteMode = HandlerParameters[10];
	PostingMode = HandlerParameters[11];
	
EndProcedure

Procedure ExecuteHandler_Conversion_AfterImportObject(ExchangeFile, Cancel, Ref, Object, ObjectParameters,
	ObjectModified, ObjectTypeName, ObjectFound)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(ExchangeFile);
	HandlerParameters.Add(Cancel);
	HandlerParameters.Add(Ref);
	HandlerParameters.Add(Object);
	HandlerParameters.Add(ObjectParameters);
	HandlerParameters.Add(ObjectModified);
	HandlerParameters.Add(ObjectTypeName);
	HandlerParameters.Add(ObjectFound);
	
	SafeMode.ExecuteObjectMethod(
	LoadProcessing, Conversion.AfterObjectImportHandlerName, HandlerParameters);
	
	ExchangeFile = HandlerParameters[0];
	Cancel = HandlerParameters[1];
	Ref = HandlerParameters[2];
	Object = HandlerParameters[3];
	ObjectParameters = HandlerParameters[4];
	ObjectModified = HandlerParameters[5];
	ObjectTypeName = HandlerParameters[6];
	ObjectFound = HandlerParameters[7];
	
EndProcedure

Procedure ExecuteHandler_Conversion_OnGetDeletionInfo(Object, Cancel)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(Object);
	HandlerParameters.Add(Cancel);
	
	SafeMode.ExecuteObjectMethod(
	LoadProcessing, Conversion.OnGetDeletionInfoHandlerName, HandlerParameters);
	
	Object = HandlerParameters[0];
	Cancel = HandlerParameters[1];
	
EndProcedure

Procedure ExecuteHandler_Conversion_AfterParameterImport(ExchangeFile, Cancel, CancelReason)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(ExchangeFile);
	HandlerParameters.Add(Cancel);
	HandlerParameters.Add(CancelReason);
	
	SafeMode.ExecuteObjectMethod(
	LoadProcessing, "Conversion_AfterParameterImport", HandlerParameters);
	
	ExchangeFile = HandlerParameters[0];
	Cancel = HandlerParameters[1];
	CancelReason = HandlerParameters[2];
	
EndProcedure

Procedure ExecuteHandler_Conversion_AfterReceiveExchangeNodeDetails(Val ExchangeNodeDataImport)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(ExchangeNodeDataImport);
	
	SafeMode.ExecuteObjectMethod(
	LoadProcessing, Conversion.AfterReceiveExchangeNodeDetailsHandlerName, HandlerParameters);
	
	ExchangeNodeDataImport = HandlerParameters[0];
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// OCR handlers

Procedure ExecuteHandler_OCR_BeforeExportObject(ExchangeFile, Source, IncomingData, OutgoingData,
	OCRName, OCR, ExportedObjects, Cancel, ExportedDataKey,
	RememberExported, DontReplaceObjectOnImport,
	AllObjectsExported, GetRefNodeOnly, Target,
	WriteMode, PostingMode, DontCreateIfNotFound)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(ExchangeFile);
	HandlerParameters.Add(Source);
	HandlerParameters.Add(IncomingData);
	HandlerParameters.Add(OutgoingData);
	HandlerParameters.Add(OCRName);
	HandlerParameters.Add(OCR);
	HandlerParameters.Add(ExportedObjects);
	HandlerParameters.Add(Cancel);
	HandlerParameters.Add(ExportedDataKey);
	HandlerParameters.Add(RememberExported);
	HandlerParameters.Add(DontReplaceObjectOnImport);
	HandlerParameters.Add(AllObjectsExported);
	HandlerParameters.Add(GetRefNodeOnly);
	HandlerParameters.Add(Target);
	HandlerParameters.Add(WriteMode);
	HandlerParameters.Add(PostingMode);
	HandlerParameters.Add(DontCreateIfNotFound);
	
	SafeMode.ExecuteObjectMethod(
	ExportDataProcessor, OCR.BeforeExportHandlerName, HandlerParameters);
	
	ExchangeFile = HandlerParameters[0];
	Source = HandlerParameters[1];
	IncomingData = HandlerParameters[2];
	OutgoingData = HandlerParameters[3];
	OCRName = HandlerParameters[4];
	OCR = HandlerParameters[5];
	ExportedObjects = HandlerParameters[6];
	Cancel = HandlerParameters[7];
	ExportedDataKey = HandlerParameters[8];
	RememberExported = HandlerParameters[9];
	DontReplaceObjectOnImport = HandlerParameters[10];
	AllObjectsExported = HandlerParameters[11];
	GetRefNodeOnly = HandlerParameters[12];
	Target = HandlerParameters[13];
	WriteMode = HandlerParameters[14];
	PostingMode = HandlerParameters[15];
	DontCreateIfNotFound = HandlerParameters[16];
	
EndProcedure

Procedure ExecuteHandler_OCR_OnExportObject(ExchangeFile, Source, IncomingData, OutgoingData, OCRName, OCR,
	ExportedObjects, ExportedDataKey, Cancel, StandardProcessing,
	Target, RefNode)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(ExchangeFile);
	HandlerParameters.Add(Source);
	HandlerParameters.Add(IncomingData);
	HandlerParameters.Add(OutgoingData);
	HandlerParameters.Add(OCRName);
	HandlerParameters.Add(OCR);
	HandlerParameters.Add(ExportedObjects);
	HandlerParameters.Add(ExportedDataKey);
	HandlerParameters.Add(Cancel);
	HandlerParameters.Add(StandardProcessing);
	HandlerParameters.Add(Target);
	HandlerParameters.Add(RefNode);
	
	SafeMode.ExecuteObjectMethod(
	ExportDataProcessor, OCR.OnExportHandlerName, HandlerParameters);
	
	ExchangeFile 		= HandlerParameters[0];
	Source 				= HandlerParameters[1];
	IncomingData 		= HandlerParameters[2];
	OutgoingData 		= HandlerParameters[3];
	OCRName 			= HandlerParameters[4];
	OCR 				= HandlerParameters[5];
	ExportedObjects 	= HandlerParameters[6];
	ExportedDataKey 	= HandlerParameters[7];
	Cancel 				= HandlerParameters[8];
	StandardProcessing 	= HandlerParameters[9];
	Target 				= HandlerParameters[10];
	RefNode 			= HandlerParameters[11];
	
EndProcedure

Procedure ExecuteHandler_OCR_AfterExportObject(ExchangeFile, Source, IncomingData, OutgoingData, OCRName, OCR,
	ExportedObjects, ExportedDataKey, Cancel, Target, RefNode)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(ExchangeFile);
	HandlerParameters.Add(Source);
	HandlerParameters.Add(IncomingData);
	HandlerParameters.Add(OutgoingData);
	HandlerParameters.Add(OCRName);
	HandlerParameters.Add(OCR);
	HandlerParameters.Add(ExportedObjects);
	HandlerParameters.Add(ExportedDataKey);
	HandlerParameters.Add(Cancel);
	HandlerParameters.Add(Target);
	HandlerParameters.Add(RefNode);
	
	SafeMode.ExecuteObjectMethod(
	ExportDataProcessor, OCR.AfterExportHandlerName, HandlerParameters);
	
	ExchangeFile 		= HandlerParameters[0];
	Source 				= HandlerParameters[1];
	IncomingData 		= HandlerParameters[2];
	OutgoingData 		= HandlerParameters[3];
	OCRName 			= HandlerParameters[4];
	OCR 				= HandlerParameters[5];
	ExportedObjects 	= HandlerParameters[6];
	ExportedDataKey 	= HandlerParameters[7];
	Cancel 				= HandlerParameters[8];
	Target 				= HandlerParameters[9];
	RefNode 			= HandlerParameters[10];
	
EndProcedure

Procedure ExecuteHandler_OCR_AfterExportObjectToExchangeFile(ExchangeFile, Source, IncomingData, OutgoingData, OCRName, OCR,
	ExportedObjects, Target, RefNode)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(ExchangeFile);
	HandlerParameters.Add(Source);
	HandlerParameters.Add(IncomingData);
	HandlerParameters.Add(OutgoingData);
	HandlerParameters.Add(OCRName);
	HandlerParameters.Add(OCR);
	HandlerParameters.Add(ExportedObjects);
	HandlerParameters.Add(Target);
	HandlerParameters.Add(RefNode);
	
	SafeMode.ExecuteObjectMethod(
	ExportDataProcessor, OCR.AfterExportToFileHandlerName, HandlerParameters);
	
	ExchangeFile 		= HandlerParameters[0];
	Source 				= HandlerParameters[1];
	IncomingData 		= HandlerParameters[2];
	OutgoingData 		= HandlerParameters[3];
	OCRName 			= HandlerParameters[4];
	OCR 				= HandlerParameters[5];
	ExportedObjects 	= HandlerParameters[6];
	Target 				= HandlerParameters[7];
	RefNode 			= HandlerParameters[8];
	
EndProcedure

Procedure ExecuteHandler_OCR_BeforeImportObject(ExchangeFile, Cancel, Sn, Source, RuleName, Rule,
	GenerateNewNumberOrCodeIfNotSet, ObjectTypeString,
	ObjectType,DontReplaceObject, WriteMode, PostingMode)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(ExchangeFile);
	HandlerParameters.Add(Cancel);
	HandlerParameters.Add(Sn);
	HandlerParameters.Add(Source);
	HandlerParameters.Add(RuleName);
	HandlerParameters.Add(Rule);
	HandlerParameters.Add(GenerateNewNumberOrCodeIfNotSet);
	HandlerParameters.Add(ObjectTypeString);
	HandlerParameters.Add(ObjectType);
	HandlerParameters.Add(DontReplaceObject);
	HandlerParameters.Add(WriteMode);
	HandlerParameters.Add(PostingMode);
	
	SafeMode.ExecuteObjectMethod(
	LoadProcessing, Rule.BeforeImportHandlerName, HandlerParameters);
	
	ExchangeFile 		= HandlerParameters[0];
	Cancel 				= HandlerParameters[1];
	Sn 					= HandlerParameters[2];
	Source 				= HandlerParameters[3];
	RuleName 			= HandlerParameters[4];
	Rule 				= HandlerParameters[5];
	GenerateNewNumberOrCodeIfNotSet = HandlerParameters[6];
	ObjectTypeString 	= HandlerParameters[7];
	ObjectType 			= HandlerParameters[8];
	DontReplaceObject 	= HandlerParameters[9];
	WriteMode 			= HandlerParameters[10];
	PostingMode 		= HandlerParameters[11];
	
EndProcedure

Procedure ExecuteHandler_OCR_OnImportObject(ExchangeFile, ObjectFound, Object, DontReplaceObject, ObjectModified, Rule)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(ExchangeFile);
	HandlerParameters.Add(ObjectFound);
	HandlerParameters.Add(Object);
	HandlerParameters.Add(DontReplaceObject);
	HandlerParameters.Add(ObjectModified);
	
	SafeMode.ExecuteObjectMethod(
	LoadProcessing, Rule.OnImportHandlerName, HandlerParameters);
	
	ExchangeFile 		= HandlerParameters[0];
	ObjectFound 		= HandlerParameters[1];
	Object 				= HandlerParameters[2];
	DontReplaceObject 	= HandlerParameters[3];
	ObjectModified 		= HandlerParameters[4];
	
EndProcedure

Procedure ExecuteHandler_OCR_AfterImportObject(ExchangeFile, Cancel, Ref, Object, ObjectParameters,
	ObjectModified, ObjectTypeName, ObjectFound, Rule)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(ExchangeFile);
	HandlerParameters.Add(Cancel);
	HandlerParameters.Add(Ref);
	HandlerParameters.Add(Object);
	HandlerParameters.Add(ObjectParameters);
	HandlerParameters.Add(ObjectModified);
	HandlerParameters.Add(ObjectTypeName);
	HandlerParameters.Add(ObjectFound);
	
	SafeMode.ExecuteObjectMethod(
	LoadProcessing, Rule.AfterImportHandlerName, HandlerParameters);
	
	ExchangeFile 		= HandlerParameters[0];
	Cancel 				= HandlerParameters[1];
	Ref 				= HandlerParameters[2];
	Object 				= HandlerParameters[3];
	ObjectParameters 	= HandlerParameters[4];
	ObjectModified 		= HandlerParameters[5];
	ObjectTypeName 		= HandlerParameters[6];
	ObjectFound 		= HandlerParameters[7];
	
EndProcedure

Procedure ExecuteHandler_OCR_SearchFieldSequence(SearchVariantNumber, SearchProperties, ObjectParameters, StopSearch,
	ObjectRef, SetAllObjectSearchProperties,
	SearchPropertyNameString, HandlerName)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(SearchVariantNumber);
	HandlerParameters.Add(SearchProperties);
	HandlerParameters.Add(ObjectParameters);
	HandlerParameters.Add(StopSearch);
	HandlerParameters.Add(ObjectRef);
	HandlerParameters.Add(SetAllObjectSearchProperties);
	HandlerParameters.Add(SearchPropertyNameString);
	
	SafeMode.ExecuteObjectMethod(
	LoadProcessing, HandlerName, HandlerParameters);
	
	SearchVariantNumber = HandlerParameters[0];
	SearchProperties 	= HandlerParameters[1];
	ObjectParameters 	= HandlerParameters[2];
	StopSearch 			= HandlerParameters[3];
	ObjectRef 			= HandlerParameters[4];
	SetAllObjectSearchProperties = HandlerParameters[5];
	SearchPropertyNameString 	 = HandlerParameters[6];
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PCR handlers

Procedure ExecuteHandler_PCR_BeforeExportProperty(ExchangeFile, Source, Target, IncomingData, OutgoingData,
	PCR, OCR, CollectionObject, Cancel, Value, TargetType, OCRName,
	ExtDimensionTypeOCRName, Empty, Expression, PropertyCollectionNode, DontReplace,
	ExportObject)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(ExchangeFile);
	HandlerParameters.Add(Source);
	HandlerParameters.Add(Target);
	HandlerParameters.Add(IncomingData);
	HandlerParameters.Add(OutgoingData);
	HandlerParameters.Add(PCR);
	HandlerParameters.Add(OCR);
	HandlerParameters.Add(CollectionObject);
	HandlerParameters.Add(Cancel);
	HandlerParameters.Add(Value);
	HandlerParameters.Add(TargetType);
	HandlerParameters.Add(OCRName);
	HandlerParameters.Add(ExtDimensionTypeOCRName);
	HandlerParameters.Add(Empty);
	HandlerParameters.Add(Expression);
	HandlerParameters.Add(PropertyCollectionNode);
	HandlerParameters.Add(DontReplace);
	HandlerParameters.Add(ExportObject);
	
	SafeMode.ExecuteObjectMethod(
	ExportDataProcessor, PCR.BeforeExportHandlerName, HandlerParameters);
	
	ExchangeFile 		= HandlerParameters[0];
	Source 				= HandlerParameters[1];
	Target 				= HandlerParameters[2];
	IncomingData 		= HandlerParameters[3];
	OutgoingData 		= HandlerParameters[4];
	PCR 				= HandlerParameters[5];
	OCR 				= HandlerParameters[6];
	CollectionObject 	= HandlerParameters[7];
	Cancel 				= HandlerParameters[8];
	Value 				= HandlerParameters[9];
	TargetType 			= HandlerParameters[10];
	OCRName 			= HandlerParameters[11];
	ExtDimensionTypeOCRName = HandlerParameters[12];
	Empty 				= HandlerParameters[13];
	Expression 			= HandlerParameters[14];
	PropertyCollectionNode = HandlerParameters[15];
	DontReplace 		= HandlerParameters[16];
	ExportObject 		= HandlerParameters[17];
	
EndProcedure

Procedure ExecuteHandler_PCR_OnExportProperty(ExchangeFile, Source, Target, IncomingData, OutgoingData,
	PCR, OCR, CollectionObject, Cancel, Value, KeyAndValue, ExtDimensionType,
	ExtDimensions, Empty, OCRName, PropertyOCR,PropertyNode, PropertyCollectionNode,
	ExtDimensionTypeOCRName, ExportObject)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(ExchangeFile);
	HandlerParameters.Add(Source);
	HandlerParameters.Add(Target);
	HandlerParameters.Add(IncomingData);
	HandlerParameters.Add(OutgoingData);
	HandlerParameters.Add(PCR);
	HandlerParameters.Add(OCR);
	HandlerParameters.Add(CollectionObject);
	HandlerParameters.Add(Cancel);
	HandlerParameters.Add(Value);
	HandlerParameters.Add(KeyAndValue);
	HandlerParameters.Add(ExtDimensionType);
	HandlerParameters.Add(ExtDimensions);
	HandlerParameters.Add(Empty);
	HandlerParameters.Add(OCRName);
	HandlerParameters.Add(PropertyOCR);
	HandlerParameters.Add(PropertyNode);
	HandlerParameters.Add(PropertyCollectionNode);
	HandlerParameters.Add(ExtDimensionTypeOCRName);
	HandlerParameters.Add(ExportObject);
	
	SafeMode.ExecuteObjectMethod(
	ExportDataProcessor, PCR.OnExportHandlerName, HandlerParameters);
	
	ExchangeFile 		= HandlerParameters[0];
	Source 				= HandlerParameters[1];
	Target 				= HandlerParameters[2];
	IncomingData 		= HandlerParameters[3];
	OutgoingData 		= HandlerParameters[4];
	PCR 				= HandlerParameters[5];
	OCR 				= HandlerParameters[6];
	CollectionObject 	= HandlerParameters[7];
	Cancel 				= HandlerParameters[8];
	Value 				= HandlerParameters[9];
	KeyAndValue 		= HandlerParameters[10];
	ExtDimensionType 	= HandlerParameters[11];
	ExtDimensions 		= HandlerParameters[12];
	Empty 				= HandlerParameters[13];
	OCRName 			= HandlerParameters[14];
	PropertyOCR 		= HandlerParameters[15];
	PropertyNode 		= HandlerParameters[16];
	PropertyCollectionNode  = HandlerParameters[17];
	ExtDimensionTypeOCRName = HandlerParameters[18];
	ExportObject 		= HandlerParameters[19];
	
EndProcedure

Procedure ExecuteHandler_PCR_AfterExportProperty(ExchangeFile, Source, Target, IncomingData, OutgoingData,
	PCR, OCR, CollectionObject, Cancel, Value, KeyAndValue, ExtDimensionType,
	ExtDimensions, OCRName, ExtDimensionTypeOCRName, PropertyOCR, PropertyNode,
	RefNode, PropertyCollectionNode, ExtDimensionNode)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(ExchangeFile);
	HandlerParameters.Add(Source);
	HandlerParameters.Add(Target);
	HandlerParameters.Add(IncomingData);
	HandlerParameters.Add(OutgoingData);
	HandlerParameters.Add(PCR);
	HandlerParameters.Add(OCR);
	HandlerParameters.Add(CollectionObject);
	HandlerParameters.Add(Cancel);
	HandlerParameters.Add(Value);
	HandlerParameters.Add(KeyAndValue);
	HandlerParameters.Add(ExtDimensionType);
	HandlerParameters.Add(ExtDimensions);
	HandlerParameters.Add(OCRName);
	HandlerParameters.Add(ExtDimensionTypeOCRName);
	HandlerParameters.Add(PropertyOCR);
	HandlerParameters.Add(PropertyNode);
	HandlerParameters.Add(RefNode);
	HandlerParameters.Add(PropertyCollectionNode);
	HandlerParameters.Add(ExtDimensionNode);
	
	SafeMode.ExecuteObjectMethod(
	ExportDataProcessor, PCR.AfterExportHandlerName, HandlerParameters);
	
	ExchangeFile 		= HandlerParameters[0];
	Source 				= HandlerParameters[1];
	Target 				= HandlerParameters[2];
	IncomingData 		= HandlerParameters[3];
	OutgoingData 		= HandlerParameters[4];
	PCR 				= HandlerParameters[5];
	OCR 				= HandlerParameters[6];
	CollectionObject 	= HandlerParameters[7];
	Cancel 				= HandlerParameters[8];
	Value 				= HandlerParameters[9];
	KeyAndValue 		= HandlerParameters[10];
	ExtDimensionType 	= HandlerParameters[11];
	ExtDimensions 		= HandlerParameters[12];
	OCRName 			= HandlerParameters[13];
	ExtDimensionTypeOCRName = HandlerParameters[14];
	PropertyOCR 		= HandlerParameters[15];
	PropertyNode 		= HandlerParameters[16];
	RefNode 			= HandlerParameters[17];
	PropertyCollectionNode = HandlerParameters[18];
	ExtDimensionNode 	= HandlerParameters[19];
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PGCR handlers

Procedure ExecuteHandler_PGCR_BeforeProcessExport(ExchangeFile, Source, Target, IncomingData, OutgoingData, OCR,
	PGCR, Cancel, ObjectCollection, DontReplace, PropertyCollectionNode, DontClear)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(ExchangeFile);
	HandlerParameters.Add(Source);
	HandlerParameters.Add(Target);
	HandlerParameters.Add(IncomingData);
	HandlerParameters.Add(OutgoingData);
	HandlerParameters.Add(OCR);
	HandlerParameters.Add(PGCR);
	HandlerParameters.Add(Cancel);
	HandlerParameters.Add(ObjectCollection);
	HandlerParameters.Add(DontReplace);
	HandlerParameters.Add(PropertyCollectionNode);
	HandlerParameters.Add(DontClear);
	
	SafeMode.ExecuteObjectMethod(
	ExportDataProcessor, PGCR.BeforeExportProcessHandlerName, HandlerParameters);
	
	ExchangeFile 		= HandlerParameters[0];
	Source 				= HandlerParameters[1];
	Target 				= HandlerParameters[2];
	IncomingData 		= HandlerParameters[3];
	OutgoingData 		= HandlerParameters[4];
	OCR 				= HandlerParameters[5];
	PGCR 				= HandlerParameters[6];
	Cancel 				= HandlerParameters[7];
	ObjectCollection 	= HandlerParameters[8];
	DontReplace 		= HandlerParameters[9];
	PropertyCollectionNode = HandlerParameters[10];
	DontClear 			= HandlerParameters[11];
	
EndProcedure

Procedure ExecuteHandler_PGCR_BeforeExportProperty(ExchangeFile, Source, Target, IncomingData, OutgoingData, OCR,
	PGCR, Cancel, CollectionObject, PropertyCollectionNode, ObjectCollectionNode)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(ExchangeFile);
	HandlerParameters.Add(Source);
	HandlerParameters.Add(Target);
	HandlerParameters.Add(IncomingData);
	HandlerParameters.Add(OutgoingData);
	HandlerParameters.Add(OCR);
	HandlerParameters.Add(PGCR);
	HandlerParameters.Add(Cancel);
	HandlerParameters.Add(CollectionObject);
	HandlerParameters.Add(PropertyCollectionNode);
	HandlerParameters.Add(ObjectCollectionNode);
	
	SafeMode.ExecuteObjectMethod(
	ExportDataProcessor, PGCR.BeforeExportHandlerName, HandlerParameters);
	
	ExchangeFile 		= HandlerParameters[0];
	Source 				= HandlerParameters[1];
	Target 				= HandlerParameters[2];
	IncomingData 		= HandlerParameters[3];
	OutgoingData 		= HandlerParameters[4];
	OCR 				= HandlerParameters[5];
	PGCR 				= HandlerParameters[6];
	Cancel 				= HandlerParameters[7];
	CollectionObject 	= HandlerParameters[8];
	PropertyCollectionNode = HandlerParameters[9];
	ObjectCollectionNode = HandlerParameters[10];
	
EndProcedure

Procedure ExecuteHandler_PGCR_OnExportProperty(ExchangeFile, Source, Target, IncomingData, OutgoingData, OCR,
	PGCR, CollectionObject, ObjectCollectionNode, CollectionObjectNode,
	PropertyCollectionNode, StandardProcessing)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(ExchangeFile);
	HandlerParameters.Add(Source);
	HandlerParameters.Add(Target);
	HandlerParameters.Add(IncomingData);
	HandlerParameters.Add(OutgoingData);
	HandlerParameters.Add(OCR);
	HandlerParameters.Add(PGCR);
	HandlerParameters.Add(CollectionObject);
	HandlerParameters.Add(ObjectCollectionNode);
	HandlerParameters.Add(CollectionObjectNode);
	HandlerParameters.Add(PropertyCollectionNode);
	HandlerParameters.Add(StandardProcessing);
	
	SafeMode.ExecuteObjectMethod(
	ExportDataProcessor, PGCR.OnExportHandlerName, HandlerParameters);
	
	ExchangeFile 		= HandlerParameters[0];
	Source 				= HandlerParameters[1];
	Target 				= HandlerParameters[2];
	IncomingData 		= HandlerParameters[3];
	OutgoingData 		= HandlerParameters[4];
	OCR 				= HandlerParameters[5];
	PGCR 				= HandlerParameters[6];
	CollectionObject 	= HandlerParameters[7];
	ObjectCollectionNode = HandlerParameters[8];
	CollectionObjectNode = HandlerParameters[9];
	PropertyCollectionNode = HandlerParameters[10];
	StandardProcessing 	= HandlerParameters[11];
	
EndProcedure

Procedure ExecuteHandler_PGCR_AfterExportProperty(ExchangeFile, Source, Target, IncomingData, OutgoingData,
	OCR, PGCR, Cancel, CollectionObject, ObjectCollectionNode,
	PropertyCollectionNode, CollectionObjectNode)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(ExchangeFile);
	HandlerParameters.Add(Source);
	HandlerParameters.Add(Target);
	HandlerParameters.Add(IncomingData);
	HandlerParameters.Add(OutgoingData);
	HandlerParameters.Add(OCR);
	HandlerParameters.Add(PGCR);
	HandlerParameters.Add(Cancel);
	HandlerParameters.Add(CollectionObject);
	HandlerParameters.Add(ObjectCollectionNode);
	HandlerParameters.Add(PropertyCollectionNode);
	HandlerParameters.Add(CollectionObjectNode);
	
	SafeMode.ExecuteObjectMethod(
	ExportDataProcessor, PGCR.AfterExportHandlerName, HandlerParameters);
	
	ExchangeFile 		= HandlerParameters[0];
	Source 				= HandlerParameters[1];
	Target 				= HandlerParameters[2];
	IncomingData 		= HandlerParameters[3];
	OutgoingData 		= HandlerParameters[4];
	OCR 				= HandlerParameters[5];
	PGCR 				= HandlerParameters[6];
	Cancel 				= HandlerParameters[7];
	CollectionObject 	= HandlerParameters[8];
	ObjectCollectionNode = HandlerParameters[9];
	PropertyCollectionNode = HandlerParameters[10];
	CollectionObjectNode = HandlerParameters[11];
	
EndProcedure

Procedure ExecuteHandler_PGCR_AfterProcessExport(ExchangeFile, Source, Target, IncomingData, OutgoingData,
	OCR, PGCR, Cancel, PropertyCollectionNode, ObjectCollectionNode)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(ExchangeFile);
	HandlerParameters.Add(Source);
	HandlerParameters.Add(Target);
	HandlerParameters.Add(IncomingData);
	HandlerParameters.Add(OutgoingData);
	HandlerParameters.Add(OCR);
	HandlerParameters.Add(PGCR);
	HandlerParameters.Add(Cancel);
	HandlerParameters.Add(PropertyCollectionNode);
	HandlerParameters.Add(ObjectCollectionNode);
	
	SafeMode.ExecuteObjectMethod(
	ExportDataProcessor, PGCR.AfterExportProcessHandlerName, HandlerParameters);
	
	ExchangeFile 		= HandlerParameters[0];
	Source 				= HandlerParameters[1];
	Target 				= HandlerParameters[2];
	IncomingData 		= HandlerParameters[3];
	OutgoingData 		= HandlerParameters[4];
	OCR 				= HandlerParameters[5];
	PGCR 				= HandlerParameters[6];
	Cancel 				= HandlerParameters[7];
	PropertyCollectionNode = HandlerParameters[8];
	ObjectCollectionNode = HandlerParameters[9];
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// DER handlers

Procedure ExecuteHandler_DER_BeforeProcessRule(Cancel, OCRName, Rule, OutgoingData, DataSelection)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(Cancel);
	HandlerParameters.Add(OCRName);
	HandlerParameters.Add(Rule);
	HandlerParameters.Add(OutgoingData);
	HandlerParameters.Add(DataSelection);
	
	SafeMode.ExecuteObjectMethod(
	ExportDataProcessor, Rule.BeforeProcessHandlerName, HandlerParameters);
	
	Cancel 			= HandlerParameters[0];
	OCRName 		= HandlerParameters[1];
	Rule 			= HandlerParameters[2];
	OutgoingData 	= HandlerParameters[3];
	DataSelection 	= HandlerParameters[4];
	
EndProcedure

Procedure ExecuteHandler_DER_AfterProcessRule(OCRName, Rule, OutgoingData)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(OCRName);
	HandlerParameters.Add(Rule);
	HandlerParameters.Add(OutgoingData);
	
	SafeMode.ExecuteObjectMethod(
	ExportDataProcessor, Rule.AfterProcessHandlerName, HandlerParameters);
	
	OCRName 	 = HandlerParameters[0];
	Rule 		 = HandlerParameters[1];
	OutgoingData = HandlerParameters[2];
	
EndProcedure

Procedure ExecuteHandler_DER_BeforeExportObject(ExchangeFile, Cancel, OCRName, Rule,
	IncomingData, OutgoingData, Object)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(ExchangeFile);
	HandlerParameters.Add(Cancel);
	HandlerParameters.Add(OCRName);
	HandlerParameters.Add(Rule);
	HandlerParameters.Add(IncomingData);
	HandlerParameters.Add(OutgoingData);
	HandlerParameters.Add(Object);
	
	SafeMode.ExecuteObjectMethod(
	ExportDataProcessor, Rule.BeforeExportHandlerName, HandlerParameters);
	
	ExchangeFile = HandlerParameters[0];
	Cancel 		 = HandlerParameters[1];
	OCRName 	 = HandlerParameters[2];
	Rule 		 = HandlerParameters[3];
	IncomingData = HandlerParameters[4];
	OutgoingData = HandlerParameters[5];
	Object 		 = HandlerParameters[6];
	
EndProcedure

Procedure ExecuteHandler_DER_AfterExportObject(ExchangeFile, Object, OCRName, IncomingData,
	OutgoingData, RefNode, Rule)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(ExchangeFile);
	HandlerParameters.Add(Object);
	HandlerParameters.Add(OCRName);
	HandlerParameters.Add(IncomingData);
	HandlerParameters.Add(OutgoingData);
	HandlerParameters.Add(RefNode);
	
	SafeMode.ExecuteObjectMethod(
	ExportDataProcessor, Rule.AfterExportHandlerName, HandlerParameters);
	
	ExchangeFile = HandlerParameters[0];
	Object 		 = HandlerParameters[1];
	OCRName 	 = HandlerParameters[2];
	IncomingData = HandlerParameters[3];
	OutgoingData = HandlerParameters[4];
	RefNode 	 = HandlerParameters[5];
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// DCR handlers

Procedure ExecuteHandler_DCP_BeforeProcessRule(Rule, Cancel, OutgoingData, DataSelection)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(Rule);
	HandlerParameters.Add(Cancel);
	HandlerParameters.Add(OutgoingData);
	HandlerParameters.Add(DataSelection);
	
	SafeMode.ExecuteObjectMethod(
	LoadProcessing, Rule.BeforeProcessHandlerName, HandlerParameters);
	
	Rule 		  = HandlerParameters[0];
	Cancel 		  = HandlerParameters[1];
	OutgoingData  = HandlerParameters[2];
	DataSelection = HandlerParameters[3];
	
EndProcedure

Procedure ExecuteHandler_DCP_BeforeDeleteObject(Rule, Object, Cancel, DeleteDirectly, IncomingData)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(Rule);
	HandlerParameters.Add(Object);
	HandlerParameters.Add(Cancel);
	HandlerParameters.Add(DeleteDirectly);
	HandlerParameters.Add(IncomingData);
	
	SafeMode.ExecuteObjectMethod(
	LoadProcessing, Rule.BeforeDeleteHandlerName, HandlerParameters);
	
	Rule 		 = HandlerParameters[0];
	Object 		 = HandlerParameters[1];
	Cancel 		 = HandlerParameters[2];
	DeleteDirectly = HandlerParameters[3];
	IncomingData = HandlerParameters[4];
	
EndProcedure

Procedure ExecuteHandler_DCP_AfterProcessRule(Rule)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(Rule);
	
	SafeMode.ExecuteObjectMethod(
	LoadProcessing, Rule.AfterProcessHandlerName, HandlerParameters);
	
	Rule = HandlerParameters[0];
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// Parameter handlers

Procedure ExecuteHandler_Parameters_AfterParameterImport(Name, Value)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(Name);
	HandlerParameters.Add(Value);
	
	HandlerName = "Parameters_[ParameterName]_AfterParameterImport";
	HandlerName = StrReplace(HandlerName, "[ParameterName]", Name);
	
	SafeMode.ExecuteObjectMethod(
	LoadProcessing, HandlerName, HandlerParameters);
	
	Name 	= HandlerParameters[0];
	Value  	= HandlerParameters[1];
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// CONSTANTS

Function ExchangeMessageFormatVersion()
	
	Return "3.1";
	
EndFunction

// Storage format version of exchange rules 
// that is supported in the processing.
//
// Exchange rules are retrieved from the file and saved in the infobase in storage format.
// Rule storage format can be obsolete. Rules need to be reread.
//
Function ExchangeRuleStorageFormatVersion()
	
	Return 2;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Main application operators

InitAttributesAndModuleVariables();

InitConversionRuleTable();
InitExportRuleTable();
CleaningRuleTableInitialization();
InitializationParameterSetupTable();
#EndIf