////////////////////////////////////////////////////////////////////////////////
// Data exchange subsystem.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// OnCreateAtServer event handler for the exchange plan node settings form.
//
// Parameters:
//  Form – managed form where the procedure is called from.
// 
Procedure NodesSetupFormOnCreateAtServer(Form, Cancel) Export
	
	// Skipping the initialization to guarantee that the form will be received if the SelfTest parameter is passed.
	If Form.Parameters.Property("SelfTest") Then
		Return;
	EndIf;
	
	LoadContextIntoForm(Form, Form.Parameters.Settings);
	
	If Form.Parameters.Property("FillChecking") Then
		Return;
	ElsIf Form.Parameters.Property("GetContextDescription") Then
		Return;
	EndIf;
	
	ExecuteFormTableComparisonAndMerging(Form, Cancel);
	
EndProcedure

// OnCreateAtServer event handler for the node setup form.
//
// Parameters:
//  Form                      – managed form where the procedure is called from.
//  ExchangePlanName - String - exchange plan name to be set up.
// 
Procedure NodeSettingsFormOnCreateAtServer(Form, ExchangePlanName) Export
	
	// Skipping the initialization to guarantee that the form will be received if the SelfTest parameter is passed.
	If Form.Parameters.Property("SelfTest") Then
		Return;
	EndIf;
	
	Form.NodeFilterStructure = ExchangePlans[ExchangePlanName].NodeFilterStructure();
	
	NodeSettingsFormOnCreateAtServerHandler(Form, "NodeFilterStructure");
	
EndProcedure

Procedure CorrespondentInfoBaseNodeSetupFormOnCreateAtServer(Form, ExchangePlanName) Export
	
	// Skipping the initialization to guarantee that the form will be received if the SelfTest parameter is passed.
	If Form.Parameters.Property("SelfTest") Then
		Return;
	EndIf;
	
	Form.ExternalConnectionParameters = Form.Parameters.ExternalConnectionParameters;
	Form.NodeFilterStructure = ExchangePlans[ExchangePlanName].CorrespondentInfoBaseNodeFilterSetup();
	
	NodeSettingsFormOnCreateAtServerHandler(Form, "NodeFilterStructure");
	
EndProcedure

// OnCreateAtServer event handler for default value setup form.
//
// Parameters:
//  Form             – managed form where the procedure is called from.
//  ExchangePlanName - String - exchange plan name to be set up.
// 
Procedure DefaultValueSetupFormOnCreateAtServer(Form, ExchangePlanName) Export
	
	// Skipping the initialization to guarantee that the form will be received if the SelfTest parameter is passed.
	If Form.Parameters.Property("SelfTest") Then
		Return;
	EndIf;
	
	Form.NodeDefaultValues = ExchangePlans[ExchangePlanName].NodeDefaultValues();
	
	NodeSettingsFormOnCreateAtServerHandler(Form, "NodeDefaultValues");
	
EndProcedure

Procedure CorrespondentInfoBaseDefaultValueSetupFormOnCreateAtServer(Form, ExchangePlanName) Export
	
	// Skipping the initialization to guarantee that the form will be received if the SelfTest parameter is passed.
	If Form.Parameters.Property("SelfTest") Then
		Return;
	EndIf;
	
	Form.ExternalConnectionParameters = Form.Parameters.ExternalConnectionParameters;
	Form.NodeDefaultValues = ExchangePlans[ExchangePlanName].CorrespondentInfoBaseNodeDefaultValues();
	
	NodeSettingsFormOnCreateAtServerHandler(Form, "NodeDefaultValues");
	
EndProcedure

Procedure GetAttributesToCheckDependingOnFunctionalOptions(AttributesToCheck, ExchangePlanName) Export
	
	ReverseIndex = AttributesToCheck.Count() - 1;
	
	While ReverseIndex >= 0 Do
		
		AttributeName = AttributesToCheck[ReverseIndex];
		
		Attribute = Metadata.ExchangePlans[ExchangePlanName].Attributes.Find(AttributeName);
		
		If Attribute <> Undefined
			And Attribute.FillChecking = FillChecking.ShowError Then
			
			FunctionalOptions = AttributeFunctionalOptions(Attribute);
			
			DeleteAttribute = True;
			
			If FunctionalOptions.Count() = 0 Then
				
				DeleteAttribute = False;
				
			Else
				
				For Each FunctionalOptionName In FunctionalOptions Do
					
					If GetFunctionalOption(FunctionalOptionName) = True Then
						
						DeleteAttribute = False;
						
						Break;
						
					EndIf;
					
				EndDo;
				
			EndIf;
			
			If DeleteAttribute Then
				
				AttributesToCheck.Delete(ReverseIndex);
				
			EndIf;
			
		EndIf;
		
		ReverseIndex = ReverseIndex - 1;
		
	EndDo;
	
EndProcedure

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

// Determines whether the AfterDataExport event handler must be executed during the
// exchange in the DIB.
// 
// Parameters:
//  Object – ExchangePlanObject – exchange plan node, for which the handler is executed.
//  Ref    – ExchangePlanRef – reference to the exchange plan node, for which the
//           handler is executed.
// 
// Returns:
//  Boolean - True if the AfterDataExport event handler must be executed, otherwise is False.
//
Function MustExecuteHandlerAfterDataExport(Object, Ref) Export
	
	Return MustExecuteHandler(Object, Ref, "SentNo");
	
EndFunction

// Determines whether the AfterDataImport event handler must be executed during the
// exchange in the DIB.
// 
// Parameters:
// Object  – ExchangePlanObject – exchange plan node, for which the handler is executed.
// Ref     – ExchangePlanRef – reference to the exchange plan node, for which the
//           handler is executed.
// 
// Returns:
// Boolean - True if the AfterDataImport event handler must be executed, otherwise is False.
//
Function MustExecuteHandlerAfterDataImport(Object, Ref) Export
	
	Return MustExecuteHandler(Object, Ref, "ReceivedNo");
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// INTERNAL

////////////////////////////////////////////////////////////////////////////////
// Infobase update

// Adds update handlers required by this subsystem to the Handlers list.
//
// Parameters:
//  Handlers - ValueTable - see the InfoBaseUpdate.NewUpdateHandlerTable for details.
// 
Procedure RegisterUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version = "*";
	Handler.Priority = 1;
	Handler.SharedData = True;
	Handler.Procedure = "DataExchangeServer.UpdateDataExchangeRules";
	
	Handler = Handlers.Add();
	Handler.Version = "1.1.1.2";
	Handler.Procedure = "DataExchangeServer.SetMappingDataAdjustmentRequiredForAllInfoBaseNodes";
	
	Handler = Handlers.Add();
	Handler.Version = "1.1.1.2";
	Handler.Procedure = "DataExchangeServer.SetExportModeForAllInfoBaseNodes";
	
	Handler = Handlers.Add();
	Handler.Version = "1.1.1.2";
	Handler.Procedure = "DataExchangeServer.UpdateDataExchangeScenarioScheduledJobs";
	
	Handler = Handlers.Add();
	Handler.Version = "1.1.2.0";
	Handler.Procedure = "DataExchangeServer.UpdateSubordinateDIBNodeSetupCompletedConstant";
	
	Handler = Handlers.Add();
	Handler.Version = "2.0.1.10";
	Handler.Procedure = "DataExchangeServer.CheckFunctionalOptionsAreSetOnInfoBaseUpdate";
	
EndProcedure

// Updates object conversion/registration rules.
// Updates all exchange plans that use SL functionality.
// Updates only standard rules.
// Rules are not updated if they were loaded from a file.
//
Procedure UpdateDataExchangeRules() Export
	
	// Skipping the update in subordinate DIB nodes because the updated register will  
	// be copied from the main node.
	If IsSubordinateDIBNode() Then
		Return;
	EndIf;
	
	// If the exchange plan was renamed or deleted from the configuration
	DeleteObsoleteRecordsFromDataExchangeRuleRegister();
	
	LoadedFromFileExchangeRules = New Array;
	LoadedFromFileRecordRules = New Array;
	
	CheckLoadedFromFileExchangeRulesAvailability(LoadedFromFileExchangeRules, LoadedFromFileRecordRules);
	
	Cancel = False;
	
	UpdateStandardDataExchangeRuleVersion(Cancel, LoadedFromFileExchangeRules, LoadedFromFileRecordRules);
	
	If Cancel Then
		Raise NStr("en = 'Error updating data exchange rules (see the event log for details).'");
	EndIf;
	
EndProcedure

// Sets the flag that shows whether the mapping data adjustment for all exchange plan
// nodes must be executed during the next data exchange.
//
Procedure SetMappingDataAdjustmentRequiredForAllInfoBaseNodes() Export
	
	InformationRegisters.CommonInfoBaseNodeSettings.SetMappingDataAdjustmentRequiredForAllInfoBaseNodes();
	
EndProcedure

// Sets the "Export by condition" value for export mode flags of all universal data
// exchange nodes.
//
Procedure SetExportModeForAllInfoBaseNodes() Export
	
	ExchangePlanList = DataExchangeCached.SLExchangePlanList();
	
	For Each Item In ExchangePlanList Do
		
		ExchangePlanName = Item.Value;
		
		If Metadata.ExchangePlans[ExchangePlanName].DistributedInfoBase Then
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
	
	Selection = Query.Execute().Choose();
	
	While Selection.Next() Do
		
		Cancel = False;
		
		Object = Selection.Ref.GetObject();
		
		Catalogs.DataExchangeScenarios.UpdateScheduledJobData(Cancel, Undefined, Object);
		
		If Cancel Then
			Raise NStr("en = 'Error updating the scheduled job for the data exchange scenario.'");
		EndIf;
		
		Object.Write();
		
	EndDo;
	
EndProcedure

// Sets the SubordinateDIBNodeSetupCompleted constant value to True for the subordinate
// DIB node.
//
Procedure UpdateSubordinateDIBNodeSetupCompletedConstant() Export
	
	If  IsSubordinateDIBNode()
		And InformationRegisters.ExchangeTransportSettings.NodeTransportSettingsAreSet(ExchangePlans.MasterNode()) Then
		
		Constants.SubordinateDIBNodeSetupCompleted.Set(True);
		
		RefreshReusableValues();
		
	EndIf;
	
EndProcedure

// Redefines the UseDataExchange constant value, if necessary.
//
Procedure CheckFunctionalOptionsAreSetOnInfoBaseUpdate() Export
	
	If Constants.UseDataExchange.Get() = True Then
		
		Constants.UseDataExchange.Set(True);
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

////////////////////////////////////////////////////////////////////////////////
// Data exchange execution.

// An entry point for performing the data exchange iteration (data export or import for the exchange plan node).
//
// Parameters:
//  Cancel                       - Boolean - cancel flag. It is set to True if errors 
//                                 occur during the procedure execution.
//  InfoBaseNode                 – ExchangePlanRef – exchange plan node, for which the 
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
Procedure ExecuteDataExchangeForInfoBaseNode(Cancel,
														InfoBaseNode,
														PerformImport = True,
														PerformExport = True,
														ExchangeMessageTransportKind = Undefined,
														LongAction = False,
														ActionID = "",
														FileID = "",
														LongActionAllowed = False
	) Export
	
	CheckUseDataExchange();
	
	If ExchangeMessageTransportKind = Enums.ExchangeMessageTransportKinds.COM Then
// Data exchange through external connection
		
		If PerformImport Then
			
			// IMPORTING DATA THROUGH THE EXTERNAL CONNECTION
			ExecuteExchangeActionForInfoBaseNodeByExternalConnection(Cancel, 
																	InfoBaseNode, 
																	Enums.ActionsOnExchange.DataImport, 
																	Undefined
			);
			
		EndIf;
		
		If PerformExport Then
			
			// EXPORTING DATA THROUGH THE EXTERNAL CONNECTION
			ExecuteExchangeActionForInfoBaseNodeByExternalConnection(Cancel, 
																	InfoBaseNode, 
																	Enums.ActionsOnExchange.DataExport, 
																	Undefined
			);
			
		EndIf;
		
	ElsIf ExchangeMessageTransportKind = Enums.ExchangeMessageTransportKinds.WS Then // Data exchange through web service
		
		If PerformImport Then
			
			// IMPORTING DATA THROUGH THE WEB SERVICE
			ExecuteExchangeOverWebServiceActionForInfoBaseNode(Cancel, 
																	InfoBaseNode, 
																	Enums.ActionsOnExchange.DataImport, 
																	LongAction, 
																	ActionID, 
																	FileID,
																	LongActionAllowed
			);
			
		EndIf;
		
		If PerformExport Then
			
			// EXPORTING DATA THROUGH THE WEB SERVICE
			ExecuteExchangeOverWebServiceActionForInfoBaseNode(Cancel, 
																	InfoBaseNode, 
																	Enums.ActionsOnExchange.DataExport, 
																	LongAction, 
																	ActionID, 
																	FileID, 
																	LongActionAllowed
			);
			
		EndIf;
		
	Else // Data exchange through ordinary channels
		
		If PerformImport Then
			
			// IMPORTING DATA
			ExecuteInfoBaseNodeExchangeAction(Cancel, 
															InfoBaseNode, 
															Enums.ActionsOnExchange.DataImport, 
															ExchangeMessageTransportKind
			);
			
		EndIf;
		
		If PerformExport Then
			
			// EXPORTING DATA
			ExecuteInfoBaseNodeExchangeAction(Cancel, 
															InfoBaseNode, 
															Enums.ActionsOnExchange.DataExport, 
															ExchangeMessageTransportKind
			);
			
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
//  Cancel                    - Boolean - cancel flag. It is set to True if errors occur
//                              during the scenario execution.
//  ExchangeExecutionSettings - CatalogRef.DataExchangeScenarios - catalog item whose
//                              attribute values will be used for performing the data
//                              exchange.
//  LineNumber                - Number - row number, for which the exchange will be
//                              performed. If it is not specified, the data exchange
//                              will be performed for all rows.
// 
Procedure ExecuteDataExchangeByDataExchangeScenario(Cancel, ExchangeExecutionSettings, LineNumber = Undefined) Export
	
	CheckUseDataExchange();
	
	QueryText = "
	|SELECT
	|	ExchangeExecutionSettingsExchangeSettings.Ref                   AS ExchangeExecutionSettings,
	|	ExchangeExecutionSettingsExchangeSettings.LineNumber            AS LineNumber,
	|	ExchangeExecutionSettingsExchangeSettings.CurrentAction         AS CurrentAction,
	|	ExchangeExecutionSettingsExchangeSettings.ExchangeTransportKind AS ExchangeTransportKind,
	|	ExchangeExecutionSettingsExchangeSettings.InfoBaseNode          AS InfoBaseNode,
	|	ExchangeExecutionSettingsExchangeSettings.TransactionItemCount  AS TransactionItemCount,
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
	
	// Setting privileged mode
	SetPrivilegedMode(True);
	
	LineNumberCondition = ?(LineNumber = Undefined, "", "AND ExchangeExecutionSettingsExchangeSettings.LineNumber = &LineNumber");
	
	QueryText = StrReplace(QueryText, "[LineNumberCondition]", LineNumberCondition);
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("ExchangeExecutionSettings", ExchangeExecutionSettings);
	Query.SetParameter("LineNumber", LineNumber);
	
	Selection = Query.Execute().Choose();
	
	While Selection.Next() Do
		
		If Selection.ExchangeOverExternalConnection Then
			
			ExecuteExchangeActionForInfoBaseNodeByExternalConnection(Cancel, Selection.InfoBaseNode, Selection.CurrentAction, Selection.TransactionItemCount);
			
		ElsIf Selection.ExchangeOverWebService Then
			
			ExecuteExchangeOverWebServiceActionForInfoBaseNode(Cancel, Selection.InfoBaseNode, Selection.CurrentAction);
			
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
			MessageString = NStr("en = 'Data exchange process started by %1 setting'");
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
//  ExchangeScenarioCode – String – DataExchangeScenarios catalog item code, for which 
//                         the exchange will be executed.
// 
Procedure ExecuteDataExchangeWithScheduledJob(ExchangeScenarioCode) Export
	
	If IsBlankString(UserName()) Then
		SetPrivilegedMode(True);
	EndIf;
	
	CheckUseDataExchange();
	
	If Not ValueIsFilled(ExchangeScenarioCode) Then
		Raise NStr("en = 'The data exchange scenario is not specified.'");
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
	
	Selection = Query.Execute().Choose();
	
	If Selection.Next() Then
		
		// Performing the exchange using scenario
		ExecuteDataExchangeByDataExchangeScenario(False, Selection.Ref);
		
	Else
		
		MessageString = NStr("en = 'The data exchange script with the %1 code is not found.'");
		MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, ExchangeScenarioCode);
		Raise MessageString;
	EndIf;
	
EndProcedure

// Received the exchange message and puts it into the temporary OS directory.
//
// Parameters:
//  Cancel                       - Boolean - cancel flag. It is set to True if errors 
//                                 occur during the procedure execution.
//  InfoBaseNode                 – ExchangePlanRef – exchange plan node, for which the
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
Function GetExchangeMessageToTemporaryDirectory(Cancel, InfoBaseNode, ExchangeMessageTransportKind) Export
	
	// Return value
	Result = New Structure;
	Result.Insert("TempExchangeMessageDirectory", "");
	Result.Insert("ExchangeMessageFileName",      "");
	Result.Insert("DataPackageFileID",            Undefined);
	
	ExchangeSettingsStructure = DataExchangeCached.GetTransportSettingsStructure(InfoBaseNode, ExchangeMessageTransportKind);
	
	ExchangeSettingsStructure.ExchangeExecutionResult = Undefined;
	ExchangeSettingsStructure.StartDate = CurrentSessionDate();
	
	// Canceling message receiving and setting the exchange state to Canceled if settings
	// contain errors.
	If ExchangeSettingsStructure.Cancel Then
		
		NString = NStr("en = 'Error initializing exchange message transport processing.'");
		CommonUseClientServer.MessageToUser(NString,,,, Cancel);
		
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
		
		NString = NStr("en = 'Error receiving exchange messages.'");
		CommonUseClientServer.MessageToUser(NString,,,, Cancel);
		
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

Function GetExchangeMessageFromCorrespondentInfoBaseToTempDirectory(Cancel, InfoBaseNode) Export
	
	// Return value
	Result = New Structure;
	Result.Insert("TempExchangeMessageDirectory", "");
	Result.Insert("ExchangeMessageFileName",      "");
	Result.Insert("DataPackageFileID",            Undefined);
	
	ExchangePlanName = DataExchangeCached.GetExchangePlanName(InfoBaseNode);
	CurrentExchangePlanNode = DataExchangeCached.GetThisExchangePlanNode(ExchangePlanName);
	CurrentExchangePlanNodeCode = CommonUse.GetAttributeValue(CurrentExchangePlanNode, "Code");
	
	MessageFileNamePattern = GetMessageFileNamePattern(CurrentExchangePlanNode, InfoBaseNode, False);
	
	// Parameters to be defined in the function
	ExchangeMessageFileDate = Date('00010101');
	ExchangeMessageDirectoryName = "";
	ErrorMessageString = "";
	
	If Not CreateTempExchangeMessageDirectory(ExchangeMessageDirectoryName, ErrorMessageString) Then
		
		// Displaying error message
		Message = NStr("en = 'Error receiving exchange message: %1'");
		Message = StringFunctionsClientServer.SubstituteParametersInString(Message, ErrorMessageString);
		CommonUseClientServer.MessageToUser(Message,,,, Cancel);
		Return Result;
	EndIf;
	
	// Getting external connection for the infobase node
	ExternalConnection = DataExchangeCached.GetExternalConnectionForInfoBaseNode(InfoBaseNode, ErrorMessageString);
	
	If ExternalConnection = Undefined Then
		
		// Displaying error message
		Message = NStr("en = 'Error establishing connection with the correspondent infobase: %1'");
		Message = StringFunctionsClientServer.SubstituteParametersInString(Message, ErrorMessageString);
		CommonUseClientServer.MessageToUser(Message,,,, Cancel);
		
		// Adding two records to the event log: one for data import and one for data export
		ExchangeSettingsStructure = New Structure("EventLogMessageKey");
		ExchangeSettingsStructure.EventLogMessageKey = GetEventLogMessageKey(InfoBaseNode, Enums.ActionsOnExchange.DataImport);
		WriteEventLogDataExchange(Message, ExchangeSettingsStructure, True);
		
		Return Result;
	EndIf;
	
	ExchangeMessageFileName = CommonUseClientServer.GetFullFileName(ExchangeMessageDirectoryName, MessageFileNamePattern + ".xml");
	
	ExternalConnection.DataExchangeExternalConnection.ExportForInfoBaseNode(Cancel, ExchangePlanName, CurrentExchangePlanNodeCode, ExchangeMessageFileName, ErrorMessageString);
	
	If Cancel Then
		
		// Displaying error message
		Message = NStr("en = 'Error exporting data from the correspondent infobase: %1'");
		Message = StringFunctionsClientServer.SubstituteParametersInString(Message, ErrorMessageString);
		CommonUseClientServer.MessageToUser(Message,,,, Cancel);
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

Function GetExchangeMessageToTempDirectoryFromCorrespondentInfoBaseOverWebService(
	Cancel,
	InfoBaseNode,
	FileID,
	LongAction,
	ActionID
	) Export
	
	// Return value
	Result = New Structure;
	Result.Insert("TempExchangeMessageDirectory", "");
	Result.Insert("ExchangeMessageFileName",      "");
	Result.Insert("DataPackageFileID",            Undefined);
	
	ExchangePlanName = DataExchangeCached.GetExchangePlanName(InfoBaseNode);
	CurrentExchangePlanNode = DataExchangeCached.GetThisExchangePlanNode(ExchangePlanName);
	CurrentExchangePlanNodeCode = CommonUse.GetAttributeValue(CurrentExchangePlanNode, "Code");
	
	// Parameters to be defined in the function
	ExchangeMessageDirectoryName = "";
	ExchangeMessageFileName = "";
	ExchangeMessageFileDate = Date('00010101');
	ErrorMessageString = "";
	
	// Getting the web service proxy for the infobase node
	Proxy = DataExchangeCached.GetWSProxyForInfoBaseNode(InfoBaseNode, ErrorMessageString);
	
	If Proxy = Undefined Then
		
		Cancel = True;
		Message = NStr("en = 'Error establishing connection with the correspondent infobase: %1'");
		Message = StringFunctionsClientServer.SubstituteParametersInString(Message, ErrorMessageString);
		ExchangeSettingsStructure = New Structure("EventLogMessageKey");
		ExchangeSettingsStructure.EventLogMessageKey = GetEventLogMessageKey(InfoBaseNode, Enums.ActionsOnExchange.DataImport);
		WriteEventLogDataExchange(Message, ExchangeSettingsStructure, True);
		
		Return Result;
	EndIf;
	
	Try
		
		Proxy.UploadData(
		ExchangePlanName,
		CurrentExchangePlanNodeCode,
		FileID,
		LongAction,
		ActionID,
		True
		);
		
	Except
		
		Cancel = True;
		Message = NStr("en = 'Error exporting data in the correspondent infobase: %1'");
		Message = StringFunctionsClientServer.SubstituteParametersInString(Message, DetailErrorDescription(ErrorInfo()));
		ExchangeSettingsStructure = New Structure("EventLogMessageKey");
		ExchangeSettingsStructure.EventLogMessageKey = GetEventLogMessageKey(InfoBaseNode, Enums.ActionsOnExchange.DataImport);
		WriteEventLogDataExchange(Message, ExchangeSettingsStructure, True);
		
		Return Result;
	EndTry;
	
	If LongAction Then
		ExchangeSettingsStructure = New Structure("EventLogMessageKey");
		ExchangeSettingsStructure.EventLogMessageKey = GetEventLogMessageKey(InfoBaseNode, Enums.ActionsOnExchange.DataImport);
		WriteEventLogDataExchange(NStr("en = 'Waiting for data from the correspondent infobase...'"), ExchangeSettingsStructure);
		Return Result;
	EndIf;
	
	Try
		FileTransferServiceFileName = GetFileFromStorageInService(New UUID(FileID), InfoBaseNode);
	Except
		
		Cancel = True;
		Message = NStr("en = 'Error receiving exchange message from the file transfer service: %1'");
		Message = StringFunctionsClientServer.SubstituteParametersInString(Message, DetailErrorDescription(ErrorInfo()));
		ExchangeSettingsStructure = New Structure("EventLogMessageKey");
		ExchangeSettingsStructure.EventLogMessageKey = GetEventLogMessageKey(InfoBaseNode, Enums.ActionsOnExchange.DataImport);
		WriteEventLogDataExchange(Message, ExchangeSettingsStructure, True);
		
		Return Result;
	EndTry;
	
	If Not CreateTempExchangeMessageDirectory(ExchangeMessageDirectoryName, ErrorMessageString) Then
		
		Cancel = True;
		Message = NStr("en = 'Error receiving exchange message: %1'");
		Message = StringFunctionsClientServer.SubstituteParametersInString(Message, ErrorMessageString);
		ExchangeSettingsStructure = New Structure("EventLogMessageKey");
		ExchangeSettingsStructure.EventLogMessageKey = GetEventLogMessageKey(InfoBaseNode, Enums.ActionsOnExchange.DataImport);
		WriteEventLogDataExchange(Message, ExchangeSettingsStructure, True);
		
		Return Result;
	EndIf;
	
	MessageFileNamePattern = GetMessageFileNamePattern(CurrentExchangePlanNode, InfoBaseNode, False);
	
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

Function GetExchangeMessageToTempDirectoryFromCorrespondentInfoBaseOverWebServiceFinishLongAction(
	Cancel,
	InfoBaseNode,
	FileID
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
		
		FileTransferServiceFileName = GetFileFromStorageInService(New UUID(FileID), InfoBaseNode);
	Except
		
		Cancel = True;
		Message = NStr("en = 'Error receiving exchange message from the file transfer service: %1'");
		Message = StringFunctionsClientServer.SubstituteParametersInString(Message, DetailErrorDescription(ErrorInfo()));
		ExchangeSettingsStructure = New Structure("EventLogMessageKey");
		ExchangeSettingsStructure.EventLogMessageKey = GetEventLogMessageKey(InfoBaseNode, Enums.ActionsOnExchange.DataImport);
		WriteEventLogDataExchange(Message, ExchangeSettingsStructure, True);
		
		Return Result;
	EndTry;
	
	If Not CreateTempExchangeMessageDirectory(ExchangeMessageDirectoryName, ErrorMessageString) Then
		
		Cancel = True;
		Message = NStr("en = 'Error receiving exchange message: %1'");
		Message = StringFunctionsClientServer.SubstituteParametersInString(Message, ErrorMessageString);
		ExchangeSettingsStructure = New Structure("EventLogMessageKey");
		ExchangeSettingsStructure.EventLogMessageKey = GetEventLogMessageKey(InfoBaseNode, Enums.ActionsOnExchange.DataImport);
		WriteEventLogDataExchange(Message, ExchangeSettingsStructure, True);
		
		Return Result;
	EndIf;
	
	ExchangePlanName = DataExchangeCached.GetExchangePlanName(InfoBaseNode);
	CurrentExchangePlanNode = DataExchangeCached.GetThisExchangePlanNode(ExchangePlanName);
	
	MessageFileNamePattern = GetMessageFileNamePattern(CurrentExchangePlanNode, InfoBaseNode, False);
	
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

Procedure ExecuteDataExchangeForInfoBaseNodeFinishLongAction(Cancel, Val InfoBaseNode,
	Val FileID,
	Val ActionStartDate) Export
	
	Try
		FileExchangeMessages = GetFileFromStorageInService(New UUID(FileID), InfoBaseNode);
	Except
		AddExchangeFinishedWithErrorEventLogMessage(InfoBaseNode,
		Enums.ActionsOnExchange.DataImport,
		ActionStartDate,
		DetailErrorDescription(ErrorInfo())
		);
		Cancel = True;
		Return;
	EndTry;
	
	// Importing the exchange message file into the current infobase
	Try
		ExecuteDataExchangeForInfoBaseNodeOverFileOrString(
			InfoBaseNode,
			FileExchangeMessages,
			Enums.ActionsOnExchange.DataImport
		);
	Except
		AddExchangeFinishedWithErrorEventLogMessage(InfoBaseNode,
		Enums.ActionsOnExchange.DataImport,
		ActionStartDate,
		DetailErrorDescription(ErrorInfo())
		);
		Cancel = True;
	EndTry;
	
	Try
		DeleteFiles(FileExchangeMessages);
	Except
	EndTry;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for working through external connection

Procedure ExportToTempStorageForInfoBaseNode(Val ExchangePlanName, Val InfoBaseNodeCode, Address) Export
	
	ExchangeMessageFullFileName = GetTempFileName("xml");
	
	ExecuteDataExchangeForInfoBaseNodeOverFileOrString(
		Undefined,
		ExchangeMessageFullFileName,
		Enums.ActionsOnExchange.DataExport,
		ExchangePlanName,
		InfoBaseNodeCode
	);
	
	Address = PutToTempStorage(New BinaryData(ExchangeMessageFullFileName));
	
	Try
		DeleteFiles(ExchangeMessageFullFileName);
	Except
	EndTry;
	
EndProcedure

Procedure ExportToFileTransferServiceForInfoBaseNode(Val ExchangePlanName,
	Val InfoBaseNodeCode,
	Val FileID) Export
	
	SetPrivilegedMode(True);
	
	MessageFileName = CommonUseClientServer.GetFullFileName(
		TempFileStorageDirectory(),
		UniqueExchangeMessageFileName()
	);
	
	ExecuteDataExchangeForInfoBaseNodeOverFileOrString(
		Undefined,
		MessageFileName,
		Enums.ActionsOnExchange.DataExport,
		ExchangePlanName,
		InfoBaseNodeCode
	);
	
	PutFileToStorage(MessageFileName, FileID);
	
EndProcedure

Procedure ExportForInfoBaseNodeViaFile(Val ExchangePlanName,
	Val InfoBaseNodeCode,
	Val ExchangeMessageFullFileName) Export
	
	ExecuteDataExchangeForInfoBaseNodeOverFileOrString(
		Undefined,
		ExchangeMessageFullFileName,
		Enums.ActionsOnExchange.DataExport,
		ExchangePlanName,
		InfoBaseNodeCode
	);
	
EndProcedure

Procedure ImportInfoBaseNodeViaFile(Cancel, Val InfoBaseNode, Val ExchangeMessageFullFileName) Export
	
	Try
		ExecuteDataExchangeForInfoBaseNodeOverFileOrString(InfoBaseNode, ExchangeMessageFullFileName, Enums.ActionsOnExchange.DataImport);
	Except
		Cancel = True;
	EndTry;
	
EndProcedure

Procedure ExportForInfoBaseNodeViaString(Val ExchangePlanName, Val InfoBaseNodeCode, ExchangeMessage) Export
	
	ExecuteDataExchangeForInfoBaseNodeOverFileOrString(Undefined,
												"",
												Enums.ActionsOnExchange.DataExport,
												ExchangePlanName,
												InfoBaseNodeCode,
												ExchangeMessage
	);
	
EndProcedure

Procedure ImportForInfoBaseNodeViaString(Val ExchangePlanName, Val InfoBaseNodeCode, ExchangeMessage) Export
	
	ExecuteDataExchangeForInfoBaseNodeOverFileOrString(Undefined,
												"",
												Enums.ActionsOnExchange.DataImport,
												ExchangePlanName,
												InfoBaseNodeCode,
												ExchangeMessage
	);
	
EndProcedure

Procedure ImportForInfoBaseNodeFromFileTransferService(Val ExchangePlanName,
	Val InfoBaseNodeCode,
	Val FileID) Export
	
	SetPrivilegedMode(True);
	
	TempFileName = GetFileFromStorage(FileID);
	
	Try
		ExecuteDataExchangeForInfoBaseNodeOverFileOrString(
			Undefined,
			TempFileName,
			Enums.ActionsOnExchange.DataImport,
			ExchangePlanName,
			InfoBaseNodeCode
		);
	Except
		Try
			DeleteFiles(TempFileName);
		Except
		EndTry;
		Raise;
	EndTry;
	
	Try
		DeleteFiles(TempFileName);
	Except
	EndTry;
	
EndProcedure

Procedure ExecuteDataExchangeForInfoBaseNodeOverFileOrString(InfoBaseNode = Undefined,
																			ExchangeMessageFullFileName = "",
																			ActionOnExchange,
																			ExchangePlanName = "",
																			InfoBaseNodeCode = "",
																			ExchangeMessage = ""
	)
	
	SetPrivilegedMode(True);
	
	If InfoBaseNode = Undefined Then
		
		InfoBaseNode = ExchangePlans[ExchangePlanName].FindByCode(InfoBaseNodeCode);
		
		If InfoBaseNode.IsEmpty() Then
			ErrorMessageString = NStr("en = 'The %1 exchange plan node with the %2 code is not found.'");
			ErrorMessageString = StringFunctionsClientServer.SubstituteParametersInString(ErrorMessageString, ExchangePlanName, InfoBaseNodeCode);
			Raise ErrorMessageString;
		EndIf;
		
	EndIf;
	
	// INITIALIZING THE DATA EXCHANGE
	ExchangeSettingsStructure = DataExchangeCached.GetExchangeSettingStructureForInfoBaseNode(InfoBaseNode, ActionOnExchange, Undefined, False);
	
	If ExchangeSettingsStructure.Cancel Then
		ErrorMessageString = NStr("en = 'Error initializing data exchange process.'");
		AddExchangeFinishEventLogMessage(ExchangeSettingsStructure);
		Raise ErrorMessageString;
	EndIf;
	
	ExchangeSettingsStructure.ExchangeExecutionResult = Undefined;
	ExchangeSettingsStructure.StartDate = CurrentSessionDate();
	
	MessageString = NStr("en = 'Data exchange process started for %1 node'");
	MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, ExchangeSettingsStructure.InfobaseNodeDescription);
	WriteEventLogDataExchange(MessageString, ExchangeSettingsStructure);
	
	If ExchangeSettingsStructure.DoDataImport Then
		
		ReadMessageWithNodeChanges(ExchangeSettingsStructure, ExchangeMessageFullFileName, ExchangeMessage);
		
	ElsIf ExchangeSettingsStructure.DoDataExport Then
		
		WriteMessageWithNodeChanges(ExchangeSettingsStructure, ExchangeMessageFullFileName, ExchangeMessage);
		
	EndIf;
	
	AddExchangeFinishEventLogMessage(ExchangeSettingsStructure);
	
	If Not ExchangeExecutionResultCompleted(ExchangeSettingsStructure.ExchangeExecutionResult) Then
		Raise ExchangeSettingsStructure.ErrorMessageString;
	EndIf;
	
EndProcedure

Procedure AddExchangeOverExternalConnectionFinishEventLogMessage(ExchangeSettingsStructure) Export
	
	SetPrivilegedMode(True);
	
	AddExchangeFinishEventLogMessage(ExchangeSettingsStructure);
	
EndProcedure

Function ExchangeOverExternalConnectionSettingsStructure(Structure) Export
	
	CheckUseDataExchange();
	
	SetPrivilegedMode(True);
	
	InfoBaseNode = ExchangePlans[Structure.ExchangePlanName].FindByCode(Structure.CurrentExchangePlanNodeCode);
	
	ActionOnExchange = Enums.ActionsOnExchange[Structure.ExchangeActionString];
	
	ExchangeSettingsStructureExternalConnection = New Structure;
	ExchangeSettingsStructureExternalConnection.Insert("ExchangePlanName", Structure.ExchangePlanName);
	ExchangeSettingsStructureExternalConnection.Insert("DebugMode",                     Structure.DebugMode);
	
	ExchangeSettingsStructureExternalConnection.Insert("InfoBaseNode",             InfoBaseNode);
	ExchangeSettingsStructureExternalConnection.Insert("InfobaseNodeDescription", CommonUse.GetAttributeValue(InfoBaseNode, "Description"));
	
	ExchangeSettingsStructureExternalConnection.Insert("EventLogMessageKey",  GetEventLogMessageKey(InfoBaseNode, ActionOnExchange));
	ExchangeSettingsStructureExternalConnection.Insert("ExchangeLogFileName",          AddStringToFileName(Structure.ExchangeLogFileName, "ExternalConnection"));
	
	ExchangeSettingsStructureExternalConnection.Insert("ExchangeExecutionResult",        Undefined);
	ExchangeSettingsStructureExternalConnection.Insert("ExchangeExecutionResultString", "");
	
	ExchangeSettingsStructureExternalConnection.Insert("ActionOnExchange", ActionOnExchange);
	
	ExchangeSettingsStructureExternalConnection.Insert("ProcessedObjectCount", 0);
	
	ExchangeSettingsStructureExternalConnection.Insert("StartDate", Undefined);
	ExchangeSettingsStructureExternalConnection.Insert("EndDate", Undefined);
	
	ExchangeSettingsStructureExternalConnection.Insert("ExchangeMessage", "");
	ExchangeSettingsStructureExternalConnection.Insert("ErrorMessageString", "");
	
	ExchangeSettingsStructureExternalConnection.Insert("TransactionItemCount", Structure.TransactionItemCount);
	
	ExchangeSettingsStructureExternalConnection.Insert("IsDIBExchange", False);
	
	Return ExchangeSettingsStructureExternalConnection;
EndFunction

Function GetObjectConversionRulesViaExternalConnection(ExchangePlanName) Export
	
	SetPrivilegedMode(True);
	
	Return InformationRegisters.DataExchangeRules.GetReadObjectConversionRules(ExchangePlanName);
	
EndFunction

Procedure ExecuteInfoBaseNodeExchangeAction(Cancel, InfoBaseNode, ActionOnExchange, ExchangeMessageTransportKind) Export
	
	SetPrivilegedMode(True);
	
	// INITIALIZING THE DATA EXCHANGE
	ExchangeSettingsStructure = DataExchangeCached.GetExchangeSettingStructureForInfoBaseNode(InfoBaseNode, ActionOnExchange, ExchangeMessageTransportKind);
	
	If ExchangeSettingsStructure.Cancel Then
		
		// Canceling message receiving and setting the exchange state to Canceled if 
		// settings contain errors.
		AddExchangeFinishEventLogMessage(ExchangeSettingsStructure);
		
		Cancel = True;
		
		Return;
	EndIf;
	
	ExchangeSettingsStructure.ExchangeExecutionResult = Undefined;
	ExchangeSettingsStructure.StartDate = CurrentSessionDate();
	
	MessageString = NStr("en = 'Data exchange process started for the %1 node'");
	MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, ExchangeSettingsStructure.InfobaseNodeDescription);
	WriteEventLogDataExchange(MessageString, ExchangeSettingsStructure);
	
	// DATA EXCHANGE
	ExecuteDataExchangeOverFileResource(ExchangeSettingsStructure);
	
	AddExchangeFinishEventLogMessage(ExchangeSettingsStructure);
	
	If Not ExchangeExecutionResultCompleted(ExchangeSettingsStructure.ExchangeExecutionResult) Then
		
		Cancel = True;
		
	EndIf;
	
EndProcedure

Procedure ExecuteExchangeOverWebServiceActionForInfoBaseNode(Cancel,
																		InfoBaseNode,
																		ActionOnExchange,
																		LongAction = False,
																		ActionID = "",
																		FileID = "",
																		LongActionAllowed = False
	)
	
	SetPrivilegedMode(True);
	
	// INITIALIZING THE DATA EXCHANGE
	ExchangeSettingsStructure = DataExchangeCached.GetExchangeSettingStructureForInfoBaseNode(InfoBaseNode, ActionOnExchange, Enums.ExchangeMessageTransportKinds.WS, False);
	
	If ExchangeSettingsStructure.Cancel Then
		// Canceling message receiving and setting the exchange state to Canceled if
		// settings contain errors.
		AddExchangeFinishEventLogMessage(ExchangeSettingsStructure);
		Cancel = True;
		Return;
	EndIf;
	
	ExchangeSettingsStructure.ExchangeExecutionResult = Undefined;
	ExchangeSettingsStructure.StartDate = CurrentSessionDate();
	
	MessageString = NStr("en = 'Data exchange process started for the %1 node'");
	MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, ExchangeSettingsStructure.InfobaseNodeDescription);
	WriteEventLogDataExchange(MessageString, ExchangeSettingsStructure);
	
	ErrorMessageString = "";
	
	// Getting the web service proxy for the infobase node
	Proxy = DataExchangeCached.GetWSProxyForInfoBaseNode(InfoBaseNode, ErrorMessageString);
	
	If Proxy = Undefined Then
		
		// Writing the message to the event log
		WriteEventLogDataExchange(ErrorMessageString, ExchangeSettingsStructure, True);
		
		// Canceling message receiving and setting the exchange state to Canceled if
		// settings contain errors.
		ExchangeSettingsStructure.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Canceled;
		AddExchangeFinishEventLogMessage(ExchangeSettingsStructure);
		Cancel = True;
		Return;
	EndIf;
	
	If ExchangeSettingsStructure.DoDataImport Then
		
		If ExchangeSettingsStructure.UseLargeDataTransfer Then
			
			FileExchangeMessages = "";
			
			Try
				
				Proxy.UploadData(ExchangeSettingsStructure.ExchangePlanName,
								ExchangeSettingsStructure.CurrentExchangePlanNodeCode,
								FileID,
								LongAction,
								ActionID,
								LongActionAllowed
				);
				
				If LongAction Then
					WriteEventLogDataExchange(NStr("en = 'Waiting for data from correspondent infobase...'"), ExchangeSettingsStructure);
					Return;
				EndIf;
				
				FileExchangeMessages = GetFileFromStorageInService(New UUID(FileID), InfoBaseNode);
			Except
				WriteEventLogDataExchange(DetailErrorDescription(ErrorInfo()), ExchangeSettingsStructure, True);
				ExchangeSettingsStructure.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Error;
				Cancel = True;
			EndTry;
			
			If Not Cancel Then
				
				ReadMessageWithNodeChanges(ExchangeSettingsStructure, FileExchangeMessages);
				
			EndIf;
			
			Try
				If Not IsBlankString(FileExchangeMessages) Then
					DeleteFiles(FileExchangeMessages);
				EndIf;
			Except
			EndTry;
			
		Else
			
			ExchangeMessageStorage = Undefined;
			
			Try
				Proxy.Upload(ExchangeSettingsStructure.ExchangePlanName, ExchangeSettingsStructure.CurrentExchangePlanNodeCode, ExchangeMessageStorage);
				
				ReadMessageWithNodeChanges(ExchangeSettingsStructure,, ExchangeMessageStorage.Get());
				
			Except
				WriteEventLogDataExchange(DetailErrorDescription(ErrorInfo()), ExchangeSettingsStructure, True);
				ExchangeSettingsStructure.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Error;
			EndTry;
			
		EndIf;
		
	ElsIf ExchangeSettingsStructure.DoDataExport Then
		
		If ExchangeSettingsStructure.UseLargeDataTransfer Then
			
			FileExchangeMessages = CommonUseClientServer.GetFullFileName(TempFileStorageDirectory(), UniqueExchangeMessageFileName());
			
			WriteMessageWithNodeChanges(ExchangeSettingsStructure, FileExchangeMessages);
			
			// Sending exchange messages only if data is exported successfully
			If ExchangeExecutionResultCompleted(ExchangeSettingsStructure.ExchangeExecutionResult) Then
				
				Try
					
					FileIDString = String(PutFileToStorageInService(FileExchangeMessages, InfoBaseNode));
					
					Try
						DeleteFiles(FileExchangeMessages);
					Except
					EndTry;
					
					Proxy.DownloadData(ExchangeSettingsStructure.ExchangePlanName,
									ExchangeSettingsStructure.CurrentExchangePlanNodeCode,
									FileIDString,
									LongAction,
									ActionID,
									LongActionAllowed
					);
					
					If LongAction Then
						WriteEventLogDataExchange(NStr("en = 'Waiting for data import in correspondent infobase...'"), ExchangeSettingsStructure);
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

Procedure ExecuteExchangeActionForInfoBaseNodeByExternalConnection(Cancel, InfoBaseNode,
	ActionOnExchange,
	TransactionItemCount)
	
	SetPrivilegedMode(True);
	
	// INITIALIZING THE DATA EXCHANGE
	ExchangeSettingsStructure = GetExchangeSettingsStructureForExternalConnection(
		InfoBaseNode,
		ActionOnExchange,
		TransactionItemCount
	);
	
	ExchangeSettingsStructure.StartDate = CurrentSessionDate();
	
	WriteLogEventDataExchangeStart(ExchangeSettingsStructure);
	
	If ExchangeSettingsStructure.Cancel Then
		// Canceling message receiving and setting the exchange state to Canceled if
		// settings contain errors.
		ExchangeSettingsStructure.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Canceled;
		AddExchangeFinishEventLogMessage(ExchangeSettingsStructure);
		Cancel = True;
		Return;
	EndIf;
	
	ErrorMessageString = "";
	
	// Getting the external connection for the infobase node
	ExternalConnection = DataExchangeCached.GetExternalConnectionForInfoBaseNode(
		InfoBaseNode,
		ErrorMessageString
	);
	
	If ExternalConnection = Undefined Then
		
		// Writing the message to the event log
		WriteEventLogDataExchange(ErrorMessageString, ExchangeSettingsStructure, True);
		
		// Canceling message receiving and setting the exchange state to Canceled if
		// settings contain errors.
		ExchangeSettingsStructure.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Canceled;
		AddExchangeFinishEventLogMessage(ExchangeSettingsStructure);
		Cancel = True;
		Return;
	EndIf;
	
	// INITIALIZING THE DATA EXCHANGE (THROUGH THE EXTERNAL CONNECTION)
	Structure = New Structure("ExchangePlanName, CurrentExchangePlanNodeCode, DebugMode, ExchangeLogFileName, TransactionItemCount");
	FillPropertyValues(Structure, ExchangeSettingsStructure);
	
	// Reversing enumeration values
	ExchangeActionString = ?(ActionOnExchange = Enums.ActionsOnExchange.DataExport,
								CommonUse.EnumValueName(Enums.ActionsOnExchange.DataImport),
								CommonUse.EnumValueName(Enums.ActionsOnExchange.DataExport));
	
	
	Structure.Insert("ExchangeActionString", ExchangeActionString);
	
	Try
		ExchangeSettingsStructureExternalConnection = ExternalConnection.DataExchangeExternalConnection.ExchangeSettingsStructure(Structure);
	Except
		// Writing the message to the event log
		WriteEventLogDataExchange(DetailErrorDescription(ErrorInfo()), ExchangeSettingsStructure, True);
		
		// Canceling message receiving and setting the exchange state to Canceled if
		// settings contain errors.
		ExchangeSettingsStructure.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Canceled;
		AddExchangeFinishEventLogMessage(ExchangeSettingsStructure);
		Cancel = True;
		Return;
	EndTry;
	
	ExchangeSettingsStructure.ExchangeExecutionResult = Undefined;
	ExchangeSettingsStructureExternalConnection.StartDate = CurrentSessionDate();
	
	ExternalConnection.DataExchangeExternalConnection.WriteLogEventDataExchangeStart(ExchangeSettingsStructureExternalConnection);
	
	// DATA EXCHANGE
	If ExchangeSettingsStructure.DoDataImport Then
		
		// Getting exchange rules from the correspondent infobase
		ObjectConversionRules = ExternalConnection.DataExchangeExternalConnection.GetObjectConversionRules(ExchangeSettingsStructureExternalConnection.ExchangePlanName);
		
		If ObjectConversionRules = Undefined Then
			
			// Exchange rules must be specified
			NString = NStr("en = 'Conversion rules for the %1 exchange plan in the second infobase is not set. The exchange is canceled.'");
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
		DataExchangeDataProcessorExternalConnection = ExternalConnection.DataProcessors.InfoBaseObjectConversion.Create();
		DataExchangeDataProcessorExternalConnection.ExchangeMode = "Data";
		DataExchangeDataProcessorExternalConnection.SavedSettings = ObjectConversionRules;
		DataExchangeDataProcessorExternalConnection.RestoreRulesFromInternalFormat();
		
		// Specifying exchange nodes
		DataExchangeDataProcessorExternalConnection.NodeForExchange = ExchangeSettingsStructureExternalConnection.InfoBaseNode;
		DataExchangeDataProcessorExternalConnection.BackgroundExchangeNode = Undefined;
		DataExchangeDataProcessorExternalConnection.DontExportObjectsByRefs = True;
		DataExchangeDataProcessorExternalConnection.ExchangeRuleFileName = "1";
		
		DataExchangeDataProcessorExternalConnection.ExternalConnection = Undefined;
		DataExchangeDataProcessorExternalConnection.DataImportExecutedInExternalConnection = False;
		
		SetCommonParametersForDataExchangeProcessing(DataExchangeDataProcessorExternalConnection, ExchangeSettingsStructureExternalConnection);
		
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
		DataProcessorForDataImport = ExternalConnection.DataProcessors.InfoBaseObjectConversion.Create();
		DataProcessorForDataImport.ExchangeMode = "Import";
		DataProcessorForDataImport.ExchangeNodeDataImport = ExchangeSettingsStructureExternalConnection.InfoBaseNode;
		DataProcessorForDataImport.ExecutingDataImportViaExternalConnection = True;
		
		SetCommonParametersForDataExchangeProcessing(DataProcessorForDataImport, ExchangeSettingsStructureExternalConnection);
		
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

Procedure ExecuteDataExchangeOverFileResource(ExchangeSettingsStructure)
	
	ExecuteExchangeMessageTransportBeforeProcessing(ExchangeSettingsStructure);
	
	If ExchangeSettingsStructure.DoDataImport Then
		
		If ExchangeSettingsStructure.ExchangeExecutionResult = Undefined Then
			
			ExecuteExchangeMessageTransportReceiving(ExchangeSettingsStructure);
			
		EndIf;
		
		// Importing data only if the exchange message is received successfully 
		If ExchangeSettingsStructure.ExchangeExecutionResult = Undefined Then
			
			ReadMessageWithNodeChanges(ExchangeSettingsStructure, ExchangeSettingsStructure.ExchangeMessageTransportDataProcessor.ExchangeMessageFileName());
			
		EndIf;
		
	ElsIf ExchangeSettingsStructure.DoDataExport Then
		
		// Exporting data
		If ExchangeSettingsStructure.ExchangeExecutionResult = Undefined Then
			
			WriteMessageWithNodeChanges(ExchangeSettingsStructure, ExchangeSettingsStructure.ExchangeMessageTransportDataProcessor.ExchangeMessageFileName());
			
		EndIf;
		
		// Sending exchange messages only if data is exported successfully
		If ExchangeExecutionResultCompleted(ExchangeSettingsStructure.ExchangeExecutionResult) Then
			
			ExecuteExchangeMessageTransportSending(ExchangeSettingsStructure);
			
		EndIf;
		
	EndIf;
	
	ExecuteExchangeMessageTransportAfterProcessing(ExchangeSettingsStructure);
	
EndProcedure

// Writes infobase node changes to the file in the temporary directory.
//
// Parameters:
//  ExchangeSettingsStructure - Structure - structure with all required data and objects
//                              for performing the exchange.
// 
Procedure WriteMessageWithNodeChanges(ExchangeSettingsStructure, Val ExchangeMessageFileName = "", ExchangeMessage = "")
	
	// {HANDLER: BeforeSendData} Start. Redefining the standard data export processor
	StandardProcessing = True;
	ProcessedObjectCount = 0;
	
	Try
		BeforeSendDataHandler(StandardProcessing,
										ExchangeSettingsStructure.InfoBaseNode,
										ExchangeMessageFileName,
										ExchangeMessage,
										ExchangeSettingsStructure.TransactionItemCount,
										ExchangeSettingsStructure.EventLogMessageKey,
										ProcessedObjectCount
		);
		
	Except
		
		ErrorMessageString = DetailErrorDescription(ErrorInfo());
		
		WriteLogEvent(ExchangeSettingsStructure.EventLogMessageKey, EventLogLevel.Error,
				ExchangeSettingsStructure.InfoBaseNode.Metadata(), 
				ExchangeSettingsStructure.InfoBaseNode, ErrorMessageString
		);
		ExchangeSettingsStructure.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Error;
		ExchangeSettingsStructure.ErrorMessageString = ErrorMessageString;
		Return;
	EndTry;
	
	If StandardProcessing = False Then
		ExchangeSettingsStructure.ProcessedObjectCount = ProcessedObjectCount;
		Return;
	EndIf;
	// {HANDLER: BeforeSendData} End
	
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
		
		If ExchangeSettingsStructure.ExchangeByObjectConversionRules Then // Universal exchange (exchange with conversion rules)
			
			// Getting the initialized exchange data processor
			DataExchangeXMLDataProcessor = ExchangeSettingsStructure.DataExchangeDataProcessor;
			DataExchangeXMLDataProcessor.ExchangeFileName = ExchangeMessageFileName;
			
			// Data export
			DataExchangeXMLDataProcessor.ExecuteDataExport();
			
			ExchangeSettingsStructure.ExchangeExecutionResult = DataExchangeXMLDataProcessor.ExchangeExecutionResult();
			
			// Commiting the data exchange performing state
			ExchangeSettingsStructure.ProcessedObjectCount = DataExchangeXMLDataProcessor.ExportedObjectCounter();
			ExchangeSettingsStructure.ExchangeMessage           = DataExchangeXMLDataProcessor.CommentOnDataExport;
			ExchangeSettingsStructure.ErrorMessageString      = DataExchangeXMLDataProcessor.ErrorMessageString();
			
		Else // Standard exchange (platform serialization)
			
			Cancel = False;
			ProcessedObjectCount = 0;
			
			ExecuteStandardNodeChangeExport(Cancel,
								ExchangeSettingsStructure.InfoBaseNode,
								ExchangeMessageFileName,
								ExchangeMessage,
								ExchangeSettingsStructure.TransactionItemCount,
								ExchangeSettingsStructure.EventLogMessageKey,
								ProcessedObjectCount
			);
			
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
//  ExchangeSettingsStructure - Structure - structure with all required data and objects
//                              for performing the exchange.
// 
Procedure ReadMessageWithNodeChanges(ExchangeSettingsStructure, Val ExchangeMessageFileName = "", ExchangeMessage = "")
	
	// {HANDLER: BeforeReceiveData} Start. Redefining the standard import data processor
	StandardProcessing = True;
	ProcessedObjectCount = 0;
	
	Try
		BeforeReceiveDataHandler(StandardProcessing,
										ExchangeSettingsStructure.InfoBaseNode,
										ExchangeMessageFileName,
										ExchangeMessage,
										ExchangeSettingsStructure.TransactionItemCount,
										ExchangeSettingsStructure.EventLogMessageKey,
										ProcessedObjectCount
		);
		
	Except
		ErrorMessageString = DetailErrorDescription(ErrorInfo());
		
		WriteLogEvent(ExchangeSettingsStructure.EventLogMessageKey, EventLogLevel.Error,
				ExchangeSettingsStructure.InfoBaseNode.Metadata(), 
				ExchangeSettingsStructure.InfoBaseNode, ErrorMessageString
		);
		ExchangeSettingsStructure.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Error;
		ExchangeSettingsStructure.ErrorMessageString = ErrorMessageString;
		Return;
	EndTry;
	
	If StandardProcessing = False Then
		ExchangeSettingsStructure.ProcessedObjectCount = ProcessedObjectCount;
		Return;
	EndIf;
	// {HANDLER: BeforeReceiveData} End
	
	If ExchangeSettingsStructure.IsDIBExchange Then // Exchange in DIB
		
		Cancel = False;
		
		// Getting the exchange data processor
		DataExchangeDataProcessor = ExchangeSettingsStructure.DataExchangeDataProcessor;
		
		// Setting the name of the exchange message file to be read
		DataExchangeDataProcessor.SetExchangeMessageFileName(ExchangeMessageFileName);
		
		DataExchangeDataProcessor.ExecuteDataImport(Cancel);
		
		If Cancel Then
			
			ExchangeSettingsStructure.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Error;
			
		EndIf;
		
	Else
		
		If ExchangeSettingsStructure.ExchangeByObjectConversionRules Then // Universal exchange (exchange with conversion rules)
			
			// Getting the initialized exchange data processor
			DataExchangeXMLDataProcessor = ExchangeSettingsStructure.DataExchangeDataProcessor;
			DataExchangeXMLDataProcessor.ExchangeFileName = ExchangeMessageFileName;
			
			// Data import
			DataExchangeXMLDataProcessor.ExecuteDataImport();
			
			ExchangeSettingsStructure.ExchangeExecutionResult = DataExchangeXMLDataProcessor.ExchangeExecutionResult();
			
			// Commiting the data exchange performing state
			ExchangeSettingsStructure.ProcessedObjectCount = DataExchangeXMLDataProcessor.ImportedObjectCounter();
			ExchangeSettingsStructure.ExchangeMessage           = DataExchangeXMLDataProcessor.CommentOnDataImport;
			ExchangeSettingsStructure.ErrorMessageString      = DataExchangeXMLDataProcessor.ErrorMessageString();
			
		Else // Standard exchange (platform serialization)
			
			ProcessedObjectCount = 0;
			ExchangeExecutionResult = Undefined;
			
			ExecuteStandardNodeChangeImport(
								ExchangeSettingsStructure.InfoBaseNode,
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
// Exchange with serialization methods

// Records changes for the exchange message.
// Can be applied if both infobases have the same metadata structures of all objects 
// that take part in the exchange.
//
Procedure ExecuteStandardNodeChangeExport(Cancel,
							InfoBaseNode,
							FileName,
							ExchangeMessage,
							TransactionItemCount = 0,
							EventLogMessageKey = "Data exchange",
							ProcessedObjectCount = 0
	)
	
	InitialDataExport = InitialDataExportFlagIsSet(InfoBaseNode);
	
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
	
	WriteMessage.BeginWrite(XMLWriter, InfoBaseNode);
	
	// Counting the number of written objects
	WrittenObjectCount = 0;
	ProcessedObjectCount = 0;
	
	UseTransactions = TransactionItemCount <> 1;
	
	If UseTransactions Then
		
		// Beginning a transaction
		BeginTransaction();
		
	EndIf;
	
	Try
		
		RefreshORMCachedValuesIfNecessary();
		
		ExchangePlanName = DataExchangeCached.GetExchangePlanName(WriteMessage.Recipient);
		
		// Getting the changed data sample
		ChangeSelection = ExchangePlans.SelectChanges(WriteMessage.Recipient, WriteMessage.MessageNo);
		
		While ChangeSelection.Next() Do
			
			Data = ChangeSelection.Get();
			
			ProcessedObjectCount = ProcessedObjectCount + 1;
			
			// Checking whether the object passes the ORR filter.
			// If the object does not pass the ORR filter, sending object deletion to the 
			// receiver infobase.
			// If the object is a record set, verifying each record.
			// Record sets are exported always, even empty ones. Empty set is the object
			// deletion analog.
			ItemSending = DataItemSend.Auto;
			
			DataExchangeEvents.OnSendData(Data, ItemSending, WriteMessage.Recipient, ExchangePlanName, InitialDataExport);
			
			If ItemSending = DataItemSend.Delete Then
				
				Data = New ObjectDeletion(Data.Ref);
				
			ElsIf ItemSending = DataItemSend.Ignore Then
				
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
		
		// Completing message writing
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
			InfoBaseNode.Metadata(), InfoBaseNode, DetailErrorDescription(ErrorInfo()));
		
		Return;
	EndTry;
	
EndProcedure

// Reads changes from exchange messages.
// Can be applied if both infobases have the same metadata structures of all objects
// that take part in the exchange.
//
Procedure ExecuteStandardNodeChangeImport(
							InfoBaseNode,
							FileName = "",
							ExchangeMessage = "",
							TransactionItemCount = 0,
							EventLogMessageKey = "Data exchange",
							ProcessedObjectCount = 0,
							ExchangeExecutionResult = Undefined)
	
	ExchangePlanManager = DataExchangeCached.GetExchangePlanManager(InfoBaseNode);
	
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
				InfoBaseNode.Metadata(), InfoBaseNode, BriefErrorDescription(ErrorInfo));
			
		Else
			
			ExchangeExecutionResult = Enums.ExchangeExecutionResults.Error;
			
			WriteLogEvent(EventLogMessageKey, EventLogLevel.Error,
				InfoBaseNode.Metadata(), InfoBaseNode, DetailErrorDescription(ErrorInfo));
			
		EndIf;
		
		Return;
	EndTry;
	
	If MessageReader.Sender <> InfoBaseNode Then // The message is not intended for this node
		
		ExchangeExecutionResult = Enums.ExchangeExecutionResults.Error;
		
		WriteLogEvent(EventLogMessageKey, EventLogLevel.Error,
			InfoBaseNode.Metadata(), InfoBaseNode, NStr("en = 'Exchange message contains data for another infobase node.'"));
		
		Return;
	EndIf;
	
	// Deleting change records for the node that is the message sender.
	ExchangePlans.DeleteChangeRecords(MessageReader.Sender, MessageReader.ReceivedNo);
	
	If InitialDataExportFlagIsSet(MessageReader.Sender) Then
		
		InformationRegisters.CommonInfoBaseNodeSettings.ClearInitialDataExportFlag(MessageReader.Sender, MessageReader.ReceivedNo);
		
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
			
			IsObjectDeletion = (TypeOf(Data) = Type("ObjectDeletion"));
			
			ProcessedObjectCount = ProcessedObjectCount + 1;
			
			// Checking whether a change conflict exists
			If ExchangePlans.IsChangeRecorded(MessageReader.Sender, Data) Then
				
				MetadataObject = ?(IsObjectDeletion, Data.Ref.Metadata(), Data.Metadata());
				
				ExchangeExecutionResult = Enums.ExchangeExecutionResults.CompletedWithWarnings;
				
				ApplyChanges = ExchangePlanManager.ApplyObjectOnChangeConflict(MessageReader.Sender, Data);
				
				If ApplyChanges Then
					
					WriteLogEvent(EventLogMessageKey, EventLogLevel.Warning,
						MetadataObject, String(Data), NStr("en = 'Object change recording conflict. Object from this infobase was replaced with object version from exchange message.'"));
					
				Else
					
					WriteLogEvent(EventLogMessageKey, EventLogLevel.Warning,
						MetadataObject, String(Data), NStr("en = 'Object change recording conflict. Object from this infobase was not changed."));
					
					Continue;
				EndIf;
				
			EndIf;
			
			Data.DataExchange.Sender = MessageReader.Sender;
			Data.DataExchange.Load = True;
			
			// Overriding the standard system behavior on receiving object deletion.
			// Setting deletion marks instead of deleting objects without infobase reference
			// integrity checking. 
			If IsObjectDeletion Then
				
				ObjectDeletion = Data;
				
				Data = Data.Ref.GetObject();
				
				If Data = Undefined Then
					
					Continue;
					
				EndIf;
				
				Data.DataExchange.Sender = MessageReader.Sender;
				Data.DataExchange.Load = True;
				
				Data.DeletionMark = True;
				
				If CommonUse.IsDocument(Data.Metadata()) Then
					
					Data.Posted = False;
					
				EndIf;
				
			EndIf;
			
			// Checking whether conflict of edit prohibition dates occurred
			Cancel = False;
			
			DataExchangeOverridable.BeforeWriteObject(Data, Cancel);
			
			If Cancel Then
				
				DataImportProhibitionFound = Data.AdditionalProperties.Property("DataImportProhibitionFound");
				
				If DataImportProhibitionFound Then
					
					// The edit prohibition date conflict does not interrupt data import.
					// Writing the error message to the log.
					ErrorMessageString = "";
					Data.AdditionalProperties.Property("DataImportProhibitionFound", ErrorMessageString);
					
					WriteLogEvent(EventLogMessageKey, EventLogLevel.Warning,
						InfoBaseNode.Metadata(), InfoBaseNode, ErrorMessageString);
					
					
				EndIf;
				
				Continue;
			EndIf;
			
			If IsObjectDeletion And AllowDeleteObjects Then
				
				Data = ObjectDeletion;
				
			EndIf;
			
			If TypeOf(Data) <> Type("ObjectDeletion") Then
				
				Data.AdditionalProperties.Insert("DontCheckEditProhibitionDates");
				
			EndIf;
			
			// Attempting to write the object
			Try
				Data.Write();
			Except
				
				ExchangeExecutionResult = Enums.ExchangeExecutionResults.Error;
				
				DataImportProhibitionFound = Data.AdditionalProperties.Property("DataImportProhibitionFound");
				
				ErrorDescription = ?(DataImportProhibitionFound, Data.AdditionalProperties.DataImportProhibitionFound, DetailErrorDescription(ErrorInfo()));
				
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
			InfoBaseNode.Metadata(), InfoBaseNode, DetailErrorDescription(ErrorInfo()));
		
	EndTry;
	
	If ExchangeExecutionResult = Enums.ExchangeExecutionResults.Error Then
		
		If UseTransactions Then
			
			RollbackTransaction();
			
		EndIf;
		
		MessageReader.CancelRead();
		
	Else
		
		If UseTransactions Then
			
			CommitTransaction();
			
		EndIf;
		
		MessageReader.EndRead();
		
	EndIf;
	
	XMLReader.Close();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Export internal functions for retrieving properties

// Returns the name of the temporary directory for data exchange messages.
// The directory name is made by the following pattern:
// "Exchange82 {UUID}", where UUID is a UUID string.
// 
// Returns:
//  String - the name of the temporary directory for data exchange messages.
//
Function TempExchangeMessageDirectory() Export
	
	Return StrReplace("Exchange82 {UUID}", "UUID", Upper(String(New UUID)));
	
EndFunction

// Returns the exchange message transport data processor name.
// 
// Parameters:
//  TransportKind – EnumRef.ExchangeMessageTransportKinds – transport kind, for 
//                  which the result will be retrieved.
// 
// Returns:
//  String        - exchange message transport data processor name.
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
// Exchange message transport

Procedure ExecuteExchangeMessageTransportBeforeProcessing(ExchangeSettingsStructure)
	
	// Getting the initialized message transport data processor
	ExchangeMessageTransportDataProcessor = ExchangeSettingsStructure.ExchangeMessageTransportDataProcessor;
	
	// Getting a new temporary file name
	If Not ExchangeMessageTransportDataProcessor.ExecuteActionsBeforeMessageProcessing() Then
		
		WriteEventLogDataExchange(ExchangeMessageTransportDataProcessor.ErrorMessageStringEL, ExchangeSettingsStructure, True);
		
		ExchangeSettingsStructure.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Error_MessageTransport;
		
	EndIf;
	
EndProcedure

Procedure ExecuteExchangeMessageTransportSending(ExchangeSettingsStructure)
	
	// Getting the initialized message transport data processor
	ExchangeMessageTransportDataProcessor = ExchangeSettingsStructure.ExchangeMessageTransportDataProcessor;
	
	// Sending the exchange message from the temporary directory
	If Not ExchangeMessageTransportDataProcessor.SendMessage() Then
		
		WriteEventLogDataExchange(ExchangeMessageTransportDataProcessor.ErrorMessageStringEL, ExchangeSettingsStructure, True);
		
		ExchangeSettingsStructure.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Error_MessageTransport;
		
	EndIf;
	
EndProcedure

Procedure ExecuteExchangeMessageTransportReceiving(ExchangeSettingsStructure)
	
	// Getting the initialized message transport data processor
	ExchangeMessageTransportDataProcessor = ExchangeSettingsStructure.ExchangeMessageTransportDataProcessor;
	
	// Receiving the exchange message and putting it to the temporary directory
	If Not ExchangeMessageTransportDataProcessor.ReceiveMessage() Then
		
		WriteEventLogDataExchange(ExchangeMessageTransportDataProcessor.ErrorMessageStringEL, ExchangeSettingsStructure, True);
		
		ExchangeSettingsStructure.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Error_MessageTransport;
		
	EndIf;
	
EndProcedure

Procedure ExecuteExchangeMessageTransportAfterProcessing(ExchangeSettingsStructure)
	
	// Getting the initialized message transport data processor
	ExchangeMessageTransportDataProcessor = ExchangeSettingsStructure.ExchangeMessageTransportDataProcessor;
	
	// Performing actions after message sending
	ExchangeMessageTransportDataProcessor.ExecuteAfterMessageProcessingActions();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// File transfer service

// Downloads the file from the file transfer service by the passed ID.
//
// Parameters:
//  FileID       - UUID - ID of the file to be downloaded.
//  InfoBaseNode - infobase node. 
//  PartSize     - Number - part size in kilobytes. If the passed value is 0, the file 
//                 is not split into parts.
// Returns:
//  String - path to the received file.
//
Function GetFileFromStorageInService(Val FileID, Val InfoBaseNode, Val PartSize = 1024) Export
	
	// Return value
	ResultFileName = "";
	
	Proxy = DataExchangeCached.GetWSProxyForInfoBaseNode(InfoBaseNode);
	
	ExchangeInsideNetwork = DataExchangeCached.IsExchangeInSameLAN(InfoBaseNode);
	
	If ExchangeInsideNetwork Then
		
		FileNameFromStorage = Proxy.GetFileFromStorage(FileID);
		
		ResultFileName = CommonUseClientServer.GetFullFileName(TempFileStorageDirectory(), FileNameFromStorage);
		
	Else
		
		SessionID = Undefined;
		PartCount = Undefined;
		
		Proxy.PrepareGetFile(FileID, PartSize, SessionID, PartCount);
		
		FileNames = New Array;
		
		AssemblyDirectory = GetTempFileName();
		CreateDirectory(AssemblyDirectory);
		
		FileNamePattern = "data.zip.[n]";
		
		For PartNumber = 1 to PartCount Do
			
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
				WriteLogEvent(NStr("en = 'Deleting temporary file'"),
				EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
			EndTry;
			Raise(NStr("en = 'The archive file does not contain data.'"));
		EndIf;
		
		FileName = CommonUseClientServer.GetFullFileName(AssemblyDirectory, Dearchiver.Items[0].Name);
		
		Dearchiver.Extract(Dearchiver.Items[0], AssemblyDirectory);
		Dearchiver.Close();
		
		File = New File(FileName);
		
		ResultFileName = CommonUseClientServer.GetFullFileName(TempFilesDir(), File.Name);
		MoveFile(FileName, ResultFileName);
		
		Try
			DeleteFiles(AssemblyDirectory);
		Except
			WriteLogEvent(NStr("en = 'Deleting temporary file'"),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		EndTry;
		
	EndIf;
	
	Return ResultFileName;
EndFunction

// Passes the specified file to the file transfer service.
//
// Parameters:
//  FileName     - String - path to the passed file.
//  InfoBaseNode - infobase node. 
//  PartSize     - Number - part size in kilobytes. If the passed value is 0, the file
//                 is not split into parts.
// Returns:
//  UUID  - file ID in the file transfer service.
//
Function PutFileToStorageInService(Val FileName, Val InfoBaseNode, Val PartSize = 1024) Export
	
	// Return value
	FileID = Undefined;
	
	Proxy = DataExchangeCached.GetWSProxyForInfoBaseNode(InfoBaseNode);
	
	ExchangeInsideNetwork = DataExchangeCached.IsExchangeInSameLAN(InfoBaseNode);
	
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
		
		// Splitting the file into parts
		SessionID = New UUID;
		
		PartCount = 1;
		If ValueIsFilled(PartSize) Then
			FileNames = SplitFile(SharedFileName, PartSize * 1024);
			PartCount = FileNames.Count();
			For PartNumber = 1 to PartCount Do
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
			WriteLogEvent(NStr("en = 'Deleting temporary file'"),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		EndTry;
		
		Proxy.SaveFileFromParts(SessionID, PartCount, FileID);
		
	EndIf;
	
	Return FileID;
EndFunction

// Retrieves the file by the ID.
//
// Parameters:
//  FileID    - UUID - ID of the file to be retrieved.
//  StorageID - String - ID of the storage where the file is placed.
//
// Returns:
//  String - file name.
//
Function GetFileFromStorage(Val FileID) Export
	
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
		Details = NStr("en = 'The file with the %1 ID is nor found.'");
		Raise StringFunctionsClientServer.SubstituteParametersInString(Details, String(FileID));
	EndIf;
	
	Selection = QueryResult.Choose();
	Selection.Next();
	FileName = Selection.FileName;
	
	// Deleting the record with the exchange message file from the record structure 
	RecordStructure = New Structure;
	RecordStructure.Insert("MessageID", String(FileID));
	InformationRegisters.DataExchangeMessages.DeleteRecord(RecordStructure);
	
	Return CommonUseClientServer.GetFullFileName(TempFileStorageDirectory(), FileName);
EndFunction

// Saves the file.
//
// Parameters:
//  FileName  - String - file description.
//  StorageID - String - ID of the storage where the file is placed.
//  FileID    - UUID - file ID. If this value is not specified, it is generated
//              automatically.
//
// Returns:
//  UUID - file ID.
//
Function PutFileToStorage(Val FileName, Val FileID = Undefined) Export
	
	FileID = ?(FileID = Undefined, New UUID, FileID);
	
	File = New File(FileName);
	
	RecordStructure = New Structure;
	RecordStructure.Insert("MessageID", String(FileID));
	RecordStructure.Insert("MessageFileName", File.Name);
	RecordStructure.Insert("MessageSendingDate", CurrentDate());
	
	InformationRegisters.DataExchangeMessages.AddRecord(RecordStructure);
	
	Return FileID;
EndFunction

Function IsExchangeInSameLAN(Val InfoBaseNode) Export
	
	Proxy = DataExchangeCached.GetWSProxyForInfoBaseNode(InfoBaseNode);
	
	TempFileName = StrReplace("test{UUID}.tmp", "UUID", String(New UUID));
	
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
			WriteLogEvent(NStr("en = 'Deleting temporary file'"),
				EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		EndTry;
		Raise DetailErrorDescription;
	EndTry;
	
	Try
		DeleteFiles(TempFileFullName);
	Except
		WriteLogEvent(NStr("en = 'Deleting temporary file'"),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
	EndTry;
	
	Return Result;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Change registration for initial data export

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
					
					FilterByPeriod     = (MainFilter.Find("Period") <> Undefined);
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
								RecordSet.Filter[DimensionName].Use = True;
								
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
							RecordSet.Filter.Recorder.Use = True;
							
							ExchangePlans.RecordChanges(Recipient, RecordSet);
							
						EndDo;
						
						Continue;
						
					ElsIf ExchangePlanContentItem.Metadata.Dimensions.Find("Period") <> Undefined Then // Registering by date
						
						Selection = RecordSetRecorderSelectionByExportStartDate(FullObjectName, ExportStartDate);
						
						RecordSet = CommonUse.ObjectManagerByFullName(FullObjectName).CreateRecordSet();
						
						While Selection.Next() Do
							
							RecordSet.Filter.Recorder.Value = Selection.Recorder;
							RecordSet.Filter.Recorder.Use = True;
							
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
	
	Return Query.Execute().Choose();
EndFunction

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
	
	Return Query.Execute().Choose();
EndFunction

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
	
	Return Query.Execute().Choose();
EndFunction

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
	
	Return Query.Execute().Choose();
EndFunction

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
	QueryText = StrReplace(QueryText, "[Dimensions]", StringFunctionsClientServer.GetStringFromSubstringArray(MainFilter));
	
	Query = New Query;
	Query.SetParameter("ExportStartDate", ExportStartDate);
	Query.SetParameter("Companies", Companies);
	Query.Text = QueryText;
	
	Return Query.Execute().Choose();
EndFunction

Function MainInformationRegisterFilterValueSelectionByExportStartDate(MainFilter, FullObjectName, ExportStartDate)
	
	QueryText =
	"SELECT DISTINCT
	|	[Dimensions]
	|FROM
	|	[FullObjectName] AS RegisterTable
	|WHERE
	|	RegisterTable.Period >= &ExportStartDate";
	
	QueryText = StrReplace(QueryText, "[FullObjectName]", FullObjectName);
	QueryText = StrReplace(QueryText, "[Dimensions]", StringFunctionsClientServer.GetStringFromSubstringArray(MainFilter));
	
	Query = New Query;
	Query.SetParameter("ExportStartDate", ExportStartDate);
	Query.Text = QueryText;
	
	Return Query.Execute().Choose();
EndFunction

Function MainInformationRegisterFilterByCompaniesValueSelection(MainFilter, FullObjectName, Companies)
	
	QueryText =
	"SELECT DISTINCT
	|	[Dimensions]
	|FROM
	|	[FullObjectName] AS RegisterTable
	|WHERE
	|	RegisterTable.Company IN(&Companies)";
	
	QueryText = StrReplace(QueryText, "[FullObjectName]", FullObjectName);
	QueryText = StrReplace(QueryText, "[Dimensions]", StringFunctionsClientServer.GetStringFromSubstringArray(MainFilter));
	
	Query = New Query;
	Query.SetParameter("Companies", Companies);
	Query.Text = QueryText;
	
	Return Query.Execute().Choose();
EndFunction

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
// Auxiliary internal procedures and functions

Function DataExchangeMonitorTable(ExchangePlans, Val ExchangePlanAdditionalProperties = "") Export
	
	QueryText = "
	|//////////////////////////////////////////////////////////////////////////////// {DataExchangeStatesImport}
	|SELECT
	|	DataExchangeStates.InfoBaseNode    AS InfoBaseNode,
	|	DataExchangeStates.EndDate         AS EndDate,
	|	CASE
	|	WHEN DataExchangeStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.Warning_ExchangeMessageReceivedPreviously)
	|	THEN 3
	|	WHEN DataExchangeStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.CompletedWithWarnings)
	|	THEN 3
	|	WHEN DataExchangeStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.Completed)
	|	THEN 2
	|	ELSE 1
	|	END                                AS ExchangeExecutionResult
	|INTO DataExchangeStatesImport
	|FROM
	|	InformationRegister.DataExchangeStates AS DataExchangeStates
	|WHERE
	|	DataExchangeStates.ActionOnExchange = VALUE(Enum.ActionsOnExchange.DataImport)
	|;
	|
	|//////////////////////////////////////////////////////////////////////////////// {DataExchangeStatesExport}
	|SELECT
	|	DataExchangeStates.InfoBaseNode    AS InfoBaseNode,
	|	DataExchangeStates.EndDate         AS EndDate,
	|	CASE
	|	WHEN DataExchangeStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.Warning_ExchangeMessageReceivedPreviously)
	|	THEN 3
	|	WHEN DataExchangeStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.CompletedWithWarnings)
	|	THEN 3
	|	WHEN DataExchangeStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.Completed)
	|	THEN 2
	|	ELSE 1
	|	END                                AS ExchangeExecutionResult
	|INTO DataExchangeStatesExport
	|FROM
	|	InformationRegister.DataExchangeStates AS DataExchangeStates
	|WHERE
	|	DataExchangeStates.ActionOnExchange = VALUE(Enum.ActionsOnExchange.DataExport)
	|;
	|
	|//////////////////////////////////////////////////////////////////////////////// {SuccessfulDataExchangeStatesImport}
	|SELECT
	|	SuccessfulDataExchangeStates.InfoBaseNode AS InfoBaseNode,
	|	SuccessfulDataExchangeStates.EndDate      AS EndDate
	|INTO SuccessfulDataExchangeStatesImport
	|FROM
	|	InformationRegister.SuccessfulDataExchangeStates AS SuccessfulDataExchangeStates
	|WHERE
	|	SuccessfulDataExchangeStates.ActionOnExchange = VALUE(Enum.ActionsOnExchange.DataImport)
	|;
	|
	|//////////////////////////////////////////////////////////////////////////////// {SuccessfulDataExchangeStatesExport}
	|SELECT
	|	SuccessfulDataExchangeStates.InfoBaseNode AS InfoBaseNode,
	|	SuccessfulDataExchangeStates.EndDate          AS EndDate
	|INTO SuccessfulDataExchangeStatesExport
	|FROM
	|	InformationRegister.SuccessfulDataExchangeStates AS SuccessfulDataExchangeStates
	|WHERE
	|	SuccessfulDataExchangeStates.ActionOnExchange = VALUE(Enum.ActionsOnExchange.DataExport)
	|;
	|
	|
	|SELECT
	|	ExchangePlans.ExchangePlanName                 AS ExchangePlanName,
	|	ExchangePlans.InfoBaseNode                     AS InfoBaseNode,
	|	
	|	[ExchangePlanAdditionalProperties]
	|	
	|	ISNULL(DataExchangeStatesExport.ExchangeExecutionResult, 0) AS LastDataExportResult,
	|	ISNULL(DataExchangeStatesImport.ExchangeExecutionResult, 0) AS LastDataImportResult,
	|	DataExchangeStatesImport.EndDate                            AS LastImportDate,
	|	DataExchangeStatesExport.EndDate                            AS LastExportDate,
	|	SuccessfulDataExchangeStatesImport.EndDate                  AS LastSuccessfulImportDate,
	|	SuccessfulDataExchangeStatesExport.EndDate                  AS LastSuccessfulExportDate
	|FROM
	|	ConfigurationExchangePlans AS ExchangePlans
	|
	|		LEFT JOIN DataExchangeStatesImport AS DataExchangeStatesImport
	|			ON ExchangePlans.InfoBaseNode = DataExchangeStatesImport.InfoBaseNode
	|
	|		LEFT JOIN DataExchangeStatesExport AS DataExchangeStatesExport
	|			ON ExchangePlans.InfoBaseNode = DataExchangeStatesExport.InfoBaseNode
	|
	|		LEFT JOIN SuccessfulDataExchangeStatesImport AS SuccessfulDataExchangeStatesImport
	|			ON ExchangePlans.InfoBaseNode = SuccessfulDataExchangeStatesImport.InfoBaseNode
	|
	|		LEFT JOIN SuccessfulDataExchangeStatesExport AS SuccessfulDataExchangeStatesExport
	|			ON ExchangePlans.InfoBaseNode = SuccessfulDataExchangeStatesExport.InfoBaseNode
	|
	|ORDER BY
	|	ExchangePlans.ExchangePlanName,
	|	ExchangePlans.Description
	|";
	
	SetPrivilegedMode(True);
	
	TempTablesManager = New TempTablesManager;
	
	GetExchangePlanTableForMonitor(TempTablesManager, ExchangePlans, ExchangePlanAdditionalProperties);
	
	QueryText = StrReplace(QueryText, "[ExchangePlanAdditionalProperties]", GetExchangePlanAdditionalPropertiesString(ExchangePlanAdditionalProperties));
	
	Query = New Query;
	Query.Text = QueryText;
	Query.TempTablesManager = TempTablesManager;
	
	Return Query.Execute().Unload();
EndFunction

Function GetExchangePlanAdditionalPropertiesString(Val PropertiesString)
	
	Result = "";
	
	Pattern = "ExchangePlans.[PropertyString] AS [PropertyString]";
	
	ArrayProperties = StringFunctionsClientServer.SplitStringIntoSubstringArray(PropertiesString);
	
	For Each PropertyString In ArrayProperties Do
		
		PropertyStringInQuery = StrReplace(Pattern, "[PropertyString]", PropertyString);
		
		Result = Result + PropertyStringInQuery + ", ";
		
	EndDo;
	
	Return Result;
EndFunction

Function ExchangePlanFilterByDataSeparationFlag(ExchangePlansArray)
	
	Result = New Array;
	
	If CommonUseCached.DataSeparationEnabled() Then
		
		If CommonUseCached.CanUseSeparatedData() Then
			
			For Each ExchangePlanName In ExchangePlansArray Do
				
				If CommonUseCached.IsSeparatedMetadataObject("ExchangePlan." + ExchangePlanName) Then
					
					Result.Add(ExchangePlanName);
					
				EndIf;
				
			EndDo;
			
		Else
			
			For Each ExchangePlanName In ExchangePlansArray Do
				
				If Not CommonUseCached.IsSeparatedMetadataObject("ExchangePlan." + ExchangePlanName) Then
					
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

// Deletes obsolete records from the information register.
// The record is considered obsolete if the exchange plan that includes the record was renamed or deleted.
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
	
	Selection = Query.Execute().Choose();
	
	While Selection.Next() Do
		
		If ExchangePlanList.FindByValue(Selection.ExchangePlanName) = Undefined Then
			
			RecordSet = CreateInformationRegisterRecordSet(New Structure("ExchangePlanName", Selection.ExchangePlanName), "DataExchangeRules");
			RecordSet.Write();
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure GetExchangePlanTableForMonitor(TempTablesManager, ExchangePlansArray, Val ExchangePlanAdditionalProperties)
	
	MethodExchangePlans = ExchangePlanFilterByDataSeparationFlag(ExchangePlansArray);
	
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
	|	Ref                       AS InfoBaseNode,
	|	Description               AS Description,
	|	""[ExchangePlanSynonym]"" AS ExchangePlanName
	|FROM
	|	ExchangePlan.[ExchangePlanName]
	|WHERE
	|	     Ref <> &ThisNode[ExchangePlanName]
	|	AND NOT DeletionMark
	|";
	
	QueryText = "";
	
	If MethodExchangePlans.Count() > 0 Then
		
		For Each ExchangePlanName In MethodExchangePlans Do
			
			ExchangePlanQueryText = StrReplace(QueryPattern,              "[ExchangePlanName]",        ExchangePlanName);
			ExchangePlanQueryText = StrReplace(ExchangePlanQueryText, "[ExchangePlanSynonym]", Metadata.ExchangePlans[ExchangePlanName].Synonym);
			ExchangePlanQueryText = StrReplace(ExchangePlanQueryText, "[ExchangePlanAdditionalProperties]", ExchangePlanAdditionalPropertiesString);
			
			ParameterName = StrReplace("ThisNode[ExchangePlanName]", "[ExchangePlanName]", ExchangePlanName);
			Query.SetParameter(ParameterName, DataExchangeCached.GetThisExchangePlanNode(ExchangePlanName));
			
			// Deleting the union literal from the first table
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
			
			AdditionalPropertiesWithoutDataSourceString = StringFunctionsClientServer.GetStringFromSubstringArray(AdditionalPropertiesWithoutDataSource) + ", ";
			
		EndIf;
		
		QueryText = "
		|SELECT
		|
		|	[AdditionalPropertiesWithoutDataSourceString]
		|
		|	Undefined              AS InfoBaseNode,
		|	""[ExchangePlanName]"" AS Description,
		|	""[ExchangePlanName]"" AS ExchangePlanName
		|";
	
		QueryText = StrReplace(QueryText, "[ExchangePlanName]", NStr("en = '<Exchange is not supported in the current mode>'"));
		QueryText = StrReplace(QueryText, "[AdditionalPropertiesWithoutDataSourceString]", AdditionalPropertiesWithoutDataSourceString);
		
	EndIf;
	
	QueryTextResult = "
	|//////////////////////////////////////////////////////// {ConfigurationExchangePlans}
	|SELECT
	|
	|	[ExchangePlanAdditionalProperties]
	|
	|	InfoBaseNode,
	|	Description,
	|	ExchangePlanName
	|INTO ConfigurationExchangePlans
	|FROM
	|	(
	|	[QueryText]
	|	) AS NestedSelect
	|;
	|";
	
	QueryTextResult = StrReplace(QueryTextResult, "[QueryText]", QueryText);
	QueryTextResult = StrReplace(QueryTextResult, "[ExchangePlanAdditionalProperties]", ExchangePlanAdditionalPropertiesString);
	
	Query.Text = QueryTextResult;
	Query.TempTablesManager = TempTablesManager;
	Query.Execute();
	
EndProcedure

Procedure CheckUseDataExchange() Export
	
	If GetFunctionalOption("UseDataExchange") <> True Then
		
		Message = NStr("en = 'Exchange execution has been disabled by your administrator.'");
		
		WriteLogEvent(NStr("en = 'Data exchange'"), EventLogLevel.Error,,, Message);
		
		Raise Message;
	EndIf;
	
EndProcedure

// Fills the value list with transport kind available for the exchange plan node.
//
Procedure FillChoiceListWithAvailableTransportTypes(InfoBaseNode, FormItem, Filter = Undefined) Export
	
	FilterSet = (Filter <> Undefined);
	
	UsedTransports = DataExchangeCached.UsedExchangeMessageTransports(InfoBaseNode);
	
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
//  ExchangeSettingsStructure - Structure - structure with all necessary data and
//                              objects for performing the exchange.
// 
Procedure AddExchangeFinishEventLogMessage(ExchangeSettingsStructure)
	
	// The Undefined state in the end of the exchange indicates that the exchange has been
	// performed successfully.
	If ExchangeSettingsStructure.ExchangeExecutionResult = Undefined Then
		ExchangeSettingsStructure.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Completed;
	EndIf;
	
	// Generating the final message to be written
	If ExchangeSettingsStructure.IsDIBExchange Then
		MessageString = NStr("en = '%1, %2'");
		MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString,
							ExchangeSettingsStructure.ExchangeExecutionResult,
							ExchangeSettingsStructure.ActionOnExchange
		);
	Else
		MessageString = NStr("en = '%1, %2; %3 objects processed.'");
		MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString,
							ExchangeSettingsStructure.ExchangeExecutionResult,
							ExchangeSettingsStructure.ActionOnExchange,
							ExchangeSettingsStructure.ProcessedObjectCount
		);
	EndIf;
	
	WriteEventLogDataExchange(MessageString, ExchangeSettingsStructure);
	
	ExchangeSettingsStructure.EndDate = CurrentSessionDate();
	
	// Writing the exchange state to the information register
	AddExchangeFinishMessageToInformationRegister(ExchangeSettingsStructure);
	
	// The data exchange has been completed successfully
	If ExchangeExecutionResultCompleted(ExchangeSettingsStructure.ExchangeExecutionResult) Then
		
		AddSuccessfulDataExchangeMessageToInformationRegister(ExchangeSettingsStructure);
		
	EndIf;
	
EndProcedure


// Writes the data exchange state to the DataExchangeStates information register.
//
// Parameters:
//  ExchangeSettingsStructure - Structure - structure with all necessary data and
//                              objects for performing the exchange.
// 
Procedure AddExchangeFinishMessageToInformationRegister(ExchangeSettingsStructure)
	
	// Generating a structure for the new information register record
	RecordStructure = New Structure;
	RecordStructure.Insert("InfoBaseNode",           ExchangeSettingsStructure.InfoBaseNode);
	RecordStructure.Insert("ActionOnExchange",       ExchangeSettingsStructure.ActionOnExchange);
	
	RecordStructure.Insert("ExchangeExecutionResult", ExchangeSettingsStructure.ExchangeExecutionResult);
	RecordStructure.Insert("StartDate",               ExchangeSettingsStructure.StartDate);
	RecordStructure.Insert("EndDate",                 ExchangeSettingsStructure.EndDate);
	
	// Adding a record to the information register
	InformationRegisters.DataExchangeStates.AddRecord(RecordStructure);
	
EndProcedure

Procedure AddSuccessfulDataExchangeMessageToInformationRegister(ExchangeSettingsStructure)
	
	// Generating a structure for the new information register record
	RecordStructure = New Structure;
	RecordStructure.Insert("InfoBaseNode",     ExchangeSettingsStructure.InfoBaseNode);
	RecordStructure.Insert("ActionOnExchange", ExchangeSettingsStructure.ActionOnExchange);
	RecordStructure.Insert("EndDate",          ExchangeSettingsStructure.EndDate);
	
	// Adding a record to the information register
	InformationRegisters.SuccessfulDataExchangeStates.AddRecord(RecordStructure);
	
EndProcedure

Procedure WriteLogEventDataExchangeStart(ExchangeSettingsStructure) Export
	
	MessageString = NStr("en = 'Data exchange process started for %1 node'");
	MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, ExchangeSettingsStructure.InfobaseNodeDescription);
	WriteEventLogDataExchange(MessageString, ExchangeSettingsStructure);
	
EndProcedure

// Returns the conversion/registration rule file info string.
//
// Parameters:
//  TempStorageAddress    – temporary storage address where rule file data is placed;
//  RuleInformationString – rule info string will be returned into this parameter.
// 
Procedure LoadRuleInformation(Cancel, TempStorageAddress, RuleInformationString) Export
	
	InformationRegisters.DataExchangeRules.LoadRuleInformation(Cancel, TempStorageAddress, RuleInformationString);
	
EndProcedure

// Supplements the value table with empty rows to reach the specified number of rows.
//
Procedure SetTableRowCount(Table, RowCount) Export
	
	While Table.Count() < RowCount Do
		
		Table.Add();
		
	EndDo;
	
EndProcedure

// Writes the data exchange event message or the transport message to the event log.
//
Procedure WriteEventLogDataExchange(Comment, ExchangeSettingsStructure, IsError = False) Export
	
	Level = ?(IsError, EventLogLevel.Error, EventLogLevel.Information);
	
	WriteLogEvent(ExchangeSettingsStructure.EventLogMessageKey, Level,,, Comment);
	
EndProcedure

Procedure NodeSettingsFormOnCreateAtServerHandler(Form, FormAttributeName)
	
	For Each FilterSettings In Form[FormAttributeName] Do
		
		FilterKey = FilterSettings.Key;
		
		If Form.Items.Find(FilterKey) = Undefined Then
			Continue;
		EndIf;
		
		If TypeOf(Form[FilterKey]) = Type("FormDataCollection") Then
			
			Table = New ValueTable;
			
			TabularSectionStructure = Form.Parameters[FormAttributeName][FilterKey];
			
			For Each Item In TabularSectionStructure Do
				
				SetTableRowCount(Table, Item.Value.Count());
				
				Table.Columns.Add(Item.Key);
				
				Table.LoadColumn(Item.Value, Item.Key);
				
			EndDo;
			
			Form[FilterKey].Load(Table);
			
		Else
			
			Form[FilterKey] = Form.Parameters[FormAttributeName][FilterKey];
			
		EndIf;
		
		Form[FormAttributeName][FilterKey] = Form.Parameters[FormAttributeName][FilterKey];
		
	EndDo;
	
EndProcedure

// Unpacks the ZIP archive file to the specified directory. Extracts all files from the
// archive.
// 
// Parameters:
//  ArchiveFileFullName  - String - name of the archive file to be unpacked.
//  FileUnpackPath       - String - path where files are extracted.
//  ArchivePassword      - String - password for unpacking the archive. The default
//                         value is an empty string.
// 
// Returns:
//  Result - Boolean - True if the archive is extracted successfully, otherwise is False.
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
//  Result - Boolean - True if the archive is packed successfully, otherwise is False.
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

// Checks whether register record set is empty.
//
Function RegisterRecordSetEmpty(RecordStructure, RegisterName) Export
	
	RegisterMetadata = Metadata.InformationRegisters[RegisterName];
	
	// Creating a register record set
	RecordSet = InformationRegisters[RegisterName].CreateRecordSet();
	
	// Filtering by register dimensions
	For Each Dimension In RegisterMetadata.Dimensions Do
		
		// Filtering if the value in the structure is specified
		If RecordStructure.Property(Dimension.Name) Then
			
			RecordSet.Filter[Dimension.Name].Set(RecordStructure[Dimension.Name]);
			
		EndIf;
		
	EndDo;
	
	RecordSet.Read();
	
	Return RecordSet.Count() = 0;
	
EndFunction

// Returns the number of records in the infobase table.
// 
// Parameters:
//  TableName – String – full name of the infobase table.
//              For example: "Catalog.Counterparties.Orders".
// 
// Returns:
//  Number - number of records in the infobase table.
//
Function RecordCountInInfoBaseTable(Val TableName) Export
	
	QueryText = "
	|SELECT
	|	Count(*) AS Count
	|FROM
	|	#TableName
	|";
	
	QueryText = StrReplace(QueryText, "#TableName", TableName);
	
	Query = New Query;
	Query.Text = QueryText;
	
	Selection = Query.Execute().Choose();
	Selection.Next();
	
	Return Selection["Count"];
	
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
Function TempInfoBaseTableRecordCount(Val TableName, TempTablesManager) Export
	
	QueryText = "
	|SELECT
	|	Count(*) AS Count
	|FROM
	|	#TableName
	|";
	
	QueryText = StrReplace(QueryText, "#TableName", TableName);
	
	Query = New Query;
	Query.Text = QueryText;
	Query.TempTablesManager = TempTablesManager;
	
	Selection = Query.Execute().Choose();
	Selection.Next();
	
	Return Selection["Count"];
	
EndFunction

// Returns the event log message key.
//
Function GetEventLogMessageKey(InfoBaseNode, ActionOnExchange) Export
	
	ExchangePlanName     = DataExchangeCached.GetExchangePlanName(InfoBaseNode);
	ExchangePlanNodeCode = TrimAll(CommonUse.GetAttributeValue(InfoBaseNode, "Code"));
	
	MessageKey = NStr("en = 'Exchange data.[ExchangePlanName].Node [NodeCode].[ActionOnExchange]'");
	
	MessageKey = StrReplace(MessageKey, "[ExchangePlanName]", ExchangePlanName);
	MessageKey = StrReplace(MessageKey, "[NodeCode]",         ExchangePlanNodeCode);
	MessageKey = StrReplace(MessageKey, "[ActionOnExchange]", ActionOnExchange);
	
	Return MessageKey;
	
EndFunction

// Returns the event log message key by the action string.
//
Function GetEventLogMessageKeyByActionString(InfoBaseNode, ExchangeActionString) Export
	
	Return GetEventLogMessageKey(InfoBaseNode, Enums.ActionsOnExchange[ExchangeActionString]);
	
EndFunction

// Returns structure with filter data for the event log.
//
Function GetEventLogFilterDataStructure(InfoBaseNode, Val ActionOnExchange) Export
	
	If TypeOf(ActionOnExchange) = Type("String") Then
		
		ActionOnExchange = Enums.ActionsOnExchange[ActionOnExchange];
		
	EndIf;
	
	DataExchangeStates = InformationRegisters.DataExchangeStates.DataExchangeStates(InfoBaseNode, ActionOnExchange);
	
	Filter = New Structure;
	Filter.Insert("EventLogMessageText", GetEventLogMessageKey(InfoBaseNode, ActionOnExchange));
	Filter.Insert("StartDate",           DataExchangeStates.StartDate);
	Filter.Insert("EndDate",             DataExchangeStates.EndDate);
	
	Return Filter;
EndFunction

// Returns the name of data exchange message file based on the sender node data and
// the target node data.
//
Function ExchangeMessageFileName(SenderNodeCode, RecipientNodeCode) Export
	
	NamePattern = "[Prefix]_[SenderNode]_[RecipientNode]";
	
	NamePattern = StrReplace(NamePattern, "[prefix]",        "Message");
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
// Returns:
// Array of EnumRef.ExchangeMessageTransportKinds;
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

Function MustExecuteHandler(Object, Ref, PropertyName)
	
	NumberAfterProcessing = Object[PropertyName];
	
	NumberBeforeProcessing = CommonUse.GetAttributeValue(Ref, PropertyName);
	
	NumberBeforeProcessing = ?(NumberBeforeProcessing = Undefined, 0, NumberBeforeProcessing);
	
	Return NumberBeforeProcessing <> NumberAfterProcessing;
	
EndFunction

Function FillExternalConnectionParameters(TransportSettings)
	
	ConnectionParameters = CommonUseClientServer.ExternalConnectionParameterStructure();
	
	ConnectionParameters.InfoBaseOperationMode        = TransportSettings.COMInfoBaseOperationMode;
	ConnectionParameters.InfoBaseDirectory            = TransportSettings.COMInfoBaseDirectory;
	ConnectionParameters.PlatformServerName           = TransportSettings.COMPlatformServerName;
	ConnectionParameters.InfoBaseNameAtPlatformServer = TransportSettings.COMInfoBaseNameAtPlatformServer;
	ConnectionParameters.OSAuthentication             = TransportSettings.COMOSAuthentication;
	ConnectionParameters.UserName                     = TransportSettings.COMUserName;
	ConnectionParameters.UserPassword                 = TransportSettings.COMUserPassword;
	
	Return ConnectionParameters;
EndFunction

Function CreateTempExchangeMessageDirectory(TempDirectoryName, ErrorMessageString = "")
	
	TempDirectoryName = CommonUseClientServer.GetFullFileName(TempFilesDir(), TempExchangeMessageDirectory());
	
	// Creating the temporary exchange message directory
	Try
		CreateDirectory(TempDirectoryName);
	Except
		ErrorMessageString = DetailErrorDescription(ErrorInfo());
		Return False;
	EndTry;
	
	Return True;
EndFunction

Function AddStringToFileName(Val FullFileName, Val Literal)
	
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

Function ExchangePlanNodeCodeString(Value) Export
	
	If TypeOf(Value) = Type("String") Then
		
		Return TrimAll(Value);
		
	ElsIf TypeOf(Value) = Type("Number") Then
		
		Return Format(Value, "ND=7; NLZ=; NG=0");
		
	EndIf;
	
	Return Value;
EndFunction

Function DataAreaNumberByExchangePlanNodeCode(Val NodeCode) Export
	
	If TypeOf(NodeCode) <> Type("String") Then
		Raise NStr("en = 'Invalid type of parameter #[1].'");
	EndIf;
	
	Result = StrReplace(NodeCode, "S0", "");
	
	Return Number(Result);
EndFunction

Function ValueByType(Value, TypeName) Export
	
	If TypeOf(Value) <> Type(TypeName) Then
		
		Return New(Type(TypeName));
		
	EndIf;
	
	Return Value;
EndFunction

Function AttributeFunctionalOptions(Attribute)
	
	Result = New Array;
	
	For Each FunctionalOption In Metadata.FunctionalOptions Do
		
		If FunctionalOption.Content.Contains(Attribute) Then
			
			Result.Add(FunctionalOption.Name);
			
		EndIf;
		
	EndDo;
	
	Return Result;
EndFunction

Function PredefinedExchangePlanNodeDescription(ExchangePlanName) Export
	
	SetPrivilegedMode(True);
	
	Return CommonUse.GetAttributeValue(DataExchangeCached.GetThisExchangePlanNode(ExchangePlanName), "Description");
EndFunction

// For internal use only.
//
Function ThisNodeDefaultDescription() Export
	
	Return ?(CommonUseCached.DataSeparationEnabled(), Metadata.Synonym, DataExchangeCached.ThisInfoBaseName());
	
EndFunction

// For internal use only.
//
Procedure BeforeSendDataHandler(StandardProcessing,
											Val Recipient,
											Val MessageFileName,
											MessageData,
											Val TransactionItemCount,
											Val EventLogEventName,
											SentObjectCount
	)
	
	DataExchangeOverridable.BeforeSendData(StandardProcessing,
											Recipient,
											MessageFileName,
											MessageData,
											TransactionItemCount,
											EventLogEventName,
											SentObjectCount
	);
	
EndProcedure

// For internal use only.
//
Procedure BeforeReceiveDataHandler(StandardProcessing,
											Val Sender,
											Val MessageFileName,
											MessageData,
											Val TransactionItemCount,
											Val EventLogEventName,
											ReceivedObjectCount
	)
	
	DataExchangeOverridable.BeforeReceiveData(StandardProcessing,
											Sender,
											MessageFileName,
											MessageData,
											TransactionItemCount,
											EventLogEventName,
											ReceivedObjectCount
	);
	
EndProcedure

// For internal use only.
//
Procedure AddExchangeFinishedWithErrorEventLogMessage(Val InfoBaseNode, 
												Val ActionOnExchange, 
												Val StartDate, 
												Val ErrorMessageString
	) Export
	
	If TypeOf(ActionOnExchange) = Type("String") Then
		
		ActionOnExchange = Enums.ActionsOnExchange[ActionOnExchange];
		
	EndIf;
	
	ExchangeSettingsStructure = New Structure;
	ExchangeSettingsStructure.Insert("InfoBaseNode", InfoBaseNode);
	ExchangeSettingsStructure.Insert("ExchangeExecutionResult", Enums.ExchangeExecutionResults.Error);
	ExchangeSettingsStructure.Insert("ActionOnExchange", ActionOnExchange);
	ExchangeSettingsStructure.Insert("ProcessedObjectCount", 0);
	ExchangeSettingsStructure.Insert("EventLogMessageKey", GetEventLogMessageKey(InfoBaseNode, ActionOnExchange));
	ExchangeSettingsStructure.Insert("StartDate", StartDate);
	ExchangeSettingsStructure.Insert("EndDate", CurrentSessionDate());
	ExchangeSettingsStructure.Insert("IsDIBExchange", DataExchangeCached.IsDistributedInfoBaseNode(InfoBaseNode));
	
	WriteEventLogDataExchange(ErrorMessageString, ExchangeSettingsStructure, True);
	
	AddExchangeFinishEventLogMessage(ExchangeSettingsStructure);
	
EndProcedure

// For internal use only.
//
Procedure CommitDataExportExecutionInLongActionMode(Val InfoBaseNode, Val StartDate) Export
	
	ActionOnExchange = Enums.ActionsOnExchange.DataExport;
	
	ExchangeSettingsStructure = New Structure;
	ExchangeSettingsStructure.Insert("InfoBaseNode", InfoBaseNode);
	ExchangeSettingsStructure.Insert("ExchangeExecutionResult", Enums.ExchangeExecutionResults.Completed);
	ExchangeSettingsStructure.Insert("ActionOnExchange", ActionOnExchange);
	ExchangeSettingsStructure.Insert("ProcessedObjectCount", 0);
	ExchangeSettingsStructure.Insert("EventLogMessageKey", GetEventLogMessageKey(InfoBaseNode, ActionOnExchange));
	ExchangeSettingsStructure.Insert("StartDate", StartDate);
	ExchangeSettingsStructure.Insert("EndDate", CurrentSessionDate());
	ExchangeSettingsStructure.Insert("IsDIBExchange", False);
	
	AddExchangeFinishEventLogMessage(ExchangeSettingsStructure);
	
EndProcedure

Procedure ExecuteFormTableComparisonAndMerging(Form, Cancel)
	
	ExchangePlanName = StringFunctionsClientServer.SplitStringIntoSubstringArray(Form.FormName, ".")[1];
	
	CorrespondentData = CorrespondentNodeCommonData(ExchangePlanName, Form.Parameters.ConnectionParameters, Cancel);
	
	If CorrespondentData = Undefined Then
		Return;
	EndIf;
	
	ThisInfoBaseData = DataForThisInfoBaseNodeTabularSections(ExchangePlanName);
	
	ExchangePlanTabularSections = DataExchangeCached.ExchangePlanTabularSections(ExchangePlanName);
	
	FormAttributes = Form.GetAttributes();
	FormAttributeNames = New Array;
	For Each FormAttribute In FormAttributes Do
		
		FormAttributeNames.Add(FormAttribute.Name);
		
	EndDo;
	
	// Merging common data tables
	For Each TabularSectionName In ExchangePlanTabularSections["CommonTables"] Do
		
		If FormAttributeNames.Find(TabularSectionName) = Undefined Then
			Continue;
		EndIf;
		
		CommonTable = New ValueTable;
		CommonTable.Columns.Add("Presentation", New TypeDescription("String"));
		CommonTable.Columns.Add("RefUUID", New TypeDescription("String"));
		
		For Each TableRow In ThisInfoBaseData[TabularSectionName] Do
			
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
	
	// Merging this infobase data tables
	For Each TabularSectionName In ExchangePlanTabularSections["ThisInfoBaseTables"] Do
		
		If FormAttributeNames.Find(TabularSectionName) = Undefined Then
			Continue;
		EndIf;
		
		ResultTable = ThisInfoBaseData[TabularSectionName].Copy();
		ResultTable.Columns.Add("Use", New TypeDescription("Boolean"));
		
		SynchronizeUseAttributeInTablesFlag(Form[TabularSectionName], ResultTable);
		
		Form[TabularSectionName].Load(ResultTable);
		
	EndDo;
	
	// Merging correspondent infobase data tables
	For Each TabularSectionName In ExchangePlanTabularSections["CorrespondentTables"] Do
		
		If FormAttributeNames.Find(TabularSectionName) = Undefined Then
			Continue;
		EndIf;
		
		ResultTable = CorrespondentData[TabularSectionName].Copy();
		ResultTable.Columns.Add("Use", New TypeDescription("Boolean"));
		
		SynchronizeUseAttributeInTablesFlag(Form[TabularSectionName], ResultTable);
		
		Form[TabularSectionName].Load(ResultTable);
		
	EndDo;
	
EndProcedure

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

Procedure LoadContextIntoForm(Form, Context)
	
	// Filling the form with data
	Attributes = Form.GetAttributes();
	
	If Context <> Undefined Then
	
		For Each Attribute In Attributes Do
			
			If Context.Property(Attribute.Name) Then
				
				If TypeOf(Form[Attribute.Name]) = Type("FormDataCollection") Then
					
					If Context[Attribute.Name].Count() = 0 Then
						
						Form[Attribute.Name].Clear();
						
					Else
						
						Table = New ValueTable;
						
						For Each Item In Context[Attribute.Name][0] Do
							
							Table.Columns.Add(Item.Key);
							
						EndDo;
						
						For Each TableRow In Context[Attribute.Name] Do
							
							FillPropertyValues(Table.Add(), TableRow);
							
						EndDo;
						
						Form[Attribute.Name].Load(Table);
						
					EndIf;
					
				Else
					
					Form[Attribute.Name] = Context[Attribute.Name];
					
				EndIf;
				
			EndIf;
			
		EndDo;
	
	EndIf;
	
	// Getting form data structure description
	AttributeString = New Array;
	
	For Each Attribute In Attributes Do
		
		If TypeOf(Form[Attribute.Name]) = Type("FormDataCollection") Then
			
			Table = Form[Attribute.Name].Unload();
			
			Columns = New Array;
			Columns.Add(Attribute.Name);
			
			For Each Column In Table.Columns Do
				
				Columns.Add(Column.Name);
				
			EndDo;
			
			AttributeString.Add(StringFunctionsClientServer.GetStringFromSubstringArray(Columns, "."));
			
		Else
			
			AttributeString.Add(Attribute.Name);
			
		EndIf;
		
	EndDo;
	
	Form.Attributes = StringFunctionsClientServer.GetStringFromSubstringArray(AttributeString);
	
EndProcedure

Procedure ExternalConnectionRefreshExchangeSettingsData(Val ExchangePlanName, Val NodeCode, Val NodeDefaultValues) Export
	
	SetPrivilegedMode(True);
	
	InfoBaseNode = ExchangePlans[ExchangePlanName].FindByCode(NodeCode);
	
	If Not ValueIsFilled(InfoBaseNode) Then
		Message = NStr("en = 'The exchange plan node with the %2 code is not found in the %1 exchange plan.'");
		Message = StringFunctionsClientServer.SubstituteParametersInString(Message, ExchangePlanName, NodeCode);
		Raise Message;
	EndIf;
	
	DataExchangeCreationWizard = DataProcessors.DataExchangeCreationWizard.Create();
	DataExchangeCreationWizard.InfoBaseNode = InfoBaseNode;
	DataExchangeCreationWizard.ExternalConnectionRefreshExchangeSettingsData(NodeDefaultValues);
	
EndProcedure

// For internal use only
Function DataForThisInfoBaseNodeTabularSections(Val ExchangePlanName) Export
	
	Result = New Structure;
	
	NodeCommonTables = DataExchangeCached.ExchangePlanTabularSections(ExchangePlanName)["AllInfoBaseTables"];
	
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
		|	NOT Table.DeletionMark
		|
		|ORDER BY
		|	Table.Presentation";
		
		TableName = TableNameFromExchangePlanTabularSectionFirstAttribute(ExchangePlanName, TabularSectionName);
		
		QueryText = StrReplace(QueryText, "[TableName]", TableName);
		
		Query = New Query;
		Query.Text = QueryText;
		
		Selection = Query.Execute().Choose();
		
		While Selection.Next() Do
			
			TableRow = TabularSectionData.Add();
			TableRow.Presentation = Selection.Presentation;
			TableRow.RefUUID = String(Selection.Ref.UUID());
			
		EndDo;
		
		Result.Insert(TabularSectionName, TabularSectionData);
		
	EndDo;
	
	Return Result;
EndFunction

Function CorrespondentNodeCommonData(Val ExchangePlanName, Val ConnectionParameters, Cancel)
	
	If ConnectionParameters.ConnectionType = "ExternalConnection" Then
		
		ErrorMessageString = "";
		
		ExternalConnection = DataExchangeCached.EstablishExternalConnection(ConnectionParameters, ErrorMessageString);
		
		If ExternalConnection = Undefined Then
			CommonUseClientServer.MessageToUser(ErrorMessageString,,,, Cancel);
			Return Undefined;
		EndIf;
		
		// ============================ {Start}
		If ConnectionParameters.CorrespondentVersion_2_0_1_6 Then
			
			Return CommonUse.ValueFromXMLString(ExternalConnection.DataExchangeExternalConnection.GetNodeCommonData_2_0_1_6(ExchangePlanName));
			
		Else
			
			Return ValueFromStringInternal(ExternalConnection.DataExchangeExternalConnection.GetCommonNodeData(ExchangePlanName));
			
		EndIf;
		// ============================ {End}
		
	ElsIf ConnectionParameters.ConnectionType = "WebService" Then
		
		ErrorMessageString = "";
		
		If ConnectionParameters.CorrespondentVersion_2_0_1_6 Then
			WSProxy = DataExchangeCached.GetWSProxy_2_0_1_6(ConnectionParameters, ErrorMessageString);
		Else
			WSProxy = DataExchangeCached.GetWSProxy(ConnectionParameters, ErrorMessageString);
		EndIf;
		
		If WSProxy = Undefined Then
			CommonUseClientServer.MessageToUser(ErrorMessageString,,,, Cancel);
			Return Undefined;
		EndIf;
		
		If ConnectionParameters.CorrespondentVersion_2_0_1_6 Then
			
			Return XDTOSerializer.ReadXDTO(WSProxy.GetCommonNodsData(ExchangePlanName));
		Else
			
			Return ValueFromStringInternal(WSProxy.GetCommonNodsData(ExchangePlanName));
		EndIf;
		
	EndIf;
	
	Return Undefined;
EndFunction

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

Function ExchangePlanCatalogs(Val ExchangePlanName) Export
	
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

Function AllExchangePlanDataExceptCatalogs(Val ExchangePlanName) Export
	
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

Function SystemAccountingSettingsAreSet(Val ExchangePlanName, Val NodeCode, ErrorMessage) Export
	
	If IsBlankString(NodeCode) Then
		Return False;
	EndIf;
	
	InfoBaseNode = ExchangePlans[ExchangePlanName].FindByCode(NodeCode);
	
	If Not ValueIsFilled(InfoBaseNode) Then
		Message = NStr("en = 'The exchange plan node with the %2 code has not been found in the %1 exchange plan.'");
		Message = StringFunctionsClientServer.SubstituteParametersInString(Message, ExchangePlanName, NodeCode);
		Raise Message;
	EndIf;
	
	Cancel = False;
	
	ExchangePlans[ExchangePlanName].AccountingSettingsCheckHandler(Cancel, InfoBaseNode, ErrorMessage);
	
	Return Not Cancel;
EndFunction

Function GetInfoBaseParameters(Val ExchangePlanName, Val NodeCode, ErrorMessage) Export
	
	Return ValueToStringInternal(InfoBaseParameters(ExchangePlanName, NodeCode, ErrorMessage));
	
EndFunction

Function GetInfoBaseParameters_2_0_1_6(Val ExchangePlanName, Val NodeCode, ErrorMessage) Export
	
	Return CommonUse.ValueToXMLString(InfoBaseParameters(ExchangePlanName, NodeCode, ErrorMessage));
	
EndFunction

Function MetadataObjectProperties(Val FullTableName) Export
	
	Result = New Structure("Synonym, Hierarchical");
	
	MetadataObject = Metadata.FindByFullName(FullTableName);
	
	FillPropertyValues(Result, MetadataObject);
	
	Return Result;
EndFunction

Function GetTableObjects(Val FullTableName) Export
	
	SetPrivilegedMode(True);
	
	MetadataObject = Metadata.FindByFullName(FullTableName);
	
	If CommonUse.IsCatalog(MetadataObject) Then
		
		If MetadataObject.Hierarchical Then
			
			If MetadataObject.HierarchyType = Metadata.ObjectProperties.HierarchyType.HierarchyFoldersAndItems Then
				
				Return DataExchangeCached.GetHierarchicalCatalogItemsHierarchyFoldersAndItems(FullTableName);
				
			Else
				
				Return DataExchangeCached.GetHierarchicalCatalogItemsHierarchyOfItems(FullTableName);
				
			EndIf;
			
		Else
			
			Return DataExchangeCached.GetNonHierarchicalCatalogItems(FullTableName);
			
		EndIf;
		
	EndIf;
	
	Return Undefined;
EndFunction

Function InfoBaseParameters(Val ExchangePlanName, Val NodeCode, ErrorMessage) Export
	
	SetPrivilegedMode(True);
	
	Result = New Structure("ExchangePlanExists, InfoBasePrefix, DefaultInfoBasePrefix, 
		|InfoBaseDescription, DefaultInfoBaseDescription, AccountingParametersAreSet, ThisNodeCode"
	);
	
	Result.ExchangePlanExists = (Metadata.ExchangePlans.Find(ExchangePlanName) <> Undefined);
	
	If Result.ExchangePlanExists Then
		
		ThisNodeProperties = CommonUse.GetAttributeValues(ExchangePlans[ExchangePlanName].ThisNode(), "Code, Description");
		
		Result.InfoBasePrefix             = GetFunctionalOption("InfoBasePrefix");
		Result.DefaultInfoBasePrefix      = DataExchangeOverridable.DefaultInfoBasePrefix();
		Result.InfoBaseDescription        = ThisNodeProperties.Description;
		Result.DefaultInfoBaseDescription = ThisNodeDefaultDescription();
		Result.AccountingParametersAreSet = SystemAccountingSettingsAreSet(ExchangePlanName, NodeCode, ErrorMessage);
		Result.ThisNodeCode               = ThisNodeProperties.Code;
		
	Else
		
		Result.InfoBasePrefix             = "";
		Result.DefaultInfoBasePrefix      = "";
		Result.InfoBaseDescription        = "";
		Result.DefaultInfoBaseDescription = "";
		Result.AccountingParametersAreSet = False;
		Result.ThisNodeCode               = "";
	EndIf;
	
	Return Result;
EndFunction

Function GetStatisticsTree(Statistics) Export
	
	FilterArray = Statistics.UnloadColumn("TargetTableName");
	
	FilterRow = StringFunctionsClientServer.GetStringFromSubstringArray(FilterArray);
	
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
	
	StatisticsOrdinaryObjects = Statistics.Copy(New Structure("OneToMany, IsObjectDeletion", False, False));
	
	// Filling ordinary rows
	For Each TableRow In StatisticsOrdinaryObjects Do
		
		TreeRow = StatisticsTree.Rows.Find(TableRow.TargetTableName, "FullName", True);
		
		FillPropertyValues(TreeRow, TableRow);
		
	EndDo;
	
	// Adding rows of OneToMany type
	Filter = New Structure("OneToMany", True);
	FillStatisticsTreeOneToMany(StatisticsTree, Statistics, Filter);
	
	// Adding object deletion rows
	Filter = New Structure("IsObjectDeletion", True);
	FillStatisticsTreeOneToMany(StatisticsTree, Statistics, Filter);
	
	Return StatisticsTree;
EndFunction

Procedure FillStatisticsTreeOneToMany(StatisticsTree, Statistics, Filter)
	
	StatisticsOneToMany = Statistics.Copy(Filter);
	
	If StatisticsOneToMany.Count() = 0 Then
		Return;
	EndIf;
	
	StatisticsOneToManyTemporary = StatisticsOneToMany.Copy(, "TargetTableName");
	StatisticsOneToManyTemporary.GroupBy("TargetTableName");
	
	For Each TableRow In StatisticsOneToManyTemporary Do
		
		Rows = StatisticsOneToMany.FindRows(New Structure("TargetTableName", TableRow.TargetTableName));
		
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
Procedure AddSubsystemsLibraryClientLogicExecutionParameters(Parameters) Export
	
	SetPrivilegedMode(True);
	
	Parameters.Insert("IsSubordinateDIBNode", IsSubordinateDIBNode());
	Parameters.Insert("DIBExchangePlanName", ?(Parameters.IsSubordinateDIBNode, ExchangePlans.MasterNode().Metadata().Name, ""));
	Parameters.Insert("SubordinateDIBNodeSetupCompleted", Constants.SubordinateDIBNodeSetupCompleted.Get());
	
EndProcedure

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
		
		Selection = Result.Choose();
		
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
				|It is recommended that you update exchange rules from the file to prevent possible errors.'"
		);
		MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, StringFunctionsClientServer.GetStringFromSubstringArray(ExchangePlansArray));
		
		WriteLogEvent(InfoBaseUpdate.EventLogMessageText(), EventLogLevel.Error,,, MessageString);
		
	EndIf;
	
EndProcedure

// Verifies the transport processor connection by the specified settings.
//
Procedure CheckExchangeMessageTransportDataProcessorConnection(Cancel, SettingsStructure, TransportKind, ErrorMessage = "") Export
	
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
		
		WriteLogEvent(NStr("en = 'Exchange message transport'"), EventLogLevel.Error,,, DataProcessorObject.ErrorMessageStringEL);
		
	EndIf;
	
EndProcedure

Procedure CheckExternalConnection(Cancel, SettingsStructure, ErrorAttachingAddIn = False) Export
	
	ErrorMessageString = "";
	
	// Attempting to establish the external connection
	ExternalConnection = EstablishExternalConnection(SettingsStructure, ErrorMessageString, ErrorAttachingAddIn);
	
	If ExternalConnection = Undefined Then
		
		// Displaying error message
		Message = NStr("en = 'Error establishing connection with the second infobase: %1'");
		Message = StringFunctionsClientServer.SubstituteParametersInString(Message, ErrorMessageString);
		CommonUseClientServer.MessageToUser(Message,,,, Cancel);
		
	EndIf;
	
EndProcedure

Function EstablishExternalConnection(SettingsStructure, ErrorMessageString = "", ErrorAttachingAddIn = False) Export
	
	// Attempting to establish the external connection
	ExternalConnection = CommonUse.EstablishExternalConnection(FillExternalConnectionParameters(SettingsStructure), ErrorMessageString, ErrorAttachingAddIn);
	
	If ExternalConnection = Undefined Then
		Return Undefined;
	EndIf;
	
	Try
		
		If Not ExternalConnection.DataExchangeExternalConnection.IsInRoleFullAccess() Then
			
			ErrorMessageString = NStr("en = 'The ""Full access"" role must be selected for the external connection user.'");
			Return Undefined;
		EndIf;
	Except
		
		ErrorMessageString = NStr("en = 'The second infobase does not provide an exchange with the current infobase.'");
		Return Undefined;
	EndTry;
	
	Return ExternalConnection;
	
EndFunction

Function GetWSProxyByConnectionParameters(SettingsStructure, ErrorMessageString = "") Export
	
	WSDLLocation = "[WebServiceURL]/ws/[ServiceName]?wsdl";
	WSDLLocation = StrReplace(WSDLLocation, "[WebServiceURL]", SettingsStructure.WSURL);
	WSDLLocation = StrReplace(WSDLLocation, "[ServiceName]",    SettingsStructure.WSServiceName);
	
	Try
		Definition = New WSDefinitions(
			WSDLLocation, 
			SettingsStructure.WSUserName,
			SettingsStructure.WSPassword);
		
		WSProxy = New WSProxy(
			Definition,
			SettingsStructure.NamespaceWebServiceURL,
			SettingsStructure.WSServiceName,
			SettingsStructure.WSServiceName + "Soap");
			
		WSProxy.User     = SettingsStructure.WSUserName;
		WSProxy.Password = SettingsStructure.WSPassword;
	Except
		ErrorMessageString = DetailErrorDescription(ErrorInfo());
		WriteLogEvent(EventLogMessageTextEstablishingConnectionToWebService(), EventLogLevel.Error,,, ErrorMessageString);
		Return Undefined;
	EndTry;
	
	Return WSProxy;
EndFunction

Function GetWSProxy(SettingsStructure, ErrorMessageString = "") Export
	
	SettingsStructure.Insert("NamespaceWebServiceURL", "http://1c-dn.com/SSL/Exchange");
	SettingsStructure.Insert("WSServiceName",          "Exchange");
	
	Return GetWSProxyByConnectionParameters(SettingsStructure, ErrorMessageString);
EndFunction

Function GetWSProxy_2_0_1_6(SettingsStructure, ErrorMessageString = "") Export
	
	SettingsStructure.Insert("NamespaceWebServiceURL", "http://1c-dn.com/SSL/Exchange_2_0_1_6");
	SettingsStructure.Insert("WSServiceName",          "Exchange_2_0_1_6");
	
	Return GetWSProxyByConnectionParameters(SettingsStructure, ErrorMessageString);
EndFunction

Function WSParameterStructure() Export
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("WSURL");
	ParametersStructure.Insert("WSUserName");
	ParametersStructure.Insert("WSPassword");
	
	Return ParametersStructure;
EndFunction

// Displays the error message and sets the Cancel flag to True.
//
// Parameters:
//  MessageText - string - message text.
//  Cancel      - (optional) Boolean - cancel flag.
//
Procedure ReportError(MessageText, Cancel = False) Export
	
	Cancel = True;
	
	CommonUseClientServer.MessageToUser(MessageText);
	
EndProcedure

// Retrieves the selective object registration rule table from the session parameters.
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
	
	// Filtering be register dimensions
	For Each Dimension In RegisterMetadata.Dimensions Do
		
		// Filtering if the value in the structure is specified
		If RecordStructure.Property(Dimension.Name) Then
			
			RecordManager[Dimension.Name] = RecordStructure[Dimension.Name];
			
		EndIf;
		
	EndDo;
	
	// Reading the record from the infobase
	RecordManager.Read();
	
	// Filling record properties with the passed structure values
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
										Val RuleTemplateName
	)
	
	RecordStructure = New Structure;
	RecordStructure.Insert("ExchangePlanName", ExchangePlanName);
	RecordStructure.Insert("RuleKind",         RuleKind);
	RecordStructure.Insert("RuleTemplateName", RuleTemplateName);
	RecordStructure.Insert("RuleSource",        Enums.DataExchangeRuleSources.ConfigurationTemplate);
	RecordStructure.Insert("UseSelectiveObjectChangeRecordFilter", True);
	
	// Creating a register record set
	RecordSet = CreateInformationRegisterRecordSet(RecordStructure, "DataExchangeRules");
	
	// Adding only one record to the new record set
	NewRecord = RecordSet.Add();
	
	// Filling record properties with values from the structure
	FillPropertyValues(NewRecord, RecordStructure);
	
	// Importing data exchange rules into the infobase
	InformationRegisters.DataExchangeRules.ImportRules(Cancel, RecordSet[0]);
	
	If Not Cancel Then
		RecordSet.Write();
	EndIf;
	
EndProcedure

Procedure UpdateStandardDataExchangeRuleVersion(Cancel, LoadedFromFileExchangeRules, LoadedFromFileRecordRules)
	
	SLExchangePlans = DataExchangeCached.SLExchangePlans();
	
	For Each ExchangePlanName In SLExchangePlans Do
		
		If LoadedFromFileExchangeRules.Find(ExchangePlanName) = Undefined
			And DataExchangeCached.HasExchangePlanTemplate(ExchangePlanName, "ExchangeRules") Then
			
			ImportDataExchangeRules(Cancel, ExchangePlanName, Enums.DataExchangeRuleKinds.ObjectConversionRules, "ExchangeRules");
			
		EndIf;
		
		If LoadedFromFileRecordRules.Find(ExchangePlanName) = Undefined
			And DataExchangeCached.HasExchangePlanTemplate(ExchangePlanName, "RecordRules") Then
			
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
	
	// Creating a register record set
	RecordSet = InformationRegisters[RegisterName].CreateRecordSet();
	
	// Filtering by register dimensions
	For Each Dimension In RegisterMetadata.Dimensions Do
		
		// Filtering if the value in the structure is specified
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
// Returns:
//  Boolean - True if the exchange rules are imported into the infobase, otherwise is False.
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
// Returns:
//  Boolean - True if the exchange message size exceed the maximum allowed size,
//            otherwise is False.
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

Function InitialDataExportFlagIsSet(InfoBaseNode) Export
	
	SetPrivilegedMode(True);
	
	Return InformationRegisters.CommonInfoBaseNodeSettings.InitialDataExportFlagIsSet(InfoBaseNode);
	
EndFunction

Function ChangesRegistered(InfoBaseNode) Export
	
	QueryText =
	"SELECT TOP 1 1
	|FROM
	|	[Table].Changes AS ChangeTable
	|WHERE
	|	ChangeTable.Node = &Node";
	
	Query = New Query;
	Query.SetParameter("Node", InfoBaseNode);
	
	SetPrivilegedMode(True);
	
	ExchangePlanContent = Metadata.ExchangePlans[DataExchangeCached.GetExchangePlanName(InfoBaseNode)].Content;
	
	For Each ContentItem In ExchangePlanContent Do
		
		Query.Text = StrReplace(QueryText, "[Table]", ContentItem.Metadata.FullName());
		
		QueryResult = Query.Execute();
		
		If Not QueryResult.IsEmpty() Then
			Return True;
		EndIf;
		
	EndDo;
	
	Return False;
EndFunction

Procedure RegisterDataForInitialExport(InfoBaseNode, Data = Undefined) Export
	
	SetPrivilegedMode(True);
	
	StandardProcessing = True;
	
	DataExchangeOverridable.InitialDataExportChangeRecord(InfoBaseNode, StandardProcessing, Data);
	
	If StandardProcessing Then
		
		If TypeOf(Data) = Type("Array") Then
			
			For Each MetadataObject In Data Do
				
				ExchangePlans.RecordChanges(InfoBaseNode, MetadataObject);
				
			EndDo;
			
		Else
			
			ExchangePlans.RecordChanges(InfoBaseNode, Data);
			
		EndIf;
		
	EndIf;
	
	If DataExchangeCached.ExchangePlanContainsObject(DataExchangeCached.GetExchangePlanName(InfoBaseNode),
		Metadata.InformationRegisters.InfoBaseObjectMaps.FullName()) Then
		
		ExchangePlans.DeleteChangeRecords(InfoBaseNode, Metadata.InformationRegisters.InfoBaseObjectMaps);
		
	EndIf;
	
EndProcedure

Function LongActionState(Val ActionID,
									Val WebServiceURL,
									Val UserName,
									Val Password,
									ErrorMessageString = ""
	) Export
	
	ConnectionParameters = WSParameterStructure();
	ConnectionParameters.WSURL      = WebServiceURL;
	ConnectionParameters.WSUserName = UserName;
	ConnectionParameters.WSPassword = Password;
	
	WSProxy = GetWSProxy(ConnectionParameters, ErrorMessageString);
	
	If WSProxy = Undefined Then
		Raise ErrorMessageString;
	EndIf;
	
	Return WSProxy.GetContinuousOperationStatus(ActionID, ErrorMessageString);
EndFunction

Function LongActionStateForInfoBaseNode(Val InfoBaseNode,
																Val ActionID,
																ErrorMessageString = ""
	) Export
	
	WSProxy = DataExchangeCached.GetWSProxyForInfoBaseNode(InfoBaseNode, ErrorMessageString);
	
	If WSProxy = Undefined Then
		Raise ErrorMessageString;
	EndIf;
	
	Return WSProxy.GetContinuousOperationStatus(ActionID, ErrorMessageString);
EndFunction

Function TempFileStorageDirectory()
	
	Return DataExchangeCached.TempFileStorageDirectory();
	
EndFunction

Function UniqueExchangeMessageFileName()
	
	Result = "Message{UUID}.xml";
	Result = StrReplace(Result, "UUID", String(New UUID));
	
	Return Result;
EndFunction

Function IsSubordinateDIBNode() Export
	
	Return ExchangePlans.MasterNode() <> Undefined;
	
EndFunction

// Returns an array of version numbers supported by the correspondent interface for the
// DataExchange subsystem.
// 
// Parameters:
//  ExternalConnection - COMconnection object that is used for working with the
//                       correspondent infobase.
//
// Returns:
//  Array of version numbers supported by the correspondent interface.
//
Function CorrespondentVersionsViaExternalConnection(ExternalConnection) Export
	
	Return CommonUse.GetInterfaceVersionsViaExternalConnection(ExternalConnection, "DataExchange");
	
EndFunction

Function AllConfigurationReferenceTypes() Export
	
	Return DataExchangeCached.AllConfigurationReferenceTypes();
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Session initialization

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
	
	Selection = Query.Execute().Choose();
	
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
	
	Selection = Query.Execute().Choose();
	
	While Selection.Next() Do
		
		ExchangeRuleStructure = Selection.ReadRulesAlready.Get();
		
		FillPropertyValuesForValueTable(SelectiveObjectChangeRecordRules, ExchangeRuleStructure["SelectiveObjectChangeRecordRules"]);
		
	EndDo;
	
	Return SelectiveObjectChangeRecordRules;
	
EndFunction

Function InitObjectChangeRecordRuleTable()
	
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
	
	// EVENT HANDLERS
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

Function ExchangePlanContainsNoNodes(Val ExchangePlanName)
	
	QueryText = "
	|SELECT TOP 1 1
	|FROM
	|	ExchangePlan." + ExchangePlanName + " AS ExchangePlan
	|WHERE
	|	ExchangePlan.Ref <> &ThisNode
	|";
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("ThisNode", ExchangePlans[ExchangePlanName].ThisNode());
	
	Return Query.Execute().IsEmpty()
	
EndFunction

Procedure FillPropertyValuesForORRValueTable(TargetTable, SourceTable)
	
	For Each SourceRow In SourceTable Do
		
		FillPropertyValues(TargetTable.Add(), SourceRow);
		
	EndDo;
	
EndProcedure

Procedure FillPropertyValuesForValueTable(TargetTable, SourceTable)
	
	For Each SourceRow In SourceTable Do
		
		FillPropertyValues(TargetTable.Add(), SourceRow);
		
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Data exchange settings structure initialization

// Initializes the data exchange subsystem for performing the exchange.
// 
// Parameters:
// 
// Returns:
//  ExchangeSettingsStructure - Structure - structure with all necessary data and
//                              objects for performing the exchange.
//
Function GetExchangeSettingStructureForInfoBaseNode(InfoBaseNode, ActionOnExchange,
	ExchangeMessageTransportKind,
	UseTransportSettings = True) Export
	
	// Return value
	ExchangeSettingsStructure = BaseExchangeSettingsStructure();
	
	ExchangeSettingsStructure.InfoBaseNode          = InfoBaseNode;
	ExchangeSettingsStructure.ActionOnExchange      = ActionOnExchange;
	ExchangeSettingsStructure.ExchangeTransportKind = ExchangeMessageTransportKind;
	ExchangeSettingsStructure.IsDIBExchange         = DataExchangeCached.IsDistributedInfoBaseNode(InfoBaseNode);
	
	InitExchangeSettingsStructureForInfoBaseNode(ExchangeSettingsStructure, UseTransportSettings);
	
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

Function GetExchangeSettingsStructureForExternalConnection(InfoBaseNode, ActionOnExchange, TransactionItemCount)
	
	// Return value
	ExchangeSettingsStructure = BaseExchangeSettingsStructure();
	
	ExchangeSettingsStructure.InfoBaseNode     = InfoBaseNode;
	ExchangeSettingsStructure.ActionOnExchange = ActionOnExchange;
	ExchangeSettingsStructure.IsDIBExchange    = DataExchangeCached.IsDistributedInfoBaseNode(InfoBaseNode);
	
	PropertyStructure = CommonUse.GetAttributeValues(ExchangeSettingsStructure.InfoBaseNode, "Code, Description");
	
	ExchangeSettingsStructure.InfoBaseNodeCode        = PropertyStructure.Code;
	ExchangeSettingsStructure.InfobaseNodeDescription = PropertyStructure.Description;
	
	
	ExchangeSettingsStructure.TransportSettings   = InformationRegisters.ExchangeTransportSettings.GetNodeTransportSettings(ExchangeSettingsStructure.InfoBaseNode);
	ExchangeSettingsStructure.DebugMode           = ExchangeSettingsStructure.TransportSettings.ExecuteExchangeInDebugMode;
	ExchangeSettingsStructure.ExchangeLogFileName = ExchangeSettingsStructure.TransportSettings.ExchangeLogFileName;
	
	If TransactionItemCount = Undefined Then
		
		TransactionItemCount = ?(ExchangeSettingsStructure.ActionOnExchange = Enums.ActionsOnExchange.DataImport,
									ExchangeSettingsStructure.TransportSettings.DataImportTransactionItemCount,
									ExchangeSettingsStructure.TransportSettings.DataExportTransactionItemCount);
		
		
	EndIf;
	
	ExchangeSettingsStructure.TransactionItemCount = TransactionItemCount;
	
	// CALCULATED VALUES
	ExchangeSettingsStructure.DoDataImport = (ExchangeSettingsStructure.ActionOnExchange = Enums.ActionsOnExchange.DataImport);
	ExchangeSettingsStructure.DoDataExport = (ExchangeSettingsStructure.ActionOnExchange = Enums.ActionsOnExchange.DataExport);
	
	ExchangeSettingsStructure.ExchangePlanName = DataExchangeCached.GetExchangePlanName(ExchangeSettingsStructure.InfoBaseNode);
	
	ExchangeSettingsStructure.CurrentExchangePlanNode = DataExchangeCached.GetThisExchangePlanNode(ExchangeSettingsStructure.ExchangePlanName);
	ExchangeSettingsStructure.CurrentExchangePlanNodeCode = CommonUse.GetAttributeValue(ExchangeSettingsStructure.CurrentExchangePlanNode, "Code");
	
	// Getting the message key for the event log
	ExchangeSettingsStructure.EventLogMessageKey = GetEventLogMessageKey(ExchangeSettingsStructure.InfoBaseNode, ExchangeSettingsStructure.ActionOnExchange);
	
	ExchangeSettingsStructure.ExchangeTransportKind = Enums.ExchangeMessageTransportKinds.COM;
	
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



// Returns:
//  ExchangeSettingsStructure - Structure - structure with all necessary data and
//                              objects for performing the exchange.
//
Function GetExchangeSettingsStructure(ExchangeExecutionSettings, LineNumber) Export
	
	// Return value
	ExchangeSettingsStructure = BaseExchangeSettingsStructure();
	
	InitExchangeSettingsStructure(ExchangeSettingsStructure, ExchangeExecutionSettings, LineNumber);
	
	If ExchangeSettingsStructure.Cancel Then
		Return ExchangeSettingsStructure;
	EndIf;
	
	// Validating settings structure values for the exchange. Writing errors to the event log.
	CheckExchangeStructure(ExchangeSettingsStructure);
	
	// Canceling if settings contain errors
	If ExchangeSettingsStructure.Cancel Then
		Return ExchangeSettingsStructure;
	EndIf;
	
	// Initializing exchange message transport data processor
	InitExchangeMessageTransportDataProcessor(ExchangeSettingsStructure);
	
	// Initializing the exchange data processor
	If ExchangeSettingsStructure.IsDIBExchange Then
		
		InitDataExchangeDataProcessor(ExchangeSettingsStructure);
		
	ElsIf ExchangeSettingsStructure.ExchangeByObjectConversionRules Then
		
		InitDataExchangeDataProcessorForConversionRules(ExchangeSettingsStructure);
		
	EndIf;
	
	Return ExchangeSettingsStructure;
EndFunction

// Retrieving the transport settings structure for performing the data exchange.
//
Function GetTransportSettingsStructure(InfoBaseNode, ExchangeMessageTransportKind) Export
	
	// Return value
	ExchangeSettingsStructure = BaseExchangeSettingsStructure();
	
	ExchangeSettingsStructure.InfoBaseNode = InfoBaseNode;
	ExchangeSettingsStructure.ActionOnExchange      = Enums.ActionsOnExchange.DataImport;
	ExchangeSettingsStructure.ExchangeTransportKind    = ExchangeMessageTransportKind;
	
	InitExchangeSettingsStructureForInfoBaseNode(ExchangeSettingsStructure, True);
	
	// Validating settings structure values for the exchange. Writing error messages to the event log.
	CheckExchangeStructure(ExchangeSettingsStructure);
	
	// Canceling if settings contain errors
	If ExchangeSettingsStructure.Cancel Then
		Return Undefined;
	EndIf;
	
	// Initializing exchange message transport data processor
	InitExchangeMessageTransportDataProcessor(ExchangeSettingsStructure);
	
	Return ExchangeSettingsStructure;
EndFunction

Procedure InitExchangeSettingsStructure(ExchangeSettingsStructure, ExchangeExecutionSettings, LineNumber)
	
	QueryText = "
	|SELECT
	|	ExchangeExecutionSettingsExchangeSettings.InfoBaseNode          AS InfoBaseNode,
	|	ExchangeExecutionSettingsExchangeSettings.InfoBaseNode.Code     AS InfoBaseNodeCode,
	|	ExchangeExecutionSettingsExchangeSettings.ExchangeTransportKind AS ExchangeTransportKind,
	|	ExchangeExecutionSettingsExchangeSettings.CurrentAction         AS ActionOnExchange,
	|	ExchangeExecutionSettingsExchangeSettings.TransactionItemCount  AS TransactionItemCount,
	|	ExchangeExecutionSettingsExchangeSettings.Ref                   AS ExchangeExecutionSettings,
	|	ExchangeExecutionSettingsExchangeSettings.Ref.Description       AS ExchangeExecutionSettingsDescription,
	|	CASE
	|		WHEN ExchangeExecutionSettingsExchangeSettings.CurrentAction  = VALUE(Enum.ActionsOnExchange.DataImport) THEN True
	|		ELSE False
	|	END                                                             AS DoDataImport,
	|	CASE
	|		WHEN ExchangeExecutionSettingsExchangeSettings.CurrentAction  = VALUE(Enum.ActionsOnExchange.DataExport) THEN True
	|		ELSE False
	|	END                                                             AS DoDataExport
	|FROM
	|	Catalog.DataExchangeScenarios.ExchangeSettings                    AS ExchangeExecutionSettingsExchangeSettings
	|WHERE
	|	  ExchangeExecutionSettingsExchangeSettings.Ref          = &ExchangeExecutionSettings
	|	AND ExchangeExecutionSettingsExchangeSettings.LineNumber = &LineNumber
	|";
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("ExchangeExecutionSettings", ExchangeExecutionSettings);
	Query.SetParameter("LineNumber",               LineNumber);
	
	Selection = Query.Execute().Choose();
	Selection.Next();
	
	// Filling structure property value
	FillPropertyValues(ExchangeSettingsStructure, Selection);
	
	ExchangeSettingsStructure.IsDIBExchange = DataExchangeCached.IsDistributedInfoBaseNode(ExchangeSettingsStructure.InfoBaseNode);
	
	ExchangeSettingsStructure.EventLogMessageKey = NStr("en = 'Data exchange'");
	
	// Checking whether basic exchange settings structure fields are filled
	CheckMainExchangeSettingsStructureFields(ExchangeSettingsStructure);
	
	If ExchangeSettingsStructure.Cancel Then
		Return;
	EndIf;
	
	
	ExchangeSettingsStructure.ExchangePlanName                = ExchangeSettingsStructure.InfoBaseNode.Metadata().Name;
	ExchangeSettingsStructure.ExchangeByObjectConversionRules = DataExchangeCached.IsUniversalDataExchangeNode(ExchangeSettingsStructure.InfoBaseNode);
	
	ExchangeSettingsStructure.CurrentExchangePlanNode     = ExchangePlans[ExchangeSettingsStructure.ExchangePlanName].ThisNode();
	ExchangeSettingsStructure.CurrentExchangePlanNodeCode = ExchangeSettingsStructure.CurrentExchangePlanNode.Code;
	
	ExchangeSettingsStructure.DataExchangeMessageTransportDataProcessorName = DataExchangeMessageTransportDataProcessorName(ExchangeSettingsStructure.ExchangeTransportKind);
	
	// Getting the message key for the event log
	ExchangeSettingsStructure.EventLogMessageKey = GetEventLogMessageKey(ExchangeSettingsStructure.InfoBaseNode, ExchangeSettingsStructure.ActionOnExchange);
	
	
	ExchangeSettingsStructure.TransportSettings   = InformationRegisters.ExchangeTransportSettings.GetNodeTransportSettings(ExchangeSettingsStructure.InfoBaseNode, ExchangeSettingsStructure.ExchangeTransportKind);
	ExchangeSettingsStructure.ExchangeLogFileName = ExchangeSettingsStructure.TransportSettings.ExchangeLogFileName;
	ExchangeSettingsStructure.DebugMode           = ExchangeSettingsStructure.TransportSettings.ExecuteExchangeInDebugMode;
	
EndProcedure

Procedure InitExchangeSettingsStructureForInfoBaseNode(ExchangeSettingsStructure, UseTransportSettings)
	
	PropertyStructure = CommonUse.GetAttributeValues(ExchangeSettingsStructure.InfoBaseNode, "Code, Description");
	
	ExchangeSettingsStructure.InfoBaseNodeCode        = PropertyStructure.Code;
	ExchangeSettingsStructure.InfobaseNodeDescription = PropertyStructure.Description;
	
	ExchangeSettingsStructure.TransportSettings = InformationRegisters.ExchangeTransportSettings.GetNodeTransportSettings(ExchangeSettingsStructure.InfoBaseNode);
	
	If UseTransportSettings Then
		
		// Using the default value if the transport kind is not specified
		If ExchangeSettingsStructure.ExchangeTransportKind = Undefined Then
			ExchangeSettingsStructure.ExchangeTransportKind = ExchangeSettingsStructure.TransportSettings.DefaultExchangeMessageTransportKind;
		EndIf;
		
		// Using the FILE transport if the transport kind is not specified
		If Not ValueIsFilled(ExchangeSettingsStructure.ExchangeTransportKind) Then
			
			ExchangeSettingsStructure.ExchangeTransportKind = Enums.ExchangeMessageTransportKinds.FILE;
			
		EndIf;
		
		If ExchangeSettingsStructure.ExchangeTransportKind = Enums.ExchangeMessageTransportKinds.Combi Then
			
			ExchangeSettingsStructure.ExchangeTransportKind = ExchangeSettingsStructure.TransportSettings.CombiExchangeMessageTransportKind;
			ExchangeSettingsStructure.UseTempDirectoryForSendingAndReceivingMessages = False; 
// Export and import of the exchange message file will be performed directly from the exchange directory.
			
		EndIf;
		
		ExchangeSettingsStructure.DataExchangeMessageTransportDataProcessorName = DataExchangeMessageTransportDataProcessorName(ExchangeSettingsStructure.ExchangeTransportKind);
		
	EndIf;
	
	ExchangeSettingsStructure.DebugMode           = ExchangeSettingsStructure.TransportSettings.ExecuteExchangeInDebugMode;
	ExchangeSettingsStructure.ExchangeLogFileName = ExchangeSettingsStructure.TransportSettings.ExchangeLogFileName;
	
	ExchangeSettingsStructure.TransactionItemCount = ?(ExchangeSettingsStructure.ActionOnExchange = Enums.ActionsOnExchange.DataImport,
								ExchangeSettingsStructure.TransportSettings.DataImportTransactionItemCount,
								ExchangeSettingsStructure.TransportSettings.DataExportTransactionItemCount
	);
	
	// DEFAULT VALUES
	ExchangeSettingsStructure.ExchangeExecutionSettings            = Undefined;
	ExchangeSettingsStructure.ExchangeExecutionSettingsDescription = "";
	
	// CALCULATED VALUES
	ExchangeSettingsStructure.DoDataImport = (ExchangeSettingsStructure.ActionOnExchange = Enums.ActionsOnExchange.DataImport);
	ExchangeSettingsStructure.DoDataExport = (ExchangeSettingsStructure.ActionOnExchange = Enums.ActionsOnExchange.DataExport);
	
	ExchangeSettingsStructure.ExchangePlanName = ExchangeSettingsStructure.InfoBaseNode.Metadata().Name;
	ExchangeSettingsStructure.ExchangeByObjectConversionRules = DataExchangeCached.IsUniversalDataExchangeNode(ExchangeSettingsStructure.InfoBaseNode);
	
	ExchangeSettingsStructure.CurrentExchangePlanNode    = ExchangePlans[ExchangeSettingsStructure.ExchangePlanName].ThisNode();
	ExchangeSettingsStructure.CurrentExchangePlanNodeCode = ExchangeSettingsStructure.CurrentExchangePlanNode.Code;
	
	// Getting the message key for the event log
	ExchangeSettingsStructure.EventLogMessageKey = GetEventLogMessageKey(ExchangeSettingsStructure.InfoBaseNode, ExchangeSettingsStructure.ActionOnExchange);
	
	If ExchangeSettingsStructure.TransportSettings.Property("WSUseLargeDataTransfer") Then
		
		ExchangeSettingsStructure.UseLargeDataTransfer = ExchangeSettingsStructure.TransportSettings.WSUseLargeDataTransfer;
		
	EndIf;
	
EndProcedure

Function BaseExchangeSettingsStructure()
	
	ExchangeSettingsStructure = New Structure;
	
	// Structure of settings by query fields
	
	ExchangeSettingsStructure.Insert("StartDate");
	ExchangeSettingsStructure.Insert("EndDate");
	
	ExchangeSettingsStructure.Insert("LineNumber");
	ExchangeSettingsStructure.Insert("ExchangeExecutionSettings");
	ExchangeSettingsStructure.Insert("ExchangeExecutionSettingsDescription");
	ExchangeSettingsStructure.Insert("InfoBaseNode");
	ExchangeSettingsStructure.Insert("InfoBaseNodeCode", "");
	ExchangeSettingsStructure.Insert("InfobaseNodeDescription", "");
	ExchangeSettingsStructure.Insert("ExchangeTransportKind");
	ExchangeSettingsStructure.Insert("ActionOnExchange");
	ExchangeSettingsStructure.Insert("TransactionItemCount");
	ExchangeSettingsStructure.Insert("DebugMode");
	ExchangeSettingsStructure.Insert("DoDataImport");
	ExchangeSettingsStructure.Insert("DoDataExport");
	ExchangeSettingsStructure.Insert("UseLargeDataTransfer", False);
	
	// Additional settings structure
	ExchangeSettingsStructure.Insert("Cancel", False);
	ExchangeSettingsStructure.Insert("IsDIBExchange", False);
	ExchangeSettingsStructure.Insert("UseTempDirectoryForSendingAndReceivingMessages", True);
	
	ExchangeSettingsStructure.Insert("DataExchangeDataProcessor");
	ExchangeSettingsStructure.Insert("ExchangeMessageTransportDataProcessor");
	
	ExchangeSettingsStructure.Insert("ExchangePlanName");
	ExchangeSettingsStructure.Insert("CurrentExchangePlanNode");
	ExchangeSettingsStructure.Insert("CurrentExchangePlanNodeCode");
	
	ExchangeSettingsStructure.Insert("ExchangeByObjectConversionRules");
	
	ExchangeSettingsStructure.Insert("DataExchangeMessageTransportDataProcessorName");
	
	ExchangeSettingsStructure.Insert("EventLogMessageKey");
	
	ExchangeSettingsStructure.Insert("TransportSettings");
	ExchangeSettingsStructure.Insert("ExchangeLogFileName");
	
	ExchangeSettingsStructure.Insert("ObjectConversionRules");
	ExchangeSettingsStructure.Insert("RulesLoaded");
	
	// Structure for writing event messages to the event log
	ExchangeSettingsStructure.Insert("ExchangeExecutionResult");
	ExchangeSettingsStructure.Insert("ActionOnExchange");
	ExchangeSettingsStructure.Insert("ProcessedObjectCount", 0);
	ExchangeSettingsStructure.Insert("ExchangeMessage",      "");
	ExchangeSettingsStructure.Insert("ErrorMessageString",   "");
	
	Return ExchangeSettingsStructure;
EndFunction

Procedure CheckMainExchangeSettingsStructureFields(ExchangeSettingsStructure)
	
	If Not ValueIsFilled(ExchangeSettingsStructure.InfoBaseNode) Then
		
		// The infobase node must be specified
		ErrorMessageString = NStr(
		"en = 'The infobase node to exchange with is not specified. The exchange has been canceled.'");
		WriteEventLogDataExchange(ErrorMessageString, ExchangeSettingsStructure, True);
		SetExchangeInitEnd(ExchangeSettingsStructure);
		
	ElsIf Not ValueIsFilled(ExchangeSettingsStructure.ExchangeTransportKind) Then
		
		ErrorMessageString = NStr("en = 'The exchange transport kind is not specified. The exchange has been canceled.'");
		WriteEventLogDataExchange(ErrorMessageString, ExchangeSettingsStructure, True);
		
		SetExchangeInitEnd(ExchangeSettingsStructure);
		
	ElsIf Not ValueIsFilled(ExchangeSettingsStructure.ActionOnExchange) Then
		
		ErrorMessageString = NStr("en = 'The action to be executed (import or export) is not specified. The exchange has been canceled.'");
		WriteEventLogDataExchange(ErrorMessageString, ExchangeSettingsStructure, True);
		
		SetExchangeInitEnd(ExchangeSettingsStructure);
		
	EndIf;
	
EndProcedure

Procedure CheckExchangeStructure(ExchangeSettingsStructure, UseTransportSettings = True)
	
	If Not ValueIsFilled(ExchangeSettingsStructure.InfoBaseNode) Then
		
		// The infobase node must be specified
		ErrorMessageString = NStr(
		"en = 'The infobase node to exchange with is not specified. The exchange has been canceled.'");
		WriteEventLogDataExchange(ErrorMessageString, ExchangeSettingsStructure, True);
		SetExchangeInitEnd(ExchangeSettingsStructure);
		
	ElsIf UseTransportSettings And Not ValueIsFilled(ExchangeSettingsStructure.ExchangeTransportKind) Then
		
		ErrorMessageString = NStr("en = 'The exchange transport kind is not specified. The exchange has been canceled.'");
		WriteEventLogDataExchange(ErrorMessageString, ExchangeSettingsStructure, True);
		
		SetExchangeInitEnd(ExchangeSettingsStructure);
		
	ElsIf Not ValueIsFilled(ExchangeSettingsStructure.ActionOnExchange) Then
		
		ErrorMessageString = NStr("en = 'The action to be executed (import or export) is not specified. The exchange has been canceled.'");
		WriteEventLogDataExchange(ErrorMessageString, ExchangeSettingsStructure, True);
		
		SetExchangeInitEnd(ExchangeSettingsStructure);
		
	ElsIf ExchangeSettingsStructure.InfoBaseNode.DeletionMark Then
		
		// The infobase node cannot be marked for deletion
		ErrorMessageString = NStr("en = 'The infobase is marked for deletion. The exchange has been canceled.'");
		WriteEventLogDataExchange(ErrorMessageString, ExchangeSettingsStructure, True);
		
		SetExchangeInitEnd(ExchangeSettingsStructure);
	
	ElsIf ExchangeSettingsStructure.InfoBaseNode = ExchangeSettingsStructure.CurrentExchangePlanNode Then
		
		// The exchange with the current infobase node cannot be provided
		ErrorMessageString = NStr(
		"en = 'The exchange with the current infobase node cannot be provided. The exchange has been canceled.'");
		WriteEventLogDataExchange(ErrorMessageString, ExchangeSettingsStructure, True);
		
		SetExchangeInitEnd(ExchangeSettingsStructure);
	
	ElsIf IsBlankString(ExchangeSettingsStructure.InfoBaseNodeCode)
		  Or IsBlankString(ExchangeSettingsStructure.CurrentExchangePlanNodeCode) Then
		
		// The infobase codes must be specified
		ErrorMessageString = NStr("en = 'One of exchange nodes has an empty code. The exchange has been canceled.'");
		WriteEventLogDataExchange(ErrorMessageString, ExchangeSettingsStructure, True);
		
		SetExchangeInitEnd(ExchangeSettingsStructure);
		
	EndIf;
	
EndProcedure

Procedure InitDataExchangeDataProcessor(ExchangeSettingsStructure)
	
	// Canceling initialization if settings contain errors
	If ExchangeSettingsStructure.Cancel Then
		Return;
	EndIf;
	
	// Creating the data processor
	DataExchangeDataProcessor = DataProcessors.DistributedInfoBaseObjectsConversion.Create();
	
	// Initializing properties
	DataExchangeDataProcessor.InfoBaseNode         = ExchangeSettingsStructure.InfoBaseNode;
	DataExchangeDataProcessor.TransactionItemCount = ExchangeSettingsStructure.TransactionItemCount;
	DataExchangeDataProcessor.EventLogMessageKey   = ExchangeSettingsStructure.EventLogMessageKey;
	
	ExchangeSettingsStructure.Insert("DataExchangeDataProcessor", DataExchangeDataProcessor);
	
EndProcedure

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

Procedure InitExchangeMessageTransportDataProcessor(ExchangeSettingsStructure)
	
	// Creating the transport data processor
	ExchangeMessageTransportDataProcessor = DataProcessors[ExchangeSettingsStructure.DataExchangeMessageTransportDataProcessorName].Create();
	
	IsOutgoingMessage = ExchangeSettingsStructure.DoDataExport;
	
	// Filling common attributes (same for all transport data processors)
	ExchangeMessageTransportDataProcessor.MessageFileNamePattern = GetMessageFileNamePattern(ExchangeSettingsStructure.CurrentExchangePlanNode, ExchangeSettingsStructure.InfoBaseNode, IsOutgoingMessage);
	
	// Filling transport settings (various for each transport data processor)
	FillPropertyValues(ExchangeMessageTransportDataProcessor, ExchangeSettingsStructure.TransportSettings);
	
	FillPropertyValues(ExchangeMessageTransportDataProcessor, ExchangeSettingsStructure, "UseTempDirectoryForSendingAndReceivingMessages");
	
	// Initialing transport
	ExchangeMessageTransportDataProcessor.Initialization();
	
	ExchangeSettingsStructure.Insert("ExchangeMessageTransportDataProcessor", ExchangeMessageTransportDataProcessor);
	
EndProcedure

Function GetDataExchangeExportDataProcessor(ExchangeSettingsStructure)
	
	DataExchangeDataProcessor = DataProcessors.InfoBaseObjectConversion.Create();
	
	DataExchangeDataProcessor.ExchangeMode = "Data";
	
	SetDataExportExchangeRules(DataExchangeDataProcessor, ExchangeSettingsStructure);
	
	// Specifying the exchange nodes
	DataExchangeDataProcessor.NodeForExchange        = ExchangeSettingsStructure.InfoBaseNode;
	DataExchangeDataProcessor.BackgroundExchangeNode = Undefined;
	
	DataExchangeDataProcessor.DontExportObjectsByRefs = True;
	DataExchangeDataProcessor.ExchangeRuleFileName   = "1";
	
	SetCommonParametersForDataExchangeProcessing(DataExchangeDataProcessor, ExchangeSettingsStructure);
	
	Return DataExchangeDataProcessor;
	
EndFunction

Function GetDataExchangeImportDataProcessor(ExchangeSettingsStructure)
	
	DataExchangeDataProcessor = DataProcessors.InfoBaseObjectConversion.Create();
	
	DataExchangeDataProcessor.ExchangeMode = "Import";
	DataExchangeDataProcessor.ExchangeNodeDataImport = ExchangeSettingsStructure.InfoBaseNode;
	
	SetCommonParametersForDataExchangeProcessing(DataExchangeDataProcessor, ExchangeSettingsStructure);
	
	Return DataExchangeDataProcessor
	
EndFunction

Procedure SetCommonParametersForDataExchangeProcessing(DataExchangeDataProcessor, ExchangeSettingsStructure)
	
	DataExchangeDataProcessor.OutputInfoMessagesToMessageWindow = False;
	DataExchangeDataProcessor.WriteInfoMessagesToLog      = DataExchangeDataProcessor.OutputInfoMessagesToMessageWindow;
	
	DataExchangeDataProcessor.AppendDataToExchangeLog = False;
	DataExchangeDataProcessor.ExportAllowedOnly       = False;
	
	DataExchangeDataProcessor.DebugModeFlag = ExchangeSettingsStructure.DebugMode;
	
	DataExchangeDataProcessor.UseTransactions         = ExchangeSettingsStructure.TransactionItemCount <> 1;
	DataExchangeDataProcessor.ObjectCountPerTransaction = ExchangeSettingsStructure.TransactionItemCount;
	
	DataExchangeDataProcessor.ExchangeLogFileName = ExchangeSettingsStructure.ExchangeLogFileName;
	
	DataExchangeDataProcessor.EventLogMessageKey = ExchangeSettingsStructure.EventLogMessageKey;
	
EndProcedure

Procedure SetDataExportExchangeRules(DataExchangeXMLDataProcessor, ExchangeSettingsStructure)
	
	ObjectConversionRules = InformationRegisters.DataExchangeRules.GetReadObjectConversionRules(ExchangeSettingsStructure.ExchangePlanName);
	
	If ObjectConversionRules = Undefined Then
		
		// Exchange rules must be specified
		NString = NStr("en = 'Conversion rules for the %1 exchange plan is not specified. The data export has been canceled.'");
		ErrorMessageString = StringFunctionsClientServer.SubstituteParametersInString(NString, ExchangeSettingsStructure.ExchangePlanName);
		WriteEventLogDataExchange(ErrorMessageString, ExchangeSettingsStructure, True);
		SetExchangeInitEnd(ExchangeSettingsStructure);
		
		Return;
	EndIf;
	
	DataExchangeXMLDataProcessor.SavedSettings = ObjectConversionRules;
	
	DataExchangeXMLDataProcessor.RestoreRulesFromInternalFormat();
	
EndProcedure

Procedure SetExchangeInitEnd(ExchangeSettingsStructure)
	
	ExchangeSettingsStructure.Cancel = True;
	ExchangeSettingsStructure.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Canceled;
	
EndProcedure

Function GetMessageFileNamePattern(CurrentExchangePlanNode, InfoBaseNode, IsOutgoingMessage)
	
	SenderNode    = ?(IsOutgoingMessage, CurrentExchangePlanNode, InfoBaseNode);
	RecipientNode = ?(IsOutgoingMessage, InfoBaseNode, CurrentExchangePlanNode);
	
	Return ExchangeMessageFileName(TrimAll(CommonUse.GetAttributeValue(SenderNode, "Code")),
									TrimAll(CommonUse.GetAttributeValue(RecipientNode, "Code")));
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Data exchange with full access rights

// Upgrades/sets reusable values and session parameters for the data exchange subsystem.
//
// Session parameters to be specified:
//  DataExchangeEnabled              - Boolean - flag that shows whether the data
//                                     exchange is used in the configuration. The data 
//                                     exchange is considered enabled if even one
//                                     exchange plan has a node except the predefined
//                                     one.
//  UsedExchangePlans                - FixedArray - array of exchange plan names that 
//                                     use the exchange.
//  ObjectChangeRecordRules          - ValueStorage - binary data that contains a value 
//                                     table with object registration rules.
//  SelectiveObjectChangeRecordRules - ValueStorage - binary data that contains a value 
//                                     table with selective object registration rules. 
//  ORMCachedValueRefreshDate        - Date (Date and time) - date of the last actual
//                                     cache for the data exchange subsystem.
// 
Procedure RefreshORMCachedValues() Export
	
	SetPrivilegedMode(True);
	
	// Updating reusable values
	RefreshReusableValues();
	
	// Getting configuration exchange plans used during the exchange
	UsedExchangePlans = GetUsedExchangePlans();
	
	// Flag that shows whether the exchange mechanism is enabled
	DataExchangeEnabled = (UsedExchangePlans.Count() <> 0);
	
	// Specifying the DataExchangeEnabled session parameter
	SessionParameters.DataExchangeEnabled = DataExchangeEnabled;
	
	// Specifying the UsedExchangePlans session parameter
	SessionParameters.UsedExchangePlans = New FixedArray(UsedExchangePlans);
	
	// Getting the registration rule table from the infobase
	ObjectChangeRecordRules = GetObjectChangeRecordRules();
	
	// Specifying the ObjectChangeRecordRules session parameter
	SessionParameters.ObjectChangeRecordRules = New ValueStorage(ObjectChangeRecordRules);
	
	// Specifying the SelectiveObjectChangeRecordRules session parameter
	SelectiveObjectChangeRecordRules = GetSelectiveObjectChangeRecordRules();
	
	SessionParameters.SelectiveObjectChangeRecordRules = New ValueStorage(SelectiveObjectChangeRecordRules);
	
	// CACHE ACTUALITY FLAG
	
	// Specifying the actual object registration mechanism update date
	ActualDate = GetFunctionalOption("CurrentORMCachedValueRefreshDate");
	
	SessionParameters.ORMCachedValueRefreshDate = ActualDate;
	
EndProcedure

// Specifies the client OS (or server) date and time as the ORMCachedValueRefreshDate constant value. 
// All reusable values of this subsystem become obsolete and require to be updated.

Procedure SetORMCachedValueRefreshDate() Export
	
	SetPrivilegedMode(True);
	// Writing the client OS date and time (CurrentDate())
	// The CurrentSessionDate() cannot be used.
	// The current server date in used as the unique ID of the object registration
	// mechanism cache.
	Constants.ORMCachedValueRefreshDate.Set(CurrentDate());
	
EndProcedure

// Specifies the data exchange subsystem session parameters.
//
// Parameters:
//  ParameterName       - String - name of the session parameter whose value is
//                        specified.
//  SpecifiedParameters - Array - set session parameter information.
// 
Procedure SessionParametersSetting(ParameterName, SpecifiedParameters) Export
	
	// Updating reusable values and session parameters
	RefreshORMCachedValues();
	
	// Registering names of parameters to be set up during the RefreshORMCachedValues
	// procedure execution.
	SpecifiedParameters.Add("DataExchangeEnabled");
	SpecifiedParameters.Add("UsedExchangePlans");
	SpecifiedParameters.Add("SelectiveObjectChangeRecordRules");
	SpecifiedParameters.Add("ObjectChangeRecordRules");
	SpecifiedParameters.Add("ORMCachedValueRefreshDate");
	
EndProcedure

// Checks whether the object registration mechanism cache is actual.
// If the cache is obsolete, it is filled with actual values.

Procedure RefreshORMCachedValuesIfNecessary() Export
	
	SetPrivilegedMode(True);
	
	If CommonUseCached.CanUseSeparatedData() Then
		
		ActualDate = GetFunctionalOption("CurrentORMCachedValueRefreshDate");
		
		If SessionParameters.ORMCachedValueRefreshDate <> ActualDate Then
			
			RefreshORMCachedValues();
			
			// Calling the procedure recursively
			RefreshORMCachedValuesIfNecessary();
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Retrieves an array of exchange plan nodes that have the "Export always" flag set.
// 
// Parameters:
//  ExchangePlanName  – String – exchange plan name whose nodes are checked.
//  FlagAttributeName – String – exchange plan attribute name for filtering nodes. 
// 
// Returns:
//  Array of exchange plan nodes that have the "Export always" flag set.
//
Function GetNodeArrayForChangeRecordExportAlways(Val ExchangePlanName, Val FlagAttributeName) Export
	
	QueryText = "
	|SELECT
	|	ExchangePlanHeader.Ref AS Node
	|FROM
	|	ExchangePlan.[ExchangePlanName] AS ExchangePlanHeader
	|WHERE
	|	  ExchangePlanHeader.Ref <> &ThisNode
	|	AND ExchangePlanHeader.[FlagAttributeName] = VALUE(Enum.ExchangeObjectExportModes.UnloadAlways)
	|	AND Not ExchangePlanHeader.DeletionMark
	|";
	
	QueryText = StrReplace(QueryText, "[ExchangePlanName]",    ExchangePlanName);
	QueryText = StrReplace(QueryText, "[FlagAttributeName]", FlagAttributeName);
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.SetParameter("ThisNode", DataExchangeCached.GetThisExchangePlanNode(ExchangePlanName));
	Query.Text = QueryText;
	
	Return Query.Execute().Unload().UnloadColumn("Node");
	
EndFunction

// Retrieves an array of exchange plan nodes that have the "Export always" flag set.
// 
// Parameters:
//  Ref               – Ref - The result array consist of nodes, in which this
//                      reference object was exported before.
//  ExchangePlanName  – String – exchange plan name whose nodes are checked.
//  FlagAttributeName – String – exchange plan attribute name for filtering nodes.
// 
// Returns:
//  Array of exchange plan nodes that have the "Export always" flag set.
//
Function GetNodeArrayForChangeRecordExportIfNecessary(Ref, Val ExchangePlanName, Val FlagAttributeName) Export
	
	QueryText = "
	|SELECT DISTINCT
	|	ExchangePlanHeader.Ref AS Node
	|FROM
	|	ExchangePlan.[ExchangePlanName] AS ExchangePlanHeader
	|LEFT JOIN
	|	InformationRegister.InfoBaseObjectMaps AS InfoBaseObjectMaps
	|ON
	|	ExchangePlanHeader.Ref = InfoBaseObjectMaps.InfoBaseNode
	|	AND InfoBaseObjectMaps.SourceUUID = &Object
	|WHERE
	|	     ExchangePlanHeader.Ref <> &ThisNode
	|	AND    ExchangePlanHeader.[FlagAttributeName] = VALUE(Enum.ExchangeObjectExportModes.ExportIfNecessary)
	|	AND NOT ExchangePlanHeader.DeletionMark
	|	AND    InfoBaseObjectMaps.SourceUUID = &Object
	|";
	
	QueryText = StrReplace(QueryText, "[ExchangePlanName]",    ExchangePlanName);
	QueryText = StrReplace(QueryText, "[FlagAttributeName]", FlagAttributeName);
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("ThisNode", DataExchangeCached.GetThisExchangePlanNode(ExchangePlanName));
	Query.SetParameter("Object",   Ref);
	
	Return Query.Execute().Unload().UnloadColumn("Node");
	
EndFunction

// Finds the scheduled job by the UUID.
// 
// Parameters:
//  JobUUID - String - string with the scheduled job UUID.
// 
// Returns:
//  Undefined    - if no job is found.
//  ScheduledJob - found by UUID scheduled job.
//
Function FindScheduledJobByParameter(JobUUID) Export
	
	// Return value
	ScheduledJob = Undefined;
	
	If IsBlankString(JobUUID) Then
		
		Return Undefined;
		
	EndIf;
	
	SetPrivilegedMode(True);
	
	Try
		
		ScheduledJob = ScheduledJobs.FindByUUID(New UUID(JobUUID));
		
	Except
		
		ScheduledJob = Undefined;
		
	EndTry;
	
	Return ScheduledJob;
	
EndFunction

// Checks whether the exchange is enabled.
// Returns:
//  Boolean - True if the system has an enabled exchange, otherwise is False.
//
Function DataExchangeEnabled() Export
	
	SetPrivilegedMode(True);
	
	Return SessionParameters.DataExchangeEnabled;
	
EndFunction

// Retrieves an array of all nodes except the predefined one for the specified exchange plan.
// 
// Parameters:
//  ExchangePlanName - String - exchange plan name as it is set in the designer.
// 
// Returns:
//  Array - array of all nodes except the predefined one for the specified exchange plan.


Function AllExchangePlanNodes(ExchangePlanName) Export
	
	SetPrivilegedMode(True);
	
	Return DataExchangeCached.GetExchangePlanNodeArray(ExchangePlanName);
	
EndFunction

// Returns the object property value structure received with a query from the infobase, 
// where structure keys are property names and structure values are object property values.
// 
// Parameters:
//  Ref – reference to the infobase object whose property values will be retrieved. 
// 
// Returns:
//  Structure - object property value structure.
//
Function GetPropertyValuesForRef(Ref, ObjectProperties, Val ObjectPropertiesString, Val MetadataObjectName) Export
	
	PropertyValues = DataExchangeEvents.CopyStructure(ObjectProperties);
	
	If PropertyValues.Count() = 0 Then
		
		Return PropertyValues; // Returning the empty structure
		
	EndIf;
	
	QueryText = "
	|SELECT
	|	[ObjectPropertiesString]
	|FROM
	|	[MetadataObjectName] AS Table
	|WHERE
	|	Table.Ref = &Ref
	|";
	
	QueryText = StrReplace(QueryText, "[ObjectPropertiesString]", ObjectPropertiesString);
	QueryText = StrReplace(QueryText, "[MetadataObjectName]",    MetadataObjectName);
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("Ref", Ref);
	
	SetPrivilegedMode(True);
	
	Try
		
		Selection = Query.Execute().Choose();
		
	Except
		
		// Writing the error message to the event log
		MessageString = NStr("en = 'Error retrieving references properties. Error executing the query: [ErrorDescription]'");
		MessageString = StrReplace(MessageString, "[ErrorDescription]", ErrorDescription());
		DataExchangeEvents.WriteEventLogORR(MessageString, Ref.Metadata());
		
		// Setting all properties to Undefined
		For Each Item In PropertyValues Do
			
			PropertyValues[Item.Key] = Undefined;
			
		EndDo;
		
		Return PropertyValues;
	EndTry;
	
	If Selection.Next() Then
		
		For Each Item In PropertyValues Do
			
			PropertyValues[Item.Key] = Selection[Item.Key];
			
		EndDo;
		
	EndIf;
	
	Return PropertyValues;
	
EndFunction

// Returns an array of exchange plan nodes by the specified query parameters and the
// text of a query the exchange plan table
//

Function NodeArrayByPropertyValues(PropertyValues, Val QueryText, Val ExchangePlanName, Val FlagAttributeName) Export
	
	SetPrivilegedMode(True);
	
	// Return value
	NodeArrayResult = New Array;
	
	// Creating a query for getting exchange plans nodes
	Query = New Query;
	
	QueryText = StrReplace(QueryText, "[RequiredConditions]",
				"AND     ExchangePlanMainTable.Ref <> &" + ExchangePlanName + "ThisNode
				|AND NOT ExchangePlanMainTable.DeletionMark
				|[FilterConditionByFlagAttribute]
				|");
	
	If IsBlankString(FlagAttributeName) Then
		
		QueryText = StrReplace(QueryText, "[FilterConditionByFlagAttribute]", "");
		
	Else
		
		QueryText = StrReplace(QueryText, "[FilterConditionByFlagAttribute]",
			"AND  (ExchangePlanMainTable.[FlagAttributeName] = VALUE(Enum.ExchangeObjectExportModes.ExportByCondition)
			|OR ExchangePlanMainTable.[FlagAttributeName] = VALUE(Enum.ExchangeObjectExportModes.EmptyRef))");
		
		QueryText = StrReplace(QueryText, "[FlagAttributeName]", FlagAttributeName);
		
	EndIf;
	
	// Query text
	Query.Text = QueryText;
	
	Query.SetParameter(ExchangePlanName + "ThisNode", DataExchangeCached.GetThisExchangePlanNode(ExchangePlanName));
	
	// Specifying query parameter values by object properties
	For Each Item In PropertyValues Do
		
		Query.SetParameter("ObjectProperty_" + Item.Key, Item.Value);
		
	EndDo;
	
	Try
		
		NodeArrayResult = Query.Execute().Unload().UnloadColumn("Ref");
		
	Except
		
		// Writing the error message to the event log
		
		MessageString = NStr("en = 'Error retrieving recipient node list. Error executing query: [ErrorDescription]'");
		MessageString = StrReplace(MessageString, "[ErrorDescription]", ErrorDescription());
		
		DataExchangeEvents.WriteEventLogORR(MessageString);
		
		Return New Array // Returning the blank array
		
	EndTry;
	
	// Returning the result array of nodes
	Return NodeArrayResult;
	
EndFunction

// Returns the ObjectChangeRecordRules session parameter value received in privileged mode.
// Returns:
//  ValueStorage - ObjectChangeRecordRules session parameter value.
//
Function SessionParametersObjectChangeRecordRules() Export
	
	SetPrivilegedMode(True);
	
	Return SessionParameters.ObjectChangeRecordRules;
	
EndFunction

Procedure ExecuteHandlerInPrivilegedMode(Value, Val HandlerLine) Export
	
	SetPrivilegedMode(True);
	
	Execute(HandlerLine);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Constants

// Returns the unlimited length string literal.
//
// Returns: 
//  String.
//
Function UnlimitedLengthString() Export
	
	Return "(Unlimited string)";
	
EndFunction

// Returns the literal of the XML node that contains the ORR constant value. 
//
// Returns: 
//  String.
//
Function FilterItemPropertyConstantValue() Export
	
	Return "ConstantValue";
	
EndFunction

// Returns the XML node literal that contains the value getting algorithm.
//
// Returns: 
//  String
//
Function FilterItemPropertyValueAlgorithm() Export
	
	Return "ValueAlgorithm";
	
EndFunction

// Returns the name of the file that is used for checking the transport data processor
// connection.
//
// Returns: 
//  String.
//
Function CheckConnectionFileName() Export
	
	Return NStr("en = 'ConnectionCheckFile'") + ".tmp";
	
EndFunction

Function InfoBaseOperationModeFile() Export
	
	Return 0;
	
EndFunction

Function InfoBaseOperationModeClientServer() Export
	
	Return 1;
	
EndFunction

Function IsErrorMessageNumberLessOrEqualToPreviouslyAcceptedMessageNumber(ErrorDescription)
	
	Return Find(Lower(ErrorDescription), Lower("Message number is less than or equal to")) > 0;
	
EndFunction

Function EventLogMessageTextEstablishingConnectionToWebService() Export
	
	Return NStr("en = 'Data exchange. Establishing connection to web service.'");
	
EndFunction

Function DataExchangeRuleLoadingEventLogMessageText() Export
	
	Return NStr("en = 'Data exchange. Importing rules.'");
	
EndFunction

Function DataExchangeCreationEventLogMessageText() Export
	
	Return NStr("en = 'Data exchange. Creating data exchange.'");
	
EndFunction
