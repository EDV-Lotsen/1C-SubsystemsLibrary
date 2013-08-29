////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// Returns a default settings file name.
// The target node exchange settings will be exported to this file.
// This value must be the same in the source and target exchange plans.
// 
// Returns:
// String, 255 - default file name for exporting data exchange settings.
//
Function SettingsFileNameForTarget() Export
	
	Return NStr("en = 'SL exchange settings'");
	
EndFunction

// Returns a filter structure of the exchange plan node filled with default values.
// The filter structure is identical to the structure of exchange plan header 
// attributes and tabular sections.
// For header attributes, the corresponding keys and values of structure items are used.
// For tabular sections, structures that contain arrays of exchange plan tabular
// section field values are used. 
// 
// Returns:
// SettingsStructure - Structure - filter structure of the exchange plan node.
// 
Function NodeFilterStructure() Export
	
	CompanyTabularSectionStructure = New Structure;
	CompanyTabularSectionStructure.Insert("Company", New Array);
	
	SettingsStructure = New Structure;
	SettingsStructure.Insert("DocumentExportStartDate", BegOfYear(CurrentSessionDate()));
	SettingsStructure.Insert("UseFilterByCompanies",   	False);
	SettingsStructure.Insert("Companies",               CompanyTabularSectionStructure);
	
	SettingsStructure.Insert("CompanyExportMode",                Enums.ExchangeObjectExportModes.ExportByCondition);
	SettingsStructure.Insert("ItemsExportMode",                  Enums.ExchangeObjectExportModes.UnloadAlways);
	SettingsStructure.Insert("CounterpartyExportMode",           Enums.ExchangeObjectExportModes.UnloadAlways);
	SettingsStructure.Insert("ReferentialInformationExportMode", Undefined);
	
	Return SettingsStructure;
EndFunction

// Returns a structure of default values for the node;
// The settings structure are identical to the structure of exchange plan header attributes.
// For header attributes, the corresponding keys and values of structure items are used.
// 
// Returns:
// SettingsStructure - Structure - default value structure of the exchange plan node.
//  
Function NodeDefaultValues() Export
	
	SettingsStructure = New Structure;
	SettingsStructure.Insert("DefaultItem", Catalogs.Items.EmptyRef());

	Return SettingsStructure;
	
EndFunction

// Returns a string with data transfer restrictions to be displayed to end users.
// An applied solution developer must generate a human-readable restriction detail
// string based on the exchange node filters.
// 
// Parameters:
// NodeFilterStructure - Structure - exchange plan node filter structure that 
// was returned by the NodeFilterStructure function.
// 
// Returns:
// String, Unlimited - string that describes data transfer restrictions. It will be
// displayed to end users.
//
Function DataTransferRestrictionDetails(NodeFilterStructure) Export
	
	// Exporting documents starting from this date
	If ValueIsFilled(NodeFilterStructure.DocumentExportStartDate) Then
		DocumentExportStartDateRestriction = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Starting from %1'"),
			Format(NodeFilterStructure.DocumentExportStartDate, "DLF=DD")
		);
	Else
		DocumentExportStartDateRestriction = NStr("en = 'Whole accounting period'");
	EndIf;
	
	// Filtering by companies
	If NodeFilterStructure.UseFilterByCompanies Then
		FilterPresentationRow = StringFunctionsClientServer.GetStringFromSubstringArray(
			NodeFilterStructure.Companies.Company,
			"; "
		);
		RestrictionFilterByCompanies = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'By companies: %1'"),
			FilterPresentationRow
		);
	Else
		RestrictionFilterByCompanies = NStr("en = 'All companies");
	EndIf;
	
	RestrictionFilterByItemsMode = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = 'Items %1'"),
		Lower(NodeFilterStructure.ItemsExportMode)
	);
	
	RestrictionFilterByContractorsMode = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = 'Counterparties and counterparty contracts %1'"),
		Lower(NodeFilterStructure.CounterpartyExportMode)
	);
	
	RestrictionFilterByReferentialInformationMode = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = 'Referential information %1'"),
		Lower(NodeFilterStructure.ReferentialInformationExportMode)
	);
	
	RestrictionFilterByCompaniesMode = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = 'Companies %1'"),
		Lower(NodeFilterStructure.CompanyExportMode)
	);
	
	Return (
		NStr("en = 'Export documents and referential information:'")
		+ Chars.LF
		+ DocumentExportStartDateRestriction
		+ Chars.LF
		+ RestrictionFilterByCompanies
		+ Chars.LF
		+ RestrictionFilterByCompaniesMode
		+ Chars.LF
		+ RestrictionFilterByItemsMode
		+ Chars.LF
		+ RestrictionFilterByContractorsMode
		+ Chars.LF
		+ RestrictionFilterByReferentialInformationMode
	);
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
// String, Unlimited - string that describes data transfer restrictions. It will be
// displayed to end users.
//
Function DefaultValueDetails(NodeDefaultValues) Export

	ItemsDetails = "";
	
	// Items
	If ValueIsFilled(NodeDefaultValues.DefaultItem) Then
		
		NString = NStr("en = 'For production expense documents the %1 item will be used.'");
		
		ItemsDetais = StringFunctionsClientServer.SubstituteParametersInString(NString, String(NodeDefaultValues.DefaultItem));
		
	Else
		
		ItemsDetais = NStr("en = 'Item will not be set for documents'");
		
	EndIf;
	
	NString = NStr("en = '%1
	|'");
	
	//
	ParameterArray = New Array;
	ParameterArray.Add(ItemsDetails);
	
	Return StringFunctionsClientServer.SubstituteParametersInString(NString, ParameterArray);

EndFunction

// Returns a creation command presentation of a new data exchange.
//
// Returns:
// String, Unlimited - command presentation to be displayed in a user interface.
//
// Example:
// Return NStr("en = 'Create an exchange in the distributed infobase.'");
//
Function NewDataExchangeCreationCommandTitle() Export
	
	Return NStr("en = 'Create exchange with the Standard subsystems library'");
	
EndFunction

// Determines whether the wizard is used for creating new exchange plan nodes.
//
// Returns:
// Boolean - flag that shows whether the wizard is used for creating new exchange
// plan nodes.
//
Function UseDataExchangeCreationWizard() Export
	
	Return True;
	
EndFunction

// Returns the user form for creating an initial image of the infobase.
// This form will be opened after you finish setting the exchange with the wizard.
// For exchange plans of an undistributed infobase, the function returns an empty string.
//
// Returns:
// String, Unlimited - form name.
//
// Example:
// Return "ExchangePlan._DemoDistributedInfoBase.Form.PrimaryImageCreationForm";
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
// Array - array of ExchangeMessageTransportKindsenumeration values.
//
Function UsedExchangeMessageTransports() Export
	
	Return DataExchangeServer.AllApplicationExchangeMessageTransports();
	
EndFunction

Function ExchangePlanUsedInServiceMode() Export
	
	Return True;
	
EndFunction

Function CommonNodeData() Export
	
	Return "DocumentExportStartDate, Companies";
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Event handlers for exchanges that do not have any rules defined.

// Object change conflict event handler.
// This event occurs during data import if changes of the object being imported
// are registered in the infobase.
//
// Parameters:
// InfoBaseNode – ExchangePlanRef – exchange plan node where data is being imported.
// Object – object that caused the change conflict.
//
// Returns:
// Boolean - True if the object being imported must be recorded into the infobase, 
// otherwise is False.
//
Function ApplyObjectOnChangeConflict(InfoBaseNode, Object) Export
	
	Return False;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for working with external connections.

// Returns a filter structure of the correspondent infobase exchange plan node filled 
// with default values.
// The filter structure is identical to the structure of correspondent infobase 
// exchange plan header attributes and tabular sections.
// For header attributes, the corresponding keys and values of structure items are used.
// For tabular sections, structures that contain arrays of exchange plan tabular
// section field values are used. 
// 
// Returns:
// SettingsStructure - Structure - filter structure of the correspondent infobase exchange plan node.
//
Function CorrespondentInfoBaseNodeFilterSetup() Export
	
	CompanyTabularSectionStructure = New Structure;
	CompanyTabularSectionStructure.Insert("Company",     New Array);
	CompanyTabularSectionStructure.Insert("Company_Key", New Array);

	SettingsStructure = New Structure;
	SettingsStructure.Insert("DocumentExportStartDate", BegOfYear(CurrentSessionDate()));
	SettingsStructure.Insert("UseFilterByCompanies",    False);
	
	SettingsStructure.Insert("Companies",   CompanyTabularSectionStructure);
	
	SettingsStructure.Insert("CompanyExportMode",                Enums.ExchangeObjectExportModes.ExportByCondition);
	SettingsStructure.Insert("ItemsExportMode",                  Enums.ExchangeObjectExportModes.UnloadAlways);
	SettingsStructure.Insert("CounterpartyExportMode",           Enums.ExchangeObjectExportModes.UnloadAlways);
	SettingsStructure.Insert("ReferentialInformationExportMode", Undefined);
	
	Return SettingsStructure;
EndFunction

// Returns a structure of correspondent infobase node default values.
// The settings structure is identical to the structure of correspondent infobase 
// exchange plan header attributes.
// For header attributes, the corresponding keys and values of structure items are used.
// 
// Returns:
// SettingsStructure - Structure - default value structure of the correspondent infobase exchange plan node.
// 
Function CorrespondentInfoBaseNodeDefaultValues() Export
	
	SettingsStructure = New Structure;
	SettingsStructure.Insert("DefaultItem", "");
	
	SettingsStructure.Insert("DefaultItem_Key", "");
	
	Return SettingsStructure;
EndFunction

// Returns a string with correspondent infobase data transfer restrictions that will be
// displayed to end users. 
// An applied solution developer must generate a human-readable restriction detail string based on the correspondent infobase filters.
// 
// Parameters:
// NodeFilterStructure - Structure - correspondent infobase exchange plan node filter 
// structure that was returned by the NodeFilterStructure function.
// 
// Returns:
// String, Unlimited - string that describes data transfer restrictions. It will be displayed to end users.
//
Function CorrespondentInfoBaseDataTransferRestrictionDetails(NodeFilterStructure) Export
	
	// Export Documents always ...
	// date beginning unloading documents
	If ValueIsFilled(NodeFilterStructure.DocumentExportStartDate) Then
		DocumentExportStartDateRestriction = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Starting from %1'"),
			Format(NodeFilterStructure.DocumentExportStartDate, "DLF=DD")
		);
	Else
		DocumentExportStartDateRestriction = NStr("en = 'Whole accounting period'");
	EndIf;
	
	// Filtering by companies
	If NodeFilterStructure.UseFilterByCompanies Then
		FilterPresentationRow = StringFunctionsClientServer.GetStringFromSubstringArray(
			NodeFilterStructure.Companies.Company,
			"; "
		);
		RestrictionFilterByCompanies = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'By companies: %1'"),
			FilterPresentationRow
		);
	Else
		RestrictionFilterByCompanies = NStr("en = 'All companies'");
	EndIf;
	
	RestrictionFilterByItemsMode = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = 'Items %1'"),
		Lower(NodeFilterStructure.ItemsExportMode)
	);
	
	RestrictionFilterByContractorsMode = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = 'Counterparties and counterparty contracts %1'"),
		Lower(NodeFilterStructure.CounterpartyExportMode)
	);
	
	RestrictionFilterByReferentialInformationMode = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = 'Referential information %1'"),
		Lower(NodeFilterStructure.ReferentialInformationExportMode)
	);
	
	RestrictionFilterByCompaniesMode = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = 'Companies %1'"),
		Lower(NodeFilterStructure.CompanyExportMode)
	);
	
	Return (
		NStr("en = 'Export documents and referential information:'")
		+ Chars.LF
		+ DocumentExportStartDateRestriction
		+ Chars.LF
		+ RestrictionFilterByCompanies
		+ Chars.LF
		+ RestrictionFilterByCompaniesMode
		+ Chars.LF
		+ RestrictionFilterByItemsMode
		+ Chars.LF
		+ RestrictionFilterByContractorsMode
		+ Chars.LF
		+ RestrictionFilterByReferentialInformationMode
	);
EndFunction

// Returns a string with correspondent infobase default value details that will be 
// An applied solution developer must generate a human-readable detail string based on 
// the default node values.
// 
// Parameters:
// NodeDefaultValues - Structure - structure of default values for the correspondent 
// infobase exchange plan node that was returned by the
// CorrespondentInfoBaseNodeDefaultValues function.
// 
// Returns:
// String, Unlimited - string that describes default values. It will be displayed to end users.
//
Function CorrespondentInfoBaseDefaultValueDetails(NodeDefaultValues) Export

	Return "";

EndFunction

////////////////////////////////////////////////////////////////////////////////
// Constants and verification of accounting parameters.

Function AccountingSettingsSetupComment() Export
	
	Return NStr("en = 'Specify responsible persons for companies.
	|For this, go to the ""Data exchange"" section and click ""Company responsible persons"".'");
	
EndFunction

Function CorrespondentInfoBaseAccountingSettingsSetupComment() Export
	
	Return NStr("en = 'Specify responsible persons for companies in the online application.
	|For this, go to the online application, ""Data exchange"" section and click ""Company responsible persons"".'");
	
EndFunction

Procedure AccountingSettingsCheckHandler(Cancel, Recipient, Message) Export
	
	Filter = Undefined;
	
	TargetProperties = CommonUse.GetAttributeValues(Recipient, "UseFilterByCompanies, Companies");
	
	If TargetProperties.UseFilterByCompanies Then
		
		Filter = TargetProperties.Companies.Unload().UnloadColumn("Company");
		
	EndIf;
	
EndProcedure






