////////////////////////////////////////////////////////////////////////////////
// Data exchange subsystem.
// 
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// INTERNAL INTERFACE

////////////////////////////////////////////////////////////////////////////////
// Object registration mechanism on exchange plan nodes (ORM).

// Retrieves the name of this infobase from the constant or from the configuration synonym.
// For internal use only.
//
Function ThisInfoBaseName() Export
	
	SetPrivilegedMode(True);
	
	Result = Constants.SystemTitle.Get();
	
	If IsBlankString(Result) Then
		
		Result = Metadata.Synonym;
		
	EndIf;
	
	Return Result;
EndFunction

// Retrieves the code of the predefined exchange plan node.
// 
// Parameters:
//  ExchangePlanName - String - exchange plan name as it is set in the designer.
// 
// Returns:
//  String - predefined exchange plan node code. 
//
Function GetThisNodeCodeForExchangePlan(ExchangePlanName) Export
	
	Return CommonUse.GetAttributeValue(GetThisExchangePlanNode(ExchangePlanName), "Code");
	
EndFunction

// Retrieves an array of names of configuration exchange plans that use the SL functionality.
// 
// Returns:
//  Array – array of configuration exchange plan names. 
//
Function SLExchangePlans() Export
	
	Return SLExchangePlanList().UnloadValues();
	
EndFunction

// Sets external connection with the infobase and returns a reference to this connection.
// For internal use only.
//
Function EstablishExternalConnection(ExternalConnectionParameters, ErrorMessageString = "") Export
	
	Return CommonUse.EstablishExternalConnection(ExternalConnectionParameters, ErrorMessageString);
	
EndFunction

// Retrieves the WSProxy object by connection settings.
// For internal use only.
//
Function GetWSProxy(ConnectionSettings, ErrorMessageString = "") Export
	
	Return DataExchangeServer.GetWSProxy(ConnectionSettings, ErrorMessageString);
	
EndFunction

// Returns a flag that shows whether the node is the predefined node of this infobase by the passed reference value.
// 
// Parameters:
//  ExchangePlanNode - ExchangePlanRef - any exchange plan node.
// 
// Returns:
//  Boolean - flag that shows whether the node is the predefined one.
//
Function IsPredefinedExchangePlanNode(ExchangePlanNode) Export
	
	If Not ValueIsFilled(ExchangePlanNode) Then
		Return False;
	EndIf;
	
	Return GetThisExchangePlanNodeByRef(ExchangePlanNode) = ExchangePlanNode;
	
EndFunction



Function FindExchangePlanNodeByCode(ExchangePlanName, NodeCode) Export
	
	QueryText =
	"SELECT
	|	ExchangePlan.Ref AS Ref
	|FROM
	|	ExchangePlan.[ExchangePlanName] AS ExchangePlan
	|WHERE
	|	ExchangePlan.Code = &Code";
	
	QueryText = StrReplace(QueryText, "[ExchangePlanName]", ExchangePlanName);
	
	Query = New Query;
	Query.SetParameter("Code", NodeCode);
	Query.Text = QueryText;
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		
		Return Undefined;
		
	EndIf;
	
	Selection = QueryResult.Choose();
	Selection.Next();
	
	Return Selection.Ref;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

////////////////////////////////////////////////////////////////////////////////
// Object registration mechanism on exchange plan nodes (ORM).

// Retrieves the object registration rule table for the exchange plan.
// 
// Parameters:
//  ExchangePlanName - String - exchange plan name as it is set in the designer
//                     whose registration rules will be retrieved.
// 
// Returns:
//  ValueTable - object registration rule table.
//
Function ExchangePlanObjectChangeRecordRules(Val ExchangePlanName) Export
	
	ObjectChangeRecordRules = DataExchangeServer.SessionParametersObjectChangeRecordRules().Get();
	
	Return ObjectChangeRecordRules.Copy(New Structure("ExchangePlanName", ExchangePlanName));
EndFunction

// Retrieves the object registration rule table for the specified exchange plan.
// 
// Parameters:
//  ExchangePlanName - String - exchange plan name as it is set in the designer.
//  FullObjectName   - String - full metadata object name whose registration rules will
//                     be retrieved.
//
// Returns:
//  ValueTable - object registration rule table.
//
Function ObjectChangeRecordRules(Val ExchangePlanName, Val FullObjectName) Export
	
	ExchangePlanObjectChangeRecordRules = DataExchangeEvents.ExchangePlanObjectChangeRecordRules(ExchangePlanName);
	
	Return ExchangePlanObjectChangeRecordRules.Copy(New Structure("MetadataObjectName", FullObjectName));
	
EndFunction

// Returns a flag that shows whether there are registration rules for the object by the
// specified exchange plan.
// 
// Parameters:
//  ExchangePlanName - String - exchange plan name as it is set in the designer.
//  FullObjectName   - String - full metadata object name whose registration rules will
//                              be checked.
// 
// Returns:
//  True if object registration rules exist, otherwise is False.
//
Function ObjectChangeRecordRulesExist(Val ExchangePlanName, Val FullObjectName) Export
	
	Return DataExchangeEvents.ObjectChangeRecordRules(ExchangePlanName, FullObjectName).Count() <> 0;
	
EndFunction

// Determines whether automatically registration is allowed.
//
// Parameters:
//  ExchangePlanName – String – name as it is set in the designer. The name of the 
//                              exchange plan that contains the metadata object.
//  FullObjectName   – String - full metadata object name whose automatically
//                              registration flag will be checked.
//
//  Returns:
//  Boolean.
//   True if metadata object auto registration is allowed in the exchange plan;
//   False if metadata object auto registration is denied in the exchange plan or the
//    exchange plan does not include the metadata object.
//
Function AutoChangeRecordAllowed(Val ExchangePlanName, Val FullObjectName) Export
	
	ExchangePlanContentItem = Metadata.ExchangePlans[ExchangePlanName].Content.Find(Metadata.FindByFullName(FullObjectName));
	
	If ExchangePlanContentItem = Undefined Then
		Return False; // The exchange plan does not include the metadata object
	EndIf;
	
	Return ExchangePlanContentItem.AutoRecord = AutoChangeRecord.Allow;
EndFunction

// Determines whether the exchange plan includes the metadata object.
// 
// Parameters:
//  ExchangePlanName – String – exchange plan name as it is set in the designer.
//  FullObjectName – String - full name of the metadata object to be checked.
// 
//  Returns:
//   Boolean - True if the exchange plan includes the metadata object, otherwise 
//             is False.
//
Function ExchangePlanContainsObject(Val ExchangePlanName, Val FullObjectName) Export
	
	ExchangePlanContentItem = Metadata.ExchangePlans[ExchangePlanName].Content.Find(Metadata.FindByFullName(FullObjectName));
	
	Return ExchangePlanContentItem <> Undefined;
EndFunction

// Determines whether the change registration must be performed according to registration rules.
//
// Parameters:
//  ExchangePlanName – String – exchange plan name as it is set in the designer.
//  FullObjectName   – String - full name of the metadata object whose registration rule
//                     usage will be checked.
// 
Function RecordChangesAccordingToObjectChangeRecordRules(Val ExchangePlanName, Val FullObjectName) Export
	
	If AutoChangeRecordAllowed(ExchangePlanName, FullObjectName) Then
		Return False;
	ElsIf Not ObjectChangeRecordRulesExist(ExchangePlanName, FullObjectName) Then
		Return False;
	EndIf;
	
	Return True;
EndFunction



// Retrieves the object registration attribute table for the selective object
// registration mechanism.
//
// Parameters:
//  ObjectName       - String - full metadata object name, for example, Catalog.Items;
//  ExchangePlanName - String - exchange plan name as it is set in the designer.
//
// Returns:
//  ChangeRecordAttributeTable - ValueTable - table of registration attributes ordered
//   by the Order field.
//
Function GetChangeRecordAttributeTable(ObjectName, ExchangePlanName) Export
	
	ObjectChangeRecordAttributeTable = DataExchangeServer.GetSelectiveObjectChangeRecordRulesSP();
	
	Filter = New Structure;
	Filter.Insert("ExchangePlanName", ExchangePlanName);
	Filter.Insert("ObjectName",       ObjectName);
	
	ChangeRecordAttributeTable = ObjectChangeRecordAttributeTable.Copy(Filter);
	
	ChangeRecordAttributeTable.Sort("Order Asc");
	
	Return ChangeRecordAttributeTable;
	
EndFunction

// Retrieves the table of selective object registration from session parameters.
// 
// Returns:
//  ValueTable - registration attribute table for all metadata objects.
//
Function GetSelectiveObjectChangeRecordRulesSP() Export
	
	SetPrivilegedMode(True);
	
	Return SessionParameters.SelectiveObjectChangeRecordRules.Get();
	
EndFunction

// Retrieves the predefined exchange plan node.
// 
// Parameters:
//  ExchangePlanName - String -  exchange plan name as it is set in the designer.
// 
// Returns:
//  ThisNode - ExchangePlanRef - predefined exchange plan node.
//
Function GetThisExchangePlanNode(ExchangePlanName) Export
	
	Return ExchangePlans[ExchangePlanName].ThisNode()
	
EndFunction

// Retrieves the predefined exchange plan node by the reference.
// 
// Parameters:
//  ExchangePlanNode - ExchangePlanRef - any exchange plan node.
// 
// Returns:
//  ThisNode - ExchangePlanRef - predefined exchange plan node.
//
Function GetThisExchangePlanNodeByRef(ExchangePlanNode) Export
	
	Return GetThisExchangePlanNode(GetExchangePlanName(ExchangePlanNode));
	
EndFunction

// Determines whether the node belongs to the DIB exchange plan.
// 
// Parameters:
//  InfoBaseNode – ExchangePlanRef – exchange plan node to be checked.
// 
// Returns:
//  Boolean - True if the node belongs to the DIB exchange plan, otherwise is False.
//
Function IsDistributedInfoBaseNode(InfoBaseNode) Export
	
	Return InfoBaseNode.Metadata().DistributedInfoBase;
	
EndFunction

// Determines whether the node belongs to the standard exchange plan (without conversion rules).
// 
// Parameters:
//  InfoBaseNode – ExchangePlanRef – exchange plan node to be checked.
// 
// Returns:
//  Boolean - True if the node belongs to the standard exchange plan, otherwise is False.
//
Function IsStandardDataExchangeNode(InfoBaseNode) Export
	
	Return Not IsDistributedInfoBaseNode(InfoBaseNode)
		  And Not HasExchangePlanTemplate(GetExchangePlanName(InfoBaseNode), "ExchangeRules");
	
EndFunction

// Determines whether the node belongs to the universal exchange plan (with conversion rules).
// 
// Parameters:
//  InfoBaseNode – ExchangePlanRef – exchange plan node to be checked.
// 
// Returns:
//  Boolean - True if the node belongs to the universal exchange plan, otherwise is False.
//
Function IsUniversalDataExchangeNode(InfoBaseNode) Export
	
	Return Not IsDistributedInfoBaseNode(InfoBaseNode)
		And HasExchangePlanTemplate(GetExchangePlanName(InfoBaseNode), "ExchangeRules");
	
EndFunction

// Determines whether the node belongs to the exchange plan that uses SL exchange functionality.
// 
// Parameters:
//  InfoBaseNode – ExchangePlanRef, ExchangePlanObject – exchange plan node to be checked.
// 
// Returns:
//  Boolean - True if the node belongs to the exchange plan that uses SL exchange
//   functionality, otherwise is False.
//
Function IsSLDataExchangeNode(InfoBaseNode) Export
	
	Return SLExchangePlans().Find(GetExchangePlanName(InfoBaseNode)) <> Undefined;
	
EndFunction

// Determines whether the node belongs to the separated exchange plan that uses SL
// exchange functionality.
// 
// Parameters:
//  InfoBaseNode – ExchangePlanRef – exchange plan node to be checked.
// 
// Returns:
//  Boolean - True if the node belongs to the separated exchange plan that uses SL 
//   exchange functionality, otherwise is False.
//
Function IsSeparatedSLDataExchangeNode(InfoBaseNode) Export
	
	Return SeparatedSLExchangePlans().Find(GetExchangePlanName(InfoBaseNode)) <> Undefined;
	
EndFunction

// Determines whether the exchange plan belongs to the DIB exchange plan.
// 
// Parameters:
//  ExchangePlanName - String - exchange plan name as it is set in the designer.
// 
// Returns:
//  Boolean True – exchange plan belongs to the DIB exchange plan, otherwise is False.
//
Function IsDistributedInfoBaseExchangePlan(ExchangePlanName) Export
	
	Return Metadata.ExchangePlans[ExchangePlanName].DistributedInfoBase;
	
EndFunction

// Retrieves the exchange plan name as the metadata object for the specified node.
// 
// Parameters:
//  ExchangePlanNode - ExchangePlanRef, ExchangePlanObject - exchange plan node.
// 
// Returns:
//  Name - String - name of the exchange plan as the metadata object.
//
Function GetExchangePlanName(ExchangePlanNode) Export
	
	Return ExchangePlanNode.Metadata().Name;
	
EndFunction

// Retrieves an array of all nodes except the predefined one for the specified exchange plan.
// 
// Parameters:
//  ExchangePlanName - String - exchange plan name as it is set in the designer.
// 
// Returns:
//  NodeArray - Array - array of all nodes except the predefined one for the specified
//   exchange plan.
//
Function GetExchangePlanNodeArray(ExchangePlanName) Export
	
	ThisNode = ExchangePlans[ExchangePlanName].ThisNode();
	
	QueryText = "
	|SELECT
	| ExchangePlan.Ref
	|FROM ExchangePlan." + ExchangePlanName + " AS ExchangePlan
	|WHERE
	|	ExchangePlan.Ref <> &ThisNode";
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("ThisNode", ThisNode);
	
	Return Query.Execute().Unload().UnloadColumn("Ref");
	
EndFunction

// Retrieves a list filled with templates of standard exchange rules from configuration 
// for the specified exchange plan. The list is filled with names and synonyms of rule 
// templates.
// 
// Parameters:
//  ExchangePlanName - String - exchange plan name as it is set in the designer.
// 
// Returns:
//  RuleList - ValueList - list filled with templates of standard exchange rules.
//
Function GetStandardExchangeRuleList(ExchangePlanName) Export
	
	Return GetStandardRuleList(ExchangePlanName, "ExchangeRules");
	
EndFunction

// Retrieves a list filled with templates of standard registration rules from
// configuration for the specified exchange plan. The list is filled with names and 
// synonyms of rule templates.
// 
// Parameters:
//  ExchangePlanName - String - exchange plan name as it is set in the designer.
// 
// Returns:
//  RuleList - RoleList values - list filled with templates of standard registration rules.
//
Function GetStandardChangeRecordRuleList(ExchangePlanName) Export
	
	Return GetStandardRuleList(ExchangePlanName, "RecordRules");
	
EndFunction

// Retrieves a list of configuration exchange plans that use the SL functionality.
// The list is filled with names and synonyms of exchange plans.
// 
// Returns:
//  ExchangePlanList - RoleList values - list of configuration exchange plans.
//
Function SLExchangePlanList() Export
	
	// Return value
	ExchangePlanList = New ValueList;
	
	SubsystemExchangePlans = New Array;
	
	DataExchangeOverridable.GetExchangePlans(SubsystemExchangePlans);
	
	For Each ExchangePlan In SubsystemExchangePlans Do
		
		ExchangePlanList.Add(ExchangePlan.Name, ExchangePlan.Synonym);
		
	EndDo;
	
	Return ExchangePlanList;
EndFunction

// Retrieves an array of separated configuration exchange plan names that use the SL functionality.
//
// Returns:
//  Array – array of separated configuration exchange plan names.
//
Function SeparatedSLExchangePlans() Export
	
	Result = New Array;
	
	SLExchangePlanArray = SLExchangePlans();
	
	For Each ExchangePlanName In SLExchangePlanArray Do
		
		If CommonUseCached.IsSeparatedMetadataObject("ExchangePlan." + ExchangePlanName) Then
			
			Result.Add(ExchangePlanName);
			
		EndIf;
		
	EndDo;
	
	Return Result;
EndFunction

Function CommonNodeData(Val InfoBaseNode) Export
	
	If TypeOf(InfoBaseNode) <> Type("String") Then
		
		ExchangePlanName = GetExchangePlanName(InfoBaseNode);
		
	Else
		
		ExchangePlanName = InfoBaseNode;
		
	EndIf;
	
	Result = "";
	
	Try
		Result = ExchangePlans[ExchangePlanName].CommonNodeData();
		Result = StrReplace(Result, "", "");
	Except
	EndTry;
	
	Return Result;
EndFunction

Function ExchangePlanTabularSections(Val ExchangePlanName) Export
	
	CommonTables           = New Array;
	ThisInfoBaseTables     = New Array;
	CorrespondentTables    = New Array;
	AllInfoBaseTables      = New Array; //All tables of the current infobase
	AllCorrespondentTables = New Array;
	
	CommonNodeData = "";
	
	Try
		CommonNodeData = ExchangePlans[ExchangePlanName].CommonNodeData();
		CommonNodeData = StrReplace(CommonNodeData, "", "");
	Except
		CommonNodeData = "";
	EndTry;
	
	TabularSections = ObjectTabularSections(Metadata.ExchangePlans[ExchangePlanName]);
	
	If Not IsBlankString(CommonNodeData) Then
		
		For Each TabularSection In TabularSections Do
			
			If Find(CommonNodeData, TabularSection) <> 0 Then
				
				CommonTables.Add(TabularSection);
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	ThisInfoBaseSettings = ExchangePlans[ExchangePlanName].NodeFilterStructure();
	
	ThisInfoBaseSettings = DataExchangeEvents.StructureKeysToString(ThisInfoBaseSettings);
	
	If IsBlankString(CommonNodeData) Then
		
		For Each TabularSection In TabularSections Do
			
			If Find(ThisInfoBaseSettings, TabularSection) <> 0 Then
				
				ThisInfoBaseTables.Add(TabularSection);
				
				AllInfoBaseTables.Add(TabularSection);
				
			EndIf;
			
		EndDo;
		
	Else
		
		For Each TabularSection In TabularSections Do
			
			If Find(ThisInfoBaseSettings, TabularSection) <> 0 Then
				
				AllInfoBaseTables.Add(TabularSection);
				
				If Find(CommonNodeData, TabularSection) = 0 Then
					
					ThisInfoBaseTables.Add(TabularSection);
					
				EndIf;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	CorrespondentSettings = ExchangePlans[ExchangePlanName].CorrespondentInfoBaseNodeFilterSetup();
	
	If IsBlankString(CommonNodeData) Then
		
		For Each CorrespondentSetting In CorrespondentSettings Do
			
			If TypeOf(CorrespondentSetting.Value) = Type("Structure") Then
				
				CorrespondentTables.Add(TabularSection);
				
				AllCorrespondentTables.Add(TabularSection);
				
			EndIf;
			
		EndDo;
		
	Else
		
		For Each CorrespondentSetting In CorrespondentSettings Do
			
			If TypeOf(CorrespondentSetting.Value) = Type("Structure") Then
				
				AllCorrespondentTables.Add(TabularSection);
				
				If Find(CommonNodeData, CorrespondentSetting.Key) = 0 Then
					
					CorrespondentTables.Add(TabularSection);
					
				EndIf;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	Result = New Structure;
	Result.Insert("CommonTables",           CommonTables);
	Result.Insert("ThisInfoBaseTables",     ThisInfoBaseTables);
	Result.Insert("CorrespondentTables",    CorrespondentTables);
	Result.Insert("AllInfoBaseTables",      AllInfoBaseTables);
	Result.Insert("AllCorrespondentTables", AllCorrespondentTables);
	
	Return Result;
EndFunction

// Retrieves the exchange plan manager by the exchange plan name.
//
// Parameters:
//  ExchangePlanName - String - exchange plan name as it is set in the designer.
//
// Returns:
//  ExchangePlanManager - exchange plan manager.
//
Function GetExchangePlanManagerByName(ExchangePlanName) Export
	
	Result = Undefined;
	
	Try
		
		Result = ExchangePlans[ExchangePlanName];
		
	Except
		Return Undefined;
	EndTry;
	
	Return Result;
EndFunction

// Retrieves the exchange plan manager by the exchange plan metadata object name.
//
// Parameters:
//  ExchangePlanNode – ExchangePlanRef – exchange plan node whose manager will be retrieved.
// 
Function GetExchangePlanManager(ExchangePlanNode) Export
	
	Return GetExchangePlanManagerByName(GetExchangePlanName(ExchangePlanNode));
	
EndFunction

// Calls the same name function from the common module.
//
Function GetConfigurationMetadataTree(Filter) Export
	
	For Each FilterItem In Filter Do
		
		Filter[FilterItem.Key] = StringFunctionsClientServer.SplitStringIntoSubstringArray(FilterItem.Value);
		
	EndDo;
	
	Return CommonUse.GetConfigurationMetadataTree(Filter);
	
EndFunction

// Returns initialized InfoBaseObjectConversion data processor for performing data import.
// The data processor is saved in the platform cache to be used repeatedly for the
// specified exchange plan node and the specified exchange massage file with the 
// unique full name.
// 
// Parameters:
//  InfoBaseNode            – ExchangePlanRef – exchange plan node.
//  ExchangeMessageFileName - String - unique exchange massage file name for importing data.
// 
// Returns:
//  DataProcessorObject.InfoBaseObjectConversion - initialized data processor for
//   performing data import.
//
Function DataImportDataProcessor(Cancel, InfoBaseNode, Val ExchangeMessageFileName) Export
	
	// INITIALIZING THE DATA PROCESSOR FOR IMPORTING DATA
	DataExchangeDataProcessor = DataProcessors.InfoBaseObjectConversion.Create();
	
	DataExchangeDataProcessor.ExchangeMode = "Import";
	
	DataExchangeDataProcessor.OutputInfoMessagesToMessageWindow = False;
	DataExchangeDataProcessor.WriteInfoMessagesToLog = False;
	DataExchangeDataProcessor.AppendDataToExchangeLog = False;
	DataExchangeDataProcessor.ExportAllowedOnly = False;
	DataExchangeDataProcessor.DebugModeFlag = False;
	
	DataExchangeDataProcessor.ExchangeLogFileName = "";
	
	DataExchangeDataProcessor.EventLogMessageKey = DataExchangeServer.GetEventLogMessageKey(InfoBaseNode, Enums.ActionsOnExchange.DataImport);
	
	DataExchangeDataProcessor.ExchangeNodeDataImport = InfoBaseNode;
	DataExchangeDataProcessor.ExchangeFileName       = ExchangeMessageFileName;
	
	DataExchangeDataProcessor.ObjectCountPerTransaction = InformationRegisters.ExchangeTransportSettings.DataImportTransactionItemCount(InfoBaseNode);
	
	Return DataExchangeDataProcessor;
	
EndFunction

// Determines whether the exchange plan has the template.
// 
// Parameters:
//  ExchangePlanName - String - exchange plan name as it is set in the designer.
//  TemplateName – String – name of the template to be checked.
// 
// Returns:
//  Boolean. True if the exchange plan contains the specified template, otherwise is False.
//
Function HasExchangePlanTemplate(Val ExchangePlanName, Val TemplateName) Export
	
	Return Metadata.ExchangePlans[ExchangePlanName].Templates.Find(TemplateName) <> Undefined;
	
EndFunction

// Calls the same name function from the DataExchangeServer module.
//
Function NodeArrayByPropertyValues(PropertyValues, QueryText, ExchangePlanName, FlagAttributeName) Export
	
	Return DataExchangeServer.NodeArrayByPropertyValues(PropertyValues, QueryText, ExchangePlanName, FlagAttributeName);
	
EndFunction

// Returns a collection of exchange message transport that can be used for the specified
// exchange plan node.
// 
// Parameters:
//  InfoBaseNode – ExchangePlanRef – exchange plan node.
// 
// Returns:
//  Array - message transports that can be used for the specified exchange plan node.
//
Function UsedExchangeMessageTransports(InfoBaseNode) Export
	
	Result = ExchangePlans[GetExchangePlanName(InfoBaseNode)].UsedExchangeMessageTransports();
	
	// Exchange via a COM connection or via a web service is not supported for base
	// configuration versions.
	If StandardSubsystemsOverridable.IsBaseConfigurationVersion() Then
		
		CommonUseClientServer.DeleteValueFromArray(Result, Enums.ExchangeMessageTransportKinds.COM);
		CommonUseClientServer.DeleteValueFromArray(Result, Enums.ExchangeMessageTransportKinds.WS);
		
	EndIf;
		
	// Exchange via a COM connection is not supported for the DIB exchange.
	If IsDistributedInfoBaseNode(InfoBaseNode) Then
		
		CommonUseClientServer.DeleteValueFromArray(Result, Enums.ExchangeMessageTransportKinds.COM);
		
	EndIf;
	
	// Exchange via a COM connection is not supported for the standard exchange (without
	// conversion rules).
	If IsStandardDataExchangeNode(InfoBaseNode) Then
		
		CommonUseClientServer.DeleteValueFromArray(Result, Enums.ExchangeMessageTransportKinds.COM);
		
	EndIf;
	
	Return Result;
EndFunction

// Establishes an external connection with the infobase and returns its reference.
// 
// Parameters:
//  InfoBaseNode       - ExchangePlanRef - mandatory. The exchange plan node whose  
//                       external connection will be established.
//  ErrorMessageString – String – optional. If an error occurs when establishing
//                       an external connection, the error message text is returned to
//                       this parameter.
//
// Returns:
//  COM object - if the external connection was established successfully;
//  Undefined  - if the external connection was not established.
//
Function GetExternalConnectionForInfoBaseNode(InfoBaseNode, ErrorMessageString = "") Export
	
	SettingsStructure = InformationRegisters.ExchangeTransportSettings.GetNodeTransportSettings(InfoBaseNode, Enums.ExchangeMessageTransportKinds.COM);
	
	Return DataExchangeServer.EstablishExternalConnection(SettingsStructure, ErrorMessageString);
	
EndFunction

// Retrieves the WSProxy object by connection settings for the 2.0.1.6 version.
// For internal use only.
//
Function GetWSProxy_2_0_1_6(ConnectionSettings, ErrorMessageString = "") Export
	
	Return DataExchangeServer.GetWSProxy_2_0_1_6(ConnectionSettings, ErrorMessageString);
	
EndFunction

// Retrieves the WSProxy object by connection settings specified for the exchange plan node.
// For internal use only.
//
Function GetWSProxyForInfoBaseNode(InfoBaseNode, ErrorMessageString = "") Export
	
	SettingsStructure = InformationRegisters.ExchangeTransportSettings.GetWSTransportSettings(InfoBaseNode);
	
	Return DataExchangeServer.GetWSProxy(SettingsStructure, ErrorMessageString);
	
EndFunction

Function IsExchangeInSameLAN(Val InfoBaseNode) Export
	
	Return DataExchangeServer.IsExchangeInSameLAN(InfoBaseNode);
	
EndFunction

// For internal use only.
//
Function GetHierarchicalCatalogItemsHierarchyFoldersAndItems(FullTableName) Export
	
	QueryText = "
	|SELECT TOP 2000
	|	Ref,
	|	Presentation,
	|	IsFolder,
	|	CASE
	|		WHEN     IsFolder AND Not DeletionMark THEN 0
	|		WHEN     IsFolder AND     DeletionMark THEN 1
	|		WHEN Not IsFolder AND Not DeletionMark THEN 2
	|		WHEN Not IsFolder AND     DeletionMark THEN 3
	|	END AS PictureIndex
	|FROM
	|	[FullTableName]
	|ORDER BY
	|	IsFolder HIERARCHY,
	|	Description
	|";
	
	QueryText = StrReplace(QueryText, "[FullTableName]", FullTableName);
	
	Query = New Query;
	Query.Text = QueryText;
	
	Table = Query.Execute().Unload(QueryResultIteration.ByGroupsWithHierarchy);
	Table.Columns.Add("ID", New TypeDescription("String"));
	
	Table.Columns.Delete("Ref");
	Table.Columns.Delete("IsFolder");
	
	Return CommonUse.ValueToXMLString(Table);
EndFunction

// For internal use only.
//
Function GetHierarchicalCatalogItemsHierarchyOfItems(FullTableName) Export
	
	QueryText = "
	|SELECT TOP 2000
	|	Ref,
	|	Presentation,
	|	FALSE AS IsFolder,
	|	CASE
	|		WHEN DeletionMark THEN 3
	|		ELSE 2
	|	END AS PictureIndex
	|FROM
	|	[FullTableName]
	|ORDER BY
	|	Description HIERARCHY
	|";
	
	QueryText = StrReplace(QueryText, "[FullTableName]", FullTableName);
	
	Query = New Query;
	Query.Text = QueryText;
	
	Table = Query.Execute().Unload(QueryResultIteration.ByGroupsWithHierarchy);
	Table.Columns.Add("ID", New TypeDescription("String"));
	
	FillObjectTreeFieldValues(Table.Rows);
	
	Table.Columns.Delete("Ref");
	Table.Columns.Delete("IsFolder");
	
	Return CommonUse.ValueToXMLString(Table);
EndFunction

// For internal use only.
//
Function GetNonHierarchicalCatalogItems(FullTableName) Export
	
	QueryText = "
	|SELECT TOP 2000
	|	Ref,
	|	Presentation,
	|	FALSE AS IsFolder,
	|	CASE
	|		WHEN DeletionMark THEN 3
	|		ELSE 2
	|	END AS PictureIndex
	|FROM
	|	[FullTableName]
	|ORDER BY
	|	Description
	|";
	
	QueryText = StrReplace(QueryText, "[FullTableName]", FullTableName);
	
	Query = New Query;
	Query.Text = QueryText;
	
	Table = Query.Execute().Unload(QueryResultIteration.ByGroupsWithHierarchy);
	Table.Columns.Add("ID", New TypeDescription("String"));
	
	FillObjectTreeFieldValues(Table.Rows);
	
	Table.Columns.Delete("Ref");
	Table.Columns.Delete("IsFolder");
	
	Return CommonUse.ValueToXMLString(Table);
EndFunction

// For internal use only.
//
Procedure FillObjectTreeFieldValues(Tree)
	
	For Each TreeRow In Tree Do
		
		TreeRow.ID = ValueToStringInternal(TreeRow.Ref);
		
		If TreeRow.IsFolder Then
			
			FillObjectTreeFieldValues(TreeRow.Rows);
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Determines whether the exchange plan can be used by the configuration functional 
// option composition.
// If no one functional option includes the exchange plan, the function returns True.
// If functional options include the exchange plan and one or more functional options
// are enabled, the function returns True.
// Otherwise, the function returns False.
//
// Parameters:
//  ExchangePlanName – String - name of the exchange plan to be checked.
//
// Returns:
//  Boolean - True if the exchange plan can be used, otherwise is False.
//
Function CanUseExchangePlan(Val ExchangePlanName) Export
	
	ObjectIsInFunctionalOptionContent = False;
	
	For Each FunctionalOption In Metadata.FunctionalOptions Do
		
		If FunctionalOption.Content.Contains(Metadata.ExchangePlans[ExchangePlanName]) Then
			
			ObjectIsInFunctionalOptionContent = True;
			
			If GetFunctionalOption(FunctionalOption.Name) = True Then
				
				Return True;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	If Not ObjectIsInFunctionalOptionContent Then
		
		Return True;
		
	EndIf;
	
	Return False;
EndFunction

// Returns an array of version numbers supported by correspondent API for the
// DataExchange subsystem.
//
// Parameters:
//  Correspondent – Structure or ExchangePlanRef - exchange plan note that matches the 
//                  correspondent infobase.
//
// Returns:
//  Array of version numbers that are supported by correspondent API.
//
Function CorrespondentVersions(Val Correspondent) Export
	
	If TypeOf(Correspondent) = Type("Structure") Then
		SettingsStructure = Correspondent;
	Else
		SettingsStructure = InformationRegisters.ExchangeTransportSettings.GetWSTransportSettings(Correspondent);
	EndIf;
	
	ConnectionParameters = New Structure;
	ConnectionParameters.Insert("URL",      SettingsStructure.WSURL);
	ConnectionParameters.Insert("UserName", SettingsStructure.WSUserName);
	ConnectionParameters.Insert("Password", SettingsStructure.WSPassword);
	
	Return CommonUse.GetInterfaceVersions(ConnectionParameters, "DataExchange");
EndFunction

// Returns an array of all reference types defined in the configuration.
//
Function AllConfigurationReferenceTypes() Export
	
	Result = New Array;
	
	CommonUseClientServer.SupplementArray(Result, Catalogs.AllRefsType().Types());
	CommonUseClientServer.SupplementArray(Result, Documents.AllRefsType().Types());
	CommonUseClientServer.SupplementArray(Result, BusinessProcesses.AllRefsType().Types());
	CommonUseClientServer.SupplementArray(Result, ChartsOfCharacteristicTypes.AllRefsType().Types());
	CommonUseClientServer.SupplementArray(Result, ChartsOfAccounts.AllRefsType().Types());
	CommonUseClientServer.SupplementArray(Result, ChartsOfCalculationTypes.AllRefsType().Types());
	CommonUseClientServer.SupplementArray(Result, Tasks.AllRefsType().Types());
	CommonUseClientServer.SupplementArray(Result, ExchangePlans.AllRefsType().Types());
	CommonUseClientServer.SupplementArray(Result, Enums.AllRefsType().Types());
	
	Return Result;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Initializing the data exchange settings structure. 

// Initializes the data exchange subsystem for performing the exchange.
// 
// Returns:
//  ExchangeSettingsStructure - Structure - structure with all required for exchange 
//  data and objects.
//
Function GetExchangeSettingStructureForInfoBaseNode(InfoBaseNode,
	ActionOnExchange,
	ExchangeMessageTransportKind,
	UseTransportSettings = True) Export
	
	Return DataExchangeServer.GetExchangeSettingStructureForInfoBaseNode(
		InfoBaseNode,
		ActionOnExchange,
		ExchangeMessageTransportKind,
		UseTransportSettings
	);
	
EndFunction

// Initializes the data exchange subsystem for performing the exchange.

// 
// Returns:
//  ExchangeSettingsStructure - Structure - structure with all required for exchange 
//  data and objects.
//
Function GetExchangeSettingsStructure(ExchangeExecutionSettings, LineNumber) Export
	
	Return DataExchangeServer.GetExchangeSettingsStructure(ExchangeExecutionSettings, LineNumber);
	
EndFunction

// Retrieves a transport settings structure for performing the data exchange.
//
Function GetTransportSettingsStructure(InfoBaseNode, ExchangeMessageTransportKind) Export
	
	Return DataExchangeServer.GetTransportSettingsStructure(InfoBaseNode, ExchangeMessageTransportKind);
	
EndFunction

// Retrieves a list filled with templates of standard exchange rules from configuration 
// for the specified exchange plan. The list is filled with names and synonyms of rule 
// templates.
// 
// Parameters:
//  ExchangePlanName - String - exchange plan name as it is set in the designer.
// 
// Returns:
//  RuleList - ValueList - list filled with templates of standard exchange rules.
//
Function GetStandardRuleList(ExchangePlanName, TemplateNameLiteral)
	
	RuleList = New ValueList;
	
	If IsBlankString(ExchangePlanName) Then
		Return RuleList;
	EndIf;
	
	Try
		
		ExchangePlanTemplates = Metadata.ExchangePlans[ExchangePlanName].Templates;
		
	Except
		Return RuleList;
	EndTry;
	
	For Each Template In ExchangePlanTemplates Do
		
		TemplateName = Template.Name;
		
		If Find(TemplateName, TemplateNameLiteral) <> 0 Then
			
			RuleList.Add(TemplateName, Template.Synonym);
			
		EndIf;
		
	EndDo;
	
	Return RuleList;
EndFunction

Function TempFileStorageDirectory() Export
	
	// Return value
	Result = "";
	
	SystemInfo = New SystemInfo;
	
	If    SystemInfo.PlatformType = PlatformType.Windows_x86
		Or SystemInfo.PlatformType = PlatformType.Windows_x86_64 Then
		
		Result = Constants.ExchangeMessageTempFileDirForWindows.Get();
		
	ElsIf SystemInfo.PlatformType = PlatformType.Linux_x86
		Or   SystemInfo.PlatformType = PlatformType.Linux_x86_64 Then
		
		Result = Constants.ExchangeMessageTempFileDirForLinux.Get();
		
	Else
		
		Result = Constants.ExchangeMessageTempFileDirForWindows.Get();
		
	EndIf;
	
	If IsBlankString(Result) Then
		Result = TrimAll(TempFilesDir());
	Else
		Result = TrimAll(Result);
		
		// Checking whether the directory exists
		Directory = New File(Result);
		
		If Not Directory.Exist() Then
			
			MessageString = NStr("en = 'The temporary file directory for the exchange messages does not exist: %1'");
			MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, Result);
			Raise MessageString;
		EndIf;
		
	EndIf;
	
	Return Result;
EndFunction

Function ObjectTabularSections(MetadataObject) Export
	
	Result = New Array;
	
	For Each TabularSection In MetadataObject.TabularSections Do
		
		Result.Add(TabularSection.Name);
		
	EndDo;
	
	Return Result;
EndFunction
