////////////////////////////////////////////////////////////////////////////////
// Data exchange subsystem
//
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// OnCreateAtServer event handler for the exchange plan node settings form.
//
// Parameters:
//  Form   - ManagedForm - form where the procedure is called from.
//  Cancel - Boolean - cancellation flag. If this parameter is set to True, the form is not created.
// 
Procedure NodesSetupFormOnCreateAtServer(Form, Cancel) Export
	
	Parameters = Form.Parameters;
	// Skipping the initialization to guarantee that the form 
  // will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then
		Return;
	EndIf;
	
	SetMandatoryFormAttributes(Form, NodeSettingsFormMandatoryAttributes());
	
	Form.CorrespondentVersion = Parameters.CorrespondentVersion;
	
	Context = New Structure;
	
	If Parameters.Property("GetDefaultValue") Then
		
		ExchangePlanName = StringFunctionsClientServer.SplitStringIntoSubstringArray(Form.FormName, ".")[1];
		
		NodeFilterStructure = NodeFilterStructure(ExchangePlanName, Parameters.CorrespondentVersion);
		CorrespondentInfobaseNodeFilterSetup = CorrespondentInfobaseNodeFilterSetup(ExchangePlanName, Parameters.CorrespondentVersion);
		ChangeTabularSectionStoringStructure(CorrespondentInfobaseNodeFilterSetup);
		
	Else
		
		NodeFilterStructure = Form.Parameters.Settings.NodeFilterStructure;
		CorrespondentInfobaseNodeFilterSetup = Form.Parameters.Settings.CorrespondentInfobaseNodeFilterSetup;
		
	EndIf;
	
	Context.Insert("NodeFilterStructure", NodeFilterStructure);
	Context.Insert("CorrespondentInfobaseNodeFilterSetup", CorrespondentInfobaseNodeFilterSetup);
	
	Form.Context = Context;
	
	FillFormData(Form);
	
	If Not Parameters.Property("FillChecking") And Not Parameters.Property("GetDefaultValue") Then
		ExecuteFormTablesComparisonAndMerging(Form, Cancel);
	EndIf;
	
EndProcedure

// OnCreateAtServer event handler for the node setup form.
//
// Parameters:
//  Form             - ManagedForm - form where the procedure is called from.
//  ExchangePlanName - String - exchange plan name to be set up.
// 
Procedure NodeSettingsFormOnCreateAtServer(Form, ExchangePlanName) Export
	
  // Skipping the initialization to guarantee that the form 
  // will be received if the Autotest parameter is passed.
	If Form.Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	CheckMandatoryFormAttributes(Form, "NodeFilterStructure, CorrespondentVersion");
	
	Form.CorrespondentVersion = Form.Parameters.CorrespondentVersion;
	Form.NodeFilterStructure  = NodeFilterStructure(ExchangePlanName, Form.CorrespondentVersion);
	
	NodeSettingsFormOnCreateAtServerHandler(Form, "NodeFilterStructure");
	
EndProcedure

// OnCreateAtServer event handler for the node setup form of the correspondent infobase.
//
// Parameters:
//  Form             - ManagedForm - correspondent infobase form.
//  ExchangePlanName - String - exchange plan name to be set up.
//  Data             - Map - contains database table list to set data synchronization rules.
// 
Procedure CorrespondentInfobaseNodeSettingsFormOnCreateAtServer(Form, ExchangePlanName, Data = Undefined) Export

  // Skipping the initialization to guarantee that the form 
  // will be received if the Autotest parameter is passed.	
	If Form.Parameters.Property("Autotest") Then
		Return;
	EndIf;
	
	CheckMandatoryFormAttributes(Form, "CorrespondentVersion, NodeFilterStructure, ExternalConnectionParameters");
	
	Form.CorrespondentVersion = Form.Parameters.CorrespondentVersion;
	Form.ExternalConnectionParameters = Form.Parameters.ExternalConnectionParameters;
	Form.NodeFilterStructure = CorrespondentInfobaseNodeFilterSetup(ExchangePlanName, Form.CorrespondentVersion);
	
	NodeSettingsFormOnCreateAtServerHandler(Form, "NodeFilterStructure");
	
	If Data <> Undefined And TypeOf(Data) = Type("Map") Then
		
		Connection = DataExchangeCached.EstablishExternalConnectionWithInfobase(Form.ExternalConnectionParameters);
		ErrorMessageString = Connection.DetailedErrorDetails;
		ExternalConnection = Connection.Connection;
		
		If ExternalConnection = Undefined Then
			Raise ErrorMessageString;
		EndIf;
		
		For Each Table In Data Do
			
			If    Form.ExternalConnectionParameters.CorrespondentVersion_2_1_1_7
				Or Form.ExternalConnectionParameters.CorrespondentVersion_2_0_1_6 Then
				
				CorrespondentInfobaseTable = CommonUse.ValueFromXMLString(ExternalConnection.DataExchangeExternalConnection.GetTableObjects_2_0_1_6(Table.Key));
				
			Else
				
				CorrespondentInfobaseTable = ValueFromStringInternal(ExternalConnection.DataExchangeExternalConnection.GetTableObjects(Table.Key));
				
			EndIf;
			
			Data.Insert(Table.Key, ValueTableFromValueTree(CorrespondentInfobaseTable));
			
		EndDo;
		
	EndIf;
	
EndProcedure

// OnCreateAtServer event handler for default value setup form.
//
// Parameters:                            
//  Form             - ManagedForm - form where the procedure is called from.
//  ExchangePlanName - String - exchange plan name to be set up.
// 
Procedure DefaultValueSetupFormOnCreateAtServer(Form, ExchangePlanName) Export
	
  // Skipping the initialization to guarantee that the form 
  // will be received if the Autotest parameter is passed.
	If Form.Parameters.Property("Autotest") Then
		Return;
	EndIf;
	
	CheckMandatoryFormAttributes(Form, "NodeDefaultValues, CorrespondentVersion");
	
	Form.CorrespondentVersion = Form.Parameters.CorrespondentVersion;
	Form.NodeDefaultValues = NodeDefaultValues(ExchangePlanName, Form.CorrespondentVersion);
	
	NodeSettingsFormOnCreateAtServerHandler(Form, "NodeDefaultValues");
	
EndProcedure

// OnCreateAtServer event handler for default value setup form for the correspondent infobase.
// The setup is performed over the external connection.
//
// Parameters:                            
//  Form             - ManagedForm - form where the procedure is called from.
//  ExchangePlanName - String - exchange plan name to be set up.
//  AdditionalData   - Arbitrary - used to get additional data.
// 
Procedure CorrespondentInfobaseDefaultValueSetupFormOnCreateAtServer(Form, ExchangePlanName, AdditionalData = Undefined) Export
	
  // Skipping the initialization to guarantee that the form 
  // will be received if the Autotest parameter is passed.
	If Form.Parameters.Property("Autotest") Then
		Return;
	EndIf;
	
	CheckMandatoryFormAttributes(Form, "CorrespondentVersion, NodeDefaultValues, ExternalConnectionParameters");
	
	Form.CorrespondentVersion = Form.Parameters.CorrespondentVersion;
	Form.ExternalConnectionParameters = Form.Parameters.ExternalConnectionParameters;
	Form.NodeDefaultValues = CorrespondentInfobaseNodeDefaultValues(ExchangePlanName, Form.CorrespondentVersion);
	
	NodeSettingsFormOnCreateAtServerHandler(Form, "NodeDefaultValues");
	
	If Form.ExternalConnectionParameters.JoinType = "TempStorage" Then
		
		AdditionalData = GetFromTempStorage(
			Form.ExternalConnectionParameters.TempStorageAddress).Get().Get("{AdditionalData}");
	EndIf;
	
EndProcedure

// Removes attributes from the list of mandatory filling.
// The attributes that are not displayed on the form must be excluded.
//
// Parameters:
// AttributesToCheck - Array - list of attributes that are checked whether their values are filled.
// Items             - FormAllItems - collection that contains all items of the managed form.
//
Procedure GetAttributesToCheckDependingOnFormItemVisibilitySettings(AttributesToCheck, Items) Export
	
	ReverseIndex = AttributesToCheck.Count() - 1;
	
	While ReverseIndex >= 0 Do
		
		AttributeName = AttributesToCheck[ReverseIndex];
		
		For Each Item In Items Do
			
			If TypeOf(Item) = Type("FormField") Then
				
				If Item.DataPath = AttributeName
					And Not Item.Visible Then
					
					AttributesToCheck.Delete(ReverseIndex);
					Break;
					
				EndIf;
				
			EndIf;
			
		EndDo;
		
		ReverseIndex = ReverseIndex - 1;
		
	EndDo;
	
EndProcedure

// Determines whether the AfterDataExport event handler must be executed during the exchange in the DIB.
// 
// Parameters:
//  Object - ExchangePlanObject - exchange plan node, for which the handler is executed.
//  Ref    - ExchangePlanRef - reference to the exchange plan node, for which the handler is executed.
// 
//  Returns:
//   Boolean - True if the AfterDataExport event handler must be executed, otherwise False.
//
Function MustExecuteHandlerAfterDataExport(Object, Ref) Export
	
	Return MustExecuteHandler(Object, Ref, "SentNo");
	
EndFunction

// Determines whether the AfterDataImport event handler must be executed during the exchange in the DIB.
// 
// Parameters:
//  Object - ExchangePlanObject - exchange plan node, for which the handler is executed.
//  Ref    - ExchangePlanRef - reference to the exchange plan node, for which the handler is executed.
// 
//  Returns:
//   Boolean - True if the AfterDataImport event handler must be executed, otherwise False.
//
Function MustExecuteHandlerAfterDataImport(Object, Ref) Export
	
	Return MustExecuteHandler(Object, Ref, "ReceivedNo");
	
EndFunction

// Returns the current infobase index.
//
// Returns:
//   String.
//
Function InfobasePrefix() Export
	
	Return GetFunctionalOption("InfobasePrefix");
	
EndFunction

// Returns the correspondent configuration version.
// If the correspondent configuration version is not defined, returns an empty version "0.0.0.0".
//
// Parameters:
//  Correspondent - ExchangePlanRef - exchange plan node to obtain a configuration version.
// 
// Returns:
//  String - correspondent configuration version.
//
// Example:
//  If CommonUseClientServer.CompareVersions(DataExchangeServer.CorrespondentVersion(Correspondent), "2.1.5.1") >= 0 Then ...
//
Function CorrespondentVersion(Val Correspondent) Export
	
	SetPrivilegedMode(True);
	
	Return InformationRegisters.CommonInfobaseNodeSettings.CorrespondentVersion(Correspondent);
EndFunction

// Sets prefix for the current infobase.
//
// Parameters:
//   Prefix - String - new value of the infobase prefix.
//
Procedure SetInfobasePrefix(Val Prefix) Export
	
	Constants.DistributedInfobaseNodePrefix.Set(TrimAll(Prefix));
	
	DataExchangeServerCall.ResetObjectChangeRecordMechanismCache();
	
EndProcedure

// Checks whether the current infobase is restored from the backup copy.
// If the infobase is restored from the backup, you have to synchronize numbers of sent
// and received messages for both infobases (the number of sent message in the current infobase 
// will be set equal to the received message number in the correspondent infobase).
// If the infobase is restored from the backup, we recommend that you do not delete change registration
// on the current infobase because this data may not be sent to the correspondent infobase yet.
//
// Parameters:
//   Sender     - ExchangePlanRef - node where the exchange message is created and sent.
//   ReceivedNo - Number - received message number in the correspondent infobase.
//
// Returns:
//   FixedStructure - structure with the following properties:
//     * Sender         - ExchangePlanRef - see the Sender parameter.
//     * ReceivedNo     - Number - see the ReceivedNo parameter.
//     * RestoredBackup - Boolean - True if the infobase is restored from the backup.
//
Function BackupCopyParameters(Val Sender, Val ReceivedNo) Export
	
	// If the infobase is restored from the backup, sent message
	// number is less than received message number in the correspondent infobase.
	// It means that in the restored infobase the received message number will be set equal
	// to number of the message that is not received yet ("message from future").
	Result = New Structure("Sender, ReceivedNo, BackupRestored");
	Result.Sender = Sender;
	Result.ReceivedNo = ReceivedNo;
	Result.BackupRestored = (ReceivedNo > CommonUse.ObjectAttributeValue(Sender, "SentNo"));
	
	Return New FixedStructure(Result);
EndFunction

// Synchronizes numbers of the sent and received messages for both infobases.
// In the current infobase the sent message number is set to the received message number
// in the correspondent infobase.
//
// Parameters:
//   BackupCopyParameters - FixedStructure - structure with the following properties:
//     * Sender         - ExchangePlanRef - node where the exchange message is created and sent.
//     * ReceivedNo     - Number - received message number in the correspondent infobase.
//     * RestoredBackup - Boolean - flag that shows whether the current infobase is restored from the backup.
//
Procedure OnBackupRestore(Val BackupCopyParameters) Export
	
	If BackupCopyParameters.BackupRestored Then
		
		// Setting the sent message number in the current infobase equal to 
   // the received message number in the correspondent infobase.
		NodeObject = BackupCopyParameters.Sender.GetObject();
		NodeObject.SentNo = BackupCopyParameters.ReceivedNo;
		NodeObject.AdditionalProperties.Insert("Import");
		NodeObject.Write();
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for operating with the data exchange issue monitor.

// Returns the count of unviewed data exchange issues.
// It is used to display exchange issue number in the user interface.
// For example, to use in a title of a hyperlink to navigate to the exchange issue monitor.
//
// Parameters:
//   Nodes - Array - value array that contains ExchangePlanRef elements.
//
// Returns:
//   Number.
// 
Function UnviewedIssueCount(Nodes = Undefined) Export
	
	Return DataExchangeIssueCount(Nodes) + VersioningIssueCount(Nodes);
	
EndFunction

// Returns structure that contains title of the hyperlink to navigate to the data exchange issue monitor.
// 
// Parameters:
//   Nodes - Array - value array that contains ExchangePlanRef elements.
//
// Returns:
// Structure - with the following properties:
//   * Title   - String - hyperlink title.
//   * Picture - Picture - picture for the hyperlink.
//
Function IssueMonitorHyperlinkTitleStructure(Nodes = Undefined) Export
	
	Quantity = UnviewedIssueCount(Nodes);
	
	If Quantity > 0 Then
		
		Title = NStr("en = 'Warnings (%1)'");
		Title = StringFunctionsClientServer.SubstituteParametersInString(Title, Quantity);
		Picture = PictureLib.Warning;
		
	Else
		
		Title = NStr("en = 'No warnings to display'");
		Picture = New Picture;
		
	EndIf;
	
	TitleStructure = New Structure;
	TitleStructure.Insert("Title",   Title);
	TitleStructure.Insert("Picture", Picture);
	
	Return TitleStructure;
	
EndFunction

#EndRegion

#Region InternalInterface

// Declares internal events of the DataExchange subsystem:
//
// Server events:
//   OnDataExport,
//   OnDataImport.
//
// See the description of this procedure in the StandardSubsystemsServer module.
Procedure OnAddInternalEvent(ClientEvents, ServerEvents) Export
	
	// SERVER EVENTS
	
	// It is used for overriding the standard data export handler.
	// The following operations must be implemented into this handler:
	// selecting data to be exported, serializing data into a message file or into a stream.
	// After the handler ends execution, exported data is sent to the data exchange subsystem recipient.
	// Messages to be exported can have arbitrary format.
	// If errors occur during sending data, the handler execution
	// must be stopped using the Raise method with an error description.
	//
	// Parameters:
	//  StandardProcessing   - Boolean - this parameter contains a flag
	//                         that shows whether the standard processing is used. You can set
	//                         this parameter value to False to cancel the standard processing.
	//                         Canceling standard processing does not mean canceling the operation.
	//                         The default value is True.
	//  Recipient            - ExchangePlanRef - exchange plan node for which data is exported.
	//  MessageFileName      - String - name of the file to export data.
	//                         If this parameter is filled, the platform expects that data will be exported to the file.
	//                         After exporting, the platform sends data from this file.
	//                         If this parameter is  empty, the system expects that data is exported to the MessageData parameter.
	//  MessageData          - Arbitrary - if MessageFileName is empty, expecting
	//                         that data will be exported in this parameter.
	//  TransactionItemCount - Number - contains the maximum number
	//                         of data items that can be included in the message during a single database transaction.
	//                         You can implement the algorithms of transaction locks for exported data in this handler.
	//                         A value of this parameter is set in the data exchange subsystem settings.
	//  EventLogEventName    - String - event name of the current data exchange session for the event log.
	//                         This parameter is used to determine the event
	//                         name (errors, warnings, information) when writing error details to the event log.
	//                         It matches the EventName parameter of the WriteLogEvent method of the global context.
	//  SentObjectCount      - Number - Sent object counter.
	//                         It is used to store the number of exported objects in the exchange protocol.
	//
	// Syntax:
	// Procedure OnDataExportInternal(StandardProcessing,
	// 						Recipient,
	// 						MessageFileName,
	// 						MessageData,
	// 						TransactionItemCount,
	// 						EventLogEventName, ReceivedObjectCount) Export
	//
	ServerEvents.Add("StandardSubsystems.DataExchange\OnDataExportInternal");
	
	// It is used for overriding the standard data import handler.
	// The following operations must be implemented into this handler:
	// necessary checking before importing data, serializing data from a message file or from a stream.
	// Messages to be imported can have arbitrary format.
	// If errors occur during receiving data, the handler execution
	// must be stopped using the Raise method with an error description.
	//
	// Parameters:
	//
	//  StandardProcessing   - Boolean - this parameter contains a flag that shows whether the standard processing is used. 
	//                         You can set this parameter value to False to cancel the standard processing.
	//                         Canceling standard processing does not mean canceling the operation.
	//                         The default value is True.
	//  Sender               - ExchangePlanRef - exchange plan node for which data is imported.
	//  MessageFileName      - String - name of the file to import data.
	//                         If this parameter is empty, data to be imported is passed in the MessageData parameter.
	//  MessageData          - Arbitrary - contains data to be imported.
	//                         If the MessageFileName parameter is empty, the data are to be imported through this parameter.
	//  TransactionItemCount - Number - defines the maximum number
	//                         of data items that can be read from a message and recorded to the infobase during one database transaction.
	//                         If it is necessary, you can implement algorithms of data recording in transaction.
	//                         A value of this parameter is set in the data exchange subsystem settings.
	//  EventLogEventName    - String - event name of the current data exchange session for the event log.
	//                         This parameter is used to determine the event
	//                         name (errors, warnings, information) when writing error details to the event log.
	//                         It matches the EventName parameter of the WriteLogEvent method of the global context.
	//  ReceivedObjectCount  - Number - received object counter.
	//                         It is used to store the number of imported objects in the exchange protocol.
	//
	// Syntax:
	// Procedure OnDataImportInternal(StandardProcessing,
	// 						Sender,
	// 						MessageFileName,
	// 						MessageData,
	// 						TransactionItemCount,
	// 						EventLogEventName, ReceivedObjectCount) Export
	//
	ServerEvents.Add("StandardSubsystems.DataExchange\OnDataImportInternal");
	
EndProcedure

// See the description of this procedure in the StandardSubsystemsServer module.
Procedure InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers) Export
	
	// CLIENT HANDLERS
	
	ClientHandlers[
		"StandardSubsystems.BaseFunctionality\OnStart"].Add(
			"DataExchangeClient");
			
	ClientHandlers[
		"StandardSubsystems.BaseFunctionality\AfterStart"].Add(
			"DataExchangeClient");
	
	// SERVER HANDLERS
	
	ServerHandlers["StandardSubsystems.InfobaseVersionUpdate\OnAddUpdateHandlers"].Add(
		"DataExchangeServer");
	
	ServerHandlers["StandardSubsystems.BaseFunctionality\RenamedMetadataObjectsOnAdd"].Add(
		"DataExchangeServer");
	
	ServerHandlers["StandardSubsystems.BaseFunctionality\SupportedInterfaceVersionsOnDefine"].Add(
		"DataExchangeServer");
	
	ServerHandlers["StandardSubsystems.BaseFunctionality\OnAddStandardSubsystemClientLogicParametersOnStart"].Add(
		"DataExchangeServer");
	
	ServerHandlers["StandardSubsystems.BaseFunctionality\StandardSubsystemClientLogicParametersOnAdd"].Add(
		"DataExchangeServer");
	
	ServerHandlers["StandardSubsystems.BaseFunctionality\OnGetMandatoryExchangePlanObjects"].Add(
		"DataExchangeServer");
	
	ServerHandlers["StandardSubsystems.BaseFunctionality\ExchangePlanObjectsToExcludeOnGet"].Add(
		"DataExchangeServer");
	
	ServerHandlers["StandardSubsystems.BaseFunctionality\OnGetExchangePlanInitialImageObjects"].Add(
		"DataExchangeServer");
		
	ServerHandlers["StandardSubsystems.BaseFunctionality\OnEnableSeparationByDataAreas"].Add(
		"DataExchangeServer");
		
	ServerHandlers["StandardSubsystems.BaseFunctionality\OnAddReferenceSearchException"].Add(
		"DataExchangeServer");
		
	ServerHandlers["StandardSubsystems.BaseFunctionality\OnFillPermissionsToAccessExternalResources"].Add(
		"DataExchangeServer");
		
	ServerHandlers["StandardSubsystems.BaseFunctionality\ExternalModuleManagersOnRegistration"].Add(
		"DataExchangeServer");
	
	If CommonUse.SubsystemExists("StandardSubsystems.AccessManagement") Then
		
		ServerHandlers["StandardSubsystems.AccessManagement\OnFillSuppliedAccessGroupProfiles"].Add(
			"DataExchangeServer");
		
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.ToDoList") Then
		ServerHandlers["StandardSubsystems.ToDoList\OnFillToDoList"].Add(
			"DataExchangeServer");
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Handlers of conditional calls.

// Imports IDs of metadata objects that are received from the DIB master node.
Procedure MetadataObjectIDsInSubordinateDIBNodeBeforeCheck(Cancel = False) Export
	
	Catalogs.MetadataObjectIDs.CheckForUsage();
	
	If DataExchangeServerCall.DataExchangeMessageImportModeBeforeStart(
			"SkipDataExchangeMessageImportingBeforeStart") Then
		Return;
	EndIf;
	
	If DataExchangeServerCall.DataExchangeMessageImportModeBeforeStart(
			"SkipMetadataObjectIDImportBeforeStart") Then
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	SetDataExchangeMessageImportModeBeforeStart("ImportPermitted", True);
	SetPrivilegedMode(False);
	
	Try
		
		If GetFunctionalOption("UseDataSynchronization") = False Then
			
			If CommonUseCached.DataSeparationEnabled() Then
				
				UseDataSynchronization = Constants.UseDataSynchronization.CreateValueManager();
				UseDataSynchronization.AdditionalProperties.Insert("DisableObjectChangeRecordMechanism");
				UseDataSynchronization.DataExchange.Load = True;
				UseDataSynchronization.Value = True;
				UseDataSynchronization.Write();
				
			Else
				
				If GetUsedExchangePlans().Count() > 0 Then
					
					UseDataSynchronization = Constants.UseDataSynchronization.CreateValueManager();
					UseDataSynchronization.AdditionalProperties.Insert("DisableObjectChangeRecordMechanism");
					UseDataSynchronization.DataExchange.Load = True;
					UseDataSynchronization.Value = True;
					UseDataSynchronization.Write();
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
		If GetFunctionalOption("UseDataSynchronization") = True Then
			
			InfobaseNode = MasterNode();
			
			If InfobaseNode <> Undefined Then
				
				TransportKind = InformationRegisters.ExchangeTransportSettings.DefaultExchangeMessageTransportKind(InfobaseNode);
				
				// Importing only application parameters
				ExecuteDataExchangeForInfobaseNode(Cancel, InfobaseNode, True, False, TransportKind,,,,,, True);
				
			EndIf;
			
		EndIf;
		
	Except
		SetPrivilegedMode(True);
		SetDataExchangeMessageImportModeBeforeStart("ImportPermitted", False);
		SetPrivilegedMode(False);
		
		EnableDataExchangeMessageImportRecurrenceBeforeStart();
		
		WriteLogEvent(
			NStr("en = 'Data exchange.""Metadata object IDs"" catalog import'", CommonUseClientServer.DefaultLanguageCode()),
			EventLogLevel.Error,,,
			DetailErrorDescription(ErrorInfo()));
		
		Raise
			NStr("en = 'Changes of the ""Metadata object IDs"" are not imported from the master node: 
			           |data import error. See details in the event log.'");
	EndTry;
	SetPrivilegedMode(True);
	SetDataExchangeMessageImportModeBeforeStart("ImportPermitted", False);
	SetPrivilegedMode(False);
	
	If Cancel Then
		
		If ConfigurationChanged() Then
			Raise
				NStr("en = 'Configuration changes that are received from the master node, are imported.
				           |Close the application. Run Designer and
				           |execute ""Update database configuration (F7)"".
				           |
				           |Then run the application.'");
		EndIf;
		
		EnableDataExchangeMessageImportRecurrenceBeforeStart();
		
		Raise
			NStr("en = 'Changes of the ""Metadata object IDs"" are not imported from the master node:
			           |data import error. See details in the event log.'");
	EndIf;
	
EndProcedure

// Set the flag that shows whether the metadata object IDs must be imported from the exchange message.
// Clears exchange messages received from the master node.
// The procedure raises the exception with details about further actions if the RaiseException value is True.
//
Procedure MetadataObjectIDsInSubordinateDIBNodeOnCheckError(RaiseException = False) Export
	
	Catalogs.MetadataObjectIDs.CheckForUsage();
	
	EnableDataExchangeMessageImportRecurrenceBeforeStart();
	
	If RaiseException Then
		ErrorText = 
			NStr("en = 'The ""Metadata object IDs"" catalog changes are not imported:
			           |checking found that it is required to import critical changes (see details in the event log,
			           |in records with the ""Metadata object IDs.It is required to import critical changes"" event).
			           |
			           |If the data exchange message is inaccessible, restart the application,
			           |set up connection settings and repeat the synchronization.
			           |If all required changes were not received from
			           |the master node, you have to update
			           |the infobafe on the master node, and repeat data synchronization in the master node and subordinate nodes.
			           |
			           |To update the infobase configuration in the master node,
			           |you have start the application once with the StartInfobaseUpdate launch parameter.
			           |To register catalog changes, specify the
			           |RegisterFullMOIDChangeForSubordinateDIBNodes launch parameter.'");
		
		Raise ErrorText;
	EndIf;
	
EndProcedure

// Imports the exchange message that contains configuration changes before infobase update.
//
Procedure InfobaseBeforeUpdate(OnClientStart, Restart) Export
	
	If CommonUseCached.DataSeparationEnabled() Then
		Return;	
	EndIf;
	
	If Not InfobaseUpdate.InfobaseUpdateRequired() Then
		ExecuteSynchronizationWhenInfobaseUpdateAbsent(OnClientStart, Restart);
	Else	
		ImportMessageBeforeInfobaseUpdate();
	EndIf;

EndProcedure

// Exports the exchange message that contains configuration changes before infobase update.
//
Procedure AfterInfobaseUpdate() Export
	
	If CommonUseCached.DataSeparationEnabled() Then
		Return;	
	EndIf;
	
	ExportMessageAfterInfobaseUpdate();
	
EndProcedure	

// Returns True if the DIB node setup is not completed and
// it is required to update application parameters that are not used in DIB.
//
Function SubordinateDIBNodeSetup() Export
	
	SetPrivilegedMode(True);
	
	Return IsSubordinateDIBNode()
	      And Constants.SubordinateDIBNodeSetupCompleted.Get() = False;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Infobase update.

// Adds update handlers that are required by the subsystem.
//
// Parameters:
//  Handlers - ValueTable - see the description of NewUpdateHandlerTable function in the InfobaseUpdate common module.
// 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version = "*";
	Handler.Priority = 1;
	Handler.SharedData = True;
	Handler.ExclusiveMode = False;
	Handler.Procedure = "DataExchangeServer.UpdateDataExchangeRules";
	
	Handler = Handlers.Add();
	Handler.Version = "1.1.1.2";
	Handler.Procedure = "DataExchangeServer.SetMappingDataAdjustmentRequiredForAllInfobaseNodes";
	
	Handler = Handlers.Add();
	Handler.Version = "1.1.1.2";
	Handler.Procedure = "DataExchangeServer.SetExportModeForAllInfobaseNodes";
	
	Handler = Handlers.Add();
	Handler.Version = "1.1.1.2";
	Handler.SharedData = True;
	Handler.Procedure = "DataExchangeServer.UpdateDataExchangeScenarioScheduledJobs";
	
	Handler = Handlers.Add();
	Handler.Version = "1.1.2.0";
	Handler.Procedure = "DataExchangeServer.UpdateSubordinateDIBNodeSetupCompletedConstant";
	
	Handler = Handlers.Add();
	Handler.Version = "2.0.1.10";
	Handler.SharedData = True;
	Handler.Procedure = "DataExchangeServer.CheckFunctionalOptionsAreSetOnInfobaseUpdate";
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.1.5";
	Handler.SharedData = True;
	Handler.Procedure = "DataExchangeServer.SetExchangePasswordSaveOverInternetFlag";
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.2.12";
	Handler.Procedure = "DataExchangeServer.ResetExchangeMonitorSettings";
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.2.21";
	Handler.SharedData = True;
	Handler.Procedure = "DataExchangeServer.CheckFunctionalOptionsAreSetOnInfobaseUpdate_2_1_2_21";
	
	Handler = Handlers.Add();
	Handler.Version = "2.2.2.4";
	Handler.SharedData = True;
	Handler.Procedure = "DataExchangeServer.SetDataImportTransactionItemNumber_2_2_2_4";
	
EndProcedure

// Updates object conversion/registration rules.
// Updates all exchange plans that use SL functionality.
// Updates only standard rules.
// Rules are not updated if they were loaded from a file.
//
Procedure UpdateDataExchangeRules() Export
	
	// If the exchange plan was renamed or deleted from the configuration
	DeleteObsoleteRecordsFromDataExchangeRuleRegister();
	
	LoadedFromFileExchangeRules = New Array;
	LoadedFromFileRecordRules   = New Array;
	
	CheckLoadedFromFileExchangeRulesAvailability(LoadedFromFileExchangeRules, LoadedFromFileRecordRules);
	
	Cancel = False;
	
	UpdateStandardDataExchangeRuleVersion(Cancel, LoadedFromFileExchangeRules, LoadedFromFileRecordRules);
	
	If Cancel Then
		Raise NStr("en = 'Errors occurred during updating of data exchange rules (see the event log).'");
	EndIf;
	
	DataExchangeServerCall.ResetObjectChangeRecordMechanismCache();
	
EndProcedure

// Sets the flag that shows whether the mapping data adjustment
// for all exchange plan nodes must be executed during the next data exchange.
//
Procedure SetMappingDataAdjustmentRequiredForAllInfobaseNodes() Export
	
	InformationRegisters.CommonInfobaseNodeSettings.SetMappingDataAdjustmentRequiredForAllInfobaseNodes();
	
EndProcedure

// Sets the "Export by condition" value for export mode flags of all universal data exchange nodes.
//
Procedure SetExportModeForAllInfobaseNodes() Export
	
	ExchangePlanList = DataExchangeCached.SLExchangePlanList();
	
	For Each Item In ExchangePlanList Do
		
		ExchangePlanName = Item.Value;
		
		If Metadata.ExchangePlans[ExchangePlanName].DistributedInfobase Then
			Continue;
		EndIf;
		
		NodeArray = DataExchangeCached.GetExchangePlanNodeArray(ExchangePlanName);
		
		For Each Node In NodeArray Do
			
			AttributeNames = CommonUse.AttributeNamesByType(Node, Type("EnumRef.ExchangeObjectExportModes"));
			
			If IsBlankString(AttributeNames) Then
				Continue;
			EndIf;
			
			AttributeNames = StrReplace(AttributeNames, " ", "");
			
			Attributes = StringFunctionsClientServer.SplitStringIntoSubstringArray(AttributeNames);
			
			ObjectModified = False;
			
			NodeObject = Node.GetObject();
			
			For Each AttributeName In Attributes Do
				
				If Not ValueIsFilled(NodeObject[AttributeName]) Then
					
					NodeObject[AttributeName] = Enums.ExchangeObjectExportModes.ExportByCondition;
					
					ObjectModified = True;
					
				EndIf;
				
			EndDo;
			
			If ObjectModified Then
				
				NodeObject.AdditionalProperties.Insert("GettingExchangeMessage");
				NodeObject.Write();
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
EndProcedure

// Updates scheduled job data for all data exchange scenarios except those marked for deletion.
//
Procedure UpdateDataExchangeScenarioScheduledJobs() Export
	
	QueryText = "
	|SELECT
	|	DataExchangeScenarios.Ref
	|FROM
	|	Catalog.DataExchangeScenarios AS DataExchangeScenarios
	|WHERE
	|	Not DataExchangeScenarios.DeletionMark
	|";
	
	Query = New Query;
	Query.Text = QueryText;
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		Cancel = False;
		
		Object = Selection.Ref.GetObject();
		
		Catalogs.DataExchangeScenarios.UpdateScheduledJobData(Cancel, Undefined, Object);
		
		If Cancel Then
			Raise NStr("en = 'Error updating the scheduled job for the data exchange scenario.'");
		EndIf;
		
		InfobaseUpdate.WriteData(Object);
		
	EndDo;
	
EndProcedure

// Sets the SubordinateDIBNodeSetupCompleted constant value
// to True for the subordinate DIB node.
//
Procedure UpdateSubordinateDIBNodeSetupCompletedConstant() Export
	
	If  IsSubordinateDIBNode()
		And InformationRegisters.ExchangeTransportSettings.NodeTransportSettingsAreSet(MasterNode()) Then
		
		Constants.SubordinateDIBNodeSetupCompleted.Set(True);
		
		RefreshReusableValues();
		
	EndIf;
	
EndProcedure

// Redefines the UseDataSynchronization constant value, if necessary.
//
Procedure CheckFunctionalOptionsAreSetOnInfobaseUpdate() Export
	
	If Constants.UseDataSynchronization.Get() = True Then
		
		Constants.UseDataSynchronization.Set(True);
		
	EndIf;
	
EndProcedure

// Redefines the UseDataSynchronization constant value, if necessary.
// The constant is shared now and its value is reseted.
//
Procedure CheckFunctionalOptionsAreSetOnInfobaseUpdate_2_1_2_21() Export
	
	If GetFunctionalOption("UseDataSynchronization") = False Then
		
		If CommonUseCached.DataSeparationEnabled() Then
			
			Constants.UseDataSynchronization.Set(True);
			
		Else
			
			If GetUsedExchangePlans().Count() > 0 Then
				
				Constants.UseDataSynchronization.Set(True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Sets the import transaction item count equal to 1.
//
Procedure SetDataImportTransactionItemNumber_2_2_2_4() Export
	
	SetDataImportTransactionItemNumber(1);
	
EndProcedure

// Sets the WSRememberPassword attribute value to True in InformationRegister.ExchangeTransportSettings.
//
Procedure SetExchangePasswordSaveOverInternetFlag() Export
	
	QueryText =
	"SELECT
	|	ExchangeTransportSettings.Node AS Node
	|FROM
	|	InformationRegister.ExchangeTransportSettings AS ExchangeTransportSettings
	|WHERE
	|	ExchangeTransportSettings.DefaultExchangeMessageTransportKind = VALUE(Enum.ExchangeMessageTransportKinds.WS)";
	
	Query = New Query;
	Query.Text = QueryText;
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		// Updating record in the information register
		RecordStructure = New Structure;
		RecordStructure.Insert("Node", Selection.Node);
		RecordStructure.Insert("WSRememberPassword", True);
		InformationRegisters.ExchangeTransportSettings.UpdateRecord(RecordStructure);
		
	EndDo;
	
EndProcedure

// Clears saved settings of the DataExchange common form.
//
Procedure ResetExchangeMonitorSettings() Export
	
	FormSettingsArray = New Array;
	FormSettingsArray.Add("/FormSettings");
	FormSettingsArray.Add("/WindowSettings");
	FormSettingsArray.Add("/WebClientWindowSettings");
	FormSettingsArray.Add("/CurrentData");
	
	For Each FormItem In FormSettingsArray Do
		SystemSettingsStorage.Delete("CommonForm.DataExchanges" + FormItem, Undefined, Undefined);
	EndDo;
	
EndProcedure

// Checks whether the SL exchange plan is a separated one.
//
// Parameters:
// ExchangePlanName - String - name of the exchange plan to check.
//
// Returns:
// Type - Boolean.
//
Function IsSLSeparatedExchangePlan(Val ExchangePlanName) Export
	
	Return DataExchangeCached.SeparatedSLExchangePlans().Find(ExchangePlanName) <> Undefined;
	
EndFunction

// Creates the selection of changed data to transmit to some exchange plan node.
// If this method is called in an active transaction, an exception is raised.
// See the ExchangePlansManager.SelectChanges() method details in the Syntax Assistant.
//
Function SelectChanges(Val Node, Val MessageNo, Val SelectionFilter = Undefined) Export
	
	If TransactionActive() Then
		Raise NStr("en = 'Selection of data changes in an active transaction is not allowed.'");
	EndIf;
	
	Return ExchangePlans.SelectChanges(Node, MessageNo, SelectionFilter);
EndFunction

// Defines default settings for the exchange plan.
// These settings are overridden in the DefineSettings() function of the exchange plan manager module.
// 
// Returns:
// Structure - containing fields:
// 	* WarnAboutExchangeRuleVersionMismatch - Boolean - flag that shows whether it is required
// 																                 to check version difference in the conversion rules. 
//                                            The checking is performed on rule set importing, 
//                                            on data sending, and on data receiving.
// 	* RuleSetFilePathOnUserSite            - String - contains the path to the archive
// 																                 of the rule set file on the user site, in the configuration section. 
//   * RuleSetFilePathInTemplateDirectory   - String - contains a relative path to the rule set
// 															                   file in the 1C:Enterprise template directory.
//
Function DefaultExchangePlanSettings() Export
	
	Parameters = New Structure;
	Parameters.Insert("WarnAboutExchangeRuleVersionMismatch", True);
	Parameters.Insert("RuleSetFilePathOnUserSite", "");
	Parameters.Insert("RuleSetFilePathInTemplateDirectory", "");
	
	Return Parameters;
	
EndFunction

// Returns the exchange plan settings value by settings name.
// 
// Parameters:
// ExchangePlanName - String - exchange plan name from the metadata. 
// ParameterName    - String - exchange plan parameter name or list of parameters separated by comma.
// 						         To find out the available value list, see the DefaultExchang PlanParameters function.
// 
// Returns:
// - Arbitrary - type of return value depends on type of the passed options.
// - Structure - if the ParameterName parameter contains a list of parameters separated by comma.
//
Function ExchangePlanSettingValue(ExchangePlanName, ParameterName) Export
	
	DefaultParameters = DefaultExchangePlanSettings();
	ExchangePlans[ExchangePlanName].DefineSettings(DefaultParameters);
	
	If Find(ParameterName, ",") = 0 Then
		
		ParameterValue = DefaultParameters[ParameterName];
		
	Else
		
		ParameterValue = New Structure(ParameterName);
		FillPropertyValues(ParameterValue, DefaultParameters);
		
	EndIf;
	
	Return ParameterValue;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for operating with FTP connection.

Function FTPConnection(Val Settings) Export
	
	Return New FTPConnection(
		Settings.Server,
		Settings.Port,
		Settings.UserName,
		Settings.UserPassword,
		ProxyServerSettings(),
		Settings.PassiveConnection,
		Settings.Timeout
	);
	
EndFunction

Function FTPDirectoryExists(Val Path, Val DirectoryName, Val FTPConnection) Export
	
	For Each FTPFile In FTPConnection.FindFiles(Path) Do
		
		If FTPFile.IsDirectory() And FTPFile.Name = DirectoryName Then
			
			Return True;
			
		EndIf;
		
	EndDo;
	
	Return False;
EndFunction

Function FTPConnectionSettings() Export
	
	Result = New Structure;
	Result.Insert("Server", "");
	Result.Insert("Port", 21);
	Result.Insert("UserName", "");
	Result.Insert("UserPassword", "");
	Result.Insert("PassiveConnection", False);
	Result.Insert("Timeout", 0);
	
	Return Result;
EndFunction

// Returns a server name and a path on the FTP server. 
// This data is got from the connection string to the FTP server.
//
// Parameters:
//  ConnectionString - String - connection string to connect to the FTP server.
// 
// Returns:
//  Structure - FTP server connection settings. Structure fields are:
//              Server - String - server name,
//              Path   - String - path on the server.
//
//  Example ():
// Result = FTPServerNameAndPath("ftp://server");
// Result.Server = "server";
// Result.Path = "/";
//
//  Example (2):
// Result = FTPServerNameAndPath("ftp://server/saas/exchange");
// Result.Server = "server";
// Result.Path = "/saas/exchange/";
//
Function FTPServerNameAndPath(Val ConnectionString) Export
	
	Result = New Structure("Server, Path");
	ConnectionString = TrimAll(ConnectionString);
	
	If (Upper(Left(ConnectionString, 6)) <> "FTP://"
		And Upper(Left(ConnectionString, 7)) <> "FTPS://")
		Or Find(ConnectionString, "@") <> 0 Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'FTP server connection string does not match the format: %1'"), ConnectionString
		);
	EndIf;
	
	ConnectionParameters = StringFunctionsClientServer.SplitStringIntoSubstringArray(ConnectionString, "/");
	
	If ConnectionParameters.Count() < 3 Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Server name is not specified in the connection string to FTP server: %1'"), ConnectionString
		);
	EndIf;
	
	Result.Server = ConnectionParameters[2];
	
	ConnectionParameters.Delete(0);
	ConnectionParameters.Delete(0);
	ConnectionParameters.Delete(0);
	
	ConnectionParameters.Insert(0, "@");
	
	If Not IsBlankString(ConnectionParameters.Get(ConnectionParameters.UBound())) Then
		
		ConnectionParameters.Add("@");
		
	EndIf;
	
	Result.Path = StringFunctionsClientServer.StringFromSubstringArray(ConnectionParameters, "/");
	Result.Path = StrReplace(Result.Path, "@", "");
	
	Return Result;
EndFunction

// Gets proxy server settings.
//
Function ProxyServerSettings()
	
	If CommonUse.SubsystemExists("StandardSubsystems.GetFilesFromInternet") Then
		
		GetFilesFromInternetModule = CommonUse.CommonModule("GetFilesFromInternet");
		GetFilesFromInternetModule.ProxySettingsAtServer();
		
	Else
		
		ProxyServerSettings = Undefined;
		
	EndIf;
	
	If ProxyServerSettings <> Undefined Then
		UseProxy = ProxyServerSettings.Get("UseProxy");
		UseSystemSettings = ProxyServerSettings.Get("UseSystemSettings");
		If UseProxy Then
			If UseSystemSettings Then
				// Proxy server system settings
				Proxy = New InternetProxy(True);
			Else
				// Custom proxy settings
				Proxy = New InternetProxy;
				Proxy.Set("ftp", ProxyServerSettings["Server"], ProxyServerSettings["Port"]);
				Proxy.User     = ProxyServerSettings["User"];
				Proxy.Password = ProxyServerSettings["Password"];
				Proxy.BypassProxyOnLocal = ProxyServerSettings["BypassProxyOnLocal"];
			EndIf;
		Else
			// Do not use proxy server
			Proxy = New InternetProxy(False);
		EndIf;
	Else
		Proxy = Undefined;
	EndIf;
	
	Return Proxy;
	
EndFunction

#EndRegion

#Region InternalProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// SL event handlers.

// Fills the structure with arrays of supported versions of the subsystems that can have versions.
// Subsystem names are used as structure keys.
// Implements the InterfaceVersion web service functionality.
// This procedure must return current version sets, therefore its body must be changed accordingly before use. See the example below.
//
// Parameters:
// SupportedVersionStructure - Structure: 
//    - Keys = Subsystem names. 
//    - Values = Arrays of supported version names.
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
	SupportedVersionStructure.Insert("DataExchange", VersionArray);
	
EndProcedure

// Adds parameters of client logic execution for the data exchange subsystem.
//
Procedure OnAddStandardSubsystemClientLogicParametersOnStart(Parameters) Export
	
	SetPrivilegedMode(True);
	
	Parameters.Insert("DIBExchangePlanName", ?(IsSubordinateDIBNode(), MasterNode().Metadata().Name, ""));
	Parameters.Insert("MasterNode", MasterNode());
	
	If Not DataExchangeCached.IsStandaloneWorkstation()
	   And IsSubordinateDIBNode()
	   And Not Constants.SubordinateDIBNodeSetupCompleted.Get() Then
		
		Parameters.Insert("OpenDataExchangeCreationWizardForSubordinateNodeSetup");
	EndIf;
	
	SetPrivilegedMode(False);
	
	If Not Parameters.Property("OpenDataExchangeCreationWizardForSubordinateNodeSetup")
	   And Users.RolesAvailable("SynchronizeData") Then
		
		Parameters.Insert("CheckSubordinateNodeConfigurationUpdateRequired");
	EndIf;
	
EndProcedure

// Fills the renamings for metadata objects
// that cannot be found by a type but these object
// references must be saved in the infobase (for example: subsystems, roles).
//
// For details see the CommonUse.AddRenaming() procedure.
//
Procedure RenamedMetadataObjectsOnAdd(Total) Export
	
	Library = "StandardSubsystems";
	
	CommonUse.AddRenaming(
		Total, "2.1.2.5", "Role.ExecuteDataExchange", "Role.SynchronizeData", Library);
		
	CommonUse.AddRenaming(
		Total, "2.1.2.5", "Role.AddEditDataExchanges", "Role.DataSynchronizationSetup", Library);
	
EndProcedure

// Fills the parameter structures required by the client configuration code.
//
// Parameters:
//   Parameters - Structure - parameter structure.
//
Procedure StandardSubsystemClientLogicParametersOnAdd(Parameters) Export
	
	AddClientParameters(Parameters);
	
EndProcedure

// The procedure is used when getting metadata objects that are mandatory for the exchange plan.
// If the subsystem includes metadata objects that must be included in
// the exchange plan content, add these metadata objects to the Objects parameter.
//
// Parameters:
// Objects                         - Array - array of configuration metadata objects that must be included in the exchange plan content.
// DistributedInfobase (read only) - Boolean - flag that shows whether DIB exchange plan objects are retrieved.
//                                      True  - list of DIB exchange plan objects is retrieved;
//                                      False - list of non-DIB exchange plan objects is retrieved.
//
Procedure OnGetMandatoryExchangePlanObjects(Objects, Val DistributedInfobase) Export
	
EndProcedure

// The procedure is used when getting metadata objects that must not be included in the exchange plan content.
// If the subsystem includes metadata objects that must not be included in
// the exchange plan content, add these metadata objects to the Objects parameter.
//
// Parameters:
// Objects                         - Array - array of configuration metadata objects that should not be included in the exchange plan content.
// DistributedInfobase (read only) - Boolean - flag that shows whether DIB exchange plan objects are retrieved.
//                                      True  - list of the objects to be excluded from a DIB exchange plan is retrieved;
//                                      False - list of non-DIB exchange plan objects is retrieved.
//
Procedure ExchangePlanObjectsToExcludeOnGet(Objects, Val DistributedInfobase) Export
	
	If DistributedInfobase Then
		
		Objects.Add(Metadata.Constants.RetryDataExchangeMessageImportBeforeStart);
		Objects.Add(Metadata.Constants.ORMCachedValueRefreshDate);
		Objects.Add(Metadata.Constants.LoadDataExchangeMessage);
		Objects.Add(Metadata.Constants.UseDataSynchronization);
		Objects.Add(Metadata.Constants.UseDataSynchronizationInLocalMode);
		Objects.Add(Metadata.Constants.UseDataSynchronizationSaaS);
		Objects.Add(Metadata.Constants.DataExchangeMessageDirectoryForWindows);
		Objects.Add(Metadata.Constants.DataExchangeMessageDirectoryForLinux);
		Objects.Add(Metadata.Constants.SubordinateDIBNodeSetupCompleted);
		Objects.Add(Metadata.Constants.DistributedInfobaseNodePrefix);
		Objects.Add(Metadata.Constants.DataExchangeMessageFromMasterNode);
		
		Objects.Add(Metadata.Catalogs.DataExchangeScenarios);
		
		Objects.Add(Metadata.InformationRegisters.ExchangeTransportSettings);
		Objects.Add(Metadata.InformationRegisters.CommonInfobaseNodeSettings);
		Objects.Add(Metadata.InformationRegisters.DataExchangeRules);
		Objects.Add(Metadata.InformationRegisters.DataExchangeMessages);
		Objects.Add(Metadata.InformationRegisters.InfobaseObjectMappings);
		Objects.Add(Metadata.InformationRegisters.DataExchangeStates);
		Objects.Add(Metadata.InformationRegisters.SuccessfulDataExchangeStates);
		
	EndIf;
	
EndProcedure

// The procedure is used for getting metadata objects that must be
// included in the exchange plan content but not included in the change record event subscriptions of this exchange plan.
// These metadata objects are used only when creating the initial image
// of a subordinate node and are not transferred during the exchange.
// If the subsystem includes metadata objects used only for creating the initial image
// of a subordinate node, add these metadata objects to the Objects parameter.
//
// Parameters:
// Objects - Array - metadata object array.
//
Procedure OnGetExchangePlanInitialImageObjects(Objects) Export
	
	Objects.Add(Metadata.Constants.SubordinateDIBNodeSettings);
	
EndProcedure

// Called when enabling data separation by data area.
//
Procedure OnEnableSeparationByDataAreas() Export
	
	If GetFunctionalOption("UseDataSynchronization") = False Then
		Constants.UseDataSynchronization.Set(True);
	EndIf;
	
EndProcedure

// Fills descriptions of supplied access group profiles and overrides update 
// parameters of profiles and access groups.
// For details see AccessManagementOverridable.OnFillSuppliedAccessGroupProfiles
//
Procedure OnFillSuppliedAccessGroupProfiles(ProfileDescriptions, UpdateParameters) Export
	
	// "Data synchronization with other applications" profile.
	ProfileDescription = CommonUse.CommonModule("AccessManagement").NewAccessGroupProfileDescription();
	ProfileDescription.ID = DataSynchronizationAccessProfileWithOtherApplications();
	ProfileDescription.Description = NStr("en = 'Data synchronization with other applications'");
	ProfileDescription.Details = NStr("en = 'This profile is assigned to those users that
										|have to control and perform the data synchronization with other applications.'");
	
	// Profile basic features
	ProfileRoles = StringFunctionsClientServer.SplitStringIntoSubstringArray(
		DataSynchronizationAccessProfileWithOtherApplicationsRoles());
	For Each Role In ProfileRoles Do
		ProfileDescription.Roles.Add(TrimAll(Role));
	EndDo;
	ProfileDescriptions.Add(ProfileDescription);
	
EndProcedure

// Fills the array with the list of names of metadata objects that might include references to
// other metadata objects, but these references are ignored in the business logic of the
// application.
//
// Parameters:
//  Array - array of strings, for example, InformationRegister.ObjectVersions.
//
Procedure OnAddReferenceSearchException(Array) Export
	
	Array.Add(Metadata.InformationRegisters.DataExchangeResults.FullName());
	
EndProcedure

// Fills a list of requests for external permissions that must be granted when an infobase is created or an application is updated.
//
// Parameters:
//  PermissionRequests - Array - list of values
//                      returned by SafeMode.RequestToUseExternalResources() method.
//
Procedure OnFillPermissionsToAccessExternalResources(PermissionRequests) Export
	
	If GetFunctionalOption("UseDataSynchronization") = False Then
		Return;
	EndIf;
	
	CreateQueriesForExternalResourceUse(PermissionRequests);
	
EndProcedure

// The procedure is called when external module managers are registered.
//
// Parameters:
//  Managers - Array(CommonModule).
//
Procedure ExternalModuleManagersOnRegistration(Managers) Export
	
	Managers.Add(DataExchangeServer);
	
EndProcedure

// Fills a user's to-do list.
//
// Parameters:
//  ToDoList - ValueTable - value table with the following columns:
//    * ID             - String - internal user task ID used by the to-do list algorithm.
//    * HasUserTasks   - Boolean - if True, the user task is displayed in the user's to-do list.
//    * Important      - Boolean - If True, the user task is outlined in red.
//    * Presentation   - String - user task presentation displayed to the user.
//    * Count          - Number  - quantitative indicator of the user task, displayed in the title of the user task.
//    * Form           - String - full path to the form that is displayed by a click on the task hyperlink in the To-do list panel.
//    * FormParameters - Structure - parameters with which the user form is opened.
//    * Owner          - String, metadata object - string ID of the user task that is the owner of the current user task, or a subsystem metadata object.
//    * Hint           - String - hint text.
//
Procedure OnFillToDoList(ToDoList) Export
	
	If Not AccessRight("Edit", Metadata.InformationRegisters.DataExchangeRules) Then
		Return;
	EndIf;
	
	// If no Administration section, the user task is not added.
	Subsystem = Metadata.Subsystems.Find("Administration");
	If Subsystem <> Undefined
		And Not AccessRight("View", Subsystem)
		And Not CommonUse.MetadataObjectEnabledByFunctionalOptions(Subsystem) Then
		Return;
	EndIf;
	
	OutputUserTask = True;
	VersionChecked = CommonSettingsStorage.Load("ToDoList", "ExchangePlans");
	If VersionChecked <> Undefined Then
		VersionArray   = StringFunctionsClientServer.SplitStringIntoSubstringArray(Metadata.Version, ".");
		CurrentVersion = VersionArray[0] + VersionArray[1] + VersionArray[2];
		If VersionChecked = CurrentVersion Then
			OutputUserTask = False; // Additional reports and data processors were checked on the current version
		EndIf;
	EndIf;
	
	ExchangePlansWithRulesFromFile = ExchangePlansWithRulesFromFile();
	
	// Adding a user task.
	UserTask = ToDoList.Add();
	UserTask.ID           = "ExchangeRules";
	UserTask.HasUserTasks = OutputUserTask And ExchangePlansWithRulesFromFile > 0;
	UserTask.Presentation = NStr("en = 'Exchange rules'");
	UserTask.Quantity     = ExchangePlansWithRulesFromFile;
	UserTask.Form         = "InformationRegister.DataExchangeRules.Form.ExchangePlanCheck";
	UserTask.Owner        = "ValidateCompatibilityWithCurrentVersion";
	
	// Checking for a user task group. If the group is missing, adding it.
	UserTaskGroup = ToDoList.Find("ValidateCompatibilityWithCurrentVersion", "ID");
	If UserTaskGroup = Undefined Then
		UserTaskGroup              = ToDoList.Add();
		UserTaskGroup.ID           = "ValidateCompatibilityWithCurrentVersion";
		UserTaskGroup.HasUserTasks = UserTask.HasUserTasks;
		UserTaskGroup.Presentation = NStr("en = 'Check compatibility'");
		If UserTask.HasUserTasks Then
			UserTaskGroup.Quantity = UserTask.Quantity;
		EndIf;
		UserTaskGroup.Owner = Subsystem;
	Else
		If Not UserTaskGroup.HasUserTasks Then
			UserTaskGroup.HasUserTasks = UserTask.HasUserTasks;
		EndIf;
		
		If UserTask.HasUserTasks Then
			UserTaskGroup.Quantity = UserTaskGroup.Quantity + UserTask.Quantity;
		EndIf;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Handlers of conditional calls to other subsystems.

// Returns the mapping between session parameter names and their initialization handlers.
//
Procedure SessionParameterSettingHandlersOnAdd(Handlers) Export
	
	Handlers.Insert("DataExchangeMessageImportModeBeforeStart", "DataExchangeServerCall.SessionParametersSetting");
	
	Handlers.Insert("ORMCachedValueRefreshDate",        "DataExchangeServerCall.SessionParametersSetting");
	Handlers.Insert("SelectiveObjectChangeRecordRules", "DataExchangeServerCall.SessionParametersSetting");
	Handlers.Insert("ObjectChangeRecordRules",          "DataExchangeServerCall.SessionParametersSetting");
	Handlers.Insert("DataSynchronizationPasswords",     "DataExchangeServerCall.SessionParametersSetting");
	Handlers.Insert("PriorityExchangeData",             "DataExchangeServerCall.SessionParametersSetting");
	Handlers.Insert("VersionDifferenceErrorOnGetData",  "DataExchangeServerCall.SessionParametersSetting");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Handlers of conditional calls of other subsystems.

// Determines whether the batch object modification is used in the configuration.
//
// Parameters:
//  Used - Boolean - True if it is used, False otherwise.
//
Procedure OnDetermineBatchObjectModificationUsed(Used) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.BatchObjectModification") Then
		Used = True;
	EndIf;
	
EndProcedure

// Determines whether the modification prohibition by date subsystem is used in the configuration.
//
// Parameters:
//  Used - Boolean - True if it is used, False otherwise.
//
Procedure OnDetermineEditProhibitionDatesUsed(Used) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.EditProhibitionDates") Then
		Used = True;
	EndIf;
	
EndProcedure

// Sets the flag that shows whether the object version is ignored.
//
// Parameters:
// Ref           - object reference whose version is to be ignored. 
// VersionNumber - Number - version number of the object to be ignored.
// Ignore        - Boolean - flag that shows whether the version is ignored.
//
Procedure OnIgnoreObjectVersion(Ref, VersionNumber, Ignore) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.ObjectVersioning") Then
		ObjectVersioningModule = CommonUse.CommonModule("ObjectVersioning");
		ObjectVersioningModule.IgnoreObjectVersion(Ref, VersionNumber, Ignore);
	EndIf;
	
EndProcedure

// Object version update handler.
//
// Parameters:
// ObjectRef                    - Ref - reference to the object to be updated.
// VersionNumberToMigrate       - Number - version number to migrate.
// IgnoredVersionNumber         - Number - version number to ignore. 
// IgnoreChangeProhibitionCheck - Boolean - flag that shows whether the import prohibition date checking is skipped.
//
Procedure OnStartUsingNewObjectVersion(ObjectRef, VersionNumber) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.ObjectVersioning") Then
		ObjectVersioningModule = CommonUse.CommonModule("ObjectVersioning");
		ObjectVersioningModule.OnStartUsingNewObjectVersion(ObjectRef, VersionNumber);
	EndIf;
	
EndProcedure

// The UseDataSynchronization constant setup handler.
//
//  Parameters:
// Cancel - Boolean - cancellation flag.
//          If this parameter value is True, data synchronization is not to be enabled.
//
Procedure DataSynchronizationOnEnable(Cancel) Export
	
EndProcedure

// The flag clearing handler for the UseDataSynchronization constant.
//
//  Parameters:
//     Cancel - Boolean - flag shows whether the synchronization disabling is canceled.
//              If its value is True, the synchronization is not disabled.
//
Procedure DataSynchronizationOnDisable(Cancel) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaSOperations.DataExchangeSaaS") Then
		DataExchangeSaaSModule = CommonUse.CommonModule("DataExchangeSaaS");
		DataExchangeSaaSModule.DataSynchronizationOnDisable(Cancel);
	EndIf;
	
EndProcedure

// The "After getting recipients" event handler. It is used in the object registration mechanism.
// The event occurs in the transaction during data writing to the infobase when data change recipients 
// are defined by the object registration rules.
//
// Parameters:
//  Data             - object to write - a document, a catalog item, an account from the chart of accounts, a constant
//                     record manager, a register record set, and so on. 
//  Recipients       - Array - array of exchange plan nodes for registering changes of the current data.
//  ExchangePlanName - String - name of the exchange plan (as a metadata object)
//                     for which object registration rules are executed.
//
Procedure AfterGetRecipients(Data, Recipients, Val ExchangePlanName) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaSOperations.DataExchangeSaaS") Then
		DataExchangeSaaSModule = CommonUse.CommonModule("DataExchangeSaaS");
		DataExchangeSaaSModule.AfterGetRecipients(Data, Recipients, ExchangePlanName);
	EndIf;
	
EndProcedure

// The handler of the edit prohibition date skipping.
//
Procedure IgnoreChangeProhibitionCheck(Ignore = True) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.EditProhibitionDates") Then
		EditProhibitionDatesInternalModule = CommonUse.CommonModule("EditProhibitionDatesService");
		EditProhibitionDatesInternalModule.IgnoreChangeProhibitionCheck(Ignore);
	EndIf;
	
EndProcedure

Procedure OnContinueSubordinateDIBNodeSetup() Export

	SetPrivilegedMode(True);
	UsersInternal.ClearNonExistentInfobaseUserIDs();

EndProcedure


////////////////////////////////////////////////////////////////////////////////
// Data exchange execution.

// An entry point for performing the data exchange iteration (data export or import for the exchange plan node).
//
// Parameters:
//  Cancel                       - Boolean - cancellation flag. It is set to True if errors 
//                                 occur during the procedure execution.
//  InfobaseNode                 – ExchangePlanRef – exchange plan node, for which the 
//                                 data exchange iteration is performed.
//  PerformImport                – (Optional) Boolean – flag that shows whether data
//                                 import must be performed.
//  PerformExport                – (Optional) Boolean – flag that shows whether data
//                                 export must be performed.
//  ExchangeMessageTransportKind - (Optional) EnumRef.ExchangeMessageTransportKinds –
//                                 transport kind to be used for performing the data
//                                 exchange. 
// 							                     The default value is retrieved from the
//                                 ExchangeTransportSettings.Resource.DefaultExchangeMessageTransportKind
//                                 information register. If it is not specified,
//                                 Enums.ExchangeMessageTransportKinds.FILE is used 
//                                 as a default value.

// 
Procedure ExecuteDataExchangeForInfobaseNode(Cancel,
														Val InfobaseNode,
														Val PerformImport = True,
														Val PerformExport = True,
														Val ExchangeMessageTransportKind = Undefined,
														LongAction = False,
														ActionID = "",
														FileID = "",
														Val LongActionAllowed = False,
														Val AuthenticationParameters = Undefined,
														Val ParametersOnly = False
	) Export
	
	CheckCanSynchronizeData();
	
	CheckUseDataExchange();
	
	If ExchangeMessageTransportKind = Enums.ExchangeMessageTransportKinds.COM Then // Data exchange through external connection
		
		CheckExternalConnectionAvailable();
		
		If PerformImport Then
			
			// IMPORTING DATA THROUGH THE EXTERNAL CONNECTION
			ExecuteExchangeActionForInfobaseNodeByExternalConnection(Cancel, 
																	InfobaseNode, 
																	Enums.ActionsOnExchange.DataImport, 
																	Undefined);
			
		EndIf;
		
		If PerformExport Then
			
			// EXPORTING DATA THROUGH THE EXTERNAL CONNECTION
			ExecuteExchangeActionForInfobaseNodeByExternalConnection(Cancel, 
																	InfobaseNode, 
																	Enums.ActionsOnExchange.DataExport, 
																	Undefined);
			
		EndIf;
		
	ElsIf ExchangeMessageTransportKind = Enums.ExchangeMessageTransportKinds.WS Then // Data exchange through web service
		
		If PerformImport Then
			
			// IMPORTING DATA THROUGH THE WEB SERVICE
			ExecuteExchangeOverWebServiceActionForInfobaseNode(Cancel, 
																	InfobaseNode, 
																	Enums.ActionsOnExchange.DataImport, 
																	LongAction, 
																	ActionID, 
																	FileID,
																	LongActionAllowed,
																	AuthenticationParameters,
																	ParametersOnly);
			
		EndIf;
		
		If PerformExport Then
			
			// EXPORTING DATA THROUGH THE WEB SERVICE
			ExecuteExchangeOverWebServiceActionForInfobaseNode(Cancel, 
																	InfobaseNode, 
																	Enums.ActionsOnExchange.DataExport, 
																	LongAction, 
																	ActionID, 
																	FileID, 
																	LongActionAllowed,
																	AuthenticationParameters,
																	ParametersOnly);
			
		EndIf;
		
	Else // Exchange over regular communication channels
		
		If PerformImport Then
			
			// IMPORTING DATA
			ExecuteInfobaseNodeExchangeAction(Cancel,
															InfobaseNode,
															Enums.ActionsOnExchange.DataImport,
															ExchangeMessageTransportKind,
															ParametersOnly);
			
		EndIf;
		
		If PerformExport Then
			
			// EXPORTING DATA
			ExecuteInfobaseNodeExchangeAction(Cancel,
															InfobaseNode,
															Enums.ActionsOnExchange.DataExport,
															ExchangeMessageTransportKind,
															ParametersOnly);
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Performs data exchange either for a single settings row or for all rows at once.
// The data exchange process consists of two steps:
//  - Node initialization - preparing the data exchange subsystem to process the data
//                          exchange.
//  - Data exchange       - either reading the message file and importing data from this 
//                          file into the infobase or exporting the changes to the
//                          message file.
//
// The initialization step is performed once per session and then its result is saved in
// the session cache on the server until the session is restarted or reusable values of
// the data exchange subsystem are reset.
// Reusable values are reset when data that affects the data exchange process (such as 
// transport settings, exchange settings, or exchange plan node filters) is changed.
//
// The exchange can be performed for a single row or for each row in the scenario.
//
// Parameters:
//  Cancel                    - Boolean - cancellation flag. It is set to True if errors occur
//                              during the scenario execution.
//  ExchangeExecutionSettings - CatalogRef.DataExchangeScenarios - catalog item whose
//                              attribute values will be used for performing the data
//                              exchange.
//  LineNumber                - Number - row number, for which the exchange will be
//                              performed. If it is not specified, the data exchange
//                              will be performed for all rows.
//
Procedure ExecuteDataExchangeUsingDataExchangeScenario(Cancel, ExchangeExecutionSettings, LineNumber = Undefined) Export
	
	CheckCanSynchronizeData();
	
	CheckUseDataExchange();
	
	SetPrivilegedMode(True);
	
	QueryText = "
	|SELECT
	|	ExchangeExecutionSettingsExchangeSettings.Ref                    AS ExchangeExecutionSettings,
	|	ExchangeExecutionSettingsExchangeSettings.LineNumber             AS LineNumber,
	|	ExchangeExecutionSettingsExchangeSettings.CurrentAction          AS CurrentAction,
	|	ExchangeExecutionSettingsExchangeSettings.ExchangeTransportKind  AS ExchangeTransportKind,
	|	ExchangeExecutionSettingsExchangeSettings.InfobaseNode           AS InfobaseNode,
	|
	|	CASE WHEN ExchangeExecutionSettingsExchangeSettings.ExchangeTransportKind = VALUE(Enum.ExchangeMessageTransportKinds.COM)
	|	THEN TRUE
	|	ELSE FALSE
	|	END AS ExchangeOverExternalConnection,
	|
	|	CASE WHEN ExchangeExecutionSettingsExchangeSettings.ExchangeTransportKind = VALUE(Enum.ExchangeMessageTransportKinds.WS)
	|	THEN TRUE
	|	ELSE FALSE
	|	END AS ExchangeOverWebService
	|FROM
	|	Catalog.DataExchangeScenarios.ExchangeSettings AS ExchangeExecutionSettingsExchangeSettings
	|WHERE
	|	ExchangeExecutionSettingsExchangeSettings.Ref = &ExchangeExecutionSettings
	|	[LineNumberCondition]
	|ORDER BY
	|	ExchangeExecutionSettingsExchangeSettings.LineNumber
	|";
	
	LineNumberCondition = ?(LineNumber = Undefined, "", "AND ExchangeExecutionSettingsExchangeSettings.LineNumber = &LineNumber");
	
	QueryText = StrReplace(QueryText, "[LineNumberCondition]", LineNumberCondition);
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("ExchangeExecutionSettings", ExchangeExecutionSettings);
	Query.SetParameter("LineNumber", LineNumber);
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		If Selection.ExchangeOverExternalConnection Then
			
			CheckExternalConnectionAvailable();
			
			TransactionItemCount = ItemCountInExecutingActionTransaction(Selection.CurrentAction);
			
			ExecuteExchangeActionForInfobaseNodeByExternalConnection(Cancel, Selection.InfobaseNode, Selection.CurrentAction, TransactionItemCount);
			
		ElsIf Selection.ExchangeOverWebService Then
			
			ExecuteExchangeOverWebServiceActionForInfobaseNode(Cancel, Selection.InfobaseNode, Selection.CurrentAction);
			
		Else
			
			// INITIALIZING THE DATA EXCHANGE
			ExchangeSettingsStructure = DataExchangeCached.GetExchangeSettingsStructure(Selection.ExchangeExecutionSettings, Selection.LineNumber);
			
			// If settings contain errors, canceling the exchange
			If ExchangeSettingsStructure.Cancel Then
				
				Cancel = True;
				
				// Writing the message to the event log
				AddExchangeFinishEventLogMessage(ExchangeSettingsStructure);
				Continue;
			EndIf;
			
			ExchangeSettingsStructure.ExchangeExecutionResult = Undefined;
			ExchangeSettingsStructure.StartDate = CurrentSessionDate();
			
			// Adding the message about exchange start to the event log
			MessageString = NStr("en = 'Data exchange process started by %1 setting'", CommonUseClientServer.DefaultLanguageCode());
			MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, ExchangeSettingsStructure.ExchangeExecutionSettingsDescription);
			WriteEventLogDataExchange(MessageString, ExchangeSettingsStructure);
			
			// DATA EXCHANGE
			ExecuteDataExchangeOverFileResource(ExchangeSettingsStructure);
			
			// Writing the message to the event log
			AddExchangeFinishEventLogMessage(ExchangeSettingsStructure);
			
			If Not ExchangeExecutionResultCompleted(ExchangeSettingsStructure.ExchangeExecutionResult) Then
				
				Cancel = True;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

// An entry point for performing the data exchange using a scheduled job.
//
// Parameters:
//  ExchangeScenarioCode - String - DataExchangeScenarios catalog item code, for which the exchange will be executed.
// 
Procedure ExecuteDataExchangeWithScheduledJob(ExchangeScenarioCode) Export
	
	// OnScheduledJobStart is not
	// called because the necessary actions are executed privately.
	
	CheckCanSynchronizeData();
	
	CheckUseDataExchange();
	
	If Not ValueIsFilled(ExchangeScenarioCode) Then
		Raise NStr("en = 'Data exchange scenario is not specified.'");
	EndIf;
	
	QueryText = "
	|SELECT
	|	DataExchangeScenarios.Ref AS Ref
	|FROM
	|	Catalog.DataExchangeScenarios AS DataExchangeScenarios
	|WHERE
	|		 DataExchangeScenarios.Code = &Code
	|	AND Not DataExchangeScenarios.DeletionMark
	|";
	
	Query = New Query;
	Query.SetParameter("Code", ExchangeScenarioCode);
	Query.Text = QueryText;
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		// Performing the exchange using scenario
		ExecuteDataExchangeUsingDataExchangeScenario(False, Selection.Ref);
	Else
		MessageString = NStr("en = 'The data exchange script with the %1 code is not found.'");
		MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, ExchangeScenarioCode);
		Raise MessageString;
	EndIf;
	
EndProcedure

//

// Received the exchange message and puts it into the temporary OS directory.
//
// Parameters:
//  Cancel                       - Boolean - cancellation flag. It is set to True if errors
//                                 occur during the procedure execution.
//  InfobaseNode                 – ExchangePlanRef – exchange plan node, for which the
//                                 exchange message will be received.
//  ExchangeMessageTransportKind - EnumRef.ExchangeMessageTransportKinds – transport
//                                 kind for receiving the exchange messages.
//
// Returns:
//  Structure with the the following keys:
//  TempExchangeMessageDirectory – full exchange directory name where the exchange
//                                 message has been imported.
//  ExchangeMessageFileName      – full exchange message file name.
//  DataPackageFileID            – exchange message file change date.
//
Function GetExchangeMessageToTemporaryDirectory(Cancel, InfobaseNode, ExchangeMessageTransportKind, DisplayMessages = True) Export
	
	// Return value
	Result = New Structure;
	Result.Insert("TempExchangeMessageDirectory", "");
	Result.Insert("ExchangeMessageFileName",      "");
	Result.Insert("DataPackageFileID",            Undefined);

	
	ExchangeSettingsStructure = DataExchangeCached.GetTransportSettingsStructure(InfobaseNode, ExchangeMessageTransportKind);
	
	ExchangeSettingsStructure.ExchangeExecutionResult = Undefined;
	ExchangeSettingsStructure.StartDate = CurrentSessionDate();
	
	// Canceling message receiving and setting the exchange state to Canceled if settings contain errors
	If ExchangeSettingsStructure.Cancel Then
		
		If DisplayMessages Then
			NString = NStr("en = 'Error initializing exchange message transport processing.'");
			CommonUseClientServer.MessageToUser(NString,,,, Cancel);
		EndIf;
		
		AddExchangeFinishEventLogMessage(ExchangeSettingsStructure);
		Return Result;
	EndIf;
	
	// Creating a temporary directory
	ExecuteExchangeMessageTransportBeforeProcessing(ExchangeSettingsStructure);
	
	If ExchangeSettingsStructure.ExchangeExecutionResult = Undefined Then
		
		// Receiving the message and putting it to the temporary directory
		ExecuteExchangeMessageTransportReceiving(ExchangeSettingsStructure);
		
	EndIf;
	
	If ExchangeSettingsStructure.ExchangeExecutionResult <> Undefined Then
		
		If DisplayMessages Then
			NString = NStr("en = 'Error receiving exchange messages.'");
			CommonUseClientServer.MessageToUser(NString,,,, Cancel);
		EndIf;
		
		// Deleting temporary directory with all content
		ExecuteExchangeMessageTransportAfterProcessing(ExchangeSettingsStructure);
		
		AddExchangeFinishEventLogMessage(ExchangeSettingsStructure);
		Return Result;
	EndIf;
	
	Result.TempExchangeMessageDirectory = ExchangeSettingsStructure.ExchangeMessageTransportDataProcessor.ExchangeMessageDirectoryName();
	Result.ExchangeMessageFileName      = ExchangeSettingsStructure.ExchangeMessageTransportDataProcessor.ExchangeMessageFileName();
	Result.DataPackageFileID            = ExchangeSettingsStructure.ExchangeMessageTransportDataProcessor.ExchangeMessageFileDate();
	
	Return Result;
EndFunction

// Receives the exchange message from the correspondent infobase and puts it into the temporary OS directory.
//
// Parameters:
//  Cancel           - Boolean - cancellation flag. It is set to True if errors occur during the procedure execution. 
//  InfobaseNode     - ExchangePlanRef - exchange plan node for which the exchange message is received. 
//  DisplayMessages  - Boolean - if True, user messages are displayed.
//
//  Returns:
//   Structure with the the following keys:
//     * TempExchangeMessageDirectory - full exchange directory name where the exchange message has been imported.
//     * ExchangeMessageFileName      - full exchange message file name.
//     * DataPackageFileID            - exchange message file change date.
//
Function GetExchangeMessageFromCorrespondentInfobaseToTempDirectory(Cancel, InfobaseNode, DisplayMessages = True) Export
	
	// Return value
	Result = New Structure;
	Result.Insert("TempExchangeMessageDirectory", "");
	Result.Insert("ExchangeMessageFileName",      "");
	Result.Insert("DataPackageFileID",            Undefined);
	
	ExchangePlanName = DataExchangeCached.GetExchangePlanName(InfobaseNode);
	CurrentExchangePlanNode = DataExchangeCached.GetThisExchangePlanNode(ExchangePlanName);
	CurrentExchangePlanNodeCode = CommonUse.ObjectAttributeValue(CurrentExchangePlanNode, "Code");
	
	MessageFileNamePattern = GetMessageFileNamePattern(CurrentExchangePlanNode, InfobaseNode, False);
	
	// Parameters to be defined in the function
	ExchangeMessageFileDate = Date('00010101');
	ExchangeMessageDirectoryName = "";
	ErrorMessageString = "";
	
	Try
		ExchangeMessageDirectoryName = CreateTempExchangeMessageDirectory();
	Except
		If DisplayMessages Then
			Message = NStr("en = 'Errors occurred during the data exchange: %1'");
			Message = StringFunctionsClientServer.SubstituteParametersInString(Message, DetailErrorDescription(ErrorInfo()));
			CommonUseClientServer.MessageToUser(Message,,,, Cancel);
		EndIf;
		Return Result;
	EndTry;
	
	// Getting external connection for the infobase node
	ConnectionData = DataExchangeCached.ExternalConnectionForInfobaseNode(InfobaseNode);
	ExternalConnection = ConnectionData.Connection;
	
	If ExternalConnection = Undefined Then
		
		Message = NStr("en = 'Errors occurred during the data exchange: %1'");
		If DisplayMessages Then
			MessageForUser = StringFunctionsClientServer.SubstituteParametersInString(Message, ConnectionData.BriefErrorDetails);
			CommonUseClientServer.MessageToUser(MessageForUser,,,, Cancel);
		EndIf;
		
		// Adding two records to the event log: one for data import and one for data export
		ExchangeSettingsStructure = New Structure("EventLogMessageKey");
		ExchangeSettingsStructure.EventLogMessageKey = GetEventLogMessageKey(InfobaseNode, Enums.ActionsOnExchange.DataImport);
		
		Message = StringFunctionsClientServer.SubstituteParametersInString(Message, ConnectionData.DetailedErrorDetails);
		WriteEventLogDataExchange(Message, ExchangeSettingsStructure, True);
		
		Return Result;
	EndIf;
	
	ExchangeMessageFileName = CommonUseClientServer.GetFullFileName(ExchangeMessageDirectoryName, MessageFileNamePattern + ".xml");
	
	ExternalConnection.DataExchangeExternalConnection.ExportForInfobaseNode(Cancel, ExchangePlanName, CurrentExchangePlanNodeCode, ExchangeMessageFileName, ErrorMessageString);
	
	If Cancel Then
		
		If DisplayMessages Then
			// Displaying error message
			Message = NStr("en = 'Errors occurred during the data export: %1'");
			Message = StringFunctionsClientServer.SubstituteParametersInString(Message, ConnectionData.BriefErrorDetails);
			CommonUseClientServer.MessageToUser(Message,,,, Cancel);
		EndIf;
		
		Return Result;
	EndIf;
	
	FileExchangeMessages = New File(ExchangeMessageFileName);
	If FileExchangeMessages.Exist() Then
		ExchangeMessageFileDate = FileExchangeMessages.GetModificationTime();
	EndIf;
	
	Result.TempExchangeMessageDirectory = ExchangeMessageDirectoryName;
	Result.ExchangeMessageFileName      = ExchangeMessageFileName;
	Result.DataPackageFileID            = ExchangeMessageFileDate;
	
	Return Result;
EndFunction

// Receives the exchange message from the correspondent infobase over the web service and puts it into the temporary OS directory.
//
// Parameters:
//  Cancel                   - Boolean - cancellation flag. 
//                             It is set to True if errors occur during the procedure execution. 
//  InfobaseNode             - ExchangePlanRef - exchange plan node for which the exchange message is received. 
//  FileID                   - UUID - file ID.
//  LongAction               - Boolean - flag that shows whether the long action is used.
//  ActionID                 - UUID - long action UUID.
//  AuthenticationParameters - Structure. Contains parameters of authentication on the web service (User, Password).
//
//  Returns:
//   Structure with the the following keys:
//     * TempExchangeMessageDirectory - full exchange directory name where the exchange message has been imported.
//     * ExchangeMessageFileName      - full exchange message file name. 
//     * DataPackageFileID            - exchange message file change date.
//
Function GetExchangeMessageToTempDirectoryFromCorrespondentInfobaseOverWebService(
											Cancel,
											InfobaseNode,
											FileID,
											LongAction,
											ActionID,
											AuthenticationParameters = Undefined
	) Export
	
	CheckCanSynchronizeData();
	
	CheckUseDataExchange();
	
	SetPrivilegedMode(True);
	
	// Return value
	Result = New Structure;
	Result.Insert("TempExchangeMessageDirectory", "");
	Result.Insert("ExchangeMessageFileName",      "");
	Result.Insert("DataPackageFileID",            Undefined);
	
	ExchangePlanName = DataExchangeCached.GetExchangePlanName(InfobaseNode);
	CurrentExchangePlanNode = DataExchangeCached.GetThisExchangePlanNode(ExchangePlanName);
	CurrentExchangePlanNodeCode = CommonUse.ObjectAttributeValue(CurrentExchangePlanNode, "Code");
	
	// Parameters to be defined in the function
	ExchangeMessageDirectoryName = "";
	ExchangeMessageFileName = "";
	ExchangeMessageFileDate = Date('00010101');
	ErrorMessageString = "";
	
	// Getting the web service proxy for the infobase node
	Proxy = GetWSProxyForInfobaseNode(InfobaseNode, ErrorMessageString, AuthenticationParameters);
	
	If Proxy = Undefined Then
		
		Cancel = True;
		Message = NStr("en = 'Error establishing connection with the correspondent infobase: %1'");
		Message = StringFunctionsClientServer.SubstituteParametersInString(Message, ErrorMessageString);
		ExchangeSettingsStructure = New Structure("EventLogMessageKey");
		ExchangeSettingsStructure.EventLogMessageKey = GetEventLogMessageKey(InfobaseNode, Enums.ActionsOnExchange.DataImport);
		WriteEventLogDataExchange(Message, ExchangeSettingsStructure, True);
		
		Return Result;
	EndIf;
	
	Try
		
		Proxy.ExecuteDataExport(
			ExchangePlanName,
			CurrentExchangePlanNodeCode,
			FileID,
			LongAction,
			ActionID,
			True);
		
	Except
		
		Cancel = True;
		Message = NStr("en = 'Error exporting data in the correspondent infobase: %1'", CommonUseClientServer.DefaultLanguageCode());
		Message = StringFunctionsClientServer.SubstituteParametersInString(Message, DetailErrorDescription(ErrorInfo()));
		ExchangeSettingsStructure = New Structure("EventLogMessageKey");
		ExchangeSettingsStructure.EventLogMessageKey = GetEventLogMessageKey(InfobaseNode, Enums.ActionsOnExchange.DataImport);
		WriteEventLogDataExchange(Message, ExchangeSettingsStructure, True);
		
		Return Result;
	EndTry;
	
	If LongAction Then
		ExchangeSettingsStructure = New Structure("EventLogMessageKey");
		ExchangeSettingsStructure.EventLogMessageKey = GetEventLogMessageKey(InfobaseNode, Enums.ActionsOnExchange.DataImport);
		WriteEventLogDataExchange(NStr("en = 'Waiting for data from the correspondent infobase...'",
			CommonUseClientServer.DefaultLanguageCode()), ExchangeSettingsStructure);
		Return Result;
	EndIf;
	
	Try
		FileTransferServiceFileName = GetFileFromStorageInService(New UUID(FileID), InfobaseNode,, AuthenticationParameters);
	Except
		
		Cancel = True;
		Message = NStr("en = 'Error receiving exchange message from the file transfer service: %1'", CommonUseClientServer.DefaultLanguageCode());
		Message = StringFunctionsClientServer.SubstituteParametersInString(Message, DetailErrorDescription(ErrorInfo()));
		ExchangeSettingsStructure = New Structure("EventLogMessageKey");
		ExchangeSettingsStructure.EventLogMessageKey = GetEventLogMessageKey(InfobaseNode, Enums.ActionsOnExchange.DataImport);
		WriteEventLogDataExchange(Message, ExchangeSettingsStructure, True);
		
		Return Result;
	EndTry;
	
	Try
		ExchangeMessageDirectoryName = CreateTempExchangeMessageDirectory();
	Except
		Cancel = True;
		Message = NStr("en = 'Error receiving exchange message: %1'", CommonUseClientServer.DefaultLanguageCode());
		Message = StringFunctionsClientServer.SubstituteParametersInString(Message, DetailErrorDescription(ErrorInfo()));
		ExchangeSettingsStructure = New Structure("EventLogMessageKey");
		ExchangeSettingsStructure.EventLogMessageKey = GetEventLogMessageKey(InfobaseNode, Enums.ActionsOnExchange.DataImport);
		WriteEventLogDataExchange(Message, ExchangeSettingsStructure, True);
		
		Return Result;
	EndTry;
	
	MessageFileNamePattern = GetMessageFileNamePattern(CurrentExchangePlanNode, InfobaseNode, False);
	
	ExchangeMessageFileName = CommonUseClientServer.GetFullFileName(ExchangeMessageDirectoryName, MessageFileNamePattern + ".xml");
	
	MoveFile(FileTransferServiceFileName, ExchangeMessageFileName);
	
	FileExchangeMessages = New File(ExchangeMessageFileName);
	If FileExchangeMessages.Exist() Then
		ExchangeMessageFileDate = FileExchangeMessages.GetModificationTime();
	EndIf;
	
	Result.TempExchangeMessageDirectory = ExchangeMessageDirectoryName;
	Result.ExchangeMessageFileName      = ExchangeMessageFileName;
	Result.DataPackageFileID            = ExchangeMessageFileDate;
	
	Return Result;
EndFunction

// The function receives an exchange message from correspondent infobase over a web service
// and saves the received exchange message to the temporary directory.
// It used if the exchange message receiving performed with background job in a correspondent infobase.
//
// Parameters:
//  Cancel                   - Boolean - cancellation flag. 
//                             It is set to True if errors occur during the procedure execution. 
//  InfobaseNode             - ExchangePlanRef - exchange plan node for which the exchange message is received.
//  FileID                   - UUID - file ID.
//  AuthenticationParameters - Structure. Contains parameters of authentication on the web service (User, Password).
//
//  Returns:
//   Structure with the the following keys:
//     * TempExchangeMessageDirectory - full exchange directory name where the exchange message has been imported.
//     * ExchangeMessageFileName      - full exchange message file name. 
//     * DataPackageFileID            - exchange message file change date.
//
Function GetExchangeMessageToTempDirectoryFromCorrespondentInfobaseOverWebServiceFinishLongAction(
							Cancel,
							InfobaseNode,
							FileID,
							Val AuthenticationParameters = Undefined
	) Export
	
	// Return value
	Result = New Structure;
	Result.Insert("TempExchangeMessageDirectory", "");
	Result.Insert("ExchangeMessageFileName",      "");
	Result.Insert("DataPackageFileID",            Undefined);
	
	// Parameters to be defined in the function
	ExchangeMessageDirectoryName = "";
	ExchangeMessageFileName = "";
	ExchangeMessageFileDate = Date('00010101');
	ErrorMessageString = "";
	
	Try
		
		FileTransferServiceFileName = GetFileFromStorageInService(New UUID(FileID), InfobaseNode,, AuthenticationParameters);
	Except
		
		Cancel = True;
		Message = NStr("en = 'Error receiving exchange message from the file transfer service: %1'", CommonUseClientServer.DefaultLanguageCode());
		Message = StringFunctionsClientServer.SubstituteParametersInString(Message, DetailErrorDescription(ErrorInfo()));
		ExchangeSettingsStructure = New Structure("EventLogMessageKey");
		ExchangeSettingsStructure.EventLogMessageKey = GetEventLogMessageKey(InfobaseNode, Enums.ActionsOnExchange.DataImport);
		WriteEventLogDataExchange(Message, ExchangeSettingsStructure, True);
		
		Return Result;
	EndTry;
	
	Try
		ExchangeMessageDirectoryName = CreateTempExchangeMessageDirectory();
	Except
		Cancel = True;
		Message = NStr("en = 'Error receiving exchange message: %1'", CommonUseClientServer.DefaultLanguageCode());
		Message = StringFunctionsClientServer.SubstituteParametersInString(Message, DetailErrorDescription(ErrorInfo()));
		ExchangeSettingsStructure = New Structure("EventLogMessageKey");
		ExchangeSettingsStructure.EventLogMessageKey = GetEventLogMessageKey(InfobaseNode, Enums.ActionsOnExchange.DataImport);
		WriteEventLogDataExchange(Message, ExchangeSettingsStructure, True);
		
		Return Result;
	EndTry;
	
	ExchangePlanName = DataExchangeCached.GetExchangePlanName(InfobaseNode);
	CurrentExchangePlanNode = DataExchangeCached.GetThisExchangePlanNode(ExchangePlanName);
	
	MessageFileNamePattern = GetMessageFileNamePattern(CurrentExchangePlanNode, InfobaseNode, False);
	
	ExchangeMessageFileName = CommonUseClientServer.GetFullFileName(ExchangeMessageDirectoryName, MessageFileNamePattern + ".xml");
	
	MoveFile(FileTransferServiceFileName, ExchangeMessageFileName);
	
	FileExchangeMessages = New File(ExchangeMessageFileName);
	If FileExchangeMessages.Exist() Then
		ExchangeMessageFileDate = FileExchangeMessages.GetModificationTime();
	EndIf;
	
	Result.TempExchangeMessageDirectory = ExchangeMessageDirectoryName;
	Result.ExchangeMessageFileName      = ExchangeMessageFileName;
	Result.DataPackageFileID            = ExchangeMessageFileDate;
	
	Return Result;
EndFunction

// Gets an exchange message file from a correspondent infobase over a web service.
// Imports the exchange message file to the current infobase.
//
// Parameters:
//  Cancel                   - Boolean - cancellation flag. 
//                             It is set to True if errors occur during the procedure execution. 
//  InfobaseNode             - ExchangePlanRef - exchange plan node for which the exchange message is received.
//  FileID                   - UUID - file ID.
//  ActionStartDate          - Date - import start date.
//  AuthenticationParameters - Structure. Contains parameters of authentication on the web service (User, Password).
//
Procedure ExecuteDataExchangeForInfobaseNodeFinishLongAction(
															Cancel,
															Val InfobaseNode,
															Val FileID,
															Val ActionStartDate,
															Val AuthenticationParameters = Undefined
	) Export
	
	CheckCanSynchronizeData();
	
	CheckUseDataExchange();
	
	SetPrivilegedMode(True);
	
	Try
		FileExchangeMessages = GetFileFromStorageInService(New UUID(FileID), InfobaseNode,, AuthenticationParameters);
	Except
		AddExchangeFinishedWithErrorEventLogMessage(InfobaseNode,
		Enums.ActionsOnExchange.DataImport,
		ActionStartDate,
		DetailErrorDescription(ErrorInfo()));
		Cancel = True;
		Return;
	EndTry;
	
	// Importing the exchange message file into the current infobase
	Try
		ExecuteDataExchangeForInfobaseNodeOverFileOrString(
			InfobaseNode,
			FileExchangeMessages,
			Enums.ActionsOnExchange.DataImport,,,, ActionStartDate);
	Except
		AddExchangeFinishedWithErrorEventLogMessage(InfobaseNode,
		Enums.ActionsOnExchange.DataImport,
		ActionStartDate,
		DetailErrorDescription(ErrorInfo()));
		Cancel = True;
	EndTry;
	
	Try
		DeleteFiles(FileExchangeMessages);
	Except
	EndTry;
	
EndProcedure

// Deletes exchange message files that are not deleted because of system failures.
// These files are stored more than 24 hours ago (calculated based on the universal current date).
// The procedure analyzes InformationRegister.DataExchangeMessages and InformationRegister.DataAreaDataExchangeMessages.
//
Procedure DeleteObsoleteExchangeMessage() Export
	
	CommonUse.ScheduledJobOnStart();
	
	CheckExchangeManagementRights();
	
	SetPrivilegedMode(True);
	
	// Deleting obsolete exchange messages that are marked in InformationRegister.DataExchangeMessages
	QueryText =
	"SELECT
	|	DataExchangeMessages.MessageID AS MessageID,
	|	DataExchangeMessages.MessageFileName AS FileName
	|FROM
	|	InformationRegister.DataExchangeMessages AS DataExchangeMessages
	|WHERE
	|	DataExchangeMessages.MessageSendingDate < &UpdateDate";
	
	Query = New Query;
	Query.SetParameter("UpdateDate", CurrentUniversalDate() - 60 * 60 * 24);
	Query.Text = QueryText;
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		MessageFileFullName = CommonUseClientServer.GetFullFileName(TempFileStorageDirectory(), Selection.FileName);
		
		MessageFile = New File(MessageFileFullName);
		
		If MessageFile.Exist() Then
			
			Try
				DeleteFiles(MessageFile.FullName);
			Except
				WriteLogEvent(EventLogMessageTextDataExchange(),
					EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
				Continue;
			EndTry;
		EndIf;
		
		// Deleting information about a message file from the storage
		RecordStructure = New Structure;
		RecordStructure.Insert("MessageID", String(Selection.MessageID));
		InformationRegisters.DataExchangeMessages.DeleteRecord(RecordStructure);
		
	EndDo;
	
	// Deleting obsolete exchange messages that are marked in InformationRegister.DataAreaDataExchangeMessages
	If CommonUse.SubsystemExists("StandardSubsystems.SaaSOperations.DataExchangeSaaS") Then
		DataExchangeSaaSModule = CommonUse.CommonModule("DataExchangeSaaS");
		DataExchangeSaaSModule.OnDeleteObsoleteExchangeMessages();
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for working via an external connection.

// For internal use.
// 
Procedure ExportToTempStorageForInfobaseNode(Val ExchangePlanName, Val InfobaseNodeCode, Address) Export
	
	ExchangeMessageFullFileName = GetTempFileName("xml");
	
	ExecuteDataExchangeForInfobaseNodeOverFileOrString(
		Undefined,
		ExchangeMessageFullFileName,
		Enums.ActionsOnExchange.DataExport,
		ExchangePlanName,
		InfobaseNodeCode);
	
	Address = PutToTempStorage(New BinaryData(ExchangeMessageFullFileName));
	
	Try
		DeleteFiles(ExchangeMessageFullFileName);
	Except
	EndTry;
	
EndProcedure

// For internal use.
// 
Procedure ExportToFileTransferServiceForInfobaseNode(Val ExchangePlanName,
	Val InfobaseNodeCode,
	Val FileID) Export
	
	SetPrivilegedMode(True);
	
	MessageFileName = CommonUseClientServer.GetFullFileName(
		TempFileStorageDirectory(),
		UniqueExchangeMessageFileName());
	
	ExecuteDataExchangeForInfobaseNodeOverFileOrString(
		Undefined,
		MessageFileName,
		Enums.ActionsOnExchange.DataExport,
		ExchangePlanName,
		InfobaseNodeCode);
	
	PutFileToStorage(MessageFileName, FileID);
	
EndProcedure

// For internal use.
// 
Procedure ExportForInfobaseNodeViaFile(Val ExchangePlanName,
	Val InfobaseNodeCode,
	Val ExchangeMessageFullFileName) Export
	
	ExecuteDataExchangeForInfobaseNodeOverFileOrString(
		Undefined,
		ExchangeMessageFullFileName,
		Enums.ActionsOnExchange.DataExport,
		ExchangePlanName,
		InfobaseNodeCode);
	
EndProcedure

// For internal use.
// 
Procedure ExportForInfobaseNodeViaString(Val ExchangePlanName, Val InfobaseNodeCode, ExchangeMessage) Export
	
	ExecuteDataExchangeForInfobaseNodeOverFileOrString(Undefined,
												"",
												Enums.ActionsOnExchange.DataExport,
												ExchangePlanName,
												InfobaseNodeCode,
												ExchangeMessage);
	
EndProcedure

// For internal use.
// 
Procedure ImportForInfobaseNodeViaString(Val ExchangePlanName, Val InfobaseNodeCode, ExchangeMessage) Export
	
	ExecuteDataExchangeForInfobaseNodeOverFileOrString(Undefined,
												"",
												Enums.ActionsOnExchange.DataImport,
												ExchangePlanName,
												InfobaseNodeCode,
												ExchangeMessage);
	
EndProcedure

// For internal use.
// 
Procedure ImportForInfobaseNodeFromFileTransferService(Val ExchangePlanName,
	Val InfobaseNodeCode,
	Val FileID) Export
	
	SetPrivilegedMode(True);
	
	TempFileName = GetFileFromStorage(FileID);
	
	Try
		ExecuteDataExchangeForInfobaseNodeOverFileOrString(
			Undefined,
			TempFileName,
			Enums.ActionsOnExchange.DataImport,
			ExchangePlanName,
			InfobaseNodeCode);
	Except
		ErrorPresentation = DetailErrorDescription(ErrorInfo());
		Try
			DeleteFiles(TempFileName);
		Except
		EndTry;
		Raise ErrorPresentation;
	EndTry;
	
	Try
		DeleteFiles(TempFileName);
	Except
	EndTry;
	
EndProcedure

// For internal use.
// 
Procedure ExecuteDataExchangeForInfobaseNodeOverFileOrString(InfobaseNode = Undefined,
																			ExchangeMessageFullFileName = "",
																			ActionOnExchange,
																			ExchangePlanName = "",
																			InfobaseNodeCode = "",
																			ExchangeMessage = "",
																			ActionStartDate = Undefined
	) Export
	
	CheckCanSynchronizeData();
	
	CheckUseDataExchange();
	
	SetPrivilegedMode(True);
	
	If InfobaseNode = Undefined Then
		
		InfobaseNode = ExchangePlans[ExchangePlanName].FindByCode(InfobaseNodeCode);
		
		If InfobaseNode.IsEmpty() Then
			ErrorMessageString = NStr("en = 'The %1 exchange plan node with the %2 code is not found.'");
			ErrorMessageString = StringFunctionsClientServer.SubstituteParametersInString(ErrorMessageString, ExchangePlanName, InfobaseNodeCode);
			Raise ErrorMessageString;
		EndIf;
		
	EndIf;
	
	// INITIALIZING THE DATA EXCHANGE
	ExchangeSettingsStructure = DataExchangeCached.GetExchangeSettingStructureForInfobaseNode(InfobaseNode, ActionOnExchange, Undefined, False);
	
	If ExchangeSettingsStructure.Cancel Then
		ErrorMessageString = NStr("en = 'Error initializing data exchange process.'");
		AddExchangeFinishEventLogMessage(ExchangeSettingsStructure);
		Raise ErrorMessageString;
	EndIf;
	
	ExchangeSettingsStructure.ExchangeExecutionResult = Undefined;
	ExchangeSettingsStructure.StartDate = ?(ActionStartDate = Undefined, CurrentSessionDate(), ActionStartDate);
	
	MessageString = NStr("en = 'Data exchange process started for %1 node'", CommonUseClientServer.DefaultLanguageCode());
	MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, ExchangeSettingsStructure.InfobaseNodeDescription);
	WriteEventLogDataExchange(MessageString, ExchangeSettingsStructure);
	
	If ExchangeSettingsStructure.DoDataImport Then
		
		If ExchangeSettingsStructure.IsDIBExchange
		   And ExchangeMessageFullFileName = ""
		   And ExchangeMessage <> "" Then
			
			ExchangeMessageFullFileName = GetTempFileName(".xml");
			TextFile = New TextDocument;
			TextFile.SetText(ExchangeMessage);
			TextFile.Write(ExchangeMessageFullFileName);
		EndIf;
		
		ReadMessageWithNodeChanges(ExchangeSettingsStructure, ExchangeMessageFullFileName, ExchangeMessage);
		
		// {Handler: AfterExchangeMessageRead} Begin
		StandardProcessing = True;
		
		AfterExchangeMessageRead(
					ExchangeSettingsStructure.InfobaseNode,
					ExchangeMessageFullFileName,
					ExchangeExecutionResultCompleted(ExchangeSettingsStructure.ExchangeExecutionResult),
					StandardProcessing);
		// {Handler: AfterExchangeMessageRead} End
		
	ElsIf ExchangeSettingsStructure.DoDataExport Then
		
		WriteMessageWithNodeChanges(ExchangeSettingsStructure, ExchangeMessageFullFileName, ExchangeMessage);
		
	EndIf;
	
	AddExchangeFinishEventLogMessage(ExchangeSettingsStructure);
	
	If Not ExchangeExecutionResultCompleted(ExchangeSettingsStructure.ExchangeExecutionResult) Then
		Raise ExchangeSettingsStructure.ErrorMessageString;
	EndIf;
	
EndProcedure

// For internal use.
// 
Procedure AddExchangeOverExternalConnectionFinishEventLogMessage(ExchangeSettingsStructure) Export
	
	SetPrivilegedMode(True);
	
	AddExchangeFinishEventLogMessage(ExchangeSettingsStructure);
	
EndProcedure

// For internal use.
// 
Function ExchangeOverExternalConnectionSettingsStructure(Structure) Export
	
	CheckUseDataExchange();
	
	SetPrivilegedMode(True);
	
	InfobaseNode = ExchangePlans[Structure.ExchangePlanName].FindByCode(Structure.CurrentExchangePlanNodeCode);
	
	ActionOnExchange = Enums.ActionsOnExchange[Structure.ExchangeActionString];
	
	ExchangeSettingsStructureExternalConnection = New Structure;
	ExchangeSettingsStructureExternalConnection.Insert("ExchangePlanName",              Structure.ExchangePlanName);
	ExchangeSettingsStructureExternalConnection.Insert("DebugMode",                     Structure.DebugMode);
	
	ExchangeSettingsStructureExternalConnection.Insert("InfobaseNode",                  InfobaseNode);
	ExchangeSettingsStructureExternalConnection.Insert("InfobaseNodeDescription",       CommonUse.ObjectAttributeValue(InfobaseNode, "Description"));
	
	ExchangeSettingsStructureExternalConnection.Insert("EventLogMessageKey",            GetEventLogMessageKey(InfobaseNode, ActionOnExchange));
	
	ExchangeSettingsStructureExternalConnection.Insert("ExchangeExecutionResult",       Undefined);
	ExchangeSettingsStructureExternalConnection.Insert("ExchangeExecutionResultString", "");
	
	ExchangeSettingsStructureExternalConnection.Insert("ActionOnExchange",              ActionOnExchange);
	
	ExchangeSettingsStructureExternalConnection.Insert("ExportHandlerDebug ",                      False);
	ExchangeSettingsStructureExternalConnection.Insert("ImportHandlerDebug",                       False);
	ExchangeSettingsStructureExternalConnection.Insert("ExportDebugExternalDataProcessorFileName", "");
	ExchangeSettingsStructureExternalConnection.Insert("ImportDebugExternalDataProcessorFileName", "");
	ExchangeSettingsStructureExternalConnection.Insert("DataExchangeLoggingMode",                  False);
	ExchangeSettingsStructureExternalConnection.Insert("ExchangeLogFileName",                      "");
	ExchangeSettingsStructureExternalConnection.Insert("ContinueOnError",                          False);
	
	SetDebugModeSettingsForStructure(ExchangeSettingsStructureExternalConnection, True);
	
	ExchangeSettingsStructureExternalConnection.Insert("ProcessedObjectCount", 0);
	
	ExchangeSettingsStructureExternalConnection.Insert("StartDate", Undefined);
	ExchangeSettingsStructureExternalConnection.Insert("EndDate",   Undefined);
	
	ExchangeSettingsStructureExternalConnection.Insert("ExchangeMessage",    "");
	ExchangeSettingsStructureExternalConnection.Insert("ErrorMessageString", "");
	
	ExchangeSettingsStructureExternalConnection.Insert("TransactionItemCount", Structure.TransactionItemCount);
	
	ExchangeSettingsStructureExternalConnection.Insert("IsDIBExchange", False);
	
	Return ExchangeSettingsStructureExternalConnection;
EndFunction

// For internal use.
// 
Function GetObjectConversionRulesViaExternalConnection(ExchangePlanName) Export
	
	SetPrivilegedMode(True);
	
	Return InformationRegisters.DataExchangeRules.GetReadObjectConversionRules(ExchangePlanName);
	
EndFunction

// For internal use.
// 
Procedure ExecuteInfobaseNodeExchangeAction(
		Cancel,
		InfobaseNode,
		ActionOnExchange,
		ExchangeMessageTransportKind = Undefined,
		Val ParametersOnly = False
	) Export
	
	SetPrivilegedMode(True);
	
	// INITIALIZING THE DATA EXCHANGE
	ExchangeSettingsStructure = DataExchangeCached.GetExchangeSettingStructureForInfobaseNode(
		InfobaseNode, ActionOnExchange, ExchangeMessageTransportKind);
	
	If ExchangeSettingsStructure.Cancel Then
		
		// If settings contain errors, canceling the exchange
		AddExchangeFinishEventLogMessage(ExchangeSettingsStructure);
		
		Cancel = True;
		
		Return;
	EndIf;
	
	ExchangeSettingsStructure.ExchangeExecutionResult = Undefined;
	ExchangeSettingsStructure.StartDate = CurrentSessionDate();
	
	MessageString = NStr("en = 'Data exchange process started for %1 node'", CommonUseClientServer.DefaultLanguageCode());
	MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, ExchangeSettingsStructure.InfobaseNodeDescription);
	WriteEventLogDataExchange(MessageString, ExchangeSettingsStructure);
	
	// DATA EXCHANGE
	ExecuteDataExchangeOverFileResource(ExchangeSettingsStructure, ParametersOnly);
	
	AddExchangeFinishEventLogMessage(ExchangeSettingsStructure);
	
	If Not ExchangeExecutionResultCompleted(ExchangeSettingsStructure.ExchangeExecutionResult) Then
		
		Cancel = True;
		
	EndIf;
	
EndProcedure

// For internal use.
// 
Procedure ExecuteExchangeOverWebServiceActionForInfobaseNode(Cancel,
																		InfobaseNode,
																		ActionOnExchange,
																		LongAction = False,
																		ActionID = "",
																		FileID = "",
																		LongActionAllowed = False,
																		AuthenticationParameters = Undefined,
																		Val ParametersOnly = False)
	
	SetPrivilegedMode(True);
	
	// INITIALIZING THE DATA EXCHANGE
	ExchangeSettingsStructure = DataExchangeCached.GetExchangeSettingStructureForInfobaseNode(InfobaseNode, ActionOnExchange, Enums.ExchangeMessageTransportKinds.WS, False);
	
	If ExchangeSettingsStructure.Cancel Then
		// If settings contain errors, canceling the exchange
		AddExchangeFinishEventLogMessage(ExchangeSettingsStructure);
		Cancel = True;
		Return;
	EndIf;
	
	ExchangeSettingsStructure.ExchangeExecutionResult = Undefined;
	ExchangeSettingsStructure.StartDate = CurrentSessionDate();
	
	MessageString = NStr("en = 'Data exchange process started for %1 node'", CommonUseClientServer.DefaultLanguageCode());
	MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, ExchangeSettingsStructure.InfobaseNodeDescription);
	WriteEventLogDataExchange(MessageString, ExchangeSettingsStructure);
	
	If ExchangeSettingsStructure.DoDataImport Then
		
		If ExchangeSettingsStructure.UseLargeDataTransfer Then
			
			// {Handler: BeforeExchangeMessageRead} Begin
			FileExchangeMessages = "";
			StandardProcessing = True;
			
			BeforeExchangeMessageRead(ExchangeSettingsStructure.InfobaseNode, FileExchangeMessages, StandardProcessing);
			// {Handler: BeforeExchangeMessageRead} End
			
			If StandardProcessing Then
				
				ErrorMessageString = "";
				
				// Getting the web service proxy for the infobase node
				Proxy = GetWSProxyForInfobaseNode(InfobaseNode, ErrorMessageString, AuthenticationParameters);
				
				If Proxy = Undefined Then
					
					// Writing the message to the event log
					WriteEventLogDataExchange(ErrorMessageString, ExchangeSettingsStructure, True);
					
					// If settings contain errors, canceling the exchange
					ExchangeSettingsStructure.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Canceled;
					AddExchangeFinishEventLogMessage(ExchangeSettingsStructure);
					Cancel = True;
					Return;
				EndIf;
				
				FileExchangeMessages = "";
				
				Try
					
					Proxy.ExecuteDataExport(ExchangeSettingsStructure.ExchangePlanName,
									ExchangeSettingsStructure.CurrentExchangePlanNodeCode,
									FileID,
									LongAction,
									ActionID,
									LongActionAllowed);
					
					If LongAction Then
						WriteEventLogDataExchange(NStr("en = 'Waiting for data from the correspondent infobase...'",
							CommonUseClientServer.DefaultLanguageCode()), ExchangeSettingsStructure);
						Return;
					EndIf;
					
					FileExchangeMessages = GetFileFromStorageInService(New UUID(FileID), InfobaseNode,, AuthenticationParameters);
				Except
					WriteEventLogDataExchange(DetailErrorDescription(ErrorInfo()), ExchangeSettingsStructure, True);
					ExchangeSettingsStructure.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Error;
					Cancel = True;
				EndTry;
				
			EndIf;
			
			If Not Cancel Then
				
				ReadMessageWithNodeChanges(ExchangeSettingsStructure, FileExchangeMessages,, ParametersOnly);
				
			EndIf;
			
			// {Handler: AfterExchangeMessageRead} Begin
			StandardProcessing = True;
			
			AfterExchangeMessageRead(
						ExchangeSettingsStructure.InfobaseNode,
						FileExchangeMessages,
						ExchangeExecutionResultCompleted(ExchangeSettingsStructure.ExchangeExecutionResult),
						StandardProcessing,
						Not ParametersOnly);
			// {Handler: AfterExchangeMessageRead} End
			
			If StandardProcessing Then
				
				Try
					If Not IsBlankString(FileExchangeMessages) Then
						DeleteFiles(FileExchangeMessages);
					EndIf;
				Except
					WriteLogEvent(EventLogMessageTextDataExchange(),
						EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
				EndTry;
				
			EndIf;
			
		Else
			
			ErrorMessageString = "";
			
			// Getting the web service proxy for the infobase node
			Proxy = GetWSProxyForInfobaseNode(InfobaseNode, ErrorMessageString, AuthenticationParameters);
			
			If Proxy = Undefined Then
				
				// Writing the message to the event log
				WriteEventLogDataExchange(ErrorMessageString, ExchangeSettingsStructure, True);
				
				// If settings contain errors, canceling the exchange
				ExchangeSettingsStructure.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Canceled;
				AddExchangeFinishEventLogMessage(ExchangeSettingsStructure);
				Cancel = True;
				Return;
			EndIf;
			
			ExchangeMessageStorage = Undefined;
			
			Try
				Proxy.ExecuteExport(ExchangeSettingsStructure.ExchangePlanName, ExchangeSettingsStructure.CurrentExchangePlanNodeCode, ExchangeMessageStorage);
				
				ReadMessageWithNodeChanges(ExchangeSettingsStructure,, ExchangeMessageStorage.Get());
				
			Except
				WriteEventLogDataExchange(DetailErrorDescription(ErrorInfo()), ExchangeSettingsStructure, True);
				ExchangeSettingsStructure.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Error;
			EndTry;
			
		EndIf;
		
	ElsIf ExchangeSettingsStructure.DoDataExport Then
		
		ErrorMessageString = "";
		
		// Getting the web service proxy for the infobase node
		Proxy = GetWSProxyForInfobaseNode(InfobaseNode, ErrorMessageString, AuthenticationParameters);
		
		If Proxy = Undefined Then
			
			// Writing the message to the event log
			WriteEventLogDataExchange(ErrorMessageString, ExchangeSettingsStructure, True);
			
			// If settings contain errors, canceling the exchange
			ExchangeSettingsStructure.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Canceled;
			AddExchangeFinishEventLogMessage(ExchangeSettingsStructure);
			Cancel = True;
			Return;
		EndIf;
		
		If ExchangeSettingsStructure.UseLargeDataTransfer Then
			
			FileExchangeMessages = CommonUseClientServer.GetFullFileName(TempFileStorageDirectory(), UniqueExchangeMessageFileName());
			
			WriteMessageWithNodeChanges(ExchangeSettingsStructure, FileExchangeMessages);
			
			// Sending exchange messages only if data is exported successfully
			If ExchangeExecutionResultCompleted(ExchangeSettingsStructure.ExchangeExecutionResult) Then
				
				Try
					
					FileIDString = String(PutFileToStorageInService(FileExchangeMessages, InfobaseNode,, AuthenticationParameters));
					
					Try
						DeleteFiles(FileExchangeMessages);
					Except
					EndTry;
					
					Proxy.ExecuteDataImport(ExchangeSettingsStructure.ExchangePlanName,
									ExchangeSettingsStructure.CurrentExchangePlanNodeCode,
									FileIDString,
									LongAction,
									ActionID,
									LongActionAllowed);
					
					If LongAction Then
						WriteEventLogDataExchange(NStr("en = 'Waiting for data import in correspondent infobase...'",
							CommonUseClientServer.DefaultLanguageCode()), ExchangeSettingsStructure);
						Return;
					EndIf;
					
				Except
					WriteEventLogDataExchange(DetailErrorDescription(ErrorInfo()), ExchangeSettingsStructure, True);
					ExchangeSettingsStructure.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Error;
					Cancel = True;
				EndTry;
				
			EndIf;
			
			Try
				DeleteFiles(FileExchangeMessages);
			Except
			EndTry;
			
		Else
			
			ExchangeMessage = "";
			
			Try
				
				WriteMessageWithNodeChanges(ExchangeSettingsStructure,, ExchangeMessage);
				
				// Sending exchange messages only if data is exported successfully
				If ExchangeExecutionResultCompleted(ExchangeSettingsStructure.ExchangeExecutionResult) Then
					
					Proxy.Download(ExchangeSettingsStructure.ExchangePlanName, ExchangeSettingsStructure.CurrentExchangePlanNodeCode, New ValueStorage(ExchangeMessage, New Deflation(9)));
					
				EndIf;
				
			Except
				WriteEventLogDataExchange(DetailErrorDescription(ErrorInfo()), ExchangeSettingsStructure, True);
				ExchangeSettingsStructure.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Error;
			EndTry;
			
		EndIf;
		
	EndIf;
	
	AddExchangeFinishEventLogMessage(ExchangeSettingsStructure);
	
	If Not ExchangeExecutionResultCompleted(ExchangeSettingsStructure.ExchangeExecutionResult) Then
		Cancel = True;
	EndIf;
	
EndProcedure

// For internal use.
// 
Procedure ExecuteExchangeActionForInfobaseNodeByExternalConnection(Cancel, InfobaseNode,
	ActionOnExchange,
	TransactionItemCount)
	
	SetPrivilegedMode(True);
	
	// INITIALIZING THE DATA EXCHANGE
	ExchangeSettingsStructure = GetExchangeSettingsStructureForExternalConnection(
		InfobaseNode,
		ActionOnExchange,
		TransactionItemCount);
	
	ExchangeSettingsStructure.StartDate = CurrentSessionDate();
	
	WriteLogEventDataExchangeStart(ExchangeSettingsStructure);
	
	If ExchangeSettingsStructure.Cancel Then
		// If settings contain errors, canceling the exchange
		ExchangeSettingsStructure.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Canceled;
		AddExchangeFinishEventLogMessage(ExchangeSettingsStructure);
		Cancel = True;
		Return;
	EndIf;
	
	ErrorMessageString = "";
	
	// Getting external connection for the infobase node
	ExternalConnection = DataExchangeCached.GetExternalConnectionForInfobaseNode(
		InfobaseNode,
		ErrorMessageString);
	
	If ExternalConnection = Undefined Then
		
		// Writing the message to the event log
		WriteEventLogDataExchange(ErrorMessageString, ExchangeSettingsStructure, True);
		
		// If settings contain errors, canceling the exchange
		ExchangeSettingsStructure.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Canceled;
		AddExchangeFinishEventLogMessage(ExchangeSettingsStructure);
		Cancel = True;
		Return;
	EndIf;
	
	// Getting remote infobase version
	ExternalConnectionSLVersion = ExternalConnection.StandardSubsystemsServer.LibVersion();
	ExchangeWithSL20 = CommonUseClientServer.CompareVersions("2.1.1.10", ExternalConnectionSLVersion) > 0;
	
	// INITIALIZING THE DATA EXCHANGE (THROUGH THE EXTERNAL CONNECTION)
	Structure = New Structure("ExchangePlanName, CurrentExchangePlanNodeCode, TransactionItemCount");
	FillPropertyValues(Structure, ExchangeSettingsStructure);
	
	// Reversing enumeration values
	ExchangeActionString = ?(ActionOnExchange = Enums.ActionsOnExchange.DataExport,
								CommonUse.EnumValueName(Enums.ActionsOnExchange.DataImport),
								CommonUse.EnumValueName(Enums.ActionsOnExchange.DataExport));
	
	Structure.Insert("ExchangeActionString", ExchangeActionString);
	Structure.Insert("DebugMode", False);
	Structure.Insert("ExchangeLogFileName", "");
	
	Try
		ExchangeSettingsStructureExternalConnection = ExternalConnection.DataExchangeExternalConnection.ExchangeSettingsStructure(Structure);
	Except
		// Writing the message to the event log
		WriteEventLogDataExchange(DetailErrorDescription(ErrorInfo()), ExchangeSettingsStructure, True);
		
		// If settings contain errors, canceling the exchange
		ExchangeSettingsStructure.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Canceled;
		AddExchangeFinishEventLogMessage(ExchangeSettingsStructure);
		Cancel = True;
		Return;
	EndTry;
	
	ExchangeSettingsStructure.ExchangeExecutionResult = Undefined;
	ExchangeSettingsStructureExternalConnection.StartDate = ExternalConnection.CurrentSessionDate();
	
	ExternalConnection.DataExchangeExternalConnection.WriteLogEventDataExchangeStart(ExchangeSettingsStructureExternalConnection);
	
	// DATA EXCHANGE
	If ExchangeSettingsStructure.DoDataImport Then
		
		// Getting exchange rules from the correspondent infobase
		ObjectConversionRules = ExternalConnection.DataExchangeExternalConnection.GetObjectConversionRules(ExchangeSettingsStructureExternalConnection.ExchangePlanName);
		
		If ObjectConversionRules = Undefined Then
			
			// Exchange rules must be specified
			NString = NStr("en = 'Conversion rules for the %1 exchange plan in the second infobase is not set. The exchange is canceled.'",
				CommonUseClientServer.DefaultLanguageCode());
			ErrorMessageString = StringFunctionsClientServer.SubstituteParametersInString(NString, ExchangeSettingsStructureExternalConnection.ExchangePlanName);
			WriteEventLogDataExchange(ErrorMessageString, ExchangeSettingsStructure, True);
			SetExchangeInitEnd(ExchangeSettingsStructure);
			Return;
		EndIf;
		
		// Data processor for importing data
		DataProcessorForDataImport = ExchangeSettingsStructure.DataExchangeDataProcessor;
		DataProcessorForDataImport.ExchangeFileName = "";
		DataProcessorForDataImport.ObjectCountPerTransaction = ExchangeSettingsStructure.TransactionItemCount;
		DataProcessorForDataImport.UseTransactions = (DataProcessorForDataImport.ObjectCountPerTransaction <> 1);
		DataProcessorForDataImport.ExecutingDataImportViaExternalConnection = True;
		
		// Getting the initialized data processor for exporting data
		DataExchangeDataProcessorExternalConnection = ExternalConnection.DataProcessors.InfobaseObjectConversion.Create();
		DataExchangeDataProcessorExternalConnection.ExchangeMode = "Data";
		DataExchangeDataProcessorExternalConnection.SavedSettings = ObjectConversionRules;
		
		Try
			DataExchangeDataProcessorExternalConnection.RestoreRulesFromInternalFormat();
		Except
			WriteEventLogDataExchange(
				StringFunctionsClientServer.SubstituteParametersInString(NStr("en = 'Error occurred in the second infobase: %1'"),
				DetailErrorDescription(ErrorInfo())), ExchangeSettingsStructure, True
			);
			
			// If settings contain errors, canceling the exchange
			ExchangeSettingsStructure.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Canceled;
			AddExchangeFinishEventLogMessage(ExchangeSettingsStructure);
			Cancel = True;
			Return;
		EndTry;
		
		// Specifying exchange nodes
		DataExchangeDataProcessorExternalConnection.NodeForExchange = ExchangeSettingsStructureExternalConnection.InfobaseNode;
		DataExchangeDataProcessorExternalConnection.BackgroundExchangeNode = Undefined;
		DataExchangeDataProcessorExternalConnection.DontExportObjectsByRefs = True;
		DataExchangeDataProcessorExternalConnection.ExchangeRuleFileName = "1";
		
		DataExchangeDataProcessorExternalConnection.ExternalConnection = Undefined;
		DataExchangeDataProcessorExternalConnection.DataImportExecutedInExternalConnection = False;
		
		SetCommonParametersForDataExchangeProcessing(DataExchangeDataProcessorExternalConnection, ExchangeSettingsStructureExternalConnection, ExchangeWithSL20);
		
		RecipientConfigurationVersion = "";
		SourceVersionFromRules = "";
		MessageText = "";
		ExternalConnectionParameters = New Structure;
		ExternalConnectionParameters.Insert("ExternalConnection", ExternalConnection);
		ExternalConnectionParameters.Insert("ExternalConnectionSLVersion", ExternalConnectionSLVersion);
		ExternalConnectionParameters.Insert("EventLogMessageKey", ExchangeSettingsStructureExternalConnection.EventLogMessageKey);
		ExternalConnectionParameters.Insert("InfobaseNode", ExchangeSettingsStructureExternalConnection.InfobaseNode);
		
		ObjectConversionRules.Get().Conversion.Property("SourceConfigurationVersion", RecipientConfigurationVersion);
		DataProcessorForDataImport.SavedSettings.Get().Conversion.Property("SourceConfigurationVersion", SourceVersionFromRules);
		
		If DifferentCorrespondentVersions(ExchangeSettingsStructure.ExchangePlanName, ExchangeSettingsStructure.EventLogMessageKey,
			SourceVersionFromRules, RecipientConfigurationVersion, MessageText, ExternalConnectionParameters) Then
			
			DataExchangeDataProcessorExternalConnection = Undefined;
			Return;
			
		EndIf;
		
		// EXPORT (CORRESPONDENT INFOBASE) - IMPORT (CURRENT INFOBASE)
		DataExchangeDataProcessorExternalConnection.ExecuteDataExport(DataProcessorForDataImport);
		
		// Commiting the data exchange performing state
		ExchangeSettingsStructure.ExchangeExecutionResult = DataProcessorForDataImport.ExchangeExecutionResult();
		ExchangeSettingsStructure.ProcessedObjectCount    = DataProcessorForDataImport.ImportedObjectCounter();
		ExchangeSettingsStructure.ExchangeMessage         = DataProcessorForDataImport.CommentOnDataImport;
		ExchangeSettingsStructure.ErrorMessageString      = DataProcessorForDataImport.ErrorMessageString();
		
		// Commiting the data exchange performing state (external connection)
		ExchangeSettingsStructureExternalConnection.ExchangeExecutionResultString = DataExchangeDataProcessorExternalConnection.ExchangeExecutionResultString();
		ExchangeSettingsStructureExternalConnection.ProcessedObjectCount          = DataExchangeDataProcessorExternalConnection.ExportedObjectCounter();
		ExchangeSettingsStructureExternalConnection.ExchangeMessage               = DataExchangeDataProcessorExternalConnection.CommentOnDataExport;
		ExchangeSettingsStructureExternalConnection.ErrorMessageString            = DataExchangeDataProcessorExternalConnection.ErrorMessageString();
		
		DataExchangeDataProcessorExternalConnection = Undefined;
		
	ElsIf ExchangeSettingsStructure.DoDataExport Then
		
		// Data processor for importing data
		DataProcessorForDataImport = ExternalConnection.DataProcessors.InfobaseObjectConversion.Create();
		DataProcessorForDataImport.ExchangeMode = "Import";
		DataProcessorForDataImport.ExchangeNodeDataImport = ExchangeSettingsStructureExternalConnection.InfobaseNode;
		DataProcessorForDataImport.ExecutingDataImportViaExternalConnection = True;
		
		SetCommonParametersForDataExchangeProcessing(DataProcessorForDataImport, ExchangeSettingsStructureExternalConnection, ExchangeWithSL20);
		
		DataProcessorForDataImport.ObjectCountPerTransaction = ExchangeSettingsStructure.TransactionItemCount;
		DataProcessorForDataImport.UseTransactions = (DataProcessorForDataImport.ObjectCountPerTransaction <> 1);
		
		// Getting the initialized data processor for exporting data
		DataExchangeXMLDataProcessor = ExchangeSettingsStructure.DataExchangeDataProcessor;
		DataExchangeXMLDataProcessor.ExchangeFileName = "";
		DataExchangeXMLDataProcessor.ExternalConnection = ExternalConnection;
		DataExchangeXMLDataProcessor.DataImportExecutedInExternalConnection = True;
		
		// EXPORT (CURRENT INFOBASE) - IMPORT (CORRESPONDENT INFOBASE)
		DataExchangeXMLDataProcessor.ExecuteDataExport(DataProcessorForDataImport);
		
		// Commiting the data exchange performing state
		ExchangeSettingsStructure.ExchangeExecutionResult = DataExchangeXMLDataProcessor.ExchangeExecutionResult();
		ExchangeSettingsStructure.ProcessedObjectCount    = DataExchangeXMLDataProcessor.ExportedObjectCounter();
		ExchangeSettingsStructure.ExchangeMessage         = DataExchangeXMLDataProcessor.CommentOnDataExport;
		ExchangeSettingsStructure.ErrorMessageString      = DataExchangeXMLDataProcessor.ErrorMessageString();
		
		// Commiting the data exchange performing state (external connection)
		ExchangeSettingsStructureExternalConnection.ExchangeExecutionResultString = DataProcessorForDataImport.ExchangeExecutionResultString();
		ExchangeSettingsStructureExternalConnection.ProcessedObjectCount          = DataProcessorForDataImport.ImportedObjectCounter();
		ExchangeSettingsStructureExternalConnection.ExchangeMessage               = DataProcessorForDataImport.CommentOnDataImport;
		ExchangeSettingsStructureExternalConnection.ErrorMessageString            = DataProcessorForDataImport.ErrorMessageString();
		
		DataProcessorForDataImport = Undefined;
		
	EndIf;
	
	AddExchangeFinishEventLogMessage(ExchangeSettingsStructure);
	
	ExternalConnection.DataExchangeExternalConnection.AddExchangeFinishEventLogMessage(ExchangeSettingsStructureExternalConnection);
	
	If Not ExchangeExecutionResultCompleted(ExchangeSettingsStructure.ExchangeExecutionResult) Then
		
		Cancel = True;
		
	EndIf;
	
EndProcedure

// For internal use.
// 
Procedure ExecuteDataExchangeOverFileResource(ExchangeSettingsStructure, Val ParametersOnly = False)
	
	If ExchangeSettingsStructure.DoDataImport Then
		
		// {Handler: BeforeExchangeMessageRead} Begin
		ExchangeMessage = "";
		StandardProcessing = True;
		
		BeforeExchangeMessageRead(ExchangeSettingsStructure.InfobaseNode, ExchangeMessage, StandardProcessing);
		// {Handler: BeforeExchangeMessageRead} End
		
		If StandardProcessing Then
			
			ExecuteExchangeMessageTransportBeforeProcessing(ExchangeSettingsStructure);
			
			If ExchangeSettingsStructure.ExchangeExecutionResult = Undefined Then
				
				ExecuteExchangeMessageTransportReceiving(ExchangeSettingsStructure);
				
				If ExchangeSettingsStructure.ExchangeExecutionResult = Undefined Then
					
					ExchangeMessage = ExchangeSettingsStructure.ExchangeMessageTransportDataProcessor.ExchangeMessageFileName();
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
		// Importing data only if the exchange message is received successfully
		If ExchangeSettingsStructure.ExchangeExecutionResult = Undefined Then
			
			ReadMessageWithNodeChanges(ExchangeSettingsStructure, ExchangeMessage,, ParametersOnly);
			
		EndIf;
		
		// {Handler: AfterExchangeMessageRead} Begin
		StandardProcessing = True;
		
		AfterExchangeMessageRead(
					ExchangeSettingsStructure.InfobaseNode,
					ExchangeMessage,
					ExchangeExecutionResultCompleted(ExchangeSettingsStructure.ExchangeExecutionResult),
					StandardProcessing,
					Not ParametersOnly);
		// {Handler: AfterExchangeMessageRead} End
		
		If StandardProcessing Then
			
			ExecuteExchangeMessageTransportAfterProcessing(ExchangeSettingsStructure);
			
		EndIf;
		
	ElsIf ExchangeSettingsStructure.DoDataExport Then
		
		ExecuteExchangeMessageTransportBeforeProcessing(ExchangeSettingsStructure);
		
		// Data export
		If ExchangeSettingsStructure.ExchangeExecutionResult = Undefined Then
			
			WriteMessageWithNodeChanges(ExchangeSettingsStructure, ExchangeSettingsStructure.ExchangeMessageTransportDataProcessor.ExchangeMessageFileName());
			
		EndIf;
		
		// Sending exchange messages only if data is exported successfully
		If ExchangeExecutionResultCompleted(ExchangeSettingsStructure.ExchangeExecutionResult) Then
			
			ExecuteExchangeMessageTransportSending(ExchangeSettingsStructure);
			
		EndIf;
		
		ExecuteExchangeMessageTransportAfterProcessing(ExchangeSettingsStructure);
		
	EndIf;
	
EndProcedure

// For internal use.
// 
Procedure BeforeExchangeMessageRead(Val Recipient, ExchangeMessage, StandardProcessing)
	
	If IsSubordinateDIBNode()
		And TypeOf(MasterNode()) = TypeOf(Recipient) Then
		
		SavedExchangeMessage = GetDataExchangeMessageFromMasterNode();
		
		If TypeOf(SavedExchangeMessage) = Type("BinaryData") Then
			
			StandardProcessing = False;
			
			ExchangeMessage = GetTempFileName("xml");
			
			SavedExchangeMessage.Write(ExchangeMessage);
			
			WriteDataReceiveEvent(Recipient, NStr("en = 'The exchange message is received from the cached values.'"));
			
			SetPrivilegedMode(True);
			SetDataExchangeMessageImportModeBeforeStart("MessageReceivedFromCache", True);
			SetPrivilegedMode(False);
			
		ElsIf TypeOf(SavedExchangeMessage) = Type("Structure") Then
			
			StandardProcessing = False;
			
			ExchangeMessage = SavedExchangeMessage.PathToFile;
			
			WriteDataReceiveEvent(Recipient, NStr("en = 'The exchange message is received from the cached values.'"));
			
			SetPrivilegedMode(True);
			SetDataExchangeMessageImportModeBeforeStart("MessageReceivedFromCache", True);
			SetPrivilegedMode(False);
			
		Else
			SetPrivilegedMode(True);
			SetDataExchangeMessageImportModeBeforeStart("MessageReceivedFromCache", False);
			SetPrivilegedMode(False);
		EndIf;
		
	EndIf;
	
EndProcedure

// For internal use.
Procedure AfterExchangeMessageRead(Val Recipient, Val ExchangeMessage, Val MessageRead, StandardProcessing, Val DeleteMessage = True)
	
	If IsSubordinateDIBNode()
		And TypeOf(MasterNode()) = TypeOf(Recipient) Then
		
		If Not MessageRead
		   And DataExchangeServerCall.DataExchangeMessageImportModeBeforeStart("MessageReceivedFromCache") Then
			// Cannot read cached message. Cached values must be cleared.
			ClearDataExchangeMessageFromMasterNode();
			Return;
		EndIf;
		
		UpdateCachedMessage = False;
		
		If ConfigurationChanged() Then
			
			// Cached values must be updated if configuration changes are received, but
			// not only during the first change import. Cached values may contain an obsolete exchange message.
			UpdateCachedMessage = True;
			
			If Not MessageRead Then
				
				If Constants.LoadDataExchangeMessage.Get() = False Then
					Constants.LoadDataExchangeMessage.Set(True);
				EndIf;
				
			EndIf;
			
		Else
			
			If DeleteMessage Then
				
				ClearDataExchangeMessageFromMasterNode();
				
				If Constants.LoadDataExchangeMessage.Get() = True Then
					Constants.LoadDataExchangeMessage.Set(False);
				EndIf;
				
			Else
				// Exchange message reading can be performed without metadata import, so after reading application parameters, you have
				// to save an exchange message to avoid reimport of this message for the basic reading.
				UpdateCachedMessage = True;
			EndIf;
			
		EndIf;
		
		If UpdateCachedMessage Then
			
			PreviousMessage = GetDataExchangeMessageFromMasterNode();
			
			UpdateCachedValues = False;
			NewMessage = New BinaryData(ExchangeMessage);
			
			StructureType = TypeOf(PreviousMessage) = Type("Structure");
			
			If StructureType Or TypeOf(PreviousMessage) = Type("BinaryData") Then
				
				If StructureType Then
					PreviousMessage = New BinaryData(PreviousMessage.PathToFile);
				EndIf;
				
				If PreviousMessage.Size() <> NewMessage.Size() Then
					UpdateCachedValues = True;
				ElsIf NewMessage <> PreviousMessage Then
					UpdateCachedValues = True;
				EndIf;
				
			Else
				
				UpdateCachedValues = True;
				
			EndIf;
			
			If UpdateCachedValues Then
				SetDataExchangeMessageFromMasterNode(NewMessage, Recipient);
			EndIf;
		EndIf;
		
	EndIf;
	
EndProcedure

// Writes infobase node changes to the file in the temporary directory.
//
// Parameters:
//  ExchangeSettingsStructure - Structure - structure with all required for exchange data and objects.
// 
Procedure WriteMessageWithNodeChanges(ExchangeSettingsStructure, Val ExchangeMessageFileName = "", ExchangeMessage = "")
	
	If ExchangeSettingsStructure.IsDIBExchange Then // Exchange in DIB
		
		Cancel = False;
		
		// Getting the exchange data processor
		DataExchangeDataProcessor = ExchangeSettingsStructure.DataExchangeDataProcessor;
		
		// Setting the name of the exchange message file to be read
		DataExchangeDataProcessor.SetExchangeMessageFileName(ExchangeMessageFileName);
		
		DataExchangeDataProcessor.ExecuteDataExport(Cancel);
		
		If Cancel Then
			
			ExchangeSettingsStructure.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Error;
			
		EndIf;
		
	Else
		
		// {Handler: OnDataExport} Begin. Redefining of the standard data export processing.
		StandardProcessing = True;
		ProcessedObjectCount = 0;
		
		Try
			OnSLDataExportHandler(StandardProcessing,
											ExchangeSettingsStructure.InfobaseNode,
											ExchangeMessageFileName,
											ExchangeMessage,
											ExchangeSettingsStructure.TransactionItemCount,
											ExchangeSettingsStructure.EventLogMessageKey,
											ProcessedObjectCount);
			
			If StandardProcessing = True Then
				
				ProcessedObjectCount = 0;
				
				OnDataExportHandler(StandardProcessing,
												ExchangeSettingsStructure.InfobaseNode,
												ExchangeMessageFileName,
												ExchangeMessage,
												ExchangeSettingsStructure.TransactionItemCount,
												ExchangeSettingsStructure.EventLogMessageKey,
												ProcessedObjectCount);
				
			EndIf;
			
		Except
			
			ErrorMessageString = DetailErrorDescription(ErrorInfo());
			
			WriteLogEvent(ExchangeSettingsStructure.EventLogMessageKey, EventLogLevel.Error,
					ExchangeSettingsStructure.InfobaseNode.Metadata(), 
					ExchangeSettingsStructure.InfobaseNode, ErrorMessageString);
			ExchangeSettingsStructure.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Error;
			ExchangeSettingsStructure.ErrorMessageString = ErrorMessageString;
			Return;
		EndTry;
		
		If StandardProcessing = False Then
			ExchangeSettingsStructure.ProcessedObjectCount = ProcessedObjectCount;
			Return;
		EndIf;
		// {Handler: OnDataExport} End
		
		If ExchangeSettingsStructure.ExchangeByObjectConversionRules Then // Universal exchange (exchange with conversion rules)
			
			// Getting the initialized exchange data processor
			DataExchangeXMLDataProcessor = ExchangeSettingsStructure.DataExchangeDataProcessor;
			DataExchangeXMLDataProcessor.ExchangeFileName = ExchangeMessageFileName;
			
			// Data export
			DataExchangeXMLDataProcessor.ExecuteDataExport();
			
			ExchangeSettingsStructure.ExchangeExecutionResult = DataExchangeXMLDataProcessor.ExchangeExecutionResult();
			
			// Commiting the data exchange performing state
			ExchangeSettingsStructure.ProcessedObjectCount = DataExchangeXMLDataProcessor.ExportedObjectCounter();
			ExchangeSettingsStructure.ExchangeMessage      = DataExchangeXMLDataProcessor.CommentOnDataExport;
			ExchangeSettingsStructure.ErrorMessageString   = DataExchangeXMLDataProcessor.ErrorMessageString();
			
		Else // Standard exchange (platform serialization)
			
			Cancel = False;
			ProcessedObjectCount = 0;
			
			ExecuteStandardNodeChangeExport(Cancel,
								ExchangeSettingsStructure.InfobaseNode,
								ExchangeMessageFileName,
								ExchangeMessage,
								ExchangeSettingsStructure.TransactionItemCount,
								ExchangeSettingsStructure.EventLogMessageKey,
								ProcessedObjectCount);
			
			ExchangeSettingsStructure.ProcessedObjectCount = ProcessedObjectCount;
			
			If Cancel Then
				
				ExchangeSettingsStructure.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Error;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Reads the exchange message with new data and imports data into the infobase.
//
// Parameters:
//  ExchangeSettingsStructure - Structure - structure with all required for exchange data and objects.
// 
Procedure ReadMessageWithNodeChanges(ExchangeSettingsStructure, Val ExchangeMessageFileName = "", ExchangeMessage = "", Val ParametersOnly = False)
	
	If ExchangeSettingsStructure.IsDIBExchange Then // Exchange in DIB
		
		Cancel = False;
		
		// Getting the exchange data processor
		DataExchangeDataProcessor = ExchangeSettingsStructure.DataExchangeDataProcessor;
		
		// Setting the name of the exchange message file to be read
		DataExchangeDataProcessor.SetExchangeMessageFileName(ExchangeMessageFileName);
		
		DataExchangeDataProcessor.ExecuteDataImport(Cancel, ParametersOnly);
		
		If Cancel Then
			
			ExchangeSettingsStructure.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Error;
			
		EndIf;
		
	Else
		
		// {Handler: OnDataImport} Begin. Redefining of the standard data import processing.
		StandardProcessing = True;
		ProcessedObjectCount = 0;
		
		Try
			OnSLDataImportHandler(StandardProcessing,
											ExchangeSettingsStructure.InfobaseNode,
											ExchangeMessageFileName,
											ExchangeMessage,
											ExchangeSettingsStructure.TransactionItemCount,
											ExchangeSettingsStructure.EventLogMessageKey,
											ProcessedObjectCount);
			
			If StandardProcessing = True Then
				
				ProcessedObjectCount = 0;
				
				OnDataImportHandler(StandardProcessing,
												ExchangeSettingsStructure.InfobaseNode,
												ExchangeMessageFileName,
												ExchangeMessage,
												ExchangeSettingsStructure.TransactionItemCount,
												ExchangeSettingsStructure.EventLogMessageKey,
												ProcessedObjectCount);
				
			EndIf;
			
		Except
			ErrorMessageString = DetailErrorDescription(ErrorInfo());
			
			WriteLogEvent(ExchangeSettingsStructure.EventLogMessageKey, EventLogLevel.Error,
					ExchangeSettingsStructure.InfobaseNode.Metadata(), 
					ExchangeSettingsStructure.InfobaseNode, ErrorMessageString);
			ExchangeSettingsStructure.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Error;
			ExchangeSettingsStructure.ErrorMessageString = ErrorMessageString;
			Return;
		EndTry;
		
		If StandardProcessing = False Then
			ExchangeSettingsStructure.ProcessedObjectCount = ProcessedObjectCount;
			Return;
		EndIf;
		// {Handler: OnDataImport} End
		
		If ExchangeSettingsStructure.ExchangeByObjectConversionRules Then // Universal exchange (exchange with conversion rules)
			
			// Getting the initialized exchange data processor
			DataExchangeXMLDataProcessor = ExchangeSettingsStructure.DataExchangeDataProcessor;
			DataExchangeXMLDataProcessor.ExchangeFileName = ExchangeMessageFileName;
			
			// Data import
			DataExchangeXMLDataProcessor.ExecuteDataImport();
			
			ExchangeSettingsStructure.ExchangeExecutionResult = DataExchangeXMLDataProcessor.ExchangeExecutionResult();
			
			// Commiting the data exchange performing state
			ExchangeSettingsStructure.ProcessedObjectCount = DataExchangeXMLDataProcessor.ImportedObjectCounter();
			ExchangeSettingsStructure.ExchangeMessage      = DataExchangeXMLDataProcessor.CommentOnDataImport;
			ExchangeSettingsStructure.ErrorMessageString   = DataExchangeXMLDataProcessor.ErrorMessageString();
			
		Else // Standard exchange (platform serialization)
			
			ProcessedObjectCount = 0;
			ExchangeExecutionResult = Undefined;
			
			ExecuteStandardNodeChangeImport(
								ExchangeSettingsStructure.InfobaseNode,
								ExchangeMessageFileName,
								ExchangeMessage,
								ExchangeSettingsStructure.TransactionItemCount,
								ExchangeSettingsStructure.EventLogMessageKey,
								ProcessedObjectCount,
								ExchangeExecutionResult);
 
			
			ExchangeSettingsStructure.ProcessedObjectCount = ProcessedObjectCount;
			ExchangeSettingsStructure.ExchangeExecutionResult = ExchangeExecutionResult;
			
		EndIf;
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Exchange with serialization methods.

// Records changes for the exchange message.
// Can be applied if both infobases have the same metadata structures of all objects  that take part in the exchange.
//
Procedure ExecuteStandardNodeChangeExport(Cancel,
							InfobaseNode,
							FileName,
							ExchangeMessage,
							TransactionItemCount = 0,
							EventLogMessageKey = "",
							ProcessedObjectCount = 0)
	
	If IsBlankString(EventLogMessageKey) Then
		EventLogMessageKey = EventLogMessageTextDataExchange();
	EndIf;
	
	InitialDataExport = InitialDataExportFlagIsSet(InfobaseNode);
	
	WriteToFile = Not IsBlankString(FileName);
	
	XMLWriter = New XMLWriter;
	
	If WriteToFile Then
		
		XMLWriter.OpenFile(FileName);
	Else
		
		XMLWriter.SetString();
	EndIf;
	
	XMLWriter.WriteXMLDeclaration();
	
	// Creating a new message
	WriteMessage = ExchangePlans.CreateMessageWriter();
	
	WriteMessage.BeginWrite(XMLWriter, InfobaseNode);
	
	// Counting the number of written objects
	WrittenObjectCount = 0;
	ProcessedObjectCount = 0;
	
	UseTransactions = TransactionItemCount <> 1;
	
	DataExchangeServerCall.CheckObjectChangeRecordMechanismCache();
	
	// Getting a changed data selection
	ChangeSelection = SelectChanges(WriteMessage.Recipient, WriteMessage.MessageNo);
	
	If UseTransactions Then
		BeginTransaction();
	EndIf;
	
	Try
		
		RecipientObject = WriteMessage.Recipient.GetObject();
		
		While ChangeSelection.Next() Do
			
			Data = ChangeSelection.Get();
			
			ProcessedObjectCount = ProcessedObjectCount + 1;
			
			// Checking whether the object passes the ORR filter.
			// If the object does not pass the ORR filter, sending object deletion to the 
			// receiver infobase.
			// If the object is a record set, verifying each record.
			// Record sets are exported always, even empty ones. Empty set is the object
			// deletion analog.

			ItemSend = DataItemSend.Auto;
			
			StandardSubsystemsServer.OnSendDataToSlave(Data, ItemSend, InitialDataExport, RecipientObject);
			
			If ItemSend = DataItemSend.Delete Then
				
				If CommonUse.IsRegister(Data.Metadata()) Then
					
					// Sending an empty record set as a register deletion
					
				Else
					
					Data = New ObjectDeletion(Data.Ref);
					
				EndIf;
				
			ElsIf ItemSend = DataItemSend.Ignore Then
				
				Continue;
				
			EndIf;
			
			// Writing data to the message
			WriteXML(XMLWriter, Data);
			
			WrittenObjectCount = WrittenObjectCount + 1;
			
			If UseTransactions
				And TransactionItemCount > 0
				And WrittenObjectCount = TransactionItemCount Then
				
				// Committing the transaction and beginning a new one
				CommitTransaction();
				BeginTransaction();
				
				WrittenObjectCount = 0;
			EndIf;
			
		EndDo;
		
		If UseTransactions Then
			
			CommitTransaction();
			
		EndIf;
		
		// Finishing writing the message
		WriteMessage.EndWrite();
		
		ExchangeMessage = XMLWriter.Close();
		
	Except
		
		If UseTransactions Then
			
			RollbackTransaction();
			
		EndIf;
		
		WriteMessage.CancelWrite();
		
		XMLWriter.Close();
		
		Cancel = True;
		
		WriteLogEvent(EventLogMessageKey, EventLogLevel.Error,
			InfobaseNode.Metadata(), InfobaseNode, DetailErrorDescription(ErrorInfo()));
 
		Return;
	EndTry;
	
EndProcedure

// Reads changes from exchange messages.
// Can be applied if both infobases have the same metadata structures of all objects that take part in the exchange.
//
Procedure ExecuteStandardNodeChangeImport(
							InfobaseNode,
							FileName = "",
							ExchangeMessage = "",
							TransactionItemCount = 0,
							EventLogMessageKey = "",
							ProcessedObjectCount = 0,
							ExchangeExecutionResult = Undefined)
 
	
	If IsBlankString(EventLogMessageKey) Then
		EventLogMessageKey = EventLogMessageTextDataExchange();
	EndIf;
	
	ExchangePlanManager = DataExchangeCached.GetExchangePlanManager(InfobaseNode);
	
	Try
		XMLReader = New XMLReader;
		
		If Not IsBlankString(ExchangeMessage) Then
			XMLReader.SetString(ExchangeMessage);
		Else
			XMLReader.OpenFile(FileName);
		EndIf;
		
		MessageReader = ExchangePlans.CreateMessageReader();
		MessageReader.BeginRead(XMLReader, AllowedMessageNo.Greater);
	Except
		
		ErrorInfo = ErrorInfo();
		
		If IsErrorMessageNumberLessOrEqualToPreviouslyAcceptedMessageNumber(BriefErrorDescription(ErrorInfo)) Then
			
			ExchangeExecutionResult = Enums.ExchangeExecutionResults.Warning_ExchangeMessageReceivedPreviously;
			
			WriteLogEvent(EventLogMessageKey, EventLogLevel.Warning,
				InfobaseNode.Metadata(), InfobaseNode, BriefErrorDescription(ErrorInfo));

		Else
			
			ExchangeExecutionResult = Enums.ExchangeExecutionResults.Error;
			
			WriteLogEvent(EventLogMessageKey, EventLogLevel.Error,
				InfobaseNode.Metadata(), InfobaseNode, DetailErrorDescription(ErrorInfo));
 
		EndIf;
		
		Return;
	EndTry;
	
	If MessageReader.From <> InfobaseNode Then // The message is not intended for this node
		
		ExchangeExecutionResult = Enums.ExchangeExecutionResults.Error;
		
		WriteLogEvent(EventLogMessageKey, EventLogLevel.Error,
			InfobaseNode.Metadata(), InfobaseNode, NStr("en = 'Exchange message contains data for another infobase node.'",
			CommonUseClientServer.DefaultLanguageCode()));
 
		Return;
	EndIf;
	
	BackupCopyParameters = BackupCopyParameters(MessageReader.From, MessageReader.ReceivedNo);
	
	DeleteChangeRecords = Not BackupCopyParameters.BackupRestored;
	
	If DeleteChangeRecords Then
		
		// Deleting change records for the message sender node
		ExchangePlans.DeleteChangeRecords(MessageReader.From, MessageReader.ReceivedNo);
		
		InformationRegisters.CommonInfobaseNodeSettings.ClearInitialDataExportFlag(MessageReader.From, MessageReader.ReceivedNo);
		
	EndIf;
	
	// Counting the number of read objects
	WrittenObjectCount = 0;
	ProcessedObjectCount = 0;
	
	Try
		AllowDeleteObjects = ExchangePlanManager.AllowDeleteObjects();
	Except
		AllowDeleteObjects = False;
	EndTry;
	
	UseTransactions = TransactionItemCount <> 1;
	
	If UseTransactions Then
		
		// Beginning a transaction
		BeginTransaction();
		
	EndIf;
	
	Try
		
		// Reading data from the message
		While CanReadXML(XMLReader) Do
			
			// Reading the next value
			Data = ReadXML(XMLReader);
			
			ItemReceive = DataItemReceive.Auto;
			SendBack = False;
			
			StandardSubsystemsServer.OnReceiveDataFromMaster(Data, ItemReceive, SendBack, MessageReader.From);
			
			If ItemReceive = DataItemReceive.Ignore Then
				Continue;
			EndIf;
				
			IsObjectDeletion = (TypeOf(Data) = Type("ObjectDeletion"));
			
			ProcessedObjectCount = ProcessedObjectCount + 1;
			
			If Not SendBack Then
				Data.DataExchange.Sender = MessageReader.Sender;
			EndIf;
			
			Data.DataExchange.Load = True;
			
			// Overriding the standard system behavior on receiving object deletion.
			// Setting deletion marks instead of deleting objects without infobase reference integrity checking.
			If IsObjectDeletion Then
				
				ObjectDeletion = Data;
				
				Data = Data.Ref.GetObject();
				
				If Data = Undefined Then
					
					Continue;
					
				EndIf;
				
				If Not SendBack Then
					Data.DataExchange.Sender = MessageReader.Sender;
				EndIf;
				
				Data.DataExchange.Load = True;
				
				Data.DeletionMark = True;
				
				If CommonUse.IsDocument(Data.Metadata()) Then
					
					Data.Posted = False;
					
				EndIf;
				
			EndIf;
			
			If IsObjectDeletion And AllowDeleteObjects Then
				
				Data = ObjectDeletion;
				
			EndIf;
			
			// Attempting to write the object
			Try
				Data.Write();
			Except
				
				ExchangeExecutionResult = Enums.ExchangeExecutionResults.Error;
				
				ErrorDescription = DetailErrorDescription(ErrorInfo());
				
				WriteLogEvent(EventLogMessageKey, EventLogLevel.Error,
					Data.Metadata(), String(Data), ErrorDescription);
 
				Break;
			EndTry;
			
			WrittenObjectCount = WrittenObjectCount + 1;
			
			If UseTransactions
				And TransactionItemCount > 0
				And WrittenObjectCount = TransactionItemCount Then
				
				// Committing the transaction and beginning a new one
				CommitTransaction();
				BeginTransaction();
				
				WrittenObjectCount = 0;
			EndIf;
			
		EndDo;
		
	Except
		
		ExchangeExecutionResult = Enums.ExchangeExecutionResults.Error;
		
		WriteLogEvent(EventLogMessageKey, EventLogLevel.Error,
			InfobaseNode.Metadata(), InfobaseNode, DetailErrorDescription(ErrorInfo()));
 
	EndTry;
	
	If ExchangeExecutionResult = Enums.ExchangeExecutionResults.Error Then
		
		MessageReader.CancelRead();
		
		If UseTransactions Then
			RollbackTransaction();
		EndIf;
	Else
		
		MessageReader.EndRead();
		
		OnBackupRestore(BackupCopyParameters);
		
		If UseTransactions Then
			CommitTransaction();
		EndIf;
		
	EndIf;
	
	XMLReader.Close();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Export internal functions for retrieving properties.

// Returns the name of the temporary directory for data exchange messages.
// The directory name is made by the following pattern:
// "Exchange82 {UUID}", where UUID is a UUID string.
// 
// Returns:
//  String - the name of the temporary directory for data exchange messages.

//
Function TempExchangeMessageDirectory() Export
	
	Return StrReplace("Exchange82 {UUID}", "GUID", Upper(String(New UUID)));
	
EndFunction

// Returns the exchange message transport data processor name.
// 
// Parameters:
//  TransportKind - EnumRef.ExchangeMessageTransportKinds - transport kind, for 
//                  which the result will be retrieved.
// 
//  Returns:
//   String - exchange message transport data processor name.
//
Function DataExchangeMessageTransportDataProcessorName(TransportKind) Export
	
	Return StrReplace("ExchangeMessageTransport[TransportKind]", "[TransportKind]", CommonUse.EnumValueName(TransportKind));
	
EndFunction

// Copy of DataExchangeClient.MaxObjectMappingFieldCount server procedure.
//
Function MaxObjectMappingFieldCount() Export
	
	Return 5;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Exchange message transport.

// For internal use.
// 
Procedure ExecuteExchangeMessageTransportBeforeProcessing(ExchangeSettingsStructure)
	
	// Getting the initialized message transport data processor
	ExchangeMessageTransportDataProcessor = ExchangeSettingsStructure.ExchangeMessageTransportDataProcessor;
	
	// Getting a new temporary file name
	If Not ExchangeMessageTransportDataProcessor.ExecuteActionsBeforeMessageProcessing() Then
		
		WriteEventLogDataExchange(ExchangeMessageTransportDataProcessor.ErrorMessageStringEL, ExchangeSettingsStructure, True);
		
		ExchangeSettingsStructure.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Error_MessageTransport;
		
	EndIf;
	
EndProcedure

// For internal use.
// 
Procedure ExecuteExchangeMessageTransportSending(ExchangeSettingsStructure)
	
	// Getting the initialized message transport data processor
	ExchangeMessageTransportDataProcessor = ExchangeSettingsStructure.ExchangeMessageTransportDataProcessor;
	
	// Sending the exchange message from the temporary directory
	If Not ExchangeMessageTransportDataProcessor.SendMessage() Then
		
		WriteEventLogDataExchange(ExchangeMessageTransportDataProcessor.ErrorMessageStringEL, ExchangeSettingsStructure, True);
		
		ExchangeSettingsStructure.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Error_MessageTransport;
		
	EndIf;
	
EndProcedure

// For internal use.
// 
Procedure ExecuteExchangeMessageTransportReceiving(ExchangeSettingsStructure)
	
	// Getting the initialized message transport data processor
	ExchangeMessageTransportDataProcessor = ExchangeSettingsStructure.ExchangeMessageTransportDataProcessor;
	
	// Receiving the exchange message and putting it to the temporary directory
	If Not ExchangeMessageTransportDataProcessor.ReceiveMessage() Then
		
		WriteEventLogDataExchange(ExchangeMessageTransportDataProcessor.ErrorMessageStringEL, ExchangeSettingsStructure, True);
		
		ExchangeSettingsStructure.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Error_MessageTransport;
		
	EndIf;
	
EndProcedure

// For internal use.
// 
Procedure ExecuteExchangeMessageTransportAfterProcessing(ExchangeSettingsStructure)
	
	// Getting the initialized message transport data processor
	ExchangeMessageTransportDataProcessor = ExchangeSettingsStructure.ExchangeMessageTransportDataProcessor;
	
	// Performing actions after message sending
	ExchangeMessageTransportDataProcessor.ExecuteAfterMessageProcessingActions();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// File transfer service.

// Downloads the file from the file transfer service by the passed ID.
//
// Parameters:
//  FileID       - UUID - ID of the file to be downloaded.
//  InfobaseNode - infobase node. 
//  PartSize     - Number - part size in kilobytes. If the passed value is 0, the file 
//                 is not split into parts.
// Returns:
//  String - path to the received file.
//
Function GetFileFromStorageInService(Val FileID, Val InfobaseNode, Val SegmentSize = 1024, Val AuthenticationParameters = Undefined) Export
	
	// Return value
	ResultFileName = "";
	
	Proxy = GetWSProxyForInfobaseNode(InfobaseNode,, AuthenticationParameters);
	
	ExchangeInsideNetwork = DataExchangeCached.IsExchangeInSameLAN(InfobaseNode, AuthenticationParameters);
	
	If ExchangeInsideNetwork Then
		
		FileNameFromStorage = Proxy.GetFileFromStorage(FileID);
		
		ResultFileName = CommonUseClientServer.GetFullFileName(TempFileStorageDirectory(), FileNameFromStorage);
		
	Else
		
		SessionID = Undefined;
		PartCount = Undefined;
		
		Proxy.PrepareGetFile(FileID, SegmentSize, SessionID, PartCount);
		
		FileNames = New Array;
		
		AssemblyDirectory = GetTempFileName();
		CreateDirectory(AssemblyDirectory);
		
		FileNamePattern = "data.zip.[n]";
		
		// Recording exchange events
		ExchangeSettingsStructure = New Structure("EventLogMessageKey");
		ExchangeSettingsStructure.EventLogMessageKey = GetEventLogMessageKey(InfobaseNode, Enums.ActionsOnExchange.DataImport);
		
		Comment = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Start receiving the exchange message from the Internet (file part number is %1).'"),
			Format(PartCount, "NZ=0; NG=0")
		);
		WriteEventLogDataExchange(Comment, ExchangeSettingsStructure);
		
		For PartNumber = 1 To PartCount Do
			
			PartData = Undefined;
			Proxy.GetFilePart(SessionID, PartNumber, PartData);
			
			FileName = StrReplace(FileNamePattern, "[n]", Format(PartNumber, "NG=0"));
			FileNamePart = CommonUseClientServer.GetFullFileName(AssemblyDirectory, FileName);
			
			PartData.Write(FileNamePart);
			FileNames.Add(FileNamePart);
		EndDo;
		PartData = Undefined;
		
		Proxy.ReleaseFile(SessionID);
		
		ArchiveName = CommonUseClientServer.GetFullFileName(AssemblyDirectory, "data.zip");
		
		MergeFiles(FileNames, ArchiveName);
		
		Dearchiver = New ZipFileReader(ArchiveName);
		If Dearchiver.Items.Count() = 0 Then
			Try
				DeleteFiles(AssemblyDirectory);
			Except
				WriteLogEvent(TempFileDeletionEventLogMessageText(),
				EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
			EndTry;
			Raise(NStr("en = 'The archive file does not contain data.'"));
		EndIf;
		
		// Recording exchange events
		ArchiveFile = New File(ArchiveName);
		
		Comment = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Finish receiving the exchange message from the Internet (compressed message size is %1 MB).'"),
			Format(Round(ArchiveFile.Size() / 1024 / 1024, 3), "NZ=0; NG=0")
		);
		WriteEventLogDataExchange(Comment, ExchangeSettingsStructure);

		
		FileName = CommonUseClientServer.GetFullFileName(AssemblyDirectory, Dearchiver.Items[0].Name);
		
		Dearchiver.Extract(Dearchiver.Items[0], AssemblyDirectory);
		Dearchiver.Close();
		
		File = New File(FileName);
		
		ResultFileName = CommonUseClientServer.GetFullFileName(TempFilesDir(), File.Name);
		MoveFile(FileName, ResultFileName);
		
		Try
			DeleteFiles(AssemblyDirectory);
		Except
			WriteLogEvent(TempFileDeletionEventLogMessageText(),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		EndTry;
		
	EndIf;
	
	Return ResultFileName;
EndFunction

// Passes the specified file to the file transfer service.
//
// Parameters:
//  FileName     - String - path to the passed file.
//  InfobaseNode - infobase node. 
//  PartSize     - Number - part size in kilobytes. If the passed value is 0, the file
//                 is not split into parts.
// Returns:
//  UUID  - file ID in the file transfer service.

//
Function PutFileToStorageInService(Val FileName, Val InfobaseNode, Val SegmentSize = 1024, Val AuthenticationParameters = Undefined) Export
	
	// Return value
	FileID = Undefined;
	
	Proxy = GetWSProxyForInfobaseNode(InfobaseNode,, AuthenticationParameters);
	
	ExchangeInsideNetwork = DataExchangeCached.IsExchangeInSameLAN(InfobaseNode, AuthenticationParameters);
	
	If ExchangeInsideNetwork Then
		
		FileNameInStorage = CommonUseClientServer.GetFullFileName(TempFileStorageDirectory(), UniqueExchangeMessageFileName());
		
		MoveFile(FileName, FileNameInStorage);
		
		Proxy.PutFileIntoStorage(FileNameInStorage, FileID);
		
	Else
		
		FileDirectory = GetTempFileName();
		CreateDirectory(FileDirectory);
		
		// Archiving the file
		SharedFileName = CommonUseClientServer.GetFullFileName(FileDirectory, "data.zip");
		Archiver = New ZipFileWriter(SharedFileName,,,, ZIPCompressionLevel.Maximum);
		Archiver.Add(FileName);
		Archiver.Write();
		
		// Splitting file into volumes
		SessionID = New UUID;
		
		PartCount = 1;
		If ValueIsFilled(SegmentSize) Then
			FileNames = SplitFile(SharedFileName, SegmentSize * 1024);
			PartCount = FileNames.Count();
			For PartNumber = 1 To PartCount Do
				FileNamePart = FileNames[PartNumber - 1];
				FileData = New BinaryData(FileNamePart);
				Proxy.PutFilePart(SessionID, PartNumber, FileData);
			EndDo;
		Else
			FileData = New BinaryData(SharedFileName);
			Proxy.PutFilePart(SessionID, 1, FileData);
		EndIf;
		
		Try
			DeleteFiles(FileDirectory);
		Except
			WriteLogEvent(TempFileDeletionEventLogMessageText(),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		EndTry;
		
		Proxy.SaveFileFromParts(SessionID, PartCount, FileID);
		
	EndIf;
	
	Return FileID;
EndFunction

// Retrieves the file by the ID.
//
// Parameters:
// FileID - UUID - file ID.
//
// Returns:
//  FileName - String - file name.
//
Function GetFileFromStorage(Val FileID) Export
	
	FileName = "";
	
	If CommonUseCached.DataSeparationEnabled()
		And CommonUseCached.CanUseSeparatedData() Then
		
		DataExchangeSaaSModule = CommonUse.CommonModule("DataExchangeSaaS");
		DataExchangeSaaSModule.OnReceiveFileFromStorage(FileID, FileName);
		
	Else
		
		OnReceiveFileFromStorage(FileID, FileName);
		
	EndIf;
	
	Return CommonUseClientServer.GetFullFileName(TempFileStorageDirectory(), FileName);
EndFunction

// Saves a file to the storage.
//
// Parameters:
//  FileName - String - file description.
//  FileID   - UUID - file ID. If the ID is specified, 
//             it is used to save the file, otherwise new file ID is to be created.
//
// Returns:
//  UUID - file ID.
//
Function PutFileToStorage(Val FileName, Val FileID = Undefined) Export
	
	FileID = ?(FileID = Undefined, New UUID, FileID);
	
	File = New File(FileName);
	
	RecordStructure = New Structure;
	RecordStructure.Insert("MessageID",          String(FileID));
	RecordStructure.Insert("MessageFileName",    File.Name);
	RecordStructure.Insert("MessageSendingDate", CurrentUniversalDate());
	
	If CommonUseCached.DataSeparationEnabled()
		And CommonUseCached.CanUseSeparatedData() Then
		
		DataExchangeSaaSModule = CommonUse.CommonModule("DataExchangeSaaS");
		DataExchangeSaaSModule.OnSaveFileToStorage(RecordStructure);
	Else
		
		OnSaveFileToStorage(RecordStructure);
		
	EndIf;
	
	Return FileID;
EndFunction

// Determines whether file transfer over LAN is possible between two infobases.
//
// Parameters:
//  InfobaseNode             - ExchangePlanRef - exchange plan node for which the exchange message is received.
//  AuthenticationParameters - Structure - contains parameters of authentication on the web service (User, Password).
//
Function IsExchangeInSameLAN(Val InfobaseNode, Val AuthenticationParameters = Undefined) Export
	
	Proxy = GetWSProxyForInfobaseNode(InfobaseNode,, AuthenticationParameters);
	
	TempFileName = StrReplace("test{GUID}.tmp", "GUID", String(New UUID));
	
	TempFileFullName = CommonUseClientServer.GetFullFileName(TempFileStorageDirectory(), TempFileName);
	TextWriter = New TextWriter(TempFileFullName);
	TextWriter.Close();
	
	Try
		Result = Proxy.FileExists(TempFileName);
	Except
		DetailErrorDescription = DetailErrorDescription(ErrorInfo());
		Try
			DeleteFiles(TempFileFullName);
		Except
			WriteLogEvent(TempFileDeletionEventLogMessageText(),
				EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		EndTry;
		Raise DetailErrorDescription;
	EndTry;
	
	Try
		DeleteFiles(TempFileFullName);
	Except
		WriteLogEvent(TempFileDeletionEventLogMessageText(),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
	EndTry;
	
	Return Result;
EndFunction

// Gets a file from the storage by the file ID.
// If a file with the specified ID is not found raises an exception.
// If the file is found, returns its name and deletes the information about the file from the storage.
//
// Parameters:
// FileID   - UUID - file ID.
// FileName - String - file name.
//
Procedure OnReceiveFileFromStorage(Val FileID, FileName)
	
	QueryText =
	"SELECT
	|	DataExchangeMessages.MessageFileName AS FileName
	|FROM
	|	InformationRegister.DataExchangeMessages AS DataExchangeMessages
	|WHERE
	|	DataExchangeMessages.MessageID = &MessageID";
	
	Query = New Query;
	Query.SetParameter("MessageID", String(FileID));
	Query.Text = QueryText;
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Description = NStr("en = 'The file with the %1 ID is not found.'");
		Raise StringFunctionsClientServer.SubstituteParametersInString(Description, String(FileID));
	EndIf;
	
	Selection = QueryResult.Select();
	Selection.Next();
	FileName = Selection.FileName;
	
	// Deleting information about a message file from the storage
	RecordStructure = New Structure;
	RecordStructure.Insert("MessageID", String(FileID));
	InformationRegisters.DataExchangeMessages.DeleteRecord(RecordStructure);
	
EndProcedure

// Saves a file to the storage.
//
Procedure OnSaveFileToStorage(Val RecordStructure)
	
	InformationRegisters.DataExchangeMessages.AddRecord(RecordStructure);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Change registration for initial data export.

// Registers changes for initial data export based on the export start date and the
// company list.
// The procedure is universal and can be used for registering data changes based on the
// export start date and the company list for object data types and register record
// sets.
// If the company list is not specified (Companies = Undefined), changes are registered
// based on the export start date only.
// The procedure registers data of all metadata objects included in the exchange plan.
// The procedure registers data unconditionally in the following cases:
// - the UseAutoRecord flag of the metadata object is set;
// - the UseAutoRecord flag is not set and registration rules are not specified.
// If registration rules are specified for the metadata object, changes are registered
// based on the export start date and the company list.
// Document changes can be registered based on the export start date and the company
// list.
// Business process changes and task changes can be registered based on the export start
// date.
// Register record set changes can be registered based on the export start date and the
// company list.
// The procedure can be used as a prototype for change registration procedures that 
// perform initial data export.
//
// Parameters:
//  Recipient       - ExchangePlanRef (mandatory) - exchange plan node whose changes
//                    will be registered.
//  ExportStartDate - Date (mandatory) – changes made since this date and time will be
//                    registered.
// Companies        - Array, Undefined (optional) - list of companies whose data changes
//                    will be registered. If this parameter is not specified, companies 
//                    are not taken into account during the change registration.
//
Procedure RegisterDataByExportStartDateAndCompany(Val Recipient, ExportStartDate,
	Companies = Undefined,
	Data = Undefined) Export
	
	FilterByCompanies = (Companies <> Undefined);
	FilterByExportStartDate = ValueIsFilled(ExportStartDate);
	
	If Not FilterByCompanies And Not FilterByExportStartDate Then
		
		If TypeOf(Data) = Type("Array") Then
			
			For Each MetadataObject In Data Do
				
				ExchangePlans.RecordChanges(Recipient, MetadataObject);
				
			EndDo;
			
		Else
			
			ExchangePlans.RecordChanges(Recipient, Data);
			
		EndIf;
		
		Return;
	EndIf;
	
	FilterByExportStartDateAndCompanies = FilterByExportStartDate And FilterByCompanies;
	
	ExchangePlanName = DataExchangeCached.GetExchangePlanName(Recipient);
	
	ExchangePlanContent = Metadata.ExchangePlans[ExchangePlanName].Content;
	
	UseFilterByMetadata = (TypeOf(Data) = Type("Array"));
	
	For Each ExchangePlanContentItem In ExchangePlanContent Do
		
		If UseFilterByMetadata
			And Data.Find(ExchangePlanContentItem.Metadata) = Undefined Then
			
			Continue;
			
		EndIf;
		
		FullObjectName = ExchangePlanContentItem.Metadata.FullName();
		
		If ExchangePlanContentItem.AutoRecord = AutoChangeRecord.Deny
			And DataExchangeCached.ObjectChangeRecordRulesExist(ExchangePlanName, FullObjectName) Then
			
			If CommonUse.IsDocument(ExchangePlanContentItem.Metadata) Then // Documents
				
				If FilterByExportStartDateAndCompanies
					And ExchangePlanContentItem.Metadata.Attributes.Find("Company") <> Undefined Then // Registering by date and companies
					
					Selection = DocumentSelectionByExportStartDateAndCompany(FullObjectName, ExportStartDate, Companies);
					
					While Selection.Next() Do
						
						ExchangePlans.RecordChanges(Recipient, Selection.Ref);
						
					EndDo;
					
					Continue;
					
				Else // Registering by date
					
					Selection = ObjectSelectionByExportStartDate(FullObjectName, ExportStartDate);
					
					While Selection.Next() Do
						
						ExchangePlans.RecordChanges(Recipient, Selection.Ref);
						
					EndDo;
					
					Continue;
					
				EndIf;
				
			ElsIf CommonUse.IsBusinessProcess(ExchangePlanContentItem.Metadata)
				Or CommonUse.IsTask(ExchangePlanContentItem.Metadata) Then // Business processes and tasks
				
				// Registering by date
				Selection = ObjectSelectionByExportStartDate(FullObjectName, ExportStartDate);
				
				While Selection.Next() Do
					
					ExchangePlans.RecordChanges(Recipient, Selection.Ref);
					
				EndDo;
				
				Continue;
				
			ElsIf CommonUse.IsRegister(ExchangePlanContentItem.Metadata) Then // Registers
				
				// Information registers (independent)
				If CommonUse.IsInformationRegister(ExchangePlanContentItem.Metadata)
					And ExchangePlanContentItem.Metadata.WriteMode = Metadata.ObjectProperties.RegisterWriteMode.Independent Then
					
					MainFilter = MainInformationRegisterFilter(ExchangePlanContentItem.Metadata);
					
					FilterByPeriod  = (MainFilter.Find("Period") <> Undefined);
					FilterByCompany = (MainFilter.Find("Company") <> Undefined);
					
					If FilterByExportStartDateAndCompanies And FilterByPeriod And FilterByCompany Then // Registering by date and companies
						
						Selection = MainInformationRegisterFilterValueSelectionByExportStartDateAndCompanies(MainFilter, FullObjectName, ExportStartDate, Companies);
						
					ElsIf FilterByExportStartDate And FilterByPeriod Then // Registering by date
						
						Selection = MainInformationRegisterFilterValueSelectionByExportStartDate(MainFilter, FullObjectName, ExportStartDate);
						
					ElsIf FilterByCompanies And FilterByCompany Then // Registering by companies
						
						Selection = MainInformationRegisterFilterByCompaniesValueSelection(MainFilter, FullObjectName, Companies);
						
					Else
						
						Selection = Undefined;
						
					EndIf;
					
					If Selection <> Undefined Then
						
						RecordSet = CommonUse.ObjectManagerByFullName(FullObjectName).CreateRecordSet();
						
						While Selection.Next() Do
							
							For Each DimensionName In MainFilter Do
								
								RecordSet.Filter[DimensionName].Value = Selection[DimensionName];
								RecordSet.Filter[DimensionName].Use   = True;
								
							EndDo;
							
							ExchangePlans.RecordChanges(Recipient, RecordSet);
							
						EndDo;
						
						Continue;
						
					EndIf;
					
				Else // Registers (other)
					
					If FilterByExportStartDateAndCompanies
						And ExchangePlanContentItem.Metadata.Dimensions.Find("Period") <> Undefined
						And ExchangePlanContentItem.Metadata.Dimensions.Find("Company") <> Undefined Then // Registering by date and companies
						
						Selection = RecordSetRecorderSelectionByExportStartDateAndCompany(FullObjectName, ExportStartDate, Companies);
						
						RecordSet = CommonUse.ObjectManagerByFullName(FullObjectName).CreateRecordSet();
						
						While Selection.Next() Do
							
							RecordSet.Filter.Recorder.Value = Selection.Recorder;
							RecordSet.Filter.Recorder.Use   = True;
							
							ExchangePlans.RecordChanges(Recipient, RecordSet);
							
						EndDo;
						
						Continue;
						
					ElsIf ExchangePlanContentItem.Metadata.Dimensions.Find("Period") <> Undefined Then // Registering by date
						
						Selection = RecordSetRecorderSelectionByExportStartDate(FullObjectName, ExportStartDate);
						
						RecordSet = CommonUse.ObjectManagerByFullName(FullObjectName).CreateRecordSet();
						
						While Selection.Next() Do
							
							RecordSet.Filter.Recorder.Value = Selection.Recorder;
							RecordSet.Filter.Recorder.Use   = True;
							
							ExchangePlans.RecordChanges(Recipient, RecordSet);
							
						EndDo;
						
						Continue;
						
					EndIf;
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
		ExchangePlans.RecordChanges(Recipient, ExchangePlanContentItem.Metadata);
		
	EndDo;
	
EndProcedure

// For internal use.
// 
Function DocumentSelectionByExportStartDateAndCompany(FullObjectName, ExportStartDate, Companies)
	
	QueryText =
	"SELECT
	|	Table.Ref AS Ref
	|FROM
	|	[FullObjectName] AS Table
	|WHERE
	|	Table.Company IN(&Companies)
	|	AND Table.Date >= &ExportStartDate";
	
	QueryText = StrReplace(QueryText, "[FullObjectName]", FullObjectName);
	
	Query = New Query;
	Query.SetParameter("ExportStartDate", ExportStartDate);
	Query.SetParameter("Companies", Companies);
	Query.Text = QueryText;
	
	Return Query.Execute().Select();
EndFunction

// For internal use.
// 
Function ObjectSelectionByExportStartDate(FullObjectName, ExportStartDate)
	
	QueryText =
	"SELECT
	|	Table.Ref AS Ref
	|FROM
	|	[FullObjectName] AS Table
	|WHERE
	|	Table.Date >= &ExportStartDate";
	
	QueryText = StrReplace(QueryText, "[FullObjectName]", FullObjectName);
	
	Query = New Query;
	Query.SetParameter("ExportStartDate", ExportStartDate);
	Query.Text = QueryText;
	
	Return Query.Execute().Select();
EndFunction

// For internal use.
// 
Function RecordSetRecorderSelectionByExportStartDateAndCompany(FullObjectName, ExportStartDate, Companies)
	
	QueryText =
	"SELECT DISTINCT
	|	RegisterTable.Recorder AS Recorder
	|FROM
	|	[FullObjectName] AS RegisterTable
	|WHERE
	|	RegisterTable.Company IN(&Companies)
	|	AND RegisterTable.Period >= &ExportStartDate";
	
	QueryText = StrReplace(QueryText, "[FullObjectName]", FullObjectName);
	
	Query = New Query;
	Query.SetParameter("ExportStartDate", ExportStartDate);
	Query.SetParameter("Companies", Companies);
	Query.Text = QueryText;
	
	Return Query.Execute().Select();
EndFunction

// For internal use.
// 
Function RecordSetRecorderSelectionByExportStartDate(FullObjectName, ExportStartDate)
	
	QueryText =
	"SELECT DISTINCT
	|	RegisterTable.Recorder AS Recorder
	|FROM
	|	[FullObjectName] AS RegisterTable
	|WHERE
	|	RegisterTable.Period >= &ExportStartDate";
	
	QueryText = StrReplace(QueryText, "[FullObjectName]", FullObjectName);
	
	Query = New Query;
	Query.SetParameter("ExportStartDate", ExportStartDate);
	Query.Text = QueryText;
	
	Return Query.Execute().Select();
EndFunction

// For internal use.
// 
Function MainInformationRegisterFilterValueSelectionByExportStartDateAndCompanies(MainFilter,
	FullObjectName,
	ExportStartDate,
	Companies)
	
	QueryText =
	"SELECT DISTINCT
	|	[Dimensions]
	|FROM
	|	[FullObjectName] AS RegisterTable
	|WHERE
	|	RegisterTable.Company IN(&Companies)
	|	AND RegisterTable.Period >= &ExportStartDate";
	
	QueryText = StrReplace(QueryText, "[FullObjectName]", FullObjectName);
	QueryText = StrReplace(QueryText, "[Dimensions]", StringFunctionsClientServer.StringFromSubstringArray(MainFilter));
	
	Query = New Query;
	Query.SetParameter("ExportStartDate", ExportStartDate);
	Query.SetParameter("Companies", Companies);
	Query.Text = QueryText;
	
	Return Query.Execute().Select();
EndFunction

// For internal use.
// 
Function MainInformationRegisterFilterValueSelectionByExportStartDate(MainFilter, FullObjectName, ExportStartDate)
	
	QueryText =
	"SELECT DISTINCT
	|	[Dimensions]
	|FROM
	|	[FullObjectName] AS RegisterTable
	|WHERE
	|	RegisterTable.Period >= &ExportStartDate";
	
	QueryText = StrReplace(QueryText, "[FullObjectName]", FullObjectName);
	QueryText = StrReplace(QueryText, "[Dimensions]", StringFunctionsClientServer.StringFromSubstringArray(MainFilter));
	
	Query = New Query;
	Query.SetParameter("ExportStartDate", ExportStartDate);
	Query.Text = QueryText;
	
	Return Query.Execute().Select();
EndFunction

// For internal use.
// 
Function MainInformationRegisterFilterByCompaniesValueSelection(MainFilter, FullObjectName, Companies)
	
	QueryText =
	"SELECT DISTINCT
	|	[Dimensions]
	|FROM
	|	[FullObjectName] AS RegisterTable
	|WHERE
	|	RegisterTable.Company IN(&Companies)";
	
	QueryText = StrReplace(QueryText, "[FullObjectName]", FullObjectName);
	QueryText = StrReplace(QueryText, "[Dimensions]", StringFunctionsClientServer.StringFromSubstringArray(MainFilter));
	
	Query = New Query;
	Query.SetParameter("Companies", Companies);
	Query.Text = QueryText;
	
	Return Query.Execute().Select();
EndFunction

// For internal use.
// 
Function MainInformationRegisterFilter(MetadataObject)
	
	Result = New Array;
	
	If MetadataObject.InformationRegisterPeriodicity <> Metadata.ObjectProperties.InformationRegisterPeriodicity.Nonperiodical
		And MetadataObject.MainFilterOnPeriod Then
		
		Result.Add("Period");
		
	EndIf;
	
	For Each Dimension In MetadataObject.Dimensions Do
		
		If Dimension.MainFilter Then
			
			Result.Add(Dimension.Name);
			
		EndIf;
		
	EndDo;
	
	Return Result;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Auxiliary internal procedures and functions.

// For internal use.
// 
Function DataExchangeMonitorTable(Val ExchangePlans, Val ExchangePlanAdditionalProperties = "", Val ExchangeWithErrorOnly = False) Export
	
	QueryText = "SELECT
	|	DataExchangeStates.InfobaseNode AS InfobaseNode,
	|	DataExchangeStates.EndDate AS EndDate,
	|	CASE
	|		WHEN DataExchangeStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.Warning_ExchangeMessageReceivedPreviously)
	|				OR DataExchangeStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.CompletedWithWarnings)
	|			THEN 2
	|		WHEN DataExchangeStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.Completed)
	|			THEN CASE
	|					WHEN ISNULL(IssueCount.Quantity, 0) > 0
	|						THEN 2
	|					ELSE 0
	|				END
	|		ELSE 1
	|	END AS ExchangeExecutionResult
	|INTO DataExchangeStatesImport
	|FROM
	|	InformationRegister.DataExchangeStates AS DataExchangeStates
	|		LEFT JOIN IssueCount AS IssueCount
	|		ON DataExchangeStates.InfobaseNode = IssueCount.InfobaseNode
	|WHERE
	|	DataExchangeStates.ActionOnExchange = VALUE(Enum.ActionsOnExchange.DataImport)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DataExchangeStates.InfobaseNode AS InfobaseNode,
	|	DataExchangeStates.EndDate AS EndDate,
	|	CASE
	|		WHEN DataExchangeStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.Warning_ExchangeMessageReceivedPreviously)
	|			THEN 2
	|		WHEN DataExchangeStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.CompletedWithWarnings)
	|			THEN 2
	|		WHEN DataExchangeStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.Completed)
	|			THEN 0
	|		ELSE 1
	|	END AS ExchangeExecutionResult
	|INTO DataExchangeStatesExport
	|FROM
	|	InformationRegister.DataExchangeStates AS DataExchangeStates
	|WHERE
	|	DataExchangeStates.ActionOnExchange = VALUE(Enum.ActionsOnExchange.DataExport)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SuccessfulDataExchangeStates.InfobaseNode AS InfobaseNode,
	|	SuccessfulDataExchangeStates.EndDate AS EndDate
	|INTO SuccessfulDataExchangeStatesImport
	|FROM
	|	InformationRegister.SuccessfulDataExchangeStates AS SuccessfulDataExchangeStates
	|WHERE
	|	SuccessfulDataExchangeStates.ActionOnExchange = VALUE(Enum.ActionsOnExchange.DataImport)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SuccessfulDataExchangeStates.InfobaseNode AS InfobaseNode,
	|	SuccessfulDataExchangeStates.EndDate AS EndDate
	|INTO SuccessfulDataExchangeStatesExport
	|FROM
	|	InformationRegister.SuccessfulDataExchangeStates AS SuccessfulDataExchangeStates
	|WHERE
	|	SuccessfulDataExchangeStates.ActionOnExchange = VALUE(Enum.ActionsOnExchange.DataExport)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DataExchangeScenarioExchangeSettings.InfobaseNode AS InfobaseNode
	|INTO DataSynchronizationScenarios
	|FROM
	|	Catalog.DataExchangeScenarios.ExchangeSettings AS DataExchangeScenarioExchangeSettings
	|WHERE
	|	DataExchangeScenarioExchangeSettings.Ref.UseScheduledJob = TRUE
	|
	|GROUP BY
	|	DataExchangeScenarioExchangeSettings.InfobaseNode
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ExchangePlans.ExchangePlanName AS ExchangePlanName,
	|	ExchangePlans.InfobaseNode AS InfobaseNode,
	|
	|	[ExchangePlanAdditionalProperties]
	|
	|	ISNULL(DataExchangeStatesExport.ExchangeExecutionResult, 0) AS LastDataExportResult,
	|	ISNULL(DataExchangeStatesImport.ExchangeExecutionResult, 0) AS LastDataImportResult,
	|	DataExchangeStatesImport.EndDate AS LastImportDate,
	|	DataExchangeStatesExport.EndDate AS LastExportDate,
	|	SuccessfulDataExchangeStatesImport.EndDate AS LastSuccessfulImportDate,
	|	SuccessfulDataExchangeStatesExport.EndDate AS LastSuccessfulExportDate,
	|	CASE
	|		WHEN DataSynchronizationScenarios.InfobaseNode IS NULL
	|			THEN 0
	|		ELSE 1
	|	END AS ScheduleConfigured
	|FROM
	|	ConfigurationExchangePlans AS ExchangePlans
	|		LEFT JOIN DataExchangeStatesImport AS DataExchangeStatesImport
	|		ON ExchangePlans.InfobaseNode = DataExchangeStatesImport.InfobaseNode
	|		LEFT JOIN DataExchangeStatesExport AS DataExchangeStatesExport
	|		ON ExchangePlans.InfobaseNode = DataExchangeStatesExport.InfobaseNode
	|		LEFT JOIN SuccessfulDataExchangeStatesImport AS SuccessfulDataExchangeStatesImport
	|		ON ExchangePlans.InfobaseNode = SuccessfulDataExchangeStatesImport.InfobaseNode
	|		LEFT JOIN SuccessfulDataExchangeStatesExport AS SuccessfulDataExchangeStatesExport
	|		ON ExchangePlans.InfobaseNode = SuccessfulDataExchangeStatesExport.InfobaseNode
	|		LEFT JOIN DataSynchronizationScenarios AS DataSynchronizationScenarios
	|		ON ExchangePlans.InfobaseNode = DataSynchronizationScenarios.InfobaseNode
	|
	|[Filter]
	|
	|ORDER BY
	|	ExchangePlans.ExchangePlanName,
	|	ExchangePlans.Description";
	
	SetPrivilegedMode(True);
	
	TempTablesManager = New TempTablesManager;
	
	GetExchangePlanTableForMonitor(TempTablesManager, ExchangePlans, ExchangePlanAdditionalProperties);
	GetExchangeResultTableForMonitor(TempTablesManager, ExchangePlans);
	
	QueryText = StrReplace(QueryText, "[ExchangePlanAdditionalProperties]", GetExchangePlanAdditionalPropertiesString(ExchangePlanAdditionalProperties));
	
	If ExchangeWithErrorOnly Then
		Filter = "
			|	WHERE ISNULL(DataExchangeStatesExport.ExchangeExecutionResult, 0) <> 0 OR ISNULL(DataExchangeStatesImport.ExchangeExecutionResult, 0) <> 0"
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
	SynchronizationSettings.Columns.Add("DataExchangeVariant", New TypeDescription("String"));
	
	For Each SynchronizationSettingsItem In SynchronizationSettings Do
		
		SynchronizationSettingsItem.LastImportDatePresentation           = RelativeSynchronizationDate(SynchronizationSettingsItem.LastImportDate);
		SynchronizationSettingsItem.LastExportDatePresentation           = RelativeSynchronizationDate(SynchronizationSettingsItem.LastExportDate);
		SynchronizationSettingsItem.LastSuccessfulImportDatePresentation = RelativeSynchronizationDate(SynchronizationSettingsItem.LastSuccessfulImportDate);
		SynchronizationSettingsItem.LastSuccessfulExportDatePresentation = RelativeSynchronizationDate(SynchronizationSettingsItem.LastSuccessfulExportDate);
		
		SynchronizationSettingsItem.DataExchangeVariant = DataExchangeVariant(SynchronizationSettingsItem.InfobaseNode);
		
	EndDo;
	
	Return SynchronizationSettings;
EndFunction

Function ConfiguredExchangeCount(Val ExchangePlans) Export
	
	QueryText = "SELECT
	|	1 AS Field1
	|FROM
	|	ConfigurationExchangePlans AS ExchangePlans";
	
	SetPrivilegedMode(True);
	
	TempTablesManager = New TempTablesManager;
	
	GetExchangePlanTableForMonitor(TempTablesManager, ExchangePlans, "");
	
	Query = New Query;
	Query.Text = QueryText;
	Query.TempTablesManager = TempTablesManager;
	
	Return Query.Execute().Unload().Count();
	
EndFunction

// For internal use.
// 
Function DataExchangeCompletedWithWarnings(Val InfobaseNode) Export
	
	SetPrivilegedMode(True);
	
	QueryText = "
	|SELECT TOP 1 1
	|FROM
	|	InformationRegister.DataExchangeStates AS DataExchangeStates
	|WHERE
	|	DataExchangeStates.InfobaseNode = &InfobaseNode
	|	AND (DataExchangeStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.Warning_ExchangeMessageReceivedPreviously)
	|			OR DataExchangeStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.CompletedWithWarnings))";
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("InfobaseNode", InfobaseNode);
	
	Return Not Query.Execute().IsEmpty();
	
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
Function ExchangePlanFilterByDataSeparationFlag(ExchangePlansArray)
	
	Result = New Array;
	
	If CommonUseCached.DataSeparationEnabled() Then
		
		If CommonUseCached.CanUseSeparatedData() Then
			
			For Each ExchangePlanName In ExchangePlansArray Do
				
				If CommonUseCached.IsSeparatedMetadataObject("ExchangePlan." + ExchangePlanName,
						CommonUseCached.MainDataSeparator())
					Or  CommonUseCached.IsSeparatedMetadataObject("ExchangePlan." + ExchangePlanName,
						CommonUseCached.AuxiliaryDataSeparator()) Then
					
					Result.Add(ExchangePlanName);
					
				EndIf;
				
			EndDo;
			
		Else
			
			For Each ExchangePlanName In ExchangePlansArray Do
				
				If Not CommonUseCached.IsSeparatedMetadataObject("ExchangePlan." + ExchangePlanName,
						CommonUseCached.MainDataSeparator())
					And Not CommonUseCached.IsSeparatedMetadataObject("ExchangePlan." + ExchangePlanName,
						CommonUseCached.AuxiliaryDataSeparator()) Then
					
					Result.Add(ExchangePlanName);
					
				EndIf;
				
			EndDo;
			
		EndIf;
		
	Else
		
		For Each ExchangePlanName In ExchangePlansArray Do
			
			Result.Add(ExchangePlanName);
			
		EndDo;
		
	EndIf;
	
	Return Result;
EndFunction

// For internal use.
// 
Function ExchangePlanFilterByStandaloneModeFlag(ExchangePlansArray)
	
	Result = New Array;
	
	For Each ExchangePlanName In ExchangePlansArray Do
		
		If ExchangePlanName <> DataExchangeCached.StandaloneModeExchangePlan() Then
			
			Result.Add(ExchangePlanName);
			
		EndIf;
		
	EndDo;
	
	Return Result;
EndFunction

// For internal use.
// 
Function CorrespondentTablesForDefaultValues(Val ExchangePlanName, Val CorrespondentVersion) Export
	
	Result = New Array;
	
	DefaultValues = CorrespondentInfobaseNodeDefaultValues(ExchangePlanName, CorrespondentVersion);
	
	For Each Item In DefaultValues Do
		
		If Find(Item.Key, "_Key") > 0 Then
			Continue;
		EndIf;
		
		Result.Add(Item.Key);
		
	EndDo;
	
	Return New FixedArray(Result);
	
EndFunction

// Deletes obsolete records from the information register.
// The record is considered obsolete if the exchange plan that
// includes the record was renamed or deleted.
// 
Procedure DeleteObsoleteRecordsFromDataExchangeRuleRegister()
	
	ExchangePlanList = DataExchangeCached.SLExchangePlanList();
	
	QueryText = "
	|SELECT DISTINCT
	|	DataExchangeRules.ExchangePlanName AS ExchangePlanName
	|FROM
	|	InformationRegister.DataExchangeRules AS DataExchangeRules
	|";
	
	Query = New Query;
	Query.Text = QueryText;
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		If ExchangePlanList.FindByValue(Selection.ExchangePlanName) = Undefined Then
			
			RecordSet = CreateInformationRegisterRecordSet(New Structure("ExchangePlanName", Selection.ExchangePlanName), "DataExchangeRules");
			RecordSet.Write();
			
		EndIf;
		
	EndDo;
	
EndProcedure

// For internal use.
// 
Procedure GetExchangePlanTableForMonitor(TempTablesManager, ExchangePlansArray, Val ExchangePlanAdditionalProperties)
	
	MethodExchangePlans = ExchangePlanFilterByDataSeparationFlag(ExchangePlansArray);
	
	If DataExchangeCached.StandaloneModeSupported() Then
		
		// Using separate monitor for the exchange plan of the standalone mode
		MethodExchangePlans = ExchangePlanFilterByStandaloneModeFlag(MethodExchangePlans);
		
	EndIf;
	
	ExchangePlanAdditionalPropertiesString = ?(IsBlankString(ExchangePlanAdditionalProperties), "", ExchangePlanAdditionalProperties + ", ");
	
	Query = New Query;
	
	QueryPattern = "
	|
	|UNION ALL
	|
	|//////////////////////////////////////////////////////// {[ExchangePlanName]}
	|SELECT
	|
	|	[ExchangePlanAdditionalProperties]
	|
	|	Ref                       AS InfobaseNode,
	|	Description               AS Description,
	|	""[ExchangePlanSynonym]"" AS ExchangePlanName
	|FROM
	|	ExchangePlan.[ExchangePlanName]
	|WHERE
	|	     Ref <> &ThisNode[ExchangePlanName]
	|	AND Not DeletionMark
	|";
	
	QueryText = "";
	
	If MethodExchangePlans.Count() > 0 Then
		
		For Each ExchangePlanName In MethodExchangePlans Do
			
			ExchangePlanQueryText = StrReplace(QueryPattern,          "[ExchangePlanName]",    ExchangePlanName);
			ExchangePlanQueryText = StrReplace(ExchangePlanQueryText, "[ExchangePlanSynonym]", Metadata.ExchangePlans[ExchangePlanName].Synonym);
			ExchangePlanQueryText = StrReplace(ExchangePlanQueryText, "[ExchangePlanAdditionalProperties]", ExchangePlanAdditionalPropertiesString);
			
			ParameterName = StrReplace("ThisNode[ExchangePlanName]", "[ExchangePlanName]", ExchangePlanName);
			Query.SetParameter(ParameterName, DataExchangeCached.GetThisExchangePlanNode(ExchangePlanName));
			
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
		|	[AdditionalPropertiesWithoutDataSourceString]
		|
		|	Undefined AS InfobaseNode,
		|	Undefined AS Description,
		|	Undefined AS ExchangePlanName
		|";
		
		QueryText = StrReplace(QueryText, "{AdditionalPropertiesWithoutDataSourceString}", AdditionalPropertiesWithoutDataSourceString);
		
	EndIf;
	
	QueryTextResult = "
	|//////////////////////////////////////////////////////// {ConfigurationExchangePlans}
	|SELECT
	|
	|	[ExchangePlanAdditionalProperties]
	|
	|	InfobaseNode,
	|	Description,
	|	ExchangePlanName
	|INTO ConfigurationExchangePlans
	|FROM
	|	(
	|	[QueryText]
	|	) AS NestedQuery
	|;
	|";
	
	QueryTextResult = StrReplace(QueryTextResult, "[QueryText]", QueryText);
	QueryTextResult = StrReplace(QueryTextResult, "[ExchangePlanAdditionalProperties]", ExchangePlanAdditionalPropertiesString);
	
	Query.Text = QueryTextResult;
	Query.TempTablesManager = TempTablesManager;
	Query.Execute();
	
EndProcedure

// For internal use.
// 
Procedure GetExchangeResultTableForMonitor(TempTablesManager, ExchangePlansArray)
	
	Query = New Query;
	
	If CommonUseCached.CanUseSeparatedData() Then
		
		QueryTextResult = "
		|SELECT
		|	DataExchangeResults.InfobaseNode AS InfobaseNode,
		|	COUNT(DISTINCT DataExchangeResults.ProblematicObjects) AS Quantity
		|INTO IssueCount
		|FROM
		|	InformationRegister.DataExchangeResults AS DataExchangeResults
		|WHERE
		|	DataExchangeResults.Skipped = FALSE
		|
		|GROUP BY
		|	DataExchangeResults.InfobaseNode";
		
	Else
		
		QueryTextResult = "
		|SELECT
		|	Undefined AS InfobaseNode,
		|	Undefined AS Quantity
		|INTO IssueCount";
		
	EndIf;
	
	Query.Text = QueryTextResult;
	Query.TempTablesManager = TempTablesManager;
	Query.Execute();
	
EndProcedure

// For internal use only.
//
Function ExchangePlansWithRulesFromFile()
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	DataExchangeRules.ExchangePlanName
	|FROM
	|	InformationRegister.DataExchangeRules AS DataExchangeRules
	|WHERE
	|	DataExchangeRules.RuleSource = &RuleSource";
	
	Query.SetParameter("RuleSource", Enums.DataExchangeRuleSources.File);
	Result = Query.Execute().Unload();
	
	Return Result.Count();
	
EndFunction
 

// For internal use.
// 
Procedure CheckUseDataExchange() Export
	
	If GetFunctionalOption("UseDataSynchronization") <> True Then
		
		MessageText = NStr("en = 'Synchronization is disabled by your administrator.'");
		WriteLogEvent(EventLogMessageTextDataExchange(), EventLogLevel.Error,,,MessageText);
		Raise MessageText;
		
	EndIf;
	
EndProcedure

// For internal use.
// 
Procedure CheckCanSynchronizeData() Export
	
	If Not Users.RolesAvailable("SynchronizeData, DataSynchronizationSetup") Then
		
		Raise NStr("en = 'Insufficient rights to perform the data synchronization.'");
		
	ElsIf InfobaseUpdate.InfobaseUpdateRequired()
	        And Not DataExchangeServerCall.DataExchangeMessageImportModeBeforeStart("ImportPermitted") Then
		
		Raise NStr("en = 'Current infobase is updating now.'");
		
	EndIf;
	
EndProcedure

// For internal use.
// 
Procedure CheckExchangeManagementRights() Export
	
	If Not Users.RolesAvailable("DataSynchronizationSetup") Then
		
		Raise NStr("en = 'Insufficient rights to administer the data synchronization.'");
		
	EndIf;
	
EndProcedure

// For internal use.
// 
Procedure CheckExternalConnectionAvailable()
	
	If CommonUse.IsLinuxServer() Then
		
		Raise NStr("en = 'If the server runs on Linux, synchronization over the direct connection is unavailable.
			|To execute data synchronization over the direct connection, 1C:Enterprise must run on Windows.'");
			
	EndIf;
	
EndProcedure

// Returns the flag that shows whether a user has rights to perform the data synchronization.
// A user can perform data synchronization if it has either full access
// or rights of the "Data synchronization with other applications" supplied profile.
//
//  Parameters:
//    User (optional) - InfobaseUser, Undefined.
//    This user is used to define whether the data synchronization is available.
//    If this parameter is not set, the current infobase user is used to calculate the function result.
//
Function DataSynchronizationPermitted(Val User = Undefined) Export
	
	If User = Undefined Then
		User = InfobaseUsers.CurrentUser();
	EndIf;
	
	If User.Roles.Contains(Metadata.Roles.FullAccess) Then
		Return True;
	EndIf;
	
	ProfileRoles = StringFunctionsClientServer.SplitStringIntoSubstringArray(
		DataSynchronizationAccessProfileWithOtherApplicationsRoles());
	For Each Role In ProfileRoles Do
		
		If Not User.Roles.Contains(Metadata.Roles.Find(TrimAll(Role))) Then
			Return False;
		EndIf;
		
	EndDo;
	
	Return True;
EndFunction


// Fills the value list with transport kind available for the exchange plan node.
//
Procedure FillChoiceListWithAvailableTransportTypes(InfobaseNode, FormItem, Filter = Undefined) Export
	
	FilterSet = (Filter <> Undefined);
	
	UsedTransports = DataExchangeCached.UsedExchangeMessageTransports(InfobaseNode);
	
	FormItem.ChoiceList.Clear();
	
	For Each Item In UsedTransports Do
		
		If FilterSet Then
			
			If Filter.Find(Item) <> Undefined Then
				
				FormItem.ChoiceList.Add(Item, String(Item));
				
			EndIf;
			
		Else
			
			FormItem.ChoiceList.Add(Item, String(Item));
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Writes a success exchange message to the event log.
//
// Parameters:
//  ExchangeSettingsStructure - Structure - structure with all required for exchange data and objects.
// 
Procedure AddExchangeFinishEventLogMessage(ExchangeSettingsStructure) Export
	
	// The Undefined state in the end of the exchange indicates that the exchange has been performed successfully.
	If ExchangeSettingsStructure.ExchangeExecutionResult = Undefined Then
		ExchangeSettingsStructure.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Completed;
	EndIf;
	
	// Generating the final message to be written
	If ExchangeSettingsStructure.IsDIBExchange Then
		MessageString = NStr("en = '%1, %2'", CommonUseClientServer.DefaultLanguageCode());
		MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString,
							ExchangeSettingsStructure.ExchangeExecutionResult,
							ExchangeSettingsStructure.ActionOnExchange);
	Else
		MessageString = NStr("en = '%1, %2; %3 objects processed.'", CommonUseClientServer.DefaultLanguageCode());
		MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString,
							ExchangeSettingsStructure.ExchangeExecutionResult,
							ExchangeSettingsStructure.ActionOnExchange,
							ExchangeSettingsStructure.ProcessedObjectCount);
	EndIf;
	
	ExchangeSettingsStructure.EndDate = CurrentSessionDate();
	
	// Writing the exchange state to the information register
	AddExchangeFinishMessageToInformationRegister(ExchangeSettingsStructure);
	
	// The data exchange has been completed successfully
	If ExchangeExecutionResultCompleted(ExchangeSettingsStructure.ExchangeExecutionResult) Then
		
		AddSuccessfulDataExchangeMessageToInformationRegister(ExchangeSettingsStructure);
		
		InformationRegisters.CommonInfobaseNodeSettings.ClearDataSendingFlag(ExchangeSettingsStructure.InfobaseNode);
		
	EndIf;
	
	WriteEventLogDataExchange(MessageString, ExchangeSettingsStructure);
	
EndProcedure

// Writes the data exchange state to the DataExchangeStates information register.
//
// Parameters:
//  ExchangeSettingsStructure - Structure - structure with all required for exchange data and objects.
// 
Procedure AddExchangeFinishMessageToInformationRegister(ExchangeSettingsStructure)
	
	// Generating a structure for the new information register record
	RecordStructure = New Structure;
	RecordStructure.Insert("InfobaseNode",            ExchangeSettingsStructure.InfobaseNode);
	RecordStructure.Insert("ActionOnExchange",        ExchangeSettingsStructure.ActionOnExchange);
	
	RecordStructure.Insert("ExchangeExecutionResult", ExchangeSettingsStructure.ExchangeExecutionResult);
	RecordStructure.Insert("StartDate",               ExchangeSettingsStructure.StartDate);
	RecordStructure.Insert("EndDate",                 ExchangeSettingsStructure.EndDate);
	
	InformationRegisters.DataExchangeStates.AddRecord(RecordStructure);
	
EndProcedure

// For internal use.
// 
Procedure AddSuccessfulDataExchangeMessageToInformationRegister(ExchangeSettingsStructure)
	
	// Generating a structure for the new information register record
	RecordStructure = New Structure;
	RecordStructure.Insert("InfobaseNode",     ExchangeSettingsStructure.InfobaseNode);
	RecordStructure.Insert("ActionOnExchange", ExchangeSettingsStructure.ActionOnExchange);
	RecordStructure.Insert("EndDate",          ExchangeSettingsStructure.EndDate);
	
	InformationRegisters.SuccessfulDataExchangeStates.AddRecord(RecordStructure);
	
EndProcedure

// For internal use.
// 
Procedure WriteLogEventDataExchangeStart(ExchangeSettingsStructure) Export
	
	MessageString = NStr("en = 'Data exchange process started for %1 node'", CommonUseClientServer.DefaultLanguageCode());
	MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, ExchangeSettingsStructure.InfobaseNodeDescription);
	WriteEventLogDataExchange(MessageString, ExchangeSettingsStructure);
	
EndProcedure

// Supplements the value table with empty rows to reach the specified number of rows.
//
Procedure SetTableRowCount(Table, LineCount) Export
	
	While Table.Count() < LineCount Do
		
		Table.Add();
		
	EndDo;
	
EndProcedure

// Writes the data exchange event message or the transport message to the event log.
//
Procedure WriteEventLogDataExchange(Comment, ExchangeSettingsStructure, IsError = False) Export
	
	Level = ?(IsError, EventLogLevel.Error, EventLogLevel.Information);
	
	WriteLogEvent(ExchangeSettingsStructure.EventLogMessageKey, Level,,, Comment);
	
EndProcedure

Procedure WriteDataReceiveEvent(Val InfobaseNode, Val Comment, Val IsError = False)
	
	Level = ?(IsError, EventLogLevel.Error, EventLogLevel.Information);
	
	EventLogMessageKey = GetEventLogMessageKey(InfobaseNode, Enums.ActionsOnExchange.DataImport);
	
	WriteLogEvent(EventLogMessageKey, Level,,, Comment);
	
EndProcedure

// For internal use.
// 
Procedure NodeSettingsFormOnCreateAtServerHandler(Form, FormAttributeName)
	
	FormAttributes = FormAttributeNames(Form);
	
	For Each FilterSettings In Form[FormAttributeName] Do
		
		Key = FilterSettings.Key;
		
		If FormAttributes.Find(Key) = Undefined Then
			Continue;
		EndIf;
		
		If TypeOf(Form[Key]) = Type("FormDataCollection") Then
			
			Table = New ValueTable;
			
			TabularSectionStructure = Form.Parameters[FormAttributeName][Key];
			
			For Each Item In TabularSectionStructure Do
				
				SetTableRowCount(Table, Item.Value.Count());
				
				Table.Columns.Add(Item.Key);
				
				Table.LoadColumn(Item.Value, Item.Key);
				
			EndDo;
			
			Form[Key].Load(Table);
			
		Else
			
			Form[Key] = Form.Parameters[FormAttributeName][Key];
			
		EndIf;
		
		Form[FormAttributeName][Key] = Form.Parameters[FormAttributeName][Key];
		
	EndDo;
	
EndProcedure

// For internal use.
// 
Function FormAttributeNames(Form)
	
	// Return value
	Result = New Array;
	
	For Each FormAttribute In Form.GetAttributes() Do
		
		Result.Add(FormAttribute.Name);
		
	EndDo;
	
	Return Result;
EndFunction

// Unpacks the ZIP archive file to the specified directory. Extracts all files from the archive.
// 
// Parameters:
//  ArchiveFileFullName  - String - name of the archive file to be unpacked.
//  FileUnpackPath       - String - path where files are extracted.
//  ArchivePassword      - String - password for unpacking the archive. The default
//                         value is an empty string.
// 
// Returns:
//  Result - Boolean - True if the archive is extracted successfully, otherwise False.

//
Function UnpackZipFile(Val ArchiveFileFullName, Val FileUnpackPath, Val ArchivePassword = "") Export
	
	// Return value
	Result = True;
	
	Try
		
		Archiver = New ZipFileReader(ArchiveFileFullName, ArchivePassword);
		
	Except
		Archiver = Undefined;
		ReportError(BriefErrorDescription(ErrorInfo()));
		Return False;
	EndTry;
	
	Try
		
		Archiver.ExtractAll(FileUnpackPath, ZIPRestoreFilePathsMode.DontRestore);
		
	Except
		
		MessageString = NStr("en = 'Error unpacking the %1 archive files to the %2  directory.'");
		MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, ArchiveFileFullName, FileUnpackPath);
		CommonUseClientServer.MessageToUser(MessageString);
		
		Result = False;
	EndTry;
	
	Archiver.Close();
	Archiver = Undefined;
	
	Return Result;
	
EndFunction

// Packs the specified directory into a ZIP archive file.
// 
// Parameters:
//  ArchiveFileFullName  - String - name of the archive file where data must be packed.
//  FilePackingMask      - String - name of the file or mask of files to be packed.
//                         It is prohibited that you name files and directories using 
//                         characters that can be converted to UNICODE characters and
//                         back incorrectly. 
//                         It is recommended that you use only roman characters to name
//                         files and folders. 
//  ArchivePassword      - String - archive password. The default value is an empty string.
// 
// Returns:
//  Result - Boolean - True if the archive is packed successfully, otherwise False.
//
Function PackIntoZipFile(Val ArchiveFileFullName, Val FilePackingMask, Val ArchivePassword = "") Export
	
	// Return value
	Result = True;
	
	Try
		
		Archiver = New ZipFileWriter(ArchiveFileFullName, ArchivePassword);
		
	Except
		Archiver = Undefined;
		ReportError(BriefErrorDescription(ErrorInfo()));
		Return False;
	EndTry;
	
	Try
		
		Archiver.Add(FilePackingMask, ZIPStorePathMode.DontStorePath);
		Archiver.Write();
		
	Except
		
		MessageString = NStr("en = 'Error packing the %1 archive files from the %2 directory.'");
		MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, ArchiveFileFullName, FilePackingMask);
		CommonUseClientServer.MessageToUser(MessageString);
		
		Result = False;
	EndTry;
	
	Archiver = Undefined;
	
	Return Result;
	
EndFunction

// Returns the number of records in the infobase table.
// 
// Parameters:
//  TableName - String - full name of the infobase table. For example: "Catalog.Counterparties.Orders".
// 
// Returns:
//  Number - number of records in the infobase table.
//
Function RecordCountInInfobaseTable(Val TableName) Export
	
	QueryText = "
	|SELECT
	|	Count(*) AS Quantity
	|FROM
	|	#TableName
	|";
	
	QueryText = StrReplace(QueryText, "#TableName", TableName);
	
	Query = New Query;
	Query.Text = QueryText;
	
	Selection = Query.Execute().Select();
	Selection.Next();
	
	Return Selection["Quantity"];
	
EndFunction

// Returns the number of records in the temporary infobase table.
// 
// Parameters:
//  TableName         – String – table name. For example: "TemporaryTable1".
//  TempTablesManager - temporary table manager that points to the TableName temporary table. 
// 
// Returns:
//  Number - number of records in the temporary infobase table.
//
Function TempInfobaseTableRecordCount(Val TableName, TempTablesManager) Export
	
	QueryText = "
	|SELECT
	|	Count(*) AS Quantity
	|FROM
	|	#TableName
	|";
	
	QueryText = StrReplace(QueryText, "#TableName", TableName);
	
	Query = New Query;
	Query.Text = QueryText;
	Query.TempTablesManager = TempTablesManager;
	
	Selection = Query.Execute().Select();
	Selection.Next();
	
	Return Selection["Quantity"];
	
EndFunction

// Returns the event log message key.
//
Function GetEventLogMessageKey(InfobaseNode, ActionOnExchange) Export
	
	ExchangePlanName     = DataExchangeCached.GetExchangePlanName(InfobaseNode);
	ExchangePlanNodeCode = TrimAll(CommonUse.ObjectAttributeValue(InfobaseNode, "Code"));
	
	MessageKey = NStr("en = 'Exchange data.[ExchangePlanName].Node [NodeCode].[ActionOnExchange]'",
		CommonUseClientServer.DefaultLanguageCode());
	
	MessageKey = StrReplace(MessageKey, "[ExchangePlanName]", ExchangePlanName);
	MessageKey = StrReplace(MessageKey, "[NodeCode]",         ExchangePlanNodeCode);
	MessageKey = StrReplace(MessageKey, "[ActionOnExchange]", ActionOnExchange);
	
	Return MessageKey;
	
EndFunction

// Returns the name of data exchange message file based on the sender node data and the target node data.
//
Function ExchangeMessageFileName(SenderNodeCode, RecipientNodeCode) Export
	
	NamePattern = "[Prefix]_[SenderNode]_[RecipientNode]";
	
	NamePattern = StrReplace(NamePattern, "[Prefix]",        "Message");
	NamePattern = StrReplace(NamePattern, "[SenderNode]",    SenderNodeCode);
	NamePattern = StrReplace(NamePattern, "[RecipientNode]", RecipientNodeCode);
	
	Return NamePattern;
EndFunction

// Checks whether the attribute is standard one.
//
Function IsStandardAttribute(StandardAttributes, AttributeName) Export
	
	For Each Attribute In StandardAttributes Do
		
		If Attribute.Name = AttributeName Then
			
			Return True;
			
		EndIf;
		
	EndDo;
	
	Return False;
	
EndFunction

// Returns an array of all exchange message transport kinds defined in the configuration.
// 
//  Returns:
//  Array of EnumRef.ExchangeMessageTransportKinds;
//
Function AllApplicationExchangeMessageTransports() Export
	
	Result = New Array;
	Result.Add(Enums.ExchangeMessageTransportKinds.COM);
	Result.Add(Enums.ExchangeMessageTransportKinds.WS);
	Result.Add(Enums.ExchangeMessageTransportKinds.FILE);
	Result.Add(Enums.ExchangeMessageTransportKinds.FTP);
	Result.Add(Enums.ExchangeMessageTransportKinds.EMAIL);
	
	Return Result;
EndFunction

// Checks whether the exchange has been performed successfully.
//
Function ExchangeExecutionResultCompleted(ExchangeExecutionResult)
	
	Return ExchangeExecutionResult = Undefined
		Or ExchangeExecutionResult = Enums.ExchangeExecutionResults.Completed
		Or ExchangeExecutionResult = Enums.ExchangeExecutionResults.CompletedWithWarnings;
	
EndFunction

// Generating the data table key.
// The table key is used for importing data selectively from the exchange message.
//
Function DataTableKey(Val SourceType, Val TargetType, Val IsObjectDeletion) Export
	
	Return SourceType + "#" + TargetType + "#" + String(IsObjectDeletion);
	
EndFunction

// For internal use.
// 
Function MustExecuteHandler(Object, Ref, PropertyName)
	
	NumberAfterProcessing = Object[PropertyName];
	
	NumberBeforeProcessing = CommonUse.ObjectAttributeValue(Ref, PropertyName);
	
	NumberBeforeProcessing = ?(NumberBeforeProcessing = Undefined, 0, NumberBeforeProcessing);
	
	Return NumberBeforeProcessing <> NumberAfterProcessing;
	
EndFunction

// For internal use.
// 
Function FillExternalConnectionParameters(TransportSettings)
	
	ConnectionParameters = CommonUseClientServer.ExternalConnectionParameterStructure();
	
	ConnectionParameters.InfobaseOperationMode        = TransportSettings.COMInfobaseOperationMode;
	ConnectionParameters.InfobaseDirectory            = TransportSettings.COMInfobaseDirectory;
	ConnectionParameters.PlatformServerName           = TransportSettings.COMPlatformServerName;
	ConnectionParameters.InfobaseNameAtPlatformServer = TransportSettings.COMInfobaseNameAtPlatformServer;
	ConnectionParameters.OSAuthentication             = TransportSettings.COMOSAuthentication;
	ConnectionParameters.UserName                     = TransportSettings.COMUserName;
	ConnectionParameters.UserPassword                 = TransportSettings.COMUserPassword;

	
	Return ConnectionParameters;
EndFunction

// For internal use.
// 
Function AddLiteralToFileName(Val FullFileName, Val Literal)
	
	If IsBlankString(FullFileName) Then
		Return "";
	EndIf;
	
	FileNameWithoutExtension = Mid(FullFileName, 1, StrLen(FullFileName) - 4);
	
	Extension = Right(FullFileName, 3);
	
	Result = "[FileNameWithoutExtension]_[Literal].[Extension]";
	
	Result = StrReplace(Result, "[FileNameWithoutExtension]", FileNameWithoutExtension);
	Result = StrReplace(Result, "[Literal]",                  Literal);
	Result = StrReplace(Result, "[Extension]",                Extension);
	
	Return Result;
EndFunction

// For internal use.
// 
Function ExchangePlanNodeCodeString(Value) Export
	
	If TypeOf(Value) = Type("String") Then
		
		Return TrimAll(Value);
		
	ElsIf TypeOf(Value) = Type("Number") Then
		
		Return Format(Value, "ND=7; NLZ=; NG=0");
		
	EndIf;
	
	Return Value;
EndFunction

// For internal use.
// 
Function DataAreaNumberByExchangePlanNodeCode(Val NodeCode) Export
	
	If TypeOf(NodeCode) <> Type("String") Then
		Raise NStr("en = 'The type of parameter #1 is incorrect.'");
	EndIf;
	
	Result = StrReplace(NodeCode, "S0", "");
	
	Return Number(Result);
EndFunction

// For internal use.
// 
Function ValueByType(Value, TypeName) Export
	
	If TypeOf(Value) <> Type(TypeName) Then
		
		Return New(Type(TypeName));
		
	EndIf;
	
	Return Value;
EndFunction

// For internal use.
// 
Function PredefinedExchangePlanNodeDescription(ExchangePlanName) Export
	
	SetPrivilegedMode(True);
	
	Return CommonUse.ObjectAttributeValue(DataExchangeCached.GetThisExchangePlanNode(ExchangePlanName), "Description");
EndFunction

// For internal use.
// 
Function ThisNodeDefaultDescription() Export
	
	Return ?(CommonUseCached.DataSeparationEnabled(), Metadata.Synonym, DataExchangeCached.ThisInfobaseName());
	
EndFunction

// For internal use.
// 
Procedure OnSLDataExportHandler(StandardProcessing,
											Val Recipient,
											Val MessageFileName,
											MessageData,
											Val TransactionItemCount,
											Val EventLogEventName,
											SentObjectCount)
	
	EventHandlers = CommonUse.InternalEventHandlers(
		"StandardSubsystems.DataExchange\OnDataExportInternal");
	
	For Each Handler In EventHandlers Do
		Handler.Module.OnDataExportInternal(
			StandardProcessing,
			Recipient,
			MessageFileName,
			MessageData,
			TransactionItemCount,
			EventLogEventName,
			SentObjectCount);
	EndDo;
	
EndProcedure

// For internal use.
// 
Procedure OnDataExportHandler(StandardProcessing,
											Val Recipient,
											Val MessageFileName,
											MessageData,
											Val TransactionItemCount,
											Val EventLogEventName,
											SentObjectCount)
	
	DataExchangeOverridable.OnDataExport(StandardProcessing,
											Recipient,
											MessageFileName,
											MessageData,
											TransactionItemCount,
											EventLogEventName,
											SentObjectCount);
	
EndProcedure

// For internal use.
// 
Procedure OnSLDataImportHandler(StandardProcessing,
											Val From,
											Val MessageFileName,
											MessageData,
											Val TransactionItemCount,
											Val EventLogEventName,
											ReceivedObjectCount)
	
	EventHandlers = CommonUse.InternalEventHandlers(
		"StandardSubsystems.DataExchange\OnDataImportInternal");
	
	For Each Handler In EventHandlers Do
		Handler.Module.OnDataImportInternal(
			StandardProcessing,
			From,
			MessageFileName,
			MessageData,
			TransactionItemCount,
			EventLogEventName,
			ReceivedObjectCount);
	EndDo;
	
EndProcedure

// For internal use.
// 
Procedure OnDataImportHandler(StandardProcessing,
											Val From,
											Val MessageFileName,
											MessageData,
											Val TransactionItemCount,
											Val EventLogEventName,
											ReceivedObjectCount)
	
	DataExchangeOverridable.OnDataImport(StandardProcessing,
											From,
											MessageFileName,
											MessageData,
											TransactionItemCount,
											EventLogEventName,
											ReceivedObjectCount);
	
EndProcedure

// For internal use.
// 
Procedure AddExchangeFinishedWithErrorEventLogMessage(Val InfobaseNode, 
												Val ActionOnExchange, 
												Val StartDate, 
												Val ErrorMessageString
	) Export
	
	If TypeOf(ActionOnExchange) = Type("String") Then
		
		ActionOnExchange = Enums.ActionsOnExchange[ActionOnExchange];
		
	EndIf;
	
	ExchangeSettingsStructure = New Structure;
	ExchangeSettingsStructure.Insert("InfobaseNode", InfobaseNode);
	ExchangeSettingsStructure.Insert("ExchangeExecutionResult", Enums.ExchangeExecutionResults.Error);
	ExchangeSettingsStructure.Insert("ActionOnExchange", ActionOnExchange);
	ExchangeSettingsStructure.Insert("ProcessedObjectCount", 0);
	ExchangeSettingsStructure.Insert("EventLogMessageKey", GetEventLogMessageKey(InfobaseNode, ActionOnExchange));
	ExchangeSettingsStructure.Insert("StartDate", StartDate);
	ExchangeSettingsStructure.Insert("EndDate", CurrentSessionDate());
	ExchangeSettingsStructure.Insert("IsDIBExchange", DataExchangeCached.IsDistributedInfobaseNode(InfobaseNode));
	
	WriteEventLogDataExchange(ErrorMessageString, ExchangeSettingsStructure, True);
	
	AddExchangeFinishEventLogMessage(ExchangeSettingsStructure);
	
EndProcedure

// For internal use.
// 
Procedure ExecuteFormTablesComparisonAndMerging(Form, Cancel)
	
	ExchangePlanName = StringFunctionsClientServer.SplitStringIntoSubstringArray(Form.FormName, ".")[1];
	
	CorrespondentData = CorrespondentNodeCommonData(ExchangePlanName, Form.Parameters.ConnectionParameters, Cancel);
	
	If CorrespondentData = Undefined Then
		Return;
	EndIf;
	
	ThisInfobaseData = DataForThisInfobaseNodeTabularSections(ExchangePlanName, Form.CorrespondentVersion);
	
	ExchangePlanTabularSections = DataExchangeCached.ExchangePlanTabularSections(ExchangePlanName, Form.CorrespondentVersion);
	
	FormAttributeNames = FormAttributeNames(Form);
	
	// Merging common data tables
	For Each TabularSectionName In ExchangePlanTabularSections["CommonTables"] Do
		
		If FormAttributeNames.Find(TabularSectionName) = Undefined Then
			Continue;
		EndIf;
		
		CommonTable = New ValueTable;
		CommonTable.Columns.Add("Presentation", New TypeDescription("String"));
		CommonTable.Columns.Add("RefUUID",      New TypeDescription("String"));
		
		For Each TableRow In ThisInfobaseData[TabularSectionName] Do
			
			FillPropertyValues(CommonTable.Add(), TableRow);
			
		EndDo;
		
		For Each TableRow In CorrespondentData[TabularSectionName] Do
			
			FillPropertyValues(CommonTable.Add(), TableRow);
			
		EndDo;
		
		ResultTable = CommonTable.Copy(, "RefUUID");
		ResultTable.GroupBy("RefUUID");
		ResultTable.Columns.Add("Presentation", New TypeDescription("String"));
		ResultTable.Columns.Add("Use", New TypeDescription("Boolean"));
		
		For Each ResultTableRow In ResultTable Do
			
			TableRow = CommonTable.Find(ResultTableRow.RefUUID, "RefUUID");
			
			ResultTableRow.Presentation = TableRow.Presentation;
			
		EndDo;
		
		SynchronizeUseAttributeInTablesFlag(Form[TabularSectionName], ResultTable);
		
		ResultTable.Sort("Presentation");
		
		Form[TabularSectionName].Load(ResultTable);
		
	EndDo;
	
	CurrentApplicationAttributeMap = Form.AttributeNames;
	
	// Merging this infobase data tables
	For Each TabularSectionName In ExchangePlanTabularSections["ThisInfobaseTables"] Do
		
		If CurrentApplicationAttributeMap.Property(TabularSectionName) Then
			AttributeName = CurrentApplicationAttributeMap[TabularSectionName];
		ElsIf FormAttributeNames.Find(TabularSectionName) = Undefined Then
			Continue;
		Else
			AttributeName = TabularSectionName;
		EndIf;
		
		ResultTable = ThisInfobaseData[TabularSectionName].Copy();
		ResultTable.Columns.Add("Use", New TypeDescription("Boolean"));
		
		SynchronizeUseAttributeInTablesFlag(Form[AttributeName], ResultTable);
		
		Form[AttributeName].Load(ResultTable);
		
	EndDo;
	
	CorrespondentAttributeMap = Form.CorrespondentInfobaseAttributeNames;
	
	// Merging correspondent infobase data tables
	For Each TabularSectionName In ExchangePlanTabularSections["CorrespondentTables"] Do
		
		If CorrespondentAttributeMap.Property(TabularSectionName) Then
			AttributeName = CorrespondentAttributeMap[TabularSectionName];
		ElsIf FormAttributeNames.Find(TabularSectionName) = Undefined Then
			Continue;
		Else
			AttributeName = TabularSectionName;
		EndIf;
		
		ResultTable = CorrespondentData[TabularSectionName].Copy();
		ResultTable.Columns.Add("Use", New TypeDescription("Boolean"));
		
		SynchronizeUseAttributeInTablesFlag(Form[AttributeName], ResultTable);
		
		Form[AttributeName].Load(ResultTable);
		
	EndDo;
	
EndProcedure

// For internal use.
// 
Procedure SynchronizeUseAttributeInTablesFlag(FormTable, ResultTable)
	
	If FormTable.Count() = 0 Then
		
		// Setting all flags to True during the first table call
		ResultTable.FillValues(True, "Use");
		
	Else
		
		// If there is a previous table context, using it to set flags.
		PreviousContextTable = FormTable.Unload(New Structure("Use", True), "RefUUID");
		
		ResultTable.FillValues(False, "Use");
		
		For Each ContextTableRow In PreviousContextTable Do
			
			TableRow = ResultTable.Find(ContextTableRow.RefUUID, "RefUUID");
			
			If TableRow <> Undefined Then
				
				TableRow.Use = True;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure

// For internal use.
// 
Procedure FillFormData(Form)
	
	// Filling data of the current application
	MappedAttributes    = Form.AttributeNames;
	NodeFilterStructure = Form.Context.NodeFilterStructure;
	
	For Each SettingItem In NodeFilterStructure Do
		
		If MappedAttributes.Property(SettingItem.Key) Then
			AttributeName = MappedAttributes[SettingItem.Key];
		Else
			AttributeName = SettingItem.Key;
		EndIf;
		
		FormAttribute = Form[AttributeName];
		
		If TypeOf(FormAttribute) = Type("FormDataCollection") Then
			
			If TypeOf(SettingItem.Value) = Type("Array")
				And SettingItem.Value.Count() > 0 Then
				
				Table = Form[AttributeName].Unload();
				
				Table.Clear();
				
				For Each TableRow In SettingItem.Value Do
					
					FillPropertyValues(Table.Add(), TableRow);
					
				EndDo;
				
				Form[AttributeName].Load(Table);
				
			EndIf;
			
		Else
			
			Form[AttributeName] = SettingItem.Value;
			
		EndIf;
		
	EndDo;
	
	// Filling correspondent data
	MappedAttributes = Form.CorrespondentInfobaseAttributeNames;
	CorrespondentInfobaseNodeFilterSetup = Form.Context.CorrespondentInfobaseNodeFilterSetup;
	
	For Each SettingItem In CorrespondentInfobaseNodeFilterSetup Do
		
		If MappedAttributes.Property(SettingItem.Key) Then
			AttributeName = MappedAttributes[SettingItem.Key];
		Else
			AttributeName = SettingItem.Key;
		EndIf;
		
		FormAttribute = Form[AttributeName];
		
		If TypeOf(FormAttribute) = Type("FormDataCollection") Then
			
			If TypeOf(SettingItem.Value) = Type("Array")
				And SettingItem.Value.Count() > 0 Then
				
				Table = Form[AttributeName].Unload();
				
				Table.Clear();
				
				For Each TableRow In SettingItem.Value Do
					
					FillPropertyValues(Table.Add(), TableRow);
					
				EndDo;
				
				Form[AttributeName].Load(Table);
				
			EndIf;
			
		Else
			
			Form[AttributeName] = SettingItem.Value;
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Checks whether the specified attributes are on the form.
// If at least one attribute is absent, the exception is raised.
//
Procedure CheckMandatoryFormAttributes(Form, Val Attributes)
	
	AbsentAttributes = New Array;
	
	FormAttributes = FormAttributeNames(Form);
	
	For Each Attribute In StringFunctionsClientServer.SplitStringIntoSubstringArray(Attributes) Do
		
		Attribute = TrimAll(Attribute);
		
		If FormAttributes.Find(Attribute) = Undefined Then
			
			AbsentAttributes.Add(Attribute);
			
		EndIf;
		
	EndDo;
	
	If AbsentAttributes.Count() > 0 Then
		
		Raise StringFunctionsClientServer.SubstituteParametersInString(NStr("en = 'Mandatory attributes of the node setup form are absent: %1'"),
			StringFunctionsClientServer.StringFromSubstringArray(AbsentAttributes)
		);
	EndIf;
	
EndProcedure

// For internal use.
// 
Procedure SetMandatoryFormAttributes(Form, MandatoryFormAttributes)
	
	AbsentAttributes = New Array;
	
	FormAttributes = FormAttributeNames(Form);
	
	For Each Attribute In MandatoryFormAttributes Do
		
		If FormAttributes.Find(Attribute.Name) = Undefined Then
			
			AbsentAttributes.Add(New FormAttribute(Attribute.Name, Attribute.AttributeType));
			Attribute.AttributeAdded = True;
			
		EndIf;
		
	EndDo;
	
	If AbsentAttributes.Count() = 0 Then
		Return;
	EndIf;
	
	Form.ChangeAttributes(AbsentAttributes);
	
	// Initializing values
	FilterParameters = New Structure();
	FilterParameters.Insert("FillRequired", True);
	FilterParameters.Insert("AttributeAdded", True);
	AttributesToFill = MandatoryFormAttributes.FindRows(FilterParameters);
	
	For Each Attribute In AttributesToFill Do
		
		Form[Attribute.Name] = Attribute.FillingValue;
		
	EndDo;
	
EndProcedure

// For internal use.
// 
Function NodeSettingsFormMandatoryAttributes()
	
	MandatoryFormAttributes = New ValueTable;
	
	MandatoryFormAttributes.Columns.Add("Name");
	MandatoryFormAttributes.Columns.Add("AttributeType");
	MandatoryFormAttributes.Columns.Add("FillRequired");
	MandatoryFormAttributes.Columns.Add("FillingValue");
	MandatoryFormAttributes.Columns.Add("AttributeAdded");
	
	NewRow = MandatoryFormAttributes.Add();
	NewRow.Name = "Context";
	NewRow.AttributeType = New TypeDescription();
	NewRow.FillRequired = False;
	
	NewRow = MandatoryFormAttributes.Add();
	NewRow.Name = "ContextDetails";
	NewRow.AttributeType = New TypeDescription("String");
	NewRow.FillRequired = False;
	
	NewRow = MandatoryFormAttributes.Add();
	NewRow.Name = "Attributes";
	NewRow.AttributeType = New TypeDescription("String");
	NewRow.FillRequired = False;
	
	NewRow = MandatoryFormAttributes.Add();
	NewRow.Name = "CorrespondentVersion";
	NewRow.AttributeType = New TypeDescription("String");
	NewRow.FillRequired = False;
	
	NewRow = MandatoryFormAttributes.Add();
	NewRow.Name = "AttributeNames";
	NewRow.AttributeType = New TypeDescription();
	NewRow.FillRequired = True;
	NewRow.FillingValue = New Structure;
	
	NewRow = MandatoryFormAttributes.Add();
	NewRow.Name = "CorrespondentInfobaseAttributeNames";
	NewRow.AttributeType = New TypeDescription();
	NewRow.FillRequired = True;
	NewRow.FillingValue = New Structure;
	
	MandatoryFormAttributes.FillValues(False, "AttributeAdded");
	
	Return MandatoryFormAttributes;
	
EndFunction

// For internal use.
// 
Procedure ChangeTabularSectionStoringStructure(DefaultSettings)
	
	For Each Settings In DefaultSettings Do
		
		If TypeOf(Settings.Value) = Type("Structure") Then
			
			DefaultSettings.Insert(Settings.Key, New Array);
			
		EndIf;
		
	EndDo;
	
EndProcedure

// For internal use.
// 
Procedure ExternalConnectionRefreshExchangeSettingsData(Val ExchangePlanName, Val NodeCode, Val NodeDefaultValues) Export
	
	SetPrivilegedMode(True);
	
	InfobaseNode = ExchangePlans[ExchangePlanName].FindByCode(NodeCode);
	
	If Not ValueIsFilled(InfobaseNode) Then
		Message = NStr("en = 'The exchange plan node with the %2 code is not found in the %1 exchange plan.'");
		Message = StringFunctionsClientServer.SubstituteParametersInString(Message, ExchangePlanName, NodeCode);
		Raise Message;
	EndIf;
	
	DataExchangeCreationWizard = DataProcessors.DataExchangeCreationWizard.Create();
	DataExchangeCreationWizard.InfobaseNode = InfobaseNode;
	DataExchangeCreationWizard.ExternalConnectionRefreshExchangeSettingsData(GetFilterSettingsValues(NodeDefaultValues));
	
EndProcedure

// For internal use.
// 
Function GetFilterSettingsValues(ExternalConnectionSettingsStructure) Export
	
	Result = New Structure;
	
	// object types
	For Each FilterSettings In ExternalConnectionSettingsStructure Do
		
		If TypeOf(FilterSettings.Value) = Type("Structure") Then
			
			ResultNested = New Structure;
			
			For Each Item In FilterSettings.Value Do
				
				If Find(Item.Key, "_Key") > 0 Then
					
					Key = StrReplace(Item.Key, "_Key", "");
					
					Array = New Array;
					
					For Each ArrayElement In Item.Value Do
						
						If Not IsBlankString(ArrayElement) Then
							
							Value = ValueFromStringInternal(ArrayElement);
							
							Array.Add(Value);
							
						EndIf;
						
					EndDo;
					
					ResultNested.Insert(Key, Array);
					
				EndIf;
				
			EndDo;
			
			Result.Insert(FilterSettings.Key, ResultNested);
			
		Else
			
			If Find(FilterSettings.Key, "_Key") > 0 Then
				
				Key = StrReplace(FilterSettings.Key, "_Key", "");
				
				Try
					If IsBlankString(FilterSettings.Value) Then
						Value = Undefined;
					Else
						Value = ValueFromStringInternal(FilterSettings.Value);
					EndIf;
				Except
					Value = Undefined;
				EndTry;
				
				Result.Insert(Key, Value);
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	// Primitive types
	For Each FilterSettings In ExternalConnectionSettingsStructure Do
		
		If TypeOf(FilterSettings.Value) = Type("Structure") Then
			
			ResultNested = Result[FilterSettings.Key];
			
			If ResultNested = Undefined Then
				
				ResultNested = New Structure;
				
			EndIf;
			
			For Each Item In FilterSettings.Value Do
				
				If Find(Item.Key, "_Key") <> 0 Then
					
					Continue;
					
				ElsIf FilterSettings.Value.Property(Item.Key + "_Key") Then
					
					Continue;
					
				EndIf;
				
				Array = New Array;
				
				For Each ArrayElement In Item.Value Do
					
					Array.Add(ArrayElement);
					
				EndDo;
				
				ResultNested.Insert(Item.Key, Array);
				
			EndDo;
			
		Else
			
			If Find(FilterSettings.Key, "_Key") <> 0 Then
				
				Continue;
				
			ElsIf ExternalConnectionSettingsStructure.Property(FilterSettings.Key + "_Key") Then
				
				Continue;
				
			EndIf;
			
			// Shielding the enumeration
			If TypeOf(FilterSettings.Value) = Type("String")
				And (     Find(FilterSettings.Value, "Enum.") <> 0
					Or Find(FilterSettings.Value, "Enumeration.") <> 0
				) Then
				
				Result.Insert(FilterSettings.Key, PredefinedValue(FilterSettings.Value));
				
			Else
				
				Result.Insert(FilterSettings.Key, FilterSettings.Value);
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Return Result;
EndFunction

// For internal use.
// 
Function DataForThisInfobaseNodeTabularSections(Val ExchangePlanName, CorrespondentVersion = "") Export
	
	Result = New Structure;
	
	NodeCommonTables = DataExchangeCached.ExchangePlanTabularSections(ExchangePlanName, CorrespondentVersion)["AllInfobaseTables"];
	
	For Each TabularSectionName In NodeCommonTables Do
		
		TabularSectionData = New ValueTable;
		TabularSectionData.Columns.Add("Presentation", New TypeDescription("String"));
		TabularSectionData.Columns.Add("RefUUID",      New TypeDescription("String"));
		
		QueryText =
		"SELECT TOP 1000
		|	Table.Ref AS Ref,
		|	Table.Presentation AS Presentation
		|FROM
		|	[TableName] AS Table
		|
		|WHERE
		|	Not Table.DeletionMark
		|
		|ORDER BY
		|	Table.Presentation";
		
		TableName = TableNameFromExchangePlanTabularSectionFirstAttribute(ExchangePlanName, TabularSectionName);
		
		QueryText = StrReplace(QueryText, "[TableName]", TableName);
		
		Query = New Query;
		Query.Text = QueryText;
		
		Selection = Query.Execute().Select();
		
		While Selection.Next() Do
			
			TableRow = TabularSectionData.Add();
			TableRow.Presentation = Selection.Presentation;
			TableRow.RefUUID = String(Selection.Ref.UUID());
			
		EndDo;
		
		Result.Insert(TabularSectionName, TabularSectionData);
		
	EndDo;
	
	Return Result;
EndFunction

// For internal use.
// 
Function CorrespondentNodeCommonData(Val ExchangePlanName, Val ConnectionParameters, Cancel)
	
	If ConnectionParameters.JoinType = "ExternalConnection" Then
		
		Connection = DataExchangeCached.EstablishExternalConnectionWithInfobase(ConnectionParameters);
		ErrorMessageString = Connection.DetailedErrorDetails;
		ExternalConnection = Connection.Connection;
		
		If ExternalConnection = Undefined Then
			CommonUseClientServer.MessageToUser(ErrorMessageString,,,, Cancel);
			Return Undefined;
		EndIf;
		
		If ConnectionParameters.CorrespondentVersion_2_1_1_7
			Or ConnectionParameters.CorrespondentVersion_2_0_1_6 Then
			
			Return CommonUse.ValueFromXMLString(ExternalConnection.DataExchangeExternalConnection.GetCommonNodeData_2_0_1_6(ExchangePlanName));
			
		Else
			
			Return ValueFromStringInternal(ExternalConnection.DataExchangeExternalConnection.GetCommonNodeData(ExchangePlanName));
			
		EndIf;
		
	ElsIf ConnectionParameters.JoinType = "WebService" Then
		
		ErrorMessageString = "";
		
		If ConnectionParameters.CorrespondentVersion_2_1_1_7 Then
			
			WSProxy = GetWSProxy_2_1_1_7(ConnectionParameters, ErrorMessageString);
			
		ElsIf ConnectionParameters.CorrespondentVersion_2_0_1_6 Then
			
			WSProxy = GetWSProxy_2_0_1_6(ConnectionParameters, ErrorMessageString);
			
		Else
			
			WSProxy = GetWSProxy(ConnectionParameters, ErrorMessageString);
			
		EndIf;
		
		If WSProxy = Undefined Then
			CommonUseClientServer.MessageToUser(ErrorMessageString,,,, Cancel);
			Return Undefined;
		EndIf;
		
		If ConnectionParameters.CorrespondentVersion_2_1_1_7
			Or ConnectionParameters.CorrespondentVersion_2_0_1_6 Then
			
			Return XDTOSerializer.ReadXDTO(WSProxy.GetCommonNodeData(ExchangePlanName));
		Else
			
			Return ValueFromStringInternal(WSProxy.GetCommonNodeData(ExchangePlanName));
		EndIf;
		
	ElsIf ConnectionParameters.JoinType = "TempStorage" Then
		
		Return GetFromTempStorage(ConnectionParameters.TempStorageAddress).Get();
		
	EndIf;
	
	Return Undefined;
EndFunction

// For internal use.
// 
Function TableNameFromExchangePlanTabularSectionFirstAttribute(Val ExchangePlanName, Val TabularSectionName)
	
	TabularSection = Metadata.ExchangePlans[ExchangePlanName].TabularSections[TabularSectionName];
	
	For Each Attribute In TabularSection.Attributes Do
		
		Type = Attribute.Type.Types()[0];
		
		If CommonUse.IsReference(Type) Then
			
			Return Metadata.FindByType(Type).FullName();
			
		EndIf;
		
	EndDo;
	
	Return "";
EndFunction

// For internal use.
// 
Function ExchangePlanCatalogs(Val ExchangePlanName)
	
	If TypeOf(ExchangePlanName) <> Type("String") Then
		
		ExchangePlanName = DataExchangeCached.GetExchangePlanName(ExchangePlanName);
		
	EndIf;
	
	Result = New Array;
	
	ExchangePlanContent = Metadata.ExchangePlans[ExchangePlanName].Content;
	
	For Each Item In ExchangePlanContent Do
		
		If CommonUse.IsCatalog(Item.Metadata)
			Or CommonUse.IsChartOfCharacteristicTypes(Item.Metadata) Then
			
			Result.Add(Item.Metadata);
			
		EndIf;
		
	EndDo;
	
	Return Result;
EndFunction

// For internal use.
// 
Function AllExchangePlanDataExceptCatalogs(Val ExchangePlanName)
	
	If TypeOf(ExchangePlanName) <> Type("String") Then
		
		ExchangePlanName = DataExchangeCached.GetExchangePlanName(ExchangePlanName);
		
	EndIf;
	
	Result = New Array;
	
	ExchangePlanContent = Metadata.ExchangePlans[ExchangePlanName].Content;
	
	For Each Item In ExchangePlanContent Do
		
		If Not (CommonUse.IsCatalog(Item.Metadata)
			Or CommonUse.IsChartOfCharacteristicTypes(Item.Metadata)) Then
			
			Result.Add(Item.Metadata);
			
		EndIf;
		
	EndDo;
	
	Return Result;
EndFunction

// For internal use.
// 
Function SystemAccountingSettingsAreSet(Val ExchangePlanName, Val Correspondent, ErrorMessage) Export
	
	If TypeOf(Correspondent) = Type("String") Then
		
		If IsBlankString(Correspondent) Then
			Return False;
		EndIf;
		
		CorrespondentCode = Correspondent;
		
		Correspondent = ExchangePlans[ExchangePlanName].FindByCode(Correspondent);
		
		If Not ValueIsFilled(Correspondent) Then
			Message = NStr("en = 'The exchange plan node with the %2 code has not been found in the %1 exchange plan.'");
			Message = StringFunctionsClientServer.SubstituteParametersInString(Message, ExchangePlanName, CorrespondentCode);
			Raise Message;
		EndIf;
		
	EndIf;
	
	Cancel = False;
	
	SetPrivilegedMode(True);
	ExchangePlans[ExchangePlanName].AccountingSettingsCheckHandler(Cancel, Correspondent, ErrorMessage);
	
	Return Not Cancel;
EndFunction

// For internal use.
// 
Function GetInfobaseParameters(Val ExchangePlanName, Val NodeCode, ErrorMessage) Export
	
	Return ValueToStringInternal(InfobaseParameters(ExchangePlanName, NodeCode, ErrorMessage));
	
EndFunction

// For internal use.
// 
Function GetInfobaseParameters_2_0_1_6(Val ExchangePlanName, Val NodeCode, ErrorMessage) Export
	
	Return CommonUse.ValueToXMLString(InfobaseParameters(ExchangePlanName, NodeCode, ErrorMessage));
	
EndFunction

// For internal use.
// 
Function MetadataObjectProperties(Val FullTableName) Export
	
	Result = New Structure("Synonym, Hierarchical");
	
	MetadataObject = Metadata.FindByFullName(FullTableName);
	
	FillPropertyValues(Result, MetadataObject);
	
	Return Result;
EndFunction

// For internal use.
// 
Function GetTableObjects(Val FullTableName) Export
	SetPrivilegedMode(True);
	
	MetadataObject = Metadata.FindByFullName(FullTableName);
	
	If CommonUse.IsCatalog(MetadataObject) Then
		
		If MetadataObject.Hierarchical Then
			If MetadataObject.HierarchyType = Metadata.ObjectProperties.HierarchyType.HierarchyFoldersAndItems Then
				Return HierarchicalCatalogItemsHierarchyFoldersAndItems(FullTableName);
			EndIf;
			
			Return HierarchicalCatalogItemsHierarchyItems(FullTableName);
		EndIf;
		
		Return NonhierarchicalCatalogItems(FullTableName);
		
	ElsIf CommonUse.IsChartOfCharacteristicTypes(MetadataObject) Then
		
		If MetadataObject.Hierarchical Then
			Return HierarchicalCatalogItemsHierarchyFoldersAndItems(FullTableName);
		EndIf;
		
		Return NonhierarchicalCatalogItems(FullTableName);
		
	EndIf;
	
	Return Undefined;
EndFunction

// For internal use only.
//
Function HierarchicalCatalogItemsHierarchyFoldersAndItems(Val FullTableName)
	
	Query = New Query("
		|SELECT TOP 2000
		|	Ref,
		|	Presentation,
		|	CASE
		|		WHEN    IsFolder AND Not  DeletionMark THEN 0
		|		WHEN    IsFolder AND      DeletionMark THEN 1
		|		WHEN Not IsFolder AND Not DeletionMark THEN 2
		|		WHEN Not IsFolder AND     DeletionMark THEN 3
		|	END AS PictureIndex
		|FROM
		|	" + FullTableName + "
		|ORDER
		|	By IsFolder
		|	HIERARCHY, Description
		|");
		
	Return QueryResultToXMLTree(Query);
EndFunction

// For internal use only.
//
Function HierarchicalCatalogItemsHierarchyItems(Val FullTableName)
	
	Query = New Query("
		|SELECT TOP 2000
		|	Ref,
		|	Presentation,
		|	CASE
		|		WHEN DeletionMark THEN 3
		|		ELSE 2
		|	END AS PictureIndex
		|FROM
		|	" + FullTableName + "
		|ORDER
		|	BY Description HIERARCHY
		|");
		
	Return QueryResultToXMLTree(Query);
EndFunction

// For internal use only.
//
Function NonhierarchicalCatalogItems(Val FullTableName)
	
	Query = New Query("
		|SELECT TOP 2000
		|	Ref,
		|	Presentation,
		|	CASE
		|		WHEN DeletionMark THEN 3
		|		ELSE 2
		|	END AS PictureIndex
		|FROM
		|	" + FullTableName + " 
		|ORDER
		|	BY Description
		|");
		
	Return QueryResultToXMLTree(Query);
EndFunction

// For internal use only.
//
Function QueryResultToXMLTree(Val Request)
	Result = Request.Execute().Unload(QueryResultIteration.ByGroupsWithHierarchy);
	
	Result.Columns.Add("ID", New TypeDescription("String"));
	FillRefIDInTree(Result.Rows);
	Result.Columns.Delete("Ref");
	
	Return CommonUse.ValueToXMLString(Result);
EndFunction

// For internal use only.
//
Procedure FillRefIDInTree(TreeRows)
	
	For Each Row In TreeRows Do
		Row.ID = ValueToStringInternal(Row.Ref);
		FillRefIDInTree(Row.Rows);
	EndDo;
	
EndProcedure

// For internal use.
// 
Function CorrespondentData(Val FullTableName) Export
	
	Result = New Structure("MetadataObjectProperties, CorrespondentInfobaseTable");
	
	Result.MetadataObjectProperties = MetadataObjectProperties(FullTableName);
	Result.CorrespondentInfobaseTable = GetTableObjects(FullTableName);
	
	Return Result;
EndFunction

// For internal use.
// 
Function CorrespondentTableData(Tables, Val ExchangePlanName) Export
	
	Result = New Map;
	ExchangePlanAttributes = Metadata.ExchangePlans[ExchangePlanName].Attributes;
	
	For Each Item In Tables Do
		
		Attribute = ExchangePlanAttributes.Find(Item);
		
		If Attribute <> Undefined Then
			
			AttributeTypes = Attribute.Type.Types();
			
			If AttributeTypes.Count() <> 1 Then
				
				MessageString = NStr("en = 'Default values cannot have composite data type.
					|The %1 attribute.'");
				MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, Attribute.FullName());
				Raise MessageString;
			EndIf;
			
			MetadataObject = Metadata.FindByType(AttributeTypes.Get(0));
			
			If Not CommonUse.IsCatalog(MetadataObject) Then
				
				MessageString = NStr("en = 'Default value selection is supported for catalogs only.
					|The %1 attribute.'");
				MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, Attribute.FullName());
				Raise MessageString;
			EndIf;
			
			MetadataObjectFullName = MetadataObject.FullName();
			
			TableData = New Structure("MetadataObjectProperties, CorrespondentInfobaseTable");
			TableData.MetadataObjectProperties = MetadataObjectProperties(MetadataObjectFullName);
			TableData.CorrespondentInfobaseTable = GetTableObjects(MetadataObjectFullName);
			
			Result.Insert(MetadataObjectFullName, TableData);
			
		EndIf;
		
	EndDo;
	
	AdditionalData = New Structure;
	
	// {Handler: GetAdditionalDataForCorrespondent} Begin
	ExchangePlans[ExchangePlanName].GetAdditionalDataForCorrespondent(AdditionalData);
	// {Handler: GetAdditionalDataForCorrespondent} End
	
	Result.Insert("{AdditionalData}", AdditionalData);
	
	Return Result;
	
EndFunction

// For internal use.
// 
Function InfobaseParameters(Val ExchangePlanName, Val NodeCode, ErrorMessage) Export
	
	SetPrivilegedMode(True);
	
	Result = New Structure;
	
	Result.Insert("ExchangePlanExists");
	Result.Insert("InfobasePrefix");
	Result.Insert("DefaultInfobasePrefix");
	Result.Insert("InfobaseDescription");
	Result.Insert("DefaultInfobaseDescription");
	Result.Insert("SystemAccountingSettingsAreSet");
	Result.Insert("ThisNodeCode");
	Result.Insert("ConfigurationVersion"); // Since SL version 2.1.5.1
	
	Result.ExchangePlanExists = (Metadata.ExchangePlans.Find(ExchangePlanName) <> Undefined);
	
	If Result.ExchangePlanExists Then
		
		ThisNodeProperties = CommonUse.ObjectAttributeValues(ExchangePlans[ExchangePlanName].ThisNode(), "Code, Description");
		
		InfobasePrefix = Undefined;
		//InfobasePrefix = DataExchangeOverridable.DefaultInfobasePrefix();
		DataExchangeOverridable.OnDefineDefaultInfobasePrefix(InfobasePrefix);
		
		Result.InfobasePrefix                 = GetFunctionalOption("InfobasePrefix");
		Result.DefaultInfobasePrefix          = InfobasePrefix;
		Result.InfobaseDescription            = ThisNodeProperties.Description;
		Result.DefaultInfobaseDescription     = ThisNodeDefaultDescription();
		Result.SystemAccountingSettingsAreSet = SystemAccountingSettingsAreSet(ExchangePlanName, NodeCode, ErrorMessage);
		Result.ThisNodeCode                   = ThisNodeProperties.Code;
		Result.ConfigurationVersion           = Metadata.Version;
	Else
		
		Result.InfobasePrefix = "";
		Result.DefaultInfobasePrefix = "";
		Result.InfobaseDescription = "";
		Result.DefaultInfobaseDescription = "";
		Result.SystemAccountingSettingsAreSet = False;
		Result.ThisNodeCode = "";
		Result.ConfigurationVersion = Metadata.Version;
	EndIf;
	
	Return Result;
EndFunction

// For internal use.
// 
Function GetStatisticsTree(Statistics, Val EnableObjectDeletion = False) Export
	
	FilterArray = Statistics.UnloadColumn("TargetTableName");
	
	FilterRow = StringFunctionsClientServer.StringFromSubstringArray(FilterArray);
	
	Filter = New Structure("FullName", FilterRow);
	
	// Getting configuration metadata object tree
	StatisticsTree = DataExchangeCached.GetConfigurationMetadataTree(Filter).Copy();
	
	// Adding columns
	StatisticsTree.Columns.Add("Key");
	StatisticsTree.Columns.Add("ObjectCountInSource");
	StatisticsTree.Columns.Add("ObjectCountInTarget");
	StatisticsTree.Columns.Add("UnmappedObjectCount");
	StatisticsTree.Columns.Add("MappedObjectPercent");
	StatisticsTree.Columns.Add("PictureIndex");
	StatisticsTree.Columns.Add("UsePreview");
	StatisticsTree.Columns.Add("TargetTableName");
	StatisticsTree.Columns.Add("ObjectTypeString");
	StatisticsTree.Columns.Add("TableFields");
	StatisticsTree.Columns.Add("SearchFields");
	StatisticsTree.Columns.Add("SourceTypeString");
	StatisticsTree.Columns.Add("TargetTypeString");
	StatisticsTree.Columns.Add("IsObjectDeletion");
	StatisticsTree.Columns.Add("DataImportedSuccessfully");
	
	
	// Indexes for searching in the statistics
	Indexes = Statistics.Indexes;
	If Indexes.Count() = 0 Then
		If EnableObjectDeletion Then
			Indexes.Add("IsObjectDeletion");
			Indexes.Add("OneToMany, IsObjectDeletion");
			Indexes.Add("IsClassifier, IsObjectDeletion");
		Else
			Indexes.Add("OneToMany");
			Indexes.Add("IsClassifier");
		EndIf;
	EndIf;
	
	ProcessedRows = New Map;
	
	// Normal strings
	Filter = New Structure("OneToMany", False);
	If Not EnableObjectDeletion Then
		Filter.Insert("IsObjectDeletion", False);
	EndIf;
		
	For Each TableRow In Statistics.FindRows(Filter) Do
		TreeRow = StatisticsTree.Rows.Find(TableRow.TargetTableName, "FullName", True);
		FillPropertyValues(TreeRow, TableRow);
		
		ProcessedRows[TableRow] = True;
	EndDo;
	
	// Adding rows of OneToMany type
	Filter = New Structure("OneToMany", True);
	If Not EnableObjectDeletion Then
		Filter.Insert("IsObjectDeletion", False);
	EndIf;
	FillStatisticsTreeOneToMany(StatisticsTree, Statistics, Filter, ProcessedRows);
	
	// Adding classifier rows
	Filter = New Structure("IsClassifier", True);
	If Not EnableObjectDeletion Then
		Filter.Insert("IsObjectDeletion", False);
	EndIf;
	FillStatisticsTreeOneToMany(StatisticsTree, Statistics, Filter, ProcessedRows);
	
	// Adding rows for object deletion
	If EnableObjectDeletion Then
		Filter = New Structure("IsObjectDeletion", True);
		FillStatisticsTreeOneToMany(StatisticsTree, Statistics, Filter, ProcessedRows);
	EndIf;
	
	// Clearing empty rows
	StatisticsRows = StatisticsTree.Rows;
	GroupPosition = StatisticsRows.Count() - 1;
	While GroupPosition >=0 Do
		Group = StatisticsRows[GroupPosition];
		
		Items = Group.Rows;
		Position = Items.Count() - 1;
		While Position >=0 Do
			Item = Items[Position];
			
			If Item.ObjectCountInTarget = Undefined 
				And Item.ObjectCountInSource = Undefined
				And Item.Rows.Count() = 0
			Then
				Items.Delete(Item);
			EndIf;
			
			Position = Position - 1;
		EndDo;
		
		If Items.Count() = 0 Then
			StatisticsRows.Delete(Group);
		EndIf;
		GroupPosition = GroupPosition - 1;
	EndDo;
	
	Return StatisticsTree;
EndFunction

// For internal use.
// 
Procedure FillStatisticsTreeOneToMany(StatisticsTree, Statistics, Filter, AlreadyProcessedRows)
	
	RowsToProcess = Statistics.FindRows(Filter);
	
	// Ignoring processed source rows
	Position = RowsToProcess.UBound();
	While Position >= 0 Do
		Candidate = RowsToProcess[Position];
		
		If AlreadyProcessedRows[Candidate] <> Undefined Then
			RowsToProcess.Delete(Position);
		Else
			AlreadyProcessedRows[Candidate] = True;
		EndIf;
		
		Position = Position - 1;
	EndDo;
		
	If RowsToProcess.Count() = 0 Then
		Return;
	EndIf;
	
	StatisticsOneToMany = Statistics.Copy(RowsToProcess);
	StatisticsOneToMany.Indexes.Add("TargetTableName");
	
	StatisticsOneToManyTemporary = StatisticsOneToMany.Copy(RowsToProcess, "TargetTableName");
	
	StatisticsOneToManyTemporary.Collapse("TargetTableName");
	
	For Each TableRow In StatisticsOneToManyTemporary Do
		Rows    = StatisticsOneToMany.FindRows(New Structure("TargetTableName", TableRow.TargetTableName));
		TreeRow = StatisticsTree.Rows.Find(TableRow.TargetTableName, "FullName", True);
		
		For Each Row In Rows Do
			NewTreeRow = TreeRow.Rows.Add();
			FillPropertyValues(NewTreeRow, TreeRow);
			FillPropertyValues(NewTreeRow, Row);
			
			If Row.IsObjectDeletion Then
				NewTreeRow.Picture = PictureLib.MarkToDelete;
			Else
				Synonym = "[TargetTableSynonym] ([SourceTableName])";
				Synonym = StrReplace(Synonym, "[TargetTableSynonym]", NewTreeRow.Synonym);
				Synonym = StrReplace(Synonym, "[SourceTableName]", DeleteClassNameFromObjectName(Row.SourceTypeString));
				
				NewTreeRow.Synonym = Synonym;
			EndIf;
		EndDo;
	EndDo;
	
EndProcedure

// For internal use.
// 
Function DeleteClassNameFromObjectName(Val Result)
	
	Result = StrReplace(Result, "DocumentRef.", "");
	Result = StrReplace(Result, "CatalogRef.", "");
	Result = StrReplace(Result, "ChartOfCharacteristicTypesRef.", "");
	Result = StrReplace(Result, "ChartOfAccountsRef.", "");
	Result = StrReplace(Result, "ChartOfCalculationTypesRef.", "");
	Result = StrReplace(Result, "BusinessProcessRef.", "");
	Result = StrReplace(Result, "TaskRef.", "");
	
	Return Result;
EndFunction

// Adds parameters of client logic execution for the data exchange subsystem.
//
Procedure AddClientParameters(Parameters) Export
	
	SetPrivilegedMode(True);
	
	Parameters.Insert("MasterNode", MasterNode());
	
EndProcedure

// For internal use.
// 
Procedure CheckLoadedFromFileExchangeRulesAvailability(LoadedFromFileExchangeRules, LoadedFromFileRecordRules)
	
	QueryText = "SELECT DISTINCT
	|	DataExchangeRules.ExchangePlanName AS ExchangePlanName,
	|	DataExchangeRules.RuleKind AS RuleKind
	|FROM
	|	InformationRegister.DataExchangeRules AS DataExchangeRules
	|WHERE
	|	DataExchangeRules.RuleSource = VALUE(Enum.DataExchangeRuleSources.File)
	|	AND DataExchangeRules.RulesLoaded";
	
	Query = New Query;
	Query.Text = QueryText;
	
	Result = Query.Execute();
	
	If Not Result.IsEmpty() Then
		
		ExchangePlansArray = New Array;
		
		Selection = Result.Select();
		
		While Selection.Next() Do
			
			If Selection.RuleKind = Enums.DataExchangeRuleKinds.ObjectConversionRules Then
				
				LoadedFromFileExchangeRules.Add(Selection.ExchangePlanName);
				
			ElsIf Selection.RuleKind = Enums.DataExchangeRuleKinds.ObjectChangeRecordRules Then
				
				LoadedFromFileRecordRules.Add(Selection.ExchangePlanName);
				
			EndIf;
			
			If ExchangePlansArray.Find(Selection.ExchangePlanName) = Undefined Then
				
				ExchangePlansArray.Add(Selection.ExchangePlanName);
				
			EndIf;
			
		EndDo;
		
		MessageString = NStr("en = 'Exchange rules loaded from a file are used for the %1 exchange plan(s).
				|These rules can be incompatible with the new program version.
				|It is recommended that you update exchange rules from the file to prevent possible errors.'",
				CommonUseClientServer.DefaultLanguageCode());
		MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, StringFunctionsClientServer.StringFromSubstringArray(ExchangePlansArray));
		
		WriteLogEvent(InfobaseUpdate.EventLogMessageText(), EventLogLevel.Error,,, MessageString);
		
	EndIf;
	
EndProcedure

// Verifies the transport processor connection by the specified settings.
//
Procedure TestExchangeMessageTransportDataProcessorConnection(Cancel, SettingsStructure, TransportKind, ErrorMessage = "") Export
	
	SetPrivilegedMode(True);
	
	// Creating data processor instance
	DataProcessorObject = DataProcessors[DataExchangeMessageTransportDataProcessorName(TransportKind)].Create();
	
	// Initializing data processor properties with the passed settings parameters
	FillPropertyValues(DataProcessorObject, SettingsStructure);
	
	// Initializing the exchange transport
	DataProcessorObject.Initialization();
	
	// Checking the connection
	If Not DataProcessorObject.ConnectionIsSet() Then
		
		MessagePattern = "%1 
         |%2";
		
		AdditionalMessage = NStr("en = 'See technical error details in the event log.'");
		
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, DataProcessorObject.ErrorMessageString, AdditionalMessage);
		
		CommonUseClientServer.MessageToUser(ErrorMessage,,,, Cancel);
		
		WriteLogEvent(NStr("en = 'Exchange message transport.'", CommonUseClientServer.DefaultLanguageCode()),
			EventLogLevel.Error,,, DataProcessorObject.ErrorMessageStringEL);
		
	EndIf;
	
EndProcedure

// Obsolete. You have to use the EstablishExternalConnectionWithInfobase function.
//
Function EstablishExternalConnection(SettingsStructure, ErrorMessageString = "", ErrorAttachingAddIn = False) Export

	Result = EstablishExternalConnectionWithInfobase(SettingsStructure);
	
	ErrorAttachingAddIn = Result.ErrorAttachingAddIn;
	ErrorMessageString  = Result.DetailedErrorDetails;

	Return Result.Connection;
EndFunction

// Main function that is used to perform the data exchange over the external connection. For internal use.
//
// Parameters: 
//     SettingsStructure - structure contains COM connection settings for the data exchange transport.
//
Function EstablishExternalConnectionWithInfobase(SettingsStructure) Export
	
	Result = CommonUse.EstablishExternalConnectionWithInfobase(
		FillExternalConnectionParameters(SettingsStructure));
	
	ExternalConnection = Result.Connection;
	If ExternalConnection = Undefined Then
		// Connection establish error
		Return Result;
	EndIf;
	
	// Checking whether it is possible to operate with the external infobase
	
	Try
		NoFullAccess = Not ExternalConnection.DataExchangeExternalConnection.IsInRoleFullAccess();
	Except
		NoFullAccess = True;
	EndTry;
	
	If NoFullAccess Then
		Result.DetailedErrorDetails = NStr("en = 'The ""System administrator"" and ""Full access"" roles must be assigned to the user that is used to establish connection to the other application.'");
		Result.BriefErrorDetails   = Result.DetailedErrorDetails;
		Result.Connection = Undefined;
	Else
		Try 
			InvalidState = ExternalConnection.InfobaseUpdate.InfobaseUpdateRequired();
		Except
			InvalidState = False
		EndTry;
		
		If InvalidState Then
			Result.DetailedErrorDetails = NStr("en = 'Other application is updating now.'");
			Result.BriefErrorDetails    = Result.DetailedErrorDetails;
			Result.Connection           = Undefined;
		EndIf;
		
	EndIf;
	
	Return Result;
EndFunction

Function TransportSettingsByExternalConnectionParameters(Parameters) Export
	
	// Converting external connection parameters to transport parameters
	TransportSettings = 
		TransportSetup(Parameters, "COMInfobaseOperationMode",        "InfobaseOperationMode",
		TransportSetup(Parameters, "COMInfobaseDirectory",            "InfobaseDirectory",
		TransportSetup(Parameters, "COMPlatformServerName",           "PlatformServerName",
		TransportSetup(Parameters, "COMInfobaseNameAtPlatformServer", "InfobaseNameAtPlatformServer",
		TransportSetup(Parameters, "COMOSAuthentication",             "OSAuthentication",
		TransportSetup(Parameters, "COMUserName",                     "UserName",
		TransportSetup(Parameters, "COMUserPassword",                 "UserPassword",
	)))))));
	
	Return TransportSettings;
EndFunction

// Auxiliary
Function TransportSetup(Val ConnectionParameters, Val TransportParameterName, Val ConnectionParameterName, Val InitialSettings = Undefined)
	Result = ?(InitialSettings = Undefined, New Structure, InitialSettings);
	
	ParameterValue = Undefined;
	ConnectionParameters.Property(ConnectionParameterName, ParameterValue);
	Result.Insert(TransportParameterName, ParameterValue);
	
	Return Result;
EndFunction

// For internal use.
// 
Function GetWSProxyByConnectionParameters(
					SettingsStructure,
					ErrorMessageString = "",
					UserMessage = "",
					ProbingCallRequired = False
	) Export
	
	Try
		DataExchangeClientServer.CheckProhibitedCharsInWSProxyUserName(SettingsStructure.WSUserName);
	Except
		UserMessage = BriefErrorDescription(ErrorInfo());
		ErrorMessageString = DetailErrorDescription(ErrorInfo());
		WriteLogEvent(EventLogMessageTextEstablishingConnectionToWebService(), EventLogLevel.Error,,, ErrorMessageString);
		Return Undefined;
	EndTry;
	
	WSDLLocation = "[WebServiceURL]/ws/[ServiceName]?wsdl";
	WSDLLocation = StrReplace(WSDLLocation, "[WebServiceURL]", SettingsStructure.WSURL);
	WSDLLocation = StrReplace(WSDLLocation, "[ServiceName]",    SettingsStructure.WSServiceName);
	
	Try
		WSProxy = CommonUse.WSProxy(
			WSDLLocation,
			SettingsStructure.NamespaceWebServiceURL,
			SettingsStructure.WSServiceName,
			,
			SettingsStructure.WSUserName,
			SettingsStructure.WSPassword,
			SettingsStructure.WSTimeout,
			ProbingCallRequired);
	Except
		UserMessage = BriefErrorDescription(ErrorInfo());
		ErrorMessageString = DetailErrorDescription(ErrorInfo());
		WriteLogEvent(EventLogMessageTextEstablishingConnectionToWebService(), EventLogLevel.Error,,, ErrorMessageString);
		Return Undefined;
	EndTry;
	
	Return WSProxy;
EndFunction

// For internal use.
// 
Function WSParameterStructure() Export
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("WSURL");
	ParametersStructure.Insert("WSUserName");
	ParametersStructure.Insert("WSPassword");
	
	Return ParametersStructure;
EndFunction

// For internal use.
// 
Function GetWSProxy(SettingsStructure, ErrorMessageString = "", UserMessage = "") Export
	
	DeleteInsignificantCharactersAtConnectionSettings(SettingsStructure);
	
	SettingsStructure.Insert("NamespaceWebServiceURL", "http://www.1c.ru/SSL/Exchange");
	SettingsStructure.Insert("WSServiceName",          "Exchange");
	SettingsStructure.Insert("WSTimeout",               600);
	
	Return GetWSProxyByConnectionParameters(SettingsStructure, ErrorMessageString, UserMessage);
EndFunction

// For internal use.
// 
Function GetWSProxy_2_0_1_6(SettingsStructure, ErrorMessageString = "", UserMessage = "") Export
	
	DeleteInsignificantCharactersAtConnectionSettings(SettingsStructure);
	
	SettingsStructure.Insert("NamespaceWebServiceURL", "http://www.1c.ru/SSL/Exchange_2_0_1_6");
	SettingsStructure.Insert("WSServiceName",          "Exchange_2_0_1_6");
	SettingsStructure.Insert("WSTimeout",              600);
	
	Return GetWSProxyByConnectionParameters(SettingsStructure, ErrorMessageString, UserMessage);
EndFunction

// For internal use.
// 
Function GetWSProxy_2_1_1_7(SettingsStructure, ErrorMessageString = "", UserMessage = "", Timeout = 600) Export
	
	DeleteInsignificantCharactersAtConnectionSettings(SettingsStructure);
	
	SettingsStructure.Insert("NamespaceWebServiceURL", "http://www.1c.ru/SSL/Exchange_2_0_1_6");
	SettingsStructure.Insert("WSServiceName",          "Exchange_2_0_1_6");
	SettingsStructure.Insert("WSTimeout",              Timeout);
	
	Return GetWSProxyByConnectionParameters(SettingsStructure, ErrorMessageString, UserMessage, True);
EndFunction

// For internal use.
// 
Function GetWSProxyForInfobaseNode(InfobaseNode, ErrorMessageString = "", AuthenticationParameters = Undefined)
	
	SettingsStructure = InformationRegisters.ExchangeTransportSettings.TransportSettingsWS(InfobaseNode, AuthenticationParameters);
	
	Try
		CorrespondentVersions = DataExchangeCached.CorrespondentVersions(SettingsStructure);
	Except
		ErrorMessageString = DetailErrorDescription(ErrorInfo());
		WriteLogEvent(EventLogMessageTextEstablishingConnectionToWebService(),
			EventLogLevel.Error,,, ErrorMessageString);
		Return Undefined;
	EndTry;
	
	CorrespondentVersion_2_0_1_6 = (CorrespondentVersions.Find("2.0.1.6") <> Undefined);
	CorrespondentVersion_2_1_1_7 = (CorrespondentVersions.Find("2.1.1.7") <> Undefined);
	
	If CorrespondentVersion_2_1_1_7 Then
		
		WSProxy = GetWSProxy_2_1_1_7(SettingsStructure, ErrorMessageString);
		
	ElsIf CorrespondentVersion_2_0_1_6 Then
		
		WSProxy = GetWSProxy_2_0_1_6(SettingsStructure, ErrorMessageString);
		
	Else
		
		WSProxy = GetWSProxy(SettingsStructure, ErrorMessageString);
		
	EndIf;
	
	Return WSProxy;
EndFunction

// For internal use.
// 
Procedure DeleteInsignificantCharactersAtConnectionSettings(Settings)
	
	For Each Settings In Settings Do
		
		If TypeOf(Settings.Value) = Type("String") Then
			
			Settings.Insert(Settings.Key, TrimAll(Settings.Value));
			
		EndIf;
		
	EndDo;
	
EndProcedure

// For internal use.
// 
Function TestWSProxyConnection(SettingsStructure, ErrorMessageString = "", UserMessage = "") Export
	
	CorrespondentVersions = DataExchangeCached.CorrespondentVersions(SettingsStructure);
	
	CorrespondentVersion_2_0_1_6 = (CorrespondentVersions.Find("2.0.1.6") <> Undefined);
	CorrespondentVersion_2_1_1_7 = (CorrespondentVersions.Find("2.1.1.7") <> Undefined);
	
	If CorrespondentVersion_2_1_1_7 Then
		
		WSProxy = GetWSProxy_2_1_1_7(SettingsStructure, ErrorMessageString, UserMessage);
		
	ElsIf CorrespondentVersion_2_0_1_6 Then
		
		WSProxy = GetWSProxy_2_0_1_6(SettingsStructure, ErrorMessageString, UserMessage);
		
	Else
		
		WSProxy = GetWSProxy(SettingsStructure, ErrorMessageString, UserMessage);
		
	EndIf;
	
	Return WSProxy;
EndFunction

// For internal use.
// 
Function CorrespondentConnectionEstablished(Val Correspondent, Val SettingsStructure, UserMessage = "") Export
	
	EventLogMessageText = NStr("en = 'Data exchange.Connection test'", CommonUseClientServer.DefaultLanguageCode());
	
	Try
		CorrespondentVersions = DataExchangeCached.CorrespondentVersions(SettingsStructure);
	Except
		ResetDataSynchronizationPassword(Correspondent);
		WriteLogEvent(EventLogMessageText,
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		UserMessage = FirstErrorBriefPresentation(ErrorInfo());
		Return False;
	EndTry;
	
	CorrespondentVersion_2_0_1_6 = (CorrespondentVersions.Find("2.0.1.6") <> Undefined);
	CorrespondentVersion_2_1_1_7 = (CorrespondentVersions.Find("2.1.1.7") <> Undefined);
	
	If CorrespondentVersion_2_1_1_7 Then
		
		WSProxy = GetWSProxy_2_1_1_7(SettingsStructure,, UserMessage, 5);
		
		If WSProxy = Undefined Then
			ResetDataSynchronizationPassword(Correspondent);
			Return False;
		EndIf;
		
		Try
			
			HasConnection = WSProxy.TestConnection(
				DataExchangeCached.GetExchangePlanName(Correspondent),
				CommonUse.ObjectAttributeValue(DataExchangeCached.GetThisExchangePlanNodeByRef(Correspondent), "Code"),
				UserMessage);
			
			If HasConnection Then
				SetDataSynchronizationPassword(Correspondent, SettingsStructure.WSPassword);
			EndIf;
			
			Return HasConnection;
		Except
			ResetDataSynchronizationPassword(Correspondent);
			WriteLogEvent(EventLogMessageText,
				EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
			UserMessage = FirstErrorBriefPresentation(ErrorInfo());
			Return False;
		EndTry;
		
	ElsIf CorrespondentVersion_2_0_1_6 Then
		
		WSProxy = GetWSProxy_2_0_1_6(SettingsStructure,, UserMessage);
		
	Else
		
		WSProxy = GetWSProxy(SettingsStructure,, UserMessage);
		
	EndIf;
	
	HasConnection = (WSProxy <> Undefined);
	
	If HasConnection Then
		SetDataSynchronizationPassword(Correspondent, SettingsStructure.WSPassword);
	Else
		ResetDataSynchronizationPassword(Correspondent);
	EndIf;
	
	Return HasConnection;
EndFunction

// Displays the error message and sets the Cancellation flag to True.
//
// Parameters:
//  MessageText - String - message text.
//  Cancel      - Boolean - cancellation flag (optional).
//
Procedure ReportError(MessageText, Cancel = False) Export
	
	Cancel = True;
	
	CommonUseClientServer.MessageToUser(MessageText);
	
EndProcedure

// Retrieves the table of selective object registration from session parameters.
// 
// Returns:
// Value table - registration attribute table for all metadata objects.
//
Function GetSelectiveObjectChangeRecordRulesSP() Export
	
	Return DataExchangeCached.GetSelectiveObjectChangeRecordRulesSP();
	
EndFunction

// Adds a single record to the information register by the passed structure values.
//
// Parameters:
//  RecordStructure - Structure - structure whose values are used to create and fill a
//                    record set.
//  RegisterName    - String - information register name where the record will be added.
//
 
Procedure AddRecordToInformationRegister(RecordStructure, Val RegisterName, Import = False) Export
	
	RecordSet = CreateInformationRegisterRecordSet(RecordStructure, RegisterName);
	
	// Adding the single record to the new record set
	NewRecord = RecordSet.Add();
	
	// Filling record property values from the passed structure
	FillPropertyValues(NewRecord, RecordStructure);
	
	RecordSet.DataExchange.Load = Import;
	
	// Writing the record set
	RecordSet.Write();
	
EndProcedure

// Updates the record in the information register by the passed structure values.
//
// Parameters:
//  RecordStructure - Structure - structure whose values will be used to create a record
//                    manager and update the record.
//  RegisterName    - String - information register name whose record will be updated.
//
 
Procedure UpdateInformationRegisterRecord(RecordStructure, Val RegisterName) Export
	
	RegisterMetadata = Metadata.InformationRegisters[RegisterName];
	
	// Creating a register record manager
	RecordManager = InformationRegisters[RegisterName].CreateRecordManager();
	
	// Setting filter for each register dimension
	For Each Dimension In RegisterMetadata.Dimensions Do
		
		// If dimension filter value is specified in a structure, the filter is set
		If RecordStructure.Property(Dimension.Name) Then
			
			RecordManager[Dimension.Name] = RecordStructure[Dimension.Name];
			
		EndIf;
		
	EndDo;
	
	// Reading the record from the infobase
	RecordManager.Read();
	
	// Filling record property values from the passed structure
	FillPropertyValues(RecordManager, RecordStructure);
	
	// Writing the record manager
	RecordManager.Write();
	
EndProcedure

// Deletes record set from the register by the passed structure values.
//
// Parameters:
//  RecordStructure - Structure - structure whose values will be used to delete the
//                    record set.
//  RegisterName    - String - name of the information register where the record set
//                    will be deleted from.
//
 
Procedure DeleteRecordSetFromInformationRegister(RecordStructure, RegisterName, Import = False) Export
	
	RecordSet = CreateInformationRegisterRecordSet(RecordStructure, RegisterName);
	
	RecordSet.DataExchange.Load = Import;
	
	// Writing the record set
	RecordSet.Write();
	
EndProcedure

// Imports data exchange rules (ORR or OCR) into the infobase.
// 
Procedure ImportDataExchangeRules(Cancel,
										Val ExchangePlanName,
										Val RuleKind,
										Val RuleTemplateName,
										Val CorrespondentRuleTemplateName = "")
	
	RecordStructure = New Structure;
	RecordStructure.Insert("ExchangePlanName", ExchangePlanName);
	RecordStructure.Insert("RuleKind",         RuleKind);
	If Not IsBlankString(CorrespondentRuleTemplateName) Then
		RecordStructure.Insert("CorrespondentRuleTemplateName", CorrespondentRuleTemplateName);
	EndIf;
	RecordStructure.Insert("RuleTemplateName", RuleTemplateName);
	RecordStructure.Insert("RuleSource",       Enums.DataExchangeRuleSources.ConfigurationTemplate);
	RecordStructure.Insert("UseSelectiveObjectChangeRecordFilter", True);
	
	// Creating a register record set
	RecordSet = CreateInformationRegisterRecordSet(RecordStructure, "DataExchangeRules");
	
	// Adding the single record to the new record set
	NewRecord = RecordSet.Add();
	
	// Filling record properties with values from the structure
	FillPropertyValues(NewRecord, RecordStructure);
	
	// Importing data exchange rules into the infobase
	InformationRegisters.DataExchangeRules.ImportRules(Cancel, RecordSet[0]);
	
	If Not Cancel Then
		RecordSet.Write();
	EndIf;
	
EndProcedure

// For internal use.
// 
Procedure UpdateStandardDataExchangeRuleVersion(Cancel, LoadedFromFileExchangeRules, LoadedFromFileRecordRules)
	
	For Each ExchangePlanName In DataExchangeCached.SLExchangePlans() Do
		
		If CommonUseCached.DataSeparationEnabled()
			And Not DataExchangeCached.ExchangePlanUsedInSaaS(ExchangePlanName) Then
			Continue;
		EndIf;
		
		If LoadedFromFileExchangeRules.Find(ExchangePlanName) = Undefined
			And DataExchangeCached.HasExchangePlanTemplate(ExchangePlanName, "ExchangeRules")
			And DataExchangeCached.HasExchangePlanTemplate(ExchangePlanName, "CorrespondentExchangeRules") Then
			
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Updating data conversion rules for the %1 exchange plan.'"), ExchangePlanName);
			WriteLogEvent(EventLogMessageTextDataExchange(),
				EventLogLevel.Information,,, MessageText);
			
			ImportDataExchangeRules(Cancel, ExchangePlanName, Enums.DataExchangeRuleKinds.ObjectConversionRules,
				"ExchangeRules", "CorrespondentExchangeRules");
			
		EndIf;
		
		If LoadedFromFileRecordRules.Find(ExchangePlanName) = Undefined
			And DataExchangeCached.HasExchangePlanTemplate(ExchangePlanName, "RecordRules") Then
			
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Updating data registration rules for the %1 exchange plan.'"), ExchangePlanName);
			WriteLogEvent(EventLogMessageTextDataExchange(),
				EventLogLevel.Information,,, MessageText);
				
			ImportDataExchangeRules(Cancel, ExchangePlanName, Enums.DataExchangeRuleKinds.ObjectChangeRecordRules, "RecordRules");
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Creates an information register record set by the passed structure values. Adds one record to the set.
//
// Parameters:
//  RecordStructure - Structure - structure whose values will be used for creating and
//                    filling the record set.
//  RegisterName    - String - information register name.
//
 
Function CreateInformationRegisterRecordSet(RecordStructure, RegisterName) Export
	
	RegisterMetadata = Metadata.InformationRegisters[RegisterName];
	
	// Creating register a record set
	RecordSet = InformationRegisters[RegisterName].CreateRecordSet();
	
	// Setting filter for each register dimension
	For Each Dimension In RegisterMetadata.Dimensions Do
		
		// If dimension filter value is specified in a structure, the filter is set
		If RecordStructure.Property(Dimension.Name) Then
			
			RecordSet.Filter[Dimension.Name].Set(RecordStructure[Dimension.Name]);
			
		EndIf;
		
	EndDo;
	
	Return RecordSet;
EndFunction

// Returns the index of the picture to be displayed in the object mapping statistic table.
//
Function StatisticsTablePictureIndex(Val UnmappedObjectCount, Val DataImportedSuccessfully) Export
	
	Return ?(UnmappedObjectCount = 0, ?(DataImportedSuccessfully = True, 2, 0), 1);
	
EndFunction

// Checks whether exchange rules for the specified exchange plan have been imported.
//
//  Returns:
//   Boolean - True if the exchange rules are imported into the infobase, otherwise False.
//
Function ObjectConversionRulesForExchangePlanLoaded(Val ExchangePlanName) Export
	
	QueryText = "
	|SELECT TOP 1 1
	|FROM
	|	InformationRegister.DataExchangeRules AS DataExchangeRules
	|WHERE
	|	  DataExchangeRules.RuleKind = VALUE(Enum.DataExchangeRuleKinds.ObjectConversionRules)
	|	AND DataExchangeRules.RulesLoaded
	|	AND DataExchangeRules.ExchangePlanName = &ExchangePlanName
	|";
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("ExchangePlanName", ExchangePlanName);
	
	Return Not Query.Execute().IsEmpty();
EndFunction

// Checks whether the exchange message size exceed the maximum allowed size.
//
//  Returns:
//   Boolean - True if the exchange message size exceed the maximum allowed size, otherwise False.
//
Function ExchangeMessageSizeExceedsAllowed(Val FileName, Val MaxMessageSize) Export
	
	// Return value
	Result = False;
	
	File = New File(FileName);
	
	If File.Exist() And File.IsFile() Then
		
		If MaxMessageSize <> 0 Then
			
			PackageSize = Round(File.Size() / 1024, 0, RoundMode.Round15as20);
			
			If PackageSize > MaxMessageSize Then
				
				MessageString = NStr("en = 'The outgoing package size is %1 Kb. It exceeds the allowed limit (%2 Kb).'");
				MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, String(PackageSize), String(MaxMessageSize));
				ReportError(MessageString, Result);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	Return Result;
	
EndFunction

// For internal use.
// 
Function InitialDataExportFlagIsSet(InfobaseNode) Export
	
	SetPrivilegedMode(True);
	
	Return InformationRegisters.CommonInfobaseNodeSettings.InitialDataExportFlagIsSet(InfobaseNode);
	
EndFunction

// For internal use.
// 
Procedure RegisterOnlyCatalogsForInitialExport(Val InfobaseNode) Export
	
	RegisterDataForInitialExport(InfobaseNode, ExchangePlanCatalogs(InfobaseNode));
	
EndProcedure

// For internal use.
// 
Procedure RegisterAllDataExceptCatalogsForInitialExport(Val InfobaseNode) Export
	
	RegisterDataForInitialExport(InfobaseNode, AllExchangePlanDataExceptCatalogs(InfobaseNode));
	
EndProcedure

// For internal use.
// 
Procedure RegisterDataForInitialExport(InfobaseNode, Data = Undefined) Export
	
	SetPrivilegedMode(True);
	
	// Updating cached values of the Object registration mechanism
	DataExchangeServerCall.CheckObjectChangeRecordMechanismCache();
	
	StandardProcessing = True;
	
	DataExchangeOverridable.InitialDataExportChangeRecord(InfobaseNode, StandardProcessing, Data);
	
	If StandardProcessing Then
		
		If TypeOf(Data) = Type("Array") Then
			
			For Each MetadataObject In Data Do
				
				ExchangePlans.RecordChanges(InfobaseNode, MetadataObject);
				
			EndDo;
			
		Else
			
			ExchangePlans.RecordChanges(InfobaseNode, Data);
			
		EndIf;
		
	EndIf;
	
	If DataExchangeCached.ExchangePlanContainsObject(DataExchangeCached.GetExchangePlanName(InfobaseNode),
		Metadata.InformationRegisters.InfobaseObjectMappings.FullName()) Then
		
		ExchangePlans.DeleteChangeRecords(InfobaseNode, Metadata.InformationRegisters.InfobaseObjectMappings);
		
	EndIf;
	
	If Not DataExchangeCached.IsDistributedInfobaseNode(InfobaseNode) Then
		
		// Setting the initial data export flag for the node
		InformationRegisters.CommonInfobaseNodeSettings.SetInitialDataExportFlag(InfobaseNode);
		
	EndIf;
	
EndProcedure

// Imports the exchange message that contains configuration changes,
// before infobase update.
//
Procedure ImportMessageBeforeInfobaseUpdate() Export
	
	If DataExchangeServerCall.DataExchangeMessageImportModeBeforeStart(
			"SkipDataExchangeMessageImportingBeforeStart") Then
		Return;
	EndIf;
	
	If GetFunctionalOption("UseDataSynchronization") = True Then
		
		InfobaseNode = MasterNode();
		
		If InfobaseNode <> Undefined Then
			
			SetPrivilegedMode(True);
			SetDataExchangeMessageImportModeBeforeStart("ImportPermitted", True);
			SetPrivilegedMode(False);
			
			Try
				// Updating object registration rules before importing data
				UpdateDataExchangeRules();
				
				TransportKind = InformationRegisters.ExchangeTransportSettings.DefaultExchangeMessageTransportKind(InfobaseNode);
				
				Cancel = False;
				
				ExecuteDataExchangeForInfobaseNode(Cancel, InfobaseNode, True, False, TransportKind); // import only
				
				// Repeat mode must be enabled in the following cases.
				// Case 1. A new configuration version is received and therefore infobase update is required.
				// - if Cancel = True, the procedure execution must be stopped, otherwise data duplicates can be created,
				// - If Cancel = False, an error might occur during the infobase update and you might need to reimport the message.
				// Case 2. Received configuration version is equal to the current infobase configuration version and no updating required.
				// - If Cancel = True, an error might occur during the infobase startup,
				//   possible cause is that predefined items are not imported.
				// - if Cancel = False, it is possible to continue import because export can be performed later.
				//   If export cannot be succeeded, it is possible to receive a new message to import.
				
				If Cancel Or InfobaseUpdate.InfobaseUpdateRequired() Then
					EnableDataExchangeMessageImportRecurrenceBeforeStart();
				EndIf;
				
				If Cancel Then
					Raise NStr("en = 'Errors occurred when getting data from the master node.'");
				EndIf;
			Except
				SetPrivilegedMode(True);
				SetDataExchangeMessageImportModeBeforeStart("ImportPermitted", False);
				SetPrivilegedMode(False);
				Raise;
			EndTry;
			SetPrivilegedMode(True);
			SetDataExchangeMessageImportModeBeforeStart("ImportPermitted", False);
			SetPrivilegedMode(False);
		EndIf;
		
	EndIf;
	
EndProcedure

// Exports the exchange message that contains configuration changes,
// before infobase update.
//
Procedure ExportMessageAfterInfobaseUpdate() Export
	
	// The repeat mode can be disabled if messages are imported and the infobase is updated successfully
	DisableDataExchangeMessageImportRepeatBeforeStart();
	
	Try
		If GetFunctionalOption("UseDataSynchronization") = True Then
			
			InfobaseNode = MasterNode();
			
			If InfobaseNode <> Undefined Then
				
				ExecuteExport = True;
				
				TransportSettings = InformationRegisters.ExchangeTransportSettings.TransportSettings(InfobaseNode);
				
				TransportKind = TransportSettings.DefaultExchangeMessageTransportKind;
				
				If TransportKind = Enums.ExchangeMessageTransportKinds.WS
					And Not TransportSettings.WSRememberPassword Then
					
					ExecuteExport = False;
					
					InformationRegisters.CommonInfobaseNodeSettings.SetDataSendingFlag(InfobaseNode);
					
				EndIf;
				
				If ExecuteExport Then
					
					ExecuteDataExchangeForInfobaseNode(False, InfobaseNode, False, True, TransportKind); // Export only
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
	Except
		WriteLogEvent(EventLogMessageTextDataExchange(),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
	EndTry;
	
EndProcedure

// Sets the RetryDataExchangeMessageImportBeforeStart constant value to True.
// Clears exchange messages received from the master node.
//
Procedure EnableDataExchangeMessageImportRecurrenceBeforeStart()
	
	ClearDataExchangeMessageFromMasterNode();
	
	Constants.RetryDataExchangeMessageImportBeforeStart.Set(True);
	
EndProcedure

// Sets to False the import repeat flag. It is called if errors occurred during message import or infobase updating.
Procedure DisableDataExchangeMessageImportRepeatBeforeStart()
	
	SetPrivilegedMode(True);
	
	If Constants.RetryDataExchangeMessageImportBeforeStart.Get() = True Then
		Constants.RetryDataExchangeMessageImportBeforeStart.Set(False);
	EndIf;
	
EndProcedure

// Performs import and export of
// an exchange message that contains configuration
// changes but configuration update is not required.
//
Procedure ExecuteSynchronizationWhenInfobaseUpdateAbsent(
		OnClientStart, Restart) Export
	
	If Not LoadDataExchangeMessage() Then
		// If the message import is canceled and the metadata configuration version is not increased,
		// you have to disable the import repetition.
		DisableDataExchangeMessageImportRepeatBeforeStart();
		Return;
	EndIf;
		
	If ConfigurationChanged() Then
		// Configuration changes are imported but are not applied
		// Exchange message cannot be imported
		Return;
	EndIf;
	
	BeginTransaction();
	Try
		ImportMessageBeforeInfobaseUpdate();
		CommitTransaction();
	Except
		If ConfigurationChanged() Then
			If Not DataExchangeServerCall.DataExchangeMessageImportModeBeforeStart(
				"MessageReceivedFromCache") Then
				// Updating configuration from version where
				// cached exchange messages are not used. Perhaps, imported message
				// contains configuration changes. Cannot determine
				// whether the return to the database configuration was made. You have to commit
				// the transaction and continue the start without exchange message export.
				CommitTransaction();
				Return;
			Else
				// Configuration changes are received.
				// It means that return to database configuration was performed.
				// The data import must be cancelled.
				RollbackTransaction();
				SetPrivilegedMode(True);
				Constants.LoadDataExchangeMessage.Set(False);
				ClearDataExchangeMessageFromMasterNode();
				SetPrivilegedMode(False);
				WriteDataReceiveEvent(MasterNode(),
					NStr("en = 'Return to the database configuration is detected.
					           |Synchronization is canceled.'"));
				Return;
			EndIf;
		EndIf;
		// If the return to the database configuration is executed, 
   // but Designer is not closed.
		// It means that the message is not imported.
		// After you switch to the repeat mode, you can click
		// the "Not synchronize and continue" button, and after that
		// return to the database configuration will be completed.
		CommitTransaction();
		EnableDataExchangeMessageImportRecurrenceBeforeStart();
		If OnClientStart Then
			Restart = True;
			Return;
		EndIf;
		Raise;
	EndTry;
	
	ExportMessageAfterInfobaseUpdate();
	
EndProcedure

// For internal use.
// 
Function LongActionStateForInfobaseNode(Val InfobaseNode,
																Val ActionID,
																ErrorMessageString = ""
	) Export
	
	WSProxy = GetWSProxyForInfobaseNode(InfobaseNode, ErrorMessageString);
	
	If WSProxy = Undefined Then
		Raise ErrorMessageString;
	EndIf;
	
	Return WSProxy.GetLongActionState(ActionID, ErrorMessageString);
EndFunction

// For internal use.
// 
Function TempFileStorageDirectory()
	
	Return DataExchangeCached.TempFileStorageDirectory();
	
EndFunction

// For internal use.
// 
Function UniqueExchangeMessageFileName()
	
	Result = "Message{GUID}.xml";
	Result = StrReplace(Result, "GUID", String(New UUID));
	
	Return Result;
EndFunction

// For internal use.
// 
Function IsSubordinateDIBNode() Export
	
	Return MasterNode() <> Undefined;
	
EndFunction

// Returns the current infobase master node if the distributed infobase
// is created based on the exchange plan that is supported in the SL data exchange subsystem.
//
// Returns:
//  ExchangePlanRef.<Exchange plan name>; Undefined - this function returns Undefined
//   in the following cases:
//   - the current infobase is not a DIB node or the master node
//     is not defined (this infobase is the master node),
//   - distributed infobase is created based on
//     an exchange plan that is not supported in the SL data exchange subsystem.
//
Function MasterNode() Export
	
	Result = ExchangePlans.MasterNode();
	
	If Result <> Undefined Then
		
		If Not DataExchangeCached.IsSLDataExchangeNode(Result) Then
			
			Result = Undefined;
			
		EndIf;
		
	EndIf;
	
	Return Result;
EndFunction

// Returns an array of version numbers supported by correspondent API for the DataExchange subsystem.
// 
// Parameters:
// ExternalConnection - COMconnection object that is used for working with the correspondent infobase.
//
// Returns:
// Array of version numbers that are supported by correspondent API.
//
Function CorrespondentVersionsViaExternalConnection(ExternalConnection) Export
	
	Return CommonUse.GetInterfaceVersionsViaExternalConnection(ExternalConnection, "DataExchange");
	
EndFunction

// For internal use.
// 
Function FirstErrorBriefPresentation(ErrorInfo)
	
	If ErrorInfo.Reason <> Undefined Then
		
		Return FirstErrorBriefPresentation(ErrorInfo.Reason);
		
	EndIf;
	
	Return BriefErrorDescription(ErrorInfo);
EndFunction

// Creates a temporary directory for exchange messages.
// Writes the directory name to the register for further deletion.
//
Function CreateTempExchangeMessageDirectory() Export
	
	Result = CommonUseClientServer.GetFullFileName(DataExchangeCached.TempFileStorageDirectory(), TempExchangeMessageDirectory());
	
	CreateDirectory(Result);
	
	If Not CommonUse.FileInfobase() Then
		
		SetPrivilegedMode(True);
		
		PutFileToStorage(Result);
		
	EndIf;
	
	Return Result;
EndFunction

// Returns the flag that shows whether the data exchange message must be imported.
//
Function LoadDataExchangeMessage() Export
	
	SetPrivilegedMode(True);
	
	Return Constants.LoadDataExchangeMessage.Get() = True;
	
EndFunction

Function InvertDefaultDataItemReceive(Val DataReceivingFromMasterNode) Export
	
	Return ?(DataReceivingFromMasterNode, DataItemReceive.Ignore, DataItemReceive.Accept);
	
EndFunction

Function DataExchangeVariant(Val Correspondent) Export
	
	Result = "Synchronization";
	
	If Not DataExchangeCached.IsDistributedInfobaseNode(Correspondent) Then
		
		AttributeNames = CommonUse.AttributeNamesByType(Correspondent, Type("EnumRef.ExchangeObjectExportModes"));
		
		AttributeValues = CommonUse.ObjectAttributeValues(Correspondent, AttributeNames);
		
		For Each Attribute In AttributeValues Do
			
			If Attribute.Value = Enums.ExchangeObjectExportModes.ManualExport
				Or Attribute.Value = Enums.ExchangeObjectExportModes.NotExport Then
				
				Result = "ReceiveAndSend";
				Break;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	Return Result;
EndFunction

Procedure ImportObjectContext(Val Context, Val Object) Export
	
	For Each Attribute In Object.Metadata().Attributes Do
		
		If Context.Property(Attribute.Name) Then
			
			Object[Attribute.Name] = Context[Attribute.Name];
			
		EndIf;
		
	EndDo;
	
	For Each TabularSection In Object.Metadata().TabularSections Do
		
		If Context.Property(TabularSection.Name) Then
			
			Object[TabularSection.Name].Load(Context[TabularSection.Name]);
			
		EndIf;
		
	EndDo;
	
EndProcedure

Function GetObjectContext(Val Object) Export
	
	Result = New Structure;
	
	For Each Attribute In Object.Metadata().Attributes Do
		
		Result.Insert(Attribute.Name, Object[Attribute.Name]);
		
	EndDo;
	
	For Each TabularSection In Object.Metadata().TabularSections Do
		
		Result.Insert(TabularSection.Name, Object[TabularSection.Name].Unload());
		
	EndDo;
	
	Return Result;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Wrappers for operating with  the external (public) application interface of the exchange plan manager.

Function NodeFilterStructure(Val ExchangePlanName, Val CorrespondentVersion, FormName = "") Export
	
	If IsBlankString(CorrespondentVersion) Then
		CorrespondentVersion = "0.0.0.0";
	EndIf;
	
	FormName = "";
	
	Result = ExchangePlans[ExchangePlanName].NodeFilterStructure(CorrespondentVersion, FormName);
	
	If IsBlankString(FormName) Then
		FormName = "NodeSettingsForm";
	EndIf;
	
	If Result = Undefined Then
		Result = New Structure;
	EndIf;
	
	Return Result;
EndFunction

Function NodeDefaultValues(Val ExchangePlanName, Val CorrespondentVersion, FormName = "") Export
	
	If IsBlankString(CorrespondentVersion) Then
		CorrespondentVersion = "0.0.0.0";
	EndIf;
	
	FormName = "";
	
	Result = ExchangePlans[ExchangePlanName].NodeDefaultValues(CorrespondentVersion, FormName);
	
	If IsBlankString(FormName) Then
		FormName = "DefaultValueSetupForm";
	EndIf;
	
	If Result = Undefined Then
		Result = New Structure;
	EndIf;
	
	Return Result;
EndFunction

Function DataTransferRestrictionDetails(Val ExchangePlanName, Val Settings, Val CorrespondentVersion) Export
	
	If IsBlankString(CorrespondentVersion) Then
		CorrespondentVersion = "0.0.0.0";
	EndIf;
	
	Return ExchangePlans[ExchangePlanName].DataTransferRestrictionDetails(Settings, CorrespondentVersion);
	
EndFunction

Function DefaultValueDetails(Val ExchangePlanName, Val Settings, Val CorrespondentVersion) Export
	
	If IsBlankString(CorrespondentVersion) Then
		CorrespondentVersion = "0.0.0.0";
	EndIf;
	
	Return ExchangePlans[ExchangePlanName].DefaultValueDetails(Settings, CorrespondentVersion);
	
EndFunction

Function CommonNodeData(Val ExchangePlanName, Val CorrespondentVersion, FormName = "") Export
	
	If IsBlankString(CorrespondentVersion) Then
		CorrespondentVersion = "0.0.0.0";
	EndIf;
	
	FormName = "";
	
	Result = ExchangePlans[ExchangePlanName].CommonNodeData(CorrespondentVersion, FormName);
	
	If IsBlankString(FormName) Then
		FormName = "NodesSetupForm";
	EndIf;
	
	Return StrReplace(Result, " ", "");
EndFunction

Function CorrespondentInfobaseNodeFilterSetup(Val ExchangePlanName, Val CorrespondentVersion, FormName = "") Export
	
	If IsBlankString(CorrespondentVersion) Then
		CorrespondentVersion = "0.0.0.0";
	EndIf;
	
	FormName = "";
	
	Result = ExchangePlans[ExchangePlanName].CorrespondentInfobaseNodeFilterSetup(CorrespondentVersion, FormName);
	
	If IsBlankString(FormName) Then
		FormName = "CorrespondentInfobaseNodeSettingsForm";
	EndIf;
	
	If Result = Undefined Then
		Result = New Structure;
	EndIf;
	
	Return Result;
EndFunction

Function CorrespondentInfobaseNodeDefaultValues(Val ExchangePlanName, Val CorrespondentVersion, FormName = "") Export
	
	If IsBlankString(CorrespondentVersion) Then
		CorrespondentVersion = "0.0.0.0";
	EndIf;
	
	FormName = "";
	
	Result = ExchangePlans[ExchangePlanName].CorrespondentInfobaseNodeDefaultValues(CorrespondentVersion, FormName);
	
	If IsBlankString(FormName) Then
		FormName = "CorrespondentInfobaseDefaultValueSetupForm";
	EndIf;
	
	If Result = Undefined Then
		Result = New Structure;
	EndIf;
	
	Return Result;
EndFunction

Function CorrespondentInfobaseDataTransferRestrictionDetails(Val ExchangePlanName, Val NodeFilterStructure, Val CorrespondentVersion) Export
	
	If IsBlankString(CorrespondentVersion) Then
		CorrespondentVersion = "0.0.0.0";
	EndIf;
	
	Return ExchangePlans[ExchangePlanName].CorrespondentInfobaseDataTransferRestrictionDetails(NodeFilterStructure, CorrespondentVersion);
	
EndFunction

Function CorrespondentInfobaseDefaultValueDetails(Val ExchangePlanName, Val NodeDefaultValues, Val CorrespondentVersion) Export
	
	If IsBlankString(CorrespondentVersion) Then
		CorrespondentVersion = "0.0.0.0";
	EndIf;
	
	Return ExchangePlans[ExchangePlanName].CorrespondentInfobaseDefaultValueDetails(NodeDefaultValues, CorrespondentVersion);
	
EndFunction

Function CorrespondentInfobaseAccountingSettingsSetupComment(Val ExchangePlanName, Val CorrespondentVersion) Export
	
	If IsBlankString(CorrespondentVersion) Then
		CorrespondentVersion = "0.0.0.0";
	EndIf;
	
	Return ExchangePlans[ExchangePlanName].CorrespondentInfobaseAccountingSettingsSetupComment(CorrespondentVersion);
	
EndFunction

Procedure OnConnectToCorrespondent(Val ExchangePlanName, Val CorrespondentVersion) Export
	
	If IsBlankString(CorrespondentVersion) Then
		CorrespondentVersion = "0.0.0.0";
	EndIf;
	
	ExchangePlans[ExchangePlanName].OnConnectToCorrespondent(CorrespondentVersion);
	
EndProcedure


// For internal use.
// 
Function DataImportDataProcessor(Cancel, Val InfobaseNode, Val ExchangeMessageFileName) Export
	
	Return DataExchangeCached.DataProcessorForDataImport(Cancel, InfobaseNode, ExchangeMessageFileName);
	
EndFunction

// Returns the initialized InfobaseObjectConversion data processor that is used to perform data import.
// The data processor is saved in platform cached data for multiple usage.
// This data processor is used for a single exchange plan and exchange message file with unique full name.
// 
// Parameters:
//  InfobaseNode            - ExchangePlanRef - exchange plan node.
//  ExchangeMessageFileName - String - unique file name of the message file to import.
// 
// Returns:
//  DataProcessorObject.InfobaseObjectConversion - initialized data processor for data import.
//
Function DataProcessorForDataImport(Cancel, Val InfobaseNode, Val ExchangeMessageFileName) Export
	
	// INITIALIZING THE DATA PROCESSOR FOR THE DATA IMPORT
	DataProcessorManager = DataProcessors.InfobaseObjectConversion;
	
	If CommonUse.SubsystemExists("DataExchangeXDTO") Then
		
		DataExchangeXDTOCachedModule = CommonUse.CommonModule("DataExchangeXDTOCached");
		DataExchangeXDTOServerModule = CommonUse.CommonModule("DataExchangeXDTOServer");
		
		If DataExchangeXDTOCachedModule.IsXDTOExchangePlan(InfobaseNode) Then
			DataProcessorManager = DataExchangeXDTOServerModule.DataConversionDataProcessorForUniversalExchange();
		EndIf;
		
	EndIf;
	
	DataExchangeDataProcessor = DataProcessorManager.Create();
	
	DataExchangeDataProcessor.ExchangeMode = "Import";
	
	DataExchangeDataProcessor.OutputInfoMessagesToMessageWindow = False;
	DataExchangeDataProcessor.WriteInfoMessagesToLog = False;
	DataExchangeDataProcessor.AppendDataToExchangeLog = False;
	DataExchangeDataProcessor.ExportAllowedOnly = False;
	DataExchangeDataProcessor.ContinueOnError = False;
	
	DataExchangeDataProcessor.ExchangeLogFileName = "";
	
	DataExchangeDataProcessor.EventLogMessageKey = GetEventLogMessageKey(InfobaseNode, Enums.ActionsOnExchange.DataImport);
	
	DataExchangeDataProcessor.ExchangeNodeDataImport = InfobaseNode;
	DataExchangeDataProcessor.ExchangeFileName       = ExchangeMessageFileName;
	
	DataExchangeDataProcessor.ObjectCountPerTransaction = DataImportTransactionItemCount();
	
	ExchangePlanName = DataExchangeCached.GetExchangePlanName(InfobaseNode);
	
	SetImportDebugSettingsForExchangeRules(DataExchangeDataProcessor, ExchangePlanName);
	
	Return DataExchangeDataProcessor;
EndFunction

// Procedures and functions for operating with data synchronization passwords.

// Returns the data synchronization password for the specified node.
// If the password is not set, the function returns Undefined.
//
// Returns:
//  String, Undefined - data synchronization password value.
//
Function DataSynchronizationPassword(Val InfobaseNode) Export
	
	SetPrivilegedMode(True);
	
	Return SessionParameters.DataSynchronizationPasswords.Get(InfobaseNode);
EndFunction

// Returns the flag that shows whether the data synchronization password is set by a user.
//
Function DataSynchronizationPasswordSpecified(Val InfobaseNode) Export
	
	Return DataSynchronizationPassword(InfobaseNode) <> Undefined;
	
EndFunction

// Sets the data synchronization password for the specified node.
// The password is stored in the session parameter.
//
Procedure SetDataSynchronizationPassword(Val InfobaseNode, Val Password)
	
	SetPrivilegedMode(True);
	
	DataSynchronizationPasswords = New Map;
	
	For Each Item In SessionParameters.DataSynchronizationPasswords Do
		
		DataSynchronizationPasswords.Insert(Item.Key, Item.Value);
		
	EndDo;
	
	DataSynchronizationPasswords.Insert(InfobaseNode, Password);
	
	SessionParameters.DataSynchronizationPasswords = New FixedMap(DataSynchronizationPasswords);
	
EndProcedure

// Resets the data synchronization password for the specified node.
//
Procedure ResetDataSynchronizationPassword(Val InfobaseNode)
	
	SetDataSynchronizationPassword(InfobaseNode, Undefined);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Checking shared data.

// Checks whether it is possible to write separated data item. Raises exception if the data item cannot be written.
//
Procedure ExecuteSharedDataOnWriteCheck(Val Data) Export
	
	If CommonUseCached.DataSeparationEnabled()
		And CommonUseCached.CanUseSeparatedData()
		And Not IsSeparatedObject(Data) Then
		
		ExceptionPresentation = NStr("en = 'Access right violation!'");
		ErrorMessage = NStr("en = 'Access right violation!'", CommonUseClientServer.DefaultLanguageCode());
		
		WriteLogEvent(
			ErrorMessage,
			EventLogLevel.Error,
			Data.Metadata());
		
		Raise ExceptionPresentation;
	EndIf;
	
EndProcedure

Function IsSeparatedObject(Val Object)
	
	FullName = Object.Metadata().FullName();
	
	Return CommonUseCached.IsSeparatedMetadataObject(FullName, CommonUseCached.MainDataSeparator())
		Or CommonUseCached.IsSeparatedMetadataObject(FullName, CommonUseCached.AuxiliaryDataSeparator())
	;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for operating with the data exchange monitor.

// Returns a structure with information about the last exchange for the specified infobase node.
// 
// Returns:
//  DataExchangeStates - Structure - contains data of the last data exchange for the specified infobase node.
//
Function ExchangeNodeDataExchangeStates(Val InfobaseNode) Export
	
	// Return value
	DataExchangeStates = New Structure;
	DataExchangeStates.Insert("InfobaseNode");
	DataExchangeStates.Insert("DataImportResult", "Undefined");
	DataExchangeStates.Insert("DataExportResult", "Undefined");
	
	QueryText = "
	|// {QUERY #0}
	|////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CASE
	|	WHEN DataExchangeStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.Completed)
	|	THEN ""Success""
	|	
	|	WHEN DataExchangeStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.CompletedWithWarnings)
	|	THEN ""CompletedWithWarnings""
	|	
	|	WHEN DataExchangeStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.Warning_ExchangeMessageReceivedPreviously)
	|	THEN ""Warning_ExchangeMessageReceivedPreviously""
	|	
	|	WHEN DataExchangeStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.Error_MessageTransport)
	|	THEN ""Error_MessageTransport""
	|	
	|	ELSE ""Error""
	|	
	|	END AS ExchangeExecutionResult
	|FROM
	|	InformationRegister.[DataExchangeStates] AS DataExchangeStates
	|WHERE
	|	  DataExchangeStates.InfobaseNode = &InfobaseNode
	|	AND DataExchangeStates.ActionOnExchange = VALUE(Enum.ActionsOnExchange.DataImport)
	|;
	|// {QUERY #1}
	|////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CASE
	|	WHEN DataExchangeStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.Completed)
	|	THEN ""Success""
	|	
	|	WHEN DataExchangeStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.CompletedWithWarnings)
	|	THEN ""CompletedWithWarnings""
	|	
	|	WHEN DataExchangeStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.Warning_ExchangeMessageReceivedPreviously)
	|	THEN ""Warning_ExchangeMessageReceivedPreviously""
	|	
	|	WHEN DataExchangeStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.Error_MessageTransport)
	|	THEN ""Error_MessageTransport""
	|	
	|	ELSE ""Error""
	|	END AS ExchangeExecutionResult
	|	
	|FROM
	|	InformationRegister.[DataExchangeStates] AS DataExchangeStates
	|WHERE
	|	  DataExchangeStates.InfobaseNode = &InfobaseNode
	|	AND DataExchangeStates.ActionOnExchange = VALUE(Enum.ActionsOnExchange.DataExport)
	|;
	|";
	
	If CommonUseCached.DataSeparationEnabled()
		And CommonUseCached.CanUseSeparatedData() Then
		QueryText = StrReplace(QueryText, "[DataExchangeStates]", "DataAreaDataExchangeStates");
	Else
		QueryText = StrReplace(QueryText, "[DataExchangeStates]", "DataExchangeStates");
	EndIf;
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("InfobaseNode", InfobaseNode);
	
	QueryResultArray = Query.ExecuteBatch();
	
	DataImportResultSelection = QueryResultArray[0].Select();
	DataExportResultSelection = QueryResultArray[1].Select();
	
	If DataImportResultSelection.Next() Then
		
		DataExchangeStates.DataImportResult = DataImportResultSelection.ExchangeExecutionResult;
		
	EndIf;
	
	If DataExportResultSelection.Next() Then
		
		DataExchangeStates.DataExportResult = DataExportResultSelection.ExchangeExecutionResult;
		
	EndIf;
	
	DataExchangeStates.InfobaseNode = InfobaseNode;
	
	Return DataExchangeStates;
EndFunction

// Returns the structure that contains details of the last data exchange for the specified infobase node and an action on data exchange.
// 
// Returns:
//  DataExchangeStates - Structure - contains data of the last data exchange for the specified infobase node.
//
Function DataExchangeStates(Val InfobaseNode, ActionOnExchange) Export
	
	// Return value
	DataExchangeStates = New Structure;
	DataExchangeStates.Insert("StartDate", Date('00010101'));
	DataExchangeStates.Insert("EndDate",   Date('00010101'));
	
	QueryText = "
	|SELECT
	|	StartDate,
	|	EndDate
	|FROM
	|	InformationRegister.[DataExchangeStates] AS DataExchangeStates
	|WHERE
	|	  DataExchangeStates.InfobaseNode       = &InfobaseNode
	|	AND DataExchangeStates.ActionOnExchange = &ActionOnExchange
	|";
	
	If CommonUseCached.DataSeparationEnabled()
		And CommonUseCached.CanUseSeparatedData() Then
		QueryText = StrReplace(QueryText, "[DataExchangeStates]", "DataAreaDataExchangeStates");
	Else
		QueryText = StrReplace(QueryText, "[DataExchangeStates]", "DataExchangeStates");
	EndIf;
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("InfobaseNode",     InfobaseNode);
	Query.SetParameter("ActionOnExchange", ActionOnExchange);
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		
		FillPropertyValues(DataExchangeStates, Selection);
		
	EndIf;
	
	Return DataExchangeStates;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Session initialization.

// Returns an array of exchange plans that take part in the data exchange.
// The return array contains all exchange plans that have exchange nodes except the
// predefined one.
// 
// Returns:
//  ExchangePlanArray - Array of String - names of all array of exchange plans that take
//                      part in the data exchange.
//

Function GetUsedExchangePlans() Export
	
	// Return value
	ExchangePlanArray = New Array;
	
	// List of all configuration nodes
	ExchangePlanList = DataExchangeCached.SLExchangePlanList();
	
	For Each Item In ExchangePlanList Do
		
		ExchangePlanName = Item.Value;
		
		If Not ExchangePlanContainsNoNodes(ExchangePlanName) Then
			
			ExchangePlanArray.Add(ExchangePlanName);
			
		EndIf;
		
	EndDo;
	
	Return ExchangePlanArray;
	
EndFunction

// Returns a table of the object registration rules from the infobase.
// 
// Returns:
//  ObjectChangeRecordRules - ValueTable - table of the common object registration
//                            rules for the object registration mechanism.
// 
Function GetObjectChangeRecordRules() Export
	
	// Return value
	ObjectChangeRecordRules = InitObjectChangeRecordRuleTable();
	
	QueryText = "
	|SELECT
	|	DataExchangeRules.ReadRulesAlready AS ReadRulesAlready
	|FROM
	|	InformationRegister.DataExchangeRules AS DataExchangeRules
	|WHERE
	|	  DataExchangeRules.RuleKind = VALUE(Enum.DataExchangeRuleKinds.ObjectChangeRecordRules)
	|	AND DataExchangeRules.RulesLoaded
	|";
	
	Query = New Query;
	Query.Text = QueryText;
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		FillPropertyValuesForORRValueTable(ObjectChangeRecordRules, Selection.ReadRulesAlready.Get());
		
	EndDo;
	
	Return ObjectChangeRecordRules;
	
EndFunction

// Returns a table of the selective object registration rules from the infobase.
// 
// Returns:
//  SelectiveObjectChangeRecordRules - ValueTable - table of the common rules of 
//                                     selective object registration for the object
//                                     registration mechanism.
//
 
Function GetSelectiveObjectChangeRecordRules() Export
	
	// Return value
	SelectiveObjectChangeRecordRules = SelectiveObjectChangeRecordRuleTableInitialization();
	
	QueryText = "
	|SELECT
	|	DataExchangeRules.ReadRulesAlready AS ReadRulesAlready
	|FROM
	|	InformationRegister.DataExchangeRules AS DataExchangeRules
	|WHERE
	|	  DataExchangeRules.RuleKind = VALUE(Enum.DataExchangeRuleKinds.ObjectConversionRules)
	|	AND DataExchangeRules.UseSelectiveObjectChangeRecordFilter
	|	AND DataExchangeRules.RulesLoaded
	|";
	
	Query = New Query;
	Query.Text = QueryText;
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		ExchangeRuleStructure = Selection.ReadRulesAlready.Get();
		
		FillPropertyValuesForValueTable(SelectiveObjectChangeRecordRules, ExchangeRuleStructure["SelectiveObjectChangeRecordRules"]);
		
	EndDo;
	
	Return SelectiveObjectChangeRecordRules;
	
EndFunction

// For internal use.
// 
Function InitObjectChangeRecordRuleTable() Export
	
	// Return value
	Rules = New ValueTable;
	
	Columns = Rules.Columns;
	
	Columns.Add("MetadataObjectName", New TypeDescription("String"));
	Columns.Add("ExchangePlanName",   New TypeDescription("String"));
	
	Columns.Add("FlagAttributeName", New TypeDescription("String"));
	
	Columns.Add("QueryText",        New TypeDescription("String"));
	Columns.Add("ObjectProperties", New TypeDescription("Structure"));
	
	Columns.Add("ObjectPropertiesString", New TypeDescription("String"));
	
	// Flag that shows whether rules are empty
	Columns.Add("RuleByObjectPropertiesEmpty", New TypeDescription("Boolean"));
	
	// Event handlers
	Columns.Add("BeforeProcess",       New TypeDescription("String"));
	Columns.Add("OnProcess",           New TypeDescription("String"));
	Columns.Add("OnProcessAdditional", New TypeDescription("String"));
	Columns.Add("AfterProcess",        New TypeDescription("String"));
	
	Columns.Add("HasBeforeProcessHandler",       New TypeDescription("Boolean"));
	Columns.Add("HasOnProcessHandler",           New TypeDescription("Boolean"));
	Columns.Add("HasOnProcessHandlerAdditional", New TypeDescription("Boolean"));
	Columns.Add("HasAfterProcessHandler",        New TypeDescription("Boolean"));
	
	Columns.Add("FilterByObjectProperties", New TypeDescription("ValueTree"));
	
	// This field is used for temporary storing data from the object or reference
	Columns.Add("FilterByProperties", New TypeDescription("ValueTree"));
	
	// Adding the index
	Rules.Indexes.Add("ExchangePlanName, MetadataObjectName");
	
	Return Rules;
	
EndFunction

// For internal use.
// 
Function SelectiveObjectChangeRecordRuleTableInitialization() Export
	
	// Return value
	Rules = New ValueTable;
	
	Columns = Rules.Columns;
	
	Columns.Add("Order",                          New TypeDescription("Number"));
	Columns.Add("ObjectName",                     New TypeDescription("String"));
	Columns.Add("ExchangePlanName",               New TypeDescription("String"));
	Columns.Add("TabularSectionName",             New TypeDescription("String"));
	Columns.Add("ChangeRecordAttributes",         New TypeDescription("String"));
	Columns.Add("ChangeRecordAttributeStructure", New TypeDescription("Structure"));
	
	// Adding the index
	Rules.Indexes.Add("ExchangePlanName, ObjectName");
	
	Return Rules;
	
EndFunction

// For internal use.
// 
Function ExchangePlanContainsNoNodes(Val ExchangePlanName)
	
	QueryText = "
	|SELECT TOP 1 1
	|FROM
	|	ExchangePlan." + ExchangePlanName + " AS
	|ExchangePlan
	|WHERE ExchangePlan.Ref <> &ThisNode
	|";
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("ThisNode", ExchangePlans[ExchangePlanName].ThisNode());
	
	Return Query.Execute().IsEmpty()
	
EndFunction

// For internal use.
// 
Procedure FillPropertyValuesForORRValueTable(TargetTable, SourceTable)
	
	For Each SourceRow In SourceTable Do
		
		FillPropertyValues(TargetTable.Add(), SourceRow);
		
	EndDo;
	
EndProcedure

// For internal use.
// 
Procedure FillPropertyValuesForValueTable(TargetTable, SourceTable)
	
	For Each SourceRow In SourceTable Do
		
		FillPropertyValues(TargetTable.Add(), SourceRow);
		
	EndDo;
	
EndProcedure

// For internal use.
// 
Function DataSynchronizationRuleDetails(Val InfobaseNode) Export
	
	CorrespondentVersion = CorrespondentVersion(InfobaseNode);
	
	ExchangePlanName = DataExchangeCached.GetExchangePlanName(InfobaseNode);
	
	Settings = FilterSettingsValuesOnNode(InfobaseNode, CorrespondentVersion);
	
	Return DataTransferRestrictionDetails(ExchangePlanName, Settings, CorrespondentVersion);
EndFunction

// For internal use.
// 
Function FilterSettingsValuesOnNode(Val InfobaseNode, Val CorrespondentVersion)
	
	Result = New Structure;
	
	InfobaseNodeObject = InfobaseNode.GetObject();
	
	ExchangePlanName = DataExchangeCached.GetExchangePlanName(InfobaseNode);
	
	NodeFilterStructure = NodeFilterStructure(ExchangePlanName, CorrespondentVersion);
	
	For Each Settings In NodeFilterStructure Do
		
		If TypeOf(Settings.Value) = Type("Structure") Then
			
			TabularSection = New Structure;
			
			For Each Column In Settings.Value Do
				
				TabularSection.Insert(Column.Key, InfobaseNodeObject[Settings.Key].UnloadColumn(Column.Key));
				
			EndDo;
			
			Result.Insert(Settings.Key, TabularSection);
			
		Else
			
			Result.Insert(Settings.Key, InfobaseNodeObject[Settings.Key]);
			
		EndIf;
		
	EndDo;
	
	Return Result;
EndFunction

// For internal use.
Procedure SetDataExchangeMessageImportModeBeforeStart(Val Property, Val EnableMode) Export
	
	// You have to set the privileged mode before the procedure call..
	
	If IsSubordinateDIBNode() Then
		
		NewStructure = New Structure(SessionParameters.DataExchangeMessageImportModeBeforeStart);
		If EnableMode Then
			If Not NewStructure.Property(Property) Then
				NewStructure.Insert(Property);
			EndIf;
		Else
			If NewStructure.Property(Property) Then
				NewStructure.Delete(Property);
			EndIf;
		EndIf;
		
		SessionParameters.DataExchangeMessageImportModeBeforeStart =
			New FixedStructure(NewStructure);
	Else
		
		SessionParameters.DataExchangeMessageImportModeBeforeStart = New FixedStructure;
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Initializes the data exchange subsystem for performing the exchange.
// 
// Parameters:
// 
// Returns:
//  ExchangeSettingsStructure - Structure - structure with all necessary data and
//                              objects for performing the exchange.
//

Function GetExchangeSettingStructureForInfobaseNode(
	InfobaseNode,
	ActionOnExchange,
	ExchangeMessageTransportKind,
	UseTransportSettings = True
	) Export
	
	// Return value
	ExchangeSettingsStructure = BaseExchangeSettingsStructure();
	
	ExchangeSettingsStructure.InfobaseNode          = InfobaseNode;
	ExchangeSettingsStructure.ActionOnExchange      = ActionOnExchange;
	ExchangeSettingsStructure.ExchangeTransportKind = ExchangeMessageTransportKind;
	ExchangeSettingsStructure.IsDIBExchange         = DataExchangeCached.IsDistributedInfobaseNode(InfobaseNode);
	
	InitExchangeSettingsStructureForInfobaseNode(ExchangeSettingsStructure, UseTransportSettings);
	
	SetDebugModeSettingsForStructure(ExchangeSettingsStructure);
	
	// Validating settings structure values for the exchange. Writing errors to the event log.
	CheckExchangeStructure(ExchangeSettingsStructure, UseTransportSettings);
	
	// Canceling if settings contain errors
	If ExchangeSettingsStructure.Cancel Then
		Return ExchangeSettingsStructure;
	EndIf;
	
	If UseTransportSettings Then
		
		// Initializing the exchange message transport data processor
		InitExchangeMessageTransportDataProcessor(ExchangeSettingsStructure);
		
	EndIf;
	
	// Initializing the exchange data processor
	If ExchangeSettingsStructure.IsDIBExchange Then
		
		InitDataExchangeDataProcessor(ExchangeSettingsStructure);
		
	ElsIf ExchangeSettingsStructure.ExchangeByObjectConversionRules Then
		
		InitDataExchangeDataProcessorForConversionRules(ExchangeSettingsStructure);
		
	EndIf;
	
	Return ExchangeSettingsStructure;
EndFunction

// For internal use.
// 
Function GetExchangeSettingsStructureForExternalConnection(InfobaseNode, ActionOnExchange, TransactionItemCount)
	
	// Return value
	ExchangeSettingsStructure = BaseExchangeSettingsStructure();
	
	ExchangeSettingsStructure.InfobaseNode     = InfobaseNode;
	ExchangeSettingsStructure.ActionOnExchange = ActionOnExchange;
	ExchangeSettingsStructure.IsDIBExchange    = DataExchangeCached.IsDistributedInfobaseNode(InfobaseNode);
	
	PropertyStructure = CommonUse.ObjectAttributeValues(ExchangeSettingsStructure.InfobaseNode, "Code, Description");
	
	ExchangeSettingsStructure.InfobaseNodeCode        = PropertyStructure.Code;
	ExchangeSettingsStructure.InfobaseNodeDescription = PropertyStructure.Description;
	
	ExchangeSettingsStructure.TransportSettings = InformationRegisters.ExchangeTransportSettings.TransportSettings(ExchangeSettingsStructure.InfobaseNode);
	
	If TransactionItemCount = Undefined Then
		
		TransactionItemCount = ?(ExchangeSettingsStructure.ActionOnExchange = Enums.ActionsOnExchange.DataImport,
									ExchangeSettingsStructure.TransportSettings.DataImportTransactionItemCount,
									ExchangeSettingsStructure.TransportSettings.DataExportTransactionItemCount);
 
		
	EndIf;
	
	ExchangeSettingsStructure.TransactionItemCount = TransactionItemCount;
	
	// CALCULATED VALUES
	ExchangeSettingsStructure.DoDataImport = (ExchangeSettingsStructure.ActionOnExchange = Enums.ActionsOnExchange.DataImport);
	ExchangeSettingsStructure.DoDataExport = (ExchangeSettingsStructure.ActionOnExchange = Enums.ActionsOnExchange.DataExport);
	
	ExchangeSettingsStructure.ExchangePlanName = DataExchangeCached.GetExchangePlanName(ExchangeSettingsStructure.InfobaseNode);
	
	ExchangeSettingsStructure.CurrentExchangePlanNode     = DataExchangeCached.GetThisExchangePlanNode(ExchangeSettingsStructure.ExchangePlanName);
	ExchangeSettingsStructure.CurrentExchangePlanNodeCode = CommonUse.ObjectAttributeValue(ExchangeSettingsStructure.CurrentExchangePlanNode, "Code");
	
	// Getting the message key for the event log
	ExchangeSettingsStructure.EventLogMessageKey = GetEventLogMessageKey(ExchangeSettingsStructure.InfobaseNode, ExchangeSettingsStructure.ActionOnExchange);
	
	ExchangeSettingsStructure.ExchangeTransportKind = Enums.ExchangeMessageTransportKinds.COM;
	
	SetDebugModeSettingsForStructure(ExchangeSettingsStructure);
	
	// Validating settings structure values for the exchange. Writing errors to the event log.
	CheckExchangeStructure(ExchangeSettingsStructure);
	
	// Canceling if settings contain errors
	If ExchangeSettingsStructure.Cancel Then
		Return ExchangeSettingsStructure;
	EndIf;
	
	// Initializing the exchange data processor
	InitDataExchangeDataProcessorForConversionRules(ExchangeSettingsStructure);
	
	Return ExchangeSettingsStructure;
EndFunction

// Initializes the data exchange subsystem for performing the exchange.
// 
// Parameters:
// 
// Returns:
//  ExchangeSettingsStructure - Structure - structure with all required for exchange data and objects.
//
Function GetExchangeSettingsStructure(ExchangeExecutionSettings, LineNumber) Export
	
	// Return value
	ExchangeSettingsStructure = BaseExchangeSettingsStructure();
	
	InitExchangeSettingsStructure(ExchangeSettingsStructure, ExchangeExecutionSettings, LineNumber);
	
	If ExchangeSettingsStructure.Cancel Then
		Return ExchangeSettingsStructure;
	EndIf;
	
	SetDebugModeSettingsForStructure(ExchangeSettingsStructure);
	
	// Validating settings structure values for the exchange. Writing errors to the event log.
	CheckExchangeStructure(ExchangeSettingsStructure);
	
	// Canceling if settings contain errors
	If ExchangeSettingsStructure.Cancel Then
		Return ExchangeSettingsStructure;
	EndIf;
	
	// Initializing the exchange message transport data processor
	InitExchangeMessageTransportDataProcessor(ExchangeSettingsStructure);
	
	// Initializing the exchange data processor
	If ExchangeSettingsStructure.IsDIBExchange Then
		
		InitDataExchangeDataProcessor(ExchangeSettingsStructure);
		
	ElsIf ExchangeSettingsStructure.ExchangeByObjectConversionRules Then
		
		InitDataExchangeDataProcessorForConversionRules(ExchangeSettingsStructure);
		
	EndIf;
	
	Return ExchangeSettingsStructure;
EndFunction

// Retrieves a transport settings structure for performing the data exchange.
//
Function GetTransportSettingsStructure(InfobaseNode, ExchangeMessageTransportKind) Export
	
	// Return value
	ExchangeSettingsStructure = BaseExchangeSettingsStructure();
	
	ExchangeSettingsStructure.InfobaseNode          = InfobaseNode;
	ExchangeSettingsStructure.ActionOnExchange      = Enums.ActionsOnExchange.DataImport;
	ExchangeSettingsStructure.ExchangeTransportKind = ExchangeMessageTransportKind;
	
	InitExchangeSettingsStructureForInfobaseNode(ExchangeSettingsStructure, True);
	
	// Validating settings structure values for the exchange. Writing errors to the event log.
	CheckExchangeStructure(ExchangeSettingsStructure);
	
	// Canceling if settings contain errors
	If ExchangeSettingsStructure.Cancel Then
		Return ExchangeSettingsStructure;
	EndIf;
	
	// Initializing the exchange message transport data processor
	InitExchangeMessageTransportDataProcessor(ExchangeSettingsStructure);
	
	Return ExchangeSettingsStructure;
EndFunction

// For internal use.
// 
Procedure InitExchangeSettingsStructure(ExchangeSettingsStructure, ExchangeExecutionSettings, LineNumber)
	
	QueryText = "
	|SELECT
	|	ExchangeExecutionSettingsExchangeSettings.InfobaseNode          AS InfobaseNode,
	|	ExchangeExecutionSettingsExchangeSettings.InfobaseNode.Code     AS InfobaseNodeCode,
	|	ExchangeExecutionSettingsExchangeSettings.ExchangeTransportKind AS ExchangeTransportKind,
	|	ExchangeExecutionSettingsExchangeSettings.CurrentAction         AS ActionOnExchange,
	|	ExchangeExecutionSettingsExchangeSettings.Ref                   AS ExchangeExecutionSettings,
	|	ExchangeExecutionSettingsExchangeSettings.Ref.Description       AS ExchangeExecutionSettingsDescription,
	|	CASE
	|		WHEN ExchangeExecutionSettingsExchangeSettings.CurrentAction = VALUE(Enum.ActionsOnExchange.DataImport) THEN True
	|		ELSE False
	|	END                                                             AS DoDataImport,
	|	CASE
	|		WHEN ExchangeExecutionSettingsExchangeSettings.CurrentAction = VALUE(Enum.ActionsOnExchange.DataExport) THEN True
	|		ELSE False
	|	END                                                             AS DoDataExport
	|FROM
	|	Catalog.DataExchangeScenarios.ExchangeSettings AS ExchangeExecutionSettingsExchangeSettings
	|WHERE
	|	  ExchangeExecutionSettingsExchangeSettings.Ref          = &ExchangeExecutionSettings
	|	AND ExchangeExecutionSettingsExchangeSettings.LineNumber = &LineNumber
	|";
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("ExchangeExecutionSettings", ExchangeExecutionSettings);
	Query.SetParameter("LineNumber",                LineNumber);
	
	Selection = Query.Execute().Select();
	Selection.Next();
	
	// Filling structure property value
	FillPropertyValues(ExchangeSettingsStructure, Selection);
	
	ExchangeSettingsStructure.IsDIBExchange = DataExchangeCached.IsDistributedInfobaseNode(ExchangeSettingsStructure.InfobaseNode);
	
	ExchangeSettingsStructure.EventLogMessageKey = NStr("en = 'Data exchange'");
	
	// Checking whether basic exchange settings structure fields are filled
	CheckMainExchangeSettingsStructureFields(ExchangeSettingsStructure);
	
	If ExchangeSettingsStructure.Cancel Then
		Return;
	EndIf;
	
 
	ExchangeSettingsStructure.ExchangePlanName = ExchangeSettingsStructure.InfobaseNode.Metadata().Name;
	ExchangeSettingsStructure.ExchangeByObjectConversionRules = DataExchangeCached.IsUniversalDataExchangeNode(ExchangeSettingsStructure.InfobaseNode);
	
	ExchangeSettingsStructure.CurrentExchangePlanNode     = ExchangePlans[ExchangeSettingsStructure.ExchangePlanName].ThisNode();
	ExchangeSettingsStructure.CurrentExchangePlanNodeCode = ExchangeSettingsStructure.CurrentExchangePlanNode.Code;
	
	ExchangeSettingsStructure.DataExchangeMessageTransportDataProcessorName = DataExchangeMessageTransportDataProcessorName(ExchangeSettingsStructure.ExchangeTransportKind);
	
	// Getting the message key for the event log
	ExchangeSettingsStructure.EventLogMessageKey = GetEventLogMessageKey(ExchangeSettingsStructure.InfobaseNode, ExchangeSettingsStructure.ActionOnExchange);
	
 
	ExchangeSettingsStructure.TransportSettings = InformationRegisters.ExchangeTransportSettings.TransportSettings(ExchangeSettingsStructure.InfobaseNode, ExchangeSettingsStructure.ExchangeTransportKind);
	
	ExchangeSettingsStructure.TransactionItemCount = ItemCountInExecutingActionTransaction(ExchangeSettingsStructure.ActionOnExchange);
	
EndProcedure

// For internal use.
// 
Procedure InitExchangeSettingsStructureForInfobaseNode(
		ExchangeSettingsStructure,
		UseTransportSettings)
	
	PropertyStructure = CommonUse.ObjectAttributeValues(ExchangeSettingsStructure.InfobaseNode, "Code, Description");
	
	ExchangeSettingsStructure.InfobaseNodeCode        = PropertyStructure.Code;
	ExchangeSettingsStructure.InfobaseNodeDescription = PropertyStructure.Description;
	
	// Getting exchange transport settings
	ExchangeSettingsStructure.TransportSettings = InformationRegisters.ExchangeTransportSettings.TransportSettings(ExchangeSettingsStructure.InfobaseNode);
	
	If ExchangeSettingsStructure.TransportSettings <> Undefined Then
		
		If UseTransportSettings Then
			
			// Using the default value if the transport kind is not specified
			If ExchangeSettingsStructure.ExchangeTransportKind = Undefined Then
				ExchangeSettingsStructure.ExchangeTransportKind  = ExchangeSettingsStructure.TransportSettings.DefaultExchangeMessageTransportKind;
			EndIf;
			
			// Using the FILE transport if the transport kind is not specified
			If Not ValueIsFilled(ExchangeSettingsStructure.ExchangeTransportKind) Then
				
				ExchangeSettingsStructure.ExchangeTransportKind = Enums.ExchangeMessageTransportKinds.FILE;
				
			EndIf;
			
			ExchangeSettingsStructure.DataExchangeMessageTransportDataProcessorName = DataExchangeMessageTransportDataProcessorName(ExchangeSettingsStructure.ExchangeTransportKind);
			
		EndIf;
		
		ExchangeSettingsStructure.TransactionItemCount = ?(ExchangeSettingsStructure.ActionOnExchange = Enums.ActionsOnExchange.DataImport,
									ExchangeSettingsStructure.TransportSettings.DataImportTransactionItemCount,
									ExchangeSettingsStructure.TransportSettings.DataExportTransactionItemCount);
		
		If ExchangeSettingsStructure.TransportSettings.Property("WSUseLargeDataTransfer") Then
			ExchangeSettingsStructure.UseLargeDataTransfer = ExchangeSettingsStructure.TransportSettings.WSUseLargeDataTransfer;
		EndIf;
		
	EndIf;
	
	// DEFAULT VALUES
	ExchangeSettingsStructure.ExchangeExecutionSettings            = Undefined;
	ExchangeSettingsStructure.ExchangeExecutionSettingsDescription = "";
	
	// CALCULATED VALUES
	ExchangeSettingsStructure.DoDataImport = (ExchangeSettingsStructure.ActionOnExchange = Enums.ActionsOnExchange.DataImport);
	ExchangeSettingsStructure.DoDataExport = (ExchangeSettingsStructure.ActionOnExchange = Enums.ActionsOnExchange.DataExport);
	
	ExchangeSettingsStructure.ExchangePlanName = ExchangeSettingsStructure.InfobaseNode.Metadata().Name;
	ExchangeSettingsStructure.ExchangeByObjectConversionRules = DataExchangeCached.IsUniversalDataExchangeNode(ExchangeSettingsStructure.InfobaseNode);
	
	ExchangeSettingsStructure.CurrentExchangePlanNode     = ExchangePlans[ExchangeSettingsStructure.ExchangePlanName].ThisNode();
	ExchangeSettingsStructure.CurrentExchangePlanNodeCode = ExchangeSettingsStructure.CurrentExchangePlanNode.Code;
	
	// Getting the message key for the event log
	ExchangeSettingsStructure.EventLogMessageKey = GetEventLogMessageKey(ExchangeSettingsStructure.InfobaseNode, ExchangeSettingsStructure.ActionOnExchange);
	
EndProcedure

// For internal use.
// 
Function BaseExchangeSettingsStructure()
	
	ExchangeSettingsStructure = New Structure;
	
	// Structure of settings by query fields
	
	ExchangeSettingsStructure.Insert("StartDate");
	ExchangeSettingsStructure.Insert("EndDate");
	
	ExchangeSettingsStructure.Insert("LineNumber");
	ExchangeSettingsStructure.Insert("ExchangeExecutionSettings");
	ExchangeSettingsStructure.Insert("ExchangeExecutionSettingsDescription");
	ExchangeSettingsStructure.Insert("InfobaseNode");
	ExchangeSettingsStructure.Insert("InfobaseNodeCode", "");
	ExchangeSettingsStructure.Insert("InfobaseNodeDescription", "");
	ExchangeSettingsStructure.Insert("ExchangeTransportKind");
	ExchangeSettingsStructure.Insert("ActionOnExchange");
	ExchangeSettingsStructure.Insert("TransactionItemCount", 1); // each item requires a single transaction
	ExchangeSettingsStructure.Insert("DoDataImport", False);
	ExchangeSettingsStructure.Insert("DoDataExport", False);
	ExchangeSettingsStructure.Insert("UseLargeDataTransfer", False);
	
	// Additional settings structure
	ExchangeSettingsStructure.Insert("Cancel", False);
	ExchangeSettingsStructure.Insert("IsDIBExchange", False);
	
	ExchangeSettingsStructure.Insert("DataExchangeDataProcessor");
	ExchangeSettingsStructure.Insert("ExchangeMessageTransportDataProcessor");
	
	ExchangeSettingsStructure.Insert("ExchangePlanName");
	ExchangeSettingsStructure.Insert("CurrentExchangePlanNode");
	ExchangeSettingsStructure.Insert("CurrentExchangePlanNodeCode");
	
	ExchangeSettingsStructure.Insert("ExchangeByObjectConversionRules", False);
	
	ExchangeSettingsStructure.Insert("DataExchangeMessageTransportDataProcessorName");
	
	ExchangeSettingsStructure.Insert("EventLogMessageKey");
	
	ExchangeSettingsStructure.Insert("TransportSettings");
	
	ExchangeSettingsStructure.Insert("ObjectConversionRules");
	ExchangeSettingsStructure.Insert("RulesLoaded", False);
	
	ExchangeSettingsStructure.Insert("ExportHandlerDebug ", False);
	ExchangeSettingsStructure.Insert("ImportHandlerDebug",  False);
	ExchangeSettingsStructure.Insert("ExportDebugExternalDataProcessorFileName", "");
	ExchangeSettingsStructure.Insert("ImportDebugExternalDataProcessorFileName", "");
	ExchangeSettingsStructure.Insert("DataExchangeLoggingMode", False);
	ExchangeSettingsStructure.Insert("ExchangeLogFileName", "");
	ExchangeSettingsStructure.Insert("ContinueOnError", False);
	
	// Structure for writing event messages to the event log
	ExchangeSettingsStructure.Insert("ExchangeExecutionResult");
	ExchangeSettingsStructure.Insert("ActionOnExchange");
	ExchangeSettingsStructure.Insert("ProcessedObjectCount", 0);
	ExchangeSettingsStructure.Insert("ExchangeMessage",      "");
	ExchangeSettingsStructure.Insert("ErrorMessageString",   "");
	
	Return ExchangeSettingsStructure;
EndFunction

// For internal use.
// 
Procedure CheckMainExchangeSettingsStructureFields(ExchangeSettingsStructure)
	
	If Not ValueIsFilled(ExchangeSettingsStructure.InfobaseNode) Then
		
		// The infobase node must be specified
		ErrorMessageString = NStr(
		"en = 'The infobase node to exchange with is not specified. The exchange is canceled.'",
			CommonUseClientServer.DefaultLanguageCode());
		WriteEventLogDataExchange(ErrorMessageString, ExchangeSettingsStructure, True);
		SetExchangeInitEnd(ExchangeSettingsStructure);
		
	ElsIf Not ValueIsFilled(ExchangeSettingsStructure.ExchangeTransportKind) Then
		
		ErrorMessageString = NStr("en = 'The exchange transport kind is not specified. The exchange is canceled.'",
			CommonUseClientServer.DefaultLanguageCode());
		WriteEventLogDataExchange(ErrorMessageString, ExchangeSettingsStructure, True);
		
		SetExchangeInitEnd(ExchangeSettingsStructure);
		
	ElsIf Not ValueIsFilled(ExchangeSettingsStructure.ActionOnExchange) Then
		
		ErrorMessageString = NStr("en = 'The action to be executed (import or export) is not specified. The exchange is canceled.'",
			CommonUseClientServer.DefaultLanguageCode());
		WriteEventLogDataExchange(ErrorMessageString, ExchangeSettingsStructure, True);
		
		SetExchangeInitEnd(ExchangeSettingsStructure);
		
	EndIf;
	
EndProcedure

// For internal use.
// 
Procedure CheckExchangeStructure(ExchangeSettingsStructure, UseTransportSettings = True)
	
	If Not ValueIsFilled(ExchangeSettingsStructure.InfobaseNode) Then
		
		// The infobase node must be specified
		ErrorMessageString = NStr(
		"en = 'The infobase node to exchange with is not specified. The exchange is canceled.'",
			CommonUseClientServer.DefaultLanguageCode());
		WriteEventLogDataExchange(ErrorMessageString, ExchangeSettingsStructure, True);
		SetExchangeInitEnd(ExchangeSettingsStructure);
		
	ElsIf UseTransportSettings And Not ValueIsFilled(ExchangeSettingsStructure.ExchangeTransportKind) Then
		
		ErrorMessageString = NStr("en = 'The exchange transport kind is not specified. The exchange is canceled.'",
			CommonUseClientServer.DefaultLanguageCode());
		WriteEventLogDataExchange(ErrorMessageString, ExchangeSettingsStructure, True);
		
		SetExchangeInitEnd(ExchangeSettingsStructure);
		
	ElsIf Not ValueIsFilled(ExchangeSettingsStructure.ActionOnExchange) Then
		
		ErrorMessageString = NStr("en = 'The action to be executed (import or export) is not specified. The exchange is canceled.'",
			CommonUseClientServer.DefaultLanguageCode());
		WriteEventLogDataExchange(ErrorMessageString, ExchangeSettingsStructure, True);
		
		SetExchangeInitEnd(ExchangeSettingsStructure);
		
	ElsIf ExchangeSettingsStructure.InfobaseNode.DeletionMark Then
		
		// The infobase node cannot be marked for deletion
		ErrorMessageString = NStr("en = 'The infobase is marked for deletion. The exchange is canceled.'",
			CommonUseClientServer.DefaultLanguageCode());
		WriteEventLogDataExchange(ErrorMessageString, ExchangeSettingsStructure, True);
		
		SetExchangeInitEnd(ExchangeSettingsStructure);
	
	ElsIf ExchangeSettingsStructure.InfobaseNode = ExchangeSettingsStructure.CurrentExchangePlanNode Then
		
		// The exchange with the current infobase node cannot be provided
		ErrorMessageString = NStr(
		"en = 'The exchange with the current infobase node cannot be provided. The exchange is canceled.'",
			CommonUseClientServer.DefaultLanguageCode());
		WriteEventLogDataExchange(ErrorMessageString, ExchangeSettingsStructure, True);
		
		SetExchangeInitEnd(ExchangeSettingsStructure);
	
	ElsIf IsBlankString(ExchangeSettingsStructure.InfobaseNodeCode)
		  Or IsBlankString(ExchangeSettingsStructure.CurrentExchangePlanNodeCode) Then
		
		// The infobase codes must be specified
		ErrorMessageString = NStr("en = 'One of exchange nodes has an empty code. The exchange is canceled.'",
			CommonUseClientServer.DefaultLanguageCode());
		WriteEventLogDataExchange(ErrorMessageString, ExchangeSettingsStructure, True);
		
		SetExchangeInitEnd(ExchangeSettingsStructure);
		
	ElsIf ExchangeSettingsStructure.ExportHandlerDebug Then
		
		ExportDataProcessorFile = New File(ExchangeSettingsStructure.ExportDebugExternalDataProcessorFileName);
		
		If Not ExportDataProcessorFile.Exist() Then
			
			ErrorMessageString = NStr("en = 'External data processor file for the export debugging does not exists. The exchange is canceled.'",
				CommonUseClientServer.DefaultLanguageCode());
			WriteEventLogDataExchange(ErrorMessageString, ExchangeSettingsStructure, True);
			
			SetExchangeInitEnd(ExchangeSettingsStructure);
			
		EndIf;
		
	ElsIf ExchangeSettingsStructure.ImportHandlerDebug Then
		
		ImportDataProcessorFile = New File(ExchangeSettingsStructure.ImportDebugExternalDataProcessorFileName);
		
		If Not ImportDataProcessorFile.Exist() Then
			
			ErrorMessageString = NStr("en = 'External data processor file for the import debugging does not exists. The exchange is canceled.'",
				CommonUseClientServer.DefaultLanguageCode());
			WriteEventLogDataExchange(ErrorMessageString, ExchangeSettingsStructure, True);
			
			SetExchangeInitEnd(ExchangeSettingsStructure);
			
		EndIf;
		
	EndIf;
	
EndProcedure

// For internal use.
// 
Procedure InitDataExchangeDataProcessor(ExchangeSettingsStructure)
	
	// Canceling initialization if settings contain errors
	If ExchangeSettingsStructure.Cancel Then
		Return;
	EndIf;
	
	// Creating the data processor
	DataExchangeDataProcessor = DataProcessors.DistributedInfobaseObjectsConversion.Create();
	
	// Initializing properties
	DataExchangeDataProcessor.InfobaseNode         = ExchangeSettingsStructure.InfobaseNode;
	DataExchangeDataProcessor.TransactionItemCount = ExchangeSettingsStructure.TransactionItemCount;
	DataExchangeDataProcessor.EventLogMessageKey   = ExchangeSettingsStructure.EventLogMessageKey;
	
	ExchangeSettingsStructure.Insert("DataExchangeDataProcessor", DataExchangeDataProcessor);
	
EndProcedure

// For internal use.
// 
Procedure InitDataExchangeDataProcessorForConversionRules(ExchangeSettingsStructure)
	
	Var DataExchangeDataProcessor;
	
	// Canceling initialization if settings contain errors
	If ExchangeSettingsStructure.Cancel Then
		Return;
	EndIf;
	
	If ExchangeSettingsStructure.DoDataExport Then
		
		DataExchangeDataProcessor = GetDataExchangeExportDataProcessor(ExchangeSettingsStructure);
		
	ElsIf ExchangeSettingsStructure.DoDataImport Then
		
		DataExchangeDataProcessor = GetDataExchangeImportDataProcessor(ExchangeSettingsStructure);
		
	EndIf;
	
	ExchangeSettingsStructure.Insert("DataExchangeDataProcessor", DataExchangeDataProcessor);
	
EndProcedure

// For internal use.
// 
Procedure InitExchangeMessageTransportDataProcessor(ExchangeSettingsStructure)
	
	// Creating the transport data processor
	ExchangeMessageTransportDataProcessor = DataProcessors[ExchangeSettingsStructure.DataExchangeMessageTransportDataProcessorName].Create();
	
	IsOutgoingMessage = ExchangeSettingsStructure.DoDataExport;
	
	// Filling common attributes (same for all transport data processors)
	ExchangeMessageTransportDataProcessor.MessageFileNamePattern = GetMessageFileNamePattern(ExchangeSettingsStructure.CurrentExchangePlanNode, ExchangeSettingsStructure.InfobaseNode, IsOutgoingMessage);
	
	// Filling transport settings (various for each transport data processor)
	FillPropertyValues(ExchangeMessageTransportDataProcessor, ExchangeSettingsStructure.TransportSettings);
	
	// Initialing transport
	ExchangeMessageTransportDataProcessor.Initialization();
	
	ExchangeSettingsStructure.Insert("ExchangeMessageTransportDataProcessor", ExchangeMessageTransportDataProcessor);
	
EndProcedure

// For internal use.
// 
Function GetDataExchangeExportDataProcessor(ExchangeSettingsStructure)
	
	DataProcessorManager = DataProcessors.InfobaseObjectConversion;
	
	If CommonUse.SubsystemExists("DataExchangeXDTO") Then
		
		DataExchangeXDTOCachedModule = CommonUse.CommonModule("DataExchangeXDTOCached");
		DataExchangeXDTOServerModule = CommonUse.CommonModule("DataExchangeXDTOServer");
		
		If DataExchangeXDTOCachedModule.IsXDTOExchangePlan(ExchangeSettingsStructure.InfobaseNode) Then
			DataProcessorManager = DataExchangeXDTOServerModule.DataConversionDataProcessorForUniversalExchange();
		EndIf;
		
	EndIf;
	
	DataExchangeDataProcessor = DataProcessorManager.Create();
	
	DataExchangeDataProcessor.ExchangeMode = "Data";
	
	// If the data processor supports the conversion rule mechanism, the following actions can be executed
	If DataExchangeDataProcessor.Metadata().Attributes.Find("ExchangeRuleFileName") <> Undefined Then
		SetDataExportExchangeRules(DataExchangeDataProcessor, ExchangeSettingsStructure);
		DataExchangeDataProcessor.DontExportObjectsByRefs = True;
		DataExchangeDataProcessor.ExchangeRuleFileName    = "1";
	EndIf;
	
	// If the data processor supports the background exchange, the following actions can be executed
	If DataExchangeDataProcessor.Metadata().Attributes.Find("BackgroundExchangeNode") <> Undefined Then
		DataExchangeDataProcessor.BackgroundExchangeNode = Undefined;
	EndIf;
		
	DataExchangeDataProcessor.NodeForExchange = ExchangeSettingsStructure.InfobaseNode;
	
	SetCommonParametersForDataExchangeProcessing(DataExchangeDataProcessor, ExchangeSettingsStructure);
	
	Return DataExchangeDataProcessor;
	
EndFunction

// For internal use.
// 
Function GetDataExchangeImportDataProcessor(ExchangeSettingsStructure)
	
	DataProcessorManager = DataProcessors.InfobaseObjectConversion;
	
	If CommonUse.SubsystemExists("DataExchangeXDTO") Then
		
		DataExchangeXDTOCachedModule = CommonUse.CommonModule("DataExchangeXDTOCached");
		DataExchangeXDTOServerModule = CommonUse.CommonModule("DataExchangeXDTOServer");
		
		If DataExchangeXDTOCachedModule.IsXDTOExchangePlan(ExchangeSettingsStructure.InfobaseNode) Then
			DataProcessorManager = DataExchangeXDTOServerModule.DataConversionDataProcessorForUniversalExchange();
		EndIf;
		
	EndIf;
	
	DataExchangeDataProcessor = DataProcessorManager.Create();
	
	DataExchangeDataProcessor.ExchangeMode = "Import";
	DataExchangeDataProcessor.ExchangeNodeDataImport = ExchangeSettingsStructure.InfobaseNode;
	
	If DataExchangeDataProcessor.Metadata().Attributes.Find("ExchangeRuleFileName") <> Undefined Then
		SetDataImportExchangeRules(DataExchangeDataProcessor, ExchangeSettingsStructure);
	EndIf;
	
	SetCommonParametersForDataExchangeProcessing(DataExchangeDataProcessor, ExchangeSettingsStructure);
	
	Return DataExchangeDataProcessor
	
EndFunction

// For internal use.
// 
Procedure SetCommonParametersForDataExchangeProcessing(DataExchangeDataProcessor, ExchangeSettingsStructure, ExchangeWithSL20 = False)
	
	DataExchangeDataProcessor.AppendDataToExchangeLog = False;
	DataExchangeDataProcessor.ExportAllowedOnly       = False;
	
	DataExchangeDataProcessor.UseTransactions           = ExchangeSettingsStructure.TransactionItemCount <> 1;
	DataExchangeDataProcessor.ObjectCountPerTransaction = ExchangeSettingsStructure.TransactionItemCount;
	
	DataExchangeDataProcessor.EventLogMessageKey = ExchangeSettingsStructure.EventLogMessageKey;
	
	If Not ExchangeWithSL20 Then
		
		SetDebugModeSettingsForDataProcessor(DataExchangeDataProcessor, ExchangeSettingsStructure);
		
	EndIf;
	
EndProcedure

Procedure SetDataExportExchangeRules(DataExchangeXMLDataProcessor, ExchangeSettingsStructure)
	
	ObjectConversionRules = InformationRegisters.DataExchangeRules.GetReadObjectConversionRules(ExchangeSettingsStructure.ExchangePlanName);
	
	If ObjectConversionRules = Undefined Then
		
		// Exchange rules must be specified
		NString = NStr("en = 'Conversion rules for the %1 exchange plan is not specified. The data export has been canceled.'",
			CommonUseClientServer.DefaultLanguageCode());
		ErrorMessageString = StringFunctionsClientServer.SubstituteParametersInString(NString, ExchangeSettingsStructure.ExchangePlanName);
		WriteEventLogDataExchange(ErrorMessageString, ExchangeSettingsStructure, True);
		SetExchangeInitEnd(ExchangeSettingsStructure);
		
		Return;
	EndIf;
	
	DataExchangeXMLDataProcessor.SavedSettings = ObjectConversionRules;
	
	Try
		DataExchangeXMLDataProcessor.RestoreRulesFromInternalFormat();
	Except
		WriteEventLogDataExchange(BriefErrorDescription(ErrorInfo()), ExchangeSettingsStructure, True);
		SetExchangeInitEnd(ExchangeSettingsStructure);
		Return;
	EndTry;
	
EndProcedure

Procedure SetDataImportExchangeRules(DataExchangeXMLDataProcessor, ExchangeSettingsStructure)
	
	ObjectConversionRules = InformationRegisters.DataExchangeRules.GetReadObjectConversionRules(ExchangeSettingsStructure.ExchangePlanName, True);
	
	If ObjectConversionRules = Undefined Then
		
		// Exchange rules must be specified
		NString = NStr("en = 'Conversion rules for the %1 exchange plan is not specified. Data import is cancelled.'",
			CommonUseClientServer.DefaultLanguageCode());
		ErrorMessageString = StringFunctionsClientServer.SubstituteParametersInString(NString, ExchangeSettingsStructure.ExchangePlanName);
		WriteEventLogDataExchange(ErrorMessageString, ExchangeSettingsStructure, True);
		SetExchangeInitEnd(ExchangeSettingsStructure);
		
		Return;
	EndIf;
	
	DataExchangeXMLDataProcessor.SavedSettings = ObjectConversionRules;
	
	Try
		DataExchangeXMLDataProcessor.RestoreRulesFromInternalFormat();
	Except
		WriteEventLogDataExchange(BriefErrorDescription(ErrorInfo()), ExchangeSettingsStructure, True);
		SetExchangeInitEnd(ExchangeSettingsStructure);
		Return;
	EndTry;
	
EndProcedure

// Reads debug settings from the infobase and fills the exchange structure with read values.
//
Procedure SetDebugModeSettingsForStructure(ExchangeSettingsStructure, IsExternalConnection = False)
	
	QueryText = "SELECT
	|	CASE
	|		WHEN &PerformDataExport
	|			THEN DataExchangeRules.ExportDebugMode
	|		ELSE FALSE
	|	END AS ExportHandlerDebug,
	|	CASE
	|		WHEN &PerformDataExport
	|			THEN DataExchangeRules.ExportDebuggingDataProcessorFileName
	|		ELSE """"
	|	END AS ExportDebugExternalDataProcessorFileName,
	|	CASE
	|		WHEN &PerformImport
	|			THEN DataExchangeRules.ImportDebugMode
	|		ELSE FALSE
	|	END AS ImportHandlerDebug,
	|	CASE
	|		WHEN &PerformImport
	|			THEN DataExchangeRules.ImportDebuggingDataProcessorFileName
	|		ELSE """"
	|	END AS ImportDebugExternalDataProcessorFileName,
	|	DataExchangeRules.DataExchangeLoggingMode AS DataExchangeLoggingMode,
	|	DataExchangeRules.ExchangeLogFileName AS ExchangeLogFileName,
	|	DataExchangeRules.DontStopOnError AS ContinueOnError
	|FROM
	|	InformationRegister.DataExchangeRules AS DataExchangeRules
	|WHERE
	|	DataExchangeRules.ExchangePlanName = &ExchangePlanName
	|	AND DataExchangeRules.RuleKind = VALUE(Enum.DataExchangeRuleKinds.ObjectConversionRules)
	|	AND DataExchangeRules.DebugMode";
	
	Query = New Query;
	Query.Text = QueryText;
	
	DoDataExport = False;
	If Not ExchangeSettingsStructure.Property("DoDataExport", DoDataExport) Then
		DoDataExport = (ExchangeSettingsStructure.ActionOnExchange = Enums.ActionsOnExchange.DataExport);
	EndIf;
	
	DoDataImport = False;
	If Not ExchangeSettingsStructure.Property("DoDataImport", DoDataImport) Then
		DoDataImport = (ExchangeSettingsStructure.ActionOnExchange = Enums.ActionsOnExchange.DataImport);
	EndIf;
	
	Query.SetParameter("ExchangePlanName",  ExchangeSettingsStructure.ExchangePlanName);
	Query.SetParameter("PerformDataExport", DoDataExport);
	Query.SetParameter("PerformImport",     DoDataImport);
	
	Result = Query.Execute();
	
	LogFileName = "";
	If IsExternalConnection And ExchangeSettingsStructure.Property("ExchangeLogFileName", LogFileName)
		And Not IsBlankString(LogFileName) Then
		
		ExchangeSettingsStructure.ExchangeLogFileName = AddLiteralToFileName(LogFileName, "ExternalConnection")
	
	EndIf;
	
	If Not Result.IsEmpty() And Not CommonUseCached.DataSeparationEnabled() Then
		
		SettingsTable = Result.Unload();
		TableRow = SettingsTable[0];
		
		FillPropertyValues(ExchangeSettingsStructure, TableRow);
		
	EndIf;
	
EndProcedure

// Reads debug settings from the infobase and the passed structure with read settings.
//
Procedure SetDebugModeSettingsForDataProcessor(DataExchangeDataProcessor, ExchangeSettingsStructure)
	
	If ExchangeSettingsStructure.Property("ExportDebugExternalDataProcessorFileName")
		And DataExchangeDataProcessor.Metadata().Attributes.Find("ExportDebugExternalDataProcessorFileName") <> Undefined Then
		
		DataExchangeDataProcessor.ExportHandlerDebug = ExchangeSettingsStructure.ExportHandlerDebug;
		DataExchangeDataProcessor.ImportHandlerDebug = ExchangeSettingsStructure.ImportHandlerDebug;
		DataExchangeDataProcessor.ExportDebugExternalDataProcessorFileName = ExchangeSettingsStructure.ExportDebugExternalDataProcessorFileName;
		DataExchangeDataProcessor.ImportDebugExternalDataProcessorFileName = ExchangeSettingsStructure.ImportDebugExternalDataProcessorFileName;
		DataExchangeDataProcessor.DataExchangeLoggingMode = ExchangeSettingsStructure.DataExchangeLoggingMode;
		DataExchangeDataProcessor.ExchangeLogFileName = ExchangeSettingsStructure.ExchangeLogFileName;
		DataExchangeDataProcessor.ContinueOnError = ExchangeSettingsStructure.ContinueOnError;
		
		If ExchangeSettingsStructure.DataExchangeLoggingMode Then
			
			If ExchangeSettingsStructure.ExchangeLogFileName = "" Then
				DataExchangeDataProcessor.OutputInfoMessagesToMessageWindow = True;
				DataExchangeDataProcessor.WriteInfoMessagesToLog = False;
			Else
				DataExchangeDataProcessor.OutputInfoMessagesToMessageWindow = False;
				DataExchangeDataProcessor.WriteInfoMessagesToLog = True;
				DataExchangeDataProcessor.ExchangeLogFileName = ExchangeSettingsStructure.ExchangeLogFileName;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Sets up export settings for the data processor.
//
Procedure SetExportDebugSettingsForExchangeRules(DataExchangeDataProcessor, ExchangePlanName, DebugMode) Export
	
	QueryText = "SELECT
	|	DataExchangeRules.ExportDebugMode AS ExportHandlerDebug,
	|	DataExchangeRules.ExportDebuggingDataProcessorFileName AS ExportDebugExternalDataProcessorFileName
	|FROM
	|	InformationRegister.DataExchangeRules AS DataExchangeRules
	|WHERE
	|	DataExchangeRules.ExchangePlanName = &ExchangePlanName
	|	AND DataExchangeRules.RuleKind = VALUE(Enum.DataExchangeRuleKinds.ObjectConversionRules)
	|	AND &DebugMode = True";
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("ExchangePlanName", ExchangePlanName);
	Query.SetParameter("DebugMode", DebugMode);
	
	Result = Query.Execute();
	
	If Result.IsEmpty() Or CommonUseCached.DataSeparationEnabled() Then
		
		DataExchangeDataProcessor.ExportHandlerDebug = False;
		DataExchangeDataProcessor.ExportDebugExternalDataProcessorFileName = "";
		
	Else
		
		SettingsTable = Result.Unload();
		DebuggingSettings = SettingsTable[0];
		
		FillPropertyValues(DataExchangeDataProcessor, DebuggingSettings);
		
	EndIf;
	
EndProcedure

// Sets up import settings for the data processor.
//
Procedure SetImportDebugSettingsForExchangeRules(DataExchangeDataProcessor, ExchangePlanName) Export
	
	QueryText = "SELECT
	|	DataExchangeRules.ImportDebugMode AS ImportHandlerDebug,
	|	DataExchangeRules.ImportDebuggingDataProcessorFileName AS ImportDebugExternalDataProcessorFileName
	|FROM
	|	InformationRegister.DataExchangeRules AS DataExchangeRules
	|WHERE
	|	DataExchangeRules.ExchangePlanName = &ExchangePlanName
	|	AND DataExchangeRules.RuleKind = VALUE(Enum.DataExchangeRuleKinds.ObjectConversionRules)
	|	AND DataExchangeRules.DebugMode";
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("ExchangePlanName", ExchangePlanName);
	
	Result = Query.Execute();
	
	If Result.IsEmpty() Or CommonUseCached.DataSeparationEnabled() Then
		
		DataExchangeDataProcessor.ImportHandlerDebug = False;
		DataExchangeDataProcessor.ImportDebugExternalDataProcessorFileName = "";
		
	Else
		
		SettingsTable = Result.Unload();
		DebuggingSettings = SettingsTable[0];
		
		FillPropertyValues(DataExchangeDataProcessor, DebuggingSettings);
		
	EndIf;
	
EndProcedure

// For internal use.
// 
Procedure SetExchangeInitEnd(ExchangeSettingsStructure)
	
	ExchangeSettingsStructure.Cancel = True;
	ExchangeSettingsStructure.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Canceled;
	
EndProcedure

// For internal use.
// 
Function GetMessageFileNamePattern(CurrentExchangePlanNode, InfobaseNode, IsOutgoingMessage)
	
	SenderNode    = ?(IsOutgoingMessage, CurrentExchangePlanNode, InfobaseNode);
	RecipientNode = ?(IsOutgoingMessage, InfobaseNode, CurrentExchangePlanNode);
	
	Return ExchangeMessageFileName(TrimAll(CommonUse.ObjectAttributeValue(SenderNode, "Code")),
									TrimAll(CommonUse.ObjectAttributeValue(RecipientNode, "Code")));
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Transaction item count.

Function DataImportTransactionItemCount() Export
	
	SetPrivilegedMode(True);
	Return Constants.DataImportTransactionItemCount.Get();
	
EndFunction

Function DataExportTransactionItemCount() Export
	
	Return 1;
	
EndFunction

Function ItemCountInExecutingActionTransaction(Action)
	
	If Action = Enums.ActionsOnExchange.DataExport Then
		ItemCount = DataExportTransactionItemCount();
	Else
		ItemCount = DataImportTransactionItemCount();
	EndIf;
	
	Return ItemCount;
	
EndFunction

Procedure SetDataImportTransactionItemNumber(Quantity) Export
	
	SetPrivilegedMode(True);
	Constants.DataImportTransactionItemCount.Set(Quantity);
	
EndProcedure

Procedure AddTransactionItemCountToTransportSettings(Result) Export
	
	Result.Insert("DataExportTransactionItemCount", DataExportTransactionItemCount());
	Result.Insert("DataImportTransactionItemCount", DataImportTransactionItemCount());
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for operating with the data exchange issue monitor.

// For internal use.
// 
Function DataExchangeIssueCount(ExchangeNodes = Undefined, ProblemType = Undefined,
	IncludingIgnored = False, Period = Undefined, SearchString = "") Export
	
	Return InformationRegisters.DataExchangeResults.IssueCount(ExchangeNodes,
		ProblemType, IncludingIgnored, Period, SearchString);
	
EndFunction

// For internal use.
// 
Function VersioningIssueCount(ExchangeNodes = Undefined, IsConflictCount = Undefined,
	IncludingIgnored = False, Period = Undefined, SearchString = "") Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.ObjectVersioning") Then
		ObjectVersioningModule = CommonUse.CommonModule("ObjectVersioning");
		Return ObjectVersioningModule.ConflictOrRejectedItemCount(ExchangeNodes,
			IsConflictCount, IncludingIgnored, Period, SearchString);
	EndIf;
		
	Return 0;
	
EndFunction

// Registers errors that occurs during the deffered document posting, in the exchange issue monitor.
//
// Parameters:
//   Object       - DocumentObject - errors occurred during deffered posting of this document.
//   ExchangeNode - ExchangePlanRef - infobase node where from the document is received.
//   ErrorMessage - error message for the event log.
//
// Note: ErrorMessage contains the error message text for the event log.
// We recommend you fill this parameter value with the result of BriefErrorDescription(ErrorInfo()).
// Message text to display in the monitor is compiled from
// system user messages that are generated but are not displayed to a user yet. 
// Therefore, we recommend you to delete cached messages before calling this method.
//
// Example of the procedure call when a document is imported to the infobase:
//
// Procedure PostDocumentOnImport(Document,
// ExchangeNode) Document.DataExchange.Load = True;
// Document.Write();
// Document.DataExchange.Load = False;
// Cancel = False;
//
// Try
// 	Document.Save(DocumentWriteMode.Posting);
// Except
// 	ErrorMessage = BriefErrorDescription(ErrorInfo());
// 	Cancel = True;
// EndTry;
//
// If Cancel
// 	Then RecordDocumentPostingError(Document, ExchangeNode, ErrorMessage);
// EndIf;
//
// EndProcedure;
//
Procedure RecordDocumentPostingError(Object, ExchangeNode, ErrorMessage) Export
	
	UserMessages = GetUserMessages(True);
	MessageText  = ErrorMessage;
	For Each Message In UserMessages Do
		MessageText = MessageText + ?(IsBlankString(MessageText), "", Chars.LF) + Message.Text;
	EndDo;
	
	ErrorReason = MessageText;
	If Not IsBlankString(TrimAll(MessageText)) Then
		
		ErrorReason = NStr("en = ' The error occurred due to %1.'");
		ErrorReason = StringFunctionsClientServer.SubstituteParametersInString(ErrorReason, MessageText);
		
	EndIf;
	
	MessageString = NStr("en = 'Cannot post the %1 document that is received from the other infobase.%2
		|Perhaps mandatory attributes are not filled.'",
		CommonUseClientServer.DefaultLanguageCode());
	MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, String(Object), ErrorReason);
	
	WriteLogEvent(EventLogMessageTextDataExchange(), EventLogLevel.Warning,,, MessageString);
	
	InformationRegisters.DataExchangeResults.RecordDocumentCheckError(Object.Ref, ExchangeNode,
		MessageText, Enums.DataExchangeProblemTypes.UnpostedDocument);
	
EndProcedure

// Registers errors of the deffered object writing in the exchange issue monitor.
//
// Parameters:
//   Object       - Object of reference type - errors occurred during deffered writing
//                  of this object. 
//   ExchangeNode - ExchangePlanRef - infobase node from which the object is received. 
//   ErrorMessage - error message for the event log.
//
// Note: ErrorMessage contains the error message text for the event log.
// We recommend you fill this parameter value with the result of BriefErrorDescription(ErrorInfo()).
// Message text to display in the monitor is compiled from
// system user messages that are generated but are not displayed to a user yet.
// Therefore, we recommend you to delete cached messages before calling this method.
//
// Example of the procedure call during the object writing  to the infobase:
//
// Procedure WriteObjectOnImport(Object,
// ExchangeNode) Object.DataExchange.Load = True;
// Object.Write();
// Object.DataExchange.Load = False;
// Cancel = False;
//
// Try
// 	Object Record();
// Except
// 	ErrorMessage = BriefErrorDescription(ErrorInfo());
// 	Cancel = True;
// EndTry;
//
// If Cancel
// 	Then RecordObjectWriteError(Object, ExchangeNode, ErrorMessage);
// EndIf;
//
// EndProcedure;
//
Procedure RecordObjectWriteError(Object, ExchangeNode, ErrorMessage) Export
	
	UserMessages = GetUserMessages(True);
	MessageText  = ErrorMessage;
	For Each Message In UserMessages Do
		MessageText = MessageText + ?(IsBlankString(MessageText), "", Chars.LF) + Message.Text;
	EndDo;
	
	ErrorReason = MessageText;
	If Not IsBlankString(TrimAll(MessageText)) Then
		
		ErrorReason = NStr("en = ' The error occurred due to %1.'");
		ErrorReason = StringFunctionsClientServer.SubstituteParametersInString(ErrorReason, MessageText);
		
	EndIf;
	
	MessageString = NStr("en = 'Cannot write the %1 object that is received from the other infobase.%2
		|Perhaps mandatory attributes are not filled.'",
		CommonUseClientServer.DefaultLanguageCode());
	MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, String(Object), ErrorReason);
	
	WriteLogEvent(EventLogMessageTextDataExchange(), EventLogLevel.Warning,,, MessageString);
	
	InformationRegisters.DataExchangeResults.RecordDocumentCheckError(Object.Ref, ExchangeNode,
		MessageText, Enums.DataExchangeProblemTypes.BlankAttributes);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// COMMON PROCEDURES AND FUNCTIONS.

// For internal use.
// 
Function QueryResultToStructure(Val QueryResult) Export
	
	Result = New Structure;
	For Each Column In QueryResult.Columns Do
		Result.Insert(Column.Name);
	EndDo;
	
	If QueryResult.IsEmpty() Then
		Return Result;
	EndIf;
	
	Selection = QueryResult.Select();
	Selection.Next();
	
	FillPropertyValues(Result, Selection);
	
	Return Result;
EndFunction

// For internal use.
// 
Function ValueTableFromValueTree(Tree)
	
	Result = New ValueTable;
	
	For Each Column In Tree.Columns Do
		
		Result.Columns.Add(Column.Name, Column.ValueType);
		
	EndDo;
	
	ExpandValueTree(Result, Tree.Rows);
	
	Return Result;
EndFunction

// For internal use.
// 
Procedure ExpandValueTree(Table, Tree)
	
	For Each TreeRow In Tree Do
		
		FillPropertyValues(Table.Add(), TreeRow);
		
		If TreeRow.Rows.Count() > 0 Then
			
			ExpandValueTree(Table, TreeRow.Rows);
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Returns the synchronization date presentation.
//
// Parameters:
// SynchronizationDate - Date - data synchronization absolute date.
//
Function SynchronizationDatePresentation(Val SynchronizationDate) Export
	
	If Not ValueIsFilled(SynchronizationDate) Then
		Return NStr("en = 'Synchronization is not performed.'");
	EndIf;
	
	Return StringFunctionsClientServer.SubstituteParametersInString(NStr("en = 'The last synchronization: %1'"),
		RelativeSynchronizationDate(SynchronizationDate));
EndFunction

// Returns presentation for the relative synchronization date.
//
// Parameters:
// SynchronizationDate - Date - data synchronization absolute date.
//
// Intervals:
//  Never                          (T = empty date)
//  Now                            (T < 5 min) 
//  5 minutes ago                  (5 min < Т < 15 min) 
//  15 minutes ago                 (15 мин < Т < 30 мин)
//  30 minutes ago                 (30 min < Т < 1 hour) 
//  1 hour ago                     (1 hour < Т < 2 hours) 
//  2 hours ago                    (2 hours < Т < 3 hours)
//  Today, 12:44:12                (3 hours < Т < yesterday) 
//  Yesterday, 22:30:45            (yesterday < Т < day before yesterday) 
//  Day before yesterday, 21:22:54 (day before yesterday < Т < posture the day before yesterday) 
//  <March 12, 2012>               (posture the day before yesterday < Т)
//
Function RelativeSynchronizationDate(Val SynchronizationDate) Export
	
	If Not ValueIsFilled(SynchronizationDate) Then
		
		Return NStr("en = 'Never'");
		
	EndIf;
	
	CurrentDate = CurrentSessionDate();
	
	Interval = CurrentDate - SynchronizationDate;
	
	If Interval < 0 Then // 0 min
		
		Result = Format(SynchronizationDate, "DLF=DD");
		
	ElsIf Interval < 60 * 5 Then // 5 min
		
		Result = NStr("en = 'Now'");
		
	ElsIf Interval < 60 * 15 Then // 15 min
		
		Result = NStr("en = '5 minutes ago'");
		
	ElsIf Interval < 60 * 30 Then // 30 min
		
		Result = NStr("en = '15 minutes ago'");
		
	ElsIf Interval < 60 * 60 * 1 Then // 1 hour
		
		Result = NStr("en = '30 minutes ago'");
		
	ElsIf Interval < 60 * 60 * 2 Then // 2 hours
		
		Result = NStr("en = '1 hour ago'");
		
	ElsIf Interval < 60 * 60 * 3 Then // 3 hours
		
		Result = NStr("en = '2 hours ago'");
		
	Else
		
		DifferenceDayCount = DifferenceDayCount(SynchronizationDate, CurrentDate);
		
		If DifferenceDayCount = 0 Then // today
			
			Result = StringFunctionsClientServer.SubstituteParametersInString(NStr("en = 'Today, %1'"), Format(SynchronizationDate, "DLF=T"));
			
		ElsIf DifferenceDayCount = 1 Then // yesterday
			
			Result = StringFunctionsClientServer.SubstituteParametersInString(NStr("en = 'Yesterday, %1'"), Format(SynchronizationDate, "DLF=T"));
			
		ElsIf DifferenceDayCount = 2 Then // day before yesterday
			
			Result = StringFunctionsClientServer.SubstituteParametersInString(NStr("en = 'Day before yesterday, %1'"), Format(SynchronizationDate, "DLF=T"));
			
		Else // long time ago
			
			Result = Format(SynchronizationDate, "DLF=DD");
			
		EndIf;
		
	EndIf;
	
	Return Result;
EndFunction

Function DifferenceDayCount(Val Date1, Val Date2)
	
	Return Int((BegOfDay(Date2) - BegOfDay(Date1)) / 86400);
	
EndFunction

// For internal use.
//
Procedure FillValueTable(Target, Val Source) Export
	Target.Clear();
	
	If TypeOf(Source)=Type("ValueTable") Then
		SourceColumns = Source.Columns;
	Else
		TempTable = Source.Unload(New Array);
		SourceColumns = TempTable.Columns;
	EndIf;
	
	If TypeOf(Target)= Type("ValueTable") Then
		TargetColumns = Target.Columns;
		TargetColumns.Clear();
		For Each Column In SourceColumns Do
			FillPropertyValues(TargetColumns.Add(), Column);
		EndDo;
	EndIf;
	
	For Each Row In Source Do
		FillPropertyValues(Target.Add(), Row);
	EndDo;
EndProcedure

Function TableIntoStrucrureArray(Val ValueTable)
	Result = New Array;
	
	ColumnNames = "";
	For Each Column In ValueTable.Columns Do
		ColumnNames = ColumnNames + "," + Column.Name;
	EndDo;
	ColumnNames = Mid(ColumnNames, 2);
	
	For Each Row In ValueTable Do
		RowStructure = New Structure(ColumnNames);
		FillPropertyValues(RowStructure, Row);
		Result.Add(RowStructure);
	EndDo;
	
	Return Result;
EndFunction

// Compares two versions that are in the String format.
//
// Parameters:
//  VersionString1  - String - version number in RR.{S|SS}.VV.BB format.
//  VersionString2  - String - the second number to compare.
//
// Returns:
//   Number - greater than 0 if VersionString1 > VersionString2, and 0 if versions are equal.
//
Function CompareVersionsWithoutAssemblyNumbers(Val VersionString1, Val VersionString2) Export
	
	String1 = ?(IsBlankString(VersionString1), "0.0.0", VersionString1);
	String2 = ?(IsBlankString(VersionString2), "0.0.0", VersionString2);
	Version1 = StringFunctionsClientServer.SplitStringIntoSubstringArray(String1, ".");
	If Version1.Count() <> 3 Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Invalid format of the VersionString1 parameter: %1'"), VersionString1);
	EndIf;
	Version2 = StringFunctionsClientServer.SplitStringIntoSubstringArray(String2, ".");
	If Version2.Count() <> 3 Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
	    	NStr("en = 'Invalid format of the VersionString2 parameter: %1'"), VersionString2);
	EndIf;
	
	Result = 0;
	For Digit = 0 To 2 Do
		Result = Number(Version1[Digit]) - Number(Version2[Digit]);
		If Result <> 0 Then
			Return Result;
		EndIf;
	EndDo;
	Return Result;
	
EndFunction

// Checks whether correspondent versions are different in the rules 
// of the current application and in the rules of the other application.
//
Function DifferentCorrespondentVersions(ExchangePlanName, EventLogMessageKey, VersionInCurrentApplication,
	VersionInOtherApplication, MessageText, ExternalConnectionParameters = Undefined) Export
	
	VersionInCurrentApplication = ?(ValueIsFilled(VersionInCurrentApplication), VersionInCurrentApplication, CorrespondentVersionInRules(ExchangePlanName));
	
	If ValueIsFilled(VersionInCurrentApplication) And ValueIsFilled(VersionInOtherApplication)
		And ExchangePlanSettingValue(ExchangePlanName, "WarnAboutExchangeRuleVersionMismatch") Then
		
		VersionInCurrentApplicationWithoutAssemblyNumber = CommonUseClientServer.ConfigurationVersionWithoutAssemblyNumber(VersionInCurrentApplication);
		VersionInOtherApplicationWithoutAssemblyNumber = CommonUseClientServer.ConfigurationVersionWithoutAssemblyNumber(VersionInOtherApplication);
		
		If VersionInCurrentApplicationWithoutAssemblyNumber <> VersionInOtherApplicationWithoutAssemblyNumber Then
			
			IsExternalConnection = (MessageText = "ExternalConnection");
			
			ExchangePlanSynonym = Metadata.ExchangePlans[ExchangePlanName].Synonym;
			
			MessagePattern = NStr("en = 'Data synchronization might be performed incorrectly because the application version %1 (%2) in the conversion rules of the current application is not matches the application version %3 in the other application. Make sure that the imported files are actual and match the versions of both applications.'");
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, ExchangePlanSynonym, VersionInCurrentApplicationWithoutAssemblyNumber, VersionInOtherApplicationWithoutAssemblyNumber);
			
			WriteLogEvent(EventLogMessageKey, EventLogLevel.Warning,,, MessageText);
			
			If ExternalConnectionParameters <> Undefined
				And CommonUseClientServer.CompareVersions("2.2.3.18", ExternalConnectionParameters.ExternalConnectionSLVersion) <= 0
				And ExternalConnectionParameters.ExternalConnection.DataExchangeExternalConnection.WarnAboutExchangeRuleVersionMismatch(ExchangePlanName) Then
				
				ExchangePlanSynonymInOtherApplication = ExternalConnectionParameters.InfobaseNode.Metadata().Synonym;
				ExternalConnectionMessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern,
					ExchangePlanSynonymInOtherApplication, VersionInOtherApplicationWithoutAssemblyNumber, VersionInCurrentApplicationWithoutAssemblyNumber);
				
				ExternalConnectionParameters.ExternalConnection.WriteLogEvent(ExternalConnectionParameters.EventLogMessageKey,
					ExternalConnectionParameters.ExternalConnection.EventLogLevel.Warning,,, ExternalConnectionMessageText);
				
			EndIf;
			
			If SessionParameters.VersionDifferenceErrorOnGetData.CheckVersionDifference Then
				
				CheckStructure = New Structure(SessionParameters.VersionDifferenceErrorOnGetData);
				CheckStructure.HasError = True;
				CheckStructure.ErrorText = MessageText;
				CheckStructure.CheckVersionDifference = False;
				SessionParameters.VersionDifferenceErrorOnGetData = New FixedStructure(CheckStructure);
				Return True;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	Return False;
	
EndFunction

// For internal use.
// 
Function InitializeVersionDifferenceCheckParameters(CheckVersionDifference) Export
	
	SetPrivilegedMode(True);
	
	CheckStructure = New Structure(SessionParameters.VersionDifferenceErrorOnGetData);
	CheckStructure.CheckVersionDifference = CheckVersionDifference;
	CheckStructure.HasError = False;
	SessionParameters.VersionDifferenceErrorOnGetData = New FixedStructure(CheckStructure);
	
	Return SessionParameters.VersionDifferenceErrorOnGetData;
	
EndFunction

// For internal use.
// 
Function VersionDifferenceErrorOnGetData() Export
	
	SetPrivilegedMode(True);
	
	Return SessionParameters.VersionDifferenceErrorOnGetData;
	
EndFunction

Function CorrespondentVersionInRules(ExchangePlanName)
	
	Query = New Query;
	Query.Text = "SELECT
	|	DataExchangeRules.ReadCorrespondentRules,
	|	DataExchangeRules.RuleKind
	|FROM
	|	InformationRegister.DataExchangeRules AS DataExchangeRules
	|WHERE
	|	DataExchangeRules.ExchangePlanName = &ExchangePlanName
	|	AND DataExchangeRules.RulesLoaded = TRUE
	|	AND DataExchangeRules.RuleKind = VALUE(Enum.DataExchangeRuleKinds.ObjectConversionRules)";
	
	Query.SetParameter("ExchangePlanName", ExchangePlanName);
	
	Result = Query.Execute();
	
	If Not Result.IsEmpty() Then
		
		Selection = Result.Select();
		Selection.Next();
		
		RuleStructure = Selection.ReadCorrespondentRules.Get().Conversion;
		CorrespondentVersion = Undefined;
		RuleStructure.Property("RecipientConfigurationVersion", CorrespondentVersion);
		
		Return CorrespondentVersion;
		
	EndIf;
	
	Return Undefined;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Constants.

// Returns the unlimited length string literal.
//
// Returns:
//  String - unlimited length string literal.
//
Function UnlimitedLengthString() Export
	
	Return "(Unlimited string)";
	
EndFunction

// Returns the literal of the XML node that contains the ORR constant value.
//
// Returns:
//  String - literal of the XML node that contains the ORR constant value.
//
Function FilterItemPropertyConstantValue() Export
	
	Return "ConstantValue";
	
EndFunction

// Returns the XML node literal that contains the value getting algorithm.
//
// Returns:
//  String - XML node literal that contains the value getting algorithm.
//
Function FilterItemPropertyValueAlgorithm() Export
	
	Return "ValueAlgorithm";
	
EndFunction

// Returns the name of the file that is used for checking the transport data processor connection.
//
// Returns:
//  String - name of the file that is used for checking the transport data processor connection.
//
Function TestConnectionFileName() Export
	
	Return "ConnectionCheckFile.tmp";
	
EndFunction

// For internal use.
// 
Function InfobaseOperationModeFile() Export
	
	Return 0;
	
EndFunction

// For internal use.
// 
Function InfobaseOperationModeClientServer() Export
	
	Return 1;
	
EndFunction

// For internal use.
// 
Function IsErrorMessageNumberLessOrEqualToPreviouslyAcceptedMessageNumber(ErrorDescription)
	
	Return Find(Lower(ErrorDescription), Lower("en = 'Message number is less than or equal to'")) > 0;
	
EndFunction

// For internal use.
// 
Function EventLogMessageTextEstablishingConnectionToWebService() Export
	
	Return NStr("en = 'Data exchange.Establishing connection to web service.'", CommonUseClientServer.DefaultLanguageCode());
	
EndFunction

// For internal use.
// 
Function DataExchangeRuleLoadingEventLogMessageText() Export
	
	Return NStr("en = 'Data exchange.Importing rules'", CommonUseClientServer.DefaultLanguageCode());
	
EndFunction

// For internal use.
// 
Function DataExchangeCreationEventLogMessageText() Export
	
	Return NStr("en = 'Data exchange.Creating data exchange.'", CommonUseClientServer.DefaultLanguageCode());
	
EndFunction

// For internal use.
// 
Function TempFileDeletionEventLogMessageText() Export
	
	Return NStr("en = 'Data exchange.Deletion of temporary file'", CommonUseClientServer.DefaultLanguageCode());
	
EndFunction

// For internal use.
// 
Function EventLogMessageTextDataExchange() Export
	
	Return NStr("en = 'Data exchange'", CommonUseClientServer.DefaultLanguageCode());
	
EndFunction

// Returns True if the subordinate DIB node configuration must be updated.
// In the master node always returns False.
// 
// Copy of the CommonUse.DIBSubordinateNodeConfigurationUpdateRequired function.
// 
Function InstallUpdateRequired() Export
	
	Return IsSubordinateDIBNode() And ConfigurationChanged();
	
EndFunction

// Returns a node content table. The table contains objects that have reference types.
//
//  Parameters:
//      ExchangeNode: exchange node reference.
//      Periodical:   flag that shows whether objects that store data 
//                    (such as documents) are included in the result. 
//      Catalog:      flag that shows whether regulatory data objects
//                    are included in the result. 
//  Result columns:
//      FullMetadataName - metadata full name (table name for the query).
//      ListPresentation - list presentation for the table. 
//      Presentation     - object presentation for the table.
//      PictureIndex     - picture index according to PictureLib.MetadataObjectsCollection. 
//      Type             - metadata type.
//
Function NodeContentRefTables(ExchangeNode, Periodical=True, Catalog=True) Export
	Return DataExchangeCached.NodeContentRefTables(ExchangeNode, Periodical, Catalog);
EndFunction

// Returns extended object presentation.
//
Function ObjectPresentation(ParameterObject) Export
	If ParameterObject=Undefined Then
		Return "";
	EndIf;
	Meta = ?(TypeOf(ParameterObject)= Type("String"), Metadata.FindByFullName(ParameterObject), ParameterObject);
	
  // The object can have no presentation attributes. 
  // Getting the object presentation form the structure fields.
	Presentation = New Structure("ExtendedObjectPresentation, ObjectPresentation");
	FillPropertyValues(Presentation, Meta);
	If Not IsBlankString(Presentation.ExtendedObjectPresentation) Then
		Return Presentation.ExtendedObjectPresentation;
	ElsIf Not IsBlankString(Presentation.ObjectPresentation) Then
		Return Presentation.ObjectPresentation;
	EndIf;
	
	Return Meta.Presentation();
EndFunction

// Returns the extended presentation of the object list.
//
Function ObjectListPresentation(ParameterObject) Export
	If ParameterObject=Undefined Then
		Return "";
	EndIf;
	Meta = ?(TypeOf(ParameterObject)=Type("String"), Metadata.FindByFullName(ParameterObject), ParameterObject);
	
  // The object can have no presentation attributes. 
  // Getting the object presentation form the structure fields.
	Presentation = New Structure("ExtendedListPresentation, ListPresentation");
	FillPropertyValues(Presentation, Meta);
	If Not IsBlankString(Presentation.ExtendedListPresentation) Then
		Return Presentation.ExtendedListPresentation;
	ElsIf Not IsBlankString(Presentation.ListPresentation) Then
		Return Presentation.ListPresentation;
	EndIf;
	
	Return Meta.Presentation();
EndFunction

// Returns the flag that shows whether the specified reference can be exported on the specified node.
//
//  Parameters:
//      ExchangeNode         - ExchangePlanRef - exchange plan node to check whether 
//                             the data export is available. 
//      Ref                  - Arbitrary - object to check.
//      AdditionalProperties - Structure - object additional properties.
//
// Returns:
//  Boolean - flag that shows whether the export is available.
//
Function RefExportAllowed(ExchangeNode, Ref, AdditionalProperties = Undefined) Export
	
	If Ref.IsEmpty() Then
		Return False;
	EndIf;
	
	RegistrationObject = Ref.GetObject();
	If RegistrationObject = Undefined Then
		// Object is deleted. Return value is True.
		Return True;
	EndIf;
	
	If AdditionalProperties <> Undefined Then
		AttributeStructure = New Structure("AdditionalProperties");
		FillPropertyValues(AttributeStructure, RegistrationObject);
		ObjectAdditionalProperties = AttributeStructure.AdditionalProperties;
		
		If TypeOf(ObjectAdditionalProperties) = Type("Structure") Then
			For Each KeyValue In AdditionalProperties Do
				ObjectAdditionalProperties.Insert(KeyValue.Key, KeyValue.Value);
			EndDo;
		EndIf;
	EndIf;
	
	// Checking whether the data export is available
	Sending = DataItemSend.Auto;
	DataExchangeEvents.DataOnSendToRecipient(RegistrationObject, Sending, , ExchangeNode);
	Return Sending = DataItemSend.Auto;
EndFunction

// Returns a flag that shows whether manual export is available for the specified reference on the specified node.
//
//  Parameters:
//      ExchangeNode - ExchangePlanRef - exchange plan node to check whether
//                     the data export is available. 
//      Ref          - Arbitrary -  object to check.
//
// Returns:
//  Boolean - flag that shows whether the export is available.
//
Function RefExportAvailableFromInteractiveAddition(ExchangeNode, Ref) Export
	
	AdditionalProperties = New Structure("InteractiveExportAddition", True);
	
	Return RefExportAllowed(ExchangeNode, Ref, AdditionalProperties);
	
EndFunction

// Wrappers for the background procedures of the interactive export modification.
//
Procedure InteractiveExportModification_GenerateUserSpreadsheetDocument(DataProcessorStructure, ResultAddress, FullMetadataName, Presentation, SimplifiedMode) Export
	ReportObject = InteractiveExportModification_ObjectBySettings(DataProcessorStructure);
	
	Result = ReportObject.GenerateUserSpreadsheetDocument(FullMetadataName, Presentation, SimplifiedMode);
	PutToTempStorage(Result, ResultAddress);
EndProcedure

// For internal use.
// 
Procedure InteractiveExportModification_GenerateValueTree(DataProcessorStructure, ResultAddress, MetadataNameList) Export
	ReportObject = InteractiveExportModification_ObjectBySettings(DataProcessorStructure);
	
	Result = ReportObject.GenerateValueTree(MetadataNameList);
	PutToTempStorage(Result, ResultAddress);
EndProcedure

// For internal use.
// 
Procedure InteractiveExportModification_RecordAdditionalChanges(DataProcessorStructure) Export
	ReportObject = InteractiveExportModification_ObjectBySettings(DataProcessorStructure);
	
	ReportObject.RecordAdditionalChanges();
EndProcedure

// For internal use.
// 
Function InteractiveExportModification_ObjectBySettings(Val Settings)
	ReportObject = DataProcessors.InteractiveExportModification.Create();
	
	FillPropertyValues(ReportObject, Settings, , "AllDocumentsFilterComposer");
	
	// Setting up the composer fractionally
	Data = ReportObject.CommonFilterSettingsComposer();
	Composer = New DataCompositionSettingsComposer;
	Composer.Initialize(New DataCompositionAvailableSettingsSource(Data.CompositionSchema));
	Composer.LoadSettings(Data.Settings);
	
	ReportObject.AllDocumentsFilterComposer = Composer;
	
	FilterItems = ReportObject.AllDocumentsFilterComposer.Settings.Filter.Items;
	FilterItems.Clear();
	ReportObject.AddDataCompositionFilterValues(
		FilterItems, Settings.AllDocumentsFilterComposerSettings.Filter.Items);
	
	Return ReportObject;
EndFunction

// For internal use.
//
Function RunBackgroundJob(MethodName, MethodParameters, MethodDetails="") Export
	
	Job = BackgroundJobs.Execute(MethodName, MethodParameters, , MethodDetails);
	Try 
		Job.WaitForCompletion( ?(GetClientConnectionSpeed()=ClientConnectionSpeed.Low, 4, 2) );
		Return Undefined;
	Except
		If Job.State=BackgroundJobState.Failed Then
			RaiseFailedJobException(Job);
		EndIf;
	EndTry;
	
	Return Job.UUID;
EndFunction

// For internal use.
//
Procedure RaiseFailedJobException(Val Job)
	// Record about the background job failure is done. Raising the exception.
	Raise StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en='The %1 job is terminated abnormally.
		         |
		         |%2'"),
		Job.Description, BriefErrorDescription(Job.ErrorInfo)
	);
EndProcedure

// For internal use.
// 
Function BackgroundJobCompleted(JobID) Export
	
	Result = True;
	If JobID<>Undefined Then
		// The current infobase is not in file mode
		Job = BackgroundJobs.FindByUUID(JobID);
		If Job<>Undefined Then
			// All unintelligible jobs are completed
			If Job.State=BackgroundJobState.Failed Then
				RaiseFailedJobException(Job);
			EndIf;
			Result = Job.State<>BackgroundJobState.Active;
		EndIf;
	EndIf;
	
	Return Result;
EndFunction

// For internal use.
// 
Procedure CancelBackgroundJob(JobID) Export
	
	If JobID <> Undefined Then 
		Job = BackgroundJobs.FindByUUID(JobID);
		If Job <> Undefined Then
			Job.Cancel();
		EndIf;
	EndIf;
	
EndProcedure

// Returns the ID of the "Data synchronization with other applications" supplied access group profile.
//
// Returns:
//  String - ID of the supplied access group profile.
//
Function DataSynchronizationAccessProfileWithOtherApplications() Export
	
	Return "04937803-5dba-11df-a1d4-005056c00008";
	
EndFunction

// Returns the list of roles that are included in the "Data synchronization with other applications" access group profile.
// 
Function DataSynchronizationAccessProfileWithOtherApplicationsRoles()
	
	If CommonUse.SubsystemExists("StandardSubsystems.ObjectVersioning") Then
		Return "SynchronizeData, RemoteAccessBaseFunctionality, ReadObjectVersionInfo";
	Else
		Return "SynchronizeData, RemoteAccessBaseFunctionality";
	EndIf;
	
EndFunction

Function GetDataExchangeMessageFromMasterNode()
	
	Return Constants.DataExchangeMessageFromMasterNode.Get().Get();
	
EndFunction

Procedure SetDataExchangeMessageFromMasterNode(ExchangeMessage, Recipient) Export
	
	PathToFile = "[Directory][Path]";
	PathToFile = StrReplace(PathToFile, "[Directory]", TempFileStorageDirectory());
	PathToFile = StrReplace(PathToFile, "[Path]", New UUID);
	
	ExchangeMessage.Write(PathToFile);
	
	MessageStructure = New Structure;
	MessageStructure.Insert("PathToFile", PathToFile);
	
	Constants.DataExchangeMessageFromMasterNode.Set(New ValueStorage(MessageStructure));
	
	WriteDataReceiveEvent(Recipient, NStr("en = 'Exchange message is cached.'"));
	
EndProcedure

Procedure ClearDataExchangeMessageFromMasterNode() Export
	
	ExchangeMessage = GetDataExchangeMessageFromMasterNode();
	
	If TypeOf(ExchangeMessage) = Type("Structure") Then
		
		DeleteFiles(ExchangeMessage.PathToFile);
		
	EndIf;
	
	Constants.DataExchangeMessageFromMasterNode.Set(New ValueStorage(Undefined));
	
EndProcedure

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////// 
// Security profiles.
//

Procedure CreateQueriesForExternalResourceUse(PermissionRequests)
	
	If CommonUseCached.DataSeparationEnabled() And CommonUseCached.CanUseSeparatedData() Then
		Return;
	EndIf;
	
	Constants.DataExchangeMessageDirectoryForLinux.CreateValueManager().OnFillPermissionsToAccessExternalResources(PermissionRequests);
	Constants.DataExchangeMessageDirectoryForWindows.CreateValueManager().OnFillPermissionsToAccessExternalResources(PermissionRequests);
	InformationRegisters.ExchangeTransportSettings.OnFillPermissionsToAccessExternalResources(PermissionRequests);
	InformationRegisters.DataExchangeRules.OnFillPermissionsToAccessExternalResources(PermissionRequests);
	
EndProcedure

Function RequestToUseExternalResourcesOnExchangeEnable() Export
	
	Requests = New Array();
	CreateQueriesForExternalResourceUse(Requests);
	Return Requests;
	
EndFunction

Procedure ExternalResourcesDataExchangeMessageDirectoryQuery(PermissionRequests, Object) Export
	
	ConstantValue = Object.Value;
	If Not IsBlankString(ConstantValue) Then
		
		Permissions = New Array();
		Permissions.Add(SafeMode.PermissionToUseFileSystemDirectory(
			ConstantValue, True, True));
		
		PermissionRequests.Add(
			SafeMode.RequestToUseExternalResources(Permissions,
				CommonUse.MetadataObjectID(Object.Metadata())));
		
	EndIf;
	
EndProcedure

Function RequestForClearingPermissionsForExternalResources() Export
	
	Requests = New Array;
	
	For Each ExchangePlanName In DataExchangeCached.SLExchangePlans() Do
		
		QueryText =
		"SELECT
		|	ExchangePlan.Ref AS Node
		|FROM
		|	ExchangePlan.[ExchangePlanName] AS ExchangePlan";
		
		QueryText = StrReplace(QueryText, "[ExchangePlanName]", ExchangePlanName);
		
		Query = New Query;
		Query.Text = QueryText;
		
		Result = Query.Execute();
		Selection = Result.Select();
		
		While Selection.Next() Do
			
			Requests.Add(SafeMode.RequestForClearingPermissionsForExternalResources(Selection.Node));
			
		EndDo;
		
	EndDo;
	
	Requests.Add(SafeMode.RequestForClearingPermissionsForExternalResources(
		CommonUse.MetadataObjectID(Metadata.Constants.DataExchangeMessageDirectoryForLinux)));
	Requests.Add(SafeMode.RequestForClearingPermissionsForExternalResources(
		CommonUse.MetadataObjectID(Metadata.Constants.DataExchangeMessageDirectoryForWindows)));
	
	Return Requests;
	
EndFunction

// Returns the template of an external module security profile name.
// The function should return the same value every time it is called.
//
// Parameters:
//  ExternalModule - AnyRef – a reference to an external module.
//
// Returns - String - security profile name template with "%1" character 
//           sequence to be replaced by UUID.
//
Function SecurityProfileNamePattern(Val ExternalModule) Export
	
	Template = "Exchange_[ExchangePlanName]_%1"; // Do not localize this parameter
	Return StrReplace(Template, "[ExchangePlanName]", ExternalModule.Name);
	
EndFunction

Function ExternalModuleContainerDictionary() Export
	
	Result = New Structure();
	
	Result.Insert("NominativeCase", NStr("en = 'Data synchronization settings.'"));
	Result.Insert("Genitive", NStr("en = 'Data synchronization settings.'"));
	
	Return Result;
	
EndFunction

Function ExternalModuleContainers() Export
	
	Result = New Array();
	DataExchangeOverridable.GetExchangePlans(Result);
	Return Result;
	
EndFunction

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////// 
// INTERNAL INTERFACE FOR THE INTERACTIVE EXPORT ADDITION.
//

// Initializes export addition for the step by step exchange wizard.
//
// Parameters:
//     InfobaseNode       - ExchangePlanRef - node reference to execute setup.
//     FromStorageAddress - String, UUID - storage address where data is saved between server calls. 
//     HasNodeScenario    - Boolean - flag that shows whether the additional setup is required.
//
// Returns:
//     Structure - data to operate with export addition.
//
Function InteractiveExportModification(Val InfobaseNode, Val FromStorageAddress, Val HasNodeScenario=Undefined) Export
	
	Result = New Structure;
	Result.Insert("InfobaseNode", InfobaseNode);
	Result.Insert("ExportVariant", 0);
	
	Result.Insert("AllDocumentsFilterPeriod", New StandardPeriod);
	Result.AllDocumentsFilterPeriod.Option = StandardPeriodVariant.LastMonth;
	
	AdditionDataProcessor = DataProcessors.InteractiveExportModification.Create();
	AdditionDataProcessor.InfobaseNode  = InfobaseNode;
	AdditionDataProcessor.ExportVariant = 0;
	
	// Specifying composer options
	Data = AdditionDataProcessor.CommonFilterSettingsComposer(FromStorageAddress);
	Result.Insert("AllDocumentsComposerAddress", PutToTempStorage(Data, FromStorageAddress));
	
	Result.Insert("AdditionalRegistration", New ValueTable);
	Columns = Result.AdditionalRegistration.Columns;
	
	StringType = New TypeDescription("String");
	Columns.Add("FullMetadataName", StringType);
	Columns.Add("Filter",       New TypeDescription("DataCompositionFilter"));
	Columns.Add("Period",       New TypeDescription("StandardPeriod"));
	Columns.Add("SelectPeriod", New TypeDescription("Boolean"));
	Columns.Add("Presentation", StringType);
	Columns.Add("FilterString", StringType);
	Columns.Add("Quantity",     StringType);

	Result.Insert("AdditionScenarioParameters", New Structure);
	AdditionScenarioParameters = Result.AdditionScenarioParameters;
	
	AdditionScenarioParameters.Insert("VariantWithoutAddition", New Structure("Use, Order, Title", True, 1));
	AdditionScenarioParameters.VariantWithoutAddition.Insert("Explanation", 
		NStr("en='Data will be sent according to the general settings.'")
	); 
	
	AdditionScenarioParameters.Insert("AllDocumentVariant", New Structure("Use, Order, Title", True, 2));
	AdditionScenarioParameters.AllDocumentVariant.Insert("Explanation",
		NStr("en='All documents of the period that match the filter options, are sent.'")
	); 
	
	AdditionScenarioParameters.Insert("ArbitraryFilterVariant", New Structure("Use, Order, Title", True, 3));
	AdditionScenarioParameters.ArbitraryFilterVariant.Insert("Explanation",
		NStr("en='Additional data is sent according to the filter settings.'")
	); 
	
	AdditionScenarioParameters.Insert("AdditionalVariant", New Structure("Use, Order, Title", False,   4));
	AdditionScenarioParameters.AdditionalVariant.Insert("Explanation",
		NStr("en='Additional settings data will be sent.'")
	); 
	
	AdditionalVariant = AdditionScenarioParameters.AdditionalVariant;
	AdditionalVariant.Insert("Title", "");
	AdditionalVariant.Insert("UseFilterPeriod", False);
	AdditionalVariant.Insert("FilterPeriod");
	AdditionalVariant.Insert("Filter", Result.AdditionalRegistration.Copy());
	AdditionalVariant.Insert("FilterFormName");
	AdditionalVariant.Insert("FormCommandTitle");
	
	MetaNode = InfobaseNode.Metadata();
	
	If HasNodeScenario=Undefined Then
		// Additional setup is not required
		HasNodeScenario = False;
	EndIf;
	
	If HasNodeScenario Then
		
		NodeManagerModule = ExchangePlans[MetaNode.Name];
		SetupAvailable = False;
		Try 
			SetupAvailable = NodeManagerModule.SetUpInteractiveExport(InfobaseNode);
		Except
			// No action required. Called method is unavailable.
		EndTry;
		
		If SetupAvailable Then
			NodeManagerModule.SetUpInteractiveExport(InfobaseNode, Result.AdditionScenarioParameters);
		EndIf;
		
	EndIf;
	
	Result.Insert("FromStorageAddress", FromStorageAddress);
	Return Result;
EndFunction

// Clears document common filter.
//
// Parameters:
//     ExportAddition - Structure, CollectionFormAttribute - export parameter details.
//
Procedure InteractiveExportModificationGeneralFilterClearing(ExportAddition) Export
	
	If IsBlankString(ExportAddition.AllDocumentsComposerAddress) Then
		ExportAddition.AllDocumentsFilterComposer.Settings.Filter.Items.Clear();
	Else
		Data = GetFromTempStorage(ExportAddition.AllDocumentsComposerAddress);
		Data.Settings.Filter.Items.Clear();
		ExportAddition.AllDocumentsComposerAddress = PutToTempStorage(Data, ExportAddition.FromStorageAddress);
		
		Composer = New DataCompositionSettingsComposer;
		Composer.Initialize(New DataCompositionAvailableSettingsSource(Data.CompositionSchema));
		Composer.LoadSettings(Data.Settings);
		ExportAddition.AllDocumentsFilterComposer = Composer;
	EndIf;
	
EndProcedure

// Clears the detailed filter.
//
// Parameters:
//     ExportAddition - Structure, CollectionFormAttribute - export parameter details.
//
Procedure InteractiveExportModificationDetailsClearing(ExportAddition) Export
	ExportAddition.AdditionalRegistration.Clear();
EndProcedure

// Defines general filter details. If the filter is not filled, returning the empty string.
//
// Parameters:
//     ExportAddition - Structure, CollectionFormAttribute - export parameter details.
//
// Returns:
//     String - filter details.
//
Function InteractiveExportModificationGeneralFilterAdditionDescription(Val ExportAddition) Export
	
	ComposerData = GetFromTempStorage(ExportAddition.AllDocumentsComposerAddress);
	
	Source = New DataCompositionAvailableSettingsSource(ComposerData.CompositionSchema);
	Composer = New DataCompositionSettingsComposer;
	Composer.Initialize(Source);
	Composer.LoadSettings(ComposerData.Settings);
	
	Return ExportAdditionFilterPresentation(Undefined, Composer, "");
EndFunction

// Define the description of the detailed filter. If the filter is not filled, returning the empty string.
//
// Parameters:
//     ExportAddition - Structure, CollectionFormAttribute - export parameter details.
//
// Returns:
//     String - filter details.
//
Function InteractiveExportModificationDetailedFilterDetails(Val ExportAddition) Export
	Return DetailedExportAdditionPresentation(ExportAddition.AdditionalRegistration, "");
EndFunction

// Analyzes history of filter settings that are saved by user for a node.
//
// Parameters:
//     ExportAddition - Structure, CollectionFormAttribute - export parameter details.
//
// Returns:
//     Value list where presentation contains - settings item name, value - settings data.
//
Function InteractiveExportModificationSettingsHistory(Val ExportAddition) Export
	AdditionDataProcessor = DataProcessors.InteractiveExportModification.Create();
	
	OptionFilter = InteractiveExportModificationVariantFilter(ExportAddition);
	
	Return AdditionDataProcessor.ReadSettingsListPresentations(ExportAddition.InfobaseNode, OptionFilter);
EndFunction

// Restores options in attributes that are contained in ExportAddition, according to the saved settings.
//
// Parameters:
//     ExportAddition           - Structure, CollectionFormAttribute - export parameter details.
//     SettingsItemPresentation - String - name of the settings item to restore.
//
// Returns:
//     Boolean - True if settings are restored, False if settings are not found.
//
Function InteractiveExportModificationRestoreSettings(ExportAddition, Val SettingsItemPresentation) Export
	
	AdditionDataProcessor = DataProcessors.InteractiveExportModification.Create();
	FillPropertyValues(AdditionDataProcessor, ExportAddition);
	
	OptionFilter = InteractiveExportModificationVariantFilter(ExportAddition);
	
	// Restoring object state
	Result = AdditionDataProcessor.RestoreCurrentAttributesFromSettings(SettingsItemPresentation, OptionFilter, ExportAddition.FromStorageAddress);
	
	If Result Then
		FillPropertyValues(ExportAddition, AdditionDataProcessor, "ExportVariant, AllDocumentsFilterPeriod, AllDocumentsFilterComposer");
		
		// Updating composer address anyway
		Data = AdditionDataProcessor.CommonFilterSettingsComposer();
		Data.Settings = ExportAddition.AllDocumentsFilterComposer.Settings;
		ExportAddition.AllDocumentsComposerAddress = PutToTempStorage(Data, ExportAddition.FromStorageAddress);
		
		FillValueTable(ExportAddition.AdditionalRegistration, AdditionDataProcessor.AdditionalRegistration);
		
		// Updating node scenario settings only if they are defined in the read message. Otherwise the current settings are used.
		If AdditionDataProcessor.AdditionalNodeScenarioRegistration.Count() > 0 Then
			FillPropertyValues(ExportAddition, AdditionDataProcessor, "NodeScenarioFilterPeriod, NodeScenarioFilterPresentation");
			FillValueTable(ExportAddition.AdditionalNodeScenarioRegistration, AdditionDataProcessor.AdditionalNodeScenarioRegistration);
			// Normalizing period settings
			InteractiveExportModificationSetNodeScenarioPeriod(ExportAddition);
		EndIf;
		
		// The current presentation of the saved settings
		ExportAddition.CurrentSettingsItemPresentation = SettingsItemPresentation;
	EndIf;

	Return Result;
EndFunction

// Saves settings with the specified name, according to the ExportAddition values.
//
// Parameters:
//     ExportAddition           - Structure, CollectionFormAttribute - export parameter details.
//     SettingsItemPresentation - String - name of the settings to be saved.
//
Procedure InteractiveExportModificationSaveSettings(ExportAddition, Val SettingsItemPresentation) Export
	
	AdditionDataProcessor = DataProcessors.InteractiveExportModification.Create();
	FillPropertyValues(AdditionDataProcessor, ExportAddition);
	
	AttributeList = "
		|ExportVariant,
		|AllDocumentsFilterPeriod, NodeScenarioFilterPeriod, NodeScenarioFilterPresentation";
	
	FillPropertyValues(AdditionDataProcessor, ExportAddition, AttributeList);
	
	FillValueTable(AdditionDataProcessor.AdditionalRegistration,             ExportAddition.AdditionalRegistration);
	FillValueTable(AdditionDataProcessor.AdditionalNodeScenarioRegistration, ExportAddition.AdditionalNodeScenarioRegistration);
	
	// Initializing settings composer
	Data = AdditionDataProcessor.CommonFilterSettingsComposer();
	
	If IsBlankString(ExportAddition.AllDocumentsComposerAddress) Then
		SettingsSource = ExportAddition.AllDocumentsFilterComposer.Settings;
	Else
		ComposerStructure = GetFromTempStorage(ExportAddition.AllDocumentsComposerAddress);
		SettingsSource = ComposerStructure.Settings;
	EndIf;
		
	AdditionDataProcessor.AllDocumentsFilterComposer = New DataCompositionSettingsComposer;
	AdditionDataProcessor.AllDocumentsFilterComposer.Initialize( New DataCompositionAvailableSettingsSource(Data.CompositionSchema) );
	AdditionDataProcessor.AllDocumentsFilterComposer.LoadSettings(SettingsSource);
	
	// Saving settings
	AdditionDataProcessor.SaveCurrentValuesInSettings(SettingsItemPresentation);
	
	// Current presentation of the saved settings
	ExportAddition.CurrentSettingsItemPresentation = SettingsItemPresentation;
EndProcedure

// Fills the form attribute according to the passed settings.
//
// Parameters:
//     Form                   - ManagedForm - attribute setup form.
//     ExportAdditionSettings - Structure - initial settings.
//     AdditionAttributeName  - String - name of form attribute to create or fill.
//
Procedure InteractiveExportModificationAttributeBySettings(Form, Val ExportAdditionSettings, Val AdditionAttributeName="ExportAddition") Export
	AdditionScenarioParameters = ExportAdditionSettings.AdditionScenarioParameters;
	
	// Processing the attributes
	AdditionAttribute = Undefined;
	For Each Attribute In Form.GetAttributes() Do
		If Attribute.Name = AdditionAttributeName Then
			AdditionAttribute = Attribute;
			Break;
		EndIf;
	EndDo;
	
	// Checking and adding the attribute
	ToAdd = New Array;
	If AdditionAttribute = Undefined Then
		AdditionAttribute = New FormAttribute(AdditionAttributeName, 
			New TypeDescription("DataProcessorObject.InteractiveExportModification"));
			
		ToAdd.Add(AdditionAttribute);
		Form.ChangeAttributes(ToAdd);
	EndIf;
	
	// Checking and adding columns of the general additional registration
	TableAttributePath = AdditionAttribute.Name + ".AdditionalRegistration";
	If Form.GetAttributes(TableAttributePath).Count()=0 Then
		ToAdd.Clear();
		Columns = ExportAdditionSettings.AdditionalRegistration.Columns;
		For Each Column In Columns Do
			ToAdd.Add(New FormAttribute(Column.Name, Column.ValueType, TableAttributePath));
		EndDo;
		Form.ChangeAttributes(ToAdd);
	EndIf;
	
	// Checking and adding additional registration columns of the node scenario
	TableAttributePath = AdditionAttribute.Name + ".AdditionalNodeScenarioRegistration";
	If Form.GetAttributes(TableAttributePath).Count()=0 Then
		ToAdd.Clear();
		Columns = AdditionScenarioParameters.AdditionalVariant.Filter.Columns;
		For Each Column In Columns Do
			ToAdd.Add(New FormAttribute(Column.Name, Column.ValueType, TableAttributePath));
		EndDo;
		Form.ChangeAttributes(ToAdd);
	EndIf;
	
	// Adding data
	AttributeValue = Form[AdditionAttributeName];
	
	// Processing value tables
	ValueToFormData(AdditionScenarioParameters.AdditionalVariant.Filter,
		AttributeValue.AdditionalNodeScenarioRegistration);
	
	AdditionScenarioParameters.AdditionalVariant.Filter =TableIntoStrucrureArray(
		AdditionScenarioParameters.AdditionalVariant.Filter);
	
	AttributeValue.AdditionScenarioParameters = AdditionScenarioParameters;
	
	AttributeValue.InfobaseNode = ExportAdditionSettings.InfobaseNode;

	AttributeValue.ExportVariant                 = ExportAdditionSettings.ExportVariant;
	AttributeValue.AllDocumentsFilterPeriod      = ExportAdditionSettings.AllDocumentsFilterPeriod;
	
	Data = GetFromTempStorage(ExportAdditionSettings.AllDocumentsComposerAddress);
	DeleteFromTempStorage(ExportAdditionSettings.AllDocumentsComposerAddress);
	AttributeValue.AllDocumentsComposerAddress = PutToTempStorage(Data, Form.UUID);
	
	AttributeValue.NodeScenarioFilterPeriod = AdditionScenarioParameters.AdditionalVariant.FilterPeriod;
	
	If AdditionScenarioParameters.AdditionalVariant.Use Then
		AttributeValue.NodeScenarioFilterPresentation = ExportAdditionPresentationByNodeScenario(AttributeValue);
	EndIf;
	
EndProcedure

// Returns the export description according to specified options.
//
// Parameters:
//     ExportAddition - Structure, FormDataCollection - export parameter details.
//
// Returns:
//     String - presentation. 
// 
Function ExportAdditionPresentationByNodeScenario(Val ExportAddition) Export
	MetaNode = ExportAddition.InfobaseNode.Metadata();
	ManagerModule = ExchangePlans[MetaNode.Name];
	
	Parameters = New Structure;
	Parameters.Insert("UseFilterPeriod", ExportAddition.AdditionScenarioParameters.AdditionalVariant.UseFilterPeriod);
	Parameters.Insert("FilterPeriod",    ExportAddition.NodeScenarioFilterPeriod);
	Parameters.Insert("Filter",          ExportAddition.AdditionalNodeScenarioRegistration);
	
	Return ManagerModule.InteractiveExportFilterPresentation(ExportAddition.InfobaseNode, Parameters);
EndFunction

//  Returns period and filter details in the string format.
//
//  Parameters:
//      Period:             period used in the filter options.
//      Filter:             data composition filter to describe. 
//      EmptyFilterDetails: the function returns this value if an empty filter is passed.
//
//  Returns:
//      String - description of period and filter.
//
Function ExportAdditionFilterPresentation(Val Period, Val Filter, Val EmptyFilterDetails=Undefined) Export
	
	OurFilter = ?(TypeOf(Filter)=Type("DataCompositionSettingsComposer"), Filter.Settings.Filter, Filter);
	
	PeriodString = ?(ValueIsFilled(Period), String(Period), "");
	FilterString  = String(OurFilter);
	
	If IsBlankString(FilterString) Then
		If EmptyFilterDetails = Undefined Then
			FilterString = NStr("en='All objects'");
		Else
			FilterString = EmptyFilterDetails;
		EndIf;
	EndIf;
	
	If Not IsBlankString(PeriodString) Then
		FilterString =  PeriodString + ", " + FilterString;
	EndIf;
	
	Return FilterString;
EndFunction

//  Returns details of the filter by AdditionalRegistration attribute.
//
//  Parameters:
//      AdditionalRegistration - ValueTable, Array - strings or structures that describes the filter. 
//      EmptyFilterDetails     - String - the function returns this value if an empty filter is passed.
//
Function DetailedExportAdditionPresentation(Val AdditionalRegistration, Val EmptyFilterDetails=Undefined) Export
	
	Text = "";
	For Each Row In AdditionalRegistration Do
		Text = Text + Chars.LF + Row.Presentation + ": " + ExportAdditionFilterPresentation(Row.Period, Row.Filter);
	EndDo;
	
	If Not IsBlankString(Text) Then
		Return TrimAll(Text);
		
	ElsIf EmptyFilterDetails=Undefined Then
		Return NStr("en='Additional data is not selected'");
		
	EndIf;
	
	Return EmptyFilterDetails;
EndFunction

// Returns the "All documents" metadata object internal group ID.
//
Function ExportAdditionAllDocumentsID() Export
	// The ID must not be identical to the full metadata name
	Return "TotalDocuments";
EndFunction

// Returns the "All catalogs" metadata object internal group ID.
//
Function ExportAdditionAllCatalogsID() Export
	// The ID must not be identical to the full metadata name
	Return "TotalCatalogs";
EndFunction

// Returns name for saving and restoring settings while interactive export addition.
//
Function ExportAdditionSettingsAutoSavingName() Export
	Return NStr("en='Last data sending (auto-saved)'");
EndFunction

// Performs additional registration of objects according to the settings.
//
// Parameters:
//     ExportAddition - Structure, FormDataCollection - export parameter details.
//
Procedure InteractiveExportModificationRegisterAdditionalData(Val ExportAddition) Export
	
	If ExportAddition.ExportVariant <= 0 Then
		Return;
	EndIf;
	
	ReportObject = DataProcessors.InteractiveExportModification.Create();
	FillPropertyValues(ReportObject, ExportAddition,,"AdditionalRegistration, AdditionalNodeScenarioRegistration");
		
	If ReportObject.ExportVariant = 1 Then
		// Period with filter, additional option is empty
		
	ElsIf ExportAddition.ExportVariant = 2 Then
		// Detailed setup
		ReportObject.AllDocumentsFilterComposer = Undefined;
		ReportObject.AllDocumentsFilterPeriod   = Undefined;
		
		FillValueTable(ReportObject.AdditionalRegistration, ExportAddition.AdditionalRegistration);
		
	ElsIf ExportAddition.ExportVariant = 3 Then
		// According to the node scenario imitating detailed option
		ReportObject.ExportVariant = 2;
		
		ReportObject.AllDocumentsFilterComposer = Undefined;
		ReportObject.AllDocumentsFilterPeriod   = Undefined;
		
		FillValueTable(ReportObject.AdditionalRegistration, ExportAddition.AdditionalNodeScenarioRegistration);
	EndIf;
	
	ReportObject.RecordAdditionalChanges();
EndProcedure

// Sets the general period in all filter dimensions.
//
// Parameters:
//     ExportAddition - Structure, FormDataCollection - export parameter details.
//
Procedure InteractiveExportModificationSetNodeScenarioPeriod(ExportAddition) Export
	For Each Row In ExportAddition.AdditionalNodeScenarioRegistration Do
		Row.Period = ExportAddition.NodeScenarioFilterPeriod;
	EndDo;
	
	// Updating the presentation
	ExportAddition.NodeScenarioFilterPresentation = ExportAdditionPresentationByNodeScenario(ExportAddition);
EndProcedure

// Returns filter options according to the settings.
//
// Parameters:
//     ExportAddition - Structure, FormDataCollection - export parameter details.
//
// Returns:
//     Array - contains numbers of used options: 
//             0 - without filter, 1 - all document filter, 2 - detailed filter, 3 - node scenario.
//
Function InteractiveExportModificationVariantFilter(Val ExportAddition) Export
	
	Result = New Array;
	
	DataTest = New Structure("AdditionScenarioParameters");
	FillPropertyValues(DataTest, ExportAddition);
	AdditionScenarioParameters = DataTest.AdditionScenarioParameters;
	If TypeOf(AdditionScenarioParameters) <> Type("Structure") Then
		// If there is no settings specified, using all options as the default settings
		Return Undefined;
	EndIf;
	
	If AdditionScenarioParameters.Property("VariantWithoutAddition") 
		And AdditionScenarioParameters.VariantWithoutAddition.Use
	Then
		Result.Add(0);
	EndIf;
	
	If AdditionScenarioParameters.Property("AllDocumentVariant")
		And AdditionScenarioParameters.AllDocumentVariant.Use 
	Then
		Result.Add(1);
	EndIf;
	
	If AdditionScenarioParameters.Property("ArbitraryFilterVariant")
		And AdditionScenarioParameters.ArbitraryFilterVariant.Use 
	Then
		Result.Add(2);
	EndIf;
	
	If AdditionScenarioParameters.Property("AdditionalVariant")
		And AdditionScenarioParameters.AdditionalVariant.Use 
	Then
		Result.Add(3);
	EndIf;
	
	If Result.Count()=4 Then
		// All options are selected, deleting filter
		Return Undefined;
	EndIf;

	Return Result;
EndFunction

// Determines available option of the backup start before the data synchronization.
// Returns - String:
//     "SaaS"                - SaaS backup functional is available.
//     "SaaSInstructionOnly" - SaaS mode, the backup must be performed by a SaaS administrator.
//     "Backup"              - the infobase runs in file mode. Backup subsystem is available.
//
//     In all other cases the function returns an empty string. It means that backup is unavailable.
//
Function BackupOption() Export
	
	Mode = New FixedStructure( CommonUseCached.ApplicationRunMode() );
	If Mode.SaaS Then
		
		HasBackupSubsystem = CommonUse.SubsystemExists("StandardSubsystems.SaaSOperations.DataAreaBackup");
		If HasBackupSubsystem Then
			DataAreaBackupModule = CommonUse.CommonModule("DataAreaBackup");
			
			BackupSupported        = DataAreaBackupModule.BackupUsed();
			HasRightToCreateBackup = Users.InfobaseUserWithFullAccess();
			
			If BackupSupported And HasRightToCreateBackup Then
				Return "SaaS";
			EndIf
		EndIf;
		
		Return "SaaSInstructionOnly"
	EndIf;
	
	HasBackupSubsystem = CommonUse.SubsystemExists("StandardSubsystems.InfobaseBackup");
	If HasBackupSubsystem Then
		
		BackupSupported        = CommonUse.FileInfobase();
		HasRightToCreateBackup = Users.InfobaseUserWithFullAccess(, True);
		
		If BackupSupported And HasRightToCreateBackup Then
			Return "Backup";
		EndIf;
	EndIf;
	
	Return "";
EndFunction

#EndRegion
