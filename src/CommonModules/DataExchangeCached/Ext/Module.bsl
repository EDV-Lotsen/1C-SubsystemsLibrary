////////////////////////////////////////////////////////////////////////////////
// Data exchange subsystem
// 
////////////////////////////////////////////////////////////////////////////////

#Region InternalInterface

////////////////////////////////////////////////////////////////////////////////
// Object registration mechanism on exchange plan nodes (ORM).

// Retrieves the name of this infobase from the constant or from the configuration synonym.
// For internal use only.
//
Function ThisInfobaseName() Export
	
	SetPrivilegedMode(True);
	
	Result = Constants.SystemTitle.Get();
	
	If IsBlankString(Result) Then
		
		Result = Metadata.Synonym;
		
	EndIf;
	
	Return Result;
EndFunction

// Gets a code of a predefined exchange plan node.
// 
// Parameters:
//  ExchangePlanName - String - plan name as it is set in Designer mode.
// 
// Returns:
//  String - predefined exchange node code.
//
Function GetThisNodeCodeForExchangePlan(ExchangePlanName) Export
	
	Return CommonUse.ObjectAttributeValue(GetThisExchangePlanNode(ExchangePlanName), "Code");
	
EndFunction

// Gets the description of a predefined exchange plan node.
// 
// Parameters:
//  InfobaseNode - ExchangePlanRef - exchange plan node.
// 
// Returns:
//  String - description of the predefined exchange plan node.
//
Function ThisNodeDescription(Val InfobaseNode) Export
	
	Return CommonUse.ObjectAttributeValue(GetThisExchangePlanNode(GetExchangePlanName(InfobaseNode)), "Description");
	
EndFunction

// Retrieves an array of names of configuration exchange plans that use the SL functionality.
//
// Returns:
// Array - array of configuration exchange plan names.
//
Function SLExchangePlans() Export
	
	Return SLExchangePlanList().UnloadValues();
	
EndFunction

// Establishes an external connection to an infobase and returns a description of this connection.
// For internal use only.
//
// Parameters:
//    Parameters - Structure - see the description of the external connection 
//                             parameters in the CommonUse.EstablishExternalConnectionWithInfobase function.
//
Function EstablishExternalConnectionWithInfobase(Parameters) Export
	
	// Converting external connection parameters to transport parameters
	TransportSettings = DataExchangeServer.TransportSettingsByExternalConnectionParameters(Parameters);
	Return DataExchangeServer.EstablishExternalConnectionWithInfobase(TransportSettings);
EndFunction

// Returns a flag that shows whether the node is the predefined node of this infobase 
// by the passed reference value.
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

// Determines whether an exchange plan specified by name is used in SaaS mode.
// For this purpose all exchange plans have the ExchangePlanUsedInSaaS() function, 
// which returns True or False, in their manager modules.
//
// Parameters:
// ExchangePlanName - String.
//
// Returns:
// Boolean.
//
Function ExchangePlanUsedInSaaS(Val ExchangePlanName) Export
	
	Result = False;
	
	If SLExchangePlans().Find(ExchangePlanName) <> Undefined Then
		
		Result = ExchangePlans[ExchangePlanName].ExchangePlanUsedInSaaS();
		
	EndIf;
	
	Return Result;
EndFunction
 

// For internal use.
//
Function StandaloneModeSupported() Export
	
	Return StandaloneModeExchangePlans().Count() = 1;
	
EndFunction

// For internal use.
//
Function StandaloneModeExchangePlan() Export
	
	Result = StandaloneModeExchangePlans();
	
	If Result.Count() = 0 Then
		
		Raise NStr("en = 'Standalone mode is not supported.'");
		
	ElsIf Result.Count() > 1 Then
		
		Raise NStr("en = 'Multiple exchange plans are created for the standalone mode.'");
		
	EndIf;
	
	Return Result[0];
EndFunction

// For internal use.
//
Function IsStandaloneWorkstation() Export
	
	If Constants.SubordinateDIBNodeSetupCompleted.Get() Then
		
		Return Constants.IsStandaloneWorkstation.Get();
		
	Else
		
		Return DataExchangeServer.MasterNode() <> Undefined
			And DataExchangeCached.StandaloneModeSupported()
			And DataExchangeServer.MasterNode().Metadata().Name = DataExchangeCached.StandaloneModeExchangePlan();
		
	EndIf;
	
EndFunction

// Determines whether the passed exchange plan node is a standalone workstation.
//
Function IsStandaloneWorkstationNode(Val InfobaseNode) Export
	
	Return DataExchangeCached.StandaloneModeSupported()
		And InfobaseNode.Metadata().Name = DataExchangeCached.StandaloneModeExchangePlan();
EndFunction

// For internal use.
//
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
	
	Selection = QueryResult.Select();
	Selection.Next();
	
	Return Selection.Ref;
EndFunction

#EndRegion

#Region InternalProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Object registration mechanism on exchange plan nodes (ORM).

// Retrieves the object registration rule table for the exchange plan.
// 
// Parameters:
//  ExchangePlanName - String - the exchange plan name as it
//                     is set in Designer mode whose registration 
//                     rules will be retrieved.
// 
// Returns:
// Value table - object registration rule table.
//
Function ExchangePlanObjectChangeRecordRules(Val ExchangePlanName) Export
	
	ObjectChangeRecordRules = DataExchangeServerCall.SessionParametersObjectChangeRecordRules().Get();
	
	Return ObjectChangeRecordRules.Copy(New Structure("ExchangePlanName", ExchangePlanName));
EndFunction

// Retrieves the object registration rule table for the specified exchange plan.
// 
// Parameters:
//  ExchangePlanName - String - the exchange plan name as it is set in Designer mode.
//  FullObjectName   - String - full metadata object name whose registration rules 
//                     will be retrieved.      
// 
// Returns:
// Value table - object registration rule table.
//
Function ObjectChangeRecordRules(Val ExchangePlanName, Val FullObjectName) Export
	
	ExchangePlanObjectChangeRecordRules = DataExchangeEvents.ExchangePlanObjectChangeRecordRules(ExchangePlanName);
	
	Return ExchangePlanObjectChangeRecordRules.Copy(New Structure("MetadataObjectName", FullObjectName));
	
EndFunction

// Returns a flag that shows whether there are registration rules for the object by the specified exchange plan.
// 
// Parameters:
//  ExchangePlanName - String - the exchange plan name as it is set in Designer mode.
//  FullObjectName   - String - full metadata  object name whose registration rules will be checked.
// 
//  Returns:
//   True if object registration rules exist, False otherwise
//
Function ObjectChangeRecordRulesExist(Val ExchangePlanName, Val FullObjectName) Export
	
	Return DataExchangeEvents.ObjectChangeRecordRules(ExchangePlanName, FullObjectName).Count() <> 0;
	
EndFunction

// Determines whether automatic registration is allowed.
//
// Parameters:
//  ExchangePlanName – String – name as it is set in Designer mode. The name of the 
//                              exchange plan that contains the metadata object.
//  FullObjectName   – String - full metadata object name whose automatic
//                              registration flag will be checked.
//
//  Returns:
//  Boolean.
//   True if metadata object auto registration is allowed in the exchange plan.
//   False if metadata object auto registration is denied in the exchange plan or the
//   exchange plan does not include the metadata object.

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
//  ExchangePlanName – String – exchange plan name as it is set in Designer mode.
//  FullObjectName   – String - full name of the metadata object to be checked.

// 
//  Returns:
//   True if the exchange plan includes the metadata object, False otherwise.
//
Function ExchangePlanContainsObject(Val ExchangePlanName, Val FullObjectName) Export
	
	ExchangePlanContentItem = Metadata.ExchangePlans[ExchangePlanName].Content.Find(Metadata.FindByFullName(FullObjectName));
	
	Return ExchangePlanContentItem <> Undefined;
EndFunction

// Returns a flag that shows whether an exchange plan is used in data exchange.
// If an exchange plan contains at least one node that is not a predefined one, it is 
// considered used in data exchange.
//
// Parameters:
//  ExchangePlanName - String - exchange plan name as it is set in Designer.
//
// Returns:
//  True if the exchange plan is used, False otherwise
//
Function DataExchangeEnabled(Val ExchangePlanName, Val Sender) Export
	
	QueryText = "SELECT TOP 1 1
	|FROM
	|	ExchangePlan." + ExchangePlanName + " AS
	|ExchangePlan
	|WHERE ExchangePlan.Ref
	|	<> &ThisNode AND ExchangePlan.Ref <> &Sender";
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("ThisNode", ExchangePlans[ExchangePlanName].ThisNode());
	Query.SetParameter("Sender", Sender);
	
	Return Not Query.Execute().IsEmpty();
	
EndFunction

// Returns the list of exchange plans that contain at least one exchange node (other than ThisNode).
//
Function UsedExchangePlans() Export
	
	Return DataExchangeServer.GetUsedExchangePlans();
	
EndFunction

// Returns the exchange plan content that is specified by the user.
// Exchange plan user content is determined by the object registration rules
// and node settings that are set by the user.
//
// Parameters:
//  Target - ExchangePlanRef - exchange plan node reference. User content is retrieved for this node.
//
//  Returns:
//   Map:
//     * Key   - String - full name of a metadata object that is included in the exchange plan content.
//     * Value - EnumRef.ExchangeObjectExportModes - object export mode.
//
Function UserExchangePlanContent(Val Target) Export
	
	Result = New Map;
	
	TargetProperties = CommonUse.ObjectAttributeValues(Target,
		CommonUse.AttributeNamesByType(Target, Type("EnumRef.ExchangeObjectExportModes"))
	);
	
	Priorities = ObjectExportModePriorities();
	
	ExchangePlanName = Target.Metadata().Name;
	
	Rules = DataExchangeCached.ExchangePlanObjectChangeRecordRules(ExchangePlanName);
	
	For Each Item In Metadata.ExchangePlans[ExchangePlanName].Content Do
		
		ObjectName = Item.Metadata.FullName();
		
		ObjectRules = Rules.FindRows(New Structure("MetadataObjectName", ObjectName));
		
		ExportMode = Undefined;
		
		If ObjectRules.Count() = 0 Then // Registration rules are not set
			
			ExportMode = Enums.ExchangeObjectExportModes.UnloadAlways;
			
		Else // Registration rules are set
			
			For Each ORR In ObjectRules Do
				
				If ValueIsFilled(ORR.FlagAttributeName) Then
					
					ExportMode = ObjectExportMaximumMode(TargetProperties[ORR.FlagAttributeName], ExportMode, Priorities);
					
				EndIf;
				
			EndDo;
			
			If ExportMode = Undefined
				Or ExportMode = Enums.ExchangeObjectExportModes.EmptyRef() Then
				
				ExportMode = Enums.ExchangeObjectExportModes.ExportByCondition;
				
			EndIf;
			
		EndIf;
		
		Result.Insert(ObjectName, ExportMode);
		
	EndDo;
	
	Return Result;
EndFunction

// Returns the object export mode based on the exchange plan user content (user settings).
//
// Parameters:
//  ObjectName - metadata object full name. Export mode is retrieved for this metadata object.
//  Target     - ExchangePlanRef - exchange plan node reference. The function gets user content from this node.
//
// Returns:
//   EnumRef.ExchangeObjectExportModes - object export mode.
//
Function ObjectExportMode(Val ObjectName, Val Target) Export
	
	Result = DataExchangeCached.UserExchangePlanContent(Target).Get(ObjectName);
	
	Return ?(Result = Undefined, Enums.ExchangeObjectExportModes.UnloadAlways, Result);
EndFunction

Function ObjectExportMaximumMode(Val ExportMode1, Val ExportMode2, Val Priorities)
	
	If Priorities.Find(ExportMode1) < Priorities.Find(ExportMode2) Then
		
		Return ExportMode1;
		
	Else
		
		Return ExportMode2;
		
	EndIf;
	
EndFunction

Function ObjectExportModePriorities()
	
	Result = New Array;
	Result.Add(Enums.ExchangeObjectExportModes.UnloadAlways);
	Result.Add(Enums.ExchangeObjectExportModes.ManualExport);
	Result.Add(Enums.ExchangeObjectExportModes.ExportByCondition);
	Result.Add(Enums.ExchangeObjectExportModes.EmptyRef());
	Result.Add(Enums.ExchangeObjectExportModes.ExportIfNecessary);
	Result.Add(Enums.ExchangeObjectExportModes.NotExport);
	Result.Add(Undefined);
	
	Return Result;
EndFunction


// Retrieves the object registration attribute table for the selective object
// registration mechanism.
//
// Parameters:
//  ObjectName       - String - full metadata object name, for example, Catalog.Items.
//  ExchangePlanName - String - The exchange plan name as it is set in Designer mode.

//
// Returns:
//  ChangeRecordAttributeTable - ValueTable - table of registration attributes ordered
//                               by the Order field.
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
// Value table - registration attribute table for all metadata objects.
//
Function GetSelectiveObjectChangeRecordRulesSP() Export
	
	SetPrivilegedMode(True);
	
	Return SessionParameters.SelectiveObjectChangeRecordRules.Get();
	
EndFunction

// Retrieves the predefined exchange plan node.
// 
// Parameters:
//  ExchangePlanName - String - exchange plan name as it is set in Designer mode.
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
//  InfobaseNode - ExchangePlanRef - exchange plan node to be checked.
// 
//  Returns:
//   True - True if the node belongs to the DIB exchange plan, False otherwise.
//
Function IsDistributedInfobaseNode(Val InfobaseNode) Export
	
	Return InfobaseNode.Metadata().DistributedInfobase;
	
EndFunction

// Determines whether the node belongs to the standard exchange plan (without conversion rules).
// 
// Parameters:
//  InfobaseNode - ExchangePlanRef - exchange plan node to be checked.
// 
//  Returns:
//   True - True if the node belongs to the standard exchange plan, False otherwise.
//
Function IsStandardDataExchangeNode(InfobaseNode) Export
	
	Return Not IsDistributedInfobaseNode(InfobaseNode)
		  And Not HasExchangePlanTemplate(GetExchangePlanName(InfobaseNode), "ExchangeRules");
EndFunction

// Determines whether the node belongs to the universal exchange plan (with conversion rules).
// 
// Parameters:
//  InfobaseNode - ExchangePlanRef - exchange plan node to be checked.
// 
//  Returns:
//   True if the node belongs to the universal exchange plan, False otherwise.
//
Function IsUniversalDataExchangeNode(InfobaseNode) Export
	
	If CommonUse.SubsystemExists("DataExchangeXDTO") Then
		
		DataExchangeXDTOCachedModule = CommonUse.CommonModule("DataExchangeXDTOCached");
		DataExchangeXDTOServerModule = CommonUse.CommonModule("DataExchangeXDTOServer");
		
		If DataExchangeXDTOCachedModule.IsXDTOExchangePlan(InfobaseNode) Then
			Return True;
		EndIf;
	EndIf;
	
	Return Not IsDistributedInfobaseNode(InfobaseNode)
		And HasExchangePlanTemplate(GetExchangePlanName(InfobaseNode), "ExchangeRules");
	
EndFunction

// Determines whether the node belongs to the exchange plan that uses SL exchange functionality.
// 
// Parameters:
//  InfobaseNode - ExchangePlanRef, ExchangePlanObject - exchange plan node to be checked.
// 
//  Returns:
//   True if the node belongs to the exchange plan that uses SL exchange functionality, False otherwise.
//
Function IsSLDataExchangeNode(Val InfobaseNode) Export
	
	Return SLExchangePlans().Find(GetExchangePlanName(InfobaseNode)) <> Undefined;
	
EndFunction

// Determines whether the node belongs to the separated exchange plan that uses 
// SL exchange functionality.
// 
// Parameters:
//  InfobaseNode - ExchangePlanRef - exchange plan node to be checked.
// 
//  Returns:
//   True if the node belongs to the exchange plan that uses SL exchange functionality, False otherwise.
//
Function IsSeparatedSLDataExchangeNode(InfobaseNode) Export
	
	Return SeparatedSLExchangePlans().Find(GetExchangePlanName(InfobaseNode)) <> Undefined;
	
EndFunction

// Determines whether the exchange plan belongs to the DIB exchange plan.
// 
// Parameters:
//  ExchangePlanName - String - exchange plan name as it is set in Designer.
// 
//  Returns:
//   True - exchange plan belongs to the DIB exchange plan, False otherwise.
//
Function IsDistributedInfobaseExchangePlan(ExchangePlanName) Export
	
	Return Metadata.ExchangePlans[ExchangePlanName].DistributedInfobase;
	
EndFunction

// Retrieves the exchange plan name as the metadata object for the specified node.
// 
// Parameters:
//  ExchangePlanNode - ExchangePlanRef, ExchangePlanObject - exchange plan node
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
//  ExchangePlanName - String - The exchange plan name as it is set in Designer mode.
// 
// Returns:
//  NodeArray - Array - array of all nodes except the predefined one for the specified exchange plan.
//
Function GetExchangePlanNodeArray(ExchangePlanName) Export
	
	ThisNode = ExchangePlans[ExchangePlanName].ThisNode();
	
	QueryText = "
	|SELECT
	| ExchangePlan.Ref
	|FROM ExchangePlan." + ExchangePlanName + " AS
	|ExchangePlan
	|	WHERE ExchangePlan.Ref <> &ThisNode";
	
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
//  ExchangePlanName - String - exchange plan name as it is set in Designer mode.
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
//  ExchangePlanName - String - exchange plan name as it is set in Designer mode.
// 
// Returns:
//  RuleList - list values - list filled with templates of standard registration rules.
//
Function GetStandardChangeRecordRuleList(ExchangePlanName) Export
	
	Return GetStandardRuleList(ExchangePlanName, "RecordRules");
	
EndFunction

// Retrieves a list of configuration exchange plans that use the SL functionality.
// The list is filled with names and synonyms of exchange plans.
// 
// Returns:
//  ExchangePlanList - list values - list of configuration exchange plans.
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
// If the configuration does not contain separators, all exchange plans are treated as separated.
// 
// Returns:
// Array - array of separated configuration exchange plan names.
//
Function SeparatedSLExchangePlans() Export
	
	Result = New Array;
	
	For Each ExchangePlanName In SLExchangePlans() Do
		
		If CommonUseCached.IsSeparatedConfiguration() Then
			
			If CommonUseCached.IsSeparatedMetadataObject("ExchangePlan." + ExchangePlanName,
					CommonUseCached.MainDataSeparator()) Then
				
				Result.Add(ExchangePlanName);
				
			EndIf;
			
		Else
			
			Result.Add(ExchangePlanName);
			
		EndIf;
		
	EndDo;
	
	Return Result;
EndFunction

// For internal use.
//
Function CommonNodeData(Val InfobaseNode) Export
	
	Return DataExchangeServer.CommonNodeData(GetExchangePlanName(InfobaseNode),
		InformationRegisters.CommonInfobaseNodeSettings.CorrespondentVersion(InfobaseNode)
	);
EndFunction

// For internal use.
//
Function ExchangePlanTabularSections(Val ExchangePlanName, Val CorrespondentVersion = "") Export
	
	CommonTables           = New Array;
	ThisInfobaseTables     = New Array;
	CorrespondentTables    = New Array;
	AllInfobaseTables      = New Array;
	AllCorrespondentTables = New Array;
	
	CommonNodeData = DataExchangeServer.CommonNodeData(ExchangePlanName, CorrespondentVersion);
	
	TabularSections = DataExchangeEvents.ObjectTabularSections(Metadata.ExchangePlans[ExchangePlanName]);
	
	If Not IsBlankString(CommonNodeData) Then
		
		For Each TabularSection In TabularSections Do
			
			If Find(CommonNodeData, TabularSection) <> 0 Then
				
				CommonTables.Add(TabularSection);
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	ThisInfobaseSettings = DataExchangeServer.NodeFilterStructure(ExchangePlanName, CorrespondentVersion);
	
	ThisInfobaseSettings = DataExchangeEvents.StructureKeysToString(ThisInfobaseSettings);
	
	If IsBlankString(CommonNodeData) Then
		
		For Each TabularSection In TabularSections Do
			
			If Find(ThisInfobaseSettings, TabularSection) <> 0 Then
				
				ThisInfobaseTables.Add(TabularSection);
				
				AllInfobaseTables.Add(TabularSection);
				
			EndIf;
			
		EndDo;
		
	Else
		
		For Each TabularSection In TabularSections Do
			
			If Find(ThisInfobaseSettings, TabularSection) <> 0 Then
				
				AllInfobaseTables.Add(TabularSection);
				
				If Find(CommonNodeData, TabularSection) = 0 Then
					
					ThisInfobaseTables.Add(TabularSection);
					
				EndIf;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	CorrespondentSettings = DataExchangeServer.CorrespondentInfobaseNodeFilterSetup(ExchangePlanName, CorrespondentVersion);
	
	If IsBlankString(CommonNodeData) Then
		
		For Each CorrespondentSetting In CorrespondentSettings Do
			
			If TypeOf(CorrespondentSetting.Value) = Type("Structure") Then
				
				CorrespondentTables.Add(CorrespondentSetting.Key);
				
				AllCorrespondentTables.Add(CorrespondentSetting.Key);
				
			EndIf;
			
		EndDo;
		
	Else
		
		For Each CorrespondentSetting In CorrespondentSettings Do
			
			If TypeOf(CorrespondentSetting.Value) = Type("Structure") Then
				
				AllCorrespondentTables.Add(CorrespondentSetting.Key);
				
				If Find(CommonNodeData, CorrespondentSetting.Key) = 0 Then
					
					CorrespondentTables.Add(CorrespondentSetting.Key);
					
				EndIf;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	Result = New Structure;
	Result.Insert("CommonTables",           CommonTables);
	Result.Insert("ThisInfobaseTables",     ThisInfobaseTables);
	Result.Insert("CorrespondentTables",    CorrespondentTables);
	Result.Insert("AllInfobaseTables",      AllInfobaseTables);
	Result.Insert("AllCorrespondentTables", AllCorrespondentTables);
	
	Return Result;
EndFunction

// Retrieves the exchange plan manager by the exchange plan name.
//
// Parameters:
//  ExchangePlanName - String - exchange plan name as it is set in Designer mode.
//
// Returns:
//  ExchangePlanManager - exchange plan manager.
//
Function GetExchangePlanManagerByName(ExchangePlanName) Export
	
	Return ExchangePlans[ExchangePlanName];
	
EndFunction

// Retrieves the exchange plan manager by the exchange plan metadata object name.
//
// Parameters:
//  ExchangePlanNode - ExchangePlanRef - exchange plan node whose manager will be retrieved.
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

// Calls the function with the same name from the DataExchangeServer module.
//
Function DataProcessorForDataImport(Cancel, Val InfobaseNode, Val ExchangeMessageFileName) Export
	
	Return DataExchangeServer.DataProcessorForDataImport(Cancel, InfobaseNode, ExchangeMessageFileName);
	
EndFunction

// Determines whether the exchange plan has the template.
// 
// Parameters:
//  ExchangePlanName - String - exchange plan name as it is set in Designer mode.
//  TemplateName     – String – name of the template to be checked.
// 
//  Returns:
//   True if the exchange plan contains the specified template, False otherwise.
//
Function HasExchangePlanTemplate(Val ExchangePlanName, Val TemplateName) Export
	
	Return Metadata.ExchangePlans[ExchangePlanName].Templates.Find(TemplateName) <> Undefined;
	
EndFunction

// Calls the same name function from the DataExchangeEvents module.
//
Function NodeArrayByPropertyValues(PropertyValues, QueryText, ExchangePlanName, FlagAttributeName, Val Data = False) Export
	
	#If ExternalConnection Or ThickClientOrdinaryApplication Then
		
		Return DataExchangeServerCall.NodeArrayByPropertyValues(PropertyValues, QueryText, ExchangePlanName, FlagAttributeName, Data);
		
	#Else
		
		SetPrivilegedMode(True);
		Return DataExchangeEvents.NodeArrayByPropertyValues(PropertyValues, QueryText, ExchangePlanName, FlagAttributeName, Data);
		
	#EndIf
	
EndFunction

// Returns a collection of exchange message transport that can be used for the specified
// exchange plan node.
// 
// Parameters:
//  InfobaseNode - ExchangePlanRef - exchange plan node to be checked.
// 
//  Returns:
//   Array - message transports that can be used for the specified exchange plan node.
//
Function UsedExchangeMessageTransports(InfobaseNode) Export
	
	Result = ExchangePlans[GetExchangePlanName(InfobaseNode)].UsedExchangeMessageTransports();
	
	// Exchange via a COM connection or via a web service is not supported for base
	// configuration versions.
	If StandardSubsystemsServer.IsBaseConfigurationVersion() Then
		
		CommonUseClientServer.DeleteValueFromArray(Result, Enums.ExchangeMessageTransportKinds.COM);
		CommonUseClientServer.DeleteValueFromArray(Result, Enums.ExchangeMessageTransportKinds.WS);
		
	EndIf;
		
	// Exchange via a COM connection is not supported for the DIB exchange
	If IsDistributedInfobaseNode(InfobaseNode) Then
		
		CommonUseClientServer.DeleteValueFromArray(Result, Enums.ExchangeMessageTransportKinds.COM);
		
	EndIf;
	
	// Exchange via a COM connection is not supported for the standard exchange (without conversion rules)
	If IsStandardDataExchangeNode(InfobaseNode) Then
		
		CommonUseClientServer.DeleteValueFromArray(Result, Enums.ExchangeMessageTransportKinds.COM);
		
	EndIf;
	
	// COM connections are not supported if 1C server is running on Linux
	If CommonUse.IsLinuxServer() Then
		
		CommonUseClientServer.DeleteValueFromArray(Result, Enums.ExchangeMessageTransportKinds.COM);
		
	EndIf;
	
	Return Result;
EndFunction

// Establishes an external connection to the infobase and returns a reference to this connection.
// 
// Parmeters:
//  InfobaseNode       - ExchangePlanRef - mandatory. The exchange plan node. External connection to this node is established.
//  ErrorMessageString – String – optional. If an error occurs when establishing
//                       an external connection, the error message text is returned to
//                       this parameter.
//
// Returns:
//  COM object - if the external connection is established.
//  Undefined  - if the external connection is not established.
 
//
Function GetExternalConnectionForInfobaseNode(InfobaseNode, ErrorMessageString = "") Export

	Result = ExternalConnectionForInfobaseNode(InfobaseNode);

	ErrorMessageString = Result.DetailedErrorDetails;
	Return Result.Connection;
	
EndFunction

// Establishes an external connection to the infobase and returns a reference to this connection.
// 
// Parameters:
//  InfobaseNode (mandatory)      - ExchangePlanRef - exchange plan node. 
//                                  External connection to this node is established. 
//  ErrorMessageString (optional) - String - if an error occurs when establishing an external connection, the error message text is stored to this parameter.
//
// Returns:
//  COM object - if the external connection is established.
//  Undefined  - if the external connection is not established.
//
Function ExternalConnectionForInfobaseNode(InfobaseNode) Export
	
	Return DataExchangeServer.EstablishExternalConnectionWithInfobase(
        InformationRegisters.ExchangeTransportSettings.TransportSettings(
            InfobaseNode, Enums.ExchangeMessageTransportKinds.COM));
	
EndFunction

// Determines whether file transfer over LAN is possible between two infobases.
//
// Parameters:
//  InfobaseNode - ExchangePlanRef - exchange plan node. Exchange messages are received for this node.
//  Password     - String - password for the WS connection.
//
Function IsExchangeInSameLAN(Val InfobaseNode, Val AuthenticationParameters = Undefined) Export
	
	Return DataExchangeServer.IsExchangeInSameLAN(InfobaseNode, AuthenticationParameters);
	
EndFunction

// Determines whether the exchange plan can be used by the configuration functional 
// option composition.
// If no one functional option includes the exchange plan, the function returns True.
// If functional options include the exchange plan and one or more functional options
// are enabled, the function returns True.
// Otherwise the function returns False.

//
// Parameters:
//  ExchangePlanName – String - name of the exchange plan to be checked.
//
// Returns:
//  Boolean - True if the exchange plan can be used, False otherwise.
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

// Returns an array of version numbers supported by correspondent API for the DataExchange subsystem.
// 
// Parameters:
// Correspondent - Structure, ExchangePlanRef. Exchange plan note that matches the correspondent infobase.
//
// Returns:
//  Array of version numbers that are supported by correspondent API.
//
Function CorrespondentVersions(Val Correspondent) Export
	
	If TypeOf(Correspondent) = Type("Structure") Then
		SettingsStructure = Correspondent;
	Else
		SettingsStructure = InformationRegisters.ExchangeTransportSettings.TransportSettingsWS(Correspondent);
	EndIf;
	
	ConnectionParameters = New Structure;
	ConnectionParameters.Insert("URL",      SettingsStructure.WSURL);
	ConnectionParameters.Insert("UserName", SettingsStructure.WSUserName);
	ConnectionParameters.Insert("Password", SettingsStructure.WSPassword);
	
	Return CommonUse.GetInterfaceVersions(ConnectionParameters, "DataExchange");
EndFunction

// Returns the array of all reference types available in the configuration.
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

Function StandaloneModeExchangePlans()
	
  // An exchange plan that is used to implement the standalone mode in SaaS mode
  // must match the following conditions:
	// - it is a separated exchange plan
	// - it is a DIB exchange plan
	// - the ExchangePlanUsedInSaaS value is True
	
	Result = New Array;
	
	For Each ExchangePlan In Metadata.ExchangePlans Do
		
		If DataExchangeServer.IsSLSeparatedExchangePlan(ExchangePlan.Name)
			And ExchangePlan.DistributedInfobase
			And ExchangePlanUsedInSaaS(ExchangePlan.Name) Then
			
			Result.Add(ExchangePlan.Name);
			
		EndIf;
		
	EndDo;
	
	Return Result;
EndFunction

Function SecurityProfileName(Val ExchangePlanName) Export
	
	If Catalogs.MetadataObjectIDs.DataUpdated() Then
		ExchangePlanID = CommonUse.MetadataObjectID(Metadata.ExchangePlans[ExchangePlanName]);
		SecurityProfileName = SafeModeInternal.ExternalModuleAttachingMode(ExchangePlanID);
	Else
		SecurityProfileName = Undefined;
	EndIf;
	
	If SecurityProfileName = Undefined Then
		SecurityProfileName = Constants.InfobaseSecurityProfile.Get();
		If IsBlankString(SecurityProfileName) Then
			SecurityProfileName = Undefined;
		EndIf;
	EndIf;
	
	Return SecurityProfileName;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Initializing the data exchange settings structure.

// Initializes the data exchange subsystem for performing the exchange.
// 
// Parameters:
// 
// Returns:
//  ExchangeSettingsStructure - Structure - structure with all required for exchange data and objects.
//
Function GetExchangeSettingStructureForInfobaseNode(
	InfobaseNode,
	ActionOnExchange,
	ExchangeMessageTransportKind,
	UseTransportSettings = True
	) Export
	
	Return DataExchangeServer.GetExchangeSettingStructureForInfobaseNode(
		InfobaseNode,
		ActionOnExchange,
		ExchangeMessageTransportKind,
		UseTransportSettings);
EndFunction

// Initializes the data exchange subsystem for performing the exchange.
// 
// Returns:
//  ExchangeSettingsStructure - Structure - structure with all required for exchange data and objects.
//
Function GetExchangeSettingsStructure(ExchangeExecutionSettings, LineNumber) Export
	
	Return DataExchangeServer.GetExchangeSettingsStructure(ExchangeExecutionSettings, LineNumber);
	
EndFunction

// Retrieves a transport settings structure for performing the data exchange.
//
Function GetTransportSettingsStructure(InfobaseNode, ExchangeMessageTransportKind) Export
	
	Return DataExchangeServer.GetTransportSettingsStructure(InfobaseNode, ExchangeMessageTransportKind);
	
EndFunction

// Retrieves a list filled with templates of standard exchange rules from configuration 
// for the specified exchange plan. The list is filled with names and synonyms of rule 
// templates.

// 
// Parameters:
//  ExchangePlanName - String - exchange plan name as it is set in Designer mode.
// 
// Returns:
//  RuleList - list values - list filled with templates of standard exchange rules.
//
Function GetStandardRuleList(ExchangePlanName, TemplateNameLiteral)
	
	RuleList = New ValueList;
	
	If IsBlankString(ExchangePlanName) Then
		Return RuleList;
	EndIf;
	
	For Each Template In Metadata.ExchangePlans[ExchangePlanName].Templates Do
		
		If Find(Template.Name, TemplateNameLiteral) <> 0 And Find(Template.Name, "Correspondent") = 0 Then
			
			RuleList.Add(Template.Name, Template.Synonym);
			
		EndIf;
		
	EndDo;
	
	Return RuleList;
EndFunction

// Returns a node content table. The table contains objects that have reference types.
//
// Parameters:
//    ExchangeNode - exchange node reference.
//    Periodical   - flag that shows whether objects that store data (such as documents) 
//                   are included in the result. 
//    Catalog      - flag that shows whether regulatory data objects are included 
//                   in the result.
//
// Returns:
//    ValueTable - a table that contains the following columns:
//      * FullMetadataName - metadata full name (a table name for the query).
//      * ListPresentation - list presentation for the table.
//      * Presentation     - object presentation for the table.
//      * PictureIndex     - picture index according to PictureLib.MetadataObjectCollection.
//      * Type             - metadata type.
//      * PeriodSelection  - flag that shows whether selection by period can be applied to the object.
//
Function NodeContentRefTables(ExchangeNode, Periodical=True, Catalog=True) Export
	
	ResultTable = New ValueTable;
	For Each KeyValue In (New Structure("FullMetadataName, Presentation, ListPresentation, PictureIndex, Type, SelectPeriod")) Do
		ResultTable.Columns.Add(KeyValue.Key);
	EndDo;
	For Each KeyValue In (New Structure("FullMetadataName, Presentation, ListPresentation, Type")) Do
		ResultTable.Indexes.Add(KeyValue.Key);
	EndDo;
	
	If ExchangeNode=Undefined Then
		Return ResultTable;
	EndIf;
	
	// All metadata objects to be registered for the node
	For Each ContentItem In ExchangeNode.Metadata().Content Do
		Meta = ContentItem.Metadata;
		Details = MetadataObjectName(Meta);
		If Details.PictureIndex >= 0 Then
			// Required reference type
			If Not Periodical And Details.Periodical Then 
				Continue;
			ElsIf Not Catalog And Details.Catalog Then 
				Continue;
			EndIf;
			
			Row = ResultTable.Add();
			FillPropertyValues(Row, Details);
			Row.SelectPeriod     = Details.Periodical;
			Row.FullMetadataName = Meta.FullName();
			Row.ListPresentation = DataExchangeServer.ObjectListPresentation(Meta);
			Row.Presentation     = DataExchangeServer.ObjectPresentation(Meta);
		EndIf;
	EndDo;
	
	ResultTable.Sort("ListPresentation");
	Return ResultTable;
EndFunction

Function MetadataObjectName(Meta)
	Res = New Structure("PictureIndex, Periodical, Catalog, Type", -1, False, False);
	
	If Metadata.Catalogs.Contains(Meta) Then
		Res.PictureIndex = 3;
		Res.Catalog = True;
		Res.Type = Type("CatalogRef." + Meta.Name);
		
	ElsIf Metadata.Documents.Contains(Meta) Then
		Res.PictureIndex = 7;
		Res.Periodical = True;
		Res.Type = Type("DocumentRef." + Meta.Name);
		
	ElsIf Metadata.ChartsOfCharacteristicTypes.Contains(Meta) Then
		Res.PictureIndex = 9;
		Res.Catalog = True;
		Res.Type = Type("ChartOfCharacteristicTypesRef." + Meta.Name);
		
	ElsIf Metadata.ChartsOfAccounts.Contains(Meta) Then
		Res.PictureIndex = 11;
		Res.Catalog = True;
		Res.Type = Type("ChartOfAccountsRef." + Meta.Name);
		
	ElsIf Metadata.ChartsOfCalculationTypes.Contains(Meta) Then
		Res.PictureIndex = 13;
		Res.Catalog = True;
		Res.Type = Type("ChartOfCalculationTypesRef." + Meta.Name);
		
	ElsIf Metadata.BusinessProcesses.Contains(Meta) Then
		Res.PictureIndex = 23;
		Res.Periodical = True;
		Res.Type = Type("BusinessProcessRef." + Meta.Name);
		
	ElsIf Metadata.Tasks.Contains(Meta) Then
		Res.PictureIndex = 25;
		Res.Periodical  = True;
		Res.Type = Type("TaskRef." + Meta.Name);
		
	EndIf;
	
	Return Res;
EndFunction

// Determines whether the object versioning is used.
//
// Parameters:
// Source - ExchangePlanRef - if this parameter is set, defines whether
// 	       object version creation is required for the passed node.
//
Function VersioningUsed(Source = Undefined, CheckAccessRights = False) Export
	
	Used = False;
	
	If CommonUse.SubsystemExists("StandardSubsystems.ObjectVersioning") Then
		
		Used = ?(Source <> Undefined, IsSLDataExchangeNode(Source), True);
		
		If Used And CheckAccessRights Then
			
			ObjectVersioningModule = CommonUse.CommonModule("ObjectVersioning");
			Used = ObjectVersioningModule.HasRightToReadObjectVersions();
			
		EndIf;
			
	EndIf;
	
	Return Used;
	
EndFunction

// Returns the name of the temporary file directory.
//
// Returns:
//  String - path to the temporary file directory.
//
Function TempFileStorageDirectory() Export
	
  // If the current infobase is running in file mode, the function returns the temporary file directory
	If CommonUse.FileInfobase() Then 
		Return TrimAll(TempFilesDir());
	EndIf;
	
	CommonPlatformType = "Windows";
	
	ServerPlatformType = CommonUseCached.ServerPlatformType();
	
	SetPrivilegedMode(True);
	
	If    ServerPlatformType = PlatformType.Windows_x86
		Or ServerPlatformType = PlatformType.Windows_x86_64 Then
		
		Result             = Constants.DataExchangeMessageDirectoryForWindows.Get();
		
	ElsIf ServerPlatformType = PlatformType.Linux_x86
		Or   ServerPlatformType = PlatformType.Linux_x86_64 Then
		
		Result             = Constants.DataExchangeMessageDirectoryForLinux.Get();
		CommonPlatformType = "Linux";
		
	Else
		
		Result             = Constants.DataExchangeMessageDirectoryForWindows.Get();
		
	EndIf;
	
	SetPrivilegedMode(False);
	
	ConstantPresentation = ?(CommonPlatformType = "Linux", 
		Metadata.Constants.DataExchangeMessageDirectoryForLinux.Presentation(),
		Metadata.Constants.DataExchangeMessageDirectoryForWindows.Presentation());
	
	If IsBlankString(Result) Then
		
		Result = TrimAll(TempFilesDir());
		
	Else
		
		Result = TrimAll(Result);
		
		// Checking whether the directory exists
		Directory = New File(Result);
		If Not Directory.Exist() Then
			
			MessagePattern = NStr("en = 'The temporary file directory does not exist.
					|Make sure that the %1 parameter value is set in the application parameters.'");
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, ConstantPresentation);
			Raise(MessageText);
			
		EndIf;
		
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion
