
// Returns flag indicating that configuration has functional option CompanyPrefixes.
//
// Value returned:
//  Boolean - functional option exists in the configuration.
//
Function IsFunctionalOptionCompanyPrefixes() Export
	Return IsFunctionalOption("CompanyPrefixes");
EndFunction

// Returns flag indicating that configuration has functional option with the specified name.
//
// Parameters:
//  FunctionalOptionName - String - functional option name, that has to be checked for existence in the configuration.
//
// Value returned:
//  Boolean 			 - Flag indicating that configuration has functional option InfobasePrefix.
//
Function IsFunctionalOptionInfobasePrefix() Export
	Return IsFunctionalOption("InfobasePrefix");
EndFunction	

// Returns flag indicating that configuration has functional option with the specified name.
//
// Parameters:
//  FunctionalOptionName - String - functional option name, that has to be checked for existence in the configuration.
//
// Value returned:
//  Boolean 			 - functional option exists in the configuration.
//
Function IsFunctionalOption(FunctionalOptionName) Export
	
	Return Metadata.FunctionalOptions.Find(FunctionalOptionName) <> Undefined;
	
EndFunction
