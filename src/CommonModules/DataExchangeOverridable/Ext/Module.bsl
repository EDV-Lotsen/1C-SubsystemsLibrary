////////////////////////////////////////////////////////////////////////////////
// Data exchange subsystem.
// 
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// Retrieves the list of exchange plans that use data exchange subsystem functionality.
//
// Parameters:
//  SubsystemExchangePlans - Array of exchange plan metadata objects - array of
//                           exchange plans that use data exchange subsystem 
//                           functionality.
//
// Example:
//
// SubsystemExchangePlans.Add(Metadata.ExchangePlans.ExchangeWithoutDataConversionRules);
// SubsystemExchangePlans.Add(Metadata.ExchangePlans.ExchangeWithSubsystemsLibrary);
// SubsystemExchangePlans.Add(Metadata.ExchangePlans.DistributedInfoBase);
//
Procedure GetExchangePlans(SubsystemExchangePlans) Export
	
	// _Demo Start Example
	SubsystemExchangePlans.Add(Metadata.ExchangePlans._DemoExchangeWithSubsystemsLibrary);	
	// _Demo End Example
	
EndProcedure

// Returns the default prefix of infobase object codes and numbers.
// 
// Returns:
//  String, 2 - default prefix of infobase object codes and numbers.
//
Function DefaultInfoBasePrefix() Export
	
	Return NStr("en = 'DM'");
	
EndFunction

// Is called before the object is written during data import with the universal
// data exchange.
//
Procedure BeforeWriteObject(Object, Cancel) Export
	
EndProcedure

// Is called before sending data.
// Is used for overriding the standard data sending handler.
// The following operations must be implemented into this handler:
//  - selecting data to be exported;
//  - serializing data into a message file or info a stream.
// After the handler ends execution, exported data is sent to the data exchange
// subsystem recipient.
// Messages to be exported can have arbitrary format.
// If errors occur during sending data, the handler execution must be stopped using
// the Raise method with an error description.
//
// Parameters:
//
// StandardProcessing               - Boolean - pass False to this parameter to  
//                                    cancel standard processing. Canceling standard  
//                                    processing does not mean canceling the 
//                                    operation. The default value is True.
//
// Target (read-only)               - ExchangePlanRef - exchange plan node for which 
//                                    data is exported.
//
// MessageFileName (read-only)      - String - name of the file where data is 
//                                    exported. If this parameter is filled, the 
//                                    system expects that data will be exported to a 
//                                    file. After exporting, the system will send
//                                    data from this file. If this parameter is 
//                                    empty, the system expects that data will be
//                                    exported to the MessageData parameter.
//
// MessageData                      - Arbitrary - if the MessageFileName parameter is 
//                                    empty, the system expects that data will be 
//                                    exported to this parameter.
//
// TransactionItemCount (read-only) - Number - defines maximum number of data items
//                                    that can be put into a message during one
//                                    database transaction.
//                                    A value of this parameter is set in the data 
//                                    exchange subsystem settings.
//
// EventLogEventName (read-only)    - String - event log event name of the current data
//                                    exchange session. This parameter is used to  
//                                    determine the event name when writing error   
//                                    details to the event log and corresponds to the  
//                                    EventName parameter of the WriteLogEvent method  
//                                    of the global context.
//
// SentObjectCount                  - Number - sent object counter. It is used to
//                                    store the number of sent objects in the
//                                    exchange protocol.
//
Procedure BeforeSendData(StandardProcessing,
								Target,
								MessageFileName,
								MessageData,
								TransactionItemCount,
								EventLogEventName,
								SentObjectCount
	) Export
	
	// StandardSubsystems.ServiceMode.MessageExchange
	MessageExchangeInternal.BeforeSendData(StandardProcessing,
								Target ,
								MessageFileName,
								MessageData,
								TransactionItemCount,
								EventLogEventName,
								SentObjectCount
	);
	// End StandardSubsystems.ServiceMode.MessageExchange
	
EndProcedure

// Is called before receiving data.
// Is used for overriding the standard data receiving handler.
// The following operations must be implemented into this handler:
//  - necessary checking before importing data;
//  - serializing data from a message file or from a stream.
// Messages to be imported can have arbitrary format.
// If errors occur during receiving data, the handler execution must be stopped using
// the Raise method with an error description.
//
// Parameters:
//
// StandardProcessing - Boolean     - pass False to this parameter to cancel standard
//                                    processing. Canceling standard processing does not
//                                    mean canceling the operation. The default value is
//                                    True.
//
// Sender (read-only)               - ExchangePlanRef - exchange plan node where data
//                                    will be imported.
//
// MessageFileName (read-only)      - String - name of the file where the data to be
//                                    imported is located. If this parameter is empty,
//                                    data to be imported is passed in the MessageData
//                                    parameter.
//
// MessageData                      - Arbitrary - contains data to be imported. If the 
//                                    MessageFileName parameter is empty, the data will  
//                                    be imported through this parameter.
//
// TransactionItemCount (read-only) - Number - defines maximum number of data items
//                                    that can be put into a message during one
//                                    database transaction.
//                                    A value of this parameter is set in the data 
//                                    exchange subsystem settings.
//
// EventLogEventName (read-only) -    String - event log event name of the current data
//                                    exchange session. This parameter is used to 
//                                    determine the event name when writing error 
//                                    details to the event log and corresponds to the 
//                                    EventName parameter of the WriteLogEvent method 
//                                    of the global context.
//
// ReceivedObjectCount              - Number - received object counter. It is used to
//                                    store the number of sent objects in the
//                                    exchange protocol.
//
Procedure BeforeReceiveData(StandardProcessing,
								Sender,
								MessageFileName,
								MessageData,
								TransactionItemCount,
								EventLogEventName,
								ReceivedObjectCount
	) Export
	
	// StandardSubsystems.ServiceMode.MessageExchange
	MessageExchangeInternal.BeforeReceiveData(StandardProcessing,
								Sender,
								MessageFileName,
								MessageData,
								TransactionItemCount,
								EventLogEventName,
								ReceivedObjectCount
	);
	// End StandardSubsystems.ServiceMode.MessageExchange
	
EndProcedure

// AfterGetRecipients event handler of the object record mechanism.
// The event occurs in the transaction of writing data to the infobase when data changes
// recipients have been determined by object record rules.
//
// Parameters:
// Data             - document, catalog, account, constant record manager, register
//                    record set, and so on - object to be written.
//
// Recipients       - Array of ExchangePlanNode - array of nodes where the current data
//                    changes will be registered.
//
// ExchangePlanName - String - name of the exchange plan as a metadata object, whose
//                    object record rules are used.
//
Procedure AfterGetRecipients(Data, Recipients, Val ExchangePlanName) Export
	
	// StandardSubsystems.ServiceMode.DataExchangeServiceMode
	DataExchangeServiceMode.AfterGetRecipients(Data, Recipients, ExchangePlanName);
	// End StandardSubsystems.ServiceMode.DataExchangeServiceMode
	
EndProcedure

// The initial data export change record handler.
// Is used for overriding the standard change record handler.
// Standard processing implies recording all data from the exchange plan composition.
// This handler can improve initial data export performance using exchange plan filters 
// for restricting data migration. Recording changes by filter must be implemented in
// this handler. You can use the DataExchangeServer.RegisterDataByExportStartDateAndCompany
// universal procedure if the data migration is filtered by date or by date and company.
// The handler cannot be used for performing the exchange in a distributed infobase.
// Using this handler, you can improve initial data export performance up to 2-4 times.
//
// Parameters:
//
// Target             - ExchangePlanRef - exchange plan node for which data is exported.
//
// StandardProcessing - Boolean - pass False to this parameter to cancel standard
//                      processing. Canceling standard processing does not mean
//                      canceling the operation. The default value is True.
//
Procedure InitialDataExportChangeRecord(Val Recipient, StandardProcessing, Filter) Export
	
	If TypeOf(Recipient) = Type("ExchangePlanRef._DemoExchangeWithSubsystemsLibrary")  Then
		StandardProcessing = False;
		AttributeValues = CommonUse.GetAttributeValues(Recipient, "UseFilterByCompanies, DocumentExportStartDate, Companies");
		Companies = ?(AttributeValues.UseFilterByCompanies, AttributeValues.Companies.Unload().UnloadColumn("Company"), Undefined);
		DataExchangeServer.RegisterDataByExportStartDateAndCompany(Recipient, AttributeValues.DocumentExportStartDate, Companies, Filter);
	EndIf;
	
EndProcedure







