////////////////////////////////////////////////////////////////////////////////////////////////////
// Contact information subsystem
// 
////////////////////////////////////////////////////////////////////////////////////////////////////

#Region InternalInterface

// Parses contact information presentation, returns XML string containing parsed field values
//
//  Parameters:
//      Text         - String - XML
//      ExpectedType - CatalogRef.ContactInformationKinds, EnumRef.ContactInformationTypes 
//                   - used for type control purposes
//
//  Returns:
//      String - XML
//
Function ContactInformationParsingXML(Val Text, Val ExpectedKind) Export
	Return ContactInformationInternal.ContactInformationParsingXML(Text, ExpectedKind);
EndFunction

//  Returns enum value of contact information kind type
//
//  Parameters:
//      InformationKind - CatalogRef.ContactInformationKinds, Structure - initial data
//
//  Returns:
//      EnumRef.ContactInformationTypes - value of Type field
//
Function ContactInformationKindType(Val InformationKind) Export
	Return ContactInformationManagement.ContactInformationKindType(InformationKind);
EndFunction

// Returns string containing contact information content value.
//
//  Parameters:
//      XMLData - String - contact information XML data
//
//  Returns:
//      String - content
//      Undefined - if content value is composite
//
Function ContactInformationContentString(Val XMLData) Export;
	Return ContactInformationXML.ContactInformationContentString(XMLData);
EndFunction

// Converts all incoming contact information formats to XML
//
Function TransformContactInformationXML(Val Data) Export
	Return ContactInformationXML.TransformContactInformationXML(Data);
EndFunction

// Returns list of IDs of address strings available for copying to the current address
// 
Function AddressesAvailableForCopying(Val FieldValuesForAnalysis, Val AddressKind) Export
	
	Return ContactInformationManagement.AddressesAvailableForCopying(FieldValuesForAnalysis, AddressKind);
	
EndFunction

// Returns the found country reference, or creates a new world country record and returns reference to it
//
Function WorldCountriesByClassifier(Val CountryCode) Export
	Return Catalogs.WorldCountries.RefByClassifier(
		New Structure("Code", CountryCode)
	);
EndFunction

// Fills collection with references to the found or created world country records
//
Procedure WorldCountryCollectionByClassifier(Collection) Export
	For Each KeyValue In Collection Do
		Collection[KeyValue.Key] = Catalogs.WorldCountries.RefByClassifier(
			New Structure("Code", KeyValue.Value.Code)
		);
	EndDo;
EndProcedure

#EndRegion