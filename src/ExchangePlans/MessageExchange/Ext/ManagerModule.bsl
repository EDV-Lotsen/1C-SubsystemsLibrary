
////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// Returns a default settings file name.
// The target node exchange settings will be exported to this file.
// This value must be the same in the source and target exchange plans.
// 
// Returns:
//  String, 255 - default file name for exporting data exchange settings.
//
Function SettingsFileNameForTarget() Export
	
	Return "";
	
EndFunction

// Returns a filter structure of the exchange plan node filled with default values.
// The filter structure is identical to the structure of exchange plan header 
// attributes and tabular sections.
// For header attributes, the corresponding keys and values of structure items are used.
// For tabular sections, structures that contain arrays of exchange plan tabular
// section field values are used. 
// 
// Returns:
//  SettingsStructure - Structure - filter structure of the exchange plan node.
// 
Function NodeFilterStructure() Export
	
	Return New Structure;
	
EndFunction

// Returns a structure of default values for the node;
// The settings structure are identical to the structure of exchange plan header attributes.
// For header attributes, the corresponding keys and values of structure items are used.
// 
// Returns:
//  SettingsStructure - Structure - default value structure of the exchange plan node.
// 
Function NodeDefaultValues() Export
	
	Return New Structure;
	
EndFunction

// Returns a string with data transfer restrictions to be displayed to end users.
// An applied solution developer must generate a human-readable restriction detail
// string based on the exchange node filters.
//
// Parameters:
//  NodeFilterStructure - Structure - exchange plan node filter structure that 
// was returned by the NodeFilterStructure function.
// 
// Returns:
//  String, Unlimited - string that describes data transfer restrictions. It will be
//  displayed to end users.
//
Function DataTransferRestrictionDetails(NodeFilterStructure) Export
	
	Return "";
	
EndFunction

// Returns a string with default value details that will be displayed to end users.
// An applied solution developer must generate a human-readable detail
// string based on the exchange node filters.
// 
// Parameters:
// NodeDefaultValues - Structure - structure of default values of the exchange plan 
// node that was returned by the NodeDefaultValues function.
// 
// Returns:
//  String, Unlimited - string that describes data transfer restrictions. It will be
//  displayed to end users.
//
Function DefaultValueDetails(NodeDefaultValues) Export
	
	Return "";
	
EndFunction

// Returns a creation command presentation of a new data exchange.
//

// Returns:
//  String, Unlimited - command presentation to be displayed in a user interface.
//
// Example:
//  Return NStr("en = 'Create an exchange in the distributed infobase.'");
//
Function NewDataExchangeCreationCommandTitle() Export
	
	Return "";
	
EndFunction

// Determines whether the wizard is used for creating new exchange plan nodes.
//
// Returns:
//  Boolean - flag that shows whether the wizard is used for creating new exchange
//   plan nodes.
//
Function UseDataExchangeCreationWizard() Export
	
	Return False;
	
EndFunction

// Determines whether the object registration mechanism is used for the current 
// exchange plan.
//
// Returns:
//  Boolean - flag that shows whether the object registration mechanism is used.
//
Function UseObjectChangeRecordMechanism() Export
	
	Return False;
	
EndFunction

// Returns the user form for creating an initial image of the infobase.
// This form will be opened after you finish setting the exchange with the wizard.
// For exchange plans of an undistributed infobase, the function returns an empty string.
//
// Returns:
//  String, Unlimited - form name.
//
// Example:
//  Return "ExchangePlan._DemoDistributedInfoBase.Form.PrimaryImageCreationForm";
//
Function InitialImageCreationFormName() Export
	
	Return "";
	
EndFunction

// Returns an array of message transports that are used for the current exchange plan.
//
// Examples:
// 1. If the exchange plan supports only two message transports (FILE and FTP), 
// the function body must be defined in the following way:
//
// Result = New Array;
// Result.Add(Enums.ExchangeMessageTransportKinds.FILE);
// Result.Add(Enums.ExchangeMessageTransportKinds.FTP);
// Return Result;
//
// 2. If the exchange plan supports all message transports that are 
// defined in the configurations, the function body must be defined in the following way:
//
// Return DataExchangeServer.AllApplicationExchangeMessageTransports();
//
// Returns:
//  Array - array of ExchangeMessageTransportKindsenumeration values.
//
Function UsedExchangeMessageTransports() Export
	
	Result = New Array;
	Result.Add(Enums.ExchangeMessageTransportKinds.WS);
	Result.Add(Enums.ExchangeMessageTransportKinds.FILE);
	Result.Add(Enums.ExchangeMessageTransportKinds.FTP);
	Result.Add(Enums.ExchangeMessageTransportKinds.EMAIL);
	
	Return Result;
	
EndFunction

Function ExchangePlanUsedInServiceMode() Export
	
	Return False;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Event handlers for exchanges that do not have any rules defined.

// Object change conflict event handler.
// This event occurs during data import if changes of the object being imported
// are registered in the infobase.
//
// Parameters:
//  InfoBaseNode – ExchangePlanRef – exchange plan node where data is being imported.
//  Object – object that caused the change conflict.
//
// Returns:
//  Boolean - True if the object being imported must be recorded into the infobase, 
//   otherwise is False.
//
Function ApplyObjectOnChangeConflict(InfoBaseNode, Object) Export
	
	Return False;
	
EndFunction

// Determines the object deletion mode during data import.
//
// Returns:
//  Boolean - True if an object will be physically deleted, False if objects are marked for deletion.
//
Function AllowDeleteObjects() Export
	
	Return True;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for working with external connections.

// Returns a filter structure of the correspondent infobase exchange plan node filled 
// with default values.
// The filter structure is identical to  the structure of correspondent infobase 
// exchange plan header attributes and tabular sections.
// For header attributes, the corresponding keys and values of structure items are used.
// For tabular sections, structures that contain arrays of exchange plan tabular
// section field values are used. 
// 
// Returns:
//  SettingsStructure - Structure - filter structure of the correspondent infobase exchange plan node.
// 
Function CorrespondentInfoBaseNodeFilterSetup() Export
	
	Return New Structure;
	
EndFunction

// Returns a structure of correspondent infobase node default values.
// The settings structure is identical to the structure of correspondent infobase 
// exchange plan header attributes.
// For header attributes, the corresponding keys and values of structure items are used.
// 
// Returns:
//  SettingsStructure - Structure - default value structure of the correspondent infobase exchange plan node.
// 
Function CorrespondentInfoBaseNodeDefaultValues() Export
	
	Return New Structure;
	
EndFunction

// Returns a string with correspondent infobase data transfer restrictions that will be
// displayed to end users.  
// An applied solution developer must generate a human-readable restriction detail string based on the correspondent infobase filters.
// 
// Parameters:
//  NodeFilterStructure - Structure - correspondent infobase exchange plan node filter 
//   structure that was returned by the NodeFilterStructure function.
// 
// Returns:
//  String, Unlimited - string that describes data transfer restrictions. It will be displayed to end users.
//
Function CorrespondentInfoBaseDataTransferRestrictionDetails(NodeFilterStructure) Export
	
	Return "";
	
EndFunction

// Returns a string with correspondent infobase default value details that will be 
// An applied solution developer must generate a human-readable detail string based on 
// the default node values.
// 
// Parameters:
//  NodeDefaultValues - Structure - structure of default values for the correspondent 
//   infobase exchange plan node that was returned by the
//   CorrespondentInfoBaseNodeDefaultValues function.
// 
// Returns:
// String, Unlimited - string that describes default values. It will be displayed to end users.
//
Function CorrespondentInfoBaseDefaultValueDetails(NodeDefaultValues) Export
	
	Return "";
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Constants and verification of accounting parameters.

Function CommonNodeData() Export
	
	Return "";
	
EndFunction

Function AccountingSettingsSetupComment() Export
	
	Return "";
	
EndFunction

Function CorrespondentInfoBaseAccountingSettingsSetupComment() Export
	
	Return "";
	
EndFunction

Procedure AccountingSettingsCheckHandler(Cancel, Recipient, Message) Export
	
	
	
EndProcedure
