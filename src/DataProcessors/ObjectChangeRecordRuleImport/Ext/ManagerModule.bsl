#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region InternalProceduresAndFunctions

// Initializes object registration rule table columns.
// 
Function ORRTableInitialization() Export
	
	ObjectChangeRecordRules = New ValueTable;
	
	Columns = ObjectChangeRecordRules.Columns;
	
	Columns.Add("SettingsObject");
	
	Columns.Add("MetadataObjectName", New TypeDescription("String"));
	Columns.Add("ExchangePlanName",   New TypeDescription("String"));
	
	Columns.Add("FlagAttributeName", New TypeDescription("String"));
	
	Columns.Add("QueryText",        New TypeDescription("String"));
	Columns.Add("ObjectProperties", New TypeDescription("Structure"));
	
	Columns.Add("ObjectPropertiesString", New TypeDescription("String"));
	
	// Flag that shows whether rules are empty
	Columns.Add("RuleByObjectPropertiesEmpty", New TypeDescription("Boolean"));
	
	Columns.Add("FilterByExchangePlanProperties", New TypeDescription("ValueTree"));
	Columns.Add("FilterByObjectProperties",       New TypeDescription("ValueTree"));
	
	// Event handlers
	Columns.Add("BeforeProcess",       New TypeDescription("String"));
	Columns.Add("OnProcess",           New TypeDescription("String"));
	Columns.Add("OnProcessAdditional", New TypeDescription("String"));
	Columns.Add("AfterProcess",        New TypeDescription("String"));
	
	Columns.Add("HasBeforeProcessHandler",       New TypeDescription("Boolean"));
	Columns.Add("HasOnProcessHandler",           New TypeDescription("Boolean"));
	Columns.Add("HasOnProcessHandlerAdditional", New TypeDescription("Boolean"));
	Columns.Add("HasAfterProcessHandler",        New TypeDescription("Boolean"));
	
	Return ObjectChangeRecordRules;
	
EndFunction

// Initializes FilterByExchangePlanProperties table columns.
// 
Function FilterByExchangePlanPropertiesTableInitialization() Export
	
	TreePattern = New ValueTree;
	
	Columns = TreePattern.Columns;
	
	Columns.Add("IsFolder",          New TypeDescription("Boolean"));
	Columns.Add("BooleanGroupValue", New TypeDescription("String"));
	
	Columns.Add("ObjectProperty",     New TypeDescription("String"));
	Columns.Add("ComparisonType",     New TypeDescription("String"));
	Columns.Add("IsConstantString",   New TypeDescription("Boolean"));
	Columns.Add("ObjectPropertyType", New TypeDescription("String"));
	
	Columns.Add("NodeParameter",               New TypeDescription("String"));
	Columns.Add("NodeParameterTabularSection", New TypeDescription("String"));
	
	Columns.Add("ConstantValue"); // arbitrary type
	
	Return TreePattern;
	
EndFunction

// Initializes FilterByExchangePlanProperties table columns.
//
Function FilterByObjectPropertiesTableInitialization() Export
	
	TreePattern = New ValueTree;
	
	Columns = TreePattern.Columns;
	
	Columns.Add("IsFolder",           New TypeDescription("Boolean"));
	Columns.Add("IsAndOperator",      New TypeDescription("Boolean"));
	
	Columns.Add("ObjectProperty",     New TypeDescription("String"));
	Columns.Add("ObjectPropertyKey",  New TypeDescription("String"));
	Columns.Add("ComparisonType",     New TypeDescription("String"));
	Columns.Add("ObjectPropertyType", New TypeDescription("String"));
	Columns.Add("FilterItemKind",     New TypeDescription("String"));
	
	Columns.Add("ConstantValue"); // arbitrary type
	Columns.Add("PropertyValue");  // arbitrary type
	
	Return TreePattern;
	
EndFunction

#EndRegion

#EndIf