////////////////////////////////////////////////////////////////////////////////
// Data exchange subsystem
// 
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// Defines the default prefix of infobase object codes and numbers.
//
// Parameters:
//   Prefix - String, 2 - default prefix of infobase object codes and numbers.
//
Procedure OnDefineDefaultInfobasePrefix(Prefix) Export

	// _Demo begin example
	Prefix = NStr("en = 'DM'");
	// _Demo end example
	
EndProcedure

// Retrieves the list of exchange plans that use data exchange subsystem functionality.
//
// Parameters:
// SubsystemExchangePlans - Array - array of exchange plans that use 
//                          data exchange subsystem functionality.
//                          Array elements are exchange plan metadata objects.
//
// The example of the procedure body:
//
//   SubsystemExchangePlans.Add(Metadata.ExchangePlans.ExchangeWithoutConversionRules);
//   SubsystemExchangePlans.Add(Metadata.ExchangePlans.ExchangeWithSubsystemsLibrary);
//   SubsystemExchangePlans.Add(Metadata.ExchangePlans.DistributedInfobase);
//
Procedure GetExchangePlans(SubsystemExchangePlans) Export
	
	//PARTIALLY_DELETED
	// _Demo begin example
	//SubsystemExchangePlans.Add(Metadata.ExchangePlans._DemoStandaloneMode);
	//SubsystemExchangePlans.Add(Metadata.ExchangePlans._DemoExchangeWithoutConversionRules);
	//SubsystemExchangePlans.Add(Metadata.ExchangePlans._DemoExchangeWithSubsystemsLibrary);
	//SubsystemExchangePlans.Add(Metadata.ExchangePlans._DemoExchangeWithSubsystemsLibrary212);
	//SubsystemExchangePlans.Add(Metadata.ExchangePlans._DemoDistributedInfobaseExchange);
	//SubsystemExchangePlans.Add(Metadata.ExchangePlans._DemoDistributedInfobaseExchangeWithExternalFiles);
	 SubsystemExchangePlans.Add(Metadata.ExchangePlans.DemoExchangeInDIB);
	 SubsystemExchangePlans.Add(Metadata.ExchangePlans.DemoExchangeWithSL);
	// _Demo end example
	
EndProcedure

// This procedure is called on data export.
// It is used for overriding the standard data export handler.
// The following operations must be implemented into this handler:
// selecting data to be exported, serializing data into a message file or info a stream.
// After the handler ends execution, exported data is sent to the data exchange subsystem Target.
// Messages to be exported can have arbitrary format.
// If errors occur during sending data, the handler execution
// must be stopped using the Raise method with an error description.
//
// Parameters:
//
// StandardProcessing   - Boolean - this parameter contains a flag that shows whether 
//                        the standard processing is used.
//                        You can set this parameter value to False to cancel the standard processing. 
//                        Canceling standard processing does not mean canceling the operation.
//                        The default value is True.
//
// Target               - ExchangePlanRef - exchange plan node for which data is exported.
//
// MessageFileName      - String - name of the file where the data is to be exported.
//                        If this parameter is filled, the platform expects that data 
//                        is to be exported to a file. 
//                        After exporting, the platform sends data from this file.
//                        If this parameter is  empty, the system expects that data 
//                        is exported to the MessageData parameter.
//
// MessageData          - Arbitrary - if the MessageFileName parameter is empty, 
//                        the platform expects that data is exported to this parameter.
//
// TransactionItemCount - Number - defines the maximum number of data items that can be put 
//                        into a message during one database transaction.
//                        You can implement the algorithms of transaction locks for 
//                        the exported data in this handler.
//                        A value of this parameter is set in the data exchange subsystem settings.
//
// EventLogEventName    - String - event log event name of the current data exchange session.
//                        This parameter is used to determine the event name (errors, warnings, information) 
//                        when writing error details to the event log.
//                        It matches the EventName parameter of the WriteLogEvent method of the global context.
//
// SentObjectCount      - Number - sent object counter. It is used to store the number of exported objects 
//                        in the exchange protocol.
//
Procedure OnDataExport(StandardProcessing,
								Target,
								MessageFileName,
								MessageData,
								TransactionItemCount,
								EventLogEventName,
								SentObjectCount
	) Export
	
EndProcedure

// This procedure is called on data import.
// It is used for overriding the standard data import handler.
// The following operations must be implemented into this handler:
// necessary checking before importing data, serializing data from a message file or from a stream.
// Messages to be imported can have arbitrary format.
// If errors occur during receiving data, the handler execution
// must be stopped using the Raise method with an error description.
//
// Parameters:
//
// StandardProcessing  - Boolean - this parameter contains a flag that shows whether 
//                                 the standard processing is used.
//                                 You can set this parameter value to False to cancel the standard processing.
//                                 Canceling standard processing does not mean canceling the operation.
//                                 The default value is True.
//
// Source               - ExchangePlanRef - exchange plan node for which data is imported.
//
// MessageFileName      - String - name of the file where the data is to be imported.
//                        If this parameter is empty, data to be imported is passed 
//                        in the MessageData parameter.
//
// MessageData          - Arbitrary - contains data to be imported.
//                        If the MessageFileName parameter is empty, the data is to be imported 
//                        through this parameter.
//
// TransactionItemCount - Number - defines the maximum number of data items that can be read 
//                        from a message and recorded to the infobase during one database transaction.
//                        If it is necessary, you can implement algorithms of data recording in transaction.
//                        A value of this parameter is set in the data exchange subsystem settings.
//
// EventLogEventName    - String - event log event name of the current data exchange session.
//                        This parameter is used to determine the event name (errors, warnings, information) 
//                        when writing error details to the event log.
//                        It matchs the EventName parameter of the WriteLogEvent method of the global context.
//
// ReceivedObjectCount  - Number - received object counter.
//                        It is used to store the number of imported objects in the exchange protocol.
//
Procedure OnDataImport(StandardProcessing,
								Source,
								MessageFileName,
								MessageData,
								TransactionItemCount,
								EventLogEventName,
								ReceivedObjectCount
	) Export
	
EndProcedure

// The initial data export change record handler.
// It is used for overriding the standard change registration handler.
// Standard processing implies recording all data from the exchange plan composition.
// This handler can improve initial data export performance using exchange plan filters 
// for restricting data migration.
// Recording changes by filter must be implemented in this handler.
// You can use the DataExchangeServer.RegisterDataByExportStartDateAndCompany
// universal procedure if the data migration is filtered by date or by date and company.
// The handler cannot be used for performing the exchange in a distributed infobase.
// Using this handler, you can improve initial data export performance up to 2-4 times.
//
// Parameters:
//
// Target - ExchangePlanRef - exchange plan node for which data is exported.
//
// StandardProcessing - Boolean - this parameter contains a flag that shows whether 
//                      the standard processing is used.
//                      You can set this parameter value to False to cancel the standard processing.
//                      Canceling standard processing does not mean canceling the operation.
//                      The default value is True.
//
Procedure InitialDataExportChangeRecord(Val Target, StandardProcessing, Filter) Export
	
	//PARTIALLY_DELETED
	// _Demo begin example
	//If    TypeOf(Target) = Type("ExchangePlanRef._DemoExchangeWithSubsystemsLibrary")
	//	Or TypeOf(Target) = Type("ExchangePlanRef._DemoExchangeWithoutConversionRules")
	//	Or TypeOf(Target) = Type("ExchangePlanRef._DemoDistributedInfobaseExchange") Then
	//	
	//	StandardProcessing = False;
	//	
	//	AttributeValues = CommonUse.ObjectAttributeValues(Target, "UseFilterByCompanies, DocumentExportStartDate, Companies");
	//	
	//	Companies = ?(AttributeValues.UseFilterByCompanies, AttributeValues.Companies.Unload().UnloadColumn("Company"), Undefined);
	//	
	//	DataExchangeServer.RegisterDataByExportStartDateAndCompany(Target, AttributeValues.DocumentExportStartDate, Companies, Filter);
	//	
	//EndIf;
	// _Demo end example
	
EndProcedure

// This procedure is called when a data change conflict is detected.
// The event occurs if an object is modified both in the current infobase and
// in a correspondent infobase, and object modifications are different.
// It overrides the standard data change conflict handler.
// The standard processing of conflicts implies receiving changes
// from the master node and ignoring changes from a subordinate node.
// To change the standard processing, redefine the ItemReceive parameter.
// In this handler you can specify the algorithms of resolving conflicts for individual infobase
// objects, or infobase object properties, or source nodes, or the entire infobase, or all data items.
// This handler is called during the execution of any data exchange type 
// (during data exchange in a distributed infobase and during data exchange based on exchange rules).
//
// Parameters:
//  DataItem                   - data item that is read from the data exchange message.
//                               Data items can be ConstantValueManager.<Constant name> objects, 
//                               infobase objects (except "Object deletion" objects), 
//                               register record sets, sequences, or recalculations.
//
// ItemReceive                 - DataItemReceive - Defines whether a read data item is recorded 
//                               to the infobase if a conflict is detected.
//                               The default parameter value is Auto, and this option implies
//                               receiving data from the master node and ignoring data from the subordinate node.
//                               You can redefine the parameter value in the handler.
//
// Source                      - ExchangePlanRef - exchange plan node that provides the source data.
//
// DataReceivingFromMasterNode - Boolean - in a distributed infobase this flag shows whether data is received from the master node.
//                               If True, data is received from the master node.
//                               If False, data is received from the subordinate node.
//                               In exchanges based on exchange rules its value is True if the object priority that
//                               is specified in the exchange rules and is used for resolving conflicts is set to 
//                               Higher (the default value) or not specified.
//                               This parameter value is False if the object priority is set to Lower or Equal.
//                               In other cases the parameter value is True.
//
Procedure OnDataChangeConflict(Val DataItem, ItemReceive, Val Source, Val DataReceivingFromMasterNode) Export
	
	//PARTIALLY_DELETED
	// _Demo begin example
	
	// Inverting the default behavior if a data change conflict is detected.
	// Receiving subordinate node data and ignoring master node data.
	
	///////////////////////////////////////////////////////////////////////////////
	// Resolving conflicts for each exchange plan
	//
	//If TypeOf(Source) = Type("ExchangePlanRef._DemoDistributedInfobaseExchange") Then
	//	
	//	// Resolving conflicts for the _DemoDistributedInfobaseExchange exchange plan
	//	
	//	If TypeOf(DataItem) = Type("CatalogObject._DemoCounterparties") Then
	//		
	//		ItemReceive = DataExchangeServer.InvertDefaultDataItemReceive(DataReceivingFromMasterNode);
	//		
	//	ElsIf TypeOf(DataItem) = Type("CatalogObject._DemoProductsAndServices") Then
	//		
	//		ItemReceive = DataExchangeServer.InvertDefaultDataItemReceive(DataReceivingFromMasterNode);
	//		
	//	EndIf;
	//	
	//ElsIf TypeOf(Source) = Type("ExchangePlanRef._DemoStandaloneMode") Then
	//	
	//	// Resolving conflicts for the _DemoStandaloneMode exchange plan
	//	
	//	If TypeOf(DataItem) = Type("CatalogObject._DemoCounterparties") Then
	//		
	//		ItemReceive = DataExchangeServer.InvertDefaultDataItemReceive(DataReceivingFromMasterNode);
	//		
	//	EndIf;
	//	
	//EndIf;
	//
	/////////////////////////////////////////////////////////////////////////////////
	//// Resolving conflicts for all exchange plans
	//
	//If TypeOf(DataItem) = Type("CatalogObject.Companies") Then
	//	
	//	ItemReceive = DataExchangeServer.InvertDefaultDataItemReceive(DataReceivingFromMasterNode);
	//	
	//EndIf;
	
	// _Demo end example
	
EndProcedure

#EndRegion