////////////////////////////////////////////////////////////////////////////////
// Data exchange subsystem
//
////////////////////////////////////////////////////////////////////////////////

#Region InternalProceduresAndFunctions

// Entry point for a data exchange iteration, which includes importing and exporting exchange plan node data.
//
// Parameters:
//  Cancel                                  - Boolean - True if errors occurred during data exchange.
//  InfobaseNode                            - ExchangePlanRef - exchange plan node that is used in the data exchange iteration. 
//  PerformImport                           - Boolean (optional) - flag that shows whether data import is required. 
//                                            The default value is True.
//  PerformExport                           - Boolean (optional) - flag that shows whether data export is required. 
//                                            The default value is True.
//  ExchangeMessageTransportKind (optional) - EnumRef.ExchangeMessageTransportKinds - transport kind that is used for data exchange. 
// 							                                Default value:                            
//                                            InformationRegister.ExchangeTransportSettings.Resource.DefaultExchangeMessageTransportKind.
// 							                                If there is no value set in the information register, Enums.ExchangeMessageTransportKinds.FILE 
//                                            is used instead.
// 
Procedure ExecuteDataExchangeForInfobaseNode(Cancel,
														InfobaseNode,
														PerformImport = True,
														PerformExport = True,
														ExchangeMessageTransportKind = Undefined,
														LongAction = False,
														ActionID = "",
														FileID = "",
														LongActionAllowed = False,
														Val AuthenticationParameters = Undefined
	) Export
	
	DataExchangeServer.ExecuteDataExchangeForInfobaseNode(Cancel,
														InfobaseNode,
														PerformImport,
														PerformExport,
														ExchangeMessageTransportKind,
														LongAction,
														ActionID,
														FileID,
														LongActionAllowed,
														AuthenticationParameters);
	
EndProcedure

// Performs data exchange for each settings row.
// The data exchange is performed in two steps:
// - exchange initialization - prepare data exchange subsystem to perform data exchange
// - data exchange           - read a message file and import the read data to the infobase, 
//                             or export changes to a message file.
// 
// Initialization is performed once per session, initialized values are cached on the server 
// until the server is restarted or until the cached values of the data exchange subsystem are reset.
// The cached values are reset when any data that affects the data exchange 
// (transport settings, data exchange settings, or exchange plan node filter settings) is changed.
//
// The exchange can be performed for all scenario rows or for a single scenario row.
//
// Parameters:
//  Cancel                    - Boolean - True if errors occurred during the data exchange.
//  ExchangeExecutionSettings - CatalogRef.DataExchangeScenarios - catalog item whose attribute 
//                              values are used to perform the data exchange. 
//  LineNumber                - Number - number of row to include in data exchange.
//                              If it is not specified, all rows are included in data exchange.
// 
Procedure ExecuteDataExchangeUsingDataExchangeScenario(Cancel, ExchangeExecutionSettings, LineNumber = Undefined) Export
	
	DataExchangeServer.ExecuteDataExchangeUsingDataExchangeScenario(Cancel, ExchangeExecutionSettings, LineNumber);
	
EndProcedure


// Checks whether the object registration cache is up-to-date.
// If the cached data is obsolete, it initializes the cache with new values.
//
Procedure CheckObjectChangeRecordMechanismCache() Export
	
	SetPrivilegedMode(True);
	
	If CommonUseCached.CanUseSeparatedData() Then
		
		ActualDate = GetFunctionalOption("CurrentORMCachedValueRefreshDate");
		
		If SessionParameters.ORMCachedValueRefreshDate <> ActualDate Then
			
			UpdateObjectChangeRecordMechanismCache();
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Sets or updates cached values and data exchange subsystem session parameters.
//
// It sets the following session parameters:
//   ObjectChangeRecordRules          - ValueStorage - object registration rule value table in binary format.
//   SelectiveObjectChangeRecordRules - ValueStorage.
//   ORMCachedValueRefreshDate        - Date (Date and time) - date of the latest data exchange subsystem cache update.
//
Procedure UpdateObjectChangeRecordMechanismCache() Export
	
	SetPrivilegedMode(True);
	
	RefreshReusableValues();
	
	If DataExchangeCached.UsedExchangePlans().Count() > 0 Then
		
		SessionParameters.ObjectChangeRecordRules          = New ValueStorage(DataExchangeServer.GetObjectChangeRecordRules());
		
		SessionParameters.SelectiveObjectChangeRecordRules = New ValueStorage(DataExchangeServer.GetSelectiveObjectChangeRecordRules());
		
	Else
		
		SessionParameters.ObjectChangeRecordRules          = New ValueStorage(DataExchangeServer.InitObjectChangeRecordRuleTable());
		
		SessionParameters.SelectiveObjectChangeRecordRules = New ValueStorage(DataExchangeServer.SelectiveObjectChangeRecordRuleTableInitialization());
		
	EndIf;
	
	// Getting date value for checking whether cached data is up-to-date
	SessionParameters.ORMCachedValueRefreshDate = GetFunctionalOption("CurrentORMCachedValueRefreshDate");
	
EndProcedure

// Sets the ORMCachedValueRefreshDate constant value to the current server date. 
// Once the constant value is changed, cached values of the data exchange subsystem 
// become obsolete and require new initialization. 
// 
Procedure ResetObjectChangeRecordMechanismCache() Export
	
	If CommonUseCached.CanUseSeparatedData() Then
		
		SetPrivilegedMode(True);
		// Saving current server date and time using
   		// the CurrentDate() method because CurrentSessionDate() 
   		// might return time from a different time zone.
   		// The current server date is used as a unique key for the object registration cache.
		Constants.ORMCachedValueRefreshDate.Set(CurrentDate());
		
	EndIf;
	
EndProcedure


// Loads a data exchange message from the local file system of the server.
//
Procedure ImportInfobaseNodeViaFile(Cancel, Val InfobaseNode, Val ExchangeMessageFullFileName) Export
	
	Try
		DataExchangeServer.ExecuteDataExchangeForInfobaseNodeOverFileOrString(InfobaseNode, ExchangeMessageFullFileName, Enums.ActionsOnExchange.DataImport);
	Except
		Cancel = True;
	EndTry;
	
EndProcedure

// Records that data exchange is completed.
//
Procedure CommitDataExportExecutionInLongActionMode(Val InfobaseNode, Val StartDate) Export
	
	SetPrivilegedMode(True);
	
	ActionOnExchange = Enums.ActionsOnExchange.DataExport;
	
	ExchangeSettingsStructure = New Structure;
	ExchangeSettingsStructure.Insert("InfobaseNode",            InfobaseNode);
	ExchangeSettingsStructure.Insert("ExchangeExecutionResult", Enums.ExchangeExecutionResults.Completed);
	ExchangeSettingsStructure.Insert("ActionOnExchange",        ActionOnExchange);
	ExchangeSettingsStructure.Insert("ProcessedObjectCount",    0);
	ExchangeSettingsStructure.Insert("EventLogMessageKey",      DataExchangeServer.GetEventLogMessageKey(InfobaseNode, ActionOnExchange));
	ExchangeSettingsStructure.Insert("StartDate",               StartDate);
	ExchangeSettingsStructure.Insert("EndDate",                 CurrentSessionDate());
	ExchangeSettingsStructure.Insert("IsDIBExchange",           DataExchangeCached.IsDistributedInfobaseNode(InfobaseNode));
	
	DataExchangeServer.AddExchangeFinishEventLogMessage(ExchangeSettingsStructure);
	
EndProcedure

// Records abnormal data exchange termination.
//
Procedure AddExchangeFinishedWithErrorEventLogMessage(Val InfobaseNode,
												Val ActionOnExchange,
												Val StartDate,
												Val ErrorMessageString
	) Export
	
	SetPrivilegedMode(True);
	
	DataExchangeServer.AddExchangeFinishedWithErrorEventLogMessage(InfobaseNode,
											ActionOnExchange,
											StartDate,
											ErrorMessageString);
EndProcedure

// Gets an exchange message file from a correspondent infobase over a web service.
// Imports the exchange message file to the current infobase.
//
Procedure ExecuteDataExchangeForInfobaseNodeFinishLongAction(
															Cancel,
															Val InfobaseNode,
															Val FileID,
															Val ActionStartDate,
															Val AuthenticationParameters = Undefined
	) Export
	
	DataExchangeServer.ExecuteDataExchangeForInfobaseNodeFinishLongAction(
															Cancel,
															InfobaseNode,
															FileID,
															ActionStartDate,
															AuthenticationParameters);
EndProcedure

// Attempts to establish external connection according to passed connection parameters.
// If external connection cannot be established, the cancellation flag is set to True.
//
Procedure TestExternalConnection(Cancel, SettingsStructure, ErrorAttachingAddIn = False) Export
	
	ErrorMessageString = "";
	
	// Attempting to establish an external connection
	Result = DataExchangeServer.EstablishExternalConnectionWithInfobase(SettingsStructure);
	// Displaying error message
	If Result.Connection = Undefined Then
		CommonUseClientServer.MessageToUser(Result.BriefErrorDetails,,,, Cancel);
	EndIf;
	ErrorAttachingAddIn = Result.ErrorAttachingAddIn;
	
EndProcedure

// Checks whether a register record set is empty.
//
Function RegisterRecordSetEmpty(RecordStructure, RegisterName) Export
	
	RegisterMetadata = Metadata.InformationRegisters[RegisterName];
	
	// Creating a register record set
	RecordSet = InformationRegisters[RegisterName].CreateRecordSet();
	
	// Setting a filter by each register dimension
	For Each Dimension In RegisterMetadata.Dimensions Do
		
		// If dimension filter value is specified in a structure, the filter is set
		If RecordStructure.Property(Dimension.Name) Then
			
			RecordSet.Filter[Dimension.Name].Set(RecordStructure[Dimension.Name]);
			
		EndIf;
		
	EndDo;
	
	RecordSet.Read();
	
	Return RecordSet.Count() = 0;
	
EndFunction

// Returns the event log message key that matches the specified action string.
//
Function GetEventLogMessageKeyByActionString(InfobaseNode, ExchangeActionString) Export
	
	SetPrivilegedMode(True);
	
	Return DataExchangeServer.GetEventLogMessageKey(InfobaseNode, Enums.ActionsOnExchange[ExchangeActionString]);
	
EndFunction

// Returns the structure that contains event log filter parameters.
//
Function GetEventLogFilterDataStructure(InfobaseNode, Val ActionOnExchange) Export
	
	If TypeOf(ActionOnExchange) = Type("String") Then
		
		ActionOnExchange = Enums.ActionsOnExchange[ActionOnExchange];
		
	EndIf;
	
	SetPrivilegedMode(True);
	
	DataExchangeStates = DataExchangeServer.DataExchangeStates(InfobaseNode, ActionOnExchange);
	
	Filter = New Structure;
	Filter.Insert("EventLogMessageText", DataExchangeServer.GetEventLogMessageKey(InfobaseNode, ActionOnExchange));
	Filter.Insert("StartDate",           DataExchangeStates.StartDate);
	Filter.Insert("EndDate",             DataExchangeStates.EndDate);
	
	Return Filter;
EndFunction

// Gets a code of a predefined exchange plan node.
// 
// Parameters:
//  ExchangePlanName - String - The exchange plan name as it is set in Designer mode
// 
// Returns:
//  String - predefined exchange node code.
//
Function GetThisNodeCodeForExchangePlan(ExchangePlanName) Export
	
	SetPrivilegedMode(True);
	
	Return DataExchangeCached.GetThisNodeCodeForExchangePlan(ExchangePlanName);
EndFunction

// Returns the array of all reference types available in the configuration.
//
Function AllConfigurationReferenceTypes() Export
	
	Return DataExchangeCached.AllConfigurationReferenceTypes();
	
EndFunction

// Returns background job state.
// This function is used to implement long actions.
// 
// Parameters:
//  JobID - UUID - background job ID.
// 
// Returns:
//  String - background job state:
//     "Actively" - the job is in progress.
//     "Completed" - the job is completed successfully.
//     "Failed" - the job is terminated due to an error or canceled by a user.
//
Function JobState(Val JobID) Export
	
	Try
		Result = ?(LongActions.JobCompleted(JobID), "Completed", "Active");
	Except
		Result = "Failed";
		WriteLogEvent(DataExchangeServer.EventLogMessageTextDataExchange(),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo())
		);
	EndTry;
	
	Return Result;
EndFunction

// Gets the state of a long action (background job) that is executed in a correspondent infobase.
//
Function LongActionState(Val ActionID,
									Val WebServiceURL,
									Val UserName,
									Val Password,
									ErrorMessageString = ""
	) Export
	
	Try
		
		ConnectionParameters = DataExchangeServer.WSParameterStructure();
		ConnectionParameters.WSURL   = WebServiceURL;
		ConnectionParameters.WSUserName = UserName;
		ConnectionParameters.WSPassword          = Password;
		
		WSProxy = DataExchangeServer.GetWSProxy(ConnectionParameters, ErrorMessageString);
		
		If WSProxy = Undefined Then
			Raise ErrorMessageString;
		EndIf;
		
		Result = WSProxy.GetLongActionState(ActionID, ErrorMessageString);
		
	Except
		Result = "Failed";
		WriteLogEvent(DataExchangeServer.EventLogMessageTextDataExchange(),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo())
		);
	EndTry;
	
	Return Result;
EndFunction

// Gets the state of a long action (background job) that is executed in a correspondent infobase 
// for a specific node.
//
Function LongActionStateForInfobaseNode(Val ActionID,
									Val InfobaseNode,
									Val AuthenticationParameters = Undefined,
									ErrorMessageString = ""
	) Export
	
	Try
		SetPrivilegedMode(True);
		
		ConnectionParameters = InformationRegisters.ExchangeTransportSettings.TransportSettingsWS(InfobaseNode, AuthenticationParameters);
		
		WSProxy = DataExchangeServer.GetWSProxy(ConnectionParameters, ErrorMessageString);
		
		If WSProxy = Undefined Then
			Raise ErrorMessageString;
		EndIf;
		
		Result = WSProxy.GetLongActionState(ActionID, ErrorMessageString);
		
	Except
		Result = "Failed";
		WriteLogEvent(DataExchangeServer.EventLogMessageTextDataExchange(),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo())
		);
	EndTry;
	
	Return Result;
EndFunction

// Gets an exchange message from a correspondent infobase over a web service 
// and saves the exchange message to a temporary directory.
//
Function GetExchangeMessageToTempDirectoryFromCorrespondentInfobaseOverWebService(
											Cancel,
											InfobaseNode,
											FileID,
											LongAction,
											ActionID,
											Val AuthenticationParameters = Undefined
	) Export
	
	Return DataExchangeServer.GetExchangeMessageToTempDirectoryFromCorrespondentInfobaseOverWebService(
											Cancel,
											InfobaseNode,
											FileID,
											LongAction,
											ActionID,
											AuthenticationParameters);
EndFunction

// Gets an exchange message from a correspondent infobase over a web service 
// and saves the exchange message to a temporary directory.
// This function is used to get an exchange message generated with a background job 
// that is executed in a correspondent infobase.
//
Function GetExchangeMessageToTempDirectoryFromCorrespondentInfobaseOverWebServiceFinishLongAction(
							Cancel,
							InfobaseNode,
							FileID,
							Val AuthenticationParameters = Undefined
	) Export
	
	Return DataExchangeServer.GetExchangeMessageToTempDirectoryFromCorrespondentInfobaseOverWebServiceFinishLongAction(
							Cancel,
							InfobaseNode,
							FileID,
							AuthenticationParameters);
EndFunction

// Returns the flag that shows whether a DIB node configuration was changed.
//
Function InstallUpdateRequired() Export
	
	DataExchangeServer.CheckCanSynchronizeData();
	
	SetPrivilegedMode(True);
	
	Return DataExchangeServer.InstallUpdateRequired();
	
EndFunction

// Deletes a record about object writing errors.
//
Procedure RecordIssueSolving(Source, ProblemType, Val DeletionMarkNewValue) Export
	
	SetPrivilegedMode(True);
	
	If DataExchangeCached.UsedExchangePlans().Count() > 0 Then
		
		ConflictRecordSet = InformationRegisters.DataExchangeResults.CreateRecordSet();
		ConflictRecordSet.Filter.ProblematicObjects.Set(Source);
		ConflictRecordSet.Filter.ProblemType.Set(ProblemType);
		
		ConflictRecordSet.Read();
		
		If ConflictRecordSet.Count() = 1 Then
			
			If DeletionMarkNewValue <> CommonUse.ObjectAttributeValue(Source, "DeletionMark") Then
				
				ConflictRecordSet[0].DeletionMark = DeletionMarkNewValue;
				ConflictRecordSet.Write();
				
			Else
				
				ConflictRecordSet.Clear();
				ConflictRecordSet.Write();
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Deletes data synchronization settings item.
//
Procedure DeleteSynchronizationSettings(Val InfobaseNode) Export
	
	DataExchangeServer.CheckExchangeManagementRights();
	
	NodeObject = InfobaseNode.GetObject();
	If NodeObject = Undefined Then
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	NodeObject.Delete();
	
EndProcedure

Function DataExchangeVariant(Val Correspondent) Export
	
	SetPrivilegedMode(True);
	
	Return DataExchangeServer.DataExchangeVariant(Correspondent);
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Data exchange in privileged mode.

// Sets data exchange subsystem session parameters.
//
// Parameters:
//  ParameterName       - String - session parameter name. 
//  SpecifiedParameters - Array - contains names of session parameters whose values are set.
// 
Procedure SessionParametersSetting(ParameterName, SpecifiedParameters) Export
	
	// Session parameter initialization must be performed without using application parameters.
	
	If ParameterName = "DataExchangeMessageImportModeBeforeStart" Then
		SessionParameters.DataExchangeMessageImportModeBeforeStart = New FixedStructure(New Structure);
		SpecifiedParameters.Add("DataExchangeMessageImportModeBeforeStart");
		Return;
	EndIf;
	
	If CommonUseCached.CanUseSeparatedData() Then
		
		// Updating cached values and session parameters
		UpdateObjectChangeRecordMechanismCache();
		
		// Registering names of session parameters that were set in DataExchangeServerCall.UpdateObjectChangeRecordMechanismCache.
		SpecifiedParameters.Add("SelectiveObjectChangeRecordRules");
		SpecifiedParameters.Add("ObjectChangeRecordRules");
		SpecifiedParameters.Add("ORMCachedValueRefreshDate");
		
		SessionParameters.DataSynchronizationPasswords = New FixedMap(New Map);
		SpecifiedParameters.Add("DataSynchronizationPasswords");
		
		SessionParameters.PriorityExchangeData = New FixedArray(New Array);
		SpecifiedParameters.Add("PriorityExchangeData");
		
		CheckStructure = New Structure;
		CheckStructure.Insert("CheckVersionDifference", False);
		CheckStructure.Insert("HasError",               False);
		CheckStructure.Insert("ErrorText",             "");
		
		SessionParameters.VersionDifferenceErrorOnGetData = New FixedStructure(CheckStructure);
		SpecifiedParameters.Add("DifferentVersionErrorOnGetData");
		
	Else
		
		SessionParameters.DataSynchronizationPasswords = New FixedMap(New Map);
		SpecifiedParameters.Add("DataSynchronizationPasswords");
		
	EndIf;
	
EndProcedure

// Checks the application execution mode, sets privileged mode, and executes a handler.
//
Procedure ExecuteHandlerInPrivilegedMode(Value, Val HandlerLine) Export
	
	If CurrentRunMode() = ClientRunMode.ManagedApplication Then
		Raise NStr("en = 'This method is not supported in the managed application mode.'");
	EndIf;
	
	SetPrivilegedMode(True);
	
	Execute(HandlerLine);
	
EndProcedure

// Gets a ScheduledJob by GUID.
// 
// Parameters:
//  JobUUID - String - scheduled job GUID.
// 
// Returns:
//  Undefined        - scheduled job with the specified GUID is not found. 
//  ScheduledJob     - scheduled job with the specified GUID.
//
Function FindScheduledJobByParameter(Val JobUUID) Export
	
	If IsBlankString(JobUUID) Then
		Return Undefined;
	EndIf;
	
	SetPrivilegedMode(True);
	
	Return ScheduledJobs.FindByUUID(New UUID(JobUUID));
EndFunction

// Returns the structure that stores object property values. 
// The structure is generated using a query to an infobase.
//  Structure fields:
//     Key - property name. 
//     Value - property value.
//
// Parameters:
// Ref - reference to an infobase object whose property values are retrieved.
//
// Returns:
//  Structure - structure containing the object property values.
//
Function GetPropertyValuesForRef(Ref, ObjectProperties, Val ObjectPropertiesString, Val MetadataObjectName) Export
	
	If CurrentRunMode() = ClientRunMode.ManagedApplication Then
		Raise NStr("en = 'This method is not supported in the managed application mode.'");
	EndIf;
	
	SetPrivilegedMode(True);
	
	Return DataExchangeEvents.GetPropertyValuesForRef(Ref, ObjectProperties, ObjectPropertiesString, MetadataObjectName);
EndFunction

// Returns an array of exchange plan nodes based on a query to an exchange plan table.
//
//
Function NodeArrayByPropertyValues(PropertyValues, Val QueryText, Val ExchangePlanName, Val FlagAttributeName, Val Data = False) Export
	
	If CurrentRunMode() = ClientRunMode.ManagedApplication Then
		Raise NStr("en = 'This method is not supported in the managed application mode.'");
	EndIf;
	
	SetPrivilegedMode(True);
	
	Return DataExchangeEvents.NodeArrayByPropertyValues(PropertyValues, QueryText, ExchangePlanName, FlagAttributeName, Data);
EndFunction

// Returns the ObjectChangeRecordRules session parameter value obtained in privileged mode.
//
// Returns:
// ValueStorage - the ObjectChangeRecordRules session parameter value.
//
Function SessionParametersObjectChangeRecordRules() Export
	
	SetPrivilegedMode(True);
	
	Return SessionParameters.ObjectChangeRecordRules;
	
EndFunction

// Returns the list of all exchange plan nodes except the predefined node.
//
// Parameters:
//  ExchangePlanName - String - exchange plan name as it is set in Designer.
//
//  Returns:
//   Array - list of exchange plan nodes.
//
Function AllExchangePlanNodes(Val ExchangePlanName) Export
	
	If CurrentRunMode() = ClientRunMode.ManagedApplication Then
		Raise NStr("en = 'This method is not supported in the managed application mode.'");
	EndIf;
	
	SetPrivilegedMode(True);
	
	Return DataExchangeCached.GetExchangePlanNodeArray(ExchangePlanName);
	
EndFunction

// Returns the flag that shows whether any changes are registered for a specified recipient.
//
Function ChangesRegistered(Val Recipient) Export
	
	QueryText =
	"SELECT TOP 1 1
	|FROM
	|	[Table].Changes AS ChangeTable
	|WHERE
	|	ChangeTable.Node = &Node";
	
	Query = New Query;
	Query.SetParameter("Node", Recipient);
	
	SetPrivilegedMode(True);
	
	ExchangePlanContent = Metadata.ExchangePlans[DataExchangeCached.GetExchangePlanName(Recipient)].Content;
	
	For Each ContentItem In ExchangePlanContent Do
		
		Query.Text = StrReplace(QueryText, "[Table]", ContentItem.Metadata.FullName());
		
		QueryResult = Query.Execute();
		
		If Not QueryResult.IsEmpty() Then
			Return True;
		EndIf;
		
	EndDo;
	
	Return False;
EndFunction

// Returns the flag that shows whether a specific exchange plan is used in data exchange.
// If an exchange plan contains at least one node that is not 
// a predefined one, it is considered used in data exchange.
//
// Parameters:
// ExchangePlanName - String - exchange plan name as it is set in Designer.
//
// Returns:
// Boolean - True if the exchange plan is used, otherwise False.
//
Function DataExchangeEnabled(Val ExchangePlanName, Val From) Export
	
	SetPrivilegedMode(True);
	
	Return DataExchangeCached.DataExchangeEnabled(ExchangePlanName, From);
EndFunction

// Returns the array of exchange plan nodes with "Always export" flag value set to True.
//
// Parameters:
// ExchangePlanName    - String - The name of the exchange plan used to determine exchange plan nodes 
//                                (as it is specified in Designer mode). 
// FlagAttributeName   - String - The name of the exchange plan attribute used to create a node selection filter. 
//
// Returns:
// Array - exchange plan nodes with "Always export" flag value set to True.
//
Function GetNodeArrayForChangeRecordExportAlways(Val ExchangePlanName, Val FlagAttributeName) Export
	
	If CurrentRunMode() = ClientRunMode.ManagedApplication Then
		Raise NStr("en = 'This method is not supported in the managed application mode.'");
	EndIf;
	
	SetPrivilegedMode(True);
	
	Return DataExchangeEvents.GetNodeArrayForChangeRecordExportAlways(ExchangePlanName, FlagAttributeName);
EndFunction

// Returns the array of exchange plan nodes with "Export when needed" flag set to True.
//
// Parameters:
//  Ref               - infobase object reference. The function returns the array of nodes where this object 
//                      was exported earlier. 
//  ExchangePlanName  - String - The name of the exchange plan used to determine exchange plan nodes 
//                      (as it is specified in Designer mode). 
//  FlagAttributeName - String - The name of the exchange plan attribute used to create a node selection filter. 
//
// Returns:
//  Array - exchange plan nodes with "Export when needed" flag value set to True.
//
Function GetNodeArrayForChangeRecordExportIfNecessary(Ref, Val ExchangePlanName, Val FlagAttributeName) Export
	
	If CurrentRunMode() = ClientRunMode.ManagedApplication Then
		Raise NStr("en = 'This method is not supported in the managed application mode.'");
	EndIf;
	
	SetPrivilegedMode(True);
	
	Return DataExchangeEvents.GetNodeArrayForChangeRecordExportIfNecessary(Ref, ExchangePlanName, FlagAttributeName);
EndFunction

// Returns the flag that shows whether application parameters are imported 
// from the exchange message.
// This function is used in a DIB data exchange when data is imported to a subordinate node.
//
Function DataExchangeMessageImportModeBeforeStart(Property) Export
	
	SetPrivilegedMode(True);
	
	Return SessionParameters.DataExchangeMessageImportModeBeforeStart.Property(Property);
	
EndFunction

// Returns the RetryDataExchangeMessageImportBeforeStart constant value:
// 1) Exchange message import error:
//    - metadata object ID import error
//    - object ID verification error
//    - import exchange message before infobase update error
//    - import exchange message before infobase update (infobase version not changed) error
// 2) Database update error after successful exchange message import
//
Function RetryDataExchangeMessageImportBeforeStart() Export
	
	SetPrivilegedMode(True);
	
	Return Constants.RetryDataExchangeMessageImportBeforeStart.Get() = True;
	
EndFunction

// Returns the list of prioritized exchange data items.
//
// Returns:
// Array - collection of references to prioritized exchange data items.
//
Function PriorityExchangeData() Export
	
	SetPrivilegedMode(True);
	
	Result = New Array;
	
	For Each Item In SessionParameters.PriorityExchangeData Do
		
		Result.Add(Item);
		
	EndDo;
	
	Return Result;
EndFunction

// Adds a passed value to the list of prioritized exchange data items.
//
Procedure SupplementPriorityExchangeData(Val Data) Export
	
	Result = PriorityExchangeData();
	
	Result.Add(Data);
	
	SetPrivilegedMode(True);
	
	SessionParameters.PriorityExchangeData = New FixedArray(Result);
	
EndProcedure

// Clears the list of prioritized exchange data items.
//
Procedure ClearPriorityExchangeData() Export
	
	SetPrivilegedMode(True);
	
	SessionParameters.PriorityExchangeData = New FixedArray(New Array);
	
EndProcedure

// Returns a list of metadata objects whose export is prohibited.
// Export is prohibited if the table has the NoExport flag set to True
// in exchange plan object registration rules.
//
// Parameters:
//     InfobaseNode - ExchangePlanRef - reference to exchange plan node.
//
// Returns:
//     Array that contains full names of metadata objects.
//
Function NonExportableNodeObjectMetadataNames(Val InfobaseNode) Export
	Result = New Array;
	
	NoExportMode = Enums.ExchangeObjectExportModes.NotExport;
	ExportModes   = DataExchangeCached.UserExchangePlanContent(InfobaseNode);
	For Each KeyValue In ExportModes Do
		If KeyValue.Value = NoExportMode Then
			Result.Add(KeyValue.Key);
		EndIf;
	EndDo;
	
	Return Result;
EndFunction

// Creates a request for clearing node permissions.
//
Function RequestForClearingPermissionsForExternalResources(Val InfobaseNode) Export
	
	Query = SafeMode.RequestForClearingPermissionsForExternalResources(InfobaseNode);
	Return CommonUseClientServer.ValueInArray(Query);
	
EndFunction

#EndRegion
