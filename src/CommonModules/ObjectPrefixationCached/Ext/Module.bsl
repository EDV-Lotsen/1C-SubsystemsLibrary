////////////////////////////////////////////////////////////////////////////////
// Object prefixation subsystemю
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

// Returns a flag that shows whether the configuration includes the CompanyPrefixes
// functional option.
//
// Returns:
//  Boolean - flag that shows whether the configuration includes the CompanyPrefixes
//            functional option.
//
Function HasFunctionalOptionCompanyPrefixes() Export

	Return HasFunctionalOption("CompanyPrefixes");

EndFunction

// Returns a flag that shows whether the configuration includes the InfoBasePrefix
// functional option.
//
// Returns:
// Boolean - flag that shows whether the configuration includes the InfoBasePrefix
//           functional option.
//
Function HasInfoBasePrefixFunctionalOption() Export

	Return HasFunctionalOption("InfoBasePrefix");

EndFunction	

// Returns a flag that shows whether the configuration includes the functional
// option of the specified name.
//
// Returns:
//  Boolean - flag that shows whether the configuration includes the functional
//            option of the specified name.
//
Function HasFunctionalOption(FunctionalOptionName)
	
	Return Metadata.FunctionalOptions.Find(FunctionalOptionName) <> Undefined;
	
EndFunction