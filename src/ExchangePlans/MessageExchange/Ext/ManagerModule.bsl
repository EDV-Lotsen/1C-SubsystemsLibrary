#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Interface

// Allows to modify the default exchange plan settings.
// For default settings values, see DataExchangeServer.DefaultExchangePlanSettings.
// 
// Parameters:
//  Settings - Structure - Contains the default settings.
//
Procedure DefineSettings(Settings) Export
	
	Settings.WarnAboutExchangeRuleVersionMismatch = False;
	
EndProcedure

// Returns the default name for a file used to export the exchange settings for the target.
// The same file name must be used both for the source and target exchange plans.
// 
// Returns:
//  String - default name of the file used to export data exchange settings.
//
Function SettingsFileNameForTarget() Export
	
	Return "";
	
EndFunction

// Returns filter structure at the exchange plan node with default values set.
// The settings structure is identical to the content of title attributes 
// and tabular section of the exchange plan.
// For title attributes, structure items with identical keys and values are used. 
// For tabular sections, structures containing the arrays of exchange plan tabular section value fields 
// are used.
// 
// Parameters:
//   CorrespondentVersion - String - correspondent version number. Can be used, among others, 
// 								                     to apply different node settings content
// 								                     to different correspondent versions. 
//   FormName             - String - name of the node setup form in use. Can be used, among others, 
//                                   to apply different forms to different correspondent versions.
// Returns:
//   SettingsStructure - Structure - filter structure for the exchange plan node.
// 
Function NodeFilterStructure() Export
	
	Return New Structure;
	
EndFunction

// Returns default value structure for a node.
// The settings structure is identical to the content of title attributes of the exchange plan.
// For title attributes, structure items with identical keys and values are used.
// 
// Parameters:
//   CorrespondentVersion - String - correspondent version number. Can be used, among others,
// 								                     to apply different node default value content 
//                                   to different correspondent versions.
//   FormName             - String - name of the default value setup form in use.
// 					                          Can be used, among others, to apply different forms 
//                                   to different correspondent versions.
// 
// Returns:
//   SettingsStructure - Structure - default value structure for the exchange plan node.
// 
Function NodeDefaultValues() Export
	
	Return New Structure;
	
EndFunction

// Returns a string with description of data migration restrictions for user.
// Based on the filters enabled at the node, the developer must create a human-readable string 
// containing restrictions description.
// 
// Parameters:
//   NodeFilterStructure  - Structure - filter structure for the exchange plan node 
//                                      retrieved by the NodeFilterStructure() function.
//   CorrespondentVersion - String    - correspondent version number. Can be used, among others, 
// 								                        to apply different data transfer restrictions
//                                      to different correspondent versions.
// Returns:
//   String - string with description of data migration restrictions for user.
//
Function DataTransferRestrictionDetails(NodeFilterStructure) Export
	
	Return "";
	
EndFunction

// Returns a string with description of default values for user.
// Based on the node default values, the developer must create a human-readable description string.
// 
// Parameters:
//   NodeDefaultValues    - Structure - default values structure for the exchange plan node 
// 										                     retrieved by the NodeDefaultValues() function.
//   CorrespondentVersion - String    - correspondent version number. Can be used, among others,
// 								                        to apply different default values to different correspondent versions.
// 
// Returns:
//   String - string with description of default values for user.
//
Function DefaultValueDetails(NodeDefaultValues) Export
	
	Return "";
	
EndFunction

// Sets presentation for a new data exchange creation command.
//
// Returns:
//   String - command presentation displayed to user.
//
Function NewDataExchangeCreationCommandTitle() Export
	
	Return "";
	
EndFunction

// Determines whether wizard is used to create new exchange plan nodes.
//
// Returns:
//   Boolean - wizard usage flag.
//
Function UseDataExchangeCreationWizard() Export
	
	Return False;
	
EndFunction

// Determines whether object change record mechanism must be used.
//
// Returns:
//   Boolean - if True, object change record mechanism must be used for the current exchange plan.
// 		         If False, object change record mechanism is not needed.
//
Function UseObjectChangeRecordMechanism() Export
	
	Return False;
	
EndFunction

// Returns a user form intended for initial infobase image creation.
// This form will be opened upon completion of exchange setup wizard.
// For non-DIB exchange plans, returns an empty string.
//
// Returns:
//   String - form name.
//
// Example:
//   Return "ExchangePlan.DistributedInfobaseExchange.Form.InitialImageCreationForm";
//
Function InitialImageCreationFormName() Export
	
	Return "";
	
EndFunction

// Returns an array of message transports used for this exchange plan.
//
// Returns:
//   Array - array containing ExchangeMessageTransportKinds enumeration values.
//
// Example:
// 1. If the exchange plan only supports FILE and FTP message transports,
//    the function body should be defined as follows:
//
// Result = New Array;
// Result.Add(Enums.ExchangeMessageTransportKinds.FILE);
// Result.Add(Enums.ExchangeMessageTransportKinds.FTP);
// Result Return;
//
// 2. If the exchange plan supports all application message transports,
//    the function body should be defined as follows:
//
// Return DataExchangeServer.AllApplicationExchangeMessageTransports();
//
Function UsedExchangeMessageTransports() Export
	
	Result = New Array;
	Result.Add(Enums.ExchangeMessageTransportKinds.WS);
	Result.Add(Enums.ExchangeMessageTransportKinds.FILE);
	Result.Add(Enums.ExchangeMessageTransportKinds.FTP);
	Result.Add(Enums.ExchangeMessageTransportKinds.EMAIL);
	
	Return Result;
	
EndFunction

// Sets the flag specifying whether exchange plan is used to organize exchange SaaS.
// If the flag is set, data exchange based on this exchange plan is available at SaaS.
// If the flag is not set, the exchange plan can only be used in the local operating mode.
//
// Returns:
//   Boolean - flag specifying whether the exchange plan is used in SaaS.
//
Function ExchangePlanUsedInSaaS() Export
	
	Return False;
	
EndFunction

// Returns flag specifying whether the exchange plan supports data exchange 
// with a SaaS correspondent infobase.
// If the flag is set, data exchange can be established between the infobase 
// in local mode and the SaaS correspondent.
//
// Returns:
//   Boolean - flag specifying whether data exchange with SaaS correspondents can be established.
//
Function CorrespondentInSaaS() Export
	
	Return False;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Exchange event handlers not using the exchange rules

// Determines the object deletion mode during data import.
//
// Returns:
//   Boolean - if True, the object is physically deleted from the infobase 
//             after the delete information is received.
// 		         If False, the object is only marked for deletion.
//
Function AllowDeleteObjects() Export
	
	Return True;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Used when working through a correspondent infobase link based on external connection or web service

// Returns names (comma-separated) of attributes and exchange plan tabular sections 
// that are common for both data exchange participants.
//
// Parameters:
//   CorrespondentVersion - String - correspondent version number. Can be used, among others, 
// 								                     to apply different common node data content 
//                                   to different correspondent versions.
//   FormName             - String - name of the default value setup form in use.
// 					                          Can be used, among others, to apply different forms 
//                                   to different correspondent versions.
//
// Returns:
//   String - attribute name list.
//
Function CommonNodeData(CorrespondentVersion, FormName) Export
	
	Return "";
EndFunction

// Returns filter structure for the exchange plan node of the correspondent infobase with default values set.
// The settings structure is identical to the content of title attributes and tabular section 
// of the exchange plan of the correspondent infobase.
// For title attributes, structure items with identical keys and values are used.
// For tabular sections, structures containing the arrays of exchange plan tabular section value fields 
// are used.
// 
// Parameters:
//   CorrespondentVersion - String - correspondent version number. Can be used, among others, 
// 								                     to apply different node settings content
//                                   to different correspondent versions. 
//   FormName             - String - name of the node setup form in use. Can be used, among others, 
// 					                          to apply different forms to different correspondent versions.
// 
// Returns:
//  SettingsStructure - Structure - filter structure for the exchange plan node of the correspondent infobase.
// 
Function CorrespondentInfobaseNodeFilterSetup(CorrespondentVersion, FormName) Export
	
	Return New Structure;
EndFunction

// Returns default value structure for a node of the correspondent infobase.
// The settings structure is identical to the content of title attributes of the exchange plan 
// of the correspondent infobase.
// For title attributes, structure items with identical keys and values are used.
// 
// Parameters:
//   CorrespondentVersion - String - correspondent version number. Can be used, among others, 
// 								                     to apply different node default value content 
//                                   to different correspondent versions.
//   FormName             - String - name of the default value setup form in use. Can be used, among others, 
// 					                          to apply different forms to different correspondent versions.
// 
// Returns:
//   SettingsStructure - Structure - default value structure for an exchange plan node 
//                                   of the correspondent infobase.
//
Function CorrespondentInfobaseNodeDefaultValues(CorrespondentVersion, FormName) Export
	
	Return New Structure;
EndFunction

// Returns a string with user description of data migration restrictions for the correspondent infobase.
// Based on the filters enabled at the correspondent node, the developer must create a human-readable 
// restrictions description string.
// 
// Parameters:
//   NodeFilterStructure  - Structure - filter structure for the exchange plan node 
//                                      of the correspondent infobase,
//                                      retrieved by the CorrespondentInfobaseNodeFilterSetup() function.
//   CorrespondentVersion - String    - correspondent version number. Can be used, among others,
// 					                             to apply different data transfer restrictions 
//                                      to different correspondent versions.
// 
// Returns:
//   String - string with description of data migration restrictions for user.
//
Function CorrespondentInfobaseDataTransferRestrictionDetails(NodeFilterStructure, CorrespondentVersion) Export
	
	Return "";
EndFunction

// Returns a string with user description of default values for the correspondent infobase.
// Based on the default values at the correspondent node, the developer must create a human-readable 
// description string.
// 
// Parameters:
//   NodeDefaultValues    - Structure - default value structure for the exchange plan node
//                                      of the correspondent infobase, retrieved by the 
//                                      CorrespondentInfobaseNodeDefaultValues() function.
//   CorrespondentVersion - String    - correspondent version number. Can be used, among others, 
// 								                        to apply different default values to different correspondent versions.
// 
// Returns:
//   String - string with description of default values for user.
//
Function CorrespondentInfobaseDefaultValueDetails(NodeDefaultValues, CorrespondentVersion) Export
	
	Return "";
EndFunction

// Sets hints for setting up the correspondent infobase accounting parameters.
// 
// Parameters:
//   CorrespondentVersion - String - correspondent version number. Can be used, among others, 
// 								                     to apply different accounting parameter setup hints 
//                                   to different correspondent versions.
// 
// Returns:
//   String - string with hints for setting up the correspondent infobase accounting parameters.
//
Function CorrespondentInfobaseAccountingSettingsSetupComment(CorrespondentVersion) Export
	
	Return "";
EndFunction

// The procedure is intended to retrieve additional data used for data exchange setup 
// at the correspondent infobase.
//
// Parameters:
//   AdditionalData - Structure - additional data used for data exchange setup at the correspondent infobase.
//                                Only values supporting XDTO serialization can be used as structure values.
//
Procedure GetAdditionalDataForCorrespondent(AdditionalData) Export
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Events handlers

// Event handler for correspondent infobase connection.
// The event occurs when connection to the correspondent infobase is established
// and correspondent version is received during wizard-based exchange setup, 
// either for direct connections or Internet connections.
// The handler can analyze correspondent versions
// and (in case the exchange setup is not supported by a correspondent version) raise exceptions.
//
// Parameters:
//   CorrespondentVersion (read-only) - String - correspondent configuration version (example: 2.1.5.1).
//
Procedure OnConnectToCorrespondent(CorrespondentVersion) Export
	
EndProcedure

// Event handler for sending the sender node data.
// The event occurs when the sender node data is sent from the current infobase
// to the correspondent infobase (before the node data is placed to exchange messages).
// The handler can be used to modify the transferred data or to cancel the data transfer.
//
// Parameters:
//   Sender - ExchangePlanObject - exchange plan node on which behalf data is sent.
//   Ignore - Boolean            - flag specifying that the node data sending is cancelled.
//                                 If set to True, the node data will not be sent. 
//                                 Set to False by default.
//
Procedure OnSendSenderData(Sender, Ignore) Export
	
EndProcedure

// Event handler for receiving the sender node data.
// The event occurs when the sender node data is received and the node data is retrieved 
// from exchange messages but not yet saved to the infobase.
// The handler can be used to modify the received data or to cancel the data transfer.
//
// Parameters:
//   Sender - ExchangePlanObject - exchange plan node on which behalf data is received.
//   Ignore - Boolean            - flag specifying that the node data receiving is rejected.
//                                 If set to True, the node data will not be received.
//                                 Set to False by default.
//
Procedure OnGetSenderData(Sender, Ignore) Export
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Constants and accounting parameter checks

// Sets hints for setting up the accounting parameters.
// 
// Returns:
//   String - string with hints for setting up the accounting parameters.
//
Function AccountingSettingsSetupComment() Export
	
	Return "";
	
EndFunction

// Validates the accounting parameters setup.
//
// Parameters:
//   Cancel    - Boolean - flag specifying whether the exchange setup cannot proceed 
//                         due to invalid accounting parameters. 
//   Recipient - ExchangePlanRef - exchange node used to validate the accounting parameters. 
//   Message   - String - contains text of invalid accounting parameters message.
//
Procedure AccountingSettingsCheckHandler(Cancel, Recipient, Message) Export
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Batch object modification

// Returns a list of attributes that are excluded from the scope 
// of the batch object modification data processor.
//
// Returns:
//   Array - array containing names of attributes that cannot be edited.
//
Function AttributesToSkipOnGroupProcessing() Export
	
	Result = New Array;
	Result.Add("*");
	Return Result;
	
EndFunction

#EndRegion

#EndIf