#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

Var Registration Export; // structure that contains registration parameters
Var ObjectChangeRecordRules Export; // value table that contains object registration rules
Var ErrorFlag Export; // global error flag

Var StringType;
Var BooleanType;
Var NumberType;
Var DateType;

Var EmptyDateValue;
Var FilterByExchangePlanPropertiesTreePattern;  // registration rule value tree pattern by exchange plan properties
Var FilterByObjectPropertiesTreePattern;      // registration rule value tree pattern by object properties
Var BooleanPropertyRootGroupValue; // boolean value for the root property group
Var ErrorMessages; // Map. Key is an error code and Value is error details

#Region InternalProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Export internal procedures and functions

// Performs a syntactic analysis of the XML file that contains registration rules. Fills
// collection values with data from the file.
// Prepares read rules for the ORR mechanism.

//
// Parameters:
//  FileName - String - full name of a rule file in the local file system.
//  InfoOnly - Boolean - flag that shows whether the file title and rule information are
//             the only data to be read. The default value is False.

//
Procedure ImportRules(Val FileName, InfoOnly = False) Export
	
	ErrorFlag = False;
	
	If IsBlankString(FileName) Then
		ReportProcessingError(4);
		Return;
	EndIf;
	
	// Initializing collections for rules
	Registration                              = RecordInitialization();
	ObjectChangeRecordRules                   = DataProcessors.ObjectChangeRecordRuleImport.ORRTableInitialization();
	FilterByExchangePlanPropertiesTreePattern = DataProcessors.ObjectChangeRecordRuleImport.FilterByExchangePlanPropertiesTableInitialization();
	FilterByObjectPropertiesTreePattern       = DataProcessors.ObjectChangeRecordRuleImport.FilterByObjectPropertiesTableInitialization();
	
	// LOADING REGISTRATION RULES
	Try
		LoadRecordFromFile(FileName, InfoOnly);
	Except
		
		// Reporting about the error
		ReportProcessingError(2, BriefErrorDescription(ErrorInfo()));
		
	EndTry;
	
	// Error reading rules from the file
	If ErrorFlag Then
		Return;
	EndIf;
	
	If InfoOnly Then
		Return;
	EndIf;
	
	// PREPARING RULES FOR THE ORR MECHANISM
	
	For Each ORR In ObjectChangeRecordRules Do
		
		PrepareRecordRuleByExchangePlanProperties(ORR);
		
		PrepareChangeRecordRuleByObjectProperties(ORR);
		
	EndDo;
	
	ObjectChangeRecordRules.FillValues(Registration.ExchangePlanName, "ExchangePlanName");
	
EndProcedure

// Prepares a string that contains rule information based on data read from the XML file.
//
// Returns:
//  InfoString - String - string with rule information.
//
Function GetRuleInformation() Export
	
	// Return value
	InfoString = "";
	
	If ErrorFlag Then
		Return InfoString;
	EndIf;
	
	InfoString = NStr("en = 'Object registration rules in the current infobase (%1) created on %2'");
	
	Return StringFunctionsClientServer.SubstituteParametersInString(InfoString,
					GetConfigurationPresentationFromRecordRules(),
					Format(Registration.CreationDateTime, "DLF = dd"));
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for loading object registration rules (ORR).

Procedure LoadRecordFromFile(FileName, InfoOnly)
	
	// Opening the file for reading
	Try
		Rules = New XMLReader();
		Rules.OpenFile(FileName);
		Rules.Read();
	Except
		Rules = Undefined;
		ReportProcessingError(1, BriefErrorDescription(ErrorInfo()));
		Return;
	EndTry;
	
	Try
		LoadRecord(Rules, InfoOnly);
	Except
		ReportProcessingError(2, BriefErrorDescription(ErrorInfo()));
	EndTry;
	
	Rules.Close();
	Rules = Undefined;
	
EndProcedure

// Loads registration rule.
//  
Procedure LoadRecord(Rules, InfoOnly)
	
	If Not ((Rules.LocalName = "RecordRules") 
		And (Rules.NodeType = XMLNodeType.StartElement)) Then
		
		// Rule format error
		ReportProcessingError(3);
		
		Return;
		
	EndIf;
	
	While Rules.Read() Do
		
		NodeName = Rules.LocalName;
		NodeType = Rules.NodeType;
		
		// Registration attributes
		If NodeName = "FormatVersion" Then
			
			Registration.FormatVersion = deElementValue(Rules, StringType);
			
		ElsIf NodeName = "ID" Then
			
			Registration.ID = deElementValue(Rules, StringType);
			
		ElsIf NodeName = "Description" Then
			
			Registration.Description = deElementValue(Rules, StringType);
			
		ElsIf NodeName = "CreationDateTime" Then
			
			Registration.CreationDateTime = deElementValue(Rules, DateType);
			
		ElsIf NodeName = "ExchangePlan" Then
			
			// Exchange plan attributes
			Registration.ExchangePlanName = deAttribute(Rules, StringType, "Name");
			
			Registration.ExchangePlan = deElementValue(Rules, StringType);
			
		ElsIf NodeName = "Comment" Then
			
			Registration.Comment = deElementValue(Rules, StringType);
			
		ElsIf NodeName = "Configuration" Then
			
			// Configuration attributes
			Registration.PlatformVersion     = deAttribute(Rules, StringType, "PlatformVersion");
			Registration.ConfigurationVersion  = deAttribute(Rules, StringType, "ConfigurationVersion");
			Registration.ConfigurationSynonym = deAttribute(Rules, StringType, "ConfigurationSynonym");
			
			// Configuration description
			Registration.Configuration = deElementValue(Rules, StringType);
			
		ElsIf NodeName = "ObjectChangeRecordRules" Then
			
			If InfoOnly Then
				
				Break; // Breaking if only registration information is required
				
			Else
				
				// Checking whether ORR have been loaded for the required exchange plan
				CheckExchangePlanExists();
				
				If ErrorFlag Then
					Break; // Rules contain wrong exchange plan
				EndIf;
				
				ImportRecordRules(Rules);
				
			EndIf;
			
		ElsIf (NodeName = "RecordRules") And (NodeType = XMLNodeType.EndElement) Then
			
			Break; // Exit
			
		Else
			
			deSkip(Rules);
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Loads registration rules according to the exchange plan format.
//
// Parameters:
//  Rules - XMLReader object.
// 
Procedure ImportRecordRules(Rules)
	
	While Rules.Read() Do
		
		NodeName = Rules.LocalName;
		
		If NodeName = "Rule" Then
			
			LoadRecordRule(Rules);
			
		ElsIf NodeName = "Group" Then
			
			LoadRecordRuleGroup(Rules);
			
		ElsIf (NodeName = "ObjectChangeRecordRules") And (Rules.NodeType = XMLNodeType.EndElement) Then
			
			Break;
			
		Else
			
			deSkip(Rules);
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Loads object registration rules.
//
// Parameters:
//  Rules  - XMLReader object.
// 
Procedure LoadRecordRule(Rules)
	
	// Rules with the Disable flag must not be loaded
	Disable = deAttribute(Rules, BooleanType, "Disable");
	If Disable Then
		deSkip(Rules);
		Return;
	EndIf;
	
	// Rules with errors must not be loaded
	Valid = deAttribute(Rules, BooleanType, "Valid");
	If Not Valid Then
		deSkip(Rules);
		Return;
	EndIf;
	
	NewRow = ObjectChangeRecordRules.Add();
	
	While Rules.Read() Do
		
		NodeName = Rules.LocalName;
		
		If NodeName = "SettingsObject" Then
			
			NewRow.SettingsObject = deElementValue(Rules, StringType);
			
		ElsIf NodeName = "MetadataObjectName" Then
			
			NewRow.MetadataObjectName = deElementValue(Rules, StringType);
			
		ElsIf NodeName = "ExportModeAttribute" Then
			
			NewRow.FlagAttributeName = deElementValue(Rules, StringType);
			
		ElsIf NodeName = "FilterByExchangePlanProperties" Then
			
			// Initializing the property collection for the current ORR
			NewRow.FilterByExchangePlanProperties = FilterByExchangePlanPropertiesTreePattern.Copy();
			
			LoadFilterByExchangePlanPropertiesTree(Rules, NewRow.FilterByExchangePlanProperties);
			
		ElsIf NodeName = "FilterByObjectProperties" Then
			
			// Initializing the property collection for the current ORR
			NewRow.FilterByObjectProperties = FilterByObjectPropertiesTreePattern.Copy();
			
			LoadFilterByObjectPropertiesTree(Rules, NewRow.FilterByObjectProperties);
			
		ElsIf NodeName = "BeforeProcess" Then
			
			NewRow.BeforeProcess = deElementValue(Rules, StringType);
			
			NewRow.HasBeforeProcessHandler = Not IsBlankString(NewRow.BeforeProcess);
			
		ElsIf NodeName = "OnProcess" Then
			
			NewRow.OnProcess = deElementValue(Rules, StringType);
			
			NewRow.HasOnProcessHandler = Not IsBlankString(NewRow.OnProcess);
			
		ElsIf NodeName = "OnProcessAdditional" Then
			
			NewRow.OnProcessAdditional = deElementValue(Rules, StringType);
			
			NewRow.HasOnProcessHandlerAdditional = Not IsBlankString(NewRow.OnProcessAdditional);
			
		ElsIf NodeName = "AfterProcess" Then
			
			NewRow.AfterProcess = deElementValue(Rules, StringType);
			
			NewRow.HasAfterProcessHandler = Not IsBlankString(NewRow.AfterProcess);
			
		ElsIf (NodeName = "Rule") And (Rules.NodeType = XMLNodeType.EndElement) Then
			
			Break;
			
		Else
			
			deSkip(Rules);
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure LoadFilterByExchangePlanPropertiesTree(Rules, ValueTree)
	
	VTRows = ValueTree.Rows;
	
	While Rules.Read() Do
		
		NodeName = Rules.LocalName;
		NodeType = Rules.NodeType;
		
		If NodeName = "FilterItem" Then
			
			LoadExchangePlanFilterItem(Rules, VTRows.Add());
			
		ElsIf NodeName = "Group" Then
			
			LoadExchangePlanFilterItemGroup(Rules, VTRows.Add());
			
		ElsIf (NodeName = "FilterByExchangePlanProperties") And (NodeType = XMLNodeType.EndElement) Then
			
			Break; // Exit
			
		Else
			
			deSkip(Rules);
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure LoadFilterByObjectPropertiesTree(Rules, ValueTree)
	
	VTRows = ValueTree.Rows;
	
	While Rules.Read() Do
		
		NodeName = Rules.LocalName;
		NodeType = Rules.NodeType;
		
		If NodeName = "FilterItem" Then
			
			LoadObjectFilterItem(Rules, VTRows.Add());
			
		ElsIf NodeName = "Group" Then
			
			LoadObjectFilterItemGroup(Rules, VTRows.Add());
			
		ElsIf (NodeName = "FilterByObjectProperties") And (NodeType = XMLNodeType.EndElement) Then
			
			Break; // Exit
			
		Else
			
			deSkip(Rules);
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Loads the object registration rule by the property.
// 
Procedure LoadExchangePlanFilterItem(Rules, NewRow)
	
	NewRow.IsFolder = False;
	
	While Rules.Read() Do
		
		NodeName = Rules.LocalName;
		NodeType = Rules.NodeType;
		
		If NodeName = "ObjectProperty" Then
			
			If NewRow.IsConstantString Then
				
				NewRow.ConstantValue = deElementValue(Rules, Type(NewRow.ObjectPropertyType));
				
			Else
				
				NewRow.ObjectProperty = deElementValue(Rules, StringType);
				
			EndIf;
			
		ElsIf NodeName = "ExchangePlanProperty" Then
			
			// The property can be a header property or tabular section property.
			// If the property is a tabular section property, the FullPropertyDescription 
			// variable contains the tabular section name and the property name.
			// The tabular section is written in square brackets,
			// for example: "[Companies].Company".

			FullPropertyDescription = deElementValue(Rules, StringType);
			
			ExchangePlanTabularSectionName = "";
			
			FirstBracketPosition = Find(FullPropertyDescription, "[");
			
			If FirstBracketPosition <> 0 Then
				
				SecondBracketPosition = Find(FullPropertyDescription, "]");
				
				ExchangePlanTabularSectionName = Mid(FullPropertyDescription, FirstBracketPosition + 1, SecondBracketPosition - FirstBracketPosition - 1);
				
				FullPropertyDescription = Mid(FullPropertyDescription, SecondBracketPosition + 2);
				
			EndIf;
			
			NewRow.NodeParameter                = FullPropertyDescription;
			NewRow.NodeParameterTabularSection = ExchangePlanTabularSectionName;
			
		ElsIf NodeName = "ComparisonType" Then
			
			NewRow.ComparisonType = deElementValue(Rules, StringType);
			
		ElsIf NodeName = "IsConstantString" Then
			
			NewRow.IsConstantString = deElementValue(Rules, BooleanType);
			
		ElsIf NodeName = "ObjectPropertyType" Then
			
			NewRow.ObjectPropertyType = deElementValue(Rules, StringType);
			
		ElsIf (NodeName = "FilterItem") And (NodeType = XMLNodeType.EndElement) Then
			
			Break; // Exit
			
		Else
			
			deSkip(Rules);
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Loads the object registration rule by the property.
// 
Procedure LoadObjectFilterItem(Rules, NewRow)
	
	NewRow.IsFolder = False;
	
	While Rules.Read() Do
		
		NodeName = Rules.LocalName;
		NodeType = Rules.NodeType;
		
		If NodeName = "ObjectProperty" Then
			
			NewRow.ObjectProperty = deElementValue(Rules, StringType);
			
		ElsIf NodeName = "ConstantValue" Then
			
			If IsBlankString(NewRow.FilterItemKind) Then
				
				NewRow.FilterItemKind = DataExchangeServer.FilterItemPropertyConstantValue();
				
			EndIf;
			
			If NewRow.FilterItemKind = DataExchangeServer.FilterItemPropertyConstantValue() Then
				
				NewRow.ConstantValue = deElementValue(Rules, Type(NewRow.ObjectPropertyType)); // Primitive types only
				
			ElsIf NewRow.FilterItemKind = DataExchangeServer.FilterItemPropertyValueAlgorithm() Then
				
				NewRow.ConstantValue = deElementValue(Rules, StringType); // String
				
			Else
				
				NewRow.ConstantValue = deElementValue(Rules, StringType); // String
				
			EndIf;
			
		ElsIf NodeName = "ComparisonType" Then
			
			NewRow.ComparisonType = deElementValue(Rules, StringType);
			
		ElsIf NodeName = "ObjectPropertyType" Then
			
			NewRow.ObjectPropertyType = deElementValue(Rules, StringType);
			
		ElsIf NodeName = "Kind" Then
			
			NewRow.FilterItemKind = deElementValue(Rules, StringType);
			
		ElsIf (NodeName = "FilterItem") And (NodeType = XMLNodeType.EndElement) Then
			
			Break; // Exit
			
		Else
			
			deSkip(Rules);
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Loads the group of object registration rules by property.
//
// Parameters:
//  Rules - XMLReader object.
// 
Procedure LoadExchangePlanFilterItemGroup(Rules, NewRow)
	
	NewRow.IsFolder = True;
	
	While Rules.Read() Do
		
		NodeName = Rules.LocalName;
		NodeType = Rules.NodeType;
		
		If NodeName = "FilterItem" Then
			
			LoadExchangePlanFilterItem(Rules, NewRow.Rows.Add());
		
		ElsIf (NodeName = "Group") And (NodeType = XMLNodeType.StartElement) Then
			
			LoadExchangePlanFilterItemGroup(Rules, NewRow.Rows.Add());
			
		ElsIf NodeName = "BooleanGroupValue" Then
			
			NewRow.BooleanGroupValue = deElementValue(Rules, StringType);
			
		ElsIf (NodeName = "Group") And (NodeType = XMLNodeType.EndElement) Then
			
			Break; // Exit
			
		Else
			
			deSkip(Rules);
			
		EndIf;
		
	EndDo;

EndProcedure

// Loads the group of object registration rules by property.
//
// Parameters:
//  Rules - XMLReader object.
// 
Procedure LoadObjectFilterItemGroup(Rules, NewRow)
	
	NewRow.IsFolder = True;
	
	While Rules.Read() Do
		
		NodeName = Rules.LocalName;
		NodeType = Rules.NodeType;
		
		If NodeName = "FilterItem" Then
			
			LoadObjectFilterItem(Rules, NewRow.Rows.Add());
		
		ElsIf (NodeName = "Group") And (NodeType = XMLNodeType.StartElement) Then
			
			LoadObjectFilterItemGroup(Rules, NewRow.Rows.Add());
			
		ElsIf NodeName = "BooleanGroupValue" Then
			
			BooleanGroupValue = deElementValue(Rules, StringType);
			
			NewRow.IsAndOperator = (BooleanGroupValue = "And");
			
		ElsIf (NodeName = "Group") And (NodeType = XMLNodeType.EndElement) Then
			
			Break; // Exit
			
		Else
			
			deSkip(Rules);
			
		EndIf;
		
	EndDo;

EndProcedure

Procedure LoadRecordRuleGroup(Rules)
	
	While Rules.Read() Do
		
		NodeName = Rules.LocalName;
		
		If NodeName = "Rule" Then
			
			LoadRecordRule(Rules);
			
		ElsIf NodeName = "Group" And Rules.NodeType = XMLNodeType.StartElement Then
			
			LoadRecordRuleGroup(Rules);
			
		ElsIf NodeName = "Group" And Rules.NodeType = XMLNodeType.EndElement Then
		
			Break;
			
		Else
			
			deSkip(Rules);
			
		EndIf;
		
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Compiling object registration rules (ORR) by exchange plan properties.

Procedure PrepareRecordRuleByExchangePlanProperties(ORR)
	
	EmptyRule = (ORR.FilterByExchangePlanProperties.Rows.Count() = 0);
	
	ObjectProperties = New Structure;
	
	FieldSelectionText = "SELECT DISTINCT ExchangePlanMainTable.Ref AS Ref";
	
	// Table with data source names (exchange plan tabular section)
	DataTable = GetDataTableForORR(ORR.FilterByExchangePlanProperties.Rows);
	
	TableDataText = GetDataTableTextForORR(DataTable);
	
	If EmptyRule Then
		
		ConditionText = "True";
		
	Else
		
		ConditionText = GetPropertyGroupConditionText(ORR.FilterByExchangePlanProperties.Rows, BooleanPropertyRootGroupValue, 0, ObjectProperties);
		
	EndIf;
	
	QueryText = FieldSelectionText + Chars.LF 
	             + "FROM"  + Chars.LF + TableDataText + Chars.LF
	             + "WHERE" + Chars.LF + ConditionText
	             + Chars.LF + "[RequiredConditions]";
	
	// Setting variable values
	ORR.QueryText    = QueryText;
	ORR.ObjectProperties = ObjectProperties;
	ORR.ObjectPropertiesString = GetObjectPropertyString(ObjectProperties);
	
EndProcedure

Function GetPropertyGroupConditionText(GroupProperties, BooleanGroupValue, Val BeforeAfter, ObjectProperties)
	
	OffsetString = "";
	
	// Getting the offset string for the property group
	For A = 0 To BeforeAfter Do
		OffsetString = OffsetString + " ";
	EndDo;
	
	ConditionText = "";
	
	For Each RecordRuleByProperty In GroupProperties Do
		
		If RecordRuleByProperty.IsFolder Then
			
			ConditionPrefix = ?(IsBlankString(ConditionText), "", Chars.LF + OffsetString + BooleanGroupValue + " ");
			
			ConditionText = ConditionText + ConditionPrefix + GetPropertyGroupConditionText(RecordRuleByProperty.Rows, RecordRuleByProperty.BooleanGroupValue, BeforeAfter + 10, ObjectProperties);
			
		Else
			
			ConditionPrefix = ?(IsBlankString(ConditionText), "", Chars.LF + OffsetString + BooleanGroupValue + " ");
			
			ConditionText = ConditionText + ConditionPrefix + GetPropertyConditionText(RecordRuleByProperty, ObjectProperties);
			
		EndIf;
		
	EndDo;
	
	ConditionText = "(" + ConditionText + Chars.LF 
				 + OffsetString + ")";
	
	Return ConditionText;
	
EndFunction

Function GetDataTableTextForORR(DataTable)
	
	TableDataText = "ExchangePlan." + Registration.ExchangePlanName + " AS ExchangePlanMainTable";
	
	For Each TableRow In DataTable Do
		
		TableSynonym = Registration.ExchangePlanName + TableRow.Name;
		
		TableDataText = TableDataText + Chars.LF + Chars.LF + "LEFT JOIN" + Chars.LF
		                 + "ExchangePlan." + Registration.ExchangePlanName + "." + TableRow.Name + " AS " + TableSynonym + "" + Chars.LF
		                 + "ON ExchangePlanMainTable.Ref = " + TableSynonym + ".Ref";
		
	EndDo;
	
	Return TableDataText;
	
EndFunction

Function GetDataTableForORR(GroupProperties)
	
	DataTable = New ValueTable;
	DataTable.Columns.Add("Name");
	
	For Each RecordRuleByProperty In GroupProperties Do
		
		If RecordRuleByProperty.IsFolder Then
			
			// Retrieving a data table for the lowest hierarchical level
			GroupDataTable = GetDataTableForORR(RecordRuleByProperty.Rows);
			
			// Adding received rows to the data table of the top hierarchical level
			For Each GroupTableRow In GroupDataTable Do
				
				FillPropertyValues(DataTable.Add(), GroupTableRow);
				
			EndDo;
			
		Else
			
			TableName = RecordRuleByProperty.NodeParameterTabularSection;
			
			// Skipping the empty table name as it is a node header property.
			If Not IsBlankString(TableName) Then
				
				TableRow = DataTable.Add();
				TableRow.Name = TableName;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	// Grouping the table
	DataTable.GroupBy("Name");
	
	Return DataTable;
	
EndFunction

Function GetPropertyConditionText(Rule, ObjectProperties)
	
	Var ComparisonType;
	
	ComparisonType = Rule.ComparisonType;
	
	// The comparison type must be inverted as the exchange plan table and the table of
	// the object to be registered contain data in inverted order (A>B <-> B<A) in the
	// "Data conversation" configuration and in the exchange plan query described in the module.

	InvertComparisonType(ComparisonType);
	
	TextOperator = GetCompareOperatorText(ComparisonType);
	
	TableSynonym = ?(IsBlankString(Rule.NodeParameterTabularSection),
	                              "ExchangePlanMainTable",
	                               Registration.ExchangePlanName + Rule.NodeParameterTabularSection);
	
	// A query parameter or a constant value can be used as a literal
	//
	// Example:
	// ExchangePlanProperty
	// <comparison type> &ObjectProperty_MyProperty ExchangePlanProperty <comparison type> DATETIME(1987,10,19,0,0,0)
	
	If Rule.IsConstantString Then
		
		ConstantValueType = TypeOf(Rule.ConstantValue);
		
		If ConstantValueType = BooleanType Then // Boolean
			
			QueryParameterLiteral = Format(Rule.ConstantValue, "BF = False; BT = True");
			
		ElsIf ConstantValueType = NumberType Then // Number
			
			QueryParameterLiteral = Format(Rule.ConstantValue, "NDS=.; NZ=0; NG=0; NN=1");
			
		ElsIf ConstantValueType = DateType Then // Date
			
			YearString   = Format(Year(Rule.ConstantValue),  "NZ=0; NG=0");
			MonthString  = Format(Month(Rule.ConstantValue),  "NZ=0; NG=0");
			DayString    = Format(Day(Rule.ConstantValue),     "NZ=0; NG=0");
			HourString   = Format(Hour(Rule.ConstantValue),  "NZ=0; NG=0");
			MinuteString = Format(Minute(Rule.ConstantValue), "NZ=0; NG=0");
			SecondString = Format(Second(Rule.ConstantValue),  "NZ=0; NG=0");
			
			QueryParameterLiteral = "DATETIME("
			+ YearString + ","
			+ MonthString + ","
			+ DayString + ","
			+ HourString + ","
			+ MinuteString + ","
			+ SecondString
			+ ")";
			
		Else // String
			
			// Enclosing string in quotation marks
			QueryParameterLiteral = """" + Rule.ConstantValue + """";
			
		EndIf;
		
	Else
		
		ObjectPropertyKey = StrReplace(Rule.ObjectProperty, ".", "_");
		
		QueryParameterLiteral = "&ObjectProperty_" + ObjectPropertyKey + "";
		
		ObjectProperties.Insert(ObjectPropertyKey, Rule.ObjectProperty);
		
	EndIf;
	
	ConditionText = TableSynonym + "." + Rule.NodeParameter + " " + TextOperator + " " + QueryParameterLiteral;
	
	Return ConditionText;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Compiling object registration rules (ORR) by object properties.

Procedure PrepareChangeRecordRuleByObjectProperties(ORR)
	
	ORR.RuleByObjectPropertiesEmpty = (ORR.FilterByObjectProperties.Rows.Count() = 0);
	
	// Skipping the blank rule
	If ORR.RuleByObjectPropertiesEmpty Then
		Return;
	EndIf;
	
	ObjectProperties = New Structure;
	
	FillObjectPropertyStructure(ORR.FilterByObjectProperties, ObjectProperties);
	
EndProcedure

Procedure FillObjectPropertyStructure(ValueTree, ObjectProperties)
	
	For Each TreeRow In ValueTree.Rows Do
		
		If TreeRow.IsFolder Then
			
			FillObjectPropertyStructure(TreeRow, ObjectProperties);
			
		Else
			
			TreeRow.ObjectPropertyKey = StrReplace(TreeRow.ObjectProperty, ".", "_");
			
			ObjectProperties.Insert(TreeRow.ObjectPropertyKey, TreeRow.ObjectProperty);
			
		EndIf;
		
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Auxiliary internal procedures and functions.

Procedure ReportProcessingError(Code = -1, ErrorDescription = "")
	
	// Setting the global error flag
	ErrorFlag = True;
	
	If ErrorMessages = Undefined Then
		ErrorMessages = InitMessages();
	EndIf;
	
	MessageString = ErrorMessages[Code];
	
	MessageString = ?(MessageString = Undefined, "", MessageString);
	
	If Not IsBlankString(ErrorDescription) Then
		
		MessageString = MessageString + Chars.LF + ErrorDescription;
		
	EndIf;
	
	WriteLogEvent(EventLogMessageKey(), EventLogLevel.Error,,, MessageString);
	
EndProcedure

Procedure InvertComparisonType(ComparisonType)
	
	If    ComparisonType = "Greater"        Then ComparisonType = "Less";
	ElsIf ComparisonType = "GreaterOrEqual" Then ComparisonType = "LessOrEqual";
	ElsIf ComparisonType = "Less"           Then ComparisonType = "Greater";
	ElsIf ComparisonType = "LessOrEqual"    Then ComparisonType = "GreaterOrEqual";
	EndIf;
	
EndProcedure

Procedure CheckExchangePlanExists()
	
	If TypeOf(Registration) <> Type("Structure") Then
		
		ReportProcessingError(0);
		Return;
		
	EndIf;
	
	If Registration.ExchangePlanName <> ExchangePlanNameForImport Then
		
		ErrorDescription = NStr("en = 'The name of the exchange plan specified in the registration rules (%1) does not match with the name of the exchange plan whose data is imported (%2)'");
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(ErrorDescription, Registration.ExchangePlanName, ExchangePlanNameForImport);
		ReportProcessingError(5, ErrorDescription);
		
	EndIf;
	
EndProcedure

Function GetCompareOperatorText(Val ComparisonType = "Equal")
	
	// Default return value
	TextOperator = "=";
	
	If    ComparisonType = "Equal"          Then TextOperator = "=";
	ElsIf ComparisonType = "NotEqual"       Then TextOperator = "<>";
	ElsIf ComparisonType = "Greater"        Then TextOperator = ">";
	ElsIf ComparisonType = "GreaterOrEqual" Then TextOperator = ">=";
	ElsIf ComparisonType = "Less"           Then TextOperator = "<";
	ElsIf ComparisonType = "LessOrEqual"    Then TextOperator = "<=";
	EndIf;
	
	Return TextOperator;
EndFunction

Function GetConfigurationPresentationFromRecordRules()
	
	ConfigurationName = "";
	Registration.Property("ConfigurationSynonym", ConfigurationName);
	
	If Not ValueIsFilled(ConfigurationName) Then
		Return "";
	EndIf;
	
	AccurateVersion = "";
	Registration.Property("ConfigurationVersion", AccurateVersion);
	
	If ValueIsFilled(AccurateVersion) Then
		
		AccurateVersion = CommonUseClientServer.ConfigurationVersionWithoutAssemblyNumber(AccurateVersion);
		
		ConfigurationName = ConfigurationName + " version " + AccurateVersion;
		
	EndIf;
	
	Return ConfigurationName;
		
EndFunction

Function GetObjectPropertyString(ObjectProperties)
	
	Result = "";
	
	For Each Item In ObjectProperties Do
		
		Result = Result + Item.Value + " AS " + Item.Key + ", ";
		
	EndDo;
	
	// Deleting last two characters
	StringFunctionsClientServer.DeleteLastCharsInString(Result, 2);
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for working with the XMLReader object.

// Reads the attribute value by name from the specified object, casts the value to
// the specified primitive type.
//
// Parameters:
//  Object - XMLReader - XMLReader object positioned to the beginning of the
//           element whose attribute will be retrieved.
//  Type   - Type - attribute type.
//  Name   - String - attribute name.
//
// Returns:
//  The attribute value received by the name and casted to the specified type.
// 
Function deAttribute(Object, Type, Name)
	
	ValueStr = TrimR(Object.GetAttribute(Name));
	
	If Not IsBlankString(ValueStr) Then
		
		Return XMLValue(Type, ValueStr);
		
	Else
		If Type = StringType Then
			Return "";
			
		ElsIf Type = BooleanType Then
			Return False;
			
		ElsIf Type = NumberType Then
			Return 0;
			
		ElsIf Type = DateType Then
			Return EmptyDateValue;
			
		EndIf;
	EndIf;
	
EndFunction // deAttribute()

// Reads the element text and casts the value to the specified primitive type.
//
// Parameters:
//  Object           - XMLReader - object whose data will be read. 
//  Type             - type of the return value.
//  SearchByProperty - for reference types, a property for searching can be specified.
//                     It can be: Code, Description, <AttributeName>, Name (of a 
//                     predefined value).
//
// Returns:
//  XML element value casted to the specified type.
//
Function deElementValue(Object, Type, SearchByProperty="")

	Value = "";
	Name      = Object.LocalName;

	While Object.Read() Do
		
		NodeName = Object.LocalName;
		NodeType = Object.NodeType;
		
		If NodeType = XMLNodeType.Text Then
			
			Value = TrimR(Object.Value);
			
		ElsIf (NodeName = Name) And (NodeType = XMLNodeType.EndElement) Then
			
			Break;
			
		Else
			
			Return Undefined;
			
		EndIf;
	EndDo;
	
	Return XMLValue(Type, Value)
	
EndFunction // deElementValue()

// Skips XML nodes till the end of the specified element (default is the current one).
//
// Parameters:
//  Object - XMLReader.
//  Name   - name of the node whose elements will be skipped.
// 
Procedure deSkip(Object, Name = "")
	
	AttachmentCount = 0; // Number of attachments with the same name
	
	If IsBlankString(Name) Then
	
		Name = Object.LocalName;
	
	EndIf;
	
	While Object.Read() Do
		
		NodeName = Object.LocalName;
		NodeType = Object.NodeType;
		
		If NodeName = Name Then
			
			If NodeType = XMLNodeType.EndElement Then
				
				If AttachmentCount = 0 Then
					Break;
				Else
					AttachmentCount = AttachmentCount - 1;
				EndIf;
				
			ElsIf NodeType = XMLNodeType.StartElement Then
				
				AttachmentCount = AttachmentCount + 1;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Local internal functions.

Function EventLogMessageKey()
	
	Return DataExchangeServer.DataExchangeRuleLoadingEventLogMessageText();
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Initializing attributes and modular variables.

// Initializes data processor attributes and modular variables.
//
Procedure InitAttributesAndModuleVariables()
	
	ErrorFlag = False;
	
	// Types
	StringType       = Type("String");
	BooleanType      = Type("Boolean");
	NumberType       = Type("Number");
	DateType         = Type("Date");
	
	EmptyDateValue = Date('00010101');
	
	BooleanPropertyRootGroupValue = "And"; // Boolean value for the root property group
	
EndProcedure

// Initializes the registration structure.
// 
Function RecordInitialization()
	
	Registration = New Structure;
	Registration.Insert("FormatVersion",    "");
	Registration.Insert("ID",               "");
	Registration.Insert("Description",      "");
	Registration.Insert("CreationDateTime", EmptyDateValue);
	Registration.Insert("ExchangePlan",     "");
	Registration.Insert("ExchangePlanName", "");
	Registration.Insert("Comment",          "");
	
	// Configuration parameters
	Registration.Insert("PlatformVersion",      "");
	Registration.Insert("ConfigurationVersion", "");
	Registration.Insert("ConfigurationSynonym", "");
	Registration.Insert("Configuration",        "");
	
	Return Registration;
	
EndFunction

// Initializes the variable that contains a map of message codes to message descriptions.
// 
Function InitMessages()
	
	Messages = New Map;
	DefaultLanguageCode = CommonUseClientServer.DefaultLanguageCode();
	
	Messages.Insert(0, NStr("en = 'Internal error.'", DefaultLanguageCode));
	Messages.Insert(1, NStr("en = 'Error opening the rule file.'", DefaultLanguageCode));
	Messages.Insert(2, NStr("en = 'Error loading rules.'", DefaultLanguageCode));
	Messages.Insert(3, NStr("en = 'Rule format error.'", DefaultLanguageCode));
	Messages.Insert(4, NStr("en = 'Error retrieving the rule file for reading.'", DefaultLanguageCode));
	Messages.Insert(5, NStr("en = 'Registration rules you try to load are not intended for the current exchange plan.'", DefaultLanguageCode));
	
	Return Messages;
	
EndFunction // InitMessages()

////////////////////////////////////////////////////////////////////////////////
// Main application operators

InitAttributesAndModuleVariables();

#EndRegion

#EndIf