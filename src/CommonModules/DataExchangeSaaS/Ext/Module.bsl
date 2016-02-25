////////////////////////////////////////////////////////////////////////////////
// DataExchangeSaaS: data exchange functionality.
//
////////////////////////////////////////////////////////////////////////////////
 
#Region InternalInterface
 
// See the description of this procedure in the StandardSubsystemsServer module.
Procedure InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers) Export
 
 // CLIENT HANDLERS. 
 
ClientHandlers[
		"StandardSubsystems.BaseFunctionality\OnStart"].Add(
			"DataExchangeSaaSClient");
 
 ClientHandlers[
  "StandardSubsystems.BaseFunctionality\OnGetExitWarningList"].Add(
   "DataExchangeSaaSClient");
 
 // SERVER HANDLERS.
 
 ServerHandlers["StandardSubsystems.InfobaseVersionUpdate\OnAddUpdateHandlers"].Add(
  "DataExchangeSaaS");
 
 If CommonUse.SubsystemExists("StandardSubsystems.SaaSOperations.MessageExchange") Then
  ServerHandlers["StandardSubsystems.SaaSOperations.MessageExchange\MessageChannelHandlersOnDefine"].Add(
   "DataExchangeSaaS");
 EndIf;
 
 If CommonUse.SubsystemExists("StandardSubsystems.SaaSOperations.JobQueue") Then
  ServerHandlers["StandardSubsystems.SaaSOperations.JobQueue\OnDefineHandlerAliases"].Add(
   "DataExchangeSaaS");
 EndIf;
 
 If CommonUse.SubsystemExists("StandardSubsystems.SaaSOperations") Then
  ServerHandlers[
   "StandardSubsystems.SaaSOperations\InfobaseParameterTableOnFill"].Add(
    "DataExchangeSaaS");
 EndIf;
 
 ServerHandlers["StandardSubsystems.BaseFunctionality\OnSendDataToMaster"].Add(
  "DataExchangeSaaS");
 
 ServerHandlers["StandardSubsystems.BaseFunctionality\OnReceiveDataFromSlave"].Add(
  "DataExchangeSaaS");
 
 ServerHandlers["StandardSubsystems.BaseFunctionality\SupportedInterfaceVersionsOnDefine"].Add(
  "DataExchangeSaaS");
 
 ServerHandlers[
  "StandardSubsystems.BaseFunctionality\StandardSubsystemClientLogicParametersOnAddOnExit"].Add(
  "DataExchangeSaaS");
 
 ServerHandlers[
  "StandardSubsystems.BaseFunctionality\OnAddStandardSubsystemClientLogicParametersOnStart"].Add(
  "DataExchangeSaaS");
 
 ServerHandlers[
  "StandardSubsystems.BaseFunctionality\StandardSubsystemClientLogicParametersOnAdd"].Add(
  "DataExchangeSaaS");
 
 If CommonUse.SubsystemExists("CloudTechnology.DataImportExport") Then
  ServerHandlers[
   "CloudTechnology.DataImportExport\OnFillExcludedFromImportExportTypes"].Add(
    "DataExchangeSaaS");
 EndIf;
 
 ServerHandlers["StandardSubsystems.BaseFunctionality\OnGetMandatoryExchangePlanObjects"].Add(
  "DataExchangeSaaS");
 
 ServerHandlers["StandardSubsystems.BaseFunctionality\ExchangePlanObjectsToExcludeOnGet"].Add(
  "DataExchangeSaaS");
 
 ServerHandlers["StandardSubsystems.BaseFunctionality\OnGetExchangePlanInitialImageObjects"].Add(
  "DataExchangeSaaS");
 
 ServerHandlers["StandardSubsystems.SaaSOperations.MessageExchange\RecordingIncomingMessageInterfaces"].Add(
  "DataExchangeSaaS");
 
 ServerHandlers["StandardSubsystems.SaaSOperations.MessageExchange\RecordingOutgoingMessageInterfaces"].Add(
  "DataExchangeSaaS");
 
EndProcedure
 
// Sets up a constant that shows whether data has been changed
// and sends a message about changes with the current data area number to the service manager.
//
Procedure SetDataChangeFlag() Export
 
 SetPrivilegedMode(True);
 
 DataArea = CommonUse.SessionSeparatorValue();
 
 BeginTransaction();
 Try
  MessageExchange.SendMessage("DataExchange\ManagementApplication\DataChangeFlag",
      New Structure("NodeCode", DataExchangeServer.ExchangePlanNodeCodeString(DataArea)),
      SaaSOperationsCached.ServiceManagerEndpoint());
  
  Constants.DataChangesRecorded.Set(True);
  
  CommitTransaction();
 Except
  RollbackTransaction();
  Raise;
 EndTry;
 
EndProcedure
 
// Adds client mode parameters for the data exchange subsystem in SaaS mode.
//
Procedure AddClientParameters(Parameters) Export
 
EndProcedure
 
// Fills the structure with parameters that are required at the exit from the application in the client mode.
//
// Parameters:
//   Parameters - Structure - parameter structure.
//
Procedure AddClientParametersOnExit(Parameters) Export
 
 Parameters.Insert("StandaloneModeParameters", StandaloneModeParametersOnExit());
 
EndProcedure
 
// Fills the passed array with common modules that contain handlers for interfaces of incoming messages.
//
// Parameters:
//  HandlerArray - array.
//
Procedure RecordingIncomingMessageInterfaces(HandlerArray) Export
 
 HandlerArray.Add(MessagesDataExchangeAdministrationControlInterface);
 HandlerArray.Add(MessagesDataExchangeAdministrationManagementInterface);
 HandlerArray.Add(DataExchangeMessagesMonitoringInterface);
 HandlerArray.Add(DataExchangeMessagesManagementInterface);
 
EndProcedure
 
// Fills the passed array with common modules that contain handlers for interfaces of outgoing messages.
//
// Parameters:
//  HandlerArray - array.
//
Procedure RecordingOutgoingMessageInterfaces(HandlerArray) Export
 
 HandlerArray.Add(MessagesDataExchangeAdministrationControlInterface);
 HandlerArray.Add(MessagesDataExchangeAdministrationManagementInterface);
 HandlerArray.Add(DataExchangeMessagesMonitoringInterface);
 HandlerArray.Add(DataExchangeMessagesManagementInterface);
 
EndProcedure
 
// Infobase update handlers
 
// Adds update handlers that are required by the subsystem.
//
// Parameters:
//  Handlers - ValueTable - see description of the NewUpdateHandlerTable function
//                          in the InfobaseUpdate common module.
// 
Procedure OnAddUpdateHandlers(Handlers) Export
 
 If CommonUseCached.DataSeparationEnabled() Then
  
  Handler = Handlers.Add();
  Handler.SharedData = True;
  Handler.HandlerManagement = True;
  Handler.Version = "*";
  Handler.ExecutionMode = "Nonexclusive";
  Handler.Procedure = "DataExchangeSaaS.FillSeparatedDataHandlers";
  
  Handler = Handlers.Add();
  Handler.Version = "*";
  Handler.SharedData = True;
  Handler.ExclusiveMode = False;
  Handler.Procedure = "DataExchangeSaaS.LockEndpoints";
  
 EndIf;
 
EndProcedure
 
// Fills the separated data handler that depends on shared data changes.
//
// Parameters:
//   Handlers - ValueTable, Undefined - see description of the NewUpdateHandlerTable function 
//                                      in the InfobaseUpdate common module.
//                                      Undefined is passed in the event of direct call 
//                                      (without using the infobase version update functionality).
// 
Procedure FillSeparatedDataHandlers(Parameters = Undefined) Export
 
 If Parameters <> Undefined And HasPredefinedNodeEmptyCodes() Then
  Handlers = Parameters.SeparatedHandlers;
  Handler = Handlers.Add();
  Handler.Version = "*";
  Handler.ExecutionMode = "Nonexclusive";
  Handler.Procedure = "DataExchangeSaaS.SetPredefinedNodeCodes";
 EndIf;
 
EndProcedure
 
// Determines and sets a code and a predefined node name for each exchange plan that is used in the SaaS mode.
// The code is generated based on a separator value.
// The description is generated based on the application caption or, if the caption is empty, 
// is generated based on the current data area presentation from InformationRegister.DataAreas.
//
Procedure SetPredefinedNodeCodes() Export
 
 For Each ExchangePlan In Metadata.ExchangePlans Do
  
  If DataExchangeSaaSCached.IsDataSynchronizationExchangePlan(ExchangePlan.Name) Then
   
   ThisNode = ExchangePlans[ExchangePlan.Name].ThisNode();
   
   If IsBlankString(CommonUse.ObjectAttributeValue(ThisNode, "Code")) Then
    
    ThisNodeObject = ThisNode.GetObject();
    ThisNodeObject.Code = ExchangePlanNodeCodeInService(SaaSOperations.SessionSeparatorValue());
    ThisNodeObject.Description = TrimAll(GeneratePredefinedNodeDescription());
    ThisNodeObject.AdditionalProperties.Insert("Import");
    ThisNodeObject.Write();
    
   EndIf;
   
  EndIf;
  
 EndDo;
 
EndProcedure
 
// Locks all endpoints except the service manager endpoint.
//
Procedure LockEndpoints() Export
 
 QueryText =
 "SELECT
 | MessageExchange.Ref AS Ref
 |FROM
 | ExchangePlan.MessageExchange AS MessageExchange
 |WHERE
 | MessageExchange.Ref <> &ThisNode
 | AND MessageExchange.Ref <> &ServiceManagerEndpoint
 | AND Not MessageExchange.Locked";
 
 Query = New Query;
 Query.SetParameter("ThisNode", MessageExchangeInternal.ThisNode());
 Query.SetParameter("ServiceManagerEndpoint", SaaSOperationsCached.ServiceManagerEndpoint());
 Query.Text = QueryText;
 
 Selection = Query.Execute().Select();
 
 While Selection.Next() Do
  
  Endpoint = Selection.Ref.GetObject();
  Endpoint.Locked = True;
  Endpoint.Write();
  
 EndDo;
 
EndProcedure
 

// Checks whether all predefined node codes are filled.
//
Function HasPredefinedNodeEmptyCodes()
	
	For Each ExchangePlan In Metadata.ExchangePlans Do
		
		If DataExchangeSaaSCached.IsDataSynchronizationExchangePlan(ExchangePlan.Name) Then
			
			QueryText = "SELECT
			|	ExchangePlan.Code
			|FROM
			|	ExchangePlan.[ExchangePlanName] AS ExchangePlan
			|WHERE
			|	ExchangePlan.Code = """"";
			
			QueryText = StrReplace(QueryText, "[ExchangePlanName]", ExchangePlan.Name);
			Query = New Query;
			Query.Text = QueryText;
			Result = Query.Execute();
			
			If Not Result.IsEmpty() Then
				
				Return True;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Return False;
	
EndFunction
 
 
// For internal use.
//
Procedure OnSendDataToSlave(DataItem, ItemSend, Val InitialImageCreating, Recipient) Export
 
 If Recipient = Undefined Then
  
  
 ElsIf ItemSend = DataItemSend.Delete
  Or ItemSend = DataItemSend.Ignore Then
  
  // No overriding for standard processing
  
 ElsIf InitialImageCreating
  And CommonUseCached.DataSeparationEnabled()
  And StandaloneModeInternal.IsStandaloneWorkstationNode(Recipient.Ref)
  And CommonUse.IsSeparatedMetadataObject(DataItem.Metadata(),
   CommonUseCached.MainDataSeparator()) Then
  
  ItemSend = DataItemSend.Ignore;
  
  WriteXML(Recipient.AdditionalProperties.ExportedData, DataItem);
  
 EndIf;
 
EndProcedure
 
// For internal use.
//
Procedure OnSendDataToMaster(DataItem, ItemSend, Recipient) Export
 
 If ItemSend = DataItemSend.Ignore Then
 
 ElsIf StandaloneModeInternal.IsStandaloneWorkstation() Then
  
  If TypeOf(DataItem) = Type("ObjectDeletion") Then
   
   MetadataObject = DataItem.Ref.Metadata();
   
  Else
   
   MetadataObject = DataItem.Metadata();
   
  EndIf;
  
  If Not CommonUse.IsSeparatedMetadataObject(MetadataObject,
    CommonUseCached.MainDataSeparator()) Then
   
   ItemSend = DataItemSend.Ignore;
   
  EndIf;
  
 EndIf;
 
EndProcedure
 
// For internal use.
//
Procedure OnReceiveDataFromSlave(DataItem, ItemReceive, SendBack, From) Export
 
 If ItemReceive = DataItemReceive.Ignore Then
 
 ElsIf CommonUseCached.DataSeparationEnabled() Then
  
  If TypeOf(DataItem) = Type("ObjectDeletion") Then
   
   MetadataObject = DataItem.Ref.Metadata();
   
  Else
   
   MetadataObject = DataItem.Metadata();
   
  EndIf;
  
  If Not CommonUse.IsSeparatedMetadataObject(MetadataObject,
    CommonUseCached.MainDataSeparator()) Then
   
   ItemReceive = DataItemReceive.Ignore;
   
  EndIf;
  
 EndIf;
 
EndProcedure
 
 
// The flag clearing handler for the UseDataSynchronization constant.
//
//  Parameters:
//    Cancel - Boolean. The flag shows whether the synchronization disabling is canceled.
//             If its value is True, the synchronization is not disabled.
//
Procedure DataSynchronizationOnDisable(Cancel) Export
 
 Constants.UseOfflineModeSaaS.Set(False);
 Constants.UseDataSynchronizationSaaSWithLocalApplication.Set(False);
 Constants.UseDataSynchronizationSaaSWithWebApplication.Set(False);
 
EndProcedure
 
#EndRegion
 
#Region InternalProceduresAndFunctions
 
////////////////////////////////////////////////////////////////////////////////
// SL event handlers.
 
// Fills the structure with parameters that are required at the exit from the application in the client mode.
// These parameters are used in the following handlers:
// - BeforeExit,
// - OnExit.
//
// Parameters:
//   Parameters - Structure - parameter structure.
//
Procedure StandardSubsystemClientLogicParametersOnAddOnExit(Parameters) Export
 
 AddClientParametersOnExit(Parameters);
 
EndProcedure
 
// Fills a map of method names and their aliases for calling from a job queue.
//
// Parameters:
//  NameAndAliasMap - Map
//   Key   - method alias, for example: ClearDataArea.
//   Value - method name, for example: SaaSOperations.ClearDataArea.
//           You can set a value to Undefined if the name is identical to the alias.
//
Procedure OnDefineHandlerAliases(NameAndAliasMap) Export
 
 NameAndAliasMap.Insert("DataExchangeSaaS.SetDataChangeFlag"); 
 NameAndAliasMap.Insert("DataExchangeSaaS.ExecuteDataExchange");
 NameAndAliasMap.Insert("DataExchangeSaaS.ExecuteDataExchangeScenarioActionInFirstInfobase");
 NameAndAliasMap.Insert("DataExchangeSaaS.ExecuteDataExchangeScenarioActionInSecondInfobase");
 
EndProcedure
 
// Generates the list of infobase parameters.
//
// Parameters:
// ParameterTable             - ValueTable - parameter description table.
// For column content details - see the SaaSOperations.GetInfobaseParameterTable() function.
//
Procedure InfobaseParameterTableOnFill(Val ParameterTable) Export
 
 If CommonUse.SubsystemExists("StandardSubsystems.SaaSOperations") Then
  SaasOperationsModule = CommonUse.CommonModule("SaaSOperations");
  SaasOperationsModule.AddConstantToInfobaseParameterTable(ParameterTable, "AddressForRestoringAccountPassword");
 EndIf;
 
EndProcedure
 
// The "After getting recipients" handler.
// It is called when objects are registered in the exchange plan.
// Sets up a constant that shows whether data has been changed and sends 
// a message about changes with the current data area number to the service manager.
//
// Parameters:
// Data             - CatalogObject or DocumentObject - object for getting attribute values and other properties..
// Targets          - Array - array of ExchangePlanRef.<Name> - exchange plan nodes.
// ExchangePlanName - String.
//
Procedure AfterGetRecipients(Data, Targets, ExchangePlanName) Export
 
 If CommonUseCached.DataSeparationEnabled() Then
  
  If Data.DataExchange.Load Then
   Return;
  EndIf;
  
  If Targets.Count() > 0
   And DataExchangeSaaSCached.IsDataSynchronizationExchangePlan(ExchangePlanName)
   And Not GetFunctionalOption("DataChangesRecorded") Then
   
   If CommonUseCached.SessionWithoutSeparators() Then
    
    SetDataChangeFlag();
   Else
    
    Try
     BackgroundJobs.Execute("DataExchangeSaaS.SetDataChangeFlag",, "1");
    Except
     // Additional exception processing is not required.
     // The expected exception is duplicate job (jobs with identical keys are found).
    EndTry;
   EndIf;
   
  EndIf;
  
 Else
  
  // Exporting only application data changes that are separated with
  // the DataAreaMainData separator to SaaS
  If StandaloneModeInternal.IsStandaloneWorkstation()
   And Not CommonUse.IsSeparatedMetadataObject(Data.Metadata(),
    CommonUseCached.MainDataSeparator()) Then
   
   CommonUseClientServer.DeleteValueFromArray(Targets, StandaloneModeInternal.ApplicationInSaaS());
  EndIf;
  
 EndIf;
 
EndProcedure
 
// Fills the structure with arrays of supported versions of the subsystems that can have versions.
// Subsystem names are used as structure keys.
// Implements the InterfaceVersion web service functionality.
// This procedure must return actual version sets, therefore its body must be changed before using. See the example below.
//
// Parameters:
// SupportedVersionStructure - Structure: 
//  - Keys   - subsystem names. 
//  - Values - arrays of versions that are supported.
//
// Example:
//
// // FileTransferService
// VersionArray = New Array;
// VersionArray.Add("1.0.1.1"); 
// VersionArray.Add("1.0.2.1"); 
// SupportedVersionStructure.Insert("FileTransferService", VersionArray);
// // End FileTransferService
//
Procedure SupportedInterfaceVersionsOnDefine(Val SupportedVersionStructure) Export
 
 VersionArray = New Array;
 VersionArray.Add("2.0.1.6");
 VersionArray.Add("2.1.1.7");
 VersionArray.Add("2.1.2.1");
 VersionArray.Add("2.1.5.17");
 VersionArray.Add("2.1.6.1");
 SupportedVersionStructure.Insert("DataExchangeSaaS", VersionArray);
 
EndProcedure
 
// Gets the list of message handlers that are processed by the library subsystems.
// 
// Parameters:
//  Handlers - ValueTable - see the field structure in MessageExchange.NewMessageHandlerTable.
// 
Procedure MessageChannelHandlersOnDefine(Handlers) Export
 
 DataExchangeMessagesMessageHandler.GetMessageChannelHandlers(Handlers);
 
EndProcedure
 
// Adds client mode parameters for the data exchange subsystem in SaaS mode at the application startup.
//
Procedure OnAddStandardSubsystemClientLogicParametersOnStart(Parameters) Export
 
 SetPrivilegedMode(True);
 
 Parameters.Insert("IsStandaloneWorkstation",
  StandaloneModeInternal.IsStandaloneWorkstation());
 Parameters.Insert("SynchronizeDataWithWebApplicationOnStart",
  StandaloneModeInternal.SynchronizeDataWithWebApplicationOnStart());
 Parameters.Insert("SynchronizeDataWithWebApplicationOnExit",
  StandaloneModeInternal.SynchronizeDataWithWebApplicationOnExit());
 
EndProcedure
 
// Fills the structure of parameters that are required in the client mode.
//
// Parameters:
//   Parameters - Structure - parameter structure.
//
Procedure StandardSubsystemClientLogicParametersOnAdd(Parameters) Export
 
 AddClientParameters(Parameters);
 
EndProcedure
 
// Fills the array of types excluded from data import and export.
//
// Parameters:
//  Types - Array(Types).
//
Procedure OnFillExcludedFromImportExportTypes(Types) Export
 
 Types.Add(Metadata.Constants.ORMCachedValueRefreshDate);
 Types.Add(Metadata.Constants.DataChangesRecorded);
 Types.Add(Metadata.Constants.SubordinateDIBNodeSettings);
 Types.Add(Metadata.Constants.LastStandaloneWorkstationPrefix);
 Types.Add(Metadata.Constants.DistributedInfobaseNodePrefix);
 
 Types.Add(Metadata.InformationRegisters.CommonNodeDataChanges);
 Types.Add(Metadata.InformationRegisters.DataAreaExchangeTransportSettings);
 Types.Add(Metadata.InformationRegisters.CommonInfobaseNodeSettings);
 Types.Add(Metadata.InformationRegisters.DataExchangeResults);
 Types.Add(Metadata.InformationRegisters.SystemMessageExchangeSessions);
 Types.Add(Metadata.InformationRegisters.InfobaseObjectMappings);
 Types.Add(Metadata.InformationRegisters.DataAreaDataExchangeStates);
 
EndProcedure
 
// Deletes exchange message files that are not deleted because of system failures.
// These files are stored more than 24 hours ago (calculated based on the universal current date).
// The procedure analyzes the InformationRegister.DataAreaDataExchangeMessages.
//
Procedure OnDeleteObsoleteExchangeMessages() Export
 
 QueryText =
 "SELECT
 | DataExchangeMessages.MessageID AS MessageID,
 | DataExchangeMessages.MessageFileName AS FileName,
 | DataExchangeMessages.DataAreaAuxiliaryData AS DataAreaAuxiliaryData
 |FROM
 | InformationRegister.DataAreaDataExchangeMessages AS DataExchangeMessages
 |WHERE
 | DataExchangeMessages.MessageSendingDate < &UpdateDate
 |
 |ORDER BY
 | DataAreaAuxiliaryData";
 
 Query = New Query;
 Query.SetParameter("UpdateDate", CurrentUniversalDate() - 60 * 60 * 24);
 Query.Text = QueryText;
 
 Selection = Query.Execute().Select();
 
 SessionParameters.UseDataArea = True;
 DataAreaAuxiliaryData = Undefined;
 
 While Selection.Next() Do
  
  MessageFileFullName = CommonUseClientServer.GetFullFileName(DataExchangeCached.TempFileStorageDirectory(), Selection.FileName);
  
  MessageFile = New File(MessageFileFullName);
  
  If MessageFile.Exist() Then
   
   Try
    DeleteFiles(MessageFile.FullName);
   Except
    WriteLogEvent(NStr("en = 'Data exchange'", CommonUseClientServer.DefaultLanguageCode()),
     EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
    Continue;
   EndTry;
  EndIf;
  
  If DataAreaAuxiliaryData <> Selection.DataAreaAuxiliaryData Then
   
   DataAreaAuxiliaryData = Selection.DataAreaAuxiliaryData;
   SessionParameters.DataAreaValue = DataAreaAuxiliaryData;
   
  EndIf;
  
  // Deleting information about a message file from the storage
  RecordStructure = New Structure;
  RecordStructure.Insert("MessageID", String(Selection.MessageID));
  InformationRegisters.DataAreaDataExchangeMessages.DeleteRecord(RecordStructure);
  
 EndDo;
 
 SessionParameters.UseDataArea = False;
 
EndProcedure
 
// Gets a file from the storage by the file ID.
// If a file with the specified ID is not found raises an exception.
// If the file is found, returns its name and deletes the information about the file from the storage.
//
// Parameters:
// FileID   - UUID - file ID.
// FileName - String - file name.
//
Procedure OnReceiveFileFromStorage(Val FileID, FileName) Export
 
 QueryText =
 "SELECT
 | DataExchangeMessages.MessageFileName AS FileName
 |FROM
 | InformationRegister.DataAreaDataExchangeMessages AS DataExchangeMessages
 |WHERE
 | DataExchangeMessages.MessageID = &MessageID";
 
 Query = New Query;
 Query.SetParameter("MessageID", String(FileID));
 Query.Text = QueryText;
 
 QueryResult = Query.Execute();
 
 If QueryResult.IsEmpty() Then
  Details = NStr("en = 'The file with the %1 ID is not found.'");
  Raise StringFunctionsClientServer.SubstituteParametersInString(Details, String(FileID));
 EndIf;
 
 Selection = QueryResult.Select();
 Selection.Next();
 FileName = Selection.FileName;
 
 // Deleting information about a message file from the storage
 RecordStructure = New Structure;
 RecordStructure.Insert("MessageID", String(FileID));
 InformationRegisters.DataAreaDataExchangeMessages.DeleteRecord(RecordStructure);
 
EndProcedure
 
// Saves a file to the storage.
//
Procedure OnSaveFileToStorage(Val RecordStructure) Export
 
 InformationRegisters.DataAreaDataExchangeMessages.AddRecord(RecordStructure);
 
EndProcedure
 
// The procedure is used when getting metadata objects that are mandatory for the exchange plan.
// If the subsystem includes metadata objects that must be included in the
// exchange plan content, add these metadata objects to the Objects parameter.
//
// Parameters:
// Objects                         - Array - array of configuration metadata objects that must be included in the exchange plan content.
// DistributedInfobase (read only) - Boolean - flag that shows whether DIB exchange plan objects are retrieved.
//                                   If True, a list for a DIB is retrieved.
//                                   If False, a list for an infobase that is not a DIB is retrieved.
//
Procedure OnGetMandatoryExchangePlanObjects(Objects, Val DistributedInfobase) Export
 
EndProcedure
 
// The procedure is used when getting metadata objects that must not be included in the exchange plan content.
// If the subsystem contains metadata objects that should not be included in
// the exchange plan content, add these metadata objects to the Objects parameter.
//
// Parameters:
// Objects                         - Array - array of configuration metadata objects that should not be included 
//                                   in the exchange plan content.
// DistributedInfobase (read only) - Boolean - flag that shows whether DIB exchange plan objects are retrieved.
//                                   If True, a list for a DIB is retrieved.
//                                   If False, a list for an infobase that is not a DIB is retrieved.
//
Procedure ExchangePlanObjectsToExcludeOnGet(Objects, Val DistributedInfobase) Export
 
 If DistributedInfobase Then
  
  Objects.Add(Metadata.Constants.DataChangesRecorded);
  Objects.Add(Metadata.Constants.UseOfflineModeSaaS);
  Objects.Add(Metadata.Constants.UseDataSynchronizationSaaSWithLocalApplication);
  Objects.Add(Metadata.Constants.UseDataSynchronizationSaaSWithWebApplication);
  Objects.Add(Metadata.Constants.LastStandaloneWorkstationPrefix);
  Objects.Add(Metadata.Constants.SynchronizeDataWithWebApplicationOnExit);
  Objects.Add(Metadata.Constants.SynchronizeDataWithWebApplicationOnStart);
  
  Objects.Add(Metadata.InformationRegisters.DataAreasExchangeTransportSettings);
  Objects.Add(Metadata.InformationRegisters.DataAreaExchangeTransportSettings);
  Objects.Add(Metadata.InformationRegisters.SystemMessageExchangeSessions);
  Objects.Add(Metadata.InformationRegisters.DataAreaDataExchangeStates);
  Objects.Add(Metadata.InformationRegisters.DataAreasSuccessfulDataExchangeStates);
  Objects.Add(Metadata.InformationRegisters.DataAreaDataExchangeMessages);
  
 EndIf;
 
EndProcedure
 
// The procedure is used when retrieving metadata objects to be included in the
// exchange plan content but NOT included in the change record event subscriptions of this exchange plan.
// These metadata objects are used only when creating the initial image of
// a subordinate node and are not transferred during the exchange.
// If there are objects in the subsystem that are used only for creating the initial image
// of a subordinate node, add these metadata objects to the Objects parameter.
//
// Parameters:
// Objects - Array - metadata object array.
//
Procedure OnGetExchangePlanInitialImageObjects(Objects) Export
 
 Objects.Add(Metadata.Constants.AddressForRestoringAccountPassword);
 
EndProcedure
 
////////////////////////////////////////////////////////////////////////////////
// Export internal procedures and functions.
 
// Exports exchange data in an exchange between data areas.
//
// Parameters:
//  Cancel        - Boolean - cancellation flag. It is set to True if errors occur during the data export. 
//  Correspondent - ExchangePlanRef - exchange plan node where data is exported to.
// 
Procedure ExecuteDataExport(Cancel, Val Correspondent) Export
 
 DataExchangeServer.ExecuteInfobaseNodeExchangeAction(
  Cancel, Correspondent, Enums.ActionsOnExchange.DataExport);
EndProcedure
 
// Imports exchange data in an exchange between data areas.
//
// Parameters:
//  Cancel        - Boolean - cancellation flag. It is set to True if errors occur during the data import.
//  Correspondent - ExchangePlanRef - exchange plan node where data is imported to.
// 
Procedure ExecuteDataImport(Cancel, Val Correspondent) Export
 
 DataExchangeServer.ExecuteInfobaseNodeExchangeAction(
  Cancel, Correspondent, Enums.ActionsOnExchange.DataImport);
EndProcedure
 
 
// Initiates the data exchange between two infobases.
//
// Parameters:
// DataExchangeScenario - ValueTable.
//
Procedure ExecuteDataExchange(DataExchangeScenario) Export
 
 SetPrivilegedMode(True);
 
 // Resetting the data change accumulation flag
 Constants.DataChangesRecorded.Set(False);
 
 If DataExchangeScenario.Count() > 0 Then
  
  // Running the scenario
  ExecuteDataExchangeScenarioActionInFirstInfobase(0, DataExchangeScenario);
  
 EndIf;
 
EndProcedure
 
// Executes the exchange scenario action that is specified in a table row for the first infobase.
//
// Parameters:
// ScenarioRowIndex     - Number - index of the row from the DataExchangeScenario table.
// DataExchangeScenario - ValueTable.
//
Procedure ExecuteDataExchangeScenarioActionInFirstInfobase(ScenarioRowIndex, DataExchangeScenario) Export
 
 SetPrivilegedMode(True);
 
 If ScenarioRowIndex > DataExchangeScenario.Count() - 1 Then
  Return; // Ending script execution
 EndIf;
 
 ScenarioString = DataExchangeScenario[ScenarioRowIndex];
 
 If ScenarioString.InfobaseNumber = 1 Then
  
  InfobaseNode = FindInfobaseNode(ScenarioString.ExchangePlanName, ScenarioString.InfobaseNodeCode);
  
  If ScenarioString.CurrentAction = "DataImport" Then
   
   ExecuteDataImport(False, InfobaseNode);
   
  ElsIf ScenarioString.CurrentAction = "DataExport" Then
   
   ExecuteDataExport(False, InfobaseNode);
   
  Else
   Raise StringFunctionsClientServer.SubstituteParametersInString(
    NStr("en = 'Unknown action (%1) is detected during data exchange between data areas.'"),
    ScenarioString.CurrentAction);
  EndIf;
  
  // Going to the next scenario step
  ExecuteDataExchangeScenarioActionInFirstInfobase(ScenarioRowIndex + 1, DataExchangeScenario);
  
 ElsIf ScenarioString.InfobaseNumber = 2 Then
  
  InfobaseNode = FindInfobaseNode(ScenarioString.ExchangePlanName, ScenarioString.ThisNodeCode);
  
  CorrespondentVersions = CorrespondentVersions(InfobaseNode);
  
  If CorrespondentVersions.Find("2.0.1.6") <> Undefined Then
   
   WSProxy = DataExchangeSaaSCached.GetCorrespondentWSProxy_2_0_1_6(InfobaseNode);
   
   If WSProxy = Undefined Then
    
    // Going to the next scenario step
    ExecuteDataExchangeScenarioActionInFirstInfobase(ScenarioRowIndex + 1, DataExchangeScenario);
    Return;
   EndIf;
   
   WSProxy.ExecuteDataExchangeScriptActionInSecondInfobase(ScenarioRowIndex, XDTOSerializer.WriteXDTO(DataExchangeScenario));
   
  Else
   
   WSProxy = DataExchangeSaaSCached.GetCorrespondentWSProxy(InfobaseNode);
   
   If WSProxy = Undefined Then
    
    // Going to the next scenario step
    ExecuteDataExchangeScenarioActionInFirstInfobase(ScenarioRowIndex + 1, DataExchangeScenario);
    Return;
   EndIf;
   
   WSProxy.ExecuteDataExchangeScriptActionInSecondInfobase(ScenarioRowIndex, ValueToStringInternal(DataExchangeScenario));
   
  EndIf;
  
 EndIf;
 
EndProcedure
 
// Executes the exchange script action that is specified in a table row for the second infobase.
//
// Parameters:
// ScenarioRowIndex     - Number - index of the row from the DataExchangeScenario table.
// DataExchangeScenario - ValueTable.
//
Procedure ExecuteDataExchangeScenarioActionInSecondInfobase(ScenarioRowIndex, DataExchangeScenario) Export
 
 SetPrivilegedMode(True);
 
 ScenarioString = DataExchangeScenario[ScenarioRowIndex];
 
 InfobaseNode = FindInfobaseNode(ScenarioString.ExchangePlanName, ScenarioString.InfobaseNodeCode);
 
 If ScenarioString.ExecutionOrderNumber = 1 Then
  // Resetting the data change accumulation flag
  Constants.DataChangesRecorded.Set(False);
 EndIf;
 
 If ScenarioString.CurrentAction = "DataImport" Then
  
  ExecuteDataImport(False, InfobaseNode);
  
 ElsIf ScenarioString.CurrentAction = "DataExport" Then
  
  ExecuteDataExport(False, InfobaseNode);
  
 Else
  Raise StringFunctionsClientServer.SubstituteParametersInString(
   NStr("en = 'Unknown action (%1) is detected during data exchange between data areas.'"),
   ScenarioString.CurrentAction);
 EndIf;
 
 // Ending script execution
 If ScenarioRowIndex = DataExchangeScenario.Count() - 1 Then
  
  // Sending a message about the exchange completion to the managing application
  WSServiceProxy = DataExchangeSaaSCached.GetExchangeServiceWSProxy();
  WSServiceProxy.CommitExchange(XDTOSerializer.WriteXDTO(DataExchangeScenario));
  Return;
 EndIf;
 
 CorrespondentVersions = CorrespondentVersions(InfobaseNode);
 
 If CorrespondentVersions.Find("2.0.1.6") <> Undefined Then
  
  WSProxy = DataExchangeSaaSCached.GetCorrespondentWSProxy_2_0_1_6(InfobaseNode);
  
  If WSProxy <> Undefined Then
   
   WSProxy.ExecuteDataExchangeScriptActionInFirstInfobase(ScenarioRowIndex + 1, XDTOSerializer.WriteXDTO(DataExchangeScenario));
   
  EndIf;
  
 Else
  
  WSProxy = DataExchangeSaaSCached.GetCorrespondentWSProxy(InfobaseNode);
  
  If WSProxy <> Undefined Then
   
   WSProxy.ExecuteDataExchangeScriptActionInFirstInfobase(ScenarioRowIndex + 1, ValueToStringInternal(DataExchangeScenario));
   
  EndIf;
  
 EndIf;
 
EndProcedure
 
// Checks whether the exchange is locked to determine whether it is being executed. 
//
// Returns:
// Boolean. 
//
Function ExecutingDataExchange() Export
 
 SetPrivilegedMode(True);
 
 WSServiceProxy = DataExchangeSaaSCached.GetExchangeServiceWSProxy();
 
 Return WSServiceProxy.ExchangeBlockIsSet(CommonUse.SessionSeparatorValue());
 
EndFunction
 
// Returns a date of the last successful import of the current data area for all infobase nodes.
// Returns Undefined if no synchronization was executed.
//
// Returns:
// Date, Undefined. 
//
Function LastSuccessfulImportForAllInfobaseNodesDate() Export
 
 QueryText =
 "SELECT
 | MIN(SuccessfulDataExchangeStates.EndDate) AS EndDate
 |FROM
 | InformationRegister.DataAreasSuccessfulDataExchangeStates AS SuccessfulDataExchangeStates
 |WHERE
 | SuccessfulDataExchangeStates.ActionOnExchange = VALUE(Enum.ActionsOnExchange.DataImport)
 | AND SuccessfulDataExchangeStates.InfobaseNode.DataAreaMainData = &DataArea
 | AND SuccessfulDataExchangeStates.InfobaseNode.Code LIKE ""S%""";
 
 SetPrivilegedMode(True);
 
 Query = New Query;
 Query.Text = QueryText;
 Query.SetParameter("DataArea", SaaSOperations.SessionSeparatorValue());
 
 Selection = Query.Execute().Select();
 Selection.Next();
 
 Return ?(ValueIsFilled(Selection.EndDate), Selection.EndDate, Undefined);
 
EndFunction
 
// Returns synchronization statuses for the applications in SaaS mode.
//
Function DataSynchronizationStatuses() Export
 
 QueryText = "SELECT
 | DataExchangeStates.InfobaseNode AS InfobaseNode,
 | CASE
 |  WHEN DataExchangeStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.Completed)
 |   OR DataExchangeStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.CompletedWithWarnings)
 |   THEN 0
 |  ELSE 1
 | END AS Status
 |INTO DataExchangeStatesImport
 |FROM
 | InformationRegister.DataAreaDataExchangeStates AS DataExchangeStates
 |WHERE
 | DataExchangeStates.ActionOnExchange = VALUE(Enum.ActionsOnExchange.DataImport)
 |;
 |
 |////////////////////////////////////////////////////////////////////////////////
 |SELECT
 | DataExchangeStates.InfobaseNode AS InfobaseNode,
 | CASE
 |  WHEN DataExchangeStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.Completed)
 |   OR DataExchangeStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.CompletedWithWarnings)
 |   THEN 0
 |  ELSE 1
 | END AS Status
 |INTO DataExchangeStatesExport
 |FROM
 | InformationRegister.DataAreaDataExchangeStates AS DataExchangeStates
 |WHERE
 | DataExchangeStates.ActionOnExchange = VALUE(Enum.ActionsOnExchange.DataExport)
 |;
 |
 |////////////////////////////////////////////////////////////////////////////////
 |SELECT
 | DataExchangeResults.InfobaseNode AS InfobaseNode,
 | COUNT(DISTINCT DataExchangeResults.ProblematicObjects) AS Quantity
 |INTO DataExchangeErrors
 |FROM
 | InformationRegister.DataExchangeResults AS DataExchangeResults
 |WHERE
 | Not DataExchangeResults.Skipped
 |GROUP BY
 | DataExchangeResults.InfobaseNode
 |;
 |
 |////////////////////////////////////////////////////////////////////////////////
 |SELECT
 | DataExchangeStatesExport.InfobaseNode  AS Package,
 | ISNULL(DataExchangeErrors.Quantity, 0) AS IssueCount,
 | CASE
 |  WHEN DataExchangeStatesExport.Status = 1 OR DataExchangeStatesImport.Status = 1
 |   THEN 1 // Error
 |  ELSE CASE
 |    WHEN ISNULL(DataExchangeErrors.Quantity, 0) > 0
 |     THEN 2 // Exchange issues
 |    ELSE 3 // No errors and no exchange issues
 |   END
 | END AS Status
 |FROM
 | DataExchangeStatesExport AS DataExchangeStatesExport
 |  LEFT JOIN DataExchangeStatesImport AS DataExchangeStatesImport
 |  ON DataExchangeStatesExport.InfobaseNode = DataExchangeStatesImport.InfobaseNode
 |  LEFT JOIN DataExchangeErrors AS DataExchangeErrors
 |  ON DataExchangeStatesExport.InfobaseNode = DataExchangeErrors.InfobaseNode";
 
 Query = New Query;
 Query.Text = QueryText;
 
 Return Query.Execute().Unload();
EndFunction
 
// Generates an exchange plan node code for the specified data area.
//
// Parameters:
// DataAreaNumber - Number - separator value. 
//
// Returns:
// String - exchange plan node code for the specified data area. 
//
Function ExchangePlanNodeCodeInService(Val DataAreaNumber) Export
 
 If TypeOf(DataAreaNumber) <> Type("Number") Then
  Raise NStr("en = 'The type of parameter #1 is incorrect.'");
 EndIf;
 
 Result = "S0[DataAreaNumber]";
 
 Return StrReplace(Result, "[DataAreaNumber]", Format(DataAreaNumber, "ND=7; NLZ=; NG=0"));
 
EndFunction
 
// Generates the application name in SaaS mode.
//
Function GeneratePredefinedNodeDescription() Export
 
 ApplicationName = SaaSOperations.GetApplicationName();
 
 Return ?(IsBlankString(ApplicationName), NStr("en = 'Web application'"), ApplicationName);
EndFunction
 
// Gets the correspondent endpoint.
// Raises an exception if the correspondent endpoint is not specified.
//
// Parameters:
// Correspondent - ExchangePlanRef - correspondent for getting an endpoint.
//
// Returns:
// ExchangePlanRef.MessageExchange - correspondent endpoint.
//
Function CorrespondentEndpoint(Val Correspondent) Export
 
 QueryText =
 "SELECT
 | DataAreaExchangeTransportSettings.CorrespondentEndpoint AS CorrespondentEndpoint
 |FROM
 | InformationRegister.DataAreaExchangeTransportSettings AS DataAreaExchangeTransportSettings
 |WHERE
 | DataAreaExchangeTransportSettings.Correspondent = &Correspondent";
 
 Query = New Query;
 Query.SetParameter("Correspondent", Correspondent);
 Query.Text = QueryText;
 
 QueryResult = Query.Execute();
 
 If QueryResult.IsEmpty() Then
  MessageString = NStr("en = 'The correspondent endpoint for %1 is not specified.'");
  MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, String(Correspondent));
  Raise MessageString;
 EndIf;
 
 Selection = QueryResult.Select();
 Selection.Next();
 
 Return Selection.CorrespondentEndpoint;
EndFunction
 
Function ExchangeMessageDirectoryName(Val Code1, Val Code2)
 
 Return StringFunctionsClientServer.SubstituteParametersInString("Exchange %1-%2", Code1, Code2);
 
EndFunction
 
 
// Sends a message.
//
// Parameters:
// Message - XDTODataObject - message.
//
Function SendMessage(Val Message) Export
 
 Message.Body.Zone = CommonUse.SessionSeparatorValue();
 Message.Body.SessionId = InformationRegisters.SystemMessageExchangeSessions.NewSession();
 
 MessagesSaaS.SendMessage(Message, SaaSOperationsCached.ServiceManagerEndpoint(), True);
 
 Return Message.Body.SessionId;
EndFunction
 
 
// For internal use.
//
Procedure CreateExchangeSettings(
   Val ExchangePlanName,
   Val CorrespondentCode,
   Val CorrespondentDescription,
   Val CorrespondentEndpoint,
   Val Settings,
   Correspondent = Undefined,
   IsCorrespondent = False,
   SLCompatibilityMode_2_0_0 = False,
   Val Prefix = ""
 ) Export
 
 BeginTransaction();
 Try
  
  ThisNodeCode = CommonUse.ObjectAttributeValue(ExchangePlans[ExchangePlanName].ThisNode(), "Code");
  
  // Checking whether code is specified for the current node
  If IsBlankString(ThisNodeCode) Then
   
   // The node code is set in the infobase update handler
   MessageString = NStr("en = 'The code of the %1 predefined exchange plan node is not specified.'");
   MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, ExchangePlanName);
   Raise MessageString;
  EndIf;
  
  // Checking prefix of the current infobase
  If IsBlankString(GetFunctionalOption("InfobasePrefix")) Then
   
   If IsBlankString(Prefix) Then
    Raise NStr("en = 'The application prefix is not specified in the Service Manager.'");
   EndIf;
   
   DataExchangeServer.SetInfobasePrefix(Prefix);
   
  EndIf;
  
  // Creating or updating a correspondent node
  Correspondent = ExchangePlans[ExchangePlanName].FindByCode(CorrespondentCode);
  
  CheckCode = False;
  
  If Correspondent.IsEmpty() Then
   CorrespondentObject = ExchangePlans[ExchangePlanName].CreateNode();
   CorrespondentObject.Code = CorrespondentCode;
   CheckCode = True;
  Else
   CorrespondentObject = Correspondent.GetObject();
  EndIf;
  
  CorrespondentObject.Description = CorrespondentDescription;
  
  DataExchangeEvents.SetNodeFilterValues(CorrespondentObject, Settings);
  
  CorrespondentObject.SentNo     = 0;
  CorrespondentObject.ReceivedNo = 0;
  
  CorrespondentObject.RegisterChanges = True;
  
  CorrespondentObject.AdditionalProperties.Insert("Import");
  CorrespondentObject.Write();
  
  Correspondent = CorrespondentObject.Ref;
  
  ActualCorrespondentCode = CommonUse.ObjectAttributeValue(Correspondent, "Code");
  
  If CheckCode And CorrespondentCode <> ActualCorrespondentCode Then
   
   MessageString = NStr("en = 'An error occurred while setting a code for the correspondent node.
    |Assigned value: %1.
    |Actual value: %2.'");
   MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, CorrespondentCode, ActualCorrespondentCode);
   Raise MessageString;
  EndIf;
  
  // Getting exchange message transport settings
  If IsCorrespondent Then
   RelativeInformationExchangeDirectory = ExchangeMessageDirectoryName(CorrespondentCode, ThisNodeCode);
  Else
   RelativeInformationExchangeDirectory = ExchangeMessageDirectoryName(ThisNodeCode, CorrespondentCode);
  EndIf;
  
  TransportSettings = InformationRegisters.DataAreasExchangeTransportSettings.TransportSettings(CorrespondentEndpoint);
  
  If TransportSettings.DefaultExchangeMessageTransportKind = Enums.ExchangeMessageTransportKinds.FILE Then
   
   // Performing exchange using a network directory
   
   FILECommonInformationExchangeDirectory = TrimAll(TransportSettings.FILEDataExchangeDirectory);
   
   If IsBlankString(FILECommonInformationExchangeDirectory) Then
    
    MessageString = NStr("en = 'The data exchange directory is not specified for the %1 endpoint.'");
    MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, String(CorrespondentEndpoint));
    Raise MessageString;
   EndIf;
   
   CommonDirectory = New File(FILECommonInformationExchangeDirectory);
   
   If Not CommonDirectory.Exist() Then
    
    MessageString = NStr("en = 'The exchange directory %1 does not exist.'");
    MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, FILECommonInformationExchangeDirectory);
    Raise MessageString;
   EndIf;
   
   If Not SLCompatibilityMode_2_0_0 Then
    
    FILEAbsoluteDataExchangeDirectory = CommonUseClientServer.GetFullFileName(
     FILECommonInformationExchangeDirectory,
     RelativeInformationExchangeDirectory
    );
    
    // Creating the message exchange directory
    AbsoluteDirectory = New File(FILEAbsoluteDataExchangeDirectory);
    If Not AbsoluteDirectory.Exist() Then
     CreateDirectory(AbsoluteDirectory.FullName);
    EndIf;
    
    // Saving exchange message transfer settings for the current data area
    RecordStructure = New Structure;
    RecordStructure.Insert("Correspondent", Correspondent);
    RecordStructure.Insert("CorrespondentEndpoint", CorrespondentEndpoint);
    RecordStructure.Insert("DataExchangeDirectory", RelativeInformationExchangeDirectory);
    
    InformationRegisters.DataAreaExchangeTransportSettings.UpdateRecord(RecordStructure);
   EndIf;
   
  ElsIf TransportSettings.DefaultExchangeMessageTransportKind = Enums.ExchangeMessageTransportKinds.FTP Then
   
   // Exchange using the FTP server
   
   FTPSettings = DataExchangeServer.FTPConnectionSettings();
   FTPSettings.Server            = TransportSettings.FTPServer;
   FTPSettings.Port              = TransportSettings.FTPConnectionPort;
   FTPSettings.UserName          = TransportSettings.FTPConnectionUser;
   FTPSettings.UserPassword      = TransportSettings.FTPConnectionPassword;
   FTPSettings.PassiveConnection = TransportSettings.FTPConnectionPassiveConnection;
   
   FTPConnection = DataExchangeServer.FTPConnection(FTPSettings);
   
   AbsoluteDataExchangeDirectory = CommonUseClientServer.GetFullFileName(
    TransportSettings.FTPPath,
    RelativeInformationExchangeDirectory
   );
   If Not DataExchangeServer.FTPDirectoryExists(AbsoluteDataExchangeDirectory, RelativeInformationExchangeDirectory, FTPConnection) Then
    FTPConnection.CreateDirectory(AbsoluteDataExchangeDirectory);
   EndIf;
   
   // Saving exchange message transfer settings for the current data area
   RecordStructure = New Structure;
   RecordStructure.Insert("Correspondent",         Correspondent);
   RecordStructure.Insert("CorrespondentEndpoint", CorrespondentEndpoint);
   RecordStructure.Insert("DataExchangeDirectory", RelativeInformationExchangeDirectory);
   
   InformationRegisters.DataAreaExchangeTransportSettings.UpdateRecord(RecordStructure);
   
  Else
   Raise StringFunctionsClientServer.SubstituteParametersInString(
    NStr("en = 'The ""%1"" exchange messages transport kind for the %2 endpoint is not supported.'"),
    String(TransportSettings.DefaultExchangeMessageTransportKind),
    String(CorrespondentEndpoint)
    );
  EndIf;
  
  CommitTransaction();
 Except
  RollbackTransaction();
  Raise;
 EndTry;
 
EndProcedure
 
// Updates settings and sets default values for a node.
//
Procedure UpdateExchangeSettings(
  Val Correspondent,
  Val NodeDefaultValues
 ) Export
 
 CorrespondentObject = Correspondent.GetObject();
 
 // Setting default values 
 DataExchangeEvents.SetNodeDefaultValues(CorrespondentObject, NodeDefaultValues);
 
 CorrespondentObject.AdditionalProperties.Insert("GettingExchangeMessage");
 CorrespondentObject.Write();
 
EndProcedure
 
// Deletes synchronization settings.
Function DeleteExchangeSettings(ExchangePlanName, CorrespondentDataArea, Session = Undefined) Export
 
 SetPrivilegedMode(True);
 
 BeginTransaction();
 Try
  
  // Sending message to the Service Manager
  Message = MessagesSaaS.NewMessage(
   MessagesDataExchangeAdministrationManagementInterface.DisableDataSynchronizationMessage());
  Message.Body.CorrespondentZone = CorrespondentDataArea;
  Message.Body.ExchangePlan = ExchangePlanName;
  Session = SendMessage(Message);
  
  CommitTransaction();
  
 Except
  
  RollbackTransaction();
  WriteLogEvent(EventLogMessageTextDataSynchronizationSetup(),
   EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
  Return False;
  
 EndTry;
 
 MessagesSaaS.DeliverQuickMessages();
 
 Return True;
 
EndFunction
 
 
// Saves session data and sets the CompletedSuccessfully flag value to True.
//
Procedure SaveSessionData(Val Message, Val Presentation = "") Export
 
 If Not IsBlankString(Presentation) Then
  Presentation = StringFunctionsClientServer.SubstituteParametersInString(NStr("en = ' {%1}'"), Presentation);
 EndIf;
 
 MessageString = NStr("en = 'Message exchange system session with ID %1 is completed. %2'",
  CommonUseClientServer.DefaultLanguageCode());
 MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString,
  String(Message.Body.SessionId), Presentation);
 WriteLogEvent(EventLogMessageTextSystemMessageExchangeSessions(),
  EventLogLevel.Information,,, MessageString);
 InformationRegisters.SystemMessageExchangeSessions.SaveSessionData(Message.Body.SessionId, Message.Body.Data);
 
EndProcedure
 
// Sets the CompletedSuccessfully flag value to True for a session that is passed to the procedure.
//
Procedure CommitSuccessfulSession(Val Message, Val Presentation = "") Export
 
 If Not IsBlankString(Presentation) Then
  Presentation = StringFunctionsClientServer.SubstituteParametersInString(NStr("en = ' {%1}'"), Presentation);
 EndIf;
 
 MessageString = NStr("en = 'Message exchange system session with ID %1 is completed. %2'",
  CommonUseClientServer.DefaultLanguageCode());
 MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString,
  String(Message.Body.SessionId), Presentation);
 WriteLogEvent(EventLogMessageTextSystemMessageExchangeSessions(),
  EventLogLevel.Information,,, MessageString);
 InformationRegisters.SystemMessageExchangeSessions.CommitSuccessfulSession(Message.Body.SessionId);
 
EndProcedure
 
// Sets the CompletedWithError flag value to False for a session that is passed to the procedure.
//
Procedure CommitUnsuccessfulSession(Val Message, Val Presentation = "") Export
 
 If Not IsBlankString(Presentation) Then
  Presentation = StringFunctionsClientServer.SubstituteParametersInString(NStr("en = ' {%1}'"), Presentation);
 EndIf;
 
 MessageString = NStr("en = 'An error occurred during the message exchange system session with ID %1. %2 
  |Correspondent error details: %3'", CommonUseClientServer.DefaultLanguageCode());
 MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString,
  String(Message.Body.SessionId), Presentation, Message.Body.ErrorDescription);
 WriteLogEvent(EventLogMessageTextSystemMessageExchangeSessions(),
  EventLogLevel.Error,,, MessageString);
 InformationRegisters.SystemMessageExchangeSessions.CommitUnsuccessfulSession(Message.Body.SessionId);
 
EndProcedure
 
 
// Logs on to a data area and executes the exchange scenario action that is specified for the first infobase. 
// The action is specified in a value table row, the row index is passed to the procedure.
//
// Parameters:
// ScenarioRowIndex     - Number - index of the row from the DataExchangeScenario table.
// DataExchangeScenario - ValueTable.
//
Procedure ExecuteDataExchangeScenarioActionInFirstInfobaseFromSharedSession(
                  ScenarioRowIndex,
                  DataExchangeScenario,
                  DataArea
 ) Export
 
 SetPrivilegedMode(True);
 CommonUse.SetSessionSeparation(True, DataArea);
 SetPrivilegedMode(False);
 
 ExecuteDataExchangeScenarioActionInFirstInfobase(ScenarioRowIndex, DataExchangeScenario);
 
 SetPrivilegedMode(True);
 CommonUse.SetSessionSeparation(False);
 SetPrivilegedMode(False);
 
EndProcedure
 
// Logs on to a data area and executes the exchange scenario action that is specified for the second infobase. 
// The action is specified in a value table row, the row index is passed to the procedure.
//
// Parameters:
// ScenarioRowIndex     - Number - index of the row from the DataExchangeScenario table.
// DataExchangeScenario - ValueTable.
//
Procedure ExecuteDataExchangeScenarioActionInSecondInfobaseFromSharedSession(
                  ScenarioRowIndex,
                  DataExchangeScenario,
                  DataArea
 ) Export
 
 SetPrivilegedMode(True);
 CommonUse.SetSessionSeparation(True, DataArea);
 SetPrivilegedMode(False);
 
 ExecuteDataExchangeScenarioActionInSecondInfobase(ScenarioRowIndex, DataExchangeScenario);
 
 SetPrivilegedMode(True);
 CommonUse.SetSessionSeparation(False);
 SetPrivilegedMode(False);
 
EndProcedure
 
// Returns the minimum required version of the platform.
//
Function RequiredPlatformVersion() Export
 
 PlatformVersion = "";
 PlatformVersion = DataExchangeSaaSOverridable.RequiredApplicationVersion();
 DataExchangeSaaSOverridable.RequiredApplicationVersionOnDefine(PlatformVersion);
 If ValueIsFilled(PlatformVersion) Then
  Return PlatformVersion;
 EndIf;
 
 SystemInfo = New SystemInfo;
 PlatformVersion = StringFunctionsClientServer.SplitStringIntoSubstringArray(SystemInfo.AppVersion, ".");
 
 // Deleting additional number (last number) from the version number
 PlatformVersion.Delete(3);
 Return StringFunctionsClientServer.StringFromSubstringArray(PlatformVersion, ".");
 
EndFunction
 
// The data synchronization setup event for the event log.
//
Function EventLogMessageTextDataSynchronizationSetup() Export
 
 Return NStr("en = 'Data exchange in SaaS mode.Data synchronization setup'",
  CommonUseClientServer.DefaultLanguageCode());
 
EndFunction
 
// The data synchronization monitor event for the event log.
//
Function EventLogMessageTextDataSynchronizationMonitor() Export
 
 Return NStr("en = 'Data exchange in SaaS mode.Data synchronization monitor'",
  CommonUseClientServer.DefaultLanguageCode());
 
EndFunction
 
// The data synchronization event for the event log.
//
Function DataSyncronizationLogEvent() Export
 
 Return NStr("en = 'Data exchange in SaaS mode.Data synchronization'",
  CommonUseClientServer.DefaultLanguageCode());
 
EndFunction
 
Function EventLogMessageTextSystemMessageExchangeSessions()
 
 Return NStr("en = 'Data exchange in SaaS mode.System message exchange sessions'",
  CommonUseClientServer.DefaultLanguageCode());
 
EndFunction
 
////////////////////////////////////////////////////////////////////////////////
// Data exchange monitor procedures and functions.
 
// For internal use.
// 
Function DataExchangeMonitorTable(Val MethodExchangePlans, Val ExchangePlanAdditionalProperties = "", Val OnlyFailedExchanges = False) Export
 
 QueryText = "SELECT
 | DataExchangeStates.InfobaseNode AS InfobaseNode,
 | DataExchangeStates.EndDate AS EndDate,
 | CASE
 |  WHEN DataExchangeStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.Completed)
 |   OR DataExchangeStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.CompletedWithWarnings)
 |   THEN 0
 |  ELSE 1
 | END AS ExchangeExecutionResult
 |INTO DataExchangeStatesImport
 |FROM
 | InformationRegister.DataAreaDataExchangeStates AS DataExchangeStates
 |WHERE
 | DataExchangeStates.ActionOnExchange = VALUE(Enum.ActionsOnExchange.DataImport)
 |;
 |
 |////////////////////////////////////////////////////////////////////////////////
 |SELECT
 | DataExchangeStates.InfobaseNode AS InfobaseNode,
 | DataExchangeStates.EndDate AS EndDate,
 | CASE
 |  WHEN DataExchangeStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.Completed)
 |   OR DataExchangeStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.CompletedWithWarnings)
 |   THEN 0
 |  ELSE 1
 | END AS ExchangeExecutionResult
 |INTO DataExchangeStatesExport
 |FROM
 | InformationRegister.DataAreaDataExchangeStates AS DataExchangeStates
 |WHERE
 | DataExchangeStates.ActionOnExchange = VALUE(Enum.ActionsOnExchange.DataExport)
 |;
 |
 |////////////////////////////////////////////////////////////////////////////////
 |SELECT
 | SuccessfulDataExchangeStates.InfobaseNode AS InfobaseNode,
 | SuccessfulDataExchangeStates.EndDate AS EndDate
 |INTO SuccessfulDataExchangeStatesImport
 |FROM
 | InformationRegister.DataAreasSuccessfulDataExchangeStates AS SuccessfulDataExchangeStates
 |WHERE
 | SuccessfulDataExchangeStates.ActionOnExchange = VALUE(Enum.ActionsOnExchange.DataImport)
 |;
 |
 |////////////////////////////////////////////////////////////////////////////////
 |SELECT
 | SuccessfulDataExchangeStates.InfobaseNode AS InfobaseNode,
 | SuccessfulDataExchangeStates.EndDate AS EndDate
 |INTO SuccessfulDataExchangeStatesExport
 |FROM
 | InformationRegister.DataAreasSuccessfulDataExchangeStates AS SuccessfulDataExchangeStates
 |WHERE
 | SuccessfulDataExchangeStates.ActionOnExchange = VALUE(Enum.ActionsOnExchange.DataExport)
 |;
 |
 |////////////////////////////////////////////////////////////////////////////////
 |SELECT
 | ExchangePlans.ExchangePlanName AS ExchangePlanName,
 | ExchangePlans.InfobaseNode AS InfobaseNode,
 | ExchangePlans.InfobaseNode.DataAreaMainData AS DataArea,
 |
 | [ExchangePlanAdditionalProperties]
 |
 | ISNULL(DataExchangeStatesExport.ExchangeExecutionResult, 0) AS LastDataExportResult,
 | ISNULL(DataExchangeStatesImport.ExchangeExecutionResult, 0) AS LastDataImportResult,
 | DataExchangeStatesImport.EndDate AS LastImportDate,
 | DataExchangeStatesExport.EndDate AS LastExportDate,
 | SuccessfulDataExchangeStatesImport.EndDate AS LastSuccessfulImportDate,
 | SuccessfulDataExchangeStatesExport.EndDate AS LastSuccessfulExportDate
 |FROM
 | ConfigurationExchangePlans AS ExchangePlans
 |  LEFT JOIN DataExchangeStatesImport AS DataExchangeStatesImport
 |  ON ExchangePlans.InfobaseNode = DataExchangeStatesImport.InfobaseNode
 |  LEFT JOIN DataExchangeStatesExport AS DataExchangeStatesExport
 |  ON ExchangePlans.InfobaseNode = DataExchangeStatesExport.InfobaseNode
 |  LEFT JOIN SuccessfulDataExchangeStatesImport AS SuccessfulDataExchangeStatesImport
 |  ON ExchangePlans.InfobaseNode = SuccessfulDataExchangeStatesImport.InfobaseNode
 |  LEFT JOIN SuccessfulDataExchangeStatesExport AS SuccessfulDataExchangeStatesExport
 |  ON ExchangePlans.InfobaseNode = SuccessfulDataExchangeStatesExport.InfobaseNode
 |
 |[Filter]
 |
 |ORDER BY
 | ExchangePlans.ExchangePlanName,
 | ExchangePlans.Description";
 
 SetPrivilegedMode(True);
 
 TempTablesManager = New TempTablesManager;
 
 GetExchangePlanTableForMonitor(TempTablesManager, MethodExchangePlans, ExchangePlanAdditionalProperties);
 
 QueryText = StrReplace(QueryText, "[ExchangePlanAdditionalProperties]",
  GetExchangePlanAdditionalPropertiesString(ExchangePlanAdditionalProperties));
 
 If OnlyFailedExchanges Then
  Filter = "
   | WHERE ISNULL(DataExchangeStatesExport.ExchangeExecutionResult, 0) <> 0 OR ISNULL(DataExchangeStatesImport.ExchangeExecutionResult, 0) <> 0"
  ;
 Else
  Filter = "";
 EndIf;
 
 QueryText = StrReplace(QueryText, "[Filter]", Filter);
 
 Query = New Query;
 Query.Text = QueryText;
 Query.TempTablesManager = TempTablesManager;
 
 SynchronizationSettings = Query.Execute().Unload();
 SynchronizationSettings.Columns.Add("LastImportDatePresentation");
 SynchronizationSettings.Columns.Add("LastExportDatePresentation");
 SynchronizationSettings.Columns.Add("LastSuccessfulImportDatePresentation");
 SynchronizationSettings.Columns.Add("LastSuccessfulExportDatePresentation");
 
 For Each SynchronizationSettingsItem In SynchronizationSettings Do
  
  SynchronizationSettingsItem.LastImportDatePresentation           = DataExchangeServer.RelativeSynchronizationDate(SynchronizationSettingsItem.LastImportDate);
  SynchronizationSettingsItem.LastExportDatePresentation           = DataExchangeServer.RelativeSynchronizationDate(SynchronizationSettingsItem.LastExportDate);
  SynchronizationSettingsItem.LastSuccessfulImportDatePresentation = DataExchangeServer.RelativeSynchronizationDate(SynchronizationSettingsItem.LastSuccessfulImportDate);
  SynchronizationSettingsItem.LastSuccessfulExportDatePresentation = DataExchangeServer.RelativeSynchronizationDate(SynchronizationSettingsItem.LastSuccessfulExportDate);
  
 EndDo;
 
 Return SynchronizationSettings;
EndFunction
 
// For internal use.
// 
Function GetExchangePlanAdditionalPropertiesString(Val PropertiesString)
 
 Result = "";
 
 Template = "ExchangePlans.[PropertyString] AS [PropertyString]";
 
 ArrayProperties = StringFunctionsClientServer.SplitStringIntoSubstringArray(PropertiesString);
 
 For Each PropertyString In ArrayProperties Do
  
  PropertyStringInQuery = StrReplace(Template, "[PropertyString]", PropertyString);
  
  Result = Result + PropertyStringInQuery + ", ";
  
 EndDo;
 
 Return Result;
EndFunction
 
// For internal use.
// 
Procedure GetExchangePlanTableForMonitor(Val TempTablesManager, Val MethodExchangePlans, Val ExchangePlanAdditionalProperties)
 
 ExchangePlanAdditionalPropertiesString = ?(IsBlankString(ExchangePlanAdditionalProperties), "", ExchangePlanAdditionalProperties + ", ");
 
 Query = New Query;
 
 QueryPattern = "
 |
 |UNION ALL
 |
 |//////////////////////////////////////////////////////// {[ExchangePlanName]}
 |SELECT
 |
 | [ExchangePlanAdditionalProperties]
 |
 | Ref                       AS InfobaseNode,
 | Description               AS Description,
 | ""[ExchangePlanSynonym]"" AS ExchangePlanName
 |FROM
 | ExchangePlan.[ExchangePlanName]
 |WHERE
 | RegisterChanges
 | AND Not DeletionMark
 |";
 
 QueryText = "";
 
 If MethodExchangePlans.Count() > 0 Then
  
  For Each ExchangePlanName In MethodExchangePlans Do
   
   ExchangePlanQueryText = StrReplace(QueryPattern,          "[ExchangePlanName]",    ExchangePlanName);
   ExchangePlanQueryText = StrReplace(ExchangePlanQueryText, "[ExchangePlanSynonym]", Metadata.ExchangePlans[ExchangePlanName].Synonym);
   ExchangePlanQueryText = StrReplace(ExchangePlanQueryText, "[ExchangePlanAdditionalProperties]", ExchangePlanAdditionalPropertiesString);
   
   // Deleting the literal that is used to perform table union
   If IsBlankString(QueryText) Then
    
    ExchangePlanQueryText = StrReplace(ExchangePlanQueryText, "UNION ALL", "");
    
   EndIf;
   
   QueryText = QueryText + ExchangePlanQueryText;
   
  EndDo;
  
 Else
  
  AdditionalPropertiesWithoutDataSourceString = "";
  
  If Not IsBlankString(ExchangePlanAdditionalProperties) Then
   
   AdditionalProperties = StringFunctionsClientServer.SplitStringIntoSubstringArray(ExchangePlanAdditionalProperties);
   
   AdditionalPropertiesWithoutDataSource = New Array;
   
   For Each Property In AdditionalProperties Do
    
    AdditionalPropertiesWithoutDataSource.Add(StrReplace("Undefined AS [Property]", "[Property]", Property));
    
   EndDo;
   
   AdditionalPropertiesWithoutDataSourceString = StringFunctionsClientServer.StringFromSubstringArray(AdditionalPropertiesWithoutDataSource) + ", ";
   
  EndIf;
  
  QueryText = "
  |SELECT
  |
  | [AdditionalPropertiesWithoutDataSourceString]
  |
  | Undefined AS InfobaseNode,
  | Undefined AS Description,
  | Undefined AS ExchangePlanName
  |";
  
  QueryText = StrReplace(QueryText, "{AdditionalPropertiesWithoutDataSourceString}", AdditionalPropertiesWithoutDataSourceString);
  
 EndIf;
 
 QueryTextResult = "
 |//////////////////////////////////////////////////////// {ConfigurationExchangePlans}
 |SELECT
 |
 | [ExchangePlanAdditionalProperties]
 |
 | InfobaseNode,
 | Description,
 | ExchangePlanName
 |INTO ConfigurationExchangePlans
 |FROM
 | (
 | [QueryText]
 | ) AS NestedQuery
 |;
 |";
 
 QueryTextResult = StrReplace(QueryTextResult, "[QueryText]", QueryText);
 QueryTextResult = StrReplace(QueryTextResult, "[ExchangePlanAdditionalProperties]", ExchangePlanAdditionalPropertiesString);
 
 Query.Text = QueryTextResult;
 Query.TempTablesManager = TempTablesManager;
 Query.Execute();
 
EndProcedure
 
////////////////////////////////////////////////////////////////////////////////
// Local internal procedures and functions.
 
Function FindInfobaseNode(Val ExchangePlanName, Val NodeCode)
 
 NodeCodeWithPrefix = ExchangePlanNodeCodeInService(Number(NodeCode));
 
 // Searching for node by code in S00000123 format
 Result = DataExchangeCached.FindExchangePlanNodeByCode(ExchangePlanName, NodeCodeWithPrefix);
 
 If Result = Undefined Then
  
  // Searching for node by code in old 0000123 format
  Result = DataExchangeCached.FindExchangePlanNodeByCode(ExchangePlanName, NodeCode);
  
 EndIf;
 
 If Result = Undefined Then
  Message = NStr("en = 'The exchange plan node named %1 with the %2 or %3 node code is not found.'");
  Message = StringFunctionsClientServer.SubstituteParametersInString(Message, ExchangePlanName, NodeCode, NodeCodeWithPrefix);
  Raise Message;
 EndIf;
 
 Return Result;
EndFunction
 
Function CorrespondentVersions(Val InfobaseNode)
 
 SettingsStructure = InformationRegisters.DataAreaExchangeTransportSettings.TransportSettingsWS(InfobaseNode);
 
 ConnectionParameters = New Structure;
 ConnectionParameters.Insert("URL",      SettingsStructure.WSURL);
 ConnectionParameters.Insert("UserName", SettingsStructure.WSUserName);
 ConnectionParameters.Insert("Password", SettingsStructure.WSPassword);
 
 Return CommonUse.GetInterfaceVersions(ConnectionParameters, "DataExchangeSaaS");
EndFunction
 
// Returns DataExchangeSaaS subsystem parameters that are required at user exit.
//
// Returns:
// Structure - parameters.
//
Function StandaloneModeParametersOnExit()
 
 ParametersOnExit = New Structure;
 
 If StandaloneModeInternal.IsStandaloneWorkstation() Then
  
  DataExchangeExecutionFormParameters = StandaloneModeInternal.DataExchangeExecutionFormParameters();
  SynchronizationWithServiceNotExecuteLongTime = StandaloneModeInternal.SynchronizationWithServiceNotExecuteLongTime();
  
 Else
  
  DataExchangeExecutionFormParameters = New Structure;
  SynchronizationWithServiceNotExecuteLongTime = False;
  
 EndIf;
 
 ParametersOnExit.Insert("DataExchangeExecutionFormParameters", DataExchangeExecutionFormParameters);
 ParametersOnExit.Insert("SynchronizationWithServiceNotExecuteLongTime", SynchronizationWithServiceNotExecuteLongTime);
 
 Return ParametersOnExit;
EndFunction
 
Procedure BeforeWriteCommonData(Object, Cancel)
 
 If Object.DataExchange.Load Then
  Return;
 EndIf;
 
 ReadOnly = False;
 StandaloneModeInternal.DefineDataChangeCapability(Object.Metadata(), ReadOnly);
 
 If ReadOnly Then
  ErrorString = NStr("en = 'Modification of shared data (%1) that is imported from the application is prohibited in standalone workstation mode.
  |Contact the application administrator.'");
  ErrorString = StringFunctionsClientServer.SubstituteParametersInString(ErrorString, String(Object));
  Raise ErrorString;
 EndIf;
 
EndProcedure
 
////////////////////////////////////////////////////////////////////////////////
// Event subscription handlers.
 
Procedure DisableAutomaticDataSynchronizationWithWebApplicationOnWrite(Source, Cancel, Replacing) Export
 
 DisableAutomaticSynchronization = False;
 
 For Each SetRow In Source Do
  
  If SetRow.DefaultExchangeMessageTransportKind = Enums.ExchangeMessageTransportKinds.WS
   And Not SetRow.WSRememberPassword Then
   
   DisableAutomaticSynchronization = True;
   Break;
   
  EndIf;
  
 EndDo;
 
 If DisableAutomaticSynchronization Then
  
  StandaloneModeInternal.DisableAutoDataSyncronizationWithWebApplication();
  
 EndIf;
 
EndProcedure
 
////////////////////////////////////////////////////////////////////////////////
// Event subscriptions for standalone workstation mode.
 
// Checks whether the shared data can be written in standalone workstation mode.
// See the detailed description in the StandaloneModeInternal.DefineDataChangeCapability procedure.
//
Procedure StandaloneModeCheckCanWriteCommonData(Source, Cancel) Export
 
 BeforeWriteCommonData(Source, Cancel);
 
EndProcedure
 
// Checks whether the shared data can be written in standalone workstation mode.
// See the detailed description in the StandaloneModeInternal.DefineDataChangeCapability procedure.
//
Procedure StandaloneModeCheckCanWriteCommonDataDocument(Source, Cancel, WriteMode, PostingMode) Export
 
 BeforeWriteCommonData(Source, Cancel);
 
EndProcedure
 
// Checks whether the shared data can be written in standalone workstation mode.
// See the detailed description in the StandaloneModeInternal.DefineDataChangeCapability procedure.
//
Procedure StandaloneModeCheckCanWriteCommonDataConstant(Source, Cancel) Export
 
 BeforeWriteCommonData(Source, Cancel);
 
EndProcedure
 
// Checks whether the shared data can be written in standalone workstation mode.
// See the detailed description in the StandaloneModeInternal.DefineDataChangeCapability procedure.
//
Procedure StandaloneModeCheckCanWriteCommonDataRecordSet(Source, Cancel, Replacing) Export
 
 BeforeWriteCommonData(Source, Cancel);
 
EndProcedure
 
// Checks whether the shared data can be written in standalone workstation mode.
// See the detailed description in the StandaloneModeInternal.DefineDataChangeCapability procedure.
//
Procedure StandaloneModeCheckCanWriteCommonDataCalculationRecordSet(Source, Cancel, Replacing, WriteOnly, WriteActualActionPeriod, WriteRecalculations) Export
 
 BeforeWriteCommonData(Source, Cancel);
 
EndProcedure
 
////////////////////////////////////////////////////////////////////////////////
// Procedures and functions to get references to shared SaaS data pages.
 
// Returns a URL by ID. 
// For internal use.
//
Function RefAddressFromInformationCenter(Val ID)
 Result = "";
 
 If Not CommonUse.SubsystemExists("CloudTechnology.InformationCenter") Then
  Return Result;
 EndIf;
 
 InformationCenterServerModule = CommonUse.CommonModule("InformationCenterServer");
 
 SetPrivilegedMode(True);
 Try
  RefData = InformationCenterServerModule.ContextRefByID(ID);
 Except
  // The method is not found
  RefData = Undefined;
 EndTry;
 
 If RefData <> Undefined Then
  Result = RefData.Address;
 EndIf;
 
 Return Result;
EndFunction
 
// Returns the URL of the article about the thin client setup.
// For internal use.
//
Function ThinClientSetupInstructionAddress() Export
 
 Return RefAddressFromInformationCenter("ThinClientSetupInstruction");
 
EndFunction
 
// Returns the URL of the article about the backup.
// For internal use.
//
Function BackupInstructionAddress() Export
 
 Return RefAddressFromInformationCenter("BackupExecutionInstruction");
 
EndFunction
 
// Handler of the background job that registers additional data and performs the exchange.
// For internal use.
//
// Parameters:
//     ExportDataProcessor - DataProcessorObject.InteractiveExportModification - initialized object.
//     StorageAddress      - String, UUID - storage address for writing the procedure result.
// 
Procedure ExchangeOnDemand(Val ExportDataProcessor, Val StorageAddress = Undefined) Export
 
 DataProcessors.InteractiveDataExchangeWizardSaaS.ExchangeOnDemand(ExportDataProcessor, StorageAddress);
 
EndProcedure
 
#EndRegion